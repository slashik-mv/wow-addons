local _, addon = ...
local module = addon.modules.consumables

addon:RegisterModuleSettings("consumables", function(panel)
    local note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 0, -92)
    note:SetWidth(520)
    note:SetJustifyH("LEFT")
    note:SetText("One selected item meeting its minimum satisfies a category.\nBoth qualities add together. No selections = skipped. Banks do not count.")
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -130)
    scroll:SetSize(510, 310)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(510, 1)
    scroll:SetScrollChild(content)
    content:EnableMouse(true)
    module:EnableItemLinks(content)
    local y = 0
    for _, group in ipairs(module.groups) do
        local heading = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", 8, y)
        heading:SetText(group.title)
        local quantityHeading = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        quantityHeading:SetPoint("TOPLEFT", 428, y)
        quantityHeading:SetText("Minimum")
        y = y - 22
        for _, item in ipairs(group.items) do
            local id = item.id
            local check = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
            check:SetSize(24, 24)
            check:SetPoint("TOPLEFT", 8, y)
            check.icon = check:CreateTexture(nil, "ARTWORK")
            check.icon:SetSize(28, 28)
            check.icon:SetPoint("LEFT", check, "RIGHT", 4, 0)
            local function refreshIcon()
                check.icon:SetTexture(C_Item.GetItemIconByID(id) or 134400)
            end
            refreshIcon()
            check:SetScript("OnShow", refreshIcon)
            check.label = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            check.label:SetPoint("LEFT", check.icon, "RIGHT", 7, 0)
            check.label:SetWidth(340)
            check.label:SetJustifyH("LEFT")
            check.label:SetText("|cffffffff|Hitem:" .. id .. "|h[" .. item.name .. "]|h|r\n|cffaaaaaa" .. item.effect .. "|r")
            check.module = "consumables"
            check.read = function() return module:GetSelections()[id] == true end
            addon:RegisterSettingsControl(check)
            check:SetScript("OnClick", function(self)
                module:SetSelected(id, self:GetChecked())
                addon:RefreshSettingsWindow()
            end)
            local minimum = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
            minimum:SetSize(56, 24)
            minimum:SetPoint("TOPLEFT", 436, y)
            minimum:SetAutoFocus(false)
            minimum:SetNumeric(true)
            minimum:SetMaxLetters(4)
            minimum:SetText(tostring(module:GetMinimum(id)))
            minimum.module = "consumables"
            minimum.itemID = id
            addon:RegisterSettingsControl(minimum)
            local function save(self)
                if tonumber(self:GetText()) ~= module:GetMinimum(id) then
                    module:SetMinimum(id, self:GetText())
                end
                self:SetText(tostring(module:GetMinimum(id)))
            end
            minimum:SetScript("OnEnterPressed", function(self) save(self); self:ClearFocus() end)
            minimum:SetScript("OnEditFocusLost", save)
            minimum:SetScript("OnEscapePressed", function(self)
                self:SetText(tostring(module:GetMinimum(id)))
                self:ClearFocus()
            end)
            minimum:SetScript("OnHide", function(self) save(self); self:ClearFocus() end)
            y = y - 40
        end
        y = y - 10
    end
    content:SetHeight(-y)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(140, 26)
    button:SetPoint("TOPLEFT", 8, -458)
    button:SetText("Check now")
    button.module = "consumables"
    addon:RegisterSettingsControl(button)
    button:SetScript("OnClick", function() module:Check(true) end)
end)
