-- Return recruitment text for a standard five-player dungeon group.
-- Unknown roles and raids are excluded rather than guessing who is needed.
function getMissingPartyRolesText()
    if IsInRaid() then return nil end

    local missing = { TANK = 1, HEALER = 1, DAMAGER = 3 }
    local partyCount = GetNumSubgroupMembers()
    if partyCount >= 4 then return nil end

    for i = 0, partyCount do
        local unit = i == 0 and "player" or ("party" .. i)
        local role = UnitGroupRolesAssigned(unit)
        -- Solo players usually have no assigned group role; use their active spec.
        if partyCount == 0 and missing[role] == nil then
            local specialization = GetSpecialization()
            if specialization then role = GetSpecializationRole(specialization) end
        end
        if missing[role] == nil then return nil end
        missing[role] = missing[role] - 1
        -- An overfilled role makes a simple recruitment message misleading.
        if missing[role] < 0 then return nil end
    end

    local parts = {}
    for _, entry in ipairs({ { "TANK", "tank" }, { "HEALER", "heal" }, { "DAMAGER", "dps" } }) do
        local count = missing[entry[1]]
        if count > 0 then
            parts[#parts + 1] = string.format("%dx %s", count, entry[2])
        end
    end
    if #parts > 0 then return "LF " .. table.concat(parts, ", ") end
end
