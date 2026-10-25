local O=ObsidianHUD
local ATLAS="ObsidianHUD/art/class_emblems.dds"
-- Class IDs are not enumeration indices (Arcanist is 117).
O.classEmblems={ [1]=0,[2]=1,[3]=2,[6]=3,[4]=4,[5]=5,[117]=6 }

function O.ClassEmblemsReady()
    local asset=ObsidianHUDAssetsClasses
    if not asset or not asset:IsTextureLoaded() then return false end
    local w,h=asset:GetTextureFileDimensions()
    return w==1024 and h==512
end

function O.UpdateClassIcon()
    if not O.classIcon then return end
    local classId=GetUnitClassId and GetUnitClassId("player")
    local tile=O.classEmblems[classId]
    local custom=O.vars.customClassIcons and tile~=nil and O.ClassEmblemsReady()
    local texture=custom and ATLAS or O.GetClassTexture()
    O.classIcon:SetHidden(not texture)
    if not texture then return end
    O.classIcon:SetTexture(texture)
    if custom then
        local x,y=tile%4,math.floor(tile/4)
        O.classIcon:SetTextureCoords(x/4,(x+1)/4,y/2,(y+1)/2)
        O.classIcon:SetDimensions(O.vars.roundBadge and 77 or 48,O.vars.roundBadge and 77 or 48)
    else
        O.classIcon:SetTextureCoords(0,1,0,1)
        O.classIcon:SetDimensions(41,41)
    end
    O.classIcon:SetColor(1,1,1,1)
end
