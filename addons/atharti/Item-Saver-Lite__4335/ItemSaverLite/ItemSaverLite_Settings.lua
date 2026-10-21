local ISL = ItemSaverLite

local LAM = LibAddonMenu2

function ISL.CreateSettingsMenu()
	local ANCHOR_OPTIONS = {
		"Top Left",
		"Top",
		"Top Right",
		"Right",
		"Bottom Right",
		"Bottom",
		"Bottom Left",
		"Left",
		"Center"
	}

	local markerTexturePaths, markerTextureNames = ISL.GetMarkerTextureArrays()
	local savedChoices, savedValues = ISL.GetSavedItemChoices()

	local optionsData = {
		{
			type = "header",
			name = "|t30:30:/esoui/art/menubar/gamepad/gp_playermenu_icon_emotes.dds|t Appearance"
		},
		{
			type = "iconpicker",
			name = "Marker Texture",
			tooltip = "Icon style for your markers.",
			choices = markerTexturePaths,
			choicesTooltips = markerTextureNames,
			iconSize = 32,
			maxRowCount = 2,
			width = "half",
			getFunc = function()
				return ISL.markerTextures[ISL.SV.markerTexture]
			end,
			setFunc = function(path)
				for name, texPath in pairs(ISL.markerTextures) do
					if texPath == path then
						ISL.SV.markerTexture = name
						break
					end
				end
				ISL.RefreshAll()
			end,
		},
		{
			type = "colorpicker",
			name = "Marker Color",
			tooltip = "The color tint applied to the marker icon.",
			width = "half",
			getFunc = function()
				local color = ZO_ColorDef:New(ISL.SV.markerColor)
				return color:UnpackRGB()
			end,
			setFunc = function(r, g, b)
				local color = ZO_ColorDef:New(r, g, b)
				ISL.SV.markerColor = color:ToHex()
				ISL.RefreshAll()
			end,
		},
		{
			type = "dropdown",
			name = "Marker Position",
			tooltip = "Position of the saved item marker.",
			choices = ANCHOR_OPTIONS,
			width = "half",
			getFunc = function()
				return ANCHOR_OPTIONS[ISL.SV.markerAnchor]
			end,
			setFunc = function(value)
				for i, option in ipairs(ANCHOR_OPTIONS) do
					if option == value then
						ISL.SV.markerAnchor = i
						break
					end
				end
				ISL.RefreshAll()
			end,
		},
		{
			type = "slider",
			name = "Marker Scale",
			tooltip = "Size modifier for the texture marker overlay.",
			min = 0.2,
			max = 2.0,
			step = 0.1,
			width = "half",
			getFunc = function() return ISL.SV.markerScale end,
			setFunc = function(value)
				ISL.SV.markerScale = value
				ISL.RefreshAll()
			end,
		},
		{
			type = "slider",
			name = "Horizontal Offset",
			tooltip = "Add an additional offset to the marker's horizontal position.",
			min = -10,
			max = 10,
			step = 1,
			width = "half",
			getFunc = function() return ISL.SV.offsetX end,
			setFunc = function(value)
				ISL.SV.offsetX = value
				ISL.RefreshAll()
			end,
		},
		{
			type = "slider",
			name = "Vertical Offset",
			tooltip = "Add an additional offset to the marker's vertical position.",
			min = -10,
			max = 10,
			step = 1,
			width = "half",
			getFunc = function() return ISL.SV.offsetY end,
			setFunc = function(value)
				ISL.SV.offsetY = value
				ISL.RefreshAll()
			end,
		},

		{
			type = "header",
			name = "|t30:30:/esoui/art/inventory/gamepad/gp_inventory_icon_miscellaneous.dds|t General Settings"
		},
		{
			type = "checkbox",
			name = "Enable Context Menu Options",
			tooltip = "Show 'Save Item' / 'Unlock' option in the right-click context menu.",
			getFunc = function() return ISL.SV.enableContextMenu end,
			setFunc = function(value)
				ISL.SV.enableContextMenu = value
			end,
			requiresReload = true,
		},
		{
			type = "header",
			name = "|t35:35:/esoui/art/lfg/gamepad/gp_lfg_groupfinder_editlisting.dds|t Saved Items",
		},
		{
			type = "description",
			reference = "ISL_SavedItemCountLabel",
			title = function()
				return string.format("Total: |cFFD700%d|r", ISL.GetSavedItemCount())
			end,
			text = "",
			width = "full",
		},
		{
			type = "dropdown",
			name = "Item List:",
			choices = savedChoices,
			choicesValues = savedValues,
			getFunc = function() return end,
			setFunc = function(value)
				ISL.selectedSavedItem = value
			end,
			width = "half",
			reference = "ISL_SAVED_ITEMS_LIST",
		},
		{
			type = "button",
			name = "Remove",
			width = "half",
			func = function()
				local entry = ISL.selectedSavedItem
				if not entry then
					d("|cFF0000[ItemSaverLite]|r No item selected.")
					return
				end

				if entry.kind == "unique" then
					ISL.SV.savedUniqueItems[entry.key] = nil
				else
					ISL.SV.savedItems[entry.key] = nil
				end

				ISL.selectedSavedItem = nil
				ISL.RefreshSavedItemsDropdown()
				ISL.RefreshAll()
				
				local labelControl = _G["ISL_SavedItemCountLabel"]
				labelControl:UpdateValue()				
			end,
		},
	}

	LAM:RegisterOptionControls("ItemSaverLiteSettingsPanel", optionsData)
	local mySettingsPanel = LAM:RegisterAddonPanel("ItemSaverLiteSettingsPanel", {
		type = "panel",
		name = "|cFFD700Item Saver Lite|r",
		author = "|cFFD700@Atharti|r"
	})

	CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
		if panel ~= mySettingsPanel then return end
		ISL.RefreshSavedItemsDropdown()
		
		local labelControl = _G["ISL_SavedItemCountLabel"]
		labelControl:UpdateValue()
	end)
end

function ISL.GetSavedItemChoices()
	local choices = {}
	local values = {}

	for itemLink in pairs(ISL.SV.savedUniqueItems) do
		table.insert(choices, itemLink)
		table.insert(values, { kind = "unique", key = itemLink })
	end

	for itemId in pairs(ISL.SV.savedItems) do
		local displayLink = ("|H1:item:%d:0:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h"):format(itemId)
		table.insert(choices, displayLink)
		table.insert(values, { kind = "id", key = itemId })
	end

	return choices, values
end

function ISL.RefreshSavedItemsDropdown()
	if not ISL_SAVED_ITEMS_LIST then return end
	local choices, values = ISL.GetSavedItemChoices()
	ISL.currentSavedDropdownValues = values
	ISL_SAVED_ITEMS_LIST:UpdateChoices(choices, values)
	ISL_SAVED_ITEMS_LIST:UpdateValue()
end

function ISL.GetSavedItemCount()
	local n = 0
	for _ in pairs(ISL.SV.savedUniqueItems) do n = n + 1 end
	for _ in pairs(ISL.SV.savedItems) do n = n + 1 end
	return n
end