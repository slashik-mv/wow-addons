local _, addon = ...
local module = {
    title = "Check Consumables",
    description = "Bag stock reminders outside combat. Paused during active Mythic+ runs.",
    groups = {
        { title = "Flasks", items = {
            { id = 241321, variants = { 241321, 241320 }, name = "Flask of Thalassian Resistance", effect = "Versatility" },
            { id = 241324, variants = { 241324, 241325 }, name = "Flask of the Blood Knights", effect = "Haste" },
            { id = 241322, variants = { 241322, 241323 }, name = "Flask of the Magisters", effect = "Mastery" },
            { id = 241326, variants = { 241326, 241327 }, name = "Flask of the Shattered Sun", effect = "Critical Strike" },
        } },
        { title = "Health Potions", items = {
            { id = 241304, variants = { 241304, 241305 }, name = "Silvermoon Health Potion", effect = "Health" },
        } },
        { title = "Battle Potions", items = {
            { id = 241308, variants = { 241308, 241309 }, name = "Light's Potential", effect = "Primary stat" },
            { id = 241288, variants = { 241288, 241289 }, name = "Potion of Recklessness", effect = "Secondary stat" },
        } },
        { title = "Enchanting", items = {
            { id = 243734, variants = { 243734, 243733 }, name = "Thalassian Phoenix Oil", effect = "Critical Strike and Haste" },
            { id = 243738, variants = { 243738, 243737 }, name = "Smuggler's Enchanted Edge", effect = "Extra Arcane damage" },
        } },
        { title = "Food", items = {
            { id = 242275, name = "Royal Roast", effect = "Primary stat" },
            { id = 255847, name = "Impossibly Royal Roast", effect = "Primary stat" },
        } },
    },
}
addon:RegisterModule("consumables", module)

function module:GetSelections()
    return addon:GetSettings().consumables.selected
end

function module:GetMinimum(id)
    local value = addon:GetSettings().consumables.minimums[id]
    if type(value) ~= "number" or value ~= value or value < 1 or value > 9999 or value ~= math.floor(value) then return 1 end
    return value
end

function module:SetMinimum(id, value)
    if not addon:CanEdit() or not addon:IsModuleEnabled("consumables") then return end
    value = tonumber(value)
    if not value or value ~= value or value < 1 or value > 9999 or value ~= math.floor(value) then
        addon:Print("Enter a whole minimum quantity from 1 to 9999.")
        return
    end
    if value == self:GetMinimum(id) then return end
    addon:GetSettings().consumables.minimums[id] = value
    self.lastSignature = nil
    self:Schedule()
end

function module:IsSuppressed()
    if InCombatLockdown() or self.challengeStarted then return true end
    if not C_ChallengeMode or not C_ChallengeMode.IsChallengeModeActive then return true end
    local ok, active = pcall(C_ChallengeMode.IsChallengeModeActive)
    return not ok or (issecretvalue and issecretvalue(active)) or active == true
end

function module:GetMissing()
    local selected, missing, signature = self:GetSelections(), {}, {}
    if not C_Item or not C_Item.GetItemCount then return end
    for _, group in ipairs(self.groups) do
        local choices, stocked, uncertain = {}, false, false
        for _, item in ipairs(group.items) do
            if selected[item.id] == true then
                local minimum, total = self:GetMinimum(item.id), 0
                choices[#choices + 1] = item.name .. " (minimum " .. minimum .. ")"
                -- Bags only: bank, reagent bank, account bank and charges excluded.
                -- Keep the original ID as the saved selection key; accept known quality variants.
                for _, id in ipairs(item.variants or { item.id }) do
                    local ok, count = pcall(C_Item.GetItemCount, id, false, false, false, false)
                    if not ok or (issecretvalue and issecretvalue(count)) or type(count) ~= "number" then
                        uncertain = true
                    else total = total + count end
                end
                if total >= minimum then stocked = true end
            end
        end
        if uncertain and not stocked then return end
        if #choices > 0 and not stocked then
            missing[#missing + 1] = { title = group.title, choices = choices }
            signature[#signature + 1] = group.title .. ":" .. table.concat(choices, ",")
        end
    end
    return missing, table.concat(signature, "|")
end

function module:HideWarning()
    if self.warning then self.warning:Hide() end
end

function module:ShowWarning(missing)
    if not self.warning then
        local frame = CreateFrame("Frame", "SlashikCombatUtilsConsumablesWarning", UIParent, "BasicFrameTemplateWithInset")
        frame:SetSize(420, 150)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame.TitleText:SetText("Missing Consumables")
        table.insert(UISpecialFrames, "SlashikCombatUtilsConsumablesWarning")
        frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.text:SetPoint("TOPLEFT", 18, -40)
        frame.text:SetWidth(384)
        frame.text:SetJustifyH("LEFT")
        local dismiss = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        dismiss:SetSize(140, 26)
        dismiss:SetPoint("BOTTOM", 0, 18)
        dismiss:SetText("Dismiss")
        dismiss:SetScript("OnClick", function() frame:Hide() end)
        self.warning = frame
    end
    local lines = { "Stock up before your next pull or key!", "" }
    for _, group in ipairs(missing) do
        lines[#lines + 1] = "|cffffd100" .. group.title .. " - bring any one:|r"
        for _, name in ipairs(group.choices) do lines[#lines + 1] = "  " .. name end
        lines[#lines + 1] = ""
    end
    -- Remove trailing blank space and measure wrapped text before sizing the window.
    lines[#lines] = nil
    self.warning.text:SetText(table.concat(lines, "\n"))
    self.warning:SetHeight(math.max(150, math.ceil(self.warning.text:GetStringHeight()) + 100))
    self.warning:Show()
end

function module:Check(manual)
    if not self.enabled then return end
    if self:IsSuppressed() then
        self:HideWarning()
        if manual then addon:Print("Consumable checks are paused in combat or during an active Mythic+ run.") end
        return
    end
    local missing, signature = self:GetMissing()
    if not missing then
        self:HideWarning()
        if manual then addon:Print("Bag counts are unavailable. Please try again shortly.") end
        return
    end
    if #missing == 0 then
        self.lastSignature = nil
        self:HideWarning()
        if manual then addon:Print("No missing selected consumables. Categories with no selections are skipped.") end
        return
    end
    if manual or signature ~= self.lastSignature then
        self.lastSignature = signature
        self:ShowWarning(missing)
    elseif self.warning and self.warning:IsShown() then
        self:ShowWarning(missing)
    end
end

function module:Schedule(delay)
    if self.timer then self.timer:Cancel(); self.timer = nil end
    if not self.enabled then return end
    if self:IsSuppressed() then self:HideWarning(); return end
    self.timer = C_Timer.NewTimer(delay or 0.5, function()
        self.timer = nil
        self:Check()
    end)
end

function module:SetSelected(id, selected)
    if not addon:CanEdit() or not addon:IsModuleEnabled("consumables") then return end
    self:GetSelections()[id] = selected == true
    self.lastSignature = nil
    self:Schedule()
end

function module:OnEvent(event)
    if event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
        -- Clear suppression only; finishing a key must not trigger a check.
        self.challengeStarted = nil
        return
    end
    if event == "CHALLENGE_MODE_START" or event == "PLAYER_REGEN_DISABLED" then
        if event == "CHALLENGE_MODE_START" then self.challengeStarted = true end
        if self.timer then self.timer:Cancel(); self.timer = nil end
        self:HideWarning()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        self.challengeStarted, self.lastSignature = nil, nil
        self:Schedule(2)
    elseif event == "BAG_UPDATE_DELAYED" then
        self:Schedule()
    end
end

function module:Enable()
    if self.enabled then return end
    self.enabled = true
    self.lastSignature = nil
    if not self.events then
        self.events = CreateFrame("Frame")
        self.events:SetScript("OnEvent", function(_, event) self:OnEvent(event) end)
    end
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_DISABLED",
        "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET" }) do
        self.events:RegisterEvent(event)
    end
    self:Schedule(2)
end

function module:Disable()
    self.enabled = false
    self.challengeStarted, self.lastSignature = nil, nil
    if self.timer then self.timer:Cancel(); self.timer = nil end
    if self.events then self.events:UnregisterAllEvents() end
    self:HideWarning()
end
