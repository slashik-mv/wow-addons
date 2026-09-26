local _, addon = ...

local function GetSettings()
    if type(SlashikChangingLayoutByTextDB) ~= "table" then
        SlashikChangingLayoutByTextDB = {}
    end
    if type(SlashikChangingLayoutByTextDB.autoPullMessages) ~= "boolean" then
        SlashikChangingLayoutByTextDB.autoPullMessages = false
    end
    return SlashikChangingLayoutByTextDB
end

local function SetAutoPullMessages(enabled)
    GetSettings().autoPullMessages = enabled
    print("Automatic pull messages: " .. (enabled and "ON" or "OFF"))
end

addon.GetSettings = GetSettings
addon.SetAutoPullMessages = SetAutoPullMessages
