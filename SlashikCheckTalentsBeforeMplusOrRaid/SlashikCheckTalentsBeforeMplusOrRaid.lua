local _, addon = ...
local getSetting = addon.getSetting
local IsInMythicPlus = addon.IsInMythicPlus
local IsInRaid = addon.IsInRaid
local IsInDelve = addon.IsInDelve
local checkMythicPlus = addon.checkMythicPlus
local checkRaid = addon.checkRaid
local checkDelve = addon.checkDelve

local f = CreateFrame("Frame")
f:RegisterEvent("READY_CHECK")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")

f:SetScript("OnEvent", function(_, event)
    if event == "READY_CHECK" then
        if IsInMythicPlus() and getSetting().enabledM == true then
            checkMythicPlus()
        elseif IsInRaid() and getSetting().enabledRaid == true then
            checkRaid()
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        if IsInDelve() and getSetting().enabledDelve == true then
            checkDelve()
        end
    end
end)
