-- Local, click-to-cast recovery shortcut. Independent of optional ready-check reminders.
local spells = {
    PRIEST = 212036, -- Mass Resurrection
    PALADIN = 212056, -- Absolution
    DRUID = 212040, -- Revitalize
    SHAMAN = 212048, -- Ancestral Vision
    MONK = 212051, -- Reawaken
    EVOKER = 361178, -- Mass Return
}
local panel, ticker, spellID
local deadline = 0

local function secret(value)
    return issecretvalue and issecretvalue(value)
end

local function inRaidInstance()
    local _, kind = GetInstanceInfo()
    return IsInRaid() and kind == "raid"
end

local function stop()
    deadline = 0
    if ticker then ticker:Cancel(); ticker = nil end
    if panel then panel:Hide() end
end

local function normalLivingPlayer()
    if InCombatLockdown() or (C_Secrets and C_Secrets.ShouldAurasBeSecret()) then return false end
    local dead, ghost = UnitIsDeadOrGhost("player"), UnitIsGhost("player")
    if secret(dead) or secret(ghost) or dead or ghost then return false end
    -- Spirit form can look alive to unit APIs; require readable absence of its aura.
    for index = 1, 255 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
        if secret(aura) then return false end
        if not aura then return true end
        if secret(aura.spellId) then return false end
        if aura.spellId == 27827 or aura.spellId == 290114 then return false end
    end
    return false
end

local function createPanel()
    panel = CreateFrame("Frame", "SlashikRaidBreakTimeMassResurrectionFrame", UIParent)
    panel:SetSize(300, 80)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, -115)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    -- This Blizzard template permits click-casting only outside combat and does not
    -- protect its parents, so hiding this independent prompt in combat remains safe.
    local cast = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate,InsecureActionButtonTemplate")
    cast:SetSize(220, 32)
    cast:SetPoint("TOP", panel, "TOP", 0, 0)
    cast:SetText("Mass Resurrect")
    cast:RegisterForClicks("AnyUp", "AnyDown")
    cast:SetAttribute("useOnKeyDown", false)
    cast:SetAttribute("type", "spell")
    cast:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if spellID then GameTooltip:SetSpellByID(spellID) end
        GameTooltip:Show()
    end)
    cast:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.cast = cast
    local dismiss = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    dismiss:SetSize(90, 22)
    dismiss:SetPoint("TOP", cast, "BOTTOM", 0, -6)
    dismiss:SetText("Dismiss")
    dismiss:SetScript("OnClick", stop)
    panel:Hide()
end

local function update()
    if deadline == 0 then return end
    if GetTime() >= deadline or not inRaidInstance() then stop(); return end
    if InCombatLockdown() then
        if panel then panel:Hide() end
        return -- Never create or configure spell buttons during combat lockdown.
    end
    local _, class = UnitClass("player")
    spellID = spells[class]
    local known = spellID and C_SpellBook.IsSpellKnown(spellID)
    -- Offer the shortcut even when testing alone or nobody else is currently dead.
    if secret(known) or not known or not normalLivingPlayer() then
        if panel then panel:Hide() end
        return
    end
    if not panel then createPanel() end
    panel.cast:SetAttribute("spell", spellID)
    -- Do not interrupt an existing cast. Failed/interrupted casts enable retry.
    local casting = UnitCastingInfo("player")
    local channeling = UnitChannelInfo("player")
    panel.cast:SetEnabled(not secret(casting) and not secret(channeling) and not casting and not channeling)
    panel:Show()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "ENCOUNTER_END", "ENCOUNTER_START", "PLAYER_ENTERING_WORLD",
    "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_DEAD", "UNIT_AURA",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "SPELLS_CHANGED" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_START" or event == "PLAYER_ENTERING_WORLD" then
        stop()
    elseif event == "ENCOUNTER_END" then
        local _, _, _, _, success = ...
        stop()
        if success ~= 0 or not inRaidInstance() then return end
        -- Allow time for a Soulstone/Restitution revival, then expire automatically.
        deadline = GetTime() + 90
        ticker = C_Timer.NewTicker(0.5, update)
        update()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, castSpellID = ...
        if unit == "player" and not secret(castSpellID) and spellID and castSpellID == spellID then stop() end
    elseif event == "UNIT_AURA" or event:match("^UNIT_SPELLCAST_") then
        if (...) == "player" then update() end
    else
        update()
    end
end)
