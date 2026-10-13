-- Run from the addon directory with Lua 5.1+. WoW APIs are mocked.
local frames, timers = {}, {}
local combat, now, known, cooldown = false, 100, true, 0
local methods = {}
local function object(secure)
 return setmetatable({scripts={},events={},shown=false,secure=secure,attrs={},x=500,y=400}, {__index=methods})
end
for _,k in ipairs({'SetSize','SetFrameStrata','SetClampedToScreen','SetMovable','RegisterForDrag','SetWidth','SetFont','SetBackdrop','SetBackdropColor','SetBackdropBorderColor','RegisterForClicks','SetMotionScriptsWhileDisabled','StartMoving','StopMovingOrSizing','SetAutoFocus','SetMaxBytes','ClearFocus'}) do methods[k]=function() end end
local function protect(s) assert(not (s.secure and combat),'protected mutation in combat') end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:RegisterEvent(k) self.events[k]=true end
function methods:SetText(v) self.content=v end
function methods:GetFont() return 'font',60,'' end
function methods:GetCenter() return self.x,self.y end
function methods:GetEffectiveScale() return 1 end
function methods:GetBottom() return 350 end
function methods:CreateFontString() return object(false) end
function methods:EnableMouse(v) self.mouse=v end
function methods:SetEnabled(v) protect(self); self.enabled=v end
function methods:SetAttribute(k,v) protect(self); self.attrs[k]=v end
function methods:ClearAllPoints() protect(self) end
function methods:SetPoint(point,parent,relative,x,y) protect(self); if type(x)=='number' then self.x,self.y=500+x,400+y end end
function methods:Show() protect(self); self.shown=true end
function methods:Hide() protect(self); self.shown=false end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
UIParent=object(false)
function CreateFrame(_,_,_,template) local f=object(template and template:find('SecureActionButtonTemplate')); frames[#frames+1]=f; return f end
function InCombatLockdown() return combat end
function GetTime() return now end
function RegisterStateDriver(button) button.driver=true end
C_Timer={NewTimer=function(_,cb) local t={cb=cb,Cancel=function(s) s.cancelled=true end}; timers[#timers+1]=t; return t end, After=function() end}
Enum={SpellBookSpellBank={Player=1}}
C_SpellBook={IsSpellInSpellBook=function() return known end}
C_Spell={GetSpellCooldown=function() return {startTime=now,duration=cooldown} end}
C_ChallengeMode={GetMapTable=function() return {399} end,GetMapUIInfo=function() return 'Ruby',399,0,0,0,2521 end}
C_LFGList={GetActivityInfoTable=function(id) if id==1 then return {mapID=2521,isMythicPlusActivity=true} elseif id==2 then return {mapID=2521,isMythicPlusActivity=false} end end,GetSearchResultInfo=function() return nil end}
local function event(name,...)
 for _,f in ipairs(frames) do if f.events[name] then f.scripts.OnEvent(f,name,...) end end
end
for _,file in ipairs({'Settings.lua','DungeonTeleports.lua','DungeonTeleportHelper.lua','PrintHelper.lua','SlashikWhichDungeonInvite.lua'}) do assert(loadfile(file))('SlashikWhichDungeonInvite',{}) end
assert(getSetting().warningX==0)
assert(getInviteDungeonMapID(1)==399 and getInviteDungeonMapID(2)==nil and getInviteDungeonMapID(3)==nil)
event('PLAYER_LOGIN')
local button
for _,f in ipairs(frames) do if f.secure then button=f end end
assert(button and not button.shown)
printWarning('Ruby',1)
assert(button.shown and button.enabled and button.attrs.spell==393256)
known=false; event('SPELLS_CHANGED'); assert(not button.enabled)
known=true; cooldown=30; event('SPELL_UPDATE_COOLDOWN'); assert(not button.enabled)
cooldown=0; event('SPELL_UPDATE_COOLDOWN'); assert(button.enabled)
local old=timers[#timers]; printWarning('Another',1); assert(old.cancelled)
startInviteWarningPreview(); assert(timers[#timers].cancelled and not button.shown)
local warning
for _,f in ipairs(frames) do if f.caption then warning=f end end
assert(warning.mouse and warning.shown)
warning.scripts.OnDragStart(warning); warning.x,warning.y=620,450; warning.scripts.OnDragStop(warning)
assert(getSetting().warningX==120 and getSetting().warningY==50)
stopInviteWarningPreview(); assert(not warning.mouse and not warning.shown)
printWarning('Moved',1); assert(warning.x==620 and warning.y==450 and button.shown)
combat=true; event('PLAYER_REGEN_DISABLED'); timers[#timers].cb()
combat=false; event('PLAYER_REGEN_ENABLED'); assert(not button.shown)
startInviteWarningPreview(); combat=true; event('PLAYER_REGEN_DISABLED'); assert(not warning.shown and not warning.mouse)
combat=false; resetInviteWarningPosition(); assert(getSetting().warningX==0 and getSetting().warningY==0)
event('LFG_LIST_APPLICATION_STATUS_UPDATED',42,'inviteaccepted',nil,'Missing listing')
assert(not button.shown)
print('PASS: mapping, spell ownership/cooldowns, repeated invites, dragging/save/reset, previews, combat expiry, missing listings')
