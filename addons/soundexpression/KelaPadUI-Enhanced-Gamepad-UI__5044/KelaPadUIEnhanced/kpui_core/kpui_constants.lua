kpuiConst = {}


kpuiConst.stringDDS = {
	["rightStickXBOne"] = "esoui/art/buttons/gamepad/xbox/nav_xbone_rs_press.dds",
	["leftStickXBOne"] = "esoui/art/buttons/gamepad/xbox/nav_xbone_ls_press.dds",
}

-- Shared shortcut for the additional gamepad menu filters.  L3 is reserved by
-- the crafting advisor for cycling writs, and the face buttons are occupied.
kpuiConst.GamepadFilterKeybind = "UI_SHORTCUT_QUINARY"


kpuiConst.Colors = {
	COLOR_ORANGE 			= ZO_ColorDef:New(220/255, 129/255, 34/255),
	COLOR_GOLD 				= ZO_ColorDef:New(254/255, 234/255, 2/255),
	COLOR_RED 				= ZO_ColorDef:New(255/255, 25/255, 25/255),
	COLOR_WHITE 			= ZO_ColorDef:New(255/255, 255/255, 255/255),
	COLOR_OFF_WHITE 		= ZO_ColorDef:New("AFAFAF"),
	COLOR_BROWN 			= ZO_ColorDef:New(197/255, 194/255, 158/255),
	COLOR_GREEN 			= ZO_ColorDef:New(0/255, 136/255, 103/255),
	COLOR_BLUE 				= ZO_ColorDef:New(0/255, 80/255, 159/255),
	COLOR_GREY 				= ZO_ColorDef:New("5c5c5c"),
	COLOR_POISON 			= ZO_ColorDef:New(162/255, 192/255, 78/255),
	COLOR_SOON 				= ZO_ColorDef:New(16/255, 154/255, 184/255),
	COLOR_NOTSOON 			= ZO_ColorDef:New(238/255, 202/255, 42/255),

	COLOR_LIGHT_GREEN 		= ZO_ColorDef:New(106/255, 203/255, 106/255),
	COLOR_LIGHT_ORANGE 		= ZO_ColorDef:New(235/255, 168/255, 95/255),
	COLOR_LIGHT_RED 		= ZO_ColorDef:New(230/255, 105/255, 105/255),
	COLOR_LIGHT_BLUE 		= ZO_ColorDef:New(77/255, 184/255, 255/255),

	-- These are INTERFACE_COLOR_TYPE_GAMEPAD_TOOLTIP field indices, not ZO_ColorDef objects.
	GENERAL_COLOR_WHITE 	= GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1,
	GENERAL_COLOR_OFF_WHITE = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_3,
	GENERAL_COLOR_NORMAL	= ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL)),
	COLOR_HEALTH  			= ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_POWER, POWERTYPE_HEALTH)),
	COLOR_MAGICKA 			= ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_POWER, POWERTYPE_MAGICKA)),
	COLOR_STAMINA 			= ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_POWER, POWERTYPE_STAMINA)),
	COLOR_VIOLET  			= ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_DISPLAY_QUALITY_ARTIFACT)),
	COLOR_MYTHIC  			= ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE)),
	COLOR_BROWN1   			= ZO_ColorDef:New("885533"),
	COLOR_TEAL    			= ZO_ColorDef:New("66CCCC"),
	COLOR_PINK    			= ZO_ColorDef:New("FF99CC"),
	COLOR_ATT    			= ZO_ColorDef:New("c5e010"),
	COLOR_TTC    			= ZO_ColorDef:New("f23d8e"),


	COLOR_DEALGREAT 		= ZO_ColorDef:New(82/255, 167/255, 49/255),
	COLOR_DEALGOOD 			= ZO_ColorDef:New(0/255, 136/255, 103/255),
	COLOR_DEALNORMAL		= ZO_ColorDef:New(16/255, 154/255, 184/255),
	COLOR_DEALBAD 			= ZO_ColorDef:New(220/255, 129/255, 34/255),
	COLOR_DEALTERRIBLE 		= ZO_ColorDef:New(255/255, 25/255, 25/255),

}

-- Shared text styles.  Every user-facing label in KelaPadUI should take one of
-- these so the add-on reads consistently: bold gold section titles, white body
-- text, and one semantic colour per value state.  Apply a style with
-- KelaApplyTextStyle (plain labels) or KelaApplyEntryTextStyle (gamepad rows).
kpuiConst.TextStyles = {
	-- Screen and page titles.
	Title 					= { font = "ZoFontGamepadCondensed54", color = kpuiConst.Colors.COLOR_WHITE },
	-- Section titles, e.g. the WEAPONS / ARMOR / JEWELRY labels.
	SectionTitle 			= { font = "ZoFontGamepadBold22", color = kpuiConst.Colors.COLOR_GOLD },
	-- Headers inside a list, e.g. the CHARACTERS row.  This mirrors the game's own
	-- list headers (ZO_GamepadMenuEntryHeaderTemplate): bold, uppercase, the
	-- interface normal text colour, left-aligned at the list indent.
	ListHeader 				= { font = "ZoFontGamepadBold22", color = kpuiConst.Colors.GENERAL_COLOR_NORMAL },
	-- The selected character's name on the trait research page, larger than body
	-- text so it reads as the page's subject.
	CharacterName 			= { font = "ZoFontGamepadCondensed42", color = kpuiConst.Colors.COLOR_WHITE },
	-- Normal body text.
	Body 					= { font = "ZoFontGamepad20", color = kpuiConst.Colors.COLOR_WHITE },
	-- Larger body text, e.g. trait names and group headings.
	BodyLarge 				= { font = "ZoFontGamepad27", color = kpuiConst.Colors.COLOR_WHITE },
	-- Secondary text.
	Dim 					= { font = "ZoFontGamepad20", color = kpuiConst.Colors.COLOR_OFF_WHITE },
	-- Value colours: complete, close to full, full, and a running timer.
	ValuePositive 			= { color = kpuiConst.Colors.COLOR_LIGHT_GREEN },
	ValueWarning 			= { color = kpuiConst.Colors.COLOR_LIGHT_ORANGE },
	ValueNegative 			= { color = kpuiConst.Colors.COLOR_LIGHT_RED },
	ValueTimer 				= { color = kpuiConst.Colors.COLOR_GOLD },
}

	 -- tooltips size
KELA_TOOLTIPS_WIDTH = 470 --650
KELA_TOOLTIPS_CONTENT_WIDTH = KELA_TOOLTIPS_WIDTH - 2 * 40
KELA_TOOLTIPS_CONTENT_WIDTH_PERCENT = 100
KELA_TOOLTIPS_FONT_BIG = 32
KELA_TOOLTIPS_FONT_MEDIUM = 27
KELA_TOOLTIPS_FONT_SMALL = 23

	
-- SI_ITEM_FORMAT_STR_SET_NAME is overridden with SafeAddString in
-- kpui_sets_gamepad.lua; it is a numeric string ID, not a format string.
