local _, addon = ...

-- Store the actual regional deadline, so offline characters reset together.
function addon:CheckWeeklyReset()
  local now = GetServerTime()
  local seconds = C_DateAndTime.GetSecondsUntilWeeklyReset()
  local deadline = self.db.nextReset
  local changed = false
  if deadline and now >= deadline then
    for _, character in pairs(self.db.characters) do character.completed = {} end
    self.db.nextReset = nil
    changed = true
  end
  if type(seconds) == "number" and seconds > 0 then
    self.db.nextReset = now + seconds
  end
  return changed
end

function addon:RegisterCharacter(level)
  -- Midnight's cap is 90. Account expansion ownership must not register level-80 alts.
  local maxLevel = GetMaxLevelForLatestExpansion and GetMaxLevelForLatestExpansion() or 90
  if (level or UnitLevel("player")) < maxLevel then return end
  local guid = UnitGUID("player")
  if not guid then return end
  local name, realm = UnitFullName("player")
  local _, class = UnitClass("player")
  local character = self.db.characters[guid]
  if not character then
    character = { completed = {} }
    self.db.characters[guid] = character
    table.insert(self.db.order, guid)
  end
  character.name, character.realm, character.class = name, realm or GetRealmName(), class
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
