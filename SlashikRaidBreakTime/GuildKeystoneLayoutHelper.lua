-- Guild view preferences are independent of the party view.
function createGuildKeystoneLayoutHelper(window)
    local layout = {}
    local function positionKey()
        return window.compact and "compactGuildKeystoneWindowPosition" or "guildKeystoneWindowPosition"
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

    function layout:apply(count)
        if InCombatLockdown() then return end
        local compact = window.compact
        window:SetSize(compact and 340 or 850, compact and (94 + count * 22) or 390)
        window.title:SetFontObject(compact and GameFontNormalSmall or GameFontNormalLarge)
        window.title:ClearAllPoints()
        window.title:SetPoint("TOPLEFT", compact and 12 or 18, compact and -12 or -18)
        window.modeButton:SetText(compact and "Expand" or "Compact")
        local controls = { window.modeButton, window.previous, window.next, window.refresh }
        for i, control in ipairs(controls) do
            control:ClearAllPoints()
            control:SetSize(compact and 74 or 100, compact and 22 or 26)
            if compact then
                control:SetPoint("BOTTOMLEFT", 12 + (i - 1) * 80, 10)
            elseif i == 1 then
                control:SetPoint("BOTTOMLEFT", 18, 18)
            else
                control:SetPoint("BOTTOMRIGHT", -18 - (4 - i) * 108, 18)
            end
        end
        window.status:ClearAllPoints()
        window.status:SetPoint("BOTTOMLEFT", compact and 12 or 18, compact and 38 or 50)
        for i, row in ipairs(window.rows) do
            local y = compact and (-34 - (i - 1) * 22) or (-52 - (i - 1) * 28)
            row.name:ClearAllPoints()
            row.name:SetPoint("TOPLEFT", compact and 12 or 18, y)
            row.name:SetSize(compact and 110 or 250, compact and 22 or 24)
            row.key:ClearAllPoints()
            row.key:SetPoint("TOPLEFT", compact and 130 or 280, y)
            row.key:SetSize(compact and 198 or 360, compact and 22 or 24)
            row.name:SetWordWrap(false)
            row.key:SetWordWrap(false)
        end
    end
    return layout
end
