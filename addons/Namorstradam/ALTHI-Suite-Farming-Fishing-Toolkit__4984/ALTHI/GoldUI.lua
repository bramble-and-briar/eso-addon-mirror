local A=ALTHarvestItems
local function L(key) return A:T(key) end
function A:RefreshGoldHeader()
    if not self.goldHeaderLabels then return end
    local active=self.db.ui.activity=='gold'
    for _,control in ipairs({self.status,self.sessionTotal,self.bagTotal,self.rate,self.guildStatus,self.resumeStatus}) do
        control:SetHidden(active)
    end
    if not active then self.bagTotal:SetHidden(not self.db.ui.showStock) end
    for _,control in ipairs(self.goldHeaderLabels) do control:SetHidden(not active) end
    if not active then return end
    local g=self:GoldState(); local current=g.characters[self:GoldCharacterId()]
    local money=self:GoldInboxAmount(); local post
    if money and money>0 then post=string.format(L('GOLD_HEADER_POST_GOLD'),self.Gold(money))
    elseif money==nil and self:GoldHasMailNotice() then post=L('GOLD_HEADER_POST_UNKNOWN')
    else post=L('GOLD_HEADER_POST_NONE') end
    local texts={L('GOLD_HEADER_ACCOUNT')..self.Gold(self:GoldWealth()),
        L('GOLD_HEADER_BANK')..(g.bankKnown and self.Gold(g.bank) or '—'),
        L('GOLD_HEADER_INVENTORY')..(current and self.Gold(current.balance) or '—'),post}
    local width=(self.window:GetWidth()-44)/2
    for i,control in ipairs(self.goldHeaderLabels) do
        control:ClearAnchors(); control:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+((i-1)%2)*(width+8),i<=2 and 60 or 84)
        control:SetDimensions(width,20); control:SetText(texts[i])
    end
end
function A:GoldChooseCharacter(control)
    ClearMenu()
    local entries={}
    if GetNumCharacters and GetCharacterInfo then
        for i=1,GetNumCharacters() do
            local name,_,_,_,_,_,id=GetCharacterInfo(i)
            if id then entries[#entries+1]={id=tostring(id),name=zo_strformat('<<1>>',name)} end
        end
    end
    if #entries==0 then
        for id,name in pairs(self:GoldRoster()) do entries[#entries+1]={id=id,name=name} end
        table.sort(entries,function(a,b) return a.name<b.name end)
    end
    for _,entry in ipairs(entries) do
        local id=entry.id
        AddMenuItem(entry.name,function() self.db.ui.goldCharacter=id; self.goldOffset=0; self:QueueRefresh() end)
    end
    ShowMenu(control)
end
local oldCreate=A.CreateWindow
function A:CreateWindow()
    oldCreate(self)
    self.goldHeaderLabels={}
    for i=1,4 do self.goldHeaderLabels[i]=self:Label(self.window,'ZoFontGameSmall') end
    local tab=self:MenuButton(self.window,L('GOLD_MODULE'),140,function() self:SelectActivity('gold') end)
    tab:SetAnchor(TOPLEFT,self.window,TOPLEFT,314,114); self.activityButtons[3]=tab
    -- Make the existing activity buttons explicit manual selections as well.
    for i,key in ipairs({'resources','fishing','gold'}) do
        local activity=key
        self.activityButtons[i]:SetHandler('OnClicked',function()
            self.goldManualSelection=true; self:SelectActivity(activity); self.goldManualSelection=nil
        end)
    end
    self.goldPanel=WINDOW_MANAGER:CreateControl(nil,self.window,CT_CONTROL)
    local panel=self.goldPanel
    panel:SetAnchor(TOPLEFT,self.window,TOPLEFT,18,174); panel:SetAnchor(BOTTOMRIGHT,self.window,BOTTOMRIGHT,-18,-18)
    panel:SetMouseEnabled(true); panel:SetHandler('OnMouseWheel',function(_,delta) self.goldOffset=math.max(0,(self.goldOffset or 0)-delta*3); self:QueueRefresh() end)
    self.goldTabs={}
    for i,spec in ipairs({{'GOLD_OVERVIEW','overview'},{'GOLD_CHARACTERS','characters'}}) do
        local key=spec[2]
        self.goldTabs[i]=self:MenuButton(panel,L(spec[1]),140,function() self.db.ui.goldTab=key; self.goldOffset=0; self:QueueRefresh() end)
    end
    self.goldChoose=self:MenuButton(panel,L('GOLD_CHOOSE_CHARACTER'),280,function(control) self:GoldChooseCharacter(control) end)
    self.goldChoose:SetAnchor(TOPLEFT,panel,TOPLEFT,0,38)
    self.goldPeriodButton=self:MenuButton(panel,L('GOLD_PERIOD_ALL'),280,function(control) self:GoldChoosePeriod(control) end)
    self.goldPeriodButton:SetAnchor(TOPLEFT,panel,TOPLEFT,0,38)
    self.goldExpand=self:MenuButton(panel,L('GOLD_INCOME_SOURCES'),280,function()
        local field='goldShowDetails'
        self.db.ui[field]=not self.db.ui[field]; self.goldOffset=0; self:QueueRefresh()
    end)
    self.goldExpand:SetAnchor(TOPLEFT,panel,TOPLEFT,0,38)
    self.goldInfo=self:MenuButton(panel,'?',30,function() end)
    self.goldLines={}
    self.goldValues={}
    self.goldHero=WINDOW_MANAGER:CreateControl(nil,panel,CT_CONTROL)
    self.goldScroll=self:MakeSlider('ALTHIGoldScrollbar',panel,82,-44,function(value) self.goldOffset=value; self:QueueRefresh() end)
    self.goldActions={self:MenuButton(panel,L('RESET'),100,function() ZO_Dialogs_ShowDialog('ALTHI_GOLD_RESET') end)}
    self:Refresh()
end
function A:RefreshGoldPanel()
    if not self.goldPanel then return end
    self:RefreshGoldHeader()
    local active=self.db.ui.activity=='gold'; local minimized=self.db.ui.minimized
    self.goldPanel:SetHidden(not active or minimized==true)
    for i,button in ipairs(self.activityButtons) do
        local keys={'resources','fishing','gold'}
        button:SetAlpha((self.db.ui.activity or 'resources')==keys[i] and 1 or 0.55)
        local width=(self.window:GetWidth()-52)/3
        button:ClearAnchors(); button:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+(i-1)*(width+8),114); button:SetWidth(width)
    end
    if not active then return end
    for _,controls in ipairs({self.rowControls,self.headers,self.dividers,self.runButtons}) do for _,c in ipairs(controls) do c:SetHidden(true) end end
    for _,c in ipairs({self.sessionGroup,self.stockGroup,self.empty,self.slider,self.stockButton,self.priceNote}) do if c then c:SetHidden(true) end end
    if minimized then return end
    self:RefreshSuiteGold()
end
local refresh=A.Refresh
function A:Refresh() refresh(self); self:RefreshGoldPanel() end
