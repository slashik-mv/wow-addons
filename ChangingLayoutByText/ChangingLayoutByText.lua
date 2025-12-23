-- Register slash command: /l, /layout
SLASH_MYLAYOUT1 = "/l"
SLASH_MYLAYOUT2 = "/layout"

local function ActivateLayoutByName(layoutName)
    layoutName = layoutName:lower()

    for layoutID, layoutInfo in pairs(EditModeManagerFrame:GetLayouts()) do
        if layoutInfo.layoutName:lower() == layoutName then
            C_EditMode.SetActiveLayout(layoutID)
            print("Activated layout:", layoutInfo.layoutName)
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