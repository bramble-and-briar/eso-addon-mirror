local AMW=AutoMasterWrits
local eventNames={
    {"Offer",EVENT_QUEST_OFFERED},{"QuestAdded",EVENT_QUEST_ADDED},{"Chatter",EVENT_CHATTER_BEGIN},
    {"ChatterEnd",EVENT_CHATTER_END},
    {"Removed",EVENT_QUEST_REMOVED},{"Effects",EVENT_EFFECT_CHANGED},{"Combat",EVENT_PLAYER_COMBAT_STATE},
    {"DeliveryInventory",EVENT_INVENTORY_SINGLE_SLOT_UPDATE},
    {"RewardSpace",EVENT_QUEST_COMPLETE_ATTEMPT_FAILED_INVENTORY_FULL},
    {"ConversationSpace",EVENT_CONVERSATION_FAILED_INVENTORY_FULL},
}

function AMW:IsRolis()
    if GetInteractionType()~=INTERACTION_CONVERSATION then return false end
    local expected=WritCreater.writCompleteStrings()["Rolis Hlaalu"]
    if not expected or expected=="" then return false end
    local gamepad,keyboard=ZO_InteractWindow_GamepadTitle,ZO_InteractWindowTargetAreaTitle
    return gamepad and gamepad.GetText and string.find(gamepad:GetText() or "",expected,1,true)~=nil
        or keyboard and keyboard.GetText and string.find(keyboard:GetText() or "",expected,1,true)~=nil or false
end

function AMW:DeliveryWritLabel(record)
    return self:CraftName(record.craft)..": "..(record.link or record.name or "master writ")
end

function AMW:PauseDelivery(message)
    local delivery=self.delivery
    if delivery then
        if delivery.current and (delivery.state=="offered" or delivery.state=="awaitingQuest") then
            message=message.." ("..self:DeliveryWritLabel(delivery.current)..")"
        end
        local duplicate=delivery.paused and delivery.pauseMessage==message
        delivery.paused,delivery.pauseMessage=true,message
        delivery.allowAccept=nil
        if duplicate then return end
    end
    self:Alert(message)
end

function AMW:ActiveDeliveryCount()
    local count=0
    for _ in pairs(self.delivery and self.delivery.active or {}) do count=count+1 end
    return count
end

function AMW:ManagedQuest(index,questId)
    local delivery=self.delivery
    if not delivery then return end
    for _,record in pairs(delivery.active) do
        if questId and record.id==questId or not questId and record.index==index then return record end
    end
end

function AMW:FocusDelivery()
    local delivery=self.delivery
    delivery.current=nil
    for craft=1,7 do
        if delivery.active[craft] then delivery.current=delivery.active[craft]; return end
    end
end

function AMW:PromptDelivery()
    local delivery=self.delivery
    local count=self:ActiveDeliveryCount()
    self:SetStatus(count.." active contracts. Press A at Rolis Hlaalu.")
    if not delivery.waveSignalled then
        delivery.waveSignalled=true
        local sound=SOUNDS.QUEST_OBJECTIVE_COMPLETE or SOUNDS.DEFAULT_CLICK
        if PlaySound and sound then PlaySound(sound) end
    end
    if not delivery.prompted then
        delivery.prompted=true
        self:Print(string.format("%d contract%s ready. Press A at Rolis Hlaalu.",count,count==1 and "" or "s"))
    end
end

function AMW:ReleaseDeliveryEvents()
    for _,entry in ipairs(eventNames) do EVENT_MANAGER:UnregisterForEvent(self.name..entry[1],entry[2]) end
end

function AMW:ReportDeliveryWaitWorker(delivery)
    local progress=delivery.lastProgressAt
    local ready,waiting,first=0,0,nil
    local quests=self:MasterQuestsWorker()
    for _,quest in ipairs(quests) do
        local record=delivery.active[quest.craft]
        if record and record.id==quest.id then
            local _,_,_,conditionDone=GetJournalQuestConditionValues(quest.index,1,1)
            if GetJournalQuestIsComplete(quest.index) or conditionDone then ready=ready+1
            else
                waiting=waiting+1
                if not first then
                    local objective=GetJournalQuestConditionInfo(quest.index,1,1,false)
                    first=quest.name..": "..(objective or "Check the journal.")
                end
            end
        end
        self:Yield()
    end
    if self.delivery~=delivery or not delivery.rolisOpen or delivery.paused or delivery.lastProgressAt~=progress then return end
    local message=string.format("Rolis waiting: %d ready, %d incomplete; %d free backpack slots.",
        ready,waiting,GetNumBagFreeSlots(BAG_BACKPACK))
    if first then message=message.." "..first end
    local interaction=GAMEPAD_INTERACTION
    local list=interaction and interaction.itemList
    local selected=list and list.GetTargetData and list:GetTargetData()
    if selected then
        local usable=selected.isChatterOption and selected.optionUsable and selected.enabled~=false
        message=message..(usable and " A: available." or " A: unavailable in the native dialog.")
    end
    self:SetStatus(message,true)
end

function AMW:ArmDelivery()
    self.delivery={armed=true,paused=true,completed=0,state="starting",active={},delivered={},needsScan=true}
    self:InstallDeliveryHooks()
    EVENT_MANAGER:RegisterForEvent(self.name.."Offer",EVENT_QUEST_OFFERED,function() self:OnQuestOffered() end)
    EVENT_MANAGER:RegisterForEvent(self.name.."QuestAdded",EVENT_QUEST_ADDED,function(_,index) self:OnQuestAdded(index) end)
    EVENT_MANAGER:RegisterForEvent(self.name.."Chatter",EVENT_CHATTER_BEGIN,function() self:OnRolisOpened() end)
    EVENT_MANAGER:RegisterForEvent(self.name.."ChatterEnd",EVENT_CHATTER_END,function() self:OnRolisClosed() end)
    EVENT_MANAGER:RegisterForEvent(self.name.."Removed",EVENT_QUEST_REMOVED,function(_,complete,index,_,_,_,id) self:OnQuestRemoved(complete,index,id) end)
    EVENT_MANAGER:RegisterForEvent(self.name.."DeliveryInventory",EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(_,bag)
        if bag==BAG_BACKPACK and self.delivery then self.delivery.itemRevision=(self.delivery.itemRevision or 0)+1 end
    end)
    local function inventoryFull()
        if self.delivery and self:IsRolis() then
            self:PauseDelivery("Backpack full. Free space for quest rewards, then resume delivery.")
        end
    end
    EVENT_MANAGER:RegisterForEvent(self.name.."RewardSpace",EVENT_QUEST_COMPLETE_ATTEMPT_FAILED_INVENTORY_FULL,inventoryFull)
    EVENT_MANAGER:RegisterForEvent(self.name.."ConversationSpace",EVENT_CONVERSATION_FAILED_INVENTORY_FULL,inventoryFull)
    EVENT_MANAGER:RegisterForEvent(self.name.."Effects",EVENT_EFFECT_CHANGED,function(...)
        if self.xpEffects[select(16,...)] then self.xpRevision=(self.xpRevision or 0)+1; self.xpDirty=true end
    end)
    EVENT_MANAGER:AddFilterForEvent(self.name.."Effects",EVENT_EFFECT_CHANGED,REGISTER_FILTER_UNIT_TAG,"player")
    EVENT_MANAGER:RegisterForEvent(self.name.."Combat",EVENT_PLAYER_COMBAT_STATE,function(_,combat)
        if combat and self.delivery then self:PauseDelivery("Delivery paused during combat.") end
    end)
    local delivery=self.delivery
    self:StartJob("watch",function()
        while self.delivery==delivery do
            local xp=self:RefreshXPWorker()
            if self.delivery~=delivery then return end
            if not xp.ready and not delivery.paused then self:PauseDelivery("Delivery paused: renew your 150% XP consumable.") end
            if delivery.deadline and not delivery.paused and GetFrameTimeSeconds()>delivery.deadline then
                self:PauseDelivery("No confirmation received. Check the current dialog before resuming.")
            end
            if xp.remaining>60 then delivery.warned=false end
            if xp.ready and xp.remaining<=60 and not delivery.warned then
                delivery.warned=true
                self:Alert("150% XP expires in less than one minute.")
            end
            if delivery.rolisOpen and not delivery.paused and self:ActiveDeliveryCount()>0
                and delivery.lastProgressAt and GetFrameTimeSeconds()-delivery.lastProgressAt>=8 and not delivery.waitReported then
                delivery.waitReported=true
                self:ReportDeliveryWaitWorker(delivery)
            end
            self:Yield(1000)
        end
    end)
end

function AMW:ValidateManagedQuestsWorker()
    local delivery=self.delivery
    local quests=self:MasterQuestsWorker()
    for _,quest in ipairs(quests) do
        local managed=delivery.active[quest.craft]
        if not managed or managed.id~=quest.id then
            self:PauseDelivery("Finish the other master writ '"..quest.name.."' before automatic delivery.")
            return false
        end
        managed.index=quest.index
        self:Yield()
    end
    for _,record in pairs(delivery.active) do
        if GetJournalQuestId(record.index)~=record.id then
            self:PauseDelivery("An active contract changed. Stop and inspect the journal.")
            return false
        end
        self:Yield()
    end
    return true
end

function AMW:StartDelivery()
    if not self:ActivateSession() then return end
    if not self.delivery and self:IsBusy() then return self:Alert("Finish or stop the current operation first.") end
    if not self:CanUseInventory() then return self:Alert("Close the bank, loot or crafting interaction first.") end
    if self.jobs and self.jobs.deliveryStart then return end
    self:ReleaseExtractionGuard()
    if self.delivery and not self.delivery.paused then return self:ResumeCurrentDelivery() end
    if self.delivery then
        for _,key in ipairs({"next","offer","questCheck","afterRolis"}) do self:CancelJob(key) end
        self.delivery.needsScan=true
    end
    if not self.delivery then self:ArmDelivery() end
    local delivery=self.delivery
    self:StartJob("deliveryStart",function()
        local saved=self.saved.deliveryQuests or {}
        -- Migrate only on an explicit command, preserving accepted legacy contracts.
        if self.saved.deliveryQuest then saved[self.saved.deliveryQuest.uid]=self.saved.deliveryQuest end
        local byId={}
        for _,record in pairs(saved) do byId[record.id]=record; self:Yield() end
        local quests=self:MasterQuestsWorker()
        local active,recovered={},{}
        for _,quest in ipairs(quests) do
            local known=byId[quest.id]
            if not known or known.craft~=quest.craft or active[quest.craft] then
                return self:PauseDelivery("Finish the other master writ '"..quest.name.."' before automatic delivery.")
            end
            known.index,known.name=quest.index,quest.name
            active[quest.craft],recovered[known.uid]=known,known
            self:Yield()
        end
        if self.delivery~=delivery then return end
        delivery.active=active
        self.saved.deliveryQuests,self.saved.deliveryQuest=recovered,nil
        if delivery.current and delivery.current.id then delivery.current=active[delivery.current.craft] end
        self:RefreshXPWorker()
        local ok,reason=self:RequireXP()
        if not ok then return self:PauseDelivery(reason) end
        delivery.paused,delivery.pauseMessage,delivery.warned,delivery.deadline=false,nil,false,nil
        if delivery.state=="offered" or delivery.state=="awaitingQuest" then return self:ResumeCurrentDelivery() end
        if self:IsRolis() then self:OnRolisOpened(); return end
        delivery.current,delivery.state,delivery.waveSignalled=nil,"filling",false
        self:PrepareNextWrit()
    end)
end

function AMW:StopDelivery(quiet)
    local total=self.delivery and self.delivery.completed or 0
    self.delivery=nil
    for _,key in ipairs({"watch","deliveryStart","next","offer","questCheck","afterRolis"}) do self:CancelJob(key) end
    self:ReleaseDeliveryEvents()
    self:ReleaseHooks("delivery")
    if not quiet then self:SetStatus("Delivery stopped: "..total.." completed. XP guard off.",true) end
end

function AMW:ResumeCurrentDelivery()
    local delivery=self.delivery
    if not delivery then return end
    if delivery.state=="offered" then return self:OnQuestOffered() end
    if delivery.state=="awaitingQuest" then
        return self:PauseDelivery("Confirmation pending. Check the dialog or journal before retrying.")
    end
    if self:IsRolis() then self:OnRolisOpened()
    elseif delivery.state=="ready" then self:PromptDelivery() end
end

function AMW:PrepareNextWrit()
    local delivery=self.delivery
    if not delivery or delivery.paused or delivery.state~="filling" or self.jobs and self.jobs.next then return end
    self:StartJob("next",function()
        if self:IsRolis() then return self:OnRolisOpened() end
        if delivery.needsScan then
            delivery.products,delivery.unavailable={},{}
            if not self:ScanWorker(delivery.products) then return end
            self:IndexDeliveryProductsWorker(delivery.products)
            if not self:ValidateManagedQuestsWorker() then return end
            delivery.pending=self:PendingMasterRequestsWorker()
            delivery.needsScan=false
        end
        local candidates={}
        for uid,record in pairs(self.inventory) do
            if record.bag==BAG_BACKPACK and record.crafted and not record.unsupported and not delivery.active[record.craft]
                and not delivery.delivered[uid] and not delivery.unavailable[uid] and not IsItemPlayerLocked(record.bag,record.slot) then
                candidates[#candidates+1]=record
            end
            self:Yield()
        end
        candidates=self:SortWorker(candidates,function(a,b) return a.uid<b.uid end)
        local selected
        for _,record in ipairs(candidates) do
            if self:FindDeliveryProofWorker(record,delivery.products,delivery.pending) then selected=record; break end
            delivery.unavailable[record.uid]=true
            self:Yield()
        end
        if self.delivery~=delivery or delivery.paused or delivery.state~="filling" then return end
        if not selected then
            if self:ActiveDeliveryCount()>0 then
                delivery.state="ready"
                self:FocusDelivery()
                return self:PromptDelivery()
            end
            local total=delivery.completed
            self:StopDelivery(true)
            return self:SetStatus(total>0 and total.." writs delivered. No further verified items in the backpack." or "No verified crafted items available in the backpack.",true)
        end
        if GetNumJournalQuests()>=MAX_JOURNAL_QUESTS then
            if self:ActiveDeliveryCount()>0 then
                delivery.state="ready"; self:FocusDelivery(); return self:PromptDelivery()
            end
            return self:PauseDelivery("Quest journal full. Free a quest slot and resume.")
        end
        self:WaitForGameCommand()
        if self:IsRolis() then
            self:OnRolisOpened()
            return
        end
        self:RefreshXPWorker()
        if not self:ValidateDeliveryProofWorker(selected) then
            if self.delivery~=delivery or delivery.paused or delivery.state~="filling" then return end
            -- Nothing has been opened. Skip this instance without preventing
            -- other verified professions or already accepted contracts from delivery.
            delivery.unavailable[selected.uid]=true
            self:CancelJob("next")
            return self:PrepareNextWrit()
        end
        if self.delivery~=delivery or delivery.paused or delivery.state~="filling" then return end
        local ok,reason=self:RequireXP()
        if not ok then return self:PauseDelivery(reason) end
        if GetInteractionType()~=INTERACTION_NONE then return self:PauseDelivery("Close the current conversation and resume delivery.") end
        if not self:CanUseInventory() then return self:PauseDelivery("Close the current interaction and resume delivery.") end
        local bag,slot=self:FindItem(selected.uid)
        if not bag or not self:IsMarkedCrafted(selected.uid) or GetItemLink(bag,slot)~=selected.link then return self:PauseDelivery("The crafted writ moved. Scan before resuming.") end
        if not self:DeliveryProofCurrent(selected) then return self:PauseDelivery("Inventory changed. Resume to verify the crafted item again.") end
        delivery.current,delivery.state=selected,"offered"
        delivery.deadline=GetFrameTimeSeconds()+10
        self:SetStatus("Opening "..self:DeliveryWritLabel(selected))
        local sent,err=self:SendGameCommand("UseItem",bag,slot)
        if not sent then self:PauseDelivery("Could not open the writ: "..tostring(err)) end
    end)
end

function AMW:OnQuestOffered()
    local delivery=self.delivery
    if not delivery or delivery.paused or delivery.state~="offered" or self.jobs and self.jobs.offer then return end
    local current=delivery.current
    self:StartJob("offer",function()
        self:WaitForGameCommand()
        self:RefreshXPWorker()
        if not self:ValidateDeliveryProofWorker(current) then
            return self:PauseDelivery("Crafted item missing, unfinished or changed. No quest accepted.")
        end
        if self.delivery~=delivery or delivery.paused or delivery.current~=current or delivery.state~="offered" then return end
        if delivery.rolisOpen then return end
        local ok,reason=self:RequireXP()
        if not ok then return self:PauseDelivery(reason) end
        local dialogue,response=GetOfferedQuestInfo()
        local strings=WritCreater.writCompleteStrings()
        if not dialogue or not string.find(dialogue,strings["Rolis Hlaalu"],1,true) or response~=strings.masterStart then
            return self:PauseDelivery("Unexpected quest offer. No quest accepted.")
        end
        local bag,slot=self:FindItem(current.uid)
        if not bag or not self:IsMarkedCrafted(current.uid) or GetItemLink(bag,slot)~=current.link or delivery.active[current.craft]
            or not self:DeliveryProofCurrent(current) then
            return self:PauseDelivery("The selected crafted writ changed. No quest accepted.")
        end
        local settings=WritCreater:GetSettings()
        local previous=settings.preventMasterWritAccept
        settings.preventMasterWritAccept=false
        delivery.allowAccept=true
        delivery.state,delivery.deadline="awaitingQuest",GetFrameTimeSeconds()+10
        local sent,err=self:SendGameCommand("AcceptOfferedQuest")
        delivery.allowAccept=nil
        settings.preventMasterWritAccept=previous
        if not sent then self:PauseDelivery("Could not accept the writ: "..tostring(err)) end
    end)
end

function AMW:OnQuestAdded(index)
    local delivery=self.delivery
    if not delivery or delivery.state~="awaitingQuest" or self.jobs and self.jobs.questCheck then return end
    local current=delivery.current
    self:StartJob("questCheck",function()
        if self.delivery~=delivery or delivery.current~=current or delivery.state~="awaitingQuest" then return end
        local _,_,craft=GetQuestConditionMasterWritInfo(index,1,1)
        if craft~=current.craft or delivery.active[craft] then return self:PauseDelivery("Unexpected master quest. Check the journal.") end
        current.index,current.id,current.name=index,GetJournalQuestId(index),GetJournalQuestName(index)
        delivery.active[craft]=current
        self.saved.deliveryQuests[current.uid]={uid=current.uid,craft=craft,id=current.id,index=index,link=current.link,name=current.name}
        delivery.current,delivery.deadline,delivery.state=nil,nil,"filling"
        if delivery.rolisOpen then delivery.state="handoff" else self:PrepareNextWrit() end
    end)
end

function AMW:OnRolisOpened()
    local delivery=self.delivery
    if not delivery or not self:IsRolis() then return end
    if not delivery.rolisOpen then
        delivery.lastProgressAt,delivery.waitReported=GetFrameTimeSeconds(),false
    end
    delivery.rolisOpen,delivery.closeSeen=true,false
    self:CancelJob("afterRolis")
    self:CancelJob("next")
    -- Lazy Writ owns the whole conversation. Only observe its lifecycle.
    if delivery.state~="offered" and delivery.state~="awaitingQuest" then
        delivery.current,delivery.deadline,delivery.state=nil,nil,"handoff"
    end
end

function AMW:OnRolisClosed()
    local delivery=self.delivery
    -- Item offers and other NPC conversations must not trigger a refill.
    if not delivery or not delivery.rolisOpen then return end
    delivery.rolisOpen,delivery.closeSeen=false,true
    self:RefillAfterRolis()
end

function AMW:RefillAfterRolis()
    local delivery=self.delivery
    if not delivery or delivery.paused or delivery.rolisOpen or not delivery.closeSeen
        or delivery.state=="filling" or self.jobs and self.jobs.afterRolis then return end
    self:StartJob("afterRolis",function()
        -- Let journal/removal notifications settle, then respect our item command interval.
        self:Yield(100)
        self:WaitForGameCommand()
        if self.delivery~=delivery or delivery.paused or delivery.rolisOpen or not delivery.closeSeen then return end
        if self:IsRolis() then return self:OnRolisOpened() end
        if delivery.state=="offered" then return self:OnQuestOffered() end
        if delivery.state=="awaitingQuest" then return end
        delivery.current,delivery.state,delivery.needsScan,delivery.waveSignalled=nil,"filling",true,false
        self:PrepareNextWrit()
    end)
end

function AMW:OnQuestRemoved(completed,index,questId)
    local delivery=self.delivery
    local current=self:ManagedQuest(index,questId)
    if not delivery or not current then return end
    if not completed then return self:PauseDelivery("A managed contract was abandoned. Check the journal.") end
    delivery.completed=delivery.completed+1
    delivery.lastProgressAt,delivery.waitReported=GetFrameTimeSeconds(),false
    delivery.delivered[current.uid]=true
    delivery.active[current.craft]=nil
    self.saved.overrides[current.uid],self.saved.deferred[current.uid]=nil,nil
    self.saved.withdraw[current.uid],self.saved.manualDeferred[current.uid],self.saved.deliveryQuests[current.uid]=nil,nil,nil
    if delivery.current==current then delivery.current=nil end
    -- Receipts can precede or follow CHATTER_END. Never refill during the dialogue.
    if delivery.closeSeen and not delivery.rolisOpen then self:RefillAfterRolis() end
end

function AMW:GuardRolisXP()
    if not self.delivery or not self:IsRolis() then return false end
    self:OnRolisOpened()
    if not self:GetXPStatus().ready then
        self:PauseDelivery("Delivery paused: renew your 150% XP consumable.")
        return true
    end
    -- Do not delay or replay Lazy Writ/player calls. Only our next item waits.
    self.lastCommandAt=GetGameTimeMilliseconds()
    return false
end

function AMW:InstallDeliveryHooks()
    self:OwnHook("delivery",_G,"CompleteQuest",function()
        return self:GuardRolisXP()
    end)
    self:OwnHook("delivery",_G,"SelectChatterOption",function(index)
        local delivery=self.delivery
        if not delivery or not self:IsRolis() then return false end
        local _,kind=GetChatterOption(index)
        if kind~=CHATTER_START_ADVANCE_COMPLETABLE_QUEST_CONDITIONS and kind~=CHATTER_START_COMPLETE_QUEST then return false end
        return self:GuardRolisXP()
    end)
    self:OwnHook("delivery",_G,"AcceptOfferedQuest",function()
        local delivery=self.delivery
        if not delivery then return false end
        local dialogue=GetOfferedQuestInfo()
        local expected=WritCreater.writCompleteStrings()["Rolis Hlaalu"]
        if dialogue and expected and string.find(dialogue,expected,1,true) then
            return delivery.paused or not delivery.allowAccept or delivery.state~="awaitingQuest"
                or not self:DeliveryProofCurrent(delivery.current) or not self:GetXPStatus().ready
        end
        return false
    end)
    self:OwnHook("delivery",WritCreater,"MasterWritsQuestAdded",function(_,index)
        local delivery=self.delivery
        if not delivery then return false end
        local _,_,craft=GetQuestConditionMasterWritInfo(index,1,1)
        local current=delivery.current
        return current and current.craft==craft and delivery.state=="awaitingQuest"
            or delivery.active[craft] and delivery.active[craft].id==GetJournalQuestId(index) or false
    end)
end
