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
    "SetWidth", "SetJustifyH", "SetAutoFocus", "SetNumeric", "SetMaxLetters", "ClearFocus", "SetAlpha" }) do
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
function methods:SetText(value) self.text = value end
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

for _, file in ipairs({ "SettingsHelper.lua", "ModuleSettingsHelper.lua", "TrackerFrameHelper.lua",
    "Modules/BoneShield.lua", "Modules/DeathAndDecay.lua", "AddonSettingsFrameHelper.lua", "SlashikCombatUtils.lua" }) do
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
print("PASS: " .. checks .. " aura cases; startup, lifecycle, visibility, previews, animation, settings and secret guards")
