local O=ObsidianHUD
local originals={}
local function matches(control,a)
    local valid,p,r,rp,x,y=control:GetAnchor(0)
    return valid and control:GetNumAnchors()==1 and p==a[1] and r==a[2] and rp==a[3]
        and math.abs(x-a[4])<0.01 and math.abs(y-a[5])<0.01
end
local function position(control,args)
    if not control then return end
    if not originals[control] then
        local anchors={}
        for i=0,control:GetNumAnchors()-1 do
            local valid,p,r,rp,x,y=control:GetAnchor(i)
            if valid then anchors[#anchors+1]={p,r,rp,x,y} end
        end
        originals[control]={anchors=anchors}
    end
    if not matches(control,args) then control:ClearAnchors(); control:SetAnchor(unpack(args)) end
    originals[control].owned=args
end
function O.ReleaseFixedBindings()
    for control,old in pairs(originals) do
        if old.owned and matches(control,old.owned) then
            control:ClearAnchors()
            for _,args in ipairs(old.anchors) do control:SetAnchor(unpack(args)) end
        end
    end
    originals={}
end
function O.UpdateFixedSkillBindings(skin)
    if not O.FixedSkillRows() then O.ReleaseFixedBindings(); return end
    local button=skin.button
    local displayed=O.SkillDisplayBar(button)
    local down=displayed==HOTBAR_CATEGORY_PRIMARY and O.SkillRowGap(button.slot) or 0
    if skin.activeTextSlot==8 then
        if O.DualUltimateView() then
            down=displayed==HOTBAR_CATEGORY_PRIMARY and O.UltimateRowSeparation() or 0
        else
            -- A single ultimate is centred between rows. Its binding belongs
            -- just below its own outer frame, not below the lower skill row.
            down=8
        end
    end
    -- Keep native labels, glyphs, visibility and actual keybindings. Only their
    -- anchors follow the lower row or the single ultimate's own frame.
    position(button.buttonText,{TOP,button.slot,BOTTOM,0,down+2})
    position(button.leftKey,{TOPRIGHT,button.slot,BOTTOM,-2,down+2})
    position(button.rightKey,{TOPLEFT,button.slot,BOTTOM,2,down+2})
end
