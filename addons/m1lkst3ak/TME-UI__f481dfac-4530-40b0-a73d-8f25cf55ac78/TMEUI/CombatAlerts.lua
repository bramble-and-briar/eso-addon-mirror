-- Transient combat awareness HUD. No career or encounter data is saved.
local N=TMEUI
local s=N.safe
local X={alerts={},stats={}}
local function now() return s(GetFrameTimeSeconds) or 0 end
local function same(a,b) return b~=nil and a==b end
local function cfg() return N.saved end
local function clean(v) return tostring(v or ''):gsub('%^%a+','') end
local function alert(key,title,detail,priority,seconds)
 X.alerts[key]={title=title,detail=detail,priority=priority,ends=now()+seconds}
end
local function panel(name,w,h)
 local p=WINDOW_MANAGER:CreateTopLevelWindow(name);p:SetDimensions(w,h);p:SetHidden(true)
 local b=WINDOW_MANAGER:CreateControl(nil,p,CT_BACKDROP);b:SetAnchorFill(p);b:SetCenterColor(.025,.023,.020,.91);b:SetEdgeColor(.66,.51,.29,1);b:SetEdgeTexture('',1,1,1)
 local function line(y,size,height)
  local l=WINDOW_MANAGER:CreateControl(nil,p,CT_LABEL);l:SetAnchor(TOPLEFT,p,TOPLEFT,12,y);l:SetAnchor(TOPRIGHT,p,TOPRIGHT,-12,y);l:SetHeight(height);l:SetFont('$(BOLD_FONT)|'..size..'|soft-shadow-thick');l:SetColor(.94,.87,.72,1);l:SetVerticalAlignment(TEXT_ALIGN_CENTER);l:SetHorizontalAlignment(TEXT_ALIGN_CENTER);return l
 end
 return p,line(6,22,26),line(37,19,25)
end
local function power(kind)
 local k=_G['COMBAT_MECHANIC_FLAGS_'..kind] or _G['POWERTYPE_'..kind];if not k then return end
 local a,b=s(GetUnitPower,'player',k);if type(a)=='number' and type(b)=='number' and b>0 then return a/b end
end

local function combat(_,r,err,ability,graphic,action,source,st,target,tt,amount,pt,dt,log,sid,tid,id)
 local c=cfg();if not c or not c.enabled or not c.awareness or err then return end
 if not same(tt,COMBAT_UNIT_TYPE_PLAYER) or same(st,COMBAT_UNIT_TYPE_PLAYER) then return end
 if same(r,ACTION_RESULT_DOT_TICK) or same(r,ACTION_RESULT_DOT_TICK_CRITICAL) then
  local k=tostring(id or ability);local t=now();local last=X.stats[k];X.stats[k]=t
  if last and t-last<3 then alert('damage','REPEATED DAMAGE',clean(ability)..' • check positioning',70,2) end
 elseif same(r,ACTION_RESULT_STUNNED) or same(r,ACTION_RESULT_KNOCKBACK) then alert('cc','CONTROLLED','Break free if needed',95,2) end
end
local function tick()
 local c=cfg();if not c or not X.hud then return end
 local t=now();local preview=(N.previewUntil or 0)>t
 local visible=c.enabled and c.awareness and (N.gameplay() or preview)
 if not visible then X.hud:SetHidden(true);X.alerts={};X.stats={};return end
 if preview then alert('preview','LOW RESOURCE ALERT','Magicka 15% left',110,1) end
 if s(IsUnitInCombat,'player') then
  for _,k in ipairs({'HEALTH','MAGICKA','STAMINA'}) do local p=power(k);local key='power'..k;if p and p<=c.low/100 then alert(key,'LOW RESOURCE ALERT',k..'  '..math.floor(p*100)..'% left',k=='HEALTH' and 100 or 45,1) else X.alerts[key]=nil end end
 else for k in pairs(X.alerts) do if k~='preview' then X.alerts[k]=nil end end;X.stats={} end
 local best;for k,e in pairs(X.alerts) do if e.ends<=t then X.alerts[k]=nil elseif not best or e.priority>best.priority then best=e end end
 for k,v in pairs(X.stats) do if t-v>5 then X.stats[k]=nil end end
 X.hud:ClearAnchors();X.hud:SetAnchor(CENTER,GuiRoot,CENTER,c.alertX,c.alertY);X.hud:SetScale(c.alertScale/100);X.hud:SetHidden(not best);if best then X.title:SetText(best.title);X.detail:SetText(best.detail) end
end
function N.initAlerts()
 local ok,a,b,c=pcall(panel,'TMEUICombatAlert',460,72);if not ok then return end;X.hud,X.title,X.detail=a,b,c
 if EVENT_COMBAT_EVENT then EVENT_MANAGER:RegisterForEvent('TMEUIAlertCombat',EVENT_COMBAT_EVENT,function(...)pcall(combat,...)end) end
 EVENT_MANAGER:RegisterForUpdate('TMEUIAlertTick',250,function() local ok=pcall(tick);if not ok then X.hud:SetHidden(true);EVENT_MANAGER:UnregisterForUpdate('TMEUIAlertTick') end end)
 if EVENT_PLAYER_DEACTIVATED then EVENT_MANAGER:RegisterForEvent('TMEUIAlertZone',EVENT_PLAYER_DEACTIVATED,function()X.alerts={};X.stats={};X.hud:SetHidden(true) end) end
end
