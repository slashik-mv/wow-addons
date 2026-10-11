local _, addon = ...
local colors = {
    healthy = { 0.15, 1, 0.08 }, low = { 0.72, 0.5, 0.02 },
    missing = { 1, 0.08, 0.06 }, unknown = { 0.6, 0.65, 0.7 },
}

-- Two tapered arcs, drawn with native lines so no external textures are needed.
local function arc(parent, side)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(210, 100)
    frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
    frame.lines = {}
    for i = 1, 18 do
        local a = math.rad(28 + (i - 1) * 38 / 18)
        local b = math.rad(28 + i * 38 / 18)
        local line = frame:CreateLine(nil, "ARTWORK")
        line:SetThickness(2 + 3 * math.sin(i / 19 * math.pi))
        line:SetStartPoint("CENTER", side * 67 * math.cos(a), -40 + 67 * math.sin(a))
        line:SetEndPoint("CENTER", side * 67 * math.cos(b), -40 + 67 * math.sin(b))
        frame.lines[#frame.lines + 1] = line
    end
    -- Move the arc's layout anchor instead of applying an AnimationGroup
    -- translation to native Line regions. A continuous cosine wave has zero
    -- velocity at both turning points and no reverse-loop transform boundary.
    local animation = { playing = false, elapsed = 0 }
    function animation:IsPlaying() return self.playing end
    function animation:Play()
        if self.playing then return end
        self.playing, self.elapsed = true, 0
        frame:SetScript("OnUpdate", function(_, elapsed)
            self.elapsed = (self.elapsed + elapsed) % 0.56
            local offset = 6.5 * (1 - math.cos(self.elapsed * 2 * math.pi / 0.56))
            frame:SetPoint("CENTER", parent, "CENTER", 0, offset)
        end)
    end
    function animation:Stop()
        if not self.playing then return end
        self.playing, self.elapsed = false, 0
        frame:SetScript("OnUpdate", nil)
        frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
    end
    frame.bounce = animation
    return frame
end

function addon:CreateTrackerFrame(name, getSettings)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(210, 100)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)
    frame.arcs = { arc(frame, -1), arc(frame, 1) }
    frame.count = frame:CreateFontString(nil, "OVERLAY")
    frame.count:SetFont(STANDARD_TEXT_FONT, 26, "OUTLINE")
    frame.count:SetPoint("CENTER", 0, 23)
    frame.timer = frame:CreateFontString(nil, "OVERLAY")
    frame.timer:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    frame.timer:SetPoint("RIGHT", frame, "CENTER", -70, 17)
    frame.timer:SetTextColor(1, 1, 1)
    frame.rightTimer = frame:CreateFontString(nil, "OVERLAY")
    frame.rightTimer:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    frame.rightTimer:SetPoint("LEFT", frame, "CENTER", 70, 17)
    frame.rightTimer:SetTextColor(1, 1, 1)
    frame.caption = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.caption:SetPoint("BOTTOM", 0, 5)
    frame.caption:SetText("PREVIEW - drag to move")
    frame.caption:Hide()
    frame.coordinates = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.coordinates:SetPoint("TOP", frame, "BOTTOM", 0, -4)
    frame.coordinates:Hide()

    function frame:GetCenterOffsets()
        local x, y = self:GetCenter()
        local cx, cy = UIParent:GetCenter()
        if not x or not y or not cx or not cy then return end
        local ratio = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return x * ratio - cx, y * ratio - cy
    end

    function frame:UpdateCoordinates()
        local x, y = self:GetCenterOffsets()
        if x and y then
            self.coordinates:SetText(string.format("X: %d   Y: %d", math.floor(x + 0.5), math.floor(y + 0.5)))
        end
    end

    function frame:ApplyPosition()
        local settings = getSettings()
        self:SetScale(settings.scale)
        self:ClearAllPoints()
        -- Store offsets in UIParent coordinates independently of tracker scale.
        self:SetPoint("CENTER", UIParent, "CENTER", settings.x / settings.scale, settings.y / settings.scale)
    end

    function frame:SetPreview(on)
        if self.dragging then self:StopMovingOrSizing(); self.dragging = nil end
        self:SetScript("OnUpdate", nil)
        self:EnableMouse(on)
        self.caption:SetShown(on)
        self.coordinates:SetShown(on)
        self:SetBackdrop(on and { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 } or nil)
        if on then
            self:SetBackdropColor(0.03, 0.04, 0.06, 0.65)
            self:SetBackdropBorderColor(0.4, 0.6, 0.8, 0.8)
        end
        self:ApplyPosition()
        if on then self:UpdateCoordinates() end
    end

    function frame:Render(state, count, seconds, bounce, rightSeconds)
        local color = colors[state]
        self.count:SetText(count)
        if InCombatLockdown() then
            self.count:SetTextColor(1, 1, 1)
        else
            self.count:SetTextColor(unpack(color))
        end
        self.timer:SetText(seconds)
        self.rightTimer:SetText(rightSeconds)
        for _, curve in ipairs(self.arcs) do
            for _, line in ipairs(curve.lines) do line:SetColorTexture(unpack(color)) end
            if state == "missing" and bounce then
                if not curve.bounce:IsPlaying() then curve.bounce:Play() end
            else
                curve.bounce:Stop()
            end
        end
        self:Show()
    end

    frame:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self.dragging = true
        self:StartMoving()
        self:SetScript("OnUpdate", self.UpdateCoordinates)
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.dragging = nil
        if not InCombatLockdown() then
            local x, y = self:GetCenterOffsets()
            if x and y then
                local settings = getSettings()
                settings.x, settings.y = x, y
            end
        end
        self:SetScript("OnUpdate", nil)
        self:ApplyPosition()
        self:UpdateCoordinates()
    end)
    frame:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        for _, curve in ipairs(self.arcs) do curve.bounce:Stop() end
    end)
    frame:ApplyPosition()
    frame:Hide()
    return frame
end
