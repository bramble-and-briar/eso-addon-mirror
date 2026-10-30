local clock,gamepad,fixed=0,false,false
local updates={}
CENTER,TOPLEFT,BOTTOM=1,2,3
HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP=1,2
ObsidianHUD={name="ObsidianHUD",vars={enabled=true,backBar=false,hudPositions={}},skillHudFactor=1}
local O=ObsidianHUD
local function control(x,y,w,h)
    local c={cx=x,cy=y,w=w,h=h,anchors={{BOTTOM,nil,BOTTOM,0,-200}},hidden=true}
    function c:GetLeft() return self.cx-self.w/2 end
    function c:GetTop() return self.cy-self.h/2 end
    function c:GetRight() return self.cx+self.w/2 end
    function c:GetBottom() return self.cy+self.h/2 end
    function c:GetWidth() return self.w end
    function c:GetHeight() return self.h end
    function c:GetNumAnchors() return #self.anchors end
    function c:GetAnchor(i) if self.anchors[i+1] then return true,unpack(self.anchors[i+1],1,5) end; return false end
    function c:ClearAnchors() self.anchors={} end
    function c:SetAnchor(p,r,rp,ax,ay)
        self.anchors={{p,r,rp,ax,ay}}
        if p==CENTER then self.cx,self.cy=ax,ay
        elseif p==TOPLEFT then self.cx,self.cy=ax+self.w/2,ay+self.h/2 end
    end
    function c:SetDimensions(width,height)
        local left,top=self:GetLeft(),self:GetTop()
        self.w,self.h=width,height; self.cx,self.cy=left+width/2,top+height/2
    end
    function c:SetHidden(value) self.hidden=value end
    function c:SetMouseEnabled(value) self.mouse=value end
    function c:SetText(value) self.text=value end
    function c:StopMovingOrResizing() end
    return c
end
GuiRoot=control(960,540,1920,1080)
ZO_SynergyTopLevel=control(960,540,1920,1080)
ZO_SynergyTopLevelContainer=control(960,820,330,50)
SYNERGY={container=ZO_SynergyTopLevelContainer}
O.nativeMoveHandle=control(0,0,1,1)
O.nativeMoveLabel=control(0,0,1,1)
O.moveHint=control(0,0,1,1)
O.moveOverlay=control(0,0,1,1)
function IsInGamepadPreferredMode() return gamepad end
function GetFrameTimeSeconds() return clock end
function GetActiveHotbarCategory() return 1 end
function d(message) error(message) end
EVENT_MANAGER={RegisterForUpdate=function(_,name,_,fn) updates[name]=fn end,
    UnregisterForUpdate=function(_,name) updates[name]=nil end}
dofile("NativeMove.lua")
O.FixedSkillRows=function() return fixed end
O.Tick=function() O.UpdateNativePositions() end
O.vars.hudPositions.keyboard={synergy={x=0.7,y=0.3}}
O.UpdateNativePositions()
assert(SYNERGY.container.cx==1344 and SYNERGY.container.cy==324)
assert(ZO_SynergyTopLevel:GetAnchor(0)==true and ZO_SynergyTopLevel.cx==960,
    "the full-screen top-level is never moved")
assert(SYNERGY.container.hidden, "moving cannot invent or activate a synergy")
fixed=true; O.skillHudFactor=1.5
O.UpdateNativePositions()
assert(SYNERGY.container.cy==324 and O.NativeHudOffset("synergy")==0,
    "fixed-bar offset and skill scale must not affect synergy")
gamepad=true
O.vars.hudPositions.controller={synergy={x=0.5,y=0.6}}
O.UpdateNativePositions()
assert(SYNERGY.container.cx==960 and SYNERGY.container.cy==648)
O.StartNativeMove("synergy")
assert(not O.nativeMoveHandle.hidden and O.nativeMoveLabel.text=="Synergie-Hinweis",
    "move preview is available with no ready synergy")
function GetGamepadRightStickX() return 1 end
function GetGamepadRightStickY() return 0 end
O.NativeMoveUpdate()
local saved=O.vars.hudPositions.controller.synergy
assert(math.abs(saved.x-(960+22)/1920)<0.000001 and math.abs(saved.y-0.6)<0.000001)
assert(O.vars.hudPositions.keyboard.synergy.x==0.7, "input modes have separate saved positions")
function GetGamepadRightStickX() return 0 end
clock=3
O.NativeMoveUpdate()
assert(not O.nativeMoving and O.nativeMoveHandle.hidden and not updates.ObsidianHUDNativeMove,
    "three-second timeout saves and exits")
O.ReleaseNativePositions()
assert(SYNERGY.container.anchors[1][1]==BOTTOM, "release restores native anchors")
SYNERGY=nil
O.UpdateNativePositions()
assert(ZO_SynergyTopLevelContainer.anchors[1][1]==CENTER, "named container fallback works")
O.ResetNativePositions()
assert(O.vars.hudPositions.keyboard==nil and next(O.vars.hudPositions.controller)==nil
    and ZO_SynergyTopLevelContainer.anchors[1][1]==BOTTOM,
    "reset clears synergy positions and restores native placement")
print("PASS: synergy container, idle preview, stick movement, timeout, mode isolation, skill independence and reset")
