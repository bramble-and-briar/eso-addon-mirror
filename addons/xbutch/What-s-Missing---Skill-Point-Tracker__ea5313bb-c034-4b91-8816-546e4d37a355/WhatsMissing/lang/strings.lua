local strings = {
	SPT_GUI_CHAR_LEVEL	= "Character Level",
	SPT_GUI_MAIN_QUEST	= "Main Quest",
	SPT_GUI_FOLIUM		= "Folium Discognitum",
	SPT_GUI_TUTORIAL	= "Tutorial",
	SPT_GUI_AVA_RANK	= "Alliance War Rank",
	SPT_GUI_MAEL_ARENA	= "Maelstrom Arena",


	SPT_GUI_TITLE		= "What's missing? - Skill Point Tracker",
	SPT_GUI_PANEL_HEADER	= "SKILL POINT TRACKER",
	SPT_GUI_INFO_HEADER	= "Quest lists",

	SPT_GUI_GSP		= "General Skill Points",
	SPT_GUI_SQS		= "Storyline Quests & Skyshards",
	SPT_GUI_GDQ		= "Group Dungeon Quests",
	SPT_GUI_PDB		= "Public Dungeon Group Boss Events",
	SPT_GUI_SOURCE		= "Source",
	SPT_GUI_PROGRESS	= "Progress",
	SPT_GUI_ZONE		= "Zone",
	SPT_GUI_STORYLINE	= "Storyline",
	SPT_GUI_SKYSHARDS	= "Skyshards",
	SPT_GUI_NOWHERE_VAULT = "Nowhere Vault",
	SPT_GUI_GROUP_DUNGEON = "Group Dungeon",
	SPT_GUI_PUBLIC_DUNGEON = "Public Dungeon",
	SPT_GUI_DUNGEON_NAME = "Dungeon Name",

	SPT_GUI_TOTAL		= "Total",
	SPT_GUI_CHAR_TOTAL	= "Character Total",
	SPT_GUI_UNASSIGNED	= "unassigned",


	SI_BINDING_NAME_SPT_TOGGLE      = "Skill Point Tracker",
	SI_BINDING_NAME_SPT_TAB_PREV    = "Prev Tab",
	SI_BINDING_NAME_SPT_TAB_NEXT    = "Next Tab",

	SPT_GUI_TAB_GSP  = "General",
	SPT_GUI_TAB_SQS  = "Zones",
	SPT_GUI_TAB_GDQ  = "Dungeons",
	SPT_GUI_TAB_PD   = "Public",
	SPT_GUI_SCANNING = "Scanning...",

	SPT_GUI_ZN_MQ		= "Main Quest",

	SPT_MSG_SHOW_GUI	= "SPT displayed.",
	SPT_MSG_HIDE_GUI	= "SPT hidden.",

	SPT_MSG_INIT		= "Running SPT for the first time!",
	SPT_MSG_HELP		= "SPT Activated!",

	SPT_QUEST_NA		= "These skill points are not quest based.",
	SPT_QUEST_NONE		= "There are no skill point quests in this zone.",

	SPT_GUI_NOT_SCANNED	= "Not yet scanned - play this character once",
	SPT_GUI_TAB_SKILLS = "Skills",
	SPT_GUI_TAB_SCRIBING = "Scribing",
	SPT_GUI_LIVE = "Live",
	SPT_GUI_LAST_SCANNED = "Last scanned",
	SPT_GUI_DATA_UNAVAILABLE = "Progression data is not ready",
	SPT_GUI_SKILLS_LEGEND = "Groups: maxed/total | -- undiscovered | * inactive | ? unknown",
	SPT_GUI_SKILLS_RANK_LEGEND = "Rank | -- undiscovered | * inactive | ? unknown",
	SPT_GUI_SCRIBING_HELP = "Groups: known/total | %s Known | %s Missing | %s Not scanned",
	SPT_GUI_SKILL_LINE = "Skill line",
	SPT_GUI_SCRIPT = "Script",
	SPT_GUI_SCRIPT_ACQUISITION = "How to obtain",
	SPT_GUI_SCRIPT_ACQUISITION_UNAVAILABLE = "Acquisition details are unavailable for this script.",
	SPT_GUI_SCRIPT_GROUP_HELP = "Expand this group and select a script to see how to obtain it.",
	SPT_GUI_SCRIPT_PICKUP = "Fixed pickup - Mages Guild",
	SPT_GUI_PICKUP_PHYSICAL = "Auridon, Vulkhel Guard: upstairs on a table.",
	SPT_GUI_PICKUP_STUN = "Glenumbra, Daggerfall: ground floor, left of the Eyevea portal.",
	SPT_GUI_PICKUP_SHIELD = "Stonefalls, Davon's Watch: ground floor, in the stairwell.",
	SPT_GUI_PICKUP_DRUID = "Stormhaven, Wayrest: upstairs on a bookshelf.",
	SPT_GUI_PICKUP_WARRIOR = "Grahtwood, Elden Root: upper floor, right of the floor circle beside glowing mushrooms.",
	SPT_GUI_PICKUP_HUNTER = "Deshaan, Mournhold: outdoor tunnel, on a table beside a candlestick.",
	SPT_GUI_PICKUP_VULNERABILITY = "Bangkorai, Evermore: ground floor, straight ahead as you enter.",
	SPT_GUI_PICKUP_VITALITY = "Reaper's March, Rawl'kha: outside, on a crate near the writ board.",
	SPT_GUI_PICKUP_MAIM = "The Rift, Riften: upstairs on a high shelf.",
	SPT_GUI_SCRIPT_PICKUP_REQUIREMENT = "Requires the Sigil of the Luminary Dragon (The Wing of the Dragon).",
	SPT_GUI_SET_SCRIPT_WAYPOINT = "Set pickup waypoint",
	SPT_MSG_SCRIPT_WAYPOINT_SET = "Waypoint set to %s.",
	SPT_MSG_SCRIPT_WAYPOINT_FAILED = "The pickup waypoint could not be set.",
	SPT_GUI_CHARACTER_RANGE = "Characters %d-%d of %d",
	SPT_GUI_SCROLL_LEFT = "Scroll left",
	SPT_GUI_SCROLL_RIGHT = "Scroll right",
	SPT_GUI_EXPAND = "Expand",
	SPT_GUI_COLLAPSE = "Collapse",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
