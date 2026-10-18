local _, addon = ...
local module=addon.modules.autoHealthPot
addon:RegisterModuleSettings("autoHealthPot", function(panel)
    local function label(text,x,y,width)
        local f=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f:SetPoint("TOPLEFT",x,y); f:SetWidth(width or 520); f:SetJustifyH("LEFT"); f:SetText(text); return f
    end
    label("Select items and move them into priority order. Both potion qualities count.\nUses Healthstone plus ONE available potion; higher quality is preferred.\nOne press per item. Resets on leaving combat or after 60 seconds without pressing.\nA cooling-down step cannot be skipped.",8,-94)
    local rows={}
    for _, item in ipairs(module.items) do
        local id=item.id
        local row=CreateFrame("Frame",nil,panel); row:SetSize(520,36)
        local check=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
        check:SetSize(26,26); check:SetPoint("LEFT",0,0); check.module="autoHealthPot"
        check.read=function() return module:Settings().selected[id] ~= false end
        addon:RegisterSettingsControl(check)
        check:SetScript("OnClick",function(self)
            if addon:CanEdit() and module.enabled then module:Settings().selected[id]=self:GetChecked()==true; module:Request() end
            addon:RefreshSettingsWindow()
        end)
        local icon=row:CreateTexture(nil,"ARTWORK"); icon:SetSize(24,24); icon:SetPoint("LEFT",check,"RIGHT",4,0)
        icon:SetTexture(C_Item.GetItemIconByID(id) or 134400)
        check.label=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        check.label:SetPoint("LEFT",icon,"RIGHT",7,0); check.label:SetWidth(350); check.label:SetJustifyH("LEFT"); check.label:SetText(item.name)
        for _, direction in ipairs({-1,1}) do
            local button=CreateFrame("Button",nil,row,direction == -1 and "UIPanelScrollUpButtonTemplate" or "UIPanelScrollDownButtonTemplate")
            button:SetSize(24,24); button:SetPoint("LEFT",direction == -1 and 448 or 479,0)
            button.module="autoHealthPot"; addon:RegisterSettingsControl(button)
            button:SetScript("OnClick",function() module:Move(id,direction) end)
        end
        rows[id]=row
    end
    local status=label("",8,-322)
    local preview=label("",8,-370)
    local update=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    update:SetSize(150,26); update:SetPoint("TOPLEFT",8,-454); update:SetText("Update macro")
    update.module="autoHealthPot"; addon:RegisterSettingsControl(update)
    update:SetScript("OnClick",function() module:Update() end)
    module.refreshUI=function()
        for i,item in ipairs(module:Order()) do rows[item.id]:ClearAllPoints(); rows[item.id]:SetPoint("TOPLEFT",8,-148-(i-1)*32) end
        status:SetText(module.message or "Enable this module to create the character macro SCU Health Pot.")
        preview:SetText(module.body or "Macro preview appears after enabling the module.")
    end
    panel:SetScript("OnShow",function() module:RefreshUI() end)
    module:RefreshUI()
end)
