--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local LibAPH = LibAPH

local LOOT_WINDOW_MS = 60000
local last_loot_ms = 0

local function IsInGroupInstance()
	return GetCurrentZoneDungeonDifficulty() ~= DUNGEON_DIFFICULTY_NONE
end

local function IsInPvP()
	return IsPlayerInAvAWorld() or IsInAvAZone() or IsInImperialCity()
end

local function IsInHouse()
	local house_id = GetCurrentZoneHouseId()
	return house_id ~= nil and house_id ~= 0
end

local function IsCrafting()
	local interaction = GetCraftingInteractionType()
	return interaction ~= nil and interaction ~= CRAFTING_TYPE_INVALID
end

local function IsInTributeMatch()
	if type(TRIBUTE) ~= "table" or type(TRIBUTE.GetGameFlowState) ~= "function" then return false end
	local state = TRIBUTE:GetGameFlowState()
	return state ~= nil and state ~= TRIBUTE_GAME_FLOW_STATE_INACTIVE
end

local function ForEachTrackedQuest(callback)
	for i = 1, GetNumJournalQuests() do
		if IsValidQuestIndex(i) then
			local _, _, _, _, _, completed, tracked, _, _, quest_type = GetJournalQuestInfo(i)
			if tracked and not completed and callback(i, quest_type) then return true end
		end
	end
	return false
end

local function HasTrackedQuest()
	return ForEachTrackedQuest(function() return true end)
end

local function HasTrackedQuestOfType(quest_type)
	return ForEachTrackedQuest(function(_, tracked_type) return tracked_type == quest_type end)
end

local function HasTrackedRepeatableQuest()
	return ForEachTrackedQuest(function(index)
		local repeat_type = GetJournalQuestRepeatType(index)
		return repeat_type ~= QUEST_REPEAT_NOT_REPEATABLE
	end)
end

local function HasTrackedDailyQuest()
	return ForEachTrackedQuest(function(index, quest_type)
		return quest_type ~= QUEST_TYPE_CRAFTING and GetJournalQuestRepeatType(index) == QUEST_REPEAT_DAILY
	end)
end

local function HasTrackedWritQuest()
	return ForEachTrackedQuest(function(index, quest_type)
		return quest_type == QUEST_TYPE_CRAFTING and GetJournalQuestRepeatType(index) ~= QUEST_REPEAT_NOT_REPEATABLE
	end)
end

local function HasTrackedMasterWritQuest()
	return ForEachTrackedQuest(function(index, quest_type)
		return quest_type == QUEST_TYPE_CRAFTING and GetJournalQuestRepeatType(index) == QUEST_REPEAT_NOT_REPEATABLE
	end)
end

local function IsGrouped()
	return GetGroupSize() > 1
end

function LibAPH.GetGroupDisplayNames()
	local names = {}
	for i = 1, GetGroupSize() do
		local unit_tag = GetGroupUnitTagByIndex(i)
		if unit_tag then
			local display_name = GetUnitDisplayName(unit_tag)
			if display_name and display_name ~= "" then names[display_name] = true end
		end
	end
	return names
end

local PLAYER_STATUS_ICON = {
	[PLAYER_STATUS_ONLINE] = "/esoui/art/tutorial/tutorial_illo_status_online.dds",
	[PLAYER_STATUS_OFFLINE] = "/esoui/art/tutorial/tutorial_illo_status_offline.dds",
	[PLAYER_STATUS_AWAY] = "/esoui/art/tutorial/tutorial_illo_status_afk.dds",
	[PLAYER_STATUS_DO_NOT_DISTURB] = "/esoui/art/tutorial/tutorial_illo_status_dnd.dds",
}

function LibAPH.GetPlayerStatusIcon(playerStatus)
	return PLAYER_STATUS_ICON[playerStatus]
end

function LibAPH.GetFriendList()
	local friends = {}
	for i = 1, GetNumFriends() do
		local display_name, _, player_status = GetFriendInfo(i)
		if display_name and display_name ~= "" then
			friends[#friends + 1] = {
				name = display_name,
				online = player_status ~= PLAYER_STATUS_OFFLINE,
				status = player_status,
				statusIcon = PLAYER_STATUS_ICON[player_status],
			}
		end
	end
	table.sort(friends, function(a, b) return a.name < b.name end)
	return friends
end

function LibAPH.GetIgnoredList()
	local ignored = {}
	for i = 1, GetNumIgnored() do
		local display_name = GetIgnoredInfo(i)
		if display_name and display_name ~= "" then ignored[#ignored + 1] = display_name end
	end
	table.sort(ignored)
	return ignored
end

local function IsGroupedWithWatchedName(context)
	local watched = context and context.names
	if not watched or not IsGrouped() then return false end
	local group = LibAPH.GetGroupDisplayNames()
	local self_name = GetDisplayName()
	for name in pairs(watched) do
		if name ~= self_name and group[name] then return true end
	end
	return false
end

local last_loot_filters = {}
local last_loot_stolen_ms = 0

local function LootedRecently()
	if last_loot_ms == 0 then return false end
	return (GetFrameTimeMilliseconds() - last_loot_ms) <= LOOT_WINDOW_MS
end

local function LootedFilterRecently(filter_type)
	local seen = last_loot_filters[filter_type]
	if not seen then return false end
	return (GetFrameTimeMilliseconds() - seen) <= LOOT_WINDOW_MS
end

local function LootedStolenRecently()
	if last_loot_stolen_ms == 0 then return false end
	return (GetFrameTimeMilliseconds() - last_loot_stolen_ms) <= LOOT_WINDOW_MS
end

function LibAPH.GetLootWindowSeconds()
	return LOOT_WINDOW_MS / 1000
end

local LOOT_FILTERS = {
	{ id = "loot_alchemy", label = LibAPH.L("ALCHEMY_MATERIAL"), filter = ITEMFILTERTYPE_ALCHEMY },
	{ id = "loot_enchanting", label = LibAPH.L("ENCHANTING_MATERIAL"), filter = ITEMFILTERTYPE_ENCHANTING },
	{ id = "loot_provisioning", label = LibAPH.L("PROVISIONING_MATERIAL"), filter = ITEMFILTERTYPE_PROVISIONING },
	{ id = "loot_blacksmithing", label = LibAPH.L("BLACKSMITHING_MATERIAL"), filter = ITEMFILTERTYPE_BLACKSMITHING },
	{ id = "loot_clothing", label = LibAPH.L("CLOTHING_MATERIAL"), filter = ITEMFILTERTYPE_CLOTHING },
	{ id = "loot_woodworking", label = LibAPH.L("WOODWORKING_MATERIAL"), filter = ITEMFILTERTYPE_WOODWORKING },
	{ id = "loot_jewelrycrafting", label = LibAPH.L("JEWELLERY_CRAFTING_MATERIAL"), filter = ITEMFILTERTYPE_JEWELRYCRAFTING },
	{ id = "loot_style", label = LibAPH.L("STYLE_MATERIAL"), filter = ITEMFILTERTYPE_STYLE_MATERIALS },
	{ id = "loot_trait", label = LibAPH.L("TRAIT_MATERIAL"), filter = ITEMFILTERTYPE_TRAIT_ITEMS },
	{ id = "loot_furnishing", label = LibAPH.L("FURNISHING_MATERIAL"), filter = ITEMFILTERTYPE_FURNISHING },
	{ id = "loot_weapons", label = LibAPH.L("WEAPON"), filter = ITEMFILTERTYPE_WEAPONS },
	{ id = "loot_armor", label = LibAPH.L("ARMOUR"), filter = ITEMFILTERTYPE_ARMOR },
	{ id = "loot_jewelry", label = LibAPH.L("PIECE_OF_JEWELLERY"), filter = ITEMFILTERTYPE_JEWELRY },
	{ id = "loot_consumable", label = LibAPH.L("CONSUMABLE"), filter = ITEMFILTERTYPE_CONSUMABLE },
	{ id = "loot_crafting", label = LibAPH.L("CRAFTING_MATERIAL"), filter = ITEMFILTERTYPE_CRAFTING },
	{ id = "loot_quest", label = LibAPH.L("QUEST_ITEM"), filter = ITEMFILTERTYPE_QUEST },
	{ id = "loot_junk", label = LibAPH.L("JUNK_ITEM"), filter = ITEMFILTERTYPE_JUNK },
	{ id = "loot_companion", label = LibAPH.L("COMPANION_ITEM"), filter = ITEMFILTERTYPE_COMPANION },
	{ id = "loot_collectible", label = LibAPH.L("COLLECTIBLE"), filter = ITEMFILTERTYPE_COLLECTIBLE },
	{ id = "loot_miscellaneous", label = LibAPH.L("MISCELLANEOUS_ITEM"), filter = ITEMFILTERTYPE_MISCELLANEOUS },
}

local QUEST_TRIGGERS = {
	{ id = "quest_main", label = LibAPH.L("MAIN_STORY_QUEST_TRACKED"), questType = QUEST_TYPE_MAIN_STORY },
	{ id = "quest_side", label = LibAPH.L("SIDE_QUEST_TRACKED_ZONE_DELVE_WORLD"), questType = QUEST_TYPE_NONE },
	{ id = "quest_guild", label = LibAPH.L("GUILD_QUEST_TRACKED_THIEVES_GUILD_DARK"), questType = QUEST_TYPE_GUILD },
	{ id = "quest_companion", label = LibAPH.L("COMPANION_QUEST_TRACKED"), questType = QUEST_TYPE_COMPANION },
	{ id = "quest_prologue", label = LibAPH.L("PROLOGUE_QUEST_TRACKED"), questType = QUEST_TYPE_PROLOGUE },
	{ id = "quest_dungeon", label = LibAPH.L("DUNGEON_QUEST_TRACKED"), questType = QUEST_TYPE_DUNGEON },
	{ id = "quest_group", label = LibAPH.L("GROUP_QUEST_TRACKED"), questType = QUEST_TYPE_GROUP },
	{ id = "quest_raid", label = LibAPH.L("TRIAL_QUEST_TRACKED"), questType = QUEST_TYPE_RAID },
	{ id = "quest_pledge", label = LibAPH.L("UNDAUNTED_PLEDGE_TRACKED"), questType = QUEST_TYPE_UNDAUNTED_PLEDGE },
	{ id = "quest_ava", label = LibAPH.L("ALLIANCE_WAR_QUEST_TRACKED"), questType = QUEST_TYPE_AVA },
	{ id = "quest_battleground", label = LibAPH.L("BATTLEGROUND_QUEST_TRACKED"), questType = QUEST_TYPE_BATTLEGROUND },
	{ id = "quest_tribute", label = LibAPH.L("TALES_OF_TRIBUTE_QUEST_TRACKED"), questType = QUEST_TYPE_TRIBUTE },
	{ id = "quest_holiday", label = LibAPH.L("HOLIDAY_EVENT_QUEST_TRACKED"), questType = QUEST_TYPE_HOLIDAY_EVENT },
	{ id = "quest_scribing", label = LibAPH.L("SCRIBING_QUEST_TRACKED"), questType = QUEST_TYPE_SCRIBING },
	{ id = "quest_class", label = LibAPH.L("CLASS_QUEST_TRACKED"), questType = QUEST_TYPE_CLASS },
	{ id = "quest_tamriel_tale", label = LibAPH.L("TAMRIEL_TALE_TRACKED"), questType = QUEST_TYPE_TAMRIEL_TALE },
}

local triggers = {
	{ id = "dungeon", group = "where", label = LibAPH.L("DUNGEON_ARENA_OR_TRIAL"), detect = IsInGroupInstance },
	{ id = "infinite_archive", group = "where", label = LibAPH.L("INFINITE_ARCHIVE"), detect = function() return IsEndlessDungeonStarted() end },
	{ id = "pvp", group = "where", label = LibAPH.L("CYRODIIL_OR_IMPERIAL_CITY"), detect = IsInPvP },
	{ id = "battleground", group = "where", label = LibAPH.L("BATTLEGROUND"), detect = function() return IsActiveWorldBattleground() end },
	{ id = "housing", group = "where", label = LibAPH.L("INSIDE_A_HOUSE"), detect = IsInHouse },
	{ id = "overland", group = "where", label = LibAPH.L("OVERLAND"), detect = function()
		return not (IsInGroupInstance() or IsEndlessDungeonStarted() or IsInPvP() or IsActiveWorldBattleground() or IsInHouse())
	end },
	{ id = "crafting", group = "where", label = LibAPH.L("AT_A_CRAFTING_STATION"), detect = IsCrafting },
	{ id = "tribute", group = "where", label = LibAPH.L("TALES_OF_TRIBUTE_MATCH"), detect = IsInTributeMatch },
	{ id = "quest", group = "quest", label = LibAPH.L("ANY_QUEST_TRACKED"), detect = HasTrackedQuest },
	{ id = "quest_repeatable", group = "quest", label = LibAPH.L("REPEATABLE_OR_DAILY_QUEST_TRACKED"), detect = HasTrackedRepeatableQuest },
	{ id = "quest_daily", group = "quest", label = LibAPH.L("DAILY_QUEST_TRACKED_THAT_IS_NOT"), detect = HasTrackedDailyQuest },
	{ id = "quest_writ", group = "quest", label = LibAPH.L("CRAFTING_WRIT_TRACKED"), detect = HasTrackedWritQuest },
	{ id = "quest_master_writ", group = "quest", label = LibAPH.L("MASTER_WRIT_TRACKED"), detect = HasTrackedMasterWritQuest },
	{ id = "looting", group = "loot", label = LibAPH.L("PICKED_ANYTHING_UP_IN_THE_LAST"), detect = LootedRecently },
	{ id = "loot_stolen", group = "loot", label = LibAPH.L("PICKED_UP_A_STOLEN_ITEM_IN"), detect = LootedStolenRecently },
	{ id = "grouped", group = "group", label = LibAPH.L("IN_A_GROUP"), detect = IsGrouped },
	{ id = "group_friend", group = "group", label = LibAPH.L("IN_A_GROUP_WITH_ONE_OF"), detect = IsGroupedWithWatchedName, needsNames = true },
}

for _, quest_trigger in ipairs(QUEST_TRIGGERS) do
	local quest_type = quest_trigger.questType
	triggers[#triggers + 1] = {
		id = quest_trigger.id,
		group = "quest",
		label = quest_trigger.label,
		detect = function() return HasTrackedQuestOfType(quest_type) end,
	}
end

for _, loot_filter in ipairs(LOOT_FILTERS) do
	local filter_type = loot_filter.filter
	triggers[#triggers + 1] = {
		id = loot_filter.id,
		group = "loot",
		label = string.format(LibAPH.L("PICKED_UP_A_IN_THE_LAST_MINUTE"), loot_filter.label),
		detect = function() return LootedFilterRecently(filter_type) end,
	}
end

function LibAPH.GetActivityTriggers()
	return triggers
end

local GROUP_LABELS = {
	{ id = "where", label = LibAPH.L("WHERE_YOU_ARE") },
	{ id = "quest", label = LibAPH.L("QUESTS") },
	{ id = "loot", label = LibAPH.L("PICKUPS") },
	{ id = "group", label = LibAPH.L("GROUP") },
}

function LibAPH.GetActivityTriggerGroups()
	return GROUP_LABELS
end

function LibAPH.GetActivityTriggersInGroup(group_id)
	local list = {}
	for _, trigger in ipairs(triggers) do
		if trigger.group == group_id then list[#list + 1] = trigger end
	end
	return list
end

function LibAPH.GetActivityTrigger(id)
	for _, trigger in ipairs(triggers) do
		if trigger.id == id then return trigger end
	end
	return nil
end

function LibAPH.RegisterActivityTrigger(definition)
	if not definition or not definition.id or type(definition.detect) ~= "function" then return false end
	if LibAPH.GetActivityTrigger(definition.id) then return false end
	triggers[#triggers + 1] = definition
	return true
end

function LibAPH.IsActivityTriggerActive(id, context)
	local trigger = LibAPH.GetActivityTrigger(id)
	if not trigger then return false end
	return trigger.detect(context) == true
end

function LibAPH.CountActiveActivityTriggers(ids, context)
	if not ids then return nil end
	local count = 0
	for _, trigger in ipairs(triggers) do
		if ids[trigger.id] then
			count = count + 1
			if trigger.detect(context) ~= true then return nil end
		end
	end
	if count == 0 then return nil end
	return count
end

local WATCHED_EVENTS = {
	EVENT_PLAYER_ACTIVATED, EVENT_LOOT_RECEIVED, EVENT_CRAFTING_STATION_INTERACT, EVENT_END_CRAFTING_STATION_INTERACT,
	EVENT_GROUP_MEMBER_JOINED, EVENT_GROUP_MEMBER_LEFT, EVENT_QUEST_ADDED, EVENT_QUEST_REMOVED, EVENT_TRACKING_UPDATE,
}

local loot_namespace = "LibAPH_ActivityLoot"
if EVENT_LOOT_RECEIVED then
	EVENT_MANAGER:RegisterForEvent(loot_namespace, EVENT_LOOT_RECEIVED, function(_, _, itemLink)
		local now = GetFrameTimeMilliseconds()
		last_loot_ms = now
		if type(itemLink) ~= "string" or itemLink == "" then return end
		if IsItemLinkStolen(itemLink) then last_loot_stolen_ms = now end
		local filter_types = { GetItemLinkFilterTypeInfo(itemLink) }
		for _, filter_type in ipairs(filter_types) do
			last_loot_filters[filter_type] = now
		end
	end)
end

function LibAPH.RegisterActivityTriggerWatcher(namespace, callback, delayMs)
	for i, event in ipairs(WATCHED_EVENTS) do
		if event then
			EVENT_MANAGER:RegisterForEvent(namespace .. "_" .. i, event, function()
				zo_callLater(callback, delayMs or 1000)
			end)
		end
	end
end

function LibAPH.UnregisterActivityTriggerWatcher(namespace)
	for i, event in ipairs(WATCHED_EVENTS) do
		if event then
			EVENT_MANAGER:UnregisterForEvent(namespace .. "_" .. i, event)
		end
	end
end
