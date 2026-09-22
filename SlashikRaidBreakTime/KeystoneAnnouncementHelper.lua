local PREFIX = "SRBT_KEY_GO"
local COOLDOWN = 5
local nextSendAt = 0
local lastReceived = {}

local function partyChannel()
    if IsInRaid() or not IsInGroup() then return nil end
    return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
end

local function unitFullName(unit)
    local name, realm = UnitFullName(unit)
    if not name then return nil end
    return name .. "-" .. ((realm and realm ~= "") and realm or GetNormalizedRealmName())
end

local function partyUnit(name)
    if unitFullName("player") == name then return "player" end
    for i = 1, GetNumSubgroupMembers() do
        local unit = "party" .. i
        if unitFullName(unit) == name then return unit end
    end
end

local function dungeonName(mapID, level)
    if type(mapID) ~= "number" or type(level) ~= "number" then return nil end
    if mapID <= 0 or mapID > 100000 or mapID % 1 ~= 0
        or level <= 0 or level > 1000 or level % 1 ~= 0 then return nil end
    return C_ChallengeMode.GetMapUIInfo(mapID)
end

function canAnnounceKeystoneToParty()
    return partyChannel() ~= nil and GetTime() >= nextSendAt
end

-- Called by Let's Go or a completed roll: send chat once and sync the visual separately.
function announceKeystoneToParty(owner, mapID, level)
    local channel = partyChannel()
    local unit = partyUnit(owner)
    local dungeon = dungeonName(mapID, level)
    if not channel or not unit or not UnitIsConnected(unit) or not dungeon then return end
    if GetTime() < nextSendAt then
        print("SlashikRaidBreakTime: Please wait a few seconds before announcing another key.")
        return
    end
    nextSendAt = GetTime() + COOLDOWN
    saveSelectedKeystone(owner, mapID, level)
    local displayOwner = Ambiguate(owner, "none")
    C_ChatInfo.SendChatMessage(string.format("Let's run %s's key: %s +%d!", displayOwner, dungeon, level), channel)
    C_ChatInfo.SendAddonMessage(PREFIX, string.format("%d:%d:%s", mapID, level, owner), channel)
    showRaidBreakKeystoneAnnouncement(dungeon, level, displayOwner, false, mapID)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
    if event == "PLAYER_LOGIN" then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    elseif event == "GROUP_ROSTER_UPDATE" then
        for name in pairs(lastReceived) do
            if not partyUnit(name) then lastReceived[name] = nil end
        end
    elseif event == "CHAT_MSG_ADDON" then
        if prefix ~= PREFIX or not partyChannel() or channel ~= partyChannel() then return end
        if sender == unitFullName("player") or not partyUnit(sender) then return end
        if type(message) ~= "string" or #message > 255 then return end
        local mapID, level, owner = message:match("^(%d+):(%d+):([^:]+)$")
        mapID, level = tonumber(mapID), tonumber(level)
        local dungeon = dungeonName(mapID, level)
        if not dungeon or not partyUnit(owner) then return end
        if GetTime() < (lastReceived[sender] or 0) then return end
        lastReceived[sender] = GetTime() + COOLDOWN
        saveSelectedKeystone(owner, mapID, level)
        showRaidBreakKeystoneAnnouncement(dungeon, level, Ambiguate(owner, "none"), false, mapID)
    end
end)
