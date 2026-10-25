local _, addon = ...
local module = addon.modules.demonSpikes
addon:RegisterModuleSettings("demonSpikes", function(panel)
    local note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 8, -94)
    note:SetWidth(510)
    note:SetJustifyH("LEFT")
    note:SetText("Left: Fury   Middle: Demon Spikes seconds   Right: Soul Fragments\nGreen: active   Red: missing   Gray: restricted / unknown\nFor combat countdowns, track Demon Spikes in Blizzard's buff viewer.")
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetSize(26, 26); check:SetPoint("TOPLEFT", 8, -154)
    check.label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    check.label:SetPoint("LEFT", check, "RIGHT", 4, 0); check.label:SetText("Bounce red lines when Demon Spikes is missing")
    check.module = "demonSpikes"; check.read = function() return addon:GetSettings().demonSpikes.bounce end
    addon:RegisterSettingsControl(check)
    check:SetScript("OnClick", function(self)
        if addon:CanEdit() and module.enabled then addon:GetSettings().demonSpikes.bounce = self:GetChecked() == true; module.frame:ApplyPosition(); module:Update() end
        addon:RefreshSettingsWindow()
    end)
    local combatOnly = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    combatOnly:SetSize(26,26); combatOnly:SetPoint("TOPLEFT",8,-370)
    combatOnly.label = panel:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    combatOnly.label:SetPoint("LEFT",combatOnly,"RIGHT",4,0); combatOnly.label:SetText("Show only in combat")
    combatOnly.module="demonSpikes"; combatOnly.read=function() return addon:GetSettings().demonSpikes.combatOnly end
    addon:RegisterSettingsControl(combatOnly)
    combatOnly:SetScript("OnClick",function(self)
        if addon:CanEdit() and module.enabled then addon:GetSettings().demonSpikes.combatOnly=self:GetChecked()==true; module:Update() end
        addon:RefreshSettingsWindow()
    end)
    for i, field in ipairs({ {"x", "Horizontal position", -10000, 10000}, {"y", "Vertical position", -10000, 10000}, {"scale", "Scale (0.5 to 3)", 0.5, 3} }) do
        local key = field[1]
        local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOPLEFT", 12, -196 - (i - 1) * 36); text:SetText(field[2])
        local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        box:SetSize(80, 24); box:SetPoint("TOPLEFT", 240, -190 - (i - 1) * 36)
        box:SetAutoFocus(false); box:SetMaxLetters(7)
        box:SetText(tostring(addon:GetSettings().demonSpikes[key])); box.module = "demonSpikes"
        addon:RegisterSettingsControl(box)
        box:SetScript("OnEnterPressed", function(self)
            local value = tonumber(self:GetText())
            if addon:CanEdit() and module.enabled and value and value >= field[3] and value <= field[4] then
                addon:GetSettings().demonSpikes[key] = value; module.frame:ApplyPosition(); module:Update()
            end
            self:SetText(tostring(addon:GetSettings().demonSpikes[key])); self:ClearFocus()
        end)
        box:SetScript("OnEscapePressed", function(self) self:SetText(tostring(addon:GetSettings().demonSpikes[key])); self:ClearFocus() end)
    end
    for i, text in ipairs({"Green / Move", "Red / Bounce", "Stop preview"}) do
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(140, 26); button:SetPoint("TOPLEFT", 8 + (i - 1) * 155, -322)
        button:SetText(text); button.module = "demonSpikes"; addon:RegisterSettingsControl(button)
        button:SetScript("OnClick", function() if i == 1 then module:StartPreview("healthy") elseif i == 2 then module:StartPreview("missing") else module:StopPreview() end end)
    end
end)
