-- Ramaladni Tracker v0.9.23 — Arcanist isolated runtime.
-- Mechanics copied from the v0.9.22 reference; other classes are not modified.
local M=RamaladniMastery
local shared=M.shared
local SkillState,LeadNow,HideState=shared.SkillState,shared.LeadNow,shared.HideState
local lead=shared.lead
local runtime={}
M.modules["Arcanist"]=runtime
do
local e={key="Arcanist:Abyssal Emergence",class="Arcanist",en="Abyssal Emergence",title="Восхождение из бездны / Abyssal Emergence",passiveId=263316,candidateIDs={263334,263369},model="timed_number",value=666,cap=0,target=false,kind="numeric+timer",mechanic="+666 Weapon/Spell Damage and maximum Crux from Ultimate",durationRule="15 sec"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Arcanist:Fate Realigned",class="Arcanist",en="Fate Realigned",title="Переписанная судьба / Fate Realigned",passiveId=263398,candidateIDs={263407,263409,268372},model="timed_number",value=300,cap=0,target=false,kind="numeric+timer+cooldown",mechanic="+300 Weapon/Spell Damage; maximum Crux proc",durationRule="25 sec buff; proc at most once per 15 sec"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Arcanist:Unbound Potential",class="Arcanist",en="Unbound Potential",title="Раскрепощённый потенциал / Unbound Potential",passiveId=263410,candidateIDs={263411},model="timed_percent",value=30,cap=0,target=false,kind="percent+conditional_timer",mechanic="Fated Fortune rank 2: on Crux gain or consume, 12% crit damage/healing plus Unbound +30% damage (15% PvP)",durationRule="7 sec; resets on actual Crux gain or spending, not Crux own 30 sec expiry"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Arcanist:Erudite's Rigor",class="Arcanist",en="Erudite's Rigor",title="Строгость эрудита / Erudite's Rigor",passiveId=263412,candidateIDs={263413,263414,263415},model="timed_percent",value=12,cap=0,target=false,kind="group_timer+target_debuff_timer",mechanic="On damage while Fatewoven Armor (or morph) is active: Minor Cowardice on attacker, Major Vitality +12% to group for 4 seconds, 1 Ultimate per Crux, max once per 2 seconds",durationRule="4 sec Major Vitality; internal proc cooldown 2 sec; no cast-only trigger"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Arcanist:Ink-Scribe's Verve",class="Arcanist",en="Ink-Scribe's Verve",title="Рвение чернильного писца / Ink-Scribe's Verve",passiveId=263416,candidateIDs={263418,263419,263420},model="healing_counter",value=100000,cap=0,target=false,kind="healing_counter+group_timer",mechanic="Progress 0..100000 healing/overhealing; generates Crux and Major Force +20% critical damage",durationRule="10 sec Major Force"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end

local ABYSSAL_EMERGENCE="Arcanist:Abyssal Emergence"
local UNBOUND_POTENTIAL="Arcanist:Unbound Potential"
local ERUDITES_RIGOR="Arcanist:Erudite's Rigor"
local INK_SCRIBES_VERVE="Arcanist:Ink-Scribe's Verve"
-- Fated Fortune rank 2 is a different learned passive from the Class Mastery.
-- ESO Logs ability catalog: rank variants 184844 and 184847. Neither is a
-- reliable seven-second aura ID; the observable source is Crux (184220).
local FATED_FORTUNE_IDS={ [184844]=1, [184847]=2 }
local fatedCache
local function HasFatedFortuneRank2(force)
  if GetUnitClassId and GetUnitClassId('player')~=117 then return false end
  local now=LeadNow()
  if not force and fatedCache and now-fatedCache.at<3 then return fatedCache.value end
  if not (SKILL_TYPE_CLASS and GetNumSkillLines and GetNumSkillAbilities and
          GetSkillAbilityId and GetSkillAbilityInfo) then return nil end
  for line=1,GetNumSkillLines(SKILL_TYPE_CLASS) do
    for idx=1,GetNumSkillAbilities(SKILL_TYPE_CLASS,line) do
      local id=GetSkillAbilityId(SKILL_TYPE_CLASS,line,idx,false)
      if FATED_FORTUNE_IDS[id] then
        local _,_,earnedRank,_,_,purchased,_,rank=GetSkillAbilityInfo(SKILL_TYPE_CLASS,line,idx)
        local r=tonumber(rank) or tonumber(earnedRank) or FATED_FORTUNE_IDS[id]
        local yes=(purchased==true and (id==184847 or r>=2))
        fatedCache={at=now,value=yes}
        return yes
      end
    end
  end
  -- Unresolved is not assumed active. /rmarc reports this case.
  return nil
end

-- The 30-second Crux buff is not a duration for the 7-second mastery.
-- ESO Logs confirms 184220 generates applybuff / applybuffstack / removebuff.
local CRUX_EFFECT_ID=184220
local ARC_DURATION=7
local arc={lastStacks=nil,buffEnd=nil,lastCruxAt=nil,untilTime=0,debug=false,
           lastTrigger=nil,lastChange=nil,ignored=nil}
local function ArcPrint(msg)
  if d then d('|c73D1FFRamaladni Arc|r '..tostring(msg)) end
end
local function SnapshotCrux()
  if not GetNumBuffs or not GetUnitBuffInfo then return end
  for i=1,(GetNumBuffs('player') or 0) do
    local _,_,finish,_,stacks,_,_,_,_,_,id=GetUnitBuffInfo('player',i)
    if id==CRUX_EFFECT_ID then
      arc.lastStacks=tonumber(stacks) or 1
      arc.buffEnd=tonumber(finish)
      arc.lastCruxAt=LeadNow()
      return
    end
  end
  arc.lastStacks=0
end
local function ArcTrigger(reason,now)
  local mastery=SkillState(RamaladniMastery.byKey[UNBOUND_POTENTIAL])
  local fated=HasFatedFortuneRank2()
  if mastery~=true or fated~=true then
    arc.ignored='Unbound='..tostring(mastery)..' FatedII='..tostring(fated)
    if arc.debug then ArcPrint('Proc ignored: '..arc.ignored) end
    return
  end
  arc.untilTime=now+ARC_DURATION
  arc.lastTrigger=reason
  if arc.debug then ArcPrint('PROC '..reason..' +30% / 7s') end
end
local function OnCruxEffect(_,change,_,effectName,unitTag,beginTime,endTime,stackCount,
                            _,_,_,_,_,_,_,abilityId)
  if unitTag~='player' or abilityId~=CRUX_EFFECT_ID then return end
  if GetUnitClassId and GetUnitClassId('player')~=117 then return end
  local now=LeadNow()
  local old=arc.lastStacks
  local oldEnd=arc.buffEnd
  local isFade=(change==EFFECT_RESULT_FADED)
  local stacks=isFade and 0 or (tonumber(stackCount) or old or 0)
  local reason=nil
  if isFade then
    -- Consuming all Crux causes FADED; natural 30s expiry also causes FADED.
    -- Use server-reported Crux expiry to avoid false seven-second procs.
    if old and old>0 and oldEnd and oldEnd>now+0.45 then
      reason='consumed '..old..'->0'
    elseif old and old>0 and not oldEnd and IsUnitInCombat and
           IsUnitInCombat('player') and arc.lastCruxAt and now-arc.lastCruxAt<25 then
      reason='probable consumption '..old..'->0'
    end
  elseif old~=nil and stacks~=old then
    reason='Crux '..old..'->'..stacks
  elseif old==nil and change==EFFECT_RESULT_GAINED and stacks>0 then
    reason='Crux gained '..stacks
  elseif old~=nil and stacks>0 and stacks==old and
         (change==EFFECT_RESULT_FULL_REFRESH or change==EFFECT_RESULT_UPDATED) and
         type(endTime)=='number' and oldEnd and endTime>oldEnd+0.75 then
    -- A fresh generation at maximum Crux can refresh the Crux effect while
    -- keeping stackCount=3. Ignore repeated notifications with unchanged end.
    reason='Crux refreshed at '..stacks
  end
  arc.lastStacks=stacks
  arc.lastChange=change
  arc.lastCruxAt=now
  if isFade then arc.buffEnd=nil
  elseif type(endTime)=='number' and endTime>now then arc.buffEnd=endTime end
  if reason then ArcTrigger(reason,now)
  elseif arc.debug then ArcPrint('No proc change='..tostring(change)..' '..tostring(old)..'->'..tostring(stacks)) end
end
local function ArcDebug(input)
  local cmd=(input or ''):lower():match('^%s*(.-)%s*$')
  if cmd=='debug' then arc.debug=not arc.debug; ArcPrint('debug '..(arc.debug and 'ON' or 'OFF')); return end
  local owned=SkillState(RamaladniMastery.byKey[UNBOUND_POTENTIAL],true)
  local fated=HasFatedFortuneRank2(true)
  local now=LeadNow()
  ArcPrint(string.format('Unbound=%s Fated Fortune II=%s Crux=%s active=%.1fs last=%s ignore=%s',
     tostring(owned),tostring(fated),tostring(arc.lastStacks),
     math.max(0,arc.untilTime-now),tostring(arc.lastTrigger),tostring(arc.ignored)))
end

-- Erudite's Rigor: the *cast* of Fatewoven Armor is not the proc.
-- Only incoming damage while OUR armor is active may trigger the upgrade.
-- We do not listen for generic Major Vitality: other players/sets can grant it.
-- A green 4s timer represents Major Vitality; the 2s internal cooldown is
-- maintained separately. Until an exact aura is confirmed, show an estimated
-- interval (the main 0.9.2+ UI prefixes estimated timers with '~').
local RIGOR_ARMOR_CASTS={
  [183648]=20, -- Fatewoven Armor
  [185908]=30, -- Cruxweaver Armor
  [186477]=20, [186480]=20, -- Unbreakable Fate, morph/variant
}
local RIGOR_ARMOR_EFFECTS={
  [183650]=20, -- Fatewoven Armor's own Major Resolve effect
  [185909]=30, -- Cruxweaver Armor's own Major Resolve effect
  [186478]=20, -- Unbreakable Fate's own Major Resolve effect
}
local RIGOR_PROC_EFFECTS={ [263413]=true, [263414]=true, [263415]=true }
local RIGOR_DURATION=4
local RIGOR_ICD=2
local rigor={armorUntil=0,untilTime=0,nextProcAt=0,lastHitAt=0,
             lastProcAt=0,source=nil,debug=false,lastReason=nil}
local function RigorPrint(message)
  if d then d('|c73D1FFRamaladni Rigor|r '..tostring(message)) end
end
local function IsRigorLearned()
  return GetUnitClassId and GetUnitClassId('player')==117 and
    SkillState(RamaladniMastery.byKey[ERUDITES_RIGOR])==true
end
local function RigorArmorCast(_,slot)
  if GetUnitClassId and GetUnitClassId('player')~=117 then return end
  if not GetSlotBoundId then return end
  local abilityId=GetSlotBoundId(slot)
  local duration=RIGOR_ARMOR_CASTS[abilityId]
  if not duration then return end
  -- Own action. Its Major Resolve buff may subsequently refine the expiry.
  local now=LeadNow()
  rigor.armorUntil=now+duration
  rigor.lastReason='Armor cast ID '..tostring(abilityId)
  if rigor.debug then RigorPrint(rigor.lastReason..' / '..duration..'s') end
end
local function RigorArmorEffect(_,change,_,_,unitTag,_,endTime,_,_,_,_,_,_,_,_,abilityId)
  if unitTag~='player' then return end
  local duration=RIGOR_ARMOR_EFFECTS[abilityId]
  if not duration then return end
  local now=LeadNow()
  if change==EFFECT_RESULT_FADED then
    -- A quick re-cast can cause a delayed FADED for the previous application;
    -- do not wipe an armor window refreshed very recently.
    if rigor.armorUntil<=now+0.35 then rigor.armorUntil=0 end
    return
  end
  if type(endTime)=='number' and endTime>now and endTime<=now+duration+2 then
    rigor.armorUntil=endTime
  elseif rigor.armorUntil<=now then
    rigor.armorUntil=now+duration
  end
end
local function RigorProcEffect(_,change,_,_,unitTag,_,endTime,_,_,_,_,_,_,_,_,abilityId)
  if unitTag~='player' or not RIGOR_PROC_EFFECTS[abilityId] then return end
  if change==EFFECT_RESULT_FADED then return end
  local now=LeadNow()
  -- Own, confirmed, *recently triggered* proc only. Never let an unrelated
  -- aura start this passive or extend the timer without our own damage event.
  if rigor.lastHitAt<=0 or now-rigor.lastHitAt>0.60 or
     rigor.armorUntil<=now or not IsRigorLearned() then return end
  if type(endTime)=='number' and endTime>now and endTime<=now+5 then
    rigor.untilTime=endTime
    rigor.source='client-effect'
    if rigor.debug then RigorPrint('ESO proc ID '..abilityId..' end='..endTime) end
  end
end
local RIGOR_DAMAGE_RESULTS={}
for _,result in ipairs({ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE,
                        ACTION_RESULT_DOT_TICK, ACTION_RESULT_DOT_TICK_CRITICAL,
                        ACTION_RESULT_BLOCKED_DAMAGE}) do
  if result~=nil then RIGOR_DAMAGE_RESULTS[result]=true end
end
local function RigorOnIncomingDamage(_,result,isError,_,_,_,_,_,_,targetType,
                                     hitValue,_,_,_,_,_,_,abilityId)
  if isError or not RIGOR_DAMAGE_RESULTS[result] then return end
  if COMBAT_UNIT_TYPE_PLAYER and targetType~=COMBAT_UNIT_TYPE_PLAYER then return end
  if type(hitValue)~='number' or hitValue<=0 then return end
  local now=LeadNow()
  if rigor.armorUntil<=now or now<rigor.nextProcAt then return end
  if not IsRigorLearned() then return end
  -- A proc cannot happen faster than every 2s; the 4s buff can refresh.
  rigor.lastHitAt=now
  rigor.lastProcAt=now
  rigor.untilTime=now+RIGOR_DURATION
  rigor.nextProcAt=now+RIGOR_ICD
  rigor.source='estimated-incoming-damage'
  rigor.lastReason='incoming damage ID '..tostring(abilityId)
  if rigor.debug then
    RigorPrint('PROC '..rigor.lastReason..' / Major Vitality ~4s, ICD 2s')
  end
end
local function RigorDebug(input)
  local command=(input or ''):lower():match('^%s*(.-)%s*$')
  if command=='debug' then
    rigor.debug=not rigor.debug
    RigorPrint('debug '..(rigor.debug and 'ON' or 'OFF'))
    return
  end
  local now=LeadNow()
  RigorPrint(string.format('learned=%s armor=%.1fs vitality=%.1fs ICD=%.1fs source=%s last=%s',
    tostring(IsRigorLearned()),math.max(0,rigor.armorUntil-now),
    math.max(0,rigor.untilTime-now),math.max(0,rigor.nextProcAt-now),
    tostring(rigor.source),tostring(rigor.lastReason)))
end

-- Ink-Scribe's Verve: unlike a normal Major Force aura, this mastery has its
-- own prerequisite: 100k of OUR healing + overhealing while in combat.
-- The game's EVENT_COMBAT_EVENT overflow parameter is overhealing, not an
-- additional independent heal event. Count each source heal only once.
-- IMPORTANT: Do not launch mastery tracking from the generic Major Force buff:
-- War Horn and other allies can grant the same effect without this passive.
local INK_THRESHOLD=100000
local INK_FORCE_DURATION=10
local INK_PROC_IDS={[263418]=true,[263419]=true,[263420]=true}
local INK_HEAL_RESULTS={}
for _,result in ipairs({ACTION_RESULT_HEAL, ACTION_RESULT_CRITICAL_HEAL,
                        ACTION_RESULT_HOT_TICK, ACTION_RESULT_HOT_TICK_CRITICAL}) do
  if result~=nil then INK_HEAL_RESULTS[result]=true end
end
local ink={progress=0,untilTime=0,lastProcAt=0,source=nil,debug=false,
           lastHeal=0,lastOverflow=0,procCount=0,lastIgnored=nil}
local function InkPrint(msg)
  if d then d('|c73D1FFRamaladni Ink|r '..tostring(msg)) end
end
local function IsInkLearned(force)
  return GetUnitClassId and GetUnitClassId('player')==117 and
    SkillState(RamaladniMastery.byKey[INK_SCRIBES_VERVE],force)==true
end
local function InkOnCombatState(_,inCombat)
  if not inCombat then
    -- Accumulation is combat-only, but the already-earned Major Force can
    -- outlive combat. Leave ink.untilTime untouched until its real expiry.
    ink.progress=0
  end
end
local function InkOnHeal(_,result,isError,_,_,_,_,sourceType,_,_,hitValue,
                         _,_,_,_,_,_,_,overflow)
  if isError or not INK_HEAL_RESULTS[result] then return end
  if COMBAT_UNIT_TYPE_PLAYER and sourceType~=COMBAT_UNIT_TYPE_PLAYER then return end
  if IsUnitInCombat and not IsUnitInCombat('player') then return end
  if not IsInkLearned() then return end
  local effective=math.max(0,tonumber(hitValue) or 0)
  local overheal=math.max(0,tonumber(overflow) or 0)
  local heal=effective+overheal
  if heal<=0 then return end
  ink.lastHeal=effective
  ink.lastOverflow=overheal
  ink.progress=ink.progress+heal
  if ink.progress>=INK_THRESHOLD then
    ink.progress=ink.progress-INK_THRESHOLD
    -- A single very large heal can cross more than one threshold; the server
    -- ultimately determines exact proc multiplicity. Preserve the remainder.
    ink.progress=ink.progress%INK_THRESHOLD
    local now=LeadNow()
    ink.untilTime=now+INK_FORCE_DURATION
    ink.lastProcAt=now
    ink.source='estimated-own-healing'
    ink.procCount=ink.procCount+1
    if ink.debug then
      InkPrint(string.format('PROC healing=%d overheal=%d next=%d/100000 Major Force ~10s',
        effective,overheal,ink.progress))
    end
  elseif ink.debug then
    InkPrint(string.format('HEAL +%d (overheal %d) progress %d/100000',
      heal,overheal,ink.progress))
  end
end
local function InkProcEffect(_,change,_,_,unitTag,_,endTime,_,_,_,_,_,_,_,_,abilityId)
  if unitTag~='player' or not INK_PROC_IDS[abilityId] then return end
  if change==EFFECT_RESULT_FADED or not IsInkLearned() then return end
  local now=LeadNow()
  -- These are ID candidates from ESO Logs, NOT sufficient evidence on their
  -- own. Only refine a recently triggered OWN 100k-healing event.
  if ink.lastProcAt==0 or now-ink.lastProcAt>1.5 then return end
  if type(endTime)=='number' and endTime>now and
     endTime<=now+INK_FORCE_DURATION+1 then
    ink.untilTime=endTime
    ink.source='client-own-proc'
    if ink.debug then InkPrint('Refined with own proc ID '..abilityId..' endTime='..endTime) end
  end
end
local function InkDebug(input)
  local cmd=(input or ''):lower():match('^%s*(.-)%s*$')
  if cmd=='debug' then
    ink.debug=not ink.debug
    InkPrint('debug '..(ink.debug and 'ON' or 'OFF'))
    return
  end
  local now=LeadNow()
  InkPrint(string.format('learned=%s progress=%d/100000 (%.1f%%) force=%.1fs procs=%d source=%s lastHeal=%d overheal=%d',
    tostring(IsInkLearned(true)),ink.progress,ink.progress/1000,
    math.max(0,ink.untilTime-now),ink.procCount,tostring(ink.source),
    ink.lastHeal,ink.lastOverflow))
end

-- Abyssal Emergence activates on an ARCANIST Ultimate, not on a random
-- Fighters Guild / Alliance War Ultimate slotted by an Arcanist character.
-- ESO Logs ability IDs (exact cast skills; supplemental guard to skillbook).
local ARCANIST_ULTIMATE_IDS={
  [189791]=true,[189867]=true,[189837]=true, -- Unblinking/Languid/Tide King's Eye
  [178449]=true,[192372]=true,[192380]=true, -- Gibbering Shield morphs
  [178455]=true,[193794]=true,[193558]=true, -- Vitalizing Glyphic morphs
}
local function IsArcanistClassUltimate(abilityId)
  if ARCANIST_ULTIMATE_IDS[abilityId] then return true end
  if not (SKILL_TYPE_CLASS and GetNumSkillLines and GetNumSkillAbilities and
          GetSkillAbilityId and GetSkillAbilityInfo) then return false end
  -- Discover all current Arcanist class Ultimates by active skillbook.
  -- Morphs can use IDs different from their parent ability.
  local actualName=GetAbilityName and GetAbilityName(abilityId)
  for line=1,GetNumSkillLines(SKILL_TYPE_CLASS) do
    for i=1,GetNumSkillAbilities(SKILL_TYPE_CLASS,line) do
      local name,_,_,_,isUltimate,purchased=GetSkillAbilityInfo(SKILL_TYPE_CLASS,line,i)
      if isUltimate and purchased then
        local skillId=GetSkillAbilityId(SKILL_TYPE_CLASS,line,i,false)
        if skillId==abilityId or (actualName and actualName~='' and actualName==name) then
          return true
        end
      end
    end
  end
  return false
end

runtime.IsClassUltimate=IsArcanistClassUltimate
runtime.Invalidate=function() fatedCache=nil end
runtime.Init=function()
  SnapshotCrux()
  EVENT_MANAGER:RegisterForEvent('RamaladniMastery_Crux',EVENT_EFFECT_CHANGED,OnCruxEffect)
  EVENT_MANAGER:AddFilterForEvent('RamaladniMastery_Crux',EVENT_EFFECT_CHANGED,
      REGISTER_FILTER_UNIT_TAG,'player',REGISTER_FILTER_ABILITY_ID,CRUX_EFFECT_ID)
  SLASH_COMMANDS['/rmarc']=ArcDebug
  SLASH_COMMANDS['/rmrigor']=RigorDebug
  SLASH_COMMANDS['/rmink']=InkDebug
  if EVENT_PLAYER_COMBAT_STATE then
    EVENT_MANAGER:RegisterForEvent('RamaladniMastery_InkCombat',EVENT_PLAYER_COMBAT_STATE,InkOnCombatState)
  end
  for result in pairs(INK_HEAL_RESULTS) do
    local namespace='RamaladniMastery_InkHeal_'..tostring(result)
    EVENT_MANAGER:RegisterForEvent(namespace,EVENT_COMBAT_EVENT,InkOnHeal)
    if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
      EVENT_MANAGER:AddFilterForEvent(namespace,EVENT_COMBAT_EVENT,
          REGISTER_FILTER_COMBAT_RESULT,result,
          REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
    else
      EVENT_MANAGER:AddFilterForEvent(namespace,EVENT_COMBAT_EVENT,
          REGISTER_FILTER_COMBAT_RESULT,result)
    end
  end
  for abilityId in pairs(INK_PROC_IDS) do
    local namespace='RamaladniMastery_InkProc_'..tostring(abilityId)
    EVENT_MANAGER:RegisterForEvent(namespace,EVENT_EFFECT_CHANGED,InkProcEffect)
    EVENT_MANAGER:AddFilterForEvent(namespace,EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_UNIT_TAG,'player',REGISTER_FILTER_ABILITY_ID,abilityId)
  end
  EVENT_MANAGER:RegisterForEvent('RamaladniMastery_RigorArmorCast',EVENT_ACTION_SLOT_ABILITY_USED,RigorArmorCast)
  EVENT_MANAGER:RegisterForEvent('RamaladniMastery_RigorArmorBuff',EVENT_EFFECT_CHANGED,RigorArmorEffect)
  EVENT_MANAGER:RegisterForEvent('RamaladniMastery_RigorProcBuff',EVENT_EFFECT_CHANGED,RigorProcEffect)
  if REGISTER_FILTER_UNIT_TAG then
    -- Both handlers explicitly reject non-player unitTags already.
    EVENT_MANAGER:AddFilterForEvent('RamaladniMastery_RigorArmorBuff',EVENT_EFFECT_CHANGED,
      REGISTER_FILTER_UNIT_TAG,'player')
    EVENT_MANAGER:AddFilterForEvent('RamaladniMastery_RigorProcBuff',EVENT_EFFECT_CHANGED,
      REGISTER_FILTER_UNIT_TAG,'player')
  end
  EVENT_MANAGER:RegisterForEvent('RamaladniMastery_RigorDamage',EVENT_COMBAT_EVENT,RigorOnIncomingDamage)
  if REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
    EVENT_MANAGER:AddFilterForEvent('RamaladniMastery_RigorDamage',EVENT_COMBAT_EVENT,
      REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
  end
end
runtime.Display=function(key,state,now)
  if key==ERUDITES_RIGOR then
    if not IsRigorLearned() then HideState(state); state.cooldownUntil=0; return true,nil end
    if rigor.untilTime>now then
      state.untilTime=rigor.untilTime
      state.activeFlag=true
      state.timerEstimated=(rigor.source~='client-effect')
      state.cooldownUntil=rigor.nextProcAt>now and rigor.nextProcAt or 0
      return true,'12%'
    end
    HideState(state);state.cooldownUntil=0;return true,nil
  end
  if key==INK_SCRIBES_VERVE then
    if not IsInkLearned() then HideState(state);return true,nil end
    if ink.untilTime>now then
      state.untilTime=ink.untilTime
      state.activeFlag=true
      state.timerEstimated=(ink.source~='client-own-proc')
      return true,'20%'
    end
    state.untilTime=0
    state.activeFlag=true
    state.timerEstimated=false
    return true,tostring(math.min(100,math.floor(ink.progress/INK_THRESHOLD*100+0.5)))..'%'
  end
  if key==UNBOUND_POTENTIAL then
    local owned=SkillState(M.byKey[key])
    local fated=HasFatedFortuneRank2()
    if owned~=true or fated~=true then HideState(state);return true,nil end
    if arc.untilTime>now then
      state.untilTime=arc.untilTime
      state.activeFlag=true
      state.timerEstimated=true
      local pvpTarget=DoesUnitExist and IsUnitPlayer and DoesUnitExist('reticleover') and IsUnitPlayer('reticleover')
      return true,(pvpTarget and '15%' or '30%')
    end
    HideState(state);return true,nil
  end
  return false,nil
end


