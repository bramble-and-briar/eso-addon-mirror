ItemSaverLite = {}

local ISL = ItemSaverLite

ISL.name = "ItemSaverLite"

local LCM = LibCustomMenu
local EM = EVENT_MANAGER

ISL.markerTextures = {}

local defaultSV = {
	savedItems = {},
	savedUniqueItems = {},
	markerTexture = "Padlock",
	markerColor = "00ff00",
	markerScale = 0.6,
	markerAnchor = 7,
	offsetX = -1,
	offsetY = 1,
	enableContextMenu = true,
}

ZO_CreateStringId("SI_ITEMSAVERLITE_SAVE", "Save")
ZO_CreateStringId("SI_ITEMSAVERLITE_UNSAVE", "Unsave")
ZO_CreateStringId("SI_BINDING_NAME_ITEMSAVERLITE_TOGGLE", "Toggle Save")

function ItemSaver_ToggleItemSave(bagId, slotIndex)
	if not bagId then
		local target = WINDOW_MANAGER:GetMouseOverControl()
		while target and target ~= GuiRoot do
			bagId, slotIndex = ISL.GetInfoFromRowControl(target)
			if bagId then break end
			target = target:GetParent()
		end
	end

	if not bagId then
		return false
	end
	return ISL.ToggleItemSave(bagId, slotIndex)
end

local LISTS = {
	ZO_PlayerInventoryList,
	ZO_PlayerBankBackpack,
	ZO_GuildBankBackpack,
	ZO_CraftBagList,
	ZO_HouseBankBackpack,
	ZO_FurnitureVaultList,
	ZO_SmithingTopLevelDeconstructionPanelInventoryBackpack,
	ZO_SmithingTopLevelImprovementPanelInventoryBackpack,
	ZO_EnchantingTopLevelInventoryBackpack,
	ZO_AlchemyTopLevelInventoryBackpack,
	ZO_VengeanceInventoryList
}

local ANCHOR_OFFSETS = {
	[TOPLEFT] = { x = 2, y = 2 },
	[TOP] = { x = 0, y = 2 },
	[TOPRIGHT] = { x = -2, y = 2 },
	[RIGHT] = { x = -2, y = 0 },
	[BOTTOMRIGHT] = { x = -2, y = -2 },
	[BOTTOM] = { x = 0, y = -2 },
	[BOTTOMLEFT] = { x = 2, y = -2 },
	[LEFT] = { x = 2, y = 0 },
	[CENTER] = { x = 0, y = 0 }
}

function ISL.IsUniqueItem(bagId, slotIndex)
	local itemType = GetItemType(bagId, slotIndex)
	return itemType == ITEMTYPE_POTION
		or itemType == ITEMTYPE_POISON
		or itemType == ITEMTYPE_ARMOR
		or itemType == ITEMTYPE_WEAPON
		or itemType == ITEMTYPE_GLYPH_ARMOR
		or itemType == ITEMTYPE_GLYPH_JEWELRY
		or itemType == ITEMTYPE_GLYPH_WEAPON
end

function ISL.GetMarkerTextureArrays()
	local paths, names, keys = {}, {}, {}
	for name in pairs(ISL.markerTextures) do
		table.insert(keys, name)
	end
	table.sort(keys)
	for i = 1, #keys do
		paths[i] = ISL.markerTextures[keys[i]]
		names[i] = keys[i]
	end
	return paths, names
end

function ISL.GetInfoFromRowControl(rowControl)
	if not rowControl then
		return
	end
	local data = rowControl.dataEntry and rowControl.dataEntry.data or rowControl
	return data.bagId or data.bag, data.slotIndex or data.index
end

function ISL.CreateMarkerControl(parent)
	local control = parent:GetNamedChild("ItemSaverLite")
	if not control then
		control = WINDOW_MANAGER:CreateControl(parent:GetName() .. "ItemSaverLite", parent, CT_TEXTURE)
		control:SetDrawTier(DT_HIGH)
	end

	local bagId, slotIndex = ISL.GetInfoFromRowControl(parent)
	local texturePath, r, g, b = ISL.GetMarkerInfo(bagId, slotIndex)

	if not texturePath then
		control:SetHidden(true)
		return
	end

	local markerAnchor, customOffsetX, customOffsetY = ISL.GetMarkerAnchor()
	local offsets = ANCHOR_OFFSETS[markerAnchor]

	control:SetHidden(false)

	if control.itemSaverTexture ~= texturePath then
		control:SetTexture(texturePath)
		control.itemSaverTexture = texturePath
	end

	control:SetColor(r, g, b)

	local scale = ISL.SV.markerScale * 32
	control:SetDimensions(scale, scale)
	control:ClearAnchors()
	control:SetAnchor(markerAnchor, parent, markerAnchor, offsets.x + customOffsetX, offsets.y + customOffsetY)
end

function ISL.RefreshEquipmentControls()
	if not ZO_CharacterEquipmentSlots then return end
	for slotId = EQUIP_SLOT_ITERATION_BEGIN, EQUIP_SLOT_ITERATION_END do
		local slotName = ZO_Character_GetEquipSlotName(slotId)
		local slotControl = ZO_CharacterEquipmentSlots:GetNamedChild(slotName)
		if slotControl then
			ISL.CreateMarkerControl(slotControl)
		end
	end
end

function ISL.RefreshAll()
	PLAYER_INVENTORY:UpdateList(INVENTORY_BACKPACK)

	for i = 1, #LISTS do
		local list = LISTS[i]
		if list and not list:IsHidden() then
			ZO_ScrollList_RefreshVisible(list)
		end
	end

	ISL.RefreshEquipmentControls()
end

function ISL.RegisterMarkers()
	local markers = {
		{ "Box Star", [[/esoui/art/guild/guild_rankicon_leader_large.dds]] },
		{ "Flag", [[/esoui/art/ava/tabicon_bg_score_disabled.dds]] },
		{ "Padlock", [[/esoui/art/campaign/campaignbrowser_fullpop.dds]] },
		{ "Star", [[/esoui/art/campaign/overview_indexicon_bonus_disabled.dds]] },
	}

	for i = 1, #markers do
		local m = markers[i]
		ISL.markerTextures[m[1]] = m[2]
	end
end

function ISL.SetupVendorFilter()
	local vendor = BACKPACK_STORE_LAYOUT_FRAGMENT

	local layoutData = vendor.layoutData
	local original = layoutData.additionalFilter

	layoutData.additionalFilter = function(slot)
		if original then
			if not original(slot) then
				return false
			end
		end

		return not ISL.IsItemSaved(slot.bagId, slot.slotIndex)
	end
end

function ISL.ToggleItemSave(bagId, slotIndex)
	if ISL.IsUniqueItem(bagId, slotIndex) then
		local link = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
		if link == "" then return false end

		local t = ISL.SV.savedUniqueItems
		if t[link] then
			t[link] = nil
		else
			t[link] = true
		end

		ISL.RefreshAll()
		return t[link] == true
	end

	local itemId = GetItemId(bagId, slotIndex)
	if itemId == 0 then return false end

	local t = ISL.SV.savedItems
	if t[itemId] then
		t[itemId] = nil
	else
		t[itemId] = true
	end

	ISL.RefreshAll()
	return t[itemId] == true
end

function ISL.GetMarkerInfo(bagId, slotIndex)
	if not ISL.IsItemSaved(bagId, slotIndex) then
		return nil
	end
	local color = ZO_ColorDef:New(ISL.SV.markerColor)
	return ISL.markerTextures[ISL.SV.markerTexture], color:UnpackRGB()
end

function ISL.IsItemSaved(bagId, slotIndex)
	if ISL.IsUniqueItem(bagId, slotIndex) then
		local link = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
		if link == "" then return false end
		return ISL.SV.savedUniqueItems[link] == true
	end

	local itemId = GetItemId(bagId, slotIndex)
	if itemId == 0 then return false end
	return ISL.SV.savedItems[itemId] == true
end

function ISL.GetMarkerAnchor()
	local constants = { TOPLEFT, TOP, TOPRIGHT, RIGHT, BOTTOMRIGHT, BOTTOM, BOTTOMLEFT, LEFT, CENTER }
	return constants[ISL.SV.markerAnchor],
		   ISL.SV.offsetX,
		   ISL.SV.offsetY
end

function ISL.InitializeHooks()
	for i = 1, #LISTS do
		local list = LISTS[i]
		if list and list.dataTypes and list.dataTypes[1] then
			SecurePostHook(list.dataTypes[1], "setupCallback", function(rowControl)
				ISL.CreateMarkerControl(rowControl)
			end)
		end
	end
end

function ISL.AddItemContextMenu(inventorySlot, slotActions)
	local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
	if not bagId then
		return
	end

	local actionText = ISL.IsItemSaved(bagId, slotIndex) and SI_ITEMSAVERLITE_UNSAVE or SI_ITEMSAVERLITE_SAVE
	slotActions:AddCustomSlotAction(
		actionText,
		function()
			ISL.ToggleItemSave(bagId, slotIndex)
		end,
		""
	)
end

function ISL.OnAddonLoaded(eventCode, addonName)
	if addonName ~= ISL.name then return end
	EM:UnregisterForEvent(ISL.name, EVENT_ADD_ON_LOADED)

	ISL.SV = ZO_SavedVars:NewAccountWide("ItemSaverLite_SV", 3, nil, defaultSV)

	ISL.RegisterMarkers()
	ISL.SetupVendorFilter()
	ISL.InitializeHooks()
	ISL.RefreshEquipmentControls()
	ISL.CreateSettingsMenu()

	if ISL.SV.enableContextMenu then
		LCM:RegisterContextMenu(ISL.AddItemContextMenu, LCM.CATEGORY_LATE)
	end

	EM:RegisterForEvent(
		ISL.name,
		EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
		function(_, bagId, _, isNew, _, reason)
			if bagId == BAG_WORN and not isNew and reason == 0 then
				ISL.RefreshEquipmentControls()
			end
		end
	)
end

EM:RegisterForEvent(ISL.name, EVENT_ADD_ON_LOADED, ISL.OnAddonLoaded)