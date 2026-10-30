CT_CONTROL,CT_LINE,DT_HIGH,DL_OVERLAY,TOPLEFT,BOTTOMRIGHT=1,2,3,4,5,6
COMBAT_MECHANIC_FLAGS_ULTIMATE=10
local scale,active=1.2,0
local function near(a,b) assert(math.abs(a-b)<0.001,tostring(a).." ~= "..tostring(b)) end
local function control(parent,w,h)
    local c={parent=parent,w=w or 0,h=h or 0,anchors={}}
    function c:SetDimensions(w,h) self.w,self.h=w,h end
    function c:SetAnchorFill(target) self.outline=target end
    function c:ClearAnchors() self.anchors={} end
    function c:SetAnchor(...) self.anchors[#self.anchors+1]={...} end
    function c:GetLeft()
        if self.outline then return self.outline:GetLeft() end
        local a=self.anchors[1]
        return a and a[2]:GetLeft()+a[4]*scale or 400
    end
    function c:GetTop()
        if self.outline then return self.outline:GetTop() end
        local a=self.anchors[1]
        return a and a[2]:GetTop()+a[5]*scale or 300
    end
    function c:GetRight() return self:GetLeft()+(self.outline and self.outline.w or self.w)*scale end
    function c:GetBottom() return self:GetTop()+(self.outline and self.outline.h or self.h)*scale end
    -- Reproduce a UI API exposing screen-sized bounds: they must not be
    -- applied as inherited/scaled child anchor offsets without conversion.
    function c:GetWidth() return self:GetRight()-self:GetLeft() end
    function c:GetHeight() return self:GetBottom()-self:GetTop() end
    function c:SetHidden(v) self.hidden=v end
    for _,name in ipairs({"SetMouseEnabled","SetDrawTier","SetDrawLayer","SetDrawLevel",
        "SetTexture","SetPixelRoundingEnabled","SetColor","SetThickness"}) do c[name]=function() end end
    return c
end
WINDOW_MANAGER={CreateControl=function(_,_,parent) return control(parent) end}
function GetSlotBoundId(_,bar) return bar==0 and 101 or 202 end
function GetSlotAbilityCost() return 100 end
function GetUnitPower() return 100,500,500 end
function GetActiveHotbarCategory() return active end
ObsidianHUD={}
local O=ObsidianHUD
function O.OtherBar(bar) return bar==0 and 1 or 0 end
function O.DualUltimateView() return true end
function O.SurfaceTexture() return "solid.dds" end
dofile("UltimateCharge.lua")
local skin={activeTextVisible=true,activeTextBar=0,timerVisible=true,timerBar=1,
    button={slot=control(),icon=control(nil,67,67)},art=control(nil,79,79),
    back=control(nil,79,79),backIcon=control(nil,67,67),backMetal=control(nil,79,79)}
for _,value in ipairs({0.75,1,1.2,1.5,0.885185}) do
    scale=value
    for bar=0,1 do
        active=bar; skin.activeTextBar=bar; skin.timerBar=O.OtherBar(bar)
        O.UpdateUltimateCharge(skin)
        for _,entry in ipairs({{skin.chargeFront,skin.art},{skin.chargeBack,skin.backMetal}}) do
            local frame,outline=entry[1],entry[2]
            near(frame.width,79); near(frame.height,79)
            local path=O.UltimateChargePath(79,79,false)
            for i=1,5 do
                local edge=frame.edges[i].fill
                near(edge:GetLeft(),outline:GetLeft()+path[i][1]*scale)
                near(edge:GetTop(),outline:GetTop()+path[i][2]*scale)
                local a=edge.anchors[2]
                near(a[4]*scale,path[i+1][1]*scale)
                near(a[5]*scale,path[i+1][2]*scale)
            end
        end
    end
end
skin.art.w,skin.art.h=91,85
O.UpdateUltimateCharge(skin)
near(skin.chargeFront.width,91); near(skin.chargeFront.height,85)
skin.art.w=0
O.UpdateUltimateCharge(skin)
assert(skin.chargeFront.root.hidden and not skin.chargeBack.root.hidden)
skin.art.w=91
O.UpdateUltimateCharge(skin)
assert(not skin.chargeFront.root.hidden)
print("PASS: charge line screen bounds match frame artwork across inherited scales, swaps, resize and zero geometry")
