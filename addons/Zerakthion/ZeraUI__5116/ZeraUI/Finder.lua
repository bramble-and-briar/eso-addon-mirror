-- Effect ID Finder. Opt-in and time-limited: nothing is registered while idle.
-- While recording, every buff/debuff you (or your pet) apply is listed once
-- per effect and target type, and linked to the skill you cast just before
-- it. Casting the same skill a few times shows which effects really belong
-- to it ("seen after 3 of 3 casts").
ZeraUIFinder={}
local F=ZeraUIFinder
F.__index=F
local NS="ZeraUIFinder"
local LIMIT=150
local RECORD_MS=60000
local LINK_MS=1500 -- an effect starting this soon after a cast belongs to it

local function clean(name) return type(name)=="string" and name:gsub("%^.*$","") or "" end
local function scopeOf(tag,debuff)
    if tag=="player" then return "self" end
    if type(tag)=="string" and tag:match("^group%d+$") then return "group" end
    if debuff then return "enemy" end
    return "other"
end

function F.New()
    return setmetatable({results={},byKey={},casts={},castOrder={},active=false,ignored=0,listeners={}},F)
end
function F:OnChange(fn) self.listeners[#self.listeners+1]=fn end
function F:Notify() for _,fn in ipairs(self.listeners) do pcall(fn) end end
function F:Clear()
    self.results={}; self.byKey={}; self.casts={}; self.castOrder={}; self.ignored=0; self.lastCast=nil
    self.status=nil; self:Notify()
end
function F:Stop(reason)
    if not self.active then return end
    self.active=false
    EVENT_MANAGER:UnregisterForEvent(NS,EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(NS.."Pet",EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForUpdate(NS)
    self.status={reason or "stopped",#self.results}
    self:Notify()
end
function F:Start()
    if self.active then self:Stop("restarted") end
    if not EVENT_EFFECT_CHANGED or not REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE or not COMBAT_UNIT_TYPE_PLAYER then
        self.status={"unavailable",0}; self:Notify(); return false
    end
    self:Clear()
    self.active=true; self.deadline=GetFrameTimeMilliseconds()+RECORD_MS
    local function record(...) self:Record(...) end
    EVENT_MANAGER:RegisterForEvent(NS,EVENT_EFFECT_CHANGED,record)
    EVENT_MANAGER:AddFilterForEvent(NS,EVENT_EFFECT_CHANGED,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
    if COMBAT_UNIT_TYPE_PLAYER_PET then
        EVENT_MANAGER:RegisterForEvent(NS.."Pet",EVENT_EFFECT_CHANGED,record)
        EVENT_MANAGER:AddFilterForEvent(NS.."Pet",EVENT_EFFECT_CHANGED,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER_PET)
    end
    EVENT_MANAGER:RegisterForUpdate(NS,500,function()
        if GetFrameTimeMilliseconds()>=self.deadline then self:Stop("finished") else self:Notify() end
    end)
    self:Notify()
    return true
end
function F:SecondsLeft()
    return self.active and math.max(0,math.ceil((self.deadline-GetFrameTimeMilliseconds())/1000)) or 0
end
-- Called for every successful bar cast while recording (cheap otherwise).
-- also: a primed Ulfsild's Contingency fires on this cast, so the effects
-- that follow belong to it as well.
function F:NoteCast(key,abilityId,name,icon,also)
    if not self.active or not key then return end
    local c=self.casts[key]
    if not c then
        c={key=key,id=abilityId,name=clean(name),icon=icon,count=0}
        self.casts[key]=c; self.castOrder[#self.castOrder+1]=key
    end
    c.count=c.count+1
    local at=GetFrameTimeMilliseconds()
    self.serial=(self.serial or 0)+1
    self.lastCast={key=key,also=also~=key and also or nil,at=at,serial=self.serial}
end
function F:Add(id,name,icon,tag,debuff,seconds,unitName,mine,live)
    local scope=scopeOf(tag,debuff)
    local k=id..":"..scope
    local r=self.byKey[k]
    local now=GetFrameTimeMilliseconds()
    if not r then
        if #self.results>=LIMIT then self.ignored=self.ignored+1; return end
        r={id=id,name=clean(name)~="" and clean(name) or clean(GetAbilityName and GetAbilityName(id) or ""),icon=(icon and icon~="") and icon or (GetAbilityIcon and GetAbilityIcon(id)) or "",
            scope=scope,duration=0,hits=0,unit=clean(unitName),after={},afterSerial={},first=now,mine=mine}
        if r.name=="" then r.name="#"..id end
        self.byKey[k]=r; self.results[#self.results+1]=r
    end
    r.hits=r.hits+1; r.last=now
    if seconds and seconds>r.duration then r.duration=seconds end
    local cast=live and self.lastCast
    if cast and now-cast.at<=LINK_MS then
        -- Count once per cast, however many targets the effect reached.
        for _,key in ipairs({cast.key,cast.also or false}) do
            if key and r.afterSerial[key]~=cast.serial then
                r.afterSerial[key]=cast.serial
                r.after[key]=(r.after[key] or 0)+1
            end
        end
    end
    return r
end
function F:Record(_,change,_,name,unitTag,beginTime,endTime,_,icon,buffType,effectType,_,_,unitName,_,id,source)
    if not self.active then return end
    if source~=COMBAT_UNIT_TYPE_PLAYER and (not COMBAT_UNIT_TYPE_PLAYER_PET or source~=COMBAT_UNIT_TYPE_PLAYER_PET) then return end
    if change~=EFFECT_RESULT_GAINED and change~=EFFECT_RESULT_UPDATED then return end
    if type(id)~="number" or id<=0 then return end
    local seconds=0
    if type(beginTime)=="number" and type(endTime)=="number" and endTime>beginTime then seconds=endTime-beginTime end
    local debuff=BUFF_EFFECT_TYPE_DEBUFF~=nil and (effectType==BUFF_EFFECT_TYPE_DEBUFF or buffType==BUFF_EFFECT_TYPE_DEBUFF)
    self:Add(id,name,icon,unitTag,debuff,seconds,unitName,true,true)
end
-- What is on you or your target right now; works without recording.
function F:Snapshot(tag)
    if not GetNumBuffs or not GetUnitBuffInfo then return 0 end
    if tag~="player" and (not DoesUnitExist or not DoesUnitExist(tag)) then return 0 end
    local n=0
    for i=1,GetNumBuffs(tag) or 0 do
        local name,start,finish,_,_,icon,_,effectType,_,_,id,_,mine=GetUnitBuffInfo(tag,i)
        if type(id)=="number" and id>0 then
            local seconds=(tonumber(finish) or 0)>(tonumber(start) or 0) and finish-start or 0
            local debuff=BUFF_EFFECT_TYPE_DEBUFF~=nil and effectType==BUFF_EFFECT_TYPE_DEBUFF
            local r=self:Add(id,name,icon,tag=="player" and "player" or "reticleover",debuff,seconds,GetUnitName and GetUnitName(tag) or "",mine,false)
            if r then r.snapshot=true; r.mine=r.mine or mine; n=n+1 end
        end
    end
    self:Notify()
    return n
end
-- Results for display. With a skill key: effects linked to that skill first,
-- by how many of its casts they followed; everything else afterwards.
function F:List(key,onlyLinked)
    local out={}
    for _,r in ipairs(self.results) do
        if not onlyLinked or (key and (r.after[key] or 0)>0) then out[#out+1]=r end
    end
    table.sort(out,function(a,b)
        local la,lb=key and a.after[key] or 0,key and b.after[key] or 0
        if la~=lb then return la>lb end
        if (a.last or 0)~=(b.last or 0) then return (a.last or 0)>(b.last or 0) end
        return a.id<b.id
    end)
    return out
end
function F:CastCount(key) local c=key and self.casts[key]; return c and c.count or 0 end
