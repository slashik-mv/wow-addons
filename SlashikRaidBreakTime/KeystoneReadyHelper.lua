-- Manual preparation controls for the party leader before starting a keystone.
local panel

local function canPrepare()
    if not isRaidBreakModuleEnabled("keystones") or InCombatLockdown()
        or IsInRaid() or not IsInGroup() or not UnitIsGroupLeader("player") then return false end
    local _, instanceType, difficulty = GetInstanceInfo()
    -- 23 is Mythic before insertion; 8 is an ongoing/completed keystone instance.
    return instanceType == "party" and difficulty == 23 and not C_ChallengeMode.IsChallengeModeActive()
end

local function refresh()
    if not canPrepare() then
        if panel then panel:Hide() end
        return
    end
    if not panel then
        panel = CreateFrame("Frame", "SlashikRaidBreakTimeKeystoneReadyFrame", UIParent, "BackdropTemplate")
        panel:SetSize(270, 48)
        panel:SetFrameStrata("DIALOG")
        panel:SetClampedToScreen(true)
        panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        panel:SetBackdropColor(0, 0, 0, 0.65)
        registerRaidBreakAlertPosition(panel, "keyReady")
        local function button(text, x, action)
            local control = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            control:SetSize(120, 28)
            control:SetPoint("LEFT", panel, "LEFT", x, 0)
            control:SetText(text)
            control:SetScript("OnClick", function()
                -- Recheck eligibility at click time, including leadership and combat.
                if canPrepare() then action() else refresh() end
            end)
        end
        button("Ready Check", 10, function() C_PartyInfo.DoReadyCheck() end)
        button("Pull 10", 140, function() C_PartyInfo.DoCountdown(10) end)
    end
    panel:Show()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE",
    "PARTY_LEADER_CHANGED", "PLAYER_DIFFICULTY_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_COMPLETED" then
        if panel then panel:Hide() end
    else
        refresh()
    end
end)
registerRaidBreakModuleListener("keystones", refresh)
