local _, addon = ...
local module = addon.modules.beacons
addon:RegisterModuleSettings("beacons", function(panel)
    local note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 8, -94)
    note:SetWidth(510)
    note:SetJustifyH("LEFT")
    note:SetText("Checks your beacons on observable living group members.\nOffline/out-of-view players are skipped; restricted data remains unknown.\nUse /scu beacons to report detection status during your combat test.")
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetSize(26, 26); check:SetPoint("TOPLEFT", 8, -154)
    check.label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    check.label:SetPoint("LEFT", check, "RIGHT", 4, 0); check.label:SetText("Bounce missing beacon icons")
    check.module = "beacons"; check.read = function() return addon:GetSettings().beacons.bounce end
    addon:RegisterSettingsControl(check)
    check:SetScript("OnClick", function(self)
        if addon:CanEdit() then addon:GetSettings().beacons.bounce = self:GetChecked() == true; module:Update() end
        addon:RefreshSettingsWindow()
    end)
    for i, field in ipairs({ {"x", "Horizontal position", -10000, 10000}, {"y", "Vertical position", -10000, 10000}, {"scale", "Scale (0.5 to 3)", 0.5, 3} }) do
        local key = field[1]
        local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOPLEFT", 12, -196 - (i - 1) * 36); text:SetText(field[2])
        local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        box:SetSize(80, 24); box:SetPoint("TOPLEFT", 240, -190 - (i - 1) * 36)
        box:SetAutoFocus(false); box:SetMaxLetters(7)
        box:SetText(tostring(addon:GetSettings().beacons[key])); box.module = "beacons"
        addon:RegisterSettingsControl(box)
        box:SetScript("OnEnterPressed", function(self)
            local value = tonumber(self:GetText())
            if addon:CanEdit() and value and value >= field[3] and value <= field[4] then
                addon:GetSettings().beacons[key] = value; module:Update()
            end
            self:SetText(tostring(addon:GetSettings().beacons[key])); self:ClearFocus()
        end)
        box:SetScript("OnEscapePressed", function(self) self:SetText(tostring(addon:GetSettings().beacons[key])); self:ClearFocus() end)
    end
    for i, text in ipairs({"Preview icons", "Stop preview"}) do
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(140, 26); button:SetPoint("TOPLEFT", 8 + (i - 1) * 155, -322)
        button:SetText(text); button.module = "beacons"; addon:RegisterSettingsControl(button)
        button:SetScript("OnClick", function() if i == 1 then module:StartPreview() else module:StopPreview() end end)
    end
end)
