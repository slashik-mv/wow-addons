local _, addon = ...
local ROW_HEIGHT, NAME_WIDTH, COLUMN_WIDTH = 38, 350, 146
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

local function CashFlowMoney(amount, signed)
  local prefix = signed and (amount > 0 and "+" or amount < 0 and "-" or "") or ""
  return prefix .. C_CurrencyInfo.GetCoinTextureString(math.abs(amount))
end

function addon:CreateCashFlowWindow()
  local panel = CreateFrame("Frame", nil, self.window, "BackdropTemplate")
  self.cashFlowWindow = panel
  panel:SetSize(315, 570)
  panel:SetPoint("TOPLEFT", self.window, "TOPRIGHT", 4, 0)
  panel:SetFrameLevel(self.window:GetFrameLevel() + 5)
  panel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  panel:SetBackdropColor(0.035, 0.045, 0.075, 0.98)
  panel:SetBackdropBorderColor(0.75, 0.58, 0.24)
  Text(panel, "GameFontNormalLarge", 18, -18, 275, "Cash flow")
  Text(panel, "GameFontDisableSmall", 18, -43, 275, "Characters and Warband Bank combined")
  local reset = Button(panel, "Reset", 70, 22, function()
    self:ResetCashFlow()
    self:RefreshCashFlowWindow()
  end)
  reset:SetPoint("TOPRIGHT", -18, -16)
  reset:SetScript("OnEnter", function(button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("Reset cash-flow statistics")
    GameTooltip:AddLine("Clears earnings, spending, and net income only. Your gold and checklist are not changed.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  reset:SetScript("OnLeave", function() GameTooltip:Hide() end)

  panel.rows = {}
  local periods = {
    { id = "daily", label = "Today" },
    { id = "weekly", label = "This week" },
    { id = "monthly", label = "This month" },
    { id = "total", label = "All time" },
  }
  for index, period in ipairs(periods) do
    local section = CreateFrame("Frame", nil, panel)
    section:SetSize(279, 112)
    section:SetPoint("TOPLEFT", 18, -68 - (index - 1) * 118)
    section.background = section:CreateTexture(nil, "BACKGROUND")
    section.background:SetAllPoints()
    section.background:SetColorTexture(0.11, 0.12, 0.16, index % 2 == 0 and 0.72 or 0.48)
    Text(section, "GameFontNormal", 10, -8, 259, period.label)
    Text(section, "GameFontHighlightSmall", 10, -34, 86, "Earnings")
    Text(section, "GameFontHighlightSmall", 10, -58, 86, "Spending")
    Text(section, "GameFontHighlightSmall", 10, -82, 86, "Net income")
    local earnings = Text(section, "GameFontHighlightSmall", 96, -34, 171, "")
    local spending = Text(section, "GameFontHighlightSmall", 96, -58, 171, "")
    local net = Text(section, "GameFontHighlightSmall", 96, -82, 171, "")
    earnings:SetJustifyH("RIGHT")
    spending:SetJustifyH("RIGHT")
    net:SetJustifyH("RIGHT")
    earnings:SetTextColor(0.35, 1, 0.35)
    spending:SetTextColor(1, 0.35, 0.35)
    panel.rows[period.id] = { earnings = earnings, spending = spending, net = net }
  end
  return panel
end

function addon:SetCashFlowWindowShown(shown)
  if not self.cashFlowWindow then self:CreateCashFlowWindow() end
  self.cashFlowWindow:SetShown(shown)
  if shown then self:RefreshCashFlowWindow() end
  if self.recommendationsWindow and self.recommendationsWindow:IsShown()
    and not self.recommendationsStandalone
  then
    self:AnchorRecommendationsWindow()
  end
end

function addon:RefreshCashFlowWindow()
  local panel = self.cashFlowWindow
  if not panel then return end
  local summary = self:GetCashFlowSummary()
  for _, period in ipairs({ "daily", "weekly", "monthly", "total" }) do
    local values, row = summary[period], panel.rows[period]
    local earnings, spending = values.earnings or 0, values.spending or 0
    local net = earnings - spending
    row.earnings:SetText(CashFlowMoney(earnings))
    row.spending:SetText(CashFlowMoney(spending))
    row.net:SetText(CashFlowMoney(net, true))
    if net > 0 then row.net:SetTextColor(0.35, 1, 0.35)
    elseif net < 0 then row.net:SetTextColor(1, 0.35, 0.35)
    else row.net:SetTextColor(1, 1, 1) end
  end
end

function addon:AnchorRecommendationsWindow()
  local panel = self.recommendationsWindow
  if not panel or not self.window then return end
  panel:ClearAllPoints()
  panel:SetScale(self.window:GetScale())
  local anchor = self.cashFlowWindow and self.cashFlowWindow:IsShown()
    and self.cashFlowWindow or self.window
  panel:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
end

function addon:CreateRecommendationsWindow()
  local panel = CreateFrame("Frame", "Slashik7MilRecommendationsFrame", UIParent, "BackdropTemplate")
  self.recommendationsWindow = panel
  panel:SetSize(430, 570)
  panel:SetFrameStrata("DIALOG")
  panel:SetClampedToScreen(true)
  panel:EnableMouse(true)
  panel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  panel:SetBackdropColor(0.035, 0.045, 0.075, 0.98)
  panel:SetBackdropBorderColor(0.75, 0.58, 0.24)
  Text(panel, "GameFontNormalLarge", 18, -18, 285, "Midnight gold world quests")
  panel.character = Text(panel, "GameFontHighlightSmall", 18, -43, 300, "")
  Text(panel, "GameFontDisableSmall", 18, -62, 390, "Active direct-gold world quests worth at least 800 gold")
  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function()
    if not self.recommendationsStandalone then
      self.db.settings.showRecommendations = false
      if self.window and self.window.recommendationsToggle then
        self.window.recommendationsToggle:SetChecked(false)
      end
    end
    self.recommendationsStandalone = false
    panel:Hide()
  end)
  local refresh = Button(panel, "Refresh", 72, 22, function()
    self.recommendationRewardRetries = 0
    self:RefreshRecommendationsWindow()
  end)
  refresh:SetPoint("TOPRIGHT", -42, -17)

  panel.scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  panel.scroll:SetPoint("TOPLEFT", 18, -84)
  panel.scroll:SetPoint("BOTTOMRIGHT", -32, 35)
  panel.scrollChild = CreateFrame("Frame", nil, panel.scroll)
  panel.scrollChild:SetSize(378, 451)
  panel.scroll:SetScrollChild(panel.scrollChild)

  panel.rows = {}
  for index = 1, 5 do
    local row = CreateFrame("Frame", nil, panel.scrollChild)
    row:SetSize(378, 64)
    row:SetPoint("TOPLEFT", 0, 0)
    row:EnableMouse(true)
    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetColorTexture(0.11, 0.12, 0.16, index % 2 == 0 and 0.72 or 0.48)
    row.title = Text(row, "GameFontNormal", 10, -8, 230, "")
    row.status = Text(row, "GameFontHighlightSmall", 270, -8, 98, "")
    row.status:SetJustifyH("RIGHT")
    row.summary = Text(row, "GameFontHighlightSmall", 10, -29, 358, "")
    row.questLines = {}
    row:SetScript("OnEnter", function(currentRow)
      local zone = currentRow.zoneData
      if not zone then return end
      GameTooltip:SetOwner(currentRow, "ANCHOR_LEFT")
      GameTooltip:SetText(zone.name)
      if #zone.goldQuests == 0 then
        GameTooltip:AddLine("No active direct-gold world quests.", 0.65, 0.65, 0.65, true)
      else
        GameTooltip:AddLine(string.format("%d active gold world quest%s", #zone.goldQuests,
          #zone.goldQuests == 1 and "" or "s"), 0.35, 1, 0.35)
        for _, quest in ipairs(zone.goldQuests) do
          GameTooltip:AddDoubleLine(quest.title,
            C_CurrencyInfo.GetCoinTextureString(quest.money), 1, 1, 1, 1, 0.82, 0)
        end
      end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.rows[index] = row
  end
  panel.loading = Text(panel, "GameFontDisableSmall", 18, -548, 394, "")
  panel.loading:SetJustifyH("CENTER")
  panel:Hide()
  table.insert(UISpecialFrames, "Slashik7MilRecommendationsFrame")
  return panel
end

function addon:RefreshRecommendationsWindow()
  local panel = self.recommendationsWindow
  if not panel then return end
  local name, realm = UnitFullName("player")
  panel.character:SetText((name or "Current character") .. " - " .. (realm or GetRealmName()))
  local ok, zones, loadingRewards = pcall(self.ScanGoldWorldQuestZones, self)
  if not ok then
    local errorText = tostring(zones)
    zones = {}
    for _, zoneKey in ipairs({ "eversong", "zulaman", "harandar", "voidstorm", "coiled" }) do
      local zone = self.midnightZones[zoneKey]
      table.insert(zones, {
        key = zoneKey,
        name = zone.name,
        goldQuests = {},
        goldQuestCount = 0,
        totalGold = 0,
        scanError = errorText,
      })
    end
    loadingRewards = false
  end
  local firstScanError
  local contentHeight = 0
  for index, row in ipairs(panel.rows) do
    local zone = zones[index]
    row.zoneData = zone
    if zone then
      row.title:SetText(zone.name)
      row.status:SetText(string.format("%d gold WQ%s", zone.goldQuestCount,
        zone.goldQuestCount == 1 and "" or "s"))
      if zone.scanError then
        firstScanError = firstScanError or zone.scanError
        row.status:SetText("Scan error")
        row.status:SetTextColor(1, 0.35, 0.35)
        row.summary:SetText("Blizzard API rejected this zone scan")
      elseif zone.goldQuestCount > 0 then
        row.status:SetTextColor(0.35, 1, 0.35)
        row.summary:SetText("Total: " .. C_CurrencyInfo.GetCoinTextureString(zone.totalGold))
      else
        row.status:SetTextColor(0.55, 0.55, 0.55)
        row.summary:SetText("No active gold world quests worth 800 gold or more")
      end
      for questIndex, quest in ipairs(zone.goldQuests) do
        local line = row.questLines[questIndex]
        if not line then
          line = {
            title = Text(row, "GameFontHighlightSmall", 10, -48 - (questIndex - 1) * 17, 255, ""),
            money = Text(row, "GameFontHighlightSmall", 268, -48 - (questIndex - 1) * 17, 100, ""),
          }
          line.title:SetWordWrap(false)
          line.money:SetJustifyH("RIGHT")
          row.questLines[questIndex] = line
        end
        line.title:SetText(quest.title)
        line.money:SetText(C_CurrencyInfo.GetCoinTextureString(quest.money))
        line.title:Show()
        line.money:Show()
      end
      for questIndex = #zone.goldQuests + 1, #row.questLines do
        row.questLines[questIndex].title:Hide()
        row.questLines[questIndex].money:Hide()
      end
      local rowHeight = zone.goldQuestCount > 0 and (55 + zone.goldQuestCount * 17) or 64
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, -contentHeight)
      row:SetHeight(rowHeight)
      contentHeight = contentHeight + rowHeight + 4
      row:Show()
    else
      row:Hide()
    end
  end
  panel.scrollChild:SetHeight(math.max(contentHeight, 451))

  local retries = self.recommendationRewardRetries or 0
  if firstScanError then
    panel.loading:SetText("Gold quest scan failed. Type /7plus debug to print details.")
    self.lastGoldQuestScanError = firstScanError
  elseif loadingRewards and retries < 5 then
    self.lastGoldQuestScanError = nil
    panel.loading:SetText("Loading world-quest reward data...")
    self.recommendationRewardRetries = (self.recommendationRewardRetries or 0) + 1
    C_Timer.After(0.75, function()
      if panel:IsShown() then self:RefreshRecommendationsWindow() end
    end)
  elseif loadingRewards then
    self.lastGoldQuestScanError = nil
    panel.loading:SetText("Some reward data is unavailable. Press Refresh to retry.")
  else
    self.lastGoldQuestScanError = nil
    panel.loading:SetText("")
  end
end

function addon:SetRecommendationsWindowShown(shown, standalone)
  local panel = self.recommendationsWindow
  if not shown then
    self.recommendationsStandalone = false
    if panel then panel:Hide() end
    return
  end

  panel = panel or self:CreateRecommendationsWindow()

  self.recommendationsStandalone = standalone == true
  panel:ClearAllPoints()
  if self.recommendationsStandalone then
    panel:SetScale(1)
    panel:SetPoint("CENTER")
  else
    self:AnchorRecommendationsWindow()
  end
  self.recommendationRewardRetries = 0
  panel:Show()
  self:RefreshRecommendationsWindow()
end

function addon:ToggleRecommendationsStandalone()
  local panel = self.recommendationsWindow
  if panel and panel:IsShown() and self.recommendationsStandalone then
    self:SetRecommendationsWindowShown(false)
  else
    self:SetRecommendationsWindowShown(true, true)
  end
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
  frame:SetScript("OnHide", function()
    SavePosition()
    if self.recommendationsWindow and not self.recommendationsStandalone then
      self.recommendationsWindow:Hide()
    end
  end)
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
  Text(frame, "GameFontNormal", 22, -114, NAME_WIDTH, "Character / realm / gold")
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
  Text(frame, "GameFontDisableSmall", 22, -506, 900, "Automatic quest checks • Click to adjust manually • Progress resets every week • Use Up / Dn to reorder")
  local settings = Button(frame, "Settings", 110, 25, function() self:OpenSettings() end)
  settings:SetPoint("BOTTOMRIGHT", -22, 18)
  local cashFlowToggle = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  cashFlowToggle:SetSize(24, 24)
  cashFlowToggle:SetPoint("RIGHT", settings, "LEFT", -78, 0)
  cashFlowToggle:SetChecked(self.db.settings.showCashFlow)
  local cashFlowLabel = cashFlowToggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cashFlowLabel:SetPoint("LEFT", cashFlowToggle, "RIGHT", 2, 0)
  cashFlowLabel:SetText("Cash flow")
  cashFlowToggle:SetScript("OnClick", function(button)
    local shown = button:GetChecked() == true
    self.db.settings.showCashFlow = shown
    self:SetCashFlowWindowShown(shown)
  end)
  frame.cashFlowToggle = cashFlowToggle
  local recommendationsToggle = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  recommendationsToggle:SetSize(24, 24)
  recommendationsToggle:SetPoint("RIGHT", cashFlowToggle, "LEFT", -108, 0)
  recommendationsToggle:SetChecked(self.db.settings.showRecommendations)
  local recommendationsLabel = recommendationsToggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  recommendationsLabel:SetPoint("LEFT", recommendationsToggle, "RIGHT", 2, 0)
  recommendationsLabel:SetText("Gold quests")
  recommendationsToggle:SetScript("OnClick", function(button)
    local shown = button:GetChecked() == true
    self.db.settings.showRecommendations = shown
    self:SetRecommendationsWindowShown(shown, false)
  end)
  frame.recommendationsToggle = recommendationsToggle
  frame.resetLabel = Text(frame, "GameFontHighlightSmall", 22, -536, 740, "")
  frame:SetScript("OnShow", function()
    self:CheckWeeklyReset()
    self:ReconcileActiveTrackedQuests()
    self:RefreshWindow()
    self:SetCashFlowWindowShown(self.db.settings.showCashFlow)
    if not self.recommendationsStandalone then
      self:SetRecommendationsWindowShown(self.db.settings.showRecommendations, false)
    end
  end)
end

function addon:CreateRow(index)
  local row = CreateFrame("Frame", nil, self.window.content)
  row:SetSize(TABLE_WIDTH, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
  row.background = row:CreateTexture(nil, "BACKGROUND")
  row.background:SetAllPoints()
  row.name = Text(row, "GameFontHighlight", 4, -4, 150, "")
  row.realm = Text(row, "GameFontDisableSmall", 4, -22, 150, "")
  row.money = Text(row, "GameFontHighlightSmall", 154, -7, 120, "")
  row.money:SetJustifyH("RIGHT")
  row.up = Button(row, "Up", 30, 24, function() self:MoveCharacter(row.guid, -1); self:RefreshWindow() end)
  row.up:SetPoint("TOPLEFT", 286, -7)
  row.down = Button(row, "Dn", 30, 24, function() self:MoveCharacter(row.guid, 1); self:RefreshWindow() end)
  row.down:SetPoint("TOPLEFT", 318, -7)
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
    row.money:SetText(type(character.money) == "number"
      and C_CurrencyInfo.GetCoinTextureString(character.money)
      or "Gold not recorded")
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
  frame.goldPanel.characters:SetText("Characters: " .. C_CurrencyInfo.GetCoinTextureString(characterMoney))
  frame.goldPanel.warband:SetText(hasWarbandMoney
    and ("Warband Bank: " .. C_CurrencyInfo.GetCoinTextureString(warbandMoney))
    or "Warband Bank: waiting for balance")
  frame.goldPanel.total:SetText("Total: " .. C_CurrencyInfo.GetCoinTextureString(trackedMoney))
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
  self:RefreshCashFlowWindow()
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
