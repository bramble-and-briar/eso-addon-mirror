-- Optional diagnostic recorder, registered only during /crpst test.
do
-- Opt-in discovery recorder. Raw observations never enter the corpse ledger.
-- AI-assisted implementation; see README.txt. No private API discovery.
local CT = CorpseTracker
local EM = EVENT_MANAGER
local Now, GetAbilityName = GetFrameTimeSeconds, GetAbilityName
local GetAPIVersion, GetWorldName, GetCVar = GetAPIVersion, GetWorldName, GetCVar
local IsUnitInCombat = IsUnitInCombat
local GetSpecificSkillAbilityKeysByAbilityId = GetSpecificSkillAbilityKeysByAbilityId
local GetSpecificSkillAbilityInfo = GetSpecificSkillAbilityInfo
local d, tostring, type, pairs, ipairs, select = d, tostring, type, pairs, ipairs, select
local GetSlotBoundId = GetSlotBoundId
local GetSlotName = GetSlotName
local GetNumBuffs, GetUnitBuffInfo = GetNumBuffs, GetUnitBuffInfo
local DoesUnitExist, GetUnitName, IsUnitDead = DoesUnitExist, GetUnitName, IsUnitDead
local math, string, table = math, string, table
local NAME = "CorpseTracker_Research"
local MAX_ROWS, MAX_ABILITIES, MAX_EFFECTS, MAX_SECONDS = 30000, 1024, 2048, 900
local R = { active=false, maxRows=MAX_ROWS, maxSeconds=MAX_SECONDS }
-- These are progression lookup seeds from the user's UESP export (2026-10-19),
-- not claimed creation/consumption markers. Client rank IDs are authoritative.
local targets = {
    {family="mender",seed=115710}, {family="tether",seed=115926},
    {family="life",seed=115315}, {family="flesh",seed=114196},
    {family="harvest",seed=115238}, {family="grasp",seed=115177},
    {family="reanimate",seed=115410}, {family="armor",seed=115206},
    {family="bones",seed=114860}, {family="skeletal",seed=114317},
    {family="skull",seed=114108}, {family="yard",seed=115252},
    {family="siphon",seed=115924},
}
local registrations, ownedEffects, ownedCount, abilityCount = {}, {}, 0, 0
local phases = { [EFFECT_RESULT_GAINED]="gained", [EFFECT_RESULT_UPDATED]="updated",
    [EFFECT_RESULT_FADED]="faded" }

local function Finite(value)
    return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end
local function Short(value, limit)
    if type(value)~="string" then return "" end
    local cut=math.min(#value,limit or 120)
    while cut>0 do
        local nextByte=value:byte(cut+1)
        if not nextByte or nextByte<128 or nextByte>=192 then break end
        cut=cut-1
    end
    return value:sub(1,cut)
end
local function Say(key,...)
    d("|c88ddccCorpse Tracker|r "..CT.T(key,...))
end
local function Unregister()
    for _, item in ipairs(registrations) do EM:UnregisterForEvent(item.name,item.event) end
    registrations={}
    ownedEffects,ownedCount={},0
end
local function Register(suffix,event,callback,...)
    local name=NAME..suffix
    EM:RegisterForEvent(name,event,callback)
    registrations[#registrations+1]={name=name,event=event}
    if select("#",...)>0 then EM:AddFilterForEvent(name,event,...) end
end
local function Own(source)
    return source==COMBAT_UNIT_TYPE_PLAYER or source==COMBAT_UNIT_TYPE_PLAYER_PET
end
local function FriendlyTag(tag)
    return type(tag)=="string" and (tag=="player" or tag:match("^playerpet%d+$") or tag:match("^group%d+$"))
end

function R:Initialize(saved)
    self:Stop("reload",false)
    self.saved=saved
    local data=saved.research
    if type(data)~="table" or data.format~=1 or type(data.rows)~="table" then
        saved.research=nil
        return
    end
    -- Keep first observations, bounded even after malformed external edits.
    local length,write=#data.rows,0
    for read=1,math.min(length,MAX_ROWS) do
        if type(data.rows[read])=="table" then write=write+1; data.rows[write]=data.rows[read] end
    end
    for index=write+1,length do data.rows[index]=nil end
    if length>MAX_ROWS then data.truncated=true end
    local retainedBudget=Finite(data.recordedSeconds)
    if not retainedBudget then
        local ending=data.stoppedAt or (data.rows[#data.rows] and data.rows[#data.rows].t)
        data.recordedSeconds=Finite(ending) and Finite(data.startedAt) and
            math.max(0,math.min(MAX_SECONDS,ending-data.startedAt)) or 0
    else data.recordedSeconds=math.max(0,math.min(MAX_SECONDS,data.recordedSeconds)) end
    if data.recording then
        local last=data.rows[#data.rows]
        if retainedBudget and Finite(data.segmentStartedAt) and last and Finite(last.t) then
            data.recordedSeconds=math.min(MAX_SECONDS,data.recordedSeconds+
                math.max(0,last.t-data.segmentStartedAt))
        end
        data.stoppedAt,data.stopReason,data.closedOnReload=Now(),"reload",true
        if #data.rows<MAX_ROWS then
            data.rows[#data.rows+1]={kind="stop",reason="reload",t=Now(),sequence=#data.rows+1}
        end
    end
    data.recording=false
    -- Retained ability dictionaries are bounded independently of event rows.
    if type(data.abilities)~="table" then data.abilities={} end
    local kept=0
    for id,value in pairs(data.abilities) do
        kept=kept+1
        if kept>MAX_ABILITIES or type(value)~="table" then data.abilities[id]=nil end
    end
end

local function Elapsed(data, running)
    local seconds = Finite(data.recordedSeconds) and data.recordedSeconds or 0
    if running then
        seconds = seconds + math.max(0, Now() - (data.segmentStartedAt or data.startedAt))
    end
    return seconds
end
function R:Limit(reason)
    self.saved.research.truncated=true
    self:Stop(reason,false)
    CT.StopTestRecording("limit")
    Say("RESEARCH_LIMIT")
end

function R:Record(kind,data)
    if not self.active then return false end
    local log=self.saved.research
    if Elapsed(log,true)>=MAX_SECONDS or #log.rows>=MAX_ROWS-1 then
        self:Limit(#log.rows>=MAX_ROWS-1 and "row_limit" or "time_limit")
        return false
    end
    data.kind,data.t,data.sequence=kind,Now(),#log.rows+1
    log.rows[#log.rows+1]=data
    return true
end

function R:Ability(id,name)
    if not self.active or not Finite(id) or id<=0 or id~=math.floor(id) then return end
    local data=self.saved.research
    local key=tostring(id)
    if data.abilities[key] then return end
    if abilityCount>=MAX_ABILITIES then data.abilityCatalogLimited=true; return end
    abilityCount=abilityCount+1
    data.abilities[key]={name=Short(GetAbilityName(id)),observedName=Short(name)}
end

function R:Snapshot(label)
    if not self.active then return end
    local count=CT.displayCount or {}
    if not self:Record("snapshot",{label=Short(label),inCombat=IsUnitInCombat("player")==true,
        selected=CT.CopySourceSelection(),estimate=count.total,minimum=count.minimum,maximum=count.maximum,
        countMode=CT.saved.countMode}) then return end
    local tags={"player","reticleover"}
    for index=1,8 do tags[#tags+1]="playerpet"..index end
    for index=1,24 do tags[#tags+1]="group"..index end
    for _, tag in ipairs(tags) do
        if not self.active then return end
        if DoesUnitExist(tag) then
            if not self:Record("unit",{tag=tag,name=Short(GetUnitName(tag)),dead=IsUnitDead(tag)==true}) then return end
            local n=GetNumBuffs(tag)
            if Finite(n) and n>=0 then
                if n>128 then self.saved.research.snapshotBuffsLimited=true end
                for index=1,math.min(n,128) do
                    local name,beginning,ending,slot,stacks,icon,buffType,effectType,
                        abilityType,statusType,id,canClickOff,castByPlayer=GetUnitBuffInfo(tag,index)
                    -- All self/pet buffs; other units only known-own buffs.
                    if tag=="player" or tag:match("^playerpet%d+$") or castByPlayer then
                        self:Ability(id,name)
                        if not self:Record("buff",{tag=tag,ability=id,name=Short(name),slot=slot,
                            beginTime=beginning,endTime=ending,stacks=stacks,icon=Short(icon,200),
                            buffType=buffType,effectType=effectType,abilityType=abilityType,
                            statusType=statusType,canClickOff=canClickOff,castByPlayer=castByPlayer}) then return end
                    end
                end
            end
        end
    end
    for _, bar in ipairs({HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP}) do
        for slot=3,8 do
            if not self.active then return end
            local id=GetSlotBoundId(slot,bar)
            self:Ability(id)
            if not self:Record("slot",{bar=bar,slot=slot,ability=id}) then return end
        end
    end
end

local function Combat(_,result,isError,name,graphic,actionSlotType,sourceName,sourceType,
    targetName,targetType,value,powerType,damageType,log,sourceId,targetId,id,overflow)
    if not R.active or not Own(sourceType) then return end
    R:Ability(id,name)
    R:Record("combat",{ability=id,name=Short(name),result=result,error=isError,
        source=sourceId,target=targetId,sourceName=Short(sourceName),targetName=Short(targetName),
        sourceType=sourceType,targetType=targetType,amount=value,powerType=powerType,
        damageType=damageType,overflow=overflow})
end

local function Effect(_,change,slot,name,tag,beginning,ending,stacks,icon,buffType,
    effectType,abilityType,statusType,unitName,unitId,id,sourceType)
    if not R.active then return end
    local key=tostring(Finite(unitId) and unitId>0 and unitId or tag)..":"..tostring(slot)..":"..tostring(id)
    local known=ownedEffects[key]
    if not Own(sourceType) and not FriendlyTag(tag) and not known then return end
    if change==EFFECT_RESULT_FADED then
        if known then ownedEffects[key]=nil; ownedCount=ownedCount-1 end
    elseif Own(sourceType) and not known then
        if ownedCount<MAX_EFFECTS then ownedEffects[key]=true; ownedCount=ownedCount+1
        else R.saved.research.effectTrackingLimited=true end
    end
    R:Ability(id,name)
    R:Record("effect",{ability=id,name=Short(name),phase=phases[change],change=change,
        slot=slot,tag=Short(tag),beginTime=beginning,endTime=ending,stacks=stacks,
        icon=Short(icon,200),buffType=buffType,effectType=effectType,abilityType=abilityType,
        statusType=statusType,unitName=Short(unitName),unit=unitId,sourceType=sourceType,
        previouslyOwned=known==true})
end

local function ResolveVariants()
    local variants={}
    for _, target in ipairs(targets) do
        local st,line,skill=GetSpecificSkillAbilityKeysByAbilityId(target.seed)
        if st and line and skill then
            for morph=0,2 do
                for rank=1,4 do
                    local id=GetSpecificSkillAbilityInfo(st,line,skill,morph,rank)
                    if Finite(id) and id>0 then
                        variants[#variants+1]={ability=id,family=target.family,morph=morph,rank=rank}
                    end
                end
            end
        end
    end
    return variants
end

function R:Start(notify)
    self:Stop("new_test",false)
    self.saved=CT.saved
    self.saved.research={format=1,addonVersion=CT.version,apiVersion=GetAPIVersion(),
        world=GetWorldName(),language=GetCVar("language.2"),startedAt=Now(),
        recording=true,rows={},abilities={},maxRows=MAX_ROWS,maxSeconds=MAX_SECONDS,
        variants=ResolveVariants(),constants={gained=EFFECT_RESULT_GAINED,updated=EFFECT_RESULT_UPDATED,
            faded=EFFECT_RESULT_FADED,player=COMBAT_UNIT_TYPE_PLAYER,pet=COMBAT_UNIT_TYPE_PLAYER_PET,
            none=COMBAT_UNIT_TYPE_NONE,other=COMBAT_UNIT_TYPE_OTHER,
            unitCreated=EVENT_UNIT_CREATED,unitDestroyed=EVENT_UNIT_DESTROYED,unitDeath=EVENT_UNIT_DEATH_STATE_CHANGED,damage=ACTION_RESULT_DAMAGE,critical=ACTION_RESULT_CRITICAL_DAMAGE,
            effectGained=ACTION_RESULT_EFFECT_GAINED,effectDuration=ACTION_RESULT_EFFECT_GAINED_DURATION,
            effectFaded=ACTION_RESULT_EFFECT_FADED,died=ACTION_RESULT_DIED,diedXP=ACTION_RESULT_DIED_XP}}
    local data=self.saved.research
    data.recording,data.segmentStartedAt,data.stoppedAt,data.stopReason=true,Now(),nil,nil
    data.lastAddonVersion=CT.version
    data.recordedSeconds=data.recordedSeconds or 0
    abilityCount,ownedCount,ownedEffects=0,0,{}
    for _ in pairs(data.abilities) do abilityCount=abilityCount+1 end
    self.active=true
    if not self:Record("start",{scope="own_combat_and_observed_effects",
            inference="none",addonVersion=CT.version}) then return false end
    for _, source in ipairs({COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET}) do
        Register("_Combat_"..source,EVENT_COMBAT_EVENT,Combat,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,source)
    end
    Register("_Effects",EVENT_EFFECT_CHANGED,Effect)
    Register("_Cast",EVENT_ACTION_SLOT_ABILITY_USED,function(_,slot)
        if not R.active then return end
        local id=GetSlotBoundId(slot)
        local name=Short(GetSlotName(slot))
        R:Ability(id,name)
        R:Record("cast",{slot=slot,ability=id,name=name,inCombat=IsUnitInCombat("player")==true})
    end)
    Register("_CombatState",EVENT_PLAYER_COMBAT_STATE,function(_,active)
        R:Record("combat_state",{active=active})
    end)
    for _, event in ipairs({EVENT_UNIT_CREATED,EVENT_UNIT_DESTROYED,EVENT_UNIT_DEATH_STATE_CHANGED}) do
        local eventId=event
        Register("_Unit_"..eventId,eventId,function(_,tag,dead)
            if FriendlyTag(tag) or tag=="reticleover" then
                R:Record("unit_event",{event=eventId,tag=Short(tag),dead=dead,
                    name=DoesUnitExist(tag) and Short(GetUnitName(tag)) or ""})
            end
        end)
    end
    self:Snapshot("start")
    if notify and self.active then Say("RESEARCH_STARTED") end
    return self.active
end

function R:Stop(reason,snapshot)
    if not self.active then Unregister(); return false end
    if snapshot then self:Snapshot("stop") end
    if not self.active then return false end
    local data=self.saved.research
    data.recordedSeconds=math.min(MAX_SECONDS,Elapsed(data,true))
    self.active=false
    Unregister()
    data.recording,data.stoppedAt,data.stopReason=false,Now(),reason or "manual"
    -- One reserved row closes the file without deleting its beginning.
    if #data.rows<MAX_ROWS then
        data.rows[#data.rows+1]={kind="stop",reason=data.stopReason,t=Now(),sequence=#data.rows+1}
    end
    return true
end

function R:Tick()
    if self.active and Elapsed(self.saved.research,true)>=MAX_SECONDS then
        self:Limit("time_limit")
    end
end
function R:Mark(label)
    if not self.active then Say("RESEARCH_IDLE"); return false end
    label=Short(label)
    if label=="" then label="test" end
    if not self:Record("mark",{label=label}) then return false end
    self:Snapshot(label)
    Say("RESEARCH_MARK",(label:gsub("|","||")))
    return true
end
function R:Clear(keepRecording)
    local restart=self.active and keepRecording
    self:Stop("clear",false)
    if CT.saved then CT.saved.research=nil end
    if restart then self:Start(false) end
end
function R:Status()
    self:Tick()
    local data=CT.saved.research
    Say("RESEARCH_STATUS",CT.T(self.active and "ENABLED" or "DISABLED"),
        data and #data.rows or 0,MAX_ROWS)
end

-- Replace only this addon's listeners when the module itself is reloaded.
if CT.Research then CT.Research:Stop("module_reload",false) end
CT.Research=R

end

local CT = CorpseTracker
local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER
local SV = ZO_SavedVars
local root = GuiRoot
local slashCommands = SLASH_COMMANDS
local hudScene, hudUIScene = HUD_SCENE, HUD_UI_SCENE
local sceneFragment = ZO_SimpleSceneFragment
local LAM = LibAddonMenu2
local tooltip = InformationTooltip
local format = string.format
local FormatDecimal = ZO_FastFormatDecimalNumber
local CommaDelimitNumber = ZO_CommaDelimitNumber
-- Replace this addon's own callbacks safely on reinitialization.
local function RegisterEvent(event, callback)
    EM:UnregisterForEvent(CT.name, event)
    EM:RegisterForEvent(CT.name, event, callback)
end
local MAX_LOG_ROWS = 6000
local defaults = {
    x = 480, y = 340, locked = false,
    radius = 12, bbTTL = 5, archerTTL = 10, spiritTTL = 10, bannerTTL = 5, skullTTL = 5,
    capture = false, physicalOnly = false, bannerUnits = false,
    debugMode = false, displayMode = "compact", countMode = "light", squareSize = 64,
    rangeMode = "siphon", manualRange = 28, includeUnknown = true, language = "auto",
    rules = {}, log = {},
}
local watch = {
    [117715] = true, [117691] = true, [117692] = true,
    [118681] = true, [122377] = true, [118764] = true, [124003] = true,
    [227068] = true, [227072] = true, [227110] = true, [227111] = true,
    [227112] = true, [227113] = true, [227114] = true,
    [263461] = true, [263462] = true, [120612] = true,
    [220102] = true,
    [118843] = true, -- Intensive Mender own-pet effect, verified natural expiry.
    [118018] = true, -- Renewing Undeath: successful corpse extension, not ground cast/healing.
    [118913] = true, -- Own Spirit Guardian pet effect; the owner effect is not another summon.
    [117891] = true, -- Blood Sacrifice: exact resource target.
    [118817] = true, -- Enduring Undeath: final stack value is the resource quantity.
    [115926] = true, -- Restoring Tether: confirmed application to the consumed resource.
    [119372] = true, -- Bitter Harvest: one target marker per resource; 650 is duration.
    [122680] = true, -- Summoner's Armor Living Corpse, verified in the probe trace.
    [263468] = true, -- Own Malevolent Promise mark on a living enemy.
    [117850] = true, [117852] = true, [117853] = true, [117854] = true,
    [117860] = true, [115567] = true, [115548] = true,
}
local phaseNames = { [EFFECT_RESULT_GAINED] = "gained",
    [EFFECT_RESULT_UPDATED] = "updated", [EFFECT_RESULT_FADED] = "faded" }
local inCombat = false
local rawBanner, direct, frame, label, timer, question, sourceButton, background, icon
local timerShown, questionShown, lastQuestionCount
local renderedText = {}
local lastCounterSample
local lastLabelUncertain, lastTimerTenth
local unitBindings, cachedFilter, nextRangeRead = {}, nil, 0
local summons = {}
local guardians = CT.NewGuardianTracker()
local menders = CT.NewGuardianTracker()
local newConsumers = CT.NewConsumerQueue()
local lastAction
local summonSerial = 0
local knownUnits, unitStates = {}, {}
local rowSerial = 0
local pendingYard, wasteState, consumeWitness
local lastSkullBody, lastSkullMarker
local pendingSiphon, lastSiphonAt = nil, -math.huge
local yardSerial, yardCasts, yardConsumed, yardUnconfirmed = 0, 0, 0, 0
local combatBaseline = { created = 0, consumed = 0, expired = 0, unmatched = 0,
    untrackedConsumed = 0, remaining = 0, yardConsumed = 0, yardUnconfirmed = 0 }
local nextCleanup = 0
local armor = CT.NewLivingCorpse()
CT.armor = armor
local promise = CT.NewPromise()
CT.promise = promise

local function Finite(value)
    return type(value) == "number" and value == value and
        value ~= math.huge and value ~= -math.huge
end

local function NormalizeSaved()
    local saved = CT.saved
    if not saved.spiritTTLRevision then
        local previous = saved.guardianTTL
        if not Finite(previous) or previous < 1 or previous > 60 then previous = saved.menderTTL end
        if Finite(previous) and previous >= 1 and previous <= 60 then saved.spiritTTL = previous end
        saved.spiritTTLRevision = 1
    end
    saved.guardianTTL, saved.menderTTL = nil, nil
    local limits = { x = {-100000,100000}, y = {-100000,100000},
        squareSize = {40,140}, radius = {1,100}, manualRange = {1,60},
        bbTTL = {1,60}, skullTTL = {1,60}, archerTTL = {1,60}, spiritTTL = {1,60}, bannerTTL = {1,60} }
    for key, bounds in pairs(limits) do
        local value = saved[key]
        saved[key] = Finite(value) and math.max(bounds[1], math.min(bounds[2], value)) or defaults[key]
    end
    for _, key in ipairs({"locked","capture","debugMode","physicalOnly","includeUnknown"}) do
        if type(saved[key]) ~= "boolean" then saved[key] = defaults[key] or false end
    end
    if saved.rangeMode ~= "siphon" and saved.rangeMode ~= "yard" and
            saved.rangeMode ~= "manual" and saved.rangeMode ~= "none" then saved.rangeMode = "siphon" end
    if saved.language ~= "auto" and not CT.IsLanguageSupported(saved.language) then saved.language = "auto" end
    if type(saved.rules) ~= "table" then saved.rules = {} end
    for id, rule in pairs(saved.rules) do
        local number = tonumber(id)
        if not Finite(number) or number <= 0 or number ~= math.floor(number) or
                type(id) ~= "string" or type(rule) ~= "table" or
                (rule.kind ~= "create" and rule.kind ~= "consume") or
                (rule.phase ~= "gained" and rule.phase ~= "updated" and rule.phase ~= "faded") or
                (rule.kind == "create" and (not Finite(rule.ttl) or rule.ttl < 1 or rule.ttl > 60)) or
                (rule.kind == "consume" and (not Finite(rule.amount) or rule.amount < 1 or
                    rule.amount > 10 or rule.amount ~= math.floor(rule.amount))) or
                watch[number] or CT.AbilityFamily(number) then
            saved.rules[id] = nil
        end
    end
    if type(saved.log) ~= "table" then saved.log = {} end
    -- Keep the log table's identity and its newest valid rows, including a
    -- stopped recording loaded from an older or damaged SavedVariables file.
    local log, length, write = saved.log, #saved.log, 0
    for read = math.max(1, length - MAX_LOG_ROWS + 1), length do
        if type(log[read]) == "table" then write = write + 1; log[write] = log[read] end
    end
    for index = write + 1, length do log[index] = nil end
end

local function Now() return GetFrameTimeSeconds() end
local function Say(s) d("|c88ddccCorpse Tracker|r " .. s) end

local function Record(kind, data)
    if not CT.saved.capture then return end
    local log = CT.saved.log
    rowSerial = rowSerial + 1
    data.kind, data.t, data.sequence = kind, Now(), rowSerial
    data.addonVersion = CT.version
    log[#log + 1] = data
    if #log > MAX_LOG_ROWS then table.remove(log, 1) end
end

local ApplyConsumer
local function QueueConsumer(kind, amount, target, targetType)
    local now = Now()
    local cutoff = lastAction and now - lastAction.at <= 0.8 and lastAction.promiseCutoff or promise.serial
    local transaction = newConsumers:Add(kind, now, amount, target, targetType,
        CT.ledger.serial, cutoff)
    if transaction then
        consumeWitness = nil
        if kind ~= "enduring" and targetType == COMBAT_UNIT_TYPE_PLAYER_PET then
            -- The marker already identifies a physical own-pet corpse.
            -- Spend it before a near-expiry body can time out during settling.
            ApplyConsumer(newConsumers:Take(transaction), now)
        end
    end
end

ApplyConsumer = function(transaction, now)
    local left, virtual, marks = transaction.amount, 0, 0
    local identity, source, accepted
    local exact = transaction.kind ~= "enduring" and transaction.kind ~= "renewing"
    local exactVirtual = exact and
        transaction.targetType == COMBAT_UNIT_TYPE_PLAYER
    if not exact or exactVirtual then
        if armor:TryConsume(transaction.at, now) then
            virtual, left = 1, left - 1
            Record("armor_consumed", { consumer = transaction.kind, serial = transaction.serial })
        end
    end
    while left > 0 and not exactVirtual do
        local marked, unit = promise:TryConsume(transaction.at, now,
            exact and transaction.target or nil, transaction.promiseCutoff)
        if not marked then break end
        marks, left = marks + 1, left - 1
        Record("promise_consumed", { consumer = transaction.kind,
            target = unit, serial = transaction.serial })
        if exact then break end
    end
    local physical = left
    if exactVirtual then
        -- A self-targeted resource marker cannot justify spending a physical
        -- corpse if the Living Corpse fade was unavailable.
        physical = 0
        identity = virtual == 1 and "armor" or "unresolved-virtual"
    elseif physical > 0 then
        local target = exact and transaction.target or nil
        local bound = target and CT.ledger.units[target]
        if bound and bound.id > transaction.bodyCutoff then
            -- A corpse born after the marker cannot pay for this cast.
            identity = "late-target"
        else
            accepted, identity, source = CT.ledger:Consume(physical, now,
                transaction.kind .. ":" .. transaction.serial, not CT.saved.physicalOnly, target,
                { strictTarget = exact, allowUntracked = true,
                    maxBodyId = transaction.bodyCutoff })
        end
    else identity = marks > 0 and "promise" or "armor" end
    Record(transaction.kind .. "_consumed", { serial = transaction.serial,
        amount = transaction.amount, physical = physical, armor = virtual, promise = marks,
        target = transaction.target, identity = identity, source = source,
        confirmedAt = transaction.at,
        applied = (exactVirtual and virtual == 1) or
            (not exactVirtual and (physical == 0 or accepted == true)) })
    consumeWitness = nil
end

local function FlushConsumers(force)
    local now = Now()
    for _, transaction in ipairs(newConsumers:TakeReady(now, force)) do
        ApplyConsumer(transaction, now)
    end
end

local function FinishYard()
    if not pendingYard or pendingYard.counted or not pendingYard.markerAt or
        Now() - pendingYard.at > 0.8 then return end
    -- Wait for the possible Armor FADED callback before choosing a physical body.
    if (armor:Relevant(Now()) or promise:Relevant(Now())) and Now() - pendingYard.at < 0.25 then return end
    local virtual = armor:TryConsume(pendingYard.at, Now())
    local marked, markedUnit
    if not virtual then marked, markedUnit = promise:TryConsume(pendingYard.at, Now(), nil, pendingYard.promiseCutoff) end
    if not virtual and not marked and (not consumeWitness or
        math.abs(pendingYard.markerAt - consumeWitness.at) > 0.15) then return end
    if not virtual and not marked and consumeWitness.evidence == "Malevolent Promise gain" then
        -- A new mark proves a consumption, but can belong to a Siphon whose
        -- exact/self callback has not arrived yet. Let those routes reconcile
        -- before attributing this witness to the pending Yard.
        if pendingSiphon or Now() - lastSiphonAt < 0.25 then consumeWitness = nil; return end
        if Now() - consumeWitness.at < 0.25 then return end
    end
    pendingYard.counted = true
    if virtual or marked then
        yardConsumed = yardConsumed + 1
        Record(virtual and "armor_consumed" or "promise_consumed",
            { consumer = "yard", serial = pendingYard.serial, target = markedUnit })
        consumeWitness = nil
        return
    end
    if CT.ledger:Consume(1, Now(), "yard:" .. pendingYard.serial, not CT.saved.physicalOnly,
            nil, { allowUntracked = true, maxBodyId = pendingYard.maxBodyId }) then
        yardConsumed = yardConsumed + 1
        Record("yard_consumed", { serial = pendingYard.serial,
            evidence = consumeWitness.evidence, physicalAssumption = CT.saved.physicalOnly,
            untrackedPossible = true })
    end
end

local function ExpireYard()
    if pendingYard and Now() - pendingYard.at > 0.8 then
        if not pendingYard.counted then
            yardUnconfirmed = yardUnconfirmed + 1
            Record("yard_unconfirmed", { serial = pendingYard.serial })
        end
        pendingYard = nil
    end
end

local function ArmYard()
    ExpireYard()
    if pendingYard then return end -- skill event and self effect are one cast
    yardSerial, yardCasts = yardSerial + 1, yardCasts + 1
    pendingYard = { at = Now(), serial = yardSerial, promiseCutoff = promise.serial }
    Record("yard_cast", { serial = yardSerial })
end

local function WasteChanged(change, stacks, endTime, combatStack)
    local previous = wasteState
    if change == EFFECT_RESULT_FADED then wasteState = nil; return end
    if change ~= EFFECT_RESULT_GAINED and change ~= EFFECT_RESULT_UPDATED then return end
    endTime = endTime or 0
    local consumed = (change == EFFECT_RESULT_GAINED and stacks > 0 and not previous) or
        (previous and (stacks > previous.stacks or
            (stacks == 10 and previous.stacks == 10 and
                (endTime > previous.endTime + 0.01 or
                 (combatStack and Now() - (previous.stackAt or Now()) > 0.25)))))
    wasteState = { stacks = stacks, endTime = math.max(endTime, previous and previous.endTime or 0),
        stackAt = combatStack and Now() or (previous and previous.stackAt or Now()) }
    if consumed then
        consumeWitness = { at = Now(), evidence = "Nothing Wasted refresh" }
        FinishYard()
    end
end

local function SeedWaste()
    wasteState = nil
    for index = 1, GetNumBuffs("player") do
        local _, _, ending, _, stacks, _, _, _, _, _, id = GetUnitBuffInfo("player", index)
        if id == 263461 or id == 263462 then
            wasteState = { stacks = stacks, endTime = ending, stackAt = Now() }; break
        end
    end
end

local function SeedArmor()
    for index = 1, GetNumBuffs("player") do
        local _, beginning, ending, slot, _, _, _, _, _, _, id = GetUnitBuffInfo("player", index)
        if id == 122680 then armor:Effect("gained", slot, beginning, ending, Now()) end
    end
end

local function Position(tag)
    if CT.saved.countMode == "light" and not (CT.saved.debugMode and CT.saved.capture) then return nil end
    -- Public positions are used only for the player, own pets and group tags.
    -- Enemy/reticle tags remain unknown; do not probe unavailable NPC positions.
    if type(tag) ~= "string" or not (tag == "player" or tag:match("^playerpet%d+$") or
            tag:match("^group%d+$")) or not DoesUnitExist(tag) then return nil end
    local zone, x, y, z = GetUnitWorldPosition(tag)
    -- Zero coordinates commonly mean unavailable world position.
    if not Finite(zone) or zone == 0 or not Finite(x) or not Finite(y) or not Finite(z) or
            (x == 0 and y == 0 and z == 0) then return nil end
    return { zone = zone, x = x, y = y, z = z }
end

local function IsOwn(sourceType)
    return sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
end

local function SampleBanner(count, channel)
    if not Finite(count) or count < 0 or count > 2147483647 or count ~= math.floor(count) then return end
    rawBanner = { count = count, at = Now(), channel = channel }
end

local function UpdateBodyPosition(tag, unitId)
    if CT.saved.countMode == "light" then return end
    local body = unitId and CT.ledger.units[unitId]
    if body and body.expires > Now() and IsUnitDead(tag) then
        local p = Position(tag)
        if p then body.position = p end
    end
end

local function SkullIdentity(unitId)
    lastSkullMarker = { at = Now(), unitId = unitId }
    if lastSkullBody and math.abs(lastSkullBody.created - Now()) <= 0.25 then
        CT.ledger:BindIdentity(lastSkullBody, unitId)
    end
end

local function BannerCreated(unitId, tag)
    if not Finite(unitId) or unitId <= 0 or unitId ~= math.floor(unitId) then return end
    if CT.ledger:Add("banner", Now(), CT.saved.bannerTTL, tag and Position(tag),
            "banner:" .. tostring(unitId), CT.saved.bannerTTL, unitId) then
        Record("banner_created", { unit = unitId, marker = 227114 })
    end
    if tag then UpdateBodyPosition(tag, unitId) end
end

local function ConsumeSiphon(targetUnitId, targetType, maxBodyId)
    local accepted, identity, source = CT.ledger:Consume(1, Now(), "siphon-application",
        not CT.saved.physicalOnly, targetUnitId, { strictTarget = true, maxBodyId = maxBodyId })
    if accepted then
        lastSiphonAt = Now()
        Record("siphon_consumed", { target = targetUnitId or 0,
            identity = identity, source = source or "unknown", targetType = targetType })
    end
    consumeWitness = nil
end

local function FlushSiphon(force)
    if pendingSiphon and (Now() - pendingSiphon.at >= 0.25 or
            (force and not armor:Relevant(Now()) and not promise:Relevant(Now(), pendingSiphon.target))) then
        local pending = pendingSiphon
        pendingSiphon = nil
        -- Without a target ID, only bodies present when the self effect arrived
        -- can be candidates. A later BB explosion cannot be spent retroactively.
        local marked, markedUnit
        if pending.target then
            marked, markedUnit = promise:TryConsume(pending.at, Now(), pending.target, pending.promiseCutoff)
        elseif not armor:TryConsume(pending.at, Now()) then
            marked, markedUnit = promise:TryConsume(pending.at, Now(), nil, pending.promiseCutoff)
        else
            lastSiphonAt, consumeWitness = Now(), nil
            Record("armor_consumed", { consumer = "siphon" })
            return
        end
        if marked then
            lastSiphonAt, consumeWitness = Now(), nil
            Record("promise_consumed", { consumer = "siphon", target = markedUnit })
        else ConsumeSiphon(pending.target, pending.targetType, pending.maxBodyId) end
    end
end

local function QueueSiphon(target, targetType)
    if pendingSiphon then
        if target then pendingSiphon.target, pendingSiphon.targetType = target, targetType end
        return
    end
    if Now() - lastSiphonAt >= 0.25 and not pendingSiphon then
        pendingSiphon = { at = Now(), maxBodyId = CT.ledger.serial,
            promiseCutoff = promise.serial, target = target, targetType = targetType }
        Record("siphon_pending", { maxBodyId = pendingSiphon.maxBodyId })
    end
    consumeWitness = nil
end

local function YardMarker()
    if pendingYard and Now() - pendingYard.at <= 0.8 then
        -- Reconciliation may wait for virtual-resource and witness callbacks.
        -- A corpse born after this server-side activation cannot pay that Yard.
        if not pendingYard.markerAt then pendingYard.maxBodyId = CT.ledger.serial end
        pendingYard.markerAt = Now()
        FinishYard()
    end
end

local function SummonChanged(abilityId, tag, unitId, change, beginTime, endTime)
    if change == EFFECT_RESULT_GAINED and
            (not Finite(beginTime) or not Finite(endTime) or endTime - beginTime > 60) then return end
    local key = tostring(abilityId) .. ":" .. (tag == "player" and "player" or tostring(unitId))
    local previous = summons[key]
    if change == EFFECT_RESULT_GAINED and endTime - beginTime >= 19 then
        -- Owner and pet effects begin a few milliseconds apart. Merge them.
        for _, instance in pairs(summons) do
            if math.abs(instance.beginTime - beginTime) <= 0.25 then previous = instance; break end
        end
        if not previous or math.abs(previous.beginTime - beginTime) > 0.25 then
            summonSerial = summonSerial + 1
            previous = { beginTime = beginTime, endTime = endTime, serial = summonSerial }
        end
        summons[key] = previous
        if tag:match("^playerpet%d+$") then
            previous.unitId = unitId
            if previous.body then CT.ledger:BindIdentity(previous.body, unitId) end
        end
    elseif change == EFFECT_RESULT_FADED and previous then
        -- Real FADED callbacks have beginTime=endTime=0. Use cached GAINED data.
        summons[key] = nil
        local p = tag:match("^playerpet%d+$") and Position(tag) or nil
        if previous.body and p then previous.body.position = p end
        if not previous.counted and Now() - previous.beginTime >= 10 then
            previous.counted = true
            if CT.ledger:Add("skeletal?", Now(), CT.saved.archerTTL, p,
                    "skeletal:" .. previous.serial, CT.saved.archerTTL) then
                previous.body = CT.ledger.bodies[#CT.ledger.bodies]
                CT.ledger:BindIdentity(previous.body, previous.unitId)
                Record("skeletal_created", { ability = abilityId, tag = tag, serial = previous.serial })
            end
        end
    end
end

local function Cleanup(now)
    if now < nextCleanup then return end
    nextCleanup = now + 1
    guardians:Cleanup(now)
    menders:Cleanup(now)
    -- FADED/UNIT_DESTROYED may be missed during transitions. Retain a grace
    -- window for late callbacks; discarding a stale summon never creates a corpse.
    for key, instance in pairs(summons) do
        if now > instance.endTime + 60 then summons[key] = nil end
    end
    for tag in pairs(knownUnits) do
        if not DoesUnitExist(tag) then
            knownUnits[tag], unitStates[tag], unitBindings[tag] = nil, nil, nil
        end
    end
    for tag in pairs(unitBindings) do
        if not DoesUnitExist(tag) then unitBindings[tag], unitStates[tag] = nil, nil end
    end
end

local function RangeFilter()
    if cachedFilter and Now() < nextRangeRead then return cachedFilter end
    local mode, range, id = CT.saved.rangeMode
    if mode == "manual" then range = CT.saved.manualRange
    elseif mode ~= "none" then range, id = CT.ReadSkillRange(mode) end
    cachedFilter = { enabled = mode ~= "none" and range ~= nil, range = range,
        includeUnknown = CT.saved.includeUnknown, mode = mode, ability = id }
    nextRangeRead = Now() + 2
    return cachedFilter
end

local function CurrentCount()
    local selection = CT.GetSourceSelection()
    if CT.saved.countMode == "light" then
        local filter = { enabled = false, mode = "none", light = true }
        local c = armor:Project(CT.ledger:Count(Now(), nil, nil, selection), Now(), selection.armor)
        return promise:Project(c, Now(), selection.promise), filter
    end
    local filter = RangeFilter()
    local player = Position("player")
    local c = armor:Project(CT.ledger:Count(Now(), player, CT.saved.radius, selection, filter),
        Now(), selection.armor)
    return promise:Project(c, Now(), selection.promise, player, CT.saved.radius, filter), filter
end

local function SetTextIfChanged(control, text)
    if renderedText[control] ~= text then
        control:SetText(text)
        renderedText[control] = text
    end
end

local function Refresh()
    local now = Now()
    Cleanup(now)
    FlushConsumers(false)
    FlushSiphon(false)
    FinishYard()
    ExpireYard()
    local c, filter = CurrentCount()
    CT.displayCount, CT.displayFilter = c, filter
    if CT.saved.capture then
        local visible = not frame:IsHidden()
        local pending = #newConsumers.pending
        local stamp = table.concat({c.total, c.minimum or 0, c.maximum or 0,
            #CT.ledger.bodies, c.virtual or 0, c.promise or 0, pending,
            pendingSiphon and 1 or 0, visible and 1 or 0, CT.saved.countMode}, ":")
        if stamp ~= lastCounterSample then
            lastCounterSample = stamp
            Record("counter", { total=c.total, minimum=c.minimum, maximum=c.maximum,
                physical=#CT.ledger.bodies, armor=c.virtual or 0, promise=c.promise or 0,
                pending=pending, pendingSiphon=pendingSiphon~=nil, visible=visible,
                nextExpiry=c.nextExpiry, countMode=CT.saved.countMode })
        end
    end
    -- Keep consumption and expiry current while menus hide the HUD. Rendering
    -- resumes on OnShow; hidden controls need no text, colour or layout writes.
    if frame:IsHidden() then return end
    local unknownIncluded = c.unknown > 0 and (not filter.enabled or filter.includeUnknown)
    local ambiguousCount = c.uncertain or (not c.light and
        (c.minimum ~= c.maximum or unknownIncluded or c.boundsBroad or
         filter.mode == "yard" or (filter.mode ~= "none" and not filter.enabled)))
    local uncertain = CT.saved.debugMode and not c.light and ambiguousCount
    local zeroRisk = c.light and c.uncertain or
        (not c.light and c.minimum == 0 and c.maximum > 0)
    if lastLabelUncertain ~= uncertain then
        label:SetColor(1, uncertain and 0.78 or 1, uncertain and 0.35 or 1, 1)
        lastLabelUncertain = uncertain
    end
    if CT.saved.displayMode ~= "detailed" then
        SetTextIfChanged(label, FormatDecimal(CommaDelimitNumber(c.total)))
        local showTimer = c.total > 0 and c.nextExpiry ~= nil and c.nextExpiry > 0
        local showQuestion = zeroRisk == true
        if timerShown ~= showTimer or questionShown ~= showQuestion then
            timerShown, questionShown = showTimer, showQuestion
            local size = CT.saved.squareSize
            local questionWidth = math.max(14, math.floor(size * 0.25))
            label:SetDimensions(showQuestion and size - questionWidth - 2 or size,
                showTimer and size - math.max(16, math.floor(size * 0.25)) or size)
            timer:SetHidden(not showTimer)
            question:SetHidden(not showQuestion)
        end
        if showQuestion and lastQuestionCount ~= c.total then
            lastQuestionCount = c.total
            question:ClearAnchors()
            question:SetAnchor(LEFT, label, CENTER, label:GetTextWidth() / 2 + 2, 0)
        end
        -- TTL and an unidentified Yard choice are estimates. Round upwards
        -- so a living entry never displays 0.0 before its expiry.
        local tenth = showTimer and math.max(1, math.ceil(c.nextExpiry * 10 - 0.000001)) or 0
        if lastTimerTenth ~= tenth then
            SetTextIfChanged(timer, showTimer and "~" .. FormatDecimal(format("%.1f", tenth / 10)) or "")
            lastTimerTenth = tenth
        end
        return
    end
    local mode = CT.SourceLabel()
    local range = c.minimum ~= c.maximum and " " .. CT.T("POSSIBLE", c.minimum, c.maximum) or ""
    SetTextIfChanged(sourceButton, CT.T("SOURCE_BUTTON"))
    local probe = CT.T("API_MISSING")
    if direct then
        local age = now - direct.at
        probe = CT.T("API_SAMPLE", direct.verified and "API" or CT.T("CANDIDATE"),
            direct.count, format("%.0f", direct.radius), age, age > 6 and CT.T("STALE") or "")
    end
    local raw = rawBanner and CT.T("BANNER_SAMPLE", rawBanner.count, now - rawBanner.at) or CT.T("BANNER_MISSING")
    local expiry = c.nextExpiry and CT.T("TTL_EXPIRES", c.nextExpiry) or CT.T("TTL_EMPTY")
    if c.light then
        SetTextIfChanged(label, table.concat({
            CT.T("CORPSES") .. " ~" .. FormatDecimal(CommaDelimitNumber(c.total)) .. (zeroRisk and " ?" or "") .. " || " .. mode,
            CT.T("LIGHT_INFO"), CT.T("BREAKDOWN", c.breakdown.bb, c.breakdown.skull, c.breakdown.other),
            CT.T("SESSION", CT.ledger.created, CT.ledger.consumed, CT.ledger.expired),
            CT.T("YARD_STATS", yardConsumed, yardUnconfirmed, CT.ledger.untrackedConsumed, CT.ledger.unmatched),
            CT.T("TTL_ESTIMATE", expiry, CT.saved.capture and CT.T("RECORDING") or ""),
        }, "\n"))
        return
    end
    local filterText = filter.mode == "none" and CT.T("RANGE_OFF") or
        (filter.enabled and CT.T("RANGE_AVAILABLE", CT.T("RANGE_" .. filter.mode:upper()),
            filter.range, c.outside, CT.T(filter.includeUnknown and "INCLUDED" or "EXCLUDED")) or
            CT.T("RANGE_UNAVAILABLE"))
    SetTextIfChanged(label, table.concat({
        CT.T("CORPSES") .. " ~" .. FormatDecimal(CommaDelimitNumber(c.total)) .. (zeroRisk and " ?" or "") .. range .. " || " .. mode,
        CT.T("BREAKDOWN", c.breakdown.bb, c.breakdown.skull, c.breakdown.other),
        CT.T("LOCATED", format("%.0f", filter.enabled and filter.range or CT.saved.radius), c.inside, c.unknown),
        probe, raw, CT.T("SESSION", CT.ledger.created, CT.ledger.consumed, CT.ledger.expired),
        CT.T("YARD_STATS", yardConsumed, yardUnconfirmed, CT.ledger.untrackedConsumed, CT.ledger.unmatched),
        CT.T("TTL_ESTIMATE", expiry, CT.saved.capture and CT.T("RECORDING") or ""),
        CT.T(c.boundsBroad and "BOUNDS_BROAD" or "CHOICE_UNKNOWN"), filterText,
    }, "\n"))
end

function CT.SubmitRadiusSnapshot(count, radius, verified, sampledAt)
    local s = CT.ValidateSnapshot(count, radius, verified, Now(), sampledAt)
    if not s then return false end
    direct = s
    Record("radius_snapshot", { count = s.count, radius = radius, verified = s.verified })
    return true
end

function CT.ApplySettings()
    if CT.saved.countMode == "light" then CT.saved.displayMode = "compact" end
    cachedFilter, nextRangeRead = nil, 0
    unitStates = {}
    CT.ledger:Expire(Now())
    CT.ledger:SetMode(CT.saved.countMode)
    -- Font, size, language and layout changes invalidate the rendered cache.
    renderedText, lastLabelUncertain, lastTimerTenth = {}, nil, 0
    local debug = CT.saved.displayMode == "detailed"
    local size = CT.saved.squareSize
    frame:SetDimensions(debug and 660 or size, debug and 360 or size)
    frame:SetMouseEnabled(true)
    frame:SetMovable(not CT.saved.locked)
    label:ClearAnchors()
    label:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    label:SetDimensions(debug and 660 or size, debug and 326 or size)
    label:SetFont(debug and "ZoFontGame" or ("$(BOLD_FONT)|" .. math.floor(size * 0.55) .. "|soft-shadow-thick"))
    label:SetHorizontalAlignment(debug and TEXT_ALIGN_LEFT or TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(debug and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
    timerShown, questionShown, lastQuestionCount = nil, nil, nil
    local timerHeight = math.max(16, math.floor(size * 0.25))
    timer:ClearAnchors()
    timer:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, size - timerHeight)
    timer:SetDimensions(size, timerHeight)
    timer:SetFont("$(BOLD_FONT)|" .. math.max(12, math.floor(size * 0.2)) .. "|soft-shadow-thick")
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timer:SetColor(1, 1, 1, 0.9)
    SetTextIfChanged(timer, "")
    timer:SetHidden(true)
    local questionSize = math.max(14, math.floor(size * 0.25))
    question:SetDimensions(questionSize, questionSize + 6)
    question:SetFont("$(BOLD_FONT)|" .. questionSize .. "|soft-shadow-thick")
    question:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    question:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    question:SetColor(1, 1, 1, 1)
    question:SetText("?")
    question:SetHidden(true)
    sourceButton:ClearAnchors()
    sourceButton:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 326)
    sourceButton:SetDimensions(660, 26)
    sourceButton:SetHidden(not debug)
    background:SetHidden(debug)
    icon:SetDimensions(size - 6, size - 6)
    icon:SetHidden(debug)
    -- The scene fragment owns visibility. Never unhide the control from the
    -- update loop: that would put it back over inventory/settings scenes.
    if CT.hudFragment then CT.hudFragment:Refresh() end
    Refresh()
end

function CT.SourceSettingsChanged()
    Record("source_selection", { selection = CT.CopySourceSelection() })
    CT.ApplySettings()
end

local function InspectUnit(tag)
    if not CT.saved.capture or not CT.saved.debugMode then return end
    if not DoesUnitExist(tag) then unitStates[tag] = nil; return end
    local name, dead = GetUnitName(tag), IsUnitDead(tag)
    local position, player = Position(tag), Position("player")
    local distance
    if position and player and position.zone == player.zone then
        local dx, dy, dz = position.x - player.x, position.y - player.y, position.z - player.z
        distance = math.sqrt(dx * dx + dy * dy + dz * dz) / 100
    end
    local stamp = tostring(unitBindings[tag] or "") .. ":" .. tostring(dead) .. ":" ..
        tostring(distance and math.floor(distance * 2)) .. ":" ..
        tostring(distance and distance <= CT.saved.radius)
    if unitStates[tag] ~= stamp then
        unitStates[tag] = stamp
        Record("unit_observed", { tag = tag, name = name, dead = dead, position = position,
            distance = distance, inRadius = distance and distance <= CT.saved.radius })

    end
end

local function CombatEvent(_, result, isError, abilityName, _, _, sourceName,
        sourceType, targetName, targetType, hitValue, _, _, _, sourceId, targetId, abilityId)
    local family = CT.AbilityFamily(abilityId)
    -- 117860 shares Yard's name but occurs without a new cast in live logs.
    local yardEffect = CT.IsYardActivation(abilityId)
    if not watch[abilityId] and not family and not CT.saved.rules[tostring(abilityId)] then return end
    if CT.saved.capture then
        Record("combat", { ability = abilityId, name = abilityName, result = result,
            error = isError, source = sourceId, target = targetId, sourceType = sourceType,
            targetType = targetType, amount = hitValue })
    end
    if isError then return end
    if sourceType == COMBAT_UNIT_TYPE_PLAYER and result == ACTION_RESULT_EFFECT_GAINED then
        if abilityId == 117891 then QueueConsumer("blood", 1, targetId, targetType)
        elseif abilityId == 115926 and hitValue == 1 then
            QueueConsumer("tether", 1, targetId, targetType)
        elseif abilityId == 119372 and hitValue == 1 then
            QueueConsumer("harvest", 1, targetId, targetType)
        elseif abilityId == 118018 and targetType == COMBAT_UNIT_TYPE_PLAYER and hitValue == 1 then
            QueueConsumer("renewing", 1)
        elseif abilityId == 118817 and targetType == COMBAT_UNIT_TYPE_PLAYER then
            QueueConsumer("enduring", hitValue)
        end
    end
    local selfEvent = sourceType == COMBAT_UNIT_TYPE_PLAYER and targetType == COMBAT_UNIT_TYPE_PLAYER
    -- Here hitValue is a stack count for GAINED, milliseconds for DURATION.
    -- Never interpret duration/fade values as corpse counts.
    if selfEvent and result == ACTION_RESULT_EFFECT_GAINED then
        if abilityId == 263461 or abilityId == 263462 then
            WasteChanged(EFFECT_RESULT_GAINED, hitValue, 0, true)
        elseif abilityId == 227113 then
            SampleBanner(hitValue, "combat")
        elseif abilityId == 117852 or yardEffect then
            ArmYard(); YardMarker()
        elseif abilityId == 117853 then
            YardMarker()
        elseif abilityId == 227068 then
            consumeWitness = { at = Now(), evidence = "Corpseburster proc combat effect" }
            FinishYard()
        end
    end
    -- First hits can precede COMBAT_STATE(true); corpses can remain usable
    -- after COMBAT_STATE(false). The combat flag is not a corpse lifetime.
    if not IsOwn(sourceType) then return end
    if abilityId == 227114 and sourceType == COMBAT_UNIT_TYPE_PLAYER and
            targetType == COMBAT_UNIT_TYPE_PLAYER_PET and result == ACTION_RESULT_EFFECT_GAINED then
        BannerCreated(targetId)
    end
    if sourceType == COMBAT_UNIT_TYPE_PLAYER and targetType == COMBAT_UNIT_TYPE_PLAYER and
            result == ACTION_RESULT_EFFECT_GAINED and CT.IsSiphonApplication(abilityId) then
        QueueSiphon()
    end
    if sourceType == COMBAT_UNIT_TYPE_PLAYER and targetType == COMBAT_UNIT_TYPE_PLAYER_PET and
            result == ACTION_RESULT_EFFECT_GAINED then
        if abilityId == 220102 then SkullIdentity(targetId) end
    end
    if sourceType == COMBAT_UNIT_TYPE_PLAYER and targetType ~= COMBAT_UNIT_TYPE_PLAYER and
            result == ACTION_RESULT_EFFECT_GAINED and CT.IsSiphonApplication(abilityId) then
        if type(targetId) == "number" and targetId > 0 then
            if promise:Relevant(Now(), targetId) then QueueSiphon(targetId, targetType)
            else
                pendingSiphon = nil
                ConsumeSiphon(targetId, targetType)
            end
        else
            QueueSiphon()
        end
    end
    if CT.IsThirdSkull(abilityId) and sourceType == COMBAT_UNIT_TYPE_PLAYER and
            (result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE) then
        -- Shared 3 s guard: AoE/bounces cannot create additional bodies, and
        -- Venom's extra Necromancer casts can advance the chain unusually fast.
        if CT.ledger:Add("skull?", Now(), CT.saved.skullTTL, nil,
                "skull-generation", 3) then
            lastSkullBody = CT.ledger.bodies[#CT.ledger.bodies]
            if lastSkullMarker and math.abs(lastSkullMarker.at - Now()) <= 0.25 then
                CT.ledger:BindIdentity(lastSkullBody, lastSkullMarker.unitId)
            end
            Record("skull_created", { ability = abilityId, target = targetId })
        end
    end
    if (abilityId == 117715 or (family == "bones" and sourceType == COMBAT_UNIT_TYPE_PLAYER_PET)) and
            (result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE) then
        local key = sourceId and sourceId ~= 0 and "bb:" .. tostring(sourceId) or "bb-fallback"
        CT.ledger:Add("blastbones", Now(), CT.saved.bbTTL, nil,
            key, sourceId and sourceId ~= 0 and CT.saved.bbTTL or 0.25, sourceId)
        for tag, unitId in pairs(unitBindings) do
            if unitId == sourceId then UpdateBodyPosition(tag, unitId) end
        end
    end
end

local function EffectChanged(_, change, effectSlot, name, tag, beginTime, endTime, stacks,
        _, _, _, _, _, unitName, unitId, abilityId, sourceType)
    local rule = CT.saved.rules[tostring(abilityId)]
    local family = CT.AbilityFamily(abilityId)
    local yardEffect = CT.IsYardActivation(abilityId)
    if not watch[abilityId] and not family and not rule then return end
    if abilityId == 263468 then
        -- The player-only unit-tag filter would discard this enemy debuff,
        -- including the valid empty-tag route. Ownership is checked here.
        local known = promise.marks[unitId]
        local ownFade = change == EFFECT_RESULT_FADED and sourceType == COMBAT_UNIT_TYPE_NONE and
            known and known.slot == effectSlot
        if (sourceType ~= COMBAT_UNIT_TYPE_PLAYER and not ownFade) or tag == "player" or
                (type(tag) == "string" and tag:match("^playerpet%d+$")) then return end
        local transition = promise:Effect(phaseNames[change], unitId, effectSlot,
            beginTime, endTime, Now(), change ~= EFFECT_RESULT_FADED and Position(tag) or nil)
        Record("promise_effect", { phase = phaseNames[change], transition = transition,
            target = unitId, slot = effectSlot, beginTime = beginTime, endTime = endTime, tag = tag })
        if change == EFFECT_RESULT_GAINED and transition == "created" and
                Finite(beginTime) and math.abs(Now() - beginTime) <= 0.25 and
                not pendingSiphon and Now() - lastSiphonAt >= 0.25 then
            -- An actually new own mark is an independent consumption witness.
            -- Old effects revealed by changing targets and duplicate tag routes
            -- must never turn a no-corpse Yard into another spend.
            consumeWitness = { at = Now(), evidence = "Malevolent Promise gain" }
            FinishYard()
        end
        return
    end
    if sourceType == COMBAT_UNIT_TYPE_PLAYER and tag:match("^playerpet%d+$") and
            type(unitId) == "number" and unitId > 0 then
        if change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED then
            unitBindings[tag] = unitId
        end
        UpdateBodyPosition(tag, unitId)
    end
    if CT.saved.capture then
        Record("effect", { ability = abilityId, name = name, phase = phaseNames[change],
            tag = tag, beginTime = beginTime, endTime = endTime, stacks = stacks,
            unitName = unitName, unit = unitId, sourceType = sourceType })
    end
    if abilityId == 122680 and tag == "player" and
            (sourceType == COMBAT_UNIT_TYPE_PLAYER or change == EFFECT_RESULT_FADED) then
        local transition = armor:Effect(phaseNames[change], effectSlot, beginTime, endTime, Now())
        Record("armor_effect", { phase = phaseNames[change], transition = transition,
            slot = effectSlot, ending = endTime })
    end
    if abilityId == 227114 and sourceType == COMBAT_UNIT_TYPE_PLAYER and
            tag:match("^playerpet%d+$") and change == EFFECT_RESULT_GAINED then
        BannerCreated(unitId, tag)
    end
    if (family == "skeletal" or abilityId == 118681) and
            (tag == "player" or tag:match("^playerpet%d+$")) and
            sourceType == COMBAT_UNIT_TYPE_PLAYER then
        SummonChanged(abilityId, tag, unitId, change, beginTime, endTime)
    end
    if abilityId == 118913 and sourceType == COMBAT_UNIT_TYPE_PLAYER and
            (change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED) then
        guardians:Track(tag, unitId, beginTime, endTime, Now())
    end
    if abilityId == 118843 and sourceType == COMBAT_UNIT_TYPE_PLAYER and
            (change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED) then
        menders:Track(tag, unitId, beginTime, endTime, Now())
    end
    if abilityId == 220102 and sourceType == COMBAT_UNIT_TYPE_PLAYER and
            tag:match("^playerpet%d+$") and change == EFFECT_RESULT_GAINED then
        SkullIdentity(unitId)
        UpdateBodyPosition(tag, unitId)
    end
    if tag ~= "player" then return end
    if (abilityId == 263461 or abilityId == 263462) and sourceType == COMBAT_UNIT_TYPE_PLAYER then
        WasteChanged(change, stacks, endTime)
    end
    if abilityId == 227113 then
        -- One pulse can GAIN(1), UPDATE(2), then FADE(2) in ~0.1 seconds.
        -- Record the latest raw value; FADE means pulse ended, NOT zero corpses.
        SampleBanner(stacks, "effect")
    end
    if sourceType == COMBAT_UNIT_TYPE_PLAYER then
        -- 117852 starts the Avid Yard self effect; it is not consumption proof.
        if (abilityId == 117852 or yardEffect) and change == EFFECT_RESULT_GAINED then ArmYard() end
        -- 117853 is an observed Yard marker. Its meaning needs a no-corpse test;
        -- require an independent consumption witness, never count it alone.
        if (abilityId == 117853 or yardEffect) and (change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED) and
            pendingYard and Now() - pendingYard.at <= 0.8 then
            YardMarker()
        end
        if abilityId == 227068 and change == EFFECT_RESULT_GAINED then
            consumeWitness = { at = Now(), evidence = "Corpseburster proc effect" }
            FinishYard()
        end
    end
    if inCombat and (abilityId == 118764 or abilityId == 124003 or CT.IsSiphonApplication(abilityId)) and change == EFFECT_RESULT_GAINED and
            sourceType == COMBAT_UNIT_TYPE_PLAYER then
        -- A new self Siphon effect, not a tick and not a keypress. The physical
        -- corpse decrement is still an assumption if living-corpse effects exist.
        QueueSiphon()
        -- A Siphon application is another consumer, not proof for a prior Yard.
        consumeWitness = nil
    end
    if rule and phaseNames[change] == rule.phase and sourceType == COMBAT_UNIT_TYPE_PLAYER then
        local key = "rule:" .. tostring(abilityId) .. ":" .. tostring(beginTime)
        if rule.kind == "create" then
            CT.ledger:Add("rule:" .. abilityId, Now(), rule.ttl, nil, key, rule.ttl)
        elseif rule.kind == "consume" then
            CT.ledger:Consume(rule.amount or 1, Now(), key, not CT.saved.physicalOnly)
        end
    end
end

-- Each ability and source needs its own event namespace: repeated filters of
-- the same type overwrite one another rather than providing an OR condition.
local filteredAbilityIds = CT.filteredAbilityIds or {}
CT.filteredAbilityIds = filteredAbilityIds
local function AbilityNamespace(id, sourceType)
    return CT.name .. (sourceType and "_Combat_" or "_Effect_") .. id ..
        (sourceType and "_" .. sourceType or "")
end

local function UnregisterAbility(id)
    EM:UnregisterForEvent(AbilityNamespace(id), EVENT_EFFECT_CHANGED)
    EM:UnregisterForEvent(AbilityNamespace(id, COMBAT_UNIT_TYPE_PLAYER), EVENT_COMBAT_EVENT)
    EM:UnregisterForEvent(AbilityNamespace(id, COMBAT_UNIT_TYPE_PLAYER_PET), EVENT_COMBAT_EVENT)
end

for id in pairs(filteredAbilityIds) do
    UnregisterAbility(id)
    filteredAbilityIds[id] = nil
end

function CT.UpdateAbilityEventFilters()
    local wanted = {}
    for id in pairs(watch) do wanted[id] = true end
    for _, variant in ipairs(CT.variants) do wanted[variant.ability] = true end
    for id in pairs(CT.saved.rules) do wanted[tonumber(id)] = true end
    for id in pairs(filteredAbilityIds) do
        if not wanted[id] then UnregisterAbility(id); filteredAbilityIds[id] = nil end
    end
    for id in pairs(wanted) do
        if not filteredAbilityIds[id] then
            local effectName = AbilityNamespace(id)
            EM:RegisterForEvent(effectName, EVENT_EFFECT_CHANGED, EffectChanged)
            EM:AddFilterForEvent(effectName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id)
            if id ~= 263468 then
                EM:AddFilterForEvent(effectName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "player")
            end
            for _, sourceType in ipairs({ COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET }) do
                local name = AbilityNamespace(id, sourceType)
                EM:RegisterForEvent(name, EVENT_COMBAT_EVENT, CombatEvent)
                EM:AddFilterForEvent(name, EVENT_COMBAT_EVENT,
                    REGISTER_FILTER_ABILITY_ID, id, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, sourceType)
            end
            filteredAbilityIds[id] = true
        end
    end
end

local function RecordDeath(_, result, _, _, _, _, _, sourceType, targetName,
        targetType, _, _, _, _, sourceId, targetId, abilityId)
    -- Death is diagnostic evidence, never proof of an available corpse.
    Record("death", { result = result, target = targetId, targetType = targetType,
        targetName = targetName, source = sourceId, sourceType = sourceType,
        ability = abilityId, positionEstimate = nil })
end

local function UpdateDeathEventFilters()
    for _, result in ipairs({ ACTION_RESULT_DIED, ACTION_RESULT_DIED_XP }) do
        local name = CT.name .. "_Death_" .. result
        EM:UnregisterForEvent(name, EVENT_COMBAT_EVENT)
        if CT.saved.capture then
            EM:RegisterForEvent(name, EVENT_COMBAT_EVENT, RecordDeath)
            EM:AddFilterForEvent(name, EVENT_COMBAT_EVENT,
                REGISTER_FILTER_COMBAT_RESULT, result, REGISTER_FILTER_IS_ERROR, false)
        end
    end
end

local function SaveCombatSummary(reason)
    FlushConsumers(true)
    FlushSiphon(true)
    FinishYard()
    ExpireYard()
    CT.ledger:Expire(Now())
    armor:Expire(Now())
    promise:Expire(Now())
    local summary = { at = Now(), created = CT.ledger.created - combatBaseline.created,
        consumed = CT.ledger.consumed - combatBaseline.consumed,
        expired = CT.ledger.expired - combatBaseline.expired,
        unmatched = CT.ledger.unmatched - combatBaseline.unmatched,
        untrackedConsumed = CT.ledger.untrackedConsumed - combatBaseline.untrackedConsumed,
        remaining = #CT.ledger.bodies, carried = combatBaseline.remaining,
        yardConsumed = yardConsumed - combatBaseline.yardConsumed,
        yardUnconfirmed = yardUnconfirmed - combatBaseline.yardUnconfirmed,
        banner = rawBanner, sourceSelection = CT.CopySourceSelection(), addonVersion = CT.version,
        countMode = CT.saved.countMode, displayMode = CT.saved.displayMode, debugMode = CT.saved.debugMode,
        armorCreated = armor.created - (combatBaseline.armorCreated or 0),
        armorConsumed = armor.consumed - (combatBaseline.armorConsumed or 0),
        armorExpired = armor.expired - (combatBaseline.armorExpired or 0),
        armorRemaining = armor.active and 1 or 0,
        promiseCreated = promise.created - (combatBaseline.promiseCreated or 0),
        promiseConsumed = promise.consumed - (combatBaseline.promiseConsumed or 0),
        promiseExpired = promise.expired - (combatBaseline.promiseExpired or 0),
        promiseRemaining = promise:Size(Now()),
        endedBy = reason }
    if CT.saved.capture and (summary.created > 0 or summary.consumed > 0 or
            summary.armorCreated > 0 or summary.armorConsumed > 0 or
            summary.promiseCreated > 0 or summary.promiseConsumed > 0 or not CT.saved.lastCombat) then
        CT.saved.lastCombat = summary
    end
    Record("combat_summary", summary)
    -- Include leading hits and out-of-combat events since the preceding summary.
    combatBaseline = { created = CT.ledger.created, consumed = CT.ledger.consumed,
        expired = CT.ledger.expired, unmatched = CT.ledger.unmatched,
        untrackedConsumed = CT.ledger.untrackedConsumed, remaining = #CT.ledger.bodies,
        yardConsumed = yardConsumed, yardUnconfirmed = yardUnconfirmed,
        armorCreated = armor.created, armorConsumed = armor.consumed, armorExpired = armor.expired,
        promiseCreated = promise.created, promiseConsumed = promise.consumed, promiseExpired = promise.expired }
    return summary
end

local function Reset(reason)
    reason = reason or "manual"
    -- Activation can arrive before COMBAT_STATE(false). Archive the current
    -- segment before clearing it, so the following empty end cannot hide it.
    if inCombat then SaveCombatSummary("reset:" .. reason) end
    CT.ledger = CT.NewLedger(CT.saved.countMode)
    armor = CT.NewLivingCorpse(); CT.armor = armor
    promise = CT.NewPromise(); CT.promise = promise
    rawBanner, direct = nil, nil
    summons = {}
    guardians = CT.NewGuardianTracker()
    menders = CT.NewGuardianTracker()
    newConsumers, lastAction = CT.NewConsumerQueue(), nil
    pendingYard, consumeWitness = nil, nil
    lastSkullBody, lastSkullMarker = nil, nil
    pendingSiphon, lastSiphonAt = nil, -math.huge
    yardCasts, yardConsumed, yardUnconfirmed = 0, 0, 0
    combatBaseline = { created = 0, consumed = 0, expired = 0, unmatched = 0,
        untrackedConsumed = 0, remaining = 0, yardConsumed = 0, yardUnconfirmed = 0 }
    SeedWaste()
    SeedArmor()
    unitStates, unitBindings = {}, {}
    -- Keep seen tags until UNIT_DESTROYED; resetting the ledger must not make
    -- an already observed corpse look newly created.
    Record("reset", { reason = reason })
end

local function DumpAPI(silent)
    -- ESO can reject even reading private function values while iterating _G.
    -- Use only the documented public version API; never inspect globals.
    local probe = { version = GetAPIVersion(), discovery = "disabled_private_api" }
    if CT.saved.capture then CT.saved.apiProbe = probe end
    if not silent then Say(CT.T("CHAT_API", probe.version)) end
    Record("api_probe", probe)
end

local function Slots(silent)
    for slot = 3, 8 do
        local id = GetSlotBoundId(slot)
        local row = { slot = slot, ability = id, name = GetSlotName(slot),
            usable = IsSlotUsable(slot), targetFailure = ActionSlotHasTargetFailure(slot),
            rangeFailure = ActionSlotHasRangeFailure(slot), costFailure = ActionSlotHasCostFailure(slot) }
        Record("slot", row)
        if not silent then Say(CT.T("CHAT_SLOT",
            slot, row.name, id, tostring(row.usable), tostring(row.targetFailure),
            tostring(row.rangeFailure), tostring(row.costFailure))) end
    end
end

function CT.ClearLogs()
    lastCounterSample = nil
    CT.saved.log = {}
    CT.Research:Clear(true)
end

function CT.ClearDiagnostics()
    CT.Research:Clear(false)
    CT.saved.capture = false
    UpdateDeathEventFilters()
    CT.saved.log, rowSerial = {}, 0
    CT.saved.variants, CT.saved.apiProbe, CT.saved.lastCombat = nil, nil, nil
    CT.saved.diagnosticStartedAt = nil
    unitStates = {}
end

function CT.StartDiagnostics(reason, append)
    lastCounterSample = nil
    -- Begin a fresh recording without throwing away corpses already in play.
    -- Capture resumes append a new state snapshot; only a new test clears it.
    if not append then CT.ClearDiagnostics() end
    CT.saved.capture = true
    UpdateDeathEventFilters()
    CT.saved.diagnosticStartedAt = Now()
    unitStates = {}
    CT.ledger:Expire(Now())
    armor:Expire(Now())
    promise:Expire(Now())
    combatBaseline = { created = CT.ledger.created, consumed = CT.ledger.consumed,
        expired = CT.ledger.expired, unmatched = CT.ledger.unmatched,
        untrackedConsumed = CT.ledger.untrackedConsumed, remaining = #CT.ledger.bodies,
        yardConsumed = yardConsumed, yardUnconfirmed = yardUnconfirmed,
        armorCreated = armor.created, armorConsumed = armor.consumed, armorExpired = armor.expired,
        promiseCreated = promise.created, promiseConsumed = promise.consumed, promiseExpired = promise.expired }
    local bodies = {}
    for _, body in ipairs(CT.ledger.bodies) do
        bodies[#bodies + 1] = { id = body.id, unitId = body.unitId,
            source = body.source, created = body.created, expires = body.expires,
            position = body.position }
    end
    Record("diagnostic_start", { reason = reason or "manual", bodies = bodies,
        created = CT.ledger.created, consumed = CT.ledger.consumed,
        expired = CT.ledger.expired, untrackedConsumed = CT.ledger.untrackedConsumed,
        armorEnding = armor.active and armor.active.ending,
        armorCreated = armor.created, armorConsumed = armor.consumed, armorExpired = armor.expired,
        promiseCreated = promise.created, promiseConsumed = promise.consumed, promiseExpired = promise.expired,
        promiseMarks = promise:Snapshot(Now()),
        rangeMode = CT.saved.rangeMode,
        sourceSelection = CT.CopySourceSelection(),
        debugMode = CT.saved.debugMode, displayMode = CT.saved.displayMode, countMode = CT.saved.countMode })
    CT.DiscoverAbilities()
    CT.UpdateAbilityEventFilters()
    CT.saved.variants = CT.variants
    Record("variants", { abilities = CT.variants })
    DumpAPI(true)
    Slots(true)
end

function CT.SetDebugMode(enabled)
    local previous = CT.saved.debugMode
    CT.saved.debugMode = enabled == true
    if CT.saved.debugMode ~= previous then
        Record("diagnostic_mode", { debugMode = CT.saved.debugMode })
    end
    CT.ApplySettings()
end

function CT.SetDisplayMode(mode)
    if mode ~= "compact" and mode ~= "detailed" then return end
    if mode == "detailed" and CT.saved.countMode == "light" then return end
    if CT.saved.displayMode ~= mode then Record("display_mode", { mode = mode }) end
    CT.saved.displayMode = mode
    CT.ApplySettings()
end

function CT.SetCountMode(mode)
    if mode ~= "light" and mode ~= "extended" then return end
    if CT.saved.countMode ~= mode then Record("count_mode", { mode = mode }) end
    CT.saved.countMode = mode
    CT.ApplySettings()
end

function CT.StopTestRecording(reason)
    FlushConsumers(true)
    CT.Research:Stop(reason or "manual", true)
    CT.saved.capture = false
    UpdateDeathEventFilters()
    unitStates = {}
    Refresh()
end

function CT.SetCapture(enabled)
    if not enabled then CT.StopTestRecording("manual"); return true end
    if CT.saved.capture and CT.Research.active then return true end
    -- Starting a session clears diagnostics only; current corpses and settings stay.
    CT.StartDiagnostics("new_test")
    if not CT.Research:Start(false) then
        CT.StopTestRecording("limit")
        return false
    end
    Refresh()
    return true
end

local function Command(text)
    if type(text) ~= "string" then return end
    local args = {}
    for a in text:gmatch("%S+") do args[#args + 1] = a end
    local cmd = args[1] or "help"
    if cmd == "settings" then
        if LAM and CT.settingsPanel then LAM:OpenToPanel(CT.settingsPanel)
        else Say(CT.T("CHAT_DEPENDENCY")) end
    elseif cmd == "debug" then
        CT.SetDebugMode(args[2] == "on")
    elseif cmd == "view" then CT.SetDisplayMode(args[2])
    elseif cmd == "mode" then CT.SetCountMode(args[2])
    elseif cmd == "test" then
        if args[2] and args[2] ~= "on" and args[2] ~= "off" then
            Say("/crpst test [on||off]"); return
        end
        local enabled = args[2] == "on" or (not args[2] and not (CT.saved.capture or CT.Research.active))
        CT.SetCapture(enabled)
        Say(CT.T("CHAT_CAPTURE", CT.T(CT.saved.capture and "ENABLED" or "DISABLED")))
    elseif cmd == "mark" then
        CT.Research:Mark(table.concat(args, " ", 2))
    elseif cmd == "research" then CT.Research:Status()
    elseif cmd == "capture" then
        CT.SetCapture(args[2] == "on")
        Say(CT.T("CHAT_CAPTURE", CT.T(CT.saved.capture and "ENABLED" or "DISABLED")))
    elseif cmd == "clearlog" then CT.ClearLogs(); Say(CT.T("CHAT_CLEARED"))
    elseif cmd == "reset" then Reset(); Say(CT.T("CHAT_RESET"))
    elseif cmd == "lock" or cmd == "unlock" then
        CT.saved.locked = cmd == "lock"
        CT.ApplySettings()
    elseif cmd == "radius" and tonumber(args[2]) and tonumber(args[2]) > 0 then
        CT.saved.radius = math.min(100, tonumber(args[2])); Say(CT.T("CHAT_RADIUS", CT.saved.radius))
    elseif cmd == "sources" then
        if LAM and CT.settingsPanel then LAM:OpenToPanel(CT.settingsPanel)
        else Say(CT.T("CHAT_DEPENDENCY")) end
    elseif cmd == "ttl" and (args[2] == "bb" or args[2] == "archer" or args[2] == "spirit" or args[2] == "guardian" or args[2] == "mender" or args[2] == "banner" or args[2] == "skull") and
            tonumber(args[3]) and tonumber(args[3]) > 0 then
        local source = (args[2] == "guardian" or args[2] == "mender") and "spirit" or args[2]
        CT.saved[source .. "TTL"] = math.min(60, tonumber(args[3]))
        Say(CT.T("CHAT_TTL"))
    elseif cmd == "physical" then
        CT.saved.physicalOnly = args[2] == "on"
        Say(CT.T("CHAT_PHYSICAL", CT.T(CT.saved.physicalOnly and "ENABLED" or "AMBIGUOUS")))
    elseif cmd == "bannerunits" then
        CT.saved.bannerUnits = false
        Say(CT.T("BANNER_TIP"))
    elseif cmd == "probe" then DumpAPI()
    elseif cmd == "slots" then Slots()
    elseif cmd == "variants" then
        CT.DiscoverAbilities()
        CT.UpdateAbilityEventFilters()
        if CT.saved.capture then CT.saved.variants = CT.variants end
        Record("variants", { abilities = CT.variants })
        Say(CT.T("CHAT_VARIANTS", #CT.variants))
    elseif cmd == "rule" and (args[2] == "create" or args[2] == "consume") and
            Finite(tonumber(args[3])) and tonumber(args[3]) > 0 and
            tonumber(args[3]) == math.floor(tonumber(args[3])) and
            (args[4] == "gained" or args[4] == "updated" or args[4] == "faded") and
            tonumber(args[5]) and tonumber(args[5]) > 0 and
            not watch[tonumber(args[3])] and not CT.AbilityFamily(tonumber(args[3])) then
        local id = tostring(math.floor(tonumber(args[3])))
        CT.saved.rules[id] = { kind = args[2], phase = args[4],
            ttl = math.max(1, math.min(60, tonumber(args[5]))),
            amount = math.max(1, math.min(10, math.floor(tonumber(args[5])))) }
        CT.UpdateAbilityEventFilters()
        Say(CT.T("CHAT_RULE", id))
    elseif cmd == "unrule" and args[2] then
        CT.saved.rules[args[2]] = nil
        CT.UpdateAbilityEventFilters()
    elseif cmd == "status" then
        local c = CurrentCount()
        Say("v" .. CT.version .. " || " .. CT.T("CHAT_STATUS1",
            CT.SourceLabel(), c.total, c.minimum, c.maximum,
            c.breakdown.bb, c.breakdown.skull, c.breakdown.other))
        Say(CT.T("CHAT_STATUS2",
            CT.ledger.created, CT.ledger.consumed, CT.ledger.untrackedConsumed,
            CT.ledger.expired, CT.ledger.unmatched,
            CT.ledger.guessed, #CT.saved.log))
        Say(CT.T("CHAT_STATUS3", yardCasts, yardConsumed, yardUnconfirmed))
    else
        Say(CT.T("COMMANDS"))
        Say("/crpst settings; view compact||detailed; mode light||extended; debug on||off; test [on||off]; mark LABEL; research; probe; slots; variants; reset; status; clearlog; lock||unlock")
        Say("/crpst sources; radius N; ttl bb||archer||spirit||banner||skull N; physical on||off")
        Say("/crpst rule create||consume ID gained||updated||faded TTL_OR_AMOUNT; unrule ID")
    end
end

local function Initialize(_, addonName)
    if addonName ~= CT.name then return end
    EM:UnregisterForEvent(CT.name, EVENT_ADD_ON_LOADED)
    CT.saved = SV:NewAccountWide("CorpseTrackerSaved", 1, nil, defaults, GetWorldName())
    CT.DiscoverAbilities()
    NormalizeSaved()
    CT.saved.visible = nil -- Retire the old Show counter setting, including hidden profiles.
    if not CT.saved.ttlRevision then
        for name, ttl in pairs({ bbTTL = 5, skullTTL = 5, archerTTL = 10, bannerTTL = 5 }) do
            if CT.saved[name] == 6 then CT.saved[name] = ttl end
        end
        CT.saved.ttlRevision = 1
    end
    CT.NormalizeSourceSettings(CT.saved)
    CT.saved.bannerUnits = false -- Name-based experimental adapter retired.
    -- Old compact profiles never supported explicit recording. Migrate them
    -- once, then preserve recordings independently of the display mode.
    if not CT.saved.captureRevision then
        if not CT.saved.debugMode then CT.ClearDiagnostics() end
        CT.saved.captureRevision = 1
    end
    if not CT.saved.displayRevision then
        CT.saved.displayMode = CT.saved.debugMode and "detailed" or "compact"
        CT.saved.debugMode, CT.saved.displayRevision = false, 1
    end
    if CT.saved.displayMode ~= "detailed" then CT.saved.displayMode = "compact" end
    if CT.saved.countMode ~= "extended" then CT.saved.countMode = "light" end
    if CT.saved.countMode == "light" then CT.saved.displayMode = "compact" end
    for _, row in ipairs(CT.saved.log) do
        local sequence = tonumber(row.sequence)
        if Finite(sequence) and sequence >= 0 and sequence <= 1e12 then
            rowSerial = math.max(rowSerial, math.floor(sequence))
        end
    end
    CT.saved.capture = false
    UpdateDeathEventFilters()
    CT.SelectLanguage(CT.saved.language)
    CT.Research:Initialize(CT.saved)
    CT.saved.addonVersion = CT.version
    CT.ledger = CT.NewLedger(CT.saved.countMode)
    SeedWaste()
    SeedArmor()
    inCombat = IsUnitInCombat("player")
    frame = WM:CreateControl("CorpseTrackerWindow", root, CT_TOPLEVELCONTROL)
    frame:SetHidden(true)
    CT.hudFragment = sceneFragment:New(frame)
    CT.hudFragment:SetConditional(function() return true end)
    hudScene:AddFragment(CT.hudFragment)
    hudUIScene:AddFragment(CT.hudFragment)
    frame:SetDimensions(660, 360)
    frame:SetAnchor(TOPLEFT, root, TOPLEFT, CT.saved.x, CT.saved.y)
    frame:SetMouseEnabled(not CT.saved.locked)
    frame:SetMovable(not CT.saved.locked)
    frame:SetClampedToScreen(true)
    frame:SetHandler("OnMoveStop", function(self)
        CT.saved.x, CT.saved.y = self:GetLeft(), self:GetTop()
    end)
    frame:SetHandler("OnMouseUp", function(_, button, upInside)
        if button == MOUSE_BUTTON_INDEX_RIGHT and upInside then Command("sources") end
    end)
    frame:SetHandler("OnMouseEnter", function(self)
        if not tooltip or not InitializeTooltip then return end
        InitializeTooltip(tooltip, self, RIGHT, 8, 0)
        local function AddLines(text, font, r, g, b)
            for line in text:gmatch("[^\n]+") do
                tooltip:AddLine(line, font, r, g, b, RIGHT,
                    MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_RIGHT, true)
            end
        end
        AddLines("Corpse Tracker", "ZoFontWinH4", 1, 1, 1)
        AddLines(CT.T("COUNT_MODE") .. ": " ..
            CT.T(CT.saved.countMode == "light" and "LIGHT" or "EXTENDED"), "ZoFontGame", 0.8, 1, 0.9)
        tooltip:AddVerticalPadding(6)
        AddLines(CT.T("SOURCES"), "ZoFontGameBold", 1, 1, 1)
        AddLines((CT.SourceLabel():gsub(", ", "\n")), "ZoFontGame", 0.8, 1, 0.9)
        tooltip:AddVerticalPadding(6)
        AddLines(CT.T("TOOLTIP_HINT"), "ZoFontGame", 0.8, 0.8, 0.8)
    end)
    frame:SetHandler("OnMouseExit", function()
        if tooltip and ClearTooltip then ClearTooltip(tooltip) end
    end)
    background = WM:CreateControl("CorpseTrackerBackground", frame, CT_BACKDROP)
    background:SetAnchorFill(frame)
    background:SetCenterColor(0.02, 0.02, 0.02, 0.8)
    background:SetEdgeColor(0.65, 0.75, 0.7, 1)
    background:SetEdgeTexture("", 1, 1, 0, 0)
    background:SetMouseEnabled(false)
    background:SetDrawLayer(DL_BACKGROUND)
    icon = WM:CreateControl("CorpseTrackerIcon", frame, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, frame, TOPLEFT, 3, 3)
    -- Custom corpse artwork; this texture is cosmetic only.
    icon:SetTexture("CorpseTracker/Textures/corpse.dds")
    icon:SetAlpha(0.55)
    icon:SetDrawLayer(DL_CONTROLS)
    icon:SetMouseEnabled(false)
    label = WM:CreateControl("CorpseTrackerText", frame, CT_LABEL)
    label:SetDrawLayer(DL_TEXT)
    label:SetMouseEnabled(false)
    label:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    label:SetDimensions(660, 326)
    label:SetFont("ZoFontGame")
    label:SetColor(0.8, 1, 0.9, 1)
    timer = WM:CreateControl("CorpseTrackerTimer", frame, CT_LABEL)
    timer:SetDrawLayer(DL_TEXT)
    timer:SetMouseEnabled(false)
    timer:SetHidden(true)
    question = WM:CreateControl("CorpseTrackerQuestion", frame, CT_LABEL)
    question:SetDrawLayer(DL_TEXT)
    question:SetMouseEnabled(false)
    question:SetHidden(true)
    sourceButton = WM:CreateControl("CorpseTrackerSources", frame, CT_BUTTON)
    sourceButton:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 326)
    sourceButton:SetDimensions(660, 26)
    sourceButton:SetFont("ZoFontGame")
    sourceButton:SetMouseEnabled(true)
    sourceButton:SetNormalFontColor(0.8, 1, 0.9, 1)
    sourceButton:SetMouseOverFontColor(1, 1, 1, 1)
    sourceButton:SetPressedFontColor(0.8, 1, 0.9, 1)
    sourceButton:SetEnabled(true)
    sourceButton:SetHandler("OnClicked", function() Command("sources") end)
    frame:SetHandler("OnShow", function() Refresh() end)
    CT.UpdateAbilityEventFilters()
    RegisterEvent(EVENT_PLAYER_COMBAT_STATE, function(_, active)
        if active == inCombat then return end
        inCombat = active
        Record("combat_state", { active = active })
        if not active then
            SaveCombatSummary("combat_end")
        end
    end)
    RegisterEvent(EVENT_PLAYER_ACTIVATED, function()
        Reset("player_activated"); CT.DiscoverAbilities(); knownUnits = {}; inCombat = IsUnitInCombat("player")
        CT.UpdateAbilityEventFilters()
    end)
    RegisterEvent(EVENT_UNIT_CREATED, function(_, tag)
        guardians:Forget(tag)
        menders:Forget(tag)
        knownUnits[tag] = true; unitStates[tag] = nil; unitBindings[tag] = nil; InspectUnit(tag)
    end)
    EM:AddFilterForEvent(CT.name, EVENT_UNIT_CREATED, REGISTER_FILTER_UNIT_TAG_PREFIX, "playerpet")
    RegisterEvent(EVENT_UNIT_DESTROYED, function(_, tag)
        Record("unit_destroyed", { tag = tag })
        guardians:Forget(tag)
        menders:Forget(tag)
        knownUnits[tag], unitStates[tag], unitBindings[tag] = nil, nil, nil
    end)
    EM:AddFilterForEvent(CT.name, EVENT_UNIT_DESTROYED, REGISTER_FILTER_UNIT_TAG_PREFIX, "playerpet")
    RegisterEvent(EVENT_UNIT_DEATH_STATE_CHANGED, function(_, tag, dead)
        local summon = dead and guardians:Death(tag, Now())
        if summon then
            local ttl = CT.saved.spiritTTL
            if CT.ledger:Add("guardian", Now(), ttl, Position(tag),
                    "guardian:" .. tostring(summon.unitId), ttl, summon.unitId) then
                Record("guardian_created", { unit = summon.unitId, tag = tag,
                    expires = Now() + ttl })
            end
        end
        local mender = dead and menders:Death(tag, Now())
        -- The latest trace shows no persistent corpse when Mender ends after
        -- combat: death and destruction arrive together. Do not infer one.
        if mender and inCombat then
            local ttl = CT.saved.spiritTTL
            if CT.ledger:Add("mender", Now(), ttl, Position(tag),
                    "mender:" .. tostring(mender.unitId), ttl, mender.unitId) then
                Record("mender_created", { unit = mender.unitId, tag = tag,
                    expires = Now() + ttl })
            end
        end
        knownUnits[tag] = true; InspectUnit(tag)
    end)
    EM:AddFilterForEvent(CT.name, EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "playerpet")
    RegisterEvent(EVENT_ACTION_SLOT_ABILITY_USED, function(_, slot)
        lastAction = { at = Now(), promiseCutoff = promise.serial }
        local id = GetSlotBoundId(slot)
        Record("skill_used", { slot = slot, ability = id })
        if id == 117850 or CT.AbilityFamily(id) == "yard" then ArmYard() end
    end)
    EM:RegisterForUpdate(CT.name, 200, function()
        CT.Research:Tick()
        if CT.saved.countMode == "extended" and CT.saved.rangeMode ~= "none" then
            for tag, unitId in pairs(unitBindings) do
                if DoesUnitExist(tag) then UpdateBodyPosition(tag, unitId)
                else unitBindings[tag] = nil end
            end
        end
        if CT.saved.capture and CT.saved.debugMode then
            InspectUnit("reticleover")
            for tag in pairs(knownUnits) do InspectUnit(tag) end
        end
        Refresh()
    end)
    slashCommands["/crpst"] = Command
    CT.ApplySettings()
    CT.RegisterSettings()
end

RegisterEvent(EVENT_ADD_ON_LOADED, Initialize)
