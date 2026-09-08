local _, addon = ...

local DEFAULT_SETTINGS = {
  enabledM = true,
  enabledRaid = true,
  enabledDelve = true,
}

local settings

local function getSetting()
  if settings ~= nil then return settings end

  if type(SlashikCheckTalentsBeforeMplusOrRaidDB) ~= "table" then
    SlashikCheckTalentsBeforeMplusOrRaidDB = {}
  end

  settings = SlashikCheckTalentsBeforeMplusOrRaidDB
  for key, value in pairs(DEFAULT_SETTINGS) do
    if settings[key] == nil then
      settings[key] = value
    end
  end
  return settings
end

local function invalidateSettingsCache()
  settings = nil
end

addon.getSetting = getSetting
addon.invalidateSettingsCache = invalidateSettingsCache

addon.DEFAULT_SETTINGS = DEFAULT_SETTINGS
