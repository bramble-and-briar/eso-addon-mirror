-- Templar catalog retained from v0.9.22
do
local e={key="Templar:Bastion of Light",class="Templar",en="Bastion of Light",title="Оплот света / Bastion of Light",passiveId=263585,candidateIDs={},model="templar_sacred",value=2144,cap=0,target=false,kind="sacred_ground+healing_tick",mechanic="Sacred Ground: 2144 Health per second; at full Health in combat +2 Ultimate per qualified heal",durationRule="Conditional Sacred Ground uptime; not a 1-second aura timer"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Templar:Devout Guardian",class="Templar",en="Devout Guardian",title="Благочестивый страж / Devout Guardian",passiveId=263586,candidateIDs={},model="templar_shield",value=300,cap=0,target=false,kind="shield_timer+recovery",mechanic="Sacred Ground generates a six-second shield (tooltip capacity 5055), +300 recoveries while shield holds, +10 Ultimate when broken",durationRule="6 sec shield and once-per-6s gate; actual aura endTime overrides estimates"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Templar:Bright Harbinger",class="Templar",en="Bright Harbinger",title="Сияющий предвестник / Bright Harbinger",passiveId=263587,candidateIDs={263672,266179},model="templar_illuminate",value=600,cap=0,target=false,kind="group_numeric+timer",mechanic="Illuminate II grants +300 Weapon/Spell Damage allies, +600 self",durationRule="Match own Bright Harbinger buff endTime; fallback predicted from recognized Dawn Wrath cast"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Templar:Judgment's Brand",class="Templar",en="Judgment's Brand",title="Клеймо правосудия / Judgment's Brand",passiveId=263588,candidateIDs={263660},model="templar_burning",value=1400,cap=0,target=false,kind="numeric+timer",mechanic="+1400 Templar ability damage, half to players",durationRule="3.1 sec from observed owned Burning Light damage; fallback exact own Brand aura"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Templar:Steadfast Candescence",class="Templar",en="Steadfast Candescence",title="Непоколебимое сияние / Steadfast Candescence",passiveId=263589,candidateIDs={263643,263644,263645},model="templar_block",value=0,cap=0,target=false,kind="blocking+stationary",mechanic="Sacred Ground while bracing; blocking benefit while stationary (numeric magnitude differs across tooltips)",durationRule="No timer; IsBlockActive and IsPlayerMoving are checked live"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end

-- Templar isolated module. Loaded after RamaladniMastery.lua.
-- v0.9.22 TEMPLAR ONLY. No alterations to other class mastery runtimes.
-- All proc times from guessed triggers are labeled as ESTIMATES. A class
-- mastery description ID is not evidence that the game emitted its effect.
local function TemplarNow() return GetFrameTimeSeconds() end
local TEM_BASTION='Templar:Bastion of Light'
local TEM_DEVOUT='Templar:Devout Guardian'
local TEM_BRIGHT='Templar:Bright Harbinger'
local TEM_JUDGMENT="Templar:Judgment's Brand"
local TEM_STEADFAST='Templar:Steadfast Candescence'
local templar={initialized=false,debug=false,at=-100,
  sacred={active=false,untilTime=0,observed=false,reason='none'},
  shield={untilTime=0,observed=false,lastStart=-100,nextAt=0,abilityId=0,
    breakAt=-100,breakCount=0,breakEstimated=false},
  bright={untilTime=0,observed=false,abilityId=0,lastCast=0},
  brand={untilTime=0,observed=false,abilityId=0,lastHit=0},
  bastion={healCount=0,ultCount=0,healAt=-100},
  lastCastId=0,lastDawnId=0,lastDawnAt=-100,lastEffectId=0,
  lastEffectName='',lastDamageId=0,unknownSkill=false}
local TEM_AURAS={
  sacred={['sacred ground']=true,['Sacred Ground']=true,
    ['священная земля']=true,['Священная земля']=true,
    -- These two self-buff skills satisfy Sacred Ground while active.
    ['solar barrage']=true,['Solar Barrage']=true,
    ['солнечный обстрел']=true,['Солнечный обстрел']=true,
    ['radial sweep']=true,['Radial Sweep']=true,
    ['empowering sweep']=true,['Empowering Sweep']=true,
    ['crescent sweep']=true,['Crescent Sweep']=true,
    ['круговая жатва']=true,['Круговая жатва']=true},
  shield={['devout guardian']=true,['Devout Guardian']=true,
    ['благочестивый страж']=true,['Благочестивый страж']=true,
    ['преданный защитник']=true,['Преданный защитник']=true},
  bright={['bright harbinger']=true,['Bright Harbinger']=true,
    ['сияющий предвестник']=true,['Сияющий предвестник']=true,
    ['светлый предвестник']=true,['Светлый предвестник']=true},
  brand={['judgment\'s brand']=true,['Judgment\'s Brand']=true,
    ['клеймо правосудия']=true,['Клеймо правосудия']=true},
  burning={['burning light']=true,['Burning Light']=true,
    ['обжигающий свет']=true,['Обжигающий свет']=true},
  bastion={['bastion of light']=true,['Bastion of Light']=true,
    ['оплот света']=true,['Оплот света']=true,
    ['бастион света']=true,['Бастион света']=true},
}
local TEM_DAWN_NAMES={
  ['sun fire']=true,['vampire\'s bane']=true,['reflective light']=true,
  ['solar flare']=true,['dark flare']=true,['solar barrage']=true,
  ['backlash']=true,['purifying light']=true,['power of the light']=true,
  ['eclipse']=true,['living dark']=true,['unstable core']=true,
  ['nova']=true,['solar disturbance']=true,['solar prison']=true,
  ['солнечный огонь']=true,['солнечный обстрел']=true,
  ['солнечная вспышка']=true,['темная вспышка']=true,
  ['тёмная вспышка']=true,['нова']=true,['новая звезда']=true,
  ['возмездие']=true,['очищающий свет']=true,
}
local TEM_ILLUMINATE_NAMES={['illuminate']=true,['освещение']=true,
  ['Освещение']=true,['Illuminate']=true}
local function TemplarLog(v)
  if d then d('|cFFD071Ramaladni Templar|r '..tostring(v)) end
end
local function TemplarName(n)
  if type(n)~='string' then return '' end
  return n:lower():gsub('%^%a+$',''):gsub('^%s+',''):gsub('%s+$','')
end
local function TemplarIs(name,kind)
  local known=TEM_AURAS[kind]
  return type(name)=='string' and (known[name]==true or known[TemplarName(name)]==true)
end
local TEM_PASSIVE_NAMES={
  [TEM_BASTION]={['bastion of light']=true,['оплот света']=true,['бастион света']=true},
  [TEM_DEVOUT]={['devout guardian']=true,['благочестивый страж']=true,['преданный защитник']=true},
  [TEM_BRIGHT]={['bright harbinger']=true,['сияющий предвестник']=true,['светлый предвестник']=true},
  [TEM_JUDGMENT]={['judgment\'s brand']=true,['клеймо правосудия']=true},
  [TEM_STEADFAST]={['steadfast candescence']=true,['непоколебимое сияние']=true,['стойкое сияние']=true},
}
local TEM_OWN_CACHE={}
local function TemplarLearned(key)
  local b=RamaladniMastery.TemplarSkillState(key)
  if b~=nil then return b end
  if GetUnitClassId and GetUnitClassId('player')~=6 then return false end
  local now=TemplarNow()
  local cached=TEM_OWN_CACHE[key]
  if cached and now-cached.time<3 then return cached.state end
  local owned=nil
  if SKILL_TYPE_CLASS and GetNumSkillLines and GetNumSkillAbilities and
      GetSkillAbilityInfo then
    for line=1,(GetNumSkillLines(SKILL_TYPE_CLASS) or 0) do
      for i=1,(GetNumSkillAbilities(SKILL_TYPE_CLASS,line) or 0) do
        local name,_,_,_,_,purchased=GetSkillAbilityInfo(SKILL_TYPE_CLASS,line,i)
        local candidates=TEM_PASSIVE_NAMES[key]
        if candidates and candidates[TemplarName(name)] then
          if IsSkillAbilityPurchased then
            purchased=IsSkillAbilityPurchased(SKILL_TYPE_CLASS,line,i)
          end
          if type(purchased)=='boolean' then owned=purchased end
          break
        end
      end
      if owned~=nil then break end
    end
  end
  TEM_OWN_CACHE[key]={time=now,state=owned}
  return owned -- never mistake UNKNOWN for unlearned or learned
end
-- Does not mistake Illuminate rank 1 or a group aura for own rank 2.
local function TemplarIlluminate2()
  if not (SKILL_TYPE_CLASS and GetNumSkillLines and GetNumSkillAbilities and
    GetSkillAbilityInfo) then return nil end
  for line=1,(GetNumSkillLines(SKILL_TYPE_CLASS) or 0) do
    for i=1,(GetNumSkillAbilities(SKILL_TYPE_CLASS,line) or 0) do
      local name,_,earnedRank,_,_,purchased,_,rank=GetSkillAbilityInfo(SKILL_TYPE_CLASS,line,i)
      if TEM_ILLUMINATE_NAMES[name] or TEM_ILLUMINATE_NAMES[TemplarName(name)] then
        local n=tonumber(rank) or tonumber(earnedRank)
        return purchased==true and n~=nil and n>=2
      end
    end
  end
  return nil -- never default unknown prerequisite to TRUE
end
local function TemplarOwnSource(sourceType)
  return sourceType~=nil and COMBAT_UNIT_TYPE_PLAYER~=nil and
    sourceType==COMBAT_UNIT_TYPE_PLAYER
end
local function TemplarHealthFull()
  if not (GetUnitPower and POWERTYPE_HEALTH) then return false end
  local current,max=GetUnitPower('player',POWERTYPE_HEALTH)
  return type(current)=='number' and type(max)=='number' and max>0 and current>=max
end
local function TemplarInCombat()
  return IsUnitInCombat and IsUnitInCombat('player')==true
end
local function TemplarBlocking()
  return IsBlockActive and IsBlockActive()==true
end
local function TemplarStill()
  return IsPlayerMoving and IsPlayerMoving()==false
end
local function TemplarTryShield(now,source)
  if TemplarLearned(TEM_DEVOUT)~=true then return end
  local p=templar.shield
  if now<p.nextAt-0.05 then return end
  p.lastStart=now;p.untilTime=now+6;p.nextAt=now+6
  p.observed=false;p.abilityId=0
  if templar.debug then TemplarLog('shield ~6s ('..source..')') end
end
local function TemplarReadPlayerAuras(now)
  if now-templar.at<0.17 then return end
  templar.at=now
  local sacred=false
  local sEnd=0
  local shieldEnd=0
  local brightEnd=0
  local brandEnd=0
  local shieldId,brightId,brandId=0,0,0
  if GetNumBuffs and GetUnitBuffInfo then
    local num=GetNumBuffs('player') or 0
    for i=1,math.min(num,128) do
      local name,started,finish,_,_,_,_,effectType,_,_,abilityId,_,castByPlayer=GetUnitBuffInfo('player',i)
      if BUFF_EFFECT_TYPE_DEBUFF==nil or effectType~=BUFF_EFFECT_TYPE_DEBUFF then
        local valid=type(finish)=='number' and finish>now
        if TemplarIs(name,'sacred') then
          sacred=true
          if valid then sEnd=math.max(sEnd,finish) end
        elseif TemplarIs(name,'shield') then
          if valid and finish>shieldEnd then shieldEnd=finish;shieldId=abilityId end
        elseif TemplarIs(name,'bright') then
          if valid and finish>brightEnd then brightEnd=finish;brightId=abilityId end
        elseif TemplarIs(name,'brand') then
          if valid and finish>brandEnd then brandEnd=finish;brandId=abilityId end
        end
      end
    end
  end
  -- Holding block qualifies as Sacred Ground only if the player actually
  -- learned Steadfast Candescence. Stationarity is *not* needed for Ground.
  if TemplarLearned(TEM_STEADFAST)==true and TemplarBlocking() then
    sacred=true;templar.sacred.reason='bracing'
  elseif sacred then
    templar.sacred.reason='actual Sacred Ground aura'
  else
    templar.sacred.reason='unconfirmed'
  end
  local wasSacred=templar.sacred.active
  templar.sacred.active=sacred
  templar.sacred.untilTime=sEnd
  templar.sacred.observed=(sEnd>now)
  if sacred and not wasSacred then TemplarTryShield(now,'Sacred Ground started') end
  -- Reapply only at a 6s gate while Ground continues (shield may have
  -- expired/broken early). A predicted shield is never called verified.
  if sacred and templar.shield.nextAt>0 and now>=templar.shield.nextAt then
    TemplarTryShield(now,'Sacred Ground persists')
  end
  if shieldEnd>now and TemplarLearned(TEM_DEVOUT)~=false then
    local p=templar.shield
    if p.abilityId~=shieldId or p.untilTime<now then p.lastStart=now end
    p.untilTime=shieldEnd;p.nextAt=math.max(p.nextAt,now)
    p.observed=true;p.abilityId=shieldId
  end
  if brightEnd>now then
    local p=templar.bright;p.untilTime=brightEnd;p.observed=true;p.abilityId=brightId
  end
  if brandEnd>now then
    local p=templar.brand;p.untilTime=brandEnd;p.observed=true;p.abilityId=brandId
  end
end
local function TemplarAbilityLine(id)
  if not (SKILL_TYPE_CLASS and GetNumSkillAbilities and GetSkillAbilityId and GetNumSkillLines) then return nil end
  -- The core Templar skill line layout is Aedric Spear (1), Dawn Wrath (2),
  -- Restoring Light (3). Some morph IDs do not equal the base line ID.
  for line=1,(GetNumSkillLines(SKILL_TYPE_CLASS) or 0) do
    for i=1,(GetNumSkillAbilities(SKILL_TYPE_CLASS,line) or 0) do
      for _,morph in ipairs({false,true}) do
        if GetSkillAbilityId(SKILL_TYPE_CLASS,line,i,morph)==id then return line end
      end
    end
  end
  return nil
end
local function TemplarCast(_,slot)
  if not (GetSlotBoundId and type(slot)=='number') then return end
  local id=GetSlotBoundId(slot)
  if type(id)~='number' or id<=0 then return end
  templar.lastCastId=id
  local name=GetAbilityName and GetAbilityName(id) or ''
  local dawn=TEM_DAWN_NAMES[TemplarName(name)] or (TemplarAbilityLine(id)==2)
  if dawn then
    templar.lastDawnId=id;templar.lastDawnAt=TemplarNow()
    if TemplarLearned(TEM_BRIGHT)==true and TemplarIlluminate2()==true then
      local p=templar.bright
      p.untilTime=TemplarNow()+20;p.observed=false;p.abilityId=0;p.lastCast=id
    end
  end
  if templar.debug then TemplarLog('cast '..id..' '..name..' dawn='..tostring(dawn)) end
end
local function TemplarEffect(_,change,_,name,unitTag,start,finish,stacks,
  icon,buffType,effectType,abilityType,statusType,unitName,unitId,abilityId,sourceType)
  if unitTag~='player' then return end
  if BUFF_EFFECT_TYPE_DEBUFF~=nil and effectType==BUFF_EFFECT_TYPE_DEBUFF then return end
  if not (TemplarIs(name,'sacred') or TemplarIs(name,'shield') or
     TemplarIs(name,'bright') or TemplarIs(name,'brand')) then return end
  -- Named OWN mastery buffs are acceptable if the client says owner PLAYER,
  -- and Sacred Ground is a self status; never activate off group aura ID.
  if not (TemplarOwnSource(sourceType) or TemplarIs(name,'sacred')) then return end
  local now=TemplarNow()
  templar.lastEffectId=abilityId or 0;templar.lastEffectName=name or ''
  local gained=change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED or
    change==EFFECT_RESULT_FULL_REFRESH
  if TemplarIs(name,'shield') and TemplarLearned(TEM_DEVOUT)~=false then
    local p=templar.shield
    if gained and type(finish)=='number' and finish>now then
      p.untilTime=finish;p.observed=true;p.abilityId=abilityId or 0
      p.nextAt=math.max(p.nextAt,now+6)
    elseif change==EFFECT_RESULT_FADED then
      -- Only early fade can be a broken shield; natural expiration does not
      -- imply +10 Ultimate. The actual +10 is correlated separately.
      if p.untilTime>now+0.3 then p.breakAt=now end
      p.untilTime=0;p.observed=false
    end
  elseif TemplarIs(name,'bright') and TemplarLearned(TEM_BRIGHT)~=false then
    local p=templar.bright
    if gained and type(finish)=='number' and finish>now then
      p.untilTime=finish;p.observed=true;p.abilityId=abilityId or 0
    elseif change==EFFECT_RESULT_FADED and p.observed and p.abilityId==abilityId then
      p.untilTime=0
    end
  elseif TemplarIs(name,'brand') and TemplarLearned(TEM_JUDGMENT)~=false then
    local p=templar.brand
    if gained and type(finish)=='number' and finish>now then
      p.untilTime=finish;p.observed=true;p.abilityId=abilityId or 0
    elseif change==EFFECT_RESULT_FADED and p.observed and p.abilityId==abilityId then
      p.untilTime=0
    end
  end
  -- The periodically refreshed buff scan handles Sacred Ground and keeps
  -- other observed auras in sync even if some effect events are missed.
  templar.at=-100
end
local function TemplarCombat(_,result,isError,abilityName,graphic,slotType,
  sourceName,sourceType,targetName,targetType,hitValue,powerType,damageType,
  log,sourceUnitId,targetUnitId,abilityId)
  if isError or not TemplarOwnSource(sourceType) then return end
  local now=TemplarNow()
  if TemplarIs(abilityName,'burning') and
     (result==ACTION_RESULT_DAMAGE or result==ACTION_RESULT_CRITICAL_DAMAGE) and
     type(hitValue)=='number' and hitValue>0 then
    if TemplarLearned(TEM_JUDGMENT)==true then
      local p=templar.brand
      p.untilTime=now+3.1;p.observed=false;p.abilityId=abilityId or 0;p.lastHit=now
    end
    templar.lastDamageId=abilityId or 0
    if templar.debug then TemplarLog('Burning Light damage id='..tostring(abilityId)) end
  end
  -- Bastion healing is an *instant tick* without a timer. Count actual
  -- ticks instead of assuming every second standing on Ground healed.
  if TemplarLearned(TEM_BASTION)==true and
     (result==ACTION_RESULT_HEAL or result==ACTION_RESULT_CRITICAL_HEAL or
      result==ACTION_RESULT_HOT_TICK or result==ACTION_RESULT_HOT_TICK_CRITICAL) and
     (TemplarIs(abilityName,'sacred') or TemplarIs(abilityName,'bastion')) and
     TemplarHealthFull() and TemplarInCombat() then
    templar.bastion.healAt=now;templar.bastion.healCount=templar.bastion.healCount+1
  end
end
local function TemplarUltimate(_,unitTag,_,powerType,powerValue,powerMax,powerEffectiveMax)
  -- EVENT_POWER_UPDATE can be dispatched with powerValue but previous
  -- values may be missing. Read current power and compare with snapshot.
  if unitTag~='player' or powerType~=POWERTYPE_ULTIMATE then return end
  local value=tonumber(powerValue)
  if value==nil then return end
  local last=templar.lastUlt
  templar.lastUlt=value
  if type(last)~='number' then return end
  local delta=value-last
  local now=TemplarNow()
  if delta==2 and now-templar.bastion.healAt<=0.6 then
    templar.bastion.ultCount=templar.bastion.ultCount+1
  elseif delta==10 and now-templar.shield.breakAt<=0.6 then
    templar.shield.breakCount=templar.shield.breakCount+1
  end
end
local function TemplarDebug(input)
  local cmd=TemplarName(input)
  if cmd=='debug' then templar.debug=not templar.debug end
  if cmd=='test' then
    local n=TemplarNow()
    templar.sacred.active=true;templar.sacred.reason='explicit TEST'
    templar.shield.untilTime=n+6;templar.shield.observed=false
    templar.shield.nextAt=n+6
    templar.bright.untilTime=n+20;templar.bright.observed=false
    templar.brand.untilTime=n+3.1;templar.brand.observed=false
    templar.testUntil=n+6
    templar.at=n -- preserve test for one scan step; never claim real proc
    TemplarLog('TEST only: ~6 shield / +300, ~20 +600, ~3 +1400; no genuine effects')
    return
  end
  TemplarReadPlayerAuras(TemplarNow())
  TemplarLog(string.format('debug=%s, mastery Bastion=%s Devout=%s Bright=%s Brand=%s Steadfast=%s IlluminateII=%s',
    tostring(templar.debug),tostring(TemplarLearned(TEM_BASTION)),
    tostring(TemplarLearned(TEM_DEVOUT)),tostring(TemplarLearned(TEM_BRIGHT)),
    tostring(TemplarLearned(TEM_JUDGMENT)),tostring(TemplarLearned(TEM_STEADFAST)),
    tostring(TemplarIlluminate2())))
  TemplarLog(string.format('ground=%s (%s), block=%s, still=%s, shield=%.1f, bright=%.1f, brand=%.1f',
    tostring(templar.sacred.active),tostring(templar.sacred.reason),
    tostring(TemplarBlocking()),tostring(TemplarStill()),
    math.max(0,templar.shield.untilTime-TemplarNow()),
    math.max(0,templar.bright.untilTime-TemplarNow()),
    math.max(0,templar.brand.untilTime-TemplarNow())))
  TemplarLog(string.format('recent cast=%s dawn=%s effect=%s %s burning=%s healing ticks=%d ult+2=%d shield breaks+10=%d',
    tostring(templar.lastCastId),tostring(templar.lastDawnId),
    tostring(templar.lastEffectId),tostring(templar.lastEffectName),
    tostring(templar.lastDamageId),templar.bastion.healCount,
    templar.bastion.ultCount,templar.shield.breakCount))
end
function RamaladniMastery.InitTemplar()
  if templar.initialized then return end
  templar.initialized=true
  SLASH_COMMANDS['/rmtemplar']=TemplarDebug
  SLASH_COMMANDS['/rmtemp']=TemplarDebug
  if GetUnitPower and POWERTYPE_ULTIMATE then
    templar.lastUlt=GetUnitPower('player',POWERTYPE_ULTIMATE)
  end
  EVENT_MANAGER:RegisterForEvent('RamaladniTemplarCast',EVENT_ACTION_SLOT_ABILITY_USED,TemplarCast)
  EVENT_MANAGER:RegisterForEvent('RamaladniTemplarEffect',EVENT_EFFECT_CHANGED,TemplarEffect)
  if REGISTER_FILTER_UNIT_TAG then
    -- TemplarEffect already ignores every unitTag except 'player'.
    EVENT_MANAGER:AddFilterForEvent('RamaladniTemplarEffect',EVENT_EFFECT_CHANGED,
      REGISTER_FILTER_UNIT_TAG,'player')
  end
  if EVENT_POWER_UPDATE and POWERTYPE_ULTIMATE then
    EVENT_MANAGER:RegisterForEvent('RamaladniTemplarUlt',EVENT_POWER_UPDATE,TemplarUltimate)
    if REGISTER_FILTER_UNIT_TAG and REGISTER_FILTER_POWER_TYPE then
      EVENT_MANAGER:AddFilterForEvent('RamaladniTemplarUlt',EVENT_POWER_UPDATE,
        REGISTER_FILTER_UNIT_TAG,'player',REGISTER_FILTER_POWER_TYPE,POWERTYPE_ULTIMATE)
    end
  end
  if EVENT_COMBAT_EVENT then
    EVENT_MANAGER:RegisterForEvent('RamaladniTemplarCombat',EVENT_COMBAT_EVENT,TemplarCombat)
    if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
      EVENT_MANAGER:AddFilterForEvent('RamaladniTemplarCombat',EVENT_COMBAT_EVENT,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
    end
  end
end
function RamaladniMastery.TemplarDisplay(key,state,now)
  local owned=TemplarLearned(key)
  state.cooldownUntil=0
  state.timerEstimated=false
  state.untilTime=0;state.activeFlag=false
  if not (templar.testUntil and templar.testUntil>now) then
    TemplarReadPlayerAuras(now)
  end
  -- Manual rendering test does not pretend the skills are purchased or the
  -- corresponding combat conditions exist. It expires automatically.
  if templar.testUntil and templar.testUntil>now then
    if key==TEM_BASTION then state.activeFlag=true;return true,'+2144' end
    if key==TEM_DEVOUT then
      state.activeFlag=true;state.untilTime=templar.shield.untilTime
      state.timerEstimated=true;return true,'+300'
    end
    if key==TEM_BRIGHT then
      state.activeFlag=true;state.untilTime=templar.bright.untilTime
      state.timerEstimated=true;return true,'+600'
    end
    if key==TEM_JUDGMENT then
      state.activeFlag=true;state.untilTime=templar.brand.untilTime
      state.timerEstimated=true;return true,'+1400'
    end
    if key==TEM_STEADFAST then state.activeFlag=true;return true,'БЛОК' end
  end
  if owned==false then return true,nil end
  local s=templar.sacred
  if key==TEM_BASTION then
    if owned==true and s.active then
      state.activeFlag=true
      return true,TemplarHealthFull() and TemplarInCombat() and '+2U' or '+2144'
    end
    return true,nil
  elseif key==TEM_DEVOUT then
    local p=templar.shield
    if owned==true and p.untilTime>now then
      state.activeFlag=true;state.untilTime=p.untilTime
      state.timerEstimated=not p.observed
      return true,'+300'
    end
    return true,nil
  elseif key==TEM_BRIGHT then
    local p=templar.bright
    if owned==true and p.untilTime>now and
        (p.observed or TemplarIlluminate2()==true) then
      state.activeFlag=true;state.untilTime=p.untilTime
      state.timerEstimated=not p.observed
      return true,'+600'
    end
    return true,nil
  elseif key==TEM_JUDGMENT then
    local p=templar.brand
    if owned==true and p.untilTime>now then
      state.activeFlag=true;state.untilTime=p.untilTime
      state.timerEstimated=not p.observed
      local player=DoesUnitExist and IsUnitPlayer and
        DoesUnitExist('reticleover') and IsUnitPlayer('reticleover')
      return true,player and '+700' or '+1400'
    end
    return true,nil
  elseif key==TEM_STEADFAST then
    if owned==true and TemplarBlocking() then
      state.activeFlag=true
      -- Do not claim +100% or +20% without resolving tooltip mismatch;
      -- the engine directly confirms blocking, and checks stationary.
      return true,TemplarStill() and 'БЛОК' or 'ЗЕМЛЯ'
    end
    return true,nil
  end
  return true,nil
end


RamaladniMastery.modules.Templar={Init=function() RamaladniMastery.InitTemplar() end, Display=function(key,state,now) return RamaladniMastery.TemplarDisplay(key,state,now) end}
