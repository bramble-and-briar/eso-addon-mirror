-- Ramaladni Tracker v0.9.23 — Warden isolated runtime.
-- Mechanics copied from the v0.9.22 reference; other classes are not modified.
local M=RamaladniMastery
local shared=M.shared
local SkillState,LeadNow,HideState=shared.SkillState,shared.LeadNow,shared.HideState
local lead=shared.lead
local runtime={}
M.modules["Warden"]=runtime
do
local e={key="Warden:Tundra's Maw",class="Warden",en="Tundra's Maw",title="Утроба тундры / Tundra's Maw",passiveId=263519,candidateIDs={145977,263825},model="warden_proc",value=20,cap=0,target=true,kind="major_brittle_timer",mechanic="Track actual Major Brittle debuff (145977) from any source; Tundra's Maw upgrades Chilled",durationRule="Use actual ESO effect endTime; Tundra's Maw tooltip says 2.1 sec, but other sources may differ"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Warden:Wild Adaptation",class="Warden",en="Wild Adaptation",title="Приспособляемость леса / Wild Adaptation",passiveId=263520,candidateIDs={263826},model="target_status_number",value=333,cap=5,target=true,kind="target_status_count+numeric",mechanic="333 Weapon/Spell Damage per distinct recognized status effect on the current target, maximum +1665",durationRule="No intrinsic timer; do not count generic debuffs as statuses"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Warden:Glacial Obstinance",class="Warden",en="Glacial Obstinance",title="Ледяная непреклонность / Glacial Obstinance",passiveId=263521,candidateIDs={267305,267310},model="warden_proc",value=15,cap=0,target=false,kind="percent+timer",mechanic="Bond with Nature triggered by Winter Embrace cast + healing at full HP, own mastery proc only",durationRule="10 sec from confirmed own proc, client endTime preferred"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Warden:Green-Keeper's Hide",class="Warden",en="Green-Keeper's Hide",title="Покров хранителя лесов / Green-Keeper's Hide",passiveId=263522,candidateIDs={263828},model="attacker_status_percent",value=3,cap=5,target=false,kind="attacker_status_count+percent",mechanic="-3% incoming damage per distinct status effect on the attacker, up to -15%; attacker must be identified",durationRule="No intrinsic timer"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Warden:Bountiful Harvest",class="Warden",en="Bountiful Harvest",title="Обильная жатва / Bountiful Harvest",passiveId=263523,candidateIDs={61709,263829,263830,268258},model="warden_proc",value=0,cap=0,target=false,kind="major_heroism_timer",mechanic="Track player's actual Major Heroism buff; Bountiful Harvest grants it for 3 sec",durationRule="Actual ESO endTime (never infer 3 sec from a generic Major Heroism cast)"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end

-- Warden v0.9.12. The main addon still owns generic HUD and SavedVariables.
-- Tundra / Harvest are STATUS UPTIME indicators: show observed Major Brittle
-- and Major Heroism even when applied from another source, not proof that
-- the character's own class mastery caused the effect.
local WARDEN_TUNDRA="Warden:Tundra's Maw"
local WARDEN_WILD='Warden:Wild Adaptation'
local WARDEN_GLACIAL='Warden:Glacial Obstinance'
local WARDEN_HIDE="Warden:Green-Keeper's Hide"
local WARDEN_HARVEST='Warden:Bountiful Harvest'
local WARDEN_KEYS={WARDEN_TUNDRA,WARDEN_WILD,WARDEN_GLACIAL,WARDEN_HIDE,WARDEN_HARVEST}
local WARDEN_OWN_PROCS={
  [145977]=WARDEN_TUNDRA, -- generic Major Brittle (user-confirmed effect ID)
  [263825]=WARDEN_TUNDRA, -- possible Tundra-specific effect ID
  [267305]=WARDEN_GLACIAL,[267310]=WARDEN_GLACIAL,
  [61709]=WARDEN_HARVEST, -- generic Major Heroism (confirm against client)
  [263829]=WARDEN_HARVEST,[263830]=WARDEN_HARVEST,[268258]=WARDEN_HARVEST,
}
local WARDEN_GENERIC_EFFECT_IDS={ [145977]=true,[61709]=true }
local WARDEN_DEFAULT_DURATION={ [WARDEN_TUNDRA]=2.1,
  [WARDEN_GLACIAL]=10,[WARDEN_HARVEST]=3 }
local warden={procs={},status={at=-1,tag=nil,signature=nil,count=nil,types=nil},
  attackerName=nil,attackerId=nil,attackerAt=-100,debug=false,lastProcAt={},scanCount=0,
  combatStatusesById={},combatStatusesByName={},statusNameCache=nil}
local function WardenLearned(key)
  return SkillState(RamaladniMastery.byKey[key])==true
end
-- For the current reticle target, use the actual effect list as a fallback
-- when ESO does not emit an effect event for a newly acquired target.
local function IsMajorBrittle(id,name)
  if id==145977 or id==263825 then return true end
  if type(name)~='string' or name=='' then return false end
  if name=='Major Brittle' or name=='Великая хрупкость' then return true end
  local localized=GetAbilityName and GetAbilityName(145977)
  return type(localized)=='string' and localized~='' and name==localized
end
local function ScanTargetBrittle(now)
  if not (GetNumBuffs and GetUnitBuffInfo and DoesUnitExist and
          DoesUnitExist('reticleover')) then return end
  local unitName=GetUnitName and GetUnitName('reticleover')
  local bestEnd,bestId=0,nil
  for i=1,(GetNumBuffs('reticleover') or 0) do
    local name,_,endTime,_,_,_,_,_,_,_,id=GetUnitBuffInfo('reticleover',i)
    if IsMajorBrittle(id,name) and type(endTime)=='number' and endTime>bestEnd then
      bestEnd,bestId=endTime,id
    end
  end
  if bestEnd>now then
    warden.procs[WARDEN_TUNDRA]={active=true,untilTime=bestEnd,
      observedId=bestId,estimated=false,unitName=unitName}
  else
    -- Don't let an old event incorrectly display Brittle on this target.
    local previous=warden.procs[WARDEN_TUNDRA]
    if previous and previous.unitName==unitName then
      previous.active=false;previous.untilTime=0
    end
  end
end
-- The client can expose another effect ID for Major Heroism. Read the player
-- buff list by NAME/ID instead of relying on a single unverified 2021 ID.
local function IsMajorHeroism(id,name)
  if id==61709 then return true end
  if type(name)~='string' or name=='' then return false end
  if name=='Major Heroism' or name=='Великий героизм' then return true end
  local localized=GetAbilityName and GetAbilityName(61709)
  return type(localized)=='string' and localized~='' and name==localized
end
local function ScanPlayerHeroism(now)
  if not (GetNumBuffs and GetUnitBuffInfo) then return end
  local bestEnd,bestId=0,nil
  for i=1,(GetNumBuffs('player') or 0) do
    local name,_,endTime,_,_,_,_,_,_,_,id=GetUnitBuffInfo('player',i)
    if IsMajorHeroism(id,name) and type(endTime)=='number' and endTime>bestEnd then
      bestEnd,bestId=endTime,id
    end
  end
  -- A player-buff scan is authoritative, so also clear stale event state.
  warden.procs[WARDEN_HARVEST]={active=bestEnd>now,untilTime=bestEnd,
    observedId=bestId,estimated=false,cooldownUntil=0,unitName='player'}
end
local function WardenOwnProc(_,change,slot,name,unitTag,beginTime,endTime,stacks,
                               icon,buffType,effectType,abilityType,statusType,
                               unitName,unitId,abilityId,sourceType)
  local key=WARDEN_OWN_PROCS[abilityId]
  if not key or not WardenLearned(key) then return end
  -- Generic Major Brittle/Heroism can come from anyone. Only mastery-specific
  -- proc IDs still require the player's own source.
  if not WARDEN_GENERIC_EFFECT_IDS[abilityId] and sourceType~=nil and
     COMBAT_UNIT_TYPE_PLAYER~=nil and
     sourceType~=COMBAT_UNIT_TYPE_PLAYER then return end
  if key==WARDEN_TUNDRA then
    -- Need enemy target; do not accidentally treat a player Major Brittle as ours.
    if unitTag=='player' or
       ((not unitTag or unitTag=='') and (not unitName or unitName=='')) then return end
  elseif unitTag~='player' then return end
  local now=LeadNow()
  local state=warden.procs[key] or {}
  if change==EFFECT_RESULT_FADED then
    if not state.unitId or not unitId or state.unitId==unitId then
      state.untilTime=0;state.active=false
    end
  elseif change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED or
         change==EFFECT_RESULT_FULL_REFRESH then
    state.active=true
    state.unitId=unitId
    state.unitName=unitName
    state.observedId=abilityId
    if type(endTime)=='number' and endTime>now then
      state.untilTime=endTime;state.estimated=false
    elseif WARDEN_GENERIC_EFFECT_IDS[abilityId] then
      -- Generic source durations vary: don't invent 2.1 / 3 sec.
      state.untilTime=0;state.active=false;state.estimated=false
    else
      -- Only confirmed mastery-specific procs may use an estimate.
      state.untilTime=now+WARDEN_DEFAULT_DURATION[key];state.estimated=true
    end
    if key==WARDEN_HARVEST then
      warden.lastProcAt[key]=now
      state.cooldownUntil=0 -- This icon is the buff timer, not the proc ICD.
    end
  else return end
  warden.procs[key]=state
  if warden.debug and d then
    d(string.format('Ramaladni Warden %s: id=%s unit=%s end=%.1f estimated=%s',
      key,tostring(abilityId),tostring(unitTag),state.untilTime or 0,
      tostring(state.estimated)))
  end
end
-- ESO status effect enumeration covers additional CC effects, so it is not
-- correct to count statusEffectType ~= NONE as an elemental/physical status.
-- Use a conservative, bounded set of eight distinct combat status categories.
local WARDEN_STATUS_KEYS={
  burning={'Burning','Горение','Подожжение'},
  chilled={'Chilled','Обморожение','Охлаждение'},
  concussed={'Concussed','Контузия','Оглушение током'},
  poisoned={'Poisoned','Отравление'},
  diseased={'Diseased','Болезнь','Заражение'},
  hemorrhaging={'Hemorrhaging','Кровотечение','Кровоизлияние'},
  sundered={'Sundered','Раскол','Разрыв'},
  overcharged={'Overcharged','Перегрузка','Перезарядка'},
}
-- Some real status effects do not appear in GetUnitBuffInfo for enemies.
-- Canonical status-effect IDs are documented in LibCombat / ESOUI.
-- The previous catalog included only a few unverified aliases.
local WARDEN_STATUS_IDS={
  [18084]='burning',
  [95136]='chilled',
  [95134]='concussed',
  [21929]='poisoned',
  [178127]='diseased',
  [148801]='hemorrhaging',
  [178123]='sundered',
  [178118]='overcharged',
  -- Older observed variants; leave recognition by name as an independent path.
  [149571]='hemorrhaging',[148800]='sundered',[149573]='sundered',
  [148797]='overcharged',[149572]='overcharged',
  [149091]='chilled',[155797]='chilled',
}
-- Combat log status IDs (do not register older unverified aliases as hits).
local WARDEN_COMBAT_STATUS_IDS={
  [18084]='burning',[95136]='chilled',[95134]='concussed',
  [21929]='poisoned',[178127]='diseased',[148801]='hemorrhaging',
  [178123]='sundered',[178118]='overcharged',
}
local WARDEN_STATUS_DURATION=4 -- estimated; combat log gives no endTime
local WARDEN_TRACK_MAX=64        -- bound cached units even in a long trial
local function WardenNormalName(s)
  if type(s)~='string' then return '' end
  -- ESO unit/combat names can have gender suffixes and color codes.
  return s:gsub('|c%x%x%x%x%x%x',''):gsub('|r',''):gsub('%^%a+$',''):lower()
end
local function WardenStatusCategory(id,name)
  if WARDEN_STATUS_IDS[id] then return WARDEN_STATUS_IDS[id] end
  if type(name)~='string' or name=='' then return nil end
  local clean=WardenNormalName(name)
  for key,names in pairs(WARDEN_STATUS_KEYS) do
    for _,localized in ipairs(names) do
      if clean==WardenNormalName(localized) then return key end
    end
  end
  -- Use client-localized labels even if they differ from the manual RU list.
  if not warden.statusNameCache then
    warden.statusNameCache={}
    if GetAbilityName then
      for knownId,category in pairs(WARDEN_STATUS_IDS) do
        local localized=GetAbilityName(knownId)
        if type(localized)=='string' and localized~='' then
          warden.statusNameCache[WardenNormalName(localized)]=category
        end
      end
    end
  end
  return warden.statusNameCache[clean]
end
local function WardenScanStatus(tag,now,known)
  if not (GetNumBuffs and GetUnitBuffInfo and DoesUnitExist and DoesUnitExist(tag)) then
    return false
  end
  local total=GetNumBuffs(tag) or 0
  warden.scanCount=total
  for i=1,total do
    local name,_,finish,_,_,_,_,_,_,_,id=GetUnitBuffInfo(tag,i)
    local cat=WardenStatusCategory(id,name)
    if cat and (type(finish)~='number' or finish<=0 or finish>now) then
      known[cat]=true
    end
  end
  return true
end
local function WardenStatusSummary(known)
  local n,names=0,{}
  for key in pairs(known) do
    n=n+1
    names[#names+1]=key
  end
  table.sort(names)
  return math.min(5,n),table.concat(names,',')
end
local function WardenCountStatus(tag,now)
  local known={}
  if not WardenScanStatus(tag,now,known) then return nil,nil end
  return WardenStatusSummary(known)
end
local function WardenTargetStatus(now)
  local target=DoesUnitExist and DoesUnitExist('reticleover') and
    GetUnitName and WardenNormalName(GetUnitName('reticleover')) or ''
  if warden.status.at>=0 and now-warden.status.at<0.35 and
     warden.status.tag==target then
    return warden.status.count,warden.status.types
  end
  local count,types=WardenCountStatus('reticleover',now)
  warden.status={at=now,tag=target,count=count,types=types}
  return count,types
end
-- Status events arrive for the *target* of the status, not the caster.
-- Unit IDs are more reliable than name matching for enemies with duplicate names.
-- Event-only information is estimated, never presented as an observed aura endTime.
local function WardenStatusBucket(index,key,now)
  if not key or key=='' then return nil end
  local bucket=index[key]
  if not bucket then
    local amount=0
    for k,v in pairs(index) do
      if now-(v.seen or 0)>12 then index[k]=nil else amount=amount+1 end
    end
    if amount>=WARDEN_TRACK_MAX then
      local oldest,oldTime=nil,math.huge
      for k,v in pairs(index) do
        if (v.seen or 0)<oldTime then oldest,oldTime=k,v.seen or 0 end
      end
      if oldest then index[oldest]=nil end
    end
    bucket={types={}}
    index[key]=bucket
  end
  bucket.seen=now
  return bucket
end
local function WardenRecordStatus(targetName,targetId,cat,result,now)
  if not cat then return end
  local id=tonumber(targetId)
  local name=WardenNormalName(targetName)
  local gained=(result==ACTION_RESULT_EFFECT_GAINED or
                result==ACTION_RESULT_EFFECT_GAINED_DURATION)
  local function Update(bucket)
    if not bucket then return end
    local old=bucket.types[cat]
    -- DoT ticks are not fresh applications: don't extend the duration on each tick.
    if gained or not old or old<=now then bucket.types[cat]=now+WARDEN_STATUS_DURATION end
  end
  if id and id>0 then
    Update(WardenStatusBucket(warden.combatStatusesById,tostring(id),now))
  end
  if name~='' then
    Update(WardenStatusBucket(warden.combatStatusesByName,name,now))
  end
end
local function WardenCombatStatus(_,result,isError,abilityName,abilityGraphic,
  abilityActionSlotType,sourceName,sourceType,targetName,targetType,
  hitValue,powerType,damageType,log,sourceUnitId,targetUnitId,abilityId,overflow)
  if isError then return end
  local cat=WARDEN_COMBAT_STATUS_IDS[abilityId]
  if not cat then return end
  -- The client also emits status damage. Only fresh applications and positive
  -- status combat results can provide useful evidence of the target's effect.
  local gained=(result==ACTION_RESULT_EFFECT_GAINED or
                result==ACTION_RESULT_EFFECT_GAINED_DURATION)
  if not gained and (type(hitValue)~='number' or hitValue<=0) then return end
  WardenRecordStatus(targetName,targetUnitId,cat,result,LeadNow())
end
local function WardenIncludeCombat(known,id,name,now)
  local bucket
  local numericId=tonumber(id)
  if numericId and numericId>0 then
    bucket=warden.combatStatusesById[tostring(numericId)]
  else
    bucket=warden.combatStatusesByName[WardenNormalName(name)]
  end
  if not bucket or now-(bucket.seen or 0)>12 then return false end
  local estimated=false
  for cat,expires in pairs(bucket.types) do
    if expires>now then
      -- Observed aura values always win; combat-inferred effects add categories.
      if not known[cat] then estimated=true end
      known[cat]=true
    else
      bucket.types[cat]=nil
    end
  end
  return estimated
end
local function WardenHideStatus(now)
  local reticle=DoesUnitExist and DoesUnitExist('reticleover') and
    GetUnitName and GetUnitName('reticleover') or nil
  local recentAttacker=warden.attackerName and now-warden.attackerAt<=5
  local matched=reticle and recentAttacker and
      WardenNormalName(reticle)==WardenNormalName(warden.attackerName)
  local known={}
  local context='none'
  local estimated=false
  if reticle and reticle~='' then
    -- Useful defensive estimate before an enemy hits the player.
    WardenScanStatus('reticleover',now,known)
    local id=matched and warden.attackerId or nil
    estimated=WardenIncludeCombat(known,id,reticle,now)
    context=matched and 'reticle+attacker' or 'reticle (potential)'
  elseif recentAttacker then
    -- Without a reticle, use combat statuses of the actual recent attacker.
    estimated=WardenIncludeCombat(known,warden.attackerId,warden.attackerName,now)
    context='recent attacker'
  else
    return nil,nil,false,context
  end
  local n,names=WardenStatusSummary(known)
  return n,names,estimated,context
end
-- Damage source identifies the last real attacker; unlike the previous version,
-- the reticle does not have to match that unit just to display a potential value.
local WARDEN_DAMAGE_RESULTS={}
for _,damageResult in pairs({
  ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE,
  ACTION_RESULT_DOT_TICK, ACTION_RESULT_DOT_TICK_CRITICAL,
  ACTION_RESULT_BLOCKED_DAMAGE, ACTION_RESULT_DAMAGE_SHIELDED,
}) do
  WARDEN_DAMAGE_RESULTS[damageResult]=true
end
local function WardenIncoming(_,result,isError,abilityName,abilityGraphic,abilityActionSlotType,
  sourceName,sourceType,targetName,targetType,hitValue,powerType,damageType,
  log,sourceUnitId,targetUnitId,abilityId,overflow)
  if isError or not WARDEN_DAMAGE_RESULTS[result] or
     type(hitValue)~='number' or hitValue<=0 then return end
  local myName=GetUnitName and GetUnitName('player')
  if not myName or WardenNormalName(targetName)~=WardenNormalName(myName) then return end
  if not sourceName or sourceName=='' or
     WardenNormalName(sourceName)==WardenNormalName(myName) then return end
  warden.attackerName=sourceName
  warden.attackerId=sourceUnitId
  warden.attackerAt=LeadNow()
end
local function WardenDebug(input)
  local cmd=(input or ''):lower():match('^%s*(.-)%s*$')
  if cmd=='debug' then
    warden.debug=not warden.debug
    if d then d('Ramaladni Warden debug '..(warden.debug and 'ON' or 'OFF')) end
  end
  local now=LeadNow()
  local n,names=WardenCountStatus('reticleover',now)
  local hideN,hideNames,hideEstimated,context=WardenHideStatus(now)
  if d then
    d(string.format('Ramaladni Warden: reticle=%s [%s], hide=%s [%s] estimated=%s context=%s attacker=%s id=%s age=%.1fs',
      tostring(n),tostring(names),tostring(hideN),tostring(hideNames),
      tostring(hideEstimated),tostring(context),tostring(warden.attackerName),
      tostring(warden.attackerId),now-warden.attackerAt))
    for _,key in ipairs(WARDEN_KEYS) do
      local ok=SkillState(RamaladniMastery.byKey[key],true)
      local proc=warden.procs[key]
      d(string.format('%s: learned=%s id=%s remaining=%.1f estimated=%s',key,
        tostring(ok),tostring(proc and proc.observedId),
        proc and math.max(0,(proc.untilTime or 0)-now) or 0,
        tostring(proc and proc.estimated)))
    end
    if GetNumBuffs and GetUnitBuffInfo and DoesUnitExist and DoesUnitExist('reticleover') then
      for i=1,math.min(GetNumBuffs('reticleover') or 0,35) do
        local name,_,finish,_,stacks,_,_,_,_,status,id=GetUnitBuffInfo('reticleover',i)
        if warden.debug then d(string.format('target aura id=%s name=%s status=%s ends=%s stacks=%s',
          tostring(id),tostring(name),tostring(status),tostring(finish),tostring(stacks))) end
      end
    end
  end
end


runtime.Init=function()
  SLASH_COMMANDS['/rmwarden']=WardenDebug
  for auraId in pairs(WARDEN_OWN_PROCS) do
    local namespace='RamaladniWardenProc_'..tostring(auraId)
    EVENT_MANAGER:RegisterForEvent(namespace,EVENT_EFFECT_CHANGED,WardenOwnProc)
    EVENT_MANAGER:AddFilterForEvent(namespace,EVENT_EFFECT_CHANGED,
      REGISTER_FILTER_ABILITY_ID,auraId)
  end
  if EVENT_COMBAT_EVENT then
    for auraId in pairs(WARDEN_COMBAT_STATUS_IDS) do
      local namespace='RamaladniWardenStatus_'..tostring(auraId)
      EVENT_MANAGER:RegisterForEvent(namespace,EVENT_COMBAT_EVENT,WardenCombatStatus)
      EVENT_MANAGER:AddFilterForEvent(namespace,EVENT_COMBAT_EVENT,
        REGISTER_FILTER_ABILITY_ID,auraId)
    end
    EVENT_MANAGER:RegisterForEvent('RamaladniWardenIncoming',EVENT_COMBAT_EVENT,
      WardenIncoming)
    if REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
      EVENT_MANAGER:AddFilterForEvent('RamaladniWardenIncoming',EVENT_COMBAT_EVENT,
        REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
    end
  end
end
local function WardenDisplay(key,state,now)
  if not WardenLearned(key) then HideState(state);state.cooldownUntil=0;return true,nil end
  if key==WARDEN_HARVEST then ScanPlayerHeroism(now) end
  if key==WARDEN_TUNDRA then ScanTargetBrittle(now) end
  if key==WARDEN_WILD then
    local n=WardenTargetStatus(now)
    if n==nil then HideState(state);return true,nil end
    state.activeFlag=true;state.untilTime=0;state.timerEstimated=false
    state.cooldownUntil=0
    return true,tostring(n*333) -- Flat Weapon/Spell Damage, NOT percent.
  end
  if key==WARDEN_HIDE then
    local n,_,estimated=WardenHideStatus(now)
    if n==nil then HideState(state);state.cooldownUntil=0;return true,nil end
    -- A zero status count must not make the icon green.
    state.activeFlag=(n>0);state.untilTime=0;state.timerEstimated=false
    state.cooldownUntil=0
    return true,(estimated and '~' or '')..tostring(n*3)..'%'
  end
  local proc=warden.procs[key]
  if proc and proc.active and proc.untilTime>now then
    if key==WARDEN_TUNDRA then
      -- A target debuff must not be displayed as active on another enemy.
      local targetName=GetUnitName and GetUnitName('reticleover')
      if targetName and targetName~='' and proc.unitName~=targetName then
        HideState(state);return true,nil
      end
    end
    state.activeFlag=true;state.untilTime=proc.untilTime
    state.timerEstimated=proc.estimated==true
    state.cooldownUntil=0
    if key==WARDEN_TUNDRA then return true,'20%' end
    if key==WARDEN_GLACIAL then return true,'15%' end
    if key==WARDEN_HARVEST then return true,nil end
  end
  HideState(state)
  state.cooldownUntil=0
  return true,nil
end


runtime.Display=WardenDisplay


