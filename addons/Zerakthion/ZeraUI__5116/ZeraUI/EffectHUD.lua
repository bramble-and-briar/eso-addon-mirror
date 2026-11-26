-- Shared, event-driven player/reticle effect HUD and Off Balance widget.
-- Snapshots are authoritative: never carry a debuff from one target to another.
local H={}; H.__index=H
ZeraUIEffectHUD=H
local PREFIX="ZeraUIEffects"
local SELF,TARGET="player","reticleover"
local OB_ICON="/esoui/art/icons/ability_debuff_offbalance.dds"
local IMMUNE_ICON="/esoui/art/icons/achievement_030.dds"
local MAX_ICONS=120 -- protect the control pool from unbounded effects
local PREWARM_ICONS=24 -- minimum per enabled grid, created gradually outside combat
-- Spare slots beyond the largest count a grid has shown. A fight that adds a
-- few more effects than before then needs no control creation in combat.
local POOL_HEADROOM=8
local PREWARM_PER_TICK=2 -- out of combat only (see H:Update)
-- The largest icon count each grid has actually shown is remembered in
-- SavedVariables, and that many hidden slots are prepared outside combat on
-- later sessions. A previously observed grid can reach MAX_ICONS: capping
-- its hint below that would repeat expensive first-display allocations after
-- every reload. Keep the cold default small and the learned hint bounded.
local POOL_HINT_LIMIT=MAX_ICONS
local BALANCE_CACHE_LIMIT=512
local function clock() return GetGameTimeMilliseconds and GetGameTimeMilliseconds() or GetFrameTimeMilliseconds() end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function number(v,fallback,lo,hi) return clamp(tonumber(v) or fallback,lo,hi) end
local function hidden(c,v)
    local h
    if c.IsControlHidden then h=c:IsControlHidden() else h=c:IsHidden() end
    if h~=v then c:SetHidden(v) end
end
local function clean(n) return type(n)=="string" and n:gsub("%^.*$", ""):lower() or "" end
local EMPTY={}
local GOLD={.91,.77,.42}
-- Mages Guild healing/shield penalty is mislabeled as BUFF by ESO.
-- 48131 verified in the live client; 48136 is the Spell Symmetry penalty.
local HEALING_PENALTY={[48131]=true,[48136]=true}
local function remaining(r,now) return r.finish>0 and math.max(0,r.finish-now) or 0 end
-- Use the actual remaining time. A reported duration is not necessarily a
-- reliable ceiling for the expiry timestamp, so do not suppress the excess.
local function timerBucket(ms,decimal)
    if ms<=0 then return "",0 end
    local s=ms/1000
    -- Seconds-to-milliseconds conversion can leave a boundary a few floating
    -- point bits high. Ten nanoseconds is far below ESO's timer resolution;
    -- this affects display rounding only, never the actual expiry timestamp.
    local rounded=ms>0.00001 and ms-0.00001 or ms
    if s>=3600 then return "h",math.ceil(rounded/3600000) end
    if s>=60 then return "m",math.ceil(rounded/60000) end
    if s<decimal then return "d",math.ceil(rounded/100) end
    return "s",math.ceil(rounded/1000)
end
-- Return the exact next countdown boundary, rather than refreshing every
-- active timer on every 100 ms HUD tick. The caller also schedules fill,
-- warning and pulse boundaries independently.
local function nextTimerChange(left,kind,bucket,decimal)
    if left<=0 or kind=="" or kind=="ready" then return math.huge end
    if kind=="d" then return math.max(1,left-(bucket-1)*100) end
    local step=kind=="h" and 3600000 or kind=="m" and 60000 or 1000
    -- Unit changes just BELOW 1h, 1m and the configured decimal cutoff,
    -- even if the ceil-rounded bucket does not change at that boundary.
    local cutoff=kind=="h" and 3600000 or kind=="m" and 60000 or decimal*1000
    if left<=cutoff then return 1 end
    return math.max(1,left-(bucket-1)*step)
end
local function sameRecord(t,r,mode)
    return t.effectID==r.id and t.effectSlot==r.slot and
        t.effectName==r.name and
        t.effectIcon==r.icon and t.effectStart==r.start and
        t.effectFinish==r.finish and t.effectStacks==r.stacks and
        t.effectDebuff==r.debuff and t.effectEstimated==(r.estimated and true or false) and
        t.effectMode==mode
end
-- Effect refreshes commonly change only start/end time. The control's
-- identity and static metadata remain valid, including tooltip and stack.
-- Configuration invalidation already clears nextPaintAt; preview and a
-- newly assigned/recycled control must still use the full paint path.
local function sameAppearance(t,r,g)
    return not t.demoRecord and t.effectTag==g.tag and t.effectMode==nil and
        t.effectID==r.id and t.effectSlot==r.slot and t.effectName==r.name and
        t.effectIcon==r.icon and t.effectStacks==r.stacks and t.effectDebuff==r.debuff
end
local function sortDuration(a,b)
    if a.finish==b.finish then return a.order<b.order end
    if a.finish==0 then return false end
    if b.finish==0 then return true end
    return a.finish<b.finish
end
local function finishBucket(bucket,visual)
    local count=bucket.scanCount
    local order=visual.sort=="Shortest first" and "Shortest first" or "Game order"
    local rebuild=bucket.scanInvalid or bucket.previousScanCount~=count or bucket.previousSort~=order or
        (order=="Shortest first" and bucket.scanChanged)
    if rebuild then
        -- Scratch records are populated in game order. Preserve the previous
        -- sorted list without rewriting it when a unit scan changes nothing.
        local list=bucket.records
        for i=1,count do list[i]=bucket.scratch[i] end
        for i=count+1,#list do list[i]=nil end
        if order=="Shortest first" and count>1 then
            local sorted=true
            for i=2,count do
                if sortDuration(list[i],list[i-1]) then sorted=false; break end
            end
            if not sorted then table.sort(list,sortDuration) end
        end
    end
    if rebuild or bucket.scanChanged then
        -- Game-order records already point at the reusable scan rows. A
        -- clock/stack change alone needs neither list writes nor remapping.
        if rebuild or bucket.scanStructureChanged then bucket.structureDirty=true
        elseif not bucket.recordsChanged then bucket.structureDirty=false end
        bucket.recordsChanged=true
    end
    bucket.previousScanCount=count; bucket.previousSort=order; bucket.scanInvalid=nil
end
function H.New(owner,ui)
    local h=setmetatable({owner=owner,ui=ui,groups={},listeners={},native={},nativePaused={},visualGeneration=1},H)
    h.groups[SELF]={tag=SELF,prefix="effectSelf",records={},pool={},scratch={},dirty=true}
    h.groups[TARGET]={tag=TARGET,prefix="effectTarget",records={},pool={},scratch={},dirty=true}
    for _,g in pairs(h.groups) do
        g.debuffGroup={tag=g.tag,prefix=g.prefix.."Debuff",records={},pool={},scratch={},isDebuff=true}
    end
    h.ob={pool={},prefix="offBalance"}
    h.warmupGroups={h.groups[SELF],h.groups[SELF].debuffGroup,h.groups[TARGET],h.groups[TARGET].debuffGroup,h.ob}
    h.warmupIndex=1
    h.balanceCache={}; h.balanceCacheSize=0
    local function name(id,fallback)
        local n=GetAbilityName and GetAbilityName(id)
        return type(n)=="string" and n~="" and clean(n) or fallback
    end
    h.obName=name(62988,"off balance"); h.immuneName=name(134599,"off balance immunity")
    h.exchangeNames={equilibrium=true,["spell symmetry"]=true,balance=true}
    h.exchangeNames[name(31642,"equilibrium")]=true
    h.exchangeNames[name(40445,"spell symmetry")]=true
    h.exchangeNames[name(40441,"balance")]=true
    h:RefreshListFlags()
    return h
end
function H:IsDebuff(kind,id,name,duration,target)
    if BUFF_EFFECT_TYPE_DEBUFF~=nil and kind==BUFF_EFFECT_TYPE_DEBUFF then return true end
    if target then return false end
    if HEALING_PENALTY[id] then return true end
    -- Guard the name fallback by the actual four-second effect duration,
    -- not time remaining. Never recolor the five-second cost reduction
    -- or thirty-second Major Resolve provided by the morphs.
    return duration>=3500 and duration<=4500 and self.exchangeNames[clean(name)]==true
end
function H:BalanceKind(id,name)
    if id==39077 or id==62988 then return 1 end
    if id==134599 then return 2 end
    -- Names can be localized or vary for the same ID. Cache only an exact
    -- ID/name pair and keep the cache bounded; unknown names still fall back.
    local cacheable=type(id)=="number" and id>0 and type(name)=="string" and name~=""
    local cached=cacheable and self.balanceCache[id]
    if cached and cached.name==name then
        if cached.kind then return cached.kind end
        return
    end
    local n=clean(name)
    local kind
    if n~="" and (n==self.immuneName or n=="off balance immunity") then kind=2
    elseif n~="" and (n==self.obName or n=="off balance") then kind=1 end
    if cacheable then
        if not cached then
            if self.balanceCacheSize>=BALANCE_CACHE_LIMIT then self.balanceCache={}; self.balanceCacheSize=0 end
            self.balanceCacheSize=self.balanceCacheSize+1
        end
        self.balanceCache[id]={name=name,kind=kind or false}
    end
    if kind then return kind end
end
function H:Window(group)
    if group.window then return group.window end
    local w=WINDOW_MANAGER:CreateTopLevelWindow(PREFIX..group.prefix)
    w:SetMouseEnabled(false); w:SetMovable(false); w:SetDrawTier(DT_HIGH); w:SetHidden(true)
    w:SetScale(self.owner:HUDCanvasScale())
    group.window=w
    if self.owner.BindWidgetDrag then self.owner:BindWidgetDrag(w,group.prefix,function() self:Position(group) end) end
    return w
end
-- Allocate a native outline once per pooled slot that needs it. Ordinary buff
-- slots need no extra controls, and reusing a slot never recreates its outline.
function H:Signal(t,offBalance)
    if t.signal or not CT_BACKDROP then return end
    t.signal=self.ui.panel(t.p,64,64,0,0); t.edges={}
    local function edge(x,y,w,h)
        local e=WINDOW_MANAGER:CreateControl(nil,t.signal,CT_BACKDROP)
        e:SetDimensions(w,h); e:SetAnchor(TOPLEFT,t.signal,TOPLEFT,x,y)
        e:SetDrawLayer(DL_CONTROLS); e:SetDrawLevel(7)
        e:SetEdgeColor(0,0,0,0); t.edges[#t.edges+1]=e
    end
    if offBalance then
        edge(-3,-3,70,4); edge(-3,63,70,4); edge(-3,1,4,62); edge(63,1,4,62)
        edge(1,1,62,2); edge(1,61,62,2); edge(1,3,2,58); edge(61,3,2,58)
    else
        -- Stay inside the slot so adjacent effects never overlap at zero gap.
        edge(0,0,64,4); edge(0,60,64,4); edge(0,4,4,56); edge(60,4,4,56)
    end
    t.signal:SetHidden(true)
end
function H:Slot(g,i)
    if g.pool[i] then return g.pool[i] end
    local u=self.ui; local p=u.panel(self:Window(g),64,64,0,0)
    local t={p=p,base=u.texture(p,u.path.."square.dds",64,64,0,0,0),
        icon=u.texture(p,nil,56,56,4,4,1),fill=u.texture(p,u.path.."fill.dds",56,56,4,4,2),
        frame=u.texture(p,u.path.."frame.dds",64,64,0,0,3),
        timer=u.text(p,30,64,64,0,0,15),stack=u.text(p,19,26,24,36,0,19),
        -- Created with the slot (pool warm-up), so the first reorder in
        -- combat does not have to grow every control table.
        rebindClaimed=false}
    t.fill:ClearAnchors(); t.fill:SetAnchor(BOTTOMLEFT,p,BOTTOMLEFT,4,-4); t.fill:SetHidden(true)
    -- Native rectangular surfaces, not an additional DDS glow. The outline
    -- sits above the dark slot frame and stays legible against bright terrain.
    if g==self.ob then self:Signal(t,true)
    else
        -- Hover for the game's tooltip, right-click to hide or whitelist.
        -- Only reacts while the cursor is shown; never in Edit Mode.
        local slot=t
        p:SetHandler("OnMouseEnter",function() self:ShowTooltip(slot) end)
        p:SetHandler("OnMouseExit",function() if ClearTooltip and InformationTooltip then ClearTooltip(InformationTooltip) end end)
        p:SetHandler("OnMouseUp",function(_,button,inside)
            if inside and (not MOUSE_BUTTON_INDEX_RIGHT or button==MOUSE_BUTTON_INDEX_RIGHT) then self:ContextMenu(slot) end
        end)
        p:SetMouseEnabled(g.interactive==true)
    end
    t.p:SetHidden(true); g.pool[i]=t
    return t
end
-- All values used by a slot are resolved once per settings generation.
-- ApplyConfig invalidates them; regular ticks never rebuild font specs or
-- repeatedly read the same settings for every effect in a grid.
function H:Visual(g)
    if g.visual then return g.visual end
    local c=self.owner.settings; local p=g.prefix; local ob=g==self.ob
    local chosen=c[p.."Font"]
    local face=chosen and chosen~="HUD font" and self.owner:ResolveFont(chosen) or
        self.owner.effectiveFont or self.owner:ResolveFont(c.fontFace)
    local chosenOutline=c[p.."Outline"]
    local v={
        size=number(c[p.."Size"],ob and 48 or 36,20,100),
        columns=ob and 1 or math.floor(number(c[p.."Columns"],8,1,16)),
        gap=ob and 0 or number(c[p.."Gap"],3,0,20),
        grow=c[p.."Grow"],singleRow=c[p.."SingleRow"]==true,
        enabled=c[p.."Enabled"]==true,sort=c[p.."Sort"],
        permanent=c[p.."Permanent"]==true,mine=c[p.."Mine"]==true,
        whitelistOnly=c[p.."WhitelistOnly"]==true,
        stacks=c[p.."Stacks"]~=false,fill=c[p.."Fill"]~=false,
        flash=c[p.."Flash"]~=false,
        flashMs=number(c[p.."FlashSeconds"],3,0,10)*1000,
        highlight=c[p.."HighlightDebuffs"]~=false,
        color=c[p.."Color"],
        face=face,outline=chosenOutline and chosenOutline~="HUD outline" and chosenOutline or c.fontStyle,
        timerSize=number(c[p.."FontSize"],30,12,48),
        stackSize=number(c[p.."StackSize"],19,10,30),
        decimal=number(c.decimalSeconds,3,0,10),
    }
    g.visual=v
    return v
end
function H:Config(g)
    local v=self:Visual(g)
    return v.size,v.columns,v.gap
end
function H:EffectiveColumns(g,count)
    local v=self:Visual(g)
    -- Single Row extends the grid rather than dropping/wrapping effects.
    return v.singleRow and count>v.columns and count or v.columns
end
-- Use the same fixed sample rectangle the HUD editor displays. Live effect
-- count changes must still grow in the configured direction, not move the
-- whole grid. A size edit, however, preserves that sample rectangle's center.
local function sizeReference(s,p)
    local ob=p=="offBalance"
    local size=number(s[p.."Size"],ob and 48 or 36,20,100)
    local cols=ob and 1 or math.floor(number(s[p.."Columns"],8,1,16))
    local gap=ob and 0 or number(s[p.."Gap"],3,0,20)
    local count=(ob or s[p.."SingleRow"]) and cols or math.min(MAX_ICONS,math.max(8,cols*2))
    local rows=math.max(1,math.ceil(count/cols))
    return (cols*size+(cols-1)*gap)/2,(rows*size+(rows-1)*gap)/2
end
function H:SetSizeOption(key,value)
    local s=self.owner.settings
    if s[key]==value then return end
    for _,g in ipairs(self.warmupGroups) do
        local p=g.prefix
        if key==p.."Size" or key==p.."Gap" or key==p.."Columns" then
            local w,h=sizeReference(s,p)
            s[key]=value
            local nw,nh=sizeReference(s,p)
            s[p.."X"]=(s[p.."X"] or -220)+nw-w
            s[p.."Y"]=(s[p.."Y"] or 20)+h-nh
            return
        end
    end
    s[key]=value
end
function H:Place(g,i,t,size,cols,gap,count)
    local v=self:Visual(g)
    local row=math.floor((i-1)/cols)
    local col=(i-1)%cols
    local grow=v.grow
    local mode=grow=="Center" and "center" or "right"
    local sx,sy,anchor,relative
    if mode=="center" then
        -- Anchor the visible row to the FIXED center of the widget, not to
        -- the first/last icon. Reflowing from 1 to N icons never moves that
        -- center, including if Single Row expands beyond the column count.
        local rowCount=math.min(cols,math.max(0,(count or g.shown or 0)-row*cols))
        sx=(col-(rowCount-1)/2)*(size+gap)
        sy=row*(size+gap)
        anchor,relative=TOP,TOP
    else
        sx=-col*(size+gap)
        -- Left to right keeps the configured left edge; a single row past
        -- the column count extends to the right.
        if grow=="Left to right" then sx=-((v.columns-1)-col)*(size+gap) end
        sy=row*(size+gap)
        anchor,relative=TOPRIGHT,TOPRIGHT
    end
    local scale=size/64
    if t.layoutSize~=size or t.layoutX~=sx or t.layoutY~=sy or t.layoutMode~=mode then
        -- Reordering effects changes anchors, not their scale. Avoid an
        -- additional native layout invalidation for each shifted icon.
        if t.layoutSize~=size then t.p:SetScale(scale) end
        if t.layoutMode==mode and t.p.SetAnchorOffsets then
            t.p:SetAnchorOffsets(sx,sy)
        else
            t.p:ClearAnchors(); t.p:SetAnchor(anchor,g.window,relative,sx,sy)
        end
        t.layoutSize,t.layoutX,t.layoutY,t.layoutMode=size,sx,sy,mode
    end
    -- Center growth may reanchor slots as effects appear. Reanchoring must
    -- not re-run the expensive native font/outline setup.
    if t.fontGeneration~=self.visualGeneration then
        self.owner:ApplyNativeFont(t.timer,v.face,v.timerSize,v.outline,"widget")
        self.owner:ApplyNativeFont(t.stack,v.face,v.stackSize,v.outline,"widget")
        t.fontGeneration=self.visualGeneration
    end
end
function H:Position(g)
    if not g.window then return end
    local c=self.owner.settings; local p=g.prefix
    -- A larger panel at an edge can extend beyond it without moving its
    -- selected center. Signed offsets also make resizing reversible.
    local x=number(c[p.."X"],-220,-4000,4000)
    local y=number(c[p.."Y"],20,-3000,3000)
    -- Clamp the whole grid (including expanding centered rows) only at the
    -- factory position. Dragging keeps the player's own coordinates intact.
    if self.owner.DefaultSetting then
        g.window:SetClampedToScreen(x==self.owner:DefaultSetting(p.."X") and y==self.owner:DefaultSetting(p.."Y"))
    end
    g.window:ClearAnchors()
    if c[p.."Grow"]=="Center" then
        local size,cols,gap=self:Config(g)
        local width=cols*size+(cols-1)*gap
        -- The reference point is where the center of the old, fixed-width
        -- editor box was. TOP rather than TOPRIGHT keeps it there when the
        -- number of icons (and the actual panel width) changes.
        g.window:SetAnchor(TOP,GuiRoot,TOPRIGHT,self.owner:UIUnits(x-width/2),self.owner:UIUnits(y))
    else
        g.window:SetAnchor(TOPRIGHT,GuiRoot,TOPRIGHT,self.owner:UIUnits(x),self.owner:UIUnits(y))
    end
end
function H:Layout(g)
    if not g.window then return end
    local size,_,gap=self:Config(g)
    local count=g.shown or 0
    local cols=self:EffectiveColumns(g,count)
    local w=g.window; self:Position(g)
    w:SetDimensions(cols*size+(cols-1)*gap,math.max(1,math.ceil(count/cols))*(size+gap)-gap)
    for i,t in ipairs(g.pool) do
        self:Place(g,i,t,size,cols,gap,count)
        t.tintKey=nil; t.nextPaintAt=nil
    end
    g.size,g.cols,g.gap=size,cols,gap
    g.nextVisualAt=nil
end
-- Spread bounded, hidden reusable controls over the existing HUD tick.
-- Never create them during combat, preview or native/edit-mode work.
-- The visible pool, layout, font and countdown behavior remain unchanged.
function H:Prewarm()
    for _=1,PREWARM_PER_TICK do
        if self:PrewarmOne() then return end
    end
end
-- Prepares one hidden slot (or one debuff outline). Returns true once every
-- enabled grid has reached its target.
function H:PrewarmOne()
    local groups=self.warmupGroups
    for _=1,#groups do
        local index=self.warmupIndex
        local g=groups[index]
        self.warmupIndex=index%#groups+1
        local v=self:Visual(g)
        if v.enabled then
            local limit=g==self.ob and 1 or self:PoolTarget(g)
            if #g.pool<limit then
                if not g.window then self:Window(g); self:Layout(g) end
                local i=#g.pool+1
                local t=self:Slot(g,i)
                self:Place(g,i,t,g.size,g.cols,g.gap,g.shown or 0)
                if g.isDebuff and v.highlight and CT_BACKDROP then self:Signal(t,false) end
                return
            end
            -- Existing hidden slots can lack a debuff outline if highlighting
            -- was previously disabled. Prepare one per tick, not in combat.
            if g.isDebuff and v.highlight and CT_BACKDROP then
                for i=1,math.min(limit,#g.pool) do
                    local t=g.pool[i]
                    if not t.signal then self:Signal(t,false); return end
                end
            end
        end
    end
    self.warmupDone=true
    return true
end
function H:PoolTarget(g)
    local hints=self.owner.settings.effectPoolHint
    local learned=type(hints)=="table" and tonumber(hints[g.prefix]) or 0
    -- The stored hint stays "largest count shown"; headroom is added here.
    if learned>0 then learned=learned+POOL_HEADROOM end
    return math.max(PREWARM_ICONS,math.min(POOL_HINT_LIMIT,learned))
end
-- Live grids only: previews and Edit Mode show a fixed sample count.
function H:RememberPool(g,count)
    if g==self.ob or count<=PREWARM_ICONS then return end
    local settings=self.owner.settings
    local hints=settings.effectPoolHint
    if type(hints)~="table" then hints={}; settings.effectPoolHint=hints end
    count=math.min(POOL_HINT_LIMIT,count)
    if (tonumber(hints[g.prefix]) or 0)<count then
        hints[g.prefix]=count
        -- Top up the spare slots after combat (Update prewarms only then).
        self.warmupDone=false
    end
end
function H:EnsureLayout(g,count)
    if count==0 and not g.window then return end
    if count>0 and not g.window then self:Window(g); self:Layout(g) end
    if not g.size then self:Layout(g) end
    -- The common case is no layout change; avoid GetHidden, dimensions,
    -- anchor math and settings lookups on every HUD tick.
    if g.shown==count and not g.layoutDirty then return end
    if count>PREWARM_ICONS and not (self.demo or self.owner.editing) then self:RememberPool(g,count) end
    local cols=self:EffectiveColumns(g,count)
    local oldShown=g.shown or 0
    local reflow=g.cols~=cols
    g.cols=cols
    for i=#g.pool+1,count do
        local t=self:Slot(g,i)
        self:Place(g,i,t,g.size,g.cols,g.gap,count)
    end
    local placedAll=false
    if count~=oldShown or reflow or g.layoutDirty then
        for i=count+1,oldShown do hidden(g.pool[i].p,true) end
        for i=oldShown+1,count do g.pool[i].nextPaintAt=nil end
        g.shown=count
        g.window:SetDimensions(cols*g.size+(cols-1)*g.gap,math.max(1,math.ceil(count/cols))*(g.size+g.gap)-g.gap)
        if reflow or self:Visual(g).grow=="Center" then
            for i=1,count do self:Place(g,i,g.pool[i],g.size,cols,g.gap,count) end
            placedAll=true
        end
        hidden(g.window,count==0)
    end
    g.layoutDirty=false
    return placedAll
end
function H:Clear(g,replaceInTick)
    for _,bucket in ipairs({g,g.debuffGroup}) do
        for i=1,#bucket.records do bucket.records[i]=nil end
        bucket.scanCount=0
        bucket.scanInvalid=true
        bucket.structureDirty=true
        -- A reticle change is consumed synchronously inside Update. The old
        -- data is discarded immediately; laying out an empty grid and then
        -- the new grid in the same tick only causes duplicate native work.
        -- Other clear paths still hide the grid immediately.
        bucket.retarget=replaceInTick or nil
        if not replaceInTick then self:EnsureLayout(bucket,0) end
    end
    if g.unlistedId then
        local unId,unName,unCode=g.unlistedId,g.unlistedName,g.unlistedCode
        for k in pairs(unId) do unId[k]=nil; unName[k]=nil; unCode[k]=nil end
    end
    g.dirty=true; g.nextExpiry=nil
    g.recordsChanged=true; g.debuffGroup.recordsChanged=true
    g.nextVisualAt=nil; g.debuffGroup.nextVisualAt=nil
end
function H:UnitEnabled(g)
    local c=self.owner.settings
    return c[g.prefix.."Enabled"] or c[g.debuffGroup.prefix.."Enabled"]
end
-- Showing the cursor (chat, '.') drops the reticle target. The target grids
-- keep their last enemy until the cursor is gone, so its icons can be hovered.
local function cursorShown()
    if IsGameCameraUIModeActive and IsGameCameraUIModeActive() then return true end
    return SCENE_MANAGER and SCENE_MANAGER.IsShowing and SCENE_MANAGER:IsShowing("hudui") or false
end
function H:ReticleChanged()
    self.reticlePending=true; self.changeSeq=(self.changeSeq or 0)+1
    if not self.targetFrozen then
        self.obActive=nil; self.obImmune=nil; self.obFallback=nil; self.obAttackable=false
    end
end
function H:ApplyReticleChange()
    self.reticlePending=nil
    self:Clear(self.groups[TARGET],true); self.obActive=nil; self.obImmune=nil; self.obFallback=nil
    self.obAttackable=false; self:EnsureLayout(self.ob,0)
end
function H:PruneFrozen(g,now)
    local nextExpiry
    for _,bucket in ipairs({g,g.debuffGroup}) do
        local list,j=bucket.records,0
        for i=1,#list do
            local r=list[i]
            if r.finish==0 or r.finish>now then
                j=j+1; list[j]=r
                if r.finish>0 and (not nextExpiry or r.finish<nextExpiry) then nextExpiry=r.finish end
            end
        end
        if j<#list then for i=#list,j+1,-1 do list[i]=nil end; bucket.recordsChanged=true; bucket.structureDirty=true end
    end
    g.nextExpiry=nextExpiry
end
function H:Invalidate()
    self:Clear(self.groups[SELF]); self:ReticleChanged()
end
-- Hides a unit's icons but keeps its records (frozen target grid).
function H:Hide(g)
    for _,bucket in ipairs({g,g.debuffGroup}) do
        self:EnsureLayout(bucket,0); bucket.recordsChanged=true; bucket.structureDirty=true; bucket.nextVisualAt=nil
    end
end
function H:Watch(tag,enabled,keep)
    local key=PREFIX..tag
    if enabled and not self.listeners[tag] and EVENT_EFFECT_CHANGED then
        local group=self.groups[tag]
        -- One dirty bit per unit coalesces any number of queued ESO effect
        -- changes into a single authoritative snapshot on the normal HUD tick.
        EVENT_MANAGER:RegisterForEvent(key,EVENT_EFFECT_CHANGED,function(_,change,effectSlot,name,unitTag,beginTime,endTime,stackCount,_,_,kind,_,_,_,_,id,sourceType)
            if unitTag~=tag then return end
            if tag==TARGET and not self:UnitEnabled(group) and not self:BalanceKind(id,name) then
                if not (EFFECT_RESULT_FADED~=nil and change==EFFECT_RESULT_FADED
                    and self:BalanceWanted() and (self.obActive or self.obImmune)
                    and (type(name)~="string" or name=="")) then return end
            end
            -- No player buff grid: ordinary buffs cannot change the debuff
            -- display. Keep the known mislabeled healing penalties and the
            -- localized name fallback even on FADED (whose clocks can be 0).
            -- Unknown types/identities take the authoritative scan path.
            if tag==SELF and not group.dirty and self.owner.settings.effectSelfEnabled==false
                and BUFF_EFFECT_TYPE_BUFF~=nil and kind==BUFF_EFFECT_TYPE_BUFF
                and type(id)=="number" and id>0 and type(name)=="string" and name~=""
                and not HEALING_PENALTY[id] and not self.exchangeNames[clean(name)] then return end
            -- No target buff grid: ordinary target buffs cannot change the
            -- debuff display. Keep Off Balance Immunity (134599), which ESO
            -- reports as BUFF_EFFECT_TYPE_BUFF, when Off Balance is watched.
            if tag==TARGET and not group.dirty and self.owner.settings.effectTargetEnabled==false
                and BUFF_EFFECT_TYPE_BUFF~=nil and kind==BUFF_EFFECT_TYPE_BUFF
                and type(id)=="number" and id>0 and type(name)=="string" and name~=""
                and not (self:BalanceWanted() and self:BalanceKind(id,name)) then return end
            -- A listed effect's new time or stacks (or an unchanged unlisted
            -- effect): patch in place instead of re-reading the whole unit list.
            if not group.dirty and EFFECT_RESULT_UPDATED~=nil and change==EFFECT_RESULT_UPDATED and
                self:PatchRecord(group,effectSlot,name,id,beginTime,endTime,stackCount,sourceType) then return end
            -- Unlisted or already-expired FADED events (whose clocks can be 0)
            -- cannot change displayed lists or watched Off Balance state.
            if not group.dirty and EFFECT_RESULT_FADED~=nil and change==EFFECT_RESULT_FADED and
                self:IgnoreFade(group,effectSlot,id,name) then return end
            -- The owner's deferred grid update re-reads the lists after this.
            self.changeSeq=(self.changeSeq or 0)+1
            group.dirty=true
        end)
        if REGISTER_FILTER_UNIT_TAG then EVENT_MANAGER:AddFilterForEvent(key,EVENT_EFFECT_CHANGED,REGISTER_FILTER_UNIT_TAG,tag) end
        local wasEmpty=not next(self.listeners)
        self.listeners[tag]=true; self.groups[tag].dirty=true
        if wasEmpty and EVENT_EFFECTS_FULL_UPDATE then
            EVENT_MANAGER:RegisterForEvent(PREFIX.."Full",EVENT_EFFECTS_FULL_UPDATE,function()
                for activeTag in pairs(self.listeners) do self.groups[activeTag].dirty=true end
                self.changeSeq=(self.changeSeq or 0)+1
            end)
        end
    elseif not enabled and self.listeners[tag] then
        EVENT_MANAGER:UnregisterForEvent(key,EVENT_EFFECT_CHANGED); self.listeners[tag]=nil
        if EVENT_EFFECTS_FULL_UPDATE and not next(self.listeners) then EVENT_MANAGER:UnregisterForEvent(PREFIX.."Full",EVENT_EFFECTS_FULL_UPDATE) end
        if keep then self:Hide(self.groups[tag]) else self:Clear(self.groups[tag]) end
    end
end
-- A FADED event for an effect neither displayed nor tracked for Off Balance
-- (including a late FADED after nextExpiry already pruned the expired row)
-- cannot change the panel. Never inspect beginTime/endTime (they can be 0).
function H:IgnoreFade(g,slot,id,name)
    if slot==nil or type(id)~="number" or id<=0 then return false end
    local target=g.tag==TARGET
    if target and self:BalanceWanted() then
        if id==39077 or id==62988 or id==134599 then return false end
        if (self.obActive or self.obImmune) and (type(name)~="string" or name=="") then return false end
        local cached=self.balanceCache[id]
        local kind
        if cached and cached.name==name then kind=cached.kind else kind=self:BalanceKind(id,name) end
        if kind then return false end
    end
    local list=g.scratch
    for i=1,g.scanCount or 0 do
        local row=list[i]
        if row.slot==slot and row.id==id then return false end
    end
    local d=g.debuffGroup
    list=d.scratch
    for i=1,d.scanCount or 0 do
        local row=list[i]
        if row.slot==slot and row.id==id then return false end
    end
    if g.unlistedId and g.unlistedId[slot]==id then
        g.unlistedId[slot]=nil; g.unlistedName[slot]=nil; g.unlistedCode[slot]=nil
    end
    return true
end
-- An UPDATED event for an effect the panel already lists (same effect slot,
-- ID and name) changes only its start, end or stacks. Apply it to that record
-- and redo the bucket's ordering exactly as a scan would.
-- Returns false for anything it cannot prove equal to a full scan: Off
-- Balance (target tracker), SELF healing-penalty / Exchange name-duration
-- heuristics, a timed/untimed or long-effect change, an effect already over,
-- a frozen or pending target, an unlisted effect whose visibility may change.
function H:PatchRecord(g,slot,name,id,beginTime,endTime,stacks,sourceType)
    if slot==nil or id==nil then return false end
    local target=g.tag==TARGET
    if self.demo or (target and (self.targetFrozen or self.reticlePending)) then return false end
    local c=self.owner.settings
    if target and self:BalanceWanted() then
        if id==39077 or id==62988 or id==134599 then return false end
        local cached=self.balanceCache[id]
        local kind
        if cached and cached.name==name then kind=cached.kind else kind=self:BalanceKind(id,name) end
        if kind then return false end
    end
    local beginMs=(tonumber(beginTime) or 0)*1000; local endMs=(tonumber(endTime) or 0)*1000
    local timed=endMs>0 and endMs>beginMs
    if not target then
        if HEALING_PENALTY[id] or (timed and endMs-beginMs>=3500 and endMs-beginMs<=4500)
            or (type(name)=="string" and name~="" and self.exchangeNames[clean(name)]) then
            return false
        end
    end
    local r,bucket
    local list=g.scratch
    for i=1,g.scanCount or 0 do
        local row=list[i]
        if row.slot==slot and row.id==id then r,bucket=row,g; break end
    end
    if not r then
        local d=g.debuffGroup
        list=d.scratch
        for i=1,d.scanCount or 0 do
            local row=list[i]
            if row.slot==slot and row.id==id then r,bucket=row,d; break end
        end
    end
    local isMine=COMBAT_UNIT_TYPE_PLAYER~=nil and sourceType==COMBAT_UNIT_TYPE_PLAYER
    if not r then
        -- Not listed at the last scan (another player's debuff, filtered,
        -- over the icon limit). It stays unlisted unless its timed/long
        -- state or (on target) player ownership changes, or it is already over.
        if not (g.unlistedId and g.unlistedId[slot]==id and g.unlistedName[slot]==name) then return false end
        if target then
            local code=(timed and 1 or 0)+((timed and endMs-beginMs>=60000) and 2 or 0)+(isMine and 4 or 0)
            return code==g.unlistedCode[slot] and (not timed or endMs>clock())
        end
        local code=(timed and 1 or 0)+((timed and endMs-beginMs>=60000) and 2 or 0)
        return code==(g.unlistedCode[slot] or 0)%4 and (not timed or endMs>clock())
    end
    local v=self:Visual(bucket)
    if target then
        if v.mine and not isMine then return false end
    end
    if r.name~=name then return false end
    if timed~=(r.finish>0) then return false end
    if timed and endMs<=clock() then return false end
    if timed and c.effectLongEffects==false and endMs-beginMs>=60000 then return false end
    local finishTime=timed and endMs or 0
    local stackCount=tonumber(stacks) or 0
    if r.finish==finishTime and r.start==beginMs and r.stacks==stackCount then return true end
    r.revision=(r.revision or 0)+1
    r.finish=finishTime; r.start=beginMs; r.stacks=stackCount
    self.changeSeq=(self.changeSeq or 0)+1
    bucket.scanChanged=true; bucket.scanStructureChanged=false
    finishBucket(bucket,v)
    -- The next natural expiry, as the scan computes it.
    local nextExpiry
    list=g.scratch
    for i=1,g.scanCount or 0 do
        local f=list[i].finish
        if f>0 and (not nextExpiry or f<nextExpiry) then nextExpiry=f end
    end
    list=g.debuffGroup.scratch
    for i=1,g.debuffGroup.scanCount or 0 do
        local f=list[i].finish
        if f>0 and (not nextExpiry or f<nextExpiry) then nextExpiry=f end
    end
    if target then
        local active,immune=self.obActive,self.obImmune
        if active and (not nextExpiry or active.finish<nextExpiry) then nextExpiry=active.finish end
        if immune and (not nextExpiry or immune.finish<nextExpiry) then nextExpiry=immune.finish end
    end
    g.nextExpiry=nextExpiry
    return true
end
function H:Scan(g,now,snapshot)
    local c=self.owner.settings; local target=g.tag==TARGET; local nextExpiry
    local d=g.debuffGroup
    local gv=self:Visual(g); local dv=self:Visual(d)
    local showBuffs=gv.enabled
    local showDebuffs=dv.enabled
    local watchBalance=target and self:BalanceWanted()
    local black=c.effectBlacklist or EMPTY
    local white=(target and c.effectWhitelistTarget or c.effectWhitelistSelf) or EMPTY
    local longOk=c.effectLongEffects~=false
    local names,anyList=self.listNames,self.listAny~=false
    local showAny=showBuffs or showDebuffs
    local debuffType=BUFF_EFFECT_TYPE_DEBUFF
    g.scanCount,d.scanCount=0,0
    g.scanChanged,d.scanChanged=false,false
    g.scanStructureChanged,d.scanStructureChanged=false,false
    g.dirty=false
    -- Rows this scan does not list, by effect slot: what an UPDATED event
    -- needs to prove it cannot change the panel (see PatchRecord).
    local unId,unName,unCode=g.unlistedId,g.unlistedName,g.unlistedCode
    if not unId then unId,unName,unCode={},{},{}; g.unlistedId,g.unlistedName,g.unlistedCode=unId,unName,unCode end
    for k in pairs(unId) do unId[k]=nil; unName[k]=nil; unCode[k]=nil end
    local active,immune
    local exists=not target or not DoesUnitExist or DoesUnitExist(TARGET)
    if target then self.obAttackable=exists and (not IsUnitAttackable or IsUnitAttackable(TARGET)) and (not IsUnitDead or not IsUnitDead(TARGET)) or false end
    if exists and GetNumBuffs and GetUnitBuffInfo then
        local count,info=GetNumBuffs,GetUnitBuffInfo
        if snapshot then count,info=snapshot:Readers(g.tag) end
        local n=count(g.tag) or 0
        for i=1,n do
            local name,start,finish,slot,stacks,icon,_,kind,_,_,id,_,mine=info(g.tag,i)
            if type(name)=="string" and name~="" then
                local beginMs=(tonumber(start) or 0)*1000; local endMs=(tonumber(finish) or 0)*1000
                local timed=endMs>0 and endMs>beginMs
                if not timed or endMs>now then
                    -- Most rows have an authoritative native type. Only the
                    -- player-side exceptional penalty needs name fallback.
                    local debuff=debuffType~=nil and kind==debuffType
                    if showAny and not debuff and not target then
                        local duration=endMs-beginMs
                        if HEALING_PENALTY[id] or duration>=3500 and duration<=4500 then
                            debuff=self:IsDebuff(kind,id,name,duration,target)
                        end
                    end
                    local obKind
                    if watchBalance then
                        if id==39077 or id==62988 then obKind=1
                        elseif id==134599 then obKind=2
                        else
                            local cached=self.balanceCache[id]
                            if cached and cached.name==name then obKind=cached.kind or nil
                            else obKind=self:BalanceKind(id,name) end
                        end
                    end
                    if obKind and timed then
                        if obKind==1 and (not active or endMs>active.finish) then active={finish=endMs,start=beginMs,icon=icon}
                        elseif obKind==2 and (not immune or endMs>immune.finish) then immune={finish=endMs,start=beginMs,icon=icon} end
                    end
                    local bucket=debuff and d or g; local v=debuff and dv or gv
                    local listed=(debuff and showDebuffs) or (not debuff and showBuffs)
                    if listed and (anyList or v.whitelistOnly) then
                        -- Name keys are only resolved when a list holds names.
                        local lname=names and clean(name) or nil
                        listed=not (black[id] or (lname and black[lname])) and
                            (not v.whitelistOnly or white[id] or (lname and white[lname]))
                    end
                    -- ESO's "Long Effects": one minute or more of total duration.
                    if listed and timed and not longOk and endMs-beginMs>=60000 then listed=false end
                    if listed and bucket.scanCount<MAX_ICONS and (timed or v.permanent) and
                        (not target or not v.mine or mine) and (not obKind or not c.offBalanceSeparate) and
                        type(icon)=="string" and icon~="" then
                        local count=bucket.scanCount+1; bucket.scanCount=count
                        local finishTime=timed and endMs or 0
                        local stackCount=tonumber(stacks) or 0
                        local r=bucket.scratch[count]
                        if not r then r={}; bucket.scratch[count]=r end
                        -- Only relative order among displayed rows matters.
                        -- An invisible effect moving in the native list must
                        -- not invalidate every subsequent visible record.
                        if r.id~=id or r.slot~=slot then bucket.scanStructureChanged=true end
                        if r.finish~=finishTime or r.start~=beginMs or r.order~=count or r.slot~=slot or
                            r.id~=id or r.icon~=icon or r.stacks~=stackCount or r.debuff~=debuff or r.name~=name then
                            bucket.scanChanged=true
                            r.revision=(r.revision or 0)+1
                            r.finish=finishTime; r.start=beginMs; r.order=count; r.slot=slot; r.id=id; r.icon=icon
                            r.stacks=stackCount; r.debuff=debuff; r.name=name
                        end
                        if timed and (not nextExpiry or endMs<nextExpiry) then nextExpiry=endMs end
                    elseif slot~=nil then
                        unId[slot]=id; unName[slot]=name
                        unCode[slot]=(timed and 1 or 0)+((timed and endMs-beginMs>=60000) and 2 or 0)+(mine and 4 or 0)
                    end
                end
            end
        end
    end
    finishBucket(g,gv); finishBucket(d,dv)
    if target then
        -- The immunity is normally an actual debuff. A nominal 15s fallback
        -- is only shown for the same uninterrupted reticle after an observation
        -- reaches its natural expiry; actual immunity always takes precedence.
        local old=self.obActive
        if active then self.obFallback=nil
        elseif immune then self.obFallback=nil
        elseif old and old.finish<=now and self.obAttackable then self.obFallback=old.finish+15000 end
        self.obActive,self.obImmune=active,immune
        if active and (not nextExpiry or active.finish<nextExpiry) then nextExpiry=active.finish end
        if immune and (not nextExpiry or immune.finish<nextExpiry) then nextExpiry=immune.finish end
    end
    g.nextExpiry=nextExpiry
end
-- timerOnly: the slot already shows this exact record (sameRecord) and only
-- a scheduled countdown/fill/pulse boundary is due. Icon, stack text, colors,
-- outline and the stored signature cannot have changed, so they are skipped;
-- every time-dependent pixel below is still evaluated exactly as before.
function H:Paint(t,r,now,group,mode,timerOnly,visual)
    local v=visual or self:Visual(group); local u=self.ui
    local left=remaining(r,now); local timed=r.finish>0
    if not timerOnly and t.path~=r.icon then t.icon:SetTexture(r.icon); t.path=r.icon end
    if not timerOnly then t.effectName=r.name; t.effectTag=group.tag; t.demoRecord=self.demo or self.owner.editing or nil end
    local kind,bucket=timerBucket(left,v.decimal)
    if mode=="ready" then kind,bucket="ready",0 end
    local estimated=r.estimated and true or false
    if t.timeKind~=kind or t.timeBucket~=bucket or t.timeEstimated~=estimated then
        local label=kind=="ready" and "∞" or kind=="" and "" or kind=="d" and string.format("%.1f",bucket/10) or tostring(bucket)..(kind=="s" and "" or kind)
        u.setText(t.timer,(estimated and "~" or "")..label)
        t.timeKind,t.timeBucket,t.timeEstimated=kind,bucket,estimated
    end
    if not timerOnly then
        local stacks=r.stacks and r.stacks>1 and v.stacks and r.stacks or 0
        if t.stackNumber~=stacks then u.setText(t.stack,stacks>0 and tostring(stacks) or ""); t.stackNumber=stacks end
    end
    local warn=timed and left>0 and left<=v.flashMs and v.flash
    local alpha=warn and not mode and (math.floor(now/250)%2==0 and .4 or 1) or 1
    if t.alpha~=alpha then t.p:SetAlpha(alpha); t.alpha=alpha end
    if not timerOnly then
        local highlight=not mode and r.debuff and v.highlight
        local tint=mode or (highlight and "highlightDebuff" or r.debuff and "debuff" or "buff")
        local color=(mode=="immune" and self.owner.settings.offBalanceImmuneColor) or
            (mode=="active" and self.owner.settings.offBalanceActiveColor) or
            (mode=="ready" and self.owner.settings.offBalanceReadyColor) or v.color
        if highlight and not t.signal then self:Signal(t,false) end
        if t.tintKey~=tint or t.tint~=color then
            t.tintKey,t.tint=tint,color; local rr,gg,bb,aa=unpack(color)
            local colored=mode or highlight
            u.color(t.fill,rr,gg,bb,(aa or 1)*(mode=="active" and .80 or mode=="immune" and .72 or highlight and .43 or .30))
            u.color(t.timer,colored and rr or 1,colored and gg or 1,colored and bb or 1,1)
            t.frame:SetColor(colored and rr or 1,colored and gg or 1,colored and bb or 1,1)
            t.icon:SetDesaturation(mode=="immune" and .55 or 0)
            if t.edges then
                hidden(t.signal,not colored)
                if colored then
                    for i,e in ipairs(t.edges) do
                        local opacity=i>4 and 1 or (mode=="ready" and .75 or .95)
                        e:SetCenterColor(rr,gg,bb,opacity*(aa or 1))
                    end
                end
            end
    end
    end
    if t.signal then
        local pulse=(mode=="active" or mode=="immune") and warn and (math.floor(now/250)%2==0 and .65 or 1) or 1
        if t.signalAlpha~=pulse then t.signalAlpha=pulse; t.signal:SetAlpha(pulse) end
    end
    local fill=v.fill and timed and left>0 and r.finish>r.start
    local height=fill and math.max(1,math.floor(56*clamp(left/(r.finish-r.start),0,1)+.5)) or 0
    if t.height~=height then
        t.height=height; hidden(t.fill,height==0)
        if height>0 then t.fill:SetHeight(height); t.fill:SetTextureCoords(0,1,1-height/56,1) end
    end
    if not timerOnly then
        hidden(t.p,false)
        -- Dirty-state signatures are stored on the rendered slot, NOT on the
        -- reusable scan record. Sorting/reusing records cannot hide changes.
        t.effectID,t.effectSlot,t.effectIcon=r.id,r.slot,r.icon
        t.effectStart,t.effectFinish,t.effectStacks=r.start,r.finish,r.stacks
        t.effectDebuff,t.effectEstimated,t.effectMode=r.debuff,estimated,mode
    end

    -- Schedule only transitions that can affect visible pixels. This keeps
    -- long buffs idle while preserving 0.1s labels, fill steps and 250ms
    -- warning pulses at the existing 100ms HUD tick resolution.
    local nextChange=nextTimerChange(left,kind,bucket,v.decimal)
    if timed and left>0 then
        nextChange=math.min(nextChange,left)
        if fill and height>1 then
            local threshold=(height-.5)*(r.finish-r.start)/56
            nextChange=math.min(nextChange,math.max(1,left-threshold+1))
        end
        if v.flash and v.flashMs>0 then
            if warn then
                nextChange=math.min(nextChange,250-now%250)
            elseif left>v.flashMs then
                nextChange=math.min(nextChange,left-v.flashMs)
            end
        end
    end
    t.nextPaintAt=now+math.max(1,math.floor(nextChange))
end
-- A changed order (sorting, or an effect added/removed in the middle) used
-- to repaint every shifted slot with its neighbour's icon, texts and colors.
-- Keep each pooled control on the effect it already displays and only move
-- its anchor: the grid looks identical, but nothing is redrawn.
-- Buff slots are unique per unit, so slot+ability identifies an effect
-- without building a string key on the HUD tick.
local function effectKey(slot,id) return (slot or 0)*1048576+(id or 0) end
function H:Rebind(g,records,n)
    local pool=g.pool
    local shown=math.min(g.shown or 0,#pool)
    if shown==0 then return false end
    local aligned=true
    for i=1,math.min(n,shown) do
        local t,r=pool[i],records[i]
        if t.effectID~=r.id or t.effectSlot~=r.slot then aligned=false; break end
    end
    if aligned then return false end
    local m=math.min(#pool,math.max(n,shown))
    local owners=g.rebindOwners or {}; g.rebindOwners=owners
    local order=g.rebindOrder or {}; g.rebindOrder=order
    for key in pairs(owners) do owners[key]=nil end
    for i=1,shown do
        local t=pool[i]
        t.rebindClaimed=false
        if t.effectID then
            local key=effectKey(t.effectSlot,t.effectID)
            if owners[key]==nil then owners[key]=t end
        end
    end
    for i=shown+1,m do
        -- A hidden spare may still carry its last effect's signature.
        local t=pool[i]
        t.rebindClaimed=false; t.effectID=nil; t.nextPaintAt=nil
    end
    local wanted=math.min(n,m)
    for i=1,wanted do
        local r=records[i]
        local t=r.id and owners[effectKey(r.slot,r.id)]
        if t and not t.rebindClaimed then t.rebindClaimed=true; order[i]=t else order[i]=false end
    end
    -- Controls whose effect ended fill the remaining positions in their
    -- existing order; the surplus ends up behind the visible range.
    local spare=1
    for i=1,m do
        local t=i<=wanted and order[i] or false
        if not t then
            while pool[spare].rebindClaimed do spare=spare+1 end
            t=pool[spare]; spare=spare+1
        end
        order[i]=t
    end
    local moved=false
    for i=1,m do
        local t=order[i]
        if pool[i]~=t then pool[i]=t; moved=true end
        order[i]=nil
    end
    return moved
end
function H:PaintGroup(g,records,now,demo)
    local n=#records
    if n==0 and not g.window then
        g.nextVisualAt=math.huge; g.recordsChanged=false; g.retarget=nil; g.structureDirty=nil
        return
    end
    local stable=not demo and not g.retarget and not g.recordsChanged and
        not g.layoutDirty and g.shown==n and g.nextVisualAt
    if stable then
        if now<g.nextVisualAt then return end
        -- The record sequence and presentation generation are unchanged.
        -- Only due countdown/fill/pulse boundaries need to be evaluated;
        -- no signature comparisons, rebind or layout pass on this path.
        local nextAt=math.huge
        local v=self:Visual(g)
        for i=1,n do
            local t=g.pool[i]
            if not t.nextPaintAt then self:Paint(t,records[i],now,g,nil,false,v)
            elseif now>=t.nextPaintAt then self:Paint(t,records[i],now,g,nil,true,v) end
            if t.nextPaintAt<nextAt then nextAt=t.nextPaintAt end
        end
        g.nextVisualAt=nextAt
        return
    end
    -- Slot/ability identity is scoped to one target. On retarget, retain the
    -- physical positions and bind the fresh observations by display index.
    local moved=not demo and not g.retarget and g.recordsChanged and g.structureDirty~=false and n>0 and self:Rebind(g,records,n)
    local previous=g.shown or 0
    local placedAll=self:EnsureLayout(g,n)
    if not placedAll and (moved or n>previous) then
        -- A control may have been parked behind the visible range by an
        -- earlier rebind, so one entering it is positioned for its index too.
        -- Place caches each control's geometry: only moved controls reanchor.
        local pool,size,cols,gap=g.pool,g.size,g.cols,g.gap
        for i=1,n do self:Place(g,i,pool[i],size,cols,gap,n) end
    end
    local nextAt=math.huge
    local v=self:Visual(g)
    for i=1,n do
        local t=g.pool[i]; local r=records[i]
        local unchanged=not g.retarget and r.revision and t.effectRecord==r and t.effectRevision==r.revision
        -- A new target is authoritative. Reuse static pixels only when every
        -- identity/tooltip field matches; the newly observed clock still wins.
        if demo or not t.nextPaintAt then
            self:Paint(t,r,now,g,nil,false,v)
        elseif g.retarget or (not unchanged and not sameRecord(t,r)) then
            if sameAppearance(t,r,g) then
                self:Paint(t,r,now,g,nil,true,v)
                t.effectStart,t.effectFinish=r.start,r.finish
                t.effectEstimated=r.estimated and true or false
            else self:Paint(t,r,now,g,nil,false,v) end
        elseif now>=t.nextPaintAt then
            self:Paint(t,r,now,g,nil,true,v)
        end
        t.effectRecord=not demo and r or nil; t.effectRevision=r.revision
        if t.nextPaintAt<nextAt then nextAt=t.nextPaintAt end
    end
    g.nextVisualAt=nextAt
    g.recordsChanged=false; g.retarget=nil; g.structureDirty=nil
end
local SAMPLE={
    "/esoui/art/icons/ability_buff_major_sorcery.dds",OB_ICON,"/esoui/art/icons/ability_buff_major_brutality.dds",
    "/esoui/art/icons/ability_buff_major_courage.dds","/esoui/art/icons/ability_armor_001.dds",
    "/esoui/art/icons/ability_mage_005.dds","/esoui/art/icons/ability_buff_major_slayer.dds","/esoui/art/icons/ability_buff_major_force.dds"}
function H:DemoList(g,now)
    g.demo=g.demo or {}
    -- Match the final one-row limit in preview/edit mode as well.
    local _,cols=self:Config(g)
    local max=self.owner.settings[g.prefix.."SingleRow"] and cols or math.min(MAX_ICONS,math.max(8,cols*2))
    for i=1,max do
        local r=g.demo[i] or {}; g.demo[i]=r
        local duration=i*3000; local left=duration-(now%3000)
        r.start=now+left-duration; r.finish=now+left; r.icon=SAMPLE[(i-1)%#SAMPLE+1]; r.stacks=i%5==0 and 3 or 0; r.debuff=g.isDebuff==true; r.order=i
    end
    for i=max+1,#g.demo do g.demo[i]=nil end
    return g.demo
end
local TAGS={SELF,TARGET}
local READY={start=0,finish=0}
function H:Update(now,snapshot)
    local c=self.owner.settings; local demo=self.demo or self.owner.editing
    -- The main HUD tick still runs when the effect grids are hidden outside
    -- combat. Prepare hidden pools before the visibility early-return so this
    -- setting does not prevent preparation before the next fight.
    if not self.warmupDone and c.enabled and not demo and not self.owner.preview and self.hudShown and
        not (self.owner.IsNativeHudEditorOpen and self.owner:IsNativeHudEditorOpen()) and
        IsUnitInCombat and IsUnitInCombat(SELF)==false then self:Prewarm() end
    if not self.visible then return end
    -- The stock HUD may reapply alpha or unhide when a target frame refreshes.
    -- Skip GetAlpha() on containers already confirmed hidden via nativePaused,
    -- and avoid empty pairs() traversal when native hiding is off.
    if next(self.nativePaused) then
        for control in pairs(self.nativePaused) do if not control:IsControlHidden() then control:SetHidden(true) end end
    end
    if next(self.native) then
        for control in pairs(self.native) do
            if not self.nativePaused[control] and control:GetAlpha()~=0 then
                control:SetAlpha(0)
            end
        end
    end
    now=now or clock()
    local frozen=not demo and cursorShown()
    if frozen then self.targetFrozen=true
    elseif self.targetFrozen then self.targetFrozen=nil; self.reticlePending=true end
    if self.reticlePending and not frozen then self:ApplyReticleChange() end
    for _,tag in ipairs(TAGS) do
        local g=self.groups[tag]
        if frozen and tag==TARGET then
            if g.nextExpiry and g.nextExpiry<=now then self:PruneFrozen(g,now) end
        elseif not demo and self.listeners[tag] and (g.dirty or g.nextExpiry and g.nextExpiry<=now) then self:Scan(g,now,snapshot) end
        self:UpdateBucket(g,now,demo,self.listeners[tag])
        self:UpdateBucket(g.debuffGroup,now,demo,self.listeners[tag])
    end
    if not c.offBalanceEnabled or not demo and not self.obAttackable then self:EnsureLayout(self.ob,0); return end
    local r,mode=self.obActive,"active"
    if demo then r=self.obDemo or {}; self.obDemo=r; r.start,r.finish=now-2000,now+5000
    elseif not r or r.finish<=now then r,mode=self.obImmune,"immune" end
    if not r or r.finish<=now then
        if c.offBalanceEstimate and self.obFallback and self.obFallback>now then
            r=self.obEstimate or {}; self.obEstimate=r; r.start,r.finish,r.estimated=self.obFallback-15000,self.obFallback,true; mode="immune"
        else mode="ready"; r=READY end
    end
    if mode=="ready" and not c.offBalanceReady then self:EnsureLayout(self.ob,0); return end
    local display=self.obDisplay or {}; self.obDisplay=display
    display.start,display.finish,display.estimated=r.start,r.finish,r.estimated
    display.icon=mode=="immune" and IMMUNE_ICON or OB_ICON; display.debuff=false
    self:EnsureLayout(self.ob,1)
    local slot=self.ob.pool[1]
    if not slot.nextPaintAt or not sameRecord(slot,display,mode) then
        self:Paint(slot,display,now,self.ob,mode)
    elseif now>=slot.nextPaintAt then
        self:Paint(slot,display,now,self.ob,mode,true)
    end
end
function H:UpdateBucket(g,now,demo,live)
    if self:Visual(g).enabled and (demo or live) then
        if not demo and not g.retarget and not g.recordsChanged and not g.layoutDirty and
            (g.shown or 0)==#g.records and g.nextVisualAt and now<g.nextVisualAt then return end
        self:PaintGroup(g,demo and self:DemoList(g,now) or g.records,now,demo)
    elseif g.shown and g.shown>0 then
        self:EnsureLayout(g,0)
        g.nextVisualAt=nil
    end
end
local function tr(owner,text)
    return owner.settings and owner.settings.menuLanguage=="tr" and ZeraUITranslate and ZeraUITranslate(text) or text
end
-- Icons take the mouse only when the grid is locked (an unlocked grid is
-- dragged by its icons) and never in Edit Mode. Checked once per tick.
function H:SyncInteractive()
    local c=self.owner.settings
    local base=c.effectInteractive~=false and not self.owner.editing
    for i=1,4 do
        local g=self.warmupGroups[i]
        local want=base and c[g.prefix.."Locked"]~=false
        if g.interactive~=want then
            g.interactive=want
            for _,t in ipairs(g.pool) do t.p:SetMouseEnabled(want) end
        end
    end
end
function H:RefreshListFlags()
    local c=self.owner.settings
    local names,any=false,false
    for _,key in ipairs({"effectBlacklist","effectWhitelistSelf","effectWhitelistTarget"}) do
        for k in pairs(c[key] or EMPTY) do
            any=true
            if type(k)=="string" then names=true; break end
        end
    end
    self.listNames=names or nil
    -- With every list empty and no whitelist-only grid, the scan skips the
    -- per-effect list lookups entirely.
    self.listAny=any
end
function H:ListsChanged()
    self:RefreshListFlags()
    for _,g in pairs(self.groups) do g.visual=nil; g.debuffGroup.visual=nil end
    self:Clear(self.groups[SELF])
    if self.targetFrozen then self:FilterFrozen(self.groups[TARGET]) else self:ReticleChanged() end
end
-- While the target grid is frozen, apply list edits to what it shows.
function H:FilterFrozen(g)
    local c=self.owner.settings
    local black,white=c.effectBlacklist or EMPTY,c.effectWhitelistTarget or EMPTY
    for _,bucket in ipairs({g,g.debuffGroup}) do
        local v=self:Visual(bucket)
        local list,j=bucket.records,0
        for i=1,#list do
            local r=list[i]; local lname=clean(r.name)
            local keep=not (black[r.id] or black[lname]) and (not v.whitelistOnly or white[r.id] or white[lname])
            if keep then j=j+1; list[j]=r end
        end
        if j<#list then for i=#list,j+1,-1 do list[i]=nil end; bucket.recordsChanged=true; bucket.structureDirty=true end
    end
end
function H:SetListed(listKey,id,name,add)
    local c=self.owner.settings
    local list=c[listKey]
    if type(list)~="table" then list={}; c[listKey]=list end
    local lname=clean(name)
    if add then
        if id then list[id]=true end
        if lname~="" then list[lname]=true end
    else
        if id then list[id]=nil end
        if lname~="" then list[lname]=nil end
    end
    self:ListsChanged()
end
function H:IsListed(listKey,id,name)
    local list=self.owner.settings[listKey] or EMPTY
    local lname=clean(name)
    return (id and list[id]) or (lname~="" and list[lname]) or false
end
function H:ShowTooltip(t)
    if not t.effectID or not InformationTooltip or not InitializeTooltip then return end
    local id=t.effectID
    local name=t.effectName or (GetAbilityName and GetAbilityName(id)) or ""
    InitializeTooltip(InformationTooltip,t.p,BOTTOM,0,-4,TOP)
    InformationTooltip:AddLine(zo_strformat and zo_strformat("<<1>>",name) or name,"ZoFontWinH4",GOLD[1],GOLD[2],GOLD[3])
    local text=""
    if not t.demoRecord and t.effectSlot and GetAbilityEffectDescription then text=GetAbilityEffectDescription(t.effectSlot) or "" end
    if text=="" and GetAbilityDescription then text=GetAbilityDescription(id) or "" end
    if text~="" then InformationTooltip:AddLine(text,"ZoFontGame",1,1,1) end
    InformationTooltip:AddLine(string.format("ID %d  ·  %s",id,tr(self.owner,"Right-click: hide or whitelist")),"ZoFontGameSmall",.72,.68,.6)
end
function H:ContextMenu(t)
    if not t.effectID or t.demoRecord or not ClearMenu or not AddMenuItem or not ShowMenu then return end
    if ClearTooltip and InformationTooltip then ClearTooltip(InformationTooltip) end
    local id,name=t.effectID,t.effectName or ""
    local whiteKey=t.effectTag==TARGET and "effectWhitelistTarget" or "effectWhitelistSelf"
    ClearMenu()
    local hidden=self:IsListed("effectBlacklist",id,name)
    AddMenuItem(tr(self.owner,hidden and "Show this effect again" or "Hide this effect (blacklist)"),function()
        self:SetListed("effectBlacklist",id,name,not hidden)
    end)
    local white=self:IsListed(whiteKey,id,name)
    AddMenuItem(tr(self.owner,white and "Remove from whitelist" or (t.effectTag==TARGET and "Add to target whitelist" or "Add to my whitelist")),function()
        self:SetListed(whiteKey,id,name,not white)
    end)
    ShowMenu(t.p)
end
function H:RestoreNative()
    for control,alpha in pairs(self.native) do
        control:SetAlpha((type(alpha)=="number" and alpha>0) and alpha or 1)
        self.native[control]=nil
    end
    for control in pairs(self.nativePaused) do control:SetHidden(false); self.nativePaused[control]=nil end
end
function H:SyncNative()
    self:RestoreNative()
    if not self.visible or (self.demo and not self.owner.editing) or not self.owner.settings.effectHideNative then return end
    local manager=_G.BUFF_DEBUFF_MANAGER or _G.BUFF_DEBUFF
    local root=_G.ZO_BuffDebuffTopLevel or (manager and manager.control) or _G.ZO_BuffDebuffContainer
    for tag,child in pairs({[SELF]="SelfContainer",[TARGET]="TargetContainer"}) do
        if self:UnitEnabled(self.groups[tag]) then
            -- Direct named controls also work when ESO reparents the target
            -- buff container under the target frame (HUD editing/layout).
            local control=_G["ZO_BuffDebuffTopLevel"..child] or (root and root.GetNamedChild and root:GetNamedChild(child))
            if control and control.GetAlpha and control.SetAlpha then
                -- Never capture 0 from a faded-out buff container as its restore alpha.
                local alpha=control:GetAlpha()
                self.native[control]=(type(alpha)=="number" and alpha>0) and alpha or 1
                if alpha~=0 then control:SetAlpha(0) end
                -- An invisible (alpha 0) stock container still rebuilds and
                -- re-times every icon each frame. Hiding the container itself
                -- stops its OnUpdate; no ESO setting is changed, and it is
                -- shown again whenever the custom grid releases it.
                if control.SetHidden and control.IsControlHidden
                    and not control:IsControlHidden() then
                    self.nativePaused[control]=true; control:SetHidden(true)
                end
            end
        end
    end
end
-- Off Balance on the target is tracked for the Off Balance widget, and for
-- a Flame Lash on the bar (its middle shows Off Balance / immunity), from
-- the same target events and scans: nothing extra is read.
function H:BalanceWanted()
    return self.owner.settings.offBalanceEnabled or self.whipBalance or false
end
function H:SetWhipBalance(on)
    on=on and true or false
    if self.whipBalance==on then return end
    self.whipBalance=on
    self.groups[TARGET].dirty=true; self.changeSeq=(self.changeSeq or 0)+1
    if self.hudShown~=nil then self:Sync(self.hudShown) end
end
-- The target's Off Balance state for the whip: time left and full time in
-- ms, "active" or "immune", and whether the immunity is the estimated 15 s.
function H:BalanceTimer()
    if self.reticlePending or not self:BalanceWanted() or not self.obAttackable then return nil end
    local now=clock()
    local r,mode=self.obActive,"active"
    if not r or r.finish<=now then r,mode=self.obImmune,"immune" end
    if r and r.finish>now then return r.finish-now,math.max(1,r.finish-(r.start or now)),mode,false end
    if self.owner.settings.offBalanceEstimate and self.obFallback and self.obFallback>now then
        return self.obFallback-now,15000,"immune",true
    end
    return nil
end
function H:Sync(show,standalone)
    self.hudShown=show
    -- The action bar's main Tick stops in the loot scene. Its effect grids
    -- still own the native buff controls; retain their 100ms updates there.
    -- Other callers (settings/combat) inherit the current scene policy.
    if standalone~=nil then self.standalone=standalone end
    local c=self.owner.settings; local selfEnabled=self:UnitEnabled(self.groups[SELF]); local targetEnabled=self:UnitEnabled(self.groups[TARGET])
    -- Each grid follows only its own switch (ESO's Buffs & Debuffs settings
    -- govern only ESO's own display). Off Balance is an independent target
    -- widget and shares their event/scan machinery only.
    local balance=self:BalanceWanted()
    local enabled=c.enabled and (selfEnabled or targetEnabled or balance)
    if not balance then self.obFallback=nil; self.obActive=nil; self.obImmune=nil end
    local demo=self.demo or self.owner.editing
    self.visible=enabled and not self.owner.gamepadSuspended and (show or self.demo and self.menuOpen) and (demo or c.effectOutsideCombat or not IsUnitInCombat or IsUnitInCombat(SELF)) and true or false
    local live=self.visible and not demo
    -- Hidden while the cursor is shown: keep the target's last icons, so
    -- they are back (and hoverable) when the HUD shows again.
    local keepTarget=not self.visible and not demo and cursorShown()
    if keepTarget then self.targetFrozen=true end
    self:Watch(SELF,live and selfEnabled)
    self:Watch(TARGET,live and (targetEnabled or balance),keepTarget)
    if not self.visible then
        self:Clear(self.groups[SELF])
        if keepTarget then self:Hide(self.groups[TARGET])
        else
            self:Clear(self.groups[TARGET])
            self.obActive=nil; self.obImmune=nil; self.obFallback=nil; self.obAttackable=false
        end
        self:EnsureLayout(self.ob,0)
    end
    self:SyncNative()
    self:SyncInteractive()
    local separateTick=self.visible and (self.standalone or self.demo and not show)
    if separateTick and not self.previewTick then
        self.previewTick=true; EVENT_MANAGER:RegisterForUpdate(PREFIX.."Preview",100,function() self:Update() end)
    elseif not separateTick and self.previewTick then
        self.previewTick=false; EVENT_MANAGER:UnregisterForUpdate(PREFIX.."Preview")
    end
    if self.visible then self:Update() end
    if self.owner.SyncWidgetDrag then self.owner:SyncWidgetDrag() end
end
function H:ApplyConfig()
    self:RefreshListFlags()
    self.visualGeneration=(self.visualGeneration or 0)+1
    self.warmupDone=false
    for _,g in pairs(self.groups) do
        g.dirty=true
        g.visual=nil; g.debuffGroup.visual=nil
        self:Layout(g); self:Layout(g.debuffGroup)
    end
    self.ob.visual=nil
    self:Layout(self.ob); self:Sync(self.hudShown)
end
function H:MenuOpened(open)
    self.menuOpen=open
    if not open then self.demo=false end
    self:Sync(self.hudShown)
end
function H:ToggleDemo()
    self.demo=not self.demo; self:Invalidate(); self:Sync(self.hudShown)
end
