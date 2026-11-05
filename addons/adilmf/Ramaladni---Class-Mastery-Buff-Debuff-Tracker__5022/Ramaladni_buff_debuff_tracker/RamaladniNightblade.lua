-- Ramaladni Tracker v0.9.23 — Nightblade isolated runtime.
-- Mechanics copied from the v0.9.22 reference; other classes are not modified.
local M=RamaladniMastery
local shared=M.shared
local SkillState,LeadNow,HideState=shared.SkillState,shared.LeadNow,shared.HideState
local lead=shared.lead
local runtime={}
M.modules["Nightblade"]=runtime
do
local e={key="Nightblade:Nocturnal Inspiration",class="Nightblade",en="Nocturnal Inspiration",title="Вдохновение Ноктюрнал / Nocturnal Inspiration",passiveId=263603,candidateIDs={263613},model="observed_stacks",value=0,cap=0,target=false,kind="chance+proc_counter",mechanic="Chance equals Weapon Critical chance to generate 2 Ultimate",durationRule="Proc rate limited to once every 0.3 sec; no duration"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Nightblade:An Eye for Exploitation",class="Nightblade",en="An Eye for Exploitation",title="Взгляд на слабости / An Eye for Exploitation",passiveId=263604,candidateIDs={263640},model="target_missing_health",value=2000,cap=0,target=true,kind="target_conditional_numeric",mechanic="Up to +2000 Weapon/Spell Damage versus missing target HP; mitigation up to 20% based on attacker missing HP",durationRule="No duration; dynamic on target and attacker health"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Nightblade:Above and Beyond",class="Nightblade",en="Above and Beyond",title="Выше всяких похвал / Above and Beyond",passiveId=263605,candidateIDs={267248},model="passive_percent",value=25,cap=30,target=false,kind="crit_cap_constant",mechanic="+25% Critical Damage/Healing (5% versus Battle Spirit), raises the critical damage/healing cap by 30 percentage points: 125% -> 155%",durationRule="Always on while purchased and Class Mastery is available; no timer"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Nightblade:Cutthroat's Focus",class="Nightblade",en="Cutthroat's Focus",title="Насмешка головореза / Cutthroat's Focus",passiveId=263606,candidateIDs={263685,268260,268259},model="timed_percent",value=5,cap=0,target=true,kind="target_debuff_timer+fixed_percent",mechanic="Attacker takes +5% damage after you dodge; 0.3 sec dodge from bracing activation",durationRule="5 sec on players, 20 sec on monsters; honor refresh"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Nightblade:Share the Spoils",class="Nightblade",en="Share the Spoils",title="Раздел добычи / Share the Spoils",passiveId=263607,candidateIDs={263688,263689,263690},model="observed_stacks",value=0,cap=0,target=false,kind="instant_proc_counter",mechanic="Group gains 250 Magicka/Stamina, 2 Ultimate; own Transfer ultimate gain doubled",durationRule="Instant proc, no independent timer"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end

-- A learned Class Mastery passive permanently raises the character's
-- Critical Damage/Healing cap by 30 percentage points (125% -> 155%).
-- The separate +25% crit damage/healing bonus is NOT added to the cap.
local NB_ABOVE_AND_BEYOND='Nightblade:Above and Beyond'
local NB_BASE_CRIT_CAP=125
local NB_ABOVE_CRIT_CAP_BONUS=30
local nbAboveScan={at=-100,owned=nil,skillId=nil,method='not checked'}
local NB_ABOVE_NAMES={
  ['above and beyond']=true,
  ['выше всяких похвал']=true,
  ['Выше всяких похвал']=true, -- Lua string.lower is ASCII-only for Cyrillic
  ['сверх пределов']=true,
  ['Сверх пределов']=true, -- older localization used in the addon catalog
}
local function NBPassiveName(value)
  if type(value)~='string' then return '' end
  return value:lower():gsub('|c%x%x%x%x%x%x',''):gsub('|r','')
      :gsub('^%s+',''):gsub('%s+$','')
end
local function NBAboveOwned(force)
  local classId=GetUnitClassId and GetUnitClassId('player')
  if classId~=3 then return false end
  local meta=RamaladniMastery.byKey[NB_ABOVE_AND_BEYOND]
  local learned=SkillState(meta,force)
  if learned~=nil then
    nbAboveScan.skillId=meta.passiveId
    nbAboveScan.method='passive ID '..tostring(meta.passiveId)
    return learned
  end
  local now=LeadNow()
  if not force and now-nbAboveScan.at<3 then return nbAboveScan.owned end
  nbAboveScan.at=now
  nbAboveScan.owned=nil
  nbAboveScan.skillId=nil
  nbAboveScan.method='not exposed in SKILL_TYPE_CLASS'
  if not (SKILL_TYPE_CLASS and GetNumSkillLines and GetNumSkillAbilities and
          GetSkillAbilityInfo) then return nil end
  -- Fallback for a client whose localization / ability rank uses a
  -- different ID for the passive. Accept only the passive's OWN name;
  -- do not guess mastery ownership from arbitrary buffs or class alone.
  local localized=GetAbilityName and NBPassiveName(GetAbilityName(meta.passiveId)) or ''
  if localized~='' then NB_ABOVE_NAMES[localized]=true end
  for line=1,(GetNumSkillLines(SKILL_TYPE_CLASS) or 0) do
    for i=1,(GetNumSkillAbilities(SKILL_TYPE_CLASS,line) or 0) do
      local name,_,_,_,_,purchased=GetSkillAbilityInfo(SKILL_TYPE_CLASS,line,i)
      if NB_ABOVE_NAMES[NBPassiveName(name)] then
        local id=GetSkillAbilityId and GetSkillAbilityId(SKILL_TYPE_CLASS,line,i,false)
        if IsSkillAbilityPurchased then
          purchased=IsSkillAbilityPurchased(SKILL_TYPE_CLASS,line,i)
        end
        nbAboveScan.skillId=id
        nbAboveScan.method='name and purchased'
        if type(purchased)=='boolean' then
          nbAboveScan.owned=purchased
        end
        return nbAboveScan.owned
      end
    end
  end
  return nil -- Unknown is NOT the same as learned.
end
local function NBAboveDebug()
  if not d then return end
  local owned=NBAboveOwned(true)
  local cap=(owned==true) and NB_BASE_CRIT_CAP+NB_ABOVE_CRIT_CAP_BONUS or NB_BASE_CRIT_CAP
  d(string.format('|c6FD6FFRamaladni NB|r Above and Beyond learned=%s; cap=%s; skillId=%s; fallback=%s',
      tostring(owned),owned==nil and 'unknown' or tostring(cap)..'%',
      tostring(nbAboveScan.skillId),nbAboveScan.method))
  if owned==nil then
    d('|c6FD6FFRamaladni NB|r Client did not expose passive purchase state. Indicator stays grey to avoid a false 155%%.')
  end
end

-- v0.9.18 NIGHTBLADE SHARE FIX. These are three distinct models, not 3 timed auras:
-- Nocturnal Inspiration: actual weapon crit chance + verified +2 Ultimate procs.
-- An Eye for Exploitation: ESTIMATED, target/attacker-dependent values.
-- Share the Spoils: verified +4 Ultimate procs (and +2 group, not an aura).
-- No generic Ultimate gains are attributed to a Nightblade mastery.
local NB_NOCTURNAL='Nightblade:Nocturnal Inspiration'
local NB_EYE='Nightblade:An Eye for Exploitation'
local NB_SHARE='Nightblade:Share the Spoils'
local NB_PROC_IDS={[263613]=NB_NOCTURNAL,[263688]=NB_SHARE,
                     [263689]=NB_SHARE,[263690]=NB_SHARE}
local nb={initialized=false,debug=false,lastUltimate=nil,lastGain=nil,
          pending={},procs={[NB_NOCTURNAL]={at=-100,count=0,id=0},
                            [NB_SHARE]={at=-100,count=0,id=0}},
          attacker={name='',id=nil,at=-100},
          lastEventId=0,lastPowerChange=0,
          nocturnalTestAt=-100,
          nocturnal={estimated=0,lastEstimateAt=-100,lastVerifiedAt=-100,
                     energyEvents=0,lastEnergyId=0,lastEnergyName='',
                     lastEnergyAmount=0,lastEnergyPower=0,lastEnergyAt=-100},
          share={castAt=-100,castId=0,source='none',testAt=-100,
                 lastGainAt=-100,lastGainValue=0,lastSiphoning='none'}}
local function NBPrint(message)
  if d then d('|cAA89FBRamaladni NB|r '..tostring(message)) end
end
-- Nightblade Nocturnal only: some ESO builds have different ability IDs
-- for a class-mastery skill. Match its OWN purchased name when the expected
-- passiveId cannot be resolved; never infer it from crit rating or class.
local nbNocturnalSkill={at=-100,owned=nil,method='unresolved'}
local NB_NOCTURNAL_NAMES={
  ['Nocturnal Inspiration']=true,['nocturnal inspiration']=true,
  ['Вдохновение Ноктюрнал']=true,['вдохновение ноктюрнал']=true,
  ['Ночное вдохновение']=true,['ночное вдохновение']=true,
}
local function NBNocturnalOwned(force)
  local meta=RamaladniMastery.byKey[NB_NOCTURNAL]
  local owned=SkillState(meta,force)
  if owned~=nil then
    nbNocturnalSkill.method='passive ID '..tostring(meta.passiveId)
    return owned
  end
  local now=LeadNow()
  if not force and now-nbNocturnalSkill.at<3 then return nbNocturnalSkill.owned end
  nbNocturnalSkill.at=now
  nbNocturnalSkill.owned=nil
  nbNocturnalSkill.method='unresolved'
  if not (GetUnitClassId and GetUnitClassId('player')==3 and SKILL_TYPE_CLASS and
      GetNumSkillLines and GetNumSkillAbilities and GetSkillAbilityInfo) then return nil end
  for line=1,(GetNumSkillLines(SKILL_TYPE_CLASS) or 0) do
    for i=1,(GetNumSkillAbilities(SKILL_TYPE_CLASS,line) or 0) do
      local name,_,_,_,_,purchased=GetSkillAbilityInfo(SKILL_TYPE_CLASS,line,i)
      if NB_NOCTURNAL_NAMES[name] then
        if IsSkillAbilityPurchased then
          local valid=IsSkillAbilityPurchased(SKILL_TYPE_CLASS,line,i)
          if type(valid)=='boolean' then purchased=valid end
        end
        nbNocturnalSkill.method='localized passive name'
        if type(purchased)=='boolean' then nbNocturnalSkill.owned=purchased end
        return nbNocturnalSkill.owned
      end
    end
  end
  return nil
end
local function NBOwns(key)
  -- Do not infer ownership from simply being a Nightblade; the Class Mastery
  -- skill line only supports two equipped masteries at a time.
  if key==NB_NOCTURNAL then return NBNocturnalOwned()==true end
  return SkillState(RamaladniMastery.byKey[key])==true
end
-- v0.9.18 SHARE THE SPOILS ONLY. ESO can give the class mastery passive a
-- different rank-specific ID. Resolve its OWN purchased name as a fallback;
-- never infer a mastery simply from class, an unrelated +4, or a group buff.
local nbShareSkillCache={at=-100,owned=nil,method='unresolved'}
local NB_SHARE_NAMES={
  ['Share the Spoils']=true,['share the spoils']=true,
  ['Доля от добычи']=true,['доля от добычи']=true,
  ['Раздел добычи']=true,['раздел добычи']=true,
}
local function NBShareOwned(force)
  local meta=RamaladniMastery.byKey[NB_SHARE]
  local direct=SkillState(meta,force)
  if direct~=nil then
    nbShareSkillCache.method='passive ID '..tostring(meta.passiveId)
    return direct
  end
  local now=LeadNow()
  if not force and now-nbShareSkillCache.at<3 then return nbShareSkillCache.owned end
  nbShareSkillCache.at=now
  nbShareSkillCache.owned=nil
  nbShareSkillCache.method='not found'
  if not (GetUnitClassId and GetUnitClassId('player')==3 and SKILL_TYPE_CLASS and
      GetNumSkillLines and GetNumSkillAbilities and GetSkillAbilityInfo) then return nil end
  for line=1,(GetNumSkillLines(SKILL_TYPE_CLASS) or 0) do
    for i=1,(GetNumSkillAbilities(SKILL_TYPE_CLASS,line) or 0) do
      local name,_,_,_,_,purchased=GetSkillAbilityInfo(SKILL_TYPE_CLASS,line,i)
      if NB_SHARE_NAMES[name] then
        if IsSkillAbilityPurchased then
          purchased=IsSkillAbilityPurchased(SKILL_TYPE_CLASS,line,i)
        end
        nbShareSkillCache.method='localized passive name'
        if type(purchased)=='boolean' then nbShareSkillCache.owned=purchased end
        return nbShareSkillCache.owned
      end
    end
  end
  return nil
end
-- Transfer II triggers on Siphoning casts in combat, at most once/4 sec.
-- Check the game's own skillbook mapping instead of maintaining unverified
-- morph IDs. Nightblade Siphoning is the third class skill line.
local function NBIsSiphoningAbility(id)
  if type(id)~='number' or id<=0 then return false end
  if GetSpecificSkillAbilityKeysByAbilityId then
    local skillType,line=GetSpecificSkillAbilityKeysByAbilityId(id)
    if skillType==SKILL_TYPE_CLASS and line==3 then return true end
    if skillType~=nil then return false end
  end
  if not (GetNumSkillAbilities and GetSkillAbilityId and SKILL_TYPE_CLASS) then return false end
  local actualName=GetAbilityName and GetAbilityName(id)
  for i=1,(GetNumSkillAbilities(SKILL_TYPE_CLASS,3) or 0) do
    local skillId=GetSkillAbilityId(SKILL_TYPE_CLASS,3,i,false)
    if skillId==id then return true end
    if type(actualName)=='string' and actualName~='' and GetSkillAbilityInfo then
      local name=GetSkillAbilityInfo(SKILL_TYPE_CLASS,3,i)
      if name==actualName then return true end
    end
  end
  return false
end
-- In modern ESO, GetPlayerStat(STAT_CRITICAL_STRIKE) returns the CRITICAL
-- RATING, not a chance in tenths of one percent. The previous 0.9.19
-- rejected normal ratings >1000, so the HUD had no valid number to display.
-- Convert via ESO's own GetCriticalStrikeChance(rating) instead of /10.
-- Cache for 0.8 sec to avoid querying an expensive derived stat each HUD tick.
local nbWeaponCrit={at=-100,percent=nil,rating=nil,method='not read'}
local function NBWeaponCritChance(force)
  local now=LeadNow()
  if not force and now-nbWeaponCrit.at<0.8 then return nbWeaponCrit.percent end
  nbWeaponCrit.at=now
  nbWeaponCrit.percent=nil
  nbWeaponCrit.rating=nil
  nbWeaponCrit.method='GetPlayerStat / GetCriticalStrikeChance not available'
  if not (GetPlayerStat and STAT_CRITICAL_STRIKE and GetCriticalStrikeChance) then return nil end
  local ok,rating=pcall(GetPlayerStat,STAT_CRITICAL_STRIKE,
                         STAT_BONUS_OPTION_APPLY_BONUS,STAT_SOFT_CAP_OPTION_APPLY_SOFT_CAP)
  if not ok or type(rating)~='number' then
    ok,rating=pcall(GetPlayerStat,STAT_CRITICAL_STRIKE)
  end
  if not ok or type(rating)~='number' or rating<0 then
    nbWeaponCrit.method='critical rating not available'
    return nil
  end
  nbWeaponCrit.rating=rating
  local converted,chance=pcall(GetCriticalStrikeChance,rating,true)
  if not converted or type(chance)~='number' or chance~=chance or chance<0 or chance>100 then
    nbWeaponCrit.method='GetCriticalStrikeChance rejected rating'
    return nil
  end
  nbWeaponCrit.percent=chance
  nbWeaponCrit.method='rating -> GetCriticalStrikeChance'
  return chance
end
local function NBTargetHealth()
  if not (GetUnitPower and POWERTYPE_HEALTH and DoesUnitExist and
          DoesUnitExist('reticleover')) then return nil end
  local hp,maxHP=GetUnitPower('reticleover',POWERTYPE_HEALTH)
  if type(hp)~='number' or type(maxHP)~='number' or maxHP<=0 then return nil end
  local missing=math.max(0,math.min(1,1-hp/maxHP))
  local pvp=(IsUnitPlayer and IsUnitPlayer('reticleover'))==true
  return missing,pvp
end
local function NBCompareTargetAndAttacker(now)
  -- Damage reduction depends on the actual attacker, not on whoever happens
  -- to be under the cursor. Same name alone is ambiguous if several enemies
  -- share a name; require matching positive IDs if the client exposes them.
  if now-nb.attacker.at>5 then return false end
  local targetId=GetUnitId and GetUnitId('reticleover')
  if nb.attacker.id and nb.attacker.id>0 and type(targetId)=='number' and targetId>0 then
    return nb.attacker.id==targetId
  end
  local name=GetUnitName and GetUnitName('reticleover')
  return type(name)=='string' and name~='' and nb.attacker.name~='' and name==nb.attacker.name
end
local function NBClassSource(name,sourceType)
  if COMBAT_UNIT_TYPE_PLAYER and sourceType==COMBAT_UNIT_TYPE_PLAYER then
    return type(name)=='string' and GetUnitName and name==GetUnitName('player')
  end
  -- Combat log events with no unit type need an exact player name match.
  return (sourceType==nil or (COMBAT_UNIT_TYPE_NONE and sourceType==COMBAT_UNIT_TYPE_NONE))
         and type(name)=='string' and name~='' and GetUnitName and
         name==GetUnitName('player')
end
local function NBConfirmed(key,id,now)
  if key==NB_SHARE then
    if NBShareOwned()~=true then return false end
  elseif not NBOwns(key) then return false end
  local proc=nb.procs[key]
  -- Transfer II has a 4-second internal cooldown. Do not count duplicate
  -- COMBAT/EFFECT/POWER events for the same activation.
  local interval=(key==NB_SHARE) and 3.5 or 0.29
  if not proc or now-proc.at<interval then return false end
  proc.at=now;proc.count=proc.count+1;proc.id=id
  if key==NB_NOCTURNAL then
    -- A confirmed source can upgrade a previously inferred +2, not double
    -- count it. A later independent proc is still allowed after 0.3 seconds.
    if nb.nocturnal.estimated>0 and now-nb.nocturnal.lastEstimateAt<=0.65 then
      nb.nocturnal.estimated=nb.nocturnal.estimated-1
      nb.nocturnal.lastEstimateAt=-100
    end
    nb.nocturnal.lastVerifiedAt=now
  end
  if nb.debug then NBPrint('CONFIRMED '..key..' ability='..tostring(id)..' x'..proc.count) end
  return true
end
local function NBMatchCandidate(key,now)
  local pending=nb.pending[key]
  local gain=nb.lastGain
  if not pending or not gain or math.abs(pending.at-gain.at)>0.65 then return end
  if (key==NB_NOCTURNAL and gain.amount==2) or
     (key==NB_SHARE and gain.amount==4) then
    if (not gain.used or (key==NB_NOCTURNAL and gain.kind=='nocturnal-estimate'))
       and NBConfirmed(key,pending.id,now) then
      gain.used=true
      gain.kind='confirmed'
      if key==NB_SHARE then nb.share.source='passive ID + ultimate power' end
    end
    nb.pending[key]=nil
  end
end
-- Fallback when the client emits no distinct Share the Spoils aura/effect.
-- A Siphoning cast AND a matching +4 Ultimate power update are both needed.
-- Raw gains alone are not evidence: Nocturnal Inspiration, sets and skills
-- can also grant Ultimate. The 0.9s window is intentionally conservative.
local function NBShareMatchCast(now)
  local cast=nb.share
  local gain=nb.lastGain
  if not gain or gain.used or gain.amount~=4 then return end
  if math.abs(cast.castAt-gain.at)>0.9 then return end
  if NBConfirmed(NB_SHARE,cast.castId,now) then
    gain.used=true
    cast.source='Siphoning cast + observed +4 Ultimate'
    if nb.debug then NBPrint('Transfer correlated: ability '..tostring(cast.castId)..' +4') end
  end
end
local function NBShareAbilityUsed(_,slot)
  if not GetSlotBoundId or type(slot)~='number' then return end
  if NBShareOwned()~=true then return end
  if IsUnitInCombat and not IsUnitInCombat('player') then return end
  local id=GetSlotBoundId(slot)
  if not NBIsSiphoningAbility(id) then return end
  nb.share.castAt=LeadNow()
  nb.share.castId=id
  nb.share.lastSiphoning=tostring(id)
  if nb.debug then NBPrint('Siphoning cast ID='..tostring(id)..'; awaiting +4 Ultimate') end
  NBShareMatchCast(nb.share.castAt)
end
local function NBPowerChanged(_,unitTag,_,powerType,value)
  if unitTag~='player' or powerType~=POWERTYPE_ULTIMATE or
     type(value)~='number' then return end
  local previous=nb.lastUltimate
  nb.lastUltimate=value
  if not previous or value<=previous then return end
  local now=LeadNow()
  local delta=value-previous
  nb.lastPowerChange=delta
  nb.lastGain={at=now,amount=delta,used=false}
  if nb.debug and (delta==2 or delta==4) then
    NBPrint('Ultimate +'..delta..' (unattributed until own-proc event)')
  end
  NBMatchCandidate(NB_NOCTURNAL,now)
  NBMatchCandidate(NB_SHARE,now)
  NBShareMatchCast(now)
  -- Last-resort estimate. ESO power updates do not carry an ability ID;
  -- counting them as CERTAIN Nocturnal procs would be inaccurate. We only
  -- count isolated +2 Ultimate increments with the mastery purchased and
  -- the character in combat, and render them with a visible '~' marker.
  if delta==2 and not nb.lastGain.used and NBNocturnalOwned()==true and
     (not IsUnitInCombat or IsUnitInCombat('player')) and
     now-nb.nocturnal.lastVerifiedAt>0.24 and
     now-nb.nocturnal.lastEstimateAt>=0.29 then
    nb.nocturnal.estimated=nb.nocturnal.estimated+1
    nb.nocturnal.lastEstimateAt=now
    nb.lastGain.used=true
    nb.lastGain.kind='nocturnal-estimate'
    if nb.debug then NBPrint('Nocturnal POSSIBLE +2 via POWER_UPDATE; inferred ~x'..nb.nocturnal.estimated) end
  end
end

-- Source-aware route for the actual instant Ultimate recovery event. Unlike
-- EVENT_POWER_UPDATE this supplies the ability ID and ability name. The
-- client can report Hemorrhage rather than Nocturnal Inspiration as source.
-- Missing/unknown sources are diagnostic ONLY, and the power-delta fallback
-- remains explicitly approximate.
local NB_NOCTURNAL_SOURCE_IDS={[263613]=true}
local NB_NOCTURNAL_SOURCE_NAMES={
  ['Nocturnal Inspiration']=true,['nocturnal inspiration']=true,
  ['Вдохновение Ноктюрнал']=true,['вдохновение ноктюрнал']=true,
  ['Ночное вдохновение']=true,['ночное вдохновение']=true,
  ['Hemorrhage']=true,['hemorrhage']=true,
  ['Кровоизлияние']=true,['кровоизлияние']=true,
}
local function NBNocturnalEnergize(_,result,isError,abilityName,_,_,sourceName,sourceType,
                                  targetName,targetType,hitValue,powerType,_,_,_,targetId,abilityId)
  if result~=ACTION_RESULT_POWER_ENERGIZE or isError or
     powerType~=COMBAT_MECHANIC_FLAGS_ULTIMATE or hitValue~=2 then return end
  if GetUnitClassId and GetUnitClassId('player')~=3 then return end
  -- Do not count someone else's ultimate gain. Unit IDs are preferred;
  -- name is a fallback since some combat results expose zero unit IDs.
  local myId=GetUnitId and GetUnitId('player')
  local myName=GetUnitName and GetUnitName('player')
  local targetIsPlayer=(type(myId)=='number' and myId>0 and targetId==myId)
     or (type(myName)=='string' and myName~='' and targetName==myName)
  if not targetIsPlayer then return end
  local now=LeadNow()
  local track=nb.nocturnal
  track.energyEvents=track.energyEvents+1
  track.lastEnergyId=abilityId or 0
  track.lastEnergyName=abilityName or ''
  track.lastEnergyAmount=hitValue
  track.lastEnergyPower=powerType
  track.lastEnergyAt=now
  local shortName=type(abilityName)=='string' and abilityName:gsub('%^.*','') or ''
  local valid=NB_NOCTURNAL_SOURCE_IDS[abilityId] or NB_NOCTURNAL_SOURCE_NAMES[shortName]
  if valid and NBNocturnalOwned()==true then
    if NBConfirmed(NB_NOCTURNAL,abilityId or 0,now) and nb.lastGain and
       now-nb.lastGain.at<=0.65 and nb.lastGain.kind=='nocturnal-estimate' then
      nb.lastGain.kind='confirmed'
    end
  end
  if nb.debug and (track.energyEvents<=15 or track.energyEvents%20==0) then
    NBPrint(string.format('Nocturnal ENERGY id=%s name=%s amount=%s power=%s src=%s tgt=%s matched=%s',
      tostring(abilityId),tostring(abilityName),tostring(hitValue),tostring(powerType),
      tostring(sourceName),tostring(targetName),tostring(valid==true)))
  end
end
local function NBProcCombat(_,result,isError,abilityName,_,_,sourceName,sourceType,
                            _,_,hitValue,_,_,_,_,_,abilityId)
  local key=NB_PROC_IDS[abilityId]
  if not key or isError or not NBClassSource(sourceName,sourceType) or
     not ((key==NB_SHARE and NBShareOwned()==true) or
          (key~=NB_SHARE and NBOwns(key))) then return end
  local now=LeadNow()
  nb.lastEventId=abilityId
  nb.pending[key]={at=now,id=abilityId}
  NBMatchCandidate(key,now)
  if nb.debug then NBPrint('own candidate '..key..' id='..abilityId..' value='..tostring(hitValue)) end
end
local function NBProcEffect(_,change,_,name,unitTag,_,_,_,_,_,_,_,_,unitName,_,abilityId,sourceType)
  local key=NB_PROC_IDS[abilityId]
  if not key or change==EFFECT_RESULT_FADED or
     not ((key==NB_SHARE and NBShareOwned()==true) or
          (key~=NB_SHARE and NBOwns(key))) then return end
  -- A received group effect is not sufficient to prove the passive activated;
  -- it also needs the player's separately observed Ultimate gain.
  if not (unitTag=='player' or (COMBAT_UNIT_TYPE_PLAYER and
       sourceType==COMBAT_UNIT_TYPE_PLAYER)) then return end
  local now=LeadNow()
  nb.lastEventId=abilityId
  nb.pending[key]={at=now,id=abilityId}
  NBMatchCandidate(key,now)
  if nb.debug then NBPrint('effect candidate '..key..' id='..abilityId) end
end
local function NBIncomingDamage(_,result,isError,_,_,_,sourceName,sourceType,
                                targetName,targetType,hitValue,_,_,_,sourceId)
  if isError or type(hitValue)~='number' or hitValue<=0 or
     not NBOwns(NB_EYE) then return end
  if not GetUnitName or targetName~=GetUnitName('player') then return end
  -- Incoming damage only; don't identify another player's support/heals as
  -- an attacker merely because the event target happens to be the player.
  local damage=(ACTION_RESULT_DAMAGE and result==ACTION_RESULT_DAMAGE) or
    (ACTION_RESULT_CRITICAL_DAMAGE and result==ACTION_RESULT_CRITICAL_DAMAGE) or
    (ACTION_RESULT_DOT_TICK and result==ACTION_RESULT_DOT_TICK) or
    (ACTION_RESULT_DOT_TICK_CRITICAL and result==ACTION_RESULT_DOT_TICK_CRITICAL) or
    (ACTION_RESULT_BLOCKED_DAMAGE and result==ACTION_RESULT_BLOCKED_DAMAGE)
  if not damage then return end
  nb.attacker={name=sourceName or '',id=tonumber(sourceId),at=LeadNow()}
end
local function NBDebug(input)
  local cmd=(input or ''):lower():match('^%s*(.-)%s*$')
  if cmd=='debug' then nb.debug=not nb.debug; NBPrint('debug '..(nb.debug and 'ON' or 'OFF'));return end
  if cmd=='share test' then
    nb.share.testAt=LeadNow()
    NBPrint('Share HUD TEST: 4-sec simulated cooldown, +4 self, +2 group; this does NOT increase real proc count')
    return
  end
  if cmd=='nocturnal test' then
    nb.nocturnalTestAt=LeadNow()
    NBPrint('Nocturnal HUD TEST: 0.85-sec green flash; weapon crit chance is still the REAL player stat; proc count unchanged')
    return
  end
  NBAboveDebug()
  local c=NBWeaponCritChance()
  local missing,pvp=NBTargetHealth()
  NBPrint(string.format('Nocturnal=%s Eye=%s Spoils=%s weaponCrit=%s targetMissing=%s pvp=%s',
    tostring(NBOwns(NB_NOCTURNAL)),tostring(NBOwns(NB_EYE)),
    tostring(NBOwns(NB_SHARE)),c and string.format('%.1f%%',c) or '?',
    missing and string.format('%.0f%%',missing*100) or '?',tostring(pvp)))
  NBPrint(string.format('Nocturnal x%d; Spoils x%d; lastCandidate=%d; lastGain=%s; attacker=%s',
    nb.procs[NB_NOCTURNAL].count,nb.procs[NB_SHARE].count,
    nb.lastEventId,tostring(nb.lastPowerChange),tostring(nb.attacker.name)))
  NBPrint(string.format('Nocturnal real x%d / inferred ~x%d; ENERGY events=%d lastID=%s lastName=%s',
    nb.procs[NB_NOCTURNAL].count,nb.nocturnal.estimated,nb.nocturnal.energyEvents,
    tostring(nb.nocturnal.lastEnergyId),tostring(nb.nocturnal.lastEnergyName)))
  NBPrint(string.format('Nocturnal critical rating=%s, chance=%s, method=%s, passive=%s (%s)',
    tostring(nbWeaponCrit.rating),
    c and string.format('%.1f%%',c) or '?',nbWeaponCrit.method,
    tostring(NBNocturnalOwned(true)),nbNocturnalSkill.method))
  NBPrint(string.format('Share learned=%s (%s); last Siphoning ID=%s; source=%s; cooldown=%.1fs',
    tostring(NBShareOwned(true)),nbShareSkillCache.method,
    nb.share.lastSiphoning,nb.share.source,
    math.max(0,nb.procs[NB_SHARE].at+4-LeadNow())))
end
local function InitNightblade()
  if nb.initialized then return end
  nb.initialized=true
  SLASH_COMMANDS['/rmnb']=NBDebug
  EVENT_MANAGER:RegisterForEvent('RamaladniNB_ShareCast',
      EVENT_ACTION_SLOT_ABILITY_USED,NBShareAbilityUsed)
  nb.lastUltimate=(GetUnitPower and POWERTYPE_ULTIMATE and GetUnitPower('player',POWERTYPE_ULTIMATE)) or nil
  EVENT_MANAGER:RegisterForEvent('RamaladniNB_Power',EVENT_POWER_UPDATE,NBPowerChanged)
  EVENT_MANAGER:AddFilterForEvent('RamaladniNB_Power',EVENT_POWER_UPDATE,
    REGISTER_FILTER_UNIT_TAG,'player',REGISTER_FILTER_POWER_TYPE,POWERTYPE_ULTIMATE)
  if EVENT_COMBAT_EVENT and ACTION_RESULT_POWER_ENERGIZE and
     COMBAT_MECHANIC_FLAGS_ULTIMATE then
    local name='RamaladniNB_NocturnalEnergy'
    EVENT_MANAGER:RegisterForEvent(name,EVENT_COMBAT_EVENT,NBNocturnalEnergize)
    -- Native event filtering prevents a Lua callback on every damage tick.
    if REGISTER_FILTER_COMBAT_RESULT then
      EVENT_MANAGER:AddFilterForEvent(name,EVENT_COMBAT_EVENT,
        REGISTER_FILTER_COMBAT_RESULT,ACTION_RESULT_POWER_ENERGIZE)
    end
  end
  for id in pairs(NB_PROC_IDS) do
    if EVENT_COMBAT_EVENT then
      local name='RamaladniNB_Proc_'..id
      EVENT_MANAGER:RegisterForEvent(name,EVENT_COMBAT_EVENT,NBProcCombat)
      EVENT_MANAGER:AddFilterForEvent(name,EVENT_COMBAT_EVENT,REGISTER_FILTER_ABILITY_ID,id)
    end
    local name='RamaladniNB_Effect_'..id
    EVENT_MANAGER:RegisterForEvent(name,EVENT_EFFECT_CHANGED,NBProcEffect)
    EVENT_MANAGER:AddFilterForEvent(name,EVENT_EFFECT_CHANGED,REGISTER_FILTER_ABILITY_ID,id)
  end
  if EVENT_COMBAT_EVENT then
    EVENT_MANAGER:RegisterForEvent('RamaladniNB_Attackers',EVENT_COMBAT_EVENT,NBIncomingDamage)
    if REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
      EVENT_MANAGER:AddFilterForEvent('RamaladniNB_Attackers',EVENT_COMBAT_EVENT,
        REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
    end
  end
end
local function NBDisplay(key,state,now)
  local meta=RamaladniMastery.byKey[key]
  local learned=(key==NB_SHARE) and NBShareOwned()
      or (key==NB_NOCTURNAL and NBNocturnalOwned()) or SkillState(meta)
  -- v0.9.20 NOCTURNAL ONLY: its critical chance is calculated from a RATING,
  -- not an effect that depends on detecting the purchased mastery ID.
  -- Show it even when purchased state is unavailable, but only flash for
  -- a confirmed OWN proc (or for an explicit HUD test).
  if key==NB_NOCTURNAL then
    local proc=nb.procs[key]
    state.untilTime=0;state.cooldownUntil=0;state.timerEstimated=false
    state.activeFlag=((learned==true or learned==nil) and
                      (now-proc.at<0.85 or now-nb.nocturnal.lastEstimateAt<0.85))
                     or now-nb.nocturnalTestAt<0.85
    -- The main tracker obtains crit chance as a base amount; the custom
    -- HUD hook draws xN prominently and the chance in the top corner.
    local crit=NBWeaponCritChance()
    return true,(crit~=nil) and string.format('%.1f%%',crit) or '?'
  end
  if learned~=true then
    state.untilTime=0;state.activeFlag=false;state.timerEstimated=false
    state.cooldownUntil=0
    -- If the Class Mastery skill line is not readable, show an explicit
    -- unknown rather than a mysteriously blank Share indicator.
    return true,(key==NB_SHARE and learned==nil) and '?' or nil
  end
  state.untilTime=0;state.cooldownUntil=0;state.timerEstimated=false
  if key==NB_SHARE then
    local proc=nb.procs[NB_SHARE]
    local last=math.max(proc.at,nb.share.testAt)
    local remaining=last+4-now
    -- The first 0.8 seconds are green: the rest is the red Transfer cooldown.
    state.untilTime=(remaining>0 and now-last<0.8) and (last+0.8) or 0
    state.cooldownUntil=(remaining>0) and (last+4) or 0
    state.activeFlag=state.untilTime>now
    state.timerEstimated=nb.share.testAt>=proc.at and remaining>0
    -- A non-timed passive still displays its actual fixed reward at rest.
    return true,'+4'
  end
  if key==NB_EYE then
    local missing=NBTargetHealth()
    state.activeFlag=missing~=nil and missing>0
    return true,nil -- Estimated values rendered by UpdateWidgetExtras.
  end
  return false,nil
end


runtime.Init=InitNightblade
runtime.Display=function(key,state,now)
  if key==NB_NOCTURNAL or key==NB_EYE or key==NB_SHARE then return NBDisplay(key,state,now) end
  if key==NB_ABOVE_AND_BEYOND then
    local owned=NBAboveOwned()
    HideState(state)
    state.cooldownUntil=0
    state.activeFlag=(owned==true)
    return true,(owned==true) and '+30%' or nil
  end
  return false,nil
end

runtime.UpdateWidgetExtras=function(entry,widget,now)
  local isNBShare=entry and entry.kind=='mastery' and entry.masteryKey==NB_SHARE
  if widget.nbShareGroup then widget.nbShareGroup:SetHidden(not isNBShare) end
  -- NIGHTBLADE (Above and Beyond): reuse the large timer label for
  -- 125%/155% CRIT CAP, with no fake seconds. Existing main HUD switches
  -- icon border to green only when state.activeFlag=true.
  if entry and entry.kind=='mastery' and entry.masteryKey==NB_ABOVE_AND_BEYOND then
    if widget.sphereShieldLabel then widget.sphereShieldLabel:SetHidden(true) end
    if widget.sphereSmallFont then
      widget.amount:SetFont('$(BOLD_FONT)|19|soft-shadow-thick')
      widget.sphereSmallFont=false
    end
    local owned=NBAboveOwned()
    local text=(owned==true) and '155%' or ((owned==false) and '125%' or '?')
    local font='$(BOLD_FONT)|24|soft-shadow-thick'
    if widget.font~=font then widget.timer:SetFont(font);widget.font=font end
    if widget.lastText~=text then widget.timer:SetText(text);widget.lastText=text end
    return
  end
  -- NIGHTBLADE three new indicators: no fake countdowns.
  local key=entry and entry.kind=='mastery' and entry.masteryKey
  if key==NB_NOCTURNAL or key==NB_EYE or key==NB_SHARE then
    if widget.sphereShieldLabel then widget.sphereShieldLabel:SetHidden(true) end
    if widget.sphereSmallFont then
      widget.amount:SetFont('$(BOLD_FONT)|19|soft-shadow-thick')
      widget.sphereSmallFont=false
    end
    local owned=(key==NB_SHARE) and NBShareOwned() or NBOwns(key)
    local display='--'
    local font='$(BOLD_FONT)|23|soft-shadow-thick'
    -- A character's critical chance exists independently of the mastery.
    -- Never gate this visible number on an ID or purchase-state lookup.
    if key==NB_NOCTURNAL then
      local crit=NBWeaponCritChance()
      -- Make the actual proc counter the LARGE centered number. Crit chance
      -- remains visible in the small top corner. Even x0 is clearly visible.
      local confirmed=nb.procs[NB_NOCTURNAL].count
      local inferred=nb.nocturnal.estimated
      display=(inferred>0 and '~x' or 'x')..tostring(confirmed+inferred)
      font='$(BOLD_FONT)|23|soft-shadow-thick'
      local chance=(crit~=nil) and string.format('%.1f%%',crit) or '?'
      if widget.lastAmount~=chance then
        widget.amount:SetText(chance);widget.lastAmount=chance
      end
    elseif owned then
      if key==NB_EYE then
        local missing,pvp=NBTargetHealth()
        if missing then
          local maxValue=pvp and 1000 or 2000
          display='~+'..tostring(math.floor(maxValue*missing+0.5))
          font='$(BOLD_FONT)|19|soft-shadow-thick'
          -- Damage reduction applies to the last verified attacker, not all
          -- mobs: only show it if that attacker is the current target.
          local reduction=NBCompareTargetAndAttacker(now) and
            ('~-'..tostring(math.floor((pvp and 10 or 20)*missing+0.5))..'%') or ''
          if widget.lastAmount~=reduction then
            widget.amount:SetText(reduction);widget.lastAmount=reduction
          end
        end
      elseif key==NB_SHARE then
        local proc=nb.procs[NB_SHARE]
        local last=math.max(proc.at,nb.share.testAt)
        if now<last+4 then
          -- Keep the 4..1 internal cooldown visible even during the green flash.
          display=tostring(math.max(1,math.ceil(last+4-now)))
        else
          display='x'..tostring(proc.count)
        end
      end
    end
    if key==NB_SHARE then
      if not widget.nbShareGroup and WINDOW_MANAGER then
        local label=WINDOW_MANAGER:CreateControl(nil,widget.win,CT_LABEL)
        label:SetAnchor(BOTTOMLEFT,widget.win,BOTTOMLEFT,2,-2)
        label:SetDimensions(30,19)
        label:SetFont('$(BOLD_FONT)|14|soft-shadow-thick')
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        label:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
        label:SetColor(.45,.80,1,1)
        label:SetMouseEnabled(false)
        widget.nbShareGroup=label
      end
      if widget.nbShareGroup then
        widget.nbShareGroup:SetHidden(not owned)
        widget.nbShareGroup:SetText(owned and '+2' or '')
      end
      -- Bottom/right timer is the large cooldown, +4 at top right and +2
      -- at bottom left; no invented percentage or long-running buff.
    end
    if key==NB_SHARE and owned==nil then display='?' end
    if widget.font~=font then widget.timer:SetFont(font);widget.font=font end
    if widget.lastText~=display then widget.timer:SetText(display);widget.lastText=display end
    return
  end
end


