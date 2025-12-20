-- Create a frame
local f = CreateFrame("Frame")

local function OnSearchResultUpdated(resultID, newStatus, groupName)
  if not resultID then return end

  if newStatus ~= "inviteaccepted" then return end

  local applicationInfo = C_LFGList.GetSearchResultInfo(resultID)
  if not applicationInfo then return end

  local activityID = applicationInfo.activityID or (applicationInfo.activityIDs and applicationInfo.activityIDs[1])
  local activityName = activityID and C_LFGList.GetActivityFullName(activityID) or "Unknown activity"

  print("►►► Group Name: " .. activityName .. ": " .. (groupName or applicationInfo.name or ""))
end

  -- Set the OnEvent script handler 
f:SetScript("OnEvent", function(self, event, resultID, newStatus, oldStatus, groupName)
    if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
      OnSearchResultUpdated(resultID, newStatus, groupName)
    end
  end)

  -- Register events
f:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
print("Hello, WhichDungeonInvite!")
