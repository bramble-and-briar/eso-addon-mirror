local AMW=AutoMasterWrits

local function effects(a,b,c)
    a,b,c=tonumber(a),tonumber(b),tonumber(c)
    if not a or not b or not c or a<1 or b<1 or c<1 or a>63 or b>63 or c>63 then return end
    local values={a,b,c}
    table.sort(values)
    if values[1]==values[2] or values[2]==values[3] then return end
    return table.concat(values,":")
end

function AMW:ReadDeliveryProduct(slot)
    local uid=self:UniqueId(BAG_BACKPACK,slot)
    if not uid then return end
    local link=GetItemLink(BAG_BACKPACK,slot)
    if link=="" then return end
    return {uid=uid,slot=slot,link=link,id=GetItemLinkItemId(link),count=GetSlotStackSize(BAG_BACKPACK,slot)}
end

function AMW:PendingMasterRequestsWorker()
    local pending={}
    local interaction=WritCreater.LLCInteractionMaster
    if not interaction or type(interaction.getAddonCraftingQueue)~="function" then return end
    local queue=interaction:getAddonCraftingQueue()
    if type(queue)~="table" then return end
    for _,requests in pairs(queue) do
        for _,request in pairs(requests) do
            if request.reference~=nil then pending[request.reference]=true end
            self:Yield()
        end
        self:Yield()
    end
    return pending
end

function AMW:IndexDeliveryProductsWorker(products)
    local byId={}
    for _,product in ipairs(products) do
        byId[product.id]=byId[product.id] or {}
        local rows=byId[product.id]
        rows[#rows+1]=product
        self:Yield()
    end
    products.byId=byId
end

function AMW:DeliveryRequirementWorker(record)
    local x={ZO_LinkHandler_ParseLink(record.link)}
    local result=tonumber(x[10])
    if not result or result<1 then return end
    if record.craft==CRAFTING_TYPE_ALCHEMY then
        local kind=result==199 and ITEMTYPE_POTION or result==239 and ITEMTYPE_POISON
        local traits=effects(x[11],x[12],x[13])
        if not kind or not traits then return end
        return {kind="alchemy",itemType=kind,effects=traits,cp=150,quantity=16}
    elseif record.craft==CRAFTING_TYPE_PROVISIONING then
        return {kind="provisioning",id=result,quantity=8}
    elseif record.craft==CRAFTING_TYPE_ENCHANTING then
        local level=tonumber(x[11])
        local cp=level==207 and 150 or level==225 and 160
        if not cp then return end
        return {kind="enchanting",id=result,quality=record.quality,cp=cp,quantity=1}
    end
    local interaction=WritCreater.LLCInteractionMaster
    if type(interaction.GetItemTemplateIdPatternIndex)~="function" or type(interaction.getItemLinkFromParticulars)~="function" then return end
    local pattern=interaction.GetItemTemplateIdPatternIndex(result)
    if not pattern then return end
    if record.craft==CRAFTING_TYPE_JEWELRYCRAFTING then
        local sets=type(interaction.GetSetIndexes)=="function" and interaction.GetSetIndexes()
        local set=type(sets)=="table" and sets[record.setId]
        if not set or (pattern~=1 and pattern~=2) then return end
        -- LLC swaps newer sets when creating a craft request. Its read-only
        -- link helper expects that converted pattern as well.
        if set.isSwapped then pattern=3-pattern end
    end
    -- One read-only LLC link calculation per frame; never create a crafting request.
    self:Yield(25)
    local ok,link=pcall(interaction.getItemLinkFromParticulars,interaction,pattern,true,150,
        record.styleId,record.trait+1,record.craft,record.setId,record.quality)
    self:Yield(25)
    if not ok or type(link)~="string" or link=="" then return end
    local id=GetItemLinkItemId(link)
    if not id or id<1 then return end
    return {kind="equipment",id=id,quality=record.quality,trait=record.trait,setId=record.setId,
        style=record.craft~=CRAFTING_TYPE_JEWELRYCRAFTING and record.styleId or nil,cp=150,quantity=1}
end

function AMW:DeliveryProductMatches(requirement,link)
    if requirement.id and GetItemLinkItemId(link)~=requirement.id then return false end
    if requirement.cp and GetItemLinkRequiredChampionPoints(link)~=requirement.cp then return false end
    if requirement.quality and GetItemLinkFunctionalQuality(link)~=requirement.quality then return false end
    if requirement.kind=="equipment" then
        if not IsItemLinkCrafted(link) or GetItemLinkTraitInfo(link)~=requirement.trait then return false end
        local _,_,_,_,_,setId=GetItemLinkSetInfo(link)
        if setId~=requirement.setId then return false end
        if requirement.style and GetItemLinkItemStyle(link)~=requirement.style then return false end
    elseif requirement.kind=="alchemy" then
        if GetItemLinkItemType(link)~=requirement.itemType then return false end
        local x={ZO_LinkHandler_ParseLink(link)}
        local encoded=tonumber(x[24])
        if not encoded or effects(math.floor(encoded/65536)%64,math.floor(encoded/256)%64,encoded%64)~=requirement.effects then return false end
    end
    return true
end

function AMW:FindDeliveryProofWorker(record,products,pending)
    if not pending or pending[record.uid] or not self:IsMarkedCrafted(record.uid) then return false end
    local requirement=self:DeliveryRequirementWorker(record)
    if not requirement then return false end
    local proof={requirement=requirement,items={}}
    local remaining=requirement.quantity
    local candidates=products
    if requirement.id then candidates=products.byId[requirement.id] or {} end
    for _,product in ipairs(candidates or {}) do
        if self:DeliveryProductMatches(requirement,product.link) and not IsItemPlayerLocked(BAG_BACKPACK,product.slot)
            and not IsItemJunk(BAG_BACKPACK,product.slot) then
            local quantity=math.min(remaining,product.count)
            if quantity>0 then
                proof.items[#proof.items+1]={uid=product.uid,slot=product.slot,link=product.link,quantity=quantity}
                remaining=remaining-quantity
            end
        end
        self:Yield()
        if remaining==0 then record.deliveryProof=proof; return true end
    end
    return false
end

function AMW:ValidateDeliveryProofWorker(record)
    local delivery=self.delivery
    local proof=record.deliveryProof
    if not delivery or not proof or not self:IsMarkedCrafted(record.uid) then return false end
    local revision=delivery.itemRevision or 0
    local pending=self:PendingMasterRequestsWorker()
    if not pending or pending[record.uid] then return false end
    for _,item in ipairs(proof.items) do
        if self:UniqueId(BAG_BACKPACK,item.slot)~=item.uid or GetItemLink(BAG_BACKPACK,item.slot)~=item.link
            or GetSlotStackSize(BAG_BACKPACK,item.slot)<item.quantity
            or IsItemPlayerLocked(BAG_BACKPACK,item.slot) or IsItemJunk(BAG_BACKPACK,item.slot)
            or not self:DeliveryProductMatches(proof.requirement,item.link) then return false end
        self:Yield()
    end
    if self.delivery~=delivery or (delivery.itemRevision or 0)~=revision then return false end
    proof.revision=revision
    return true
end

function AMW:DeliveryProofCurrent(record)
    return record and record.deliveryProof and self.delivery
        and record.deliveryProof.revision==(self.delivery.itemRevision or 0) and self:IsMarkedCrafted(record.uid) or false
end
