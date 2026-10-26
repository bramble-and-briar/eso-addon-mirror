local O=ObsidianHUD
local HALF=0.2 -- Match the two 200ms phases of ESO's HotbarSwapAnimation.

function O.SetPreviewTexture(skin,texture)
    if skin.previewTexture~=texture then
        skin.previewPreviousTexture=skin.previewTexture
        skin.previewTexture=texture
    end
    local collapsing=skin.previewSwapAt and GetFrameTimeSeconds()-skin.previewSwapAt<HALF
    skin.backIcon:SetTexture(collapsing and skin.previewPreviousTexture or texture)
end

function O.StopPreviewSwap(skin)
    if not skin.previewSwapAt then return end
    skin.previewSwapAt=nil
    skin.back:SetDimensions(skin.previewWidth,skin.previewHeight)
    skin.back:SetAlpha(1)
    skin.timer:SetAlpha(1); skin.backStacks:SetAlpha(1)
    if skin.previewTexture then skin.backIcon:SetTexture(skin.previewTexture) end
end

function O.UpdatePreviewSwap(skin)
    if not skin.previewSwapAt then return end
    local elapsed=math.max(0,GetFrameTimeSeconds()-skin.previewSwapAt)
    if not skin.timerVisible or elapsed>=HALF*2 then O.StopPreviewSwap(skin); return end
    local first=elapsed<HALF
    local p=first and elapsed/HALF or (elapsed-HALF)/HALF
    local amount=first and (1-p*p) or (1-(1-p)*(1-p))
    -- Keep a positive aperture for inset icon anchors at the midpoint.
    local minimum=math.min(12,skin.previewHeight)
    skin.back:SetDimensions(skin.previewWidth,minimum+(skin.previewHeight-minimum)*amount)
    skin.back:SetAlpha(amount)
    skin.timer:SetAlpha(first and 0 or 1)
    skin.backStacks:SetAlpha(first and 0 or 1)
    skin.backIcon:SetTexture(first and (skin.previewPreviousTexture or skin.previewTexture) or skin.previewTexture)
end

function O.StartPreviewSwap(skin,now)
    O.StopPreviewSwap(skin)
    if not skin.timerVisible then return end
    skin.previewSwapAt=now
    O.UpdatePreviewSwap(skin)
end
