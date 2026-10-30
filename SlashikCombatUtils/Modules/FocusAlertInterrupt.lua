local _, addon = ...
local module = { title="Focus Alert Interrupt", description="Voice or sound alerts for enemy focus casts when your interrupt is ready." }
addon:RegisterModule("focusInterrupt", module)
local function secret(value) return issecretvalue and issecretvalue(value) end
-- Adapted from the user's installed FocusAlertInterrupt; cooldowns may be estimated.
-- Fallback sounds when LibSharedMedia is absent
local BUILTIN_SOUNDS = {
    { name = "Auction Window Close", file = 567499 },
    { name = "Raid Warning",   id = SOUNDKIT.RAID_WARNING          },
    { name = "Ready Check",    id = SOUNDKIT.READY_CHECK           },
    { name = "Alarm",          id = SOUNDKIT.ALARM_CLOCK_WARNING_3 },
    { name = "Quest Complete", id = SOUNDKIT.IG_QUEST_LOG_OPEN     },
    { name = "Ping",           id = SOUNDKIT.MAP_PING              },
    { name = "Ding",           id = SOUNDKIT.LEVEL_UP              },
}

-- Base cooldowns (Midnight 12.0)
local CLASS_INTERRUPTS = {
    DEATHKNIGHT = { { id = 47528,  name = "Mind Freeze",        cd = 15 } },
    DEMONHUNTER = { { id = 183752, name = "Disrupt",            cd = 15 } },
    DRUID       = { { id = 106839, name = "Skull Bash",         cd = 15, specs = {102,103,104} } },
    EVOKER      = { { id = 351338, name = "Quell",              cd = 40, specs = {1467,1473} } },
    HUNTER      = { { id = 147362, name = "Counter Shot",       cd = 24, specs = {253,254} },
                    { id = 187707, name = "Muzzle",             cd = 15, specs = {255} } },
    MAGE        = { { id = 2139,   name = "Counterspell",       cd = 20 } },
    MONK        = { { id = 116705, name = "Spear Hand Strike",  cd = 15, specs = {268,269} } },
    PALADIN     = { { id = 96231,  name = "Rebuke",             cd = 15, specs = {66,70} } },
    PRIEST      = { { id = 15487,  name = "Silence",            cd = 45, specs = {258} } },
    ROGUE       = { { id = 1766,   name = "Kick",               cd = 15 } },
    SHAMAN      = { { id = 57994,  name = "Wind Shear",         cd = 12 } },
    WARLOCK     = { { id = 19647,  name = "Spell Lock",         cd = 24 },
                    { id = 119910, name = "Axe Toss",           cd = 30, specs = {265} } },
    WARRIOR     = { { id = 6552,   name = "Pummel",             cd = 15 } },
}

local CD_REDUCTION_TALENTS = {
    [382297] = { affects = 2139,   reduction = 5  },
    [371016] = { affects = 351338, reduction = 20 },
    [329526] = { affects = 57994,  reduction = 4  },
}
local CD_ON_SUCCESS_TALENTS = {
    [378848] = { affects = 47528, reduction = 3 },
}

-- ---------------------------------------------------------------
--  State
-- ---------------------------------------------------------------
local db
local LSM = nil
local playerClass, playerSpec
local interruptSpells       = {}
local interruptReadyAt      = 0
local lastAlertTime         = 0
local pendingAlert          = false
local lastInterruptCastTime = nil
local lastInterruptSpellID  = nil
local onSuccessReductions   = {}
local cachedCD              = {}

-- ---------------------------------------------------------------
--  Sound helpers
-- ---------------------------------------------------------------
local function GetSoundList()
    local t, seen = {}, {}
    for _, s in ipairs(BUILTIN_SOUNDS) do t[#t+1] = s.name; seen[s.name] = true end
    if LSM then
        for _, name in ipairs(LSM:List("sound")) do
            if not seen[name] then t[#t+1] = name; seen[name] = true end
        end
    end
    return t
end

local function PlayAlertSound(name)
    if LSM then
        local path = LSM:Fetch("sound", name, true)
        if path then PlaySoundFile(path, "Master"); return end
    end
    for _, s in ipairs(BUILTIN_SOUNDS) do
        if s.name == name then
            if s.file then PlaySoundFile(s.file, "Master") else PlaySound(s.id, "Master") end
            return
        end
    end
    PlaySoundFile(BUILTIN_SOUNDS[1].file, "Master")
end

-- ---------------------------------------------------------------
--  DB
-- ---------------------------------------------------------------
local function InitDB()
    db = addon:GetSettings().focusInterrupt
    LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- ---------------------------------------------------------------
--  Talents
-- ---------------------------------------------------------------
local function ScanTalents()
    if not C_ClassTalents or not C_Traits then return end
    local ok0, configID = pcall(C_ClassTalents.GetActiveConfigID)
    if not ok0 or not configID then return end
    local ok1, configInfo = pcall(C_Traits.GetConfigInfo, configID)
    if not ok1 or not configInfo or not configInfo.treeIDs or #configInfo.treeIDs == 0 then return end
    local ok2, nodeIDs = pcall(C_Traits.GetTreeNodes, configInfo.treeIDs[1])
    if not ok2 or not nodeIDs then return end
    for _, nodeID in ipairs(nodeIDs) do
        local ok3, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if ok3 and node and node.activeEntry and (node.activeRank or 0) > 0 then
            local ok4, entry = pcall(C_Traits.GetEntryInfo, configID, node.activeEntry.entryID)
            if ok4 and entry and entry.definitionID then
                local ok5, def = pcall(C_Traits.GetDefinitionInfo, entry.definitionID)
                if ok5 and def and def.spellID then
                    local t = CD_REDUCTION_TALENTS[def.spellID]
                    if t then
                        for _, spell in ipairs(interruptSpells) do
                            if spell.id == t.affects then
                                local newCd = spell.cd - t.reduction
                                if newCd > 1 then cachedCD[spell.id] = newCd end
                            end
                        end
                    end
                    local s = CD_ON_SUCCESS_TALENTS[def.spellID]
                    if s then onSuccessReductions[s.affects] = s.reduction end
                end
            end
        end
    end
end

local function TryCacheCD()
    if InCombatLockdown() then return end
    for _, spell in ipairs(interruptSpells) do
        local ok, info = pcall(C_Spell.GetSpellCooldown, spell.id)
        if ok and info then
            local ok2, dur = pcall(function() return info.duration end)
            if ok2 and not secret(dur) and type(dur)=="number" then
                local n = tonumber(string.format("%.1f", dur))
                if n and n > 1.5 and n < 120 then
                    cachedCD[spell.id] = n
                    local start=info.startTime
                    if not secret(start) and type(start)=="number" then interruptReadyAt=math.max(interruptReadyAt,start+n) end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------
--  Spell setup
-- ---------------------------------------------------------------
local function UpdateInterruptSpells()
    local idx = GetSpecialization()
    if idx then playerSpec = GetSpecializationInfo(idx) end
    local data = CLASS_INTERRUPTS[playerClass]
    local newSpells = {}
    if data then
        for _, spell in ipairs(data) do
            local match = not spell.specs
            if not match then
                for _, s in ipairs(spell.specs) do
                    if s == playerSpec then match = true; break end
                end
            end
            if match and (IsPlayerSpell(spell.id) or IsSpellKnown(spell.id) or IsSpellKnown(spell.id, true)) then
                local cd = spell.cd
                local okms, ms = pcall(GetSpellBaseCooldown, spell.id)
                if okms and not secret(ms) and type(ms)=="number" and ms > 1500 then cd = ms / 1000 end
                newSpells[#newSpells+1] = { id = spell.id, name = spell.name, cd = cd }
            end
        end
    end
    local changed = #newSpells ~= #interruptSpells
    if not changed then
        for i, s in ipairs(newSpells) do
            if s.id ~= (interruptSpells[i] and interruptSpells[i].id) then changed = true; break end
        end
    end
    if changed then interruptReadyAt = 0; cachedCD = {}; onSuccessReductions = {} end
    interruptSpells = newSpells
    cachedCD = {}; onSuccessReductions = {}
    ScanTalents()
    TryCacheCD()
end

-- ---------------------------------------------------------------
--  Alert
-- ---------------------------------------------------------------
local function IsInterruptReady()
    return #interruptSpells > 0 and (interruptReadyAt == 0 or GetTime() >= interruptReadyAt)
end

local function FireAlert()
    if not module.enabled then return end
    local now = GetTime()
    if now - lastAlertTime < 1.5 then return end
    lastAlertTime = now
    if db.ttsMode and C_TTSSettings and C_VoiceChat then
        local voiceID = C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard)
        C_VoiceChat.SpeakText(voiceID, (db.ttsMessage ~= "" and db.ttsMessage) or "Interrupt", 0, 100, false)
    else
        PlayAlertSound(db.soundName)
    end
end


local focusCasting, wasReady, wasCasting = false, false, false
local function CanAlert()
    local ok, enemy=pcall(UnitCanAttack,"player","focus")
    if not ok or secret(enemy) or not enemy then return false end
    for _, api in ipairs({UnitCastingInfo,UnitChannelInfo}) do
        local ok,name,_,_,_,_,_,channelImmune,castImmune=pcall(api,"focus")
        if ok and not secret(name) and name~=nil then
            local immune
            if api==UnitCastingInfo then immune=castImmune else immune=channelImmune end
            if not secret(immune) and immune==true then return false end
            return true
        end
    end
    return focusCasting
end
function module:GetSounds() InitDB(); return GetSoundList() end
function module:PreviewSound(name)
    if not self.enabled then return end
    InitDB(); PlayAlertSound(name)
end
function module:TestAlert() InitDB(); lastAlertTime=-math.huge; FireAlert() end
function module:Check()
    if not self.enabled then return end
    local casting,ready=CanAlert(),IsInterruptReady()
    if casting and ready and (pendingAlert or not wasReady or not wasCasting) then FireAlert() end
    pendingAlert=false; wasReady=ready; wasCasting=casting
end
function module:Event(event,unit,castGUID,spellID)
    if event=="UNIT_SPELLCAST_SUCCEEDED" then
        if unit~="player" and unit~="pet" then return end
        if secret(spellID) then return end
        for _, spell in ipairs(interruptSpells) do
            if spell.id==spellID then
                interruptReadyAt=GetTime()+(cachedCD[spell.id] or spell.cd)
                lastInterruptCastTime=GetTime(); lastInterruptSpellID=spell.id
                wasReady=false
                return
            end
        end
    elseif event=="UNIT_SPELLCAST_INTERRUPTED" and unit=="focus" then
        if lastInterruptCastTime and GetTime()-lastInterruptCastTime<=1 then
            local reduction=onSuccessReductions[lastInterruptSpellID]
            if reduction then interruptReadyAt=interruptReadyAt-reduction end
        end
        lastInterruptCastTime=nil; lastInterruptSpellID=nil; focusCasting=false; pendingAlert=false
    elseif event=="UNIT_SPELLCAST_START" or event=="UNIT_SPELLCAST_CHANNEL_START" then
        if unit=="focus" then focusCasting=true; pendingAlert=true end
    elseif event=="UNIT_SPELLCAST_STOP" or event=="UNIT_SPELLCAST_CHANNEL_STOP" or event=="UNIT_SPELLCAST_FAILED" then
        if unit=="focus" then focusCasting=false; pendingAlert=false end
    elseif event=="PLAYER_FOCUS_CHANGED" then
        focusCasting=false; wasCasting=false; pendingAlert=true
    elseif event=="PLAYER_REGEN_ENABLED" then TryCacheCD()
    else UpdateInterruptSpells() end
end
function module:Enable()
    if self.enabled then return end
    InitDB(); self.enabled=true
    local _, class=UnitClass("player"); playerClass=class
    lastAlertTime=-math.huge; pendingAlert=false; focusCasting=false; wasReady=false; wasCasting=false
    UpdateInterruptSpells()
    if not self.events then self.events=CreateFrame("Frame") end
    self.events:SetScript("OnEvent",function(_,event,...) self:Event(event,...) end)
    for _, event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_SPECIALIZATION_CHANGED","SPELLS_CHANGED","PLAYER_TALENT_UPDATE","UNIT_PET","PLAYER_REGEN_ENABLED","PLAYER_FOCUS_CHANGED"}) do self.events:RegisterEvent(event) end
    self.events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED","player","pet")
    for _, event in ipairs({"UNIT_SPELLCAST_START","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_CHANNEL_STOP","UNIT_SPELLCAST_INTERRUPTED","UNIT_SPELLCAST_FAILED"}) do self.events:RegisterUnitEvent(event,"focus") end
    self.elapsed=0
    self.events:SetScript("OnUpdate",function(_,elapsed)
        self.elapsed=self.elapsed+elapsed
        if self.elapsed>=0.05 then self.elapsed=0; self:Check() end
    end)
end
function module:Disable()
    self.enabled=false; pendingAlert=false; focusCasting=false
    if self.events then self.events:UnregisterAllEvents(); self.events:SetScript("OnUpdate",nil) end
end
