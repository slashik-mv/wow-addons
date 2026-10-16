local _, addon = ...
addon.modules, addon.moduleOrder = {}, {}

function addon:RegisterModule(key, module)
    assert(not self.modules[key], "Duplicate combat module: " .. key)
    self.modules[key] = module
    self.moduleOrder[#self.moduleOrder + 1] = key
end

function addon:IsModuleEnabled(key)
    return self.modules[key] ~= nil and self:GetSettings().modules[key] ~= false
end

function addon:SetModuleEnabled(key, enabled)
    if not self.modules[key] or not self:CanEdit() then return false end
    self:GetSettings().modules[key] = enabled == true
    self:RefreshModule(key)
    return true
end

function addon:RefreshModule(key)
    local module = self.modules[key]
    if self:IsModuleEnabled(key) then module:Enable() else module:Disable() end
end

function addon:RefreshModules()
    for _, key in ipairs(self.moduleOrder) do self:RefreshModule(key) end
end

-- Keep display ordering separate from module startup order.
function addon:GetModuleDisplayOrder()
    local saved = self:GetSettings().moduleOrder
    local order, seen = {}, {}
    if type(saved) == "table" then
        for _, key in ipairs(saved) do
            if type(key) == "string" and self.modules[key] and not seen[key] then
                order[#order + 1], seen[key] = key, true
            end
        end
    end
    for _, key in ipairs(self.moduleOrder) do
        if not seen[key] then order[#order + 1] = key end
    end
    return order
end

function addon:MoveModule(key, direction)
    if not self:CanEdit() or (direction ~= -1 and direction ~= 1) then return end
    local order = self:GetModuleDisplayOrder()
    for index, current in ipairs(order) do
        if current == key then
            local destination = index + direction
            if destination < 1 or destination > #order then return end
            order[index], order[destination] = order[destination], order[index]
            self:GetSettings().moduleOrder = order
            self:RefreshSettingsWindow()
            return
        end
    end
end
