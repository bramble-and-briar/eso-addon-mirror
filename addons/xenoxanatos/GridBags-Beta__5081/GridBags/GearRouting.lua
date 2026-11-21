-- Item delivery purposes only. Never calls a deconstruction or research action.
GridBagsGearRouting = {}
local G = GridBagsGearRouting
local R,M,F,S = GridBagsRouting,GridBagsSmartRouting,GridBagsCrafting,GridBagsSnapshots
local CRAFTS = {[1]=true,[2]=true,[3]=true,[6]=true,[7]=true}
local RESEARCH = {[1]=true,[2]=true,[6]=true,[7]=true}

function G:Observe(bag,slot,link)
    if not GetItemLinkCraftingSkillType or not CanItemBeDeconstructed then return nil end
    local ok,result=pcall(function()
        local craft=GetItemLinkCraftingSkillType(link)
        if not CRAFTS[craft] and GetItemLinkItemType then
            local kind=GetItemLinkItemType(link)
            for _,name in ipairs({"ITEMTYPE_GLYPH_ARMOR","ITEMTYPE_GLYPH_WEAPON","ITEMTYPE_GLYPH_JEWELRY"})do
                if _G[name]and kind==_G[name]then craft=3 end
            end
        end
        if not CRAFTS[craft] then return {allowed=false,at=GetTimeStamp()}end
        local forced=IsItemLinkForcedNotDeconstructable and IsItemLinkForcedNotDeconstructable(link)
        return {craft=craft,allowed=not forced and CanItemBeDeconstructed(bag,slot,craft)==true,at=GetTimeStamp()}
    end)
    return ok and result or nil
end

function G:LiveItem(spec,observed)
    local source=spec.state=="bank"and R.BANK or spec.source
    local items=observed and (observed.bag and {observed}or observed)or R:Scan(source)
    local uid=spec.state=="bank"and (spec.bankUid or spec.uid)or spec.uid
    for _,item in ipairs(items)do
        local match=not uid or item.uid==uid or (spec.state=="bank"and(spec.maxStack or 1)>1)
        if item.link==spec.link and match then return item end
    end
end

function G:Evidence(spec,observed)
    local source=spec.state=="bank"and R.BANK or spec.source
    if source==R.ANY then
        local copy={};for key,value in pairs(spec)do copy[key]=value end
        copy.source=R.character;return self:Evidence(copy)
    end
    if source==R.character or (source==R.BANK and R:IsBanking())then
        local item=self:LiveItem(spec,observed)
        if not item then return nil,"Item is missing or its identity changed; refresh the source view"end
        if item.blocked then return nil,item.blockedReason or "Source item cannot be transferred"end
        return self:Observe(item.bag,item.slot,item.link)
    end
    local record=source==R.BANK and GridBags.saved.bankSnapshots[GetWorldName()]or S.records[source]
    if not record or GetTimeStamp()-(record.updatedAt or 0)>7*86400 then return nil,"Source snapshot is missing or stale; visit the character/bank to refresh it"end
    for _,item in ipairs(record.items or {})do
        if item.link==spec.link and (not spec.uid or item.uid==spec.uid)then
            if item.locked or item.playerLocked or item.stolen then return nil,"Saved source item is locked or stolen"end
            local data=item.deconstruction
            if not data or GetTimeStamp()-(data.at or 0)>7*86400 then return nil,"Refresh this source snapshot to capture deconstruction eligibility"end
            return data
        end
    end
    return nil,"Item is not present in the saved source snapshot"
end

function G:Candidates(link,source,craft,research,except)
    local entries,noData={},false
    for id in pairs(R.data.profiles)do
        local role=F:Role(id,craft)
        if id~=source and role[research and "researcher"or "crafter"]then
            local eligible=true
            if research then
                local state=M:Knowledge(link,id,true)
                if state=="no-data"then noData=true end
                eligible=state=="unknown"and not M:Duplicate(id,link,true,except)
            end
            if eligible then
                local skills=F:Skills(id);local data=skills and skills[craft]
                if data and type(data.rank)=="number"and type(data.passivePoints)=="number"then
                    entries[#entries+1]={id=id,craft=craft,rank=data.rank,points=data.passivePoints,priority=role.priority or 100}
                else noData=true end
            end
        end
    end
    table.sort(entries,function(a,b)
        if a.rank~=b.rank then return a.rank>b.rank end
        if a.points~=b.points then return a.points>b.points end
        if a.priority~=b.priority then return a.priority<b.priority end
        return R:Name(a.id)<R:Name(b.id)
    end)
    if entries[1]then
        for _,entry in ipairs(entries)do
            entry.top=entry.rank==entries[1].rank and entry.points==entries[1].points and entry.priority==entries[1].priority
        end
    end
    return entries,noData
end

function G:ResearchCandidates(link,source,except)
    local key,craft=M:ResearchKey(link)
    if not key or not RESEARCH[craft] then return {},"This item has no supported researchable trait (or Character Knowledge is unavailable)",false end
    local entries,noData=self:Candidates(link,source,craft,true,except)
    local reason=#entries>0 and "Choose a verified recipient; ranked by earned profession rank, passive investment, then profile priority"or
        (noData and "Research knowledge or profession scans are missing/stale; refresh designated researchers"or "No other designated researcher needs this trait without an existing copy or planned delivery")
    return entries,reason,noData
end

function G:Choices(spec,kind)
    if not spec then return {},"Mark an item first"end
    if spec.blocked then return {},"Source item is locked, stolen or character-bound; resolve that before planning this delivery"end
    if GetItemLinkBindType and BIND_TYPE_ON_PICKUP_BACKPACK and GetItemLinkBindType(spec.link)==BIND_TYPE_ON_PICKUP_BACKPACK then
        return {},"This item is character-bound and cannot be sent through the account bank"
    end
    if kind=="research"then return self:ResearchCandidates(spec.link,spec.source)end
    local evidence,reason=self:Evidence(spec)
    if not evidence then return {},reason or "Deconstruction eligibility unavailable; refresh the source snapshot"end
    if not evidence.allowed or not CRAFTS[evidence.craft]then return {},"ESO does not mark this source item as deconstructable"end
    local entries,noData=self:Candidates(spec.link,spec.source,evidence.craft,false)
    return entries,#entries>0 and "Choose a crafter; ranked by earned profession rank, passive investment, then profile priority"or
        (noData and "Designated crafter profession scans are missing/stale"or "No other Crafter profile is assigned to this item's profession")
end

function G:EligibleDeconstruction(plan,observed)
    local craft=plan.smart.craft
    if not CRAFTS[craft]then return false,"Unsupported deconstruction profession","DECONSTRUCTION_UNAVAILABLE"end
    if not F:Role(plan.dest,craft).crafter then return false,"Recipient is no longer a Crafter for this profession","PROFILE_NOT_ASSIGNED"end
    local skills=F:Skills(plan.dest)
    if not skills or not skills[craft]or type(skills[craft].rank)~="number"then return false,"Recipient profession scan is missing/stale","CRAFT_DATA_MISSING"end
    local evidence,reason=self:Evidence(plan,observed)
    if not evidence or not evidence.allowed or evidence.craft~=craft then return false,reason or "Item is no longer eligible for deconstruction","DECONSTRUCTION_UNAVAILABLE"end
    return true
end

function G:EligibleResearch(plan)
    local key,craft=M:ResearchKey(plan.link)
    if not key or not RESEARCH[craft]or craft~=plan.smart.craft then return false,"Item has no matching researchable trait","NOT_LEARNABLE"end
    if not F:Role(plan.dest,craft).researcher then return false,"Recipient is no longer a Researcher for this profession","PROFILE_NOT_ASSIGNED"end
    local skills=F:Skills(plan.dest)
    if not skills or not skills[craft]or type(skills[craft].rank)~="number"then return false,"Recipient profession scan is missing/stale","CRAFT_DATA_MISSING"end
    return true
end
