-- Custom Attribute Bar, flat layouts (Native, Stacked, Pyramid): Zera's own
-- bars with the Cast Classic artwork, at the same place and size the skin
-- had when it was drawn over ESO's bars (AttributeGeometry). ESO's health,
-- magicka and stamina bars are hidden and their power handler paused
-- (AttributeCore); the small bars ESO hangs under them (mount stamina,
-- werewolf, siege) are hung under these bars instead.
function ZeraUIAttachCustomBars(A,UI)
    local core=ZeraUIAttributeCore
    local WM=WINDOW_MANAGER
    local NS="ZeraUICustomBars"
    local BARS={
        {name="Health",power="COMBAT_MECHANIC_FLAGS_HEALTH",native="ZO_PlayerAttributeHealth"},
        {name="Magicka",power="COMBAT_MECHANIC_FLAGS_MAGICKA",native="ZO_PlayerAttributeMagicka"},
        {name="Stamina",power="COMBAT_MECHANIC_FLAGS_STAMINA",native="ZO_PlayerAttributeStamina"},
    }
    -- ESO anchors these to its own bars (playerattributebars.xml).
    local SMALL={
        {control="ZO_PlayerAttributeMountStamina",to="Stamina",point=TOPLEFT,rel=BOTTOMLEFT},
        {control="ZO_PlayerAttributeWerewolf",to="Magicka",point=TOPRIGHT,rel=BOTTOMRIGHT},
        {control="ZO_PlayerAttributeSiegeHealth",to="Health",point=TOP,rel=BOTTOM},
    }
    local COLORS={Health={218/255,52/255,53/255},Magicka={50/255,145/255,246/255},Stamina={32/255,186/255,118/255}}
    local SHIELD_RGB={.30,.65,1}
    local TRAUMA_RGB={.67,.11,.39}          -- ESO's trauma gradient (powershield.lua)
    local NO_HEALING_RGBA={.50,.07,.07,.45} -- ESO's no-healing frame colour, as a tint
    local WARN_RGB={1,.12,.10}
    local LOW=.25                           -- ESO's health warning threshold
    local FLASH_MS=300                      -- ESO's warner half-cycle
    local C={bars={},byName={},byPower={},vis=core.vis}
    local movingCount=0

    local function tex(parent,file,w,h,x,y,level)
        local c=UI.texture(parent,file,w,h,x,y,level)
        c:SetDrawTier(DT_HIGH)
        return c
    end
    local function build()
        if C.window then return end
        local win=WM:CreateTopLevelWindow(NS)
        win:SetMouseEnabled(false); win:SetHidden(true); win:SetDrawTier(DT_HIGH)
        C.window=win
        for _,d in ipairs(BARS) do
            local e={name=d.name,power=d.power,native=d.native}
            e.anchor=UI.panel(win,1,1,0,0)
            e.bar=UI.panel(e.anchor,1,1,0,0)
            e.bar:SetDrawTier(DT_HIGH)
            local rgb=COLORS[d.name]
            e.base=tex(e.bar,UI.path.."attribute_classic_base.dds",1,1,0,0,5)
            e.track=tex(e.bar,UI.path.."casttrack.dds",1,1,2,2,6)
            e.fill=tex(e.bar,UI.path.."attribute_classic_fill.dds",1,1,0,0,7)
            e.fill:SetTextureCoords(0,1,0,1); e.fill:SetColor(rgb[1],rgb[2],rgb[3],1)
            e.edge=tex(e.bar,UI.path.."attribute_classic_fill.dds",1,1,0,0,8)
            e.edge:SetColor(math.min(1,rgb[1]+.18),math.min(1,rgb[2]+.18),math.min(1,rgb[3]+.18),1)
            e.edge:SetHidden(true)
            if d.name=="Health" then
                e.noHealing=tex(e.bar,UI.path.."attribute_classic_fill.dds",1,1,2,2,8)
                e.noHealing:SetColor(NO_HEALING_RGBA[1],NO_HEALING_RGBA[2],NO_HEALING_RGBA[3],NO_HEALING_RGBA[4]); e.noHealing:SetHidden(true)
                e.shield=tex(e.bar,UI.path.."attribute_classic_fill.dds",1,2,2,2,9)
                e.shield:SetColor(SHIELD_RGB[1],SHIELD_RGB[2],SHIELD_RGB[3],1); e.shield:SetHidden(true)
                e.trauma=tex(e.bar,UI.path.."attribute_classic_fill.dds",1,2,2,2,9)
                e.trauma:SetColor(TRAUMA_RGB[1],TRAUMA_RGB[2],TRAUMA_RGB[3],1); e.trauma:SetHidden(true)
                e.warn=tex(e.bar,UI.path.."attribute_classic_warning.dds",1,1,-5,-5,10)
                e.warn:SetColor(WARN_RGB[1],WARN_RGB[2],WARN_RGB[3],1)
                if TEX_BLEND_MODE_ADD and e.warn.SetBlendMode then e.warn:SetBlendMode(TEX_BLEND_MODE_ADD) end
                e.warn:SetAlpha(0); e.warn:SetHidden(true)
            end
            e.number=UI.text(e.bar,16,100,24,0,0,30)
            e.number:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            e.number:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            e.number:SetDrawTier(DT_HIGH)
            C.bars[#C.bars+1]=e
            C.byName[d.name]=e
        end
    end

    -- Fill: same geometry and 160 ms smoothstep as the Cast Classic skin.
    -- The fill is hung once (layout) from the bar's start edge, the bright
    -- edge from the fill's moving end, so a frame only changes the width,
    -- and only when the drawn width changes by a quarter unit on screen.
    local function hangFill(e)
        local pad=2
        e.fill:ClearAnchors(); e.edge:ClearAnchors()
        if e.reverse then
            e.fill:SetAnchor(TOPRIGHT,e.bar,TOPRIGHT,-pad,pad)
            e.edge:SetAnchor(TOPLEFT,e.fill,TOPLEFT,0,1)
        else
            e.fill:SetAnchor(TOPLEFT,e.bar,TOPLEFT,pad,pad)
            e.edge:SetAnchor(TOPRIGHT,e.fill,TOPRIGHT,0,1)
        end
        e.fill:SetHeight(e.height-2*pad)
        e.edge:SetDimensions(1,math.max(1,e.height-2*pad-2))
        e.fillShown,e.edgeShown,e.fillKey=nil,nil,nil
    end
    local function drawFill(e,fraction,exact)
        e.fraction=fraction
        local amount=math.max(1,e.width-4)*fraction
        local fill=fraction>0
        if e.fillShown~=fill then e.fillShown=fill; e.fill:SetHidden(not fill) end
        if fill then
            -- Exact endpoint widths and quantized frame widths must not collide.
            local key=exact and amount or -math.floor(amount*e.screenScale*4+.5)
            if e.fillKey~=key then e.fillKey=key; e.fill:SetWidth(amount) end
        end
        local edge=fill and fraction<1 and amount>=1
        if e.edgeShown~=edge then e.edgeShown=edge; e.edge:SetHidden(not edge) end
    end
    local function detachMotion(e)
        if not e.moving then return end
        e.moving=false
        movingCount=movingCount-1
        if movingCount<=0 then
            movingCount=0
            if C.window then C.window:SetHandler("OnUpdate",nil) end
        end
    end
    local function stopMotion(e)
        detachMotion(e)
        e.target=nil; e.fraction=nil
    end
    local function sharedTick()
        local now=GetFrameTimeMilliseconds()
        local bars=C.bars
        for i=1,#bars do
            local e=bars[i]
            if e.moving then
                local t=(now-e.startTime)/160
                if t>=1 then
                    drawFill(e,e.target,true)
                    e.moving=false
                    movingCount=movingCount-1
                else
                    if t<0 then t=0 end
                    local eased=t*t*(3-2*t)
                    drawFill(e,e.start+(e.target-e.start)*eased)
                end
            end
        end
        if movingCount<=0 then
            movingCount=0
            C.window:SetHandler("OnUpdate",nil)
        end
    end
    local function moveFill(e,fraction)
        if e.target==fraction then return end
        if e.fraction==nil then drawFill(e,fraction,true); e.target=fraction; return end
        e.target=fraction
        if e.fraction==fraction then detachMotion(e); return end
        e.start,e.startTime=e.fraction,GetFrameTimeMilliseconds()
        if not e.moving then
            e.moving=true
            movingCount=movingCount+1
            if movingCount==1 and C.window then C.window:SetHandler("OnUpdate",sharedTick) end
        end
    end
    -- A 2 px line along the top (shield) or bottom (trauma), as a share of
    -- the maximum, never longer than the bar.
    local function line(e,c,amount,key)
        local fraction=e.maximum and amount>0 and math.max(0,math.min(1,amount/e.maximum)) or 0
        if e[key]==fraction and e[key.."W"]==e.width then return end
        e[key],e[key.."W"]=fraction,e.width
        c:SetHidden(fraction<=0)
        if fraction>0 then c:SetDimensions(math.max(1,(e.width-4)*fraction),2) end
    end
    local function healthMarks(e)
        local s=A.settings
        line(e,e.shield,C.vis.shield,"shieldFraction")
        line(e,e.trauma,s.attrTrauma~=false and C.vis.trauma or 0,"traumaFraction")
        local tint=s.attrNoHealing~=false and C.vis.noHealing or false
        if e.tinted~=tint then e.tinted=tint; e.noHealing:SetHidden(not tint) end
    end

    -- Warning: health pulses at 25 % or lower (ESO's health warner, with the
    -- Cast Classic art). Magicka and stamina warnings stay off, as they were
    -- under Cast Classic (clean resource visuals).
    local function startWarn(e)
        if e.warnOn then return end
        e.warnOn=true
        e.warn:SetAlpha(0); e.warn:SetHidden(false)
        -- Same native 0-to-1, 300 ms ping-pong as ESO's health warner.
        if not e.warnTimeline and CreateSimpleAnimation and ANIMATION_ALPHA and ANIMATION_PLAYBACK_PING_PONG and LOOP_INDEFINITELY then
            local animation,timeline=CreateSimpleAnimation(ANIMATION_ALPHA,e.warn)
            animation:SetAlphaValues(0,1); animation:SetDuration(FLASH_MS)
            timeline:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG,LOOP_INDEFINITELY)
            e.warnTimeline=timeline
        end
        if e.warnTimeline then e.warnTimeline:PlayFromStart() end
    end
    local function stopWarn(e)
        e.warnLow=nil
        if e.warnOn then
            e.warnOn=false
            if e.warnTimeline then e.warnTimeline:Stop() end
            e.warn:SetAlpha(0); e.warn:SetHidden(true)
        end
    end
    local function lowHealth(e)
        local low=e.value>0 and e.value/e.maximum<=LOW and not (IsUnitDead and IsUnitDead("player"))
        if low==(e.warnLow or false) then return end
        if low then e.warnLow=true; startWarn(e) else stopWarn(e) end
    end

    local function draw(e)
        if not (C.active and e.value and e.maximum) then return end
        moveFill(e,math.max(0,math.min(100,e.value/e.maximum*100))/100)
        if e.name=="Health" then healthMarks(e); lowHealth(e) end
        A:RenderAttributeNumber(e,e.value,e.maximum,C.vis.shield)
    end
    local function setPower(e,value,maxValue,effectiveMax)
        if type(value)~="number" then return end
        local maximum=core.ReachableMax(maxValue,effectiveMax)
        if type(maximum)~="number" or maximum<=0 then maximum=e.maximum end
        if not maximum or maximum<=0 then return end
        e.value,e.maximum=value,maximum
        if not e.drawFn then e.drawFn=function() draw(e) end end
        C.gate:Request(e.name,e.drawFn)
    end
    local function onPower(powerType,value,maxValue,effectiveMax)
        local e=C.byPower[powerType]
        if e then setPower(e,value,maxValue,effectiveMax) end
    end
    local function onVisual()
        local e=C.byName.Health
        if e and e.value then
            if not e.drawFn then e.drawFn=function() draw(e) end end
            C.gate:Request(e.name,e.drawFn)
        end
    end

    -- ESO's small bars: hang them under these bars, restore on release.
    local function hangSmall()
        for _,sm in ipairs(SMALL) do
            local c=_G[sm.control]
            local e=C.byName[sm.to]
            if c and e and c.GetAnchor and c.ClearAnchors and c.SetAnchor then
                if not sm.saved then sm.saved=core.SaveAnchors(c) end
                c:ClearAnchors(); c:SetAnchor(sm.point,e.bar,sm.rel,0,-1)
            end
        end
    end
    local function releaseSmall()
        -- playerattributebars.xml anchors these containers to ESO's Stamina,
        -- Magicka, and Health bars in both Keyboard and Gamepad modes;
        -- ApplyStyle() only styles their children, never re-anchors them.
        for _,sm in ipairs(SMALL) do
            local c=_G[sm.control]
            if c and sm.saved then
                core.RestoreAnchors(c,sm.saved)
            end
            sm.saved=nil
        end
    end

    local function baseHeight()
        local h=0
        for _,name in ipairs(core.FLAT_NATIVE) do
            local c=_G[name]
            if c and c.GetHeight then h=math.max(h,c:GetHeight() or 0) end
        end
        if h>0 then A.attrBaseHeight=h end
    end
    -- Position only (Edit Mode drags, HUD layout): cheap.
    function A:PositionCustomBars()
        if not C.active then if C.window then C.dirty=true end; return end
        local s=self.settings
        local geometry=self:AttributeGeometry()
        local rootScale=self.root.GetScale and self.root:GetScale() or 1
        C.window:SetScale(rootScale)
        C.window:ClearAnchors(); C.window:SetAnchor(TOPLEFT,self.root,TOPLEFT,0,0)
        local screenScale=s.attrScale*rootScale
        for _,e in pairs(C.byName) do
            local g=geometry[e.name]
            UI.reposition(e.anchor,C.window,g[1],g[2]); e.anchor:SetDimensions(g[3],g[4])
            UI.reposition(e.bar,e.anchor,0,0)
            e.bar:SetScale(s.attrScale)
            if e.screenScale~=screenScale then e.screenScale=screenScale; e.fillKey=nil end
        end
    end
    local function layout()
        local s=A.settings
        baseHeight()
        A:PositionCustomBars()
        local geometry=A:AttributeGeometry()
        local face=A:ResolveFont(s.attrFont=="HUD font" and s.fontFace or s.attrFont)
        for _,e in pairs(C.byName) do
            local g=geometry[e.name]
            local w,h=g[3]/s.attrScale,A.attrBaseHeight or 24
            e.width,e.height=w,h
            -- Stacked bars all drain right-to-left; side by side, magicka
            -- fills inward as on ESO's bars.
            e.reverse=e.name=="Magicka" and s.attrLayout~="Stacked"
            e.bar:SetDimensions(w,h); e.base:SetDimensions(w,h)
            e.track:SetDimensions(w-4,h-4)
            if e.noHealing then e.noHealing:SetDimensions(w-4,h-4) end
            if e.trauma then UI.reposition(e.trauma,e.bar,2,h-4) end
            if e.warn then e.warn:SetDimensions(w+10,h+10) end
            -- Hang the fill again and redraw at the new size from what is shown.
            e.screenScale=s.attrScale*(A.root.GetScale and A.root:GetScale() or 1)
            hangFill(e)
            local t=e.target or e.fraction
            detachMotion(e)
            e.shieldFraction,e.traumaFraction,e.tinted=nil,nil,nil
            if t then drawFill(e,t,true); e.target=t end
            A:LayoutAttributeNumber(e.number,e.bar,w,h,face)
            UI.hidden(e.number,false,true)
            e.displayKey,e.lastPercent,e.danger=nil,nil,nil
        end
        hangSmall()
        C.laidOut=true
    end
    local function refresh()
        core.ReadVisuals(C.vis)
        for _,e in pairs(C.byName) do
            local power=_G[e.power]
            if power and GetUnitPower then
                local v,m,eff=GetUnitPower("player",power)
                if type(v)=="number" then
                    local maximum=core.ReachableMax(m,eff)
                    if maximum and maximum>0 then e.value,e.maximum=v,maximum; draw(e) end
                end
            end
        end
    end

    -- active: Custom flat owns the screen. relayout: settings may have
    -- changed (false for scene-only refreshes, which never lay out again).
    local function syncCustom(active,relayout)
        active=not not active
        if not active then
            if relayout and C.window then C.dirty=true end
            if C.active then
                C.active=false
                core.SetVisualConsumer(nil)
                core.CancelGate()
                for _,e in pairs(C.byName) do stopMotion(e); if e.warn then stopWarn(e) end end
                C.window:SetHidden(true)
                releaseSmall()
                core.SetNative(false,core.FLAT_NATIVE)
            end
            return
        end
        build()
        C.gate=core.Gate(A)
        C.byPower={}
        for _,e in pairs(C.byName) do local p=_G[e.power]; if p then C.byPower[p]=e end end
        local starting=not C.active
        if starting then
            C.active=true
            core.SetNative(true,core.FLAT_NATIVE)
            core.SetVisualConsumer(onVisual)
        end
        if relayout or C.dirty or not C.laidOut then C.dirty=nil; layout()
        elseif starting then hangSmall() end
        C.window:SetHidden(false)
        if starting or relayout then refresh() end
        local s=A.settings
        A.attrStatus="Active: Custom "..s.attrLayout..(s.attrSplit and " (individual)" or " (grouped)")
    end
    function A:IsCustomBarsActive() return C.active==true end
    function A:RehangCustomSmallBars() if C.active then hangSmall() end end
    core.RegisterAdapter("custom",{Sync=syncCustom,OnPower=onPower})
end
