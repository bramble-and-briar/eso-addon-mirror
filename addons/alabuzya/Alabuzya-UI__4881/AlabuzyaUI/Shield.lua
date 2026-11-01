local AlabuzyaUI=AlabuzyaUI
-- Shared shield reading; Diablo supplies the circular presentation.
AlabuzyaUI.Shield={}
local M=AlabuzyaUI.Shield
local SEGMENTS=48
function M.Amount()
    if not GetUnitAttributeVisualizerEffectInfo then return 0 end
    local value=GetUnitAttributeVisualizerEffectInfo('player',ATTRIBUTE_VISUAL_POWER_SHIELDING,
        STAT_MITIGATION,ATTRIBUTE_HEALTH,COMBAT_MECHANIC_FLAGS_HEALTH)
    return math.max(0,value or 0)
end
function M.NewRing(parent)
    local ring={parent=parent,lines={},fraction=-1}
    return ring
end
local function Line(ring,index,glow)
    local pair=ring.lines[index]
    if not pair then pair={} ring.lines[index]=pair end
    local layer=glow and 1 or 2
    local c=pair[layer]
    if not c then
        c=WINDOW_MANAGER:CreateControl(nil,ring.parent,CT_LINE)
        c:SetMouseEnabled(false)
        -- Native lines have a solid default surface; do not depend on an
        -- unverified game texture path for their visibility.
        c:SetPixelRoundingEnabled(false)
        c:SetThickness(glow and 5 or 2.2)
        c:SetColor(1,.95,.82,glow and .20 or .95)
        c:SetDrawLayer(DL_OVERLAY) c:SetDrawLevel(glow and 24 or 25)
        pair[layer]=c
    end
    return c
end
local function Position(line,parent,x1,y1,x2,y2)
    local cx,cy=parent:GetWidth()/2,parent:GetHeight()/2
    -- ESO's line control uses two endpoints, not a normal rectangular quad.
    ZO_Anchor_LineInContainer(line,parent,cx+x1,cy+y1,cx+x2,cy+y2)
    line:SetHidden(false)
end
function M.UpdateRing(ring,value,maxHealth)
    local fraction=maxHealth>0 and math.max(0,math.min(1,value/maxHealth)) or 0
    if ring.fraction==fraction then return end
    ring.fraction=fraction
    local used=0
    -- Both sides begin at six o'clock and meet at twelve o'clock at 100% HP.
    -- Match the 166px health fluid and its center in Core.Orb.
    for _,side in ipairs({-1,1}) do
        for i=1,math.ceil(fraction*SEGMENTS) do
            local a=(i-1)*math.pi/SEGMENTS
            local b=math.min(i/SEGMENTS,fraction)*math.pi
            local x1,y1=side*82*math.sin(a),-44+82*math.cos(a)
            local x2,y2=side*82*math.sin(b),-44+82*math.cos(b)
            used=used+1
            Position(Line(ring,used,true),ring.parent,x1,y1,x2,y2)
            Position(Line(ring,used,false),ring.parent,x1,y1,x2,y2)
        end
    end
    for i=used+1,#ring.lines do
        for _,line in ipairs(ring.lines[i]) do line:SetHidden(true) end
    end
end
