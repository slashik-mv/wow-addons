local _, addon = ...
local ROW_HEIGHT, NAME_WIDTH, COLUMN_WIDTH = 38, 280, 146
local TABLE_WIDTH = NAME_WIDTH + #addon.tasks * COLUMN_WIDTH
local WINDOW_WIDTH = TABLE_WIDTH + 60
local GOLD_GOAL = 7000000 * 10000

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
  frame:SetSize(WINDOW_WIDTH, 570)
  frame:SetScale(math.min(1, UIParent:GetWidth() / (WINDOW_WIDTH + 30), UIParent:GetHeight() / 600))
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
  Text(titleBar, "GameFontHighlightSmall", 62, -33, 700, "Your alt army. Your weekly checklist. One gold goal.")
  local goldPanel = CreateFrame("Frame", nil, titleBar)
  goldPanel:SetSize(430, 50)
  goldPanel:SetPoint("TOPRIGHT", -8, -3)
  goldPanel:EnableMouse(true)
  goldPanel.characters = goldPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  goldPanel.characters:SetPoint("TOPRIGHT", 0, -1)
  goldPanel.warband = goldPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  goldPanel.warband:SetPoint("TOPRIGHT", 0, -18)
  goldPanel.total = goldPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  goldPanel.total:SetPoint("TOPRIGHT", 0, -36)
  goldPanel:SetScript("OnEnter", function(panel)
    GameTooltip:SetOwner(panel, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText("Account gold tracker")
    GameTooltip:AddLine("The total includes the Warband Bank and the latest balance seen on each tracked character.", 1, 1, 1, true)
    GameTooltip:AddLine("Log into every level-80+ alt once to include its gold. Gains, purchases, bank deposits, and withdrawals update automatically.", 1, 0.82, 0, true)
    GameTooltip:Show()
  end)
  goldPanel:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.goldPanel = goldPanel
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  frame.summary = Text(frame, "GameFontHighlight", 22, -77, 500, "")
  local goldBar = CreateFrame("StatusBar", nil, frame, "BackdropTemplate")
  goldBar:SetSize(WINDOW_WIDTH - 600, 30)
  goldBar:SetPoint("TOP", frame, "TOP", 70, -17)
  goldBar:SetMinMaxValues(0, GOLD_GOAL)
  goldBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  goldBar:SetStatusBarColor(0.95, 0.68, 0.05)
  goldBar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  goldBar:SetBackdropColor(0.02, 0.025, 0.04, 0.9)
  goldBar:SetBackdropBorderColor(0.55, 0.43, 0.18, 1)
  goldBar.text = goldBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  goldBar.text:SetPoint("CENTER")
  goldBar.text:SetShadowOffset(1, -1)
  frame.goldBar = goldBar
  frame.goldMilestones = {}
  local function AddGoldMilestone(amount, label, red, green, blue)
    local marker = goldBar:CreateTexture(nil, "OVERLAY")
    marker:SetSize(2, 26)
    marker:SetPoint("CENTER", goldBar, "LEFT", (amount / GOLD_GOAL) * (WINDOW_WIDTH - 600), 0)
    marker:SetColorTexture(red, green, blue, 0.95)
    local markerLabel = goldBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    markerLabel:SetPoint("LEFT", marker, "RIGHT", 4, 0)
    markerLabel:SetText(label)
    markerLabel:SetTextColor(red, green, blue)
    markerLabel:SetShadowOffset(1, -1)
    table.insert(frame.goldMilestones, {
      amount = amount, marker = marker, label = markerLabel,
      red = red, green = green, blue = blue,
    })
  end
  AddGoldMilestone(5000000 * 10000, "5M", 0.25, 0.85, 1)
  AddGoldMilestone(5500000 * 10000, "5.5M", 0.85, 0.5, 1)
  Text(frame, "GameFontNormal", 22, -114, NAME_WIDTH, "Character / realm")
  for index, task in ipairs(self.tasks) do
    local label = Text(frame, "GameFontNormal", 22 + NAME_WIDTH + (index - 1) * COLUMN_WIDTH, -106, COLUMN_WIDTH, task.label)
    label:SetJustifyH("CENTER")
  end
  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 22, -150)
  scroll:SetPoint("BOTTOMRIGHT", -38, 76)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(TABLE_WIDTH, 1)
  scroll:SetScrollChild(content)
  frame.content, frame.rows = content, {}
  frame.empty = Text(content, "GameFontHighlight", 12, -24, 870, "Log into a level-80 or higher character to add it to your checklist.")
  Text(frame, "GameFontDisableSmall", 22, -506, 900, "Manual checkboxes • Progress resets every week • Use Up / Dn to reorder characters")
  local settings = Button(frame, "Settings", 110, 25, function() self:OpenSettings() end)
  settings:SetPoint("BOTTOMRIGHT", -22, 18)
  frame.resetLabel = Text(frame, "GameFontHighlightSmall", 22, -536, 740, "")
  frame:SetScript("OnShow", function() self:CheckWeeklyReset(); self:RefreshWindow() end)
end

function addon:CreateRow(index)
  local row = CreateFrame("Frame", nil, self.window.content)
  row:SetSize(TABLE_WIDTH, ROW_HEIGHT)
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
    row.name:SetText("(" .. (character.level or 90) .. ") " .. character.name .. (current and " (you)" or ""))
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
  local trackedMoney, _, hasWarbandMoney, characterMoney, warbandMoney = self:GetTrackedMoney()
  local progress = math.min(100, trackedMoney / GOLD_GOAL * 100)
  frame.goldPanel.characters:SetText("Characters: " .. GetCoinTextureString(characterMoney))
  frame.goldPanel.warband:SetText(hasWarbandMoney
    and ("Warband Bank: " .. GetCoinTextureString(warbandMoney))
    or "Warband Bank: waiting for balance")
  frame.goldPanel.total:SetText("Total: " .. GetCoinTextureString(trackedMoney))
  frame.goldBar:SetValue(math.min(trackedMoney, GOLD_GOAL))
  frame.goldBar:SetStatusBarColor(trackedMoney >= GOLD_GOAL and 0.2 or 0.95, trackedMoney >= GOLD_GOAL and 0.8 or 0.68, trackedMoney >= GOLD_GOAL and 0.25 or 0.05)
  for _, milestone in ipairs(frame.goldMilestones) do
    local reached = trackedMoney >= milestone.amount
    milestone.marker:SetColorTexture(
      reached and 0.2 or milestone.red,
      reached and 1 or milestone.green,
      reached and 0.2 or milestone.blue,
      0.95
    )
    milestone.label:SetTextColor(
      reached and 0.3 or milestone.red,
      reached and 1 or milestone.green,
      reached and 0.3 or milestone.blue
    )
  end
  frame.goldBar.text:SetText(string.format("%.1f%%", progress))
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
