local AMW=AutoMasterWrits
local eventNames={
    {"Offer",EVENT_QUEST_OFFERED},{"QuestAdded",EVENT_QUEST_ADDED},{"Chatter",EVENT_CHATTER_BEGIN},
    {"Reward",EVENT_QUEST_COMPLETE_DIALOG},{"Removed",EVENT_QUEST_REMOVED},
    {"Effects",EVENT_EFFECT_CHANGED},{"Combat",EVENT_PLAYER_COMBAT_STATE},
}

function AMW:IsRolis()
    if GetInteractionType()==INTERACTION_NONE then return false end
    local strings=WritCreater.writCompleteStrings()
    local expected=strings["Rolis Hlaalu"]
    if not expected or expected=="" then return false end
    local gamepad=ZO_InteractWindow_GamepadTitle
    local keyboard=ZO_InteractWindowTargetAreaTitle
    return gamepad and gamepad.GetText and string.find(gamepad:GetText() or "",expected,1,true)~=nil
        or keyboard and keyboard.GetText and string.find(keyboard:GetText() or "",expected,1,true)~=nil or false
end

function AMW:IsWritReady(index)
    if GetJournalQuestIsComplete(index) then return true end
    local _,_,_,step=GetJournalQuestInfo(index)
    if step==QUEST_STEP_TYPE_END then return true end
    local _,maximum,failed,complete=GetJournalQuestConditionValues(index,1,1)
    return not failed and complete==true and maximum and maximum>0 or false
end

function AMW:PauseDelivery(message)
    if self.delivery then
        self.delivery.paused=true
        self.delivery.allowComplete,self.delivery.allowChatter,self.delivery.allowAccept=nil,nil,nil
    end
    self:Alert(message)
end

function AMW:ReleaseDeliveryEvents()
    for _,entry in ipairs(eventNames) do EVENT_MANAGER:UnregisterForEvent(self.name..entry[1],entry[2]) end
end

function AMW:ArmDelivery()
    self.delivery={armed=true,paused=true,completed=0,state="starting"}
    self:InstallDeliveryHooks()
    EVENT_MANAGER:RegisterForEvent(self.name.."Offer",EVENT_QUEST_OFFERED,function() self:OnQuestOffered() end)
    EVENT_MANAGER:RegisterForEvent(self.name.."QuestAdded",EVENT_QUEST_ADDED,function(_,index) self:OnQuestAdded(index) end)
    EVENT_MANAGER:RegisterForEvent(self.name.."Chatter",EVENT_CHATTER_BEGIN,function(_,count) self:OnChatter(count) end)
    EVENT_MANAGER:RegisterForEvent(self.name.."Reward",EVENT_QUEST_COMPLETE_DIALOG,function(_,index) self:FinishManagedQuest(index) end)
    EVENT_MANAGER:RegisterForEvent(self.name.."Removed",EVENT_QUEST_REMOVED,function(_,complete,index,_,_,_,id) self:OnQuestRemoved(complete,index,id) end)
    EVENT_MANAGER:RegisterForEvent(self.name.."Effects",EVENT_EFFECT_CHANGED,function(...)
        local id=select(16,...)
        if self.xpEffects[id] then
            self.xpRevision=(self.xpRevision or 0)+1
            self.xpDirty=true
        end
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
            if not xp.ready and not delivery.paused then self:PauseDelivery("Delivery paused: the 150% XP consumable is missing or expiring.") end
            if delivery.deadline and not delivery.paused and GetFrameTimeSeconds()>delivery.deadline then
                self:PauseDelivery("The operation was not confirmed. Inspect the dialog or journal.")
            end
            if xp.ready and xp.remaining<=60 and not delivery.warned then
                delivery.warned=true
                self:Alert("The 150% XP consumable expires in less than one minute.")
            end
            self:Yield(1000)
        end
    end)
end

function AMW:StartDelivery()
    if not self:ActivateSession() then return end
    if not self.delivery and self:IsBusy() then return self:Alert("Finish or stop the current operation first.") end
    if not self:CanUseInventory() then return self:Alert("Close the bank, loot or crafting interaction first.") end
    if not self.delivery then self:ArmDelivery() end
    local delivery=self.delivery
    self:StartJob("deliveryStart",function()
        local quests=self:MasterQuestsWorker()
        if self.delivery~=delivery then return end
        local known=self.saved.deliveryQuest
        for _,quest in ipairs(quests) do
            if not known or known.id~=quest.id then
                return self:PauseDelivery("Finish the active master writ '"..quest.name.."' before using automatic delivery.")
            end
            self:Yield()
        end
        self:RefreshXPWorker()
        local ok,reason=self:RequireXP()
        if not ok then return self:PauseDelivery(reason) end
        delivery.paused,delivery.warned=false,false
        if not delivery.current and known then
            for _,quest in ipairs(quests) do
                if quest.id==known.id then
                    delivery.current=known
                    known.index=quest.index
                    delivery.state="ready"
                end
                self:Yield()
            end
            if not delivery.current then self.saved.deliveryQuest=nil end
        end
        if delivery.current then self:ResumeCurrentDelivery() else self:PrepareNextWrit() end
    end)
end

function AMW:StopDelivery()
    local total=self.delivery and self.delivery.completed or 0
    self.delivery=nil
    for _,key in ipairs({"watch","deliveryStart","next","offer","questCheck","chatter","reward","between"}) do self:CancelJob(key) end
    self:ReleaseDeliveryEvents()
    self:ReleaseHooks("delivery")
    self:SetStatus("Delivery stopped ("..total.." completed). The session XP guard is now off.",true)
end

function AMW:ResumeCurrentDelivery()
    local delivery=self.delivery
    if not delivery or not delivery.current then return self:PrepareNextWrit() end
    if delivery.state=="offered" then return self:OnQuestOffered() end
    if delivery.state=="reward" then return self:FinishManagedQuest(delivery.current.index) end
    if delivery.state=="awaitingQuest" or delivery.state=="completing" then
        return self:PauseDelivery("Confirmation is pending. Inspect the journal before retrying.")
    end
    if self:IsRolis() then self:OnChatter(GetChatterOptionCount())
    else self:SetStatus("150% XP ready. Talk to Rolis Hlaalu.",true) end
end

function AMW:PrepareNextWrit()
    local delivery=self.delivery
    if not delivery or delivery.paused or delivery.current then return end
    self:StartJob("next",function()
        if not self:ScanWorker() then return end
        local selected
        for uid,record in pairs(self.inventory) do
            if record.bag==BAG_BACKPACK and record.crafted and not record.unsupported
                and not IsItemPlayerLocked(record.bag,record.slot)
                and (not selected or uid<selected.uid) then selected=record end
            self:Yield()
        end
        if self.delivery~=delivery or delivery.paused then return end
        if not selected then
            local total=delivery.completed
            self:StopDelivery()
            return self:SetStatus("Batch finished: "..total.." delivered. Review deferred writs for another batch.",true)
        end
        self:RefreshXPWorker()
        local ok,reason=self:RequireXP()
        if not ok then return self:PauseDelivery(reason) end
        local bag,slot=self:FindItem(selected.uid)
        if not bag or not self:IsMarkedCrafted(selected.uid) then return self:PauseDelivery("The crafted writ moved. Scan before resuming.") end
        delivery.current,delivery.state=selected,"offered"
        delivery.deadline=GetFrameTimeSeconds()+10
        self:SetStatus("Opening a marked-crafted writ: "..self:Describe(selected))
        self:SecureCall("UseItem",bag,slot)
    end)
end

function AMW:OnQuestOffered()
    local delivery=self.delivery
    if not delivery or delivery.paused or delivery.state~="offered" then return end
    self:StartJob("offer",function()
        self:RefreshXPWorker()
        if self.delivery~=delivery or delivery.paused then return end
        local ok,reason=self:RequireXP()
        if not ok then return self:PauseDelivery(reason) end
        local dialogue,response=GetOfferedQuestInfo()
        local strings=WritCreater.writCompleteStrings()
        if not dialogue or not string.find(dialogue,strings["Rolis Hlaalu"],1,true) or response~=strings.masterStart then
            return self:PauseDelivery("Unexpected quest offer. No quest was accepted.")
        end
        local current=delivery.current
        local bag,slot=self:FindItem(current.uid)
        if not bag or not self:IsMarkedCrafted(current.uid) or GetItemLink(bag,slot)~=current.link then
            return self:PauseDelivery("The selected crafted writ changed. No quest was accepted.")
        end
        local settings=WritCreater:GetSettings()
        local previous=settings.preventMasterWritAccept
        settings.preventMasterWritAccept=false
        delivery.allowAccept=true
        delivery.state,delivery.deadline="awaitingQuest",GetFrameTimeSeconds()+10
        local success,err=pcall(AcceptOfferedQuest)
        delivery.allowAccept=nil
        settings.preventMasterWritAccept=previous
        if not success then self:PauseDelivery("Could not accept the writ: "..tostring(err)) end
    end)
end

function AMW:OnQuestAdded(index)
    local delivery=self.delivery
    if not delivery or delivery.state~="awaitingQuest" then return end
    self:StartJob("questCheck",function()
        local current=delivery.current
        local _,_,craft=GetQuestConditionMasterWritInfo(index,1,1)
        if craft~=current.craft then return self:PauseDelivery("Unexpected quest added. Inspect the journal.") end
        current.index,current.id=index,GetJournalQuestId(index)
        delivery.state,delivery.deadline="ready",nil
        self.saved.deliveryQuest={uid=current.uid,craft=current.craft,id=current.id,index=index,link=current.link}
        self:Yield(350)
        if self.delivery~=delivery or delivery.current~=current or delivery.state~="ready" then return end
        if not self:IsWritReady(index) then return self:PauseDelivery("The accepted writ is not ready. No further writ will be opened.") end
        self:SetStatus("Talk to Rolis Hlaalu to deliver the accepted writ.",true)
    end)
end

function AMW:OnChatter(count)
    local delivery=self.delivery
    if not delivery or delivery.paused then return end
    self:StartJob("chatter",function()
        self:RefreshXPWorker()
        if self.delivery~=delivery or delivery.paused or not self:IsRolis() then return end
        local current=delivery.current
        if not current or not current.index or GetJournalQuestId(current.index)~=current.id then return end
        local ok,reason=self:RequireXP()
        if not ok then return self:PauseDelivery(reason) end
        if not self:IsWritReady(current.index) then return self:PauseDelivery("The current writ is not ready.") end
        for index=1,count do
            local _,kind=GetChatterOption(index)
            if kind==CHATTER_START_ADVANCE_COMPLETABLE_QUEST_CONDITIONS or kind==CHATTER_START_COMPLETE_QUEST then
                if not self:IsRolis() then return end
                delivery.allowChatter=true
                local success,err=pcall(SelectChatterOption,index)
                delivery.allowChatter=nil
                if not success then self:PauseDelivery("Dialog failed: "..tostring(err)) end
                return
            end
            self:Yield()
        end
        self:SetStatus("Select the writ delivery conversation with Rolis Hlaalu.",true)
    end)
end

function AMW:FinishManagedQuest(index)
    local delivery=self.delivery
    if not delivery or not delivery.current or delivery.current.index~=index then return end
    delivery.state="reward"
    if delivery.paused then return end
    self:StartJob("reward",function()
        self:RefreshXPWorker()
        if self.delivery~=delivery or delivery.paused or not self:IsRolis() then return end
        if GetJournalQuestId(index)~=delivery.current.id or not GetJournalQuestIsComplete(index) then
            return self:PauseDelivery("The reward does not match the managed complete quest.")
        end
        local ok,reason=self:RequireXP()
        if not ok then return self:PauseDelivery(reason) end
        delivery.allowComplete=true
        delivery.state,delivery.deadline="completing",GetFrameTimeSeconds()+10
        local success,err=pcall(CompleteQuest)
        delivery.allowComplete=nil
        if not success then self:PauseDelivery("Completion failed: "..tostring(err)) end
    end)
end

function AMW:OnQuestRemoved(completed,index,questId)
    local delivery=self.delivery
    local current=delivery and delivery.current
    if not current or (current.id~=questId and (questId or current.index~=index)) then return end
    if not completed then return self:PauseDelivery("The managed writ was removed without completion.") end
    for _,key in ipairs({"offer","questCheck","chatter","reward"}) do self:CancelJob(key) end
    delivery.completed=delivery.completed+1
    self.saved.overrides[current.uid],self.saved.deferred[current.uid]=nil,nil
    self.saved.withdraw[current.uid],self.saved.manualDeferred[current.uid],self.saved.deliveryQuest=nil,nil,nil
    delivery.current,delivery.deadline,delivery.state=nil,nil,"between"
    self:StartJob("between",function()
        self:Yield(250)
        if self.delivery~=delivery or delivery.paused then return end
        if self:IsRolis() then EndInteraction(INTERACTION_CONVERSATION) end
        self:Yield(500)
        if self.delivery==delivery then self:PrepareNextWrit() end
    end)
end

function AMW:InstallDeliveryHooks()
    self:OwnHook("delivery",_G,"CompleteQuest",function()
        local delivery=self.delivery
        if not delivery or not self:IsRolis() then return false end
        return delivery.paused or not delivery.allowComplete or not self:GetXPStatus().ready or not self:HasWorkBudget()
    end)
    self:OwnHook("delivery",_G,"SelectChatterOption",function()
        return self.delivery and self:IsRolis() and not self.delivery.allowChatter or false
    end)
    self:OwnHook("delivery",_G,"AcceptOfferedQuest",function()
        local delivery=self.delivery
        if not delivery then return false end
        local dialogue=GetOfferedQuestInfo()
        local expected=WritCreater.writCompleteStrings()["Rolis Hlaalu"]
        if dialogue and expected and string.find(dialogue,expected,1,true) then
            return delivery.paused or not delivery.allowAccept or not self:GetXPStatus().ready
        end
        return false
    end)
    self:OwnHook("delivery",WritCreater,"MasterWritsQuestAdded",function(_,index)
        if not self.delivery or not self.delivery.current then return false end
        local _,_,craft=GetQuestConditionMasterWritInfo(index,1,1)
        return craft==self.delivery.current.craft
    end)
end

