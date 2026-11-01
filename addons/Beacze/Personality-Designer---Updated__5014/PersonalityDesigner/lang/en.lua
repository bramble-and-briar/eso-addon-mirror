PersonalityDesigner = {
	name = "PersonalityDesigner",
	title = "Personality Designer",
	author = "Atronyx, Alianym, Tes96",
	version = "2.0.0",
	savedVariablesVersion = 999,
}

local PD = PersonalityDesigner

local stringsEN = {
	-- These use ZOS localization
	P_DESIGNER_MENU = GetString(SI_BINDING_NAME_GAMEPAD_TOGGLE_GAME_CAMERA_UI_MODE),
	P_DESIGNER_PERSONALITY = GetString(SI_COLLECTIBLECATEGORYTYPE9),
	P_DESIGNER_OPEN = GetString(SI_GIFT_INVENTORY_OPEN_KEYBIND),
	P_DESIGNER_TOGGLE = GetString(SI_GAMEPAD_TOGGLE_OPTION),
	P_DESIGNER_ACTIVE = GetString(SI_RESTYLE_SHEET_HEADER),
	P_DESIGNER_CATEGORY = GetString(SI_ITEMLISTSORTTYPE1),
	P_DESIGNER_DISABLED = GetString(SI_ADDONLOADSTATE3),
	P_DESIGNER_ENABLED = GetString(SI_ADDONLOADSTATE2),	
	P_DESIGNER_CREATE = GetString(SI_DIALOG_CREATE),
	P_DESIGNER_DELETE = GetString(SI_MAIL_DELETE),

	P_DESIGNER_CEREMONIAL = GetString(SI_EMOTECATEGORY1),
	P_DESIGNER_CHEERS_JEERS = GetString(SI_EMOTECATEGORY2),
	P_DESIGNER_EMOTION = GetString(SI_EMOTECATEGORY4),
	P_DESIGNER_ENTERTAIN = GetString(SI_EMOTECATEGORY5),
	P_DESIGNER_FOOD_DRINK = GetString(SI_EMOTECATEGORY6),
	P_DESIGNER_DIRECTIONS = GetString(SI_EMOTECATEGORY7),
	P_DESIGNER_PHYSICAL = GetString(SI_EMOTECATEGORY9),
	P_DESIGNER_POSES = GetString(SI_EMOTECATEGORY10),
	P_DESIGNER_PROP = GetString(SI_EMOTECATEGORY11),
	P_DESIGNER_SOCIAL = GetString(SI_EMOTECATEGORY12),

	P_DESIGNER_MEMENTO = GetString(SI_COLLECTIBLECATEGORYTYPE5),

	-- These need translation
	-- AddOn Menu --
	P_DESIGNER_ACTIVE_PERSONALITY = "Active Personality",

	P_DESIGNER_IDLE = "Idle Time (seconds)",
	P_DESIGNER_IDLE_DESC = "Set the idle time before emotes/mementos start.",

	P_DESIGNER_DELAY = "Delay Time (seconds)",
	P_DESIGNER_DELAY_DESC = "Set the delay between emotes/mementos.",

	P_DESIGNER_NAME_TOOLTIP = "The name must be unique!",

	P_DESIGNER_FREQ = "Frequency",
	P_DESIGNER_ACTION = "Action",
	P_DESIGNER_DESIGN = "Design",

	-- Presets --
	P_DESIGNER_DEFAULT_BLANK = "Blank",
	P_DESIGNER_DEFAULT_FIT = "Keep Fit",
	P_DESIGNER_DEFAULT_MAGIC = "Magical",
	P_DESIGNER_DEFAULT_RUDE = "Rude",


	-- Keybind Actions --
	P_DESIGNER_CYCLE = "Cycle",
	P_DESIGNER_CYCLE_TO = "Cycled To",
	P_DESIGNER_EMPTY = "Empty Personality!",
	P_DESIGNER_CYCLE_EMPTY = "Empty Personality! Switched to Disabled.",
	
	-- Frequency --
	P_DESIGNER_INFREQUENT = "Infrequent",
	P_DESIGNER_DEFAULT = "Default",
	P_DESIGNER_FREQUENT = "Frequent",
	
	-- Design Action --
	P_DESIGNER_ACTION_01 = "Action 01",
	P_DESIGNER_ACTION_02 = "Action 02",
	P_DESIGNER_ACTION_03 = "Action 03",
	P_DESIGNER_ACTION_04 = "Action 04",
	P_DESIGNER_ACTION_05 = "Action 05",
	P_DESIGNER_ACTION_06 = "Action 06",
	P_DESIGNER_ACTION_07 = "Action 07",
	P_DESIGNER_ACTION_08 = "Action 08",
	P_DESIGNER_ACTION_09 = "Action 09",
	P_DESIGNER_ACTION_10 = "Action 10",
	
	P_DESIGNER_PDENABLED = "Personality Designer enabled:",
}

for id, stringVar in pairs(stringsEN) do
   ZO_CreateStringId(id, stringVar)
   SafeAddVersion(id, 1)
end

ZO_CreateStringId("SI_BINDING_NAME_PD1", zo_strformat("<<1>><<2>> <<3>><<4>>", "|cEECA2A", GetString(P_DESIGNER_TOGGLE), GetString(P_DESIGNER_PERSONALITY), "|r"))
ZO_CreateStringId("SI_BINDING_NAME_PD2", zo_strformat("<<1>><<2>> <<3>><<4>>", "|cEECA2A", GetString(P_DESIGNER_CYCLE), GetString(P_DESIGNER_PERSONALITY), "|r"))
ZO_CreateStringId("SI_BINDING_NAME_PD_MENU", zo_strformat("<<1>><<2>> <<3>> <<4>><<5>>", "|cEECA2A", GetString(P_DESIGNER_OPEN), PD.title, GetString(P_DESIGNER_MENU), "|r"))