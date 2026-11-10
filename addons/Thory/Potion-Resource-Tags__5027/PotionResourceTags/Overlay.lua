local PRT = PotionResourceTags
PRT.Overlay = {}
local Overlay = PRT.Overlay

function Overlay.Clear(icon)
    local label = icon and icon.PotionResourceTagsLabel
    if label then
        label:SetText("")
        label:SetHidden(true)
    end
end

function Overlay.Update(icon, link, gamepadHUD)
    if not icon then
        return
    end
    -- Always clear on reuse, including empty slots and non-quickslot wheels.
    Overlay.Clear(icon)
    local marker = PRT.Classifier.Classify(link)
    if not marker then
        return
    end
    local label = icon.PotionResourceTagsLabel
    if not label then
        -- Sibling of the texture: its cooldown cropping/desaturation must not
        -- change the text. The row/slot parent still controls visibility.
        label = WINDOW_MANAGER:CreateControl("", icon:GetParent(), CT_LABEL)
        icon.PotionResourceTagsLabel = label
        label:SetMouseEnabled(false)
        label:SetDrawTier(DT_HIGH)
        label:SetDrawLayer(DL_OVERLAY)
        label:SetDrawLevel(10)
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        label:SetVerticalAlignment(TEXT_ALIGN_TOP)
        label:SetColor(1, 1, 1, 1)
    end
    label:ClearAnchors()
    label:SetAnchor(TOPLEFT, icon, TOPLEFT, 1, -2)
    label:SetDimensions(gamepadHUD and 30 or 22, gamepadHUD and 32 or 24)
    label:SetFont(gamepadHUD and "ZoFontGamepadBold27" or "ZoFontGameOutline")
    label:SetText(marker)
    label:SetHidden(false)
end
