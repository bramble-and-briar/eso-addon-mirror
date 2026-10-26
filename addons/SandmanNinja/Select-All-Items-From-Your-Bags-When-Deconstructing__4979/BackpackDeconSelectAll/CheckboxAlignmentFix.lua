-- Called by the main file when each keyboard checkbox is created.
local A = BackpackDeconSelectAll

function A.FixCheckbox(checkbox)
    local label = checkbox:GetNamedChild("Label")
    label:ClearAnchors()
    label:SetAnchor(LEFT, checkbox, RIGHT, 6, 0)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetWidth(480)
    label:SetHeight(48)
    local versionLabel = WINDOW_MANAGER:CreateControl(nil, checkbox:GetParent(), CT_LABEL)
    versionLabel:SetAnchor(TOPLEFT, checkbox, BOTTOMLEFT, 22, 18)
    versionLabel:SetDimensions(120, 18)
    versionLabel:SetFont("ZoFontGameSmall")
    versionLabel:SetColor(0.65, 0.65, 0.65, 1)
    versionLabel:SetText("v" .. A.version)
end
