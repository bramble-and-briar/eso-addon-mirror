local O=ObsidianHUD
function O.UltimateChargeRatio(bar)
    if not COMBAT_MECHANIC_FLAGS_ULTIMATE or not GetSlotAbilityCost or not GetUnitPower then return 0 end
    local cost=GetSlotAbilityCost(8,COMBAT_MECHANIC_FLAGS_ULTIMATE,bar)
    local points=GetUnitPower("player",COMBAT_MECHANIC_FLAGS_ULTIMATE)
    if not cost or cost<=0 then return 0 end
    return math.max(0,math.min(1,(points or 0)/cost))
end
function O.UltimateChargePath(w,h,right)
    -- Trace the actual fantasy_slot.dds octagon, not its rectangular bounds.
    local path={}
    for _,p in ipairs({{32,61},{8,61},{3,56},{3,8},{8,3},{32,3}}) do
        path[#path+1]={(right and 64-p[1] or p[1])*w/64,p[2]*h/64}
    end
    return path
end
local function createFrame(parent,icon)
    local root=WINDOW_MANAGER:CreateControl(nil,parent,CT_CONTROL)
    root:SetMouseEnabled(false)
    root:SetAnchor(TOPLEFT,icon,TOPLEFT,-6,-6)
    root:SetAnchor(BOTTOMRIGHT,icon,BOTTOMRIGHT,6,6)
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
local function draw(frame,w,h,ratio,active)
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
function O.HideUltimateCharge(skin)
    if skin.chargeFront then
        skin.chargeFront.root:SetHidden(true); skin.chargeBack.root:SetHidden(true)
        skin.chargeFront.visible=false; skin.chargeBack.visible=false
    end
end
function O.UpdateUltimateCharge(skin)
    if not skin.activeTextVisible then O.HideUltimateCharge(skin); return end
    if not skin.chargeFront then
        skin.chargeFront=createFrame(skin.button.slot,skin.button.icon)
        skin.chargeBack=createFrame(skin.back,skin.backIcon)
    end
    local active=GetActiveHotbarCategory()
    local width,height=skin.button.icon:GetWidth(),skin.button.icon:GetHeight()
    if O.skillScaleDimensions and O.SkillIconRestSize then width,height=O.SkillIconRestSize(skin.button) end
    draw(skin.chargeFront,width+12,height+12,O.UltimateChargeRatio(active),true)
    if O.DualUltimateView() and skin.timerVisible then
        draw(skin.chargeBack,skin.previewWidth,skin.previewHeight,O.UltimateChargeRatio(O.OtherBar(active)),false)
    else skin.chargeBack.root:SetHidden(true); skin.chargeBack.visible=false end
end
