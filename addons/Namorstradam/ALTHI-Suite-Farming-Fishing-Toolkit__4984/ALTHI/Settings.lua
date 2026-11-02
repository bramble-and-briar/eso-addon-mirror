local A=ALTHarvestItems
local function L(key) return A:T(key) end
A.sourceFilters={{"all","ALL"},{"normal","RESOURCE_NODES_3E4CB5"},{"world","WORLD_OBJECTS"},
    {"creature","ANIMAL_NPC_LOOT"},{"mail","MAIL_REWARDS"},{"processing","PROCESSING"},
    {"vendor","NPC_VENDOR"},{"activity","ACTIVITIES_REWARDS"},{"unknown","UNCONFIRMED"}}
function A:FilterLayout()
    local width=self.settingsWindow:GetWidth()-64
    self.filterColumns=math.max(1,math.min(5,math.floor(width/330)))
    local layout,pending,y={},{},0
    local function Flush()
        if #pending>0 then layout[#layout+1]={kind="cards",items=pending,y=y,height=200}; pending={}; y=y+200 end
    end
    for _,data in ipairs(self:SelectionRows()) do
        if data.group then
            data.layoutY=y
            Flush(); layout[#layout+1]={kind="group",data=data,y=y,height=44}; y=y+44
            if data.expanded then
                layout[#layout+1]={kind="bulk",data=data,y=y,height=38}; y=y+38
                if data.tabs then
                    local pendingTabs,x={},0
                    for index,name in ipairs(data.tabs) do
                        local tabWidth=math.min(width,math.max(145,math.min(280,#self:T(name)*9+30)))
                        if x>0 and x+tabWidth>width then
                            layout[#layout+1]={kind="tabs",data=data,tabs=pendingTabs,y=y,height=38}; y=y+38; pendingTabs={}; x=0
                        end
                        pendingTabs[#pendingTabs+1]={index=index,name=name,x=x,width=tabWidth}; x=x+tabWidth+12
                    end
                    layout[#layout+1]={kind="tabs",data=data,tabs=pendingTabs,y=y,height=38}; y=y+38
                end
            end
        else pending[#pending+1]=data; if #pending==self.filterColumns then Flush() end end
    end
    Flush(); return layout,y
end
function A:ScrollSettings(delta)
    self.settingsOffset=math.max(0,math.min(self.settingsMaxOffset or 0,self.settingsOffset+delta)); self:RefreshSettings()
end
function A:CreateFilterCard(parent)
    local card=WINDOW_MANAGER:CreateControl(nil,parent,CT_CONTROL)
    local border=WINDOW_MANAGER:CreateControl(nil,card,CT_BACKDROP)
    border:SetAnchorFill(card); border:SetCenterColor(0.035,0.04,0.035,1)
    border:SetEdgeTexture("",1,1,1); border:SetEdgeColor(0.65,0.65,0.6,0.35)
    card.icon=WINDOW_MANAGER:CreateControl(nil,card,CT_TEXTURE)
    card.icon:SetAnchor(TOPLEFT,card,TOPLEFT,10,10); card.icon:SetDimensions(24,24)
    local function Label(y,height,font)
        local label=self:Label(card,font)
        label:SetAnchor(TOPLEFT,card,TOPLEFT,10,y); label:SetAnchor(TOPRIGHT,card,TOPRIGHT,-10,y)
        label:SetHeight(height); label:SetMaxLineCount(2); label:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE); return label
    end
    card.label=Label(7,28,"ZoFontGame")
    card.label:ClearAnchors(); card.label:SetAnchor(TOPLEFT,card,TOPLEFT,42,7)
    card.label:SetAnchor(TOPRIGHT,card,TOPRIGHT,-10,7); card.label:SetMaxLineCount(2); card.label:SetHeight(44)
    local function Toggle(_,button) if button==MOUSE_BUTTON_INDEX_LEFT then self:ToggleSelection(card.data) end end
    card.label:SetHandler("OnMouseDown",Toggle); card.icon:SetHandler("OnMouseDown",Toggle)
    card.known=Label(52,58,"ZoFontGameSmall"); card.known:SetMaxLineCount(3)
    card.level=Label(112,26,"ZoFontGameSmall")
    card.price=self:Button(card,"",200,function() self:OpenPriceEditor(card.data.id) end)
    card.price:SetFont("ZoFontGameSmall"); card.price:SetAnchor(BOTTOMLEFT,card,BOTTOMLEFT,10,-27)
    card.price:SetAnchor(BOTTOMRIGHT,card,BOTTOMRIGHT,-10,-27); card.price:SetHeight(22)
    card.priceSource=Label(167,22,"ZoFontGameSmall"); card.priceSource:SetMaxLineCount(1)
    for _,control in ipairs({card,card.label,card.icon,card.known,card.level,card.price,card.priceSource}) do
        control:SetMouseEnabled(true)


        control:SetHandler("OnMouseWheel",function(_,delta) self:ScrollSettings(-delta*80) end)
    end
    return card
end
function A:CreateFilterRow()
    local row=WINDOW_MANAGER:CreateControl(nil,self.filterViewport,CT_CONTROL); row.cards={}; row.tabs={}
    row:SetMouseEnabled(true); row:SetHandler("OnMouseWheel",function(_,delta) self:ScrollSettings(-delta*80) end)
    row.header=self:Button(row,"",500,function()
        if row.data then self.activeExpanded[row.data.key]=not row.data.expanded; self:RefreshSettings() end
    end)
    row.header:SetFont("ZoFontWinH3")
    row.separator=WINDOW_MANAGER:CreateControl(nil,row.header,CT_TEXTURE)
    row.separator:SetAnchor(BOTTOMLEFT,row.header,BOTTOMLEFT,0,0)
    row.separator:SetAnchor(BOTTOMRIGHT,row.header,BOTTOMRIGHT,0,0)
    row.separator:SetHeight(1); row.separator:SetColor(0.65,0.65,0.6,0.5)
    row.enable=self:MenuButton(row,L("SELECT_ALL"),230,function() self:SetItemsEnabled(row.data.ids,true) end)
    row.disable=self:MenuButton(row,L("DESELECT_ALL"),230,function() self:SetItemsEnabled(row.data.ids,false) end)
    row.counter=self:Label(row,"ZoFontGameSmall"); return row
end
function A:RefreshSettings()
    if not self.settingsWindow or self.settingsRefreshing then return end
    self.settingsRefreshing=true
    if self.placeGlobalButtons then self.placeGlobalButtons() end
    self.filterViewport:SetDimensions(self.settingsWindow:GetWidth()-60,self.settingsWindow:GetHeight()-234)
    local layout,total=self:FilterLayout()
    local viewportHeight=self.settingsWindow:GetHeight()-234
    self.settingsMaxOffset=math.max(0,total-viewportHeight)
    self.settingsOffset=math.max(0,math.min(self.settingsOffset,self.settingsMaxOffset))
    self.settingsSlider:SetMinMax(0,math.max(1,self.settingsMaxOffset)); self.settingsSlider:SetValue(self.settingsOffset)
    self.settingsSlider:SetHidden(self.settingsMaxOffset==0)
    local sticky
    for _,entry in ipairs(layout) do
        if entry.kind=="group" and entry.y<=self.settingsOffset then sticky=entry end
    end
    local pinned={}
    local inset=sticky and sticky.data.expanded and sticky.y<self.settingsOffset and 44 or 0
    if inset>0 then
        for _,entry in ipairs(layout) do
            if entry.y>sticky.y then
                if entry.data~=sticky.data or (entry.kind~="bulk" and entry.kind~="tabs") then break end
                pinned[#pinned+1]={kind=entry.kind,data=entry.data,tabs=entry.tabs,
                    y=entry.y,height=entry.height,pinned=true}
                inset=inset+entry.height
            end
        end
    end
    if not self.stickyHeader then
        local header=self:Button(self.settingsWindow,"",500,function()
            local data=self.stickyHeader.data
            if data then
                self.activeExpanded[data.key]=false
                self.settingsOffset=self.stickyHeader.origin
                self:RefreshSettings()
            end
        end)
        header:SetFont("ZoFontWinH3"); header:SetNormalFontColor(1,1,1,1)
        header:SetHandler("OnMouseWheel",function(_,delta) self:ScrollSettings(-delta*80) end)
        local line=WINDOW_MANAGER:CreateControl(nil,header,CT_TEXTURE)
        line:SetAnchor(BOTTOMLEFT,header,BOTTOMLEFT,0,0); line:SetAnchor(BOTTOMRIGHT,header,BOTTOMRIGHT,0,0)
        line:SetHeight(1); line:SetColor(0.65,0.65,0.6,0.5)
        self.stickyHeader=header
    end
    self.stickyHeader:SetHidden(inset==0)
    if inset>0 then
        self.stickyHeader.data=sticky.data; self.stickyHeader.origin=sticky.y
        self.stickyHeader:ClearAnchors(); self.stickyHeader:SetAnchor(TOPLEFT,self.settingsWindow,TOPLEFT,18,172)
        self.stickyHeader:SetAnchor(TOPRIGHT,self.settingsWindow,TOPRIGHT,-42,172)
        self.stickyHeader:SetHeight(38); self.stickyHeader:SetText(sticky.data.name)
    end
    self.filterViewport:ClearAnchors()
    self.filterViewport:SetAnchor(TOPLEFT,self.settingsWindow,TOPLEFT,18,172+inset)
    self.filterViewport:SetAnchor(BOTTOMRIGHT,self.settingsWindow,BOTTOMRIGHT,-42,-62)
    self.filterViewport:SetDimensions(self.settingsWindow:GetWidth()-60,viewportHeight-inset)
    local visible=pinned
    for _,entry in ipairs(layout) do
        if entry.y+entry.height>self.settingsOffset+inset and entry.y<self.settingsOffset+viewportHeight then visible[#visible+1]=entry end
    end
    for index=1,math.max(#visible,#self.selectionControls) do
        local entry,row=visible[index],self.selectionControls[index]
        if entry and not row then row=self:CreateFilterRow(); self.selectionControls[index]=row end
        if row then
            row:SetHidden(not entry)
            if entry then
                row.data=entry.data
                local parent=entry.pinned and self.settingsWindow or self.filterViewport
                row:SetParent(parent)
                row:ClearAnchors()
                row:SetAnchor(TOPLEFT,parent,TOPLEFT,entry.pinned and 18 or 0,
                    entry.pinned and (172+entry.y-sticky.y) or (entry.y-self.settingsOffset-inset))
                row:SetDimensions(self.filterViewport:GetWidth(),entry.height-6)
                row.header:SetHidden(entry.kind~="group"); row.enable:SetHidden(entry.kind~="bulk")
                row.disable:SetHidden(entry.kind~="bulk"); row.counter:SetHidden(entry.kind~="bulk")
                for _,card in ipairs(row.cards) do card:SetHidden(true) end
                for _,tab in ipairs(row.tabs) do tab:SetHidden(true) end
                local indent=entry.data and (entry.data.depth or 0)*16 or 20
                if entry.kind=="group" then
                    row.header:ClearAnchors(); row.header:SetAnchor(TOPLEFT,row,TOPLEFT,indent,0)
                    row.header:SetAnchor(TOPRIGHT,row,TOPRIGHT,0,0); row.header:SetHeight(38)
                    row.header:SetText(entry.data.name); row.header:SetNormalFontColor(1,1,1,1)
                elseif entry.kind=="bulk" then
                    row.enable:ClearAnchors(); row.enable:SetAnchor(LEFT,row,LEFT,indent+12,0)
                    row.disable:ClearAnchors(); row.disable:SetAnchor(LEFT,row,LEFT,indent+250,0)
                    row.counter:ClearAnchors(); row.counter:SetAnchor(RIGHT,row,RIGHT,-12,0)
                    row.counter:SetText(entry.data.selected.." / "..entry.data.total..L("ACTIVE"))
                elseif entry.kind=="tabs" then
                    for index,spec in ipairs(entry.tabs) do
                        local tab=row.tabs[index]
                        if not tab then
                            tab=self:MenuButton(row,"",150,function(control)
                                self.db.ui.filterTabs[control.category]=control.index
                                self.settingsOffset=control.origin or 0
                                self:RefreshSettings()
                            end)
                            row.tabs[index]=tab
                        end
                        tab.category=entry.data.category; tab.index=spec.index
                        tab.origin=entry.data.layoutY
                        tab:ClearAnchors(); tab:SetAnchor(TOPLEFT,row,TOPLEFT,spec.x,0)
                        tab:SetDimensions(spec.width,30); tab:SetText(L(spec.name)); tab:SetHidden(false)
                        tab:SetAlpha(spec.index==entry.data.activeTab and 1 or 0.65)
                    end
                else
                    local width=(self.filterViewport:GetWidth()-20)/self.filterColumns
                    for column,data in ipairs(entry.items) do
                        local card=row.cards[column]
                        if not card then card=self:CreateFilterCard(row); row.cards[column]=card end
                        card.data=data; card:SetHidden(false); card:ClearAnchors()
                        card:SetAnchor(TOPLEFT,row,TOPLEFT,20+(column-1)*width,0); card:SetDimensions(width-8,192)
                        local active=self:IsEnabled(data.id)
                        card.icon:SetTexture(data.icon); card.icon:SetAlpha(active and 1 or 0.35)
                        card.label:SetText(GetItemQualityColor(data.quality):Colorize(data.name))
                        card.label:SetAlpha(active and 1 or 0.35)
                        card.known:SetText(L("ORIGIN")..self:KnownText(data.id)); card.level:SetText(self:MaterialInfo(data.id))
                        local price,source=self:Price(data.id)
                        card.price:SetText((price~=nil and self.UnitGold(price) or L("NO_PRICE")).."  ·  "..L("EDIT"))
                        card.priceSource:SetText(source)
                    end
                end
            end
        end
    end
    for _,filter in ipairs(self.sourceFilters) do
        if filter[1]==self.db.ui.sourceFilter then self.sourceButton:SetText(L("SOURCE_3AAC03")..L(filter[2])) end
    end
    self.settingsRevision=self.catalogRevision; self.settingsDirty=false; self.filterPricesAt=self.Now(); self.settingsRefreshing=false
end
function A:OpenSourceMenu()
    if not self.sourceMenu then
        local menu=WINDOW_MANAGER:CreateTopLevelWindow("ALTHISourceMenu")
        menu:SetDimensions(360,#self.sourceFilters*34+16); menu:SetAnchor(TOPRIGHT,self.sourceButton,BOTTOMRIGHT,0,0)
        menu:SetMouseEnabled(true); menu:SetClampedToScreen(true); menu:SetDrawTier(DT_HIGH); self:Backdrop(menu)
        menu.buttons={}
        for index,spec in ipairs(self.sourceFilters) do
            local key=spec[1]
            local button=self:Button(menu,L(spec[2]),340,function()
                self.db.ui.sourceFilter=key; self.filteredExpanded=nil; self.settingsOffset=0; menu:SetHidden(true); self:RefreshSettings()
            end)
            button:SetAnchor(TOPLEFT,menu,TOPLEFT,10,8+(index-1)*34)
            menu.buttons[key]=button
        end
        menu:SetHidden(true); self.sourceMenu=menu
    end
    local menu=self.sourceMenu
    local show=menu:IsHidden()
    menu:SetHidden(not show)
    if show then menu:BringWindowToTop() end
end
function A:OpenSettings()
    if not self:TopDialog() and self:HasIntegratedSettings() and SCENE_MANAGER
        and SCENE_MANAGER.IsShowingBaseScene and SCENE_MANAGER:IsShowingBaseScene() then
        self:OpenMainSettings()
    end
    if not self.settingsWindow then
        local window=WINDOW_MANAGER:CreateTopLevelWindow("ALTHISelectionWindow"); local ui=self.db.ui
        window:SetDimensions(ui.filterWidth or 1120,ui.filterHeight or 760)
        window:SetDimensionConstraints(760,430,1800,1100); window:SetResizeHandleSize(12)
        window:SetAnchor(CENTER,GuiRoot,CENTER,0,0); window:SetMouseEnabled(true)
        window:SetMovable(true); window:SetClampedToScreen(true); self:Backdrop(window)
        local title=self:Label(window,"ZoFontWinH2")
        title:SetAnchor(TOPLEFT,window,TOPLEFT,18,12); title:SetText(self:GoldText("ALTHI").." – "..L("FILTER_LIST"))
        local help=self:Label(window,"ZoFontGameSmall")
        help:SetAnchor(TOPLEFT,window,TOPLEFT,18,49); help:SetAnchor(TOPRIGHT,window,TOPRIGHT,-18,49)
        help:SetHeight(24); help:SetText(L("CLICK_CATEGORY_EXPAND_COLLAPSE_CLICK_MATERIAL_ENABLE_DISABLE_CLICK_PRI"))
        local searchLabel=self:Label(window); searchLabel:SetAnchor(TOPLEFT,window,TOPLEFT,18,86); searchLabel:SetText(L("SEARCH"))
        local bg=WINDOW_MANAGER:CreateControl(nil,window,CT_BACKDROP)
        bg:SetAnchor(TOPLEFT,window,TOPLEFT,150,83); bg:SetAnchor(TOPRIGHT,window,TOPRIGHT,-390,83); bg:SetHeight(30)
        bg:SetCenterColor(0.08,0.11,0.08,1); bg:SetEdgeTexture("",1,1,1); bg:SetEdgeColor(0.5,0.4,0.2,1)
        local search=WINDOW_MANAGER:CreateControl("ALTHISelectionSearch",bg,CT_EDITBOX)
        search:SetAnchor(TOPLEFT,bg,TOPLEFT,8,2); search:SetAnchor(BOTTOMRIGHT,bg,BOTTOMRIGHT,-8,-2)
        search:SetFont("ZoFontGame"); search:SetMaxInputChars(80); self:EnableEdit(search); self.settingsSearch=search
        search:SetHandler("OnTextChanged",function(control) self.settingsQuery=control:GetText(); self.filteredExpanded=nil; self.settingsOffset=0; self:RefreshSettings() end)
        search:SetHandler("OnEscape",function() self:CloseFilter() end)
        self.sourceButton=self:MenuButton(window,"",350,function() self:OpenSourceMenu() end)
        self.sourceButton:SetAnchor(TOPRIGHT,window,TOPRIGHT,-28,83)
        self.selectAllButton=self:MenuButton(window,L("SELECT_ENTIRE_LIST"),330,function() self:SetItemsEnabled(self:AllMaterialIds(),true) end)
        self.selectNoneButton=self:MenuButton(window,L("DESELECT_ENTIRE_LIST"),330,function() self:SetItemsEnabled(self:AllMaterialIds(),false) end)
        local function PlaceGlobalButtons()
            local half=(window:GetWidth()-60)/2
            self.selectAllButton:ClearAnchors(); self.selectAllButton:SetAnchor(TOPLEFT,window,TOPLEFT,18,126); self.selectAllButton:SetWidth(half-12)
            self.selectNoneButton:ClearAnchors(); self.selectNoneButton:SetAnchor(TOPLEFT,window,TOPLEFT,18+half,126); self.selectNoneButton:SetWidth(half-12)
        end
        self.placeGlobalButtons=PlaceGlobalButtons; PlaceGlobalButtons()
        self.filterViewport=WINDOW_MANAGER:CreateControl(nil,window,CT_CONTROL)
        self.filterViewport:SetAnchor(TOPLEFT,window,TOPLEFT,18,172)
        self.filterViewport:SetAnchor(BOTTOMRIGHT,window,BOTTOMRIGHT,-42,-62); self.filterViewport:SetAutoRectClipChildren(true)
        self.settingsSlider=self:MakeSlider("ALTHISelectionSlider",window,172,-62,function(value)
            if not self.settingsRefreshing then self.settingsOffset=value; self:RefreshSettings() end
        end)
        self.filterClose=self:CloseIcon(window)
        window:SetHandler("OnMouseWheel",function(_,delta) self:ScrollSettings(-delta*80) end)
        window:SetHandler("OnResizeStop",function() ui.filterWidth,ui.filterHeight=window:GetWidth(),window:GetHeight(); self:RefreshSettings() end)
        window:SetHandler("OnRectWidthChanged",function() self:RefreshSettings() end)
        window:SetHandler("OnRectHeightChanged",function() self:RefreshSettings() end)
        window:SetHandler("OnHide",function()
            search:LoseFocus()
            if self.sourceMenu then self.sourceMenu:SetHidden(true) end
        end)

        self.settingsWindow=window; self.expanded=ui.expanded; self.selectionControls={}; self.settingsOffset=0
    end
    self:ShowDialog(self.settingsWindow); self:RefreshSettings()
end

function A:CloseFilter()
    if not self.settingsWindow then return end
    self:CloseDialog(self.settingsWindow)
    self.settingsSearch:LoseFocus()
    if self.sourceMenu then self.sourceMenu:SetHidden(true) end
end
