-- Register slash command: /l, /layout
SLASH_MYLAYOUT1 = "/l"
SLASH_MYLAYOUT2 = "/layout"

-- Simple BIG text in middle of the screen
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
    text:SetFont(font, 40, flags)

    frame.text = text
    frame:Show()

    C_Timer.After(duration or 10, function()
        frame:Hide()
    end)
end

-- Activate Layout by Name
local function ActivateLayoutByName(layoutName)
    layoutName = layoutName:lower()

    for layoutID, layoutInfo in pairs(EditModeManagerFrame:GetLayouts()) do
        if layoutInfo.layoutName:lower() == layoutName then
            C_EditMode.SetActiveLayout(layoutID)
            local msg = "Activated layout: " .. layoutInfo.layoutName
            print(msg)
            ShowBigTextInCenter(msg, 1)
            return
        end
    end

    print("Layout not found:", layoutName)
end

-- Slash command handler
SlashCmdList["MYLAYOUT"] = function(msg)
    msg = msg and msg:lower():trim() or ""

    if msg == "help" then
        print("Usage:")
        local layouts = EditModeManagerFrame:GetLayouts()
        for layoutID, layoutInfo in pairs(layouts) do
            print("/l " .. layoutInfo.layoutName:lower() .. "  - activate " .. layoutInfo.layoutName .. " layout")
        end
        print("or")
        for layoutID, layoutInfo in pairs(layouts) do
            print("/layout " .. layoutInfo.layoutName:lower() .. "  - activate " .. layoutInfo.layoutName .. " layout")
        end
    else
       ActivateLayoutByName(msg)
    end
end