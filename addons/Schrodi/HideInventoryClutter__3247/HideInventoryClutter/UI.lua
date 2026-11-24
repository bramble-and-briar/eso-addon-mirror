local HIC = HideInventoryClutter

function HIC.initializeUI()
	HideInventoryClutter_LockedButton:SetAlpha(0.3)
	HideInventoryClutter_LockedButton:ClearAnchors()
	if HIC.savedVariables.positionLocked.top == nil and HIC.savedVariables.positionLocked.left == nil then
		HideInventoryClutter_LockedButton:SetAnchor(TOPLEFT, ZO_PlayerInventoryInfoBar, TOPLEFT, 282, 9)
	else
		HideInventoryClutter_LockedButton:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 
			HIC.savedVariables.positionLocked.left, HIC.savedVariables.positionLocked.top)
	end

	HideInventoryClutter_ConsumablesButton:SetAlpha(0.3)
	HideInventoryClutter_ConsumablesButton:ClearAnchors()
	if HIC.savedVariables.positionConsumable.top == nil and HIC.savedVariables.positionConsumable.left == nil then
		HideInventoryClutter_ConsumablesButton:SetAnchor(TOPLEFT, ZO_PlayerInventoryInfoBar, TOPLEFT, 300, 0)
	else
		HideInventoryClutter_ConsumablesButton:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 
		HIC.savedVariables.positionConsumable.left, HIC.savedVariables.positionConsumable.top)
	end
end

function HIC.getTooltipTextConsumables()
	if HIC.lastActiveMenu == LF_SMITHING_DECONSTRUCT 
	or HIC.lastActiveMenu == LF_JEWELRY_DECONSTRUCT 
	or HIC.lastActiveMenu == LF_ENCHANTING_EXTRACTION
	or HIC.lastActiveMenu == LF_RETRAIT then
		return "This filter doesn't affect this menu"
	end

	return "Consumables " .. (HIC.consumablesVisible and "visible" or "hidden")
end

function HIC.getTooltipTextLocked()
	if HIC.lastActiveMenu == LF_INVENTORY 
	or HIC.lastActiveMenu == LF_BANK_DEPOSIT 
	or HIC.lastActiveMenu == LF_HOUSE_BANK_DEPOSIT
	or HIC.lastActiveMenu == LF_RETRAIT then
		return "Locked items " .. (HIC.lockedVisible and "visible" or "hidden")
	elseif HIC.lastActiveMenu == LF_VENDOR_SELL then
		return "Items not worth selling " .. (HIC.lockedVisible and "visible" or "hidden")
	elseif HIC.lastActiveMenu == LF_SMITHING_DECONSTRUCT or HIC.lastActiveMenu == LF_JEWELRY_DECONSTRUCT or HIC.lastActiveMenu == LF_ENCHANTING_EXTRACTION then
		return "Items not worth deconstructing " .. (HIC.lockedVisible and "visible" or "hidden")
	end
end

function HIC.showButtons()
	HIC.buttonsVisible = true
	HideInventoryClutter_ConsumablesButton:SetHidden(false)
	HideInventoryClutter_LockedButton:SetHidden(false)
	HIC.dbg("buttons visible: " .. tostring(HIC.buttonsVisible))
end

function HIC.hideButtons()
	HIC.buttonsVisible = false
	HideInventoryClutter_ConsumablesButton:SetHidden(true)
	HideInventoryClutter_LockedButton:SetHidden(true)
	HIC.dbg("buttons visible: " .. tostring(HIC.buttonsVisible))
end