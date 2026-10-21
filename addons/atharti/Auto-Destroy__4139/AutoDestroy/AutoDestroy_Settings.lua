local AD = AutoDestroy

local LAM = LibAddonMenu2

function AD.GetChoices()
	local choices = {}
	local values = {}

	for itemLink, _ in pairs(AD.SV.itemsList) do
		table.insert(choices, itemLink)
		table.insert(values, itemLink)
	end

	return choices, values
end

function AD.RefreshDropdown()
	AD_ITEMS_LIST:UpdateChoices(AD.GetChoices())
	AD_ITEMS_LIST:UpdateValue()
end

function AD.SetupSettings()
	local panelData = {
		type = "panel",
		name = "Auto Destroy",
		displayName = "|cFFD700Auto Destroy|r",
		author = "|cFFD700@Atharti|r",
		registerForRefresh = true,
		registerForDefaults = true,
	}

	local selectedItemLink
	local choices, values = AD.GetChoices()

	local optionsData = {
		{
			type = "header",
			name = "|t30:30:/esoui/art/guild/history/gamepad/gp_guildhistory_customize.dds|t CUSTOM LIST",
		},
		{
			type = "checkbox",
			name = "Enable Auto Destroy",
			tooltip = "Toggle automatic destruction of specified items on inventory update.",
			getFunc = function() return AD.SV.autoDestroyEnabled end,
			setFunc = function(value)
				if value then
					AD.DialogEnableAD()
				else
					AD.SV.autoDestroyEnabled = value
				end
			end,
			default = false,
			reference = "AD_MAIN",
		},
		{
			type = "dropdown",
			name = "List Of Items To Destroy:",
			tooltip = "Select an item to remove from the AutoDestroy list.",
			choices = choices,
			choicesValues = values,
			getFunc = function() return end,
			setFunc = function(value)
				selectedItemLink = value
			end,
			width = "half",
			reference = "AD_ITEMS_LIST",
		},
		{
			type = "button",
			name = "Remove from AutoDestroy list",
			tooltip = "Removes the selected item from the list.",
			width = "half",
			func = function()
				if selectedItemLink and AD.SV.itemsList[selectedItemLink] then
					AD.SV.itemsList[selectedItemLink] = nil
					AD.RefreshDropdown()
				else
					d("|cFF0000[AutoDestroy]|r No item selected or item does not exist.")
				end
			end,
		},
		{
			type = "header",
			name = "|t30:30:/esoui/art/addons/gamepad/gp_mod_listing_category_mapandcompass.dds|t Treasure Maps",
		},
		{
			type = "description",
			text = "Feature below will automatically |cFF8800OPEN|r all |cFF8800UNKNOWN|r treasure maps instantly and |cFF0000DESTROY|r all treasure maps except:\n- |c008000Blackwood|r\n- |c008000Deadlands|r\n- |c008000High Isle|r\n- |c008000Telvanni Peninsula|r\n- |c008000Apocrypha|r\n- |c008000West Weald|r\n- |c008000Solstice|r",
		},
		{
			type = "divider",
		},
		{
			type = "checkbox",
			name = "Destroy Base Game And Cheap DLC Treasure Maps",
			getFunc = function() return AD.SV.destroyMaps end,
			setFunc = function(value)
				if value then
					AD.DialogEnableMaps()
				else
					AD.SV.destroyMaps = value
				end
			end,
			default = false,
			reference = "AD_DESTROY_TRASHURE",
		},
	}

	LAM:RegisterOptionControls("AutoDestroyOptions", optionsData)
	local mySettingsPanel = LAM:RegisterAddonPanel("AutoDestroyOptions", panelData)

	CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
		if panel ~= mySettingsPanel then return end
		AD.RefreshDropdown()
	end)
end