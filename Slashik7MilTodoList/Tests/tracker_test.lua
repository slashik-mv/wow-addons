-- Run from the addon directory with Lua 5.1 or newer.
local addon = {}
local now, seconds, guid, level = 1000, 100, "Player-A", 90
GetServerTime = function() return now end
C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return seconds end }
UnitGUID = function() return guid end
UnitLevel = function() return level end
GetMaxLevelForLatestExpansion = function() return 90 end
UnitFullName = function() return "Alt", "Realm" end
UnitClass = function() return "Mage", "MAGE" end
GetRealmName = function() return "Realm" end
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
addon.db.characters[guid].completed.liadrin = true
addon:RegisterCharacter(85)
assert(addon.db.characters[guid].level == 85)
assert(#addon.db.order == 1 and addon.db.characters[guid].completed.liadrin)
addon:RegisterCharacter(90)
assert(addon.db.characters[guid].level == 90)
level, guid = 90, "Player-B"
addon:RegisterCharacter()
assert(#addon.db.order == 2)
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
addon:InitializeDatabase()
assert(addon.db.characters[guid].completed.abundance, "reload preserves progress")
now, seconds = 1099, 1
assert(not addon:CheckWeeklyReset())
now, seconds = 1100, 604800
assert(addon:CheckWeeklyReset(), "deadline resets all alts")
assert(next(addon.db.characters[guid].completed) == nil)
assert(next(addon.db.characters["Player-A"].completed) == nil)
assert(addon.db.order[1] == guid, "reset preserves order")
addon:SetCompleted(guid, "liadrin", true)
now, seconds = 2000000, nil
assert(addon:CheckWeeklyReset(), "offline across weeks clears progress")
assert(addon.db.nextReset == nil)
seconds = 400
addon:CheckWeeklyReset()
assert(addon.db.nextReset == now + 400, "server timing recovers")
print("PASS: registration, deduplication, level-up, ordering, manual checks, persistence, weekly/offline reset, API recovery")
