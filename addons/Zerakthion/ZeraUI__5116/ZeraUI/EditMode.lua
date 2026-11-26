-- Mouse-only interactive HUD layout and appearance editor.
-- All edit controls are created lazily on first BeginEdit() and hidden on exit
-- so normal gameplay pays zero CPU or mouse-hit cost.
function ZeraUIAttachEditor(A,UI)
    local WM=WINDOW_MANAGER
    local function tr(text) return A.settings and A.settings.menuLanguage=="tr" and ZeraUITranslate(text) or text end
    local keys={"x","y","gridX","gridY","quickX","quickY","ultX","ultY","castX","castY","synergyX","synergyY","attrX","attrY","attrHealthX","attrHealthY","attrMagickaX","attrMagickaY","attrStaminaX","attrStaminaY","passiveX","passiveY"}
    for _,prefix in ipairs({"setCooldown","offBalance","effectSelf","effectTarget","effectSelfDebuff","effectTargetDebuff","playerInteraction","instanceKick","reticleInteract","tutorialTip","interactWindow","curved"}) do
        keys[#keys+1]=prefix.."X"; keys[#keys+1]=prefix.."Y"
    end
    keys[#keys+1]="curvedGap"
    local parts={
        {name="Action bar",x="gridX",y="gridY",grid=true},
        {name="Ultimate",x="ultX",y="ultY"},
        {name="Potion",x="quickX",y="quickY"},
        {name="Cast bar",x="castX",y="castY"},
        {name="Synergy",x="synergyX",y="synergyY"},
        {name="Class ultimate-generation cooldowns",x="passiveX",y="passiveY"},
        {name="Attributes",x="attrX",y="attrY"},
        {name="Health",x="attrHealthX",y="attrHealthY",independent=true,attributeIndividual=true},
        {name="Magicka",x="attrMagickaX",y="attrMagickaY",independent=true,attributeIndividual=true},
        {name="Stamina",x="attrStaminaX",y="attrStaminaY",independent=true,attributeIndividual=true},
    }
    local resizeKeys={scale=true,skillSize=true,gapX=true,gapY=true,ultScale=true,quickScale=true,
        castScale=true,synergyScale=true,attrScale=true,attrWidth=true,attrGap=true}
    local cornerResizeSpecs={
        ["Action bar"]={key="skillSize",min=32,max=96,step=1,scope="hud",mode="hudSize",sens=.45},
        ["Ultimate"]={key="ultScale",min=.5,max=1.8,step=.05,scope="hud",mode="hudSize",sens=.005},
        ["Potion"]={key="quickScale",min=.5,max=1.8,step=.05,scope="hud",mode="hudSize",sens=.005},
        ["Cast bar"]={key="castScale",min=.5,max=1.8,step=.05,scope="hud",mode="hudSize",sens=.005},
        ["Synergy"]={key="synergyScale",min=.5,max=1.8,step=.05,scope="hud",mode="hudSize",sens=.005},
        ["Attributes"]={key="attrScale",min=.5,max=1.8,step=.05,scope="attributes",mode="hudSize",sens=.005},
        ["curved"]={key="curvedScale",min=.6,max=1.8,step=.05,scope="attributes",mode="direct",sens=.005},
        ["setCooldown"]={key="setCooldownIconSize",min=24,max=128,step=1,scope="sets",mode="direct",sens=.5},
        ["effectSelf"]={key="effectSelfSize",min=20,max=100,step=1,scope="effects",mode="effectSize",sens=.5},
        ["effectSelfDebuff"]={key="effectSelfDebuffSize",min=20,max=100,step=1,scope="effects",mode="effectSize",sens=.5},
        ["effectTarget"]={key="effectTargetSize",min=20,max=100,step=1,scope="effects",mode="effectSize",sens=.5},
        ["effectTargetDebuff"]={key="effectTargetDebuffSize",min=20,max=100,step=1,scope="effects",mode="effectSize",sens=.5},
        ["offBalance"]={key="offBalanceSize",min=20,max=100,step=1,scope="effects",mode="effectSize",sens=.5},
    }
    local CENTER_SNAP_THRESHOLD=4

    -- Same two-row reference used by Edit Mode, even when a special hotbar
    -- is active. All coordinates are in the root's unscaled local space.
    -- raw=true: saved Q/R offsets, without the arrow clearance. Resize
    -- correction works on saved values; frames use what is drawn.
    function A:HudEditGeometry(raw)
        local s=self.settings
        local width=5*s.skillSize+4*s.gapX
        local height=2*s.skillSize+s.gapY
        local left=111+(328-width)/2+s.gridX
        local top=36+s.gridY
        local px,py,pw,ph=self:PassiveTimerLayout(s,left,top,width)
        local clear=raw and {quickX=s.quickX,ultX=s.ultX} or self:ArrowLayout(s,left,top,width) -- frames follow the drawn Q/R
        local geometry={
            ["Action bar"]={left,top,width,height+20},
            ["Ultimate"]={left+width+17+clear.ultX,top+(height-82)/2+s.ultY,150*s.ultScale,111*s.ultScale},
            ["Potion"]={left-95+clear.quickX,top+(height-80)/2+s.quickY,80*s.quickScale,100*s.quickScale},
            ["Cast bar"]={left+width/2-164*s.castScale+s.castX,top-55+s.castY,328*s.castScale,31*s.castScale},
            ["Synergy"]={left+width/2-100*s.synergyScale+s.synergyX,top+2*s.skillSize+s.gapY+12+s.synergyY,200*s.synergyScale,88*s.synergyScale},
            ["Class ultimate-generation cooldowns"]={px,py,pw,ph},
        }
        for name,g in pairs(self:AttributeGeometry()) do geometry[name]=g end
        return geometry
    end
    local function screenCenter(s,g)
        -- Root BOTTOM anchor: X is its compensated center, Y is its bottom.
        return s.x+(g[1]+g[3]/2-275)*s.scale,s.y+(g[2]+g[4]/2-245)*s.scale
    end
    function A:SetHudSize(key,value)
        local s=self.settings
        if s[key]==value then return end
        if not resizeKeys[key] then s[key]=value; return end
        local before=self:HudEditGeometry(true)
        local centers={}
        for _,part in ipairs(parts) do
            if not part.attributeIndividual or s.attrSplit then
                local x,y=screenCenter(s,before[part.name]); centers[part.name]={x,y}
            end
        end
        s[key]=value
        local function correct(part,geometry)
            local old=centers[part.name]
            if old then
                local x,y=screenCenter(s,geometry[part.name])
                s[part.x]=s[part.x]+(old[1]-x)/s.scale
                s[part.y]=s[part.y]+(old[2]-y)/s.scale
            end
        end
        -- Grid first (other offsets are relative to it), grouped resources
        -- before individual ones. Fractional offsets avoid round-trip drift.
        correct(parts[1],self:HudEditGeometry(true))
        local geometry=self:HudEditGeometry(true)
        for i=2,#parts do if not parts[i].attributeIndividual then correct(parts[i],geometry) end end
        if s.attrSplit then
            geometry=self:HudEditGeometry(true)
            for _,part in ipairs(parts) do if part.attributeIndividual then correct(part,geometry) end end
        end
    end
    local function snapshot(s)
        local t={}; for _,key in ipairs(keys) do t[key]=s[key] end; return t
    end
    local function restore(s,t)
        for _,key in ipairs(keys) do s[key]=t[key] end
    end
    local function snap(value,step)
        if not step or step<=0 then return value end
        return math.floor(value/step+.5)*step
    end
    local function roundStep(value,step,minVal,maxVal)
        value=math.max(minVal,math.min(maxVal,value))
        local snapped=math.floor(value/step+.5)*step
        if step<1 then snapped=math.floor(snapped*100+.5)/100 end
        return math.max(minVal,math.min(maxVal,snapped))
    end
    -- Drag the whole widget using cursor-space coordinates, not action-bar
    -- scale. No mouse polling in normal play: RenderWidgetDrag runs only
    -- from an actual mouse-down until release/scene exit/lock.
    A.widgetWindows={}
    A.widgetOrder={}
    local widgetTitles={
        effectSelf="Self Buffs",effectSelfDebuff="Self Debuffs",
        effectTarget="Target Buffs",effectTargetDebuff="Target Debuffs",
        setCooldown="Set Cooldowns",offBalance="Off Balance",playerInteraction="Player Interaction",
        instanceKick="Leave Now warning",reticleInteract="Interact prompt [E]",tutorialTip="Tutorial tip",interactWindow="NPC Dialogue",curved="Resource arcs",
    }
    function A:EditWidgetTitle(key)
        return widgetTitles[key] or key
    end
    function A:GetEditSelectionKey(sel)
        sel=sel or self.editSelected
        if not sel then return nil end
        if sel.kind=="widget" then return sel.widget and sel.widget.prefix end
        return sel.part and sel.part.name
    end
    -- Dynamic inventory of all currently active/editable HUD elements, derived
    -- strictly from the real `parts` handles and `widgetWindows` registry.
    function A:GetEditableElements()
        local list={}
        for _,part in ipairs(parts) do
            local h=self.editHandles and self.editHandles[part.name]
            if h and h.control and not h.control:IsHidden() then
                list[#list+1]={key=part.name,title=tr(self:EditWidgetTitle(part.name)),sel={kind="part",part=part}}
            end
        end
        local seen={}
        for _,prefix in ipairs(self.widgetOrder or {}) do
            local w=self.widgetWindows[prefix]
            if w and w.window and not w.window:IsHidden() then
                seen[prefix]=true
                list[#list+1]={key=prefix,title=tr(self:EditWidgetTitle(prefix)),sel={kind="widget",widget=w}}
            end
        end
        for prefix,w in pairs(self.widgetWindows or {}) do
            if not seen[prefix] and w and w.window and not w.window:IsHidden() then
                list[#list+1]={key=prefix,title=tr(self:EditWidgetTitle(prefix)),sel={kind="widget",widget=w}}
            end
        end
        return list
    end
    -- Read the rendered control center, not its differently anchored saved
    -- offsets. Both coordinates use the same GuiRoot coordinate space.
    local function centerOffset(control)
        if not control or not control.GetCenter or not GuiRoot.GetCenter then return end
        local x,y=control:GetCenter()
        local cx,cy=GuiRoot:GetCenter()
        if type(x)=="number" and type(y)=="number" and type(cx)=="number" and type(cy)=="number" then
            local g=A:GlobalUIScale()
            return math.floor((x-cx)*g+.5),math.floor((y-cy)*g+.5)
        end
    end
    local function buildCenterGuides(self)
        local guide=WM:CreateTopLevelWindow("ZeraUICenterGuides")
        guide:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,0,0)
        guide:SetAnchor(BOTTOMRIGHT,GuiRoot,BOTTOMRIGHT,0,0)
        guide:SetMouseEnabled(false); guide:SetDrawTier(DT_MEDIUM or DT_HIGH)
        local function line(vertical)
            local c=WM:CreateControl(nil,guide,CT_BACKDROP)
            c:SetMouseEnabled(false); c:SetEdgeColor(0,0,0,0)
            c:SetCenterColor(.3,.83,1,.58)
            if vertical then
                c:SetWidth(1); c:SetAnchor(TOP,guide,TOP,0,0); c:SetAnchor(BOTTOM,guide,BOTTOM,0,0)
            else
                c:SetHeight(1); c:SetAnchor(LEFT,guide,LEFT,0,0); c:SetAnchor(RIGHT,guide,RIGHT,0,0)
            end
            return c
        end
        self.editCenterV=line(true)
        self.editCenterH=line(false)
        local origin=UI.text(guide,13,80,22,0,0,5)
        origin:ClearAnchors(); origin:SetAnchor(TOPLEFT,guide,CENTER,5,5)
        origin:SetText("0, 0"); origin:SetColor(.5,.9,1,1); origin:SetMouseEnabled(false)
        guide:SetHidden(true); self.editCenterGuides=guide
    end
    local function highlightCenterGuides(snapX,snapY)
        if A.editCenterV then
            if snapX then A.editCenterV:SetCenterColor(1,.84,.35,.92) else A.editCenterV:SetCenterColor(.3,.83,1,.58) end
        end
        if A.editCenterH then
            if snapY then A.editCenterH:SetCenterColor(1,.84,.35,.92) else A.editCenterH:SetCenterColor(.3,.83,1,.58) end
        end
    end
    -- Pooled CT_LINE grid lattice using native ZO_ObjectPool. Created lazily
    -- only when Grid is toggled ON inside Edit Mode; hidden on exit.
    local function ensureGridOverlay(self)
        if self.editGridOverlay then return self.editGridOverlay end
        local root=WM:CreateTopLevelWindow("ZeraUIEditGridOverlay")
        root:SetAnchorFill(GuiRoot)
        root:SetDrawLayer(DL_BACKGROUND); root:SetDrawTier(DT_LOW); root:SetDrawLevel(0)
        root:SetMouseEnabled(false); root:SetMovable(false); root:SetHidden(true)
        local function makeLine()
            local line=WM:CreateControl(nil,root,CT_LINE)
            line:SetDrawLayer(DL_BACKGROUND); line:SetDrawTier(DT_LOW); line:SetDrawLevel(1)
            line:SetColor(.30,.83,1,.18)
            if line.SetThickness then line:SetThickness("1px") end
            if line.SetPixelRoundingEnabled then line:SetPixelRoundingEnabled(true) end
            line:SetMouseEnabled(false)
            return line
        end
        local function resetLine(line)
            line:ClearAnchors(); line:SetHidden(true)
        end
        local vPool,hPool
        if ZO_ObjectPool then
            vPool=ZO_ObjectPool:New(makeLine,resetLine)
            hPool=ZO_ObjectPool:New(makeLine,resetLine)
            vPool:SetCustomAcquireBehavior(function(line) line:SetHidden(false) end)
            hPool:SetCustomAcquireBehavior(function(line) line:SetHidden(false) end)
        else
            local function simplePool()
                local active,free={},{}
                return {
                    AcquireObject=function(_,k)
                        local obj=active[k] or free[k] or makeLine()
                        free[k]=nil; active[k]=obj; obj:SetHidden(false); return obj
                    end,
                    ReleaseObject=function(_,k)
                        local obj=active[k]; if obj then active[k]=nil; free[k]=obj; resetLine(obj) end
                    end,
                    GetActiveObjects=function() return active end,
                }
            end
            vPool,hPool=simplePool(),simplePool()
        end
        self.editGridOverlay={root=root,vPool=vPool,hPool=hPool}
        return self.editGridOverlay
    end
    local function releaseAbove(pool,maxKey)
        local active=pool:GetActiveObjects()
        local toRelease={}
        for k in pairs(active) do if k>maxKey then toRelease[#toRelease+1]=k end end
        for _,k in ipairs(toRelease) do pool:ReleaseObject(k) end
    end
    function A:RefreshEditGrid()
        local show=not not (self.editing and self.settings.editShowGrid)
        if not show then
            if self.editGridOverlay then self.editGridOverlay.root:SetHidden(true) end
            return
        end
        local grid=ensureGridOverlay(self)
        grid.root:SetHidden(false)
        local rawStep=math.floor(tonumber(self.settings.editSnap) or 0)
        -- Avoid creating thousands of lines if snap is 0..7; show a crisp 16-unit visual lattice.
        local step=rawStep>=8 and rawStep or 16
        local w,h=GuiRoot:GetDimensions()
        w,h=math.floor(w or 0),math.floor(h or 0)
        if grid.lastStep==step and grid.lastW==w and grid.lastH==h then return end
        grid.lastStep,grid.lastW,grid.lastH=step,w,h
        local zero="0ui"
        local vCount=math.floor(w/step)
        for i=0,vCount do
            local xStr=string.format("%dui",i*step)
            local line=grid.vPool:AcquireObject(i)
            line:ClearAnchors()
            line:SetAnchor(TOPLEFT,grid.root,TOPLEFT,xStr,zero)
            line:SetAnchor(BOTTOMLEFT,grid.root,BOTTOMLEFT,xStr,zero)
        end
        releaseAbove(grid.vPool,vCount)
        local hCount=math.floor(h/step)
        for i=0,hCount do
            local yStr=string.format("%dui",i*step)
            local line=grid.hPool:AcquireObject(i)
            line:ClearAnchors()
            line:SetAnchor(TOPLEFT,grid.root,TOPLEFT,zero,yStr)
            line:SetAnchor(TOPRIGHT,grid.root,TOPRIGHT,zero,yStr)
        end
        releaseAbove(grid.hPool,hCount)
    end
    local function updateWidgetTitle(w)
        local name=widgetTitles[w.prefix]
        local visible=not not (A.editing and A.settings.enabled and name)
        if visible and not w.title then
            -- Lazy, reusable edit-only controls. They do not intercept clicks
            -- or require an update handler during normal gameplay.
            local title=UI.panel(w.window,174,22,0,0)
            title:SetMouseEnabled(false); title:SetDrawLevel(40)
            local bg=UI.texture(title,UI.path.."square.dds",174,22,0,0,41)
            bg:SetColor(0,0,0,.85); bg:SetMouseEnabled(false)
            local label=UI.text(title,16,174,22,0,0,42)
            label:SetText(tr(name)); label:SetMouseEnabled(false)
            w.title,w.titleText=title,label
        end
        if w.title then
            if w.titleVisible~=visible then
                w.titleVisible=visible; w.title:SetHidden(not visible)
            end
            if visible then
                -- Flip title below only when the widget is genuinely within ~26 px of the top edge.
                local top=w.window.GetTop and w.window:GetTop()
                if type(top)~="number" and w.window.GetScreenRect then top=select(2,w.window:GetScreenRect()) end
                local rootTop=GuiRoot and GuiRoot.GetTop and GuiRoot:GetTop() or 0
                local scale=w.window.GetScale and w.window:GetScale() or 1
                if type(scale)~="number" or scale<=0 then scale=1 end
                local below=type(top)=="number" and (top-rootTop)<26*scale
                if w.titleBelow~=below then
                    w.titleBelow=below; w.title:ClearAnchors()
                    if below then w.title:SetAnchor(TOP,w.window,BOTTOM,0,4)
                    else w.title:SetAnchor(BOTTOM,w.window,TOP,0,-4) end
                end
            end
        end
    end
    -- Selection: one module at a time, shown with a gold frame. Its center
    -- offset from the middle of the screen can be typed in the toolbar.
    local function selectionTarget(sel)
        if not sel then return end
        if sel.kind=="widget" then return sel.widget.window,widgetTitles[sel.widget.prefix] or sel.widget.prefix end
        local h=A.editHandles and A.editHandles[sel.part.name]
        return h and h.control,sel.part.name
    end
    local function wholeHud(sel)
        return sel and sel.kind=="part" and A.settings.moveTogether and not sel.part.independent
    end
    local function isDraggingAny()
        return A.drag~=nil or A.widgetDrag~=nil or A.resizeDrag~=nil
    end
    function A:PositionNudgeBar()
        local bar=self.editNudgeBar
        if not bar then return end
        local sel=self.editSelected
        local target=selectionTarget(sel)
        if not self.editing or not target or target:IsHidden() or isDraggingAny() then
            bar:SetHidden(true); return
        end
        local l,t,r,b=target:GetScreenRect()
        if type(l)~="number" or type(t)~="number" or type(r)~="number" or type(b)~="number" then
            bar:SetHidden(true); return
        end
        local bw,bh=bar:GetWidth(),bar:GetHeight()
        if bw<1 then bw=302 end
        if bh<1 then bh=34 end
        local sw,sh=GuiRoot:GetWidth(),GuiRoot:GetHeight()
        local gap=8
        local placeAbove=(sh-b)<(bh+gap+4) and t>(sh-b)
        local cx=(l+r)/2
        local x=math.max(4,math.min(sw-bw-4,cx-bw/2))
        local y=placeAbove and math.max(4,t-bh-gap) or math.min(sh-bh-4,b+gap)
        bar:ClearAnchors()
        bar:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,math.floor(x+.5),math.floor(y+.5))
        bar:SetHidden(false)
    end
    function A:RefreshEditReadout(force)
        if not self.editing or not self.editStatus then return end
        local sel=self.editSelected
        local target,name=selectionTarget(sel)
        if not target or target:IsHidden() then
            if sel then self:SelectEdit(nil) end
            return
        end
        local x,y=centerOffset(target)
        if not x then return end
        -- While either box is being typed in, keep both: Tab from X to Y
        -- must not lose the X just typed.
        local typing=false
        for _,box in ipairs({self.editX,self.editY}) do
            if box and box.HasFocus and box:HasFocus() then typing=true end
        end
        for _,pair in ipairs({{self.editX,x},{self.editY,y}}) do
            local box,value=pair[1],pair[2]
            if box and (force or not typing) then
                local text=tostring(value)
                if box:GetText()~=text then box:SetText(text) end
            end
        end
        local label=string.format(tr("Selected: %s"),tr(name))..(wholeHud(sel) and "  ("..tr("whole HUD moves").. ")" or "")
        if label~=self.editCoordinateText then self.editCoordinateText=label; self.editStatus:SetText(label) end
        self:PositionNudgeBar()
    end
    function A:SetEditColorPickerActive(active)
        active=not not active
        if active then
            if not self.editing or self.editColorPickerActive then return end
            self.editColorPickerActive=true
            self.drag=nil; self.widgetDrag=nil; self.resizeDrag=nil
            highlightCenterGuides(false,false)
            if self.editToolbar then self.editToolbar:SetHidden(true) end
            if self.editNudgeBar then self.editNudgeBar:SetHidden(true) end
            if self.editSelectionFrame then self.editSelectionFrame:SetHidden(true) end
            if self.editResizeHandle then self.editResizeHandle:SetHidden(true) end
            for _,h in pairs(self.editHandles or {}) do h.control:SetHidden(true) end
            if self.SetEditInspectorColorPickerActive then self:SetEditInspectorColorPickerActive(true) end
            self:SyncWidgetDrag()
            return
        end
        if not self.editColorPickerActive then return end
        self.editColorPickerActive=false
        if self.SetEditInspectorColorPickerActive then self:SetEditInspectorColorPickerActive(false) end
        if not self.editing then self:SyncWidgetDrag(); return end
        if self.editToolbar then self.editToolbar:SetHidden(false) end
        self:UpdateEditHandles()
        local target=selectionTarget(self.editSelected)
        local key=self:GetEditSelectionKey(self.editSelected)
        if self.editSelectionFrame then self.editSelectionFrame:SetHidden(not target) end
        if self.editResizeHandle then self.editResizeHandle:SetHidden(not (target~=nil and key~=nil and cornerResizeSpecs[key]~=nil)) end
        self:PositionNudgeBar()
        self:SyncWidgetDrag()
    end
    function A:SelectEdit(sel)
        if ClearMenu then ClearMenu() end
        if self.editColorPickerActive then
            if COLOR_PICKER and COLOR_PICKER.IsShown and COLOR_PICKER:IsShown() and COLOR_PICKER.Cancel then COLOR_PICKER:Cancel() end
            if COLOR_PICKER_GAMEPAD and COLOR_PICKER_GAMEPAD.IsShown and COLOR_PICKER_GAMEPAD:IsShown() and COLOR_PICKER_GAMEPAD.Cancel then COLOR_PICKER_GAMEPAD:Cancel() end
            self:SetEditColorPickerActive(false)
        end
        self.editSelected=sel
        self.editCoordinateText=nil
        local target=selectionTarget(sel)
        local key=self:GetEditSelectionKey(sel)
        local frame=self.editSelectionFrame
        if frame then
            frame:ClearAnchors()
            if target then
                frame:SetAnchor(TOPLEFT,target,TOPLEFT,-4,-4)
                frame:SetAnchor(BOTTOMRIGHT,target,BOTTOMRIGHT,4,4)
            end
            frame:SetHidden(not target)
        end
        if self.editResizeHandle then
            local canResize=target~=nil and key~=nil and cornerResizeSpecs[key]~=nil
            self.editResizeHandle:SetHidden(not canResize)
        end
        for name,h in pairs(self.editHandles or {}) do
            local on=sel and sel.kind=="part" and sel.part.name==name
            h.border:SetColor(1,on and .78 or 1,on and .3 or 1,on and 1 or .55)
            h.label:SetColor(1,on and .84 or 1,on and .45 or 1,1)
        end
        for _,box in ipairs({self.editX,self.editY}) do
            if box and not target then box:SetText("") end
        end
        if not target and self.editStatus then
            self.editStatus:SetText(string.format(tr("Select an element  •  Snap %d px"),self.settings.editSnap or 0))
        end
        if self.editStatusStrip then
            local st=self.studioStyle
            local c=target and (st and st.yellow or {.953,.800,.310,1}) or (st and st.card or {.941,.914,.855,1})
            self.editStatusStrip:SetCenterColor(c[1],c[2],c[3],c[4] or 1)
        end
        self:PositionNudgeBar()
        self:RefreshEditReadout(true)
        if self.RefreshEditElementList then self:RefreshEditElementList(true) end
        if self.RefreshEditInspector then self:RefreshEditInspector() end
    end
    local function clampWidget(p,x,y)
        if p=="setCooldown" or p=="playerInteraction" or p=="instanceKick" or p=="reticleInteract" or p=="tutorialTip" or p=="interactWindow" then return math.max(-2500,math.min(2500,x)),math.max(-1500,math.min(1500,y)) end
        return math.max(-4000,math.min(4000,x)),math.max(-3000,math.min(3000,y))
    end
    -- Align Q/R saved offset with ArrowLayout's drawn position ONLY when the
    -- user actually drags, nudges, or edits Q/R, so opening Edit Mode and
    -- saving unrelated changes never persists pushed-out quickX/ultX offsets.
    local function alignArrowPartOffset(self,part)
        if not part or (part.x~="quickX" and part.x~="ultX") then return end
        local s=self.settings
        local width=5*s.skillSize+4*s.gapX
        local clear=self:ArrowLayout(s,111+(328-width)/2+s.gridX,36+s.gridY,width)
        if part.x=="quickX" then s.quickX=clear.quickX
        elseif part.x=="ultX" then s.ultX=clear.ultX end
    end
    local function moveSelection(sel,dx,dy)
        local s=A.settings
        if sel.kind=="widget" then
            local w=sel.widget; local p=w.prefix
            if not A:WidgetDragAllowed(p) then return end
            s[p.."X"],s[p.."Y"]=clampWidget(p,s[p.."X"]+dx,s[p.."Y"]+dy)
            w.position(); updateWidgetTitle(w)
            return
        end
        local part=sel.part
        if wholeHud(sel) then s.x=s.x+dx; s.y=s.y+dy
        else
            alignArrowPartOffset(A,part)
            dx,dy=dx/s.scale,dy/s.scale
            s[part.x]=s[part.x]+dx; s[part.y]=s[part.y]+dy
            if part.grid then
                for _,p in ipairs(parts) do if not p.grid and not p.attributeIndividual then
                    s[p.x]=s[p.x]-dx; s[p.y]=s[p.y]-dy
                end end
            end
        end
        A:PositionElements(); A:UpdateEditHandles()
    end
    function A:NudgeEditSelection(dx,dy)
        local sel=self.editSelected
        if not sel then return end
        local mult=(IsShiftKeyDown and IsShiftKeyDown()) and math.max(5,self.settings.editSnap or 5) or 1
        moveSelection(sel,dx*mult,dy*mult)
        self.editReadoutAt=0
        self:RefreshEditReadout(true)
    end
    function A:CenterEditSelection(axis)
        local sel=self.editSelected
        local target=selectionTarget(sel)
        if not target then return end
        local cx,cy=centerOffset(target)
        if not cx then return end
        local dx=axis~="y" and -cx or 0
        local dy=axis~="x" and -cy or 0
        if dx~=0 or dy~=0 then moveSelection(sel,dx,dy) end
        self.editReadoutAt=0
        self:RefreshEditReadout(true)
    end
    function A:SnapEditSelectionToGrid()
        local sel=self.editSelected
        local target=selectionTarget(sel)
        local step=tonumber(self.settings.editSnap) or 0
        if not target or step<=0 then return end
        local cx,cy=centerOffset(target)
        if not cx then return end
        local tx,ty=snap(cx,step),snap(cy,step)
        if tx~=cx or ty~=cy then moveSelection(sel,tx-cx,ty-cy) end
        self.editReadoutAt=0
        self:RefreshEditReadout(true)
    end
    function A:ApplyEditCoordinates()
        local sel=self.editSelected
        local target=selectionTarget(sel)
        if not target then return end
        local tx,ty=tonumber(self.editX:GetText()),tonumber(self.editY:GetText())
        local cx,cy=centerOffset(target)
        -- "1e309" reads as infinity: only finite numbers, kept on the screen.
        local function finite(v) return v and v==v and v>-math.huge and v<math.huge end
        if not finite(tx) or not finite(ty) or not cx then self:RefreshEditReadout(true); return end
        local w=GuiRoot.GetWidth and tonumber(GuiRoot:GetWidth()) or 0
        local h=GuiRoot.GetHeight and tonumber(GuiRoot:GetHeight()) or 0
        local g=self:GlobalUIScale()
        local halfW=(w>0 and w or 3840)*g/2; local halfH=(h>0 and h or 2160)*g/2
        tx=math.floor(math.max(-halfW,math.min(halfW,tx))+.5)
        ty=math.floor(math.max(-halfH,math.min(halfH,ty))+.5)
        if tx~=cx or ty~=cy then moveSelection(sel,tx-cx,ty-cy) end
        -- Anchors settle on the next frame; the readout refreshes then.
        self.editReadoutAt=0
    end
    function A:ResetEditSelection()
        local sel=self.editSelected
        if not sel then return end
        local s=self.settings
        if sel.kind=="widget" then
            local p=sel.widget.prefix
            s[p.."X"],s[p.."Y"]=self:DefaultSetting(p.."X"),self:DefaultSetting(p.."Y")
            if p=="curved" then s.curvedGap=self:DefaultSetting("curvedGap") end
            sel.widget.position(); updateWidgetTitle(sel.widget)
        elseif wholeHud(sel) then s.x,s.y=0,-70
        else
            local part=sel.part
            if part.grid then
                local x,y=self:DefaultSetting("gridX"),self:DefaultSetting("gridY")
                local dx,dy=x-s.gridX,y-s.gridY
                s.gridX,s.gridY=x,y
                for _,p in ipairs(parts) do if not p.grid and not p.attributeIndividual then s[p.x]=s[p.x]-dx; s[p.y]=s[p.y]-dy end end
            elseif part.name=="Attributes" then
                if self.ResetAttributePositions then self:ResetAttributePositions()
                else
                    s.attrX,s.attrY=self:DefaultSetting("attrX"),self:DefaultSetting("attrY")
                    if s.attrLayout=="Stacked" then s.attrX,s.attrY=-245,-30 end
                end
            else s[part.x],s[part.y]=self:DefaultSetting(part.x),self:DefaultSetting(part.y) end
        end
        self:PositionElements(); self:UpdateEditHandles()
        self.editReadoutAt=0
        if self.RefreshEditInspector then self:RefreshEditInspector() end
    end
    -- Native ESO right-click context menu for any Edit Mode widget.
    function A:ShowEditContextMenu(sel,anchorControl)
        if not self.editing or not sel or not ClearMenu or not AddMenuItem or not ShowMenu then return end
        self:SelectEdit(sel)
        local key=self:GetEditSelectionKey(sel)
        local title=tr(self:EditWidgetTitle(key))
        ClearMenu()
        if self.ToggleEditInspector then
            AddMenuItem(tr("Customize").." ("..title..")",function() self:ToggleEditInspector(true) end)
        end
        AddMenuItem(tr("Center horizontally (X = 0)"),function() self:CenterEditSelection("x") end)
        AddMenuItem(tr("Center vertically (Y = 0)"),function() self:CenterEditSelection("y") end)
        if (tonumber(self.settings.editSnap) or 0)>0 then
            AddMenuItem(tr("Snap to grid"),function() self:SnapEditSelectionToGrid() end)
        end
        if key=="Attributes" or key=="Health" or key=="Magicka" or key=="Stamina" or key=="curved" then
            if self.SetAttributeMode then
                for _,pair in ipairs({{"Off","Off"},{"Default","Default Attribute Bar"},{"Custom","Custom Attribute Bar"}}) do
                    local modeVal,modeLbl=pair[1],pair[2]
                    local mark=self.settings.attrMode==modeVal and "• " or "  "
                    AddMenuItem(mark..tr("Attribute bars")..": "..tr(modeLbl),function()
                        self:SetAttributeMode(modeVal)
                        if modeVal=="Off" then
                            self:SelectEdit(nil)
                            self:UpdateEditHandles()
                        else
                            self:SelectAttributeEditTarget()
                        end
                    end)
                end
            end
            if self.AttributeLayoutChoices and self.SetAttributeLayout then
                for _,layout in ipairs(self:AttributeLayoutChoices()) do
                    local choice=layout
                    local mark=self.settings.attrLayout==choice and "• " or "  "
                    AddMenuItem(mark..tr("Layout")..": "..tr(choice),function()
                        self:SetAttributeLayout(choice)
                        self:SelectAttributeEditTarget()
                    end)
                end
            end
            if self.settings.attrLayout~="Curved" then
                AddMenuItem(tr(self.settings.attrSplit and "Group attribute bars" or "Move attributes individually"),function()
                    self.settings.attrSplit=not self.settings.attrSplit
                    self:ApplyScopedVisual("attributes")
                    self:SelectAttributeEditTarget()
                end)
            end
        elseif key=="setCooldown" then
            local nextDir=self.settings.setCooldownDirection=="Vertical" and "Horizontal" or "Vertical"
            AddMenuItem(tr("Switch layout")..": "..tr(nextDir),function()
                self.settings.setCooldownDirection=nextDir
                self:ApplyScopedVisual("sets")
                if self.RefreshEditInspector then self:RefreshEditInspector() end
            end)
        elseif key=="effectSelf" or key=="effectSelfDebuff" or key=="effectTarget" or key=="effectTargetDebuff" then
            local p=key
            AddMenuItem(tr(self.settings[p.."SingleRow"] and "Disable single row" or "Enable single row"),function()
                self.settings[p.."SingleRow"]=not self.settings[p.."SingleRow"]
                self:ApplyScopedVisual("effects")
                if self.RefreshEditInspector then self:RefreshEditInspector() end
            end)
        end
        AddMenuItem(tr("Reset position"),function() self:ResetEditSelection() end)
        if self.ResetWidgetAppearance and self.HasWidgetAppearance and self:HasWidgetAppearance(key) then
            AddMenuItem(tr("Reset appearance"),function() self:ResetWidgetAppearance(key) end)
            AddMenuItem(tr("Reset position & appearance"),function()
                self:ResetEditSelection()
                self:ResetWidgetAppearance(key)
            end)
        end
        ShowMenu(anchorControl)
    end
    function A:SelectAttributeEditTarget()
        if not self.editing then return end
        self:UpdateEditHandles()
        local s=self.settings
        if s.attrLayout=="Curved" then
            local w=self.widgetWindows and self.widgetWindows.curved
            if w then self:SelectEdit({kind="widget",widget=w}); return end
        else
            local targetName=s.attrSplit and "Health" or "Attributes"
            for _,p in ipairs(parts) do
                if p.name==targetName then self:SelectEdit({kind="part",part=p}); return end
            end
        end
        if self.RefreshEditInspector then self:RefreshEditInspector() end
    end
    function A:WidgetDragAllowed(prefix)
        if self.gamepadSuspended or self.editColorPickerActive then return false end
        if prefix=="playerInteraction" or prefix=="instanceKick" or prefix=="reticleInteract" or prefix=="tutorialTip" or prefix=="interactWindow" then
            if not self.editing then return false end
            if self.PlayerInteractionDragAllowed and not self:PlayerInteractionDragAllowed(prefix) then return false end
        end
        local hud=SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
        local cursor=SCENE_MANAGER:IsShowing("hudui") or (IsGameCameraUIModeActive and IsGameCameraUIModeActive())
        return self.settings.enabled and (self.editing or (hud and cursor and not self.settings[prefix.."Locked"])) and not (self.IsNativeHudEditorOpen and self:IsNativeHudEditorOpen())
    end
    function A:BindWidgetDrag(window,prefix,position)
        if not self.widgetWindows[prefix] then self.widgetOrder[#self.widgetOrder+1]=prefix end
        local w={window=window,prefix=prefix,position=position}; self.widgetWindows[prefix]=w
        window:SetHandler("OnMouseDown",function(_,button)
            if (not MOUSE_BUTTON_INDEX_LEFT or button==MOUSE_BUTTON_INDEX_LEFT) and self:WidgetDragAllowed(prefix) and GetUIMousePosition then
                self.drag=nil; self.resizeDrag=nil
                local x,y=GetUIMousePosition(); local s=self.settings
                self.widgetDrag={widget=w,x=x,y=y,startX=s[prefix.."X"],startY=s[prefix.."Y"]}
                if self.editing then
                    self:SelectEdit({kind="widget",widget=w})
                    if self.SetEditInspectorDragging then self:SetEditInspectorDragging(true) end
                end
            end
        end)
        window:SetHandler("OnMouseUp",function(_,button,upInside)
            if self.editing and MOUSE_BUTTON_INDEX_RIGHT and button==MOUSE_BUTTON_INDEX_RIGHT and upInside then
                if self.widgetDrag and self.widgetDrag.widget==w then
                    self:RenderWidgetDrag(true)
                    self.widgetDrag=nil
                    highlightCenterGuides(false,false)
                    if self.SetEditInspectorDragging then self:SetEditInspectorDragging(false) end
                end
                self:ShowEditContextMenu({kind="widget",widget=w},window)
                return
            end
            if self.widgetDrag and self.widgetDrag.widget==w then
                self:RenderWidgetDrag(true)
                self.widgetDrag=nil
                highlightCenterGuides(false,false)
                if self.editing then
                    if self.SetEditInspectorDragging then self:SetEditInspectorDragging(false) end
                    self:PositionNudgeBar()
                end
            end
        end)
        window:SetHandler("OnHide",function()
            if self.widgetDrag and self.widgetDrag.widget==w then
                self.widgetDrag=nil
                highlightCenterGuides(false,false)
                if self.SetEditInspectorDragging then self:SetEditInspectorDragging(false) end
            end
        end)
        self:SyncWidgetDrag()
    end
    function A:SyncWidgetDrag()
        for prefix,w in pairs(self.widgetWindows) do
            local allow=not not self:WidgetDragAllowed(prefix)
            if w.mouse~=allow then w.mouse=allow; w.window:SetMouseEnabled(allow) end
            if not allow and self.widgetDrag and self.widgetDrag.widget==w then
                self.widgetDrag=nil
                highlightCenterGuides(false,false)
                if self.SetEditInspectorDragging then self:SetEditInspectorDragging(false) end
            end
            if self.editing or w.titleVisible then updateWidgetTitle(w) end
        end
        if self.effectHUD and self.effectHUD.SyncInteractive then self.effectHUD:SyncInteractive() end
    end
    function A:RenderWidgetDrag(released)
        local drag=self.widgetDrag; if not drag then return end
        local w=drag.widget; local p=w.prefix
        if not self:WidgetDragAllowed(p) then
            self.widgetDrag=nil
            highlightCenterGuides(false,false)
            if self.SetEditInspectorDragging then self:SetEditInspectorDragging(false) end
            return
        end
        local x,y=GetUIMousePosition(); local s=self.settings
        local g=self:GlobalUIScale()
        local dx,dy=(x-drag.x)*g,(y-drag.y)*g
        if self.editing then
            if s.editAxis=="Horizontal" then dy=0 elseif s.editAxis=="Vertical" then dx=0 end
            dx,dy=snap(dx,s.editSnap),snap(dy,s.editSnap)
        end
        local nx,ny=clampWidget(p,drag.startX+dx,drag.startY+dy)
        if nx~=s[p.."X"] or ny~=s[p.."Y"] then
            s[p.."X"],s[p.."Y"]=nx,ny; w.position()
            if self.editing then
                -- Magnetic screen-center alignment unless Shift is held.
                local cx,cy=centerOffset(w.window)
                local snapX,snapY=false,false
                if cx and not (IsShiftKeyDown and IsShiftKeyDown()) then
                    if math.abs(cx)<=CENTER_SNAP_THRESHOLD then
                        s[p.."X"]=clampWidget(p,s[p.."X"]-cx,s[p.."Y"]); snapX=true
                    end
                    if math.abs(cy)<=CENTER_SNAP_THRESHOLD then
                        local _,cyClamped=clampWidget(p,s[p.."X"],s[p.."Y"]-cy)
                        s[p.."Y"]=cyClamped; snapY=true
                    end
                    if snapX or snapY then w.position() end
                end
                highlightCenterGuides(snapX,snapY)
                updateWidgetTitle(w)
            end
        end
        if self.editing then self:RefreshEditReadout() end
        if released then self.widgetDrag=nil; highlightCenterGuides(false,false) end
    end
    local function startCornerResize(self)
        local key=self:GetEditSelectionKey()
        local spec=key and cornerResizeSpecs[key]
        if not spec or not GetUIMousePosition then return end
        local x,y=GetUIMousePosition()
        self.drag=nil; self.widgetDrag=nil
        self.resizeDrag={key=key,spec=spec,x=x,y=y,startVal=tonumber(self.settings[spec.key]) or spec.min}
        if self.SetEditInspectorDragging then self:SetEditInspectorDragging(true) end
        self:PositionNudgeBar()
    end
    local function renderCornerResize(self)
        local rd=self.resizeDrag; if not rd then return end
        local x,y=GetUIMousePosition()
        local g=self:GlobalUIScale()
        local delta=((x-rd.x)+(y-rd.y))*.5*g
        local spec=rd.spec
        local val=roundStep(rd.startVal+delta*spec.sens,spec.step,spec.min,spec.max)
        if val==self.settings[spec.key] then return end
        if spec.mode=="hudSize" then self:SetHudSize(spec.key,val)
        elseif spec.mode=="effectSize" and self.effectHUD then self.effectHUD:SetSizeOption(spec.key,val)
        else self.settings[spec.key]=val end
        self:ApplyScopedVisual(spec.scope)
        if self.SyncEditInspectorValue then self:SyncEditInspectorValue(spec.key)
        elseif self.RefreshEditInspector then self:RefreshEditInspector() end
    end
    local function endCornerResize(self)
        if not self.resizeDrag then return end
        self.resizeDrag=nil
        if self.SetEditInspectorDragging then self:SetEditInspectorDragging(false) end
        self:PositionNudgeBar()
        if self.RefreshEditInspector then self:RefreshEditInspector() end
    end
    -- Studio theme & Rajdhani Bold helpers (reuses A.studioStyle from Studio.lua).
    local CORAL={.871,.353,.447,1}
    local WHITE={1,1,1,1}
    local ROW_LAYER=DL_CONTROLS or 1
    local function rgba(c) return c[1],c[2],c[3],c[4] or 1 end
    local function studioTheme()
        local s=A.studioStyle
        if s and s.prepareFont then s.prepareFont() end
        return s
    end
    local function studioPalette(s)
        if s then return s.cream,s.card,s.field,s.ink,s.soft,s.yellow,s.teal end
        return {.906,.875,.800,1},{.941,.914,.855,1},{.886,.847,.761,1},{.086,.086,.086,1},{.33,.32,.30,1},{.953,.800,.310,1},{.373,.776,.682,1}
    end
    local function makeFill(s,parent,x,y,w,h,color,edge,thickness,level,layer)
        local b
        if s and s.fill then b=s.fill(parent,x,y,w,h,color,edge,thickness,level)
        else
            b=WM:CreateControl(nil,parent,CT_BACKDROP)
            b:SetDimensions(w,h); b:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
            b:SetCenterColor(rgba(color)); b:SetEdgeColor(rgba(edge)); b:SetEdgeTexture("",1,1,thickness or 2)
            b:SetDrawLayer(DL_BACKGROUND); b:SetDrawLevel(level or 1)
        end
        if layer then b:SetDrawLayer(layer) end
        return b
    end
    local function makeLabel(s,parent,value,x,y,w,size,color,align,h)
        if s and s.label then return s.label(parent,value,x,y,w,size,color,align,h,true) end
        local l=WM:CreateControl(nil,parent,CT_LABEL)
        l:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); l:SetDimensions(w,h or (size+8))
        l:SetFont(string.format("$(BOLD_FONT)|$(KB_%d)",size or 15))
        l:SetColor(rgba(color)); l:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT); l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        l:SetDrawLayer(DL_TEXT or DL_CONTROLS); l:SetText(value or "")
        return l
    end
    local function makeButton(s,parent,value,x,y,w,h,fn,accent,small,level)
        if s and s.button then
            local b=s.button(parent,value,x,y,w,h,fn,accent,small)
            if accent==CORAL and b.SetTextColor then b:SetTextColor(WHITE) end
            if level then
                if b.shadow then b.shadow:SetDrawLevel(level) end
                if b.face then b.face:SetDrawLevel(level+1) end
                if b.text then b.text:SetDrawLevel(level+3) end
            end
            return b
        end
        local b=WM:CreateControl(nil,parent,CT_BUTTON)
        b:SetDimensions(w,h); b:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
        b:SetFont("$(BOLD_FONT)|14|thick-outline"); b:SetText(value or ""); b:SetMouseEnabled(true)
        b:SetHandler("OnClicked",fn)
        function b:SetLabel(v) self:SetText(v or "") end
        function b:SetAccent() end
        function b:SetTextColor() end
        return b
    end
    local function boldFontForEdit(probeLabel,size)
        local f=probeLabel and probeLabel.GetFont and probeLabel:GetFont() or ""
        if f:find("Rajdhani",1,true) then
            local path=A.ResolveFont and A:ResolveFont("Rajdhani Bold") or "ZeraUI/fonts/Rajdhani-Bold-OL.slug"
            return string.format("%s|%d",path,math.floor(size*1.12+.5))
        end
        return string.format("$(BOLD_FONT)|$(KB_%d)",size)
    end

    local function buildNudgeBar(self)
        local s=studioTheme()
        local CREAM,CARD,_,INK,_,YELLOW,_=studioPalette(s)
        local bar=WM:CreateTopLevelWindow("ZeraUIEditNudgeBar")
        bar:SetDimensions(302,34); bar:SetDrawTier(DT_HIGH); bar:SetDrawLevel(45)
        bar:SetMouseEnabled(true); bar:SetHidden(true)
        makeFill(s,bar,3,3,302,34,INK,INK,1,0)
        makeFill(s,bar,0,0,302,34,CREAM,INK,2,1)
        local function btn(label,x,w,fn,accent)
            return makeButton(s,bar,label,x,4,w,24,fn,accent or CARD,true,3)
        end
        btn("<",6,26,function() self:NudgeEditSelection(-1,0) end)
        btn("^",36,26,function() self:NudgeEditSelection(0,-1) end)
        btn("v",66,26,function() self:NudgeEditSelection(0,1) end)
        btn(">",96,26,function() self:NudgeEditSelection(1,0) end)
        btn("0X",128,36,function() self:CenterEditSelection("x") end)
        btn(tr("Reset"),170,60,function() self:ResetEditSelection() end)
        btn(tr("Style"),236,60,function() if self.ToggleEditInspector then self:ToggleEditInspector() end end,YELLOW)
        self.editNudgeBar=bar
    end

    local BAR_W,BAR_H_OPEN,BAR_H_CLOSED=356,396,214
    local LIST_ROW_W,LIST_ROW_H,LIST_GAP_Y=310,24,3

    local function createElementRow(s,parent)
        local _,CARD,FIELD,INK,_,YELLOW,_=studioPalette(s)
        local btn=WM:CreateControl(nil,parent,CT_BUTTON)
        btn:SetDimensions(LIST_ROW_W,LIST_ROW_H); btn:SetMouseEnabled(true)
        local face=makeFill(s,btn,0,0,LIST_ROW_W,LIST_ROW_H,FIELD,INK,2,4,ROW_LAYER)
        local tag=makeFill(s,face,0,0,5,LIST_ROW_H,INK,INK,1,6,ROW_LAYER)
        local lbl=makeLabel(s,face,"",12,-2,LIST_ROW_W-18,13,INK,TEXT_ALIGN_LEFT,LIST_ROW_H)
        lbl:SetDrawLevel(9)
        local row={btn=btn,face=face,tag=tag,label=lbl,selected=false,hover=false}
        local function paint()
            if row.selected then
                face:SetCenterColor(rgba(INK))
                face:SetEdgeColor(rgba(INK))
                tag:SetCenterColor(rgba(YELLOW)); tag:SetEdgeColor(rgba(YELLOW))
                lbl:SetColor(rgba(YELLOW))
            else
                local c=row.hover and CARD or FIELD
                face:SetCenterColor(rgba(c))
                face:SetEdgeColor(rgba(row.hover and YELLOW or INK))
                tag:SetCenterColor(rgba(row.hover and YELLOW or INK)); tag:SetEdgeColor(rgba(row.hover and YELLOW or INK))
                lbl:SetColor(rgba(INK))
            end
        end
        row.paint=paint
        btn:SetHandler("OnMouseEnter",function() row.hover=true; paint() end)
        btn:SetHandler("OnMouseExit",function() row.hover=false; paint() end)
        btn:SetHandler("OnMouseUp",function(_,mouse,inside)
            if not inside or not A.editing then return end
            if MOUSE_BUTTON_INDEX_RIGHT and mouse==MOUSE_BUTTON_INDEX_RIGHT then
                if row.sel then A:ShowEditContextMenu(row.sel,btn) end
                return
            end
            if not MOUSE_BUTTON_INDEX_LEFT or mouse==MOUSE_BUTTON_INDEX_LEFT then
                if PlaySound and SOUNDS and SOUNDS.DEFAULT_CLICK then PlaySound(SOUNDS.DEFAULT_CLICK) end
                A:SelectEdit(row.sel)
                if A.ShowEditInspector then A:ShowEditInspector(true) end
            end
        end)
        btn:SetHidden(true)
        return row
    end

    function A:SetEditElementListOpen(open)
        self.editListOpen=open~=false
        if not self.editToolbar then return end
        local s=studioTheme()
        local _,CARD,_,_,_,YELLOW,_=studioPalette(s)
        local h=self.editListOpen and BAR_H_OPEN or BAR_H_CLOSED
        self.editToolbar:SetHeight(h)
        if self.editToolbarBg then self.editToolbarBg:SetHeight(h) end
        if self.editToolbarShadow then self.editToolbarShadow:SetHeight(h) end
        if self.editListCard then self.editListCard:SetHidden(not self.editListOpen) end
        if self.editListShadow then self.editListShadow:SetHidden(not self.editListOpen) end
        if self.editListScroll then self.editListScroll:SetHidden(not self.editListOpen) end
        if self.editElementsToggle then
            self.editElementsToggle:SetAccent(self.editListOpen and YELLOW or CARD)
            local count=self.editElementCount or 0
            self.editElementsToggle:SetLabel(string.format("%s (%d) %s",tr("Elements"),count,self.editListOpen and "^" or "v"))
        end
    end

    function A:SyncEditInspectorButton()
        if not self.editInspectorButton then return end
        local s=studioTheme()
        local _,CARD,_,_,_,YELLOW,_=studioPalette(s)
        local shown=self.IsEditInspectorShown and self:IsEditInspectorShown()
        self.editInspectorButton:SetAccent(shown and YELLOW or CARD)
    end

    function A:RefreshEditElementList(highlightOnly)
        if not self.editing or not self.editListChild then return end
        local selectedKey=self:GetEditSelectionKey()
        local rows=self.editListRows or {}
        if highlightOnly and self.editListEntries then
            for i,entry in ipairs(self.editListEntries) do
                local row=rows[i]
                if row then
                    local isSel=entry.key==selectedKey
                    if row.selected~=isSel then row.selected=isSel; row.paint() end
                end
            end
            return
        end
        local s=studioTheme()
        local elements=self:GetEditableElements()
        self.editElementCount=#elements
        local entries={{key=nil,title=tr("HUD Overview"),sel=nil}}
        for _,e in ipairs(elements) do entries[#entries+1]=e end
        self.editListEntries=entries
        for i,entry in ipairs(entries) do
            local row=rows[i]
            if not row then
                row=createElementRow(s,self.editListChild)
                rows[i]=row
            end
            local y=(i-1)*(LIST_ROW_H+LIST_GAP_Y)
            row.sel=entry.sel
            row.key=entry.key
            row.selected=entry.key==selectedKey
            row.label:SetText(entry.title or "")
            row.btn:ClearAnchors()
            row.btn:SetAnchor(TOPLEFT,self.editListChild,TOPLEFT,0,y)
            row.btn:SetHidden(false)
            row.paint()
        end
        for i=#entries+1,#rows do rows[i].btn:SetHidden(true) end
        self.editListRows=rows
        local totalH=math.max(20,#entries*(LIST_ROW_H+LIST_GAP_Y)+4)
        if self.editListChild~=self.editListScroll then
            self.editListChild:SetHeight(totalH)
            if ZO_Scroll_UpdateScrollBar and self.editListScroll then pcall(ZO_Scroll_UpdateScrollBar,self.editListScroll) end
        end
        if self.editElementsToggle then
            self.editElementsToggle:SetLabel(string.format("%s (%d) %s",tr("Elements"),self.editElementCount,self.editListOpen and "^" or "v"))
        end
    end

    function A:BuildEditControls()
        if self.editHandles then return end
        local st=studioTheme()
        local CREAM,CARD,FIELD,INK,INK_SOFT,YELLOW,TEAL=studioPalette(st)
        self.editHandles={}
        buildCenterGuides(self)
        buildNudgeBar(self)
        for _,part in ipairs(parts) do
            local descriptor=part
            local c=UI.panel(self.root,100,50,0,0)
            c:SetDrawTier(DT_HIGH); c:SetDrawLevel(30); c:SetMouseEnabled(true)
            local border=UI.texture(c,UI.path.."editframe.dds",100,50,0,0,31)
            local label=UI.text(c,14,120,20,0,-20,32)
            label:SetText(tr(part.name))
            c:SetHidden(true)
            c:SetHandler("OnMouseDown",function(_,button)
                if self.editing and (not MOUSE_BUTTON_INDEX_LEFT or button==MOUSE_BUTTON_INDEX_LEFT) then
                    self:SelectEdit({kind="part",part=descriptor})
                    self:StartDrag(descriptor)
                end
            end)
            c:SetHandler("OnMouseUp",function(_,button,upInside)
                if self.editing and MOUSE_BUTTON_INDEX_RIGHT and button==MOUSE_BUTTON_INDEX_RIGHT and upInside then
                    self:EndDrag()
                    self:ShowEditContextMenu({kind="part",part=descriptor},c)
                    return
                end
                self:EndDrag()
            end)
            c:SetHandler("OnHide",function()
                if self.drag and self.drag.part==descriptor then self:EndDrag() end
            end)
            self.editHandles[part.name]={control=c,border=border,label=label}
        end
        local bar=WM:CreateTopLevelWindow("ZeraUIEditToolbar")
        bar:SetDimensions(BAR_W,BAR_H_OPEN); bar:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,24,90)
        bar:SetDrawTier(DT_HIGH); bar:SetMouseEnabled(true); bar:SetMovable(true); bar:SetClampedToScreen(true)
        self.editToolbarShadow=makeFill(st,bar,6,6,BAR_W,BAR_H_OPEN,INK,INK,1,0)
        self.editToolbarBg=makeFill(st,bar,0,0,BAR_W,BAR_H_OPEN,CREAM,INK,3,1)
        local title=makeLabel(st,bar,tr("ZERA UI — EDIT MODE"),12,8,230,18,INK,TEXT_ALIGN_LEFT,28)
        local editFont=boldFontForEdit(title,14)

        self.editInspectorButton=makeButton(st,bar,tr("Inspector"),248,10,98,26,function()
            if self.ToggleEditInspector then self:ToggleEditInspector() end
        end,YELLOW,true,4)

        self.editStatusStrip=makeFill(st,bar,10,42,BAR_W-20,24,CARD,INK,2,2)
        self.editStatus=makeLabel(st,self.editStatusStrip,"",8,-2,BAR_W-36,12,INK,TEXT_ALIGN_LEFT,24)
        self.editStatus:SetDrawLevel(9)

        local function button(name,x,y,width,height,fn,accent,small)
            return makeButton(st,bar,tr(name),x,y,width,height,fn,accent or CARD,small,4)
        end
        local function smallEdit(x,y,w,maxChars,onCommit)
            local bg=makeFill(st,bar,x,y,w,28,FIELD,INK,2,3)
            local box
            if WM.CreateControlFromVirtual then
                local ok,created=pcall(WM.CreateControlFromVirtual,WM,nil,bg,"ZO_DefaultEditForBackdrop")
                if ok then box=created end
            end
            if not box then
                box=WM:CreateControl(nil,bg,CT_EDITBOX)
                box:SetAnchor(TOPLEFT,bg,TOPLEFT,6,4); box:SetAnchor(BOTTOMRIGHT,bg,BOTTOMRIGHT,-6,-4)
            end
            box:SetFont(editFont); box:SetMaxInputChars(maxChars or 6)
            box:SetDrawLayer(DL_CONTROLS or 1); box:SetDrawLevel(10)
            box:SetMouseEnabled(true)
            if box.SetColor then box:SetColor(rgba(INK)) end
            box:SetHandler("OnMouseDown",function(c) if not c:HasFocus() then c:TakeFocus() end end)
            box:SetHandler("OnEnter",function(c) c:LoseFocus(); onCommit(c) end)
            box:SetHandler("OnEscape",function(c) c:LoseFocus(); self:RefreshEditReadout(true) end)
            box:SetHandler("OnFocusGained",function() bg:SetEdgeTexture("",1,1,3); bg:SetCenterColor(rgba(CARD)) end)
            box:SetHandler("OnFocusLost",function() bg:SetEdgeTexture("",1,1,2); bg:SetCenterColor(rgba(FIELD)) end)
            return box
        end
        local function coordinate(name,x)
            makeLabel(st,bar,name,x,72,16,13,INK,TEXT_ALIGN_CENTER,28)
            local box=smallEdit(x+18,72,80,6,function() self:ApplyEditCoordinates() end)
            box:SetHandler("OnTab",function() if box==self.editX and self.editY then self.editY:TakeFocus() else box:LoseFocus(); self:ApplyEditCoordinates() end end)
            return box
        end
        -- Row 1: Coordinates + Apply (symmetric 10px margins)
        self.editX=coordinate("X",10)
        self.editY=coordinate("Y",114)
        button("Apply",220,72,126,28,function() self:ApplyEditCoordinates() end,CARD,true)
        -- Row 2: Snap + Grid + Elements list toggle
        makeLabel(st,bar,tr("Snap"),10,106,42,13,INK,TEXT_ALIGN_LEFT,28)
        self.editSnapBox=smallEdit(54,106,44,3,function(c)
            local v=math.max(0,math.min(64,math.floor(tonumber(c:GetText()) or self.settings.editSnap or 0)))
            self.settings.editSnap=v; c:SetText(tostring(v))
            self:RefreshEditGrid(); self:UpdateEditHandles()
            if self.RefreshEditInspector then self:RefreshEditInspector() end
        end)
        self.editGridButton=button("Grid: OFF",104,106,114,28,function()
            self.settings.editShowGrid=not self.settings.editShowGrid
            self:RefreshEditGrid(); self:UpdateEditHandles()
            if self.RefreshEditInspector then self:RefreshEditInspector() end
        end,CARD,true)
        self.editListOpen=true
        self.editElementsToggle=button("Elements",224,106,122,28,function()
            self:SetEditElementListOpen(not self.editListOpen)
        end,YELLOW,true)
        -- Row 3: Move together + Reset all
        self.editLinkButton=button("Move together",10,140,164,28,function()
            self:EndDrag(); self.settings.moveTogether=not self.settings.moveTogether; self:UpdateEditHandles(); self:RefreshEditReadout(true)
            if self.RefreshEditInspector then self:RefreshEditInspector() end
        end,CARD,true)
        self.editResetAll=button("Reset all",182,140,164,28,function()
            self:EndDrag()
            local now=GetFrameTimeMilliseconds()
            if not self.editResetArmed or now-self.editResetArmed>3000 then
                self.editResetArmed=now
                self.editResetAll:SetLabel(tr("Click again to confirm"))
                self.editResetAll:SetAccent(CORAL)
                if self.editResetAll.SetTextColor then self.editResetAll:SetTextColor(WHITE) end
                return
            end
            self.editResetArmed=nil
            self.editResetAll:SetLabel(tr("Reset all"))
            if self.editResetAll.SetTextColor then self.editResetAll:SetTextColor(nil) end
            self.editResetAll:SetAccent(CARD)
            for _,key in ipairs(keys) do self.settings[key]=self:DefaultSetting(key) end
            for _,w in pairs(self.widgetWindows) do w.position(); updateWidgetTitle(w) end
            self:ResetAttributePositions()
            self:PositionElements(); self:UpdateEditHandles(); self.editReadoutAt=0
            if self.RefreshEditInspector then self:RefreshEditInspector() end
        end,CARD,true)
        -- Row 4: Cancel + Save
        button("Cancel",10,174,164,30,function() self:FinishEdit(false) end,CARD,false)
        button("Save",182,174,164,30,function() self:FinishEdit(true) end,TEAL,false)

        -- Compact single-column selectable HUD Elements list card.
        self.editListShadow=makeFill(st,bar,13,217,BAR_W-20,170,INK,INK,1,2)
        self.editListCard=makeFill(st,bar,10,214,BAR_W-20,170,CARD,INK,2,3)
        makeLabel(st,self.editListCard,tr("HUD Elements"),10,1,150,13,INK,TEXT_ALIGN_LEFT,22)
        makeLabel(st,self.editListCard,tr("Right-click: options"),164,2,162,11,INK_SOFT,TEXT_ALIGN_RIGHT,20)
        makeFill(st,self.editListCard,8,24,BAR_W-36,2,INK,INK,1,4)

        -- Parent scroll container to `bar` (not `DL_BACKGROUND` backdrop) so its
        -- controls & native scrollbar keep crisp DL_CONTROLS layering.
        local listScroll,listChild
        if WM.CreateControlFromVirtual then
            local ok,created=pcall(WM.CreateControlFromVirtual,WM,"ZeraUIEditElementListScroll",bar,"ZO_ScrollContainer")
            if ok and created then
                listScroll=created
                listChild=listScroll:GetNamedChild("ScrollChild")
            end
        end
        if not listScroll or not listChild then
            listScroll=WM:CreateControl(nil,bar,CT_CONTROL)
            listChild=listScroll
        end
        listScroll:SetAnchor(TOPLEFT,self.editListCard,TOPLEFT,8,30)
        listScroll:SetAnchor(BOTTOMRIGHT,self.editListCard,BOTTOMRIGHT,-2,-6)
        if listChild~=listScroll then
            listChild:SetWidth(LIST_ROW_W)
            if ZO_Scroll_SetUseFadeGradient then pcall(ZO_Scroll_SetUseFadeGradient,listScroll,false) end
        end
        self.editListScroll,self.editListChild,self.editListRows=listScroll,listChild,{}

        local holder=WM:CreateTopLevelWindow("ZeraUIEditSelection")
        holder:SetDrawTier(DT_HIGH); holder:SetMouseEnabled(false)
        holder:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,0,0); holder:SetDimensions(1,1)
        -- Four solid edges and a faint fill, all plain backdrop centers.
        local frame=WM:CreateControl(nil,holder,CT_CONTROL)
        frame:SetMouseEnabled(false)
        local function edge(p1,p2,x1,y1,x2,y2,w,h,alpha)
            local e=WM:CreateControl(nil,frame,CT_BACKDROP)
            e:SetMouseEnabled(false); e:SetDrawLayer(DL_OVERLAY or DL_CONTROLS); e:SetDrawLevel(50)
            e:SetEdgeColor(0,0,0,0); e:SetCenterColor(1,.78,.3,alpha or 1)
            e:SetAnchor(p1,frame,p1,x1,y1); e:SetAnchor(p2,frame,p2,x2,y2)
            if w then e:SetWidth(w) end; if h then e:SetHeight(h) end
        end
        edge(TOPLEFT,BOTTOMRIGHT,0,0,0,0,nil,nil,.08)
        edge(TOPLEFT,TOPRIGHT,0,0,0,0,nil,2)
        edge(BOTTOMLEFT,BOTTOMRIGHT,0,0,0,0,nil,2)
        edge(TOPLEFT,BOTTOMLEFT,0,0,0,0,2,nil)
        edge(TOPRIGHT,BOTTOMRIGHT,0,0,0,0,2,nil)
        -- Bottom-right corner resize grip for scalable/resizable widgets.
        local grip=WM:CreateControl(nil,frame,CT_BACKDROP)
        grip:SetDimensions(12,12); grip:SetAnchor(BOTTOMRIGHT,frame,BOTTOMRIGHT,2,2)
        grip:SetDrawLayer(DL_OVERLAY or DL_CONTROLS); grip:SetDrawLevel(55)
        grip:SetCenterColor(1,.82,.32,.95); grip:SetEdgeColor(.12,.09,.03,1); grip:SetEdgeTexture("",1,1,1)
        grip:SetMouseEnabled(true); grip:SetHidden(true)
        grip:SetHandler("OnMouseDown",function(_,button)
            if self.editing and (not MOUSE_BUTTON_INDEX_LEFT or button==MOUSE_BUTTON_INDEX_LEFT) then startCornerResize(self) end
        end)
        grip:SetHandler("OnMouseUp",function() endCornerResize(self) end)
        grip:SetHandler("OnHide",function() endCornerResize(self) end)
        grip:SetHandler("OnMouseEnter",function() grip:SetCenterColor(1,.95,.65,1) end)
        grip:SetHandler("OnMouseExit",function() grip:SetCenterColor(1,.82,.32,.95) end)
        self.editResizeHandle=grip
        frame:SetHidden(true)
        self.editSelectionFrame=frame
        bar:SetHidden(true); self.editToolbar=bar
    end
    function A:UpdateEditHandles()
        if not self.editing then return end
        local s=self.settings
        local st=studioTheme()
        local _,CARD,_,_,_,_,TEAL=studioPalette(st)
        local geometry=self:HudEditGeometry()
        for name,h in pairs(self.editHandles) do
            local g=geometry[name]; UI.reposition(h.control,self.root,g[1],g[2])
            h.control:SetDimensions(g[3],g[4]); h.border:SetDimensions(g[3],g[4])
            h.label:SetWidth(math.max(90,g[3])); local attr=name=="Attributes" or name=="Health" or name=="Magicka" or name=="Stamina"
            h.control:SetHidden(self.editColorPickerActive or (attr and (not (self.attrOwned or (self.IsCustomBarsActive and self:IsCustomBarsActive())) or (name=="Attributes" and s.attrSplit) or (name~="Attributes" and not s.attrSplit))))
        end
        self.editLinkButton:SetLabel(tr(s.moveTogether and "Move together: ON" or "Move together: OFF"))
        self.editLinkButton:SetAccent(s.moveTogether and TEAL or CARD)
        if self.editGridButton then
            self.editGridButton:SetLabel(tr(s.editShowGrid and "Grid: ON" or "Grid: OFF"))
            self.editGridButton:SetAccent(s.editShowGrid and TEAL or CARD)
        end
        if self.editSnapBox and (not self.editSnapBox.HasFocus or not self.editSnapBox:HasFocus()) then
            self.editSnapBox:SetText(tostring(s.editSnap or 0))
        end
        if not self.editSelected then
            self.editStatus:SetText(string.format(tr("Select an element  •  Snap %d px"),s.editSnap or 0))
        end
        self:SyncEditInspectorButton()
        if not isDraggingAny() then self:RefreshEditElementList(false) end
        self:PositionNudgeBar()
    end
    function A:StartDrag(part)
        if not self.editing or self.editColorPickerActive or not GetUIMousePosition then return end
        local x,y=GetUIMousePosition()
        self.resizeDrag=nil
        local linked=self.settings.moveTogether and not part.independent
        self.drag={part=part,x=x,y=y,origin=snapshot(self.settings),linked=linked}
        if self.SetEditInspectorDragging then self:SetEditInspectorDragging(true) end
        self:PositionNudgeBar()
        self:RefreshEditReadout()
    end
    function A:RenderEdit()
        local now=GetFrameTimeMilliseconds()
        if self.resizeDrag then renderCornerResize(self); return end
        if self.editSelected and (not self.editReadoutAt or now-self.editReadoutAt>=100) then
            self.editReadoutAt=now; self:RefreshEditReadout()
        end
        if not self.drag then return end
        local d=self.drag; local s=self.settings
        local x,y=GetUIMousePosition()
        local g=self:GlobalUIScale()
        local dx,dy=(x-d.x)*g,(y-d.y)*g
        if s.editAxis=="Horizontal" then dy=0 elseif s.editAxis=="Vertical" then dx=0 end
        if not d.linked then dx=dx/s.scale; dy=dy/s.scale end
        dx,dy=snap(dx,s.editSnap),snap(dy,s.editSnap)
        if d.dx==dx and d.dy==dy then return end
        if not d.linked and not d.arrowAligned and (dx~=0 or dy~=0) then
            alignArrowPartOffset(self,d.part)
            d.origin=snapshot(s)
            d.arrowAligned=true
        end
        d.dx,d.dy=dx,dy
        restore(s,d.origin)
        if d.linked then s.x=s.x+dx; s.y=s.y+dy
        else
            local part=d.part
            s[part.x]=s[part.x]+dx; s[part.y]=s[part.y]+dy
            -- The other element anchors follow the skill grid by design.
            -- Counter-offset them when only the grid should move.
            if part.grid then
                for _,p in ipairs(parts) do if not p.grid and not p.attributeIndividual then
                    s[p.x]=s[p.x]-dx; s[p.y]=s[p.y]-dy
                end end
            end
        end
        self:PositionElements(); self:UpdateEditHandles()
        -- Magnetic screen-center snap for parts unless Shift is held.
        local h=self.editHandles and self.editHandles[d.part.name]
        local cx,cy=centerOffset(h and h.control)
        local snapX,snapY=false,false
        if cx and not (IsShiftKeyDown and IsShiftKeyDown()) then
            if math.abs(cx)<=CENTER_SNAP_THRESHOLD then snapX=true end
            if math.abs(cy)<=CENTER_SNAP_THRESHOLD then snapY=true end
            if snapX or snapY then
                moveSelection({kind="part",part=d.part},snapX and -cx or 0,snapY and -cy or 0)
            end
        end
        highlightCenterGuides(snapX,snapY)
        self:RefreshEditReadout()
    end
    function A:EndDrag()
        self.drag=nil
        endCornerResize(self)
        highlightCenterGuides(false,false)
        if self.SetEditInspectorDragging then self:SetEditInspectorDragging(false) end
        self:UpdateEditHandles()
    end
    function A:BeginEdit()
        if self.editing then return end
        if self.gamepadSuspended then return end
        if self:IsNativeHudEditorOpen() then d("Zera UI: exit ESO's HUD editor first."); return end
        if IsUnitInCombat and IsUnitInCombat("player") then d("Zera UI: leave combat before editing the HUD."); return end
        if self.CloseTrackMenu then self:CloseTrackMenu() end
        self:BuildEditControls()
        -- Full transactional snapshot: Save commits all position + appearance
        -- edits; Cancel restores every visual and layout key cleanly.
        self.editOriginal=self.SnapshotAppearance and self:SnapshotAppearance() or snapshot(self.settings)
        self.editPreview=not not self.preview
        self.editing=true
        self.editCoordinateText=nil
        self.editResetArmed=nil
        self.editResetAll:SetLabel(tr("Reset all"))
        local _,CARD=studioPalette(studioTheme())
        if self.editResetAll.SetTextColor then self.editResetAll:SetTextColor(nil) end
        self.editResetAll:SetAccent(CARD)
        self:SelectEdit(nil)
        self.editCenterGuides:SetHidden(false)
        highlightCenterGuides(false,false)
        self:RefreshEditGrid()
        if not self.preview then self:Command("preview") else self:UpdatePreview() end
        self:ApplyVisibility() -- show sample widgets even with no target/equipped proc
        self.editToolbar:SetHidden(false)
        self:UpdateEditHandles()
        self:SetEditElementListOpen(self.editListOpen~=false)
        if ZO_Scroll_ResetToTop and self.editListScroll and self.editListChild~=self.editListScroll then pcall(ZO_Scroll_ResetToTop,self.editListScroll) end
        if self.ShowEditInspector then self:ShowEditInspector(true) end
        -- Exit the Settings scene into the game's cursor-mode HUD.
        self:EnterEditorInput()
    end
    function A:FinishEdit(save,nativeTakeover)
        if not self.editing then return end
        self.drag=nil
        self.widgetDrag=nil
        self.resizeDrag=nil
        highlightCenterGuides(false,false)
        if self.SetEditInspectorDragging then self:SetEditInspectorDragging(false) end
        if ClearMenu then ClearMenu() end
        if COLOR_PICKER and COLOR_PICKER.IsShown and COLOR_PICKER:IsShown() and COLOR_PICKER.Cancel then COLOR_PICKER:Cancel() end
        if COLOR_PICKER_GAMEPAD and COLOR_PICKER_GAMEPAD.IsShown and COLOR_PICKER_GAMEPAD:IsShown() and COLOR_PICKER_GAMEPAD.Cancel then COLOR_PICKER_GAMEPAD:Cancel() end
        self.editColorPickerActive=false
        if self.SetEditInspectorColorPickerActive then self:SetEditInspectorColorPickerActive(false) end
        if not save then
            if self.RestoreAppearanceSnapshot then self:RestoreAppearanceSnapshot(self.editOriginal)
            else restore(self.settings,self.editOriginal) end
        end
        self.editing=false; self.editOriginal=nil
        self.editCoordinateText=nil
        self:SelectEdit(nil)
        if self.ShowEditInspector then self:ShowEditInspector(false) end
        if self.editX then self.editX:LoseFocus(); self.editY:LoseFocus() end
        if self.editSnapBox then self.editSnapBox:LoseFocus() end
        self.editCenterGuides:SetHidden(true)
        if self.editGridOverlay then self.editGridOverlay.root:SetHidden(true) end
        if self.editNudgeBar then self.editNudgeBar:SetHidden(true) end
        for _,h in pairs(self.editHandles) do h.control:SetHidden(true) end
        self.editToolbar:SetHidden(true)
        local wasPreview=self.editPreview; self.editPreview=nil
        if (not not self.preview)~=wasPreview then self:Command("preview") end
        self:ApplySettings()
        if CALLBACK_MANAGER and self.settingsPanel then
            CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel",self.settingsPanel)
        end
        if nativeTakeover then return end
        if self.ReleaseEditorInput then self:ReleaseEditorInput()
        elseif SetGameCameraUIMode then pcall(SetGameCameraUIMode,false) end
    end
end
