-- User-started, bounded envelope series. Native cooldowns and confirmations win.
local A=ALTHarvestItems
local envelopes={alchemy=219853,metal=219849,wood=219851,cloth=219850,jewelry=219854,runes=219852}
function A:SurveyUseBlocked()
    return not CallSecureProtected or not IsItemUsable or not CanInteractWithItem
        or (IsUnitInCombat and IsUnitInCombat('player'))
        or (ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog())
end
function A:FindSurveyEnvelope(key)
    if self:SurveyUseBlocked() then return end
    local wanted=envelopes[key]; local allowed={}
    if key=='selected' and self.SurveySelectedKeys then
        for _,craft in ipairs(self:SurveySelectedKeys()) do allowed[envelopes[craft]]=true end
    elseif wanted then allowed[wanted]=true else return end
    local bestSlot,bestId,bestRemaining
    for slot=0,GetBagSize(BAG_BACKPACK)-1 do
        local id=GetItemLinkItemId(GetItemLink(BAG_BACKPACK,slot))
        local batch=self.surveyBatch
        if allowed[id] and (not batch or not batch.remaining or (batch.remaining[id] or 0)>0) then
            local usable,quickslot=IsItemUsable(BAG_BACKPACK,slot)
            local locked=IsItemPlayerLocked and IsItemPlayerLocked(BAG_BACKPACK,slot)
            local remaining=GetItemCooldownInfo and GetItemCooldownInfo(BAG_BACKPACK,slot) or 0
            if (usable or remaining>0) and not quickslot and not locked and (CanInteractWithItem(BAG_BACKPACK,slot) or remaining>0) then
                if not bestRemaining or remaining<bestRemaining then bestSlot,bestId,bestRemaining=slot,id,remaining end
            end
        end
    end
    return bestSlot,bestId,bestRemaining or 0
end
function A:StopSurveyBatch()
    self.surveyBatch=nil
end
function A:SurveyWindowActive()
    local w=self.surveyWindow
    return w and self.surveyRequestedVisible and not w:IsHidden() and not self:TopDialog() and self:SuiteBaseScene()
end
function A:IssueSurveyOpen(key,batch)
    local slot,id,cooldown=self:FindSurveyEnvelope(key)
    if not slot or cooldown>0 or self.surveyOpening then return false end
    local confirmation=ITEM_USE_TYPE_COMBINATION and GetItemUseType and GetItemUseType(BAG_BACKPACK,slot)==ITEM_USE_TYPE_COMBINATION
    if batch and confirmation then self:StopSurveyBatch(); self:Say(self:T('SURVEY_BATCH_CONFIRMATION')); return false end
    if GetNumBagFreeSlots and GetSlotStackSize(BAG_BACKPACK,slot)>1 and GetNumBagFreeSlots(BAG_BACKPACK)==0 then
        self:StopSurveyBatch(); return false
    end
    local before=0
    for i=0,GetBagSize(BAG_BACKPACK)-1 do
        if GetItemLinkItemId(GetItemLink(BAG_BACKPACK,i))==id then before=before+GetSlotStackSize(BAG_BACKPACK,i) end
    end
    self.surveyOpening={key=key,id=id,slot=slot,before=before,deadline=self.Now()+12,confirmation=confirmation}
    local action=confirmation and 'InitiateConfirmUseInventoryItem' or 'UseItem'
    local ok=CallSecureProtected(action,BAG_BACKPACK,slot)
    if ok==false then
        self.surveyOpening=nil; self:StopSurveyBatch(); self:Say(self:T('SURVEY_OPEN_DECLINED')); return false
    end
    self:QueueSurveyScan(); return true
end
function A:StartSurveyOpening(all)
    self.surveyEnvelopeCache=nil -- Explicit user actions always get a fresh eligibility check.
    if all and self.surveyBatch then self:StopSurveyBatch(); self:RefreshSurveyOpening(); return end
    if not self:SurveyWindowActive() or self.surveyOpening or self.surveyBatch or self:SurveyUseBlocked() then return end
    local key=self.surveyWindow.key
    if all then
        if not GetItemUseType then return end
        self:UpdateSurveyStock()
        local count=self:SurveySummary(key).closedInventory
        if count<1 then return end
        local remaining={}
        for id,amount in pairs(self.surveyBackpack or {}) do
            local craft,_,closed=self:DescribeSurvey(id)
            local allowed=craft==key
            if key=='selected' then
                for _,selected in ipairs(self:SurveySelectedKeys()) do if craft==selected then allowed=true end end
            end
            if closed and allowed then remaining[id]=amount end
        end
        self.surveyBatch={key=key,left=count,remaining=remaining} -- Per-item budgets exclude newly arriving professions.
    end
    if all then self:SurveyOpeningTick() else self:IssueSurveyOpen(key,false) end
    self:EnsureSurveyTicker(); self:RefreshSurveyOpening()
end
function A:RefreshSurveyOpening()
    local w=self.surveyWindow; if not w or not w.open then return end
    local slot,_,remaining=self:FindSurveyEnvelope(w.key)
    local suffix=''
    if slot and remaining>0 then suffix=string.format(' (%.1f s)',remaining/1000)
    elseif self.surveyOpening then suffix=' ('..self:T('SURVEY_WAITING')..')' end
    w.open:SetText(self:T('SURVEY_OPEN_ONE')..suffix)
    w.open:SetEnabled(slot~=nil and remaining==0 and not self.surveyOpening and not self.surveyBatch)
    if w.openAll then
        w.openAll:SetText(self:T(self.surveyBatch and 'SURVEY_STOP_BATCH' or 'SURVEY_OPEN_ALL'))
        w.openAll:SetEnabled(self.surveyBatch~=nil or (slot~=nil and not self.surveyOpening and GetItemUseType~=nil))
    end
end
function A:SurveyOpeningTick()
    local active=self:SurveyWindowActive()
    if self.surveyBatch and (not active or self.surveyBatch.key~=self.surveyWindow.key or self:SurveyUseBlocked()) then self:StopSurveyBatch() end
    local pending=self.surveyOpening
    if pending and pending.confirmation and ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog() then
        pending.deadline=self.Now()+12 -- Reading a native confirmation is not a failed request.
    end
    if pending and self.Now()>=pending.deadline then
        self.surveyOpening=nil; self:StopSurveyBatch(); self:Say(self:T('SURVEY_RESULT_TIMEOUT'))
    end
    local batch=self.surveyBatch
    if batch and not self.surveyOpening and self.Now()>=(self.surveyNextAt or 0) then
        if batch.left<1 then self:StopSurveyBatch()
        else
            local slot,_,cooldown=self:FindSurveyEnvelope(batch.key)
            if not slot then self:StopSurveyBatch()
            elseif cooldown==0 then self:IssueSurveyOpen(batch.key,true) end
        end
    end
    self:RefreshSurveyOpening()
    if not active and not self.surveyOpening then EVENT_MANAGER:UnregisterForUpdate('ALTHarvestItemsSurveyOpening') end
end
function A:EnsureSurveyTicker()
    EVENT_MANAGER:UnregisterForUpdate('ALTHarvestItemsSurveyOpening')
    EVENT_MANAGER:RegisterForUpdate('ALTHarvestItemsSurveyOpening',250,function() self:SurveyOpeningTick() end)
end
local close=A.CloseDialog
function A:CloseDialog(w)
    if w==self.surveyWindow and self.CloseSurveyList then return self:CloseSurveyList() end
    return close(self,w)
end
local initialize=A.Initialize
function A:Initialize()
    initialize(self)
    EVENT_MANAGER:RegisterForEvent('ALTHarvestItemsSurveyOpening',EVENT_PLAYER_DEACTIVATED,function()
        self:StopSurveyBatch(); self.surveyOpening=nil
        EVENT_MANAGER:UnregisterForUpdate('ALTHarvestItemsSurveyOpening')
    end)
end
