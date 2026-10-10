local TOOLTIP_TEXT_COLOR = "#c4c19d"
local tooltip = nil

function AUI.ShowTooltip(_text)
	if not tooltip then
		tooltip = WINDOW_MANAGER:CreateTopLevelWindow("AUI_Tooltip")		
		tooltip:SetClampedToScreen(true) 
		tooltip:SetDrawTier(DT_HIGH)			
		tooltip:SetDrawLayer(4)	
		tooltip:SetMouseEnabled(true)	
	
		tooltip.Border = WINDOW_MANAGER:CreateControl("AUI_Tooltip_Border", tooltip, CT_BACKDROP)
		tooltip.Border:SetClampedToScreen(true) 
		tooltip.Border:SetAnchor(TOPLEFT, tooltip, TOPLEFT, 0, 0)
		tooltip.Border:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 64, 8) 				
		tooltip.Border:SetCenterColor(0, 0, 0, 1) 	
	
		tooltip.Text = WINDOW_MANAGER:CreateControl(nil, tooltip.Border, CT_LABEL)
		tooltip.Text:SetColor(AUI.Color.ConvertHexToRGBA(TOOLTIP_TEXT_COLOR, 1.0):UnpackRGBA())	
		tooltip.Text:SetFont("ZoFontGame")
		tooltip.Text:SetAnchor(CENTER, tooltip.Border, CENTER, 0, 0)		
		tooltip.Text:SetHorizontalAlignment(TEXT_ALIGN_CENTER ) 	
		tooltip.Text:SetVerticalAlignment(TEXT_ALIGN_CENTER ) 	
	end

	tooltip.Text:SetText(_text)
	
	tooltip.Border:SetDimensions(tooltip.Text:GetWidth() + 20, tooltip.Text:GetHeight() + 10) 
	
	local x, y = GetUIMousePosition()
	tooltip:SetAnchor(TOPLEFT, GUIROOT, TOPLEFT, x + 24, y)
	
	tooltip:SetHidden(false)
end

function AUI.HideTooltip()
	if tooltip then
		tooltip:SetHidden(true)
	end
end