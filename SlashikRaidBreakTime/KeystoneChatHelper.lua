-- Called only by a guild row's Whisper button; keep the realm in the recipient.
function whisperGuildKeystoneOwner(name, mapID, level)
    if not IsInGuild() or type(name) ~= "string" or name == "" then return end
    if type(mapID) ~= "number" or type(level) ~= "number" or mapID <= 0 or level <= 0 then return end
    local dungeon = C_ChallengeMode.GetMapUIInfo(mapID)
    if not dungeon then return end
    local shortName = Ambiguate(name, "short")
    local message = string.format("Hi %s, would you like to run your +%d %s?", shortName, level, dungeon)
    C_ChatInfo.SendChatMessage(message, "WHISPER", nil, name)
end

-- Called directly by a Post button click to announce a known keystone in /g.
function postKeystoneToGuild(mapID, level)
    if not IsInGuild() then
        print("SlashikRaidBreakTime: Join a guild to post a keystone in guild chat.")
        return
    end
    if type(mapID) ~= "number" or type(level) ~= "number" then return end
    if mapID <= 0 or level <= 0 then return end
    local dungeon = C_ChallengeMode.GetMapUIInfo(mapID)
    if not dungeon then return end
    local message = string.format("%s +%d", dungeon, level)
    local recruitment = getMissingPartyRolesText()
    if recruitment then message = message .. " - " .. recruitment end
    C_ChatInfo.SendChatMessage(message, "GUILD")
end
