local f = CreateFrame("Frame")
f:RegisterEvent("READY_CHECK")

local function ShowBigTextInCenter(msg, duration)
    -- creating frame for text
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(800, 200)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:Hide()

    -- setting text object
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    text:SetPoint("CENTER")
    text:SetText(msg)

    -- custom size of text
    local font, _, flags = text:GetFont()
    text:SetFont(font, 60, flags)

    frame.text = text
    frame:Show()

    C_Timer.After(duration or 10, function()
        frame:Hide()
    end)
end

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

local function printWarning(activeBuildName)
    local msg = "WRONG TALENT BUILD: " .. activeBuildName
    print(msg)
    ShowBigTextInCenter(msg, 7)
end

f:SetScript("OnEvent", function(_, event)
    
     if event == "READY_CHECK" then
        if IsInMythicPlus() then

            -- list of the correct substrings
            local allowedBuildNames = {
                "m+",
                "m +",
                "mplus",
                "m plus",
                "mythic+",
                "mythic +",
                "mythicplus",
                "mythic plus"
            }

            local activeBuildName = getActiveLayoutBuildName()
        
            if not checkLayoutName(allowedBuildNames, activeBuildName) then
                printWarning(activeBuildName)
            end

        elseif IsInRaid() then

            -- list of the correct substrings
            local allowedBuildNames = {
                "raid"
            }

            local activeBuildName = getActiveLayoutBuildName()
        
            if not checkLayoutName(allowedBuildNames, activeBuildName) then
                printWarning(activeBuildName)
            end
        end
     end
end)