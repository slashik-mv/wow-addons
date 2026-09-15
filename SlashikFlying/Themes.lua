local _, ns = ...

-- Register another ID here to add a theme. All appearance defaults belong here;
-- flight data, visibility and saved position are shared by every renderer.
ns.Themes = {
    compact = {
        name = "Compact", width = 240, height = 32, gap = 2,
        texture = "Interface\\Buttons\\WHITE8x8",
        font = "Fonts\\FRIZQT__.TTF", fontSize = 11, fontFlags = "OUTLINE",
        background = {0.07, 0.07, 0.08, 0.85},
        speed = {height = 14, color = {0.05, 0.67, 0.76}},
        wind = {y = 0, height = 6, gap = 2, color = {0.64, 0.32, 0.90}},
        vigor = {y = -8, height = 8, gap = 2, color = {0.40, 0.58, 0.72}},
        icon = {size = 32, crop = 0.08},
    },
    blizzard = {
        name = "Blizzard", layoutVersion = 2, width = 200, height = 70, gap = 8,
        texture = "Interface\\TargetingFrame\\UI-StatusBar",
        font = "Fonts\\FRIZQT__.TTF", fontSize = 12, fontFlags = "OUTLINE",
        background = {0.06, 0.04, 0.02, 0.9},
        border = {texture = "Interface\\Tooltips\\UI-Tooltip-Border", size = 12, color = {0.8, 0.7, 0.45, 1}},
        speed = {height = 18, color = {0.12, 0.55, 0.9}},
        wind = {y = 0, height = 12, gap = 8, color = {0.64, 0.32, 0.90}},
        vigor = {y = -16, height = 32, gap = 2, color = {1, 1, 1},
            atlas = {fill = "dragonriding_vigor_fill", background = "dragonriding_vigor_background", frame = "dragonriding_vigor_frame"}},
        icon = {size = 42, crop = 0.04},
    },
}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end

-- Sanitize saved appearance data against the registered schema. Missing new
-- fields receive defaults without erasing existing per-theme preferences.
local function validate(saved, defaults)
    if type(saved) ~= "table" then return copy(defaults) end
    for key, default in pairs(defaults) do
        local value = saved[key]
        if type(default) == "table" then
            saved[key] = validate(value, default)
        elseif type(value) ~= type(default) then
            saved[key] = default
        elseif type(value) == "number" then
            if value ~= value or value == math.huge or value == -math.huge
                or (default >= 0 and value < 0) or math.abs(value) > 1000 then
                saved[key] = default
            end
        end
    end
    return saved
end
function ns.InitializeThemes(settings)
    if type(settings.themes) ~= "table" then settings.themes = {} end
    local migrateWidth = not settings.themes.compact and settings.width
    -- Upgrade the original Blizzard circle size without resetting preferences.
    local blizzard = settings.themes.blizzard
    -- Apply the narrower default once, allowing any width to be chosen later.
    if type(blizzard) == "table" and blizzard.layoutVersion ~= 2 then
        if blizzard.width == 280 then blizzard.width = 200 end
        blizzard.layoutVersion = 2
    end
    if type(blizzard) == "table" and type(blizzard.vigor) == "table"
        and blizzard.vigor.height == 46 then
        blizzard.vigor.height = 32
        if blizzard.height == 84 then blizzard.height = 70 end
    end
    for id, defaults in pairs(ns.Themes) do
        settings.themes[id] = validate(settings.themes[id], defaults)
        local theme = settings.themes[id]
        if theme.width < 120 or theme.width > 600 then theme.width = defaults.width end
        if theme.height < 1 then theme.height = defaults.height end
    end
    if type(migrateWidth) == "number" and migrateWidth >= 120 and migrateWidth <= 600 then
        settings.themes.compact.width = migrateWidth
    end
    settings.width = nil
    if type(settings.themeId) ~= "string" or not ns.Themes[settings.themeId] then settings.themeId = "compact" end
end
function ns.GetTheme()
    local settings = ns.GetSettings()
    return settings.themes[settings.themeId]
end
function ns.ThemeList()
    local ids = {}
    for id in pairs(ns.Themes) do ids[#ids + 1] = id end
    table.sort(ids)
    return table.concat(ids, ", ")
end
