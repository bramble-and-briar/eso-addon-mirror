local CASE = {}

CASE.name = "CASE"

local LAM = LibAddonMenu2
local EM = EVENT_MANAGER

local defaultSV = {
	enableGC = false,
	gcMemoryLimitMB = 500,
	showMemoryUI = false,
	clearPVPAlerts = false,
	memoryUI = {
		x = 200,
		y = 200,
	},
}

-- ================================
-- GarbageCollector
-- ================================
function CASE.GarbageCollector()
	local memBeforeKB = collectgarbage("count")
	local limitKB = CASE.SV.gcMemoryLimitMB * 1024

	if memBeforeKB >= limitKB then
		collectgarbage("collect")
	end
end

function CASE.UpdateGarbageCollector()
	if CASE.SV.enableGC then
		EM:RegisterForUpdate(CASE.name .. "_GarbageCollector", 60000, CASE.GarbageCollector)
	else
		EM:UnregisterForUpdate(CASE.name .. "_GarbageCollector")
	end
end

-- ================================
-- Memory
-- ================================
local memoryLabel

function CASE.UpdateMemoryLabel()
	local memMB = collectgarbage("count") / 1024
	memoryLabel:SetText(string.format("%.1f MB", memMB))
end

function CASE.CreateMemoryUI()
	local ctl = WINDOW_MANAGER:CreateTopLevelWindow(CASE.name .. "_MemoryUI")
	ctl:SetDimensions(200, 30)
	ctl:SetMouseEnabled(true)
	ctl:SetMovable(true)
	ctl:SetClampedToScreen(true)

	ctl:SetAnchor(
		TOPLEFT,
		GuiRoot,
		TOPLEFT,
		CASE.SV.memoryUI.x,
		CASE.SV.memoryUI.y
	)

	ctl:SetHandler("OnMoveStop", function(self)
		local x, y = self:GetLeft(), self:GetTop()
		CASE.SV.memoryUI.x = x
		CASE.SV.memoryUI.y = y
	end)

	local label = WINDOW_MANAGER:CreateControl(nil, ctl, CT_LABEL)
	label:SetAnchor(CENTER)
	label:SetFont("ZoFontGameSmall")
	label:SetColor(1, 1, 1, 1)

	ctl:SetHidden(true)

	memoryLabel = label
end

function CASE.ToggleMemoryUI(enabled)
	if enabled then
		memoryLabel:GetParent():SetHidden(false)
		EM:RegisterForUpdate(CASE.name .. "_MemoryUI", 1000, CASE.UpdateMemoryLabel)
		CASE.UpdateMemoryLabel()
	else
		EM:UnregisterForUpdate(CASE.name .. "_MemoryUI")
		memoryLabel:GetParent():SetHidden(true)
	end
end

-- ================================
-- Miat's Trash
-- ================================
function CASE.ClearPVPAlertsTables()
	if PVP_Alerts_Main_Table and PVP_Alerts_Main_Table.SV then
		ZO_ClearTable(PVP_Alerts_Main_Table.SV.CP)
		ZO_ClearTable(PVP_Alerts_Main_Table.SV.playersDB)
	end
end

-- ================================
-- Settings
-- ================================

function CASE.InitializeSettings()
	local panelData = {
		type = "panel",
		name = "CASE",
		displayName = "|cFFD700Character Addon Settings Editor|r",
		author = "|cFFD700@Atharti|r",
		registerForRefresh = true,
	}

	local INGAME_SV = ZO_Ingame_SavedVariables['Default']

	local characterSubmenus = {}
	for accountId, charactersList in pairs(INGAME_SV) do
		local characterIdsFromNameChange = {}
		for characterId, _ in pairs(charactersList['$AccountWide']['NameChange']) do
			if characterId ~= 'version' then
				table.insert(characterIdsFromNameChange, characterId)
			end
		end
		table.sort(characterIdsFromNameChange, function(a, b) return tonumber(a) < tonumber(b) end)

		local existingCharacters = {}
		for i = 1, GetNumCharacters() do
			local name, _, _, _, _, _, characterId = GetCharacterInfo(i)
			existingCharacters[characterId] = true
		end

		local function exists(characterId)
			return existingCharacters[characterId]
		end

		local characters = {}
		for i = 1, #characterIdsFromNameChange do
			local characterId = characterIdsFromNameChange[i]
			local characterName = charactersList['$AccountWide']['NameChange'][characterId]
			local characterString = '%2d) |c888888[%s]|r — |c%s%s|r'
			local color = exists(characterId) and '00ff00' or 'ff0000'

			characters[i] = characterString:format(i, characterId, color, characterName)
		end

		table.insert(characterSubmenus, {
			type = 'submenu',
			name = accountId,
			tooltip = ('All characters for %s'):format(accountId),
			controls = {
				{
					type = 'description',
					text = table.concat(characters, '\n'),
				}
			},
		})
	end

	local optionsData = {
		-- ================================
		-- Character Sheet Section
		-- ================================
		{
			type = "header",
			name = "|t35:35:/esoui/art/companion/gamepad/gp_companion_icon_overview.dds|t Character Sheet",
		},
		{
			type = "description",
			title = "Table below contains character names and their respective IDs of currently logged in account on current server. |c00ff00Green|r name means active existing character, while |cff0000Red|r is for characters that belong to another megaserver or were deleted, but files still contain their data.",
		},
		unpack(characterSubmenus),
		-- ================================
		-- Data Management Section
		-- ================================
		{
			type = "header",
			name = "|t35:35:/esoui/art/lfg/gamepad/gp_lfg_groupfinder_editlisting.dds|t Data Management",
		},
		{
			type = "description",
			text = "Addons that have been removed may leave behind unused saved variables files that take up disk space.",
		},
		{
			type = "description",
			reference = "CASE_UnusedDataLabel",
			title = function()
				local unusedMB = GetAddOnManager():GetTotalUnusedAddOnSavedVariablesDiskUsageMB()
				local color
				local displayText

				if unusedMB > 0 then
					color = "ffa500"
					if unusedMB < 1 then
						local unusedKB = unusedMB * 1024
						displayText = string.format("%.1f KB", unusedKB)
					else
						displayText = string.format("%.2f MB", unusedMB)
					end
				else
					color = "888888"
					displayText = "0 KB"
				end

				return string.format("Unused Saved Variables Disk Usage: |c%s%s|r", color, displayText)
			end,
			text = "",
			width = "half",
		},
		{
			type = "button",
			name = "Delete Unused SV",
			tooltip = "Clears saved variable files from addons that no longer exist.",
			func = function()
				GetAddOnManager():ClearUnusedAddOnSavedVariables()
				local labelControl = _G["CASE_UnusedDataLabel"]
				labelControl:UpdateValue()
			end,
			width = "half",
			isDangerous = true,
			warning = "This will permanently delete unused saved variables files from disk.",
		},
		-- ================================
		-- AddOns LUA Memory Section
		-- ================================
		{
			type = "header",
			name = "|t35:35:/esoui/art/ava/overview_icon_underdog_score.dds|t AddOns LUA Memory",
		},
		{
			type = "description",
			text = "Feature below allows to purge empty tables and other redundant addon data from currently used memory. Might cause barely noticeable microfreeze the moment it happens if its enabled. Some not well optimized addons could stack up to few gigabytes of trash, so its good to purge it for performance. Set the memory limit to trigger the cleanup.",
		},
		{
			type = "checkbox",
			name = "Memory Monitor",
			tooltip = "Displays current Lua memory usage.",
			getFunc = function() return CASE.SV.showMemoryUI end,
			setFunc = function(value)
				CASE.SV.showMemoryUI = value
				CASE.ToggleMemoryUI(value)
			end,
		},
		{
			type = "checkbox",
			name = "Addon memory cleanup",
			tooltip = "Cleans up all available memory.",
			getFunc = function() return CASE.SV.enableGC end,
			setFunc = function(value)
				CASE.SV.enableGC = value
				CASE.UpdateGarbageCollector()
			end,
		},
		{
			type = "slider",
			name = "Memory limit when to perform cleanup",
			tooltip = "Cleanup will happen once you reach this limit.",
			min = 100,
			max = 10000,
			step = 50,
			getFunc = function() return CASE.SV.gcMemoryLimitMB end,
			setFunc = function(value) CASE.SV.gcMemoryLimitMB = value end,
			disabled = function() return not CASE.SV.enableGC end,
			format = "%d MB",
		},
		-- ================================
		-- Misc
		-- ================================
		{
			type = "header",
			name = "|t30:30:/esoui/art/inventory/gamepad/gp_inventory_icon_miscellaneous.dds|t Miscellaneous",
		},
		{
			type = "checkbox",
			name = "Prevent Miat PVP Alerts To Store Garbage",
			tooltip = "Sets Miat PVP_Alerts_Main_Table.SV.CP and .playersDB to always be empty to prevent storing insane amount of unnecessary data if you are using this addon purely for 3D icons.",
			getFunc = function() return CASE.SV.clearPVPAlerts end,
			setFunc = function(value)
				CASE.SV.clearPVPAlerts = value
				if value then
					CASE.ClearPVPAlertsTables()
				end
			end,
			requiresReload = true,
		},
	}

	LAM:RegisterAddonPanel("CASE", panelData)
	LAM:RegisterOptionControls("CASE", optionsData)
end


-- ================================
-- Init
-- ================================
local function OnAddonLoaded(_, addonName)
	if addonName ~= CASE.name then return end
	EM:UnregisterForEvent(CASE.name, EVENT_ADD_ON_LOADED)

	CASE.SV = ZO_SavedVars:NewAccountWide("CASE_SavedVariables", 1, nil, defaultSV)

	CASE.CreateMemoryUI()
	CASE.InitializeSettings()
	CASE.ToggleMemoryUI(CASE.SV.showMemoryUI)
	CASE.UpdateGarbageCollector()

	if CASE.SV.clearPVPAlerts then
		EM:RegisterForEvent(CASE.name .. "_ClearPVPAlerts", EVENT_PLAYER_ACTIVATED, function()
			CASE.ClearPVPAlertsTables()
		end)
	end
end

EM:RegisterForEvent(CASE.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
