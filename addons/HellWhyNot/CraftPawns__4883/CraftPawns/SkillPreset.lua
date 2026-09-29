local CAM = CraftPawns
CAM.SkillPreset = {}
local SP = CAM.SkillPreset

-- Ability names are resolved against live skill-line data, avoiding volatile
-- numeric indices. Target ranks are centralized here.
SP.definition = {
    ["Alchemy"] = { ["Solvent Proficiency"]=8 },
    ["Blacksmithing"] = { ["Metalworking"]=10, ["Metallurgy"]=4, ["Miner Hireling"]=3 },
    ["Clothing"] = { ["Tailoring"]=10, ["Stitching"]=4, ["Outfitter Hireling"]=3 },
    ["Enchanting"] = { ["Potency Improvement"]=10, ["Enchanter Hireling"]=3 },
    ["Jewelry Crafting"] = { ["Engraver"]=5, ["Lapidary Research"]=4 },
    ["Provisioning"] = { ["Recipe Improvement"]=6, ["Forager Hireling"]=3 },
    ["Woodworking"] = { ["Woodworking"]=10, ["Carpentry"]=4, ["Lumberjack Hireling"]=3 },
}

SP.researchPassives = {
    ["Metallurgy"]=true, ["Stitching"]=true,
    ["Carpentry"]=true, ["Lapidary Research"]=true,
}

-- Rank one of each primary crafting proficiency is granted for free. The
-- preset totals are paid points: 52 primary + 15 hireling + 16 research.
SP.freeFirstRank = {
    ["Solvent Proficiency"]=true, ["Metalworking"]=true,
    ["Tailoring"]=true, ["Potency Improvement"]=true,
    ["Engraver"]=true, ["Recipe Improvement"]=true,
    ["Woodworking"]=true,
}

local function paidRanks(name,rank)
    rank=tonumber(rank) or 0
    return math.max(0,rank-(SP.freeFirstRank[name] and 1 or 0))
end

function SP:Scan()
    local result = { required={}, allocated=0, configuredCost=0, missing=0, found={} }
    local maxSkillType = tonumber(SKILL_TYPE_MAX_VALUE) or 8
    for skillType = 1, maxSkillType do
        for lineIndex = 1, GetNumSkillLines(skillType) do
            local lineName = GetSkillLineInfo(skillType, lineIndex)
            local wanted = self.definition[lineName]
            if wanted then
                for abilityIndex = 1, GetNumSkillAbilities(skillType, lineIndex) do
                    local name, _, _, passive, _, purchased, progressionIndex, rank = GetSkillAbilityInfo(skillType, lineIndex, abilityIndex)
                    local target = wanted[name]
                    if target and passive then
                        -- The API can return a rank descriptor even when the
                        -- passive is not purchased. Never count it unless the
                        -- purchased flag is true.
                        rank = purchased and (tonumber(rank) or 1) or 0
                        local currentCost,targetCost=paidRanks(name,rank),paidRanks(name,target)
                        local item = { line=lineName, name=name, current=currentCost, target=targetCost,
                            currentRank=rank, targetRank=target,
                            skillType=skillType, lineIndex=lineIndex, abilityIndex=abilityIndex,
                            progressionIndex=progressionIndex }
                        item.category = self.researchPassives[name] and "research" or "core"
                        result.required[#result.required+1] = item
                        result.found[lineName.."\0"..name]=true
                        result.configuredCost = result.configuredCost + targetCost
                        result.allocated = result.allocated + math.min(currentCost,targetCost)
                        result.missing = result.missing + math.max(0,targetCost-currentCost)
                    end
                end
            end
        end
    end
    -- Never report completion if a renamed/unresolved required ability was
    -- omitted from the live scan.
    for lineName,wanted in pairs(self.definition) do
        for name,targetRank in pairs(wanted) do
            if not result.found[lineName.."\0"..name] then
                local targetCost=paidRanks(name,targetRank)
                result.required[#result.required+1]={line=lineName,name=name,current=0,target=targetCost,currentRank=0,targetRank=targetRank,unresolved=true,category=self.researchPassives[name] and "research" or "core"}
                result.configuredCost=result.configuredCost+targetCost
                result.missing=result.missing+targetCost
            end
        end
    end
    result.expectedCost = CAM.expectedPresetCost
    return result
end

function SP:IsResearchComplete(snapshot)
    for _, craftType in ipairs(CAM.RESEARCH_CRAFTS) do
        local research = snapshot.research and snapshot.research[craftType]
        if not research or not CAM.ResearchPlanner:IsComplete(research) then return false end
    end
    return true
end

-- Readiness is based on whether every relevant required rank is owned or can
-- be bought with currently unspent points. Total lifetime skill points do not
-- matter. Research passives stop being requirements after all research ends.
function SP:GetReadiness(snapshot)
    local complete = self:IsResearchComplete(snapshot)
    local allocated = 0
    for _, item in ipairs(snapshot.skillBuild.required or {}) do
        if not (complete and (item.category == "research" or self.researchPassives[item.name])) then
            allocated = allocated + math.min(item.current, item.target)
        end
    end
    local unspent = snapshot.unspentPoints or 0
    local acquired = snapshot.totalAcquired or 0
    local target = complete and 67 or 83
    allocated = math.min(target, allocated)
    local missing = target - allocated
    return {
        researchComplete = complete,
        target = target,
        acquired = acquired,
        pointsNeeded = math.max(0, target - acquired),
        correctlyAllocated = allocated,
        missing = missing,
        canFill = unspent >= missing,
        shortfall = math.max(0, missing - unspent),
    }
end

function SP:GetUnspentPoints()
    if GetAvailableSkillPoints then return GetAvailableSkillPoints() or 0 end
    return 0
end

function SP:GetTotalAcquired(build)
    return self:GetUnspentPoints() + self:CountAllSpentSkillPoints()
end

function SP:CountAllSpentSkillPoints()
    -- Use the same player-skill objects as ESO's Skills screen. Their method
    -- correctly handles free starter ranks, morphs, subclass multipliers and
    -- class mastery without reconstructing those rules ourselves.
    if SKILLS_DATA_MANAGER and SKILLS_DATA_MANAGER.IsDataReady and SKILLS_DATA_MANAGER:IsDataReady() then
        local exact=0
        for _,skillTypeData in SKILLS_DATA_MANAGER:SkillTypeIterator() do
            for _,skillLineData in skillTypeData:SkillLineIterator() do
                exact=exact+skillLineData:GetNumPointsAllocated()
            end
        end
        return exact
    end
    local spent = 0
    local maxSkillType = tonumber(SKILL_TYPE_MAX_VALUE) or 8
    for skillType=1,maxSkillType do
        local lineCount = GetNumSkillLines(skillType) or 0
        for lineIndex=1,lineCount do
            local pointCost = type(GetSkillLinePointCostMultiplier)=="function" and (GetSkillLinePointCostMultiplier(skillType,lineIndex) or 1) or 1
            local abilityCount = GetNumSkillAbilities(skillType,lineIndex) or 0
            for abilityIndex=1,abilityCount do
                local _,_,_,passive,_,purchased,progressionIndex,rank = GetSkillAbilityInfo(skillType,lineIndex,abilityIndex)
                -- Auto-granted abilities appear as purchased but cost no
                -- skill point. Counting them caused the observed +13 error.
                local autoGranted = type(IsSkillAbilityAutoGrant)=="function" and IsSkillAbilityAutoGrant(skillType,lineIndex,abilityIndex)
                if purchased then
                    if passive then
                        local paid=math.max(0,(tonumber(rank) or 1)-(autoGranted and 1 or 0))
                        spent = spent + paid * pointCost
                    else
                        if not autoGranted then spent = spent + pointCost end
                        if progressionIndex and type(GetProgressionSkillMorphSlot)=="function" then
                            local ok,morphSlot=pcall(GetProgressionSkillMorphSlot,progressionIndex)
                            if ok and tonumber(morphSlot) and morphSlot>0 then spent=spent+pointCost end
                        end
                    end
                end
            end
        end
    end
    return spent
end

function SP:AllocateMissing()
    local snapshot = CAM.Scanner:BuildSnapshot()
    if not snapshot or not snapshot.skillBuild then return false, "Current character data is incomplete." end
    local readiness = self:GetReadiness(snapshot)
    local missing = readiness.missing
    if missing == 0 then return false, "All configured passives are already allocated." end
    if self:GetUnspentPoints() < missing then return false, string.format("%d additional unspent skill points are required.", missing-self:GetUnspentPoints()) end
    if type(PrepareSkillPointAllocationRequest)~="function" or type(AddPassiveChangeToAllocationRequest)~="function" or type(SendSkillPointAllocationRequest)~="function" then
        return false, "This ESO client does not expose skill allocation requests."
    end

    local function callAllocationApi(name,...)
        if type(IsProtectedFunction)=="function" and IsProtectedFunction(name) then
            return CallSecureProtected(name,...)
        end
        local fn=_G[name]
        if type(fn)~="function" then return false,"API unavailable: "..name end
        local ok,result=pcall(fn,...)
        return ok,result
    end

    local prepared,prepareError=callAllocationApi("PrepareSkillPointAllocationRequest",SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY,RESPEC_PAYMENT_TYPE_GOLD)
    if not prepared then return false,"ESO refused the allocation request: "..tostring(prepareError) end
    local bought, changed = 0, 0
    for _, item in ipairs(snapshot.skillBuild.required) do
        local required = not (readiness.researchComplete and (item.category == "research" or self.researchPassives[item.name]))
        if required and not item.unresolved and item.current < item.target then
            local abilityId = GetSpecificSkillAbilityInfo(item.skillType,item.lineIndex,item.abilityIndex,0,item.targetRank)
            local skillLineId = GetSkillLineId(item.skillType,item.lineIndex)
            if abilityId and abilityId>0 and skillLineId and skillLineId>0 then
                local added,addError=callAllocationApi("AddPassiveChangeToAllocationRequest",skillLineId,abilityId,false)
                if not added then
                    callAllocationApi("CancelSkillPointAllocationRequest")
                    return false,"ESO refused a passive change: "..tostring(addError)
                end
                bought = bought + (item.target-item.current)
                changed = changed + 1
            end
        end
    end
    if changed==0 then callAllocationApi("CancelSkillPointAllocationRequest"); return false, "No purchasable passive ranks were found." end
    local sent,sendError=callAllocationApi("SendSkillPointAllocationRequest")
    if not sent then callAllocationApi("CancelSkillPointAllocationRequest"); return false,"ESO refused to apply the passives: "..tostring(sendError) end
    return true, string.format("Submitted %d passive rank(s) for allocation.", bought)
end
