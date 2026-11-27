-- Lightweight custom-effect tracker. Saved rules are independent of bar position.
-- All durations shown by the HUD use the frame clock (milliseconds).
ZeraUITracker = {}
local T = ZeraUITracker
T.__index = T
local BUILTIN=ZeraUISkillRules
local NW_ID,NW_DURATION=263461,12000
local OFF_BALANCE={[39077]=true,[62988]=true}
local NW_SIPHONS={[116445]=true,[118009]=true,[118764]=true,[115924]=true,[118008]=true,[118763]=true}
local NW_COMBAT,NW_EFFECT="ZeraUINothingWastedCombat","ZeraUINothingWastedEffect"
local POWER_LASH_COMBAT,POWER_LASH_ID="ZeraUIPowerLashCombat",34117
-- Landslide and its mastery upgrade use the same observed stack effect.
local LANDSLIDE=29465
local WHIPS={[23806]=true,[20816]=true,[20805]=true,[256798]=true,[20824]=true}
local FLAME_WHIPS={[20816]=true,[20824]=true}
-- Slot identities are separate from the confirmed self-buff identities.
-- Never start these passive timers simply because a related skill was cast.
local FRENZY_SLOTS={[132141]=true,[134160]=true,[135841]=true}
local FATECARVER_SLOTS={[185805]=true,[193331]=true,[183122]=true,[193397]=true,[186366]=true,[193398]=true,[238174]=true}
local DREAD_SLOTS={[185823]=true}
local PASSIVE_VAMPIRE={[135189]=true,[135190]=true}
local PASSIVE_ARCANIST={[263369]=true,[268372]=true}
local EXTERNAL_COUNTS={[61503]=61504,[61505]=61506,[61504]=61504,[61506]=61506,[40076]=40076,[40079]=40079}
local AMBIGUOUS_EXTERNAL={ [38254]=true,[52790]=true,[217353]=true,[217358]=true }
for _,entries in pairs(BUILTIN.shared) do for _,rule in ipairs(entries) do AMBIGUOUS_EXTERNAL[rule.effect]=true end end
for _,entries in pairs(BUILTIN.duration) do for _,rule in ipairs(entries) do if rule.shared then AMBIGUOUS_EXTERNAL[rule.effect]=true end end end

T.presets = {
    martial = { effect=217353, duration=5, mode="auto" },
    status = { effect=217358, duration=10, mode="auto" },
}
-- Independent script rules. Never infer a Knife effect from the slot timer:
-- the engine may report its Affix buff instead of the Signature debuff.
local KNIFE_RULES={martial={T.presets.martial},status={T.presets.status}}
local function normalizedName(name)
    return type(name)=="string" and name:lower():gsub("’","'") or ""
end
local function siphonSlot(id,index,category)
    if NW_SIPHONS[id] then return true end
    local name=normalizedName(GetSlotName and GetSlotName(index,category))
    if name=="" and GetAbilityName then name=normalizedName(GetAbilityName(id)) end
    if name=="detonating siphon" or name=="shocking siphon" or name=="mystic siphon" then return true end
    if GetAbilityName and name~="" then
        for _,known in ipairs({116445,118009,118764}) do if name==normalizedName(GetAbilityName(known)) then return true end end
    end
    return false
end
local function unitNameKey(name)
    return type(name)=="string" and name:gsub("%^.*$","") or ""
end
local function selfName(name)
    if not GetUnitName then return false end
    local clean=unitNameKey(name)
    return clean~="" and clean==unitNameKey(GetUnitName("player"))
end
local function unknownSource(source)
    return source==nil or source==0 or source==COMBAT_UNIT_TYPE_NONE
end
-- Traveling Knife grimoire and its signature scripts (IDs read in a live
-- client). Names are only a fallback: a translated client reports other names.
local KNIFE_GRIMOIRE=7
local KNIFE_SCRIPTS={[41]="martial",[29]="status"}
local function automaticRules(key,ability)
    if not key then return end
    local crafted,_,signature=key:match("^c:(%d+):(%d+):(%d+):%d+$")
    if crafted and tonumber(crafted)==KNIFE_GRIMOIRE then
        local kind=KNIFE_SCRIPTS[tonumber(signature)]
        if kind then return KNIFE_RULES[kind],key end
    end
    if not crafted or not GetCraftedAbilityScriptDisplayName then return end
    local grimoire=GetCraftedAbilityDisplayName and normalizedName(GetCraftedAbilityDisplayName(tonumber(crafted))) or ""
    if not grimoire:find("knife",1,true) and ability and GetAbilityName then grimoire=normalizedName(GetAbilityName(ability)) end
    if not grimoire:find("knife",1,true) then return end
    local script=normalizedName(GetCraftedAbilityScriptDisplayName(tonumber(signature)))
    if script:find("warrior's opportunity",1,true) then return KNIFE_RULES.martial,key end
    if script:find("assassin's misery",1,true) then return KNIFE_RULES.status,key end
end

local function isCraftedTaunt(key,id)
    if BUILTIN.craftedTaunt[id] then return true end
    local focus=key and tonumber(key:match("^c:%d+:(%d+):%d+:%d+$"))
    if focus and GetCraftedAbilityScriptDisplayName then
        return normalizedName(GetCraftedAbilityScriptDisplayName(focus))=="taunt"
    end
    return false
end

-- Separate stack sources from duration sources (consolidated in SkillRules.lua).
local STACK_SOURCES=BUILTIN.stacks
-- Selected ability/effect mappings.
-- They are observation-only: native duration tracking remains unchanged.
local TARGET_IDS={
    [38788]=38791,[38745]=38747,[28379]=29293,[38839]=38841,[38845]=38848,
    [83600]=85156,[85187]=85192,[85179]=85182,
    [38701]=38703,[28869]=44540,[38645]=44545,[38660]=44549,
    [29073]=62648,[29089]=62722,[29078]=62692,[38944]=62682,[38978]=62745,[38970]=62712,
    [28306]=38254,[38250]=38254,[38256]=38254,[38989]=38254,
    [29173]=61743,[20668]=44369,[20917]=31102,
    [58855]=58856,[58879]=58880,[86023]=101703,[86027]=101904,[86031]=101944,
    [33326]=33333,[36943]=36947,[36957]=36960,[40382]=40385,
    [35750]=35756,[40372]=40375,[40465]=40468,
    [122174]=106754,[122388]=106754,[122391]=106754,
}
local PROC_IDS={[46324]=46327,[114716]=46327}
-- Friendly recipient counts are explicit opt-ins, not every player buff.
-- Resolving Vigor is self-only and deliberately excluded.
local ALLY_COUNT_EFFECTS=BUILTIN.allyCounts

-- Player buff IDs for toggles whose native slot flag can lag until a swap.
-- Banner variants share one activation; never treat an ally's banner as ours.
local BANNER_IDS={217699,227085,227600,230289,217704,217705,217706,227003,227004,227007,227008,227009,227029,227030,227066,227067,227069,227070,227071,227073,227082,227086,227087,227088,227089,227091,227092,227093,227094,227095,227096,227101,227102,227103,227104,227106,227107,227108,227109,227110,227111,227112,227113,227115,227116,227120,227123,230293,231753}
local TOGGLE_GROUPS={banner=BANNER_IDS,
    frenzy={132141,172418},simmering={134160,134166},sated={135841,172648},
    mend={103543},mendspirit={103747},symbiosis={103755},
    meditate={103492},deepthoughts={103652},introspection={103665},
    guard={61511,61536,61529,78338,81415,80923,80947,80983,81420},
    overload={24785,24806,24804},cloak={25375,25380},
}
local TOGGLE_KEYS={}
for group,ids in pairs(TOGGLE_GROUPS) do for _,id in ipairs(ids) do TOGGLE_KEYS[id]=group end end

-- Estimate key of a rule: fixed (cast) timers are keyed by position.
local function fallbackKey(rule,index) return rule.mode=="cast" and -index or rule.effect end
local function positive(value)
    local n=tonumber(value)
    return n and n>0 and n<math.huge and n or nil
end
local function integer(value)
    local n=positive(value)
    return n and n==math.floor(n) and n or nil
end

-- Phase chains: one skill, several timed effects started together. The
-- soonest phase is shown in the centre, the next one in the lower-left
-- corner, and it moves to the centre when the first phase ends. Durations
-- are read once per binding from the game's own (localised) tooltip text.
local SECOND_UNITS={"second","sekunde","seconde","segundo","сек","秒"}
local function durationsIn(text,limit)
    if type(text)~="string" or text=="" then return nil end
    text=text:gsub("|c%x%x%x%x%x%x",""):gsub("|r",""):lower()
    local found,pos={},1
    while #found<(limit or 4) do
        local best,stop,value
        for _,unit in ipairs(SECOND_UNITS) do
            local s,e,num=text:find("(%d+[%.,]?%d*)[%s\194\160]*"..unit,pos)
            if s and (not best or s<best) then best,stop,value=s,e,num end
        end
        if not best then break end
        local n=tonumber((value:gsub(",",".")))
        -- "every 1 second" style tick rates are not effect durations.
        if n and n>=1.5 and n<=600 then found[#found+1]=math.floor(n*1000+.5) end
        pos=stop+1
    end
    return found
end
-- Entries are {ms,name}; returns parallel duration and name lists.
local function sortedPhases(list)
    table.sort(list,function(x,y) return x[1]<y[1] end)
    local ms,names={},{}
    for _,e in ipairs(list) do
        -- Effects ending within the same moment read as one timer.
        if not ms[#ms] or e[1]-ms[#ms]>600 then ms[#ms+1]=e[1]; names[#names+1]=e[2] or ""
        elseif e[2] and e[2]~="" then names[#names]=names[#names]~="" and names[#names].." + "..e[2] or e[2] end
    end
    if #ms==0 then return nil end
    return ms,names
end
local contingencyCraftedId
local function isContingency(key,id)
    if BUILTIN.contingency[id] then return true end
    local crafted=key and tonumber(key:match("^c:(%d+):"))
    if not crafted then return false end
    if contingencyCraftedId==nil then
        contingencyCraftedId=GetAbilityCraftedAbilityId and (integer(GetAbilityCraftedAbilityId(217528)) or integer(GetAbilityCraftedAbilityId(222678))) or false
    end
    return contingencyCraftedId~=false and crafted==contingencyCraftedId
end
local function scriptName(id)
    local n=GetCraftedAbilityScriptDisplayName and GetCraftedAbilityScriptDisplayName(id) or ""
    return type(n)=="string" and n:gsub("%^.*$","") or ""
end
local function contingencyPhases(key,id)
    local crafted,a,b,c=key:match("^c:(%d+):(%d+):(%d+):(%d+)$")
    local list={}
    if crafted and GetCraftedAbilityScriptDescription then
        for _,script in ipairs({tonumber(a),tonumber(b),tonumber(c)}) do
            if script and script>0 then
                local d=durationsIn(GetCraftedAbilityScriptDescription(tonumber(crafted),script),1)
                if d and d[1] then list[#list+1]={d[1],scriptName(script)} end
            end
        end
    end
    if #list==0 and id and GetAbilityDescription then
        -- The first duration of the full tooltip is the rune itself.
        local all=durationsIn(GetAbilityDescription(id),5) or {}
        for i=2,#all do list[#list+1]={all[i],""} end
    end
    return sortedPhases(list)
end
-- Resolving Vigor: heal over time, then Minor Resolve.
local CAST_CHAINS={[61507]={{5000,"Heal over time"},{20000,"Minor Resolve"}}}
local function castPhases(id)
    local fallback=CAST_CHAINS[id]
    local found=GetAbilityDescription and durationsIn(GetAbilityDescription(id),#fallback) or nil
    local list={}
    for i,e in ipairs(fallback) do list[i]={found and #found==#fallback and found[i] or e[1],e[2]} end
    return sortedPhases(list)
end

function T.New(rules,procRules)
    -- Preserve saved v0.3/v0.4 single-effect mappings on upgrade.
    for key,value in pairs(rules) do
        if type(value)=="table" and value.effect then rules[key]={value} end
    end
    local tracker=setmetatable({rules=rules,procRules=procRules or {},procState={},procWanted={},stackWanted={},stackSeen={},stackZeroUntil={},permanentStacks={},snapshotStacks={},toggleWanted={},toggleBuffs={},toggleObserved={},toggleState={},toggleRetry={},watched={}, requested={}, real={}, scan={}, fallback={}, bindings={}, effectSeen={}, phaseSeen={}, sharedRecords={},sharedCast={},chargeState={},targetBlacklist={},trackingPolicies={},chainState={},chainSpecs={},targetLearn={},lastTarget={},procGame={},toggleGame={},auxWanted={},auxWatched={},passiveWanted={},passiveEffects={},external={},reticle={},enabled=true,targetsEnabled=true,procEnabled=true,retVersion=1,targetRev=1},T)
    tracker.stackGame={}
    tracker.passiveTextCache={count=0,text=""}
    -- Reuse callbacks across ability namespaces; the engine still filters
    -- each registration independently, with no broad combat-event handler.
    tracker.effectCallback=function(...) tracker:OnEffect(...) end
    tracker.auxCallback=function(...) tracker:OnAuxEffect(...) end
    tracker.specialCallback=function(...) tracker:OnSpecialCombat(...) end
    tracker.nwCombatCallback=function(...) tracker:OnNWCombat(...) end
    tracker.nwEffectCallback=function(...) tracker:OnNWEffect(...) end
    tracker.powerLashCallback=function(...) tracker:OnPowerLashCombat(...) end
    return tracker
end

function T:Policy(slot)
    return self.trackingPolicies[slot.abilityKey] or self.trackingPolicies[slot.visualKey]
end
local function resolveTimerPolicy(p,rule)
    return p and ((rule and p.effects and p.effects[rule.effect]) or p.timer)
end
function T:TimerPolicy(slot,rule)
    return resolveTimerPolicy(self:Policy(slot),rule)
end
function T:Soonest(slot,rule)
    local mode=self:TimerPolicy(slot,rule)
    if mode=="first" then return true end
    if mode=="last" then return false end
    return self.soonest
end
function T:ExternalEligible(slot,rule)
    return not slot.isKnife and not rule.shared and rule.mode~="cast" and not AMBIGUOUS_EXTERNAL[rule.effect]
end

-- Weapon-variant resolution (no ability IDs listed; works for any skill ESO
-- marks as chaining). Observed in the 2026-11-21 diagnostic: on the INACTIVE
-- bar GetSlotBoundId reports the variant of the ACTIVE weapon (both bars'
-- Blockade flipped Frost<->Storms on every swap). ESO's own action bar
-- resolves the variant from the morph instead:
--   SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(raw):GetEffectiveAbilityId(bar)
-- (actionbarassignmentmanager.lua ResetSlot, playerskillsdata.lua).
-- The resolved form is used ONLY when all of these hold, otherwise the slot
-- keeps the previous raw behaviour (unverified transforms stay untouched):
--   * the slot is on the inactive PRIMARY/BACKUP bar, skills data is ready,
--     and ESO marks the morph as chaining;
--   * the raw ID equals ESO's form for the ACTIVE bar (i.e. it really is the
--     active weapon's variant), and ESO's form for this bar differs from it;
--   * the two bars hold different main-hand weapon types (a weapon variant
--     can only differ when the weapons differ);
--   * this morph has not repeatedly disagreed with the raw ID on the active
--     bar. That negative state is the only memory kept, and it is cleared on
--     skill, equipment and Armory changes (T.ResetFormTrust).
-- No positive trust is cached: agreement is re-checked live on every call.
-- The raw ID is never overwritten; callers receive both.
local FORM_DISTRUST_AFTER=3
local formDistrust={}  -- morph base ability -> active-bar disagreements (sticky after the limit)
local function barsHoldDifferentWeapons()
    if not (GetItemWeaponType and BAG_WORN~=nil and EQUIP_SLOT_MAIN_HAND~=nil and EQUIP_SLOT_BACKUP_MAIN~=nil) then return false end
    return GetItemWeaponType(BAG_WORN,EQUIP_SLOT_MAIN_HAND)~=GetItemWeaponType(BAG_WORN,EQUIP_SLOT_BACKUP_MAIN)
end
local function chainedProgression(raw,category)
    if category~=HOTBAR_CATEGORY_PRIMARY and category~=HOTBAR_CATEGORY_BACKUP then return nil end
    local m=SKILLS_DATA_MANAGER
    if not (m and m.GetProgressionDataByAbilityId and m.IsDataReady and m:IsDataReady()) then return nil end
    local pd=m:GetProgressionDataByAbilityId(raw)
    if not (pd and pd.IsChainingAbility and pd.GetEffectiveAbilityId and pd:IsChainingAbility()) then return nil end
    return pd,pd.GetAbilityId and pd:GetAbilityId() or raw
end
-- Returns: resolved form (or nil to keep raw), chained (ESO chaining morph).
local function weaponVariantForm(raw,category)
    local pd,base=chainedProgression(raw,category)
    if not pd then return nil,false end
    local active=GetActiveHotbarCategory and GetActiveHotbarCategory()
    local form=integer(pd:GetEffectiveAbilityId(category))
    local distrusted=(formDistrust[base] or 0)>=FORM_DISTRUST_AFTER
    if category==active then
        -- Active bar: raw is authoritative. Use it, and check ESO against it.
        if form and not distrusted then
            if form==raw then formDistrust[base]=nil
            else formDistrust[base]=(formDistrust[base] or 0)+1 end
        end
        return nil,true
    end
    if not form or form==raw or distrusted then return nil,true end
    if active~=HOTBAR_CATEGORY_PRIMARY and active~=HOTBAR_CATEGORY_BACKUP then return nil,true end
    -- Live agreement: the reported raw must be ESO's form for the active bar.
    if integer(pd:GetEffectiveAbilityId(active))~=raw then return nil,true end
    if not barsHoldDifferentWeapons() then return nil,true end
    return form,true
end
function T.ResetFormTrust() for k in pairs(formDistrust) do formDistrust[k]=nil end end
-- The slot's display name follows the same active-weapon variant as the raw
-- ID, so chained slots use the resolved ability's name on both bars.
local function bindingSlotName(index,category,id,chained)
    if chained and GetAbilityName then return GetAbilityName(id) end
    return GetSlotName and GetSlotName(index,category)
end

-- Returns key, ability (resolved), raw (as reported by GetSlotBoundId),
-- chained, resolved. noVariant: skip weapon-variant resolution (per-tick use).
function T.IdentifySlot(index,category,sampledRaw,noVariant)
    local raw=integer(sampledRaw or GetSlotBoundId(index,category))
    if not raw then return nil,nil end
    local ability,crafted=raw,nil
    if ACTION_TYPE_CRAFTED_ABILITY and type(GetSlotType)=="function" and GetSlotType(index,category)==ACTION_TYPE_CRAFTED_ABILITY then
        crafted=raw
        if type(GetAbilityIdForCraftedAbilityId)=="function" then ability=integer(GetAbilityIdForCraftedAbilityId(raw)) or raw end
    elseif type(GetAbilityCraftedAbilityId)=="function" then
        crafted=integer(GetAbilityCraftedAbilityId(ability))
    end
    if crafted and type(GetCraftedAbilityActiveScriptIds)=="function" then
        local a,b,c=GetCraftedAbilityActiveScriptIds(crafted)
        return string.format("c:%d:%d:%d:%d",crafted,a or 0,b or 0,c or 0),ability,raw
    end
    if noVariant then return "a:"..ability,ability,raw,false,false end
    local form,chained=weaponVariantForm(raw,category)
    if form then ability=form end
    return "a:"..ability,ability,raw,chained,form~=nil
end
-- Change detection for chained slots follows the resolved ability, so a raw
-- ID that only mirrors the active weapon does not count as a binding change.
local function identityRaw(id,raw,chained) if chained then return id end return raw end

-- A crafted ability may have a new runtime ID after its scripts change.
-- Identify Banner by its grimoire as well as known buff/ability IDs.
local function toggleGroupFor(key,id,index,category,sampledRaw)
    if TOGGLE_KEYS[id] then return TOGGLE_KEYS[id] end
    if not id then return end
    local raw=sampledRaw or GetSlotBoundId(index,category)
    if TOGGLE_KEYS[raw]=="banner" then return "banner" end
    local crafted=key and tonumber(key:match("^c:(%d+):"))
    if crafted then
        local bannerCrafted=GetAbilityCraftedAbilityId and integer(GetAbilityCraftedAbilityId(217699))
        if bannerCrafted and bannerCrafted==crafted then return "banner" end
        local name=GetCraftedAbilityDisplayName and normalizedName(GetCraftedAbilityDisplayName(crafted)) or ""
        if name:find("banner bearer",1,true) then return "banner" end
    end
    local name=GetSlotName and normalizedName(GetSlotName(index,category)) or ""
    local abilityName=GetAbilityName and normalizedName(GetAbilityName(id)) or ""
    if name:find("banner bearer",1,true) or abilityName:find("banner bearer",1,true) then return "banner" end
    if crafted and (name:find("banner",1,true) or abilityName:find("banner",1,true)) then return "banner" end
    local icon=GetAbilityIcon and normalizedName(GetAbilityIcon(217699)) or ""
    if icon~="" and GetSlotTexture and normalizedName(GetSlotTexture(index,category))==icon then return "banner" end
end

local function isKnife(key,id,index,category)
    if not id then return false end
    local crafted=key and tonumber(key:match("^c:(%d+):"))
    if crafted==KNIFE_GRIMOIRE then return true end
    local name=crafted and GetCraftedAbilityDisplayName and normalizedName(GetCraftedAbilityDisplayName(crafted)) or ""
    if name:find("knife",1,true) then return true end
    name=GetAbilityName and normalizedName(GetAbilityName(id)) or ""
    if name:find("traveling knife",1,true) or (crafted and name:find("knife",1,true)) then return true end
    name=GetSlotName and normalizedName(GetSlotName(index,category)) or ""
    return name:find("traveling knife",1,true)~=nil or (crafted and name:find("knife",1,true)~=nil)
end

-- Visual preferences follow explicitly known forms of the same skill. Do not
-- group all skills sharing a stack effect (e.g. Arcanist Crux) or all morphs.
local VISUAL_ALIASES={
    ["a:123699"]="a:117624",["a:123704"]="a:117624", -- Venom Skull
    ["a:123718"]="a:117637",["a:123719"]="a:117637", -- Ricochet Skull
    ["a:61907"]="a:61902",["a:61930"]="a:61919",["a:61932"]="a:61927", -- Focus proc forms
}
function T.VisualKey(key) return VISUAL_ALIASES[key] or key end
function T.IdentifyVisualSlot(index,category)
    local key,id=T.IdentifySlot(index,category)
    return T.VisualKey(key),id
end

local selfCastRules={}
local function selfCastRule(key,ability)
    if not ability or key~="a:"..ability or not GetAbilityName then return nil end
    local cached=selfCastRules[ability]
    if cached~=nil then return cached or nil end
    local name=normalizedName(GetAbilityName(ability)):gsub("%^.*$","")
    local duration=BUILTIN.selfCastNames[name]
    local rule=duration and {{effect=ability,mode="cast",duration=duration}} or nil
    if name~="" then selfCastRules[ability]=rule or false end
    return rule
end

function T:RulesFor(key,ability,ignoreCustom)
    if not ignoreCustom and key and self.rules[key] then return self.rules[key],key end
    local base=ability and "a:"..ability
    if not ignoreCustom and base and self.rules[base] then return self.rules[base],base end
    local selfCast=selfCastRule(key,ability)
    if selfCast then return selfCast,key end
    if self.wardMasteryOwned and BUILTIN.wardMastery[ability] then return BUILTIN.wardMastery[ability],base end
    local auto,autoKey=automaticRules(key,ability)
    if auto then return auto,autoKey end
    local variants=BUILTIN.racialDuration[ability]
    if variants then
        local race=GetUnitRaceId and GetUnitRaceId("player")
        return variants[race==9 and 2 or race==6 and 3 or 1],base
    end
    -- Never attach a base-skill rule to an unrecognized crafted script set.
    if BUILTIN.duration[key] then return BUILTIN.duration[key],key end
    if isCraftedTaunt(key,ability) then return BUILTIN.tauntRule,key end
    if base==key and BUILTIN.shared[ability] then return BUILTIN.shared[ability],key end
end
function T:RuleFor(key,ability,index)
    local list,ruleKey=self:RulesFor(key,ability)
    return list and list[index or 1],ruleKey
end

function T.Validate(effect,duration,mode)
    effect=integer(effect); duration=positive(duration); mode=mode or "auto"
    if not effect then return nil,"Effect ID must be a positive integer." end
    if mode~="auto" and mode~="effect" and mode~="cast" then return nil,"Mode: auto, effect, or cast." end
    if mode~="effect" and (not duration or duration>3600) then return nil,"Enter a fallback duration greater than 0 and at most 3600 seconds." end
    return {effect=effect,duration=duration or 0,mode=mode}
end

function T:SetRule(key,effect,duration,mode,index)
    if not key then return false,"No skill in that slot." end
    local rule,problem=T.Validate(effect,duration,mode)
    if not rule then return false,problem end
    local ability=tonumber(key:match("^a:(%d+)$"))
    local crafted=tonumber(key:match("^c:(%d+):"))
    if crafted and GetAbilityIdForCraftedAbilityId then ability=GetAbilityIdForCraftedAbilityId(crafted) end
    local list=self:RulesFor(key,ability) or {}
    index=index or 1
    if index<1 or index>3 or index>#list+1 then return false,"Add effect entries in order (1-3)." end
    for i,r in ipairs(list) do
        if i~=index and r.effect==rule.effect then return false,"This effect ID is already tracked on the skill." end
    end
    -- Replace list identity so the HUD invalidates its cached fill.
    local copy={}
    for i,r in ipairs(list) do copy[i]=r end
    copy[index]=rule; self.rules[key]=copy; self.chainSpecs[key]=nil
    -- Running timers of this position stop: effect timers are stored under
    -- their ID, fixed timers under -position.
    local bucket=self.fallback[key]
    if bucket then
        local old=list[index]
        if old then bucket[fallbackKey(old,index)]=nil; bucket[old.effect]=nil end
        bucket[rule.effect]=nil; bucket[-index]=nil
    end
    self.targetLearn[key]=nil; self.lastTarget[key]=nil
    self.retVersion=(self.retVersion or 0)+1; self.targetRev=(self.targetRev or 0)+1
    return true,rule
end

-- Replace every timer of a skill at once (the tracking window's Save).
function T:SetRules(key,list)
    if not key then return false,"No skill in that slot." end
    -- Positions are kept: an empty middle stays the game's own timer and a
    -- lower-left timer stays lower left ({mode="off"} fills the gap).
    local copy,seen,promoted,last={},{},false,0
    for i=1,3 do if list[i] then last=i end end
    for i=1,last do
        local r=list[i]
        if r then
            local rule,problem
            if r.keep then
                -- An unchanged row keeps every field of its rule (placement,
                -- follow-up, fallback mode/seconds of built-in rules). It was
                -- valid when saved, so it is copied, not validated again.
                rule={}
                for k,v in pairs(r.keep) do rule[k]=v end
                rule.promote=nil
            else
                rule,problem=T.Validate(r.effect,r.duration,r.mode)
                if not rule then return false,problem end
            end
            if rule.mode~="cast" then
                if seen[rule.effect] then return false,"This effect ID is already tracked on the skill." end
                seen[rule.effect]=true
            end
            copy[i]=rule
            -- One corner timer may move to the middle when the middle ends.
            if r.promote and i>=2 and not promoted then rule.promote=true; promoted=true end
        else copy[i]={effect=0,duration=0,mode="off"} end
    end
    self.rules[key]=last>0 and copy or nil
    self.fallback[key]=nil; self.chainSpecs[key]=nil; self.targetLearn[key]=nil; self.lastTarget[key]=nil
    self.retVersion=(self.retVersion or 0)+1; self.targetRev=(self.targetRev or 0)+1
    return true,#copy
end
function T:ClearRule(key,index)
    if not key then return end
    self.chainSpecs[key]=nil; self.targetLearn[key]=nil; self.lastTarget[key]=nil
    self.retVersion=(self.retVersion or 0)+1; self.targetRev=(self.targetRev or 0)+1
    local list=self.rules[key]
    if not index then self.rules[key]=nil; self.fallback[key]=nil
    elseif list and list[index] then
        local copy={}
        local bucket=self.fallback[key]
        local moved={}
        for i,r in ipairs(list) do
            if i~=index then
                copy[#copy+1]=r
                -- Fixed timers are keyed by position: follow the shift.
                if bucket and r.mode=="cast" then moved[#copy]=bucket[-i] or false end
            end
        end
        self.rules[key]=#copy>0 and copy or nil
        if bucket then
            if list[index].mode~="cast" then bucket[list[index].effect]=nil end
            for i=1,#list do bucket[-i]=nil end
            for i,v in pairs(moved) do if v then bucket[-i]=v end end
        end
        self.lastTarget[key]=nil
    end
end

-- Classify the actual slot target at bind time. Localized descriptions for
-- Self and Enemy can be anchored to two known skills in the same client.
local targetEnemyDescription,targetSelfDescription,targetGroundDescription,targetAreaDescription,targetConeDescription
local function timerTargetDescription(ability)
    return normalizedName(GetAbilityTargetDescription(ability,nil,"player")):match("^%s*(.-)%s*$")
end
local function timerTargetScope(id,category)
    if not id then return nil end
    if BUILTIN.groundTimers[id] then return "ground" end
    if not GetAbilityTargetDescription then return nil end
    local effective=GetEffectiveAbilityIdForAbilityOnHotbar and GetEffectiveAbilityIdForAbilityOnHotbar(id,category)
    if BUILTIN.groundTimers[effective] then return "ground" end
    local value=timerTargetDescription(effective and effective>0 and effective or id)
    if value=="" and effective and effective~=id then value=timerTargetDescription(id) end
    if value=="" then return nil end
    if not targetEnemyDescription then local enemy=timerTargetDescription(117624); if enemy~="" then targetEnemyDescription=enemy end end
    if value=="enemy" or value==targetEnemyDescription then return "enemy" end
    if not targetSelfDescription then local own=timerTargetDescription(61507); if own~="" then targetSelfDescription=own end end
    if value=="self" or value==targetSelfDescription then return "self" end
    -- Localized anchors: Caltrops is placed on the ground, Vigor is an area
    -- cast, Dragonfire Breath is a cone. Never equate a ground label with
    -- area/cone if a client reports identical descriptions for both.
    if not targetGroundDescription then local v=timerTargetDescription(33376); if v~="" then targetGroundDescription=v end end
    if not targetAreaDescription then local v=timerTargetDescription(61503); if v~="" then targetAreaDescription=v end end
    if not targetConeDescription then local v=timerTargetDescription(20917); if v~="" then targetConeDescription=v end end
    if value=="ground" or (value==targetGroundDescription and value~=targetAreaDescription and value~=targetConeDescription) then return "ground" end
    if value=="area" or value=="cone" or value==targetAreaDescription or value==targetConeDescription then return "area" end
    return "other"
end
local selfTargetEffects,selfTargetCount={},0
local function isSelfTargetEffect(id)
    if not id or not GetAbilityTargetDescription then return false end
    local cached=selfTargetEffects[id]
    if cached~=nil then return cached end
    local value=timerTargetDescription(id)
    if value=="" then return false end
    if not targetSelfDescription then local own=timerTargetDescription(61507); if own~="" then targetSelfDescription=own end end
    local result=(value=="self" or value==targetSelfDescription)
    if selfTargetCount>=256 then
        for k in pairs(selfTargetEffects) do selfTargetEffects[k]=nil end
        selfTargetCount=0
    end
    selfTargetEffects[id]=result; selfTargetCount=selfTargetCount+1
    return result
end

-- A broad runtime ability-list notification is not a character respec.
-- Verify native identity of ordinary, already resolved slots without
-- resolving their rules again. Crafted/custom/locked and racial rules
-- retain the full binding path (their metadata can have other inputs).
function T:NativeBindingUnchanged(slot,index,category,sampledRaw)
    if slot.bindingOwner~=self or slot.bindingIndex~=index or slot.bindingCategory~=category
        or slot.ruleLock or slot.customTimer then return false end
    local previous=slot.abilityKey
    if previous and (previous:sub(1,2)=="c:" or self.rules[previous] or BUILTIN.racialDuration[slot.abilityId]) then return false end
    local key,id,raw,chained=T.IdentifySlot(index,category,sampledRaw)
    if key~=slot.abilityKey or id~=slot.abilityId or identityRaw(id,raw,chained)~=slot.bindingIdentityRaw then return false end
    if not id then return slot.bindingEffective==nil and slot.bindingName==nil and slot.bindingAbilityName==nil end
    local effective=GetEffectiveAbilityIdForAbilityOnHotbar and GetEffectiveAbilityIdForAbilityOnHotbar(id,category) or id
    if effective~=slot.bindingEffective then return false end
    local name=bindingSlotName(index,category,id,chained)
    local abilityName=GetAbilityName and GetAbilityName(id)
    return name and name~="" and abilityName and abilityName~=""
        and name==slot.bindingName and abilityName==slot.bindingAbilityName
end

function T:Bind(slot,index,category,reuse,lockMode,sampledRaw)
    local key,id,raw,chained=T.IdentifySlot(index,category,sampledRaw)
    local idRaw=identityRaw(id,raw,chained)
    -- The binding owns the effective rule, not the account-wide saved rule.
    -- Retain a resolved lock on unchanged identities until the owner
    -- revalidates it after allocation/equipment/settings changes.
    if lockMode==nil then lockMode=slot.abilityKey==key and slot.ruleLock or false end
    local rule,ruleKey=self:RulesFor(key,id)
    local custom=ruleKey and self.rules[ruleKey]==rule and rule~=nil
    if lockMode and custom then
        if lockMode=="middle" and rule[1] and rule[1].mode~="off" then
            local any=false
            for i=2,#rule do if rule[i].mode~="off" then any=true; break end end
            if any then
                if slot.maskedRuleSource~=rule then
                    local copy={}
                    for i,r in ipairs(rule) do copy[i]=r end
                    copy[1]={effect=0,duration=0,mode="off"}
                    slot.maskedRuleSource,slot.maskedRule=rule,copy
                end
                rule=slot.maskedRule
                ruleKey=ruleKey.."#middle"
            else
                rule,ruleKey=self:RulesFor(key,id,true); custom=false
                if ruleKey then ruleKey=ruleKey.."#locked" end
            end
        elseif lockMode=="all" then
            rule,ruleKey=self:RulesFor(key,id,true); custom=false
            if ruleKey then ruleKey=ruleKey.."#locked" end
        end
    else lockMode=false end
    slot.ruleLock=lockMode
    -- Only the incremental hotbar path may reuse metadata. Explicit skill,
    -- settings, passive and lifecycle invalidations still run a full bind.
    local effective=id and GetEffectiveAbilityIdForAbilityOnHotbar and GetEffectiveAbilityIdForAbilityOnHotbar(id,category) or id
    local name=id and bindingSlotName(index,category,id,chained) or nil
    local abilityName=id and GetAbilityName and GetAbilityName(id) or nil
    if reuse and slot.bindingOwner==self and slot.bindingIndex==index and slot.bindingCategory==category
        and slot.abilityKey==key and slot.abilityId==id and slot.bindingIdentityRaw==idRaw and slot.bindingEffective==effective
        and slot.bindingName==name and slot.bindingAbilityName==abilityName and slot.track==rule and slot.trackKey==ruleKey
        and (not id or (name and name~="" and abilityName and abilityName~="")) then
        return false,false
    end
    if slot.bindingEffective~=effective or slot.bindingIdentityRaw~=idRaw or slot.bindingCategory~=category or slot.bindingName~=name or slot.bindingAbilityName~=abilityName then self.syncDirty=true end
    slot.ttRetVer=nil; slot.tcRev=nil
    slot.bindingOwner,slot.bindingIndex,slot.bindingCategory=self,index,category
    slot.bindingRaw,slot.bindingIdentityRaw,slot.bindingEffective,slot.bindingName,slot.bindingAbilityName=raw,idRaw,effective,name,abilityName
    local changed=slot.abilityKey~=key or slot.abilityId~=id or slot.track~=rule or slot.trackKey~=ruleKey
    if changed then
        slot.effectEnd=nil; slot.lastHeight=nil
        slot.expiryActive={}
    end
    slot.abilityKey,slot.abilityId=key,id
    slot.visualKey=T.VisualKey(key)
    slot.track,slot.trackKey=rule,ruleKey
    slot.timerTargetScope=timerTargetScope(id,category)
    slot.customTimer=not not custom
    local primary=rule and rule[1]
    if primary and primary.mode=="off" then primary=nil end
    local targetEffect=primary and (primary.mode~="cast" and primary.effect or nil) or (not primary and id and (TARGET_IDS[id] or id) or nil)
    if id==39113 and primary and primary.mode=="cast" and primary.effect==109966 then targetEffect=109966 end
    local procEffect=key and self:GetProcRule(key,id) or nil
    local readyEffects=self.procRules[key]==nil and (BUILTIN.contingency[id] and BUILTIN.contingencyProcs or BUILTIN.readyProcs[id] and {BUILTIN.readyProcs[id]}) or nil
    local toggleGroup=toggleGroupFor(key,id,index,category,raw)
    if toggleGroup=="banner" then targetEffect=nil end
    if changed or slot.targetEffect~=targetEffect or slot.procEffect~=procEffect or (slot.readyEffects~=nil)~=(readyEffects~=nil) or slot.toggleGroup~=toggleGroup then self.syncDirty=true end
    slot.targetEffect=targetEffect
    slot.recipientEffect=BUILTIN.sharedRecipients[id]
    slot.recipientAliases=BUILTIN.groupRecipientAliases[id]
    slot.groupBuffCount=slot.recipientEffect~=nil or slot.recipientAliases~=nil or (not (primary and primary.shared) and BUILTIN.groupBuffEffects[targetEffect]==true)
    slot.sharedEffect=primary and primary.shared and primary.effect or nil
    slot.chargeId=BUILTIN.chargeAliases[id] or (BUILTIN.chargeSkills[id]~=nil and id or nil)
    slot.chain=self:ChainSpec(key,id,lockMode and not custom)
    slot.matchName=id and GetAbilityName and normalizedName(abilityName):gsub("%^.*$","") or nil
    slot.readyEffects=readyEffects
    slot.procEffect=procEffect
    slot.toggleGroup=toggleGroup
    slot.isKnife=isKnife(key,id,index,category)
    slot.suppressStack=toggleGroup=="banner" or EXTERNAL_COUNTS[id]~=nil or slot.isKnife or BUILTIN.phaseBadge[id] or BUILTIN.topRightTimer[id]
    slot.stackEffect=not slot.suppressStack and STACK_SOURCES[id] or nil
    slot.stackOnlyPrimary=(primary and BUILTIN.stackOnlyEffects[primary.effect]) or
        (not primary and BUILTIN.stackOnlyEffects[slot.stackEffect]) or false
    slot.targetStackEffect=BUILTIN.targetStacks[id] or (isCraftedTaunt(key,id) and 52790 or nil)
    slot.phaseStack=BUILTIN.phaseInfo[id] and id or nil
    slot.phaseBadge=BUILTIN.phaseBadge[id] or false
    slot.topRightTimer=BUILTIN.topRightTimer[id] or false
    slot.noStackGlow=BUILTIN.noStackGlow[id] or false
    slot.stackReadyAt=BUILTIN.stackReadyAt[id]
    slot.fragProc=BUILTIN.fragProc[id] or false
    slot.noExpiryGlow=BUILTIN.noExpiryGlow[targetEffect] or (targetEffect and self:IsOffBalance(targetEffect,GetAbilityName and GetAbilityName(targetEffect))) or false
    if not slot.noExpiryGlow then
        for _,entry in ipairs(rule or {}) do
            local effect=entry.effect
            if effect and effect>0 and (BUILTIN.noExpiryGlow[effect] or self:IsOffBalance(effect,GetAbilityName and GetAbilityName(effect))) then
                slot.noExpiryGlow=true; break
            end
        end
    end
    slot.focusRequired=BUILTIN.focusRequired[id]
    slot.noDurationFill=BUILTIN.noDurationFill[id] or slot.noExpiryGlow or slot.stackEffect==267744 or slot.procEffect~=nil or slot.readyEffects~=nil or false
    slot.focusTarget=BUILTIN.focusTarget[id] or false
    slot.noNativeTimer=BUILTIN.noNativeTimer[id] or BUILTIN.topRightTimer[id] or slot.stackOnlyPrimary or
        BUILTIN.stackOnlyEffects[slot.stackEffect] or false
    slot.deviceParent=BUILTIN.devices[id] and id or nil
    slot.shieldCharges=BUILTIN.shieldCharges[id] and id or nil
    slot.combatTimer=BUILTIN.combatTimers[id] and id or nil
    slot.nwSlot=id and siphonSlot(id,index,category)
    slot.landslideSlot=WHIPS[id]
    slot.flameSlot=FLAME_WHIPS[id]
    slot.externalCountEffect=EXTERNAL_COUNTS[id]
    slot.vampirePassiveSlot=FRENZY_SLOTS[id] or false
    slot.arcanistPassiveSlot=FATECARVER_SLOTS[id] and "Fatecarver" or DREAD_SLOTS[id] and "Tentacular Dread" or nil
    -- Precompute bind-time capability gates so UpdateSkillTimers avoids
    -- invoking Tracker helpers on ineligible slots every 100 ms tick.
    slot.groundTimer=slot.timerTargetScope=="ground" and not (primary and primary.placement)
    slot.groundNoTargetCount=slot.groundTimer and not slot.customTimer and not slot.groupBuffCount
    slot.hasTrackerPrimary=id~=nil and not slot.flameSlot and (slot.stackOnlyPrimary or slot.chain~=nil
        or slot.deviceParent~=nil or slot.combatTimer~=nil or slot.chargeId==46331 or primary~=nil)
    slot.canProc=slot.readyEffects~=nil or slot.procEffect~=nil or (slot.chain~=nil and slot.chain.trigger=="contingency")
    local customPrimary=slot.customTimer and primary~=nil
    slot.followTargetEligible=id~=nil and not (slot.chain or slot.toggleGroup or slot.deviceParent or slot.combatTimer
        or slot.chargeId or slot.phaseStack or slot.groupBuffCount or slot.sharedEffect or slot.noNativeTimer)
        and not (primary and primary.mode=="cast")
        and (slot.timerTargetScope~="self" or customPrimary)
        and (not slot.groundTimer or customPrimary)
        and (slot.timerTargetScope~="other" or primary~=nil or (targetEffect~=nil and targetEffect~=id))
    return changed,true
end
function T:ChainSpec(key,id,ignoreCustom)
    if not key or not id then return nil end
    -- A user-defined effect list for the skill always wins.
    if not ignoreCustom and (self.rules[key] or self.rules["a:"..id]) then return nil end
    local cached=self.chainSpecs[key]
    if cached~=nil then return cached or nil end
    local spec=false
    if isContingency(key,id) then
        -- No readable script durations: leave the skill to the game timer.
        local phases,names=contingencyPhases(key,id)
        local rune=GetAbilityDuration and positive(GetAbilityDuration(id,nil,"player"))
        if phases then spec={trigger="contingency",phases=phases,names=names,rune=rune and rune>=5000 and rune<=60000 and rune or 22000} end
    elseif CAST_CHAINS[id] then
        local phases,names=castPhases(id)
        spec={trigger="cast",phases=phases,names=names}
    end
    self.chainSpecs[key]=spec
    return spec or nil
end
function T:StartChain(key,spec,at)
    if not key or not spec or #spec.phases==0 then return end
    local state=self.chainState[key] or {}
    for i,ms in ipairs(spec.phases) do
        local r=state[i] or {}; r.finish=at+ms; r.duration=ms; state[i]=r
    end
    for i=#spec.phases+1,#state do state[i]=nil end
    self.chainState[key]=state
end
-- Ulfsild's rune triggers on the next ability cast with a cost or a dodge.
-- A dodge shows only as a fade of the rune buff, even 190 ms after the cast
-- when the dodge cancels the cast animation. The fade is held briefly: a
-- recast of the rune reports fade and gain in the same frame, and that gain
-- clears the hold so the recast never counts as a trigger.
function T:TriggerPrimed(at)
    local p=self.primed
    self.primed=nil
    if p then self:StartChain(p.key,self.chainSpecs[p.key] or nil,at) end
end
function T:ObserveCast(key,now)
    local p=self.primed
    if not self.enabled or not p or key==p.key then return end
    if now>p.untilTime then self.primed=nil; return end
    if now-p.castAt>100 then self:TriggerPrimed(now) end
end
function T:ObservePrime(change,endTime)
    local now=GetFrameTimeMilliseconds()
    local p=self.primed
    if change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED then
        if not p and self.contingencyKey then
            p={key=self.contingencyKey,castAt=now,untilTime=now+22000}; self.primed=p
        end
        if p and type(endTime)=="number" and endTime>0 then
            local left=(endTime-GetGameTimeSeconds())*1000
            if left>0 then p.untilTime=now+left; p.gameEnd=endTime; p.fadeAt=nil end
        end
    elseif change==EFFECT_RESULT_FADED and p and p.replacedEnd and type(endTime)=="number" and math.abs(endTime-p.replacedEnd)<=.05 then
        p.replacedEnd=nil
    elseif change==EFFECT_RESULT_FADED and p and not p.fadeAt then
        local early=p.gameEnd and GetGameTimeSeconds()<p.gameEnd-.4 or (not p.gameEnd and now<p.untilTime-400)
        if not early then self.primed=nil else p.fadeAt=now end
    end
end
function T:ChainGet(slot,now,index)
    local p=self.primed
    if p and p.fadeAt and now-p.fadeAt>=300 then self:TriggerPrimed(p.fadeAt)
    elseif p and now>p.untilTime+500 then self.primed=nil end
    local state=self.chainState[slot.abilityKey]
    local k=0
    if state then for i=1,#state do
        local r=state[i]
        if r.finish>now then k=k+1; if k==index then return r.finish-now,r.duration,0,false end end
    end end
    if index==1 then return 0,0,0,false end
    return nil
end
function T:ChainRemaining(slot,now)
    local state=self.chainState[slot.abilityKey]
    local last=state and state[#state]
    return last and last.finish>now and last.finish-now or 0
end
-- Debuff timers follow the enemy you look at (like a target frame): your
-- own debuffs on the reticle target are read once per change, and a skill
-- whose debuff was seen on an enemy shows that target's time, 0 if the
-- target lacks it, and keeps the last target's time while you look away.
local RETICLE_NS="ZeraUIFollowTarget"
function T:SyncFollowTarget(enabled)
    enabled=enabled and true or false
    -- followRegistered starts as nil. Compare it as a boolean, otherwise a
    -- disabled follow mode never reaches its steady state and every slot
    -- refresh wipes target memory and forces a full Sync rebuild.
    if self.followTarget==enabled and (self.followRegistered or false)==enabled then return end
    local wasEnabled=self.followTarget==true
    self.followTarget=enabled
    self.retVersion=(self.retVersion or 0)+1
    if enabled and not self.followRegistered and EVENT_EFFECT_CHANGED then
        EVENT_MANAGER:RegisterForEvent(RETICLE_NS,EVENT_EFFECT_CHANGED,function() self.retDirty=true end)
        if REGISTER_FILTER_UNIT_TAG then EVENT_MANAGER:AddFilterForEvent(RETICLE_NS,EVENT_EFFECT_CHANGED,REGISTER_FILTER_UNIT_TAG,"reticleover") end
        if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
            EVENT_MANAGER:AddFilterForEvent(RETICLE_NS,EVENT_EFFECT_CHANGED,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
        end
        self.followRegistered=true; self.retDirty=true
    elseif not enabled and self.followRegistered then
        EVENT_MANAGER:UnregisterForEvent(RETICLE_NS,EVENT_EFFECT_CHANGED)
        self.followRegistered=false; self.retMine=nil; self.retHostile=false
    end
    if not enabled then
        self.followRegistered=false
        self.retMine=nil; self.retHostile=false
        -- Only a real ON->OFF transition invalidates learned targets/bindings.
        if wasEnabled then self.targetLearn={}; self.lastTarget={}; self.syncDirty=true; self.targetRev=(self.targetRev or 0)+1 end
    end
end
function T:ReticleChanged() self.retDirty=true end
-- Lowercased, color-free names of reticle effects. Effect names repeat all
-- fight long, so each is converted once; the cache is wiped if it ever
-- grows large (strings are never collected from weak tables).
local reticleNames,reticleNameCount={},0
local function reticleName(name)
    if type(name)~="string" then return "" end
    local clean=reticleNames[name]
    if clean then return clean end
    if reticleNameCount>=256 then
        for k in pairs(reticleNames) do reticleNames[k]=nil end
        reticleNameCount=0
    end
    clean=normalizedName(name):gsub("%^.*$","")
    reticleNames[name]=clean; reticleNameCount=reticleNameCount+1
    return clean
end
function T:RefreshReticle(snapshot)
    if not self.followTarget or not self.retDirty then return end
    self.retDirty=false
    local tag="reticleover"
    local hostile=(DoesUnitExist and DoesUnitExist(tag) and not (IsUnitDead and IsUnitDead(tag)) and (not IsUnitAttackable or IsUnitAttackable(tag))) and true or false
    if not hostile then
        if self.retHostile then
            self.retHostile=false
            self.retVersion=(self.retVersion or 0)+1
            local m=self.retMine
            if m then
                for k in pairs(m.byId) do m.byId[k]=nil end
                for k in pairs(m.byName) do m.byName[k]=nil end
                if m.byDamageName then for k in pairs(m.byDamageName) do m.byDamageName[k]=nil end end
            end
        end
        return
    end
    self.retVersion=(self.retVersion or 0)+1
    local m=self.retMine or {byId={},byName={},byDamageName={},pool={}}; self.retMine=m
    for k in pairs(m.byId) do m.byId[k]=nil end
    for k in pairs(m.byName) do m.byName[k]=nil end
    m.byDamageName=m.byDamageName or {}
    for k in pairs(m.byDamageName) do m.byDamageName[k]=nil end
    self.retHostile=true
    if not GetNumBuffs or not GetUnitBuffInfo then return end
    local frame,game=GetFrameTimeMilliseconds(),GetGameTimeSeconds()
    -- One reused record per matching effect: nothing outside this cache
    -- keeps a record (TargetTimer copies the numbers it needs).
    local pool,used=m.pool,0
    local count,info=GetNumBuffs,GetUnitBuffInfo
    if snapshot then count,info=snapshot:Readers(tag) end
    for i=1,count(tag) or 0 do
        local name,start,finish,_,_,_,_,kind,abilityType,_,id,_,mine=info(tag,i)
        -- A known buff is not a hostile debuff even when cast by us.
        if mine and (not BUFF_EFFECT_TYPE_BUFF or kind~=BUFF_EFFECT_TYPE_BUFF) and type(finish)=="number" and finish>game and type(id)=="number" then
            used=used+1
            local r=pool[used]
            if not r then r={}; pool[used]=r end
            r.id=id; r.finish=frame+(finish-game)*1000; r.duration=(finish-(tonumber(start) or game))*1000
            r.damage=ABILITY_TYPE_DAMAGE~=nil and abilityType==ABILITY_TYPE_DAMAGE
            local old=m.byId[id]
            if not old or r.finish>old.finish then m.byId[id]=r end
            local lname=reticleName(name)
            local byName=m.byName[lname]
            if lname~="" and (not byName or r.finish>byName.finish) then m.byName[lname]=r end
            if r.damage and lname~="" then
                local damage=m.byDamageName[lname]
                -- Two different damage IDs of the same name are ambiguous.
                -- A curated ID can still select the correct one explicitly.
                if damage==nil then m.byDamageName[lname]=r
                elseif damage and damage.id~=id then m.byDamageName[lname]=false
                elseif damage and r.finish>damage.finish then m.byDamageName[lname]=r end
            end
        end
    end
end
-- An area/cone cast can either leave a placed object or attach a DoT to
-- each enemy. Without an explicit rule, only a confirmed own timed damage
-- effect of the same skill and duration may establish target ownership.
local function areaProbe(slot)
    local primary=slot.track and slot.track[1]
    return slot.timerTargetScope=="area" and not slot.customTimer and not primary and slot.targetEffect==slot.abilityId
end
local function groundTimer(slot)
    local primary=slot.track and slot.track[1]
    -- A triggered trap can attach a DoT after its placement phase.
    return slot.timerTargetScope=="ground" and not (primary and primary.placement)
end
local function matchingAreaDamage(slot,r)
    local span=slot.skillDuration
    return r and r.damage and span and span>1500 and math.abs(r.duration-span)<=math.max(500,span*.15)
end
-- Plain lookups (a nil key reads as nil): no closure or helper call per
-- slot on the HUD tick.
function T:MatchReticle(slot)
    local m=self.retMine
    if not m then return nil end
    local byId=m.byId
    local best,r
    -- Only the middle timer follows the target; corner timers keep theirs.
    local primary=slot.track and slot.track[1]
    if primary and primary.mode~="cast" and primary.mode~="off" and not primary.shared then
        best=byId[primary.effect]
        r=byId[primary.followup]; if r and (not best or r.finish>best.finish) then best=r end
        -- Curated/custom effect IDs are authoritative. A same-name side
        -- effect or the initial hit may have a completely different timer.
        return best
    end
    if slot.targetEffect and slot.targetEffect~=slot.abilityId then return byId[slot.targetEffect] end
    if areaProbe(slot) then
        local learned=self.targetLearn[slot.abilityKey]
        if learned then return byId[learned] end
        local exact=byId[slot.abilityId]
        if matchingAreaDamage(slot,exact) then return exact end
        local candidate=m.byDamageName and m.byDamageName[slot.matchName]
        if matchingAreaDamage(slot,candidate) then return candidate end
        return nil
    end
    best=byId[self.targetLearn[slot.abilityKey]]
    r=byId[slot.targetEffect]; if r and (not best or r.finish>best.finish) then best=r end
    r=byId[slot.abilityId]; if r and (not best or r.finish>best.finish) then best=r end
    if not best and slot.matchName and slot.matchName~="" and slot.timerTargetScope=="enemy" then
        -- A name alone is ambiguous (hit, interrupt, status effect, DoT).
        -- Only learn it if the game's own tooltip duration corroborates it.
        local candidate=m.byName[slot.matchName]
        local span=slot.skillDuration
        if candidate and span and span>1500 and math.abs(candidate.duration-span)<=math.max(500,span*.15) then best=candidate end
    end
    return best
end
function T:CanFollowTarget(slot,probe)
    if not self.followTarget or not slot.abilityKey then return false end
    if slot.chain or slot.toggleGroup or slot.deviceParent or slot.combatTimer or slot.chargeId or slot.phaseStack or slot.groupBuffCount or slot.sharedEffect or slot.noNativeTimer then return false end
    local p=self:Policy(slot)
    if p and (p.timer=="first" or p.timer=="last") then return false end
    local primary=slot.track and slot.track[1]
    if primary and primary.mode=="cast" then return false end
    if slot.timerTargetScope=="self" and not (slot.customTimer and primary and primary.mode~="off") then return false end
    if groundTimer(slot) and not (slot.customTimer and primary and primary.mode~="off") then return false end
    if areaProbe(slot) then return probe==true or self.targetLearn[slot.abilityKey]~=nil end
    -- An unconfigured area/ground/ally skill keeps its native timer. Its
    -- secondary enemy effect is not evidence of the cast's own duration.
    if slot.timerTargetScope=="other" and not (primary and primary.mode~="off") and not (slot.targetEffect and slot.targetEffect~=slot.abilityId) then return false end
    return true
end
local function cacheTargetTimer(self,slot,retVer,key,kind,finish,duration)
    slot.ttRetVer=retVer; slot.ttKey=key; slot.ttSkillDur=slot.skillDuration
    slot.ttTrack=slot.track
    slot.ttRetHostile=self.retHostile; slot.ttKeepLast=self.keepLastTarget; slot.ttFollow=self.followTarget
    slot.ttKind=kind; slot.ttFinish=finish; slot.ttDuration=duration
end
function T:TargetTimer(slot,now)
    local retVer=self.retVersion or 1
    local key=slot.abilityKey
    if slot.ttRetVer==retVer and slot.ttKey==key and slot.ttSkillDur==slot.skillDuration
        and slot.ttTrack==slot.track
        and slot.ttRetHostile==self.retHostile and slot.ttKeepLast==self.keepLastTarget and slot.ttFollow==self.followTarget then
        local kind=slot.ttKind
        if kind=="match" or kind=="last" then return math.max(0,slot.ttFinish-now),slot.ttDuration end
        if kind=="zero" then return 0,0 end
        return nil
    end
    local learned=key and self.targetLearn[key] or nil
    if not self.retHostile and not (key and self.lastTarget[key]) then
        cacheTargetTimer(self,slot,retVer,key,"none",0,0)
        return nil
    end
    if not self:CanFollowTarget(slot,true) then
        cacheTargetTimer(self,slot,retVer,key,"none",0,0)
        return nil
    end
    if self.retHostile then
        local r=self:MatchReticle(slot)
        if r then
            if learned~=r.id then
                self.targetLearn[key]=r.id
                self.targetRev=(self.targetRev or 0)+1
                self.retVersion=(self.retVersion or 0)+1
                retVer=self.retVersion
                if areaProbe(slot) and self.targetsEnabled then
                    -- Subscribe only to positively identified IDs; no broad
                    -- combat listener or extra periodic scan for learned DoTs.
                    self.requested[r.id]=true
                    self.targetWanted=self.targetWanted or {}; self.targetWanted[r.id]=true
                    self:RegisterWatchedEffect(r.id)
                end
            end
            local last=self.lastTarget[key] or {}; self.lastTarget[key]=last
            last.finish,last.duration=r.finish,r.duration
            cacheTargetTimer(self,slot,retVer,key,"match",r.finish,r.duration)
            return math.max(0,r.finish-now),r.duration
        end
        if learned then
            -- Forget the time but keep the table: switching between
            -- enemies with and without the DoT then allocates nothing.
            local last=self.lastTarget[key] or {}; self.lastTarget[key]=last
            last.finish=0; last.duration=0
            cacheTargetTimer(self,slot,retVer,key,"zero",0,0)
            return 0,0
        end
        cacheTargetTimer(self,slot,retVer,key,"none",0,0)
        return nil
    end
    -- Remembered per skill, so a slot that changed skills never shows the
    -- other skill's last target.
    local last=self.lastTarget[key]
    if self.keepLastTarget~=false and learned and last then
        -- Keep zero too. Otherwise looking away from an unaffected enemy
        -- resurrects the native timer or a different enemy's old DoT.
        cacheTargetTimer(self,slot,retVer,key,"last",last.finish,last.duration)
        return math.max(0,last.finish-now),last.duration
    end
    cacheTargetTimer(self,slot,retVer,key,"none",0,0)
    return nil
end
function T:RefreshToggleGroup(group)
    local active=false
    for _,id in ipairs(TOGGLE_GROUPS[group]) do if self.toggleBuffs[id] then active=true; break end end
    self.toggleState[group]=active
end
function T:ToggleActive(slot,index,category)
    local group=slot.toggleGroup
    if group and self.toggleObserved[group] then return self.toggleState[group]==true end
    return IsSlotToggled(index,category)==true
end

-- Banner is resolved on the active hotbar via IsSlotToggled, then shares
-- one state between every Banner variant. A short grace period preserves an
-- immediate buff event while the native toggle catches up, but old aura IDs
-- can never keep the glow on indefinitely after the native toggle turns off.
function T:SampleNativeBanner(row,category,now)
    if not row or not IsSlotToggled then return end
    for i=1,5 do
        local s=row[i]
        if s and s.toggleGroup=="banner" and T.IdentifySlot(i+2,category,nil,true)==s.abilityKey then
            local native=IsSlotToggled(i+2,category)==true
            local previous=self.bannerNative
            local oldState=self.toggleState.banner
            self.bannerNative=native
            if (previous~=nil and previous~=native) or oldState==native or now>=(self.bannerGrace or 0) then
                self.toggleObserved.banner=true; self.toggleState.banner=native; self.bannerGrace=nil
                if native then self.bannerOffConfirmed=nil elseif previous==true then self.bannerOffConfirmed=true end
                if not native and (previous~=false or oldState~=false) then for _,id in ipairs(BANNER_IDS) do self.toggleBuffs[id]=nil end end
            end
            return
        end
    end
end
function T:GetProcRule(key,id)
    local value=self.procRules[key]
    if value==false then return nil end
    return value or PROC_IDS[id]
end
function T:SetProcRule(key,value)
    if not key then return false,"No skill in that slot." end
    local id=integer(value)
    if not id then return false,"Proc effect ID must be a positive integer." end
    self.procRules[key]=id
    return true,"Proc effect saved: "..id
end
function T:ClearProcRule(key,disableDefault)
    if key then
        if disableDefault then self.procRules[key]=false else self.procRules[key]=nil end
        self.syncDirty=true
    end
end
function T:ProcActive(slot,now)
    if self.procEnabled and slot.readyEffects then
        for _,id in ipairs(slot.readyEffects) do
            local bucket=self.real[id]
            if bucket then for _,r in pairs(bucket) do if r.finish>now then return true end end end
            bucket=self.scan[id]
            if bucket then for _,r in pairs(bucket) do if r.finish>now then return true end end end
            local ready=self.readyPermanent and self.readyPermanent[id]
            if ready and next(ready) then return true end
        end
    end
    local p=self.primed
    if self.procEnabled and p and p.key==slot.abilityKey and now<p.untilTime and not p.fadeAt then return true end
    local state=self.procEnabled and slot.procEffect and self.procState[slot.procEffect]
    if state and state>now then return true end
    if state then self.procState[slot.procEffect]=nil end
    return false
end
local function cacheTargetCount(self,slot,rev,key,count,minExpiry)
    slot.tcRev=rev; slot.tcKey=key; slot.tcTargetEff=slot.targetEffect; slot.tcTrack=slot.track
    slot.tcGroupOnly=self.groupOnly; slot.tcTargetsEnabled=self.targetsEnabled; slot.tcBlacklist=self.targetBlacklist
    slot.tcCount=count; slot.tcMinExpiry=minExpiry
    return count
end
function T:TargetCount(slot,now)
    local rev=self.targetRev or 1
    local key=slot.abilityKey
    if slot.tcRev==rev and slot.tcKey==key and slot.tcTargetEff==slot.targetEffect and slot.tcTrack==slot.track
        and slot.tcGroupOnly==self.groupOnly and slot.tcTargetsEnabled==self.targetsEnabled and slot.tcBlacklist==self.targetBlacklist
        and (not slot.tcMinExpiry or now<slot.tcMinExpiry) then
        return slot.tcCount
    end
    if slot.toggleGroup=="banner" or not self.targetsEnabled or not slot.targetEffect then return cacheTargetCount(self,slot,rev,key,0,nil) end
    -- A ground instance has a duration, not a number of victims. Preserve
    -- intentional overrides and explicit friendly recipient displays.
    if groundTimer(slot) and not slot.customTimer and not slot.groupBuffCount then return cacheTargetCount(self,slot,rev,key,0,nil) end
    local targetId=areaProbe(slot) and self.targetLearn[key] or slot.targetEffect
    if self.targetBlacklist[key] or self.targetBlacklist[slot.visualKey] or self.targetBlacklist[slot.targetEffect] or (slot.recipientEffect and self.targetBlacklist[slot.recipientEffect]) then return cacheTargetCount(self,slot,rev,key,0,nil) end
    if self.targetBlacklist[targetId] then return cacheTargetCount(self,slot,rev,key,0,nil) end
    local minExpiry=nil
    if slot.recipientAliases then
        -- Union direct morph records and attributed stat-buff records.
        -- No temporary recipient table allocated on the HUD tick.
        local buckets=self.sharedRecords[key]
        -- Freedom's shared Minor Protection is personal, so never count
        -- its timer as a group Minor Resolve recipient.
        local direct=not slot.sharedEffect and self.real[slot.targetEffect] or nil
        local n=0
        local groupOnly=self.groupOnly
        if direct then for _,r in pairs(direct) do
            if r.finish>now and r.isTarget then
                if not minExpiry or r.finish<minExpiry then minExpiry=r.finish end
                if not groupOnly or self:IsGroupRecipient(r) then n=n+1 end
            end
        end end
        if buckets then for i,id in ipairs(slot.recipientAliases) do
            local bucket=buckets[id]
            if bucket then for rkey,r in pairs(bucket) do
                if r.finish>now and r.isTarget then
                    if not minExpiry or r.finish<minExpiry then minExpiry=r.finish end
                    if self:IsGroupRecipient(r) then
                        local previous=direct and direct[rkey]
                        local seen=previous and previous.finish>now and previous.isTarget
                        if not seen then for j=1,i-1 do
                            local earlier=buckets[slot.recipientAliases[j]]
                            local old=earlier and earlier[rkey]
                            if old and old.finish>now and old.isTarget then seen=true; break end
                        end end
                        if not seen then n=n+1 end
                    end
                end
            end end
        end end
        return cacheTargetCount(self,slot,rev,key,n,minExpiry)
    end
    local follow=BUILTIN.nextPhase[targetId]
    local bucket
    if slot.recipientEffect or slot.sharedEffect then
        local records=self.sharedRecords[key]
        bucket=records and records[slot.recipientEffect or slot.sharedEffect]
    else bucket=(follow and self.real[follow]) or self.real[targetId] end
    if not bucket and not (slot.recipientEffect and not slot.sharedEffect) then return cacheTargetCount(self,slot,rev,key,0,nil) end
    local n=0
    local groupOnly=self.groupOnly
    if bucket then
        for k,r in pairs(bucket) do
            if r.finish<=now then bucket[k]=nil
            elseif r.isTarget then
                if not minExpiry or r.finish<minExpiry then minExpiry=r.finish end
                if not groupOnly or r.isDebuff or self:IsGroupRecipient(r) then n=n+1 end
            end
        end
    end
    -- A unique primary effect and a shared recipient effect may both
    -- report a member. Deduplicate the recipients of both.
    if slot.recipientEffect and not slot.sharedEffect and slot.targetEffect~=slot.recipientEffect then
        local direct=self.real[slot.targetEffect]
        if direct then for k,r in pairs(direct) do
            if r.finish<=now then direct[k]=nil
            elseif r.isTarget then
                if not minExpiry or r.finish<minExpiry then minExpiry=r.finish end
                if (not groupOnly or r.isDebuff or self:IsGroupRecipient(r)) and not (bucket and bucket[k] and bucket[k].isTarget) then n=n+1 end
            end
        end end
    end
    return cacheTargetCount(self,slot,rev,key,n,minExpiry)
end

function T:ClearEstimate(effectId)
    for key,entries in pairs(self.bindings) do
        for _,rule in ipairs(entries) do
            if rule.effect==effectId and rule.mode=="auto" and self.fallback[key] then
                self.fallback[key][effectId]=nil
            end
        end
    end
end

local function targetKey(unitId,unitTag,unitName,effectSlot)
    if unitId and unitId>0 then return "id:"..unitId end
    if unitTag and unitTag~="" then return "tag:"..unitTag..":"..tostring(unitName or "")..":"..tostring(effectSlot or 0) end
    return "unknown:"..tostring(unitName or "")..":"..tostring(effectSlot or 0)
end

local function recordFields(beginTime,endTime,gameNow,frameNow)
    gameNow=gameNow or GetGameTimeSeconds()
    if type(endTime)~="number" or endTime<=gameNow then return nil end
    local left=(endTime-gameNow)*1000
    local span=(endTime-(beginTime or gameNow))*1000
    -- The server's begin time can sit slightly ahead of the client clock.
    -- Keep the effect's own length for such a small offset, so the countdown
    -- opens on its nominal number; a genuinely longer remainder still wins.
    local duration=span
    if span<=0 or left-span>500 then duration=math.max(left,span) end
    return (frameNow or GetFrameTimeMilliseconds())+left,duration,endTime,type(beginTime)=="number" and beginTime or nil
end

local function record(beginTime,endTime,stackCount,gameNow,frameNow)
    local finish,duration,gameEnd,gameBegin=recordFields(beginTime,endTime,gameNow,frameNow)
    if not finish then return nil end
    return {finish=finish,duration=duration,stacks=stackCount or 0,gameEnd=gameEnd,gameBegin=gameBegin}
end
-- True for a gain/update that belongs to an older application than the one
-- held (game times oldBegin/oldEnd): it ends earlier and did not start later.
-- Such a delayed event must not shorten a refreshed timer or lower stacks.
local function olderApplication(oldBegin,oldEnd,beginTime,endTime)
    return type(oldEnd)=="number" and type(endTime)=="number" and endTime>0 and endTime<oldEnd-.05 and
        (type(beginTime)~="number" or type(oldBegin)~="number" or beginTime<=oldBegin+.05)
end

-- Shared effects are attached only to the most recent matching successful
-- cast. Refreshes from unrelated skills must not extend that skill's timer.
function T:RefreshGroupNames()
    self.targetRev=(self.targetRev or 0)+1
    self.groupRosterKnown=false
    self.groupAliases=nil; self.playerDisplayName=nil
    if not self.enabled or (not self.groupOnly and not self.groupBuffWanted and (not self.sharedWanted or not next(self.sharedWanted))) then self.groupNames=nil; self.playerName=nil; return end
    self.groupNames={}
    if not GetUnitName then return end
    self.playerName=unitNameKey(GetUnitName("player"))
    self.playerDisplayName=GetUnitDisplayName and unitNameKey(GetUnitDisplayName("player")) or ""
    if not GetGroupSize or not GetGroupUnitTagByIndex then return end
    self.groupRosterKnown=true
    self.groupAliases={}
    for i=1,GetGroupSize() do
        local tag=GetGroupUnitTagByIndex(i)
        if tag and tag~="" then
            local name=unitNameKey(GetUnitName(tag))
            if name=="" then self.groupRosterKnown=false end
            if name~="" and name~=self.playerName then
                self.groupNames[name]=true
                local display=GetUnitDisplayName and unitNameKey(GetUnitDisplayName(tag)) or ""
                if display~="" and display~=self.playerDisplayName then self.groupAliases[display]=name end
            end
        else self.groupRosterKnown=false end
    end
end
function T:IsGroupRecipient(r)
    if self.groupRosterKnown and r.groupName and r.groupName~="" then return self.groupNames and self.groupNames[r.groupName] or false end
    return r.isGroup
end
local function groupBuffIdentity(self,id,unitTag,unitName)
    if not BUILTIN.groupBuffEffects[id] or unitTag=="player" then return nil end
    local name=unitNameKey(unitName)
    if name~="" and name==self.playerDisplayName then return nil end
    if self.groupAliases and self.groupAliases[name] then name=self.groupAliases[name] end
    local tagged=unitTag and unitTag:match("^group%d+$")~=nil
    if not tagged and not (self.groupNames and self.groupNames[name]) then return nil end
    if self.playerName and self.playerName~="" and name==self.playerName then return nil end
    if tagged and AreUnitsEqual and AreUnitsEqual("player",unitTag) then return nil end
    -- A native recipient name survives a group-tag change, even while the
    -- roster is incomplete. Do not switch a named recipient to a tag key
    -- just because the roster has not caught up with the effect event.
    if self.groupNames and self.groupNames[name] then return "name:"..name,name end
    if tagged then
        local rosterName=GetUnitName and unitNameKey(GetUnitName(unitTag)) or ""
        if rosterName~="" and rosterName==self.playerName then return nil end
        if rosterName~="" then return "name:"..rosterName,rosterName end
        if name~="" then return "name:"..name,name end
        return "group:"..unitTag,name
    end
    return "name:"..name,name
end
function T:ObserveShared(change,id,key,beginTime,endTime,unitTag,unitId,debuff,abilityType,unitName)
    if not self.sharedWanted or not self.sharedWanted[id] then return end
    if change==EFFECT_RESULT_FADED then
        local removed=false
        for _,byEffect in pairs(self.sharedRecords) do
            local bucket=byEffect[id]; local old=bucket and bucket[key]
            if old and (not endTime or endTime==0 or endTime>=old.gameEnd-.05) then bucket[key]=nil; removed=true end
        end
        if removed then self.targetRev=(self.targetRev or 0)+1 end
        return
    elseif change~=EFFECT_RESULT_GAINED and change~=EFFECT_RESULT_UPDATED then
        return
    end
    local cast=self.sharedCast[id]
    if not cast or GetFrameTimeMilliseconds()>cast.untilTime then return end
    local finish,duration,gameEnd,gameBegin=recordFields(beginTime,endTime)
    if not finish then return end
    local byEffect=self.sharedRecords[cast.key] or {}; self.sharedRecords[cast.key]=byEffect
    local bucket=byEffect[id] or {}; byEffect[id]=bucket
    local name=unitNameKey(unitName)
    local ally=cast.recipient and ((unitTag and unitTag:match("^group%d+$")~=nil) or (self.groupNames and self.groupNames[name]))
    if self.playerName and self.playerName~="" and name==self.playerName then ally=false end
    if ally and AreUnitsEqual and AreUnitsEqual("player",unitTag) then ally=false end
    local groupIdentity,groupName=groupBuffIdentity(self,id,unitTag,unitName)
    if cast.recipient and BUILTIN.groupBuffEffects[id] then ally=groupIdentity~=nil; name=groupName or name end
    if ABILITY_TYPE_AREAEFFECT and abilityType==ABILITY_TYPE_AREAEFFECT and not groupIdentity then ally=false end
    -- Keep timer observations for self or hostile targets, but only count
    -- group members for recipient rules. Never count the caster as an ally.
    if cast.recipient and unitTag~="player" and not ally then return end
    -- A delayed update of an older application keeps the newer timer.
    local old=bucket[key]
    if old and olderApplication(old.gameBegin,old.gameEnd,gameBegin,gameEnd) then return end
    local isTarget=((unitId and unitId>0) or groupIdentity~=nil) and unitTag~="player" and (ally or (not cast.recipient and debuff)) or false
    if old then
        old.finish=finish; old.duration=duration; old.gameEnd=gameEnd; old.gameBegin=gameBegin
        old.stacks=0; old.isGroup=ally; old.isDebuff=debuff; old.groupName=name; old.isTarget=isTarget
    else
        bucket[key]={finish=finish,duration=duration,gameEnd=gameEnd,gameBegin=gameBegin,stacks=0,
            isGroup=ally,isDebuff=debuff,groupName=name,isTarget=isTarget}
    end
    self.targetRev=(self.targetRev or 0)+1
end

function T:OnDeviceEffect(parent,id,change,effectSlot,beginTime,endTime)
    self.deviceState=self.deviceState or {}
    local state=self.deviceState[parent]
    local isParent=id==parent and BUILTIN.devices[parent][1]~=parent
    if not state then state={}; self.deviceState[parent]=state end
    if isParent then
        if change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED then
            local r=record(beginTime,endTime,0)
            local old=state.parent
            if r and not (old and olderApplication(old.gameBegin,old.gameEnd,beginTime,endTime)) then
                if old and r.gameBegin and old.gameBegin and r.gameBegin>old.gameBegin+.3 then
                    for k,child in pairs(state) do
                        if k~="parent" and child.gameBegin and child.gameBegin<r.gameBegin-.3 then state[k]=nil end
                    end
                end
                state.parent=r
            end
        elseif change==EFFECT_RESULT_FADED then
            local old=state.parent
            if old and endTime and endTime>0 and endTime<old.gameEnd-.05 then return end
            if old and (not endTime or endTime==0) and old.gameBegin and GetGameTimeSeconds()-old.gameBegin<.3 then return end
            if old then
                for k,child in pairs(state) do
                    if k~="parent" and child.gameBegin and old.gameBegin and child.gameBegin<=old.gameBegin+.3 then state[k]=nil end
                end
            end
            state.parent=nil
        end
        return
    end
    -- Mines have unique child IDs. Frozen Gates use the same ability ID for
    -- each placed device, so the engine's instance slot distinguishes them.
    local key=id==parent and tostring(effectSlot or 0) or id
    local prior=state[key]
    if change==EFFECT_RESULT_FADED then
        if prior and (not endTime or endTime==0 or endTime>=prior.gameEnd-.05) then state[key]=nil end
    elseif (change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED) and (id~=parent or BUILTIN.devices[parent][1]==parent) then
        local r=record(beginTime,endTime,0)
        if r and not (prior and olderApplication(prior.gameBegin,prior.gameEnd,beginTime,endTime)) then state[key]=r end
    end
end

function T:DeviceState(slot,now)
    local state=self.deviceState and self.deviceState[slot.deviceParent]
    if not state then return nil end
    local count,best=0,nil
    local soonest=self:Soonest(slot)
    for key,r in pairs(state) do
        if r.finish<=now then state[key]=nil
        elseif key~="parent" then count=count+1; if not best or (soonest and r.finish<best.finish) or (not soonest and r.finish>best.finish) then best=r end end
    end
    best=best or state.parent
    return count,best and best.finish-now or 0,best and best.duration or 0
end

function T:OnEffect(_,change,effectSlot,_,unitTag,beginTime,endTime,stackCount,_,buffType,effectType,abilityType,_,unitName,unitId,effectId,sourceType)
    if not self.enabled or not self.watched[effectId] then return end
    if self.targetStackWanted and self.targetStackWanted[effectId] and (effectId==52790 or not sourceType or sourceType==COMBAT_UNIT_TYPE_PLAYER) then
        -- Do not publish a different enemy's stack count. The reticle
        -- snapshot is refreshed once for the exact tracked effect event.
        -- Keep the first scheduled time: a stream of events (other enemies,
        -- other tanks) must not postpone the re-read indefinitely.
        self.reticleStackRecovery=self.reticleStackRecovery or GetFrameTimeMilliseconds()+100
        if unitTag=="reticleover" then
            self.reticleStacks=self.reticleStacks or {}
            self.reticleStacks[effectId]=change==EFFECT_RESULT_FADED and 0 or tonumber(stackCount) or 0
        end
        if effectId==52790 then return end -- external taunt counter, not our duration
    end
    local authoritative=BUILTIN.authoritativeStacks[effectId] and self.stackWanted[effectId]
    if authoritative and unitTag~="player" then return end
    if sourceType and COMBAT_UNIT_TYPE_PLAYER and sourceType~=COMBAT_UNIT_TYPE_PLAYER and not (authoritative and unitTag=="player" and unknownSource(sourceType)) then return end
    -- Our own copy of this effect arrived: a cast expecting it needs no
    -- recovery scan for it.
    if change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED then
        local seen=self.effectAt or {}; self.effectAt=seen
        seen[effectId]=GetFrameTimeMilliseconds()
        local pending=self.recoveryPending
        if pending then pending[effectId]=nil end
    end
    -- Permanent stack effects have no timed record to compare against on
    -- fade. Remember the observed application start independently, so a
    -- delayed old fade cannot erase a newly gained Blood Hunger/Crux/etc.
    if authoritative and type(beginTime)=="number" and beginTime>0 then
        local known=self.stackGame[effectId]
        if known and beginTime<known-.05 then return end
        if (change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED) and (not known or beginTime>known) then
            self.stackGame[effectId]=beginTime
        end
    end
    if self.primeWanted and self.primeWanted[effectId] and unitTag=="player" then self:ObservePrime(change,endTime) end
    if self.reticleWanted and self.reticleWanted[effectId] and unitTag~="reticleover" and unitTag~="player" and (not unitTag or unitTag=="") then
        -- Some enemy events omit a unit tag. Recover the selected reticle
        -- once, without scanning other enemies or adding an update loop.
        self.reticleStackRecovery=self.reticleStackRecovery or GetFrameTimeMilliseconds()+100
    end
    local chargeParent=self.chargeWanted and self.chargeWanted[effectId]
    if chargeParent then
        local now=GetFrameTimeMilliseconds()
        local state=self.chargeState[chargeParent]
        if BUILTIN.chargeTrigger[effectId] then
            if change==EFFECT_RESULT_GAINED and state and state.count>0 and (not state.hit or now-state.hit>500) then
                state.count=state.count-1; state.hit=now
            end
            return
        elseif chargeParent==46331 then
            if unitTag~="player" then return end
            if change==EFFECT_RESULT_FADED then
                if not state or not state.gameBegin or not beginTime or beginTime==0 or beginTime>=state.gameBegin-.05 then
                    self.chargeState[chargeParent]={count=0,finish=now,gameBegin=state and state.gameBegin or beginTime}
                end
            elseif change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED then
                local count=tonumber(stackCount) or 0
                local left=type(endTime)=="number" and (endTime-GetGameTimeSeconds())*1000 or 0
                local span=type(beginTime)=="number" and type(endTime)=="number" and (endTime-beginTime)*1000 or 0
                local fresh=not state or change==EFFECT_RESULT_GAINED and
                    (not state.gameBegin or beginTime and beginTime>state.gameBegin+.05)
                if state and state.gameBegin and beginTime and beginTime>0 and beginTime<state.gameBegin-.05 then return end
                if left>0 then
                    if fresh then
                        state={count=count>0 and count or BUILTIN.chargeSkills[46331],finish=now+left,duration=span>0 and span or 6000,
                            gameBegin=beginTime,eventAt=now,gainAt=change==EFFECT_RESULT_GAINED and now or nil}
                    else
                        if count>0 and count<state.count then state.hit=now; state.count=count end
                        state.finish=now+left; state.duration=span>0 and span or state.duration
                        state.gameBegin=beginTime; state.eventAt=now
                    end
                    self.chargeState[chargeParent]=state
                end
            end
        elseif BUILTIN.trapEffects[chargeParent] then
            if effectId==BUILTIN.trapEffects[chargeParent] and change==EFFECT_RESULT_GAINED then self.chargeState[chargeParent]={count=0}
            elseif effectId==chargeParent and change==EFFECT_RESULT_GAINED then self.chargeState[chargeParent]={count=1}
            elseif effectId==chargeParent and change==EFFECT_RESULT_FADED then self.chargeState[chargeParent]={count=0} end
        elseif change==EFFECT_RESULT_FADED then self.chargeState[chargeParent]={count=0}
        elseif change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED then
            local count=tonumber(stackCount) or 0
            local finish=type(endTime)=="number" and endTime>GetGameTimeSeconds() and now+(endTime-GetGameTimeSeconds())*1000 or nil
            if count>0 then self.chargeState[chargeParent]={count=count,finish=finish}
            elseif change==EFFECT_RESULT_GAINED and not state then self.chargeState[chargeParent]={count=BUILTIN.chargeSkills[chargeParent] or 0} end
        end
    end
    local deviceParent=self.deviceWanted and self.deviceWanted[effectId]
    if deviceParent then self:OnDeviceEffect(deviceParent,effectId,change,effectSlot,beginTime,endTime); return end
    local gained=change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED
    local group=self.toggleWanted[effectId]
    if group and unitTag=="player" then
        -- Toggles have no end time. An event of an earlier activation (older
        -- start) arrives late and must neither switch the current one off
        -- nor bring a switched-off one back.
        local known=self.toggleGame[effectId]
        local started=type(beginTime)=="number" and beginTime>0 and beginTime or nil
        if known and started and started<known-.05 then return end
        if started and (not known or started>known) then self.toggleGame[effectId]=started end
        if change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED or change==EFFECT_RESULT_FADED then
            self.toggleBuffs[effectId]=change~=EFFECT_RESULT_FADED or nil
            if group=="banner" then
                -- A fade is an off signal for the shared Banner activation,
                -- not just one member of an OR of potentially stale aura IDs.
                -- A stale UPDATED event must not resurrect an off Banner.
                if not (gained and self.bannerOffConfirmed) and (change~=EFFECT_RESULT_UPDATED or self.toggleState.banner or self.bannerNative==nil) then
                    self.toggleObserved.banner=true; self.toggleState.banner=gained
                    self.bannerGrace=GetFrameTimeMilliseconds()+300
                    if not gained then for _,id in ipairs(BANNER_IDS) do self.toggleBuffs[id]=nil end end
                end
            else
                self.toggleRetry[group]=nil
                self.toggleObserved[group]=true; self:RefreshToggleGroup(group)
            end
        end
    end
    if self.procWanted[effectId] and unitTag=="player" then
        local known=self.procGame[effectId]
        local older=known and type(endTime)=="number" and endTime>0 and endTime<known.finish-.05 and
            (type(beginTime)~="number" or not known.begin or beginTime<=known.begin+.05)
        if change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED then
            if not older then
                local left=type(endTime)=="number" and endTime-GetGameTimeSeconds() or 0
                self.procState[effectId]=left>0 and GetFrameTimeMilliseconds()+left*1000 or
                    ((not endTime or endTime==0) and math.huge or nil)
                if type(endTime)=="number" and endTime>0 then
                    local pg=known or {}
                    pg.finish=endTime; pg.begin=type(beginTime)=="number" and beginTime or nil
                    self.procGame[effectId]=pg
                else
                    self.procGame[effectId]=nil
                end
            end
        elseif change==EFFECT_RESULT_FADED and not older then self.procState[effectId]=nil; self.procGame[effectId]=nil end
    end
    local groupIdentity,groupName=groupBuffIdentity(self,effectId,unitTag,unitName)
    -- A confirmed group member is not a ground-area object. Use a stable
    -- key even when the engine reports a missing/zero runtime unit ID.
    local key=authoritative and "player" or groupIdentity or targetKey(unitId,unitTag,unitName,effectSlot)
    if self.readyWanted and self.readyWanted[effectId] then
        self.readyPermanent=self.readyPermanent or {}
        local bucket=self.readyPermanent[effectId] or {}; self.readyPermanent[effectId]=bucket
        if gained and (not endTime or endTime==0) then bucket[key]=true
        else bucket[key]=nil end
    end
    if self.sharedWanted and self.sharedWanted[effectId] then
        local debuff=BUFF_EFFECT_TYPE_DEBUFF and (effectType==BUFF_EFFECT_TYPE_DEBUFF or buffType==BUFF_EFFECT_TYPE_DEBUFF)
        self:ObserveShared(change,effectId,key,beginTime,endTime,unitTag,unitId,debuff,abilityType,unitName)
    end
    local bucket=self.real[effectId] or {}; self.real[effectId]=bucket
    local prior=bucket[key]
    -- Ignore delayed fades for a refreshed effect before touching its stacks.
    if change==EFFECT_RESULT_FADED and prior and endTime and endTime~=0 and endTime<prior.gameEnd-.05 then return end
    -- A delayed gain/update of an older application must not shorten the
    -- current timer or lower its stacks.
    if gained and prior and olderApplication(prior.gameBegin,prior.gameEnd,beginTime,endTime) then return end
    -- A watched debuff update can arrive without a unit tag. When the
    -- selected reticle already has that effect, invalidate its snapshot;
    -- never assign the tagless event's end time to the selected enemy.
    if self.followTarget and (gained or change==EFFECT_RESULT_FADED) and sourceType==COMBAT_UNIT_TYPE_PLAYER and (not unitTag or unitTag=="") and self.retHostile and self.retMine and self.retMine.byId[effectId] then
        local slots=self.followExact and self.followExact[effectId]
        if slots then for _,slot in ipairs(slots) do
            if self.targetLearn[slot.abilityKey]==effectId and self:CanFollowTarget(slot,false) then self.retDirty=true; break end
        end end
    end
    if self.stackWanted[effectId] then
        local count=tonumber(stackCount) or 0
        if authoritative and (gained or change==EFFECT_RESULT_FADED) then
            self.stackSeen[effectId]=true
            self.permanentStacks[effectId]=gained and count or 0
            self.snapshotStacks[effectId]=nil
            if not self.stackEventAt then self.stackEventAt={} end
            self.stackEventAt[effectId]=GetFrameTimeMilliseconds()
        end
        if gained and count>0 then
            self.stackSeen[effectId]=true; self.stackZeroUntil[effectId]=nil
            if unitTag=="player" then
                self.permanentStacks[effectId]=(not endTime or endTime<=GetGameTimeSeconds()) and count or nil
                self.snapshotStacks[effectId]=nil
            end
        elseif change==EFFECT_RESULT_FADED or (change==EFFECT_RESULT_UPDATED and self.stackSeen[effectId] and count==0) then
            -- A real reset wins over a stale native count briefly, not for
            -- the rest of the session. Unrelated zero-stack gain events
            -- must never shut down native stack tracking permanently.
            self.stackZeroUntil[effectId]=GetFrameTimeMilliseconds()+350
            if unitTag=="player" then self.permanentStacks[effectId]=authoritative and 0 or nil; self.snapshotStacks[effectId]=nil end
            if authoritative then
                self.real[effectId]={}; bucket=self.real[effectId]
                self.scan[effectId]=nil
                self.targetRev=(self.targetRev or 0)+1
            end
            if self.scan[effectId] then
                if self.scan[effectId][unitTag]~=nil then self.targetRev=(self.targetRev or 0)+1 end
                self.scan[effectId][unitTag]=nil
            end
        end
    end
    if gained then
        local phase=BUILTIN.phaseInfo[effectId]
        local fixed=BUILTIN.fixedObservedDuration[effectId]
        local recBegin,recEnd,recStacks=beginTime,endTime,phase and phase.count or stackCount
        if fixed and abilityType==ABILITY_TYPE_AREAEFFECT then
            local clock=GetGameTimeSeconds()
            local started=type(beginTime)=="number" and beginTime>0 and beginTime or clock
            recBegin,recEnd,recStacks=started,started+fixed,stackCount
        elseif phase then
            local clock=GetGameTimeSeconds()
            local started=type(beginTime)=="number" and beginTime>0 and beginTime or clock
            recBegin,recEnd,recStacks=started,started+phase.duration,phase.count
            -- A delayed first-phase update must not undo the second proc.
            local second=BUILTIN.nextPhase[effectId]
            local later=second and self.real[second] and self.real[second][key]
            if later and later.gameBegin and started<=later.gameBegin then return end
            local first=BUILTIN.previousPhase[effectId]
            local newer=first and self.real[first] and self.real[first][key]
            if newer and newer.gameBegin and started<newer.gameBegin then return end
        end
        local finish,duration,gameEnd,gameBegin=recordFields(recBegin,recEnd)
        if finish then
            -- Only trustworthy, unique runtime unit IDs contribute to counts.
            -- Selected AoE heals count other recipients (not the caster).
            -- All other buffs, reticle snapshots and estimates are excluded.
            local debuff=BUFF_EFFECT_TYPE_DEBUFF and (effectType==BUFF_EFFECT_TYPE_DEBUFF or buffType==BUFF_EFFECT_TYPE_DEBUFF)
            local ally=ALLY_COUNT_EFFECTS[effectId]
            -- For any other slotted effect, count a real, identified friendly
            -- player rather than requiring a hard-coded heal ID. Unknown
            -- unit tags are accepted only for the audited recipient IDs.
            if not ally and self.targetWanted and self.targetWanted[effectId] and unitTag and unitTag~="" and unitTag~="player" and not debuff then
                local friendlyPlayer=unitTag:match("^group%d+$")~=nil or
                    (IsUnitPlayer and DoesUnitExist and DoesUnitExist(unitTag) and IsUnitPlayer(unitTag) and (not IsUnitAttackable or not IsUnitAttackable(unitTag)))
                ally=friendlyPlayer and not isSelfTargetEffect(effectId)
            end
            if groupIdentity and not debuff then ally=true end
            if ABILITY_TYPE_AREAEFFECT and abilityType==ABILITY_TYPE_AREAEFFECT and not groupIdentity then ally=false end
            if ally and not groupIdentity and unitTag and unitTag~="" and IsUnitPlayer and DoesUnitExist and DoesUnitExist(unitTag) and not IsUnitPlayer(unitTag) then ally=false end
            if ally and unitTag and unitTag~="" and AreUnitsEqual and AreUnitsEqual("player",unitTag) then ally=false end
            if ally and selfName(unitName) then ally=false end
            local isTarget=((unitId and unitId>0) or groupIdentity~=nil) and unitTag~="player" and
                (ally or debuff or (not BUFF_EFFECT_TYPE_DEBUFF and unitTag=="reticleover")) or false
            if BUILTIN.singleTarget[effectId] and isTarget then
                -- A transfer replaces the earlier target; a delayed fade of
                -- that earlier target must not erase the new one. A delayed
                -- update of the earlier application must not take it back.
                if gameBegin then
                    for old,o in pairs(bucket) do
                        if old~=key and o.gameBegin and o.gameBegin>gameBegin+.05 then return end
                    end
                end
                for old in pairs(bucket) do if old~=key then bucket[old]=nil end end
                self.scan[effectId]=nil
            end
            local other=BUILTIN.nextPhase[effectId] or BUILTIN.previousPhase[effectId]
            if other then self.real[other]=nil; self.scan[other]=nil; self.reticle[other]=nil end
            -- Update existing bucket[key] in-place when exclusively owned by this
            -- unit (never mutate a table aliased by self.reticle for a different tag).
            local r=(prior and (self.reticle[effectId]~=prior or unitTag=="reticleover")) and prior or {}
            r.finish=finish; r.duration=duration; r.stacks=recStacks or 0; r.gameEnd=gameEnd; r.gameBegin=gameBegin
            r.isTarget=isTarget
            r.isDebuff=debuff or (not BUFF_EFFECT_TYPE_DEBUFF and unitTag=="reticleover")
            r.isGroup=(unitTag and unitTag:match("^group%d+$")~=nil) or (self.groupNames and self.groupNames[unitNameKey(unitName)])
            r.groupName=groupName or unitNameKey(unitName)
            bucket[key]=r
            self.targetRev=(self.targetRev or 0)+1
            -- An exact own debuff gain on the hostile reticle is already
            -- proof of target ownership, even if the player aims elsewhere
            -- before our next reticle snapshot. The snapshot still decides
            -- which enemy's timer (or zero) is displayed.
            if self.followTarget and unitTag=="reticleover" and debuff and sourceType==COMBAT_UNIT_TYPE_PLAYER then
                local slots=self.followExact and self.followExact[effectId]
                if slots then
                    for _,slot in ipairs(slots) do
                        if not self.targetLearn[slot.abilityKey] and self:CanFollowTarget(slot,false)
                            and (not DoesUnitExist or DoesUnitExist(unitTag)) and (not IsUnitDead or not IsUnitDead(unitTag))
                            and (not IsUnitAttackable or IsUnitAttackable(unitTag)) then
                            self.targetLearn[slot.abilityKey]=effectId
                            self.retVersion=(self.retVersion or 0)+1
                        end
                    end
                end
            end
            if unitTag=="reticleover" and self.reticleWanted and self.reticleWanted[effectId] then self.reticle[effectId]=r end
            self.effectSeen[effectId]=true
            if BUILTIN.previousPhase[effectId] then self.effectSeen[BUILTIN.previousPhase[effectId]]=true end
            self.phaseSeen[effectId]=true
            -- Real observations supersede any estimates for this effect.
            self:ClearEstimate(effectId)
        end
    elseif change==EFFECT_RESULT_FADED then
        local mutated=false
        if prior then bucket[key]=nil; mutated=true end
        self.effectSeen[effectId]=true
        local rr=self.reticle[effectId]
        if unitTag=="reticleover" and rr and (not endTime or endTime==0 or endTime>=rr.gameEnd-.05) then self.reticle[effectId]=nil; mutated=true end
        -- A reticle snapshot can otherwise outlive an observed early fade.
        if self.scan[effectId] then
            local snapshot=self.scan[effectId][unitTag]
            if snapshot and (not endTime or endTime==0 or endTime>=snapshot.gameEnd-.05) then self.scan[effectId][unitTag]=nil; mutated=true end
        end
        if mutated then self.targetRev=(self.targetRev or 0)+1 end
        -- If no matching observed gain, still stop an estimate for a known fade.
        self:ClearEstimate(effectId)
    end
end

-- Nothing Wasted: prefer actual effect counts. Some clients expose a
-- small integer on the combat gain instead of an effect stack update.
local function nwStackCount(value)
    local n=integer(value)
    return n and n<=10 and n or nil
end
function T:ClearNothingWasted()
    self.nwFinish,self.nwCount,self.nwFadeAt,self.nwObserved,self.nwRecoverAt=nil,nil,nil,nil,nil
    self.nwCountSource,self.nwCountAt,self.nwGameEnd,self.nwGainAt,self.nwGameBegin=nil,nil,nil,nil,nil
end
function T:ObserveNothingWasted(beginTime,endTime,count,snapshot)
    local now,gameNow=GetFrameTimeMilliseconds(),GetGameTimeSeconds()
    local actual=nwStackCount(count)
    local changed=actual and self.nwCount and actual~=self.nwCount
    if actual then
        self.nwCount,self.nwCountSource,self.nwCountAt=actual,snapshot and "snapshot" or "effect",now
    elseif snapshot then return end
    -- Zero on a hidden-effect gain/update is often absent stack metadata,
    -- not a fade. Only actual fade or expiry should remove a live count.
    self.nwFadeAt=nil
    local left=type(endTime)=="number" and (endTime-gameNow)*1000 or 0
    if not snapshot then self.nwGainAt=now end
    if left>0 and left<=NW_DURATION+500 then
        self.nwFinish=now+left; self.nwObserved=true; self.nwGameEnd=endTime
        self.nwGameBegin=type(beginTime)=="number" and beginTime or nil
    elseif not snapshot then
        self.nwFinish=now+NW_DURATION; self.nwObserved=true
    elseif not self.nwObserved and type(beginTime)=="number" and beginTime>0 then
        local age=(gameNow-beginTime)*1000
        if age>=0 and age<NW_DURATION then self.nwFinish=now+NW_DURATION-age; self.nwObserved=true end
    end
    if snapshot and actual and (not self.nwFinish or (changed and left<=0)) then self.nwFinish=now+NW_DURATION; self.nwObserved=true end
end
function T:OnNWCombat(_,result,isError,_,_,_,sourceName,sourceType,targetName,targetType,hitValue,_,_,_,_,_,ability)
    if not self.nwListening or isError or ability~=NW_ID then return end
    local selfTarget=targetType==COMBAT_UNIT_TYPE_PLAYER or selfName(targetName)
    local ownSource=sourceType==COMBAT_UNIT_TYPE_PLAYER or selfName(sourceName)
    if not ownSource and not (unknownSource(sourceType) and selfTarget) then return end
    if not selfTarget and not (ownSource and unknownSource(targetType)) then return end
    local now=GetFrameTimeMilliseconds()
    if result==ACTION_RESULT_EFFECT_FADED then
        -- A fade right after a new gain belongs to the replaced application.
        if not (self.nwGainAt and now-self.nwGainAt<400) then self.nwFadeAt=now+200 end
    elseif result~=nil then
        -- Any successful combat result counts for
        -- this exact hidden passive ID, including its refresh/decay events.
        self.nwFadeAt=nil; self.nwFinish=now+NW_DURATION; self.nwObserved=true; self.nwGainAt=now
        local candidate=nwStackCount(hitValue)
        if candidate and selfTarget and
            (result==ACTION_RESULT_EFFECT_GAINED or result==ACTION_RESULT_EFFECT_GAINED_DURATION) and
            (not self.nwCountAt or self.nwCountSource=="combat" or now-self.nwCountAt>200) then
            self.nwCount,self.nwCountSource,self.nwCountAt=candidate,"combat",now
        end
        -- If the hidden buff's stack update is missing, recover once after
        -- the matched event. No periodic player buff polling.
        self.nwRecoverAt=now+150
    end
end
function T:OnNWEffect(_,change,_,_,unitTag,beginTime,endTime,count,_,_,_,_,_,unitName,_,ability,sourceType)
    if not self.nwListening or ability~=NW_ID then return end
    local namedSelf=(unitTag==nil or unitTag=="") and (selfName(unitName) or ((not unitName or unitName=="") and sourceType==COMBAT_UNIT_TYPE_PLAYER))
    if unitTag~="player" and not namedSelf then return end
    if change==EFFECT_RESULT_FADED then
        -- Ignore the delayed fade of an older application (earlier end).
        if type(endTime)=="number" and endTime>0 and self.nwGameEnd and endTime<self.nwGameEnd-.05 then return end
        self.nwFadeAt=GetFrameTimeMilliseconds()+200
    elseif change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED then
        -- A delayed update of the previous application must not roll the
        -- live count and time back (e.g. 4 stacks / 11 s to 3 / 6 s).
        if olderApplication(self.nwGameBegin,self.nwGameEnd,beginTime,endTime) then return end
        if nwStackCount(count) then self.nwRecoverAt=nil end
        -- Only a changed count / new gain restarts an inferred clock.
        -- Duplicate same-count effect updates must not extend it forever,
        -- but a real, later end time from the game is always taken.
        local gameNow=GetGameTimeSeconds()
        local newEnd=type(endTime)=="number" and endTime>gameNow and (not self.nwGameEnd or endTime>self.nwGameEnd+.05)
        if change==EFFECT_RESULT_GAINED or newEnd or (nwStackCount(count) and (count~=self.nwCount or self.nwCountSource=="combat")) or self.nwFadeAt or not self.nwFinish then
            self:ObserveNothingWasted(beginTime,endTime,count,false)
        end
    end
end
-- Subscription changes in a single Sync/SetEnabled transaction can request
-- recovery independently. Finish all registrations first and read each unit
-- once, synchronously. Standalone callers retain immediate recovery.
local function recoverUnits(self,plan,player,reticle,snapshot)
    if plan then
        if player then plan.player=true end
        if reticle then plan.reticle=true end
    else
        if player then self:ScanUnit("player",snapshot) end
        if reticle then self:ScanUnit("reticleover",snapshot) end
    end
end
function T:ReconcileNothingWasted(plan)
    local wanted=self.enabled and self.nwWanted and EVENT_COMBAT_EVENT and EVENT_EFFECT_CHANGED and
        REGISTER_FILTER_ABILITY_ID and COMBAT_UNIT_TYPE_PLAYER
    if wanted and not self.nwListening then
        self.nwListening=true
        EVENT_MANAGER:RegisterForEvent(NW_COMBAT,EVENT_COMBAT_EVENT,self.nwCombatCallback)
        EVENT_MANAGER:AddFilterForEvent(NW_COMBAT,EVENT_COMBAT_EVENT,REGISTER_FILTER_ABILITY_ID,NW_ID)
        -- Hidden buff combat events may have source NONE. Exact ability ID
        -- remains engine-filtered; verify the local source/recipient in Lua.
        EVENT_MANAGER:RegisterForEvent(NW_EFFECT,EVENT_EFFECT_CHANGED,self.nwEffectCallback)
        EVENT_MANAGER:AddFilterForEvent(NW_EFFECT,EVENT_EFFECT_CHANGED,REGISTER_FILTER_ABILITY_ID,NW_ID)
        -- Exact ID filter stays in the engine. Hidden player effects may
        -- lack a unit tag; verify their player name and source in Lua.
        recoverUnits(self,plan,true,false)
    elseif not wanted and self.nwListening then
        EVENT_MANAGER:UnregisterForEvent(NW_COMBAT,EVENT_COMBAT_EVENT)
        EVENT_MANAGER:UnregisterForEvent(NW_EFFECT,EVENT_EFFECT_CHANGED)
        self.nwListening=nil; self:ClearNothingWasted()
    end
end
function T:GetNothingWasted(slot,now)
    if not self.nwListening or not slot.nwSlot then return 0,nil end
    if self.nwFadeAt and now>=self.nwFadeAt then self:ClearNothingWasted() end
    local left=self.nwFinish and math.max(0,self.nwFinish-now) or 0
    -- Do not show an old count indefinitely if the game never supplied the
    -- next decay event. Allow a short grace for asynchronous event delivery.
    if self.nwFinish and now>self.nwFinish+250 then self:ClearNothingWasted() end
    return left,self.nwCount
end

function T:ObserveLandslide(change,beginTime,endTime,count)
    if change==EFFECT_RESULT_FADED then
        local old=self.landslide
        if not old or not endTime or endTime==0 or not old.gameEnd or endTime>=old.gameEnd-.05 then self.landslide=nil end
    elseif change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED then
        local old=self.landslide
        if old and olderApplication(old.gameBegin,old.gameEnd,beginTime,endTime) then return end
        count=tonumber(count) or 0
        if count<=0 then self.landslide=nil; return end
        local r=record(beginTime,endTime,count)
        self.landslide=r or {stacks=count,finish=math.huge}
    end
end

function T:ObservePassiveEffect(id,change,beginTime,endTime)
    local old=self.passiveEffects[id]
    if change==EFFECT_RESULT_FADED then
        -- A delayed fade belonging to the previous application must not
        -- erase a newer refresh of the same passive.
        if old and (not endTime or endTime==0 or endTime>=old.gameEnd-.05) then self.passiveEffects[id]=nil end
    elseif change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED then
        if old and olderApplication(old.gameBegin,old.gameEnd,beginTime,endTime) then return end
        local observed=record(beginTime,endTime,0)
        if observed then self.passiveEffects[id]=observed end
    end
end
function T:GetPassiveBadges(slot,now)
    if not self.enabled or not self.passiveEffects then return 0,0,0,0,nil end
    if self.vampirePassiveEnabled and slot.vampirePassiveSlot then
        local first,second=self.passiveEffects[135189],self.passiveEffects[135190]
        local best=first and second and (first.finish>=second.finish and first or second) or first or second
        return best and math.max(0,best.finish-now) or 0,best and best.duration or 0,0,0,"vampire"
    end
    local mode=self.arcanistPassiveMode
    local family=slot.arcanistPassiveSlot
    if family and (mode==family or mode=="Both") then
        local abyss,fate=self.passiveEffects[263369],self.passiveEffects[268372]
        return abyss and math.max(0,abyss.finish-now) or 0,abyss and abyss.duration or 0,
            fate and math.max(0,fate.finish-now) or 0,fate and fate.duration or 0,"arcanist"
    end
    return 0,0,0,0,nil
end
function T:OnAuxEffect(_,change,effectSlot,_,unitTag,beginTime,endTime,stacks,_,_,_,_,_,_,_,id,sourceType)
    if not self.enabled or unitTag~="player" or not self.auxWanted[id] then return end
    if self.passiveWanted[id] then self:ObservePassiveEffect(id,change,beginTime,endTime); return end
    if id==LANDSLIDE then
        -- This self-only passive cannot be applied by another player. Some
        -- passive effects report an unclassified source, so do not drop it.
        self:ObserveLandslide(change,beginTime,endTime,stacks)
        return
    end
    if sourceType==nil or sourceType==0 or sourceType==COMBAT_UNIT_TYPE_NONE or sourceType==COMBAT_UNIT_TYPE_PLAYER or sourceType==COMBAT_UNIT_TYPE_PLAYER_PET then return end
    local bucket=self.external[id] or {}; self.external[id]=bucket
    local old=bucket[effectSlot]
    if change==EFFECT_RESULT_FADED then
        if old and (not endTime or endTime==0 or endTime>=old.gameEnd-.05) then bucket[effectSlot]=nil end
    elseif change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED then
        if old and olderApplication(old.gameBegin,old.gameEnd,beginTime,endTime) then return end
        if effectSlot and effectSlot>0 then bucket[effectSlot]=record(beginTime,endTime,0) end
    end
end

function T:ReconcileAux(plan)
    local wanted=self.enabled and self.auxWanted or {}
    local changed=false
    for id,ns in pairs(self.auxWatched) do
        if not wanted[id] then
            EVENT_MANAGER:UnregisterForEvent(ns,EVENT_EFFECT_CHANGED)
            self.auxWatched[id]=nil; self.external[id]=nil; self.passiveEffects[id]=nil; changed=true
            if id==LANDSLIDE then self.landslide=nil end
        end
    end
    if not EVENT_EFFECT_CHANGED or not REGISTER_FILTER_ABILITY_ID or not REGISTER_FILTER_UNIT_TAG then return end
    for id in pairs(wanted) do
        if not self.auxWatched[id] then
            local ns="ZeraUIAuxEffect_"..id
            EVENT_MANAGER:RegisterForEvent(ns,EVENT_EFFECT_CHANGED,self.auxCallback)
            EVENT_MANAGER:AddFilterForEvent(ns,EVENT_EFFECT_CHANGED,REGISTER_FILTER_ABILITY_ID,id)
            EVENT_MANAGER:AddFilterForEvent(ns,EVENT_EFFECT_CHANGED,REGISTER_FILTER_UNIT_TAG,"player")
            self.auxWatched[id]=ns; changed=true
        end
    end
    if changed then recoverUnits(self,plan,true,false) end
end

local LANDSLIDE_TEXT,EXTERNAL_TEXT={},{}
function T:AuxCount(slot,now)
    if slot.landslideSlot and self.landslideEnabled and self.landslide and self.landslide.finish>now then
        local n=self.landslide.stacks
        local s=LANDSLIDE_TEXT[n]
        if not s then s="L:"..n; LANDSLIDE_TEXT[n]=s end
        return s
    end
    local id=slot.externalCountEffect
    if self.externalCountsEnabled and id then
        local ext=self.external[id]
        if ext then
            local count=0
            for _,r in pairs(ext) do if r.finish>now then count=count+1 end end
            if count>0 then
                local s=EXTERNAL_TEXT[count]
                if not s then s="E:"..count; EXTERNAL_TEXT[count]=s end
                return s
            end
        end
    end
    return ""
end

-- Off Balance can be reported with different effect IDs; also match the
-- localized name of the canonical ability (resolved once, on first use).
-- Used to keep Off Balance target effects free of the expiry glow.
local function offBalanceKey(name) return normalizedName(name):gsub("%^.*$","") end
function T:IsOffBalance(id,name)
    if OFF_BALANCE[id] then return true end
    if not self.offBalanceNameKey then
        local own=GetAbilityName and GetAbilityName(62988)
        own=type(own)=="string" and own~="" and own or "Off Balance"
        self.offBalanceNameKey=offBalanceKey(own)
        self.offBalanceCleanKey=offBalanceKey(zo_strformat and zo_strformat("<<1>>",own) or own)
    end
    local cache=self.offBalanceIdCache
    local known=id and cache and cache[id]
    if known and known.name==name then return known.result end
    local n=offBalanceKey(name)
    local result=n~="" and (n==self.offBalanceNameKey or n==self.offBalanceCleanKey or n=="off balance")
    -- Do not cache absent names or invalid IDs. Include the reported name so
    -- a transient or reused ID cannot poison a later valid name match.
    if type(id)=="number" and id>0 and n~="" then
        if not cache then cache={}; self.offBalanceIdCache=cache end
        cache[id]={name=name,result=result}
    end
    return result
end
-- Power Lash:
--   Active stacks (5..1->0) and remaining window are read directly from the
--   native Action Slot Effect API on EVENT_ACTION_SLOT_EFFECT_UPDATE and
--   slot bind/transform/swap-settle (mirroring ESOUI HandleSlotEffectUpdated).
--   Hidden combat event 34117 (2245/2250, targetType==PLAYER) is retained only
--   to anchor the authoritative 20 s cooldown (cdFinish/cdDuration) so early
--   5-stack consumption counts down the remaining cooldown in red instead of
--   exposing green Off Balance early. 262658 (45 s passive) is never tracked.
local function powerLashState(self)
    local state=self.chargeState[20824]
    if not state then
        state={count=0}
        self.chargeState[20824]=state
    end
    return state
end
function T:ObservePowerLashSlot(slotIndex,category,now,isActiveBar,boundId)
    local bound=boundId
    if bound==nil then bound=GetSlotBoundId and GetSlotBoundId(slotIndex,category) or 0 end
    local state=self.chargeState[20824]
    if bound~=20824 then
        -- Reverted to 20816 (final stack spent or expired): clear active
        -- charges only and preserve cdFinish/cdDuration.
        if state then state.count=0; state.finish=nil end
        return
    end
    local stacks=GetActionSlotEffectStackCount and (GetActionSlotEffectStackCount(slotIndex,category) or 0) or 0
    local remain=GetActionSlotEffectTimeRemaining and (GetActionSlotEffectTimeRemaining(slotIndex,category) or 0) or 0
    local dur=GetActionSlotEffectDuration and (GetActionSlotEffectDuration(slotIndex,category) or 0) or 0
    if remain>0 then
        -- ESOUI actionbar.lua only queries GetActionSlotEffectStackCount on
        -- the active bar; preserve a known positive count if an inactive bar
        -- reports 0 while remaining time is still >0 on bound 20824.
        if stacks==0 and not isActiveBar and state and (state.count or 0)>0 then
            stacks=state.count
        end
        if stacks>0 then
            state=powerLashState(self)
            state.count=stacks
            state.finish=now+remain
            local freshWindow=not state.cdFinish or now>=state.cdFinish or (now+remain)>state.cdFinish+1000
            if freshWindow then
                state.cdFinish=now+remain
                state.cdDuration=dur>0 and dur or 20000
            end
            state.duration=state.cdDuration or (dur>0 and dur or 20000)
            return
        end
    end
    if state then state.count=0; state.finish=nil end
end
function T:OnPowerLashCombat(_,result,isError,_,_,_,_,sourceType,_,targetType,hitValue,_,_,_,_,_,ability)
    if not self.flameListening or isError or ability~=POWER_LASH_ID or targetType~=COMBAT_UNIT_TYPE_PLAYER then return end
    local state=self.chargeState[20824]
    if result==ACTION_RESULT_EFFECT_FADED then
        if state then state.count=0; state.finish=nil end
        return
    end
    if result~=ACTION_RESULT_EFFECT_GAINED_DURATION or sourceType~=COMBAT_UNIT_TYPE_PLAYER then return end
    local now=GetFrameTimeMilliseconds()
    -- Reject duplicate GAINED_DURATION within an active 20 s window while
    -- allowing a back-to-back re-proc at the 20 s boundary despite RTT skew.
    if state and state.cdFinish and (state.cdFinish-now)>1000 then return end
    local dur=tonumber(hitValue) or 20000
    if dur<1000 or dur>60000 then dur=20000 end
    state=powerLashState(self)
    state.cdDuration=dur
    state.cdFinish=now+dur
end
function T:ReconcilePowerLash()
    local wanted=self.enabled and self.flameWanted and EVENT_COMBAT_EVENT and REGISTER_FILTER_ABILITY_ID and COMBAT_UNIT_TYPE_PLAYER
    if wanted and not self.flameListening then
        self.flameListening=true
        EVENT_MANAGER:RegisterForEvent(POWER_LASH_COMBAT,EVENT_COMBAT_EVENT,self.powerLashCallback)
        EVENT_MANAGER:AddFilterForEvent(POWER_LASH_COMBAT,EVENT_COMBAT_EVENT,REGISTER_FILTER_ABILITY_ID,POWER_LASH_ID)
        if REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE then
            EVENT_MANAGER:AddFilterForEvent(POWER_LASH_COMBAT,EVENT_COMBAT_EVENT,REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
        end
    elseif not wanted and self.flameListening then
        EVENT_MANAGER:UnregisterForEvent(POWER_LASH_COMBAT,EVENT_COMBAT_EVENT)
        self.flameListening=nil
        self.chargeState[20824]=nil
    end
end
-- Flame Lash / Power Lash middle timer priority:
--   1. "charges"  : Power Lash active stacks (>0) and 20 s window remaining.
--   2. "cooldown" : stacks spent early, 20 s Power Lash cooldown still active (red).
--   3. "flame"    : cooldown ready; ZeraUI falls through to target Off Balance / immunity.
function T:WhipTimer(slot,now)
    if not slot.flameSlot then return nil end
    local state=self.chargeState[20824]
    if state then
        if state.count>0 and state.finish and state.finish>now then
            return state.finish-now,state.duration or 20000,false,"charges"
        end
        if state.cdFinish and state.cdFinish>now then
            return state.cdFinish-now,state.cdDuration or 20000,false,"cooldown"
        end
    end
    return 0,0,false,"flame"
end

function T:ScanUnit(unitTag,snapshot)
    if unitTag=="reticleover" then self.reticle={}; self.targetRev=(self.targetRev or 0)+1 end
    if not self.enabled or (not next(self.watched) and not self.nwListening and not next(self.auxWatched)) or type(GetNumBuffs)~="function" or type(GetUnitBuffInfo)~="function" then return end
    self.targetRev=(self.targetRev or 0)+1
    for _,bucket in pairs(self.scan) do bucket[unitTag]=nil end
    local seenProcs=unitTag=="player" and {} or nil
    local authoritativeSnapshot=unitTag=="player" and self.stackRecoveryScan and {} or nil
    local seenToggles=unitTag=="player" and {} or nil
    local nwName=self.nwListening and unitTag=="player" and GetAbilityName and normalizedName(GetAbilityName(NW_ID)) or ""
    if unitTag=="player" then
        for id in pairs(self.snapshotStacks) do self.snapshotStacks[id]=nil end
        for id in pairs(self.external) do self.external[id]=nil end
    end
    if unitTag=="reticleover" then self.reticleStacks={} end
    local count,info=GetNumBuffs,GetUnitBuffInfo
    if snapshot then count,info=snapshot:Readers(unitTag) end
    local gameNow,frameNow=GetGameTimeSeconds(),GetFrameTimeMilliseconds()
    if unitTag=="player" and self.primeRecover and self.primeWanted and next(self.primeWanted) then
        self.primeRecover=nil; self.primeRecoverScan=true
    end
    for i=1,(count(unitTag) or 0) do
        local name,beginTime,endTime,effectSlot,stacks,_,_,_,_,_,ability,_,castByPlayer=info(unitTag,i)
        -- A rune still on the player after a reload or zone change is primed.
        -- Only the first scan after a reset: in play the rune can still be
        -- listed for a moment after it has already triggered.
        if unitTag=="player" and self.primeRecoverScan and not self.primed and self.primeWanted[ability] then
            self:ObservePrime(EFFECT_RESULT_UPDATED,endTime)
        end
        if unitTag=="player" and self.auxWatched[ability] then
            if self.passiveWanted[ability] then self:ObservePassiveEffect(ability,EFFECT_RESULT_UPDATED,beginTime,endTime)
            elseif ability==LANDSLIDE then self:ObserveLandslide(EFFECT_RESULT_UPDATED,beginTime,endTime,stacks)
            elseif ability~=LANDSLIDE and castByPlayer==false then
                local bucket=self.external[ability] or {}; self.external[ability]=bucket
                bucket[effectSlot or i]=record(beginTime,endTime,0,gameNow,frameNow)
            end
        end
        if unitTag=="reticleover" and self.targetStackWanted and self.targetStackWanted[ability] and (castByPlayer or ability==52790) then
            self.reticleStacks[ability]=math.max(self.reticleStacks[ability] or 0,tonumber(stacks) or 0)
        end
        if self.nwListening and unitTag=="player" and not self.nwFadeAt then
            if ability==NW_ID or (nwName~="" and normalizedName(name)==nwName) then self:ObserveNothingWasted(beginTime,endTime,stacks,true) end
        end
        if self.watched[ability] and (castByPlayer or (unitTag=="player" and BUILTIN.authoritativeStacks[ability])) then
            if unitTag=="player" and ability==46331 and self.chargeWanted and self.chargeWanted[ability] then
                local state=self.chargeState[ability]
                if not state or (not state.gameBegin and (stacks or 0)>0) or
                    (beginTime and state.gameBegin and beginTime>state.gameBegin+.25) then
                    self:OnEffect(nil,EFFECT_RESULT_GAINED,effectSlot,nil,unitTag,beginTime,endTime,stacks,nil,nil,nil,nil,nil,nil,nil,ability,COMBAT_UNIT_TYPE_PLAYER)
                end
            end
            if self.deviceWanted and self.deviceWanted[ability] then
                self:OnDeviceEffect(self.deviceWanted[ability],ability,EFFECT_RESULT_UPDATED,effectSlot,beginTime,endTime)
            end
            if self.stackWanted[ability] and (stacks or 0)>0 then
                self.stackSeen[ability]=true
                if unitTag=="player" and (not endTime or endTime<=gameNow) then self.snapshotStacks[ability]=stacks end
            end
            if authoritativeSnapshot and self.stackRecoveryIds and self.stackRecoveryIds[ability] then
                authoritativeSnapshot[ability]={count=tonumber(stacks) or 0,timed=type(endTime)=="number" and endTime>gameNow}
            end
            if seenToggles and self.toggleWanted[ability] then seenToggles[ability]=true end
            if unitTag=="player" and self.procWanted[ability] then
                seenProcs[ability]=true
                local left=type(endTime)=="number" and endTime-gameNow or 0
                self.procState[ability]=left>0 and frameNow+left*1000 or
                    ((not endTime or endTime==0) and math.huge or nil)
            end
            local phase=BUILTIN.phaseInfo[ability]
            local r=record(beginTime,phase and type(beginTime)=="number" and beginTime+phase.duration or endTime,phase and phase.count or stacks,gameNow,frameNow)
            if r then
                self.effectSeen[ability]=true
                if BUILTIN.previousPhase[ability] then self.effectSeen[BUILTIN.previousPhase[ability]]=true end
                self.phaseSeen[ability]=true
                self.scan[ability]=self.scan[ability] or {}
                local old=self.scan[ability][unitTag]
                if not old or r.finish>old.finish then self.scan[ability][unitTag]=r end
                if unitTag=="reticleover" and self.reticleWanted and self.reticleWanted[ability] then self.reticle[ability]=self.scan[ability][unitTag] end
            end
        end
    end
    self.primeRecoverScan=nil
    -- Recover a missed consumption only after a confirmed cast and on the
    -- real player snapshot. Do not let a near-simultaneous stale snapshot
    -- replace an observed stack update.
    if authoritativeSnapshot then
        local now=GetFrameTimeMilliseconds()
        for id in pairs(self.stackRecoveryIds or {}) do
            if self.stackWanted[id] and (not self.stackEventAt or now-(self.stackEventAt[id] or -10000)>350) and
                (authoritativeSnapshot[id]~=nil or self.stackSeen[id]) then
                local observed=authoritativeSnapshot[id]
                self.stackSeen[id]=true
                self.permanentStacks[id]=observed and not observed.timed and observed.count or (not observed and 0 or nil)
                self.real[id]=nil; self.snapshotStacks[id]=nil
            end
        end
    end
    if seenProcs then for id in pairs(self.procState) do if not seenProcs[id] then self.procState[id]=nil end end end
    if seenToggles then
        for id,group in pairs(self.toggleWanted) do
            if seenToggles[id] then self.toggleBuffs[id]=true; self.toggleObserved[group]=true
            else self.toggleBuffs[id]=nil end
        end
        for group in pairs(self.toggleObserved) do
            -- Once sampled, native Banner state owns both bars. A stale
            -- player buff snapshot cannot override it after deactivation.
            if group~="banner" or self.bannerNative==nil then self:RefreshToggleGroup(group) end
        end
    end
end

function T:RegisterWatchedEffect(id)
    if self.watched[id] or not self.enabled or not EVENT_MANAGER or not EVENT_EFFECT_CHANGED or not REGISTER_FILTER_ABILITY_ID or not REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE or not COMBAT_UNIT_TYPE_PLAYER then return false end
    local ns="ZeraUIEffect_"..id
    EVENT_MANAGER:RegisterForEvent(ns,EVENT_EFFECT_CHANGED,self.effectCallback)
    EVENT_MANAGER:AddFilterForEvent(ns,EVENT_EFFECT_CHANGED,REGISTER_FILTER_ABILITY_ID,id)
    if BUILTIN.authoritativeStacks[id] and REGISTER_FILTER_UNIT_TAG then
        EVENT_MANAGER:AddFilterForEvent(ns,EVENT_EFFECT_CHANGED,REGISTER_FILTER_UNIT_TAG,"player")
    elseif id~=52790 then EVENT_MANAGER:AddFilterForEvent(ns,EVENT_EFFECT_CHANGED,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER) end
    self.watched[id]=ns
    return true
end

function T:Reconcile(plan)
    local wanted=self.enabled and self.requested or {}
    local changed=false
    for id,ns in pairs(self.watched) do
        if not wanted[id] then
            EVENT_MANAGER:UnregisterForEvent(ns,EVENT_EFFECT_CHANGED)
            self.watched[id]=nil; self.real[id]=nil; self.scan[id]=nil; self.procState[id]=nil
            self.effectSeen[id]=nil; self.phaseSeen[id]=nil; changed=true
            self.targetRev=(self.targetRev or 0)+1
        end
    end
    if not EVENT_EFFECT_CHANGED or not REGISTER_FILTER_ABILITY_ID or not REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE or not COMBAT_UNIT_TYPE_PLAYER then return end
    for id in pairs(wanted) do
        if self:RegisterWatchedEffect(id) then changed=true end
    end
    if changed then recoverUnits(self,plan,true,true) end
    self:ReconcileSpecialCombat()
end

-- Register combat events only for specific slotted mechanics. Everything
-- else remains on the engine-filtered effect callbacks used by the HUD.
function T:ReconcileSpecialCombat()
    if not EVENT_COMBAT_EVENT or not REGISTER_FILTER_ABILITY_ID then return end
    self.specialCombatListeners=self.specialCombatListeners or {}
    self.specialCombatState=self.specialCombatState or {}
    local wanted=self.enabled and self.specialCombatWanted or {}
    wanted=wanted or {}
    for id,mode in pairs(self.specialCombatListeners) do
        if not wanted[id] then
            local ns="ZeraUISpecialCombat_"..id
            EVENT_MANAGER:UnregisterForEvent(ns,EVENT_COMBAT_EVENT)
            if mode=="split" then EVENT_MANAGER:UnregisterForEvent(ns.."Fade",EVENT_COMBAT_EVENT) end
            self.specialCombatListeners[id]=nil
        end
    end
    for id,spec in pairs(wanted) do
        if not self.specialCombatListeners[id] then
            local ns="ZeraUISpecialCombat_"..id
            local source=not spec.shield and (spec.pet and COMBAT_UNIT_TYPE_PLAYER_PET or not spec.pet and COMBAT_UNIT_TYPE_PLAYER) or nil
            local function registerFiltered(name,resultCode)
                EVENT_MANAGER:RegisterForEvent(name,EVENT_COMBAT_EVENT,self.specialCallback)
                EVENT_MANAGER:AddFilterForEvent(name,EVENT_COMBAT_EVENT,REGISTER_FILTER_ABILITY_ID,id)
                if spec.shield and REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE then
                    EVENT_MANAGER:AddFilterForEvent(name,EVENT_COMBAT_EVENT,REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
                elseif source and REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE then
                    EVENT_MANAGER:AddFilterForEvent(name,EVENT_COMBAT_EVENT,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,source)
                end
                if resultCode and REGISTER_FILTER_COMBAT_RESULT then
                    EVENT_MANAGER:AddFilterForEvent(name,EVENT_COMBAT_EVENT,REGISTER_FILTER_COMBAT_RESULT,resultCode)
                end
            end
            local resultCode=spec.result and _G[spec.result] or nil
            if (spec.passive or spec.result=="ACTION_RESULT_POWER_ENERGIZE") and resultCode then
                registerFiltered(ns,resultCode)
                self.specialCombatListeners[id]=true
            elseif resultCode and ACTION_RESULT_EFFECT_FADED and REGISTER_FILTER_COMBAT_RESULT then
                -- Split timed combat buffs into separate gain and fade C-side
                -- filtered listeners so unrelated HoT ticks/heals stay in C++.
                registerFiltered(ns,resultCode)
                registerFiltered(ns.."Fade",ACTION_RESULT_EFFECT_FADED)
                self.specialCombatListeners[id]="split"
            else
                registerFiltered(ns,nil)
                self.specialCombatListeners[id]=true
            end
        end
    end
end

function T:OnSpecialCombat(_,result,isError,_,_,_,_,sourceType,_,targetType,_,_,_,_,_,_,id)
    local spec=self.enabled and self.specialCombatWanted and self.specialCombatWanted[id]
    if not spec or isError then return end
    local now=GetFrameTimeMilliseconds()
    if spec.passive then
        if sourceType==COMBAT_UNIT_TYPE_PLAYER and result==ACTION_RESULT_POWER_ENERGIZE then
            self.specialCombatState[spec.parent]={finish=now+spec.duration*1000,duration=spec.duration*1000}
        end
        return
    end
    local state=self.specialCombatState[spec.parent]
    if spec.shield then
        if targetType~=COMBAT_UNIT_TYPE_PLAYER then return end
        if result==ACTION_RESULT_EFFECT_FADED then self.specialCombatState[spec.parent]={count=0}; return end
        if result==ACTION_RESULT_EFFECT_GAINED or result==ACTION_RESULT_EFFECT_GAINED_DURATION or (ACTION_RESULT_BEGIN and result==ACTION_RESULT_BEGIN) then
            if state and state.gained and now-state.gained<300 then return end
            local duration=GetAbilityDuration and positive(GetAbilityDuration(spec.parent,nil,"player")) or nil
            self.specialCombatState[spec.parent]={count=spec.shield,gained=now,finish=now+(duration or 30000)}
        elseif ACTION_RESULT_DAMAGE_SHIELDED and result==ACTION_RESULT_DAMAGE_SHIELDED and state then
            state.count=math.max(0,(state.count or 0)-1)
        end
    else
        local source=spec.pet and COMBAT_UNIT_TYPE_PLAYER_PET or not spec.pet and COMBAT_UNIT_TYPE_PLAYER
        if not source or sourceType~=source then return end
        if result==ACTION_RESULT_EFFECT_FADED then
            if state and state.gained and now-state.gained<300 then return end
            self.specialCombatState[spec.parent]={finish=0,duration=0}; return
        end
        if not result then return end
        if spec.result and result~=_G[spec.result] then return end
        local duration=spec.duration and spec.duration*1000 or GetAbilityDuration and positive(GetAbilityDuration(spec.parent,nil,"player"))
        if duration then self.specialCombatState[spec.parent]={finish=now+duration,duration=duration,gained=now} end
    end
end

function T:ActivePassiveLines()
    local lines={}
    local manager=SKILLS_DATA_MANAGER
    if self.passivesEnabled and manager and manager.GetActiveClassSkillLine then
        if not manager.IsDataReady or manager:IsDataReady() then
            for i=1,3 do
                local line=manager:GetActiveClassSkillLine(i)
                local lineId=line and (line.GetId and line:GetId() or line.id)
                if lineId and BUILTIN.ultPassives[lineId] then lines[lineId]=true end
            end
        end
    end
    return lines
end

local PASSIVE_LABELS={}
function T:PassiveText(now)
    if not self.enabled or not self.passivesEnabled then return "" end
    local lines=self.passiveLines
    if not lines or #lines==0 then return "" end
    local cache=self.passiveTextCache
    local count,changed=0,false
    for _,line in ipairs(lines) do
        local state=self.specialCombatState and self.specialCombatState["ult:"..line]
        if state and state.finish>now then
            count=count+1
            local sec=math.ceil((state.finish-now)/1000)
            local base=count*2
            if cache[base-1]~=line or cache[base]~=sec then
                cache[base-1],cache[base]=line,sec
                changed=true
            end
        end
    end
    if count==0 then
        if cache.count~=0 then cache.count=0; cache.text="" end
        return ""
    end
    if changed or cache.count~=count then
        cache.count=count
        for i=1,count do
            local base=i*2
            PASSIVE_LABELS[i]=BUILTIN.ultPassives[cache[base-1]].name.." "..cache[base].."s"
        end
        cache.text=table.concat(PASSIVE_LABELS,"  ·  ",1,count)
    end
    return cache.text
end

local function hasPassive(self,kind)
    return not self.passiveCheck or self.passiveCheck(kind)~=false
end

function T:Sync(slots,categories,snapshot)
    local nwAllowed=self.nwEnabled and hasPassive(self,"nw")
    local vampAllowed=self.vampirePassiveEnabled and hasPassive(self,"vampire")
    local arcAllowed=hasPassive(self,"arcanist")
    local landAllowed=self.landslideEnabled and hasPassive(self,"landslide")
    if not self.syncDirty and self.syncedCat1==categories[1] and self.syncedCat2==categories[2]
        and self.syncedTargets==self.targetsEnabled and self.syncedProcs==self.procEnabled and self.syncedNW==nwAllowed and self.syncedPassives==self.passivesEnabled
        and self.syncedVampirePassive==vampAllowed and self.syncedArcanistPassive==self.arcanistPassiveMode
        and self.syncedArcAllowed==arcAllowed and self.syncedLandslide==landAllowed then return end
    self.syncDirty=false
    self.retVersion=(self.retVersion or 0)+1; self.targetRev=(self.targetRev or 0)+1
    self.syncedCat1,self.syncedCat2=categories[1],categories[2]
    self.syncedTargets,self.syncedProcs=self.targetsEnabled,self.procEnabled
    self.syncedNW=nwAllowed
    self.syncedPassives=self.passivesEnabled
    self.syncedVampirePassive,self.syncedArcanistPassive=vampAllowed,self.arcanistPassiveMode
    self.syncedArcAllowed,self.syncedLandslide=arcAllowed,landAllowed
    local nwWanted,flameWanted=false,false
    local vampireWanted,arcanistWanted=false,false
    local aux,reticleWanted,followExact={},{},{}
    local function bindFollowEffect(id,slot)
        if not id then return end
        local list=followExact[id] or {}; followExact[id]=list
        list[#list+1]=slot
    end
    local bindings,wanted,procs,toggles,groups,stacks,targetStacks,devices,specialCombat,targetWanted={},{},{},{},{},{},{},{},{},{}
    local specialParents={}
    local sharedWanted,sharedKeys,chargeWanted,chargeParents,transformed,readyWanted={},{},{},{},{},{}
    local primeWanted,contingencyKey={},nil
    for r=1,2 do
        if categories[r] then for i=1,6 do
            local s=slots[r][i]
            if nwAllowed and s and s.nwSlot then nwWanted=true end
            if i<=5 and s and s.abilityKey then
                if vampAllowed and s.vampirePassiveSlot then vampireWanted=true end
                if arcAllowed and s.arcanistPassiveSlot and (self.arcanistPassiveMode==s.arcanistPassiveSlot or self.arcanistPassiveMode=="Both") then arcanistWanted=true end
            end
            if s and s.abilityKey then
                if s.flameSlot then flameWanted=true end
                if landAllowed and s.landslideSlot then aux[LANDSLIDE]=true end
                if self.externalCountsEnabled and s.externalCountEffect then aux[s.externalCountEffect]=true end
                local p=self:Policy(s)
                if p and p.external then
                    for _,rule in ipairs(s.track or {}) do
                        if rule.mode~="off" and self:ExternalEligible(s,rule) then aux[rule.effect]=true end
                    end
                end
            end
            if s and s.track then
                bindings[s.trackKey]=s.track
                for _,rule in ipairs(s.track) do
                    if rule.mode~="cast" and rule.mode~="off" then wanted[rule.effect]=true end
                    if not rule.shared and rule.mode~="cast" and rule.mode~="off" and self:TimerPolicy(s,rule)=="target" then
                        reticleWanted[rule.effect]=true
                        if rule.followup then reticleWanted[rule.followup]=true end
                    end
                    if rule.shared then sharedWanted[rule.effect]=true; sharedKeys[s.abilityKey]=true end
                    if rule.placement then wanted[rule.placement]=true end
                    if rule.followup then wanted[rule.followup]=true end
                end
            end
            -- Index only the middle timer's exact identities. Undeclared
            -- area damage still needs the duration/name proof from MatchReticle.
            if s and s.abilityKey and not areaProbe(s) then
                local primary=s.track and s.track[1]
                if primary and primary.mode~="cast" and primary.mode~="off" and not primary.shared then
                    bindFollowEffect(primary.effect,s); bindFollowEffect(primary.followup,s)
                elseif not primary and (s.timerTargetScope=="enemy" or s.targetEffect~=s.abilityId) then
                    bindFollowEffect(s.targetEffect,s)
                end
            end
            if s and self.targetsEnabled and s.targetEffect then wanted[s.targetEffect]=true; targetWanted[s.targetEffect]=true end
            if s and self.targetsEnabled and self.followTarget and areaProbe(s) then
                local learned=self.targetLearn[s.abilityKey]
                if learned then wanted[learned]=true; targetWanted[learned]=true end
            end
            if s and s.abilityKey then
                for _,effectId in ipairs({s.sharedEffect or false,s.recipientEffect or false}) do
                    if effectId then wanted[effectId]=true; sharedWanted[effectId]=true; sharedKeys[s.abilityKey]=true end
                end
                if self.targetsEnabled and s.recipientAliases then
                    sharedKeys[s.abilityKey]=true
                    for _,effectId in ipairs(s.recipientAliases) do wanted[effectId]=true; sharedWanted[effectId]=true end
                end
                if s.readyEffects and self.procEnabled then for _,id in ipairs(s.readyEffects) do wanted[id]=true; readyWanted[id]=true end end
                if s.chain and s.chain.trigger=="contingency" then
                    contingencyKey=contingencyKey or s.abilityKey
                    for _,id in ipairs(BUILTIN.contingencyProcs) do wanted[id]=true; primeWanted[id]=true end
                end
                local parent=s.chargeId
                if parent then
                    chargeParents[parent]=true
                    if parent~=20824 then
                        wanted[parent]=true; chargeWanted[parent]=parent
                        local trigger=BUILTIN.trapEffects[parent]
                        if trigger then wanted[trigger]=true; chargeWanted[trigger]=parent end
                        if parent==46331 then wanted[143808]=true; chargeWanted[143808]=parent end
                        if s.abilityId==256798 then transformed[parent]=true end
                    end
                end
            end
            if s and s.stackEffect then wanted[s.stackEffect]=true; stacks[s.stackEffect]=true end
            if s and s.targetStackEffect then wanted[s.targetStackEffect]=true; targetStacks[s.targetStackEffect]=true end
            if s and s.deviceParent then
                wanted[s.deviceParent]=true; devices[s.deviceParent]=s.deviceParent
                for _,id in ipairs(BUILTIN.devices[s.deviceParent]) do wanted[id]=true; devices[id]=s.deviceParent end
            end
            if s and s.shieldCharges then
                local parent=s.shieldCharges; local spec=BUILTIN.shieldCharges[parent]
                specialParents[parent]=true
                for j=2,#spec do specialCombat[spec[j]]={parent=parent,shield=spec[1]} end
            end
            if s and s.combatTimer then
                local parent=s.combatTimer; local spec=BUILTIN.combatTimers[parent]
                specialParents[parent]=true
                specialCombat[spec.event]={parent=parent,result=spec.result,pet=spec.pet,duration=spec.duration}
            end
            if s and self.procEnabled and s.procEffect then wanted[s.procEffect]=true; procs[s.procEffect]=true end
            if s and s.toggleGroup then
                groups[s.toggleGroup]=true
                for _,id in ipairs(TOGGLE_GROUPS[s.toggleGroup]) do wanted[id]=true; toggles[id]=s.toggleGroup end
            end
        end end
    end
    self.passiveLines={}
    for line in pairs(self:ActivePassiveLines()) do
        self.passiveLines[#self.passiveLines+1]=line
        local spec=BUILTIN.ultPassives[line]; local parent="ult:"..line
        specialParents[parent]=true
        for _,id in ipairs(spec.ids) do specialCombat[id]={parent=parent,passive=true,duration=spec.duration,result="ACTION_RESULT_POWER_ENERGIZE"} end
    end
    table.sort(self.passiveLines)
    self.sharedWanted,self.chargeWanted=sharedWanted,chargeWanted
    self.groupBuffWanted=false
    for id in pairs(BUILTIN.groupBuffEffects) do if wanted[id] then self.groupBuffWanted=true; break end end
    if next(sharedWanted) or self.groupOnly or self.groupBuffWanted then
        if not self.groupNames then self:RefreshGroupNames() end
    else self.groupNames=nil; self.playerName=nil; self.groupAliases=nil; self.playerDisplayName=nil; self.groupRosterKnown=false end
    self.readyWanted=readyWanted
    self.primeWanted,self.contingencyKey=primeWanted,contingencyKey
    if self.primed and self.primed.key~=contingencyKey then self.primed=nil end
    for key in pairs(self.chainState) do
        local bound=false
        for r=1,2 do for i=1,6 do local s=slots[r] and slots[r][i]; if s and s.abilityKey==key and s.chain then bound=true end end end
        if not bound then self.chainState[key]=nil end
    end
    if self.readyPermanent then for id in pairs(self.readyPermanent) do if not readyWanted[id] then self.readyPermanent[id]=nil end end end
    for key in pairs(self.sharedRecords) do if not sharedKeys[key] then self.sharedRecords[key]=nil end end
    for id,cast in pairs(self.sharedCast) do if not sharedKeys[cast.key] then self.sharedCast[id]=nil end end
    for parent in pairs(self.chargeState) do if not chargeParents[parent] then self.chargeState[parent]=nil end end
    if transformed[256798] and not (self.transformed and self.transformed[256798]) then
        self.chargeState[256798]={count=5}
    elseif not transformed[256798] and self.transformed and self.transformed[256798] then
        self.chargeState[256798]={count=0}
    end
    self.transformed=transformed
    self.bindings,self.requested,self.procWanted=bindings,wanted,procs
    self.followExact=followExact
    local reticleChanged=false
    for id in pairs(self.reticleWanted or {}) do if not reticleWanted[id] then self.reticle[id]=nil; reticleChanged=true end end
    for id in pairs(reticleWanted) do if not (self.reticleWanted and self.reticleWanted[id]) then reticleChanged=true end end
    self.reticleWanted=reticleWanted
    for id in pairs(self.stackWanted) do if not stacks[id] then self.stackSeen[id]=nil; self.permanentStacks[id]=nil; self.snapshotStacks[id]=nil; self.stackZeroUntil[id]=nil; self.stackGame[id]=nil end end
    self.stackWanted=stacks
    self.targetStackWanted=targetStacks
    self.targetWanted=targetWanted
    self.deviceWanted=devices
    self.specialCombatWanted=specialCombat
    if self.specialCombatState then for parent in pairs(self.specialCombatState) do if not specialParents[parent] then self.specialCombatState[parent]=nil end end end
    if self.deviceState then for parent in pairs(self.deviceState) do if not devices[parent] then self.deviceState[parent]=nil end end end
    self.toggleWanted=toggles
    for id in pairs(self.toggleBuffs) do if not toggles[id] then self.toggleBuffs[id]=nil end end
    for group in pairs(self.toggleObserved) do if not groups[group] then self.toggleObserved[group]=nil; self.toggleState[group]=nil end end
    for group in pairs(self.toggleRetry) do if not groups[group] then self.toggleRetry[group]=nil end end
    if not groups.banner then self.bannerNative=nil; self.bannerGrace=nil; self.bannerOffConfirmed=nil end
    for id in pairs(self.procState) do if not procs[id] then self.procState[id]=nil end end
    for key in pairs(self.fallback) do if not bindings[key] then self.fallback[key]=nil end end
    local recovery={reticle=reticleChanged}
    self:Reconcile(recovery)
    local passiveWanted={}
    if vampireWanted then for id in pairs(PASSIVE_VAMPIRE) do passiveWanted[id]=true; aux[id]=true end end
    if arcanistWanted then for id in pairs(PASSIVE_ARCANIST) do passiveWanted[id]=true; aux[id]=true end end
    self.passiveWanted=passiveWanted
    self.auxWanted=aux; self:ReconcileAux(recovery)
    self.nwWanted=nwWanted; self:ReconcileNothingWasted(recovery)
    self.flameWanted=flameWanted; self:ReconcilePowerLash()
    recoverUnits(self,nil,recovery.player,recovery.reticle,snapshot)
end

local function resetTrackingState(self,full)
    self.sharedRecords={}; self.sharedCast={}; self.chargeState={}; self.transformed=nil; self.readyPermanent={}
    self.chainState={}; self.primed=nil; self.stackRecoveryIds=nil; self.stackRecoveryAt=nil; self.stackEventAt=nil; self.stackGame={}
    self.fallback={}; self.toggleBuffs={}; self.toggleObserved={}; self.toggleState={}; self.toggleRetry={}
    self.bannerNative=nil; self.bannerGrace=nil; self.bannerOffConfirmed=nil
    self.stackSeen={}; self.permanentStacks={}; self.snapshotStacks={}; self.stackZeroUntil={}
    self.deviceState={}; self.specialCombatState={}; self.reticleStacks={}; self.reticleStackRecovery=nil
    self.targetLearn={}; self.lastTarget={}; self.retMine=nil; self.retHostile=false; self.retDirty=true
    if not full then return end
    self.real={}; self.scan={}; self.procState={}
    self.effectSeen={}; self.phaseSeen={}; self.recoveryAt=nil; self.recoveryPending=nil; self.effectAt=nil
    self.primeRecover=true; self.syncDirty=true
    -- Skill data may not have been ready when a lookup came back empty.
    for key,spec in pairs(self.chainSpecs) do if spec==false then self.chainSpecs[key]=nil end end
    self.toggleGame={}; self.procGame={}
    self.groupNames=nil; self.playerName=nil; self.groupAliases=nil; self.playerDisplayName=nil; self.groupRosterKnown=false
    self:ClearNothingWasted()
    self.external={}; self.landslide=nil; self.reticle={}
    self.passiveEffects={}
end

function T:SetEnabled(enabled)
    if self.enabled==enabled then return end
    self.enabled=enabled
    self.syncDirty=true
    self.retVersion=(self.retVersion or 0)+1; self.targetRev=(self.targetRev or 0)+1
    if not enabled then resetTrackingState(self,false) end
    local recovery={}
    self:Reconcile(recovery)
    self:ReconcileAux(recovery)
    self:ReconcileNothingWasted(recovery)
    self:ReconcilePowerLash()
    recoverUnits(self,nil,recovery.player,recovery.reticle)
end

-- An effect seen once (e.g. an arena weapon's) may never fire with the new
-- gear. Forget that, so its skill falls back to the native timer again.
function T:GearChanged()
    self.effectSeen={}
end
function T:ResetRuntime()
    self.retVersion=(self.retVersion or 0)+1; self.targetRev=(self.targetRev or 0)+1
    resetTrackingState(self,true)
end

-- Bound retained target data even for effects observed but not currently
-- displayed. No full buff scan or per-tick allocation in the hot path.
local function pruneCollection(collection,now)
    local pruned=false
    for id,bucket in pairs(collection) do
        for key,r in pairs(bucket) do if r.finish<=now then bucket[key]=nil; pruned=true end end
        if not next(bucket) then collection[id]=nil; pruned=true end
    end
    return pruned
end
function T:Prune(now)
    if self.nextPrune and now<self.nextPrune then return end
    self.nextPrune=now+1000
    local pruned=pruneCollection(self.real,now)
    if pruneCollection(self.scan,now) then pruned=true end
    pruneCollection(self.fallback,now)
    for _,byEffect in pairs(self.sharedRecords) do
        for _,bucket in pairs(byEffect) do
            for key,r in pairs(bucket) do if r.finish<=now then bucket[key]=nil; pruned=true end end
            -- Keep the empty container until unbinding: after an observed
            -- fade, a stale native timer must not resurrect the effect.
        end
    end
    if pruned then self.targetRev=(self.targetRev or 0)+1 end
    for id,cast in pairs(self.sharedCast) do if now>cast.untilTime then self.sharedCast[id]=nil end end
    for _,bucket in pairs(self.external) do for k,r in pairs(bucket) do if r.finish<=now then bucket[k]=nil end end end
    if self.landslide and self.landslide.finish<=now then self.landslide=nil end
end

-- Recover once after a confirmed toggle cast if the buff event was missed.
-- No additional recurring scan or update registration.
function T:UpdateToggleRecovery(now,snapshot)
    local scan=false
    if next(self.toggleRetry) then
        for group,at in pairs(self.toggleRetry) do
            if now>=at then self.toggleRetry[group]=nil; scan=true end
        end
    end
    local recover=self.recoveryAt and now>=self.recoveryAt
    if recover then
        self.recoveryAt=nil
        local missing=self.recoveryPending and next(self.recoveryPending)~=nil
        self.recoveryPending=nil
        if missing then self:ScanUnit("reticleover",snapshot) else recover=false end
    end
    local nwRecover=self.nwRecoverAt and now>=self.nwRecoverAt
    if nwRecover then self.nwRecoverAt=nil end
    local stackRecover=self.stackRecoveryAt and now>=self.stackRecoveryAt
    if stackRecover then self.stackRecoveryAt=nil; self.stackRecoveryScan=true end
    if scan or recover or nwRecover or stackRecover then self:ScanUnit("player",snapshot) end
    self.stackRecoveryScan=nil
    if stackRecover then self.stackRecoveryIds=nil end
    if self.reticleStackRecovery and now>=self.reticleStackRecovery then
        self.reticleStackRecovery=nil
        -- The general recovery above already read the same live reticle.
        -- Player-only authoritative stack recovery does not change it.
        if not recover then self:ScanUnit("reticleover",snapshot) end
    end
end

function T:OnCast(slot,now)
    if self.enabled and BUILTIN.fragProc[slot.abilityId] then
        self.real[46327]=nil; self.scan[46327]=nil; self.procState[46327]=nil; self.effectSeen[46327]=true
        self.targetRev=(self.targetRev or 0)+1
    end
    if self.enabled and slot.stackEffect and BUILTIN.authoritativeStacks[slot.stackEffect] then
        self.stackRecoveryIds=self.stackRecoveryIds or {}
        self.stackRecoveryIds[slot.stackEffect]=true
        self.stackRecoveryAt=now+450
    end
    if self.enabled and slot.toggleGroup then self.toggleRetry[slot.toggleGroup]=now+300 end
    if self.enabled and slot.toggleGroup=="banner" then self.bannerOffConfirmed=nil end
    if self.enabled then
        self.sharedCast={}
        for _,id in ipairs({slot.sharedEffect or false,slot.recipientEffect or false}) do
            if id then self.sharedCast[id]={key=slot.abilityKey,untilTime=now+1200,recipient=slot.recipientEffect==id} end
        end
        if self.targetsEnabled and slot.recipientAliases then
            for _,id in ipairs(slot.recipientAliases) do self.sharedCast[id]={key=slot.abilityKey,untilTime=now+1200,recipient=true} end
        end
        for _,rule in ipairs(slot.track or {}) do
            if rule.shared and not self.sharedCast[rule.effect] then self.sharedCast[rule.effect]={key=slot.abilityKey,untilTime=now+1200} end
        end
        local parent=slot.chargeId
        if parent then
            local state=self.chargeState[parent]
            if BUILTIN.trapEffects[parent] then self.chargeState[parent]={count=1,untilTime=now+30000}
            elseif parent==46331 then
                -- The gain can arrive before the slot-use event. Preserve a
                -- fresh observed stack count, otherwise initialize on cast.
                if not (state and state.gainAt and now-state.gainAt<=300 and state.count>0) then
                    local duration=GetAbilityDuration and tonumber(GetAbilityDuration(46331,nil,"player")) or 0
                    if duration<2000 or duration>15000 then duration=6000 end
                    self.chargeState[parent]={count=BUILTIN.chargeSkills[parent],finish=now+duration,duration=duration,castAt=now,gameBegin=GetGameTimeSeconds()}
                end
            elseif state and slot.abilityId==256798 then state.count=math.max(0,state.count-1) end
        end
    end
    local chain=self.enabled and slot.chain
    if chain and chain.trigger=="cast" then self:StartChain(slot.abilityKey,chain,now)
    elseif chain and chain.trigger=="contingency" then
        -- Ulfsild itself costs resources: recasting it while a rune is
        -- primed sets that rune off (its phases start) and places a new one.
        local old=self.primed
        local consumed=old and old.key==slot.abilityKey and now-old.castAt>100 and now<=old.untilTime
        if consumed then self:TriggerPrimed(now) end
        -- The replaced rune's fade arrives late; it must not end the new one.
        self.primed={key=slot.abilityKey,castAt=now,untilTime=now+(chain.rune or 22000),replacedEnd=consumed and old.gameEnd or nil}
    end
    local entries,key=slot.track,slot.trackKey
    if not self.enabled or not entries then return end
    local bucket
    local scan=false
    for index,rule in ipairs(entries) do
        local duration=rule.duration*1000
        if rule.castDurationAPI and GetAbilityDuration then duration=positive(GetAbilityDuration(slot.abilityId,nil,"player")) or 0 end
        -- Only explicit fixed-duration own casts; observed effect endpoints
        -- already include game-side modifiers and must not be multiplied.
        if rule.mode~="effect" and rule.mode~="off" and duration>0 then
            if not bucket then bucket={}; self.fallback[key]=bucket end
            bucket[fallbackKey(rule,index)]={finish=now+duration,duration=duration,stacks=0}
        end
        if rule.placement then
            self.phaseSeen[rule.effect]=nil
            self.real[rule.placement]=nil; self.scan[rule.placement]=nil
            self.targetRev=(self.targetRev or 0)+1
        end
        if rule.mode~="cast" and rule.mode~="off" and (not rule.nativeFallback or not self.effectSeen[rule.effect]) then
            -- Expect this effect unless our own copy of it was just handled
            -- (the effect event can come just before the slot-use event).
            local at=self.effectAt and self.effectAt[rule.effect]
            if not (at and now-at>=0 and now-at<=150) then
                self.recoveryPending=self.recoveryPending or {}
                self.recoveryPending[rule.effect]=true
                scan=true
            end
        end
    end
    -- A brief reticle snapshot can recover real effects missed by the event
    -- API; it runs only if an expected effect is still missing by then.
    -- No continuous combat-log scan is performed.
    if scan and not self.recoveryAt then self.recoveryAt=now+250 end
end

local function longest(bucket,now,best,soonest,targetsOnly,nonVictimsOnly)
    if bucket then
        for k,r in pairs(bucket) do
            if r.finish<=now then bucket[k]=nil
            elseif (not targetsOnly or r.isTarget) and (not nonVictimsOnly or not r.isTarget and not r.isDebuff) and (not best or (soonest and r.finish<best.finish) or (not soonest and r.finish>best.finish)) then best=r end
        end
    end
    return best
end
-- Target records take precedence over self/other records, even when the
-- latter expire earlier/later. Resolve both priorities in one traversal;
-- the old target-only search followed by a full search repeated the work
-- on every self-only effect. Prune expired records identically.
local function preferredReal(bucket,now,soonest)
    local target,other
    if bucket then
        for k,r in pairs(bucket) do
            if r.finish<=now then bucket[k]=nil
            elseif r.isTarget then
                if not target or (soonest and r.finish<target.finish) or (not soonest and r.finish>target.finish) then target=r end
            elseif not target and (not other or (soonest and r.finish<other.finish) or (not soonest and r.finish>other.finish)) then other=r end
        end
    end
    return target or other
end
function T:Get(slot,now,index)
    local rule=slot.track and slot.track[index or 1]
    -- Keep Blood Hunger's real effect/stack state intact, but never turn it
    -- into a central or corner countdown (including the native fallback).
    if ((not index or index==1) and slot.stackOnlyPrimary) or
        (rule and BUILTIN.stackOnlyEffects[rule.effect]) then return 0,0,0,false end
    if slot.chargeId==46331 and (not index or index==1) and slot.track==BUILTIN.duration["a:46331"] then
        local state=self.chargeState[46331]
        if state and state.count>0 and state.finish and state.finish>now then
            return state.finish-now,state.duration or 6000,state.count,false
        end
        if state then return 0,0,0,false end
        -- Login/reload recovery may still have a native slot duration.
        return nil
    end
    if slot.chain then
        if (index or 1)<=2 then return self:ChainGet(slot,now,index or 1) end
        return nil
    end
    if slot.combatTimer and (not index or index==1) and not slot.track then
        local state=self.specialCombatState and self.specialCombatState[slot.combatTimer]
        if state and state.finish then return math.max(0,state.finish-now),state.duration,0,false end
    end
    if slot.deviceParent and (not index or index==1) then
        local count,left,duration=self:DeviceState(slot,now)
        if count~=nil then return left,duration,count,false end
    end
    local key=slot.trackKey
    if not rule or rule.mode=="off" then return nil end
    local best
    if rule.shared then
        local policy=self:Policy(slot)
        local timerPolicy=resolveTimerPolicy(policy,rule)
        local soonest=timerPolicy=="first" or (timerPolicy~="last" and self.soonest)
        local byEffect=self.sharedRecords[slot.abilityKey]
        local bucket=byEffect and byEffect[rule.effect]
        if not bucket then if slot.noNativeTimer then return 0,0,0,false end; return nil end
        best=preferredReal(bucket,now,soonest)
        if best then return best.finish-now,best.duration,0,false end
        return 0,0,0,false
    end
    if rule.mode~="cast" then
        local policy=self:Policy(slot)
        local timerPolicy=resolveTimerPolicy(policy,rule)
        local soonest=timerPolicy=="first" or (timerPolicy~="last" and self.soonest)
        -- Explicit target mode never borrows another enemy's timer or uses
        -- a native/estimated countdown when the reticle has no matching effect.
        if timerPolicy=="target" then
            best=self.reticle[rule.effect]
            local follow=rule.followup and self.reticle[rule.followup]
            if follow and follow.finish>now and (not best or best.finish<follow.finish) then best=follow end
            if best and best.finish>now then return best.finish-now,best.duration,best.stacks,false end
            return 0,0,0,false
        end
        if (slot.groundTimer~=nil and slot.groundTimer or groundTimer(slot)) and not slot.customTimer and (not index or index==1) and rule.nativeFallback then
            -- A curated placed-area effect can also emit per-victim records.
            -- Own placement/player records or the game's native cast timer
            -- are authoritative; a victim entering later cannot extend it.
            best=longest(self.real[rule.effect],now,nil,false,false,true)
            local own=self.scan[rule.effect] and self.scan[rule.effect].player
            if own and own.finish>now and (not best or own.finish>best.finish) then best=own end
            if best then return best.finish-now,best.duration,best.stacks,false end
            return nil
        end
        best=preferredReal(self.real[rule.effect],now,soonest)
        if not best then
            -- A scan can be stale relative to the actual per-target records.
            best=longest(self.scan[rule.effect],now,nil,soonest)
        end
        if rule.followup then
            best=longest(self.real[rule.followup],now,best,soonest)
            best=longest(self.scan[rule.followup],now,best,soonest)
        end
        if not best and policy and policy.external and self:ExternalEligible(slot,rule) then
            best=longest(self.external[rule.effect],now,nil,soonest)
        end
    end
    if best then
        if rule.mode=="auto" then
            local bucket=self.fallback[key]
            if bucket then bucket[fallbackKey(rule,index or 1)]=nil end
        end
        return best.finish-now,best.duration,best.stacks,false
    end
    if rule.placement and not self.phaseSeen[rule.effect] then
        best=longest(self.real[rule.placement],now,nil)
        best=longest(self.scan[rule.placement],now,best)
        if best then return best.finish-now,best.duration,best.stacks,false end
        -- The engine can report the placed trap before the DOT is applied.
        if rule.nativeFallback then return nil end
    end
    local bucket=self.fallback[key]
    local fk=bucket and fallbackKey(rule,index or 1) or nil
    local estimated=rule.mode~="effect" and bucket and bucket[fk]
    if estimated and estimated.finish>now then return estimated.finish-now,estimated.duration,0,rule.mode~="cast" end
    if bucket then bucket[fk]=nil end
    if rule.nativeFallback and not self.effectSeen[rule.effect] then return nil end
    return 0,0,0,false
end

function T:PhaseBadge(slot,now)
    if not slot.phaseBadge then return nil end
    local first=slot.abilityId
    local second=BUILTIN.nextPhase[first]
    if longest(self.real[second],now,nil) or longest(self.scan[second],now,nil) then return "[2/2]" end
    if longest(self.real[first],now,nil) or longest(self.scan[first],now,nil) then return "[1/2]" end
end

local function positiveStackRecord(bucket,now)
    local best
    if bucket then for k,r in pairs(bucket) do
        if r.finish<=now then bucket[k]=nil
        elseif r.stacks>0 and (not best or r.finish>best.finish) then best=r end
    end end
    return best and best.stacks
end
-- Keep the feature gate in A:UpdateSkillTimers aligned with these charge
-- sources whenever another charge-bearing slot type is introduced.
function T:GetCharge(slot,now,native)
    if slot.chargeId then
        local id=slot.chargeId
        local state=self.chargeState[id]
        if state then
            if state.finish and now>=state.finish then state.count=0; state.native=false end
            if state.untilTime and now>=state.untilTime then state.count=0 end
            if id==46331 and native and native>0 and (not state.castAt or now-state.castAt>=250) then
                state.native=true
                if native<state.count then state.count=native; state.hit=now end
            elseif id==46331 and state.native and native==0 and state.count>0 then
                state.count=0; state.hit=now
                return 0,true
            end
            if BUILTIN.trapEffects[id] then
                local active=self.real[id]; local best=longest(active,now,nil)
                if state.count>0 and not state.untilTime and not best then state.count=0 end
            end
            return state.count,false
        end
        if id==46331 and native and native>0 then
            self.chargeState[id]={count=native,native=true,finish=slot.nativeTimer and slot.nativeTimer.finish>now and slot.nativeTimer.finish or now+6000,
                duration=slot.nativeTimer and slot.nativeTimer.duration or 6000}
            return native,true
        end
        return 0,false
    end
    if slot.shieldCharges then
        local state=self.specialCombatState and self.specialCombatState[slot.shieldCharges]
        if state then return state.finish and state.finish>now and state.count or 0 end
        return nil
    end
    if slot.deviceParent then return self:DeviceState(slot,now) or 0 end
    if slot.targetStackEffect then return self.reticleStacks and self.reticleStacks[slot.targetStackEffect] or 0 end
    if slot.phaseStack then
        local nextId=BUILTIN.nextPhase[slot.phaseStack]
        local best=positiveStackRecord(self.real[nextId],now) or positiveStackRecord(self.real[slot.phaseStack],now)
        return best or 0
    end
end
function T:GetStack(slot,now)
    local id=slot.stackEffect
    if not id then return nil end
    local observed=self.permanentStacks[id] or positiveStackRecord(self.real[id],now)
    if observed then return observed end
    if self.stackZeroUntil[id] and now<self.stackZeroUntil[id] then return 0 end
    local scanned=self.snapshotStacks[id] or positiveStackRecord(self.scan[id],now)
    if scanned~=nil then return scanned end
    if BUILTIN.authoritativeStacks[id] and self.stackSeen[id] then return 0 end
end
