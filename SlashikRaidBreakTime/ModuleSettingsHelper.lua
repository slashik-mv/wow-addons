-- Module master switches deliberately live separately from individual preferences.
local listeners = {}
local valid = { keystones = true, breakTimer = true, raidRecovery = true }

function isRaidBreakModuleEnabled(module)
    if not valid[module] then return false end
    local settings = getSettings()
    if type(settings.modules) ~= "table" then settings.modules = {} end
    return settings.modules[module] ~= false
end

function registerRaidBreakModuleListener(module, callback)
    listeners[module] = listeners[module] or {}
    table.insert(listeners[module], callback)
end

function setRaidBreakModuleEnabled(module, enabled)
    if not valid[module] then return false end
    if InCombatLockdown() then
        print("SlashikRaidBreakTime: Module switches can only be changed outside combat.")
        return false
    end
    local previous = isRaidBreakModuleEnabled(module)
    getSettings().modules[module] = enabled == true
    if previous ~= (enabled == true) then
        for _, callback in ipairs(listeners[module] or {}) do callback(enabled == true) end
    end
    return true
end
