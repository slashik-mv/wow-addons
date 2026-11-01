local _, addon = ...

-- Settings scope and initial enable state for every selectable module.
-- New modules default to character-specific and disabled when not listed here.
addon.moduleConfig = {
    boneShield     = { scope = "character", enabledByDefault = true },
    consumables    = { scope = "character", enabledByDefault = false },
    beacons        = { scope = "character", enabledByDefault = true },
    autoHealthPot  = { scope = "character", enabledByDefault = false },
    demonSpikes    = { scope = "character", enabledByDefault = false },
    focusInterrupt = { scope = "character", enabledByDefault = true },
    battleResLust  = { scope = "warband",   enabledByDefault = false },
}

function addon:IsWarbandModule(key)
    local config = self.moduleConfig[key]
    return config ~= nil and config.scope == "warband"
end
