-- Character-local combat camera, with bounded confirmation retries.
local N=ESOHardcore
local s=N.safe
local C={status='Waiting for gameplay',attempts=0}
N.combatCamera=C
local function cfg() return N.hardcore and N.hardcore.saved end
local function clock() return s(GetFrameTimeSeconds) or 0 end
local function perspective()
 local distance=s(GetCameraDistance)
 C.distance=distance
 if type(distance)~='number' or distance<0 then return nil end
 return distance<=0.001
end
local function safeContext()
 if not N.gameplay() then return false,'Waiting for gameplay scene' end
 if s(IsMounted)==true or s(IsUnitDead,'player')==true or s(IsGameCameraUIModeActive)==true or s(ZO_Dialogs_IsShowingDialog)==true or s(IsPlayerInSiegeWeapon)==true or s(IsUsingSiegeWeapon)==true then return false,'Waiting for safe camera context' end
 local interaction=s(GetInteractionType)
 if type(interaction)=='number' and interaction~=(INTERACTION_NONE or 0) then return false,'Waiting for interaction to finish' end
 return true
end
function C.enabled() local a=cfg();return a and a.combatCamera~=false end
function C.toggle() local a=cfg();if a then a.combatCamera=not C.enabled() end end
function C.info() return C.status..' | Distance: '..tostring(C.distance)..' | Combat: '..tostring(C.combat)..' | Attempts: '..C.attempts end
local function request(first,t)
 local current=perspective()
 if current==first then C.status=first and 'First person confirmed' or 'Third person confirmed';return true end
 if t<(C.nextAttempt or 0) then return false end
 if C.attempts>=3 then C.status='Camera switch not confirmed; console API may be restricted';return false end
 if type(ToggleGameCameraFirstPerson)~='function' then C.status='Camera toggle API unavailable';return false end
 -- If distance is unavailable, issue one edge-triggered toggle only, never blindly repeat.
 if current==nil and C.attempts>0 then return false end
 C.attempts=C.attempts+1;C.nextAttempt=t+1.2
 local ok,err=pcall(ToggleGameCameraFirstPerson)
 if not ok then C.status='Camera rejected: '..tostring(err);return false end
 C.status=first and 'First person requested' or 'Third person requested'
 if current==nil then C.status=C.status..' (distance unavailable)';return true end
 return false
end
function C.tick()
 local a=cfg();if not a then return end
 local combat=C.eventCombat;if combat==nil then combat=s(IsUnitInCombat,'player') end
 C.combat=combat
 if combat==nil then C.status='Combat state unavailable';return end
 local desired=C.enabled() and N.visualActive() and combat==true
 local t=clock()
 if desired then
  C.leaveAt=nil
  if not C.engaged then C.engaged=true;C.done=false;C.attempts=0;C.nextAttempt=0;C.owned=false end
  if C.done then return end
  local safe,why=safeContext();if not safe then C.status=why;return end
  local before=perspective();local previousAttempts=C.attempts
  C.done=request(true,t)
  if C.attempts>previousAttempts and before~=true then C.owned=true end
  return
 end
 if not C.engaged then C.status=not C.enabled() and 'Disabled' or not N.visualActive() and 'Immersion not active' or 'Ready — awaiting combat';return end
 if not C.leaveAt then C.leaveAt=t;C.attempts=0;C.nextAttempt=0 end
 if t-C.leaveAt<2 then return end
 local safe,why=safeContext();if not safe then C.status=why;return end
 if not C.owned or request(false,t) or C.attempts>=3 then C.engaged=false;C.owned=false;C.leaveAt=nil end
end
function C.reset() C.engaged=false;C.owned=false;C.done=false;C.leaveAt=nil;C.eventCombat=nil;C.attempts=0;C.nextAttempt=0 end
function C.init()
 EVENT_MANAGER:RegisterForUpdate('ESOHCCombatCamera',200,function() local ok,err=pcall(C.tick);if not ok then C.status='Camera error: '..tostring(err) end end)
 if EVENT_PLAYER_COMBAT_STATE then EVENT_MANAGER:RegisterForEvent('ESOHCCombatCameraState',EVENT_PLAYER_COMBAT_STATE,function(_,inCombat) C.eventCombat=inCombat end) end
 if EVENT_PLAYER_DEACTIVATED then EVENT_MANAGER:RegisterForEvent('ESOHCCombatCamera',EVENT_PLAYER_DEACTIVATED,C.reset) end
end
