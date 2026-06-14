local SlashikWhichDungeonInviteAddon = _G.SlashikWhichDungeonInviteAddon
local S = SlashikWhichDungeonInviteAddon.Settings

-- Create a frame
local f = CreateFrame("Frame")

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
    text:SetFont(font, 60, flags)

    frame.text = text
    frame:Show()

    C_Timer.After(duration or 10, function()
        frame:Hide()
    end)
end

local function printWarning(msg)
    print("►►► Group Name: " .. msg)
    if S:Get("enabledScreenWarning") == true then
      ShowBigTextInCenter(msg, 7)
    end
end


local function SendGreetingToGroup()
    local message = "Greetings, travelers!"
    local channel

    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        channel = "INSTANCE_CHAT"
    elseif IsInRaid() then
        channel = "RAID"
    elseif IsInGroup() then
        channel = "PARTY"
    end

    if channel then
        SendChatMessage(message, channel)
    end
end

local function OnSearchResultUpdated(resultID, newStatus, groupName)
  if not resultID then return end

  if newStatus ~= "inviteaccepted" then return end

  local applicationInfo = C_LFGList.GetSearchResultInfo(resultID)

  local activityID = applicationInfo.activityID or (applicationInfo.activityIDs and applicationInfo.activityIDs[1])
  local activityName = activityID and C_LFGList.GetActivityFullName(activityID) or "Unknown activity"

  printWarning(activityName .. ": " .. (groupName or applicationInfo.name or ""))

  if S:Get("enabledHI") == true then
    -- small delay so the group channel is fully available
    C_Timer.After(3, SendGreetingToGroup)
  end
end

  -- Set the OnEvent script handler 
f:SetScript("OnEvent", function(self, event, resultID, newStatus, oldStatus, groupName)
    if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
      OnSearchResultUpdated(resultID, newStatus, groupName)
    end
  end)

  -- Register events
f:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")