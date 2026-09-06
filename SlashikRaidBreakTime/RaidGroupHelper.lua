function createRaidGroupHelper(addonPrefix)
    local helper = {}

    function helper:isAllowedToStart()
        if not IsInGroup() then return true end
        return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
    end

    function helper:isSenderAllowed(sender)
        local shortSender = Ambiguate(sender, "short")
        local members = GetNumGroupMembers()

        if IsInRaid() then
            for i = 1, members do
                local name = GetRaidRosterInfo(i)
                if name and Ambiguate(name, "short") == shortSender then
                    local unit = "raid" .. i
                    return UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)
                end
            end
        else
            if Ambiguate(UnitName("player"), "short") == shortSender then
                return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
            end
            for i = 1, members - 1 do
                local unit = "party" .. i
                local name = UnitName(unit)
                if name and Ambiguate(name, "short") == shortSender then
                    return UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)
                end
            end
        end
        return false
    end

    function helper:broadcast(seconds, imageIndex)
        local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
        C_ChatInfo.SendAddonMessage(addonPrefix, string.format("START:%d:%d", seconds, imageIndex), channel)
    end

    return helper
end
