local _, addon = ...

local MINIMUM_GOLD_REWARD = 800 * 10000
local MIDNIGHT_ZONE_ORDER = { "eversong", "zulaman", "harandar", "voidstorm", "coiled" }
local requestedRewardData = {}
local assignmentQuestIDs = {}

-- Special Assignment IDs belong to the weekly checklist, not the gold WQ list.
for _, assignment in ipairs(addon.specialAssignments) do
  for _, questID in ipairs(assignment.ids) do assignmentQuestIDs[questID] = true end
end

local function QuestID(info)
  return info and (info.questID or info.questId)
end

local function QuestTitle(questID)
  local title = C_TaskQuest.GetQuestInfoByQuestID(questID)
  if (type(title) ~= "string" or title == "") and C_QuestLog.GetTitleForQuestID then
    title = C_QuestLog.GetTitleForQuestID(questID)
  end
  return type(title) == "string" and title ~= "" and title or ("Quest " .. questID)
end

local function IsSpecialAssignment(questID, title)
  return assignmentQuestIDs[questID]
    or (type(title) == "string" and title:match("^Special Assignment:%s*")) ~= nil
end

local function CurrencyRewardCount(questID)
  if C_QuestLog.GetQuestRewardCurrencies then
    local currencies = C_QuestLog.GetQuestRewardCurrencies(questID)
    return type(currencies) == "table" and #currencies or 0
  end
  if GetNumQuestLogRewardCurrencies then
    return GetNumQuestLogRewardCurrencies(questID) or 0
  end
  return 0
end

local function ActiveWorldQuestIDs(zone)
  local questIDs, seen = {}, {}
  local zoneMapIDs = {}
  for _, mapID in ipairs(zone.mapIDs) do zoneMapIDs[mapID] = true end

  for _, mapID in ipairs(zone.mapIDs) do
    local quests = C_TaskQuest.GetQuestsOnMap(mapID)
    if type(quests) == "table" then
      for _, info in ipairs(quests) do
        local questID = QuestID(info)
        local questMapID = info.mapID
        if not questMapID and questID and C_TaskQuest.GetQuestZoneID then
          questMapID = C_TaskQuest.GetQuestZoneID(questID)
        end
        local isWorldQuest = questID and (not QuestUtils_IsQuestWorldQuest
          or QuestUtils_IsQuestWorldQuest(questID))
        if questID and zoneMapIDs[questMapID] and isWorldQuest and not seen[questID] then
          seen[questID] = true
          table.insert(questIDs, questID)
        end
      end
    end
  end
  return questIDs
end

local function GoldWorldQuests(zone)
  local quests, totalGold, loading = {}, 0, false

  for _, questID in ipairs(ActiveWorldQuestIDs(zone)) do
    local title = QuestTitle(questID)
    if not IsSpecialAssignment(questID, title)
      and not C_QuestLog.IsQuestFlaggedCompleted(questID)
    then
      if HaveQuestRewardData(questID) then
        local money = GetQuestLogRewardMoney(questID)
        local itemRewards = GetNumQuestLogRewards(questID)
        local currencyRewards = CurrencyRewardCount(questID)
        if type(money) == "number" and money >= MINIMUM_GOLD_REWARD
          and itemRewards == 0 and currencyRewards == 0
        then
          table.insert(quests, { questID = questID, title = title, money = money })
          totalGold = totalGold + money
        end
      else
        if not requestedRewardData[questID] then
          requestedRewardData[questID] = true
          C_TaskQuest.RequestPreloadRewardData(questID)
        end
        loading = true
      end
    end
  end

  table.sort(quests, function(left, right)
    if left.money ~= right.money then return left.money > right.money end
    return left.title < right.title
  end)
  return quests, totalGold, loading
end

function addon:ScanGoldWorldQuestZones()
  local results, loadingRewards = {}, false

  for _, zoneKey in ipairs(MIDNIGHT_ZONE_ORDER) do
    local zone = self.midnightZones[zoneKey]
    local result = {
      key = zoneKey,
      name = zone.name,
      goldQuests = {},
      goldQuestCount = 0,
      totalGold = 0,
    }
    table.insert(results, result)

    -- A failure in one Blizzard API response must not blank every zone.
    local ok, quests, totalGold, loading = pcall(GoldWorldQuests, zone)
    if ok then
      result.goldQuests = quests
      result.goldQuestCount = #quests
      result.totalGold = totalGold
      loadingRewards = loadingRewards or loading
    else
      result.scanError = tostring(quests)
    end
  end

  return results, loadingRewards
end

function addon:PrintGoldWorldQuestDebug()
  print("|cffffd166Slashik7MilTodoList Midnight gold quest debug|r")
  if self.lastGoldQuestScanError then
    print("|cffff5555Last scan error:|r " .. self.lastGoldQuestScanError)
  end
  local zones, loading = self:ScanGoldWorldQuestZones()
  for _, zone in ipairs(zones) do
    print(string.format("%s: %d qualifying quest(s), %d copper total",
      zone.name, zone.goldQuestCount, zone.totalGold))
    for _, quest in ipairs(zone.goldQuests) do
      print(string.format("  %d | %s | %d copper", quest.questID, quest.title, quest.money))
    end
    if zone.scanError then print("  Error: " .. zone.scanError) end
  end
  print("Reward loading=" .. tostring(loading))
end
