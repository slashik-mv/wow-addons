local _, addon = ...

local completionHandled = false
local generation = 0

local function CancelCompletionMessage()
    generation = generation + 1
end

local function ResetCompletionMessage()
    generation = generation + 1
    completionHandled = false
end

local function OnChallengeModeCompleted()
    if completionHandled then return end
    completionHandled = true
    if not addon.GetSettings().autoPullMessages then return end

    local currentGeneration = generation
    local attempts = 0
    local function TryCompletionMessage()
        if currentGeneration ~= generation then return end
        if not addon.GetSettings().autoPullMessages or not IsInGroup() or IsInRaid() then return end

        local info = C_ChallengeMode.GetChallengeCompletionInfo()
        if info and info.mapChallengeModeID > 0 and info.level > 0
            and info.time > 0 and type(info.onTime) == "boolean" then
            if info.practiceRun then return end
            local messages = info.onTime and addon.TimedCompletionMessages or addon.OvertimeCompletionMessages
            addon.SendRandomMessage(messages, "PARTY")
            return
        end

        -- Completion data may become available just after the event.
        attempts = attempts + 1
        if attempts < 5 then
            C_Timer.After(0.5, TryCompletionMessage)
        end
    end

    TryCompletionMessage()
end

addon.OnChallengeModeCompleted = OnChallengeModeCompleted
addon.ResetCompletionMessage = ResetCompletionMessage
addon.CancelCompletionMessage = CancelCompletionMessage
