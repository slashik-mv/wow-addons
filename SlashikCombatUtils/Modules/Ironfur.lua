local _, addon = ...
local module = { title = "Ironfur", description = "Guardian Druid: Ironfur duration, stacks and Rage." }
addon:RegisterModule("ironfur", module)
local SPELL_ID, GUARDIAN_SPEC = 192081, 104
local function secret(value) return issecretvalue and issecretvalue(value) end

-- Share the proven opaque display readers; resolve Ironfur's own metadata below.
local display = addon.modules.boneShield
module.IsAuraEntry = display.IsAuraEntry
module.ReadInstanceCount = display.ReadInstanceCount
module.ReadViewerCount = display.ReadViewerCount
module.ReadViewerTimer = display.ReadViewerTimer

function module:ReadRestrictedCount()
    self.countSource = "no matching Blizzard buff entry"
    if not C_UnitAuras then return "unknown", "?", "" end
    -- Re-resolve on every refresh: Blizzard can recycle a viewer frame for a
    -- different buff. Do not retain the frame or its secret instance ID.
    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        for _, name in ipairs({ "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
            local viewer = _G[name]
            local pool = viewer and viewer.itemFramePool
            if pool and pool.EnumerateActive then
                for item in pool:EnumerateActive() do
                    local id = item.cooldownID
                    if not secret(id) and type(id) == "number" then
                        local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, id)
                        local unit = item.auraDataUnit
                        -- auraDataUnit may itself be secret. In that case only
                        -- use an entry explicitly declared a self aura in metadata.
                        local playerAura = not secret(unit) and unit == "player"
                        if ok and self:IsAuraEntry(info, SPELL_ID) and (playerAura or
                            (secret(unit) and not secret(info.selfAura) and info.selfAura == true)) then
                            self.countSource = "matched entry, no readable display source"
                            local found, count = self:ReadViewerCount(item)
                            if found then return "unknown", count, self:ReadViewerTimer(item) end
                        end
                    end
                end
            end
        end
    end
    -- An instance identified before restrictions began is still a valid handle.
    -- Failed/removed instances never turn into a false zero-stack warning.
    local found, count = self:ReadInstanceCount(self.knownInstanceID)
    if found then self.countSource = "previously identified aura"; return "unknown", count, "" end
    return "unknown", "?", ""
end

-- Never infer absence from a restricted query or compare secret aura fields.
function module:ReadAura()
    self.countSource = "direct aura query"
    self.timerSource = "unavailable"
    if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then return "unknown", "?", "" end
    if C_Secrets and C_Secrets.ShouldSpellAuraBeSecret and C_Secrets.ShouldSpellAuraBeSecret(SPELL_ID) then
        return self:ReadRestrictedCount()
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, SPELL_ID)
    if not ok or secret(aura) then return self:ReadRestrictedCount() end
    if not aura then self.knownInstanceID = nil; return "missing", 0, "" end
    if not secret(aura.auraInstanceID) then self.knownInstanceID = aura.auraInstanceID end
    local count, expires = aura.applications, aura.expirationTime
    if secret(count) then
        local _, _, timer = self:ReadRestrictedCount()
        return "unknown", count, timer
    end
    if type(count) ~= "number" then return self:ReadRestrictedCount() end
    local state = count >= 2 and "healthy" or (count > 0 and "low" or "missing")
    local remaining = ""
    if secret(expires) then
        local _, _, timer = self:ReadRestrictedCount()
        remaining = timer
    elseif type(expires) == "number" and expires > 0 then
        self.timerSource = "direct aura expiration"
        remaining = math.max(0, math.ceil(expires - GetTime()))
    end
    return state, count, remaining
end

function module:IsGuardian()
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    return class == "DRUID" and spec and GetSpecializationInfo(spec) == GUARDIAN_SPEC
end

function module:Update()
    if not self.enabled then
        if self.frame then self.frame:Hide() end
        return
    end
    if not self:IsGuardian() then
        self.knownInstanceID = nil
        if self.preview then
            self.preview = nil
            self.frame:SetPreview(false)
        end
        self.frame:Hide()
        return
    end
    local settings = addon:GetSettings().ironfur
    if self.preview then
        local state = self.preview
        self.frame:Render(state, state == "healthy" and 2 or (state == "low" and 1 or 0),
            state == "missing" and "" or "7", settings.bounce, "65")
        return
    end
    if UnitIsDeadOrGhost("player") or (settings.combatOnly and not InCombatLockdown()) then
        self.frame:Hide()
        return
    end
    local state, count, remaining = self:ReadAura()
    local rage = "?"
    if UnitPower then
        local rageType = Enum and Enum.PowerType and Enum.PowerType.Rage or 1
        local ok, value = pcall(UnitPower, "player", rageType)
        if ok and (secret(value) or type(value) == "number") then rage = value end
    end
    self.frame:Render(state, count, remaining, settings.bounce, rage)
end

function module:Initialize()
    if self.events then return end
    self.frame = addon:CreateTrackerFrame("SlashikCombatUtilsIronfurFrame", function() return addon:GetSettings().ironfur end)
    self.events = CreateFrame("Frame")
    self.events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then self.knownInstanceID = nil end
        if event == "PLAYER_REGEN_DISABLED" and self.preview then self:StopPreview() end
        self:Update()
    end)
end

function module:Enable()
    self:Initialize()
    if not self.enabled then
        self.enabled = true
        self.events:RegisterUnitEvent("UNIT_AURA", "player")
        self.events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        self.events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
        for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_DISABLED",
            "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do self.events:RegisterEvent(event) end
        -- Timer also refreshes restrictions and expiry if no aura event arrives.
        self.elapsed = 0
        self.events:SetScript("OnUpdate", function(_, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= 0.1 then self.elapsed = 0; self:Update() end
        end)
    end
    self.frame:ApplyPosition()
    self:Update()
end

function module:Disable()
    self.enabled = false
    self.knownInstanceID = nil
    self.preview = nil
    if not self.events then return end
    self.events:UnregisterAllEvents()
    self.events:SetScript("OnUpdate", nil)
    self.frame:SetPreview(false)
    self.frame:Hide()
end

function module:StartPreview(state)
    if not addon:CanEdit() or not addon:IsModuleEnabled("ironfur") then return end
    if not self:IsGuardian() then
        addon:Print("Ironfur is available only for Guardian Druids.")
        return
    end
    self:Initialize()
    self.preview = state or "healthy"
    self.frame:SetPreview(true)
    self:Update()
end

function module:StopPreview()
    self.preview = nil
    if self.frame then self.frame:SetPreview(false); self:Update() end
end
