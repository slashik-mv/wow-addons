-- Run from the addon directory with Lua 5.1 or newer.
local addon = {}
local completed, requested, watched = {}, {}, {}
local superTrackedQuestID
-- Blizzard can return quests from the wider map context. The returned mapID,
-- not merely the map passed to GetQuestsOnMap, identifies the quest's zone.
local mapQuests = {
  { questID = 10001, mapID = 2395 },
  { questId = 10002, mapID = 2395 },
  { questID = 10003, mapID = 2395 },
  { questID = 10004, mapID = 2395 },
  { questID = 10005, mapID = 2395 },
  { questID = 10006, mapID = 2395 },
  { questID = 92145, mapID = 2395 },
  { questID = 20001, mapID = 2437 },
  { questID = 30001 },
  { questID = 30002, mapID = 2512 },
  { questID = 40001, mapID = 2395 },
}
local questZones = { [30001] = 2413 }
local titles = {
  [10001] = "Sunlit Profits",
  [10002] = "Another Golden Opportunity",
  [10003] = "Rewards Still Loading",
  [10004] = "Gear With Converted Gold",
  [10005] = "Below Minimum Reward",
  [10006] = "Currency With Converted Gold",
  [92145] = "Special Assignment: The Grand Magister's Drink",
  [20001] = "Amani Payday",
  [30001] = "Harandar Holdings",
  [30002] = "Coiled Coin",
  [40001] = "Not Actually a World Quest",
}
local rewardMoney = {
  [10001] = 8000000,
  [10002] = 9000000,
  [10004] = 10000000,
  [10005] = 7990000,
  [10006] = 11000000,
  [92145] = 15000000,
  [20001] = 12000000,
  [30001] = 8500000,
  [30002] = 9500000,
  [40001] = 13000000,
}
local itemRewards = { [10004] = 1 }
local currencyRewards = { [10006] = {{ currencyID = 1 }} }

C_TaskQuest = {
  GetQuestsOnMap = function() return mapQuests end,
  GetQuestInfoByQuestID = function(questID) return titles[questID] end,
  GetQuestZoneID = function(questID) return questZones[questID] end,
  RequestPreloadRewardData = function(questID) requested[questID] = true end,
}
C_QuestLog = {
  IsQuestFlaggedCompleted = function(questID) return completed[questID] == true end,
  GetTitleForQuestID = function(questID) return titles[questID] end,
  GetQuestRewardCurrencies = function(questID) return currencyRewards[questID] or {} end,
  GetQuestWatchType = function(questID) return watched[questID] end,
  AddWorldQuestWatch = function(questID, watchType)
    watched[questID] = watchType
    return true
  end,
}
C_SuperTrack = {
  SetSuperTrackedQuestID = function(questID) superTrackedQuestID = questID end,
}
Enum = { QuestWatchType = { Manual = 1 } }
HaveQuestRewardData = function(questID) return rewardMoney[questID] ~= nil end
GetQuestLogRewardMoney = function(questID) return rewardMoney[questID] or 0 end
GetNumQuestLogRewards = function(questID) return itemRewards[questID] or 0 end
GetNumQuestLogRewardCurrencies = nil
QuestUtils_IsQuestWorldQuest = function(questID) return questID ~= 40001 end

assert(loadfile("Settings.lua"))("Slashik7MilTodoList", addon)
assert(loadfile("Tracker.lua"))("Slashik7MilTodoList", addon)
assert(loadfile("Recommendations.lua"))("Slashik7MilTodoList", addon)

local zones, loading = addon:ScanGoldWorldQuestZones()
assert(#zones == 5, "all five Midnight zones are returned")
assert(zones[1].name == "Eversong Woods" and zones[2].name == "Zul'Aman"
  and zones[3].name == "Harandar" and zones[4].name == "Voidstorm"
  and zones[5].name == "Coiled Isle", "zones use a stable order")
assert(zones[1].goldQuestCount == 2 and zones[1].totalGold == 17000000,
  "only direct-gold quests worth at least 800 gold are included")
assert(zones[1].goldQuests[1].questID == 10002, "quests are ordered by reward")
assert(zones[2].goldQuestCount == 1 and zones[2].totalGold == 12000000)
assert(zones[3].goldQuestCount == 1 and zones[4].goldQuestCount == 0
  and zones[5].goldQuestCount == 1, "zones with and without matches are represented")
assert(zones[2].goldQuests[1].questID == 20001,
  "quests returned for multiple maps are assigned only to their real zone")
assert(loading and requested[10003], "missing reward data is requested")
assert(addon:TrackGoldWorldQuest(10001), "a gold world quest can be tracked")
assert(watched[10001] == Enum.QuestWatchType.Manual,
  "click tracking uses Blizzard's manual world quest watch type")
assert(superTrackedQuestID == 10001, "the clicked world quest becomes super tracked")

completed[10002] = true
zones = addon:ScanGoldWorldQuestZones()
assert(zones[1].goldQuestCount == 1 and zones[1].goldQuests[1].questID == 10001,
  "completed quests are removed per character")

print("PASS: Midnight zone gold quests, reward filters, loading and completion")
