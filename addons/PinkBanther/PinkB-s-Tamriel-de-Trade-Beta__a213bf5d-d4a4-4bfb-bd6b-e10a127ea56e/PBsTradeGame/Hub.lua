-- Pure simulation: no ESO API, wall clock or shared gameplay RNG.
local H={}; PBTrade.Hub=H
local K=PBTrade.HubData
local function finite(n) return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge end
local function integer(n,lo,hi) return finite(n) and n==math.floor(n) and n>=lo and n<=hi end
function H.Capacity(chapter) local n=H.Size(chapter); return math.ceil(n*n*K.capacityShare) end
function H.Size(chapter) return K.chapterSize[math.min(5,math.max(3,chapter or 3))] or K.size end
function H.New(cycle)
    return {version=K.version,buildings={},annex={},blueprints={},policy="balanced",eventSeed=K.eventSeed,lastEventCycle=cycle or 0,eventLog={},decorationSeed=K.decoration.seed,nextBuildingId=1,lastSettledCycle=cycle or 0,growth=0,introSeen=false}
end
function H.Load(saved,cycle,chapter)
    local size=H.Size(chapter)
    local h=H.New(cycle)
    if type(saved)~="table" then return h end
    for id in pairs(K.blueprints) do h.blueprints[id]=type(saved.blueprints)=="table" and saved.blueprints[id]==true or nil end
    h.policy=K.policyById[saved.policy] and saved.policy or "balanced"
    h.pendingPolicy=K.policyById[saved.pendingPolicy] and saved.pendingPolicy or nil
    h.eventSeed=integer(saved.eventSeed,1,2147483646) and saved.eventSeed or K.eventSeed
    h.lastEventCycle=integer(saved.lastEventCycle,0,cycle or 0) and saved.lastEventCycle or (cycle or 0)
    local event=type(saved.activeEvent)=="table" and K.eventById[saved.activeEvent.id]
    if event and integer(saved.activeEvent.remaining,1,event.duration) then h.activeEvent={id=event.id,remaining=saved.activeEvent.remaining} end
    for _,entry in ipairs(type(saved.eventLog)=="table" and saved.eventLog or {}) do
        if type(entry)=="table" and K.eventById[entry.id] and integer(entry.cycle,0,cycle or 0) then h.eventLog[#h.eventLog+1]={id=entry.id,cycle=entry.cycle} end
        if #h.eventLog>=K.eventLogLimit then break end
    end
    h.introSeen=saved.introSeen==true
    h.growth=finite(saved.growth) and math.max(0,math.min(saved.growth,1e9)) or 0
    -- The enclosing campaign cycle is authoritative; loading never pays historical income.
    h.decorationSeed=integer(saved.decorationSeed,1,2147483646) and saved.decorationSeed or K.decoration.seed
    local cells,ids,pending={},{},{}
    local function read(list,isAnnex)
        for _,b in ipairs(type(list)=="table" and list or {}) do
            if type(b)=="table" and K.byId[b.type] and integer(b.x,1,K.maximumSize) and integer(b.y,1,K.maximumSize)
                and integer(b.id,1,1000000) and not ids[b.id]
                and finite(b.paidCost) and b.paidCost>=0 and b.paidCost<=K.maximumCost then
                local remaining=integer(b.remainingPeriods,0,K.byId[b.type].periods) and b.remainingPeriods or K.byId[b.type].periods
                local level=integer(b.level,1,K.maxLevel) and b.level or 1
                local target=remaining>0 and integer(b.targetLevel,level+1,level+1) and b.targetLevel<=K.maxLevel and b.targetLevel or nil
                local copy={id=b.id,type=b.type,x=b.x,y=b.y,level=level,targetLevel=target,paidCost=b.paidCost,remainingPeriods=remaining}
                ids[b.id]=true; h.nextBuildingId=math.max(h.nextBuildingId,b.id+1)
                if isAnnex then h.annex[#h.annex+1]=copy
                elseif b.x>size or b.y>size then pending[#pending+1]=copy
                elseif not cells[b.x..":"..b.y] then
                    cells[b.x..":"..b.y]=true; h.buildings[#h.buildings+1]=copy
                end
            end
        end
    end
    read(saved.buildings,false); read(saved.annex,true)
    -- Keep in-bounds buildings fixed; move old 8x8 outliers into free plots, then retain
    -- excess as an operating legacy district. No investment or construction is deleted.
    for _,b in ipairs(pending) do
        local placed=false
        for y=1,size do for x=1,size do
            if not placed and not cells[x..":"..y] then
                b.x,b.y=x,y; cells[x..":"..y]=true; h.buildings[#h.buildings+1]=b; placed=true
            end
        end end
        if not placed then h.annex[#h.annex+1]=b end
    end
    return h
end
function H.Catalogue(chapter)
    local list={}; for _,f in ipairs(K.facilities) do if (chapter or 1)>=(f.minChapter or K.minChapter) then list[#list+1]=f end end
    return list
end
function H.Operating(h)
    local policy=K.policyById[h.policy] or K.policyById.balanced
    local event=h.activeEvent and K.eventById[h.activeEvent.id]
    local severity=event and event.adverse and (policy.adverse or 1) or 1
    return {policy=policy,event=event,income=policy.income*(1+((event and event.income or 1)-1)*severity),
        upkeep=policy.upkeep*(1+((event and event.upkeep or 1)-1)*severity)}
end
function H.QueuePolicy(h,chapter,id)
    if chapter<K.minChapter or not K.policyById[id] then return false end
    h.pendingPolicy=id; return true
end
function H.EventStep(h,cycle,occupied)
    if h.activeEvent then
        h.activeEvent.remaining=h.activeEvent.remaining-1
        if h.activeEvent.remaining<=0 then h.activeEvent=nil end
    end
    if not occupied or h.activeEvent or cycle-h.lastEventCycle<K.eventGap then return end
    local function random() h.eventSeed=(h.eventSeed*48271+11)%2147483647; return h.eventSeed/2147483647 end
    if random()>=K.eventChance then return end
    local e=K.events[math.floor(random()*#K.events)+1]
    h.activeEvent={id=e.id,remaining=e.duration}; h.lastEventCycle=cycle
    table.insert(h.eventLog,1,{id=e.id,cycle=cycle})
    while #h.eventLog>K.eventLogLimit do table.remove(h.eventLog) end
    return e
end
function H.Expand(h,chapter)
    local size=H.Size(chapter); local placed=0
    if size<=K.size then return 0 end
    local remaining={}
    for _,b in ipairs(h.annex or {}) do
        local spot
        if b.x<=size and b.y<=size and not H.At(h,b.x,b.y) then spot={b.x,b.y} end
        if not spot then for y=1,size do for x=1,size do
            if not spot and not H.At(h,x,y) then spot={x,y} end
        end end end
        if spot then b.x,b.y=spot[1],spot[2]; h.buildings[#h.buildings+1]=b; placed=placed+1
        else remaining[#remaining+1]=b end
    end
    h.annex=remaining; return placed
end
function H.LearnBlueprints(h,supply)
    h.blueprints=h.blueprints or {}
    for id in pairs(K.blueprints) do if (supply[id] or 0)>0 then h.blueprints[id]=true end end
end
function H.At(h,x,y) for _,b in ipairs(h.buildings) do if b.x==x and b.y==y then return b end end end
function H.All(h)
    local all={}
    for _,list in ipairs({h.buildings,h.annex or {}}) do for _,b in ipairs(list) do all[#all+1]=b end end
    return all
end
-- A connected central promenade. Cosmetic paving never consumes buildable land.
function H.Ground(x,y,size)
    local center=math.ceil((size or K.size)/2)
    return (x==center or y==center) and "hub_walkway" or "hub_ground"
end
function H.Decoration(h,x,y,size)
    local n=((h.decorationSeed or K.decoration.seed)+x*7381+y*19391)%2147483647
    for _=1,2 do n=(n*48271+11)%2147483647 end
    local roll=n%100
    if H.Ground(x,y,size)=="hub_walkway" or roll<K.decoration.plainShare then return nil,n%3 end
    return roll<K.decoration.plainShare+K.decoration.treeShare and "tree" or "cypress",n%3
end
local function add(out,values,multiplier)
    for key,value in pairs(values) do out[key]=(out[key] or 0)+value*(multiplier or 1) end
end
-- A paved plot underneath a building is occupied, not an open road.
-- One or more orthogonal open road neighbours grants one bonus, never per side.
function H.RoadAccess(h,x,y,chapter)
    local size=H.Size(chapter)
    for _,offset in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local nx,ny=x+offset[1],y+offset[2]
        if nx>=1 and ny>=1 and nx<=size and ny<=size and H.Ground(nx,ny,size)=="hub_walkway" and not H.At(h,nx,ny) then return true end
    end
    return false
end
function H.Effects(h,chapter,supply)
    local r={abilities={},pairs={},districts={},membership={},income={},roadAccess={}}
    for _,a in ipairs(K.abilities) do r.abilities[a.id]=0 end
    for _,b in ipairs(H.All(h)) do if b.remainingPeriods==0 then
        local bonus=(h.blueprints and h.blueprints[b.type]) and K.blueprintBonus or 0
        bonus=bonus+math.min(K.supplyLimit,(supply or {})[b.type] or 0)*K.supplyPerProperty
        add(r.abilities,K.byId[b.type].abilities,(1+(b.level-1)*K.levelAbilityStep)*(1+bonus))
    end end
    for _,b in ipairs(h.buildings) do
        if b.remainingPeriods==0 and H.RoadAccess(h,b.x,b.y,chapter) then
            r.roadAccess[b.id]=true; r.income[b.id]=K.roadIncome
        end
    end
    local active={}
    for _,b in ipairs(h.buildings) do if b.remainingPeriods==0 then active[#active+1]=b end end
    table.sort(active,function(a,b) return a.id<b.id end)
    local function adjacent(a,b) return math.abs(a.x-b.x)+math.abs(a.y-b.y)==1 end
    for i,a in ipairs(active) do for j=i+1,#active do local b=active[j]
        if adjacent(a,b) then for _,rule in ipairs(K.adjacency) do
            if (a.type==rule.a and b.type==rule.b) or (a.type==rule.b and b.type==rule.a) then
                add(r.abilities,rule.abilities)
                r.pairs[#r.pairs+1]={a=a.id,b=b.id,name=rule.name}
                r.income[a.id]=(r.income[a.id] or 0)+K.adjacencyIncome
                r.income[b.id]=(r.income[b.id] or 0)+K.adjacencyIncome
            end
        end end
    end end
    if (chapter or 3)>=K.districtChapter then
        -- Rule order is priority; each facility belongs to at most one district.
        for _,rule in ipairs(K.districts) do
            if #r.districts<K.maximumDistricts then
                local visited={}
                for _,seed in ipairs(active) do
                    if not visited[seed.id] and not r.membership[seed.id] and rule.needs[seed.type] then
                        local group,counts={seed},{}; visited[seed.id]=true; local pos=1
                        while pos<=#group do local a=group[pos]; pos=pos+1; counts[a.type]=(counts[a.type] or 0)+1
                            for _,b in ipairs(active) do
                                if not visited[b.id] and not r.membership[b.id] and rule.needs[b.type] and adjacent(a,b) then
                                    visited[b.id]=true; group[#group+1]=b
                                end
                            end
                        end
                        local valid=true; for id,n in pairs(rule.needs) do if (counts[id] or 0)<n then valid=false end end
                        if valid then
                            r.districts[#r.districts+1]=rule; add(r.abilities,rule.abilities)
                            for _,b in ipairs(group) do r.membership[b.id]=rule; r.income[b.id]=(r.income[b.id] or 0)+rule.income end
                            break -- One effective district of each type.
                        end
                    end
                end
            end
        end
    end
    local operating=H.Operating(h)
    for k,v in pairs(r.abilities) do
        r.abilities[k]=math.floor(v*(operating.policy.abilities[k] or 1)*(operating.event and operating.event.abilities and operating.event.abilities[k] or 1)+.5)
    end
    for k,v in pairs(r.income) do r.income[k]=math.min(K.maximumLayoutIncome,v) end
    return r
end
function H.Abilities(h,chapter) return H.Effects(h,chapter).abilities end
function H.BattleProfile(h,chapter,supply,style,important,defense)
    local r={enabled=false,pressure=1,value=1,idle=1,enemyWait=1,playerWait=1,resistance=0,enemyTactic=1,coverage={}}
    if (chapter or 1)<K.minChapter then return r end
    r.enabled=true; r.barrier=important and not defense; r.defense=defense
    r.abilities=H.Effects(h,chapter,supply).abilities
    local config=K.battle; local threshold=config.threshold[math.min(5,chapter)]
    local specialty=config.styles[style] or "influence"
    r.specialty=specialty
    for _,a in ipairs(K.abilities) do
        local need=threshold*(a.id==specialty and config.specialist or 1)
        r.coverage[a.id]=r.abilities[a.id]/(r.abilities[a.id]+need)
    end
    local c=r.coverage
    -- Stance relief uses the plain threshold (no specialist premium): every stance has a fixed
    -- answering ability regardless of who the opponent is.
    r.stanceRelief={}
    for sid,ability in pairs(K.stanceAbility) do
        local have=r.abilities[ability] or 0
        r.stanceRelief[sid]=K.stanceReliefMax*have/(have+threshold)
    end
    r.pressure=(1+config.pressureBonus*c.capital)/(1+(r.barrier and config.pressurePenalty*(1-c.capital) or 0))
    r.value=1+(r.barrier and config.valuePenalty*(1-c.influence) or 0)
    r.idle=1-config.idleRelief*c.commerce
    r.resistance=config.resistanceRelief*c.information
    if defense then
        r.playerWait=1-config.playerWaitRelief*c.logistics
        r.enemyTactic=1-config.resistanceRelief*c.information
    else r.enemyWait=1+config.enemyWaitBonus*c.logistics end
    return r
end
function H.Find(h,id)
    for _,b in ipairs(h.buildings) do if b.id==id then return b end end
end
local function busy(h)
    local n=0; for _,b in ipairs(H.All(h)) do if b.remainingPeriods>0 then n=n+1 end end; return n
end
function H.Quote(h,context,operation,id,x,y)
    if context.chapter<K.minChapter then return nil,"交易拠点は第3章から解禁されます" end
    local b=H.Find(h,id); if not b then return nil,"対象施設が見つかりません" end
    if operation=="demolish" then
        return {cost=0,refund=math.floor(b.paidCost*(b.remainingPeriods>0 and K.cancelRefund or K.demolitionRefund)),periods=0}
    end
    if b.remainingPeriods>0 then return nil,"工事中の施設は変更できません" end
    if busy(h)>=K.constructionSlots then return nil,"工事枠が満員です" end
    local cost,periods
    if operation=="upgrade" then
        if b.level>=K.maxLevel then return nil,"施設レベルは上限です" end
        cost=math.floor(b.paidCost*K.upgradeShare); periods=K.upgradePeriods
        if b.paidCost+cost>K.maximumCost then return nil,"投資額が上限に達しています" end
    elseif operation=="move" then
        if not integer(x,1,H.Size(context.chapter)) or not integer(y,1,H.Size(context.chapter)) or H.At(h,x,y) then return nil,"空き区画を選んでください" end
        cost=math.floor(b.paidCost*K.moveShare); periods=K.movePeriods
    else return nil,"不明な施設操作です" end
    if not finite(context.cash) or context.cash<cost then return nil,"商会資金が不足しています" end
    return {cost=cost,refund=0,periods=periods}
end
function H.Change(h,context,operation,id,x,y)
    local q,why=H.Quote(h,context,operation,id,x,y); if not q then return false,why end
    local b=H.Find(h,id)
    if operation=="demolish" then
        for i,v in ipairs(h.buildings) do if v.id==id then table.remove(h.buildings,i); break end end
    elseif operation=="upgrade" then
        b.paidCost=b.paidCost+q.cost; b.targetLevel=b.level+1; b.remainingPeriods=q.periods
    else
        b.x,b.y=x,y; b.remainingPeriods=q.periods -- Moving is a sunk expense, never refundable investment.
    end
    return true,q
end
function H.Cost(id,average)
    local f=K.byId[id]; if not f then return nil end
    average=finite(average) and math.max(0,average) or 0
    return math.min(K.maximumCost,math.floor(math.max(K.minimumCost,average*K.costShare)*f.cost))
end
function H.Build(h,context,id,x,y)
    local f=K.byId[id]
    if context.chapter<K.minChapter then return false,"交易拠点は第3章から解禁されます" end
    if not f or not integer(x,1,H.Size(context.chapter)) or not integer(y,1,H.Size(context.chapter)) then return false,"建設位置または施設が不正です" end
    if context.chapter<(f.minChapter or K.minChapter) then return false,"この施設は第"..f.minChapter.."章で解禁されます" end
    if H.At(h,x,y) then return false,"この区画には既に施設があります" end
    if #H.All(h)>=H.Capacity(context.chapter) then
        return false,"施設数が上限（"..H.Capacity(context.chapter).."棟）です。撤去して入れ替えてください"
    end
    if busy(h)>=K.constructionSlots then return false,"工事枠が満員です。決算で工事が進みます" end
    local cost=H.Cost(id,context.average)
    if not finite(context.cash) or context.cash<cost then return false,"商会資金が不足しています" end
    h.buildings[#h.buildings+1]={id=h.nextBuildingId,type=id,x=x,y=y,level=1,paidCost=cost,remainingPeriods=f.periods}
    h.nextBuildingId=h.nextBuildingId+1
    return true,cost
end
function H.Settle(h,cycle,chapter)
    local r={gross=0,upkeep=0,net=0,completed={},districts={}}
    if cycle<=h.lastSettledCycle then return r end
    h.lastSettledCycle=cycle
    if chapter<K.minChapter then return r end
    if h.pendingPolicy then h.policy=h.pendingPolicy; h.pendingPolicy=nil; r.policy=K.policyById[h.policy].name end
    local operating=H.Operating(h)
    local effects=H.Effects(h,chapter) -- Snapshot before completion: newly opened facilities earn next period.
    for _,b in ipairs(H.All(h)) do
        if b.remainingPeriods>0 then
            b.remainingPeriods=b.remainingPeriods-1
            if b.remainingPeriods==0 then
                b.level=b.targetLevel or b.level; b.targetLevel=nil
                r.completed[#r.completed+1]=K.byId[b.type].name
            end
        else
            r.gross=r.gross+math.floor(b.paidCost*K.incomeShare*(K.byId[b.type].income or 1)*(1+(effects.income[b.id] or 0))*operating.income)
            r.upkeep=r.upkeep+math.floor(b.paidCost*K.upkeepShare*(K.byId[b.type].upkeep or 1)*operating.upkeep)
            h.growth=h.growth+K.growthPerBuilding
        end
    end
    if #r.completed>0 then
        local before={}; for _,d in ipairs(effects.districts) do before[d.id]=true end
        for _,d in ipairs(H.Effects(h,chapter).districts) do if not before[d.id] then r.districts[#r.districts+1]=d.name end end
    end
    r.event=H.EventStep(h,cycle,#H.All(h)>0)
    r.net=r.gross-r.upkeep
    return r
end
return H
