local _, addon = ...
local module = { title = "Demon Spikes", description = "Vengeance Demon Hunter: Fury, Demon Spikes duration and Soul Fragments." }
addon:RegisterModule("demonSpikes", module)
local BUFF_ID, CAST_ID, SOUL_CLEAVE = 203819, 203720, 228477
local display = addon.modules.boneShield
local function secret(value) return issecretvalue and issecretvalue(value) end

-- Numbers may be secret in combat. Pass them unchanged to SetText.
local function readNumber(api, ...)
    if not api then return "?" end
    local ok, value = pcall(api, ...)
    if ok and (secret(value) or type(value) == "number") then return value end
    return "?"
end
function module:IsVengeance()
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    return class == "DEMONHUNTER" and spec and GetSpecializationInfo(spec) == 581
end
function module:ReadViewerTimer()
    if not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCooldownInfo then return "" end
    for _, name in ipairs({"BuffIconCooldownViewer", "BuffBarCooldownViewer"}) do
        local viewer = _G[name]
        local pool = viewer and viewer.itemFramePool
        if pool and pool.EnumerateActive then
            for item in pool:EnumerateActive() do
                local id = item.cooldownID
                if not secret(id) and type(id) == "number" then
                    local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, id)
                    if ok and (display:IsAuraEntry(info, BUFF_ID) or display:IsAuraEntry(info, CAST_ID)) then
                        local unit = item.auraDataUnit
                        if (not secret(unit) and unit == "player") or
                            (secret(unit) and not secret(info.selfAura) and info.selfAura == true) then
                            return display.ReadViewerTimer(self, item)
                        end
                    end
                end
            end
        end
    end
    return ""
end
function module:ReadAura()
    self.timerSource = "unavailable"
    local restricted = C_Secrets and C_Secrets.ShouldSpellAuraBeSecret and C_Secrets.ShouldSpellAuraBeSecret(BUFF_ID)
    if not restricted and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, BUFF_ID)
        if ok and not secret(aura) then
            if not aura then return "missing", 0 end
            if type(aura) == "table" then
                local expires = aura.expirationTime
                if not secret(expires) and type(expires) == "number" and expires > 0 then
                    self.timerSource = "direct buff expiration"
                    return "healthy", math.max(0, math.ceil(expires - GetTime()))
                end
                return "healthy", self:ReadViewerTimer()
            end
        end
    end
    -- A viewer can supply opaque countdown text without proving buff presence.
    return "unknown", self:ReadViewerTimer()
end
function module:Update()
    if not self.frame then return end
    if not self.enabled or not self:IsVengeance() then
        if self.preview then self.preview=nil; self.frame:SetPreview(false) end
        self.frame:Hide(); return
    end
    local settings = addon:GetSettings().demonSpikes
    if self.preview then
        self.frame:Render(self.preview, self.preview == "healthy" and "8" or "0", "75", settings.bounce, "4")
        return
    end
    if UnitIsDeadOrGhost("player") or (settings.combatOnly and not InCombatLockdown()) then self.frame:Hide(); return end
    local state, seconds = self:ReadAura()
    local furyType = Enum and Enum.PowerType and Enum.PowerType.Fury or 17
    local fury = readNumber(UnitPower, "player", furyType)
    local souls = readNumber(C_Spell and C_Spell.GetSpellCastCount, SOUL_CLEAVE)
    self.frame:Render(state, seconds, fury, settings.bounce, souls)
end
function module:Initialize()
    if self.events then return end
    self.frame = addon:CreateTrackerFrame("SlashikCombatUtilsDemonSpikesFrame", function() return addon:GetSettings().demonSpikes end)
    self.events = CreateFrame("Frame")
    self.events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" and self.preview then self:StopPreview() end
        self:Update()
    end)
end
function module:Enable()
    self:Initialize()
    self.enabled = true
    for _, event in ipairs({"UNIT_AURA", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT"}) do self.events:RegisterUnitEvent(event, "player") end
    for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "SPELL_UPDATE_USES"}) do self.events:RegisterEvent(event) end
    self.elapsed = 0
    self.events:SetScript("OnUpdate", function(_, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 0.1 then self.elapsed=0; self:Update() end
    end)
    self.frame:ApplyPosition(); self:Update()
end
function module:Disable()
    self.enabled=false; self.preview=nil
    if not self.events then return end
    self.events:UnregisterAllEvents(); self.events:SetScript("OnUpdate", nil)
    self.frame:SetPreview(false); self.frame:Hide()
end
function module:StartPreview(state)
    if not addon:CanEdit() or not addon:IsModuleEnabled("demonSpikes") then return end
    if not self:IsVengeance() then addon:Print("Demon Spikes is available only for Vengeance Demon Hunters."); return end
    self:Initialize(); self.preview=state or "healthy"
    self.frame:SetPreview(true); self:Update()
end
function module:StopPreview()
    self.preview=nil
    if self.frame then self.frame:SetPreview(false); self:Update() end
end
