-- Run from the addon directory with Lua 5.1 or newer.
local addon = {}
local completed, requested = {}, {}
local mapQuests = {
  [2395] = {
    { questID = 10001 },
    { questId = 10002 },
    { questID = 10003 },
    { questID = 10004 },
    { questID = 10005 },
    { questID = 10006 },
    { questID = 92145 },
  },
  [2437] = {{ questID = 20001 }},
  [2413] = {{ questID = 30001 }},
  [2512] = {{ questID = 30002 }},
}
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
}
local itemRewards = { [10004] = 1 }
local currencyRewards = { [10006] = {{ currencyID = 1 }} }

C_TaskQuest = {
  GetQuestsOnMap = function(mapID) return mapQuests[mapID] end,
  GetQuestInfoByQuestID = function(questID) return titles[questID] end,
  RequestPreloadRewardData = function(questID) requested[questID] = true end,
}
C_QuestLog = {
  IsQuestFlaggedCompleted = function(questID) return completed[questID] == true end,
  GetTitleForQuestID = function(questID) return titles[questID] end,
  GetQuestRewardCurrencies = function(questID) return currencyRewards[questID] or {} end,
}
HaveQuestRewardData = function(questID) return rewardMoney[questID] ~= nil end
GetQuestLogRewardMoney = function(questID) return rewardMoney[questID] or 0 end
GetNumQuestLogRewards = function(questID) return itemRewards[questID] or 0 end
GetNumQuestLogRewardCurrencies = nil

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
assert(loading and requested[10003], "missing reward data is requested")

completed[10002] = true
zones = addon:ScanGoldWorldQuestZones()
assert(zones[1].goldQuestCount == 1 and zones[1].goldQuests[1].questID == 10001,
  "completed quests are removed per character")

print("PASS: Midnight zone gold quests, reward filters, loading and completion")
