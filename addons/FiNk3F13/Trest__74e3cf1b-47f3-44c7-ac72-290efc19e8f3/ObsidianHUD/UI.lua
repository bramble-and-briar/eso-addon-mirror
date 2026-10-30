local O=ObsidianHUD
local WHITE="ObsidianHUD/art/obsidian_solid.dds"
local FALLBACK="esoui/art/miscellaneous/progressbar_genericfill.dds"
local ART="ObsidianHUD/art/"
local surfaces={}
local function create(parent,kind) return WINDOW_MANAGER:CreateControl(nil,parent,kind) end

local function assetReady(asset,width,height)
    if not asset or not asset:IsTextureLoaded() then return false end
    local w,h=asset:GetTextureFileDimensions()
    return w==width and h==height
end

function O.FantasyReady()
    return assetReady(ObsidianHUDAssetsFantasyFrame,1024,128) and
        assetReady(ObsidianHUDAssetsFantasyFill,1024,128) and
        (not O.vars.roundBadge or (assetReady(ObsidianHUDAssetsCurveFrame,1024,128) and assetReady(ObsidianHUDAssetsCurveFill,1024,128))) and
        assetReady(ObsidianHUDAssetsFantasyRound,128,128)
end

local function artwork(parent,file,layer)
    local c=create(parent,CT_TEXTURE)
    c:SetTexture(ART..file)
    c:SetColor(1,1,1,1)
    c:SetDrawLayer(layer or DL_OVERLAY)
    c:SetMouseEnabled(false)
    return c
end

function O.SurfaceTexture()
    local asset=ObsidianHUDAssetsSolid
    if asset and asset:IsTextureLoaded() then
        local w,h=asset:GetTextureFileDimensions()
        if w==64 and h==64 then return WHITE,true end
    end
    local fallback=ObsidianHUDAssetsFallback
    return FALLBACK,fallback and fallback:IsTextureLoaded() or false
end

local function surface(control)
    control.obsidianSurface=true
    local texture=O.SurfaceTexture()
    control:SetTexture(texture)
    surfaces[#surfaces+1]=control
end

function O.UpdateMaterials()
    local texture,ready=O.SurfaceTexture()
    if O.currentSurface~=texture then
        for _,control in ipairs(surfaces) do
            if control.obsidianSurface then control:SetTexture(texture) end
        end
        O.currentSurface=texture
    end
    O.materialReady=ready and O.FantasyReady()
end

function O.Rect(parent,r,g,b,a)
    local c=create(parent,CT_TEXTURE)
    surface(c)
    c:SetColor(r,g,b,a or 1)
    c:SetDrawLayer(DL_BACKGROUND)
    c:SetMouseEnabled(false)
    return c
end

function O.Label(parent,size)
    local c=create(parent,CT_LABEL)
    c:SetFont("$(BOLD_FONT)|"..size.."|soft-shadow-thick")
    c:SetColor(1,1,1,1)
    c:SetDrawLayer(DL_TEXT)
    c:SetMouseEnabled(false)
    return c
end

function O.Frame(parent)
    local c=create(parent,CT_CONTROL)
    c:SetMouseEnabled(false)
    local bg=O.Rect(c,0.015,0.018,0.027,0.97)
    bg:SetAnchorFill(c)
    c.background=bg
    c.edges={}
    for _,edge in ipairs({{TOPLEFT,TOPRIGHT},{BOTTOMLEFT,BOTTOMRIGHT},{TOPLEFT,BOTTOMLEFT},{TOPRIGHT,BOTTOMRIGHT}}) do
        local line=O.Rect(c,0.26,0.29,0.35,1)
        line:SetDrawLayer(DL_OVERLAY)
        line:SetDrawLevel(2)
        line:SetAnchor(edge[1],c,edge[1])
        line:SetAnchor(edge[2],c,edge[2])
        if #c.edges<2 then line:SetHeight(1) else line:SetWidth(1) end
        c.edges[#c.edges+1]=line
    end
    return c
end

local function resource(parent,spec)
    local frame=create(parent,CT_CONTROL)
    frame:SetMouseEnabled(false)
    local track=artwork(frame,"fantasy_fill.dds",DL_BACKGROUND)
    track:SetAnchorFill(frame)
    track:SetColor(0.12,0.10,0.13,1)
    local fill=create(frame,CT_TEXTURE)
    fill:SetAnchor(TOPLEFT,frame,TOPLEFT,0,0)
    fill:SetTexture(ART.."fantasy_fill.dds")
    fill:SetDrawLayer(DL_CONTROLS)
    fill:SetDrawLevel(1)
    fill:SetColor(1,1,1,1)
    local border=artwork(frame,"fantasy_frame.dds")
    border:SetAnchorFill(frame)
    border:SetDrawLevel(3)
    local name=O.Label(frame,13)
    name:SetAnchor(LEFT,frame,LEFT,31,-1)
    name:SetText(spec.name)
    local value=O.Label(frame,15)
    value:SetAnchor(RIGHT,frame,RIGHT,-27,-1)
    local bar={frame=frame,fill=fill,name=name,value=value,border=border,track=track}
    bar.curve={}
    for _,part in ipairs({"capTrack","bodyTrack","capFill","bodyFill","capBorder","bodyBorder"}) do
        local isBorder=part:find("Border")
        local control=artwork(frame,isBorder and "fantasy_curve_frame.dds" or "fantasy_curve_fill.dds",
            isBorder and DL_OVERLAY or (part:find("Track") and DL_BACKGROUND or DL_CONTROLS))
        control:SetDrawLevel(isBorder and 3 or 1)
        control:SetHidden(true)
        bar.curve[part]=control
    end
    return bar
end

local CURVE_U=96/512
local CURVE_WIDTH=394*CURVE_U
function O.ResourceFillExtent(bar,ratio)
    local width=bar.curveWidth
    if ratio<=0 then return 0 end
    if ratio>=1 then return width end
    -- Actual visible interior at the DDS midline, excluding transparent
    -- padding and the bevel. Texture-space 100% is not visible-fill 100%.
    local left,right=width*25/1024,width*985/1024
    if bar.curved then
        local cap=math.min(CURVE_WIDTH,width)
        left=cap*(93/1024)/CURVE_U
        right=cap+(width-cap)*(985/1024-CURVE_U)/(1-CURVE_U)
    end
    return math.max(0,math.min(left+(right-left)*ratio,right-2))
end
function O.UpdateCurvedFill(bar,ratio)
    if not bar.curved then return end
    local width=bar.curveWidth
    local cap=math.min(CURVE_WIDTH,width)
    local filled=O.ResourceFillExtent(bar,ratio)
    local capFilled=math.min(cap,filled)
    local bodyFilled=math.max(0,filled-cap)
    bar.curve.capFill:SetWidth(capFilled)
    bar.curve.capFill:SetTextureCoords(0,CURVE_U*capFilled/cap,0,1)
    bar.curve.capFill:SetHidden(capFilled<=0)
    bar.curve.bodyFill:SetWidth(bodyFilled)
    bar.curve.bodyFill:SetTextureCoords(CURVE_U,CURVE_U+(1-CURVE_U)*bodyFilled/(width-cap),0,1)
    bar.curve.bodyFill:SetHidden(bodyFilled<=0)
    if filled>0 then
        local c=O.vars[bar.resourceKey]
        local seam=0.45+0.55*capFilled/filled
        bar.curve.capFill:SetGradientColors(ORIENTATION_HORIZONTAL,
            c[1]*0.45,c[2]*0.45,c[3]*0.45,1,c[1]*seam,c[2]*seam,c[3]*seam,1)
        bar.curve.bodyFill:SetGradientColors(ORIENTATION_HORIZONTAL,
            c[1]*seam,c[2]*seam,c[3]*seam,1,c[1],c[2],c[3],1)
    end
end
function O.UpdateResourceFill(bar,ratio)
    local filled=O.ResourceFillExtent(bar,ratio)
    bar.fill:SetWidth(filled)
    bar.fill:SetHeight(bar.fillHeight)
    bar.fill:SetTextureCoords(0,filled/bar.curveWidth,0,1)
    bar.fill:SetHidden(bar.curved or filled<=0)
    O.UpdateCurvedFill(bar,ratio)
end

local RESOURCE_TRANSITION=0.12
local function resourceRatio(bar,now)
    if not bar.resourceTransition then return bar.displayedRatio end
    local t=math.max(0,math.min(1,(now-bar.resourceStarted)/RESOURCE_TRANSITION))
    -- A short ease-out follows repeated resource ticks without visible jumps.
    return bar.resourceFrom+(bar.targetRatio-bar.resourceFrom)*(1-(1-t)*(1-t))
end
local function drawResource(bar,ratio)
    bar.displayedRatio=ratio
    O.UpdateResourceFill(bar,ratio)
end
function O.SetResourceRatio(bar,ratio,maximum)
    local now=GetFrameTimeSeconds()
    if not O.resourcesVisible or bar.displayedRatio==nil or bar.resourceMaximum~=maximum
        or ratio==0 or ratio>=1 or ratio<bar.displayedRatio then
        bar.resourceTransition=false
        bar.targetRatio=ratio
        drawResource(bar,ratio)
    elseif bar.targetRatio~=ratio then
        bar.resourceFrom=resourceRatio(bar,now)
        bar.resourceStarted=now
        bar.targetRatio=ratio
        bar.resourceTransition=true
        drawResource(bar,bar.resourceFrom)
    else
        -- Layout/colour changes must also redraw the curved lower bar.
        drawResource(bar,resourceRatio(bar,now))
    end
    bar.resourceMaximum=maximum
end
function O.AnimateResources()
    if not O.resourcesVisible then return end
    local now=GetFrameTimeSeconds()
    for _,spec in ipairs(O.resources) do
        local bar=O.bars[spec.key]
        if bar.resourceTransition then
            drawResource(bar,resourceRatio(bar,now))
            if now-bar.resourceStarted>=RESOURCE_TRANSITION then bar.resourceTransition=false end
        end
    end
end
function O.ResetResourceAnimations()
    if not O.bars then return end
    for _,bar in pairs(O.bars) do
        bar.resourceTransition=false
        bar.displayedRatio=nil
    end
end

function O.CreateUI()
    local root=WINDOW_MANAGER:CreateTopLevelWindow("ObsidianHUDResources")
    root:SetDrawLayer(DL_CONTROLS)
    root:SetDrawTier(DT_LOW)
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    O.root=root
    root:SetHandler("OnUpdate",O.AnimateResources)
    O.panel=O.Frame(root)
    O.panel:SetAnchorFill(root)
    O.panel:SetHidden(true)
    O.title=O.Label(root,12)
    O.title:SetFont("$(ANTIQUE_FONT)|16|soft-shadow-thick")
    O.title:SetAnchor(TOPLEFT,root,TOPLEFT,90,6)
    O.accent=O.Rect(root,1,1,1,1)
    O.accent:SetAnchor(TOPLEFT,root,TOPLEFT,125,13)
    O.accent:SetAnchor(TOPRIGHT,root,TOPRIGHT,-12,13)
    O.accent:SetHeight(1)
    O.accent:SetHidden(true)
    O.bars={}
    for _,spec in ipairs(O.resources) do O.bars[spec.key]=resource(root,spec) end
    O.shield=WINDOW_MANAGER:CreateControl(nil,O.bars.health.frame,CT_STATUSBAR)
    O.shield:SetAnchorFill(O.bars.health.frame)
    O.shield:SetTexture(ART.."fantasy_fill.dds")
    O.shield:SetDrawLayer(DL_CONTROLS)
    O.shield:SetDrawLevel(2)
    O.shield:SetColor(0.54,0.86,1,0.9)
    O.shield:SetMinMax(0,1)
    O.shield:SetHidden(true)
    O.badge=artwork(root,"fantasy_round.dds")
    O.badge:SetDrawLevel(10)
    O.badge:SetAnchor(TOPLEFT,root,TOPLEFT,0,17)
    O.badge:SetDimensions(86,86)
    O.classIcon=artwork(root,"fantasy_round.dds")
    O.classIcon:SetAnchor(CENTER,O.badge,CENTER,0,0)
    O.classIcon:SetDimensions(41,41)
    O.classIcon:SetDrawLevel(11)
    O.classIcon:SetHidden(true)
    local fragment=ZO_SimpleSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    O.fragment=fragment
    O.Layout()
end

function O.ArrangeResourceBars(force)
    local order=O.ResourceOrder()
    local primary=order[2].key
    if not force and O.displayedPrimary==primary then return end
    O.displayedPrimary=primary
    for i,spec in ipairs(order) do
        local bar=O.bars[spec.key]
        bar.resourceKey=spec.key
        local curved=i==3 and O.vars.roundBadge
        bar.curved=curved
        local inset=56+(i-1)*6
        local overlap=curved and 32 or 0
        bar.border:SetHidden(curved)
        bar.fill:SetHidden(curved)
        bar.track:SetHidden(curved)
        bar.frame:ClearAnchors()
        bar.frame:SetAnchor(TOPLEFT,O.root,TOPLEFT,inset-overlap,27+(i-1)*27)
        bar.frame:SetDimensions(O.vars.width-62-(i-1)*28+overlap,43-(i-1)*4)
        local width=O.vars.width-62-(i-1)*28+overlap
        bar.curveWidth=width
        local height=43-(i-1)*4
        bar.fillHeight=height
        for part,control in pairs(bar.curve) do
            local cap=part:find("cap")==1
            control:ClearAnchors()
            control:SetAnchor(TOPLEFT,bar.frame,TOPLEFT,cap and 0 or CURVE_WIDTH,0)
            control:SetDimensions(cap and CURVE_WIDTH or width-CURVE_WIDTH,height)
            control:SetTextureCoords(cap and 0 or CURVE_U,cap and CURVE_U or 1,0,1)
            control:SetHidden(not curved)
            if part:find("Track") then control:SetColor(0.12,0.10,0.13,1)
            elseif part:find("Border") then control:SetColor(unpack(O.vars.accent))
            else local c=O.vars[spec.key]; control:SetColor(c[1],c[2],c[3],1) end
        end
        bar.name:ClearAnchors()
        bar.name:SetAnchor(LEFT,bar.frame,LEFT,99-(inset-overlap),0)
        bar.name:SetFont("$(BOLD_FONT)|"..(i==1 and 12 or 11).."|soft-shadow-thick")
        bar.value:ClearAnchors()
        -- Keep the entire value text on the straight section at every width.
        local tipWidth=curved and (width-CURVE_WIDTH)*33/416 or width*33/512
        bar.value:SetAnchor(RIGHT,bar.frame,RIGHT,-math.max(40,tipWidth+12),0)
        bar.value:SetFont("$(BOLD_FONT)|"..(i==1 and 14 or 12).."|soft-shadow-thick")
        O.UpdateResourceFill(bar,bar.displayedRatio or 0)
    end
end

function O.Layout()
    local v=O.vars
    O.root:ClearAnchors()
    O.root:SetAnchor(BOTTOM,GuiRoot,BOTTOM,v.x,v.y)
    O.root:SetDimensions(v.width,116)
    O.root:SetScale(v.scale)
    O.root:SetAlpha(v.opacity)
    O.accent:SetColor(unpack(v.accent))
    O.badge:SetTexture(ART.."fantasy_round.dds")
    O.badge:ClearAnchors()
    O.badge:SetAnchor(TOPLEFT,O.root,TOPLEFT,v.roundBadge and -7 or 0,v.roundBadge and 18 or 17)
    O.badge:SetDimensions(v.roundBadge and 100 or 86,v.roundBadge and 100 or 86)
    O.badge:SetColor(unpack(v.accent))
    O.title:SetText(GetUnitName and zo_strformat("<<1>>",GetUnitName("player")) or "Obsidian")
    O.title:ClearAnchors()
    O.title:SetAnchor(TOPLEFT,O.root,TOPLEFT,90,6)
    O.UpdateClassIcon()
    O.ArrangeResourceBars(true)
    for _,spec in ipairs(O.resources) do
        local c=v[spec.key]
        O.bars[spec.key].border:SetColor(unpack(v.accent))
        O.bars[spec.key].fill:SetGradientColors(ORIENTATION_HORIZONTAL,c[1]*0.45,c[2]*0.45,c[3]*0.45,1,c[1],c[2],c[3],1)
        O.bars[spec.key].value:SetHidden(not v.numbers)
    end
end

function O.GetClassTexture()
    if not GetNumClasses or not GetClassInfo or not GetUnitClassId then return nil end
    local selected=GetUnitClassId("player")
    for i=1,GetNumClasses() do
        local data={GetClassInfo(i)}
        if data[1]==selected then
            local icon=IsInGamepadPreferredMode and IsInGamepadPreferredMode() and data[8] or data[7]
            if type(icon)~="string" or icon=="" then icon=data[3] end
            return type(icon)=="string" and icon~="" and icon or nil
        end
    end
end

function O.UpdateResources()
    O.ArrangeResourceBars(false)
    local shield=0
    if GetUnitAttributeVisualizerEffectInfo then
        local shieldValue=GetUnitAttributeVisualizerEffectInfo("player",ATTRIBUTE_VISUAL_POWER_SHIELDING,
            STAT_MITIGATION,ATTRIBUTE_HEALTH,COMBAT_MECHANIC_FLAGS_HEALTH)
        shield=math.max(0,tonumber(shieldValue) or 0)
    end
    for _,spec in ipairs(O.resources) do
        local current,maximum,effective=GetUnitPower("player",spec.power)
        maximum=effective and effective>0 and effective or maximum
        local bar=O.bars[spec.key]
        local ratio=O.Ratio(current,maximum)
        O.SetResourceRatio(bar,ratio,maximum)
        if spec.key=="health" then
            bar.value:SetText(O.HealthValueText(current,maximum,shield))
            O.shield:SetValue(O.Ratio(shield,maximum))
            O.shield:SetHidden(shield<=0 or not maximum or maximum<=0)
        else bar.value:SetText(O.ValueText(current,maximum)) end
    end
end

function O.CreateSlotSkin(button,stableSlot)
    local skin={button=button}
    local icon=button.icon
    -- Empty quickslots hide their native icon. Keep their decoration attached
    -- to the slot so the same frame remains visible with or without an item.
    local target=stableSlot and button.slot or icon
    local frame=O.Frame(target)
    frame:SetDrawLayer(DL_OVERLAY)
    frame:SetDrawLevel(20)
    local framePad=stableSlot and 2.5 or 4
    frame:SetAnchor(TOPLEFT,target,TOPLEFT,-framePad,-framePad)
    frame:SetAnchor(BOTTOMRIGHT,target,BOTTOMRIGHT,framePad,framePad)
    -- The centre must remain transparent so the real ability icon stays visible.
    frame.background:SetHidden(true)
    skin.art=artwork(frame,"fantasy_slot.dds")
    local artPad=stableSlot and 4.5 or 6
    skin.art:SetAnchor(TOPLEFT,target,TOPLEFT,-artPad,-artPad)
    skin.art:SetAnchor(BOTTOMRIGHT,target,BOTTOMRIGHT,artPad,artPad)
    skin.art:SetDrawLevel(21)
    skin.frame=frame
    return skin
end

function O.SkillIconRestSize(button)
    -- Native keyboard/gamepad templates leave three units between slot and
    -- resting icon size. The slot stays fixed while Icon/FlipCard bounce.
    local width,height=O.SkillSlotSize(button.slot)
    return math.max(1,width-3),math.max(1,height-3)
end

function O.UpdateBarIndicator(button,active,visible)
    if not button or not visible then
        if O.barIndicator then O.barIndicator:SetHidden(true) end
        return
    end
    if O.barIndicatorSlot~=button.slot then
        if O.barIndicator then O.barIndicator:SetHidden(true) end
        -- Anchor beside the active slot, but do not inherit the slot's
        -- visibility/alpha or clipping while ESO reapplies its templates.
        O.barIndicator=create(ZO_ActionBar1 or button.slot:GetParent(),CT_TEXTURE)
        O.barIndicator:SetTexture("esoui/art/buttons/large_rightarrow_up.dds")
        O.barIndicator:SetDimensions(64,64)
        O.barIndicator:SetMouseEnabled(false)
        O.barIndicator:SetAnchor(RIGHT,button.slot,LEFT,5,0)
        O.barIndicator:SetDrawTier(DT_HIGH)
        O.barIndicator:SetDrawLayer(DL_OVERLAY)
        O.barIndicator:SetDrawLevel(40)
        O.barIndicator:SetColor(0.08,1,0.12,1)
        -- Keep the arrow's dark outline; additive green layers provide the
        -- luminous centre and a small halo without turning it yellow/white.
        for _,style in ipairs({{72,39,0.28},{64,41,0.55}}) do
            local glow=create(O.barIndicator,CT_TEXTURE)
            glow:SetTexture("esoui/art/buttons/large_rightarrow_up.dds")
            glow:SetDimensions(style[1],style[1])
            glow:SetAnchor(CENTER,O.barIndicator,CENTER,0,0)
            glow:SetDrawTier(DT_HIGH)
            glow:SetDrawLayer(DL_OVERLAY)
            glow:SetDrawLevel(style[2])
            glow:SetColor(0.02,1,0.06,style[3])
            if TEX_BLEND_MODE_ADD then glow:SetBlendMode(TEX_BLEND_MODE_ADD) end
            glow:SetMouseEnabled(false)
        end
        O.barIndicatorSlot=button.slot
    end
    if O.barIndicator.SetInheritAlpha then O.barIndicator:SetInheritAlpha(false) end
    O.barIndicator:SetAlpha(1)
    O.barIndicator:SetHidden(false)
end

function O.LayoutSkillPreview(skin)
    local equal=O.vars.skillHudView=="equal" or O.IsFixedSkillView()
    local iconWidth,iconHeight=O.SkillIconRestSize(skin.button)
    local width=equal and iconWidth+12 or 43
    local height=equal and iconHeight+12 or 43
    local displayed=O.SkillDisplayBar and O.SkillDisplayBar(skin.button) or GetActiveHotbarCategory()
    local placement=O.IsFixedSkillView() and displayed or "above"
    local gap=O.SkillRowGap(skin.button.slot)
    if skin.activeTextSlot==8 and O.DualUltimateView() then gap=O.UltimateRowSeparation() end
    local sizeTarget=equal and skin.button.slot or nil
    if skin.previewPlacement~=placement or skin.previewGap~=gap or skin.previewSizeTarget~=sizeTarget then
        skin.previewPlacement=placement
        skin.previewGap=gap
        skin.previewSizeTarget=sizeTarget
        skin.back:ClearAnchors()
        if sizeTarget and placement~="above" then
            -- Match the active artwork's RESTING bounds, using the stable
            -- slot. Following skin.art also copies the pressed icon's bounce
            -- into the other weapon's preview, as if both skills were used.
            local offset=placement==HOTBAR_CATEGORY_PRIMARY and gap or -gap
            skin.back:SetAnchor(TOPLEFT,sizeTarget,TOPLEFT,-4.5,offset-4.5)
            skin.back:SetAnchor(BOTTOMRIGHT,sizeTarget,BOTTOMRIGHT,4.5,offset+4.5)
        elseif placement=="above" then
            skin.back:SetAnchor(BOTTOM,skin.button.slot,TOP,0,-15.5)
        else
            skin.back:SetAnchor(CENTER,skin.button.slot,CENTER,0,placement==HOTBAR_CATEGORY_PRIMARY and gap or -gap)
        end
    end
    if skin.previewWidth==width and skin.previewHeight==height then return end
    skin.previewWidth,skin.previewHeight=width,height
    if not sizeTarget or placement=="above" then skin.back:SetDimensions(width,height) end
    local inset=equal and 6 or 3
    skin.backIcon:ClearAnchors()
    skin.backIcon:SetAnchor(TOPLEFT,skin.back,TOPLEFT,inset,inset)
    skin.backIcon:SetAnchor(BOTTOMRIGHT,skin.back,BOTTOMRIGHT,-inset,-inset)
end

function O.CreateSkillSkin(button)
    local skin=O.CreateSlotSkin(button)
    local icon=button.icon
    local back=O.Frame(button.slot)
    -- Match the active frame: an opaque rectangular backing otherwise shows
    -- through the transparent, bevelled corners of the shared artwork.
    back.background:SetHidden(true)
    back:SetDrawLayer(DL_OVERLAY)
    back:SetDrawLevel(20)
    -- Anchor to the stable slot, never the icon animated by skill activation.
    back:SetAnchor(BOTTOM,button.slot,TOP,0,-15.5)
    back:SetDimensions(43,43)
    local backIcon=O.Rect(back,1,1,1,1)
    backIcon.obsidianSurface=false -- Slot icons must never be replaced by the shared surface loader.
    backIcon:SetDrawLayer(DL_CONTROLS)
    -- Only the inactive icon is muted. Timers and stack text stay legible.
    backIcon:SetDesaturation(1)
    backIcon:SetColor(0.7,0.7,0.7,1)
    backIcon:SetAnchor(TOPLEFT,back,TOPLEFT,3,3)
    backIcon:SetAnchor(BOTTOMRIGHT,back,BOTTOMRIGHT,-3,-3)
    local backMetal=artwork(back,"fantasy_slot.dds")
    backMetal:SetAnchorFill(back)
    backMetal:SetDrawLevel(21)
    local timer=O.Label(back,16)
    timer:SetAnchor(CENTER,back,CENTER,0,0)
    skin.back,skin.backIcon,skin.timer,skin.backMetal=back,backIcon,timer,backMetal
    -- Persistent proc readiness is separate from native activation/bounce
    -- animations, so it also works in the no-animation HUD views.
    skin.procFront=create(button.slot,CT_TEXTURE)
    skin.procFront:SetAnchorFill(button.icon)
    skin.procBack=create(back,CT_TEXTURE)
    skin.procBack:SetAnchorFill(backIcon)
    for _,entry in ipairs({{skin.procFront,button.icon},{skin.procBack,backIcon}}) do
        local highlight,icon=entry[1],entry[2]
        highlight.procAnimation=false
        highlight.procReady=false
        highlight.procTexture=false
        highlight.procGlow=create(highlight,CT_TEXTURE)
        local glow=highlight.procGlow
        glow:SetTexture("esoui/art/hud/gamepad/gp_skillglow.dds")
        glow:SetTextureCoords(0.1875,0.8125,0.1875,0.8125)
        glow:SetAnchor(TOPLEFT,icon,TOPLEFT,-12,-12)
        glow:SetAnchor(BOTTOMRIGHT,icon,BOTTOMRIGHT,12,12)
        glow:SetDrawTier(DT_HIGH); glow:SetDrawLayer(DL_OVERLAY); glow:SetDrawLevel(22)
        glow:SetColor(1,1,1,0.75); glow:SetHidden(true); glow:SetMouseEnabled(false)
        highlight:SetDrawTier(DT_HIGH)
        highlight:SetDrawLayer(DL_OVERLAY)
        highlight:SetDrawLevel(23)
        highlight:SetColor(1,1,1,1)
        if TEX_BLEND_MODE_ADD then highlight:SetBlendMode(TEX_BLEND_MODE_ADD); glow:SetBlendMode(TEX_BLEND_MODE_ADD) end
        highlight:SetMouseEnabled(false)
        highlight:SetHidden(true)
    end
    O.CreateSkillText(skin)
    back:SetHandler("OnUpdate",function() O.UpdatePreviewSwap(skin); O.UpdateBackBarTimer(skin) end)
    return skin
end
