--[[------------------------------------------------------------------------------------------------
Title:          Mounts
Author:         Static_Recharge
Description:    Creates and handles the mount specific features for the add-on.
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local LCM = LibCustomMenu
local EM = EVENT_MANAGER
local CDM = ZO_COLLECTIBLE_DATA_MANAGER
local SSF = StaticsSocialFeatures


--[[------------------------------------------------------------------------------------------------
Static Values
------------------------------------------------------------------------------------------------]]--
local multiRiderSubCatID = 75


--[[------------------------------------------------------------------------------------------------
Mounts Class Initialization
Mounts    													              - Parent object containing all functions, tables, variables, constants and other data managers.
├─ :IsInitialized()                               - Returns true if the object has been successfully initialized.
├─ :PlayerIdle()															    - Checks if the player is idle and updates the timer accordingly.
├─ :MountPlayer()                									- Mounts the targetted player.
├─ :UpdateMountData()               							- Updates the mount lists.
├─ :OnGroupMemberJoined(eventCode, memberCharacterName, memberDisplayName, isLocalPlayer) 
│                                                 - Updates the mount to the multi mount.
├─ :OnGroupMemberLeft(eventCode, memberCharacterName, reason, isLocalPlayer, isLeader, memberDisplayName, actionRequiredVote)
│                                     						- Updates the mount to the solo mount.
├─ :OnPlayerActivated(eventCode, initial)					- Updates the mount if group status changed while player was offline.
├─ :MountContextMenu()														- Adds an entry to the Mount list context menu.
└─ :GetParent()                                   - Returns the parent object of this object for reference to parent variables.
------------------------------------------------------------------------------------------------]]--
local Mounts = {}


--[[------------------------------------------------------------------------------------------------
Mounts.Initialize()
Inputs:				None
Outputs:			None
Description:	Initializes all of the variables and tables.
------------------------------------------------------------------------------------------------]]--
function Mounts.Initialize()
  Mounts.eventSpace = "SSFMounts"
  local SV = SSF.SV
  
  -- Session variables
	Mounts.SoloMount = {
		Keys = {},
		Values = {},
	}
	Mounts.MultiMount = {
		Keys = {},
		Values = {},
	}
	Mounts.currentMount = nil
	Mounts.UpdateMountData()

  -- Context Menu
  Mounts.MountContextMenu()

  -- Event Registrations
	EM:RegisterForEvent(Mounts.eventSpace, EVENT_GROUP_MEMBER_JOINED, Mounts.OnGroupMemberJoined)
	EM:RegisterForEvent(Mounts.eventSpace, EVENT_GROUP_MEMBER_LEFT, Mounts.OnGroupMemberLeft)
	EM:RegisterForEvent(Mounts.eventSpace, EVENT_PLAYER_ACTIVATED, Mounts.OnPlayerActivated)

  -- Keybindings associations
	ZO_CreateStringId("SI_BINDING_NAME_SSF_MOUNT_PLAYER", "Mount Group Member")

	Mounts.initialized = true
end


--[[------------------------------------------------------------------------------------------------
Mounts.IsInitialized()
Inputs:				None
Outputs:			initialized                         - bool for object initialized state
Description:	Returns true if the object has been successfully initialized.
------------------------------------------------------------------------------------------------]]--
function Mounts.IsInitialized()
  return Mounts.initialized
end


--[[------------------------------------------------------------------------------------------------
Mounts.MountPlayer()
Inputs:				None
Outputs:			None
Description:	Mounts the targetted player
------------------------------------------------------------------------------------------------]]--
function Mounts.MountPlayer()
	-- if not grouped then don't need to process anything
	if not IsUnitGrouped("player") then return end

	local function DistanceToUnit(unitID)
		local _, selfX, selfY, selfH = GetUnitWorldPosition("player")
		local _, targetX, targetY, targetH = GetUnitWorldPosition(unitID)
		local nDistance = zo_distance3D(targetX, targetY, targetH, selfX, selfY, selfH) / 100
		return nDistance
	end
	
	local GroupMultiMounts = {}
	local displayNamePref = nil
	local isMountable = false
	for iD = 1, GetGroupSize() do
		local playerID = GetGroupUnitTagByIndex(iD)
		local playerCharName = GetUnitName(playerID)
		local playerDisplayName = GetUnitDisplayName(playerID)
		local distance = DistanceToUnit(playerID)
		local mountedState, hasEnabledGroupMount, hasFreePassengerSlot = GetTargetMountedStateInfo(playerDisplayName)
		if mountedState == MOUNTED_STATE_MOUNT_RIDER and hasEnabledGroupMount and hasFreePassengerSlot then isMountable = true else isMountable = false end
		if not ZO_ShouldPreferUserId() then displayNamePref = playerCharName else displayNamePref = playerDisplayName end
		displayNamePref = zo_strformat("<<1>>", displayNamePref)--<< Strip genders
		if playerDisplayName ~= GetUnitDisplayName("player") and IsUnitOnline(playerID) and IsUnitInGroupSupportRange(playerID) and isMountable and distance < 5.0 then
			table.insert(GroupMultiMounts, {name = displayNamePref, distance = distance})
		end
	end
	if #GroupMultiMounts > 0 then
		table.sort(GroupMultiMounts, function(a, b) return a.distance < b.distance end)
		--dismount
		EnablePreviewMode(true)
		DisablePreviewMode()
		local name = GroupMultiMounts[1].name
		UseMountAsPassenger(name)
		if SSF.SV.multiMountNotify then
			SSF.Notifications.Notify(zo_strformat("Mounted <<1>> as a passenger.", name))
		end
	else
		if SSF.SV.multiMountNotify then
			SSF.Notifications.Notify(zo_strformat("No multi-mount within range."))
		end
	end
end


--[[------------------------------------------------------------------------------------------------
Mounts.UpdateMountData()
Inputs:				None
Outputs:			None
Description:	Updates the mount lists.
------------------------------------------------------------------------------------------------]]--
function Mounts.UpdateMountData()
	local function IsNotMountCategory(categoryData)
		return not categoryData:IsOutfitStylesCategory() and not categoryData:IsHousingCategory()
	end

	local function IsMount(collectibleData)
		return collectibleData:IsCategoryType(COLLECTIBLE_CATEGORY_TYPE_MOUNT)
	end

	local SoloMountCollectionData = {id = {}, name = {}}
	local MultiMountCollectionData = {id = {}, name = {}}

	--Iterate over the main categories and do not use outfits or houses
	for idx, categoryData in CDM:CategoryIterator({IsNotMountCategory}) do
		--Iterate over the sub-categories of the current main category and do not use outfits or houses
		for _, subCategoryData in categoryData:SubcategoryIterator({IsNotMountCategory}) do
			--Iterate over the sub-categorie's collectibles and only check for mounts collectible type
			for _, subCatCollectibleData in subCategoryData:CollectibleIterator({IsMount}) do
				--Check if the mount is owned/unlocked and not blocked
				if subCatCollectibleData:IsUnlocked() and not subCatCollectibleData:IsBlocked() then
					local id = subCatCollectibleData:GetId()
					local isActive = subCatCollectibleData:IsActive(GAMEPLAY_ACTOR_CATEGORY_PLAYER)
					local name = subCatCollectibleData:GetFormattedName()
					if isActive then
						Mounts.currentMount = {
							id = id,
							name = name,
						}
					end
					if subCategoryData:GetId() == multiRiderSubCatID then
						table.insert(MultiMountCollectionData.id, id)
						table.insert(MultiMountCollectionData.name, name)
					else
						table.insert(SoloMountCollectionData.id, id)
						table.insert(SoloMountCollectionData.name, name)
					end
				end
			end
		end
	end

	-- add in virtual mount selections
	table.insert(SoloMountCollectionData.id, 1, 7) --offset id by 6, first collectible that's not a mount
	table.insert(SoloMountCollectionData.name, 1, "-- Random Favorite Mount")
	table.insert(SoloMountCollectionData.id, 2, 8)
	table.insert(SoloMountCollectionData.name, 2, "-- Random Mount")

	-- convert to paired lists and sort
	Mounts.MultiMount = LibStatic.PairedListNew(MultiMountCollectionData.name, MultiMountCollectionData.id)
	Mounts.SoloMount = LibStatic.PairedListNew(SoloMountCollectionData.name, SoloMountCollectionData.id)
	Mounts.MultiMount:Sort()
	Mounts.SoloMount:Sort()
end


--[[------------------------------------------------------------------------------------------------
Mounts.OnGroupMemberJoined(eventCode, memberCharacterName, memberDisplayName, isLocalPlayer)
Inputs:				eventCode 													- ZOS eventcode
							memberCharacterName 								- Character name of who joined
							memberDisplayName 									- Display name of who joined
							isLocalPlayer 											- True if the person who joined is the user
Outputs:			None
Description:	Updates the mount to the multi mount.
------------------------------------------------------------------------------------------------]]--
function Mounts.OnGroupMemberJoined(eventCode, memberCharacterName, memberDisplayName, isLocalPlayer)
	if isLocalPlayer and SSF.CH.multiMountEnable then
		UseCollectible(SSF.CH.multiMount, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
		SSF.Chat:Debug(zo_strformat("Set to multi mount: <<1>>", GetCollectibleLink(SSF.CH.multiMount)))
	end
end


--[[------------------------------------------------------------------------------------------------
Mounts.OnGroupMemberLeft(eventCode, memberCharacterName, reason, isLocalPlayer, isLeader, memberDisplayName, actionRequiredVote)
Inputs:				eventCode 													- ZOS eventcode
							memberCharacterName 								- Character name of who left
							reason 															- Reason code for the leave
							isLocalPlayer 											- True if the person who left is the user
							isLeader 														- True if it was the leader that left
							memberDisplayName 									- Display name of who left
							actionRequiredVote 									- True if it was a vote kick
Outputs:			None
Description:	Updates the mount to the solo mount.
------------------------------------------------------------------------------------------------]]--
function Mounts.OnGroupMemberLeft(eventCode, memberCharacterName, reason, isLocalPlayer, isLeader, memberDisplayName, actionRequiredVote)
	if isLocalPlayer and SSF.CH.multiMountEnable then
		if SSF.CH.soloMount == 7 or SSF.CH.soloMount == 8 then
			SetRandomMountType(SSF.CH.soloMount - 6, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
		else
			UseCollectible(SSF.CH.soloMount, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
			SSF.Chat:Debug(zo_strformat("Set to solo mount: <<1>>", GetCollectibleLink(SSF.CH.soloMount)))
		end
	end
end


--[[------------------------------------------------------------------------------------------------
Mounts.OnPlayerActivated(eventCode, initial)
Inputs:				eventCode 													- ZOS eventcode
							initial 														- true if this is the initial load
Outputs:			None
Description:	Updates the mount if group status changed while player was offline.
------------------------------------------------------------------------------------------------]]--
function Mounts.OnPlayerActivated(eventCode, initial)
	if initial and SSF.CH.multiMountEnable then
		if IsUnitGrouped("player") then
			UseCollectible(SSF.CH.multiMount, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
			SSF.Chat:Debug(zo_strformat("Set to multi mount: <<1>>", GetCollectibleLink(SSF.CH.multiMount)))
		else
			UseCollectible(SSF.CH.soloMount, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
			SSF.Chat:Debug(zo_strformat("Set to solo mount: <<1>>", GetCollectibleLink(SSF.CH.soloMount)))
		end
	end
	EM:UnregisterForEvent(Mounts.eventSpace, EVENT_PLAYER_ACTIVATED)
end


--[[------------------------------------------------------------------------------------------------
Mounts.MountContextMenu()
Inputs:			  None
Outputs:			None
Description:	Adds an entry to the Mount list context menu.
------------------------------------------------------------------------------------------------]]--
function Mounts.MountContextMenu()	
	ZO_PreHook(ZO_CollectibleTile_Keyboard, "ShowMenu", function(self_)
		local data = self_.collectibleData
		if data:GetCategoryType() == COLLECTIBLE_CATEGORY_TYPE_MOUNT and SSF.CH.multiMountEnable then
			local ZO_ShowMenu = ShowMenu
			function ShowMenu(...)
				ShowMenu = ZO_ShowMenu
				AddCustomMenuItem("SSF Set Mount", function()
					local id = data:GetId()
					local index = Mounts.SoloMount:GetChoiceByValue(id)
					if index then
						SSF.CH.soloMount = id
						return
					end
					index = Mounts.MultiMount:GetChoiceByValue(id)
					if index then
						SSF.CH.multiMount = id
						return
					end
				end)
				return ShowMenu(...)
			end
		end
	end)

	ZO_PreHook(ZO_CollectibleImitationTile_Keyboard, 'ShowMenu', function(self_)
		local data = self_.imitationCollectibleData
		if data.randomMountType and SSF.CH.multiMountEnable then
			local ZO_ShowMenu = ShowMenu
			function ShowMenu(...)
				ShowMenu = ZO_ShowMenu
				AddCustomMenuItem("SSF Set Mount", function()
					SSF.CH.soloMount = data.randomMountType + 6 --offset id by 6, first collectible that's not a mount
				end)
				return ShowMenu(...)
			end
		end
	end)
end


--[[------------------------------------------------------------------------------------------------
Global template assignment
------------------------------------------------------------------------------------------------]]--
StaticsSocialFeatures.Mounts = Mounts