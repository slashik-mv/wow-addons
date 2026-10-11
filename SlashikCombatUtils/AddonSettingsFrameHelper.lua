local _, addon = ...
local window
local controls = {}

function addon:RefreshSettingsWindow()
    if not window then return end
    for key, check in pairs(window.checks) do check:SetChecked(self:IsModuleEnabled(key)) end
    for _, control in ipairs(controls) do
        local enabled = self:IsModuleEnabled(control.module)
        control:SetEnabled(enabled)
        control:SetAlpha(enabled and 1 or 0.45)
        if control.label then control.label:SetAlpha(enabled and 1 or 0.45) end
        if control.read then control:SetChecked(control.read()) end
    end
    window.scale:SetText(tostring(math.floor(self:GetSettings().boneShield.scale * 100 + 0.5)))
end

local function label(text, x, y, template)
    local textRegion = window:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    textRegion:SetPoint("TOPLEFT", x, y)
    textRegion:SetJustifyH("LEFT")
    textRegion:SetWidth(490)
    textRegion:SetText(text)
    return textRegion
end

local function option(key, text, y)
    local check = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetPoint("TOPLEFT", 48, y)
    check.label = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    check.label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    check.label:SetText(text)
    check.module = "boneShield"
    check.read = function() return addon:GetSettings().boneShield[key] end
    controls[#controls + 1] = check
    check:SetScript("OnClick", function(self)
        if addon:CanEdit() and addon:IsModuleEnabled("boneShield") then
            addon:GetSettings().boneShield[key] = self:GetChecked() == true
            addon:RefreshModule("boneShield")
        end
        addon:RefreshSettingsWindow()
    end)
end

local function action(text, x, y, width, callback)
    local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button.module = "boneShield"
    controls[#controls + 1] = button
    button:SetScript("OnClick", function()
        if addon:CanEdit() and addon:IsModuleEnabled("boneShield") then callback() end
        addon:RefreshSettingsWindow()
    end)
end

function addon:ShowSettings()
    if not window then
        window = CreateFrame("Frame", "SlashikCombatUtilsSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(600, 580)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:SetMovable(true)
        window:SetClampedToScreen(true)
        window:EnableMouse(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        window.TitleText:SetText("Slashik Combat Utils - Settings")
        table.insert(UISpecialFrames, "SlashikCombatUtilsSettingsFrame")
        window:SetScript("OnHide", function() addon.modules.boneShield:StopPreview() end)
        label("Disabling a module stops its tracker.\nIndividual preferences remain saved when disabled.", 24, -42)
        window.checks = {}
        for index, key in ipairs(self.moduleOrder) do
            local module = self.modules[key]
            local check = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
            check:SetPoint("TOPLEFT", 22, -90 - (index - 1) * 60)
            local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            title:SetPoint("LEFT", check, "RIGHT", 2, 0)
            title:SetText(module.title)
            label(module.description, 56, -124 - (index - 1) * 60, "GameFontHighlightSmall")
            check:SetScript("OnClick", function(self)
                addon:SetModuleEnabled(key, self:GetChecked())
                addon:RefreshSettingsWindow()
            end)
            window.checks[key] = check
        end
        option("combatOnly", "Show only in combat", -158)
        option("showTimer", "Show remaining seconds on the left", -190)
        option("bounce", "Bounce red lines when Bone Shield is missing", -222)
        option("showDeathAndDecay", "Show Death and Decay buff time on the right", -250)
        label("Green: 5+ stacks    Dark yellow: 1-4    Red: 0", 56, -282)
        label("Live tracking appears only for Blood Death Knights while alive.\nGray lines: display-only count. ? means no aura source is available.", 56, -306, "GameFontHighlightSmall")
        label("Display size (50-300%):", 56, -338)
        local scale = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
        scale:SetSize(50, 24)
        scale:SetPoint("TOPLEFT", 245, -330)
        scale:SetAutoFocus(false)
        scale:SetNumeric(true)
        scale:SetMaxLetters(3)
        scale.module = "boneShield"
        controls[#controls + 1] = scale
        window.scale = scale
        local function applyScale()
            local value = tonumber(scale:GetText())
            if value and value >= 50 and value <= 300 then
                addon:GetSettings().boneShield.scale = value / 100
                addon:RefreshModule("boneShield")
            else addon:Print("Enter a display size from 50 to 300 percent.") end
            scale:ClearFocus()
        end
        scale:SetScript("OnEnterPressed", function()
            if addon:CanEdit() and addon:IsModuleEnabled("boneShield") then applyScale() end
            addon:RefreshSettingsWindow()
        end)
        scale:SetScript("OnEscapePressed", function() scale:ClearFocus(); addon:RefreshSettingsWindow() end)
        action("Apply", 315, -330, 90, applyScale)
        label("Drag preview: X 0 / Y 0 = screen center; +X right, +Y up.", 56, -379, "GameFontHighlightSmall")
        action("Green / Move", 56, -403, 140, function() addon.modules.boneShield:StartPreview("healthy") end)
        action("Yellow", 206, -403, 110, function() addon.modules.boneShield:StartPreview("low") end)
        action("Red / Bounce", 326, -403, 140, function() addon.modules.boneShield:StartPreview("missing") end)
        action("Stop preview", 56, -441, 140, function() addon.modules.boneShield:StopPreview() end)
        action("Reset position / size", 206, -441, 190, function()
            local settings = addon:GetSettings().boneShield
            settings.x, settings.y, settings.scale = 0, -100, 1
            addon:RefreshModule("boneShield")
        end)
        label("/scu or /slashikcombatutils opens this window.\nSettings changes and previews are available outside combat.\nClosing this window or entering combat ends the preview.", 24, -505, "GameFontDisableSmall")
    end
    self:RefreshSettingsWindow()
    window:Show()
end

function addon:RegisterSettingsCategory()
    local panel = CreateFrame("Frame")
    panel.name = "Slashik Combat Utils"
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(panel.name)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(220, 28)
    button:SetPoint("TOPLEFT", 16, -54)
    button:SetText("Open module settings")
    button:SetScript("OnClick", function() addon:ShowSettings() end)
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
end
