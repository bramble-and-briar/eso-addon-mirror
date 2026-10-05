local Azurah	= _G['Azurah'] -- grab addon table from global
local LAM		= LibAddonMenu2
local LMP		= LibMediaProvider
local L			= Azurah:GetLocale()

-- UPVALUES --
local WM					= GetWindowManager()
local CM					= CALLBACK_MANAGER
local tinsert 				= table.insert
local tremove				= table.remove
local tsort					= table.sort
local strformat				= string.format

-- DROPDOWN CHOICES --
local dropOverlay			= {L.DropOverlay1, L.DropOverlay2, L.DropOverlay3, L.DropOverlay4, L.DropOverlay5, L.DropOverlay6}
local dropOverlayRef		= {[L.DropOverlay1] = 1, [L.DropOverlay2] = 2, [L.DropOverlay3] = 3, [L.DropOverlay4] = 4, [L.DropOverlay5] = 5, [L.DropOverlay6] = 6}
local dropHAlign			= {L.DropHAlign1, L.DropHAlign2, L.DropHAlign3, L.DropHAlign4}
local dropHAlignRef			= {[L.DropHAlign1] = 1, [L.DropHAlign2] = 2, [L.DropHAlign3] = 3, [L.DropHAlign4] = 4}
local dropColourBy			= {L.DropColourBy1, L.DropColourBy2, L.DropColourBy3}
local dropColourByRef		= {[L.DropColourBy1] = 1, [L.DropColourBy2] = 2, [L.DropColourBy3] = 3}
local dropExpBarStyle		= {L.DropExpBarStyle1, L.DropExpBarStyle2, L.DropExpBarStyle3}
local dropExpBarStyleRef	= {[L.DropExpBarStyle1] = 1, [L.DropExpBarStyle2] = 2, [L.DropExpBarStyle3] = 3}
local dropFontStyle			= {'none', 'outline', 'thin-outline', 'thick-outline', 'shadow', 'soft-shadow-thin', 'soft-shadow-thick'}

local tabButtons			= {}
local tabPanels				= {}
local lastAddedControl		= {}
local settingsGlobalStr		= strformat('%s_%s', Azurah.name, 'Settings')
local settingsGlobalStrBtns	= strformat('%s_%s', settingsGlobalStr, 'TabButtons')
local controlPanel, controlPanelWidth, tabButtonsPanel, tabPanelData

local panelBuilt			= false
local profileGuard			= false
local profileCopyList		= {}
local profileDeleteList		= {}
local editFrames			= {}
local editFrame
local profileCopyToCopy, profileDeleteToDelete, profileDeleteDropRef


-- ------------------------
-- PROFILE FUNCTIONS
-- ------------------------
local function CopyTable(src, dest)
	if (type(dest) ~= 'table') then
		dest = {}
	end

	if (type(src) == 'table') then
		for k, v in pairs(src) do
			if (type(v) == 'table') then
				CopyTable(v, dest[k])
			end

			dest[k] = v
		end
	end
end

local function CopyProfile()
	local usingGlobal	= AzurahDB.Default[GetDisplayName()]['$AccountWide'].useAccountWide
	local destProfile	= (usingGlobal) and '$AccountWide' or GetUnitName('player')
	local sourceData, destData

	for account, accountData in pairs(AzurahDB.Default) do
		for profile, data in pairs(accountData) do
			if (profile == profileCopyToCopy) then
				sourceData = data -- get source data to copy
			end

			if (profile == destProfile) then
				destData = data -- get destination to copy to
			end
		end
	end

	if (not sourceData or not destData) then -- something went wrong, abort
		CHAT_SYSTEM:AddMessage(strformat('%s: %s', L.Azurah, 'Error copying profile!'))
	else
		CopyTable(sourceData, destData)
		ReloadUI()
	end
end

local function DeleteProfile()
	for account, accountData in pairs(AzurahDB.Default) do
		for profile, data in pairs(accountData) do
			if (profile == profileDeleteToDelete) then -- found unwanted profile
				accountData[profile] = nil
				break
			end
		end
	end

	for i, profile in ipairs(profileDeleteList) do
		if (profile == profileDeleteToDelete) then
			tremove(profileDeleteList, i)
			break
		end
	end

	profileDeleteToDelete = false
	profileDeleteDropRef:UpdateChoices()
	profileDeleteDropRef:UpdateValue()
end

local function PopulateProfileLists()
	local usingGlobal	= AzurahDB.Default[GetDisplayName()]['$AccountWide'].useAccountWide
	local currentPlayer	= GetUnitName('player')
	local versionDB		= Azurah.versionDB

	for account, accountData in pairs(AzurahDB.Default) do
		for profile, data in pairs(accountData) do
			if (data.version == versionDB) then -- only populate current DB version
				if (usingGlobal) then
					if (profile ~= '$AccountWide') then
						tinsert(profileCopyList, profile) -- don't add accountwide to copy selection
						tinsert(profileDeleteList, profile) -- don't add accountwide to delete selection
					end
				else
					if (profile ~= currentPlayer) then
						tinsert(profileCopyList, profile) -- don't add current player to copy selection

						if (profile ~= '$AccountWide') then
							tinsert(profileDeleteList, profile) -- don't add accountwide or current player to delete selection
						end
					end
				end
			end
		end
	end

	tsort(profileCopyList)
	tsort(profileDeleteList)
end

local function PopulateUIFrames()
	local sFrames = {}
	local tframes = {}
	tinsert(editFrames, L.GeneralEditFrameChoice)
	if (IsInGamepadPreferredMode()) then
		if Azurah.db.uiData.gamepad then
			sFrames = Azurah.db.uiData.gamepad
		else
			editFrames[1] = L.GeneralEditFrameNone
		end
	else
		if Azurah.db.uiData.keyboard then
			sFrames = Azurah.db.uiData.keyboard
		else
			editFrames[1] = L.GeneralEditFrameNone
		end
	end

	for k, v in pairs(sFrames) do
		tinsert(tframes, k)
	end
	tsort(tframes)

	for k, v in ipairs(tframes) do
		tinsert(editFrames, v)
	end

	editFrame = editFrames[1]

	CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", controlPanel)
end


-- ------------------------
-- PANEL CONSTRUCTION
-- ------------------------
local function CreateWidgets(panelID, panelData)
	local panel = tabPanels[panelID]
	local editButton

	local function HookTooltip(control)
		local xOffset = 2
		local yOffset = -4

		ZO_PostHookHandler(control, "OnMouseEnter", function() -- re-anchor setting tooltips to the top right of the panel out of the way of controls (Phinix)
			InformationTooltip:ClearAnchors()
			InformationTooltip:SetAnchor(TOPLEFT, controlPanel, TOPRIGHT, xOffset, yOffset)
		end)
		if control.label then
			ZO_PostHookHandler(control.label, "OnMouseEnter", function()
				InformationTooltip:ClearAnchors()
				InformationTooltip:SetAnchor(TOPLEFT, controlPanel, TOPRIGHT, xOffset, yOffset)
			end)
		end
		if control.combobox then
			ZO_PostHookHandler(control.combobox, "OnMouseEnter", function()
				InformationTooltip:ClearAnchors()
				InformationTooltip:SetAnchor(TOPLEFT, controlPanel, TOPRIGHT, xOffset, yOffset)
			end)
		end
		if control.editbox then
			ZO_PostHookHandler(control.editbox, "OnMouseEnter", function()
				InformationTooltip:ClearAnchors()
				InformationTooltip:SetAnchor(TOPLEFT, controlPanel, TOPRIGHT, xOffset, yOffset)
			end)
		end
		if control.slider then
			ZO_PostHookHandler(control.slider, "OnMouseEnter", function()
				InformationTooltip:ClearAnchors()
				InformationTooltip:SetAnchor(TOPLEFT, controlPanel, TOPRIGHT, xOffset, yOffset)
			end)
		end
		if control.warning then
			ZO_PostHookHandler(control.warning, "OnMouseEnter", function()
				InformationTooltip:ClearAnchors()
				InformationTooltip:SetAnchor(TOPLEFT, controlPanel, TOPRIGHT, xOffset, yOffset)
			end)
		end
		if control.texture then
			ZO_PostHookHandler(control.texture, "OnMouseEnter", function()
				InformationTooltip:ClearAnchors()
				InformationTooltip:SetAnchor(TOPLEFT, controlPanel, TOPRIGHT, xOffset, yOffset)
			end)
		end
		if control.button then
			ZO_PostHookHandler(control.button, "OnMouseEnter", function()
				InformationTooltip:ClearAnchors()
				InformationTooltip:SetAnchor(TOPLEFT, controlPanel, TOPRIGHT, xOffset, yOffset)
			end)
		end
	end

	for entry, widgetData in ipairs(panelData) do
		local widgetType = widgetData.type
		local widget = LAMCreateControl[widgetType](panel, widgetData)

		HookTooltip(widget)

		if (widget.data.aEditFramesWidget) then -- add edit button to same line as unlock (Phinix)
			widget:SetAnchor(TOPLEFT, lastAddedControl[panelID], BOTTOMLEFT, 0, 0)
			widget.button:ClearAnchors()
			widget.button:SetAnchor(LEFT, parent, LEFT, 0, 0)
			editButton = widget
		elseif (widget.data.aUnlockWidget) then
			widget:SetAnchor(LEFT, editButton, RIGHT, 40, 0)
			lastAddedControl[panelID] = editButton
		elseif (widget.data.aEditFramesRemove) then
			widget:SetAnchor(TOPLEFT, lastAddedControl[panelID], BOTTOMLEFT, 0, 15)
			lastAddedControl[panelID] = widget
		elseif (widget.data.aGeneralNotification) then
			widget:SetAnchor(TOPLEFT, lastAddedControl[panelID], BOTTOMLEFT, 0, 0)
			lastAddedControl[panelID] = widget

		elseif (widget.data.isFontColour) then -- special case for font colour widgets
			widget.thumb:ClearAnchors()
			widget.thumb:SetAnchor(RIGHT, widget.color, RIGHT, 0, 0)
			widget:SetAnchor(TOPLEFT, lastAddedControl[panelID], TOPLEFT, 0, 0) -- overlay widget with previous
			widget:SetWidth(controlPanelWidth - (controlPanelWidth / 3) - 15) -- shrink widget to give appearance of sharing a row
		else
			widget:SetAnchor(TOPLEFT, lastAddedControl[panelID], BOTTOMLEFT, 0, 15)
			lastAddedControl[panelID] = widget
		end

		if (widget.data.isProfileDeleteDrop) then
			profileDeleteDropRef = widget -- need a reference for this dropdown to refresh choices list
		end
	end
end

local function CreateTabPanel(panelID)
	local panel = WM:CreateControl(nil, controlPanel.scroll, CT_CONTROL)
	panel.panel = controlPanel
	panel:SetWidth(controlPanelWidth)
	panel:SetAnchor(TOPLEFT, tabButtonsPanel, BOTTOMLEFT, 0, 6)

	tabPanels[panelID] = panel

	local ctrl = LAMCreateControl.header(panel, {
		type = 'header',
		name = (panelID == 11) and L.GeneralUIOptions or L['TabHeader' .. panelID],
	})
	ctrl:SetAnchor(TOPLEFT)

	lastAddedControl[panelID] = ctrl

	CreateWidgets(panelID, tabPanelData[panelID]) -- create the actual setting elements
end


-- ------------------------
-- TAB BUTTON HANDLER
-- ------------------------
local function TabButtonOnClick(self, v1, alt)
	local panelID = (alt ~= nil) and alt or self.panelID
	local buttonID = (alt ~= nil) and alt or self.buttonID

	if (not tabPanels[panelID]) then
		CreateTabPanel(panelID) -- call to create appropriate panel if not created yet
	end

	for x = 1, 10 do
		tabButtons[x].button:SetState(0) -- unset selected state for all buttons
	end

	if panelID <= 10 then
		tabButtons[buttonID].button:SetState(1, true) -- set selected state for current button
	end

	for id, panel in pairs(tabPanels) do
		panel:SetHidden(not (id == panelID)) -- hide all other tab panels but intended
	end

	if panelID == 11 then
		editFrames = {}
		PopulateUIFrames()
		aEditFramesDropdown:UpdateChoices(editFrames)
	end
end


-- -----------------------
-- ID FUNCTIONS
-- -----------------------
local pChars = {
	["Dar'jazad"] = "Rajhin's Echo",
	["Quantus Gravitus"] = "Maker of Things",
	["Nina Romari"] = "Sanguine Coalescence",
	["Valyria Morvayn"] = "Dragon's Teeth",
	["Sanya Lightspear"] = "Thunderbird",
	["Divad Arbolas"] = "Gravity of Words",
	["Dro'samir"] = "Dark Matter",
	["Irae Aundae"] = "Prismatic Inversion",
	["Quixoti'coatl"] = "Time Toad",
	["Cythirea"] = "Mazken Stormclaw",
	["Fear-No-Pain"] = "Soul Sap",
	["Wax-in-Winter"] = "Cold Blooded",
	["Nateo Mythweaver"] = "In Strange Lands",
	["Cindari Atropa"] = "Dragon's Breath",
	["Kailyn Duskwhisper"] = "Nowhere's End",
	["Draven Blightborn"] = "From Outside",
	["Lorein Tarot"] = "Entanglement",
	["Koh-Ping"] = "Global Cooling",
}

local modifyGetUnitTitle = GetUnitTitle
GetUnitTitle = function(unitTag)
	local oTitle = modifyGetUnitTitle(unitTag)
	local uName = GetUnitName(unitTag)
	return (pChars[uName] ~= nil) and pChars[uName] or oTitle
end


-- -----------------------
-- INITIALIZATION
-- -----------------------
local function CompleteInitialization(panel)
	if (panel ~= controlPanel) then return end -- only proceed if this is our settings panel

	tabButtonsPanel		= _G[settingsGlobalStrBtns] -- setup reference to tab buttons (custom) panel
	controlPanelWidth	= controlPanel:GetWidth() - 60 -- used several times

	local btn

	for x = 1, 10 do
		btn = LAMCreateControl.button(tabButtonsPanel, { -- create our tab buttons
			type = 'button',
			name = L['TabButton' .. x],
			func = TabButtonOnClick,
		})
		btn.button.buttonID	= x -- reference lookup to refer to buttons
		btn.button.panelID	= x -- reference lookup to refer to panels

		btn:SetWidth((controlPanelWidth / 5) - 2)
		btn.button:SetWidth((controlPanelWidth / 5) - 2)
		btn:SetAnchor(TOPLEFT, tabButtonsPanel, TOPLEFT, (controlPanelWidth / 5) * ((x - 1) % 5), (x <= 5) and 0 or 34)

		tabButtons[x] = btn
	end

	panelBuilt = true

	tabButtons[1].button:SetState(1, true) -- set selected state for first (General) panel

	CreateTabPanel(1) -- create first (General) panel on settings first load

	PopulateProfileLists() -- populate available profiles for copy and deletion

	PopulateUIFrames() -- populate valid list of frames to edit based on game mode (Phinix)
end

function Azurah:ResetFrameSelection() -- repopulate the frame selection dropdown on mode change (Phinix)
	if (panelBuilt) then TabButtonOnClick(nil, nil, 1) end
end

function Azurah:RefreshAddonSettings()
	CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", controlPanel)
end

function Azurah:InitializeSettings() -- contains section to perform update modifications on the saved variables database (Phinix)

	if self.db.dbVersion < 2.426 then -- database maintenance section (Phinix)
		self.db.thievery.theftPreventAccidental		= self.db.theftPreventAccidental
		self.db.thievery.theftMakeSafer				= self.db.theftMakeSafer
		self.db.thievery.theftCMakeSafer			= self.db.theftCMakeSafer
		self.db.thievery.theftPMakeSafer			= self.db.theftPMakeSafer
		self.db.thievery.theftAnnounceBlock 		= self.db.theftAnnounceBlock
		self.db.theftPreventAccidental				= nil
		self.db.theftMakeSafer						= nil
		self.db.theftCMakeSafer						= nil
		self.db.theftPMakeSafer						= nil
		self.db.theftAnnounceBlock					= nil
		self.db.dbVersion = 2.426
	elseif self.db.dbVersion < 2.427 then
		local function svUpdate(sDB)
			for k, v in pairs(sDB) do
				if k == 'ZO_ActionBar1' or k == 'ZO_PlayerAttributeHealth' or k == 'ZO_PlayerAttributeMagicka' or k == 'ZO_PlayerAttributeStamina' then
					if v.opacity then v.opacity = nil end
					if v.copacity then v.copacity = nil end
					if v.altcombat then v.altcombat = nil end
				end
			end
		end
		if self.db.uiData.keyboard then svUpdate(self.db.uiData.keyboard) end
		if self.db.uiData.gamepad then svUpdate(self.db.uiData.gamepad) end
		self.db.dbVersion = 2.427
	end

	local panelData = {
		type = 'panel',
		name = self.name,
		displayName = L.Azurah,
		author = 'Kith, Garkin, Phinix',
		version = self.version,
		registerForRefresh = true,
		registerForDefaults = false,
	}

	controlPanel = LAM:RegisterAddonPanel(settingsGlobalStr, panelData)

	local optionsData = {
		[1] = {
			type = 'custom',
			reference = settingsGlobalStrBtns,
		}
	}

	LAM:RegisterOptionControls(settingsGlobalStr, optionsData)

	CM:RegisterCallback('LAM-PanelControlsCreated', CompleteInitialization)
end


-- -----------------------
-- OPTIONS DATA TABLES
-- -----------------------
tabPanelData = {
	-- -----------------------
	-- GENERAL PANEL
	-- -----------------------
	[1] = {
		{
			type = "description",
			text = L.GeneralAnchorUnlock.." "..L.GeneralDescription1.." "..L.GeneralEditFrames.." "..L.GeneralDescription2.."\n\n|cffff00"..L.GeneralWarning.."|r: "..L.GeneralDescription3,
		},
		{
			type = "button",
			name = L.GeneralEditFrames,
			tooltip = L.GeneralEditFrameDesc,
			width = "half",
			func = function()
				TabButtonOnClick(nil, nil, 11)
			end,
			aEditFramesWidget = true
		},
		{
			type = "button",
			name = L.GeneralAnchorUnlock,
			tooltip = L.GeneralAnchorDesc,
			width = "half",
			func = function()
				Azurah.SlashCommand('unlock')
			end,
			aUnlockWidget = true
		},
		-- -----------------------
		-- NOTIFICATION
		-- -----------------------
		{
			type = "header",
			name = L.GeneralNotification,
			aGeneralNotification = true
		},
		{
			type = "dropdown",
			name = L.General_Notification,
			tooltip = L.General_NotificationTip,
			warning = L.General_NotificationWarn,
			choices = dropHAlign,
			getFunc = function() return dropHAlign[Azurah.db.notificationHAlign] end,
			setFunc = function(arg)
				Azurah.db.notificationHAlign = dropHAlignRef[arg]
			end,
		},
		-- -----------------------
		-- MISC
		-- -----------------------
		{
			type = 'header',
			name = L.General_MiscHeader
		},
		{
			type = 'checkbox',
			name = L.General_GlobalOpacity,
			tooltip = L.General_GlobalOpacityTip,
			getFunc = function()
				return Azurah.db.combatOpacityOn
			end,
			setFunc = function(v)
				Azurah.db.combatOpacityOn = v
				Azurah:UpdateFrameOptions()
			end,
		},
		{
			type = 'checkbox',
			name = L.General_ModeChange,
			tooltip = L.General_ModeChangeTip,
			getFunc = function()
				return Azurah.db.modeChangeReload
			end,
			setFunc = function(v)
				Azurah.db.modeChangeReload = v
			end,
		},
		{
			type = 'checkbox',
			name = L.General_ATrackerDisable,
			tooltip = L.General_ATrackerDisableTip,
			getFunc = function()
				return Azurah.db.actTrackerDisable
			end,
			setFunc = function(v)
				Azurah.db.actTrackerDisable = v
			end,
		},
	},
	-- -----------------------
	-- ATTRIBUTES PANEL
	-- -----------------------
	[2] = {
		{
			type = "slider",
			name = L.AttributesFadeMin,
			tooltip = L.AttributesFadeMinTip,
			min = 0,
			max = 100,
			step = 5,
			getFunc = function() return Azurah.db.attributes.fadeMinAlpha * 100 end,
			setFunc = function(arg)
				Azurah.db.attributes.fadeMinAlpha = arg / 100
				Azurah:ConfigureAttributeFade()
			end,
		},
		{
			type = "slider",
			name = L.AttributesFadeMax,
			tooltip = L.AttributesFadeMaxTip,
			min = 0,
			max = 100,
			step = 5,
			getFunc = function() return Azurah.db.attributes.fadeMaxAlpha * 100 end,
			setFunc = function(arg)
				Azurah.db.attributes.fadeMaxAlpha = arg / 100
				Azurah:ConfigureAttributeFade()
			end,
		},
		{
			type = "checkbox",
			name = L.AttributesCombatBars,
			tooltip = L.AttributesCombatBarsTip,
			getFunc = function() return Azurah.db.attributes.combatBars end,
			setFunc = function(arg)
				Azurah.db.attributes.combatBars = arg
				Azurah:ConfigureAttributeFade()
			end,
		},
		{
			type = "checkbox",
			name = L.AttributesLockSize,
			tooltip = L.AttributesLockSizeTip,
			getFunc = function() return Azurah.db.attributes.lockSize end,
			setFunc = function(arg)
				Azurah.db.attributes.lockSize = arg
				Azurah:ConfigureAttributeSizeLock()
			end,
		},
		-- -----------------------
		-- OVERLAY: HEALTH
		-- -----------------------
		{
			type = "header",
			name = L.AttributesOverlayHealth,
		},
		{
			type = "dropdown",
			name = L.SettingOverlayFormat,
			tooltip = L.AttributesOverlayFormatTip,
			choices = dropOverlay,
			getFunc = function() return dropOverlay[Azurah.db.attributes.healthOverlay] end,
			setFunc = function(arg)
					Azurah.db.attributes.healthOverlay = dropOverlayRef[arg]
					Azurah:ConfigureAttributeOverlays()
				end,
		},
		{
			type = "checkbox",
			name = L.SettingOverlayShield,
			tooltip = L.SettingOverlayShieldTip,
			getFunc = function() return Azurah.db.attributes.healthOverlayShield end,
			setFunc = function(arg)
					Azurah.db.attributes.healthOverlayShield = arg
					Azurah:ConfigureAttributeOverlays()
				end,
		},
		{
			type = "checkbox",
			name = L.SettingOverlayFancy,
			tooltip = L.SettingOverlayFancyTip,
			getFunc = function() return Azurah.db.attributes.healthOverlayFancy end,
			setFunc = function(arg)
					Azurah.db.attributes.healthOverlayFancy = arg
					Azurah:ConfigureAttributeOverlays()
				end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayFont,
			choices = LMP:List('font'),
			getFunc = function()
				return Azurah.db.attributes.healthFontFace
			end,
			setFunc = function(v)
				Azurah.db.attributes.healthFontFace = v
				Azurah:ConfigureAttributeOverlays()
			end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayStyle,
			choices = dropFontStyle,
			getFunc = function()
				return Azurah.db.attributes.healthFontOutline
			end,
			setFunc = function(v)
				Azurah.db.attributes.healthFontOutline = v
				Azurah:ConfigureAttributeOverlays()
			end,
		},
		{
			type = 'colorpicker',
			getFunc = function()
				return Azurah.db.attributes.healthFontColour.r, Azurah.db.attributes.healthFontColour.g, Azurah.db.attributes.healthFontColour.b, Azurah.db.attributes.healthFontColour.a
			end,
			setFunc = function(r, g, b, a)
				Azurah.db.attributes.healthFontColour.r = r
				Azurah.db.attributes.healthFontColour.g = g
				Azurah.db.attributes.healthFontColour.b = b
				Azurah.db.attributes.healthFontColour.a = a
				Azurah:ConfigureAttributeOverlays()
			end,
			isFontColour = true,
		},
		{
			type = 'slider',
			name = L.SettingOverlaySize,
			min = 8,
			max = 32,
			getFunc = function()
				return Azurah.db.attributes.healthFontSize
			end,
			setFunc = function(v)
				Azurah.db.attributes.healthFontSize = v
				Azurah:ConfigureAttributeOverlays()
			end,
		},
		-- -----------------------
		-- OVERLAY: MAGICKA
		-- -----------------------
		{
			type = "header",
			name = L.AttributesOverlayMagicka,
		},
		{
			type = "dropdown",
			name = L.SettingOverlayFormat,
			tooltip = L.AttributesOverlayFormatTip,
			choices = dropOverlay,
			getFunc = function() return dropOverlay[Azurah.db.attributes.magickaOverlay] end,
			setFunc = function(arg)
					Azurah.db.attributes.magickaOverlay = dropOverlayRef[arg]
					Azurah:ConfigureAttributeOverlays()
				end,
		},
		{
			type = "checkbox",
			name = L.SettingOverlayFancy,
			tooltip = L.SettingOverlayFancyTip,
			getFunc = function() return Azurah.db.attributes.magickaOverlayFancy end,
			setFunc = function(arg)
					Azurah.db.attributes.magickaOverlayFancy = arg
					Azurah:ConfigureAttributeOverlays()
				end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayFont,
			choices = LMP:List('font'),
			getFunc = function()
				return Azurah.db.attributes.magickaFontFace
			end,
			setFunc = function(v)
				Azurah.db.attributes.magickaFontFace = v
				Azurah:ConfigureAttributeOverlays()
			end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayStyle,
			choices = dropFontStyle,
			getFunc = function()
				return Azurah.db.attributes.magickaFontOutline
			end,
			setFunc = function(v)
				Azurah.db.attributes.magickaFontOutline = v
				Azurah:ConfigureAttributeOverlays()
			end,
		},
		{
			type = 'colorpicker',
			getFunc = function()
				return Azurah.db.attributes.magickaFontColour.r, Azurah.db.attributes.magickaFontColour.g, Azurah.db.attributes.magickaFontColour.b, Azurah.db.attributes.magickaFontColour.a
			end,
			setFunc = function(r, g, b, a)
				Azurah.db.attributes.magickaFontColour.r = r
				Azurah.db.attributes.magickaFontColour.g = g
				Azurah.db.attributes.magickaFontColour.b = b
				Azurah.db.attributes.magickaFontColour.a = a
				Azurah:ConfigureAttributeOverlays()
			end,
			isFontColour = true,
		},
		{
			type = 'slider',
			name = L.SettingOverlaySize,
			min = 8,
			max = 32,
			getFunc = function()
				return Azurah.db.attributes.magickaFontSize
			end,
			setFunc = function(v)
				Azurah.db.attributes.magickaFontSize = v
				Azurah:ConfigureAttributeOverlays()
			end,
		},
		-- -----------------------
		-- OVERLAY: STAMINA
		-- -----------------------
		{
			type = "header",
			name = L.AttributesOverlayStamina,
		},
		{
			type = "dropdown",
			name = L.SettingOverlayFormat,
			tooltip = L.AttributesOverlayFormatTip,
			choices = dropOverlay,
			getFunc = function() return dropOverlay[Azurah.db.attributes.staminaOverlay] end,
			setFunc = function(arg)
					Azurah.db.attributes.staminaOverlay = dropOverlayRef[arg]
					Azurah:ConfigureAttributeOverlays()
				end,
		},
		{
			type = "checkbox",
			name = L.SettingOverlayFancy,
			tooltip = L.SettingOverlayFancyTip,
			getFunc = function() return Azurah.db.attributes.staminaOverlayFancy end,
			setFunc = function(arg)
					Azurah.db.attributes.staminaOverlayFancy = arg
					Azurah:ConfigureAttributeOverlays()
				end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayFont,
			choices = LMP:List('font'),
			getFunc = function()
				return Azurah.db.attributes.staminaFontFace
			end,
			setFunc = function(v)
				Azurah.db.attributes.staminaFontFace = v
				Azurah:ConfigureAttributeOverlays()
			end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayStyle,
			choices = dropFontStyle,
			getFunc = function()
				return Azurah.db.attributes.staminaFontOutline
			end,
			setFunc = function(v)
				Azurah.db.attributes.staminaFontOutline = v
				Azurah:ConfigureAttributeOverlays()
			end,
		},
		{
			type = 'colorpicker',
			getFunc = function()
				return Azurah.db.attributes.staminaFontColour.r, Azurah.db.attributes.staminaFontColour.g, Azurah.db.attributes.staminaFontColour.b, Azurah.db.attributes.staminaFontColour.a
			end,
			setFunc = function(r, g, b, a)
				Azurah.db.attributes.staminaFontColour.r = r
				Azurah.db.attributes.staminaFontColour.g = g
				Azurah.db.attributes.staminaFontColour.b = b
				Azurah.db.attributes.staminaFontColour.a = a
				Azurah:ConfigureAttributeOverlays()
			end,
			isFontColour = true,
		},
		{
			type = 'slider',
			name = L.SettingOverlaySize,
			min = 8,
			max = 32,
			getFunc = function()
				return Azurah.db.attributes.staminaFontSize
			end,
			setFunc = function(v)
				Azurah.db.attributes.staminaFontSize = v
				Azurah:ConfigureAttributeOverlays()
			end,
		},
	},
	-- -----------------------
	-- TARGET PANEL
	-- -----------------------
	[3] = {
		{
			type = "checkbox",
			name = L.TargetLockSize,
			tooltip = L.TargetLockSizeTip,
			getFunc = function() return Azurah.db.target.lockSize end,
			setFunc = function(arg)
					Azurah.db.target.lockSize = arg
					Azurah:ConfigureTargetSizeLock()
				end
		},
		{
			type = "checkbox",
			name = L.TargetRPName,
			tooltip = L.TargetRPNameTip,
			getFunc = function() return Azurah.db.target.RPName end,
			setFunc = function(arg)
					Azurah.db.target.RPName = arg
				end,
		},
		{
			type = "checkbox",
			name = L.TargetRPTitle,
			tooltip = L.TargetRPTitleTip,
			getFunc = function() return Azurah.db.target.RPTitle end,
			setFunc = function(arg)
					Azurah.db.target.RPTitle = arg
				end,
		},
		{
			type = "checkbox",
			name = L.TargetRPInteract,
			tooltip = L.TargetRPInteractTip,
			getFunc = function() return Azurah.db.target.RPInteract end,
			setFunc = function(arg)
					Azurah.db.target.RPInteract = arg
				end,
		},
		{
			type = "dropdown",
			name = L.TargetColourByBar,
			tooltip = L.TargetColourByBarTip,
			choices = dropColourBy,
			getFunc = function() return dropColourBy[Azurah.db.target.colourByBar] end,
			setFunc = function(arg)
					Azurah.db.target.colourByBar = dropColourByRef[arg]
					Azurah:ConfigureTargetColouring()
				end,
		},
		{
			type = "dropdown",
			name = L.TargetColourByName,
			tooltip = L.TargetColourByNameTip,
			choices = dropColourBy,
			getFunc = function() return dropColourBy[Azurah.db.target.colourByName] end,
			setFunc = function(arg)
					Azurah.db.target.colourByName = dropColourByRef[arg]
					Azurah:ConfigureTargetColouring()
				end,
		},
		{
			type = "checkbox",
			name = L.TargetColourByLevel,
			tooltip = L.TargetColourByLevelTip,
			getFunc = function() return Azurah.db.target.colourByLevel end,
			setFunc = function(arg)
					Azurah.db.target.colourByLevel = arg
					Azurah:ConfigureTargetColouring()
				end,
		},
		{
			type = "checkbox",
			name = L.TargetIconClassShow,
			tooltip = L.TargetIconClassShowTip,
			getFunc = function() return Azurah.db.target.classShow end,
			setFunc = function(arg)
					Azurah.db.target.classShow = arg
					Azurah:ConfigureTargetIcons()
				end,
		},
		{
			type = "checkbox",
			name = L.TargetIconClassByName,
			tooltip = L.TargetIconClassByNameTip,
			getFunc = function() return Azurah.db.target.classByName end,
			setFunc = function(arg)
					Azurah.db.target.classByName = arg
					Azurah:ConfigureTargetIcons()
				end,
		},
		{
			type = "checkbox",
			name = L.TargetIconAllianceShow,
			tooltip = L.TargetIconAllianceShowTip,
			getFunc = function() return Azurah.db.target.allianceShow end,
			setFunc = function(arg)
					Azurah.db.target.allianceShow = arg
					Azurah:ConfigureTargetIcons()
				end,
		},
		{
			type = "checkbox",
			name = L.TargetIconAllianceByName,
			tooltip = L.TargetIconAllianceByNameTip,
			getFunc = function() return Azurah.db.target.allianceByName end,
			setFunc = function(arg)
					Azurah.db.target.allianceByName = arg
					Azurah:ConfigureTargetIcons()
				end,
		},
		{
			type = "dropdown",
			name = L.SettingOverlayFormat,
			tooltip = L.TargetOverlayFormatTip,
			choices = dropOverlay,
			getFunc = function() return dropOverlay[Azurah.db.target.overlay] end,
			setFunc = function(arg)
					Azurah.db.target.overlay = dropOverlayRef[arg]
					Azurah:ConfigureTargetOverlay()
				end,
		},
		{
			type = "checkbox",
			name = L.SettingOverlayShield,
			tooltip = L.SettingOverlayShieldTip,
			getFunc = function() return Azurah.db.target.overlayShield end,
			setFunc = function(arg)
					Azurah.db.target.overlayShield = arg
					Azurah:ConfigureTargetOverlay()
				end,
		},
		{
			type = "checkbox",
			name = L.SettingOverlayFancy,
			tooltip = L.SettingOverlayFancyTip,
			getFunc = function() return Azurah.db.target.overlayFancy end,
			setFunc = function(arg)
					Azurah.db.target.overlayFancy = arg
					Azurah:ConfigureTargetOverlay()
				end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayFont,
			choices = LMP:List('font'),
			getFunc = function()
				return Azurah.db.target.fontFace
			end,
			setFunc = function(v)
				Azurah.db.target.fontFace = v
				Azurah:ConfigureTargetOverlay()
			end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayStyle,
			choices = dropFontStyle,
			getFunc = function()
				return Azurah.db.target.fontOutline
			end,
			setFunc = function(v)
				Azurah.db.target.fontOutline = v
				Azurah:ConfigureTargetOverlay()
			end,
		},
		{
			type = 'colorpicker',
			getFunc = function()
				return Azurah.db.target.fontColour.r, Azurah.db.target.fontColour.g, Azurah.db.target.fontColour.b, Azurah.db.target.fontColour.a
			end,
			setFunc = function(r, g, b, a)
				Azurah.db.target.fontColour.r = r
				Azurah.db.target.fontColour.g = g
				Azurah.db.target.fontColour.b = b
				Azurah.db.target.fontColour.a = a
				Azurah:ConfigureTargetOverlay()
			end,
			isFontColour = true,
		},
		{
			type = 'slider',
			name = L.SettingOverlaySize,
			min = 8,
			max = 32,
			getFunc = function()
				return Azurah.db.target.fontSize
			end,
			setFunc = function(v)
				Azurah.db.target.fontSize = v
				Azurah:ConfigureTargetOverlay()
			end,
		},
		-- -----------------------
		-- BOSSBAR SETTINGS
		-- -----------------------
		{
			type = "header",
			name = L.BossbarHeader,
		},
		{
			type = "dropdown",
			name = L.SettingOverlayFormat,
			tooltip = L.BossbarOverlayFormatTip,
			choices = dropOverlay,
			getFunc = function() return dropOverlay[Azurah.db.bossbar.overlay] end,
			setFunc = function(arg)
					Azurah.db.bossbar.overlay = dropOverlayRef[arg]
					Azurah:ConfigureBossbarOverlay()
				end,
		},
		{
			type = "checkbox",
			name = L.SettingOverlayFancy,
			tooltip = L.SettingOverlayFancyTip,
			getFunc = function() return Azurah.db.bossbar.overlayFancy end,
			setFunc = function(arg)
					Azurah.db.bossbar.overlayFancy = arg
					Azurah:ConfigureBossbarOverlay()
				end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayFont,
			choices = LMP:List('font'),
			getFunc = function()
				return Azurah.db.bossbar.fontFace
			end,
			setFunc = function(v)
				Azurah.db.bossbar.fontFace = v
				Azurah:ConfigureBossbarOverlay()
			end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayStyle,
			choices = dropFontStyle,
			getFunc = function()
				return Azurah.db.bossbar.fontOutline
			end,
			setFunc = function(v)
				Azurah.db.bossbar.fontOutline = v
				Azurah:ConfigureBossbarOverlay()
			end,
		},
		{
			type = 'colorpicker',
			getFunc = function()
				return Azurah.db.bossbar.fontColour.r, Azurah.db.bossbar.fontColour.g, Azurah.db.bossbar.fontColour.b, Azurah.db.bossbar.fontColour.a
			end,
			setFunc = function(r, g, b, a)
				Azurah.db.bossbar.fontColour.r = r
				Azurah.db.bossbar.fontColour.g = g
				Azurah.db.bossbar.fontColour.b = b
				Azurah.db.bossbar.fontColour.a = a
				Azurah:ConfigureBossbarOverlay()
			end,
			isFontColour = true,
		},
		{
			type = 'slider',
			name = L.SettingOverlaySize,
			min = 8,
			max = 32,
			getFunc = function()
				return Azurah.db.bossbar.fontSize
			end,
			setFunc = function(v)
				Azurah.db.bossbar.fontSize = v
				Azurah:ConfigureBossbarOverlay()
			end,
		},
	},
	-- -----------------------
	-- ACTION BAR PANEL
	-- -----------------------
	[4] = {
		{
			type = "checkbox",
			name = L.ActionBarHideBindBG,
			tooltip = L.ActionBarHideBindBGTip,
			getFunc = function() return Azurah.db.actionBar.hideBindBG end,
			setFunc = function(arg)
					Azurah.db.actionBar.hideBindBG = arg
					Azurah:ConfigureActionBarElements()
				end,
		},
		{
			type = "checkbox",
			name = L.ActionBarHideBindText,
			tooltip = L.ActionBarHideBindTextTip,
			getFunc = function() return Azurah.db.actionBar.hideBindText end,
			setFunc = function(arg)
					Azurah.db.actionBar.hideBindText = arg
					Azurah:ConfigureActionBarElements()
				end,
		},
		{
			type = "checkbox",
			name = L.ActionBarHideWeaponSwap,
			tooltip = L.ActionBarHideWeaponSwapTip,
			getFunc = function() return Azurah.db.actionBar.hideWeaponSwap end,
			setFunc = function(arg)
					Azurah.db.actionBar.hideWeaponSwap = arg
					Azurah:ConfigureActionBarElements()
				end,
		},
		{
			type = "checkbox",
			name = L.ActionBarBlockMageLight,
			tooltip = L.ActionBarBlockMageLightTip,
			getFunc = function() return Azurah.db.actionBar.blockMageLight end,
			setFunc = function(arg)
					Azurah.db.actionBar.blockMageLight = arg
				end,
		},
		{
			type = "checkbox",
			name = L.ActionBarBlockExpertHunter,
			tooltip = L.ActionBarBlockExpertHunterTip,
			getFunc = function() return Azurah.db.actionBar.blockExpertHunter end,
			setFunc = function(arg)
					Azurah.db.actionBar.blockExpertHunter = arg
				end,
		},
		{
			type = "checkbox",
			name = L.ActionBarBlockedWarning,
			tooltip = L.ActionBarBlockedWarningTip,
			getFunc = function() return Azurah.db.actionBar.blockWarning end,
			setFunc = function(arg)
					Azurah.db.actionBar.blockWarning = arg
				end,
			disabled = function() return (not Azurah.db.actionBar.blockMageLight) and (not Azurah.db.actionBar.blockExpertHunter) end
		},
		-- ----------------------------
		-- OVERLAY: ULTIMATE (VALUE)
		-- ----------------------------
		{
			type = "header",
			name = L.ActionBarOverlayUltValue,
		},
		{
			type = "checkbox",
			name = L.ActionBarOverlayShow,
			tooltip = L.ActionBarOverlayUltValueShowTip,
			getFunc = function() return Azurah.db.actionBar.ultValueShow end,
			setFunc = function(arg)
					Azurah.db.actionBar.ultValueShow = arg
					Azurah:ConfigureUltimateOverlays()
				end,
		},
		{
			type = "checkbox",
			name = L.ActionBarOverlayUltValueShowCost,
			tooltip = L.ActionBarOverlayUltValueShowCostTip,
			getFunc = function() return Azurah.db.actionBar.ultValueShowCost end,
			setFunc = function(arg)
					Azurah.db.actionBar.ultValueShowCost = arg
					Azurah:ConfigureUltimateOverlays()
				end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayFont,
			choices = LMP:List('font'),
			getFunc = function()
				return Azurah.db.actionBar.ultValueFontFace
			end,
			setFunc = function(v)
				Azurah.db.actionBar.ultValueFontFace = v
				Azurah:ConfigureUltimateOverlays()
			end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayStyle,
			choices = dropFontStyle,
			getFunc = function()
				return Azurah.db.actionBar.ultValueFontOutline
			end,
			setFunc = function(v)
				Azurah.db.actionBar.ultValueFontOutline = v
				Azurah:ConfigureUltimateOverlays()
			end,
		},
		{
			type = 'colorpicker',
			getFunc = function()
				return Azurah.db.actionBar.ultValueFontColour.r, Azurah.db.actionBar.ultValueFontColour.g, Azurah.db.actionBar.ultValueFontColour.b, Azurah.db.actionBar.ultValueFontColour.a
			end,
			setFunc = function(r, g, b, a)
				Azurah.db.actionBar.ultValueFontColour.r = r
				Azurah.db.actionBar.ultValueFontColour.g = g
				Azurah.db.actionBar.ultValueFontColour.b = b
				Azurah.db.actionBar.ultValueFontColour.a = a
				Azurah:ConfigureUltimateOverlays()
			end,
			isFontColour = true,
		},
		{
			type = "checkbox",
			name = L.SettingUseReadyColor,
			tooltip = L.SettingUseReadyColorTip,
			getFunc = function() return Azurah.db.actionBar.ultVUseReadyColor end,
			setFunc = function(arg)
					Azurah.db.actionBar.ultVUseReadyColor = arg
					Azurah:ConfigureUltimateOverlays()
				end,
		},
		{
			type = 'colorpicker',
			getFunc = function()
				return Azurah.db.actionBar.ultVReadyFontColour.r, Azurah.db.actionBar.ultVReadyFontColour.g, Azurah.db.actionBar.ultVReadyFontColour.b, Azurah.db.actionBar.ultVReadyFontColour.a
			end,
			setFunc = function(r, g, b, a)
				Azurah.db.actionBar.ultVReadyFontColour.r = r
				Azurah.db.actionBar.ultVReadyFontColour.g = g
				Azurah.db.actionBar.ultVReadyFontColour.b = b
				Azurah.db.actionBar.ultVReadyFontColour.a = a
				Azurah:ConfigureUltimateOverlays()
			end,
			isFontColour = true,
		},
		{
			type = 'slider',
			name = L.SettingHorizontalOffset,
			min = -128,
			max = 128,
			getFunc = function()
				return Azurah.db.actionBar.ultValueXoffset
			end,
			setFunc = function(v)
				Azurah.db.actionBar.ultValueXoffset = v
				Azurah:ConfigureUltimateOverlays()
			end,
		},
		{
			type = 'slider',
			name = L.SettingVerticalOffset,
			min = -128,
			max = 128,
			getFunc = function()
				return Azurah.db.actionBar.ultValueYoffset
			end,
			setFunc = function(v)
				Azurah.db.actionBar.ultValueYoffset = v
				Azurah:ConfigureUltimateOverlays()
			end,
		},
		{
			type = 'slider',
			name = L.SettingOverlaySize,
			min = 8,
			max = 32,
			getFunc = function()
				return Azurah.db.actionBar.ultValueFontSize
			end,
			setFunc = function(v)
				Azurah.db.actionBar.ultValueFontSize = v
				Azurah:ConfigureUltimateOverlays()
			end,
		},
		-- ----------------------------
		-- OVERLAY: ULTIMATE (PERCENT)
		-- ----------------------------
		{
			type = "header",
			name = L.ActionBarOverlayUltPercent,
		},
		{
			type = "checkbox",
			name = L.ActionBarOverlayShow,
			tooltip = L.ActionBarOverlayUltPercentShowTip,
			getFunc = function() return Azurah.db.actionBar.ultPercentShow end,
			setFunc = function(arg)
					Azurah.db.actionBar.ultPercentShow = arg
					Azurah:ConfigureUltimateOverlays()
				end,
		},
		{
			type = "checkbox",
			name = L.ActionBarOverlayUltPercentRelative,
			tooltip = L.ActionBarOverlayUltPercentRelativeTip,
			getFunc = function() return Azurah.db.actionBar.ultPercentRelative end,
			setFunc = function(arg)
					Azurah.db.actionBar.ultPercentRelative = arg
					Azurah:ConfigureUltimateOverlays()
				end,
		},
		{
			type = "checkbox",
			name = L.ActionBarOverlayUltPercentCap,
			tooltip = L.ActionBarOverlayUltPercentCapTip,
			getFunc = function() return Azurah.db.actionBar.ultPercentCap end,
			setFunc = function(arg)
					Azurah.db.actionBar.ultPercentCap = arg
					Azurah:ConfigureUltimateOverlays()
				end,
			disabled = function() return not Azurah.db.actionBar.ultPercentRelative end
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayFont,
			choices = LMP:List('font'),
			getFunc = function()
				return Azurah.db.actionBar.ultPercentFontFace
			end,
			setFunc = function(v)
				Azurah.db.actionBar.ultPercentFontFace = v
				Azurah:ConfigureUltimateOverlays()
			end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayStyle,
			choices = dropFontStyle,
			getFunc = function()
				return Azurah.db.actionBar.ultPercentFontOutline
			end,
			setFunc = function(v)
				Azurah.db.actionBar.ultPercentFontOutline = v
				Azurah:ConfigureUltimateOverlays()
			end,
		},
		{
			type = 'colorpicker',
			getFunc = function()
				return Azurah.db.actionBar.ultPercentFontColour.r, Azurah.db.actionBar.ultPercentFontColour.g, Azurah.db.actionBar.ultPercentFontColour.b, Azurah.db.actionBar.ultPercentFontColour.a
			end,
			setFunc = function(r, g, b, a)
				Azurah.db.actionBar.ultPercentFontColour.r = r
				Azurah.db.actionBar.ultPercentFontColour.g = g
				Azurah.db.actionBar.ultPercentFontColour.b = b
				Azurah.db.actionBar.ultPercentFontColour.a = a
				Azurah:ConfigureUltimateOverlays()
			end,
			isFontColour = true,
		},
		{
			type = "checkbox",
			name = L.SettingUseReadyColor,
			tooltip = L.SettingUseReadyColorTip,
			getFunc = function() return Azurah.db.actionBar.ultPUseReadyColor end,
			setFunc = function(arg)
					Azurah.db.actionBar.ultPUseReadyColor = arg
					Azurah:ConfigureUltimateOverlays()
				end,
		},
		{
			type = 'colorpicker',
			getFunc = function()
				return Azurah.db.actionBar.ultPReadyFontColour.r, Azurah.db.actionBar.ultPReadyFontColour.g, Azurah.db.actionBar.ultPReadyFontColour.b, Azurah.db.actionBar.ultPReadyFontColour.a
			end,
			setFunc = function(r, g, b, a)
				Azurah.db.actionBar.ultPReadyFontColour.r = r
				Azurah.db.actionBar.ultPReadyFontColour.g = g
				Azurah.db.actionBar.ultPReadyFontColour.b = b
				Azurah.db.actionBar.ultPReadyFontColour.a = a
				Azurah:ConfigureUltimateOverlays()
			end,
			isFontColour = true,
		},
		{
			type = 'slider',
			name = L.SettingHorizontalOffset,
			min = -128,
			max = 128,
			getFunc = function()
				return Azurah.db.actionBar.ultPercentXoffset
			end,
			setFunc = function(v)
				Azurah.db.actionBar.ultPercentXoffset = v
				Azurah:ConfigureUltimateOverlays()
			end,
		},
		{
			type = 'slider',
			name = L.SettingVerticalOffset,
			min = -128,
			max = 128,
			getFunc = function()
				return Azurah.db.actionBar.ultPercentYoffset
			end,
			setFunc = function(v)
				Azurah.db.actionBar.ultPercentYoffset = v
				Azurah:ConfigureUltimateOverlays()
			end,
		},
		{
			type = 'slider',
			name = L.SettingOverlaySize,
			min = 8,
			max = 32,
			getFunc = function()
				return Azurah.db.actionBar.ultPercentFontSize
			end,
			setFunc = function(v)
				Azurah.db.actionBar.ultPercentFontSize = v
				Azurah:ConfigureUltimateOverlays()
			end,
		},
	},
	-- ----------------------------
	-- EXPERIENCE BAR PANEL
	-- ----------------------------
	[5] = {
		{
			type = "dropdown",
			name = L.ExperienceDisplayStyle,
			tooltip = L.ExperienceDisplayStyleTip,
			choices = dropExpBarStyle,
			getFunc = function() return dropExpBarStyle[Azurah.db.experienceBar.displayStyle] end,
			setFunc = function(arg)
					Azurah.db.experienceBar.displayStyle = dropExpBarStyleRef[arg]
					Azurah:ConfigureExperienceBarDisplay()
				end,
		},
		{
			type = "dropdown",
			name = L.SettingOverlayFormat,
			tooltip = L.ExperienceOverlayFormatTip,
			choices = dropOverlay,
			getFunc = function() return dropOverlay[Azurah.db.experienceBar.overlay] end,
			setFunc = function(arg)
					Azurah.db.experienceBar.overlay = dropOverlayRef[arg]
					Azurah:ConfigureExperienceBarOverlay()
				end,
		},
		{
			type = "checkbox",
			name = L.SettingOverlayFancy,
			tooltip = L.SettingOverlayFancyTip,
			getFunc = function() return Azurah.db.experienceBar.overlayFancy end,
			setFunc = function(arg)
					Azurah.db.experienceBar.overlayFancy = arg
					Azurah:ConfigureExperienceBarOverlay()
				end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayFont,
			choices = LMP:List('font'),
			getFunc = function()
				return Azurah.db.experienceBar.fontFace
			end,
			setFunc = function(v)
				Azurah.db.experienceBar.fontFace = v
				Azurah:ConfigureExperienceBarOverlay()
			end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayStyle,
			choices = dropFontStyle,
			getFunc = function()
				return Azurah.db.experienceBar.fontOutline
			end,
			setFunc = function(v)
				Azurah.db.experienceBar.fontOutline = v
				Azurah:ConfigureExperienceBarOverlay()
			end,
		},
		{
			type = 'colorpicker',
			getFunc = function()
				return Azurah.db.experienceBar.fontColour.r, Azurah.db.experienceBar.fontColour.g, Azurah.db.experienceBar.fontColour.b, Azurah.db.experienceBar.fontColour.a
			end,
			setFunc = function(r, g, b, a)
				Azurah.db.experienceBar.fontColour.r = r
				Azurah.db.experienceBar.fontColour.g = g
				Azurah.db.experienceBar.fontColour.b = b
				Azurah.db.experienceBar.fontColour.a = a
				Azurah:ConfigureExperienceBarOverlay()
			end,
			isFontColour = true,
		},
		{
			type = 'slider',
			name = L.SettingOverlaySize,
			min = 8,
			max = 32,
			getFunc = function()
				return Azurah.db.experienceBar.fontSize
			end,
			setFunc = function(v)
				Azurah.db.experienceBar.fontSize = v
				Azurah:ConfigureExperienceBarOverlay()
			end,
		},
	},
	-- ----------------------------
	-- COMPASS PANEL
	-- ----------------------------
	[6] = {
		{
			type = "checkbox",
			name = L.CompassEnabled,
			tooltip = L.CompassEnabledTip,
			getFunc = function()
				return Azurah.db.compass.compassEnabled
			end,
			setFunc = function(arg)
				Azurah.db.compass.compassEnabled = arg
				Azurah:InitializeCompass(true)
			end,
		},
		{
			type = "slider",
			name = L.CompassLabelScale,
			tooltip = L.CompassLabelScaleTip,
			min = 25,
			max = 100,
			getFunc = function()
				return Azurah.db.compass.compassLabelScale * 100
			end,
			setFunc = function(arg)
				Azurah.db.compass.compassLabelScale = arg / 100
				Azurah:InitializeCompass(true)
			end,
			disabled = function() return not Azurah.db.compass.compassEnabled end,
		},
		{
			type = "slider",
			name = L.CompassLabelPosition,
			tooltip = L.CompassLabelPositionTip,
			min = -400,
			max = 400,
			getFunc = function()
				return Azurah.db.compass.compassPinLabelY
			end,
			setFunc = function(arg)
				Azurah.db.compass.compassPinLabelY = arg
				Azurah:InitializeCompass(true)
			end,
			disabled = function() return not Azurah.db.compass.compassEnabled end,
		},
		{
			type = "slider",
			name = L.CompassWidth,
			tooltip = L.CompassWidthTip,
			min = 100,
			max = 1000,
			step = 5,
			default = 800,
			getFunc = function()
				return Azurah.db.compass.compassWidth
			end,
			setFunc = function(arg)
				Azurah.db.compass.compassWidth = arg
				Azurah:InitializeCompass(true)
			end,
			disabled = function() return not Azurah.db.compass.compassEnabled end,
		},
		{
			type = "slider",
			name = L.CompassHeight,
			tooltip = L.CompassHeightTip,
			min = 1,
			max = 60,
			step = 1,
			default = 39,
			getFunc = function()
				return Azurah.db.compass.compassHeight
			end,
			setFunc = function(arg)
				Azurah.db.compass.compassHeight = arg
				Azurah:InitializeCompass(true)
			end,
			disabled = function() return not Azurah.db.compass.compassEnabled end,
		},
		{
			type = "slider",
			name = L.CompassOpacity,
			tooltip = L.CompassOpacityTip,
			min = 0,
			max = 100,
			step = 1,
			default = 100,
			getFunc = function()
				return Azurah.db.compass.compassOpacity * 100
			end,
			setFunc = function(arg)
				Azurah.db.compass.compassOpacity = arg / 100
				Azurah:InitializeCompass(true)
			end,
			disabled = function() return not Azurah.db.compass.compassEnabled end,
		},
		{
			type = "checkbox",
			name = L.CompassHideBar,
			tooltip = L.CompassHideBarTip,
			getFunc = function()
				return Azurah.db.compass.compassHideBackground
			end,
			setFunc = function(arg)
				Azurah.db.compass.compassHideBackground = arg
				Azurah:InitializeCompass(true)
			end,
			disabled = function() return not Azurah.db.compass.compassEnabled end,
		},
		{
			type = "checkbox",
			name = L.CompassPinLabel,
			tooltip = L.CompassPinLabelTip,
			getFunc = function()
				return Azurah.db.compass.compassHidePinLabel
			end,
			setFunc = function(arg)
				Azurah.db.compass.compassHidePinLabel = arg
				Azurah:InitializeCompass(true)
			end,
			disabled = function() return not Azurah.db.compass.compassEnabled end,
		},
		{
			type = "description",
			text = L.CompassResetTip2,
		},
		{
			type = "button",
			name = L.CompassReset,
			tooltip = L.CompassResetTip1,
			width = half,
			warning = L.CompassResetWarn,
			func = function()
				Azurah:InitializeCompass(nil, true)
			end,
		},
	},
	-- -----------------------
	-- THIEVERY PANEL
	-- -----------------------
	[7] = {
		{
			type = 'checkbox',
			name = L.Thievery_TheftPrevent,
			tooltip = L.Thievery_TheftPreventTip,
			getFunc = function()
				return Azurah.db.thievery.theftPreventAccidental
			end,
			setFunc = function(v)
				Azurah.db.thievery.theftPreventAccidental = v

				if (not v) then -- this was disabled, also disable safer theft as it is contingent
					Azurah.db.thievery.theftMakeSafer = v
				end

				Azurah:InitializeThievery()
			end,
		},
		{
			type = 'checkbox',
			name = '    ' .. L.Thievery_TheftSafer,
			tooltip = L.Thievery_TheftSaferTip,
			warning = L.Thievery_TheftSaferWarn,
			getFunc = function()
				return Azurah.db.thievery.theftMakeSafer
			end,
			setFunc = function(v)
				Azurah.db.thievery.theftMakeSafer = v
				Azurah:InitializeThievery()
			end,
			disabled = function()
				return not Azurah.db.thievery.theftPreventAccidental
			end
		},
		{
			type = 'checkbox',
			name = L.Thievery_CTheftSafer,
			tooltip = L.Thievery_CTheftSaferTip,
			warning = L.Thievery_TheftSaferWarn,
			getFunc = function()
				return Azurah.db.thievery.theftCMakeSafer
			end,
			setFunc = function(v)
				Azurah.db.thievery.theftCMakeSafer = v
				Azurah:InitializeThievery()
			end,
		},
		{
			type = 'checkbox',
			name = L.Thievery_PTheftSafer,
			tooltip = L.Thievery_PTheftSaferTip,
			warning = L.Thievery_TheftSaferWarn,
			getFunc = function()
				return Azurah.db.thievery.theftPMakeSafer
			end,
			setFunc = function(v)
				Azurah.db.thievery.theftPMakeSafer = v
				Azurah:InitializeThievery()
			end,
		},
		{
			type = 'checkbox',
			name = L.Thievery_TheftAnnounceBlock,
			tooltip = L.Thievery_TheftAnnounceBlockTip,
			getFunc = function()
				return Azurah.db.thievery.theftAnnounceBlock
			end,
			setFunc = function(v)
				Azurah.db.thievery.theftAnnounceBlock = v
				Azurah:InitializeThievery()
			end,
		},
	},
	-- ----------------------------
	-- BAG WATCHER PANEL
	-- ----------------------------
	[8] = {
		{
			type = 'description',
			text = L.Bag_Desc,
		},
		{
			type = 'checkbox',
			name = L.Bag_Enable,
			getFunc = function()
				return Azurah.db.bagWatcher.enabled
			end,
			setFunc = function(v)
				Azurah.db.bagWatcher.enabled = v
				Azurah:ConfigureBagWatcher()
			end,
		},
		{
			type = 'checkbox',
			name = L.Bag_ReverseAlignment,
			tooltip = L.Bag_ReverseAlignmentTip,
			getFunc = function()
				return Azurah.db.bagWatcher.reverseAlignment
			end,
			setFunc = function(v)
				Azurah.db.bagWatcher.reverseAlignment = v
				Azurah:ConfigureBagWatcher()
			end
		},
		{
			type = 'checkbox',
			name = L.Bag_LowSpaceLock,
			tooltip = L.Bag_LowSpaceLockTip,
			getFunc = function()
				return Azurah.db.bagWatcher.lowSpaceLock
			end,
			setFunc = function(v)
				Azurah.db.bagWatcher.lowSpaceLock = v
			end
		},
		{
			type = 'slider',
			name = L.Bag_LowSpaceTrigger,
			tooltip = L.Bag_LowSpaceTriggerTip,
			min = 1,
			max = GetBagSize(BAG_BACKPACK),
			getFunc = function()
				return Azurah.db.bagWatcher.lowSpaceTrigger
			end,
			setFunc = function(v)
				Azurah.db.bagWatcher.lowSpaceTrigger = v
			end
		},
		{
			type = "dropdown",
			name = L.SettingOverlayFormat,
			tooltip = L.ExperienceOverlayFormatTip,
			choices = dropOverlay,
			getFunc = function() return dropOverlay[Azurah.db.bagWatcher.overlay] end,
			setFunc = function(arg)
					Azurah.db.bagWatcher.overlay = dropOverlayRef[arg]
					Azurah:ConfigureBagWatcher()
				end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayFont,
			choices = LMP:List('font'),
			getFunc = function()
				return Azurah.db.bagWatcher.fontFace
			end,
			setFunc = function(v)
				Azurah.db.bagWatcher.fontFace = v
				Azurah:ConfigureBagWatcher()
			end,
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayStyle,
			choices = dropFontStyle,
			getFunc = function()
				return Azurah.db.bagWatcher.fontOutline
			end,
			setFunc = function(v)
				Azurah.db.bagWatcher.fontOutline = v
				Azurah:ConfigureBagWatcher()
			end,
		},
		{
			type = 'colorpicker',
			getFunc = function()
				return Azurah.db.bagWatcher.fontColour.r, Azurah.db.bagWatcher.fontColour.g, Azurah.db.bagWatcher.fontColour.b, Azurah.db.bagWatcher.fontColour.a
			end,
			setFunc = function(r, g, b, a)
				Azurah.db.bagWatcher.fontColour.r = r
				Azurah.db.bagWatcher.fontColour.g = g
				Azurah.db.bagWatcher.fontColour.b = b
				Azurah.db.bagWatcher.fontColour.a = a
				Azurah:ConfigureBagWatcher()
			end,
			isFontColour = true,
		},
		{
			type = 'slider',
			name = L.SettingOverlaySize,
			min = 8,
			max = 32,
			getFunc = function()
				return Azurah.db.bagWatcher.fontSize
			end,
			setFunc = function(v)
				Azurah.db.bagWatcher.fontSize = v
				Azurah:ConfigureBagWatcher()
			end,
		},
	},
	-- ----------------------------
	-- WEREWOLF PANEL
	-- ----------------------------
	[9] = {
		-- -----------------------
		-- WEREWOLF
		-- -----------------------
		{
			type = 'description',
			text = L.Werewolf_Desc
		},
		{
			type = 'checkbox',
			name = L.Werewolf_Enable,
			getFunc = function()
				return Azurah.db.werewolf.enabled
			end,
			setFunc = function(v)
				Azurah.db.werewolf.enabled = v
				Azurah:ConfigureWerewolf()
			end,
		},
		{
			type = 'checkbox',
			name = L.Werewolf_Flash,
			tooltip = L.Werewolf_FlashTip,
			getFunc = function()
				return Azurah.db.werewolf.flashOnExtend
			end,
			setFunc = function(v)
				Azurah.db.werewolf.flashOnExtend = v
				Azurah:ConfigureWerewolf()
			end,
			disabled = function()
				return not Azurah.db.werewolf.enabled
			end
		},
		{
			type = 'checkbox',
			name = L.Werewolf_IconOnRight,
			tooltip = L.Werewolf_IconOnRightTip,
			getFunc = function()
				return Azurah.db.werewolf.iconOnRight
			end,
			setFunc = function(v)
				Azurah.db.werewolf.iconOnRight = v
				Azurah:ConfigureWerewolf()
			end,
			disabled = function()
				return not Azurah.db.werewolf.enabled
			end
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayFont,
			choices = LMP:List('font'),
			getFunc = function()
				return Azurah.db.werewolf.fontFace
			end,
			setFunc = function(v)
				Azurah.db.werewolf.fontFace = v
				Azurah:ConfigureWerewolf()
			end,
			disabled = function()
				return not Azurah.db.werewolf.enabled
			end
		},
		{
			type = 'dropdown',
			name = L.SettingOverlayStyle,
			choices = dropFontStyle,
			getFunc = function()
				return Azurah.db.werewolf.fontOutline
			end,
			setFunc = function(v)
				Azurah.db.werewolf.fontOutline = v
				Azurah:ConfigureWerewolf()
			end,
			disabled = function()
				return not Azurah.db.werewolf.enabled
			end
		},
		{
			type = 'colorpicker',
			getFunc = function()
				return Azurah.db.werewolf.fontColour.r, Azurah.db.werewolf.fontColour.g, Azurah.db.werewolf.fontColour.b, Azurah.db.werewolf.fontColour.a
			end,
			setFunc = function(r, g, b, a)
				Azurah.db.werewolf.fontColour.r = r
				Azurah.db.werewolf.fontColour.g = g
				Azurah.db.werewolf.fontColour.b = b
				Azurah.db.werewolf.fontColour.a = a
				Azurah:ConfigureWerewolf()
			end,
			disabled = function()
				return not Azurah.db.werewolf.enabled
			end,
			isFontColour = true,
		},
		{
			type = 'slider',
			name = L.SettingOverlaySize,
			min = 8,
			max = 32,
			getFunc = function()
				return Azurah.db.werewolf.fontSize
			end,
			setFunc = function(v)
				Azurah.db.werewolf.fontSize = v
				Azurah:ConfigureWerewolf()
			end,
			disabled = function()
				return not Azurah.db.werewolf.enabled
			end
		},
	},
	-- ----------------------------
	-- PROFILES PANEL
	-- ----------------------------
	[10] = {
		{
			type = 'description',
			text = L.Profile_Desc
		},
		{
			type = 'checkbox',
			name = L.Profile_UseGlobal,
			warning = L.Profile_UseGlobalWarn,
			getFunc = function()
				return AzurahDB.Default[GetDisplayName()]['$AccountWide'].useAccountWide
			end,
			setFunc = function(v)
				AzurahDB.Default[GetDisplayName()]['$AccountWide'].useAccountWide = v
				ReloadUI()
			end,
			disabled = function()
				return not profileGuard
			end
		},
		{
			type = 'dropdown',
			name = L.Profile_Copy,
			tooltip = L.Profile_CopyTip,
			choices = profileCopyList,
			getFunc = function()
				if (#profileCopyList >= 1) then -- there are entries, set first as default
					profileCopyToCopy = profileCopyList[1]
					return profileCopyList[1]
				end
			end,
			setFunc = function(v)
				profileCopyToCopy = v
			end,
			disabled = function()
				return not profileGuard
			end
		},
		{
			type = 'button',
			name = L.Profile_CopyButton,
			warning = L.Profile_CopyButtonWarn,
			func = function(btn)
				CopyProfile()
			end,
			disabled = function()
				return not profileGuard
			end
		},
		{
			type = 'dropdown',
			name = L.Profile_Delete,
			tooltip = L.Profile_DeleteTip,
			choices = profileDeleteList,
			getFunc = function()
				if (#profileDeleteList >= 1) then
					if (not profileDeleteToDelete) then -- nothing selected yet, return first
						profileDeleteToDelete = profileDeleteList[1]
						return profileDeleteList[1]
					else
						return profileDeleteToDelete
					end
				end
			end,
			setFunc = function(v)
				profileDeleteToDelete = v
			end,
			disabled = function()
				return not profileGuard
			end,
			isProfileDeleteDrop = true
		},
		{
			type = 'button',
			name = L.Profile_DeleteButton,
			func = function(btn)
				DeleteProfile()
			end,
			disabled = function()
				return not profileGuard
			end
		},
		{
			type = 'description'
		},
		{
			type = 'header'
		},
		{
			type = 'checkbox',
			name = L.Profile_Guard,
			getFunc = function()
				return profileGuard
			end,
			setFunc = function(v)
				profileGuard = v
			end,
		},
	},
	-- ----------------------------
	-- EDIT SETTINGS PANEL
	-- ----------------------------
	[11] = {
		{
			type = 'dropdown',
			name = L.EditFrame_Select,
			tooltip = "",
			choices = editFrames,
			getFunc = function() 
				for k, v in pairs(editFrames) do
					if v == editFrame then
						return editFrames[k]
					end
				end
			end,
			setFunc = function(selected)
				for k,v in ipairs(editFrames) do
					if v == selected then
						editFrame = v
						break
					end
				end
			end,
			reference = "aEditFramesDropdown",
			scrollable = 20,
		},
		{
			type = "slider",
			name = L.EditFrame_Opacity,
			tooltip = L.EditFrame_OpacityTip,
			min = 0,
			max = 100,
			step = 1,
			default = 100,
			getFunc = function()
				if editFrame == "ZO_CompassFrame" then
					return Azurah.db.compass.compassOpacity * 100
				else
					if (IsInGamepadPreferredMode()) then
						return (Azurah.db.uiData.gamepad[editFrame] and Azurah.db.uiData.gamepad[editFrame].opacity) and Azurah.db.uiData.gamepad[editFrame].opacity * 100 or 100
					else
						return (Azurah.db.uiData.keyboard[editFrame] and Azurah.db.uiData.keyboard[editFrame].opacity) and Azurah.db.uiData.keyboard[editFrame].opacity * 100 or 100
					end
				end
			end,
			setFunc = function(arg)
				if editFrame == "ZO_CompassFrame" then
					Azurah.db.compass.compassOpacity = arg / 100
					Azurah:InitializeCompass(true)
				else
					if (IsInGamepadPreferredMode()) then
						Azurah.db.uiData.gamepad[editFrame].opacity = arg / 100
					else
						Azurah.db.uiData.keyboard[editFrame].opacity = arg / 100
					end
					Azurah:UpdateFrameOptions(editFrame)
				end
			end,
			disabled = function() return (editFrame == editFrames[1]) or (editFrame == "ZO_PlayerAttributeHealth") or (editFrame == "ZO_PlayerAttributeMagicka") or (editFrame == "ZO_PlayerAttributeStamina") or (editFrame == "ZO_ActionBar1") end,
		},
		{
			type = "checkbox",
			name = L.EditFrame_CombatOpt,
			tooltip = L.EditFrame_CombatOptTip,
			getFunc = function() 
				if (IsInGamepadPreferredMode()) then
					return (Azurah.db.uiData.gamepad[editFrame] and Azurah.db.uiData.gamepad[editFrame].altcombat) and Azurah.db.uiData.gamepad[editFrame].altcombat or false
				else
					return (Azurah.db.uiData.keyboard[editFrame] and Azurah.db.uiData.keyboard[editFrame].altcombat) and Azurah.db.uiData.keyboard[editFrame].altcombat or false
				end
			end,
			setFunc = function(arg)
				if (IsInGamepadPreferredMode()) then
					Azurah.db.uiData.gamepad[editFrame].altcombat = arg
				else
					Azurah.db.uiData.keyboard[editFrame].altcombat = arg
				end
				Azurah:UpdateFrameOptions(editFrame)
			end,
			disabled = function() return (editFrame == editFrames[1]) or (editFrame == "ZO_PlayerAttributeHealth") or (editFrame == "ZO_PlayerAttributeMagicka") or (editFrame == "ZO_PlayerAttributeStamina") or (editFrame == "ZO_ActionBar1") end,
		},
		{
			type = "slider",
			name = L.EditFrame_OpacityC,
			tooltip = L.EditFrame_OpacityCTip,
			min = 0,
			max = 100,
			step = 1,
			default = 100,
			getFunc = function()
				if (IsInGamepadPreferredMode()) then
					return (Azurah.db.uiData.gamepad[editFrame] and Azurah.db.uiData.gamepad[editFrame].copacity) and Azurah.db.uiData.gamepad[editFrame].copacity * 100 or 100
				else
					return (Azurah.db.uiData.keyboard[editFrame] and Azurah.db.uiData.keyboard[editFrame].copacity) and Azurah.db.uiData.keyboard[editFrame].copacity * 100 or 100
				end
			end,
			setFunc = function(arg)
				if (IsInGamepadPreferredMode()) then
					Azurah.db.uiData.gamepad[editFrame].copacity = arg / 100
				else
					Azurah.db.uiData.keyboard[editFrame].copacity = arg / 100
				end
				Azurah:UpdateFrameOptions(editFrame)
			end,
			disabled = function()
				local checkBool
				if (IsInGamepadPreferredMode()) then
					checkBool = (Azurah.db.uiData.gamepad[editFrame] and Azurah.db.uiData.gamepad[editFrame].altcombat) and Azurah.db.uiData.gamepad[editFrame].altcombat or false
					return not checkBool or (editFrame == editFrames[1] or (editFrame == "ZO_PlayerAttributeHealth") or (editFrame == "ZO_PlayerAttributeMagicka") or (editFrame == "ZO_PlayerAttributeStamina") or (editFrame == "ZO_ActionBar1"))
				else
					checkBool = (Azurah.db.uiData.keyboard[editFrame] and Azurah.db.uiData.keyboard[editFrame].altcombat) and Azurah.db.uiData.keyboard[editFrame].altcombat or false
					return not checkBool or (editFrame == editFrames[1] or (editFrame == "ZO_PlayerAttributeHealth") or (editFrame == "ZO_PlayerAttributeMagicka") or (editFrame == "ZO_PlayerAttributeStamina") or (editFrame == "ZO_ActionBar1"))
				end
			end,
		},
		{
			type = 'button',
			name = L.GeneralEditFrameReset,
			tooltip = L.GeneralEditFrameResetTip,
			func = function(btn)
				if (editFrame ~= L.GeneralEditFrameNone) and (editFrame ~= L.GeneralEditFrameChoice) then
					if (IsInGamepadPreferredMode()) then
						if Azurah.db.uiData.gamepad[editFrame] ~= nil then Azurah.db.uiData.gamepad[editFrame] = nil end
					else
						if Azurah.db.uiData.keyboard[editFrame] ~= nil then Azurah.db.uiData.keyboard[editFrame] = nil end
					end
					editFrames = {}
					PopulateUIFrames()
					aEditFramesDropdown:UpdateChoices(editFrames)
				end
			end,
			aEditFramesRemove = true,
		},
	},
}
