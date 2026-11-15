-- Controller navigation around the original CMX windows and HUD.
local A=CMX2
local C={items={},controls={},selection=1,history={}}
A.Controller=C
local Screen=ZO_Gamepad_ParametricList_Screen:Subclass()

function C.ClearMenu() C.items={} end
function C.AddMenuItem(label,callback)
    C.items[#C.items+1]={label=label,callback=callback}
end
function C.AddSubMenu(label,items)
    C.items[#C.items+1]={label=label,items=items}
end
function C.ShowMenu()
    if #C.items==0 then return end
    C.history={}
    C.returnScene=SCENE_MANAGER:GetCurrentScene():GetName()
    SCENE_MANAGER:Show("CMX2_CONTEXT_SCENE")
    C.screen:PerformUpdate()
end
function C.TooltipExit()
    if InformationTooltip then ClearTooltip(InformationTooltip) end
    if C.hint then C.hint:SetHidden(true) end
    for tooltip,scale in pairs(C.tooltipScales or {}) do tooltip:SetScale(scale) end
    C.tooltipScales={}
end

function C.ShowOutput(text,channel)
    if ZO_IsConsoleOrGameCoreUI and ZO_IsConsoleOrGameCoreUI() then
        ZO_Dialogs_ShowGamepadDialog("CMX2_OUTPUT",{text=text})
    else
        if type(channel)=="string" then StartChatInput(channel .. text)
        else StartChatInput(text,channel) end
    end
end

function C.IsReportOpen()
    return SCENE_MANAGER:IsShowing("CMX2_REPORT_SCENE")
end

function C.HintText(control)
    local text=control.tooltip
    local lines={}
    local function Add(value)
        if type(value)=="number" then value=GetString(value)
        elseif type(value)=="function" then
            local ok,result=pcall(value)
            value=ok and result or nil
        end
        if type(value)=="string" and value~="" then lines[#lines+1]=value end
    end
    if type(text)=="table" then for _,value in ipairs(text) do Add(value) end else Add(text) end
    if #lines==0 then
        if control.GetText then Add(control:GetText()) end
        if #lines==0 then
            for _,name in ipairs({"Label","Name","Text","Title"}) do
                local child=control:GetNamedChild(name)
                if child and child.GetText then Add(child:GetText());if #lines>0 then break end end
            end
        end
    end
    return table.concat(lines,"\n\n")
end

function C.ShowHint(control)
    if not C.hint then return end
    local text=C.HintText(control)
    C.hint:SetHidden(text=="")
    if text=="" then return end
    if InformationTooltip then ClearTooltip(InformationTooltip) end
    local width=math.min(460,GuiRoot:GetWidth()-40)
    C.hint:SetWidth(width)
    C.hintText:SetWidth(width-40)
    C.hintText:SetText(text)
    local height=C.hintText:GetTextHeight()
    C.hintText:SetHeight(height)
    C.hint:SetHeight(height+28)
    C.hint:ClearAnchors()
    local x,y=control:GetCenter()
    local left=x+control:GetWidth()/2+18
    if left+width>GuiRoot:GetWidth()-20 then left=x-control:GetWidth()/2-width-18 end
    left=math.max(20,left)
    local top=math.max(20,math.min(y-height/2,GuiRoot:GetHeight()-height-48))
    C.hint:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,left,top)
end

function C.EnlargeSpecialTooltips()
    C.tooltipScales=C.tooltipScales or {}
    for _,name in ipairs({"ItemTooltip","AbilityTooltip","InformationTooltip"}) do
        local tooltip=_G[name]
        if tooltip and not tooltip:IsControlHidden() then
            local scale=C.tooltipScales[tooltip] or tooltip:GetScale()
            C.tooltipScales[tooltip]=scale
            tooltip:SetScale(math.max(scale,1.75))
        end
    end
end

function Screen:Initialize(control,scene)
    ZO_Gamepad_ParametricList_Screen.Initialize(self,control,ZO_GAMEPAD_HEADER_TABBAR_DONT_CREATE,true,scene)
    self.headerData={titleText="Combat Metrics 2"}
    self:SetListsUseTriggerKeybinds(true)
    -- The stock d-pad query calls private IsKeyDown from add-on code on console.
    -- Give this list a public stick-only query instead of invoking that path.
    self:GetMainList().movementController=ZO_MovementController:New(
        MOVEMENT_CONTROLLER_DIRECTION_VERTICAL,nil,function()
            return DIRECTIONAL_INPUT:GetY(ZO_DI_LEFT_STICK)
        end)
end
function Screen:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor={alignment=KEYBIND_STRIP_ALIGN_LEFT,
        {name="Auswählen",keybind="UI_SHORTCUT_PRIMARY",callback=function()
            local entry=self:GetMainList():GetTargetData()
            local item=entry and entry.item
            if not item then return end
            if item.items then C.history[#C.history+1]=C.items;C.items=item.items;self:PerformUpdate()
            elseif item.callback then item.callback();self:PerformUpdate() end
        end},
        {name="Zurück",keybind="UI_SHORTCUT_NEGATIVE",callback=function()
            if #C.history>0 then C.items=table.remove(C.history);self:PerformUpdate()
            else SCENE_MANAGER:Show(C.returnScene or "CMX2_REPORT_SCENE") end
        end},
    }
end
function Screen:PerformUpdate()
    local list=self:GetMainList()
    local selected=list:GetSelectedIndex() or 1
    list:Clear()
    ZO_GamepadGenericHeader_Refresh(self.header,self.headerData)
    for _,item in ipairs(C.items) do
        local label=type(item.label)=="function" and item.label() or item.label or item.name or item[1] or "Eintrag"
        local entry=ZO_GamepadEntryData:New(label)
        entry.item=item
        if not item.callback then item.callback=item.func or item[2] end
        list:AddEntry("ZO_GamepadMenuEntryTemplate",entry)
    end
    list:Commit()
    if list:GetNumEntries()>0 then list:SetSelectedIndexWithoutAnimation(math.min(selected,list:GetNumEntries())) end
    self.dirty=false
end
function Screen:OnShowing() self:PerformUpdate() end

local function Visible(control)
    return control and not control:IsControlHidden() and control:GetWidth()>1 and control:GetHeight()>1
end
function C.Rebuild()
    local controls={}
    local function Walk(control)
        if not Visible(control) then return end
        if control~=CombatMetrics2_Report and (control:GetHandler("OnMouseUp") or control:GetHandler("OnClicked")
            or control:GetHandler("OnMouseDoubleClick") or control:GetHandler("OnMouseEnter")) then
            local x,y=control:GetCenter()
            if x>=0 and y>=0 and x<=GuiRoot:GetWidth() and y<=GuiRoot:GetHeight() then controls[#controls+1]=control end
        end
        for i=1,control:GetNumChildren() do Walk(control:GetChild(i)) end
    end
    Walk(CombatMetrics2_Report)
    table.sort(controls,function(a,b)
        local ax,ay=a:GetCenter();local bx,by=b:GetCenter()
        if math.abs(ay-by)<5 then return ax<bx end
        return ay<by
    end)
    C.controls=controls
    C.selection=1
    for i,control in ipairs(controls) do if control==C.focused then C.selection=i;return end end
end

function C.Focus(index)
    local old=C.focused
    C.selection=math.max(1,math.min(index,#C.controls))
    C.focused=C.controls[C.selection]
    if old~=C.focused then
        local exit=old and old:GetHandler("OnMouseExit")
        if exit then pcall(exit,old) end
        C.TooltipExit()
    end
    local control=C.focused
    C.outline:SetHidden(control==nil)
    if control then
        C.outline:ClearAnchors()
        C.outline:SetAnchor(TOPLEFT,control,TOPLEFT,-3,-3)
        C.outline:SetAnchor(BOTTOMRIGHT,control,BOTTOMRIGHT,3,3)
        if old~=control then
            local enter=control:GetHandler("OnMouseEnter")
            if enter then pcall(enter,control) end
        end
        C.ShowHint(control)
        C.EnlargeSpecialTooltips()
    end
end

function C.Move(dx,dy)
    C.Rebuild()
    local current=C.focused or C.controls[1]
    if not current then return end
    local x,y=current:GetCenter()
    local best,score
    for i,control in ipairs(C.controls) do
        local tx,ty=control:GetCenter();local vx,vy=tx-x,ty-y
        local forward=vx*dx+vy*dy
        if forward>4 then
            local sideways=math.abs(vx*dy-vy*dx)
            local candidate=forward+sideways*3
            if not score or candidate<score then best,score=i,candidate end
        end
    end
    C.Focus(best or C.selection)
end

function C.Activate(right)
    if not Visible(C.focused) then C.Rebuild();C.Focus(C.selection) end
    local control=C.focused
    if not control then return end
    local fn=control:GetHandler("OnMouseUp") or control:GetHandler("OnClicked") or control:GetHandler("OnMouseDoubleClick")
    if fn then fn(control,right and MOUSE_BUTTON_INDEX_RIGHT or MOUSE_BUTTON_INDEX_LEFT,true,C.multiSelect or false,false,false) end
    zo_callLater(function()
        if SCENE_MANAGER:IsShowing("CMX2_REPORT_SCENE") then C.Rebuild();C.Focus(C.selection) end
    end,30)
end

function C.Scroll(direction)
    local control=C.focused
    while control and control~=GuiRoot do
        local handler=control:GetHandler("OnMouseWheel")
        if handler then handler(control,direction,false,false,false);return end
        control=control:GetParent()
    end
end

function C:UpdateDirectionalInput()
    if not SCENE_MANAGER:IsShowing("CMX2_REPORT_SCENE") then return end
    local x,y=DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)
    local now=GetFrameTimeMilliseconds()
    if math.abs(x)<0.4 and math.abs(y)<0.4 then C.nextMove=0
    elseif now>=(C.nextMove or 0) then
        if math.abs(x)>math.abs(y) then C.Move(x>0 and 1 or -1,0)
        else C.Move(0,y>0 and -1 or 1) end
        C.nextMove=now+180
    end
    local scroll=DIRECTIONAL_INPUT:GetY(ZO_DI_RIGHT_STICK)
    if math.abs(scroll)>0.4 and now>=(C.nextScroll or 0) then C.Scroll(scroll>0 and 1 or -1);C.nextScroll=now+120 end
end

function C.Settings()
    C.ClearMenu()
    local db=A.db
    C.AddMenuItem(function()
        return db.lightmode and "Aufzeichnung: nur Live-Werte" or "Aufzeichnung: vollständige Kampfberichte"
    end)
    local function Toggle(label,target,key,after)
        C.AddMenuItem(function() return label .. (target[key] and ": AN" or ": AUS") end,function()
            target[key]=not target[key];if after then after() end
        end)
    end
    local live=CombatMetrics2_LiveReport
    Toggle("Live-HUD",db.liveReport,"enabled",function() A.UpdateEvents() end)
    for _,entry in ipairs({{"DPS","damageOut"},{"Einzelziel-DPS","damageOutSingle"},{"HPS","healOut"},
        {"Eingehender Schaden","damageIn"},{"Eingehende Heilung","healIn"},{"Zeit","time"}}) do
        Toggle(entry[1],db.liveReport,entry[2],function() live:Refresh() end)
    end
    C.AddMenuItem(function() return "HUD-Layout: " .. db.liveReport.layout end,function()
        local layouts={Compact="Horizontal",Horizontal="Vertical",Vertical="Compact"}
        db.liveReport.layout=layouts[db.liveReport.layout] or "Compact";live:Refresh()
    end)
    C.AddMenuItem(function() return string.format("HUD-Größe: %.1f",db.liveReport.scale) end,function()
        live:Resize(db.liveReport.scale>=2 and 0.8 or db.liveReport.scale+0.1)
    end)
    C.AddMenuItem("HUD-Position wechseln",function()
        C.position=(C.position or 0)%3+1
        local positions={{GuiRoot:GetWidth()/2,GuiRoot:GetHeight()-220},{GuiRoot:GetWidth()-250,GuiRoot:GetHeight()-220},{250,200}}
        local p=positions[C.position];live:ClearAnchors();live:SetAnchor(CENTER,GuiRoot,TOPLEFT,p[1],p[2]);A.SavePosition(live)
    end)
    C.AddMenuItem(function() return string.format("Bericht-Größe: %.1f",db.FightReport.scale) end,function()
        CombatMetrics2_Report:Resize(db.FightReport.scale>=1.5 and 0.7 or db.FightReport.scale+0.1)
    end)
    Toggle("Gruppenwerte",db,"recordgrp",function() A.UpdateEvents() end)
    Toggle("Leichtmodus – keine Kampfberichte",db,"lightmode",function() A.UpdateEvents() end)
    Toggle("Leichtmodus in PvP",db,"lightmodeincyrodil",function() A.UpdateEvents() end)
    C.ShowMenu()
end

function C.Initialize()
    ZO_Dialogs_RegisterCustomDialog("CMX2_OUTPUT",{
        gamepadInfo={dialogType=GAMEPAD_DIALOGS.BASIC},
        title={text="Combat Metrics 2 – Zusammenfassung"},
        mainText={text=function(dialog) return dialog.data.text end},
        buttons={{keybind="DIALOG_PRIMARY",text=SI_DIALOG_CONFIRM}},
    })
    local context=ZO_Scene:New("CMX2_CONTEXT_SCENE",SCENE_MANAGER)
    context:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    context:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    context:AddFragment(ZO_FadeSceneFragment:New(CombatMetrics2_ContextWindow))
    C.screen=Screen:New(CombatMetrics2_ContextWindow,context)
    C.outline=CombatMetrics2_ControllerFocus
    C.hint=CombatMetrics2_ControllerHint
    C.hintText=CombatMetrics2_ControllerHintText
    C.outline:SetHidden(true)
    local keys
    keys={alignment=KEYBIND_STRIP_ALIGN_LEFT,
        {name="Auswählen",keybind="UI_SHORTCUT_PRIMARY",callback=function() C.Activate(false) end},
        {name="Kontext",keybind="UI_SHORTCUT_SECONDARY",callback=function() C.Activate(true) end},
        {name="Einstellungen",keybind="UI_SHORTCUT_TERTIARY",callback=C.Settings},
        {name="Zurück",keybind="UI_SHORTCUT_NEGATIVE",callback=function() CombatMetrics2_Report:Toggle() end},
        {name="Vorheriges Feld",keybind="UI_SHORTCUT_LEFT_SHOULDER",callback=function() C.Rebuild();C.Focus(C.selection-1) end},
        {name="Nächstes Feld",keybind="UI_SHORTCUT_RIGHT_SHOULDER",callback=function() C.Rebuild();C.Focus(C.selection+1) end},
        {name=function() return C.multiSelect and "Mehrfachauswahl: AN" or "Mehrfachauswahl: AUS" end,
            keybind="UI_SHORTCUT_LEFT_STICK",callback=function() C.multiSelect=not C.multiSelect;KEYBIND_STRIP:UpdateKeybindButtonGroup(keys) end},
    }
    local scene=SCENE_MANAGER:GetScene("CMX2_REPORT_SCENE")
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:RegisterCallback("StateChange",function(_,state)
        if state==SCENE_SHOWN then
            KEYBIND_STRIP:AddKeybindButtonGroup(keys)
            DIRECTIONAL_INPUT:Activate(C,CombatMetrics2_Report)
            zo_callLater(function() C.Rebuild();C.Focus(C.selection) end,60)
        elseif state==SCENE_HIDING then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(keys)
            DIRECTIONAL_INPUT:Deactivate(C);C.outline:SetHidden(true);C.TooltipExit()
        end
    end)
    if LibRadialMenu then
        LibRadialMenu:RegisterAddon("CombatMetrics2","Combat Metrics 2")
        LibRadialMenu:RegisterEntry("CombatMetrics2","Kampfbericht öffnen","report",
            "/esoui/art/menubar/gamepad/gp_playermenu_icon_character.dds",function() CombatMetrics2_Report:Toggle() end)
    end
end

function A.MakeMenu(defaults) C.defaults=defaults end
A.OpenSettings=C.Settings
