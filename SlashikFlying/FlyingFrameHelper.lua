local _, ns = ...
local ASCENT, SECOND_WIND, SURGE = 372610, 425782, 361584
local function bar(parent, r, g, b)
    local frame = CreateFrame("StatusBar", nil, parent)
    frame:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    frame:SetMinMaxValues(0, 1)
    frame:SetStatusBarColor(r, g, b)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.07, 0.07, 0.08, 0.85)
    return frame
end
function ns.CreateFlyingFrame()
    local frame = CreateFrame("Frame", "SlashikFlyingFrame", UIParent)
    frame:Hide()
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    local speed = bar(frame, 0.05, 0.67, 0.76)
    speed.text = speed:CreateFontString(nil, "OVERLAY")
    speed.text:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    speed.text:SetPoint("CENTER")
    local vigor, wind = {}, {}
    local icon = CreateFrame("Frame", nil, frame)
    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetAllPoints()
    icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.cd = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cd:SetAllPoints()
    icon.cd:SetDrawEdge(false)
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOM", frame, "TOP", 0, 7)
    hint:SetText("SlashikFlying - drag to move; /sf lock")

    local function layoutRow(row, count, y, height, color)
        local width = ns.GetSettings().width
        for i = 1, count do
            if not row[i] then row[i] = bar(frame, unpack(color)) end
            row[i]:ClearAllPoints()
            row[i]:SetPoint("TOPLEFT", frame, "TOPLEFT", (i - 1) * (width + 2) / count, y)
            row[i]:SetSize((width - (count - 1) * 2) / count, height)
            row[i]:Show()
        end
        for i = count + 1, #row do row[i]:Hide() end
        row.count = count
    end
    function frame:ApplySettings()
        local s = ns.GetSettings()
        self:SetScale(s.scale)
        self:SetSize(s.width + 34, 32)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", s.x, s.y)
        speed:ClearAllPoints()
        speed:SetPoint("BOTTOMLEFT")
        speed:SetSize(s.width, 14)
        layoutRow(wind, wind.count or 3, 0, 6, {0.64, 0.32, 0.90})
        layoutRow(vigor, vigor.count or 6, -8, 8, {0.40, 0.58, 0.72})
        icon:SetPoint("TOPLEFT", self, "TOPLEFT", s.width + 2, 0)
        icon:SetSize(32, 32)
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
    local function updateRow(row, spell, fallback, y, height, color)
        local info = C_Spell.GetSpellCharges(spell)
        local count = math.floor(ns.Number(info and info.maxCharges, fallback))
        count = math.max(1, math.min(12, count))
        if row.count ~= count then layoutRow(row, count, y, height, color) end
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
            updateRow(vigor, ASCENT, 6, -8, 8, {0.40, 0.58, 0.72})
            updateRow(wind, SECOND_WIND, 3, 0, 6, {0.64, 0.32, 0.90})
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
