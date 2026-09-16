local _, ns = ...
local colors = {
    cyan = {0, 0.9, 1}, yellow = {1, 0.85, 0.1},
    white = {1, 1, 1}, purple = {0.75, 0.35, 1},
}
local map, driver, marker, pulse, settings
local elapsed, openedAt = 0, 0
local segments = 48

-- Hollow rings leave the player's directional arrow and nearby map details visible.
-- Native line primitives avoid additional texture assets and mouse interception.
local function createRing(parent)
    local ring = CreateFrame("Frame", nil, parent)
    ring:SetPoint("CENTER")
    ring:EnableMouse(false)
    ring.lines = {}
    for i = 1, segments do
        local outer = ring:CreateLine(nil, "ARTWORK")
        local inner = ring:CreateLine(nil, "OVERLAY")
        ring.lines[i] = {outer, inner}
    end
    return ring
end
local function styleRing(ring)
    local size = settings.size
    ring:SetSize(size, size)
    local color = colors[settings.color]
    for i, pair in ipairs(ring.lines) do
        local a, b = (i - 1) * 2 * math.pi / segments, i * 2 * math.pi / segments
        for j, line in ipairs(pair) do
            line:SetStartPoint("CENTER", ring, math.cos(a) * size / 2, math.sin(a) * size / 2)
            line:SetEndPoint("CENTER", ring, math.cos(b) * size / 2, math.sin(b) * size / 2)
            line:SetThickness(j == 1 and 5 or 2.5)
            if j == 1 then line:SetColorTexture(0, 0, 0, 0.9)
            else line:SetColorTexture(color[1], color[2], color[3], 1) end
        end
    end
end
local function update()
    local mapID = map:GetMapID()
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local x, y
    if position then x, y = position:GetXY() end
    x, y = ns.Number(x, nil), ns.Number(y, nil)
    -- Never project a position from a different map/floor or keep a stale marker.
    if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then
        marker:Hide(); return
    end
    local canvas = map:GetCanvas()
    local scale = map:GetEffectiveScale() / canvas:GetEffectiveScale()
    marker:SetScale(scale)
    marker:ClearAllPoints()
    marker:SetPoint("CENTER", canvas, "TOPLEFT", canvas:GetWidth() * x / scale, -canvas:GetHeight() * y / scale)
    marker:Show()
    local age = GetTime() - openedAt
    if settings.pulse and age < 2.4 then
        local phase = (age % 0.8) / 0.8
        pulse:SetScale(1 + phase * 0.75)
        pulse:SetAlpha(1 - phase)
        pulse:Show()
    else pulse:Hide() end
end
local function sync(restart)
    if not map then return end
    settings = ns.GetMapHighlightSettings()
    styleRing(marker.ring)
    styleRing(pulse)
    if settings.enabled and map:IsShown() then
        if restart then openedAt = GetTime() end
        driver:Show()
        update()
    else
        driver:Hide()
        marker:Hide()
    end
end
function ns.RefreshMapHighlight() sync(true) end
local function attach()
    if map or not WorldMapFrame or not WorldMapFrame.GetCanvas then return end
    map = WorldMapFrame
    driver = CreateFrame("Frame", nil, map)
    driver:Hide()
    marker = CreateFrame("Frame", "SlashikFlyingMapHighlight", map:GetCanvas())
    marker:SetSize(1, 1)
    marker:SetFrameLevel(marker:GetParent():GetFrameLevel() + 100)
    marker:EnableMouse(false)
    marker:Hide()
    marker.ring = createRing(marker)
    pulse = createRing(marker)
    driver:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.05 then elapsed = 0; update() end
    end)
    map:HookScript("OnShow", function() elapsed = 0; sync(true) end)
    map:HookScript("OnHide", function() driver:Hide(); marker:Hide() end)
    sync(true)
end
-- Works whether Blizzard_WorldMap is already present or loaded later.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self)
    attach()
    if map then self:UnregisterAllEvents() end
end)
