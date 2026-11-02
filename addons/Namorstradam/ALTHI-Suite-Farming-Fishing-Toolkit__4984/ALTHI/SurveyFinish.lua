-- Area first, stock in the footer; tie-breaking uses the existing roster cache.
local A=ALTHarvestItems
local function place(c,w,x,y,width,height)
    c:ClearAnchors(); c:SetAnchor(TOPLEFT,w,TOPLEFT,x,y); c:SetDimensions(width,height)
end
local rows=A.SurveyInventoryRows
function A:SurveyInventoryRows(key)
    local result=rows(self,key); local free={}
    for _,row in ipairs(result) do free[row.name]=self:SurveyTravelTarget(row.name)~=nil end
    table.sort(result,function(a,b)
        if a.inventory~=b.inventory then return a.inventory>b.inventory end
        if free[a.name]~=free[b.name] then return free[a.name] end
        local an,bn=zo_strlower(a.name),zo_strlower(b.name)
        return an==bn and a.name<b.name or an<bn
    end)
    return result
end
local capacity=A.SurveyRowCapacity
function A:SurveyRowCapacity()
    if self.surveyWindow.key=='selected' then return math.max(3,math.min(25,math.floor((self.surveyWindow:GetHeight()-390)/32))) end
    return capacity(self)
end
local layout=A.LayoutSurveyWindow
function A:LayoutSurveyWindow()
    layout(self)
    local w=self.surveyWindow; if w.key~='selected' then return end
    local width,height=w:GetWidth(),w:GetHeight(); local minimized=self.db.ui.surveyMinimized==true
    place(w.areaTitle,w,18,138,width-36,24)
    place(w.areaCounts,w,18,166,width-36,24)
    place(w.dividers[2],w,18,196,width-36,1)
    place(w.empty,w,18,208,width-60,30)
    place(w.dividers[3],w,18,height-182,width-36,1)
    place(w.info,w,18,height-170,width-36,48)
    place(w.closed,w,18,height-114,width-36,28)
    place(w.bankStatus,w,18,height-82,width-36,24)
    place(w.scroll,w,width-22,208,12,math.max(1,height-390))
    w.info:SetHidden(minimized)
    w.areaCounts:SetMouseEnabled(true)
    w.areaCounts:SetHandler('OnMouseEnter',function(c) self:ShowSuiteTip(c,TOP,self:T('SURVEY_EYE_LEGEND')) end)
    w.areaCounts:SetHandler('OnMouseExit',function() self:HideSuiteTip() end)
end
local travel=A.RefreshSurveyTravelRows
function A:RefreshSurveyTravelRows()
    travel(self)
    local w=self.surveyWindow; if not w or w.key~='selected' or self.db.ui.surveyMinimized then return end
    for i,label in ipairs(w.rows) do
        local y=208+(i-1)*32
        place(label,w,18,y,w:GetWidth()-252,30)
        place(w.amounts[i],w,w:GetWidth()-232,y,80,30)
        place(w.rowLines[i],w,18,y+31,w:GetWidth()-60,1)
        if w.travelButtons[i] then place(w.travelButtons[i],w,w:GetWidth()-142,y,108,30) end
    end
end
local draw=A.DrawSurveyList
function A:DrawSurveyList()
    -- Build before sorting on first open/roster refresh; no native roster work
    -- in an idle minimized HUD. Travel itself still revalidates before use.
    if self.surveyWindow and self.surveyWindow.key and not self.db.ui.surveyMinimized
        and (not self.surveyTravelAt or self.Now()-self.surveyTravelAt>30
        or self.surveyTravelDirty and self.Now()-self.surveyTravelAt>=5) then self:BuildSurveyTravelTargets() end
    draw(self)
    self:RefreshCompactSurveyTarget()
end

-- Reuse the sorted inventory list and the guarded travel action in compact mode.
function A:RefreshCompactSurveyTarget()
    local w=self.surveyWindow; if not w or not w.key then return end
    if not w.nextArea then
        w.nextArea=self:Label(w,'ZoFontGameBold')
        w.nextCaption=self:Label(w,'ZoFontGameSmall')
        w.nextTravel=self:Button(w,'',108,function(c) if c.area then self:RequestSurveyTravel(c.area) end end)
        w.nextTravel:SetHandler('OnMouseEnter',function(c) if c.area then self:ShowSuiteTip(c,TOP,self:SurveyTravelTip(c.area)) end end)
        w.nextTravel:SetHandler('OnMouseExit',function() self:HideSuiteTip() end)
    end
    local minimized=self.db.ui.surveyMinimized==true
    local row=minimized and self:SurveyInventoryRows('selected')[1]
    w.nextArea:SetHidden(not row); w.nextTravel:SetHidden(not row); w.nextCaption:SetHidden(not row)
    if not row then w.nextTravel.area=nil; return end
    place(w.nextCaption,w,18,201,w:GetWidth()-36,22); w.nextCaption:SetText(self:T('SURVEY_NEXT_AREA'))
    place(w.nextArea,w,18,225,w:GetWidth()-160,29)
    place(w.nextTravel,w,w:GetWidth()-136,225,108,29)
    w.nextArea:SetText(row.name..' · '..self.Integer(row.inventory))
    w.nextTravel.area=row.name
    local target=self:SurveyTravelTarget(row.name)
    local node=not target and self:SurveyRecallNode(row.name)
    w.nextTravel:SetText(target and '|t24:24:EsoUI/Art/Icons/poi/poi_wayshrine_complete.dds|t'
        or self.coin..(node and ' '..self:SurveyRecallCostText(node.cost) or ' —'))
    w.nextTravel:SetEnabled(target~=nil or node~=nil)
end
local initialize=A.Initialize
function A:Initialize()
    initialize(self)
    EVENT_MANAGER:RegisterForEvent('ALTHarvestItemsSurveyRestore',EVENT_PLAYER_ACTIVATED,function()
        EVENT_MANAGER:UnregisterForEvent('ALTHarvestItemsSurveyRestore',EVENT_PLAYER_ACTIVATED)
        if self.db.ui.surveyVisible then
            self.surveyRestoring=true
            self:OpenSurveyOverview()
            self.surveyRestoring=nil
            self:UpdateSurveyVisibility()
        end
    end)
end
