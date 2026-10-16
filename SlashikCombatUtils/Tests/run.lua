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
    "RegisterForDrag", "SetFont", "SetTextColor", "SetAllPoints", "SetThickness", "SetStartPoint",
    "SetEndPoint", "SetLooping", "SetOffset", "SetDuration", "SetSmoothing", "SetBackdrop",
    "SetBackdropColor", "SetBackdropBorderColor", "ClearAllPoints", "StartMoving", "StopMovingOrSizing",
    "SetWidth", "SetHeight", "SetScrollChild", "SetJustifyH", "SetAutoFocus", "SetNumeric", "SetMaxLetters", "ClearFocus", "SetAlpha" }) do
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

for _, file in ipairs({ "SettingsHelper.lua", "ModuleSettingsHelper.lua", "TrackerFrameHelper.lua",
    "Modules/BoneShield.lua", "Modules/DeathAndDecay.lua", "Modules/Consumables.lua", "AddonSettingsFrameHelper.lua", "ConsumablesSettingsHelper.lua", "SlashikCombatUtils.lua" }) do
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
SlashikCombatUtilsDB.settings.consumables.selected = {
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
            SlashikCombatUtilsDB.settings.consumables.selected = { [item.id] = true }
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

SlashikCombatUtilsDB.settings.consumables.selected = { [241308] = true }
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
assert(cleanOrder[1] == "consumables" and cleanOrder[2] == "boneShield" and #cleanOrder == 3)
assert(addon.moduleOrder[1] == "boneShield", "Display ordering does not change startup order")
print("PASS: saved module ordering, arrows, boundaries, stale entries and combat guard")
