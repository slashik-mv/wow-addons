local _, addon = ...
local module = { title = "Battle Ress and Lust", description = "Shared battle resurrection charges and your Sated / Exhaustion timer." }
addon:RegisterModule("battleResLust", module)

-- Same data sources as BResLustTracker: Rebirth's shared charges and player lockout auras.
-- Independent implementation; no dependency on the standalone addon's frames or saved variables.
local lockouts = {57723, 57724, 80354, 264689, 390435, 160455, 357745}
local function secret(value) return issecretvalue and issecretvalue(value) end
local function numeric(value) return not secret(value) and type(value) == "number" end
local function settings() return addon:GetSettings().battleResLust end
local function timeText(seconds)
    local whole = math.max(0, math.ceil(seconds))
    return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end
local function text(parent, size, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
    label:SetPoint("TOPLEFT", x, y)
    label:SetTextColor(1, 1, 1)
    return label
end
local function row(parent, icon)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(180, 48)
    frame.icon = frame:CreateTexture(nil, "BACKGROUND")
    frame.icon:SetSize(48, 48); frame.icon:SetPoint("TOPLEFT"); frame.icon:SetTexture(icon)
    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints(frame.icon); frame.cooldown:SetHideCountdownNumbers(true)
    frame.label = text(frame, 18, 54, 0)
    frame.count = text(frame, 26, 99, 3)
    frame.timer = text(frame, 24, 54, -22)
    return frame
end
function module:ApplyPosition()
    if not self.frame then return end
    local s, frame = settings(), self.frame
    frame:SetScale(s.scale); frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", s.x / s.scale, s.y / s.scale)
end
function module:SavePosition()
    local frame = self.frame
    local x, y = frame:GetCenter()
    local cx, cy = UIParent:GetCenter()
    if x and y and cx and cy then
        local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        settings().x, settings().y = x * ratio - cx, y * ratio - cy
    end
end
function module:CreateDisplay()
    if self.frame then return end
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(180, 104); frame:SetFrameStrata("LOW"); frame:SetClampedToScreen(true)
    frame:SetMovable(true); frame:RegisterForDrag("LeftButton"); frame:EnableMouse(false)
    frame.res = row(frame, 136080); frame.res.label:SetText("Res:")
    frame.lust = row(frame, 136012)
    frame.caption = text(frame, 12, 0, 22)
    frame.caption:Hide()
    frame:SetScript("OnDragStart", function()
        if self.preview and addon:CanEdit() then frame.dragging = true; frame:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing(); frame.dragging = nil
        if addon:CanEdit() then self:SavePosition() end
        self:ApplyPosition()
    end)
    self:ApplyPosition(); frame:Hide()
end
function module:SyncLust()
    self.lustAura, self.lustUnknown = nil, false
    if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then self.lustUnknown = true; return end
    for _, id in ipairs(lockouts) do
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
        if not ok or secret(aura) then self.lustUnknown = true
        elseif aura then self.lustAura = aura; return end
    end
end
function module:RenderRes()
    local r = self.frame.res
    r.label:SetText("Res:")
    r.cooldown:Clear(); r.timer:SetText(""); r.count:SetText("?"); r.count:SetTextColor(0.65, 0.65, 0.65)
    local ok, info = pcall(C_Spell.GetSpellCharges, 20484)
    if not ok or secret(info) or not info then r.label:SetText(""); r.count:SetText(""); return end
    local count, maximum = info.currentCharges, info.maxCharges
    if numeric(maximum) and maximum <= 0 then r.label:SetText(""); r.count:SetText(""); return end
    -- The count can be handed directly to the font string even when restricted.
    if secret(count) then r.count:SetText(count)
    elseif numeric(count) then
        r.count:SetText(count); r.count:SetTextColor(count > 0 and 0 or 1, count > 0 and 1 or 0, 0)
    end
    local start, duration, rate = info.cooldownStartTime, info.cooldownDuration, info.chargeModRate
    if numeric(count) and numeric(maximum) and count >= maximum then r.timer:SetText("Ready"); return end
    if numeric(start) and numeric(duration) and (numeric(rate) or (not secret(rate) and rate == nil)) then
        rate = rate or 1
        if start > 0 and duration > 0 and rate > 0 then
            local remaining = start + duration / rate - GetTime()
            if remaining > 0 then r.timer:SetText(timeText(remaining)); r.cooldown:SetCooldown(start, duration, rate) end
        end
    else
        r.timer:SetText("?")
    end
end
function module:RenderLust()
    local r, aura = self.frame.lust, self.lustAura
    r.cooldown:Clear(); r.icon:SetTexture(136012)
    r.label:SetText("Lust"); r.timer:SetText("Ready"); r.timer:SetTextColor(0, 1, 0)
    if aura then
        r.label:SetText(""); r.timer:SetTextColor(1, 0.1, 0.1)
        if secret(aura.icon) or aura.icon ~= nil then r.icon:SetTexture(aura.icon) end
        local expiration, duration = aura.expirationTime, aura.duration
        if numeric(expiration) and expiration > 0 then
            local remaining = expiration - GetTime()
            if remaining > 0 then
                r.timer:SetText(timeText(remaining))
                if numeric(duration) and duration > 0 then r.cooldown:SetCooldown(expiration - duration, duration) end
            else
                r.label:SetText("Lust"); r.timer:SetText("Ready"); r.timer:SetTextColor(0, 1, 0)
            end
        else r.timer:SetText("?") end
    elseif self.lustUnknown then
        r.timer:SetText("?"); r.timer:SetTextColor(0.65, 0.65, 0.65)
    end
end
function module:Update()
    if not self.enabled or not self.frame then return end
    local s, frame = settings(), self.frame
    if self.preview and InCombatLockdown() then self:StopPreview(); return end
    local _, location = GetInstanceInfo()
    local allowed = (location == "party" and s.showInDungeon) or (location == "raid" and s.showInRaid)
        or (location ~= "party" and location ~= "raid" and s.showInWorld)
    if not (s.showRes or s.showLust) or (not self.preview and (not allowed or (s.combatOnly and not InCombatLockdown()))) then frame:Hide(); return end
    frame.res:SetShown(s.showRes); frame.lust:SetShown(s.showLust)
    frame.res:ClearAllPoints(); frame.res:SetPoint("TOPLEFT", 0, 0)
    frame.lust:ClearAllPoints(); frame.lust:SetPoint("TOPLEFT", 0, s.showRes and -56 or 0)
    frame:SetHeight(s.showRes and s.showLust and 104 or 48)
    if self.preview then
        frame.res.label:SetText("Res:"); frame.res.count:SetText("1"); frame.res.count:SetTextColor(0, 1, 0); frame.res.timer:SetText("7:29"); frame.res.cooldown:Clear()
        frame.lust.label:SetText(""); frame.lust.timer:SetText("9:32"); frame.lust.timer:SetTextColor(1, 0.1, 0.1); frame.lust.cooldown:Clear()
        if frame.dragging then self:SavePosition() end
        frame.caption:SetText(string.format("Drag to move   X: %d   Y: %d", math.floor(s.x + 0.5), math.floor(s.y + 0.5)))
    else
        if s.showRes then self:RenderRes() end
        if s.showLust then self:RenderLust() end
    end
    frame:Show()
end
function module:StartPreview()
    if not self.enabled or not addon:CanEdit() then return end
    self.preview = true; self.frame:EnableMouse(true); self.frame.caption:Show(); self:Update()
end
function module:StopPreview()
    self.preview = false
    if self.frame then
        if self.frame.dragging then self.frame:StopMovingOrSizing(); self.frame.dragging = nil end
        self.frame:EnableMouse(false); self.frame.caption:Hide(); self:ApplyPosition()
    end
    if self.enabled then self:SyncLust(); self:Update() end
end
function module:Enable()
    if self.enabled then self:ApplyPosition(); self:Update(); return end
    self.enabled = true; self:CreateDisplay(); self:SyncLust()
    if not self.events then self.events = CreateFrame("Frame") end
    for _, event in ipairs({"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "SPELL_UPDATE_CHARGES", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET", "ENCOUNTER_START", "ENCOUNTER_END"}) do self.events:RegisterEvent(event) end
    self.events:RegisterUnitEvent("UNIT_AURA", "player")
    self.events:SetScript("OnEvent", function() self:SyncLust(); self:Update() end)
    self.elapsed, self.auraElapsed = 0, 0
    self.events:SetScript("OnUpdate", function(_, elapsed)
        self.elapsed, self.auraElapsed = self.elapsed + elapsed, self.auraElapsed + elapsed
        if self.auraElapsed >= 1 then self.auraElapsed = 0; self:SyncLust() end
        if self.elapsed >= 0.1 then self.elapsed = 0; self:Update() end
    end)
    self:Update()
end
function module:Disable()
    self.enabled = false; self:StopPreview()
    if self.events then self.events:UnregisterAllEvents(); self.events:SetScript("OnUpdate", nil); self.events:SetScript("OnEvent", nil) end
    if self.frame then self.frame:Hide() end
end
