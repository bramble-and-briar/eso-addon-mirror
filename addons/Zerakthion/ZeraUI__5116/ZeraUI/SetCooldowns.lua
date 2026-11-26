-- Independent set-proc HUD. Only equipped, unsuppressed sets register
-- C++-filtered ability/result/unit events.
local C={}
C.__index=C
ZeraUISetCooldowns=C
local PREFIX="ZeraUISetCooldown"
local catalog=ZeraUISetCatalog
local JORVULD_ID=346
local BODY_SLOTS={
    EQUIP_SLOT_HEAD,EQUIP_SLOT_CHEST,EQUIP_SLOT_SHOULDERS,EQUIP_SLOT_HAND,
    EQUIP_SLOT_WAIST,EQUIP_SLOT_LEGS,EQUIP_SLOT_FEET,EQUIP_SLOT_NECK,
    EQUIP_SLOT_RING1,EQUIP_SLOT_RING2,
}
local FRONT_SLOTS={EQUIP_SLOT_MAIN_HAND,EQUIP_SLOT_OFF_HAND}
local BACK_SLOTS={EQUIP_SLOT_BACKUP_MAIN,EQUIP_SLOT_BACKUP_OFF}
local POWER_BY_TYPE={}
local POWER_KIND={}
for _,key in ipairs({"STAMINA","MAGICKA","ULTIMATE"}) do
    local code=_G["COMBAT_MECHANIC_FLAGS_"..key] or _G["POWERTYPE_"..key]
    if code~=nil then POWER_KIND[key]=code; POWER_BY_TYPE[code]=key end
end
local RELEASE_RESULTS={}
for _,name in ipairs({"ACTION_RESULT_DAMAGE","ACTION_RESULT_CRITICAL_DAMAGE","ACTION_RESULT_BLOCKED_DAMAGE","ACTION_RESULT_DAMAGE_SHIELDED"}) do
    local code=_G[name]
    if code~=nil then RELEASE_RESULTS[code]=true end
end
local function clock()
    return GetGameTimeMilliseconds and GetGameTimeMilliseconds() or GetFrameTimeMilliseconds()
end
local function normalized(name)
    return (name or ""):gsub("%^.*$",""):lower():gsub("^perfected%s+",""):gsub("^perfect%s+","")
end
local function canonicalSetId(id)
    id=tonumber(id)
    if not id or id<=0 then return nil end
    if GetItemSetUnperfectedSetId then
        local unperf=GetItemSetUnperfectedSetId(id)
        if type(unperf)=="number" and unperf>0 then return unperf end
    end
    return id
end
local function isSetSuppressed(id)
    if not (id and GetItemSetSuppressionInfo and ITEM_BONUS_SUPPRESSION_TYPE_NONE~=nil) then return false end
    local sup=GetItemSetSuppressionInfo(id)
    return sup~=nil and sup~=ITEM_BONUS_SUPPRESSION_TYPE_NONE
end
local function rowFor(id,name)
    local cid=canonicalSetId(id)
    local rule=cid and catalog.byId[cid]
    if not rule and id and id~=cid then rule=catalog.byId[id] end
    if rule then return type(rule)=="string" and catalog.byName[rule] or rule end
    local key=normalized(name)
    return catalog.byName[key]
end
local rawNames=catalog.rawNames or {}
local function preferenceKey(id,name)
    local cid=canonicalSetId(id)
    local row=(cid and catalog.byId[cid]) or (id and catalog.byId[id])
    if type(row)=="string" then return row end
    local key=normalized(name)
    if catalog.byName[key] or catalog.pending[key] then return key end
    local alias=rawNames[cid or id] and normalized(rawNames[cid or id])
    if alias and catalog.byName[alias] then return alias end
    return "id:"..tostring(cid or id)
end
function C:CatalogChoices()
    local names={}
    for name in pairs(catalog.byName) do names[name]=name:gsub("^%l",string.upper):gsub(" %l",string.upper) end
    for name in pairs(catalog.pending) do names[name]=name:gsub("^%l",string.upper):gsub(" %l",string.upper) end
    for id,row in pairs(catalog.byId) do
        if type(row)=="table" then
            local key=preferenceKey(id,rawNames[id])
            if not names[key] then names[key]=rawNames[id] or ("Set ID "..id) end
        end
    end
    if C.ScanGear then
        local _,gear=C.ScanGear()
        for id,g in pairs(gear) do if rowFor(id,g.name) then names[preferenceKey(id,g.name)]=g.name:gsub("%^.*$","") end end
    end
    local choices,keys={},{}
    for key,name in pairs(names) do choices[#choices+1]=name; keys[name]=key end
    table.sort(choices)
    return choices,keys
end
-- Format the actual remaining time, without capping it to the duration.
local INT_STR={}
local function intStr(n)
    local s=INT_STR[n]
    if not s then
        s=tostring(n)
        if n>=0 and n<=999 then INT_STR[n]=s end
    end
    return s
end
local function fmtKey(ms,decimal)
    if ms<=0 then return 0,"" end
    if ms<(decimal or 3)*1000 then return 1,math.floor(ms/100+.5) end
    -- Match the main HUD's ten-nanosecond display-boundary tolerance.
    local rounded=ms>0.00001 and ms-0.00001 or ms
    return 2,math.ceil(rounded/1000)
end
local function fmt(ms,decimal)
    if ms<=0 then return "" end
    if ms<(decimal or 3)*1000 then return string.format("%.1f",ms/1000) end
    -- Match the main HUD's ten-nanosecond display-boundary tolerance.
    local rounded=ms>0.00001 and ms-0.00001 or ms
    return intStr(math.ceil(rounded/1000))
end
local function scanGear()
    local gear={}
    if not (GetItemLink and GetItemLinkSetInfo and BAG_WORN) then return {},gear,false,false end
    local jBody,jFront,jBack=0,0,0
    local suppressedCache={}
    local function suppressed(id)
        local cached=suppressedCache[id]
        if cached==nil then
            cached=isSetSuppressed(id) and true or false
            suppressedCache[id]=cached
        end
        return cached
    end
    local function count(slots,bar)
        for _,slot in ipairs(slots) do
            local link=slot and GetItemLink(BAG_WORN,slot)
            if link and link~="" then
                local has,setName,_,_,required,rawId=GetItemLinkSetInfo(link,false)
                rawId=tonumber(rawId); required=tonumber(required)
                if has and rawId and rawId>0 and required and required>0 then
                    local cid=canonicalSetId(rawId) or rawId
                    local pieces=1
                    if bar~="body" and EQUIP_TYPE_TWO_HAND then
                        local equip=GetItemEquipType and GetItemEquipType(BAG_WORN,slot) or GetItemLinkEquipType and GetItemLinkEquipType(link)
                        if equip==EQUIP_TYPE_TWO_HAND then pieces=2 end
                    end
                    local isSup=suppressed(rawId)
                    if cid==JORVULD_ID and not isSup then
                        if bar=="body" then jBody=jBody+pieces
                        elseif bar=="front" then jFront=jFront+pieces
                        else jBack=jBack+pieces end
                    end
                    local g=gear[cid]
                    local isPerf=rawId~=cid
                    if not g then
                        g={id=cid,rawId=rawId,name=setName,required=required,body=0,front=0,back=0,
                            perfBody=0,perfFront=0,perfBack=0,link=link,suppressed=isSup}
                        gear[cid]=g
                    else
                        if isPerf then g.rawId=rawId end
                        if not g.suppressed and isSup then g.suppressed=true end
                    end
                    g[bar]=g[bar]+pieces
                    if isPerf then
                        if bar=="body" then g.perfBody=g.perfBody+pieces
                        elseif bar=="front" then g.perfFront=g.perfFront+pieces
                        else g.perfBack=g.perfBack+pieces end
                    end
                end
            end
        end
    end
    count(BODY_SLOTS,"body"); count(FRONT_SLOTS,"front"); count(BACK_SLOTS,"back")
    local grouped={}
    for cid,g in pairs(gear) do
        local rule=rowFor(cid,g.name)
        if rule and not g.suppressed then
            local front=g.body+g.front>=g.required
            local back=g.body+g.back>=g.required
            if front or back then
                local perfected=(g.perfBody+g.perfFront>=g.required) or (g.perfBody+g.perfBack>=g.required)
                local prior=grouped[rule]
                if prior then
                    prior.front=prior.front or front; prior.back=prior.back or back
                    prior.perfected=prior.perfected or perfected
                else
                    grouped[rule]={id=cid,rawId=g.rawId,name=g.name,required=g.required,
                        front=front,back=back,perfected=perfected,link=g.link,rule=rule}
                end
            end
        end
    end
    return grouped,gear,jBody+jFront>=5,jBody+jBack>=5
end
C.ScanGear=scanGear
local function reset(s)
    s.activeEnd=0; s.cdEnd=0; s.stacks=0; s.activeLength=0; s.cdLength=0
    s.unit=nil; s.effectStart=nil; s.lastProc=nil; s.markTarget=nil; s.markStart=nil; s.consumePending=nil; s.toggleTarget=nil; s.triggerEnd=nil; s.triggerLength=nil
    s.value=nil; s.resourcePercent=nil; s.progress=nil; s.valueReady=nil; s.toggle=nil; s.targets=nil; s.preview=nil; s.specialAt=nil
    s.zenApplied=nil; s.zenDots=nil; s.zenEnd=nil; s.zenCountVisible=nil
    s.ghostEnd=0; s.ghostLength=0; s.procCount=0; s.targetCDs=nil; s.phase=nil; s.wasOnCooldown=nil
    if s.rule.pa then s.paRecords={}; s.paTextCount=nil; s.paTextSize=nil; s.paCountText="0/"..(s.paSize or 1) end
end
local function available(s,bar)
    return bar==HOTBAR_CATEGORY_BACKUP and s.back or bar~=HOTBAR_CATEGORY_BACKUP and s.front
end
function C:HasJorvuld(bar)
    bar=bar or (GetActiveHotbarCategory and GetActiveHotbarCategory())
    return bar==HOTBAR_CATEGORY_BACKUP and self.jorvuldBack==true or bar~=HOTBAR_CATEGORY_BACKUP and self.jorvuldFront==true
end
function C:RefreshBosses()
    local bosses,last=0,nil
    if GetUnitName then
        for i=1,(MAX_BOSSES or 6) do
            local tag="boss"..i
            local name=GetUnitName(tag)
            if name and name~="" then bosses=bosses+1; last=tag end
        end
    end
    self.soleBossTag=bosses==1 and last or nil
end
-- Target selection: a sole boss (cached on EVENT_BOSSES_CHANGED) can be
-- tracked independently of the crosshair. Otherwise use reticleover.
local function zenTarget(self,cfg)
    if cfg.setCooldownZenBoss and self.soleBossTag then return self.soleBossTag end
    return "reticleover"
end
-- "All" counts every player-owned damage-type effect; "Timed" additionally
-- requires a duration >1s. Neither API classification proves a true DoT.
local function zenDot(start,finish,abilityType,mine,method)
    if not (mine and ABILITY_TYPE_DAMAGE and abilityType==ABILITY_TYPE_DAMAGE) then return false end
    if method~="Timed" then return true end
    return type(start)=="number" and type(finish)=="number" and finish-start>1
end
-- Resource calculations are event-driven. Never read power from the HUD tick.
function C:ComputeValue(s)
    local r=s.rule
    if not r.power then return end
    local data=self.power
    if not data then return end
    local p=data[r.power]
    if r.power=="HIGHEST" then
        local mag,stam=data.MAGICKA,data.STAMINA
        if mag and stam then p=stam.max>mag.max and stam or mag end
    end
    if not p then return end
    if r.perUltimate then
        local mult=(r.jorvuld and self:HasJorvuld()) and 1.4 or 1
        if s.valUlt~=p.value or s.valMult~=mult or not s.value then
            s.valUlt,s.valMult=p.value,mult
            local seconds=(p.value/r.perUltimate)*mult
            s.value=string.format("%.1fs",seconds); s.progress=math.min(1,math.max(0,p.value/500)); s.valueReady=p.value>=500
        end
    elseif p.max>0 then
        local ratio=math.max(0,math.min(1,p.value/p.max))
        local pct=math.floor(100*ratio+.5)
        if r.resourceSide and (s.resPctKey~=pct or not s.resourcePercent) then
            s.resPctKey=pct
            s.resourcePercent=intStr(pct).."%"
        end
        if r.maxBonus then
            local f=math.min(1,(1-ratio)/(1-r.cap))
            s.progress=f; s.valueReady=f>=.9999
            s.pillFrac=f
            if r.percent then
                if s.valMaxF~=f or not s.value then s.valMaxF=f; s.value=string.format("%.1f%%",r.maxBonus*f) end
            else
                local bonus=math.floor(r.maxBonus*f+.5)
                if s.valBonusKey~=bonus or not s.value then s.valBonusKey=bonus; s.value=intStr(bonus) end
            end
        elseif r.threshold then
            s.progress=ratio
            if s.valPctKey~=pct or not s.value then s.valPctKey=pct; s.value=intStr(pct).."%" end
            s.valueReady=r.above and ratio>=r.threshold or not r.above and ratio<r.threshold
            -- Label fill: how close the resource is to the side that procs.
            s.pillFrac=r.above and math.min(1,ratio/r.threshold) or math.min(1,(1-ratio)/(1-r.threshold))
        end
    end
end
function C:OnPower(kind,value,maxValue,effectiveMax,immediate)
    if not self.enabled or not self.hasPower or type(value)~="number" then return end
    local key=POWER_BY_TYPE[kind]
    if not key or not self.wantedPower[key] then return end
    -- Same reachable maximum as the attribute bars (see AttributeCore.lua).
    local max=ZeraUIReachableMax and ZeraUIReachableMax(tonumber(maxValue),effectiveMax) or
        (type(effectiveMax)=="number" and effectiveMax>0 and effectiveMax or tonumber(maxValue)) or 0
    local entry=self.power[key]
    if not entry then entry={value=value,max=max}; self.power[key]=entry
    else entry.value=value; entry.max=max end
    for _,s in pairs(self.states) do
        if s.rule.power==key or s.rule.power=="HIGHEST" then self:ComputeValue(s) end
    end
    -- When the 100 ms HUD tick is active, let the tick paint updated resource
    -- values instead of repainting every tile 20-40 times/sec on power events.
    if immediate or not (self.owner and self.owner.updating) then self:PaintNow() end
end
function C:RefreshPower()
    self.hasPower=false
    local wanted={}
    for _,s in pairs(self.states) do
        local r=s.rule
        if r.power then
            self.hasPower=true
            if r.power=="HIGHEST" then wanted.MAGICKA=true; wanted.STAMINA=true else wanted[r.power]=true end
        end
    end
    self.wantedPower=wanted
    if not self.hasPower or not GetUnitPower then return end
    for key in pairs(wanted) do
        local kind=POWER_KIND[key]
        if kind then local v,m,e=GetUnitPower("player",kind); self:OnPower(kind,v,m,e,true) end
    end
end
function C:OnWeaponSwap()
    if not self.enabled then return end
    if self.jorvuldFront~=self.jorvuldBack then
        for _,s in pairs(self.states) do
            if s.rule.jorvuld then
                if s.rule.power then self:ComputeValue(s) end
                if s.rule.opportunist then s.specialAt=nil end
            end
        end
    end
    self:PaintNow()
end
local DEATH_RESULTS
local function disarmMarkedDeath(self,s)
    local events=s and s.deathEvents
    if not events then return end
    s.deathEvents=nil
    for _,r in ipairs(events) do EVENT_MANAGER:UnregisterForEvent(r[1],r[2]) end
end
local function armMarkedDeath(self,s)
    if not (s and (s.rule.mark or s.rule.toggle=="target") and REGISTER_FILTER_COMBAT_RESULT and EVENT_COMBAT_EVENT) then return end
    if s.deathEvents then return end
    if not DEATH_RESULTS then
        local deathResults={}
        local candidates={ACTION_RESULT_DIED,ACTION_RESULT_DIED_XP,ACTION_RESULT_DIED_COMPANION_XP}
        for i=1,3 do
            local code=candidates[i]
            if code~=nil and not deathResults[code] then deathResults[code]=true end
        end
        DEATH_RESULTS=deathResults
    end
    local deathResults=DEATH_RESULTS
    local function onMarkedDeath(_,result,_,_,_,_,_,_,_,_,_,_,_,_,_,targetId)
        if not deathResults[result] or not targetId then return end
        if s.rule.mark and s.markTarget==targetId then
            s.activeEnd=0; s.markTarget=nil; disarmMarkedDeath(self,s); self:PaintNow()
        elseif s.rule.toggle=="target" and s.toggleTarget==targetId then
            s.toggle=false; s.toggleTarget=nil; s.stacks=0; disarmMarkedDeath(self,s); self:PaintNow()
        end
    end
    local events={}
    for code in pairs(deathResults) do
        local name=PREFIX..s.id.."_markedDeath_"..tostring(code)
        EVENT_MANAGER:RegisterForEvent(name,EVENT_COMBAT_EVENT,onMarkedDeath)
        EVENT_MANAGER:AddFilterForEvent(name,EVENT_COMBAT_EVENT,REGISTER_FILTER_COMBAT_RESULT,code)
        events[#events+1]={name,EVENT_COMBAT_EVENT}
    end
    if next(events) then s.deathEvents=events end
end
function C:OnDeathStateChanged(dead)
    if not self.enabled then return end
    self:ResetPA(not dead)
    if dead then
        for _,s in pairs(self.states) do
            if s.rule.toggle then s.toggle=false; s.toggleTarget=nil; s.targets=nil; s.stacks=0; disarmMarkedDeath(self,s)
            elseif s.rule.mark then s.activeEnd=nil; s.markTarget=nil; s.markStart=nil; disarmMarkedDeath(self,s) end
        end
        self:PaintNow()
    else
        self:Recover(false,true)
    end
end
local MISSING_ICON="/esoui/art/icons/icon_missing.dds"
local function itemIcon(link)
    if not link or link=="" then return end
    -- GetItemLinkInfo returns the item's actual texture as its first result.
    local icon=GetItemLinkInfo and GetItemLinkInfo(link)
    if (not icon or icon=="") and GetItemLinkIcon then icon=GetItemLinkIcon(link) end
    if type(icon)=="string" and icon~="" and icon~=MISSING_ICON then return icon end
end
local function iconFor(s)
    local icon=s.rule.icon or (s.rule.ids[1] and GetAbilityIcon and GetAbilityIcon(s.rule.ids[1]))
    if not icon or icon=="" then icon=itemIcon(s.link) or MISSING_ICON end
    return icon
end
function C:BindTileIcon(tile,s)
    local icon=s.icon
    if not icon then icon=iconFor(s); s.icon=icon end
    -- Rebind a pooled tile when its set changes, even if the cached path
    -- happens to match. Reset texture state so a previously hidden tile
    -- cannot carry tint, cropped coordinates, or a blank texture.
    local owner=s.id or s.name
    if tile.iconPath~=icon or tile.iconOwner~=owner then
        tile.icon:SetTexture(icon)
        tile.icon:SetTextureCoords(0,1,0,1)
        tile.icon:SetColor(1,1,1,1)
        tile.icon:SetAlpha(1)
        tile.icon:SetHidden(false)
        tile.iconPath,tile.iconOwner=icon,owner
        tile.mode=nil; tile.timeKind=nil; tile.stackKind=nil; tile.secKind=nil
    end
end
function C.New(owner,ui)
    local learned=owner.settings.setCooldownLearned
    if type(learned)=="table" then
        for name,id in pairs(learned) do
            if catalog.pending[name] and type(id)=="number" and id>0 and id==math.floor(id) then
                local rule={ids={id}}
                for k,v in pairs(catalog.pending[name]) do rule[k]=v end
                catalog.byName[name]=rule
            end
        end
    end
    return setmetatable({owner=owner,ui=ui,states={},order={},pool={},power={},visible=false,pills={},pillCount=0,visualGen=1},C)
end
local PROBE=PREFIX.."Probe"
function C:StopProbe(cancel)
    local p=self.probe
    if not p then return end
    self.probe=nil
    EVENT_MANAGER:UnregisterForEvent(PROBE.."Effect",EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(PROBE.."Damage",EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForUpdate(PROBE)
    if cancel then return end
    local learned=self.owner.settings.setCooldownLearned
    if type(learned)~="table" then learned={}; self.owner.settings.setCooldownLearned=learned end
    for name,id in pairs(p.found) do
        if not catalog.byName[name] then
            local rule={ids={id}}
            for k,v in pairs(catalog.pending[name]) do rule[k]=v end
            catalog.byName[name]=rule; learned[name]=id
            d(string.format("Zera UI set learned: %s [%d]",name,id))
        end
    end
    self:Refresh(true)
    local missing=false
    for name in pairs(p.wanted) do
        if not catalog.byName[name] then d("Zera UI set probe: not identified: "..name); missing=true end
    end
    if missing then
        for _,row in ipairs(p.rows) do
            d(string.format("Zera UI probe: %s [%d] %s",row.name,row.id,row.what))
        end
    end
    self:Report()
end
function C:StartProbe()
    self:StopProbe(true)
    if not self.enabled then d("Zera UI set probe: /zera sets on first"); return end
    local _,gear=scanGear()
    local wanted={}
    for _,g in pairs(gear) do
        local name=normalized(g.name)
        if catalog.pending[name] and not rowFor(g.id,g.name) and (g.body+g.front>=g.required or g.body+g.back>=g.required) then wanted[name]=true end
    end
    if not next(wanted) then d("Zera UI set probe: no equipped sets awaiting identification"); return end
    if not (EVENT_EFFECT_CHANGED and EVENT_COMBAT_EVENT and REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER) then return end
    local p={wanted=wanted,found={},rows={},seen={},deadline=clock()+30000}
    self.probe=p
    local function record(id,name,what,kind)
        if self.probe~=p or type(id)~="number" or id<=0 then return end
        if not name or name=="" then name=GetAbilityName and GetAbilityName(id) or "" end
        local key=normalized(name)
        local rule=catalog.pending[key]
        if wanted[key] and rule and (rule.effect and kind=="effect" or not rule.effect and kind=="damage") and not p.found[key] then
            p.found[key]=id
        end
        if not p.seen[id] and #p.rows<24 then
            p.seen[id]=true; p.rows[#p.rows+1]={name=name,id=id,what=what}
        end
    end
    EVENT_MANAGER:RegisterForEvent(PROBE.."Effect",EVENT_EFFECT_CHANGED,function(_,change,_,name,tag,start,finish,_,_,_,_,_,_,_,_,id,source)
        if source==COMBAT_UNIT_TYPE_PLAYER and tag=="player" and (change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED) and finish and start and finish>start then
            record(id,name,string.format("buff %.1fs",finish-start),"effect")
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(PROBE.."Effect",EVENT_EFFECT_CHANGED,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
    EVENT_MANAGER:RegisterForEvent(PROBE.."Damage",EVENT_COMBAT_EVENT,function(_,result,_,name,_,_,_,source,_,_,_,_,_,_,_,_,id)
        if source==COMBAT_UNIT_TYPE_PLAYER and (result==ACTION_RESULT_DAMAGE or result==ACTION_RESULT_CRITICAL_DAMAGE or result==ACTION_RESULT_BLOCKED_DAMAGE) then record(id,name,"damage","damage") end
    end)
    EVENT_MANAGER:AddFilterForEvent(PROBE.."Damage",EVENT_COMBAT_EVENT,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
    EVENT_MANAGER:RegisterForUpdate(PROBE,250,function()
        local done=true
        for name in pairs(wanted) do if not p.found[name] then done=false; break end end
        if done or clock()>=p.deadline then self:StopProbe() end
    end)
    d("Zera UI set probe: 30 seconds. Proc your equipped unknown sets on a dummy. /zera sets probe stop to finish early.")
end
-- Powerful Assault: confirmed personal effects, one record per group member.
-- The only tick work before the next expiration is a scalar comparison.
local function paName(name) return type(name)=="string" and name:gsub("%^.*$","") or "" end
local function paRecount(s,now)
    local count,first,length=0,nil,0
    for key,r in pairs(s.paRecords) do
        if r.finish<=now then s.paRecords[key]=nil
        else
            count=count+1
            if not first or r.finish<first then first=r.finish; length=r.finish-r.start end
        end
    end
    s.stacks=count; s.activeEnd=first or 0; s.activeLength=math.max(0,length)
    if s.paTextCount~=count or s.paTextSize~=s.paSize or not s.paCountText then
        s.paTextCount=count; s.paTextSize=s.paSize; s.paCountText=count.."/"..(s.paSize or 1)
    end
end
function C:ObservePA(s,change,tag,name,beginTime,endTime,source,now)
    if self.states[s.rule]~=s or source~=COMBAT_UNIT_TYPE_PLAYER then return end
    if tag=="reticleover" or tag=="reticleoverplayer" or tag=="reticleovertarget" then return end
    local key=paName(name)
    if key=="" then key=s.paTags and s.paTags[tag]
    elseif s.paAliases then key=s.paAliases[key] or key end
    if not key or not s.paMembers or not s.paMembers[key] then return end
    now=now or clock()
    local start=type(beginTime)=="number" and beginTime>0 and beginTime*1000 or nil
    local finish=type(endTime)=="number" and endTime>0 and endTime*1000 or nil
    local old=s.paRecords[key]
    -- An older application must not shorten or clear a refreshed recipient.
    if old and ((start and start<old.start-50) or (finish and finish<old.finish-50 and (not start or start<=old.start+50))) then return end
    if change==EFFECT_RESULT_FADED then
        if not old then return end
        s.paRecords[key]=nil
    elseif change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED then
        if not finish or finish<=now then return end
        start=start or (old and old.start) or now
        if old and old.start==start and old.finish==finish then return end
        if old then old.start,old.finish=start,finish else s.paRecords[key]={start=start,finish=finish} end
    else return end
    paRecount(s,now)
    -- No PaintNow here: one existing set tick paints all recipients together.
end
function C:RefreshPARoster(recover)
    local s=self.states[catalog.byName["powerful assault"]]
    if not s or not s.paRecords then return end
    local old=s.paMembers or {}
    local members,tags,aliases={},{},{}
    local function add(tag)
        local name=paName(GetUnitName and GetUnitName(tag))
        if name~="" then
            if not members[name] then members[name]=tag end
            tags[tag]=name
            local display=paName(GetUnitDisplayName and GetUnitDisplayName(tag))
            if display~="" then aliases[display]=name end
        end
    end
    add("player")
    local size=GetGroupSize and GetGroupSize() or 0
    if GetGroupUnitTagByIndex then for i=1,size do local tag=GetGroupUnitTagByIndex(i); if tag and tag~="" then add(tag) end end end
    s.paMembers,s.paTags,s.paAliases,s.paSize=members,tags,aliases,math.max(1,size)
    local now=clock()
    for key in pairs(s.paRecords) do if not members[key] then s.paRecords[key]=nil end end
    -- Initial enable/reload or newly joined members only; never from Update.
    if GetNumBuffs and GetUnitBuffInfo then
        for key,tag in pairs(members) do if recover or not old[key] then
            for i=1,GetNumBuffs(tag) or 0 do
                local _,start,finish,_,_,_,_,_,_,_,id,_,mine=GetUnitBuffInfo(tag,i)
                if id==61771 and mine==true then self:ObservePA(s,EFFECT_RESULT_UPDATED,tag,key,start,finish,COMBAT_UNIT_TYPE_PLAYER,now) end
            end
        end end
    end
    paRecount(s,now)
end
function C:ResetPA(recover)
    local s=self.states[catalog.byName["powerful assault"]]
    if not s then return end
    s.paRecords={}; s.paMembers=nil; s.paTags=nil; s.paAliases=nil
    paRecount(s,clock())
    if recover then self:RefreshPARoster(true) end
end
function C:Unwatch(s)
    disarmMarkedDeath(self,s)
    for _,r in ipairs(s.events or {}) do EVENT_MANAGER:UnregisterForEvent(r[1],r[2]) end
    s.events={}
end
function C:Watch(s)
    local rule=s.rule
    s.events={}
    local function event(ability,kind,eventCode,fn,unitFilter,extraFilter,extraValue)
        if not (eventCode and REGISTER_FILTER_ABILITY_ID and unitFilter and COMBAT_UNIT_TYPE_PLAYER) then return end
        local name=PREFIX..s.id.."_"..kind.."_"..ability
        EVENT_MANAGER:RegisterForEvent(name,eventCode,fn)
        EVENT_MANAGER:AddFilterForEvent(name,eventCode,REGISTER_FILTER_ABILITY_ID,ability,unitFilter,COMBAT_UNIT_TYPE_PLAYER)
        if extraFilter~=nil and extraValue~=nil then
            EVENT_MANAGER:AddFilterForEvent(name,eventCode,extraFilter,extraValue)
        end
        s.events[#s.events+1]={name,eventCode}
    end
    if rule.pa then
        s.paRecords=s.paRecords or {}
        event(61771,"pa",EVENT_EFFECT_CHANGED,function(_,change,_,_,tag,start,finish,_,_,_,_,_,_,name,_,id,source)
            if id==61771 then self:ObservePA(s,change,tag,name,start,finish,source) end
        end,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE)
        return
    end
    if rule.zen and EVENT_BOSSES_CHANGED then
        local name=PREFIX..s.id.."_bosses"
        EVENT_MANAGER:RegisterForEvent(name,EVENT_BOSSES_CHANGED,function()
            self:RefreshBosses()
            s.specialAt=nil
        end)
        s.events[#s.events+1]={name,EVENT_BOSSES_CHANGED}
        self:RefreshBosses()
    end
    -- Resolve numeric ACTION_RESULT_* codes once per watched set (not per combat event).
    local resultSet,singleResult=nil,nil
    if rule.results then
        resultSet={}
        local count=0
        for _,resultName in ipairs(rule.results) do
            local code=_G[resultName]
            if code~=nil then resultSet[code]=true; count=count+1; singleResult=code end
        end
        if count~=1 or rule.release then singleResult=nil end
    end
    for _,ability in ipairs(rule.ids) do
        if rule.mark then
            -- Listen to the target debuff, not the related player buff (which can
            -- be reported separately). Both combat and reticle events can arrive.
            if ability==252048 then
                event(ability,"mark",EVENT_COMBAT_EVENT,function(_,result,_,_,_,_,_,source,_,target,_,_,_,_,_,targetId,id)
                    if id~=ability or source~=COMBAT_UNIT_TYPE_PLAYER or target==COMBAT_UNIT_TYPE_PLAYER then return end
                    if result==ACTION_RESULT_EFFECT_GAINED or result==ACTION_RESULT_EFFECT_GAINED_DURATION then
                        self:Mark(s,targetId)
                    elseif result==ACTION_RESULT_EFFECT_FADED and targetId and (s.markTarget==targetId or (s.markTarget==nil and (s.activeEnd or 0)>clock())) then
                        s.activeEnd=0; s.markTarget=nil; disarmMarkedDeath(self,s); self:PaintNow()
                    end
                end,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE)
                event(ability,"markEffect",EVENT_EFFECT_CHANGED,function(_,change,_,_,tag,beginTime,endTime,_,_,_,_,_,_,_,unit,id,source)
                    if id~=ability or source~=COMBAT_UNIT_TYPE_PLAYER or tag=="player" then return end
                    if change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED then self:Mark(s,unit,beginTime,endTime)
                    end -- Combat fade/death is authoritative; reticle fades can be visibility changes.
                end,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE)
            end
        elseif rule.toggle then
            event(ability,"toggle",EVENT_COMBAT_EVENT,function(_,result,_,_,_,_,_,source,_,target,_,_,_,_,_,targetId,id)
                if id~=ability then return end
                if rule.toggle=="self" and target~=COMBAT_UNIT_TYPE_PLAYER or rule.toggle=="target" and source~=COMBAT_UNIT_TYPE_PLAYER then return end
                if result==ACTION_RESULT_EFFECT_GAINED then
                    s.toggle=true; s.toggleTarget=targetId
                    if rule.toggle=="target" then
                        if s.toggleTarget~=nil then armMarkedDeath(self,s) else disarmMarkedDeath(self,s) end
                    end
                elseif result==ACTION_RESULT_EFFECT_FADED and (rule.toggle=="self" or s.toggleTarget==targetId) then
                    s.toggle=false; s.toggleTarget=nil; s.targets=nil; s.stacks=0
                    if rule.toggle=="target" then disarmMarkedDeath(self,s) end
                else return end
                self:PaintNow()
            end,rule.toggle=="self" and REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE or REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE)
        elseif rule.effect then
            local unitTag=rule.targetStacks and "reticleover" or "player"
            event(ability,"effect",EVENT_EFFECT_CHANGED,function(_,change,_,_,tag,beginTime,endTime,stacks,_,_,_,_,_,_,unit,id,source)
                if id==ability and source==COMBAT_UNIT_TYPE_PLAYER then
                    self:Effect(s,change,tag,beginTime,endTime,stacks,unit)
                end
            end,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,REGISTER_FILTER_UNIT_TAG,unitTag)
        elseif rule.results then
            event(ability,"proc",EVENT_COMBAT_EVENT,function(_,result,_,_,_,_,_,source,_,target,_,_,_,_,_,targetId,id)
                if id~=ability or (rule.targetTracking and target~=COMBAT_UNIT_TYPE_PLAYER) or (not rule.targetTracking and source~=COMBAT_UNIT_TYPE_PLAYER) then return end
                if rule.release and rule.releaseDuration and result==ACTION_RESULT_EFFECT_FADED and target==COMBAT_UNIT_TYPE_PLAYER and s.phase=="armed" then
                    -- Only the armed buff faded, not the ICD or a confirmed
                    -- released effect. Keep the release gate for actual damage
                    -- that may be reported after the buff fade.
                    s.activeEnd=0; self:PaintNow(); return
                end
                if resultSet and resultSet[result] then self:Proc(s,ability,targetId) end
            end,rule.targetTracking and REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE or REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,
                singleResult and REGISTER_FILTER_COMBAT_RESULT or nil,singleResult)
        end
    end
    if rule.ghost then
        local ability=rule.ghost
        event(ability,"ghost",EVENT_COMBAT_EVENT,function(_,result,_,_,_,_,_,source,_,_,hit,_,_,_,_,_,id)
            if id==ability and source==COMBAT_UNIT_TYPE_PLAYER and result==ACTION_RESULT_EFFECT_GAINED_DURATION then
                s.ghostLength=type(hit)=="number" and hit>0 and hit or 6600
                s.ghostEnd=clock()+s.ghostLength; self:PaintNow()
            end
        end,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,REGISTER_FILTER_COMBAT_RESULT,ACTION_RESULT_EFFECT_GAINED_DURATION)
    end
    -- Spaulder of Ruin (163401): store per-recipient expiry timestamps.
    -- GAINED grants a 12s safety window; FADED shortens it to a 2.1s debounce
    -- so pulse refreshes do not flicker while real range exits drop cleanly.
    for _,ability in ipairs(rule.recipients or {}) do
        event(ability,"aura",EVENT_COMBAT_EVENT,function(_,result,_,_,_,_,_,source,_,target,_,_,_,_,_,targetId,id)
            if id~=ability or source~=COMBAT_UNIT_TYPE_PLAYER or target==COMBAT_UNIT_TYPE_PLAYER or not targetId then return end
            local now=clock()
            if result==ACTION_RESULT_EFFECT_GAINED then
                s.targets=s.targets or {}; s.targets[targetId]=now+12000
                s.toggle=true
            elseif result==ACTION_RESULT_EFFECT_FADED then
                local existing=s.targets and s.targets[targetId]
                if not existing then return end
                local grace=now+2100
                if grace<existing then s.targets[targetId]=grace end
                return
            else return end
            local count=0; for uid,expiry in pairs(s.targets) do if expiry>now then count=count+1 else s.targets[uid]=nil end end
            s.stacks=count; self:PaintNow()
        end,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE)
    end
    if rule.opportunist then
        for _,ability in ipairs({135924,137985}) do
            event(ability,"recipient",EVENT_COMBAT_EVENT,function(_,result,_,_,_,_,_,source,_,_,_,_,_,_,_,targetId,id)
                if id==ability and source==COMBAT_UNIT_TYPE_PLAYER and result==ACTION_RESULT_EFFECT_GAINED and targetId then
                    s.targets=s.targets or {}; s.targets[targetId]=clock()+22000; self:PaintNow()
                end
            end,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,REGISTER_FILTER_COMBAT_RESULT,ACTION_RESULT_EFFECT_GAINED)
        end
    end
    if rule.trigger then
        local ability=rule.trigger
        event(ability,"cooldown",EVENT_COMBAT_EVENT,function(_,result,_,_,_,_,_,_,_,target,hit,_,_,_,_,_,id)
            if id~=ability or target~=COMBAT_UNIT_TYPE_PLAYER then return end
            if result==ACTION_RESULT_EFFECT_GAINED_DURATION then
                local length=type(hit)=="number" and hit>0 and hit or rule.cd
                if length and length>0 then
                    s.cdLength=length; s.cdEnd=clock()+length
                    if rule.triggerActive then s.triggerEnd=s.cdEnd; s.triggerLength=length end
                    self:PaintNow()
                end
            elseif result==ACTION_RESULT_EFFECT_FADED then
                s.cdEnd=0; s.triggerEnd=nil; self:PaintNow()
            end
        end,REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE)
    end
    if rule.release then
        local ability=rule.release
        event(ability,"release",EVENT_COMBAT_EVENT,function(_,result,_,_,_,_,_,source,_,_,_,_,_,_,_,_,id)
            if id==ability and source==COMBAT_UNIT_TYPE_PLAYER and RELEASE_RESULTS[result] then
                if rule.releaseDuration then
                    if s.phase~="armed" then return end
                    s.phase="released"; s.activeLength=rule.releaseDuration; s.activeEnd=clock()+rule.releaseDuration
                else s.activeEnd=0 end
                s.stacks=0; self:PaintNow()
            end
        end,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE)
    end
end
function C:Mark(s,unit,beginTime,endTime)
    local now=clock(); local r=s.rule
    local targetId=unit and unit>0 and unit or nil
    local start=type(beginTime)=="number" and beginTime>0 and beginTime*1000 or now
    if s.markStart and start<s.markStart-150 then return end
    if targetId and s.markTarget==targetId and (s.activeEnd or 0)>now and (s.cdEnd or 0)>now and not beginTime then return end
    local duplicate=s.markStart and math.abs(start-s.markStart)<150 and (s.markTarget==targetId or not s.markTarget or not targetId)
    if not duplicate then
        s.markStart=start; s.cdLength=r.cd; s.cdEnd=start+r.cd
    end
    s.markTarget=targetId or (duplicate and s.markTarget or nil)
    if s.markTarget~=nil then armMarkedDeath(self,s) else disarmMarkedDeath(self,s) end
    s.activeLength=r.duration
    s.activeEnd=type(endTime)=="number" and endTime*1000>now and endTime*1000 or start+r.duration
    self:PaintNow()
end
function C:Proc(s,ability,targetId)
    local now=clock(); local r=s.rule
    if r.countProcs then
        s.procCount=(s.procCount or 0)+1; self:PaintNow(); return
    end
    -- Target-specific ICDs must not prevent a proc on a different recipient.
    if r.perTarget and targetId and targetId~=0 then
        s.targetCDs=s.targetCDs or {}
        if (s.targetCDs[targetId] or 0)>now then return end
        for id,expiry in pairs(s.targetCDs) do if expiry<=now then s.targetCDs[id]=nil end end
        s.targetCDs[targetId]=now+(r.cd or 0)
    elseif r.cd and (s.cdEnd or 0)>now then return end
    -- Coalesce duplicate events from one AoE proc without blocking later procs.
    if s.lastProc and now-s.lastProc<150 then return end
    s.lastProc=now
    if r.release then s.phase="armed" end
    local duration=r.duration
    if r.apiDuration and ability and GetAbilityDuration then
        local actual=GetAbilityDuration(ability,nil,"player")
        if type(actual)=="number" and actual>0 then duration=actual end
    end
    if duration and duration>0 and r.jorvuld and self:HasJorvuld() then duration=duration*1.4 end
    if duration and duration>0 then
        s.activeLength=duration; s.activeEnd=now+duration
    end
    if r.ghost then s.ghostEnd=0 end
    if r.cd and not r.trigger then s.cdLength=r.cd; s.cdEnd=now+r.cd end
    self:PaintNow()
end
function C:ResetProcCounts()
    for _,s in pairs(self.states) do
        if s.rule and s.rule.countProcs then s.procCount=0 end
    end
    self:PaintNow()
end
function C:Effect(s,change,tag,beginTime,endTime,stacks,unit)
    if s.rule.targetStacks then
        if tag~="reticleover" then return end
    elseif tag~="player" then return end
    local now=clock()
    if change==EFFECT_RESULT_FADED then
        if s.unit and unit and s.unit~=unit then return end
        if beginTime and s.effectStart and beginTime<s.effectStart-.05 then return end
        -- Same start but an earlier end: the fade of the application before
        -- an extension (e.g. Kilt stacks refreshed). Keep the current stacks.
        if type(endTime)=="number" and endTime>0 and (s.activeEnd or 0)>0 and endTime*1000<s.activeEnd-50 and
            (not beginTime or not s.effectStart or beginTime<=s.effectStart+.05) then return end
        local inCombat=not IsUnitInCombat or IsUnitInCombat("player")
        if s.rule.consumeStacks and (s.consumePending or (inCombat and (s.stacks or 0)>=s.rule.consumeStacks-1 and ((s.activeEnd or 0)==0 or s.activeEnd>now+150))) then
            s.cdLength=s.rule.cd; s.cdEnd=now+s.rule.cd
        end
        s.consumePending=nil; s.activeEnd=0; s.stacks=0; s.effectStart=nil
    elseif change==EFFECT_RESULT_GAINED or change==EFFECT_RESULT_UPDATED then
        -- A delayed update of an older application (earlier start, or the
        -- same start with an earlier end) must not roll stacks/time back.
        if beginTime and s.effectStart and (not s.unit or not unit or s.unit==unit) then
            if beginTime<s.effectStart-.05 then return end
            if math.abs(beginTime-s.effectStart)<=.05 and type(endTime)=="number" and (s.activeEnd or 0)>0 and endTime*1000<s.activeEnd-50 then return end
        end
        if s.rule.effectCooldownOnGain and (change==EFFECT_RESULT_GAINED or (beginTime and s.effectStart and beginTime>s.effectStart+.05)) and (s.cdEnd or 0)<=now then
            s.cdLength=s.rule.cd; s.cdEnd=now+s.rule.cd
        end
        s.unit=unit; s.effectStart=beginTime
        local previous=s.stacks or 0
        s.stacks=s.rule.stacks and math.max(0,tonumber(stacks) or 0) or 0
        if s.rule.consumeStacks then
            if s.stacks>=s.rule.consumeStacks then s.consumePending=true
            elseif s.stacks==0 and (s.consumePending or previous>=s.rule.consumeStacks-1) then
                s.cdLength=s.rule.cd; s.cdEnd=now+s.rule.cd; s.consumePending=nil
            elseif s.stacks>0 then s.consumePending=nil end
        end
        if type(endTime)=="number" and endTime*1000>now then
            s.activeEnd=endTime*1000
            s.activeLength=math.max(1,(endTime-(beginTime or now/1000))*1000)
        else s.activeEnd=0 end
    else return end
    self:PaintNow()
end
function C:ReticleChanged(snapshot,noPaint)
    if not self.enabled then return end
    local wanted={}
    for _,s in pairs(self.states) do
        if s.rule.targetStacks then
            s.activeEnd=0; s.stacks=0; s.unit=nil; s.effectStart=nil
            for _,id in ipairs(s.rule.ids) do wanted[id]=s end
        elseif s.rule.mark then wanted[252048]=s
        elseif s.rule.zen then
            -- Never carry the previous enemy's count through a target change,
            -- even if the regular 500 ms scan is not due yet.
            s.specialAt=nil; s.zenApplied=false; s.zenDots=0; s.zenEnd=nil; s.zenCountVisible=false; s.value=""; s.progress=0; s.valueReady=false
        end
    end
    if next(wanted) and GetNumBuffs and GetUnitBuffInfo then
        local num,info=GetNumBuffs,GetUnitBuffInfo
        if snapshot then num,info=snapshot:Readers("reticleover") end
        for i=1,num("reticleover") or 0 do
            local _,start,finish,_,stacks,_,_,_,_,_,id,_,mine=info("reticleover",i)
            local s=wanted[id]
            if s and mine then
                if s.rule.mark then
                    if not s.markStart or (start or 0)*1000>s.markStart+150 then self:Mark(s,nil,start,finish) end
                else self:Effect(s,EFFECT_RESULT_UPDATED,"reticleover",start,finish,stacks) end
            end
        end
    end
    -- From the tick, the paint that follows uses the same snapshot.
    if not noPaint then self:PaintNow() end
end
function C:Recover(recoverPA,resetToggles)
    if recoverPA~=false then self:RefreshPARoster(true) end
    if not (GetNumBuffs and GetUnitBuffInfo) then return end
    local effects={}
    for _,s in pairs(self.states) do
        if resetToggles and s.rule.toggle then
            -- Zoning/death turns off Spaulder & clears Bloodlord target; only
            -- active observed player buffs below re-arm toggle="self".
            -- Do NOT wipe active toggle state when swapping an unrelated set.
            s.toggle=false; s.toggleTarget=nil; s.targets=nil; s.stacks=0
            disarmMarkedDeath(self,s)
        elseif resetToggles and s.rule.mark then
            s.activeEnd=nil; s.markTarget=nil; s.markStart=nil
            disarmMarkedDeath(self,s)
        end
        if not s.rule.pa and not s.rule.mark and not s.rule.targetStacks and (s.rule.effect or s.rule.duration or s.rule.toggle=="self") then
            for _,id in ipairs(s.rule.ids) do effects[id]=s end
        end
    end
    if not next(effects) then self:ReticleChanged(); return end
    for i=1,GetNumBuffs("player") or 0 do
        local _,start,finish,_,stacks,_,_,_,_,_,id,_,mine=GetUnitBuffInfo("player",i)
        if effects[id] and mine==true then
            local s=effects[id]
            if s.rule.toggle=="self" then s.toggle=true
            else
                self:Effect(s,EFFECT_RESULT_UPDATED,"player",start,finish,stacks)
                if s.rule.release and type(finish)=="number" and finish*1000>clock() and s.activeEnd and s.activeEnd>clock() then s.phase="armed" end
            end
            -- An effect that starts its cooldown on gain was gained at "start".
            if (not s.rule.effect or s.rule.effectCooldownOnGain) and s.rule.cd and start and start*1000+s.rule.cd>clock() then
                s.cdLength=s.rule.cd; s.cdEnd=start*1000+s.rule.cd
            end
        end
    end
    self:ReticleChanged()
end
function C:Refresh(recover)
    if not self.enabled then return end
    self.visualGen=(self.visualGen or 0)+1
    local gear,_,jFront,jBack=scanGear()
    local jChanged=self.jorvuldFront~=jFront or self.jorvuldBack~=jBack
    self.jorvuldFront,self.jorvuldBack=jFront,jBack
    local changed=false
    for key,s in pairs(self.states) do
        if not gear[key] then self:Unwatch(s); self.states[key]=nil; changed=true end
    end
    local added,paAdded=false,false
    for key,g in pairs(gear) do
        local s=self.states[key]
        if not s then
            s=g; s.cleanName=(s.name or ""):gsub("%^.*$",""); s.icon=iconFor(s); reset(s); self.states[key]=s; self:Watch(s); added=true; changed=true; if s.rule.pa then paAdded=true end
        else
            s.front=g.front; s.back=g.back; s.perfected=g.perfected; s.rawId=g.rawId
            if jChanged and s.rule.opportunist then s.specialAt=nil end
            if s.name~=g.name or s.link~=g.link then
                s.name=g.name; s.cleanName=(s.name or ""):gsub("%^.*$",""); s.link=g.link; s.icon=iconFor(s)
            end
        end
    end
    if changed then self:RebuildOrder(); self:Layout() end
    if recover or added then self:Recover(recover==true or paAdded,recover==true) end
    if recover or changed or jChanged then self:RefreshPower() end
    self:PaintNow()
end
function C:RebuildOrder()
    local cfg=self.owner.settings
    local filter=cfg.setCooldownFilter or {}
    self.order={}
    for _,s in pairs(self.states) do
        local selected=filter[preferenceKey(s.id,s.name)]==true
        if cfg.setCooldownFilterMode=="Only selected" and selected or cfg.setCooldownFilterMode=="Hide selected" and not selected or
            (cfg.setCooldownFilterMode~="Only selected" and cfg.setCooldownFilterMode~="Hide selected") then
            self.order[#self.order+1]=s
        else s.lastDisplayMode=nil; s.wasOnCooldown=false
        end
    end
    table.sort(self.order,function(a,b) return a.id<b.id end)
end
function C:ApplyConfig()
    self.visualGen=(self.visualGen or 0)+1
    if self.enabled then
        for _,s in pairs(self.states) do if s.rule.zen then s.specialAt=nil end end
        self:RebuildOrder(); self:Layout(); self:Sync(self.hudShown)
    end
end
function C:Reset()
    for _,s in pairs(self.states) do
        disarmMarkedDeath(self,s)
        reset(s)
        if s.rule.power then self:ComputeValue(s) end
    end
end
function C:Sync(show)
    self.hudShown=show
    local cfg=self.owner.settings
    local enabled=cfg.enabled and cfg.setCooldownEnabled
    local inCombat=IsUnitInCombat and IsUnitInCombat("player")
    local menuDemo=self.menuOpen and self.demo
    local wasVisible=self.visible
    self.visible=enabled and not self.owner.gamepadSuspended and ((show and (self.demo or self.owner.editing or cfg.setCooldownOutsideCombat~=false or inCombat)) or menuDemo) and true or false
    if wasVisible and not self.visible then
        for _,s in pairs(self.states) do s.lastDisplayMode=nil; s.wasOnCooldown=false end
        self:StopEffects()
    end
    if enabled and not self.enabled then
        self.enabled=true; self:Refresh(true); self:Layout()
    elseif not enabled and self.enabled then
        self:StopProbe(true)
        for _,s in pairs(self.states) do self:Unwatch(s) end
        self.states={}; self.order={}; self.enabled=false; self.demo=false
        self:StopEffects()
        for _,t in ipairs(self.pool) do t.p:SetHidden(true); t.hidden=true end
    end
    if self.visible and not wasVisible then
        for _,s in pairs(self.states) do if s.rule.zen then s.specialAt=nil end end
    end
    if self.enabled and self.layoutDemo~=(not not (self.demo or self.owner.editing)) then self:Layout() end
    if self.window then self.window:SetHidden(not self.visible) end
    local menuTick=self.visible and menuDemo and not show
    if menuTick and not self.menuTick then
        self.menuTick=true
        EVENT_MANAGER:RegisterForUpdate(PREFIX.."MenuPreview",100,function() self:PaintNow() end)
    elseif not menuTick and self.menuTick then
        self.menuTick=false; EVENT_MANAGER:UnregisterForUpdate(PREFIX.."MenuPreview")
    end
    if self.visible then self:PaintNow() end
    if self.owner.SyncWidgetDrag then self.owner:SyncWidgetDrag() end
end
function C:MenuOpened(open)
    self.menuOpen=open
    if not open and self.demo then self.demo=false; self:Layout() end
    self:Sync(self.hudShown)
end
function C:EnsureWindow()
    if self.window then return end
    self.window=WINDOW_MANAGER:CreateTopLevelWindow(PREFIX.."HUD")
    self.window:SetMouseEnabled(false)
    self.window:SetDrawTier(DT_HIGH)
    self.window:SetHidden(not self.visible)
    if self.owner.BindWidgetDrag then self.owner:BindWidgetDrag(self.window,"setCooldown",function() self:Position() end) end
end
local function createTile(self,index)
    self:EnsureWindow()
    local u=self.ui
    local p=u.panel(self.window,48,48,0,0)
    p:SetHidden(true)
    local tile={p=p,hidden=true}
    tile.base=u.texture(p,u.path.."square.dds",48,48,0,0,0)
    tile.icon=u.texture(p,nil,42,42,3,3,1)
    tile.fill=u.texture(p,u.path.."fill.dds",42,42,3,3,2)
    tile.fill:ClearAnchors(); tile.fill:SetAnchor(BOTTOMLEFT,p,BOTTOMLEFT,3,-3)
    tile.fill:SetHidden(true)
    tile.frame=u.texture(p,u.path.."frame.dds",48,48,0,0,3)
    tile.aura=u.texture(p,u.path.."procglow.dds",60,60,-6,-6,4)
    tile.aura:SetHidden(true)
    -- The action bar's own golden loop and fade-out. Same textures and the
    -- same renderer (A:SetGoldLoop / A:FlashWidget, drawn in A:Render), so
    -- a tile costs nothing per frame unless one of them is running.
    tile.widget=true
    tile.goldBase=u.texture(p,u.path.."glow.dds",72,72,-12,-12,4)
    tile.goldBase:SetColor(1,.76,.22,1); tile.goldBase:SetHidden(true)
    tile.goldBase2=u.texture(p,u.path.."glow.dds",70,70,-11,-11,4)
    tile.goldBase2:SetColor(1,.76,.22,1); tile.goldBase2:SetHidden(true)
    tile.goldLoop=u.texture(p,u.path.."goldloop.dds",64,64,-8,-8,5)
    tile.goldLoop:SetTextureCoords(0,1/8,0,1/4); tile.goldLoop:SetHidden(true)
    tile.glow=u.texture(p,u.path.."glow.dds",68,68,-10,-10,7)
    tile.wave=u.texture(p,u.path.."wave.dds",68,68,-10,-10,6)
    tile.burst=u.texture(p,u.path.."burst.dds",48,48,0,0,6)
    for _,c in ipairs({tile.glow,tile.wave,tile.burst}) do c:SetAlpha(0); c:SetHidden(true) end
    tile.time=u.text(p,24,48,48,0,0,9)
    tile.stack=u.text(p,15,19,18,28,0,10)
    tile.secondaryBg=u.texture(p,u.path.."square.dds",54,20,0,50,3)
    tile.secondaryBg:SetColor(.03,.035,.035,.9); tile.secondaryBg:SetHidden(true)
    tile.secondary=u.text(p,16,54,20,0,50,10)
    tile.resourceBg=u.texture(p,u.path.."square.dds",50,22,53,13,3)
    tile.resourceBg:SetColor(.03,.035,.035,.9); tile.resourceBg:SetHidden(true)
    tile.resource=u.text(p,16,50,22,53,13,10)
    tile.nameBg=u.texture(p,u.path.."square.dds",120,16,53,16,0)
    tile.name=u.text(p,12,120,16,53,16,9)
    tile.name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.pool[index]=tile
    return tile
end
-- Resource label threshold effect, built only for tiles that show a resource.
-- Reuses fill.dds (solid parts), ringburst.dds (moving light) and glow.dds (flash).
local function ensurePill(self,t)
    if t.pill then return t.pill end
    local u,p=self.ui,t.p
    local pill={}
    pill.halo=u.texture(p,u.path.."glow.dds",60,32,0,0,2)
    pill.fill=u.texture(p,u.path.."fill.dds",1,22,0,0,4)
    pill.edges={}
    for i=1,4 do pill.edges[i]=u.texture(p,u.path.."fill.dds",1,1,0,0,5) end
    pill.dot=u.texture(p,u.path.."ringburst.dds",16,16,0,0,6)
    for _,c in ipairs({pill.halo,pill.fill,pill.dot,unpack(pill.edges)}) do c:SetColor(1,.78,.25,1); c:SetHidden(true) end
    t.pill=pill
    return pill
end
local function place(c,p,w,h,x,y)
    c:SetDimensions(w,h); c:ClearAnchors(); c:SetAnchor(TOPLEFT,p,TOPLEFT,x,y)
end
function C:Position()
    if not self.window then return end
    local cfg=self.owner.settings
    self.window:ClearAnchors(); self.window:SetAnchor(CENTER,GuiRoot,CENTER,self.owner:UIUnits(cfg.setCooldownX),self.owner:UIUnits(cfg.setCooldownY))
end
function C:Layout()
    if not self.enabled then return end
    self.visualGen=(self.visualGen or 0)+1
    local cfg=self.owner.settings
    local demo=self.demo or self.owner.editing
    self.layoutDemo=not not demo
    local count=demo and 3 or #self.order
    if count==0 and not self.window then return end
    self:EnsureWindow()
    local gap=cfg.setCooldownGap
    local vertical=cfg.setCooldownDirection=="Vertical"
    self.window:SetScale(self.owner:HUDCanvasScale(cfg.setCooldownScale))
    self:Position()
    local cursor,cross=0,0
    for i=1,count do
        local t=self.pool[i] or createTile(self,i)
        local s=not demo and self.order[i]
        local override=s and (cfg.setCooldownOverrides or {})[preferenceKey(s.id,s.name)] or {}
        t.override=override
        local size=math.max(24,math.min(128,override.size or cfg.setCooldownIconSize or 48))
        local inset=math.max(2,math.floor(size/16+.5)); local inner=size-2*inset
        local nameW=math.max(120,size); local nameH=math.max(16,(cfg.setCooldownNameSize or 12)+5)
        local secondSize=math.max(8,math.min(32,tonumber(cfg.setCooldownSecondarySize) or 16))
        local footerW=math.max(size,math.ceil(secondSize*3.5+8))
        local footerH=math.max(18,secondSize+4)
        local previewRule=demo and i==1 and catalog.byName["way of martial knowledge"] or nil
        local hasResource=(s and s.rule.resourceSide) or (previewRule and previewRule.resourceSide)
        local resourceW,resourceH=math.max(48,math.ceil(secondSize*2.8+8)),math.max(20,secondSize+4)
        local contentW=math.max(size,footerW)+(hasResource and resourceW+4 or 0)
        local pos=cfg.setCooldownNamePosition or "Right"
        local ix,iy,nx,ny=(math.max(size,footerW)-size)/2,0,0,0
        local w,h=contentW,size+footerH+2
        if cfg.setCooldownNames then
            if pos=="Right" then nx=contentW+5; ny=(size-nameH)/2; w=contentW+5+nameW
            elseif pos=="Left" then ix=ix+nameW+5; ny=(size-nameH)/2; w=contentW+nameW+5
            elseif pos=="Above" then
                iy=nameH+3; w=math.max(nameW,contentW); nx=(w-nameW)/2; ix=ix+(w-contentW)/2; h=iy+size+footerH+2
            else
                w=math.max(nameW,contentW); nx=(w-nameW)/2; ix=ix+(w-contentW)/2
                ny=size+footerH+5; h=ny+nameH
            end
        end
        place(t.p,self.window,w,h,vertical and 0 or cursor,vertical and cursor or 0)
        cursor=cursor+(vertical and h or w)+gap; cross=math.max(cross,vertical and w or h)
        place(t.base,t.p,size,size,ix,iy)
        place(t.icon,t.p,inner,inner,ix+inset,iy+inset)
        place(t.frame,t.p,size,size,ix,iy)
        local bloom=math.floor(size/8+.5)
        place(t.aura,t.p,size+2*bloom,size+2*bloom,ix-bloom,iy-bloom)
        local function around(c,k)
            local d=math.floor(size*k+.5); place(c,t.p,d,d,ix+(size-d)/2,iy+(size-d)/2)
        end
        around(t.goldLoop,1.36); around(t.goldBase,1.53); around(t.goldBase2,1.47)
        local flashSize=math.floor(size*1.41+.5)
        t.glowSize=flashSize
        for _,c in ipairs({t.glow,t.wave,t.burst}) do c:ClearAnchors(); c:SetAnchor(CENTER,t.base,CENTER,0,0) end
        t.glow:SetDimensions(flashSize,flashSize); t.wave:SetDimensions(flashSize,flashSize); t.burst:SetDimensions(size,size)
        t.lastFlashSize=nil
        t.fill:ClearAnchors(); t.fill:SetAnchor(BOTTOMLEFT,t.base,BOTTOMLEFT,inset,-inset)
        t.fill:SetDimensions(inner,inner); t.inner=inner; t.height=nil; t.baseW=size; t.secondaryBgW=footerW
        place(t.time,t.p,size,size,ix+(cfg.setCooldownTimerX or 0)+(override.timerX or 0),iy+(cfg.setCooldownTimerY or 0)+(override.timerY or 0))
        local stackW,stackH=math.max(19,(cfg.setCooldownStackSize or 15)*1.4),math.max(18,(cfg.setCooldownStackSize or 15)+3)
        if s and s.rule.pa then stackW=math.max(stackW,math.ceil((cfg.setCooldownStackSize or 15)*3.1)) end
        stackW=math.max(1,math.min(size-2,stackW))
        t.stackRoom=math.max(1,stackW-2)
        t.paStackRoom=s and s.rule.pa and t.stackRoom or nil
        place(t.stack,t.p,stackW,stackH,ix+size-stackW-1,iy)
        place(t.secondaryBg,t.p,footerW,footerH,ix+(size-footerW)/2,iy+size+2)
        place(t.secondary,t.p,footerW,footerH,ix+(size-footerW)/2,iy+size+2)
        place(t.resourceBg,t.p,resourceW,resourceH,ix+size+4,iy+(size-resourceH)/2)
        place(t.resource,t.p,resourceW,resourceH,ix+size+4,iy+(size-resourceH)/2)
        if hasResource then
            local pill=ensurePill(self,t)
            local px,py,pw,ph=ix+size+4,iy+(size-resourceH)/2,resourceW,resourceH
            pill.x,pill.y,pill.w,pill.h=px,py,pw,ph; pill.fillW=nil; pill.dotStep=nil; pill.haloGrow=1
            local e=2
            place(pill.edges[1],t.p,pw,e,px,py); place(pill.edges[2],t.p,pw,e,px,py+ph-e)
            place(pill.edges[3],t.p,e,ph,px,py); place(pill.edges[4],t.p,e,ph,px+pw-e,py)
            local d=math.floor(ph*.8+.5); place(pill.dot,t.p,d,d,px-d/2,py-d/2); pill.dotSize=d
            pill.halo:ClearAnchors(); pill.halo:SetAnchor(CENTER,t.p,TOPLEFT,px+pw/2,py+ph/2); pill.halo:SetDimensions(pw+16,ph+16)
            pill.fill:ClearAnchors(); pill.fill:SetAnchor(TOPLEFT,t.p,TOPLEFT,px,py); pill.fill:SetDimensions(1,ph)
        elseif t.pill then
            self:SetPill(t,nil)
        end
        place(t.nameBg,t.p,nameW,nameH,nx,ny)
        place(t.name,t.p,nameW,nameH,nx,ny)
        local align=(pos=="Right" or pos=="Left") and TEXT_ALIGN_LEFT or TEXT_ALIGN_CENTER
        t.name:SetHorizontalAlignment(align)
        local positions={
            [t.time]={ix+(cfg.setCooldownTimerX or 0)+(override.timerX or 0),iy+(cfg.setCooldownTimerY or 0)+(override.timerY or 0)},
            [t.stack]={ix+size-stackW-1,iy},[t.secondary]={ix+(size-footerW)/2,iy+size+2},
            [t.resource]={ix+size+4,iy+(size-resourceH)/2},[t.name]={nx,ny},
        }
        local fontGen=self.owner and self.owner.fontGeneration or 0
        t.fonts={}; t.fitText={}; t.fitSize={}; t.fitAppliedGen={}; t.fitGeneration=fontGen; t.tileFontGen=fontGen
        for _,label in ipairs({t.time,t.stack,t.secondary,t.resource,t.name}) do
            local timerSize=math.max(8,math.min(tonumber(cfg.setCooldownFontSize) or 24,math.floor(size*.75)))
            local sizeLabel=label==t.time and timerSize or label==t.stack and (cfg.setCooldownStackSize or 15) or label==t.name and (cfg.setCooldownNameSize or 12) or secondSize
            local font=(cfg.setCooldownFont~="HUD font" and self.owner:ResolveFont(cfg.setCooldownFont)) or self.owner.effectiveFont
            local outline=cfg.setCooldownOutline~="HUD outline" and cfg.setCooldownOutline or cfg.fontStyle
            font=font or self.owner:ResolveFont(cfg.fontFace)
            self.owner:ApplyNativeFont(label,font,sizeLabel,outline or cfg.fontStyle,"widget")
            t.fonts[label]={font=font,size=sizeLabel,style=outline or cfg.fontStyle,x=positions[label][1],y=positions[label][2]}
            t.fitSize[label]=sizeLabel
            t.fitAppliedGen[label]=fontGen
        end
        self.ui.hidden(t.name,not cfg.setCooldownNames)
        t.nameBg:SetHidden(not (cfg.setCooldownNames and cfg.setCooldownNameBg))
        self.ui.hidden(t.resource,not hasResource)
        t.resourceBg:SetHidden(not hasResource)
        t.mode=nil
    end
    local total=math.max(1,cursor-gap)
    self.window:SetDimensions(vertical and math.max(1,cross) or total,vertical and total or math.max(1,cross))
    for i=count+1,#self.pool do
        local t=self.pool[i]
        self:SetLoop(t,false)
        if t.pill then self:SetPill(t,nil) end
        t.p:SetHidden(true); t.hidden=true
    end
end
-- Cache the applied font size per label so ordinary countdown ticks that fit at
-- spec.size never re-apply fonts or dirty anchors on every 100 ms digit change.
local function fitText(self,t,label,value,room)
    local spec=t.fonts and t.fonts[label]
    if not spec then return end
    local gen=self.owner and self.owner.fontGeneration or 0
    if t.fitGeneration~=gen then
        t.fitGeneration=gen
        t.fitText={}
    end
    local appliedGen=t.fitAppliedGen and t.fitAppliedGen[label]
    local staleGen=appliedGen~=gen or (label.vabFontGeneration~=nil and label.vabFontGeneration~=gen)
    if not staleGen and t.fitText[label]==value then return end
    t.fitText[label]=value
    local curSize=t.fitSize and t.fitSize[label] or spec.size
    local targetSize=spec.size
    if value~="" and ((self.owner and self.owner.MeasureStringUIWidth) or label.GetStringWidth) then
        if curSize~=spec.size or staleGen then
            self.owner:ApplyNativeFont(label,spec.font,spec.size,spec.style,"widget")
            curSize=spec.size
            staleGen=false
        end
        local width
        if self.owner and self.owner.MeasureStringUIWidth then
            width=self.owner:MeasureStringUIWidth(label,value)
        else
            local ok,w=pcall(label.GetStringWidth,label,value)
            width=ok and w or nil
        end
        if type(width)=="number" and width>room and width>0 then
            targetSize=math.max(8,math.floor(spec.size*room/width))
        end
    end
    if curSize~=targetSize or staleGen then
        self.owner:ApplyNativeFont(label,spec.font,targetSize,spec.style,"widget")
        label:ClearAnchors(); label:SetAnchor(TOPLEFT,t.p,TOPLEFT,spec.x,spec.y)
    end
    if t.fitSize then t.fitSize[label]=targetSize end
    if t.fitAppliedGen then t.fitAppliedGen[label]=gen end
end
function C:ToggleDemo()
    if not self.enabled then return end
    self.demo=not self.demo
    self:Layout()
    self:Sync(self.hudShown)
end
function C:PaintNow(snapshot)
    if not self.visible then return end
    self:Update(clock(),snapshot)
end
function C:UpdateSpecial(s,now,snapshot)
    local rule=s.rule
    if rule.pa then
        if (s.activeEnd or 0)>0 and now>=s.activeEnd then paRecount(s,now) end
        return
    end
    if not (rule.zen or rule.opportunist or rule.recipients) or (s.specialAt and now-s.specialAt<500) then return end
    s.specialAt=now
    if rule.recipients then
        -- Prune recipients whose 2.1s fade-debounce or 12s safety window elapsed.
        local count=0
        if s.targets then
            for id,expiry in pairs(s.targets) do
                if expiry>now then count=count+1 else s.targets[id]=nil end
            end
        end
        s.stacks=count
    end
    if rule.zen then
        local count,applied,markEnd=0,false,nil
        local tag=zenTarget(self,self.owner.settings)
        local method=self.owner.settings.setCooldownZenCountMode or "All"
        if GetNumBuffs and GetUnitBuffInfo then
            local num,info=GetNumBuffs,GetUnitBuffInfo
            if snapshot then num,info=snapshot:Readers(tag) end
            for i=1,num(tag) or 0 do
                local _,start,finish,_,_,_,_,_,abilityType,_,id,_,mine=info(tag,i)
                -- Each wearer applies their own mark; only mine counts.
                if id==rule.ids[1] and mine then
                    applied=true
                    if type(finish)=="number" and finish*1000>now then
                        markEnd=math.max(markEnd or 0,finish*1000)
                    end
                elseif zenDot(start,finish,abilityType,mine,method) then count=count+1 end
            end
        end
        s.zenApplied=applied; s.zenDots=count; s.zenEnd=markEnd
        s.zenCountVisible=method=="Timed" and applied or method~="Timed" and count>0
        s.value=s.zenCountVisible and tostring(count) or ""
        s.progress=applied and math.min(1,count/5) or 0; s.valueReady=applied and count>=5
    end
    if rule.opportunist then
        local roAbility=s.perfected and 137986 or 135923
        local duration=GetAbilityDuration and GetAbilityDuration(roAbility,nil,"player")
        if type(duration)=="number" and duration>0 then
            if rule.jorvuld and self:HasJorvuld() then duration=duration*1.4 end
            s.preview=string.format("%.1fs",duration/1000)
        else s.preview=nil end
        local count=0
        if s.targets then
            for id,expiry in pairs(s.targets) do
                if expiry>now then count=count+1 else s.targets[id]=nil end
            end
        end
        s.stacks=count
    end
end
local stateColors={active="setCooldownActiveColor",cooldown="setCooldownCooldownColor",ready="setCooldownReadyColor",offbar="setCooldownOffBarColor",value="setCooldownValueColor",zenLow="lastColor",zenMedium="setCooldownReadyColor"}
local stateAlphas={active="setCooldownActiveAlpha",cooldown="setCooldownCooldownAlpha",ready="setCooldownReadyAlpha",offbar="setCooldownOffBarAlpha",value="setCooldownValueAlpha",zenLow="setCooldownActiveAlpha",zenMedium="setCooldownActiveAlpha"}
function C:PlayAlert(name)
    if name and name~="None" and PlaySound and SOUNDS and SOUNDS[name] then PlaySound(SOUNDS[name]) end
end
local MIN_LOOP_ICD=3000
local function effectKind(r)
    if r.toggle then return nil end
    if r.martial then return "loop" end
    if r.power then return "value" end
    if r.zen then return "flash" end
    if r.cd and r.cd<MIN_LOOP_ICD then return nil end
    if r.opportunist or r.perTarget or r.targetTracking then return "flash" end
    if r.cd or r.mark then return "loop" end
    return "flash"
end
function C:SetLoop(t,on)
    if t.loopOn==on then return end
    t.loopOn=on
    if self.owner.SetGoldLoop then self.owner:SetGoldLoop(t,on) end
end
function C:Flash(t)
    if self.owner.FlashWidget then self.owner:FlashWidget(t) end
end
function C:SetPill(t,state,frac,flash)
    local pill=t.pill
    if not pill then return end
    if state~=pill.state then
        pill.state=state
        local on=state=="max"
        for _,e in ipairs(pill.edges) do e:SetHidden(not on) end
        pill.dot:SetHidden(not on); pill.halo:SetHidden(not on)
        pill.fill:SetHidden(state==nil)
        pill.fill:SetColor(1,.78,.25,on and .38 or .20)
        self.pills=self.pills or {}
        if on then
            pill.dotStep=nil
            if not self.pills[t] then self.pills[t]=GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0; self.pillCount=(self.pillCount or 0)+1 end
        elseif self.pills[t] then
            self.pills[t]=nil; self.pillCount=math.max(0,(self.pillCount or 1)-1); pill.flashAt=nil
        end
    end
    if state then
        local w=math.max(1,math.floor(pill.w*math.max(0,math.min(1,frac or 0))+.5))
        if pill.fillW~=w then pill.fill:SetDimensions(w,pill.h); pill.fillW=w end
    end
    if flash and state=="max" then pill.flashAt=GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0 end
end
function C:RenderPills(now)
    local period=math.max(250,self.owner.settings.loopPeriod or 1150)
    for t,start in pairs(self.pills or {}) do
        local pill=t.pill
        local per=2*(pill.w+pill.h)
        local step=math.floor(((now-start)%period)*48/period)
        if pill.dotStep~=step then
            pill.dotStep=step
            local d=step/48*per
            local x,y
            if d<pill.w then x,y=pill.x+d,pill.y
            elseif d<pill.w+pill.h then x,y=pill.x+pill.w,pill.y+d-pill.w
            elseif d<2*pill.w+pill.h then x,y=pill.x+pill.w-(d-pill.w-pill.h),pill.y+pill.h
            else x,y=pill.x,pill.y+pill.h-(d-2*pill.w-pill.h) end
            local dx,dy=x-pill.dotSize/2,y-pill.dotSize/2
            if pill.dot.SetAnchorOffsets then pill.dot:SetAnchorOffsets(dx,dy)
            else pill.dot:ClearAnchors(); pill.dot:SetAnchor(TOPLEFT,t.p,TOPLEFT,dx,dy) end
            local breathe=.72+.28*math.cos((now-start)*2*math.pi/period)
            local f=pill.flashAt and (now-pill.flashAt)/700
            if f and f>=1 then pill.flashAt=nil; f=nil end
            local boost=f and (1-f)^1.3 or 0
            pill.halo:SetAlpha(math.min(1,.45*breathe+boost))
            local grow=f and 1+.35*(1-(1-f)^2) or 1
            if pill.haloGrow~=grow then
                pill.haloGrow=grow
                pill.halo:SetDimensions((pill.w+16)*grow,(pill.h+16)*grow)
            end
            for _,e in ipairs(pill.edges) do e:SetAlpha(math.min(1,breathe+boost)) end
        end
    end
end
function C:StopEffects()
    for _,t in ipairs(self.pool) do
        self:SetLoop(t,false)
        if t.pill then self:SetPill(t,nil) end
    end
end
function C:ApplyEffects(t,s,now,mode,demo,hide,isAvailable,cd,active,stacks,inCombat)
    local cfg=self.owner.settings
    local r=s.rule
    local kind=effectKind(r)
    local animations=cfg.animations~=false and cfg.setCooldownShowGlow~=false
    if inCombat==nil then inCombat=IsUnitInCombat and IsUnitInCombat("player") or false end
    local loop=false
    if animations and cfg.setCooldownBorderAnimation~=false and not hide then
        if demo then loop=mode=="ready"
        elseif kind=="loop" then loop=inCombat and isAvailable and cd<=0 and (not r.martial or s.valueReady==true) end
    end
    self:SetLoop(t,loop)
    local auraHidden=cfg.setCooldownShowGlow==false or mode=="offbar" or mode=="value" or loop
    if t.auraHidden~=auraHidden then t.aura:SetHidden(auraHidden); t.auraHidden=auraHidden end
    local fire=false
    if not demo then
        if kind=="loop" then
            local cdEnd=s.cdEnd or 0
            fire=s.fxCd~=nil and cdEnd>s.fxCd+50 and cdEnd>now
            s.fxCd=cdEnd
        elseif kind=="flash" then
            local on=(r.zen and s.valueReady==true) or (not r.zen and (active>0 or stacks>0))
            fire=s.fxOn==false and on
            s.fxOn=on
        end
    end
    local reached=s.valueReady==true
    local crossed=not demo and s.fxReady==false and reached
    if not demo then s.fxReady=reached end
    if r.resourceSide and t.pill then
        local state=cfg.setCooldownResourceGlow~=false and cfg.animations~=false and not hide and (reached and "max" or "fill") or nil
        if demo then state=cfg.setCooldownResourceGlow~=false and "fill" or nil end
        self:SetPill(t,state,demo and .58 or s.pillFrac,crossed and cfg.setCooldownProcFlash~=false)
    elseif kind=="value" and crossed then
        fire=true
    end
    if fire and not hide and cfg.setCooldownProcFlash~=false and cfg.animations~=false then self:Flash(t) end
end
function C:Update(now,snapshot)
    if not self.visible then return end
    local cfg=self.owner.settings
    local list=self.order
    local demo=self.demo or self.owner.editing
    if demo then
        local t=now%8000
        local demoList=self.demoList
        if not demoList then
            demoList={
                {name="Martial Knowledge",cleanName="Martial Knowledge",rule=catalog.byName["way of martial knowledge"],
                    activeEnd=0,activeLength=5000,cdEnd=0,cdLength=8000,resourcePercent="42%",stacks=0,front=true,back=true},
                {name="Set cooldown",cleanName="Set cooldown",rule={ids={97714}},activeEnd=0,cdEnd=0,cdLength=8000,stacks=0,front=true,back=true},
                {name="Set ready",cleanName="Set ready",rule={ids={172671}},activeEnd=0,cdEnd=0,stacks=0,front=true,back=true},
            }
            self.demoList=demoList
        end
        demoList[1].activeEnd=t<5000 and now+5000-t or 0
        demoList[1].cdEnd=now+8000-t
        demoList[2].cdEnd=now+8000-t
        list=demoList
    end
    if #list==0 then return end
    local activeBar=GetActiveHotbarCategory and GetActiveHotbarCategory()
    local inCombat=IsUnitInCombat and IsUnitInCombat("player") or false
    local visualGen=self.visualGen or 1
    local fontGen=self.owner and self.owner.fontGeneration or 0
    for i,s in ipairs(list) do
        local t=self.pool[i]
        if t then
            self:UpdateSpecial(s,now,snapshot)
            local phaseActive=(s.triggerEnd or 0)>now
            local active=math.max(0,math.max(s.activeEnd or 0,s.triggerEnd or 0)-now)
            local cd=math.max(0,(s.cdEnd or 0)-now)
            local stacks=s.stacks or 0
            local ghost=math.max(0,(s.ghostEnd or 0)-now)
            if (s.activeEnd or 0)>0 and s.activeEnd<=now then
                s.activeEnd=0
                if s.markTarget~=nil then s.markTarget=nil; disarmMarkedDeath(self,s) end
                if not (s.rule.opportunist or s.rule.recipients) then stacks=0; s.stacks=0 end
            end
            local isAvailable=available(s,activeBar)
            local dynamic=s.rule.power or s.rule.zen or s.rule.toggle
            local zenActive=s.rule.zen and s.zenApplied
            local mode=zenActive and ((s.zenDots or 0)>=4 and "active" or (s.zenDots or 0)>=2 and "zenMedium" or "zenLow") or
                (active>0 or ghost>0 or (stacks>0 and not s.rule.opportunist) or s.toggle) and "active" or cd>0 and "cooldown" or not isAvailable and "offbar" or
                (s.valueReady and not s.rule.martial) and "active" or dynamic and "value" or "ready"
            self:BindTileIcon(t,s)
            local hide=not demo and ((mode=="ready" and not cfg.setCooldownReady) or (mode=="offbar" and cfg.setCooldownOffBar==false))
            if t.hidden~=hide then t.p:SetHidden(hide); t.hidden=hide end
            if not demo then
                local old=s.lastDisplayMode
                s.lastDisplayMode=mode
                if mode=="active" or mode=="cooldown" then s.wasOnCooldown=true end
                if not self.menuOpen and old and old~=mode and not dynamic then
                    local override=t.override
                    local procSound=override and override.procSound or cfg.setCooldownProcSound
                    local readySound=override and override.readySound or cfg.setCooldownReadySound
                    if mode=="active" and old~="offbar" then self:PlayAlert(procSound)
                    elseif mode=="cooldown" and (old=="ready" or old=="offbar") then self:PlayAlert(procSound)
                    elseif mode=="ready" and (old=="active" or old=="cooldown" or (old=="offbar" and s.wasOnCooldown)) then
                        s.wasOnCooldown=false; self:PlayAlert(readySound)
                    end
                elseif mode=="ready" then
                    s.wasOnCooldown=false
                end
            end
            if hide then
                self:ApplyEffects(t,s,now,mode,demo,hide,isAvailable,cd,active,stacks,inCombat)
            else
                if t.mode~=mode then
                    t.mode=mode
                    local c=(t.override and mode=="active" and t.override.activeColor) or
                        (t.override and mode=="cooldown" and t.override.cooldownColor) or cfg[stateColors[mode]] or {1,1,1,1}
                    local r,g,b,a=c[1],c[2],c[3],c[4] or 1
                    t.p:SetAlpha(cfg[stateAlphas[mode]] or 1)
                    t.icon:SetDesaturation(cfg.setCooldownDesaturate~=false and (mode=="cooldown" and .65 or mode=="offbar" and .85 or 0) or 0)
                    t.icon:SetAlpha(1)
                    self.ui.color(t.aura,r,g,b,a*(mode=="ready" and .95 or .75))
                    t.frame:SetHidden(cfg.setCooldownShowFrame==false)
                    if cfg.setCooldownColorFrame then t.frame:SetColor(r,g,b,a) else t.frame:SetColor(1,1,1,1) end
                    self.ui.color(t.time,unpack(cfg.setCooldownColorTimer~=false and c or cfg.setCooldownTimerColor or {1,1,1,1}))
                    self.ui.color(t.stack,unpack(cfg.setCooldownStackColor or {.55,.87,1,1}))
                    self.ui.color(t.secondary,unpack(cfg.setCooldownSecondaryColor or {.94,.45,1,1}))
                    self.ui.color(t.resource,1,1,1,1)
                    self.ui.color(t.name,unpack(cfg.setCooldownNameColor or {1,1,1,1}))
                    t.fill:SetColor(r,g,b,.7*a)
                end
                local value=s.rule.toggle and (s.toggle and "ON" or "OFF") or s.value
                if s.rule.countProcs and cfg.setCooldownResourceValue==false then value=nil end
                local decimal=cfg.setCooldownDecimal
                local timeKind,timeVal,timeMs=0,"",nil
                if s.rule.zen then
                    if zenActive and s.zenEnd then
                        timeMs=math.max(0,s.zenEnd-now)
                        timeKind,timeVal=fmtKey(timeMs,decimal)
                    end
                elseif active>0 then
                    timeMs=active; timeKind,timeVal=fmtKey(active,decimal)
                elseif ghost>0 then
                    timeMs=ghost; timeKind,timeVal=fmtKey(ghost,decimal)
                elseif cd>0 and not s.rule.martial then
                    timeMs=cd; timeKind,timeVal=fmtKey(cd,decimal)
                elseif isAvailable and not s.rule.martial and value then
                    timeKind,timeVal=3,value
                end
                if t.timeKind~=timeKind or t.timeVal~=timeVal or t.timeDec~=decimal or t.timeVisGen~=visualGen or t.timeFontGen~=fontGen then
                    local timerText
                    if timeKind==1 then timerText=fmt(timeMs,decimal)
                    elseif timeKind==2 then timerText=intStr(timeVal)
                    elseif timeKind==3 then timerText=timeVal
                    else timerText="" end
                    t.timeKind,t.timeVal,t.timeDec,t.timeVisGen,t.timeFontGen=timeKind,timeVal,decimal,visualGen,fontGen
                    self.ui.setText(t.time,timerText)
                    fitText(self,t,t.time,timerText,math.max(1,(t.baseW or (t.base.GetWidth and t.base:GetWidth()) or 48)-4))
                end
                if t.tileFontGen~=fontGen then
                    t.tileFontGen=fontGen
                    local resSpec=t.fonts and t.fonts[t.resource]
                    if resSpec then self.owner:ApplyNativeFont(t.resource,resSpec.font,resSpec.size,resSpec.style,"widget") end
                    local nameSpec=t.fonts and t.fonts[t.name]
                    if nameSpec then self.owner:ApplyNativeFont(t.name,nameSpec.font,nameSpec.size,nameSpec.style,"widget") end
                end
                self.ui.setText(t.resource,s.rule.resourceSide and (s.resourcePercent or "—") or "")
                local stackKind,stackVal=0,""
                if cfg.setCooldownShowStacks~=false then
                    if s.rule.pa then
                        if stacks>0 then stackKind,stackVal=1,s.paCountText or "" end
                    elseif s.rule.zen then
                        if s.zenCountVisible then stackKind,stackVal=2,s.zenDots or 0 end
                    elseif s.rule.countProcs then
                        if cfg.setCooldownProcCount~=false then stackKind,stackVal=2,s.procCount or 0 end
                    elseif stacks>0 and (not s.rule.opportunist or cfg.setCooldownROCount~=false) then
                        stackKind,stackVal=2,stacks
                    end
                end
                if t.stackKind~=stackKind or t.stackVal~=stackVal or t.stackVisGen~=visualGen or t.stackFontGen~=fontGen then
                    local stackText
                    if stackKind==1 then stackText=stackVal
                    elseif stackKind==2 then stackText=intStr(stackVal)
                    else stackText="" end
                    t.stackKind,t.stackVal,t.stackVisGen,t.stackFontGen=stackKind,stackVal,visualGen,fontGen
                    self.ui.setText(t.stack,stackText)
                    fitText(self,t,t.stack,stackText,t.stackRoom or t.paStackRoom or 40)
                end
                local secKind,secVal,secMs=0,"",nil
                if s.rule.martial and cd>0 then
                    secMs=cd; secKind,secVal=fmtKey(cd,decimal)
                elseif active>0 and ghost>0 then
                    secMs=ghost; secKind,secVal=fmtKey(ghost,decimal)
                elseif active>0 and cd>0 and cfg.setCooldownBoth then
                    secMs=cd; secKind,secVal=fmtKey(cd,decimal)
                elseif cfg.setCooldownRODuration~=false and s.preview then
                    secKind,secVal=3,s.preview
                elseif (active>0 or cd>0) and isAvailable and not s.rule.resourceSide and value then
                    secKind,secVal=3,value
                end
                if t.secKind~=secKind or t.secVal~=secVal or t.secDec~=decimal or t.secVisGen~=visualGen or t.secFontGen~=fontGen then
                    local secondary
                    if secKind==1 then secondary=fmt(secMs,decimal)
                    elseif secKind==2 then secondary=intStr(secVal)
                    elseif secKind==3 then secondary=secVal
                    else secondary="" end
                    t.secKind,t.secVal,t.secDec,t.secVisGen,t.secFontGen=secKind,secVal,decimal,visualGen,fontGen
                    self.ui.setText(t.secondary,secondary)
                    fitText(self,t,t.secondary,secondary,math.max(1,(t.secondaryBgW or (t.secondaryBg.GetWidth and t.secondaryBg:GetWidth()) or 54)-4))
                    local secondaryShown=secondary~=""
                    if t.secondaryShown~=secondaryShown then t.secondaryBg:SetHidden(not secondaryShown); t.secondaryShown=secondaryShown end
                end
                self:ApplyEffects(t,s,now,mode,demo,hide,isAvailable,cd,active,stacks,inCombat)
                local cleanName=s.cleanName
                if not cleanName then cleanName=(s.name or ""):gsub("%^.*$",""); s.cleanName=cleanName end
                self.ui.setText(t.name,cleanName)
                local remain=active>0 and active or ghost>0 and ghost or cd
                local total=active>0 and (phaseActive and s.triggerLength or s.activeLength) or ghost>0 and s.ghostLength or s.cdLength
                local fraction=remain>0 and total and total>0 and math.max(0,math.min(1,remain/total)) or (isAvailable or zenActive) and s.progress or 0
                local inner=t.inner or 42
                local height=cfg.setCooldownShowFill~=false and math.floor(inner*fraction+.5) or 0
                if t.height~=height then
                    t.height=height; t.fill:SetHidden(height==0)
                    if height>0 then t.fill:SetDimensions(inner,height); t.fill:SetTextureCoords(0,1,1-fraction,1) end
                end
            end
        end
    end
end
function C:Report()
    if not self.enabled then d("Zera UI set cooldowns: disabled"); return end
    d("Zera UI set cooldowns: "..#self.order.." supported equipped sets")
    for _,s in ipairs(self.order) do d(string.format("%s [%d] | %s | %s",s.name,s.id,table.concat(s.rule.ids,", "),s.front and s.back and "both bars" or s.front and "front bar" or "back bar")) end
end
-- A one-shot diagnostic only. In particular, do not assume that Chilled or
-- Concussion are DoTs, or attribute another player's status effects to us.
function C:ReportZen()
    if not (GetNumBuffs and GetUnitBuffInfo) then d("Zera UI Z'en: effect API unavailable."); return end
    self:RefreshBosses()
    local tag=zenTarget(self,self.owner.settings)
    local s=self.states[catalog.byName["z'en's redress"]]
    local observed,marked=0,false
    local method=self.owner.settings.setCooldownZenCountMode or "All"
    d(string.format("Zera UI Z'en: target=%s (%s), set=%s, method=%s. Effects: ID, duration, type, status, mine, All/Timed.",
        tag,tostring(GetUnitName and GetUnitName(tag) or "?"),s and "equipped" or "not equipped/enabled",method))
    local count=0
    for i=1,GetNumBuffs(tag) or 0 do
        local name,start,finish,_,_,_,_,_,abilityType,statusType,id,_,mine=GetUnitBuffInfo(tag,i)
        if id==126597 and mine then marked=true end
        if type(start)=="number" and type(finish)=="number" and finish>start or zenDot(start,finish,abilityType,mine,"All") then
            count=count+1
            local counted=id~=126597 and zenDot(start,finish,abilityType,mine,method)
            if counted then observed=observed+1 end
            local duration=type(start)=="number" and type(finish)=="number" and string.format("%.1fs",finish-start) or "?"
            d(string.format("%s [%s] %s type=%s status=%s mine=%s %s/%s",tostring(name or "?"),tostring(id),duration,tostring(abilityType),tostring(statusType),tostring(mine),
                tostring(zenDot(start,finish,abilityType,mine,"All")),tostring(zenDot(start,finish,abilityType,mine,"Timed"))))
        end
    end
    if count==0 then d("Zera UI Z'en: no timed effects on the target."); end
    d(string.format("Zera UI Z'en: mark=%s, observed damage effects=%d (bonus capped at 5).",tostring(marked),observed))
end
function C:ReportGear()
    local supported,gear=scanGear()
    if not next(gear) then
        d("Zera UI gear: no item set data returned by ESO. Check equipped gear, then /zera sets refresh.")
        return
    end
    local ids={}
    for id in pairs(gear) do ids[#ids+1]=id end
    table.sort(ids)
    for _,id in ipairs(ids) do
        local g=gear[id]
        local rule=rowFor(id,g.name)
        local key=normalized(g.name)
        local status=g.suppressed and "SUPPRESSED"
            or (rule and (supported[rule] and "TRACKABLE" or "NOT ENOUGH PIECES"))
            or (catalog.passive[id] or key=="slimecraw" or key=="velothi ur-mage's amulet") and "NO TIMED PROC"
            or catalog.pending[key] and "NEEDS EFFECT ID (/zera sets probe)" or "NOT IN CATALOG"
        d(string.format("Zera UI gear: %s [%d] F:%d B:%d / %d | %s",g.name,id,g.body+g.front,g.body+g.back,g.required,status))
    end
end
