local A=ALTHarvestItems
local dialogName='ALTHARVESTITEMS_SURVEY_RECALL'
function A:SurveyTravelAllowed()
    return not (IsUnitInCombat and IsUnitInCombat('player')) and not (IsUnitDead and IsUnitDead('player'))
        and not (IsInCampaign and IsInCampaign()) and CanLeaveCurrentLocationViaTeleport and CanLeaveCurrentLocationViaTeleport()
end
function A:SurveyRecallCostText(cost)
    local text=self.Integer(cost)
    local cash=GetCurrencyAmount and GetCurrencyAmount(CURT_MONEY,CURRENCY_LOCATION_CHARACTER) or GetCurrentMoney and GetCurrentMoney()
    if type(cash)=='number' and cost>cash then text='|cFF5555'..text..'|r' end
    return text
end
local node=A.SurveyRecallNode
function A:SurveyRecallNode(area,fresh)
    area=self:SurveyZoneBase(area)
    self.recallCache=self.recallCache or {}
    local key=zo_strlower(area); local cached=self.recallCache[key]
    if not fresh and cached and self.Now()-cached.at<1 then return cached.value end
    local value=node(self,area)
    self.recallCache[key]={at=self.Now(),value=value}
    return value
end
function A:SurveyTravelTip(area)
    local target=self:SurveyTravelTarget(area)
    if target then return string.format(self:T('SURVEY_TRAVEL_NEUTRAL'),self:T(target.kind=='friend' and 'SURVEY_TRAVEL_FRIEND' or 'SURVEY_TRAVEL_GUILD')) end
    local destination=self:SurveyRecallNode(area)
    if not destination then return self:T('SURVEY_RECALL_UNAVAILABLE') end
    return self:T('SURVEY_WAYSHRINE')..'\n'..string.format(self:T('SURVEY_RECALL_COST'),self:SurveyRecallCostText(destination.cost),self.coin)
end
function A:ExecuteSurveyRecall(data)
    if not data or not self.surveyRequestedVisible or not self:SurveyTravelAllowed()
        or not GetRecallCooldown or not GetCurrencyAmount or not FastTravelToNode then return false end
    local destination=self:SurveyRecallNode(data.area,true)
    local _,premium=GetRecallCooldown()
    local cash=GetCurrencyAmount(CURT_MONEY,CURRENCY_LOCATION_CHARACTER)
    if not destination or destination.index~=data.index or destination.cost>data.cost or premium~=0 or destination.cost>cash then
        return false -- A changed quote requires a new explicit click and confirmation.
    end
    self:StopSurveyBatch(); self:HideSuiteTip()
    FastTravelToNode(destination.index)
    return true
end
function A:RequestSurveyTravel(area)
    if not self:SurveyWindowActive() or not self:SurveyTravelAllowed()
        or (ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog()) then return false end
    self:BuildSurveyTravelTargets()
    if self:SurveyTravelTarget(area) then return self:TravelToSurveyZone(area) end
    local destination=self:SurveyRecallNode(area,true)
    if not destination or not GetRecallCooldown or not FastTravelToNode or not GetCurrencyAmount then return false end
    local _,premium=GetRecallCooldown()
    if premium~=0 or destination.cost>GetCurrencyAmount(CURT_MONEY,CURRENCY_LOCATION_CHARACTER) then return false end
    local data={area=area,index=destination.index,cost=destination.cost}
    self:StopSurveyBatch(); self:HideSuiteTip()
    if self.db.options.confirmSurveyTravel~=false then
        if not ZO_Dialogs_ShowDialog then return false end
        ZO_Dialogs_ShowDialog(dialogName,data)
        return true
    end
    return self:ExecuteSurveyRecall(data)
end
local rows=A.RefreshSurveyTravelRows
function A:RefreshSurveyTravelRows()
    rows(self)
    local w=self.surveyWindow; if not w or w.key~='selected' or self.db.ui.surveyMinimized then return end
    for i,label in ipairs(w.rows) do
        local button=w.travelButtons[i]
        if not label:IsHidden() and not self.db.ui.surveyMinimized then
            local destination=not self:SurveyTravelTarget(button.area) and self:SurveyRecallNode(button.area)
            if destination then button:SetText(self.coin..' '..self:SurveyRecallCostText(destination.cost)) end
            label:SetWidth(w:GetWidth()-252)
            w.amounts[i]:ClearAnchors(); w.amounts[i]:SetAnchor(TOPLEFT,w,TOPLEFT,w:GetWidth()-232,278+(i-1)*32); w.amounts[i]:SetWidth(80)
            button:ClearAnchors(); button:SetAnchor(TOPLEFT,w,TOPLEFT,w:GetWidth()-142,278+(i-1)*32); button:SetDimensions(108,30)
            button:SetFont('ZoFontGameSmall')
        end
        button:SetHandler('OnMouseEnter',function(c) self.surveyTravelHovered=c; self:ShowSuiteTip(c,TOP,self:SurveyTravelTip(c.area)) end)
        button:SetHandler('OnMouseExit',function() self.surveyTravelHovered=nil; self:HideSuiteTip() end)
    end
end
-- No timer-driven cost/hover refresh. Quotes are snapshots refreshed by
-- opening/redrawing or explicit hover; the click always validates live costs.
function A:SetSurveyTravelConfirmation(value)
    self.db.options.confirmSurveyTravel=value==true
    if self.mainSettings then self:RefreshMainSettings() end
end
local refresh=A.RefreshMainSettings
function A:RefreshMainSettings()
    refresh(self)
    if self.mainSettings and self.mainSettings.recallConfirmation then
        self.mainSettings.recallConfirmation:SetText(self:T('SURVEY_CONFIRM_SETTING')..': '..self:T(self.db.options.confirmSurveyTravel~=false and 'ON' or 'OFF'))
    end
end
local initialize=A.Initialize
function A:Initialize()
    initialize(self)
    ZO_Dialogs_RegisterCustomDialog(dialogName,{
        gamepadInfo=GAMEPAD_DIALOGS and {dialogType=GAMEPAD_DIALOGS.BASIC} or nil,
        title={text=self:T('SURVEY_WAYSHRINE')},
        mainText={text=function(d) return d.data.area..'\n'..string.format(self:T('SURVEY_RECALL_COST'),self.Integer(d.data.cost),self.coin)..'\n'..self:T('SURVEY_RECALL_QUESTION') end},
        buttons={
            {text=SI_DIALOG_CONFIRM,callback=function(d) self:ExecuteSurveyRecall(d.data) end},
            {text=SI_DIALOG_CANCEL},
        },
    })
end
