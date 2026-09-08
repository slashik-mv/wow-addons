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
