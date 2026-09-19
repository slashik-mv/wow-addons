-- Adapted from SlashikWhichDungeonInvite's centered warning helper.
local announcementFrame
local hideTimer

function showRaidBreakKeystoneAnnouncement(dungeon, level, owner, insertReminder)
    if not announcementFrame then
        announcementFrame = CreateFrame("Frame", nil, UIParent)
        announcementFrame:SetSize(800, 240)
        announcementFrame:SetPoint("CENTER")
        announcementFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        announcementFrame:EnableMouse(false)
        local title = announcementFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        title:SetPoint("CENTER", 0, 30)
        title:SetWidth(800)
        local font, _, flags = title:GetFont()
        title:SetFont(font, 60, flags)
        announcementFrame.title = title
        local subtitle = announcementFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        subtitle:SetPoint("TOP", title, "BOTTOM", 0, -12)
        subtitle:SetWidth(800)
        announcementFrame.subtitle = subtitle
    end
    if hideTimer then hideTimer:Cancel() end
    announcementFrame.title:SetText(insertReminder and (owner .. " — insert your keystone!")
        or string.format("Next key: %s +%d", dungeon, level))
    announcementFrame.subtitle:SetText(insertReminder and string.format("+%d %s", level, dungeon)
        or ("Key owner: " .. owner))
    announcementFrame:Show()
    hideTimer = C_Timer.NewTimer(7, function()
        announcementFrame:Hide()
        hideTimer = nil
    end)
end
