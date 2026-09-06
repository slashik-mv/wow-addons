function createBossModCompatibility(addonName, frame)
    local compatibility = {}

    function compatibility:getDBMBreakSeconds(message)
        -- DBM's public break sync is the BT command on its D5 addon-message prefix.
        local fields = { strsplit("\t", message) }
        for i = 1, #fields - 1 do
            if fields[i] == "BT" then
                return tonumber(fields[i + 1])
            end
        end
    end

    function compatibility:registerBigWigsCompatibility()
        local loader = _G.BigWigsLoader
        if not loader or type(loader.RegisterMessage) ~= "function" then return end

        loader.RegisterMessage(addonName, "BigWigs_StartBreak", function(_, _, seconds)
            frame:showCompatibleBreak(seconds)
        end)
        loader.RegisterMessage(addonName, "BigWigs_StopBreak", function()
            frame:hideBreak()
        end)
    end

    return compatibility
end
