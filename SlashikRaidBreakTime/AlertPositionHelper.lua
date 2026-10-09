-- One position per alert group; previews never call gameplay or spell handlers.
local definitions = {
    { key = "keystones", name = "Keystone alerts", title = "Next key: Example Dungeon +10", subtitle = "Key owner: Example", x = 0, y = 0 },
    { key = "recovery", name = "Recovery warnings", title = "DON'T RELEASE!", subtitle = "Example has a Soulstone.\nAlso used for ready-check and priest recovery warnings.", x = 0, y = 0 },
    { key = "massRes", name = "Mass Resurrect", x = 0, y = -115 },
}
local targets, previews = {}, {}
local editor, selected, dragging

local function positions()
    SlashikRaidBreakTimeDB = SlashikRaidBreakTimeDB or {}
    if type(SlashikRaidBreakTimeDB.alertPositions) ~= "table" then SlashikRaidBreakTimeDB.alertPositions = {} end
    return SlashikRaidBreakTimeDB.alertPositions
end

local function definition(key)
    for _, entry in ipairs(definitions) do if entry.key == key then return entry end end
end

local function apply(frame, key)
    local defaults = definition(key)
    local saved = positions()[key]
    local x, y = defaults.x, defaults.y
    if type(saved) == "table" and type(saved.x) == "number" and type(saved.y) == "number"
        and saved.x == saved.x and saved.y == saved.y and math.abs(saved.x) < 100000 and math.abs(saved.y) < 100000 then
        x, y = saved.x, saved.y
    end
    -- Clamp restored positions if resolution/UI scale changed since saving.
    x = math.max(-UIParent:GetWidth() / 2 + 50, math.min(UIParent:GetWidth() / 2 - 50, x))
    y = math.max(-UIParent:GetHeight() / 2 + 40, math.min(UIParent:GetHeight() / 2 - 40, y))
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

function registerRaidBreakAlertPosition(frame, key, onMoved)
    assert(definition(key), "Unknown alert group")
    targets[key] = { frame = frame, onMoved = onMoved }
    apply(frame, key)
end

local function update(key)
    local target = targets[key]
    if target then
        apply(target.frame, key)
        if target.onMoved then target.onMoved() end
    end
    if previews[key] then apply(previews[key], key) end
end

local function finishDrag(save)
    if not dragging then return end
    local preview = dragging
    dragging = nil
    preview:StopMovingOrSizing()
    if save and not InCombatLockdown() then
        local x, y = preview:GetCenter()
        local cx, cy = UIParent:GetCenter()
        local scale = preview:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if x and y and cx and cy then positions()[preview.key] = { x = x * scale - cx, y = y * scale - cy } end
        update(preview.key)
    else
        apply(preview, preview.key)
    end
end

local function closeEditor()
    finishDrag(not InCombatLockdown())
    for _, preview in pairs(previews) do preview:Hide() end
end

local function selectPreview(key)
    finishDrag(true)
    selected = key
    for name, preview in pairs(previews) do preview:SetShown(name == key) end
    editor.status:SetText("Drag the outlined preview: " .. definition(key).name .. " — position saves when released.")
end

local function decoration(parent, text, width, height, point, relative, relativePoint, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetPoint(point, relative, relativePoint, x, y)
    button:SetText(text)
    button:EnableMouse(false) -- Decorative only; dragging still reaches the preview.
    return button
end

function showRaidBreakAlertPositionEditor()
    if InCombatLockdown() then
        print("SlashikRaidBreakTime: Move alerts outside combat.")
        return
    end
    if not editor then
        editor = CreateFrame("Frame", "SlashikRaidBreakTimeAlertPositionEditor", UIParent, "BasicFrameTemplateWithInset")
        editor:SetSize(650, 125)
        editor:SetPoint("TOP", UIParent, "TOP", 0, -40)
        editor:SetFrameStrata("TOOLTIP")
        editor.TitleText:SetText("Move alerts — select one preview at a time")
        editor:SetScript("OnHide", closeEditor)
        table.insert(UISpecialFrames, "SlashikRaidBreakTimeAlertPositionEditor")
        editor.status = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        editor.status:SetPoint("BOTTOM", 0, 16)
        for index, entry in ipairs(definitions) do
            local key = entry.key
            local tab = decoration(editor, entry.name, 145, 24, "TOPLEFT", editor, "TOPLEFT", 12 + (index - 1) * 150, -32)
            tab:EnableMouse(true)
            tab:SetScript("OnClick", function() selectPreview(key) end)
            local preview = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            preview.key = key
            preview:SetSize(key == "massRes" and 300 or 800, key == "massRes" and 80 or 240)
            preview:SetFrameStrata("FULLSCREEN_DIALOG")
            preview:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
            preview:SetBackdropColor(0.05, 0.12, 0.18, 0.8)
            preview:SetBackdropBorderColor(0.3, 0.8, 1, 1)
            preview:SetMovable(true)
            preview:SetClampedToScreen(true)
            preview:EnableMouse(true)
            preview:RegisterForDrag("LeftButton")
            preview:SetScript("OnDragStart", function(self)
                if InCombatLockdown() then return end
                dragging = self
                self:StartMoving()
            end)
            preview:SetScript("OnDragStop", function() finishDrag(true) end)
            if key == "massRes" then
                local cast = decoration(preview, "Mass Resurrect (preview)", 220, 32, "TOP", preview, "TOP", 0, 0)
                decoration(preview, "Dismiss", 90, 22, "TOP", cast, "BOTTOM", 0, -6)
            else
                local title = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
                title:SetPoint("CENTER", 0, 30)
                title:SetWidth(800)
                local font, _, flags = title:GetFont()
                title:SetFont(font, 60, flags)
                title:SetText(entry.title)
                local subtitle = preview:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
                subtitle:SetPoint("TOP", title, "BOTTOM", 0, -12)
                subtitle:SetWidth(800)
                subtitle:SetText(entry.subtitle)
                if key == "keystones" then decoration(preview, "Teleport", 110, 28, "TOP", subtitle, "BOTTOM", 0, -16) end
            end
            previews[key] = preview
            preview:Hide()
        end
        local reset = decoration(editor, "Reset positions", 145, 24, "TOPLEFT", editor, "TOPLEFT", 12, -64)
        reset:EnableMouse(true)
        reset:SetScript("OnClick", function()
            if InCombatLockdown() then return end
            finishDrag(false)
            SlashikRaidBreakTimeDB.alertPositions = {}
            for _, entry in ipairs(definitions) do update(entry.key) end
        end)
        local done = decoration(editor, "Done", 145, 24, "TOPRIGHT", editor, "TOPRIGHT", -12, -64)
        done:EnableMouse(true)
        done:SetScript("OnClick", function() editor:Hide(); showRaidBreakAddonSettings() end)
    end
    if SlashikRaidBreakTimeSettingsFrame then SlashikRaidBreakTimeSettingsFrame:Hide() end
    for _, entry in ipairs(definitions) do apply(previews[entry.key], entry.key) end
    editor:Show()
    selectPreview(selected or "keystones")
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function()
    if editor and editor:IsShown() then editor:Hide() end
end)
