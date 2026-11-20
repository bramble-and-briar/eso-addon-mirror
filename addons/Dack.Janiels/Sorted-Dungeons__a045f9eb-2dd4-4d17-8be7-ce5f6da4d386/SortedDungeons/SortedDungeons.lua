local addon = {}
addon.name = "SortedDungeons"
addon.version = 1
addon.versionString = "1.0.0"

local eventManager = GetEventManager()

local DUNGEON_ACTIVITY_TYPES = {
	LFG_ACTIVITY_DUNGEON,
	LFG_ACTIVITY_MASTER_DUNGEON,
}

local DUNGEON_SORT_KEYS = {
	GetDungeonFinderSortName = {
		caseInsensitive = true,
		tiebreaker = "GetId",
	},
	GetId = {},
}

local function OnAddOnLoaded(eventId, addonName)
	if addonName ~= addon.name then
		return
	end
	eventManager:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	function ZO_ActivityFinderLocation_Base:GetDungeonFinderSortName()
		local formattedName = zo_strformat(SI_LFG_ACTIVITY_NAME, self:GetRawName())
		if zo_strsub(zo_strlower(formattedName), 1, 4) == "the " then
			return zo_strsub(formattedName, 5)
		end
		return formattedName
	end

	local function CompareDungeonFinderLocations(leftLocation, rightLocation)
		return ZO_TableOrderingFunction(
			leftLocation,
			rightLocation,
			"GetDungeonFinderSortName",
			DUNGEON_SORT_KEYS,
			ZO_SORT_ORDER_UP
		)
	end

	local function SortDungeonFinderLocations()
		local sortedLocationsData = ZO_ACTIVITY_FINDER_ROOT_MANAGER.sortedLocationsData
		for _, activityType in ipairs(DUNGEON_ACTIVITY_TYPES) do
			local locations = sortedLocationsData[activityType]
			if locations then
				table.sort(locations, CompareDungeonFinderLocations)
			end
		end
	end

	SortDungeonFinderLocations()
end

eventManager:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
