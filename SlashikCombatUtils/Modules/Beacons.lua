local _, addon = ...
local module = { title = "Beacon Reminder", description = "Holy Paladin with Beacon of Faith: missing beacon warnings.", spells = {53563, 156910} }
addon:RegisterModule("beacons", module)
local function secret(value) return issecretvalue and issecretvalue(value) end
local function read(fn, ...)
    if not fn then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or secret(value) then return nil end
    return value
end
function module:Eligible()
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    return class == "PALADIN" and spec and GetSpecializationInfo(spec) == 65
        and read(C_SpellBook and C_SpellBook.IsSpellKnown, 156910) == true
end
function module:ScanUnit(unit, id, name)
    -- Enumerate actual helpful auras, rather than rejecting a spell up front based
    -- on its potential secrecy. Match readable spell identity and player ownership.
    local uncertain
    for index = 1, 255 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
        if not ok then return "unknown", "aura query failed" end
        if secret(aura) then return "unknown", "restricted aura data" end
        if not aura then return uncertain and "unknown" or "missing", uncertain end
        local sid, auraName = aura.spellId, aura.name
        local readableID = not secret(sid) and type(sid) == "number"
        local readableName = not secret(auraName) and type(auraName) == "string"
        local matches = (readableID and sid == id) or (readableName and name and auraName == name)
        if matches or (not readableID and not readableName) then
            local source = aura.sourceUnit
            local mine
            if not secret(source) and type(source) == "string" then mine = read(UnitIsUnit, source, "player") end
            if matches and mine == true then return "present", "owned aura found" end
            if mine ~= false then uncertain = "restricted aura identity or caster" end
        end
    end
    return "unknown", "aura scan limit"
end
function module:Scan(id)
    local name = read(C_Spell and C_Spell.GetSpellName, id)
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return "unknown", "aura API unavailable" end
    local units, uncertain = {}, nil
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    else
        units[1] = "player"
        for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
    end
    local checked, skipped = 0, 0
    for _, unit in ipairs(units) do
        local connectedOK, connected = pcall(UnitIsConnected, unit)
        local visibleOK, visible = pcall(UnitIsVisible, unit)
        if not connectedOK or not visibleOK or secret(connected) or secret(visible) then
            uncertain = "restricted visibility or connection"
        elseif not connected or not visible then
            -- A distant/offline player should not suppress warnings for the local group.
            skipped = skipped + 1
        else
            local dead = read(UnitIsDeadOrGhost, unit)
            if dead == false then
                checked = checked + 1
                local state, reason = self:ScanUnit(unit, id, name)
                if state == "present" then return state, reason end
                if state == "unknown" then uncertain = reason end
            elseif dead == nil then uncertain = "restricted life status" end
        end
    end
    if checked == 0 and not uncertain then uncertain = "no observable living members" end
    local reason = uncertain or ("no owned aura on observable members; skipped " .. skipped .. " offline/out-of-view")
    return uncertain and "unknown" or "missing", reason
end
function module:CreateDisplay()
    if self.frame then return end
    local frame = CreateFrame("Frame", "SlashikCombatUtilsBeaconReminder", UIParent)
    frame:SetSize(140, 90)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    self.frame, self.icons = frame, {}
    for i, id in ipairs(self.spells) do
        local icon = CreateFrame("Frame", nil, frame)
        icon:SetSize(48, 48)
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.texture:SetTexture(C_Spell.GetSpellTexture(id))
        icon.label = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        icon.label:SetPoint("TOP", icon, "BOTTOM", 0, -4)
        icon.label:SetText(i == 1 and "Light missing" or "Faith missing")
        self.icons[i] = icon
    end
    self.elapsed = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        self.elapsed = self.elapsed + elapsed
        self:PositionIcons()
    end)
end
function module:PositionIcons()
    local settings = addon:GetSettings().beacons
    local count = (self.icons[1]:IsShown() and 1 or 0) + (self.icons[2]:IsShown() and 1 or 0)
    local n = 0
    local offset = settings.bounce and (1 - math.cos(self.elapsed * math.pi * 2 / 0.7)) * 6 or 0
    for _, icon in ipairs(self.icons) do
        if icon:IsShown() then
            n = n + 1
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", self.frame, "CENTER", (n - (count + 1) / 2) * 90, offset)
        end
    end
end
function module:Update()
    if not self.enabled then return end
    if self.preview and InCombatLockdown() then self.preview = nil end
    if not self.preview and (not self:Eligible() or not IsInGroup() or read(UnitIsDeadOrGhost, "player") ~= false) then
        self.status, self.reasons = { "inactive", "inactive" }, nil
        if self.frame then self.frame:Hide() end
        return
    end
    self:CreateDisplay()
    local settings = addon:GetSettings().beacons
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", settings.x, settings.y)
    self.frame:SetScale(settings.scale)
    if self.preview then
        self.status, self.reasons = { "missing", "missing" }, { "preview", "preview" }
    else
        local light, lightReason = self:Scan(53563)
        local faith, faithReason = self:Scan(156910)
        self.status, self.reasons = { light, faith }, { lightReason, faithReason }
    end
    for i, icon in ipairs(self.icons) do icon:SetShown(self.status[i] == "missing") end
    self:PositionIcons()
    self.frame:SetShown(self.status[1] == "missing" or self.status[2] == "missing")
end
function module:StartPreview()
    if not addon:CanEdit() or not self.enabled then return end
    self.preview = true
    self:Update()
end
function module:StopPreview() self.preview = nil; self:Update() end
function module:Debug()
    self:Update()
    local state = self.status or { "inactive", "inactive" }
    if self.reasons then addon:Print("Beacon scan: Light=" .. self.reasons[1] .. "; Faith=" .. self.reasons[2]) end
    addon:Print("Beacons: Light=" .. state[1] .. ", Faith=" .. state[2] .. ". Unknown means restricted data or no observable members; missing checks exclude offline/out-of-view players.")
end
function module:Enable()
    self.enabled = true
    if not self.events then self.events = CreateFrame("Frame") end
    -- Ignore potentially secret event payloads; rescan fixed party/raid unit tokens.
    self.events:SetScript("OnEvent", function() self.dirty = true end)
    for _, event in ipairs({"UNIT_AURA", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "SPELLS_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_HEALTH", "UNIT_CONNECTION"}) do self.events:RegisterEvent(event) end
    self.poll = 0
    self.events:SetScript("OnUpdate", function(_, elapsed)
        self.poll = self.poll + elapsed
        if self.poll >= (self.dirty and 0.15 or 1) then self.poll = 0; self.dirty = false; self:Update() end
    end)
    self:Update()
end
function module:Disable()
    self.enabled, self.preview = false, nil
    self.status, self.reasons = { "disabled", "disabled" }, nil
    if self.events then self.events:UnregisterAllEvents(); self.events:SetScript("OnUpdate", nil) end
    if self.frame then self.frame:Hide() end
end
