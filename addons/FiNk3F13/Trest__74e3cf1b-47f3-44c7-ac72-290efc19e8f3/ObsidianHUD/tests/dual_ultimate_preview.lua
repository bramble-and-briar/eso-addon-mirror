CENTER,TOPLEFT,BOTTOM,TOP,BOTTOMRIGHT=1,2,3,4,5
HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP,HOTBAR_CATEGORY_QUICKSLOT_WHEEL=1,2,3
local active=1
local ids={[1]=101,[2]=202}
local function near(a,b) assert(math.abs(a-b)<0.001,tostring(a).." ~= "..tostring(b)) end
GuiRoot={GetWidth=function() return 1920 end,GetHeight=function() return 1080 end}
local function control(x,y,w,h)
    local c={x=x or 0,y=y or 0,w=w or 64,h=h or 64,alpha=1}
    function c:GetWidth()
        local a,b=self.corners and self.corners[TOPLEFT],self.corners and self.corners[BOTTOMRIGHT]
        if a and b then return b[2]:GetRight()+b[4]-a[2]:GetLeft()-a[4] end
        return self.w
    end
    function c:GetHeight()
        local a,b=self.corners and self.corners[TOPLEFT],self.corners and self.corners[BOTTOMRIGHT]
        if a and b then return b[2]:GetBottom()+b[5]-a[2]:GetTop()-a[5] end
        return self.h
    end
    function c:center()
        local tl,br=self.corners and self.corners[TOPLEFT],self.corners and self.corners[BOTTOMRIGHT]
        if tl and br then
            return (tl[2]:GetLeft()+tl[4]+br[2]:GetRight()+br[4])/2,
                (tl[2]:GetTop()+tl[5]+br[2]:GetBottom()+br[5])/2
        end
        local a=self.anchor
        if not a then return self.x,self.y end
        if a[2]==GuiRoot then return a[4],a[5] end
        local rx,ry=a[2]:center()
        return rx+a[4],ry+a[5]
    end
    function c:GetLeft() local x=self:center(); return x-self:GetWidth()/2 end
    function c:GetTop() local _,y=self:center(); return y-self:GetHeight()/2 end
    function c:GetRight() return self:GetLeft()+self:GetWidth() end
    function c:GetBottom() return self:GetTop()+self:GetHeight() end
    function c:GetNumAnchors() return self.anchor and 1 or 0 end
    function c:GetAnchor() if self.anchor then return true,unpack(self.anchor) end; return false end
    function c:ClearAnchors() self.anchor=nil; self.corners=nil end
    function c:SetAnchor(...)
        self.anchor={...}
        self.corners=self.corners or {}; self.corners[self.anchor[1]]=self.anchor
    end
    function c:SetDimensions(w,h) self.w,self.h=w,h end
    function c:SetHidden(v) self.hidden=v end
    function c:SetAlpha(v) self.alpha=v end
    function c:SetText(v) self.text=v end
    function c:SetDesaturation() end
    function c:SetColor() end
    function c:SetTexture(v) self.texture=v end
    return c
end
function IsInGamepadPreferredMode() return true end
function GetActiveHotbarCategory() return active end
function GetSlotBoundId(slot,bar) return slot==8 and ids[bar] or 0 end
function GetSlotTexture(slot,bar) return bar==1 and "native101.dds" or nil end
function GetAbilityIcon(id) return "ability"..id..".dds" end
for _,view in ipairs({"fixed_dual","fixed_dual_static"}) do
    ObsidianHUD={vars={enabled=true,backBar=true,skillHudView=view,
        hudPositions={controller={skills={x=0.4,y=0.6},ultimate={x=0.8,y=0.6},quickslot={x=0.2,y=0.6}}}}}
    local O=ObsidianHUD
    function O.OtherBar(bar) return bar==1 and 2 or bar==2 and 1 end
    local buttons={}
    for slot=1,8 do buttons[slot]={slot=control(500+slot*70,650,slot==8 and 70 or 64,slot==8 and 70 or 64)} end
    function ZO_ActionBar_GetButton(slot) return buttons[slot] end
    dofile("UI.lua"); dofile("NativeMove.lua"); dofile("Native.lua"); dofile("PreviewSwap.lua")
    function O.BackBarTimerText() return "" end
    function O.UpdateStackText() end
    function O.UpdateSkillProcHighlight() end
    function O.StopSkillProcHighlight() end
    local s={button=buttons[8],activeTextSlot=8,back=control(),backIcon=control(),
        timer=control(),backStacks=control(),backMetal=control()}
    s.back.edges={}
    local frontY,backY
    for i=1,20 do
        active=i%2+1
        -- Before ESO's midpoint callback the native slot still contains the
        -- previous weapon's icon/category. It must retain that row as well.
        for _,b in pairs(buttons) do b.slot.hotbarCategory=O.OtherBar(active) end
        O.UpdateSkillPreview(s,8,active,true)
        O.UpdateNativePositions()
        local display=O.SkillDisplayBar(s.button)
        local _,oldY=s.button.slot:center()
        local _,oldPreviewY=s.back:center()
        local fy=display==1 and oldY or oldPreviewY
        local by=display==2 and oldY or oldPreviewY
        if frontY then near(fy,frontY); near(by,backY) else frontY,backY=fy,by end
        assert(s.timerBar==O.OtherBar(display))
        assert(s.backIcon.texture==(display==1 and "ability202.dds" or "native101.dds"))
        for _,b in pairs(buttons) do b.slot.hotbarCategory=active end
        -- A stale faded preview must not disappear in either fixed mode.
        s.back:SetAlpha(0)
        O.UpdateSkillPreview(s,8,active,true)
        O.UpdateNativePositions()
        assert(not s.back.hidden and s.back.alpha==1 and s.timerVisible,
            "both equipped ultimates remain visible despite missing native inactive texture")
        assert(s.timerBar==O.OtherBar(active))
        assert(s.backIcon.texture==(active==1 and "ability202.dds" or "native101.dds"))
        local _,nativeY=s.button.slot:center()
        local _,previewY=s.back:center()
        local fy=active==1 and nativeY or previewY
        local by=active==2 and nativeY or previewY
        if frontY then near(fy,frontY); near(by,backY) else frontY,backY=fy,by end
        assert(fy<by,"front ultimate stays above back ultimate")
    end
    ids[2]=0; active=1
    for _,b in pairs(buttons) do b.slot.hotbarCategory=active end
    O.UpdateSkillPreview(s,8,active,true)
    assert(s.back.hidden and not s.timerVisible,"empty ultimate cannot acquire a fallback icon")
    active=2
    for _,b in pairs(buttons) do b.slot.hotbarCategory=active end
    O.UpdateSkillPreview(s,8,active,true)
    assert(not s.back.hidden,"equipped front ultimate stays visible with empty active back slot")
    ids[2]=202
    O.UpdateSkillPreview(s,8,active,false)
    assert(s.back.hidden,"HUD scene visibility remains respected")
    -- Exercise the production tick as well as the preview helper: later
    -- decoration/native-back-bar suppression must not hide our second icon.
    O.vars.skillFrames=true
    s.frame=control(); s.frame.edges={}; s.art=control()
    s.art:SetAnchor(CENTER,s.button.slot,CENTER,0,0)
    s.activeTimer=control(); s.textRoot=control()
    s.button.icon=control()
    function s.button.slot:GetNamedChild() return nil end
    function O.CreateSkillSkin() return s end
    function O.StyleSkillText() end
    function O.UpdateActiveSkillText() end
    function O.UpdateUltimateCharge() end
    function O.UpdateBarIndicator() end
    O.vars.skillFrameColor={1,1,1}
    for i=1,10 do
        active=i%2+1
        for _,b in pairs(buttons) do b.slot.hotbarCategory=active end
        O.UpdateSkills(true)
        O.UpdateNativePositions()
        assert(not s.back.hidden and s.timerVisible and s.activeTextBar==active)
        local _,nativeY=s.button.slot:center()
        local _,previewY=s.back:center()
        near(active==1 and nativeY or previewY,frontY)
        near(active==2 and nativeY or previewY,backY)
    end
end
print("PASS: dual ultimate icons, missing slot texture fallback, fixed weapon identity across swaps and empty slots")
