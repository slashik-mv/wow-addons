-- One frame, two layouts, with independent saved positions.
function createKeystoneLayoutHelper(window)
    local layout = {}
    local function positionKey()
        return window.compact and "compactKeystoneWindowPosition" or "keystoneWindowPosition"
    end

    function layout:savePosition()
        local point, _, relativePoint, x, y = window:GetPoint()
        SlashikRaidBreakTimeDB = SlashikRaidBreakTimeDB or {}
        SlashikRaidBreakTimeDB[positionKey()] = { point = point, relativePoint = relativePoint, x = x, y = y }
    end

    function layout:restorePosition()
        local position = SlashikRaidBreakTimeDB and SlashikRaidBreakTimeDB[positionKey()]
        local anchors = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true,
            CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
        window:ClearAllPoints()
        if type(position) == "table" and anchors[position.point] and anchors[position.relativePoint]
            and type(position.x) == "number" and type(position.y) == "number" then
            window:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
        else window:SetPoint("CENTER") end
    end

    function layout:apply(memberCount)
        if InCombatLockdown() then return end
        local compact = window.compact
        window:SetSize(compact and 340 or 868, compact and (74 + memberCount * 22) or 255)
        window.title:SetFontObject(compact and GameFontNormalSmall or GameFontNormalLarge)
        window.title:ClearAllPoints()
        window.title:SetPoint("TOPLEFT", compact and 12 or 18, compact and -12 or -18)
        for _, region in ipairs(window.normalOnly) do region:SetShown(not compact) end
        window.modeButton:SetText(compact and "Expand" or "Compact")
        window.modeButton:SetSize(compact and 74 or 90, compact and 22 or 26)
        window.modeButton:ClearAllPoints()
        window.modeButton:SetPoint("BOTTOMLEFT", compact and 12 or 18, compact and 10 or 20)
        window.refresh:SetSize(compact and 74 or 100, compact and 22 or 26)
        window.refresh:ClearAllPoints()
        window.refresh:SetPoint("BOTTOMRIGHT", compact and -12 or -18, compact and 10 or 20)
        for i, row in ipairs(window.rows) do
            local rowY = compact and (-34 - (i - 1) * 22) or (-52 - (i - 1) * 28)
            row.name:ClearAllPoints()
            row.name:SetPoint("TOPLEFT", window, "TOPLEFT", compact and 12 or 18, rowY)
            row.name:SetSize(compact and 110 or 240, compact and 22 or 24)
            row.key:ClearAllPoints()
            row.key:SetPoint("TOPLEFT", window, "TOPLEFT", compact and 130 or 270, rowY)
            row.key:SetSize(compact and 198 or 200, compact and 22 or 24)
            row.name:SetWordWrap(false)
            row.key:SetWordWrap(false)
        end
    end

    return layout
end
