-- "Curved" attribute layout: health on a left arc, stamina (top) and magicka
-- (bottom) on a right arc, around the character. Own controls; ESO's native
-- resource bars are hidden while this layout is active and restored after.
-- Everything is event driven. The only timed work is one 33 ms update, run
-- only while the regeneration tick bar or the dodge fatigue arc is moving.
--
-- Texture geometry, in units of the 96 x 384 frame (see
-- dev/tools/make_curved_bars.py): a "(" arc from row 12 to 372, middle row
-- 192, bow 47, band 15 (+2 outline), flat end cuts. The right side mirrors
-- it; stamina is its own piece on rows 12..188, magicka on 196..372. The
-- regeneration tick bar touches the outer side of the lower stamina (rows
-- 124..188); the dodge fatigue / mount arc runs concentric further out on
-- the upper stamina (rows 12..100), its badge just under it. Every piece is
-- a full-frame texture; fills are cropped by row.
function ZeraUIAttachCurvedBars(A,UI)
    local core=ZeraUIAttributeCore
    local WM=WINDOW_MANAGER
    local FW,FH=96,384
    local TOP,MID,BOTTOM,SAG,XMID=12,192,372,47,18
    local BAND,OUTLINE=15,2
    local STAM_END,MAG_START=188,196          -- separate pieces, 4 units apart outside their outlines
    local HALF_SPAN=STAM_END-TOP              -- 176
    local THIN_OFF,THIN_END=17.5,100          -- dodge / mount arc: offset of its centre, lower end
    local THIN_SPAN=THIN_END-TOP              -- 88
    local REGEN_TOP=124                       -- tick bar rows 124..188
    local REGEN_SPAN=STAM_END-REGEN_TOP       -- 64
    local BADGE=16
    local EXTENT=20   -- widget half-width beyond XMID (regen bar, badge)
    local EARLY_MS=1750                       -- a regen-sized rise this soon after a tick is not one
    local HALF=(BOTTOM-TOP)/2
    local R=(HALF*HALF+SAG*SAG)/(2*SAG)
    local LOW_ON,LOW_OFF=25,28
    local DODGE,FATIGUE,EXPERT_EVASION=28549,69143,151113
    local TICK_MS=2000
    local NS="ZeraUICurved"

    -- Band centre x of the "(" arc at a row, in frame units; the thin arc is
    -- concentric, THIN_OFF further out (drawn with its middle at XMID too).
    local function arcX(row) return XMID+R-math.sqrt(R*R-(row-MID)^2) end
    local function thinX(row) return XMID+R-math.sqrt((R+THIN_OFF)^2-(row-MID)^2) end

    local C={bars={},vis=core.vis}
    local syncCurved
    A.curved=C
    local function tex(parent,file,level)
        local c=WM:CreateControl(nil,parent,CT_TEXTURE)
        if file then c:SetTexture(file) end
        c:SetDrawLayer(DL_CONTROLS); c:SetDrawLevel(level or 1)
        return c
    end
    local function label(parent,align,level)
        local c=UI.text(parent,14,80,20,0,0,level or 8)
        c:SetHorizontalAlignment(align)
        return c
    end
    local function build()
        if C.window then return end
        local w=WM:CreateTopLevelWindow("ZeraUICurvedBars")
        w:SetMouseEnabled(false); w:SetHidden(true)
        C.window=w
        for _,name in ipairs({"Health","Stamina","Magicka"}) do
            local b={name=name}
            local key=name:lower()
            -- Colours are in the textures (rim + interior, as in the reference).
            b.track=tex(w,UI.path.."curve_"..key.."_track.dds",1)
            b.fill=tex(w,UI.path.."curve_"..key.."_fill.dds",2)
            if name=="Health" then
                b.shield=tex(w,UI.path.."curve_shield_fill.dds",3)
                b.shield:SetColor(1,1,1,.95); b.shield:SetHidden(true)
                -- Trauma: the top of the health arc that must be healed first
                -- (ESO's trauma colour).
                b.trauma=tex(w,UI.path.."curve_shield_fill.dds",3)
                b.trauma:SetColor(.67,.11,.39,1); b.trauma:SetHidden(true)
            end
            local align=name=="Health" and TEXT_ALIGN_LEFT or TEXT_ALIGN_RIGHT
            b.percent=label(w,align,10); b.value=label(w,align,10)
            C.bars[name:lower()]=b
        end
        C.dodgeLine=tex(w,UI.path.."square.dds",5); C.dodgeLine:SetHidden(true)
        C.regenTrack=tex(w,UI.path.."curve_regen_track.dds",1); C.regenTrack:SetHidden(true)
        C.regenFill=tex(w,UI.path.."curve_regen_fill.dds",2); C.regenFill:SetHidden(true)
        C.thinTrack=tex(w,UI.path.."curve_dodge_track.dds",1); C.thinTrack:SetHidden(true)
        C.thinFill=tex(w,UI.path.."curve_dodge_fill.dds",2); C.thinFill:SetColor(.06,.5,.02,1); C.thinFill:SetHidden(true)
        C.badge=UI.panel(w,BADGE,BADGE,0,0); C.badge:SetHidden(true)
        C.badgeFrame=tex(C.badge,UI.path.."square.dds",6); C.badgeFrame:SetColor(.05,.05,.06,.95)
        C.badgeIcon=tex(C.badge,nil,7)
        C.badgeCount=label(C.badge,TEXT_ALIGN_RIGHT,9)
        -- Edit Mode moves the widget; a spacing/size change also relayouts.
        if A.BindWidgetDrag then A:BindWidgetDrag(w,"curved",function()
            local s=A.settings
            if C.active and C.layoutKey~=(s.curvedGap or 400)*1000+(s.curvedScale or 1) then syncCurved(true,true) else C.position() end
        end) end
    end

    -- Geometry --------------------------------------------------------------
    local function place(c,x,y,w,h,point,rel)
        c:ClearAnchors(); c:SetAnchor(point or TOPLEFT,C.window,rel or TOPLEFT,x,y)
        if w then c:SetDimensions(w,h) end
    end
    function C.position()
        if not C.window then return end
        local s=A.settings
        C.window:ClearAnchors()
        C.window:SetAnchor(CENTER,GuiRoot,CENTER,A:UIUnits(s.curvedX or 0),A:UIUnits(s.curvedY or 0))
    end
    function A:PositionCurvedBars()
        if not C.active then if C.window then C.dirty=true end; return end
        C.position()
    end
    function C.layout()
        local s=A.settings; local k=s.curvedScale or 1; local gap=s.curvedGap or 400
        -- The shield is drawn over the health fill; a lower alpha keeps the
        -- health visible under it. Set here, never per frame.
        C.bars.health.shield:SetColor(1,1,1,math.max(.1,math.min(1,s.curvedShieldAlpha or .95)))
        C.k=k; C.layoutKey=gap*1000+k
        C.window:SetScale(A:HUDCanvasScale())
        local W=(gap/2+XMID+EXTENT)*2*k
        C.window:SetDimensions(W,FH*k)
        C.position()
        local left=W/2-(gap/2+XMID)*k            -- left frame, "(" as drawn
        local right=W/2+(gap/2+XMID)*k-FW*k      -- right frame, mirrored
        C.left,C.right=left,right
        local h,st,mg=C.bars.health,C.bars.stamina,C.bars.magicka
        place(h.track,left,0,FW*k,FH*k); h.track:SetTextureCoords(0,1,0,1)
        place(h.fill,left,FH*k,nil,nil,BOTTOMLEFT); h.fill:SetWidth(FW*k)
        place(h.shield,left,FH*k,nil,nil,BOTTOMLEFT); h.shield:SetWidth(FW*k)
        h.trauma:SetWidth(FW*k)
        place(st.track,right,0,FW*k,FH*k); st.track:SetTextureCoords(1,0,0,1)
        place(st.fill,right,STAM_END*k,nil,nil,BOTTOMLEFT); st.fill:SetWidth(FW*k)
        place(mg.track,right,0,FW*k,FH*k); mg.track:SetTextureCoords(1,0,0,1)
        place(mg.fill,right,MAG_START*k); mg.fill:SetWidth(FW*k)
        place(C.thinTrack,right,0,FW*k,FH*k); C.thinTrack:SetTextureCoords(1,0,0,1)
        place(C.thinFill,right,THIN_END*k,nil,nil,BOTTOMLEFT); C.thinFill:SetWidth(FW*k)
        place(C.regenTrack,right,0,FW*k,FH*k); C.regenTrack:SetTextureCoords(1,0,0,1)
        place(C.regenFill,right,STAM_END*k,nil,nil,BOTTOMLEFT); C.regenFill:SetWidth(FW*k)
        -- Badge just under the outer arc's lower end, centred on it.
        local size=BADGE*k
        local row=THIN_END+2+BADGE/2
        place(C.badge,right+(FW-thinX(row))*k-size/2,(THIN_END+2)*k,size,size)
        C.badgeFrame:ClearAnchors(); C.badgeFrame:SetAnchor(TOPLEFT,C.badge,TOPLEFT,0,0); C.badgeFrame:SetDimensions(size,size)
        C.badgeIcon:ClearAnchors(); C.badgeIcon:SetAnchor(TOPLEFT,C.badge,TOPLEFT,2*k,2*k); C.badgeIcon:SetDimensions(size-4*k,size-4*k)
        C.badgeCount:ClearAnchors(); C.badgeCount:SetAnchor(BOTTOMRIGHT,C.badge,BOTTOMRIGHT,2*k,3*k); C.badgeCount:SetDimensions(size,size)
        C.dodgeLine:SetDimensions((BAND+2*OUTLINE)*k,2*k)
        -- Texts on the inner side of the arcs.
        local face=A:ResolveFont(s.attrFont=="HUD font" and s.fontFace or s.attrFont)
        local style=s.attrOutline or "thick-outline"
        -- Fonts are resized with the arcs (never stretched), and kept readable.
        local ps=math.max(8,math.floor((s.curvedPercentSize or 15)*k+.5))
        local vs=math.max(8,math.floor((s.curvedValueSize or 11)*k+.5))
        local hx=left+(XMID+BAND/2+OUTLINE+10)*k
        local rx2=right+FW*k-(XMID+BAND/2+OUTLINE+10)*k
        local function text(c,x,y,size,align)
            A:ApplyNativeFont(c,face,size,style,"attribute")
            c:SetDimensions(120*k,size*1.5)
            c:ClearAnchors()
            c:SetAnchor(align==TEXT_ALIGN_LEFT and LEFT or RIGHT,C.window,TOPLEFT,x,y)
        end
        text(h.percent,hx,(MID-10)*k,ps,TEXT_ALIGN_LEFT)
        text(h.value,hx,(MID+8)*k,vs,TEXT_ALIGN_LEFT)
        text(st.percent,rx2,(MID-32)*k,ps,TEXT_ALIGN_RIGHT)
        text(st.value,rx2,(MID-14)*k,vs,TEXT_ALIGN_RIGHT)
        text(mg.value,rx2,(MID+14)*k,vs,TEXT_ALIGN_RIGHT)
        text(mg.percent,rx2,(MID+32)*k,ps,TEXT_ALIGN_RIGHT)
        for _,b in pairs(C.bars) do b.fillKey,b.shieldKey,b.shownValue,b.shownPercent=nil,nil,nil,nil end
        h.traumaKey,h.tinted=nil,nil
        C.dodgeKey,C.thinKey,C.regenKey=nil,nil,nil
        C.laidOut=true
    end

    -- Values ----------------------------------------------------------------
    local function setText(c,text)
        if c.vabCurvedText~=text then c.vabCurvedText=text; UI.setText(c,text) end
    end
    -- Visible rows of the fill: health and stamina grow upward to their top
    -- row, magicka downward. Full shows the whole tip.
    local function fillRows(name,frac)
        if name=="Health" then return frac>=1 and 0 or BOTTOM-frac*(BOTTOM-TOP),FH end
        if name=="Stamina" then return frac>=1 and 0 or STAM_END-frac*HALF_SPAN,STAM_END end
        if name=="Regen" then return STAM_END-frac*REGEN_SPAN,STAM_END end
        if name=="Thin" then return frac>=1 and 0 or THIN_END-frac*THIN_SPAN,THIN_END end
        return MAG_START,frac>=1 and FH or MAG_START+frac*HALF_SPAN
    end
    -- Redraw only when the visible height changes by half a unit or more.
    local function drawFill(c,name,frac,b,keyName)
        local k=C.k
        local top,bottom=fillRows(name,frac)
        local key=frac<=0 and -1 or math.floor((bottom-top)*k*2+.5)
        if b[keyName]==key then return end
        b[keyName]=key
        if frac<=0 then c:SetHidden(true); return end
        c:SetHeight((bottom-top)*k)
        local mirrored=name~="Health"
        c:SetTextureCoords(mirrored and 1 or 0,mirrored and 0 or 1,top/FH,bottom/FH)
        c:SetHidden(false)
    end
    local function blink(c,on)
        if on then
            if not c.vabBlink and CreateSimpleAnimation and ANIMATION_ALPHA then
                local anim,timeline=CreateSimpleAnimation(ANIMATION_ALPHA,c)
                anim:SetAlphaValues(1,.35); anim:SetDuration(450)
                timeline:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG,LOOP_INDEFINITELY)
                c.vabBlink=timeline
            end
            if c.vabBlink and not c.vabBlink:IsPlaying() then c.vabBlink:PlayFromStart() end
        elseif c.vabBlink and c.vabBlink:IsPlaying() then
            c.vabBlink:Stop(); c:SetAlpha(1)
        end
    end
    local function paint(c,red)
        if c.vabCurvedRed==red then return end
        c.vabCurvedRed=red
        if red then UI.color(c,1,.19,.19,1) else UI.color(c,1,1,1,1) end
    end
    local function shortText(v) return core.FormatValue(v,"Short",v) end
    local function drawBar(b)
        local value,maximum=b.cur,b.max
        local s=A.settings
        local frac=math.max(0,math.min(1,value/maximum))
        drawFill(b.fill,b.name,frac,b,"fillKey")
        local pct=frac*100
        if s.attrLowWarning~=false then
            if b.name=="Health" and (value<=0 or (IsUnitDead and IsUnitDead("player"))) then b.low=false
            elseif pct<=LOW_ON then b.low=true elseif pct>=LOW_OFF then b.low=false end
        else b.low=false end
        -- Build a new string only when what is shown changes: "38.5k" stays
        -- the same across 100 points of health, so most updates allocate
        -- nothing.
        local n=math.max(0,math.floor(value+.5))
        local format=s.attrFormat or "Short"
        local shown=core.DisplayKey(n,format)
        local shield=b.name=="Health" and s.attrShieldValue~=false and math.floor((C.shield or 0)+.5) or 0
        local shieldShown=core.ShieldKey(shield)
        local maxShown=format=="Full / Max" and math.floor(maximum+.5) or 0
        if b.shownValue~=shown or b.shownShield~=shieldShown or b.shownMax~=maxShown or b.shownFormat~=format then
            b.shownValue,b.shownShield,b.shownMax,b.shownFormat=shown,shieldShown,maxShown,format
            local text=core.FormatValue(n,format,math.floor(maximum+.5))
            if shield>0 then text=text.." |c4DA6FF("..shortText(shield)..")|r" end
            setText(b.value,text)
        end
        local percent=s.attrPercent~=false and math.floor(pct+.5) or -1
        if b.shownPercent~=percent then
            b.shownPercent=percent
            setText(b.percent,percent>=0 and tostring(percent).."%" or "")
        end
        paint(b.percent,b.low)
        if b.name=="Health" then
            paint(b.value,b.low); blink(b.fill,b.low)
        else
            blink(b.percent,b.low)
        end
    end
    -- The marker's anchor points and parent never change. Keep the first
    -- anchor and update only its exact offsets (the draw keys stay rounded).
    local function moveMarker(c,point,x,y)
        if not c.vabCurvedAnchored or not c.SetAnchorOffsets then
            c:ClearAnchors(); c:SetAnchor(point,C.window,TOPLEFT,x,y)
            c.vabCurvedAnchored=true
        elseif c.vabCurvedAnchorX~=x or c.vabCurvedAnchorY~=y then
            c:SetAnchorOffsets(x,y)
        end
        c.vabCurvedAnchorX,c.vabCurvedAnchorY=x,y
    end
    -- Trauma from health minus trauma up to health. The arc fills to full
    -- health and draws the shield separately from the bottom, so there is no
    -- shield overflow to take off (unlike ESO's bar). No healing tints the
    -- health fill. All three health overlays run inside the health gate.
    local function drawTrauma()
        local h=C.bars.health
        local t=A.settings.attrTrauma~=false and C.vis.trauma or 0
        if not (t>0 and h.cur and h.max and h.max>0 and h.cur>0) then
            if h.traumaKey~=-1 then h.traumaKey=-1; h.traumaShown=false; h.trauma:SetHidden(true) end
            return
        end
        local low=math.max(0,h.cur-t)
        if h.cur<=low then
            if h.traumaKey~=-1 then h.traumaKey=-1; h.traumaShown=false; h.trauma:SetHidden(true) end
            return
        end
        local k=C.k
        local f2,f1=math.min(1,h.cur/h.max),math.min(1,low/h.max)
        local top=f2>=1 and 0 or BOTTOM-f2*(BOTTOM-TOP)
        local bottom=BOTTOM-f1*(BOTTOM-TOP)
        local key=math.floor(top*k*2+.5)*100000+math.floor(bottom*k*2+.5)
        if h.traumaKey==key then return end
        h.traumaKey=key
        moveMarker(h.trauma,BOTTOMLEFT,C.left,bottom*k)
        h.trauma:SetHeight((bottom-top)*k)
        h.trauma:SetTextureCoords(0,1,top/FH,bottom/FH)
        if not h.traumaShown then h.traumaShown=true; h.trauma:SetHidden(false) end
    end
    local function drawNoHealing()
        local h=C.bars.health
        local on=A.settings.attrNoHealing~=false and C.vis.noHealing or false
        if h.tinted==on then return end
        h.tinted=on
        if on then h.fill:SetColor(.55,.30,.30,1) else h.fill:SetColor(1,1,1,1) end
    end
    local function drawHealthMarks(h)
        drawNoHealing()
        if h.max and h.max>0 then
            drawFill(h.shield,"Health",math.min(1,(C.shield or 0)/h.max),h,"shieldKey")
        end
        drawTrauma()
    end
    -- Values are kept on every event; drawing goes through the shared
    -- update-rate gate ("Every change" draws at once) so health fill, shield
    -- arc, trauma, no-healing tint, and text always stay synchronized.
    local function updateBar(b,value,maximum)
        if not maximum or maximum<=0 then return end
        b.cur,b.max=value,maximum
        if not b.drawFn then
            b.drawFn=function() drawBar(b); if b.name=="Health" then drawHealthMarks(b) end end
        end
        C.gate:Request(b.name,b.drawFn)
    end
    local function updateShield(readAll)
        local h=C.bars.health
        if readAll then core.ReadVisuals(C.vis) end
        C.shield=math.max(0,C.vis.shield)
        if h.cur and h.max and h.max>0 then
            updateBar(h,h.cur,h.max)
        else
            drawNoHealing()
        end
    end
    local function onVisual()
        updateShield(false)
    end

    -- C: stamina left after a dodge (dark), or the cost itself (red) -------
    -- GetAbilityCost is expensive (~54 us in a trial profile) and the cost
    -- only changes with dodge fatigue, stats or Expert Evasion, which pass
    -- fresh=true. Stamina updates reuse it, refreshed once a second.
    local COST_REFRESH_MS=1000
    local function updateDodge(fresh)
        local st=C.bars.stamina
        local now=GetFrameTimeMilliseconds()
        if fresh or not C.dodgeCostAt or now-C.dodgeCostAt>=COST_REFRESH_MS then
            C.dodgeCost=GetAbilityCost and (GetAbilityCost(DODGE,COMBAT_MECHANIC_FLAGS_STAMINA,nil,"player") or GetAbilityCost(DODGE)) or 0
            C.dodgeCostAt=now
        end
        local cost=C.dodgeCost
        if not st.max or st.max<=0 or not cost or cost<=0 then
            if C.dodgeKey~=-1 then C.dodgeKey=-1; C.dodgeShown=false; C.dodgeLine:SetHidden(true) end
            return
        end
        local short=st.cur<cost
        local frac=math.min(1,(short and cost or st.cur-cost)/st.max)
        local row=STAM_END-frac*HALF_SPAN
        local key=math.floor(row*C.k*2+.5)*2+(short and 1 or 0)
        if C.dodgeKey==key then return end
        C.dodgeKey=key
        local x=C.right+(FW-arcX(row))*C.k
        moveMarker(C.dodgeLine,CENTER,x,row*C.k)
        if C.dodgeShort~=short then
            C.dodgeShort=short
            if short then C.dodgeLine:SetColor(1,.15,.1,1) else C.dodgeLine:SetColor(.02,.02,.02,.95) end
        end
        if not C.dodgeShown then C.dodgeShown=true; C.dodgeLine:SetHidden(false) end
    end

    -- Animation: regeneration bar and fatigue arc --------------------------
    local animate
    -- Tick bar colours: no regeneration (block,
    -- sprint, sneak...) is red, turning yellow then orange late in the cycle
    -- (release now to catch the tick); dodge fatigue runs yellow at 1 stack
    -- towards red at 5; otherwise green.
    local GREEN,RED,PRE1,PRE2={.42,.86,.38,1},{.95,.18,.12,1},{1,1,0,1},{1,.6,0,1}
    local FATIGUE_COLORS={}
    for i=1,5 do local t=(i-1)/4; FATIGUE_COLORS[i]={1,1-.9*t,0,1} end
    local function regenColor(regen,frac)
        if (regen or 0)<=0 then return frac>.85 and PRE2 or frac>.75 and PRE1 or RED end
        local f=C.fatigue
        if f then return FATIGUE_COLORS[math.max(1,math.min(5,f.stacks or 1))] end
        return GREEN
    end
    local readRegen
    local function needsLoop()
        local st=C.bars.stamina
        local regen=C.lastTick and st.max and st.cur<st.max
        return regen or (C.fatigue~=nil and not C.mounted)
    end
    local function syncLoop()
        local want=C.active and needsLoop() or false
        if want==C.looping then return end
        C.looping=want
        if want then EVENT_MANAGER:RegisterForUpdate(NS.."Anim",33,animate)
        else EVENT_MANAGER:UnregisterForUpdate(NS.."Anim") end
    end
    local function showRegen(on)
        if C.regenShown==on then return end
        C.regenShown=on; C.regenTrack:SetHidden(not on)
        if not on then C.regenFill:SetHidden(true) end
        C.regenKey=nil
    end
    local function drawThin(frac)
        local on=frac~=nil
        if C.thinOn~=on then C.thinOn=on; C.thinTrack:SetHidden(not on); C.badge:SetHidden(not on) end
        if not on then C.thinKey=nil; C.thinFill:SetHidden(true); return end
        drawFill(C.thinFill,"Thin",frac,C,"thinKey")
    end
    local function setBadge(icon,count)
        if C.badgeIcon.vabIcon~=icon then C.badgeIcon.vabIcon=icon; C.badgeIcon:SetTexture(icon or "") end
        local text=count and count>0 and tostring(count) or ""
        setText(C.badgeCount,text)
        local hide=text==""
        if C.badgeHidden~=hide then C.badgeHidden=hide; C.badgeCount:SetHidden(hide) end
    end
    local function resolveMountIcon()
        if GetActiveCollectibleByType and COLLECTIBLE_CATEGORY_TYPE_MOUNT then
            local id=GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_MOUNT,GAMEPLAY_ACTOR_CATEGORY_PLAYER)
            if id and id~=0 and GetCollectibleIcon then
                local icon=GetCollectibleIcon(id)
                if icon and icon~="" then return icon end
            end
        end
        return "/esoui/art/mounts/tabicon_mounts_up.dds"
    end
    local function updateThin(now)
        if C.mounted then
            local m=C.mount
            setBadge(C.mountIcon or resolveMountIcon(),0)
            drawThin(m and m[2]>0 and math.max(0,math.min(1,m[1]/m[2])) or 1)
            return
        end
        local f=C.fatigue
        if f then
            local left=f.finish-now
            if left<=0 then C.fatigue=nil
            else
                if C.dodgeIcon==nil then C.dodgeIcon=(GetAbilityIcon and GetAbilityIcon(DODGE)) or false end
                setBadge(C.dodgeIcon or nil,f.stacks)
                drawThin(math.min(1,left/f.span))
                return
            end
        end
        drawThin(nil)
    end
    animate=function()
        if not C.active then syncLoop(); return end
        local now=GetFrameTimeMilliseconds()
        local st=C.bars.stamina
        if C.lastTick and st.max and st.cur<st.max then
            local elapsed=now-C.lastTick
            -- Keep the 2 s rhythm through a tick the deltas did not show;
            -- the next regen-sized rise is then accepted whenever it comes.
            if elapsed>=TICK_MS+10 then
                C.lastTick=C.lastTick+math.floor(elapsed/TICK_MS)*TICK_MS; elapsed=now-C.lastTick
                C.tickTrusted=false
            end
            local frac=math.min(1,elapsed/TICK_MS)
            -- The regen stat is read every frame: blocking changes it with
            -- no event, and the colour must follow at once both ways.
            local color=regenColor(readRegen(),frac)
            if C.regenColor~=color then C.regenColor=color; C.regenFill:SetColor(color[1],color[2],color[3],color[4]) end
            drawFill(C.regenFill,"Regen",math.max(.002,frac),C,"regenKey")
            showRegen(true)
        else showRegen(false) end
        if C.fatigue and not C.mounted then updateThin(now) end
        syncLoop()
    end
    readRegen=function()
        C.regen=GetPlayerStat and GetPlayerStat(C.inCombat and STAT_STAMINA_REGEN_COMBAT or STAT_STAMINA_REGEN_IDLE,STAT_BONUS_OPTION_APPLY_BONUS) or 0
        return C.regen
    end
    local function refreshRegen() C.regenKey=nil; return readRegen() end
    -- Tick detection: a rise equal to the live regen stat is a
    -- tick, unless it comes within 1750 ms of a trusted tick (a resource
    -- return of the same size). The stat is read on each rise, since regen
    -- buffs do not always raise EVENT_STATS_UPDATED.
    local function observeRise(delta)
        if delta<=0 or delta~=refreshRegen() then return end
        local now=GetFrameTimeMilliseconds()
        if C.lastTick and C.tickTrusted and now-C.lastTick<EARLY_MS then return end
        C.lastTick=now; C.tickTrusted=true; C.regenKey=nil
    end

    -- Events ----------------------------------------------------------------
    local function onPower(powerType,value,maximum,effectiveMax)
        local maxValue=core.ReachableMax(maximum,effectiveMax) or maximum
        if powerType==COMBAT_MECHANIC_FLAGS_HEALTH then
            updateBar(C.bars.health,value,maxValue)
        elseif powerType==COMBAT_MECHANIC_FLAGS_STAMINA then
            local st=C.bars.stamina
            local before=st.cur
            updateBar(st,value,maxValue)
            if before then observeRise(value-before) end
            updateDodge()
            if value>=maxValue then showRegen(false) end
            if C.looping then syncLoop() else animate() end
        elseif powerType==COMBAT_MECHANIC_FLAGS_MAGICKA then
            updateBar(C.bars.magicka,value,maxValue)
        elseif powerType==COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA then
            local m=C.mount
            if m then m[1],m[2]=value,maxValue else C.mount={value,maxValue} end
            if C.mounted then updateThin(GetFrameTimeMilliseconds()) end
        end
    end
    local function onFatigue(_,change,_,_,unitTag,beginTime,endTime,stacks,_,_,_,_,_,_,_,abilityId)
        if unitTag~="player" or abilityId~=FATIGUE then return end
        if change==EFFECT_RESULT_FADED then C.fatigue=nil
        else
            local span=math.max(1,(endTime-beginTime)*1000)
            C.fatigue={finish=endTime*1000,span=span,stacks=stacks or 0}
        end
        updateDodge(true)
        updateThin(GetFrameTimeMilliseconds()); syncLoop()
    end
    local function onMounted()
        C.mounted=IsMounted and IsMounted() or false
        if C.mounted then
            local v,m=GetUnitPower("player",COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA)
            local cur=C.mount
            if cur then cur[1],cur[2]=v or 0,m or 0 else C.mount={v or 0,m or 0} end
            C.mountIcon=resolveMountIcon()
        end
        C.thinKey=nil
        updateThin(GetFrameTimeMilliseconds()); syncLoop()
    end
    local function onStats() refreshRegen(); updateDodge(true); animate() end
    local function onCombat(_,inCombat) C.inCombat=inCombat and true or false; onStats() end
    local function register()
        local E=EVENT_MANAGER
        C.inCombat=IsUnitInCombat and IsUnitInCombat("player") or false
        E:RegisterForEvent(NS.."Fatigue",EVENT_EFFECT_CHANGED,onFatigue)
        E:AddFilterForEvent(NS.."Fatigue",EVENT_EFFECT_CHANGED,REGISTER_FILTER_ABILITY_ID,FATIGUE,REGISTER_FILTER_UNIT_TAG,"player")
        E:RegisterForEvent(NS.."Evasion",EVENT_EFFECT_CHANGED,function() updateDodge(true) end)
        E:AddFilterForEvent(NS.."Evasion",EVENT_EFFECT_CHANGED,REGISTER_FILTER_ABILITY_ID,EXPERT_EVASION,REGISTER_FILTER_UNIT_TAG,"player")
        E:RegisterForEvent(NS.."Stats",EVENT_STATS_UPDATED,onStats)
        E:AddFilterForEvent(NS.."Stats",EVENT_STATS_UPDATED,REGISTER_FILTER_UNIT_TAG,"player")
        E:RegisterForEvent(NS.."Combat",EVENT_PLAYER_COMBAT_STATE,onCombat)
        E:RegisterForEvent(NS.."Mount",EVENT_MOUNTED_STATE_CHANGED,onMounted)
        if EVENT_ACTIVE_MOUNT_CHANGED then
            E:RegisterForEvent(NS.."ActiveMount",EVENT_ACTIVE_MOUNT_CHANGED,function()
                C.mountIcon=resolveMountIcon()
                if C.mounted then updateThin(GetFrameTimeMilliseconds()) end
            end)
        end
    end
    local function unregister()
        local E=EVENT_MANAGER
        E:UnregisterForEvent(NS.."Fatigue",EVENT_EFFECT_CHANGED)
        E:UnregisterForEvent(NS.."Evasion",EVENT_EFFECT_CHANGED)
        E:UnregisterForEvent(NS.."Stats",EVENT_STATS_UPDATED)
        E:UnregisterForEvent(NS.."Combat",EVENT_PLAYER_COMBAT_STATE)
        E:UnregisterForEvent(NS.."Mount",EVENT_MOUNTED_STATE_CHANGED)
        if EVENT_ACTIVE_MOUNT_CHANGED then E:UnregisterForEvent(NS.."ActiveMount",EVENT_ACTIVE_MOUNT_CHANGED) end
    end
    -- A dodge fatigue already running at reload.
    local function recoverFatigue()
        C.fatigue=nil
        for i=1,(GetNumBuffs and GetNumBuffs("player") or 0) do
            local _,beginTime,endTime,_,stacks,_,_,_,_,_,abilityId=GetUnitBuffInfo("player",i)
            if abilityId==FATIGUE and endTime and endTime>beginTime then
                C.fatigue={finish=endTime*1000,span=(endTime-beginTime)*1000,stacks=stacks or 0}
            end
        end
    end

    -- ESO's bars are hidden and their power handler paused (AttributeCore).
    syncCurved=function(active,relayout)
        active=not not active
        if not active then
            if relayout and C.window then C.dirty=true end
            if C.active then
                C.active=false
                unregister()
                core.SetVisualConsumer(nil)
                core.CancelGate()
                syncLoop()
                for _,b in pairs(C.bars) do blink(b.fill,false); blink(b.percent,false) end
                C.window:SetHidden(true)
                core.SetNative(false)
            end
            return
        end
        build()
        C.gate=core.Gate(A)
        local starting=not C.active
        if starting then
            C.active=true
            core.SetNative(true)
            core.SetVisualConsumer(onVisual)
            register()
            C.lastTick=nil; C.tickTrusted=nil; C.regenShown=nil; C.regenColor=nil
            refreshRegen(); recoverFatigue()
            C.mounted=IsMounted and IsMounted() or false
        end
        local needLayout=relayout or C.dirty or not C.laidOut
        if needLayout then C.dirty=nil; C.layout() end
        if starting or needLayout then
            core.ReadVisuals(C.vis)
            C.shield=math.max(0,C.vis.shield)
            for name,b in pairs(C.bars) do
                b.cur=nil
                local kind=name=="health" and COMBAT_MECHANIC_FLAGS_HEALTH or name=="stamina" and COMBAT_MECHANIC_FLAGS_STAMINA or COMBAT_MECHANIC_FLAGS_MAGICKA
                local v,m,e=GetUnitPower("player",kind)
                local maxValue=core.ReachableMax(m,e) or m
                if v and maxValue and maxValue>0 then
                    b.cur,b.max=v,maxValue
                    drawBar(b)
                    if b.name=="Health" then drawHealthMarks(b) end
                end
            end
            updateDodge(true); onMounted()
            animate()
        end
        C.window:SetHidden(false)
        A.attrStatus="Active: Curved"
    end
    function A:SetCurvedGap(value)
        local s=self.settings
        s.curvedGap=math.max(250,math.min(800,math.floor(value+.5)))
        if C.active then syncCurved(true,true) end
    end
    core.RegisterAdapter("curved",{Sync=syncCurved,OnPower=onPower})
end
