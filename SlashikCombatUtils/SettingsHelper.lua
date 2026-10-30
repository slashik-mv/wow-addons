local _, addon = ...

local function number(value, default, low, high)
    if type(value) ~= "number" or value ~= value or value < low or value > high then return default end
    return value
end

local function copySettings(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copySettings(entry) end
    return result
end

function addon:GetSettings()
    if type(SlashikCombatUtilsCharDB) ~= "table" then SlashikCombatUtilsCharDB = {} end
    local db = SlashikCombatUtilsCharDB
    if type(db.settings) ~= "table" then
        -- Keep the old account settings as a migration snapshot for other characters.
        local legacy = type(SlashikCombatUtilsDB) == "table" and SlashikCombatUtilsDB.settings
        db.settings = type(legacy) == "table" and copySettings(legacy) or {}
    end
    local settings = db.settings
    if type(settings.modules) ~= "table" then settings.modules = {} end
    -- Preserve the original trackers' historical defaults; new modules opt in.
    if settings.modules.boneShield == nil then settings.modules.boneShield = true end
    if settings.modules.beacons == nil then settings.modules.beacons = true end
    if settings.modules.demonSpikes == nil then settings.modules.demonSpikes = false end
    if settings.modules.consumables == nil then settings.modules.consumables = false end
    if settings.modules.autoHealthPot == nil then settings.modules.autoHealthPot = false end
    if settings.modules.focusInterrupt == nil then settings.modules.focusInterrupt = true end
    if type(settings.focusInterrupt) ~= "table" then settings.focusInterrupt = {} end
    local focus = settings.focusInterrupt
    focus.ttsMode = focus.ttsMode == true
    if type(focus.ttsMessage) ~= "string" or focus.ttsMessage:match("^%s*$") then focus.ttsMessage = "Interrupt" end
    if type(focus.soundName) ~= "string" then focus.soundName = "Auction Window Close" end
    if type(settings.autoHealthPot) ~= "table" then settings.autoHealthPot = {} end
    for _, key in ipairs({"selected", "order", "ownedBodies"}) do
        if type(settings.autoHealthPot[key]) ~= "table" then settings.autoHealthPot[key] = {} end
    end
    if type(settings.boneShield) ~= "table" then settings.boneShield = {} end
    if type(settings.consumables) ~= "table" then settings.consumables = {} end
    if type(settings.consumables.selected) ~= "table" then settings.consumables.selected = {} end
    if type(settings.consumables.minimums) ~= "table" then settings.consumables.minimums = {} end
    if type(settings.beacons) ~= "table" then settings.beacons = {} end
    local beacons = settings.beacons
    beacons.bounce = beacons.bounce ~= false
    beacons.x = number(beacons.x, 0, -10000, 10000)
    beacons.y = number(beacons.y, 0, -10000, 10000)
    beacons.scale = number(beacons.scale, 1, 0.5, 3)
    if type(settings.demonSpikes) ~= "table" then settings.demonSpikes = {} end
    local spikes = settings.demonSpikes
    spikes.bounce = spikes.bounce ~= false
    spikes.combatOnly = spikes.combatOnly == true
    spikes.x = number(spikes.x, 0, -10000, 10000)
    spikes.y = number(spikes.y, -100, -10000, 10000)
    spikes.scale = number(spikes.scale, 1, 0.5, 3)
    local bone = settings.boneShield
    bone.combatOnly = bone.combatOnly == true
    bone.showDeathAndDecay = bone.showDeathAndDecay ~= false
    bone.showTimer = bone.showTimer ~= false
    bone.bounce = bone.bounce ~= false
    bone.scale = number(bone.scale, 1, 0.5, 3)
    bone.x = number(bone.x, 0, -10000, 10000)
    bone.y = number(bone.y, -100, -10000, 10000)
    return settings
end

function addon:Print(message)
    print("|cff70db70SlashikCombatUtils:|r " .. message)
end

function addon:CanEdit()
    if InCombatLockdown() then
        self:Print("Change settings and previews outside combat.")
        return false
    end
    return true
end
