-- Adapted from SlashikWhichDungeonInvite's centered warning helper.
local announcementFrame
local hideTimer
local teleportButton
local teleportMapID
local announcementEndsAt = 0

local function updateAnnouncementTeleport()
    if InCombatLockdown() then return end
    if not teleportButton then
        -- Keep the secure button separate so the text can still show/hide in combat.
        teleportButton = createDungeonTeleportButton(UIParent, 1)
        teleportButton:Hide()
        teleportButton:ClearAllPoints()
        teleportButton:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
        teleportButton:SetSize(110, 28)
        teleportButton:SetFrameStrata("FULLSCREEN_DIALOG")
        RegisterStateDriver(teleportButton, "visibility", "[combat] hide;")
    end
    local visible = teleportMapID ~= nil and GetTime() < announcementEndsAt
    updateDungeonTeleportButton(teleportButton, visible and teleportMapID or nil)
    if visible and announcementFrame then
        -- Use coordinates, never anchor a protected button to a FontString.
        local bottom = announcementFrame.subtitle:GetBottom()
        if bottom then
            local scale = announcementFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
            teleportButton:ClearAllPoints()
            teleportButton:SetPoint("TOP", UIParent, "BOTTOMLEFT", UIParent:GetWidth() / 2, bottom * scale - 16)
        end
    end
    teleportButton:SetShown(visible)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", updateAnnouncementTeleport)

function showRaidBreakKeystoneAnnouncement(dungeon, level, owner, insertReminder, mapID)
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
    local duration = insertReminder and 7 or 15
    teleportMapID = not insertReminder and mapID or nil
    announcementEndsAt = GetTime() + duration
    updateAnnouncementTeleport()
    hideTimer = C_Timer.NewTimer(duration, function()
        announcementFrame:Hide()
        teleportMapID = nil
        announcementEndsAt = 0
        updateAnnouncementTeleport()
        hideTimer = nil
    end)
end
