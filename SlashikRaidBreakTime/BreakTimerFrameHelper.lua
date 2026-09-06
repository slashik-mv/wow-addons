function createRaidBreakTimeFrame(images)
    local frame = CreateFrame("Frame", "SlashikRaidBreakTimeFrame", UIParent, "BackdropTemplate")
    frame:SetSize(500, 270)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark" })
    frame:SetBackdropColor(0, 0, 0, 0.82)
    frame:Hide()

    frame.art = frame:CreateTexture(nil, "ARTWORK")
    frame.art:SetSize(250, 250)
    frame.art:SetPoint("LEFT", 10, 0)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.title:SetPoint("TOPLEFT", frame.art, "TOPRIGHT", 28, -42)
    frame.title:SetText("Raid Break")

    frame.timer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.timer:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -24)
    frame.timer:SetText("00:00")

    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.hint:SetPoint("TOPLEFT", frame.timer, "BOTTOMLEFT", 3, -18)
    frame.hint:SetText("Enjoy the break!")

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Tracks the live countdown while the UI is loaded.
    local breakEndTime = 0

    local function formatTime(seconds)
        seconds = math.max(0, math.ceil(seconds))
        return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
    end

    function frame:hideBreak()
        breakEndTime = 0
        if SlashikRaidBreakTimeDB then
            SlashikRaidBreakTimeDB.activeBreak = nil
        end
        self:Hide()
    end

    function frame:showBreak(seconds, imageIndex)
        SlashikRaidBreakTimeDB = SlashikRaidBreakTimeDB or {}
        imageIndex = imageIndex or 1
        breakEndTime = GetTime() + seconds
        self.art:SetTexture(images[imageIndex] or images[1])
        SlashikRaidBreakTimeDB.activeBreak = {
            endAt = GetServerTime() + seconds,
            imageIndex = imageIndex,
        }
        self:Show()
    end

    function frame:restoreBreakAfterReload()
        SlashikRaidBreakTimeDB = SlashikRaidBreakTimeDB or {}
        local activeBreak = SlashikRaidBreakTimeDB.activeBreak
        if not activeBreak or type(activeBreak.endAt) ~= "number" then return end

        local remaining = activeBreak.endAt - GetServerTime()
        if remaining > 0 then
            self:showBreak(remaining, activeBreak.imageIndex)
        else
            SlashikRaidBreakTimeDB.activeBreak = nil
        end
    end

    function frame:showCompatibleBreak(seconds)
        seconds = tonumber(seconds)
        if seconds and seconds > 0 and seconds <= 3600 then
            self:showBreak(seconds, math.random(#images))
        elseif seconds == 0 then
            self:hideBreak()
        end
    end

    frame:SetScript("OnUpdate", function(self)
        if not self:IsShown() then return end
        local remaining = breakEndTime - GetTime()
        self.timer:SetText(formatTime(remaining))
        if remaining <= 0 then
            self:hideBreak()
        end
    end)

    return frame
end
