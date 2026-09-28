-- Raid Soulstone reminders: ready-check buffs and self-reported wipe recovery.
-- No automatic resurrection or changes to the release button.
local PREFIX = "SRBT_SOULSTONE"
local SOULSTONE_RESURRECTION = 3026
local encounter, deadline, reported = nil, 0, false
local holders, timers = {}, {}
local warning
local readyCheckActive = false
local readyCheckInitiator
local readyWarningSent = false
local READY_WARNING = "USE SOULSTONE ON A HEALER!"

local function announceReadyWarning()
    if not getSettings().soulstoneEnabled then return end
    if readyWarningSent then return end
    local player, realm = UnitFullName("player")
    realm = realm and realm ~= "" and realm or GetNormalizedRealmName()
    if not player or not realm or not readyCheckInitiator then return end
    local playerName = player .. "-" .. realm
    local isInitiator = readyCheckInitiator == playerName
        or readyCheckInitiator == Ambiguate(playerName, "none")
    -- The initiator uses raid warning; other opted-in players use ordinary raid chat.
    readyWarningSent = true
    if isInitiator and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        C_ChatInfo.SendChatMessage(READY_WARNING, "RAID_WARNING")
    else
        -- Fall back to chat if the initiator lost raid-warning permissions.
        C_ChatInfo.SendChatMessage("No Soulstone in the raid!", "RAID")
    end
end

local function channel()
    local _, instanceType = GetInstanceInfo()
    if not IsInRaid() or instanceType ~= "raid" then return nil end
    return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "RAID"
end

local function fullName(unit)
    local name, realm = UnitFullName(unit)
    realm = realm and realm ~= "" and realm or GetNormalizedRealmName()
    if name and realm then return name .. "-" .. realm end
end

local function raidUnit(sender)
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        local name = fullName(unit)
        if name and (sender == name or sender == Ambiguate(name, "none")) then return unit, name end
    end
end

local function showWarning(titleText, subtitleText)
    if not warning then
        warning = CreateFrame("Frame", nil, UIParent)
        warning:SetSize(800, 240)
        warning:SetPoint("CENTER")
        warning:SetFrameStrata("FULLSCREEN_DIALOG")
        warning:EnableMouse(false)
        local title = warning:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        title:SetPoint("CENTER", 0, 30)
        title:SetWidth(800)
        local font, _, flags = title:GetFont()
        title:SetFont(font, 60, flags)
        warning.title = title
        warning.subtitle = warning:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        warning.subtitle:SetPoint("TOP", title, "BOTTOM", 0, -12)
        warning.subtitle:SetWidth(800)
    end
    warning.title:SetText(titleText)
    warning.subtitle:SetText(subtitleText)
    warning:Show()
end

local function render()
    local names = {}
    for name in pairs(holders) do
        if raidUnit(name) then names[#names + 1] = Ambiguate(name, "none") end
    end
    table.sort(names)
    if #names == 0 or not channel() or GetTime() >= deadline then
        if warning then warning:Hide() end
        return
    end
    showWarning("DON'T RELEASE!", table.concat(names, ", ") .. (#names == 1 and " has a Soulstone." or " have Soulstones."))
end

local function checkReadySoulstone()
    if not getSettings().soulstoneEnabled then return end
    if not readyCheckActive then return end
    if warning then warning:Hide() end
    if not channel() or InCombatLockdown() then return end
    local warlock, unknown = false, false
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        local _, class = UnitClass(unit)
        if class == "WARLOCK" and UnitIsConnected(unit) then warlock = true end
        -- Out-of-range, offline or restricted information cannot prove an aura is absent.
        if not class or not UnitIsConnected(unit) or not UnitIsVisible(unit) then
            unknown = true
        else
            for index = 1, 255 do
                local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")
                if issecretvalue and issecretvalue(aura) then unknown = true; break end
                if not aura then break end
                if issecretvalue and issecretvalue(aura.spellId) then
                    unknown = true
                elseif aura.spellId == 20707 then
                    return -- Any Soulstone holder is enough, regardless of role.
                end
                if index == 255 then unknown = true end
            end
        end
    end
    if warlock and not unknown then
        showWarning("USE SOULSTONE\nON A HEALER!", "No Soulstone detected in the raid.")
        announceReadyWarning()
    end
end

local function reset()
    for _, timer in ipairs(timers) do timer:Cancel() end
    timers, holders = {}, {}
    encounter, deadline, reported = nil, 0, false
    readyCheckActive = false
    readyWarningSent = false
    readyCheckInitiator = nil
    if warning then warning:Hide() end
end

-- The setting controls ready checks only; wipe recovery is always enabled.
function setRaidSoulstoneEnabled(enabled)
    getSettings().soulstoneEnabled = enabled == true
    if not enabled and readyCheckActive then reset() end
end

local function checkOwnSoulstone()
    if not encounter or GetTime() >= deadline or not channel() then return end
    local usable = false
    if UnitIsDead("player") and not UnitIsGhost("player") then
        for _, option in ipairs(C_DeathInfo.GetSelfResurrectOptions() or {}) do
            -- Match the resurrection spell, not the warlock's Soulstone cast/aura.
            if option.optionType == Enum.SelfResurrectOptionType.Spell
                and option.id == SOULSTONE_RESURRECTION and option.canUse then usable = true; break end
        end
    end
    local name = fullName("player")
    if not name or usable == reported then return end
    reported = usable
    holders[name] = usable or nil
    C_ChatInfo.SendAddonMessage(PREFIX, encounter .. ":" .. (usable and "1" or "0"), channel())
    render()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "ENCOUNTER_START", "ENCOUNTER_END", "CHAT_MSG_ADDON",
    "SELF_RES_SPELL_CHANGED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "READY_CHECK", "READY_CHECK_FINISHED",
    "UNIT_AURA", "PLAYER_REGEN_DISABLED" }) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    elseif event == "READY_CHECK" then
        if not getSettings().soulstoneEnabled then return end
        reset()
        if not channel() or InCombatLockdown() then return end
        readyCheckActive = true
        readyCheckInitiator = ...
        checkReadySoulstone()
    elseif event == "READY_CHECK_FINISHED" then
        if readyCheckActive then reset() end
    elseif event == "UNIT_AURA" then
        local unit = ...
        if readyCheckActive and (unit == "player" or (type(unit) == "string" and unit:match("^raid%d+$"))) then
            checkReadySoulstone()
        end
    elseif event == "ENCOUNTER_START" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_DISABLED" then
        reset()
    elseif event == "ENCOUNTER_END" then
        local id, _, _, _, success = ...
        reset()
        if success ~= 0 or not channel() then return end
        encounter, deadline = id, GetTime() + 15
        -- Briefly defer so every client can process ENCOUNTER_END before reports arrive.
        timers[#timers + 1] = C_Timer.NewTimer(0.5, checkOwnSoulstone)
        timers[#timers + 1] = C_Timer.NewTimer(2, checkOwnSoulstone)
        timers[#timers + 1] = C_Timer.NewTimer(15, reset)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, distribution, sender = ...
        if prefix ~= PREFIX or not encounter or GetTime() >= deadline
            or not channel() or distribution ~= channel() or type(message) ~= "string" or #message > 32 then return end
        local id, state = message:match("^(%d+):([01])$")
        if tonumber(id) ~= encounter then return end
        local unit, name = raidUnit(sender)
        if not unit or name == fullName("player") then return end
        local available = state == "1"
        if available and (not UnitIsDead(unit) or UnitIsGhost(unit)) then return end
        if (holders[name] == true) == available then return end
        holders[name] = available or nil
        render()
    elseif event == "GROUP_ROSTER_UPDATE" then
        if readyCheckActive then checkReadySoulstone()
        elseif not channel() then reset() else render() end
    else
        checkOwnSoulstone()
    end
end)
