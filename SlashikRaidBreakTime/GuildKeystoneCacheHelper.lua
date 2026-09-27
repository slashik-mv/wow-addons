-- Saved per guild; timestamps represent received key information, not roster activity.
function createGuildKeystoneCacheHelper()
    local helper = {}
    function helper:get()
        local guild, _, _, realm = GetGuildInfo("player")
        realm = realm and realm ~= "" and realm or GetNormalizedRealmName()
        if not IsInGuild() or not guild or not realm then return nil end
        SlashikRaidBreakTimeDB = SlashikRaidBreakTimeDB or {}
        local db = SlashikRaidBreakTimeDB
        db.guildKeystoneCache = db.guildKeystoneCache or {}
        local id = realm .. ":" .. guild
        db.guildKeystoneCache[id] = db.guildKeystoneCache[id] or {}
        return db.guildKeystoneCache[id], id
    end
    function helper:save(name, class, mapID, level)
        local cache = self:get()
        if not cache then return end
        cache[name] = mapID > 0 and { mapID = mapID, level = level,
            class = class, seenAt = GetServerTime() } or nil
    end
    function helper:age(key)
        local seconds = math.max(0, GetServerTime() - (key.seenAt or GetServerTime()))
        if seconds < 60 then return "just now" end
        if seconds < 3600 then return math.floor(seconds / 60) .. "m ago" end
        if seconds < 86400 then return math.floor(seconds / 3600) .. "h ago" end
        return math.floor(seconds / 86400) .. "d ago"
    end
    return helper
end
