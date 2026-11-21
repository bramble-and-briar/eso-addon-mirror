-- Gold Standard: native, closable gamepad-friendly dashboards.
local GS=GoldStandard
local GOLD="|cE8BC63"; local GREEN="|c8BDEA7"; local WHITE="|cE6EBF2"; local MUTED="|cAAB7C3"; local END="|r"
local function label(parent,name,x,y,w,h,font)
    local c=WINDOW_MANAGER:CreateControl(name,parent,CT_LABEL)
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
    c:SetDimensions(w,h)
    c:SetFont(font or "ZoFontGamepad27")
    c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return c
end
local function button(parent,name,x,y,w,text,callback)
    local c=WINDOW_MANAGER:CreateControl(name,parent,CT_BUTTON)
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
    c:SetDimensions(w,45)
    c:SetFont("ZoFontGamepad27")
    c:SetNormalFontColor(.94,.80,.47,1)
    c:SetMouseOverFontColor(1,1,1,1)
    c:SetText(text)
    c:SetHandler("OnClicked",callback)
    return c
end

-- TME shared blue frame; anchored strips follow resizing and scaling.
local function TMEBlueFrame(parent)
    local function edge(a,b,c,d,vertical)
        local t=WINDOW_MANAGER:CreateControl(nil,parent,CT_TEXTURE)
        t:SetAnchor(a,parent,b,0,0); t:SetAnchor(c,parent,d,0,0)
        if vertical then t:SetWidth(2) else t:SetHeight(2) end
        t:SetColor(0.20,0.65,0.90,0.95); t:SetMouseEnabled(false)
        t:SetDrawLayer(DL_BACKGROUND); t:SetDrawLevel(3)
    end
    edge(TOPLEFT,TOPLEFT,TOPRIGHT,TOPRIGHT,false)
    edge(BOTTOMLEFT,BOTTOMLEFT,BOTTOMRIGHT,BOTTOMRIGHT,false)
    edge(TOPLEFT,TOPLEFT,BOTTOMLEFT,BOTTOMLEFT,true)
    edge(TOPRIGHT,TOPRIGHT,BOTTOMRIGHT,BOTTOMRIGHT,true)
end

local function background(parent,name,r,g,b,a)
    local bg=WINDOW_MANAGER:CreateControl(name,parent,CT_BACKDROP)
    bg:SetAnchorFill(parent)
    bg:SetCenterColor(0.015,0.028,0.048,a)
    bg:SetEdgeColor(0.20,0.65,0.90,0.95)
    TMEBlueFrame(parent)
    return bg
end
-- Slider-driven, resolution-independent positions (0..100% of the available
-- screen area), with independent size percentages for each UI element.
-- Migrate old pixel coordinates once so existing players keep their placement.
local LAYOUT_DEFAULT={hud={x=14,y=12,scale=100},panel={x=50,y=50,scale=100},popup={x=90,y=16,scale=100},toast={x=50,y=9,scale=100},wealth={x=75,y=55,scale=100}}
function GS:GetLayoutControl(id)
    if id=="hud" then return self.hud end
    if id=="panel" then return self.panel end
    if id=="popup" then return self.flipPopup end
    if id=="toast" then return self.toastControl end
    if id=="wealth" then return self.wealthHUD end
end
function GS:LayoutValue(id,axis)
    local key=id..(axis=="x" and "PosX" or axis=="y" and "PosY" or "Scale")
    local v=self.saved[key]
    if type(v)=="number" then return v end
    if axis=="scale" then return 100 end
    local ctrl=self:GetLayoutControl(id)
    local dim=(axis=="x" and GuiRoot:GetWidth() or GuiRoot:GetHeight())
    local len=ctrl and (axis=="x" and ctrl:GetWidth() or ctrl:GetHeight()) or 0
    local oldKey=(id=="panel" and "panel" or id)..(axis=="x" and "X" or "Y")
    local old=self.saved[oldKey]
    local offset=old
    if id=="panel" and type(old)=="number" then offset=(dim-len)/2+old end
    if type(offset)=="number" then
        v=math.floor(math.max(0,math.min(100,offset/math.max(1,dim-len)*100))+0.5)
    else v=LAYOUT_DEFAULT[id][axis] end
    self.saved[key]=v
    return v
end
function GS:ApplyLayout(id)
    local ctrl=self:GetLayoutControl(id)
    if not ctrl then return end
    local scale=math.max(65,math.min(150,self:LayoutValue(id,"scale"))) / 100
    -- SetScale affects visual footprint; clamp the anchor against that footprint.
    ctrl:SetScale(scale)
    local availableX=math.max(0,GuiRoot:GetWidth()-ctrl:GetWidth()*scale)
    local availableY=math.max(0,GuiRoot:GetHeight()-ctrl:GetHeight()*scale)
    local x=availableX*math.max(0,math.min(100,self:LayoutValue(id,"x")))/100
    local y=availableY*math.max(0,math.min(100,self:LayoutValue(id,"y")))/100
    ctrl:ClearAnchors()
    ctrl:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,math.floor(x+0.5),math.floor(y+0.5))
end
function GS:ChangeLayoutSetting(id,axis,value)
    local key=id..(axis=="x" and "PosX" or axis=="y" and "PosY" or "Scale")
    self.saved[key]=math.floor(tonumber(value) or 0)
    self:ApplyLayout(id)
    if self.layoutMode then self:LayoutSelectionPreview() end
    if self.RefreshUI and not self.layoutMode then self:RefreshUI() end
end
function GS:ResetSliderLayout(id)
    local def=LAYOUT_DEFAULT[id]
    if not def then return end
    for _,axis in ipairs({"x","y","scale"}) do
        self.saved[id..(axis=="x" and "PosX" or axis=="y" and "PosY" or "Scale")]=def[axis]
    end
    self:ApplyLayout(id)
    if self.layoutMode then self:LayoutSelectionPreview() end
end
function GS:ShowLayoutSliderPreview(id)
    -- Toggle a single live preview without changing ESO scenes or keybind groups.
    if self.sliderPreviewId==id then
        self:CloseSliderPreview()
        return
    end
    self:CloseSliderPreview()
    self.sliderPreviewId=id
    local ctrl=self:GetLayoutControl(id)
    if not ctrl then return end
    self.sliderPreviewWasHidden=ctrl:IsHidden()
    ctrl:SetHidden(false)
    if id=="wealth" then
        self.wealthTitle:SetText(GOLD.."WEALTH MANAGEMENT • PREVIEW"..END)
        self.wealthDetail:SetText("Craft Bag excess above 100  |  Furnishings above 1")
    elseif id=="panel" then
        self.panelTitle:SetText(GOLD.."GOLD STANDARD • DASHBOARD POSITION PREVIEW"..END)
        self:RenderPanel()
    elseif id=="popup" then
        self.flipPopupTitle:SetText(GOLD.."FLIP FINDER • POSITION PREVIEW"..END)
        self.flipPopupSubtitle:SetText("Adjust position / size with the Add-Ons sliders")
    elseif id=="toast" then
        self.toastLabel:SetText("LOOT PREVIEW: +1,250g")
    elseif id=="hud" then
        self.hudTitle:SetText(GOLD.."GOLD STANDARD • POSITION PREVIEW"..END)
    end
end
function GS:CloseSliderPreview()
    if not self.sliderPreviewId then return end
    local id=self.sliderPreviewId
    local ctrl=self:GetLayoutControl(id)
    if ctrl and self.sliderPreviewWasHidden then ctrl:SetHidden(true) end
    self.sliderPreviewId=nil
    self.sliderPreviewWasHidden=nil
    if self.RefreshUI then self:RefreshUI() end
end
function GS:InitializeUI()
    local hud=WINDOW_MANAGER:CreateTopLevelWindow("GoldStandard_HUD")
    hud:SetDimensions(585,310)
    hud:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,self.saved.hudX or 230,self.saved.hudY or 140)
    hud:SetClampedToScreen(true)
    hud:SetMouseEnabled(true)
    hud:SetMovable(true)
    hud:SetHandler("OnMoveStop",function(c)
        local x,y=c:GetLeft(),c:GetTop()
        self.saved.hudX=x;self.saved.hudY=y
    end)
    background(hud,"GoldStandard_HUD_Background",.045,.07,.10,.91)
    self.hud=hud
    self.hudTitle=label(hud,"GoldStandard_HUD_Title",12,4,335,25,"ZoFontGamepad27")
    self.hudLine=label(hud,"GoldStandard_HUD_Line",12,38,560,38)
    self.hudGold=label(hud,"GoldStandard_HUD_Gold",12,79,560,34,"ZoFontGamepad22")
    self.hudAP=label(hud,"GoldStandard_HUD_AP",12,118,560,34,"ZoFontGamepad22")
    self.hudAPValue=label(hud,"GoldStandard_HUD_AP_Value",12,154,560,42,"ZoFontGamepad22")
    self.hudTel=label(hud,"GoldStandard_HUD_TelVar",12,202,560,42,"ZoFontGamepad22")
    self.hudLast=label(hud,"GoldStandard_HUD_Last",12,256,560,42,"ZoFontGamepad22")
    hud:SetHidden(not self.saved.showHUD)

    local win=WINDOW_MANAGER:CreateTopLevelWindow("GoldStandard_Dashboard")
    win:SetDimensions(1120,790)
    win:SetAnchor(CENTER,GuiRoot,CENTER,self.saved.panelX or 0,self.saved.panelY or 0)
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetHandler("OnMoveStop",function(c)
        -- Save position relative to the screen center rather than absolute pixels.
        self.saved.panelX=c:GetLeft()-(GuiRoot:GetWidth()-c:GetWidth())/2
        self.saved.panelY=c:GetTop()-(GuiRoot:GetHeight()-c:GetHeight())/2
    end)
    background(win,"GoldStandard_Dashboard_BG",.035,.055,.08,.985)
    win:SetHidden(true)
    self.panel=win
    self.panelTitle=label(win,"GoldStandard_Dashboard_Title",25,10,900,55,"ZoFontGamepad42")
    self.panelSubtitle=label(win,"GoldStandard_Dashboard_Sub",26,64,1040,35,"ZoFontGamepad22")
    self.tabs={"empire","tracker","advisor","flip","sales","history"}
    self.tabButtons={}
    for i,tab in ipairs(self.tabs) do
        self.tabButtons[tab]=button(win,"GoldStandard_Tab_"..tab,18+(i-1)*178,107,171,string.upper(tab),function() self:ShowPanel(tab) end)
    end
    self.close=button(win,"GoldStandard_Dashboard_Close",940,15,155,"CLOSE (CIRCLE)",function()self:HidePanel()end)
    self.rows={}
    for i=1,12 do
        self.rows[i]=label(win,"GoldStandard_Dashboard_Row"..i,28,176+(i-1)*42,1064,41,"ZoFontGamepad27")
    end
    self.footer=label(win,"GoldStandard_Dashboard_Footer",26,692,1065,35,"ZoFontGamepad22")
    self.primary=button(win,"GoldStandard_Dashboard_Primary",25,735,520,"REFRESH",function() self:PanelAction() end)
    self.secondary=button(win,"GoldStandard_Dashboard_Secondary",575,735,520,"RESET SESSION",function() self:PanelSecondary() end)
    -- Do not automatically dismiss on global SceneStateChanged.
    -- Native scene transitions can report SCENE_SHOWING immediately after
    -- this overlay is opened. Closure belongs to Circle / CLOSE only.
    self.currentTab="empire";self.historyOffset=0;self.flipOffset=0;self.empirePage=1
    -- Settings-hosted interface: NEVER replace or push the gamepad Add-Ons scene.
    -- Keybinds are installed directly into the *existing* gamepad options scene.
    -- This is essential on console: a scene push/show from a LibAddonMenu action
    -- can dismiss the Add-Ons scene and return controller actions to gameplay.
    self.dashboardFromSettings=false
    -- PS5 gamepad: L2/R2 switch tabs; L1/R1 page within a tab.
    -- Triggers are deliberately ethereal (ESO's native gamepad tab pattern).
    self.keybinds={
        alignment=KEYBIND_STRIP_ALIGN_LEFT,
        {name="PREVIOUS TAB",keybind="UI_SHORTCUT_LEFT_TRIGGER",ethereal=true,callback=function()self:SwitchTab(-1)end},
        {name="NEXT TAB",keybind="UI_SHORTCUT_RIGHT_TRIGGER",ethereal=true,callback=function()self:SwitchTab(1)end},
        {name="PAGE UP",keybind="UI_SHORTCUT_LEFT_SHOULDER",ethereal=true,callback=function()self:PageScroll(-1)end},
        {name="PAGE DOWN",keybind="UI_SHORTCUT_RIGHT_SHOULDER",ethereal=true,callback=function()self:PageScroll(1)end},
        {name=function()return "ACTION" end,keybind="UI_SHORTCUT_PRIMARY",callback=function()self:PanelAction()end},
        {name=function()return "SCROLL UP" end,keybind="UI_SHORTCUT_SECONDARY",callback=function()self:NavigateSecondary()end},
        {name=function()return "SCROLL DOWN" end,keybind="UI_SHORTCUT_TERTIARY",callback=function()self:NavigateTertiary()end},
        {name="BACK / CLOSE",keybind="UI_SHORTCUT_NEGATIVE",callback=function()self:HidePanel()end},
    }
    local toast=WINDOW_MANAGER:CreateTopLevelWindow("GoldStandard_Toast")
    toast:SetDimensions(660,70);toast:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,self.saved.toastX or math.max(0,(GuiRoot:GetWidth()-660)/2),self.saved.toastY or 110);toast:SetHidden(true)
    toast:SetMouseEnabled(true);toast:SetMovable(true)
    toast:SetHandler("OnMoveStop",function(c)self.saved.toastX=c:GetLeft();self.saved.toastY=c:GetTop()end)
    background(toast,"GoldStandard_Toast_BG",.04,.13,.09,.93)
    self.toastLabel=label(toast,"GoldStandard_Toast_Text",16,7,630,55,"ZoFontGamepad27")
    self.toastControl=toast
    -- Independent wealth HUD: purely informational, never blocks controller input.
    local wealth=WINDOW_MANAGER:CreateTopLevelWindow("GoldStandard_WealthHUD")
    wealth:SetDimensions(680,465)
    wealth:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,1100,650)
    wealth:SetClampedToScreen(true)
    wealth:SetMouseEnabled(false)
    wealth:SetHidden(not self.saved.showWealthHUD)
    background(wealth,"GoldStandard_Wealth_BG",.035,.06,.095,.96)
    self.wealthHUD=wealth
    self.wealthTitle=label(wealth,"GoldStandard_Wealth_Title",18,8,645,40,"ZoFontGamepad36")
    self.wealthDetail=label(wealth,"GoldStandard_Wealth_Detail",18,58,645,32,"ZoFontGamepad22")
    self.wealthMaterialLine=label(wealth,"GoldStandard_Wealth_Mats",18,96,645,42,"ZoFontGamepad27")
    self.wealthFurnitureLine=label(wealth,"GoldStandard_Wealth_Furn",18,141,645,42,"ZoFontGamepad27")
    self.wealthTotalLine=label(wealth,"GoldStandard_Wealth_Total",18,191,645,40,"ZoFontGamepad27")
    self.wealthRows={}
    for i=1,5 do
        self.wealthRows[i]=label(wealth,"GoldStandard_Wealth_Row"..i,18,244+(i-1)*38,645,37,"ZoFontGamepad22")
    end
    self.wealthFooter=label(wealth,"GoldStandard_Wealth_Footer",18,436,645,25,"ZoFontGamepad18")
    -- Non-modal trader popup; keeps the guild-trader interface open and usable.
    local pop=WINDOW_MANAGER:CreateTopLevelWindow("GoldStandard_FlipPopup")
    pop:SetDimensions(690,465)
    pop:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,self.saved.popupX or math.max(0,GuiRoot:GetWidth()-735),self.saved.popupY or 160)
    pop:SetMovable(true)
    pop:SetHandler("OnMoveStop",function(c) self.saved.popupX=c:GetLeft();self.saved.popupY=c:GetTop() end)
    pop:SetClampedToScreen(true)
    pop:SetMouseEnabled(true)
    pop:SetHidden(true)
    background(pop,"GoldStandard_FlipPopupBG",.035,.055,.085,.97)
    self.flipPopup=pop
    self.flipPopupTitle=label(pop,"GoldStandard_FlipPopupTitle",20,12,620,45,"ZoFontGamepad36")
    self.flipPopupSubtitle=label(pop,"GoldStandard_FlipPopupSubtitle",20,60,650,35,"ZoFontGamepad22")
    self.flipPopupRows={}
    for i=1,6 do
        self.flipPopupRows[i]=label(pop,"GoldStandard_FlipPopupRow"..i,20,108+(i-1)*45,650,44,"ZoFontGamepad22")
    end
    self.flipPopupFooter=label(pop,"GoldStandard_FlipPopupFooter",20,386,650,38,"ZoFontGamepad22")
    -- Popup is passive: no Close button. ESO trader close event dismisses it.
    -- Full-screen gamepad-safe position editor; the real windows are used
    -- as live previews and each coordinate is persisted independently.
    self.layoutTargets={
        {id="hud",control=hud,keyX="hudX",keyY="hudY",title="TRACKER HUD"},
        {id="panel",control=win,keyX="panelX",keyY="panelY",title="DASHBOARD"},
        {id="popup",control=pop,keyX="popupX",keyY="popupY",title="FLIP FINDER POPUP"},
        {id="toast",control=toast,keyX="toastX",keyY="toastY",title="LOOT NOTIFICATION"},
    }
    self.layoutIndex=1
    self.layoutMode=false
    self.layoutKeys={alignment=KEYBIND_STRIP_ALIGN_LEFT,
        {name="NEXT WINDOW",keybind="UI_SHORTCUT_RIGHT_SHOULDER",callback=function()self:CycleLayoutTarget(1)end},
        {name="PREVIOUS WINDOW",keybind="UI_SHORTCUT_LEFT_SHOULDER",callback=function()self:CycleLayoutTarget(-1)end},
        {name="SAVE POSITIONS",keybind="UI_SHORTCUT_PRIMARY",callback=function()self:StopLayoutPreview()end},
        {name="RESET SELECTED",keybind="UI_SHORTCUT_SECONDARY",callback=function()self:ResetLayoutTarget()end},
        {name="CLOSE PREVIEW",keybind="UI_SHORTCUT_NEGATIVE",callback=function()self:StopLayoutPreview()end},
    }
    local banner=WINDOW_MANAGER:CreateTopLevelWindow("GoldStandard_PositionPreview")
    banner:SetDimensions(900,115)
    banner:SetAnchor(TOP,GuiRoot,TOP,0,12)
    banner:SetHidden(true)
    background(banner,"GoldStandard_PositionPreviewBG",.06,.075,.10,.97)
    self.layoutBanner=banner
    self.layoutLabel=label(banner,"GoldStandard_PositionPreviewText",18,8,864,95,"ZoFontGamepad27")
    -- Position previews never create their own scene. Slider positioning
    -- happens while native Add-Ons settings retains focus.
    -- No popup keybind group: Circle remains owned by the native guild trader.
    -- Apply persisted slider placement/scaling to all four widgets.
    for _,id in ipairs({"hud","panel","popup","toast","wealth"}) do self:ApplyLayout(id) end
end
function GS:LayoutMoveTarget(target,x,y)
    local ctl=target.control
    local scale=ctl.GetScale and ctl:GetScale() or 1
    local maxX=math.max(0,GuiRoot:GetWidth()-ctl:GetWidth()*scale)
    local maxY=math.max(0,GuiRoot:GetHeight()-ctl:GetHeight()*scale)
    self.saved[target.id.."PosX"]=math.floor(math.max(0,math.min(100,x/math.max(1,maxX)*100))+0.5)
    self.saved[target.id.."PosY"]=math.floor(math.max(0,math.min(100,y/math.max(1,maxY)*100))+0.5)
    self:ApplyLayout(target.id)
end
function GS:LayoutSelectionPreview()
    if not self.layoutMode then return end
    local target=self.layoutTargets[self.layoutIndex]
    for i,item in ipairs(self.layoutTargets) do
        -- Preview all four elements without executing gameplay transactions.
        item.control:SetHidden(false)
    end
    self.hudTitle:SetText(GOLD.."GOLD STANDARD • TRACKER PREVIEW"..END)
    self.hudLine:SetText("Session value 12,345g    Gold/hour 6,789g")
    self.hudLast:SetText("Move this HUD with the RIGHT STICK")
    self.panelTitle:SetText(GOLD.."GOLD STANDARD • DASHBOARD PREVIEW"..END)
    self.panelSubtitle:SetText("Layout editor: reposition windows with right stick")
    self.flipPopupTitle:SetText(GOLD.."FLIP FINDER • POSITION PREVIEW"..END)
    self.flipPopupSubtitle:SetText("Automatic trader results would appear here")
    self.flipPopupFooter:SetText("This is a placement preview, not a trader scan.")
    self.toastLabel:SetText("LOOT NOTIFICATION PREVIEW: +1,250g")
    self.layoutLabel:SetText(GOLD.."POSITION EDITOR  ["..self.layoutIndex.."/4] "..target.title..END.."\n"..
        WHITE.."Right Stick: move highlighted window | L1/R1: select window | X: save | Square: reset | Circle: exit"..END)
end
function GS:CycleLayoutTarget(d)
    self.layoutIndex=((self.layoutIndex-1+d)%#self.layoutTargets)+1
    self:LayoutSelectionPreview()
end
function GS:ResetLayoutTarget()
    self:ResetSliderLayout(self.layoutTargets[self.layoutIndex].id)
    self:LayoutSelectionPreview()
end
function GS:StartLayoutPreview()
    -- The former right-stick editor switched ESO scenes and exposed gameplay.
    -- The supported PS5 editor is now the native Add-Ons X/Y/Size sliders.
    self:ShowLayoutSliderPreview("hud")
end
function GS:StopLayoutPreview()
    self:CloseSliderPreview()
end
function GS:ShowFlipPopup()
    -- Only the trader-open lifecycle may display the real Flip Finder popup.
    -- Position previews use ShowLayoutSliderPreview("popup") instead.
    if not self.openTrader then return end
    if self.flipPopup and self.saved.flipPopup~=false then
        self.flipPopup:SetHidden(false)
        self:UpdateFlipPopup()
    end
end
function GS:HideFlipPopup()
    -- Called when the trader is closed; do not take over the native Circle key.
    if self.flipPopup then self.flipPopup:SetHidden(true) end
end
function GS:UpdateFlipPopup()
    if self.layoutMode then return end
    if not self.flipPopup or self.flipPopup:IsHidden() or not self.market then return end
    local m=self.market
    local best=self:BestFlips()
    self.flipPopupTitle:SetText(GOLD.."FLIP FINDER"..END.."  "..WHITE.."AUTO SCAN"..END)
    self.flipPopupSubtitle:SetText("Pages "..self:PageCount().." | Listings "..#m.items.." | Deals "..#best)
    for i=1,6 do
        local r=best[i]
        if r then
            local name=r.name or "Item"
            self.flipPopupRows[i]:SetText(i..". "..name.." x"..r.qty.." | "..self:Money(r.asking).."g | "..GREEN.."+"..self:Money(r.profit).."g ("..string.format("%.0f",r.roi).."%)"..END)
        else self.flipPopupRows[i]:SetText(i==1 and "No qualifying deals in scanned listings yet." or "") end
    end
    self.flipPopupFooter:SetText(MUTED..(m.message or "Opening trader...")..END)
end
function GS:ShowToast(s)
    if self.layoutMode then return end
    if not self.toastControl then return end
    self.toastLabel:SetText(GREEN..tostring(s)..END)
    self.toastControl:SetHidden(false)
    local token=GetFrameTimeMilliseconds()
    self.toastToken=token
    if zo_callLater then zo_callLater(function()
        if self.toastControl and self.toastToken==token then self.toastControl:SetHidden(true) end
    end,(self.saved.toastSeconds or 3)*1000) end
end
-- Gamepad START opens the native main menu. Hide only the real-time
-- Tracker HUD while it is open; do not hide the trader popup or change
-- the current scene, focus, or saved HUD visibility preference.
function GS:IsStartMenuOpen()
    if self.startMenuOpen then return true end
    if not SCENE_MANAGER or not SCENE_MANAGER.GetScene then return false end
    local scene=SCENE_MANAGER:GetScene("mainMenuGamepad")
    if not scene or not scene.GetState then return false end
    local state=scene:GetState()
    return state==SCENE_SHOWING or state==SCENE_SHOWN
end
function GS:UpdateTrackerHUDVisibility()
    if not self.hud or not self.saved then return end
    -- Position preview is explicitly requested by the user and should
    -- remain visible while adjusting HUD sliders within Add-Ons settings.
    local preview=self.sliderPreviewId=="hud"
    self.hud:SetHidden(not (self.saved.showHUD and not self:IsStartMenuOpen()) and not preview)
end
function GS:RegisterStartMenuVisibility()
    if not SCENE_MANAGER or not SCENE_MANAGER.GetScene then return end
    local scene=SCENE_MANAGER:GetScene("mainMenuGamepad")
    if not scene or not scene.RegisterCallback then return end
    self.startMenuOpen = scene.GetState and
        (scene:GetState()==SCENE_SHOWING or scene:GetState()==SCENE_SHOWN) or false
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState==SCENE_SHOWING or newState==SCENE_SHOWN then
            self.startMenuOpen=true
        elseif newState==SCENE_HIDING or newState==SCENE_HIDDEN then
            -- Keep the HUD hidden through the closing transition.
            self.startMenuOpen=newState~=SCENE_HIDDEN
        end
        self:UpdateTrackerHUDVisibility()
    end)
    self:UpdateTrackerHUDVisibility()
end
function GS:RefreshUI()
    if self.layoutMode then return end
    if not self.hud or not self.saved then return end
    self:UpdateTrackerHUDVisibility()
    self.hudTitle:SetText(GOLD.."GOLD STANDARD"..END.."   "..MUTED.."Know What It's Worth."..END)
    local s=self.session
    if self.saved.hudMode==1 then
        self.hudLine:SetText("Recent: "..(self.lastValue and (GOLD..self:Money(self.lastValue).."g"..END) or "unpriced"))
    elseif self.saved.hudMode==3 then
        self.hudLine:SetText("Value "..GOLD..self:Money(self:NetEstimated()).."g"..END.."   Gross "..self:Money(s.found).."g")
    else
        self.hudLine:SetText("GS Net "..GOLD..self:Money(self:NetEstimated()).."g"..END.."   "..GREEN..self:Money(self:NetPerHour()).."g/h"..END)
    end
    local cur=self:ReadCurrencies()
    local function bal(v) return type(v)=="number" and self:Money(v).."g" or "unavailable" end
    if self.saved.hudShowGold~=false then
        self.hudGold:SetText("Gold on hand: "..GOLD..bal(cur.carried)..END.."    Bank: "..GOLD..bal(cur.banked)..END)
    else self.hudGold:SetText("") end
    if self.saved.hudShowAP~=false then
        if type(cur.ap)=="number" then
            local converted=self:APConversion(cur.ap)
            self.hudAP:SetText("Total AP: "..GOLD..self:Money(cur.ap)..END)
            self.hudAPValue:SetText("Converted Gold (AP): "..(converted.gross and (GREEN.."~"..self:Money(converted.gross).."g"..END) or MUTED.."Unavailable"..END))
        else
            self.hudAP:SetText("Total AP: --")
            self.hudAPValue:SetText("Converted Gold (AP): --")
        end
    else self.hudAP:SetText("");self.hudAPValue:SetText("") end
    if self.saved.hudShowTelVar~=false then
        if type(cur.telVar)=="number" then
            local converted=self:TelVarConversion(cur.telVar)
            self.hudTel:SetText("Tel Var: "..GOLD..self:Money(cur.telVar)..END.."\nConverted Gold (Tel Var): "..(converted.gross and (GREEN.."~"..self:Money(converted.gross).."g"..END) or MUTED.."Unavailable"..END))
        else
            self.hudTel:SetText("Tel Var: --\nConverted Gold (Tel Var): --")
        end
    else self.hudTel:SetText("") end
    self:RefreshWealthHUD()
    self.hudLast:SetText("Last: "..(self.lastLoot or "none"))
    if self.panel and not self.panel:IsHidden() then self:RenderPanel() end
end
function GS:RefreshWealthHUD()
    if not self.wealthHUD or not self.saved then return end
    local preview=self.sliderPreviewId=="wealth"
    if not preview then self.wealthHUD:SetHidden(not self.saved.showWealthHUD) end
    if not self.saved.showWealthHUD and not preview then return end
    local s=self:ScanWealth(false)
    self.wealthTitle:SetText(GOLD.."GOLD STANDARD  /  WEALTH"..END)
    self.wealthDetail:SetText(MUTED.."SURPLUS VALUATION  •  TSC RESALE ESTIMATES"..END)
    self.wealthMaterialLine:SetText("Craft Bag >"..self.saved.wealthMaterialKeep..": "..GREEN..self:Money(s.matGold).."g"..END.."   ("..s.matExcess.." excess)")
    self.wealthFurnitureLine:SetText("Furnishings >"..self.saved.wealthFurnitureKeep..": "..GREEN..self:Money(s.furnitureGold).."g"..END.."   ("..s.furnitureExcess.." excess)")
    self.wealthTotalLine:SetText("KNOWN SURPLUS VALUE: "..GOLD..self:Money(s.knownTotal).."g"..END)
    local items={}
    for _,r in ipairs(s.materials) do if r.value then items[#items+1]=r end end
    for _,r in ipairs(s.furnishings) do if r.value then items[#items+1]=r end end
    table.sort(items,function(a,b) return a.value>b.value end)
    for i,control in ipairs(self.wealthRows) do
        local r=items[i]
        if r then
            local name=(GetItemLinkName and GetItemLinkName(r.link)) or r.link
            control:SetText(i..". "..name.." x"..self:Money(r.excess).."   "..GREEN..self:Money(r.value).."g"..END)
        else control:SetText("") end
    end
    local unavailable=(not s.matAccessible and "Craft Bag not readable; " or "")..(not s.furnitureAccessible and "Vault not readable; " or "")
    self.wealthFooter:SetText(MUTED..unavailable.."Unpriced excess types: "..s.unpriced..END)
end

function GS:InstallPanelKeybinds()
    if KEYBIND_STRIP and not self.bindsShown then
        KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds)
        self.bindsShown=true
    end
    if KEYBIND_STRIP and self.bindsShown and KEYBIND_STRIP.UpdateKeybindButtonGroup then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds)
    end
end
function GS:RemovePanelKeybinds()
    if KEYBIND_STRIP and self.bindsShown then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybinds)
        self.bindsShown=false
    end
end
function GS:TogglePanel()
    if self.panel and not self.panel:IsHidden() then self:HidePanel()
    else self:ShowPanel(self.currentTab) end
end
function GS:ShowPanel(tab)
    if tab=="wealth" then tab="empire";self.empirePage=6 end
    if tab=="settings" then tab="empire" end
    self.currentTab=tab or self.currentTab or "empire"
    self:CloseSliderPreview()
    self:HideFlipPopup()
    -- Deliberately do NOT call SCENE_MANAGER:Push, Show, Hide or ShowBaseScene.
    -- Keep Add-Ons settings active, so gamepad buttons cannot cast abilities.
    self.panel:SetHidden(false)
    if self.currentTab=="empire" then self:BuildEmpire(false) end
    self:InstallPanelKeybinds()
    self:RenderPanel()
end
function GS:HidePanel()
    self:RemovePanelKeybinds()
    if self.panel then self.panel:SetHidden(true) end
    self.dashboardFromSettings=false
    -- No scene transitions: ESO stays on the exact native Add-Ons page.
end
function GS:SwitchTab(direction)
    local index=1
    for i,tab in ipairs(self.tabs) do if tab==self.currentTab then index=i;break end end
    self.currentTab=self.tabs[((index-1+direction)%#self.tabs)+1]
    -- Never call ShowPanel() here. Scene re-entry was stealing controller focus.
    self:RenderPanel()
    if KEYBIND_STRIP and self.bindsShown and KEYBIND_STRIP.UpdateKeybindButtonGroup then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds)
    end
end
function GS:PageScroll(direction)
    if self.currentTab=="history" then
        self.historyOffset=math.max(0,math.min(math.max(0,#self.saved.history-11),self.historyOffset+direction*10))
    elseif self.currentTab=="flip" then
        self.flipOffset=math.max(0,math.min(math.max(0,#self:BestFlips()-8),self.flipOffset+direction*8))
    elseif self.currentTab=="empire" then
        self.empirePage=math.max(1,math.min(6,(self.empirePage or 1)+direction))
    else
        -- On non-paged tabs L1/R1 can be used as alternate tab navigation.
        self:SwitchTab(direction)
        return
    end
    self:RenderPanel()
end
function GS:NavigateSecondary()
    self:Scroll(-1)
end
function GS:NavigateTertiary()
    self:Scroll(1)
end
function GS:Scroll(direction)
    if self.currentTab=="history" then self.historyOffset=math.max(0,math.min(math.max(0,#self.saved.history-11),self.historyOffset+direction))
    elseif self.currentTab=="flip" then self.flipOffset=math.max(0,math.min(math.max(0,#self:BestFlips()-8),self.flipOffset+direction))
    elseif self.currentTab=="empire" then self.empirePage=math.max(1,math.min(6,(self.empirePage or 1)+direction))
    end
    self:RenderPanel()
end
function GS:PanelAction()
    if self.currentTab=="flip" then
        self:CaptureTraderResults()
        self:Print(self.market.message)
    elseif self.currentTab=="advisor" then
        local n,reason=self:OwnListings()
        self:Print(n and ("Saved "..n.." accessible listings.") or reason)
    elseif self.currentTab=="empire" then self:SaveEmpireSnapshot();self:RenderPanel()
    elseif self.currentTab=="tracker" then self:Refresh()
    elseif self.currentTab=="history" then self.historyOffset=0;self:Refresh()
    elseif self.currentTab=="sales" then
        local added,msg=self:ScanPersonalSales();self:Print(msg or "Sales unavailable");self:Refresh() end
end
function GS:PanelSecondary()
    if self.currentTab=="tracker" then self:ResetSession()
    elseif self.currentTab=="flip" then self:ResetTrader("Scan cleared. Search at trader to capture new pages.")
    elseif self.currentTab=="advisor" then self:OwnListings()
    elseif self.currentTab=="empire" then self.empirePage=1;self:RenderPanel()
    elseif self.currentTab=="sales" then self:ScanPersonalSales()
    elseif self.currentTab=="history" then self.historyOffset=math.max(0,#self.saved.history-11);self:RenderPanel() end
end
function GS:RenderPanel()
    if not self.panel or self.panel:IsHidden() then return end
    local tab=self.currentTab
    self.panelTitle:SetText(GOLD.."GOLD STANDARD"..END.."   /   "..string.upper(tab))
    self.panelSubtitle:SetText("Know What It's Worth.  |  L2/R2: tabs  |  L1/R1: pages")
    local rows,footer={},""
    self.primary:SetText("REFRESH");self.secondary:SetText("RESET SESSION")
    if tab=="tracker" then
        local s=self.session
        rows={
            GOLD.."SESSION ECONOMICS"..END,
            "Gold Standard Net Gold: "..self:Money(self:NetEstimated()).."g",
            "Gross item acquisitions: "..self:Money(s.found).."g",
            "Crafting inputs consumed (known): -"..self:Money(s.consumed).."g",
            "Materials / crafting outputs recorded: "..self:Money(s.output).."g (included above)",
            "Wallet gold gained: +"..self:Money(s.rawIn).."g  |  Vendor sales: +"..self:Money(s.vendorSales or 0).."g",
            "Wallet gold spent: -"..self:Money(s.rawOut).."g  |  Vendor purchases: -"..self:Money(s.vendorPurchases or 0).."g",
            "AP gained: +"..self:Money(s.apGained or 0).."  |  Gold value: +"..self:Money(self:CurrencyDeltaGold("ap",s.apGained or 0)).."g",
            "AP spent: -"..self:Money(s.apSpent or 0).."  |  Gold value: -"..self:Money(self:CurrencyDeltaGold("ap",s.apSpent or 0)).."g",
            "Tel Var gained: +"..self:Money(s.telGained or 0).."  |  Gold value: +"..self:Money(self:CurrencyDeltaGold("tel",s.telGained or 0)).."g",
            "Tel Var spent: -"..self:Money(s.telSpent or 0).."  |  Gold value: -"..self:Money(self:CurrencyDeltaGold("tel",s.telSpent or 0)).."g",
            "Net estimated gold/hour: "..self:Money(self:NetPerHour()).."g/h",
            "Elapsed: "..math.floor(self:Elapsed()/60).."m "..(self:Elapsed()%60).."s",
            "Items gained: "..self:Money(s.items).."  |  Unpriced units: "..self:Money(s.unpriced),
            "Lifetime acquired value: "..self:Money(self.saved.lifetimeFound).."g",
            "Lifetime earned: "..self:Money(self.saved.lifetimeRawIn).."g | Lifetime spent: "..self:Money(self.saved.lifetimeRawOut).."g",
        }
        footer="Session ledger  |  L2/R2: sections  |  L1/R1: navigation"
        self.secondary:SetText("RESET SESSION")
    elseif tab=="advisor" then
        local w=self:ScanWealth(false)
        local listings=self.saved.listings or {}
        local low,high,unpriced,ask,market=0,0,0,0,0
        for _,r in ipairs(listings) do
            local asking=tonumber(r.asking) or 0
            ask=ask+asking
            if type(r.market)=="number" and r.market>0 then
                market=market+r.market
                if asking<r.market*.85 then low=low+1 end
                if asking>r.market*1.20 then high=high+1 end
            else unpriced=unpriced+1 end
        end
        rows[1]=GOLD.."YOUR NEXT BEST FINANCIAL MOVES"..END
        rows[2]=GREEN.."SURPLUS TO SELL: "..self:Money(w.knownTotal).."g"..END
        rows[3]="Materials above "..self.saved.wealthMaterialKeep..": "..self:Money(w.matExcess).." units  |  "..self:Money(w.matGold).."g"
        rows[4]="Furnishings above "..self.saved.wealthFurnitureKeep..": "..self:Money(w.furnitureExcess).." units  |  "..self:Money(w.furnitureGold).."g"
        rows[5]=GOLD.."REPRICE YOUR TRADER LISTINGS"..END
        rows[6]="At least 15% below TSC: "..low.." listings  |  20% above: "..high
        rows[7]="Asking total: "..self:Money(ask).."g  |  Known TSC value: "..self:Money(market).."g"
        rows[8]="Without TSC reference: "..unpriced.." listings"
        rows[9]=GOLD.."NEXT ACTIONS"..END
        rows[10]=low>0 and ("Review "..low.." underpriced listing(s) before relisting") or "No clearly underpriced observed listings"
        rows[11]=high>0 and ("Review "..high.." potentially overpriced listing(s)") or "No clearly overpriced observed listings"
        rows[12]=w.knownTotal>0 and "Review your surplus holdings in EMPIRE > SURPLUS" or "No priced surplus above your keep thresholds"
        self.primary:SetText("SCAN MY LISTINGS");self.secondary:SetText("SCAN MY LISTINGS")
    elseif tab=="flip" then
        local best=self:BestFlips();local m=self.market
        rows[1]=GOLD.."TRADER: "..m.trader..END
        rows[2]="Observed: "..#m.items.." listings | pages: "..self:PageCount().." | qualified: "..#best
        rows[3]="Filters: ≥"..self:Money(self.saved.minProfit).."g NET, ≥"..self.saved.minROI.."% ROI; fee "..self.saved.resaleFee.."%"
        for i=1,math.min(8,#best-self.flipOffset) do
            local r=best[i+self.flipOffset]
            rows[i+3]=(i+self.flipOffset)..". "..r.link.." x"..r.qty.."  BUY "..self:Money(r.asking).."g"..
                "  "..GREEN.."+"..self:Money(r.profit).."g / "..string.format("%.0f",r.roi).."%"..END
        end
        if #best==0 then rows[4]="No qualifying flips in the observed search pages." end
        rows[12]=MUTED..(m.message or "Open a trader and search.")..END
        footer="Automatic scanning at visited guild traders"
        self.primary:SetText("SCAN CURRENT PAGE");self.secondary:SetText("CLEAR SCAN")
    elseif tab=="empire" then
        rows,footer=self:EmpirePageRows(self.empirePage or 1)
        self.primary:SetText("REFRESH & SAVE SNAPSHOT");self.secondary:SetText("EMPIRE OVERVIEW")
    elseif tab=="sales" then
        local n,gross,net=self:SalesSummary()
        rows[1]=GOLD.."PERSONAL GUILD TRADER SALES"..END
        rows[2]="Cached sales: "..n.." | Gross: "..self:Money(gross).."g | After recorded tax: "..self:Money(net).."g"
        rows[3]="Last cache scan: "..tostring(self.saved.salesScanTime or "never")
        for i=1,9 do
            local sale=self.saved.sales[i]
            if sale then
                rows[i+3]=i..". "..(sale.link or "Item").." x"..(sale.qty or 1).."  SOLD "..self:Money(sale.price).."g"
            end
        end
        footer="Personal sales recorded from loaded guild history"
        self.primary:SetText("SCAN SALES CACHE");self.secondary:SetText("SCAN SALES CACHE")
    elseif tab=="history" then
        rows[1]=GOLD.."RECENT TRANSACTIONS ("..#self.saved.history..")"..END
        for i=1,11 do
            local h=self.saved.history[i+self.historyOffset]
            if h then
                local desc=h.link or h.source or "Transaction"
                local val=h.value and (self:Money(h.value).."g") or "unpriced"
                rows[i+1]=(i+self.historyOffset)..". "..desc.."  "..tostring(h.qty or 0).."  |  "..val
            end
        end
        footer="L1/R1: page  |  Triangle/Square: scroll"
        self.primary:SetText("LATEST");self.secondary:SetText("OLDEST")
    end
    -- Font scaling is intentionally much larger than the PC client UI.
    -- Long ESO item links can overflow; constrain each row to its panel.
    for i,c in ipairs(self.rows) do c:SetText(rows[i] or "") end
    self.footer:SetText(MUTED..footer..END)
end
