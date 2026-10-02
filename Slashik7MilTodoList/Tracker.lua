local _, addon = ...

-- Quest IDs are more reliable than quest names and work with every client locale.
-- Pools contain the rotating variants that can satisfy one checklist column.
local AUTOMATIC_TASK_QUESTS = {
  abundance = { 89507 },
  haranir = {
    88993, 88994, 88995, 88996, 88997, 88998, 88999,
    92716, 92719, 92720, 92721, 92722, 92724, 92725,
  },
  liadrin = {
    93766, 93767, 93769, 93889, 93890, 93892, 93909, 93910,
    93911, 93912, 93913, 94457, 95842, 95843, 96727, 98232,
  },
}

-- Some capstone world quests have a wrapper ID and a separate activity ID.
-- Keeping both IDs in one group prevents a single assignment filling two slots.
local SPECIAL_ASSIGNMENTS = {
  { key = "grandMagistersDrink", ids = { 92848, 92145 } },
  { key = "shadeAndClaw", ids = { 92139 } },
  { key = "oursOnceMore", ids = { 94866, 91796 } },
  { key = "templeBroken", ids = { 94865, 91390 } },
  { key = "huntersRegret", ids = { 94390 } },
  { key = "pushBackTheLight", ids = { 94391, 93013 } },
  { key = "agentsOfTheShield", ids = { 94795, 93244 } },
  { key = "precisionExcision", ids = { 94743, 93438 } },
  { key = "coiledDemandAndSupply", coiled = true, ids = { 95921, 96492 } },
  { key = "coiledFaceTheSwarm", coiled = true, ids = { 95922, 96029 } },
  { key = "coiledWraithWrath", coiled = true, ids = { 96307 } },
}

local QUEST_TASK, QUEST_ASSIGNMENT = {}, {}
for taskID, questIDs in pairs(AUTOMATIC_TASK_QUESTS) do
  for _, questID in ipairs(questIDs) do QUEST_TASK[questID] = taskID end
end
for _, assignment in ipairs(SPECIAL_ASSIGNMENTS) do
  for _, questID in ipairs(assignment.ids) do QUEST_ASSIGNMENT[questID] = assignment end
end

local function IsQuestCompleted(questID)
  return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
    and C_QuestLog.IsQuestFlaggedCompleted(questID) == true
end

-- Store the actual regional deadline, so offline characters reset together.
function addon:CheckWeeklyReset()
  local now = GetServerTime()
  local seconds = C_DateAndTime.GetSecondsUntilWeeklyReset()
  local deadline = self.db.nextReset
  local changed = false
  if deadline and now >= deadline then
    for _, character in pairs(self.db.characters) do
      character.completed = {}
      character.automaticAssignments = {}
    end
    self.db.nextReset = nil
    changed = true
  end
  if type(seconds) == "number" and seconds > 0 then
    self.db.nextReset = now + seconds
  end
  return changed
end

function addon:RegisterCharacter(level)
  local characterLevel = level or UnitLevel("player")
  if characterLevel < 80 then return end
  local guid = UnitGUID("player")
  if not guid then return end
  local name, realm = UnitFullName("player")
  local _, class = UnitClass("player")
  local character = self.db.characters[guid]
  if not character then
    character = { completed = {}, automaticAssignments = {} }
    self.db.characters[guid] = character
    table.insert(self.db.order, guid)
  end
  character.completed = character.completed or {}
  character.automaticAssignments = character.automaticAssignments or {}
  character.level = characterLevel
  character.name, character.realm, character.class = name, realm or GetRealmName(), class
  self:UpdateCharacterMoney()
end

function addon:UpdateCharacterMoney()
  local guid = UnitGUID("player")
  local character = guid and self.db.characters[guid]
  if not character or not GetMoney then return false end
  character.money = GetMoney()
  return true
end

function addon:UpdateWarbandMoney()
  if not C_Bank or not C_Bank.FetchDepositedMoney or not Enum or not Enum.BankType then
    return false
  end
  local money = C_Bank.FetchDepositedMoney(Enum.BankType.Account)
  if type(money) ~= "number" then return false end
  self.db.warbandMoney = money
  return true
end

function addon:GetTrackedMoney()
  local total, knownCharacters = 0, 0
  for _, character in pairs(self.db.characters) do
    if type(character.money) == "number" then
      total = total + character.money
      knownCharacters = knownCharacters + 1
    end
  end
  local warbandMoney = type(self.db.warbandMoney) == "number" and self.db.warbandMoney or 0
  return total + warbandMoney, knownCharacters, self.db.warbandMoney ~= nil, total, warbandMoney
end

function addon:MoveCharacter(guid, offset)
  local order = self.db.order
  for index, value in ipairs(order) do
    if value == guid then
      local destination = index + offset
      if destination < 1 or destination > #order then return end
      order[index], order[destination] = order[destination], order[index]
      return
    end
  end
end

function addon:SetCompleted(guid, taskID, completed)
  self:CheckWeeklyReset()
  local character = self.db.characters[guid]
  if not character then return end
  for _, task in ipairs(self.tasks) do
    if task.id == taskID then
      character.completed[taskID] = completed and true or nil
      return
    end
  end
end

function addon:CompleteCurrentTask(taskID)
  local guid = UnitGUID("player")
  local character = guid and self.db.characters[guid]
  if not character or character.completed[taskID] then return false end
  character.completed[taskID] = true
  return true
end

function addon:RecordSpecialAssignment(assignment)
  local guid = UnitGUID("player")
  local character = guid and self.db.characters[guid]
  if not character or not assignment then return false end
  character.automaticAssignments = character.automaticAssignments or {}
  if character.automaticAssignments[assignment.key] then return false end
  character.automaticAssignments[assignment.key] = true

  if assignment.coiled then
    return self:CompleteCurrentTask("assignment3")
  end

  local count = 0
  for key, recorded in pairs(character.automaticAssignments) do
    if recorded then
      local coiled = false
      for _, known in ipairs(SPECIAL_ASSIGNMENTS) do
        if known.key == key then
          coiled = known.coiled == true
          break
        end
      end
      if not coiled then count = count + 1 end
    end
  end
  local changed = self:CompleteCurrentTask("assignment1")
  if count >= 2 then changed = self:CompleteCurrentTask("assignment2") or changed end
  return changed
end

function addon:HandleQuestTurnedIn(questID)
  if not self.db or type(questID) ~= "number" then return false end
  self:CheckWeeklyReset()
  self:RegisterCharacter()

  local taskID = QUEST_TASK[questID]
  if taskID then return self:CompleteCurrentTask(taskID) end

  local assignment = QUEST_ASSIGNMENT[questID]
  if assignment then return self:RecordSpecialAssignment(assignment) end

  -- This catches future English-client Special Assignments until their IDs are added.
  local title = C_QuestLog and C_QuestLog.GetTitleForQuestID
    and C_QuestLog.GetTitleForQuestID(questID)
  if type(title) == "string" and title:match("^Special Assignment:") then
    return self:RecordSpecialAssignment({ key = "quest" .. questID })
  end
  return false
end

function addon:ScanAutomaticCompletions()
  if not self.db or not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted then return false end
  self:CheckWeeklyReset()
  self:RegisterCharacter()
  local changed = false

  for taskID, questIDs in pairs(AUTOMATIC_TASK_QUESTS) do
    for _, questID in ipairs(questIDs) do
      if IsQuestCompleted(questID) then
        changed = self:CompleteCurrentTask(taskID) or changed
        break
      end
    end
  end

  for _, assignment in ipairs(SPECIAL_ASSIGNMENTS) do
    for _, questID in ipairs(assignment.ids) do
      if IsQuestCompleted(questID) then
        changed = self:RecordSpecialAssignment(assignment) or changed
        break
      end
    end
  end
  return changed
end
