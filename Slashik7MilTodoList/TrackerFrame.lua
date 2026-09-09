local _, addon = ...
local ROW_HEIGHT, NAME_WIDTH, COLUMN_WIDTH = 38, 280, 126

local function Text(parent, font, x, y, width, value)
  local text = parent:CreateFontString(nil, "OVERLAY", font)
  text:SetPoint("TOPLEFT", x, y)
  text:SetWidth(width)
  text:SetJustifyH("LEFT")
  text:SetText(value)
  return text
end

local function Button(parent, label, width, height, callback)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width, height)
  button:SetText(label)
  button:SetScript("OnClick", callback)
  return button
end

function addon:CreateWindow()
  local frame = CreateFrame("Frame", "Slashik7MilTodoListFrame", UIParent, "BackdropTemplate")
  self.window = frame
  frame:Hide()
  frame:SetSize(970, 570)
  frame:SetScale(math.min(1, UIParent:GetWidth() / 1000, UIParent:GetHeight() / 600))
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  frame:SetBackdropColor(0.035, 0.045, 0.075, 0.98)
  frame:SetBackdropBorderColor(0.75, 0.58, 0.24)
  local position = self.db.position
  if position then frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
  else frame:SetPoint("CENTER") end
  table.insert(UISpecialFrames, "Slashik7MilTodoListFrame")

  local titleBar = CreateFrame("Frame", nil, frame)
  titleBar:SetPoint("TOPLEFT", 8, -8)
  titleBar:SetPoint("TOPRIGHT", -40, -8)
  titleBar:SetHeight(58)
  titleBar:EnableMouse(true)
  titleBar:RegisterForDrag("LeftButton")
  titleBar:SetScript("OnDragStart", function()
    if not self.db.settings.lockWindow then frame:StartMoving() end
  end)
  local function SavePosition()
    frame:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint()
    self.db.position = { point = point, relativePoint = relativePoint, x = x, y = y }
  end
  titleBar:SetScript("OnDragStop", SavePosition)
  frame:SetScript("OnHide", SavePosition)
  local icon = titleBar:CreateTexture(nil, "ARTWORK")
  icon:SetSize(42, 42)
  icon:SetPoint("TOPLEFT", 10, -8)
  icon:SetTexture("Interface\\AddOns\\Slashik7MilTodoList\\addonIcon")
  Text(titleBar, "GameFontNormalLarge", 62, -10, 600, "Slashik7MilTodoList")
  Text(titleBar, "GameFontHighlightSmall", 62, -33, 700, "Your alt army. Five weeklies. One gold goal.")
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  frame.summary = Text(frame, "GameFontHighlight", 22, -77, 900, "")
  Text(frame, "GameFontNormal", 22, -114, NAME_WIDTH, "Character / realm")
  for index, task in ipairs(self.tasks) do
    local label = Text(frame, "GameFontNormal", 22 + NAME_WIDTH + (index - 1) * COLUMN_WIDTH, -106, COLUMN_WIDTH, task.label)
    label:SetJustifyH("CENTER")
  end
  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 22, -150)
  scroll:SetPoint("BOTTOMRIGHT", -38, 76)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(910, 1)
  scroll:SetScrollChild(content)
  frame.content, frame.rows = content, {}
  frame.empty = Text(content, "GameFontHighlight", 12, -24, 870, "Log into a level-90 character to add it to your checklist.")
  Text(frame, "GameFontDisableSmall", 22, -506, 900, "Manual checkboxes • Progress resets every week • Use Up / Dn to reorder characters")
  local settings = Button(frame, "Settings", 110, 25, function() self:OpenSettings() end)
  settings:SetPoint("BOTTOMRIGHT", -22, 18)
  frame.resetLabel = Text(frame, "GameFontHighlightSmall", 22, -536, 740, "")
  frame:SetScript("OnShow", function() self:CheckWeeklyReset(); self:RefreshWindow() end)
end

function addon:CreateRow(index)
  local row = CreateFrame("Frame", nil, self.window.content)
  row:SetSize(910, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
  row.background = row:CreateTexture(nil, "BACKGROUND")
  row.background:SetAllPoints()
  row.name = Text(row, "GameFontHighlight", 4, -4, 208, "")
  row.realm = Text(row, "GameFontDisableSmall", 4, -22, 208, "")
  row.up = Button(row, "Up", 30, 24, function() self:MoveCharacter(row.guid, -1); self:RefreshWindow() end)
  row.up:SetPoint("TOPLEFT", 214, -7)
  row.down = Button(row, "Dn", 30, 24, function() self:MoveCharacter(row.guid, 1); self:RefreshWindow() end)
  row.down:SetPoint("TOPLEFT", 245, -7)
  row.checks = {}
  for taskIndex, task in ipairs(self.tasks) do
    local taskID = task.id
    local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    check:SetSize(28, 28)
    check:SetPoint("TOPLEFT", NAME_WIDTH + (taskIndex - 1) * COLUMN_WIDTH + (COLUMN_WIDTH - 28) / 2, -5)
    check:SetScript("OnClick", function(button)
      self:SetCompleted(row.guid, taskID, button:GetChecked())
      self:RefreshWindow()
    end)
    check:SetScript("OnEnter", function(button)
      GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.db.characters[row.guid].name)
      GameTooltip:AddLine(task.label:gsub("\n", " "), 1, 0.82, 0)
      GameTooltip:AddLine("Click to mark complete or incomplete.", 1, 1, 1)
      GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.checks[taskIndex] = check
  end
  self.window.rows[index] = row
  return row
end

function addon:RefreshWindow()
  local frame, total = self.window, 0
  if not frame then return end
  local count = #self.db.order
  frame.empty:SetShown(count == 0)
  frame.content:SetHeight(math.max(80, count * ROW_HEIGHT))
  for index, guid in ipairs(self.db.order) do
    local character = self.db.characters[guid]
    local row = frame.rows[index] or self:CreateRow(index)
    row.guid = guid
    local current = guid == UnitGUID("player")
    row.background:SetColorTexture(current and 0.18 or 0.12, current and 0.16 or 0.14, 0.19, current and 0.9 or (index % 2 == 0 and 0.55 or 0.2))
    row.name:SetText(character.name .. (current and " (you)" or ""))
    local color = RAID_CLASS_COLORS[character.class]
    if color then row.name:SetTextColor(color.r, color.g, color.b) end
    row.realm:SetText(character.realm)
    row.up:SetEnabled(index > 1)
    row.down:SetEnabled(index < count)
    for taskIndex, task in ipairs(self.tasks) do
      local completed = character.completed[task.id] == true
      row.checks[taskIndex]:SetChecked(completed)
      if completed then total = total + 1 end
    end
    row:Show()
  end
  for index = count + 1, #frame.rows do frame.rows[index]:Hide() end
  frame.summary:SetText(string.format("%d characters  |  %d / %d weeklies completed", count, total, count * #self.tasks))
  local remaining = self.db.nextReset and math.max(0, self.db.nextReset - GetServerTime())
  frame.resetLabel:SetText(remaining and ("Weekly reset in " .. SecondsToTime(remaining)) or "Waiting for the server's weekly reset time...")
end

function addon:ShowWindow()
  if not self.window then self:CreateWindow() end
  self.window:Show()
end

function addon:ToggleWindow()
  if not self.window then self:CreateWindow() end
  self.window:SetShown(not self.window:IsShown())
end
