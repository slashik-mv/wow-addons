local function knowsTeleport(spellID)
    return spellID and C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Player)
end

local function remainingCooldown(spellID)
    local cooldown = C_Spell.GetSpellCooldown(spellID)
    if not cooldown then return 0 end
    return math.max(0, cooldown.startTime + cooldown.duration - GetTime())
end

-- Secure spell attributes must only be changed outside combat.
function updateDungeonTeleportButton(button, mapID)
    if InCombatLockdown() then return end
    local spellID = mapID and SlashikRaidBreakTimeDungeonTeleports[mapID]
    button.spellID = spellID
    button:SetAttribute("spell", spellID)
    button:SetAttribute("type", knowsTeleport(spellID) and "spell" or nil)
    button:SetEnabled(knowsTeleport(spellID) and remainingCooldown(spellID) <= 0 or false)
end

function createDungeonTeleportButton(parent, rowIndex)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    button:SetSize(82, 22)
    -- Secure buttons cannot have FontStrings anywhere in their anchor chain.
    -- Anchor directly to the window, aligned with the row's other buttons.
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 654, -53 - (rowIndex - 1) * 28)
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
