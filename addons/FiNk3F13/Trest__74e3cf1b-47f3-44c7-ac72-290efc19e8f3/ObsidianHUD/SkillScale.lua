local O=ObsidianHUD
local owner,base,applied,profile

local function release()
    if owner and applied and math.abs(owner:GetScale()-applied)<0.0001 then
        owner:SetScale(base)
    end
    owner,base,applied,profile=nil,nil,nil,nil
    O.skillScalePositions=nil
    O.skillScaleDimensions=nil
    O.skillHudFactor=nil
end

function O.UpdateSkillScale()
    local root=ZO_ActionBar1
    local mode=IsInGamepadPreferredMode and IsInGamepadPreferredMode() and "controller" or "keyboard"
    if owner and (owner~=root or profile~=mode) then
        O.ReleaseNativePositions()
        release()
    end
    if not root then return end
    local size=math.max(1,math.min(1.5,tonumber(O.vars.skillHudScale) or 1))
    local factor=O.vars.enabled and size or 1
    local current=root:GetScale()
    if type(current)~="number" or current<=0 then return end
    if factor==1 then
        if owner then O.ReleaseNativePositions(); release() end
        return
    end
    if not owner then owner,base,profile=root,current,mode end
    -- ESO may reset its native scale when switching keyboard/controller UI.
    -- Use that new baseline; never multiply our previous result again.
    if applied and math.abs(current-applied)>0.0001 then base=current end
    local wanted=base*factor
    if math.abs(current-wanted)>0.0001 then
        if not O.skillScalePositions and O.CaptureSkillScalePositions then
            O.skillScalePositions=O.CaptureSkillScalePositions()
        end
        if not O.skillScaleDimensions and O.CaptureSkillScaleDimensions then
            O.skillScaleDimensions=O.CaptureSkillScaleDimensions()
        end
        O.ReleaseNativePositions()
        root:SetScale(wanted)
    end
    O.skillHudFactor=factor
    applied=wanted
end
