local _, addon = ...
local module = { title = "Bone Shield", description = "Blood Death Knight: stacks, remaining seconds and missing-shield warning." }
addon:RegisterModule("boneShield", module)
local SPELL_ID, BLOOD_SPEC = 195181, 250

local function secret(value)
    return issecretvalue and issecretvalue(value)
end

local function matchesSpell(value, spellID)
    return not secret(value) and value == spellID
end

-- Match public cooldown metadata, never the restricted spell ID of a live aura.
function module:IsAuraEntry(info, spellID)
    if secret(info) or type(info) ~= "table" then return false end
    if matchesSpell(info.spellID, spellID) or matchesSpell(info.overrideSpellID, spellID) then return true end
    local linked = info.linkedSpellIDs
    if not secret(linked) and type(linked) == "table" then
        for _, id in ipairs(linked) do if matchesSpell(id, spellID) then return true end end
    end
    return false
end

function module:ReadInstanceCount(instanceID)
    if not secret(instanceID) and instanceID == nil then return end
    if not C_UnitAuras.GetAuraApplicationDisplayCount then return end
    local ok, count = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, "player", instanceID, 1)
    -- A secret string is passed unchanged to FontString:SetText. No formatting,
    -- equality checks, arithmetic, or branching on its content is permitted.
    if ok and (secret(count) or type(count) == "string" or type(count) == "number") then
        return true, count
    end
end

function module:ReadViewerCount(item)
    local found, count = self:ReadInstanceCount(item.auraInstanceID)
    if found then self.countSource = "aura display API"; return true, count end
    -- Some clients reject instance queries in combat even though Blizzard's
    -- own FontString already has the current stack text. Mirror that text as
    -- an opaque value; never call GetApplicationsText (it compares stacks).
    if item.GetApplicationsFontString then
        local ok, textRegion = pcall(item.GetApplicationsFontString, item)
        if ok and textRegion and textRegion.GetText then
            local read, text = pcall(textRegion.GetText, textRegion)
            if read and (secret(text) or (type(text) == "string" and text ~= "")) then
                self.countSource = "Blizzard stack text"
                return true, text
            end
        end
    end
    -- Blizzard suppresses its label at one stack. Its aura cache supplies that
    -- value; prefer the refreshed label above for changing multi-stack buffs.
    local data = item.auraDataCached
    if not secret(data) and type(data) == "table" then
        local value = data.applications
        if secret(value) or type(value) == "number" then
            self.countSource = "Blizzard aura cache"
            return true, value
        end
    end
end

function module:ReadViewerTimer(item, sourceKey)
    sourceKey = sourceKey or "timerSource"
    -- Mirror the countdown already formatted by Blizzard. It may be a secret
    -- string: pass it directly to SetText, never parse or calculate with it.
    local region
    if item.GetDurationFontString then
        local ok, value = pcall(item.GetDurationFontString, item)
        if ok then region = value end
    end
    if not region then
        local cooldown = item.Cooldown
        if cooldown and cooldown.GetCountdownFontString then
            local ok, value = pcall(cooldown.GetCountdownFontString, cooldown)
            if ok then region = value end
        end
    end
    if region and region.GetText then
        local ok, text = pcall(region.GetText, region)
        if ok and (secret(text) or type(text) == "string") then
            self[sourceKey] = "Blizzard countdown text"
            return text
        end
    end
    return ""
end

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
    local state = count >= 5 and "healthy" or (count > 0 and "low" or "missing")
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

function module:IsBlood()
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    return class == "DEATHKNIGHT" and spec and GetSpecializationInfo(spec) == BLOOD_SPEC
end

function module:Update()
    if not self.enabled then
        if self.frame then self.frame:Hide() end
        return
    end
    if not self:IsBlood() then
        self.knownInstanceID = nil
        if self.preview then
            self.preview = nil
            self.frame:SetPreview(false)
        end
        self.frame:Hide()
        return
    end
    local settings = addon:GetSettings().boneShield
    if self.preview then
        local state = self.preview
        self.frame:Render(state, state == "healthy" and 6 or (state == "low" and 3 or 0),
            settings.showTimer and (state == "missing" and "" or "11") or "", settings.bounce, settings.showDeathAndDecay and "8" or "")
        return
    end
    if UnitIsDeadOrGhost("player") or (settings.combatOnly and not InCombatLockdown()) then
        self.frame:Hide()
        return
    end
    local state, count, remaining = self:ReadAura()
    -- Do not use `and remaining or ...`: that branches on a secret timer string.
    if not settings.showTimer then remaining = "" end
    local deathAndDecay = ""
    if settings.showDeathAndDecay then deathAndDecay = self:ReadDeathAndDecayTimer() end
    self.frame:Render(state, count, remaining, settings.bounce, deathAndDecay)
end

function module:Initialize()
    if self.events then return end
    self.frame = addon:CreateTrackerFrame("SlashikCombatUtilsBoneShieldFrame", function() return addon:GetSettings().boneShield end)
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
    if not addon:CanEdit() or not addon:IsModuleEnabled("boneShield") then return end
    if not self:IsBlood() then
        addon:Print("Bone Shield is available only for Blood Death Knights.")
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
