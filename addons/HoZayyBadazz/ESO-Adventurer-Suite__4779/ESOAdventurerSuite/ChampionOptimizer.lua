local EPC = ESOProgressionCoach
EPC.ChampionOptimizer = EPC.ChampionOptimizer or {}
local C = EPC.ChampionOptimizer

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok,a,b,c,d,e = pcall(fn,...)
    if not ok then return fallback end
    return a,b,c,d,e
end
local function num(fn, fallback, ...)
    local v=safe(fn,fallback,...); return tonumber(v) or fallback
end
local function lower(s) return string.lower(tostring(s or "")) end
local function has(text, words)
    text=lower(text)
    for _,w in ipairs(words or {}) do if string.find(text,w,1,true) then return true end end
    return false
end

local LABELS={}
local function disciplineLabel(t)
    if t==rawget(_G,"CHAMPION_DISCIPLINE_TYPE_WORLD") then return "CRAFT" end
    if t==rawget(_G,"CHAMPION_DISCIPLINE_TYPE_COMBAT") then return "WARFARE" end
    if t==rawget(_G,"CHAMPION_DISCIPLINE_TYPE_CONDITIONING") then return "FITNESS" end
    return "CHAMPION"
end

local EnrichChampionContext029174
local ApplyMaxPowerScore029174
local NotifyMaxPowerChampion029174

function C:GetContext()
    local profile=EPC.GearOptimizer and EPC.GearOptimizer.GetProfile and EPC.GearOptimizer:GetProfile() or {}
    local plan=EPC.GearOptimizer and EPC.GearOptimizer.BuildFullSkillPlan and EPC.GearOptimizer:BuildFullSkillPlan() or nil
    local role=plan and plan.context and plan.context.role or "DAMAGE"
    local context={ profile=profile or {}, role=tostring(role or "DAMAGE") }
    if EnrichChampionContext029174 then return EnrichChampionContext029174(self, context) end
    return context
end

function C:ScoreSkill(node, context)
    local name=lower(node.name); local desc=lower(node.desc); local text=name.." "..desc
    local score=0
    local label=disciplineLabel(node.disciplineType)
    local role=lower(context.role)
    local magicka=context.profile and context.profile.magicka==true

    if node.isRoot then score=score+35 end
    if node.slottable then score=score+120 end

    if label=="WARFARE" then
        if has(text,{"critical damage","critical healing","critical chance"}) then score=score+240 end
        if has(text,{"damage done","direct damage","damage over time","single target","area of effect"}) then score=score+210 end
        if magicka and has(text,{"magicka","spell"}) then score=score+95 end
        if (not magicka) and has(text,{"stamina","weapon"}) then score=score+95 end
        if role=="healer" then
            if has(text,{"healing done","healing received","heal","restoration"}) then score=score+330 end
            if has(text,{"damage done","direct damage"}) then score=score-80 end
        elseif role=="tank" then
            if has(text,{"damage taken","block","resistance","shield","mitigation"}) then score=score+320 end
            if has(text,{"healing received"}) then score=score+120 end
        else
            if has(text,{"damage done","critical damage","direct damage","damage over time","single target","area of effect"}) then score=score+180 end
        end
    elseif label=="FITNESS" then
        if has(text,{"max health","health","armor","resistance","damage taken"}) then score=score+150 end
        if has(text,{"movement speed","sprint","roll dodge","break free","block","recovery"}) then score=score+135 end
        if role=="tank" and has(text,{"block","health","resistance","damage taken","shield"}) then score=score+260 end
        if role=="healer" and has(text,{"magicka","recovery","health"}) then score=score+120 end
        if role=="damage" and has(text,{"movement speed","stamina","magicka","recovery"}) then score=score+100 end
    elseif label=="CRAFT" then
        if has(text,{"movement speed","out of combat","mount","riding"}) then score=score+210 end
        if has(text,{"gold","treasure","chest","loot","harvest","resource","gather"}) then score=score+190 end
        if has(text,{"craft","inspiration","research","deconstruct","refine","repair"}) then score=score+145 end
        if has(text,{"fall damage","stealth","pickpocket"}) then score=score+55 end
    end
    if ApplyMaxPowerScore029174 then score=ApplyMaxPowerScore029174(self,node,context,score) end
    return score
end

function C:CollectNodes()
    local nodes,byId={},{}
    local count=num(GetNumChampionDisciplines,0)
    for di=1,count do
        local disciplineId=num(GetChampionDisciplineId,0,di)
        local dtype=safe(GetChampionDisciplineType,nil,disciplineId)
        local nskills=num(GetNumChampionDisciplineSkills,0,di)
        for si=1,nskills do
            local id=num(GetChampionSkillId,0,di,si)
            if id>0 then
                local maxp=num(GetChampionSkillMaxPoints,0,id)
                local minUnlock=maxp>0 and maxp or 0
                if maxp>0 and type(WouldChampionSkillNodeBeUnlocked)=="function" then
                    for p=0,maxp do if safe(WouldChampionSkillNodeBeUnlocked,false,id,p)==true then minUnlock=p break end end
                    if minUnlock==0 and not safe(IsChampionSkillRootNode,false,id) then minUnlock=1 end
                end
                local st=safe(GetChampionSkillType,nil,id)
                local slottable=type(CanChampionSkillTypeBeSlotted)=="function" and safe(CanChampionSkillTypeBeSlotted,false,st)==true
                local node={id=id,disciplineIndex=di,disciplineId=disciplineId,disciplineType=dtype,name=tostring(safe(GetChampionSkillName,"Champion Star",id) or "Champion Star"),desc=tostring(safe(GetChampionSkillDescription,"",id,math.max(1,minUnlock)) or ""),maxPoints=maxp,minUnlock=minUnlock,isRoot=safe(IsChampionSkillRootNode,false,id)==true,slottable=slottable,links={},saved=num(GetNumPointsSpentOnChampionSkill,0,id)}
                nodes[#nodes+1]=node; byId[id]=node
            end
        end
    end
    for _,node in ipairs(nodes) do
        if type(GetChampionSkillLinkIds)=="function" then
            local vals={GetChampionSkillLinkIds(node.id)}
            for _,v in ipairs(vals) do if tonumber(v) and byId[tonumber(v)] then node.links[#node.links+1]=tonumber(v) end end
        end
    end
    return nodes,byId
end

local function pathToRoot(target, byId)
    if target.isRoot then return {target} end
    local q, seen = {{target.id}}, {[target.id]=true}
    while #q>0 do
        local path=table.remove(q,1); local node=byId[path[#path]]
        if node then
            for _,lid in ipairs(node.links or {}) do
                if not seen[lid] then
                    seen[lid]=true; local np={}; for i,v in ipairs(path) do np[i]=v end; np[#np+1]=lid
                    local ln=byId[lid]
                    if ln and ln.isRoot then
                        local out={}; for i=#np,1,-1 do out[#out+1]=byId[np[i]] end; return out
                    end
                    q[#q+1]=np
                end
            end
        end
    end
    return {target}
end

-- BuildPlan/BuildView are defined once below by the MAX POWER optimizer.

function C:Notify(msg,good)
    if EPC.GearOptimizer and EPC.GearOptimizer.NotifyResult then EPC.GearOptimizer:NotifyResult(msg,good) elseif d then d("[ESO Adventurer Suite] "..msg) end
end

function C:_ApplyBestChampionBuildNow()
    if self.Initialize then self:Initialize() end
    if safe(IsUnitInCombat,false,"player")==true then self:Notify("CHAMPION: leave combat before redistributing points.",false) return false end
    if type(IsChampionSystemUnlocked)=="function" and not safe(IsChampionSystemUnlocked,false) then self:Notify("CHAMPION: Champion progression is not unlocked yet.",false) return false end
    if type(PrepareChampionPurchaseRequest)~="function" or type(AddSkillToChampionPurchaseRequest)~="function" or type(SendChampionPurchaseRequest)~="function" then self:Notify("CHAMPION: this ESO client does not expose the Champion allocation API.",false) return false end
    local cost=num(GetChampionRespecCost,0)
    if cost>0 and self._costConfirmed~=true then
        local dialogName="EAS_CONFIRM_CHAMPION_REDISTRIBUTE"
        if type(ZO_Dialogs_RegisterCustomDialog)=="function" and type(ZO_Dialogs_ShowDialog)=="function" then
            if not self._confirmDialogRegistered then
                ZO_Dialogs_RegisterCustomDialog(dialogName,
                {
                    title={text="CONFIRM CHAMPION REDISTRIBUTION"},
                    mainText={text="Apply the best detected Champion Point build? ESO will charge the current respec cost shown in the Champion system."},
                    buttons={
                        {text=SI_DIALOG_CONFIRM, callback=function()
                            self._costConfirmed=true
                            self:_ApplyBestChampionBuildNow()
                        end},
                        {text=SI_DIALOG_CANCEL, callback=function()
                            self._costConfirmed=nil
                            self:Notify("CHAMPION: redistribution cancelled. No points were changed.",false)
                        end},
                    },
                })
                self._confirmDialogRegistered=true
            end
            self:Notify(string.format("CHAMPION: best-build plan ready. Confirm the %d gold redistribution in the dialog.",cost),true)
            ZO_Dialogs_ShowDialog(dialogName)
            return true
        end
        self:Notify(string.format("CHAMPION: %d gold respec requires confirmation, but the dialog API is unavailable. No changes were submitted.",cost),false)
        return false
    end
    self._costConfirmed=nil
    local plan=self:BuildPlan()
    local ok=pcall(PrepareChampionPurchaseRequest,true); if not ok then self:Notify("CHAMPION: ESO would not start a Champion respec request here.",false) return false end
    -- A true respec request must describe the complete target state.
    -- Send every node, including zero-point targets, so old allocations are removed
    -- instead of only adding the new recommendations on top of them.
    for _,node in ipairs(plan.nodes) do
        local pool=plan.pools[node.disciplineId]
        local target=pool and (pool.alloc[node.id] or 0) or 0
        pcall(AddSkillToChampionPurchaseRequest,node.id,target)
    end
    if type(AddHotbarSlotToChampionPurchaseRequest)=="function" and HOTBAR_CATEGORY_CHAMPION~=nil then
        local startSlot,endSlot=1,12
        if type(GetAssignableChampionBarStartAndEndSlots)=="function" then local a,b=safe(GetAssignableChampionBarStartAndEndSlots,nil); startSlot=tonumber(a) or startSlot; endSlot=tonumber(b) or endSlot end
        local nextByDiscipline={}
        for slot=startSlot,endSlot do
            local reqId=type(GetRequiredChampionDisciplineIdForSlot)=="function" and num(GetRequiredChampionDisciplineIdForSlot,0,slot,HOTBAR_CATEGORY_CHAMPION) or 0
            local p=plan.pools[reqId]
            if p then
                nextByDiscipline[reqId]=(nextByDiscipline[reqId] or 0)+1
                local n=p.slots[nextByDiscipline[reqId]]
                pcall(AddHotbarSlotToChampionPurchaseRequest,slot,n and n.id or 0)
            else
                pcall(AddHotbarSlotToChampionPurchaseRequest,slot,0)
            end
        end
    end
    local expected=type(GetExpectedResultForChampionPurchaseRequest)=="function" and safe(GetExpectedResultForChampionPurchaseRequest,nil) or nil
    local successConst=rawget(_G,"CHAMPION_PURCHASE_SUCCESS")
    if expected~=nil and successConst~=nil and expected~=successConst then self:Notify("CHAMPION: ESO reports the planned Champion allocation is not currently valid (result "..tostring(expected)..").",false) return false end
    if cost > 0 and EPC.Activities and type(EPC.Activities.SetPendingGoldSpend) == "function" then
        EPC.Activities:SetPendingGoldSpend("respec", cost)
    end
    local sent=pcall(SendChampionPurchaseRequest)
    if not sent then
        if EPC.Activities and type(EPC.Activities.ClearPendingGoldSpend) == "function" then
            EPC.Activities:ClearPendingGoldSpend("respec")
        end
        self:Notify("CHAMPION: ESO rejected the Champion respec request.",false)
        return false
    end
    self:Notify(string.format("CHAMPION: best-build redistribution submitted for Craft, Warfare, and Fitness. Respec cost: %d gold.",cost),true)
    if EPC.RequestRefresh then EPC:RequestRefresh("champion-respec") end
    return true
end


function C:ApplyBestChampionBuild()
    if NotifyMaxPowerChampion029174 then NotifyMaxPowerChampion029174(self) end
    if safe(IsUnitInCombat,false,"player")==true then self:Notify("CHAMPION: leave combat before redistributing points.",false) return false end
    if EPC and EPC.RefreshNow then EPC:RefreshNow("pre-champion-redistribute") end
    if EPC and EPC.Journal and EPC.Journal.window and not EPC.Journal.window:IsHidden() and type(EPC.Journal.Hide)=="function" then
        EPC.Journal:Hide()
    end
    if SCENE_MANAGER and type(SCENE_MANAGER.Show)=="function" then
        local shown=false
        for _,sceneName in ipairs({"championPerks","champion"}) do
            local ok=pcall(function() SCENE_MANAGER:Show(sceneName) end)
            if ok then shown=true break end
        end
    end
    self:Notify("CHAMPION: opening Champion and preparing the best detected allocation...",true)
    if type(zo_callLater)=="function" then
        zo_callLater(function() self:_ApplyBestChampionBuildNow() end,250)
        return true
    end
    return self:_ApplyBestChampionBuildNow()
end


function C:Initialize()
    if self._eventReady or not EVENT_MANAGER or not EVENT_CHAMPION_PURCHASE_RESULT then return end
    self._eventReady=true
    EVENT_MANAGER:RegisterForEvent("ESOAdventurerSuite_ChampionOptimizer", EVENT_CHAMPION_PURCHASE_RESULT, function(_, result)
        local success=rawget(_G,"CHAMPION_PURCHASE_SUCCESS")
        if success~=nil and result==success then
            -- EVENT_MONEY_UPDATE normally consumes the pending cost first. If ESO
            -- does not emit a usable money reason/update, commit the confirmed cost
            -- shortly after the successful Champion purchase result instead.
            if EPC.Activities and type(EPC.Activities.CommitPendingGoldSpend) == "function" and type(zo_callLater) == "function" then
                zo_callLater(function()
                    if EPC.Activities then EPC.Activities:CommitPendingGoldSpend("respec") end
                end, 500)
            elseif EPC.Activities and type(EPC.Activities.CommitPendingGoldSpend) == "function" then
                EPC.Activities:CommitPendingGoldSpend("respec")
            end
            C:Notify("CHAMPION: redistribution completed. Craft, Warfare, and Fitness were rebuilt.",true)
        else
            if EPC.Activities and type(EPC.Activities.ClearPendingGoldSpend) == "function" then
                EPC.Activities:ClearPendingGoldSpend("respec")
            end
            C:Notify("CHAMPION: ESO rejected the redistribution (result "..tostring(result).."). No success was reported.",false)
        end
        if EPC.RequestRefresh then EPC:RequestRefresh("champion-purchase-result") end
    end)
end

-- v0.29.174 - MAX POWER Champion optimizer.
-- Scores CP against the skill build RESPEC + BUILD actually plans, current role,
-- current content, and personal penetration need. Allocation is incremental with
-- diminishing returns instead of filling one high-keyword node to cap first.
EnrichChampionContext029174 = function(self,base)
    base=base or {}
    local g=EPC.GearOptimizer
    local buildContext=g and type(g.GetWornBuildContext)=="function" and g:GetWornBuildContext() or {}
    local skillPlan=g and type(g.BuildFullSkillPlan)=="function" and g:BuildFullSkillPlan() or nil
    local skillProfile=g and type(g.AnalyzeSkillPlan029174)=="function" and g:AnalyzeSkillPlan029174(skillPlan) or {directShare=.5,dotShare=.5,aoeShare=.35,singleShare=.65,total=0}
    base.profile=buildContext.profile or base.profile or {}
    base.role=tostring(buildContext.role or base.role or "DAMAGE")
    base.mode=buildContext.maxPowerMode or (g and g.ResolveMaxPowerMode029174 and g:ResolveMaxPowerMode029174()) or "SOLO"
    base.modeLabel=buildContext.maxPowerLabel or base.mode
    base.archetype=buildContext.archetype or base.role
    base.power=buildContext.power or {}
    base.penGap=tonumber(buildContext.penGap) or 0
    base.penTarget=tonumber(buildContext.personalPenTarget) or 0
    base.personalPen=tonumber(buildContext.personalPen) or 0
    base.skillProfile=skillProfile
    return base
end

ApplyMaxPowerScore029174 = function(self,node,context,score)
    context=context or self:GetContext()
    score=tonumber(score) or 0
    local text=lower(node.name).." "..lower(node.desc)
    local label=disciplineLabel(node.disciplineType)
    local role=lower(context.role)
    local mode=tostring(context.mode or "SOLO")
    local sp=context.skillProfile or {}

    if label=="WARFARE" then
        if role=="damage" or role=="dps" then
            if has(text,{"direct damage"}) then score=score+math.floor(620*(tonumber(sp.directShare) or .5)) end
            if has(text,{"damage over time"}) then score=score+math.floor(620*(tonumber(sp.dotShare) or .5)) end
            if has(text,{"area of effect"}) then score=score+math.floor(620*(tonumber(sp.aoeShare) or .35)) end
            if has(text,{"single target"}) then score=score+math.floor(620*(tonumber(sp.singleShare) or .65)) end
            if has(text,{"weapon and spell damage","damage done"}) then score=score+410 end
            if has(text,{"critical damage"}) then
                score=score+(mode=="TRIAL_BOSS" and 250 or 430)
            end
            if has(text,{"offensive penetration","penetration"}) then
                local gap=tonumber(context.penGap) or 0
                if gap<=0 then score=score-500 else score=score+math.min(650,math.floor(gap/18)) end
            end
            if has(text,{"off balance"}) then score=score+(mode=="TRIAL_BOSS" and 310 or 180) end
            if mode=="AOE_TRASH" and has(text,{"area of effect"}) then score=score+420 end
            if mode=="TRIAL_BOSS" and has(text,{"single target","direct damage"}) then score=score+180 end
            if mode=="INFINITE_ARCHIVE" and has(text,{"healing received","damage taken","shield"}) then score=score+120 end
        elseif role=="healer" then
            if has(text,{"healing done","heal over time","area of effect healing","single target healing","critical healing"}) then score=score+620 end
            if has(text,{"damage shield","healing received"}) then score=score+240 end
            if has(text,{"weapon and spell damage"}) then score=score+120 end
        elseif role=="tank" then
            if has(text,{"damage taken","direct damage taken","damage over time taken","area of effect damage taken","single target damage taken"}) then score=score+650 end
            if has(text,{"block","armor","resistance","damage shield"}) then score=score+560 end
            if has(text,{"healing received"}) then score=score+280 end
        end
    elseif label=="FITNESS" then
        if role=="tank" then
            if has(text,{"max health","armor","block","damage taken","healing received","shield"}) then score=score+560 end
            if has(text,{"stamina recovery","magicka recovery","restore stamina","restore magicka"}) then score=score+330 end
        elseif role=="healer" then
            if has(text,{"max health","magicka recovery","recovery","movement speed","break free"}) then score=score+320 end
        else
            if mode=="INFINITE_ARCHIVE" then
                if has(text,{"max health","armor","damage taken","healing received","recovery"}) then score=score+430 end
            elseif mode=="PVP" then
                if has(text,{"max health","armor","break free","roll dodge","sprint","movement speed","recovery"}) then score=score+430 end
            else
                if has(text,{"movement speed","recovery","restore magicka","restore stamina"}) then score=score+260 end
                if has(text,{"max health","armor"}) then score=score+120 end
            end
        end
    elseif label=="CRAFT" then
        -- Combat power is unaffected by Craft CP, so optimize the run economy and
        -- time saved: faster movement/gathering plus potion/food/treasure utility.
        if has(text,{"food","drink","potion","treasure chest","movement speed","mount speed","harvest","gather"}) then score=score+330 end
        if mode=="INFINITE_ARCHIVE" and has(text,{"potion","food","drink","movement speed"}) then score=score+180 end
    end

    -- Nodes that need a slot must justify one of only four active slots. Passive
    -- nodes are always-on, so they get a small efficiency advantage when close.
    if node.slottable then score=score+80 else score=score+55 end
    return math.max(-10000,score)
end

local function easChampionCandidatePathCost029174(target,p,byId)
    local path=pathToRoot(target,byId)
    local cost=0
    for _,n in ipairs(path or {}) do
        local want=math.max(0,tonumber(n.minUnlock) or 0)
        local old=tonumber(p.alloc[n.id]) or 0
        if want>old then cost=cost+(want-old) end
    end
    if cost==0 and (tonumber(p.alloc[target.id]) or 0)<(tonumber(target.maxPoints) or 0) then cost=1 end
    return cost,path
end

local function easChampionAllocateStep029174(target,p,byId)
    local before=p.spent
    local _,path=easChampionCandidatePathCost029174(target,p,byId)
    for _,n in ipairs(path or {}) do
        local want=math.max(0,tonumber(n.minUnlock) or 0)
        local old=tonumber(p.alloc[n.id]) or 0
        local add=math.min(math.max(0,p.budget-p.spent),math.max(0,want-old))
        if add>0 then p.alloc[n.id]=old+add; p.spent=p.spent+add end
    end
    if p.spent<p.budget then
        local cur=tonumber(p.alloc[target.id]) or 0
        local maxp=tonumber(target.maxPoints) or 0
        if cur<maxp and p.spent==before then
            p.alloc[target.id]=cur+1
            p.spent=p.spent+1
        end
    end
    return p.spent-before
end

function C:BuildPlan()
    local context=self:GetContext()
    local nodes,byId=self:CollectNodes()
    local plan={context=context,nodes=nodes,byId=byId,pools={},targets={},slotted={}}
    for _,node in ipairs(nodes) do
        local p=plan.pools[node.disciplineId]
        if not p then
            p={disciplineId=node.disciplineId,disciplineType=node.disciplineType,label=disciplineLabel(node.disciplineType),budget=num(GetNumSpentChampionPoints,0,node.disciplineId)+num(GetNumUnspentChampionPoints,0,node.disciplineId),spent=0,alloc={},ranked={},selectedSlottables={},candidateTargets={}}
            plan.pools[node.disciplineId]=p
        end
        node.score=self:ScoreSkill(node,context)
        p.ranked[#p.ranked+1]=node
    end

    for _,p in pairs(plan.pools) do
        table.sort(p.ranked,function(a,b) if a.score==b.score then return a.name<b.name end return a.score>b.score end)

        -- Pick only four slottable destinations. Spending deep into a fifth active
        -- star is dead power because ESO cannot slot it at the same time.
        for _,n in ipairs(p.ranked) do
            if n.slottable and n.score>0 and #p.selectedSlottables<4 then
                p.selectedSlottables[#p.selectedSlottables+1]=n
                n._maxPowerSlot029174=true
            end
        end

        -- All chosen slottables plus the strongest always-on passives compete for
        -- points. Prerequisite nodes are paid automatically only when a target is
        -- worth reaching.
        local passiveCount=0
        for _,n in ipairs(p.ranked) do
            if n._maxPowerSlot029174 then
                p.candidateTargets[#p.candidateTargets+1]=n
            elseif not n.slottable and n.score>0 and passiveCount<18 then
                passiveCount=passiveCount+1
                p.candidateTargets[#p.candidateTargets+1]=n
            end
        end

        local guard=0
        while p.spent<p.budget and guard<5000 do
            guard=guard+1
            local best,bestEfficiency=nil,-1e30
            for _,n in ipairs(p.candidateTargets) do
                local cur=tonumber(p.alloc[n.id]) or 0
                local maxp=tonumber(n.maxPoints) or 0
                if cur<maxp then
                    local cost=easChampionCandidatePathCost029174(n,p,byId)
                    if cost>0 and p.spent+cost<=p.budget then
                        local frac=maxp>0 and (cur/maxp) or 0
                        local decay=n.slottable and (1-0.35*frac) or (1-0.58*frac)
                        local slotBoost=n._maxPowerSlot029174 and 1.22 or 1.0
                        local efficiency=(tonumber(n.score) or 0)*decay*slotBoost/math.max(1,cost)
                        if efficiency>bestEfficiency then best,bestEfficiency=n,efficiency end
                    end
                end
            end
            if not best then break end
            if easChampionAllocateStep029174(best,p,byId)<=0 then break end
        end

        -- v0.29.175 - Exhaust every legally spendable point.
        -- The 0.29.174 remainder pass only searched candidateTargets. If those
        -- stars were capped (or the next candidate path cost more than the small
        -- remainder), legal points could be left unused. Search the whole tree
        -- for the best legal next destination until the discipline pool is empty.
        local function spendRemainder029175(allowUnselectedSlottable)
            local guard=0
            while p.spent<p.budget and guard<5000 do
                guard=guard+1
                local best,bestValue=nil,-1e30
                for _,n in ipairs(p.ranked) do
                    local cur=tonumber(p.alloc[n.id]) or 0
                    local maxp=tonumber(n.maxPoints) or 0
                    local selected=(n._maxPowerSlot029174==true)
                    if cur<maxp and (allowUnselectedSlottable or not n.slottable or selected) then
                        local cost=easChampionCandidatePathCost029174(n,p,byId)
                        if cost>0 and p.spent+cost<=p.budget then
                            local value=tonumber(n.score) or 0
                            -- Prefer always-on passives and stars we are already
                            -- investing in. Unselected slottables are a true last
                            -- resort because points there provide no active power.
                            if not n.slottable then value=value+1800 end
                            if selected then value=value+1500 end
                            if cur>0 then value=value+2600 end
                            if n.isRoot then value=value+350 end
                            value=value/math.max(1,cost)
                            if value>bestValue then best,bestValue=n,value end
                        end
                    end
                end
                if not best then break end
                if easChampionAllocateStep029174(best,p,byId)<=0 then break end
            end
        end

        if p.spent<p.budget then spendRemainder029175(false) end
        -- Absolute fallback: if ESO's tree topology leaves only an unselected
        -- slottable able to accept the final few points, spend there rather than
        -- silently leaving spendable CP unused. This does not slot that fifth star.
        if p.spent<p.budget then spendRemainder029175(true) end
        p.unspent=math.max(0,p.budget-p.spent)

        p.slots={}
        table.sort(p.selectedSlottables,function(a,b) return (tonumber(a.score) or 0)>(tonumber(b.score) or 0) end)
        for _,n in ipairs(p.selectedSlottables) do
            if (tonumber(p.alloc[n.id]) or 0)>0 and #p.slots<4 then p.slots[#p.slots+1]=n end
        end
    end
    return plan
end

function C:BuildView()
    local plan=self:BuildPlan()
    local view={cost=num(GetChampionRespecCost,0),pools={},context=plan.context,mode=plan.context.modeLabel or plan.context.mode,archetype=plan.context.archetype,skillProfile=plan.context.skillProfile,penetration={current=plan.context.personalPen or 0,target=plan.context.penTarget or 0,gap=plan.context.penGap or 0}}
    for _,p in pairs(plan.pools) do
        local row={label=p.label,budget=p.budget,spent=p.spent,unspent=math.max(0,(tonumber(p.budget) or 0)-(tonumber(p.spent) or 0)),top={},slots={}}
        for _,n in ipairs(p.ranked) do
            if (p.alloc[n.id] or 0)>0 and #row.top<8 then row.top[#row.top+1]={name=n.name,points=p.alloc[n.id],slottable=n.slottable,score=n.score} end
        end
        for _,n in ipairs(p.slots or {}) do row.slots[#row.slots+1]={name=n.name,points=p.alloc[n.id] or 0,score=n.score} end
        view.pools[#view.pools+1]=row
    end
    table.sort(view.pools,function(a,b) local o={CRAFT=1,WARFARE=2,FITNESS=3}; return (o[a.label] or 9)<(o[b.label] or 9) end)
    return view
end

NotifyMaxPowerChampion029174 = function(self)
    local ctx=self:GetContext()
    local sp=ctx.skillProfile or {}
    self:Notify(string.format("MAX POWER CP: %s | %s | Direct %.0f%% / DoT %.0f%% | AoE %.0f%% / Single %.0f%% | Pen %d/%d",tostring(ctx.archetype or ctx.role or "BUILD"),tostring(ctx.modeLabel or ctx.mode or "AUTO"),(tonumber(sp.directShare) or 0)*100,(tonumber(sp.dotShare) or 0)*100,(tonumber(sp.aoeShare) or 0)*100,(tonumber(sp.singleShare) or 0)*100,tonumber(ctx.personalPen) or 0,tonumber(ctx.penTarget) or 0),true)
end
