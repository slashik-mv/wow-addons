local _, addon = ...
local module=addon.modules.focusInterrupt
addon:RegisterModuleSettings("focusInterrupt",function(panel)
    local function label(text,x,y)
        local region=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        region:SetPoint("TOPLEFT",x,y); region:SetWidth(500); region:SetJustifyH("LEFT"); region:SetText(text)
        return region
    end
    local function editable() return addon:CanEdit() and addon:IsModuleEnabled("focusInterrupt") end
    label("Alerts for focus casts/channels, including when your interrupt becomes ready.\nCombat cooldowns may be estimated; interruptibility can be restricted.\nDisable the standalone FocusAlertInterrupt addon to avoid duplicate alerts.",8,-94)
    local mode=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
    mode:SetSize(26,26); mode:SetPoint("TOPLEFT",8,-150)
    mode.label=label("Speak a phrase (uncheck to play a sound)",40,-157)
    mode.module="focusInterrupt"; mode.read=function() return addon:GetSettings().focusInterrupt.ttsMode end
    addon:RegisterSettingsControl(mode)
    mode:SetScript("OnClick",function(self)
        if editable() then addon:GetSettings().focusInterrupt.ttsMode=self:GetChecked()==true end
        addon:RefreshSettingsWindow()
    end)
    label("Spoken phrase:",12,-192)
    local box=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
    box:SetSize(300,24); box:SetPoint("TOPLEFT",130,-185); box:SetAutoFocus(false); box:SetMaxLetters(64)
    box.module="focusInterrupt"; addon:RegisterSettingsControl(box)
    local function save(self)
        if editable() then
            local text=self:GetText():match("^%s*(.-)%s*$")
            addon:GetSettings().focusInterrupt.ttsMessage=text~="" and text or "Interrupt"
        end
        self:SetText(addon:GetSettings().focusInterrupt.ttsMessage)
    end
    box:SetScript("OnEnterPressed",function(self) save(self); self:ClearFocus() end)
    box:SetScript("OnEditFocusLost",save)
    box:SetScript("OnEscapePressed",function(self) self:SetText(addon:GetSettings().focusInterrupt.ttsMessage); self:ClearFocus() end)
    local chosen=label("",12,-225)
    local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",12,-247); scroll:SetSize(440,145)
    local content=CreateFrame("Frame",nil,scroll); content:SetWidth(430); scroll:SetScrollChild(content)
    local rows={}
    local function refresh()
        box:SetText(addon:GetSettings().focusInterrupt.ttsMessage)
        chosen:SetText("Selected sound: "..addon:GetSettings().focusInterrupt.soundName)
        local sounds=module:GetSounds(); content:SetHeight(math.max(1,#sounds*25))
        for i,name in ipairs(sounds) do
            local row=rows[i]
            if not row then
                row=CreateFrame("Button",nil,content,"UIPanelButtonTemplate")
                row:SetSize(420,23); row:SetPoint("TOPLEFT",0,-(i-1)*25)
                row.module="focusInterrupt"; addon:RegisterSettingsControl(row); rows[i]=row
            end
            row:SetText(name); row:Show()
            row:SetScript("OnClick",function()
                if editable() then addon:GetSettings().focusInterrupt.soundName=name; chosen:SetText("Selected sound: "..name); module:PreviewSound(name) end
            end)
        end
        for i=#sounds+1,#rows do rows[i]:Hide() end
    end
    local test=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    test:SetSize(140,26); test:SetPoint("TOPLEFT",12,-420); test:SetText("Test Alert")
    test.module="focusInterrupt"; addon:RegisterSettingsControl(test)
    test:SetScript("OnClick",function() if editable() then save(box); module:TestAlert() end end)
    panel:SetScript("OnShow",refresh)
    panel:SetScript("OnHide",function() box:ClearFocus() end)
    refresh()
end)
