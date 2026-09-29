local CAM = CraftPawns
CAM.LazyCrafting = {}
local LC = CAM.LazyCrafting

local function IsDurablyPrepared(status)
    return status=="mailed" or status=="researching" or status=="researchStarted" or status=="researched"
end

function LC:IsPrepared(entry)
    if not entry then return false end
    if IsDurablyPrepared(entry.status) then return true end
    if entry.status=="crafted" and CAM.MailTransfer and type(CAM.MailTransfer.FindAccessibleMatch)=="function" then
        return CAM.MailTransfer:FindAccessibleMatch(entry)~=nil
    end
    return false
end

function LC:IsAvailable()
    return CAM.sv.settings.integrateLazySetCrafter and type(LibLazyCrafting)=="table" and
        type(LibLazyCrafting.AddRequestingAddon)=="function" and
        type(LibLazyCrafting.getPatternFromResearchLine)=="function"
end

function LC:RequestKey(targetId,item)
    return table.concat({targetId,item.craftType,item.lineIndex,item.traitType},":")
end

function LC:OnCraftEvent(event,station,result)
    if type(result)~="table" or not result.reference then return end
    for targetId,prepared in pairs(CAM.server.prepared or {}) do
        if prepared[result.reference] then
            local entry=prepared[result.reference]
            entry.status=(event==LLC_CRAFT_SUCCESS) and "crafted" or tostring(event)
            entry.updatedAt=GetTimeStamp()
            if event==LLC_CRAFT_SUCCESS and result.slot~=nil then
                local bag=result.bag or BAG_BACKPACK
                local link=GetItemLink(bag,result.slot,LINK_STYLE_DEFAULT)
                if link and link~="" then
                    entry.qualifications={
                        itemType=select(1,GetItemLinkItemType(link)),
                        specializedItemType=select(2,GetItemLinkItemType(link)),
                        equipType=GetItemLinkEquipType(link),
                        weaponType=GetItemLinkWeaponType(link),
                        armorType=GetItemLinkArmorType(link),
                    }
                end
            end
            return
        end
    end
end

function LC:GetItemLinkFromId(itemId)
    if type(LibLazyCrafting.getItemLinkFromItemId)=="function" then
        local ok,link=pcall(LibLazyCrafting.getItemLinkFromItemId,itemId)
        if ok then return link end
    end
    return nil
end

function LC:GetRequestRequirements(request)
    local handle=self:GetHandle()
    if not handle or type(handle.getMatRequirements)~="function" then return {} end
    local ok,requirements=pcall(handle.getMatRequirements,handle,request)
    return ok and type(requirements)=="table" and requirements or {}
end

function LC:GetAvailableMaterialCount(itemLink)
    if not itemLink or itemLink=="" or type(GetItemLinkStacks)~="function" then return 0 end
    local backpack,_,craftBag=GetItemLinkStacks(itemLink)
    return (tonumber(backpack) or 0)+(tonumber(craftBag) or 0)
end

function LC:ApplyQueueShortages(rows)
    local required,available={},{ }
    for _,row in ipairs(rows) do
        row.materialShortages={}
        for itemId,amount in pairs(self:GetRequestRequirements(row.request)) do
            itemId=tonumber(itemId)
            amount=tonumber(amount) or 0
            if itemId and itemId>0 and amount>0 then
                local link=self:GetItemLinkFromId(itemId)
                if available[itemId]==nil then available[itemId]=self:GetAvailableMaterialCount(link) end
                local before=math.max(0,(required[itemId] or 0)-available[itemId])
                required[itemId]=(required[itemId] or 0)+amount
                local after=math.max(0,required[itemId]-available[itemId])
                local newlyMissing=after-before
                if newlyMissing>0 then
                    local name=link and zo_strformat(SI_TOOLTIP_ITEM_NAME,GetItemLinkName(link)) or ("Item "..itemId)
                    row.materialShortages[#row.materialShortages+1]={itemId=itemId,name=name,amount=newlyMissing}
                end
            end
        end
        table.sort(row.materialShortages,function(a,b) return a.name<b.name end)
        local parts={}
        for _,missing in ipairs(row.materialShortages) do parts[#parts+1]=missing.amount.." "..missing.name end
        row.materialShortageText=#parts>0 and ("Queue becomes short: "..table.concat(parts,", ")) or nil
    end
end

function LC:ReportQueueShortages(rows)
    rows=rows or self:GetQueueRows()
    local count=0
    for _,row in ipairs(rows) do
        if row.materialShortageText then count=count+1 end
    end
    if count>0 then
        CAM:Notify(string.format("Queue has material shortages on %d request%s. Open View Queue for details.",count,count==1 and "" or "s"),true)
    end
    return count
end

function LC:GetHandle()
    if self.handle then return self.handle end
    if not self:IsAvailable() then return nil end
    if type(LibLazyCrafting.GetRequestingAddon)=="function" then self.handle=LibLazyCrafting:GetRequestingAddon(CAM.name) end
    if not self.handle then self.handle=LibLazyCrafting:AddRequestingAddon(CAM.name,true,function(...) LC:OnCraftEvent(...) end) end
    return self.handle
end

function LC:IsCraftable(item)
    local _,_,numTraits=GetSmithingResearchLineInfo(item.craftType,item.lineIndex)
    for traitIndex=1,(numTraits or 0) do
        local traitType,_,known=GetSmithingResearchLineTraitInfo(item.craftType,item.lineIndex,traitIndex)
        if traitType==item.traitType then return known==true end
    end
    return false
end

function LC:ChooseStyle(pattern,craftType)
    if craftType==CRAFTING_TYPE_JEWELRYCRAFTING then return 1 end
    local bestStyle,bestCount,firstKnown=nil,0,nil
    if type(GetNumValidItemStyles)=="function" and type(GetValidItemStyleId)=="function" then
        for index=1,GetNumValidItemStyles() do
            local styleId=GetValidItemStyleId(index)
            if styleId and IsSmithingStyleKnown(styleId,pattern) then
                firstKnown=firstKnown or styleId
                local materialLink=type(GetItemStyleMaterialLink)=="function" and
                    GetItemStyleMaterialLink(styleId,LINK_STYLE_DEFAULT) or nil
                local available=self:GetAvailableMaterialCount(materialLink)
                if available>bestCount then
                    bestStyle,bestCount=styleId,available
                end
            end
        end
    end
    -- Race IDs and the nine original racial style IDs share the same 1-9
    -- ordering. Imperial is race/style 10. This is only the no-stock fallback;
    -- no race receives normal selection priority.
    local racialStyle=type(GetUnitRaceId)=="function" and tonumber(GetUnitRaceId("player")) or nil
    if bestStyle then return bestStyle end
    if racialStyle and racialStyle>=1 and racialStyle<=10 and IsSmithingStyleKnown(racialStyle,pattern) then
        return racialStyle
    end
    return firstKnown or racialStyle or 1
end

function LC:Submit(item,reference)
    local handle=self:GetHandle()
    if not handle or type(handle.CraftSmithingItemByLevel)~="function" then return false,"LibLazyCrafting requester unavailable" end
    local pattern=LibLazyCrafting.getPatternFromResearchLine(item.craftType,item.lineIndex)
    if not pattern then return false,"No smithing pattern for research line" end
    local style=self:ChooseStyle(pattern,item.craftType)
    local ok,request=pcall(handle.CraftSmithingItemByLevel,handle,pattern,false,1,style,
        item.traitType+1,false,item.craftType,LibLazyCrafting.INDEX_NO_SET or 0,0,true,reference)
    return ok and type(request)=="table",ok and nil or tostring(request)
end

function LC:IsReferenceQueued(reference)
    local handle=self:GetHandle()
    if not handle or type(handle.findItemByReference)~="function" then return false end
    local ok,matches=pcall(handle.findItemByReference,handle,reference)
    return ok and type(matches)=="table" and #matches>0
end

function LC:GetTraitName(item)
    if not item then return "Unknown trait" end
    return CAM:GetTraitName(item.traitType)
end

function LC:GetRoundItems(snapshot,craftType,rounds)
    local research=snapshot and snapshot.research and snapshot.research[craftType]
    local reservations,items,usedLines={},{},{}
    for lineIndex=1,#(research and research.lines or {}) do reservations[lineIndex]={} end
    local perRound=craftType==CRAFTING_TYPE_JEWELRYCRAFTING and 1 or 3
    local active,now=0,GetTimeStamp()
    for _,line in ipairs(research and research.lines or {}) do
        local current=line.currentResearch
        if current and (not current.endsAt or current.endsAt>now) then active=active+1 end
    end
    -- Active timers occupy only the first prepared round. Every later round
    -- stays full: one active item changes three rounds from nine items to eight.
    local limit=math.max(0,math.max(1,tonumber(rounds) or 1)*perRound-math.min(perRound,active))
    while #items<limit do
        local target,bestDepth
        for lineIndex,line in ipairs(research and research.lines or {}) do
            if not usedLines[lineIndex] then
                local reserved=reservations[lineIndex]
                local traitIndex,trait
                for index,candidate in ipairs(line.traits or {}) do
                    local craftable={craftType=craftType,lineIndex=lineIndex,traitType=candidate.type}
                    if not candidate.known and not candidate.researching and not reserved[index] and self:IsCraftable(craftable) then traitIndex=index; trait=candidate; break end
                end
                if traitIndex then
                    local depth=line.knownCount or 0
                    if line.currentResearch then depth=depth+1 end
                    for _ in pairs(reserved) do depth=depth+1 end
                    if not target or depth<bestDepth or (depth==bestDepth and lineIndex<target.lineIndex) then
                        bestDepth=depth; target={lineIndex=lineIndex,traitIndex=traitIndex,trait=trait,line=line}
                    end
                end
            end
        end
        if not target then
            if next(usedLines) then usedLines={} else break end
        else
            reservations[target.lineIndex][target.traitIndex]=true
            usedLines[target.lineIndex]=true
            items[#items+1]={craftType=craftType,lineIndex=target.lineIndex,traitIndex=target.traitIndex,
                lineName=target.line.name,traitType=target.trait.type,traitName=target.trait.name}
        end
    end
    return items
end

function LC:GetBatchItems(targetId,plan)
    local record=CAM.server.characters[targetId]
    local snapshot=record and record.snapshot
    local items={}
    local rounds=plan and plan.rounds or 3
    for _,craftType in ipairs(CAM.RESEARCH_CRAFTS) do
        local source=self:GetRoundItems(snapshot,craftType,rounds)
        for _,item in ipairs(source) do items[#items+1]=item end
    end
    return items
end

function LC:QueuePlan(targetId,plan)
    if not self:IsAvailable() then return 0,{"LibLazyCrafting is unavailable or disabled."} end
    local queued,failures=0,{}
    CAM.server.prepared[targetId]=CAM.server.prepared[targetId] or {}
    local state=CAM.server.prepared[targetId]
    for _,item in ipairs(self:GetBatchItems(targetId,plan)) do
            local key=self:RequestKey(targetId,item)
            local savedEntry=state[key]
            local savedStatus=savedEntry and savedEntry.status
            if not self:IsPrepared(savedEntry) and not (savedStatus=="queued" and self:IsReferenceQueued(key)) then
                if savedEntry and savedStatus then savedEntry.status="lost"; savedEntry.updatedAt=GetTimeStamp() end
            if not self:IsCraftable(item) then
                failures[#failures+1]="Current crafter does not know "..item.lineName.." — "..self:GetTraitName(item)
            else
                local success,reason=self:Submit(item,key)
                if success then
                    state[key]={status="queued",queuedAt=GetTimeStamp(),item=item}
                    queued=queued+1
                else
                    failures[#failures+1]="Could not queue "..item.lineName.." — "..self:GetTraitName(item)..(reason and (": "..reason) or "")
                end
            end
            end
    end
    return queued,failures
end

function LC:CountQueueBatch(plan,targetId)
    local count=0
    local state=targetId and CAM.server.prepared[targetId] or {}
    for _,item in ipairs(self:GetBatchItems(targetId,plan)) do
                local reference=targetId and self:RequestKey(targetId,item)
                local entry=reference and state and state[reference]
                local status=entry and entry.status
                if not self:IsPrepared(entry) and not (status=="queued" and self:IsReferenceQueued(reference)) then
                    count=count+1
                end
    end
    return count
end

function LC:GetQueueRows()
    local handle=self:GetHandle()
    local rows={}
    if not handle or type(handle.personalQueue)~="table" then return rows end
    for station,requests in pairs(handle.personalQueue) do
        if type(requests)=="table" then
            for _,request in ipairs(requests) do
                local reference=request.reference
                local targetId=type(reference)=="string" and reference:match("^([^:]+):") or nil
                local record=targetId and CAM.server.characters[targetId]
                local prepared=targetId and CAM.server.prepared[targetId]
                local saved=prepared and prepared[reference]
                local item=saved and saved.item
                local knownCount,totalTraits
                local snapshot=record and record.snapshot
                local research=item and snapshot and snapshot.research and snapshot.research[item.craftType]
                local line=research and research.lines and research.lines[item.lineIndex]
                if line then knownCount=line.knownCount or 0; totalTraits=#(line.traits or {}) end
                local liveTraitName=item and self:GetTraitName(item)
                rows[#rows+1]={
                    station=tonumber(request.station) or tonumber(station),
                    reference=reference,
                    character=record and record.currentName or "Unknown character",
                    lineName=item and item.lineName or ("Pattern "..tostring(request.pattern or "?")),
                    traitName=liveTraitName or (item and item.traitName) or ("Trait "..tostring(request.trait or "?")),
                    knownCount=knownCount,
                    totalTraits=totalTraits,
                    request=request,
                }
            end
        end
    end
    table.sort(rows,function(a,b)
        if a.character~=b.character then return a.character<b.character end
        if a.station~=b.station then return a.station<b.station end
        return a.lineName<b.lineName
    end)
    self:ApplyQueueShortages(rows)
    return rows
end

function LC:CancelReference(reference)
    local handle=self:GetHandle()
    if not handle or type(handle.cancelItemByReference)~="function" then return false,"LibLazyCrafting requester unavailable" end
    if not self:IsReferenceQueued(reference) then return false,"That request is no longer queued" end
    handle:cancelItemByReference(reference)
    local targetId=type(reference)=="string" and reference:match("^([^:]+):") or nil
    local entry=targetId and CAM.server.prepared[targetId] and CAM.server.prepared[targetId][reference]
    if entry then entry.status="lost"; entry.updatedAt=GetTimeStamp() end
    return true
end

function LC:ClearQueue()
    local handle=self:GetHandle()
    if not handle or type(handle.cancelItem)~="function" then return 0,"LibLazyCrafting requester unavailable" end
    local rows=self:GetQueueRows()
    handle:cancelItem()
    for _,row in ipairs(rows) do
        local targetId=type(row.reference)=="string" and row.reference:match("^([^:]+):") or nil
        local entry=targetId and CAM.server.prepared[targetId] and CAM.server.prepared[targetId][row.reference]
        if entry and entry.status=="queued" then entry.status="lost"; entry.updatedAt=GetTimeStamp() end
    end
    return #rows
end
