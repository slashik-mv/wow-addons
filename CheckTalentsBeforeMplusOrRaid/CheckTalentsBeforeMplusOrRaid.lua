print("Hello CheckTalentsBeforeMplusOrRaid!")

local specID = GetSpecializationInfo(GetSpecialization())
local configID = C_ClassTalents.GetActiveConfigID()

if not configID then return end

local loadoutIDs = C_ClassTalents.GetLoadoutIDsForConfig(configID)

for _, loadoutID in ipairs(loadoutIDs) do
    local info = C_ClassTalents.GetLoadoutInfo(loadoutID)
    if info then
        print(info.isActive and "► ACTIVE:" or "  ", info.name)
    end
end