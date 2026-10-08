local addonName = ...
local ADDON_PREFIX = "SRBT"

-- Builds the visible raid-break timer window and its countdown behavior from BreakTimerFrameHelper.lua.
local frame = createRaidBreakTimeFrame()

-- Handles raid permissions and addon-message synchronization.
local raidGroup = createRaidGroupHelper(ADDON_PREFIX)

-- Handles DBM and BigWigs break-timer compatibility.
local bossMods = createBossModCompatibility(addonName, frame)

-- Hidden party-keystone window and communication, independent of break timers.
local guildKeystones = createGuildKeystoneHelper()
local keystones = createKeystoneHelper(function() guildKeystones:show() end)

registerRaidBreakModuleListener("breakTimer", function(enabled)
    if not enabled then frame:hideBreak() end
end)

local function startBreak(minutes)
    if not isRaidBreakModuleEnabled("breakTimer") then return end
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

    local imageIndex = getRandomPicture()
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

    if not isRaidBreakModuleEnabled("breakTimer") then return end
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
    if not isRaidBreakModuleEnabled("breakTimer") then
        print("SlashikRaidBreakTime: Raid Break Timer is disabled. Right-click the minimap button to enable it.")
        return
    end
    local command, value = input:match("^(%S*)%s*(.-)$")
    command = command:lower()
    if command == "hide" or command == "stop" then
        frame:hideBreak()
    elseif command == "test" then
        frame:showBreak(300, getRandomPicture())
    else
        startBreak(tonumber(command))
    end
end

SLASH_SLASHIKRAIDBREAKSETTINGS1 = "/srbt"
local function printSettingsHelp()
    print("|cff55ddffSlashik Raid Break Time commands:|r")
    print("|cffffcc00/srbt options|r - Open module settings (also right-click the minimap button).")
    print("|cffffcc00/srbt key|r - Open the party keystone window.")
    print("|cffffcc00/srbt key guild|r - Open the guild keystone window.")
    print("|cffffcc00/srbt random <on|off>|r - Turn automatic image rotation on or off.")
    print("|cffffcc00/srbt timer <1-120>|r - Set how often images change, in minutes.")
    print("|cffffcc00/srbt audio <on|off>|r - Turn break-warning sounds on or off.")
    print("|cffffcc00/srbt soulstone <on|off>|r - Ready-check screen/raid reminders (default: off). All recovery features require the Raid Recovery module.")
    print("|cffffcc00/srbt settings|r - Show the current addon settings.")
    print("|cffffcc00/srbt soulstone debug <on|off|status>|r - Diagnose Soulstone warnings (session only).")
    print("|cffffcc00/srbt settings default|r - Reset rotation to on, timer to 1 minute, audio and ready-check Soulstone reminders to off.")
    print("|cffffcc00/srbt help|r - Show this command list.")
end

SlashCmdList.SLASHIKRAIDBREAKSETTINGS = function(input)
    local command, value = input:match("^(%S*)%s*(.-)$")
    command = command:lower()

    if command == "" or command == "help" then
        printSettingsHelp()
    elseif command == "options" then
        showRaidBreakAddonSettings()
    elseif command == "key" then
        if not isRaidBreakModuleEnabled("keystones") then
            print("SlashikRaidBreakTime: Keystones is disabled. Right-click the minimap button to enable it.")
            return
        end
        if value:lower() == "guild" then
            guildKeystones:show()
        else
            keystones:show()
        end
    elseif command == "settings" then
        if value:lower() == "default" then
            frame:resetSettings()
            setRaidSoulstoneEnabled(false)
            print("|cff55ddffSlashik Raid Break Time: settings reset to rotation on, a 1-minute timer, audio and ready-check Soulstone reminders off.|r")
        else
            local rotationStatus = frame:isRandomImagesEnabled() and "on" or "off"
            local audioStatus = frame:isAudioEnabled() and "on" or "off"
            print(string.format("|cff55ddffSlashik Raid Break Time: random image rotation is %s.|r", rotationStatus))
            print(string.format("|cff55ddffRandom image timer: every %d minute(s).|r", frame:getRandomTimerMinutes()))
            print(string.format("|cff55ddffBreak-warning audio is %s.|r", audioStatus))
            print(string.format("|cff55ddffSaved ready-check screen/raid reminders: %s. All recovery features require the Raid Recovery module.|r", getSettings().soulstoneEnabled and "on" or "off"))
            for _, module in ipairs({ "keystones", "breakTimer", "raidRecovery" }) do
                print("SRBT module " .. module .. ": " .. (isRaidBreakModuleEnabled(module) and "enabled" or "disabled"))
            end
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
    elseif command == "soulstone" then
        value = value:lower()
        local debugCommand = value:match("^debug%s*(.*)$")
        if debugCommand ~= nil then
            raidSoulstoneDebug(debugCommand)
            return
        end
        if value == "on" or value == "off" then
            setRaidSoulstoneEnabled(value == "on")
            print("|cff55ddffSlashik Raid Break Time: saved ready-check screen/raid reminders are " .. value .. ". These apply only while Raid Recovery is enabled.|r")
        else
            print("|cffffcc00Usage: /srbt soulstone <on|off>|r")
        end
    elseif command == "audio" then
        value = value:lower()
        if value == "on" then
            frame:setAudioEnabled(true)
            print("|cff55ddffSlashik Raid Break Time: break-warning audio is on.|r")
        elseif value == "off" then
            frame:setAudioEnabled(false)
            print("|cff55ddffSlashik Raid Break Time: break-warning audio is off.|r")
        else
            print("|cffffcc00Usage: /srbt audio <on|off>|r")
        end
    else
        printSettingsHelp()
    end
    refreshRaidBreakAddonSettings()
end
