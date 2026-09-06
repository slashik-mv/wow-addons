local addonName = ...
local ADDON_PREFIX = "SRBT"
local images = SlashikRaidBreakTimeImages

-- Builds the visible raid-break timer window and its countdown behavior from BreakTimerFrameHelper.lua.
local frame = createRaidBreakTimeFrame(images)

-- Handles raid permissions and addon-message synchronization.
local raidGroup = createRaidGroupHelper(ADDON_PREFIX)

-- Handles DBM and BigWigs break-timer compatibility.
local bossMods = createBossModCompatibility(addonName, frame)

local function startBreak(minutes)
    if not raidGroup:isAllowedToStart() then
        print("|cffff4444Slashik Raid Break Time: only the raid leader or an assistant can start a break.|r")
        return
    end

    if not minutes then
        print("|cffffcc00Usage: /break <minutes>  (from 1 to 120)|r")
        return
    end
    local seconds = math.floor(minutes * 60)
    if seconds < 60 or seconds > 7200 then
        print("|cffffcc00Usage: /break <minutes>  (from 1 to 120)|r")
        return
    end

    local imageIndex = math.random(#images)
    frame:showBreak(seconds, imageIndex)
    if IsInGroup() then raidGroup:broadcast(seconds, imageIndex) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
    if event == "PLAYER_LOGIN" then
        SlashikRaidBreakTimeDB = SlashikRaidBreakTimeDB or {}
        C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
        C_ChatInfo.RegisterAddonMessagePrefix("D5")
        bossMods:registerBigWigsCompatibility()
        frame:restoreBreakAfterReload()
        print("|cff55ddffSlashik Raid Break Time loaded. Use /break <minutes>.|r")
        return
    end

    if prefix == "D5" and message and raidGroup:isSenderAllowed(sender) then
        frame:showCompatibleBreak(bossMods:getDBMBreakSeconds(message))
        return
    end

    if prefix ~= ADDON_PREFIX or not message or not raidGroup:isSenderAllowed(sender) then return end
    local seconds, imageIndex = message:match("^START:(%d+):(%d+)$")
    if seconds and imageIndex then
        frame:showBreak(tonumber(seconds), tonumber(imageIndex))
    end
end)

SLASH_SLASHIKRAIDBREAKTIME1 = "/break"
SlashCmdList.SLASHIKRAIDBREAKTIME = function(input)
    local command, value = input:match("^(%S*)%s*(.-)$")
    command = command:lower()
    if command == "hide" or command == "stop" then
        frame:hideBreak()
    elseif command == "test" then
        frame:showBreak(300, math.random(#images))
    else
        startBreak(tonumber(command))
    end
end

SLASH_SLASHIKRAIDBREAKSETTINGS1 = "/srbt"
local function printSettingsHelp()
    print("|cff55ddffSlashik Raid Break Time settings:|r")
    print("|cffffcc00/srbt random <on|off>|r - Turn automatic image rotation on or off.")
    print("|cffffcc00/srbt timer <1-120>|r - Set how often images change, in minutes.")
    print("|cffffcc00/srbt settings|r - Show the current rotation settings.")
    print("|cffffcc00/srbt settings default|r - Reset rotation to on with a 1-minute timer.")
    print("|cffffcc00/srbt help|r - Show this command list.")
end

SlashCmdList.SLASHIKRAIDBREAKSETTINGS = function(input)
    local command, value = input:match("^(%S*)%s*(.-)$")
    command = command:lower()

    if command == "" or command == "help" then
        printSettingsHelp()
    elseif command == "settings" then
        if value:lower() == "default" then
            frame:resetRandomImageSettings()
            print("|cff55ddffSlashik Raid Break Time: random image settings reset to on with a 1-minute timer.|r")
        else
            local rotationStatus = frame:isRandomImagesEnabled() and "on" or "off"
            print(string.format("|cff55ddffSlashik Raid Break Time: random image rotation is %s.|r", rotationStatus))
            print(string.format("|cff55ddffRandom image timer: every %d minute(s).|r", frame:getRandomTimerMinutes()))
        end
    elseif command == "random" then
        value = value:lower()
        if value == "on" then
            frame:setRandomImagesEnabled(true)
            print("|cff55ddffSlashik Raid Break Time: random image rotation is on.|r")
        elseif value == "off" then
            frame:setRandomImagesEnabled(false)
            print("|cff55ddffSlashik Raid Break Time: random image rotation is off.|r")
        else
            print("|cffffcc00Usage: /srbt random <on|off>|r")
        end
    elseif command == "timer" then
        if frame:setRandomTimerMinutes(value) then
            print(string.format("|cff55ddffSlashik Raid Break Time: images change every %d minute(s).|r", frame:getRandomTimerMinutes()))
        else
            print("|cffffcc00Usage: /srbt timer <1-120>|r")
        end
    else
        printSettingsHelp()
    end
end
