local _, addon = ...
local module = addon.modules.boneShield
local BUFF_ID, CAST_ID = 188290, 43265

local function secret(value)
    return issecretvalue and issecretvalue(value)
end

-- Companion timer in the Blood DK display. Track the player's buff, not the
-- spell cooldown or an estimated ground-effect lifetime.
function module:ReadDeathAndDecayTimer()
    self.deathAndDecaySource = "unavailable"
    local restricted = C_Secrets and C_Secrets.ShouldSpellAuraBeSecret
        and C_Secrets.ShouldSpellAuraBeSecret(BUFF_ID)
    if not restricted and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, BUFF_ID)
        if ok and not secret(aura) then
            if not aura then
                self.deathAndDecaySource = "buff absent"
                return ""
            end
            local expires = aura.expirationTime
            if not secret(expires) and type(expires) == "number" then
                self.deathAndDecaySource = "direct buff expiration"
                if expires > 0 then return math.max(0, math.ceil(expires - GetTime())) end
                return ""
            end
        end
    end
    -- Only inspect buff viewers, never Essential/Utility spell cooldowns.
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
                        if ok and (self:IsAuraEntry(info, BUFF_ID) or self:IsAuraEntry(info, CAST_ID)) then
                            local playerAura = not secret(unit) and unit == "player"
                            local selfAura = secret(unit) and not secret(info.selfAura) and info.selfAura == true
                            if playerAura or selfAura then
                                return self:ReadViewerTimer(item, "deathAndDecaySource")
                            end
                        end
                    end
                end
            end
        end
    end
    return ""
end
