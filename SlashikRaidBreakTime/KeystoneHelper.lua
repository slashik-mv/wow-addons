-- Separate protocol so ordinary party members can share keys without raid-leader permissions.
function createKeystoneHelper()
    local PREFIX = "SRBT_KEYS"
    local helper = {}
    local window
    local results = {}
    local requestToken
    local sequence = 0
    local nextRequestAt = 0
    local lastReplies = {}
    local rosterSignature
    local refreshTimer

    local function cancelPendingRefresh()
        if refreshTimer then
            refreshTimer:Cancel()
            refreshTimer = nil
        end
    end

    local function fullName(unit)
        local name, realm = UnitFullName(unit)
        if not name then return nil end
        return name .. "-" .. ((realm and realm ~= "") and realm or GetNormalizedRealmName())
    end

    local function partyMembers()
        local members = { { unit = "player", name = fullName("player") } }
        if not IsInRaid() then
            for i = 1, GetNumSubgroupMembers() do
                local unit = "party" .. i
                local name = fullName(unit)
                if name then members[#members + 1] = { unit = unit, name = name } end
            end
        end
        return members
    end

    local function groupChannel()
        if IsInRaid() then return nil end
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
        if IsInGroup() then return "PARTY" end
    end

    local function updateRoster()
        local names, present = {}, {}
        for _, member in ipairs(partyMembers()) do
            if member.name then
                names[#names + 1] = member.name
                present[member.name] = true
            end
        end
        -- Unit order and leader changes do not change party membership.
        table.sort(names)
        local signature = (groupChannel() or "SOLO") .. ":" .. table.concat(names, ";")
        if signature == rosterSignature then return false end
        rosterSignature = signature
        requestToken = nil
        -- Keep keys for remaining members while removing departed members' data.
        for name in pairs(results) do
            if not present[name] then results[name] = nil end
        end
        for name in pairs(lastReplies) do
            if not present[name] then lastReplies[name] = nil end
        end
        return true
    end

    local function scheduleRefresh()
        cancelPendingRefresh()
        refreshTimer = C_Timer.NewTimer(math.max(2, nextRequestAt - GetTime()), function()
            refreshTimer = nil
            if window and window:IsShown() then helper:refresh() end
        end)
    end

    local function ownKey()
        local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
        local level = C_MythicPlus.GetOwnedKeystoneLevel()
        if mapID and level and mapID > 0 and level > 0 then return mapID, level end
        return 0, 0
    end

    local function render()
        if not window or not window:IsShown() then return end
        local members = partyMembers()
        for i, row in ipairs(window.rows) do
            local member = members[i]
            row.name:SetText(member and member.name or "")
            -- Reset reused rows before applying the current party member's class color.
            row.name:SetTextColor(1, 1, 1)
            if member then
                local _, className = UnitClass(member.unit)
                local color = className and RAID_CLASS_COLORS[className]
                if color then
                    row.name:SetTextColor(color.r, color.g, color.b)
                end
            end
            local text = ""
            if member then
                local key = results[member.name]
                if not UnitIsConnected(member.unit) then
                    text = "Offline"
                elseif not key then
                    text = "Unknown"
                elseif key.mapID == 0 then
                    text = "No keystone"
                else
                    local dungeon = C_ChallengeMode.GetMapUIInfo(key.mapID)
                    text = string.format("+%d  %s", key.level, dungeon or ("Dungeon " .. key.mapID))
                end
            end
            row.key:SetText(text)
        end
        window.hint:SetText(IsInRaid() and "Party only — showing your own keystone." or "Unknown: no reply yet. Party members need the updated addon.")
    end

    function helper:refresh()
        if GetTime() < nextRequestAt then
            if not refreshTimer then scheduleRefresh() end
            return
        end
        cancelPendingRefresh()
        updateRoster()
        nextRequestAt = GetTime() + 2
        sequence = sequence + 1
        requestToken = string.format("%s-%d-%d", UnitGUID("player"), GetServerTime(), sequence)
        local mapID, level = ownKey()
        results[fullName("player")] = { mapID = mapID, level = level }
        render()
        local channel = groupChannel()
        if channel then C_ChatInfo.SendAddonMessage(PREFIX, "Q:" .. requestToken, channel) end
    end

    function helper:show()
        if not window then
            window = CreateFrame("Frame", "SlashikRaidBreakTimeKeystoneFrame", UIParent, "BackdropTemplate")
            window:SetSize(660, 255)
            window:SetPoint("CENTER")
            window:SetFrameStrata("DIALOG")
            window:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark" })
            window:SetBackdropColor(0, 0, 0, 0.95)
            window:SetMovable(true)
            window:EnableMouse(true)
            window:RegisterForDrag("LeftButton")
            window:SetScript("OnDragStart", window.StartMoving)
            window:SetScript("OnDragStop", window.StopMovingOrSizing)
            window:SetScript("OnHide", cancelPendingRefresh)
            table.insert(UISpecialFrames, "SlashikRaidBreakTimeKeystoneFrame")
            local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            title:SetPoint("TOPLEFT", 18, -18)
            title:SetText("Party Keystones")
            local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
            close:SetPoint("TOPRIGHT", -4, -4)
            window.rows = {}
            for i = 1, 5 do
                local row = {}
                row.name = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.name:SetPoint("TOPLEFT", 18, -52 - (i - 1) * 28)
                row.name:SetSize(240, 24)
                row.name:SetJustifyH("LEFT")
                row.key = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.key:SetPoint("TOPLEFT", 270, -52 - (i - 1) * 28)
                row.key:SetSize(260, 24)
                row.key:SetJustifyH("LEFT")
                window.rows[i] = row
            end
            window.hint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            window.hint:SetPoint("BOTTOMLEFT", 18, 16)
            window.hint:SetSize(500, 36)
            window.hint:SetJustifyH("LEFT")
            local refresh = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
            refresh:SetSize(100, 26)
            refresh:SetPoint("BOTTOMRIGHT", -18, 20)
            refresh:SetText("Refresh")
            refresh:SetScript("OnClick", function() helper:refresh() end)

            -- Keep the decorative keystone in its own column above Refresh.
            window.keystoneArt = window:CreateTexture(nil, "ARTWORK")
            window.keystoneArt:SetSize(96, 96)
            window.keystoneArt:SetPoint("BOTTOM", refresh, "TOP", 0, 12)
            window.keystoneArt:SetTexture("Interface\\AddOns\\SlashikRaidBreakTime\\keystoneIcon.tga")
        end
        window:Show()
        self:refresh()
        render()
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("CHAT_MSG_ADDON")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
        if event == "PLAYER_LOGIN" then
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
            updateRoster()
        elseif event == "GROUP_ROSTER_UPDATE" then
            local changed = updateRoster()
            if changed and window and window:IsShown() then
                scheduleRefresh()
            end
            render()
        elseif event == "BAG_UPDATE_DELAYED" then
            local mapID, level = ownKey()
            results[fullName("player")] = { mapID = mapID, level = level }
            render()
        elseif event == "CHAT_MSG_ADDON" then
            if prefix ~= PREFIX or channel ~= groupChannel() or type(message) ~= "string" then return end
            local memberName
            for _, member in ipairs(partyMembers()) do
                if sender == member.name then memberName = member.name break end
            end
            if not memberName or memberName == fullName("player") then return end
            local token = message:match("^Q:([%w%-]+)$")
            if token and #token <= 80 then
                if GetTime() < (lastReplies[memberName] or 0) then return end
                lastReplies[memberName] = GetTime() + 2
                local mapID, level = ownKey()
                C_ChatInfo.SendAddonMessage(PREFIX, string.format("R:%s:%d:%d", token, mapID, level), channel)
                return
            end
            local replyToken, mapID, level = message:match("^R:([%w%-]+):(%d+):(%d+)$")
            if not requestToken or replyToken ~= requestToken then return end
            mapID, level = tonumber(mapID), tonumber(level)
            if not mapID or not level or mapID > 100000 or level > 1000 then return end
            if (mapID == 0) ~= (level == 0) then return end
            results[memberName] = { mapID = mapID, level = level }
            render()
        end
    end)

    return helper
end
