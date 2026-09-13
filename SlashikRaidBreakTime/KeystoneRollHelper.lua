-- Use WoW's public /roll result, not a separate local random-number generator.
function createKeystoneRollHelper()
    local pending
    local timeout
    local events = CreateFrame("Frame")
    local helper = {}

    local function clear()
        pending = nil
        events:UnregisterEvent("CHAT_MSG_SYSTEM")
        if timeout then timeout:Cancel(); timeout = nil end
    end

    -- Build a pattern from the localized roll message, including positional formats.
    local function rollPattern()
        local formatText = RANDOM_ROLL_RESULT
        local pattern, fields, offset, argument = "^", {}, 1, 0
        while offset <= #formatText do
            local tail = formatText:sub(offset)
            local token, kind = tail:match("^(%%[sd])")
            local position, positionalKind = tail:match("^%%(%d+)%$([sd])")
            if position then
                token = "%" .. position .. "$" .. positionalKind
                kind = positionalKind
            elseif token then
                kind = token:sub(-1)
            end
            if token then
                argument = argument + 1
                fields[#fields + 1] = tonumber(position) or argument
                pattern = pattern .. (kind == "s" and "(.-)" or "(%d+)")
                offset = offset + #token
            else
                local char = formatText:sub(offset, offset)
                pattern = pattern .. char:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
                offset = offset + 1
            end
        end
        return pattern .. "$", fields
    end

    events:SetScript("OnEvent", function(_, _, message)
        if not pending then return end
        local captures = { message:match(pending.pattern) }
        local values = {}
        for i, value in ipairs(captures) do values[pending.fields[i]] = value end
        local name, result, low, high = values[1], tonumber(values[2]), tonumber(values[3]), tonumber(values[4])
        local player, realm = UnitFullName("player")
        local full = player .. "-" .. ((realm and realm ~= "") and realm or GetNormalizedRealmName())
        if name ~= player and name ~= full then return end
        if low ~= 1 or high ~= #pending.keys or not result or not pending.keys[result] then return end
        local key, callback = pending.keys[result], pending.callback
        clear()
        callback(key)
    end)

    function helper:start(keys, callback)
        if pending then return end
        if #keys == 0 then
            print("SlashikRaidBreakTime: No available keys to roll. Try Refresh first.")
            return
        end
        local pattern, fields = rollPattern()
        pending = { keys = keys, callback = callback, pattern = pattern, fields = fields }
        events:RegisterEvent("CHAT_MSG_SYSTEM")
        timeout = C_Timer.NewTimer(10, function()
            clear()
            print("SlashikRaidBreakTime: No roll result received. Please try again.")
        end)
        RandomRoll(1, #keys)
    end

    helper.cancel = clear
    function helper:isPending() return pending ~= nil end
    return helper
end
