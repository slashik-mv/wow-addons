-- Run from the addon directory with Lua 5.1 or newer.
local addon = {}
local now, seconds, guid, level = 1000, 100, "Player-A", 90
GetServerTime = function() return now end
C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return seconds end }
local warbandMoney = 400000000
C_Bank = { FetchDepositedMoney = function(bankType) assert(bankType == 2); return warbandMoney end }
Enum = { BankType = { Account = 2 } }
UnitGUID = function() return guid end
UnitLevel = function() return level end
GetMaxLevelForLatestExpansion = function() return 90 end
UnitFullName = function() return "Alt", "Realm" end
UnitClass = function() return "Mage", "MAGE" end
GetRealmName = function() return "Realm" end
local money = 123456789
GetMoney = function() return money end
local activeQuests, questTitles = {}, {}
C_QuestLog = {
  IsOnQuest = function(questID) return activeQuests[questID] == true end,
  GetTitleForQuestID = function(questID) return questTitles[questID] end,
}
assert(loadfile("Settings.lua"))("Slashik7MilTodoList", addon)
assert(loadfile("Tracker.lua"))("Slashik7MilTodoList", addon)
addon:InitializeDatabase()
addon:CheckWeeklyReset()
assert(addon.db.nextReset == 1100)
level = 79
addon:RegisterCharacter()
assert(#addon.db.order == 0, "below-80 alt must not register")
addon:RegisterCharacter(80)
addon:RegisterCharacter(80)
assert(#addon.db.order == 1, "level-up registers once")
assert(addon.db.characters[guid].level == 80)
assert(addon.db.characters[guid].money == money)
assert(addon:UpdateWarbandMoney())
assert(addon.db.warbandMoney == warbandMoney)
addon.db.characters[guid].completed.liadrin = true
addon:RegisterCharacter(85)
assert(addon.db.characters[guid].level == 85)
assert(#addon.db.order == 1 and addon.db.characters[guid].completed.liadrin)
addon:RegisterCharacter(90)
assert(addon.db.characters[guid].level == 90)
level, guid = 90, "Player-B"
money = 200000000
addon:RegisterCharacter()
assert(#addon.db.order == 2)
local totalMoney, knownCharacters, hasWarbandMoney, characterMoney, trackedWarbandMoney = addon:GetTrackedMoney()
assert(totalMoney == 723456789 and knownCharacters == 2 and hasWarbandMoney)
assert(characterMoney == 323456789 and trackedWarbandMoney == 400000000)
money = 150000000
assert(addon:UpdateCharacterMoney())
totalMoney, knownCharacters = addon:GetTrackedMoney()
assert(totalMoney == 673456789 and knownCharacters == 2, "money gains and spending update the account total")
warbandMoney = 450000000
assert(addon:UpdateWarbandMoney())
totalMoney = addon:GetTrackedMoney()
assert(totalMoney == 723456789, "Warband Bank deposits and withdrawals update without losing account gold")
addon:MoveCharacter(guid, -1)
assert(addon.db.order[1] == guid)
addon:MoveCharacter(guid, -1)
assert(addon.db.order[1] == guid, "boundary move is harmless")
addon:SetCompleted(guid, "abundance", true)
addon:SetCompleted("Player-A", "haranir", true)
addon:SetCompleted(guid, "invalid", true)
assert(addon.db.characters[guid].completed.invalid == nil)
addon:SetCompleted(guid, "abundance", false)
assert(not addon.db.characters[guid].completed.abundance)
addon:SetCompleted(guid, "abundance", true)
activeQuests[89507] = true
assert(addon:ReconcileActiveTrackedQuests())
assert(not addon.db.characters[guid].completed.abundance, "an active weekly must stay unchecked before turn-in")
activeQuests[89507] = nil
assert(addon:HandleQuestTurnedIn(89507))
assert(addon.db.characters[guid].completed.abundance, "turned-in Abundance auto-checks")
addon:SetCompleted(guid, "haranir", true)
activeQuests[92720] = true
assert(addon:ReconcileActiveTrackedQuests())
assert(not addon.db.characters[guid].completed.haranir, "an active Haranir story clears a stale check")
activeQuests[92720] = nil
assert(addon:HandleQuestTurnedIn(92720))
assert(addon.db.characters[guid].completed.haranir, "turned-in Haranir story auto-checks")
assert(addon:HandleQuestTurnedIn(93767))
assert(addon.db.characters[guid].completed.liadrin, "Liadrin variant auto-checks")
activeQuests[98172] = true
assert(addon:ReconcileActiveTrackedQuests())
assert(not addon.db.characters[guid].completed.liadrin, "active Trailing Xal'atath clears a stale Apex Cache check")
activeQuests[98172] = nil
assert(addon:HandleQuestTurnedIn(98172))
assert(addon.db.characters[guid].completed.liadrin, "turned-in Trailing Xal'atath auto-checks the Apex Cache")
assert(addon:HandleQuestTurnedIn(92848))
assert(addon.db.characters[guid].completed.assignment1, "first Special Assignment auto-checks slot one")
assert(not addon:HandleQuestTurnedIn(92145), "wrapper and activity IDs count as one assignment")
assert(not addon.db.characters[guid].completed.assignment2)
assert(addon:HandleQuestTurnedIn(94866))
assert(addon.db.characters[guid].completed.assignment2, "second Special Assignment auto-checks slot two")
assert(addon:HandleQuestTurnedIn(96029))
assert(addon.db.characters[guid].completed.assignment3, "Coiled Isle assignment auto-checks slot three")
questTitles[99999] = "Special Assignment: A Future Assignment"
assert(not addon:HandleQuestTurnedIn(99999), "future assignment is recorded after both regular slots are full")
addon:SetCompleted(guid, "abundance", true)
addon:InitializeDatabase()
assert(addon.db.characters[guid].completed.abundance, "reload preserves progress")
now, seconds = 1099, 1
assert(not addon:CheckWeeklyReset())
now, seconds = 1100, 604800
assert(addon:CheckWeeklyReset(), "deadline resets all alts")
assert(next(addon.db.characters[guid].completed) == nil)
assert(next(addon.db.characters[guid].automaticAssignments) == nil)
assert(next(addon.db.characters["Player-A"].completed) == nil)
assert(addon.db.order[1] == guid, "reset preserves order")
addon:SetCompleted(guid, "liadrin", true)
now, seconds = 2000000, nil
assert(addon:CheckWeeklyReset(), "offline across weeks clears progress")
assert(addon.db.nextReset == nil)
seconds = 400
addon:CheckWeeklyReset()
assert(addon.db.nextReset == now + 400, "server timing recovers")
addon.db.characters[guid].completed = { abundance = true, haranir = true, liadrin = true }
addon.db.characters[guid].automaticAssignments = { oldScan = true }
addon.db.automationVersion = 1
addon:InitializeDatabase()
assert(addon.db.automationVersion == 2)
assert(next(addon.db.characters[guid].completed) == nil, "1.6 automatic results are cleared once")
assert(next(addon.db.characters[guid].automaticAssignments) == nil, "1.6 assignment scan is cleared once")
print("PASS: registration, ordering, manual and automatic checks, active quest reconciliation, persistence, weekly reset, migration")
