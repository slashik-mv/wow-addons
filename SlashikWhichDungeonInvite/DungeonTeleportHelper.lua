local function knowsTeleport(spellID)
    return spellID and C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Player)
end

local function remainingCooldown(spellID)
    local cooldown = C_Spell.GetSpellCooldown(spellID)
    if not cooldown then return 0 end
    return math.max(0, cooldown.startTime + cooldown.duration - GetTime())
end

-- Secure spell attributes must only be changed outside combat.
function updateInviteDungeonTeleportButton(button, mapID)
    if InCombatLockdown() then return end
    local spellID = mapID and SlashikWhichDungeonInviteDungeonTeleports[mapID]
    button.spellID = spellID
    button:SetAttribute("spell", spellID)
    button:SetAttribute("type", knowsTeleport(spellID) and "spell" or nil)
    button:SetEnabled(knowsTeleport(spellID) and remainingCooldown(spellID) <= 0 or false)
end

function createInviteDungeonTeleportButton(parent)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    button:SetSize(110, 28)
    -- Anchor directly to UIParent, never to the notification or its FontString.
    button:SetPoint("CENTER", parent, "CENTER", 0, -150)
    button:SetText("Teleport")
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local spellID = self.spellID
        GameTooltip:SetText("Dungeon teleport")
        if not spellID then
            GameTooltip:AddLine("No teleport mapped for this dungeon.", 1, 0.5, 0.2)
        elseif InCombatLockdown() then
            GameTooltip:AddLine("Unavailable during combat.", 1, 0.5, 0.2)
        elseif not knowsTeleport(spellID) then
            GameTooltip:AddLine("You have not unlocked this teleport.", 1, 0.5, 0.2)
        else
            GameTooltip:SetSpellByID(spellID)
            local seconds = remainingCooldown(spellID)
            if seconds > 0 then
                GameTooltip:AddLine(string.format("Cooldown remaining: %d min", math.ceil(seconds / 60)), 1, 0.5, 0.2)
            else
                GameTooltip:AddLine("Click to teleport yourself to this dungeon.", 0.2, 1, 0.2)
            end
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

-- LFG activities use instance map IDs, not Challenge Mode IDs.
function getInviteDungeonMapID(activityID)
    local activity = activityID and C_LFGList.GetActivityInfoTable(activityID)
    if not activity or not activity.isMythicPlusActivity or not activity.mapID or activity.mapID == 0 then return end
    for _, challengeID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
        if SlashikWhichDungeonInviteDungeonTeleports[challengeID] then
            local _, _, _, _, _, mapID = C_ChallengeMode.GetMapUIInfo(challengeID)
            if mapID == activity.mapID then return challengeID end
        end
    end
end
