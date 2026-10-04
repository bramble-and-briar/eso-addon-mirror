local U={}; U.__index=U; PBTrade.UI=U
local C,D,M=PBTrade.Config,PBTrade.Data,PBTrade.Model
local T=C.theme
local ink=T.text; local light=T.text
local COMPANY_NAME_DIALOG="PBTRADE_COMPANY_NAME_GAMEPAD"
local layoutRecords
-- Match PBsWarTable: resolve the localized font object to its actual descriptor.
local function applyFont(control,size)
    local valid={[18]=true,[20]=true,[22]=true,[25]=true,[27]=true,[34]=true,[36]=true,[42]=true,[54]=true,[61]=true}
    size=valid[size] and size or 27
    local name="ZoFontGamepad"..size
    local source=_G[name]
    if source and source.GetFontInfo then
        local face,actualSize=source:GetFontInfo()
        if type(face)=="string" and face~="" and type(actualSize)=="number" and actualSize>0 then
            control:SetFont(face.."|"..actualSize.."|soft-shadow-thick")
            return
        end
    end
    control:SetFont(name)
end
local function gold(value)
    return M.FormatMoney(value)
end
local function remember(c,parent,x,y,w,h)
    layoutRecords[#layoutRecords+1]={control=c,parent=parent,x=x,y=y,w=w,h=h}
    return c
end
local function box(parent,x,y,w,h,color,edge)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_BACKDROP)
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); c:SetDimensions(w,h)
    c:SetCenterColor(unpack(color or T.panel))
    c:SetEdgeColor(unpack(edge or T.edge)); c:SetEdgeTexture("",1,1,1)
    return remember(c,parent,x,y,w,h)
end
local function label(parent,x,y,w,h,text,size,color)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); c:SetDimensions(w,h)
    applyFont(c,size or 22); c:SetColor(unpack(color or light))
    c:SetDrawLayer(DL_TEXT)
    c:SetText(text or ""); return remember(c,parent,x,y,w,h)
end
local function panel(parent,x,y,w,h)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_CONTROL)
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); c:SetDimensions(w,h); return remember(c,parent,x,y,w,h)
end
local function texture(parent,x,y,w,h,name,color)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_TEXTURE)
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); c:SetDimensions(w,h)
    PBTrade.Assets.Apply(c,name); c:SetColor(unpack(color or {1,1,1,1}))
    c:SetDrawLayer(DL_BACKGROUND)
    return remember(c,parent,x,y,w,h)
end
local function plaque(parent,x,y,w,h)
    local base=box(parent,x,y,w,h,{.04,.05,.03,1},T.edge)
    local art=texture(base,0,0,w,h,"wood_frame",{1,1,1,.72})
    return base,art
end
function U.New(app)
    local self=setmetatable({app=app,rows={},pins={},coinControls={{},{}},nextMove=0,refreshMarkers={}},U)
    self.root=WINDOW_MANAGER:CreateTopLevelWindow("PBTradeWindow")
    self.root:SetAnchorFill(GuiRoot); self.root:SetHidden(true)
    layoutRecords={}
    local scenery=texture(self.root,0,0,1,1,"treasury"); scenery:SetAnchorFill(self.root)
    local veil=box(self.root,0,0,1,1,{.015,.023,.02,.20},{0,0,0,0}); veil:SetAnchorFill(self.root)
    local p=panel(self.root,0,0,C.ui.width,C.ui.height); self.content=p
    -- Background is edge-to-edge; only the standard keybind strip has reserved space.
    layoutRecords={}
    self.gameplay=panel(p,0,0,1240,780)
    p=self.gameplay
    box(p,0,0,1240,108,{.02,.025,.02,.70},{0,0,0,0})
    box(p,40,104,1160,1,T.gold,{0,0,0,0})
    box(p,40,704,1160,1,T.edge,{0,0,0,0})
    texture(p,39,17,80,80,"crest"):SetDrawLayer(DL_CONTROLS)
    label(p,133,27,660,44,C.displayTitle,34)
    self.subtitle=label(p,135,71,650,30,"",18)
    self.stats=label(p,820,27,370,80,"",22)
    self.tabs=label(p,42,111,1140,32,"",22)
    self.map=panel(p,40,158,1160,500)
    texture(self.map,0,0,760,500,"atlas",{.83,.81,.75,1})
    -- Original decorative atlas with real ESO region cards layered above it.
    texture(self.map,774,0,386,500,"wood_frame",{.67,.72,.69,.96})
    box(self.map,18,9,609,35,{.04,.05,.04,.88},{0,0,0,0})
    self.mapHeading=label(self.map,26,12,595,30,"",18)
    label(self.map,640,32,100,35,"N  ↑",27,{.18,.14,.09,1})
    box(self.map,24,455,704,36,{.04,.05,.04,.88},{0,0,0,0})
    label(self.map,35,459,690,32,"↑↓：地域選択    ←→：8地域ずつ移動    ×：地域を開く",18)
    label(self.map,798,20,340,40,"交易路の記録",27)
    self.mapDetail=label(self.map,798,76,338,360,"",22)
    for i=1,C.ui.mapPageSize do
        local pin=plaque(self.map,30+((i-1)%2)*350,62+math.floor((i-1)/2)*96,330,78)
        local text=label(pin,12,9,306,62,"",22)
        pin:SetMouseEnabled(true); pin:SetHandler("OnMouseUp",function() self.app.index=(self.mapPage or 0)*C.ui.mapPageSize+i; self.app:Act("confirm"); self:Refresh() end)
        self.pins[i]={box=pin,text=text}
    end
    self.ledger=panel(p,40,158,1160,500)
    texture(self.ledger,0,0,710,500,"wood_frame",{.66,.69,.65,.98})
    texture(self.ledger,734,0,426,500,"wood_frame",{.65,.70,.67,.97})
    -- The wood frame has a deeper ornamental top edge than a plain backdrop.
    -- Use the same 22px content inset as the detail panel so the heading sits
    -- inside the frame instead of riding across its upper rule.
    self.ledgerHeading=label(self.ledger,26,24,666,32,"",27,ink)
    self.detail=label(self.ledger,758,22,376,454,"",22)
    for i=1,C.ui.pageSize do
        -- Ten rows per page: the nine domestic actions plus "finish" fit on one page.
        local row=plaque(self.ledger,18,56+(i-1)*44,674,40)
        -- Centre the single-line caption in the 40px plaque.  A 2px inset made
        -- Japanese glyphs appear visibly high against the engraved row border.
        local text=label(row,14,7,648,28,"",22,ink)
        row:SetMouseEnabled(true); row:SetHandler("OnMouseUp",function()
            self.app.index=(self.page or 0)*C.ui.pageSize+i; self.app:Act("confirm"); self:Refresh()
        end)
        self.rows[i]={box=row,text=text}
    end
    self.hubView=PBTrade.HubUI.New(p,panel,box,label,texture)
    self.battle=panel(p,40,158,1160,500)
    self.battle:SetDrawTier(DT_MEDIUM)
    local function battleLayer(control,layer,level)
        control:SetDrawTier(DT_MEDIUM)
        control:SetDrawLayer(layer)
        control:SetDrawLevel(level or 0)
        return control
    end
    self.battleBackdrop=battleLayer(box(self.battle,0,0,1160,500,{.025,.034,.03,.30},{.49,.39,.24,.55}),DL_BACKGROUND,0)
    self.battleTitle=battleLayer(label(self.battle,24,0,1100,34,"",27),DL_OVERLAY,3)
    self.bands={}
    for i=1,6 do
        local y=64+(i-1)*38
        local enemy=battleLayer(box(self.battle,20,y,560,28,{.48,.12,.14,.40},{0,0,0,0}),DL_BACKGROUND,10)
        local own=battleLayer(box(self.battle,580,y,560,28,{.08,.27,.52,.44},{0,0,0,0}),DL_BACKGROUND,10)
        local enemyTip=battleLayer(texture(self.battle,508,y,C.battle.bandTipWidth,28,"band_tip_right",{.48,.12,.14,.40}),DL_BACKGROUND,11)
        local ownTip=battleLayer(texture(self.battle,580,y,C.battle.bandTipWidth,28,"band_tip_left",{.08,.27,.52,.44}),DL_BACKGROUND,11)
        local enemyGlow=battleLayer(texture(self.battle,20,y,C.battle.bandGlowWidth,28,"band_glow",{1,.44,.35,.88}),DL_BACKGROUND,12)
        local ownGlow=battleLayer(texture(self.battle,1044,y,C.battle.bandGlowWidth,28,"band_glow",{.42,.78,1,.92}),DL_BACKGROUND,12)
        self.bands[i]={enemy=enemy,own=own,enemyTip=enemyTip,ownTip=ownTip,enemyGlow=enemyGlow,ownGlow=ownGlow,phase=(i-1)/6}
    end
    self.coinAreas={}; self.floors={}
    for side=1,2 do
        local bayX=side==1 and 74 or 674
        local viewport=panel(self.battle,bayX,65,400,C.coins.viewportHeight)
        self.coinAreas[side]=viewport
        self.floors[side]=battleLayer(texture(viewport,0,C.coins.floorY+C.coins.plinthOffsetY,C.coins.plinthWidth,C.coins.plinthHeight,"coin_plinth"),DL_CONTROLS,0)
    end
    self.bidFrames={}
    for _,spec in ipairs({{34,306,516,45},{610,306,516,45}}) do
        local frame,art=plaque(self.battle,spec[1],spec[2],spec[3],spec[4])
        self.bidFrames[#self.bidFrames+1]={
            frame=battleLayer(frame,DL_OVERLAY,1),
            art=battleLayer(art,DL_OVERLAY,2),
        }
    end
    self.leftBid=battleLayer(label(self.battle,52,313,490,34,"",27,{.94,.79,.60,1}),DL_OVERLAY,3)
    self.rightBid=battleLayer(label(self.battle,628,313,490,34,"",27,{1,.88,.56,1}),DL_OVERLAY,3)
    self.commandFrames={
        battleLayer(texture(self.battle,16,410,696,89,"wood_frame",{.83,.83,.76,1}),DL_OVERLAY,1),
        battleLayer(texture(self.battle,723,410,421,89,"wood_frame",{.72,.76,.71,1}),DL_OVERLAY,1),
    }
    -- DL_OVERLAY sorts above DL_TEXT in the live ESO client. Keep the panel art at levels
    -- 1-2 and its text at level 3; otherwise the wood textures cover every caption.
    self.commandTabs=battleLayer(label(self.battle,28,417,670,22,"",18,T.gold),DL_OVERLAY,3)
    self.command=battleLayer(label(self.battle,28,438,670,32,"",27),DL_OVERLAY,3)
    self.commandHint=battleLayer(label(self.battle,28,472,670,25,"",18),DL_OVERLAY,3)
    self.log=battleLayer(label(self.battle,735,417,398,78,"",18),DL_OVERLAY,3)
    -- Tactic banner: two slim lines over the title row, clear of the bands, coins and bids.
    local function overlay(c,level) c:SetDrawLayer(DL_OVERLAY); c:SetDrawLevel(level); return c end
    -- Popup strip above the coin bays (y 36-62): one lane per side for moves and status,
    -- and a full-width strip for day summaries and the player's tactic cut-in.
    self.lanes={}
    for _,spec in ipairs({{"enemy",20},{"player",600}}) do
        local lane=overlay(box(self.battle,spec[2],38,540,24,{.02,.028,.024,.86},T.edge),14)
        local text=overlay(label(lane,12,0,516,24,"",18),15)
        lane:SetHidden(true)
        self.lanes[spec[1]]={box=lane,text=text,queue={},current=nil,time=0}
    end
    self.cutin=overlay(box(self.battle,14,38,1132,25,{.018,.024,.02,.92},T.gold),15)
    self.cutinStripe=overlay(box(self.cutin,0,23,1132,2,T.gold,{0,0,0,0}),16)
    self.cutinLine=overlay(label(self.cutin,14,0,1104,23,"",18),17)
    self.cutinVerdict=overlay(label(self.cutin,14,0,1104,23,"",18),17)
    self.cutin:SetHidden(true)
    self.wide={queue={},current=nil,time=0}
    self.notice=label(p,44,675,1150,32,"",18)
    self.helpLine=label(p,44,720,1150,30,"↑↓：選択    ←→：頁送り（交渉中は分類切替）    L1 / R1：帳簿・分類切替    ×：決定    ○：戻る / 中断    □：手引き（交渉中は撤退）    △：詳細",18)
    -- Separate screens, rather than opaque overlay backdrops over the entire game.
    -- Keep containers non-rendering. Text uses the normal TEXT layer, above all
    -- stage artwork/shades in BACKGROUND; no type depends on OVERLAY sorting.
    p=self.content
    local function stageLayer(c,level)
        c:SetDrawLayer(c:GetType()==CT_LABEL and DL_TEXT or DL_BACKGROUND)
        c:SetDrawLevel(level)
        return c
    end
    local function openingLayer(c,level)
        stageLayer(c,level)
        -- Set the primary draw priority too: layer/level alone do not specify
        -- the tier inherited by different native control types.
        c:SetDrawTier(c:GetType()==CT_LABEL and DT_HIGH or DT_MEDIUM)
        return c
    end
    self.openingPanel=panel(p,0,0,1240,780)
    self.openingPanel:SetDrawTier(DT_MEDIUM)
    openingLayer(box(self.openingPanel,0,0,1240,780,{0,0,0,1},{0,0,0,0}),0)
    self.openingArt=openingLayer(texture(self.openingPanel,0,0,1240,780,"treasury"),3)
    openingLayer(box(self.openingPanel,0,0,1240,90,{0,0,0,.45},{0,0,0,0}),4)
    openingLayer(box(self.openingPanel,0,485,1240,295,{.01,.012,.01,.88},{0,0,0,0}),4)
    openingLayer(box(self.openingPanel,60,493,1120,2,T.gold,{0,0,0,0}),5)
    self.openingText=openingLayer(label(self.openingPanel,80,504,1080,216,"",C.opening.fontSize,{1,.93,.78,1}),6)
    -- Speaker card for pages that name a portrait (the true ending's farewell): a framed
    -- portrait above the band on the left, with a name plate touching the band.
    self.openingCard={
        openingLayer(box(self.openingPanel,60,158,300,300,{.02,.025,.022,1},T.gold),4),
        openingLayer(texture(self.openingPanel,66,164,288,288,"ember"),5),
        openingLayer(box(self.openingPanel,60,448,300,34,{.01,.012,.01,.94},T.gold),4),
    }
    self.openingPortrait=self.openingCard[2]
    self.openingSpeaker=openingLayer(label(self.openingPanel,60,451,300,30,"",27,T.gold),6)
    self.openingSpeaker:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.openingCard[#self.openingCard+1]=self.openingSpeaker
    self.openingNext=openingLayer(label(self.openingPanel,1150,678,40,36,"▼",27,T.gold),6)
    self.openingHint=openingLayer(label(self.openingPanel,80,730,760,30,"×：次へ　　○：スキップ",18,T.gold),6)
    self.openingPage=openingLayer(label(self.openingPanel,1040,730,140,30,"",18,T.gold),6)
    self.openingPage:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.openingPanel:SetHidden(true)
    -- Title and company-naming screens: a dedicated mercantile hall, above the ledger.
    local titleLayer=stageLayer
    local function centered(c) c:SetHorizontalAlignment(TEXT_ALIGN_CENTER); return c end
    self.titlePanel=panel(p,0,0,1240,780)
    titleLayer(box(self.titlePanel,0,0,1240,780,{.018,.024,.021,1},{0,0,0,0}),0)
    self.titleBackdrop=titleLayer(texture(self.titlePanel,0,0,1240,780,"title_hall",{.88,.91,.90,1}),3)
    -- The DDS is 2:1; crop its sides back to the 1240:780 stage without stretching the hall.
    self.titleBackdrop:SetTextureCoords(.103,.897,0,1)
    titleLayer(box(self.titlePanel,0,0,1240,780,{.008,.012,.011,.43},{0,0,0,0}),4)
    titleLayer(box(self.titlePanel,218,20,804,742,{.014,.019,.017,.66},{.48,.38,.21,.68}),5)
    titleLayer(box(self.titlePanel,246,42,748,2,T.gold,{0,0,0,0}),6)
    titleLayer(box(self.titlePanel,246,330,748,1,T.gold,{0,0,0,0}),6)
    titleLayer(texture(self.titlePanel,560,35,120,120,"crest"),6)
    titleLayer(centered(label(self.titlePanel,270,72,220,28,"第二紀",18,T.gold)),7)
    titleLayer(centered(label(self.titlePanel,750,72,220,28,"交易年代記",18,T.gold)),7)
    self.titleName=titleLayer(centered(label(self.titlePanel,0,151,1240,64,C.displayTitle,54,{1,.86,.55,1})),7)
    titleLayer(centered(label(self.titlePanel,0,214,1240,30,"PB's Tamriel de Trade",22,T.gold)),7)
    self.titleCompany=titleLayer(centered(label(self.titlePanel,0,258,1240,44,"",34,{1,.90,.68,1})),7)
    self.titleStatus=titleLayer(centered(label(self.titlePanel,270,303,700,30,"",22)),7)
    self.titleRows={}
    for i=1,8 do
        local rowBox=titleLayer(box(self.titlePanel,350,351+(i-1)*42,540,36,{.025,.045,.038,.78},{.34,.29,.19,.72}),7)
        local text=titleLayer(centered(label(rowBox,0,3,540,30,"",22)),8)
        self.titleRows[i]={box=rowBox,text=text}
    end
    titleLayer(box(self.titlePanel,240,716,760,38,{.012,.018,.016,.78},{.34,.29,.19,.55}),6)
    self.titleNotice=titleLayer(centered(label(self.titlePanel,250,721,740,28,"",18)),7)
    -- Name entry: focusing an edit control is what makes the console show its keyboard.
    self.nameEditBox=titleLayer(box(self.titlePanel,350,298,540,42,{.01,.012,.01,.96},T.gold),9)
    -- The gamepad template supplies Accept / Cancel keybinds while focused (Cancel restores the
    -- previous text) and calls focusLostCallback afterwards; its own handlers stay untouched.
    self.nameEdit=WINDOW_MANAGER:CreateControlFromVirtual("PBTradeCompanyNameEdit",self.nameEditBox,"ZO_DefaultEditForBackdrop_Gamepad")
    remember(self.nameEdit,self.nameEditBox,12,5,516,30)
    self.nameEdit:SetDrawLayer(DL_TEXT); self.nameEdit:SetDrawLevel(10)
    applyFont(self.nameEdit,27); self.nameEdit:SetMaxInputChars(64); self.nameEdit:SetColor(unpack(light))
    if self.nameEdit.SetTextType and TEXT_TYPE_ALL then self.nameEdit:SetTextType(TEXT_TYPE_ALL) end
    if self.nameEdit.SetVirtualKeyboardType and VIRTUAL_KEYBOARD_TYPE_DEFAULT then
        self.nameEdit:SetVirtualKeyboardType(VIRTUAL_KEYBOARD_TYPE_DEFAULT)
    end
    -- Japanese IME commits its composed text just after focus is released on console.
    -- Queue the read instead of consuming the still-empty edit control in this callback.
    self.nameEdit.focusLostCallback=function() self:QueueTypingFinish() end
    self.nameEditBox:SetHidden(true); self.titlePanel:SetHidden(true)
    self:RegisterCompanyNameDialog()
    self.modal,self.modalArt=plaque(p,225,155,790,510)
    self.modal:SetCenterColor(.025,.03,.02,1)
    -- Result/campaign dialogs must beat the complete negotiation stage, including
    -- dynamically-created coin textures and level 17 tactic strips.  A layer alone
    -- is insufficient across sibling control trees in the live client, so give every
    -- dialog surface the HIGH tier as well as an explicit local order.
    local function modalLayer(c,level)
        c:SetDrawTier(DT_HIGH); c:SetDrawLayer(DL_OVERLAY); c:SetDrawLevel(level)
        return c
    end
    modalLayer(self.modal,100); modalLayer(self.modalArt,101)
    self.campaignBackdrop=modalLayer(texture(self.modal,8,8,774,494,"chapter_1"),102)
    self.campaignShade=modalLayer(box(self.modal,8,8,774,494,{.01,.015,.012,.62},{0,0,0,0}),103)
    self.modalText=modalLayer(label(self.modal,30,25,730,460,"",22),104)
    self.fxPanel=box(p,320,102,600,64,{.04,.08,.07,.94},T.gold)
    self.fxPanel:SetDrawLayer(DL_OVERLAY); self.fxPanel:SetDrawLevel(20)
    self.fxText=label(self.fxPanel,16,10,568,44,"",27,T.gold)
    self.fxText:SetDrawLayer(DL_OVERLAY); self.fxText:SetDrawLevel(21)
    self.keybinds={alignment=KEYBIND_STRIP_ALIGN_CENTER}
    for _,spec in ipairs({{"UI_SHORTCUT_PRIMARY","confirm","決定"},{"UI_SHORTCUT_NEGATIVE","back","戻る"},
        {"UI_SHORTCUT_SECONDARY","info","手引き"},{"UI_SHORTCUT_TERTIARY","detail","詳細"},
        {"UI_SHORTCUT_LEFT_SHOULDER","previous","前の分類"},{"UI_SHORTCUT_RIGHT_SHOULDER","next","次の分類"}}) do
        local action=spec[2]
        local name=spec[3]
        -- □ is the negotiation's special action: withdraw with a single press.
        if action=="info" then name=function()
            local app=self.app; return type(app)=="table" and app.screen=="battle" and "撤退" or "手引き" end end
        self.keybinds[#self.keybinds+1]={keybind=spec[1],name=name,callback=function() self:Action(action) end}
    end
    self.scene=ZO_Scene:New(C.scene,SCENE_MANAGER)
    self.scene:AddFragment(ZO_SimpleSceneFragment:New(self.root))
    self.scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    self.scene:AddFragment(ZO_ActionLayerFragment:New("PBTradeInput"))
    self.scene:RegisterCallback("StateChange",function(_,state)
        if state==SCENE_SHOWING then
            -- The session state is built on first open, not during add-on load.
            if type(self.app)=="function" then self.app=self.app() end
            -- Ordinary ledger pages reopen at the title.  Story playback and other
            -- pending flows resume exactly where they were when the scene was hidden.
            local screen=self.app.screen
            local resume={hub=true,battle=true,result=true,rankings=true,admin=true,admin_pick=true,
                opening=true,naming=true,strategy=true,delegate_pick=true}
            if not resume[screen] then self.app:ShowTitle() end
            self:Resize()
            KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds); self:Refresh()
        elseif state==SCENE_SHOWN then
            if PBTrade.Audio.SyncMusic then PBTrade.Audio.SyncMusic(self.app.screen) end
            self.active=true; self.nextMove=0; DIRECTIONAL_INPUT:Activate(self,self.root)
        elseif state==SCENE_HIDING then
            self:FinishTyping(false)
            if type(self.app)=="table" and self.app.FlushSave then self.app:FlushSave() end
            if PBTrade.Audio.StopMusic then PBTrade.Audio.StopMusic() end
            self.active=false; self.keyDirection=nil; DIRECTIONAL_INPUT:Deactivate(self); KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybinds)
        end
    end)
    self.layout=layoutRecords; layoutRecords=nil
    self:Resize()
    return self
end
-- Read native controls when diagnosing a device-specific rendering failure.
-- Does not modify the current screen or saved campaign.
function U:DescribeDisplay()
    local lines={"v"..C.version.." screen="..(type(self.app)=="table" and self.app.screen or "unopened")}
    for _,name in ipairs({"gameplay","openingPanel","openingArt","openingText","titlePanel","titleName"}) do
        local c=self[name]
        local w,h=c:GetDimensions()
        local detail=string.format("%s hidden=%s alpha=%.2f size=%.0fx%.0f tier=%s layer=%s level=%s",
            name,tostring(c:IsHidden()),c:GetAlpha(),w,h,tostring(c:GetDrawTier()),
            tostring(c:GetDrawLayer()),tostring(c:GetDrawLevel()))
        if c:GetType()==CT_LABEL then detail=detail.." text="..c:GetText() end
        if c:GetType()==CT_TEXTURE then detail=detail.." loaded="..tostring(PBTrade.Assets.IsUsable(c)) end
        lines[#lines+1]=detail
    end
    return table.concat(lines,"\n")
end
function U:Resize()
    local w,h=GuiRoot:GetWidth(),GuiRoot:GetHeight()
    self.viewportWidth,self.viewportHeight=w,h
    local height=math.max(1,h-C.ui.keybindHeight)
    local scale=math.min(w/C.ui.width,height/C.ui.height)
    self.sx=w/(scale*C.ui.width); self.sy=height/(scale*C.ui.height)
    self.content:SetScale(scale); self.content:SetDimensions(w/scale,height/scale)
    self.content:ClearAnchors(); self.content:SetAnchor(TOPLEFT,self.root,TOPLEFT,0,0)
    for _,item in ipairs(self.layout) do
        item.control:ClearAnchors()
        item.control:SetAnchor(TOPLEFT,item.parent,TOPLEFT,item.x*self.sx,item.y*self.sy)
        item.control:SetDimensions(item.w*self.sx,item.h*self.sy)
    end
end
function U:UpdateBattleBands(normalized)
    local total=1120
    local red=total*normalized
    local blue=total-red
    local glow=C.battle.bandGlowWidth
    local tip=C.battle.bandTipWidth
    for _,band in ipairs(self.bands) do
        local y=(64+(_-1)*38)*self.sy
        local redTip=math.min(tip,red); local blueTip=math.min(tip,blue)
        band.enemy:SetHidden(red<=redTip); band.own:SetHidden(blue<=blueTip)
        band.enemy:ClearAnchors(); band.enemy:SetAnchor(TOPLEFT,self.battle,TOPLEFT,20*self.sx,y)
        band.enemy:SetWidth(math.max(1,(red-redTip)*self.sx))
        band.enemyTip:SetHidden(redTip<2); band.enemyTip:ClearAnchors()
        band.enemyTip:SetAnchor(TOPLEFT,self.battle,TOPLEFT,(20+red-redTip)*self.sx,y); band.enemyTip:SetDimensions(redTip*self.sx,28*self.sy)
        band.ownTip:SetHidden(blueTip<2); band.ownTip:ClearAnchors()
        band.ownTip:SetAnchor(TOPLEFT,self.battle,TOPLEFT,(20+red)*self.sx,y); band.ownTip:SetDimensions(blueTip*self.sx,28*self.sy)
        band.own:ClearAnchors(); band.own:SetAnchor(TOPLEFT,self.battle,TOPLEFT,(20+red+blueTip)*self.sx,y)
        band.own:SetWidth(math.max(1,(blue-blueTip)*self.sx))
        local phase=((self.bandFxTime or 0)/C.battle.bandAnimationSeconds+band.phase)%1
        local redGlow=math.min(glow,red)
        local blueGlow=math.min(glow,blue)
        band.enemyGlow:SetHidden(redGlow<4)
        band.ownGlow:SetHidden(blueGlow<4)
        if redGlow>=4 then
            band.enemyGlow:ClearAnchors()
            band.enemyGlow:SetAnchor(TOPLEFT,self.battle,TOPLEFT,
                (20+phase*math.max(0,red-redGlow))*self.sx,y)
            band.enemyGlow:SetDimensions(redGlow*self.sx,28*self.sy)
        end
        if blueGlow>=4 then
            band.ownGlow:ClearAnchors()
            band.ownGlow:SetAnchor(TOPLEFT,self.battle,TOPLEFT,
                (20+red+(1-phase)*math.max(0,blue-blueGlow))*self.sx,y)
            band.ownGlow:SetDimensions(blueGlow*self.sx,28*self.sy)
        end
    end
end
-- Keyboard entry, done the way the base game's console screens do it (e.g. mail subject):
-- focus the edit box once and let the platform keyboard serve it. No forced refocus.
function U:OpenKeyboard()
    if self:RegisterCompanyNameDialog() then
        self.editing=false; self.keyboardCommitTime=nil; self.companyNameEditControl=nil
        ZO_Dialogs_ShowGamepadDialog(COMPANY_NAME_DIALOG,{name=self.app.pendingName or ""})
        return
    end
    self.editing=true; self.keyboardTime=0; self.keyboardCommitTime=nil
    self.nameEditBox:SetHidden(false); self.titleStatus:SetHidden(true)
    self.app.notice="文字を入力したら ×（決定）で確定します。○ で入力を取り消します"; self.titleNotice:SetText(self.app.notice)
    self.nameEdit:SetText(self.app.pendingName or ""); self.nameEdit:TakeFocus()
end
-- Use ESO's own parametric gamepad dialog on console. Its text field is the same route used by
-- outfit and guild-rank naming, so the platform IME delivers Japanese composition correctly.
function U:RegisterCompanyNameDialog()
    if self.companyNameDialogRegistered then return true end
    if not (ZO_Dialogs_RegisterCustomDialog and ZO_Dialogs_ShowGamepadDialog
        and ZO_GenericGamepadDialog_GetControl and GAMEPAD_DIALOGS and GAMEPAD_DIALOGS.PARAMETRIC) then return false end
    local ui=self
    local parametricDialog=ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
    local function release()
        ui.companyNameEditControl=nil
        ZO_Dialogs_ReleaseDialogOnButtonPress(COMPANY_NAME_DIALOG)
    end
    -- Japanese composition can be committed as the platform keyboard closes. Capture the
    -- EditBox before ESO refreshes the parametric row; otherwise setup may restore the old
    -- cached value and replace the just-committed Japanese text with an empty string.
    local function captureName(edit)
        if edit and parametricDialog.data then parametricDialog.data.name=edit:GetText() end
    end
    local function submitName(dialog)
        -- Read the live native control as well as the cache. This also covers a platform
        -- IME commit that did not emit OnTextChanged before the confirm key was pressed.
        local edit=ui.companyNameEditControl
        local name=edit and edit:GetText() or (dialog.data and dialog.data.name or "")
        if dialog.data then dialog.data.name=name end
        if ui.app:SubmitTypedName(name) then release(); ui:Refresh(); return true end
        KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
        return false
    end
    ZO_Dialogs_RegisterCustomDialog(COMPANY_NAME_DIALOG,{
        canQueue=true,
        gamepadInfo={dialogType=GAMEPAD_DIALOGS.PARAMETRIC},
        setup=function(dialog) dialog:setupFunc() end,
        title={text="商会名を入力"},
        mainText={text="日本語・英数字を使用できます（16文字まで）\n×：選択　↓：決定欄へ　□：直接決定"},
        parametricList={
            {
                template="ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                templateData={
                    nameField=true,
                    textChangedCallback=captureName,
                    focusLostCallback=captureName,
                    setup=function(control,data)
                        local edit=control.editBoxControl
                        data.control=control; ui.companyNameEditControl=edit
                        edit.textChangedCallback=data.textChangedCallback
                        edit.focusLostCallback=data.focusLostCallback
                        edit:SetMaxInputChars(64); edit:SetTextType(TEXT_TYPE_ALL)
                        if edit.SetVirtualKeyboardType and VIRTUAL_KEYBOARD_TYPE_DEFAULT then
                            edit:SetVirtualKeyboardType(VIRTUAL_KEYBOARD_TYPE_DEFAULT)
                        end
                        edit:SetText((parametricDialog.data and parametricDialog.data.name) or "")
                    end,
                    callback=function()
                        if ui.companyNameEditControl then ui.companyNameEditControl:TakeFocus() end
                    end,
                    narrationText=ZO_GetDefaultParametricListEditBoxNarrationText,
                },
            },
            {
                template="ZO_GamepadTextFieldSubmitItem",
                templateData={
                    finishedSelector=true,
                    text="この名前で決定",
                    setup=function(control,data,...)
                        ZO_SharedGamepadEntry_OnSetup(control,data,...)
                    end,
                    callback=submitName,
                },
                icon=ZO_GAMEPAD_SUBMIT_ENTRY_ICON,
            },
        },
        blockDialogReleaseOnPress=true,
        buttons={
            {keybind="DIALOG_PRIMARY",text="選択",callback=function(dialog)
                local data=dialog.entryList:GetTargetData()
                if data and data.callback then data.callback(dialog)
                elseif data and data.control then data.control.editBoxControl:TakeFocus() end
            end},
            {keybind="DIALOG_SECONDARY",text="この名前で決定",callback=submitName},
            {keybind="DIALOG_NEGATIVE",text="戻る",callback=release},
        },
        noChoiceCallback=release,
    })
    self.companyNameDialogRegistered=true
    return true
end
function U:QueueTypingFinish()
    if not self.editing or self.keyboardCommitTime then return end
    self.keyboardCommitTime=0
end
-- Watchdog: however focus was lost (keyboard closed, Accept, Cancel, another control),
-- wait briefly for the platform IME's final composition event, then read the text.
function U:UpdateKeyboard(dt)
    if not self.editing then return end
    self.keyboardTime=self.keyboardTime+dt
    if self.keyboardCommitTime then
        self.keyboardCommitTime=self.keyboardCommitTime+dt
        if self.keyboardCommitTime>=C.input.imeCommitDelay then self:FinishTyping(true) end
    elseif self.keyboardTime>=.5 and not self.nameEdit:HasFocus() then self:QueueTypingFinish() end
end
function U:FinishTyping(submit)
    if not self.editing then return end
    self.editing=false; self.keyboardCommitTime=nil
    local text=self.nameEdit:GetText()
    if self.nameEdit:HasFocus() then self.nameEdit:LoseFocus() end
    self.nameEditBox:SetHidden(true); self.titleStatus:SetHidden(false)
    if submit and type(self.app)=="table" then self.app:SubmitTypedName(text) end
    if self.active then self:Refresh() end
end
function U:Action(action)
    if self.editing then return end
    self.app:Act(action)
    if self.app.closeRequested then self.app.closeRequested=false; SCENE_MANAGER:Hide(C.scene) end
    self:Refresh()
end
-- The D-pad arrives as Bindings.xml Down/Up events. Never query ZO_DI_DPAD:
-- it calls the private IsKeyDown and raises an insecure-code UI error on consoles.
function U:DirectionKey(direction,down)
    if not self.active then return end
    if down then self.keyDirection=direction; self:MoveDirection(direction)
    elseif self.keyDirection==direction then self.keyDirection=nil; self.heldDirection=nil end
end
function U:MoveDirection(direction)
    if not direction then self.heldDirection=nil; return end
    local now=GetFrameTimeSeconds()
    if direction~=self.heldDirection or now>=self.nextMove then
        if self.app.screen=="hub" then
            local d={up={0,-1},down={0,1},left={-1,0},right={1,0}}
            self.app:HubMove(d[direction][1],d[direction][2])
        elseif direction=="up" then self.app:Move(-1)
        elseif direction=="down" then self.app:Move(1)
        else self.app:MovePage(direction=="right" and 1 or -1) end
        self:Refresh()
        self.nextMove=now+(direction==self.heldDirection and C.input.repeatDelay or C.input.firstRepeat)
        self.heldDirection=direction
    end
end
function U:UpdateDirectionalInput()
    if not self.active or self.editing then return end
    local x,y=DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)
    local direction=self.keyDirection
    if not direction then
        if math.abs(y)>C.input.deadzone then direction=y>0 and "up" or "down"
        elseif math.abs(x)>C.input.deadzone then direction=x>0 and "right" or "left" end
    end
    self:MoveDirection(direction)
end
-- Anything that changes which texts or lists are shown forces a full Refresh.
local function markers(a)
    local b=a.engine.battle
    return a.screen,a.modal,a.fx,b,b and #b.log,b and b.result,a.tacticScene,a.groupCall,a.notice,a.index
end
function U:Changed()
    local screen,modal,fx,b,logs,result,scene,call,notice,index=markers(self.app)
    local m=self.refreshMarkers
    return screen~=m[1] or modal~=m[2] or fx~=m[3] or b~=m[4] or logs~=m[5] or result~=m[6] or scene~=m[7] or call~=m[8]
        or notice~=m[9] or index~=m[10]
end
-- Per-tick battle visuals only: gauge bands, bids, timers and coin piles.
-- Row lists, ledgers and headings are rebuilt by the throttled full Refresh.
function U:RefreshBattleFrame()
    local b=self.app.engine.battle
    if not b then return end
    local normalized=(b.gauge+C.battle.gaugeLimit)/(2*C.battle.gaugeLimit)
    self:UpdateBattleBands(normalized)
    self.leftBid:SetText("相手の拠出　"..gold(b.enemyBid).." ゴールド")
    -- Under a standing stance, show how much of the contribution actually pushes the border.
    local force=self.app.engine:PlayerForce()
    self.rightBid:SetText("自社の拠出　"..gold(b.playerBid).." ゴールド"..(force<b.playerBid and ("（実効 "..gold(math.floor(force)).."）") or ""))
    if self.commandHintText then
        self.commandHint:SetText(string.format("伝令 %.1f秒  |  %s",b.playerWait,self.commandHintText))
    end
    if self.visualBattle~=b then self.visualBattle=b; self.coins=PBTrade.Coins.New(b.effectiveValue) end
    -- While a group call is on screen, the new group funding is held back from the coin pile.
    self.coins:SetBid(1,b.enemyBid); self.coins:SetBid(2,self.app.groupCall and self.app.groupCall.heldBid or b.playerBid)
    self:RenderCoins()
    self:RenderPopups()
end
-- UTF-8 aware typewriter: characters are split once per line, text is only
-- rebuilt when the visible count changes.
local function characters(text)
    local chars={}; for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars+1]=ch end
    return chars
end
local function easeOut(t) t=math.min(1,math.max(0,t)); return 1-(1-t)^3 end
local verdictColors={great={1,.84,.38,1},good={.62,.95,.72,1},weak={.86,.8,.62,1},void={.62,.62,.6,1},backfire={1,.42,.38,1}}
-- Line 1 types the move, then the opponent's reaction; line 2 stamps the verdict and effect.
-- The negotiation keeps running underneath and input stays with the trade.
function U:RenderTacticScene()
    local a=self.app; local scene=a.tacticScene
    if not scene then self.cutinState=nil; return end
    self.cutin:SetHidden(false)
    local st=self.cutinState
    if not st or st.scene~=scene then
        local head="◆ 駆け引き「"..scene.tactic.name.."」  "
        st={scene=scene,act=characters(head..scene.act),react=characters(head..scene.reaction),head=#characters(head)}
        self.cutinState=st
        self.cutinLine:SetText(""); self.cutinVerdict:SetText("")
        self.cutinVerdict:SetColor(unpack(verdictColors[scene.kind] or T.gold))
    end
    local stage,t=a:TacticStage()
    local S=C.tacticScene
    local chars,elapsed=st.act,scene.time
    if stage~="intro" then chars,elapsed=st.react,scene.time-S.intro end
    -- The tactic name appears at once; only the narration types out.
    local count=math.min(#chars,st.head+math.floor(elapsed*S.typeSpeed))
    if st.chars~=chars or st.count~=count then
        st.chars,st.count=chars,count; self.cutinLine:SetText(table.concat(chars,"",1,count))
    end
    self.cutinStripe:SetWidth(math.max(1,1132*easeOut(stage=="intro" and t or 1)*self.sx))
    self.cutinLine:SetHidden(stage=="result"); self.cutinVerdict:SetHidden(stage~="result")
    if stage=="result" then
        if not st.verdictShown then st.verdictShown=true; self.cutinVerdict:SetText("◆「"..scene.tactic.name.."」  "..scene.verdict.."   "..scene.detail) end
        self.cutinVerdict:SetScale(1+.15*(1-easeOut(t*5)))
    else self.cutinVerdict:SetScale(1) end
end
local popupColors={call={1,.84,.38,1},fund={.9,.87,.76,1},alert={1,.5,.44,1},tactic={.82,.7,1,1},group={1,.64,.30,1},discovery={1,.84,.38,1},day={1,.86,.55,1},
    stance={.62,.84,1,1},stanceBreak={.56,1,.68,1}}
-- Advances one popup channel: fade in, hold (shorter when more are waiting), fade out, next.
local function stepPopup(channel,dt,hold)
    if not channel.current then
        channel.current=table.remove(channel.queue,1); channel.time=0
        if not channel.current then return nil end
    end
    channel.time=channel.time+dt
    local P=C.ui
    local holdFor=#channel.queue>0 and P.popupBusyHold or hold
    local total=P.popupFadeIn+holdFor+P.popupFadeOut
    if channel.time>=total then channel.current=nil; return stepPopup(channel,0,hold) end
    local alpha=channel.time<P.popupFadeIn and channel.time/P.popupFadeIn
        or (channel.time>P.popupFadeIn+holdFor and (total-channel.time)/P.popupFadeOut or 1)
    return channel.current,alpha
end
-- Battle popups: pulls new engine events, then draws the wide strip (tactic cut-in first,
-- then day summaries) or, when it is free, the two side lanes above the coin bays.
function U:RenderPopups()
    local a=self.app; local b=a.engine.battle
    local now=GetFrameTimeSeconds(); local dt=math.min(.25,math.max(0,now-(self.popupClock or now))); self.popupClock=now
    if self.popupBattle~=b then
        self.popupBattle=b; self.popupCursor=0; self.wide.queue={}; self.wide.current=nil
        for _,lane in pairs(self.lanes) do lane.queue={}; lane.current=nil end
    end
    local events=b and b.events or {}
    while self.popupCursor<#events do
        self.popupCursor=self.popupCursor+1
        local event=events[self.popupCursor]
        local channel=event.lane=="wide" and self.wide or self.lanes[event.lane]
        if channel then channel.queue[#channel.queue+1]=event end
    end
    local scene=a.tacticScene; local call=a.groupCall
    local wide,alpha
    if not scene and not call then wide,alpha=stepPopup(self.wide,dt,C.ui.popupWideHold) end
    self:RenderTacticScene()
    if call then
        -- Group call: gold banner that stamps in, over the day summaries and side lanes.
        local t=call.time/C.groupCall.seconds
        self.cutin:SetHidden(false); self.cutin:SetAlpha(1); self.wideShown=nil
        self.cutinLine:SetHidden(true); self.cutinVerdict:SetHidden(false)
        if self.callShown~=call then
            self.callShown=call; self.cutinVerdict:SetText("◆ "..call.name.."を知るもの来たれ！")
            self.cutinVerdict:SetColor(unpack(popupColors.call))
        end
        self.cutinVerdict:SetScale(1+.3*(1-easeOut(t*4)))
        self.cutinStripe:SetWidth(math.max(1,1132*easeOut(t*2)*self.sx))
    elseif not scene then
        self.cutin:SetHidden(not wide)
        if wide then
            self.cutinLine:SetHidden(false); self.cutinVerdict:SetHidden(true)
            if self.wideShown~=wide then self.wideShown=wide; self.cutinLine:SetText(wide.text); self.cutinLine:SetColor(unpack(popupColors.day)) end
            self.cutin:SetAlpha(alpha); self.cutinStripe:SetWidth(1132*self.sx)
        end
    else self.cutin:SetAlpha(1); self.wideShown=nil; self.cutinLine:SetColor(unpack(light)) end
    local blocked=scene~=nil or wide~=nil or call~=nil
    for _,lane in pairs(self.lanes) do
        local event,laneAlpha
        if not blocked then event,laneAlpha=stepPopup(lane,dt,C.ui.popupHold) end
        lane.box:SetHidden(not event)
        if event then
            if lane.shown~=event then
                lane.shown=event; lane.text:SetText(event.text); lane.text:SetColor(unpack(popupColors[event.kind] or light))
                if event.sentiment and PBTrade.Audio and PBTrade.Audio.Play then
                    PBTrade.Audio.Play(event.sentiment=="positive" and "statusPositive" or "statusNegative")
                end
            end
            lane.box:SetAlpha(laneAlpha)
        end
    end
end
function U:Refresh()
    local a=self.app; local rows=a:Rows(); local row=a:Selected(rows); local b=a.engine.battle
    local m=self.refreshMarkers
    if m[1]~=a.screen and self.active and KEYBIND_STRIP.UpdateKeybindButtonGroup then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds)
    end
    m[1],m[2],m[3],m[4],m[5],m[6],m[7],m[8],m[9],m[10]=markers(a)
    self.fullRefreshElapsed=0
    self.subtitle:SetText(M.CompanyName(a.state).."  /  交易台帳  /  第"..a.state.chapter.."章")
    self.stats:SetText("商会資金  "..M.FormatCompact(a.state.cash).."\n総資産  "..M.FormatCompact(M.Assets(a.state)).."\n所有  "..#M.Owned(a.state).." 件")
    local campaign=M.CampaignStatus(a.state)
    self.tabs:SetText((a.tab==1 and "◆ " or "◇ ").."地図    "..(a.tab==2 and "◆ " or "◇ ").."所有物件    "
        ..(a.tab==3 and "◆ " or "◇ ").."連合    "..(a.tab==4 and "◆ " or "◇ ").."駆け引き    "
        ..(a.tab==5 and "◆ " or "◇ ").."経営    |  第"..a.state.chapter.."章  "..campaign.short)
    -- Background music follows the screen (credits / tribute / duel).
    if self.active and PBTrade.Audio.SyncMusic then PBTrade.Audio.SyncMusic(a.screen) end
    local titleScreen=a.screen=="title" or a.screen=="naming"
    local opening=a.screen=="opening"
    self.gameplay:SetHidden(titleScreen or opening)
    self.titlePanel:SetHidden(not titleScreen); self.notice:SetHidden(titleScreen or opening)
    self.openingPanel:SetHidden(not opening); self.helpLine:SetHidden(opening or titleScreen or a.screen=="hub")
    if opening then self:RenderOpening() end
    if titleScreen then
        if a.keyboardRequested then a.keyboardRequested=false; self:OpenKeyboard() end
        if a.screen=="title" then
            self.titleCompany:SetText(a.state.companyName and ("「"..a.state.companyName.."」") or "")
            self.titleStatus:SetText(a:TitleStatus())
        else
            self.titleCompany:SetText(a.pendingName and ("「"..a.pendingName.."」") or "「　　　」")
            self.titleStatus:SetText("商会名は"..C.campaign.companyNameMaxChars.."文字まで。候補から選ぶか、キーボードで入力できます")
        end
        for i,controls in ipairs(self.titleRows) do
            local item=rows[i]; controls.box:SetHidden(not item)
            if item then
                controls.text:SetText((a.index==i and "◆ " or "")..item.label)
                controls.text:SetColor(unpack(item.enabled==false and {.52,.52,.48,1} or (a.index==i and {1,.86,.55,1} or ink)))
                controls.box:SetCenterColor(unpack(a.index==i and {.47,.41,.23,.65} or {.04,.065,.05,.5}))
            end
        end
        self.titleNotice:SetText(a.notice or "")
    end
    PBTrade.HubUI.Refresh(self.hubView,a,function() self:Refresh() end)
    self.map:SetHidden(a.screen~="map")
    self.ledger:SetHidden(a.screen~="properties" and a.screen~="owned" and a.screen~="groups" and a.screen~="tactics" and a.screen~="management" and a.screen~="rankings" and a.screen~="admin" and a.screen~="admin_pick" and a.screen~="strategy" and a.screen~="delegate_pick")
    self.battle:SetHidden(a.screen~="battle" and a.screen~="result")
    self.notice:SetText(a.notice)
    if a.screen=="map" then
        local mapRows=rows; self.mapPage=math.floor((a.index-1)/C.ui.mapPageSize)
        self.mapHeading:SetText("交易地図・地域索引  "..(self.mapPage+1).." / "..math.ceil(#mapRows/C.ui.mapPageSize).."  |  現在"..#mapRows.."地域")
        for i,pin in ipairs(self.pins) do
            local index=self.mapPage*C.ui.mapPageSize+i
            local z=mapRows[index] and mapRows[index].zone; pin.box:SetHidden(not z)
            if z then
            local counts=M.ZoneSummary(a.state,z.id)
            local color=not a.state.unlocked[z.id] and T.locked
                or (counts.own>0 and T.own or (counts.ally>0 and T.ally or (counts.enemy>0 and T.enemy or T.neutral)))
            pin.box:SetCenterColor(color[1],color[2],color[3],.62)
            pin.box:SetEdgeColor(unpack(index==a.index and T.gold or T.edge))
            pin.text:SetText((index==a.index and "◆ " or "")..z.shortName.."\n"..(a.state.unlocked[z.id] and "買収可" or "未開放").." / "..(counts.own+counts.enemy+counts.neutral+counts.ally).."物件"..(counts.ally>0 and ("（同盟 "..counts.ally.."）") or ""))
            end
        end
        if row then
            local z=row.zone; local counts=M.ZoneSummary(a.state,z.id)
            local landmarks,landmarksVisited=M.ZoneLandmarks(a.state,z.id)
            self.mapDetail:SetText(z.name.."\n"..(a.state.visited[z.id] and "交易路調査済み" or "未訪問")
                .."\n\n自社所有："..counts.own.."\n同盟商会所有："..counts.ally.."\n敵商会所有："..counts.enemy.."\n中立："..counts.neutral
                ..(landmarks>0 and ("\n実在地点：◎登録済み "..landmarksVisited.." / 全 "..landmarks) or "")
                .."\n\n"..(a.state.unlocked[z.id] and "×：地域の物件を見る" or "開放条件：所有 "..(2+z.unlockTier*C.campaign.unlockOwnedStep).." 件")
                .."\n\n緑：自社拠点あり\n赤：敵商会あり\n金茶：中立のみ\n灰：未開放\n※混在地域の内訳は上記参照")
        end
    elseif a.screen=="rankings" then
        self.page=math.floor((a.index-1)/C.ui.pageSize)
        local period=a.rankingPeriod or M.CurrentPeriod(a.state)
        local first=self.page*C.ui.pageSize
        local pages=math.max(1,math.ceil(#a.rankingRows/C.ui.pageSize))
        self.ledgerHeading:SetText("第"..period.."期  商会資金力ランキング  /  "..(self.page+1).." / "..pages.."頁  /  交渉・防衛・内政後")
        for i,controls in ipairs(self.rows) do
            local absolute=first+i
            local r=a.rankingRows[absolute]; controls.box:SetHidden(not r)
            if r then
                controls.text:SetText(r.rank.."位  "..r.name.."  "..M.FormatCompact(r.fundingPower)..(r.id==C.playerId and "  ★" or (M.IsAllied(a.state,r.id) and "  〔同盟〕" or "")))
                controls.text:SetColor(unpack(ink))
                controls.box:SetCenterColor(unpack(a.index==absolute and {.47,.41,.23,.65} or {.04,.065,.05,.36}))
            end
        end
        if row and row.ranking then
            local r=row.ranking
            self.detail:SetText("第"..period.."期\n"..r.name.."\n現在 "..r.rank.."位 / "..#a.rankingRows.."商会"
                .."\n前期比："..(period>1 and ((r.rankChange>0 and "+" or "")..r.rankChange) or "―").."\n\n資金力："..M.FormatMoney(r.fundingPower)
                .."\n商会現金："..M.FormatMoney(r.cash).."\n物件の調達余力："..M.FormatMoney(r.reserves).."\n\n総資産："..M.FormatMoney(r.assets)
                .."\n所有物件："..r.propertyCount.."\n\n資金力＝現金＋物件調達余力\n評価額は総資産にのみ加算。\n\n★：自社 / ↑↓：商会を選択\n× / ○：第"..period.."期の決算へ")
        end
    elseif a.screen=="properties" or a.screen=="owned" or a.screen=="groups" or a.screen=="tactics" or a.screen=="management"
        or a.screen=="admin" or a.screen=="admin_pick" or a.screen=="strategy" or a.screen=="delegate_pick" then
        self.page=math.floor((a.index-1)/C.ui.pageSize)
        local heading=a.screen=="owned" and "所有物件" or (a.screen=="groups" and "グループ資金調達"
            or (a.screen=="tactics" and "駆け引き技" or (a.screen=="management" and "商会経営"
            or (a.screen=="strategy" and "交易会議・次の10期の方針" or (a.screen=="delegate_pick" and "支配人へ委任する通常物件" or "地域の物件")))))
        if a.screen=="admin" or a.screen=="admin_pick" then
            local left=a.admin and a.admin.left or 0
            self.ledgerHeading:SetText("第"..M.CurrentPeriod(a.state).."期  内政  /  残り行動 "..left.." / "..C.admin.actions
                ..(a.screen=="admin_pick" and ("  /  "..(a.adminPickName[a.admin.kind] or "").."先を選択") or "")
                .."  /  商会資金 "..M.FormatCompact(a.state.cash))
        else self.ledgerHeading:SetText(heading.."  /  "..#rows.." 件  /  "..(self.page+1).."頁  ←→切替") end
        for i,controls in ipairs(self.rows) do
            local index=self.page*C.ui.pageSize+i; local item=rows[index]; controls.box:SetHidden(not item)
            if item then
                if item.tactic then
                    controls.text:SetText((a.index==index and "◆ " or "   ")..item.tactic.name.."  ["..(item.learned and "習得" or "未習得").."]  "..M.FormatMoney(item.tactic.cost).." ゴールド")
                    controls.text:SetColor(unpack(item.learned and ink or {.52,.52,.48,1}))
                elseif item.group then
                    local g=item.group; controls.text:SetText((a.index==index and "◆ " or "   ")..g.name.."  ["..(g.learned and "習得" or "未習得").."]  "..g.count.."/"..g.minimum)
                    controls.text:SetColor(unpack(ink))
                elseif item.property then
                    local p=item.property; local allied=M.IsAllied(a.state,p.owner)
                    local owner=p.owner==C.playerId and "自社" or (p.owner==C.neutralId and "中立" or (allied and "同盟" or "敵"))
                    local risk=p.owner==C.playerId and M.RiskLabel(p.independenceRisk) or nil
                    -- ◎ registered real place (buyable from anywhere), ○ not registered yet.
                    local visitedPlace=p.canonical and M.IsPropertyVisited(a.state,p)
                    local visit=p.canonical and not visitedPlace and "/未登録" or ""
                    local mark=p.canonical and (visitedPlace and "◎" or "○") or ""
                    local stance=""
                    if p.owner~=C.playerId and (visitedPlace or not p.canonical) then
                        for _,sid in ipairs(M.NegotiationStances(a.state,p)) do stance=stance.."〈"..D.stanceById[sid].name.."〉" end
                    end
                    controls.text:SetText((a.index==index and "◆ " or "   ")..mark..p.name.."  ["..owner..(risk and "/"..risk or "")..visit.."]  "..M.FormatCompact(p.marketValue)..(stance~="" and "  "..stance or ""))
                    local riskColor=risk=="離反" and {.53,.53,.53,1} or risk=="危険" and {1,.52,.52,1}
                        or risk=="警戒" and {1,.77,.42,1} or risk=="注意" and {.93,.88,.58,1} or (allied and T.allyText) or ink
                    controls.text:SetColor(unpack(riskColor))
                else
                    controls.text:SetText((a.index==index and "◆ " or "   ")..item.label)
                    controls.text:SetColor(unpack(item.enabled==false and {.52,.52,.48,1} or ink))
                end
                controls.box:SetCenterColor(unpack(a.index==index and {.47,.41,.23,.65} or {.04,.065,.05,.36}))
            end
        end
        self.detail:SetText(row and (row.detailText or row.tactic and a:TacticDetail(row.tactic)
            or (row.group and a:GroupDetail(row.group) or (row.property and a:Detail(row.property) or a:ManagementDetail(row)))) or "記録はありません")
    elseif b then
        local target=a.state.properties[b.targetId]
        local stances=""
        for _,stance in ipairs(b.stances or {}) do
            stances=stances.."  〈"..D.stanceById[stance.id].name..(stance.broken and "：崩壊" or (stance.hits>1 and ("：あと"..stance.hits.."手") or "")).."〉"
        end
        self.battleTitle:SetText("第"..M.CurrentPeriod(a.state).."期  "..(b.mode=="defense" and "商会防衛" or "買収交渉").."  /  "..target.name.."  /  "..D.companies[b.defender].name..stances
            .."      交渉 "..(b.day or 1).."日目")
        self:RefreshBattleFrame()
        if row then
            local tabs={}
            for c,category in ipairs(a.battleCategories) do
                tabs[#tabs+1]=((a.battleCategory or 1)==c and "◆ " or "◇ ")..category.name
            end
            self.commandTabs:SetText(table.concat(tabs,"   ").."      ←→ / L1 R1：切替")
            self.command:SetText("‹ "..a.index.."/"..#rows.." ›  "..row.label)
            self.command:SetColor(unpack(row.enabled==false and {.52,.52,.48,1} or ink))
            local hint=row.hint or row.command=="request" and ("要求額 "..M.FormatMoney(a.engine:Quote(row.id)).." / 残高 "..M.FormatMoney(row.property.reserve).." / 負担 "..row.property.independenceRisk.." +"..row.property.independenceIncrease)
                or (row.command=="group" and (row.group.count.."件 / 調達倍率 "..M.FormatRatio(row.group.bonus)..((row.group.landmarks or 0)>0 and ("（実在地点 "..row.group.landmarks.."件）") or "").." / 全構成物件に負担")
                or (row.command=="tactic" and (row.tactic.description.." / コスト "..row.tactic.cost))
                or (row.command=="stabilize" and "最も危険な自社物件の独立危険度を下げる") or "投入資金は返還されません")
            self.commandHintText=hint
            self.commandHint:SetText(string.format("伝令 %.1f秒  |  %s",b.playerWait,hint))
        else self.commandHintText=nil end
        local log={}; for i=math.max(1,#b.log-2),#b.log do log[#log+1]=b.log[i] end; self.log:SetText(table.concat(log,"\n"))
    end
    local modalText=a.modal and a.modal.text
    if a.screen=="result" and not modalText then
        local heading=b.mode=="defense" and (b.result=="won" and "防衛成功 — 商会の旗を守りました" or "防衛不成立 — 物件の所有権を失いました")
            or (b.result=="won" and "契約締結 — 商会に新たな旗印" or "交渉終了 — 帳簿を見直しましょう")
        modalText=heading
            .."\n\n"..a.state.properties[b.targetId].name.."\n自社出資："..gold(b.playerBid).."　相手出資："..gold(b.enemyBid)
            .."\n商会資金の消費："..gold(b.treasurySpent).."\n交渉日数："..(b.day or 1).."日\n"..(b.result=="timeout" and "交渉期限切れ。" or "")
            ..(b.takeover and ("\n\n◆ "..b.takeover.name.."を傘下に収めた！\n"
                ..(b.takeover.body and "商会本体の買収が成立し、商会は解体されました。" or "全中枢を押さえ、商会は解体されました。")
                .."\n傘下物件 "..b.takeover.count.." 件（評価額 "..M.FormatCompact(b.takeover.value).."）と資金 "..gold(b.takeover.cash).." を獲得") or "")
            ..(function()
                -- Losing to a standing stance teaches its counter; breaking one is worth a line too.
                local lines={}
                for _,stance in ipairs(b.stances or {}) do
                    local st=D.stanceById[stance.id]
                    if stance.broken then lines[#lines+1]="構え「"..st.name.."」を崩した"
                    elseif b.result~="won" then lines[#lines+1]="構え「"..st.name.."」が崩れなかった――"..st.hint end
                end
                return #lines>0 and ("\n\n"..table.concat(lines,"\n")) or ""
            end)()
            ..(#(b.learnedTactics or {})>0 and "\n\n習得："..table.concat((function() local n={}; for _,id in ipairs(b.learnedTactics) do n[#n+1]=D.tacticById[id].name end; return n end)()," / ") or "")
            .."\n\n×："..(b.mode=="defense" and "内政へ" or "敵商会の攻撃判定へ")
    end
    local campaignModal=a.modal and a.modal.campaign
    self.campaignBackdrop:SetHidden(not campaignModal); self.campaignShade:SetHidden(not campaignModal)
    if campaignModal and self.campaignAsset~=a.modal.background then
        self.campaignAsset=a.modal.background; PBTrade.Assets.Apply(self.campaignBackdrop,self.campaignAsset)
    end
    self.modal:SetHidden(not modalText); self.modalText:SetText(modalText or "")
    self.fxPanel:SetHidden(not a.fx or a.screen=="title" or a.screen=="naming" or a.screen=="opening")
    if a.fx then
        self.fxText:SetText(a.fx.text)
        local colors={takeover={1,.8,.3,1},groupDiscovery={1,.84,.38,1},discovery={.93,.74,.29,1},defection={1,.38,.34,1},chapter={.67,.86,1,1},
            ending={1,.84,.38,1},settlement={.57,1,.72,1},tactic={.82,.68,1,1},period={1,.86,.55,1}}
        self.fxText:SetColor(unpack(colors[a.fx.kind] or T.gold))
    end
end
-- ESO controls do not expose SetClipsChildren. Crop texture geometry and UVs
-- together using the public TextureControl API, including partially visible rims.
local function clippedTexture(control,parent,x,y,w,h)
    local left,top=math.max(0,x),math.max(0,y)
    local right,bottom=math.min(parent:GetWidth(),x+w),math.min(parent:GetHeight(),y+h)
    local visible=right>left and bottom>top
    control:SetHidden(not visible)
    if not visible then return end
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT,parent,TOPLEFT,left,top)
    control:SetDimensions(right-left,bottom-top)
    control:SetTextureCoords(math.max(0,(left-x)/w),math.min(1,(right-x)/w),
        math.max(0,(top-y)/h),math.min(1,(bottom-y)/h))
end
-- Coin sprites are pooled on demand and capped per frame; creating the full
-- pool at load exhausts the shared per-frame add-on CPU budget on consoles.
function U:CoinControl(side,i)
    local controls=self.coinControls[side]
    local coin=controls[i]
    if coin or self.coinsCreated>=C.coins.createPerFrame then return coin end
    coin=WINDOW_MANAGER:CreateControl(nil,self.coinAreas[side],CT_TEXTURE)
    PBTrade.Assets.Apply(coin,"coin"); coin:SetDimensions(C.coins.width,C.coins.height)
    coin:SetColor(1,1,1,1); coin:SetDrawTier(DT_MEDIUM); coin:SetDrawLayer(DL_CONTROLS); coin:SetDrawLevel(i); coin:SetHidden(true)
    controls[i]=coin; self.coinsCreated=self.coinsCreated+1
    return coin
end
function U:RenderCoins()
    if not self.coins then return end
    self.coinsCreated=0
    for side,controls in ipairs(self.coinControls) do
        local frame=self.coins:Frame(side)
        local viewport=self.coinAreas[side]
        local center=(400*self.sx-C.coins.pileWidth)/2
        for i=1,math.min(#frame.coins,C.coins.limit) do self:CoinControl(side,i) end
        for i,control in ipairs(controls) do
            local coin=frame.coins[i]
            control:SetHidden(not coin)
            if coin then
                clippedTexture(control,viewport,center+coin.x,coin.y,
                    C.coins.width*coin.scale,C.coins.height*coin.scale)
                control:SetColor(coin.shade,coin.shade,coin.shade,1)
            end
        end
        local floor=self.floors[side]
        clippedTexture(floor,viewport,center+(C.coins.pileWidth-C.coins.plinthWidth)/2,
            (frame.plinthY or frame.floorY)+C.coins.plinthOffsetY,C.coins.plinthWidth,C.coins.plinthHeight)
    end
end
function U:Tick(dt)
    if not self.active then return end
    self:UpdateKeyboard(dt)
    PBTrade.Assets.PollAll(dt)
    if self.viewportWidth~=GuiRoot:GetWidth() or self.viewportHeight~=GuiRoot:GetHeight() then self:Resize() end
    self.app:Tick(dt)
    if self.coins and (self.app.screen=="battle" or self.app.screen=="result")
        and not (self.app.modal and self.app.modal.pauseBattle) then
        self.bandFxTime=(self.bandFxTime or 0)+dt
        local impacts=self.coins:Tick(dt)
        PBTrade.Audio.Impact(self.coins,impacts)
    end
    -- Full text/list rebuilds allocate heavily (row tables, 1,303-property scans),
    -- so run them at a low rate or on a visible state change; animate every tick.
    local screen=self.app.screen
    self.fullRefreshElapsed=(self.fullRefreshElapsed or 0)+dt
    -- Only the negotiation screens change on their own; others redraw on input or on change.
    local timed=(screen=="battle" or screen=="result") and self.fullRefreshElapsed>=C.ui.fullRefreshSeconds
    if self:Changed() or timed then
        self:Refresh()
    elseif screen=="battle" or screen=="result" then
        self:RefreshBattleFrame()
    elseif screen=="opening" then
        self:RenderOpening()
    end
end
-- Crop a background to fill the full 1240x780 opening stage, then drift slowly inward.
local function stageCoords(name,zoom)
    local size=PBTrade.Assets.sizes[name] or {C.ui.width,C.ui.height}
    local stage=C.ui.width/C.ui.height; local ratio=size[1]/size[2]
    local fu,fv=1,1
    if ratio>stage then fu=stage/ratio else fv=ratio/stage end
    fu,fv=fu*(1-zoom),fv*(1-zoom)
    return (1-fu)/2,(1+fu)/2,(1-fv)/2,(1+fv)/2
end
-- Keep the proven HIGH text tier while revealing complete UTF-8 code points.
function U:RenderOpening()
    local a=self.app; local o=a.opening
    if not o then return end
    local page,timeline=a:OpeningPage()
    if not page then
        a:FinishOpening(); self:Refresh(); return
    end
    local O=C.opening
    if self.openingShownPage~=o.page or self.openingShownFor~=o then
        self.openingShownPage=o.page; self.openingShownFor=o; self.openingCount=nil
        PBTrade.Assets.Apply(self.openingArt,page.bg)
        self.openingArt:SetAlpha(1)
        self.openingPage:SetText(o.page.." / "..#o.pages)
        self.openingText:SetAlpha(1)
        self.openingText:SetHidden(false)
        for _,control in ipairs(self.openingCard) do control:SetHidden(page.portrait==nil) end
        if page.portrait then
            PBTrade.Assets.Apply(self.openingPortrait,page.portrait)
            self.openingSpeaker:SetText(page.speaker or "")
        end
    end
    local drift=math.min(1,o.pageTime/O.driftSeconds)
    self.openingArt:SetTextureCoords(stageCoords(page.bg,O.driftZoom*drift))
    local count=math.max(timeline.lead,PBTrade.Story.Visible(timeline,o.time))
    if count~=self.openingCount then
        self.openingCount=count
        self.openingText:SetText(table.concat(timeline.chars,"",1,count))
    end
    local done=o.time>=timeline.total
    self.openingHint:SetText(done and "×：次へ　　○：スキップ" or "×：全文表示　　○：スキップ")
    self.openingNext:SetHidden(not done)
    self.openingNext:SetAlpha(.35+.65*math.abs(math.sin(o.pageTime*3)))
end
