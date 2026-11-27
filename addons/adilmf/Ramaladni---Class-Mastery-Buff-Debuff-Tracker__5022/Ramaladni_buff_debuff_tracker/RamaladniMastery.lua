-- RamaladniMastery.lua v0.9.23 MODULAR TEST (shared core; extracted from v0.9.22)
-- Catalog from ESO Logs export and 2026 ESOHub class mastery pages.
-- Candidate effect IDs are NOT treated as proof that ESO emits them.
-- Runtime only displays values observed through ESO unit/effect API.
RamaladniMastery={byKey={},byClass={},classes={},all={},modules={}}
local M=RamaladniMastery
local GetDisplayName = GetDisplayName
local GetWorldName = GetWorldName
local HasMaxRankInAllClassSkillLines = HasMaxRankInAllClassSkillLines
local IsSkillAbilityPurchased = IsSkillAbilityPurchased
local SKILLS_DATA_MANAGER = SKILLS_DATA_MANAGER
local ZO_SavedVars = ZO_SavedVars
local d = d
local ipairs = ipairs
local math = math
local pairs = pairs
local select = select
local string = string
local tonumber = tonumber
local tostring = tostring
local type = type
local COMBAT_MECHANIC_FLAGS_ULTIMATE = COMBAT_MECHANIC_FLAGS_ULTIMATE
local EVENT_ACTION_SLOT_ABILITY_USED = EVENT_ACTION_SLOT_ABILITY_USED
local EVENT_MANAGER = EVENT_MANAGER
local EVENT_PLAYER_ACTIVATED = EVENT_PLAYER_ACTIVATED
local EVENT_POWER_UPDATE = EVENT_POWER_UPDATE
local EVENT_SKILL_POINTS_CHANGED = EVENT_SKILL_POINTS_CHANGED
local GetCurrentCharacterId = GetCurrentCharacterId
local GetFrameTimeSeconds = GetFrameTimeSeconds
local GetNumSkillAbilities = GetNumSkillAbilities
local GetNumSkillLines = GetNumSkillLines
local GetSkillAbilityId = GetSkillAbilityId
local GetSkillAbilityInfo = GetSkillAbilityInfo
local GetSlotAbilityCost = GetSlotAbilityCost
local GetSlotBoundId = GetSlotBoundId
local GetUnitClassId = GetUnitClassId
local GetUnitName = GetUnitName
local GetUnitPower = GetUnitPower
local REGISTER_FILTER_POWER_TYPE = REGISTER_FILTER_POWER_TYPE
local REGISTER_FILTER_UNIT_TAG = REGISTER_FILTER_UNIT_TAG
local SKILL_TYPE_CLASS = SKILL_TYPE_CLASS
local SLASH_COMMANDS = SLASH_COMMANDS
M.classes[#M.classes+1]={id="Dragonknight",name="Рыцарь-дракон / Dragonknight"}
M.byClass["Dragonknight"]={}
M.classes[#M.classes+1]={id="Nightblade",name="Клинок ночи / Nightblade"}
M.byClass["Nightblade"]={}
M.classes[#M.classes+1]={id="Sorcerer",name="Чародей / Sorcerer"}
M.byClass["Sorcerer"]={}
M.classes[#M.classes+1]={id="Templar",name="Храмовник / Templar"}
M.byClass["Templar"]={}
M.classes[#M.classes+1]={id="Warden",name="Хранитель / Warden"}
M.byClass["Warden"]={}
M.classes[#M.classes+1]={id="Necromancer",name="Некромант / Necromancer"}
M.byClass["Necromancer"]={}
M.classes[#M.classes+1]={id="Arcanist",name="Арканист / Arcanist"}
M.byClass["Arcanist"]={}
-- v0.9.2: Class Mastery runtime and per-character profile ownership.
-- This module owns character-specific settings and special passive mechanics.
-- The tracker module only supplies ESO event/time state to these hooks.
local function CopySaved(value)
  if type(value)~='table' then return value end
  local new={}
  for k,v in pairs(value) do
    if type(k)~='function' and type(v)~='function' then
      new[CopySaved(k)]=CopySaved(v)
    end
  end
  return new
end

-- Read the actual saved account before ZO_SavedVars creates defaults.
-- Opening the legacy account via NewAccountWide(nil namespace) can clear
-- nested world namespaces when the parent has no version.
local function GetRawAccount()
  local root=RamaladniTrackerSaved
  if type(root)~='table' then return nil end
  local profile=root.Default
  if type(profile)~='table' then return nil end
  local user=profile[GetDisplayName()]
  if type(user)~='table' then return nil end
  local account=user['$AccountWide']
  if type(account)=='table' then return account end
end
local function HasSavedSettings(account)
  return type(account)=='table' and
    (type(account.characterProfiles)=='table' or type(account.entries)=='table' or
     type(account.window)=='table' or type(account.learned)=='table' or
     account.nextId~=nil or account.legacyAssignedCharacter~=nil)
end
local function HasWorldSettings(account)
  return type(account)=='table' and
    (account.__ramaladniWorldInitialized==true or HasSavedSettings(account))
end

-- Keep the v1.0.1b world namespace layout. Import a legacy account only
-- when no world already owns settings; otherwise its origin is ambiguous.
-- Preserve the old data for backup/manual recovery, including empty lists.
function M.LoadWorldAccount(defaults)
  local world=GetWorldName()
  local legacy=GetRawAccount()
  local import=legacy and legacy.version==1 and
    not legacy.__ramaladniLegacyMigrationWorld and HasSavedSettings(legacy)
  if import then
    for key,value in pairs(legacy) do
      if key==world then
        if HasWorldSettings(value) then import=false; break end
      elseif type(value)=='table' and
        (value.__ramaladniWorldInitialized==true or
         (value.version==1 and HasSavedSettings(value))) then
        import=false; break
      end
    end
  end
  local account=ZO_SavedVars:NewAccountWide('RamaladniTrackerSaved',1,world,defaults)
  if import then
    for _,field in ipairs({'characterProfiles','legacyAssignedCharacter',
                           'entries','nextId','window','learned'}) do
      local value=legacy[field]
      if value~=nil then account[field]=CopySaved(value) end
    end
    legacy.__ramaladniLegacyMigrationWorld=world
    account.__ramaladniMigratedFromLegacy=true
  end
  account.__ramaladniWorldInitialized=true
  return account
end

local lead
local InitLeadTracking
function M.SelectCharacterProfile(account,defaults)
  -- Defer event wiring until the player is in the world; profiles are loaded
  -- earlier. The tracker will create HUD widgets after player activation.
  if not lead.initRegistered then
    lead.initRegistered=true
    EVENT_MANAGER:RegisterForEvent('RamaladniMasteryDK_Ready',EVENT_PLAYER_ACTIVATED,function()
      EVENT_MANAGER:UnregisterForEvent('RamaladniMasteryDK_Ready',EVENT_PLAYER_ACTIVATED)
      InitLeadTracking()
    end)
  end
  if type(account)~='table' then return CopySaved(defaults) end
  local id=GetCurrentCharacterId()
  if not id or tostring(id)=='' or tostring(id)=='0' then
    -- Character ID is preferred: names can change; fallback only for old API.
    id=(GetUnitName('player')) or 'unknown-character'
  end
  local key=tostring(id)
  if type(account.characterProfiles)~='table' then account.characterProfiles={} end
  local profiles=account.characterProfiles
  local profile=profiles[key]
  if type(profile)~='table' then
    profile=CopySaved(defaults)
    if account.legacyAssignedCharacter==nil then
      -- Import the old account-wide configuration ONCE, to this character.
      -- Never share mutable tables with legacy data or any other character.
      for _,field in ipairs({'entries','nextId','window','learned'}) do
        if account[field]~=nil then profile[field]=CopySaved(account[field]) end
      end
      account.legacyAssignedCharacter=key
    end
    profiles[key]=profile
  end
  -- Restore missing fields without erasing a genuinely empty saved list.
  for field,value in pairs(defaults) do
    if profile[field]==nil then profile[field]=CopySaved(value) end
  end
  return profile
end

-- Runtime v0.9.5: A mastery aura may be the RESULT of many different
-- abilities/sets. Never start a class mastery timer from a generic buff.
-- Trigger-driven masteries instead depend on an owned class passive and
-- the game's corresponding ACTUAL triggering action/resource change.
local LEAD_FROM_FRONT='Dragonknight:Lead from the Front'
local BOOMING_VOICE='Dragonknight:Booming Voice'
local ABYSSAL_EMERGENCE='Arcanist:Abyssal Emergence'
local UNBOUND_POTENTIAL='Arcanist:Unbound Potential'
local ERUDITES_RIGOR="Arcanist:Erudite's Rigor"
local INK_SCRIBES_VERVE="Arcanist:Ink-Scribe's Verve"
local NOTHING_WASTED='Necromancer:Nothing Wasted'
local INEXORABLE_DESCENT='Dragonknight:Inexorable Descent'
local PASSIVE_TRIGGERED={
  [LEAD_FROM_FRONT]=true,
  [BOOMING_VOICE]=true,
  [ABYSSAL_EMERGENCE]=true,
  [UNBOUND_POTENTIAL]=true,
  [ERUDITES_RIGOR]=true,
  [INK_SCRIBES_VERVE]=true,
}
-- Other classes with a *different* prerequisite (e.g. Burning Light rank 2,
-- Illuminate rank 2, or a dedicated passive proc) continue to use only their
-- OWN ability-specific proc IDs. Do not use universal Major/Minor buff IDs.
local SKILL_CLASS_IDS={Dragonknight=1,Sorcerer=2,Nightblade=3,Warden=4,Necromancer=5,Templar=6,Arcanist=117}
lead={initialized=false,initRegistered=false,debug=false,lastPower=nil,
            lastPowerAt=0,recentDrop=nil,pending=nil,confirmed=nil,
            lastAbility=0,lastSlot=0,lastCost=0,lastSpent=0,
            stormRank2=nil,passiveOwned=nil,lastError=nil}
local function LeadNow() return GetFrameTimeSeconds() end
local function LeadPrint(message)
  d('|c6FD6FFRamaladni Mastery|r '..message)
end
local skillCache={}
-- The committed class-mastery selection is shared by HUD and class modules.
-- ESO's own skill line cache deliberately marks the player's mastery line
-- active even on a subclassed build; enforce the native UI eligibility rule.
local masterySelection
local currentModule
function M.RefreshActiveMasteries()
  local manager=SKILLS_DATA_MANAGER
  if not manager:IsDataReady() or manager:IsGatingEventUpdates() then return nil end
  local selected,unknown={},{}
  local count=manager:GetNumActiveClassSkillLines()
  if count==0 then return nil end -- skill data not populated yet
  if manager:GetNumPlayerClassActiveSkillLines()==count and HasMaxRankInAllClassSkillLines() then
    -- Match the purchased passive itself, never a generic proc or aura ID.
    local ids={}
    for _,meta in ipairs(M.all) do ids[meta.passiveId]=meta end
    for i=1,manager:GetNumActiveClassMasterySkillLines() do
      local line=manager:GetActiveClassMasterySkillLine(i)
      for _,skill in line:SkillIterator() do
        if skill:IsPassive() and IsSkillAbilityPurchased(skill:GetIndices()) then
          local meta
          for rank=1,skill:GetNumRanks() do
            local id=skill:GetRankData(rank):GetAbilityId()
            if ids[id] then meta=ids[id];break end
          end
          if meta and SKILL_CLASS_IDS[meta.class]==line:GetClassId() then
            selected[meta.key]=skill:GetCurrentRank()
          else
            unknown[#unknown+1]=skill:GetCurrentProgressionData():GetAbilityId()
          end
        end
      end
    end
  end
  masterySelection=selected
  return selected,unknown
end
local function SkillState(meta,force)
  if meta and masterySelection then
    local rank=masterySelection[meta.key]
    return rank~=nil,rank
  end
  if not meta then return false,nil end
  local now=LeadNow()
  local key=meta.key
  local cached=skillCache[key]
  if not force and cached and now-cached.time<3 then return cached.bought,cached.rank end
  local wanted=meta.passiveId
  local classId=GetUnitClassId('player')
  local expected=SKILL_CLASS_IDS[meta.class]
  if type(classId)=='number' and expected and classId~=expected then
    skillCache[key]={time=now,bought=false}
    return false,nil
  end
  for line=1,GetNumSkillLines(SKILL_TYPE_CLASS) do
    for i=1,GetNumSkillAbilities(SKILL_TYPE_CLASS,line) do
      if GetSkillAbilityId(SKILL_TYPE_CLASS,line,i,false)==wanted then
        local _,_,earnedRank,_,_,purchased,_,rank=GetSkillAbilityInfo(SKILL_TYPE_CLASS,line,i)
        local actualRank=tonumber(rank) or tonumber(earnedRank)
        local bought=purchased==true
        skillCache[key]={time=now,bought=bought,rank=actualRank}
        return bought,actualRank
      end
    end
  end
  -- Some game builds expose Class Mastery under a separate skillType.
  -- Unresolved ownership is UNKNOWN, not an implicit yes. Cache this
  -- negative lookup for the same 3s as successful lookups: otherwise a
  -- mastery icon can enumerate every class skill on every 200ms HUD tick.
  -- EVENT_SKILL_POINTS_CHANGED invalidates this cache immediately.
  skillCache[key]={time=now,bought=nil,rank=nil}
  return nil,nil
end
-- Small public wrapper used ONLY by the isolated Templar module.
function M.TemplarSkillState(key)
  return SkillState(M.byKey[key])
end
-- v0.9.16 NIGHTBLADE ONLY: Above and Beyond has NO timed proc.
local function CurrentUltimate()
  local value=GetUnitPower('player',COMBAT_MECHANIC_FLAGS_ULTIMATE)
  return type(value)=='number' and value or nil
end
local function ClearTriggerState()
  lead.confirmed=nil
  lead.pending=nil
end
local function ConfirmUltimate(pending,pre,after,now)
  if not pending or not pre or not after then return false end
  local spent=pre-after
  if spent<pending.minCost-1 or spent<=0 then return false end
  -- When the entire Ultimate pool was spent but tiny instant gains followed,
  -- count the full pre-cast bank; avoid the minimum ability-cost pitfall.
  if after<=10 then spent=pre end
  lead.confirmed={at=pending.at,spent=spent,abilityId=pending.abilityId,
                  slot=pending.slot,from=pending.from,bankBefore=pre,bankAfter=after,
                  lead=(pending.from=='storm' and pending.leadBought),
                  booming=(pending.from=='storm' and pending.boomBought),
                  abyssal=(pending.from=='arcanist' and pending.abyssalBought),
                  source='observed-power-spend'}
  lead.lastSpent=spent
  lead.lastCost=pending.minCost
  lead.lastAbility=pending.abilityId
  lead.lastSlot=pending.slot
  lead.pending=nil
  if lead.debug then
    LeadPrint(string.format('ULT SPENT pre=%.0f after=%.0f spent=%.0f cost=%.0f StormII=%s Lead=%s Booming=%s Abyssal=%s',
       pre,after,spent,pending.minCost,tostring(pending.storm2),
       tostring(pending.leadBought),tostring(pending.boomBought),tostring(pending.abyssalBought)))
  end
  return true
end
-- Only an actual action spending ULTIMATE is eligible. A normal spell such as
-- Быстрый клич can fire EVENT_ACTION_SLOT_ABILITY_USED, but NOT a decrease in
-- COMBAT_MECHANIC_FLAGS_ULTIMATE. The latter is mandatory to confirm the trigger.
local function OnUltimateUsed(_,slot)
  if type(slot)~='number' then return end
  local cost=tonumber(GetSlotAbilityCost(slot,COMBAT_MECHANIC_FLAGS_ULTIMATE)) or 0
  if cost<=0 then return end
  local dk=GetUnitClassId('player')==1
  local arc=GetUnitClassId('player')==117
  local storm2=dk and M.modules.Dragonknight.HasStormVoiceRank2(true) or false
  local leadBought=dk and storm2==true and SkillState(M.byKey[LEAD_FROM_FRONT],true)==true
  local boomBought=dk and storm2==true and SkillState(M.byKey[BOOMING_VOICE],true)==true
  local abilityId=GetSlotBoundId(slot) or 0
  local abyssBought=arc and M.modules.Arcanist.IsClassUltimate(abilityId) and
    SkillState(M.byKey[ABYSSAL_EMERGENCE],true)==true
  lead.passiveOwned=leadBought
  lead.stormRank2=storm2
  if not (leadBought or boomBought or abyssBought) then
    if lead.debug then LeadPrint('Cast rejected: Storm II='..tostring(storm2)..'; mastery not learned') end
    return
  end
  local now=LeadNow()
  local id=abilityId
  local current=CurrentUltimate()
  local pending={at=now,slot=slot,abilityId=id,minCost=cost,bankBefore=lead.lastPower,
    from=dk and 'storm' or 'arcanist',storm2=storm2,leadBought=leadBought,
    boomBought=boomBought,abyssalBought=abyssBought}
  local recent=lead.recentDrop
  if recent and now-recent.at<=0.35 and recent.pre>=cost and
      ConfirmUltimate(pending,recent.pre,recent.after,now) then return end
  local before=lead.lastPower
  if before and current and before>current and before>=cost and
      ConfirmUltimate(pending,before,current,now) then return end
  lead.pending=pending
  if lead.debug then LeadPrint(string.format('Ultimate candidate ID=%s cost=%s bank=%s; awaiting actual power spend',
       tostring(id),tostring(cost),tostring(current))) end
end
local function OnLeadPowerUpdate(_,unitTag,_,powerType,powerValue)
  if unitTag~='player' or powerType~=COMBAT_MECHANIC_FLAGS_ULTIMATE or
     type(powerValue)~='number' then return end
  local now=LeadNow()
  local prev=lead.lastPower
  lead.lastPower=powerValue
  lead.lastPowerAt=now
  if prev and powerValue<prev then
    lead.recentDrop={at=now,pre=prev,after=powerValue}
    if lead.pending and now-lead.pending.at<=1.5 then
      local p=lead.pending
      -- The cast-start snapshot may precede an intermediate power update.
      -- Prefer it to the last partial value when available.
      local initial=p.bankBefore or prev
      ConfirmUltimate(p,initial,powerValue,now)
    elseif lead.confirmed and now-lead.confirmed.at<=1.0 and
           lead.confirmed.bankBefore and powerValue<lead.confirmed.bankAfter then
      -- Some clients split the Ultimate deduction into more than one update.
      -- Continue counting the same spend, never start a second proc.
      local initial=lead.confirmed.bankBefore
      local spent=powerValue<=10 and initial or (initial-powerValue)
      if spent>lead.confirmed.spent then
        lead.confirmed.spent=spent
        lead.confirmed.bankAfter=powerValue
        lead.lastSpent=spent
      end
    end
  end
end
local function TriggerRemaining(key,now)
  local conf=lead.confirmed
  if not conf then return nil,nil end
  local activeStart,finish,amount
  if key==LEAD_FROM_FRONT and conf.lead then
    activeStart=conf.at;finish=activeStart+conf.spent/15;amount='10%'
  elseif key==BOOMING_VOICE and conf.booming then
    activeStart=conf.at+15;finish=activeStart+10
    amount='+'..tostring(math.floor(conf.spent*5+0.5))
  elseif key==ABYSSAL_EMERGENCE and conf.abyssal then
    activeStart=conf.at;finish=activeStart+15;amount='+666'
  else return nil,nil end
  if now>=finish then return nil,nil end
  if now<activeStart then return 0,activeStart-now end
  return finish,amount
end
local function LeadDebugCommand(input)
  local command=(input or ''):lower():match('^%s*(.-)%s*$')
  if command=='debug' then
    lead.debug=not lead.debug
    LeadPrint('debug '..(lead.debug and 'ON' or 'OFF'))
    return
  end
  local now=LeadNow()
  local leadBought=SkillState(M.byKey[LEAD_FROM_FRONT],true)
  local boomBought=SkillState(M.byKey[BOOMING_VOICE],true)
  local storm2=M.modules.Dragonknight.HasStormVoiceRank2(true)
  local c=lead.confirmed
  LeadPrint(string.format('Storm Voice II=%s Lead=%s Booming=%s bank=%s pending=%s',
    tostring(storm2),tostring(leadBought),tostring(boomBought),tostring(lead.lastPower),
    lead.pending and tostring(lead.pending.abilityId) or 'none'))
  LeadPrint(string.format('Confirmed=%s spent=%s lastCost=%s LeadRemain=%.1fs source=%s',
    c and tostring(c.abilityId) or 'none',tostring(lead.lastSpent),tostring(lead.lastCost),
    math.max(0,(TriggerRemaining(LEAD_FROM_FRONT,now) or now)-now),
    c and c.source or 'none'))
end
local function InvalidateSkillCache()
  skillCache={}
  lead.stormCheck=nil
  if M.modules.Arcanist and M.modules.Arcanist.Invalidate then
    M.modules.Arcanist.Invalidate()
  end
end

-- Names encode event and filter values. A retained name keeps the existing
-- callback; each reconciliation only adds/removes the difference.
function M.NewEventSet()
  local active={}
  return function(build)
    local wanted={}
    local ok=true
    local function Add(name,event,handler,...)
      wanted[name]=true
      if active[name] then return end
      if not EVENT_MANAGER:RegisterForEvent(name,event,handler) then
        ok=false; d('Ramaladni: event registration failed: '..name); return
      end
      if select('#',...)>0 and not EVENT_MANAGER:AddFilterForEvent(name,event,...) then
        EVENT_MANAGER:UnregisterForEvent(name,event)
        ok=false; d('Ramaladni: event filter failed: '..name); return
      end
      active[name]=event
    end
    build(Add)
    for name,event in pairs(active) do
      if not wanted[name] then
        EVENT_MANAGER:UnregisterForEvent(name,event)
        active[name]=nil
      end
    end
    return ok
  end
end

-- Common shared state/functions are initialized before class modules load.
local function HideState(state)
  state.untilTime=0
  state.activeFlag=false
  state.timerEstimated=false
  state.stacks=0
end
M.shared={SkillState=SkillState,LeadNow=LeadNow,HideState=HideState,
                          LeadPrint=LeadPrint,lead=lead}
-- Compatible public API used by the main HUD, unchanged function signatures.
function M.IsLandslideLearned()
  return SkillState(M.byKey['Dragonknight:Inexorable Descent'],true)
end
function M.UpdateWidgetExtras(entry,widget,now)
  if not widget or not widget.win then return end
  local key=entry and entry.kind=='mastery' and entry.masteryKey
  if widget.nbShareGroup then widget.nbShareGroup:SetHidden(key~='Nightblade:Share the Spoils') end
  if type(key)=='string' and key:sub(1,11)=='Nightblade:' then
    local mod=M.modules.Nightblade
    if mod and mod.UpdateWidgetExtras then return mod.UpdateWidgetExtras(entry,widget,now) end
  end
  if key=='Sorcerer:Sphere of Influence' then
    local mod=M.modules.Sorcerer
    if mod and mod.UpdateWidgetExtras then return mod.UpdateWidgetExtras(entry,widget,now) end
  end
  if widget.sphereShieldLabel then widget.sphereShieldLabel:SetHidden(true) end
  if widget.sphereSmallFont then
    widget.amount:SetFont('$(BOLD_FONT)|19|soft-shadow-thick')
    widget.sphereSmallFont=false
  end
end

local syncLeadEvents=M.NewEventSet()
local leadSelection={}
local function SyncLeadEvents(selected)
  local wanted=selected[LEAD_FROM_FRONT] or selected[BOOMING_VOICE] or selected[ABYSSAL_EMERGENCE]
  local previous=leadSelection[LEAD_FROM_FRONT] or leadSelection[BOOMING_VOICE] or leadSelection[ABYSSAL_EMERGENCE]
  if wanted and not previous then
    lead.lastPower=CurrentUltimate()
    lead.recentDrop=nil
  end
  -- Never carry a removed mastery into a later activation. Retained
  -- masteries keep their own confirmed timer and correlation state.
  for key,flag in pairs({[LEAD_FROM_FRONT]='lead',[BOOMING_VOICE]='booming',[ABYSSAL_EMERGENCE]='abyssal'}) do
    if not selected[key] then
      if lead.confirmed then lead.confirmed[flag]=false end
      if lead.pending then
        local pendingFlag=flag=='lead' and 'leadBought' or (flag=='booming' and 'boomBought' or 'abyssalBought')
        lead.pending[pendingFlag]=false
      end
    end
  end
  if not wanted then ClearTriggerState();lead.recentDrop=nil end
  syncLeadEvents(function(Add)
    if wanted then
      Add('RamaladniMastery_Ability',EVENT_ACTION_SLOT_ABILITY_USED,OnUltimateUsed)
      Add('RamaladniMastery_UltPower',EVENT_POWER_UPDATE,OnLeadPowerUpdate,
        REGISTER_FILTER_UNIT_TAG,'player',REGISTER_FILTER_POWER_TYPE,COMBAT_MECHANIC_FLAGS_ULTIMATE)
    end
  end)
  leadSelection=selected
end
function M.SyncActiveEvents()
  if not lead.initialized or not masterySelection then return end
  SyncLeadEvents(masterySelection)
  if currentModule and currentModule.SyncEvents then currentModule.SyncEvents(masterySelection) end
end
InitLeadTracking=function()
  if lead.initialized then return end
  lead.initialized=true
  EVENT_MANAGER:RegisterForEvent('RamaladniMastery_SkillChanges',EVENT_SKILL_POINTS_CHANGED,InvalidateSkillCache)
  SLASH_COMMANDS['/rmlead']=LeadDebugCommand
  local classId=GetUnitClassId('player')
  local current=nil
  for class,id in pairs(SKILL_CLASS_IDS) do if id==classId then current=class end end
  currentModule=current and M.modules[current]
  if currentModule and currentModule.Init then currentModule.Init() end
  M.SyncActiveEvents()
end

function M.OnObservedEffect(entry,meta,state,change,start,finish,stacks,source,actualId,now)
  if not meta then return end
  -- No mastery can be activated by a buff if it is *known* not to be learned.
  -- Unknown ownership is handled conservatively by DisplayAmount.
  local bought=SkillState(meta)
  if bought==false then HideState(state);return end
  if meta.key=='Nightblade:Nocturnal Inspiration' or meta.key=='Nightblade:An Eye for Exploitation' or meta.key=='Nightblade:Share the Spoils' then
    -- Independent NB runtime validates the actual source. Do not activate
    -- from generic effect events here.
    HideState(state)
    return
  end
  if meta.class=='Templar' then
    -- All Templar states are set by the class-specific runtime. Do not
    -- let generic candidate IDs start unrelated timers.
    return
  end
  if meta.class=='Sorcerer' then
    -- Sorcerer event tracking is isolated in SorcAura/SorcAbilityCast.
    -- The generic HUD must never activate it from a lookalike group buff.
    HideState(state)
    return
  end
  if meta.key=='Dragonknight:Inexorable Descent' then
    local mod=M.modules.Dragonknight
    if mod and mod.OnObservedEffect then
      return mod.OnObservedEffect(entry,meta,state,change,start,finish,stacks,source,actualId,now)
    end
    return
  end
  if meta.key==ERUDITES_RIGOR then
    -- Only the armor+incoming-damage trigger may start the timer; do not allow
    -- the tracker to mistake 263413/263414/263415 for another caster's buff.
    return
  end
  if meta.key==UNBOUND_POTENTIAL then
    -- Unbound Potential has no independent aura. Crux changes exclusively
    -- control its window, so never overwrite it with passive / generic buffs.
    return
  end
  if PASSIVE_TRIGGERED[meta.key] then
    -- Ignore ordinary group Major Berserk/Protection and even same-named
    -- proc effects; actual action + Ultimate spending owns these timelines.
    HideState(state)
    return
  end
  -- The skill ID is the passive description, not evidence of an active aura.
  -- Likewise a NAME-only match can come from another source or a generic
  -- Major/Minor effect; demand an EXACT own-proc candidate ID.
  if actualId==meta.passiveId then HideState(state);return end
  local ownProc=false
  for _,candidate in ipairs(meta.candidateIDs or {}) do
    if actualId==candidate then ownProc=true;break end
  end
  if not ownProc then HideState(state);return end
  local mod=M.modules.Necromancer
  if meta.key=='Necromancer:Nothing Wasted' and mod and mod.OnObservedEffect then
    return mod.OnObservedEffect(entry,meta,state,change,start,finish,stacks,source,actualId,now)
  end
end
-- Future class-specific calculations can be added HERE, without modifying
-- the main tracker again. Returning true means this module handled the value.
function M.DisplayAmount(entry,state,now)
  if not entry then return false,nil end
  local key=entry.masteryKey
  local meta=M.byKey[key]
  if not meta then return false,nil end
  local module=M.modules[meta.class]
  if module and module.Display then
    local handled,amount=module.Display(key,state,now)
    if handled then return true,amount end
  end
  if PASSIVE_TRIGGERED[key] then
    local untilTime,amount=TriggerRemaining(key,now)
    if untilTime and untilTime>now then
      state.untilTime=untilTime
      state.activeFlag=true
      state.timerEstimated=true
      return true,amount
    end
    HideState(state)
    if untilTime==0 then
      -- Booming Voice has a 15-second *delay* prior to its 10-second buff.
      -- Display that waiting phase as a cooldown, not as an active buff.
      local _,wait=TriggerRemaining(key,now)
      state.cooldownUntil=now+wait
    else
      state.cooldownUntil=0
    end
    return true,nil
  end
  -- Common safety gate for every other class mastery in the catalog.
  -- If the passive is not learned, an identically named effect from another
  -- ability/set must never light its mastery indicator.
  local bought=SkillState(meta)
  if bought==false then HideState(state);return true,nil end
  if bought==nil then
    -- Some ESO builds do not expose Class Mastery as SKILL_TYPE_CLASS.
    -- An exact, ability-specific proc is usable, but never invent a timer.
    return false,nil
  end
  return false,nil
end
