local A=ALTHarvestItems
function A:InvalidateSurveyCaches()
    self.surveySummaryCache={}; self.surveyEnvelopeCache=nil
end
local summary=A.SurveySummary
function A:SurveySummary(key)
    self.surveySummaryCache=self.surveySummaryCache or {}
    if not self.surveySummaryCache[key] then self.surveySummaryCache[key]=summary(self,key) end
    return self.surveySummaryCache[key]
end
local stock=A.UpdateSurveyStock
function A:UpdateSurveyStock() self:InvalidateSurveyCaches(); return stock(self) end
local change=A.SelectionChanged
function A:SelectionChanged()
    self.professionSelectionCache={}; self:InvalidateSurveyCaches(); return change(self)
end
local profession=A.ProfessionSelection
function A:ProfessionSelection(key)
    if self.professionCacheRevision~=self.catalogRevision then
        self.professionSelectionCache={}; self.professionCacheRevision=self.catalogRevision
    end
    self.professionSelectionCache=self.professionSelectionCache or {}
    local c=self.professionSelectionCache[key]
    if not c then local ids,selected=profession(self,key); c={ids,selected}; self.professionSelectionCache[key]=c end
    return c[1],c[2]
end
local refresh=A.RefreshProfessions
function A:RefreshProfessions()
    self.professionSelectionCache={}; self.surveySummaryCache={}
    refresh(self)
end
local find=A.FindSurveyEnvelope
function A:FindSurveyEnvelope(key)
    if self:SurveyUseBlocked() then return end
    local c=self.surveyEnvelopeCache
    local batch=self.surveyBatch
    if c and c.key==key and (not batch or not batch.remaining or (c.id and (batch.remaining[c.id] or 0)>0)) then
        if not c.slot then return end
        if GetItemLinkItemId(GetItemLink(BAG_BACKPACK,c.slot))==c.id then
            local usable,quick=IsItemUsable(BAG_BACKPACK,c.slot)
            local remaining=GetItemCooldownInfo and GetItemCooldownInfo(BAG_BACKPACK,c.slot) or 0
            if not quick and not (IsItemPlayerLocked and IsItemPlayerLocked(BAG_BACKPACK,c.slot))
                and (usable or remaining>0) and (CanInteractWithItem(BAG_BACKPACK,c.slot) or remaining>0) then
                if remaining>0 then self.surveyCooldownUntil=self.Now()+remaining/1000 end
                return c.slot,c.id,remaining
            end
            return
        end
    end
    local slot,id,remaining=find(self,key)
    if slot and remaining and remaining>0 then self.surveyCooldownUntil=self.Now()+remaining/1000 end
    self.surveyEnvelopeCache={key=key,slot=slot,id=id}
    return slot,id,remaining
end
local tick=A.SurveyOpeningTick
function A:SurveyOpeningTick()
    if not self:SurveyWindowActive() and not self.surveyOpening and not self.surveyBatch then self:EnsureSurveyTicker(); return end
    if self.db.ui.surveyMinimized and not self.surveyOpening and not self.surveyBatch then
        if self.RefreshSurveyArea then self:RefreshSurveyArea() end
        return -- No inventory, roster, shrine or row work in an idle compact HUD.
    end
    tick(self)
    if self.RefreshSurveyArea and self:SurveyWindowActive() then self:RefreshSurveyArea() end
    self:EnsureSurveyTicker()
end
function A:EnsureSurveyTicker()
    local needed=self.surveyOpening or self.surveyBatch or (self.surveyRequestedVisible and self.surveyWindow and not self.surveyWindow:IsHidden())
    local cooldown=not self.db.ui.surveyMinimized and self.Now()<(self.surveyCooldownUntil or 0)
    local interval=(self.surveyOpening or self.surveyBatch or cooldown) and 250 or 1000
    if not needed then EVENT_MANAGER:UnregisterForUpdate('ALTHarvestItemsSurveyOpening'); self.surveyTickInterval=nil; return end
    if self.surveyTickInterval==interval then return end
    EVENT_MANAGER:UnregisterForUpdate('ALTHarvestItemsSurveyOpening'); self.surveyTickInterval=interval
    EVENT_MANAGER:RegisterForUpdate('ALTHarvestItemsSurveyOpening',interval,function() self:SurveyOpeningTick() end)
end
-- One native node catalogue per network change/30 seconds, not one full scan per row/second.
function A:SurveyRecallNode(area,fresh)
    if not GetNumFastTravelNodes or not GetFastTravelNodeInfo or not GetFastTravelNodePOIIndicies or not GetZoneId
        or not GetZoneNameById or not GetRecallCost or not GetRecallCurrency or not GetFastTravelNodeOutboundOnlyInfo
        or not GetFastTravelNodeHouseId or not POI_TYPE_WAYSHRINE then return end
    local now=self.Now()
    if not self.surveyShrineNodes or self.surveyShrineDirty or (not EVENT_FAST_TRAVEL_NETWORK_UPDATED and now-(self.surveyShrineAt or 0)>=30) then
        local map={}
        for i=1,GetNumFastTravelNodes() do
            local known,_,_,_,_,_,kind,_,locked=GetFastTravelNodeInfo(i)
            if known and not locked and kind==POI_TYPE_WAYSHRINE and GetFastTravelNodeHouseId(i)==0 and not GetFastTravelNodeOutboundOnlyInfo(i) then
                local zone=GetFastTravelNodePOIIndicies(i)
                if zone and zone>0 then
                    local key=zo_strlower(self:SurveyZoneBase(GetZoneNameById(GetZoneId(zone))))
                    map[key]=map[key] or {}; map[key][#map[key]+1]=i
                end
            end
        end
        self.surveyShrineNodes=map; self.surveyShrineAt=now; self.surveyShrineDirty=nil
    end
    local best; local key=zo_strlower(self:SurveyZoneBase(area))
    for _,i in ipairs(self.surveyShrineNodes[key] or {}) do
        local known,name,_,_,_,_,kind,_,locked=GetFastTravelNodeInfo(i)
        local zone=GetFastTravelNodePOIIndicies(i)
        local correctZone=zone and zone>0 and zo_strlower(self:SurveyZoneBase(GetZoneNameById(GetZoneId(zone))))==key
        if known and not locked and correctZone and kind==POI_TYPE_WAYSHRINE and not GetFastTravelNodeOutboundOnlyInfo(i) and GetFastTravelNodeHouseId(i)==0 then
            local cost=GetRecallCost(i)
            if type(cost)=='number' and cost>=0 and GetRecallCurrency(i)==CURT_MONEY and
                (not best or cost<best.cost or (cost==best.cost and zo_strlower(name)<zo_strlower(best.name))) then best={index=i,name=name,cost=cost} end
        end
    end
    return best
end
local initialize=A.Initialize
function A:Initialize()
    initialize(self)
    if EVENT_FAST_TRAVEL_NETWORK_UPDATED then EVENT_MANAGER:RegisterForEvent('ALTHISurveyShrines',EVENT_FAST_TRAVEL_NETWORK_UPDATED,function() self.surveyShrineDirty=true end) end
    EVENT_MANAGER:RegisterForEvent('ALTHISurveyTickReset',EVENT_PLAYER_DEACTIVATED,function() self.surveyTickInterval=nil end)
end
