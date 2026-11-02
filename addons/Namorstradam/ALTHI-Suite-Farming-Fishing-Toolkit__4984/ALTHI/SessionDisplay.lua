-- Header room for both clocks; native anchoring, no text on raw Button reads.
local A=ALTHarvestItems
function A:SetTabEmphasis(button,active)
    if not button then return end
    button:SetAlpha(active and 1 or 0.55)
    for _,line in ipairs(button.menuLines or {}) do
        if active then line:SetColor(1,1,1,0.95) else line:SetColor(0.65,0.65,0.6,0.45) end
    end
end
local function gathering(self)
    return self.db.ui.activity=='resources' or self.db.ui.activity=='fishing'
end
local top=A.TableTop
function A:TableTop() return top(self)+(self.db.ui.activity=='resources' and 24 or 0) end
local tools=A.FishingToolsTop
function A:FishingToolsTop() return tools(self)+(gathering(self) and 24 or 0) end
local function shift(control,parent)
    if not control or not control.GetAnchor then return end
    local anchors={}
    for index=0,1 do
        local valid,point,relative,relativePoint,x,y,constrains=control:GetAnchor(index)
        if valid then
            anchors[#anchors+1]={point,relative,relativePoint,x,y+(relative==parent and 24 or 0),constrains}
        end
    end
    if #anchors>0 then
        control:ClearAnchors()
        for _,a in ipairs(anchors) do control:SetAnchor(unpack(a)) end
    end
end
-- Absolute final coordinates also apply to direct selection refreshes.
function A:LayoutGatheringProfessions()
    if not self.professionButtons or not self.surveyButtons then return end
    local width=self.window:GetWidth()-36; local step=width/(#self.professionSpecs+2)
    local function place(c,x,y,h)
        if not c then return end
        c:ClearAnchors(); c:SetAnchor(TOPLEFT,self.window,TOPLEFT,x,y); c:SetDimensions(step,h)
    end
    for i,b in ipairs(self.professionButtons) do
        place(b,18+(i-1)*step,216,40)
        place(self.surveyButtons[i],18+(i-1)*step,250,26)
    end
    place(self.allFiltersButton,18+#self.professionSpecs*step,220,32)
    place(self.suiteFilter,18+(#self.professionSpecs+1)*step,220,32)
    -- Direct profession refresh used to restore obsolete two-column tab anchors.
    for i,c in ipairs({self.activityButtons[1],self.activityButtons[2],self.refiningTab}) do
        c:ClearAnchors(); c:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+(i-1)*(width+8)/3,176)
        c:SetDimensions((width-16)/3,30)
    end
end
local professions=A.RefreshProfessions
function A:RefreshProfessions() professions(self); self:LayoutGatheringProfessions() end
local surveys=A.RefreshSurveys
function A:RefreshSurveys() surveys(self); self:LayoutGatheringProfessions() end
local refresh=A.Refresh
function A:Refresh()
    refresh(self)
    if not self.window or not self.suiteButtons then return end
    local extra=gathering(self)
    if not self.sessionClocks then self.sessionClocks=self:Label(self.window,'ZoFontGameSmall') end
    local c=self.sessionClocks; c:ClearAnchors(); c:SetAnchor(TOPLEFT,self.window,TOPLEFT,18,110)
    c:SetDimensions(self.window:GetWidth()-36,27); c:SetVerticalAlignment(TEXT_ALIGN_CENTER); c:SetHidden(not extra)
    if extra then
        local s=self.db.session
        c:SetText(self:SessionClockText())
        local _,totals=self:RowsAndTotals()
        self.status:SetText(self.Integer(totals.sessionCount)..' '..self:T('SESSION_UNITS'))
        for _,list in ipairs({self.suiteButtons,self.activityButtons}) do
            for _,control in ipairs(list or {}) do shift(control,self.window) end
        end
        for _,control in ipairs({self.refiningTab,self.professionDivider}) do shift(control,self.window) end
        if self.db.ui.activity=='fishing' then
            shift(self.fishingInfo,self.window)
            for _,control in ipairs(self.fishingCards) do shift(control,self.window) end
            for _,control in ipairs(self.fishingLines) do shift(control,self.window) end
            -- Tools and item table already use the shifted dynamic top functions.
        end
    end
    if extra then self:LayoutGatheringProfessions() end
    if self.db.ui.activity=='gold' then
        for _,b in ipairs(self.suiteButtons) do shift(b,self.window) end
    end
    if not self.tradeHeader then self.tradeHeader=self:Label(self.window,'ZoFontGameSmall') end
    local t=self.tradeHeader; t:ClearAnchors(); t:SetAnchor(TOPLEFT,self.window,TOPLEFT,18,110)
    t:SetDimensions(self.window:GetWidth()-36,27); t:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    t:SetHidden(self.db.ui.activity~='gold')
    if self.db.ui.activity=='gold' then
        local trade=self:GoldTradeSummary(); local n=trade.value+trade.refunds-trade.costs-trade.fees
        t:SetText(self:T('GOLD_TRADE_BALANCE')..': '..(trade.unavailable and '—' or (n<0 and '|cDD5555' or '')..self.Gold(n)..(n<0 and '|r' or ''))..' · '..self:T(self:GoldPeriodKey()))
    end
    if self.db.ui.minimized then
        local height=174
        self.window:SetDimensionConstraints(self.db.ui.showStock and 620 or 480,height,1800,height)
        if self.window:GetHeight()~=height then self.window:SetHeight(height) end
    end
    self:SetTabEmphasis(self.activityButtons[1],self.db.ui.activity=='resources')
    self:SetTabEmphasis(self.activityButtons[2],self.db.ui.activity=='fishing')
    self:SetTabEmphasis(self.refiningTab,self.db.ui.activity=='refining')
    for i,button in ipairs(self.goldTabs or {}) do self:SetTabEmphasis(button,(self.db.ui.goldTab or 'overview')==({'overview','characters'})[i]) end
    for i,button in ipairs(self.refiningViews or {}) do self:SetTabEmphasis(button,(i==2)==(self.db.ui.refiningLifetime==true)) end
end
local create=A.CreateWindow
function A:CreateWindow() create(self); self:Refresh() end
