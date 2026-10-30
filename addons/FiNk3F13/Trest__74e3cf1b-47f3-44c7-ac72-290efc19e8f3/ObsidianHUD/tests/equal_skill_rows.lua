TOPLEFT,BOTTOMRIGHT,CENTER,BOTTOM,TOP=1,2,3,4,5
HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP=0,1
local scale,active=1,0
local function near(a,b) assert(math.abs(a-b)<0.001,tostring(a).." ~= "..tostring(b)) end
local function control(w,h,x,y)
    local c={w=w or 0,h=h or 0,x=x or 300,y=y or 500,anchors={}}
    function c:ClearAnchors() self.anchors={} end
    function c:SetAnchor(p,r,rp,x,y) self.anchors[p]={r,rp,x,y} end
    function c:edge(p,horizontal)
        local a=self.anchors[p]
        if a then
            local r,rp,dx,dy=unpack(a)
            local edge=horizontal and (rp==BOTTOMRIGHT and r:GetRight() or r:GetLeft())
                or (rp==BOTTOMRIGHT and r:GetBottom() or r:GetTop())
            return edge+(horizontal and dx or dy)*scale
        end
    end
    function c:GetLeft() return self:edge(TOPLEFT,true) or self.x end
    function c:GetTop() return self:edge(TOPLEFT,false) or self.y end
    function c:GetRight() return self:edge(BOTTOMRIGHT,true) or self:GetLeft()+self.w*scale end
    function c:GetBottom() return self:edge(BOTTOMRIGHT,false) or self:GetTop()+self.h*scale end
    function c:GetWidth() return (self:GetRight()-self:GetLeft())/scale end
    function c:GetHeight() return (self:GetBottom()-self:GetTop())/scale end
    function c:SetDimensions(w,h) self.w,self.h=w,h end
    return c
end
function GetActiveHotbarCategory() return active end
ObsidianHUD={vars={}}
local O=ObsidianHUD
function O.IsFixedSkillView() return true end
function O.DualUltimateView() return O.vars.skillHudView=="fixed_dual" or O.vars.skillHudView=="fixed_dual_static" end
function O.SkillSlotSize(slot) return slot.w,slot.h end
function O.SkillRowGap() return 72 end
function O.UltimateRowSeparation() return 88 end
dofile("UI.lua")
for _,view in ipairs({"fixed","fixed_dual","fixed_static","fixed_dual_static"}) do
    O.vars.skillHudView=view
    for _,size in ipairs({0.885185,1,1.2,1.5}) do
        scale=size
        for slot=3,8 do
            local resting=slot==8 and 67 or 61
            local icon=control(resting,resting)
            local art=control()
            art:SetAnchor(TOPLEFT,icon,TOPLEFT,-6,-6)
            art:SetAnchor(BOTTOMRIGHT,icon,BOTTOMRIGHT,6,6)
            local s={activeTextSlot=slot,button={slot=control(resting+3,resting+3),icon=icon},
                art=art,back=control(),backIcon=control()}
            for _,bar in ipairs({0,1,0}) do
                active=bar
                for _,amount in ipairs({1,1.1,0.4,1}) do
                    icon.w,icon.h=resting*amount,resting*amount
                    O.LayoutSkillPreview(s)
                    near(s.back:GetWidth(),resting+12)
                    near(s.back:GetHeight(),resting+12)
                    near(s.backIcon:GetWidth(),resting)
                    near(s.backIcon:GetHeight(),resting)
                    near(s.back:GetLeft(),s.button.slot:GetLeft()-4.5*scale)
                    local gap=slot==8 and O.DualUltimateView() and 88 or 72
                    near(s.back:GetTop()-s.button.slot:GetTop(),((bar==0 and gap or -gap)-4.5)*scale)
                end
            end
        end
    end
end
print("PASS: other-bar preview retains equal resting size and stable position during active skill presses across views, scales and swaps")
