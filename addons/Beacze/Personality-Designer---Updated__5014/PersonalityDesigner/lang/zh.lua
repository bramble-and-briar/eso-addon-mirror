PersonalityDesigner = {
	name = "PersonalityDesigner",
	title = "Personality Designer",
	author = "Atronyx, Alianym, Tes96",
	version = "2.0.0",
	savedVariablesVersion = 999,
}

local PD = PersonalityDesigner

-- Translated by Lykeion
local stringsZH = {
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
	P_DESIGNER_ACTIVE_PERSONALITY = "启用个性",

	P_DESIGNER_IDLE = "闲置时间(秒)",
	P_DESIGNER_IDLE_DESC = "设定在表情/纪念品开始播放前的闲置时间.",

	P_DESIGNER_DELAY = "间隔时间(秒)",
	P_DESIGNER_DELAY_DESC = "设定表情/纪念品播放的间隔时间.",

	P_DESIGNER_NAME_TOOLTIP = "名称不可以重复!",

	P_DESIGNER_FREQ = "频率",
	P_DESIGNER_ACTION = "动作",
	P_DESIGNER_DESIGN = "设计",

	-- Presets --
	P_DESIGNER_DEFAULT_BLANK = "空白",
	P_DESIGNER_DEFAULT_FIT = "保持健康",
	P_DESIGNER_DEFAULT_MAGIC = "魔法精通",
	P_DESIGNER_DEFAULT_RUDE = "粗鲁无礼",


	-- Keybind Actions --
	P_DESIGNER_CYCLE = "循环",
	P_DESIGNER_CYCLE_TO = "循环至",
	P_DESIGNER_EMPTY = "清空个性!",
	P_DESIGNER_CYCLE_EMPTY = "清空个性! 切换至关闭.",
	
		
	-- Frequency --
	P_DESIGNER_INFREQUENT = "罕用",
	P_DESIGNER_DEFAULT = "默认",
	P_DESIGNER_FREQUENT = "常用",
	
	-- Design Action --
	P_DESIGNER_ACTION_01 = "动作 01",
	P_DESIGNER_ACTION_02 = "动作 02",
	P_DESIGNER_ACTION_03 = "动作 03",
	P_DESIGNER_ACTION_04 = "动作 04",
	P_DESIGNER_ACTION_05 = "动作 05",
	P_DESIGNER_ACTION_06 = "动作 06",
	P_DESIGNER_ACTION_07 = "动作 07",
	P_DESIGNER_ACTION_08 = "动作 08",
	P_DESIGNER_ACTION_09 = "动作 09",
	P_DESIGNER_ACTION_10 = "动作 10",
	
	P_DESIGNER_PDENABLED = "是否启用 Personality Designer:",
}

for id, stringVar in pairs(stringsZH) do
   ZO_CreateStringId(id, stringVar)
   SafeAddVersion(id, 1)
end

ZO_CreateStringId("SI_BINDING_NAME_PD1", zo_strformat("<<1>><<2>> <<3>><<4>>", "|cEECA2A", GetString(P_DESIGNER_TOGGLE), GetString(P_DESIGNER_PERSONALITY), "|r"))
ZO_CreateStringId("SI_BINDING_NAME_PD2", zo_strformat("<<1>><<2>> <<3>><<4>>", "|cEECA2A", GetString(P_DESIGNER_CYCLE), GetString(P_DESIGNER_PERSONALITY), "|r"))
ZO_CreateStringId("SI_BINDING_NAME_PD_MENU", zo_strformat("<<1>><<2>> <<3>> <<4>><<5>>", "|cEECA2A", GetString(P_DESIGNER_OPEN), PD.title, GetString(P_DESIGNER_MENU), "|r"))