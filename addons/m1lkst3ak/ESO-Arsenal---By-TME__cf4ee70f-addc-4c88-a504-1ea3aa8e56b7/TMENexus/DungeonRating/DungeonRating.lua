ZO_CreateStringId("SI_BINDING_NAME_DUNGEON_BUDDY_TOGGLE_MENU", "Dungeon Buddy: Career & Settings")
ZO_CreateStringId("SI_BINDING_NAME_DUNGEON_BUDDY_OPEN_SETTINGS", "Dungeon Buddy: Open Settings")
ZO_CreateStringId("SI_BINDING_NAME_DUNGEON_BUDDY_OPEN_BOSS_DRAFT", "Dungeon Buddy: Open Prepared Boss Report")
ZO_CreateStringId("SI_BINDING_NAME_DUNGEON_BUDDY_PREPARE_BOSS_REPORT", "Dungeon Buddy: Prepare Boss Report (Radial)")
-- Dungeon Buddy (integrated v0.3)
-- Separate from Battle Ground Rating. Conservative event attribution.
local DR = {name="DungeonRating", version="2.0.1"}
local EM = EVENT_MANAGER
local function now() return GetFrameTimeSeconds and GetFrameTimeSeconds() or 0 end
local function bool(v) return v==true end
local function say(s) if d then d("[Dungeon Buddy] "..tostring(s)) end end
local function safe(fn, ...) if type(fn)=="function" then local ok,v=pcall(fn,...); if ok then return v end end end
local function player() return safe(GetUnitDisplayName,"player") or safe(GetUnitName,"player") or "Player" end
local function isOwnName(name)
  if not name or name=="" then return false end
  return name==safe(GetUnitName,"player") or name==safe(GetUnitDisplayName,"player") or name==safe(GetRawUnitName,"player")
end
local function zone() return safe(GetUnitZone,"player") or "Unknown dungeon" end
local function role()
  local r=safe(GetSelectedLFGRole)
  if r==LFG_ROLE_HEAL or r==LFG_ROLE_HEALER then return "HEAL" end
  if r==LFG_ROLE_TANK then return "TANK" end
  if r==LFG_ROLE_DPS or r==LFG_ROLE_DAMAGE then return "DPS" end
  return "UNKNOWN"
end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function fmt(n) return string.format("%.0f",n or 0) end
local function clock(t) t=math.max(0,math.floor(t)); return string.format("%02d:%02d",math.floor(t/60),t%60) end
local defaults={learnedBuffs={},ultimateEffectIds={},observedAbilities={},settings={showHUD=true,showWorldHUD=true,showRollingEffects=true,showRefreshHighlights=true,showPace=true,showTrend=true,manualRole="AUTO",difficultyLabels=true,showBossHUD=true,autoReport=true,showPlayerCard=false,previewWindows=false,windowLayout={rollingBuff={x=100,y=420,scale=100},rollingDebuff={x=1350,y=420,scale=100},world={x=200,y=180,scale=100},live={x=200,y=180,scale=100},boss={x=720,y=180,scale=100},report={x=350,y=190,scale=100},career={x=330,y=150,scale=100},playerCard={x=220,y=90,scale=100}}},history={},players={},records={},ratings={HEAL=0,DPS=0,TANK=0},runs=0}
local S,run,hud,bossHUD,reportHUD,menu,playerCard
local worldHUD
local rollingPanels={}
local completedInstance=false
local lastBossReportContext=nil
local pendingBossReport=nil
local ultimateLastAt=0
local function characterKey() return tostring(safe(GetUnitName,"player") or "player") end
local state
local bossTags = {}
local function dungeonAbility(zoneId, abilityId)
  local registry=DungeonRatingEncounterData
  local curated=registry and registry[zoneId] and registry[zoneId][abilityId]
  if curated then return curated end
  local intel=DungeonRatingSourceIntelligence
  local e=intel and intel.zoneEvents and intel.zoneEvents[zoneId] and intel.zoneEvents[zoneId][abilityId]
  if e and e.name and not e.name:find("Encounter event",1,true) then return {name=e.name,alert="ENCOUNTER",kind=e.kind} end
  local a=intel and intel.dungeonAbilityAnnotations and intel.dungeonAbilityAnnotations[abilityId]
  if a then return {name=a.note~="" and a.note or tostring(abilityId),alert="ABILITY",kind="unscoped"} end
  return nil
end
local function difficulty()
  -- No fabricated dungeon-specific rankings. Difficulty data can be populated in the registry.
  local z=safe(GetZoneId,safe(GetUnitZoneIndex,"player")) or safe(GetCurrentMapZoneId)
  local entry=DR.registry[z] or (DungeonRatingCatalog and DungeonRatingCatalog[(zone() or ""):lower()])
  local vet
  if type(ZO_GetEffectiveDungeonDifficulty)=="function" then
    vet=ZO_GetEffectiveDungeonDifficulty()==DUNGEON_DIFFICULTY_VETERAN
  elseif safe(IsUnitGrouped,"player") and type(IsGroupUsingVeteranDifficulty)=="function" then
    vet=safe(IsGroupUsingVeteranDifficulty)
  else
    vet=safe(IsUnitUsingVeteranDifficulty,"player")
  end
  local mode=vet and "Veteran" or "Normal"
  local tier=entry and ((mode=="Normal" and math.min(2,entry.tier)) or entry.tier)
  return tier and ("Tier "..tier.."/5") or "Unranked",mode,z
end
DR.registry={} -- keyed by verified zone IDs; no speculative boss IDs or tiers
DR.mechanics={} -- keyed by verified ability IDs, e.g. {alert="INTERRUPT", roles={...}}
local function grade(x)
  if x<5 then return "BAD" elseif x<10 then return "SUBPAR" elseif x<15 then return "AVERAGE"
  elseif x<20 then return "GOOD" elseif x<30 then return "GREAT" elseif x<40 then return "ELITE" else return "LEGENDARY" end
end
-- Identification registry. These are not required effects for any role.
-- Never manufacture an effect duration from this table.
local supportRegistry={
  ["Major Courage"]="buff",["Minor Courage"]="buff",["Major Slayer"]="buff",
  ["Major Evasion"]="buff",["Major Force"]="buff",["Major Heroism"]="buff",
  ["Minor Berserk"]="buff",["Minor Resolve"]="buff",["Empower"]="buff",
  ["Major Resolve"]="buff",["Minor Vulnerability"]="debuff",
  ["Major Vulnerability"]="debuff",["Major Breach"]="debuff",["Minor Breach"]="debuff",
  ["Minor Maim"]="debuff",
  ["Powerful Assault"]="buff",["Pillager's Profit"]="instant",
  ["Xoryn's Masterpiece"]="passive",["Pearlescent Ward"]="passive",
  ["Lucent Echoes"]="passive",["Crimson Oath's Rive"]="debuff",
  ["Z'en's Redress"]="debuff",["Roar of Alkosh"]="debuff",
  ["Elemental Catalyst"]="debuff",["Elemental Weakness"]="debuff",
  ["Martial Knowledge"]="debuff",["Spaulder of Ruin"]="passive",
  ["Symphony of Blades"]="instant",["Grand Rejuvenation"]="instant",
  ["Pearls of Ehlnofey"]="instant",["Cryptcannon Vestments"]="passive",
  ["Ozezan the Inferno"]="buff",["Archdruid Devyric"]="debuff",
  ["Nazaray"]="instant",["Drake's Rush"]="buff",["Turning Tide"]="debuff",
  ["Saxhleel Champion"]="buff",["Claw of Yolnahkriin"]="buff",
  ["Gossamer"]="buff",["Spell Power Cure"]="buff",
  ["Vestment of Olorime"]="buff",["Roaring Opportunist"]="buff",
  ["Master Architect"]="buff",["War Machine"]="buff",
  ["Aegis of Galenwe"]="buff",["Kinras's Wrath"]="buff",
}
local ultimateNames={
  ["The Unblinking Eye"]=true,["Gibbering Shield"]=true,["Vitalizing Glyphic"]=true,
  ["Dragonknight Standard"]=true,["Dragon Leap"]=true,["Magma Armor"]=true,
  ["Frozen Colossus"]=true,["Bone Goliath Transformation"]=true,["Reanimate"]=true,
  ["Death Stroke"]=true,["Consuming Darkness"]=true,["Soul Shred"]=true,
  ["Summon Storm Atronach"]=true,["Negate Magic"]=true,["Overload"]=true,
  ["Radial Sweep"]=true,["Nova"]=true,["Rite of Passage"]=true,
  ["Feral Guardian"]=true,["Secluded Grove"]=true,["Sleet Storm"]=true,
  ["Rapid Fire"]=true,["Elemental Storm"]=true,["Lacerate"]=true,
  ["Shield Wall"]=true,["Panacea"]=true,["Berserker Strike"]=true,
  ["Dawnbreaker"]=true,["Meteor"]=true,["Undo"]=true,
  ["War Horn"]=true,["Barrier"]=true,["Soul Strike"]=true,
  ["Blood Scion"]=true,["Werewolf Transformation"]=true,
}
local function isUltimateAbility(abilityId)
  if not abilityId then return false end
  local name=safe(GetAbilityName,tonumber(abilityId))
  if not name then return false end
  if ultimateNames[name] then return true end
  -- Morphs and localized names: ultimate action-slot detection is authoritative.
  return false
end
local function combatDuration()
  if not run then return 0 end
  return (run.combatSeconds or 0)+(run.combatStart and math.max(0,now()-run.combatStart) or 0)
end
-- Cast-driven duration coverage. Each ability has a deadline and accumulated
-- covered COMBAT seconds. Recasts extend/refresh that deadline, never double-count.
local function durationCoverageFlush(t)
  if not run or not run.combatStart then return end
  t=t or now()
  for _,bucket in pairs(run.durationCoverage or {}) do
    for _,e in pairs(bucket) do
      local from=e.lastAccounted or t
      if t>from then
        e.covered=(e.covered or 0)+math.max(0,math.min(t,e.expires or 0)-from)
      end
      e.lastAccounted=t
    end
  end
end
local function trackDuration(abilityId,kind,duration,name,sourceUltimate)
  if not run or not run.combatStart or not abilityId or not kind then return end
  duration=tonumber(duration)
  if not duration or duration<=0 or duration>600 then return end
  if kind~="buff" and kind~="debuff" and kind~="dot" then return end
  if sourceUltimate or isUltimateAbility(abilityId) then return end
  local bucket=run.durationCoverage[kind]
  local key=tostring(abilityId)
  local t=now()
  durationCoverageFlush(t)
  local e=bucket[key] or {covered=0,observed=true,name=name or key}
  e.expires=t+duration
  e.lastAccounted=t
  bucket[key]=e
  run.durationObserved=run.durationObserved or {}
  run.durationObserved[key]={kind=kind,duration=duration,name=name or key}
end
local function roleUptime(kind)
  if not run then return nil end
  local total=combatDuration()
  if total<=0 then return nil end
  local bucket=run.durationCoverage and run.durationCoverage[kind]
  if not bucket then return nil end
  local sum,n=0,0
  for _,e in pairs(bucket) do
    if e.observed then
      local covered=e.covered or 0
      if run.combatStart and e.lastAccounted then
        covered=covered+math.max(0,math.min(now(),e.expires or 0)-e.lastAccounted)
      end
      sum=sum+math.min(total,covered)
      n=n+1
    end
  end
  if n==0 then return nil end
  return clamp(100*sum/(total*n),0,100)
end
local function buffUptime() return roleUptime("buff") end
local function debuffUptime() return roleUptime("debuff") end
local function dotUptime()
  if not run or combatDuration()<=0 then return nil end
  if run.dotObserved then return clamp(100*((run.dotSeconds or 0)+(run.combatStart and run.lastDotTick and math.min(2,math.max(0,now()-run.lastDotTick)) or 0))/combatDuration(),0,100) end
  if (run.damageEvents or 0)>0 then return 0 end
  return nil
end
local function targetUptime()
  if not run or combatDuration()<=0 or (run.damageEvents or 0)==0 then return nil end
  local seconds=run.targetSeconds or 0
  if run.combatStart and run.lastTargetHit then
    seconds=seconds+math.min(2,math.max(0,now()-run.lastTargetHit))
  end
  return clamp(100*seconds/combatDuration(),0,100)
end
local function closeUptimeSegment(entry)
  if entry and entry.since then
    entry.seconds=(entry.seconds or 0)+math.max(0,now()-entry.since)
    entry.since=nil
  end
end
local function targetGrade(p)
  if not p then return "UNAVAILABLE" end
  if p>=95 then return "LEGENDARY" elseif p>=90 then return "ELITE" elseif p>=85 then return "GREAT" elseif p>=80 then return "GOOD" elseif p>=70 then return "AVERAGE" elseif p>=60 then return "SUBPAR" end
  return "BAD"
end
local buffGrade
local function roleMetricLines(h)
  local function line(label,v)
    return label..": "..(type(v)=="number" and string.format("%.1f%% | %s",v,(label:find("TIME ON TARGET",1,true) and targetGrade(v) or buffGrade(v))) or "N/A")
  end
  if h.role=="HEAL" then return line("BUFF UPTIME",h.buffUptime).."\n"..line("DEBUFF UPTIME",h.debuffUptime) end
  if h.role=="TANK" then return line("BUFF UPTIME",h.buffUptime).."\n"..line("DEBUFF UPTIME",h.debuffUptime) end
  if h.role=="DPS" then return line("BUFF UPTIME",h.buffUptime).."\n"..line("DEBUFF UPTIME",h.debuffUptime).."\n"..line("DoT UPTIME",h.dotUptime).."\n"..line("TIME ON TARGET (EST.)",h.timeOnTarget) end
  return "ROLE UPTIME: N/A"
end
buffGrade=function(p)
  if not p then return "UNAVAILABLE" end
  if p<20 then return "BAD" elseif p<35 then return "SUBPAR" elseif p<50 then return "AVERAGE"
  elseif p<65 then return "GOOD" elseif p<80 then return "GREAT" elseif p<92 then return "ELITE" end
  return "LEGENDARY"
end
local function scoreParts()
  if not run then return {buff=0,healing=0,damage=0,utility=0,penalty=0,total=0} end
  local t=math.max(1,combatDuration());local dps=run.damage/t;local hps=run.heal/t
  local buff=0;local healing=0;local damage=0;local utility=0
  if run.role=="HEAL" then
    buff=(buffUptime() or 0)*0.25
    healing=clamp(hps/500,0,12)
    damage=clamp(dps/850,0,6)
    utility=clamp(run.interrupts*1.5+(run.shield or 0)/t/700,0,5)+(run.ultimatePoints or 0)
  elseif run.role=="TANK" then
    buff=(debuffUptime() or 0)*0.18
    utility=clamp(run.blocked/t/100+run.taunts*1.5+run.interrupts*2+run.ccEvents,0,16)
    damage=clamp(dps/700,0,8)
    healing=clamp(hps/700,0,4)
  else
    buff=(dotUptime() or 0)*0.06+(targetUptime() or 0)*0.09
    damage=clamp(dps/1800,0,24)
    healing=clamp(hps/1200,0,3)
    utility=clamp(run.interrupts*2+run.ccEvents,0,6)
  end
  local penalty=run.deaths*5
  return {buff=buff,healing=healing,damage=damage,utility=utility,penalty=penalty,total=math.max(0,buff+healing+damage+utility-penalty)}
end
local function score() return scoreParts().total end
local function makeLabel(parent,y,size,color,width)
  local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
  c:SetAnchor(TOPLEFT,parent,TOPLEFT,14,y);c:SetDimensions(width or 470,28)
  c:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin",size));c:SetColor(unpack(color));return c
end
-- Fit informational panels vertically; fixed width avoids layout jitter.
local function fitBody(panel,label,top,minHeight,padding)
  if not panel or not label then return end
  local old=label:GetHeight()
  label:SetHeight(0)
  local h=safe(label.GetTextHeight,label) or safe(label.GetHeight,label)
  if not h or h<=0 then
    local lines=1; for _ in (label:GetText() or ""):gmatch("\n") do lines=lines+1 end
    h=math.max(22,lines*22)
  end
  h=math.ceil(h)+4
  label:SetHeight(h)
  local wanted=math.max(minHeight,top+h+(padding or 12))
  if math.abs(panel:GetHeight()-wanted)>1 then panel:SetHeight(wanted) end
end
local function applyWindowLayout(window,key)
  if not window or not S then return end
  local layouts=S.settings.windowLayout or {}
  local l=layouts[key]
  if not l then return end
  window:ClearAnchors()
  window:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,l.x or 200,l.y or 180)
  window:SetScale(math.max(0.5,math.min(2,(l.scale or 100)/100)))
end
local function enableWindowDrag(window,key)
  if not window then return end
  window:SetMovable(true)
  window:SetMouseEnabled(true)
  window:SetHandler("OnMouseDown",function(self,button) if button==MOUSE_BUTTON_INDEX_LEFT then self:StartMoving() end end)
  window:SetHandler("OnMouseUp",function(self,button) if button==MOUSE_BUTTON_INDEX_LEFT then self:StopMovingOrResizing() end end)
  window:SetHandler("OnMoveStop",function(self)
    if not S or not S.settings.windowLayout then return end
    local l=S.settings.windowLayout[key]
    if not l then return end
    local scale=self:GetScale()
    l.x=math.floor((self:GetLeft() or l.x)+0.5)
    l.y=math.floor((self:GetTop() or l.y)+0.5)
    applyWindowLayout(self,key)
  end)
end
local function refreshWindowLayouts()
  for key,panel in pairs(rollingPanels) do applyWindowLayout(panel,key) end
  applyWindowLayout(hud,"live")
  applyWindowLayout(worldHUD,"world")
  applyWindowLayout(bossHUD,"boss")
  applyWindowLayout(reportHUD,"report")
  if menu then applyWindowLayout(menu,"career") end
  applyWindowLayout(playerCard,"playerCard")
end

-- TME shared antique gold frame; anchored strips follow resizing and scaling.
local function TMEGoldFrame(parent)
    local function edge(a,b,c,d,vertical)
        local t=WINDOW_MANAGER:CreateControl(nil,parent,CT_TEXTURE)
        t:SetAnchor(a,parent,b,0,0); t:SetAnchor(c,parent,d,0,0)
        if vertical then t:SetWidth(2) else t:SetHeight(2) end
        t:SetColor(0.66,0.51,0.29,0.95); t:SetMouseEnabled(false)
        t:SetDrawLayer(DL_BACKGROUND); t:SetDrawLevel(3)
    end
    edge(TOPLEFT,TOPLEFT,TOPRIGHT,TOPRIGHT,false)
    edge(BOTTOMLEFT,BOTTOMLEFT,BOTTOMRIGHT,BOTTOMRIGHT,false)
    edge(TOPLEFT,TOPLEFT,BOTTOMLEFT,BOTTOMLEFT,true)
    edge(TOPRIGHT,TOPRIGHT,BOTTOMRIGHT,BOTTOMRIGHT,true)
end

local function makePanel(name,width,height,x,y)
  local w=WINDOW_MANAGER:CreateTopLevelWindow(name)
  w:SetDimensions(width,height);w:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)
  w:SetClampedToScreen(true);w:SetMouseEnabled(false);w:SetHidden(true)
  local bg=WINDOW_MANAGER:CreateControl(nil,w,CT_BACKDROP)
  bg:SetAnchorFill();bg:SetCenterColor(0.025,0.023,0.020,0.92);bg:SetEdgeColor(0.66,0.51,0.29,0.95)
  TMEGoldFrame(w)
  return w
end
local function ensureHUD()
  if hud or not WINDOW_MANAGER then return end
  hud=makePanel("DungeonRatingHUD",550,510,200,180)
  local labels={
    {"header",10,19,{0.95,0.78,0.43}},{"diff",40,14,{0.7,0.85,1}},
    {"timer",68,16,{1,1,1}},{"fight",103,17,{1,1,1}},
    {"overall",138,17,{1,1,1}},{"damage",174,15,{1,1,1}},
    {"healing",205,15,{1,1,1}},{"score",241,18,{0.98,0.86,0.55}},
    {"pace",275,15,{0.70,0.86,0.98}},{"buff",308,15,{0.70,0.95,0.76}},{"role2",340,15,{0.70,0.95,0.76}}}
  for _,a in ipairs(labels) do hud[a[1]]=makeLabel(hud,a[2],a[3],a[4]) end
  hud.targetDetail=makeLabel(hud,370,14,{.7,.85,1},520)
  hud.timers=makeLabel(hud,400,14,{.7,.85,1},520); hud.timers:SetDimensions(520,100)
  enableWindowDrag(hud,"live");applyWindowLayout(hud,"live")
  bossHUD=makePanel("DungeonRatingBossIntelligenceHUD",560,245,720,180)
  bossHUD.header=makeLabel(bossHUD,12,18,{0.98,0.82,0.46})
  bossHUD.name=makeLabel(bossHUD,45,17,{1,1,1})
  bossHUD.mechanic=makeLabel(bossHUD,81,15,{1,0.68,0.45},530)
  bossHUD.mechanic:SetDimensions(530,100)
  bossHUD.response=makeLabel(bossHUD,181,14,{0.76,0.86,1},530)
  bossHUD.source=makeLabel(bossHUD,215,12,{0.65,0.75,0.85})
  enableWindowDrag(bossHUD,"boss");applyWindowLayout(bossHUD,"boss")
end
-- Compact persistent out-of-dungeon card. All values come from saved character runs.
local function ensurePlayerCard()
  if playerCard or not WINDOW_MANAGER then return end
  playerCard=makePanel("DungeonBuddyPlayerCard",920,165,220,90)
  playerCard.header=makeLabel(playerCard,10,18,{0.95,0.78,0.43},880)
  playerCard.identity=makeLabel(playerCard,41,18,{1,1,1},880)
  playerCard.career=makeLabel(playerCard,76,15,{0.75,0.90,1},880)
  playerCard.highs=makeLabel(playerCard,106,15,{0.75,0.95,0.78},880)
  playerCard.last=makeLabel(playerCard,136,14,{1,1,1},880)
  enableWindowDrag(playerCard,"playerCard")
  applyWindowLayout(playerCard,"playerCard")
end
local function updatePlayerCard()
  if not S then return end
  ensurePlayerCard()
  if not playerCard then return end
  local inDungeon=safe(IsUnitInDungeon,"player") or safe(IsUnitInGroupDungeon,"player") or safe(IsInDungeon)
  local visible=S.settings.previewWindows or (S.settings.showPlayerCard~=false and not inDungeon and not run)
  playerCard:SetHidden(not visible)
  if not visible then return end
  local name=characterKey()
  local history=S.history or {}
  local count,total,bestScore,bestDPS,bestHPS,bestUptime=0,0,0,0,0,0
  local latest,latestRole
  for _,h in ipairs(history) do
    if h.character==name or (h.character==nil and name==player()) then
      count=count+1;total=total+(h.score or 0)
      bestScore=math.max(bestScore,h.score or 0)
      bestDPS=math.max(bestDPS,h.overallDPS or 0)
      bestHPS=math.max(bestHPS,h.overallHPS or 0)
      local uptime=h.role=="HEAL" and h.buffUptime or h.role=="TANK" and h.debuffUptime or h.dotUptime
      bestUptime=math.max(bestUptime,uptime or 0)
      if not latest or (h.date or 0)>(latest.date or 0) then latest=h;latestRole=h.role end
    end
  end
  local archetype=S.settings.manualRole~="AUTO" and S.settings.manualRole or role()
  if archetype=="UNKNOWN" then archetype=latestRole or "UNASSIGNED" end
  local roleName=archetype=="HEAL" and "HEALER" or archetype
  local avg=count>0 and total/count or 0
  local metric=archetype=="HEAL" and "BUFF" or archetype=="TANK" and "DEBUFF" or "DoT"
  playerCard.header:SetText("DUNGEON BUDDY  |  PVE PLAYER CARD")
  playerCard.identity:SetText(name.."  |  "..roleName.."  |  CAREER "..string.format("%.1f",avg).." "..(count>0 and grade(avg) or "UNRANKED"))
  playerCard.career:SetText(string.format("CAREER  %d runs  |  Average %.1f  |  Best score %.1f",count,avg,bestScore))
  playerCard.highs:SetText(string.format("ALL-TIME HIGHS  DPS %s  |  HPS %s  |  %s uptime %.1f%%",fmt(bestDPS),fmt(bestHPS),metric,bestUptime))
  if latest then
    local lastUptime=latest.role=="HEAL" and latest.buffUptime or latest.role=="TANK" and latest.debuffUptime or latest.dotUptime
    playerCard.last:SetText(string.format("LAST RUN  %s  |  %.1f %s  |  DPS %s  HPS %s  |  Uptime %.1f%%",tostring(latest.zone or "Dungeon"),latest.score or 0,tostring(latest.grade or grade(latest.score or 0)),fmt(latest.overallDPS),fmt(latest.overallHPS),lastUptime or 0))
  else
    playerCard.last:SetText("LAST RUN  No saved dungeon runs for this character")
  end
end
local worldCasts={}
local world={damage=0,heal=0,seconds=0,effects={}}
local function insideDungeon()
  return safe(IsUnitInDungeon,"player") or safe(IsUnitInGroupDungeon,"player") or safe(IsInDungeon)
end
local function worldState(_,active)
  if insideDungeon() then world={damage=0,heal=0,seconds=0,effects={}}; return end
  if active and not world.started then world.damage=0;world.heal=0;world.seconds=0;world.started=now()
  elseif not active and world.started then world.seconds=now()-world.started;world.started=nil end
end
local function worldCombat(_,result,isError,abilityName,abilityGraphic,abilityAction,sourceName,sourceType,targetName,targetType,hitValue)
  if insideDungeon() or isError then return end
  if not (sourceType==COMBAT_UNIT_TYPE_PLAYER or sourceType==COMBAT_UNIT_TYPE_PLAYER_PET or isOwnName(sourceName)) then return end
  if not world.started and safe(IsUnitInCombat,"player") then worldState(nil,true) end
  if not world.started then return end
  local v=math.max(0,tonumber(hitValue) or 0)
  if result==ACTION_RESULT_DAMAGE or result==ACTION_RESULT_CRITICAL_DAMAGE or result==ACTION_RESULT_DOT_TICK or result==ACTION_RESULT_DOT_TICK_CRITICAL then world.damage=world.damage+v
  elseif result==ACTION_RESULT_HEAL or result==ACTION_RESULT_CRITICAL_HEAL or result==ACTION_RESULT_HOT_TICK or result==ACTION_RESULT_HOT_TICK_CRITICAL then world.heal=world.heal+v end
end
local function worldEffect(_,change,slot,name,tag,beg,ending,stack,icon,buffType,effectType,abilityType,statusEffectType,unitName,unitId,abilityId,sourceType)
  if insideDungeon() then return end
  local key=tostring(tag)..":"..tostring(unitId)..":"..tostring(slot)..":"..tostring(abilityId)
  if change==EFFECT_RESULT_FADED then world.effects[key]=nil;return end
  local kind=buffType==BUFF_EFFECT_TYPE_DEBUFF and "DEBUFF" or (buffType==BUFF_EFFECT_TYPE_BUFF and "BUFF" or nil)
  local registered=supportRegistry[(name or ""):gsub("%^%a+","")]
  if registered=="buff" or registered=="debuff" then kind=registered:upper() end
  if not kind or registered=="instant" or registered=="passive" then return end
  local attributed=sourceType==COMBAT_UNIT_TYPE_PLAYER or (COMBAT_UNIT_TYPE_PLAYER_PET and sourceType==COMBAT_UNIT_TYPE_PLAYER_PET)
  local t=now()
  if not attributed then
    for id,cast in pairs(worldCasts) do
      if t-cast.at>2.5 then worldCasts[id]=nil
      elseif id==abilityId or (t-cast.at<=1.25 and cast.name and name and cast.name:lower()==name:lower()) then attributed=true end
    end
  end
  if kind=="DEBUFF" then
    if not attributed or tag=="player" or (tag and tag:match("^group%d+$")) then return end
  elseif tag~="player" and not attributed then return end
  if (change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED) and tonumber(ending) and ending>t then
    world.effects["cast:"..tostring(abilityId)]=nil
    world.effects[key]={name=name or "Effect",ending=ending,kind=kind}
  end
end
-- Independent display-only effects stream. Never writes scoring coverage.
local rollingEffects={}
local deadTargets={}
local rollingCasts={}
local rollingZone=nil
local refreshGlows={}
local rollingLinks={}
local function clearRefreshGlows()
  for _,g in pairs(refreshGlows) do g:SetHidden(true) end
end
local rollingAliases={ ["major sorcery"]="Major Brutality", ["major brutality"]="Major Brutality", ["major prophecy"]="Major Savagery", ["major savagery"]="Major Savagery", ["minor sorcery"]="Minor Brutality", ["minor brutality"]="Minor Brutality", ["minor prophecy"]="Minor Savagery", ["minor savagery"]="Minor Savagery", ["bright harbinger"]="Bright Harbinger", ["illuminate"]="Illuminate" }
local function rollingDisplay(n) local clean=tostring(n or ""):gsub("%^%a+",""); return rollingAliases[clean:lower()] or clean end
local function rollingName(n) return rollingDisplay(n):lower() end
local function rollingKnown(n) return rollingAliases[tostring(n or ""):gsub("%^%a+",""):lower()]~=nil end
local function rollingSlotId(slot)
  local bar=safe(GetActiveHotbarCategory)
  local id=bar~=nil and safe(GetSlotBoundId,slot,bar) or nil
  if not id or id==0 then id=safe(GetSlotBoundId,slot) end
  return id
end
local function rollingLink(e,t)
  if e.persistent then return end
  local link=rollingLinks[rollingName(e.name)]
  if link and link.ending>t and math.abs(link.ending-e.ending)<2 then return link.id end
  if e.own and e.id then
    for slot=3,8 do if tostring(rollingSlotId(slot))==tostring(e.id) then return tostring(e.id) end end
  end
end
local function usableSlotControl(c)
  return c and safe(c.GetWidth,c) and safe(c.GetWidth,c)>0 and not safe(c.IsHidden,c)
end
local function rollingSlotControl(slot)
  local button=safe(ZO_ActionBar_GetButton,slot)
  if button then
    local c=safe(button.GetControl,button) or button.slot or button.control or button
    if usableSlotControl(c) then return c end
  end
  if ACTION_BAR then
    local b=safe(ACTION_BAR.GetButton,ACTION_BAR,slot)
    if b then local c=safe(b.GetControl,b) or b.slot or b.control or b;if usableSlotControl(c) then return c end end
  end
  local c=safe(GetControl,"ActionButton"..slot) or _G["ActionButton"..slot]
  if usableSlotControl(c) then return c end
end
local function refreshActionSlots(wanted,t)
  clearRefreshGlows()
  if not S.settings.showRefreshHighlights or S.settings.previewWindows then return end
  for slot=3,8 do
    local id=rollingSlotId(slot)
    if id and wanted[tostring(id)] then
      local control=rollingSlotControl(slot)
      if control then
        local g=refreshGlows[slot]
        if not g then
          g=WINDOW_MANAGER:CreateControl("DungeonBuddyRefreshGlow"..slot,GuiRoot,CT_LABEL)
          g:SetFont("$(BOLD_FONT)|26|soft-shadow-thick")
          g:SetHorizontalAlignment(TEXT_ALIGN_CENTER);g:SetVerticalAlignment(TEXT_ALIGN_CENTER)
          g:SetMouseEnabled(false)
          if g.SetDrawTier and DT_HIGH then g:SetDrawTier(DT_HIGH) end
          if g.SetDrawLayer and DL_OVERLAY then g:SetDrawLayer(DL_OVERLAY) end
          refreshGlows[slot]=g
        end
        g:ClearAnchors();g:SetAnchor(BOTTOM,control,TOP,0,-4);g:SetDimensions(130,36)
        local urgent=wanted[tostring(id)]<=3
        g:SetText("▼ REFRESH");g:SetColor(1,urgent and .24 or .88,.15,.75+.25*math.sin(t*9));g:SetHidden(false)
      end
    end
  end
end
local function rollingResetZone()
  local z=tostring(safe(GetUnitZoneIndex,"player") or zone())..":"..tostring(insideDungeon())
  if rollingZone~=z then rollingZone=z;rollingEffects={};deadTargets={};rollingCasts={};rollingLinks={};clearRefreshGlows() end
end
local function rollingCast(_,slot)
  rollingResetZone()
  local id=rollingSlotId(slot)
  if id and id~=0 then rollingCasts[tostring(id)]={at=now(),name=safe(GetAbilityName,id),slot=slot} end
end
local function rollingEffect(_,change,slot,name,tag,beg,ending,stack,icon,buffType,effectType,abilityType,statusEffectType,unitName,unitId,abilityId,sourceType)
  rollingResetZone()
  local key=tostring(tag)..":"..tostring(unitId)..":"..tostring(slot)..":"..tostring(abilityId)
  if change==EFFECT_RESULT_FADED then rollingEffects[key]=nil;return end
  if change~=EFFECT_RESULT_GAINED and change~=EFFECT_RESULT_UPDATED then return end
  local kind=(BUFF_EFFECT_TYPE_DEBUFF and buffType==BUFF_EFFECT_TYPE_DEBUFF) and "debuff" or ((BUFF_EFFECT_TYPE_BUFF and buffType==BUFF_EFFECT_TYPE_BUFF) and "buff" or nil)
  local registered=supportRegistry[(name or ""):gsub("%^%a+","")]
  if registered=="buff" or registered=="debuff" then kind=registered end
  if tag=="player" and rollingKnown(name) then kind="buff" end
  if not kind or ((registered=="instant" or registered=="passive") and not rollingKnown(name)) then return end
  local t=now();ending=tonumber(ending)
  if not ending or ending<=t or ending-t>600 then return end
  local own=sourceType==COMBAT_UNIT_TYPE_PLAYER or (COMBAT_UNIT_TYPE_PLAYER_PET and sourceType==COMBAT_UNIT_TYPE_PLAYER_PET)
  for id,c in pairs(rollingCasts) do
    if t-c.at>2.5 then rollingCasts[id]=nil
    elseif id==tostring(abilityId) or (t-c.at<=1.25 and c.name and name and c.name:lower()==name:lower()) then own=true end
  end
  -- Link only observed own effects to an exact ID/name or a unique recent cast.
  if own then
    local exact,unique,count=nil,nil,0
    for id,c in pairs(rollingCasts) do
      if t-c.at<=1.25 then
        count=count+1;unique=id
        if id==tostring(abilityId) or rollingName(c.name)==rollingName(name) then exact=id end
      end
    end
    local prior=rollingLinks[rollingName(name)]
    local candidate=exact or (count==1 and change==EFFECT_RESULT_GAINED and unique)
    if not candidate then for actionSlot=3,8 do if tostring(rollingSlotId(actionSlot))==tostring(abilityId) then candidate=tostring(abilityId);exact=candidate;break end end end
    if candidate and (exact or not prior or prior.id==candidate) then
      rollingLinks[rollingName(name)]={id=candidate,ending=ending}
    elseif prior and exact==nil and candidate and prior.id~=candidate then
      rollingLinks[rollingName(name)]=nil
    elseif prior and prior.ending>t and not candidate then prior.ending=ending end
  end
  local friendly=tag=="player" or (tag and tag:match("^group%d+$"))
  if kind=="debuff" and (friendly or not own) then return end
  if kind=="debuff" and unitId and unitId~=0 and change==EFFECT_RESULT_GAINED then deadTargets[tostring(unitId)]=nil end
  if kind=="buff" and not (tag=="player" or (friendly and own)) then return end
  rollingEffects[key]={targetId=unitId and tostring(unitId),sourceAbility=own and rollingLinks[rollingName(name)] and rollingLinks[rollingName(name)].id,name=name or "Effect",kind=kind,ending=ending,duration=math.max(0.1,ending-(tonumber(beg) or t)),id=tostring(abilityId),own=own,entered=rollingEffects[key] and rollingEffects[key].entered or t}
end
local function rollingPanel(key,kind)
  local p=rollingPanels[key];if p then return p end
  p=WINDOW_MANAGER:CreateTopLevelWindow("DungeonBuddy"..key)
  p:SetDimensions(440,320);p:SetClampedToScreen(false);p:SetHidden(true)
  p:SetMouseEnabled(false);p.rows={};rollingPanels[key]=p
  for i=1,8 do
    local r=makeLabel(p,0,20,{1,1,1},440)
    r:SetHorizontalAlignment(kind=="buff" and TEXT_ALIGN_RIGHT or TEXT_ALIGN_LEFT)
    r:SetHidden(true);p.rows[i]=r
  end
  applyWindowLayout(p,key);return p
end
-- Snapshot currently visible effects, including effects applied before loading.
-- GetUnitBuffInfo returns castByPlayer, unlike the event's source type.
local function rollingSnapshot(tag,kind,add,t)
  if not GetUnitBuffInfo or not GetNumBuffs then return end
  local count=safe(GetNumBuffs,tag) or 0
  for i=1,count do
    local ok,name,beg,ending,slot,stack,icon,buffType,effectType,abilityType,statusEffectType,abilityId,canClickOff,castByPlayer=pcall(GetUnitBuffInfo,tag,i)
    if ok and name then
      ending=tonumber(ending)
      local actual=(BUFF_EFFECT_TYPE_DEBUFF and effectType==BUFF_EFFECT_TYPE_DEBUFF) and "debuff" or ((BUFF_EFFECT_TYPE_BUFF and effectType==BUFF_EFFECT_TYPE_BUFF) and "buff" or nil)
      local known=tag=="player" and rollingKnown(name)
      if known then actual="buff" end
      local persistent=known and (not ending or ending==0 or ending-t>600)
      if actual==kind and (tag=="player" or castByPlayer==true) and (persistent or (ending and ending>t and ending-t<=600)) then
        add({name=name,kind=kind,ending=persistent and t+100000 or ending,persistent=persistent,duration=persistent and 0 or math.max(.1,ending-(tonumber(beg) or t)),own=castByPlayer==true,id=tostring(abilityId),entered=t})
      end
    end
  end
end
local function updateRolling()
  if not S then return end
  rollingResetZone();local t=now();local preview=S.settings.previewWindows
  local hideRolling=not S.settings.showRollingEffects and not preview
  local wanted={}
  local buckets={buff={},debuff={}}
  local function add(e)
    local bucket=buckets[e.kind];if not bucket or not e.name or e.ending<=t then return end
    local k=rollingDisplay(e.name:gsub(" %(est%.%)$",""));local old=bucket[k]
    e.name=k
    if not old or (e.persistent and not old.persistent) or (not old.persistent and ((old.estimated and not e.estimated) or (old.estimated==e.estimated and e.ending<old.ending))) then bucket[k]=e end
  end
  for k,e in pairs(rollingEffects) do if e.ending<=t then rollingEffects[k]=nil else add(e) end end
  rollingSnapshot("player","buff",add,t)
  rollingSnapshot("reticleover","debuff",add,t)
  for i=1,6 do rollingSnapshot("boss"..i,"debuff",add,t) end
  if insideDungeon() and run then
    for _,kind in ipairs({"buff","debuff"}) do for id,e in pairs(run.durationCoverage[kind] or {}) do
      add({name=e.name,kind=kind,ending=e.expires or 0,duration=(run.durationObserved[id] or {}).duration or 10,estimated=true})
    end end
  else
    for _,e in pairs(world.effects) do add({name=e.name,kind=e.kind:lower(),ending=e.ending,estimated=true}) end
  end
  TMENexus.effectBuckets=buckets
  TMENexus.abilityLinks=rollingLinks
  local ends={}
  for _,bucket in pairs(buckets) do for _,e in pairs(bucket) do
    local id=rollingLink(e,t)
    if not id and e.own and e.id then id=tostring(e.id) end
    if id and not e.persistent and e.ending>t then ends[id]=math.min(ends[id] or math.huge,e.ending) end
  end end
  local targetEnds={}
  for _,e in pairs(rollingEffects) do
    if e.kind=="debuff" and e.own and e.targetId and e.targetId~="0" and not deadTargets[e.targetId] and e.ending>t then
      local id=e.sourceAbility or e.id
      if id then targetEnds[id]=math.max(targetEnds[id] or 0,e.ending) end
    end
  end
  TMENexus.targetAbilityEnds=targetEnds
  TMENexus.abilityEffectEnds=ends
  for _,kind in ipairs({"buff","debuff"}) do
    local p=rollingPanel(kind=="buff" and "rollingBuff" or "rollingDebuff",kind);local entries={}
    for _,e in pairs(buckets[kind]) do entries[#entries+1]=e end
    if preview then entries={{name=kind=="buff" and "Major Resolve" or "Major Breach",ending=t+12},{name=kind=="buff" and "Minor Berserk" or "Minor Breach",ending=t+2}} end
    table.sort(entries,function(a,b) if a.ending==b.ending then return a.name<b.name end return a.ending<b.ending end)
    p:SetHidden(hideRolling or (not preview and #entries==0))
    p.positions=p.positions or {};local positions={}
    for i,r in ipairs(p.rows) do
      local e=entries[i];r:SetHidden(not e)
      if e then
        local remaining=e.ending-t;local target=(i-1)*39;
        local id=not preview and rollingLink(e,t)
        if id and not e.persistent and remaining<=6 then wanted[id]=math.min(wanted[id] or 6,remaining) end
        local fontSize=remaining<=3 and math.floor(28+2*math.sin(t*9)) or (remaining<=6 and 25 or 20)
        if r.refreshFont~=fontSize then r:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick",fontSize));r.refreshFont=fontSize end
        r:SetHeight(38);local old=p.positions[e.name]
        local y=old and (old+(target-old)*.32) or target+16
        positions[e.name]=y
        r:ClearAnchors();r:SetAnchor(TOPLEFT,p,TOPLEFT,0,y)
        local cr,cg,cb=.45,.95,.65;if kind=="debuff" then cr,cg,cb=1,.65,.39 end
        if remaining<=3 then cr,cg,cb=1,.30,.30 elseif remaining<=6 then cr,cg,cb=1,.83,.35 end
        r:SetText(e.persistent and (e.name.."  ACTIVE") or string.format("%s%s  %.1fs",e.name,e.estimated and "~" or "",remaining));r:SetColor(cr,cg,cb,math.min(1,remaining/.35))
      end
    end
    p.positions=positions
  end
  TMENexus.refreshWanted=S.settings.showRefreshHighlights and wanted or {}; TMENexus.effectBuckets=buckets
  if TMENexus.customBarsActive then clearRefreshGlows() else refreshActionSlots(wanted,t) end
end
local function updateWorld()
  if not worldHUD then
    worldHUD=makePanel("DungeonBuddyWorldHUD",550,280,200,180)
    worldHUD.header=makeLabel(worldHUD,10,19,{.95,.78,.43},520)
    worldHUD.body=makeLabel(worldHUD,42,16,{1,1,1},520);worldHUD.body:SetDimensions(520,230)
    applyWindowLayout(worldHUD,"world")
  end
  local preview=S.settings.previewWindows
  local inside=insideDungeon()
  if inside then world={damage=0,heal=0,seconds=0,effects={}} end
  local visible=preview or (not inside and S.settings.showWorldHUD~=false and (world.started or (safe(IsUnitInCombat,"player"))))
  worldHUD:SetHidden(not visible);if not visible then return end
  local elapsed=world.started and now()-world.started or world.seconds
  local lines={string.format("%s  |  DPS %s  |  HPS %s",world.started and "COMBAT" or "LAST FIGHT",fmt(world.damage/math.max(1,elapsed)),fmt(world.heal/math.max(1,elapsed))),"Damage "..fmt(world.damage).."  |  Healing "..fmt(world.heal),"Combat time "..clock(elapsed)}
  local buffs,debuffs={},{}
  for k,e in pairs(world.effects) do
    if e.ending<=now() then world.effects[k]=nil else local bucket=e.kind=="BUFF" and buffs or debuffs;bucket[#bucket+1]=e end
  end
  for _,bucket in ipairs({buffs,debuffs}) do table.sort(bucket,function(a,b) return a.ending<b.ending end) end
  for i,bucket in ipairs({buffs,debuffs}) do
    lines[#lines+1]=i==1 and "BUFFS" or "DEBUFFS"
    local entries={};for j=1,math.min(3,#bucket) do local e=bucket[j];entries[#entries+1]=e.name.." "..fmt(e.ending-now()).."s" end
    lines[#lines+1]=#entries>0 and table.concat(entries," | ") or "None observed"
  end
  worldHUD.header:SetText("DUNGEON BUDDY  |  WORLD COMBAT")
  worldHUD.body:SetText(table.concat(lines,"\n"))
  fitBody(worldHUD,worldHUD.body,42,100,12)
end
local function goldSnapshot()
  local gs=GoldStandard
  local wallet=safe(GetCurrentMoney) or 0
  if gs and gs.saved and gs.saved.tracking and gs.initialized then return {wallet=wallet,found=gs.saved.lifetimeFound or 0,raw=gs.saved.lifetimeRawIn or 0} end
  return {wallet=wallet}
end
local function goldEarned(start)
  if not start then return nil end
  local current=goldSnapshot()
  if start.found and current.found then return math.max(0,current.found-start.found)+math.max(0,current.raw-start.raw),"Gold Standard gross estimate" end
  return math.max(0,current.wallet-start.wallet),"Wallet net gain only"
end
local function goldLine(h)
  return h.goldEarned~=nil and ("Gold earned: ~"..fmt(h.goldEarned).."g ("..tostring(h.goldSource)..")") or "Gold earned: N/A (not recorded)"
end
local function updateHUD()
  if not run or not hud then return end
  run.activeSeconds=math.max(1,now()-run.started)
  local ct=combatDuration();local elapsed=run.combatStart and math.max(1,now()-run.combatStart) or math.max(1,run.lastFightSeconds or 1)
  local fightD=run.combatStart and run.fightDamage or (run.lastFightDamage or 0)
  local fightH=run.combatStart and run.fightHeal or (run.lastFightHeal or 0)
  local tier,mode=difficulty();local sc=score()
  hud.header:SetText("DUNGEON BUDDY  |  "..run.role)
  hud.diff:SetText(mode.."  |  "..run.zone.."  |  "..tier)
  hud.timer:SetText("RUN TIME  "..clock(run.activeSeconds))
  hud.fight:SetText(string.format("%s  DPS %s/s   |   HPS %s/s",run.combatStart and "FIGHT" or "LAST FIGHT",fmt(fightD/elapsed),fmt(fightH/elapsed)))
  hud.overall:SetText("DUNGEON COMBAT AVG  DPS "..fmt(run.damage/math.max(1,ct)).."/s   |   HPS "..fmt(run.heal/math.max(1,ct)).."/s")
  hud.damage:SetText("TOTAL DAMAGE  "..fmt(run.damage))
  hud.healing:SetText("TOTAL HEALING  "..fmt(run.heal))
  hud.score:SetText(string.format("SCORE  %.1f  |  %s",sc,grade(sc)))
  local best=S.records[run.key];local pace="GOOD PACE"
  if best and run.checkpoint and best.checkpoints and best.checkpoints[run.checkpoint] then
    local delta=math.floor(run.activeSeconds-best.checkpoints[run.checkpoint]);pace=delta<=0 and "GOOD PACE" or "BEHIND PB PACE"
  else pace="PACE NOT YET COMPARABLE" end
  hud.pace:SetText(S.settings.showPace and pace or "")
  local pct=buffUptime()
  local metric=run.role=="HEAL" and "BUFF UPTIME" or run.role=="TANK" and "DEBUFF UPTIME" or "DoT UPTIME"
  local value=run.role=="HEAL" and pct or run.role=="TANK" and debuffUptime() or dotUptime()
  hud.buff:SetText(metric.."  "..(value and string.format("%.1f%%  |  %s",value,buffGrade(value)) or "N/A"))
  local target=targetUptime()
  hud.role2:SetText(run.role=="DPS" and ("TIME ON TARGET (EST.)  "..(target and string.format("%.1f%%  |  %s",target,targetGrade(target)) or "N/A")) or "")
  local covered=target and ct*target/100 or 0
  hud.targetDetail:SetText(run.role=="DPS" and string.format("Active %.1fs / %.1fs | Downtime %.1fs",covered,ct,math.max(0,ct-covered)) or "")
  local lines={}
  for _,kind in ipairs({"buff","debuff"}) do
    local entries={}
    for _,e in pairs(run.durationCoverage[kind]) do
      local remaining=(e.expires or 0)-now()
      if remaining>0 then entries[#entries+1]={name=e.name,remaining=remaining} end
    end
    table.sort(entries,function(a,b) return a.remaining<b.remaining end)
    local parts={}; for i=1,math.min(3,#entries) do parts[#parts+1]=string.format("%s %.0fs",entries[i].name,entries[i].remaining) end
    lines[#lines+1]=kind:upper()..": "..(#parts>0 and table.concat(parts," | ") or "None active")
  end
  hud.timers:SetText(table.concat(lines,"\n"))
  local timerY=run.role=="DPS" and 400 or 340
  hud.timers:ClearAnchors();hud.timers:SetAnchor(TOPLEFT,hud,TOPLEFT,14,timerY)
  fitBody(hud,hud.timers,timerY,360,12)
  hud:SetHidden(not (S.settings.showHUD or S.settings.previewWindows))
  if bossHUD then
    local boss=run.activeBoss
    bossHUD:SetHidden(not (S.settings.previewWindows or (S.settings.showBossHUD and boss)))
    if boss or S.settings.previewWindows then
      boss=boss or {name="BOSS PREVIEW",health=100}
      bossHUD.header:SetText("BOSS INTELLIGENCE  |  "..run.zone)
      bossHUD.name:SetText(boss.name.."  |  "..(boss.health and (boss.health.."%") or "ENGAGED"))
      local ref=type(DungeonRatingFindBossReference)=="function" and DungeonRatingFindBossReference(run.zone,boss.name)
      local tips={}
      if ref and ref.mechanics then
        for i=1,math.min(3,#ref.mechanics) do
          local tip=ref.mechanics[i]
          tips[#tips+1]=tostring(i)..". "..tostring(tip.response or tip.name or "Key mechanic")
        end
      end
      bossHUD.mechanic:SetText(#tips>0 and table.concat(tips,"\n") or "TANK AND SPANK  |  No special mechanic documented")
      bossHUD.response:SetText(ref and ref.kind=="OPTIONAL" and "OPTIONAL ENCOUNTER" or "")
      bossHUD.source:SetText("REFERENCE GUIDE  |  No automatic mechanic alerts")
      fitBody(bossHUD,bossHUD.mechanic,81,120,76)
      local y=81+bossHUD.mechanic:GetHeight()
      bossHUD.response:ClearAnchors();bossHUD.response:SetAnchor(TOPLEFT,bossHUD,TOPLEFT,14,y+4)
      bossHUD.source:ClearAnchors();bossHUD.source:SetAnchor(TOPLEFT,bossHUD,TOPLEFT,14,y+36)
    end
  end
end
local function groupSnapshot()
  local names={}
  local n=safe(GetGroupSize) or 0
  for i=1,n do
    local tag="group"..i
    local name=safe(GetUnitDisplayName,tag) or safe(GetUnitName,tag)
    if name and name~="" then names[name]=true end
  end
  names[player()]=true
  return names
end
local function recordEncounter()
  if not run or not run.combatStart then return end
  local duration=math.max(0.001,now()-run.combatStart)
  run.encounters=run.encounters or {}
  table.insert(run.encounters,{index=#run.encounters+1,boss=run.activeBoss and run.activeBoss.name or nil,
    duration=duration,damage=run.fightDamage,rawHealing=run.fightHeal,
    dps=run.fightDamage/duration,hps=run.fightHeal/duration,
    deaths=math.max(0,run.deaths-(run.fightStartDeaths or 0)),
    startedAt=run.combatStart-run.started})
end
local function begin()
  if run or completedInstance then return end
  if not (safe(IsUnitInDungeon,"player") or safe(IsUnitInGroupDungeon,"player") or safe(IsInDungeon)) then return end
  lastBossReportContext=nil; pendingBossReport=nil
  local tier,mode,z=difficulty()
  run={started=now(),activeSeconds=1,combatSeconds=0,combatStart=nil,fightDamage=0,fightHeal=0,lastFightDamage=0,lastFightHeal=0,lastFightSeconds=0,damage=0,heal=0,shield=0,damageTaken=0,blocked=0,shieldEvents=0,interrupts=0,taunts=0,ccEvents=0,groupDeaths=0,healAbsorbed=0,healEffective=0,uptime={buff={},debuff={},dot={}},durationCoverage={buff={},debuff={},dot={}},recentCasts={},durationObserved={},targetSeconds=0,lastTargetHit=nil,buffSeconds=0,buffActive={},buffKeys={},buffCoverageSeconds=0,buffCoverageActive=false,buffCoverageObserved=false,buffCoverageLast=nil,ultimateUses=0,ultimateSupportUses=0,ultimatePoints=0,ultimateSupportPending=false,deaths=0,events=0,ownEvents=0,damageEvents=0,healEvents=0,role=S.settings.manualRole~="AUTO" and S.settings.manualRole or role(),zone=zone(),zoneId=z,mode=mode,abilities={},key=tostring(z or zone())..":"..mode,group=groupSnapshot(),lastScore=0,checkpoint=0,checkpoints={},bossKills=0,bosses={},activeBoss=nil,encounters={}}
  run.goldStart=goldSnapshot()
  ensureHUD()
  if safe(IsUnitInCombat,"player") then state(nil,true) end
  say("Run started: "..run.zone.." ("..run.role..")")
end
local openReport
local function finish()
  if not run then return end
  run.activeSeconds=math.max(1,now()-run.started)
  if run.combatStart then state(nil,false) end
  local parts=scoreParts();local ct=combatDuration();local result={id=tostring(safe(GetTimeStamp) or 0)..":"..tostring(S.runs+1),scoringVersion="0.3.4",character=safe(GetUnitName,"player"),combatSeconds=ct,overallDPS=run.damage/math.max(1,ct),overallHPS=run.heal/math.max(1,ct),rawHealing=run.heal,ultimateUses=run.ultimateUses,ultimateSupportUses=run.ultimateSupportUses,ultimatePoints=run.ultimatePoints,effectiveHealingAvailable=(run.healEffective or 0)>0,buffUptime=buffUptime(),debuffUptime=debuffUptime(),dotUptime=dotUptime(),timeOnTarget=targetUptime(),scoreParts=parts,zone=run.zone,mode=run.mode or "Unknown",role=run.role,seconds=run.activeSeconds,score=score(),damage=run.damage,heal=run.heal,damageTaken=run.damageTaken,blocked=run.blocked,taunts=run.taunts,healEffective=run.healEffective,healAbsorbed=run.healAbsorbed,groupDeaths=run.groupDeaths,interrupts=run.interrupts,ccEvents=run.ccEvents,buffSeconds=run.buffSeconds,deaths=run.deaths,date=safe(GetTimeStamp) or 0,group=run.group,abilities=run.abilities,completionVerified=run.completionVerified==true,events=run.events,ownEvents=run.ownEvents,damageEvents=run.damageEvents,healEvents=run.healEvents,bossKills=run.bossKills,bosses=run.bosses,encounters=run.encounters,grade=grade(score())}
  result.goldEarned,result.goldSource=goldEarned(run.goldStart)
  -- Personal records are scoped to character, dungeon, difficulty and role.
  local recordKey=table.concat({result.character or "Unknown",result.zone or "Unknown",result.mode or "Unknown",result.role or "UNKNOWN"},"|")
  S.personalBests=S.personalBests or {}
  local previous=S.personalBests[recordKey]
  if result.completionVerified then
    result.personalBest=false -- records retained, no celebrations
    result.previousBest=previous and previous.score or nil
    local entry=previous or {}
    if not entry.score or result.score>entry.score then entry.score=result.score;entry.scoreRunId=result.id end
    if not entry.fastest or result.seconds<entry.fastest then entry.fastest=result.seconds;entry.fastestRunId=result.id;result.fastestClear=true end
    entry.bestDPS=math.max(entry.bestDPS or 0,result.overallDPS or 0)
    entry.bestHPS=math.max(entry.bestHPS or 0,result.overallHPS or 0)
    local roleMetric=result.role=="HEAL" and result.buffUptime or result.role=="TANK" and result.debuffUptime or result.dotUptime
    if roleMetric then entry.bestBuff=math.max(entry.bestBuff or 0,roleMetric) end
    entry.runs=(entry.runs or 0)+1
    S.personalBests[recordKey]=entry
  end
  table.insert(S.history,result)
  if #S.history>500 then table.remove(S.history,1) end
  local best=S.records[run.key]
  -- Do not claim a personal-best clear without a verified completion event.
  if result.completionVerified and (not best or run.activeSeconds<best.seconds) then S.records[run.key]={seconds=run.activeSeconds,checkpoints=run.checkpoints} end
  local r=run.role
  if r~="UNKNOWN" then S.ratings[r]=S.ratings[r]==0 and result.score or (S.ratings[r]*0.8+result.score*0.2) end
  for name in pairs(run.group) do
    if name~=player() then
      local p=S.players[name] or {encounters=0,runs={}}
      p.encounters=p.encounters+1
      -- Groupmate's unobservable DPS/HPS/mitigation are deliberately NOT inferred.
      table.insert(p.runs,{zone=run.zone,date=result.date,groupClearSeconds=result.seconds,observedRole="UNKNOWN"})
      if #p.runs>100 then table.remove(p.runs,1) end
      S.players[name]=p
    end
  end
  S.runs=S.runs+1
  say(string.format("Run saved: %s, %s, %.1f (%s)",run.zone,clock(result.seconds),result.score,grade(result.score)))
  run=nil; bossTags={}; if hud then hud:SetHidden(true) end; if bossHUD then bossHUD:SetHidden(true) end
  if S.settings.autoReport and type(openReport)=="function" then openReport(result) end
end
local function bossChanged()
  if not run then return end
  local active=nil
  for i=1,6 do
    local tag="boss"..i
    if safe(DoesUnitExist,tag) then
      local name=safe(GetUnitName,tag) or ("Boss "..i)
      local unitId=safe(GetUnitId,tag)
      local key=tostring(unitId or name)
      bossTags[tag]=key
      local b=run.bosses[key] or {name=name,defeated=false}
      run.bosses[key]=b
      local current,max
      if type(GetUnitPower)=="function" then
        local ok,a,b=pcall(GetUnitPower,tag,COMBAT_MECHANIC_FLAGS_HEALTH)
        if ok then current,max=a,b end
      end
      if type(current)=="number" and type(max)=="number" and max>0 then b.health=math.floor(100*current/max+0.5) end
      if not b.defeated then active=b end
    else bossTags[tag]=nil end
  end
  run.activeBoss=active
  if active and active.name then lastBossReportContext={zone=run.zone,name=active.name} end
end
local function bossDeath(tag)
  if not run or not tag or not tag:match("^boss%d+$") then return end
  local key=bossTags[tag]
  local b=key and run.bosses[key]
  if b and not b.defeated then
    b.defeated=true;b.health=0;b.defeatedAt=now()-run.started
    run.bossKills=(run.bossKills or 0)+1
    run.checkpoint=run.checkpoint+1
    run.checkpoints[run.checkpoint]=now()-run.started
    say("Boss defeated (death state confirmed): "..b.name.." | "..tostring(run.bossKills).." total")
    if run.activeBoss==b then run.activeBoss=nil end
  end
end
local function combat(_,result,isError,abilityName,abilityGraphic,abilityAction,sourceName,sourceType,targetName,targetType,hitValue,powerType,damageType,log,sourceUnitId,targetUnitId,abilityId)
  if targetUnitId and targetUnitId~=0 and ((ACTION_RESULT_TARGET_DEAD and result==ACTION_RESULT_TARGET_DEAD) or (ACTION_RESULT_DIED and result==ACTION_RESULT_DIED) or (ACTION_RESULT_DIED_XP and result==ACTION_RESULT_DIED_XP) or (ACTION_RESULT_KILLING_BLOW and result==ACTION_RESULT_KILLING_BLOW)) then
    local k=tostring(targetUnitId);deadTargets[k]=true
    for key,e in pairs(rollingEffects) do if e.kind=="debuff" and e.targetId==k then rollingEffects[key]=nil end end
  end
  if not run then return end
  local me=player()
  -- Combat sourceType is more reliable than display-name equality for the local player.
  -- Keep name matching as a fallback for clients with incomplete source types.
  local sourceIsMe=(sourceType==COMBAT_UNIT_TYPE_PLAYER or sourceType==COMBAT_UNIT_TYPE_PLAYER_PET) or isOwnName(sourceName)
  local targetIsMe=(targetType==COMBAT_UNIT_TYPE_PLAYER) or isOwnName(targetName)
  run.events=(run.events or 0)+1
  if sourceIsMe then run.ownEvents=(run.ownEvents or 0)+1 end
  local amount=math.max(0,tonumber(hitValue) or 0)
  if sourceIsMe then
    if result==ACTION_RESULT_TAUNTED then run.taunts=run.taunts+1 end
    if result==ACTION_RESULT_DAMAGE or result==ACTION_RESULT_CRITICAL_DAMAGE or result==ACTION_RESULT_DOT_TICK or result==ACTION_RESULT_DOT_TICK_CRITICAL then run.damage=run.damage+amount;run.fightDamage=run.fightDamage+amount;run.damageEvents=(run.damageEvents or 0)+1 end
    if result==ACTION_RESULT_HEAL or result==ACTION_RESULT_CRITICAL_HEAL or result==ACTION_RESULT_HOT_TICK or result==ACTION_RESULT_HOT_TICK_CRITICAL then
      run.heal=run.heal+amount;run.fightHeal=run.fightHeal+amount;run.healEffective=run.healEffective+amount;run.healEvents=(run.healEvents or 0)+1
    end
    -- Direct damage/healing is not evidence of a maintained timed buff.
    -- Duration entries are learned from effect observations, not guessed here.
    if run.combatStart and amount>0 and (result==ACTION_RESULT_DOT_TICK or result==ACTION_RESULT_DOT_TICK_CRITICAL) and abilityId and (targetUnitId or (targetName and targetName~="")) then
      -- Tick-based coverage estimate, bounded to the observed tick interval.
      -- Not a claim that the game exposed the exact underlying DoT duration.
      local t=now(); run.dotObserved=true
      if run.lastDotTick then run.dotSeconds=(run.dotSeconds or 0)+math.min(2,math.max(0,t-run.lastDotTick)) end
      run.lastDotTick=t
      local key=tostring(abilityId)..":"..tostring(targetUnitId or targetName or "enemy")
      local bucket=run.uptime.dot
      local entry=bucket[key] or {seconds=0,observed=true}
      if entry.lastTick then entry.seconds=entry.seconds+math.min(2,math.max(0,now()-entry.lastTick)) end
      entry.lastTick=now();bucket[key]=entry
    end
    if run.combatStart and (result==ACTION_RESULT_DAMAGE or result==ACTION_RESULT_CRITICAL_DAMAGE or result==ACTION_RESULT_DOT_TICK or result==ACTION_RESULT_DOT_TICK_CRITICAL) and amount>0 then
      if run.lastTargetHit then run.targetSeconds=run.targetSeconds+math.min(2,math.max(0,now()-run.lastTargetHit)) end
      run.lastTargetHit=now()
    end
    if result==ACTION_RESULT_HEAL_ABSORBED then run.healAbsorbed=run.healAbsorbed+amount end
  end
  if targetIsMe and (result==ACTION_RESULT_DAMAGE or result==ACTION_RESULT_CRITICAL_DAMAGE) then run.damageTaken=run.damageTaken+amount end
  if targetIsMe and result==ACTION_RESULT_BLOCKED_DAMAGE then run.blocked=run.blocked+amount end
  if targetIsMe and result==ACTION_RESULT_DAMAGE_SHIELDED then run.shieldEvents=run.shieldEvents+1 end
  if sourceIsMe and (result==ACTION_RESULT_DAMAGE_SHIELDED or result==ACTION_RESULT_ABSORBED) then run.shield=run.shield+amount end
  -- Taunt counted only from explicit TAUNTED result; availability depends on ESO event stream.
  if sourceIsMe and result==ACTION_RESULT_INTERRUPT then run.interrupts=run.interrupts+1 end
  if sourceIsMe and (result==ACTION_RESULT_STUNNED or result==ACTION_RESULT_DISORIENTED) then run.ccEvents=run.ccEvents+1 end
  -- Standalone curated data adapted from CrutchAlerts; no runtime dependency.
  local zoneId=run.zoneId
  local known=dungeonAbility(zoneId,abilityId)
  if known and not sourceIsMe then
    local k=tostring(abilityId)
    local a=run.abilities[k] or {name=abilityName,count=0,source=sourceName}
    a.count=a.count+1;run.abilities[k]=a
  end

end
local function effect(_,changeType,effectSlot,effectName,unitTag,beginTime,endTime,stackCount,iconName,buffType,effectType,abilityType,statusEffectType,unitName,unitId,abilityId,sourceType)
  if not run or not run.combatStart or not abilityId then return end
  if changeType~=EFFECT_RESULT_GAINED and changeType~=EFFECT_RESULT_UPDATED then return end
  local isGroup=unitTag and (unitTag=="player" or unitTag:match("^group%d+$"))
  local isEnemy=unitTag and (unitTag:match("^boss%d+$") or unitTag=="reticleover")
  local kind
  if isGroup and buffType==BUFF_EFFECT_TYPE_BUFF then kind="buff"
  elseif isEnemy and buffType==BUFF_EFFECT_TYPE_DEBUFF then kind="debuff" end
  local registered=supportRegistry[effectName or ""]
  if registered=="buff" or registered=="debuff" then kind=registered end
  if registered=="instant" or registered=="passive" then return end
  if not kind then return end
  -- Ultimates may apply ordinary named effects; associate observed effects
  -- with recent ultimate casts and exclude them from uptime requirements.
  if isUltimateAbility(abilityId) then return end
  if run.lastUltimateAt and now()-run.lastUltimateAt<1.5
    and (effectName=="Barrier" or effectName=="Major Force" or effectName=="Major Protection") then return end
  -- The effect can have a different ID from the skill that generated it.
  -- Accept direct player attribution OR a recent cast with the same ID.
  local key=tostring(abilityId)
  local cast=run.recentCasts[key]
  local attributed=(sourceType==COMBAT_UNIT_TYPE_PLAYER or sourceType==COMBAT_UNIT_TYPE_PLAYER_PET)
    or (cast and now()-cast.at<=2.5)
  -- ESO frequently uses a distinct effect ID. Correlate a very recent
  -- locally cast ability by its name, without accepting arbitrary group buffs.
  if not attributed then
    for castId,info in pairs(run.recentCasts) do
      if now()-info.at<=1.25 then
        local castName=safe(GetAbilityName,tonumber(castId))
        if castName and effectName and castName:lower()==effectName:lower() then
          attributed=true;break
        end
      end
    end
  end
  if not attributed then return end
  if cast and cast.ultimate then return end
  local duration=tonumber(endTime) and tonumber(beginTime) and (endTime-beginTime) or nil
  if not duration or duration<=0 then return end
  -- Do not permanently blacklist effects merely because an ultimate was cast.
  trackDuration(abilityId,kind,duration,effectName)
  if kind=="buff" or kind=="debuff" then
    S.learnedBuffs=S.learnedBuffs or {}
    S.learnedBuffs[characterKey()]=S.learnedBuffs[characterKey()] or {}
    S.learnedBuffs[characterKey()][key]={name=effectName or "Effect",kind=kind,duration=duration,lastSeen=safe(GetTimeStamp) or 0}
  end
end

state=function(_,inCombat)
  if not run then return end
  if inCombat and not run.combatStart then
    run.combatStart=now();run.lastTargetHit=nil;run.fightDamage=0;run.fightHeal=0;run.fightStartDeaths=run.deaths
    for _,bucket in pairs(run.durationCoverage) do
      for _,e in pairs(bucket) do e.lastAccounted=now() end
    end
  elseif not inCombat and run.combatStart then
    for _,bucket in pairs(run.uptime) do for _,entry in pairs(bucket) do closeUptimeSegment(entry) end end
    if run.lastTargetHit then run.targetSeconds=run.targetSeconds+math.min(2,math.max(0,now()-run.lastTargetHit)) end
    if run.lastDotTick then run.dotSeconds=(run.dotSeconds or 0)+math.min(2,math.max(0,now()-run.lastDotTick)) end
    run.lastDotTick=nil
    run.lastTargetHit=nil
    for _,entry in pairs(run.uptime.dot) do entry.lastTick=nil end
    durationCoverageFlush()
    recordEncounter()
    run.lastFightSeconds=math.max(0.001,now()-run.combatStart)
    run.lastFightDamage=run.fightDamage;run.lastFightHeal=run.fightHeal
    run.combatSeconds=run.combatSeconds+run.lastFightSeconds;run.combatStart=nil
  end
end
local function abilityUsed(_,slotId)
  if not insideDungeon() then
    local id=safe(GetSlotBoundId,slotId)
    if id and id~=0 then
      local t=now(); for k,v in pairs(worldCasts) do if t-v.at>2.5 then worldCasts[k]=nil end end
      worldCasts[id]={at=t,name=safe(GetAbilityName,id)}
      local learned=S.learnedBuffs and S.learnedBuffs[characterKey()] and S.learnedBuffs[characterKey()][tostring(id)]
      if learned and tonumber(learned.duration) and learned.duration>0 and learned.kind=="debuff" then
        world.effects["cast:"..id]={name=(learned.name or "Effect").." (est.)",ending=t+learned.duration,kind="DEBUFF"}
      end
    end
  end
  if not run or not run.combatStart then return end
  local slot=tonumber(slotId)
  if not slot then return end
  local abilityId=safe(GetSlotBoundId,slot)
  if not abilityId or abilityId==0 then return end
  local key=tostring(abilityId)
  local ultimateSlot=(tonumber(ACTION_BAR_ULTIMATE_SLOT_INDEX) or 8)
  local isUltimateSlot=(slot==ultimateSlot)
  run.recentCasts[key]={at=now(),slot=slot,ultimate=isUltimateSlot}
  if isUltimateSlot then
    run.lastUltimateAt=now()
    return
  end
  -- Use the ESO ability duration when known. Only assign a category if
  -- the effect or combat events have established it; never infer from icon.
  local known=run.durationObserved[key]
  local learned=S.learnedBuffs and S.learnedBuffs[characterKey()] and S.learnedBuffs[characterKey()][key]
  if known then trackDuration(abilityId,known.kind,known.duration,known.name)
  elseif learned and tonumber(learned.duration) and learned.duration>0 then
    trackDuration(abilityId,learned.kind or "buff",learned.duration,learned.name)
  end
end
local function ultimateUsed(_,slotId)
  if not run or not run.combatStart or run.role~="HEAL" then return end
  if tonumber(slotId)~=(tonumber(ACTION_BAR_ULTIMATE_SLOT_INDEX) or 8) then return end
  local t=now()
  if t-ultimateLastAt<1.5 then return end
  ultimateLastAt=t
  run.ultimateUses=(run.ultimateUses or 0)+1
  run.ultimatePoints=(run.ultimatePoints or 0)+0.05
  run.ultimateSupportPending=t
  run.lastUltimateAt=t
end
local function dead(_,unitTag,isDead)
  if run and isDead then bossDeath(unitTag); if unitTag=="player" then run.deaths=run.deaths+1 elseif unitTag and unitTag:match("^group%d+$") then run.groupDeaths=run.groupDeaths+1 end end
end
local closeReport
local function tick()
  if safe(IsUnitInDungeon,"player") or safe(IsUnitInGroupDungeon,"player") or safe(IsInDungeon) then
    begin()
  else
    -- Only rearm after actually leaving the instance.
    finish()
    if not S.settings.previewWindows and closeReport and reportHUD and not reportHUD:IsHidden() then closeReport() end
    completedInstance=false
  end
  if run then bossChanged() end
  updateHUD()
  updatePlayerCard()
  updateWorld()
end
local function activityCompleted()
  -- ESO's native center-screen announcement uses this exact event.
  -- Restrict attribution to a run that is already active inside a dungeon.
  if not run then return end
  if not (safe(IsUnitInDungeon,"player") or safe(IsUnitInGroupDungeon,"player") or safe(IsInDungeon)) then return end
  completedInstance=true
  run.completionVerified=true
  run.checkpoint=run.checkpoint+1
  run.checkpoints[run.checkpoint]=now()-run.started
  say("Activity completion confirmed by ESO.")
  finish()
end
local function closeMenu()
  if not menu or menu:IsHidden() then return end
  menu:SetHidden(true)
  if KEYBIND_STRIP and menu.bindings then KEYBIND_STRIP:RemoveKeybindButtonGroup(menu.bindings) end
end
local function openMenu()
  if menu and not menu:IsHidden() then closeMenu();return end
  if not WINDOW_MANAGER then return end
  if not menu then
    menu=WINDOW_MANAGER:CreateTopLevelWindow("DungeonRatingMenu")
    menu:SetDimensions(850,565);menu:SetAnchor(CENTER,GuiRoot,CENTER);    menu:SetClampedToScreen(true);enableWindowDrag(menu,"career");applyWindowLayout(menu,"career")
    menu:SetHidden(true);menu:SetMouseEnabled(false)
    local bg=WINDOW_MANAGER:CreateControl(nil,menu,CT_BACKDROP)
    bg:SetAnchorFill();bg:SetCenterColor(0.035,0.031,0.025,0.98)
    bg:SetEdgeColor(0.66,0.51,0.29,0.95);-- no edge texture required
    TMEGoldFrame(menu)
    menu.title=WINDOW_MANAGER:CreateControl(nil,menu,CT_LABEL)
    menu.title:SetAnchor(TOPLEFT,menu,TOPLEFT,24,20)
    menu.title:SetDimensions(570,35);menu.title:SetFont("$(BOLD_FONT)|23|soft-shadow-thin")
    menu.body=WINDOW_MANAGER:CreateControl(nil,menu,CT_LABEL)
    menu.body:SetAnchor(TOPLEFT,menu,TOPLEFT,24,70)
    menu.body:SetDimensions(800,475);menu.body:SetFont("$(BOLD_FONT)|17|soft-shadow-thin")
  end
  if not menu.index then menu.index=1 end
  menu.scope=menu.scope or "CHARACTER"
  menu.items={"SETTINGS","CAREER","HISTORY","RUN DETAILS","ENCOUNTERS","TRENDS","RECORDS","SUMMARY","HEALER","DPS","TANK","BOSSES","PLAYERS","DIFFICULTY","SUPPORT","PROFITABILITY"}
  local function refresh()
    local page=menu.items[menu.index]
    menu.title:SetText("DUNGEON BUDDY  |  "..page)
    local content
    if page=="CAREER" then
      local count=0;local totalD,totalH,totalCombat,totalScore,bestScore,completed=0,0,0,0,0,0
      for _,h in ipairs(S.history) do
        if menu.scope=="ACCOUNT" or h.character==safe(GetUnitName,"player") then
        count=count+1;totalD=totalD+(h.damage or 0);totalH=totalH+(h.rawHealing or h.heal or 0)
        totalCombat=totalCombat+(h.combatSeconds or 0);totalScore=totalScore+(h.score or 0)
        bestScore=math.max(bestScore,h.score or 0);if h.completionVerified then completed=completed+1 end
        end
      end
      content=string.format("%s SCOPE  |  X: switch character/account\nPVE CAREER  |  %d runs  |  %d verified clears\nAverage score: %.1f  |  Best score: %.1f\nTotal damage: %s\nRaw healing: %s\nOverall combat DPS: %s  |  HPS: %s\n\nSelect HISTORY to browse runs and RUN DETAILS for full statistics.",menu.scope,count,completed,totalScore/math.max(1,count),bestScore,fmt(totalD),fmt(totalH),fmt(totalD/math.max(1,totalCombat)),fmt(totalH/math.max(1,totalCombat)))
    elseif page=="HISTORY" then
      local n=#S.history;menu.historyIndex=math.max(1,math.min(n,menu.historyIndex or n))
      content="DUNGEON HISTORY  |  "..n.." recorded runs\nL1/R1: cycle runs   |   X: view details\n"
      for i=math.min(n,menu.historyIndex+4),math.max(1,menu.historyIndex-4),-1 do
        local h=S.history[i]
        content=content..string.format("\n%s %d. %s | %s | %.1f %s",i==menu.historyIndex and ">" or " ",i,tostring(h.zone),tostring(h.mode),h.score or 0,tostring(h.grade or ""))
      end
    elseif page=="PROFITABILITY" then
      local groups={};for _,h in ipairs(S.history) do
        if h.completionVerified and h.goldEarned~=nil then
          local key=tostring(h.zone).." | "..tostring(h.mode).." | "..tostring(h.goldSource)
          local g=groups[key] or {name=key,n=0,gold=0,seconds=0};groups[key]=g;g.n=g.n+1;g.gold=g.gold+h.goldEarned;g.seconds=g.seconds+(h.seconds or 0)
        end
      end
      local rows={};for _,g in pairs(groups) do rows[#rows+1]=g end
      table.sort(rows,function(a,b) return a.gold/math.max(1,a.seconds)>b.gold/math.max(1,b.seconds) end)
      content="DUNGEON PROFITABILITY | Verified clears | Ranked by gold/hour"
      for i=1,math.min(8,#rows) do local g=rows[i];content=content..string.format("\n%s\n%d runs | ~%sg/run | ~%sg/h",g.name,g.n,fmt(g.gold/g.n),fmt(g.gold*3600/math.max(1,g.seconds))) end
      if #rows==0 then content=content.."\nNo valued clears yet" end
    elseif page=="RUN DETAILS" then
      local h=S.history[menu.historyIndex or #S.history]
      if not h then content="No saved runs yet" else
        local t=math.max(1,h.combatSeconds or 0)
        content=string.format("%s  |  %s  |  %s\nScore %.1f (%s)  |  %s\nDuration %s  |  Combat %s\nOverall DPS %s  |  Overall HPS %s\nTotal damage %s\nTotal healing %s\n%s\nDeaths %d  |  Boss kills %d\nVerified clear: %s\nScoring version: %s",tostring(h.zone),tostring(h.mode),tostring(h.role),h.score or 0,tostring(h.grade),tostring(h.character or "Character"),clock(h.seconds or 0),clock(h.combatSeconds or 0),fmt(h.overallDPS or (h.damage or 0)/t),fmt(h.overallHPS or (h.heal or 0)/t),fmt(h.damage),fmt(h.rawHealing or h.heal),roleMetricLines(h),h.deaths or 0,h.bossKills or 0,h.completionVerified and "YES" or "NO",tostring(h.scoringVersion or "legacy")).."\n"..goldLine(h)
      end
    elseif page=="ENCOUNTERS" then
      local h=S.history[menu.historyIndex or #S.history]
      if not h then content="No saved runs yet" else
        content="ENCOUNTER HISTORY  |  "..tostring(h.zone).."\n"
        local list=h.encounters or {}
        if #list==0 then content=content.."No detailed encounter records (legacy run or no combat)" end
        for i,e in ipairs(list) do
          if i<=12 then content=content..string.format("\n%d. %s  %s\n    DPS %s  HPS %s  DMG %s  RAW %s  Deaths %d",i,e.boss or "Combat encounter",clock(e.duration or 0),fmt(e.dps),fmt(e.hps),fmt(e.damage),fmt(e.rawHealing),e.deaths or 0) end
        end
      end
    elseif page=="TRENDS" then
      content="PERFORMANCE TRENDS  |  Recent 10 recorded runs\n"
      local recent={};local maxScore=1
      for i=#S.history,1,-1 do
        local h=S.history[i]
        if menu.scope=="ACCOUNT" or h.character==safe(GetUnitName,"player") then
          table.insert(recent,h);maxScore=math.max(maxScore,h.score or 0)
          if #recent==10 then break end
        end
      end
      if #recent==0 then content=content.."No run history yet" end
      for i=#recent,1,-1 do
        local h=recent[i]
        local bars=math.floor(16*(h.score or 0)/maxScore+0.5)
        content=content..string.format("\n%s %s %.1f | DPS %s HPS %s",string.rep("#",bars),string.rep("-",16-bars),h.score or 0,fmt(h.overallDPS),fmt(h.overallHPS))
      end
      content=content.."\nScores are normalized to the highest displayed run."
    elseif page=="RECORDS" then
      local keys={}
      for key,entry in pairs(S.personalBests or {}) do
        if menu.scope=="ACCOUNT" or key:sub(1,#(safe(GetUnitName,"player") or "")+1)==(safe(GetUnitName,"player") or "").."|" then
          table.insert(keys,{key=key,entry=entry})
        end
      end
      table.sort(keys,function(a,b)return a.key<b.key end)
      menu.recordIndex=math.max(1,math.min(#keys,menu.recordIndex or 1))
      content="PERSONAL RECORDS  |  "..menu.scope.."\nD-pad: select record  |  X: switch scope\n"
      if #keys==0 then content=content.."No verified clear records yet" end
      for i=math.max(1,menu.recordIndex-3),math.min(#keys,menu.recordIndex+3) do
        local k=keys[i]
        local character,dungeon,mode,r=k.key:match("^(.-)|(.-)|(.-)|(.+)$")
        content=content..string.format("\n%s %s / %s / %s\n    Best %.1f | Fastest %s | DPS %s | HPS %s | Role %.1f%%",i==menu.recordIndex and ">" or " ",dungeon or "?",mode or "?",r or "?",k.entry.score or 0,clock(k.entry.fastest or 0),fmt(k.entry.bestDPS),fmt(k.entry.bestHPS),k.entry.bestBuff or 0)
      end
    elseif page=="SUMMARY" then
      local h=run or S.history[#S.history]
      content="Saved runs: "..S.runs.."\n"..(run and "ACTIVE RUN" or "LAST RUN")
      if h then content=content.."\n"..tostring(h.zone).." | "..tostring(h.role).." | "..clock(h.activeSeconds or h.seconds or 0).."\nDamage: "..fmt(h.damage).." | Healing: "..fmt(h.heal).."\nDPS: "..fmt(h.damage/math.max(1,h.activeSeconds or h.seconds or 1)).." | HPS: "..fmt(h.heal/math.max(1,h.activeSeconds or h.seconds or 1)).."\nScore: "..string.format("%.1f",run and score() or h.score).." | "..(h.completionVerified and "Verified clear" or "Unverified run") end
    elseif page=="BOSSES" then
      local h=run or S.history[#S.history]
      content=h and ("Verified boss deaths: "..tostring(h.bossKills or 0).."\n"..(h.activeBoss and ("ACTIVE: "..h.activeBoss.name) or "No active boss")) or "No dungeon data yet"
      if h and h.bosses then
        local count=0
        for _,b in pairs(h.bosses) do
          if count<8 then content=content.."\n"..tostring(b.name).." | "..(b.defeated and "DEFEATED" or "OBSERVED") end
          count=count+1
        end
      end
      content=content.."\nBoss disappearance alone never counts as a kill."
    elseif page=="PLAYERS" then
      local n=0;for _ in pairs(S.players) do n=n+1 end
      content="Encountered players: "..n.."\nUse /dr player NAME for encounter history."
    elseif page=="DIFFICULTY" then
      local tier,mode=difficulty();content=(zone() or "Unknown").." | "..mode.." | "..tier.."\nCommunity estimate, not an official ZOS rank"
    elseif page=="SUPPORT" then
      content=run and ("Shield: "..fmt(run.shield).."\nBlocked: "..fmt(run.blocked).."\nTaunts: "..fmt(run.taunts).."\nGroup deaths: "..fmt(run.groupDeaths).."\nInterrupts: "..run.interrupts.."\nCC: "..run.ccEvents.."\nBuff seconds: "..fmt(run.buffSeconds)) or "Enter a dungeon to view support measurements"
    elseif page=="SETTINGS" then
      menu.settingKeys={"careerProfile","showHUD","showBossHUD","showPace","showTrend","autoReport","showRollingEffects"}
      menu.settingNames={"Open Career Profile","Live HUD","Boss reference","PB pace","Score trend","Auto report","Rolling effects HUD"}
      menu.settingIndex=menu.settingIndex or 1
      content="SETTINGS  |  L1/R1 select setting, X activate\n"
      for i,key in ipairs(menu.settingKeys) do
        content=content.."\n"..(i==menu.settingIndex and "> " or "  ")..menu.settingNames[i]..(key=="careerProfile" and "  [X: OPEN]" or (": "..(S.settings[key] and "ON" or "OFF")))
      end
    else
      local r=page=="HEALER" and "HEAL" or page
      local h=run or S.history[#S.history]
      content=page.." career rating: "..fmt(S.ratings[r])
      if h then
        local t=math.max(1,h.combatSeconds or 0)
        content=content.."\nLast/active run: "..tostring(h.role).."\nDamage: "..fmt(h.damage).." | DPS: "..fmt(h.damage/t).."\nHealing: "..fmt(h.heal).." | HPS: "..fmt(h.heal/t).."\nDeaths: "..fmt(h.deaths).." | Combat: "..fmt(h.combatSeconds or 0).."s"
      end
      if run then
        local p=scoreParts()
        content=content..string.format("\n%s (%.1f) | Buff %.1f | Healing %.1f | Damage %.1f | Utility %.1f | Death -%.1f",grade(score()),score(),p.buff,p.healing,p.damage,p.utility,p.penalty)
        content=content.."\nPerformance breakdown shown above"
      end
      content=content.."\nRole scoring uses attributed combat evidence. Unavailable metrics display N/A."
    end
    local navHint = (page=="HISTORY" or page=="RUN DETAILS") and "L1/R1: cycle runs" or page=="SETTINGS" and "L1/R1: select setting" or page=="RECORDS" and "L1/R1: cycle records" or "L1/R1: change page"
    menu.body:SetText(content.."\n\nL2/R2: previous/next page  |  "..navHint.."\nX: choose  |  Circle: back / close")
    fitBody(menu,menu.body,70,180,16)
  end
  menu.refresh=refresh
  menu:SetHidden(false);refresh()
  if KEYBIND_STRIP and not menu.bindings then
    menu.bindings={
      {alignment=KEYBIND_STRIP_ALIGN_LEFT,name="Previous page",keybind="UI_SHORTCUT_LEFT_TRIGGER",callback=function()
        menu.index=menu.index==1 and #menu.items or menu.index-1
        menu.refresh()
      end},
      {alignment=KEYBIND_STRIP_ALIGN_LEFT,name="Next page",keybind="UI_SHORTCUT_RIGHT_TRIGGER",callback=function()
        menu.index=menu.index==#menu.items and 1 or menu.index+1
        menu.refresh()
      end},
      {alignment=KEYBIND_STRIP_ALIGN_LEFT,name="Previous",keybind="UI_SHORTCUT_LEFT_SHOULDER",callback=function()
        local page=menu.items[menu.index]
        if page=="HISTORY" or page=="RUN DETAILS" then menu.historyIndex=math.min(#S.history,math.max(1,(menu.historyIndex or #S.history)+1))
        elseif page=="SETTINGS" then menu.settingIndex=(menu.settingIndex or 1)-1;if menu.settingIndex<1 then menu.settingIndex=#menu.settingKeys end
        elseif page=="RECORDS" then menu.recordIndex=math.max(1,(menu.recordIndex or 1)-1)
        else menu.index=menu.index==1 and #menu.items or menu.index-1 end
        menu.refresh()
      end},
      {alignment=KEYBIND_STRIP_ALIGN_LEFT,name="Next",keybind="UI_SHORTCUT_RIGHT_SHOULDER",callback=function()
        local page=menu.items[menu.index]
        if page=="HISTORY" or page=="RUN DETAILS" then menu.historyIndex=math.max(1,(menu.historyIndex or #S.history)-1)
        elseif page=="SETTINGS" then menu.settingIndex=(menu.settingIndex or 1)%#menu.settingKeys+1
        elseif page=="RECORDS" then menu.recordIndex=(menu.recordIndex or 1)+1
        else menu.index=menu.index==#menu.items and 1 or menu.index+1 end
        menu.refresh()
      end},
      {alignment=KEYBIND_STRIP_ALIGN_LEFT,name="Toggle setting",keybind="UI_SHORTCUT_PRIMARY",callback=function()
        if menu.items[menu.index]=="HISTORY" then menu.index=4;menu.refresh()
        elseif menu.items[menu.index]=="CAREER" or menu.items[menu.index]=="RECORDS" or menu.items[menu.index]=="TRENDS" then menu.scope=menu.scope=="ACCOUNT" and "CHARACTER" or "ACCOUNT";menu.refresh()
        elseif menu.items[menu.index]=="SETTINGS" then
          local key=menu.settingKeys[menu.settingIndex or 1]
          if key=="careerProfile" then menu.index=2;menu.refresh() elseif key then S.settings[key]=not S.settings[key];menu.refresh() end
        end
      end},
      {alignment=KEYBIND_STRIP_ALIGN_RIGHT,name="Back / Close",keybind="UI_SHORTCUT_NEGATIVE",callback=function() if menu.index==4 then menu.index=3;menu.refresh() elseif menu.index~=1 then menu.index=1;menu.refresh() else closeMenu() end end}
    }
  end
  if KEYBIND_STRIP and menu.bindings then KEYBIND_STRIP:AddKeybindButtonGroup(menu.bindings) end
end
closeReport=function()
  if not reportHUD then return end
  reportHUD:SetHidden(true)
  if KEYBIND_STRIP and reportHUD.bindings then KEYBIND_STRIP:RemoveKeybindButtonGroup(reportHUD.bindings) end
end
openReport=function(h)
  if not WINDOW_MANAGER or not h then return end
  if not reportHUD then
    reportHUD=makePanel("DungeonRatingPerformanceReport",720,510,350,190)
    enableWindowDrag(reportHUD,"report");applyWindowLayout(reportHUD,"report")
    reportHUD.title=makeLabel(reportHUD,16,22,{0.95,0.78,0.43},620)
    reportHUD.body=makeLabel(reportHUD,62,16,{1,1,1},690)
    reportHUD.body:SetDimensions(690,435)
    reportHUD.bindings={{alignment=KEYBIND_STRIP_ALIGN_RIGHT,name="Close report",keybind="UI_SHORTCUT_NEGATIVE",callback=function()
      closeReport()
    end}}
  end
  reportHUD.title:SetText("DUNGEON BUDDY  |  PERFORMANCE REPORT")
  local p=h.scoreParts or {}
  reportHUD.body:SetText(string.format("%s  |  %s  |  %s\nFINAL SCORE  %.1f  |  %s\nRun %s  |  Combat %s\n\nDamage %s  |  Overall DPS %s\nTotal healing %s  |  Overall HPS %s\n%s\nDeaths: %d  |  Boss kills: %d\n\nRole uptime %.1f  Healing %.1f  Damage %.1f  Utility %.1f  Death penalty -%.1f\n\nCircle: close",tostring(h.zone),tostring(h.mode),tostring(h.role),h.score or 0,tostring(h.grade),clock(h.seconds or 0),clock(h.combatSeconds or 0),fmt(h.damage),fmt(h.overallDPS),fmt(h.rawHealing or h.heal),fmt(h.overallHPS),roleMetricLines(h)..(h.role=="HEAL" and string.format("\nUltimate Score: +%.2f",h.ultimatePoints or 0) or ""),h.deaths or 0,h.bossKills or 0,p.buff or 0,p.healing or 0,p.damage or 0,p.utility or 0,p.penalty or 0))

  reportHUD.body:SetText(reportHUD.body:GetText().."\n"..goldLine(h))
  fitBody(reportHUD,reportHUD.body,62,180,14)
  reportHUD:SetHidden(false)
  if KEYBIND_STRIP then KEYBIND_STRIP:AddKeybindButtonGroup(reportHUD.bindings) end
end
-- Same editable-chat-draft pattern as BG Rating: prepare first, player sends.
-- The prepared text is never automatically transmitted to chat.
local function prepareBossReport()
  local boss=run and run.activeBoss
  local context=(boss and boss.name and {zone=run.zone,name=boss.name}) or lastBossReportContext
  if not context then say("No boss identified yet. Engage a boss first.");return false end
  local ref=type(DungeonRatingFindBossReference)=="function" and DungeonRatingFindBossReference(context.zone,context.name)
  local tips={}
  if ref and type(ref.mechanics)=="table" then
    for i=1,math.min(3,#ref.mechanics) do
      local item=ref.mechanics[i]
      local tip=tostring(item.response or item.name or "")
      if tip~="" then tips[#tips+1]=tip end
    end
  end
  local detail=#tips>0 and table.concat(tips,"; ") or "Tank and spank."
  local text="Dungeon Buddy - Boss report: "..detail
  -- ESO chat limits are channel dependent. Keep a single short, editable draft.
  if #text>350 then text=text:sub(1,347).."..." end
  pendingBossReport={text=text,boss=context.name,channel=CHAT_CHANNEL_PARTY}
  say("Boss report prepared for "..context.name..". Use Open Prepared Boss Report to review it in Party chat.")
  return true
end
local function openBossReportDraft()
  if not pendingBossReport then say("No prepared boss report. Select Prepare Boss Report first.");return end
  if pendingBossReport.channel==nil then say("Party chat channel is unavailable.");return end
  local chat=type(ZO_GetChatSystem)=="function" and ZO_GetChatSystem() or nil
  if not chat or type(chat.StartTextEntry)~="function" then say("Editable chat input unavailable.");return end
  local ok,err=pcall(function() chat:StartTextEntry(pendingBossReport.text,pendingBossReport.channel,nil,true) end)
  if not ok then say("Could not open boss report draft: "..tostring(err)) end
end
-- Single radial-menu action: identify current/last boss, prepare its mechanics,
-- then open the editable party-chat draft. Sending remains manual.
function DungeonBuddy_PrepareBossReport()
  if prepareBossReport() then openBossReportDraft() end
end
function DungeonBuddy_OpenBossDraft() openBossReportDraft() end
local function command(s)
  s=(s or ""):lower()
  if s=="bossreport" then prepareBossReport()
  elseif s=="bossdraft" then openBossReportDraft()
  elseif s=="menu" then openMenu()
  elseif s=="close" then closeMenu()
  elseif s=="settings" then if not menu or menu:IsHidden() then openMenu() end;if menu then menu.index=1;menu.refresh() end
  elseif s=="diagnose" or s=="diag" then
    if not run then say("No active run; enter a dungeon and attack an enemy first") else
      say("Combat events: "..fmt(run.events).." | attributed to you: "..fmt(run.ownEvents).." | damage events: "..fmt(run.damageEvents).." | heal events: "..fmt(run.healEvents))
      say("Damage "..fmt(run.damage).." | Healing "..fmt(run.heal).." | DPS "..fmt(run.damage/math.max(1,combatDuration())).." | HPS "..fmt(run.heal/math.max(1,combatDuration())))
    end
  elseif s=="score" then
    if not run then say("Enter a dungeon for a live score breakdown") else
      local t=math.max(1,run.activeSeconds); local r=run.role
      local p=scoreParts()
      say("Score "..string.format("%.1f",score()).." ("..grade(score())..") | Role "..r.." | Combat DPS "..fmt(run.damage/math.max(1,combatDuration())).." | Combat HPS "..fmt(run.heal/math.max(1,combatDuration())))
      say(string.format("Breakdown: Role uptime %.1f | Healing %.1f | Damage %.1f | Utility %.1f | Death -%.1f",p.buff,p.healing,p.damage,p.utility,p.penalty))
      say("Scores start at zero; deaths subtract 5 points. Role uptime requires player-attributed evidence.")
    end
  elseif s=="hud on" then S.settings.showHUD=true; say("HUD on")
  elseif s=="hud off" then S.settings.showHUD=false; say("HUD off")
  elseif s=="role heal" or s=="role dps" or s=="role tank" then S.settings.manualRole=s:sub(6):upper();say("Role override "..S.settings.manualRole)
  elseif s=="role auto" then S.settings.manualRole="AUTO";say("Automatic role")
  elseif s=="pace on" then S.settings.showPace=true;say("Pace indicator on")
  elseif s=="pace off" then S.settings.showPace=false;say("Pace indicator off")
  elseif s=="trend on" then S.settings.showTrend=true;say("Trend indicator on")
  elseif s=="trend off" then S.settings.showTrend=false;say("Trend indicator off")
  elseif s=="history" then
    local count=#S.history; say("Saved runs: "..count)
    for i=math.max(1,count-4),count do local h=S.history[i]; if h then say(h.zone.." | "..h.role.." | "..clock(h.seconds).." | "..string.format("%.1f",h.score)) end end
  elseif s=="players" then
    local n=0;for _ in pairs(S.players) do n=n+1 end;say("Encountered players: "..n)
  elseif s:sub(1,7)=="player " then
    local name=s:sub(8);local found
    for k,v in pairs(S.players) do if k:lower()==name then found=v;name=k;break end end
    if found then say(name.." | encounters "..found.encounters) else say("No stored encounter for "..name) end
  elseif s=="abilities" then
    if not run then say("No active dungeon run") else
      local n=0
      for id,a in pairs(run.abilities) do
        n=n+1
        if n<=30 then say(id.." | "..tostring(a.name).." | "..a.count) end
      end
      say("Known encounter ability IDs observed: "..n)
    end
  elseif s=="catalog" then
    local n=0; for _,v in pairs(DungeonRatingEncounterData or {}) do for _ in pairs(v) do n=n+1 end end
    local scoped=0;local annotations=0;local phases=0
    local intel=DungeonRatingSourceIntelligence or {}
    for _,v in pairs(intel.zoneEvents or {}) do for _ in pairs(v) do scoped=scoped+1 end end
    for _ in pairs(intel.dungeonAbilityAnnotations or {}) do annotations=annotations+1 end
    for _,v in pairs(intel.bossHealthPhases or {}) do phases=phases+#v end
    say("Curated: "..n.." | zone script events: "..scoped.." | annotations: "..annotations.." | boss health phases: "..phases)
  elseif s=="difficulty" then
    local tier,mode=difficulty();say((zone() or "Unknown").." | "..mode.." | "..tier.." (community estimate)")
  elseif s=="support" then
    if run then say("Shield observed: "..fmt(run.shield).." | Blocked: "..fmt(run.blocked).." | Interrupts: "..run.interrupts.." | CC: "..run.ccEvents.." | Taunt: "..fmt(run.taunts or 0).." | Buff uptime observed: "..fmt(run.buffSeconds).."s") else say("No active dungeon") end
  elseif s=="bosses" then
    if not run then say("No active dungeon") else
      say("Verified boss deaths: "..tostring(run.bossKills or 0))
      for _,b in pairs(run.bosses) do say(b.name.." | "..(b.defeated and "DEFEATED" or "OBSERVED")) end
    end
  elseif s=="stats" then say("Runs: "..S.runs.." | DPS rating "..fmt(S.ratings.DPS).." | Healer rating "..fmt(S.ratings.HEAL).." | Tank rating "..fmt(S.ratings.TANK))
  elseif s=="complete" then
    if run then
      completedInstance=true
      run.completionVerified=true
      run.checkpoint=run.checkpoint+1
      run.checkpoints[run.checkpoint]=now()-run.started
      finish()
    else say("No active dungeon") end
  elseif s=="checkpoint" then
    if run then run.checkpoint=run.checkpoint+1;run.checkpoints[run.checkpoint]=now()-run.started;say("Checkpoint "..run.checkpoint.." saved") end
  elseif s=="finish" then finish()
  else say("Commands: /dr menu | close | diagnose | score | difficulty | support | catalog | abilities | stats | history | players | player NAME | hud on/off | pace on/off | trend on/off | role auto/heal/dps/tank | checkpoint | complete | finish") end
end
-- Dependency-free access: ESO's built-in Controls > Keybindings > Addon Keys.
-- ESO does not expose a documented general-purpose registration API for an
-- arbitrary third-party panel inside the native Add-Ons settings list.
-- This deliberately does not mutate protected gamepad settings internals.
function DungeonBuddy_ToggleMenu()
  if S then openMenu() end
end
function DungeonBuddy_OpenSettings()
  if not S then return end
  if menu and not menu:IsHidden() then closeMenu() end
  openMenu()
  if menu then menu.index=1;menu.refresh() end
end

-- ESO Add-Ons Settings integration through LibAddonMenu-2.0.
-- Career Profile is a first-class button on the Dungeon Buddy settings panel.
local settingsRegistered=false
local function openCareerFromSettings()
  if not S then return end
  if menu and not menu:IsHidden() then closeMenu() end
  openMenu()
  if menu and menu.items then
    for i,page in ipairs(menu.items) do
      if page=="CAREER" then menu.index=i; break end
    end
    if menu.refresh then menu.refresh() end
  end
end
local function setWindowPreview(enabled)
  if not S then return end
  S.settings.previewWindows=enabled==true
  ensureHUD()
  if hud then
    if enabled and not run then
      hud.header:SetText("DUNGEON BUDDY  |  HEALER PREVIEW")
      hud.diff:SetText("Veteran  |  Dungeon preview")
      hud.timer:SetText("RUN TIME  12:34")
      hud.fight:SetText("CURRENT FIGHT  DPS 1,250/s  |  HPS 8,500/s")
      hud.overall:SetText("DUNGEON AVG  DPS 1,100/s  |  HPS 7,900/s")
      hud.damage:SetText("TOTAL DAMAGE  125000")
      hud.healing:SetText("TOTAL HEALING  950000")
      hud.score:SetText("SCORE  28.5  |  GREAT")
      hud.pace:SetText("PACE PREVIEW")
      hud.buff:SetText("BUFF UPTIME  85.0%  |  ELITE")
      hud.role2:SetText("")
    end
    hud:SetHidden(not (enabled or (run and S.settings.showHUD)))
  end
  if bossHUD then
    bossHUD:SetHidden(not enabled)
    if enabled then
      bossHUD.header:SetText("BOSS INTELLIGENCE  |  PREVIEW")
      bossHUD.name:SetText("Boss Preview")
      bossHUD.mechanic:SetText("1. Avoid the heavy attack\n2. Interrupt the channel\n3. Move out of the area")
      bossHUD.response:SetText("PREVIEW")
      bossHUD.source:SetText("REFERENCE GUIDE")
    end
  end
  if enabled and not reportHUD then
    -- Preview without recording a run.
    openReport({zone="DUNGEON PREVIEW",mode="Veteran",role="HEAL",score=28.5,grade="GREAT",seconds=750,combatSeconds=480,damage=125000,overallDPS=260,rawHealing=950000,overallHPS=1979,buffUptime=85,deaths=0,bossKills=3,scoreParts={}})
  end
  if reportHUD then
    reportHUD:SetHidden(not enabled)
    if not enabled and KEYBIND_STRIP and reportHUD.bindings then KEYBIND_STRIP:RemoveKeybindButtonGroup(reportHUD.bindings) end
  end
  if menu and not menu:IsHidden() then applyWindowLayout(menu,"career") end
  updatePlayerCard()
end
local function registerAddonSettings()
  if settingsRegistered or not S then return end
  local lam=TMENexus.settingsProxy
  if not lam or type(lam.RegisterAddonPanel)~="function" or type(lam.RegisterOptionControls)~="function" then return end
  local panelId="DungeonBuddyOptionsPanel"
  local ok,err=pcall(function()
    lam:RegisterAddonPanel(panelId,{
      type="panel", name="Dungeon Buddy", displayName="Dungeon Buddy",
      author="Trash Man Enterprises", version=DR.version,
      registerForRefresh=true, registerForDefaults=true,
    })
    local actions={
      {type="button",name="Prepare Boss Report",tooltip="Prepare an editable Party chat report from the current or most recently detected boss mechanics. Nothing is sent automatically.",func=prepareBossReport,width="full"},
       {type="button",name="Open Prepared Boss Report",tooltip="Open the prepared boss mechanics in editable Party chat. You must press Send yourself.",func=openBossReportDraft,width="full"},
       {type="button",name="Close End-of-Run Report",tooltip="Dismiss the current report without affecting saved history.",func=closeReport,width="full"},
      {type="button",name="Open Career Profile",tooltip="Open career statistics, records, and dungeon run history.",func=openCareerFromSettings,width="full"},
      {type="button",name="Open Dungeon Buddy Settings",tooltip="Open the controller-friendly Dungeon Buddy settings window.",func=function()
        if menu and not menu:IsHidden() then closeMenu() end
        openMenu()
        if menu and menu.items then
          for i,page in ipairs(menu.items) do if page=="SETTINGS" then menu.index=i;break end end
          if menu.refresh then menu.refresh() end
        end
      end,width="full"},
    }
    local options={actions[4]}
    local function section(name,controls)
      options[#options+1]={type="submenu",name=name,controls=controls}
    end
    local function toggles(toggles)
      local controls={}
    for _,item in ipairs(toggles) do
      local key,label=item[1],item[2]
      controls[#controls+1]={type="checkbox",name=label,
        getFunc=function() return S.settings[key]==true end,
        setFunc=function(v) S.settings[key]=(v==true); if menu and menu.refresh and not menu:IsHidden() then menu.refresh() end end,
        default=defaults.settings[key],width="full"}
    end
      return controls
    end
    section("Combat HUDs",toggles({{"showHUD","Dungeon combat meter"},{"showWorldHUD","World combat meter"},{"showPlayerCard","Out-of-dungeon player card"},{"showBossHUD","Boss intelligence"}}))
    section("Rolling Effects & Refresh Alerts",toggles({{"showRollingEffects","Rolling buff / debuff text"},{"showRefreshHighlights","Action bar refresh highlights"}}))
    section("Performance & Reports",toggles({{"showPace","Performance pace"},{"showTrend","Score trend"},{"autoReport","Automatic end-of-run report"}}))
    options[#options+1]={type="header",name="HUD placement"}
    local preview={type="checkbox",name="Preview HUD windows",tooltip="Show Live HUD, Boss Intelligence and End-of-Run report while arranging windows. Drag windows with a mouse or use the position sliders.",getFunc=function() return S.settings.previewWindows==true end,setFunc=setWindowPreview,default=false,width="full"}
    options[#options+1]=preview
    local layouts={}
    local windowNames={rollingBuff="Rolling Buffs (left)",rollingDebuff="Rolling Debuffs (right)",world="World Combat HUD",live="Live HUD",boss="Boss Intelligence",report="End-of-Run HUD",career="Career Profile",playerCard="Out-of-Dungeon Player Card"}
    local windowOrder={"rollingBuff","rollingDebuff","world","live","boss","report","career","playerCard"}
    for _,key in ipairs(windowOrder) do
      local title=windowNames[key]
      local controls={}
      for _,axis in ipairs({"x","y"}) do
        local coord=axis
        controls[#controls+1]={type="slider",name=coord=="x" and "Horizontal position" or "Vertical position",min=(key=="rollingBuff" or key=="rollingDebuff") and -440 or 0,max=(key=="rollingBuff" or key=="rollingDebuff") and math.ceil((coord=="x" and GuiRoot:GetWidth() or GuiRoot:GetHeight())/5)*5 or 1800,step=5,getFunc=function() return S.settings.windowLayout[key][coord] end,setFunc=function(v) S.settings.windowLayout[key][coord]=v;refreshWindowLayouts() end,default=defaults.settings.windowLayout[key][coord],width="full"}
      end
      controls[#controls+1]={type="slider",name="Size (%)",min=50,max=200,step=5,getFunc=function() return S.settings.windowLayout[key].scale end,setFunc=function(v) S.settings.windowLayout[key].scale=v;refreshWindowLayouts() end,default=100,width="full"}
      layouts[key]=controls
    end
    for _,key in ipairs(windowOrder) do section(windowNames[key].." layout",layouts[key]) end
    section("Report Tools & Advanced",{actions[1],actions[2],actions[3],actions[5]})
    lam:RegisterOptionControls(panelId,options)
  end)
  if ok then settingsRegistered=true else say("Dungeon Buddy settings registration error: "..tostring(err)) end
end

local radialRegistered=false
local function registerRadialMenu()
  if radialRegistered then return true end
  local lib=_G and _G.LibRadialMenu
  if type(lib)~="table" or type(lib.RegisterAddon)~="function" or type(lib.RegisterEntry)~="function" then return false end
  local ok,err=pcall(function()
    lib:RegisterAddon("DungeonRating","Dungeon Buddy")
    lib:RegisterEntry("DungeonRating","PREPARE BOSS REPORT","boss_report",
      "/esoui/art/icons/achievement_dungeon_001.dds",
      function() DungeonBuddy_PrepareBossReport() end,
      "Prepare the detected boss mechanics in editable Party chat. You press Send.")
  end)
  if ok then radialRegistered=true else say("LibRadialMenu registration failed: "..tostring(err)) end
  return radialRegistered
end
local function initialized(_,addon)
  if addon~="TMENexus" then return end
  S=ZO_SavedVars:NewAccountWide("NexusDungeonSaved",1,nil,defaults)
  S.settings.windowLayout=S.settings.windowLayout or {}
  TMENexus.applyDungeonLayout=function(minimal)
    local w,h=GuiRoot:GetWidth(),GuiRoot:GetHeight()
    local layout=S.settings.windowLayout
    layout.world={x=w*.02,y=h*.07,scale=80};layout.live={x=w*.02,y=h*.07,scale=80};layout.boss={x=w*.62,y=h*.24,scale=75}
    layout.rollingBuff={x=w*.18,y=h*.35,scale=90};layout.rollingDebuff={x=w*.68,y=h*.35,scale=90}
    layout.playerCard={x=w*.02,y=h*.3,scale=75}
    S.settings.showPlayerCard=false;S.settings.showWorldHUD=not minimal;S.settings.showRollingEffects=true;S.settings.showRefreshHighlights=true
    refreshWindowLayouts()
  end
  for key,layout in pairs(defaults.settings.windowLayout) do
    S.settings.windowLayout[key]=S.settings.windowLayout[key] or {x=layout.x,y=layout.y,scale=layout.scale}
  end
  SLASH_COMMANDS["/dr"]=command
  EM:RegisterForEvent(DR.name.."Combat",EVENT_COMBAT_EVENT,function(...) combat(...);worldCombat(...) end)
  if EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE then
    EM:RegisterForEvent(DR.name.."Complete",EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE,activityCompleted)
  end
  if EVENT_PLAYER_ACTIVATED then
    EM:RegisterForEvent(DR.name.."Activated",EVENT_PLAYER_ACTIVATED,function() tick() end)
  end
  EM:RegisterForEvent(DR.name.."State",EVENT_PLAYER_COMBAT_STATE,function(...) state(...);worldState(...) end)
  if EVENT_ACTION_SLOT_ABILITY_USED then EM:RegisterForEvent(DR.name.."Ultimates",EVENT_ACTION_SLOT_ABILITY_USED,function(...) abilityUsed(...);ultimateUsed(...);rollingCast(...) end) end
  if EVENT_BOSSES_CHANGED then EM:RegisterForEvent(DR.name.."Bosses",EVENT_BOSSES_CHANGED,bossChanged) end
  if EVENT_EFFECT_CHANGED then EM:RegisterForEvent(DR.name.."Effects",EVENT_EFFECT_CHANGED,function(...) effect(...);worldEffect(...);rollingEffect(...) end) end
  if EVENT_UNIT_DEATH_STATE_CHANGED then EM:RegisterForEvent(DR.name.."Dead",EVENT_UNIT_DEATH_STATE_CHANGED,dead) end
  EM:RegisterForUpdate(DR.name.."Tick",1000,tick)
  EM:RegisterForUpdate(DR.name.."RollingEffects",100,updateRolling)
  registerRadialMenu(); EM:RegisterForUpdate(DR.name.."RadialRetry",2500,function() if registerRadialMenu() then EM:UnregisterForUpdate(DR.name.."RadialRetry") end end)
  ensureHUD(); ensurePlayerCard(); updatePlayerCard(); registerAddonSettings(); EM:RegisterForUpdate(DR.name.."SettingsRetry",2000,function() if settingsRegistered then EM:UnregisterForUpdate(DR.name.."SettingsRetry") else registerAddonSettings() end end); say("v2.0.5 loaded. Career Profile is available in Add-Ons > Dungeon Buddy when LibAddonMenu-2.0 is installed.")
end
EM:RegisterForEvent(DR.name.."Init",EVENT_ADD_ON_LOADED,initialized)


-- TME Menu Visibility: independent of saved visibility and ongoing statistics.
-- Suppress presentation, not SetHidden state: existing timers/close actions remain authoritative.
local tmeMenuAlpha = setmetatable({}, {__mode="k"})
local function tmeMenuContext()
    if not SCENE_MANAGER then return false, false, false end
    local scene=SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene()
    local name=scene and scene.GetName and scene:GetName()
    local main=SCENE_MANAGER.IsShowing and SCENE_MANAGER:IsShowing("mainMenuGamepad")
    if main then return true,false,false end
    if not name then return false,false,false end
    local lower=string.lower(name)
    local gameplay=(lower=="hud" or lower=="hudui" or lower=="hudgamepad" or lower=="huduigamepad")
    local addon=lower:find("addon",1,true)~=nil or lower:find("libaddonmenu",1,true)~=nil or lower=="gamepadoptions" or lower=="gamepadoptionsroot"
    local map=lower:find("worldmap",1,true)~=nil or lower=="gamepadworldmap"
    return not gameplay,addon,map
end
local function tmeMenuSuppress(control, suppress)
    if not control then return end
    if suppress then
        if tmeMenuAlpha[control]==nil then tmeMenuAlpha[control]=control:GetAlpha() end
        if control:GetAlpha()~=0 then control:SetAlpha(0) end
    elseif tmeMenuAlpha[control]~=nil then
        control:SetAlpha(tmeMenuAlpha[control]);tmeMenuAlpha[control]=nil
    end
end

EVENT_MANAGER:RegisterForUpdate("DungeonRatingTME_MenuVisibility", 100, function()
    if not S then return end
    local blocked,addon=tmeMenuContext()
    local hide=blocked and not S.settings.previewWindows
    tmeMenuSuppress(hud,hide);tmeMenuSuppress(bossHUD,hide)
    tmeMenuSuppress(worldHUD,hide or (TMENexus.context~="World" and not S.settings.previewWindows));tmeMenuSuppress(playerCard,hide or (TMENexus.context~="World" and not S.settings.previewWindows))
    tmeMenuSuppress(reportHUD,hide)
    for _,p in pairs(rollingPanels) do tmeMenuSuppress(p,hide) end
    for _,g in pairs(refreshGlows) do tmeMenuSuppress(g,blocked) end
    tmeMenuSuppress(menu,hide and not addon)
end)
