local addonName = ...
local ADDON_PREFIX = "SRBT"
local images = SlashikRaidBreakTimeImages

local frame = CreateFrame("Frame", "SlashikRaidBreakTimeFrame", UIParent, "BackdropTemplate")
frame:SetSize(500, 270)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetFrameStrata("HIGH")
frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark" })
frame:SetBackdropColor(0, 0, 0, 0.82)
frame:Hide()

frame.art = frame:CreateTexture(nil, "ARTWORK")
frame.art:SetSize(250, 250)
frame.art:SetPoint("LEFT", 10, 0)

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
frame.title:SetPoint("TOPLEFT", frame.art, "TOPRIGHT", 28, -42)
frame.title:SetText("Raid Break")

frame.timer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
frame.timer:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -24)
frame.timer:SetText("00:00")

frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.hint:SetPoint("TOPLEFT", frame.timer, "BOTTOMLEFT", 3, -18)
frame.hint:SetText("Enjoy the break!")

frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

local endTime = 0

local function formatTime(seconds)
    seconds = math.max(0, math.ceil(seconds))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function showBreak(seconds, imageIndex)
    endTime = GetTime() + seconds
    frame.art:SetTexture(images[imageIndex] or images[1])
    frame:Show()
end

local function showCompatibleBreak(seconds)
    seconds = tonumber(seconds)
    if seconds and seconds > 0 and seconds <= 3600 then
        showBreak(seconds, math.random(#images))
    elseif seconds == 0 then
        frame:Hide()
    end
end

frame:SetScript("OnUpdate", function(_, elapsed)
    if not frame:IsShown() then return end
    local remaining = endTime - GetTime()
    frame.timer:SetText(formatTime(remaining))
    if remaining <= 0 then
        frame:Hide()
    end
end)

local function isAllowedToStart()
    if not IsInGroup() then return true end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

local function isSenderAllowed(sender)
    local shortSender = Ambiguate(sender, "short")
    local members = GetNumGroupMembers()

    if IsInRaid() then
        for i = 1, members do
            local name = GetRaidRosterInfo(i)
            if name and Ambiguate(name, "short") == shortSender then
                local unit = "raid" .. i
                return UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)
            end
        end
    else
        if Ambiguate(UnitName("player"), "short") == shortSender then
            return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
        end
        for i = 1, members - 1 do
            local unit = "party" .. i
            local name = UnitName(unit)
            if name and Ambiguate(name, "short") == shortSender then
                return UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)
            end
        end
    end
    return false
end

local function broadcast(seconds, imageIndex)
    local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, string.format("START:%d:%d", seconds, imageIndex), channel)
end

local function getDBMBreakSeconds(message)
    -- DBM's public break sync is the BT command on its D5 addon-message prefix.
    local fields = { strsplit("\t", message) }
    for i = 1, #fields - 1 do
        if fields[i] == "BT" then
            return tonumber(fields[i + 1])
        end
    end
end

local function registerBigWigsCompatibility()
    local loader = _G.BigWigsLoader
    if not loader or type(loader.RegisterMessage) ~= "function" then return end

    loader.RegisterMessage(addonName, "BigWigs_StartBreak", function(_, _, seconds)
        showCompatibleBreak(seconds)
    end)
    loader.RegisterMessage(addonName, "BigWigs_StopBreak", function()
        frame:Hide()
    end)
end

local function startBreak(minutes)
    if not isAllowedToStart() then
        print("|cffff4444Slashik Raid Break Time: only the raid leader or an assistant can start a break.|r")
        return
    end

    if not minutes then
        print("|cffffcc00Usage: /srb <minutes>  (from 1 to 120)|r")
        return
    end
    local seconds = math.floor(minutes * 60)
    if seconds < 60 or seconds > 7200 then
        print("|cffffcc00Usage: /srb <minutes>  (from 1 to 120)|r")
        return
    end

    local imageIndex = math.random(#images)
    showBreak(seconds, imageIndex)
    if IsInGroup() then broadcast(seconds, imageIndex) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
    if event == "PLAYER_LOGIN" then
        C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
        C_ChatInfo.RegisterAddonMessagePrefix("D5")
        registerBigWigsCompatibility()
        print("|cff55ddffSlashik Raid Break Time loaded. Use /srb <minutes>.|r")
        return
    end

    if prefix == "D5" and message and isSenderAllowed(sender) then
        showCompatibleBreak(getDBMBreakSeconds(message))
        return
    end

    if prefix ~= ADDON_PREFIX or not message or not isSenderAllowed(sender) then return end
    local seconds, imageIndex = message:match("^START:(%d+):(%d+)$")
    if seconds and imageIndex then
        showBreak(tonumber(seconds), tonumber(imageIndex))
    end
end)

SLASH_SLASHIKRAIDBREAKTIME1 = "/srb"
SLASH_SLASHIKRAIDBREAKTIME2 = "/slashikbreak"
SLASH_SLASHIKRAIDBREAKTIME3 = "/break"
SlashCmdList.SLASHIKRAIDBREAKTIME = function(input)
    local command, value = input:match("^(%S*)%s*(.-)$")
    command = command:lower()
    if command == "hide" or command == "stop" then
        frame:Hide()
    elseif command == "test" then
        showBreak(300, math.random(#images))
    else
        startBreak(tonumber(command))
    end
end
