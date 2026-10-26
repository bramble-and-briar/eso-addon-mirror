Bankir = Bankir or {}

local actionChoices = {
	[1] = GetString(BANKIR_MENU_MODE_DO_NOTHING),
	[2] = GetString(BANKIR_MENU_MODE_DEPOSIT),
	[3] = GetString(BANKIR_MENU_MODE_WITHDRAW),
}

local qualityChoices = {
	[1] = GetItemQualityColor(1):Colorize(GetString("SI_ITEMQUALITY", 1)),
	[2] = GetItemQualityColor(2):Colorize(GetString("SI_ITEMQUALITY", 2)),
	[3] = GetItemQualityColor(3):Colorize(GetString("SI_ITEMQUALITY", 3)),
	[4] = GetItemQualityColor(4):Colorize(GetString("SI_ITEMQUALITY", 4)),
	[5] = GetItemQualityColor(5):Colorize(GetString("SI_ITEMQUALITY", 5)),
}

local function getSavedVarForIdType(idTypeStr)
	local selectedBagRules = Bankir.savedVarsProfile[Bankir.Menu.selectedBankId]
	if idTypeStr == "itemType" then
		return selectedBagRules.byItemType
	elseif idTypeStr == "specializedItemType" then
		return selectedBagRules.bySpecializedItemType
	elseif idTypeStr == "itemId" then
		return selectedBagRules.byItemId
	end
end

local function getTypeChildrenLists(id, idTypeStr)
	local result
	if idTypeStr == "itemType" then
		if Bankir.Data.itemTypeChildrenItemIds[id] then
			result = result or {}
			table.insert(result, { idTypeStr = "itemId", list = Bankir.Data.itemTypeChildrenItemIds[id] })
		end
		if Bankir.Data.itemTypeChildrenSpecializedTypes[id] then
			result = result or {}
			table.insert(result, { idTypeStr = "specializedItemType", list = Bankir.Data.itemTypeChildrenSpecializedTypes[id] })
		end
	elseif idTypeStr == "specializedItemType" then
		if Bankir.Data.specializedItemTypeChildrenItemIds[id] then
			result = result or {}
			table.insert(result, { idTypeStr = "itemId", list = Bankir.Data.specializedItemTypeChildrenItemIds[id] })
		end
	end
	
	return result
end

local function getStacks(id, idTypeStr)
	local rule = getSavedVarForIdType(idTypeStr)[id]
	if rule then
		return rule.push, rule.pull, rule.pullInStacks
	else
		return 0, 0, false
	end
end

local function setStacks(value, action, id, idTypeStr)
	local ruleList = getSavedVarForIdType(idTypeStr)
	local oldValue
	if ruleList[id] then
		oldValue = ruleList[id][action]
	else
		ruleList[id] = { push = 0, pull = 0 }
	end
	
	if oldValue ~= value then
		ruleList[id][action] = value
		
		-- update children ids
		local childrenLists = getTypeChildrenLists(id, idTypeStr)
		if childrenLists then
			for _, list in ipairs(childrenLists) do
				for i, childId in ipairs(list.list) do
					setStacks(value, action, childId, list.idTypeStr)
				end
			end
		end
		-- update tweens
		if Bankir.Data.tweens[idTypeStr][id] then
			for i, childId in ipairs(Bankir.Data.tweens[idTypeStr][id]) do
				setStacks(value, action, childId, idTypeStr)
			end
		end
	end
	
	local anotherAction
	if action == "push" then anotherAction = "pull" else anotherAction = "push" end
	if value == 0 and ruleList[id][anotherAction] == 0 then
		ruleList[id] = nil
	end
end

local function setQuality(value, id, idTypeStr)
	local ruleList = getSavedVarForIdType(idTypeStr)
	if ruleList[id] then
		ruleList[id].quality = value
	end
	-- update children too
	local childrenLists = getTypeChildrenLists(id, idTypeStr)
	if childrenLists then
		for _, list in ipairs(childrenLists) do
			for i, childId in ipairs(list.list) do
				setQuality(value, childId, list.idTypeStr)
			end
		end
	end
	-- update tweens
	if Bankir.Data.tweens[idTypeStr][id] then
		for i, childId in ipairs(Bankir.Data.tweens[idTypeStr][id]) do
			setQuality(value, childId, idTypeStr)
		end
	end
end

local divider = {
	type = "divider",
	width = "full",
	height = 5,
	alpha = 1.0,
}

local dividerSmall = {
	type = "divider",
	width = "half",
	height = 5,
	alpha = 0.5,
}

local dividerInvisible = {
	type = "divider",
	width = "full",
	height = 5,
	alpha = 0.0,
}

local function makeHeader(title)
	return {
		type = "header",
		name = title,
	}
end

local function makeBankSelector()
	if #Bankir.Data.bankBagNames == 1 then
		return nil end
	
	return {
		type = "dropdown",
		name = GetString(BANKIR_MENU_BANK_SELECT),
		tooltip = GetString(BANKIR_MENU_BANK_SELECT_DESC),
		width = "full",
		choices = Bankir.Data.bankBagNames,
		getFunc = function()
			return Bankir.Data.bankBagNames[Bankir.Menu.selectedBankIndex]
		end,
		setFunc = function(selectedChoice)
			for index, name in ipairs(Bankir.Data.bankBagNames) do
				if name == selectedChoice then
					Bankir.Menu.selectedBankIndex = index
					Bankir.Menu.selectedBankId = Bankir.Data.bankBagIds[index]
					break
				end
			end
		end,
	}
end

local function makeCurrencyTab(currencyTypes)
	local controls = {}
	for i, currencyType in ipairs(currencyTypes) do
		--pre-declare so the functions of these two know about each other
		local checkbox1, checkbox2, slider
		checkbox1 = {
			type = "checkbox",
			name = zo_strformat(GetString(BANKIR_MENU_CURRENCY_DEPOSIT), GetCurrencyName(currencyType),
				ZO_Currency_GetPlatformFormattedCurrencyIcon(currencyType)),
			tooltip = GetString(BANKIR_MENU_CURRENCY_DEPOSIT_DESC),
			width = "full",
			getFunc = function()
				if Bankir.savedVarsProfile[Bankir.Menu.selectedBankId].currency then
					return Bankir.savedVarsProfile[Bankir.Menu.selectedBankId].currency[currencyType].push
				else
					return false
				end
			end,
			setFunc = function(value)
				Bankir.savedVarsProfile[Bankir.Menu.selectedBankId].currency[currencyType].push = value
			end,
			disabled = function()
				if not Bankir.savedVarsProfile[Bankir.Menu.selectedBankId].currency then
					return true
				elseif Bankir.Menu.selectedBankId ~= BAG_BANK and currencyType ~= CURT_MONEY then
					return true
				end
			end,
		}
		checkbox2 = {
			type = "checkbox",
			name = zo_strformat(GetString(BANKIR_MENU_CURRENCY_WITHDRAW), GetCurrencyName(currencyType),
				ZO_Currency_GetPlatformFormattedCurrencyIcon(currencyType)),
			tooltip = GetString(BANKIR_MENU_CURRENCY_WITHDRAW_DESC),
			width = "full",
			getFunc = function()
				if Bankir.savedVarsProfile[Bankir.Menu.selectedBankId].currency then
					return Bankir.savedVarsProfile[Bankir.Menu.selectedBankId].currency[currencyType].pull
				else
					return false
				end
			end,
			setFunc = function(value)
				Bankir.savedVarsProfile[Bankir.Menu.selectedBankId].currency[currencyType].pull = value
			end,
			disabled = function()
				if not Bankir.savedVarsProfile[Bankir.Menu.selectedBankId].currency then
					return true
				elseif Bankir.Menu.selectedBankId ~= BAG_BANK and currencyType ~= CURT_MONEY then
					return true
				end
			end,
		}
		slider = {
			type = "slider",
			name = GetString(BANKIR_MENU_CURRENCY_AMOUNT),
			tooltip = GetString(BANKIR_MENU_CURRENCY_AMOUNT_DESC),
			min = 0,
			max = Bankir.savedVarsCommon.currencySlidersMaxValue,
			step = 500,
			width = "full",
			getFunc = function()
				if Bankir.savedVarsProfile[Bankir.Menu.selectedBankId].currency then
					return Bankir.savedVarsProfile[Bankir.Menu.selectedBankId].currency[currencyType].amount
				else
					return 0
				end
			end,
			setFunc = function(value)
				Bankir.savedVarsProfile[Bankir.Menu.selectedBankId].currency[currencyType].amount = value
			end,
			disabled = function()
				if not Bankir.savedVarsProfile[Bankir.Menu.selectedBankId].currency then
					return true
				elseif Bankir.Menu.selectedBankId ~= BAG_BANK and currencyType ~= CURT_MONEY then
					return true
				elseif not Bankir.savedVarsProfile[Bankir.Menu.selectedBankId].currency[currencyType].push
				and not Bankir.savedVarsProfile[Bankir.Menu.selectedBankId].currency[currencyType].pull then
					return true
				end
			end,
		}
		table.insert(controls, checkbox1)
		table.insert(controls, checkbox2)
		table.insert(controls, slider)
		table.insert(controls, divider)
	end
	return controls
end

local function makeQualityDropdown(id, idTypeStr, modeDropdown)
	return {
		type = "dropdown",
		name = GetString(BANKIR_MENU_QUALITY_SELECT),
		tooltip = GetString(BANKIR_MENU_QUALITY_SELECT_DESC),
		width = "full",
		choices = qualityChoices,
		getFunc = function()
			local ruleList = getSavedVarForIdType(idTypeStr)
			local neededQuality = 1
			if ruleList[id] then
				neededQuality = ruleList[id].quality or 1
			end
			if neededQuality == 0 then neededQuality = 1 end
			return qualityChoices[neededQuality]
		end,
		setFunc = function(selectedChoice)
			for i = 1, #qualityChoices do
				if qualityChoices[i] == selectedChoice then
					setQuality(i, id, idTypeStr)
				end
			end
		end,
	}
end

local function makeSelectedProfileLabel()
	return {
		type = "description",
		title = GetString(BANKIR_MENU_CURRENT_PROFILE_NAME) .. Bankir.savedVarsCharacter.profile,
		tooltip = GetString(BANKIR_MENU_CURRENT_PROFILE_NAME_DESC),
		width = "full",
		reference = "BankirMenuSelectedProfileLabel",
	}
end

local function makeSettingsMenu()
	local controls = {}
	table.insert(controls, {
			type = "dropdown",
			name = GetString(BANKIR_MENU_PROFILE_SELECT),
			tooltip = GetString(BANKIR_MENU_PROFILE_SELECT_DESC),
			width = "full",
			reference = "BankirMenuProfilesDropdown",
			choices = Bankir.Profiles.getProfilesNames(),
			getFunc = function() return Bankir.savedVarsCharacter.profile end,
			setFunc = function(selectedChoice)
				Bankir.Profiles.setCurrentProfile(selectedChoice)
				_G["BankirMenuSelectedProfileLabel"].data.title = GetString(BANKIR_MENU_CURRENT_PROFILE_NAME) .. Bankir.savedVarsCharacter.profile
				_G["BankirMenuSelectedProfileLabel"]:UpdateValue()
			end,
		})
	table.insert(controls, {
			type = "editbox",
			name = GetString(BANKIR_MENU_PROFILE_EDIT_NAME),
			width = "full",
			getFunc = function() return Bankir.savedVarsCharacter.profile end,
			setFunc = function(text)
				Bankir.Profiles.updateCurrentProfileName(Bankir.savedVarsCharacter.profile, text)
				_G["BankirMenuProfilesDropdown"]:UpdateChoices(Bankir.Profiles.getProfilesNames())
				_G["BankirMenuSelectedProfileLabel"].data.title = GetString(BANKIR_MENU_CURRENT_PROFILE_NAME) .. Bankir.savedVarsCharacter.profile
				_G["BankirMenuSelectedProfileLabel"]:UpdateValue()
			end,
			isMultiline = false,
		})
	table.insert(controls, {
			type = "button",
			name = GetString(BANKIR_MENU_PROFILE_NEW),
			func = function()
				Bankir.Profiles.createNewProfile("New profile")
				_G["BankirMenuProfilesDropdown"]:UpdateChoices(Bankir.Profiles.getProfilesNames())
				_G["BankirMenuSelectedProfileLabel"].data.title = GetString(BANKIR_MENU_CURRENT_PROFILE_NAME) .. Bankir.savedVarsCharacter.profile
				_G["BankirMenuSelectedProfileLabel"]:UpdateValue()
			end,
			width = "full",
		})
	table.insert(controls, {
			type = "button",
			name = GetString(BANKIR_MENU_PROFILE_COPY),
			tooltip = GetString(BANKIR_MENU_PROFILE_COPY_DESC),
			func = function()
				Bankir.Profiles.copyCurrentProfile()
				_G["BankirMenuProfilesDropdown"]:UpdateChoices(Bankir.Profiles.getProfilesNames())
				_G["BankirMenuSelectedProfileLabel"].data.title = GetString(BANKIR_MENU_CURRENT_PROFILE_NAME) .. Bankir.savedVarsCharacter.profile
				_G["BankirMenuSelectedProfileLabel"]:UpdateValue()
			end,
			width = "full",
		})
	table.insert(controls, {
			type = "button",
			name = GetString(BANKIR_MENU_PROFILE_DELETE),
			func = function()
				Bankir.Profiles.deleteCurrentProfile()
				_G["BankirMenuProfilesDropdown"]:UpdateChoices(Bankir.Profiles.getProfilesNames())
				_G["BankirMenuSelectedProfileLabel"].data.title = GetString(BANKIR_MENU_CURRENT_PROFILE_NAME) .. Bankir.savedVarsCharacter.profile
				_G["BankirMenuSelectedProfileLabel"]:UpdateValue()
			end,
			width = "full",
			isDangerous = true,
			warning = GetString(BANKIR_MENU_PROFILE_DELETE_WARNING),
			disabled = function() return #Bankir.Profiles.getProfilesNames() == 1 end,
		})
	table.insert(controls, divider)
	table.insert(controls, {
			type = "checkbox",
			name = GetString(BANKIR_MENU_MOVE_LOCKED_ITEMS),
			tooltip = GetString(BANKIR_MENU_MOVE_LOCKED_ITEMS_DESC),
			getFunc = function()
				return Bankir.savedVarsCommon.moveLockedItems
			end,
			setFunc = function(value)
				Bankir.savedVarsCommon.moveLockedItems = value
			end,
		})
	table.insert(controls, {
			type = "checkbox",
			name = GetString(BANKIR_MENU_SHOW_DEPOSIT_NOT_ALLOWED_MESSAGE),
			tooltip = GetString(BANKIR_MENU_SHOW_DEPOSIT_NOT_ALLOWED_MESSAGE_DESC),
			getFunc = function()
				return Bankir.savedVarsCommon.showOperationFailMessages
			end,
			setFunc = function(value)
				Bankir.savedVarsCommon.showOperationFailMessages = value
			end,
		})
	table.insert(controls, {
			type = "editbox",
			name = GetString(BANKIR_MENU_BANK_SLIDERS_MAX_VALUE),
			tooltip = zo_strformat(GetString(BANKIR_MENU_BANK_SLIDERS_MAX_VALUE_DESC), GetString(SI_ITEM_ACTION_BANK_DEPOSIT), GetString(SI_ITEM_ACTION_BANK_WITHDRAW)),
			width = "full",
			isMultiline = false,
			textType = TEXT_TYPE_NUMERIC,
			default = Bankir.savedVarsCommon.bankSlidersMaxValue,
			requiresReload = true,
			getFunc = function() return Bankir.savedVarsCommon.bankSlidersMaxValue end,
			setFunc = function(text)
				Bankir.savedVarsCommon.bankSlidersMaxValue = tonumber(text)
			end,
		})
	table.insert(controls, {
			type = "editbox",
			name = GetString(BANKIR_MENU_CURRENCY_SLIDERS_MAX_VALUE),
			tooltip = zo_strformat(GetString(BANKIR_MENU_CURRENCY_SLIDERS_MAX_VALUE_DESC), GetString(SI_ITEM_ACTION_BANK_DEPOSIT), GetString(SI_ITEM_ACTION_BANK_WITHDRAW)),
			width = "full",
			isMultiline = false,
			textType = TEXT_TYPE_NUMERIC,
			default = Bankir.savedVarsCommon.currencySlidersMaxValue,
			requiresReload = true,
			getFunc = function() return Bankir.savedVarsCommon.currencySlidersMaxValue end,
			setFunc = function(text)
				Bankir.savedVarsCommon.currencySlidersMaxValue = tonumber(text)
			end,
		})
	
	return controls
end

local function makeIdTypeSliders(id, idTypeStr)
	-- pre-declare so the functions of these two know about each other
	local header, label, sliderPush, sliderPull, pullCheckbox
	
	-- prepare name for dropdown
	local name = Bankir.Functions.getNameOfType(id, idTypeStr)
	name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name) -- make first char uppercase
	if getTypeChildrenLists(id, idTypeStr) then
		name = name .. " - " .. GetString(SI_INVENTORY_WALLET_ALL_FILTER) -- "Name of type - All"
	end
	
	header = {
		type = "header",
		name = name,
	}
	label = {
		type = "description",
		title = name,
	}
	sliderPush = {
		type = "slider",
		name = GetString(SI_ITEM_ACTION_BANK_DEPOSIT),
		tooltip = GetString(BANKIR_MENU_PUSH_DESC),
		min = 0,
		max = Bankir.savedVarsCommon.bankSlidersMaxValue,
		step = 1,
		width = "full",
		getFunc = function()
			return select(1, getStacks(id, idTypeStr))
		end,
		setFunc = function(value)
			setStacks(value, "push", id, idTypeStr)
		end,
	}
	sliderPull = {
		type = "slider",
		name = GetString(SI_ITEM_ACTION_BANK_WITHDRAW),
		tooltip = GetString(BANKIR_MENU_PULL_DESC),
		min = 0,
		max = Bankir.savedVarsCommon.bankSlidersMaxValue,
		step = 1,
		width = "full",
		getFunc = function()
			return select(2, getStacks(id, idTypeStr))
		end,
		setFunc = function(value)
			setStacks(value, "pull", id, idTypeStr)
		end,
	}
	pullCheckbox = {
		type = "checkbox",
		name = zo_strformat(GetString(BANKIR_MENU_PULL_IN_STACKS), GetString(SI_ITEM_ACTION_BANK_WITHDRAW)),
		tooltip = zo_strformat(GetString(BANKIR_MENU_PULL_IN_STACKS_DESC), GetString(SI_ITEM_ACTION_BANK_WITHDRAW)),
		width = "full",
		getFunc = function()
			return select(3, getStacks(id, idTypeStr))
		end,
		setFunc = function(value)
			setStacks(value, "pullInStacks", id, idTypeStr)
		end,
	}
	return header, label, sliderPush, sliderPull, pullCheckbox
end

local function makeWidgetsForTypes(typesData)
	local controls = {}
	for i, typeData in ipairs(typesData) do
		local id = typeData.id
		local idTypeStr = typeData.idTypeStr
		local header, _, sliderPush, sliderPull, pullCheckbox = makeIdTypeSliders(id, idTypeStr)
		table.insert(controls, header)
		table.insert(controls, sliderPush)
		table.insert(controls, sliderPull)
		table.insert(controls, pullCheckbox)
		local isQualityRuled = false
		for i = 1, #Bankir.Data.qualityRuledItemTypes[idTypeStr] do
			if Bankir.Data.qualityRuledItemTypes[idTypeStr][i] == id then
				isQualityRuled = true
				local qualityDropdown = makeQualityDropdown(id, idTypeStr, dropdown)
				table.insert(controls, qualityDropdown)
			end
		end
		local childrenLists = getTypeChildrenLists(id, idTypeStr)
		if childrenLists then
			for _, list in ipairs(childrenLists) do
				for i, childId in ipairs(list.list) do
					local _, label, sliderPush, sliderPull, pullCheckbox = makeIdTypeSliders(childId, list.idTypeStr)
					table.insert(controls, dividerSmall)
					table.insert(controls, label)
					table.insert(controls, sliderPush)
					table.insert(controls, sliderPull)
					table.insert(controls, pullCheckbox)
					if isQualityRuled then
						local qualityDropdown = makeQualityDropdown(childId, list.idTypeStr, dropdown)
						table.insert(controls, qualityDropdown)
					end
				end
			end
		end
		table.insert(controls, dividerInvisible)
	end
	return controls
end

local function makeLCKSettings()
	local LCK = LibCharacterKnowledge
	
	local controls = {
		{
			type = "header",
			name = "LibCharacterKnowledge",
		},
		{
			type = "description",
			title = GetString(BANKIR_MENU_INTEGRATIONS_LCK_DESC),
			disabled = LCK == nil,
		},
		divider,
	}
	
	local currentId = GetCurrentCharacterId()
	for _, charData in pairs(Bankir.Data.charactersList) do
		if charData.id ~= currentId then
			table.insert(controls, {
				type = "checkbox",
				name = charData.name,
				width = "full",
				getFunc = function()
					return Bankir.savedVarsServer.Integrations.LCK.CharactersList[charData.id] ~= nil
				end,
				setFunc = function(value)
					Bankir.savedVarsServer.Integrations.LCK.CharactersList[charData.id] = value and true or nil
				end,
				disabled = function()
					return LCK == nil
				end,
			})
		end
	end
	return controls
end

Bankir.MenuBuildFunctions = {
	divider = divider,
	dividerSmall = dividerSmall,
	makeHeader = makeHeader,
	makeBankSelector = makeBankSelector,
	makeCurrencyTab = makeCurrencyTab,
	makeProfileSelector = makeProfileSelector,
	makeSelectedProfileLabel = makeSelectedProfileLabel,
	makeSettingsMenu = makeSettingsMenu,
	makeWidgetsForTypes = makeWidgetsForTypes,
	makeLCKSettings = makeLCKSettings,
}
