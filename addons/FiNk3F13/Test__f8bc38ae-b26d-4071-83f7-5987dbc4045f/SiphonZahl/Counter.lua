-- Tracks the own corpse sources observed in the user's lifecycle tests.
-- No assumed corpse lifetime: count requires a marked, existing dead own unit.
SiphonZahlCounter={}
local C=SiphonZahlCounter
local EM=EVENT_MANAGER
local units,resources,spent={},{},{}
local cast
local bonesDamage={[117691]=true,[117692]=true,[117715]=true}
local petMarkers={[220102]="skull",[118681]="skeletal_archer"}
local siphon={[115924]=true,[118008]=true,[118763]=true}
local function Pet(tag) return type(tag)=="string" and tag:match("^playerpet%d+$")~=nil end
local function ValidId(id) return type(id)=="number" and id>0 end
local function Forget(tag)
    local id=units[tag]
    if id then resources[id]=nil;spent[id]=nil end
    units[tag]=nil
end
local function Bind(tag,id)
    if not Pet(tag) or not ValidId(id) then return end
    if units[tag] and units[tag]~=id then Forget(tag) end
    units[tag]=id
end
local function Mark(id,source)
    if not ValidId(id) or spent[id] or resources[id] then return end
    local count=0
    for _ in pairs(resources) do count=count+1 end
    if count>=128 then
        local removed=false
        for key in pairs(resources) do
            local bound=false
            for _,boundId in pairs(units) do if key==boundId then bound=true;break end end
            if not bound then resources[key]=nil;removed=true;break end
        end
        if not removed then return end
    end
    resources[id]={source=source}
end
local function Position(tag)
    if not GetUnitRawWorldPosition then return end
    local zone,x,y,z=GetUnitRawWorldPosition(tag)
    if type(zone)~="number" or zone<=0 then return end
    if type(x)~="number" or type(y)~="number" or type(z)~="number" then return end
    for _,v in ipairs({x,y,z}) do
        if v~=v or math.abs(v)==math.huge then return end
    end
    if x==0 and z==0 then return end
    return {zone=zone,x=x,y=y,z=z}
end
function C.Snapshot()
    local player=DoesUnitExist and DoesUnitExist("player") and Position("player")
    local heading
    if GetMapPlayerPosition then
        local _,_,h=GetMapPlayerPosition("player")
        if type(h)=="number" and h==h and math.abs(h)~=math.huge then heading=h end
    end
    local total,unknown,outside=0,0,0
    for tag,id in pairs(units) do
        if DoesUnitExist and not DoesUnitExist(tag) then
            Forget(tag)
        elseif resources[id] and not spent[id] and IsUnitDead and IsUnitDead(tag)==true then
            local p=Position(tag)
            if not p or not player or not heading then
                unknown=unknown+1
            elseif p.zone~=player.zone then outside=outside+1
            else
                local dx,dy,dz=p.x-player.x,p.y-player.y,p.z-player.z
                local horizontal=math.sqrt(dx*dx+dz*dz)
                local forward=-dx*math.sin(heading)-dz*math.cos(heading)
                if dx*dx+dy*dy+dz*dz<=1100^2 and
                    (horizontal<0.01 or forward>=horizontal*math.sqrt(0.5)-0.000001) then
                    total=total+1
                else outside=outside+1 end
            end
        end
    end
    return {total=total,minimum=total,uncertain=false,rangeUnknown=unknown,
        rangeOutside=outside,rangeFallback=false,directionUnknown=heading==nil}
end
function C.Initialize()
    local name="SiphonZahlCounter"
    EM:RegisterForEvent(name,EVENT_EFFECT_CHANGED,function(_,change,slot,effectName,tag,beginning,
        ending,stacks,icon,buffType,effectType,abilityType,statusType,unitName,id,ability,sourceType)
        if not Pet(tag) then return end
        if change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED then
            if sourceType==COMBAT_UNIT_TYPE_PLAYER or sourceType==COMBAT_UNIT_TYPE_PLAYER_PET then Bind(tag,id) end
        end
        if change==EFFECT_RESULT_GAINED and petMarkers[ability] and sourceType==COMBAT_UNIT_TYPE_PLAYER then
            -- Archer marker identifies the summon, not a corpse. Snapshot
            -- counts it only while ESO exposes this exact unit as dead.
            Mark(id,petMarkers[ability])
        end
        -- FADED is deliberately ignored: the traces show it at corpse birth.
    end)
    EM:RegisterForEvent(name,EVENT_COMBAT_EVENT,function(_,result,isError,effectName,graphic,slotType,
        sourceName,sourceType,targetName,targetType,value,powerType,damageType,log,sourceId,targetId,ability)
        if isError then return end
        if (result==ACTION_RESULT_DAMAGE or result==ACTION_RESULT_CRITICAL_DAMAGE)
            and sourceType==COMBAT_UNIT_TYPE_PLAYER_PET and bonesDamage[ability] then
            Mark(sourceId,"blastbones")
        elseif result==ACTION_RESULT_EFFECT_GAINED and sourceType==COMBAT_UNIT_TYPE_PLAYER
            and targetType==COMBAT_UNIT_TYPE_PLAYER_PET and petMarkers[ability] then
            Mark(targetId,petMarkers[ability])
        elseif result==ACTION_RESULT_EFFECT_GAINED and sourceType==COMBAT_UNIT_TYPE_PLAYER
            and siphon[ability] and cast and not cast.resolved
            and GetFrameTimeSeconds()-cast.at<=1.5 and resources[targetId] then
            resources[targetId]=nil;spent[targetId]=true;cast.resolved=true
        end
    end)
    EM:RegisterForEvent(name,EVENT_ACTION_SLOT_ABILITY_USED,function(_,slot)
        local ability=GetSlotBoundId(slot)
        -- This correlates cast/response; it never expires a corpse.
        cast=siphon[ability] and {at=GetFrameTimeSeconds(),resolved=false} or nil
    end)
    EM:RegisterForEvent(name,EVENT_UNIT_CREATED,function(_,tag) if Pet(tag) then Forget(tag) end end)
    EM:RegisterForEvent(name,EVENT_UNIT_DESTROYED,function(_,tag)
        if Pet(tag) and DoesUnitExist and not DoesUnitExist(tag) then Forget(tag) end
    end)
    EM:RegisterForEvent(name,EVENT_PLAYER_ACTIVATED,function() units,resources,spent={},{},{};cast=nil end)
end
