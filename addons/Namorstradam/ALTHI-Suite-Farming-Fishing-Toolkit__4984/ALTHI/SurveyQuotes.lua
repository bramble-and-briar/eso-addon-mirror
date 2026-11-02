-- Live visible quotes: reuse already-resolved node indices, never rebuild lists.
local A=ALTHarvestItems
local function remember(self,button)
    button.quoteNode=nil; button.quoteText=nil
    if not button.area or self:SurveyTravelTarget(button.area) then return end
    local node=self:SurveyRecallNode(button.area)
    if node then button.quoteNode={index=node.index,name=node.name} end
end
local rows=A.RefreshSurveyTravelRows
function A:RefreshSurveyTravelRows()
    rows(self)
    local w=self.surveyWindow
    if not w or self.db.ui.surveyMinimized then return end
    for _,button in ipairs(w.travelButtons or {}) do
        if not button:IsHidden() then remember(self,button) end
    end
end
local compact=A.RefreshCompactSurveyTarget
function A:RefreshCompactSurveyTarget()
    compact(self)
    local w=self.surveyWindow
    if w and w.nextTravel and not w.nextTravel:IsHidden() then
        remember(self,w.nextTravel)
        w.nextTravel:SetHandler('OnMouseEnter',function(c)
            self.surveyTravelHovered=c; self.surveyQuoteTip=nil
            if c.area then self:ShowSuiteTip(c,TOP,self:SurveyTravelTip(c.area)) end
        end)
        w.nextTravel:SetHandler('OnMouseExit',function() self.surveyTravelHovered=nil; self.surveyQuoteTip=nil; self:HideSuiteTip() end)
    end
end
function A:RefreshVisibleSurveyQuotes()
    if not self:SurveyWindowActive() or not GetRecallCost then return end
    local now=self.Now()
    if self.surveyQuoteTickAt and now-self.surveyQuoteTickAt<1 then return end
    self.surveyQuoteTickAt=now
    local w=self.surveyWindow
    local buttons=self.db.ui.surveyMinimized and {w.nextTravel} or w.travelButtons or {}
    local cash -- One carried-gold read for all visible paid quotes.
    local costs={}
    for _,button in ipairs(buttons) do
        local node=button.quoteNode
        if node and not button:IsHidden() then
            local cost=costs[node.index]
            if cost==nil then cost=GetRecallCost(node.index); costs[node.index]=cost end
            if type(cost)=='number' and cost>=0 then
                if cash==nil then cash=GetCurrencyAmount and GetCurrencyAmount(CURT_MONEY,CURRENCY_LOCATION_CHARACTER) or GetCurrentMoney and GetCurrentMoney() or 0 end
                local amount=self.Integer(cost)
                if cost>cash then amount='|cFF5555'..amount..'|r' end
                local value=self.coin..' '..amount
                if button.quoteText~=value then button:SetText(value); button.quoteText=value end
                local destination={index=node.index,name=node.name,cost=cost}
                self.recallCache=self.recallCache or {}
                self.recallCache[zo_strlower(self:SurveyZoneBase(button.area))]={at=now,value=destination}
                if self.surveyTravelHovered==button then
                    local tip=self:T('SURVEY_WAYSHRINE')..'\n'..string.format(self:T('SURVEY_RECALL_COST'),amount,self.coin)
                    if self.surveyQuoteTip~=tip then self:ShowSuiteTip(button,TOP,tip); self.surveyQuoteTip=tip end
                end
            end
        end
    end
end
local tick=A.SurveyOpeningTick
function A:SurveyOpeningTick()
    tick(self)
    self:RefreshVisibleSurveyQuotes()
end
