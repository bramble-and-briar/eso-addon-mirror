UniversalTracker = UniversalTracker or {}

local settings = nil
local settingPages = {
	mainMenu = {},
	setupList = {},
	newSetup = {},
	trackedList = {},
	newTracker = {
		general = {},
		visiblity = {},
		abilities = {},
		position = {},
		columns = {},
		bar = {},
		text = {
			label = nil,
			duration = {},
			stacks = {},
			abilityName = {},
			unitName = {},
		},
		editedNav = {},
		newNav = {},
	},
}

local editIndex = -1
local isCharacterSettings = false

local firstAbilityIDIndex = 0

-- New/updated tracker settings. Local until "save"
-- These are default values for a new tracker.
local newTracker = {
	id = -1,
	name = "",
	type = "Compact",
	targetType = "Player",
	overrideTexturePath = "",
	requiredSetID = "",
	requiredZoneID = "",
	requiredSkillID = "",
	appliedBySelf = false,
	hideInactive = false,
	hideActive = false,
	hidden = false,
	x = 0,
	y = 0,
	scale = 1,
	listSettings = {
		columns = 1,
		horizontalOffsetScale = 1,
		verticalOffsetScale = 1,
	},
	barSettings = {
		alignment = "Left",
		length = 200,
		sameEndColor = true,
		startColor = {
			r = 0,
			g = 1,
			b = 0,
			a = 1,
		},
		endColor = {
			r = 1,
			g = 0,
			b = 0,
			a = 1,
		},
		backgroundColor = {
			r = 0.467,
			g = 0.467,
			b = 0.467,
			a = 1,
		},
		edgeColor = {
			r = 1,
			g = 0.8745,
			b = 0,
			a = 1,
		},
	},
	textSettings = {
		duration = {
			overrideDuration = "",
			color = {
				r = 1,
				g = 1,
				b = 1,
				a = 1,
			},
			textScale = 1,
			x = -5,
			y = 0,
			hidden = false,
		},
		stacks = {
			color = {
				r = 1,
				g = 1,
				b = 1,
				a = 1,
			},
			textScale = 1,
			x = -5,
			y = 0,
			hidden = false,
		},
		abilityLabel = {
			color = {
				r = 1,
				g = 1,
				b = 1,
				a = 1,
			},
			textScale = 1,
			x = 5,
			y = 0,
			hidden = false,
		},
		unitLabel = {
			color = {
				r = 1,
				g = 1,
				b = 1,
				a = 1,
			},
			textScale = 1,
			x = 0,
			y = 0,
			hidden = false,
			accountName = true,
		},
	},
	abilityIDs = { --abilityIDs are values. indexes increase by 1 from 1. Each setting gets an index.
		[1] = "",
	},
	hashedAbilityIDs = { --abilityIDs are keys

	},
}

local newSetup = {
	name = "New Setup",
	id = -1,
	trackerIDList = {}
}

local function createHashedIDList(settingAbilityIDs)
	local hashedAbilityIDs = {}
	for i = #settingAbilityIDs, 1, -1 do 
		if tonumber(settingAbilityIDs[i]) and tonumber(settingAbilityIDs[i]) > 0 then
			hashedAbilityIDs[tonumber(settingAbilityIDs[i])] = true
		else
			table.remove(settingAbilityIDs, i)
		end
	end
	return hashedAbilityIDs
end

local function loadMenu(menu, shouldReturn)
	if settings then
		settings:RemoveAllSettings()
		settings:AddSettings(menu, nil, true)

		if shouldReturn then
			LibHarvensAddonSettings:GoBack()
		end
	end
end

--Appends table2 to table1
local function appendTables(table1, table2)
	if type(table2) == "table" then
		for _, v in ipairs(table2) do
			table.insert(table1, v)
		end
	elseif table2 ~= nil then
		table.insert(table1, table2)
	end
end

local function updateTrackerSettingList()
	--Modify the provided settaings as needed to fit tracker type.
	local loadedSettingsList = {}
	appendTables(loadedSettingsList, settingPages.newTracker.general)
	appendTables(loadedSettingsList, settingPages.newTracker.visiblity)
	appendTables(loadedSettingsList, settingPages.newTracker.abilities)
	appendTables(loadedSettingsList, settingPages.newTracker.position)
	if newTracker.type ~= "Floating" and (newTracker.targetType == "Boss" or newTracker.targetType == "All" or newTracker.targetType == "Group") then
		appendTables(loadedSettingsList, settingPages.newTracker.columns)
	end
	if newTracker.type == "Bar" then
		appendTables(loadedSettingsList, settingPages.newTracker.bar)
	end
	appendTables(loadedSettingsList, settingPages.newTracker.text.duration)
	if newTracker.type == "Compact" then
		appendTables(loadedSettingsList, settingPages.newTracker.text.stacks)
	end
	if newTracker.type == "Bar" or newTracker.type == "Compact" then
		appendTables(loadedSettingsList, settingPages.newTracker.text.abilityName)
		appendTables(loadedSettingsList, settingPages.newTracker.text.unitName)
	end
	if editIndex == -1 then
		appendTables(loadedSettingsList, settingPages.newTracker.newNav)
	else
		appendTables(loadedSettingsList, settingPages.newTracker.editedNav)
	end
	
	loadMenu(loadedSettingsList, false)
end

local function getNextAvailableIndex(charSettings, isSetup)
	local index = 1
	if isSetup then
		if not charSettings then
			while UniversalTracker.savedVariables.setupList[index] do
				index = index + 1
			end
		else
			while UniversalTracker.characterSavedVariables.setupList[index] do
				index = index + 1
			end
		end
	else
		if not charSettings then
			while UniversalTracker.savedVariables.trackerList[index] do
				index = index + 1
			end
		else
			while UniversalTracker.characterSavedVariables.trackerList[index] do
				index = index + 1
			end
		end
	end
	return index
end

local function makeAnnouncement(announcementString1, announcementString2)
	local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.COLLECTIBLE_UNLOCKED)
	messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_COLLECTIBLES_UPDATED)
	messageParams:SetText(announcementString1, announcementString2)
	messageParams:SetLifespanMS(3000)
	CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
end

function UniversalTracker.loadSetup(id)
	local idList = nil
	for k, v in pairs(UniversalTracker.savedVariables.setupList) do
		if v.id == id then
			idList = v.trackerIDList
			break
		end
	end
	if not idList then
		for k, v in pairs(UniversalTracker.characterSavedVariables.setupList) do
			if v.id == id then
				idList = v.trackerIDList
			end
		end
	end

	if idList == nil then 
		UniversalTracker.chat:Print("Could not locate setup with id "..tostring(id))
		return
	end

	for k, v in pairs(UniversalTracker.savedVariables.trackerList) do
		if v and v.name and v.id then
			v.hidden = not idList[v.id]
			if UniversalTracker.Controls[v.id] and UniversalTracker.Controls[v.id].object then
				UniversalTracker.Controls[v.id].object:SetHidden(v.hidden)
			elseif UniversalTracker.Controls[v.id] and UniversalTracker.Controls[v.id][1] and UniversalTracker.Controls[v.id][1].object then
				UniversalTracker.refreshList(v, string.gsub(UniversalTracker.Controls[v.id][1].unitTag, "%d+", ""))
			end
		end
	end
	for k, v in pairs(UniversalTracker.characterSavedVariables.trackerList) do
		if v and v.name and v.id then
			v.hidden = not idList[v.id]
			if UniversalTracker.Controls[v.id] and UniversalTracker.Controls[v.id].object then
				UniversalTracker.Controls[v.id].object:SetHidden(v.hidden)
			elseif UniversalTracker.Controls[v.id] and UniversalTracker.Controls[v.id][1] and UniversalTracker.Controls[v.id][1].object then
				UniversalTracker.refreshList(v, string.gsub(UniversalTracker.Controls[v.id][1].unitTag, "%d+", ""))
			end
		end
	end

end

--It might be expensive to call this repeatedly on slider settings, but this
--makes the code more maintainable and I don't expect performance issues
--when the player is sitting in a menu.
UniversalTracker.previewTrackerInfo = ZO_DeepTableCopy(newTracker)
local function previewTracker()
	UniversalTracker.previewTrackerInfo = ZO_DeepTableCopy(newTracker)
	UniversalTracker.previewTrackerInfo.id = -999

	HUD_FRAGMENT.state = "shown"
	UniversalTracker.InitSingleDisplay(UniversalTracker.previewTrackerInfo)
	HUD_FRAGMENT.state = "hidden"
	EVENT_MANAGER:RegisterForUpdate(UniversalTracker.name.."PreviewTracker", 2500, function()
		EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name.."PreviewTracker")
		UniversalTracker.ReleaseSingleDisplay(UniversalTracker.previewTrackerInfo)
	end)

end

local function toWhiteString(str) return "|cFFFFFF"..str.."|r" end
local function toYellowString(str) return "|cFFFF00"..str.."|r" end

function UniversalTracker.InitSettings()
	if not LibHarvensAddonSettings then return end

	settings = LibHarvensAddonSettings:AddAddon("Universal Effect Tracker")

	---------------------------------------
	---				Sections			---
	---------------------------------------

	local setupSection = {type = LibHarvensAddonSettings.ST_SECTION,label = toWhiteString("Setups")}
	local trackerSection = {type = LibHarvensAddonSettings.ST_SECTION,label = toWhiteString("Trackers")}
	local printSection = {type = LibHarvensAddonSettings.ST_SECTION,label = toWhiteString("Print")}
	local eventSection = {type = LibHarvensAddonSettings.ST_SECTION,label = toWhiteString("Event Listener")}
	local presetSection = {type = LibHarvensAddonSettings.ST_SECTION, label = toWhiteString("Presets")}

	---------------------------------------
	---				LABELS				---
	---------------------------------------

	local setupLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Setups")}
	local trackerLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Trackers")}
	local navLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Navigation")}

	local accountTrackersLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Account Trackers")}
	local characterTrackersLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Character Trackers")}

	local editSetupLabel = { type = LibHarvensAddonSettings.ST_LABEL, label = toYellowString("Edit Setup")}
	local accountSetupsLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Account Setups")}
	local characterSetupsLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Character Setups")}

	local generalLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("General")}
	local visibilityLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Visibility")}
	local abilityIDListLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Tracked abilityIDs")}
	local positionLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Position")}
	local listSettingsLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("List Settings")}
	local barSettingsLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Bar Settings")}
	local durationLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Duration")}
	local stacksLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Stacks")}
	local abilityNameLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Ability Name")}
	local unitNameLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Unit Name")}

	local printLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Print")}
	local eventLabel = {type = LibHarvensAddonSettings.ST_LABEL,label = toYellowString("Event Listener")}
	local presetLabel = {type = LibHarvensAddonSettings.ST_LABEL, label = toYellowString("Presets")}

	-----------------------------------------------------------
	---		Early Declarations for Self/Cross References	---
	-----------------------------------------------------------
	
	local setNewAbilityID = nil
	local add1AbilityID = nil
	local deleteTracker = nil
	local deleteSetup = nil
	local loadSetup = nil
	local copyTrackerToAccount, copyTrackerToCharacter = nil, nil
	local copySetupToAccount, copySetupToCharacter = nil, nil
	local setNewTrackerSaveType = nil
	local columnCount, horizontalSpacing, verticalSpacing = nil, nil, nil
	local newScale, newYOffset, newXOffset = nil, nil, nil
	local hideDuration, durationFontColor, durationFontScale, durationOverride, durationXOffset, durationYOffset = nil, nil, nil, nil, nil, nil
	local hideStacks, stackFontColor, stackFontScale, stackXOffset, stackYOffset = nil, nil, nil, nil, nil
	local hideAbilityLabel, abilityLabelFontColor, abilityLabelFontScale, abilityLabelXOffset, abilityLabelYOffset  = nil, nil, nil, nil, nil
	local hideunitLabel, preferPlayerName, unitLabelFontColor, unitLabelFontScale, unitLabelXOffset, unitLabelYOffset  = nil, nil, nil, nil, nil, nil

	---------------------------------------
	---			Navigation Buttons		---
	---------------------------------------

	local setupListMenuButton = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "SETUP LIST",
		buttonText = "SETUPS",
		tooltip = "Load, View, Edit, and delete from your list of setups.\n\
					A setup is a collection of trackers. Loading a setup enables all trackers in the collection and disables all other trackers.",
		clickHandler = function(control)
			loadMenu(settingPages.setupList, true)

			local insertIndex = settings:GetIndexOf(accountSetupsLabel, true) + 1

			for k, v in pairs(UniversalTracker.savedVariables.setupList) do
				if v and v.name then
					settings:AddSetting({
						type = LibHarvensAddonSettings.ST_BUTTON,
						label = UniversalTracker.savedVariables.setupList[k].name, 
						buttonText = UniversalTracker.savedVariables.setupList[k].name, 
						tooltip = "Load or Edit this setup.",
						clickHandler = function(control)
							editIndex = k
							isCharacterSettings = false
							newSetup = ZO_DeepTableCopy(UniversalTracker.savedVariables.setupList[editIndex])
							loadMenu(settingPages.newSetup, false)

							--Remove the save destination
							settings:RemoveSettings(#settings.settings - 2, 1, false)

							local insertIndex = settings:GetIndexOf(accountTrackersLabel, true) + 1

							--Add the trackers to toggle for the setup.
							for k, v in pairs(UniversalTracker.savedVariables.trackerList) do
								if v and v.id and v.name then
									settings:AddSetting({
										type = LibHarvensAddonSettings.ST_CHECKBOX,
										label = v.name,
										tooltip = "Choose whether to include this tracker with the setup.",
										getFunction = function() if newSetup.trackerIDList[v.id] then return true else return false end end,
										setFunction = function(value)
											if value == true then
												newSetup.trackerIDList[v.id] = true
											else
												newSetup.trackerIDList[v.id] = nil
											end						
										end,
										default = false
									}, insertIndex, false)
								end
							end

							insertIndex = settings:GetIndexOf(characterTrackersLabel, true) + 1

							for k, v in pairs(UniversalTracker.characterSavedVariables.trackerList) do
								if v and v.id and v.name then
									settings:AddSetting({
										type = LibHarvensAddonSettings.ST_CHECKBOX,
										label = v.name,
										tooltip = "Choose whether to include this tracker with the setup.",
										getFunction = function() if newSetup.trackerIDList[v.id] then return true else return false end end,
										setFunction = function(value)
											if value == true then
												newSetup.trackerIDList[v.id] = true
											else
												newSetup.trackerIDList[v.id] = nil
											end						
										end,
										default = false
									}, insertIndex, false)
								end
							end

							settings:AddSetting(loadSetup, 3, false)

							settings:AddSettings({deleteSetup, copySetupToCharacter, copySetupToAccount}, #settings.settings - 1, false)

						end
					}, insertIndex, false)
				end
			end

			insertIndex = settings:GetIndexOf(characterSetupsLabel, true) + 1

			for k, v in pairs(UniversalTracker.characterSavedVariables.setupList) do
				if v and v.name then
					settings:AddSetting({
						type = LibHarvensAddonSettings.ST_BUTTON,
						label = UniversalTracker.characterSavedVariables.setupList[k].name, 
						buttonText = UniversalTracker.characterSavedVariables.setupList[k].name, 
						tooltip = "Load or Edit this setup.",
						clickHandler = function(control)
							editIndex = k
							isCharacterSettings = true
							newSetup = ZO_DeepTableCopy(UniversalTracker.characterSavedVariables.setupList[editIndex])
							loadMenu(settingPages.newSetup, false)

							--Remove the save destination
							settings:RemoveSettings(6, 1, false)

							local insertIndex = settings:GetIndexOf(accountTrackersLabel, true) + 1

							--Add the trackers to toggle for the setup.
							for k, v in pairs(UniversalTracker.savedVariables.trackerList) do
								if v and v.id and v.name then
									settings:AddSetting({
										type = LibHarvensAddonSettings.ST_CHECKBOX,
										label = v.name,
										tooltip = "Choose whether to include this tracker with the setup.",
										getFunction = function() if newSetup.trackerIDList[v.id] then return true else return false end end,
										setFunction = function(value)
											if value == true then
												newSetup.trackerIDList[v.id] = true
											else
												newSetup.trackerIDList[v.id] = nil
											end						
										end,
										default = false
									}, insertIndex, false)
								end
							end

							insertIndex = settings:GetIndexOf(characterTrackersLabel, true) + 1

							for k, v in pairs(UniversalTracker.characterSavedVariables.trackerList) do
								if v and v.id and v.name then
									settings:AddSetting({
										type = LibHarvensAddonSettings.ST_CHECKBOX,
										label = v.name,
										tooltip = "Choose whether to include this tracker with the setup.",
										getFunction = function() if newSetup.trackerIDList[v.id] then return true else return false end end,
										setFunction = function(value)
											if value == true then
												newSetup.trackerIDList[v.id] = true
											else
												newSetup.trackerIDList[v.id] = nil
											end						
										end,
										default = false
									}, insertIndex, false)
								end
							end

							settings:AddSetting(loadSetup, 3, false)

							settings:AddSettings({deleteSetup, copySetupToCharacter, copySetupToAccount}, #settings.settings - 1, false)

						end
					}, insertIndex, false)
				end
			end
		end
	}

	local addNewSetupButton = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "NEW SETUP",
		buttonText = "ADD NEW",
		tooltip = "Create a new setup.\n\
					A setup is a collection of trackers. Loading a setup enables all trackers in the collection and disables all other trackers.",
		clickHandler = function(control)
			--reset local variables
			newSetup = {
				name = "New Setup",
				id = -1,
				trackerIDList = {}
			}

			loadMenu(settingPages.newSetup, true)
			isCharacterSettings = false
			
			for k, v in pairs(UniversalTracker.savedVariables.trackerList) do
				if v and v.id and v.name then
					settings:AddSetting({
						type = LibHarvensAddonSettings.ST_CHECKBOX,
						label = v.name,
						tooltip = "Choose whether to include this tracker with the setup.",
						getFunction = function() if newSetup.trackerIDList[v.id] then return true else return false end end,
						setFunction = function(value)
							if value == true then
								newSetup.trackerIDList[v.id] = true
							else
								newSetup.trackerIDList[v.id] = nil
							end						
						end,
						default = false
					}, 4, false)
				end
			end

			for k, v in pairs(UniversalTracker.characterSavedVariables.trackerList) do
				if v and v.id and v.name then
					settings:AddSetting({
						type = LibHarvensAddonSettings.ST_CHECKBOX,
						label = v.name,
						tooltip = "Choose whether to include this tracker with the setup.",
						getFunction = function() if newSetup.trackerIDList[v.id] then return true else return false end end,
						setFunction = function(value)
							if value == true then
								newSetup.trackerIDList[v.id] = true
							else
								newSetup.trackerIDList[v.id] = nil
							end						
						end,
						default = false
					}, #settings.settings - 3, false)
				end
			end

			editIndex = -1
		end
	}

	-- Helper function to reduce clutter between account/character saved variables
	local function loadTrackerList(savedVarTrackerListTable, isCharSettings)
		local insertIndex
		if isCharSettings then
			insertIndex = settings:GetIndexOf(characterTrackersLabel, true) + 1
		else
			insertIndex = settings:GetIndexOf(accountTrackersLabel, true) + 1
		end

		for k, v in pairs(savedVarTrackerListTable) do
			if v.name then --avoids creating blank entries in the list.
				settings:AddSetting({
					type = LibHarvensAddonSettings.ST_BUTTON,
					label = savedVarTrackerListTable[k].name, 
					buttonText = savedVarTrackerListTable[k].name, 
					tooltip = "Edit this tracker.",
					clickHandler = function(control)
						editIndex = k
						isCharacterSettings = isCharSettings
						newTracker = ZO_DeepTableCopy(savedVarTrackerListTable[editIndex])

						updateTrackerSettingList()

						--remove the base ability ID
						settings:RemoveSettings(firstAbilityIDIndex, 1, false)

						--dynamically add the extra ability IDs
						for i = 1, (#savedVarTrackerListTable[editIndex].abilityIDs) do
							local newIndex = firstAbilityIDIndex + i - 1
							settings:AddSetting({
								type = setNewAbilityID.type,
								label = setNewAbilityID.label,
								tooltip = setNewAbilityID.tooltip,
								textType = setNewAbilityID.textType,
								maxChars = setNewAbilityID.maxChars,
								getFunction = function() return newTracker.abilityIDs[i] end,
								setFunction = function(value) 
									newTracker.abilityIDs[i] = value
								end,
								default = newTracker.abilityIDs[i]
							}, newIndex, false)
						end
					end
				}, insertIndex, false)
			end
		end
	end

	local trackedListMenuButton = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "TRACKER LIST",
		buttonText = "TRACKERS",
		tooltip = "View, Edit, and delete from your list of tracked effects.",
		clickHandler = function(control)
			loadMenu(settingPages.trackedList, true)

			loadTrackerList(UniversalTracker.savedVariables.trackerList, false)
			loadTrackerList(UniversalTracker.characterSavedVariables.trackerList, true)
		end
	}
	local addNewTrackerButton = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "NEW TRACKER",
		buttonText = "ADD NEW",
		tooltip = "Create a new effect tracker.",
		clickHandler = function(control)
			--reset local variables
			newTracker = {
				id = -1,
				name = "",
				type = "Compact",
				targetType = "Player",
				overrideTexturePath = "",
				requiredSetID = "",
				requiredZoneID = "",
				requiredSkillID = "",
				appliedBySelf = false,
				hideInactive = false,
				hideActive = false,
				hidden = false,
				x = 0,
				y = 0,
				scale = 1,
				listSettings = {
					columns = 1,
					horizontalOffsetScale = 1,
					verticalOffsetScale = 1,
				},
				barSettings = {
					alignment = "Left",
					length = 200,
					sameEndColor = true,
					startColor = {
						r = 0,
						g = 1,
						b = 0,
						a = 1,
					},
					endColor = {
						r = 1,
						g = 0,
						b = 0,
						a = 1,
					},
					backgroundColor = {
						r = 0.467,
						g = 0.467,
						b = 0.467,
						a = 1,
					},
					edgeColor = {
						r = 1,
						g = 0.8745,
						b = 0,
						a = 1,
					},
				},
				textSettings = {
					duration = {
						overrideDuration = "",
						color = {
							r = 1,
							g = 1,
							b = 1,
							a = 1,
						},
						textScale = 1,
						x = -5,
						y = 0,
						hidden = false,
					},
					stacks = {
						color = {
							r = 1,
							g = 1,
							b = 1,
							a = 1,
						},
						textScale = 1,
						x = -5,
						y = 0,
						hidden = false,
					},
					abilityLabel = {
						color = {
							r = 1,
							g = 1,
							b = 1,
							a = 1,
						},
						textScale = 1,
						x = 5,
						y = 0,
						hidden = false,
					},
					unitLabel = {
						color = {
							r = 1,
							g = 1,
							b = 1,
							a = 1,
						},
						textScale = 1,
						x = 0,
						y = 0,
						hidden = false,
						accountName = true,
					},
				},
				abilityIDs = { [1] = "" }, --abilityIDs are values
				hashedAbilityIDs = {}, --abilityIDs are keys
			}

			--Modify the provided settaings as needed to fit the default tracker type (Compact, Player)
			local loadedSettingsList = {}
			appendTables(loadedSettingsList, settingPages.newTracker.general)
			appendTables(loadedSettingsList, settingPages.newTracker.visiblity)
			appendTables(loadedSettingsList, settingPages.newTracker.abilities)
			appendTables(loadedSettingsList, settingPages.newTracker.position)
			appendTables(loadedSettingsList, settingPages.newTracker.text.duration)
			appendTables(loadedSettingsList, settingPages.newTracker.text.stacks)
			appendTables(loadedSettingsList, settingPages.newTracker.text.abilityName)
			appendTables(loadedSettingsList, settingPages.newTracker.text.unitName)
			appendTables(loadedSettingsList, settingPages.newTracker.newNav)
			
			loadMenu(loadedSettingsList, true)

			isCharacterSettings = false

			editIndex = -1
		end
	}
	local returnToMainMenuButton = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "BACK",
		buttonText = "BACK",
		tooltip = "Return to main menu.",
		clickHandler = function(control)
			loadMenu(settingPages.mainMenu, false)
		end
	}

	---------------------------------------
	---				Setups		  		---
	---------------------------------------

	local setNewSetupName = {
		type = LibHarvensAddonSettings.ST_EDIT,
		label = "Setup Name",
		tooltip = "Enter your custom name for this tracker\n",
		getFunction = function() return newSetup.name end,
		setFunction = function(value)
			newSetup.name = value
		end,
		default = "New Setup",
	}
	local setupSaveButton = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "SAVE",
		buttonText = "SAVE",
		tooltip = "Save Changes and Return to main menu.",
		clickHandler = function(control)
			local index
			if editIndex >= 0 then
				index = editIndex
			else
				index = getNextAvailableIndex(isCharacterSettings, true)
			end

			--Error checking
			if newSetup.name == "" then
				makeAnnouncement("You must enter a name for your setup.", "A copy was not created.")
				return
			end

			if isCharacterSettings then
				UniversalTracker.characterSavedVariables.setupList[index] = ZO_DeepTableCopy(newSetup)
				if editIndex < 0 then
					UniversalTracker.characterSavedVariables.setupList[index].id = UniversalTracker.savedVariables.nextSetupID
					UniversalTracker.savedVariables.nextSetupID = UniversalTracker.savedVariables.nextSetupID + 1
				end
			else
				UniversalTracker.savedVariables.setupList[index] = ZO_DeepTableCopy(newSetup)
				if editIndex < 0 then
					UniversalTracker.savedVariables.setupList[index].id = UniversalTracker.savedVariables.nextSetupID
					UniversalTracker.savedVariables.nextSetupID = UniversalTracker.savedVariables.nextSetupID + 1
				end
			end
			
			loadMenu(settingPages.mainMenu, false)
			editIndex = -1
		end
	}
	local setupCancelButton = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "CANCEL",
		buttonText = "CANCEL",
		tooltip = "Discard Changes and Return to main menu.",
		clickHandler = function(control)
			loadMenu(settingPages.mainMenu, false)
			editIndex = -1
		end
	}

	loadSetup = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "Load Setup",
		buttonText = "LOAD",
		tooltip = "Sets the hidden state of all trackers to those described by this setup.\n\
					Ignores unsaved changes.",
		clickHandler = function(control)
			local id = nil
			if isCharacterSettings then
				id = UniversalTracker.characterSavedVariables.setupList[editIndex].id
			else
				id = UniversalTracker.savedVariables.setupList[editIndex].id
			end

			if not id then return end

			UniversalTracker.loadSetup(id)

			makeAnnouncement("Setup has been loaded.")
		end
	}

	deleteSetup = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "Delete Setup",
		buttonText = "DELETE",
		tooltip = "PERMANENTLY removes this setup.\n\
					This action cannot be undone.",
		clickHandler = function(control)
			if isCharacterSettings then
				table.remove(UniversalTracker.characterSavedVariables.setupList, editIndex)
			else
				table.remove(UniversalTracker.savedVariables.setupList, editIndex)
			end

			loadMenu(settingPages.mainMenu, false)
		end
	}

	copySetupToAccount = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "COPY (ACCOUNT)",
		buttonText = "COPY",
		tooltip = "Creates a copy of the current setup and saves it to your account's setups.",
		clickHandler = function(control)
			local index = getNextAvailableIndex(false, true)

			--Error checking
			if newSetup.name == "" then
				makeAnnouncement("You must enter a name for your setup.", "A copy was not created.")
				return
			end

			UniversalTracker.savedVariables.setupList[index] = ZO_DeepTableCopy(newSetup)
			UniversalTracker.savedVariables.setupList[index].id = UniversalTracker.savedVariables.nextSetupID
			UniversalTracker.savedVariables.nextSetupID = UniversalTracker.savedVariables.nextSetupID + 1
			
			makeAnnouncement("You have successfully created a new copy of this setup.")
			--Don't load a new menu.
		end
	}

	copySetupToCharacter = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "COPY (Character)",
		buttonText = "COPY",
		tooltip = "Creates a copy of the current setup and saves it to your characters's setups.",
		clickHandler = function(control)
			local index = getNextAvailableIndex(true, true)

			--Error checking
			if newSetup.name == "" then
				makeAnnouncement("You must enter a name for your tracker.", "A copy was not created.")
				return
			end
			UniversalTracker.characterSavedVariables.setupList[index] = ZO_DeepTableCopy(newSetup)
			UniversalTracker.characterSavedVariables.setupList[index].id = UniversalTracker.savedVariables.nextSetupID
			UniversalTracker.savedVariables.nextSetupID = UniversalTracker.savedVariables.nextSetupID + 1
			
			makeAnnouncement("You have successfully created a new copy of this setup.")
			--Don't load a new menu.
		end
	}

	---------------------------------------
	---		Trackers (Management)  		---
	---------------------------------------
	
	setNewTrackerSaveType = {
		type = LibHarvensAddonSettings.ST_DROPDOWN,
		label = "Save Destination",
		tooltip = "Choose where to save this tracker.",
		items = {
			{name = "Account", data = 1},
			{name = "Character", data = 2},
		},
		getFunction = function() if isCharacterSettings then return "Character" else return "Account" end end,
		setFunction = function(control, itemName, itemData)
			if itemName == "Account" then
				isCharacterSettings = false
			elseif itemName == "Character" then
				isCharacterSettings = true
			end
		end,
		default = 1,
	}

	--Fancy back buttons.
	local trackerSaveButton = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "SAVE",
		buttonText = "SAVE",
		tooltip = "Save Changes and Return to main menu.",
		clickHandler = function(control)
			local index
			if editIndex >= 0 then
				index = editIndex
			else
				index = getNextAvailableIndex(isCharacterSettings)
			end
			newTracker.hashedAbilityIDs = createHashedIDList(newTracker.abilityIDs)

			--Error checking
			if newTracker.name == "" then
				makeAnnouncement("You must enter a name for your tracker.")
				return
			end
			if not next(newTracker.hashedAbilityIDs) then
				makeAnnouncement("You must enter at least one ability ID for your tracker.")
				return
			end

			if newTracker.type == "Floating" and (newTracker.targetType == "All" or newTracker.targetType == "Reticle Target" or newTracker.targetType == "Boss") then
				makeAnnouncement("Incompatible target and display types.", "Floating trackers are only for you and your group.")
				return
			end

			if not isCharacterSettings then
				UniversalTracker.savedVariables.trackerList[index] = ZO_DeepTableCopy(newTracker)
				if editIndex < 0 then
					UniversalTracker.savedVariables.trackerList[index].id = UniversalTracker.savedVariables.nextID
					UniversalTracker.savedVariables.nextID = UniversalTracker.savedVariables.nextID + 1
				end
				UniversalTracker.InitSingleDisplay(UniversalTracker.savedVariables.trackerList[index]) --Load new changes.
			else
				UniversalTracker.characterSavedVariables.trackerList[index] = ZO_DeepTableCopy(newTracker)
				if editIndex < 0 then
					UniversalTracker.characterSavedVariables.trackerList[index].id = UniversalTracker.savedVariables.nextID
					UniversalTracker.savedVariables.nextID = UniversalTracker.savedVariables.nextID + 1
				end
				UniversalTracker.InitSingleDisplay(UniversalTracker.characterSavedVariables.trackerList[index]) --Load new changes.
			end
			
			
			loadMenu(settingPages.mainMenu, false)
			editIndex = -1
		end
	}
	local trackerCancelButton = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "CANCEL",
		buttonText = "CANCEL",
		tooltip = "Discard Changes and Return to main menu.",
		clickHandler = function(control)
			loadMenu(settingPages.mainMenu, false)
			if editIndex >= 0 then
				if not isCharacterSettings then
					UniversalTracker.InitSingleDisplay(UniversalTracker.savedVariables.trackerList[editIndex]) --Load old changes
				else
					UniversalTracker.InitSingleDisplay(UniversalTracker.characterSavedVariables.trackerList[editIndex]) --Load old changes
				end
			end
			editIndex = -1
		end
	}

	deleteTracker = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "Delete Tracker",
		buttonText = "DELETE",
		tooltip = "PERMANENTLY removes this tracker.\n\
					This action cannot be undone.",
		clickHandler = function(control)
			UniversalTracker.ReleaseSingleDisplay(newTracker)

			if isCharacterSettings then
				table.remove(UniversalTracker.characterSavedVariables.trackerList, editIndex)
			else
				table.remove(UniversalTracker.savedVariables.trackerList, editIndex)
			end

			loadMenu(settingPages.mainMenu, false)
		end
	}

	copyTrackerToAccount = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "COPY (ACCOUNT)",
		buttonText = "COPY",
		tooltip = "Creates a copy of the current tracker and saves it to your account's trackers.",
		clickHandler = function(control)
			local index = getNextAvailableIndex(false)
			newTracker.hashedAbilityIDs = createHashedIDList(newTracker.abilityIDs)

			--Error checking
			if newTracker.name == "" then
				makeAnnouncement("You must enter a name for your tracker.", "A copy was not created.")
				return
			end
			if not next(newTracker.hashedAbilityIDs) then
				makeAnnouncement("You must enter at least one ability ID for your tracker.", "A copy was not created.")
				return
			end

			if newTracker.type == "Floating" and (newTracker.targetType == "All" or newTracker.targetType == "Reticle Target" or newTracker.targetType == "Boss") then
				makeAnnouncement("Incompatible target and display types.", "Floating trackers are only for you and your group.")
				return
			end

			UniversalTracker.savedVariables.trackerList[index] = ZO_DeepTableCopy(newTracker)

			UniversalTracker.savedVariables.trackerList[index].id = UniversalTracker.savedVariables.nextID
			UniversalTracker.savedVariables.nextID = UniversalTracker.savedVariables.nextID + 1
			UniversalTracker.InitSingleDisplay(UniversalTracker.savedVariables.trackerList[index]) --Load new changes.
			
			makeAnnouncement("You have successfully created a new copy of this tracker.")
			--Don't load a new menu.
		end
	}

	copyTrackerToCharacter = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "COPY (Character)",
		buttonText = "COPY",
		tooltip = "Creates a copy of the current tracker and saves it to your character's trackers.",
		clickHandler = function(control)
			local index = getNextAvailableIndex(true)
			newTracker.hashedAbilityIDs = createHashedIDList(newTracker.abilityIDs)

			--Error checking
			if newTracker.name == "" then
				makeAnnouncement("You must enter a name for your tracker.", "A copy was not created.")
				return
			end
			if not next(newTracker.hashedAbilityIDs) then
				makeAnnouncement("You must enter at least one ability ID for your tracker.", "A copy was not created.")
				return
			end

			if newTracker.type == "Floating" and (newTracker.targetType == "All" or newTracker.targetType == "Reticle Target" or newTracker.targetType == "Boss") then
				makeAnnouncement("Incompatible target and display types.", "Floating trackers are only for you and your group.")
				return
			end

			UniversalTracker.characterSavedVariables.trackerList[index] = ZO_DeepTableCopy(newTracker)

			UniversalTracker.characterSavedVariables.trackerList[index].id = UniversalTracker.savedVariables.nextID
			UniversalTracker.savedVariables.nextID = UniversalTracker.savedVariables.nextID + 1
			UniversalTracker.InitSingleDisplay(UniversalTracker.characterSavedVariables.trackerList[index]) --Load new changes.
			
			makeAnnouncement("You have successfully created a new copy of this tracker.")
			--Don't load a new menu.
		end
	}

	---------------------------------------
	---		Trackers (General)		    ---
	---------------------------------------

	local setNewTrackerName = {
		type = LibHarvensAddonSettings.ST_EDIT,
		label = "Tracker Name",
		tooltip = "Enter your custom name for this tracker\n",
		getFunction = function() return newTracker.name end,
		setFunction = function(value)
			newTracker.name = value
		end,
		default = "New Tracker",
	}

	local setNewTrackerType = nil
	setNewTrackerType = {
		type = LibHarvensAddonSettings.ST_DROPDOWN,
		label = "Tracker Type",
		tooltip = "Choose the display type.\n\nFloating trackers aren't compatible with \"Reticle Target\" or \"All\" target types.",
		items = {
			{name = "Compact", data = 1},
			{name = "Bar", data = 2},
			{name = "Floating", data = 3},
		},
		getFunction = function() return newTracker.type end,
		setFunction = function(control, itemName, itemData) 
			newTracker.type = itemName
			updateTrackerSettingList()
			local index = settings:GetIndexOf(setNewTrackerType, true)
			LibHarvensAddonSettings.list:SetSelectedIndexWithoutAnimation(index)
		end,
		default = 1,
	}

	local setNewTrackerTargetType = nil
	setNewTrackerTargetType = {
		type = LibHarvensAddonSettings.ST_DROPDOWN,
		label = "Target Type",
		tooltip = "Choose who the tracker will focus on.",
		items = {
			{name = "Player", data = 1},
			{name = "Group", data = 2},
			{name = "Boss", data = 3},
			{name = "Reticle Target", data = 4},
			{name = "All", data = 5}
		},
		getFunction = function() return newTracker.targetType end,
		setFunction = function(control, itemName, itemData) 
			newTracker.targetType = itemName
			updateTrackerSettingList()
			local index = settings:GetIndexOf(setNewTrackerTargetType, true)
			LibHarvensAddonSettings.list:SetSelectedIndexWithoutAnimation(index)
		end,
		default = 1
	}

	local setRequiredZone= {
		type = LibHarvensAddonSettings.ST_EDIT,
		textType = TEXT_TYPE_NUMERIC,
		label = "Required Zone ID",
		tooltip = "If this setting is set, the tracker will only be enabled while in a zone with the specified ID.\n\
					Visit the utilities page to get a printout of the current zone's ID",
		getFunction = function() return newTracker.requiredZoneID end,
		setFunction = function(value)
			newTracker.requiredZoneID = value
		end,
		default = ""
	}

	local setRequiredSetID = {
		type = LibHarvensAddonSettings.ST_EDIT,
		textType = TEXT_TYPE_NUMERIC,
		label = "Required Set ID",
		tooltip = "If this setting is set, the tracker will only be enabled while receiving the full set bonus from the specified set.\n\
					Visit the utilities page to get a printout of your equipped sets' IDs",
		getFunction = function() return newTracker.requiredSetID end,
		setFunction = function(value)
			newTracker.requiredSetID = value
		end,
		default = ""
	}

	local setRequiredSkillID = {
		type = LibHarvensAddonSettings.ST_EDIT,
		textType = TEXT_TYPE_NUMERIC,
		label = "Required Skill ID",
		tooltip = "If this setting is set, the tracker will only be enabled while having a skill with the specified ID equipped.\n\
					Visit the utilities page to get a printout of your slotted skills' IDs",
		getFunction = function() return newTracker.requiredSkillID end,
		setFunction = function(value)
			newTracker.requiredSkillID = value
		end,
		default = ""
	}

	local setNewTrackerOverrideTexture = {
		type = LibHarvensAddonSettings.ST_EDIT,
		label = "Override Texture",
		tooltip = "The tracker will use a texture based off of the AbilityID unless you specify an overide here.\n\
					You can specify a texture path or abilityID here.",
		getFunction = function() return newTracker.overrideTexturePath end,
		setFunction = function(value)
			if tonumber(value) ~= nil and GetAbilityIcon(tonumber(value)) ~= "/esoui/art/icons/icon_missing.dds" then
				newTracker.overrideTexturePath = GetAbilityIcon(tonumber(value))
			else
				newTracker.overrideTexturePath = value
			end
			previewTracker()
		end,
		default = ""
	}

	local appliedBySelf = {
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = "Only my effects",
		tooltip = "Only track debuffs that you directly apply.\n\n \
					Won't consistently work on Reticle Target trackers.",
		getFunction = function() return newTracker.appliedBySelf end,
		setFunction = function(value) 
			newTracker.appliedBySelf = value
		end,
		default = newTracker.appliedBySelf
	}

	local hideInactive = {
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = "Only Active Effects",
		tooltip = "Hides the tracker when there are no active effects.\n\nDoesn't affect trackers with \"All\" target type.",
		getFunction = function() return newTracker.hideInactive end,
		setFunction = function(value) 
			newTracker.hideInactive = value
			if value then newTracker.hideActive = false end
		end,
		default = newTracker.hideInactive
	}

	local hideActive = {
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = "Only Inactive Effects",
		tooltip = "Only shows the tracker when the effect has fallen off.\n\nDoesn't affect trackers with \"All\" target type.",
		getFunction = function() return newTracker.hideActive end,
		setFunction = function(value) 
			newTracker.hideActive = value
			if value then newTracker.hideInactive = false end
		end,
		default = newTracker.hideActive
	}

	-- Sets as hidden while in the menu. Hidden trackers get released when the user hits save.
	local hideTracker = {
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = "Disable Tracker",
		tooltip = "Disables the tracker without deleting it.",
		getFunction = function() return newTracker.hidden end,
		setFunction = function(value) 
			newTracker.hidden = value
		end,
		default = newTracker.hidden
	}

	setNewAbilityID = {
		type = LibHarvensAddonSettings.ST_EDIT,
		label = "Ability ID",
		tooltip = "Enter an abilityID for this tracker to track.\n\
					Multiple abilityIDs can be tracked.\n\n\
					To delete this abilityID slot, enter an ability ID of \"0\" -\
					It will be removed after saving the tracker.",
		textType = TEXT_TYPE_NUMERIC,
		maxChars = 10,
		getFunction = function() return newTracker.abilityIDs[1] end,
		setFunction = function(value) 
			newTracker.abilityIDs[1] = value
		end,
		default = newTracker.abilityIDs[1]
	}

	add1AbilityID = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "Add AbilityID",
		buttonText = "ADD",
		tooltip = "Adds an ability ID that you can track.",
		clickHandler = function(control)
			local newIndex = settings:GetIndexOf(add1AbilityID, true)
			newTracker.abilityIDs[newIndex - firstAbilityIDIndex + 1] = ""
			settings:AddSetting({
				type = setNewAbilityID.type,
				label = setNewAbilityID.label,
				tooltip = setNewAbilityID.tooltip,
				textType = setNewAbilityID.textType,
				maxChars = setNewAbilityID.maxChars,
				getFunction = function() return newTracker.abilityIDs[newIndex - firstAbilityIDIndex + 1] end,
				setFunction = function(value) 
					newTracker.abilityIDs[newIndex - firstAbilityIDIndex + 1] = value
				end,
				default = newTracker.abilityIDs[newIndex - firstAbilityIDIndex + 1]
			}, newIndex, false)
		end
	}

	newXOffset = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "X Offset",
		tooltip = "Modifies the X Offset.",
		min = 0,
		max = GuiRoot:GetWidth(),
		step = 5,
		format = "%.0f",  -- No decimal places
		unit = "",
		getFunction = function() return newTracker.x end,
		setFunction = function(value)
			newTracker.x = value
			previewTracker()
		end,
		default = newTracker.x,
		disable = function() return newTracker.type == "Floating" end
	}

	newYOffset = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Y Offset",
		tooltip = "Modifies the Y Offset.",
		min = 0,
		max = GuiRoot:GetHeight(),
		step = 5,
		format = "%.0f",  -- No decimal places
		unit = "",
		getFunction = function() return newTracker.y end,
		setFunction = function(value) 
			newTracker.y = value
			previewTracker()
		end,
		default = newTracker.y
	}

	newScale = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Scale",
		tooltip = "Modifies the tracker's size.\n",
		min = 0.1,
		max = 5,
		step = 0.1,
		format = "%.01f", 
		unit = "",
		getFunction = function() return newTracker.scale end,
		setFunction = function(value)
			newTracker.scale = value
			previewTracker()
		end,
		default = newTracker.scale
	}


	-----------------------------------------
	---			Trackers (List)			  ---
	-----------------------------------------

	columnCount = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Columns",
		tooltip = "Modifies the number of columns when displaying a boss or group list.\n",
		min = 1,
		max = 3,
		step = 1,
		format = "%1f", 
		unit = "",
		getFunction = function() return newTracker.listSettings.columns end,
		setFunction = function(value)
			newTracker.listSettings.columns = value
			previewTracker()
		end,
		default = newTracker.listSettings.columns
	}

	horizontalSpacing = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Horizontal Offset Scale",
		tooltip = "Trackers have a default horizontal offset depending on their type\n\
			You can multiply that value by a scale here.\n",
		min = 0.1,
		max = 5,
		step = 0.1,
		format = "%.1f", 
		unit = "",
		getFunction = function() return newTracker.listSettings.horizontalOffsetScale end,
		setFunction = function(value)
			newTracker.listSettings.horizontalOffsetScale = value
			previewTracker()
		end,
		default = newTracker.listSettings.horizontalOffsetScale
	}

	verticalSpacing = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Vertical Offset Scale",
		tooltip = "Trackers have a default vertical offset depending on their type\n\
			You can multiply that value by a scale here.\n",
		min = 0.1,
		max = 5,
		step = 0.1,
		format = "%.1f", 
		unit = "",
		getFunction = function() return newTracker.listSettings.verticalOffsetScale end,
		setFunction = function(value)
			newTracker.listSettings.verticalOffsetScale = value
			previewTracker()
		end,
		default = newTracker.listSettings.verticalOffsetScale
	}

	-----------------------------------------
	---			Trackers (Bar)			  ---
	-----------------------------------------

	local setBarAlignment = {
		type = LibHarvensAddonSettings.ST_DROPDOWN,
		label = "Alignment",
		tooltip = "Choose the tracker's orientation",
		items = {
			{name = "Left", data = 1},
			{name = "Right", data = 2},
			{name = "Top", data = 3},
			{name = "Bottom", data = 4},
		},
		getFunction = function() return newTracker.barSettings.alignment or "Left" end,
		setFunction = function(control, itemName, itemData) 
			newTracker.barSettings.alignment = itemName
			previewTracker()
		end,
		default = 1
	}
	
	local setBarLength = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Bar Length",
		tooltip = "Modifies the bar's length.\n",
		min = 50,
		max = 500,
		step = 5,
		format = "%f", 
		unit = "",
		getFunction = function() return newTracker.barSettings.length or 200 end,
		setFunction = function(value)
			newTracker.barSettings.length = value
			previewTracker()
		end,
		default = 200
	}

	local setUseBarEndColor = {
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = "Static Color",
		tooltip = "Should the start color be used all the way through the animation?",
		getFunction = function() return newTracker.barSettings.sameEndColor end,
		setFunction = function(value) 
			newTracker.barSettings.sameEndColor = value
		end,
		default = newTracker.barSettings.sameEndColor
	}

	local setBarStartColor = {
		type = LibHarvensAddonSettings.ST_COLOR,
		label = "Bar Start Color",
		tooltip = "Choose the starting color for the bar's animation",
		getFunction = function() 
			return newTracker.barSettings.startColor.r, newTracker.barSettings.startColor.g, 
				newTracker.barSettings.startColor.b, newTracker.barSettings.startColor.a 
		end,
		setFunction = function(r, g, b, a) 
			newTracker.barSettings.startColor = {r = r, g = g, b = b, a = a}
		end,
		default = {0, 1, 0, 1}
	}

	local setBarEndColor = {
		type = LibHarvensAddonSettings.ST_COLOR,
		label = "Bar End Color",
		tooltip = "Choose the ending color for the bar's animation",
		getFunction = function() 
			return newTracker.barSettings.endColor.r, newTracker.barSettings.endColor.g, 
				newTracker.barSettings.endColor.b, newTracker.barSettings.endColor.a 
		end,
		setFunction = function(r, g, b, a) 
			newTracker.barSettings.endColor = {r = r, g = g, b = b, a = a}
		end,
		default = {1, 0, 0, 1}
	}

	local setBarBackgroundColor = {
		type = LibHarvensAddonSettings.ST_COLOR,
		label = "Bar Background Color",
		tooltip = "",
		getFunction = function() 
			return newTracker.barSettings.backgroundColor.r, newTracker.barSettings.backgroundColor.g, 
				newTracker.barSettings.backgroundColor.b, newTracker.barSettings.backgroundColor.a 
		end,
		setFunction = function(r, g, b, a) 
			newTracker.barSettings.backgroundColor = {r = r, g = g, b = b, a = 1}
			previewTracker()
		end,
		default = {0.467, 0.467, 0.467, 1}
	}
	
	local setBarEdgeColor = {
		type = LibHarvensAddonSettings.ST_COLOR,
		label = "Bar Edge Color",
		tooltip = "",
		getFunction = function() 
			return newTracker.barSettings.edgeColor.r, newTracker.barSettings.edgeColor.g, 
				newTracker.barSettings.edgeColor.b, newTracker.barSettings.edgeColor.a 
		end,
		setFunction = function(r, g, b, a) 
			newTracker.barSettings.edgeColor = {r = r, g = g, b = b, a = a}
			previewTracker()
		end,
		default = {1, 0.8745, 0, 1}
	}


	-----------------------------------------
	---			Trackers (Text)		      ---
	-----------------------------------------

	-- Duration
	hideDuration = {
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = "Hide Duration",
		tooltip = "Disables the duration countdown display.",
		getFunction = function() return newTracker.textSettings.duration.hidden end,
		setFunction = function(value) 
			newTracker.textSettings.duration.hidden = value 
			previewTracker()
		end,
		default = newTracker.textSettings.duration.hidden
	}

	durationOverride = {
		type = LibHarvensAddonSettings.ST_EDIT,
		label = "Duration Override",
		tooltip = "Override the ability's duration with this value (in seconds).\n\n\
					The tracker will no longer listen for faded effects (e.g. from cleanses, unit deaths, or other people applying the buff) if this is set.",
		textType = TEXT_TYPE_NUMERIC,
		maxChars = 9,
		getFunction = function() return newTracker.textSettings.duration.overrideDuration or "" end,
		setFunction = function(value) 
			newTracker.textSettings.duration.overrideDuration = value
		end,
		default = newTracker.textSettings.duration.overrideDuration or ""
	}

	durationFontColor = {
		type = LibHarvensAddonSettings.ST_COLOR,
		label = "Duration Text Color",
		tooltip = "Choose the duration's text color",
		getFunction = function() 
			return newTracker.textSettings.duration.color.r, newTracker.textSettings.duration.color.g, 
				newTracker.textSettings.duration.color.b, newTracker.textSettings.duration.color.a 
		end,
		setFunction = function(r, g, b, a) 
			newTracker.textSettings.duration.color = {r = r, g = g, b = b, a = a}
			previewTracker()
		end,
		default = {1, 1, 1, 1}
	}

	durationFontScale = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Duration Text Scale",
		tooltip = "Modifies the duration's text size.\n",
		min = 0.1,
		max = 5,
		step = 0.1,
		format = "%.01f", 
		unit = "",
		getFunction = function() return newTracker.textSettings.duration.textScale end,
		setFunction = function(value)
			newTracker.textSettings.duration.textScale = value
			previewTracker()
		end,
		default = newTracker.textSettings.duration.textScale
	}

	durationXOffset = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "X Offset",
		tooltip = "Modifies the Duration's X Offset.",
		min = -100,
		max = 100,
		step = 1,
		format = "%.0f",  -- No decimal places
		unit = "",
		getFunction = function() return newTracker.textSettings.duration.x end,
		setFunction = function(value) 
			newTracker.textSettings.duration.x  = value
			previewTracker()
		end,
		default = newTracker.textSettings.duration.x 
	}

	durationYOffset = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Y Offset",
		tooltip = "Modifies the duration's Y Offset.",
		min = -100,
		max = 100,
		step = 1,
		format = "%.0f",  -- No decimal places
		unit = "",
		getFunction = function() return newTracker.textSettings.duration.y end,
		setFunction = function(value) 
			newTracker.textSettings.duration.y = value
			previewTracker()
		end,
		default = newTracker.textSettings.duration.y
	}

	-- Stacks
	hideStacks = {
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = "Hide Stacks",
		tooltip = "Disables the stack count display.",
		getFunction = function() return newTracker.textSettings.duration.hidden end,
		setFunction = function(value) 
			newTracker.textSettings.stacks.hidden = value 
			previewTracker()
		end,
		default = newTracker.textSettings.duration.hidden
	}

	stackFontColor = {
		type = LibHarvensAddonSettings.ST_COLOR,
		label = "Stacks Text Color",
		tooltip = "Choose the stack's text color",
		getFunction = function() 
			return newTracker.textSettings.stacks.color.r, newTracker.textSettings.stacks.color.g, 
				newTracker.textSettings.stacks.color.b, newTracker.textSettings.stacks.color.a 
		end,
		setFunction = function(r, g, b, a) 
			newTracker.textSettings.stacks.color = {r = r, g = g, b = b, a = a}
			previewTracker()
		end,
		default = {1, 1, 1, 1}
	}

	stackFontScale = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Stacks Text Scale",
		tooltip = "Modifies the stack's text size.\n",
		min = 0.1,
		max = 5,
		step = 0.1,
		format = "%.01f", 
		unit = "",
		getFunction = function() return newTracker.textSettings.stacks.textScale end,
		setFunction = function(value)
			newTracker.textSettings.stacks.textScale = value
			previewTracker()
		end,
		default = newTracker.textSettings.stacks.textScale
	}

	stackXOffset = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "X Offset",
		tooltip = "Modifies the stacks's X Offset.",
		min = -100,
		max = 100,
		step = 1,
		format = "%.0f",  -- No decimal places
		unit = "",
		getFunction = function() return newTracker.textSettings.stacks.x end,
		setFunction = function(value) 
			newTracker.textSettings.stacks.x  = value
			previewTracker()
		end,
		default = newTracker.textSettings.stacks.x 
	}

	stackYOffset = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Y Offset",
		tooltip = "Modifies the stacks's Y Offset.",
		min = -100,
		max = 100,
		step = 1,
		format = "%.0f",  -- No decimal places
		unit = "",
		getFunction = function() return newTracker.textSettings.stacks.y end,
		setFunction = function(value) 
			newTracker.textSettings.stacks.y = value
			previewTracker()
		end,
		default = newTracker.textSettings.stacks.y
	}

	-- Ability Name
	hideAbilityLabel = {
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = "Hide Ability Label",
		tooltip = "Disables the Ability Name label display.",
		getFunction = function() return newTracker.textSettings.abilityLabel.hidden end,
		setFunction = function(value) 
			newTracker.textSettings.abilityLabel.hidden = value 
			previewTracker()
		end,
		default = newTracker.textSettings.abilityLabel.hidden
	}

	abilityLabelFontColor = {
		type = LibHarvensAddonSettings.ST_COLOR,
		label = "Ability Label Text Color",
		tooltip = "Choose the ability label's text color",
		getFunction = function() 
			return newTracker.textSettings.abilityLabel.color.r, newTracker.textSettings.abilityLabel.color.g, 
				newTracker.textSettings.abilityLabel.color.b, newTracker.textSettings.abilityLabel.color.a 
		end,
		setFunction = function(r, g, b, a) 
			newTracker.textSettings.abilityLabel.color = {r = r, g = g, b = b, a = a}
			previewTracker()
		end,
		default = {1, 1, 1, 1}
	}

	abilityLabelFontScale = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Ability Label Text Scale",
		tooltip = "Modifies the label's text size.\n",
		min = 0.1,
		max = 5,
		step = 0.1,
		format = "%.01f", 
		unit = "",
		getFunction = function() return newTracker.textSettings.abilityLabel.textScale end,
		setFunction = function(value)
			newTracker.textSettings.abilityLabel.textScale = value
			previewTracker()
		end,
		default = newTracker.textSettings.abilityLabel.textScale
	}

	abilityLabelXOffset = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Ability Label X Offset",
		tooltip = "Modifies the label's X Offset.",
		min = -100,
		max = 100,
		step = 1,
		format = "%.0f",  -- No decimal places
		unit = "",
		getFunction = function() return newTracker.textSettings.abilityLabel.x end,
		setFunction = function(value) 
			newTracker.textSettings.abilityLabel.x = value
			previewTracker()
		end,
		default = newTracker.textSettings.abilityLabel.x 
	}

	abilityLabelYOffset = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Ability Label Y Offset",
		tooltip = "Modifies the label's Y Offset.",
		min = -100,
		max = 100,
		step = 1,
		format = "%.0f",  -- No decimal places
		unit = "",
		getFunction = function() return newTracker.textSettings.abilityLabel.y end,
		setFunction = function(value) 
			newTracker.textSettings.abilityLabel.y = value
			previewTracker()
		end,
		default = newTracker.textSettings.abilityLabel.y
	}

	
	-- Unit Name
	hideunitLabel = {
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = "Hide Unit Label",
		tooltip = "Disables the Unit Name label display.",
		getFunction = function() return newTracker.textSettings.unitLabel.hidden end,
		setFunction = function(value) 
			newTracker.textSettings.unitLabel.hidden = value 
			previewTracker()
		end,
		default = newTracker.textSettings.unitLabel.hidden
	}

	preferPlayerName = {
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = "Account Name",
		tooltip = "For players, choose whether the tracker displays their character name or account name.",
		getFunction = function() return newTracker.textSettings.unitLabel.accountName end,
		setFunction = function(value) 
			newTracker.textSettings.unitLabel.accountName = value 
			previewTracker()
		end,
		default = newTracker.textSettings.unitLabel.accountName
	}

	unitLabelFontColor = {
		type = LibHarvensAddonSettings.ST_COLOR,
		label = "Unit Label Text Color",
		tooltip = "Choose the unit label's text color",
		getFunction = function() 
			return newTracker.textSettings.unitLabel.color.r, newTracker.textSettings.unitLabel.color.g, 
				newTracker.textSettings.unitLabel.color.b, newTracker.textSettings.unitLabel.color.a 
		end,
		setFunction = function(r, g, b, a) 
			newTracker.textSettings.unitLabel.color = {r = r, g = g, b = b, a = a}
			previewTracker()
		end,
		default = {1, 1, 1, 1}
	}

	unitLabelFontScale = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Unit Label Text Scale",
		tooltip = "Modifies the label's text size.\n",
		min = 0.1,
		max = 5,
		step = 0.1,
		format = "%.01f", 
		unit = "",
		getFunction = function() return newTracker.textSettings.unitLabel.textScale end,
		setFunction = function(value)
			newTracker.textSettings.unitLabel.textScale = value
			previewTracker()
		end,
		default = newTracker.textSettings.unitLabel.textScale
	}

	unitLabelXOffset = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Unit Label X Offset",
		tooltip = "Modifies the label's X Offset.",
		min = -100,
		max = 100,
		step = 1,
		format = "%.0f",  -- No decimal places
		unit = "",
		getFunction = function() return newTracker.textSettings.unitLabel.x end,
		setFunction = function(value) 
			newTracker.textSettings.unitLabel.x  = value
			previewTracker()
		end,
		default = newTracker.textSettings.unitLabel.x 
	}

	unitLabelYOffset = {
		type = LibHarvensAddonSettings.ST_SLIDER,
		label = "Unit Label Y Offset",
		tooltip = "Modifies the label's Y Offset.",
		min = -100,
		max = 100,
		step = 1,
		format = "%.0f",  -- No decimal places
		unit = "",
		getFunction = function() return newTracker.textSettings.unitLabel.y end,
		setFunction = function(value) 
			newTracker.textSettings.unitLabel.y = value
			previewTracker()
		end,
		default = newTracker.textSettings.unitLabel.y
	}

	---------------------------------------
	---		Utilities (Print)			---
	---------------------------------------
	
	local printCurrentEffects = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "PLAYER",
		buttonText = "PRINT EFFECTS",
		tooltip = "Prints information about your active effects.",
		clickHandler = function(control)
			for i = 1, GetNumBuffs("player") do
				local buffName, _, _, _, _, iconFilename, _, _, _, _, abilityId, _, _ = GetUnitBuffInfo("player", i) 
				UniversalTracker.chat:Print(buffName.." (ID:"..abilityId..") ".."Texture="..iconFilename)
			end
		end
	}

	local printTargetEffects = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "TARGET",
		buttonText = "PRINT EFFECTS",
		tooltip = "Prints information about a target's effects.\n\
					Exit the menu and look at a target within 3 seconds to get their information.",
		clickHandler = function(control)
			zo_callLater(function() 
					if not DoesUnitExist("reticleover") then
					UniversalTracker.chat:Print("Player isn't looking at a unit.")
					return
				end
				for i = 1, GetNumBuffs("reticleover") do
					local buffName, _, _, _, _, iconFilename, _, _, _, _, abilityId, _, _ = GetUnitBuffInfo("reticleover", i) 
					UniversalTracker.chat:Print(buffName.." (ID:"..abilityId..") ".."Texture="..iconFilename)
				end
			end, 3000)
		end
	}

	local printBossEffects = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "BOSS",
		buttonText = "PRINT EFFECTS",
		tooltip = "Prints effect information about nearby bosses.",
		clickHandler = function(control)
			for x = 1, 12 do
				if DoesUnitExist("boss"..x) then
					UniversalTracker.chat:Print(zo_strformat(SI_UNIT_NAME, GetUnitName("boss"..x)))
					for i = 1, GetNumBuffs("boss"..x) do
						local buffName, _, _, _, _, iconFilename, _, _, _, _, abilityId, _, _ = GetUnitBuffInfo("boss"..x, i) 
						UniversalTracker.chat:Print(".   "..buffName.." (ID:"..abilityId..") ".."Texture="..iconFilename)
					end
				end
			end
		end
	}

	local printItemSets = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "SETS",
		buttonText = "PRINT SET IDS",
		tooltip = "Prints the Set IDs of your currently equipped sets.",
		clickHandler = function(control)
			UniversalTracker.printEquips()
		end
	}

	local printSkills = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "SKILLS",
		buttonText = "PRINT SKILL IDS",
		tooltip = "Prints the Skill IDs of your currently equipped skills.\n\
					Note that these can differ from effect IDs.",
		clickHandler = function(control)
			local abilityID
			UniversalTracker.chat:Print("Frontbar")
			for i = 3, 8 do
				abilityID = GetEffectiveAbilityIdForAbilityOnHotbar(GetSlotBoundId(i, HOTBAR_CATEGORY_PRIMARY), HOTBAR_CATEGORY_PRIMARY)
				if abilityID ~= 0 then UniversalTracker.chat:Print(".   "..GetAbilityName(abilityID).." = "..abilityID) end
			end
			UniversalTracker.chat:Print("Backbar")
			for i = 3, 8 do
				abilityID = GetEffectiveAbilityIdForAbilityOnHotbar(GetSlotBoundId(i, HOTBAR_CATEGORY_BACKUP), HOTBAR_CATEGORY_BACKUP)
				if abilityID ~= 0 then UniversalTracker.chat:Print(".   "..GetAbilityName(abilityID).." = "..abilityID) end
			end
		end
	}

	local printCurrentZone = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "ZONE",
		buttonText = "PRINT ZONE ID",
		tooltip = "Prints the ID of the zone you are in..",
		clickHandler = function(control)
			local zoneID, _, _, _ = GetUnitRawWorldPosition("player")
			UniversalTracker.chat:Print("You are in "..GetZoneNameById(zoneID).." with ID "..zoneID)
		end
	}

	---------------------------------------
	---		Utilities (Events)			---
	---------------------------------------
	
	local shouldtrackEffectGained = true
	local trackEffectGained = {
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = "Effect Gained",
		tooltip = "Should the event spammer include the ACTION_RESULT_EFFECT_GAINED result?",
		getFunction = function() return shouldtrackEffectGained end,
		setFunction = function(value) 
			shouldtrackEffectGained = value
		end,
		default = shouldtrackEffectGained
	}
	
	local shouldtrackEffectGainedDuration = true
	local trackEffectGainedDuration = {
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = "Effect Gained Duration",
		tooltip = "Should the event spammer include the ACTION_RESULT_EFFECT_GAINED_DURATION result?",
		getFunction = function() return shouldtrackEffectGainedDuration end,
		setFunction = function(value) 
			shouldtrackEffectGainedDuration = value
		end,
		default = shouldtrackEffectGainedDuration
	}
	
	local shouldTrackEffectFaded = true
	local trackEffectFaded = {
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = "Effect Faded",
		tooltip = "Should the event spammer include the ACTION_RESULT_EFFECT_FADED result?",
		getFunction = function() return shouldTrackEffectFaded end,
		setFunction = function(value) 
			shouldTrackEffectFaded = value
		end,
		default = shouldTrackEffectFaded
	}

	local showDuplicates = true
	local duplicateAbilityIDTable = {
		[ACTION_RESULT_EFFECT_GAINED] = {},
		[ACTION_RESULT_EFFECT_GAINED_DURATION] = {},
		[ACTION_RESULT_EFFECT_FADED] = {},
	}
	local allowDuplicates = {
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = "Duplicate Messages",
		tooltip = "Should the event spammer show repeated messages?",
		getFunction = function() return showDuplicates end,
		setFunction = function(value) 
			showDuplicates = value
		end,
		default = showDuplicates
	}

	local startDebugSpam = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "Start Event Spam",
		tooltip = "Listens on EVENT_COMBAT_EVENT based on the filters above and dumps the output into chat.",
		clickHandler = function(control)
			UniversalTracker.chat:Print("Now listening on EVENT_COMBAT_EVENT")
			EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name.." Debug Spam", EVENT_COMBAT_EVENT)
			duplicateAbilityIDTable = {
				[ACTION_RESULT_EFFECT_GAINED] = {},
				[ACTION_RESULT_EFFECT_GAINED_DURATION] = {},
				[ACTION_RESULT_EFFECT_FADED] = {},
			}

			EVENT_MANAGER:RegisterForEvent(UniversalTracker.name.." Debug Spam", EVENT_COMBAT_EVENT, function(_, result, _, abilityName, _, _, _, _, targetName, _, hitValue, _, _, _, _, _, id)
				if not targetName or targetName == "" then return end
				if not showDuplicates and duplicateAbilityIDTable[result] and duplicateAbilityIDTable[result][id] then return end

				if result == ACTION_RESULT_EFFECT_GAINED and shouldtrackEffectGained then
					duplicateAbilityIDTable[result][id] = true
					UniversalTracker.chat:Print(zo_strformat(SI_UNIT_NAME, targetName).." Gained Effect "..zo_strformat(SI_ABILITY_NAME, abilityName).." with ID "..id.." for "..(hitValue/1000).." seconds")
				elseif result == ACTION_RESULT_EFFECT_GAINED_DURATION and shouldtrackEffectGainedDuration then
					duplicateAbilityIDTable[result][id] = true
					UniversalTracker.chat:Print(zo_strformat(SI_UNIT_NAME, targetName).." Gained Duration on "..zo_strformat(SI_ABILITY_NAME, abilityName).." with ID "..id.." for "..(hitValue/1000).." seconds")
				elseif result == ACTION_RESULT_EFFECT_FADED and shouldTrackEffectFaded then
					duplicateAbilityIDTable[result][id] = true
					UniversalTracker.chat:Print(zo_strformat(SI_ABILITY_NAME, abilityName).." with ID "..id.." Faded on "..zo_strformat(SI_UNIT_NAME, targetName))
				end
			end)			
		end,
	}
	local stopDebugSpam = {
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = "Stop Event Spam",
		tooltip = "Unregisters the utility-provided EVENT_COMBAT_EVeNT listener.",
		clickHandler = function(control)
			UniversalTracker.chat:Print("No longer listening on EVENT_COMBAT_EVENT")
			EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name.." Debug Spam", EVENT_COMBAT_EVENT)
			duplicateAbilityIDTable = {
				[ACTION_RESULT_EFFECT_GAINED] = {},
				[ACTION_RESULT_EFFECT_GAINED_DURATION] = {},
				[ACTION_RESULT_EFFECT_FADED] = {},
			}
		end,
	}

	---------------------------------------
	---		Utilities (Presets)			---
	---------------------------------------

	local function savePreset(presetTable)
		local index = getNextAvailableIndex(isCharacterSettings)

		if not isCharacterSettings then
			UniversalTracker.savedVariables.trackerList[index] = ZO_DeepTableCopy(presetTable)
			UniversalTracker.savedVariables.trackerList[index].id = UniversalTracker.savedVariables.nextID
			UniversalTracker.savedVariables.nextID = UniversalTracker.savedVariables.nextID + 1
			UniversalTracker.InitSingleDisplay(UniversalTracker.savedVariables.trackerList[index]) --Load new changes.
		else
			UniversalTracker.characterSavedVariables.trackerList[index] = ZO_DeepTableCopy(presetTable)
			UniversalTracker.characterSavedVariables.trackerList[index].id = UniversalTracker.savedVariables.nextID
			UniversalTracker.savedVariables.nextID = UniversalTracker.savedVariables.nextID + 1
			UniversalTracker.InitSingleDisplay(UniversalTracker.characterSavedVariables.trackerList[index]) --Load new changes.
		end
	end

	local function generatePreset(presetName, presetTable)
		return {
			type = LibHarvensAddonSettings.ST_BUTTON,
			label = string.upper(presetName),
			buttonText = "LOAD",
			tooltip = "Copies an "..string.lower(presetName).." preset into the target save location.",
			clickHandler = function(control)
				savePreset(presetTable)
				makeAnnouncement("Loaded "..string.lower(presetName).." preset.")
			end
		}
	end

	local offBalancePreset = generatePreset("off balance", UniversalTracker.presets.offBalance)
	local tauntPreset = generatePreset("taunt", UniversalTracker.presets.taunt)
	local staggerPreset = generatePreset("stagger", UniversalTracker.presets.stagger)
	local relentlessPreset = generatePreset("relentless focus", UniversalTracker.presets.relentlessFocus)
	local mercilessPreset = generatePreset("merciless resolve", UniversalTracker.presets.mercilessResolve)
	local alkoshPreset = generatePreset("alkosh", UniversalTracker.presets.alkosh)
	local mkPreset = generatePreset("martial knowledge", UniversalTracker.presets.mk)
	local synergyPreset = generatePreset("resource synergy", UniversalTracker.presets.synergyCooldown)

	---------------------------------------
	---			Menu Groupings			---
	---------------------------------------

	settingPages.mainMenu = {setupSection, setupLabel, setupListMenuButton, addNewSetupButton, 
							trackerSection, trackerLabel, trackedListMenuButton, addNewTrackerButton, 
							printSection, printLabel, printSkills, printItemSets, printCurrentZone, printCurrentEffects, printTargetEffects, printBossEffects,
							eventSection, eventLabel, trackEffectGained, trackEffectGainedDuration, trackEffectFaded, allowDuplicates, stopDebugSpam, startDebugSpam,
							presetSection, presetLabel, setNewTrackerSaveType, offBalancePreset, tauntPreset, staggerPreset, relentlessPreset, mercilessPreset, alkoshPreset, mkPreset, synergyPreset}
	settingPages.setupList = {accountSetupsLabel, characterSetupsLabel, navLabel, returnToMainMenuButton}
	settingPages.newSetup = {editSetupLabel, setNewSetupName, accountTrackersLabel, characterTrackersLabel, navLabel, setNewTrackerSaveType, setupCancelButton, setupSaveButton}
	settingPages.trackedList = {accountTrackersLabel, characterTrackersLabel, navLabel, returnToMainMenuButton}

	settingPages.newTracker.general = {generalLabel, setNewTrackerName, setNewTrackerType, setNewTrackerTargetType, setNewTrackerOverrideTexture, hideTracker}
	settingPages.newTracker.visiblity = {visibilityLabel, setRequiredSetID, setRequiredSkillID, setRequiredZone, appliedBySelf, hideInactive, hideActive}
	settingPages.newTracker.abilities = {abilityIDListLabel, setNewAbilityID, add1AbilityID}
	settingPages.newTracker.position = {positionLabel, newScale, newXOffset, newYOffset}
	settingPages.newTracker.bar = {barSettingsLabel, setBarAlignment, setBarLength, setBarBackgroundColor, setBarEdgeColor, setUseBarEndColor, setBarStartColor, setBarEndColor}
	settingPages.newTracker.columns = {listSettingsLabel, columnCount, horizontalSpacing, verticalSpacing}
	settingPages.newTracker.text = {
		duration = {durationLabel, hideDuration, durationOverride, durationFontColor, durationFontScale, durationXOffset, durationYOffset},
		stacks = {stacksLabel, hideStacks, stackFontColor, stackFontScale, stackXOffset, stackYOffset},
		abilityName = {abilityNameLabel, hideAbilityLabel, abilityLabelFontColor, abilityLabelFontScale, abilityLabelXOffset, abilityLabelYOffset},
		unitName = {unitNameLabel, hideunitLabel, preferPlayerName, unitLabelFontColor, unitLabelFontScale, unitLabelXOffset, unitLabelYOffset}
	}
	settingPages.newTracker.editedNav = {navLabel, deleteTracker, copyTrackerToCharacter, copyTrackerToAccount, trackerCancelButton, trackerSaveButton}
	settingPages.newTracker.newNav = {navLabel, setNewTrackerSaveType, trackerCancelButton, trackerSaveButton}

	-- I'm resorting to storing and calculating this so 
	-- I don't have to edit a dozen lines every time I want to
	-- put a setting before the abilityID
	--
	-- This is the index of the first abilityID textbox.
	firstAbilityIDIndex = #settingPages.newTracker.general + #settingPages.newTracker.visiblity + 2

	settings:AddSettings(settingPages.mainMenu)
end