local _, addon = ...
local module = addon.modules.battleResLust
addon:RegisterModuleSettings("battleResLust", function(panel)
    local function label(value, x, y)
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", x, y); fs:SetWidth(510); fs:SetJustifyH("LEFT"); fs:SetText(value)
        return fs
    end
    label("Warband settings: shared across your characters.\nRes: shared charges / recharge. Lust: your Sated / Exhaustion lockout.\nRes icon alone: no shared charge data. ?: restricted timer data.", 8, -94)
    for i, option in ipairs({{"showRes", "Show battle resurrection"}, {"showLust", "Show lust / heroism"}, {"showInDungeon", "Show in dungeons"}, {"showInRaid", "Show in raids"}, {"showInWorld", "Show outside dungeons and raids"}, {"combatOnly", "Show only in combat"}}) do
        local key = option[1]
        local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        check:SetSize(26, 26); check:SetPoint("TOPLEFT", 8, -150 - (i - 1) * 28)
        check.label = label(option[2], 40, -157 - (i - 1) * 28)
        check.module = "battleResLust"; check.read = function() return addon:GetSettings().battleResLust[key] end
        addon:RegisterSettingsControl(check)
        check:SetScript("OnClick", function(self)
            if addon:CanEdit() and module.enabled then addon:GetSettings().battleResLust[key] = self:GetChecked() == true; module:Update() end
            addon:RefreshSettingsWindow()
        end)
    end
    local boxes = {}
    for i, field in ipairs({{"x", "X", -10000, 10000}, {"y", "Y", -10000, 10000}, {"scale", "Scale", 0.5, 3}}) do
        local key, x = field[1], 12 + (i - 1) * 165
        label(field[2], x, -337)
        local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        box:SetSize(85, 24); box:SetPoint("TOPLEFT", x + 45, -330); box:SetAutoFocus(false); box:SetMaxLetters(8)
        box.module = "battleResLust"; addon:RegisterSettingsControl(box); boxes[key] = box
        local function restore() box:SetText(tostring(addon:GetSettings().battleResLust[key])); box:ClearFocus() end
        box:SetScript("OnEnterPressed", function(self)
            local value = tonumber(self:GetText())
            if addon:CanEdit() and module.enabled and value and value >= field[3] and value <= field[4] then
                addon:GetSettings().battleResLust[key] = value; module:ApplyPosition(); module:Update()
            end
            restore()
        end)
        box:SetScript("OnEscapePressed", restore)
    end
    for i, title in ipairs({"Preview / Move", "Stop preview"}) do
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(150, 26); button:SetPoint("TOPLEFT", 12 + (i - 1) * 165, -380); button:SetText(title)
        button.module = "battleResLust"; addon:RegisterSettingsControl(button)
        button:SetScript("OnClick", function() if i == 1 then module:StartPreview() else module:StopPreview() end end)
    end
    label("Scale: 0.5 to 3. Position is relative to the screen center (0, 0).\nDisable the standalone BResLustTracker to avoid duplicate displays.", 12, -425)
    local function refresh() for key, box in pairs(boxes) do box:SetText(tostring(addon:GetSettings().battleResLust[key])) end end
    panel:SetScript("OnShow", refresh)
    panel:SetScript("OnHide", function() for _, box in pairs(boxes) do box:ClearFocus() end end)
    refresh()
end)
