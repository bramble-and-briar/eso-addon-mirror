-- Pure Lua: no ESO calls, no wall clock. Inject RNG for repeatable tests.
local E = {}; E.__index=E; PBTrade.Engine=E
local C, M, D = PBTrade.Config, PBTrade.Model, PBTrade.Data
local B = C.battle
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local profiles={
    steady={opening=1,budget=1,bid=1,wait=1,react=.20}, wealth={opening=1.15,budget=1.35,bid=1.25,wait=1.12,react=.18},
    aggressive={opening=1.30,budget=1.05,bid=1.08,wait=.72,react=.42}, information={opening=.85,budget=1.0,bid=.88,wait=.92,react=.72},
    subversion={opening=1.0,budget=1.12,bid=.96,wait=.82,react=.58}, dominion={opening=1.35,budget=1.55,bid=1.30,wait=.68,react=.85},
}
function E.New(state, rng)
    return setmetatable({state=state, random=rng or math.random, accumulator=0},E)
end
function E:Log(message)
    local log=self.battle.log; log[#log+1]=message
    while #log>B.logLimit do table.remove(log,1) end
end
function E:Start(id, attacker)
    if self.battle and not self.battle.result then return false,"買収交渉が進行中です" end
    local p=self.state.properties[id]
    if not p then return false,"物件が見つかりません" end
    if not M.IsAvailable(self.state,p) then return false,"この章では交易路が存在しません" end
    if not self.state.unlocked[p.zone] then return false,"まだ交易路が開いていません" end
    if not attacker and not M.IsPropertyVisited(self.state,p) then return false,"ESO内の現地で物件登録すると買収できます" end
    if attacker then
        if p.owner~=C.playerId then return false,"防衛できる自社物件ではありません" end
        if attacker==C.playerId or attacker==C.neutralId or not self.state.companies[attacker] then return false,"攻撃商会が不正です" end
    elseif p.owner==C.playerId then return false,"すでに自社所有です" end
    local opponent=attacker or p.owner
    local company=self.state.companies[opponent]; local profile=profiles[(company and company.personality) or "steady"] or profiles.steady
    local defense=attacker and ((company and company.defense) or .5) or 0
    local assault=attacker and (C.counterattack.chapter[self.state.chapter] or C.counterattack.chapter[#C.counterattack.chapter]) or nil
    -- A rival's headquarters is fought for with the whole group behind it.
    local value,headquarters=M.NegotiationValue(self.state,p,attacker)
    local groupReserve=0
    -- A hostile acquisition can mobilize reserves from the attacker's whole portfolio, just as
    -- the player can call several owned properties during the defense.  Headquarters retain the
    -- same group-reserve rule when the player is the attacker.
    if headquarters or attacker then local _,reserves=M.CompanyAssets(self.state,opponent); groupReserve=reserves end
    local opening=math.floor(value*B.openingEnemyBidFactor*profile.opening*(1+defense*.25))
    local budget=math.floor(value*B.enemyBudgetFactor*profile.budget*(1+defense*.20))
    if assault then
        opening=math.floor(opening*assault.opening)
        budget=math.floor(budget*assault.budget)
    end
    local policy,event=M.ActivePolicy(self.state),M.ActiveMarketEvent(self.state)
    local stanceIds=M.NegotiationStances(self.state,p,attacker)
    local budgetMultiplier=(policy and policy.enemyBudgetMultiplier or 1)*(event and event.enemyBudgetMultiplier or 1)
    for _,sid in ipairs(stanceIds) do budgetMultiplier=budgetMultiplier*(D.stanceById[sid].enemyBudget or 1) end
    budget=math.floor(budget*budgetMultiplier)
    if opponent~=C.neutralId then
        local company=self.state.companies[opponent]
        local available=company.cash+groupReserve
        opening=math.min(opening,available)
        budget=math.min(budget,available-opening)
        local fromCash=math.min(company.cash,opening); company.cash=company.cash-fromCash
        groupReserve=groupReserve-(opening-fromCash)
    end
    local hub=M.HubProfile(self.state,p,attacker)
    self.accumulator=0
    self.battle={hub=hub,targetId=id, defender=opponent, mode=attacker and "defense" or "acquisition", gauge=B.initialGauge, velocity=0, acceleration=0,
        playerWait=0, enemyWait=B.enemyOpeningWait, elapsed=0, playerBid=0, stanceDiscount=0,
        enemyBid=opening, enemyBudget=budget,
        momentum=0, requests={}, log={}, treasurySpent=0, baseValue=value,effectiveValue=value*hub.value,
        headquarters=headquarters, critical=M.IsCriticalProperty(self.state,p), finalStronghold=p.finalStronghold==true,
        criticalStage=0, groupReserve=groupReserve, groupReserveStart=groupReserve+0,
        assault=assault,assaultAcceleration=assault and assault.acceleration or 0,
        enemyGroups=company and opponent~=C.neutralId and M.CompanyGroups(self.state,opponent) or {},
        enemyGroupsUsed={},enemyGroupUses=0,
        effects={},delayedEffects={},learnedTactics={},day=1,turns=0,events={}}
    self.battle.aiProfile=profile; self.battle.aiStyle=(company and company.personality) or "steady"
    local hits=self.battle.critical and not attacker and C.stances.criticalHits or 1
    local stances={}
    for _,sid in ipairs(stanceIds) do
        -- The hub eases a stance for the whole negotiation; fixed at the start like every hub bonus.
        stances[#stances+1]={id=sid,hits=hits,broken=false,relief=hub.stanceRelief and hub.stanceRelief[sid] or 0}
    end
    self.battle.stances=stances
    self:Log(attacker and "防衛開始。境目を左端まで押せば防衛成功、右端で物件喪失。" or "交渉開始。境目を左端まで押せば買収成立。")
    if hub.enabled then self:Log(M.HubSummary(self.state,p,attacker)) end
    if headquarters then
        self:Log(company.name.."が総力で本社を守る（交渉価値 "..M.FormatMoney(value).."）")
        self:Notify("enemy","グループの総力で本社を防衛（交渉価値 "..M.FormatMoney(value).."）","alert")
    end
    if self.battle.critical then
        self:Log("重要交渉：相手は三段階の防衛契約を準備している")
        self:Notify("wide","重要交渉――防衛契約が段階的に発動する","alert")
    end
    if assault then
        self:Log("敵攻勢："..assault.label.."（第"..self.state.chapter.."章）")
        self:Notify("enemy","敵攻勢「"..assault.label.."」――投入速度と予算が強化","alert","negative")
    end
    for _,stance in ipairs(stances) do
        local st=D.stanceById[stance.id]
        self:Log("構え「"..st.name.."」："..st.hint)
        self:Notify("enemy","構え「"..st.name.."」――"..st.hint,"stance")
    end
    self:Notify("wide",self:DaySummary(),"day")
    -- A negotiator hired in domestic affairs joins this negotiation (attack or defense).
    if (self.state.envoyBattles or 0)>0 then
        self.state.envoyBattles=self.state.envoyBattles-1
        local K=C.admin
        self.battle.momentum=math.min(B.maxMomentum,self.battle.momentum+K.hireMomentum)
        self:AddEffect("playerWaitMultiplier",K.hireWaitFactor,K.hireSeconds)
        self:Log("腕利きの交渉役が同席している"); self:Notify("player","腕利きの交渉役が同席している","tactic")
    end
    return true
end
local function comma(n)
    return M.FormatMoney(n)
end
-- Battle popups: lane is "enemy" (above the rival's coins), "player" (above ours) or "wide".
-- Side-lane events also carry their meaning for the player.  The UI uses this rather than
-- the physical lane to distinguish encouraging and adverse status sounds.
function E:Notify(lane,text,kind,sentiment)
    local events=self.battle.events
    if not sentiment and lane=="player" then sentiment=kind=="alert" and "negative" or "positive"
    elseif not sentiment and lane=="enemy" then sentiment="negative" end
    if #events<400 then events[#events+1]={lane=lane,text=text,kind=kind,sentiment=sentiment} end
end
function E:DaySummary()
    local b=self.battle
    return "― 交渉"..b.day.."日目 ―    相手  拠出 "..comma(b.enemyBid).." / 残予算 "..comma(b.enemyBudget)
        .."    ｜    自社  拠出 "..comma(b.playerBid).." / 商会資金 "..comma(self.state.cash)
end
-- A day passes after turnsPerDay executed commands or daySeconds of negotiation, whichever first.
function E:NextDay()
    local b=self.battle
    b.day=b.day+1; b.dayTurns=0; b.dayTime=0
    local K=C.criticalBattle
    local nextStage=(b.criticalStage or 0)+1
    if b.critical and K.days[nextStage] and b.day>=K.days[nextStage] then
        local company=b.defender~=C.neutralId and self.state.companies[b.defender] or nil
        local multiplier=b.finalStronghold and K.finalStrongholdMultiplier or 1
        local wanted=math.floor(b.baseValue*K.reinforcementShares[nextStage]*multiplier)
        local available=company and (company.cash+(b.groupReserve or 0)) or 0
        local amount=math.min(wanted,available)
        if company and amount>0 then
            local fromCash=math.min(company.cash,amount); company.cash=company.cash-fromCash
            if amount>fromCash then b.groupReserve=math.max(0,(b.groupReserve or 0)-(amount-fromCash)) end
            b.enemyBid=b.enemyBid+amount; b.lastEnemyAction=b.elapsed
        end
        b.criticalStage=nextStage
        self:AddEffect("enemyAccelerationBoost",K.acceleration[nextStage]*multiplier,K.effectSeconds)
        local name=K.names[nextStage]
        self:Log(name.."  +"..comma(amount))
        self:Notify("enemy",name.."　追加出資 +"..comma(amount),"alert")
    end
    self:Notify("wide",self:DaySummary(),"day")
end
function E:PlayerTurn()
    local b=self.battle
    b.turns=b.turns+1; b.dayTurns=(b.dayTurns or 0)+1
    if b.dayTurns>=B.turnsPerDay then self:NextDay() end
end
function E:AddEffect(kind,amount,duration)
    local effects=self.battle.effects
    effects[#effects+1]={type=kind,amount=amount,remaining=duration}
    while #effects>C.tactics.effectLimit do table.remove(effects,1) end
end
-- How much of a contribution from `source` (request/group/ally/treasury) moves the border.
function E:FundWeight(source)
    local weight=1
    for _,stance in ipairs(self.battle.stances or {}) do
        if not stance.broken then
            local w=D.stanceById[stance.id].weights[source] or 1
            weight=weight*(w+(1-w)*(stance.relief or 0))
        end
    end
    return weight
end
-- While a stance stands, money can only press so hard: piling more gold hits a ceiling.
function E:PressureCap()
    local standing,relief=0,0 -- counted in place: this runs every simulation step
    for _,stance in ipairs(self.battle.stances or {}) do if not stance.broken then standing=standing+1; relief=relief+(stance.relief or 0) end end
    if standing==0 then return 1 end
    -- Critical targets hold a little tighter; a second stance tightens the ceiling further.
    local K=C.stances
    return K.pressureCap*(1+relief/standing)*(self.battle.critical and K.criticalCapShare or 1)/(1+K.extraStanceTighten*(standing-1))
end
-- Contribution that actually pushes the border: the bid minus what standing stances absorbed.
function E:PlayerForce()
    local b=self.battle; return (b.playerBid-(b.stanceDiscount or 0))*(b.hub and b.hub.pressure or 1)
end
function E:EnemyWaitFactor()
    local factor=1
    for _,stance in ipairs(self.battle.stances or {}) do
        if not stance.broken then
            local f=D.stanceById[stance.id].enemyWait or 1
            factor=factor*(1+(f-1)*(1-(stance.relief or 0)))
        end
    end
    return factor
end
function E:StandingStances()
    local list={}
    for _,stance in ipairs(self.battle and self.battle.stances or {}) do if not stance.broken then list[#list+1]=stance end end
    return list
end
-- A counter lands on every standing stance it answers. Returns the stances it broke.
-- Breaking releases everything contributed so far at full weight and swings the border.
function E:HitStances(test)
    local b=self.battle; local broken={}; local shaken
    for _,stance in ipairs(b.stances or {}) do
        local st=D.stanceById[stance.id]
        if not stance.broken and test(st) then
            stance.hits=stance.hits-1
            if stance.hits<=0 then stance.broken=true; broken[#broken+1]=st
            else shaken=st; self:Log("構え「"..st.name.."」が揺らいだ（あと"..stance.hits.."手）")
                self:Notify("enemy","構え「"..st.name.."」が揺らいだ！ あと"..stance.hits.."手","stance","positive") end
        end
    end
    if #broken>0 then
        b.stanceDiscount=0
        b.velocity=clamp(b.velocity-C.stances.breakVelocity*#broken,-B.maxVelocity,B.maxVelocity)
        for _,st in ipairs(broken) do
            self:Log("構え「"..st.name.."」を崩した！ 出資が満額で効き始める")
            self:Notify("wide","構え「"..st.name.."」を崩した！――積んだ出資が満額で効き始める","stanceBreak")
        end
    end
    return broken,shaken
end
function E:EffectTotal(kind,default)
    local value=default or 0
    for _,effect in ipairs(self.battle.effects) do
        if effect.type==kind then
            if kind=="playerWaitMultiplier" or kind=="valueMultiplier" then value=value*effect.amount else value=value+effect.amount end
        end
    end
    return value
end
function E:PlayerWaitDuration() return B.playerWait*self:EffectTotal("playerWaitMultiplier",1)*(self.battle.hub and self.battle.hub.playerWait or 1) end
function E:TacticResistance(tactic,target)
    local base=clamp(target and target.negotiationResistances and (target.negotiationResistances[tactic.resistanceKey] or 0) or 0,0,1)
    -- True immunities stay immune; assistance applies only against opposing properties.
    if base<1 and target and target.owner~=C.playerId and self.battle and self.battle.hub then
        base=math.max(0,base-self.battle.hub.resistance)
    end
    return base
end
function E:UseTactic(id)
    if not self:Ready() then return false,"伝令の帰還を待ってください" end
    local tactic=D.tacticById[id]
    if not tactic or not self.state.learnedTactics[id] then return false,"まだ習得していない駆け引きです" end
    if self.state.cash<tactic.cost then return false,"商会資金が不足しています" end
    local effect=tactic.effect; local target=self.state.properties[self.battle.targetId]
    local ownTarget
    if effect.type=="ownRisk" then
        for _,p in ipairs(M.Owned(self.state)) do if not ownTarget or p.independenceRisk>ownTarget.independenceRisk then ownTarget=p end end
        if not ownTarget then return false,"対象となる自社物件がありません" end
    elseif effect.type=="enemyRisk" and target.owner==C.neutralId then return false,"中立物件には離反工作が効きません" end
    self.state.cash=self.state.cash-tactic.cost; self.battle.treasurySpent=self.battle.treasurySpent+tactic.cost
    self.battle.lastPlayerAction=self.battle.elapsed
    local resistance=self:TacticResistance(tactic,effect.type=="ownRisk" and ownTarget or target)
    local power=1-resistance; local amount=(effect.amount or 0)*power
    local direction,defected
    if power<=0 then self:Log(tactic.name.."は無効でした")
    elseif effect.type=="playerAcceleration" or effect.type=="enemyAccelerationPenalty" then self:AddEffect(effect.type,amount,effect.duration)
    elseif effect.type=="velocity" then self.battle.velocity=clamp(self.battle.velocity+amount,-B.maxVelocity,B.maxVelocity)
    elseif effect.type=="randomVelocity" then
        direction=self.random()<.55 and -1 or 1; self.battle.velocity=clamp(self.battle.velocity+direction*amount,-B.maxVelocity,B.maxVelocity)
    elseif effect.type=="playerWaitMultiplier" then self:AddEffect(effect.type,math.max(.1,1-(1-effect.amount)*power),effect.duration)
    elseif effect.type=="enemyWait" then self.battle.enemyWait=self.battle.enemyWait+amount
    elseif effect.type=="delayedAcceleration" then self.battle.delayedEffects[#self.battle.delayedEffects+1]={remaining=effect.delay,type="playerAcceleration",amount=amount,duration=effect.duration}
    elseif effect.type=="resetWaits" then self.battle.playerWait=B.playerWait; self.battle.enemyWait=B.enemyOpeningWait
    elseif effect.type=="valueMultiplier" then self:AddEffect(effect.type,1+(effect.amount-1)*power,effect.duration)
    elseif effect.type=="enemyRisk" then target.independenceRisk=clamp(target.independenceRisk+amount,0,B.riskMax-1); defected=self:CheckDefection(target)
    elseif effect.type=="ownRisk" then ownTarget.independenceRisk=clamp(ownTarget.independenceRisk+amount,0,B.riskMax-1) end
    if power>0 then self:Log(tactic.name.."を実行") end
    local brokenStances,shaken={},nil
    if power>0 then brokenStances,shaken=self:HitStances(function(st) return st.breakers and st.breakers[id] end) end
    self:PlayerTurn()
    if effect.type~="resetWaits" then self.battle.playerWait=self:PlayerWaitDuration() end
    -- The outcome feeds the tactic cut-in: power, applied amount and any swing or defection.
    return true,{tactic=tactic,resistance=resistance,target=ownTarget or target,
        power=math.max(0,power),amount=amount,direction=direction,targetDefected=defected,
        brokenStances=brokenStances,shakenStance=shaken}
end
function E:TryLearnTactics(result)
    local learned={}; local defense=self.battle.mode=="defense"
    for _,tactic in ipairs(D.tactics) do
        local rule=tactic.learn
        if not self.state.learnedTactics[tactic.id] and not rule.starting then
            local eligible=(not rule.result or rule.result==result or (rule.result=="lost" and result~="won"))
                and (not rule.defense or defense) and (not rule.category or M.HasOwnedCategory(self.state,rule.category))
            if eligible and self.random()<(rule.chance or 0) then
                self.state.learnedTactics[tactic.id]=true; learned[#learned+1]=tactic.id
                self:Log(tactic.name.."を習得した！")
            end
        end
    end
    self.battle.learnedTactics=learned
end
function E:DefectionChance(p)
    return clamp((p.independenceRisk-C.independence.safeThreshold)*C.independence.chancePerPoint,0,C.independence.maxChance)
end
function E:CheckDefection(p)
    local chance=self:DefectionChance(p)
    if chance>0 and self.random()<chance then
        p.owner=C.neutralId; p.independenceRisk=B.riskMax
        self:Log(p.name.."が離反しました")
        return true
    end
    return false
end
function E:DiscoverGroup(p)
    local found={}
    for _,id in ipairs(p.groups) do
        local group=PBTrade.Data.groups[id]
        local count=group and #M.GroupMembers(self.state,id) or 0
        -- A flash must be immediately usable.  The requested property is a member because we
        -- only inspect p.groups; require at least two current members and the group's own,
        -- possibly stricter, activation threshold before rolling the discovery chance.
        local required=group and math.max(2,group.minimum or 2,group.discoverAt or 0) or math.huge
        if group and count>=required and not self.state.learnedGroups[id] and self.random()<(group.discoveryChance or 0) then
            self.state.learnedGroups[id]=true; found[#found+1]=id
            self:Log(group.name.."を閃いた！")
            if #found>=C.groups.maxDiscoveriesPerRequest then break end
        end
    end
    return found
end
function E:Ready()
    return self.battle and not self.battle.result and self.battle.playerWait<=0
end
function E:Quote(id)
    local p=self.state.properties[id]
    if not p or p.owner~=C.playerId then return 0 end
    local count=self.battle and self.battle.requests[id] or 0
    local base=p.expectedProfit*B.fundingProfitFactor+p.marketValue*B.fundingValueFactor
    return math.floor(math.min(p.reserve,base/(1+(count or 0)*B.fatiguePerRequest)))
end
function E:Fund(amount, acceleration, source)
    local b=self.battle
    b.lastPlayerAction=b.elapsed
    b.playerBid=b.playerBid+amount
    local weight=self:FundWeight(source or "treasury")
    b.stanceDiscount=(b.stanceDiscount or 0)+amount*(1-weight)
    b.momentum=clamp(b.momentum+acceleration*B.momentumPerFunding*math.min(1,weight),0,B.maxMomentum)
    b.playerWait=self:PlayerWaitDuration()
end
function E:Request(id)
    if not self:Ready() then return false,"伝令の帰還を待ってください" end
    local amount=self:Quote(id)
    if amount<=0 then return false,"調達できる手元資金がありません" end
    local p=self.state.properties[id]
    local discoveries=self:DiscoverGroup(p)
    if #discoveries>0 then
        -- The flash replaces the single request: the newly learned group fires at once, so the
        -- triggering property is not charged twice and only one player turn is consumed.
        local status=M.GroupStatus(self.state,discoveries[1])
        self:Notify("player","閃き：「"..status.name.."」","discovery")
        return self:FundGroup(status,discoveries)
    end
    p.reserve=p.reserve-amount
    p.independenceRisk=clamp(p.independenceRisk+p.independenceIncrease,0,B.riskMax-1)
    self.battle.requests[id]=(self.battle.requests[id] or 0)+1
    self:Fund(amount,p.gaugeAcceleration,"request")
    self:Log(p.name.."  +"..comma(amount).." / 負担 "..p.independenceRisk)
    self:Notify("player",p.name.."から  +"..comma(amount),"fund")
    local defected=self:CheckDefection(p)
    if defected then self:Notify("player",p.name.."が離反した！","alert") end
    self:PlayerTurn()
    return true,amount,{discoveries=discoveries,defected=defected,property=p}
end
function E:FundGroup(status,discoveries)
    local base,acceleration,paid,defected=0,0,0,{}
    for _,p in ipairs(status.members) do
        local amount=self:Quote(p.id)
        if amount>0 then
            p.reserve=p.reserve-amount; p.independenceRisk=clamp(p.independenceRisk+p.independenceIncrease,0,B.riskMax-1)
            self.battle.requests[p.id]=(self.battle.requests[p.id] or 0)+1
            base=base+amount; acceleration=acceleration+p.gaugeAcceleration; paid=paid+1
            if self:CheckDefection(p) then defected[#defected+1]=p end
        end
    end
    if paid==0 then return false,"系列に調達余力がありません" end
    local amount=math.floor(base*status.bonus)
    self:Fund(amount,acceleration/paid+C.groups.accelerationBonus,"group")
    local broken=self:HitStances(function(st) return st.breakByGroup end)
    self:Log(status.name.."  +"..comma(amount).."（"..paid.."件）")
    self:Notify("player",status.name.."  +"..comma(amount).."（"..paid.."件）","fund")
    for _,p in ipairs(defected) do self:Notify("player",p.name.."が離反した！","alert") end
    self:PlayerTurn()
    return true,amount,{group=status,discoveries=discoveries or {},defected=defected,brokenStances=broken}
end
function E:RequestGroup(id)
    if not self:Ready() then return false,"伝令の帰還を待ってください" end
    local status=M.GroupStatus(self.state,id)
    if not status or not status.learned then return false,"まだこの連合を閃いていません" end
    if not status.usable then return false,"系列物件が不足しています" end
    return self:FundGroup(status)
end
-- Ask an allied company to back this negotiation (once per ally per negotiation).
function E:RequestAlly(id)
    if not self:Ready() then return false,"伝令の帰還を待ってください" end
    local b=self.battle; b.allyRequests=b.allyRequests or {}
    if not M.IsAllied(self.state,id) then return false,"同盟を結んでいない商会です" end
    if b.allyRequests[id] then return false,"この交渉ではすでに支援を受けています" end
    if b.defender==id then return false,"交渉相手の同盟商会には頼めません" end
    local amount=M.AllianceFundAmount(self.state,id); if amount<=0 then return false,"同盟商会に余裕資金がありません" end
    local c=self.state.companies[id]; c.cash=c.cash-amount; b.allyRequests[id]=true
    local broken=M.StrainAlliance(self.state,id,C.alliance.fundTrust)
    self:Fund(amount,B.baseAcceleration+.5,"ally")
    local brokenStances=self:HitStances(function(st) return st.breakByAlly end)
    self:Log(c.name.."の支援  +"..comma(amount)); self:Notify("player","同盟 "..c.name.."の支援  +"..comma(amount),"fund")
    if broken then self:Log(c.name.."との同盟が解消された"); self:Notify("player",c.name.."との同盟が解消された！","alert") end
    self:PlayerTurn()
    return true,amount,{ally=id,broken=broken,brokenStances=brokenStances}
end
function E:Stabilize()
    if not self:Ready() then return false,"伝令の帰還を待ってください" end
    if self.state.cash<C.independence.stabilizeCost then return false,"商会資金が不足しています" end
    local target
    for _,p in ipairs(M.Owned(self.state)) do if not target or p.independenceRisk>target.independenceRisk then target=p end end
    if not target or target.independenceRisk<=0 then return false,"根回しが必要な物件はありません" end
    self.state.cash=self.state.cash-C.independence.stabilizeCost
    self.battle.lastPlayerAction=self.battle.elapsed
    target.independenceRisk=math.max(0,target.independenceRisk-C.independence.stabilizeAmount)
    self.battle.treasurySpent=self.battle.treasurySpent+C.independence.stabilizeCost
    self.battle.playerWait=B.playerWait; self:Log(target.name.."を安定化  -"..C.independence.stabilizeAmount)
    self:Notify("player",target.name.."を根回しで安定化","fund")
    self:PlayerTurn()
    return true,target
end
function E:Treasury(amount)
    if not self:Ready() then return false,"伝令の帰還を待ってください" end
    -- Amounts come from the gap-based menu; any whole positive amount the treasury holds is valid.
    if type(amount)~="number" or amount~=amount or amount<=0 or amount==math.huge or amount~=math.floor(amount) then
        return false,"投入額が不正です" end
    if self.state.cash<amount then return false,"商会資金が不足しています" end
    self.state.cash=self.state.cash-amount
    self.battle.treasurySpent=self.battle.treasurySpent+amount
    self:Fund(amount,B.baseAcceleration,"treasury")
    self:Log("商会資金を投入  +"..comma(amount))
    self:Notify("player","商会資金を投入  +"..comma(amount),"fund")
    self:PlayerTurn()
    return true
end
function E:Finish(result)
    local b=self.battle
    if not b or b.result then return end
    b.result=result
    -- Reserves the group spent defending its headquarters come out of its properties, pro rata.
    local spent=(b.groupReserveStart or 0)-(b.groupReserve or 0)
    if (b.headquarters or b.mode=="defense") and spent>0 then
        local _,total=M.CompanyAssets(self.state,b.defender)
        if total>0 then
            for _,p in pairs(self.state.properties) do
                if p.owner==b.defender and (p.reserve or 0)>0 then p.reserve=math.max(0,p.reserve-math.floor(spent*p.reserve/total+.5)) end
            end
        end
    end
    if result=="won" then
        if b.mode=="defense" then
            self.state.defensesWon=self.state.defensesWon+1; self:Log("防衛成功。所有権を維持しました。")
        else
            local acquired=self.state.properties[b.targetId]
            -- Buying an ally's property strains the alliance, and may break it.
            if M.IsAllied(self.state,acquired.owner) then
                b.allianceStrained=acquired.owner
                b.allianceBroken=M.StrainAlliance(self.state,acquired.owner,C.alliance.acquireTrust) and acquired.owner or nil
                if b.allianceBroken then self:Log(self.state.companies[acquired.owner].name.."との同盟が解消された") end
            end
            acquired.owner=C.playerId
            acquired.independenceRisk=math.min(acquired.independenceRisk,C.independence.reacquireRisk)
            self.state.wins=self.state.wins+1; M.Unlock(self.state)
            self:Log("買収成立。物件が商会に加わりました。")
            for _,definition in ipairs(D.properties) do
                local locked=self.state.properties[definition.id]
                if locked.finalStronghold and locked.owner~=C.playerId then
                    local wasKey=false
                    for _,id in ipairs(locked.requiresProperties or {}) do if id==b.targetId then wasKey=true end end
                    if wasKey and M.IsAvailable(self.state,locked) then
                        b.finalStrongholdUnlocked=locked
                        self:Log(locked.name.."への道が開いた！")
                        self:Notify("wide","最終物件出現：「"..locked.name.."」","discovery")
                    end
                end
            end
            b.takeover=M.Takeover(self.state,b.targetId)
            if b.takeover then self:Log(b.takeover.name.."を傘下に収めた！ 物件 "..b.takeover.count.." 件") end
        end
    else
        if b.mode=="defense" then
            self.state.properties[b.targetId].owner=b.defender
            self.state.defensesLost=self.state.defensesLost+1; self:Log("防衛不成立。物件の所有権を失いました。")
        else
            self.state.losses=self.state.losses+1
            self:Log(result=="withdrawn" and "交渉を撤回しました。" or "買収不成立。")
        end
    end
    self:TryLearnTactics(result)
    -- All committed capital is spent, including on withdrawal. No free retry loop.
    -- No income settlement yet: that belongs to the campaign phase.
end
function E:UseEnemyTactic(company)
    self.battle.lastEnemyAction=self.battle.elapsed
    local id=company and company.tacticBias; local tactic=id and D.tacticById[id]
    if not tactic then return end
    if id=="messenger" then self.battle.enemyWait=self.battle.enemyWait*.55
    elseif id=="rumor" then self:AddEffect("enemyAccelerationBoost",.75*(self.battle.hub and self.battle.hub.enemyTactic or 1),10)
    elseif id=="defection" then
        local target
        for _,p in ipairs(M.Owned(self.state)) do if not target or p.independenceRisk>target.independenceRisk then target=p end end
        if target then target.independenceRisk=clamp(target.independenceRisk+16*(self.battle.hub and self.battle.hub.enemyTactic or 1),0,B.riskMax-1); self:CheckDefection(target) end
    elseif id=="gift" then
        local extra=math.min(company.cash,math.floor(self.battle.baseValue*.015)); company.cash=company.cash-extra
        self.battle.enemyBid=self.battle.enemyBid+extra
    end
    self:Log("相手が「"..tactic.name.."」を使用")
    self:Notify("enemy","駆け引き「"..tactic.name.."」を仕掛けてきた","tactic")
end
-- COM group funding uses only groups its company currently owns in sufficient numbers.  It
-- consumes those members' real reserves and raises their independence risk, so a spectacular
-- defense can weaken the rival's long game or even cause a peripheral holding to defect.
function E:UseEnemyGroup(company)
    local b,K=self.battle,C.enemyGroups
    if not company or b.enemyBudget<=0 or b.enemyGroupUses>=K.maxUses[self.state.chapter] then return false end
    if b.enemyBid-self:PlayerForce()>b.baseValue*K.maximumEnemyLeadShare then return false end
    local best,bestRaw,bestOutput,bestContributions
    for _,group in ipairs(b.enemyGroups or {}) do
        if not b.enemyGroupsUsed[group.id] then
            local raw,contributions,ownedCount=0,{},0
            for _,p in ipairs(group.members) do
                if p.owner==b.defender then
                    ownedCount=ownedCount+1
                    if p.reserve>0 then
                        local quote=math.floor(math.min(p.reserve,p.expectedProfit*B.fundingProfitFactor+p.marketValue*B.fundingValueFactor)*K.contributionShare)
                        if quote>0 then raw=raw+quote; contributions[#contributions+1]={property=p,amount=quote} end
                    end
                end
            end
            local multiplier=1+(group.bonus-1)*K.bonusEffect
            local output=math.floor(raw*multiplier)
            if ownedCount>=(group.required or group.minimum or 2) and output>(bestOutput or 0) then
                best,bestRaw,bestOutput,bestContributions=group,raw,output,contributions
            end
        end
    end
    if not best or bestRaw<=0 then return false end
    local cap=math.floor(b.baseValue*K.capShare[self.state.chapter])
    local wanted=math.min(bestOutput,b.enemyBudget,cap)
    if wanted<=0 then return false end
    local scale=wanted/bestOutput; local rawSpent=math.max(1,math.floor(bestRaw*scale+.5))
    local remaining=rawSpent
    for i,row in ipairs(bestContributions) do
        local amount=i==#bestContributions and remaining or math.min(remaining,math.floor(row.amount*scale+.5))
        amount=math.min(amount,row.property.reserve); remaining=remaining-amount
        row.property.reserve=row.property.reserve-amount
        row.property.independenceRisk=clamp(row.property.independenceRisk+math.max(1,math.floor(row.property.independenceIncrease*K.riskFactor+.5)),0,B.riskMax-1)
        if row.property.id~=b.targetId then self:CheckDefection(row.property) end
    end
    rawSpent=rawSpent-math.max(0,remaining)
    local multiplier=1+(best.bonus-1)*K.bonusEffect
    local amount=math.min(wanted,math.floor(rawSpent*multiplier))
    if amount<=0 then return false end
    -- Direct member deductions must not also be removed by the aggregate reserve settlement.
    b.groupReserve=math.max(0,(b.groupReserve or 0)-rawSpent)
    b.groupReserveStart=math.max(0,(b.groupReserveStart or 0)-rawSpent)
    b.enemyBudget=math.max(0,b.enemyBudget-amount); b.enemyBid=b.enemyBid+amount
    b.enemyGroupsUsed[best.id]=true; b.enemyGroupUses=b.enemyGroupUses+1; b.lastEnemyAction=b.elapsed
    self:AddEffect("enemyAccelerationBoost",K.acceleration,K.effectSeconds)
    self:Log("敵グループ技「"..best.name.."」  +"..comma(amount).."（"..#bestContributions.."件）")
    self:Notify("enemy","グループ技「"..best.name.."」  +"..comma(amount),"group","negative")
    return true,{group=best,amount=amount,spent=rawSpent}
end
-- The side the border is moving toward is under attack. If it has not acted for a while,
-- the push against it keeps building so a one-sided negotiation ends quickly.
function E:IdlePressure()
    local b=self.battle
    if math.abs(b.velocity)<1e-6 then b.idleSide=nil; return 0 end
    local pressedPlayer=b.velocity>0 -- positive velocity heads for the player's loss
    local last=pressedPlayer and (b.lastPlayerAction or 0) or (b.lastEnemyAction or 0)
    local idle=b.elapsed-last-B.idleGrace
    if idle<=0 then b.idleSide=nil; return 0 end
    local side=pressedPlayer and "player" or "enemy"
    if b.idleSide~=side then
        b.idleSide=side
        self:Log(pressedPlayer and "自社の手が止まり、一気に押し込まれていく……" or "相手の手が止まった。流れが一気に傾く！")
        self:Notify(side,pressedPlayer and "手が止まり、一気に押し込まれている……" or "手が止まった。流れが一気に傾く！","alert",
            pressedPlayer and "negative" or "positive")
    end
    local push=B.idleAcceleration*math.min(1,idle/B.idleRamp)
    return pressedPlayer and push*(b.hub and b.hub.idle or 1) or -push
end
function E:Step(dt)
    local b=self.battle
    b.elapsed=b.elapsed+dt
    b.dayTime=(b.dayTime or 0)+dt
    if b.dayTime>=B.daySeconds then self:NextDay() end
    for i=#b.effects,1,-1 do local effect=b.effects[i]; effect.remaining=effect.remaining-dt; if effect.remaining<=0 then table.remove(b.effects,i) end end
    for i=#b.delayedEffects,1,-1 do
        local effect=b.delayedEffects[i]; effect.remaining=effect.remaining-dt
        if effect.remaining<=0 then self:AddEffect(effect.type,effect.amount,effect.duration); self:Log("宴席の働きかけが広がりました"); self:Notify("player","宴席の働きかけが広がった","tactic"); table.remove(b.delayedEffects,i) end
    end
    b.effectiveValue=b.baseValue*self:EffectTotal("valueMultiplier",1)*(b.hub and b.hub.value or 1)
    b.playerWait=math.max(0,b.playerWait-dt)
    b.enemyWait=math.max(0,b.enemyWait-dt)
    if b.enemyWait<=0 then
        local profile=b.aiProfile or profiles.steady
        local pressure=clamp((self:PlayerForce()-b.enemyBid)/math.max(B.priceFloor,b.effectiveValue),0,1)
        local company=b.defender~=C.neutralId and self.state.companies[b.defender] or nil
        local groupChance=C.enemyGroups.chance[self.state.chapter] or 0
        local usedGroup=company and self.random()<groupChance and self:UseEnemyGroup(company)
        local amount=0
        if not usedGroup then amount=math.min(b.enemyBudget,math.floor(b.effectiveValue*B.enemyBidFactor*profile.bid*
            (1+self.random()*B.enemyBidVariation+profile.react*pressure))) end
        if b.defender~=C.neutralId then
            -- Headquarters defence draws on the group's property reserves once cash runs out.
            amount=math.min(amount,company.cash+(b.groupReserve or 0))
            local fromCash=math.min(company.cash,amount); company.cash=company.cash-fromCash
            if amount>fromCash then b.groupReserve=b.groupReserve-(amount-fromCash) end
        end
        b.enemyBudget=b.enemyBudget-amount; b.enemyBid=b.enemyBid+amount
        b.enemyWait=B.enemyWait*profile.wait*(b.assault and b.assault.wait or 1)*self:EnemyWaitFactor()*(b.hub and b.hub.enemyWait or 1)
        if amount>0 then
            self:Log("相手側の追加出資  +"..comma(amount)); b.lastEnemyAction=b.elapsed
            self:Notify("enemy","追加出資  +"..comma(amount).."（計 "..comma(b.enemyBid).."）","fund")
        end
        if company and self.random()<math.min(.9,C.tactics.aiUseChance+(b.assault and b.assault.tactic or 0)) then self:UseEnemyTactic(company) end
    end
    b.momentum=math.max(0,b.momentum-B.momentumDecay*dt)
    -- Saturation prevents a single enormous bid from teleporting the gauge.
    -- Stances discount money toward the border: PlayerForce() is the weighted contribution.
    local pressure=clamp((self:PlayerForce()-b.enemyBid)/math.max(B.priceFloor,b.effectiveValue),-1,self:PressureCap())
    b.acceleration=-pressure*B.pressureAcceleration-b.momentum+B.baseAcceleration
        -self:EffectTotal("playerAcceleration",0)-self:EffectTotal("enemyAccelerationPenalty",0)+self:EffectTotal("enemyAccelerationBoost",0)
        +(b.assaultAcceleration or 0)
    b.acceleration=b.acceleration+self:IdlePressure()
    b.velocity=clamp(b.velocity+(b.acceleration-B.drag*b.velocity)*dt,-B.maxVelocity,B.maxVelocity)
    -- Position-dependent pace: the border creeps near the centre and races near either edge.
    local edge=math.abs(b.gauge)/B.gaugeLimit
    b.gaugeSpeed=b.velocity*B.paceScale*(B.centerSpeed+(B.edgeSpeed-B.centerSpeed)*edge^B.edgeCurve)
    b.gauge=clamp(b.gauge+b.gaugeSpeed*dt,-B.gaugeLimit,B.gaugeLimit)
    if b.gauge<=-B.gaugeLimit then self:Finish("won")
    elseif b.gauge>=B.gaugeLimit then self:Finish("lost")
    elseif b.elapsed>=B.duration then self:Finish("timeout") end
end
function E:Tick(dt)
    if not self.battle or self.battle.result or type(dt)~="number" or dt~=dt or dt<=0 then return end
    self.accumulator=self.accumulator+math.min(dt,B.maxFrameDelta)
    while self.accumulator+1e-9>=B.step and not self.battle.result do
        self.accumulator=math.max(0,self.accumulator-B.step); self:Step(B.step)
    end
end
