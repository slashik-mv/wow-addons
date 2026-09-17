local _, ns = ...
local colors = {
    cyan = {0, 0.9, 1}, yellow = {1, 0.85, 0.1},
    white = {1, 1, 1}, purple = {0.75, 0.35, 1},
}
local texture = "Interface\\AddOns\\SlashikFlying\\mapHighlightRing"
local map, driver, marker, pulse, settings
local elapsed, openedAt = 0, 0
local sourcePin, lastMapID

local function populate(frame, size)
    local c = colors[settings.color]
    frame:ClearUnits()
    -- Native positioning keeps the ring aligned even when Lua map coordinates
    -- are unavailable. The transparent center preserves the directional arrow.
    frame:AddUnit("player", texture, size, size, c[1], c[2], c[3], 1, 7, false)
    frame:FinalizeUnits()
end
local function update()
    local pin
    for candidate in map:EnumeratePinsByTemplate("GroupMembersPinTemplate") do
        if candidate:IsShown() then pin = candidate; break end
    end
    if not pin then marker:Hide(); pulse:Hide(); sourcePin = nil; return end
    local mapID = pin:GetUiMapID()
    -- Wait for Blizzard's pin to finish changing maps; retry on the next tick.
    if not mapID or mapID ~= map:GetMapID() then marker:Hide(); pulse:Hide(); return end
    if sourcePin ~= pin then
        sourcePin, lastMapID = pin, nil
        for _, frame in ipairs({marker, pulse}) do
            frame:ClearAllPoints()
            frame:SetAllPoints(pin)
            frame:SetFrameLevel(pin:GetFrameLevel() + 1)
        end
    end
    if lastMapID ~= mapID then
        marker:SetUiMapID(mapID)
        pulse:SetUiMapID(mapID)
        lastMapID = mapID
    end
    -- The ring asset's 100px diameter sits inside a 128px transparent square.
    local size = settings.size * 1.28 * map:GetEffectiveScale() / marker:GetEffectiveScale()
    -- Show first: native frame visibility/map transitions can invalidate the
    -- unit list. Re-submit the player even if the map ID and size are unchanged,
    -- so an entry lost while loading or flying across zones can recover.
    marker:Show()
    marker:SetAlpha(1)
    populate(marker, size)
    local age = GetTime() - openedAt
    if settings.pulse and age < 2.4 then
        local phase = (age % 0.8) / 0.8
        pulse:Show()
        populate(pulse, size * (1 + phase * 0.75))
        pulse:SetAlpha(1 - phase)
    else pulse:Hide() end
end
local function sync(restart)
    if not map then return end
    settings = ns.GetMapHighlightSettings()
    sourcePin, lastMapID = nil, nil
    if settings.enabled and map:IsShown() then
        if restart then openedAt = GetTime() end
        driver:Show()
        update()
    else
        driver:Hide(); marker:Hide(); pulse:Hide()
    end
end
function ns.RefreshMapHighlight() sync(true) end
local function attach()
    if map or not WorldMapFrame or not WorldMapFrame.EnumeratePinsByTemplate then return end
    map = WorldMapFrame
    driver = CreateFrame("Frame", nil, map)
    driver:Hide()
    marker = CreateFrame("UnitPositionFrame", "SlashikFlyingMapHighlight", map:GetCanvas())
    pulse = CreateFrame("UnitPositionFrame", nil, map:GetCanvas())
    for _, frame in ipairs({marker, pulse}) do frame:EnableMouse(false); frame:Hide() end
    driver:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.05 then elapsed = 0; update() end
    end)
    map:HookScript("OnShow", function() elapsed = 0; sync(true) end)
    map:HookScript("OnHide", function() driver:Hide(); marker:Hide(); pulse:Hide() end)
    sync(true)
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self)
    attach()
    if map then self:UnregisterAllEvents() end
end)
