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
