local window
local controls = {}

function refreshRaidBreakAddonSettings()
    if not window then return end
    for module, check in pairs(window.checks) do check:SetChecked(isRaidBreakModuleEnabled(module)) end
    for _, control in ipairs(controls) do
        local enabled = isRaidBreakModuleEnabled(control.module)
        control:SetEnabled(enabled)
        control:SetAlpha(enabled and 1 or 0.45)
        if control.label then control.label:SetAlpha(enabled and 1 or 0.45) end
        if control.read then control:SetChecked(control.read()) end
    end
    if window.minutes then window.minutes:SetText(tostring(getSettings().randomTimerMinutes)) end
end

local function option(module, text, y, read, write)
    local check = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetPoint("TOPLEFT", 48, y)
    check.label = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    check.label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    check.label:SetText(text)
    check.module, check.read = module, read
    controls[#controls + 1] = check
    check:SetScript("OnClick", function(self)
        if isRaidBreakModuleEnabled(module) then write(self:GetChecked() == true) end
        refreshRaidBreakAddonSettings()
    end)
end

local function action(module, text, x, y, width, callback)
    local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button.module = module
    controls[#controls + 1] = button
    button:SetScript("OnClick", function()
        if isRaidBreakModuleEnabled(module) then callback() end
        refreshRaidBreakAddonSettings()
    end)
end
local modules = {
    { "keystones", "Keystones", "Party and guild keys, announcements, teleports and key-owner reminders." },
    { "breakTimer", "Raid Break Timer", "Break countdowns, rotating pictures, sounds and DBM/BigWigs break sync." },
    { "raidRecovery", "Raid Recovery & Soulstone Reminders", "Ready-check reminders, warlock whispers, DON'T RELEASE and mass resurrection." },
}

function showRaidBreakAddonSettings()
    if not window then
        window = CreateFrame("Frame", "SlashikRaidBreakTimeSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(600, 695)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:SetMovable(true)
        window:EnableMouse(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        window.TitleText:SetText("Slashik Raid Break Time — Settings")
        table.insert(UISpecialFrames, "SlashikRaidBreakTimeSettingsFrame")
        local note = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        note:SetPoint("TOPLEFT", 24, -42)
        note:SetWidth(510)
        note:SetJustifyH("LEFT")
        note:SetText("Master switches: disabling a module stops all its features.\nIndividual preferences remain saved and apply again when enabled.")
        window.checks = {}
        for index, entry in ipairs(modules) do
            local module = entry[1]
            local check = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
            check:SetPoint("TOPLEFT", 22, ({ -90, -220, -445 })[index])
            local label = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("LEFT", check, "RIGHT", 2, 0)
            label:SetText(entry[2])
            local detail = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            detail:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 32, 0)
            detail:SetWidth(475)
            detail:SetJustifyH("LEFT")
            detail:SetText(entry[3])
            check:SetScript("OnClick", function(self)
                setRaidBreakModuleEnabled(module, self:GetChecked())
                refreshRaidBreakAddonSettings()
            end)
            window.checks[module] = check
        end
        option("keystones", "Open party keys when Mythic+ finishes", -155,
            function() return SlashikRaidBreakTimeDB.autoOpenKeystones == true end,
            function(on)
                SlashikRaidBreakTimeDB.autoOpenKeystones = on
                local party = SlashikRaidBreakTimeKeystoneFrame
                if party and party.autoOpen then party.autoOpen:SetChecked(on) end
            end)
        option("breakTimer", "Automatically rotate pictures", -280,
            function() return getSettings().randomImages end,
            function(on) SlashikRaidBreakTimeFrame:setRandomImagesEnabled(on) end)
        option("breakTimer", "Play one-minute and break-end sounds", -310,
            function() return getSettings().audioEnabled end,
            function(on) SlashikRaidBreakTimeFrame:setAudioEnabled(on) end)
        local timerLabel = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        timerLabel:SetPoint("TOPLEFT", 80, -352)
        timerLabel:SetText("Picture interval (minutes, 1–120):")
        local minutes = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
        minutes:SetSize(45, 24)
        minutes:SetPoint("TOPLEFT", 350, -346)
        minutes:SetAutoFocus(false)
        minutes:SetNumeric(true)
        minutes:SetMaxLetters(3)
        minutes.module, minutes.label = "breakTimer", timerLabel
        controls[#controls + 1] = minutes
        window.minutes = minutes
        local function applyMinutes()
            if not isRaidBreakModuleEnabled("breakTimer") then return end
            if not SlashikRaidBreakTimeFrame:setRandomTimerMinutes(minutes:GetText()) then
                print("SlashikRaidBreakTime: Enter a whole number from 1 to 120 minutes.")
            end
            minutes:ClearFocus()
        end
        minutes:SetScript("OnEnterPressed", function() applyMinutes(); refreshRaidBreakAddonSettings() end)
        minutes:SetScript("OnEscapePressed", function() minutes:ClearFocus(); refreshRaidBreakAddonSettings() end)
        action("breakTimer", "Apply", 420, -346, 95, applyMinutes)
        action("breakTimer", "Reset break settings", 80, -385, 180, function()
            SlashikRaidBreakTimeFrame:setRandomImagesEnabled(true)
            SlashikRaidBreakTimeFrame:setRandomTimerMinutes(1)
            SlashikRaidBreakTimeFrame:setAudioEnabled(false)
        end)
        option("raidRecovery", "Ready-check Soulstone screen and raid reminders", -510,
            function() return getSettings().soulstoneEnabled end, setRaidSoulstoneEnabled)
        local recoveryNote = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        recoveryNote:SetPoint("TOPLEFT", 80, -545)
        recoveryNote:SetWidth(470)
        recoveryNote:SetJustifyH("LEFT")
        recoveryNote:SetText("Whispers, DON'T RELEASE and Mass Resurrect remain active while\nthe module is enabled, independently of the ready-check option.")
        action("raidRecovery", "Reset recovery settings", 80, -585, 200,
            function() setRaidSoulstoneEnabled(false) end)
        local footer = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        local moveAlerts = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        moveAlerts:SetSize(180, 24)
        moveAlerts:SetPoint("TOPLEFT", 80, -624)
        moveAlerts:SetText("Move alerts")
        moveAlerts:SetScript("OnClick", showRaidBreakAlertPositionEditor)
        footer:SetPoint("BOTTOMLEFT", 24, 20)
        footer:SetText("All modules start enabled. Module switches cannot be changed during combat.")
    end
    refreshRaidBreakAddonSettings()
    window:Show()
end

for _, module in ipairs({ "keystones", "breakTimer", "raidRecovery" }) do
    registerRaidBreakModuleListener(module, refreshRaidBreakAddonSettings)
end
