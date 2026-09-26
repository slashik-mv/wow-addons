local _, addon = ...
local ShowBigTextInCenter = addon.ShowBigTextInCenter

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

local function PrintHelp()
    print("Usage:")
    local layouts = EditModeManagerFrame:GetLayouts()
    for layoutID, layoutInfo in pairs(layouts) do
        print("/l " .. layoutInfo.layoutName:lower() .. "  - activate " .. layoutInfo.layoutName .. " layout")
    end
    print("or")
    for layoutID, layoutInfo in pairs(layouts) do
        print("/layout " .. layoutInfo.layoutName:lower() .. "  - activate " .. layoutInfo.layoutName .. " layout")
    end
    print("/l <seconds> - say a random message and start a pull countdown")
    print("/l msg       - say a random message without starting a pull countdown")
    print("/l msg on    - enable automatic Mythic dungeon pull messages")
    print("/l msg off   - disable automatic pull messages (default)")
    print("Automatic pull messages: " .. (addon.GetSettings().autoPullMessages and "ON" or "OFF"))
end

addon.ActivateLayoutByName = ActivateLayoutByName
addon.PrintHelp = PrintHelp
