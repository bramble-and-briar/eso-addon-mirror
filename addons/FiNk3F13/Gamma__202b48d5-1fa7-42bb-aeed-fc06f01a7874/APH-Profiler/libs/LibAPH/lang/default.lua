--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local function RegisterString(id, text)
	if _G[id] then
		SafeAddString(_G[id], text, 1)
	else
		ZO_CreateStringId(id, text)
		SafeAddVersion(_G[id], 1)
	end
end

local strings = {

	ACTIVE_SCOPE = "Active scope",
	ALCHEMY_MATERIAL = "alchemy material",
	ALLIANCE_WAR_QUEST_TRACKED = "Alliance War quest tracked",
	ANY_QUEST_TRACKED = "Any quest tracked",
	ARMOUR = "armour",
	AT_A_CRAFTING_STATION = "At a crafting station",
	BATTLEGROUND = "Battleground",
	BATTLEGROUND_QUEST_TRACKED = "Battleground quest tracked",
	BLACKSMITHING_MATERIAL = "blacksmithing material",
	CLASS_QUEST_TRACKED = "Class quest tracked",
	CLOSE = "Close",
	CLOTHING_MATERIAL = "clothing material",
	COLLECTIBLE = "collectible",
	COMPANION_ITEM = "companion item",
	COMPANION_QUEST_TRACKED = "Companion quest tracked",
	CONSUMABLE = "consumable",
	COPY_PASTE_THE_CONTENT_OF_THIS = "COPY PASTE THE CONTENT OF THIS WINDOW AND PASTE IT ON https://pastebin.com/ AND SUBMIT THE LINK.",
	COPY_PASTE_THIS_BUG_REPORT = "COPY & PASTE THIS BUG REPORT",
	CRAFTING_MATERIAL = "crafting material",
	CRAFTING_WRIT_TRACKED = "Crafting writ tracked",
	CYRODIIL_OR_IMPERIAL_CITY = "Cyrodiil or Imperial City",
	DAILY_QUEST_TRACKED_THAT_IS_NOT = "Daily quest tracked that is not crafting",
	DISMISS_BUG = "Dismiss Bug",
	DUNGEON_ARENA_OR_TRIAL = "Dungeon, Arena or Trial",
	DUNGEON_QUEST_TRACKED = "Dungeon quest tracked",
	ENCHANTING_MATERIAL = "enchanting material",
	FURNISHING_MATERIAL = "furnishing material",
	GROUP = "Group",
	GROUP_QUEST_TRACKED = "Group quest tracked",
	GUILD_QUEST_TRACKED_THIEVES_GUILD_DARK = "Guild quest tracked (Thieves Guild, Dark Brotherhood, Fighters, Mages)",
	HOLIDAY_EVENT_QUEST_TRACKED = "Holiday event quest tracked",
	INFINITE_ARCHIVE = "Infinite Archive",
	INSIDE_A_HOUSE = "Inside a house",
	IN_A_GROUP = "In a group",
	IN_A_GROUP_WITH_ONE_OF = "In a group with one of the names below",
	JEWELLERY_CRAFTING_MATERIAL = "jewellery crafting material",
	JUNK_ITEM = "junk item",
	LESS_THAN_0_1_MB = "less than 0.1 MB",
	LOADING = "Loading...",
	MAIN_STORY_QUEST_TRACKED = "Main story quest tracked",
	MASTER_WRIT_TRACKED = "Master writ tracked",
	MISCELLANEOUS_ITEM = "miscellaneous item",
	MORE_INFO = "More Info (<<1>>)",
	MORE_INFO_0 = "More Info (0)",
	NAVIGATE = "Navigate",
	NEWER_VERSION = " (Newer Version)",
	NO_MATCHES = "No matches",
	NO_MATCHES_FOR = "No matches for \"%s\"",
	NO_MATCHES_FOR_YET = "No matches for \"%s\" yet",
	OLD_VERSION = " (Old Version)",
	OPEN = "Open",
	OPEN_PASTEBIN_COM_IN_YOUR_BROWSER = "Open pastebin.com in your browser? Paste this report there, submit it, and share the link.",
	OVERLAND = "Overland",
	PICKED_ANYTHING_UP_IN_THE_LAST = "Picked anything up in the last minute",
	PICKED_UP_A_IN_THE_LAST_MINUTE = "Picked up a %s in the last minute",
	PICKED_UP_A_STOLEN_ITEM_IN = "Picked up a stolen item in the last minute",
	PICKUPS = "Pickups",
	PIECE_OF_JEWELLERY = "piece of jewellery",
	PROLOGUE_QUEST_TRACKED = "Prologue quest tracked",
	PROVISIONING_MATERIAL = "provisioning material",
	QUESTS = "Quests",
	QUEST_ITEM = "quest item",
	REPEATABLE_OR_DAILY_QUEST_TRACKED = "Repeatable or daily quest tracked",
	SCOPE = "Scope: ",
	SCOPES = "Scopes",
	SCOPE_2 = "Scope",
	SCRIBING_QUEST_TRACKED = "Scribing quest tracked",
	SEARCH_AGAIN = "Search again",
	SELECT_ALL = "Select All",
	SIDE_QUEST_TRACKED_ZONE_DELVE_WORLD = "Side quest tracked (zone, delve, world)",
	STYLE_MATERIAL = "style material",
	TALES_OF_TRIBUTE_MATCH = "Tales of Tribute match",
	TALES_OF_TRIBUTE_QUEST_TRACKED = "Tales of Tribute quest tracked",
	TAMRIEL_TALE_TRACKED = "Tamriel tale tracked",
	TRAIT_MATERIAL = "trait material",
	TRIAL_QUEST_TRACKED = "Trial quest tracked",
	TURN_SCOPES_ON_OR_OFF = "Turn scopes on or off",
	CLEAR_RECENT_SEARCHES = "Clear recent searches",
	UNDAUNTED_PLEDGE_TRACKED = "Undaunted pledge tracked",
	WEAPON = "weapon",
	WHERE_YOU_ARE = "Where you are",
	WIPE_ALL_BUGS = "Wipe All Bugs",
	WOODWORKING_MATERIAL = "woodworking material",
}

for key, text in pairs(strings) do
	RegisterString("SI_LIBAPH_" .. key, text)
end
