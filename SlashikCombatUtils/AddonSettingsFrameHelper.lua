local _, addon = ...
local window, page
local controls, builders = {}, {}

function addon:RegisterSettingsControl(control)
    controls[#controls + 1] = control
end

function addon:RegisterModuleSettings(key, builder)
    builders[key] = builder
end

function addon:RefreshSettingsWindow()
    if not window then return end
    local order = self:GetModuleDisplayOrder()
    for index, key in ipairs(order) do
        local row, check = window.rows[key], window.checks[key]
        if row then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 28, -85 - (index - 1) * 40)
            check:ClearAllPoints()
            check:SetPoint("TOPLEFT", 177, -90 - (index - 1) * 40)
            row.up:SetEnabled(index > 1)
            row.down:SetEnabled(index < #order)
        end
    end
    for key, check in pairs(window.checks) do
        check:SetChecked(self:IsModuleEnabled(key))
        window.rows[key].selected:SetShown(window.selectedModule == key)
    end
    for _, control in ipairs(controls) do
        local enabled = self:IsModuleEnabled(control.module)
        control:SetEnabled(enabled)
        control:SetAlpha(enabled and 1 or 0.45)
        if control.label then control.label:SetAlpha(enabled and 1 or 0.45) end
        if control.read then control:SetChecked(control.read()) end
    end
    for key, panel in pairs(window.pages) do
        panel.status:SetText(self:IsModuleEnabled(key) and "Module enabled" or "Module disabled - enable it in the sidebar to change settings.")
        if panel.scale and not panel.scale:HasFocus() then
            panel.scale:SetText(tostring(math.floor(self:GetSettings().boneShield.scale * 100 + 0.5)))
        end
    end
end

local function label(text, x, y, template)
    local textRegion = page:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    textRegion:SetPoint("TOPLEFT", x, y)
    textRegion:SetJustifyH("LEFT")
    textRegion:SetWidth(490)
    textRegion:SetText(text)
    return textRegion
end

local function option(key, text, y)
    local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetPoint("TOPLEFT", 48, y)
    check.label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
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
    local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
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

builders.boneShield = function(panel)
    page = panel
        option("combatOnly", "Show only in combat", -93)
        option("showTimer", "Show remaining seconds on the left", -125)
        option("bounce", "Bounce red lines when Bone Shield is missing", -157)
        option("showDeathAndDecay", "Show Death and Decay buff time on the right", -185)
        label("Green: 5+ stacks    Dark yellow: 1-4    Red: 0", 56, -217)
        label("Live tracking appears only for Blood Death Knights while alive.\nGray lines: display-only count. ? means no aura source is available.", 56, -241, "GameFontHighlightSmall")
        label("Display size (50-300%):", 56, -273)
        local scale = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
        scale:SetSize(50, 24)
        scale:SetPoint("TOPLEFT", 245, -265)
        scale:SetAutoFocus(false)
        scale:SetNumeric(true)
        scale:SetMaxLetters(3)
        scale.module = "boneShield"
        controls[#controls + 1] = scale
        page.scale = scale
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
        action("Apply", 315, -265, 90, applyScale)
        label("Drag preview: X 0 / Y 0 = screen center; +X right, +Y up.", 56, -314, "GameFontHighlightSmall")
        action("Green / Move", 56, -338, 140, function() addon.modules.boneShield:StartPreview("healthy") end)
        action("Yellow", 206, -338, 110, function() addon.modules.boneShield:StartPreview("low") end)
        action("Red / Bounce", 326, -338, 140, function() addon.modules.boneShield:StartPreview("missing") end)
        action("Stop preview", 56, -376, 140, function() addon.modules.boneShield:StopPreview() end)
        action("Reset position / size", 206, -376, 190, function()
            local settings = addon:GetSettings().boneShield
            settings.x, settings.y, settings.scale = 0, -100, 1
            addon:RefreshModule("boneShield")
        end)
end

function addon:SelectSettingsModule(key)
    if not self.modules[key] then return end
    local oldKey = window.selectedModule
    if oldKey ~= key and oldKey then
        local oldModule = self.modules[oldKey]
        if oldModule.StopPreview then oldModule:StopPreview() end
        local oldPage = window.pages[oldKey]
        if oldPage and oldPage.scale then oldPage.scale:ClearFocus() end
    end
    window.selectedModule = key
    for _, panel in pairs(window.pages) do panel:Hide() end
    page = window.pages[key]
    if not page then
        page = CreateFrame("Frame", nil, window)
        page:SetPoint("TOPLEFT", 250, -48)
        page:SetSize(550, 500)
        window.pages[key] = page
        label(self.modules[key].title, 0, 0, "GameFontNormalLarge")
        label(self.modules[key].description, 0, -30, "GameFontHighlightSmall")
        page.status = label("", 0, -62, "GameFontDisableSmall")
        if builders[key] then builders[key](page)
        else label("No additional settings for this module.", 0, -105) end
    end
    page:Show()
    self:RefreshSettingsWindow()
end

function addon:ShowSettings()
    if not window then
        window = CreateFrame("Frame", "SlashikCombatUtilsSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(840, 570)
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
        window.checks, window.rows, window.pages = {}, {}, {}
        window:SetScript("OnHide", function()
            for _, module in pairs(addon.modules) do
                if module.StopPreview then module:StopPreview() end
            end
            for _, panel in pairs(window.pages) do
                if panel.scale then panel.scale:ClearFocus() end
            end
        end)
        local sidebar = CreateFrame("Frame", nil, window, "BackdropTemplate")
        sidebar:SetPoint("TOPLEFT", 12, -32)
        sidebar:SetSize(215, 493)
        sidebar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        sidebar:SetBackdropColor(0, 0, 0, 0.22)
        local heading = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        heading:SetPoint("TOPLEFT", 14, -16)
        heading:SetText("Modules")
        local hint = sidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 14, -43)
        hint:SetWidth(185)
        hint:SetJustifyH("LEFT")
        hint:SetText("Select a name to view settings.\nCheckboxes enable. Arrows reorder.")
        for index, key in ipairs(self:GetModuleDisplayOrder()) do
            local row = CreateFrame("Button", nil, sidebar)
            row:SetSize(145, 36)
            row:SetPoint("TOPLEFT", 28, -85 - (index - 1) * 40)
            row.selected = row:CreateTexture(nil, "BACKGROUND")
            row.selected:SetAllPoints()
            row.selected:SetColorTexture(0.65, 0.48, 0.15, 0.28)
            local title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            title:SetPoint("LEFT", 8, 0)
            title:SetWidth(129)
            title:SetJustifyH("LEFT")
            title:SetText(self.modules[key].title)
            row:SetScript("OnClick", function() addon:SelectSettingsModule(key) end)
            local check = CreateFrame("CheckButton", nil, sidebar, "UICheckButtonTemplate")
            check:SetSize(26, 26)
            check:SetPoint("TOPLEFT", 177, -90 - (index - 1) * 40)
            check:SetScript("OnClick", function(self)
                addon:SetModuleEnabled(key, self:GetChecked())
                addon:RefreshSettingsWindow()
            end)
            row.up = CreateFrame("Button", nil, sidebar, "UIPanelScrollUpButtonTemplate")
            row.up:SetSize(20, 18)
            row.up:SetPoint("TOPRIGHT", row, "TOPLEFT", -1, 0)
            row.up:SetScript("OnClick", function() addon:MoveModule(key, -1) end)
            row.down = CreateFrame("Button", nil, sidebar, "UIPanelScrollDownButtonTemplate")
            row.down:SetSize(20, 18)
            row.down:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", -1, 0)
            row.down:SetScript("OnClick", function() addon:MoveModule(key, 1) end)
            window.rows[key], window.checks[key] = row, check
        end
        local divider = window:CreateTexture(nil, "ARTWORK")
        divider:SetSize(1, 493)
        divider:SetPoint("TOPLEFT", 234, -32)
        divider:SetColorTexture(0.6, 0.6, 0.6, 0.35)
        local footer = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        footer:SetPoint("BOTTOMLEFT", 24, 18)
        footer:SetText("/scu   |   Change settings outside combat. Closing this window ends previews.")
    end
    self:SelectSettingsModule(window.selectedModule or self:GetModuleDisplayOrder()[1])
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
