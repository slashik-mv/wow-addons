DEFAULT_SETTINGS = {
  enabledScreenWarning = true,
  warningX = 0,
  warningY = 0,
  enabledHI = false,
  greetingMessage = "Greetings, travelers!"
}

local function initializeDefaultSettings(settings)
  for key, value in pairs(DEFAULT_SETTINGS) do
    if settings[key] == nil then
      settings[key] = value
    end
  end
end

function getSetting()
  if type(SlashikWhichDungeonInviteDB) ~= "table" then
    SlashikWhichDungeonInviteDB = {}
  end

  local settings = SlashikWhichDungeonInviteDB
  initializeDefaultSettings(settings)
  return settings
end
