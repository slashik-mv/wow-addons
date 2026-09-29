local _, addon = ...

local greetedDungeon
local pendingArrival = false
local suppressArrival = false
local arrivalGeneration = 0

local function GetDungeonKey()
    local inInstance, instanceType = IsInInstance()
    local _, _, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    if not inInstance or instanceType ~= "party"
        or (difficultyID ~= 1 and difficultyID ~= 2)
        or not IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInRaid()
        or not IsPartyLFG() then
        return nil
    end
    local dungeonID = GetPartyLFGID()
    if not dungeonID or not instanceID then return nil end
    return tostring(dungeonID) .. ":" .. tostring(instanceID) .. ":" .. tostring(difficultyID)
end

local function ResetPendingGreeting()
    pendingArrival = false
    arrivalGeneration = arrivalGeneration + 1
end

local function OnDungeonFinderGroupLeft()
    ResetPendingGreeting()
    greetedDungeon = nil
end

local function OnDungeonFinderProposalSucceeded()
    -- Allow a new queued run, including the same dungeon with the same party.
    -- Arrival detection also works when this event is absent for a backfill join.
    greetedDungeon = nil
end

local function TryGreeting()
    if not pendingArrival then return end
    local key = GetDungeonKey()
    if not key then return end

    ResetPendingGreeting()
    if greetedDungeon == key then return end
    greetedDungeon = key
    if not suppressArrival and addon.GetSettings().autoPullMessages then
        addon.SendRandomPullMessage()
    end
end

local function OnDungeonFinderEnteringWorld(isInitialLogin, isReloadingUi)
    ResetPendingGreeting()
    pendingArrival = true
    suppressArrival = isInitialLogin or isReloadingUi

    local generation = arrivalGeneration
    local attempts = 0
    local function CheckArrival()
        if generation ~= arrivalGeneration or not pendingArrival then return end
        TryGreeting()
        attempts = attempts + 1
        if pendingArrival and attempts < 10 then
            C_Timer.After(1, CheckArrival)
        end
    end

    -- Allow the client to finish loading before sending chat.
    C_Timer.After(1, CheckArrival)
end

local function OnDungeonFinderGroupUpdated()
    if not pendingArrival then return end
    local generation = arrivalGeneration
    C_Timer.After(1, function()
        if generation == arrivalGeneration then TryGreeting() end
    end)
end

addon.OnDungeonFinderProposalSucceeded = OnDungeonFinderProposalSucceeded
addon.OnDungeonFinderEnteringWorld = OnDungeonFinderEnteringWorld
addon.OnDungeonFinderGroupUpdated = OnDungeonFinderGroupUpdated
addon.OnDungeonFinderGroupLeft = OnDungeonFinderGroupLeft
addon.ResetDungeonFinderGreeting = ResetPendingGreeting
