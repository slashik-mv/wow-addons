local warningFrame
local teleportButton
local hideTimer
local teleportMapID
local endsAt = 0
local preview = false
local WARNING_DURATION_SECONDS = 7

local function UpdateTeleport()
    if InCombatLockdown() then return end
    if not teleportButton then
        teleportButton = createInviteDungeonTeleportButton(UIParent)
        teleportButton:Hide()
        teleportButton:SetFrameStrata("FULLSCREEN_DIALOG")
        RegisterStateDriver(teleportButton, "visibility", "[combat] hide;")
    end
    local visible = not preview and teleportMapID ~= nil and GetTime() < endsAt
    updateInviteDungeonTeleportButton(teleportButton, visible and teleportMapID or nil)
    if visible and warningFrame then
        -- Only coordinates connect the secure button to the movable text frame.
        local bottom = warningFrame.text:GetBottom()
        local x = warningFrame:GetCenter()
        if bottom and x then
            local scale = warningFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
            teleportButton:ClearAllPoints()
            teleportButton:SetPoint("TOP", UIParent, "BOTTOMLEFT", x * scale, bottom * scale - 16)
        end
    end
    teleportButton:SetShown(visible)
end

local function ApplyPosition()
    local settings = getSetting()
    warningFrame:ClearAllPoints()
    warningFrame:SetPoint("CENTER", UIParent, "CENTER", settings.warningX, settings.warningY)
end

local function CenterOffsets(frame)
    local x, y = frame:GetCenter()
    local cx, cy = UIParent:GetCenter()
    if not x or not y or not cx or not cy then return end
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * scale - cx, y * scale - cy
end

local function UpdateCoordinates(frame)
    local x, y = CenterOffsets(frame)
    if x and y then
        frame.coordinates:SetText(string.format("X: %d   Y: %d", math.floor(x + 0.5), math.floor(y + 0.5)))
    end
end

local function StopDragging(frame)
    frame:StopMovingOrSizing()
    frame:SetScript("OnUpdate", nil)
    if frame.dragging then
        local x, y = CenterOffsets(frame)
        if x and y then
            local settings = getSetting()
            settings.warningX, settings.warningY = x, y
        end
        frame.dragging = nil
    end
    ApplyPosition()
    UpdateCoordinates(frame)
    UpdateTeleport()
end

local function GetWarningFrame()
    if warningFrame then return warningFrame end
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    warningFrame = frame
    frame:SetSize(800, 200)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.text:SetPoint("CENTER")
    frame.text:SetWidth(800)
    local font, _, flags = frame.text:GetFont()
    frame.text:SetFont(font, 60, flags)
    frame.caption = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.caption:SetPoint("BOTTOM", 0, 8)
    frame.caption:SetText("PREVIEW - drag to move")
    frame.caption:Hide()
    frame.coordinates = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.coordinates:SetPoint("TOP", frame, "BOTTOM", 0, -4)
    frame.coordinates:Hide()
    frame:SetScript("OnDragStart", function(self)
        if not preview or InCombatLockdown() then return end
        self.dragging = true
        self:StartMoving()
        self:SetScript("OnUpdate", UpdateCoordinates)
    end)
    frame:SetScript("OnDragStop", StopDragging)
    ApplyPosition()
    frame:Hide()
    return frame
end

function stopInviteWarningPreview()
    if not preview then return end
    preview = false
    StopDragging(warningFrame)
    warningFrame:EnableMouse(false)
    warningFrame.caption:Hide()
    warningFrame.coordinates:Hide()
    warningFrame:SetBackdrop(nil)
    warningFrame:Hide()
end

function startInviteWarningPreview()
    if InCombatLockdown() then
        print("Move the invitation notification outside combat.")
        return
    end
    local frame = GetWarningFrame()
    if hideTimer then hideTimer:Cancel(); hideTimer = nil end
    teleportMapID, endsAt = nil, 0
    preview = true
    frame.text:SetText("Dungeon invitation")
    frame:EnableMouse(true)
    frame.caption:Show()
    frame.coordinates:Show()
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(0.03, 0.04, 0.06, 0.65)
    frame:SetBackdropBorderColor(0.4, 0.6, 0.8, 0.8)
    ApplyPosition()
    frame:Show()
    UpdateCoordinates(frame)
    UpdateTeleport()
end

function resetInviteWarningPosition()
    if InCombatLockdown() then
        print("Reset the invitation notification position outside combat.")
        return
    end
    if warningFrame and warningFrame.dragging then StopDragging(warningFrame) end
    local settings = getSetting()
    settings.warningX, settings.warningY = 0, 0
    if warningFrame then ApplyPosition(); UpdateCoordinates(warningFrame) end
    UpdateTeleport()
end

local function ShowBigTextInCenter(msg, duration, mapID)
    stopInviteWarningPreview()
    local frame = GetWarningFrame()
    if hideTimer then hideTimer:Cancel() end
    frame.text:SetText(msg)
    frame:Show()
    teleportMapID = mapID
    endsAt = GetTime() + duration
    UpdateTeleport()
    hideTimer = C_Timer.NewTimer(duration, function()
        frame:Hide()
        teleportMapID, endsAt, hideTimer = nil, 0, nil
        UpdateTeleport()
    end)
end

function printWarning(msg, activityID)
    print("►►► Group Name: " .. msg)
    if getSetting().enabledScreenWarning == true then
        ShowBigTextInCenter(msg, WARNING_DURATION_SECONDS, getInviteDungeonMapID(activityID))
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then stopInviteWarningPreview() end
    UpdateTeleport()
end)

function SendGreetingToGroup()
    local message = getSetting().greetingMessage
    if not message:find("%S") then return end
    local channel

    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        channel = "INSTANCE_CHAT"
    elseif IsInRaid() then
        channel = "RAID"
    elseif IsInGroup() then
        channel = "PARTY"
    end

    if channel then
        SendChatMessage(message, channel)
    end
end
