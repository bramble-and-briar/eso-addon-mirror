------------------------------------------------------------
-- RYTICTANK TANKSTATS v3.1 - local-reference optimization
-- Tank-focused combat report. Command: /tankstats
-- Original implementation; architecture informed by live testing.
------------------------------------------------------------
RyticTank = RyticTank or {}
local RyticTank = RyticTank
RyticTank.Stats = RyticTank.Stats or {}
local S=RyticTank.Stats
local EM,WM=EVENT_MANAGER,WINDOW_MANAGER

-- Cache frequently used globals/functions while preserving all Stats behavior.
local GetGameTimeMilliseconds=GetGameTimeMilliseconds
local GetAdvancedStatValue=GetAdvancedStatValue
local tonumber=tonumber
local tostring=tostring
local string_format=string.format

local function statsEnabled()
    return not RyticTank.saved or not RyticTank.saved.stats or RyticTank.saved.stats.enabled ~= false
end


S.current=nil
S.last=nil
S.effectSlots={}
S.viewFight=nil
S.viewSavedIndex=nil
S.debuffSlots={}
S.combatEffectSlots={}

local function has(v) return v~=nil end
local DAMAGE={}
local BLOCKED={}
local HEAL={}
if has(ACTION_RESULT_DAMAGE) then DAMAGE[ACTION_RESULT_DAMAGE]=true end
if has(ACTION_RESULT_CRITICAL_DAMAGE) then DAMAGE[ACTION_RESULT_CRITICAL_DAMAGE]=true end
if has(ACTION_RESULT_DOT_TICK) then DAMAGE[ACTION_RESULT_DOT_TICK]=true end
if has(ACTION_RESULT_DOT_TICK_CRITICAL) then DAMAGE[ACTION_RESULT_DOT_TICK_CRITICAL]=true end
if has(ACTION_RESULT_BLOCKED_DAMAGE) then DAMAGE[ACTION_RESULT_BLOCKED_DAMAGE]=true BLOCKED[ACTION_RESULT_BLOCKED_DAMAGE]=true end
if has(ACTION_RESULT_BLOCKED_CRITICAL_DAMAGE) then DAMAGE[ACTION_RESULT_BLOCKED_CRITICAL_DAMAGE]=true BLOCKED[ACTION_RESULT_BLOCKED_CRITICAL_DAMAGE]=true end
if has(ACTION_RESULT_DAMAGE_SHIELDED) then DAMAGE[ACTION_RESULT_DAMAGE_SHIELDED]=true end
if has(ACTION_RESULT_HEAL) then HEAL[ACTION_RESULT_HEAL]=true end
if has(ACTION_RESULT_CRITICAL_HEAL) then HEAL[ACTION_RESULT_CRITICAL_HEAL]=true end
if has(ACTION_RESULT_HOT_TICK) then HEAL[ACTION_RESULT_HOT_TICK]=true end
if has(ACTION_RESULT_HOT_TICK_CRITICAL) then HEAL[ACTION_RESULT_HOT_TICK_CRITICAL]=true end

local function ms() return GetGameTimeMilliseconds() end
local function sec() return ms()/1000 end
local function pct(a,b) if not b or b<=0 then return 0 end return (a or 0)*100/b end
local function fmt(n)
    n=math.floor(tonumber(n) or 0)
    local s=tostring(n)
    while true do local x,c=s:gsub("^(-?%d+)(%d%d%d)","%1,%2"); s=x; if c==0 then break end end
    return s
end
local function cap(s,n)
    s=tostring(s or "Unknown")
    if #s>n then return s:sub(1,n-1).."…" end
    return s
end
local function safe(fn,default,...)
    if type(fn)~="function" then return default end
    local ok,a,b,c=pcall(fn,...)
    if not ok then return default end
    return a,b,c
end
local function power(pt)
    local cur,maxv=0,0
    local a,b=safe(GetUnitPower,0,"player",pt)
    cur=tonumber(a) or 0
    if type(GetUnitPowerMax)=="function" then maxv=tonumber(safe(GetUnitPowerMax,0,"player",pt)) or 0
    else maxv=tonumber(b) or 0 end
    return cur,maxv
end
local function stat(id)
    if not id then return 0 end
    return tonumber(safe(GetPlayerStat,0,id)) or 0
end
local function adv(id)
    if type(GetAdvancedStatValue)~="function" then return 0 end
    local ok,a,b,c=pcall(GetAdvancedStatValue,id)
    if not ok then return 0 end
    if id==ADVANCED_STAT_DISPLAY_TYPE_BLOCK_MITIGATION then return tonumber(c) or 0 end
    return tonumber(b) or 0
end
local function isBlocking()
    return type(IsBlockActive)=="function" and IsBlockActive() or false
end
local function name(s)
    if not s or s=="" then return "Unknown" end
    if type(zo_strformat)=="function" then return zo_strformat("<<C:1>>",s) end
    return s
end

local function fightNew()
    return {start=ms(),finish=0,damage=0,blockedDamage=0,shieldedDamage=0,hits=0,
        blockedHits=0,unblockedHits=0,largest=0,healing=0,enemies={},abilities={},heals={},buffs={},
        directDamage=0,dotDamage=0,aoeDamage=0,otherDamage=0,potentialMisses={},
        blockSeconds=0,blockStart=nil,lowH=100,lowS=100,lowM=100,
        resourceSamples=0,prevH=nil,prevS=nil,prevM=nil,
        healthGain=0,staminaGain=0,magickaGain=0,
        healthDrain=0,staminaDrain=0,magickaDrain=0,
        statRanges={},
        potentialMissDamage=0,potentialPrevented=0,potentialBlockedDamage=0,
        -- Rolling last incoming hits; frozen on player death for quick wipe diagnosis.
        recentHits={},deathHits=nil,died=false,
        debuffs={},debuffTargets={},bossTargetId=nil,bossTargetName=nil}
end
local function fightTime(f)
    if not f then return 0 end
    return math.max(0,(((f.finish or 0)>0 and f.finish or ms())-f.start)/1000)
end
local function bucket(t,key,label,value,icon)
    key=tostring(key or label or "unknown")
    local v=t[key]
    if not v then v={name=name(label),amount=0,count=0,icon=icon}; t[key]=v end
    v.amount=v.amount+(tonumber(value) or 0); v.count=v.count+1
end

local function rangeSample(f,key,value)
    value=tonumber(value); if not f or not value then return end
    f.statRanges=f.statRanges or {}
    local r=f.statRanges[key]
    if not r then f.statRanges[key]={low=value,high=value}
    else
        if value<r.low then r.low=value end
        if value>r.high then r.high=value end
    end
end

local function rangeText(f,key)
    local r=f and f.statRanges and f.statRanges[key]
    if not r then return "LOW --   HIGH --" end
    return "LOW "..fmt(r.low).."   HIGH "..fmt(r.high)
end

local function closeBuffSlot(f,slot,t)
    local st=S.effectSlots[slot]
    if not st then return end
    S.effectSlots[slot]=nil
    local b=f.buffs[st.id]
    if not b then return end
    b.activeCount=math.max(0,(b.activeCount or 1)-1)
    if b.activeCount==0 and b.liveStarted then
        b.seconds=(b.seconds or 0)+math.max(0,t-b.liveStarted)
        b.liveStarted=nil
    end
end

local function openBuffSlot(f,slot,id,label,icon,t)
    local st=S.effectSlots[slot]
    if st and st.id==id then return end
    if st then closeBuffSlot(f,slot,t) end
    local b=f.buffs[id]
    if not b then b={name=name(label),seconds=0,count=0,icon=icon,activeCount=0}; f.buffs[id]=b end
    b.activeCount=(b.activeCount or 0)+1
    if b.activeCount==1 then b.liveStarted=t; b.count=b.count+1 end
    S.effectSlots[slot]={active=true,id=id}
end

local function SnapshotPlayerBuffs(f)
    if not f then return end
    local now=sec()
    for i=1,GetNumBuffs("player") do
        local label,_,_,slot,_,icon,_,effectType,_,_,id=GetUnitBuffInfo("player",i)
        if slot and id and id~=0 and effectType~=BUFF_EFFECT_TYPE_DEBUFF then
            openBuffSlot(f,slot,id,label,icon,now)
        end
    end
end

function S.StartFight()
    S.current=fightNew()
    S.units={}
    S.tickFailed=false
    S.effectSlots={}
S.viewFight=nil
S.viewSavedIndex=nil
    SnapshotPlayerBuffs(S.current)
    if isBlocking() then S.current.blockStart=sec() end
end

local function closeBlock(f)
    if f and f.blockStart then
        f.blockSeconds=f.blockSeconds+math.max(0,sec()-f.blockStart)
        f.blockStart=nil
    end
end

local function closeEffects(f)
    local now=sec()
    for _,b in pairs(f.buffs) do
        if b.liveStarted then b.seconds=(b.seconds or 0)+math.max(0,now-b.liveStarted) end
        b.liveStarted=nil; b.activeCount=0
    end
    S.effectSlots={}
    S.viewFight=nil; S.viewSavedIndex=nil
end

local function closeDebuffs(f)
    local t=sec()
    for _,b in pairs(f.debuffs or {}) do
        if b.liveStarted then
            b.seconds=(b.seconds or 0)+math.max(0,t-b.liveStarted)
            b.liveStarted=nil
            b.activeCount=0
        end
    end
    S.debuffSlots={}
end


local function closeCombatEffects(f)
    local tnow=sec()
    for _,st in pairs(S.combatEffectSlots or {}) do
        if st.kind=="buff" then
            local b=f.buffs[st.id]; if b then b.seconds=(b.seconds or 0)+math.max(0,tnow-st.started) end
        elseif st.kind=="debuff" then
            local b=f.debuffs[st.key]; if b then b.seconds=(b.seconds or 0)+math.max(0,tnow-st.started) end
        end
    end
    S.combatEffectSlots={}
end

function S.EndFight()
    if not S.current then return end
    closeBlock(S.current); closeEffects(S.current); closeDebuffs(S.current); closeCombatEffects(S.current)
    S.current.finish=ms()
    S.last=S.current; S.current=nil
    S.Refresh()
end

function S.OnCombatState(_,inCombat)
    if not statsEnabled() then return end
    if inCombat then S.StartFight() else S.EndFight() end
end

local function isEffectCombatResult(result)
    return (ACTION_RESULT_EFFECT_GAINED and result==ACTION_RESULT_EFFECT_GAINED)
        or (ACTION_RESULT_EFFECT_GAINED_DURATION and result==ACTION_RESULT_EFFECT_GAINED_DURATION)
        or (ACTION_RESULT_EFFECT_FADED and result==ACTION_RESULT_EFFECT_FADED)
end

local function combatEffect(f,result,abilityId,abilityName,abilityGraphic,targetType,targetName,targetUnitId)
    if not f or not abilityId or abilityId==0 then return end
    local faded=ACTION_RESULT_EFFECT_FADED and result==ACTION_RESULT_EFFECT_FADED
    local tnow=sec()
    if targetType==COMBAT_UNIT_TYPE_PLAYER then
        local key="B:"..tostring(abilityId)
        local st=S.combatEffectSlots[key]
        local b=f.buffs[abilityId]
        if not b then b={name=name(abilityName),seconds=0,count=0,icon=abilityGraphic}; f.buffs[abilityId]=b end
        if faded then
            if st then b.seconds=(b.seconds or 0)+math.max(0,tnow-st.started); S.combatEffectSlots[key]=nil end
        elseif not st then
            S.combatEffectSlots[key]={kind="buff",id=abilityId,started=tnow}; b.count=(b.count or 0)+1
        end
    elseif targetType then
        local targetId=tostring(targetUnitId or targetName or "unknown")
        local dkey=tostring(abilityId)..":"..targetId
        local skey="D:"..dkey
        local st=S.combatEffectSlots[skey]
        local b=f.debuffs[dkey]
        if not b then
            b={id=abilityId,name=name(abilityName),target=name(targetName),targetId=targetId,
               seconds=0,count=0,icon=abilityGraphic,boss=false}
            f.debuffs[dkey]=b
        end
        if faded then
            if st then b.seconds=(b.seconds or 0)+math.max(0,tnow-st.started); S.combatEffectSlots[skey]=nil end
        elseif not st then
            S.combatEffectSlots[skey]={kind="debuff",key=dkey,started=tnow}; b.count=(b.count or 0)+1
        end
    end
end

function S.OnCombatEvent(_,result,isError,abilityName,abilityGraphic,abilityActionSlotType,
 sourceName,sourceType,targetName,targetType,hitValue,powerType,damageType,log,
 sourceUnitId,targetUnitId,abilityId,overflow)
    local f=S.current
    if not f or isError then return end
    local value=tonumber(hitValue) or 0
    -- Buff/debuff uptime is tracked only by EVENT_EFFECT_CHANGED.
    -- Do not also feed combat-effect events or uptime will be double-counted.
    if targetType==COMBAT_UNIT_TYPE_PLAYER and DAMAGE[result] and value>0 then
        f.damage=f.damage+value; f.hits=f.hits+1; f.largest=math.max(f.largest,value)

        -- Keep the last three incoming damaging blows in chronological order.
        -- "Blocked" is based on ESO's explicit blocked-damage result, not a guess.
        f.recentHits=f.recentHits or {}
        f.recentHits[#f.recentHits+1]={
            name=name(abilityName),
            enemy=name(sourceName),
            amount=value,
            blocked=BLOCKED[result] and true or false,
            icon=abilityGraphic,
            abilityId=abilityId,
            at=ms(),
        }
        while #f.recentHits>3 do table.remove(f.recentHits,1) end

        -- Damage profile. DoT is reliable from result type. Direct/AoE classification
        -- is best-effort from combat-event action type when ESO exposes it.
        if result==ACTION_RESULT_DOT_TICK or result==ACTION_RESULT_DOT_TICK_CRITICAL then
            f.dotDamage=f.dotDamage+value
        elseif abilityActionSlotType==ACTION_SLOT_TYPE_OTHER or abilityActionSlotType==ACTION_SLOT_TYPE_NORMAL_ABILITY then
            f.directDamage=f.directDamage+value
        else
            f.otherDamage=f.otherDamage+value
        end

        if not isBlocking() and not BLOCKED[result] then
            f.unblockedHits=f.unblockedHits+1
            if value>=5000 then
                local k=tostring(abilityId or abilityName or "unknown")
                local q=f.potentialMisses[k]
                if not q then q={name=name(abilityName),enemy=name(sourceName),amount=0,count=0,largest=0,prevented=0,blockedEstimate=0}; f.potentialMisses[k]=q end
                q.amount=q.amount+value; q.count=q.count+1; q.largest=math.max(q.largest,value)
                local bm=tonumber(adv(ADVANCED_STAT_DISPLAY_TYPE_BLOCK_MITIGATION)) or 0
                local frac=bm>1 and bm/100 or bm
                frac=math.max(0,math.min(.99,frac))
                local prevented=value*frac
                local blockedEstimate=value-prevented
                q.prevented=q.prevented+prevented; q.blockedEstimate=q.blockedEstimate+blockedEstimate
                f.potentialMissDamage=(f.potentialMissDamage or 0)+value
                f.potentialPrevented=(f.potentialPrevented or 0)+prevented
                f.potentialBlockedDamage=(f.potentialBlockedDamage or 0)+blockedEstimate
            end
        end
        if BLOCKED[result] then f.blockedDamage=f.blockedDamage+value; f.blockedHits=f.blockedHits+1 end
        if has(ACTION_RESULT_DAMAGE_SHIELDED) and result==ACTION_RESULT_DAMAGE_SHIELDED then
            f.shieldedDamage=f.shieldedDamage+value
        end
        bucket(f.enemies,sourceUnitId or sourceName,sourceName,value)
        bucket(f.abilities,abilityId or abilityName,abilityName,value,abilityGraphic)
    end
    if targetType==COMBAT_UNIT_TYPE_PLAYER and HEAL[result] and value>0 then
        f.healing=f.healing+value
        bucket(f.heals,abilityId or abilityName,abilityName,value,abilityGraphic)
    end
end

-- Track by EFFECT SLOT, not only ability ID. This prevents overlapping copies of
-- the same effect from incorrectly restarting/ending uptime.
function S.OnEffectChanged(_,changeType,effectSlot,effectName,unitTag,beginTime,endTime,
 stackCount,iconName,buffType,effectType,abilityType,statusEffectType,unitName,unitId,abilityId,sourceType)
    local f=S.current
    if not f or unitTag~="player" or not effectSlot or not abilityId or abilityId==0 then return end
    local st=S.effectSlots[effectSlot]
    if changeType==EFFECT_RESULT_FADED then
        -- A late fade for the prior ability must not close a reused slot.
        if st and st.id==abilityId then closeBuffSlot(f,effectSlot,sec()) end
    elseif effectType==BUFF_EFFECT_TYPE_DEBUFF then
        if st then closeBuffSlot(f,effectSlot,sec()) end
    elseif changeType==EFFECT_RESULT_GAINED or changeType==EFFECT_RESULT_UPDATED then
        openBuffSlot(f,effectSlot,abilityId,effectName,iconName,sec())
    end
end

-- Enemy debuff tracking. ESO only exposes effects for unit tags the client currently
-- knows about, so boss-target uptime is intentionally reported separately from all
-- observed hostile targets.
function S.OnDebuffChanged(_,changeType,effectSlot,effectName,unitTag,beginTime,endTime,
 stackCount,iconName,buffType,effectType,abilityType,statusEffectType,unitName,unitId,abilityId,sourceType)
    local f=S.current
    if not f or not abilityId or abilityId==0 or not unitTag or unitTag=="player" then return end
    if BUFF_EFFECT_TYPE_DEBUFF and effectType~=BUFF_EFFECT_TYPE_DEBUFF then return end

    local isBoss=string.find(unitTag,"boss",1,true)==1
    local isReticle=(unitTag=="reticleover")
    if not isBoss and not isReticle then return end

    local t=sec()
    local targetId=tostring(unitId or unitTag or unitName or "unknown")
    local targetName=name(unitName or unitTag)
    if isBoss then
        f.bossTargetId=targetId
        f.bossTargetName=targetName
    end

    local key=tostring(abilityId)..":"..targetId
    local b=f.debuffs[key]
    if not b then
        b={id=abilityId,name=name(effectName),target=targetName,targetId=targetId,
           seconds=0,count=0,icon=iconName,boss=isBoss}
        f.debuffs[key]=b
    elseif isBoss then
        b.boss=true
    end

    f.debuffTargets[targetId]=f.debuffTargets[targetId] or {name=targetName,boss=isBoss}
    if isBoss then f.debuffTargets[targetId].boss=true end

    local slotKey=tostring(unitTag)..":"..tostring(effectSlot)
    local st=S.debuffSlots[slotKey]

    if changeType==EFFECT_RESULT_GAINED or changeType==EFFECT_RESULT_UPDATED then
        if not st or not st.active then
            S.debuffSlots[slotKey]={active=true,key=key,started=t}
            b.count=(b.count or 0)+1
        elseif st.key~=key then
            local old=f.debuffs[st.key]
            if old then old.seconds=(old.seconds or 0)+math.max(0,t-st.started) end
            S.debuffSlots[slotKey]={active=true,key=key,started=t}
            b.count=(b.count or 0)+1
        end
    elseif changeType==EFFECT_RESULT_FADED then
        if st and st.active then
            local old=f.debuffs[st.key]
            if old then old.seconds=(old.seconds or 0)+math.max(0,t-st.started) end
            S.debuffSlots[slotKey]=nil
        end
    end
end

local function SnapshotEnemyDebuffs(unitTag)
    local f=S.current
    if not f or not unitTag or not DoesUnitExist(unitTag) then return end
    local isBoss=string.find(unitTag,"boss",1,true)==1
    local isReticle=unitTag=="reticleover"
    if not isBoss and not isReticle then return end
    local targetName=name(GetUnitName(unitTag) or unitTag)
    local targetId=tostring(GetUnitDisplayName(unitTag) or targetName or unitTag)
    if isBoss then f.bossTargetId=targetId; f.bossTargetName=targetName end
    f.debuffTargets[targetId]=f.debuffTargets[targetId] or {name=targetName,boss=isBoss}
    if isBoss then f.debuffTargets[targetId].boss=true end

    local seen={}
    local n=GetNumBuffs(unitTag) or 0
    local now=sec()
    for i=1,n do
        local effectName,beginTime,endTime,_,_,iconName,_,effectType,_,_,abilityId=GetUnitBuffInfo(unitTag,i)
        if abilityId and abilityId~=0 and (not BUFF_EFFECT_TYPE_DEBUFF or effectType==BUFF_EFFECT_TYPE_DEBUFF) then
            local key=tostring(abilityId)..":"..targetId
            seen[key]=true
            local b=f.debuffs[key]
            if not b then
                b={id=abilityId,name=name(effectName),target=targetName,targetId=targetId,seconds=0,count=0,icon=iconName,boss=isBoss}
                f.debuffs[key]=b
            elseif isBoss then b.boss=true end
            local slotKey="SNAP:"..tostring(unitTag)..":"..key
            local st=S.debuffSlots[slotKey]
            if not st then
                S.debuffSlots[slotKey]={active=true,key=key,started=now}
                b.count=(b.count or 0)+1
            end
        end
    end
    local prefix="SNAP:"..tostring(unitTag)..":"
    for slotKey,st in pairs(S.debuffSlots) do
        if string.sub(slotKey,1,#prefix)==prefix and not seen[st.key] then
            local old=f.debuffs[st.key]
            if old then old.seconds=(old.seconds or 0)+math.max(0,now-st.started) end
            S.debuffSlots[slotKey]=nil
        end
    end
end

local function debuffSeconds(f,key,b)
    local n=b.seconds or 0
    if f==S.current and b.liveStarted then
        n=n+math.max(0,sec()-b.liveStarted)
    end
    return n
end

local function debuffLines(f,bossOnly,maxrows,offset)
    if not f then return "|c777777No fight data.|r" end
    local d=fightTime(f)
    local merged={}
    for key,b in pairs(f.debuffs or {}) do
        if (not bossOnly) or b.boss then
            local mk=tostring(b.id)..":"..tostring(b.targetId)
            local x=merged[mk]
            if not x then
                x={name=b.name,target=b.target,seconds=0,count=0,boss=b.boss}
                merged[mk]=x
            end
            x.seconds=x.seconds+debuffSeconds(f,key,b)
            x.count=x.count+(b.count or 0)
        end
    end
    local a={}
    for _,v in pairs(merged) do a[#a+1]=v end
    table.sort(a,function(x,y) return (x.seconds or 0)>(y.seconds or 0) end)

    offset=math.max(0,tonumber(offset) or 0)
    maxrows=maxrows or #a
    local maxOffset=math.max(0,#a-maxrows)
    if offset>maxOffset then offset=maxOffset end

    local out={}
    local last=math.min(#a,offset+maxrows)
    for i=offset+1,last do
        local v=a[i]
        out[#out+1]=string_format("%-32s %6.1f%%  x%-3d",cap(v.name,32),math.min(100,pct(v.seconds,d)),v.count)
    end
    if #out==0 then
        return bossOnly and "|c777777No boss debuffs observed.|r" or "|c777777No enemy debuffs observed.|r"
    end
    if #a>maxrows then
        out[#out+1]=string_format("|c777777Rows %d-%d of %d — mouse wheel to scroll|r",
            offset+1,last,#a)
    end
    return table.concat(out,"\n")
end

-- Group optimization watch list.
-- These are high-value trial effects. "Missing" means the effect was not
-- observed at all during the selected fight; "LOW" means observed uptime
-- was below the target. This is an optimization aid, not a requirement that
-- every composition must provide every listed effect.
local OPT_BUFFS={
    {name="Major Courage",target=90},
    {name="Minor Courage",target=90},
    {name="Major Force",target=70},
    {name="Minor Berserk",target=90},
    {name="Minor Slayer",target=95},
}
local OPT_DEBUFFS={
    {name="Major Vulnerability",target=80},
    {name="Major Breach",target=95},
    {name="Minor Breach",target=90},
    {name="Minor Brittle",target=70},
    {name="Minor Vulnerability",target=80},
    {name="Crusher",target=90},
}

local function normalizedEffectName(v)
    return zo_strlower(tostring(v or "")):gsub("|c%x%x%x%x%x%x",""):gsub("|r","")
end

local function findBuffByName(f,wanted)
    local wn=normalizedEffectName(wanted)
    for _,b in pairs((f and f.buffs) or {}) do
        local bn=normalizedEffectName(b.name)
        if bn==wn or string.find(bn,wn,1,true) then return b end
    end
end

local function findDebuffByName(f,wanted)
    local wn=normalizedEffectName(wanted)
    local best=nil
    for key,b in pairs((f and f.debuffs) or {}) do
        local bn=normalizedEffectName(b.name)
        if bn==wn or string.find(bn,wn,1,true) then
            local n=debuffSeconds(f,key,b)
            if not best or n>best.seconds then best={seconds=n,data=b} end
        end
    end
    return best
end

local function optimizationLines(f,list,isDebuff)
    if not f then return "|cFF8A00No fight data yet.|r" end
    local duration=math.max(.001,fightTime(f))
    local out={}
    for _,watch in ipairs(list) do
        local seconds=0
        if isDebuff then
            local hit=findDebuffByName(f,watch.name)
            seconds=hit and hit.seconds or 0
        else
            local hit=findBuffByName(f,watch.name)
            if hit then
                seconds=(hit.seconds or 0)
                if f==S.current and hit.started then seconds=seconds+math.max(0,sec()-hit.started) end
            end
        end
        local up=math.min(100,pct(seconds,duration))
        if seconds<=0 then
            out[#out+1]=string_format("|cFF8A00%-24s MISSING|r",watch.name)
        elseif up<(watch.target or 0) then
            out[#out+1]=string_format("|cFF8A00%-24s LOW %5.1f%%  (target %d%%)|r",watch.name,up,watch.target)
        end
    end
    if #out==0 then return "|c55FF88No watched optimization gaps detected.|r" end
    return table.concat(out,"\n")
end


-- CMX-style enemy debuff tracking through LibCombat.
-- LibCombat supplies target unitId, abilityId, effect type, source type and a
-- unique effect slot. Multiple overlapping slots are merged into one uptime
-- interval per ability/target, preventing uptime above 100%.
function S.OnLibCombatUnits(_,units)
    S.units={}
    for id,u in pairs(units or {}) do
        S.units[id]={name=u.name,bossId=u.bossId,isBoss=u.isBoss}
    end
    local f=S.current or S.last
    if f then
        for _,b in pairs(f.debuffs or {}) do
            local u=S.units[tonumber(b.targetId)] or S.units[b.targetId]
            if u then
                b.target=name(u.name)
                b.boss=(u.bossId~=nil and u.bossId~=0) or u.isBoss==true
                if f.debuffTargets[b.targetId] then
                    f.debuffTargets[b.targetId].name=b.target
                    f.debuffTargets[b.targetId].boss=b.boss
                end
            end
        end
    end
end

function S.OnLibCombatEffect(callbackType,timems,unitId,abilityId,changeType,effectType,stacks,sourceType,slotId,hitValue)
    if not statsEnabled() then return end
    local f=S.current
    if not f or not abilityId or abilityId==0 or not unitId then return end
    if BUFF_EFFECT_TYPE_DEBUFF and effectType~=BUFF_EFFECT_TYPE_DEBUFF then return end

    local LC=LibCombat
    local abilityName=(LC and type(LC.GetFormattedAbilityName)=="function" and LC.GetFormattedAbilityName(abilityId)) or tostring(abilityId)
    local targetId=tostring(unitId)
    local targetName="Enemy "..targetId
    local isBoss=false

    -- LibCombat's unit table is the same normalized unit information CMX uses.
    if S.units and S.units[unitId] then
        local u=S.units[unitId]
        if u.name and u.name~="" then targetName=name(u.name) end
        isBoss=(u.bossId~=nil and u.bossId~=0) or u.isBoss==true
    end

    local key=tostring(abilityId)..":"..targetId
    local b=f.debuffs[key]
    if not b then
        b={id=abilityId,name=name(abilityName),target=targetName,targetId=targetId,
           seconds=0,count=0,icon=nil,boss=isBoss,activeCount=0,liveStarted=nil}
        f.debuffs[key]=b
    else
        if targetName and targetName~="" then b.target=targetName end
        if isBoss then b.boss=true end
    end

    f.debuffTargets[targetId]=f.debuffTargets[targetId] or {name=targetName,boss=isBoss}
    if isBoss then
        f.debuffTargets[targetId].boss=true
        f.bossTargetId=targetId
        f.bossTargetName=targetName
    end

    local skey=tostring(callbackType)..":"..targetId..":"..tostring(slotId or abilityId)
    local st=S.debuffSlots[skey]
    local now=sec()

    if changeType==EFFECT_RESULT_GAINED or changeType==EFFECT_RESULT_UPDATED then
        if not st then
            S.debuffSlots[skey]={key=key,active=true}
            b.activeCount=(b.activeCount or 0)+1
            if b.activeCount==1 then
                b.liveStarted=now
                b.count=(b.count or 0)+1
            end
        elseif st.key~=key then
            local old=f.debuffs[st.key]
            if old then
                old.activeCount=math.max(0,(old.activeCount or 1)-1)
                if old.activeCount==0 and old.liveStarted then
                    old.seconds=(old.seconds or 0)+math.max(0,now-old.liveStarted)
                    old.liveStarted=nil
                end
            end
            S.debuffSlots[skey]={key=key,active=true}
            b.activeCount=(b.activeCount or 0)+1
            if b.activeCount==1 then
                b.liveStarted=now
                b.count=(b.count or 0)+1
            end
        end
    elseif changeType==EFFECT_RESULT_FADED then
        if st then
            local old=f.debuffs[st.key]
            if old then
                old.activeCount=math.max(0,(old.activeCount or 1)-1)
                if old.activeCount==0 and old.liveStarted then
                    old.seconds=(old.seconds or 0)+math.max(0,now-old.liveStarted)
                    old.liveStarted=nil
                end
            end
            S.debuffSlots[skey]=nil
        end
    end
end

function S.Tick()
    local f=S.current
    if not f then return end
    local h,hm=power(POWERTYPE_HEALTH); local st,stm=power(POWERTYPE_STAMINA); local m,mm=power(POWERTYPE_MAGICKA)
    f.lowH=math.min(f.lowH,pct(h,hm)); f.lowS=math.min(f.lowS,pct(st,stm)); f.lowM=math.min(f.lowM,pct(m,mm))
    local function delta(cur,prev,gainKey,drainKey)
        if prev~=nil then
            local d=cur-prev
            if d>0 then f[gainKey]=(f[gainKey] or 0)+d
            elseif d<0 then f[drainKey]=(f[drainKey] or 0)-d end
        end
        return cur
    end
    f.prevH=delta(h,f.prevH,"healthGain","healthDrain")
    f.prevS=delta(st,f.prevS,"staminaGain","staminaDrain")
    f.prevM=delta(m,f.prevM,"magickaGain","magickaDrain")
    f.resourceSamples=(f.resourceSamples or 0)+1
    local physSample=stat(STAT_PHYSICAL_RESIST)
    local spellSample=stat(STAT_SPELL_RESIST)
    local blockCostSample=adv(ADVANCED_STAT_DISPLAY_TYPE_BLOCK_COST)
    if physSample>0 then rangeSample(f,"physicalResistance",physSample) end
    if spellSample>0 then rangeSample(f,"spellResistance",spellSample) end
    rangeSample(f,"maxHealth",hm); rangeSample(f,"maxStamina",stm); rangeSample(f,"maxMagicka",mm)
    if blockCostSample>0 then rangeSample(f,"blockCost",blockCostSample) end
    if STAT_HEALTH_REGEN_COMBAT then rangeSample(f,"healthRecovery",stat(STAT_HEALTH_REGEN_COMBAT)) end
    if STAT_STAMINA_REGEN_COMBAT then rangeSample(f,"staminaRecovery",stat(STAT_STAMINA_REGEN_COMBAT)) end
    if STAT_MAGICKA_REGEN_COMBAT then rangeSample(f,"magickaRecovery",stat(STAT_MAGICKA_REGEN_COMBAT)) end
    if isBlocking() and not f.blockStart then f.blockStart=sec()
    elseif not isBlocking() and f.blockStart then closeBlock(f) end
end

local function sorted(t)
    local a={}
    for _,v in pairs(t or {}) do a[#a+1]=v end
    table.sort(a,function(x,y) return (x.amount or 0)>(y.amount or 0) end)
    return a
end
local function linesBuckets(t,total,maxrows)
    local a,out=sorted(t),{}
    for i=1,math.min(maxrows,#a) do
        local v=a[i]
        out[#out+1]=string_format("%-22s  %9s  %5.1f%%",cap(v.name,22),fmt(v.amount),pct(v.amount,total))
    end
    return #out>0 and table.concat(out,"\n") or "|c777777No data recorded.|r"
end

local function splitBucketColumns(tbl,total,maxrows)
    local a=sorted(tbl); local names,vals,pcts={},{},{}
    for i=1,math.min(maxrows,#a) do
        local v=a[i]
        names[#names+1]=cap(v.name,22)
        vals[#vals+1]=fmt(v.amount)
        pcts[#pcts+1]=string_format("%.1f%%",pct(v.amount,total))
    end
    if #names==0 then names[1]="No data recorded." end
    return table.concat(names,"\n"),table.concat(vals,"\n"),table.concat(pcts,"\n")
end

local function buffSeconds(f,id,b)
    local n=b.seconds or 0
    if f==S.current and b.liveStarted then n=n+math.max(0,sec()-b.liveStarted) end
    return n
end
local function buffLines(f,maxrows)
    if not f then return "|c777777No data recorded.|r" end
    local d=fightTime(f); local a={}
    for id,b in pairs(f.buffs) do a[#a+1]={id=id,name=b.name,count=b.count,seconds=buffSeconds(f,id,b)} end
    table.sort(a,function(x,y) return x.seconds>y.seconds end)
    local out={}
    for i=1,(maxrows and math.min(maxrows,#a) or #a) do
        local b=a[i]
        out[#out+1]=string_format("%-23s %6.1f%%  x%d",cap(b.name,23),pct(b.seconds,d),b.count or 0)
    end
    return #out>0 and table.concat(out,"\n") or "|c777777No buff data recorded.|r"
end


local function splitBuffDetailColumns(f)
    if not f then return "No buff data recorded.","","" end
    local d=fightTime(f); local a={}
    for id,b in pairs(f.buffs or {}) do a[#a+1]={id=id,name=b.name,count=b.count,seconds=buffSeconds(f,id,b)} end
    table.sort(a,function(x,y) return x.seconds>y.seconds end)
    local names,uptimes,counts={},{},{}
    for i=1,#a do
        local b=a[i]
        names[#names+1]=cap(b.name,52)
        uptimes[#uptimes+1]=string_format("%.1f%%",pct(b.seconds,d))
        counts[#counts+1]="x"..tostring(b.count or 0)
    end
    if #names==0 then names[1]="No buff data recorded." end
    return table.concat(names,"\n"),table.concat(uptimes,"\n"),table.concat(counts,"\n")
end

local function splitBuffColumns(f,maxrows)
    if not f then return "No buff data recorded.","","" end
    local d=fightTime(f); local a={}
    for id,b in pairs(f.buffs or {}) do a[#a+1]={id=id,name=b.name,count=b.count,seconds=buffSeconds(f,id,b)} end
    table.sort(a,function(x,y) return x.seconds>y.seconds end)
    local names,vals,counts={},{},{}
    for i=1,math.min(maxrows,#a) do
        local b=a[i]
        names[#names+1]=cap(b.name,23)
        vals[#vals+1]=string_format("%.1f%%",pct(b.seconds,d))
        counts[#counts+1]="x"..tostring(b.count or 0)
    end
    if #names==0 then names[1]="No buff data recorded." end
    return table.concat(names,"\n"),table.concat(vals,"\n"),table.concat(counts,"\n")
end

local function statsSV()
    if not RyticTank.saved then return nil end
    RyticTank.saved.stats=RyticTank.saved.stats or {}
    RyticTank.saved.stats.savedFights=RyticTank.saved.stats.savedFights or {}
    return RyticTank.saved.stats
end

local function copyFight(f)
    if not f then return nil end
    local function cp(v,seen)
        if type(v)~="table" then return v end
        seen=seen or {}; if seen[v] then return seen[v] end
        local n={}; seen[v]=n
        for k,x in pairs(v) do n[cp(k,seen)]=cp(x,seen) end
        return n
    end
    local n=cp(f)
    n.finish=(n.finish or 0)>0 and n.finish or ms()
    if f==S.current then
        local now=sec()
        if n.blockStart then n.blockSeconds=n.blockSeconds+math.max(0,now-n.blockStart) end
        for _,collection in ipairs({n.buffs,n.debuffs}) do
            for _,b in pairs(collection or {}) do
                if b.liveStarted then b.seconds=(b.seconds or 0)+math.max(0,now-b.liveStarted) end
                b.liveStarted=nil; b.activeCount=0
            end
        end
    end
    n.blockStart=nil
    n.savedAt=GetTimeStamp and GetTimeStamp() or 0
    return n
end

function S.SaveFight()
    local f=S.viewFight or S.current or S.last
    if not f then d("|cFFAA00RyticTank: no fight to save.|r"); return end
    local sv=statsSV(); if not sv then return end
    local saved=copyFight(f)
    saved.label="Fight "..tostring(#sv.savedFights+1).." - "..tostring(saved.savedAt)
    table.insert(sv.savedFights,saved)
    while #sv.savedFights>20 do table.remove(sv.savedFights,1) end
    S.viewFight=saved; S.viewSavedIndex=#sv.savedFights
    d("|c55FF88RyticTank: fight saved ("..#sv.savedFights.."/20).|r")
    S.Refresh()
end

function S.ShowSaved(step)
    local sv=statsSV(); if not sv or #sv.savedFights==0 then
        d("|cFFAA00RyticTank: no saved fights.|r"); return
    end
    local i=S.viewSavedIndex or (#sv.savedFights+1)
    i=math.max(1,math.min(#sv.savedFights,i+(step or -1)))
    S.viewSavedIndex=i; S.viewFight=sv.savedFights[i]
    S.Refresh()
end

function S.ShowLive()
    S.viewFight=nil; S.viewSavedIndex=nil; S.Refresh()
end

function S.DeleteSaved()
    local sv=statsSV()
    if not sv or not S.viewSavedIndex then return end
    table.remove(sv.savedFights,S.viewSavedIndex)
    if #sv.savedFights==0 then S.ShowLive(); return end
    S.viewSavedIndex=math.min(S.viewSavedIndex,#sv.savedFights)
    S.viewFight=sv.savedFights[S.viewSavedIndex]
    S.Refresh()
end

local function copyLastHits(f)
    local out={}
    if not f then return out end
    for i,v in ipairs(f.recentHits or {}) do
        out[i]={
            name=v.name,enemy=v.enemy,amount=v.amount,blocked=v.blocked,
            icon=v.icon,abilityId=v.abilityId,at=v.at,
        }
    end
    return out
end

function S.OnPlayerDead()
    local f=S.current or S.last
    if not f then return end
    f.deathHits=copyLastHits(f)
    f.died=true
    S.Refresh()
end

local function deathBlowLines(f)
    if not f then return "|c777777No fight data.|r" end
    local hits=(f.deathHits and #f.deathHits>0) and f.deathHits or f.recentHits
    if not hits or #hits==0 then return "|c777777No incoming blows recorded.|r" end
    local out={}
    for i,v in ipairs(hits) do
        local status=v.blocked and "|c55CCFFBLOCKED|r" or "|cFF6666HIT|r"
        local death=(f.died and i==#hits) and "  |cFF3333DEATH|r" or ""
        out[#out+1]=string_format("%d. %-24s %9s   %s%s",i,cap(v.name,24),fmt(v.amount),status,death)
        out[#out+1]="   |c888888"..cap(v.enemy,46).."|r"
    end
    if not f.died then
        out[#out+1]=""
        out[#out+1]="|c888888Live rolling last 3 incoming blows. Freezes on death.|r"
    end
    return table.concat(out,"\n")
end

local function panel(parent,x,y,w,h,title)
    local p=WM:CreateControl(nil,parent,CT_BACKDROP); p:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); p:SetDimensions(w,h)
    p:SetCenterColor(0,0,0,.72); p:SetEdgeColor(.35,.35,.35,1)
    local hd=WM:CreateControl(nil,p,CT_LABEL); hd:SetFont("ZoFontWinH4"); hd:SetAnchor(TOPLEFT,p,TOPLEFT,10,7); hd:SetText("|cFFFFFF"..title.."|r")
    local l=WM:CreateControl(nil,p,CT_LABEL); l:SetFont("ZoFontGame"); l:SetAnchor(TOPLEFT,p,TOPLEFT,10,34); l:SetDimensions(w-20,h-42)
    l:SetVerticalAlignment(TEXT_ALIGN_TOP)
    return l
end


local function makeLabel(parent,x,y,w,h,font)
    local l=WM:CreateControl(nil,parent,CT_LABEL)
    l:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); l:SetDimensions(w,h)
    l:SetFont(font or "ZoFontGame"); l:SetVerticalAlignment(TEXT_ALIGN_TOP)
    return l
end


local function makeColumnLabel(parent,x,y,w,h,font,align)
    local l=WM:CreateControl(nil,parent,CT_LABEL)
    l:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
    l:SetDimensions(w,h)
    l:SetFont(font or "ZoFontGame")
    l:SetVerticalAlignment(TEXT_ALIGN_TOP)
    l:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    return l
end

local function makeSummaryTable(parent,x,y,w,h,title,color,valueX,percentX)
    local p=WM:CreateControl(nil,parent,CT_BACKDROP)
    p:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); p:SetDimensions(w,h)
    p:SetCenterColor(0.015,0.02,0.025,.94); p:SetEdgeColor(.28,.32,.36,1)
    local bar=WM:CreateControl(nil,p,CT_BACKDROP); bar:SetAnchor(TOPLEFT,p,TOPLEFT,1,1); bar:SetDimensions(w-2,38)
    bar:SetCenterColor(color[1],color[2],color[3],.35); bar:SetEdgeColor(color[1],color[2],color[3],.9)
    local hd=makeLabel(p,12,7,w-24,30,"ZoFontWinH4"); hd:SetText("|cFFFFFF"..title.."|r")
    local names=makeColumnLabel(p,12,48,valueX-18,h-58,"ZoFontGame",TEXT_ALIGN_LEFT)
    local vals=makeColumnLabel(p,valueX,48,(percentX or w-12)-valueX-8,h-58,"ZoFontGame",TEXT_ALIGN_RIGHT)
    local pcts=nil
    if percentX then pcts=makeColumnLabel(p,percentX,48,w-percentX-12,h-58,"ZoFontGame",TEXT_ALIGN_RIGHT) end
    return p,names,vals,pcts
end

local function makePanel(parent,x,y,w,h,title,color)
    local p=WM:CreateControl(nil,parent,CT_BACKDROP)
    p:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); p:SetDimensions(w,h)
    p:SetCenterColor(0.015,0.02,0.025,.94); p:SetEdgeColor(.28,.32,.36,1)
    local bar=WM:CreateControl(nil,p,CT_BACKDROP); bar:SetAnchor(TOPLEFT,p,TOPLEFT,1,1); bar:SetDimensions(w-2,38)
    bar:SetCenterColor(color[1],color[2],color[3],.35); bar:SetEdgeColor(color[1],color[2],color[3],.9)
    local hd=makeLabel(p,12,7,w-24,30,"ZoFontWinH4"); hd:SetText("|cFFFFFF"..title.."|r")
    local l=makeLabel(p,12,48,w-24,h-58,"ZoFontGame")
    return p,l
end

local function makeScrollablePanel(parent,x,y,w,h,title,color)
    local p=WM:CreateControl(nil,parent,CT_BACKDROP)
    p:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); p:SetDimensions(w,h)
    p:SetCenterColor(0.015,0.02,0.025,.94); p:SetEdgeColor(.28,.32,.36,1)
    local bar=WM:CreateControl(nil,p,CT_BACKDROP); bar:SetAnchor(TOPLEFT,p,TOPLEFT,1,1); bar:SetDimensions(w-2,38)
    bar:SetCenterColor(color[1],color[2],color[3],.35); bar:SetEdgeColor(color[1],color[2],color[3],.9)
    local hd=makeLabel(p,12,7,w-24,30,"ZoFontWinH4"); hd:SetText("|cFFFFFF"..title.."|r")
    local scroll=WM:CreateControlFromVirtual(nil,p,"ZO_ScrollContainer")
    scroll:SetAnchor(TOPLEFT,p,TOPLEFT,8,45); scroll:SetAnchor(BOTTOMRIGHT,p,BOTTOMRIGHT,-8,-8)
    local child=scroll:GetNamedChild("ScrollChild")
    local l=WM:CreateControl(nil,child,CT_LABEL)
    l:SetAnchor(TOPLEFT,child,TOPLEFT,4,3); l:SetWidth(w-52); l:SetFont("ZoFontGame")
    l:SetVerticalAlignment(TEXT_ALIGN_TOP)
    l:SetHandler("OnTextChanged",function(self)
        local th=self:GetTextHeight()
        self:SetHeight(math.max(th+8,h-70)); child:SetHeight(math.max(th+12,h-65))
    end)
    return p,l
end

local function tabButton(parent,text,x,handler)
    local b=WM:CreateControl(nil,parent,CT_BUTTON)
    b:SetDimensions(180,38); b:SetAnchor(BOTTOMLEFT,parent,BOTTOMLEFT,x,-10)
    b:SetFont("ZoFontGameBold"); b:SetText(text); b:SetHandler("OnClicked",handler)
    return b
end

function S.ShowTab(tab)
    S.tab=tab or "summary"
    for k,c in pairs(S.pages or {}) do c:SetHidden(k~=S.tab) end
    S.Refresh()
end

function S.CloseWindow()
    if S.window then RyticTank.UI.CloseModal(S.window) end
end

function S.CreateWindow()
    if S.window then return end
    local w=WM:CreateTopLevelWindow("RyticTankTankStats"); S.window=w
    w:SetDimensions(1180,790); w:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
    w:SetMovable(true); w:SetMouseEnabled(true); w:SetClampedToScreen(true); w:SetHidden(true)
    RyticTank.UI.AttachModal(w,statsEnabled)
    w:SetKeyboardEnabled(true)
    w:SetHandler("OnKeyDown", function(_, key)
        if key == KEY_ESCAPE then
            S.CloseWindow()
        end
    end)
    local bg=WM:CreateControl(nil,w,CT_BACKDROP); bg:SetAnchorFill()
    bg:SetCenterColor(.005,.008,.012,.96); bg:SetEdgeColor(.4,.45,.5,1)

    local title=makeLabel(w,20,12,400,36,"ZoFontWinH2")
    title:SetText("|c49BFFF RYTIC TANKSTATS|r")
    S.header=makeLabel(w,430,18,600,30,"ZoFontGameBold")
    local close=WM:CreateControl(nil,w,CT_BUTTON); close:SetDimensions(42,34)
    close:SetAnchor(TOPRIGHT,w,TOPRIGHT,-10,9); close:SetFont("ZoFontGameBold")
    close:SetText("X"); close:SetHandler("OnClicked",function() S.CloseWindow() end)

    local save=WM:CreateControl(nil,w,CT_BUTTON); save:SetDimensions(85,30); save:SetAnchor(TOPRIGHT,w,TOPRIGHT,-62,11)
    save:SetFont("ZoFontGameBold"); save:SetText("SAVE"); save:SetHandler("OnClicked",function() S.SaveFight() end)
    local live=WM:CreateControl(nil,w,CT_BUTTON); live:SetDimensions(85,30); live:SetAnchor(TOPRIGHT,w,TOPRIGHT,-152,11)
    live:SetFont("ZoFontGameBold"); live:SetText("LIVE"); live:SetHandler("OnClicked",function() S.ShowLive() end)
    local prev=WM:CreateControl(nil,w,CT_BUTTON); prev:SetDimensions(38,30); prev:SetAnchor(TOPRIGHT,w,TOPRIGHT,-242,11)
    prev:SetFont("ZoFontGameBold"); prev:SetText("<"); prev:SetHandler("OnClicked",function() S.ShowSaved(-1) end)
    local nextb=WM:CreateControl(nil,w,CT_BUTTON); nextb:SetDimensions(38,30); nextb:SetAnchor(TOPRIGHT,w,TOPRIGHT,-282,11)
    nextb:SetFont("ZoFontGameBold"); nextb:SetText(">"); nextb:SetHandler("OnClicked",function() S.ShowSaved(1) end)
    local del=WM:CreateControl(nil,w,CT_BUTTON); del:SetDimensions(70,30); del:SetAnchor(TOPRIGHT,w,TOPRIGHT,-325,11)
    del:SetFont("ZoFontGameBold"); del:SetText("DELETE"); del:SetHandler("OnClicked",function() S.DeleteSaved() end)

    S.pages={}
    local function page(key)
        local p=WM:CreateControl(nil,w,CT_CONTROL); p:SetAnchor(TOPLEFT,w,TOPLEFT,12,54)
        p:SetDimensions(1156,672); S.pages[key]=p; return p
    end

    -- SUMMARY
    local p=page("summary")
    _,S.damageNames,S.damageVals=makeSummaryTable(p,0,0,370,325,"DAMAGE & MITIGATION",{.75,.12,.12},245)
    _,S.defenseNames,S.defenseVals,S.defenseMax=makeSummaryTable(p,382,0,370,325,"RESOURCES / DEFENSE",{.05,.45,.8},205,318)
    _,S.buffNames,S.buffVals,S.buffCounts=makeSummaryTable(p,764,0,392,325,"BUFF UPTIMES",{.05,.65,.3},275,335)
    _,S.enemyNames,S.enemyVals,S.enemyPcts=makeSummaryTable(p,0,337,370,335,"DAMAGE TAKEN BY ENEMY",{.55,.15,.75},235,305)
    _,S.abilityNames,S.abilityVals,S.abilityPcts=makeSummaryTable(p,382,337,370,335,"DAMAGE TAKEN BY ABILITY",{.9,.45,.05},235,305)
    _,S.healNames,S.healVals,S.healPcts=makeSummaryTable(p,764,337,392,335,"HEALING RECEIVED",{.05,.65,.3},250,320)

    -- DAMAGE ANALYSIS
    local d=page("damage")
    _,S.profile=makePanel(d,0,0,565,672,"INCOMING DAMAGE PROFILE",{.75,.12,.12})
    _,S.damageDetail=makePanel(d,577,0,579,326,"TOP INCOMING ABILITIES",{.9,.45,.05})
    _,S.deathRecap=makePanel(d,577,338,579,334,"LAST 3 BLOWS / DEATH RECAP",{.75,.12,.12})

    -- POTENTIAL MISSED BLOCKS
    local m=page("misses")
    _,S.missSummary=makePanel(m,0,0,360,672,"BLOCK ANALYSIS",{.75,.12,.12})
    _,S.missList=makePanel(m,372,0,784,672,"POTENTIAL MISSED BLOCKS",{.85,.25,.15})

    -- BUFFS
    -- Three fixed columns prevent proportional-font overlap.
    local b=page("buffs")
    local bp=WM:CreateControl(nil,b,CT_BACKDROP); bp:SetAnchor(TOPLEFT,b,TOPLEFT,0,0); bp:SetDimensions(1156,455)
    bp:SetCenterColor(0.015,0.02,0.025,.94); bp:SetEdgeColor(.28,.32,.36,1)
    local bar=WM:CreateControl(nil,bp,CT_BACKDROP); bar:SetAnchor(TOPLEFT,bp,TOPLEFT,1,1); bar:SetDimensions(1154,38)
    bar:SetCenterColor(.05,.65,.3,.35); bar:SetEdgeColor(.05,.65,.3,.9)
    local hd=makeLabel(bp,12,7,1132,30,"ZoFontWinH4"); hd:SetText("|cFFFFFFBUFF UPTIME / APPLICATIONS|r")
    local h1=makeColumnLabel(bp,16,45,650,26,"ZoFontGameBold",TEXT_ALIGN_LEFT); h1:SetText("|cFFFFFFBuff / Effect|r")
    local h2=makeColumnLabel(bp,680,45,180,26,"ZoFontGameBold",TEXT_ALIGN_RIGHT); h2:SetText("|cFFFFFFUptime|r")
    local h3=makeColumnLabel(bp,890,45,180,26,"ZoFontGameBold",TEXT_ALIGN_RIGHT); h3:SetText("|cFFFFFFApplications|r")
    -- Debuffs-style paging: fixed labels render only the rows inside this panel.
    -- The labels belong to the Buffs page, so hiding the page hides every row.
    S.buffDetailOffset=0
    S.buffDetailTotalRows=0
    S.buffDetailNames=makeColumnLabel(bp,16,73,650,350,"ZoFontGame",TEXT_ALIGN_LEFT)
    S.buffDetailVals=makeColumnLabel(bp,680,73,180,350,"ZoFontGame",TEXT_ALIGN_RIGHT)
    S.buffDetailCounts=makeColumnLabel(bp,890,73,180,350,"ZoFontGame",TEXT_ALIGN_RIGHT)
    bp:SetMouseEnabled(true)
    bp:SetHandler("OnMouseWheel",function(_,delta)
        local maxOffset=math.max(0,(S.buffDetailTotalRows or 0)-16)
        S.buffDetailOffset=math.max(0,math.min(maxOffset,(S.buffDetailOffset or 0)-delta*3))
        S.Refresh()
    end)
    _,S.missingBuffs=makePanel(b,0,467,1156,205,"MISSING / LOW GROUP BUFFS — OPTIMIZATION",{.95,.35,.02})

    -- RESOURCES
    local r=page("resources")
    _,S.resourceDetail=makePanel(r,0,0,565,672,"RESOURCE PERFORMANCE",{.05,.45,.8})
    _,S.defenseDetail=makePanel(r,577,0,579,672,"DEFENSIVE STATS",{.05,.55,.75})

    -- DEBUFFS
    -- Use normal page-owned panels here. ZO_ScrollContainer's virtual ScrollChild
    -- can remain visible when the page is hidden, which caused debuff text to leak
    -- onto the Buffs tab. Direct page-owned labels hide/show correctly with the tab.
    local db=page("debuffs")
    local bossPanel
    local allPanel
    bossPanel,S.bossDebuffs=makePanel(db,0,0,565,455,"BOSS DEBUFF UPTIME",{.75,.18,.12})
    allPanel,S.allDebuffs=makePanel(db,577,0,579,455,"ALL OBSERVED ENEMY DEBUFFS",{.65,.3,.08})
    S.bossDebuffScroll=0
    S.allDebuffScroll=0
    bossPanel:SetMouseEnabled(true)
    allPanel:SetMouseEnabled(true)
    bossPanel:SetHandler("OnMouseWheel",function(_,delta)
        S.bossDebuffScroll=math.max(0,(S.bossDebuffScroll or 0)-delta*3)
        S.Refresh()
    end)
    allPanel:SetHandler("OnMouseWheel",function(_,delta)
        S.allDebuffScroll=math.max(0,(S.allDebuffScroll or 0)-delta*3)
        S.Refresh()
    end)
    _,S.missingDebuffs=makePanel(db,0,467,1156,205,"MISSING / LOW GROUP DEBUFFS — OPTIMIZATION",{.95,.35,.02})

    tabButton(w,"SUMMARY",15,function() S.ShowTab("summary") end)
    tabButton(w,"DAMAGE",205,function() S.ShowTab("damage") end)
    tabButton(w,"MISSED BLOCKS",395,function() S.ShowTab("misses") end)
    tabButton(w,"BUFFS",585,function() S.ShowTab("buffs") end)
    tabButton(w,"RESOURCES",775,function() S.ShowTab("resources") end)
    tabButton(w,"DEBUFFS",965,function() S.ShowTab("debuffs") end)

    S.ShowTab("summary")
end

local function missLines(f)
    if not f then return "|c777777No fight data.|r" end
    local a={}
    for _,v in pairs(f.potentialMisses or {}) do a[#a+1]=v end
    table.sort(a,function(x,y) return x.amount>y.amount end)
    local out={"|cAAAAAAThese are large hits received while the addon did not detect active block.",
               "They are NOT automatically classified as blockable mechanics.|r",""}
    for i=1,math.min(18,#a) do
        local v=a[i]
        out[#out+1]=string_format("|cFFAA66%-28s|r  %9s   x%-3d  largest %s",
            cap(v.name,28),fmt(v.amount),v.count,fmt(v.largest))
        out[#out+1]="  |c888888"..cap(v.enemy,55).."|r"
        if (v.prevented or 0)>0 then
            out[#out+1]="  |c55FF88Potentially prevented: "..fmt(v.prevented).."|r   |cAAAAAAEst. if blocked: "..fmt(v.blockedEstimate).."|r"
        end
    end
    if #a==0 then out[#out+1]="|c777777No large unblocked hits recorded.|r" end
    return table.concat(out,"\n")
end


local function RenderBuffRowsClean(f)
    if not S.buffDetailNames then return end
    local rows={}
    if f then
        for id,buff in pairs(f.buffs or {}) do
            rows[#rows+1]={name=buff.name or "Unknown",count=buff.count or 0,
                seconds=buffSeconds(f,id,buff)}
        end
        table.sort(rows,function(a,b) return a.seconds>b.seconds end)
    end
    local visibleRows=16
    S.buffDetailTotalRows=#rows
    local offset=math.max(0,math.min(math.max(0,#rows-visibleRows),S.buffDetailOffset or 0))
    S.buffDetailOffset=offset
    local names,uptimes,counts={},{},{}
    local duration=f and fightTime(f) or 0
    for i=offset+1,math.min(#rows,offset+visibleRows) do
        local row=rows[i]
        names[#names+1]=cap(row.name,52)
        uptimes[#uptimes+1]=string_format("%.1f%%",math.min(100,pct(row.seconds,duration)))
        counts[#counts+1]="x"..tostring(row.count)
    end
    if #names==0 then names[1]="|c777777No buff data recorded.|r" end
    S.buffDetailNames:SetText(table.concat(names,"\n"))
    S.buffDetailVals:SetText(table.concat(uptimes,"\n"))
    S.buffDetailCounts:SetText(table.concat(counts,"\n"))
end

function S.Refresh()
    if not S.window or S.window:IsHidden() then return end
    local f=S.current or S.last
    local h,hm=power(POWERTYPE_HEALTH); local st,stm=power(POWERTYPE_STAMINA); local m,mm=power(POWERTYPE_MAGICKA)
    local phys=stat(STAT_PHYSICAL_RESIST); local spell=stat(STAT_SPELL_RESIST)
    local blockCost=adv(ADVANCED_STAT_DISPLAY_TYPE_BLOCK_COST); local blockMit=adv(ADVANCED_STAT_DISPLAY_TYPE_BLOCK_MITIGATION)
    local d=f and fightTime(f) or 0
    local state="|cAAAAAALAST FIGHT|r"
    if f==S.current then state="|c55FF88CURRENT FIGHT|r"
    elseif S.viewFight then
        local sv=statsSV()
        state=string_format("|cFFD36ASAVED FIGHT %d/%d|r",S.viewSavedIndex or 0,sv and #sv.savedFights or 0)
    end
    S.header:SetText(f and string_format("%s   |cFFFFFFActive: %.1fs|r",state,d) or "|cAAAAAAWAITING FOR COMBAT|r")

    local function statRow(label,value,alreadyFormatted)
        local shown=alreadyFormatted and tostring(value) or fmt(value)
        return string_format("%-18s %10s",label,shown)
    end
    local function rangeRow(label,key)
        local r=f and f.statRanges and f.statRanges[key]
        if not r then return string_format("%-18s %10s  %10s",label,"--","--") end
        return string_format("%-18s %10s  %10s",label,fmt(r.low),fmt(r.high))
    end

    local defenseText=
        string_format("|c49BFFF%-10s|r %8s / %-8s (%3.0f%%)","Health",fmt(h),fmt(hm),pct(h,hm)).."\n"..
        string_format("|c55FF88%-10s|r %8s / %-8s (%3.0f%%)","Stamina",fmt(st),fmt(stm),pct(st,stm)).."\n"..
        string_format("|cB56CFF%-10s|r %8s / %-8s (%3.0f%%)","Magicka",fmt(m),fmt(mm),pct(m,mm)).."\n\n"..
        statRow("Physical Resist",phys).."\n"..
        statRow("Spell Resist",spell).."\n"..
        statRow("Block Mitigation",string_format("%.1f%%",blockMit),true).."\n"..
        statRow("Block Cost",blockCost).."\n"..
        string_format("%-18s %10s","Blocking Now",(isBlocking() and "|c55FF88YES|r" or "|cFF6666NO|r"))..
        (f and ("\n\n|cFFD36AFIGHT MIN / MAX|r\n"..
        string_format("%-18s %10s  %10s","STAT","MIN","MAX").."\n"..
        rangeRow("Physical Resist","physicalResistance").."\n"..
        rangeRow("Spell Resist","spellResistance").."\n"..
        rangeRow("Block Cost","blockCost").."\n"..
        rangeRow("Max Health","maxHealth").."\n"..
        rangeRow("Max Stamina","maxStamina").."\n"..
        rangeRow("Max Magicka","maxMagicka")) or "")
    S.defenseDetail:SetText(defenseText)

    -- Summary defense panel uses three real columns:
    -- label | primary value | secondary value.
    -- Keep every table the same row count so values cannot drift vertically.
    local dn={
        "Health","Stamina","Magicka","",
        "Physical Resistance","Spell Resistance","Block Mitigation","Block Cost","Blocking Now"
    }
    local dv={
        fmt(h).." / "..fmt(hm),
        fmt(st).." / "..fmt(stm),
        fmt(m).." / "..fmt(mm),
        "",
        fmt(phys),fmt(spell),string_format("%.1f%%",blockMit),fmt(blockCost),
        (isBlocking() and "|c55FF88YES|r" or "|cFF6666NO|r")
    }
    local dx={
        string_format("%.0f%%",pct(h,hm)),
        string_format("%.0f%%",pct(st,stm)),
        string_format("%.0f%%",pct(m,mm)),
        "","","","","",""
    }

    if f then
        local pr=f.statRanges and f.statRanges.physicalResistance
        local sr=f.statRanges and f.statRanges.spellResistance
        local bc=f.statRanges and f.statRanges.blockCost

        dn[#dn+1]="";                 dv[#dv+1]="";                  dx[#dx+1]=""
        dn[#dn+1]="|cFFD36AFIGHT MIN / MAX|r"
        dv[#dv+1]="|cFFD36AMIN|r";    dx[#dx+1]="|cFFD36AMAX|r"
        dn[#dn+1]="Physical Resistance"
        dv[#dv+1]=pr and fmt(pr.low) or "--"; dx[#dx+1]=pr and fmt(pr.high) or "--"
        dn[#dn+1]="Spell Resistance"
        dv[#dv+1]=sr and fmt(sr.low) or "--"; dx[#dx+1]=sr and fmt(sr.high) or "--"
        dn[#dn+1]="Block Cost"
        dv[#dv+1]=bc and fmt(bc.low) or "--"; dx[#dx+1]=bc and fmt(bc.high) or "--"
    end

    S.defenseNames:SetText(table.concat(dn,"\n"))
    S.defenseVals:SetText(table.concat(dv,"\n"))
    S.defenseMax:SetText(table.concat(dx,"\n"))

    if not f then
        S.damageNames:SetText("|c777777No fight recorded yet.|r"); S.damageVals:SetText("")
        S.buffNames:SetText("|c777777No buff data recorded yet.|r"); S.buffVals:SetText(""); S.buffCounts:SetText("")
        S.enemyNames:SetText("|c777777No damage data recorded yet.|r"); S.enemyVals:SetText(""); S.enemyPcts:SetText("")
        S.abilityNames:SetText("|c777777No damage data recorded yet.|r"); S.abilityVals:SetText(""); S.abilityPcts:SetText("")
        S.healNames:SetText("|c777777No healing data recorded yet.|r"); S.healVals:SetText(""); S.healPcts:SetText("")
        S.profile:SetText("|c777777Enter combat to begin analysis.|r")
        S.damageDetail:SetText("|c777777No damage data.|r")
        if S.deathRecap then S.deathRecap:SetText("|c777777No incoming blows recorded.|r") end
        S.missSummary:SetText("|c777777No fight data.|r")
        S.missList:SetText("|c777777No fight data.|r")
        RenderBuffRowsClean(nil)
        S.resourceDetail:SetText(defenseText)
        S.bossDebuffs:SetText("|c777777No boss debuff data recorded yet.|r")
        S.allDebuffs:SetText("|c777777No enemy debuff data recorded yet.|r")
        S.missingBuffs:SetText("|cFF8A00No fight data yet.|r")
        S.missingDebuffs:SetText("|cFF8A00No fight data yet.|r")
        return
    end

    local bs=f.blockSeconds
    if f==S.current and f.blockStart then bs=bs+math.max(0,sec()-f.blockStart) end
    local avg=f.hits>0 and f.damage/f.hits or 0
    local damageText=
        "|cFF7777Damage Taken|r            "..fmt(f.damage).."\n"..
        "|c49BFFFBlocked Damage Seen|r     "..fmt(f.blockedDamage).."\n"..
        "|c66CCFFShielded Damage Seen|r    "..fmt(f.shieldedDamage).."\n"..
        "|cFFFFFFLargest Hit|r             "..fmt(f.largest).."\n"..
        "|cFFFFFFAverage Hit|r             "..fmt(avg).."\n"..
        "|cFFFFFFHits Taken|r              "..fmt(f.hits).."\n"..
        "|cFFFFFFBlocked Hits|r            "..fmt(f.blockedHits).."\n"..
        "|cFFFFFFUnblocked Hits|r          "..fmt(f.unblockedHits).."\n"..
        "|c55CCFFBlock Uptime|r            "..string_format("%.1f%%",pct(bs,d)).."\n"..
        "|c55FF88Healing Received|r        "..fmt(f.healing).."\n\n"..
        "|c888888Exact pre-mitigation damage is not guessed.|r"
    S.damageNames:SetText(table.concat({
        "|cFF7777Damage Taken|r","|c49BFFFBlocked Damage Seen|r","|c66CCFFShielded Damage Seen|r",
        "Largest Hit","Average Hit","Hits Taken","Blocked Hits","Unblocked Hits","|c55CCFFBlock Uptime|r","|c55FF88Healing Received|r"
    },"\n"))
    S.damageVals:SetText(table.concat({
        fmt(f.damage),fmt(f.blockedDamage),fmt(f.shieldedDamage),fmt(f.largest),fmt(avg),fmt(f.hits),
        fmt(f.blockedHits),fmt(f.unblockedHits),string_format("%.1f%%",pct(bs,d)),fmt(f.healing)
    },"\n"))

    local classified=(f.directDamage or 0)+(f.dotDamage or 0)+(f.aoeDamage or 0)+(f.otherDamage or 0)
    S.profile:SetText(
        "|cFFFFFFTOTAL OBSERVED DAMAGE|r   "..fmt(f.damage).."\n\n"..
        "|cFFAA55Direct / non-DoT|r        "..fmt(f.directDamage).."   "..string_format("%.1f%%",pct(f.directDamage,f.damage)).."\n"..
        "|cB56CFFDoT|r                     "..fmt(f.dotDamage).."   "..string_format("%.1f%%",pct(f.dotDamage,f.damage)).."\n"..
        "|cFF7777AoE classified|r          "..fmt(f.aoeDamage).."   "..string_format("%.1f%%",pct(f.aoeDamage,f.damage)).."\n"..
        "|cAAAAAAOther / unknown|r         "..fmt(f.otherDamage).."   "..string_format("%.1f%%",pct(f.otherDamage,f.damage)).."\n\n"..
        "|c49BFFFBlocked-hit damage|r      "..fmt(f.blockedDamage).."   "..string_format("%.1f%%",pct(f.blockedDamage,f.damage)).."\n"..
        "|c66CCFFShielded damage|r         "..fmt(f.shieldedDamage).."   "..string_format("%.1f%%",pct(f.shieldedDamage,f.damage)).."\n"..
        "|c55CCFFBlock uptime|r            "..string_format("%.1f%%",pct(bs,d)).."\n\n"..
        "|c888888DoT classification is event-result based.\nAoE/direct classification will be refined as we validate ESO event metadata.|r"
    )
    S.damageDetail:SetText(linesBuckets(f.abilities,f.damage,11))
    if S.deathRecap then S.deathRecap:SetText(deathBlowLines(f)) end
    S.missSummary:SetText(
        "|cFFFFFFFight time|r        "..string_format("%.1fs",d).."\n"..
        "|cFFFFFFTotal hits|r        "..fmt(f.hits).."\n"..
        "|c55CCFFBlocked hits|r      "..fmt(f.blockedHits).."  ("..string_format("%.1f%%",pct(f.blockedHits,f.hits))..")\n"..
        "|cFF7777Unblocked hits|r    "..fmt(f.unblockedHits).."  ("..string_format("%.1f%%",pct(f.unblockedHits,f.hits))..")\n"..
        "|c55CCFFBlock uptime|r      "..string_format("%.1f%%",pct(bs,d)).."\n\n"..
        "|cFFAA66Potential missed-block damage|r  "..fmt(f.potentialMissDamage or 0).."\n"..
        "|c55FF88Potentially preventable|r        "..fmt(f.potentialPrevented or 0).."\n"..
        "|cAAAAAAEst. damage if blocked|r        "..fmt(f.potentialBlockedDamage or 0).."\n\n"..
        "|cAAAAAAPotential misses are hits >= 5,000 while block was not detected. Prevention uses the block-mitigation stat sampled at each hit.|r"
    )
    S.missList:SetText(missLines(f))
    RenderBuffRowsClean(f)
    local function rate(v) return d>0 and (v or 0)/d or 0 end
    S.resourceDetail:SetText(
        "|cFFFFFFFIGHT LOWS|r\n"..
        "Health:  "..string_format("%.0f%%",f.lowH).."\n"..
        "Stamina: "..string_format("%.0f%%",f.lowS).."\n"..
        "Magicka: "..string_format("%.0f%%",f.lowM).."\n\n"..
        "|cFFD36ARECOVERY STAT LOW / HIGH|r\n"..
        "Health:  "..rangeText(f,"healthRecovery").."\n"..
        "Stamina: "..rangeText(f,"staminaRecovery").."\n"..
        "Magicka: "..rangeText(f,"magickaRecovery").."\n\n"..
        "|c55FF88OBSERVED REGENERATION / SEC|r\n"..
        "Health:  "..fmt(rate(f.healthGain)).." /s   total "..fmt(f.healthGain).."\n"..
        "Stamina: "..fmt(rate(f.staminaGain)).." /s   total "..fmt(f.staminaGain).."\n"..
        "Magicka: "..fmt(rate(f.magickaGain)).." /s   total "..fmt(f.magickaGain).."\n\n"..
        "|cFF7777OBSERVED RESOURCE DRAIN / SEC|r\n"..
        "Health:  "..fmt(rate(f.healthDrain)).." /s   total "..fmt(f.healthDrain).."\n"..
        "Stamina: "..fmt(rate(f.staminaDrain)).." /s   total "..fmt(f.staminaDrain).."\n"..
        "Magicka: "..fmt(rate(f.magickaDrain)).." /s   total "..fmt(f.magickaDrain).."\n\n"..
        "|c888888Observed deltas are sampled during combat; this is not source-attributed regeneration yet.|r"
    )
    local n1,v1,p1=splitBucketColumns(f.enemies,f.damage,10)
    S.enemyNames:SetText(n1); S.enemyVals:SetText(v1); S.enemyPcts:SetText(p1)
    local n2,v2,p2=splitBucketColumns(f.abilities,f.damage,10)
    S.abilityNames:SetText(n2); S.abilityVals:SetText(v2); S.abilityPcts:SetText(p2)
    local n3,v3,p3=splitBucketColumns(f.heals,f.healing,10)
    S.healNames:SetText(n3); S.healVals:SetText(v3); S.healPcts:SetText(p3)
    local bn,bv,bc=splitBuffColumns(f,11)
    S.buffNames:SetText(bn); S.buffVals:SetText(bv); S.buffCounts:SetText(bc)
    S.bossDebuffs:SetText(debuffLines(f,true,17,S.bossDebuffScroll))
    S.allDebuffs:SetText(debuffLines(f,false,17,S.allDebuffScroll))
    S.missingBuffs:SetText(optimizationLines(f,OPT_BUFFS,false))
    S.missingDebuffs:SetText(optimizationLines(f,OPT_DEBUFFS,true))
end

local function librarySubscriptions(on)
    if not LibCombat then return end
    local subscriptions={
        {LIBCOMBAT_EVENT_EFFECTS_OUT,S.OnLibCombatEffect},
        {LIBCOMBAT_EVENT_GROUPEFFECTS_OUT,S.OnLibCombatEffect},
        {LIBCOMBAT_EVENT_UNITS,S.OnLibCombatUnits},
    }
    for _,v in ipairs(subscriptions) do
        if v[1]~=nil then
            if on then LibCombat:RegisterCallbackType(v[1],v[2],"RyticTankTools")
            else LibCombat:UnregisterCallbackType(v[1],v[2],"RyticTankTools") end
        end
    end
    if not on then S.units={} end
end

local function registerRuntime()
    if S.runtimeRegistered then return end
    S.runtimeRegistered=true
    librarySubscriptions(true)

    EM:RegisterForEvent("RyticTankTSCombat",EVENT_PLAYER_COMBAT_STATE,S.OnCombatState)
    EM:RegisterForEvent("RyticTankTSEvents",EVENT_COMBAT_EVENT,S.OnCombatEvent)
    EM:AddFilterForEvent(
        "RyticTankTSEvents",EVENT_COMBAT_EVENT,
        REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER,
        REGISTER_FILTER_IS_ERROR,false
    )
    if EVENT_PLAYER_DEAD then
        EM:RegisterForEvent("RyticTankTSPlayerDead",EVENT_PLAYER_DEAD,S.OnPlayerDead)
    end
    EM:RegisterForEvent("RyticTankTSEffects",EVENT_EFFECT_CHANGED,S.OnEffectChanged)
    EM:AddFilterForEvent("RyticTankTSEffects",EVENT_EFFECT_CHANGED,REGISTER_FILTER_UNIT_TAG,"player")

    EM:RegisterForUpdate("RyticTankTSTick",250,function()
        if not statsEnabled() then return end
        if S.current and not S.tickFailed then
            local ok,err=pcall(S.Tick)
            if not ok then S.tickFailed=true; d("|cFF5555Rytic stats sampling stopped for this fight: "..tostring(err).."|r") end
        end
        if S.window and not S.window:IsHidden() then
            local ok,err=pcall(S.Refresh)
            if not ok and S.defense then S.defense:SetText("|cFF5555UPDATE ERROR|r\n"..tostring(err)) end
        end
    end)
end

local function unregisterRuntime()
    if not S.runtimeRegistered then return end
    S.runtimeRegistered=false
    librarySubscriptions(false)
    EM:UnregisterForEvent("RyticTankTSCombat",EVENT_PLAYER_COMBAT_STATE)
    EM:UnregisterForEvent("RyticTankTSEvents",EVENT_COMBAT_EVENT)
    if EVENT_PLAYER_DEAD then EM:UnregisterForEvent("RyticTankTSPlayerDead",EVENT_PLAYER_DEAD) end
    EM:UnregisterForEvent("RyticTankTSEffects",EVENT_EFFECT_CHANGED)
    EM:UnregisterForUpdate("RyticTankTSTick")
end

function S.SetEnabled(enabled)
    local on=enabled and true or false
    if RyticTank.saved then
        RyticTank.saved.stats=RyticTank.saved.stats or {}
        RyticTank.saved.stats.enabled=on
    end

    if on then
        registerRuntime()
    else
        if S.current then S.EndFight() end

        -- Settings can disable TankStats while another addon/settings window owns
        -- ESO's UI/cursor mode.  Do not call CloseWindow() here because it forces
        -- SetGameCameraUIMode(false).  The module OFF path only needs to hide its
        -- own window; the normal TankStats X/toggle close path still uses
        -- CloseWindow() and retains its existing behavior.
        if S.window then RyticTank.UI.CloseModal(S.window) end

        unregisterRuntime()
        S.effectSlots={}
        S.debuffSlots={}
        S.combatEffectSlots={}
    end
end

function S.Toggle()
    if not statsEnabled() then
        d("|cFFAA00RyticTank TankStats is OFF. Enable it in RyticTankTools settings.|r")
        return
    end
    if not S.window then S.CreateWindow() end
    if S.window:IsHidden() then
        if not RyticTank.UI.OpenModal(S.window) then return end
        local ok,err=pcall(S.Refresh)
        if not ok then d("|cFF5555RyticTank TankStats: "..tostring(err).."|r") end
    else
        S.CloseWindow()
    end
end

function S.Initialize()
    statsSV()
    S.CreateWindow()
    SLASH_COMMANDS["/tankstats"]=S.Toggle
    SLASH_COMMANDS["/tank"]=S.Toggle
    S.SetEnabled(statsEnabled())
    d("|c00FF00RyticTank TankStats v4 ready: /tankstats|r")
end
