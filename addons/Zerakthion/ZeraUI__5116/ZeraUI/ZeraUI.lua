-- Zera UI: PC keyboard combat HUD.
local ADDON = "ZeraUI"
local Tracker = ZeraUITracker
local A = { slots = {}, nativeAlpha = {}, nativeAlphaWatch = {}, nativeAlphaCount = 0, nativeWatchCount = 0, animated = {}, animCount = 0, procSlots={}, procCount = 0, loopSlots={}, loopCount = 0, pressAnims={}, pressCount = 0, togglePulses={}, togglePulseCount = 0, iconTransitions={}, iconTransCount = 0, fillSlots={}, fillCount = 0, lastSynergy = nil, hotkeys = {}, hudVisualGen = 0 }
local TWO_PI = 2 * math.pi
local GOLD_LOOP_UV = {}
for f=0,31 do
    local col,row=f%8,math.floor(f/8)
    GOLD_LOOP_UV[f]={col/8,(col+1)/8,row/4,(row+1)/4}
end
local function mapSet(tbl,key,val,field)
    local had=tbl[key]~=nil
    if val~=nil then
        tbl[key]=val
        if not had then A[field]=A[field]+1 end
    elseif had then
        tbl[key]=nil
        A[field]=A[field]-1
    end
end
local WM, EM = WINDOW_MANAGER, EVENT_MANAGER
local PATH = ADDON .. "/textures/"
local SIZE, PITCH, GAP = 64, 66, 2
local INSET, INNER = 4, 56
local CAST_WIDTH, CAST_HEIGHT, CAST_LEFT = 328, 31, 30
local CAST_TRACK = CAST_WIDTH-CAST_LEFT-2
-- Exhausting Fatecarver morph aliases for preserving its existing skill-icon
-- decimal countdown mirror (channel duration itself comes natively from
-- ACTION_RESULT_BEGIN hitValue).
local EXHAUSTING_FATECARVER={[183122]=true,[193397]=true}
local PRIMARY, BACKUP = HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP
-- Defaults, migrations, and font catalog live in Defaults.lua and Fonts.lua.
-- Slot-duration data may depend on ESO's timer setting even while its bar is
-- hidden. While enabled, keep it on; restore the previous value on disable.
function A:SyncNativeTimers()
    if not (GetSetting and SetSetting and SETTING_TYPE_UI and UI_SETTING_SHOW_ACTION_BAR_TIMERS) then return end
    local s=self.settings
    if self.syncingNativeTimers then return end
    self.syncingNativeTimers=true
    if s.nativeTimersRestore then
        -- If the player already turned timers back on, their newer choice wins.
        local current=GetSetting(SETTING_TYPE_UI,UI_SETTING_SHOW_ACTION_BAR_TIMERS)
        if tonumber(current)==0 and tonumber(s.nativeTimersRestore)~=0 then
            SetSetting(SETTING_TYPE_UI,UI_SETTING_SHOW_ACTION_BAR_TIMERS,s.nativeTimersRestore)
        end
        s.nativeTimersRestore=nil
    end
    local current=GetSetting(SETTING_TYPE_UI,UI_SETTING_SHOW_ACTION_BAR_TIMERS)
    if s.enabled and not self.gamepadSuspended then
        if tonumber(current)==0 then
            if s.forceTimersRestore==nil then s.forceTimersRestore=tostring(current) end
            SetSetting(SETTING_TYPE_UI,UI_SETTING_SHOW_ACTION_BAR_TIMERS,"1")
        end
    elseif s.forceTimersRestore~=nil then
        if tonumber(current)==1 then SetSetting(SETTING_TYPE_UI,UI_SETTING_SHOW_ACTION_BAR_TIMERS,s.forceTimersRestore) end
        s.forceTimersRestore=nil
    end
    self.syncingNativeTimers=nil
end
-- IsHidden can include a parent's visibility during a scene transition.
-- Own the label's local hidden flag instead: sibling contours must follow
-- the label even while their common parent is hidden by the game menu.
local function locallyHidden(control)
    if control.IsControlHidden then return control:IsControlHidden() end
    return control:IsHidden()
end
local function labelHidden(label,hidden)
    if locallyHidden(label)~=hidden then label:SetHidden(hidden) end
end
-- Opened windows go in front of the HUD, which shares their draw tier;
-- otherwise the newest window only comes forward after a click.
function A.RaiseWindow(w)
    if w and w.BringWindowToTop then pcall(w.BringWindowToTop,w) end
end
-- The HUD can be shown after a window opened (ESO enters UI mode a moment
-- later); keep any open Zera UI window in front of it.
function A:RaiseOpenWindows()
    local w=rawget(_G,"ZeraUISkillTracking")
    if w and w.IsHidden and not w:IsHidden() then A.RaiseWindow(w) end
end
if ZO_CreateStringId then ZO_CreateStringId("SI_BINDING_NAME_ZERA_UI_SETTINGS","Open Zera UI settings") end
local function clamp(x) return math.max(0, math.min(1, x or 0)) end
local function boundedSize(value,default,minSize,maxSize)
    local n=tonumber(value)
    if not n or n~=n or n==math.huge or n==-math.huge then n=tonumber(default) or minSize end
    if n~=n or n==math.huge or n==-math.huge then n=minSize end
    return math.max(minSize,math.min(maxSize,math.floor(n+.5)))
end
local function seconds(ms) return math.max(0, (ms or 0) / 1000) end
-- Native action-slot totals can exceed the skill's whole-second tooltip
-- duration by a few hundred milliseconds. Limit only the opening integer
-- display when both durations are known and differ by at most 500 ms.
-- Keep the actual expiry, decimals, fractional skill durations and custom
-- effect timers untouched. Ignore ten nanoseconds of float boundary noise.
local function wholeSeconds(t,durationMs,skillDurationMs)
    local n=math.ceil(t>0.00000001 and t-0.00000001 or t)
    if type(durationMs)=="number" and durationMs>0 then
        local remainingMs=t*1000
        if type(skillDurationMs)=="number" and skillDurationMs>0 and skillDurationMs%1000==0
            and durationMs>skillDurationMs and durationMs<=skillDurationMs+500
            and remainingMs>skillDurationMs and remainingMs<=durationMs+0.00001 then
            local nominal=skillDurationMs/1000
            if n>nominal then n=nominal end
        elseif remainingMs>durationMs and remainingMs<=durationMs+500 then
            local rounded=durationMs>0.00001 and durationMs-0.00001 or durationMs
            local ceiling=math.ceil(rounded/1000)
            if n>ceiling then n=ceiling end
        end
    end
    return n
end
local function timeText(t,durationMs,skillDurationMs)
    if t <= 0 then return "" end
    if t <= A.settings.decimalSeconds then return string.format("%.1f", t) end
    return tostring(wholeSeconds(t,durationMs,skillDurationMs))
end
local function place(c, w, h, x, y, parent)
    c:SetDimensions(w, h)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    return c
end
local function texture(parent, file, w, h, x, y, level)
    local c = WM:CreateControl(nil, parent, CT_TEXTURE)
    place(c,w,h,x,y,parent)
    if file then c:SetTexture(file) end
    c:SetDrawLayer(DL_CONTROLS)
    c:SetDrawLevel(level or 0)
    return c
end
local function text(parent, size, w, h, x, y, level)
    local c = WM:CreateControl(nil,parent,CT_LABEL)
    place(c,w,h,x,y,parent)
    c:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline",size))
    c:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    c:SetDrawLayer(DL_CONTROLS)
    c:SetDrawLevel(level or 8)
    c.vabOwner=parent
    c:SetColor(1,1,1,1)
    return c
end
local function panel(parent,w,h,x,y)
    local c = WM:CreateControl(nil,parent,CT_CONTROL)
    return place(c,w,h,x,y,parent)
end
-- Use native ESO text controls for every number. In 0.9.0 the glyph
-- textures parented under labels did not render in the live game.
local function color(t,r,g,b,a)
    a=a or 1
    local previous=t.vabColor
    if t.vabOwner and previous and previous[1]==r and previous[2]==g and previous[3]==b and previous[4]==a then return end
    t:SetColor(r,g,b,a)
    if t.vabOwner then
        if previous then
            previous[1],previous[2],previous[3],previous[4]=r,g,b,a
        else
            t.vabColor={r,g,b,a}
        end
    end
end
local function paint(t,c) color(t,c[1],c[2],c[3],c[4]) end
local function reposition(c,parent,x,y)
    c:ClearAnchors(); c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
end
-- Center-anchored two-pass effect: fixed hot edge plus expanding outline.
-- Render uses the current frame time, independent of the API polling rate.
local function glowControls(s,p,x,y,base,isRound)
    local name = isRound and "ringglow.dds" or "glow.dds"
    local outer = isRound and "ringwave.dds" or "wave.dds"
    s.glowSize=base
    s.glow=texture(p,PATH..name,base,base,0,0,5)
    s.wave=texture(p,PATH..outer,base,base,0,0,4)
    local burstSize=isRound and base-20 or base-26
    s.burst=texture(p,PATH..(isRound and "ringburst.dds" or "burst.dds"),burstSize,burstSize,0,0,4)
    for _,t in ipairs({s.glow,s.wave,s.burst}) do
        t:ClearAnchors(); t:SetAnchor(CENTER,p,TOPLEFT,x,y)
        t:SetAlpha(0); t:SetHidden(true)
    end
end
-- Exact ability key (including all three Scribing scripts), never bar position.
-- Sparse rules inherit live global defaults; no extra timers or allocations.
function A:SkillOption(slot,key)
    local rule=not self.preview and slot.visualKey and self.settings.skillVisualRules and self.settings.skillVisualRules[slot.visualKey]
    if rule and rule[key]~=nil then return rule[key] end
    if key=="loopStacks" and not self.preview and slot.nwSlot and self.settings.showNothingWasted then return 10 end
    return self.settings[key]
end
local function syncSlotOptions(s)
    local nw=s.nwSlot==true
    local preview=A.preview==true
    if s.skillOptGen==A.hudVisualGen and s.skillOptKey==s.abilityKey and s.skillOptVisual==s.visualKey and s.skillOptNw==nw and s.skillOptPreview==preview then return end
    s.skillOptGen,s.skillOptKey,s.skillOptVisual,s.skillOptNw,s.skillOptPreview=A.hudVisualGen,s.abilityKey,s.visualKey,nw,preview
    s.optLoopInactive=A:SkillOption(s,"loopInactive")
    s.optExpiryLoop=A:SkillOption(s,"expiryLoop")
    s.optLoopSeconds=A:SkillOption(s,"loopSeconds")
    s.optStackLoop=A:SkillOption(s,"stackLoop")
    s.optLoopStacks=A:SkillOption(s,"loopStacks")
end
local function flash(slot,expiry,soft)
    if not A.settings.animations then return end
    -- Set widget tiles have their own switch (setCooldownProcFlash).
    if expiry and not slot.widget and not A:SkillOption(slot,"expiryGlow") then return end
    if not expiry and slot.abilityKey and not A:SkillOption(slot,"pressFlash") then return end
    if soft then
        color(slot.glow,1,.78,.24); color(slot.wave,1,.78,.24); color(slot.burst,1,.78,.24)
    elseif slot.whipFlash then
        paint(slot.glow,A.settings.glowColor); paint(slot.wave,A.settings.glowColor); paint(slot.burst,A.settings.glowColor)
    end
    slot.whipFlash=soft or nil
    local strength=A.settings.glowStrength*(soft and .80 or 1)
    -- A new flash writes its initial values directly; invalidate the render cache.
    slot.lastFlashGlow,slot.lastFlashSize,slot.lastFlashWave,slot.lastFlashBurst=nil,nil,nil,nil
    slot.flashAt=GetFrameTimeMilliseconds()
    slot.flashExpiry=expiry or false
    mapSet(A.animated,slot,true,"animCount")
    slot.glow:SetHidden(false); slot.wave:SetHidden(false)
    slot.burst:SetHidden(false); slot.burst:SetAlpha(.3*A.settings.burstStrength*strength)
    slot.glow:SetAlpha(.95*strength); slot.wave:SetAlpha(0)
    slot.wave:SetDimensions(slot.glowSize,slot.glowSize)
end
local function clearFlash(slot)
    slot.glow:SetAlpha(0); slot.wave:SetAlpha(0)
    slot.burst:SetAlpha(0); slot.burst:SetHidden(true)
    slot.glow:SetHidden(true); slot.wave:SetHidden(true)
    if slot.whipFlash then
        paint(slot.glow,A.settings.glowColor); paint(slot.wave,A.settings.glowColor); paint(slot.burst,A.settings.glowColor); slot.whipFlash=nil
    end
    mapSet(A.animated,slot,nil,"animCount")
end
-- Pressed-button feedback: the icon and its duration fill sink a few pixels
-- into the frame and a pale bevel fades out (about 200 ms). Geometry is only
-- touched while the animation runs; the timer text and frame stay put.
local PRESS_MS,PRESS_DEPTH=200,3
local function startPress(slot)
    if not A.settings.pressSink or not slot.pressRing then return end
    local now=GetFrameTimeMilliseconds()
    local running=A.pressAnims[slot]
    if running and now-running<PRESS_MS*.6 then return end
    mapSet(A.pressAnims,slot,now,"pressCount")
    slot.pressRing:SetHidden(false)
end
local function setPressDepth(slot,d)
    if slot.pressDepth==d then return end
    slot.pressDepth=d
    local inner=INNER-2*d
    slot.icon:SetDimensions(inner,inner)
    if slot.icon.SetAnchorOffsets then slot.icon:SetAnchorOffsets(INSET+d,INSET+d)
    else slot.icon:ClearAnchors(); slot.icon:SetAnchor(TOPLEFT,slot.container,TOPLEFT,INSET+d,INSET+d) end
    slot.fill:SetWidth(inner)
    if slot.fill.SetAnchorOffsets then slot.fill:SetAnchorOffsets(INSET+d,-(INSET+d))
    else slot.fill:ClearAnchors(); slot.fill:SetAnchor(BOTTOMLEFT,slot.container,BOTTOMLEFT,INSET+d,-(INSET+d)) end
    slot.pressInner=d>0 and inner or nil
    if slot.lastHeight then
        local h=math.min(slot.lastHeight,inner); slot.fill:SetHeight(math.max(.1,h))
    end
end
local function renderPress(slot,start,now)
    local elapsed=now-start
    if elapsed>=PRESS_MS then
        setPressDepth(slot,0); slot.pressRing:SetAlpha(0); slot.pressRing:SetHidden(true)
        mapSet(A.pressAnims,slot,nil,"pressCount"); return
    end
    local k=elapsed<60 and elapsed/60 or elapsed<110 and 1 or 1-(elapsed-110)/(PRESS_MS-110)
    k=k*k*(3-2*k)
    setPressDepth(slot,math.floor(PRESS_DEPTH*k*2+.5)/2)
    slot.pressRing:SetAlpha(.7*(1-elapsed/PRESS_MS)^1.4)
end
local function renderFlash(slot,now,pressMs,expiryMs,glowStrength,burstStrength)
    local elapsed=now-slot.flashAt
    if elapsed<0 then elapsed=0 end
    local expiry=slot.flashExpiry
    local life=expiry and (expiryMs or A.settings.expiryMs) or (pressMs or A.settings.pressMs)
    if elapsed>=life then clearFlash(slot); return end
    local strength=(glowStrength or A.settings.glowStrength)*(slot.whipFlash and .80 or 1)
    local hold=life*(expiry and .33 or .42)
    -- Keep exact original curves and values; inline bounds and skip inactive phases.
    local glow=elapsed<hold and strength or (1-(elapsed-hold)/(life-hold))^1.22*strength
    if slot.lastFlashGlow~=glow then slot.lastFlashGlow=glow; slot.glow:SetAlpha(glow) end
    local waveStart=life*.20
    if elapsed>waveStart then
        local p=(elapsed-waveStart)/(life*.80)
        local inv=1-p
        local size=slot.glowSize*(1+(expiry and .55 or .66)*(1-inv*inv))
        if slot.lastFlashSize~=size then slot.lastFlashSize=size; slot.wave:SetDimensions(size,size) end
        local wave=.76*inv^1.3*strength
        if slot.lastFlashWave~=wave then slot.lastFlashWave=wave; slot.wave:SetAlpha(wave) end
    else
        if slot.lastFlashSize~=slot.glowSize then slot.lastFlashSize=slot.glowSize; slot.wave:SetDimensions(slot.glowSize,slot.glowSize) end
        if slot.lastFlashWave~=0 then slot.lastFlashWave=0; slot.wave:SetAlpha(0) end
    end
    local t=elapsed/(life>1 and life or 1)
    if t<.45 then
        local burst=t<.14 and (.28+.72*t/.14) or (1-(t-.14)/.31)^2
        local burstAlpha=burst*(burstStrength or A.settings.burstStrength)*strength
        if slot.lastFlashBurst~=burstAlpha then slot.lastFlashBurst=burstAlpha; slot.burst:SetAlpha(burstAlpha) end
    elseif slot.lastFlashBurst~=0 then
        slot.lastFlashBurst=0; slot.burst:SetAlpha(0)
    end
end
local function makeSlot(parent,x,y)
    local s = {}
    s.container = panel(parent,SIZE,SIZE,x,y)
    local p = s.container
    texture(p,PATH .. "square.dds",SIZE,SIZE,0,0,0)
    s.icon = texture(p,nil,INNER,INNER,INSET,INSET,1)
    s.iconHidden = false
    s.fill = texture(p,PATH .. "fill.dds",INNER,INNER,INSET,INSET,2)
    s.fillHidden = false
    s.fill:ClearAnchors()
    s.fill:SetAnchor(BOTTOMLEFT,p,BOTTOMLEFT,INSET,-INSET)
    s.frame = texture(p,PATH .. "frame.dds",SIZE,SIZE,0,0,3)
    glowControls(s,p,SIZE/2,SIZE/2,SIZE+26,false)
    s.proc=texture(p,PATH.."procglow.dds",SIZE+20,SIZE+20,-10,-10,6)
    s.proc:SetHidden(true)
    s.toggleGlow=texture(p,PATH.."toggleglow.dds",SIZE,SIZE,0,0,6)
    s.toggleGlow:SetHidden(true)
    -- Solid gold edge under the travelling loop light: makes the warning
    -- readable at a glance instead of a thin moving highlight only.
    -- Two stacked glow lines give a thick border that glows outward and
    -- leaves the icon itself untinted.
    s.goldBase=texture(p,PATH.."glow.dds",SIZE+34,SIZE+34,-17,-17,6)
    s.goldBase:SetColor(1,.76,.22,1); s.goldBase:SetHidden(true)
    s.goldBase2=texture(p,PATH.."glow.dds",SIZE+30,SIZE+30,-15,-15,6)
    s.goldBase2:SetColor(1,.76,.22,1); s.goldBase2:SetHidden(true)
    s.goldLoop=texture(p,PATH.."goldloop.dds",82,82,-9,-9,7)
    s.goldLoop:SetTextureCoords(0,1/8,0,1/4); s.goldLoop:SetHidden(true)
    -- Pale bevel shown while the button is pressed in.
    s.pressRing=texture(p,PATH.."procglow.dds",SIZE+10,SIZE+10,-5,-5,8)
    s.pressRing:SetColor(.95,.90,.76,1); s.pressRing:SetAlpha(0); s.pressRing:SetHidden(true)
    s.timer = text(p,A.settings.timerSize,SIZE,SIZE,0,1,15)
    s.stackBadge=texture(p,PATH.."stackbadge.dds",26,24,SIZE-28,2,17)
    s.stackBadge:SetHidden(true); s.stackBadgeHidden=true
    s.stack = text(p,A.settings.stackSize,26,24,SIZE-28,1,19)
    color(s.stack,.44,.82,1)
    s.target=text(p,16,20,20,1,1,9)
    s.estimate = text(p,16,20,20,22,1)
    color(s.estimate,1,.82,.28); s.estimate:SetText("~"); s.estimate:SetHidden(true)
    s.extraTimers={}
    s.expiryActive={}
    for i=2,3 do
        local label=text(p,16,30,20,i==2 and 1 or SIZE-31,SIZE-20,10)
        if i==2 then color(label,.40,.90,1) else color(label,1,.82,.30) end
        label:SetHidden(true); s.extraTimers[i]=label
    end
    return s
end
-- Native circular clipping uses screen-space rects (the same convention
-- as ESO's ZO_RevealingControl). A move/scale/layout event refreshes the
-- clip, never Tick or Render. Keep strips as a compatibility fallback.
local function circleIconPieces(parent,iconSize)
    if parent.SetCircularClip then
        local icon=texture(parent,nil,iconSize,iconSize,0,0,1)
        local function clip(control,left,top,right,bottom)
            if not (left and top and right and bottom) or right<=left or bottom<=top then return end
            local x,y,r=(left+right)/2,(top+bottom)/2,math.min(right-left,bottom-top)/2
            if control.clipX==x and control.clipY==y and control.clipRadius==r then return end
            control:SetCircularClip(x,y,r)
            control.clipX,control.clipY,control.clipRadius=x,y,r
        end
        local function refresh(control)
            clip(control,control:GetLeft(),control:GetTop(),control:GetRight(),control:GetBottom())
        end
        if icon.SetCircularClip and icon.SetHandler and icon.GetLeft and icon.GetTop and icon.GetRight and icon.GetBottom then
            local ok=pcall(icon.SetCircularClip,icon,0,0,1)
            if ok then
                icon:SetHandler("OnRectChanged",clip)
                icon:SetHandler("OnEffectivelyShown",refresh)
                refresh(icon)
                return {icon}
            end
        end
        icon:SetHidden(true)
    end
    local strips=math.min(32,math.ceil(iconSize/2))
    local function edge(i)
        local dy=math.abs((i+.5)/strips-.5)*2
        return math.floor((.5-math.sqrt(math.max(0,1-dy*dy))/2)*iconSize+.5)
    end
    local result,j={},0
    while j<strips do
        local inset=edge(j); local last=j+1
        while last<strips and edge(last)==inset do last=last+1 end
        local top,bottom=j/strips,last/strips
        local left,right=inset/iconSize,1-inset/iconSize
        if right>left then
            local piece=texture(parent,nil,iconSize*(right-left),iconSize*(bottom-top),iconSize*left,iconSize*top,1)
            piece:SetTextureCoords(left,right,top,bottom)
            piece.vabUV={left,right,top,bottom}
            result[#result+1]=piece
        end
        j=last
    end
    return result
end
local function makeMeter(parent,x,y,size,key,isUltimate)
    local m = { size = size }
    m.container = panel(parent,size,size,x,y)
    local p = m.container
    m.base = texture(p,PATH .. "circle.dds",size,size,0,0,0)
    -- Crop arbitrary game textures to a disc using native circular clipping
    -- when supported and matching UV strips otherwise.
    local iconSize = math.floor(size*.84)
    local origin=(size-iconSize)/2
    m.icon=panel(p,iconSize,iconSize,origin,origin)
    m.iconHidden=false
    if isUltimate then
        -- Two fixed icon banks per meter. Populate during binding refresh;
        -- normal role swaps merely switch visibility, avoiding reuploading
        -- every cropped texture strip. The geometry is identical.
        m.iconBanks={}
        for i=1,2 do
            local bank=panel(m.icon,iconSize,iconSize,0,0)
            bank:SetHidden(i~=1)
            m.iconBanks[i]={control=bank,slices=circleIconPieces(bank,iconSize)}
        end
        m.iconBankIndex=1
        m.iconSlices=m.iconBanks[1].slices
    else
        m.iconSlices=circleIconPieces(m.icon,iconSize)
    end
    m.aura=texture(p,PATH.."readyaura.dds",size*1.28,size*1.28,-size*.14,-size*.14,0)
    m.aura:SetHidden(true)
    m.arc = texture(p,PATH .. (isUltimate and "ultarc.dds" or "arc.dds"),size,size,0,0,isUltimate and 3 or 2)
    if isUltimate then
        m.activeRing=texture(p,PATH.."ultactive.dds",size*1.18,size*1.18,-size*.09,-size*.09,2)
        m.activeRing:SetHidden(true)
        -- "Gapless bright core" Overload: a soft halo and a dark edge under
        -- the colored ring, a white core over it, in a larger frame than the
        -- classic ring. Built once here, never in combat.
        m.ringSize=size; m.ringParent=p
        m.lightGlow=texture(p,PATH.."ultlightningglow.dds",size*1.6,size*1.6,-size*.3,-size*.3,0)
        m.lightGlow:SetHidden(true)
        m.lightEdge=texture(p,PATH.."ultlightningedge.dds",size*1.26,size*1.26,-size*.13,-size*.13,1)
        m.lightEdge:SetColor(.02,.04,.11,1); m.lightEdge:SetHidden(true)
        m.lightCore=texture(p,PATH.."ultlightninggapless.dds",size*1.26,size*1.26,-size*.13,-size*.13,3)
        m.lightCore:SetColor(1,1,1,1); m.lightCore:SetHidden(true)
    end
    glowControls(m,p,size/2,size/2,size+20,true)
    m.value = text(p,math.floor(size*.26),size,size,0,0,15)
    m.sub = text(p,12,size,16,0,size*.73,15)
    m.key = text(p,13,size,18,0,size+2)
    m.key:SetText(key or "")
    A.hotkeys[#A.hotkeys+1]=m.key
    return m
end
local function meterAura(m,on,r,g,b,strength)
    on=on and A.settings.ringBloom
    if m.auraOn~=on then m.aura:SetHidden(not on); m.auraOn=on end
    if on and (m.auraR~=r or m.auraG~=g or m.auraB~=b or m.auraStrength~=strength) then
        color(m.aura,r,g,b,strength or .8); m.auraR,m.auraG,m.auraB,m.auraStrength=r,g,b,strength
    end
end
local function arc(m,f,r,g,b,a)
    local i = math.floor(clamp(f)*255+.5)
    local col,row = i%16,math.floor(i/16)
    if m.lastArc ~= i then
        m.arc:SetTextureCoords(col/16,(col+1)/16,row/16,(row+1)/16)
        m.lastArc = i
    end
    a=a or 1
    if m.arcR~=r or m.arcG~=g or m.arcB~=b or m.arcA~=a then
        color(m.arc,r,g,b,a); m.arcR,m.arcG,m.arcB,m.arcA=r,g,b,a
    end
end
local TOGGLE_PULSE_GROUPS={overload=true,cloak=true,frenzy=true,simmering=true,sated=true,guard=true,banner=true,mend=true,mendspirit=true,symbiosis=true,meditate=true,deepthoughts=true,introspection=true}
function A:TogglePulseEnabled(group)
    return TOGGLE_PULSE_GROUPS[group] and self.settings.toggleGlow and self.settings.togglePulse
end
function A:SetTogglePulse(control,active,strength)
    if active then
        mapSet(self.togglePulses,control,strength,"togglePulseCount")
    else
        mapSet(self.togglePulses,control,nil,"togglePulseCount")
        if control.vabToggleAlpha~=strength then control:SetAlpha(strength); control.vabToggleAlpha=strength end
    end
end
local function ultimateRing(m,active,charge,ready,toggleGroup)
    local normal=A.settings.ultimateColor
    local toggle=toggleGroup and A.settings.toggleGlow
    local overload=toggleGroup=="overload"
    local lightning=overload and toggle
    local running=toggle and A.settings.togglePulseColor or A.settings.activeUltColor
    active=active or not not toggle
    local containerHidden=m.container:IsHidden()
    local gold=ready and not overload and A.settings.ultimateReadyGlow and A.settings.animations and not containerHidden
    local showRing=active or gold
    if m.isActiveRing~=showRing then
        m.activeRing:SetHidden(not showRing)
        m.isActiveRing=showRing
    end
    A:SetTogglePulse(m.activeRing,not containerHidden and ((toggle and A:TogglePulseEnabled(toggleGroup)) or (gold and not active)),toggle and A.settings.toggleGlowStrength or 1)
    -- Swap the existing active-ring texture, never create another control
    -- during combat. Overload is a distinct state even if its cost is met.
    local gapless=lightning and A.settings.overloadStyle=="Gapless"
    local ringTexture=lightning and (gapless and "ultlightningbold.dds" or "ultlightning.dds") or "ultactive.dds"
    local extras=gapless and showRing or false
    if m.lightExtras~=extras then
        m.lightEdge:SetHidden(not extras); m.lightCore:SetHidden(not extras); m.lightGlow:SetHidden(not extras); m.lightExtras=extras
    end
    if m.activeTexture~=ringTexture then
        m.activeRing:SetTexture(PATH..ringTexture)
        m.activeTexture=ringTexture
        -- The gapless ring is drawn larger; only on a style change.
        local scale=ringTexture=="ultlightningbold.dds" and 1.26 or 1.18
        if m.activeScale~=scale then
            local size=m.ringSize
            m.activeRing:SetDimensions(size*scale,size*scale)
            m.activeRing:ClearAnchors()
            m.activeRing:SetAnchor(TOPLEFT,m.ringParent,TOPLEFT,-size*(scale-1)/2,-size*(scale-1)/2)
            m.activeScale=scale
        end
    end
    local rotate=lightning and A.settings.animations and A:TogglePulseEnabled(toggleGroup) and not containerHidden
    if m.lightningRotating and not rotate then
        if m.activeRing.SetTextureRotation then
            m.activeRing:SetTextureRotation(0); m.lightEdge:SetTextureRotation(0); m.lightCore:SetTextureRotation(0); m.lightGlow:SetTextureRotation(0)
        end
        m.lightningStep=nil
    end
    m.lightningRotating=rotate
    if showRing then
        -- An active-effect glow is independent of the gold charge arc.
        local ringColor=active and running or normal
        if m.activeRingColor~=ringColor then
            paint(m.activeRing,ringColor)
            m.lightGlow:SetColor(ringColor[1],ringColor[2],ringColor[3],1)
            m.activeRingColor=ringColor
        end
    end
    arc(m,charge,normal[1],normal[2],normal[3],normal[4])
    local c=gold and normal or (active and running or normal)
    -- While Overload is active the blue ring owns the entire glow layer.
    -- Keep the metallic charge arc and numerical resource value unchanged.
    meterAura(m,active or (ready and not overload),c[1],c[2],c[3],gold and .95 or (active and .45 or .68))
    A:SetTogglePulse(m.aura,gold and A.settings.ringBloom,1)
end
-- The engine may return the current weapon's elemental icon for an inactive
-- destruction-staff bar. Preserve the actual icon observed on that bar while
-- it was active, including any equipped skill style. Never reuse it after a
-- different wall morph or weapon type is equipped.
local WALL_ICON_FAMILY={
    [28858]=1,[28807]=1,[28854]=1,[28849]=1,
    [39052]=2,[39053]=2,[39073]=2,[39067]=2,
    [39011]=3,[39012]=3,[39018]=3,[39028]=3,
}
local function wallWeapon(category)
    if not GetItemWeaponType or BAG_WORN==nil then return end
    local equip=category==PRIMARY and EQUIP_SLOT_MAIN_HAND or category==BACKUP and EQUIP_SLOT_BACKUP_MAIN
    if equip==nil then return end
    local weapon=GetItemWeaponType(BAG_WORN,equip)
    if (WEAPONTYPE_FIRE_STAFF and weapon==WEAPONTYPE_FIRE_STAFF) or
       (WEAPONTYPE_FROST_STAFF and weapon==WEAPONTYPE_FROST_STAFF) or
       (WEAPONTYPE_LIGHTNING_STAFF and weapon==WEAPONTYPE_LIGHTNING_STAFF) then return weapon end
end
local function setIcon(s,slot,category,warmOnly,sampledRaw,sampledTexture)
    local icon = sampledTexture
    if s.iconBanks then
        local index=category==BACKUP and 2 or 1
        local bank=s.iconBanks[index]
        -- During the native swap grace, a known category icon is more
        -- reliable than an outgoing texture sample. Settlement revalidates.
        if not warmOnly and A.swapPending and bank.category==category and bank.path then icon=bank.path
        elseif icon==nil then icon=GetSlotTexture(slot,category) end
        if icon and icon~="" then
            if bank.path~=icon then
                for _,piece in ipairs(bank.slices) do
                    local uv=piece.vabUV; piece:SetTexture(icon); if uv then piece:SetTextureCoords(uv[1],uv[2],uv[3],uv[4]) end
                end
                bank.path=icon
            end
        else bank.path=nil end
        bank.category=category
        if warmOnly then return icon or false end
        if s.iconBankIndex~=index then
            s.iconBanks[s.iconBankIndex].control:SetHidden(true)
            bank.control:SetHidden(false)
            s.iconBankIndex=index; s.iconSlices=bank.slices
        end
        if s.desaturation~=nil and bank.desaturation~=s.desaturation then
            for _,piece in ipairs(bank.slices) do piece:SetDesaturation(s.desaturation) end
            bank.desaturation=s.desaturation
        end
        s.iconPath=bank.path
        local hidden=not bank.path
        if s.iconHidden~=hidden then s.iconHidden=hidden; s.icon:SetHidden(hidden) end
        return icon or false
    end
    if icon==nil then icon=GetSlotTexture(slot,category) end
    local id=(category==PRIMARY or category==BACKUP) and slot>=3 and slot<=7 and GetSlotBoundId and (sampledRaw or GetSlotBoundId(slot,category))
    local family=id and WALL_ICON_FAMILY[id]
    local weapon=family and wallWeapon(category)
    local cached=s.wallIcon
    if cached and (cached.family~=family or cached.weapon~=weapon or cached.category~=category) then
        s.wallIcon=nil; cached=nil
    end
    if family and weapon then
        if category==A.active and not A.swapPending and icon and icon~="" then
            s.wallIcon={family=family,weapon=weapon,category=category,icon=icon}
        elseif cached then
            icon=cached.icon
        end
    end
    if icon and icon ~= "" then
        if s.iconPath~=icon then
            if s.iconSlices then for _,piece in ipairs(s.iconSlices) do local uv=piece.vabUV; piece:SetTexture(icon); if uv then piece:SetTextureCoords(uv[1],uv[2],uv[3],uv[4]) end end
            else s.icon:SetTexture(icon) end
            s.iconPath=icon
        end
        if s.iconHidden~=false then s.iconHidden=false; s.icon:SetHidden(false) end
    elseif not s.iconHidden then s.iconHidden=true; s.icon:SetHidden(true) end
end
local function meterDesaturation(m,value)
    if m.desaturation==value then return end
    m.desaturation=value
    for _,piece in ipairs(m.iconSlices) do piece:SetDesaturation(value) end
    if m.iconBanks then m.iconBanks[m.iconBankIndex].desaturation=value end
end
local function ultimateIcon(m,ready)
    meterDesaturation(m,ready and 0 or .65)
    local alpha=ready and 1 or .45
    if m.ultIconAlpha~=alpha then m.icon:SetAlpha(alpha); m.ultIconAlpha=alpha end
end
local function setText(label, value)
    if label.vabText ~= value then label:SetText(value); label.vabText = value end
end
-- Badge geometry used by the HUD (font fitting lives in Fonts.lua).
local function stackCounterSize(stackSize,value)
    return math.max(24,math.min(60,math.ceil(stackSize*.76*math.max(1,#value)+10))),math.max(22,math.min(34,stackSize+6))
end
local function passiveBadgeSize(cornerSize,kind)
    local size=boundedSize(cornerSize,16,10,24)
    -- Two mastery timers must fit next to one another below Crux.
    if kind=="arcanist" then size=math.min(size,14) end
    return size,kind=="arcanist" and 30 or math.max(32,math.ceil(size*.67*3+6)),math.max(17,size+4)
end
local function recipientBadgeSize(targetSize,group)
    if group then return math.min(30,math.max(26,math.ceil(targetSize*.67*2+8))),math.max(18,targetSize+4) end
    return math.min(30,math.max(20,math.ceil(targetSize*.67*2+6))),math.max(20,targetSize+4)
end
local function stackBadgeSize(size,value)
    return math.max(15,math.min(36,math.ceil(size*.76*math.max(1,#value)+5))),math.max(14,size+3)
end
local function setStack(s,count)
    local preview=A.preview==true
    if not preview and s.suppressStack then count=0 end
    local isCharge=s.isCharge==true
    local noGlow=s.noStackGlow==true
    local readyAt=s.stackReadyAt
    local gen,fontGen=A.hudVisualGen,A.fontGeneration
    local nw=s.nwSlot==true
    if s.stackCacheCount==count and s.stackCacheCharge==isCharge and s.stackCacheNoGlow==noGlow and
        s.stackCacheReadyAt==readyAt and s.stackCachePreview==preview and
        s.stackCacheGen==gen and s.stackCacheFontGen==fontGen and
        s.stackCacheVisual==s.visualKey and s.stackCacheNw==nw then
        return
    end
    local cfg=A.settings
    s.displayedStack=count
    local value=(isCharge and cfg.showCharges or not isCharge and cfg.showStacks) and count>0 and tostring(count) or ""
    local visible=cfg.stackBadge and value~=""
    local ready=false
    if visible and not isCharge and not noGlow then
        local threshold=readyAt
        if not threshold then syncSlotOptions(s); threshold=s.optLoopStacks end
        ready=count>=threshold
    end
    if s.stackBadgeReady~=ready then
        s.stackBadge:SetTexture(PATH..(ready and "stackbadge-ready.dds" or "stackbadge.dds")); s.stackBadgeReady=ready
    end
    local badgeHidden=not visible
    if s.stackBadgeHidden~=badgeHidden then s.stackBadgeHidden=badgeHidden; s.stackBadge:SetHidden(badgeHidden) end
    if value=="" then
        setText(s.stack,"")
        s.stackCacheCount,s.stackCacheCharge,s.stackCacheNoGlow,s.stackCacheReadyAt,s.stackCachePreview,s.stackCacheGen,s.stackCacheFontGen,s.stackCacheVisual,s.stackCacheNw=count,isCharge,noGlow,readyAt,preview,gen,fontGen,s.visualKey,nw
        return
    end
    local width,height=stackCounterSize(cfg.stackSize,value)
    local _
    local size=#value<=2 and A.stackFontLimit or cfg.stackSize
    _,width=A:FitCounterText(s.stack,A.effectiveFont or A:ResolveFont(cfg.fontFace),cfg.fontStyle,true,value,size or cfg.stackSize,width,60,true)
    if s.stackBadgeWidth~=width or s.stackBadgeHeight~=height then
        s.stackBadgeWidth,s.stackBadgeHeight=width,height
        -- Grow around the original counter center, not the outer corner.
        -- Otherwise increasing the font moves the number toward the icon.
        local x,y=49-width/2,13-height/2
        s.stackBadge:SetDimensions(width,height); reposition(s.stackBadge,s.container,x,y+1)
        s.stack:SetDimensions(width,height); reposition(s.stack,s.container,x,y)
    end
    if s.stackReady~=ready or s.stackCharge~=isCharge then
        s.stackReady=ready
        s.stackCharge=isCharge
        if ready then color(s.stack,1,.89,.55) elseif isCharge then paint(s.stack,cfg.chargeColor) else paint(s.stack,cfg.stackColor) end
    end
    setText(s.stack,value)
    s.stackCacheCount,s.stackCacheCharge,s.stackCacheNoGlow,s.stackCacheReadyAt,s.stackCachePreview,s.stackCacheGen,s.stackCacheFontGen,s.stackCacheVisual,s.stackCacheNw=count,isCharge,noGlow,readyAt,preview,gen,fontGen,s.visualKey,nw
end
local function setTint(label,t,r,g,b)
    -- A fixed colour (a colour table as r): the whip's Off Balance (green)
    -- or immunity (red), never the warning thresholds.
    if type(r)=="table" then
        if label.timerTint==r then return end
        label.timerTint=r; paint(label,r); return
    end
    local state=0
    if A.settings.warningColors and t>0 then
        if t<=A.settings.lastSeconds then state=1 elseif t<=A.settings.soonSeconds then state=2 end
    end
    if label.timerTint==state then return end
    label.timerTint=state
    if state==1 then paint(label,A.settings.lastColor)
    elseif state==2 then paint(label,A.settings.soonColor)
    elseif r then color(label,r,g,b) else paint(label,A.settings.normalColor) end
end
local function setCost(label,cost,ultimate,blocked)
    local costVal=cost and cost>0 and cost or 0
    if label.lastCostVal~=costVal or label.lastCostGen~=A.hudVisualGen then
        label.lastCostVal,label.lastCostGen=costVal,A.hudVisualGen
        setText(label,costVal>0 and tostring(costVal) or "")
    end
    local ready=costVal>0 and ultimate>=costVal and not blocked or false
    if label.ready~=ready then
        paint(label,ready and A.settings.readyColor or A.settings.unreadyColor)
        label.ready=ready
    end
end
local function changeNative(control, hide, watch)
    if not control or not control.GetAlpha then return end
    if hide then
        if A.nativeAlpha[control] == nil then
            local alpha=control:GetAlpha()
            mapSet(A.nativeAlpha,control,(type(alpha)=="number" and alpha>0) and alpha or 1,"nativeAlphaCount")
        end
        if watch then mapSet(A.nativeAlphaWatch,control,true,"nativeWatchCount") end
        if control:GetAlpha()~=0 then control:SetAlpha(0) end
    elseif A.nativeAlpha[control] ~= nil then
        local saved=A.nativeAlpha[control]
        mapSet(A.nativeAlpha,control,nil,"nativeAlphaCount")
        mapSet(A.nativeAlphaWatch,control,nil,"nativeWatchCount")
        control:SetAlpha((type(saved)=="number" and saved>0) and saved or 1)
    end
end
-- An alpha-0 control is still "shown": every native ActionButton keeps its
-- per-frame OnUpdate handlers (TimerUpdate formats and SetText()s each active
-- timer, CooldownUpdate polls every slot during each GCD, FillBarUpdate for the
-- back row). Hiding the fragment for our own reason (the mechanism ESO's
-- auto-hide action bar uses) stops those handlers. Events, keybinds
-- (OnSlotDown) and the buttons' Lua state are unaffected.
local NATIVE_BAR_REASON="ZeraUI"
local function setNativeBarHidden(hidden)
    if not (ACTION_BAR_FRAGMENT and ACTION_BAR_FRAGMENT.SetHiddenForReason) then return end
    hidden=hidden and true or false
    if (A.nativeBarHidden or false)==hidden then return end
    A.nativeBarHidden=hidden
    ACTION_BAR_FRAGMENT:SetHiddenForReason(NATIVE_BAR_REASON,hidden,0,0)
end
local function restoreNative()
    setNativeBarHidden(false)
    for c,v in pairs(A.nativeAlpha) do
        c:SetAlpha((type(v)=="number" and v>0) and v or 1)
    end
    A.nativeAlpha = {}; A.nativeAlphaCount = 0
    A.nativeAlphaWatch = {}; A.nativeWatchCount = 0
end
function A:HideNative()
    -- Capture pre-hide alpha (clamped away from 0) before hiding the fragment,
    -- because ZO_HUDFadeSceneFragment:Hide(0) immediately drives ZO_ActionBar1
    -- alpha to 0 and would otherwise poison A.nativeAlpha with 0 on restore.
    changeNative(ZO_ActionBar1,true,false)
    if ZO_ActionBar1 and ZO_ActionBar1.GetNamedChild then
        for _,name in ipairs({"KeybindBG","WeaponSwap","Quickslot"}) do
            changeNative(ZO_ActionBar1:GetNamedChild(name),true,false)
        end
    end
    for i=3,8 do changeNative(_G["ActionButton"..i],true,false) end
    changeNative(_G.QuickslotButton,true,false)
    changeNative(_G.CompanionUltimateButton,true,false)
    setNativeBarHidden(true)
    if (IsPlayerInWerewolfForm and IsPlayerInWerewolfForm()) or (HOTBAR_CATEGORY_WEREWOLF~=nil and self.active==HOTBAR_CATEGORY_WEREWOLF) then
        changeNative(_G.ZO_PlayerAttributeWerewolf,true,true)
    end
    if self.settings.showSynergy and (type(GetCurrentSynergyInfo)=="function" or type(GetSynergyInfo)=="function") then
        changeNative(ZO_SynergyTopLevel or (SYNERGY and SYNERGY.control),true,true)
    end
end
-- Use ESO's slot-aware tooltip, including the inactive hotbar and scribed skills.
-- Mouse handlers are only active in cursor mode; no per-frame tooltip polling.
function A:ClearSkillTooltip(control)
    local owner=self.skillTooltipOwner
    if not owner or (control and owner~=control) then return end
    self.skillTooltipOwner=nil
    if AbilityTooltip and ClearTooltip and AbilityTooltip:GetOwner()==owner then ClearTooltip(AbilityTooltip) end
end
function A:ShowSkillTooltip(control)
    if not self.skillTooltipMouse or control:IsHidden() or not AbilityTooltip or not InitializeTooltip then return end
    local category=control.vabTooltipCategory()
    local slot=control.vabTooltipSlot
    self:ClearSkillTooltip()
    if not category or (GetSlotBoundId(slot,category) or 0)<=0 then return end
    InitializeTooltip(AbilityTooltip,control,BOTTOM,0,-6,TOP)
    -- Scribed skills have no action tooltip; show their ability instead.
    local crafted=ACTION_TYPE_CRAFTED_ABILITY and GetSlotType and GetSlotType(slot,category)==ACTION_TYPE_CRAFTED_ABILITY
    local abilityId=crafted and GetAbilityIdForCraftedAbilityId and GetAbilityIdForCraftedAbilityId(GetSlotBoundId(slot,category))
    if abilityId and abilityId>0 and AbilityTooltip.SetAbilityId then AbilityTooltip:SetAbilityId(abilityId)
    else AbilityTooltip:SetAction(slot,category) end
    self.skillTooltipOwner=control
end
function A:BindSkillTooltip(control,slot,category)
    self.skillTooltipControls=self.skillTooltipControls or {}
    self.skillTooltipControls[#self.skillTooltipControls+1]=control
    control.vabTooltipSlot=slot
    control.vabTooltipCategory=category
    control:SetMouseEnabled(false)
    control:SetHandler("OnMouseEnter",function(c) self:ShowSkillTooltip(c) end)
    control:SetHandler("OnMouseExit",function(c) self:ClearSkillTooltip(c) end)
    control:SetHandler("OnHide",function(c) self:ClearSkillTooltip(c) end)
end
function A:SyncSkillTooltips()
    if not self.skillTooltipControls then return end
    local hud=SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
    local cursor=SCENE_MANAGER:IsShowing("hudui") or (IsGameCameraUIModeActive and IsGameCameraUIModeActive())
    local allow=not not (self.settings.showSkillTooltips and self.settings.enabled and hud and cursor and not self.preview and not self.editing and not self.root:IsHidden() and not (IsInGamepadPreferredMode and IsInGamepadPreferredMode()))
    if allow==self.skillTooltipMouse then return end
    self.skillTooltipMouse=allow
    if not allow then self:ClearSkillTooltip() end
    for _,c in ipairs(self.skillTooltipControls) do c:SetMouseEnabled(allow) end
end
-- Enter (chat) or '.' switches hud -> hudui. During that switch neither
-- scene counts as showing for a moment; it is not a reason to hide the HUD
-- (hiding would also drop the target's buff and debuff grids).
local function hudScene(includeLoot)
    if SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui") or (includeLoot and SCENE_MANAGER:IsShowing("loot")) then return true end
    local nextScene=SCENE_MANAGER.GetNextScene and SCENE_MANAGER:GetNextScene()
    local name=nextScene and nextScene.GetName and nextScene:GetName()
    return name=="hud" or name=="hudui" or (includeLoot and name=="loot")
end
function A:ApplyVisibility(sceneOnly)
    local hud = hudScene()
    self.gamepadSuspended=not not (IsInGamepadPreferredMode and IsInGamepadPreferredMode())
    local allowed=self.settings.enabled and not self.gamepadSuspended and not (self.IsNativeHudEditorOpen and self:IsNativeHudEditorOpen())
    local show = not not (allowed and (hud or self.preview))
    -- Loot hides the action bar, not the player's buff/debuff display.
    -- Keep its independent scene policy and only run its tick when needed.
    local effectShow=not not (allowed and (show or hudScene(true)))
    local effectChanged=self.visibilityEffects~=effectShow
    local cursor = not not (SCENE_MANAGER:IsShowing("hudui") or (IsGameCameraUIModeActive and IsGameCameraUIModeActive()))
    local replace = not not (show and (not self.preview or self.editing) and self.settings.replaceNative)
    local cursorChanged=self.visibilityCursor~=cursor
    local unchanged=sceneOnly and self.visibilityShow==show and self.visibilityReplace==replace
        and self.visibilityEnabled==self.settings.enabled and (not not self.updating)==show
        and self.root:IsHidden()==not show
    self.visibilityShow,self.visibilityCursor,self.visibilityReplace=show,cursor,replace
    self.visibilityEffects=effectShow
    self.visibilityEnabled=self.settings.enabled
    if unchanged then
        -- SHOWING/SHOWN/HIDING/HIDDEN on neighbouring scenes may all report
        -- the same HUD policy. Do not refresh gameplay listeners or grids.
        -- UI-mode changes still need the target-freeze/tooltip interaction.
        self:SyncSkillTooltips()
        if (cursorChanged or effectChanged) and self.effectHUD then self.effectHUD:Sync(effectShow,effectShow and not show) end
        if self.SyncPlayerInteraction then self:SyncPlayerInteraction() end
        if self.SyncWidgetDrag then self:SyncWidgetDrag() end
        if replace then self:HideNative()
        elseif self.nativeBarHidden or next(self.nativeAlpha) then restoreNative() end
        if self.SyncAttributes then self:SyncAttributes(true) end
        if show then self:RaiseOpenWindows() end
        return
    end
    local wasEnabled=self.tracker.enabled
    self.tracker:SetEnabled(self.settings.enabled)
    -- Reconcile the independent follow-target listener on both /zera off and /zera on.
    self.tracker:SyncFollowTarget(self.settings.enabled and self.settings.followTargetTimers~=false)
    if self.settings.enabled and not wasEnabled and self.categories and not self.preview then
        local now=GetFrameTimeMilliseconds()
        for row=1,2 do
            local cat=self.categories[row]
            if cat and self.slots[row] then
                for i=1,5 do
                    local s=self.slots[row][i]
                    if s and s.flameSlot then self.tracker:ObservePowerLashSlot(i+2,cat,now,cat==self.active) end
                end
            end
        end
    end
    if not self.settings.enabled and self.finder then self.finder:Stop("HUD disabled"); self:CloseTrackMenu() end
    self.root:SetHidden(not show)
    self:SyncSkillTooltips()
    if self.setCooldowns then self.setCooldowns:Sync(show) end
    if self.effectHUD then self.effectHUD:Sync(effectShow,effectShow and not show) end
    if self.SyncPlayerInteraction then self:SyncPlayerInteraction() end
    if self.SyncWidgetDrag then self:SyncWidgetDrag() end
    if replace then self:HideNative()
    else restoreNative() end
    if self.SyncAttributes then self:SyncAttributes(sceneOnly) end
    if show then self:RaiseOpenWindows() end
    if show and not self.updating then
        -- Slot changes coalesced while the HUD was hidden (skills window).
        if self.slotRefreshPending and not self.preview then self:RefreshSlots(true) end
        self:ResetExpiryState()
        if self.preview then self:UpdatePreview() end
        self.updating = true
        self:SyncWerewolfMode()
        self:RefreshSynergy()
        EM:RegisterForUpdate(ADDON .. "Tick",100,function() self:Tick() end)
        self.root:SetHandler("OnUpdate",function() self:Render(GetFrameTimeMilliseconds()) end)
    elseif not show and self.updating then
        self.updating = false
        self:ClearCast()
        if self.castShown then self.cast:SetHidden(true); self.castShown=false end
        self.weaponPairLocked=GetActiveWeaponPairInfo and select(2,GetActiveWeaponPairInfo())==true or false
        EM:UnregisterForUpdate(ADDON .. "Tick")
        self.root:SetHandler("OnUpdate",nil)
        for s in pairs(self.animated) do clearFlash(s) end
        self.synergy.offer=nil; self:WatchSynergy(nil); self:HideSynergyImmediate()
        self:ResetExpiryState()
    end
    -- A visible HUD owns its own work. If it disappears before consuming a
    -- queued slot change, hand off to one named hidden-HUD update instead.
    if self.slotRefreshPending or self.swapPending or self.slotWorkDue then self:ScheduleSlotWork() end
end
function A:GamepadModeChanged()
    self.gamepadSuspended=not not (IsInGamepadPreferredMode and IsInGamepadPreferredMode())
    if self.gamepadSuspended then
        if self.editing then self:FinishEdit(false,true) end
        if self.preview then self:Command("preview") end
        self:CloseTrackMenu()
        if self.finder then self.finder:Stop("Gamepad mode") end
    end
    self:ApplyVisibility()
    self:SyncNativeTimers()
end
local function clearEmptySlot(self,s)
    setText(s.timer,""); s.timerTextMode="zero"; s.timerWholeSec=nil; s.timerVisualGen=nil
    if s.estimatedShown then labelHidden(s.estimate,true); s.estimatedShown=false end
    if not s.fillHidden then s.fillHidden=true; s.fill:SetHidden(true) end
    mapSet(self.fillSlots,s,nil,"fillCount")
    s.isCharge=false
    setStack(s,0)
    self:SetToggle(s,false); self:SetProc(s,false); self:SetGoldLoop(s,false)
    self:ShowTargetCount(s,""); s.lastTargetCountVal=0
    if s.auxCount or s.landslideLabel then self:AuxiliaryCount(s,nil) end
    if s.passiveBadges then self:ShowPassiveBadges(s,nil,nil,nil,nil,nil) end
    for idx=2,3 do
        local lbl=s.extraTimers[idx]
        if lbl.vabVisible~=false then labelHidden(lbl,true); lbl.vabVisible=false end
        s.expiryActive[idx]=nil
    end
end
function A:ResetExpiryState()
    self.hudVisualGen=(self.hudVisualGen or 0)+1
    self.quickRenderAt=nil; self.quickRenderIdle=nil
    if self.ultimate then local m=self.ultimate; m.durHidden=nil; m.wwControlsShown=nil; m.furyHidden=nil; m.primaryCostHidden=nil end
    if self.secondary then local m=self.secondary; m.durHidden=nil; m.wwControlsShown=nil; m.furyHidden=nil; m.primaryCostHidden=nil end
    for _,row in ipairs(self.slots) do for _,slot in ipairs(row) do
        -- State events may have arrived while the custom HUD was hidden.
        slot.appearanceDirty=true
        slot.expiryActive={}
        slot.whipTimerKind=nil
        if slot.whipFlash then clearFlash(slot) end
        if slot.goldLoop then slot.goldLoop:SetAlpha(1) end
        if slot.goldLoop then self:SetGoldLoop(slot,false) end
        if slot.timer and not slot.abilityId and not self.preview then clearEmptySlot(self,slot) end
    end end
end
function A:ResetCorpseState()
    for _,row in ipairs(self.slots) do for _,slot in ipairs(row) do slot.corpseBlocked=nil; slot.targetBlocked=nil; slot.targetBlockReason=nil; slot.resourceBlocked=nil; slot.requirementBlocked=nil; slot.appearanceHasStack=nil; slot.appearanceDirty=true end end
    self.resourcePools=nil
end
function A:ResetReticleSkillState()
    for rowIndex,row in ipairs(self.slots) do for _,s in ipairs(row) do
        if rowIndex==self.activeRow and (s.targetKind or s.corpseRequired or s.focusTarget or s.targetBlocked) then s.appearanceDirty=true end
        -- Keep the shown dark/bright state until it is re-evaluated: clearing
        -- it here lit the icon for up to one tick before it darkened again.
        s.lastRangeKey=nil
        -- Default follow-target mode (nil per-skill policy) also
        -- changes the displayed timer without an actual effect expiry.
        if self.tracker:CanFollowTarget(s) then s.expiryActive[1]=nil end
        for i,rule in ipairs(s.track or {}) do
            if self.tracker:TimerPolicy(s,rule)=="target" then s.expiryActive[i]=nil end
        end
    end end
end
function A:StyleIcon(slot,desaturation,alpha,instant)
    if slot.desatTarget==desaturation and slot.alphaTarget==alpha and not (instant and self.iconTransitions[slot]) and (self.settings.swapFade and self.settings.animations or not self.iconTransitions[slot]) then return end
    slot.desatTarget,slot.alphaTarget=desaturation,alpha
    if instant or not self.settings.swapFade or not self.settings.animations or slot.desatNow==nil then
        slot.desatNow,slot.alphaNow=desaturation,alpha
        slot.icon:SetDesaturation(desaturation); slot.icon:SetAlpha(alpha); mapSet(self.iconTransitions,slot,nil,"iconTransCount")
    else
        mapSet(self.iconTransitions,slot,{at=GetFrameTimeMilliseconds(),d=slot.desatNow,a=slot.alphaNow},"iconTransCount")
    end
end
-- Only skills that truly require a corpse may use target/requirement flags.
-- Native no-target/requirement bits also cover ordinary offensive skills and
-- can briefly describe the outgoing weapon when indexed by action slot.
local CORPSE_REQUIRED={[116445]=true,[118009]=true,[118764]=true,[116450]=true,[118123]=true,[118071]=true}
local CORPSE_NAMES={["shocking siphon"]=true,["mystic siphon"]=true,["detonating siphon"]=true,
    ["restoring tether"]=true,["mortal coil"]=true,["braided tether"]=true,
    ["bitter harvest"]=true,["deaden pain"]=true,["necrotic potency"]=true,["repentance"]=true}
-- Use the game's target metadata, not a list of all hostile abilities.
-- Compare localized descriptions against a known enemy-target skill as well
-- as the English tooltip. Area, ground, self and cone are not strict targets.
local function targetDescription(id)
    if not id or type(GetAbilityTargetDescription)~="function" then return nil end
    local value=GetAbilityTargetDescription(id,nil,"player")
    return type(value)=="string" and string.lower(value:match("^%s*(.-)%s*$")) or nil
end
local enemyDescription
local function targetKind(id,category)
    if not id then return nil end
    local effective=GetEffectiveAbilityIdForAbilityOnHotbar and GetEffectiveAbilityIdForAbilityOnHotbar(id,category)
    local description=targetDescription(effective and effective>0 and effective or id)
    if (not description or description=="") and effective and effective~=id then description=targetDescription(id) end
    if not description or description=="" then return nil end
    if not enemyDescription then enemyDescription=targetDescription(117624) end
    if description=="enemy" or description==enemyDescription then return "enemy" end
    if description=="ally" or description=="target" or description=="friendly target" then return "unit" end
    return nil
end
local function nativeUsable(slot,category)
    local button=type(ZO_ActionBar_GetButton)=="function" and ZO_ActionBar_GetButton(slot)
    -- noUpdates: the native button is inside its swap animation and its
    -- usable flag is frozen. Treat it as unknown (the existing fallbacks run).
    if button and button.slot and button.slot.hotbarCategory==category and not button.noUpdates then return button.usable end
    return nil
end
local function slotMatches(s,slot,category,sample)
    return (sample and sample.active or GetActiveHotbarCategory())==category and s.boundCategory==category and GetSlotBoundId(slot,category)==s.boundRaw
end
-- Reticle validity is shared by both bars within a synchronous timer pass.
-- Input and native event callbacks never use this sample: they read live.
-- How long the reticle must stay empty before the inactive bar darkens its
-- enemy-only skills: longer than crossing empty ground between enemies.
local function reticleEnemy(sample)
    if sample and sample.enemyRead then return sample.enemy end
    local valid=DoesUnitExist and IsUnitAttackable and DoesUnitExist("reticleover") and IsUnitAttackable("reticleover") and not (IsUnitDead and IsUnitDead("reticleover"))
    if sample then sample.enemyRead=true; sample.enemy=valid end
    return valid
end
local function corpseUnavailable(slot,category)
    -- Only called for corpse-consuming skills after the swap guard. Read the
    -- native button as in 0.9.15, but never modify or refresh its state.
    if (ActionSlotHasRequirementFailure and ActionSlotHasRequirementFailure(slot,category)) or
       (ActionSlotHasTargetFailure and ActionSlotHasTargetFailure(slot,category)) then return true end
    local usable=nativeUsable(slot,category)
    if usable~=nil then return usable==false end
    -- Generic usability is a last resort for these skills only, and must not
    -- interpret the global cooldown itself as a missing corpse.
    if type(IsSlotUsable)=="function" then
        local remain,_,global=GetSlotCooldownInfo(slot,category)
        if global and (remain or 0)>0 then return nil end
        return IsSlotUsable(slot,category)==false
    end
    return nil
end
function A:RememberPower(kind,value,now)
    self.resourcePools=self.resourcePools or {}
    local entry=self.resourcePools[kind] or {}; self.resourcePools[kind]=entry
    if entry.value~=value then self.appearancePowerRevision=(self.appearancePowerRevision or 0)+1 end
    entry.value,entry.at=value,now
end
function A:ReadPowerPool(kind,now)
    local entry=self.resourcePools and self.resourcePools[kind]
    if not entry or (not self.powerEvents and now-entry.at>=1000) then
        local value=GetUnitPower("player",kind)
        if value==nil then return nil end
        self:RememberPower(kind,value,now); return value
    end
    return entry.value
end
local function insufficient(self,slot,category,now,kind)
    local cost=GetSlotAbilityCost(slot,kind,category) or 0
    local power=cost>0 and self:ReadPowerPool(kind,now)
    return type(power)=="number" and cost>power
end
local function confirmedCostFailure(self,slot,category,now)
    if not ActionSlotHasCostFailure or not ActionSlotHasCostFailure(slot,category) then return false,false end
    -- Only on a reported cost failure: independently compare the bound
    -- skill's actual cost against the player's pools. A stale failure bit
    -- with enough resources must not darken a skill on the new bar.
    local mag,stam,hp=COMBAT_MECHANIC_FLAGS_MAGICKA,COMBAT_MECHANIC_FLAGS_STAMINA,COMBAT_MECHANIC_FLAGS_HEALTH
    if not (mag and stam and hp and GetSlotAbilityCost and GetUnitPower) then return true,true end
    return insufficient(self,slot,category,now,mag) or insufficient(self,slot,category,now,stam)
        or insufficient(self,slot,category,now,hp),true
end
-- Weapon requirements are properties of a skill line and the equipment set
-- assigned to its hotbar, not of the physical action button's failure bits.
-- Resolve weapon line indices from canonical skills at refresh time; no
-- localized names or hardcoded line ordering. Elemental runtime variants
-- sometimes have no progression metadata, so map those aliases explicitly.
local WEAPON_LINE_ANCHORS={twohand={38814,28297},shield={28306,28304},dual={28607,28379},bow={28869,28879},destro={46340,29173},resto={37243,31531}}
local WEAPON_VARIANT={}
for family,ids in pairs(WEAPON_LINE_ANCHORS) do for _,id in ipairs(ids) do WEAPON_VARIANT[id]=family end end
for _,id in ipairs({28858,28807,28854,28849,39052,39053,39073,39067,39011,39012,39018,39028,
    29091,29073,29089,29078,38984,38985,38993,38989,38990,38937,38944,38978,38970,
    28800,28794,28799,28798,39143,39145,39147,39146,39161,39162,39167,39163,
    83619,83625,83628,83630,85130}) do WEAPON_VARIANT[id]="destro" end
local function abilityLine(id)
    if type(id)~="number" or id<=0 then return end
    if GetSpecificSkillAbilityKeysByAbilityId then
        local kind,line=GetSpecificSkillAbilityKeysByAbilityId(id)
        if kind and kind~=SKILL_TYPE_NONE and kind~=0 and line and line>0 then return kind,line end
    end
    if GetAbilityProgressionXPInfoFromAbilityId and GetSkillAbilityIndicesFromProgressionIndex then
        local has,index=GetAbilityProgressionXPInfoFromAbilityId(id)
        if has and index and index>0 then return GetSkillAbilityIndicesFromProgressionIndex(index) end
    end
end
local function matchesWeapon(kind,...)
    if kind==nil then return false end
    for i=1,select("#",...) do if kind==select(i,...) then return true end end
    return false
end
local function oneHand(kind)
    return matchesWeapon(kind,WEAPONTYPE_AXE,WEAPONTYPE_HAMMER,WEAPONTYPE_SWORD,WEAPONTYPE_DAGGER)
end
local function equippedFamily(main,off)
    if main==nil then return nil end
    if matchesWeapon(main,WEAPONTYPE_TWO_HANDED_AXE,WEAPONTYPE_TWO_HANDED_HAMMER,WEAPONTYPE_TWO_HANDED_SWORD) then return "twohand" end
    if matchesWeapon(main,WEAPONTYPE_FIRE_STAFF,WEAPONTYPE_FROST_STAFF,WEAPONTYPE_LIGHTNING_STAFF) then return "destro" end
    if matchesWeapon(main,WEAPONTYPE_HEALING_STAFF) then return "resto" end
    if matchesWeapon(main,WEAPONTYPE_BOW) then return "bow" end
    if oneHand(main) and off==nil then return nil end
    if oneHand(main) and matchesWeapon(off,WEAPONTYPE_SHIELD) then return "shield" end
    if oneHand(main) and oneHand(off) then return "dual" end
    return "none"
end
function A:RefreshWeaponLoadouts()
    self.weaponLoadouts=self.weaponLoadouts or {}
    local gear=self.weaponLoadouts
    local oldPrimary,oldBackup=gear[PRIMARY],gear[BACKUP]
    if GetItemWeaponType and BAG_WORN~=nil and EQUIP_SLOT_MAIN_HAND~=nil and EQUIP_SLOT_OFF_HAND~=nil and EQUIP_SLOT_BACKUP_MAIN~=nil and EQUIP_SLOT_BACKUP_OFF~=nil then
        gear[PRIMARY]=equippedFamily(GetItemWeaponType(BAG_WORN,EQUIP_SLOT_MAIN_HAND),GetItemWeaponType(BAG_WORN,EQUIP_SLOT_OFF_HAND))
        gear[BACKUP]=equippedFamily(GetItemWeaponType(BAG_WORN,EQUIP_SLOT_BACKUP_MAIN),GetItemWeaponType(BAG_WORN,EQUIP_SLOT_BACKUP_OFF))
    else gear[PRIMARY]=nil; gear[BACKUP]=nil end
    if oldPrimary~=gear[PRIMARY] or oldBackup~=gear[BACKUP] then
        for _,row in ipairs(self.slots) do for _,s in ipairs(row) do s.appearanceDirty=true end end
    end
end
function A:RefreshWeaponLines()
    self.weaponLines={}
    if not SKILL_TYPE_WEAPON then return end
    for family,ids in pairs(WEAPON_LINE_ANCHORS) do
        for _,id in ipairs(ids) do
            local kind,line=abilityLine(id)
            if kind==SKILL_TYPE_WEAPON and line and line>0 then self.weaponLines[line]=family; break end
        end
    end
end
function A:SkillWeaponFamily(s,slot,category)
    if not s.abilityId or (category~=PRIMARY and category~=BACKUP) then return nil end
    local raw=GetSlotBoundId(slot,category)
    local crafted=s.abilityKey and tonumber(s.abilityKey:match("^c:(%d+):"))
    if not crafted and ACTION_TYPE_CRAFTED_ABILITY and GetSlotType and GetSlotType(slot,category)==ACTION_TYPE_CRAFTED_ABILITY then crafted=raw end
    if not crafted and GetAbilityCraftedAbilityId then local id=GetAbilityCraftedAbilityId(s.abilityId); if id and id>0 then crafted=id end end
    local kind,line
    if crafted and crafted>0 and GetSkillAbilityIndicesFromCraftedAbilityId then kind,line=GetSkillAbilityIndicesFromCraftedAbilityId(crafted) end
    if not kind or kind==SKILL_TYPE_NONE or kind==0 or not line or line<=0 then kind,line=abilityLine(s.abilityId) end
    if (not kind or kind==SKILL_TYPE_NONE or kind==0 or not line or line<=0) and not crafted and raw~=s.abilityId then kind,line=abilityLine(raw) end
    if kind==SKILL_TYPE_WEAPON and line and self.weaponLines[line] then return self.weaponLines[line] end
    if not crafted then return WEAPON_VARIANT[s.abilityId] or WEAPON_VARIANT[raw] end
end
function A:WrongWeapon(s,category)
    local equipped=self.weaponLoadouts and self.weaponLoadouts[category]
    return self.settings.showUnavailable and s and s.weaponFamily~=nil and equipped~=nil and s.weaponFamily~=equipped or false
end
-- Only use explicit target/range flags for an actual unit-target ability.
-- A weapon-slot failure makes the slot snapshot ambiguous after a swap.
-- A generic unusable or GCD flag alone is never enough to darken a skill.
local function targetUnavailable(s,slot,category,validEnemy)
    if ActionSlotHasWeaponSlotFailure and ActionSlotHasWeaponSlotFailure(slot,category) then return nil end
    local target=ActionSlotHasTargetFailure and ActionSlotHasTargetFailure(slot,category)
    local range=ActionSlotHasRangeFailure and ActionSlotHasRangeFailure(slot,category)
    local usable=nativeUsable(slot,category)
    if s.targetKind=="enemy" and DoesUnitExist and IsUnitAttackable then
        -- A dedicated target failure corroborated by the real reticle is
        -- stronger evidence than a native icon that has not repainted yet.
        if target and validEnemy==false then return true,"target" end
    end
    -- Otherwise a native 'usable' result trumps a migrated failure bit.
    if usable==true then return false end
    if range and validEnemy~=false then return true,"range" end
    if target and validEnemy~=true then return true,"target" end
    -- Some native buttons report no-target via usability without a dedicated
    -- flag. Restrict that fallback to known enemy skills with no attackable
    -- reticle target, never a GCD or generic requirement alone.
    if usable==false and validEnemy==false then
        local remain,_,global=GetSlotCooldownInfo(slot,category)
        if not (global and (remain or 0)>0) then return true,"target" end
        if s.targetBlocked and s.targetBlockReason=="target" then return true,"target" end
    end
    return false
end
function A:SlotUnavailable(slot,category,knownSlot,now,sample)
    if not self.settings.showUnavailable then return false end
    local s=knownSlot
    if not s then
        local row=self.categories[1]==category and 1 or self.categories[2]==category and 2
        s=row and self.slots[row][slot-2]
    end
    if not s or not s.abilityId then return false end
    if self:WrongWeapon(s,category) then return true,"WEAPON" end
    now=now or GetFrameTimeMilliseconds()
    -- Keep the last trustworthy corpse state attached to the skill's own
    -- hotbar, not the physical active button. Inactive native usability
    -- can refer to the active weapon, so don't sample it across a swap.
    local stable=category==self.active and not (self.swapPending and now<self.swapPending.untilTime) and slotMatches(s,slot,category,sample)
    if s.focusRequired then
        local count=self.tracker:GetStack(s,now)
        if count==nil then count=stable and self:ReadNativeStack(s,slot,category,now) or s.nativeStack or 0 end
        if count<s.focusRequired then return true,"STACKS" end
        -- Inactive bar: a fixed look; the reticle
        -- never darkens it (no flicker while sweeping between enemies).
        if s.focusTarget and category==self.active then
            if DoesUnitExist and IsUnitAttackable and not reticleEnemy(sample) then return true,"TARGET" end
            -- A valid reticle is not proof of cast range. The live probe
            -- reports range failure even when IsSlotUsable is true and
            -- before the native button repaints. Trust only the explicit
            -- active-slot range bit, never an outgoing bar or generic GCD.
            if stable and self.settings.darkenTarget and ActionSlotHasRangeFailure and
                ActionSlotHasRangeFailure(slot,category) and
                not (ActionSlotHasWeaponSlotFailure and ActionSlotHasWeaponSlotFailure(slot,category)) then
                return true,"TARGET"
            end
        end
        return false,nil -- generic requirement/GCD flags cannot replace the explicit stack threshold
    end
    s.resourceBlocked=false
    s.requirementBlocked=false
    if self.settings.darkenCorpse and s.corpseRequired then
        if stable then
            local blocked=corpseUnavailable(slot,category)
            if blocked~=nil then s.corpseBlocked=blocked end
        end
    else s.corpseBlocked=nil end
    if self.settings.darkenTarget and s.targetKind and not s.corpseRequired then
        -- The reticle belongs to the player, not the active weapon. Both
        -- rows can reliably evaluate a known enemy-only skill without
        -- consulting the inactive native button's stale usability bits.
        local validEnemy
        if s.targetKind=="enemy" and DoesUnitExist and IsUnitAttackable then
            validEnemy=reticleEnemy(sample)
        end
        if stable then
            -- Active bar: ESO's own usable state decides, as on the native
            -- button. A moment with no enemy under the reticle (sweeping the
            -- camera between enemies) is not a reason by itself.
            local blocked,reason=targetUnavailable(s,slot,category,validEnemy)
            -- Do not carry a previous target-state blackout into an ambiguous
            -- active slot; unlike a corpse state, reticle validity can change.
            s.targetBlocked=blocked==true; s.targetBlockReason=reason
            -- Last trustworthy range reading of this skill for this target.
            s.lastRangeKey=blocked==true and reason=="range" and s.abilityKey or nil
        elseif category==self.active and validEnemy==false and
            (nativeUsable(slot,category)~=true or
                (not (ActionSlotHasWeaponSlotFailure and ActionSlotHasWeaponSlotFailure(slot,category)) and
                 ActionSlotHasTargetFailure and ActionSlotHasTargetFailure(slot,category))) then
            -- Swap settle: no attackable reticle target for a known enemy-only
            -- skill. Darken immediately instead of flashing usable for 300 ms;
            -- settled native state (e.g. tab-lock) reconciles once swapPending ends.
            s.targetBlocked=true; s.targetBlockReason="target"
        elseif category==self.active and validEnemy==true and s.lastRangeKey and s.lastRangeKey==s.abilityKey then
            -- Swap settle: ESO's range bit is not trusted for 300 ms. Keep the
            -- last reading for the same skill and target instead of lighting
            -- the skill up and darkening it again; the fresh reading follows.
            s.targetBlocked=true; s.targetBlockReason="range"
        else
            -- Inactive bar: a fixed look. Its native
            -- bits are stale and the reticle alone made it flicker while
            -- sweeping between enemies, so target state never darkens it.
            s.targetBlocked=nil; s.targetBlockReason=nil
        end
    else s.targetBlocked=nil; s.targetBlockReason=nil end
    local activeVerified=stable or (category==self.active and slotMatches(s,slot,category,sample) and
        not (ActionSlotHasWeaponSlotFailure and ActionSlotHasWeaponSlotFailure(slot,category)))
    if self.settings.darkenResource and activeVerified then
        local blocked,reported=confirmedCostFailure(self,slot,category,now)
        s.resourceBlocked=blocked
        s.resourceCheck=reported or blocked
    end
    if not s.corpseRequired and activeVerified and ActionSlotHasRequirementFailure and ActionSlotHasRequirementFailure(slot,category) then
        s.requirementBlocked=true
    end
    if s.resourceBlocked then return true,"RESOURCE" end
    if s.corpseBlocked then return true,"CORPSE" end
    if s.requirementBlocked then return true,"REQUIREMENT" end
    if s.targetBlocked then return true,"TARGET" end
    return false,nil
end
function A:UpdateSlotAppearance(s,slot,category,now,sample)
    s.appearanceDirty=nil
    now=now or GetFrameTimeMilliseconds()
    -- Native hotbar state events are the primary update. Stagger recovery
    -- across the five physical slots, using the existing 100 ms Tick only.
    s.appearanceCheckAt=now+(EVENT_HOTBAR_SLOT_STATE_UPDATED and (400+(slot-3)*50) or 100)
    s.resourceCheck=nil
    local active=category==self.active
    local disabled,reason=self:SlotUnavailable(slot,category,s,now,sample)
    s.appearancePowerRevision=self.appearancePowerRevision
    s.unavailableReason=reason
    local changed=s.unavailable~=disabled
    s.unavailable=disabled
    local tint=disabled and self.settings.unavailableTint or 1
    if s.iconTint~=tint then s.icon:SetColor(tint,tint,tint,1); s.iconTint=tint end
    self:StyleIcon(s,disabled and 1 or (active and 0 or self.settings.inactiveDesaturation),
        disabled and self.settings.unavailableAlpha or (active and 1 or self.settings.inactiveAlpha),changed or self.swapPending~=nil)
    if disabled and changed then
        -- A real cast may consume the last corpse. Allow that confirmed cast
        -- to finish its flash, but do not flash a blocked press or expiry.
        if not s.lastCastEvent or GetFrameTimeMilliseconds()-s.lastCastEvent>self.settings.pressMs then clearFlash(s) end
        self:SetProc(s,false); self:SetGoldLoop(s,false); if not s.fillHidden then s.fillHidden=true; s.fill:SetHidden(true) end; mapSet(self.fillSlots,s,nil,"fillCount")
    end
end
-- Skill tooltip durations are read only when a binding changes or a cast is
-- confirmed, never in the timer/render update. Player modifiers can change
-- between casts, so refresh even when the bound skill itself is unchanged.
function A:CacheSkillDuration(s)
    local duration=s.abilityId and GetAbilityDuration and GetAbilityDuration(s.abilityId,nil,"player") or nil
    s.skillDuration=type(duration)=="number" and duration>0 and duration or nil
end
-- A quickslot selection is independent of the skill/ultimate bindings.
function A:RefreshQuickslotBinding()
    if not self.root or self.preview then return end
    local q=GetCurrentQuickslot()
    if q then
        local kind=GetSlotType and GetSlotType(q,HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        local boundId=GetSlotBoundId and GetSlotBoundId(q,HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if self.quickSlot~=q or self.quickKind~=kind or self.quickBoundId~=boundId then
            self.quickEnd=nil; self.quickDuration=nil; self.quickCooling=false
            self.quickSlot=q; self.quickKind=kind; self.quickBoundId=boundId
            self.quickDirty=true; self.quickRenderIdle=nil; self.quickRenderAt=nil
        end
        self.quickCooldownDirty=true
        setIcon(self.quick,q,HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    end
end
-- Normal weapon swaps change the role of two fixed category rows, not
-- their bindings. Keep the expensive metadata/registration pass separate.
function A:RefreshBarPresentation()
    self.activeRow=self.active==BACKUP and 2 or 1
    self.otherCategory=self.active==PRIMARY and BACKUP or PRIMARY
    self.costDirty=true
    self:PositionSlotRows()
    self:PositionArrow()
    for row=1,2 do
        local category=self.categories[row]
        for i=1,5 do
            local s=self.slots[row][i]
            self:UpdateSlotAppearance(s,i+2,category)
            if category~=self.active and not self:SkillOption(s,"loopInactive") then self:SetGoldLoop(s,false) end
        end
    end
    setIcon(self.ultimate,8,self.active)
    setIcon(self.secondary,8,self.otherCategory)
    local hovered=self.skillTooltipOwner
    if hovered then
        if hovered:IsHidden() or not AbilityTooltip or AbilityTooltip:GetOwner()~=hovered then self:ClearSkillTooltip()
        else self:ShowSkillTooltip(hovered) end
    end
end

-- Render/Tick/input consume the same pending work while visible. Only a
-- hidden HUD needs a timer. One named job owns both reasons; an earlier
-- deadline may wake it up harmlessly, but a new swap cannot settle early.
function A:ScheduleSlotWork()
    if self.armoryRestore then return end
    if not self.slotWorkDue and (self.updating or self.preview or not (self.slotRefreshPending or self.swapPending)) then return end
    local now=GetFrameTimeMilliseconds()
    local due
    if not self.updating and not self.preview then
        if self.slotRefreshPending then due=now+1
        elseif self.swapPending then due=math.max(now+1,self.swapPending.untilTime) end
    end
    local namespace=ADDON.."SlotWork"
    if self.slotWorkDue and (not due or due<self.slotWorkDue) then
        EM:UnregisterForUpdate(namespace); self.slotWorkDue=nil
    elseif self.slotWorkDue then return end
    if not due then return end
    if not self.slotWorkCallback then
        self.slotWorkCallback=function()
            local deadline=self.slotWorkDue
            if not deadline or GetFrameTimeMilliseconds()<deadline then return end
            EM:UnregisterForUpdate(namespace); self.slotWorkDue=nil
            if not self.preview and (self.slotRefreshPending or
                self.swapPending and GetFrameTimeMilliseconds()>=self.swapPending.untilTime) then
                self:RefreshSlots(true)
            end
            self:ScheduleSlotWork()
        end
    end
    self.slotWorkDue=due
    EM:RegisterForUpdate(namespace,math.max(1,due-now),self.slotWorkCallback)
end

-- Rebind a physical slot only when its canonical identity/metadata changed.
-- Preserve the existing visual and runtime state for unchanged bindings.
function A:RefreshSlot(s,i,category,force,settled,verifyOnly)
    local oldKey,oldCategory=s.abilityKey,s.boundCategory
    -- Icon-family and binding identity consume one synchronous slot sample.
    -- A zero sentinel also avoids repeating an empty-slot query.
    local raw=GetSlotBoundId(i+2,category)
    setIcon(s,i+2,category,nil,raw or 0)
    local changed,rebound
    if verifyOnly and self.tracker:NativeBindingUnchanged(s,i+2,category,raw or 0) then
        changed,rebound=false,false
    else
        changed,rebound=self.tracker:Bind(s,i+2,category,not force,nil,raw or 0)
    end
    -- A kept binding may still see a new raw ID: chained slots on the inactive
    -- bar report the active weapon's variant (Tracker weaponVariantForm). Record the
    -- observed raw so slotMatches() keeps sampling availability after a swap.
    if rebound==false and s.boundCategory==category then s.boundRaw=raw end
    if rebound~=false then
        -- Metadata may change at the same canonical identity (rank, variant).
        s.timerWholeSec=nil; s.timerTextMode=nil; s.timerVisualGen=nil
        s.stackCacheGen=nil; s.auxCacheValue=nil; s.skillOptGen=nil; s.lastTargetCountGen=nil
        self:CacheSkillDuration(s)
        if changed then
            if oldKey~=s.abilityKey or oldCategory~=category then
                local oldNative,oldDisplay=s.nativeStack or 0,s.displayedStack or 0
                s.replacedStackUntil=(oldNative>0 or oldDisplay>0) and GetFrameTimeMilliseconds()+650 or nil
                setStack(s,0)
            end
            s.nativeTimer=nil; s.nativeStack=nil; clearFlash(s); s.lastPress=nil; s.lastCastEvent=nil
            s.whipTimerKind=nil
        elseif oldCategory~=category then
            s.nativeTimer=nil
        end
        if not s.abilityId then clearEmptySlot(self,s) end
        if oldKey~=s.abilityKey or oldCategory~=category then s.corpseBlocked=nil; s.targetBlocked=nil; s.targetBlockReason=nil; s.resourceBlocked=nil; s.requirementBlocked=nil; s.appearanceHasStack=nil end
        s.boundCategory=category
        s.boundRaw=raw
        s.weaponFamily=self:SkillWeaponFamily(s,i+2,category)
        local name=s.abilityId and GetSlotName(i+2,category) or ""
        if s.corpseName~=name or s.corpseAbility~=s.abilityId then
            s.corpseName,s.corpseAbility=name,s.abilityId
            s.corpseRequired=s.abilityId and (CORPSE_REQUIRED[s.abilityId] or CORPSE_NAMES[string.lower(name or "")]) or false
            local detonating=GetAbilityName and GetAbilityName(118764)
            s.suppressFill=s.abilityId==118764 or name=="Detonating Siphon" or (detonating and detonating~="" and name==detonating)
        end
        s.targetKind=not s.corpseRequired and targetKind(s.abilityId,category) or nil
        self:PrepareSlotControls(s)
    end
    -- Assignment validation is not a repaint. The swap presentation already
    -- changed the visual role; active native usability is sampled again
    -- after the engine's stabilization window, without resetting timers.
    if settled and s.nativeTimer then s.nativeTimer.valid=false end
    if s.flameSlot and (rebound~=false or settled) then
        self.tracker:ObservePowerLashSlot(i+2,category,GetFrameTimeMilliseconds(),category==self.active,raw or 0)
    end
    if rebound~=false or s.appearanceDirty or (settled and category==self.active) then
        if rebound~=false then s.container:SetHidden(false) end
        self:UpdateSlotAppearance(s,i+2,category)
        if category~=self.active and not self:SkillOption(s,"loopInactive") then self:SetGoldLoop(s,false) end
    end
    return rebound~=false
end

function A:RefreshSlots(deferBindings,snapshot)
    if not self.root then return end
    if self.preview then self.slotRefreshPending=true; return end
    if self.armoryRestore then self.armoryRestore.slots=true; return end
    self.slotRefreshPending=nil
    local active = GetActiveHotbarCategory()
    local categoryChanged=self.active and active~=self.active
    local settled=false
    if categoryChanged then
        local now=GetFrameTimeMilliseconds()
        self.swapPending={category=active,untilTime=now+300}
        self.swapTimerUntil=now+300
        if self.ClearStalePending then self:ClearStalePending(active) end
    elseif self.swapPending and GetFrameTimeMilliseconds()>=self.swapPending.untilTime then
        -- Also settle when the HUD is hidden and no Tick is running.
        self.swapPending=nil; settled=true
    end
    self.active = active
    self:SyncWerewolfMode()
    local normal = active == PRIMARY or active == BACKUP
    local holdBindings=deferBindings and normal and self.swapPending and self.categories and self.categories[1]==PRIMARY and self.categories[2]==BACKUP
    if holdBindings then
        -- Retain all dirty reasons until the stable category sample. Repeated
        -- native slot/skill events during the guard need no second repaint.
        if categoryChanged then self:RefreshBarPresentation() end
        self:ScheduleSlotWork()
        return
    end
    local metadataDirty=self.skillRefreshPending
    if metadataDirty then self:ForgetPassives(); self.tracker.syncDirty=true; self.skillRefreshPending=nil end
    local rankDirty,modifierDirty=self.skillRankRefreshPending,self.skillModifierRefreshPending
    self.skillRankRefreshPending,self.skillModifierRefreshPending=nil,nil
    local function rankAffected(s)
        if not rankDirty or not s.abilityId then return false end
        if rankDirty.all or not GetAbilityProgressionXPInfoFromAbilityId then return true end
        local has,index=GetAbilityProgressionXPInfoFromAbilityId(s.abilityId)
        return has and rankDirty[index]==true or false
    end
    local ward=self:CharacterHasPassive("wardMastery")==true
    local wardChanged=self.tracker.wardMasteryOwned~=ward
    self.tracker.wardMasteryOwned=ward
    local force=not deferBindings or metadataDirty or wardChanged or not self.categories
        or self.categories[1]~=(normal and PRIMARY or active) or (self.categories[2]~=nil)~=normal
    local dirtySlots,allSlots,listDirty=self.slotRefreshSlots,self.slotRefreshAll,self.slotListRefresh
    self.slotRefreshSlots,self.slotRefreshAll,self.slotListRefresh=nil,nil,nil
    local stable=not force and not rankDirty and not modifierDirty and not settled and not categoryChanged and not allSlots
    local verifyList=stable and listDirty and not self.tracker.syncDirty
    local partial=stable and not listDirty and dirtySlots
    local bindingsUpdated=force
    self.costDirty=true
    if not self.weaponLoadouts or (not self.wornGearEvents and (force or settled or categoryChanged)) then self:RefreshWeaponLoadouts() end
    if force or not self.weaponLines then self:RefreshWeaponLines() end
    local other = active == PRIMARY and BACKUP or PRIMARY
    if not normal then other = nil end
    local isSingle=not self.preview and not normal
    local layoutChanged=not self.categories or (self.categories[2]~=nil)~=normal or (self.singleRowLayout~=nil and self.singleRowLayout~=isSingle)
    self.categories = normal and {PRIMARY,BACKUP} or {active,nil}
    self.activeRow = active==BACKUP and 2 or 1
    self.otherCategory = other
    if layoutChanged then self:PositionElements() elseif force or categoryChanged then self:PositionSlotRows(); self:PositionArrow() end
    for row=1,2 do
        local category = self.categories[row]
        for i=1,5 do
            local s = self.slots[row][i]
            if category then
                local marked=dirtySlots and dirtySlots[category] and dirtySlots[category][i+2]
                if not partial or marked then
                    if self:RefreshSlot(s,i,category,force or rankAffected(s),settled,verifyList and not marked) then bindingsUpdated=true
                    elseif modifierDirty then self:CacheSkillDuration(s) end
                end
            else s.container:SetHidden(true); mapSet(self.fillSlots,s,nil,"fillCount"); mapSet(self.iconTransitions,s,nil,"iconTransCount"); s.desatTarget=nil; s.track=nil; s.trackKey=nil; s.skillDuration=nil; s.corpseBlocked=nil; s.targetBlocked=nil; s.targetBlockReason=nil; s.resourceBlocked=nil; s.requirementBlocked=nil; s.appearanceHasStack=nil; s.boundCategory=nil; s.boundRaw=nil; s.targetKind=nil; s.expiryActive={}; s.timerWholeSec=nil; s.timerTextMode=nil; s.stackCacheGen=nil; s.auxCacheValue=nil; s.skillOptGen=nil; s.lastTargetCountGen=nil; self:SetProc(s,false); self:SetGoldLoop(s,false); self:SetToggle(s,false) end
        end
        local state=self.slots[row][6]
        if category then
            local marked=dirtySlots and dirtySlots[category] and dirtySlots[category][8]
            if not partial or marked then
                local _,rebound
                if verifyList and not marked then
                    local raw=GetSlotBoundId(8,category)
                    if self.tracker:NativeBindingUnchanged(state,8,category,raw or 0) then rebound=false
                    else _,rebound=self.tracker:Bind(state,8,category,true,nil,raw or 0) end
                else
                    _,rebound=self.tracker:Bind(state,8,category,not (force or rankAffected(state)))
                end
                if rebound~=false then
                    bindingsUpdated=true
                    self:CacheSkillDuration(state)
                    state.nativeTimer=nil
                    state.durationCategory=category; state.weaponFamily=self:SkillWeaponFamily(state,8,category)
                elseif modifierDirty then self:CacheSkillDuration(state) end
                if settled and state.nativeTimer then state.nativeTimer.valid=false end
            end
        else state.track=nil; state.trackKey=nil; state.skillDuration=nil; state.nativeTimer=nil; state.durationCategory=nil; state.expiryActive={}; state.weaponFamily=nil end
    end
    self.tracker.targetsEnabled=self.settings.showTargets
    self.tracker.targetBlacklist=self.settings.multiTargetBlacklist or {}
    self.tracker.soonest=self.settings.targetExpireFirst
    self.tracker:SyncFollowTarget(self.settings.followTargetTimers~=false and self.settings.enabled)
    self.tracker.keepLastTarget=self.settings.followKeepLast~=false
    self.tracker.passivesEnabled=self.settings.showUltimatePassives
    self.tracker.procEnabled=self.settings.procHighlight
    self.tracker.nwEnabled=self.settings.showNothingWasted
    self.tracker.vampirePassiveEnabled=self.settings.showVampirePassive~=false
    self.tracker.arcanistPassiveMode=self.settings.arcanistPassiveMode or "Fatecarver"
    self.tracker.trackingPolicies=self.settings.trackingPolicies
    self.tracker.landslideEnabled=self.settings.showLandslide
    self.tracker.externalCountsEnabled=self.settings.showExternalCounts
    self.tracker.groupOnly=self.settings.groupRecipientsOnly
    if bindingsUpdated or self.tracker.syncDirty then self:EnforceTrackingLocks() end
    self.tracker:Sync(self.slots,self.categories,snapshot)
    if self.effectHUD and self.effectHUD.SetWhipBalance then self.effectHUD:SetWhipBalance(self.tracker.flameWanted) end
    if self.StudioVisible and self:StudioVisible() then self:StudioRefresh() end
    local activeTexture=setIcon(self.ultimate,8,active)
    self.secondary.container:SetHidden(not other or not self.settings.showBackUlt)
    labelHidden(self.secondaryCost,not other or not self.settings.showBackUlt or not self.settings.showUltCost)
    local otherTexture
    if other then otherTexture=setIcon(self.secondary,8,other) end
    -- Only reconcile the hidden banks from stable API samples. Both sizes
    -- now hold both physical ultimate textures, ready for the next swap.
    if other and not self.swapPending then
        setIcon(self.ultimate,8,other,true,nil,otherTexture)
        setIcon(self.secondary,8,active,true,nil,activeTexture)
    end
    self:RefreshQuickslotBinding()
    if not self.swapPending and self.externalIconsPending then self:RefreshExternalIcons() end
    -- A weapon swap or changed skill must not leave the previous slot's description.
    local hovered=self.skillTooltipOwner
    if hovered then
        if hovered:IsHidden() or not AbilityTooltip or AbilityTooltip:GetOwner()~=hovered then self:ClearSkillTooltip()
        else self:ShowSkillTooltip(hovered) end
    end
    self:ScheduleSlotWork()
end

-- Merge assignment/skill metadata event bursts into one binding refresh.
-- Render, Tick and combat input may flush it first. The one-shot fallback
-- also works while the HUD is hidden (e.g. the skills or Studio window).
function A:RequestSlotRefresh(slot,category,listOnly)
    if self.armoryRestore then self.armoryRestore.slots=true; return end
    if slot and category and slot>=3 and slot<=8 then
        self.slotRefreshSlots=self.slotRefreshSlots or {}
        self.slotRefreshSlots[category]=self.slotRefreshSlots[category] or {}
        self.slotRefreshSlots[category][slot]=true
    elseif listOnly then self.slotListRefresh=true
    else self.slotRefreshAll=true end
    if not self.preview and self.swapPending and self.active==GetActiveHotbarCategory()
        and self.categories and self.categories[1]==PRIMARY and self.categories[2]==BACKUP
        and GetFrameTimeMilliseconds()<self.swapPending.untilTime then return end
    self.slotRefreshPending=true
    self:ScheduleSlotWork()
end
function A:SkillRespecResult(result)
    -- Only committed allocations invalidate ownership. Unknown API results
    -- retain the conservative path; explicit failures change nothing.
    if RESPEC_RESULT_SUCCESS==nil or result==nil or result==RESPEC_RESULT_SUCCESS then self:SkillsChanged() end
end
function A:SkillsChanged()
    if self.armoryRestore then self.armoryRestore.skills=true; return end
    -- Confirmed character allocation/lifecycle changes. Do not route the
    -- generic ability-list notification here: it also fires for runtime data.
    self.characterRefreshAfterCombat=nil
    self:ForgetPassives()
    Tracker.ResetFormTrust()
    self.tracker.syncDirty=true
    self.skillRefreshPending=true
    self:RequestSlotRefresh()
end
function A:AbilityListChanged()
    self:RequestSlotRefresh(nil,nil,true)
end
function A:WerewolfStateChanged()
    if not self.root or self.preview then return end
    if self.armoryRestore then self.armoryRestore.slots=true; return end
    -- The form event can precede the real category change by over a second
    -- or follow it after the new bar has already been bound. Keep Fury and
    -- native ownership current but do not force a second metadata rebuild.
    if self.active~=GetActiveHotbarCategory() then self:RefreshSlots(true)
    else
        self:SyncWerewolfMode()
        self.costDirty=true
        self:AbilityListChanged()
    end
end
function A:SkillRankChanged(progression)
    local dirty=self.skillRankRefreshPending or {}; self.skillRankRefreshPending=dirty
    if type(progression)=="number" and progression>0 then dirty[progression]=true else dirty.all=true end
    self:RequestSlotRefresh()
end
function A:SkillModifiersChanged()
    -- CP/equipment modifiers may affect duration/cost, not passive ownership.
    self.skillModifierRefreshPending=true
    self.costDirty=true
    self:RequestSlotRefresh()
end
function A:FullSkillsChanged()
    -- A broad full notification has no payload. During combat allocations
    -- cannot be edited; validate identities/durations now, revalidate the
    -- character once on combat exit. Explicit allocation events still win.
    if IsUnitInCombat and IsUnitInCombat("player") then
        self.characterRefreshAfterCombat=true
        self:SkillModifiersChanged()
    else self:SkillsChanged() end
end
function A:FlushCharacterRefresh()
    if not self.characterRefreshAfterCombat then return end
    self.characterRefreshAfterCombat=nil
    self:SkillsChanged()
end
-- A real category transition must remain immediate: casts, WW layout and
-- availability all depend on the new bar before its next frame.
function A:ActiveHotbarRefreshEvent(didChange,assignments,category)
    -- Only discard the explicit no-change notification. Missing payloads,
    -- category mismatches and assignment/full events remain conservative.
    if didChange==false and assignments==false and category==self.active and self.active==GetActiveHotbarCategory() then return end
    self:SlotRefreshEvent(false)
end
function A:SlotRefreshEvent(individual,slot,category)
    if self.active~=GetActiveHotbarCategory() then
        self:RefreshSlots(true)
    elseif individual or not self.swapPending or (self.active~=PRIMARY and self.active~=BACKUP)
        or GetFrameTimeMilliseconds()>=self.swapPending.untilTime then
        self:RequestSlotRefresh(slot,category)
    end
end

function A:InvalidateNativeTimers()
    for row=1,2 do
        local slots=self.slots[row]
        if slots then
            for i=1,6 do
                local s=slots[i]
                if s and s.nativeTimer then s.nativeTimer.valid=false end
            end
        end
    end
end

-- Native slot timers are event-driven (EVENT_ACTION_SLOT_EFFECT_UPDATE +
-- EVENT_ACTION_SLOT_EFFECTS_CLEARED) and expire locally on the frame clock,
-- matching ESOUI actionbar.lua/actionbutton.lua. During a weapon swap, continue
-- an already known countdown until the 300 ms stabilization window settles.
local function readNativeCached(self,s,slot,category,now,filterShort)
    local cached=s.nativeTimer
    if self.swapTimerUntil and now<self.swapTimerUntil then
        if cached then
            local rem=math.max(0,cached.finish-now)
            return rem,rem>0 and cached.duration or 0
        end
        return 0,0
    end
    if cached and cached.valid then
        local rem=math.max(0,cached.finish-now)
        return rem,rem>0 and cached.duration or 0
    end
    local remain=GetActionSlotEffectTimeRemaining(slot,category) or 0
    -- Gate GetActionSlotEffectDuration on remain > 0 (Test B proved expired
    -- slot-8 ultimates retain stale duration after remain hits 0).
    local duration=remain>0 and GetActionSlotEffectDuration and (GetActionSlotEffectDuration(slot,category) or 0) or 0
    -- Native slot effects can echo the global one-second cast lock. The
    -- cast bar already represents it and it is not a skill effect.
    if remain<=0 or (filterShort and duration>0 and duration<=1500) then
        remain,duration=0,0
    end
    cached=cached or {}; s.nativeTimer=cached
    cached.finish,cached.duration,cached.valid=now+remain,duration,true
    return remain,duration
end
function A:ReadNativeTimer(s,slot,category,now)
    if s.noNativeTimer then return 0,0 end
    return readNativeCached(self,s,slot,category,now,true)
end

function A:ReadNativeStack(s,slot,category,now)
    if self.swapTimerUntil and now<self.swapTimerUntil then return s.nativeStack or 0 end
    local value=GetActionSlotEffectStackCount(slot,category) or 0
    if s.replacedStackUntil then
        -- Ignore outgoing positive counts during the short binding grace.
        -- A newly equipped skill can already have stacks and may never
        -- produce zero, so do not wait for zero indefinitely.
        if value>0 and now<s.replacedStackUntil then return 0 end
        s.replacedStackUntil=nil
    end
    s.nativeStack=value
    return s.nativeStack
end

-- Slow recovery polls cover login, UI loading and missed events. Event-driven
-- clients otherwise avoid polling power/cost/inventory at the timer rate.
function A:ReadResources(now)
    if not self.powerAt or (not self.powerEvents and now-self.powerAt>=1000) then
        local value,maximum=GetUnitPower("player",COMBAT_MECHANIC_FLAGS_ULTIMATE)
        self.ultPower=value or 0; self.ultMax=maximum and maximum>0 and maximum or 500; self.powerAt=now
    end
    if not self.costEvents or self.costDirty or not self.costAt or now-self.costAt>=1000 then
        self.mainCost=GetSlotAbilityCost(8,COMBAT_MECHANIC_FLAGS_ULTIMATE,self.active) or 0
        self.backCost=self.otherCategory and (GetSlotAbilityCost(8,COMBAT_MECHANIC_FLAGS_ULTIMATE,self.otherCategory) or 0) or nil
        self.costAt=now; self.costDirty=false
    end
    if self.werewolfMode and COMBAT_MECHANIC_FLAGS_WEREWOLF and
        (not self.furyAt or (not self.powerEvents and now-self.furyAt>=1000)) then
        self:ObserveFury(GetUnitPower("player",COMBAT_MECHANIC_FLAGS_WEREWOLF),now)
    end
end
function A:ObserveFury(value,now)
    if not self.werewolfMode then return end
    self.furyPower=math.max(0,math.min(1000,tonumber(value) or 0))
    self.furyAt=now
    if self.furyPower>=1000 then self.furyReadyUntil=now+1700 end
end
function A:SyncWerewolfMode()
    local ww=(IsPlayerInWerewolfForm and IsPlayerInWerewolfForm()) or
        (HOTBAR_CATEGORY_WEREWOLF~=nil and self.active==HOTBAR_CATEGORY_WEREWOLF)
    ww=not not ww
    if self.werewolfMode~=ww then
        self.werewolfMode=ww; self.furyPower=nil; self.furyAt=nil
        self.rampageEnd=nil; self.furyReadyUntil=nil; self.ultReady=false
    end
    local native=_G.ZO_PlayerAttributeWerewolf
    if ww and self.settings.enabled and self.settings.replaceNative and self.updating then
        if native and self.nativeAlpha[native]==nil then changeNative(native,true,true) end
    else changeNative(native,false) end
end
-- Ulfsild's Contingency fires on the next ability "with a cost".
local COST_MECHANICS={"COMBAT_MECHANIC_FLAGS_MAGICKA","COMBAT_MECHANIC_FLAGS_STAMINA","COMBAT_MECHANIC_FLAGS_HEALTH","COMBAT_MECHANIC_FLAGS_ULTIMATE"}
function A:SlotHasCost(slot,category)
    if not GetSlotAbilityCost then return true end
    local known=false
    for _,name in ipairs(COST_MECHANICS) do
        local mechanic=_G[name]
        if mechanic then
            known=true
            local cost=GetSlotAbilityCost(slot,mechanic,category)
            if (tonumber(cost) or 0)>0 then return true end
        end
    end
    return not known
end
function A:PressedSlot(slot)
    if not self.settings.enabled or self.preview or not self.updating then return end
    if slot<3 or slot>8 then return end
    local actual=GetActiveHotbarCategory()
    if actual~=self.active or self.slotRefreshPending then self:RefreshSlots(true) end
    local target=slot==8 and self.ultimate or self.slots[self.activeRow or 1][slot-2]
    -- Every key press, even one the HUD shows as unavailable: a cast event
    -- with no press since the previous one was not cast by the player.
    target.lastKeyDown=GetFrameTimeMilliseconds()
    if slot<8 then
        -- Input still samples live state. If an event was missed, request
        -- the corresponding icon correction on the next existing Tick.
        local blocked,reason=self:SlotUnavailable(slot,self.active,target)
        if target.unavailable~=blocked or target.unavailableReason~=reason then target.appearanceDirty=true end
        if blocked then return end
    end
    if slot==8 and self:WrongWeapon(self.slots[self.activeRow][6],self.active) then return end
    local now=GetFrameTimeMilliseconds()
    -- Ignore initial duplicate Down events while still allowing normal skill spam.
    if target.lastPress and now-target.lastPress<90 then return end
    target.lastPress=now
    if slot<8 then startPress(target) end
    if target.lastCastEvent and now-target.lastCastEvent<90 then return end
    flash(target)
end
function A:OnCast(slot)
    if not self.settings.enabled or self.preview then return end
    if slot<3 or slot>8 then return end
    local actual=GetActiveHotbarCategory()
    if actual~=self.active or self.slotRefreshPending then self:RefreshSlots(true) end
    local target=slot==8 and self.ultimate or self.slots[self.activeRow or 1][slot-2]
    local now=GetFrameTimeMilliseconds()
    if slot==8 and self.werewolfMode and ((self.furyPower or 0)>=1000 or (self.furyReadyUntil and now<=self.furyReadyUntil)) then
        -- Successful Rampage use, not merely a key press. After the game
        -- drains Fury it may report the new power before this cast event.
        self.rampageEnd=now+20000; self.furyReadyUntil=nil; self.furyPower=0; self.furyAt=nil
    end
    local trackingSlot=slot<8 and target or self.slots[self.activeRow][6]
    if trackingSlot and trackingSlot.nativeTimer then trackingSlot.nativeTimer.valid=false end
    -- A transient outgoing binding must not assign a cast to the wrong
    -- morph, Scribing combination or shared buff recipient bucket.
    local abilityKey,abilityId=Tracker.IdentifySlot(slot,actual)
    -- A dodge roll (or another cost outside the bar) that sets a primed
    -- Ulfsild's rune off makes the game report the rune's slot as used
    -- again, without a key press. That is the rune going off: start its
    -- phases, but show no second cast and prime no new rune.
    if slot<8 and trackingSlot.chain and trackingSlot.chain.trigger=="contingency" and trackingSlot.abilityKey==abilityKey
        and target.lastKeyDown and target.lastCastEvent and target.lastCastEvent>=target.lastKeyDown then
        local p=self.tracker.primed
        if p and p.key==abilityKey then self.tracker:TriggerPrimed(now) end
        return
    end
    local exhausting=slot<8 and EXHAUSTING_FATECARVER[abilityId] and trackingSlot.abilityKey==abilityKey
    -- Any other cast consumes a primed Ulfsild's Contingency rune.
    local primed=self.tracker.primed and now<=self.tracker.primed.untilTime and self.tracker.primed.key or nil
    if self:SlotHasCost(slot,actual) then self.tracker:ObserveCast(abilityKey,now) else primed=nil end
    if self.finder.active then self.finder:NoteCast(abilityKey,abilityId,GetSlotName(slot,actual),GetSlotTexture and GetSlotTexture(slot,actual),primed) end
    if trackingSlot.abilityKey==abilityKey then
        self:CacheSkillDuration(trackingSlot)
        self.tracker:OnCast(trackingSlot,now)
    end
    -- A successful cast must not restart the animation already started on key down.
    if not target.lastPress or now-target.lastPress>500 then
        flash(target)
        if slot<8 then startPress(target) end
    end
    target.lastCastEvent=now
    local channel,duration
    -- U46+ tooltip API returns (isChanneled, durationMS), not the old
    -- three-value signature. Query only the confirmed cast, never per frame.
    if abilityId and GetAbilityCastInfo then channel,duration=GetAbilityCastInfo(abilityId,nil,"player") end
    local group=trackingSlot.toggleGroup
    local indefinite=group=="meditate" or group=="deepthoughts" or group=="introspection"
    local nextMode,nextBase
    if indefinite then
        nextMode="indefinite"
    elseif (channel==true or exhausting) and type(duration)=="number" and duration>0 then
        nextMode="channel"; nextBase=duration
    elseif channel==false and type(duration)=="number" and duration>0 then
        nextMode="hardcast"; nextBase=duration
    else
        nextMode="gcd"
    end
    local castName=GetSlotName(slot,self.active) or ""
    local castIcon=GetSlotTexture and GetSlotTexture(slot,self.active) or nil
    -- When a skill is pressed while the previous cast/GCD still has time left,
    -- ESO queues it. Keep the outgoing bar intact and reuse the pre-allocated
    -- pending buffer until EVENT_ACTION_UPDATE_COOLDOWNS (GCD) or
    -- ACTION_RESULT_BEGIN (hardcast/channel) confirms actual start.
    local pending=self.PrunePendingCast and self:PrunePendingCast(now) or self.pendingCast
    if pending and pending.mode~="gcd" and pending.abilityId==abilityId then
        return
    end
    local preBeginGcd=nextMode=="gcd" and pending~=nil and pending.mode~="gcd"
        and self.castMode=="gcd" and (not self.castEnd or self.castEnd>now)
        and self.lastCastTime~=nil and pending.at~=nil and self.lastCastTime>=pending.at
    if preBeginGcd then
        if self.castAbilityId~=abilityId and self.QueuePreBeginGcd then
            self:QueuePreBeginGcd(slot,self.active,now,abilityId,castName,castIcon)
        end
        return
    end
    if nextMode=="indefinite" then
        local togglingOff=(self.castMode=="indefinite" and self.castToggleSeen)
            or self.tracker:ToggleActive(trackingSlot,slot,self.active)
        if togglingOff then
            if self.castMode=="indefinite" then self:ClearCast(true) end
            return
        end
        if self.castMode=="indefinite" and (self.castAbilityId==abilityId or (self.castToggleSlot and self.castToggleSlot.toggleGroup==group)) then
            return
        end
    end
    local gcdTail=self.lastGcdEnd and self.lastGcdEnd>now
    if nextMode~="indefinite" and ((self.castEnd and self.castEnd>now) or gcdTail) and self.QueuePendingCast then
        self:QueuePendingCast(slot,self.active,now,nextMode,abilityId,nextBase,trackingSlot,abilityKey,exhausting,castName,castIcon)
        return
    end
    -- Preserve an unpromoted queued channel/hardcast across the brief post-GCD
    -- RTT window if a follow-up instant cast arrives before ACTION_RESULT_BEGIN.
    local keepPendingCast=nextMode=="gcd" and pending~=nil and pending.mode~="gcd"
    self:ClearCast(keepPendingCast)
    self:StartCastState(now,slot,self.active,nextMode,abilityId,nextBase,trackingSlot,abilityKey,exhausting,castName,castIcon)
    if nextMode=="gcd" then self:SyncGcdCooldown(now) end
end
-- Synergy tracking lives in Synergy.lua (attached via ZeraUIAttachSynergy).
function A:UltDuration(category,row,now)
    local state=self.slots[row] and self.slots[row][6]
    if not category or not state then
        return 0,false
    end
    local remain,duration,_,estimated=self.tracker:Get(state,now)
    local native=remain==nil
    if remain==nil then
        remain,duration=readNativeCached(self,state,8,category,now,false)
        if remain<=0 then duration=nil end
    end
    local secondary,secondaryDuration
    if state.chain or state.track and state.track[2] then secondary,secondaryDuration=self.tracker:Get(state,now,2) end
    local targets=state.targetEffect and self.tracker:TargetCount(state,now) or 0
    return remain,estimated,secondary,targets,duration,secondaryDuration,native and state.skillDuration or nil
end
function A:ShowUltDuration(m,remain,estimated,secondary,targets,duration,secondaryDuration,skillDuration)
    secondary=secondary or 0; targets=targets or 0
    local hideDur=(remain<=0 and secondary<=0) or not self.settings.showUltDuration
    if m.durHidden~=hideDur then labelHidden(m.duration,hideDur); m.durHidden=hideDur end
    if not hideDur then
        local decSec=self.settings.decimalSeconds
        local rt=remain>0 and remain/1000 or 0
        local st=secondary>0 and secondary/1000 or 0
        local fine=(remain>0 and rt<=decSec) or (secondary>0 and st<=decSec)
        local rWhole=remain>0 and wholeSeconds(rt,duration,skillDuration) or 0
        local sWhole=secondary>0 and wholeSeconds(st,secondaryDuration) or 0
        local estFlag=estimated and true or false
        if fine or m.durMode~="whole" or m.durMainWhole~=rWhole or m.durSecWhole~=sWhole or m.durEst~=estFlag or m.durGen~=self.hudVisualGen then
            local main=remain>0 and (estFlag and "~" or "")..(rt<=decSec and string.format("%.1f",rt) or tostring(rWhole)) or ""
            local secText=secondary>0 and (st<=decSec and string.format("%.1f",st) or tostring(sWhole)) or nil
            setText(m.duration,secText and (main~="" and main.."/" or "")..secText or main)
            m.durMode=fine and "fine" or "whole"
            m.durMainWhole,m.durSecWhole,m.durEst,m.durGen=rWhole,sWhole,estFlag,self.hudVisualGen
        end
        setTint(m.duration,remain>0 and rt or st)
    elseif m.durMode~="zero" or m.durGen~=self.hudVisualGen then
        setText(m.duration,"")
        m.durMode="zero"; m.durMainWhole=nil; m.durSecWhole=nil; m.durGen=self.hudVisualGen
    end
    local targetVal=(targets>1 or (targets==1 and self.settings.showSingleTarget)) and targets or 0
    if m.lastTargetVal~=targetVal or m.lastTargetGen~=self.hudVisualGen then
        m.lastTargetVal,m.lastTargetGen=targetVal,self.hudVisualGen
        setText(m.target,targetVal>0 and tostring(targetVal) or "")
    end
end
function A:SetProc(slot,active)
    if active then
        if not self.procSlots[slot] then
            mapSet(self.procSlots,slot,true,"procCount"); slot.proc:SetHidden(self.loopSlots[slot]~=nil); slot.proc:SetAlpha(1); slot.procAlpha=1
        end
    elseif self.procSlots[slot] then mapSet(self.procSlots,slot,nil,"procCount"); slot.proc:SetHidden(true) end
end
-- Golden fade-out for widget tiles (set HUD): the action bar's expiry flash.
function A:FlashWidget(w) flash(w,true) end
-- Also drives set widget tiles, which have no proc highlight (slot.proc).
function A:SetGoldLoop(slot,active)
    if active then
        if not self.loopSlots[slot] then
            mapSet(self.loopSlots,slot,GetFrameTimeMilliseconds(),"loopCount"); slot.loopFrame=nil
            slot.goldLoop:SetTextureCoords(0,1/8,0,1/4)
            slot.goldLoop:SetHidden(false); if slot.proc then slot.proc:SetHidden(true) end
            if slot.goldBase then slot.goldBase:SetHidden(false); slot.goldBase2:SetHidden(false); slot.goldBaseAlpha=nil end
        end
    elseif self.loopSlots[slot] then
        mapSet(self.loopSlots,slot,nil,"loopCount"); slot.goldLoop:SetHidden(true)
        if slot.goldBase then slot.goldBase:SetHidden(true); slot.goldBase2:SetHidden(true) end
        if slot.proc then slot.proc:SetHidden(not self.procSlots[slot]) end; slot.loopFrame=nil
    end
end
function A:SkillLoopReady(s,stack,loopT,nw,whipKind,cat,active)
    if whipKind=="balance" or whipKind=="immune" or whipKind=="cooldown" or s.noExpiryGlow or not self.settings.animations or
        s.toggleGroup=="banner" or s.unavailable or s.iconHidden then return false end
    syncSlotOptions(s)
    if cat~=active and not s.optLoopInactive then return false end
    -- Power Lash: the golden loop for as long as its charges last.
    if whipKind=="charges" then return true end
    if s.stackReadyAt then
        return not nw and not s.isCharge and stack>=s.stackReadyAt
    end
    if s.noStackGlow and stack>0 then return false end
    return (not s.focusRequired and s.optExpiryLoop and loopT>0 and loopT<=s.optLoopSeconds) or
        (not nw and not s.isCharge and not s.noStackGlow and s.optStackLoop and stack>=s.optLoopStacks)
end
function A:SetToggle(slot,active)
    active=not not active
    local visible=active and self.settings.toggleGlow and true or false
    local pulse=visible and self:TogglePulseEnabled(slot.toggleGroup) and true or false
    local strength=self.settings.toggleGlowStrength
    if slot.toggled==active and slot.toggleGlowShown==visible and slot.togglePulseWanted==pulse and slot.togglePulseStrength==strength then return end
    slot.toggled=active
    if slot.toggleGlowShown~=visible then
        slot.toggleGlowShown=visible; slot.toggleGlow:SetHidden(not visible)
    end
    if slot.togglePulseWanted~=pulse or slot.togglePulseStrength~=strength then
        slot.togglePulseWanted=pulse; slot.togglePulseStrength=strength
        self:SetTogglePulse(slot.toggleGlow,pulse,strength)
    end
end
local PASSIVE_CORNERS=8
local function passiveSlotKind(cfg,slot)
    if slot.vampirePassiveSlot and cfg.showVampirePassive~=false then return "vampire" end
    local mode=cfg.arcanistPassiveMode or "Fatecarver"
    if slot.arcanistPassiveSlot and (mode==slot.arcanistPassiveSlot or mode=="Both") then return "arcanist" end
end
-- Features that draw their own timers or badges on a skill. While one is
-- on, the skill's own timers can't be edited and are suppressed in the
-- binding only. The saved rule survives a change of build or equipment.
-- A passive feature locks a skill only when this character can get that
-- passive. Subclassing removes Class Mastery (Nothing Wasted), and a whip
-- from a subclassed Ardent Flame has no Landslide without Earthen Heart.
-- Buff ids of each feature; the passive is found by id or, failing that, by
-- the buff's name (both names come from the same client language).
local LOCK_PASSIVES={landslide={29465,238232},nw={263461},vampire={135189,135190},arcanist={263369,268372},wardMastery={263873}}
local function plainName(name)
    name=tostring(name or ""):gsub("%^.*$",""):gsub("’","'"):lower()
    return (name:gsub("^%s+",""):gsub("%s+$",""))
end
local function skillLineNativeActive(line)
    if not line then return true end
    -- ZO_SkillLineData:RefreshDynamicData overrides isActive=true for the
    -- player's own Class Mastery line even after subclassing. Read the native
    -- dynamic active flag for Class Mastery lines directly.
    if GetSkillLineDynamicInfo and line.GetIndices then
        local skillType,skillLineIndex=line:GetIndices()
        if skillType and skillLineIndex then
            local _,_,nativeActive,_,_,_,isClassMastery=GetSkillLineDynamicInfo(skillType,skillLineIndex)
            if isClassMastery or (line.IsClassMastery and line:IsClassMastery()) then
                return nativeActive==true
            end
        end
    end
    if line.IsActive then return line:IsActive()==true end
    return true
end
local function passiveOwned(skillData)
    if not skillData or (skillData.IsPassive and not skillData:IsPassive()) then return nil end
    -- Class Mastery passives report rank 0 whether purchased or not, so rely
    -- on purchased state (native first when indices exist), never rank > 0.
    local purchased
    if IsSkillAbilityPurchased and skillData.GetIndices then
        local skillType,skillLineIndex,skillIndex=skillData:GetIndices()
        if skillType and skillLineIndex and skillIndex then
            purchased=IsSkillAbilityPurchased(skillType,skillLineIndex,skillIndex)==true
        end
    end
    if purchased==nil then purchased=skillData.IsPurchased and skillData:IsPurchased()==true or false end
    if not purchased then return false end
    local line=skillData.GetSkillLineData and skillData:GetSkillLineData()
    return skillLineNativeActive(line)
end
-- true / false, or nil while ESO's skill data is not ready (then the lock
-- stays, as before). Cached until skills, points or lines change.
function A:CharacterHasPassive(kind)
    local ids=LOCK_PASSIVES[kind]
    if not ids then return true end
    self.passiveKnown=self.passiveKnown or {}
    if self.passiveKnown[kind]~=nil then return self.passiveKnown[kind] end
    local m=SKILLS_DATA_MANAGER
    if not (m and m.GetSkillTypeData) or (m.IsDataReady and not m:IsDataReady()) then return nil end
    local result,names=false,{}
    if kind=="wardMastery" and m.GetNumPlayerClassActiveSkillLines and m.GetNumActiveClassSkillLines and
        m:GetNumPlayerClassActiveSkillLines()~=m:GetNumActiveClassSkillLines() then
        self.passiveKnown[kind]=false; return false
    end
    for _,id in ipairs(ids) do
        local progression=m.GetProgressionDataByAbilityId and m:GetProgressionDataByAbilityId(id)
        local data=progression and progression.GetSkillData and progression:GetSkillData()
        if not data and m.GetSkillDataByAbilityId then data=m:GetSkillDataByAbilityId(id) end
        local owned=passiveOwned(data)
        if owned then result=true end
        local name=GetAbilityName and plainName(GetAbilityName(id)) or ""
        if name~="" then names[name]=true end
    end
    if not result and next(names) then
        for _,skillType in ipairs({SKILL_TYPE_CLASS,SKILL_TYPE_WORLD}) do
            local typeData=skillType and m:GetSkillTypeData(skillType)
            if typeData and typeData.SkillLineIterator then
                for _,line in typeData:SkillLineIterator() do
                    if skillLineNativeActive(line) and line.SkillIterator then
                        for _,skillData in line:SkillIterator() do
                            local progression=skillData.GetCurrentProgressionData and skillData:GetCurrentProgressionData()
                            local name=progression and progression.GetName and plainName(progression:GetName())
                            if (not name or name=="") and GetSkillAbilityInfo and skillData.GetIndices then
                                local skillType,skillLineIndex,skillIndex=skillData:GetIndices()
                                if skillType and skillLineIndex and skillIndex then
                                    name=plainName((GetSkillAbilityInfo(skillType,skillLineIndex,skillIndex)))
                                end
                            end
                            if name and names[name] and passiveOwned(skillData) then result=true; break end
                        end
                    end
                    if result then break end
                end
            end
            if result then break end
        end
    end
    self.passiveKnown[kind]=result
    return result
end
function A:ForgetPassives() self.passiveKnown=nil end
function A:TrackingLock(slot)
    local cfg=self.settings
    if not slot or not slot.abilityKey then return nil end
    local function passive(kind) return self:CharacterHasPassive(kind)~=false and kind or nil end
    if cfg.showNothingWasted and slot.nwSlot and passive("nw") then return "nw" end
    local kind=passiveSlotKind(cfg,slot)
    if kind and passive(kind) then return kind end
    if cfg.showLandslide and slot.landslideSlot and passive("landslide") then return "landslide" end
    return nil
end
-- The middle timer of these skills is always drawn by their own mechanic:
-- Flame Lash (Off Balance / immunity, Power Lash charges) and Exhausting Fatecarver's channel.
function A:MiddleBlocked(slot)
    if not slot or not slot.abilityKey then return nil end
    if slot.flameSlot then return "whip" end
    if EXHAUSTING_FATECARVER[slot.abilityId] then return "exhausting" end
end
function A:ArmoryStarted(operation,buildIndex)
    if operation~=ARMORY_BUILD_OPERATION_TYPE_RESTORE or self.armoryRestore then return end
    self.armoryRestore={index=buildIndex,slots=self.slotRefreshPending or self.swapPending~=nil}
    self.slotRefreshPending=nil
    if self.slotWorkDue then EM:UnregisterForUpdate(ADDON.."SlotWork"); self.slotWorkDue=nil end
end
function A:FlushEquipmentChanged()
    self.gearRefreshPending=nil
    self.gearRefreshGen=(self.gearRefreshGen or 0)+1
    if self.armoryRestore then self.armoryRestore.gear=true; return end
    Tracker.ResetFormTrust()
    self.tracker:GearChanged()
    self:RefreshWeaponLoadouts()
    self:SkillModifiersChanged(); self.setCooldowns:Refresh()
end
function A:EquipmentChanged(full)
    if full then
        self.quickDirty=true
        self.gearRefreshPending=nil
        self.gearRefreshGen=(self.gearRefreshGen or 0)+1
        self:FlushEquipmentChanged()
        return
    end
    Tracker.ResetFormTrust()
    if self.armoryRestore then self.armoryRestore.gear=true; return end
    if self.gearRefreshPending then return end
    local gen=(self.gearRefreshGen or 0)+1
    self.gearRefreshGen=gen
    self.gearRefreshPending=true
    if zo_callLater then
        zo_callLater(function()
            if self.gearRefreshPending and self.gearRefreshGen==gen then self:FlushEquipmentChanged() end
        end,20)
    else
        self:FlushEquipmentChanged()
    end
end
function A:ArmoryResponse(result,buildIndex)
    local pending=self.armoryRestore
    if pending and pending.index and buildIndex and pending.index~=buildIndex then return end
    self.armoryRestore=nil
    self.gearRefreshPending=nil
    self.gearRefreshGen=(self.gearRefreshGen or 0)+1
    Tracker.ResetFormTrust()
    if result~=ARMORY_BUILD_RESTORE_RESULT_SUCCESS then
        -- No reset for failed operations. If native data actually changed,
        -- reconcile only the observed dirty metadata, preserving timers.
        if pending then
            if pending.gear then self:EquipmentChanged(true) end
            if pending.skills then self:SkillsChanged() end
            if pending.slots then self:RequestSlotRefresh() end
            self:ScheduleSlotWork()
        end
        return
    end
    self.characterRefreshAfterCombat=nil; self:ForgetPassives()
    self.weaponLoadouts=nil; self.quickDirty=true
    self.tracker:ResetRuntime(); self.effectHUD:Invalidate(); self.setCooldowns:ResetPA(false)
    self:RefreshSlots()
    self.tracker:ScanUnit("player"); self.tracker:ScanUnit("reticleover")
    self.setCooldowns:Refresh(true)
end
function A:EnforceTrackingLocks()
    if not self.categories or self.armoryRestore then return end
    local rules=self.tracker.rules
    if not next(rules) then return end
    for r=1,2 do
        local category=self.categories[r]
        if category then for i=1,6 do
            local s=self.slots[r][i]
            local base=s.abilityId and "a:"..s.abilityId
            if rules[s.abilityKey] or (base and rules[base]) or s.ruleLock then
                local lock=i<6 and self:TrackingLock(s)
                if lock and self:CharacterHasPassive(lock)==nil then lock=nil end
                local mode=(i==6 or lock) and "all" or (self:MiddleBlocked(s) and "middle" or false)
                if (s.ruleLock or false)~=mode then
                    self.tracker:Bind(s,i<=5 and i+2 or 8,category,false,mode)
                    if i<6 then s.timerWholeSec=nil; s.timerTextMode=nil; s.stackCacheGen=nil; s.auxCacheValue=nil; s.skillOptGen=nil; s.lastTargetCountGen=nil end
                end
            end
        end end
    end
end
local function passivePosition(corner,w,h)
    local x=corner%2==1 and 0 or SIZE-w
    local y=corner<=2 and SIZE-h or corner<=4 and 0 or corner<=6 and -h-2 or SIZE+2
    return x,y
end
local function passiveIntersects(x,y,w,h,corner,badgeW,badgeH)
    local px,py=passivePosition(corner,badgeW,badgeH)
    return x and y and w and h and x<px+badgeW and x+w>px and y<py+badgeH and y+h>py or false
end
local function passiveCorner(blockedLeft,blockedRight,blockedTopLeft,blockedTopRight,used,w,h)
    for corner=1,PASSIVE_CORNERS do
        local blocked=(corner==1 and blockedLeft) or (corner==2 and blockedRight) or
            (corner==3 and blockedTopLeft) or (corner==4 and blockedTopRight)
        local ux,uy
        if used then ux,uy=passivePosition(used,w,h) end
        if not blocked and (not used or not passiveIntersects(ux,uy,w,h,corner,w,h)) then return corner end
    end
    return 8
end
local function passiveOccupied(slot,corner,w,h)
    local target=slot.target.vabText and slot.target.vabText~=""
    if target then
        local tw,th=slot.recipientW or 20,slot.recipientH or 20
        local cx=slot.groupBuffCount and 16 or 15
        local cy=slot.groupBuffCount and 55 or 11
        if passiveIntersects(cx-tw/2,cy-th/2,tw,th,corner,w,h) then return true end
    end
    if slot.stack.vabText and slot.stack.vabText~="" then
        local sw,sh=slot.stackBadgeWidth or 26,slot.stackBadgeHeight or 24
        if passiveIntersects(49-sw/2,13-sh/2,sw,sh,corner,w,h) then return true end
    end
    for index=2,3 do
        if slot.extraTimers[index].vabVisible then
            local ew=slot.extraTimerWidths and slot.extraTimerWidths[index] or 30
            local eh=slot.extraTimerHeights and slot.extraTimerHeights[index] or 20
            local top=(index==2 and slot.recipientCountVisible)
            local cx=index==2 and 16 or 48
            local cy=top and 11 or 54
            if passiveIntersects(cx-ew/2,cy-eh/2,ew,eh,corner,w,h) then return true end
        end
    end
    if slot.landslideLabel and slot.landslideLabel.vabText and slot.landslideLabel.vabText~="" then
        local lw,lh=slot.landslideWidth or 18,slot.landslideHeight or 17
        if passiveIntersects(1,SIZE-lh+1,lw,lh,corner,w,h) then return true end
    end
    if slot.auxCount and slot.auxCount.vabText and slot.auxCount.vabText~="" then
        local size=A.settings.cornerBadgeSize or 16
        local aw,ah=math.max(28,math.ceil(size*.67*4+4)),math.max(18,size+4)
        if passiveIntersects((SIZE-aw)/2,10-ah/2,aw,ah,corner,w,h) then return true end
    end
    if slot.estimatedShown and passiveIntersects(22,1,20,20,corner,w,h) then return true end
    return false
end
function A:EnsurePassiveBadge(slot,index)
    slot.passiveBadges=slot.passiveBadges or {}
    local badge=slot.passiveBadges[index]
    if not badge then
        badge={back=texture(slot.container,PATH.."stackbadge-ready.dds",32,17,0,47,17),
            label=text(slot.container,12,32,17,0,46,20)}
        slot.passiveBadges[index]=badge
        self:ApplyNativeFont(badge.label,self.effectiveFont or self:ResolveFont(self.settings.fontFace),self.settings.cornerBadgeSize or 16,self.settings.fontStyle,true)
        badge.back:SetHidden(true); labelHidden(badge.label,true)
    end
    return badge
end
function A:ShowPassiveBadges(slot,left,duration,second,secondDuration,kind)
    local badges=slot.passiveBadges
    local firstShown=left and left>0
    local secondShown=second and second>0
    if not firstShown and not secondShown then
        if badges then for i=1,2 do
            local badge=badges[i]
            if badge and badge.visible then badge.visible=false; badge.back:SetHidden(true); labelHidden(badge.label,true) end
        end end
        return
    end
    if not badges then self:EnsurePassiveBadge(slot,firstShown and 1 or 2); badges=slot.passiveBadges end
    -- Mastery boxes stay within half the skill; use the configured font caps.
    local size,badgeW,badgeH=passiveBadgeSize(self.settings.cornerBadgeSize,kind)
    local lowerLeft=passiveOccupied(slot,1,badgeW,badgeH)
    local lowerRight=passiveOccupied(slot,2,badgeW,badgeH)
    local topLeft=passiveOccupied(slot,3,badgeW,badgeH)
    local topRight=passiveOccupied(slot,4,badgeW,badgeH)
    local used
    for index=1,2 do
        local remain=index==1 and left or second
        local span=index==1 and duration or secondDuration
        local shown=remain and remain>0
        local badge=badges[index]
        if shown and not badge then badge=self:EnsurePassiveBadge(slot,index) end
        if badge then
            if shown then
                local prefix=kind=="arcanist" and (index==1 and "A" or "F") or ""
                local value=prefix..tostring(wholeSeconds(seconds(remain),span))
                -- Two mastery badges share the bottom row: at most half the icon each.
                local _,w=self:FitCounterText(badge.label,self.effectiveFont or self:ResolveFont(self.settings.fontFace),
                    self.settings.fontStyle,true,value,size,badgeW,kind=="arcanist" and SIZE/2 or 40,true,
                    #value<=#prefix+2 and prefix.."99" or nil)
                local corner=passiveCorner(lowerLeft,lowerRight,topLeft,topRight,used,badgeW,badgeH)
                used=corner
                if badge.corner~=corner or badge.w~=w or badge.h~=badgeH then
                    local x,y=passivePosition(corner,w,badgeH)
                    badge.back:SetDimensions(w,badgeH); badge.label:SetDimensions(w,badgeH)
                    reposition(badge.back,slot.container,x,y)
                    reposition(badge.label,slot.container,x,y-1)
                    badge.corner,badge.w,badge.h=corner,w,badgeH
                end
                local tint=kind=="arcanist" and (index==1 and "abyss" or "fate") or "vampire"
                if badge.tint~=tint then
                    if tint=="abyss" then color(badge.label,.66,1,.81)
                    elseif tint=="fate" then color(badge.label,.71,.88,1)
                    else color(badge.label,1,.90,.70) end
                    badge.tint=tint
                end
                setText(badge.label,value)
            end
            if badge.visible~=not not shown then
                badge.visible=not not shown
                badge.back:SetHidden(not shown); labelHidden(badge.label,not shown)
            end
        end
    end
end
function A:EnsureLandslide(slot)
    if not slot.landslideLabel then
        -- Reuse the existing beveled metallic badge, with an emerald tint.
        slot.landslideBadge=texture(slot.container,PATH.."stackbadge-ready.dds",18,17,1,SIZE-18,17)
        color(slot.landslideBadge,.48,1,.67)
        slot.landslideLabel=text(slot.container,self.settings.cornerBadgeSize or 16,18,17,1,SIZE-19,19)
        local size=self.landslideFontLimit or self.settings.cornerBadgeSize or 16
        self:FitCounterText(slot.landslideLabel,self.effectiveFont or self:ResolveFont(self.settings.fontFace),self.settings.fontStyle,true,"9",size,stackBadgeSize(self.settings.cornerBadgeSize or 16,"9"),36,true)
        color(slot.landslideLabel,.63,1,.80)
        slot.landslideBadge:SetHidden(true); slot.landslideBadgeHidden=true; labelHidden(slot.landslideLabel,true)
        slot.auxCacheValue=nil
    end
end
local function sizeAuxCount(slot,size)
    local width=math.max(28,math.ceil(size*.67*4+4))
    local height=math.max(18,size+4)
    slot.auxCount:SetDimensions(width,height)
    reposition(slot.auxCount,slot.container,(SIZE-width)/2,10-height/2)
    slot.auxCacheValue=nil
end
function A:EnsureAuxCount(slot)
    if not slot.auxCount then
        local label=text(slot.container,14,28,18,18,0,18)
        slot.auxCount=label
        self:ApplyNativeFont(label,self.effectiveFont or self:ResolveFont(self.settings.fontFace),self.settings.cornerBadgeSize or 16,self.settings.fontStyle,true)
        sizeAuxCount(slot,self.settings.cornerBadgeSize or 16)
        color(label,1,.82,.35); labelHidden(label,true)
        slot.auxCacheValue=nil
    end
end
local function positionExtraTimer(slot,index,top)
    local width=slot.extraTimerWidths and slot.extraTimerWidths[index] or 30
    local height=slot.extraTimerHeights and slot.extraTimerHeights[index] or 20
    local cfg=A.settings
    if index==2 then
        -- Phase strings need more horizontal room than a two-digit timer.
        -- Clamp the whole label inside the 64px icon, even with custom offsets.
        if slot.phaseBadge then width,height=42,18 end
        local label=slot.extraTimers[index]
        label:SetDimensions(width,height)
        if label.phaseWidth~=width or label.phaseHeight~=height then
            label.phaseWidth,label.phaseHeight=width,height
            label.extraFitText=nil
        end
        if slot.phaseBadge then
            local x=math.max(2,math.min(64-width-2,2+(cfg.extraLeftX or 0)))
            local y=math.max(2,math.min(64-height-2,44+(cfg.extraLeftY or 0)))
            reposition(label,slot.container,x,y); return
        end
    end
    local cx=index==2 and 16+(cfg.extraLeftX or 0) or 48+(cfg.extraRightX or 0)
    local cy=((top or (index==3 and slot.topRightTimer)) and 11 or 54)+(index==2 and (cfg.extraLeftY or 0) or (cfg.extraRightY or 0))
    reposition(slot.extraTimers[index],slot.container,cx-width/2,cy-height/2)
end
-- Reuse the ordinary target label; only add one metallic backing for a
-- supported group buff. Prewarm at binding time, never on the first buff.
function A:PrepareRecipientBadge(slot)
    local cfg=self.settings
    local group=slot.groupBuffCount and true or false
    if group and not slot.recipientBadge then
        slot.recipientBadge=texture(slot.container,PATH.."stackbadge-ready.dds",26,18,1,SIZE-18,17)
        slot.recipientBadge:SetHidden(true); slot.recipientBadgeHidden=true
    end
    if slot.targetGroupStyle~=group then
        slot.targetGroupStyle=group
        local label=slot.target
        label:SetDrawLevel(group and 19 or 9)
        label.vabFontGeneration=nil
    end
    local targetSize=boundedSize(cfg.targetSize,16,10,22)
    local width,height=recipientBadgeSize(targetSize,group)
    if slot.recipientW~=width or slot.recipientH~=height or slot.recipientGeometryGroup~=group then
        slot.recipientW,slot.recipientH,slot.recipientGeometryGroup=width,height,group
        slot.target:SetDimensions(width,height)
        local x=(group and 16 or 15)-width/2
        local y=(group and 55 or 11)-height/2
        reposition(slot.target,slot.container,x,y)
        if slot.recipientBadge then
            slot.recipientBadge:SetDimensions(width,height)
            reposition(slot.recipientBadge,slot.container,x,y+1)
        end
    end
    local font=self.effectiveFont or self:ResolveFont(cfg.fontFace)
    self:FitCounterText(slot.target,font,cfg.fontStyle,group and true or nil,"99",targetSize,width,group and 32 or width,group)
    slot.target.countFitText=nil
    slot.lastTargetCountGen=nil
    if slot.recipientBadge and not group then slot.recipientBadge:SetHidden(true); slot.recipientBadgeHidden=true end
end
function A:ShowTargetCount(slot,value)
    setText(slot.target,value)
    if value~="" then
        local size=boundedSize(self.settings.targetSize,16,10,22)
        local label=slot.target
        if label.countFitText~=value or label.countFitSize~=size or label.countFitGeneration~=self.fontGeneration then
            local font=self.effectiveFont or self:ResolveFont(self.settings.fontFace)
            if slot.groupBuffCount then
                -- Metallic group badge: fit inside its bevel, widen a little if needed.
                local base=recipientBadgeSize(size,true)
                local _,w=self:FitCounterText(label,font,self.settings.fontStyle,true,value,size,base,32,true,#value<=2 and "99" or nil)
                if w~=slot.recipientW then
                    local h=slot.recipientH or 18
                    slot.recipientW=w; label:SetDimensions(w,h); reposition(label,slot.container,16-w/2,55-h/2)
                    if slot.recipientBadge then slot.recipientBadge:SetDimensions(w,h); reposition(slot.recipientBadge,slot.container,16-w/2,55-h/2+1) end
                end
            else
                local room=slot.recipientW or 30
                self:FitCounterText(label,font,self.settings.fontStyle,nil,value,size,room,room,false,#value<=2 and "99" or nil)
            end
            label.countFitText,label.countFitSize,label.countFitGeneration=value,size,self.fontGeneration
        end
    end
    if slot.recipientBadge then
        local visible=slot.groupBuffCount and value~=""
        local showBadge=visible and self.settings.stackBadge
        local badgeHidden=not showBadge
        if slot.recipientBadgeHidden~=badgeHidden then slot.recipientBadgeHidden=badgeHidden; slot.recipientBadge:SetHidden(badgeHidden) end
        if slot.recipientCountVisible~=visible then
            -- The cyan auxiliary timer uses the lower left by default.
            -- Move it above the skill temporarily if the recipient badge is visible.
            positionExtraTimer(slot,2,visible)
            slot.recipientCountVisible=visible
        end
    end
end
function A:AuxiliaryCount(slot,value)
    if slot.auxCacheValue==value and slot.auxCacheGen==self.hudVisualGen and slot.auxCacheFontGen==self.fontGeneration then return end
    local landslide=value:sub(1,2)=="L:" and value:match("^L:(%d+)$") or nil
    if landslide then self:EnsureLandslide(slot) end
    if slot.landslideLabel then
        local visible=landslide~=nil
        local width,height=stackBadgeSize(self.settings.cornerBadgeSize or 16,landslide or "")
        if landslide then
            local _
            local size=self.landslideFontLimit or self.settings.cornerBadgeSize or 16
            _,width=self:FitCounterText(slot.landslideLabel,self.effectiveFont or self:ResolveFont(self.settings.fontFace),
                self.settings.fontStyle,true,landslide,size,width,36,true)
        end
        if slot.landslideWidth~=width or slot.landslideHeight~=height then
            slot.landslideWidth,slot.landslideHeight=width,height
            slot.landslideBadge:SetDimensions(width,height); reposition(slot.landslideBadge,slot.container,1,SIZE-height+2)
            slot.landslideLabel:SetDimensions(width,height); reposition(slot.landslideLabel,slot.container,1,SIZE-height+1)
        end
        local badgeHidden=not visible or not self.settings.stackBadge
        if slot.landslideBadgeHidden~=badgeHidden then slot.landslideBadgeHidden=badgeHidden; slot.landslideBadge:SetHidden(badgeHidden) end
        setText(slot.landslideLabel,landslide or ""); labelHidden(slot.landslideLabel,not visible)
    end
    local auxText=landslide and "" or value
    if auxText~="" and not slot.auxCount then self:EnsureAuxCount(slot) end
    if slot.auxCount then
        setText(slot.auxCount,auxText)
        labelHidden(slot.auxCount,auxText=="")
    end
    slot.auxCacheValue,slot.auxCacheGen,slot.auxCacheFontGen=value,self.hudVisualGen,self.fontGeneration
end

function A:PrepareSlotControls(slot)
    if not self.effectiveFont then return end
    local passiveKind=passiveSlotKind(self.settings,slot)
    if passiveKind then
        self:EnsurePassiveBadge(slot,1)
        if passiveKind=="arcanist" then self:EnsurePassiveBadge(slot,2) end
    end
    self:PrepareRecipientBadge(slot)
    positionExtraTimer(slot,2,slot.recipientCountVisible)
    positionExtraTimer(slot,3,false)
    if slot.landslideSlot and self.settings.showLandslide then self:EnsureLandslide(slot) end
    if slot.externalCountEffect and self.settings.showExternalCounts then self:EnsureAuxCount(slot) end
end

-- Attribute bars: Off (ESO's own bars, untouched), Default (ESO's bars
-- arranged by Zera) or Custom (Zera's own bars). attrEnabled/attrCustomSkin
-- are the pre-split keys, kept in step for one version so a rollback works.
local ATTRIBUTE_LAYOUTS={Default={"Pyramid","Native"},Custom={"Curved","Native","Stacked","Pyramid"}}
function A:AttributeLayoutChoices(mode)
    local list=ATTRIBUTE_LAYOUTS[(mode or self.settings.attrMode)=="Default" and "Default" or "Custom"]
    local out={}; for i,v in ipairs(list) do out[i]=v end
    return out
end
function A:NormalizeAttributeLayout()
    local s=self.settings
    if s.attrMode~="Off" and s.attrMode~="Default" and s.attrMode~="Custom" then s.attrMode="Custom" end
    s.attrEnabled=s.attrMode~="Off"
    if s.attrMode~="Off" then s.attrCustomSkin=s.attrMode=="Custom" end
    for _,layout in ipairs(self:AttributeLayoutChoices()) do if layout==s.attrLayout then return end end
    s.attrLayout="Pyramid"
    self:ResetAttributePositions()
end
function A:SetAttributeMode(mode)
    self.settings.attrMode=mode
    self:NormalizeAttributeLayout()
    self:ApplySettings()
end
function A:SetAttributeLayout(layout)
    local allowed=false
    for _,l in ipairs(self:AttributeLayoutChoices()) do if l==layout then allowed=true end end
    if not allowed then return end
    if self.settings.attrLayout~=layout then
        self.settings.attrLayout=layout
        self:ResetAttributePositions()
    end
    self:ApplySettings()
end
function A:EnterEditorInput()
    local manager=SCENE_MANAGER
    if manager and manager.SetInUIMode then
        manager:SetInUIMode(true)
        if manager.ShowBaseScene then manager:ShowBaseScene() end
    else
        if manager and manager.SetBaseScene then manager:SetBaseScene("hudui") end
        if manager and manager.Show then manager:Show("hudui") end
        if SetGameCameraUIMode then pcall(SetGameCameraUIMode,true) end
    end
end
function A:ReleaseEditorInput()
    local manager=SCENE_MANAGER
    if not manager or (not manager:IsShowing("hudui") and not manager:IsShowing("hud")) then return end
    -- SetInUIMode switches both the base scene AND its input action layer.
    -- Turning the camera off first bypasses that transition in ESO.
    if manager.SetInUIMode then
        manager:SetInUIMode(false)
    else
        if manager.SetBaseScene then manager:SetBaseScene("hud") end
        if SetGameCameraUIMode then pcall(SetGameCameraUIMode,false) end
        if manager.Show then manager:Show("hud") end
    end
end

function A:LayoutUltimateNumbers(werewolf)
    local m,s=self.ultimate,self.settings
    local font=self.effectiveFont or self:ResolveFont(s.fontFace)
    local size=werewolf and math.min(21,s.ultValueSize) or s.ultValueSize
    self:ApplyNativeFont(m.value,font,size,s.fontStyle,"strong")
    self:ApplyNativeFont(m.furyValue,font,math.min(18,math.max(14,size-2)),s.fontStyle,"strong")
    m.value:SetDimensions(82,werewolf and 24 or 82)
    reposition(m.value,m.container,0,werewolf and 42 or 0)
    m.furyValue:SetDimensions(82,22)
    reposition(m.furyValue,m.container,0,13)
    m.valueBacking:SetDimensions(math.min(70,size*2.05),werewolf and 24 or math.min(56,size*1.38))
    m.valueBacking:ClearAnchors()
    m.valueBacking:SetAnchor(CENTER,m.container,CENTER,0,werewolf and 13 or 0)
    m.werewolfLayout=werewolf or false
    self.hudVisualGen=(self.hudVisualGen or 0)+1
end
function A:UpdateQuickslot(now)
    if not self.settings.showQuickslot then return end
    local q=self.quickSlot or (GetCurrentQuickslot and GetCurrentQuickslot())
    if not q then return end
    self.quickSlot=q
    local category=HOTBAR_CATEGORY_QUICKSLOT_WHEEL
    if not self.inventoryEvents or self.quickDirty or not self.quickCountAt then
        local count=GetSlotItemCount(q,category) or 0
        local kind=GetSlotType and GetSlotType(q,category)
        -- Collectibles and emotes have no inventory count but remain usable.
        local empty=(kind==nil or kind==ACTION_TYPE_ITEM) and count<=0 or (ACTION_TYPE_NOTHING~=nil and kind==ACTION_TYPE_NOTHING)
        if self.quickEmpty~=empty then
            self.quickEmpty=empty; self.quickRenderIdle=nil; self.quickRenderAt=nil
            if empty then clearFlash(self.quick) end
        end
        setText(self.quick.sub,count>0 and tostring(count) or "")
        self.quickDirty=false; self.quickCountAt=now
    end
    if not self.cooldownEvents or self.quickCooldownDirty or (self.quickEnd and now>=self.quickEnd) then
        self.quickCooldownDirty=false
        local rem,dur,global=GetSlotCooldownInfo(q,category)
        -- Global 1s skill cooldown is NOT a potion cooldown.
        if (rem or 0)>0 and (dur or 0)>2000 then
            local nextEnd=now+rem
            if not self.quickEnd or math.abs(nextEnd-self.quickEnd)>15 or self.quickDuration~=dur then
                self.quickRenderAt=nil; self.quickRenderIdle=nil
            end
            self.quickEnd=nextEnd; self.quickDuration=dur
        elseif (rem or 0)<=0 and not global then
            if self.quickEnd~=nil or self.quickDuration~=nil then self.quickRenderAt=nil; self.quickRenderIdle=nil end
            self.quickEnd=nil; self.quickDuration=nil
        end
    end
    local cooling=self.quickEnd and self.quickEnd>now or false
    local blocked=cooling or self.quickEmpty
    meterDesaturation(self.quick,blocked and .8 or 0)
    local alpha=blocked and .23 or 1
    if self.quickIconAlpha~=alpha then self.quick.icon:SetAlpha(alpha); self.quickIconAlpha=alpha end
    if not cooling and self.quickCooling and not self.quickEmpty then flash(self.quick) end
    self.quickCooling=cooling
end
-- The effect grids are drawn on the frame after the tick, so the skill
-- timers and the grids do not add up in one frame (a trial boss profile put
-- the tick at 1.4 ms, a quarter to a half of it the grids). It shares the
-- tick's effect readings unless the grids saw an effect or target change
-- since the tick; then it reads the lists fresh, so nothing is scanned
-- from stale readings.
function A:RunDeferredHUD()
    self.hudDueAfter=nil
    local snapshot=self.effectSnapshot
    if snapshot and self.effectHUD.changeSeq~=self.hudSeq then snapshot:Begin() end
    self.effectHUD:Update(nil,snapshot)
end
function A:Tick()
    -- No frame was drawn since the last tick (e.g. the bar is hidden): the
    -- grids update inside this tick, as before, sharing its readings.
    local frame=GetFrameTimeMilliseconds()
    local inline=not self.renderFrame or not self.tickFrame or self.renderFrame<=self.tickFrame
    self.tickFrame=frame; self.hudDueAfter=nil
    -- Share raw native readings only within this synchronous tick. Event
    -- handlers and recovery outside Tick always read the live API directly.
    local snapshot=self.effectSnapshot
    if not snapshot then snapshot=ZeraUIEffectSnapshot.New(); self.effectSnapshot=snapshot end
    snapshot:Begin()
    -- Settle bindings before consuming effects. Recovery triggered by the
    -- binding pass can share these fresh native rows with all tick readers.
    local now,active
    if not self.preview then
        now=GetFrameTimeMilliseconds(); active=GetActiveHotbarCategory()
        if active~=self.active or self.slotRefreshPending or self.swapPending and now>=self.swapPending.untilTime then self:RefreshSlots(true,snapshot) end
    end
    if self.reticleScanPending then
        self.reticleScanPending=nil
        self.tracker:ScanUnit("reticleover",snapshot)
        if self.setCooldowns then self.setCooldowns:ReticleChanged(snapshot,true) end
    end
    if self.setCooldowns then self.setCooldowns:PaintNow(snapshot) end
    if self.effectHUD then
        if inline then self.effectHUD:Update(nil,snapshot)
        else self.hudDueAfter=frame; self.hudSeq=self.effectHUD.changeSeq end
    end
    if self.preview then return end
    if self.swapTimerUntil and now>=self.swapTimerUntil then self.swapTimerUntil=nil; self:InvalidateNativeTimers() end
    self.tracker:UpdateToggleRecovery(now,snapshot)
    if not self.swapPending then self.tracker:SampleNativeBanner(self.slots[self.activeRow],active,now) end
    self.tracker:Prune(now)
    -- Sample the channel before its skill timer so both read one endpoint.
    self:SampleCast(now)
    self.tracker:RefreshReticle(snapshot)
    self:UpdateSkillTimers(now,active)
    setText(self.passiveTimer,self.tracker:PassiveText(now))
    self:UpdateUltimate(now)
    self:UpdateQuickslot(now)
    if self:SynergyDue(now) then self:RefreshSynergy() end
end

-- A single synchronous read context for both skill rows. No change to the
-- 100 ms cadence, event ordering, or independent visual channels.
function A:UpdateSkillTimers(now,active)
    local sample=self.slotUpdateSample or {}; self.slotUpdateSample=sample
    sample.active=active; sample.enemyRead=false; sample.enemy=nil
    local cfg,tracker=self.settings,self.tracker
    local follow=tracker.followTarget
    local decSec=cfg.decimalSeconds
    local hudGen,fontGen=self.hudVisualGen,self.fontGeneration
    local studioTest=self.studioTest
    for row=1,2 do
        local cat=self.categories[row]
        if cat then for i=1,5 do
            local slot=i+2
            local s=self.slots[row][i]
            if not s.abilityId then
                if s.appearanceDirty then self:UpdateSlotAppearance(s,slot,cat,now,sample) end
            else
            -- Reticle validity remains responsive on the active row even when
            -- a native event is missing (e.g. death or attackability change).
            -- SlotUnavailable ignores target/range checks on the inactive bar,
            -- while s.focusRequired stays evaluated on both rows for Focus stacks.
            local targetChanged=false
            if cat==active and s.targetKind=="enemy" and self.settings.showUnavailable and self.settings.darkenTarget then
                if not sample.enemyRead then reticleEnemy(sample) end
                targetChanged=s.appearanceEnemy~=sample.enemy
                s.appearanceEnemy=sample.enemy
            end
            if s.appearanceDirty or s.focusRequired or targetChanged or cat==active and
                (not s.appearanceCheckAt or cfg.showUnavailable and
                    (now>=s.appearanceCheckAt or s.resourceCheck and s.appearancePowerRevision~=self.appearancePowerRevision)) then
                self:UpdateSlotAppearance(s,slot,cat,now,sample)
            end
            local exhaustingChannel=self.castExhaustingSlot==s and self.castExhaustingKey==s.abilityKey
            local remain,duration,stack,estimated
            if s.hasTrackerPrimary then
                remain,duration,stack,estimated=tracker:Get(s,now)
            end
            local nativeRead=remain==nil
            if remain==nil and not s.flameSlot then
                if exhaustingChannel then remain,duration=math.max(0,(self.castEnd or now)-now),self.castDuration or 0
                else remain,duration=self:ReadNativeTimer(s,slot,cat,now) end
            end
            local whipLeft,whipDuration,whipEstimated,whipKind
            if s.flameSlot then
                whipLeft,whipDuration,whipEstimated,whipKind=tracker:WhipTimer(s,now)
            end
            -- Whip middle:
            --   "charges"  : Power Lash active stacks & remaining 20 s window.
            --   "cooldown" : stacks spent early, remaining 20 s cooldown (red).
            --   "flame"    : cooldown ready -> target Off Balance (green) or
            --                Off Balance immunity (red) from the effect panel.
            -- Never falls back to the native slot timer (45 s passive 262658).
            if whipKind=="flame" and self.effectHUD then
                local bl,bd,mode,be=self.effectHUD:BalanceTimer()
                if mode then whipLeft,whipDuration,whipEstimated,whipKind=bl,bd,be,mode=="active" and "balance" or "immune" end
            end
            if whipKind then remain,duration,estimated=whipLeft,whipDuration,whipEstimated end
            -- Your debuff timers follow the enemy you are looking at.
            if follow and s.followTargetEligible and not whipKind and not exhaustingChannel then
                local fl,fd=tracker:TargetTimer(s,now)
                if fl then remain,duration,estimated,nativeRead=fl,fd,false,false end
            end
            -- A corner timer marked "move to middle" takes over when it ends.
            local track=s.track
            local promote=track and not s.chain and ((track[2] and track[2].promote and 2) or (track[3] and track[3].promote and 3)) or nil
            local promoted
            if promote and not whipKind and remain<=0 then
                local pl,pd=tracker:Get(s,now,promote)
                if pl and pl>0 then remain,duration,estimated,promoted=pl,pd,false,promote end
            end
            -- Tracking window "Test": play the typed rows for a few seconds.
            local testing=studioTest and studioTest.key==s.abilityKey and self:StudioTestTimer(s,now,1)
            if testing then
                remain,duration,estimated=self:StudioTestTimer(s,now,1); promoted=nil
                local tp=studioTest.phases
                local tpi=tp and ((tp[2] and tp[2].promote and 2) or (tp[3] and tp[3].promote and 3)) or nil
                if tpi and remain<=0 then
                    local pl,pd=self:StudioTestTimer(s,now,tpi)
                    if pl and pl>0 then remain,duration,promoted=pl,pd,tpi end
                end
                promote=tpi
            end
            if s.whipTimerKind~=whipKind then s.expiryActive[1]=nil; s.whipTimerKind=whipKind end
            s.isCharge=false
            if s.suppressStack then
                -- Banner aura counts and Knife's slot counters aren't stacks.
                stack=0
            else
                local charge,timerDirty
                if s.deviceParent then
                    charge=stack or 0
                elseif s.chargeId or s.shieldCharges or s.targetStackEffect or s.phaseStack then
                    charge,timerDirty=tracker:GetCharge(s,now,s.chargeId==46331 and cat==active and (not s.replacedStackUntil or now>=s.replacedStackUntil) and (not self.swapTimerUntil or now>=self.swapTimerUntil) and self:ReadNativeStack(s,slot,cat,now) or nil)
                end
                if s.chargeId==46331 and timerDirty and not testing then
                    local cl,cd=tracker:Get(s,now)
                    if cl~=nil then remain,duration,estimated,nativeRead=cl,cd,false,false end
                end
                if charge~=nil then stack=charge; s.isCharge=true
                else
                    local trackedStack
                    if s.stackEffect then trackedStack=tracker:GetStack(s,now) end
                    if trackedStack~=nil then stack=trackedStack
                    else
                        -- A duration effect's stackCount may be zero even while
                        -- the actual slot has stacks; preserve the independent counter.
                        local nativeStack=self:ReadNativeStack(s,slot,cat,now)
                        stack=nativeStack>0 and nativeStack or (stack or 0)
                    end
                end
            end
            if cat==active and s.stackEffect and not s.focusRequired and self.settings.showUnavailable then
                local hasStack=(stack or 0)>0
                if s.appearanceHasStack~=nil and s.appearanceHasStack~=hasStack then
                    self:UpdateSlotAppearance(s,slot,cat,now,sample)
                end
                s.appearanceHasStack=hasStack
            else s.appearanceHasStack=nil end
            local toggled=tracker:ToggleActive(s,slot,cat)
            local nw=s.nwSlot and cfg.showNothingWasted and self:CharacterHasPassive("nw")~=false
            local nwLeft,nwIndex=0,nil
            if nw then
                local nwCount
                nwLeft,nwCount=tracker:GetNothingWasted(s,now)
                stack=nwCount or 0
                s.isCharge=false
                if not (track and track[2]) then nwIndex=2
                elseif not track[3] then nwIndex=3 end
            end
            -- Banner's native slot duration can linger after deactivation.
            -- It is a toggle, not an ordinary timed DoT or expiry proc.
            if s.toggleGroup=="banner" and not toggled then remain,duration,stack=0,0,0 end
            if exhaustingChannel then
                remain=math.max(0,(self.castEnd or now)-now); duration=self.castDuration or 0; estimated=false
            elseif s.exhaustingSuppressedKey then
                if s.exhaustingSuppressedKey~=s.abilityKey or remain<=0 then s.exhaustingSuppressedKey=nil
                else remain,duration=0,0 end
            end
            local t=remain>0 and remain/1000 or 0
            local expired=s.expiryActive[1] and remain<=0 and not toggled
            s.expiryActive[1]=remain>0 and not toggled
            if toggled or s.toggled~=false then self:SetToggle(s,toggled) end
            local showEstimate=estimated and remain>0 or false
            if s.estimatedShown~=showEstimate then labelHidden(s.estimate,not showEstimate); s.estimatedShown=showEstimate end
            s.effectDuration=duration
            local finish=remain>0 and now+remain or nil
            if not finish or not s.effectEnd or math.abs(finish-s.effectEnd)>65 then s.effectEnd=finish end
            -- Native on/off state is independent of duration and usability.
            -- Never paint a permanently active toggle as an all-green timer.
            local procActive=tracker.procEnabled and s.canProc and tracker:ProcActive(s,now) or false
            local hideFill=(not cfg.showFill or remain<=0 or toggled or s.unavailable or procActive or s.suppressFill or s.noDurationFill or s.noExpiryGlow or whipKind=="charges" or whipKind=="balance" or whipKind=="immune" or whipKind=="cooldown") and true or false
            if s.fillHidden~=hideFill then s.fillHidden=hideFill; s.fill:SetHidden(hideFill) end
            mapSet(self.fillSlots,s,not hideFill and duration and duration>0 and true or nil,"fillCount")
            if exhaustingChannel and t>0 then
                setText(s.timer,string.format("%.1f",t))
                s.timerTextMode="fine"; s.timerWholeSec=nil; s.timerVisualGen=hudGen
            elseif t<=0 then
                if s.timerTextMode~="zero" or s.timerVisualGen~=hudGen then
                    setText(s.timer,"")
                    s.timerTextMode="zero"; s.timerWholeSec=nil; s.timerVisualGen=hudGen
                end
            elseif t<=decSec then
                setText(s.timer,string.format("%.1f",t))
                s.timerTextMode="fine"; s.timerWholeSec=nil; s.timerVisualGen=hudGen
            else
                local wholeSec=wholeSeconds(t,duration,nativeRead and not whipKind and s.skillDuration or nil)
                if wholeSec~=s.timerWholeSec or s.timerTextMode~="whole" or s.timerVisualGen~=hudGen then
                    setText(s.timer,tostring(wholeSec))
                    s.timerWholeSec=wholeSec; s.timerTextMode="whole"; s.timerVisualGen=hudGen
                end
            end
            if t>0 or (whipKind and whipKind~="flame") then
                setTint(s.timer,t,whipKind=="balance" and self.settings.offBalanceActiveColor or (whipKind=="immune" or whipKind=="cooldown") and self.settings.offBalanceImmuneColor or nil)
            end
            if stack~=0 or s.stackCacheCount~=0 or s.stackCacheGen~=hudGen or s.stackCacheFontGen~=fontGen then
                setStack(s,stack)
            end
            if s.landslideSlot or s.externalCountEffect or s.landslideLabel or s.auxCount then
                -- Previously allocated badges must still receive an empty
                -- value when settings/skill bindings disable their source.
                self:AuxiliaryCount(s,tracker:AuxCount(s,now))
            end
            local targets=tracker.targetsEnabled and s.targetEffect and not s.groundNoTargetCount and s.toggleGroup~="banner" and whipKind~="charges" and tracker:TargetCount(s,now) or 0
            local targetVal=(targets>1 or (targets==1 and (s.topRightTimer or cfg.showSingleTarget or (s.groupBuffCount and cfg.showSingleGroupBuff)))) and targets or 0
            local targetGroup=s.groupBuffCount==true
            if targetVal~=s.lastTargetCountVal or s.lastTargetCountGen~=hudGen or s.lastTargetCountFontGen~=fontGen or s.lastTargetCountGroup~=targetGroup then
                s.lastTargetCountVal,s.lastTargetCountGen,s.lastTargetCountFontGen,s.lastTargetCountGroup=targetVal,hudGen,fontGen,targetGroup
                self:ShowTargetCount(s,targetVal>0 and tostring(targetVal) or "")
            end
            local showProc=procActive and not s.unavailable and not (s.noStackGlow and stack>0) or false
            if showProc or self.procSlots[s] then self:SetProc(s,showProc) end
            -- Only live timers/stacks trigger the persistent border. Zero time
            -- is handled by the existing one-shot expiry flash.
            -- A phase chain warns for its last phase, not each promotion.
            local loopT=s.chain and seconds(tracker:ChainRemaining(s,now)) or t
            local loop=false
            if cfg.animations and not toggled and not s.unavailable and not s.iconHidden and not s.noExpiryGlow
                and s.toggleGroup~="banner" and whipKind~="balance" and whipKind~="immune" and whipKind~="cooldown"
                and (loopT>0 or stack>0 or whipKind=="charges") then
                loop=self:SkillLoopReady(s,stack,loopT,nw,whipKind,cat,active)
            end
            local nwWarn=nw and cfg.animations and cfg.nwWarning and not s.iconHidden and nwLeft>0 and nwLeft<=cfg.nwWarnSeconds*1000
            local showLoop=loop or nwWarn
            if showLoop or self.loopSlots[s] then self:SetGoldLoop(s,showLoop) end
            for index=2,3 do
                local label=s.extraTimers[index]
                -- A hidden, already cleared corner without a configured or
                -- special source has no timer/expiry work on this tick.
                if testing or index==nwIndex or (track and track[index]) or
                    (index==2 and (s.chain or s.phaseBadge)) or label.vabVisible~=false or s.expiryActive[index] then
                local left,extraDuration,approx
                -- Empty optional channels never resolve an effect. Still
                -- process their visibility/expiry below to clear old UI.
                if index~=promoted and (track and track[index] or (index==2 and s.chain)) then
                    local _
                    left,extraDuration,_,approx=tracker:Get(s,now,index)
                end
                local phase=index==2 and s.phaseBadge and tracker:PhaseBadge(s,now)
                if testing then left,extraDuration=self:StudioTestTimer(s,now,index); approx=false end
                if whipKind=="charges" or index==promoted then left=0 end
                if index==nwIndex then left,extraDuration,approx=nwLeft,nil,false end
                local visible=phase~=nil and phase~=false or (left and left>0 or false)
                if index~=nwIndex and s.expiryActive[index] and not visible then expired=true end
                -- A chain's next phase moving to the centre is not an expiry.
                s.expiryActive[index]=index~=nwIndex and visible and not s.chain and index~=promote
                if label.vabVisible~=visible then labelHidden(label,not visible); label.vabVisible=visible end
                if visible then
                    local extraSec=left and left>0 and left/1000 or 0
                    local value
                    if phase then
                        value=phase
                        label.extraMode="phase"; label.extraWhole=nil
                    elseif extraSec<=decSec then
                        value=(approx and "~" or "")..string.format("%.1f",extraSec)
                        label.extraMode="fine"; label.extraWhole=nil
                    else
                        local w=wholeSeconds(extraSec,extraDuration)
                        local approxFlag=approx and true or false
                        if label.extraMode=="whole" and label.extraWhole==w and label.extraApprox==approxFlag and label.extraGen==hudGen and label.extraFitText then
                            value=label.extraFitText
                        else
                            value=(approxFlag and "~" or "")..tostring(w)
                            label.extraMode="whole"; label.extraWhole=w; label.extraApprox=approxFlag; label.extraGen=hudGen
                        end
                    end
                    setText(label,value)
                    -- Long decimals or unusually high saved values are fitted
                    -- into their own half of the icon, never over the neighbor.
                    local desired=boundedSize(index==2 and cfg.extraLeftSize or cfg.extraRightSize,cfg.extraSize or 16,10,22)
                    if phase then desired=math.min(14,desired) end
                    if label.extraFitText~=value or label.extraFitSize~=desired or label.extraFitGeneration~=fontGen then
                        local font=self.effectiveFont or self:ResolveFont(cfg.fontFace)
                        local room=phase and 42 or s.extraTimerWidths and s.extraTimerWidths[index] or 30
                        self:FitCounterText(label,font,cfg.fontStyle,nil,value,desired,room,room,false,phase and "[1/2]" or nil)
                        label.extraFitText,label.extraFitSize,label.extraFitGeneration=value,desired,fontGen
                    end
                    local col=index==2 and cfg.secondColor or cfg.thirdColor
                    setTint(label,extraSec,col[1],col[2],col[3])
                end
                end
            end
            if s.vampirePassiveSlot or s.arcanistPassiveSlot or s.passiveBadges then
                local left,span,extra,extraSpan,kind=tracker:GetPassiveBadges(s,now)
                self:ShowPassiveBadges(s,left,span,extra,extraSpan,kind)
            end
            -- Transition only: refreshes, empty slots, bar swaps and rule edits
            -- never continuously trigger expiry glow.
            if expired and self.updating and not s.unavailable and s.toggleGroup~="banner" and not s.noExpiryGlow and whipKind~="balance" and whipKind~="immune" and whipKind~="cooldown" and not s.focusRequired and not s.stackReadyAt then flash(s,true) end
            end
        end end
    end
end

function A:UpdateUltimate(now)
    self:ReadResources(now)
    if self.werewolfMode and not self.furyAt and COMBAT_MECHANIC_FLAGS_WEREWOLF then
        self:ObserveFury(GetUnitPower("player",COMBAT_MECHANIC_FLAGS_WEREWOLF),now)
    end
    local ult,cost=self.ultPower,self.mainCost
    local mainState=self.slots[self.activeRow][6]
    local weaponBlocked=self:WrongWeapon(mainState,self.active)
    local ready=cost>0 and ult>=cost and not weaponBlocked
    local m=self.ultimate
    if m.lastUltVal~=ult or m.lastUltGen~=self.hudVisualGen then
        m.lastUltVal,m.lastUltGen=ult,self.hudVisualGen
        setText(m.value,tostring(ult))
    end
    setCost(self.primaryCost,cost,ult,weaponBlocked)
    local remain,estimate,extra,targets,ultSpan,extraSpan,ultSkillSpan=self:UltDuration(self.active,self.activeRow,now)
    local ultActive=remain>0
    local mainToggle=mainState.toggleGroup and self.tracker:ToggleActive(mainState,8,self.active) and mainState.toggleGroup or nil
    -- Overload stays active after a bar swap. Its ring belongs on the large
    -- meter whichever bar holds it; the small meter never shows it.
    local otherState=self.otherCategory and self.slots[3-self.activeRow][6]
    local ringToggle=mainToggle or (otherState and otherState.toggleGroup=="overload"
        and self.tracker:ToggleActive(otherState,8,self.otherCategory) and "overload") or nil
    if self.werewolfMode then
        local fury=self.furyPower or 0
        -- Recover the active Rampage timer on reload if the engine exposes
        -- its real 20-second slot effect. Never use a transformation timer.
        local nativeLeft=GetActionSlotEffectTimeRemaining(8,self.active) or 0
        local nativeSpan=GetActionSlotEffectDuration(8,self.active) or 0
        if nativeLeft>0 and nativeSpan>=19000 and nativeSpan<=21000 then
            self.rampageEnd=now+nativeLeft
        end
        remain=math.max(0,(self.rampageEnd or now)-now)
        ultActive=remain>0; ultSpan=20000; ultSkillSpan=20000; estimate=false; extra=nil; targets=0
        ready=fury>=1000 and not ultActive
        ringToggle=nil
        if m.primaryCostHidden~=true then labelHidden(self.primaryCost,true); m.primaryCostHidden=true end
        local furyInt=math.floor(fury)
        if m.lastFuryVal~=furyInt or m.lastFuryGen~=self.hudVisualGen then
            m.lastFuryVal,m.lastFuryGen=furyInt,self.hudVisualGen
            setText(m.furyValue,tostring(furyInt))
        end
        if m.furyHidden~=false then labelHidden(m.furyValue,false); m.furyHidden=false end
        if not m.werewolfLayout then self:LayoutUltimateNumbers(true) end
        if m.wwControlsShown~=true then
            m.rampageBacking:SetHidden(false); m.furyRing.arc:SetHidden(false); m.rampageInnerRing.arc:SetHidden(false)
            m.arc:SetHidden(true); m.activeRing:SetHidden(true); m.isActiveRing=false
            m.wwControlsShown=true
        end
        if m.lightExtras then m.lightEdge:SetHidden(true); m.lightCore:SetHidden(true); m.lightGlow:SetHidden(true); m.lightExtras=false end
        self:SetTogglePulse(m.activeRing,false,1)
        if ultActive then arc(m.furyRing,remain/20000,.21,1,.30,1)
        elseif ready then arc(m.furyRing,1,1,.20,.12,1)
        else arc(m.furyRing,fury/1000,.96,.42,.18,1) end
        -- The outer arc belongs to Fury/Rampage, the inner arc exclusively
        -- to the actual ultimate resource. Both have identical stroke width
        -- and individual borders; their four-pixel gap never intersects.
        arc(m.rampageInnerRing,ult/(self.ultMax or 500),1,.82,.32,1)
        local rc=ultActive and self.settings.activeUltColor or self.settings.ultimateColor
        meterAura(m,ultActive or ready,rc[1],rc[2],rc[3],.45)
        self:SetTogglePulse(m.aura,false,1)
        ultimateIcon(m,true)
    else
        if m.furyHidden~=true then labelHidden(m.furyValue,true); m.furyHidden=true end
        if m.wwControlsShown~=false then
            m.rampageBacking:SetHidden(true); m.furyRing.arc:SetHidden(true); m.rampageInnerRing.arc:SetHidden(true); m.arc:SetHidden(false)
            m.wwControlsShown=false
        end
        if m.werewolfLayout then self:LayoutUltimateNumbers(false) end
        local hideCost=not self.settings.showUltCost
        if m.primaryCostHidden~=hideCost then labelHidden(self.primaryCost,hideCost); m.primaryCostHidden=hideCost end
        ultimateRing(m,ultActive,cost>0 and ult/cost or 0,ready,ringToggle)
        ultimateIcon(m,ready)
    end
    m.werewolfLayout=self.werewolfMode
    if ready and not self.ultReady and ringToggle~="overload" then flash(self.ultimate) end
    self.ultReady=ready
    if self.otherCategory then
        local c2=self.backCost or 0
        local backRemain,backEstimate,backExtra,backTargets,backSpan,backExtraSpan,backSkillSpan=self:UltDuration(self.otherCategory,3-self.activeRow,now)
        local backActive=backRemain>0
        local backState=self.slots[3-self.activeRow][6]
        local backBlocked=self:WrongWeapon(backState,self.otherCategory)
        local backReady=c2>0 and ult>=c2 and not backBlocked
        setCost(self.secondaryCost,c2,ult,backBlocked)
        local backToggle=self.settings.showBackUlt and backState.toggleGroup and backState.toggleGroup~="overload" and self.tracker:ToggleActive(backState,8,self.otherCategory) and backState.toggleGroup or nil
        ultimateRing(self.secondary,backActive,c2>0 and ult/c2 or 0,backReady,backToggle)
        ultimateIcon(self.secondary,backReady)
        -- If the active effect is on the other bar, carry its countdown above
        -- the large meter; when both are active, retain both durations.
        if ultActive or (extra and extra>0) then self:ShowUltDuration(self.ultimate,remain,estimate,extra,targets,ultSpan,extraSpan,ultSkillSpan)
        else self:ShowUltDuration(self.ultimate,backRemain,backEstimate,backExtra,backTargets,backSpan,backExtraSpan,backSkillSpan) end
        self:ShowUltDuration(self.secondary,ultActive and backRemain or 0,backEstimate,ultActive and backExtra or nil,ultActive and backTargets or nil,backSpan,backExtraSpan,backSkillSpan)
    else setCost(self.secondaryCost,nil,ult); self:ShowUltDuration(self.secondary,0,false); self:ShowUltDuration(self.ultimate,remain,estimate,extra,targets,ultSpan,extraSpan,ultSkillSpan); ultimateRing(self.secondary,false,0,false) end
end
-- Cast bar sampling & clearing live in CastBar.lua (attached via ZeraUIAttachCastBar).
function A:RenderQuickslot(now)
    if not self.settings.showQuickslot then return end
    local qr=self.quickEnd and math.max(0,self.quickEnd-now) or 0
    if qr==0 and self.quickRenderIdle then return end
    if qr>0 and self.quickRenderAt and now<self.quickRenderAt then return end
    self.quickRenderIdle=qr==0
    local qs=seconds(qr)
    local decSec=self.settings.decimalSeconds
    local step=qr<=0 and 0 or qs<=decSec and -math.floor(qr/100+.5)-1 or wholeSeconds(qs)
    if self.quickTimeStep~=step then self.quickTimeStep=step; setText(self.quick.value,timeText(qs)) end
    setTint(self.quick.value,qs)
    local qc=self.settings.quickColor
    local dur=self.quickDuration
    local fraction=qr>0 and dur and dur>0 and 1-qr/dur or 1
    if self.quickEmpty then
        -- Preserve a real cooldown countdown, but never indicate readiness.
        arc(self.quick,qr>0 and fraction or 0,.35,.35,.35,.72)
    else
        arc(self.quick,fraction,qc[1],qc[2],qc[3],qc[4])
    end
    meterAura(self.quick,qr<=0 and not self.quickEmpty,qc[1],qc[2],qc[3],.9)
    if qr>0 then
        local nextWait=qr
        if dur and dur>0 then
            local arcStep=self.quick.lastArc or 0
            if arcStep<255 then
                local nextArcMs=qr-dur*(1-(arcStep+.5)/255)
                if nextArcMs<nextWait then nextWait=nextArcMs end
            end
        end
        local nextTextMs
        if qs<=decSec then
            local decStep=math.floor(qr/100+.5)
            nextTextMs=qr-(decStep-.5)*100
        else
            nextTextMs=qr-(step-1)*1000
            local toDec=qr-decSec*1000
            if toDec<nextTextMs then nextTextMs=toDec end
        end
        if nextTextMs<nextWait then nextWait=nextTextMs end
        if self.settings.warningColors then
            local soonMs=(self.settings.soonSeconds or 0)*1000
            local lastMs=(self.settings.lastSeconds or 0)*1000
            if soonMs>0 and qr>soonMs then
                local toSoon=qr-soonMs
                if toSoon<nextWait then nextWait=toSoon end
            end
            if lastMs>0 and qr>lastMs then
                local toLast=qr-lastMs
                if toLast<nextWait then nextWait=toLast end
            end
        end
        self.quickRenderAt=now+math.max(1,nextWait)
    else
        self.quickRenderAt=nil
    end
end
function A:Render(now)
    self.renderFrame=now
    if self.hudDueAfter and now>self.hudDueAfter then self:RunDeferredHUD() end
    -- One coalesced slot refresh per frame (see SlotRefreshEvent).
    if not self.preview and (self.slotRefreshPending or self.swapPending and now>=self.swapPending.untilTime) then self:RefreshSlots(true) end
    -- Reassert hidden alpha if a native fade animation changed it. While
    -- ACTION_BAR_FRAGMENT hides ZO_ActionBar1, its child buttons need no
    -- per-frame GetAlpha() reads; only watch independent controls (Synergy /
    -- Werewolf), falling back to full nativeAlpha if ZO_ActionBar1 is shown.
    if self.nativeBarHidden or self.nativeAlphaCount>0 then
        local barHidden=self.nativeBarHidden and ZO_ActionBar1 and ZO_ActionBar1.IsControlHidden and ZO_ActionBar1:IsControlHidden()
        local watch=barHidden and self.nativeAlphaWatch or self.nativeAlpha
        if (barHidden and self.nativeWatchCount or self.nativeAlphaCount)>0 then
            for c in pairs(watch) do if c:GetAlpha()~=0 then c:SetAlpha(0) end end
        end
    end
    local cfg=self.settings
    if self.animCount>0 then
        local pressMs,expiryMs,glowStrength,burstStrength=cfg.pressMs,cfg.expiryMs,cfg.glowStrength,cfg.burstStrength
        for s in pairs(self.animated) do renderFlash(s,now,pressMs,expiryMs,glowStrength,burstStrength) end
    end
    local sets=self.setCooldowns
    if sets and (sets.pillCount or 0)>0 then sets:RenderPills(now) end
    if self.iconTransCount>0 then
        for slot,t in pairs(self.iconTransitions) do
            local p=(now-t.at)/135
            if p<0 then p=0 elseif p>1 then p=1 end
            local eased=p*p*(3-2*p)
            slot.desatNow=t.d+(slot.desatTarget-t.d)*eased; slot.alphaNow=t.a+(slot.alphaTarget-t.a)*eased
            slot.icon:SetDesaturation(slot.desatNow); slot.icon:SetAlpha(slot.alphaNow)
            if p>=1 then mapSet(self.iconTransitions,slot,nil,"iconTransCount") end
        end
    end
    local sy=self.synergy
    if sy.transition or (sy.hold and not self.animated[sy]) then self:RenderSynergy(now) end
    if self.procCount>0 then
        local procAlpha
        for slot in pairs(self.procSlots) do
            if not self.loopSlots[slot] then
                -- Every visible proc uses the same phase on this frame.
                if not procAlpha then procAlpha=cfg.procPulse and (.70+.30*math.sin(now/170)) or 1 end
                local alpha=procAlpha
                if slot.procAlpha==nil or math.abs(slot.procAlpha-alpha)>=1/255 or alpha==1 and slot.procAlpha~=1 then
                    slot.proc:SetAlpha(alpha); slot.procAlpha=alpha
                end
            end
        end
    end
    if self.togglePulseCount>0 then
        -- All active toggles share one gentle pulse. Keep a visible edge
        -- between peaks; never create textures or restart flash timelines.
        local tp=cfg.togglePulsePeriod
        local pulse=.65+.35*math.cos(now*TWO_PI/(tp>250 and tp or 250))
        for control,strength in pairs(self.togglePulses) do
            local alpha=strength*pulse
            if not control.vabToggleAlpha or math.abs(control.vabToggleAlpha-alpha)>=1/255 then
                control:SetAlpha(alpha); control.vabToggleAlpha=alpha
            end
        end
    end
    -- At most two existing textures rotate; quantize to 30 Hz to avoid
    -- redundant UI writes at high frame rates. No state/API polling here.
    if self.ultimate.lightningRotating or self.secondary.lightningRotating then
        local rotationStep=math.floor(now/33)
        if self.ultimate.lightningRotating and self.ultimate.lightningStep~=rotationStep then
            local m=self.ultimate
            if m.activeRing.SetTextureRotation then
                local angle=(now%1400)*TWO_PI/1400
                m.activeRing:SetTextureRotation(angle)
                if m.lightExtras then m.lightEdge:SetTextureRotation(angle); m.lightCore:SetTextureRotation(angle); m.lightGlow:SetTextureRotation(angle) end
            end
            m.lightningStep=rotationStep
        end
        if self.secondary.lightningRotating and self.secondary.lightningStep~=rotationStep then
            local m=self.secondary
            if m.activeRing.SetTextureRotation then
                local angle=(now%1400)*TWO_PI/1400
                m.activeRing:SetTextureRotation(angle)
                if m.lightExtras then m.lightEdge:SetTextureRotation(angle); m.lightCore:SetTextureRotation(angle); m.lightGlow:SetTextureRotation(angle) end
            end
            m.lightningStep=rotationStep
        end
    end
    if self.pressCount>0 then
        for slot,start in pairs(self.pressAnims) do renderPress(slot,start,now) end
    end
    if self.loopCount>0 then
        local period=cfg.loopPeriod
        local breathDenom=period>250 and period or 250
        for slot,start in pairs(self.loopSlots) do
            local elapsed=now-start
            if elapsed<0 then elapsed=0 end
            local frame=math.floor((elapsed%period)*32/period)
            if slot.loopFrame~=frame then
                local uv=GOLD_LOOP_UV[frame]
                slot.goldLoop:SetTextureCoords(uv[1],uv[2],uv[3],uv[4])
                slot.loopFrame=frame
                if slot.goldBase then
                    -- Gentle breathing in step with the loop, sampled on each
                    -- of its 32 sprite frames rather than on every game frame.
                    local a=math.floor((.78+.22*math.cos(elapsed*TWO_PI/breathDenom))*40+.5)/40
                    if slot.goldBaseAlpha~=a then slot.goldBase:SetAlpha(a); slot.goldBase2:SetAlpha(a*.8); slot.goldBaseAlpha=a end
                end
            end
        end
    end
    if self.widgetDrag then self:RenderWidgetDrag() end
    if self.editing then self:RenderEdit() end
    if self.preview then return end
    -- No game-state API queries in this rendering loop.
    -- A fill drains at a constant rate, so after each write the next frame
    -- that can move it by a quarter pixel is known: frames before that are
    -- skipped with three comparisons. A refreshed effect or a press-sink
    -- change differs from the stored key and is recomputed at once.
    if self.fillCount>0 then
        for s in pairs(self.fillSlots) do
            local finish,duration=s.effectEnd,s.effectDuration
            if finish and duration and duration>0 and not (s.lastHeight and s.fillEnd==finish and
                s.fillDuration==duration and s.fillInner==s.pressInner and now<s.fillNextAt) then
                local inner=s.pressInner or INNER
                local rem=finish-now
                local f=rem>0 and rem/duration or 0
                if f>1 then f=1 end
                local height=inner*f
                local prevH=s.lastHeight
                if not prevH or (height-prevH)>=.25 or (prevH-height)>=.25 then
                    s.fill:SetHeight(height>.1 and height or .1); s.lastHeight=height
                    s.fillEnd,s.fillDuration,s.fillInner,s.fillNextAt=finish,duration,s.pressInner,now+.25*duration/inner
                end
            end
        end
    end
    if self.castShown or self.castEnd or self.castMode=="indefinite" then self:RenderCast(now) end
    if cfg.showQuickslot and not self.quickRenderIdle and (not self.quickRenderAt or now>=self.quickRenderAt) then self:RenderQuickslot(now) end
end
-- Separate the addon HUD scale and saved offsets from ESO's global UI canvas
-- scale. No SavedVariables migration: existing values are defined at 1x UI.
function A:GlobalUIScale()
    local g=GetUIGlobalScale and GetUIGlobalScale() or 1
    return type(g)=="number" and g>0 and g<math.huge and g==g and g or 1
end
function A:UIUnits(value)
    return value/self:GlobalUIScale()
end
-- One shared visual scale for independently anchored Zera UI windows.
-- A component-specific slider (e.g. Set Cooldowns) multiplies this base.
-- Saved scale values are NEVER rewritten when ESO UI Scale changes.
function A:HUDCanvasScale(multiplier)
    return self.settings.scale*(multiplier or 1)/self:GlobalUIScale()
end
-- Edit HUD's scale is the common base for all Zera-owned widgets. Refresh
-- only on configuration/canvas changes, never on the combat/render tick.
function A:SyncWidgetScales()
    local visual=self:HUDCanvasScale()
    local function setIfChanged(w,scale)
        if w and w:GetScale()~=scale then w:SetScale(scale) end
    end
    setIfChanged(self.root,visual)
    if self.curved then setIfChanged(self.curved.window,visual) end
    if self.setCooldowns then
        setIfChanged(self.setCooldowns.window,self:HUDCanvasScale(self.settings.setCooldownScale))
    end
    if self.effectHUD then
        for _,group in pairs(self.effectHUD.groups) do
            setIfChanged(group.window,visual)
            setIfChanged(group.debuffGroup.window,visual)
        end
        setIfChanged(self.effectHUD.ob.window,visual)
    end
    if self.studio then setIfChanged(self.studio.window,visual) end
end
function A:AnchorHudRoot()
    local s=self.settings
    -- The skill grid is at local X=275, 30 units left of the root's center.
    -- Both its scale and GuiRoot anchor offsets must use the same canvas units.
    self.root:ClearAnchors()
    self.root:SetAnchor(BOTTOM,GuiRoot,BOTTOM,self:UIUnits(s.x+30*s.scale),self:UIUnits(s.y))
end
-- Reapply only visual transforms when ESO finishes changing UI scale or
-- resolution. Keep all user settings and combat state untouched.
function A:SyncCanvasScale()
    local g=self:GlobalUIScale()
    local w=GuiRoot and GuiRoot.GetWidth and GuiRoot:GetWidth()
    local h=GuiRoot and GuiRoot.GetHeight and GuiRoot:GetHeight()
    local gw=type(w)=="number" and math.floor(w+.5) or 0
    local gh=type(h)=="number" and math.floor(h+.5) or 0
    if self.canvasScale==g and self.canvasW==gw and self.canvasH==gh then return end
    local scaleChanged=self.canvasScale~=nil and self.canvasScale~=g
    self.canvasScale,self.canvasW,self.canvasH=g,gw,gh
    if scaleChanged then
        self.fontGeneration=(self.fontGeneration or 0)+1
        self.hudVisualGen=(self.hudVisualGen or 0)+1
        self.counterFontMetrics=nil
        if self.PrepareCounterFontMetrics and self.effectiveFont and self.settings then
            self:PrepareCounterFontMetrics(self.effectiveFont,self.settings.fontStyle)
        end
    end
    self:SyncWidgetScales()
    self:PositionElements()
    if scaleChanged and self.SyncAttributes then self:SyncAttributes(false) end
    if self.PositionCurvedBars then self:PositionCurvedBars()
    elseif self.curved and self.curved.window then self.curved.position() end
    if self.setCooldowns and self.setCooldowns.window then self.setCooldowns:Position() end
    if self.effectHUD then
        for _,group in pairs(self.effectHUD.groups) do
            if group.window then self.effectHUD:Position(group) end
            if group.debuffGroup.window then self.effectHUD:Position(group.debuffGroup) end
        end
        if self.effectHUD.ob.window then self.effectHUD:Position(self.effectHUD.ob) end
    end
    if self.SyncPlayerInteraction then self:SyncPlayerInteraction() end
    if self.editing and self.UpdateEditHandles then self:UpdateEditHandles() end
end
-- Active bar arrow styles. Large/Left/Double never overlap the potion (Q)
-- or, for Double, the ultimate (R): Q moves left / R moves right only by
-- what is missing, so a player who already moved them far enough sees no
-- change. Saved offsets are never written here. The two-row span is used
-- even with one bar, so a swap or werewolf never moves Q or R.
local ARROW_GOLD={231/255,182/255,82/255,1}
local ARROW_STYLES={Classic=true,Large=true,Left=true,Double=true}
-- Class ultimate-generation cooldown text: its own size (0 = secondary timer
-- size). The bottom edge stays where it always was, so it grows upward.
function A:PassiveTimerLayout(s,left,top,width)
    local custom=(s.passiveTimerSize or 0)>0
    local size=custom and s.passiveTimerSize or s.extraSize
    local w=math.max(400,width)
    -- 0 keeps today's 20 px box exactly, whatever the secondary size.
    local h=custom and math.max(20,size+4) or 20
    return left+(width-w)/2+s.passiveX,top-2-h+s.passiveY,w,h,size
end
function A:ArrowLayout(s,left,top,width)
    local style=ARROW_STYLES[s.arrowStyle] and s.arrowStyle or "Classic"
    local out={style=style,quickX=s.quickX,ultX=s.ultX}
    if style=="Classic" or not s.showArrow then return out end
    local w,h=math.floor(s.skillSize*26/64+.5),math.floor(s.skillSize*37/64+.5)
    out.w,out.h=w,h
    local span=2*s.skillSize+s.gapY
    local function overlaps(y,height) return y<top+span and y+height>top end
    local arrowLeft=style=="Large" and left-5-w or left-11-w
    if overlaps(top+(span-80)/2+s.quickY,100*s.quickScale) then
        local limit=arrowLeft-4-(left-95)-80*s.quickScale
        if s.quickX>limit then out.quickX=limit end
    end
    if style=="Double" and overlaps(top+(span-82)/2+s.ultY,111*s.ultScale) then
        local need=w-2 -- right arrow: left+width+11..+11+w, then a 4 px gap
        if s.ultX<need then out.ultX=need end
    end
    return out
end
function A:Build()
    self.root=WM:CreateTopLevelWindow(ADDON .. "HUD")
    -- Extend right for the cost labels without moving the skill grid.
    self.root:SetDimensions(610,245)
    self.root:SetScale(self:HUDCanvasScale())
    self:AnchorHudRoot()
    self.root:SetMouseEnabled(false)
    self.root:SetMovable(false)
    self.root:SetDrawTier(DT_HIGH)
    for r=1,2 do
        self.slots[r]={}
        local row=r
        for i=1,5 do
            self.slots[r][i]=makeSlot(self.root,111+(i-1)*PITCH,36+(r-1)*(SIZE+GAP))
            self:BindSkillTooltip(self.slots[r][i].container,i+2,function() return self.categories and self.categories[row] end)
        end
        self.slots[r][6]={expiryActive={}} -- invisible ultimate tracking state, one per hotbar
    end
    self.skillKeys={}
    for i=1,5 do local l=text(self.root,14,SIZE,20,111+(i-1)*PITCH,164); l:SetText(tostring(i)); self.hotkeys[#self.hotkeys+1]=l; self.skillKeys[i]=l end
    self.passiveTimer=text(self.root,14,400,20,75,14,15)
    color(self.passiveTimer,1,.82,.35)
    self.arrow=texture(self.root,PATH .. "arrow.dds",14,20,94,56,5)
    -- Created once; PositionArrow only moves/shows them on layout or swap.
    self.arrowLarge=texture(self.root,PATH.."arrowlarge.dds",26,37,0,0,5); self.arrowLarge:SetHidden(true)
    self.arrowRight=texture(self.root,PATH.."arrowlarge.dds",26,37,0,0,5); self.arrowRight:SetTextureCoords(1,0,0,1); self.arrowRight:SetHidden(true)
    self.stripLeft=texture(self.root,nil,4,64,0,0,5); self.stripLeft:SetColor(unpack(ARROW_GOLD)); self.stripLeft:SetHidden(true)
    self.stripRight=texture(self.root,nil,4,64,0,0,5); self.stripRight:SetColor(unpack(ARROW_GOLD)); self.stripRight:SetHidden(true)
    self.quick=makeMeter(self.root,16,66,80,"Q")
    self.ultGroup=panel(self.root,150,130,456,65)
    self.ultimate=makeMeter(self.ultGroup,0,0,82,"R",true)
    local furyMeter=self.ultimate
    -- Prevent red skill-icon artwork from leaking into the transparent gap
    -- between the two custom arcs. The backing has an open center.
    furyMeter.rampageBacking=texture(furyMeter.container,PATH.."rampageback.dds",94,94,-6,-6,3)
    furyMeter.rampageBacking:SetHidden(true)
    furyMeter.furyRing={arc=texture(furyMeter.container,PATH.."rampageouter.dds",94,94,-6,-6,4)}
    furyMeter.rampageInnerRing={arc=texture(furyMeter.container,PATH.."rampageinner.dds",94,94,-6,-6,4)}
    furyMeter.furyRing.arc:SetHidden(true)
    furyMeter.rampageInnerRing.arc:SetHidden(true)
    furyMeter.furyValue=text(furyMeter.container,17,82,22,0,15,31)
    furyMeter.furyValue:SetDrawTier(DT_HIGH); color(furyMeter.furyValue,1,.72,.32); furyMeter.furyValue:SetHidden(true)
    -- Keep contrast localized to the number, without dimming the whole icon.
    local value=self.ultimate.value
    value:SetDrawTier(DT_HIGH); value:SetDrawLevel(30)
    self.ultimate.valueBacking=texture(self.ultimate.container,PATH.."ulttextback.dds",40,24,0,0,28)
    self.ultimate.valueBacking:SetDrawTier(DT_HIGH)
    self.ultimate.valueBacking:ClearAnchors()
    self.ultimate.valueBacking:SetAnchor(CENTER,self.ultimate.container,CENTER,0,0)
    self.secondary=makeMeter(self.ultGroup,54,54,42,"",true)
    self:BindSkillTooltip(self.ultimate.container,8,function() return self.active end)
    self:BindSkillTooltip(self.secondary.container,8,function() return self.otherCategory end)
    self.ultimate.duration=text(self.ultimate.container,self.settings.ultDurationSize,82,32,0,-23+self.settings.ultDurationOffset,15)
    self.secondary.duration=text(self.secondary.container,13,46,18,-2,-12+self.settings.ultDurationOffset,15)
    self.ultimate.target=text(self.ultimate.container,14,23,18,6,4,18)
    self.secondary.target=text(self.secondary.container,11,16,15,0,0,18)
    -- The small back-bar ultimate is a foreground inset, not interleaved
    -- with the large meter's icon, frame and value controls.
    local function lift(c)
        if not c then return end
        if c.SetDrawTier then c:SetDrawTier(DT_HIGH) end
        if c.SetDrawLevel then c:SetDrawLevel((c.GetDrawLevel and c:GetDrawLevel() or 0)+40) end
    end
    for _,c in ipairs({self.secondary.base,self.secondary.aura,self.secondary.arc,self.secondary.activeRing,self.secondary.lightGlow,self.secondary.lightEdge,self.secondary.lightCore,
        self.secondary.glow,self.secondary.wave,self.secondary.burst,self.secondary.value,self.secondary.sub,
        self.secondary.key,self.secondary.duration,self.secondary.target}) do lift(c) end
    for _,bank in ipairs(self.secondary.iconBanks) do for _,c in ipairs(bank.slices) do lift(c) end end
    self.ultimate.duration:SetHidden(true); self.secondary.duration:SetHidden(true)
    self.primaryCost=text(self.ultGroup,20,54,24,83,26,15)
    self.primaryCost:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.secondaryCost=text(self.ultGroup,15,48,22,99,64,15)
    self.secondaryCost:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.secondary.value:SetHidden(true); self.secondary.sub:SetHidden(true)
    self.cast=panel(self.root,CAST_WIDTH,CAST_HEIGHT,111,0)
    -- Solid rectangular geometry avoids stretched rounded texture corners.
    texture(self.cast,PATH .. "castbase.dds",CAST_WIDTH,CAST_HEIGHT,0,0,0)
    texture(self.cast,PATH .. "casttrack.dds",CAST_TRACK,CAST_HEIGHT-4,CAST_LEFT,2,1)
    self.castIcon=texture(self.cast,nil,27,27,2,2,3)
    self.castFill=texture(self.cast,PATH .. "goldfill.dds",1,CAST_HEIGHT-4,CAST_LEFT,2,2)
    self.castFillHidden=false
    self.castName=text(self.cast,15,226,CAST_HEIGHT,37,1,15)
    self.castName:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.castTime=text(self.cast,15,49,CAST_HEIGHT,270,1,15)
    self.castTime:SetHorizontalAlignment(TEXT_ALIGN_RIGHT or TEXT_ALIGN_CENTER)
    self.cast:SetHidden(true); self.castShown=false
    local sy={}
    sy.container=panel(self.root,200,88,175,178)
    sy.name=text(sy.container,15,200,20,0,0)
    sy.visual=panel(sy.container,53,53,73,17)
    sy.visual:ClearAnchors(); sy.visual:SetAnchor(CENTER,sy.container,TOPLEFT,100,43.5)
    texture(sy.visual,PATH.."square.dds",53,53,0,0,0)
    sy.icon=texture(sy.visual,nil,45,45,4,4,1)
    sy.frame=texture(sy.visual,PATH .. "frame.dds",53,53,0,0,3)
    glowControls(sy,sy.visual,26.5,26.5,79,false)
    sy.key=text(sy.container,14,200,18,0,69)
    sy.key:SetText(self.settings.synergyKey)
    sy.container:SetAlpha(0)
    sy.container:SetHidden(true)
    self.synergy=sy
end
-- Visual row order: logical rows stay bound to PRIMARY (1) and BACKUP (2) so
-- weapon swaps never rebind slots or reset timers; only container offsets swap.
local function visualRow(self,row)
    if not self.preview and self.settings.activeBarOnTop and self.activeRow==2 and self.categories and self.categories[2] then
        return 3-row
    end
    return row
end
local function singleBarActive(self)
    return not self.preview and self.categories and not self.categories[2] or false
end
-- Keep Q and R anchored to the two-row span so transforming into Werewolf
-- (or any single-bar mode) never shifts Q/R; center the single skill row on
-- the vertical midpoint of Potion (Q) and Ultimate (R), clamped inside the
-- two-row grid footprint so extreme custom Q/R offsets stay safely bounded.
local function singleRowTop(self,s,top)
    if not singleBarActive(self) then return top end
    local span=2*s.skillSize+s.gapY
    local quickCenter=top+(span-80)/2+s.quickY+40*s.quickScale
    local ultCenter=top+(span-82)/2+s.ultY+41*s.ultScale
    local centered=(quickCenter+ultCenter)/2-s.skillSize/2
    local maxTop=top+span-s.skillSize
    if centered<top then return top elseif centered>maxTop then return maxTop end
    return centered
end
function A:PositionSlotRows(left,top)
    local s=self.settings
    if not left then
        local width=5*s.skillSize+4*s.gapX
        left=111+(328-width)/2+s.gridX
        top=36+s.gridY
    end
    local pitchX,pitchY=s.skillSize+s.gapX,s.skillSize+s.gapY
    local single=singleBarActive(self)
    local singleTop=single and singleRowTop(self,s,top) or top
    for row=1,2 do
        local y=single and row==1 and singleTop or top+(visualRow(self,row)-1)*pitchY
        for i=1,5 do
            local c=self.slots[row][i].container
            local x=left+(i-1)*pitchX
            if c.vabRowX~=x or c.vabRowY~=y then
                c.vabRowX,c.vabRowY=x,y
                if c.SetAnchorOffsets then c:SetAnchorOffsets(x,y) else reposition(c,self.root,x,y) end
            end
        end
    end
end
function A:PositionArrow()
    local s=self.settings
    local w=5*s.skillSize+4*s.gapX
    local left=111+(328-w)/2+s.gridX
    local top=36+s.gridY
    local arrowRow=self.preview and 1 or visualRow(self,self.activeRow)
    local rowTop=top+(arrowRow-1)*(s.skillSize+s.gapY)
    reposition(self.arrow,self.root,left-17,rowTop+(s.skillSize-20)/2)
    local off=not s.showArrow or (not self.preview and self.categories and not self.categories[2])
    local layout=self:ArrowLayout(s,left,top,w)
    local style=layout.style
    local strips,both=style=="Left" or style=="Double",style=="Double"
    if layout.w then
        local aw,ah=layout.w,layout.h
        local ay=rowTop+(s.skillSize-ah)/2
        self.arrowLarge:SetDimensions(aw,ah)
        reposition(self.arrowLarge,self.root,style=="Large" and left-5-aw or left-11-aw,ay)
        if strips then self.stripLeft:SetDimensions(4,s.skillSize); reposition(self.stripLeft,self.root,left-8,rowTop) end
        if both then
            self.stripRight:SetDimensions(4,s.skillSize); reposition(self.stripRight,self.root,left+w+4,rowTop)
            self.arrowRight:SetDimensions(aw,ah); reposition(self.arrowRight,self.root,left+w+11,ay)
        end
    end
    self.arrow:SetHidden(off or style~="Classic")
    self.arrowLarge:SetHidden(off or style=="Classic")
    self.stripLeft:SetHidden(off or not strips)
    self.stripRight:SetHidden(off or not both)
    self.arrowRight:SetHidden(off or not both)
end
function A:PositionElements()
    local s=self.settings
    local width=5*s.skillSize+4*s.gapX
    local left=111+(328-width)/2+s.gridX
    local top=36+s.gridY
    local span=2*s.skillSize+s.gapY
    local single=singleBarActive(self)
    self.singleRowLayout=single
    local keyTop=single and (singleRowTop(self,s,top)+s.skillSize) or (top+span)
    self:AnchorHudRoot()
    self:PositionSlotRows(left,top)
    for i,key in ipairs(self.skillKeys) do reposition(key,self.root,left+(i-1)*(s.skillSize+s.gapX),keyTop) end
    self:PositionArrow()
    local clear=self:ArrowLayout(s,left,top,width)
    reposition(self.quick.container,self.root,left-95+clear.quickX,top+(span-80)/2+s.quickY)
    reposition(self.ultGroup,self.root,left+width+17+clear.ultX,top+(span-82)/2+s.ultY)
    reposition(self.cast,self.root,left+width/2-CAST_WIDTH*s.castScale/2+s.castX,top-55+s.castY)
    reposition(self.synergy.container,self.root,left+width/2-100*s.synergyScale+s.synergyX,top+span+12+s.synergyY)
    local px,py,pw,ph=self:PassiveTimerLayout(s,left,top,width)
    self.passiveTimer:SetDimensions(pw,ph)
    reposition(self.passiveTimer,self.root,px,py)
    if self.PositionAttributes then self:PositionAttributes() end
    if self.PositionCustomBars then self:PositionCustomBars() end
end
function A:ApplyLayout()
    local s=self.settings
    local width=5*s.skillSize+4*s.gapX
    local left=111+(328-width)/2+s.gridX
    local top=36+s.gridY
    local span=2*s.skillSize+s.gapY
    local single=singleBarActive(self)
    self.singleRowLayout=single
    local keyTop=single and (singleRowTop(self,s,top)+s.skillSize) or (top+span)
    local resolved=self:ResolveFont(s.fontFace)
    -- Test the selected face on one real HUD label before applying it to
    -- the rest. Missing optional fonts never become a required dependency.
    local firstTimer=self.slots[1][1].timer
    local loaded=self:ApplyNativeFont(firstTimer,resolved,s.timerSize,s.fontStyle)
    if not loaded then
        resolved=self:DefaultFontPath()
        self.fontStatus="Selected: "..tostring(s.fontFace).." | Using Univers 67 (font unavailable). Install the .slug and reselect the font."
    else
        self.fontStatus="Active font: "..tostring(s.fontFace)
        if resolved:lower():sub(-5)==".slug" and not resolved:lower():find("^esoui/") then
            self.fontStatus=self.fontStatus.." | Optional .slug: verify in Preview; ESO may silently substitute a missing face."
        end
    end
    firstTimer.timerTint=nil
    self.effectiveFont=resolved
    self:PrepareCounterFontMetrics(resolved,s.fontStyle)
    -- Landslide is permanently bounded to 1..12. Pick a single safe
    -- font size for both badge widths, rather than resizing on 9 -> 10.
    local corner=s.cornerBadgeSize or 16
    local one=self:CounterFontLimit("9",corner,stackBadgeSize(corner,"9"),36,true)
    local two=self:CounterFontLimit("99",corner,stackBadgeSize(corner,"99"),36,true)
    self.landslideFontLimit=math.min(one,two)
    local stackOne=self:CounterFontLimit("9",s.stackSize,stackCounterSize(s.stackSize,"9"),60,true)
    local stackTwo=self:CounterFontLimit("99",s.stackSize,stackCounterSize(s.stackSize,"99"),60,true)
    self.stackFontLimit=math.min(stackOne,stackTwo)
    local function font(label,size)
        self:ApplyNativeFont(label,resolved,size,s.fontStyle)
        label.timerTint=nil
    end
    self:PositionSlotRows(left,top)
    for row=1,2 do for i=1,5 do
        local slot=self.slots[row][i]
        slot.container:SetScale(s.skillSize/SIZE)
        if slot.timer~=firstTimer then font(slot.timer,s.timerSize) end
        self:ApplyNativeFont(slot.stack,resolved,self.stackFontLimit,s.fontStyle,true)
        self:PrepareRecipientBadge(slot)
        font(slot.estimate,s.extraSize)
        slot.stackReady=nil; paint(slot.stack,s.stackColor); paint(slot.fill,s.fillColor)
        paint(slot.target,s.targetColor); paint(slot.proc,s.procColor)
        paint(slot.toggleGlow,s.togglePulseColor)
        slot.toggleGlow:SetAlpha(s.toggleGlowStrength); slot.toggleGlow.vabToggleAlpha=s.toggleGlowStrength; slot.togglePulseWanted=nil
        paint(slot.glow,s.glowColor); paint(slot.wave,s.glowColor); paint(slot.burst,s.glowColor)
        slot.extraTimerWidths=slot.extraTimerWidths or {}
        slot.extraTimerHeights=slot.extraTimerHeights or {}
        for j=2,3 do
            local extraSize=boundedSize(j==2 and s.extraLeftSize or s.extraRightSize,s.extraSize or 16,10,22)
            local extraW,extraH=30,math.max(20,extraSize+4)
            if slot.extraTimerWidths[j]~=extraW or slot.extraTimerHeights[j]~=extraH then
                slot.extraTimerWidths[j],slot.extraTimerHeights[j]=extraW,extraH
                slot.extraTimers[j]:SetDimensions(extraW,extraH)
            end
            positionExtraTimer(slot,j,(j==2 and slot.recipientCountVisible))
            font(slot.extraTimers[j],extraSize)
            slot.extraTimers[j].extraFitText=nil
        end
        if slot.auxCount then sizeAuxCount(slot,s.cornerBadgeSize or 16); self:ApplyNativeFont(slot.auxCount,resolved,s.cornerBadgeSize or 16,s.fontStyle,true) end
        if slot.landslideLabel then self:ApplyNativeFont(slot.landslideLabel,resolved,self.landslideFontLimit,s.fontStyle,true) end
        if slot.passiveBadges then for _,badge in pairs(slot.passiveBadges) do self:ApplyNativeFont(badge.label,resolved,s.cornerBadgeSize or 16,s.fontStyle,true) end end
    end end
    for i,key in ipairs(self.skillKeys) do
        key:SetWidth(s.skillSize)
        reposition(key,self.root,left+(i-1)*(s.skillSize+s.gapX),keyTop)
        font(key,s.keySize)
    end
    local px,py,pw,ph,passiveSize=self:PassiveTimerLayout(s,left,top,width)
    self.passiveTimer:SetDimensions(pw,ph)
    reposition(self.passiveTimer,self.root,px,py)
    font(self.passiveTimer,passiveSize)
    self:PositionArrow()
    local clear=self:ArrowLayout(s,left,top,width)
    self.quick.container:SetScale(s.quickScale)
    reposition(self.quick.container,self.root,left-95+clear.quickX,top+(span-80)/2+s.quickY)
    self.ultGroup:SetScale(s.ultScale)
    reposition(self.ultGroup,self.root,left+width+17+clear.ultX,top+(span-82)/2+s.ultY)
    self:LayoutUltimateNumbers(not self.preview and self.werewolfMode)
    font(self.ultimate.duration,s.ultDurationSize)
    font(self.secondary.duration,math.max(9,s.ultDurationSize-6))
    font(self.ultimate.target,s.targetSize); font(self.secondary.target,math.max(9,s.targetSize-4))
    paint(self.ultimate.target,s.targetColor); paint(self.secondary.target,s.targetColor)
    self.ultimate.duration:SetDimensions(82,math.max(23,s.ultDurationSize+8))
    reposition(self.ultimate.duration,self.ultimate.container,0,-math.max(18,s.ultDurationSize-1)+s.ultDurationOffset)
    reposition(self.secondary.duration,self.secondary.container,-2,-12+s.ultDurationOffset)
    font(self.primaryCost,s.ultCostSize); font(self.secondaryCost,math.max(10,s.ultCostSize-5))
    self.primaryCost.ready=nil; self.secondaryCost.ready=nil
    labelHidden(self.primaryCost,not s.showUltCost)
    self.secondary.container:SetHidden(not s.showBackUlt or not self.otherCategory)
    labelHidden(self.secondaryCost,not s.showBackUlt or not s.showUltCost or not self.otherCategory)
    font(self.quick.value,s.quickTimerSize)
    local countSize=boundedSize(s.quickCountSize,12,8,24)
    font(self.quick.sub,countSize)
    local countPosition=s.quickCountPosition or "Inside bottom"
    local countHeight=math.max(16,countSize+4)
    local countWidth=44
    local qx,qy=(80-countWidth)/2,80*.73
    -- Bottom and Top sit outside the ring; Bottom moves the key label down.
    local keyY=80+2
    if countPosition=="Top" then qy=-countHeight-1
    elseif countPosition=="Bottom" then qy=80+1; keyY=qy+countHeight
    elseif countPosition=="Left" then qx,qy=-countWidth+9,(80-countHeight)/2
    elseif countPosition=="Top left" then qx,qy=-4,-2
    elseif countPosition=="Top right" then qx,qy=80-countWidth+4,-2 end
    self.quick.sub:SetDimensions(countWidth,countHeight); reposition(self.quick.sub,self.quick.container,qx,qy)
    reposition(self.quick.key,self.quick.container,0,keyY)
    font(self.quick.key,s.keySize); font(self.ultimate.key,s.keySize)
    for _,m in ipairs({self.quick,self.ultimate,self.secondary}) do
        paint(m.glow,s.glowColor); paint(m.wave,s.glowColor); paint(m.burst,s.glowColor)
    end
    self.cast:SetScale(s.castScale)
    reposition(self.cast,self.root,left+width/2-CAST_WIDTH*s.castScale/2+s.castX,top-55+s.castY)
    -- Keep the global font choice, but never embolden the cast foreground.
    -- At small sizes extra white copies crowd the counters and black outline.
    local castStyle=s.fontStyle=="thick-outline" and "outline" or s.fontStyle
    local compactOutline=s.fontStyle=="thick-outline"
    self:ApplyNativeFont(self.castName,resolved,s.castFontSize,castStyle,compactOutline)
    self:ApplyNativeFont(self.castTime,resolved,s.castTimeSize,castStyle,compactOutline)
    color(self.castName,1,1,1,1); color(self.castTime,1,1,1,1)
    paint(self.castFill,s.castColor); self.castTint=nil
    self.synergy.container:SetScale(s.synergyScale)
    paint(self.synergy.glow,s.glowColor); paint(self.synergy.wave,s.glowColor); paint(self.synergy.burst,s.glowColor)
    reposition(self.synergy.container,self.root,left+width/2-100*s.synergyScale+s.synergyX,top+2*s.skillSize+s.gapY+12+s.synergyY)
    font(self.synergy.name,s.synergyTextSize); font(self.synergy.key,s.synergyKeySize)
    labelHidden(self.synergy.name,not s.synergyName); labelHidden(self.synergy.key,not s.synergyShowKey)
    setText(self.synergy.key,s.synergyKey)
    if self.lastSynergy or self.preview then
        self.synergy.container:SetAlpha(s.synergyOpacity); self.synergy.visual:SetScale(1); self.synergy.visualScale=1; self.synergy.transition=nil
    end
end
function A:ReplayVisualPreview()
    if not self.preview then self:Command("preview") end
    flash(self.slots[1][2]); flash(self.slots[2][4],true)
    flash(self.ultimate); self:FlashSynergy()
end
function A:UpdatePreview()
    self.hudVisualGen=(self.hudVisualGen or 0)+1
    self.quickTimeStep=nil; self.quickRenderIdle=nil; self.quickRenderAt=nil; self.castTimeStep=nil; self.castFillWidth=nil
    self:PositionElements()
    for r=1,2 do for i=1,5 do
        local slot=self.slots[r][i]
        local toggleSample=r==2 and i==5
        local sample=toggleSample and 0 or (i==2 and 2.5 or i==3 and .8 or i*3+r)
        self:SetToggle(slot,toggleSample)
        local hideFill=toggleSample or not self.settings.showFill
        slot.container:SetHidden(false); slot.fillHidden=hideFill; slot.fill:SetHidden(hideFill)
        slot.fill:SetHeight(INNER*(.25+i*.12)); paint(slot.fill,self.settings.fillColor)
        self:StyleIcon(slot,r==2 and self.settings.inactiveDesaturation or 0,r==2 and self.settings.inactiveAlpha or 1,true)
        setText(slot.timer,timeText(sample)); setTint(slot.timer,sample)
        slot.isCharge=(r==1 and i==4)
        setStack(slot,slot.isCharge and 2 or (i==2 and (r==1 and 3 or 2) or 0))
        self:AuxiliaryCount(slot,"")
        if slot.passiveBadges then self:ShowPassiveBadges(slot,0,0,0,0,nil) end
        self:ShowTargetCount(slot,self.settings.showTargets and i==1 and "4" or "")
        self:SetProc(slot,self.settings.procHighlight and i==5 and r==1)
        self:SetGoldLoop(slot,self.settings.animations and (r==1 or self.settings.loopInactive) and not toggleSample and
            ((self.settings.expiryLoop and sample>0 and sample<=self.settings.loopSeconds) or
             (self.settings.stackLoop and i==2 and 3>=self.settings.loopStacks)))
        for j=2,3 do
            local label=slot.extraTimers[j]
            labelHidden(label,i~=4); label.vabVisible=i==4
            if i==4 then
                setText(label,j==2 and "5" or "10")
                local c=j==2 and self.settings.secondColor or self.settings.thirdColor
                setTint(label,5,c[1],c[2],c[3])
            end
        end
    end end
    local meter=self.ultimate
    meter.rampageBacking:SetHidden(true); meter.furyRing.arc:SetHidden(true); meter.rampageInnerRing.arc:SetHidden(true); meter.arc:SetHidden(false); labelHidden(meter.furyValue,true)
    if meter.werewolfLayout then
        self:LayoutUltimateNumbers(false)
    end
    setText(self.ultimate.value,"175")
    self.secondary.container:SetHidden(not self.settings.showBackUlt)
    -- The back ultimate's Overload is active: the large meter shows it.
    ultimateRing(self.ultimate,false,175/125,true,"overload")
    ultimateRing(self.secondary,false,175/100,true)
    ultimateIcon(self.ultimate,true); ultimateIcon(self.secondary,true)
    setCost(self.primaryCost,125,175); setCost(self.secondaryCost,100,175)
    setText(self.ultimate.duration,"8"); setTint(self.ultimate.duration,8)
    setText(self.secondary.duration,"")
    setText(self.ultimate.target,""); setText(self.secondary.target,"")
    setText(self.passiveTimer,self.editing and "Transfer 3s" or "")
    labelHidden(self.ultimate.duration,not self.settings.showUltDuration)
    labelHidden(self.secondary.duration,true)
    labelHidden(self.primaryCost,not self.settings.showUltCost)
    labelHidden(self.secondaryCost,not self.settings.showUltCost or not self.settings.showBackUlt)
    local q=self.settings.quickColor
    setText(self.quick.value,"24"); setTint(self.quick.value,24); arc(self.quick,.5,q[1],q[2],q[3],q[4])
    meterAura(self.quick,true,q[1],q[2],q[3],.9)
    local showCast=not not self.settings.showGCD
    self.cast:SetHidden(not showCast); self.castShown=showCast
    self.castFillHidden=false; self.castFill:SetHidden(false); self.castFill:SetWidth(CAST_TRACK*.7)
    paint(self.castFill,self.settings.castColor); self.castTint=nil
    setText(self.castName,"Echoing Vigor"); setText(self.castTime,"0.3")
    self.synergy.container:SetHidden(not self.settings.showSynergy); self.synergy.container:SetAlpha(self.settings.synergyOpacity); self.synergy.visual:SetScale(1); self.synergy.visualScale=1; setText(self.synergy.name,"Conduit")
    local icon=GetSlotTexture(3,GetActiveHotbarCategory())
    if icon and icon~="" then self.synergy.icon:SetTexture(icon); self.castIcon:SetTexture(icon) end
end
function A:ApplySettings()
    self:NormalizeFonts()
    self:NormalizeAttributeLayout()
    self.hudVisualGen=(self.hudVisualGen or 0)+1
    self.quickRenderIdle=nil; self.quickRenderAt=nil; self.quickTimeStep=nil; self.castTimeStep=nil; self.castFillWidth=nil
    if self.tracker then self.tracker.syncDirty=true end
    self.root:SetScale(self:HUDCanvasScale())
    self:AnchorHudRoot()
    self:ApplyLayout()
    if self.editing and self.UpdateEditHandles then self:UpdateEditHandles() end
    for _,label in ipairs(self.hotkeys) do labelHidden(label,not self.settings.showHotkeys) end
    self.quick.container:SetHidden(not self.settings.showQuickslot)
    for slot in pairs(self.animated) do
        if not self.settings.animations or (slot.abilityKey and not self:SkillOption(slot,slot.flashExpiry and "expiryGlow" or "pressFlash")) then clearFlash(slot) end
    end
    if not self.settings.synergyPressFlash or not self.settings.animations then clearFlash(self.synergy); self.synergy.offer=nil; self:WatchSynergy(nil) end
    if not self.settings.enabled then self.preview=false; self.previewWasDisabled=nil end
    if self.preview then self:UpdatePreview() end
    restoreNative()
    self:RefreshSlots(); self:RefreshSynergy(); self:ApplyVisibility()
    if self.setCooldowns then self.setCooldowns:ApplyConfig() end
    if self.effectHUD then self.effectHUD:ApplyConfig() end
    self:SyncWidgetScales()
    self:SyncNativeTimers()
    if not self.gamepadSuspended then self:Tick() end
end
-- Scoped visual refresh for live Edit Mode controls: avoids rebuilding unrelated
-- subsystems (e.g., gear scans or action-slot rebinds) while dragging sliders.
function A:ApplyScopedVisual(scope)
    if scope=="sets" then
        self:NormalizeFonts()
        if self.setCooldowns then self.setCooldowns:ApplyConfig() end
        self:SyncWidgetScales()
        if self.editing and self.RefreshEditReadout then self:RefreshEditReadout(true) end
        return
    elseif scope=="effects" then
        self:NormalizeFonts()
        if self.effectHUD then self.effectHUD:ApplyConfig() end
        self:SyncWidgetScales()
        if self.editing and self.RefreshEditReadout then self:RefreshEditReadout(true) end
        return
    elseif scope=="attributes" then
        self:NormalizeFonts()
        self:NormalizeAttributeLayout()
        if self.SyncAttributes then self:SyncAttributes(false) end
        if self.PositionAttributes then self:PositionAttributes() end
        if self.PositionCustomBars then self:PositionCustomBars() end
        self:SyncWidgetScales()
        if self.editing and self.UpdateEditHandles then self:UpdateEditHandles() end
        if self.editing and self.RefreshEditReadout then self:RefreshEditReadout(true) end
        return
    elseif scope=="hud" then
        self:NormalizeFonts()
        self.hudVisualGen=(self.hudVisualGen or 0)+1
        self.quickRenderIdle=nil; self.quickRenderAt=nil; self.quickTimeStep=nil; self.castTimeStep=nil; self.castFillWidth=nil
        self.root:SetScale(self:HUDCanvasScale())
        self:AnchorHudRoot()
        self:ApplyLayout()
        if self.PositionAttributes then self:PositionAttributes() end
        if self.PositionCustomBars then self:PositionCustomBars() end
        for _,label in ipairs(self.hotkeys) do labelHidden(label,not self.settings.showHotkeys) end
        self.quick.container:SetHidden(not self.settings.showQuickslot)
        if self.preview then self:UpdatePreview() end
        self:SyncWidgetScales()
        if self.editing and self.UpdateEditHandles then self:UpdateEditHandles() end
        if self.editing and self.RefreshEditReadout then self:RefreshEditReadout(true) end
        return
    end
    self:ApplySettings()
end
function A:EnsureSettings()
    if self.settingsRegistered then return end
    local ok,registered,problem=pcall(ZeraUIRegisterSettings,self)
    if not ok or not registered then
        if not self.settingsErrorShown then
            d("Zera UI settings unavailable: "..tostring(ok and problem or registered))
            self.settingsErrorShown=true
        end
    else self.settingsErrorShown=false end
end
-- Refresh cached icon paths after optional external texture redirectors
-- (e.g. AbilityIconsFramework) update redirects or quickslot potion hooks.
-- Never runs in combat or when no external icon framework is installed.
function A:RefreshExternalIcons()
    if not self.root or self.preview or not self.categories then return end
    if self.swapPending then self.externalIconsPending=true; return end
    self.externalIconsPending=nil
    for row=1,2 do
        local cat=self.categories[row]
        if cat then
            for i=1,5 do
                local s=self.slots[row][i]
                s.iconPath=nil
                if cat==self.active then s.wallIcon=nil end
                setIcon(s,i+2,cat)
            end
        end
    end
    for _,m in ipairs({self.ultimate,self.secondary}) do
        if m and m.iconBanks then
            for _,b in ipairs(m.iconBanks) do b.path=nil end
        end
        if m then m.iconPath=nil end
    end
    if self.active then
        local activeTex=setIcon(self.ultimate,8,self.active)
        if self.otherCategory then
            local otherTex=setIcon(self.secondary,8,self.otherCategory)
            setIcon(self.ultimate,8,self.otherCategory,true,nil,otherTex)
            setIcon(self.secondary,8,self.active,true,nil,activeTex)
        end
    end
    if self.quick then self.quick.iconPath=nil; self:RefreshQuickslotBinding() end
end
function A:ResetCombatSession()
    self:ClearCast()
    self:InvalidateNativeTimers()
    self.weaponPairLocked=GetActiveWeaponPairInfo and select(2,GetActiveWeaponPairInfo())==true or false
    self.synergy.offer=nil; self:WatchSynergy(nil); self:HideSynergyImmediate()
    self.tracker:ResetRuntime(); self:ResetExpiryState(); self:ResetCorpseState()
    self.effectHUD:Invalidate()
end
function A:Initialize()
    ZeraUIAttachDefaults(self,{boundedSize=boundedSize})
    ZeraUIAttachFonts(self,{addon=ADDON,text=text})
    ZeraUIAttachSynergy(self,{addon=ADDON,flash=flash,clearFlash=clearFlash,setText=setText,clamp=clamp})
    ZeraUIAttachCastBar(self,{castTrack=CAST_TRACK,setText=setText,paint=paint})
    ZeraUIAttachCommands(self,{flash=flash,clearFlash=clearFlash})
    self:LoadAndMigrateSettings()
    self.tracker=Tracker.New(self.settings.tracking,self.settings.procRules)
    self.tracker.passiveCheck=function(kind) return self:CharacterHasPassive(kind) end
    -- Chained-slot identity and passive ownership read ESO's skills data.
    -- Keep callbacks attached so subclassing/respec updates invalidate caches
    -- after SKILLS_DATA_MANAGER refreshes its own dynamic state.
    local skillsData=SKILLS_DATA_MANAGER
    if skillsData and skillsData.RegisterCallback then
        local ready=not skillsData.IsDataReady or skillsData:IsDataReady()
        skillsData:RegisterCallback("FullSystemUpdated",function()
            if not ready then
                ready=true
                self:SkillsChanged()
            else
                self:FullSkillsChanged()
            end
        end)
        skillsData:RegisterCallback("SkillLineAdded",function() self:SkillsChanged() end)
    end
    self.finder=ZeraUIFinder.New()
    self:Build(); self:RefreshSlots()
    self.setCooldowns=ZeraUISetCooldowns.New(self,{panel=panel,texture=texture,text=text,path=PATH,
        setText=setText,color=color,hidden=labelHidden})
    self.effectHUD=ZeraUIEffectHUD.New(self,{panel=panel,texture=texture,text=text,path=PATH,setText=setText,color=color})
    ZeraUIAttachEditor(self,{panel=panel,texture=texture,text=text,reposition=reposition,path=PATH})
    ZeraUIAttachEditInspector(self,{path=PATH})
    ZeraUIAttachStudio(self)
    local attrUI={panel=panel,text=text,texture=texture,path=PATH,reposition=reposition,setText=setText,color=color,hidden=labelHidden}
    ZeraUIAttachAttributeCore(self,attrUI)
    ZeraUIAttachAttributes(self,attrUI)
    ZeraUIAttachCurvedBars(self,{panel=panel,text=text,path=PATH,setText=setText,color=color})
    ZeraUIAttachCustomBars(self,attrUI)
    ZeraUIAttachPlayerInteraction(self,{text=text,texture=texture,path=PATH})
    -- Optional AbilityIconsFramework bridge: when AIF is absent, this single
    -- startup type check is the only code that ever executes (zero overhead).
    if type(AbilityIconsFramework)=="table" and type(AbilityIconsFramework.UpdateAllSlots)=="function" and type(SecurePostHook)=="function" then
        pcall(SecurePostHook,AbilityIconsFramework,"UpdateAllSlots",function() self:RefreshExternalIcons() end)
    end
    local function register(ev,fn) if ev then EM:RegisterForEvent(ADDON,ev,fn) end end
    -- Resync HUD canvas scale on settled screen-resize events. No per-frame scale reads.
    register(EVENT_ALL_GUI_SCREENS_RESIZED,function() self:SyncCanvasScale() end)
    register(EVENT_INTERFACE_SETTING_CHANGED,function(_,settingType,settingId)
        if settingType==SETTING_TYPE_UI and settingId==UI_SETTING_SHOW_ACTION_BAR_TIMERS then
            self:SyncNativeTimers()
        end
    end)
    if EVENT_INTERFACE_SETTING_CHANGED and REGISTER_FILTER_SETTING_SYSTEM_TYPE and SETTING_TYPE_UI then
        EM:AddFilterForEvent(ADDON,EVENT_INTERFACE_SETTING_CHANGED,REGISTER_FILTER_SETTING_SYSTEM_TYPE,SETTING_TYPE_UI)
    end
    register(EVENT_PLAYER_ACTIVATED,function()
        self:SyncCanvasScale(); self.armoryRestore=nil; self.gearRefreshPending=nil; self.gearRefreshGen=(self.gearRefreshGen or 0)+1; self.characterRefreshAfterCombat=nil; self:ForgetPassives()
        if self.editing then self:FinishEdit(false) end; self:CloseTrackMenu(); self.setCooldowns:ResetPA(false); self.weaponLoadouts=nil
        self:ResetCombatSession()
        self:EnsureSettings(); self.finder:Stop("Zone changed")
        self.powerAt=nil; self.furyAt=nil; self.quickDirty=true; self.quickCooldownDirty=true; self.swapPending=nil; self.swapTimerUntil=nil
        self:RefreshSlots(); self:SyncWerewolfMode(); self.tracker:ScanUnit("player"); self.tracker:ScanUnit("reticleover"); self:RefreshSynergy(); self:ApplyVisibility(); self.setCooldowns:Refresh(true)
    end)
    register(EVENT_PLAYER_COMBAT_STATE,function(_,inCombat) if inCombat then self.setCooldowns:ResetProcCounts(); if self.editing then self:FinishEdit(false) end else self:FlushCharacterRefresh() end; self.setCooldowns:Sync(self.setCooldowns.hudShown); self.effectHUD:Sync(self.effectHUD.hudShown) end)
    register(EVENT_ACTION_SLOT_ABILITY_USED,function(_,slot) self:OnCast(slot) end)
    if EVENT_ACTION_UPDATE_COOLDOWNS then
        self.cooldownEvents=true
        register(EVENT_ACTION_UPDATE_COOLDOWNS,function()
            self.quickCooldownDirty=true
            if self.updating and (self.lastCastSlot or self.pendingCast) then
                self:OnCastCooldownsUpdated(GetFrameTimeMilliseconds())
            end
        end)
    end
    if EVENT_COMBAT_EVENT and ACTION_RESULT_BEGIN and REGISTER_FILTER_COMBAT_RESULT and REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
        local ns=ADDON.."CastBegin"
        EM:RegisterForEvent(ns,EVENT_COMBAT_EVENT,function(_,_,_,_,_,_,_,sourceType,_,targetType,hitValue,_,_,_,sourceUnitId,targetUnitId,abilityId)
            self:OnCastBegin(abilityId,hitValue,sourceType,targetType,sourceUnitId,targetUnitId)
        end)
        EM:AddFilterForEvent(ns,EVENT_COMBAT_EVENT,REGISTER_FILTER_COMBAT_RESULT,ACTION_RESULT_BEGIN)
        EM:AddFilterForEvent(ns,EVENT_COMBAT_EVENT,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
        if REGISTER_FILTER_IS_ERROR then EM:AddFilterForEvent(ns,EVENT_COMBAT_EVENT,REGISTER_FILTER_IS_ERROR,false) end
    end
    if EVENT_COMBAT_EVENT and ACTION_RESULT_INTERRUPT and REGISTER_FILTER_COMBAT_RESULT and REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
        local ns=ADDON.."CastInterrupt"
        EM:RegisterForEvent(ns,EVENT_COMBAT_EVENT,function(_,result,isError,_,_,_,_,_,_,targetType)
            if not isError and result==ACTION_RESULT_INTERRUPT and targetType==COMBAT_UNIT_TYPE_PLAYER and self.castMode and self.castMode~="gcd" then self:CancelCastKeepGcd() end
        end)
        EM:AddFilterForEvent(ns,EVENT_COMBAT_EVENT,REGISTER_FILTER_COMBAT_RESULT,ACTION_RESULT_INTERRUPT)
        EM:AddFilterForEvent(ns,EVENT_COMBAT_EVENT,REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
        if REGISTER_FILTER_IS_ERROR then EM:AddFilterForEvent(ns,EVENT_COMBAT_EVENT,REGISTER_FILTER_IS_ERROR,false) end
    end
    if EVENT_PLAYER_STUNNED_STATE_CHANGED then
        register(EVENT_PLAYER_STUNNED_STATE_CHANGED,function(_,stunned)
            if stunned and self.castMode and self.castMode~="gcd" then self:CancelCastKeepGcd() end
        end)
    end
    if EVENT_WEAPON_PAIR_LOCK_CHANGED then
        self.weaponPairLocked=GetActiveWeaponPairInfo and select(2,GetActiveWeaponPairInfo())==true or false
        register(EVENT_WEAPON_PAIR_LOCK_CHANGED,function(_,locked) self:OnWeaponPairLockChanged(locked) end)
    end
    if type(SecurePostHook)=="function" and type(ZO_ActionBar_OnActionButtonDown)=="function" then
        -- Never replace or intercept a protected combat input function.
        pcall(SecurePostHook,"ZO_ActionBar_OnActionButtonDown",function(slot) self:PressedSlot(slot) end)
    end
    register(EVENT_HOTBAR_SLOT_UPDATED,function(_,slot,category)
        if HOTBAR_CATEGORY_QUICKSLOT_WHEEL and category==HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
            self.quickDirty=true; self.quickCooldownDirty=true; self:RefreshQuickslotBinding(); return
        end
        if slot and slot>=3 and slot<=8 then self:SlotRefreshEvent(true,slot,category) end
    end)
    -- Preserve the legacy active-slot signal (including runtime morphs).
    -- Duplicate reports share the same per-category dirty slot.
    register(EVENT_ACTION_SLOT_UPDATED,function(_,slot)
        if not slot or (slot>=3 and slot<=8) then self:SlotRefreshEvent(true,slot,GetActiveHotbarCategory()) end
    end)
    register(EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED,function(_,didChange,assignments,category)
        self:ActiveHotbarRefreshEvent(didChange,assignments,category)
    end)
    register(EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED,function() self:SlotRefreshEvent(false) end)
    -- Keep allocation, rank, modifier and runtime list notifications separate.
    local function skillsChanged() self:SkillsChanged() end
    register(EVENT_SKILL_LINE_ADDED,skillsChanged)
    register(EVENT_SKILLS_FULL_UPDATE,function() self:FullSkillsChanged() end)
    register(EVENT_ABILITY_LIST_CHANGED,function() self:AbilityListChanged() end)
    register(EVENT_ABILITY_PROGRESSION_RANK_UPDATE,function(_,progression) self:SkillRankChanged(progression) end)
    register(EVENT_CRAFTED_ABILITY_RESET,function() self:SkillRankChanged() end)
    register(EVENT_SKILL_RESPEC_RESULT,function(_,result) self:SkillRespecResult(result) end)
    register(EVENT_ABILITY_PROGRESSION_RESULT,function(_,result)
        if not ABILITY_PROGRESSION_RESULT_SUCCESS or result==ABILITY_PROGRESSION_RESULT_SUCCESS then self:SkillsChanged() end
    end)
    -- Buying or refunding a passive spends or returns skill points.
    register(EVENT_SKILL_POINTS_CHANGED,skillsChanged)
    register(EVENT_CHAMPION_PURCHASE_RESULT,function() self:SkillModifiersChanged() end)
    local function refreshGroup() self.tracker:RefreshGroupNames(); self.setCooldowns:RefreshPARoster(false) end
    register(EVENT_GROUP_MEMBER_JOINED,refreshGroup)
    register(EVENT_GROUP_MEMBER_LEFT,refreshGroup)
    register(EVENT_GROUP_UPDATE,refreshGroup)
    register(EVENT_RETICLE_TARGET_CHANGED,function()
        -- Reticle changes invalidate last-known target state on both bars;
        -- the existing 100 ms tick rechecks the active row safely.
        self:ResetReticleSkillState()
        self.tracker:ReticleChanged()
        self.effectHUD:ReticleChanged()
        -- Nothing is drawn from the new target's effects before the next
        -- 100 ms tick, so the tick reads its list once into the shared
        -- snapshot. A burst of changes (sweeping over a pack) costs one read.
        -- Without a running tick, read now as before.
        if self.updating then self.reticleScanPending=true
        else
            self.tracker:ScanUnit("reticleover")
            self.setCooldowns:ReticleChanged()
        end
    end)
    register(EVENT_ACTIVE_WEAPON_PAIR_CHANGED,function(_,_,locked)
        self.weaponPairLocked=locked==true
        local outgoing=self.castMode and self.castMode~="gcd" and self.lastCastCategory or nil
        if outgoing~=nil then self:ClearCast(true) end
        self:SlotRefreshEvent(false)
        if self.ClearStalePending then
            local activeCat=GetActiveHotbarCategory and GetActiveHotbarCategory() or self.active
            self:ClearStalePending(activeCat,outgoing)
        end
        if self.setCooldowns and self.setCooldowns.OnWeaponSwap then self.setCooldowns:OnWeaponSwap() end
    end)
    register(EVENT_HOTBAR_SLOT_STATE_UPDATED,function(_,slot,category)
        if category~=GetActiveHotbarCategory() then return end
        if self.active~=category then self:RefreshSlots(true) end
        -- A slot-state event cannot bypass the category stabilization guard.
        if slot>=3 and slot<=7 and not self.preview and self.updating then
            self:UpdateSlotAppearance(self.slots[self.activeRow][slot-2],slot,category)
        end
    end)
    register(EVENT_ACTION_SLOT_EFFECT_UPDATE,function(_,category,slot)
        -- Preserve the last per-bar countdown during the swap transition;
        -- an early effect event may still describe the outgoing bar.
        local now=GetFrameTimeMilliseconds()
        if self.swapTimerUntil and now<self.swapTimerUntil then return end
        for row=1,2 do
            if self.categories[row]==category and slot>=3 and slot<=8 then
                local s=slot==8 and self.slots[row][6] or self.slots[row][slot-2]
                if s then
                    if s.nativeTimer then s.nativeTimer.valid=false end
                    if slot<=7 and s.flameSlot then self.tracker:ObservePowerLashSlot(slot,category,now,category==self.active) end
                end
            end
        end
    end)
    if EVENT_ACTION_SLOT_EFFECTS_CLEARED then
        register(EVENT_ACTION_SLOT_EFFECTS_CLEARED,function() self:InvalidateNativeTimers() end)
    end
    if EVENT_POWER_UPDATE and REGISTER_FILTER_UNIT_TAG then
        self.powerEvents=true
        register(EVENT_POWER_UPDATE,function(_,tag,_,powerType,value,maxValue,effectiveMax)
            if tag~="player" then return end
            self.setCooldowns:OnPower(powerType,value,maxValue,effectiveMax)
            local now=GetFrameTimeMilliseconds()
            if powerType==COMBAT_MECHANIC_FLAGS_ULTIMATE then
                self.ultPower=value; self.ultMax=maxValue and maxValue>0 and maxValue or self.ultMax or 500; self.powerAt=now
            elseif powerType==COMBAT_MECHANIC_FLAGS_WEREWOLF then
                self:ObserveFury(value,now)
            elseif powerType==COMBAT_MECHANIC_FLAGS_MAGICKA or powerType==COMBAT_MECHANIC_FLAGS_STAMINA or powerType==COMBAT_MECHANIC_FLAGS_HEALTH then
                self:RememberPower(powerType,value,now)
                self:UpdateAttributePower(powerType,value,maxValue,effectiveMax)
            elseif powerType==COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA then
                self:UpdateAttributePower(powerType,value,maxValue,effectiveMax)
            end
        end)
        EM:AddFilterForEvent(ADDON,EVENT_POWER_UPDATE,REGISTER_FILTER_UNIT_TAG,"player")
    end
    if EVENT_ULTIMATE_ABILITY_COST_CHANGED then
        self.costEvents=true
        register(EVENT_ULTIMATE_ABILITY_COST_CHANGED,function() self.costDirty=true end)
    end
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE and REGISTER_FILTER_BAG_ID and BAG_BACKPACK then
        self.inventoryEvents=true
        register(EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function() self.quickDirty=true end)
        EM:AddFilterForEvent(ADDON,EVENT_INVENTORY_SINGLE_SLOT_UPDATE,REGISTER_FILTER_BAG_ID,BAG_BACKPACK)
    end
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE and REGISTER_FILTER_BAG_ID and BAG_WORN then
        self.wornGearEvents=true
        local ns=ADDON.."WornGear"
        -- Only the 14 gear slots that affect equipped sets/weapons (skip poison & costume slots).
        local wornGearSlots={
            [EQUIP_SLOT_HEAD]=true,[EQUIP_SLOT_NECK]=true,[EQUIP_SLOT_CHEST]=true,[EQUIP_SLOT_SHOULDERS]=true,
            [EQUIP_SLOT_MAIN_HAND]=true,[EQUIP_SLOT_OFF_HAND]=true,[EQUIP_SLOT_WAIST]=true,[EQUIP_SLOT_LEGS]=true,
            [EQUIP_SLOT_FEET]=true,[EQUIP_SLOT_RING1]=true,[EQUIP_SLOT_RING2]=true,[EQUIP_SLOT_HAND]=true,
            [EQUIP_SLOT_BACKUP_MAIN]=true,[EQUIP_SLOT_BACKUP_OFF]=true,
        }
        EM:RegisterForEvent(ns,EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(_,_,slot,_,_,reason)
            if slot and not wornGearSlots[slot] then return end
            if not reason or not INVENTORY_UPDATE_REASON_DEFAULT or reason==INVENTORY_UPDATE_REASON_DEFAULT then
                self:EquipmentChanged(false)
            end
        end)
        EM:AddFilterForEvent(ns,EVENT_INVENTORY_SINGLE_SLOT_UPDATE,REGISTER_FILTER_BAG_ID,BAG_WORN)
        if REGISTER_FILTER_INVENTORY_UPDATE_REASON and INVENTORY_UPDATE_REASON_DEFAULT then
            EM:AddFilterForEvent(ns,EVENT_INVENTORY_SINGLE_SLOT_UPDATE,REGISTER_FILTER_INVENTORY_UPDATE_REASON,INVENTORY_UPDATE_REASON_DEFAULT)
        end
    end
    register(EVENT_INVENTORY_FULL_UPDATE,function() self:EquipmentChanged(true) end)
    register(EVENT_ACTIVE_QUICKSLOT_CHANGED,function() self.quickDirty=true; self.quickCooldownDirty=true; self:RefreshQuickslotBinding() end)
    register(EVENT_PERSONALITY_CHANGED,function() self.quickDirty=true; self:RefreshQuickslotBinding() end)
    if ZO_COLLECTIBLE_DATA_MANAGER and ZO_COLLECTIBLE_DATA_MANAGER.RegisterCallback then
        ZO_COLLECTIBLE_DATA_MANAGER:RegisterCallback("OnCollectionUpdated",function()
            self.quickDirty=true; self:RefreshQuickslotBinding()
        end)
    end
    register(EVENT_SYNERGY_ABILITY_CHANGED,function() self:RefreshSynergy() end)
    register(EVENT_UNIT_DEATH_STATE_CHANGED,function(_,tag,dead)
        if tag~="player" then return end
        self:ResetCombatSession()
        if self.setCooldowns and self.setCooldowns.OnDeathStateChanged then self.setCooldowns:OnDeathStateChanged(dead) else self.setCooldowns:ResetPA(not dead) end
        if not dead then self.tracker:RefreshGroupNames(); self.tracker:ScanUnit("player"); self.tracker:ScanUnit("reticleover"); self:RefreshSynergy() end
    end)
    if EVENT_UNIT_DEATH_STATE_CHANGED and REGISTER_FILTER_UNIT_TAG then EM:AddFilterForEvent(ADDON,EVENT_UNIT_DEATH_STATE_CHANGED,REGISTER_FILTER_UNIT_TAG,"player") end
    register(EVENT_ARMORY_BUILD_OPERATION_STARTED,function(_,operation,index) self:ArmoryStarted(operation,index) end)
    register(EVENT_ARMORY_BUILD_RESTORE_RESPONSE,function(_,result,index) self:ArmoryResponse(result,index) end)
    register(EVENT_WEREWOLF_STATE_CHANGED,function() self:WerewolfStateChanged() end)
    register(EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,function() self:GamepadModeChanged() end)
    register(EVENT_GAME_CAMERA_UI_MODE_CHANGED,function() self:SyncWidgetDrag(); self:SyncSkillTooltips() end)
    for _,sceneName in ipairs({"hud","hudui"}) do
        local scene=SCENE_MANAGER:GetScene(sceneName)
        if scene then scene:RegisterCallback("StateChange",function() self:ApplyVisibility(true) end) end
    end
    local lootScene=SCENE_MANAGER:GetScene("loot")
    if lootScene then lootScene:RegisterCallback("StateChange",function() self:ApplyVisibility(true) end) end
    SLASH_COMMANDS["/zera"]=function(input) self:Command(input) end
    SLASH_COMMANDS["/zeraui"]=SLASH_COMMANDS["/zera"]
    ZeraUI_OpenSettings=function()
        if self.settingsPanel and LibAddonMenu2 and LibAddonMenu2.OpenToPanel then LibAddonMenu2:OpenToPanel(self.settingsPanel)
        else self:OpenTrackMenu() end
    end
    self:EnsureSettings()
    self:ApplySettings()
end
EM:RegisterForEvent(ADDON,EVENT_ADD_ON_LOADED,function(_,name)
    if name~=ADDON then return end
    EM:UnregisterForEvent(ADDON,EVENT_ADD_ON_LOADED)
    A:Initialize()
end)
