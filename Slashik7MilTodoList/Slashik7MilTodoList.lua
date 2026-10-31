local _, addon = ...
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_MONEY")
events:RegisterEvent("ACCOUNT_MONEY")
events:RegisterEvent("BANKFRAME_OPENED")
events:RegisterEvent("QUEST_TURNED_IN")
events:SetScript("OnEvent", function(_, event, argument, isReloadingUi)
  if event == "ADDON_LOADED" then
    if argument ~= "Slashik7MilTodoList" then return end
    addon:InitializeDatabase()
    addon:RegisterSettingsUI()
  elseif event == "PLAYER_LOGIN" then
    addon:CheckWeeklyReset()
    addon:RegisterCharacter()
    addon:ReconcileActiveTrackedQuests()
    addon:UpdateWarbandMoney()
    addon:InitializeCashFlowBaseline()
    addon.resetTicker = C_Timer.NewTicker(30, function()
      addon:CheckWeeklyReset()
      if addon.window and addon.window:IsShown() then addon:RefreshWindow() end
    end)
  elseif event == "PLAYER_MONEY" and addon.db then
    addon:QueueMoneyUpdate()
  elseif (event == "ACCOUNT_MONEY" or event == "BANKFRAME_OPENED") and addon.db then
    addon:QueueMoneyUpdate()
  elseif event == "QUEST_TURNED_IN" and addon.db then
    if addon:HandleQuestTurnedIn(argument) and addon.window and addon.window:IsShown() then
      addon:RefreshWindow()
    end
    if addon.recommendationsWindow and addon.recommendationsWindow:IsShown() then
      addon:RefreshRecommendationsWindow()
    end
  elseif addon.db then
    addon:CheckWeeklyReset()
    addon:RegisterCharacter(event == "PLAYER_LEVEL_UP" and argument or nil)
    if event == "PLAYER_ENTERING_WORLD" then
      addon:UpdateWarbandMoney()
      addon:ReconcileActiveTrackedQuests()
    end
    if addon.window and addon.window:IsShown() then addon:RefreshWindow() end
    if event == "PLAYER_ENTERING_WORLD" and (argument or isReloadingUi) then
      -- Wait until world-entry UI initialization has finished before opening.
      C_Timer.After(0.5, function()
        if addon.db.settings.showOnLogin then addon:ShowWindow() end
      end)
    end
  end
end)

SLASH_SLASHIK7PLUS1 = "/7plus"
SLASH_SLASHIK7PLUS2 = "/7+"
SlashCmdList.SLASHIK7PLUS = function(message)
  local command = message:match("^%s*(.-)%s*$"):lower()
  if command == "debug" then
    addon:PrintGoldWorldQuestDebug()
  else
    addon:ToggleRecommendationsStandalone()
  end
end

SLASH_SLASHIK7CASH1 = "/7cash"
SlashCmdList.SLASHIK7CASH = function()
  addon:ToggleCashFlowStandalone()
end

SLASH_SLASHIK7QUESTS1 = "/7quests"
SLASH_SLASHIK7QUESTS2 = "/7wq"
SlashCmdList.SLASHIK7QUESTS = function()
  addon:ToggleRecommendationsStandalone()
end

SLASH_SLASHIK7MIL1 = "/7mil"
SLASH_SLASHIK7MIL2 = "/s7mil"
SLASH_SLASHIK7MIL3 = "/slashik7mil"
SLASH_SLASHIK7MIL4 = "/7"
SlashCmdList.SLASHIK7MIL = function(message)
  local command = message:match("^%s*(.-)%s*$"):lower()
  if command == "settings" then
    addon:OpenSettings()
  elseif command == "position" then
    addon.db.position = nil
    if addon.window then
      addon.window:ClearAllPoints()
      addon.window:SetPoint("CENTER")
    end
  elseif command == "" then
    addon:ToggleWindow()
  else
    print("|cffffd166Slashik7MilTodoList:|r /7 - checklist; /7cash - cash flow; /7quests or /7wq - gold world quests; /7mil settings - options; /7mil position - center window.")
  end
end
