local _, ns = ...
local hud
local function message(text) print("|cff55ddffSlashikFlying:|r " .. text) end
local function help()
    message("/sf unlock - drag a preview; /sf lock - save and return to automatic display.")
    message("/sf test - toggle preview; /sf width <120-600> (current theme); /sf scale <0.5-3>.")
    message("/sf enabled <on|off>; /sf combat <on|off> - hide in combat.")
    message("/sf theme <" .. ns.ThemeList() .. "> - switch appearance; /sf theme - show selection.")
    message("/sf settings - show settings; /sf settings default - reset everything.")
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        ns.GetSettings()
        hud = ns.CreateFlyingFrame()
        for _, name in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_CAN_GLIDE_CHANGED", "PLAYER_IS_GLIDING_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "SPELLS_CHANGED"}) do
            events:RegisterEvent(name)
        end
    end
    if hud then hud:UpdateVisibility() end
end)
SLASH_SLASHIKFLYING1 = "/sf"
SLASH_SLASHIKFLYING2 = "/slashikflying"
SlashCmdList.SLASHIKFLYING = function(input)
    if not hud then return end
    local command, value = input:lower():match("^%s*(%S*)%s*(.-)%s*$")
    local s = ns.GetSettings()
    if command == "unlock" then
        hud.unlocked = true
        s.enabled = true
        message("Drag the display, then use /sf lock.")
    elseif command == "lock" then
        hud.unlocked, hud.preview = false, false
    elseif command == "test" then
        hud.preview = not hud.preview
        hud.unlocked = false
        if hud.preview then s.enabled = true end
        message(hud.preview and "Preview on. /sf test to exit." or "Preview off.")
    elseif command == "theme" then
        if value == "" then
            message("Theme: " .. s.themeId .. ". Available: " .. ns.ThemeList()); return
        end
        if not ns.Themes[value] then message("Unknown theme. Available: " .. ns.ThemeList()); return end
        s.themeId = value
        message("Theme: " .. ns.Themes[value].name)
    elseif command == "width" or command == "scale" then
        local number = tonumber(value)
        local low, high = command == "width" and 120 or 0.5, command == "width" and 600 or 3
        if not number or number ~= number or number < low or number > high then
            message("Use /sf " .. command .. " <" .. low .. "-" .. high .. ">."); return
        end
        if command == "width" then ns.GetTheme().width = number else s.scale = number end
    elseif command == "enabled" or command == "combat" then
        if value ~= "on" and value ~= "off" then message("Use on or off."); return end
        s[command == "enabled" and "enabled" or "hideInCombat"] = value == "on"
    elseif command == "settings" then
        if value == "default" then
            s = ns.ResetSettings()
            hud.preview, hud.unlocked = false, false
            message("Settings and position reset.")
        else
            message(string.format("Theme: %s; enabled: %s; width: %g; scale: %g; hide in combat: %s.", s.themeId, tostring(s.enabled), ns.GetTheme().width, s.scale, tostring(s.hideInCombat)))
        end
    else help(); return end
    hud:ApplySettings()
    hud:UpdateVisibility()
end
