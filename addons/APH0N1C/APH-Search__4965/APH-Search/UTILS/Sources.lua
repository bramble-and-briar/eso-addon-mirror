--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local SS = APHSearchCore
local ActivateVerbFor, EmoteCollectionRow, SetBonusText

SS.SCOPE_SETTINGS = "Settings"
SS.SCOPE_KEYBINDS = "Keybinds"
SS.SCOPE_ADDONS = "Add-ons"
SS.SCOPE_PANELS = "Add-on Settings"
SS.SCOPE_COMMANDS = "Commands"

local function Clean(text)
	if not text or text == "" then return "" end
	if not string.find(text, "[|<^]") then return text end
	return LibAPH.StripColors(zo_strformat("<<1>>", text))
end

SS.RegisterProvider({
	scope = SS.SCOPE_SETTINGS,
	rank = 2,
	build = function()
		if IsInGamepadPreferredMode() and SS.GamepadSettingsRows then return SS.GamepadSettingsRows() end
		local rows = {}
		local source = ZO_SharedOptions_SettingsData
		if type(source) ~= "table" then return rows end

		for panelId, systems in pairs(source) do
			if SS.IsPanelReachable(panelId) then
				local panel_name = Clean(SS.PanelName(panelId))
				for system, settings in pairs(systems) do
					for settingId, data in pairs(settings) do
						local label = SS.ResolveText(data.text)
						if label and label ~= "" then
							rows[#rows + 1] = {
								label = Clean(label),
								detail = Clean(SS.ResolveText(data.tooltipText) or ""),
								where = panel_name,
								panel = panelId,
								system = system,
								settingId = settingId,
							}
						end
					end
				end
			end
		end
		return rows
	end,
	go = function(row) return SS.GoToSetting(row) end,
})

SS.RegisterProvider({
	scope = SS.SCOPE_KEYBINDS,
	rank = 6,
	build = function()
		local rows = {}

		for layer = 1, GetNumActionLayers() do
			local layer_name, categories = GetActionLayerInfo(layer)
			for category = 1, (categories or 0) do
				local category_name, actions = GetActionLayerCategoryInfo(layer, category)
				for action = 1, (actions or 0) do
					local action_name, rebindable, hidden = GetActionInfo(layer, category, action)
					if action_name and rebindable and not hidden then
						local string_id = _G["SI_BINDING_NAME_" .. action_name]
						local label = string_id and GetString(string_id) or ""
						if label ~= "" then
							local where = "Keybind"
							local detail = Clean(category_name or "")
							if layer_name and layer_name ~= "" and detail ~= "" then
								detail = detail .. ", " .. Clean(layer_name)
							elseif layer_name and layer_name ~= "" then
								detail = Clean(layer_name)
							end
							rows[#rows + 1] = {
								label = Clean(label),
								detail = detail,
								where = where,
								action = action_name,
							}
						end
					end
				end
			end
		end
		return rows
	end,
	go = function(row) return SS.GoToKeybinds(row) end,
})

SS.RegisterProvider({
	scope = SS.SCOPE_ADDONS,
	rank = 5,
	build = function()
		local rows = {}
		local am = GetAddOnManager()
		if not am then return rows end

		for position = 1, am:GetNumAddOns() do
			local name, title, author = am:GetAddOnInfo(position)
			local shown = Clean(title)
			if shown == "" then shown = name end
			if shown and shown ~= "" then
				rows[#rows + 1] = {
					label = shown,
					detail = Clean(author or ""),
					where = "Add-Ons",
					folder = name,
					addonIndex = position,
				}
			end
		end
		return rows
	end,
	go = function(row) return SS.GoToAddons(row) end,
})

local MAX_PANEL_DEPTH = 4

local function CollectPanelControls(parent, panel, panel_name, rows, depth, trail)
	if not parent or depth > MAX_PANEL_DEPTH then return end
	if type(parent.GetNumChildren) ~= "function" then return end

	local count = parent:GetNumChildren()
	if type(count) ~= "number" then return end

	for position = 1, count do
		local child = parent:GetChild(position)
		local data = child and child.data
		local label = data and Clean(SS.ResolveText(data.name) or "")

		if label and label ~= "" then
			rows[#rows + 1] = {
				label = label,
				detail = Clean(SS.ResolveText(data.tooltip) or ""),
				where = trail ~= "" and (panel_name .. ", " .. trail) or panel_name,
				panelControl = panel,
				control = child,
			}
			if child.scroll then
				CollectPanelControls(child.scroll, panel, panel_name, rows, depth + 1,
					trail ~= "" and (trail .. ", " .. label) or label)
			end
		elseif child then
			CollectPanelControls(child.scroll or child, panel, panel_name, rows, depth + 1, trail)
		end
	end
end

SS.RegisterProvider({
	scope = SS.SCOPE_PANELS,
	rank = 4,
	build = function()
		if not IsKeyboardUISupported() then return SS.ConsolePanelRows() end
		local rows = {}
		local lam = LibAddonMenu2
		if not lam or type(lam.GetAddonPanelContainer) ~= "function" then return rows end

		local ok, container = pcall(lam.GetAddonPanelContainer, lam)
		if not ok or not container or type(container.GetNumChildren) ~= "function" then return rows end

		for position = 1, container:GetNumChildren() do
			local panel = container:GetChild(position)
			local data = panel and panel.data
			if data and data.name then
				local label = Clean(SS.ResolveText(data.name) or "")
				if label ~= "" then
					rows[#rows + 1] = {
						label = label,
						detail = Clean(data.author or ""),
						where = SS.L("SETTINGS_ADD_ONS"),
						panelControl = panel,
					}
					if panel.scroll then
						CollectPanelControls(panel.scroll, panel, label, rows, 1, "")
					end
				end
			end
		end
		return rows
	end,
	go = function(row) return SS.GoToPanelControl(row) end,
})

SS.RegisterProvider({
	scope = SS.SCOPE_COMMANDS,
	rank = 7,
	build = function()
		local rows = {}
		if type(SLASH_COMMANDS) ~= "table" then return rows end

		for command in pairs(SLASH_COMMANDS) do
			if type(command) == "string" and command ~= "" then
				rows[#rows + 1] = {
					label = command,
					detail = "",
					where = SS.L("SLASH_COMMAND"),
					command = command,
				}
			end
		end
		return rows
	end,
	go = function(row) return SS.GoToCommand(row) end,
})

SS.SCOPE_MENUS = "Menus"

local MENUS = {
	{ GetString(SI_QUEST_JOURNAL_MENU_JOURNAL), "questJournal", GetString(SI_MAIN_MENU_JOURNAL) },
	{ GetString(SI_MAIN_MENU_MAP), "worldMap", SS.L("WORLD") },
	{ GetString(SI_MAIN_MENU_INVENTORY), "inventory", GetString(SI_MAIN_MENU_CHARACTER) },
	{ GetString(SI_JOURNAL_MENU_ACHIEVEMENTS), "achievements", GetString(SI_MAIN_MENU_JOURNAL) },
	{ GetString(SI_STAT_GAMEPAD_CHAMPION_POINTS_LABEL), "championPerks", GetString(SI_MAIN_MENU_CHARACTER) },
	{ GetString(SI_MAIN_MENU_COLLECTIONS), "collectionsBook", GetString(SI_MAIN_MENU_COLLECTIONS) },
	{ GetString(SI_OUTFIT_STYLES_BOOK_TITLE), "outfitStylesBook", GetString(SI_MAIN_MENU_COLLECTIONS) },
	{ GetString(SI_JOURNAL_MENU_LORE_LIBRARY), "loreLibrary", GetString(SI_MAIN_MENU_JOURNAL) },
	{ GetString(SI_GAMEPAD_MAIN_MENU_JOURNAL_ANTIQUITIES), "antiquityJournalKeyboard", GetString(SI_MAIN_MENU_JOURNAL) },
	{ SS.L("ANTIQUITY_LORE"), "antiquityLoreKeyboard", GetString(SI_MAIN_MENU_JOURNAL) },
	{ GetString(SI_JOURNAL_MENU_CADWELLS_ALMANAC), "cadwellsAlmanac", GetString(SI_MAIN_MENU_JOURNAL) },
	{ GetString(SI_MAIN_MENU_TAMRIEL_TOMES), "TamrielTomesSceneKeyboard", GetString(SI_MAIN_MENU_JOURNAL) },
	{ SS.L("DAILY_LOGIN_REWARDS"), "dailyLoginRewards", SS.L("REWARDS") },
	{ SS.L("SCRIBING_LIBRARY"), "scribingLibraryKeyboard", GetString(SI_MAIN_MENU_CHARACTER) },
	{ GetString(SI_MAIN_MENU_MAIL), "mailInbox", GetString(SI_MAIN_MENU_MAIL) },
	{ GetString(SI_SOCIAL_MENU_SEND_MAIL), "mailSend", GetString(SI_MAIN_MENU_MAIL) },
	{ SS.L("FRIENDS_LIST"), "friendsList", GetString(SI_MAIN_MENU_SOCIAL) },
	{ SS.L("IGNORE_LIST"), "ignoreList", GetString(SI_MAIN_MENU_SOCIAL) },
	{ GetString(SI_MAIN_MENU_NOTIFICATIONS), "notifications", GetString(SI_MAIN_MENU_SOCIAL) },
	{ SS.L("GROUP_AND_ACTIVITY_FINDER"), "groupMenuKeyboard", GetString(SI_MAIN_MENU_SOCIAL) },
	{ SS.L("GUILD_HOME"), "guildHome", GetString(SI_MAIN_MENU_GUILDS) },
	{ GetString(SI_GAMEPAD_GUILD_ROSTER_HEADER), "guildRoster", GetString(SI_MAIN_MENU_GUILDS) },
	{ SS.L("GUILD_HISTORY"), "guildHistory", GetString(SI_MAIN_MENU_GUILDS) },
	{ GetString(SI_GAMEPAD_GUILD_HEADER_GUILD_SERVICES_HERALDRY), "guildHeraldry", GetString(SI_MAIN_MENU_GUILDS) },
	{ SS.L("GUILD_RANKS"), "guildRanks", GetString(SI_MAIN_MENU_GUILDS) },
	{ SS.L("GUILD_RECRUITMENT"), "guildRecruitmentKeyboard", GetString(SI_MAIN_MENU_GUILDS) },
	{ GetString(SI_PLAYER_MENU_CAMPAIGNS), "campaignBrowser", GetString(SI_MAIN_MENU_ALLIANCE_WAR) },
	{ SS.L("CAMPAIGN_OVERVIEW"), "campaignOverview", GetString(SI_MAIN_MENU_ALLIANCE_WAR) },
	{ SS.L("HELP_AND_CUSTOMER_SUPPORT"), "helpCustomerSupport", GetString(SI_MAIN_MENU_HELP) },
	{ GetString(SI_HELP_EMOTES), "helpEmotes", GetString(SI_MAIN_MENU_HELP) },
	{ GetString(SI_HELP_TUTORIALS), "helpTutorials", GetString(SI_MAIN_MENU_HELP) },
	{ GetString(SI_MAIN_MENU_MARKET), "market", GetString(SI_MAIN_MENU_MARKET) },
	{ GetString(SI_MAIN_MENU_CROWN_CRATES), "crownCrateKeyboard", GetString(SI_MAIN_MENU_MARKET) },
	{ SS.L("SEAL_OF_ENDEAVOUR_STORE"), "endeavorSealStoreSceneKeyboard", GetString(SI_MAIN_MENU_MARKET) },
	{ SS.L("GAMMA_ADJUST"), "gammaAdjust", GetString(SI_GAME_MENU_SETTINGS) },
	{ SS.L("SCREEN_ADJUST"), "screenAdjust", GetString(SI_GAME_MENU_SETTINGS) },
}

local function TimedActivitiesReady()
	return SS.SceneExists("TimedActivitiesKeyboard")
		and TIMED_ACTIVITIES_KEYBOARD ~= nil
		and type(TIMED_ACTIVITIES_KEYBOARD.SelectActivityTypeCategory) == "function"
end

local function ShowTimedActivities(activityType)
	return SS.ShowTimedActivities(activityType)
end

local function InventoryTabReady()
	return SS.SceneExists("inventory")
		and INVENTORY_MENU_BAR ~= nil
		and INVENTORY_MENU_BAR.modeBar ~= nil
		and type(INVENTORY_MENU_BAR.modeBar.SelectFragment) == "function"
end

local function GuildSelectorReady(scene)
	return SS.SceneExists(scene)
		and GUILD_SELECTOR ~= nil
		and type(GUILD_SELECTOR.SelectGuild) == "function"
end

local MENU_ACTIONS = {
	{
		label = SS.L("WEEKLY_CHALLENGES"),
		where = GetString(SI_MAIN_MENU_TAMRIEL_TOMES),
		available = TimedActivitiesReady,
		action = function() return ShowTimedActivities(TIMED_ACTIVITY_TYPE_WEEKLY) end,
	},
	{
		label = SS.L("SEASONAL_CHALLENGES"),
		where = GetString(SI_MAIN_MENU_TAMRIEL_TOMES),
		available = TimedActivitiesReady,
		action = function() return ShowTimedActivities(TIMED_ACTIVITY_TYPE_SEASONAL) end,
	},
	{
		label = GetString(SI_GAMEPAD_INVENTORY_CRAFT_BAG_HEADER),
		where = GetString(SI_MAIN_MENU_INVENTORY),
		available = InventoryTabReady,
		action = function() return SS.ShowInventoryTab(SI_INVENTORY_MODE_CRAFT_BAG) end,
	},
	{
		label = GetString(SI_INVENTORY_MODE_CURRENCY),
		where = GetString(SI_MAIN_MENU_INVENTORY),
		available = InventoryTabReady,
		action = function() return SS.ShowInventoryTab(SI_INVENTORY_MODE_CURRENCY) end,
	},
	{
		label = GetString(SI_INVENTORY_MODE_QUEST_ITEMS),
		where = GetString(SI_MAIN_MENU_INVENTORY),
		available = InventoryTabReady,
		action = function() return SS.ShowInventoryTab(SI_INVENTORY_MODE_QUEST_ITEMS) end,
	},
	{
		label = SS.L("QUICKSLOTS"),
		where = GetString(SI_MAIN_MENU_INVENTORY),
		available = InventoryTabReady,
		action = function() return SS.ShowInventoryTab(SI_INVENTORY_MODE_QUICKSLOTS) end,
	},
	{
		label = GetString(SI_GUILD_BROWSER_TITLE),
		where = GetString(SI_MAIN_MENU_GUILDS),
		available = function() return GuildSelectorReady("guildBrowserKeyboard") end,
		action = function()
			return SS.ShowGuildSelectorScene("guildBrowserKeyboard", GetString(SI_GUILD_BROWSER_TITLE))
		end,
	},
	{
		label = SS.L("CREATING_AND_JOINING_GUILDS"),
		where = GetString(SI_MAIN_MENU_GUILDS),
		available = function() return GuildSelectorReady("guildCreate") end,
		action = function()
			return SS.ShowGuildSelectorScene("guildCreate", GetString(SI_GUILD_CREATE_TITLE))
		end,
	},
	{
		label = SS.L("GOLDEN_PURSUITS"),
		where = SS.L("GROUP_AND_ACTIVITY_FINDER"),
		available = function()
			return PROMOTIONAL_EVENT_MANAGER ~= nil
				and type(PROMOTIONAL_EVENT_MANAGER.ShowPromotionalEventScene) == "function"
		end,
		action = function()
			PROMOTIONAL_EVENT_MANAGER:ShowPromotionalEventScene()
			return true
		end,
	},
}

function SS.SceneExists(name)
	return SCENE_MANAGER:GetScene(name) ~= nil
end

SS.RegisterProvider({
	scope = SS.SCOPE_MENUS,
	rank = 1,
	build = function()
		if IsInGamepadPreferredMode() then return SS.GamepadMenuRows() end
		local rows = {}
		for _, entry in ipairs(MENUS) do
			if SS.SceneExists(entry[2]) then
				rows[#rows + 1] = {
					label = entry[1],
					detail = entry[3],
					where = entry[3],
					scene = entry[2],
				}
			end
		end

		for _, entry in ipairs(MENU_ACTIONS) do
			if entry.available() then
				rows[#rows + 1] = {
					label = entry.label,
					detail = entry.where,
					where = entry.where,
					action = entry.action,
				}
			end
		end
		return rows
	end,
	go = function(row) return SS.GoToScene(row) end,
})

SS.SCOPE_ACHIEVEMENTS = "Achievements"

SS.RegisterProvider({
	scope = SS.SCOPE_ACHIEVEMENTS,
	tier = 2,
	rank = 3,
	buildItems = function()
		local items = {}
		for top = 1, GetNumAchievementCategories() do
			local category, sub_categories, achievements = GetAchievementCategoryInfo(top)
			for position = 1, (achievements or 0) do
				items[#items + 1] = { id = GetAchievementId(top, nil, position), category = category }
			end
			for sub = 1, (sub_categories or 0) do
				local sub_name, sub_achievements = GetAchievementSubCategoryInfo(top, sub)
				for position = 1, (sub_achievements or 0) do
					items[#items + 1] = { id = GetAchievementId(top, sub, position), category = category, sub = sub_name }
				end
			end
		end
		return items
	end,
	buildRow = function(item, rows)
		local id = item.id
		if not id or id == 0 then return end
		local name, description = GetAchievementInfo(id)
		if not name or name == "" then return end
		local where = item.category
		if item.sub and item.sub ~= "" then where = item.category .. ", " .. item.sub end
		rows[#rows + 1] = {
			label = Clean(name),
			detail = Clean(description or ""),
			where = Clean(where),
			achievementId = id,
		}
	end,
	go = function(row) return SS.GoToAchievement(row) end,
})

SS.SCOPE_QUESTS = "Quests"

local SHOW_QUEST_ALIASES = { "show quest", "show quest on map", "tracked quest", "focused quest", "current quest" }
SS.SCOPE_ANTIQUITIES = "Antiquities"

SS.RegisterProvider({
	scope = SS.SCOPE_QUESTS,
	rank = 2,
	build = function()
		local rows = {}

		local focused_name
		for index = 1, MAX_JOURNAL_QUESTS do
			if IsValidQuestIndex(index) then
				local name, _, step = GetJournalQuestInfo(index)
				if name and name ~= "" then
					local label = Clean(name)
					rows[#rows + 1] = {
						label = label,
						detail = Clean(step or ""),
						where = "Quest",
						questIndex = index,
					}
					if index == SS.FocusedQuestIndex() then focused_name = label end
				end
			end
		end

		if #rows > 0 then
			rows[#rows + 1] = {
				label = SS.L("SHOW_QUEST"),
				alias = SHOW_QUEST_ALIASES,
				detail = focused_name or SS.L("NOTHING_IS_FOCUSED_RIGHT_NOW"),
				where = SS.L("QUEST_WHICHEVER_ONE_YOU_ARE_TRACKING"),
				rank = 1,
				focusedQuest = true,
			}
		end
		return rows
	end,
	go = function(row) return SS.ShowQuestOnMap(row) end,
})

SS.RegisterProvider({
	scope = SS.SCOPE_ANTIQUITIES,
	tier = 2,
	rank = 3,
	buildItems = function()
		local ids = {}
		local id = GetNextAntiquityId(nil)
		while id do
			ids[#ids + 1] = id
			id = GetNextAntiquityId(id)
		end
		return ids
	end,
	buildRow = function(id, rows)
		local name = GetAntiquityName(id)
		if not name or name == "" then return end
		local zone = ""
		local zone_id = GetAntiquityZoneId(id)
		if zone_id and zone_id ~= 0 then zone = GetZoneNameById(zone_id) or "" end
		rows[#rows + 1] = {
			label = Clean(name),
			detail = Clean(zone),
			where = "Antiquity",
			antiquityId = id,
		}
	end,
	go = function(row) return SS.ShowAntiquity(row) end,
})

SS.SCOPE_MAP = "Map"
SS.SCOPE_WAYSHRINES = "Wayshrines"
SS.SCOPE_DUNGEONS = "Dungeons"
SS.SCOPE_ARENAS = "Arenas"
SS.SCOPE_TRIALS = "Trials"
SS.SCOPE_HOUSES = "Houses"

local MAP_RANK_TRAVEL = 2
local MAP_RANK_SPOT = 8

local KIND_WAYSHRINE, KIND_DUNGEON, KIND_ARENA, KIND_TRIAL, KIND_HOUSE = "wayshrine", "dungeon", "arena", "trial", "house"

local KIND_BY_FILTER = {}
if MAP_FILTER_WAYSHRINES then KIND_BY_FILTER[MAP_FILTER_WAYSHRINES] = KIND_WAYSHRINE end
if MAP_FILTER_DUNGEONS then KIND_BY_FILTER[MAP_FILTER_DUNGEONS] = KIND_DUNGEON end
if MAP_FILTER_ARENAS then KIND_BY_FILTER[MAP_FILTER_ARENAS] = KIND_ARENA end
if MAP_FILTER_TRIALS then KIND_BY_FILTER[MAP_FILTER_TRIALS] = KIND_TRIAL end
if MAP_FILTER_HOUSES then KIND_BY_FILTER[MAP_FILTER_HOUSES] = KIND_HOUSE end

local TRAVEL_KIND = {}
if POI_TYPE_WAYSHRINE then TRAVEL_KIND[POI_TYPE_WAYSHRINE] = "Wayshrine" end
if POI_TYPE_GROUP_DUNGEON then TRAVEL_KIND[POI_TYPE_GROUP_DUNGEON] = SS.L("GROUP_DUNGEON") end
if POI_TYPE_PUBLIC_DUNGEON then TRAVEL_KIND[POI_TYPE_PUBLIC_DUNGEON] = GetString(SI_ZONEDISPLAYTYPE6) end
if POI_TYPE_HOUSE then TRAVEL_KIND[POI_TYPE_HOUSE] = "House" end

local function TravelKind(poiType, zoneIndex, poiIndex)
	local override = zoneIndex and poiIndex and GetPOIMapFilterOverride(zoneIndex, poiIndex) or nil
	local kind = override and override ~= MAP_FILTER_NONE and KIND_BY_FILTER[override] or nil
	if not kind then
		if poiType == POI_TYPE_HOUSE then
			kind = KIND_HOUSE
		elseif poiType == POI_TYPE_WAYSHRINE then
			kind = KIND_WAYSHRINE
		elseif INSTANCE_TYPE_RAID and zoneIndex and poiIndex and GetPOIInstanceType(zoneIndex, poiIndex) == INSTANCE_TYPE_RAID then
			kind = KIND_TRIAL
		else
			kind = KIND_DUNGEON
		end
	end

	if kind == KIND_TRIAL then return kind, "Trial" end
	if kind == KIND_ARENA then return kind, "Arena" end
	return kind, TRAVEL_KIND[poiType] or "Travel"
end

local EMPTY_LIST = {}
local function ZoneNameByIndex(zoneIndex)
	return Clean(GetZoneNameByIndex(zoneIndex) or "")
end

local function MapsByName()
	local by_name = {}

	for index = 1, GetNumMaps() do
		local label = Clean(GetMapInfoByIndex(index) or "")
		if label ~= "" and not by_name[zo_strlower(label)] then
			by_name[zo_strlower(label)] = { label = label, mapIndex = index }
		end
	end
	return by_name
end

local function CollectTravelNodes(rows, zones, taken, maps)
	for node = 1, GetNumFastTravelNodes() do
		local _, name, _, _, _, _, poiType = GetFastTravelNodeInfo(node)
		local label = Clean(name or "")
		if label ~= "" then
			local key = zo_strlower(label)
			local zoneIndex, poiIndex = GetFastTravelNodePOIIndicies(node)
			if zoneIndex then zones[zoneIndex] = true end

			local zone_name = zoneIndex and ZoneNameByIndex(zoneIndex) or ""
			local kind, kind_label = TravelKind(poiType, zoneIndex, poiIndex)
			local own_map = maps[key]
			local blocked = SS.TravelNodeBlock(node)

			rows[#rows + 1] = {
				label = label,
				kind = kind,
				detail = blocked and (SS.L("CANNOT_TRAVEL") .. blocked) or "",
				where = zone_name ~= "" and (kind_label .. ", " .. zone_name) or kind_label,
				rank = MAP_RANK_TRAVEL,
				zoneId = zoneIndex and GetZoneId(zoneIndex) or nil,
				nodeIndex = node,
				mapIndex = own_map and own_map.mapIndex or nil,
			}
			taken[key] = true
		end
	end
end

local function CollectMaps(rows, taken, maps)
	for key, entry in pairs(maps) do
		if not taken[key] then
			rows[#rows + 1] = {
				label = entry.label,
				where = "Zone",
				rank = MAP_RANK_TRAVEL,
				mapIndex = entry.mapIndex,
			}
			taken[key] = true
		end
	end
end

local function CollectZonePOIs(rows, zoneIndex, taken)
	local zone_name = ZoneNameByIndex(zoneIndex)
	local zoneId = GetZoneId(zoneIndex)
	for poi = 1, GetNumPOIs(zoneIndex) do
		local label = Clean(GetPOIInfo(zoneIndex, poi) or "")
		if label ~= "" and not taken[zo_strlower(label)] then
			local poi_type = GetPOIType(zoneIndex, poi)
			local is_dungeon = poi_type ~= nil and (poi_type == POI_TYPE_PUBLIC_DUNGEON or poi_type == POI_TYPE_GROUP_DUNGEON)
			local prefix = is_dungeon and TRAVEL_KIND[poi_type] or nil
			rows[#rows + 1] = {
				label = label,
				kind = is_dungeon and KIND_DUNGEON or nil,
				where = prefix and (zone_name ~= "" and (prefix .. ", " .. zone_name) or prefix) or (zone_name ~= "" and zone_name or "Map"),
				rank = MAP_RANK_SPOT,
				zoneId = zoneId,
				zoneIndex = zoneIndex,
				poiIndex = poi,
			}
			taken[zo_strlower(label)] = true
		end
	end
end

local function CollectPOIs(rows, zones, taken)
	for zoneIndex in pairs(zones) do CollectZonePOIs(rows, zoneIndex, taken) end
end

SS.RegisterProvider({
	scope = SS.SCOPE_MAP,
	rank = MAP_RANK_SPOT,
	buildItems = function()
		local items = { "nodes" }
		for zoneIndex = 1, GetNumZones() do items[#items + 1] = zoneIndex end
		return items
	end,
	buildRow = function(item, rows, state)
		if item == "nodes" then
			state.zones, state.taken, state.maps = {}, {}, MapsByName()
			CollectTravelNodes(rows, state.zones, state.taken, state.maps)
			CollectMaps(rows, state.taken, state.maps)
		elseif state.zones[item] then
			CollectZonePOIs(rows, item, state.taken)
		end
	end,
	go = function(row) return SS.GoToMapSpot(row) end,
})

local function RegisterMapKind(scope, kind)
	SS.RegisterProvider({
		scope = scope,
		subsetOf = SS.SCOPE_MAP,
		rank = MAP_RANK_TRAVEL,
		build = function()
			local all, zones, taken = {}, {}, {}
			CollectTravelNodes(all, zones, taken, MapsByName())
			if kind == KIND_DUNGEON then CollectPOIs(all, zones, taken) end
			local rows = {}
			for _, row in ipairs(all) do
				if row.kind == kind then rows[#rows + 1] = row end
			end
			return rows
		end,
		go = function(row) return SS.GoToMapSpot(row) end,
	})
end

RegisterMapKind(SS.SCOPE_WAYSHRINES, KIND_WAYSHRINE)
RegisterMapKind(SS.SCOPE_DUNGEONS, KIND_DUNGEON)
RegisterMapKind(SS.SCOPE_ARENAS, KIND_ARENA)
RegisterMapKind(SS.SCOPE_TRIALS, KIND_TRIAL)
RegisterMapKind(SS.SCOPE_HOUSES, KIND_HOUSE)

SS.SCOPE_SKILLS = "Skills"
SS.SCOPE_CHAMPION = "Champion"

local function IsSkillLineListed(lineData)
	return lineData:IsAvailableOrAdvised()
end

SS.SKILL_LINE_FILTERS = { IsSkillLineListed }

function SS.IsSkillLineListed(lineData)
	return lineData ~= nil
		and type(lineData.IsAvailableOrAdvised) == "function"
		and lineData:IsAvailableOrAdvised()
end

SS.RegisterProvider({
	scope = SS.SCOPE_SKILLS,
	rank = 4,
	buildItems = function()
		local lines = {}
		local manager = SKILLS_DATA_MANAGER
		if not manager or type(manager.SkillTypeIterator) ~= "function" then return lines end

		for _, typeData in manager:SkillTypeIterator() do
			local type_name = type(typeData.GetName) == "function" and Clean(typeData:GetName()) or ""
			for _, lineData in typeData:SkillLineIterator(SS.SKILL_LINE_FILTERS) do
				lines[#lines + 1] = { type_name = type_name, lineData = lineData }
			end
		end
		return lines
	end,
	buildRow = function(item, rows)
		local type_name, lineData = item.type_name, item.lineData
		local line_name = type(lineData.GetName) == "function" and Clean(lineData:GetName()) or ""
		if line_name ~= "" then
			rows[#rows + 1] = {
				label = line_name,
				where = type_name ~= "" and (SS.L("SKILL_LINE") .. type_name) or SS.L("SKILL_LINE_2"),
				rank = 3,
				skillLineData = lineData,
				go = function(entry) return SS.BrowseToSkillLine(entry) end,
			}
		end
		for _, skillData in lineData:SkillIterator() do
			local progression = type(skillData.GetCurrentProgressionData) == "function"
				and skillData:GetCurrentProgressionData() or nil
			local label = progression and type(progression.GetName) == "function"
				and Clean(progression:GetName()) or ""
			if label ~= "" then
				local active = type(skillData.IsActive) == "function" and skillData:IsActive()
				local trail = line_name
				if type_name ~= "" and line_name ~= "" then trail = type_name .. ", " .. line_name end
				rows[#rows + 1] = {
					label = label,
					detail = active and SS.L("ACTIVE_ABILITY") or "Passive",
					where = trail ~= "" and (SS.L("SKILL") .. trail) or "Skill",
					skillData = skillData,
				}
			end
		end
	end,
	go = function(row) return SS.BrowseToSkill(row) end,
})

local function ClusterMembers(clusterData)
	if type(clusterData.GetClusterChildren) ~= "function" then return "" end

	local names = {}
	for _, child in ipairs(clusterData:GetClusterChildren()) do
		if type(child.GetFormattedName) == "function" then
			names[#names + 1] = Clean(child:GetFormattedName())
		end
	end
	return table.concat(names, ", ")
end

SS.RegisterProvider({
	scope = SS.SCOPE_CHAMPION,
	rank = 4,
	build = function()
		local rows = {}
		local manager = CHAMPION_DATA_MANAGER
		if not manager or type(manager.ChampionDisciplineDataIterator) ~= "function" then return rows end

		for _, disciplineData in manager:ChampionDisciplineDataIterator() do
			local discipline = type(disciplineData.GetFormattedName) == "function"
				and Clean(disciplineData:GetFormattedName()) or ""
			for _, skillData in disciplineData:ChampionSkillDataIterator() do
				local label = type(skillData.GetFormattedName) == "function"
					and Clean(skillData:GetFormattedName()) or ""
				if label ~= "" then
					local bonus = type(skillData.GetCurrentBonusText) == "function"
						and Clean(skillData:GetCurrentBonusText() or "") or ""
					rows[#rows + 1] = {
						label = label,
						detail = bonus,
						where = discipline ~= "" and (SS.L("CHAMPION") .. discipline) or "Champion",
						championSkillData = skillData,
						disciplineData = disciplineData,
					}
				end
			end

			if type(disciplineData.ChampionClusterDataIterator) == "function" then
				for _, clusterData in disciplineData:ChampionClusterDataIterator() do
					local label = type(clusterData.GetFormattedName) == "function"
						and Clean(clusterData:GetFormattedName()) or ""
					local root = type(clusterData.GetRootChampionSkillData) == "function"
						and clusterData:GetRootChampionSkillData() or nil
					if label ~= "" and root then
						rows[#rows + 1] = {
							label = label,
							detail = ClusterMembers(clusterData),
							where = discipline ~= "" and (SS.L("CHAMPION") .. discipline) or "Champion",
							championSkillData = root,
							championPortal = true,
							disciplineData = disciplineData,
						}
					end
				end
			end
		end
		return rows
	end,
	go = function(row) return SS.ShowChampionSkill(row) end,
})

SS.SCOPE_TITLES = "Titles"
SS.SCOPE_EMOTES = "Emotes"

local function PlayerName()
	return GetRawUnitName("player") or ""
end

SS.RegisterProvider({
	scope = SS.SCOPE_TITLES,
	rank = 5,
	build = function()
		local rows = {}

		local who = PlayerName()
		local current = GetCurrentTitleIndex()

		for index = 1, GetNumTitles() do
			local raw = GetTitle(index)
			if raw and raw ~= "" then
				local label = LibAPH.StripColors(zo_strformat(raw, who))
				if label ~= "" then
					rows[#rows + 1] = {
						label = label,
						detail = index == current and SS.L("WORN_NOW") or "",
						where = "Title",
						titleIndex = index,
					}
				end
			end
		end

		if #rows > 0 then
			rows[#rows + 1] = {
				label = Clean(GetString(SI_STATS_NO_TITLE)),
				detail = current == nil and SS.L("WORN_NOW") or "",
				where = "Title",
				rank = 6,
			}
		end
		return rows
	end,
	go = function(row) return SS.SetTitle(row) end,
})

local function EmoteRow(index, rows)
	local locked_by = GetEmoteCollectibleId(index)
	if locked_by and locked_by ~= 0 and not IsCollectibleUnlocked(locked_by) then return end

	local slash, category, _, display = GetEmoteInfo(index)
	if not slash or slash == "" then return end
	local label = Clean(display or "")
	if label == "" then label = Clean(slash) end
	local group = category and Clean(GetString("SI_EMOTECATEGORY", category)) or ""
	rows[#rows + 1] = {
		label = label,
		detail = Clean(slash),
		where = group ~= "" and (SS.L("EMOTE") .. group) or "Emote",
		emoteIndex = index,
	}
end

SS.RegisterProvider({
	scope = SS.SCOPE_EMOTES,
	rank = 6,
	buildItems = function()
		local items = {}
		for index = 1, GetNumEmotes() do items[#items + 1] = index end
		for _, data in ipairs(SS.AllCollectibles()) do items[#items + 1] = data end
		return items
	end,
	buildRow = function(item, rows, state)
		if type(item) == "number" then return EmoteRow(item, rows) end
		if SS.CollectionBucket(item) == "emotes" then EmoteCollectionRow(item, rows, state) end
	end,
	go = function(row) return SS.PlayEmote(row) end,
})

SS.SCOPE_HELP = "Help"

local STUCK_ALIASES = { "stuck", "unstuck" }

local function CollectSupportCategories(rows)
	if IsInGamepadPreferredMode() and SS.GamepadHelpRows then
		SS.GamepadHelpRows(rows)
		return
	end
	local screen = HELP_CUSTOMER_SUPPORT_KEYBOARD
	local tree = screen and screen.tree
	local root = tree and tree.rootNode
	if not root or type(root.GetChildren) ~= "function" then return end

	for _, node in ipairs(root:GetChildren() or EMPTY_LIST) do
		local data = type(node.GetData) == "function" and node:GetData() or nil
		local label = data and Clean(SS.ResolveText(data.name) or "") or ""
		if label ~= "" and data.categoryFragment then
			local row = {
				label = label,
				tier = 1,
				where = GetString(SI_HELP_CUSTOMER_SUPPORT),
				supportFragment = data.categoryFragment,
				go = function(entry) return SS.GoToSupportScreen(entry) end,
			}
			if data.categoryFragment == HELP_CUSTOMER_SERVICE_CHARACTER_STUCK_KEYBOARD_FRAGMENT then
				row.alias = STUCK_ALIASES
			end
			rows[#rows + 1] = row
		end
	end
end

SS.RegisterProvider({
	scope = SS.SCOPE_HELP,
	tier = 2,
	rank = 3,
	build = function()
		local rows = {}
		CollectSupportCategories(rows)

		for category = 1, GetNumHelpCategories() do
			local category_name = GetHelpCategoryInfo(category)
			for entry = 1, (GetNumHelpEntriesWithinCategory(category) or 0) do
				local name, description = GetHelpInfo(category, entry)
				if name and name ~= "" then
					rows[#rows + 1] = {
						label = Clean(name),
						detail = Clean(description or ""),
						where = SS.L("HELP") .. Clean(category_name or ""),
						helpCategory = category,
						helpIndex = entry,
					}
				end
			end
		end
		return rows
	end,
	go = function(row) return SS.GoToHelp(row) end,
})

SS.SCOPE_ITEMS = "Items"

local ITEM_BAGS = {
	{ bag = BAG_BACKPACK, where = SS.L("ITEM_BACKPACK") },
	{ bag = BAG_VIRTUAL, where = SS.L("ITEM_CRAFT_BAG") },
}

local function BagSlots(bagId)
	local slot
	return function()
		slot = ZO_GetNextBagSlotIndex(bagId, slot)
		return slot
	end
end

SS.RegisterProvider({
	scope = SS.SCOPE_ITEMS,
	rank = 4,
	buildItems = function()
		local slots = {}
		for _, source in ipairs(ITEM_BAGS) do
			if source.bag then
				for slot in BagSlots(source.bag) do slots[#slots + 1] = { source = source, slot = slot } end
			end
		end
		return slots
	end,
	buildRow = function(item, rows, state)
		local bag = item.source.bag
		local label = Clean(GetItemName(bag, item.slot) or "")
		if label == "" then return end
		local stack = GetSlotStackSize(bag, item.slot) or 0
		state[bag] = state[bag] or {}
		local seen = state[bag][label]
		if seen then
			seen.stack = seen.stack + stack
			seen.row.detail = string.format(SS.L("IN_THE_STACK"), seen.stack)
			return
		end
		local row = {
			label = label,
			where = item.source.where,
			bagId = bag,
			slotIndex = item.slot,
		}
		if stack > 1 then row.detail = string.format(SS.L("IN_THE_STACK"), stack) end
		state[bag][label] = { row = row, stack = stack }
		rows[#rows + 1] = row
	end,
	go = function(row) return SS.ShowInventoryItem(row) end,
})

SS.SCOPE_CROWN = "Crown Store"

SS.RegisterProvider({
	scope = SS.SCOPE_CROWN,
	tier = 3,
	rank = 9,
	describe = function(text)
		return string.format(SS.L("SEARCH_THE_CROWN_STORE_FOR"), text)
	end,
	build = function()
		return {
			{
				label = string.format("%s %s", Clean(GetString(SI_MARKET_SEARCH_EDIT_DEFAULT)),
					Clean(GetString(SI_MAIN_MENU_MARKET))),
				where = "Crown Store",
				always = true,
			},
		}
	end,
	go = function(row) return SS.SearchCrownStore(row) end,
})

SS.SCOPE_COLLECTIBLES = "Collectibles"
SS.SCOPE_ALLIES = "Allies"
SS.SCOPE_TOOLS = "Tools"
SS.SCOPE_OUTFIT_STYLES = "Outfit Styles"
SS.SCOPE_SET_ITEMS = "Set Items"

local PLAYER_ACTOR = GAMEPLAY_ACTOR_CATEGORY_PLAYER
local ACTIVATE_VERBS = {
	[SI_COLLECTIBLE_ACTION_SET_ACTIVE] = SI_COLLECTIBLE_ACTION_SET_ACTIVE,
	[SI_COLLECTIBLE_ACTION_DISMISS] = SI_COLLECTIBLE_ACTION_SET_ACTIVE,
	[SI_COLLECTIBLE_ACTION_PUT_AWAY] = SI_COLLECTIBLE_ACTION_SET_ACTIVE,
	[SI_COLLECTIBLE_ACTION_USE] = SI_COLLECTIBLE_ACTION_USE,
}

local function AllCollectibles()
	return ZO_COLLECTIBLE_DATA_MANAGER:GetAllCollectibleDataObjects()
end

local function IsOutfitStyle(data)
	return type(data.IsOutfitStyle) == "function" and data:IsOutfitStyle()
end

local BUCKET_ALLIES, BUCKET_TOOLS, BUCKET_EMOTES = "allies", "tools", "emotes"
local BUCKET_BY_TOP_CATEGORY = { [91] = BUCKET_ALLIES, [66] = BUCKET_TOOLS, [28] = BUCKET_EMOTES }
local BUCKET_BY_TYPE = {}
if COLLECTIBLE_CATEGORY_TYPE_ASSISTANT then BUCKET_BY_TYPE[COLLECTIBLE_CATEGORY_TYPE_ASSISTANT] = BUCKET_ALLIES end
if COLLECTIBLE_CATEGORY_TYPE_COMPANION then BUCKET_BY_TYPE[COLLECTIBLE_CATEGORY_TYPE_COMPANION] = BUCKET_ALLIES end
if COLLECTIBLE_CATEGORY_TYPE_EMOTE then BUCKET_BY_TYPE[COLLECTIBLE_CATEGORY_TYPE_EMOTE] = BUCKET_EMOTES end

local function TopCategory(data)
	local category = type(data.GetCategoryData) == "function" and data:GetCategoryData() or nil
	local guard = 0
	while category and type(category.GetParentData) == "function" and category:GetParentData() and guard < 8 do
		category = category:GetParentData()
		guard = guard + 1
	end
	return category
end

function SS.CollectionBucket(data)
	local top = TopCategory(data)
	local bucket = top and type(top.GetId) == "function" and BUCKET_BY_TOP_CATEGORY[top:GetId()] or nil
	if bucket then return bucket end
	if type(data.GetCategoryType) == "function" then return BUCKET_BY_TYPE[data:GetCategoryType()] end
	return nil
end

local function CategoryPath(data, state, prefix)
	state.paths = state.paths or {}
	local category = type(data.GetCategoryData) == "function" and data:GetCategoryData() or nil
	local key = category and type(category.GetId) == "function" and category:GetId() or nil
	local path = key ~= nil and state.paths[key] or nil
	if path then return path end

	local names = {}
	while category and #names < 8 do
		local name = type(category.GetFormattedName) == "function" and Clean(category:GetFormattedName() or "") or ""
		if name ~= "" then table.insert(names, 1, name) end
		category = type(category.GetParentData) == "function" and category:GetParentData() or nil
	end
	if prefix then table.insert(names, 1, prefix) end
	path = #names > 0 and table.concat(names, ", ") or (prefix or "Collections")
	if key ~= nil then state.paths[key] = path end
	return path
end

local function CollectibleWhere(data, state, prefix)
	state.wheres = state.wheres or {}
	local key = type(data.GetCategoryId) == "function" and data:GetCategoryId() or nil
	local where = key ~= nil and state.wheres[key] or nil
	if not where then
		local category = type(data.GetCategoryFormattedName) == "function"
			and Clean(data:GetCategoryFormattedName() or "") or ""
		where = category ~= "" and (prefix .. ", " .. category) or prefix
		if key ~= nil then state.wheres[key] = where end
	end
	return where
end

function ActivateVerbFor(data)
	if type(data.IsUnlocked) ~= "function" or not data:IsUnlocked() then return nil end
	if type(data.IsCollectibleCategoryUsable) == "function" and not data:IsCollectibleCategoryUsable(PLAYER_ACTOR) then return nil end
	if type(data.GetPrimaryInteractionStringId) ~= "function" then return nil end
	return ACTIVATE_VERBS[data:GetPrimaryInteractionStringId(PLAYER_ACTOR)]
end

local function CollectibleRows(data, rows, where_of, with_action)
	local shown = type(data.IsShownInCollection) ~= "function" or data:IsShownInCollection()
	local label = type(data.GetFormattedName) == "function" and Clean(data:GetFormattedName()) or ""
	if not shown or label == "" then return end
	local where = where_of()

	local id = type(data.GetId) == "function" and data:GetId() or nil
	local locked = type(data.IsUnlocked) == "function" and not data:IsUnlocked()
	rows[#rows + 1] = {
		label = label,
		detail = locked and SS.L("NOT_COLLECTED_YET") or "",
		where = where,
		collectibleId = id,
		go = function(row) return SS.BrowseToCollectible(row) end,
	}

	local verb = with_action and ActivateVerbFor(data)
	if verb and id then
		rows[#rows + 1] = {
			label = label,
			where = GetString(verb),
			detail = "",
			collectibleId = id,
			tier = 1,
			rank = 2,
			go = function(row) return SS.UseCollectibleRow(row) end,
		}
	end
end

SS.RegisterProvider({
	scope = SS.SCOPE_COLLECTIBLES,
	rank = 4,
	buildItems = AllCollectibles,
	buildRow = function(data, rows, state)
		if IsOutfitStyle(data) or SS.CollectionBucket(data) then return end
		CollectibleRows(data, rows, function() return CollectibleWhere(data, state, "Collectible") end, true)
	end,
	go = function(row) return SS.BrowseToCollectible(row) end,
})

local function RegisterCollectionBucket(scope, bucket, prefix, with_action)
	SS.RegisterProvider({
		scope = scope,
		rank = 4,
		buildItems = AllCollectibles,
		buildRow = function(data, rows, state)
			if SS.CollectionBucket(data) ~= bucket then return end
			CollectibleRows(data, rows, function() return CategoryPath(data, state, prefix) end, with_action)
		end,
		go = function(row) return SS.BrowseToCollectible(row) end,
	})
end

SS.AllCollectibles = AllCollectibles

function EmoteCollectionRow(data, rows, state)
	CollectibleRows(data, rows, function() return CategoryPath(data, state, "Collections") end, false)
end

RegisterCollectionBucket(SS.SCOPE_ALLIES, BUCKET_ALLIES, nil, true)
RegisterCollectionBucket(SS.SCOPE_TOOLS, BUCKET_TOOLS, nil, true)

SS.RegisterProvider({
	scope = SS.SCOPE_OUTFIT_STYLES,
	rank = 4,
	buildItems = AllCollectibles,
	buildRow = function(data, rows, state)
		if not IsOutfitStyle(data) then return end
		local label = type(data.GetFormattedName) == "function" and Clean(data:GetFormattedName()) or ""
		if label == "" then return end
		local locked = type(data.IsUnlocked) == "function" and not data:IsUnlocked()
		rows[#rows + 1] = {
			label = label,
			detail = locked and SS.L("NOT_COLLECTED_YET") or "",
			where = CollectibleWhere(data, state, SS.L("OUTFIT_STYLE")),
			collectibleId = type(data.GetId) == "function" and data:GetId() or nil,
		}
	end,
	go = function(row) return SS.GoToOutfitStyle(row) end,
})

local function SetCategoryPath(setData)
	local category = type(setData.GetCategoryData) == "function" and setData:GetCategoryData() or nil
	if not category then return GetString(SI_ITEM_SETS_BOOK_TITLE) end
	local name = Clean(category:GetFormattedName())
	local parent = type(category.GetParentCategoryData) == "function" and category:GetParentCategoryData() or nil
	if parent then name = Clean(parent:GetFormattedName()) .. ", " .. name end
	return SS.L("SET_ITEMS") .. name
end

function SetBonusText(setData)
	for _, piece in setData:PieceIterator() do
		local link = type(piece.GetItemLink) == "function" and piece:GetItemLink() or nil
		if link and link ~= "" then
			local _, _, numBonuses = GetItemLinkSetInfo(link, false)
			local bonuses = {}
			for index = 1, numBonuses or 0 do
				local _, description = GetItemLinkSetBonusInfo(link, false, index)
				if description and description ~= "" then bonuses[#bonuses + 1] = Clean(description) end
			end
			return table.concat(bonuses, " ")
		end
	end
	return ""
end

SS.RegisterProvider({
	scope = SS.SCOPE_SET_ITEMS,
	rank = 4,
	matchEffects = true,
	buildItems = function()
		local manager = ITEM_SET_COLLECTIONS_DATA_MANAGER
		if not manager or type(manager.ItemSetCollectionIterator) ~= "function" then return {} end
		local sets = {}
		for _, setData in manager:ItemSetCollectionIterator() do sets[#sets + 1] = setData end
		return sets
	end,
	buildRow = function(setData, rows)
		local label = Clean(setData:GetFormattedName())
		if label == "" then return end
		rows[#rows + 1] = {
			label = label,
			where = SetCategoryPath(setData),
			detail = SetBonusText(setData),
			itemSetId = setData:GetId(),
		}
	end,
	go = function(row) return SS.GoToItemSet(row) end,
})

SS.SCOPE_LEADERBOARDS = "Leaderboards"

local function CollectLeaderboardNodes(rows, node, trail)
	if type(node.GetChildren) ~= "function" then return end

	for _, child in ipairs(node:GetChildren() or EMPTY_LIST) do
		local data = type(child.GetData) == "function" and child:GetData() or nil
		local label = data and Clean(data.name or "") or ""
		if label ~= "" then
			rows[#rows + 1] = {
				label = label,
				where = trail ~= "" and (SS.L("LEADERBOARD") .. trail) or "Leaderboard",
				leaderboardName = label,
			}
			CollectLeaderboardNodes(rows, child, label)
		else
			CollectLeaderboardNodes(rows, child, trail)
		end
	end
end

SS.RegisterProvider({
	scope = SS.SCOPE_LEADERBOARDS,
	rank = 4,
	build = function()
		if IsInGamepadPreferredMode() and SS.GamepadLeaderboardRows then return SS.GamepadLeaderboardRows() end
		local rows = {}
		local tree = LEADERBOARDS and LEADERBOARDS.navigationTree
		if not tree or not tree.rootNode then return rows end

		CollectLeaderboardNodes(rows, tree.rootNode, "")
		return rows
	end,
	go = function(row) return SS.GoToLeaderboard(row) end,
})

SS.SCOPE_FRIENDS = "Friends"

local function FriendRows(rows, index)
	local display, note, status = GetFriendInfo(index)
	local name = Clean(display or "")
	if name == "" then return end

	local has_char, char_name, zone_name = GetFriendCharacterInfo(index)
	local character, zone = Clean(char_name or ""), Clean(zone_name or "")

	local online = status ~= nil and status ~= PLAYER_STATUS_OFFLINE
	local shown = ZO_FormatUserFacingDisplayName(name)
	local alias = {}
	if character ~= "" then alias[#alias + 1] = zo_strlower(character) end
	if shown ~= name then alias[#alias + 1] = zo_strlower(name) end

	local where = online and SS.L("FRIEND_ONLINE") or SS.L("FRIEND_OFFLINE")
	local detail = ""
	if online and has_char and character ~= "" then
		detail = zone ~= "" and (character .. " in " .. zone) or character
	elseif not online then
		detail = Clean(note or "")
	end

	rows[#rows + 1] = {
		label = shown,
		detail = detail,
		where = where,
		alias = alias,
		friendName = name,
	}

	if not online then return end

	if IsChatSystemAvailableForCurrentPlatform() then
		rows[#rows + 1] = {
			label = string.format(SS.L("WHISPER"), shown),
			where = where,
			alias = alias,
			friendName = name,
			friendAction = "whisper",
		}
	end
	if not IsPlayerInGroup(name) then
		rows[#rows + 1] = {
			label = string.format(SS.L("INVITE_TO_GROUP"), shown),
			where = where,
			alias = alias,
			friendName = name,
			friendAction = "invite",
		}
	end
	rows[#rows + 1] = {
		label = string.format(SS.L("TRAVEL_TO"), shown),
		where = where,
		alias = alias,
		friendName = name,
		friendAction = "jump",
	}
end

SS.RegisterProvider({
	scope = SS.SCOPE_FRIENDS,
	rank = 4,
	build = function()
		local rows = {}

		for index = 1, (GetNumFriends() or 0) do
			FriendRows(rows, index)
		end
		return rows
	end,
	go = function(row) return SS.GoToFriend(row) end,
})

SS.SCOPE_GROUPS = {
	{
		title = GetString(SI_MAIN_MENU_MAP),
		scopes = { SS.SCOPE_MAP, SS.SCOPE_WAYSHRINES, SS.SCOPE_DUNGEONS, SS.SCOPE_ARENAS, SS.SCOPE_TRIALS, SS.SCOPE_HOUSES, SS.SCOPE_QUESTS },
	},
	{
		title = GetString(SI_MAIN_MENU_COLLECTIONS),
		scopes = { SS.SCOPE_COLLECTIBLES, SS.SCOPE_ALLIES, SS.SCOPE_EMOTES, SS.SCOPE_TOOLS, SS.SCOPE_OUTFIT_STYLES, SS.SCOPE_SET_ITEMS },
	},
}
