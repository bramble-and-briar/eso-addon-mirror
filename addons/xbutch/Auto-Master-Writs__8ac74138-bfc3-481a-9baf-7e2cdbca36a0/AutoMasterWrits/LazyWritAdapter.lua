local AMW = AutoMasterWrits
local standardCrafts = {
    [CRAFTING_TYPE_BLACKSMITHING]=true, [CRAFTING_TYPE_CLOTHIER]=true,
    [CRAFTING_TYPE_WOODWORKING]=true, [CRAFTING_TYPE_JEWELRYCRAFTING]=true,
    [CRAFTING_TYPE_ENCHANTING]=true, [CRAFTING_TYPE_ALCHEMY]=true, [CRAFTING_TYPE_PROVISIONING]=true,
}
function AMW:LazyReady()
    return WritCreater and WritCreater.savedVarsAccountWide
        and type(WritCreater.savedVarsAccountWide.craftedMasterWrits) == "table"
        and type(WritCreater.sealedWritNames) == "table"
        and WritCreater.LLCInteractionMaster and type(WritCreater.GetSettings) == "function"
end

function AMW:IsMarkedCrafted(uid)
    return WritCreater and WritCreater.savedVarsAccountWide
        and WritCreater.savedVarsAccountWide.craftedMasterWrits[uid] == true or false
end

function AMW:ReadWrit(bag, slot)
    if GetItemType(bag, slot) ~= ITEMTYPE_MASTER_WRIT then return end
    local uid = self:UniqueId(bag, slot)
    if not uid then return end
    local link = GetItemLink(bag, slot)
    local craft = WritCreater.sealedWritNames[GetItemLinkName(link)]
    local parts = { ZO_LinkHandler_ParseLink(link) }
    local quality, trait = tonumber(parts[12]), tonumber(parts[14])
    local equipment = craft == 1 or craft == 2 or craft == 6 or craft == 7
    return {
        uid=uid, bag=bag, slot=slot, link=link, craft=craft or 0,
        quality=quality or GetItemLinkFunctionalQuality(link), trait=trait or 0,
        setId=equipment and tonumber(parts[13]) or nil, styleId=equipment and tonumber(parts[15]) or nil,
        vouchers=math.floor((tonumber(parts[24]) or 0)/10000+0.5), crafted=self:IsMarkedCrafted(uid),
        unsupported=not standardCrafts[craft] or (equipment and (not quality or quality<1 or quality>5 or not trait)),
    }
end

function AMW:MasterQuestsWorker()
    local result = {}
    for index=1,MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(index) then
            local _,_,craft=GetQuestConditionMasterWritInfo(index,1,1)
            if standardCrafts[craft] then
                result[#result+1]={index=index,id=GetJournalQuestId(index),name=GetJournalQuestName(index),craft=craft}
            end
        end
        self:Yield()
    end
    return result
end

function AMW:UseMimic(style)
    local setting=WritCreater:GetSettings().useMimic
    if not setting then return false end
    if setting==WritCreater.MW_USE_MIMIC_ALWAYS then return true end
    local link=GetItemStyleMaterialLink(style)
    if setting==WritCreater.MW_USE_MIMIC_IF_NO_STONES then
        local bag,bank,craft=GetItemLinkStacks(link)
        return bag+bank+craft==0
    end
    local price=LibPrice and LibPrice.ItemLinkToPriceGold(link) or 0
    return (setting==WritCreater.MW_USE_MIMIC_IF_EXPENSIVE_1k and price>1000)
        or (setting==WritCreater.MW_USE_MIMIC_IF_EXPENSIVE_3k and price>3000) or false
end

function AMW:QueueOne(record)
    local bag,slot=self:FindItem(record.uid)
    if not bag or self:IsMarkedCrafted(record.uid) then return false end
    self:Classify(record)
    if record.deferred or record.unsupported or IsItemJunk(bag,slot) then return false end
    if GetCraftingInteractionType()~=CRAFTING_TYPE_INVALID then error("Leave the crafting station before queueing.") end
    local parts={ZO_LinkHandler_ParseLink(record.link)}
    local interaction=WritCreater.LLCInteractionMaster
    if record.craft==CRAFTING_TYPE_ALCHEMY then
        if WritCreater.isAlchemyWritCraftable and not WritCreater.isAlchemyWritCraftable(bag,slot) then return false end
        WritCreater.alchemySealedWrit(bag,slot,record.uid)
    elseif record.craft==CRAFTING_TYPE_PROVISIONING then
        local result=tonumber(parts[10])
        local _,list,index=GetRecipeInfoFromItemId(result)
        if not list or not GetRecipeInfo(list,index) then return false end
        interaction:CraftProvisioningItemByResultItemId(result,2,true,record.uid)
    elseif record.craft==CRAFTING_TYPE_ENCHANTING then
        local levelId=tonumber(parts[11])
        local level=levelId==207 and 150 or levelId==225 and 160
        if not level then return false end
        interaction:CraftEnchantingGlyphDesiredResult(true,level,tonumber(parts[10]),record.quality,true,record.uid)
    else
        local pattern=interaction.GetItemTemplateIdPatternIndex(tonumber(parts[10]))
        if not pattern then return false end
        interaction:CraftSmithingItemByLevel(pattern,true,150,record.styleId,record.trait+1,
            self:UseMimic(record.styleId),record.craft,record.setId,record.quality,true,record.uid)
    end
    return true
end

function AMW:QueueEligible()
    if not self:ActivateSession() then return end
    if self:IsBusy() then return self:Alert("Finish or stop the current operation first.") end
    if GetCraftingInteractionType()~=CRAFTING_TYPE_INVALID then return self:Alert("Leave the crafting station before queueing.") end
    self:StartJob("queue",function()
        if not self:ScanWorker() then return end
        local interaction=WritCreater.LLCInteractionMaster
        local existing={}
        local queue=interaction.getAddonCraftingQueue and interaction:getAddonCraftingQueue() or {}
        for station,requests in pairs(queue) do
            for position=#requests,1,-1 do
                local request=requests[position]
                local record=self.inventory[request.reference]
                if record and record.deferred and interaction.cancelItem then
                    interaction:cancelItem(station,position)
                elseif request.reference~=nil then
                    existing[request.reference]=true
                end
                self:Yield()
            end
        end
        for _,record in pairs(self.inventory) do
            if record.bag==BAG_BACKPACK and (record.deferred or record.unsupported) then
                self:ArmBanking()
                return self:Alert("Deposit deferred writs or include them before queueing.")
            end
            self:Yield()
        end
        local queued,skipped=0,0
        for uid,record in pairs(self.inventory) do
            if record.bag==BAG_BACKPACK and not record.crafted and not existing[uid] then
                -- One external crafting request per frame. Library calls cannot be preempted.
                if not self:HasWorkBudget() then self:Yield(50) end
                if self:QueueOne(record) then queued=queued+1 else skipped=skipped+1 end
                self:Yield(25)
            else
                self:Yield()
            end
        end
        self:SetStatus(string.format("%d requests added to Lazy Writ Crafter; %d skipped.",queued,skipped),true)
    end)
end
