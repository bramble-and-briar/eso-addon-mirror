CENTER,TOPLEFT,BOTTOM=1,2,3
HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP,HOTBAR_CATEGORY_QUICKSLOT_WHEEL=1,2,3
local width,height,active=1920,1080,1
local function near(a,b) assert(math.abs(a-b)<0.001,tostring(a).." ~= "..tostring(b)) end
local function control(x,y,w,h,scale)
    local c={cx=x,cy=y,w=w,h=h,scale=scale,units=scale}
    function c:GetLeft() return self.cx-self.w*self.scale/2 end
    function c:GetTop() return self.cy-self.h*self.scale/2 end
    function c:GetRight() return self.cx+self.w*self.scale/2 end
    function c:GetBottom() return self.cy+self.h*self.scale/2 end
    function c:GetWidth() return self.w end
    function c:GetHeight() return self.h end
    function c:GetNumAnchors() return self.anchor and (self.extraAnchor and 2 or 1) or 0 end
    function c:GetAnchor() if self.anchor then return true,unpack(self.anchor,1,5) end; return false end
    function c:ClearAnchors() self.anchor=nil; self.extraAnchor=nil end
    function c:SetAnchor(p,r,rp,x,y)
        self.anchor={p,r,rp,x,y}
        self.cx,self.cy=x*self.units,y*self.units
    end
    c.anchor={CENTER,GuiRoot,TOPLEFT,x/scale,y/scale}
    return c
end
function GetActiveHotbarCategory() return active end
function IsInGamepadPreferredMode() return false end
for _,scale in ipairs({0.75,1,1.25,1.5}) do
    width,height,active=1920,1080,1
    GuiRoot={GetWidth=function() return width end,GetHeight=function() return height end}
    ObsidianHUD={vars={enabled=true,backBar=true,skillHudView="fixed",x=123,y=-215,
        hudPositions={keyboard={skills={x=0.4,y=0.6},ultimate={x=0.7,y=0.6},quickslot={x=0.3,y=0.6},
            buffs={x=0.2,y=0.2},synergy={x=0.6,y=0.3}},
            controller={skills={x=0.5,y=0.6},buffs={x=0.1,y=0.2},synergy={x=0.5,y=0.4}}}}}
    local O=ObsidianHUD
    local buttons={}
    for slot=1,8 do buttons[slot]={slot=control(600+slot*70,700,64,64,scale)} end
    function ZO_ActionBar_GetButton(slot) return buttons[slot] end
    ZO_BuffDebuffTopLevelSelfContainer=control(500,300,100,40,1)
    SYNERGY={container=control(960,800,330,50,1)}
    dofile("NativeMove.lua")
    O.Tick=O.UpdateNativePositions
    local positions=O.vars.hudPositions.keyboard
    local baseline={}
    for _,slot in ipairs({1,3,8}) do baseline[slot]={buttons[slot].slot.cx,buttons[slot].slot.cy} end
    O.vars.hudPositions.keyboard={}
    for i=1,12 do
        active=i%2+1
        O.UpdateNativePositions()
        for _,entry in ipairs({{"skills",3},{"ultimate",8},{"quickslot",1}}) do
            local key,slot=entry[1],entry[2]
            near(buttons[slot].slot.cx,baseline[slot][1])
            near(buttons[slot].slot.cy,baseline[slot][2]+O.NativeHudOffset(key))
        end
    end
    O.vars.hudPositions.keyboard=positions
    local function check()
        for _,entry in ipairs({{"skills",3},{"ultimate",8},{"quickslot",1}}) do
            local key,slot=entry[1],entry[2]
            near(buttons[slot].slot.cx,positions[key].x*width)
            near(buttons[slot].slot.cy,positions[key].y*height+O.NativeHudOffset(key))
        end
        assert(O.vars.x==123 and O.vars.y==-215, "resource settings are untouched")
        for slot=4,7 do
            near(buttons[slot].slot.cy,buttons[3].slot.cy)
            near(buttons[slot].slot.cx-buttons[3].slot.cx,(slot-3)*70*buttons[3].slot.scale/scale)
        end
        near(SYNERGY.container.cx,positions.synergy.x*width)
        near(SYNERGY.container.cy,positions.synergy.y*height)
    end
    -- No addon scaling cache exists: this is ESO's inherited/native UI scale.
    assert(O.skillScalePositions==nil)
    for i=1,12 do
        active=i%2+1
        O.UpdateNativePositions()
        check()
    end
    -- ESO can add another anchor without replacing our matching first anchor.
    for slot=3,7 do buttons[slot].slot.extraAnchor=true end
    local buffX,buffY=SYNERGY.container.cx,SYNERGY.container.cy
    O.UpdateNativePositions(true)
    for slot=3,7 do assert(buttons[slot].slot:GetNumAnchors()==1,"native extra anchor removed") end
    near(SYNERGY.container.cx,buffX); near(SYNERGY.container.cy,buffY)
    check()
    -- Native scale can change without creating an addon-owned scale snapshot.
    for _,button in pairs(buttons) do
        button.slot.scale=scale*1.1; button.slot.units=scale*1.1
    end
    O.UpdateNativePositions()
    check()
    width,height=1600,900
    O.UpdateNativePositions()
    check()
    local buffs,synergy=positions.buffs,positions.synergy
    local controllerBuffs=O.vars.hudPositions.controller.buffs
    O.skillScalePositions={skills={x=0.99,y=0.99}}
    O.ResetSkillPositions()
    assert(not positions.skills and not positions.ultimate and not positions.quickslot)
    assert(not O.vars.hudPositions.controller.skills and O.skillScalePositions==nil)
    assert(positions.buffs==buffs and positions.synergy==synergy
        and O.vars.hudPositions.controller.buffs==controllerBuffs,
        "selective reset preserves every unrelated saved position")
    assert(O.vars.x==123 and O.vars.y==-215)
    O.skillScalePositions={skills={x=0.99,y=0.99},ultimate={x=0.95,y=0.99}}
    O.ResetNativePositions()
    assert(O.skillScalePositions==nil,"full position reset must discard the scaling snapshot too")
    for _,profile in pairs(O.vars.hudPositions) do assert(next(profile)==nil) end
    near(buttons[3].slot.cx,baseline[3][1]*1.1)
    assert(O.vars.x==123 and O.vars.y==-215,"native-only reset preserves resource layout")
end
print("PASS: native UI scale, repeated front/back layout, scale/resolution invalidation and skill-only reset")
