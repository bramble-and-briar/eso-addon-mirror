local S = Stunned
local LAM = LibAddonMenu2

function S.InitSettings()
	local soundChoices = {
		"ARMORY_SAVE_SUCCESS",
		"BATTLEGROUND_ROUND_RECAP_SCREEN_FINAL_WIN",
		"BATTLEGROUND_ROUND_RECAP_SCREEN_WIN",
		"ENDLESS_DUNGEON_BUFF_ACQUIRE_VERSE",
		"ENDLESS_DUNGEON_BUFF_ACQUIRE_AVATAR_VISION",
		"ENDLESS_DUNGEON_BUFF_ACQUIRE_VISION",
		"CHAMPION_RESPEC_TOGGLED",
		"DEATH_RECAP_KILLING_BLOW_SHOWN"
	}

	local panelData = {
		type = "panel",
		name = "Stunned",
		displayName = "|cFFD700Stunned|r",
		author = "|cFFD700@Atharti|r",
		registerForRefresh = true,
	}

	local optionsData = {
		{
			type = "header",
			name = "|t30:30:/esoui/art/inventory/gamepad/gp_inventory_icon_miscellaneous.dds|t General Settings",
		},
		{
			type = "checkbox",
			name = "Blur Screen On Stun",
			tooltip = "Apply fullscreen blur when stunned",
			getFunc = function() return S.SV.blurOnStun end,
			setFunc = function(value) S.SV.blurOnStun = value end,
		},
		{
			type = "checkbox",
			name = "Hide Game UI On Stun",
			tooltip = "Hides the game interface (action bars, chat, etc.) when affected. Text pop-ups will not be visible if its ON.",
			getFunc = function() return S.SV.hideGameUI end,
			setFunc = function(value) S.SV.hideGameUI = value end,
		},
		{
			type = "dropdown",
			name = "Stun Popup Font Size",
			tooltip = "Select the font size for stun/fear/charm popup messages",
			choices = {24, 28, 30, 32, 34, 36, 40, 48, 54},
			getFunc = function() return S.SV.popupFontSize end,
			setFunc = function(value)
				S.SV.popupFontSize = value
			end,
			requiresReload = true,
		},
		{
			type = "dropdown",
			name = "Notification Font Size",
			tooltip = "Select the font size for notification messages (Staggered, Rooted, etc.)",
			choices = {24, 28, 30, 32, 34, 36, 40, 48, 54},
			getFunc = function() return S.SV.notificationFontSize end,
			setFunc = function(value)
				S.SV.notificationFontSize = value
			end,
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Only In Combat",
			tooltip = "Only show popups/sounds for stuns and other effects while in combat",
			getFunc = function() return S.SV.combatOnly end,
			setFunc = function(value) S.SV.combatOnly = value end,
			requiresReload = true,
		},
		{
			type = "header",
			name = "|t30:30:/esoui/art/notifications/gamepad/gp_notificationicon_duel.dds|t Stun Popups",
		},
		{
			type = "checkbox",
			name = "|cFFD700STUNNED!|r",
			tooltip = "Show blur and announcement when stunned",
			getFunc = function() return S.SV.trackStun end,
			setFunc = function(value) S.SV.trackStun = value end,
			width = "half",
		},
		{
			type = "colorpicker",
			name = "",
			tooltip = "Choose the color for stunned popup text",
			getFunc = function()
				local hex = S.SV.stunColor or "FF0000"
				local r = tonumber("0x" .. hex:sub(1,2)) / 255
				local g = tonumber("0x" .. hex:sub(3,4)) / 255
				local b = tonumber("0x" .. hex:sub(5,6)) / 255
				return r, g, b
			end,
			setFunc = function(r, g, b)
				local hex = string.format("%02X%02X%02X", r*255, g*255, b*255)
				S.SV.stunColor = hex
			end,
			disabled = function() return not S.SV.trackStun end,
			width = "half",
		},
		{
			type = "checkbox",
			name = "Sound",
			tooltip = "Play a sound when stunned",
			getFunc = function() return S.SV.stunSoundEnabled end,
			setFunc = function(value) S.SV.stunSoundEnabled = value end,
			disabled = function() return not S.SV.trackStun end,
			width = "half",
		},
		{
			type = "dropdown",
			name = "",
			tooltip = "Select sound to play when stunned",
			choices = soundChoices,
			getFunc = function() return S.SV.stunSound end,
			setFunc = function(value)
				S.SV.stunSound = value
				PlaySound(SOUNDS[value])
			end,
			disabled = function() return not S.SV.trackStun or not S.SV.stunSoundEnabled end,
			width = "half",
		},
		{
			type = "checkbox",
			name = "Text",
			tooltip = "Show on-screen text when stunned",
			getFunc = function() return S.SV.textStun end,
			setFunc = function(value) S.SV.textStun = value end,
			disabled = function() return not S.SV.trackStun end,
		},
		{
			type = "divider",
		},
		{
			type = "checkbox",
			name = "|cFFD700FEARED!|r",
			tooltip = "Show blur and announcement when feared",
			getFunc = function() return S.SV.trackFear end,
			setFunc = function(value) S.SV.trackFear = value end,
			width = "half",
		},
		{
			type = "colorpicker",
			name = "",
			tooltip = "Choose the color for feared popup text",
			getFunc = function()
				local hex = S.SV.fearColor or "FF0000"
				local r = tonumber("0x" .. hex:sub(1,2)) / 255
				local g = tonumber("0x" .. hex:sub(3,4)) / 255
				local b = tonumber("0x" .. hex:sub(5,6)) / 255
				return r, g, b
			end,
			setFunc = function(r, g, b)
				local hex = string.format("%02X%02X%02X", r*255, g*255, b*255)
				S.SV.fearColor = hex
			end,
			disabled = function() return not S.SV.trackFear end,
			width = "half",
		},
		{
			type = "checkbox",
			name = "Sound",
			tooltip = "Play a sound when feared",
			getFunc = function() return S.SV.fearSoundEnabled end,
			setFunc = function(value) S.SV.fearSoundEnabled = value end,
			disabled = function() return not S.SV.trackFear end,
			width = "half",
		},
		{
			type = "dropdown",
			name = "",
			tooltip = "Select sound to play when feared",
			choices = soundChoices,
			getFunc = function() return S.SV.fearSound end,
			setFunc = function(value)
				S.SV.fearSound = value
				PlaySound(SOUNDS[value])
			end,
			disabled = function() return not S.SV.trackFear or not S.SV.fearSoundEnabled end,
			width = "half",
		},
		{
			type = "checkbox",
			name = "Text",
			tooltip = "Show on-screen text when feared",
			getFunc = function() return S.SV.textFear end,
			setFunc = function(value) S.SV.textFear = value end,
			disabled = function() return not S.SV.trackFear end,
		},
		{
			type = "divider",
		},
		{
			type = "checkbox",
			name = "|cFFD700CHARMED!|r",
			tooltip = "Show blur and announcement when charmed",
			getFunc = function() return S.SV.trackCharm end,
			setFunc = function(value) S.SV.trackCharm = value end,
			width = "half",
		},
		{
			type = "colorpicker",
			name = "",
			tooltip = "Choose the color for charmed popup text",
			getFunc = function()
				local hex = S.SV.charmColor or "FF0000"
				local r = tonumber("0x" .. hex:sub(1,2)) / 255
				local g = tonumber("0x" .. hex:sub(3,4)) / 255
				local b = tonumber("0x" .. hex:sub(5,6)) / 255
				return r, g, b
			end,
			setFunc = function(r, g, b)
				local hex = string.format("%02X%02X%02X", r*255, g*255, b*255)
				S.SV.charmColor = hex
			end,
			disabled = function() return not S.SV.trackCharm end,
			width = "half",
		},
		{
			type = "checkbox",
			name = "Sound",
			tooltip = "Play a sound when charmed",
			getFunc = function() return S.SV.charmSoundEnabled end,
			setFunc = function(value) S.SV.charmSoundEnabled = value end,
			disabled = function() return not S.SV.trackCharm end,
			width = "half",
		},
		{
			type = "dropdown",
			name = "",
			tooltip = "Select sound to play when charmed",
			choices = soundChoices,
			getFunc = function() return S.SV.charmSound end,
			setFunc = function(value)
				S.SV.charmSound = value
				PlaySound(SOUNDS[value])
			end,
			disabled = function() return not S.SV.trackCharm or not S.SV.charmSoundEnabled end,
			width = "half",
		},
		{
			type = "checkbox",
			name = "Text",
			tooltip = "Show on-screen text when charmed",
			getFunc = function() return S.SV.textCharm end,
			setFunc = function(value) S.SV.textCharm = value end,
			disabled = function() return not S.SV.trackCharm end,
		},
		{
			type = "header",
			name = "|t35:35:/esoui/art/armory/buildicons/buildicon_72.dds|t Notifications",
		},
		{
			type = "checkbox",
			name = "|cFFD700ROOTED!|r",
			tooltip = "Show popup when rooted",
			getFunc = function() return S.SV.trackRooted end,
			setFunc = function(value) S.SV.trackRooted = value end,
			width = "half",
		},
		{
			type = "colorpicker",
			name = "",
			tooltip = "Choose the color for rooted popup text",
			getFunc = function()
				local hex = S.SV.rootedColor or "FF8C00"
				local r = tonumber("0x" .. hex:sub(1,2)) / 255
				local g = tonumber("0x" .. hex:sub(3,4)) / 255
				local b = tonumber("0x" .. hex:sub(5,6)) / 255
				return r, g, b
			end,
			setFunc = function(r, g, b)
				local hex = string.format("%02X%02X%02X", r*255, g*255, b*255)
				S.SV.rootedColor = hex
			end,
			disabled = function() return not S.SV.trackRooted end,
			width = "half",
		},
		{
			type = "checkbox",
			name = "Sound",
			tooltip = "Play a sound when rooted",
			getFunc = function() return S.SV.rootedSoundEnabled end,
			setFunc = function(value) S.SV.rootedSoundEnabled = value end,
			disabled = function() return not S.SV.trackRooted end,
			width = "half",
		},
		{
			type = "dropdown",
			name = "",
			tooltip = "Select sound to play when rooted",
			choices = soundChoices,
			getFunc = function() return S.SV.rootedSound end,
			setFunc = function(value)
				S.SV.rootedSound = value
				PlaySound(SOUNDS[value])
			end,
			disabled = function() return not S.SV.trackRooted or not S.SV.rootedSoundEnabled end,
			width = "half",
		},
		{
			type = "divider",
		},
		{
			type = "checkbox",
			name = "|cFFD700SILENCED!|r",
			tooltip = "Show popup when silenced",
			getFunc = function() return S.SV.trackSilenced end,
			setFunc = function(value) S.SV.trackSilenced = value end,
			width = "half",
		},
		{
			type = "colorpicker",
			name = "",
			tooltip = "Choose the color for silenced popup text",
			getFunc = function()
				local hex = S.SV.silencedColor or "4169E1"
				local r = tonumber("0x" .. hex:sub(1,2)) / 255
				local g = tonumber("0x" .. hex:sub(3,4)) / 255
				local b = tonumber("0x" .. hex:sub(5,6)) / 255
				return r, g, b
			end,
			setFunc = function(r, g, b)
				local hex = string.format("%02X%02X%02X", r*255, g*255, b*255)
				S.SV.silencedColor = hex
			end,
			disabled = function() return not S.SV.trackSilenced end,
			width = "half",
		},
		{
			type = "checkbox",
			name = "Sound",
			tooltip = "Play a sound when silenced",
			getFunc = function() return S.SV.silencedSoundEnabled end,
			setFunc = function(value) S.SV.silencedSoundEnabled = value end,
			disabled = function() return not S.SV.trackSilenced end,
			width = "half",
		},
		{
			type = "dropdown",
			name = "",
			tooltip = "Select sound to play when silenced",
			choices = soundChoices,
			getFunc = function() return S.SV.silencedSound end,
			setFunc = function(value)
				S.SV.silencedSound = value
				PlaySound(SOUNDS[value])
			end,
			disabled = function() return not S.SV.trackSilenced or not S.SV.silencedSoundEnabled end,
			width = "half",
		},
		{
			type = "divider",
		},
		{
			type = "checkbox",
			name = "|cFFD700STAGGERED!|r",
			tooltip = "Show popup when staggered",
			getFunc = function() return S.SV.trackStaggered end,
			setFunc = function(value) S.SV.trackStaggered = value end,
			width = "half",
		},
		{
			type = "colorpicker",
			name = "",
			tooltip = "Choose the color for staggered popup text",
			getFunc = function()
				local hex = S.SV.staggeredColor or "FFD700"
				local r = tonumber("0x" .. hex:sub(1,2)) / 255
				local g = tonumber("0x" .. hex:sub(3,4)) / 255
				local b = tonumber("0x" .. hex:sub(5,6)) / 255
				return r, g, b
			end,
			setFunc = function(r, g, b)
				local hex = string.format("%02X%02X%02X", r*255, g*255, b*255)
				S.SV.staggeredColor = hex
			end,
			disabled = function() return not S.SV.trackStaggered end,
			width = "half",
		},
		{
			type = "checkbox",
			name = "Sound",
			tooltip = "Play a sound when staggered",
			getFunc = function() return S.SV.staggeredSoundEnabled end,
			setFunc = function(value) S.SV.staggeredSoundEnabled = value end,
			disabled = function() return not S.SV.trackStaggered end,
			width = "half",
		},
		{
			type = "dropdown",
			name = "",
			tooltip = "Select sound to play when staggered",
			choices = soundChoices,
			getFunc = function() return S.SV.staggeredSound end,
			setFunc = function(value)
				S.SV.staggeredSound = value
				PlaySound(SOUNDS[value])
			end,
			disabled = function() return not S.SV.trackStaggered or not S.SV.staggeredSoundEnabled end,
			width = "half",
		},
		{
			type = "divider",
		},
		{
			type = "checkbox",
			name = "|cFFD700PACIFIED!|r",
			tooltip = "Show popup when pacified",
			getFunc = function() return S.SV.trackPacified end,
			setFunc = function(value) S.SV.trackPacified = value end,
			width = "half",
		},
		{
			type = "colorpicker",
			name = "",
			tooltip = "Choose the color for pacified popup text",
			getFunc = function()
				local hex = S.SV.pacifiedColor or "4169E1"
				local r = tonumber("0x" .. hex:sub(1,2)) / 255
				local g = tonumber("0x" .. hex:sub(3,4)) / 255
				local b = tonumber("0x" .. hex:sub(5,6)) / 255
				return r, g, b
			end,
			setFunc = function(r, g, b)
				local hex = string.format("%02X%02X%02X", r*255, g*255, b*255)
				S.SV.pacifiedColor = hex
			end,
			disabled = function() return not S.SV.trackPacified end,
			width = "half",
		},
		{
			type = "checkbox",
			name = "Sound",
			tooltip = "Play a sound when pacified",
			getFunc = function() return S.SV.pacifiedSoundEnabled end,
			setFunc = function(value) S.SV.pacifiedSoundEnabled = value end,
			disabled = function() return not S.SV.trackPacified end,
			width = "half",
		},
		{
			type = "dropdown",
			name = "",
			tooltip = "Select sound to play when pacified",
			choices = soundChoices,
			getFunc = function() return S.SV.pacifiedSound end,
			setFunc = function(value)
				S.SV.pacifiedSound = value
				PlaySound(SOUNDS[value])
			end,
			disabled = function() return not S.SV.trackPacified or not S.SV.pacifiedSoundEnabled end,
			width = "half",
		},
		{
			type = "divider",
		},
		{
			type = "checkbox",
			name = "|cFFD700OFF-BALANCE!|r",
			tooltip = "Show popup when off-balance",
			getFunc = function() return S.SV.trackOffBalance end,
			setFunc = function(value) S.SV.trackOffBalance = value end,
			width = "half",
		},
		{
			type = "colorpicker",
			name = "",
			tooltip = "Choose the color for off-balance popup text",
			getFunc = function()
				local hex = S.SV.offBalanceColor or "00CED1"
				local r = tonumber("0x" .. hex:sub(1,2)) / 255
				local g = tonumber("0x" .. hex:sub(3,4)) / 255
				local b = tonumber("0x" .. hex:sub(5,6)) / 255
				return r, g, b
			end,
			setFunc = function(r, g, b)
				local hex = string.format("%02X%02X%02X", r*255, g*255, b*255)
				S.SV.offBalanceColor = hex
			end,
			disabled = function() return not S.SV.trackOffBalance end,
			width = "half",
		},
		{
			type = "checkbox",
			name = "Sound",
			tooltip = "Play a sound when off-balance",
			getFunc = function() return S.SV.offBalanceSoundEnabled end,
			setFunc = function(value) S.SV.offBalanceSoundEnabled = value end,
			disabled = function() return not S.SV.trackOffBalance end,
			width = "half",
		},
		{
			type = "dropdown",
			name = "",
			tooltip = "Select sound to play when off-balance",
			choices = soundChoices,
			getFunc = function() return S.SV.offBalanceSound end,
			setFunc = function(value)
				S.SV.offBalanceSound = value
				PlaySound(SOUNDS[value])
			end,
			disabled = function() return not S.SV.trackOffBalance or not S.SV.offBalanceSoundEnabled end,
			width = "half",
		},
	}

	LAM:RegisterAddonPanel("StunnedPanel", panelData)
	LAM:RegisterOptionControls("StunnedPanel", optionsData)
end