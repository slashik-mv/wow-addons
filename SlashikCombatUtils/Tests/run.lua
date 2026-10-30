function IsPlayerSpell() return false end
function IsSpellKnown() return false end
-- Run from the addon directory with Lua 5.1+. No game files are modified.
unpack = unpack or table.unpack
local frames, addon = {}, {}
local combat, dead, spec, class = false, false, 250, "DEATHKNIGHT"
local dndAura, dndRestricted
local aura, restricted, failQuery, queries = nil, false, false, 0
local SECRET = setmetatable({}, { __lt = function() error("Secret compared") end,
    __le = function() error("Secret compared") end, __sub = function() error("Secret arithmetic") end })
local methods = {}
local function object(name)
    local o = setmetatable({ name = name, scripts = {}, events = {}, shown = true }, { __index = methods })
    if name then _G[name] = o end
    return o
end
for _, method in ipairs({ "SetSize", "SetPoint", "SetFrameStrata", "SetClampedToScreen", "SetMovable",
    "RegisterForDrag", "SetFontObject", "SetFont", "SetTextColor", "SetAllPoints", "SetThickness", "SetStartPoint",
    "SetEndPoint", "SetLooping", "SetOffset", "SetDuration", "SetSmoothing", "SetBackdrop",
    "SetBackdropColor", "SetBackdropBorderColor", "ClearAllPoints", "StartMoving", "StopMovingOrSizing",
    "SetFrameLevel", "RegisterForClicks", "SetHighlightTexture", "SetHyperlinksEnabled", "SetWidth", "SetHeight", "SetScrollChild", "SetJustifyH", "SetAutoFocus", "SetNumeric", "SetMaxLetters", "ClearFocus", "SetAlpha" }) do
    methods[method] = function() end
end
function methods:SetStartPoint(point, relativeTo, x, y)
    assert(type(relativeTo) == "table" and type(x) == "number" and type(y) == "number", "Line needs explicit relative frame and offsets")
    self.startPoint = {point, relativeTo, x, y}
end
function methods:SetEndPoint(point, relativeTo, x, y)
    assert(type(relativeTo) == "table" and type(x) == "number" and type(y) == "number", "Line needs explicit relative frame and offsets")
    self.endPoint = {point, relativeTo, x, y}
end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:RegisterUnitEvent(event, unit) self.events[event] = unit end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:UnregisterAllEvents() self.events = {} end
function methods:SetScale(value) self.scale = value end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:GetCenter() return 500, 400 end
function methods:SetHeight(value) self.height = value end
function methods:GetStringHeight()
    local _, newlines = (self.text or ""):gsub("\n", "")
    return (newlines + 1) * 14
end
function methods:SetTexture(value) self.texture = value end
function methods:SetText(value) self.text = value end
function methods:HasFocus() return false end
function methods:GetText() return self.text end
function methods:EnableMouse(on) self.mouse = on end
function methods:SetEnabled(on) self.enabled = on end
function methods:SetChecked(on) self.checked = on end
function methods:GetChecked() return self.checked end
function methods:SetColorTexture(r, g, b) self.color = { r, g, b } end
function methods:CreateFontString() return object() end
function methods:CreateLine() error("Native Line rendering must not be used") end
function methods:CreateTexture() return object() end
function methods:SetRotation(angle) assert(type(angle) == "number"); self.rotation = angle end
function methods:CreateAnimationGroup() return object() end
function methods:CreateAnimation() return object() end
function methods:Play() self.playing = true end
function methods:Stop() self.playing = false end
function methods:IsPlaying() return self.playing == true end
function methods:Show() self.shown = true end
function methods:IsShown() return self.shown end
function methods:Hide()
    local shown = self.shown
    self.shown = false
    if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetShown(on) if on then self:Show() else self:Hide() end end
function CreateFrame(_, name)
    local f = object(name)
    f.TitleText = object()
    frames[#frames + 1] = f
    return f
end
UIParent, UISpecialFrames, SlashCmdList = object(), {}, {}
GameTooltip = object()
Minimap = object()
function methods:GetFrameLevel() return 1 end
function methods:GetWidth() return 140 end
function methods:GetHeight() return 140 end
STANDARD_TEXT_FONT = "test-font"
function InCombatLockdown() return combat end
function UnitClass() return "Death Knight", class end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return spec end
function UnitIsDeadOrGhost() return dead end
function GetTime() return 100 end
function issecretvalue(value) return rawequal(value, SECRET) end
C_Secrets = { ShouldSpellAuraBeSecret = function(id) if id == 188290 then return dndRestricted end; assert(id == 195181); return restricted end }
C_UnitAuras = { GetPlayerAuraBySpellID = function(id)
    if id == 188290 then return dndAura end
    assert(id == 195181)
    queries = queries + 1
    if failQuery then error("Restricted API") end
    return aura
end }
Settings = { RegisterCanvasLayoutCategory = function(panel) return panel end, RegisterAddOnCategory = function() end }

local activeKey, bagCounts, bagQueries = false, {}, 0
C_ChallengeMode = { IsChallengeModeActive = function() return activeKey end }
C_Item = { GetItemIconByID = function(id) return id + 100000 end, GetItemCount = function(id, bank, uses, reagent, account)
    assert(not bank and not uses and not reagent and not account, "Only bag stock counts")
    bagQueries = bagQueries + 1
    return bagCounts[id] or 0
end }
C_Timer = { NewTimer = function(_, callback)
    return { callback = callback, Cancel = function(self) self.cancelled = true end }
end }

SOUNDKIT={RAID_WARNING=1,READY_CHECK=2,ALARM_CLOCK_WARNING_3=3,IG_QUEST_LOG_OPEN=4,MAP_PING=5,LEVEL_UP=6}
for _, file in ipairs({ "SettingsHelper.lua", "ModuleSettingsHelper.lua", "TrackerFrameHelper.lua",
    "Modules/BoneShield.lua", "Modules/DeathAndDecay.lua", "Modules/Consumables.lua", "Modules/Beacons.lua", "Modules/AutoHealthPot.lua", "Modules/DemonSpikes.lua", "Modules/FocusAlertInterrupt.lua", "AddonSettingsFrameHelper.lua", "ConsumablesSettingsHelper.lua", "BeaconSettingsHelper.lua", "DemonSpikesSettingsHelper.lua", "FocusInterruptSettingsHelper.lua", "AutoHealthPotSettingsHelper.lua", "MinimapButtonHelper.lua", "SlashikCombatUtils.lua" }) do
    assert(loadfile(file))("SlashikCombatUtils", addon)
end
local startup = frames[#frames]
startup.scripts.OnEvent(startup, "ADDON_LOADED", "AnotherAddon")
assert(SlashikCombatUtilsDB == nil)
startup.scripts.OnEvent(startup, "ADDON_LOADED", "SlashikCombatUtils")
local module = addon.modules.boneShield
assert(module.enabled and module.frame:IsShown())
assert(module.events.events.UNIT_AURA == "player")
local checks = 0
local function state(expected, count, timer)
    local actual, stacks, seconds = module:ReadAura()
    assert(actual == expected, actual .. " ~= " .. expected)
    assert(stacks == count)
    if timer ~= nil then assert(seconds == timer) end
    checks = checks + 1
end
state("missing", 0, "")
for _, count in ipairs({ 1, 4, 5, 6, 10 }) do
    aura = { applications = count, expirationTime = 110.2 }
    state(count >= 5 and "healthy" or "low", count, 11)
end
aura.expirationTime = 99
state("healthy", 10, 0)
aura.expirationTime = SECRET
state("healthy", 10, "")
aura.applications = SECRET
state("unknown", SECRET, "")
module:Update()
assert(rawequal(module.frame.count.text, SECRET), "Secret count must reach SetText unchanged")
aura = SECRET
state("unknown", "?", "")
aura = nil
restricted = true
local before = queries
state("unknown", "?", "")
assert(queries == before, "Restricted query should not run")
local instanceCount, instanceID = SECRET, 42
C_UnitAuras.GetAuraApplicationDisplayCount = function(unit, id, minimum)
    assert(unit == "player" and minimum == 1)
    if not rawequal(id, instanceID) then error("Removed aura") end
    return instanceCount
end
restricted = false
aura = { applications = 6, expirationTime = 111, auraInstanceID = 42 }
state("healthy", 6, 11)
restricted = true
state("unknown", SECRET, "")
module:Update()
assert(rawequal(module.frame.count.text, SECRET) and not module.frame.arcs[1].bounce:IsPlaying())
instanceID = 43
state("unknown", "?", "") -- old aura removed
local item = { cooldownID = 7, auraDataUnit = "player", auraInstanceID = SECRET }
local timerText = SECRET
item.Cooldown = { GetCountdownFontString = function()
    return { GetText = function() return timerText end }
end }
local info = { spellID = 195181 }
BuffIconCooldownViewer = { itemFramePool = { EnumerateActive = function()
    return next, { [item] = true }, nil
end } }
C_CooldownViewer = { GetCooldownViewerCooldownInfo = function(id) assert(id == 7); return info end }
instanceID = SECRET
state("unknown", SECRET, SECRET) -- first applied in combat, secret instance ID
module:Update()
assert(rawequal(module.frame.count.text, SECRET))
assert(rawequal(module.frame.timer.text, SECRET), "Secret countdown must reach SetText unchanged")
addon:GetSettings().boneShield.showTimer = false
module:Update()
assert(module.frame.timer.text == "", "Timer setting must hide secret countdown")
addon:GetSettings().boneShield.showTimer = true
timerText = "22"
module:Update()
assert(module.frame.timer.text == "22")
timerText = "21"
module:Update()
assert(module.frame.timer.text == "21", "Countdown must refresh")
item.Cooldown = nil
item.GetDurationFontString = function() return { GetText = function() return SECRET end } end
module:Update()
assert(rawequal(module.frame.timer.text, SECRET), "Buff bar countdown must also work")
item.GetDurationFontString = nil
module:Update()
assert(module.frame.timer.text == "", "Missing source must clear previous countdown")
local displayCount = SECRET
item.GetApplicationsFontString = function()
    return { GetText = function() return displayCount end }
end
C_UnitAuras.GetAuraApplicationDisplayCount = function() error("Instance query forbidden in combat") end
state("unknown", SECRET, "")
module:Update()
assert(rawequal(module.frame.count.text, SECRET), "Mirror native stack text when instance API fails")
assert(module.countSource == "Blizzard stack text")
displayCount = "3"
state("unknown", "3", "")
displayCount = "4"
state("unknown", "4", "") -- label must update, not retain gain-time count
item.auraDataUnit = SECRET
info.selfAura = true
state("unknown", "4", "")
info.selfAura = false
state("unknown", "?", "")
item.auraDataUnit = "player"
displayCount = ""
item.auraDataCached = { applications = 1 }
state("unknown", 1, "")
item.auraDataCached = nil
state("unknown", "?", "")
displayCount = SECRET
info = { spellID = 123 }
state("unknown", "?", "") -- recycled viewer frame must not supply another buff
info = { spellID = SECRET }
state("unknown", "?", "")
info = { spellID = 195181 }
item.auraDataUnit = "target"
state("unknown", "?", "")
BuffIconCooldownViewer, C_CooldownViewer = nil, nil
module.knownInstanceID = nil
C_UnitAuras.GetAuraApplicationDisplayCount = nil
aura = nil
restricted, failQuery = false, true
state("unknown", "?", "")
failQuery = false
module:Update()
assert(module.frame.arcs[1].bounce:IsPlaying())
aura = { applications = 5, expirationTime = 111 }
module:Update()
assert(not module.frame.arcs[1].bounce:IsPlaying())
assert(module.frame.count.text == 5 and module.frame.timer.text == 11)
restricted = true
module:Update()
assert(module.frame.count.text == "?" and not module.frame.arcs[1].bounce:IsPlaying())
restricted = false
spec = 251
module:Update()
assert(not module.frame:IsShown())
module:StartPreview("missing")
assert(module.preview == nil and not module.frame:IsShown(), "Frost cannot preview")
spec = 250
module:StartPreview("missing")
assert(module.preview == "missing")
spec = 252
module:Update()
assert(module.preview == nil and not module.frame:IsShown(), "Spec change ends preview")
spec, class = 250, "MAGE"
module:StartPreview("healthy")
module:Update()
assert(module.preview == nil and not module.frame:IsShown(), "Other classes cannot preview")
class = "DEATHKNIGHT"
spec, dead = 250, true
module:Update()
assert(not module.frame:IsShown())
dead = false
local settings = addon:GetSettings().boneShield
settings.combatOnly = true
module:Update()
assert(not module.frame:IsShown())
combat = true
module:Update()
assert(module.frame:IsShown())
assert(addon:SetModuleEnabled("boneShield", false) == false)
assert(module.enabled)
combat = false
settings.combatOnly = false
addon:ShowSettings()
for _, name in ipairs({ "healthy", "low", "missing" }) do
    module:StartPreview(name)
    assert(module.preview == name and module.frame:IsShown())
    assert(module.frame.arcs[1].bounce:IsPlaying() == (name == "missing"))
end
combat = true
module.events.scripts.OnEvent(module.events, "PLAYER_REGEN_DISABLED")
assert(module.preview == nil and not module.frame.mouse)
combat = false
module:StartPreview("missing")
SlashikCombatUtilsSettingsFrame:Hide()
assert(module.preview == nil)
module:StartPreview("missing")
addon:SetModuleEnabled("boneShield", false)
assert(module.preview == nil and not module.enabled and not module.frame:IsShown())
assert(next(module.events.events) == nil and module.events.scripts.OnUpdate == nil)
assert(not module.frame.arcs[1].bounce:IsPlaying())
module:StopPreview()
assert(not module.frame:IsShown(), "Closing settings must not revive a disabled tracker")
settings.scale = 1.5
addon:SetModuleEnabled("boneShield", true)
assert(module.enabled and module.frame.scale == 1.5)
settings.scale, settings.x = 0 / 0, math.huge
addon:GetSettings()
assert(settings.scale == 1 and settings.x == 0)
SlashCmdList.SLASHIKCOMBATUTILS()
assert(SlashikCombatUtilsSettingsFrame:IsShown())
-- Exercise actual bounce callbacks across the peak and loop boundary.
local curve = module.frame.arcs[1]
curve.SetPoint = function(self, _, _, _, _, y) self.testOffset = y end
module.frame:Render("missing", 0, "", true)
local previous = 0
for tick = 1, 1120 do
    curve.scripts.OnUpdate(curve, 0.001)
    local offset = curve.testOffset
    assert(offset >= 0 and offset <= 13, "Bounce must stay within its travel range")
    assert(math.abs(offset - previous) < 0.074, "Bounce must not jump at turning points")
    if tick == 280 then assert(math.abs(offset - 13) < 0.00001) end
    if tick == 560 then assert(math.abs(offset) < 0.00001) end
    previous = offset
end
module.frame:Render("healthy", 6, "11", true)
assert(curve.scripts.OnUpdate == nil and curve.testOffset == 0, "Stopping must restore the anchor")
-- Right-side timer is independent of Bone Shield and never a spell cooldown.
dndAura = { expirationTime = 108.2 }
assert(module:ReadDeathAndDecayTimer() == 9)
module:StopPreview()
module:Update()
assert(module.frame.rightTimer.text == 9)
dndAura = nil
module:Update()
assert(module.frame.rightTimer.text == "")
dndRestricted = true
local dndInfo = { spellID = 43265, linkedSpellIDs = {188290}, selfAura = true }
local dndText = SECRET
local dndItem = { cooldownID = 8, auraDataUnit = SECRET,
    Cooldown = { GetCountdownFontString = function()
        return { GetText = function() return dndText end }
    end } }
BuffIconCooldownViewer = { itemFramePool = { EnumerateActive = function()
    return next, { [dndItem] = true }, nil
end } }
C_CooldownViewer = { GetCooldownViewerCooldownInfo = function() return dndInfo end }
assert(rawequal(module:ReadDeathAndDecayTimer(), SECRET))
module:Update()
assert(rawequal(module.frame.rightTimer.text, SECRET))
addon:GetSettings().boneShield.showDeathAndDecay = false
module:Update()
assert(module.frame.rightTimer.text == "")
addon:GetSettings().boneShield.showDeathAndDecay = true
dndInfo = { spellID = 195181 }
assert(module:ReadDeathAndDecayTimer() == "", "Do not mirror Bone Shield on the right")
dndInfo = { spellID = 188290 }
dndItem.auraDataUnit = "target"
assert(module:ReadDeathAndDecayTimer() == "", "Do not track target buffs")
BuffIconCooldownViewer = nil
assert(module:ReadDeathAndDecayTimer() == "", "No source must clear the timer")
local settingsWindow = SlashikCombatUtilsSettingsFrame
addon:RegisterModule("testModule", { title = "Test module", description = "Test settings page", Enable = function() end, Disable = function() end })
local builds = 0
addon:RegisterModuleSettings("testModule", function(panel) builds = builds + 1; panel.testBuilt = true end)
module:StartPreview("healthy")
addon:SelectSettingsModule("testModule")
assert(module.preview == nil, "Switching pages ends previous preview")
assert(settingsWindow.pages.testModule:IsShown() and not settingsWindow.pages.boneShield:IsShown())
assert(settingsWindow.pages.testModule.testBuilt)
addon:SelectSettingsModule("boneShield")
assert(settingsWindow.pages.boneShield:IsShown() and not settingsWindow.pages.testModule:IsShown())
addon:SelectSettingsModule("testModule")
assert(builds == 1, "Reuse page controls")
addon:SelectSettingsModule("boneShield")
addon:SetModuleEnabled("boneShield", false)
settingsWindow.rows.boneShield.scripts.OnClick()
assert(not addon:IsModuleEnabled("boneShield"), "Selection must not enable the module")
assert(settingsWindow.pages.boneShield:IsShown(), "Disabled settings remain inspectable")
addon:SetModuleEnabled("boneShield", true)
print("PASS: " .. checks .. " aura cases; startup, lifecycle, visibility, previews, animation, settings and secret guards")


-- Consumables: categories are OR groups and empty categories are ignored.
combat = false
local consumables = addon.modules.consumables
assert(not consumables.enabled and not consumables.timer, "Consumables must start disabled")
assert(not addon:IsModuleEnabled("consumables"))
addon:SetModuleEnabled("consumables", true)
assert(addon:GetSettings().modules.consumables == true, "Saved opt-in survives defaults")
assert(consumables.enabled)
local function flush()
    local timer = consumables.timer
    if timer and not timer.cancelled then timer.callback() end
end
flush()
assert(not consumables.warning)
consumables:SetSelected(241321, true)
consumables:SetSelected(241324, true)
consumables:SetSelected(241304, true)
flush()
assert(consumables.warning:IsShown())
local missing = consumables:GetMissing()
assert(#missing == 2 and #missing[1].choices == 2)
assert(consumables.warning.text.text:find("Silvermoon Health Potion", 1, true))
bagCounts[241326] = 5
assert(#consumables:GetMissing() == 2, "Unselected flasks must not satisfy selection")
bagCounts[241324] = 1
missing = consumables:GetMissing()
assert(#missing == 1 and missing[1].title == "Health Potions")
bagCounts[241304] = 2
consumables:Check()
assert(not consumables.warning:IsShown())
bagCounts[241304] = nil
consumables:OnEvent("BAG_UPDATE_DELAYED"); flush()
assert(consumables.warning:IsShown())
consumables.warning:Hide()
consumables:OnEvent("BAG_UPDATE_DELAYED"); flush()
assert(not consumables.warning:IsShown(), "Dismissed list must not spam on every bag event")
consumables:Check(true)
assert(consumables.warning:IsShown(), "Manual check reopens dismissed reminder")
consumables:Schedule()
local pending = consumables.timer
local before = bagQueries
combat = true
consumables:OnEvent("PLAYER_REGEN_DISABLED")
assert(pending.cancelled and not consumables.warning:IsShown())
consumables:Check(true)
assert(bagQueries == before, "No bag reads in combat")
combat = false
consumables:OnEvent("PLAYER_REGEN_ENABLED"); flush()
-- Start event protects the countdown even before the API reports an active key.
consumables:OnEvent("CHALLENGE_MODE_START")
before = bagQueries
consumables:Check(true)
consumables:OnEvent("BAG_UPDATE_DELAYED"); flush()
consumables:OnEvent("PLAYER_REGEN_ENABLED"); flush()
assert(bagQueries == before and not consumables.warning:IsShown())
activeKey = true
consumables:OnEvent("PLAYER_ENTERING_WORLD"); flush()
consumables:Check(true)
assert(bagQueries == before, "Reload/zone inside an active key stays suppressed")
consumables:Disable(); consumables:Enable(); flush()
assert(bagQueries == before, "Enabling inside a key stays suppressed")
activeKey = false
before = bagQueries
consumables:OnEvent("CHALLENGE_MODE_COMPLETED"); flush()
assert(bagQueries == before and not consumables.warning:IsShown(), "Key completion does not check")
consumables:OnEvent("READY_CHECK"); flush()
consumables:OnEvent("PLAYER_REGEN_ENABLED"); flush()
assert(bagQueries == before, "Ready checks and combat end do not check")
assert(not consumables.events.events.READY_CHECK and not consumables.events.events.PLAYER_REGEN_ENABLED)
consumables:OnEvent("BAG_UPDATE_DELAYED"); flush()
assert(consumables.warning:IsShown(), "Bag updates still check after a key")
consumables:OnEvent("CHALLENGE_MODE_START")
before = bagQueries
consumables:OnEvent("CHALLENGE_MODE_RESET"); flush()
assert(not consumables:IsSuppressed())
assert(bagQueries == before and not consumables.warning:IsShown(), "Key reset does not check")
bagCounts[241304] = SECRET
consumables:Check()
assert(not consumables.warning:IsShown(), "Unknown stock must not become a false missing alert")
bagCounts[241304] = nil
consumables:Schedule()
pending = consumables.timer
addon:SetModuleEnabled("consumables", false)
assert(pending.cancelled and not next(consumables.events.events))
before = bagQueries
pending.callback()
assert(bagQueries == before and not consumables.warning:IsShown())
assert(consumables:GetSelections()[241304], "Disabling preserves selections")
addon:SelectSettingsModule("consumables")
assert(settingsWindow.pages.consumables:IsShown())
assert(not settingsWindow.pages.boneShield:IsShown())
local itemChecks = 0
for _, frame in ipairs(frames) do
    if frame.module == "consumables" and frame.read then
        itemChecks = itemChecks + 1
        assert(not frame.enabled, "Disabled module controls are dimmed and disabled")
    end
end
assert(itemChecks == 11)
addon:SetModuleEnabled("consumables", true)
consumables:SetSelected(241308, true)
consumables:SetSelected(241288, true)
bagCounts[241288], bagCounts[241304] = 1, 1
assert(#consumables:GetMissing() == 0, "Any selected battle potion satisfies its category")
consumables:SetSelected(241304, false)
bagCounts[241304] = nil
assert(#consumables:GetMissing() == 0, "Deselected category is ignored")
print("PASS: consumables selection, bags-only counts, dismissal, combat/key suppression, lifecycle and settings")

consumables:SetSelected(243734, true)
consumables:SetSelected(243738, true)
consumables:SetSelected(242275, true)
consumables:SetSelected(255847, true)
missing = consumables:GetMissing()
assert(#missing == 2 and missing[1].title == "Enchanting" and missing[2].title == "Food")
bagCounts[243738] = 1
missing = consumables:GetMissing()
assert(#missing == 1 and missing[1].title == "Food")
bagCounts[255847] = 1
assert(#consumables:GetMissing() == 0)
bagCounts[243738], bagCounts[255847] = nil, nil
bagCounts[243734], bagCounts[242275] = 1, 1
assert(#consumables:GetMissing() == 0, "Either selected oil or food satisfies its own category")
print("PASS: Enchanting and Food alternatives")

-- Exact quality variants from the player's bag screenshots.
SlashikCombatUtilsCharDB.settings.consumables.selected = {
    [241322] = true, [241308] = true, [243734] = true,
}
bagCounts = {}
assert(#consumables:GetMissing() == 3)
consumables:Check(true)
assert(consumables.warning:IsShown())
bagCounts = { [241323] = 3, [241309] = 27, [243733] = 38 }
consumables:OnEvent("BAG_UPDATE_DELAYED"); flush()
assert(#consumables:GetMissing() == 0 and not consumables.warning:IsShown(), "Owned quality variants clear warning")
bagCounts[241323] = nil
missing = consumables:GetMissing()
assert(#missing == 1 and missing[1].title == "Flasks")
bagCounts = { [241322] = 1, [241308] = 1, [243734] = 1 }
assert(#consumables:GetMissing() == 0, "Original quality IDs remain supported")
print("PASS: screenshot quality variants and existing saved selections")

-- Each ranked consumable accepts either quality independently under one saved checkbox.
local ranked = 0
for _, group in ipairs(consumables.groups) do
    for _, item in ipairs(group.items) do
        if item.variants then
            ranked = ranked + 1
            assert(#item.variants == 2)
            SlashikCombatUtilsCharDB.settings.consumables.selected = { [item.id] = true }
            bagCounts = {}
            assert(#consumables:GetMissing() == 1)
            for _, variant in ipairs(item.variants) do
                bagCounts = { [variant] = 1 }
                assert(#consumables:GetMissing() == 0, "Quality variant missing: " .. variant)
            end
        end
    end
end
assert(ranked == 9, "All flasks, potions and weapon consumables have both qualities")
print("PASS: both quality variants for all nine ranked consumables")

SlashikCombatUtilsCharDB.settings.consumables.selected = { [241308] = true }
assert(consumables:GetMinimum(241308) == 1)
consumables:SetMinimum(241308, "20")
bagCounts = { [241308] = 9, [241309] = 10 }
assert(#consumables:GetMissing() == 1)
bagCounts[241309] = 11
assert(#consumables:GetMissing() == 0, "Combine qualities at the exact minimum")
consumables:SetMinimum(241308, "21")
assert(consumables:GetMissing()[1].choices[1]:find("minimum 21", 1, true))
for _, invalid in ipairs({ "", "abc", 0, -1, 1.5, 10000 }) do
    consumables:SetMinimum(241308, invalid)
    assert(consumables:GetMinimum(241308) == 21)
end
consumables:SetSelected(241288, true)
consumables:SetMinimum(241288, 5)
bagCounts = { [241308] = 20, [241288] = 4 }
assert(#consumables:GetMissing() == 1, "Different items cannot pool quantities")
bagCounts[241288] = 5
assert(#consumables:GetMissing() == 0, "Any selected item meeting its minimum suffices")
combat = true
consumables:SetMinimum(241288, 10)
assert(consumables:GetMinimum(241288) == 5)
combat = false
local boxes = 0
for _, frame in ipairs(frames) do
    if frame.module == "consumables" and frame.itemID then
        boxes = boxes + 1
        if frame.itemID == 241308 then
            frame:SetText("30")
            frame.scripts.OnEnterPressed(frame)
            assert(consumables:GetMinimum(241308) == 30)
            frame:SetText("0")
            frame.scripts.OnEditFocusLost(frame)
            assert(frame:GetText() == "30")
        end
    end
end
assert(boxes == 11)
consumables:Disable(); consumables:Enable()
assert(consumables:GetMinimum(241308) == 30, "Minimums persist through module toggles")
print("PASS: per-item minimums, mixed qualities, validation, combat guard and quantity controls")

local selectedPage = settingsWindow.selectedModule
local enabledBefore = addon:IsModuleEnabled("consumables")
settingsWindow.rows.consumables.up.scripts.OnClick()
assert(addon:GetModuleDisplayOrder()[1] == "consumables")
assert(addon:GetSettings().moduleOrder[1] == "consumables", "Order is saved")
assert(not settingsWindow.rows.consumables.up.enabled)
assert(settingsWindow.selectedModule == selectedPage)
assert(addon:IsModuleEnabled("consumables") == enabledBefore)
combat = true
addon:MoveModule("consumables", 1)
assert(addon:GetModuleDisplayOrder()[1] == "consumables")
combat = false
settingsWindow.rows.consumables.down.scripts.OnClick()
assert(addon:GetModuleDisplayOrder()[1] == "boneShield")
addon:GetSettings().moduleOrder = { "unknown", "consumables", "consumables" }
local cleanOrder = addon:GetModuleDisplayOrder()
assert(cleanOrder[1] == "consumables" and cleanOrder[2] == "boneShield" and #cleanOrder == 7)
assert(addon.moduleOrder[1] == "boneShield", "Display ordering does not change startup order")
print("PASS: saved module ordering, arrows, boundaries, stale entries and combat guard")

local modified, clicked, searched, inspected = false, nil, nil, nil
function IsModifiedClick() return modified end
function HandleModifiedItemClick(text) clicked = text end
function SetItemRef(link) inspected = link end
C_Item.GetItemNameByID = function() return "Localized potion name" end
AuctionHouseFrame = {
    IsShown = function() return true end,
    SetSearchText = function(_, text) searched = text; return true end,
}
local linkText = "|Hitem:241308|h[Light's Potential]|h"
consumables:ClickItem("item:241308", linkText, "LeftButton")
assert(searched == "Localized potion name" and not inspected)
modified = true
consumables:ClickItem("item:241308", linkText, "LeftButton")
assert(clicked == linkText)
modified = false
AuctionHouseFrame = nil
consumables:ClickItem("item:241308", linkText, "LeftButton")
assert(inspected == "item:241308")
print("PASS: item links fill native Auction House search, forward modified clicks and open item tooltips")

for _, frame in ipairs(frames) do
    if frame.events.PLAYER_LOGIN then frame.scripts.OnEvent(frame, "PLAYER_LOGIN") end
end
local minimapButton = SlashikCombatUtilsMinimapButton
assert(minimapButton, "Minimap button is created on login")
local previousShow, opened = addon.ShowSettings, 0
addon.ShowSettings = function() opened = opened + 1 end
minimapButton.scripts.OnClick(minimapButton, "LeftButton")
assert(opened == 1, "Left-click opens settings")
addon.ShowSettings = previousShow
minimapButton.scripts.OnDragStart(minimapButton)
assert(minimapButton.scripts.OnUpdate)
minimapButton.scripts.OnDragStop(minimapButton)
assert(not minimapButton.scripts.OnUpdate)
print("PASS: minimap button login, settings click and drag cleanup")

local beacon = addon.modules.beacons
class, spec, dead, combat = "PALADIN", 65, false, false
local talented, grouped, raid, restrictedBeacon = true, true, false, false
local visible, deaths, own = {}, {}, {}
C_SpellBook = { IsSpellKnown = function(id) assert(id == 156910); return talented end }
C_Spell = { GetSpellName = function(id) return tostring(id) end, GetSpellTexture = function(id) return id end }
C_Secrets.ShouldSpellAuraBeSecret = function() return restrictedBeacon end
function IsInGroup() return grouped end
function IsInRaid() return raid end
function GetNumGroupMembers() return 2 end
function GetNumSubgroupMembers() return 1 end
function UnitIsConnected() return true end
function UnitIsVisible(unit) return visible[unit] ~= false end
function UnitIsDeadOrGhost(unit) return deaths[unit] or false end
function UnitIsUnit(a, b) return a == b end
C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
    assert(filter == "HELPFUL")
    if restrictedBeacon then return SECRET end
    local auras = {}
    for _, spellID in ipairs({53563, 156910}) do
        local value = own[unit .. spellID]
        if rawequal(value, SECRET) then return SECRET end
        if value then auras[#auras + 1] = { spellId = spellID, name = tostring(spellID), sourceUnit = "player" } end
    end
    return auras[index]
end
beacon:Update()
assert(beacon.frame:IsShown() and beacon.icons[1]:IsShown() and beacon.icons[2]:IsShown())
own.party153563, own.player156910 = {}, {}
beacon:Update()
assert(not beacon.frame:IsShown())
deaths.party1 = true
beacon:Update()
assert(beacon.icons[1]:IsShown() and not beacon.icons[2]:IsShown(), "Death removes coverage")
deaths.party1 = false
own.party153563 = nil
combat = true
beacon:Update()
assert(beacon.icons[1]:IsShown(), "Readable combat auras can trigger warnings")
restrictedBeacon = true
beacon:Update()
assert(not beacon.frame:IsShown() and beacon.status[1] == "unknown")
restrictedBeacon = false
own.party153563 = SECRET
beacon:Update()
assert(beacon.status[1] == "unknown" and not beacon.icons[1]:IsShown())
own.party153563 = nil
visible.party1 = false
beacon:Update()
assert(beacon.status[1] == "missing" and beacon.icons[1]:IsShown(), "Invisible members must not suppress local warning")
visible.party1 = true
combat = false
raid = true
own = { raid153563 = {}, raid2156910 = {} }
beacon:Update()
assert(not beacon.frame:IsShown(), "Raid unit tokens are supported")
talented = false
beacon:Update()
assert(beacon.status[1] == "inactive")
talented = true
grouped = false
beacon:Update()
assert(not beacon.frame:IsShown())
beacon:StartPreview()
assert(beacon.frame:IsShown())
combat = true
beacon:Update()
assert(not beacon.preview and not beacon.frame:IsShown())
combat = false
addon:SelectSettingsModule("beacons")
assert(settingsWindow.pages.beacons:IsShown())
beacon:Disable()
assert(not next(beacon.events.events) and not beacon.events.scripts.OnUpdate)
print("PASS: beacon ownership filter, death, party/raid, talent gate, combat, secret guards, preview and settings")

beacon.enabled = true
grouped, raid, talented, combat = true, false, true, false
local originalIndex = C_UnitAuras.GetAuraDataByIndex
C_Secrets.ShouldSpellAuraBeSecret = function() return true end
own = {}
beacon:Update()
assert(beacon.status[1] == "missing", "Potential secrecy must not block a readable dungeon scan")
C_UnitAuras.GetAuraDataByIndex = function(unit, index)
    if index == 1 then return {spellId = 53563, sourceUnit = "party1"} end
    if index == 2 then return {spellId = 53563, sourceUnit = "player"} end
end
assert(beacon:Scan(53563) == "present", "Find own beacon after another paladin's")
C_UnitAuras.GetAuraDataByIndex = function(unit, index)
    if index == 1 then return {spellId = 53563, sourceUnit = "party1"} end
end
assert(beacon:Scan(53563) == "missing", "Another paladin's beacon does not count")
C_UnitAuras.GetAuraDataByIndex = function(unit, index)
    if index == 1 then return {spellId = SECRET, name = "53563", sourceUnit = "player"} end
end
assert(beacon:Scan(53563) == "present", "Readable name can identify a beacon")
C_UnitAuras.GetAuraDataByIndex = function(unit, index)
    if index == 1 then return {spellId = 53563, sourceUnit = SECRET} end
end
assert(beacon:Scan(53563) == "unknown", "Restricted ownership cannot prove missing")
C_UnitAuras.GetAuraDataByIndex = function() error("restricted") end
assert(beacon:Scan(53563) == "unknown")
print("PASS: indexed beacon scanning, potential secrecy, other casters and readable-name fallback")

C_UnitAuras.GetAuraDataByIndex = function() return nil end
visible.party1 = false
assert(beacon:Scan(53563) == "missing")
local visibleAPI = UnitIsVisible
function UnitIsVisible(unit) if unit == "party1" then return nil end; return true end
assert(beacon:Scan(53563) == "missing", "Nil visibility means out of view")
function UnitIsVisible() return false end
assert(beacon:Scan(53563) == "unknown", "No checked members is not proof of missing")
function UnitIsVisible(unit) if unit == "party1" then return SECRET end; return true end
assert(beacon:Scan(53563) == "unknown", "Secret visibility remains unknown")
UnitIsVisible = visibleAPI
visible.party1 = true
local connectionAPI = UnitIsConnected
function UnitIsConnected(unit) return unit ~= "party1" end
assert(beacon:Scan(53563) == "missing", "Offline members are skipped")
UnitIsConnected = connectionAPI
print("PASS: out-of-view/offline members skipped; secret visibility and empty coverage guarded")

local health=addon.modules.autoHealthPot
assert(not health.enabled)
combat=false
local macroBody, writes, exists = nil, 0, false
function UnitGUID() return "test-player" end
function GetMacroIndexByName() return exists and 121 or 0 end
function GetMacroInfo() return "SCU Health Pot", 134400, macroBody end
function GetNumMacros() return 0, 0 end
function CreateMacro(name, icon, body, character)
    assert(not combat and character and name == "SCU Health Pot")
    macroBody=body; exists=true; writes=writes+1; return 121
end
function EditMacro(index,name,icon,body)
    assert(not combat and index == 121); macroBody=body; writes=writes+1; return index
end
C_Item.GetItemCount=function(id,bank,uses,reagent,account)
    assert(not bank and uses and not reagent and not account)
    return bagCounts[id] or 0
end
bagCounts={ [5512]=3, [271883]=5, [241304]=5, [258138]=5 }
addon:SetModuleEnabled("autoHealthPot",true)
health:Update()
assert(macroBody == "#showtooltip\n/stopcasting\n/castsequence [@player] reset=combat/60 item:5512, item:271883")
local previousWrites=writes
health:Update(); assert(writes == previousWrites, "Do not rewrite unchanged macros")
bagCounts[271884]=1; health:Update()
assert(macroBody:find("item:271884",1,true) and not macroBody:find("item:271883",1,true))
health:Move(271884,-1); health:Update()
assert(macroBody:find("item:271884, item:5512",1,true))
health:Settings().selected[271884]=false; health:Update()
assert(macroBody:find("item:241304",1,true))
combat=true; previousWrites=writes
bagCounts={ [258138]=1 }; health:Request()
assert(health.pending and writes == previousWrites)
combat=false; health.events.scripts.OnEvent(); health.timer.callback()
assert(macroBody:find("item:258138",1,true) and not macroBody:find("5512",1,true))
bagCounts={}; health:Update(); assert(macroBody == "#showtooltip")
macroBody="user edited macro"; health:Update()
assert(macroBody == "user edited macro", "Never overwrite manually edited macros")
exists=false
function GetNumMacros() return 0,18 end
previousWrites=writes; health:Update(); assert(writes == previousWrites)
addon:SelectSettingsModule("autoHealthPot")
assert(settingsWindow.pages.autoHealthPot:IsShown())
health:Request(); local timer=health.timer
health:Disable(); assert(timer.cancelled and not next(health.events.events))
timer.callback(); assert(writes == previousWrites)
print("PASS: auto health pot ordering, qualities, one potion, combat deferral, ownership, slots and lifecycle")

health:Settings().order={5512,271884,241305,258138}
health:Settings().selected={}
assert(health:Order()[1].id == 224464, "New stone becomes first in existing saved priorities")
bagCounts={ [224464]=3, [271884]=2 }
assert(health:Build():find("item:224464, item:271884",1,true))
health:Settings().selected[224464]=false
assert(not health:Build():find("224464",1,true))
health:Settings().selected[224464]=true
health.enabled=true
health:Move(224464,1)
assert(health:Order()[1].id == 5512 and health:Order()[2].id == 224464, "User can change new default priority")
print("PASS: Demonic Healthstone priority migration, sequence and checkbox")

-- Simulate reload text normalization while keeping the persisted ownership record.
exists=true
health:Settings().order={224464,5512,271884,241305,258138}
local oldBody="#showtooltip\n/stopcasting\n/castsequence [@player] reset=combat item:258138"
health:Settings().ownedBodies["test-player"]=oldBody
macroBody=oldBody:gsub("\n", "\r\n") .. "\r\n"
bagCounts={ [224464]=3, [258138]=67 }
local rawEdit=EditMacro
function EditMacro(index,name,icon,body)
    local result=rawEdit(index,name,icon,body)
    macroBody=macroBody .. "\n"
    return result
end
health:Update()
assert(macroBody:find("item:224464, item:258138",1,true), "Reload updates the owned potion macro with Demonic Healthstone")
assert(health.message:find("Macro ready",1,true), "Readback accepts the client's final newline")
previousWrites=writes
health:Update()
assert(writes == previousWrites, "Normalized text does not cause repeated edits")
macroBody=macroBody .. "/say manual change"
health:Update()
assert(writes == previousWrites, "Real command edits still prevent automatic replacement")
print("PASS: reloaded macro line endings, Demonic Healthstone update, readback and manual edit protection")

-- Existing ownership records keep the previous combat-only body during migration.
macroBody=oldBody
health:Settings().ownedBodies["test-player"]=oldBody
health:Update()
assert(macroBody:find("reset=combat/60 item:224464, item:258138",1,true), "Existing macro gains inactivity fallback without losing item order")
assert(health.message:find("Macro ready",1,true))
print("PASS: combat-only macro migrates to combat plus inactivity reset")

-- Simulate switching characters by loading separate per-character SavedVariables.
local legacy = {
    modules={consumables=true, autoHealthPot=true, beacons=false},
    consumables={selected={[241308]=true}, minimums={[241308]=12}},
    autoHealthPot={order={224464,258138}, selected={[5512]=false}, ownedBodies={ ["test-player"]=oldBody }},
    boneShield={x=42,y=80,scale=1.2}, beacons={x=100,bounce=false},
    moduleOrder={"autoHealthPot","consumables"}, minimapAngle=2,
}
SlashikCombatUtilsDB={settings=legacy}
SlashikCombatUtilsCharDB=nil
local first=addon:GetSettings()
local firstDB=SlashikCombatUtilsCharDB
assert(first ~= legacy and first.consumables ~= legacy.consumables)
assert(first.consumables.minimums[241308] == 12 and first.boneShield.x == 42)
assert(first.autoHealthPot.ownedBodies["test-player"] == oldBody)
first.modules.consumables=false
first.consumables.minimums[241308]=40
first.autoHealthPot.order[1]=258138
first.boneShield.x=-50
first.moduleOrder[1]="beacons"
first.minimapAngle=3
SlashikCombatUtilsCharDB=nil
local second=addon:GetSettings()
assert(second.modules.consumables and second.consumables.minimums[241308] == 12)
assert(second.autoHealthPot.order[1] == 224464 and second.boneShield.x == 42)
assert(second.moduleOrder[1] == "autoHealthPot" and second.minimapAngle == 2)
second.modules.beacons=true
assert(not first.modules.beacons and not legacy.modules.beacons)
SlashikCombatUtilsCharDB=firstDB
assert(addon:GetSettings() == first and first.consumables.minimums[241308] == 40, "Reload never migrates twice")
SlashikCombatUtilsDB=nil
SlashikCombatUtilsCharDB=nil
local fresh=addon:GetSettings()
assert(fresh.modules.consumables == false and fresh.modules.autoHealthPot == false)
assert(fresh.boneShield.x == 0)
print("PASS: per-character migration, nested isolation, reload persistence, macro ownership and fresh defaults")

function UnitIsDeadOrGhost() return dead end
local spikes=addon.modules.demonSpikes
class,spec,dead,combat="DEMONHUNTER",581,false,false
local spikesAura, spikesRestricted, furyValue, soulsValue = nil,false,75,4
C_Secrets.ShouldSpellAuraBeSecret=function(id) assert(id==203819); return spikesRestricted end
C_UnitAuras.GetPlayerAuraBySpellID=function(id) assert(id==203819); return spikesAura end
function UnitPower(unit,power) assert(unit=="player" and power==17); return furyValue end
C_Spell.GetSpellCastCount=function(id) assert(id==228477); return soulsValue end
BuffIconCooldownViewer=nil; BuffBarCooldownViewer=nil
assert(not addon:IsModuleEnabled("demonSpikes"), "New tracker defaults off")
assert(not addon:IsModuleEnabled("testModule"), "Unconfigured future modules default off")
addon:SetModuleEnabled("demonSpikes", true)
assert(addon:GetSettings().modules.demonSpikes == true, "Explicit enable persists")
assert(spikes.frame:IsShown() and spikes.frame.count.text==0)
assert(spikes.frame.timer.text==75 and spikes.frame.rightTimer.text==4)
assert(spikes.frame.arcs[1].bounce:IsPlaying())
spikesAura={expirationTime=108.2}; spikes:Update()
assert(spikes.frame.count.text==9 and not spikes.frame.arcs[1].bounce:IsPlaying())
assert(spikes.frame.arcs[1].lines[1].color[2]==1)
spikesAura=nil; addon:GetSettings().demonSpikes.bounce=false; spikes:Update()
assert(not spikes.frame.arcs[1].bounce:IsPlaying())
addon:GetSettings().demonSpikes.bounce=true
combat=true; spikesRestricted=true; furyValue=SECRET; soulsValue=SECRET
spikes:Update()
assert(rawequal(spikes.frame.timer.text,SECRET) and rawequal(spikes.frame.rightTimer.text,SECRET))
assert(not spikes.frame.arcs[1].bounce:IsPlaying(), "Restricted aura cannot trigger false missing warning")
local viewerItem={cooldownID=99,auraDataUnit="player", GetDurationFontString=function() return {GetText=function() return SECRET end} end}
BuffIconCooldownViewer={itemFramePool={EnumerateActive=function() local done=false; return function() if not done then done=true; return viewerItem end end end}}
C_CooldownViewer={GetCooldownViewerCooldownInfo=function() return {spellID=203819} end}
spikes:Update(); assert(rawequal(spikes.frame.count.text,SECRET), "Opaque countdown reaches center text")
C_CooldownViewer.GetCooldownViewerCooldownInfo=function() return {spellID=999} end
spikes:Update(); assert(spikes.frame.count.text=="", "Ignore recycled viewer entry")
spikesRestricted=false; spikesAura={expirationTime=SECRET}
spikes:Update(); assert(spikes.frame.arcs[1].lines[1].color[2]==1)
combat=false; spikesAura=nil; furyValue=0; soulsValue=0
addon:GetSettings().demonSpikes.combatOnly=true; spikes:Update(); assert(not spikes.frame:IsShown())
spikes:StartPreview("missing"); assert(spikes.frame:IsShown() and spikes.frame.arcs[1].bounce:IsPlaying())
combat=true; spikes.events.scripts.OnEvent(nil,"PLAYER_REGEN_DISABLED"); assert(not spikes.preview)
combat=false; addon:GetSettings().demonSpikes.combatOnly=false
spikes:StartPreview("healthy"); spec=577; spikes:Update(); assert(not spikes.preview and not spikes.frame:IsShown())
spec=581; dead=true; spikes:Update(); assert(not spikes.frame:IsShown())
dead=false; class="DEATHKNIGHT"; spikes:Update(); assert(not spikes.frame:IsShown())
class="DEMONHUNTER"; spikes:Update(); assert(spikes.frame:IsShown())
addon:SelectSettingsModule("demonSpikes"); assert(settingsWindow.pages.demonSpikes:IsShown())
spikes:Disable(); assert(not spikes.frame:IsShown() and not next(spikes.events.events) and not spikes.events.scripts.OnUpdate)
print("PASS: Vengeance gate, Fury/souls, buff duration, colors/bounce, secret display, viewer recycling, previews and lifecycle")

local focus=addon.modules.focusInterrupt
focus:Disable()
assert(addon:IsModuleEnabled("focusInterrupt"))
assert(addon:GetSettings().focusInterrupt.ttsMode==false)
assert(addon:GetSettings().focusInterrupt.soundName=="Auction Window Close")
addon:GetSettings().focusInterrupt.ttsMode=true
class,spec,combat="DEATHKNIGHT",250,false
local now, enemy, cast, immune, spoken, sounded=100,true,nil,false,0,0
function GetTime() return now end
function UnitCanAttack() return enemy end
function UnitCastingInfo() return cast,nil,nil,nil,nil,nil,nil,immune end
function UnitChannelInfo() return nil end
function IsPlayerSpell(id) return id==47528 end
function IsSpellKnown() return false end
function GetSpellBaseCooldown() return 15000 end
C_Spell.GetSpellCooldown=function() return {startTime=0,duration=0} end
C_ClassTalents=nil; C_Traits=nil
Enum=Enum or {}; Enum.TtsVoiceType={Standard=0}
C_TTSSettings={GetVoiceOptionID=function() return 0 end}
C_VoiceChat={SpeakText=function(_,message) assert(message=="Interrupt"); spoken=spoken+1 end}
function PlaySound() sounded=sounded+1 end
function PlaySoundFile(file) assert(file==567499); sounded=sounded+1 end
addon:SetModuleEnabled("focusInterrupt",true)
focus:Check(); assert(spoken==0)
cast="Danger"; focus:Event("UNIT_SPELLCAST_START","focus"); focus:Check(); assert(spoken==1)
focus:Check(); assert(spoken==1, "No repeated alert every update")
now=102; focus:Event("UNIT_SPELLCAST_SUCCEEDED","player",nil,47528)
focus:Event("UNIT_SPELLCAST_START","focus"); focus:Check(); assert(spoken==1,"Cooldown suppresses alert")
now=117; focus:Check(); assert(spoken==2,"Ready mid-cast alerts")
now=120; enemy=false; focus:Event("UNIT_SPELLCAST_START","focus"); focus:Check(); assert(spoken==2)
enemy=true; immune=true; focus:Check(); assert(spoken==2,"Skip readable immune casts")
immune=false; now=122; focus:Event("PLAYER_FOCUS_CHANGED"); focus:Check(); assert(spoken==3)
addon:GetSettings().focusInterrupt.ttsMode=false; focus:TestAlert(); assert(sounded==1)
focus:Event("UNIT_SPELLCAST_START","focus"); focus:Disable(); now=130; focus:Check()
assert(spoken==3 and sounded==1 and not next(focus.events.events) and not focus.events.scripts.OnUpdate)
function IsPlayerSpell() return false end
focus:Enable(); focus:Check(); assert(sounded==1,"No known interrupt means no alerts")
focus:Disable(); function IsPlayerSpell(id) return id==47528 end
C_Spell.GetSpellCooldown=function() return {startTime=125,duration=15} end
focus:Enable(); focus:Check(); assert(sounded==1,"Reload with active cooldown does not report ready")
now=141; focus:Check(); assert(sounded==2)
C_Spell.GetSpellCooldown=function() return {startTime=SECRET,duration=SECRET} end
focus:Event("PLAYER_REGEN_ENABLED")
focus:Event("UNIT_SPELLCAST_SUCCEEDED","player",nil,SECRET)
addon:SelectSettingsModule("focusInterrupt"); assert(settingsWindow.pages.focusInterrupt:IsShown())
focus:Disable()
print("PASS: focus alerts, throttle, cooldown, focus changes, friendly/immune filtering, sound, disabled cleanup and secret guards")

-- Channel starts and cancellation use the same alert path as normal casts.
cast=nil; now=200
C_Spell.GetSpellCooldown=function() return {startTime=0,duration=0} end
function UnitChannelInfo() return "Channel",nil,nil,nil,nil,nil,false end
focus:Enable(); focus:Event("UNIT_SPELLCAST_CHANNEL_START","focus"); focus:Check()
assert(sounded==3,"Channel start alerts")
function UnitChannelInfo() return nil end
focus:Event("UNIT_SPELLCAST_CHANNEL_STOP","focus"); now=202; focus:Check()
assert(sounded==3,"Stopped channels do not alert")
focus:Event("UNIT_SPELLCAST_START","focus"); focus:Disable(); focus:TestAlert()
assert(sounded==3,"Pending and test alerts respect disabled module")
print("PASS: focus channel start/stop and disabled test alerts")
