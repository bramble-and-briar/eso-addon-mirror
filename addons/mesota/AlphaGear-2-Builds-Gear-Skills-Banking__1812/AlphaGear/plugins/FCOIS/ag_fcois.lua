------------------------------------------------------------------------------------------------------------------------
-- Global AlphaGear variable
------------------------------------------------------------------------------------------------------------------------
AG = AG or {}
AG.plugins = AG.plugins or {}

-- TODO use Custom Events
-- CALLBACK_MANAGER:RegisterCallback("uniqueCustomEventName", functionWithCustomSignature)
-- CALLBACK_MANAGER:FireCallbacks("uniqueCustomEventName", customParam1, customParam2,  ...)

------------------------------------------------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------------------------------------------------
--Integration/Plugin coding for FCOItemSaver addon.
--> Download the addon here: https://www.esoui.com/downloads/info630-FCOItemSaver.html
--> Author of this code here: Baertram
---> API functions of FCOIS, check /AddOns/FCOItemSaver/FCOIS_API.lua
---> Used function to mark an item in the inventory of the currently logged in character:
-----> FCOIS.MarkItem(bag, slot, iconId, showIcon, updateInventories)
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- Global variables
------------------------------------------------------------------------------------------------------------------------
AG.plugins.FCOIS = AG.plugins.FCOIS or {}

-- FCOIS_CON_ICON_LOCK = 1 -- defined as global constant in FCOIS
local FCOIS_CON_ICON_NONE = 0

------------------------------------------------------------------------------------------------------------------------
-- Local variables
------------------------------------------------------------------------------------------------------------------------
--Local "speed up" variables
local AGplugFCOIS = AG.plugins.FCOIS
local isAddonReady = AGplugFCOIS.isAddonReady

------------------------------------------------------------------------------------------------------------------------
-- Functions
------------------------------------------------------------------------------------------------------------------------

--- Writes trace messages to the console
-- fmt with %d, %s,
local function trace(fmt, ...)
	if AG.isDebug then
		d(string.format(fmt, ...))
	end
end

--Check if the addon FCOItemSaver is enabled and if the functions to mark items in the inventory are given
function AGplugFCOIS.isAddonReady()
	return (FCOIS ~= nil and FCOIS.MarkItem ~= nil) or false
end

--Check if the setting to mark inventory set parts with the FCOIS marker icons is enabled
function AGplugFCOIS.isFCOISMarkerIconsEnabled()
	return AG.account.Integrations.Inventory.UseFCOIS
end

--Update the shown items in the inventory list so that the marker icons will be shown/hidden properly
function AGplugFCOIS.updateInventoryList()
	if not AGplugFCOIS.isAddonReady() then
		return
	end
	FCOIS.FilterBasics(false)
end

-- returns the FCOIS icon id of the set or 0 if it isn't assinged
function AGplugFCOIS.getFCOISIconId(setData)
	-- initialize structure 
	setData["FCOIS"] = setData["FCOIS"] or {}
	return setData["FCOIS"]["icon"] or 0
end

-- sets the new FCOIS icon id to the set
function AGplugFCOIS.setFCOISIconId(setData, newIconId)
	-- initialize structure 
	setData["FCOIS"] = setData["FCOIS"] or {}
	setData["FCOIS"]["icon"] = newIconId
end



--Get the list of marker icons defined as gear sets (5 static ones + n dyanmic ones) from FCOIS.
--Parameter: String "listType" specifies the type of list to build:
--> ListType can be one of the following one:
---> standard: A list with the marker icons, using the name from the settings, including the icon as texture (if "withIcons" = true) and disabled icons are marked red.
---> standardNonDisabled: A list with the marker icons, using the name from the settings, including the icon as texture (if "withIcons" = true) and disabled icons are not marked in any other way then enabled ones.
---> keybinds: A list with the marker icons, using the fixed name from the translations, including the icon as texture (if "withIcons" = true) and disabled icons are marked red.
---> gearSets: A list with only the gear set marker icons, using the name from the settings, including the icon as texture (if "withIcons" = true) and disabled icons are marked red.
-->Returns a table with the FCOIS marker icon ID as key and a String "name + small icon (depending on parameter "listType") as value
-- and a 2nd table with the marker icon ID as key and their marker icon ID as value as well.
--> The two tables are used for a LAM dropdown box normally.
function AGplugFCOIS.getFCOISGearSetMarkerIconsList()
	local gearMarkerIconsList, gearMarkerIconsValuesList = FCOIS.GetLAMMarkerIconsDropdown("gearSets", true)
	return gearMarkerIconsList, gearMarkerIconsValuesList
end

--- called when a gear set will be modifyed. 
-- removes all icons for all affected builds for all items in the set
-- icons form other build remain assigned
function AGplugFCOIS.onPreChangeGearSet(usageMap, affectedBuildIds)
	-- perform changes for all affected builds
	for i = 1, #affectedBuildIds do
		local buildId = affectedBuildIds[i]
		AGplugFCOIS.computeChanges(usageMap, buildId, FCOIS_CON_ICON_NONE, true, affectedBuildIds)
	end
end

--- called when a gear set has been modifyed. 
-- adds all icons to all affected builds for all items in the set
function AGplugFCOIS.onPostChangeGearSet(usageMap, affectedBuildIds)
	-- perform changes for all affected builds
	for i = 1, #affectedBuildIds do
		local buildId = affectedBuildIds[i]
		AGplugFCOIS.computeChanges(usageMap, buildId, FCOIS_CON_ICON_NONE, false, affectedBuildIds)
	end
end

-- called when a gear set is assigned to a build
--  * all items get the icon of the build
--  * same effect as if the icon of the build was switched to a new value
function AGplugFCOIS.onAssignGearSetToBuild(usageMap, currentBuildId)
	AGplugFCOIS.computeChanges(usageMap, currentBuildId, FCOIS_CON_ICON_NONE, false, {currentBuildId})
end

-- called when a gear set is unassigned from a build
--  * all items loose the icon of the build
--  * same effect as if the icon of the build was switched to FCOIS_CON_ICON_NONE
function AGplugFCOIS.onRemoveGearSetFromBuild(usageMap, currentBuildId)
	AGplugFCOIS.computeChanges(usageMap, currentBuildId, FCOIS_CON_ICON_NONE, true, {currentBuildId})
end

-- called when the icon for a build was changed
-- set data still contains the old IconId
function AGplugFCOIS.onChangeBuildIcon(usageMap, currentBuildId, newIconId)
	trace("AGplugFCOIS.onChangeBuildIcon()")
	AGplugFCOIS.computeChanges(usageMap, currentBuildId, newIconId, true, {currentBuildId})
end


function AGplugFCOIS.computeChanges(usageMap, currentBuildId, iconId, useIconIdAsNew, buildIdsToIgnore)
	-- gather items from build
	local agModel = AG.setdata
	local build = agModel[currentBuildId].Set
	local gearSetId = build.gear
	if gearSetId == 0 then
		return
	end
	local gearSet = agModel[gearSetId].Gear

	local newIconId = iconId
	local oldIconId = AGplugFCOIS.getFCOISIconId(build)

	if not useIconIdAsNew then
		newIconId = oldIconId
		oldIconId = iconId
	end

	trace("AGplugFCOIS.onChangeBcomputeChanges() - old: %d, new: %d", oldIconId, newIconId)



	local changeSet = {}

	-- ignore poison slots
	local firstSlot = 1
	local lastSlot = 14

	for slot = firstSlot, lastSlot do
		local item = gearSet[slot]

		if item.id ~= 0 then
			AGplugFCOIS.computeChangeCore(usageMap, buildIdsToIgnore, oldIconId, newIconId, item, changeSet)
		end
	end

	AGplugFCOIS.applyChangeSet(changeSet)
end

function AGplugFCOIS.computeSingleChange(usageMap, currentBuildId, oldIconId, newIconId, item)
	local changeSet = {}

	if item.id ~= 0 then
		AGplugFCOIS.computeChangeCore(usageMap, {currentBuildId}, oldIconId, newIconId, item, changeSet)
	end

	AGplugFCOIS.applyChangeSet(changeSet)
end

--- computes the changes to apply 
-- usagemap: item-Id -> {pid = profileid, bid = buildid}
function AGplugFCOIS.computeChangeCore(usageMap, buildIdsToIgnore, oldIconId, newIconId, item, changeSet)

	-- TODO: add profiles in usagemap

	local function ignore(buildInfo) 
		for _, v in pairs(buildIdsToIgnore) do 
			if v == buildInfo.bid and AG.setdata.currentProfileId == buildInfo.pid then 
				return true 
			end 
		end
		return false		
	end


	-- must be at least in this build
	local buildInfos = usageMap[item.id]
	local removeOldIcon = oldIconId ~= FCOIS_CON_ICON_NONE
	local addNewIcon = newIconId ~= FCOIS_CON_ICON_NONE

	-- if the item was in more than one build, it might be that old and new icon aren't affected
	if #buildInfos > 1 then
		local agModel

		for _, buildInfo in pairs(buildInfos) do
			if not ignore(buildInfo) then
				-- get iconid from other build.

				if buildInfo.pid == AG.setdata.currentProfileId then
					agModel = AG.setdata
				else
					agModel = AG.setdata.profiles[buildInfo.pid].setdata
				end
			
				local otherBuild = agModel[buildInfo.bid].Set

				if otherBuild["FCOIS"] ~= nil and otherBuild["FCOIS"]["icon"] ~= nil then
					local otherIconId = otherBuild["FCOIS"]["icon"]

					-- if the other icon is the same as the old icon, it must remain
					if otherIconId == oldIconId then
						removeOldIcon = false
					end

					-- removed to make sure that icon is set even if AG and FCOIS aren't synchronized
					-- if the other icon is the same as the new icon, it must not be added
					-- if otherIconId == newIconId then
					--   addNewIcon = false
					-- end
				end
			end

			-- if both options are false, nothing will be done
			if not addNewIcon and not removeOldIcon then
				-- shortcut
				break
			end
		end
	end

	if removeOldIcon or addNewIcon then
		if removeOldIcon then
			table.insert(changeSet, {item, oldIconId, false})
		end

		if addNewIcon then
			table.insert(changeSet, {item, newIconId, true})
		end
	end
end

--- Applies changes in bulk mode
-- changeset consists of rows {item, iconid, show}
-- item has id and link as fields
function AGplugFCOIS.applyChangeSet(changeSet)
	trace("AGplugFCOIS.applyChangeSet() - changes: %d", #changeSet)
	if #changeSet == 0 then
		return
	end
	
	local addonName = "AlphaGear2"

	FCOIS.UseTemporaryUniqueIds(addonName, true)

	for _, changeRow in pairs(changeSet) do
		FCOIS.MarkItemByItemInstanceId(changeRow[1].id, changeRow[2], changeRow[3], changeRow[1].link, nil, addonName)
	end

	FCOIS.UseTemporaryUniqueIds(addonName, false)
	AGplugFCOIS.updateInventoryList()
end
