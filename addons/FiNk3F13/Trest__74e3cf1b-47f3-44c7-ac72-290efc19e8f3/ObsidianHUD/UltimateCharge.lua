local O=ObsidianHUD
local function hasUltimate(bar)
    return bar~=nil and GetSlotBoundId and (tonumber(GetSlotBoundId(8,bar)) or 0)>0
end
function O.UltimateChargeRatio(bar)
    if not hasUltimate(bar) or not COMBAT_MECHANIC_FLAGS_ULTIMATE or not GetSlotAbilityCost or not GetUnitPower then return 0 end
    local cost=GetSlotAbilityCost(8,COMBAT_MECHANIC_FLAGS_ULTIMATE,bar)
    local points=GetUnitPower("player",COMBAT_MECHANIC_FLAGS_ULTIMATE)
    -- Select only the current value before conversion: ESO's GetUnitPower
    -- also returns maxima, which tonumber would interpret as its base.
    cost=tonumber(cost)
    points=tonumber(points) or 0
    if not cost or cost<=0 or cost~=cost or cost==math.huge or points~=points then return 0 end
    return math.max(0,math.min(1,points/cost))
end
function O.UltimateChargePath(w,h,right)
    -- Trace the actual fantasy_slot.dds octagon, not its rectangular bounds.
    local path={}
    for _,p in ipairs({{32,61},{8,61},{3,56},{3,8},{8,3},{32,3}}) do
        path[#path+1]={(right and 64-p[1] or p[1])*w/64,p[2]*h/64}
    end
    return path
end
local function createFrame(parent,icon,outline)
    local root=WINDOW_MANAGER:CreateControl(nil,parent,CT_CONTROL)
    root:SetMouseEnabled(false)
    if outline then root:SetAnchorFill(outline)
    else
        root:SetAnchor(TOPLEFT,icon,TOPLEFT,-6,-6)
        root:SetAnchor(BOTTOMRIGHT,icon,BOTTOMRIGHT,6,6)
    end
    root:SetDrawTier(DT_HIGH); root:SetDrawLayer(DL_OVERLAY); root:SetDrawLevel(35)
    local frame={root=root,edges={}}
    local texture=O.SurfaceTexture()
    for i=1,10 do
        local edge={branch=i<=5 and 1 or 2,index=(i-1)%5+1}
        for _,key in ipairs({"glow","fill","core"}) do
            edge[key]=WINDOW_MANAGER:CreateControl(nil,root,CT_LINE)
            edge[key]:SetTexture(texture); edge[key]:SetMouseEnabled(false)
            edge[key]:SetPixelRoundingEnabled(false)
        end
        edge.glow:SetColor(1,0.7,0.15,0.32)
        edge.fill:SetColor(1,0.86,0.3,1)
        edge.core:SetColor(1,0.98,0.72,1)
        for level,key in ipairs({"glow","fill","core"}) do
            edge[key]:SetDrawLayer(DL_OVERLAY); edge[key]:SetDrawLevel(35+level)
        end
        frame.edges[#frame.edges+1]=edge
    end
    return frame
end
local function segment(root,control,x1,y1,x2,y2,thickness)
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT,root,TOPLEFT,x1,y1)
    control:SetAnchor(BOTTOMRIGHT,root,TOPLEFT,x2,y2)
    control:SetThickness(thickness)
end
local function frameSize(frame)
    local root=frame.root
    if not root.GetLeft or not root.GetRight or not root.GetTop or not root.GetBottom then
        return root:GetWidth(),root:GetHeight()
    end
    local left,top,right,bottom=root:GetLeft(),root:GetTop(),root:GetRight(),root:GetBottom()
    if not left or not top or not right or not bottom then return 0,0 end
    local w,h=right-left,bottom-top
    if w<=0 or h<=0 then return 0,0 end
    if frame.screenWidth~=w or frame.screenHeight~=h then
        -- Screen bounds and child anchor offsets need not use the same units
        -- under ESO's inherited UI scale. Measure one anchor unit instead of
        -- feeding screen pixels back into scaled offsets a second time.
        local probe=frame.probe
        if not probe then
            probe=WINDOW_MANAGER:CreateControl(nil,root,CT_CONTROL)
            probe:SetDimensions(1,1); probe:SetMouseEnabled(false); probe:SetHidden(true)
            frame.probe=probe
        end
        probe:ClearAnchors(); probe:SetAnchor(TOPLEFT,root,TOPLEFT,0,0)
        local x,y=probe:GetLeft(),probe:GetTop()
        probe:ClearAnchors(); probe:SetAnchor(TOPLEFT,root,TOPLEFT,1,1)
        local dx,dy=probe:GetLeft()-x,probe:GetTop()-y
        if dx<=0 or dy<=0 then return 0,0 end
        frame.anchorWidth,frame.anchorHeight=w/dx,h/dy
        frame.screenWidth,frame.screenHeight=w,h
    end
    return frame.anchorWidth,frame.anchorHeight
end
local function draw(frame,w,h,ratio,active)
    if not w or not h or w<=0 or h<=0 then
        frame.root:SetHidden(true); frame.visible=false; return
    end
    if not frame.visible then frame.root:SetHidden(false); frame.visible=true end
    if frame.width==w and frame.height==h and frame.ratio==ratio and frame.active==active then return end
    frame.width,frame.height,frame.ratio,frame.active=w,h,ratio,active
    local paths={O.UltimateChargePath(w,h,false),O.UltimateChargePath(w,h,true)}
    local total,starts,lengths=0,{},{}
    for i=1,5 do
        local a,b=paths[1][i],paths[1][i+1]
        starts[i]=total; lengths[i]=math.sqrt((b[1]-a[1])^2+(b[2]-a[2])^2)
        total=total+lengths[i]
    end
    local distance=ratio*total
    for _,edge in ipairs(frame.edges) do
        local a,b=paths[edge.branch][edge.index],paths[edge.branch][edge.index+1]
        local length=lengths[edge.index]
        local filled=math.max(0,math.min(length,distance-starts[edge.index]))
        edge.filled=filled
        for _,entry in ipairs({{edge.glow,7},{edge.fill,2.8},{edge.core,1}}) do
            if filled>0 then
                local t=filled/length
                segment(frame.root,entry[1],a[1],a[2],a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,entry[2])
            end
            entry[1]:SetHidden(filled<=0)
        end
    end
end
local function drawFrame(frame,ratio,active)
    local w,h=frameSize(frame)
    draw(frame,w,h,ratio,active)
end
local function hide(frame)
    if not frame then return end
    frame.root:SetHidden(true)
    frame.visible=false
    frame.ratio=nil
end
function O.HideUltimateCharge(skin)
    hide(skin.chargeFront)
    hide(skin.chargeBack)
end
function O.UpdateUltimateCharge(skin)
    if not skin.activeTextVisible then O.HideUltimateCharge(skin); return end
    local active=GetActiveHotbarCategory()
    local logical=active
    if O.SkillDisplayBar then active=O.SkillDisplayBar(skin.button) end
    local other=O.OtherBar(active)
    if not other or skin.activeTextBar~=logical then O.HideUltimateCharge(skin); return end
    -- Empty slots can retain the previous ultimate's cost during a swap.
    -- Validate each bar's bound ability before creating or displaying its frame.
    if hasUltimate(active) then
        if not skin.chargeFront then skin.chargeFront=createFrame(skin.button.slot,skin.button.icon,skin.art) end
        drawFrame(skin.chargeFront,O.UltimateChargeRatio(active),true)
    else hide(skin.chargeFront) end
    if O.DualUltimateView() and skin.timerVisible and skin.timerBar==other and hasUltimate(other) then
        if not skin.chargeBack then skin.chargeBack=createFrame(skin.back,skin.backIcon,skin.backMetal) end
        drawFrame(skin.chargeBack,O.UltimateChargeRatio(other),false)
    else hide(skin.chargeBack) end
end
