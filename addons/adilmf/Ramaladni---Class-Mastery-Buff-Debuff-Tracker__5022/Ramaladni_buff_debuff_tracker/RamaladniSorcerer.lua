-- Ramaladni Tracker v0.9.23 — Sorcerer isolated runtime.
-- Mechanics copied from the v0.9.22 reference; other classes are not modified.
local M=RamaladniMastery
local shared=M.shared
local SkillState,LeadNow,HideState=shared.SkillState,shared.LeadNow,shared.HideState
local lead=shared.lead
local runtime={}
M.modules["Sorcerer"]=runtime
do
local e={key="Sorcerer:Conservation of Energy",class="Sorcerer",en="Conservation of Energy",title="Сохранение энергии / Conservation of Energy",passiveId=263870,candidateIDs={263877,263901},model="observed_stacks",value=0,cap=0,target=false,kind="instant_proc_counter",mechanic="Rank 2 Blood Magic: any paid non-cost-per-tick ability restores Magicka and Stamina; exact amount scales with maximum resources",durationRule="Instant activation; count observed eligible casts, no invented timer"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Sorcerer:Font of Power",class="Sorcerer",en="Font of Power",title="Источник силы / Font of Power",passiveId=263871,candidateIDs={263878},model="conditional_percent",value=15,cap=0,target=false,kind="dynamic_percent+timer",mechanic="Rank 2 Dark Magic prerequisite: Sorcerer skill grants +15% Weapon/Spell Damage plus 1% per complete 1750 maximum Magicka or Stamina (higher value)",durationRule="10 sec from eligible Sorcerer ability; calculated from actual use, marked estimated unless ESO reports endTime"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Sorcerer:Static Reverberation",class="Sorcerer",en="Static Reverberation",title="Статический резонанс / Static Reverberation",passiveId=263872,candidateIDs={263928},model="observed_stacks",value=5,cap=0,target=false,kind="conditional_chance",mechanic="5% +1% per 1% missing target HP; divided by (1 + own active permanent pets), 1441 Shock Damage",durationRule="Instant damage proc; internal minimum 0.3 sec between procs; no aura timer"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Sorcerer:Calculated Defense",class="Sorcerer",en="Calculated Defense",title="Расчётливая защита / Calculated Defense",passiveId=263873,candidateIDs={264991,268274},model="timed_percent",value=6,cap=0,target=false,kind="two_phase_timer+percent",mechanic="0.5 sec shield when Sorcerer ability or cast-time skill begins; if shield survives, self/nearby group +6% Weapon/Spell Damage",durationRule="0.5 sec shield; 20 sec bonus ONLY when actual own mastery proc is observed"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Sorcerer:Sphere of Influence",class="Sorcerer",en="Sphere of Influence",title="Сфера влияния / Sphere of Influence",passiveId=263874,candidateIDs={263915,268275},model="observed_stacks",value=225,cap=0,target=false,kind="two_timer+numeric",mechanic="Casting a shield on self/ally: an extra 4 sec shield and +225 Health/Magicka/Stamina Recovery for 12 sec",durationRule="Separate observable 4 sec shield and 12 sec recovery phases"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end

-- v0.9.15 SORCERER ONLY. All calculations below are segregated from
-- Warden, DK, Arcanist and other mastery runtimes. Avoid generic group
-- aura IDs: they do not prove this Sorcerer's mastery was responsible.
-- HideState comes from the core shared interface
local SORC_CONSERVATION='Sorcerer:Conservation of Energy'
local SORC_FONT='Sorcerer:Font of Power'
local SORC_STATIC='Sorcerer:Static Reverberation'
local SORC_DEFENSE='Sorcerer:Calculated Defense'
local SORC_SPHERE='Sorcerer:Sphere of Influence'
local SORC_KEYS={SORC_CONSERVATION,SORC_FONT,SORC_STATIC,SORC_DEFENSE,SORC_SPHERE}
local sorc={initialized=false,debug=false,casts=0,paid=0,classCasts=0,
  conservation={at=-100,count=0,lastId=0},font={untilTime=0,observed=false,lastId=0},
  static={at=-100,count=0,lastId=0},defense={shieldUntil=0,bonusUntil=0,
       shieldObserved=false,bonusObserved=false,lastId=0},
  sphere={shieldUntil=0,recoveryUntil=0,shieldObserved=false,recoveryObserved=false,
          shieldId=0,recoveryId=0,lastId=0,lastCastId=0,lastUnit='',
          lastSource='none',lastCandidate=0,probeCount=0},
  recentCastAt=-100,lastEligibleAt=-100,lastShieldCastAt=-100,unknownPets=nil,
  shieldEvents=0,lastShieldReason='none',
  lastAbility=0,lastCost=0,lastPerTick=nil,lastClass=nil}
local function SorcPrint(message)
  if d then d('|c8AB5FFRamaladni Sorc|r '..tostring(message)) end
end
local function SorcLearned(key)
  return SkillState(RamaladniMastery.byKey[key])==true
end
local function SorcMaxPower(powerType)
  if not (GetUnitPower and powerType) then return nil end
  local _,maximum,effective=GetUnitPower('player',powerType)
  if type(effective)=='number' and effective>0 then return effective end
  if type(maximum)=='number' and maximum>0 then return maximum end
  return nil
end
local function SorcRank2(names)
  if not (SKILL_TYPE_CLASS and GetNumSkillLines and GetNumSkillAbilities and
          GetSkillAbilityInfo) then return nil end
  for line=1,GetNumSkillLines(SKILL_TYPE_CLASS) do
    for i=1,GetNumSkillAbilities(SKILL_TYPE_CLASS,line) do
      local name,_,earnedRank,_,_,purchased,_,rank=
        GetSkillAbilityInfo(SKILL_TYPE_CLASS,line,i)
      if type(name)=='string' then
        local normalized=name:lower():gsub('%^%a+$','')
        for _,wanted in ipairs(names) do
          if normalized==wanted:lower() then
            if purchased~=true then return false end
            local actual=tonumber(rank) or tonumber(earnedRank)
            if actual==nil then return nil end
            return actual>=2
          end
        end
      end
    end
  end
  return nil -- unknown client localization; never pretend rank II was verified
end
local SORC_BLOOD_NAMES={'Blood Magic','Магия крови'}
local SORC_EXPLOIT_NAMES={'Exploitation','Ruthlessness','Беспощадность','Эксплуатация'}
local function SorcClassAbility(id)
  if not (type(id)=='number' and id>0) then return false end
  -- Engine mapping includes the currently morphed spell, not just its base ID.
  if GetSpecificSkillAbilityKeysByAbilityId and SKILL_TYPE_CLASS then
    local skillType=GetSpecificSkillAbilityKeysByAbilityId(id)
    if type(skillType)=='number' then return skillType==SKILL_TYPE_CLASS end
  end
  if not (GetNumSkillLines and GetNumSkillAbilities and GetSkillAbilityId and
          SKILL_TYPE_CLASS) then return false end
  for line=1,GetNumSkillLines(SKILL_TYPE_CLASS) do
    for index=1,GetNumSkillAbilities(SKILL_TYPE_CLASS,line) do
      if GetSkillAbilityId(SKILL_TYPE_CLASS,line,index,false)==id then return true end
    end
  end
  return false
end
local function SorcAbilityPaid(id)
  if not (GetAbilityBaseCostInfo and type(id)=='number' and id>0) then
    return false,nil,nil -- No cost API: do not count free or tick casts.
  end
  local cost,flags,perTick=GetAbilityBaseCostInfo(id,nil,'player')
  if type(cost)~='number' or cost<=0 or perTick==true then
    return false,cost,perTick
  end
  -- The base-cost function already excludes free abilities. Require a
  -- resource flag if available, rather than counting an unknown cost type.
  if flags~=nil then
    local recognized=false
    for _,flag in ipairs({COMBAT_MECHANIC_FLAGS_MAGICKA,
        COMBAT_MECHANIC_FLAGS_STAMINA,COMBAT_MECHANIC_FLAGS_HEALTH,
        COMBAT_MECHANIC_FLAGS_ULTIMATE}) do
      if flag and flags==flag then recognized=true end
    end
    if not recognized then
      for _,flag in ipairs({COMBAT_MECHANIC_FLAGS_MAGICKA,
          COMBAT_MECHANIC_FLAGS_STAMINA,COMBAT_MECHANIC_FLAGS_HEALTH,
          COMBAT_MECHANIC_FLAGS_ULTIMATE}) do
        if type(flags)=='number' and type(flag)=='number' and flag>0 and
           math.floor(flags/flag)%2==1 then recognized=true end
      end
    end
    if not recognized then return false,cost,perTick end
  end
  return true,cost,perTick
end
local function SorcOwnSource(sourceType)
  return sourceType==nil or COMBAT_UNIT_TYPE_PLAYER==nil or
         sourceType==COMBAT_UNIT_TYPE_PLAYER
end
-- Sphere of Influence triggers on a SHIELD CAST, not merely when either
-- candidate effect ID happens to appear. This also supports shields whose
-- spawned ESO effect IDs differ from the ESO Logs catalog.
-- The prediction is explicitly marked ~ until the client confirms an aura.
local SORC_SHIELD_NAMES={
  ['conjured ward']=true,['hardened ward']=true,
  ['regenerative ward']=true,['empowered ward']=true,
  ['призванный оберег']=true,['закалённый оберег']=true,
  ['закаленный оберег']=true,['регенерирующий оберег']=true,
  ['прочный оберег']=true,['призванный оберег']=true,
  ['сияющий щит']=true,['лечебный оберег']=true,
  ['поглощение магии']=true,['магический оберег']=true,
  ['dampen magic']=true,['harness magicka']=true,
  ['healing ward']=true,['steadfast ward']=true,
  ['shimmering shield']=true,['radiant ward']=true,
}
local function SorcShieldAbility(id)
  if type(id)~='number' or id<=0 then return false,'bad-id' end
  local name=GetAbilityName and GetAbilityName(id)
  local normalized=(type(name)=='string' and name or ''):lower()
  normalized=normalized:gsub('%^%a+$',''):gsub('^%s+',''):gsub('%s+$','')
  if SORC_SHIELD_NAMES[normalized] then return true,'skill-name' end
  -- The full ability text is not always available for morphed skills.
  -- Detect clear shield-only spell names in that case, but avoid the
  -- unrelated passive's own 263874 ID and its effect candidates.
  if id~=263874 and id~=263915 and id~=268275 and
      (normalized:find('щит',1,true) or normalized:find('оберег',1,true) or
       normalized:find('shield',1,true) or
       (normalized:find('ward',1,true) and not normalized:find('reward',1,true))) then
    return true,'shield-name'
  end
  if not GetAbilityDescription then return false,'no-description-API' end
  local description=GetAbilityDescription(id)
  if type(description)~='string' or description=='' then return false,'empty-tooltip' end
  local d=description:lower()
  -- Use shield-specific descriptions in either ESO language; merely seeing
  -- the word 'protection' does not imply an actual damage shield cast.
  if d:find('damage shield',1,true) or d:find('shield that absorbs',1,true) or
     d:find('щит',1,true) or d:find('поглощает',1,true) and d:find('урон',1,true) then
    return true,'tooltip'
  end
  return false,'non-shield'
end
local function SorcStartSpherePrediction(id,now)
  local p=sorc.sphere
  sorc.lastShieldCastAt=now
  p.lastCastId=id
  p.probeCount=0
  p.lastSource='shield-cast (estimated)'
  p.lastUnit='own cast / target not guaranteed'
  p.shieldUntil=now+4
  p.recoveryUntil=now+12
  p.shieldObserved=false
  p.recoveryObserved=false
  p.shieldId=0
  p.recoveryId=0
end
-- The client can expose a shield application even when it does not send
-- EVENT_ACTION_SLOT_ABILITY_USED (or the slot's tooltip cannot be resolved).
-- This is only a fallback for OUR shield on player/group member, not a
-- generic source-less group aura.
local function SorcShieldApplied(_,change,_,name,unitTag,start,finish,stacks,
                                 icon,buffType,effectType,abilityType,statusType,
                                 unitName,unitId,abilityId,sourceType)
  if change~=EFFECT_RESULT_GAINED and change~=EFFECT_RESULT_FULL_REFRESH then return end
  if BUFF_EFFECT_TYPE_DEBUFF~=nil and effectType==BUFF_EFFECT_TYPE_DEBUFF then return end
  if not (unitTag=='player' or
     (type(unitTag)=='string' and unitTag:match('^group%d+$'))) then return end
  if type(abilityId)~='number' or abilityId<=0 or
     abilityId==263874 or abilityId==263915 or abilityId==268275 then return end
  -- Do not assume the passive exists when its ownership is explicitly false.
  if SkillState(RamaladniMastery.byKey[SORC_SPHERE])==false then return end
  local now=LeadNow()
  local own=SorcOwnSource(sourceType) and sourceType~=nil and
            (COMBAT_UNIT_TYPE_PLAYER==nil or sourceType==COMBAT_UNIT_TYPE_PLAYER)
  -- NONE is only accepted when an own shield cast was just detected.
  if not own and now-sorc.lastShieldCastAt>1.5 then return end
  local isShield,reason=SorcShieldAbility(abilityId)
  if not isShield and type(name)=='string' then
    local normalized=name:lower()
    if SORC_SHIELD_NAMES[normalized] or
       normalized:find('оберег',1,true) or
       normalized:find('damage shield',1,true) then
       isShield=true;reason='effect-name'
    end
  end
  if not isShield then return end
  sorc.shieldEvents=sorc.shieldEvents+1
  sorc.lastShieldReason=reason
  -- An aura often arrives just after the action-slot callback. Do NOT
  -- restart the prediction for the same cast, or a refresh tick.
  if now-sorc.lastShieldCastAt>=1.5 then
    SorcStartSpherePrediction(abilityId,now)
    sorc.sphere.lastSource='own-shield-aura ('..reason..', estimated)'
    sorc.sphere.lastUnit=unitTag
  end
  if sorc.debug then
    SorcPrint(string.format('SPHERE shield applied id=%s name=%s target=%s reason=%s',
       tostring(abilityId),tostring(name),tostring(unitTag),tostring(reason)))
  end
end
local function SorcAbilityCast(_,slot)
  if not (GetSlotBoundId and type(slot)=='number') then return end
  local id=GetSlotBoundId(slot)
  if type(id)~='number' or id<=0 then return end
  local now=LeadNow()
  sorc.casts=sorc.casts+1
  sorc.lastAbility=id
  sorc.recentCastAt=now
  local classSkill=SorcClassAbility(id)
  sorc.lastClass=classSkill
  if classSkill then sorc.classCasts=sorc.classCasts+1 end
  local paid,cost,perTick=SorcAbilityPaid(id)
  sorc.lastCost=cost or 0;sorc.lastPerTick=perTick
  local isShield,shieldReason=SorcShieldAbility(id)
  if isShield and SkillState(RamaladniMastery.byKey[SORC_SPHERE])~=false then
    SorcStartSpherePrediction(id,now)
    sorc.lastShieldReason=shieldReason
  end
  if paid and SorcLearned(SORC_CONSERVATION) and
      SorcRank2(SORC_BLOOD_NAMES)==true then
    sorc.paid=sorc.paid+1
    local proc=sorc.conservation
    proc.count=proc.count+1;proc.at=now;proc.lastId=id
  end
  if classSkill and SorcLearned(SORC_FONT) and
      SorcRank2(SORC_EXPLOIT_NAMES)==true then
    local proc=sorc.font
    proc.untilTime=now+10;proc.observed=false;proc.lastId=id
  end
  -- Only the short initial shield is predicted. Survival cannot be inferred
  -- from a cast, so the 20 sec group bonus needs its own real observed proc.
  local castTime=0
  if GetAbilityCastInfo then
    local a,b=GetAbilityCastInfo(id)
    if type(b)=='number' then castTime=b end
    if type(a)=='number' then castTime=a end
  end
  if (classSkill or castTime>0) and SorcLearned(SORC_DEFENSE) then
    sorc.defense.shieldUntil=now+.5
    sorc.defense.shieldObserved=false
    sorc.lastEligibleAt=now
  end
  if sorc.debug then
    SorcPrint(string.format('cast id=%s sorc=%s paid=%s cost=%s perTick=%s castMS=%s shield=%s (%s)',
      tostring(id),tostring(classSkill),tostring(paid),tostring(cost),
      tostring(perTick),tostring(castTime),tostring(isShield),tostring(shieldReason)))
  end
end
-- Known candidate IDs are for event discovery only; do not infer an aura
-- duration from them, and do not treat another player's aura as our mastery.
local SORC_AURA_IDS={
  [263877]=SORC_CONSERVATION,[263901]=SORC_CONSERVATION,
  [263878]=SORC_FONT,[264991]=SORC_DEFENSE,[268274]=SORC_DEFENSE,
  [263915]=SORC_SPHERE,[268275]=SORC_SPHERE,
}
local function SorcAura(_,change,_,name,unitTag,start,finish,stacks,
                        icon,buffType,effectType,abilityType,statusType,
                        unitName,unitId,abilityId,sourceType)
  local key=SORC_AURA_IDS[abilityId]
  if not key or not SorcLearned(key) then return end
  local now=LeadNow()
  if key==SORC_SPHERE then
    -- A Sphere shield/recovery can land on an ALLY rather than on 'player'.
    -- Some ESO buffs report sourceType NONE, so own shield-cast correlation
    -- is stronger than requiring COMBAT_UNIT_TYPE_PLAYER unconditionally.
    if now-sorc.lastShieldCastAt>2.5 then return end
    if not (SorcOwnSource(sourceType) or
       (COMBAT_UNIT_TYPE_NONE~=nil and sourceType==COMBAT_UNIT_TYPE_NONE)) then return end
  elseif unitTag~='player' or not SorcOwnSource(sourceType) then
    return
  end
  local gained=change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED or
               change==EFFECT_RESULT_FULL_REFRESH
  if key==SORC_CONSERVATION then
    -- A precise resource restoring proc is instant; if casts were already
    -- counted, do not double count the same action.
    if gained and now-sorc.conservation.at>1.5 then
      local c=sorc.conservation;c.at=now;c.count=c.count+1;c.lastId=abilityId
    end
  elseif key==SORC_FONT then
    if gained and type(finish)=='number' and finish>now and
        now-sorc.recentCastAt<=1.5 and sorc.lastClass==true then
      sorc.font.untilTime=finish;sorc.font.observed=true
      sorc.font.lastId=abilityId
    end
  elseif key==SORC_DEFENSE then
    if gained and type(finish)=='number' and finish>now then
      local duration=(type(start)=='number' and start>0) and finish-start or finish-now
      if duration>=8 and now-sorc.lastEligibleAt<=2 then
        sorc.defense.bonusUntil=finish
        sorc.defense.bonusObserved=true;sorc.defense.bonusId=abilityId;sorc.defense.lastId=abilityId
      elseif duration>0 and duration<=1.3 then
        sorc.defense.shieldUntil=finish
        sorc.defense.shieldObserved=true;sorc.defense.shieldId=abilityId;sorc.defense.lastId=abilityId
      end
    elseif change==EFFECT_RESULT_FADED then
      -- A 0.5s shield fade must NEVER cancel a separate 20s group bonus.
      if sorc.defense.shieldId==abilityId then sorc.defense.shieldUntil=0 end
      if sorc.defense.bonusId==abilityId and
          (sorc.defense.shieldId~=abilityId or now>=sorc.defense.shieldUntil) then
        sorc.defense.bonusUntil=0
      end
    end
  elseif key==SORC_SPHERE then
    local p=sorc.sphere
    if gained and type(finish)=='number' and finish>now then
      local duration=(type(start)=='number' and start>0) and finish-start or finish-now
      if duration>=8 and duration<=18 then
        p.recoveryUntil=finish;p.recoveryObserved=true;p.recoveryId=abilityId
      elseif duration>0 and duration<=6 then
        p.shieldUntil=finish;p.shieldObserved=true;p.shieldId=abilityId
      end
      p.lastId=abilityId;p.lastUnit=unitTag or unitName or 'unknown'
      p.lastSource='ESO effect'
    elseif change==EFFECT_RESULT_FADED then
      -- Expiry of the shield must never stop the independent regeneration.
      -- Old fades must not erase a newer shield cast from the same ability.
      if p.shieldObserved and p.shieldId==abilityId and
          p.shieldUntil<=now+0.5 then p.shieldUntil=0 end
      if p.recoveryObserved and p.recoveryId==abilityId and
          p.recoveryUntil<=now+0.5 then p.recoveryUntil=0 end
    end
  end
  if sorc.debug then
    SorcPrint(string.format('aura key=%s id=%s change=%s duration=%s finish=%s',
      key,tostring(abilityId),tostring(change),
      tostring(type(finish)=='number' and type(start)=='number' and finish-start or '?'),
      tostring(finish)))
  end
end
local function SorcStaticHit(_,result,isError,abilityName,abilityGraphic,slotType,
                             sourceName,sourceType,targetName,targetType,hitValue,
                             powerType,damageType,log,sourceUnitId,targetUnitId,abilityId)
  if abilityId~=263928 or isError or not SorcLearned(SORC_STATIC) or
     not SorcOwnSource(sourceType) then return end
  if type(hitValue)~='number' or hitValue<=0 then return end
  local now=LeadNow()
  -- Multiple log records may describe one hit; this is not an aura timer.
  if now-sorc.static.at>=0.295 then
    sorc.static.at=now;sorc.static.count=sorc.static.count+1
    sorc.static.lastId=abilityId
    if sorc.debug then SorcPrint('static observed Shock proc '..tostring(hitValue)) end
  end
end
-- Only count recognizable permanent Sorcerer combat creatures. ESO also
-- exposes temporary pets, companions and noncombat collectables under pet tags.
local SORC_PET_NAMES={'familiar','clannfear','twilight','volatile','бес','кланнфир',
                      'сумрак','крылат','матриарх','истязатель'}
local function SorcPermanentPets()
  if not (DoesUnitExist and GetUnitName) then return nil end
  local count,unknown=0,0
  local base=UNIT_PLAYER_PET or 'playerpet'
  for i=1,7 do
    local tag=base..i
    if DoesUnitExist(tag) then
      local name=GetUnitName(tag)
      local normal=type(name)=='string' and name:lower() or ''
      local recognized=false
      for _,phrase in ipairs(SORC_PET_NAMES) do
        if normal:find(phrase,1,true) then recognized=true;break end
      end
      if recognized then count=count+1 elseif normal~='' then unknown=unknown+1 end
    end
  end
  sorc.unknownPets=unknown
  -- Unknown pet type: omit chance rather than silently divide by wrong count.
  if unknown>0 then return nil end
  return count
end
local function SorcStaticChance()
  if not (DoesUnitExist and DoesUnitExist('reticleover') and GetUnitPower and
          POWERTYPE_HEALTH) then return nil end
  local current,maximum=GetUnitPower('reticleover',POWERTYPE_HEALTH)
  if type(current)~='number' or type(maximum)~='number' or maximum<=0 then return nil end
  local pets=SorcPermanentPets()
  if pets==nil then return nil end
  local missing=math.max(0,math.min(100,(1-current/maximum)*100))
  return math.min(100,(5+missing)/(1+pets)),pets
end
local function SorcDisplay(key,state,now)
  -- Some game builds expose Class Mastery passives under a separate skill
  -- line; unknown ownership must not silently suppress an observed shield.
  local owned=SkillState(RamaladniMastery.byKey[key])
  if owned==false or (owned~=true and key~=SORC_SPHERE) then
    HideState(state);state.cooldownUntil=0;return true,nil
  end
  state.cooldownUntil=0
  state.timerEstimated=false
  if key==SORC_CONSERVATION then
    local c=sorc.conservation
    state.untilTime=0;state.activeFlag=(now-c.at<0.9)
    if state.activeFlag then return true,'x'..tostring(c.count) end
    return true,nil
  elseif key==SORC_FONT then
    local p=sorc.font
    if SorcRank2(SORC_EXPLOIT_NAMES)~=true then HideState(state);return true,nil end
    if p.untilTime>now then
      state.untilTime=p.untilTime;state.activeFlag=true
      state.timerEstimated=not p.observed
      local m=SorcMaxPower(POWERTYPE_MAGICKA)
      local s=SorcMaxPower(POWERTYPE_STAMINA)
      if m==nil and s==nil then return true,'15%+' end
      local highest=math.max(m or 0,s or 0)
      return true,tostring(15+math.floor(highest/1750))..'%'
    end
  elseif key==SORC_STATIC then
    state.untilTime=0
    local chance=SorcStaticChance()
    local flashed=now-sorc.static.at<0.9
    state.activeFlag=flashed or chance~=nil
    if flashed then return true,'x'..tostring(sorc.static.count) end
    if chance~=nil then return true,string.format('%.1f%%',chance) end
    return true,nil
  elseif key==SORC_DEFENSE then
    local proc=sorc.defense
    if proc.bonusUntil>now then
      state.untilTime=proc.bonusUntil;state.activeFlag=true
      state.timerEstimated=not proc.bonusObserved
      return true,'6%'
    end
    if proc.shieldUntil>now then
      state.untilTime=proc.shieldUntil;state.activeFlag=true
      state.timerEstimated=not proc.shieldObserved
      return true,'щит'
    end
  elseif key==SORC_SPHERE then
    local proc=sorc.sphere
    -- 12 sec recovery is the primary timer; if only the shield is present,
    -- show its 4 sec window instead. Distinct observed procs, no cast guesses.
    if proc.recoveryUntil>now then
      state.untilTime=proc.recoveryUntil;state.activeFlag=true
      state.timerEstimated=not proc.recoveryObserved
      return true,'+225'
    end
    if proc.shieldUntil>now then
      state.untilTime=proc.shieldUntil;state.activeFlag=true
      state.timerEstimated=not proc.shieldObserved
      return true,'щит'
    end
  end
  HideState(state)
  return true,nil
end
local function SorcDebug(input)
  local command=(input or ''):lower():match('^%s*(.-)%s*$')
  if command=='sphere test' then
    if SkillState(RamaladniMastery.byKey[SORC_SPHERE])==false then
      SorcPrint('Sphere TEST: passive explicitly not learned.');return
    end
    SorcStartSpherePrediction(0,LeadNow())
    sorc.sphere.lastSource='explicit TEST (not actual effect)'
    SorcPrint('Sphere TEST: ~12 / +225 and ~Щ4 should show on the HUD.')
    return
  end
  if command=='debug' then
    sorc.debug=not sorc.debug
    if sorc.debug then
      EVENT_MANAGER:RegisterForEvent('RamaladniSorc_SphereProbe',
        EVENT_EFFECT_CHANGED,SorcSphereProbe)
    else
      EVENT_MANAGER:UnregisterForEvent('RamaladniSorc_SphereProbe',EVENT_EFFECT_CHANGED)
    end
    SorcPrint('debug '..(sorc.debug and 'ON' or 'OFF'))
  end
  local m=SorcMaxPower(POWERTYPE_MAGICKA)
  local s=SorcMaxPower(POWERTYPE_STAMINA)
  local chance,pets=SorcStaticChance()
  SorcPrint(string.format('BloodII=%s ExploitII=%s casts=%d paid=%d sorcCasts=%d lastAbility=%d cost=%s perTick=%s class=%s',
    tostring(SorcRank2(SORC_BLOOD_NAMES)),tostring(SorcRank2(SORC_EXPLOIT_NAMES)),
    sorc.casts,sorc.paid,sorc.classCasts,sorc.lastAbility,tostring(sorc.lastCost),
    tostring(sorc.lastPerTick),tostring(sorc.lastClass)))
  SorcPrint(string.format('masteries: conservation=%s font=%s static=%s defense=%s sphere=%s',
    tostring(SorcLearned(SORC_CONSERVATION)),tostring(SorcLearned(SORC_FONT)),
    tostring(SorcLearned(SORC_STATIC)),tostring(SorcLearned(SORC_DEFENSE)),
    tostring(SorcLearned(SORC_SPHERE))))
  SorcPrint(string.format('maxMag=%s maxStam=%s staticChance=%s pets=%s unknownPets=%s procCount=%d',
    tostring(m),tostring(s),chance and string.format('%.1f%%',chance) or '?',
    tostring(pets),tostring(sorc.unknownPets),sorc.static.count))
  SorcPrint(string.format('fontUntil=%.1f defenseShield=%.1f defenseBonus=%.1f sphereShield=%.1f sphereRegen=%.1f',
    sorc.font.untilTime,sorc.defense.shieldUntil,sorc.defense.bonusUntil,
    sorc.sphere.shieldUntil,sorc.sphere.recoveryUntil))
  local p=sorc.sphere
  SorcPrint(string.format('sphere lastCast=%s shieldLeft=%.1fs regenLeft=%.1fs shieldESO=%s regenESO=%s eventId=%s source=%s target=%s',
    tostring(p.lastCastId),math.max(0,p.shieldUntil-LeadNow()),
    math.max(0,p.recoveryUntil-LeadNow()),tostring(p.shieldObserved),
    tostring(p.recoveryObserved),tostring(p.lastId),p.lastSource,p.lastUnit))
  SorcPrint('shield events='..tostring(sorc.shieldEvents)..
    ' lastShieldReason='..tostring(sorc.lastShieldReason))
end
-- Optional event discovery: only enabled by /rmsorc debug, only around
-- a recognized shield cast. Captures unverified IDs WITHOUT activating a
-- mastery timer from arbitrary nearby buffs.
SorcSphereProbe=function(_,change,_,name,unitTag,start,finish,_,_,_,effectType,
                              _,_,unitName,unitId,abilityId,sourceType)
  if change~=EFFECT_RESULT_GAINED and change~=EFFECT_RESULT_UPDATED and
     change~=EFFECT_RESULT_FULL_REFRESH then return end
  local now=LeadNow()
  if now-sorc.lastShieldCastAt>2.5 then return end
  if type(finish)~='number' or finish<=now then return end
  if not (SorcOwnSource(sourceType) or
     (COMBAT_UNIT_TYPE_NONE~=nil and sourceType==COMBAT_UNIT_TYPE_NONE)) then return end
  if BUFF_EFFECT_TYPE_DEBUFF~=nil and effectType==BUFF_EFFECT_TYPE_DEBUFF then return end
  local duration=(type(start)=='number' and start>0) and finish-start or finish-now
  if not ((duration>=2.5 and duration<=5.5) or
          (duration>=10 and duration<=14)) then return end
  local p=sorc.sphere
  if p.probeCount>=12 then return end
  p.probeCount=p.probeCount+1
  SorcPrint(string.format('SPHERE candidate id=%s name=%s target=%s/%s duration=%.1f src=%s (unverified)',
    tostring(abilityId),tostring(name),tostring(unitTag),tostring(unitName),
    duration,tostring(sourceType)))
end
local function InitSorc()
  if sorc.initialized then return end
  sorc.initialized=true
  SLASH_COMMANDS['/rmsorc']=SorcDebug
  EVENT_MANAGER:RegisterForEvent('RamaladniSorc_Cast',EVENT_ACTION_SLOT_ABILITY_USED,
    SorcAbilityCast)
  -- Recover own shield gains when action-slot events do not fire.
  EVENT_MANAGER:RegisterForEvent('RamaladniSorc_ShieldApplied',
    EVENT_EFFECT_CHANGED,SorcShieldApplied)
  for id in pairs(SORC_AURA_IDS) do
    local namespace='RamaladniSorc_Aura_'..tostring(id)
    EVENT_MANAGER:RegisterForEvent(namespace,EVENT_EFFECT_CHANGED,SorcAura)
    EVENT_MANAGER:AddFilterForEvent(namespace,EVENT_EFFECT_CHANGED,
      REGISTER_FILTER_ABILITY_ID,id)
  end
  if EVENT_COMBAT_EVENT then
    EVENT_MANAGER:RegisterForEvent('RamaladniSorc_Static',EVENT_COMBAT_EVENT,
      SorcStaticHit)
    EVENT_MANAGER:AddFilterForEvent('RamaladniSorc_Static',EVENT_COMBAT_EVENT,
      REGISTER_FILTER_ABILITY_ID,263928)
  end
end


runtime.Init=InitSorc
runtime.Display=SorcDisplay
runtime.UpdateWidgetExtras=function(entry,widget,now)
  local active=entry and entry.kind=='mastery' and
               entry.masteryKey==SORC_SPHERE
  if not active then
    if widget.sphereShieldLabel then widget.sphereShieldLabel:SetHidden(true) end
    if widget.sphereSmallFont then
      widget.amount:SetFont('$(BOLD_FONT)|19|soft-shadow-thick')
      widget.sphereSmallFont=false
    end
    return
  end
  if not widget.sphereShieldLabel then
    if not WINDOW_MANAGER then return end
    local label=WINDOW_MANAGER:CreateControl(nil,widget.win,CT_LABEL)
    label:SetAnchor(BOTTOMLEFT,widget.win,BOTTOMLEFT,2,-2)
    label:SetDimensions(27,20)
    label:SetFont('$(BOLD_FONT)|15|soft-shadow-thick')
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    label:SetColor(.40,.85,1,1)
    label:SetMouseEnabled(false)
    widget.sphereShieldLabel=label
  end
  if not widget.sphereSmallFont then
    widget.amount:SetFont('$(BOLD_FONT)|17|soft-shadow-thick')
    widget.sphereSmallFont=true
  end
  local p=sorc.sphere
  local remaining=p.shieldUntil-now
  if remaining>0 then
    local value=(p.shieldObserved and '' or '~')..'Щ'..tostring(math.ceil(remaining))
    if widget.sphereLastShieldText~=value then
      widget.sphereShieldLabel:SetText(value)
      widget.sphereLastShieldText=value
    end
    widget.sphereShieldLabel:SetHidden(false)
  else
    widget.sphereShieldLabel:SetHidden(true)
    widget.sphereLastShieldText=nil
  end
end


