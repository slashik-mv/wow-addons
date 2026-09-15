local _, ns = ...
local ASCENT, SECOND_WIND, SURGE = 372610, 425782, 361584
local function bar(parent)
    local frame = CreateFrame("StatusBar", nil, parent)
    frame:SetMinMaxValues(0, 1)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.art = frame:CreateTexture(nil, "OVERLAY")
    frame.art:SetAllPoints()
    frame.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.border:SetAllPoints()
    return frame
end
local function border(frame, theme)
    local style = theme.border
    frame:SetBackdrop(style and {edgeFile = style.texture, edgeSize = style.size} or nil)
    if style then frame:SetBackdropBorderColor(unpack(style.color)) end
end
local function styleBar(frame, theme, style, native)
    frame:SetOrientation(native and "VERTICAL" or "HORIZONTAL")
    frame:SetStatusBarTexture(native and style.atlas.fill or theme.texture)
    frame:SetStatusBarColor(unpack(style.color))
    frame.bg:ClearAllPoints()
    frame.bg:SetAllPoints()
    if native then
        frame.bg:SetAtlas(style.atlas.background)
        frame.bg:SetVertexColor(1, 1, 1, 1)
        frame.art:SetAtlas(style.atlas.frame)
        frame.art:Show()
        -- Match the native atlas proportions instead of stretching its artwork.
        for _, pair in ipairs({{frame.bg, style.atlas.background}, {frame.art, style.atlas.frame}}) do
            local info = C_Texture.GetAtlasInfo(pair[2])
            local fill = C_Texture.GetAtlasInfo(style.atlas.fill)
            pair[1]:ClearAllPoints()
            pair[1]:SetPoint("CENTER")
            pair[1]:SetSize(frame:GetWidth() * info.width / fill.width, frame:GetHeight() * info.height / fill.height)
        end
        frame.border:SetBackdrop(nil)
    else
        frame.bg:SetColorTexture(unpack(theme.background))
        frame.art:Hide()
        border(frame.border, theme)
    end
end
local function hasAtlases(style)
    if not style.atlas or not C_Texture or not C_Texture.GetAtlasInfo then return false end
    for _, atlas in pairs(style.atlas) do if not C_Texture.GetAtlasInfo(atlas) then return false end end
    return true
end
function ns.CreateFlyingFrame()
    local frame = CreateFrame("Frame", "SlashikFlyingFrame", UIParent)
    frame:Hide()
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    local speed = bar(frame)
    speed.text = speed:CreateFontString(nil, "OVERLAY")
    speed.text:SetPoint("CENTER")
    local vigor, wind = {}, {}
    local icon = CreateFrame("Frame", nil, frame)
    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetAllPoints()
    icon.cd = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cd:SetAllPoints()
    icon.cd:SetDrawEdge(false)
    icon.border = CreateFrame("Frame", nil, icon.cd, "BackdropTemplate")
    icon.border:SetAllPoints(icon)
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOM", frame, "TOP", 0, 7)
    hint:SetText("SlashikFlying - drag to move; /sf lock")

    local theme
    local function layoutRow(row, count, style)
        local width = theme.width
        local slot = (width - (count - 1) * style.gap) / count
        local native = hasAtlases(style)
        local w, h = slot, style.height
        if native then
            local info = C_Texture.GetAtlasInfo(style.atlas.fill)
            h = math.min(h, slot * info.height / info.width)
            w = h * info.width / info.height
        end
        for i = 1, count do
            if not row[i] then row[i] = bar(frame) end
            row[i]:ClearAllPoints()
            row[i]:SetPoint("TOPLEFT", frame, "TOPLEFT", (i - 1) * (slot + style.gap) + (slot - w) / 2, style.y)
            row[i]:SetSize(w, h)
            styleBar(row[i], theme, style, native)
            row[i]:Show()
        end
        for i = count + 1, #row do row[i]:Hide() end
        row.count = count
    end
    function frame:ApplySettings()
        local s = ns.GetSettings()
        theme = ns.GetTheme()
        self:SetScale(s.scale)
        self:SetSize(theme.width + theme.gap + theme.icon.size, theme.height)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", s.x, s.y)
        speed:ClearAllPoints()
        speed:SetPoint("BOTTOMLEFT")
        speed:SetSize(theme.width, theme.speed.height)
        styleBar(speed, theme, theme.speed, false)
        speed.text:SetFont(theme.font, theme.fontSize, theme.fontFlags)
        layoutRow(wind, wind.count or 3, theme.wind)
        layoutRow(vigor, vigor.count or 6, theme.vigor)
        icon:ClearAllPoints()
        icon:SetPoint("RIGHT", self, "RIGHT", 0, 0)
        icon:SetSize(theme.icon.size, theme.icon.size)
        local crop = theme.icon.crop
        icon.tex:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
        border(icon.border, theme)
        self:EnableMouse(self.unlocked == true)
        hint:SetShown(self.unlocked == true)
    end
    frame:SetScript("OnDragStart", function(self) if self.unlocked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        local ratio = UIParent:GetEffectiveScale() / self:GetEffectiveScale()
        local s = ns.GetSettings()
        s.x, s.y = x - ux * ratio, y - uy * ratio
        self:ApplySettings()
    end)
    local function updateRow(row, spell, fallback, style)
        local info = C_Spell.GetSpellCharges(spell)
        local count = math.floor(ns.Number(info and info.maxCharges, fallback))
        count = math.max(1, math.min(12, count))
        if row.count ~= count then layoutRow(row, count, style) end
        local current = ns.Number(info and info.currentCharges, 0)
        local start = ns.Number(info and info.cooldownStartTime, 0)
        local duration = ns.Number(info and info.cooldownDuration, 0)
        local progress = duration > 0 and math.max(0, math.min(1, (GetTime() - start) / duration)) or 0
        for i = 1, count do
            row[i]:SetValue(i <= current and 1 or (i == current + 1 and progress or 0))
            row[i]:SetAlpha(i == current + 1 and 0.65 or 1)
        end
    end
    function frame:Refresh()
        if self.preview or self.unlocked then
            for _, row in ipairs({vigor, wind}) do
                for i = 1, row.count do row[i]:SetValue(1); row[i]:SetAlpha(1) end
            end
            speed:SetValue(0.65)
            speed.text:SetText("845%")
            icon.cd:Clear()
        else
            local gliding, _, velocity = C_PlayerInfo.GetGlidingInfo()
            local percent = gliding and ns.Number(velocity, 0) / 7 * 100 or 0
            speed:SetValue(math.max(0, math.min(1, percent / 1300)))
            speed.text:SetFormattedText("%d%%", math.floor(percent + 0.5))
            updateRow(vigor, ASCENT, 6, theme.vigor)
            updateRow(wind, SECOND_WIND, 3, theme.wind)
            local cd = C_Spell.GetSpellCooldown(SURGE)
            local start = ns.Number(cd and cd.startTime, 0)
            local duration = ns.Number(cd and cd.duration, 0)
            if duration > 1.5 and start + duration > GetTime() then
                icon.cd:SetCooldown(start, duration, ns.Number(cd.modRate, 1))
            else
                icon.cd:Clear()
            end
        end
        icon.tex:SetTexture(C_Spell.GetSpellTexture(SURGE) or 134400)
    end
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.05 then elapsed = 0; self:Refresh() end
    end)
    -- Hidden frames do not run OnUpdate, so dismounted characters do no polling.
    function frame:UpdateVisibility()
        local s = ns.GetSettings()
        local _, canGlide = C_PlayerInfo.GetGlidingInfo()
        local visible = s.enabled and ((IsMounted() and canGlide == true) or self.preview or self.unlocked)
        if s.hideInCombat and UnitAffectingCombat("player") then visible = false end
        self:SetShown(visible == true)
        if visible then self:Refresh() end
    end
    frame:ApplySettings()
    return frame
end
