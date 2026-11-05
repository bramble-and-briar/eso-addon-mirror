-- Ramaladni Tracker v0.9.23 — Dragonknight isolated runtime.
-- Mechanics copied from the v0.9.22 reference; other classes are not modified.
local M=RamaladniMastery
local shared=M.shared
local SkillState,LeadNow,HideState=shared.SkillState,shared.LeadNow,shared.HideState
local lead=shared.lead
local runtime={}
M.modules["Dragonknight"]=runtime
do
local e={key="Dragonknight:Inexorable Descent",class="Dragonknight",en="Inexorable Descent",title="Неумолимый спуск / Inexorable Descent",passiveId=238232,candidateIDs={263198,259228,259241,259684,44987,44988,29465,29466,29467},model="stacks_percent",value=1,cap=12,target=false,kind="stacks+percent",mechanic="+1% potency of damage, healing and damage shields for each observed Landslide stack, max 12",durationRule="No separate mastery timer; follows Landslide stacks, not an unrelated buff duration"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Dragonknight:Booming Voice",class="Dragonknight",en="Booming Voice",title="Громовой голос / Booming Voice",passiveId=240268,candidateIDs={263200,270020},model="observed_stacks",value=0,cap=0,target=false,kind="delayed_timer+numeric",mechanic="+5 Health/Magicka/Stamina Recovery per Ultimate spent",durationRule="15 sec delay followed by 10 sec bonus"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Dragonknight:Wildfire Embers",class="Dragonknight",en="Wildfire Embers",title="Дикие угли / Wildfire Embers",passiveId=259224,candidateIDs={263208,263309},model="stacks_percent",value=25,cap=12,target=true,kind="target_stacks+timer",mechanic="Up to 12 stacks, each further stack increases this effect's damage 25%",durationRule="12 sec DoT; read actual expiration per enemy"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Dragonknight:Resolute Defense",class="Dragonknight",en="Resolute Defense",title="Непоколебимая оборона / Resolute Defense",passiveId=263220,candidateIDs={263230,263231,263232,263233,263234},model="stacks_percent",value=6,cap=5,target=false,kind="conditional_stacks+percent",mechanic="6% extra block effectiveness per second bracing, up to 5 stacks (+30%)",durationRule="Only while bracing; no generic duration"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end
do
local e={key="Dragonknight:Lead from the Front",class="Dragonknight",en="Lead from the Front",title="Веди с фронта / Lead from the Front",passiveId=263247,candidateIDs={263248,263250,263306,263307,263308},model="timed_percent",value=10,cap=0,target=false,kind="group_timer+fixed_percent",mechanic="Major Berserk +10% damage and Major Protection -10% damage taken",durationRule="1 sec per 15 Ultimate spent; read target's actual effect endTime"}
RamaladniMastery.byKey[e.key]=e
RamaladniMastery.all[#RamaladniMastery.all+1]=e
RamaladniMastery.byClass[e.class][#RamaladniMastery.byClass[e.class]+1]=e
end

local INEXORABLE_DESCENT="Dragonknight:Inexorable Descent"
local LEAD_FROM_FRONT="Dragonknight:Lead from the Front"
local BOOMING_VOICE="Dragonknight:Booming Voice"
-- IDs from the user's ESO Logs ability catalog. Some may be internal,
-- so accept only an observed player aura with positive stackCount.
-- Passive tooltip IDs 29463, 44984, and mastery 238232 are NOT aura IDs.
local LANDSLIDE_AURA_IDS={
  [263198]=true,[259228]=true,[259241]=true,[259684]=true,
  [44987]=true,[44988]=true,[29465]=true,[29466]=true,[29467]=true,
}
local landslide={stacks=nil,abilityId=nil,source=nil,updatedAt=0,
                 scanAt=-1,debug=false,scanCount=0}
local function LandslideName(name)
  if type(name)~='string' or name=='' then return false end
  if name=='Landslide' or name=='Оползень' then return true end
  if not GetAbilityName then return false end
  for _,id in ipairs({29463,44984}) do
    local localized=GetAbilityName(id)
    if type(localized)=='string' and localized~='' and localized==name then
      return true
    end
  end
  return false
end
local function SetLandslide(stacks,abilityId,source,now)
  local n=tonumber(stacks)
  if n==nil then return end
  landslide.stacks=math.max(0,math.min(12,math.floor(n)))
  landslide.abilityId=abilityId
  landslide.source=source
  landslide.updatedAt=now
end
local function ScanLandslide(now)
  -- Reuse the already running 200 ms UI tick; cap additional player scans.
  if now-landslide.scanAt<0.65 then return end
  landslide.scanAt=now
  if not (GetNumBuffs and GetUnitBuffInfo) then return end
  local count=GetNumBuffs('player') or 0
  landslide.scanCount=count
  local matchId,matchStacks,matchName
  for i=1,count do
    local name,_,_,_,stacks,_,_,_,_,_,abilityId=GetUnitBuffInfo('player',i)
    if LANDSLIDE_AURA_IDS[abilityId] or LandslideName(name) then
      if type(stacks)=='number' and stacks>0 then
        if not matchStacks or stacks>matchStacks then
          matchId,matchStacks,matchName=abilityId,stacks,name
        end
      end
    end
  end
  if matchStacks then
    SetLandslide(matchStacks,matchId,'buff-scan',now)
  else
    -- A player aura scan can't certify the state of an invisible effect.
    -- Discard stale event-only data instead of inventing missing stacks.
    if landslide.source=='buff-scan' or now-landslide.updatedAt>1.0 then
      landslide.stacks=nil
      landslide.abilityId=nil
      landslide.source=nil
    end
  end
end
local LandslideDebug
local function BuildLandslideDebug(input)
  local cmd=(input or ''):lower():match('^%s*(.-)%s*$')
  if cmd=='debug' then
    landslide.debug=not landslide.debug
    if d then d('Ramaladni Landslide debug '..(landslide.debug and 'ON' or 'OFF')) end
  end
  ScanLandslide(GetFrameTimeSeconds())
  local learned=RamaladniMastery.IsLandslideLearned and RamaladniMastery.IsLandslideLearned()
  if d then d(string.format('Ramaladni Landslide: mastery=%s, stacks=%s, observedID=%s, source=%s, playerAuras=%d',
        tostring(learned),tostring(landslide.stacks),tostring(landslide.abilityId),
        tostring(landslide.source),landslide.scanCount)) end
  if d and GetNumBuffs and GetUnitBuffInfo then
    local count=GetNumBuffs('player') or 0
    for i=1,count do
      local name,_,_,_,stacks,_,_,_,_,_,id=GetUnitBuffInfo('player',i)
      if LANDSLIDE_AURA_IDS[id] or LandslideName(name) then
        d(string.format('Landslide aura: id=%s name=%s stacks=%s',tostring(id),tostring(name),tostring(stacks)))
      end
    end
  end
end
LandslideDebug=BuildLandslideDebug
local STORM_VOICE_IDS={ [29462]=1, [44953]=2 }
local function HasStormVoiceRank2(force)
  if GetUnitClassId and GetUnitClassId('player')~=1 then return false end
  local now=LeadNow()
  if lead.stormCheck and not force and now-lead.stormCheck.time<3 then
    return lead.stormCheck.rank2
  end
  if not (SKILL_TYPE_CLASS and GetNumSkillLines and GetNumSkillAbilities and
          GetSkillAbilityId and GetSkillAbilityInfo) then return nil end
  for line=1,GetNumSkillLines(SKILL_TYPE_CLASS) do
    for i=1,GetNumSkillAbilities(SKILL_TYPE_CLASS,line) do
      local id=GetSkillAbilityId(SKILL_TYPE_CLASS,line,i,false)
      if STORM_VOICE_IDS[id] then
        local _,_,earnedRank,_,_,purchased,_,rank=GetSkillAbilityInfo(SKILL_TYPE_CLASS,line,i)
        local actualRank=tonumber(rank) or tonumber(earnedRank)
        local yes=(purchased==true) and ((actualRank or STORM_VOICE_IDS[id])>=2)
        lead.stormCheck={time=now,rank2=yes}
        return yes
      end
    end
  end
  return nil
end
function RamaladniMastery.IsLandslideLearned()
  return SkillState(RamaladniMastery.byKey[INEXORABLE_DESCENT],true)
end

runtime.HasStormVoiceRank2=HasStormVoiceRank2
runtime.Init=function()
  SLASH_COMMANDS['/rmlandslide']=LandslideDebug
end
runtime.OnObservedEffect=function(entry,meta,state,change,start,finish,stacks,source,actualId,now)
  if not LANDSLIDE_AURA_IDS[actualId] then return end
  if change==EFFECT_RESULT_FADED then
    landslide.stacks=0
    landslide.abilityId=actualId
    landslide.source='effect-faded'
    landslide.updatedAt=now
  else
    SetLandslide(stacks,actualId,'effect-event',now)
  end
end
runtime.Display=function(key,state,now)
  if key~=INEXORABLE_DESCENT then return false,nil end
  local learned=SkillState(M.byKey[INEXORABLE_DESCENT])
  if learned==false then HideState(state); return true,nil end
  ScanLandslide(now)
  local stacks=landslide.stacks
  if stacks and stacks>0 and learned==true then
    state.stacks=stacks
    state.activeFlag=true
    state.untilTime=0
    state.timerEstimated=false
    state.cooldownUntil=0
    state.observedId=landslide.abilityId
    return true,tostring(stacks)..'%'
  end
  HideState(state)
  return true,nil
end


