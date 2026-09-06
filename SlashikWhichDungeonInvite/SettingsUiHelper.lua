local ADDON_NAME = ...

local function AddCheckbox(category, settings, key, label, tooltip)
  local registeredSetting = Settings.RegisterAddOnSetting(
    category,
    key,
    key,
    settings,
    Settings.VarType.Boolean,
    label,
    DEFAULT_SETTINGS[key]
  )
  Settings.CreateCheckbox(category, registeredSetting, tooltip)
end

local GREETING_MAX_BYTES = 255

local function ClearTextFocus(editBox)
  editBox:ClearFocus()
end

local function InitializeGreetingInput(initializer, frame)
  local registeredSetting = initializer:GetData().setting
  if not frame.EditBox then
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, -4)
    label:SetText("Greeting message")

    local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetSize(420, 30)
    editBox:SetPoint("TOPLEFT", 6, -26)
    editBox:SetAutoFocus(false)
    editBox:SetMaxBytes(GREETING_MAX_BYTES)
    editBox:SetScript("OnEnterPressed", ClearTextFocus)
    editBox:SetScript("OnEscapePressed", ClearTextFocus)
    editBox:SetScript("OnHide", ClearTextFocus)
    frame.EditBox = editBox

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 0, -64)
    hint:SetText("Saved automatically. Leave empty to send no greeting.")
  end

  if frame.valueChangedHandle then
    frame.valueChangedHandle:Unregister()
  end
  frame.EditBox:SetScript("OnTextChanged", nil)
  frame.EditBox:SetText(registeredSetting:GetValue())
  frame.EditBox:SetScript("OnTextChanged", function(editBox, userInput)
    if userInput then
      registeredSetting:SetValue(editBox:GetText())
    end
  end)
  frame.valueChangedHandle = Settings.SetOnValueChangedCallback("greetingMessage", function(_, _, value)
    if frame.EditBox:GetText() ~= value then
      frame.EditBox:SetText(value)
    end
  end)
end

local function ResetGreetingInput(initializer, frame)
  frame.valueChangedHandle:Unregister()
  frame.valueChangedHandle = nil
  frame.EditBox:ClearFocus()
  frame.EditBox:SetScript("OnTextChanged", nil)
end

local function AddGreetingInput(category, layout, settings)
  local registeredSetting = Settings.RegisterAddOnSetting(
    category, "greetingMessage", "greetingMessage", settings,
    Settings.VarType.String, "Greeting message", DEFAULT_SETTINGS.greetingMessage
  )
  local data = Settings.CreateSettingInitializerData(registeredSetting)
  local initializer = Settings.CreateSettingInitializer("SlashikWhichDungeonInviteGreetingInputTemplate", data)
  initializer.InitFrame = InitializeGreetingInput
  initializer.Resetter = ResetGreetingInput
  layout:AddInitializer(initializer)
end

local function RegisterSettingsUI()
  local settings = getSetting()
  local category, layout = Settings.RegisterVerticalLayoutCategory(ADDON_NAME)
  Settings.RegisterAddOnCategory(category)

  AddCheckbox(category, settings, "enabledScreenWarning", "Enable screen warning", "Turns the warning on/off for middle of the screen")
  AddCheckbox(category, settings, "enabledHI", "Enable Greetings", "Automatically sends your greeting message to party or raid chat")
  AddGreetingInput(category, layout, settings)
end

-- Init when addon loads
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
  if name ~= ADDON_NAME then return end
  RegisterSettingsUI()
end)
