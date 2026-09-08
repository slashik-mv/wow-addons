local _, addon = ...

local function IsInMythicPlus()
    local inInstance, instanceType = IsInInstance()
    if not inInstance or instanceType ~= "party" then return false end

    local _, _, difficultyID = GetInstanceInfo()
    return difficultyID == 8 or difficultyID == 23          -- 8 = Mythic+, 23 = Mythic
end

local function IsInRaid()
    local inInstance, instanceType = IsInInstance()
    if not inInstance or instanceType ~= "raid" then return false end
    return true
end

local function IsInDelve()
    local inInstance, instanceType = IsInInstance()
    if instanceType ~= "scenario" then return false end
    return true
end

local function checkLayoutName(allowedBuildNames, activeBuildName)
    for _, v in ipairs(allowedBuildNames) do
        if string.find(activeBuildName:lower(), v:lower(), 1, true) then
            return true
        end
    end
    return false
end

local function getActiveLayoutBuildName()
    -- getting spec id (specilization)
    local specID = PlayerUtil.GetCurrentSpecID()
    if specID == 0 then return end

    -- getting active layout talent build name
    local activeConfigID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    local activeLayoutBuildName = C_Traits.GetConfigInfo(activeConfigID)

    return activeLayoutBuildName.name

    -- -- all build layout names
    -- for _, configID in ipairs(C_ClassTalents.GetConfigIDsBySpecID(specID)) do
    --     local info = C_Traits.GetConfigInfo(configID)
    --     if info then
    --         print(("Talent build: %s (configID=%d)"):format(info.name, configID))
    --     end
    -- end
    -- -- all build layout names
end 

addon.IsInMythicPlus = IsInMythicPlus
addon.IsInRaid = IsInRaid
addon.IsInDelve = IsInDelve

local function checkMythicPlus()
    local allowedBuildNames = { "m+", "m +", "mplus", "m plus", "mythic+", "mythic +", "mythicplus", "mythic plus" }
    local activeBuildName = getActiveLayoutBuildName()

    if not checkLayoutName(allowedBuildNames, activeBuildName) then
        addon.printWarning(activeBuildName)
    end
end

addon.checkMythicPlus = checkMythicPlus

local function checkRaid()
    local allowedBuildNames = { "raid" }
    local activeBuildName = getActiveLayoutBuildName()

    if not checkLayoutName(allowedBuildNames, activeBuildName) then
        addon.printWarning(activeBuildName)
    end
end

addon.checkRaid = checkRaid

local function checkDelve()
    local allowedBuildNames = { "delve" }
    local activeBuildName = getActiveLayoutBuildName()

    if not checkLayoutName(allowedBuildNames, activeBuildName) then
        addon.printWarning(activeBuildName)
    end
end

addon.checkDelve = checkDelve
