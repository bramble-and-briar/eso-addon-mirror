ZO_CreateStringId("SI_BINDING_NAME_DUNGEON_BUDDY_TOGGLE_MENU", "Dungeon Buddy: Career & Settings")
ZO_CreateStringId("SI_BINDING_NAME_DUNGEON_BUDDY_OPEN_SETTINGS", "Dungeon Buddy: Open Settings")
ZO_CreateStringId("SI_BINDING_NAME_DUNGEON_BUDDY_OPEN_BOSS_DRAFT", "Dungeon Buddy: Open Prepared Boss Report")
ZO_CreateStringId("SI_BINDING_NAME_DUNGEON_BUDDY_PREPARE_BOSS_REPORT", "Dungeon Buddy: Prepare Boss Report (Radial)")
-- Dungeon Buddy (integrated v0.3)
-- Separate from Battle Ground Rating. Conservative event attribution.
local DR = {name="DungeonRating", version="0.3"}
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
local defaults={learnedBuffs={},ultimateEffectIds={},observedAbilities={},settings={showHUD=true,showPace=true,showTrend=true,manualRole="AUTO",difficultyLabels=true,showBossHUD=true,autoReport=true,showPlayerCard=true,previewWindows=false,windowLayout={live={x=200,y=180,scale=100},boss={x=720,y=180,scale=100},report={x=350,y=190,scale=100},career={x=330,y=150,scale=100},playerCard={x=220,y=90,scale=100}}},history={},players={},records={},ratings={HEAL=0,DPS=0,TANK=0},runs=0}
local S,run,hud,bossHUD,reportHUD,menu,playerCard
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
local function dotUptime() return roleUptime("dot") end
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
local buffGrade
local function roleMetricLines(h)
  local function line(label,v)
    return label..": "..(type(v)=="number" and string.format("%.1f%% | %s",v,buffGrade(v)) or "N/A")
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
    buff=((dotUptime() or 0)+(targetUptime() or 0))*0.08
    damage=clamp(dps/400,0,32)
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
  applyWindowLayout(hud,"live")
  applyWindowLayout(bossHUD,"boss")
  applyWindowLayout(reportHUD,"report")
  if menu then applyWindowLayout(menu,"career") end
  applyWindowLayout(playerCard,"playerCard")
end

-- TME shared blue frame; anchored strips follow resizing and scaling.
local function TMEBlueFrame(parent)
    local function edge(a,b,c,d,vertical)
        local t=WINDOW_MANAGER:CreateControl(nil,parent,CT_TEXTURE)
        t:SetAnchor(a,parent,b,0,0); t:SetAnchor(c,parent,d,0,0)
        if vertical then t:SetWidth(2) else t:SetHeight(2) end
        t:SetColor(0.20,0.65,0.90,0.95); t:SetMouseEnabled(false)
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
  bg:SetAnchorFill();bg:SetCenterColor(0.015,0.028,0.048,0.92);bg:SetEdgeColor(0.20,0.65,0.90,0.95)
  TMEBlueFrame(w)
  return w
end
local function ensureHUD()
  if hud or not WINDOW_MANAGER then return end
  hud=makePanel("DungeonRatingHUD",500,400,200,180)
  local labels={
    {"header",10,19,{0.95,0.78,0.43}},{"diff",40,14,{0.7,0.85,1}},
    {"timer",68,16,{1,1,1}},{"fight",103,17,{1,1,1}},
    {"overall",138,17,{1,1,1}},{"damage",174,15,{1,1,1}},
    {"healing",205,15,{1,1,1}},{"score",241,18,{0.98,0.86,0.55}},
    {"pace",275,15,{0.70,0.86,0.98}},{"buff",308,15,{0.70,0.95,0.76}},{"role2",340,15,{0.70,0.95,0.76}}}
  for _,a in ipairs(labels) do hud[a[1]]=makeLabel(hud,a[2],a[3],a[4]) end
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
  local visible=S.settings.previewWindows or (S.settings.showPlayerCard~=false and inDungeon and not run)
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
  hud.role2:SetText(run.role=="DPS" and ("TIME ON TARGET (EST.)  "..(target and string.format("%.1f%%  |  %s",target,buffGrade(target)) or "N/A")) or "")
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
  ensureHUD()
  if safe(IsUnitInCombat,"player") then state(nil,true) end
  say("Run started: "..run.zone.." ("..run.role..")")
end
local openReport
local function finish()
  if not run then return end
  run.activeSeconds=math.max(1,now()-run.started)
  if run.combatStart then state(nil,false) end
  local parts=scoreParts();local ct=combatDuration();local result={id=tostring(safe(GetTimeStamp) or 0)..":"..tostring(S.runs+1),scoringVersion="0.3",character=safe(GetUnitName,"player"),combatSeconds=ct,overallDPS=run.damage/math.max(1,ct),overallHPS=run.heal/math.max(1,ct),rawHealing=run.heal,ultimateUses=run.ultimateUses,ultimateSupportUses=run.ultimateSupportUses,ultimatePoints=run.ultimatePoints,effectiveHealingAvailable=(run.healEffective or 0)>0,buffUptime=buffUptime(),debuffUptime=debuffUptime(),dotUptime=dotUptime(),timeOnTarget=targetUptime(),scoreParts=parts,zone=run.zone,mode=run.mode or "Unknown",role=run.role,seconds=run.activeSeconds,score=score(),damage=run.damage,heal=run.heal,damageTaken=run.damageTaken,blocked=run.blocked,taunts=run.taunts,healEffective=run.healEffective,healAbsorbed=run.healAbsorbed,groupDeaths=run.groupDeaths,interrupts=run.interrupts,ccEvents=run.ccEvents,buffSeconds=run.buffSeconds,deaths=run.deaths,date=safe(GetTimeStamp) or 0,group=run.group,abilities=run.abilities,completionVerified=run.completionVerified==true,events=run.events,ownEvents=run.ownEvents,damageEvents=run.damageEvents,healEvents=run.healEvents,bossKills=run.bossKills,bosses=run.bosses,encounters=run.encounters,grade=grade(score())}
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
  run.ultimatePoints=(run.ultimatePoints or 0)+1
  run.ultimateSupportPending=t
  run.lastUltimateAt=t
end
local function dead(_,unitTag,isDead)
  if run and isDead then bossDeath(unitTag); if unitTag=="player" then run.deaths=run.deaths+1 elseif unitTag and unitTag:match("^group%d+$") then run.groupDeaths=run.groupDeaths+1 end end
end
local function tick()
  if safe(IsUnitInDungeon,"player") or safe(IsUnitInGroupDungeon,"player") or safe(IsInDungeon) then
    begin()
  else
    -- Only rearm after actually leaving the instance.
    finish()
    completedInstance=false
  end
  if run then bossChanged() end
  updateHUD()
  updatePlayerCard()
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
    bg:SetAnchorFill();bg:SetCenterColor(0.03,0.05,0.09,0.98)
    bg:SetEdgeColor(0.20,0.65,0.90,0.95);-- no edge texture required
    TMEBlueFrame(menu)
    menu.title=WINDOW_MANAGER:CreateControl(nil,menu,CT_LABEL)
    menu.title:SetAnchor(TOPLEFT,menu,TOPLEFT,24,20)
    menu.title:SetDimensions(570,35);menu.title:SetFont("$(BOLD_FONT)|23|soft-shadow-thin")
    menu.body=WINDOW_MANAGER:CreateControl(nil,menu,CT_LABEL)
    menu.body:SetAnchor(TOPLEFT,menu,TOPLEFT,24,70)
    menu.body:SetDimensions(800,475);menu.body:SetFont("$(BOLD_FONT)|17|soft-shadow-thin")
  end
  if not menu.index then menu.index=1 end
  menu.scope=menu.scope or "CHARACTER"
  menu.items={"SETTINGS","CAREER","HISTORY","RUN DETAILS","ENCOUNTERS","TRENDS","RECORDS","SUMMARY","HEALER","DPS","TANK","BOSSES","PLAYERS","DIFFICULTY","SUPPORT"}
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
    elseif page=="RUN DETAILS" then
      local h=S.history[menu.historyIndex or #S.history]
      if not h then content="No saved runs yet" else
        local t=math.max(1,h.combatSeconds or 0)
        content=string.format("%s  |  %s  |  %s\nScore %.1f (%s)  |  %s\nDuration %s  |  Combat %s\nOverall DPS %s  |  Overall HPS %s\nTotal damage %s\nTotal healing %s\n%s\nDeaths %d  |  Boss kills %d\nVerified clear: %s\nScoring version: %s",tostring(h.zone),tostring(h.mode),tostring(h.role),h.score or 0,tostring(h.grade),tostring(h.character or "Character"),clock(h.seconds or 0),clock(h.combatSeconds or 0),fmt(h.overallDPS or (h.damage or 0)/t),fmt(h.overallHPS or (h.heal or 0)/t),fmt(h.damage),fmt(h.rawHealing or h.heal),roleMetricLines(h),h.deaths or 0,h.bossKills or 0,h.completionVerified and "YES" or "NO",tostring(h.scoringVersion or "legacy"))
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
      menu.settingKeys={"careerProfile","showHUD","showBossHUD","showPace","showTrend","autoReport"}
      menu.settingNames={"Open Career Profile","Live HUD","Boss reference","PB pace","Score trend","Auto report"}
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
local function closeReport()
  if not reportHUD then return end
  reportHUD:SetHidden(true)
  if KEYBIND_STRIP and reportHUD.bindings then KEYBIND_STRIP:RemoveKeybindButtonGroup(reportHUD.bindings) end
end
openReport=function(h)
  if not WINDOW_MANAGER or not h then return end
  if not reportHUD then
    reportHUD=makePanel("DungeonRatingPerformanceReport",720,460,350,190)
    enableWindowDrag(reportHUD,"report");applyWindowLayout(reportHUD,"report")
    reportHUD.title=makeLabel(reportHUD,16,22,{0.95,0.78,0.43},620)
    reportHUD.body=makeLabel(reportHUD,62,16,{1,1,1},690)
    reportHUD.body:SetDimensions(690,380)
    reportHUD.bindings={{alignment=KEYBIND_STRIP_ALIGN_RIGHT,name="Close report",keybind="UI_SHORTCUT_NEGATIVE",callback=function()
      closeReport()
    end}}
  end
  reportHUD.title:SetText("DUNGEON BUDDY  |  PERFORMANCE REPORT")
  local p=h.scoreParts or {}
  reportHUD.body:SetText(string.format("%s  |  %s  |  %s\nFINAL SCORE  %.1f  |  %s\nRun %s  |  Combat %s\n\nDamage %s  |  Overall DPS %s\nTotal healing %s  |  Overall HPS %s\n%s\nDeaths: %d  |  Boss kills: %d\n\nRole uptime %.1f  Healing %.1f  Damage %.1f  Utility %.1f  Death penalty -%.1f\n\nCircle: close",tostring(h.zone),tostring(h.mode),tostring(h.role),h.score or 0,tostring(h.grade),clock(h.seconds or 0),clock(h.combatSeconds or 0),fmt(h.damage),fmt(h.overallDPS),fmt(h.rawHealing or h.heal),fmt(h.overallHPS),roleMetricLines(h)..(h.role=="HEAL" and string.format("\nUltimates %d | Ultimate score +%.1f",h.ultimateUses or 0,h.ultimatePoints or 0) or ""),h.deaths or 0,h.bossKills or 0,p.buff or 0,p.healing or 0,p.damage or 0,p.utility or 0,p.penalty or 0))

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
  local lam=LibAddonMenu2
  if not lam or type(lam.RegisterAddonPanel)~="function" or type(lam.RegisterOptionControls)~="function" then return end
  local panelId="DungeonBuddyOptionsPanel"
  local ok,err=pcall(function()
    lam:RegisterAddonPanel(panelId,{
      type="panel", name="Dungeon Buddy", displayName="Dungeon Buddy",
      author="Trash Man Enterprises", version=DR.version,
      registerForRefresh=true, registerForDefaults=true,
    })
    local options={
      {type="description",text="Dungeon Buddy performance HUD, End-of-Run report, and Career Profile."},
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
    local toggles={
      {"showHUD","Show Live HUD"},
      {"showPlayerCard","Show out-of-dungeon Player Card"},
      {"showBossHUD","Show Boss Intelligence HUD"},
      {"showPace","Show performance pace"},
      {"showTrend","Show score trend"},
      {"autoReport","Show End-of-Run report automatically"},
    }
    for _,item in ipairs(toggles) do
      local key,label=item[1],item[2]
      options[#options+1]={type="checkbox",name=label,
        getFunc=function() return S.settings[key]==true end,
        setFunc=function(v) S.settings[key]=(v==true); if menu and menu.refresh and not menu:IsHidden() then menu.refresh() end end,
        default=defaults.settings[key],width="full"}
    end
    options[#options+1]={type="header",name="Window positioning and size"}
    options[#options+1]={type="checkbox",name="Preview HUD windows",tooltip="Show Live HUD, Boss Intelligence and End-of-Run report while arranging windows. Drag windows with a mouse or use the position sliders.",getFunc=function() return S.settings.previewWindows==true end,setFunc=setWindowPreview,default=false,width="full"}
    local windowNames={live="Live HUD",boss="Boss Intelligence",report="End-of-Run HUD",career="Career Profile",playerCard="Out-of-Dungeon Player Card"}
    local windowOrder={"live","boss","report","career","playerCard"}
    for _,key in ipairs(windowOrder) do
      local title=windowNames[key]
      options[#options+1]={type="header",name=title}
      for _,axis in ipairs({"x","y"}) do
        local coord=axis
        options[#options+1]={type="slider",name=title.." "..(coord=="x" and "horizontal position" or "vertical position"),min=0,max=1800,step=5,getFunc=function() return S.settings.windowLayout[key][coord] end,setFunc=function(v) S.settings.windowLayout[key][coord]=v;refreshWindowLayouts() end,default=defaults.settings.windowLayout[key][coord],width="full"}
      end
      options[#options+1]={type="slider",name=title.." size (%)",min=50,max=200,step=5,getFunc=function() return S.settings.windowLayout[key].scale end,setFunc=function(v) S.settings.windowLayout[key].scale=v;refreshWindowLayouts() end,default=100,width="full"}
    end
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
  if addon~=DR.name then return end
  S=ZO_SavedVars:NewAccountWide("DungeonRatingSaved",1,nil,defaults)
  S.settings.windowLayout=S.settings.windowLayout or {}
  for key,layout in pairs(defaults.settings.windowLayout) do
    S.settings.windowLayout[key]=S.settings.windowLayout[key] or {x=layout.x,y=layout.y,scale=layout.scale}
  end
  SLASH_COMMANDS["/dr"]=command
  EM:RegisterForEvent(DR.name.."Combat",EVENT_COMBAT_EVENT,combat)
  if EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE then
    EM:RegisterForEvent(DR.name.."Complete",EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE,activityCompleted)
  end
  if EVENT_PLAYER_ACTIVATED then
    EM:RegisterForEvent(DR.name.."Activated",EVENT_PLAYER_ACTIVATED,function() tick() end)
  end
  EM:RegisterForEvent(DR.name.."State",EVENT_PLAYER_COMBAT_STATE,state)
  if EVENT_ACTION_SLOT_ABILITY_USED then EM:RegisterForEvent(DR.name.."Ultimates",EVENT_ACTION_SLOT_ABILITY_USED,function(...) abilityUsed(...);ultimateUsed(...) end) end
  if EVENT_BOSSES_CHANGED then EM:RegisterForEvent(DR.name.."Bosses",EVENT_BOSSES_CHANGED,bossChanged) end
  if EVENT_EFFECT_CHANGED then EM:RegisterForEvent(DR.name.."Effects",EVENT_EFFECT_CHANGED,effect) end
  if EVENT_UNIT_DEATH_STATE_CHANGED then EM:RegisterForEvent(DR.name.."Dead",EVENT_UNIT_DEATH_STATE_CHANGED,dead) end
  EM:RegisterForUpdate(DR.name.."Tick",1000,tick)
  registerRadialMenu(); EM:RegisterForUpdate(DR.name.."RadialRetry",2500,function() if registerRadialMenu() then EM:UnregisterForUpdate(DR.name.."RadialRetry") end end)
  ensureHUD(); ensurePlayerCard(); updatePlayerCard(); registerAddonSettings(); EM:RegisterForUpdate(DR.name.."SettingsRetry",2000,function() if settingsRegistered then EM:UnregisterForUpdate(DR.name.."SettingsRetry") else registerAddonSettings() end end); say("v0.3 loaded. Career Profile is available in Add-Ons > Dungeon Buddy when LibAddonMenu-2.0 is installed.")
end
EM:RegisterForEvent(DR.name.."Init",EVENT_ADD_ON_LOADED,initialized)
