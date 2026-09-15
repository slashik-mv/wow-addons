local _, ns = ...
local defaults = { enabled = true, scale = 1, x = 0, y = -100, hideInCombat = false }
local limits = { scale = {0.5, 3}, x = {-10000, 10000}, y = {-10000, 10000} }
function ns.GetSettings()
    if type(SlashikFlyingDB) ~= "table" then SlashikFlyingDB = {} end
    if type(SlashikFlyingDB.settings) ~= "table" then SlashikFlyingDB.settings = {} end
    local settings = SlashikFlyingDB.settings
    for key, default in pairs(defaults) do
        local value = settings[key]
        local range = limits[key]
        if type(value) ~= type(default) or (range and (value ~= value or value < range[1] or value > range[2])) then
            settings[key] = default
        end
    end
    ns.InitializeThemes(settings)
    return settings
end
function ns.ResetSettings()
    SlashikFlyingDB = { settings = {} }
    return ns.GetSettings()
end
-- Never perform arithmetic or comparisons on restricted Midnight API values.
function ns.Number(value, fallback)
    if issecretvalue and issecretvalue(value) then return fallback end
    if type(value) ~= "number" or value ~= value then return fallback end
    return value
end
