print("Hello CheckTalentsBeforeMplusOrRaid!")

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("TRAIT_CONFIG_UPDATED")

f:SetScript("OnEvent", function()       -- has to be called during some event because when game is still not fully loaded the PlayerUtil.GetCurrentSpecID() returns always 0
    local specID = PlayerUtil.GetCurrentSpecID()
    if specID == 0 then return end

    print("Current specID:", specID)

    local configIDs1 = C_ClassTalents.GetConfigIDsBySpecID(specID)

    print("#configIDs1: " .. #configIDs1)

    for _, configID in ipairs(configIDs1) do
        local info = C_Traits.GetConfigInfo(configID)
        if info then
            print(("Talent build: %s (configID=%d)"):format(info.name, configID))
        end
    end
end)

local function GetCurrentSpecIDSafe()       -- does not work at the end
    local specID = PlayerUtil.GetCurrentSpecID()
    if specID ~= 0 then
        return specID
    end

    local specIndex = GetSpecialization()
    if specIndex then
        return GetSpecializationInfo(specIndex)
    end
end

local currentSpecID = GetCurrentSpecIDSafe()
print("Current currentSpecID:", currentSpecID)


