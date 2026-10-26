local AMW=AutoMasterWrits
local extractionDelayMilliseconds=1000
-- Craft mapping matches Lazy Writ Crafter's LootHandler master-writ IDs.
AMW.unopenedIds={
    [217917]=CRAFTING_TYPE_BLACKSMITHING,[217918]=CRAFTING_TYPE_CLOTHIER,
    [217919]=CRAFTING_TYPE_WOODWORKING,[217920]=CRAFTING_TYPE_ENCHANTING,
    [217921]=CRAFTING_TYPE_PROVISIONING,[217922]=CRAFTING_TYPE_ALCHEMY,
    [217923]=CRAFTING_TYPE_JEWELRYCRAFTING,
}

function AMW:ExtractedCraftAtSlot(slot)
    if GetItemType(BAG_BACKPACK,slot)~=ITEMTYPE_MASTER_WRIT then return end
    return WritCreater.sealedWritNames[GetItemLinkName(GetItemLink(BAG_BACKPACK,slot))]
end

function AMW:IsMasterWritOffer()
    local dialogue=GetOfferedQuestInfo()
    local expected=WritCreater.writCompleteStrings()["Rolis Hlaalu"]
    return type(dialogue)=="string" and type(expected)=="string" and expected~=""
        and string.find(dialogue,expected,1,true)~=nil
end

function AMW:ReleaseExtractionGuard()
    self.extractionAcceptGuard=false
    EVENT_MANAGER:UnregisterForEvent(self.name.."ExtractionOffer",EVENT_QUEST_OFFERED)
    self:ReleaseHooks("extraction")
end

function AMW:GuardExtractionAcceptance()
    self.extractionAcceptGuard=true
    self:OwnHook("extraction",_G,"AcceptOfferedQuest",function()
        return self.extractionAcceptGuard and self:IsMasterWritOffer() or false
    end)
    EVENT_MANAGER:RegisterForEvent(self.name.."ExtractionOffer",EVENT_QUEST_OFFERED,function()
        if self.extracting and self:IsMasterWritOffer() then
            self:StopExtraction("Extraction stopped: unexpected master-writ offer. No contract accepted.")
        end
    end)
end

function AMW:StopExtraction(message)
    self.extracting=nil
    self:CancelJob("extract")
    EVENT_MANAGER:UnregisterForEvent(self.name.."ExtractionOffer",EVENT_QUEST_OFFERED)
    EVENT_MANAGER:UnregisterForEvent(self.name.."ExtractionInventory",EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    if message then self:SetStatus(message,true) end
end

function AMW:StartExtraction()
    if not self:ActivateSession() then return end
    if self:IsBusy() then return self:Alert("Finish or stop the current operation first.") end
    if not self:CanUseInventory() then return self:Alert("Close the bank, loot or crafting interaction first.") end
    local operation={opened=0,counts={},limit=math.max(1,math.min(200,math.floor(tonumber(self.saved.extractLimit) or 50)))}
    self.extracting=operation
    self:GuardExtractionAcceptance()
    EVENT_MANAGER:RegisterForEvent(self.name.."ExtractionInventory",EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        function(_,bag,slot,_,_,reason,change)
            local pending=operation.pending
            if self.extracting==operation and pending and bag==BAG_BACKPACK and slot==pending.slot
                and reason==INVENTORY_UPDATE_REASON_DEFAULT and type(change)=="number" then
                pending.change=pending.change+change
            end
        end)
    self:ArmBanking()
    self:StartJob("extract",function()
        local stacks={}
        for slot=0,GetBagSize(BAG_BACKPACK)-1 do
            local craft=self.unopenedIds[GetItemId(BAG_BACKPACK,slot)]
            if craft then
                local uid=self:UniqueId(BAG_BACKPACK,slot)
                if uid and not IsItemPlayerLocked(BAG_BACKPACK,slot) then
                    stacks[#stacks+1]={slot=slot,uid=uid,craft=craft,link=GetItemLink(BAG_BACKPACK,slot)}
                end
            else
                craft=self:ExtractedCraftAtSlot(slot)
                if craft then
                    -- All existing sealed writs count, including crafted, locked and deferred items.
                    operation.counts[craft]=(operation.counts[craft] or 0)+GetSlotStackSize(BAG_BACKPACK,slot)
                end
            end
            self:Yield()
        end
        -- Settings/radial scenes close asynchronously. Give the explicit command
        -- one command interval to return to gameplay before its first item use.
        self:Yield(extractionDelayMilliseconds)
        for _,stack in ipairs(stacks) do
            while self:UniqueId(BAG_BACKPACK,stack.slot)==stack.uid and (operation.counts[stack.craft] or 0)<operation.limit do
                self:WaitForGameCommand(extractionDelayMilliseconds)
                if self.extracting~=operation then return end
                if not self:CanUseInventory() then return self:StopExtraction("Extraction stopped by the current interaction.") end
                if GetNumBagFreeSlots(BAG_BACKPACK)<=self.saved.reserveSlots then
                    return self:StopExtraction("Backpack space reserve reached.")
                end
                local amount=GetSlotStackSize(BAG_BACKPACK,stack.slot)
                local id=GetItemId(BAG_BACKPACK,stack.slot)
                if self.unopenedIds[id]~=stack.craft then return self:StopExtraction("The unopened stack changed.") end
                if GetItemType(BAG_BACKPACK,stack.slot)==ITEMTYPE_MASTER_WRIT then
                    return self:StopExtraction("Extraction stopped: a sealed contract is not an unopened stack. No contract opened.")
                end
                if self:UniqueId(BAG_BACKPACK,stack.slot)~=stack.uid or IsItemPlayerLocked(BAG_BACKPACK,stack.slot) then
                    return self:StopExtraction("The unopened stack moved or was locked.")
                end
                operation.pending={slot=stack.slot,change=0}
                local sent,err=self:SendGameCommand("UseItem",BAG_BACKPACK,stack.slot)
                if not sent then return self:StopExtraction("Extraction stopped: "..tostring(err)) end
                if self.extracting~=operation then return end
                local deadline=GetFrameTimeSeconds()+8
                repeat
                    self:Yield(100)
                    local uid=self:UniqueId(BAG_BACKPACK,stack.slot)
                    local current=uid==stack.uid and GetSlotStackSize(BAG_BACKPACK,stack.slot) or 0
                    local change=operation.pending.change
                    if change<-1 then return self:StopExtraction("Another operation changed the stack. Stop the other extractor.") end
                    if uid and uid~=stack.uid and not (amount==1 and self:ExtractedCraftAtSlot(stack.slot)==stack.craft) then
                        return self:StopExtraction("The unopened stack moved. No further item was used.")
                    end
                    if change==-1 or current<amount then
                        if current<amount and amount-current~=1 then return self:StopExtraction("Another operation changed the stack. Stop the other extractor.") end
                        operation.opened=operation.opened+1
                        -- A confirmed unopened master writ produces one sealed writ of this craft.
                        operation.counts[stack.craft]=(operation.counts[stack.craft] or 0)+1
                        operation.pending=nil
                        break
                    end
                    if GetFrameTimeSeconds()>deadline then
                        return self:StopExtraction("Extraction not confirmed for "..self:CraftName(stack.craft)..": "..stack.link..". No retry sent.")
                    end
                until false
                self:SetStatus("Extracted "..operation.opened.." writs.")
                self:Yield()
            end
            self:Yield()
        end
        -- One bounded classification pass after the batch, never after every item.
        if self:ScanWorker() then self:ArmBanking() end
        self.extracting=nil
        EVENT_MANAGER:UnregisterForEvent(self.name.."ExtractionOffer",EVENT_QUEST_OFFERED)
        EVENT_MANAGER:UnregisterForEvent(self.name.."ExtractionInventory",EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        -- Keep the acceptance veto for delayed auto-accept handlers. Only an explicit
        -- delivery command or Stop all work releases it; extraction never accepts quests.
        self:SetStatus("Extraction finished: "..operation.opened.." writs.",true)
    end)
end

