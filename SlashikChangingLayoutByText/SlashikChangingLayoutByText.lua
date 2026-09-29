local _, addon = ...
local ActivateLayoutByName = addon.ActivateLayoutByName
local PrintHelp = addon.PrintHelp
local SendRandomPullMessage = addon.SendRandomPullMessage
local StartPullCountdown = addon.StartPullCountdown

-- Register slash commands: /l and /layout.
SLASH_MYLAYOUT1 = "/l"
SLASH_MYLAYOUTLONG1 = "/layout"

-- Short-command handler: layouts plus pull countdowns.
SlashCmdList["MYLAYOUT"] = function(msg)
    msg = msg and msg:lower():trim() or ""

    if msg == "help" then
        PrintHelp()
    elseif msg:match("^msg%s+on$") then
        addon.SetAutoPullMessages(true)
    elseif msg:match("^msg%s+off$") then
        addon.SetAutoPullMessages(false)
    elseif msg == "msg" then
        SendRandomPullMessage()
    elseif msg:match("^%d+$") and tonumber(msg) > 0 then
        StartPullCountdown(tonumber(msg))
    else
        ActivateLayoutByName(msg)
    end
end

-- Long-command handler: layouts only.
SlashCmdList["MYLAYOUTLONG"] = function(msg)
    ActivateLayoutByName(msg and msg:lower():trim() or "")
end

-- WoW broadcasts standard party countdowns even when others lack this addon.
local frame = CreateFrame("Frame")
frame:RegisterEvent("START_PLAYER_COUNTDOWN")
frame:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
frame:RegisterEvent("LFG_PROPOSAL_FAILED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_LEFT")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("LFG_UPDATE")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "START_PLAYER_COUNTDOWN" then
        addon.OnPlayerCountdownStarted()
    elseif event == "LFG_PROPOSAL_SUCCEEDED" then
        addon.OnDungeonFinderProposalSucceeded()
    elseif event == "PLAYER_ENTERING_WORLD" then
        addon.OnDungeonFinderEnteringWorld(...)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "LFG_UPDATE" then
        addon.OnDungeonFinderGroupUpdated()
    elseif event == "GROUP_LEFT" then
        addon.OnDungeonFinderGroupLeft()
    elseif event == "LFG_PROPOSAL_FAILED" then
        addon.ResetDungeonFinderGreeting()
    end
end)
