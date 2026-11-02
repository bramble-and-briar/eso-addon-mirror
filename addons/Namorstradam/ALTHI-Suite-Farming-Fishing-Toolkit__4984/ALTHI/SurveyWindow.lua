-- Resizable stock window; native survey counts remain independent of harvesting.
local A=ALTHarvestItems
local function place(c,parent,x,y,width,height)
    c:ClearAnchors(); c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); c:SetDimensions(width,height)
end
function A:SurveyRowCapacity()
    return math.max(3,math.min(25,math.floor((self.surveyWindow:GetHeight()-288)/32)))
end
function A:LayoutSurveyWindow()
    local w=self.surveyWindow; local width,height=w:GetWidth(),w:GetHeight()
    place(w.title,w,18,14,width-228,30)
    place(w.info,w,18,66,width-36,60)
    place(w.bankStatus,w,18,128,width-36,24)
    place(w.columns,w,18,168,width-36,28)
    place(w.empty,w,18,208,width-60,30)
    place(w.closed,w,18,height-74,width-36,28)
    local bw=(width-48)/2
    place(w.open,w,18,height-40,bw,30); place(w.openAll,w,30+bw,height-40,bw,30)
    place(w.scroll,w,width-22,208,12,height-288)
    local positions={52,158,height-82}
    for i,line in ipairs(w.dividers) do place(line,w,18,positions[i],width-36,1) end
end
function A:DrawSurveyList()
    local w=self.surveyWindow; if not w or not w.key then return end
    self:LayoutSurveyWindow()
    local summary=self:SurveySummary(w.key); local rows=self:SurveyInventoryRows(w.key)
    w.title:SetText(self:GoldText(self:T('SURVEY_REPORTS'))..' – '..self:T(w.craftTitle))
    w.info:SetText(self:SurveyTip(w.key)); w.bankStatus:SetText(self:SurveyBankStatus())
    local capacity=self:SurveyRowCapacity(); local width=w:GetWidth()
    self.surveyOffset=math.max(0,math.min(self.surveyOffset or 0,math.max(0,#rows-capacity)))
    local icon=self:SurveyIcons(w.key)
    for i=1,capacity do
        if not w.rows[i] then
            w.rows[i]=self:Label(w,'ZoFontGameBold'); w.rows[i]:SetMouseEnabled(false)
            w.amounts[i]=self:Label(w,'ZoFontGame'); w.amounts[i]:SetMouseEnabled(false); w.amounts[i]:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            w.rowLines[i]=WINDOW_MANAGER:CreateControl(nil,w,CT_TEXTURE)
            w.rowLines[i]:SetColor(0.65,0.65,0.6,0.3); w.rowLines[i]:SetMouseEnabled(false)
        end
        local row=rows[i+self.surveyOffset]; local y=208+(i-1)*32
        place(w.rows[i],w,18,y,width-174,30)
        place(w.amounts[i],w,width-148,y,106,30)
        place(w.rowLines[i],w,18,y+31,width-60,1)
        w.rows[i]:SetText(row and row.name or '')
        w.amounts[i]:SetText(row and (row.inventory..' '..icon) or '')
        w.rows[i]:SetHidden(not row); w.amounts[i]:SetHidden(not row); w.rowLines[i]:SetHidden(not row)
    end
    for i=capacity+1,#w.rows do w.rows[i]:SetHidden(true); w.amounts[i]:SetHidden(true); w.rowLines[i]:SetHidden(true) end
    w.empty:SetHidden(#rows>0); w.empty:SetText(self:T('SURVEY_EMPTY'))
    w.closed:SetText(string.format(self:T('SURVEY_UNIDENTIFIED'),summary.closedInventory+summary.closedBank))
    w.columns:SetText(self:T('SURVEY_STOCK_HEADING'))
    w.scroll.syncing=true; w.scroll:SetMinMax(0,math.max(0,#rows-capacity)); w.scroll:SetValue(self.surveyOffset); w.scroll.syncing=nil
    w.scroll:SetHidden(#rows<=capacity)
    self:RefreshSurveyOpening(); self:ApplyAppearance()
end
function A:OpenSurveyList(key,title)
    if self.surveyBatch and self.surveyBatch.key~=key then self:StopSurveyBatch() end
    self:UpdateSurveyStock(); self.surveyHovered=nil; self:HideSurveyTip()
    if not self.surveyWindow then
        local w=WINDOW_MANAGER:CreateTopLevelWindow('ALTHarvestItemsSurveyWindow'); self.surveyWindow=w
        local ui=self.db.ui
        w:SetDimensions(ui.surveyWidth or 560,ui.surveyHeight or 550)
        w:SetDimensionConstraints(480,400,1200,1100); w:SetResizeHandleSize(12)
        w:SetAnchor(CENTER,GuiRoot,CENTER,0,0); w:SetMouseEnabled(true); w:SetMovable(true); w:SetClampedToScreen(true); self:Backdrop(w)
        w.title=self:Label(w,'ZoFontWinH3')
        w.opacity=self:OpacityControl(w,'surveyBackgroundAlpha'); w.opacity:SetAnchor(TOPRIGHT,w,TOPRIGHT,-62,17)
        w.info=self:Label(w,'ZoFontGameBold'); w.info:SetMaxLineCount(3)
        w.bankStatus=self:Label(w,'ZoFontGameSmall'); w.columns=self:Label(w,'ZoFontGameBold')
        w.rows={}; w.amounts={}; w.rowLines={}; w.dividers={}
        for i=1,3 do
            local line=WINDOW_MANAGER:CreateControl(nil,w,CT_TEXTURE); line:SetColor(0.65,0.65,0.6,0.45); line:SetMouseEnabled(false); w.dividers[i]=line
        end
        w.empty=self:Label(w); w.empty:SetMouseEnabled(false); w.closed=self:Label(w,'ZoFontGameBold')
        w.open=self:MenuButton(w,'',240,function() self:OpenSurveyEnvelope() end)
        w.openAll=self:MenuButton(w,'',240,function() self:StartSurveyOpening(true) end)
        for _,entry in ipairs({{w.open,'SURVEY_OPEN_ONE_TIP'},{w.openAll,'SURVEY_OPEN_ALL_TIP'}}) do
            local label=entry[2]
            entry[1]:SetHandler('OnMouseEnter',function(control) self:ShowSuiteTip(control,TOP,self:T(label)) end)
            entry[1]:SetHandler('OnMouseExit',function() self:HideSuiteTip() end)
        end
        w.scroll=WINDOW_MANAGER:CreateControl(nil,w,CT_SLIDER)
        w.scroll:SetOrientation(ORIENTATION_VERTICAL); w.scroll:SetMouseEnabled(true); w.scroll:SetValueStep(1)
        w.scroll:SetThumbTexture('EsoUI/Art/Miscellaneous/scrollbox_elevator.dds','EsoUI/Art/Miscellaneous/scrollbox_elevator_disabled.dds','EsoUI/Art/Miscellaneous/scrollbox_elevator.dds',12,30,0,0,1,1)
        local wheel=function(_,delta) self.surveyOffset=(self.surveyOffset or 0)-delta; self:DrawSurveyList() end
        w:SetHandler('OnMouseWheel',wheel); w.scroll:SetHandler('OnMouseWheel',wheel)
        w.scroll:SetHandler('OnValueChanged',function(control,value) if not control.syncing then self.surveyOffset=math.floor(value+0.5); self:DrawSurveyList() end end)
        w:SetHandler('OnResizeStop',function(control)
            ui.surveyWidth,ui.surveyHeight=control:GetWidth(),control:GetHeight(); self:DrawSurveyList()
        end)
        w:SetHandler('OnRectWidthChanged',function() self:DrawSurveyList() end)
        w:SetHandler('OnRectHeightChanged',function() self:DrawSurveyList() end)
        w:SetHandler('OnHide',function() self:StopSurveyBatch() end)
        -- Persistent HUD window: deliberately absent from ESC-managed top levels.
        w:SetHidden(true); self:CloseIcon(w)
    end
    self.surveyWindow.key=key; self.surveyWindow.craftTitle=title; self.surveyOffset=0
    self.db.ui.surveyProfession=key; self.db.ui.surveyVisible=true; self.surveyRequestedVisible=true
    self:DrawSurveyList(); self:UpdateSurveyVisibility(); self:EnsureSurveyTicker()
    if not self.surveyRestoring then self:ReleaseSuiteMouse() end
end
