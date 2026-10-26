local O=ObsidianHUD
function O.UltimateChargeRatio(bar)
    if not COMBAT_MECHANIC_FLAGS_ULTIMATE or not GetSlotAbilityCost or not GetUnitPower then return 0 end
    local cost=GetSlotAbilityCost(8,COMBAT_MECHANIC_FLAGS_ULTIMATE,bar)
    local points=GetUnitPower("player",COMBAT_MECHANIC_FLAGS_ULTIMATE)
    if not cost or cost<=0 then return 0 end
    return math.max(0,math.min(1,(points or 0)/cost))
end
local function createFrame(parent,icon)
    local root=WINDOW_MANAGER:CreateControl(nil,parent,CT_CONTROL)
    root:SetMouseEnabled(false)
    root:SetAnchor(TOPLEFT,icon,TOPLEFT,-3,-3)
    root:SetAnchor(BOTTOMRIGHT,icon,BOTTOMRIGHT,3,3)
    root:SetDrawTier(DT_HIGH); root:SetDrawLayer(DL_OVERLAY); root:SetDrawLevel(35)
    local frame={root=root,edges={}}
    for _,point in ipairs({TOPLEFT,TOPRIGHT,BOTTOMRIGHT,BOTTOMLEFT}) do
        local track=O.Rect(root,0.12,0.12,0.12,0.95)
        local fill=O.Rect(root,1,0.75,0.18,1)
        for _,c in ipairs({track,fill}) do c:SetDrawLayer(DL_OVERLAY); c:SetAnchor(point,root,point) end
        track:SetDrawLevel(36); fill:SetDrawLevel(37)
        frame.edges[#frame.edges+1]={track=track,fill=fill}
    end
    return frame
end
local function draw(frame,w,h,ratio,active)
    if not frame.visible then frame.root:SetHidden(false); frame.visible=true end
    if frame.width==w and frame.height==h and frame.ratio==ratio and frame.active==active then return end
    frame.width,frame.height,frame.ratio,frame.active=w,h,ratio,active
    for i,edge in ipairs(frame.edges) do
        local horizontal=i==1 or i==3
        local length=horizontal and w or h
        local amount=math.max(0,math.min(1,ratio*4-(i-1)))
        edge.track:SetDimensions(horizontal and length or 3,horizontal and 3 or length)
        edge.fill:SetDimensions(horizontal and length*amount or 3,horizontal and 3 or length*amount)
        edge.fill:SetHidden(amount<=0)
        edge.fill:SetColor(active and 1 or 0.8,active and 0.75 or 0.6,0.18,1)
    end
end
function O.HideUltimateCharge(skin)
    if skin.chargeFront then
        skin.chargeFront.root:SetHidden(true); skin.chargeBack.root:SetHidden(true)
        skin.chargeFront.visible=false; skin.chargeBack.visible=false
    end
end
function O.UpdateUltimateCharge(skin)
    if not O.DualUltimateView() or not skin.activeTextVisible then O.HideUltimateCharge(skin); return end
    if not skin.chargeFront then
        skin.chargeFront=createFrame(skin.button.slot,skin.button.icon)
        skin.chargeBack=createFrame(skin.back,skin.backIcon)
    end
    local active=GetActiveHotbarCategory()
    draw(skin.chargeFront,skin.button.icon:GetWidth()+6,skin.button.icon:GetHeight()+6,O.UltimateChargeRatio(active),true)
    if skin.timerVisible then
        draw(skin.chargeBack,skin.previewWidth-6,skin.previewHeight-6,O.UltimateChargeRatio(O.OtherBar(active)),false)
    else skin.chargeBack.root:SetHidden(true); skin.chargeBack.visible=false end
end
