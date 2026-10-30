CENTER,TOPLEFT,BOTTOM=1,2,3
HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP,HOTBAR_CATEGORY_QUICKSLOT_WHEEL=1,2,3
local active,gamepad,clock,sx,sy=1,false,0,0,0
GuiRoot={GetWidth=function() return 1920 end,GetHeight=function() return 1080 end}
local function near(a,b) assert(math.abs(a-b)<0.001,tostring(a).." ~= "..tostring(b)) end
local function control(x,y,w,h,scale)
    local c={x=x,y=y,w=w,h=h,scale=scale or 1}
    function c:GetLeft() return self.x-self.w*self.scale/2 end
    function c:GetTop() return self.y-self.h*self.scale/2 end
    function c:GetRight() return self.x+self.w*self.scale/2 end
    function c:GetBottom() return self.y+self.h*self.scale/2 end
    function c:GetWidth() return self.w end
    function c:GetHeight() return self.h end
    function c:GetNumAnchors() return self.a and 1 or 0 end
    function c:GetAnchor() if self.a then return true,unpack(self.a,1,5) end; return false end
    function c:ClearAnchors() self.a=nil end
    function c:SetAnchor(p,r,rp,dx,dy)
        self.a={p,r,rp,dx,dy}
        if p==CENTER then self.x,self.y=dx*self.scale,dy*self.scale
        else self.x,self.y=dx+self.w/2,dy+self.h/2 end
    end
    function c:SetDimensions(w,h)
        local x,y=self:GetLeft(),self:GetTop()
        self.w,self.h=w,h; self.x,self.y=x+w/2,y+h/2
    end
    function c:SetHidden() end
    function c:SetMouseEnabled() end
    function c:SetText() end
    function c:StopMovingOrResizing() end
    c.a={CENTER,GuiRoot,TOPLEFT,x/c.scale,y/c.scale}
    return c
end
function GetActiveHotbarCategory() return active end
function IsInGamepadPreferredMode() return gamepad end
function GetFrameTimeSeconds() return clock end
function GetGamepadRightStickX() return sx end
function GetGamepadRightStickY() return sy end
function d(message) error(message) end
EVENT_MANAGER={RegisterForUpdate=function() end,UnregisterForUpdate=function() end}
for _,view in ipairs({"fixed","fixed_dual","fixed_static","fixed_dual_static"}) do
    for _,factor in ipairs({1,1.5}) do
        for _,controller in ipairs({false,true}) do
            active,gamepad,clock,sx,sy=1,controller,0,0,0
            ObsidianHUD={name="ObsidianHUD",vars={enabled=true,backBar=true,skillHudView=view,hudPositions={}},skillHudFactor=factor}
            local O=ObsidianHUD
            local buttons={}
            for i=1,8 do buttons[i]={slot=control(400+i*80,700,64,64,factor)} end
            function ZO_ActionBar_GetButton(slot) return buttons[slot] end
            O.nativeMoveHandle=control(0,0,1,1)
            O.nativeMoveLabel=control(0,0,1,1); O.moveHint=control(0,0,1,1); O.moveOverlay=control(0,0,1,1)
            dofile("NativeMove.lua"); O.Tick=O.UpdateNativePositions
            local mode=gamepad and "controller" or "keyboard"
            O.vars.hudPositions[mode]={skills={x=0.3,y=0.65},ultimate={x=0.7,y=0.4},quickslot={x=0.1,y=0.55}}
            local keys={skills=3,ultimate=8,quickslot=1}
            local function check()
                local p=O.vars.hudPositions[mode]
                for key,slot in pairs(keys) do
                    near(buttons[slot].slot.x,p[key].x*1920)
                    near(buttons[slot].slot.y,p[key].y*1080+O.NativeHudOffset(key))
                end
                for slot=4,7 do near(buttons[slot].slot.y,buttons[3].slot.y) end
            end
            O.UpdateNativePositions(); check()
            for _,key in ipairs({"skills","quickslot","ultimate"}) do
                local before={}
                for other,slot in pairs(keys) do before[other]={buttons[slot].slot.x,buttons[slot].slot.y} end
                O.StartNativeMove(key)
                for other,slot in pairs(keys) do near(buttons[slot].slot.x,before[other][1]); near(buttons[slot].slot.y,before[other][2]) end
                sx,sy=1,1; O.NativeMoveUpdate(); sx,sy=0,0
                near(buttons[keys[key]].slot.x,before[key][1]+22)
                near(buttons[keys[key]].slot.y,before[key][2]-22)
                for other,slot in pairs(keys) do
                    if other~=key then near(buttons[slot].slot.x,before[other][1]); near(buttons[slot].slot.y,before[other][2]) end
                end
                O.StopNativeMove(); check()
                for i=1,6 do active=i%2+1; O.UpdateNativePositions(); check() end
            end
            assert(O.vars.hudPositions[gamepad and "keyboard" or "controller"]==nil,"profiles remain separate")
            local before={}
            for key,slot in pairs(keys) do before[key]={buttons[slot].slot.x,buttons[slot].slot.y} end
            O.vars.x,O.vars.y=77,-222
            local p=O.vars.hudPositions[mode]
            p.buffs={x=0.2,y=0.25}; p.synergy={x=0.5,y=0.7}
            local buffs,synergy=p.buffs,p.synergy
            O.StartNativeMove("skillgroup")
            for key,slot in pairs(keys) do near(buttons[slot].slot.x,before[key][1]); near(buttons[slot].slot.y,before[key][2]) end
            for i=1,3 do sx,sy=1,1; O.NativeMoveUpdate() end
            sx,sy=0,0
            for key,slot in pairs(keys) do near(buttons[slot].slot.x,before[key][1]+66); near(buttons[slot].slot.y,before[key][2]-66) end
            O.StopNativeMove(); check()
            for i=1,6 do active=i%2+1; O.UpdateNativePositions(); check() end
            assert(O.vars.x==77 and O.vars.y==-222 and p.buffs==buffs and p.synergy==synergy,
                "group movement excludes resources, buffs and synergy")
            -- Moving just the potion afterwards must remain independent.
            local skillX,skillY=buttons[3].slot.x,buttons[3].slot.y
            local ultX,ultY=buttons[8].slot.x,buttons[8].slot.y
            O.StartNativeMove("quickslot"); sx=1; O.NativeMoveUpdate(); sx=0; O.StopNativeMove()
            near(buttons[3].slot.x,skillX); near(buttons[3].slot.y,skillY)
            near(buttons[8].slot.x,ultX); near(buttons[8].slot.y,ultY)
        end
    end
end
print("PASS: independent skill/potion/ultimate movement, distinct heights, stable start/stop, scale and weapon swaps in both input profiles")
