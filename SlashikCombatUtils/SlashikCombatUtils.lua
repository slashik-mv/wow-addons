local addonName, addon = ...
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    addon:GetSettings()
    addon:RegisterSettingsCategory()
    addon:RefreshModules()
end)

SLASH_SLASHIKCOMBATUTILS1 = "/scu"
SLASH_SLASHIKCOMBATUTILS2 = "/slashikcombatutils"
SlashCmdList.SLASHIKCOMBATUTILS = function(message)
    if message and message:lower():match("^%s*debug%s*$") then
        local module = addon.modules.boneShield
        addon:Print("Bone Shield source: " .. (module.countSource or "not queried"))
        addon:Print("Bone Shield timer: " .. (module.timerSource or "not queried"))
        addon:Print("Death and Decay timer: " .. (module.deathAndDecaySource or "not queried"))
        return
    end
    addon:ShowSettings()
end
