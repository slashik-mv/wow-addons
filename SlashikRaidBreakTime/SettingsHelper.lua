local function initializeDefaultSettings(settings)
    if settings.randomImages == nil then
        settings.randomImages = true
    end
    if type(settings.randomTimerMinutes) ~= "number" or settings.randomTimerMinutes < 1 then
        settings.randomTimerMinutes = 1
    end
    if settings.audioEnabled == nil then
        settings.audioEnabled = false
    end
end

function getSettings()
    SlashikRaidBreakTimeDB = SlashikRaidBreakTimeDB or {}
    SlashikRaidBreakTimeDB.settings = SlashikRaidBreakTimeDB.settings or {}

    local settings = SlashikRaidBreakTimeDB.settings
    initializeDefaultSettings(settings)
    return settings
end

function resetSettingsToDefault()
    local settings = getSettings()
    settings.randomImages = true
    settings.randomTimerMinutes = 1
    settings.audioEnabled = false
    return settings
end
