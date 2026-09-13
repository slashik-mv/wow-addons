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
