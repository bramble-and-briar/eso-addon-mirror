-- Controller navigation around the original CMX windows and HUD.
local A=CMX2
local C={items={},controls={},selection=1,history={}}
A.Controller=C
local Screen=ZO_Gamepad_ParametricList_Screen:Subclass()

-- Flat native backdrops avoid depending on custom DDS edge assets on console.
-- Mirror subsequent edge-colour changes so inactive/resize overlays stay hidden.
function C.InitializeFrame(control,thickness,r,g,b,a)
    if control.cmx2FrameLines then return end
    local lines={}
    local wm=GetWindowManager()
    for _,side in ipairs({"Top","Bottom","Left","Right"}) do
        local line=wm:CreateControl(nil,control,CT_BACKDROP)
        line:SetMouseEnabled(false)
        line:SetExcludeFromResizeToFitExtents(true)
        line:SetEdgeColor(0,0,0,0)
        if side=="Top" or side=="Bottom" then
            line:SetAnchor(side=="Top" and TOPLEFT or BOTTOMLEFT,control,side=="Top" and TOPLEFT or BOTTOMLEFT)
            line:SetAnchor(side=="Top" and TOPRIGHT or BOTTOMRIGHT,control,side=="Top" and TOPRIGHT or BOTTOMRIGHT)
            line:SetHeight(thickness)
        else
            line:SetAnchor(side=="Left" and TOPLEFT or TOPRIGHT,control,side=="Left" and TOPLEFT or TOPRIGHT)
            line:SetAnchor(side=="Left" and BOTTOMLEFT or BOTTOMRIGHT,control,side=="Left" and BOTTOMLEFT or BOTTOMRIGHT)
            line:SetWidth(thickness)
        end
        lines[#lines+1]=line
    end
    control.cmx2FrameLines=lines
    local setEdge=control.SetEdgeColor
    control.SetEdgeColor=function(self,r,g,b,a)
        setEdge(self,r,g,b,a)
        for _,line in ipairs(lines) do line:SetCenterColor(r,g,b,a or 1) end
    end
    control:SetEdgeColor(r or 1,g or 1,b or 1,a or 0)
end

function C.ClearMenu()
    if C.hudPreview then C.SetHUDPreview(false) end
    C.items={}
end

function C.SetHUDPreview(enabled)
    C.hudPreview=enabled==true
    local live=CombatMetrics2_LiveReport
    if C.hudPreview then
        if C.hudDrawTier==nil then C.hudDrawTier=live:GetDrawTier() end
        live:SetDrawTier(DT_HIGH)
        live:Refresh()
    elseif C.hudDrawTier~=nil then
        live:SetDrawTier(C.hudDrawTier)
        C.hudDrawTier=nil
    end
    if C.previewFrame then
        C.previewFrame:ClearAnchors()
        C.previewFrame:SetAnchor(TOPLEFT,live,TOPLEFT,-6,-34)
        C.previewFrame:SetAnchor(BOTTOMRIGHT,live,BOTTOMRIGHT,6,6)
        C.previewFrame:SetHidden(not C.hudPreview)
    end
    live:Toggle(A.db.liveReport.enabled)
end

function C.MoveHUD(dx,dy)
    local live=CombatMetrics2_LiveReport
    local x,y=live:GetCenter()
    local halfWidth,halfHeight=live:GetWidth()/2,live:GetHeight()/2
    x=math.max(halfWidth+12,math.min(GuiRoot:GetWidth()-halfWidth-12,x+dx))
    y=math.max(halfHeight+46,math.min(GuiRoot:GetHeight()-halfHeight-12,y+dy))
    live:ClearAnchors()
    live:SetAnchor(CENTER,GuiRoot,TOPLEFT,x,y)
    A.SavePosition(live)
end
function C.AddMenuItem(label,callback)
    C.items[#C.items+1]={label=label,callback=callback}
end
function C.AddSubMenu(label,items)
    C.items[#C.items+1]={label=label,items=items}
end
function C.ShowMenu()
    if #C.items==0 then return end
    C.history={}
    local current=SCENE_MANAGER:GetCurrentScene()
    local name=current and current:GetName()
    -- Settings can be opened from the report's gear context menu. Never
    -- overwrite the original destination with the context scene itself.
    if name~="CMX2_CONTEXT_SCENE" then C.returnScene=name end
    if not C.returnScene or C.returnScene=="CMX2_CONTEXT_SCENE" then
        C.returnScene="CMX2_REPORT_SCENE"
    end
    if name~="CMX2_CONTEXT_SCENE" then SCENE_MANAGER:Show("CMX2_CONTEXT_SCENE") end
    C.screen:PerformUpdate()
end
function C.CloseMenu()
    if C.hudPreview then C.SetHUDPreview(false) end
    C.history={}
    local destination=C.returnScene
    if not destination or destination=="CMX2_CONTEXT_SCENE" then destination="CMX2_REPORT_SCENE" end
    SCENE_MANAGER:Show(destination)
end

function C.TooltipExit()
    if C.HideDetails then C.HideDetails() end
    -- A report can close without moving away from its selected row. Its
    -- OnMouseExit is then never called, so clear legacy tooltips explicitly.
    for _,name in ipairs({"InformationTooltip","ItemTooltip","SkillTooltip","AbilityTooltip","ChampionSkillTooltip"}) do
        local tooltip=_G[name]
        if tooltip then ClearTooltip(tooltip) end
    end
    if C.hint then C.hint:SetHidden(true) end
    for tooltip,scale in pairs(C.tooltipScales or {}) do tooltip:SetScale(scale) end
    C.tooltipScales={}
end

function C.ShowOutput(text,channel)
    if ZO_IsConsoleOrGameCoreUI and ZO_IsConsoleOrGameCoreUI() then
        -- Queue after the report has actually returned; scene-hiding callbacks
        -- can otherwise consume a dialog before its fragment is visible.
        C.pendingOutput={text=text}
        if SCENE_MANAGER:IsShowing("CMX2_CONTEXT_SCENE") then C.CloseMenu() end
        zo_callLater(C.FlushOutput,0)
    else
        if type(channel)=="string" then StartChatInput(channel .. text)
        else StartChatInput(text,channel) end
    end
end

function C.FlushOutput()
    if not C.pendingOutput or not C.IsReportOpen() then return end
    local scene=SCENE_MANAGER:GetScene("CMX2_REPORT_SCENE")
    if scene.GetState and scene:GetState()~=SCENE_SHOWN then return end
    local data=C.pendingOutput
    C.pendingOutput=nil
    C.TooltipExit()
    ZO_Dialogs_ShowGamepadDialog("CMX2_OUTPUT",data)
end

function C.IsReportOpen()
    return SCENE_MANAGER:IsShowing("CMX2_REPORT_SCENE")
end

function C.HintText(control)
    if C.GetScrollOwner(control) and not control.tooltip then
        return "Liste: rechter Stick hoch/runter. Linker Stick: Eintrag auswählen."
    end
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
    if C.detailVisible then C.hint:SetHidden(true);return end
    local text=C.HintText(control)
    C.hint:SetHidden(text=="")
    if text=="" then return end
    if InformationTooltip then ClearTooltip(InformationTooltip) end
    local boundLeft,boundTop,boundRight,boundBottom=20,20,GuiRoot:GetWidth()-20,GuiRoot:GetHeight()-28
    if C.GetDetailBounds then boundLeft,boundTop,boundRight,boundBottom=C.GetDetailBounds() end
    local width=math.min(420,boundRight-boundLeft)
    C.hint:SetWidth(width)
    C.hintText:SetWidth(width-40)
    C.hintText:SetText(text)
    local height=C.hintText:GetTextHeight()
    if height+28>boundBottom-boundTop and C.ShowDetail then
        C.hint:SetHidden(true)
        C.ShowDetail("text","Hinweis",text)
        return
    end
    C.hintText:SetHeight(height)
    C.hint:SetHeight(height+28)
    C.hint:ClearAnchors()
    local x,y=control:GetCenter()
    -- A fixed right-hand slot keeps every row's hint in the same place.
    local left=math.max(boundLeft,boundRight-width)
    local top=math.max(boundTop,math.min(y-height/2,boundBottom-height-28))
    C.hint:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,left,top)
end

function C.EnlargeSpecialTooltips()
    C.tooltipScales=C.tooltipScales or {}
    for _,name in ipairs({"ItemTooltip","AbilityTooltip","SkillTooltip","ChampionSkillTooltip","InformationTooltip"}) do
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
            elseif item.callback then
                item.callback()
                if SCENE_MANAGER:IsShowing("CMX2_CONTEXT_SCENE") then self:PerformUpdate() end
            end
        end},
        {name="Zurück",keybind="UI_SHORTCUT_NEGATIVE",callback=function()
            if #C.history>0 then C.items=table.remove(C.history);self:PerformUpdate()
            else C.CloseMenu() end
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
function Screen:OnShowing()
    ZO_Gamepad_ParametricList_Screen.OnShowing(self)
    self:PerformUpdate()
end

local function Visible(control)
    return control and not control:IsControlHidden() and control:GetWidth()>1 and control:GetHeight()>1
end
function C.GetScrollOwner(control)
    while control and control~=GuiRoot do
        if control.scroll and control.scroll.GetScrollExtents and control.scrollbar then return control end
        control=control:GetParent()
    end
end

function C.Rebuild()
    local controls={}
    local positions={}
    -- Iterative traversal avoids console call-stack limits on nested reports.
    local pending={CombatMetrics2_Report}
    while #pending>0 do
        local control=table.remove(pending)
        if Visible(control) then
            if control~=CombatMetrics2_Report and (control:GetHandler("OnMouseUp") or control:GetHandler("OnClicked")
                or control:GetHandler("OnMouseDoubleClick") or control:GetHandler("OnMouseEnter")
                or control:GetHandler("OnMouseWheel") or (C.GetScrollOwner(control)==control)) then
                local x,y=control:GetCenter()
                if (x>=0 and y>=0 and x<=GuiRoot:GetWidth() and y<=GuiRoot:GetHeight()) or C.GetScrollOwner(control) then
                    controls[#controls+1]=control
                    positions[control]={row=math.floor(y/5),x=x,y=y,index=#controls}
                end
            end
            for i=control:GetNumChildren(),1,-1 do pending[#pending+1]=control:GetChild(i) end
        end
    end
    -- Sort a geometry snapshot with a strict, deterministic ordering. Comparing
    -- live positions with a five-pixel tolerance can form cycles during layout
    -- (A < B < C < A), aborting focus creation on the real report.
    table.sort(controls,function(a,b)
        local pa,pb=positions[a],positions[b]
        if pa.row~=pb.row then return pa.row<pb.row end
        if pa.x~=pb.x then return pa.x<pb.x end
        if pa.y~=pb.y then return pa.y<pb.y end
        return pa.index<pb.index
    end)
    C.controls=controls
    C.selection=1
    for i,control in ipairs(controls) do if control==C.focused then C.selection=i;return end end
end

function C.RefreshOutline()
    local control=C.focused
    if not C.outline then return false end
    if not Visible(control) then C.outline:SetHidden(true);return false end
    C.outline:ClearAnchors()
    C.outline:SetAnchor(TOPLEFT,control,TOPLEFT,-3,-3)
    C.outline:SetAnchor(BOTTOMRIGHT,control,BOTTOMRIGHT,3,3)
    C.outline:SetHidden(false)
    return true
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
        local scrollOwner=C.GetScrollOwner(control)
        if scrollOwner and scrollOwner~=control then ZO_Scroll_ScrollControlIntoView(scrollOwner,control) end
        C.RefreshOutline()
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
    local current=Visible(C.focused) and C.focused or C.controls[1]
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
    C.RestoreFocus()
end

function C.Scroll(direction)
    if C.detailVisible and C.detailScrolling then C.ScrollDetails(direction);return end
    local owner=C.GetScrollOwner(C.focused)
    if owner then
        ZO_Scroll_ScrollRelative(owner,-direction*60)
        -- Close hints anchored to a row that has moved out of the viewport.
        C.TooltipExit()
        C.focused=owner
        C.Rebuild();C.Focus(C.selection)
        return
    end
    local control=C.focused
    while control and control~=GuiRoot do
        local handler=control:GetHandler("OnMouseWheel")
        if handler then handler(control,direction,false,false,false);return end
        control=control:GetParent()
    end
end

function C.RestoreFocus()
    C.focusGeneration=(C.focusGeneration or 0)+1
    local generation=C.focusGeneration
    local attempts=0
    local function restore()
        if generation~=C.focusGeneration or not C.IsReportOpen() then return end
        if ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog() then return end
        C.Rebuild()
        C.Focus(C.selection)
        attempts=attempts+1
        if not C.focused and attempts<10 then zo_callLater(restore,60) end
    end
    zo_callLater(restore,60)
end

function C:UpdateDirectionalInput()
    if not SCENE_MANAGER:IsShowing("CMX2_REPORT_SCENE") then return end
    if ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog() then return end
    local now=GetFrameTimeMilliseconds()
    if now>=(C.nextFocusCheck or 0) then
        C.nextFocusCheck=now+250
        if not Visible(C.focused) or (C.outline and C.outline:IsControlHidden()) then
            C.Rebuild();C.Focus(C.selection)
        end
    end
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
    for _,move in ipairs({{"links",-40,0},{"rechts",40,0},{"oben",0,-40},{"unten",0,40}}) do
        local dx,dy=move[2],move[3]
        C.AddMenuItem("HUD nach " .. move[1],function() C.MoveHUD(dx,dy) end)
    end
    C.AddMenuItem(function() return string.format("Bericht-Größe: %.1f",db.FightReport.scale) end,function()
        CombatMetrics2_Report:Resize(db.FightReport.scale>=1.5 and 0.7 or db.FightReport.scale+0.1)
    end)
    Toggle("Gruppenwerte",db,"recordgrp",function() A.UpdateEvents() end)
    Toggle("Leichtmodus – keine Kampfberichte",db,"lightmode",function() A.UpdateEvents() end)
    Toggle("Leichtmodus in PvP",db,"lightmodeincyrodil",function() A.UpdateEvents() end)
    C.AddMenuItem("Zurück zum Kampfbericht",C.CloseMenu)
    C.SetHUDPreview(true)
    C.ShowMenu()
end

function C.Initialize()
    ZO_Dialogs_RegisterCustomDialog("CMX2_OUTPUT",{
        gamepadInfo={dialogType=GAMEPAD_DIALOGS.BASIC,allowShowOnNextScene=true},
        title={text="Combat Metrics 2 – Zusammenfassung"},
        mainText={text=function(dialog) return dialog.data.text end},
        buttons={{keybind="DIALOG_PRIMARY",text=SI_DIALOG_CONFIRM}},
        finishedCallback=function() C.RestoreFocus() end,
    })
    local context=ZO_Scene:New("CMX2_CONTEXT_SCENE",SCENE_MANAGER)
    context:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    context:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    context:AddFragment(ZO_FadeSceneFragment:New(CombatMetrics2_ContextWindow))
    C.screen=Screen:New(CombatMetrics2_ContextWindow,context)
    C.previewFrame=CombatMetrics2_HUDPreview
    context:RegisterCallback("StateChange",function(_,state)
        if state==SCENE_HIDING and C.hudPreview then C.SetHUDPreview(false) end
    end)
    C.outline=CombatMetrics2_ControllerFocus
    C.hint=CombatMetrics2_ControllerHint
    C.hintText=CombatMetrics2_ControllerHintText
    C.outline:SetHidden(true)
    local keys
    keys={alignment=KEYBIND_STRIP_ALIGN_LEFT,
        {name="Auswählen",keybind="UI_SHORTCUT_PRIMARY",callback=function() C.Activate(false) end},
        {name="Kontext",keybind="UI_SHORTCUT_SECONDARY",callback=function() C.Activate(true) end},
        {name="Details scrollen",keybind="UI_SHORTCUT_RIGHT_STICK",callback=function()
            if C.ToggleDetailsScroll then C.ToggleDetailsScroll() end
        end,visible=function() return C.detailVisible==true end},
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
            zo_callLater(C.FlushOutput,0)
            KEYBIND_STRIP:AddKeybindButtonGroup(keys)
            DIRECTIONAL_INPUT:Activate(C,CombatMetrics2_Report)
            C.RestoreFocus()
        elseif state==SCENE_HIDING then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(keys)
            C.focusGeneration=(C.focusGeneration or 0)+1
            DIRECTIONAL_INPUT:Deactivate(C);C.outline:SetHidden(true);C.TooltipExit()
        end
    end)
    -- Warm-up adds and lays out the report fragment before its first opening.
    -- Also follow the actual window visibility, not just the scene callback.
    CombatMetrics2_Report:SetHandler("OnEffectivelyShown",function() C.RestoreFocus() end,"CMX2ControllerFocus")
    CombatMetrics2_Report:SetHandler("OnEffectivelyHidden",function()
        C.outline:SetHidden(true);C.TooltipExit()
    end,"CMX2ControllerFocus")
    CombatMetrics2_Report:SetHandler("OnUpdate",function()
        if not C.IsReportOpen() then return end
        if ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog() then
            C.outline:SetHidden(true);return
        end
        local now=GetFrameTimeMilliseconds()
        if now<(C.nextOutlineUpdate or 0) then return end
        C.nextOutlineUpdate=now+200
        if not C.RefreshOutline() then C.RestoreFocus() end
    end,"CMX2ControllerFocus")
    -- Optional details must not prevent the main controller from being wired.
    if C.InitializeDetails then C.InitializeDetails() end
    if LibRadialMenu then
        LibRadialMenu:RegisterAddon("CombatMetrics2","Combat Metrics 2")
        LibRadialMenu:RegisterEntry("CombatMetrics2","Kampfbericht öffnen","report",
            "/esoui/art/menubar/gamepad/gp_playermenu_icon_character.dds",function() CombatMetrics2_Report:Toggle() end)
    end
end

function A.MakeMenu(defaults) C.defaults=defaults end
A.OpenSettings=C.Settings
