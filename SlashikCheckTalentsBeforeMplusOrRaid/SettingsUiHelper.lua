local ADDON_NAME, addon = ...
local getSetting = addon.getSetting
local DEFAULT_SETTINGS = addon.DEFAULT_SETTINGS

local function RegisterSettingsUI()
  if not Settings then return end

  local category = Settings.RegisterVerticalLayoutCategory(ADDON_NAME)
  Settings.RegisterAddOnCategory(category)

  local CreateCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox
  if not CreateCheckbox then
    print("API Problem -> CreateCheckbox or CreateCheckBox do not exist!")
    return
  end

  local function AddCheckbox(varName, label, tooltip)
    local setting = Settings.RegisterAddOnSetting(
      category,
      varName,                 -- internal setting name
      varName,                 -- key in SavedVariables table
      getSetting(),            -- SavedVariables table with defaults applied
      Settings.VarType.Boolean,
      label,
      DEFAULT_SETTINGS[varName]
    )
    Settings.SetOnValueChangedCallback(varName, addon.invalidateSettingsCache)
    CreateCheckbox(category, setting, tooltip)
  end

  -- Settings
  AddCheckbox("enabledM", "Enable for M+", "Turns the warning on/off for M+")
  AddCheckbox("enabledRaid", "Enable for Raid", "Turns the warning on/off for Raid")
  AddCheckbox("enabledDelve", "Enable for Delve", "Turns the warning on/off for Delve")
end

-- Init when addon loads
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
  if name ~= ADDON_NAME then return end
  getSetting()
  RegisterSettingsUI()
end)
