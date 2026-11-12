Bankir = Bankir or {}

local actionChoices = {
	[1] = GetString(BANKIR_MENU_MODE_DO_NOTHING),
	[2] = GetString(BANKIR_MENU_MODE_DEPOSIT),
	[3] = GetString(BANKIR_MENU_MODE_WITHDRAW),
}

local qualityChoices = {
	GetItemQualityColor(1):Colorize(GetString("SI_ITEMQUALITY", 1)),
	GetItemQualityColor(2):Colorize(GetString("SI_ITEMQUALITY", 2)),
	GetItemQualityColor(3):Colorize(GetString("SI_ITEMQUALITY", 3)),
	GetItemQualityColor(4):Colorize(GetString("SI_ITEMQUALITY", 4)),
	GetItemQualityColor(5):Colorize(GetString("SI_ITEMQUALITY", 5)),
}

local function setRuleValue(valueName, value, id, idTypeStr, hasQualityRuleSet)
	local ruleList = Bankir.SVProfile[Bankir.Menu.selectedBankId][idTypeStr]
	local oldValue
	
	if ruleList[id] then
		oldValue = ruleList[id][valueName]
	else -- new rule, oldValue is nil
		ruleList[id] = { push = 0, pull = 0 }
	end
	
	if oldValue ~= value then
		ruleList[id][valueName] = value
		
		-- update children ids
		if Bankir.Data.childrenTable[idTypeStr][id] then
			for childTypeStr in pairs(Bankir.Data.childrenTable[idTypeStr][id]) do
				local list = Bankir.Data.childrenTable[idTypeStr][id][childTypeStr]
				for i, childId in ipairs(list) do
					setRuleValue(valueName, value, childId, childTypeStr)
				end
			end
		end
		-- update tweens
		if Bankir.Data.tweensTable[idTypeStr][id] then
			for tweenTypeStr in pairs(Bankir.Data.tweensTable[idTypeStr][id]) do
				local list = Bankir.Data.tweensTable[idTypeStr][id][tweenTypeStr]
				for i, tweenId in ipairs(list) do
					setRuleValue(valueName, value, tweenId, tweenTypeStr)
				end
			end
		end
	end
	
	local rule = ruleList[id]
	if rule.push == 0 and rule.pull == 0 then
		if not rule.pullInStacks then
			if not rule.quality or #rule.quality == #Bankir.Data.defaultQualityValues then
				ruleList[id] = nil
			end
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
				if Bankir.SVProfile[Bankir.Menu.selectedBankId].currency then
					return Bankir.SVProfile[Bankir.Menu.selectedBankId].currency[currencyType].push
				else
					return false
				end
			end,
			setFunc = function(value)
				Bankir.SVProfile[Bankir.Menu.selectedBankId].currency[currencyType].push = value
			end,
			disabled = function()
				if not Bankir.SVProfile[Bankir.Menu.selectedBankId].currency then
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
				if Bankir.SVProfile[Bankir.Menu.selectedBankId].currency then
					return Bankir.SVProfile[Bankir.Menu.selectedBankId].currency[currencyType].pull
				else
					return false
				end
			end,
			setFunc = function(value)
				Bankir.SVProfile[Bankir.Menu.selectedBankId].currency[currencyType].pull = value
			end,
			disabled = function()
				if not Bankir.SVProfile[Bankir.Menu.selectedBankId].currency then
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
			max = Bankir.SVCommon.currencySlidersMaxValue,
			step = 500,
			width = "full",
			getFunc = function()
				if Bankir.SVProfile[Bankir.Menu.selectedBankId].currency then
					return Bankir.SVProfile[Bankir.Menu.selectedBankId].currency[currencyType].amount
				else
					return 0
				end
			end,
			setFunc = function(value)
				Bankir.SVProfile[Bankir.Menu.selectedBankId].currency[currencyType].amount = value
			end,
			disabled = function()
				if not Bankir.SVProfile[Bankir.Menu.selectedBankId].currency then
					return true
				elseif Bankir.Menu.selectedBankId ~= BAG_BANK and currencyType ~= CURT_MONEY then
					return true
				elseif not Bankir.SVProfile[Bankir.Menu.selectedBankId].currency[currencyType].push
				and not Bankir.SVProfile[Bankir.Menu.selectedBankId].currency[currencyType].pull then
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

local function makeQualityDropdown(id, idTypeStr)
	return {
		type = "dropdown",
		name = GetString(BANKIR_MENU_QUALITY_SELECT),
		tooltip = GetString(BANKIR_MENU_QUALITY_SELECT_DESC),
		width = "full",
		choices = qualityChoices,
		choicesValues = Bankir.Data.defaultQualityValues,
		multiSelect = true,
		getFunc = function()
			local neededQualities = Bankir.Functions.getEffectiveRule(id, idTypeStr, Bankir.Menu.selectedBankId).quality
			return neededQualities
		end,
		setFunc = function(selectedChoices)
			if #selectedChoices == #Bankir.Data.defaultQualityValues then
				setRuleValue("quality", nil, id, idTypeStr)
			else
				setRuleValue("quality", selectedChoices, id, idTypeStr)
			end
		end,
	}
end

local function makeRulesProfileSelector()
	return {
		type = "dropdown",
		name = GetString(BANKIR_MENU_CURRENT_PROFILE_NAME),
		tooltip = GetString(BANKIR_MENU_PROFILE_SELECT_DESC),
		width = "full",
		reference = "BankirMenuRulesProfilesDropdown",
		choices = Bankir.Profiles.getProfilesNames(),
		getFunc = function() return Bankir.SVCharacter.profile end,
		setFunc = function(selectedChoice)
			Bankir.Profiles.setCurrentProfile(selectedChoice)
			local settingsSelector = _G["BankirMenuSettingsProfilesDropdown"]
			if settingsSelector then
				_G["BankirMenuSettingsProfilesDropdown"]:UpdateChoices(Bankir.Profiles.getProfilesNames())
			end
		end,
	}
end

local function makeSettingsMenu()
	local controls = {}
	table.insert(controls, {
			type = "dropdown",
			name = GetString(BANKIR_MENU_PROFILE_SELECT),
			tooltip = GetString(BANKIR_MENU_PROFILE_SELECT_DESC),
			width = "full",
			reference = "BankirMenuSettingsProfilesDropdown",
			choices = Bankir.Profiles.getProfilesNames(),
			getFunc = function() return Bankir.SVCharacter.profile end,
			setFunc = function(selectedChoice)
				Bankir.Profiles.setCurrentProfile(selectedChoice)
				_G["BankirMenuRulesProfilesDropdown"]:UpdateChoices(Bankir.Profiles.getProfilesNames())
			end,
		})
	table.insert(controls, {
			type = "editbox",
			name = GetString(BANKIR_MENU_PROFILE_EDIT_NAME),
			width = "full",
			getFunc = function() return Bankir.SVCharacter.profile end,
			setFunc = function(text)
				Bankir.Profiles.updateCurrentProfileName(Bankir.SVCharacter.profile, text)
				_G["BankirMenuSettingsProfilesDropdown"]:UpdateChoices(Bankir.Profiles.getProfilesNames())
				_G["BankirMenuRulesProfilesDropdown"]:UpdateChoices(Bankir.Profiles.getProfilesNames())
			end,
			isMultiline = false,
		})
	table.insert(controls, {
			type = "button",
			name = GetString(BANKIR_MENU_PROFILE_NEW),
			func = function()
				Bankir.Profiles.initProfile("New profile")
				_G["BankirMenuSettingsProfilesDropdown"]:UpdateChoices(Bankir.Profiles.getProfilesNames())
				_G["BankirMenuRulesProfilesDropdown"]:UpdateChoices(Bankir.Profiles.getProfilesNames())
			end,
			width = "full",
		})
	table.insert(controls, {
			type = "button",
			name = GetString(BANKIR_MENU_PROFILE_COPY),
			tooltip = GetString(BANKIR_MENU_PROFILE_COPY_DESC),
			func = function()
				Bankir.Profiles.copyCurrentProfile()
				_G["BankirMenuSettingsProfilesDropdown"]:UpdateChoices(Bankir.Profiles.getProfilesNames())
				_G["BankirMenuRulesProfilesDropdown"]:UpdateChoices(Bankir.Profiles.getProfilesNames())
			end,
			width = "full",
		})
	table.insert(controls, {
			type = "button",
			name = GetString(BANKIR_MENU_PROFILE_DELETE),
			func = function()
				Bankir.Profiles.deleteCurrentProfile()
				_G["BankirMenuSettingsProfilesDropdown"]:UpdateChoices(Bankir.Profiles.getProfilesNames())
				_G["BankirMenuRulesProfilesDropdown"]:UpdateChoices(Bankir.Profiles.getProfilesNames())
			end,
			width = "full",
			isDangerous = true,
			warning = GetString(BANKIR_MENU_PROFILE_DELETE_WARNING),
			disabled = function() return #Bankir.Profiles.getProfilesNames() == 1 end,
		})
	table.insert(controls, divider)
	table.insert(controls, {
			type = "checkbox",
			name = GetString(BANKIR_MENU_ENABLE_AUTO_MODE),
			tooltip = GetString(BANKIR_MENU_ENABLE_AUTO_MODE_DESC),
			getFunc = function()
				return Bankir.SVCommon.autoModeEnabled
			end,
			setFunc = function(value)
				Bankir.SVCommon.autoModeEnabled = value
			end,
		})
	table.insert(controls, {
			type = "checkbox",
			name = GetString(BANKIR_MENU_MOVE_LOCKED_ITEMS),
			tooltip = GetString(BANKIR_MENU_MOVE_LOCKED_ITEMS_DESC),
			getFunc = function()
				return Bankir.SVCommon.moveLockedItems
			end,
			setFunc = function(value)
				Bankir.SVCommon.moveLockedItems = value
			end,
		})
	table.insert(controls, {
			type = "checkbox",
			name = GetString(BANKIR_MENU_MOVE_QUEST_ITEMS),
			tooltip = GetString(BANKIR_MENU_MOVE_QUEST_ITEMS_DESC),
			getFunc = function()
				return Bankir.SVCommon.moveQuestItems
			end,
			setFunc = function(value)
				Bankir.SVCommon.moveQuestItems = value
			end,
		})
	table.insert(controls, {
			type = "checkbox",
			name = GetString(BANKIR_MENU_SHOW_FAIL_MESSAGES),
			tooltip = GetString(BANKIR_MENU_SHOW_FAIL_MESSAGES_DESC),
			getFunc = function()
				return Bankir.SVCommon.showOperationFailMessages
			end,
			setFunc = function(value)
				Bankir.SVCommon.showOperationFailMessages = value
			end,
		})
	table.insert(controls, {
			type = "editbox",
			name = GetString(BANKIR_MENU_BANK_SLIDERS_MAX_VALUE),
			tooltip = zo_strformat(GetString(BANKIR_MENU_BANK_SLIDERS_MAX_VALUE_DESC), GetString(SI_ITEM_ACTION_BANK_DEPOSIT), GetString(SI_ITEM_ACTION_BANK_WITHDRAW)),
			width = "full",
			isMultiline = false,
			textType = TEXT_TYPE_NUMERIC,
			default = Bankir.SVCommon.bankSlidersMaxValue,
			requiresReload = true,
			getFunc = function() return Bankir.SVCommon.bankSlidersMaxValue end,
			setFunc = function(text)
				Bankir.SVCommon.bankSlidersMaxValue = tonumber(text)
			end,
		})
	table.insert(controls, {
			type = "editbox",
			name = GetString(BANKIR_MENU_CURRENCY_SLIDERS_MAX_VALUE),
			tooltip = zo_strformat(GetString(BANKIR_MENU_CURRENCY_SLIDERS_MAX_VALUE_DESC), GetString(SI_ITEM_ACTION_BANK_DEPOSIT), GetString(SI_ITEM_ACTION_BANK_WITHDRAW)),
			width = "full",
			isMultiline = false,
			textType = TEXT_TYPE_NUMERIC,
			default = Bankir.SVCommon.currencySlidersMaxValue,
			requiresReload = true,
			getFunc = function() return Bankir.SVCommon.currencySlidersMaxValue end,
			setFunc = function(text)
				Bankir.SVCommon.currencySlidersMaxValue = tonumber(text)
			end,
		})
	
	return controls
end

local function makeIdTypeSliders(id, idTypeStr, useHeader)
	-- pre-declare so the functions of these two know about each other
	local header, sliderPush, sliderPull, pullCheckbox
	
	-- prepare name
	local name = Bankir.Functions.getNameOfType(id, idTypeStr)
	name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name) -- make first char uppercase
	
	if Bankir.Data.childrenTable[idTypeStr][id] then
		useHeader = true
		name = name .. " - " .. GetString(SI_INVENTORY_WALLET_ALL_FILTER) -- "Name of type - All"
	end
	
	if useHeader then
		header = {
			type = "header",
			name = name,
		}
	else
		header = {
			type = "description",
			title = name,
		}
	end
	sliderPush = {
		type = "slider",
		name = GetString(SI_ITEM_ACTION_BANK_DEPOSIT),
		tooltip = GetString(BANKIR_MENU_PUSH_DESC),
		min = 0,
		max = Bankir.SVCommon.bankSlidersMaxValue,
		step = 1,
		width = "full",
		getFunc = function()
			return Bankir.Functions.getEffectiveRule(id, idTypeStr, Bankir.Menu.selectedBankId).push
		end,
		setFunc = function(value)
			setRuleValue("push", value, id, idTypeStr)
		end,
	}
	sliderPull = {
		type = "slider",
		name = GetString(SI_ITEM_ACTION_BANK_WITHDRAW),
		tooltip = GetString(BANKIR_MENU_PULL_DESC),
		min = 0,
		max = Bankir.SVCommon.bankSlidersMaxValue,
		step = 1,
		width = "full",
		getFunc = function()
			return Bankir.Functions.getEffectiveRule(id, idTypeStr, Bankir.Menu.selectedBankId).pull
		end,
		setFunc = function(value)
			setRuleValue("pull", value, id, idTypeStr)
		end,
	}
	pullCheckbox = {
		type = "checkbox",
		name = zo_strformat(GetString(BANKIR_MENU_PULL_IN_STACKS), GetString(SI_ITEM_ACTION_BANK_WITHDRAW)),
		tooltip = zo_strformat(GetString(BANKIR_MENU_PULL_IN_STACKS_DESC), GetString(SI_ITEM_ACTION_BANK_WITHDRAW)),
		width = "full",
		getFunc = function()
			return Bankir.Functions.getEffectiveRule(id, idTypeStr, Bankir.Menu.selectedBankId).pullInStacks
		end,
		setFunc = function(value)
			setRuleValue("pullInStacks", value, id, idTypeStr)
		end,
	}
	return header, sliderPush, sliderPull, pullCheckbox
end

local function makeWidgetsForTypes(typesData, useHeader, useQuality)
	if useHeader == nil then useHeader = true end
	
	local controls = {}
	for i, typeData in ipairs(typesData) do
		local id = typeData.id
		local idTypeStr = typeData.idTypeStr
		local header, sliderPush, sliderPull, pullCheckbox = makeIdTypeSliders(id, idTypeStr, useHeader)
		table.insert(controls, header)
		table.insert(controls, sliderPush)
		table.insert(controls, sliderPull)
		table.insert(controls, pullCheckbox)
		if useQuality == nil then
			for i = 1, #Bankir.Data.qualityRuledItemTypes[idTypeStr] do
				if Bankir.Data.qualityRuledItemTypes[idTypeStr][i] == id then
					useQuality = true
					break
				end
			end
		end
		if useQuality then
			local qualityDropdown = makeQualityDropdown(id, idTypeStr)
			table.insert(controls, qualityDropdown)
		end
		table.insert(controls, dividerSmall)
		if Bankir.Data.childrenTable[idTypeStr][id] then
			for childTypeStr in pairs(Bankir.Data.childrenTable[idTypeStr][id]) do
				local list = Bankir.Data.childrenTable[idTypeStr][id][childTypeStr]
				for i, childId in ipairs(list) do
					local childControls = makeWidgetsForTypes(
						{{ id = childId, idTypeStr = childTypeStr }}, false, useQuality)
					for _, childControl in pairs(childControls) do
						table.insert(controls, childControl)
					end
				end
			end
		end
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
					return Bankir.SVServer.ResearchCharactersList[charData.id] ~= nil
				end,
				setFunc = function(value)
					Bankir.SVServer.ResearchCharactersList[charData.id] = value and true or nil
				end,
				disabled = function()
					return LCK == nil
				end,
			})
		end
	end
	return controls
end

function Bankir.createProcessButton(processFunc)
	local name = "BankirProcessButtonWindow"
	
	wnd = WINDOW_MANAGER:CreateControl(name, GuiRoot, CT_TOPLEVELCONTROL)
	--setWindowSize()
	wnd:SetClampedToScreenInsets(10)
	wnd:SetAnchor(TOPLEFT, ZO_PlayerBankMenu, BOTTOMLEFT, 0, 0)
	wnd:SetDimensionConstraints(60, 60)
	wnd:SetMovable(true)
	wnd:SetMouseEnabled(true)
	wnd:SetClampedToScreen(true)
	wnd:SetTopmost(true)
	wnd:SetHidden(true)
	
	local bg = WINDOW_MANAGER:CreateControl(name .. "Bg", wnd, CT_BACKDROP)
	bg:SetAnchorFill(wnd)
	bg:SetCenterColor(0, 0, 0, 0.5)
	bg:SetEdgeColor(0, 0, 0, 0)
	
	local btn = WINDOW_MANAGER:CreateControlFromVirtual(name .. "Button", wnd, "ZO_DefaultButton")
	btn.title = GetString(BANKIR_START_QUEUE_MANUALLY)
	--btn:SetNormalTexture("/esoui/art/guild/gamepad/gp_guild_options_changeicon.dds")
	btn:SetPressedTexture("/esoui/art/guild/gamepad/gp_guild_options_changeicon.dds")
	btn:SetState(1, true)
	btn:SetWidth(60)
	btn:SetHeight(60)
	btn:SetAnchor(TOPLEFT, wnd, TOPLEFT, 0, 0)
	
	local function onProcessButtonClick()
		processFunc()
	end
	
	local function onProcessButtonMouseEnter(button)
		if button.title then
			ZO_Tooltips_ShowTextTooltip(button, TOP, button.title)
		end
	end
	
	local function onProcessButtonMouseExit()
		ZO_Tooltips_HideTextTooltip()
	end
	
	btn:SetHandler("OnClicked", onProcessButtonClick)
	btn:SetHandler("OnMouseEnter", onProcessButtonMouseEnter)
	btn:SetHandler("OnMouseExit", onProcessButtonMouseExit)
	
	local fragment = ZO_FadeSceneFragment:New(wnd)
	local bankScene = SCENE_MANAGER:GetScene("bank")
	bankScene:AddFragment(fragment)
	local guildBankScene = SCENE_MANAGER:GetScene("guildBank")
	guildBankScene:AddFragment(fragment)
	
	return wnd
end

Bankir.MenuBuildFunctions = {
	divider = divider,
	dividerSmall = dividerSmall,
	makeHeader = makeHeader,
	makeBankSelector = makeBankSelector,
	makeCurrencyTab = makeCurrencyTab,
	makeRulesProfileSelector = makeRulesProfileSelector,
	makeSelectedProfileLabel = makeSelectedProfileLabel,
	makeSettingsMenu = makeSettingsMenu,
	makeWidgetsForTypes = makeWidgetsForTypes,
	makeLCKSettings = makeLCKSettings,
}
