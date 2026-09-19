-- Saved selection is shared through the existing Let's Go / Roll announcement.
local function fullName(unit)
    local name, realm = UnitFullName(unit)
    if name then return name .. "-" .. ((realm and realm ~= "") and realm or GetNormalizedRealmName()) end
end

local function ownerInParty(owner)
    if IsInRaid() or not IsInGroup() then return false end
    if fullName("player") == owner then return true end
    for i = 1, GetNumSubgroupMembers() do
        if fullName("party" .. i) == owner then return true end
    end
    return false
end

local function clearSelection()
    if SlashikRaidBreakTimeDB then SlashikRaidBreakTimeDB.selectedKeystone = nil end
end

function saveSelectedKeystone(owner, mapID, level)
    if C_ChallengeMode.IsChallengeModeActive() then clearSelection(); return end
    SlashikRaidBreakTimeDB = SlashikRaidBreakTimeDB or {}
    SlashikRaidBreakTimeDB.selectedKeystone = { owner = owner, mapID = mapID, level = level }
end

local function getSelection()
    local key = SlashikRaidBreakTimeDB and SlashikRaidBreakTimeDB.selectedKeystone
    if not key then return end
    if type(key) ~= "table" or type(key.owner) ~= "string"
        or type(key.mapID) ~= "number" or type(key.level) ~= "number"
        or key.mapID <= 0 or key.level <= 0 or not ownerInParty(key.owner)
        or C_ChallengeMode.IsChallengeModeActive() then
        clearSelection()
        return
    end
    return key
end

local function remindOwner(initiator, seconds)
    -- Countdown payloads can be secret during encounters in Midnight.
    if issecretvalue and (issecretvalue(initiator) or issecretvalue(seconds)) then return end
    if type(seconds) ~= "number" or seconds <= 0 or InCombatLockdown() then return end
    local key = getSelection()
    if not key then return end
    local partyInitiator = UnitGUID("player") == initiator
    for i = 1, GetNumSubgroupMembers() do
        if UnitGUID("party" .. i) == initiator then partyInitiator = true end
    end
    if not partyInitiator then return end
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    local dungeon, _, _, _, _, dungeonInstanceID = C_ChallengeMode.GetMapUIInfo(key.mapID)
    if instanceType ~= "party" or not dungeon or dungeonInstanceID ~= instanceID then return end
    -- Persist this deadline too, so reloading during a pull cannot duplicate it.
    local now = GetServerTime()
    if type(key.remindedUntil) == "number" and now < key.remindedUntil then return end
    key.remindedUntil = now + seconds
    showRaidBreakKeystoneAnnouncement(dungeon, key.level, Ambiguate(key.owner, "none"), true)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "START_PLAYER_COUNTDOWN", "CANCEL_PLAYER_COUNTDOWN", "GROUP_ROSTER_UPDATE",
    "PLAYER_ENTERING_WORLD", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, initiator, seconds)
    if event == "START_PLAYER_COUNTDOWN" then
        remindOwner(initiator, seconds)
    elseif event == "CANCEL_PLAYER_COUNTDOWN" then
        local key = getSelection()
        if key then key.remindedUntil = nil end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        getSelection()
    else
        clearSelection()
    end
end)
