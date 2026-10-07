-- Self-reported Holy Priest recovery; ordinary Spirit of Redemption is not enough.
function createRaidRestitutionHelper(fullName, raidUnit, channel, debugLog)
    local helper = {}
    local reports = {}
    local observed = {}
    local witnessed, aliveUntil, lastState = false, nil, nil

    local function secret(value)
        return issecretvalue and issecretvalue(value)
    end

    -- nil means unknown, never absence: restricted aura data must not imply revival.
    local function hasAngel(unit)
        -- Access itself is forbidden while auras are restricted; checking returned
        -- secret values is too late. Unknown is not evidence that angel form ended.
        if InCombatLockdown() or (C_Secrets and C_Secrets.ShouldAurasBeSecret()) then return nil end
        local unknown = false
        for i = 1, 255 do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit or "player", i, "HELPFUL")
            if secret(aura) then return nil end
            if not aura then
                if unknown then return nil end
                return false
            end
            if secret(aura.spellId) then unknown = true
            elseif aura.spellId == 27827 then return true end
        end
    end

    function helper:reset()
        reports = {}
        observed = {}
        witnessed, aliveUntil, lastState = false, nil, nil
    end

    -- Local-only fallback, never broadcast as a confirmed Restitution report.
    -- Called only during the existing bounded post-wipe monitoring window.
    local function observePriests()
        for _, info in pairs(observed) do info.readable = false end
        if InCombatLockdown() or (C_Secrets and C_Secrets.ShouldAurasBeSecret()) then return end
        local present = {}
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            local _, class = UnitClass(unit)
            if not secret(class) and class == "PRIEST" then
                local name = fullName(unit)
                if name then
                    present[name] = true
                    local connected, visible = UnitIsConnected(unit), UnitIsVisible(unit)
                    local ghost, dead = UnitIsGhost(unit), UnitIsDead(unit)
                    if reports[name] ~= nil or secret(connected) or not connected
                        or (not secret(ghost) and ghost) then
                        observed[name] = nil
                    elseif not secret(visible) and visible and not secret(ghost) and not secret(dead) then
                        local angel = hasAngel(unit)
                        local info = observed[name]
                        if angel == true then
                            observed[name] = { state = "angel", readable = true }
                            if not info or info.state ~= "angel" then
                                debugLog("Observed priest angel (unconfirmed): " .. name)
                            end
                        elseif angel == false and info then
                            if dead then
                                observed[name] = nil
                            else
                                if info.state == "angel" then
                                    info.state, info.untilTime = "alive", GetTime() + 7
                                    debugLog("Observed priest alive after angel: " .. name)
                                end
                                info.readable = true
                            end
                        end
                    end
                end
            end
        end
        for name in pairs(observed) do
            if not present[name] then observed[name] = nil end
        end
    end

    function helper:check(encounter)
        if encounter and channel() then observePriests() end
        local _, class = UnitClass("player")
        if class ~= "PRIEST" or not channel() then return end
        local known = C_SpellBook.IsSpellKnown(391124)
        if secret(known) or not known then return end
        local angel = hasAngel()
        local dead, ghost = UnitIsDead("player"), UnitIsGhost("player")
        if secret(dead) or secret(ghost) then return end
        local state = "none"
        if angel == true and not ghost then
            witnessed, aliveUntil = true, nil
            state = "angel"
        elseif angel == false and witnessed and not dead and not ghost then
            aliveUntil = aliveUntil or GetTime() + 7
            if GetTime() < aliveUntil then state = "alive" end
        elseif ghost or (angel == false and dead) then
            witnessed, aliveUntil = false, nil
        end
        -- During the pull we only collect evidence; send after ENCOUNTER_END.
        if not encounter then return end
        local name = fullName("player")
        if not name or state == lastState then return end
        lastState = state
        reports[name] = { state = state, untilTime = GetTime() + (state == "alive" and 7 or 30) }
        debugLog("Sending Restitution state: " .. state)
        C_ChatInfo.SendAddonMessage("SRBT_RESTITUTION", encounter .. ":" .. state, channel())
    end

    function helper:receive(message, distribution, sender, encounter)
        if not encounter or distribution ~= channel() or type(message) ~= "string" or #message > 40 then return end
        local id, state = message:match("^(%d+):(%a+)$")
        if tonumber(id) ~= encounter or (state ~= "angel" and state ~= "alive" and state ~= "none") then return end
        local unit, name = raidUnit(sender)
        if not unit or name == fullName("player") then return end
        local _, class = UnitClass(unit)
        if class ~= "PRIEST" then return end
        local previous = reports[name]
        -- Duplicate alive packets must not prolong the short post-revival message.
        if previous and previous.state == state then return end
        reports[name] = { state = state, untilTime = GetTime() + (state == "alive" and 7 or 30) }
        debugLog("Received Restitution state: " .. name .. " / " .. state)
    end

    function helper:warning()
        local angels, alive = {}, {}
        for name, report in pairs(reports) do
            local unit = raidUnit(name)
            if unit and UnitIsConnected(unit) and GetTime() < report.untilTime then
                local ghost, dead = UnitIsGhost(unit), UnitIsDead(unit)
                if not secret(ghost) and not ghost then
                    if report.state == "angel" then
                        angels[#angels + 1] = Ambiguate(name, "none")
                    elseif report.state == "alive" and not secret(dead) and not dead then
                        alive[#alive + 1] = Ambiguate(name, "none")
                    end
                end
            end
        end
        table.sort(angels)
        table.sort(alive)
        if #angels > 0 then
            return table.concat(angels, ", ") .. " — Restitution active.\nWait for the priest to revive!"
        elseif #alive > 0 then
            return table.concat(alive, ", ") .. " — alive!\nWait for resurrection."
        end
        -- Confirmed reports above always win. Never infer Restitution from angel form.
        local fallbackAngels, fallbackAlive = {}, {}
        for name, info in pairs(observed) do
            local unit = raidUnit(name)
            if reports[name] == nil and info.readable and unit then
                local connected, visible = UnitIsConnected(unit), UnitIsVisible(unit)
                local ghost, dead = UnitIsGhost(unit), UnitIsDead(unit)
                if not secret(connected) and connected and not secret(visible) and visible
                    and not secret(ghost) and not ghost then
                    if info.state == "angel" then
                        fallbackAngels[#fallbackAngels + 1] = Ambiguate(name, "none")
                    elseif not secret(dead) and not dead and GetTime() < info.untilTime then
                        fallbackAlive[#fallbackAlive + 1] = Ambiguate(name, "none")
                    end
                end
            end
        end
        table.sort(fallbackAngels)
        table.sort(fallbackAlive)
        if #fallbackAlive > 0 then
            return table.concat(fallbackAlive, ", ") .. " — alive!\nWait for resurrection."
        elseif #fallbackAngels > 0 then
            return table.concat(fallbackAngels, ", ") .. " — angel form detected.\nRevival not confirmed.", "DON'T RELEASE YET!"
        end
    end
    return helper
end
