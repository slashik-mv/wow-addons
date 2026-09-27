-- Guild-only view. Uses LibKeystone without changing the party window's settings.
function createGuildKeystoneHelper()
    local helper, results, members = {}, {}, {}
    local lib = LibStub("LibKeystone")
    local cacheHelper = createGuildKeystoneCacheHelper()
    local guildID, initialRequestGuild
    local window, openAfterCombat
    local page, nextRequest = 1, 0
    local PAGE_SIZE = 10

    local function roster(prune)
        members = {}
        local cache, id = cacheHelper:get()
        if id ~= guildID then results = {}; guildID = id; initialRequestGuild = nil end
        local present = {}
        local count = GetNumGuildMembers()
        local complete, sawPlayer = count > 0, false
        if IsInGuild() then
            for i = 1, count do
                local name, _, _, _, _, _, _, _, online, _, class = GetGuildRosterInfo(i)
                if name and not name:find("-", 1, true) then
                    local realm = GetNormalizedRealmName()
                    name = realm and (name .. "-" .. realm) or nil
                end
                if name then
                    present[name] = true
                    if Ambiguate(name, "none") == UnitName("player") then sawPlayer = true end
                    if online or (cache and cache[name]) then
                        members[#members + 1] = { name = name, class = class, online = online == true }
                    end
                    if not online then results[name] = nil end
                else complete = false end
            end
        end
        if prune and complete and sawPlayer and cache then
            for name in pairs(cache) do if not present[name] then cache[name] = nil end end
            for name in pairs(results) do if not present[name] then results[name] = nil end end
        end
    end

    local function memberKey(member)
        if not member then return nil end
        local cache = cacheHelper:get()
        return results[member.name] or (cache and cache[member.name])
    end

    local function render()
        if not window or not window.ready or not window:IsShown() or InCombatLockdown() then return end
        -- Re-sort as key replies arrive; names provide a stable tie-breaker.
        table.sort(members, function(a, b)
            if a.online ~= b.online then return a.online end
            local aKey, bKey = memberKey(a), memberKey(b)
            local aLevel = aKey and aKey.mapID > 0 and aKey.level or 0
            local bLevel = bKey and bKey.mapID > 0 and bKey.level or 0
            if aLevel ~= bLevel then return aLevel > bLevel end
            return a.name < b.name
        end)
        local pages = math.max(1, math.ceil(#members / PAGE_SIZE))
        page = math.min(page, pages)
        local count = math.min(PAGE_SIZE, math.max(0, #members - (page - 1) * PAGE_SIZE))
        local offlineRow
        for i = 1, count do
            if not members[(page - 1) * PAGE_SIZE + i].online then offlineRow = i; break end
        end
        window.layout:apply(count, offlineRow)
        for i, row in ipairs(window.rows) do
            local member = members[(page - 1) * PAGE_SIZE + i]
            local key = memberKey(member)
            row.member = member
            row.name:SetText(member and (window.compact and Ambiguate(member.name, "short") or member.name) or "")
            local color = member and member.class and RAID_CLASS_COLORS[member.class]
            row.name:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
            local text = ""
            if member then
                if not key then text = "Unknown"
                elseif key.mapID == 0 then text = "No keystone"
                else text = string.format("+%d  %s", key.level, C_ChallengeMode.GetMapUIInfo(key.mapID) or ("Dungeon " .. key.mapID)) end
            end
            row.key:SetText(text)
            if member and not member.online and key then
                row.key:SetText(text .. (window.compact and " (offline)" or (" — Offline · seen " .. cacheHelper:age(key))))
            elseif key and key.seenAt then row.key:SetText(text .. " (last known)") end
            row.hover:SetShown(member ~= nil)
            row.whisper:SetShown(member ~= nil and member.online and not window.compact)
            row.whisper:SetEnabled(key ~= nil and key.mapID > 0 and key.level > 0
                and C_ChallengeMode.GetMapUIInfo(key.mapID) ~= nil)
            row.teleport:SetShown(member ~= nil and not window.compact)
            updateDungeonTeleportButton(row.teleport, key and key.mapID)
        end
        local online = 0
        for _, member in ipairs(members) do if member.online then online = online + 1 end end
        window.status:SetText(IsInGuild() and string.format("%d online · %d offline — Page %d/%d", online, #members - online, page, pages) or "You are not in a guild.")
        window.previous:SetEnabled(page > 1)
        window.next:SetEnabled(page < pages)
    end

    lib.Register(helper, function(level, mapID, _, sender, channel)
        if channel ~= "GUILD" or not IsInGuild() then return end
        if type(level) ~= "number" or type(mapID) ~= "number" then return end
        if level < 0 or level > 1000 or mapID < 0 or mapID > 100000 or (level == 0) ~= (mapID == 0) then return end
        roster()
        for _, member in ipairs(members) do
            if sender == member.name or sender == Ambiguate(member.name, "none") then
                cacheHelper:save(member.name, member.class, mapID, level)
                results[member.name] = { level = level, mapID = mapID }
                roster()
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
            initialRequestGuild = guildID
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
            window.compact = SlashikRaidBreakTimeDB and SlashikRaidBreakTimeDB.compactGuildKeystones == true or false
            window.layout = createGuildKeystoneLayoutHelper(window)
            window.layout:restorePosition()
            window:SetMovable(true)
            window:EnableMouse(true)
            window:RegisterForDrag("LeftButton")
            window:SetScript("OnDragStart", function(self)
                if not InCombatLockdown() then self:StartMoving() end
            end)
            window:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                window.layout:savePosition()
            end)
            RegisterStateDriver(window, "visibility", "[combat] hide;")
            table.insert(UISpecialFrames, "SlashikRaidBreakTimeGuildKeystoneFrame")
            local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            title:SetPoint("TOPLEFT", 18, -18)
            title:SetText("Guild Keystones")
            window.title = title
            window.offlineDivider = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            window.offlineDivider:SetText("Offline — last known")
            window.offlineDivider:SetJustifyH("LEFT")
            window.offlineDividerLine = window:CreateTexture(nil, "ARTWORK")
            window.offlineDividerLine:SetColorTexture(0.7, 0.6, 0.3, 0.5)
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
                -- A non-secure hit area keeps full last-known details readable in compact mode.
                row.hover = CreateFrame("Frame", nil, window)
                row.hover:SetAllPoints(row.key)
                row.hover:EnableMouse(true)
                row.hover:SetScript("OnEnter", function(self)
                    local member = row.member
                    local key = memberKey(member)
                    if not member or not key then return end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(member.name)
                    GameTooltip:AddLine(string.format("+%d %s", key.level,
                        C_ChallengeMode.GetMapUIInfo(key.mapID) or "Unknown dungeon"), 1, 1, 1)
                    local cache = cacheHelper:get()
                    local saved = cache and cache[member.name]
                    if saved then
                        GameTooltip:AddLine((member.online and "Online" or "Offline") .. " — last received " .. cacheHelper:age(saved), 1, 0.82, 0)
                        GameTooltip:AddLine("Last-known keys may have changed.", 0.7, 0.7, 0.7)
                    end
                    GameTooltip:Show()
                end)
                row.hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
                row.whisper = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
                row.whisper:SetSize(82, 22)
                row.whisper:SetPoint("TOPLEFT", window, "TOPLEFT", 654, -53 - (i - 1) * 28)
                row.whisper:SetText("Whisper")
                row.whisper:SetScript("OnClick", function()
                    local member = row.member
                    local key = memberKey(member)
                    if key and member.online then whisperGuildKeystoneOwner(member.name, key.mapID, key.level) end
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
            window.refresh = button("Refresh", -18, function() helper:refresh() end)
            window.modeButton = button("Compact", -342, function()
                if InCombatLockdown() then return end
                window:StopMovingOrSizing()
                window.layout:savePosition()
                window.compact = not window.compact
                SlashikRaidBreakTimeDB.compactGuildKeystones = window.compact
                render()
                window.layout:restorePosition()
            end)
            window.ready = true
        end
        window:Show()
        self:refresh()
        render()
    end

    -- One delayed request per guild per login. Incoming replies are cached even with the window closed.
    local initialTimer
    local function requestInitialKeys()
        if initialTimer or not guildID or initialRequestGuild == guildID or #members == 0 then return end
        initialTimer = C_Timer.NewTimer(5, function()
            initialTimer = nil
            roster()
            if guildID and initialRequestGuild ~= guildID and #members > 0 then
                helper:refresh()
                if initialRequestGuild ~= guildID then requestInitialKeys() end
            end
        end)
    end
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_LOGIN", "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN" }) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and openAfterCombat then
            openAfterCombat = false
            helper:show()
        elseif event == "PLAYER_LOGIN" or event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
            roster(event == "GUILD_ROSTER_UPDATE")
            render()
            if event ~= "GUILD_ROSTER_UPDATE" and IsInGuild() then C_GuildInfo.GuildRoster() end
            requestInitialKeys()
        else render() end
    end)
    return helper
end
