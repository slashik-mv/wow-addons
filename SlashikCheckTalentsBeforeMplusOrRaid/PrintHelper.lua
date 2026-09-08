local _, addon = ...

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

local function printWarning(activeBuildName)
    local msg = "WRONG TALENT BUILD: " .. activeBuildName
    print(msg)
    ShowBigTextInCenter(msg, 7)
end

addon.printWarning = printWarning
