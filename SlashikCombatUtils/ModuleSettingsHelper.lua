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
