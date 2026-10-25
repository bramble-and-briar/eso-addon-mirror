TOPLEFT,CENTER,TOP,BOTTOM,LEFT,RIGHT=1,2,3,4,5,6
DT_HIGH,DL_OVERLAY,CT_BACKDROP=3,4,5
MOUSE_BUTTON_INDEX_LEFT=1
HOTBAR_CATEGORY_QUICKSLOT_WHEEL=9
local gamepad,clock,sx,sy=false,0,0,0
local ui,camera=false,false
local updates={}
local factors={[TOPLEFT]={0,0},[CENTER]={0.5,0.5},[TOP]={0.5,0},[BOTTOM]={0.5,1},[LEFT]={0,0.5},[RIGHT]={1,0.5}}
local function control(w,h)
    local c={width=w or 0,height=h or 0,anchors={},handlers={}}
    function c:GetWidth() return self.width end
    function c:GetHeight() return self.height end
    function c:SetDimensions(x,y) self.width,self.height=x,y end
    function c:SetAnchor(point,rel,rp,x,y) self.anchors[#self.anchors+1]={point,rel,rp,x or 0,y or 0} end
    function c:ClearAnchors() self.anchors={} end
    function c:GetNumAnchors() return #self.anchors end
    function c:GetAnchor(i)
        local a=self.anchors[i+1]
        if not a then return false end
        return true,unpack(a,1,5)
    end
    function c:GetLeft()
        if self==GuiRoot then return 0 end
        local a=self.anchors[1]; local rel=a[2] or GuiRoot
        return rel:GetLeft()+rel:GetWidth()*factors[a[3]][1]+a[4]-self.width*factors[a[1]][1]
    end
    function c:GetTop()
        if self==GuiRoot then return 0 end
        local a=self.anchors[1]; local rel=a[2] or GuiRoot
        return rel:GetTop()+rel:GetHeight()*factors[a[3]][2]+a[5]-self.height*factors[a[1]][2]
    end
    function c:SetHandler(name,fn) self.handlers[name]=fn end
    return setmetatable(c,{__index=function(_,key) return function(self,...) self[key.."Args"]={...} end end})
end
GuiRoot=control(1920,1080)
local buttons={}
for slot=3,7 do
    local c=control(60,60)
    if slot==3 then c:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,500,900)
    else c:SetAnchor(TOPLEFT,buttons[3].slot,TOPLEFT,(slot-3)*65,0) end
    buttons[slot]={slot=c}
end
buttons[8]={slot=control(70,70)}
buttons[8].slot:SetAnchor(TOPLEFT,buttons[7].slot,TOPLEFT,75,0)
local quick=control(60,60); quick:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,350,900)
ZO_BuffDebuffTopLevelSelfContainer=control(0,40)
ZO_BuffDebuffTopLevelSelfContainer:SetAnchor(CENTER,GuiRoot,TOPLEFT,960,780)
function ZO_ActionBar_GetButton(slot,bar)
    if bar==HOTBAR_CATEGORY_QUICKSLOT_WHEEL and slot==1 then return {slot=quick} end
    return buttons[slot]
end
function IsInGamepadPreferredMode() return gamepad end
function GetFrameTimeSeconds() return clock end
function GetGamepadRightStickX() return sx end
function GetGamepadRightStickY() return sy end
function IsGameCameraUIModeActive() return camera end
function SetGameCameraUIMode(value) camera=value end
SCENE_MANAGER={IsInUIMode=function() return ui end,SetInUIMode=function(_,value) ui=value end}
EVENT_MANAGER={RegisterForUpdate=function(_,name,_,fn) updates[name]=fn end,
    UnregisterForUpdate=function(_,name) updates[name]=nil end}
WINDOW_MANAGER={CreateTopLevelWindow=function() return control() end,CreateControl=function() return control() end}
local messages={}
function d(message) messages[#messages+1]=message end
ObsidianHUD={name="ObsidianHUD",vars={enabled=true,hudPositions={}},moveOverlay=control(),moveHint=control()}
local O=ObsidianHUD
function O.Label() return control() end
function O.Tick() O.UpdateNativePositions() end
local resourceStopped=false
function O.StopMove() resourceStopped=true; O.moving=false end
dofile("NativeMove.lua")
O.CreateNativeMoveUI()
local targets={skills=buttons[3].slot,ultimate=buttons[8].slot,quickslot=quick,buffs=ZO_BuffDebuffTopLevelSelfContainer}
local original={}
for key,c in pairs(targets) do original[key]={unpack(c.anchors[1],1,5)} end
local function checkAnchor(control,args)
    local current=control.anchors[1]
    for i=1,5 do assert(current[i]==args[i],"original native anchor must be restored") end
end
-- Entering/exiting without movement leaves ESO's default layout untouched.
O.StartNativeMove("skills"); assert(O.nativeMoving and ui and camera)
clock=4; O.NativeMoveUpdate()
assert(not O.nativeMoving and not ui and not camera)
assert(not O.vars.hudPositions.keyboard.skills)
checkAnchor(targets.skills,original.skills)
-- Independent controls, including the zero-width buff container, are movable.
for _,key in ipairs({"skills","ultimate","quickslot","buffs"}) do
    local c=targets[key]
    local ultimateLeft=targets.ultimate:GetLeft()
    O.StartNativeMove(key)
    sx,sy=1,1; clock=clock+1
    O.NativeMoveUpdate(); sx,sy=0,0
    if key=="skills" then assert(targets.ultimate:GetLeft()==ultimateLeft,"moving five skills must not pull the ultimate along") end
    assert(O.vars.hudPositions.keyboard[key],"movement must persist per element")
    O.StopNativeMove()
    local pos=O.vars.hudPositions.keyboard[key]
    assert(math.abs(c:GetLeft()+c:GetWidth()/2-pos.x*1920)<0.001)
    assert(math.abs(c:GetTop()+c:GetHeight()/2-pos.y*1080)<0.001)
    assert(not rawget(c,"SetHiddenArgs") and not rawget(c,"SetAlphaArgs"),"moving must not change native scene visibility or alpha")
    assert(next(c.handlers)==nil,"native input handlers remain intact")
end
for swap=1,30 do
    for _,c in pairs(targets) do c:ClearAnchors(); c:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,20,20) end
    O.Tick()
    for key,c in pairs(targets) do
        assert(math.abs(c:GetLeft()+c:GetWidth()/2-O.vars.hudPositions.keyboard[key].x*1920)<0.001)
    end
end
GuiRoot.width,GuiRoot.height=1280,720
O.Tick()
for key,c in pairs(targets) do
    local pos=O.vars.hudPositions.keyboard[key]
    assert(math.abs(c:GetLeft()+c:GetWidth()/2-pos.x*1280)<0.001,"positions must adapt to a changed UI resolution")
end
GuiRoot.width,GuiRoot.height=1920,1080; O.Tick()
-- Resource and native move modes never run simultaneously.
O.moving=true; O.StartNativeMove("ultimate")
assert(resourceStopped and not O.moving and O.nativeMoving)
O.StartNativeMove("quickslot"); assert(O.nativeMoveLabel.SetTextArgs[1]=="Traenke / Schnellzugriff")
O.StopNativeMove()
-- Disabling restores the original relational anchors, not frozen coordinates.
O.vars.enabled=false; O.Tick()
for key,c in pairs(targets) do checkAnchor(c,original[key]) end
O.StartNativeMove("skills"); assert(not O.nativeMoving)
O.vars.enabled=true; O.Tick()
-- Controller positions are separate, and existing settings cursors stay open.
gamepad=true; O.Tick()
for key,c in pairs(targets) do checkAnchor(c,original[key]) end
ui,camera=true,true; O.StartNativeMove("buffs")
sx=1; O.NativeMoveUpdate(); sx=0; O.StopNativeMove()
assert(ui and camera and O.vars.hudPositions.controller.buffs)
assert(not O.vars.hudPositions.controller.skills)
gamepad=false; O.Tick()
assert(math.abs(targets.skills:GetLeft()+30-O.vars.hudPositions.keyboard.skills.x*1920)<0.001)
-- Do not erase an anchor installed by another owner after our last update.
quick:ClearAnchors(); quick:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,111,222)
O.vars.enabled=false; O.Tick()
assert(quick:GetLeft()==111 and quick:GetTop()==222)
O.vars.enabled=true; O.Tick()
O.ResetNativePositions()
assert(next(O.vars.hudPositions.keyboard)==nil)
O.StartNativeMove("buffs")
O.nativeMoveHandle.handlers.OnMouseDown(O.nativeMoveHandle,1)
assert(O.nativeMoving)
O.nativeMoveHandle.handlers.OnMouseUp(O.nativeMoveHandle,1)
O.StopNativeMove()
ZO_BuffDebuffTopLevelSelfContainer=nil
O.StartNativeMove("buffs"); assert(not O.nativeMoving and #messages>0)
print("Native Move UI: four targets, save/restore, 30 relayouts, separate controller profile, cursor preservation and native input passed")
