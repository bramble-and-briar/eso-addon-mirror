local BA = BindAll

function BA.initMenu()

	local defaults = {
		accountWide = true,
		autoBind = false,
		printToChat = false,
	}

	local panelData = {
		type = "panel",
		name = "BindAll",
		displayName = "BindAll",
		author = "ownedbynico",
		version = BA.version,
		registerForRefresh = true,
	}

	local optionsData = {
		{
			type = "checkbox",
			name = "Account-wide settings",
			getFunc = function() return BA.savedVariablesChar.accountWide end,
			setFunc = function(value)
						BA.savedVariablesChar.accountWide = value
						BA.savedVariables = value and BA.savedVariablesAccount or BA.savedVariablesChar
					  end,
			width = "full",
		},
		{
			type = "divider",
			height = 15,
			alpha = 0.5,
			width = "full"
		},
		{
			type = "checkbox",
			name = "Automatically bind on pickup",
			getFunc = function() return BA.savedVariables.autoBind end,
			setFunc = function(value) BA.savedVariables.autoBind = value end,
			width = "full"
		},
		{
			type = "checkbox",
			name = "Print bound items to chat",
			getFunc = function() return BA.savedVariables.printToChat end,
			setFunc = function(value) BA.savedVariables.printToChat = value end,
			width = "full"
		},
	}
	
	BA.savedVariablesAccount = ZO_SavedVars:NewAccountWide("BASV", 1, nil, defaults)
	BA.savedVariablesChar = ZO_SavedVars:NewCharacterIdSettings("BASV", 1, nil, defaults)
	
	BA.savedVariables = BA.savedVariablesChar
	if BA.savedVariablesChar.accountWide == true then
		BA.savedVariables = BA.savedVariablesAccount
	end
	
	if MyUI_RegisterExternalSection then MyUI_RegisterExternalSection(18, "BindAll", "18. BindAll", optionsData) end
end