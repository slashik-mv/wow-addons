local _, addon = ...
local module = {
    title = "Auto Health Pot", description = "One macro for Healthstone and your preferred healing potion.",
    macroName = "SCU Health Pot",
    items = {
        {id=224464, name="Demonic Healthstone", variants={224464}, stone=true},
        {id=5512, name="Healthstone", variants={5512}, stone=true},
        {id=271884, name="Concentrated Silvermoon Health Potion", variants={271884,271883}},
        {id=241305, name="Silvermoon Health Potion", variants={241304,241305}},
        {id=258138, name="Potent Healing Potion", variants={258138}},
    },
}
addon:RegisterModule("autoHealthPot", module)
function module:Settings() return addon:GetSettings().autoHealthPot end
function module:Order()
    local order, seen, lookup = {}, {}, {}
    for _, item in ipairs(self.items) do lookup[item.id] = item end
    for _, id in ipairs(self:Settings().order) do
        if type(id) == "number" and lookup[id] and not seen[id] then order[#order+1]=lookup[id]; seen[id]=true end
    end
    -- Introduce the new item first even for players with an existing saved order.
    -- Once reordered, its explicit saved position takes precedence.
    if not seen[224464] then table.insert(order, 1, lookup[224464]); seen[224464]=true end
    for _, item in ipairs(self.items) do if not seen[item.id] then order[#order+1]=item end end
    return order
end
function module:Move(id, direction)
    if not addon:CanEdit() or not self.enabled then return end
    local order = self:Order()
    for i, item in ipairs(order) do
        if item.id == id and (direction == -1 or direction == 1) and order[i+direction] then
            order[i], order[i+direction] = order[i+direction], order[i]
            local saved = {}; for _, value in ipairs(order) do saved[#saved+1] = value.id end
            self:Settings().order = saved
            self:Request(); self:RefreshUI(); return
        end
    end
end
function module:Build()
    local sequence, potion = {}, false
    for _, item in ipairs(self:Order()) do
        if self:Settings().selected[item.id] ~= false and (item.stone or not potion) then
            for _, id in ipairs(item.variants) do
                local ok, count = pcall(C_Item.GetItemCount, id, false, true, false, false)
                if not ok or (issecretvalue and issecretvalue(count)) or type(count) ~= "number" then return nil end
                if count > 0 then
                    sequence[#sequence+1] = "item:" .. id
                    if not item.stone then potion = true end
                    break
                end
            end
        end
    end
    if #sequence == 0 then return "#showtooltip", false end
    return "#showtooltip\n/stopcasting\n/castsequence [@player] reset=combat " .. table.concat(sequence, ", "), true
end
-- Compare commands, allowing harmless newline normalization after a reload.
local function normalizedBody(body)
    if type(body) ~= "string" then return nil end
    return (body:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("%s+$", ""))
end
function module:RefreshUI() if self.refreshUI then self.refreshUI() end end
function module:Update()
    if not self.enabled then return end
    if InCombatLockdown() then self.pending=true; self.message="Update queued until combat ends."; self:RefreshUI(); return end
    self.pending=false
    local body, available = self:Build()
    if not body then self.message="Bag counts unavailable; macro unchanged."; self:RefreshUI(); return end
    self.body=body
    local character = UnitGUID("player")
    if not character then self.message="Waiting for character data."; self:RefreshUI(); return end
    local saved = self:Settings().ownedBodies
    local index = GetMacroIndexByName(self.macroName)
    if index and index > 0 then
        local _, _, existing = GetMacroInfo(index)
        local limit = Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_ACCOUNT_MACROS or MAX_ACCOUNT_MACROS or 120
        if index <= limit or not saved[character] or normalizedBody(existing) ~= normalizedBody(saved[character]) then
            if index <= limit then
                self.message="An account macro has this name. Rename it, then Update macro."
            elseif not saved[character] then
                self.message="This character has no ownership record for this macro. Rename it, then Update macro."
            else
                self.message="Macro commands were manually edited. Rename it, then Update macro."
            end
            self:RefreshUI(); return
        end
        if normalizedBody(existing) ~= normalizedBody(body) then EditMacro(index, self.macroName, nil, body) end
    else
        local _, count = GetNumMacros()
        local limit = Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_CHARACTER_MACROS or MAX_CHARACTER_MACROS or 18
        if count >= limit then self.message="Character macro slots are full. Free one, then Update macro."; self:RefreshUI(); return end
        index=CreateMacro(self.macroName, "INV_Misc_QuestionMark", body, true)
    end
    if index and index > 0 and normalizedBody(select(3, GetMacroInfo(index))) == normalizedBody(body) then
        saved[character]=body
        self.message=available and "Macro ready. Drag SCU Health Pot from /macro to your action bar." or "No selected healing items in bags. Macro has no actions."
    else self.message="Macro could not be updated. Try Update macro again." end
    self:RefreshUI()
end
function module:Request()
    if not self.enabled then return end
    if self.timer then self.timer:Cancel(); self.timer=nil end
    if InCombatLockdown() then self:Update(); return end
    self.timer=C_Timer.NewTimer(0.3, function() self.timer=nil; self:Update() end)
end
function module:Enable()
    self.enabled=true
    if not self.events then self.events=CreateFrame("Frame") end
    for _, event in ipairs({"PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED"}) do self.events:RegisterEvent(event) end
    self.events:SetScript("OnEvent", function() self:Request() end)
    self:Request()
end
function module:Disable()
    self.enabled=false; self.pending=false
    if self.timer then self.timer:Cancel(); self.timer=nil end
    if self.events then self.events:UnregisterAllEvents() end
    self.message="Disabled. Existing macro is kept but will not update."
    self:RefreshUI()
end
