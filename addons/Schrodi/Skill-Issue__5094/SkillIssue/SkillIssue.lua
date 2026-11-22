local ADDON_NAME = "SkillIssue"
local SI = {}

local defaults = {
	blockAlways = {},
	blockOutOfCombat = {},
	blockInCombat = {},
	logBlocked = true,
}

local lastLogAbilityId, lastLogTime

local addAlwaysChoices = {}
local addAlwaysValues = {}
local removeAlwaysChoices = {}
local removeAlwaysValues = {}
local addOocChoices = {}
local addOocValues = {}
local removeOocChoices = {}
local removeOocValues = {}
local addIcChoices = {}
local addIcValues = {}
local removeIcChoices = {}
local removeIcValues = {}

local function ClearTable(t)
	for k in pairs(t) do t[k] = nil end
end

local function PopulateEquipped()
	local seen = {}
	ClearTable(addAlwaysChoices)
	ClearTable(addAlwaysValues)
	for bar = 0, 1 do
		for slot = 3, 8 do
			local slotType = GetSlotType(slot, bar)
			if slotType then
				local abilityId
				if slotType == ACTION_TYPE_CRAFTED_ABILITY then
					abilityId = GetAbilityIdForCraftedAbilityId(GetSlotBoundId(slot, bar))
				else
					abilityId = GetSlotBoundId(slot, bar)
				end
				if abilityId and abilityId > 0 and not seen[abilityId] then
					seen[abilityId] = true
					local name = zo_strformat("<<t:1>>", GetAbilityName(abilityId))
					table.insert(addAlwaysChoices, name .. " (" .. abilityId .. ") (Slot " .. slot .. (bar == 0 and "" or "b") .. ")")
					table.insert(addAlwaysValues, abilityId)
				end
			end
		end
	end
	ClearTable(addOocChoices)
	ClearTable(addOocValues)
	for i, v in ipairs(addAlwaysChoices) do addOocChoices[i] = v end
	for i, v in ipairs(addAlwaysValues) do addOocValues[i] = v end
	ClearTable(addIcChoices)
	ClearTable(addIcValues)
	for i, v in ipairs(addAlwaysChoices) do addIcChoices[i] = v end
	for i, v in ipairs(addAlwaysValues) do addIcValues[i] = v end
end

local function PopulateBlocked(blockList, choices, values)
	ClearTable(choices)
	ClearTable(values)
	for abilityId in pairs(blockList) do
		local name = zo_strformat("<<t:1>>", GetAbilityName(abilityId))
		table.insert(choices, name .. " (" .. abilityId .. ")")
		table.insert(values, abilityId)
	end
end

function SI.ShouldBlock(abilityId)
	if SI.SV.blockAlways[abilityId] then return true end
	if SI.SV.blockOutOfCombat[abilityId] then return not IsUnitInCombat('player') end
	if SI.SV.blockInCombat[abilityId] then return IsUnitInCombat('player') end
	return false
end

function SI.GetBlockedText(blockList)
	local names = {}
	for abilityId in pairs(blockList) do
		local name = zo_strformat("<<t:1>>", GetAbilityName(abilityId))
		table.insert(names, name .. " (" .. abilityId .. ")")
	end
	if #names == 0 then return "No skills blocked" end
	table.sort(names)
	return table.concat(names, "\n")
end

function SI.RefreshAll()
	PopulateEquipped()
	PopulateBlocked(SI.SV.blockAlways, removeAlwaysChoices, removeAlwaysValues)
	PopulateBlocked(SI.SV.blockOutOfCombat, removeOocChoices, removeOocValues)
	PopulateBlocked(SI.SV.blockInCombat, removeIcChoices, removeIcValues)

	for _, ref in ipairs({
		ADDON_NAME .. "_AlwaysAdd",
		ADDON_NAME .. "_AlwaysRemove",
		ADDON_NAME .. "_OocAdd",
		ADDON_NAME .. "_OocRemove",
		ADDON_NAME .. "_IcAdd",
		ADDON_NAME .. "_IcRemove",
	}) do
		local ctrl = _G[ref]
		if ctrl and ctrl.UpdateChoices then ctrl:UpdateChoices() end
	end
end

function SI.SetupHook()
	ZO_PreHook("ZO_ActionBar_CanUseActionSlots", function()
		if GetInteractionType() ~= INTERACTION_NONE then return end
		local slotId = tonumber(debug.traceback():match('keybind = "ACTION_BUTTON_(%d)'))
		if slotId and slotId >= 3 and slotId <= 8 then
			local abilityId = GetSlotBoundId(slotId)
			if abilityId and SI.ShouldBlock(abilityId) then
				if SI.SV.logBlocked then
					local now = GetGameTimeMilliseconds()
					if abilityId ~= lastLogAbilityId or not lastLogTime or now - lastLogTime > 500 then
						lastLogAbilityId = abilityId
						lastLogTime = now
						local name = zo_strformat("<<t:1>>", GetAbilityName(abilityId))
						if SI.SV.blockAlways[abilityId] then
							d("|cFF0000[" .. ADDON_NAME .. "]|r " .. name .. " blocked")
						elseif SI.SV.blockInCombat[abilityId] then
							d("|cFF0000[" .. ADDON_NAME .. "]|r " .. name .. " blocked in combat")
						else
							d("|cFF0000[" .. ADDON_NAME .. "]|r " .. name .. " blocked out of combat")
						end
					end
				end
				return true
			end
		end
	end)
end

function SI.CreateSettings()
	local panelData = {
		type = "panel",
		name = "SkillIssue",
		displayName = "Skill Issue",
		author = "Schrodi",
		version = "1.0",
		slashCommand = "/skillissue",
		registerForRefresh = true,
	}

	local panel = LibAddonMenu2:RegisterAddonPanel(ADDON_NAME .. "_Panel", panelData)

	local options = {}

	local function AddSection(header, blockList, aChoices, aValues, rChoices, rValues, refPrefix)
		table.insert(options, {
			type = "header",
			name = header,
		})
		table.insert(options, {
			type = "dropdown",
			name = "Add Skill",
			tooltip = "Select a skill to block",
			reference = ADDON_NAME .. "_" .. refPrefix .. "Add",
			choices = aChoices,
			choicesValues = aValues,
			getFunc = function() return nil end,
			setFunc = function(abilityId)
				blockList[abilityId] = true
				SI.RefreshAll()
			end,
		})
		table.insert(options, {
			type = "description",
			text = function() return SI.GetBlockedText(blockList) end,
		})
		table.insert(options, {
			type = "dropdown",
			name = "Remove Skill",
			tooltip = "Select a skill to unblock",
			reference = ADDON_NAME .. "_" .. refPrefix .. "Remove",
			choices = rChoices,
			choicesValues = rValues,
			getFunc = function() return nil end,
			setFunc = function(abilityId)
				blockList[abilityId] = nil
				SI.RefreshAll()
			end,
		})
		table.insert(options, {
			type = "button",
			name = "Clear All",
			tooltip = "Remove all skills from this list",
			func = function()
				for k in pairs(blockList) do blockList[k] = nil end
				SI.RefreshAll()
			end,
		})
	end

	table.insert(options, {
		type = "description",
		text = "Block skills from being used. Skills are blocked by specific morph.",
	})
	table.insert(options, {
		type = "button",
		name = "Load from skillbars",
		tooltip = "Load currently equipped skills into the dropdowns",
		func = function()
			PopulateEquipped()
			for _, ref in ipairs({
				ADDON_NAME .. "_AlwaysAdd",
				ADDON_NAME .. "_OocAdd",
				ADDON_NAME .. "_IcAdd",
			}) do
				local ctrl = _G[ref]
				if ctrl and ctrl.UpdateChoices then ctrl:UpdateChoices() end
			end
		end,
		width = "half",
	})
	table.insert(options, {
		type = "checkbox",
		name = "Log blocked skills",
		tooltip = "Show a chat message when a skill is blocked",
		getFunc = function() return SI.SV.logBlocked end,
		setFunc = function(value) SI.SV.logBlocked = value end,
		width = "half",
	})

	AddSection("Block Always", SI.SV.blockAlways, addAlwaysChoices, addAlwaysValues, removeAlwaysChoices, removeAlwaysValues, "Always")
	AddSection("Block Outside of Combat", SI.SV.blockOutOfCombat, addOocChoices, addOocValues, removeOocChoices, removeOocValues, "Ooc")
	AddSection("Block In Combat", SI.SV.blockInCombat, addIcChoices, addIcValues, removeIcChoices, removeIcValues, "Ic")

	LibAddonMenu2:RegisterOptionControls(ADDON_NAME .. "_Panel", options)
end

local function UpdateRemoveDropdowns()
	PopulateBlocked(SI.SV.blockAlways, removeAlwaysChoices, removeAlwaysValues)
	PopulateBlocked(SI.SV.blockOutOfCombat, removeOocChoices, removeOocValues)
	PopulateBlocked(SI.SV.blockInCombat, removeIcChoices, removeIcValues)
	for _, ref in ipairs({
		ADDON_NAME .. "_AlwaysRemove",
		ADDON_NAME .. "_OocRemove",
		ADDON_NAME .. "_IcRemove",
	}) do
		local ctrl = _G[ref]
		if ctrl and ctrl.UpdateChoices then ctrl:UpdateChoices() end
	end
end

function SI.OnPlayerActivated()
	SI.SV = ZO_SavedVars:NewAccountWide(ADDON_NAME .. "_SV", 1, nil, defaults)
	SI.SetupHook()
	SI.CreateSettings()
	CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
		if panel:GetName() == ADDON_NAME .. "_Panel" then
			UpdateRemoveDropdowns()
		end
	end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
	if addonName ~= ADDON_NAME then return end
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
		EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)
		SI.OnPlayerActivated()
	end)
end)
