-- Register slash commands: /l and /layout.
SLASH_MYLAYOUT1 = "/l"
SLASH_MYLAYOUTLONG1 = "/layout"

-- Simple BIG text in middle of the screen
local function ShowBigTextInCenter(msg, duration)
    -- creating frame for text
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(800, 200)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:Hide()

    -- setting text object
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    text:SetPoint("CENTER")
    text:SetText(msg)

    -- custom size of text
    local font, _, flags = text:GetFont()
    text:SetFont(font, 40, flags)

    frame.text = text
    frame:Show()

    C_Timer.After(duration or 10, function()
        frame:Hide()
    end)
end

-- Activate Layout by Name
local function ActivateLayoutByName(layoutName)
    layoutName = layoutName:lower()

    for layoutID, layoutInfo in pairs(EditModeManagerFrame:GetLayouts()) do
        if layoutInfo.layoutName:lower() == layoutName then
            C_EditMode.SetActiveLayout(layoutID)
            local msg = "Activated layout: " .. layoutInfo.layoutName
            print(msg)
            ShowBigTextInCenter(msg, 1)
            return
        end
    end

    print("Layout not found:", layoutName)
end

-- Send a random message from the shared list.
local function SendRandomPullMessage()
    local messages = SlashikChangingLayoutPullMessages
    if messages and #messages > 0 then
        SendChatMessage(messages[math.random(#messages)], "SAY")
    end
end

-- Send a random raid message from the shared list.
local function SendRandomRaidMessage()
    local messages = SlashikChangingLayoutRaidMessages
    if messages and #messages > 0 then
        SendChatMessage(messages[math.random(#messages)], "SAY")
    end
end

-- Announce a random message and start the standard pull countdown.
local function StartPullCountdown(seconds)
    SendRandomPullMessage()
    C_PartyInfo.DoCountdown(seconds)
end

-- Short-command handler: layouts plus pull countdowns.
SlashCmdList["MYLAYOUT"] = function(msg)
    msg = msg and msg:lower():trim() or ""

    if msg == "help" then
        print("Usage:")
        local layouts = EditModeManagerFrame:GetLayouts()
        for layoutID, layoutInfo in pairs(layouts) do
            print("/l " .. layoutInfo.layoutName:lower() .. "  - activate " .. layoutInfo.layoutName .. " layout")
        end
        print("or")
        for layoutID, layoutInfo in pairs(layouts) do
            print("/layout " .. layoutInfo.layoutName:lower() .. "  - activate " .. layoutInfo.layoutName .. " layout")
        end
        print("/l <seconds> - say a random message and start a pull countdown")
        print("/l msg       - say a random message without starting a pull countdown")
        print("/l rmsg      - say a random raid message without starting a pull countdown")
    elseif msg == "msg" then
        SendRandomPullMessage()
    elseif msg == "rmsg" then
        SendRandomRaidMessage()
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
