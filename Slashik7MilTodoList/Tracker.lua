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
    93911, 93912, 93913, 94457, 95842, 95843, 96727, 98172, 98232,
  },
}

-- Some capstone world quests have a wrapper ID and a separate activity ID.
-- Keeping both IDs in one group prevents a single assignment filling two slots.
addon.midnightZones = {
  eversong = { name = "Eversong Woods", mapIDs = { 2395 } },
  zulaman = { name = "Zul'Aman", mapIDs = { 2437 } },
  harandar = { name = "Harandar", mapIDs = { 2413 } },
  voidstorm = { name = "Voidstorm", mapIDs = { 2405, 2444 } },
  coiled = { name = "Coiled Isle", mapIDs = { 2512 } },
}
local SPECIAL_ASSIGNMENTS = {
  { key = "grandMagistersDrink", zone = "eversong", title = "The Grand Magister's Drink", ids = { 92848, 92145 } },
  { key = "shadeAndClaw", zone = "eversong", title = "Shade and Claw", ids = { 92139 } },
  { key = "oursOnceMore", zone = "zulaman", title = "Ours Once More!", ids = { 94866, 91796 } },
  { key = "templeBroken", zone = "zulaman", title = "What Remains of a Temple Broken", ids = { 94865, 91390 } },
  { key = "huntersRegret", zone = "harandar", title = "A Hunter's Regret", ids = { 94390 } },
  { key = "pushBackTheLight", zone = "harandar", title = "Push Back the Light", ids = { 94391, 93013 } },
  { key = "agentsOfTheShield", zone = "voidstorm", title = "Agents of the Shield", ids = { 94795, 93244 } },
  { key = "precisionExcision", zone = "voidstorm", title = "Precision Excision", ids = { 94743, 93438 } },
  { key = "coiledDemandAndSupply", zone = "coiled", title = "Demand and Supply", coiled = true, ids = { 95921, 96492 } },
  { key = "coiledFaceTheSwarm", zone = "coiled", title = "Face the Swarm", coiled = true, ids = { 95922, 96029 } },
  { key = "coiledWraithWrath", zone = "coiled", title = "Wraith Wrath", coiled = true, ids = { 96307 } },
}
addon.specialAssignments = SPECIAL_ASSIGNMENTS

local QUEST_TASK, QUEST_ASSIGNMENT = {}, {}
for taskID, questIDs in pairs(AUTOMATIC_TASK_QUESTS) do
  for _, questID in ipairs(questIDs) do QUEST_TASK[questID] = taskID end
end
for _, assignment in ipairs(SPECIAL_ASSIGNMENTS) do
  for _, questID in ipairs(assignment.ids) do QUEST_ASSIGNMENT[questID] = assignment end
end

local function IsQuestOnLog(questID)
  if not C_QuestLog then return false end
  if C_QuestLog.IsOnQuest then return C_QuestLog.IsOnQuest(questID) == true end
  if C_QuestLog.GetLogIndexForQuestID then
    local index = C_QuestLog.GetLogIndexForQuestID(questID)
    return type(index) == "number" and index > 0
  end
  return false
end

local function NewCashFlowPeriod(key)
  return { key = key, earnings = 0, spending = 0 }
end

local function CashFlowPeriodKeys(nextReset)
  local calendar = C_DateAndTime.GetCurrentCalendarTime()
  local year, month, day = calendar.year, calendar.month, calendar.monthDay
  return {
    daily = string.format("%04d-%02d-%02d", year, month, day),
    -- Round to the nearest hour so small API timing differences cannot create a new week.
    weekly = tostring(math.floor(((nextReset or 0) + 1800) / 3600)),
    monthly = string.format("%04d-%02d", year, month),
  }
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
  local firstBalance = type(character.money) ~= "number"
  character.money = GetMoney()
  if firstBalance and self.db.cashFlow and type(self.db.cashFlow.lastTotal) == "number" then
    self.db.cashFlow.lastTotal = self.db.cashFlow.lastTotal + character.money
  end
  return true
end

function addon:UpdateWarbandMoney()
  if not C_Bank or not C_Bank.FetchDepositedMoney or not Enum or not Enum.BankType then
    return false
  end
  local money = C_Bank.FetchDepositedMoney(Enum.BankType.Account)
  if type(money) ~= "number" then return false end
  local firstBalance = type(self.db.warbandMoney) ~= "number"
  self.db.warbandMoney = money
  if firstBalance and self.db.cashFlow and type(self.db.cashFlow.lastTotal) == "number" then
    self.db.cashFlow.lastTotal = self.db.cashFlow.lastTotal + money
  end
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

function addon:InitializeCashFlow()
  local cashFlow = self.db.cashFlow
  if type(cashFlow) ~= "table" then
    cashFlow = {}
    self.db.cashFlow = cashFlow
  end
  cashFlow.total = type(cashFlow.total) == "table" and cashFlow.total or NewCashFlowPeriod("total")
  cashFlow.total.earnings = cashFlow.total.earnings or 0
  cashFlow.total.spending = cashFlow.total.spending or 0

  local periodKeys = CashFlowPeriodKeys(self.db.nextReset)
  if (cashFlow.periodVersion or 0) < 2 then
    -- Version 1 rounded the reset deadline down. Near an hour boundary that could
    -- clear the weekly bucket while leaving today's bucket intact.
    if type(cashFlow.weekly) == "table" then
      cashFlow.weekly.key = periodKeys.weekly
      if type(cashFlow.daily) == "table" then
        cashFlow.weekly.earnings = math.max(cashFlow.weekly.earnings or 0, cashFlow.daily.earnings or 0)
        cashFlow.weekly.spending = math.max(cashFlow.weekly.spending or 0, cashFlow.daily.spending or 0)
      end
    end
    cashFlow.periodVersion = 2
  end

  for period, key in pairs(periodKeys) do
    if type(cashFlow[period]) ~= "table" or cashFlow[period].key ~= key then
      cashFlow[period] = NewCashFlowPeriod(key)
    end
  end
  return cashFlow
end

function addon:InitializeCashFlowBaseline()
  local cashFlow = self:InitializeCashFlow()
  cashFlow.lastTotal = self:GetTrackedMoney()
end

function addon:RecordCashFlow()
  local cashFlow = self:InitializeCashFlow()
  local trackedMoney = self:GetTrackedMoney()
  if type(cashFlow.lastTotal) ~= "number" then
    cashFlow.lastTotal = trackedMoney
    return 0
  end

  local change = trackedMoney - cashFlow.lastTotal
  cashFlow.lastTotal = trackedMoney
  if change == 0 then return 0 end

  local field = change > 0 and "earnings" or "spending"
  local amount = math.abs(change)
  for _, period in ipairs({ "daily", "weekly", "monthly", "total" }) do
    cashFlow[period][field] = (cashFlow[period][field] or 0) + amount
  end
  return change
end

function addon:GetCashFlowSummary()
  return self:InitializeCashFlow()
end

function addon:ResetCashFlow()
  self.db.cashFlow = nil
  self:InitializeCashFlowBaseline()
end

function addon:QueueMoneyUpdate()
  self.moneyUpdateGeneration = (self.moneyUpdateGeneration or 0) + 1
  local generation = self.moneyUpdateGeneration
  C_Timer.After(0.75, function()
    if generation ~= self.moneyUpdateGeneration or not self.db then return end
    self:UpdateCharacterMoney()
    self:UpdateWarbandMoney()
    self:RecordCashFlow()
    if self.window and self.window:IsShown() then self:RefreshWindow() end
  end)
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

function addon:ReconcileActiveTrackedQuests()
  if not self.db then return false end
  self:CheckWeeklyReset()
  self:RegisterCharacter()
  local guid = UnitGUID("player")
  local character = guid and self.db.characters[guid]
  if not character then return false end
  local changed = false

  for taskID, questIDs in pairs(AUTOMATIC_TASK_QUESTS) do
    for _, questID in ipairs(questIDs) do
      if IsQuestOnLog(questID) then
        if character.completed[taskID] then
          character.completed[taskID] = nil
          changed = true
        end
        break
      end
    end
  end
  return changed
end
