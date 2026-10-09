-- Raid Soulstone reminders: ready-check buffs and self-reported wipe recovery.
-- No automatic resurrection or changes to the release button.
local PREFIX = "SRBT_SOULSTONE"
local SOULSTONE_RESURRECTION = 3026
local encounter, deadline, reported = nil, 0, false
local holders, timers = {}, {}
local warning
local readyCheckActive = false
local readyCheckInitiator
local readyWarningSent = false
local readyWhispersSent = false
local READY_WARNING = "USE SOULSTONE ON A HEALER!"
local visibleSoulstones, pullSoulstones, fallbackSoulstones = {}, {}, {}
local pullEncounter
local fallbackReady = false
local debugEnabled, debugHistory = false, {}

local function debugValue(value)
    if issecretvalue and issecretvalue(value) then return "<restricted>" end
    return tostring(value)
end

local function debugLog(message)
    if not debugEnabled then return end
    local line = string.format("[%.1f] %s", GetTime(), message)
    debugHistory[#debugHistory + 1] = line
    if #debugHistory > 30 then table.remove(debugHistory, 1) end
    print("|cff55ddffSRBT Soulstone debug:|r " .. line)
end

function raidSoulstoneDebug(command)
    if command == "on" then
        debugEnabled = true
        debugLog("Enabled for this session. Enable on the Soulstone holder too for resurrection diagnostics.")
    elseif command == "off" then
        debugEnabled = false
        print("SRBT Soulstone debug: off.")
    elseif command == "" or command == "status" then
        print("SRBT Soulstone debug: " .. (debugEnabled and "on" or "off")
            .. "; encounter=" .. debugValue(encounter) .. "; pull=" .. debugValue(pullEncounter)
            .. "; deadline=" .. debugValue(deadline) .. "; fallbackReady=" .. debugValue(fallbackReady))
        for label, entries in pairs({ visible = visibleSoulstones, pull = pullSoulstones,
            fallback = fallbackSoulstones, confirmed = holders }) do
            local count = 0
            for name, info in pairs(entries) do
                count = count + 1
                print("SRBT " .. label .. ": " .. debugValue(name) .. " = "
                    .. debugValue(type(info) == "table" and info.expiresAt or info))
            end
            print("SRBT " .. label .. " count: " .. count)
        end
        for _, line in ipairs(debugHistory) do print("SRBT history: " .. line) end
    else
        print("Usage: /srbt soulstone debug <on|off|status>")
    end
end

local function isSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function announceReadyWarning()
    local player, realm = UnitFullName("player")
    realm = realm and realm ~= "" and realm or GetNormalizedRealmName()
    if not player or not realm or not readyCheckInitiator then return end
    local playerName = player .. "-" .. realm
    local isInitiator = readyCheckInitiator == playerName
        or readyCheckInitiator == Ambiguate(playerName, "none")
    -- The initiator uses raid warning; other opted-in players use ordinary raid chat.
    if getSettings().soulstoneEnabled and not readyWarningSent then
        readyWarningSent = true
        if isInitiator and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
            C_ChatInfo.SendChatMessage(READY_WARNING, "RAID_WARNING")
        else
            -- Fall back to chat if the initiator lost raid-warning permissions.
            C_ChatInfo.SendChatMessage("No Soulstone in the raid!", "RAID")
        end
    end
    if isInitiator and not readyWhispersSent then
        readyWhispersSent = true
        -- Only the initiator whispers, once per ready check, to every online warlock.
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            local _, class = UnitClass(unit)
            if class == "WARLOCK" and UnitIsConnected(unit) then
                local name, targetRealm = UnitFullName(unit)
                targetRealm = targetRealm and targetRealm ~= "" and targetRealm or GetNormalizedRealmName()
                if name and targetRealm then
                    C_ChatInfo.SendChatMessage(
                        "Hi! Nobody in the raid has Soulstone. Please use it on a healer before we pull :)",
                        "WHISPER", nil, name .. "-" .. targetRealm)
                end
            end
        end
    end
end

local function channel()
    if not isRaidBreakModuleEnabled("raidRecovery") then return nil end
    local _, instanceType = GetInstanceInfo()
    if not IsInRaid() or instanceType ~= "raid" then return nil end
    return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "RAID"
end

local function fullName(unit)
    local name, realm = UnitFullName(unit)
    realm = realm and realm ~= "" and realm or GetNormalizedRealmName()
    if name and realm then return name .. "-" .. realm end
end

local function raidUnit(sender)
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        local name = fullName(unit)
        if name and (sender == name or sender == Ambiguate(name, "none")) then return unit, name end
    end
end

local restitution = createRaidRestitutionHelper(fullName, raidUnit, channel, debugLog)
local soulstoneDeadline = 0

-- Observe only readable, out-of-combat buffs. Never infer absence from restricted data.
local function rememberSoulstone(unit)
    if pullEncounter or InCombatLockdown() or not channel() then return end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret() then return end
    local name = fullName(unit)
    if not name then return end
    visibleSoulstones[name] = nil
    if not UnitIsConnected(unit) or not UnitIsVisible(unit) then return end
    for index = 1, 255 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")
        if isSecret(aura) or not aura then return end
        if not isSecret(aura.spellId) and aura.spellId == 20707 then
            local expiry = aura.expirationTime
            if isSecret(expiry) or type(expiry) ~= "number" or expiry <= 0 then expiry = nil end
            visibleSoulstones[name] = { expiresAt = expiry }
            debugLog("Recorded pre-pull Soulstone: " .. debugValue(name) .. "; expires=" .. debugValue(expiry))
            return
        end
    end
end

local function rememberRaidSoulstones()
    if pullEncounter or InCombatLockdown() then return end
    visibleSoulstones = {}
    if not channel() then return end
    for i = 1, GetNumGroupMembers() do rememberSoulstone("raid" .. i) end
end

local function showWarning(titleText, subtitleText)
    debugLog("SHOW: " .. titleText .. " / " .. subtitleText)
    if not warning then
        warning = CreateFrame("Frame", nil, UIParent)
        warning:SetSize(800, 240)
        registerRaidBreakAlertPosition(warning, "recovery")
        warning:SetFrameStrata("FULLSCREEN_DIALOG")
        warning:EnableMouse(false)
        local title = warning:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        title:SetPoint("CENTER", 0, 30)
        title:SetWidth(800)
        local font, _, flags = title:GetFont()
        title:SetFont(font, 60, flags)
        warning.title = title
        warning.subtitle = warning:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        warning.subtitle:SetPoint("TOP", title, "BOTTOM", 0, -12)
        warning.subtitle:SetWidth(800)
    end
    warning.title:SetText(titleText)
    warning.subtitle:SetText(subtitleText)
    warning:Show()
end

local function render()
    local names = {}
    for name, available in pairs(holders) do
        local unit = raidUnit(name)
        if GetTime() < soulstoneDeadline and available and unit and UnitIsConnected(unit) and UnitIsDead(unit) and not UnitIsGhost(unit) then
            names[#names + 1] = Ambiguate(name, "none")
        end
    end
    table.sort(names)
    if not channel() or GetTime() >= deadline then
        debugLog("Render skipped: outside raid instance/group or warning expired.")
        if warning then warning:Hide() end
        return
    end
    if #names > 0 then
        showWarning("DON'T RELEASE!", table.concat(names, ", ") .. (#names == 1 and " has a Soulstone." or " have Soulstones."))
        return -- Confirmed reports always take priority over remembered buffs.
    end
    local restitutionWarning, restitutionTitle = restitution:warning()
    if restitutionWarning then
        showWarning(restitutionTitle or "DON'T RELEASE!", restitutionWarning)
        return
    end
    if fallbackReady and GetTime() < soulstoneDeadline then
        for name, info in pairs(fallbackSoulstones) do
            local unit = raidUnit(name)
            if not unit or not UnitIsConnected(unit) or not UnitIsDead(unit) or UnitIsGhost(unit)
                or (info.expiresAt and info.expiresAt <= GetTime()) or holders[name] ~= nil then
                fallbackSoulstones[name] = nil
            else names[#names + 1] = Ambiguate(name, "none") end
        end
    end
    table.sort(names)
    if #names > 0 then
        showWarning("DON'T RELEASE YET!", table.concat(names, ", ") .. " had Soulstone before the pull.\nCheck if they can resurrect — not confirmed.")
    else
        debugLog("No eligible confirmed or fallback holders to display.")
        if warning then warning:Hide() end
    end
end

local function checkReadySoulstone()
    if not readyCheckActive then return end
    if warning then warning:Hide() end
    if not channel() or InCombatLockdown() then return end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret() then return end
    local warlock, unknown = false, false
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        local _, class = UnitClass(unit)
        if class == "WARLOCK" and UnitIsConnected(unit) then warlock = true end
        -- Out-of-range, offline or restricted information cannot prove an aura is absent.
        if not class or not UnitIsConnected(unit) or not UnitIsVisible(unit) then
            unknown = true
        else
            for index = 1, 255 do
                local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")
                if issecretvalue and issecretvalue(aura) then unknown = true; break end
                if not aura then break end
                if issecretvalue and issecretvalue(aura.spellId) then
                    unknown = true
                elseif aura.spellId == 20707 then
                    return -- Any Soulstone holder is enough, regardless of role.
                end
                if index == 255 then unknown = true end
            end
        end
    end
    if warlock and not unknown then
        if getSettings().soulstoneEnabled then
            showWarning("USE SOULSTONE\nON A HEALER!", "No Soulstone detected in the raid.")
        end
        announceReadyWarning()
    end
end

local function reset(preserveRestitution)
    for _, timer in ipairs(timers) do timer:Cancel() end
    timers, holders = {}, {}
    encounter, deadline, reported = nil, 0, false
    readyCheckActive = false
    readyWarningSent = false
    readyWhispersSent = false
    readyCheckInitiator = nil
    fallbackSoulstones, fallbackReady = {}, false
    soulstoneDeadline = 0
    if not preserveRestitution then restitution:reset() end
    if warning then warning:Hide() end
end

-- Individual preferences never override the recovery module's master switch.
registerRaidBreakModuleListener("raidRecovery", function()
    reset()
    pullEncounter, pullSoulstones, visibleSoulstones = nil, {}, {}
end)

function setRaidSoulstoneEnabled(enabled)
    getSettings().soulstoneEnabled = enabled == true
    if not enabled and readyCheckActive and warning then warning:Hide() end
end

local function checkOwnSoulstone()
    if not encounter or GetTime() >= deadline or not channel() then return end
    debugLog("Own check: dead=" .. debugValue(UnitIsDead("player")) .. "; ghost=" .. debugValue(UnitIsGhost("player")))
    local usable = false
    if UnitIsDead("player") and not UnitIsGhost("player") then
        for _, option in ipairs(C_DeathInfo.GetSelfResurrectOptions() or {}) do
            debugLog("Resurrection option: id=" .. debugValue(option.id) .. "; type=" .. debugValue(option.optionType)
                .. "; usable=" .. debugValue(option.canUse) .. "; name=" .. debugValue(option.name))
            -- Match the resurrection spell, not the warlock's Soulstone cast/aura.
            if option.optionType == Enum.SelfResurrectOptionType.Spell
                and option.id == SOULSTONE_RESURRECTION and option.canUse then usable = true; break end
        end
    end
    local name = fullName("player")
    if not name or usable == reported then return end
    reported = usable
    debugLog("Sending own Soulstone state: " .. debugValue(usable))
    holders[name] = usable -- Preserve explicit withdrawals so the fallback cannot revive them.
    C_ChatInfo.SendAddonMessage(PREFIX, encounter .. ":" .. (usable and "1" or "0"), channel())
    render()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "ENCOUNTER_START", "ENCOUNTER_END", "CHAT_MSG_ADDON",
    "SELF_RES_SPELL_CHANGED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "READY_CHECK", "READY_CHECK_FINISHED",
    "UNIT_AURA", "UNIT_FLAGS", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, ...)
    if event ~= "PLAYER_LOGIN" and not isRaidBreakModuleEnabled("raidRecovery") then return end
    if event == "PLAYER_LOGIN" then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        C_ChatInfo.RegisterAddonMessagePrefix("SRBT_RESTITUTION")
        rememberRaidSoulstones()
    elseif event == "READY_CHECK" then
        reset()
        if not channel() or InCombatLockdown() then return end
        readyCheckActive = true
        readyCheckInitiator = ...
        rememberRaidSoulstones()
        checkReadySoulstone()
    elseif event == "READY_CHECK_FINISHED" then
        if readyCheckActive then reset() end
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" and (pullEncounter or encounter) then
            restitution:check(encounter)
            if encounter then render() end
        end
        if unit == "player" or (type(unit) == "string" and unit:match("^raid%d+$")) then rememberSoulstone(unit) end
        if readyCheckActive and (unit == "player" or (type(unit) == "string" and unit:match("^raid%d+$"))) then
            checkReadySoulstone()
        end
    elseif event == "ENCOUNTER_START" then
        debugLog("ENCOUNTER_START id=" .. debugValue((...)) .. "; combat=" .. debugValue(InCombatLockdown()))
        rememberRaidSoulstones()
        pullSoulstones, visibleSoulstones = visibleSoulstones, {}
        pullEncounter = ...
        reset()
    elseif event == "PLAYER_ENTERING_WORLD" then
        reset()
        pullEncounter, pullSoulstones, visibleSoulstones = nil, {}, {}
        rememberRaidSoulstones()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if readyCheckActive then reset() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        rememberRaidSoulstones()
    elseif event == "UNIT_FLAGS" then
        if encounter then render() end
    elseif event == "ENCOUNTER_END" then
        local id, _, _, _, success = ...
        debugLog("ENCOUNTER_END id=" .. debugValue(id) .. "; success=" .. debugValue(success)
            .. "; matching pull=" .. debugValue(pullEncounter == id) .. "; channel=" .. debugValue(channel()))
        local matchingPull = pullEncounter == id
        local snapshot = matchingPull and pullSoulstones or {}
        pullEncounter, pullSoulstones, visibleSoulstones = nil, {}, {}
        -- Keep the priest's witnessed angel state through this matching wipe only.
        reset(matchingPull and success == 0 and channel() ~= nil)
        if success ~= 0 or not channel() then return end
        encounter, deadline = id, GetTime() + 30
        soulstoneDeadline = GetTime() + 15
        fallbackSoulstones = snapshot
        -- Warn before players release; confirmed reports replace this immediately when received.
        fallbackReady = true
        render()
        -- Briefly defer so every client can process ENCOUNTER_END before reports arrive.
        timers[#timers + 1] = C_Timer.NewTimer(0.5, checkOwnSoulstone)
        timers[#timers + 1] = C_Timer.NewTimer(2, checkOwnSoulstone)
        -- Bounded polling covers aura removal/revival and expires the alive message.
        timers[#timers + 1] = C_Timer.NewTicker(0.5, function()
            restitution:check(encounter)
            render()
        end)
        timers[#timers + 1] = C_Timer.NewTimer(30, function() reset() end)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, distribution, sender = ...
        if prefix == "SRBT_RESTITUTION" then
            if encounter and GetTime() < deadline and channel() then
                restitution:receive(message, distribution, sender, encounter)
                render()
            end
            return
        end
        if prefix == PREFIX then
            debugLog("Received: " .. debugValue(sender) .. " / " .. debugValue(distribution) .. " / " .. debugValue(message))
        end
        if prefix ~= PREFIX or not encounter or GetTime() >= deadline
            or not channel() or distribution ~= channel() or type(message) ~= "string" or #message > 32 then return end
        local id, state = message:match("^(%d+):([01])$")
        if tonumber(id) ~= encounter then return end
        local unit, name = raidUnit(sender)
        if not unit or name == fullName("player") then return end
        local available = state == "1"
        if available and (not UnitIsDead(unit) or UnitIsGhost(unit)) then return end
        if holders[name] == available then return end
        holders[name] = available
        render()
    elseif event == "GROUP_ROSTER_UPDATE" then
        rememberRaidSoulstones()
        if readyCheckActive then checkReadySoulstone()
        elseif not channel() then reset() else render() end
    else
        if pullEncounter or encounter then
            restitution:check(encounter)
            if encounter then render() end
        end
        checkOwnSoulstone()
    end
end)
