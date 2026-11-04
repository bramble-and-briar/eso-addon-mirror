-- Jesus de Platre - Multi Enemy Taunt Tracker v0.6.2
-- A private HUD, never uses group markers.  Events are keyed ONLY by unitId.
-- No guessing a unique enemy from a shared display name.
local A = "JDP_MultiTaunt"
local TAUNT_ID = 38254 -- taunt debuff ID, not the skill casting ID
local MAX_TRACK = 40
local MAX_ROWS = 8
local TICK_MS = 250 -- timers and expiry display; effects use event callbacks
local settings, window, title, subtitle, rows = nil,nil,nil,nil,{}
local tracked = {} -- [unitId] = { name, expires, owner, updated, expiredAt }
local samples = {effect=0, combat=0, combatTaunt=0, noId=0, target=0, last="none"}
local demo = false
local defaults = {enabled=true, x=410, y=-140, locked=false, alertAt=3, maxRows=8, showExpired=true}
local function clock() return GetFrameTimeSeconds() end
local function say(s) d("|c66CCFF[JDP Multi]|r "..s) end
local colors={mine={0.2,0.95,0.35},other={0.28,0.62,1},unknown={1,0.77,0.22},expired={1,0.22,0.22}}
local function timeLabel(secs) return string.format("%.1fs",math.max(0,secs)) end
local function safeName(name)
  if type(name)~="string" or name=="" then return "Enemy" end
  if zo_strformat then return zo_strformat("<<1>>",name) end
  return name
end
local function updateEntry(id,name,endsAt,owner,origin)
  if type(id)~="number" or id==0 then samples.noId=samples.noId+1;return end
  local t=clock()
  if type(endsAt)~="number" or endsAt<=t then return end
  local e=tracked[id] or {}
  e.id=id;e.name=safeName(name or e.name);e.expires=endsAt
  e.owner=owner or "unknown";e.updated=t;e.expiredAt=nil;e.origin=origin
  tracked[id]=e
end
local function clearEntry(id)
  local e=tracked[id]
  if e then e.expires=clock();e.expiredAt=clock();e.owner="expired" end
end
-- sourceType describes the caster of the taunt effect, not its target.
-- COMBAT_UNIT_TYPE_PLAYER is confidently ours; other source types may be
-- ambiguous, so unknown stays amber rather than falsely claiming OTHER.
local function ownerFromSource(sourceType)
  if sourceType==COMBAT_UNIT_TYPE_PLAYER then return "mine" end
  if COMBAT_UNIT_TYPE_GROUP and sourceType==COMBAT_UNIT_TYPE_GROUP then return "other" end
  return "unknown"
end
local function onEffect(_,changeType,_,effectName,unitTag,beginTime,endTime,_,_,_,_,_,_,unitName,unitId,abilityId,sourceType)
  if abilityId~=TAUNT_ID then return end
  samples.effect=samples.effect+1
  samples.last="effect id="..tostring(unitId).." change="..tostring(changeType).." source="..tostring(sourceType)
  if not unitId or unitId==0 then samples.noId=samples.noId+1;return end
  if changeType==EFFECT_RESULT_FADED then
    clearEntry(unitId)
  elseif changeType==EFFECT_RESULT_GAINED or changeType==EFFECT_RESULT_UPDATED or changeType==EFFECT_RESULT_FULL_REFRESH or changeType==EFFECT_RESULT_TRANSFER then
    updateEntry(unitId,unitName,endTime,ownerFromSource(sourceType),"effect")
  end
end
-- Combat events supplement identification and diagnostics. They are not
-- sufficient to assert an active taunt timer: skill IDs differ from debuff ID.
local function onCombat(_,result,isError,abilityName,_,_,sourceName,sourceType,targetName,targetType,hitValue,powerType,damageType,logged,sourceUnitId,targetUnitId,abilityId)
  if not targetUnitId or targetUnitId==0 then return end
  if abilityId ~= TAUNT_ID then return end
  samples.combat=samples.combat+1
  samples.combatTaunt=samples.combatTaunt+1
  samples.last="combat target="..tostring(targetUnitId).." result="..tostring(result).." source="..tostring(sourceType)
  local e=tracked[targetUnitId]
  if e then e.name=safeName(targetName or e.name);e.updated=clock() end
end
-- Cross-check the reticle target with GetUnitBuffInfo: this is the most
-- trustworthy owner signal, particularly when effect sourceType is unknown.
local function sampleReticle()
  if not DoesUnitExist("reticleover") or IsUnitDead("reticleover") or not IsUnitAttackable("reticleover") then return end
  if type(GetUnitId)~="function" then return end
  local id=GetUnitId("reticleover")
  if not id or id==0 then return end
  samples.target=samples.target+1
  local name=GetUnitName("reticleover")
  for i=1,(GetNumBuffs("reticleover") or 0) do
    local _,_,endsAt,_,_,_,_,_,_,_,abilityId,_,castByPlayer=GetUnitBuffInfo("reticleover",i)
    if abilityId==TAUNT_ID then
      local owner=castByPlayer==true and "mine" or (castByPlayer==false and "other" or "unknown")
      updateEntry(id,name,endsAt,owner,"reticle")
      return
    end
  end
  -- If the target used to have a taunt and no longer does, mark it expired.
  -- We do not create a new red row for an enemy with no taunt history.
  if tracked[id] and tracked[id].expires>clock() then clearEntry(id) end
end
local function makeLabel(parent,font,x,y,w,h)
  local l=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
  l:SetFont(font);l:SetDimensions(w,h);l:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
  return l
end
local function createUI()
  window=WINDOW_MANAGER:CreateTopLevelWindow("JDPMultiTauntPanel")
  window:SetDimensions(345,62+MAX_ROWS*31)
  window:SetAnchor(CENTER,GuiRoot,CENTER,settings.x,settings.y)
  window:SetClampedToScreen(true)
  window:SetDrawLayer(DL_OVERLAY);window:SetDrawTier(DT_HIGH)
  window:SetMovable(true);window:SetMouseEnabled(true)
  window:SetHandler("OnMouseDown",function(self,button) if not settings.locked and button==MOUSE_BUTTON_INDEX_LEFT then self:StartMoving() end end)
  window:SetHandler("OnMouseUp",function(self,button)
    if button==MOUSE_BUTTON_INDEX_LEFT and not settings.locked then
      self:StopMovingOrResizing()
      local left,top=self:GetLeft(),self:GetTop()
      local parentW,parentH=GuiRoot:GetDimensions()
      settings.x=math.floor(left+345/2-parentW/2)
      settings.y=math.floor(top+window:GetHeight()/2-parentH/2)
    end
  end)
  local bg=WINDOW_MANAGER:CreateControl(nil,window,CT_BACKDROP)
  bg:SetAnchorFill(window);bg:SetCenterColor(0.025,0.04,0.07,0.84);bg:SetEdgeColor(0.26,0.36,0.45,0.95)
  if bg.SetEdgeTexture then bg:SetEdgeTexture("",1,1,1,0) end
  -- A dedicated drag handle avoids guessing which child receives mouse clicks.
  local dragHandle=WINDOW_MANAGER:CreateControl(nil,window,CT_CONTROL)
  dragHandle:SetAnchor(TOPLEFT,window,TOPLEFT,0,0)
  dragHandle:SetDimensions(345,55)
  dragHandle:SetMouseEnabled(true)
  dragHandle:SetHandler("OnMouseDown",function(_,button)
    if not settings.locked and button==MOUSE_BUTTON_INDEX_LEFT then window:StartMoving() end
  end)
  dragHandle:SetHandler("OnMouseUp",function(_,button)
    if button==MOUSE_BUTTON_INDEX_LEFT and not settings.locked then
      window:StopMovingOrResizing()
      local left,top=window:GetLeft(),window:GetTop()
      local parentW,parentH=GuiRoot:GetDimensions()
      settings.x=math.floor(left+window:GetWidth()/2-parentW/2)
      settings.y=math.floor(top+window:GetHeight()/2-parentH/2)
    end
  end)
  title=makeLabel(window,"ZoFontGameBold",11,8,258,24)
  title:SetColor(0.9,0.96,1,1);title:SetText("JESUS DE PLATRE  |  MULTI TAUNT")
  local donationLink=makeLabel(window,"ZoFontGameBold",275,9,58,24)
  donationLink:SetText("Donate")
  donationLink:SetColor(0.45,0.88,1,1)
  donationLink:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  donationLink:SetMouseEnabled(true)
  donationLink:SetHandler("OnMouseUp",function(_,button)
    if button==MOUSE_BUTTON_INDEX_LEFT and type(JDPDonateShow)=="function" then JDPDonateShow() end
  end)
  subtitle=makeLabel(window,"ZoFontGame",11,32,323,24)
  subtitle:SetColor(0.73,0.79,0.84,1)
  for i=1,MAX_ROWS do
    local panel=WINDOW_MANAGER:CreateControl(nil,window,CT_CONTROL)
    panel:SetDimensions(323,29);panel:SetAnchor(TOPLEFT,window,TOPLEFT,11,57+(i-1)*31)
    local fill=WINDOW_MANAGER:CreateControl(nil,panel,CT_BACKDROP)
    fill:SetAnchorFill(panel);fill:SetCenterColor(0.09,0.12,0.17,0.85);fill:SetEdgeColor(0.09,0.12,0.17,0)
    local name=makeLabel(panel,"ZoFontGame",8,3,191,24);name:SetColor(1,1,1,1)
    local stat=makeLabel(panel,"ZoFontGameBold",200,3,60,24)
    local timer=makeLabel(panel,"ZoFontGameBold",260,3,57,24);timer:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    rows[i]={p=panel,name=name,stat=stat,timer=timer}
  end
end
local function demoEntries()
  local t=clock()
  return {
    {name="Bloodfiend A",owner="mine",expires=t+12.8},
    {name="Bloodfiend B",owner="other",expires=t+8.4},
    {name="Bloodfiend C",owner="expired",expires=t-0.1},
  }
end
local function tick()
  if not window or not settings.enabled then if window then window:SetHidden(true) end;return end
  -- Reticle buffs can update without a reticle-target event; sample at a
  -- slower cadence only while an attackable reticle target is present.
  if not demo and DoesUnitExist("reticleover") then sampleReticle() end
  local t=clock()
  local active={}
  local count=0
  if demo then active=demoEntries() else
    for id,e in pairs(tracked) do
      count=count+1
      if e.expires<=t and not e.expiredAt then e.expiredAt=t;e.owner="expired" end
      if e.expiredAt and t-e.expiredAt>4 then tracked[id]=nil
      elseif (e.expires>t or settings.showExpired) then active[#active+1]=e end
    end
    if count>MAX_TRACK then
      local oldest,oldT
      for id,e in pairs(tracked) do if not oldT or e.updated<oldT then oldest=id;oldT=e.updated end end
      if oldest then tracked[oldest]=nil end
    end
    table.sort(active,function(a,b)
      if a.owner=="expired" and b.owner~="expired" then return false end
      if b.owner=="expired" and a.owner~="expired" then return true end
      return a.expires<b.expires
    end)
  end
  local visible=math.min(settings.maxRows,#active)
  subtitle:SetText(demo and "DEMO | Example entries only" or string.format("%d active / %d listed | /jdptaunt help",(function() local n=0 for _,e in ipairs(active) do if e.expires>t then n=n+1 end end return n end)(),visible))
  for i,row in ipairs(rows) do
    local e=active[i]
    if i>settings.maxRows or not e then row.p:SetHidden(true)
    else
      row.p:SetHidden(false)
      local rem=math.max(0,e.expires-t)
      local state=rem<=0 and "expired" or e.owner
      local c=colors[state] or colors.unknown
      local blink=(state=="mine" and rem<=settings.alertAt and math.floor(t*4)%2==0)
      row.name:SetText(string.format("%d. %s",i,e.name))
      row.stat:SetText(state=="mine" and "YOU" or state=="other" and "OTHER" or state=="expired" and "EXPIRED" or "? OWNER")
      row.timer:SetText(state=="expired" and "TAUNT!" or timeLabel(rem))
      row.stat:SetColor(c[1],c[2],c[3],blink and 0.2 or 1)
      row.timer:SetColor(c[1],c[2],c[3],blink and 0.2 or 1)
    end
  end
  window:SetHeight(62+math.max(1,visible)*31)
  window:SetHidden(false)
end
local function command(cmd)
  local args={};for s in string.gmatch(string.lower(cmd or ""),"%S+") do args[#args+1]=s end
  local k,v=args[1],args[2]
  if k=="on" or k=="off" then settings.enabled=(k=="on");say("Panel "..k)
  elseif k=="demo" then demo=(v~="off");say("Demo "..(demo and "on" or "off"))
  elseif k=="clear" then tracked={};say("Tracking cleared")
  elseif k=="lock" then settings.locked=(v~="off");say("Drag lock "..tostring(settings.locked))
  elseif k=="move" then
    local dx,dy=tonumber(v),tonumber(args[3])
    if dx and dy and dx>=-2000 and dx<=2000 and dy>=-2000 and dy<=2000 then
      settings.x=settings.x+math.floor(dx);settings.y=settings.y+math.floor(dy)
      window:ClearAnchors();window:SetAnchor(CENTER,GuiRoot,CENTER,settings.x,settings.y)
      say("Moved by "..dx..", "..dy)
    else say("Usage: /jdptaunt move 100 0 (right), or move 0 100 (down)") end
  elseif k=="resetpos" then
    settings.x=defaults.x;settings.y=defaults.y
    window:ClearAnchors();window:SetAnchor(CENTER,GuiRoot,CENTER,settings.x,settings.y)
    say("Panel position reset")
  elseif k=="alert" then local n=tonumber(v);if n and n>=1 and n<=10 then settings.alertAt=n;say("Warning at "..n.."s") else say("Use alert 1-10") end
  elseif k=="rows" then local n=tonumber(v);if n and n>=1 and n<=MAX_ROWS then settings.maxRows=math.floor(n);say("Rows="..settings.maxRows) else say("Use rows 1-8") end
  elseif k=="debug" then
    say(string.format("effect=%d; combat-taunt=%d; reticle=%d; noId=%d",samples.effect,samples.combatTaunt,samples.target,samples.noId))
    say("Last: "..samples.last.."; active tracked IDs="..tostring((function() local n=0 for _ in pairs(tracked) do n=n+1 end return n end)()))
    say("Taunt buff ID="..TAUNT_ID..". Combat event counts only match this debuff ID; other skill casts may not match.")
  elseif k=="help" or not k then
    say("/jdptaunt on | off | demo | demo off | debug | clear")
    say("/jdptaunt rows 1-8 | alert 1-10 | lock on/off | move X Y | resetpos")
    say("Drag the panel with your mouse when unlocked. Expired taunts stay red for 4 seconds.")
  else say("Unknown command: /jdptaunt help") end
  tick()
end
local function onLoaded(_,name)
  if name~="JesusDePlatre_PrivateMarker" then return end
  EVENT_MANAGER:UnregisterForEvent(A.."_load",EVENT_ADD_ON_LOADED)
  settings=ZO_SavedVars:NewAccountWide("JDPMultiTauntSaved",1,nil,defaults,GetWorldName())
  createUI()
  SLASH_COMMANDS["/jdptaunt"]=command
  EVENT_MANAGER:RegisterForEvent(A.."_effect",EVENT_EFFECT_CHANGED,onEffect)
  EVENT_MANAGER:AddFilterForEvent(A.."_effect",EVENT_EFFECT_CHANGED,REGISTER_FILTER_ABILITY_ID,TAUNT_ID)
  EVENT_MANAGER:RegisterForEvent(A.."_combat",EVENT_COMBAT_EVENT,onCombat)
  EVENT_MANAGER:AddFilterForEvent(A.."_combat",EVENT_COMBAT_EVENT,REGISTER_FILTER_ABILITY_ID,TAUNT_ID)
  EVENT_MANAGER:RegisterForEvent(A.."_target",EVENT_RETICLE_TARGET_CHANGED,function() sampleReticle(); tick() end)
  EVENT_MANAGER:RegisterForUpdate(A.."_tick",TICK_MS,tick)
end
EVENT_MANAGER:RegisterForEvent(A.."_load",EVENT_ADD_ON_LOADED,onLoaded)
