local ADDON_NAME, addon = ...

function addon:RegisterSettingsUI()
  local category = Settings.RegisterVerticalLayoutCategory(ADDON_NAME)
  Settings.RegisterAddOnCategory(category)
  self.settingsCategory = category
  local function AddCheckbox(key, label, tooltip)
    local setting = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_" .. key,
      key, self.db.settings, Settings.VarType.Boolean, label, self.defaults[key])
    Settings.CreateCheckbox(category, setting, tooltip)
  end
  AddCheckbox("showOnLogin", "Open checklist on login", "Show the weekly checklist when logging into any character.")
  AddCheckbox("lockWindow", "Lock window position", "Prevent dragging the checklist window. Use /7mil position to center it.")
end

function addon:OpenSettings()
  Settings.OpenToCategory(self.settingsCategory:GetID())
end
