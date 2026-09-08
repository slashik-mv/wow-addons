local _, addon = ...

local function SendRandomMessage(messages)
    if messages and #messages > 0 then
        SendChatMessage(messages[math.random(#messages)], "SAY")
    end
end

local function SendRandomPullMessage()
    SendRandomMessage(addon.PullMessages)
end

local function StartPullCountdown(seconds)
    SendRandomPullMessage()
    C_PartyInfo.DoCountdown(seconds)
end

addon.SendRandomPullMessage = SendRandomPullMessage
addon.StartPullCountdown = StartPullCountdown
