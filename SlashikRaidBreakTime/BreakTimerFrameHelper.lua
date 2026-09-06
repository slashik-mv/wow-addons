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

    -- Tracks the live countdown and the current illustration while the UI is loaded.
    local breakEndTime = 0
    local currentImageIndex = 1
    local nextImageChangeTime = 0

    local function scheduleNextImageChange(nextImageChangeAt)
        local settings = getSettings()
        if not settings.randomImages then
            nextImageChangeTime = math.huge
            return nil
        end

        local serverTime = GetServerTime()
        nextImageChangeAt = tonumber(nextImageChangeAt) or (serverTime + settings.randomTimerMinutes * 60)
        nextImageChangeTime = GetTime() + math.max(0, nextImageChangeAt - serverTime)
        return nextImageChangeAt
    end

    local function formatTime(seconds)
        seconds = math.max(0, math.ceil(seconds))
        return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
    end

    function frame:hideBreak()
        breakEndTime = 0
        nextImageChangeTime = 0
        if SlashikRaidBreakTimeDB then
            SlashikRaidBreakTimeDB.activeBreak = nil
        end
        self:Hide()
    end

    function frame:showBreak(seconds, imageIndex, nextImageChangeAt)
        SlashikRaidBreakTimeDB = SlashikRaidBreakTimeDB or {}
        currentImageIndex = tonumber(imageIndex) or 1
        if currentImageIndex < 1 or currentImageIndex > #images then
            currentImageIndex = 1
        end

        breakEndTime = GetTime() + seconds
        nextImageChangeAt = scheduleNextImageChange(nextImageChangeAt)
        self.art:SetTexture(images[currentImageIndex])
        SlashikRaidBreakTimeDB.activeBreak = {
            endAt = GetServerTime() + seconds,
            imageIndex = currentImageIndex,
            nextImageChangeAt = nextImageChangeAt,
        }
        self:Show()
    end

    function frame:showNextImage()
        local settings = getSettings()
        if not settings.randomImages or #images < 2 then return end

        local nextImageIndex = math.random(#images - 1)
        if nextImageIndex >= currentImageIndex then
            nextImageIndex = nextImageIndex + 1
        end

        currentImageIndex = nextImageIndex
        local nextImageChangeAt = scheduleNextImageChange()
        self.art:SetTexture(images[currentImageIndex])

        local activeBreak = SlashikRaidBreakTimeDB and SlashikRaidBreakTimeDB.activeBreak
        if activeBreak then
            activeBreak.imageIndex = currentImageIndex
            activeBreak.nextImageChangeAt = nextImageChangeAt
        end
    end

    function frame:setRandomImagesEnabled(enabled)
        local settings = getSettings()
        settings.randomImages = enabled

        local activeBreak = SlashikRaidBreakTimeDB.activeBreak
        if enabled then
            local nextImageChangeAt = scheduleNextImageChange()
            if activeBreak then
                activeBreak.nextImageChangeAt = nextImageChangeAt
            end
        else
            nextImageChangeTime = math.huge
            if activeBreak then
                activeBreak.nextImageChangeAt = nil
            end
        end
    end

    function frame:setRandomTimerMinutes(minutes)
        minutes = tonumber(minutes)
        if not minutes or minutes ~= math.floor(minutes) or minutes < 1 or minutes > 120 then
            return false
        end

        local settings = getSettings()
        settings.randomTimerMinutes = minutes

        if settings.randomImages and self:IsShown() then
            local nextImageChangeAt = scheduleNextImageChange()
            local activeBreak = SlashikRaidBreakTimeDB.activeBreak
            if activeBreak then
                activeBreak.nextImageChangeAt = nextImageChangeAt
            end
        end
        return true
    end

    function frame:getRandomTimerMinutes()
        return getSettings().randomTimerMinutes
    end

    function frame:isRandomImagesEnabled()
        return getSettings().randomImages
    end

    function frame:resetRandomImageSettings()
        resetSettingsToDefault()

        if self:IsShown() then
            local nextImageChangeAt = scheduleNextImageChange()
            local activeBreak = SlashikRaidBreakTimeDB.activeBreak
            if activeBreak then
                activeBreak.nextImageChangeAt = nextImageChangeAt
            end
        end
    end

    function frame:restoreBreakAfterReload()
        SlashikRaidBreakTimeDB = SlashikRaidBreakTimeDB or {}
        local activeBreak = SlashikRaidBreakTimeDB.activeBreak
        if not activeBreak or type(activeBreak.endAt) ~= "number" then return end

        local remaining = activeBreak.endAt - GetServerTime()
        if remaining > 0 then
            self:showBreak(remaining, activeBreak.imageIndex, activeBreak.nextImageChangeAt)
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
        elseif GetTime() >= nextImageChangeTime then
            self:showNextImage()
        end
    end)

    return frame
end
