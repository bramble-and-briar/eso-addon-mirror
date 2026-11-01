-- Small standalone estimate; no enumeration of nearby corpses is available.
-- Event IDs observed in Necromancer combat traces; no third-party code bundled.
SiphonZahlCounter = {}
local C = SiphonZahlCounter
local bodies, seen, pets = {}, {}, {}
local pendingSpend
local siphonCast
local liveDiagnostics={}
local petUnits,corpsePositions={},{}
local lastRange={inside=0,outside=0,unknown=0,radius=8}
local diagnostics
local observedDeaths={}
local lastSpend = -math.huge
local spendIds = { [115924]=true, [118008]=true, [118763]=true }
local otherConsumers = { [115252]=true, [117805]=true, [117850]=true,
    [115926]=true, [118122]=true, [118279]=true, [115238]=true,
    [118623]=true, [118639]=true }
local function Record(kind,data)
    if not diagnostics or not diagnostics.debugEnabled then return end
    local rows=diagnostics.debugLog
    if #rows>=300 then table.remove(rows,1) end
    data=data or {};data.kind=kind;data.time=GetFrameTimeSeconds()
    data.version="0.6.9"
    data.inCombat=IsUnitInCombat("player")==true
    liveDiagnostics[kind]=data
    rows[#rows+1]=data
end
function C.GetDiagnosticsText()
    local action=liveDiagnostics.ability_used or {}
    local swap=liveDiagnostics.weapon_pair_changed or {}
    local consumer=liveDiagnostics.consumer_event or {}
    local unknown=liveDiagnostics.unmatched_consumption or {}
    local uncertain=liveDiagnostics.uncertain or {}
    local api=GetAPIVersion and GetAPIVersion() or "?"
    local platform=ZO_IsConsoleOrGameCoreUI and ZO_IsConsoleOrGameCoreUI() and "Konsole" or "PC/Gamepad"
    return "Siphon Zahl 0.6.9 | API "..tostring(api).." | "..platform..
        "\nAktion: "..tostring(action.ability or "-").." | Waffenpaar: "..tostring(swap.pair or "-")..
        "\nVerbrauch: "..tostring(consumer.ability or "-").." | Ergebnis: "..tostring(consumer.result or "-")..
        " | Zieltyp: "..tostring(consumer.targetType or "-")..
        "\nUnzugeordnetes Ziel: "..tostring(unknown.target or "-")..
        " | Unsicher: "..tostring(uncertain.reason or "nein")..
        "\nRadius: "..tostring(lastRange.radius).."m | Innen: "..lastRange.inside..
        " | Aussen: "..lastRange.outside.." | Position unbekannt: "..lastRange.unknown
end
local function WorldPosition(tag)
    if not GetUnitWorldPosition or not DoesUnitExist or not DoesUnitExist(tag) then return end
    local zone,x,y,z=GetUnitWorldPosition(tag)
    if type(zone)~="number" or zone<=0 or type(x)~="number" or type(y)~="number"
        or type(z)~="number" or x~=x or y~=y or z~=z
        or math.abs(x)==math.huge or math.abs(y)==math.huge or math.abs(z)==math.huge
        or (x==0 and y==0 and z==0) then return end
    return {zone=zone,x=x,y=y,z=z}
end
local function CaptureCorpsePosition(tag)
    local id=petUnits[tag]
    if not id or not IsUnitDead or not IsUnitDead(tag) then return end
    local position=WorldPosition(tag)
    if position then corpsePositions[id]={position=position,at=GetFrameTimeSeconds()} end
end
function C.ConfigureDiagnostics(settings)
    diagnostics=settings
    if type(settings.debugLog)~="table" then settings.debugLog={} end
    while #settings.debugLog>300 do table.remove(settings.debugLog,1) end
end
local function MarkUncertain(reason,cutoff)
    local affected=0
    for _,body in ipairs(bodies) do
        if not cutoff or body.created<=cutoff then
            body.uncertain=true;body.reason=reason;affected=affected+1
        end
    end
    Record("uncertain",{reason=reason,affected=affected})
end
local function Clean(now)
    for index=#bodies,1,-1 do
        if bodies[index].ending<=now then
            local body=bodies[index]
            Record("expired",{key=body.key,source=body.source,created=body.created,ending=body.ending})
            table.remove(bodies,index)
        end
    end
    for key, ending in pairs(seen) do if ending<=now then seen[key]=nil end end
    for id,entry in pairs(corpsePositions) do if now-entry.at>15 then corpsePositions[id]=nil end end
    for tag, pet in pairs(pets) do if now>pet.ending+2 then pets[tag]=nil end end
    if pendingSpend and now>=pendingSpend+0.25 then
        MarkUncertain("Verbrauch ohne eindeutige Leichenzuordnung",pendingSpend)
        pendingSpend=nil;lastSpend=now
    end
end
local function Add(key, now, guard, ttl, source)
    Clean(now)
    if seen[key] then return end
    seen[key]=now+guard
    bodies[#bodies+1]={key=key,created=now,ending=now+(ttl or 5),uncertain=false,source=source}
    Record("created",{key=key,source=source,ttl=ttl or 5})
end
local function Spend(now, targetId)
    Clean(now)
    local key="unit:"..tostring(targetId)
    if seen["spent:"..key] then return true end
    for i, body in ipairs(bodies) do
        if body.key==key then
            table.remove(bodies,i);seen["spent:"..key]=now+6
            Record("consumed",{key=key})
            pendingSpend=nil;lastSpend=now;return true
        end
    end
    local death=targetId and observedDeaths[targetId]
    if death and now-death.at<=60 and death.targetType==COMBAT_UNIT_TYPE_NONE
        and (death.sourceType==COMBAT_UNIT_TYPE_PLAYER or death.sourceType==COMBAT_UNIT_TYPE_PLAYER_PET) then
        -- PTS trace: Siphon can consume the actual slain NPC (same unit ID),
        -- while the separately tracked Skull/Blastbones bodies remain intact.
        -- This identity evidence is not a claim about NPC corpse lifetime.
        seen["spent:"..key]=now+6
        pendingSpend=nil;lastSpend=now
        Record("external_corpse_consumed",{target=targetId,deathAgo=now-death.at})
        return true
    end
    local candidates={}
    for _,body in ipairs(bodies) do candidates[#candidates+1]=body.key end
    Record("unmatched_consumption",{target=targetId,deathAgo=death and now-death.at,
        deathResult=death and death.result,candidates=candidates})
    -- Siphon might have used an untracked NPC corpse or virtual resource.
    -- Preserve an upper-bound estimate instead of claiming exact consumption.
    -- A self notification often arrives before the identifying pet event.
    -- Give both routes time to resolve instead of flagging every cast unknown.
    if now-lastSpend>=0.4 and not pendingSpend then pendingSpend=now end
end
function C.Snapshot()
    Clean(GetFrameTimeSeconds())
    for tag in pairs(petUnits) do CaptureCorpsePosition(tag) end
    local radius=diagnostics and diagnostics.radiusMeters or 8
    if type(radius)~="number" or radius~=radius then radius=8 end
    radius=math.max(1,math.min(28,radius))
    local filter=diagnostics and diagnostics.rangeEnabled==true
    local player=filter and WorldPosition("player")
    local minimum,total,outside,unknown=0,0,0,0
    for _,body in ipairs(bodies) do
        local id=tonumber(body.key:match("^unit:(%d+)$"))
        local entry=id and corpsePositions[id]
        local p=entry and entry.position
        local include=not filter
        if filter then
            if p and player and p.zone==player.zone then
                local dx,dy,dz=p.x-player.x,p.y-player.y,p.z-player.z
                include=dx*dx+dy*dy+dz*dz<=(radius*100)^2
                if not include then outside=outside+1 end
            elseif p and player and p.zone~=player.zone then outside=outside+1
            else unknown=unknown+1 end
        end
        if include then
            total=total+1
            if not body.uncertain then minimum=minimum+1 end
        end
    end
    lastRange={inside=total,outside=outside,unknown=unknown,radius=radius}
    return {total=total,minimum=minimum,uncertain=minimum<total,rangeUnknown=unknown,rangeOutside=outside}
end
local function Combat(_, result, isError, name, graphic, slotType, sourceName,
    sourceType, targetName, targetType, value, powerType, damageType, log,
    sourceId, targetId, abilityId)
    if isError then return end
    local now=GetFrameTimeSeconds()
    if result==ACTION_RESULT_DIED or result==ACTION_RESULT_DIED_XP
            or result==ACTION_RESULT_KILLING_BLOW then
            if type(targetId)=="number" and targetId>0 then
                for id,death in pairs(observedDeaths) do
                    if now-death.at>60 then observedDeaths[id]=nil end
                end
                local size=0;for _ in pairs(observedDeaths) do size=size+1 end
                if size<256 or observedDeaths[targetId] then
                    observedDeaths[targetId]={at=now,result=result,sourceType=sourceType,targetType=targetType}
                end
            end
            Record("unit_death_observed",{result=result,source=sourceId,sourceType=sourceType,
                target=targetId,targetType=targetType,ability=abilityId})
    end
    if sourceType~=COMBAT_UNIT_TYPE_PLAYER and sourceType~=COMBAT_UNIT_TYPE_PLAYER_PET then return end
    if spendIds[abilityId] or otherConsumers[abilityId] then
        Record("consumer_event",{ability=abilityId,result=result,target=targetId,targetType=targetType,
            source=sourceId,sourceType=sourceType,amount=value})
    end
    if sourceType==COMBAT_UNIT_TYPE_PLAYER and targetType==COMBAT_UNIT_TYPE_PLAYER_PET
        and (result==ACTION_RESULT_EFFECT_GAINED or result==ACTION_RESULT_EFFECT_GAINED_DURATION) then
        Record("own_pet_marker",{ability=abilityId,result=result,target=targetId,source=sourceId,amount=value})
    end
    local damage=result==ACTION_RESULT_DAMAGE or result==ACTION_RESULT_CRITICAL_DAMAGE
    if damage and ((sourceType==COMBAT_UNIT_TYPE_PLAYER_PET and
        (abilityId==117691 or abilityId==117692 or abilityId==117715)) or abilityId==117715) then
        local hasId=type(sourceId)=="number" and sourceId>0
        Add(hasId and "unit:"..sourceId or "blastbones-fallback",now,hasId and 6 or 0.4)
    elseif (abilityId==220102 or abilityId==227114) and sourceType==COMBAT_UNIT_TYPE_PLAYER
        and targetType==COMBAT_UNIT_TYPE_PLAYER_PET and result==ACTION_RESULT_EFFECT_GAINED then
        local hasId=type(targetId)=="number" and targetId>0
        local source=abilityId==227114 and "banner" or "skull"
        Add(hasId and "unit:"..targetId or source.."-fallback",now,hasId and 6 or 3,5,source)
    elseif sourceType==COMBAT_UNIT_TYPE_PLAYER and spendIds[abilityId]
        and result==ACTION_RESULT_EFFECT_GAINED then
        -- Slotting/weapon swaps can reapply passive effects. Only a confirmed
        -- action-slot activation can open a new Siphon consumption transaction.
        if siphonCast and not siphonCast.resolved and now-siphonCast.at<=1.5 then
            if Spend(now,targetId) then siphonCast.resolved=true end
        else
            Record("siphon_refresh_ignored",{ability=abilityId,target=targetId,targetType=targetType})
        end
    elseif sourceType==COMBAT_UNIT_TYPE_PLAYER and result==ACTION_RESULT_EFFECT_GAINED then
        -- Recorded consumer markers are distinct from a keypress or a cast.
        if abilityId==117891 or (abilityId==115926 and value==1)
            or (abilityId==119372 and value==1) then
            Spend(now,targetId)
        elseif (abilityId==118018 and targetType==COMBAT_UNIT_TYPE_PLAYER and value==1)
            or (abilityId==118817 and targetType==COMBAT_UNIT_TYPE_PLAYER and value>0)
            or (abilityId==227068 and targetType==COMBAT_UNIT_TYPE_PLAYER) then
            -- Reconcile a shared proc with identifying Siphon events first.
            Spend(now,nil)
        end
    end
end
local petEffects={ [118913]="guardian", [118843]="mender",
    [114317]="skeletal", [118680]="skeletal", [118726]="skeletal",
    [118681]="skeletal", [122377]="skeletal", [118738]="skeletal" }
local function PetTag(tag)
    return type(tag)=="string" and tag:match("^playerpet%d+$")~=nil
end
local function SkeletalEnd(pet,now,route)
    if not pet or pet.kind~="skeletal" or pet.counted then return end
    local natural=math.abs(now-pet.ending)<=1
    local matureFade=route=="effect_faded" and pet.ending-pet.beginning>=19
        and now-pet.beginning>=10
    if not natural and not matureFade then return end
    pet.counted=true
    Add("unit:"..pet.unitId,now,12,10,"skeletal")
    Record("skeletal_end",{unit=pet.unitId,route=route,expectedEnd=pet.ending})
end
local function Effect(_,change,slot,name,tag,beginning,ending,stacks,icon,
    buffType,effectType,abilityType,statusType,unitName,unitId,abilityId,sourceType)
    if not PetTag(tag) then return end
    local now=GetFrameTimeSeconds()
    if type(unitId)=="number" and unitId>0 then
        -- Bind only observed own pet effects, never enemy or group coordinates.
        if (sourceType==COMBAT_UNIT_TYPE_PLAYER or sourceType==COMBAT_UNIT_TYPE_PLAYER_PET)
            and (change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED or petUnits[tag]==unitId) then
            petUnits[tag]=unitId;CaptureCorpsePosition(tag)
        end
    end
    Record("pet_effect",{ability=abilityId,change=change,tag=tag,unit=unitId,
        sourceType=sourceType,beginning=beginning,ending=ending,stacks=stacks})
    if (abilityId==227114 or abilityId==220102) and change==EFFECT_RESULT_GAINED
        and sourceType==COMBAT_UNIT_TYPE_PLAYER and type(unitId)=="number" and unitId>0 then
        Add("unit:"..unitId,now,6,5,abilityId==227114 and "banner" or "skull")
        return
    end
    local kind=petEffects[abilityId]
    if not kind then return end
    if (change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED)
        and sourceType==COMBAT_UNIT_TYPE_PLAYER and type(unitId)=="number" and unitId>0
        and type(beginning)=="number" and type(ending)=="number"
        and ending>now and beginning<=now+0.5 and ending>beginning and ending-beginning<=60 then
        local old=pets[tag]
        if old and old.unitId==unitId and math.abs(old.beginning-beginning)<0.5 then
            old.ending=ending
        else
            pets[tag]={unitId=unitId,kind=kind,beginning=beginning,ending=ending,counted=false}
        end
    elseif change==EFFECT_RESULT_FADED then
        local pet=pets[tag]
        -- Late fade events may belong to an older occupant of the pet slot.
        if kind=="skeletal" and pet and pet.unitId==unitId then
            SkeletalEnd(pet,now,"effect_faded")
        end
    end
end
local function PetDeath(_,tag,dead)
    if PetTag(tag) and dead then CaptureCorpsePosition(tag) end
    local pet=PetTag(tag) and pets[tag]
    if PetTag(tag) then
        Record("pet_death",{tag=tag,dead=dead,unit=pet and pet.unitId,
            source=pet and pet.kind,expectedEnd=pet and pet.ending})
    end
    if not dead or not pet or pet.counted then return end
    local now=GetFrameTimeSeconds()
    -- Count recognized summons at their natural end, not arbitrary despawns.
    if math.abs(now-pet.ending)>1 then return end
    -- Corpse creation is independent of the player's combat state.
    pet.counted=true
    Add("unit:"..pet.unitId,now,12,10,pet.kind)
end
function C.Initialize()
    local name="SiphonZahlCounter"
    EVENT_MANAGER:RegisterForEvent(name,EVENT_COMBAT_EVENT,Combat)
    EVENT_MANAGER:RegisterForEvent(name,EVENT_EFFECT_CHANGED,Effect)
    EVENT_MANAGER:RegisterForEvent(name,EVENT_UNIT_DEATH_STATE_CHANGED,PetDeath)
    EVENT_MANAGER:RegisterForEvent(name,EVENT_UNIT_CREATED,function(_,tag)
        if PetTag(tag) then Record("pet_created",{tag=tag});pets[tag]=nil;petUnits[tag]=nil end
    end)
    EVENT_MANAGER:RegisterForEvent(name,EVENT_UNIT_DESTROYED,function(_,tag)
        if PetTag(tag) then
            CaptureCorpsePosition(tag)
            local pet=pets[tag]
            Record("pet_destroyed",{tag=tag,unit=pet and pet.unitId,source=pet and pet.kind})
            SkeletalEnd(pet,GetFrameTimeSeconds(),"unit_destroyed")
            pets[tag]=nil
            petUnits[tag]=nil
        end
    end)
    EVENT_MANAGER:RegisterForEvent(name,EVENT_ACTION_SLOT_ABILITY_USED,function(_,slot)
        local ability=GetSlotBoundId(slot)
        Record("ability_used",{ability=ability})
        if spendIds[ability] then siphonCast={at=GetFrameTimeSeconds(),resolved=false} end
        -- A skill press alone does not prove corpse consumption.
    end)
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
        EVENT_MANAGER:RegisterForEvent(name,EVENT_ACTIVE_WEAPON_PAIR_CHANGED,function(_,pair,locked)
            Record("weapon_pair_changed",{pair=pair,locked=locked})
        end)
    end
    EVENT_MANAGER:RegisterForEvent(name,EVENT_PLAYER_ACTIVATED,function()
        bodies,seen,pets,observedDeaths={},{},{},{};pendingSpend=nil;siphonCast=nil;lastSpend=-math.huge
        liveDiagnostics={}
        petUnits,corpsePositions={},{}
    end)
end
