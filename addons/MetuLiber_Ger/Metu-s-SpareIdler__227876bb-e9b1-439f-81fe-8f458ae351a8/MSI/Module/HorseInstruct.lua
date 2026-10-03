-- MessageMgr.lua
if MSI == nil then MSI = MSI or {} end
local MSI = _G['MSI']

local trainPriorities ={
	RIDING_TRAIN_CARRYING_CAPACITY,
	RIDING_TRAIN_STAMINA,
	RIDING_TRAIN_SPEED,
}
local trainNames = {
	[RIDING_TRAIN_CARRYING_CAPACITY] = "Capacity"
	[RIDING_TRAIN_STAMINA] = "Stamina",
	[RIDING_TRAIN_SPEED] = "Speed",
}

LazyHorseFeed.defaultCharacter = 
{
	["TrainOrder"] = {
		RIDING_TRAIN_CARRYING_CAPACITY,
		RIDING_TRAIN_STAMINA,
		RIDING_TRAIN_SPEED,
	},
	["trainEvenly"] = false,
	["useCharacterSettings"] = false,
}
LazyHorseFeed.default = {
	["accountWideProfile"] = LazyHorseFeed.defaultCharacter,
}


local panel =  
{
     type = "panel",
     name = "Lazy Horse Trainer",
     registerForRefresh = true,
     displayName = "|c8080FF Lazy Horse Trainer|r",
     author = "@Dolgubon"
}
local function shallowCopy (source, destination)
	for k, v in pairs(source) do
		destination[k] = v
	end
end
LazyHorseFeed.localizedStrings = {}
LazyHorseFeed.localizedStrings.SettingsStrings = {}


LazyHorseFeed.localizedStrings.SettingsStrings.nowEditing                   = "You are changing %s settings"
LazyHorseFeed.localizedStrings.SettingsStrings.accountWide                  = "Account Wide"
LazyHorseFeed.localizedStrings.SettingsStrings.characterSpecific            = "Character Specific"

LazyHorseFeed.localizedStrings.SettingsStrings.showAtStation 				= "Show at Station"
LazyHorseFeed.localizedStrings.SettingsStrings.showAtStationTooltip			= "Always show the Set Crafter UI at crafting stations"
LazyHorseFeed.localizedStrings.SettingsStrings.saveLastChoice				= "Save Choices"
LazyHorseFeed.localizedStrings.SettingsStrings.saveLastChoiceTooltip		= "Save the last selected choices"
LazyHorseFeed.localizedStrings.SettingsStrings.closeOnExit                  = "Close on Station Exit"
LazyHorseFeed.localizedStrings.SettingsStrings.closeOnExitTooltip           = "Close the Set Crafter UI when exiting a crafting station"
LazyHorseFeed.localizedStrings.SettingsStrings.useCharacterSettings         = "Use character settings" 
LazyHorseFeed.localizedStrings.SettingsStrings.useCharacterSettingsTooltip  = "Use character specific settings on this character only"
LazyHorseFeed.localizedStrings.SettingsStrings.showToggleButton              = "Always show toggle button"
LazyHorseFeed.localizedStrings.SettingsStrings.showToggleButtonTooltip       = "Show the UI toggle button at all times"

local SettingsStrings = LazyHorseFeed.localizedStrings.SettingsStrings

local options =
{
	{
		type = "header",
		name = function() 
			local profile = SettingsStrings.accountWide
			if LazyHorseFeed.charSavedVars.useCharacterSettings then
				profile = SettingsStrings.characterSpecific
			end
			return  string.format(SettingsStrings.nowEditing, profile)  
		end, -- or string id or function returning a string
	},
	{
		type = "checkbox",
		name = SettingsStrings.useCharacterSettings,
		tooltip = SettingsStrings.useCharacterSettingsTooltip,
		getFunc = function() return LazyHorseFeed.charSavedVars.useCharacterSettings end,
		setFunc = function(value) 
			LazyHorseFeed.charSavedVars.useCharacterSettings = value
			if IsConsoleUI() then
				LazyHorseFeed.consoleSettingsMenu:UpdateControls()
			end
		end,
	},
	{
		type = "divider",
		height = 15,
		alpha = 0.5,
		width = "full"
	},
	
}

function LazyHorseFeed:GetSettings()
	if LazyHorseFeed.charSavedVars.useCharacterSettings then
		return LazyHorseFeed.charSavedVars
	else
		return LazyHorseFeed.savedvars.accountWideProfile
	end
end

local function trainingReset()
	local date = {}
	local till = {}
	local day = 86400
	local hour = 3600
	local seconds = GetTimeUntilCanBeTrained()/1000
	local minutes = math.floor( seconds / 60)
	local hours = math.floor(minutes  / 60)
	minutes = minutes % 60
	d("Already trained today. "..hours.."h "..minutes.."m until you can train again")
end


local function HandleStableOpen()
	if GetTimeUntilCanBeTrained() > 0 then
		trainingReset()
		-- SCENE_MANAGER:Show('hud')
		return
	end
	if GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) <250 then
		d("You do not have enough gold to train your riding skill")
		return
	end
	local inventoryBonus ,_,staminaBonus,_,speedBonus = GetRidingStats()

	local trainLevels = 
	{
		[RIDING_TRAIN_SPEED] = speedBonus,
		[RIDING_TRAIN_CARRYING_CAPACITY] = inventoryBonus,
		[RIDING_TRAIN_STAMINA] = staminaBonus,
	}
	if LazyHorseFeed:GetSettings().trainEvenly then
		local minVal = 60
		local minStat = 0
		for i = 1, 3 do
			if trainLevels[i] < minVal then
				minStat = i
				minVal = trainLevels[i]
			end
		end
		if minStat > 0 then
			TrainRiding(minStat)
			d("Trained "..trainNames[minStat])
			SCENE_MANAGER:Show('hud')
			return
		end
	end
	for i = 1, #LazyHorseFeed:GetSettings().TrainOrder do
		if trainLevels[LazyHorseFeed:GetSettings().TrainOrder[i]]~=60 then
			TrainRiding(LazyHorseFeed:GetSettings().TrainOrder[i])
			d("Trained "..trainNames[LazyHorseFeed:GetSettings().TrainOrder[i]])
			SCENE_MANAGER:Show('hud')
			return
		end
	end
	d("Max training level already")
end


local function HandleChatterBegin(eventCode, optionCount)
	for i = 1, optionCount do
		local optionString, optionType = GetChatterOption(i)
		if optionString == "View Stable" then
			SelectChatterOption(i)
		end
	end
end


local function addToControlTable(newOption, t)
	t.indexed[#t.indexed + 1 ] = newOption
	t.nameMap[newOption.label] = newOption
	newOption.conversionIndex = #t.indexed
end
local function LAMtoHASDropdownConverter(option, controlTable)
	local newOption = {
		type = LibHarvensAddonSettings.ST_DROPDOWN,
		label = option.name,
		default = option.default,
		-- setFunction = option.setFunc,
		getFunction = option.getFunc,
		tooltip = option.tooltip,
		disable = option.disabled,
	}

	newOption.setFunction = function(combobox, name, item) option.setFunc(item.data) end
	
	local items = {}
	local labelMap = {}
	if not option.choicesValues then
		option.choicesValues = option.choices
	end
	for i = 1, # option.choices do
		items[i] = {name = option.choices[i], data = option.choicesValues[i]}
		if option.choicesValues[i] then
			labelMap[items[i].data] = items[i].name
		end
	end
	newOption.items = items
	newOption.getFunction = function() return labelMap[option.getFunc()]  end
	addToControlTable(newOption, controlTable)
end

local function convertlamToHasTable(optionsTable, controlTable)
	local LAMtoHAS = {
		slider = LibHarvensAddonSettings.ST_SLIDER,
		header = LibHarvensAddonSettings.ST_SECTION,
		checkbox = LibHarvensAddonSettings.ST_CHECKBOX,
		colorpicker = LibHarvensAddonSettings.ST_COLOR,
		button = LibHarvensAddonSettings.ST_BUTTON,
		editbox = LibHarvensAddonSettings.ST_EDIT,
	}
	local LAMtoHASSpecial = {
		dropdown = LAMtoHASDropdownConverter,
		submenu = function(option, controlTable) convertlamToHasTable(option.controls, controlTable) end
	}
	local controlTable = controlTable or {
		indexed = {},
		nameMap = {},
	}
	
	-- LAMHASMissing = {}
	
	for i, entry in ipairs(optionsTable) do
		local newType = LAMtoHAS[entry.type]
		if newType and not entry.isPCOnly then
			local newOption = {
				type = newType,
				label = entry.name,
				default = entry.default,
				setFunction = entry.setFunc,
				getFunction = entry.getFunc,
				tooltip = entry.tooltip,
				min = entry.min,
				max = entry.max,
				step = entry.step,
				disable = entry.disabled,
				clickHandler = entry.func,
				buttonText = entry.name,
			}
			addToControlTable(newOption, controlTable)
			-- settings:AddSetting(newOption)
		elseif LAMtoHASSpecial[entry.type] then
			LAMtoHASSpecial[entry.type](entry, controlTable)
		else
			-- LAMHASMissing[entry.type] = entry.type
		end
	end
	return controlTable
end


function LazyHorseFeed:Initialize()
	EVENT_MANAGER:RegisterForEvent(LazyHorseFeed.name, EVENT_CHATTER_BEGIN, HandleChatterBegin)
	EVENT_MANAGER:RegisterForEvent(LazyHorseFeed.name, EVENT_STABLE_INTERACT_START, HandleStableOpen)
	LazyHorseFeed.savedvars = ZO_SavedVars:NewAccountWide("lazyhorsefeedsavedvars", LazyHorseFeed.version, nil, LazyHorseFeed.default)

	LazyHorseFeed.charSavedVars = ZO_SavedVars:NewCharacterIdSettings("lazyhorsefeedsavedvars",
	LazyHorseFeed.version, nil, LazyHorseFeed.savedvars.accountWideProfile) 
	local tooltips = {
		"Select the training you want to complete first",
		"Select the training you want to complete second",
		"Select the training you want to complete third",
	}
	if IsConsoleUI() then
		tooltips = "This training will be completed third"
	end
	
	table.insert(options, 
	{
		type = "checkbox",
		name = "Train stats evenly",
		tooltip = "Always train the lowest riding stat, resulting in stats being trained evenly" , 
		getFunc = function() return LazyHorseFeed:GetSettings().trainEvenly end,
		setFunc = function(value) 
			LazyHorseFeed:GetSettings().trainEvenly = value 
		end,
	})
	for i = 1, #trainPriorities do
		table.insert(options ,
			{
				type = "dropdown",
				name = "Train "..i..":",
				tooltip = tooltips[i],
				choices = trainNames,
				getFunc = function() return trainNames[LazyHorseFeed:GetSettings().TrainOrder[i]] end,
				setFunc = function(value) 
					local TrainOrder = LazyHorseFeed:GetSettings().TrainOrder
					local newNum
					for k , v in pairs(trainNames) do
						if v==value then
							newNum = k
						end
					end
					local oldSpot 
					for i = 1, #LazyHorseFeed:GetSettings().TrainOrder do
						if TrainOrder[i] == newNum then
							oldSpot = i
						end
					end
					local currentPriority = TrainOrder[i]
					if not IsConsoleUI() then
						TrainOrder[i] = newNum
						TrainOrder[oldSpot] = currentPriority
					else
						TrainOrder[i] = newNum
						if TrainOrder[1] == newNum then
							TrainOrder[2]  = (newNum + 1)%3 + 1
						end
						TrainOrder[3] = 6- TrainOrder[1] - TrainOrder[2]
						LazyHorseFeed.consoleSettingsMenu:UpdateControls()
					end
					-- TrainOrder[i] = oldSpot
					-- TrainOrder[oldSpot] = oldNum
				end,
				disabled = function() return (i == 3 and IsConsoleUI()) or LazyHorseFeed:GetSettings().trainEvenly end
			}
		)
	end
	if not IsConsoleUI() then
		local LAM = LibAddonMenu2
		LAM:RegisterAddonPanel("LazyHorseFeedPanel", panel)
		LAM:RegisterOptionControls("LazyHorseFeedPanel", options)
	else
		local controlTable = convertlamToHasTable(options)
		local LHA = LibHarvensAddonSettings
		local options = {
			-- allowDefaults = true, --will allow users to reset the settings to default values
			allowRefresh = true, --if this is true, when one of settings is changed, all other settings will be checked for state change (disable/enable)
			defaultsFunction = function() --this function is called when allowDefaults is true and user hit the reset button
			  d("Reset")
			end,
		}

		local settings = LHA:AddAddon("|c8080FFLazy Horse Trainer|r", options)
		if not settings then
		   return
		end
		LazyHorseFeed.consoleSettingsMenu = settings
		for i = 1, #controlTable.indexed do
			settings:AddSetting(controlTable.indexed[i])
		end
	end
end






 
function LazyHorseFeed.OnAddOnLoaded(event, addonName)
	if addonName == LazyHorseFeed.name then
		LazyHorseFeed:Initialize()
	end
end
 
EVENT_MANAGER:RegisterForEvent(LazyHorseFeed.name, EVENT_ADD_ON_LOADED, LazyHorseFeed.OnAddOnLoaded)



--[[

@Dolgubon could it be a sync problem, where you may have to wait for a mail to be completely sent before moving on to other tasks? (like guild bank, where nothing works till it's actually finished an action)

manavortex @manavortex Mar 13 10:14
afaik the mailbox has an internal table, and that doesn't automatically get rebuilt when you delete a mail.
It might be that that gets knocked over

Baertram @Baertram Mar 13 10:26
Postmaster is able to mass take items from mails + delete them. So maybe look into this code or ask the dev.

Michael Auerswald @flipswitchingmonkey Mar 13 14:25
@Dolgubon found it, but it's not fully implemented yet, unfortunately. It has some nice functions in it already, but alas, no list of bosses or way to track them (yet)


]]