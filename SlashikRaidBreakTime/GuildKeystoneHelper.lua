-- Guild-only view. Uses LibKeystone without changing the party window's settings.
function createGuildKeystoneHelper()
    local helper, results, members = {}, {}, {}
    local lib = LibStub("LibKeystone")
    local window, openAfterCombat
    local page, nextRequest = 1, 0
    local PAGE_SIZE = 10

    local function roster()
        members = {}
        local present = {}
        if IsInGuild() then
            for i = 1, GetNumGuildMembers() do
                local name, _, _, _, _, _, _, _, online, _, class = GetGuildRosterInfo(i)
                if name and online then
                    if not name:find("-", 1, true) then name = name .. "-" .. GetNormalizedRealmName() end
                    members[#members + 1] = { name = name, class = class }
                    present[name] = true
                end
            end
        end
        for name in pairs(results) do if not present[name] then results[name] = nil end end
    end

    local function render()
        if not window or not window.ready or not window:IsShown() or InCombatLockdown() then return end
        -- Re-sort as key replies arrive; names provide a stable tie-breaker.
        table.sort(members, function(a, b)
            local aKey, bKey = results[a.name], results[b.name]
            local aLevel = aKey and aKey.mapID > 0 and aKey.level or 0
            local bLevel = bKey and bKey.mapID > 0 and bKey.level or 0
            if aLevel ~= bLevel then return aLevel > bLevel end
            return a.name < b.name
        end)
        local pages = math.max(1, math.ceil(#members / PAGE_SIZE))
        page = math.min(page, pages)
        for i, row in ipairs(window.rows) do
            local member = members[(page - 1) * PAGE_SIZE + i]
            local key = member and results[member.name]
            row.member = member
            row.name:SetText(member and member.name or "")
            local color = member and member.class and RAID_CLASS_COLORS[member.class]
            row.name:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
            local text = ""
            if member then
                if not key then text = "Unknown"
                elseif key.mapID == 0 then text = "No keystone"
                else text = string.format("+%d  %s", key.level, C_ChallengeMode.GetMapUIInfo(key.mapID) or ("Dungeon " .. key.mapID)) end
            end
            row.key:SetText(text)
            row.whisper:SetShown(member ~= nil)
            row.whisper:SetEnabled(key ~= nil and key.mapID > 0 and key.level > 0
                and C_ChallengeMode.GetMapUIInfo(key.mapID) ~= nil)
            row.teleport:SetShown(member ~= nil)
            updateDungeonTeleportButton(row.teleport, key and key.mapID)
        end
        window.status:SetText(IsInGuild() and string.format("%d online — Page %d/%d", #members, page, pages) or "You are not in a guild.")
        window.previous:SetEnabled(page > 1)
        window.next:SetEnabled(page < pages)
    end

    lib.Register(helper, function(level, mapID, _, sender, channel)
        if channel ~= "GUILD" or not IsInGuild() then return end
        if type(level) ~= "number" or type(mapID) ~= "number" then return end
        if level < 0 or level > 1000 or mapID < 0 or mapID > 100000 or (level == 0) ~= (mapID == 0) then return end
        for _, member in ipairs(members) do
            if sender == member.name or sender == Ambiguate(member.name, "none") then
                results[member.name] = { level = level, mapID = mapID }
                render()
                return
            end
        end
    end)

    function helper:refresh()
        if GetTime() < nextRequest then return end
        nextRequest = GetTime() + 3
        roster()
        render()
        if IsInGuild() then
            C_GuildInfo.GuildRoster()
            lib.Request("GUILD")
        end
    end

    function helper:show()
        if InCombatLockdown() then
            openAfterCombat = true
            print("SlashikRaidBreakTime: The guild keystone window will open after combat.")
            return
        end
        if not window then
            window = CreateFrame("Frame", "SlashikRaidBreakTimeGuildKeystoneFrame", UIParent, "BackdropTemplate")
            window:Hide()
            window:SetSize(850, 390)
            window:SetClampedToScreen(true)
            window:SetFrameStrata("DIALOG")
            window:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark" })
            window:SetBackdropColor(0, 0, 0, 0.95)
            local position = SlashikRaidBreakTimeDB and SlashikRaidBreakTimeDB.guildKeystoneWindowPosition
            local anchors = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
            if type(position) == "table" and anchors[position.point] and anchors[position.relativePoint]
                and type(position.x) == "number" and type(position.y) == "number" then
                window:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
            else window:SetPoint("CENTER") end
            window:SetMovable(true)
            window:EnableMouse(true)
            window:RegisterForDrag("LeftButton")
            window:SetScript("OnDragStart", window.StartMoving)
            window:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                local point, _, relativePoint, x, y = self:GetPoint()
                SlashikRaidBreakTimeDB = SlashikRaidBreakTimeDB or {}
                SlashikRaidBreakTimeDB.guildKeystoneWindowPosition = { point = point, relativePoint = relativePoint, x = x, y = y }
            end)
            RegisterStateDriver(window, "visibility", "[combat] hide;")
            table.insert(UISpecialFrames, "SlashikRaidBreakTimeGuildKeystoneFrame")
            local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            title:SetPoint("TOPLEFT", 18, -18)
            title:SetText("Guild Keystones")
            local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
            close:SetPoint("TOPRIGHT", -4, -4)
            window.rows = {}
            for i = 1, PAGE_SIZE do
                local row = {}
                row.name = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.name:SetPoint("TOPLEFT", 18, -52 - (i - 1) * 28)
                row.name:SetSize(250, 24)
                row.name:SetJustifyH("LEFT")
                row.key = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.key:SetPoint("TOPLEFT", 280, -52 - (i - 1) * 28)
                row.key:SetSize(360, 24)
                row.key:SetJustifyH("LEFT")
                row.whisper = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
                row.whisper:SetSize(82, 22)
                row.whisper:SetPoint("TOPLEFT", window, "TOPLEFT", 654, -53 - (i - 1) * 28)
                row.whisper:SetText("Whisper")
                row.whisper:SetScript("OnClick", function()
                    local member = row.member
                    local key = member and results[member.name]
                    if key then whisperGuildKeystoneOwner(member.name, key.mapID, key.level) end
                end)
                row.teleport = createDungeonTeleportButton(window, i)
                row.teleport:ClearAllPoints()
                row.teleport:SetPoint("TOPLEFT", window, "TOPLEFT", 744, -53 - (i - 1) * 28)
                window.rows[i] = row
            end
            window.status = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            window.status:SetPoint("BOTTOMLEFT", 18, 24)
            local function button(label, x, callback)
                local control = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
                control:SetSize(100, 26)
                control:SetPoint("BOTTOMRIGHT", x, 18)
                control:SetText(label)
                control:SetScript("OnClick", callback)
                return control
            end
            window.previous = button("Previous", -234, function() if not InCombatLockdown() then page = math.max(1, page - 1); render() end end)
            window.next = button("Next", -126, function() if not InCombatLockdown() then page = math.min(math.max(1, math.ceil(#members / PAGE_SIZE)), page + 1); render() end end)
            button("Refresh", -18, function() helper:refresh() end)
            window.ready = true
        end
        window:Show()
        self:refresh()
        render()
    end

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_LOGIN", "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN" }) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and openAfterCombat then
            openAfterCombat = false
            helper:show()
        elseif event == "PLAYER_LOGIN" or event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
            roster()
            render()
            -- Initial roster loading may finish after the first key request.
            if event == "GUILD_ROSTER_UPDATE" and window and window:IsShown() and IsInGuild() and not window.requestedInitialRoster then
                window.requestedInitialRoster = true
                lib.Request("GUILD")
            end
        else render() end
    end)
    return helper
end
