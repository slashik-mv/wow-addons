-- Only insert a matching key when the player opens the Font of Power.
-- Starting the challenge always remains a manual action.
local events = CreateFrame("Frame")
events:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
events:SetScript("OnEvent", function()
    if not isRaidBreakModuleEnabled("keystones") or InCombatLockdown()
        or C_ChallengeMode.IsChallengeModeActive() or C_ChallengeMode.HasSlottedKeystone()
        or GetCursorInfo() then return end

    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and not info.isLocked then
                local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
                if C_ChallengeMode.CanUseKeystoneInCurrentMap(location) then
                    C_Container.PickupContainerItem(bag, slot)
                    local cursorType, itemID = GetCursorInfo()
                    if cursorType == "item" and itemID == info.itemID then
                        C_ChallengeMode.SlotKeystone()
                        -- Return our key to its bag if insertion failed; never discard it.
                        ClearCursor()
                    end
                    return
                end
            end
        end
    end
end)
