CT_TEXTURE,DL_OVERLAY,DT_HIGH=1,2,3
TOPLEFT,BOTTOMRIGHT,RIGHT,LEFT,CENTER=1,2,3,4,5
HOTBAR_CATEGORY_QUICKSLOT_WHEEL=9
local created={}
local function control(parent)
    local c={parent=parent,alpha=1,anchors={}}
    function c:SetHidden(v) self.hidden=v end
    function c:IsHidden() return self.hidden or (self.parent and self.parent:IsHidden()) or false end
    function c:SetAlpha(v) self.alpha=v end
    function c:GetAlpha() return self.alpha end
    function c:SetInheritAlpha(v) self.inheritAlpha=v end
    function c:SetAnchor(...) self.anchors[#self.anchors+1]={...} end
    function c:SetTexture(v) self.texture=v end
    function c:SetColor(...) self.color={...} end
    function c:GetParent() return self.parent end
    function c:SetDimensions(w,h) self.width,self.height=w,h end
    function c:GetNamedChild(name) return self[name] end
    for _,name in ipairs({"SetDrawLayer","SetDrawLevel","SetDrawTier","SetMouseEnabled"}) do
        c[name]=function() end
    end
    return c
end
WINDOW_MANAGER={CreateControl=function(_,_,parent)
    local c=control(parent); created[#created+1]=c; return c
end}
ObsidianHUD={vars={enabled=true,quickslotFrame=true,skillFrameColor={1,0.2,1}}}
local O=ObsidianHUD
dofile("UI.lua"); dofile("Native.lua")
function O.Frame(parent)
    local c=control(parent); c.background=control(c); c.edges={control(c),control(c)}; return c
end
ZO_ActionBar1=control()
local slot=control(ZO_ActionBar1)
slot.Backdrop=control(slot)
local icon=control(slot); icon:SetHidden(true)
local button={slot=slot,icon=icon}
function ZO_ActionBar_GetButton(index,bar)
    assert(index==1 and bar==HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    return button
end
ObsidianHUDAssetsFantasySlot={IsTextureLoaded=function() return true end}
O.UpdateQuickslot(true)
local art=created[1]
assert(art.texture=="ObsidianHUD/art/fantasy_slot.dds")
assert(art.parent.parent==slot and art.parent.parent~=icon)
assert(not art:IsHidden() and icon:IsHidden(),"empty native icon does not hide the custom potion frame")
assert(slot.Backdrop:GetAlpha()==0 and art.color[3]==1)
O.UpdateQuickslot(false)
assert(art:IsHidden() and slot.Backdrop:GetAlpha()==1,"HUD visibility and native backing restore")
icon:SetHidden(false)
O.UpdateQuickslot(true)
assert(not art:IsHidden() and #created==1,"equipping an item reuses the same frame")
local skill={slot=control(ZO_ActionBar1)}
O.UpdateBarIndicator(skill,1,true)
assert(O.barIndicator.parent==ZO_ActionBar1 and O.barIndicator.anchors[1][2]==skill.slot)
assert(O.barIndicator.color[2]==1 and O.barIndicator.inheritAlpha==false)
skill.slot:SetHidden(true); skill.slot:SetAlpha(0)
assert(not O.barIndicator:IsHidden(),"native slot visibility cannot swallow the green arrow")
O.barIndicator:SetAlpha(0)
O.UpdateBarIndicator(skill,2,true)
assert(O.barIndicator:GetAlpha()==1 and not O.barIndicator:IsHidden())
O.UpdateBarIndicator(skill,2,false)
assert(O.barIndicator:IsHidden(),"arrow still follows explicit HUD visibility")
print("PASS: potion frame with empty/filled slot, native art restore, bright independent arrow and HUD visibility")
