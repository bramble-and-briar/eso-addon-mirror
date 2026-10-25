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
    return assetReady(ObsidianHUDAssetsFantasyFrame,512,64) and
        assetReady(ObsidianHUDAssetsFantasyFill,512,64) and
        (not O.vars.roundBadge or (assetReady(ObsidianHUDAssetsCurveFrame,512,64) and assetReady(ObsidianHUDAssetsCurveFill,512,64))) and
        assetReady(O.vars.roundBadge and ObsidianHUDAssetsFantasyRound or ObsidianHUDAssetsFantasyDiamond,128,128)
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

function O.MaterialStatus()
    local texture,ready=O.SurfaceTexture()
    ready=ready and O.FantasyReady()
    return "Fantasy-Grafiken: "..(ready and "geladen" or "werden geladen - Originalbalken bleiben sichtbar")..
        " | "..(texture==WHITE and "eigene DDS" or "ESO-Ausweichtextur")
end

function O.PrintMaterialStatus()
    d("Obsidian HUD "..O.version..": "..O.MaterialStatus())
    d("Obsidian HUD: aktiv="..tostring(O.vars.enabled).." | HUD="..tostring(HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()))
    for _,entry in ipairs({
        {"Rahmen",ObsidianHUDAssetsFantasyFrame},
        {"Balken",ObsidianHUDAssetsFantasyFill},
        {"Kurvenrahmen",ObsidianHUDAssetsCurveFrame},
        {"Kurvenfuellung",ObsidianHUDAssetsCurveFill},
        {"Emblem",O.vars.roundBadge and ObsidianHUDAssetsFantasyRound or ObsidianHUDAssetsFantasyDiamond},
        {"Klassensymbole",ObsidianHUDAssetsClasses},
        {"Flaeche",ObsidianHUDAssetsSolid},
        {"ESO-Ersatz",ObsidianHUDAssetsFallback},
    }) do
        local asset=entry[2]
        local w,h=0,0
        if asset then w,h=asset:GetTextureFileDimensions() end
        d("Obsidian HUD: "..entry[1].." | geladen="..tostring(asset and asset:IsTextureLoaded() or false).." | "..tostring(w).."x"..tostring(h))
    end
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
    local fill=create(frame,CT_STATUSBAR)
    fill:SetAnchorFill(frame)
    fill:SetTexture(ART.."fantasy_fill.dds")
    fill:SetDrawLayer(DL_CONTROLS)
    fill:SetDrawLevel(1)
    fill:SetColor(1,1,1,1)
    fill:SetMinMax(0,1)
    fill:SetValue(1)
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
function O.UpdateCurvedFill(bar,ratio)
    if not bar.curved then return end
    local width=bar.curveWidth
    local cap=math.min(CURVE_WIDTH,width)
    local filled=width*ratio
    local capFilled=math.min(cap,filled)
    local bodyFilled=math.max(0,filled-cap)
    bar.curve.capFill:SetWidth(capFilled)
    bar.curve.capFill:SetTextureCoords(0,CURVE_U*capFilled/cap,0,1)
    bar.curve.capFill:SetHidden(capFilled<=0)
    bar.curve.bodyFill:SetWidth(bodyFilled)
    bar.curve.bodyFill:SetTextureCoords(CURVE_U,CURVE_U+(1-CURVE_U)*bodyFilled/(width-cap),0,1)
    bar.curve.bodyFill:SetHidden(bodyFilled<=0)
end

function O.CreateUI()
    local root=WINDOW_MANAGER:CreateTopLevelWindow("ObsidianHUDResources")
    root:SetDrawLayer(DL_CONTROLS)
    root:SetDrawTier(DT_LOW)
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    O.root=root
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
    O.shield:SetAnchor(TOPLEFT,O.bars.health.frame,TOPLEFT,3,3)
    O.shield:SetAnchor(TOPRIGHT,O.bars.health.frame,TOPRIGHT,-3,3)
    O.shield:SetHeight(3)
    surface(O.shield)
    O.shield:SetDrawLayer(DL_OVERLAY)
    O.shield:SetColor(0.54,0.86,1,0.95)
    O.shield:SetMinMax(0,1)
    O.shield:SetHidden(true)
    O.badge=artwork(root,"fantasy_diamond.dds")
    O.badge:SetDrawLevel(10)
    O.badge:SetAnchor(TOPLEFT,root,TOPLEFT,0,17)
    O.badge:SetDimensions(86,86)
    O.classIcon=artwork(root,"fantasy_diamond.dds")
    O.classIcon:SetAnchor(CENTER,O.badge,CENTER,0,0)
    O.classIcon:SetDimensions(41,41)
    O.classIcon:SetDrawLevel(11)
    O.classIcon:SetHidden(true)
    O.level=O.Label(root,13)
    O.level:SetAnchor(TOP,O.badge,BOTTOM,0,3)
    O.level:SetColor(1,1,1,1)
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
        bar.value:SetAnchor(RIGHT,bar.frame,RIGHT,-27,0)
        bar.value:SetFont("$(BOLD_FONT)|"..(i==1 and 14 or 12).."|soft-shadow-thick")
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
    O.badge:SetTexture(ART..(v.roundBadge and "fantasy_round.dds" or "fantasy_diamond.dds"))
    O.badge:ClearAnchors()
    O.badge:SetAnchor(TOPLEFT,O.root,TOPLEFT,v.roundBadge and -7 or 0,v.roundBadge and 18 or 17)
    O.badge:SetDimensions(v.roundBadge and 100 or 86,v.roundBadge and 100 or 86)
    O.badge:SetColor(unpack(v.accent))
    O.title:SetText(GetUnitName and zo_strformat("<<1>>",GetUnitName("player")) or "Obsidian")
    O.title:ClearAnchors()
    O.title:SetAnchor(TOPLEFT,O.root,TOPLEFT,90,6)
    O.level:SetText(GetUnitLevel and tostring(GetUnitLevel("player")) or "")
    O.UpdateClassIcon()
    O.ArrangeResourceBars(true)
    for _,spec in ipairs(O.resources) do
        local c=v[spec.key]
        O.bars[spec.key].border:SetColor(unpack(v.accent))
        O.bars[spec.key].fill:SetGradientColors(c[1]*0.45,c[2]*0.45,c[3]*0.45,1,c[1],c[2],c[3],1)
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
    for _,spec in ipairs(O.resources) do
        local current,maximum,effective=GetUnitPower("player",spec.power)
        maximum=effective and effective>0 and effective or maximum
        local bar=O.bars[spec.key]
        local ratio=O.Ratio(current,maximum)
        bar.fill:SetValue(ratio)
        O.UpdateCurvedFill(bar,ratio)
        bar.value:SetText(O.ValueText(current,maximum))
    end
    if GetUnitAttributeVisualizerEffectInfo then
        local shield=GetUnitAttributeVisualizerEffectInfo("player",ATTRIBUTE_VISUAL_POWER_SHIELDING,
            STAT_MITIGATION,ATTRIBUTE_HEALTH,COMBAT_MECHANIC_FLAGS_HEALTH)
        local _,maximum,effective=GetUnitPower("player",COMBAT_MECHANIC_FLAGS_HEALTH)
        O.shield:SetValue(O.Ratio(shield,effective or maximum))
        O.shield:SetHidden(not shield or shield<=0)
    end
end

function O.CreateSkillSkin(button)
    local skin={button=button}
    local icon=button.icon
    local frame=O.Frame(icon)
    frame:SetDrawLayer(DL_OVERLAY)
    frame:SetDrawLevel(20)
    frame:SetAnchor(TOPLEFT,icon,TOPLEFT,-4,-4)
    frame:SetAnchor(BOTTOMRIGHT,icon,BOTTOMRIGHT,4,4)
    -- The centre must remain transparent so the real ability icon stays visible.
    frame.background:SetHidden(true)
    skin.art=artwork(frame,"fantasy_slot.dds")
    skin.art:SetAnchor(TOPLEFT,icon,TOPLEFT,-6,-6)
    skin.art:SetAnchor(BOTTOMRIGHT,icon,BOTTOMRIGHT,6,6)
    skin.art:SetDrawLevel(21)
    skin.frame=frame
    local back=O.Frame(button.slot)
    back:SetAnchor(BOTTOM,icon,TOP,0,-17)
    back:SetDimensions(43,43)
    local backIcon=O.Rect(back,1,1,1,1)
    backIcon.obsidianSurface=false -- Slot icons must never be replaced by the shared surface loader.
    backIcon:SetDrawLayer(DL_CONTROLS)
    backIcon:SetAnchor(TOPLEFT,back,TOPLEFT,3,3)
    backIcon:SetAnchor(BOTTOMRIGHT,back,BOTTOMRIGHT,-3,-3)
    local backMetal=artwork(back,"fantasy_slot.dds")
    backMetal:SetAnchorFill(back)
    backMetal:SetDrawLevel(4)
    local timer=O.Label(back,16)
    timer:SetAnchor(CENTER,back,CENTER,0,0)
    skin.back,skin.backIcon,skin.timer,skin.backMetal=back,backIcon,timer,backMetal
    return skin
end
