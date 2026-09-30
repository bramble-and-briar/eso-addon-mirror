local M = {}; PBTrade.Model = M
local C, D = PBTrade.Config, PBTrade.Data
function M.Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}; for k,v in pairs(value) do copy[k] = M.Copy(v) end; return copy
end
function M.New()
    local s = {schemaVersion=C.schemaVersion, cash=C.campaign.startingCash, properties={},
        companies=M.Copy(D.companies),
        visited={}, visitedProperties={}, unlocked={}, learnedTactics={smile=true}, learnedGroups={}, alliances={},
        wins=0, losses=0, defensesWon=0, defensesLost=0, chapter=1, reputation=50,
        cycles=0,debt=0,rebuilds=0,campaignComplete=false,molagTakeover=false,molagFortified=false,
        molagFortificationVersion=0,canonicalValuation=C.canonical.version,
        delegatedWins=0,delegatedLosses=0,lastStrategicCycle=0}
    for _, p in ipairs(D.properties) do
        s.properties[p.id] = M.Copy(p)
        s.properties[p.id].reserve = p.expectedProfit * C.battle.reserveProfitFactor
    end
    s.hub=PBTrade.Hub.New(s.cycles)
    M.Unlock(s); return s
end
-- A real place discovered after the campaign has run for a while enters at the current
-- market level: its base price compounded at the neutral growth rate for every settled period.
function M.ScaleToMarket(s,p)
    local E=C.economy
    local periods=s.cycles or 0
    if periods<=0 then p.reserve=p.expectedProfit*C.battle.reserveProfitFactor; return p end
    local factor=(1+E.marketGrowth+E.neutralGrowthBonus)^periods
    p.marketValue=math.min(E.maximumPropertyValue,math.max(p.marketValue,math.floor(p.marketValue*factor)))
    p.expectedProfit=math.min(E.maximumExpectedProfit,math.max(p.expectedProfit,math.floor(p.expectedProfit*factor)))
    p.reserve=p.expectedProfit*C.battle.reserveProfitFactor
    return p
end
-- Average value of the regular properties right now (real places excluded, so they never
-- feed back into their own reference price).
function M.MarketAverage(s)
    local total,n=0,0
    for _,p in pairs(s.properties) do if not p.canonical then total=total+p.marketValue; n=n+1 end end
    return n>0 and total/n or C.canonical.base
end
-- Prices a real place from the current average property: tier multiple x spread, plus any
-- investments already made in it. `average` may be passed in to price many at once.
function M.PriceCanonical(s,p,average)
    local L=PBTrade.LiveCatalog; if not L then return M.ScaleToMarket(s,p) end
    local value,profit,tier=L.BaseValue(p.id,p.name,average or M.MarketAverage(s))
    p.marketValue,p.expectedProfit,p.valueTier=value,profit,tier and tier.label or nil
    p.finalAcquisition=tier and tier.finalAcquisition==true or false
    if tier and tier.category and p.category~="inn" then p.category=tier.category end
    for _=1,p.investCount or 0 do
        p.marketValue=math.floor(p.marketValue*(1+C.admin.investValueGain)); p.expectedProfit=math.floor(p.expectedProfit*(1+C.admin.investProfitGain))
    end
    p.reserve=p.expectedProfit*C.battle.reserveProfitFactor
    return p
end
function M.HasOwnedCategory(s,category)
    for _,p in ipairs(M.Owned(s)) do if p.category==category then return true end end
    return false
end
function M.Owned(s, owner)
    local result = {}
    for _, p in ipairs(D.properties) do
        if s.properties[p.id].owner == (owner or C.playerId) then result[#result+1] = s.properties[p.id] end
    end
    return result
end
function M.IsAvailable(s,p)
    if p.finalAcquisition and not s.campaignComplete then return false end
    local company=s.companies[p.owner]
    if (p.minChapter or (company and company.minChapter) or 1)>s.chapter then return false end
    for _,id in ipairs(p.requiresProperties or {}) do
        if not s.properties[id] or s.properties[id].owner~=C.playerId then return false end
    end
    return true
end
function M.IsPropertyVisited(s,p)
    return not p.canonical or p.requiresVisit==false or s.visitedProperties[p.id]==true
end
-- Cash plus owned property values (no hub). This is the scale hub prices are set against, so a
-- facility costs the same share of a company's wealth whenever it is ordered.
function M.CoreAssets(s)
    -- Force a floating-point accumulator.  Long campaigns can legitimately exceed the
    -- signed 64-bit integer range in desktop Lua even though ESO's Lua number is a double.
    local total = 0.0+s.cash
    for _, p in ipairs(M.Owned(s)) do total = total + p.marketValue end
    return total
end
-- What the player has sunk into the trade hub (built, under construction and legacy annex),
-- counted at the amount paid. Ordering a facility therefore moves wealth from cash into the
-- hub instead of making the company look poorer; demolishing returns only the refund.
function M.HubValue(s)
    local total=0.0
    if s.hub then for _,b in ipairs(PBTrade.Hub.All(s.hub)) do total=total+(b.paidCost or 0) end end
    return total*PBTrade.HubData.assetShare
end
function M.Assets(s) return M.CoreAssets(s)+M.HubValue(s) end
-- Reference wealth for hub prices (the field is still called `average` in Hub contexts).
function M.HubCostBase(s) return M.CoreAssets(s) end
function M.FormatNumber(value)
    value=math.floor(value or 0); local sign=value<0 and "-" or ""
    local reversed=string.format("%.0f",math.abs(value)):reverse():gsub("(%d%d%d)","%1,")
    return sign..reversed:gsub(",$",""):reverse()
end
-- Money in Japanese units, the two largest groups: 6500 / 1万6050 / 1億2345万 / 3兆4123億.
-- Lower groups are dropped (not rounded up), so a figure never reads as more than it is.
local moneyUnits={{1e16,"京"},{1e12,"兆"},{1e8,"億"},{1e4,"万"}}
function M.FormatMoney(value)
    value=math.floor(value or 0); local sign=value<0 and "-" or ""; value=math.abs(value)
    if value<1e4 then return sign..string.format("%.0f",value) end
    for i,unit in ipairs(moneyUnits) do
        if value>=unit[1] then
            local top=math.floor(value/unit[1])
            local text=string.format("%.0f",top)..unit[2]
            local nextUnit=moneyUnits[i+1]
            local restValue=value-top*unit[1]
            local rest=nextUnit and math.floor(restValue/nextUnit[1]) or math.floor(restValue)
            if rest>0 then text=text..string.format("%.0f",rest)..(nextUnit and nextUnit[2] or "") end
            return sign..text
        end
    end
end
M.FormatCompact=M.FormatMoney
function M.HubSupply(s)
    local supply={}; local blueprints=PBTrade.HubData.blueprints
    for _,p in pairs(s.properties) do if p.owner==C.playerId then
        for id,b in pairs(blueprints) do if b.categories[p.category] then supply[id]=(supply[id] or 0)+1 end end
    end end
    return supply
end
function M.RefreshHub(s)
    if not s.hub then return end
    PBTrade.Hub.Expand(s.hub,s.chapter)
    if s.chapter>=3 then PBTrade.Hub.LearnBlueprints(s.hub,M.HubSupply(s)) end
end
function M.HubProfile(s,p,attacker)
    local company=s.companies[attacker or p.owner]
    return PBTrade.Hub.BattleProfile(s.hub,s.chapter,M.HubSupply(s),company and company.personality,
        M.IsCriticalProperty(s,p) or p.isHeadquarters==true,attacker~=nil)
end
-- How much the hub eases one stance right now (0..stanceReliefMax), and the ability behind it.
function M.HubStanceRelief(s,stanceId)
    local K=PBTrade.HubData; local ability=K.stanceAbility[stanceId]
    if not ability or s.chapter<K.minChapter then return 0,ability,0 end
    local have=PBTrade.Hub.Effects(s.hub,s.chapter,M.HubSupply(s)).abilities[ability] or 0
    local threshold=K.battle.threshold[math.min(5,s.chapter)]
    return K.stanceReliefMax*have/(have+threshold),ability,have
end
function M.HubSummary(s,p,attacker)
    local r=M.HubProfile(s,p,attacker); if not r.enabled then return nil end
    local specialty=""; for _,a in ipairs(PBTrade.HubData.abilities) do if a.id==r.specialty then specialty=a.name end end
    return (r.barrier and ("重点障壁："..specialty) or "拠点支援")
        ..string.format("：資金効力 %.2f倍 / 交渉基準 %.2f倍",r.pressure,r.value)
        ..string.format("\n待機 %.2f倍 / 敵待機 %.2f倍 / 疲弊 %.2f倍",r.playerWait,r.enemyWait,r.idle)
end
function M.Unlock(s)
    M.RefreshHub(s)
    local tier = math.floor(math.max(0, #M.Owned(s)-2) / C.campaign.unlockOwnedStep)
    for _, z in ipairs(D.zones) do
        if (z.minChapter or 1)<=s.chapter and z.unlockTier<=tier then s.unlocked[z.id]=true end
    end
end
function M.RiskLabel(risk)
    if risk >= 128 then return "離反", "888888" end
    if risk >= 90 then return "危険", "ff8585" end
    if risk >= 55 then return "警戒", "ffc46b" end
    if risk >= 25 then return "注意", "eee193" end
    return "安定", "94d3b0"
end
-- Real places in a region: how many exist (in this chapter) and how many were visited.
function M.ZoneLandmarks(s,id)
    local total,visited=0,0
    for _,propertyId in ipairs(D.propertyIdsByZone[id] or {}) do
        local p=s.properties[propertyId]
        if p and p.canonical and M.IsAvailable(s,p) then
            total=total+1; if M.IsPropertyVisited(s,p) then visited=visited+1 end
        end
    end
    return total,visited
end
function M.ZoneSummary(s, id)
    local counts = {own=0, enemy=0, neutral=0, ally=0}
    for _, propertyId in ipairs(D.propertyIdsByZone[id] or {}) do
        local p=s.properties[propertyId]
        if M.IsAvailable(s,p) then
            local key = p.owner == C.playerId and "own" or (p.owner == C.neutralId and "neutral" or (M.IsAllied(s,p.owner) and "ally" or "enemy"))
            counts[key] = counts[key]+1
        end
    end
    return counts
end
function M.Rankings(s)
    local rows,byId={},{}
    for id,company in pairs(s.companies) do
        if id~=C.neutralId and not company.dissolved and (company.minChapter or 1)<=s.chapter then
            local cash=id==C.playerId and s.cash or company.cash
            local row={id=id,name=company.name,cash=cash,reserves=0,assets=cash,propertyCount=0}
            rows[#rows+1]=row; byId[id]=row
        end
    end
    for _,p in pairs(s.properties) do
        local row=byId[p.owner]
        if row then
            row.reserves=row.reserves+p.reserve; row.assets=row.assets+p.marketValue; row.propertyCount=row.propertyCount+1
        end
    end
    for _,row in ipairs(rows) do row.fundingPower=row.cash+row.reserves end
    table.sort(rows,function(a,b)
        if a.fundingPower~=b.fundingPower then return a.fundingPower>b.fundingPower end
        if a.assets~=b.assets then return a.assets>b.assets end
        return a.id<b.id
    end)
    for i,row in ipairs(rows) do row.rank=i end
    return rows
end
function M.GroupMembers(s,id,owner)
    local result={}
    for _,p in ipairs(D.properties) do
        local state=s.properties[p.id]
        if state.owner==(owner or C.playerId) and M.IsAvailable(s,state) then
            for _,groupId in ipairs(state.groups) do
                if groupId==id then result[#result+1]=state; break end
            end
        end
    end
    return result
end
function M.FormatRatio(x)
    local text=string.format("%.2f",x):gsub("0+$",""):gsub("%.$",""); return text
end
-- One pass over the catalog builds the owned member lists of every requested group
-- (the per-group scan cost ~70 x 1,300 iterations per ledger refresh once super groups exist).
function M.GroupMembersAll(s,ids)
    local wanted,result={},{}
    for _,id in ipairs(ids) do wanted[id]=true; result[id]={} end
    for _,p in ipairs(D.properties) do
        local state=s.properties[p.id]
        if state and state.owner==C.playerId and M.IsAvailable(s,state) then
            for _,groupId in ipairs(state.groups) do
                if wanted[groupId] then local list=result[groupId]; list[#list+1]=state end
            end
        end
    end
    return result
end
function M.GroupStatusAll(s,ids)
    local members=M.GroupMembersAll(s,ids); local out={}
    for _,id in ipairs(ids) do out[id]=M.GroupStatus(s,id,members[id]) end
    return out
end
function M.GroupStatus(s,id,members)
    local group=D.groups[id]; if not group then return nil end
    members=members or M.GroupMembers(s,id)
    local landmarks=0; for _,p in ipairs(members) do if p.canonical then landmarks=landmarks+1 end end
    local G=C.groups; local landmarkBonus=math.min(G.landmarkBonusMax,landmarks*G.landmarkBonusPerMember)
    return {id=id,name=group.name,members=members,count=#members,minimum=group.minimum,
        learned=s.learnedGroups[id] or false,usable=s.learnedGroups[id] and #members>=group.minimum,
        bonus=group.bonus+landmarkBonus,baseBonus=group.bonus,landmarks=landmarks,landmarkBonus=landmarkBonus,tier=group.tier,
        discoveryChance=group.discoveryChance}
end
-- Groups an AI company can actually activate from its current portfolio.  COM companies do not
-- receive free discoveries: every listed group already satisfies its real ownership minimum.
function M.CompanyGroups(s,owner)
    local buckets={}
    for _,definition in ipairs(D.properties) do
        local p=s.properties[definition.id]
        if p and p.owner==owner and M.IsAvailable(s,p) then
            for _,id in ipairs(p.groups or {}) do
                local members=buckets[id]; if not members then members={}; buckets[id]=members end
                members[#members+1]=p
            end
        end
    end
    local rows={}
    for id,members in pairs(buckets) do
        local group=D.groups[id]
        local required=group and math.max(group.minimum or 2,group.discoverAt or 0)
        if group and #members>=required then
            local landmarks=0; for _,p in ipairs(members) do if p.canonical then landmarks=landmarks+1 end end
            local landmarkBonus=math.min(C.groups.landmarkBonusMax,landmarks*C.groups.landmarkBonusPerMember)
            rows[#rows+1]={id=id,name=group.name,members=members,count=#members,minimum=group.minimum,
                required=required,bonus=group.bonus+landmarkBonus,tier=group.tier}
        end
    end
    table.sort(rows,function(a,b) if a.bonus~=b.bonus then return a.bonus>b.bonus end return a.id<b.id end)
    return rows
end
function M.AvailableGroups(s)
    local rows={}
    local ids={}; for id in pairs(D.groups) do ids[#ids+1]=id end
    for _,status in pairs(M.GroupStatusAll(s,ids)) do if status.usable then rows[#rows+1]=status end end
    table.sort(rows,function(a,b) return a.name<b.name end); return rows
end
-- Legacy all-property progress remains available for old saves and statistics. The live ESO
-- catalog is open-ended, so it is no longer used as the true-ending condition.
function M.EverythingStatus(s)
    local owned,total=0,0
    for _,definition in ipairs(D.properties) do
        local p=s.properties[definition.id]
        if p and M.IsAvailable(s,p) and (not p.canonical or M.IsPropertyVisited(s,p)) then
            total=total+1; if p.owner==C.playerId then owned=owned+1 end
        end
    end
    return owned,total
end
D.endlessChapter={title="最後の大買収",subtitle="トール・ドライオクを商会の旗の下へ",background="chapter_5",
    description="モラグ・バルの鎖を断った商会に、最後の証文が届きました。グレナンブラでトール・ドライオクを物件登録し、100京ゴールド級の最終買収を成立させてください。"}
function M.TrueEndingProperty(s)
    for _,definition in ipairs(D.properties) do
        local p=s.properties[definition.id]
        if p and p.finalAcquisition then return p end
    end
end
function M.StartEndless(s,random)
    if s.endless then return nil end
    s.endless=true
    local target=M.TrueEndingProperty(s)
    return {count=0,target=target,registered=target and M.IsPropertyVisited(s,target) or false}
end
function M.CheckTrueEnding(s)
    if not s.campaignComplete or s.trueEnding then return false end
    local target=M.TrueEndingProperty(s)
    if target and M.IsPropertyVisited(s,target) and target.owner==C.playerId then s.trueEnding=true; return true end
    return false
end
function M.CampaignStatus(s)
    if s.campaignComplete then
        local target=M.TrueEndingProperty(s); local assets=M.Assets(s)
        local registered=target and M.IsPropertyVisited(s,target) or false
        local owned=target and target.owner==C.playerId or false
        local primary=s.trueEnding and "トール・ドライオク買収完了"
            or (registered and ("最終買収 "..(owned and "成立" or "未成立").." / 評価額 "..M.FormatCompact(target.marketValue))
                or "トール・ドライオクを現地で物件登録")
        return {chapter=D.endlessChapter,current=owned and 1 or 0,target=1,complete=s.trueEnding==true,assets=assets,
            assetComplete=true,endless=true,
            finalProperty=target,registered=registered,
            summary=primary.."\n総資産 "..M.FormatCompact(assets)..(s.trueEnding and "\n真のエンディング到達" or ""),short=primary}
    end
    local chapter=D.campaigns[s.chapter]; if not chapter then return nil end
    local objective=chapter.objective; local current,target,complete
    if objective.type=="assets" then
        current=M.Assets(s); target=objective.target; complete=current>=target
    else
        current=0; target=#objective.targets
        for _,id in ipairs(objective.targets) do if s.properties[id].owner==C.playerId then current=current+1 end end
        complete=current>=target
    end
    local assets=M.Assets(s); local assetTarget=objective.type=="assets" and objective.target or objective.assetTarget
    local assetComplete=not assetTarget or assets>=assetTarget
    complete=complete and assetComplete
    local primary=objective.type=="assets" and ("総資産 "..M.FormatCompact(assets).." / "..M.FormatCompact(target))
        or ("中枢拠点 "..current.." / "..target)
    local parts={primary}
    if objective.type~="assets" and assetTarget then parts[#parts+1]="総資産 "..M.FormatCompact(assets).." / "..M.FormatCompact(assetTarget) end
    return {chapter=chapter,current=current,target=target,complete=complete,assets=assets,assetTarget=assetTarget,
        assetComplete=assetComplete,
        summary=table.concat(parts,"\n"),short=primary}
end
function M.FormChapterTwoAlliance(s)
    local id=C.campaign.chapterTwoAlly
    local company=id and s.companies[id]
    if not company or company.dissolved or #M.Owned(s,id)==0 then return false end
    if not M.IsAllied(s,id) then s.alliances[id]={trust=C.alliance.startTrust,automatic=true} end
    return true
end
function M.AdvanceCampaign(s)
    if s.endless then return nil end
    local status=M.CampaignStatus(s)
    if status and status.complete and s.chapter<#D.campaigns then
        s.chapter=s.chapter+1; M.Unlock(s)
        if s.chapter==2 then M.FormChapterTwoAlliance(s) end
        return D.campaigns[s.chapter]
    end
    if status and status.complete and s.chapter==#D.campaigns and not s.campaignComplete then
        s.campaignComplete=true; return {ending=true,title="交易戦終結",background="chapter_5"}
    end
end
-- The three outer headquarters and final stronghold are economic fortresses.
-- This flag is separate from the mass takeover so older chapter-5 saves are fortified once.
function M.FortifyMolagHeadquarters(s)
    local K=C.campaign
    if (s.molagFortificationVersion or 0)>=K.molagFortificationVersion or s.chapter<K.molagTakeoverChapter then return nil end
    local chapter=D.campaigns[K.molagTakeoverChapter]
    local target=chapter and chapter.objective and chapter.objective.assetTarget or 0
    local ids=D.companyHeadquarters[K.molagCompany] or {}
    local values,total={},0
    for i,id in ipairs(ids) do
        local p=s.properties[id]
        local shares=K.molagHeadquartersAssetShares
        local share=shares[i] or shares[#shares] or 0
        local value=math.min(C.economy.maximumPropertyValue,
            math.max(p.marketValue,math.floor(target*share+.5)))
        p.marketValue=value
        p.expectedProfit=math.min(C.economy.maximumExpectedProfit,
            math.max(p.expectedProfit,math.floor(value*K.molagHeadquartersProfitYield+.5)))
        values[#values+1]={id=id,name=p.name,value=value}; total=total+value
    end
    local company=s.companies[K.molagCompany]
    local treasury=math.floor(total*K.molagTreasuryShare+.5)
    if company then
        company.cash=math.max(company.cash,treasury)
        local stronghold=s.properties[ids[#ids]]
        if stronghold and stronghold.owner~=C.playerId and not s.campaignComplete then company.dissolved=nil end
    end
    s.molagFortified=true
    s.molagFortificationVersion=K.molagFortificationVersion
    return {headquarters=values,totalValue=total,treasury=treasury}
end

-- Chapter 5 difficulty spike: a random share of every property not yet Molag Bal's
-- defects to the Concern at once, the player's holdings included. Runs once per save.
function M.MolagTakeover(s,random)
    local K=C.campaign
    if s.chapter<K.molagTakeoverChapter then return nil end
    local fortification=M.FortifyMolagHeadquarters(s)
    if s.molagTakeover then
        if fortification then
            return {candidates=0,count=0,fromPlayer=0,fromRivals=0,fromNeutral=0,lost={},fortification=fortification}
        end
        return nil
    end
    s.molagTakeover=true
    local candidates={}
    for _,definition in ipairs(D.properties) do
        local p=s.properties[definition.id]
        if p and p.owner~=K.molagCompany then candidates[#candidates+1]=p end
    end
    random=random or math.random
    for i=#candidates,2,-1 do
        local j=math.min(i,math.floor(random()*i)+1); candidates[i],candidates[j]=candidates[j],candidates[i]
    end
    local count=math.floor(#candidates*K.molagTakeoverShare+.5)
    local report={candidates=#candidates,count=count,fromPlayer=0,fromRivals=0,fromNeutral=0,lost={},fortification=fortification}
    for i=1,count do
        local p=candidates[i]
        if p.owner==C.playerId then report.fromPlayer=report.fromPlayer+1; report.lost[#report.lost+1]=p
        elseif p.owner==C.neutralId then report.fromNeutral=report.fromNeutral+1
        else report.fromRivals=report.fromRivals+1 end
        p.owner=K.molagCompany
    end
    return report
end
-- Company takeover: once the player owns all of a rival's headquarters, the rival is
-- dissolved and every property it still holds joins the player (with part of its cash).
function M.Takeover(s,propertyId)
    local company=D.headquartersOf[propertyId]
    local c=company and s.companies[company]
    if not c or c.dissolved then return nil end
    if s.chapter<(D.companyTakeoverChapter[company] or 1) then return nil end
    for _,id in ipairs(D.companyHeadquarters[company]) do
        if s.properties[id].owner~=C.playerId then return nil end
    end
    local report={company=company,name=c.name,count=0,value=0,cash=math.floor(c.cash*C.takeover.cashShare),body=c.ordinaryCompany==true}
    for _,definition in ipairs(D.properties) do
        local p=s.properties[definition.id]
        if p and p.owner==company then
            p.owner=C.playerId; p.independenceRisk=math.min(p.independenceRisk,C.independence.reacquireRisk)
            report.count=report.count+1; report.value=report.value+p.marketValue
        end
    end
    s.cash=s.cash+report.cash; c.cash=0; c.dissolved=true; s.alliances[company]=nil; M.Unlock(s)
    return report
end
-- Called when a chapter opens: rivals whose headquarters the player already holds fall now.
function M.CheckTakeovers(s)
    local reports={}; local ids={}
    for company in pairs(D.companyHeadquarters) do ids[#ids+1]=company end; table.sort(ids)
    for _,company in ipairs(ids) do
        local report=M.Takeover(s,D.companyHeadquarters[company][1]); if report then reports[#reports+1]=report end
    end
    return reports
end
-- A rival's size: cash plus the value (and the reserves) of every property it holds.
function M.CompanyAssets(s,id)
    local c=s.companies[id]; local value,reserves=0.0+(c and c.cash or 0),0.0
    for _,p in pairs(s.properties) do if p.owner==id then value=value+p.marketValue; reserves=reserves+(p.reserve or 0) end end
    return value,reserves
end
-- Negotiation value of a property: a rival's headquarters is worth a share of the whole group.
function M.NegotiationValue(s,p,attacker)
    local company=D.headquartersOf[p.id]
    if attacker or not company or p.owner~=company then return p.marketValue,false end
    local assets=M.CompanyAssets(s,company)
    return math.max(p.marketValue,math.floor(assets*C.takeover.hqValueShare)),true
end
-- Deterministic 0..1 roll from a key, so the list, the start dialog and the battle agree.
local function roll(key)
    local h=5381
    for i=1,#key do h=(h*33+key:byte(i))%2147483647 end
    for _=1,3 do h=(h*48271+11)%2147483647 end
    return h/2147483647
end
-- Stances guarding this negotiation this period: a list of Data.stances ids (possibly empty).
-- Molag Bal's dominion stacks two stances.
function M.NegotiationStances(s,p,attacker)
    local K=C.stances
    -- Stances are how a target resists being bought; defending our own property has none.
    if not p or attacker or (s.chapter or 1)<K.minChapter then return {} end
    local opponent=attacker or p.owner
    local key=p.id..":"..tostring(opponent)..":"..tostring(s.cycles or 0)
    local critical=not attacker and M.IsCriticalProperty(s,p)
    local order=D.stances
    if opponent==C.neutralId then
        if critical or roll(key)<K.neutralShare then return {order[1+math.floor(roll(key.."#")*#order)%#order].id} end
        return {}
    end
    local company=s.companies[opponent]; if not company then return {} end
    if not critical and roll(key)>=K.routineShare then return {} end
    if company.personality=="dominion" then
        local first=1+math.floor(roll(key.."#")*#order)%#order
        return {order[first].id,order[first%#order+1].id}
    end
    return {K.house[company.personality] or order[1+math.floor(roll(key.."#")*#order)%#order].id}
end
-- One line describing the stances ("鉄壁の金庫：hint"), or nil.
function M.StanceSummary(ids,separator)
    local parts={}
    for _,id in ipairs(ids or {}) do local st=D.stanceById[id]; if st then parts[#parts+1]="構え「"..st.name.."」："..st.hint end end
    return #parts>0 and table.concat(parts,separator or "\n") or nil
end
function M.FundingPower(s)
    local total=0.0+s.cash; for _,p in ipairs(M.Owned(s)) do total=total+p.reserve end; return total
end
-- Cheapest property the player could negotiate for right now (nil when none is open).
function M.CheapestTarget(s)
    local best
    for _,definition in ipairs(D.properties) do
        local p=s.properties[definition.id]
        if p and p.owner~=C.playerId and s.unlocked[p.zone] and M.IsAvailable(s,p) and M.IsPropertyVisited(s,p)
            and (not best or p.marketValue<best.marketValue) then best=p end
    end
    return best
end
-- Rescue loan scaled to the market, so a bankrupt company can always buy back a foothold
-- even after many periods of compounding prices.
function M.RebuildTerms(s)
    local E=C.economy; local cheapest=M.CheapestTarget(s); local value=cheapest and cheapest.marketValue or 0
    local need=math.max(E.rebuildThreshold,math.floor(value*E.rebuildTargetShare))
    local grant=math.max(E.rebuildGrant,math.ceil(value*E.rebuildGrantShare))
    return need,grant,cheapest
end
function M.CanRebuild(s) local need=M.RebuildTerms(s); return M.FundingPower(s)<need end
function M.Rebuild(s)
    local need,grant=M.RebuildTerms(s)
    if M.FundingPower(s)>=need then return false,"再建融資が必要な状態ではありません" end
    s.cash=s.cash+grant; s.debt=s.debt+grant
    s.reputation=math.max(0,s.reputation-C.economy.rebuildReputationCost); s.rebuilds=s.rebuilds+1
    return true,grant
end
-- Rivals trade among themselves once per settlement: neutral properties are bought outright,
-- rival-owned ones are contested by cash and defense. Campaign targets and headquarters stay put.
local protected
function M.RivalTurn(s,random)
    local R=C.rivals
    if not protected then
        protected={}
        for _,chapter in ipairs(D.campaigns) do for _,id in ipairs(chapter.objective.targets or {}) do protected[id]=true end end
    end
    local ids={}; for id,c in pairs(s.companies) do
        if id~=C.playerId and id~=C.neutralId and (c.minChapter or 1)<=s.chapter and c.cash>0 then ids[#ids+1]=id end
    end
    table.sort(ids)
    local deals={}; local count=#D.properties
    for _,id in ipairs(ids) do
        local c=s.companies[id]
        if count>0 and random()<R.tradeChance*(c.aggression or .5) then
            local budget=c.cash*R.maxCashShare; local best,bestScore
            for _=1,R.samples do
                local p=s.properties[D.properties[math.min(count,math.floor(random()*count)+1)].id]
                if p and p.owner~=id and p.owner~=C.playerId and not protected[p.id] and not p.isHeadquarters and not p.finalAcquisition
                    and M.IsAvailable(s,p) and math.floor(p.marketValue*R.priceFactor)<=budget then
                    local score=p.marketValue*(p.category==c.acquisitionBias and R.biasWeight or 1)
                    if not bestScore or score>bestScore then best,bestScore=p,score end
                end
            end
            if best then
                local seller=best.owner~=C.neutralId and s.companies[best.owner] or nil
                local chance=1
                if seller then chance=math.max(.1,math.min(.9,c.cash/(c.cash+seller.cash*(1+(seller.defense or .5))))) end
                if random()<chance then
                    local price=math.floor(best.marketValue*R.priceFactor)
                    c.cash=c.cash-price
                    if seller then seller.cash=seller.cash+math.floor(price*R.sellerShare) end
                    deals[#deals+1]={buyer=id,seller=best.owner,property=best,price=price}
                    best.owner=id
                    if #deals>=(R.maxDealsPerPeriod or math.huge) then break end
                end
            end
        end
    end
    return deals
end
function M.SettleCycle(s)
    local policy=M.ActivePolicy(s); local event=M.ActiveMarketEvent(s)
    local gross,recovered=0,0
    for _,p in pairs(s.properties) do
        if p.owner==C.playerId then
            local eventProfit=event and (not event.categories or event.categories[p.category]) and (event.profitMultiplier or 1) or 1
            gross=gross+math.floor(p.expectedProfit*C.economy.profitShare*(policy and policy.profitMultiplier or 1)*eventProfit)
            local cap=p.expectedProfit*C.battle.reserveProfitFactor
            local recovery=C.economy.reserveRecoveryPeriods*(policy and policy.reserveRecoveryMultiplier or 1)
            local before=p.reserve; p.reserve=math.min(cap,p.reserve+p.expectedProfit*recovery)
            recovered=recovered+(p.reserve-before)
        elseif p.owner~=C.neutralId and s.companies[p.owner] then
            s.companies[p.owner].cash=s.companies[p.owner].cash+math.floor(p.expectedProfit*C.economy.enemyProfitShare)
        end
    end
    if (s.guardPeriods or 0)>0 then s.guardPeriods=s.guardPeriods-1 end
    for id,a in pairs(s.alliances) do if type(a)=="table" then a.trust=math.min(C.alliance.maxTrust,a.trust+C.alliance.trustRecovery) end end
    if (s.scandalPeriods or 0)>0 then s.scandalPeriods=s.scandalPeriods-1 end
    M.RefreshHub(s)
    local hubReport=PBTrade.Hub.Settle(s.hub,s.cycles+1,s.chapter)
    gross=gross+hubReport.net
    local debtPayment=math.min(s.debt,math.floor(gross*C.economy.debtPaymentShare))
    s.debt=s.debt-debtPayment; s.cash=s.cash+gross-debtPayment
    local marketGrowth,highestValue=0,0
    for _,p in pairs(s.properties) do
        local bonus=p.owner==C.playerId and C.economy.playerGrowthBonus
            or (p.owner==C.neutralId and C.economy.neutralGrowthBonus or C.economy.enemyGrowthBonus)
        local policyGrowth=p.owner==C.playerId and policy and (policy.playerGrowthBonus or 0) or 0
        local eventGrowth=event and (not event.categories or event.categories[p.category]) and (event.growthBonus or 0) or 0
        local rate=C.economy.marketGrowth+bonus+policyGrowth+eventGrowth
        local before=p.marketValue
        p.marketValue=math.min(C.economy.maximumPropertyValue,math.max(before+1,math.floor(before*(1+rate)+.5)))
        p.expectedProfit=math.min(C.economy.maximumExpectedProfit,math.max(p.expectedProfit+1,math.floor(p.expectedProfit*(1+rate)+.5)))
        marketGrowth=marketGrowth+(p.marketValue-before); highestValue=math.max(highestValue,p.marketValue)
    end
    s.cycles=s.cycles+1
    return {hub=hubReport,gross=gross,debtPayment=debtPayment,net=gross-debtPayment,reserveRecovered=recovered,
        marketGrowth=marketGrowth,highestValue=highestValue,cycle=s.cycles}
end
-- One period (期) = acquisition, the counterattack/defense check and the settlement.
-- The period in progress is the next one to be settled.
function M.CurrentPeriod(s) return (s.cycles or 0)+1 end
local stateFields={"cash","wins","losses","defensesWon","defensesLost","chapter","reputation","cycles","debt","rebuilds","campaignComplete","molagTakeover","molagFortified","molagFortificationVersion","companyName","guardPeriods","scandalPeriods","envoyBattles","canonicalValuation","endless","trueEnding","activePolicy","policyUntil","marketEvent","marketEventUntil","lastStrategicCycle","strategyPending","delegatedWins","delegatedLosses"}
-- Domestic affairs (内政). Each action is costed in gold; the caller spends the action point.
function M.InvestCost(s,p)
    local K=C.admin
    return math.ceil(p.marketValue*K.investCostShare*(1+K.investRepeatSurcharge*(p.investCount or 0)))
end
function M.Invest(s,id)
    local p=s.properties[id]
    if not p or p.owner~=C.playerId then return false,"自社物件ではありません" end
    local cost=M.InvestCost(s,p); if s.cash<cost then return false,"商会資金が不足しています（必要 "..cost.."）" end
    local K,E=C.admin,C.economy
    s.cash=s.cash-cost
    p.marketValue=math.min(E.maximumPropertyValue,math.floor(p.marketValue*(1+K.investValueGain)))
    p.expectedProfit=math.min(E.maximumExpectedProfit,math.floor(p.expectedProfit*(1+K.investProfitGain)))
    p.investCount=(p.investCount or 0)+1
    return true,cost
end
function M.LobbyCost(s,p) local K=C.admin; return math.max(K.lobbyMinimumCost,math.ceil(p.marketValue*K.lobbyCostShare)) end
function M.Lobby(s,id)
    local p=s.properties[id]
    if not p or p.owner~=C.playerId then return false,"自社物件ではありません" end
    if p.independenceRisk<=0 then return false,"負担はすでにありません" end
    local cost=M.LobbyCost(s,p); if s.cash<cost then return false,"商会資金が不足しています（必要 "..cost.."）" end
    s.cash=s.cash-cost; local before=p.independenceRisk
    p.independenceRisk=math.max(0,p.independenceRisk-C.admin.lobbyAmount)
    return true,cost,before-p.independenceRisk
end
function M.GuardCost(s) local K=C.admin; return math.max(K.guardMinimumCost,math.ceil(M.Assets(s)*K.guardCostShare)) end
function M.Guard(s)
    local cost=M.GuardCost(s); if s.cash<cost then return false,"商会資金が不足しています（必要 "..cost.."）" end
    s.cash=s.cash-cost; s.guardPeriods=C.admin.guardPeriods
    return true,cost
end
local objectiveIds
function M.IsObjective(s,id)
    if not objectiveIds then
        objectiveIds={}
        for _,chapter in ipairs(D.campaigns) do for _,target in ipairs(chapter.objective.targets or {}) do objectiveIds[target]=true end end
    end
    return objectiveIds[id]==true
end
function M.IsCriticalProperty(s,p)
    return p and (p.isHeadquarters or p.finalStronghold or p.finalAcquisition or M.IsObjective(s,p.id)) and true or false
end
function M.ActivePolicy(s)
    if not s.activePolicy or (s.policyUntil or 0)<=s.cycles then return nil end
    return D.tradePolicyById[s.activePolicy]
end
function M.ActiveMarketEvent(s)
    if not s.marketEvent or (s.marketEventUntil or 0)<=s.cycles then return nil end
    return D.marketEventById[s.marketEvent]
end
function M.BeginStrategicSeason(s,random)
    local interval=C.strategy.interval
    if s.strategyPending and D.marketEventById[s.marketEvent] then
        return {cycle=s.lastStrategicCycle,event=D.marketEventById[s.marketEvent],untilCycle=s.marketEventUntil}
    end
    if s.cycles<=0 or s.cycles%interval~=0 or s.lastStrategicCycle==s.cycles then return nil end
    random=random or math.random
    local index=math.min(#D.marketEvents,math.floor(random()*#D.marketEvents)+1)
    local event=D.marketEvents[index]
    s.marketEvent=event.id; s.marketEventUntil=s.cycles+interval; s.lastStrategicCycle=s.cycles; s.strategyPending=true
    return {cycle=s.cycles,event=event,untilCycle=s.marketEventUntil}
end
function M.ChooseTradePolicy(s,id)
    local policy=D.tradePolicyById[id]; if not policy then return false,"経営方針が見つかりません" end
    s.activePolicy=id; s.policyUntil=s.cycles+C.strategy.interval; s.strategyPending=nil
    return true,policy
end
function M.PassiveRecoveryAmount(s)
    local policy=M.ActivePolicy(s)
    return math.max(0,C.independence.passiveRecovery+(policy and policy.riskRecovery or 0))
end
function M.DelegationTerms(s,p)
    local K=C.delegation; local company=s.companies[p.owner]
    local defense=company and company.defense or 0
    local policy,event=M.ActivePolicy(s),M.ActiveMarketEvent(s)
    local chance=K.baseChance+s.reputation*K.reputationWeight-defense*K.defenseWeight
        +(policy and policy.delegateChance or 0)+(event and event.delegateChance or 0)
        -#M.NegotiationStances(s,p)*K.stancePenalty -- a manager cannot break a stance
    chance=math.max(K.minimumChance,math.min(K.maximumChance,chance))
    return math.ceil(p.marketValue*K.successCostShare),math.ceil(p.marketValue*K.failureCostShare),chance
end
function M.CanDelegate(s,p)
    if not p or p.owner==C.playerId then return false,"買収対象ではありません" end
    if s.chapter<C.delegation.minimumChapter then return false,"委任買収は第2章から利用できます" end
    if M.IsCriticalProperty(s,p) then return false,"重要物件はプレイヤー自身の交渉が必要です" end
    if M.IsAllied(s,p.owner) then return false,"同盟商会との交渉は委任できません" end
    if not s.unlocked[p.zone] or not M.IsAvailable(s,p) then return false,"交易路が開いていません" end
    if not M.IsPropertyVisited(s,p) then return false,"実在地点を訪問していません" end
    local cost=M.DelegationTerms(s,p)
    if s.cash<cost then return false,"成功時の買収資金が不足しています" end
    return true
end
function M.DelegationCandidates(s)
    local rows={}
    for _,definition in ipairs(D.properties) do
        local p=s.properties[definition.id]
        local ok=M.CanDelegate(s,p)
        if ok then rows[#rows+1]=p end
    end
    table.sort(rows,function(a,b) return a.marketValue<b.marketValue end)
    return rows
end
function M.DelegateAcquisition(s,id,random)
    local p=s.properties[id]; local ok,why=M.CanDelegate(s,p); if not ok then return false,why end
    local cost,failureCost,chance=M.DelegationTerms(s,p); random=random or math.random
    local seller=p.owner; local success=random()<chance; local paid=success and cost or failureCost
    s.cash=s.cash-paid
    local company=s.companies[seller]; if company then company.cash=company.cash+math.floor(paid*.5) end
    if success then
        p.owner=C.playerId; p.independenceRisk=math.min(p.independenceRisk,C.independence.reacquireRisk)
        s.wins=s.wins+1; s.delegatedWins=(s.delegatedWins or 0)+1; M.Unlock(s)
    else s.losses=s.losses+1; s.delegatedLosses=(s.delegatedLosses or 0)+1 end
    return true,{success=success,property=p,cost=paid,chance=chance,seller=seller}
end
function M.DivestPrice(s,p) return math.floor(p.marketValue*C.admin.divestShare) end
function M.Divest(s,id)
    local p=s.properties[id]
    if not p or p.owner~=C.playerId then return false,"自社物件ではありません" end
    local price=M.DivestPrice(s,p)
    p.owner=C.neutralId; p.investCount=nil; p.independenceRisk=C.admin.divestRisk
    s.cash=s.cash+price
    return true,price
end
function M.BondAmount(s) local K=C.admin; return math.max(K.bondMinimum,math.floor(M.Assets(s)*K.bondShare)) end
function M.BondRoom(s)
    local K=C.admin; local amount=M.BondAmount(s)
    return (s.debt or 0)+math.ceil(amount*(1+K.bondInterest))<=math.max(K.bondMinimum*2,M.Assets(s)*K.bondDebtCap),amount
end
function M.Bond(s)
    local ok,amount=M.BondRoom(s); if not ok then return false,"信用枠の上限に達しています（負債が大きすぎます）" end
    local owed=math.ceil(amount*(1+C.admin.bondInterest))
    s.cash=s.cash+amount; s.debt=(s.debt or 0)+owed
    return true,amount,owed
end
function M.SabotageCost(s) local K=C.admin; return math.max(K.sabotageMinimumCost,math.ceil(M.Assets(s)*K.sabotageCostShare)) end
function M.SabotageChance(s,c)
    local K=C.admin; return math.max(.3,math.min(.8,K.sabotageBaseChance-(c.defense or .5)*K.sabotageDefenseWeight))
end
function M.Sabotage(s,companyId,random)
    local c=s.companies[companyId]
    if not c or companyId==C.playerId or companyId==C.neutralId or c.dissolved then return false,"対象の商会がありません" end
    local cost=M.SabotageCost(s); if s.cash<cost then return false,"商会資金が不足しています（必要 "..cost.."）" end
    s.cash=s.cash-cost
    if (random or math.random)()<M.SabotageChance(s,c) then
        local drained=math.floor(c.cash*C.admin.sabotageDrain); c.cash=c.cash-drained
        return true,cost,{success=true,drained=drained}
    end
    s.reputation=math.max(0,s.reputation-C.admin.scandalReputation); s.scandalPeriods=1
    return true,cost,{success=false}
end
function M.HireCost(s) local K=C.admin; return math.max(K.hireMinimumCost,math.ceil(M.Assets(s)*K.hireCostShare)) end
function M.Hire(s)
    if (s.envoyBattles or 0)>0 then return false,"交渉役はすでに待機しています" end
    local cost=M.HireCost(s); if s.cash<cost then return false,"商会資金が不足しています（必要 "..cost.."）" end
    s.cash=s.cash-cost; s.envoyBattles=1
    return true,cost
end
-- Alliances ---------------------------------------------------------------------------------
function M.IsAllied(s,id) return s.alliances[id]~=nil and type(s.alliances[id])=="table" end
function M.AllianceCount(s) local n=0; for id in pairs(s.alliances) do if M.IsAllied(s,id) then n=n+1 end end; return n end
function M.AllianceCost(s) local K=C.alliance; return math.max(K.minimumCost,math.ceil(M.Assets(s)*K.costShare)) end
function M.AllianceChance(s,c)
    local K=C.alliance; local power=M.FundingPower(s); local ratio=power/math.max(1,power+c.cash)
    return math.max(.1,math.min(.85,K.baseChance+(s.reputation or 50)*K.reputationWeight+ratio*K.powerWeight-(c.aggression or .5)*K.aggressionWeight))
end
function M.CanAlly(s,id)
    local c=s.companies[id]; local K=C.alliance
    if not c or id==C.playerId or id==C.neutralId or c.dissolved or (c.minChapter or 1)>s.chapter then return false,"同盟を結べる商会ではありません" end
    if K.refuses[id] then return false,c.name.."は同盟に応じません" end
    if M.IsAllied(s,id) then return false,"すでに同盟を結んでいます" end
    if M.AllianceCount(s)>=K.maxAlliances then return false,"同盟は "..K.maxAlliances.." つまでです" end
    return true
end
function M.ProposeAlliance(s,id,random)
    local ok,why=M.CanAlly(s,id); if not ok then return false,why end
    local cost=M.AllianceCost(s); if s.cash<cost then return false,"商会資金が不足しています（必要 "..cost.."）" end
    s.cash=s.cash-cost
    if (random or math.random)()<M.AllianceChance(s,s.companies[id]) then
        s.alliances[id]={trust=C.alliance.startTrust}; return true,cost,true
    end
    return true,cost,false
end
-- Lowers trust; at zero the alliance breaks. Returns true when it broke.
function M.StrainAlliance(s,id,amount)
    local a=M.IsAllied(s,id) and s.alliances[id]; if not a then return false end
    a.trust=a.trust-amount
    if a.trust<=0 then s.alliances[id]=nil; return true end
    return false
end
function M.AllianceFundAmount(s,id)
    local c=s.companies[id]; local K=C.alliance
    if not c or not M.IsAllied(s,id) then return 0 end
    return math.min(c.cash,math.max(K.fundMinimum,math.floor(c.cash*K.fundShare)))
end
function M.Repay(s)
    if (s.debt or 0)<=0 then return false,"負債はありません" end
    local amount=math.min(s.debt,math.floor(s.cash*C.admin.repayCashShare))
    if amount<=0 then return false,"返済に回せる商会資金がありません" end
    s.cash=s.cash-amount; s.debt=s.debt-amount; s.reputation=math.min(100,s.reputation+C.admin.repayReputation)
    return true,amount
end
-- Player company name: trimmed, single line, at most companyNameMaxChars UTF-8 characters.
function M.NormalizeCompanyName(text)
    if type(text)~="string" then return nil end
    -- `%c` is locale-sensitive in the client and can classify UTF-8 continuation bytes as
    -- controls on console. Replace ASCII controls explicitly so Japanese bytes stay intact.
    text=text:gsub("%z"," "):gsub("[\1-\31\127]"," ")
    -- Do not use a byte-range gmatch here. The console client can return only its ASCII
    -- matches, which turns "PinkBanther商会" into "PinkBanther" when the name is confirmed.
    -- Walk complete UTF-8 code points directly, as the opening typewriter does.
    local chars={}; local i=1
    while i<=#text do
        local first=text:byte(i)
        local width=first<128 and 1 or (first<224 and 2 or (first<240 and 3 or 4))
        chars[#chars+1]=text:sub(i,i+width-1)
        i=i+width
    end
    local function blank(ch) return ch==" " or ch=="　" or ch=="\t" end
    while chars[1] and blank(chars[1]) do table.remove(chars,1) end
    while chars[#chars] and blank(chars[#chars]) do chars[#chars]=nil end
    if #chars==0 then return nil end
    return table.concat(chars,"",1,math.min(#chars,C.campaign.companyNameMaxChars))
end
function M.SetCompanyName(s,name)
    name=M.NormalizeCompanyName(name); if not name then return false end
    s.companyName=name; s.companies[C.playerId].name=name
    return true
end
function M.CompanyName(s) return s.companyName or s.companies[C.playerId].name end
function M.Export(s)
    local out={schemaVersion=C.schemaVersion,properties={},companies={},visited=M.Copy(s.visited),
        visitedProperties=M.Copy(s.visitedProperties),unlocked=M.Copy(s.unlocked),
        learnedTactics=M.Copy(s.learnedTactics),learnedGroups=M.Copy(s.learnedGroups),alliances=M.Copy(s.alliances),canonicalProperties={}}
    out.hub=M.Copy(s.hub)
    for _,key in ipairs(stateFields) do out[key]=s[key] end
    for id,p in pairs(s.properties) do
        -- Untouched real places (neutral, never visited, never invested) are re-imported and
        -- re-priced every session; writing thousands of them only bloats the save.
        local untouched=p.canonical and p.owner==C.neutralId and not s.visitedProperties[id] and not p.investCount
            and p.canonicalSource~="eso_location"
        if not untouched then
            out.properties[id]={owner=p.owner,independenceRisk=p.independenceRisk,reserve=p.reserve,
                marketValue=p.marketValue,expectedProfit=p.expectedProfit,investCount=p.investCount}
            if p.canonical then
                -- Client-imported places are re-imported every session; keep only name and region
                -- for them (to follow index shifts). Places created from visits need the full record.
                if p.canonicalSource=="eso_location" then
                    local definition=M.Copy(p); definition.reserve=nil; out.canonicalProperties[id]=definition
                else out.canonicalProperties[id]={name=p.name,zone=p.zone,canonicalSource=p.canonicalSource} end
            end
        end
    end
    for id,company in pairs(s.companies) do out.companies[id]={cash=company.cash,dissolved=company.dissolved or nil} end
    return out
end
function M.Load(saved)
    if type(saved)~="table" then return M.New() end
    local moneyMigration=(saved.schemaVersion or 0)<9
    -- Saved real places whose id no longer exists (the client renumbered its map points) are
    -- matched by region and name; visit-created places are restored from their full record.
    local remap={}; local L=PBTrade.LiveCatalog
    for id,p in pairs(saved.canonicalProperties or {}) do
        if not D.propertyById[id] and D.zoneById[p.zone] then
            local match=L and L.Find(p.zone,p.name)
            if match then remap[id]=match.id
            elseif p.marketValue then
                local definition=M.Copy(p); D.properties[#D.properties+1]=definition; D.AddProperty(definition)
                if L then L.Index(definition) end
            end
        end
    end
    local function current(id) return remap[id] or id end
    local s=M.New()
    for _,key in ipairs(stateFields) do if saved[key]~=nil then s[key]=saved[key] end end
    if moneyMigration then
        if saved.cash~=nil then s.cash=C.Money(s.cash,"saved:cash") end
        if saved.debt~=nil then s.debt=C.Money(s.debt,"saved:debt") end
    end
    if s.companyName and not M.SetCompanyName(s,s.companyName) then s.companyName=nil end
    local restored={}
    for savedId,record in pairs(saved.properties or {}) do
        local id=current(savedId); local p=s.properties[id]; restored[id]=true; if p then
            if record.owner and s.companies[record.owner] then p.owner=record.owner end
            if type(record.independenceRisk)=="number" then p.independenceRisk=math.max(0,math.min(C.battle.riskMax,record.independenceRisk)) end
            if type(record.reserve)=="number" then
                local value=moneyMigration and C.Money(record.reserve,id..":reserve") or record.reserve
                p.reserve=math.max(0,value)
            end
            if type(record.marketValue)=="number" then
                local value=moneyMigration and C.Money(record.marketValue,id..":value") or record.marketValue
                p.marketValue=math.max(1,math.min(C.economy.maximumPropertyValue,value))
            end
            if type(record.investCount)=="number" then p.investCount=math.max(0,math.floor(record.investCount)) end
            if type(record.expectedProfit)=="number" then
                local value=moneyMigration and C.Money(record.expectedProfit,id..":profit") or record.expectedProfit
                p.expectedProfit=math.max(1,math.min(C.economy.maximumExpectedProfit,value))
            end
        end
    end
    for id,record in pairs(saved.companies or {}) do
        if s.companies[id] and type(record.cash)=="number" then
            local value=moneyMigration and C.Money(record.cash,id..":cash") or record.cash
            s.companies[id].cash=math.max(0,value)
        end
        if s.companies[id] and record.dissolved then s.companies[id].dissolved=true end
    end
    -- v8 introduced regional companies.  Existing player acquisitions are sacred; other
    -- generated businesses adopt the new initial owner so old campaigns gain the wider market.
    local companyMigration=(saved.schemaVersion or 0)<8 and not saved.molagTakeover
    if companyMigration then
        for _,definition in ipairs(D.properties) do
            local p=s.properties[definition.id]
            if definition.generatedName and p and p.owner~=C.playerId then p.owner=definition.owner end
        end
    end
    -- v10 moved Dophore from Stormhaven to Stros M'Kai, installed House Tamrith in
    -- Stormhaven and split High Isle between Verelois and Dufort. Preserve anything the
    -- player already bought; otherwise adopt the authored regional balance. A chapter-five
    -- Molag takeover is also preserved verbatim.
    if (saved.schemaVersion or 0)<10 and not saved.molagTakeover then
        local rebalanced={stormhaven=true,stros=true,highisle=true}
        for _,definition in ipairs(D.properties) do
            local p=s.properties[definition.id]
            if definition.generatedName and rebalanced[definition.zone] and p and p.owner~=C.playerId then
                p.owner=definition.owner
            end
        end
    end
    for _,key in ipairs({"visited","visitedProperties","unlocked","learnedTactics","learnedGroups","alliances"}) do if type(saved[key])=="table" then s[key]=M.Copy(saved[key]) end end
    -- v10 introduced the promised Fullbright alliance. Saves already beyond the chapter-one
    -- transition receive it on load if the company still exists; dissolved companies stay gone.
    if (saved.schemaVersion or 0)<10 and s.chapter>=2 then M.FormChapterTwoAlliance(s) end
    for oldId,newId in pairs(remap) do if s.visitedProperties[oldId] then s.visitedProperties[oldId]=nil; s.visitedProperties[newId]=true end end
    -- Real places new to this save, and (once per valuation version) the ones saved under an
    -- older pricing rule, are priced from today's average property.
    local reprice=(saved.canonicalValuation or 0)<C.canonical.version
    local average
    for id,p in pairs(s.properties) do
        if p.canonical and (not restored[id] or reprice) then
            average=average or M.MarketAverage(s); M.PriceCanonical(s,p,average)
        end
    end
    s.canonicalValuation=C.canonical.version
    s.hub=PBTrade.Hub.Load(saved.hub,s.cycles,s.chapter)
    s.learnedTactics.smile=true; s.schemaVersion=C.schemaVersion; M.Unlock(s)
    if companyMigration then M.CheckTakeovers(s) end
    return s
end
-- One decision per offensive battle cycle. Defense settlement does not recurse.
function M.RollCounterattack(s,random)
    local owned=M.Owned(s)
    if #owned==0 then return nil,"防衛対象の物件がありません" end
    local candidates,total={},0
    -- Sort IDs so the same RNG sequence is deterministic on Lua implementations.
    local ids={}; for id in pairs(s.companies) do ids[#ids+1]=id end; table.sort(ids)
    for _,id in ipairs(ids) do
        local c=s.companies[id]
        -- Allies never raise a hostile bid against the player.
        if id~=C.playerId and id~=C.neutralId and not M.IsAllied(s,id) and (c.minChapter or 1)<=s.chapter and c.cash>=C.counterattack.minimumCash and #M.Owned(s,id)>0 then
            local _,reserves=M.CompanyAssets(s,id)
            local funding=c.cash+reserves
            -- Serious attacks come disproportionately from companies that can actually finance
            -- them, while aggression still distinguishes personalities at equal strength.
            local weight=(c.aggression or .5)*math.sqrt(math.max(1,funding/C.counterattack.minimumCash))
            total=total+weight
            candidates[#candidates+1]={id=id,company=c,weight=weight,funding=funding,aggression=c.aggression or .5}
        end
    end
    if total<=0 then return nil,"敵商会は攻撃資金を準備できませんでした" end
    local pick=random()*total; local selected=candidates[#candidates]
    for _,candidate in ipairs(candidates) do pick=pick-candidate.weight; if pick<0 then selected=candidate; break end end
    local chapterRule=C.counterattack.chapter[s.chapter] or C.counterattack.chapter[#C.counterattack.chapter]
    local chance=math.min(C.counterattack.maxChance,C.counterattack.baseChance+(selected.company.aggression or .5)*C.counterattack.aggressionWeight+(chapterRule.chance or 0))
    local policy,event=M.ActivePolicy(s),M.ActiveMarketEvent(s)
    chance=chance*(policy and policy.counterattackMultiplier or 1)*(event and event.counterattackMultiplier or 1)
    chance=math.min(C.counterattack.maxChance,chance)
    local portfolioFactor=math.min(1,C.counterattack.portfolioChanceFloor+math.max(0,#owned-1)*C.counterattack.portfolioChanceStep)
    chance=chance*portfolioFactor
    -- A guard contract from domestic affairs halves the odds while it lasts.
    if (s.guardPeriods or 0)>0 then chance=chance*C.admin.guardChanceFactor end
    -- A sabotage scandal makes rivals bolder until the next settlement.
    if (s.scandalPeriods or 0)>0 then chance=math.min(C.counterattack.maxChance,chance*C.admin.scandalChanceFactor) end
    if random()>=chance then return nil,"今回は敵商会からの買収攻撃はありませんでした" end
    local source
    for _,p in ipairs(M.Owned(s,selected.id)) do
        if not source or (p.isHeadquarters and not source.isHeadquarters)
            or (p.isHeadquarters==source.isHeadquarters and p.marketValue>source.marketValue) then source=p end
    end
    local attackable={}
    for _,p in ipairs(owned) do
        if M.IsAvailable(s,p) and s.unlocked[p.zone] then attackable[#attackable+1]=p end
    end
    if #attackable==0 then return nil,"現在の交易圏に攻撃可能な自社物件がありません" end
    local best,score,maxValue
    for _,p in ipairs(attackable) do maxValue=math.max(maxValue or 0,p.marketValue) end
    for _,p in ipairs(attackable) do
        local value=random()+p.independenceRisk/C.battle.riskMax*C.counterattack.riskWeight
        if p.category==selected.company.acquisitionBias then value=value+selected.aggression end
        if p.isHeadquarters then value=value+C.counterattack.headquartersWeight end
        value=value+(p.marketValue/math.max(1,maxValue))*C.counterattack.valueWeight
        if not score or value>score then best,score=p,value end
    end
    return {companyId=selected.id,propertyId=best.id,sourcePropertyId=source.id,chance=chance,
        threat=chapterRule.label,chapter=s.chapter,funding=selected.funding},
        selected.company.name.."が"..best.name.."への買収を仕掛けました（"..chapterRule.label.."）"
end
