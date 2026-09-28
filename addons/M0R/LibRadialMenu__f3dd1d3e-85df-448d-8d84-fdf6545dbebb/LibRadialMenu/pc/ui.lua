LibRadialMenu = LibRadialMenu or {}
local libRadialWheelEntries = LibRadialMenu.libRadialWheelEntries
local registeredEntries = LibRadialMenu.registeredEntries
local addonNames = LibRadialMenu.addonNames


local slotOptions = {}
local slotLookup = {}
local addonNameOptions = {}
local addonLookup = {}
local entryNameOptions = {}
local entryLookup = {}

local currentAddonSelected = "libradialmenu"
local currentEntrySelected = "libradialmenu"
local currentSlotSelected = 1


local function getSlotText(entryData, index)
	if entryData.addon then
		local entryAddon = registeredEntries[entryData.addon]
		if entryAddon and entryAddon[entryData.entry] and addonNames[entryData.addon] then
			local entry = entryAddon[entryData.entry]
			local addonName = addonNames[entryData.addon]
			local slotIcon = entry.icon or ""
			local slotname = entry.name or entryData.entry
			local description = entry.description
			return string.format("%s|t24:24:%s|t %s", string.format(GetString(SI_LIBRADIALMENU_ASSIGN_SLOT), index), slotIcon, slotname)
		end
	end	
	return string.format(GetString(SI_LIBRADIALMENU_ASSIGN_SLOT), index)
end


local function updateSlotText()
	for i,v in pairs(slotOptions) do
		slotOptions[i] = nil
		slotLookup[i] = nil
	end
	for i,v in pairs(LibRadialMenu.libRadialWheelEntries) do
		local slotText = getSlotText(v, i)
		slotOptions[i] = slotText
		slotLookup[slotText] = i
	end
	if LibRadialMenuSettingsPageSlotDropdown then
		LibRadialMenuSettingsPageSlotDropdown:UpdateChoices()
		LibRadialMenuSettingsPageSlotDropdown:UpdateValue()
	end
end


local function fillSlots() -- call on settings created + size updated
	for i,v in pairs(LibRadialMenu.vars.slots) do
		if i > LibRadialMenu.vars.numSlots then
			LibRadialMenu.vars.slots[i] = nil
		end
	end

	for i=1,LibRadialMenu.vars.numSlots do
		if (type(LibRadialMenu.vars.slots[i]) ~= "table") then
			LibRadialMenu.vars.slots[i] = {}
		end
	end

	LibRadialMenu.libRadialWheelEntries = LibRadialMenu.vars.slots	
	updateSlotText()
end


local function changeEntry(newEntry)
	--update entry list
	LibRadialMenu.vars.slots[currentSlotSelected].addon = currentAddonSelected
	LibRadialMenu.vars.slots[currentSlotSelected].entry = entryLookup[newEntry]
end

local function updateEntryDisplay()
	local currentSlot = LibRadialMenu.vars.slots[currentSlotSelected]
	if currentSlot and LibRadialMenuSettingsPanelCurrentEntryInfo and LibRadialMenuSettingsPanelCurrentEntryDescription and LibRadialMenuSettingsPanelCurrentEntryImage then
		if currentSlot.addon and currentSlot.entry then
			local entryAddon = LibRadialMenu.registeredEntries[currentSlot.addon]
			if entryAddon and entryAddon[currentSlot.entry] and LibRadialMenu.addonNames[currentSlot.addon] then
				local entry = entryAddon[currentSlot.entry]
				local addonName = LibRadialMenu.addonNames[currentSlot.addon]
				local slotIcon = entry.icon or ""
				local slotname = entry.name or currentSlot.entry
				local description = entry.description
				LibRadialMenuSettingsPanelCurrentEntryInfo.data.title = addonName
				LibRadialMenuSettingsPanelCurrentEntryInfo.data.text = slotname
				LibRadialMenuSettingsPanelCurrentEntryDescription.data.text = description
				LibRadialMenuSettingsPanelCurrentEntryImage.data.texture = slotIcon
			else
				LibRadialMenuSettingsPanelCurrentEntryInfo.data.title = ""
				LibRadialMenuSettingsPanelCurrentEntryInfo.data.text = ""
				LibRadialMenuSettingsPanelCurrentEntryDescription.data.text = ""
				LibRadialMenuSettingsPanelCurrentEntryImage.data.texture = "/esoui/art/icons/heraldrycrests_misc_blank_01.dds"
			end
		else
			LibRadialMenuSettingsPanelCurrentEntryInfo.data.title = ""
			LibRadialMenuSettingsPanelCurrentEntryInfo.data.text = ""
			LibRadialMenuSettingsPanelCurrentEntryDescription.data.text = ""
			LibRadialMenuSettingsPanelCurrentEntryImage.data.texture = "/esoui/art/icons/heraldrycrests_misc_blank_01.dds"
		end
		LibRadialMenuSettingsPanelCurrentEntryInfo:UpdateValue()
		LibRadialMenuSettingsPanelCurrentEntryDescription:UpdateValue()
		LibRadialMenuSettingsPanelCurrentEntryImage.texture:SetTexture(LibRadialMenuSettingsPanelCurrentEntryImage.data.texture)
	end
end

local function changeAddon(newAddon)
	--update entry list
	if newAddon == nil then return end
	currentAddonSelected = newAddon
	for i,v in pairs(entryNameOptions) do
		entryNameOptions[i] = nil
	end
	local indexTable = {}
	local addonEntries = LibRadialMenu.registeredEntries[currentAddonSelected]


	if addonEntries == nil then -- if unassigned
		local entryText = "Unassigned"
		local v = "unassigned"
		entryNameOptions[#entryNameOptions+1] = entryText
		entryLookup[v] = entryText
		entryLookup[entryText] = v
		if LibRadialMenuSettingsPageEntryDropdown then
			LibRadialMenuSettingsPageEntryDropdown:UpdateChoices()
			LibRadialMenuSettingsPageEntryDropdown:UpdateValue()
		end
		return
	end


	for i,v in pairs(addonEntries) do
		indexTable[#indexTable+1] = i
	end
	table.sort(indexTable)
	for i,v in ipairs(indexTable) do
		local cEntry = addonEntries[v]
		local entryText = string.format("|t24:24:%s|t %s", cEntry.icon, cEntry.name)
		entryNameOptions[#entryNameOptions+1] = entryText
		entryLookup[v] = entryText
		entryLookup[entryText] = v
		--x = v
	end
	if LibRadialMenuSettingsPageEntryDropdown then
		LibRadialMenuSettingsPageEntryDropdown:UpdateChoices()
		LibRadialMenuSettingsPageEntryDropdown:UpdateValue()
	end
	
end

local function changeSlot(newSlot)
	local newSlotId = slotLookup[newSlot]
	local newSlotVar = LibRadialMenu.vars.slots[newSlotId]
	if newSlotVar then
		currentSlotSelected = newSlotId
		currentEntrySelected = newSlotVar.entry
		changeAddon(newSlotVar.addon)
		LibRadialMenuSettingsPageAddonDropdown:UpdateChoices()
		LibRadialMenuSettingsPageAddonDropdown:UpdateValue()
		LibRadialMenuSettingsPageEntryDropdown:UpdateChoices()
		LibRadialMenuSettingsPageEntryDropdown:UpdateValue()
		--changeEntry(newSlotVar.entry)
	end
end


local function updateAddonList()
	for i,v in pairs(addonLookup) do
		addonLookup[i] = nil
	end
	for i,v in pairs(addonNameOptions) do
		addonNameOptions[i] = nil
	end
	for i,v in pairs(LibRadialMenu.addonNames) do
		addonNameOptions[#addonNameOptions+1] = v
		addonLookup[v] = i
		addonLookup[i] = v
	end
	addonNameOptions[#addonNameOptions+1] = "Unassigned"
	addonLookup["unassigned"] = "Unassigned"
	addonLookup["Unassigned"] = "unassigned"
	if LibRadialMenuSettingsPageAddonDropdown then
		LibRadialMenuSettingsPageAddonDropdown:UpdateChoices()
		LibRadialMenuSettingsPageAddonDropdown:UpdateValue()
	end
end


function LibRadialMenu.UpdateSettingsMenu() -- really its just create, but console recreates it to update it so i guess name is update
	local panelName = "LibRadialMenuSettingsPanel"
	local panelData = {
		type = "panel",
		name = "|cFFD700LibRadialMenu|r",
		author = "|c0DC1CF@M0R_Gaming|r",
	}

	updateSlotText()

	

	for i,v in pairs(LibRadialMenu.addonNames) do
		addonNameOptions[#addonNameOptions+1] = v
		addonLookup[v] = i
		addonLookup[i] = v
	end

	for i,v in pairs(LibRadialMenu.registeredEntries[currentAddonSelected]) do
		local entryText = string.format("|t24:24:%s|t %s", v.icon, v.name)
		entryNameOptions[#entryNameOptions+1] = entryText
		entryLookup[i] = entryText
		entryLookup[entryText] = i
	end


	local optionsTable = {
		{
			type = "slider",
			name = SI_LIBRADIALMENU_WHEEL_INDEX,
			tooltip = SI_LIBRADIALMENU_WHEEL_INDEX_TOOLTIP,
			min = 0,
			max = 6,
			step = 1,
			getFunc = function() return LibRadialMenu.vars.wheelIndex end,
			setFunc = function(value)
				LibRadialMenu.vars.wheelIndex = value
				LibRadialMenu.resetTable()
				LibRadialMenu.insertWheelAtIndex(value)
			end,
			width = "full",
		},
		{
			type = "slider",
			name = SI_LIBRADIALMENU_NUM_SLOTS,
			tooltip = SI_LIBRADIALMENU_NUM_SLOTS_TOOLTIP,
			min = 2,
			max = 25,
			step = 1,
			getFunc = function() return LibRadialMenu.vars.numSlots end,
			setFunc = function(value)
				LibRadialMenu.vars.numSlots = value
				-- update references here (nvm, doing it below)
			end,
			width = "half",
		},
	    {
			type = "button",
			name = SI_LIBRADIALMENU_REFRESH_MENU,
			tooltip = SI_LIBRADIALMENU_REFRESH_MENU_TOOLTIP,
			width = "half",
			func = function()
				-- update references here for real
				fillSlots()
			end,
		},
	    {
			type = "header",
			name = SI_LIBRADIALMENU_ASSIGN_SLOTS_HEADER,
			width = "full",
		},

		{
			type = "dropdown",
			name = "Selected Slot",
			width = "full",
			choices = slotOptions,
			getFunc = function() return slotOptions[currentSlotSelected] end,
			setFunc = function(value)
				changeSlot(value)
				updateEntryDisplay()
			end,
			reference = "LibRadialMenuSettingsPageSlotDropdown"
		},
		{
			type = "description",
			title = "Addon Name",
			text = "Entry Name",
			width = "half",
			reference = "LibRadialMenuSettingsPanelCurrentEntryInfo"
		},

		{
			type = "texture",
			image = "/esoui/art/login/gamepad/loading-ouroboros.dds",
			width = "half",
			imageWidth = 48,
			imageHeight = 48,
			reference = "LibRadialMenuSettingsPanelCurrentEntryImage"
		},
		{
			type = "description",
			text = "Entry description ",
			width = "full",
			reference = "LibRadialMenuSettingsPanelCurrentEntryDescription"
		},


	    {
			type = "divider",
		},

		{
			type = "dropdown",
			name = "Addon Name",
			width = "half",
			choices = addonNameOptions,
			getFunc = function() return addonLookup[currentAddonSelected] end,
			setFunc = function(value)
				changeAddon(addonLookup[value])
			end,
			reference = "LibRadialMenuSettingsPageAddonDropdown"
		},
		{
			type = "dropdown",
			name = "Entry Name",
			width = "half",
			choices = entryNameOptions,
			getFunc = function() return entryLookup[currentEntrySelected] end,
			setFunc = function(value)
				--d(entryLookup[value])
				changeEntry(value)
				updateEntryDisplay()
				updateSlotText()
			end,
			reference = "LibRadialMenuSettingsPageEntryDropdown"
		},

	}

	local panel = LibAddonMenu2:RegisterAddonPanel(panelName, panelData)
	LibAddonMenu2:RegisterOptionControls(panelName, optionsTable)

	LibRadialMenu.panel = panel


	CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
		if panel and panel.data and panel.data.name == panelData.name then
			updateAddonList()
			updateSlotText()
			changeSlot(slotOptions[currentSlotSelected])
			updateEntryDisplay()
		end
	end)



	fillSlots()
end

function LibRadialMenu.openSettings()
	if (LibRadialMenuSettingsPanel == nil) then
		d("LibRadialMenu - Failed to open the settings panel, please open it manually!")
		return
	end
	LibAddonMenu2:OpenToPanel(LibRadialMenuSettingsPanel)
end

LibRadialMenu:RegisterEntry("libradialmenu", GetString(SI_LIBRADIALMENU_OPEN_SETTINGS), "opensettings", "esoui/art/skillsadvisor/advisor_tabicon_settings_up.dds",
	LibRadialMenu.openSettings,
	GetString(SI_LIBRADIALMENU_OPEN_SETTINGS_TOOLTIP))