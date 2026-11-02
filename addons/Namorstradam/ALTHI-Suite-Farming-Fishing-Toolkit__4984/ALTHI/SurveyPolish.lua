local A=ALTHarvestItems
local compactHeight=266
local function place(c,w,x,y,width,height)
    c:ClearAnchors(); c:SetAnchor(TOPLEFT,w,TOPLEFT,x,y); c:SetDimensions(width,height)
end
function A:SurveyZoneBase(name)
    local text=(type(name)=='string' and name or ''):gsub('%^.*','')
    local roman={'I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII'}
    for i,value in ipairs({'Ⅰ','Ⅱ','Ⅲ','Ⅳ','Ⅴ','Ⅵ','Ⅶ','Ⅷ','Ⅸ','Ⅹ','Ⅺ','Ⅻ'}) do text=text:gsub(value,' '..roman[i]) end
    for _,space in ipairs({' ',' ',' '}) do text=text:gsub(space,' ') end
    return (text:gsub('^[ \t\r\n]+',''):gsub('[ \t\r\n]+$',''):gsub('[ \t\r\n]+[IVXLCDM]+$',''):gsub('[ \t\r\n]+$',''))
end
local describe=A.DescribeSurvey
function A:DescribeSurvey(id)
    local key,area,closed=describe(self,id)
    if key and area then area=self:SurveyZoneBase(area) end
    return key,area,closed
end
function A:OpenSurveyMap(area)
    if not self:SurveyWindowActive() or not GetNumZones or not GetZoneNameByIndex or not GetZoneId
        or not GetMapIndexByZoneId or not WORLD_MAP_MANAGER or not WORLD_MAP_MANAGER.SetMapByIndex
        or not WORLD_MAP_MANAGER.IsMapChangingAllowed or not WORLD_MAP_MANAGER:IsMapChangingAllowed()
        or not ZO_WorldMap_ShowWorldMap then return false end
    local key=zo_strlower(self:SurveyZoneBase(area))
    for i=1,GetNumZones() do
        if zo_strlower(self:SurveyZoneBase(GetZoneNameByIndex(i)))==key then
            local index=GetMapIndexByZoneId(GetZoneId(i))
            if not index then return false end
            self:StopSurveyBatch(); self:HideSuiteTip()
            ZO_WorldMap_ShowWorldMap(); WORLD_MAP_MANAGER:SetMapByIndex(index)
            return true
        end
    end
    return false
end
function A:ToggleSurveyMinimized()
    local w=self.surveyWindow; if not w then return end
    local ui=self.db.ui; local top,left=w:GetTop(),w:GetLeft(); local height=w:GetHeight()
    if not ui.surveyMinimized then
        ui.surveyHeight=height
        ui.surveyFoldEdge=(top+height/2>=(GuiRoot:GetHeight() or 1080)/2) and 'bottom' or 'top'
        self:StopSurveyBatch()
    end
    ui.surveyMinimized=not ui.surveyMinimized
    local target=ui.surveyMinimized and compactHeight or math.min(1100,math.max(502,ui.surveyHeight or 550))
    self.surveyResizing=true
    w:SetDimensionConstraints(480,ui.surveyMinimized and compactHeight or 502,1200,ui.surveyMinimized and compactHeight or 1100)
    w:SetHeight(target); self.surveyResizing=nil
    if ui.surveyFoldEdge=='bottom' then top=top+height-target end
    top=math.max(0,math.min(top,math.max(0,(GuiRoot:GetHeight() or 1080)-target)))
    w:ClearAnchors(); w:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,left,top)
    self:DrawSurveyList()
    if self.SaveSurveyPosition then self:SaveSurveyPosition() end
end
local layout=A.LayoutSurveyWindow
function A:LayoutSurveyWindow()
    layout(self)
    local w=self.surveyWindow; if w.key~='selected' then return end
    local width,height=w:GetWidth(),w:GetHeight(); local minimized=self.db.ui.surveyMinimized==true
    if not w.minimize then
        w.minimize=self:MenuButton(w,'^',30,function() self:ToggleSurveyMinimized() end)
        w.professionCounts={}
        w:SetHandler('OnHide',function()
            self:StopSurveyBatch(); self:HideSuiteTip()
            self.surveyTravelHovered=nil; self.professionHovered=nil; self.allFiltersHovered=nil
        end)
        w:SetHandler('OnResizeStop',function(c)
            self.db.ui.surveyWidth=c:GetWidth()
            if not self.db.ui.surveyMinimized then self.db.ui.surveyHeight=c:GetHeight() end
            self:DrawSurveyList()
        end)
    end
    w.title:SetFont(width<620 and 'ZoFontGameBold' or 'ZoFontWinH3')
    w.title:SetWidth(width-250)
    w.opacity:ClearAnchors(); w.opacity:SetAnchor(TOPRIGHT,w,TOPRIGHT,-92,17)
    place(w.minimize,w,width-78,12,30,30); w.minimize:SetText(minimized and 'v' or '^')
    local step=(width-36)/7
    for i,spec in ipairs(self.professionSpecs) do
        if i>6 then break end
        local count=w.professionCounts[i]
        if not count then
            count=self:Button(w,'',step,function() end); count:SetFont('ZoFontGameSmall')
            local key=spec[1]
            count:SetHandler('OnMouseEnter',function(c) self:ShowSuiteTip(c,TOP,self:SurveyTip(key)) end)
            count:SetHandler('OnMouseExit',function() self:HideSuiteTip() end)
            w.professionCounts[i]=count
        end
        local text=tostring(self:SurveySummary(spec[1]).inventory)
        count:SetText(text); count:SetAlpha(w.professions[i].selected>0 and 1 or 0.3)
        place(count,w,18+(i-1)*step,100,step,26)
    end
    place(w.info,w,18,138,width-36,54)
    place(w.closed,w,18,height-108,width-36,28)
    place(w.bankStatus,w,18,height-76,width-36,24)
    place(w.dividers[3],w,18,height-120,width-36,1)
    place(w.scroll,w,width-22,278,12,math.max(1,height-400))
    w.columns:SetHidden(true); w.empty:SetHidden(minimized)
    w.bankStatus:SetHidden(minimized); w.closed:SetHidden(minimized)
    w.dividers[3]:SetHidden(minimized)
end
local capacity=A.SurveyRowCapacity
function A:SurveyRowCapacity()
    if self.surveyWindow.key=='selected' then return math.max(3,math.min(25,math.floor((self.surveyWindow:GetHeight()-400)/32))) end
    return capacity(self)
end
local draw=A.DrawSurveyList
function A:DrawSurveyList()
    draw(self)
    local w=self.surveyWindow; if not w or w.key~='selected' then return end
    local s=self:SurveySummary('selected'); local bank=self.db.surveyBank and tostring(s.closedBank) or '—'
    w.closed:SetText(string.format(self:T('SURVEY_UNIDENTIFIED_SPLIT'),s.closedInventory,bank))
    local minimized=self.db.ui.surveyMinimized==true
    w.closed:SetHidden(minimized); w.bankStatus:SetHidden(minimized)
    w.columns:SetHidden(true); w.empty:SetHidden(minimized or #self:SurveyInventoryRows('selected')>0)
    w.open:SetHidden(minimized); w.openAll:SetHidden(minimized); w.scroll:SetHidden(minimized or w.scroll:IsHidden())
    for i,row in ipairs(w.rows) do
        if minimized then row:SetHidden(true); w.amounts[i]:SetHidden(true); w.rowLines[i]:SetHidden(true); w.travelButtons[i]:SetHidden(true) end
        row:SetMouseEnabled(not minimized)
        row:SetHandler('OnMouseUp',function(c,button) if button==MOUSE_BUTTON_INDEX_LEFT then self:OpenSurveyMap(c:GetText()) end end)
    end
end
local open=A.OpenSurveyOverview
function A:OpenSurveyOverview()
    local minimized=self.db.ui.surveyMinimized
    local expandedHeight=self.db.ui.surveyHeight or 550
    self.db.ui.surveyMinimized=false; open(self)
    if minimized then self.surveyWindow:SetHeight(expandedHeight); self:ToggleSurveyMinimized()
    else
        local w=self.surveyWindow; w:SetDimensionConstraints(480,502,1200,1100)
        if w:GetHeight()<502 then w:SetHeight(502) end
    end
    self:DrawSurveyList()
end
local active=A.SurveyWindowActive
function A:SurveyWindowActive()
    return active(self) and not self.surveyResizing
end
local opening=A.RefreshSurveyOpening
function A:RefreshSurveyOpening()
    local w=self.surveyWindow; if not w or not w.open then return end
    if self.db.ui.surveyMinimized then
        w.open:SetEnabled(false); w.openAll:SetEnabled(false)
        w.open:SetAlpha(0.35); w.openAll:SetAlpha(0.35)
        return
    end
    opening(self)
    local slot,_,cooldown=self:FindSurveyEnvelope(w.key)
    local minimized=self.db.ui.surveyMinimized==true
    -- Native CT_BUTTON exposes SetEnabled, not IsEnabled (the latter belongs
    -- to other API object types). Use our actual eligibility, never read back.
    local ready=slot~=nil and (cooldown or 0)==0 and not self.surveyOpening and not minimized
    local one=ready and not self.surveyBatch
    local all=not minimized and (self.surveyBatch~=nil or (ready and GetItemUseType~=nil))
    w.open:SetEnabled(one==true); w.open:SetAlpha(one and 1 or 0.35)
    w.openAll:SetEnabled(all==true); w.openAll:SetAlpha(all and 1 or 0.35)
end
local refresh=A.Refresh
function A:Refresh()
    refresh(self)
    if self.mainOpacity then
        self.mainOpacity:ClearAnchors(); self.mainOpacity:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,-94,16)
        self.titleLabel:SetWidth(self.window:GetWidth()-254)
        self.titleLabel:SetFont(self.window:GetWidth()<620 and 'ZoFontGameBold' or 'ZoFontWinH2')
    end
end
local visibility=A.UpdateWindowVisibility
function A:UpdateWindowVisibility()
    visibility(self)
    if not self:SuiteBaseScene() and not self:TopDialog() then
        self:HideSuiteTip(); self.professionHovered=nil; self.allFiltersHovered=nil; self.surveyTravelHovered=nil
    end
end
