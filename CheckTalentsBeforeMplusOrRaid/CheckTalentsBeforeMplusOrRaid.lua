print("Hello CheckTalentsBeforeMplusOrRaid!")

local f = CreateFrame("Frame")
f:RegisterEvent("READY_CHECK")

local function ShowBigTextInCenter(msg, duration)
    -- creating frame for text
    local frame = CreateFrame("FrameBigText", nil, UIParent)
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

    -- TEST
    return true
    -- local _, _, difficultyID = GetInstanceInfo()
    -- return difficultyID == 8 or difficultyID == 23          -- 8 = Mythic+, 23 = Mythic
end

local function IsInRaid()
    local inInstance, instanceType = IsInInstance()
    if not inInstance or instanceType ~= "raid" then return false end
    return true
end


f:SetScript("OnEvent", function(_, event)       -- has to be called during some event because when game is still not fully loaded the PlayerUtil.GetCurrentSpecID() returns always 0
    
     if event == "READY_CHECK" and IsInMythicPlus() then
        print("Ready check")
        print("M+!!!!!")

        -- this should be loaded from addon settings
        local expectedLayoutBuildName = "m+"

        -- getting spec id (specilization)
        local specID = PlayerUtil.GetCurrentSpecID()
        if specID == 0 then return end

        -- getting active layout talent build name
        local activeConfigID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
        local activeLayoutBuildName = C_Traits.GetConfigInfo(activeConfigID)
        print("Active talent build:", activeLayoutBuildName.name)

        if expectedLayoutBuildName:lower() ~= activeLayoutBuildName.name:lower() then
            local msg = "WRONG TALENT BUILD: " .. activeLayoutBuildName.name
            print(msg)
            ShowBigTextInCenter(msg, 5)
        end


        -- -- all build layout names
        -- for _, configID in ipairs(C_ClassTalents.GetConfigIDsBySpecID(specID)) do
        --     local info = C_Traits.GetConfigInfo(configID)
        --     if info then
        --         print(("Talent build: %s (configID=%d)"):format(info.name, configID))
        --     end
        -- end
        -- -- all build layout names
        
    elseif event == "READY_CHECK" and IsInRaid() then
        print("raid - in progress")
        -- in progress 
     end

end)