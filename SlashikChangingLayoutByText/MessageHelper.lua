local _, addon = ...

local function SendRandomMessage(messages)
    if messages and #messages > 0 then
        SendChatMessage(messages[math.random(#messages)], "SAY")
    end
end

local function SendRandomPullMessage()
    SendRandomMessage(addon.PullMessages)
end

local function IsInMythicDungeonParty()
    if not IsInGroup() or IsInRaid() then
        return false
    end

    local inInstance, instanceType = IsInInstance()
    local _, _, difficultyID = GetInstanceInfo()
    -- Before a key starts, the dungeon uses Mythic difficulty (23).
    return inInstance and instanceType == "party" and difficultyID == 23
end

local function OnPlayerCountdownStarted()
    if addon.GetSettings().autoPullMessages and IsInMythicDungeonParty() then
        SendRandomPullMessage()
    end
end

local function StartPullCountdown(seconds)
    -- Preserve the explicit /l countdown greeting when automatic messages are off.
    -- Otherwise, let the Mythic dungeon event send it to avoid duplicates.
    if not addon.GetSettings().autoPullMessages or not IsInMythicDungeonParty() then
        SendRandomPullMessage()
    end
    C_PartyInfo.DoCountdown(seconds)
end

addon.SendRandomPullMessage = SendRandomPullMessage
addon.StartPullCountdown = StartPullCountdown
addon.OnPlayerCountdownStarted = OnPlayerCountdownStarted
