local _, addon = ...

local function number(value, default, low, high)
    if type(value) ~= "number" or value ~= value or value < low or value > high then return default end
    return value
end

function addon:GetSettings()
    if type(SlashikCombatUtilsDB) ~= "table" then SlashikCombatUtilsDB = {} end
    local db = SlashikCombatUtilsDB
    if type(db.settings) ~= "table" then db.settings = {} end
    local settings = db.settings
    if type(settings.modules) ~= "table" then settings.modules = {} end
    if type(settings.boneShield) ~= "table" then settings.boneShield = {} end
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
