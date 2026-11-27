--[[------------------------------------------------------------------------------------------------
Title:					Static's Furnishing Improvements
Author:					Static_Recharge
Version:			  1.1.0
Description:		Adds functionality to the in game furnishing menus and placement UI
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local EM = EVENT_MANAGER
local SM = SCENE_MANAGER
local CRAFTING_STATIONS = 104
local LS = LibStatic


--[[------------------------------------------------------------------------------------------------
StaticsFurnishingImprovements Object Initialization
StaticsFurnishingImprovements					            - Parent object containing all functions, tables, variables, constants and other data managers.
├─ :IsInitialized()                               - Returns true if the object has been successfully initialized.
├─ :OnPlayerActivated() 													- Shows or hides the retrieve to bag menu.
├─ :StowCraftingStationsHook() 										- Automatically stores crafting stations in the furnishing vault when picking them up from a house.
├─ :DepositSameFromInventory() 										- Deposits already existing stacks into the furnishing vault.
├─ :DepositSameFromHouseDialog() 									- Starts the dialog to confirm moving furniture from the house to the furnishing vault.
├─ :DepositSameFromHouse() 									 			- Moves furniture from the house to the furnishing vault.
└─ :AddDepostSameKeybindButton()						 			- Adds the Deposit Same keybinding to the strip. 
------------------------------------------------------------------------------------------------]]--
StaticsFurnishingImprovements = {}
local SFI = StaticsFurnishingImprovements

-- Static definitions
SFI.addonName = "StaticsFurnishingImprovements"
SFI.addonVersion = "1.1.0"
SFI.author = "|CFF0000Static_Recharge|r"
SFI.varsVersion = 1


--[[------------------------------------------------------------------------------------------------
SFI.Initialize()
Inputs:				None
Outputs:			None
Description:	Initializes all of the variables, object managers, slash commands and main event
							callbacks.
------------------------------------------------------------------------------------------------]]--
function SFI.Initialize()
	SFI.Defaults = {
		-- Misc
		chatEnabled = true,
		debugEnabled = false,
		settingsChanged = true,

		-- Deposit and Retrieve
		depositSameFromInventory = true,
		depositSameFromHouse = true,
		depositCraftingStations = false,
		showRetrieveToOnHUD = true,

		-- Queue
		queueEnabled = true,
		queueTop = nil,
		queueLeft = nil,
		queueShowAfterAdd = true,
		Queue = {},

		-- Vault Stats
		vaultStatsEnabled = true,
		vaultStatsTop = nil,
		vaultStatsLeft = nil,
		vaultAutoShow = false,
		VaultData = {},
	}

	SFI.Dialogs = {
		DEPOSIT_SAME = {
			canQueue = false,
			title ={text = "Deposit Same from House",},
			mainText ={text = "This will move |cFFFF66<<1>>|r items from the current house to the Furniture Vault.\n\nAre you sure?",},
			buttons = {
				[1] = {
					text = SI_YES,
					callback = function(dialog)
						SFI.DepositSameFromHouse()
					end,
				},
				[2] = {
					text = SI_NO,
					callback = function(dialog)
						
					end,
				}
			}
		},
	}

	SFI.MasterStations = {
		[203555] = true, 					-- Grand Master Blacksmithing Station
		[203553] = true, 					-- Grand Master Clothing Station
		[203556] = true, 					-- Grand Master Jewleryaw Crafting Station
		[203554] = true, 					-- Grand Master Woodworking Station
	}
	
	-- Session Variables
	SFI.Scenes = {
		housingEditorHUD = SM:GetScene("housingEditorHud"),
		housingEditorHUDUI = SM:GetScene("housingEditorHudUI"),
		furnitureVaultScene = SM:GetScene("furnitureVault"),
		inventoryScene = SM:GetScene("inventory"),
		hudUI = SM:GetScene("hudui"),
		hud = SM:GetScene("hud"),
	}

	-- Saved Variables Initialization
	SFI.SV = ZO_SavedVars:NewAccountWide("StaticsFurnishingImprovementsWideVars", SFI.varsVersion, nil, SFI.Defaults, GetWorldName())

	-- Library Initialization
	local Options = {
		addonIdentifier = "SFI",
		prefixColor = "0086B3",
		textColor = "FFFFFF",
		chatEnabled = SFI.SV.chatEnabled,
		debugEnabled = SFI.SV.debugEnabled,
	}
	SFI.Chat = LS.ChatNew(Options)

	-- Module Initialization
	SFI.Settings.Initialize()
	if SFI.SV.queueEnabled then
		SFI.Queue.Initialize()
	else
		SFI.Queue = nil
	end
	if SFI.SV.vaultStatsEnabled then
		SFI.VaultStats.Initialize()
	else
		SFI.VaultStats = nil
	end

	-- Hooks
	SFI.StowCraftingStationsHook()	
	
	-- Event Registrations and Callbacks
  EM:RegisterForEvent(SFI.addonName, EVENT_PLAYER_ACTIVATED, SFI.OnPlayerActivated)

	-- Slash Commands
	SLASH_COMMANDS["/sfisamehouse"] = function() SFI.DepositSameFromHouseDialog() end

	-- Keybinds
	SFI.AddDepostSameKeybindButton()
	ZO_CreateStringId("SI_BINDING_NAME_SFI_Deposit_Same_From_House", "Deposit Same From House")

	-- Dialogs
	ESO_Dialogs[SFI.addonName .. "Deposit_Same_Confirm"] = SFI.Dialogs.DEPOSIT_SAME
  
	SFI.initialized = true
end


--[[------------------------------------------------------------------------------------------------
SFI.OnPlayerActivated()
Inputs:				None
Outputs:			None
Description:	Shows or hides the retrieve to bag menu.
------------------------------------------------------------------------------------------------]]--
function SFI.OnPlayerActivated()
	SFI.Chat:Debug("OnPlayerActivated started.")
	if IsOwnerOfCurrentHouse() then
		if SFI.SV.showRetrieveToOnHUD then
			SFI.Scenes.housingEditorHUD:AddFragment(HOUSING_FURNITURE_RETRIEVE_TO_FRAGMENT)
		else
			SFI.Scenes.housingEditorHUD:RemoveFragment(HOUSING_FURNITURE_RETRIEVE_TO_FRAGMENT)
		end
		SFI.Scenes.housingEditorHUDUI:AddFragment(HOUSING_FURNITURE_RETRIEVE_TO_FRAGMENT)
	else
		SFI.Scenes.housingEditorHUD:RemoveFragment(HOUSING_FURNITURE_RETRIEVE_TO_FRAGMENT)
		SFI.Scenes.housingEditorHUDUI:RemoveFragment(HOUSING_FURNITURE_RETRIEVE_TO_FRAGMENT)
	end  
end


--[[------------------------------------------------------------------------------------------------
SFI.StowCraftingStationsHook()
Inputs:				None
Outputs:			None
Description:	Automatically stores crafting stations in the furnishing vault when picking them up from a house.
------------------------------------------------------------------------------------------------]]--
function SFI.StowCraftingStationsHook()
	local function preHookRetrieve(data)
		if not SFI.SV.depositCraftingStations then return end

		SFI.currentRetrieveTo = HousingEditorGetRetrieveToBag()
		if SFI.currentRetrieveTo == BAG_FURNITURE_VAULT then return end

		local furnitureLink
		if data then
			furnitureLink = data.retrievableFurnitureId
		else
			furnitureLink = GetPlacedFurnitureLink(HousingEditorGetSelectedFurnitureId())
		end
		local itemId = GetItemLinkItemId(furnitureLink)
		local _, subCategory = GetFurnitureDataInfo(GetItemLinkFurnitureDataId(furnitureLink))
		SFI.Chat:Debug(zo_strformat("link: <<1>>, subCategory: <<2>>", furnitureLink, subCategory))

		if subCategory == CRAFTING_STATIONS then
			if not SFI.MasterStations[itemId] then
				HousingEditorSetRetrieveToBag(BAG_FURNITURE_VAULT)
				SFI.Chat:Msg(zo_strformat("<<1>> sent to the Furnishing Vault.", furnitureLink))
			else
				HousingEditorSetRetrieveToBag(SFI.currentRetrieveTo)
				SFI.Chat:Msg(zo_strformat("<<1>> can't be sent to the Furnishing Vault. Sending to previously selected bag.", furnitureLink))
			end
		end
	end

	local function postHookRetrieve()
		if SFI.currentRetrieveTo then
			HousingEditorSetRetrieveToBag(SFI.currentRetrieveTo)
			SFI.currentRetrieveTo = nil
		end
	end

	ZO_PreHook("HousingEditorRequestRemoveSelectedFurniture", preHookRetrieve)
	ZO_PostHook("HousingEditorRequestRemoveSelectedFurniture", postHookRetrieve)
	ZO_PreHook("HousingEditorRequestRemoveFurniture", preHookRetrieve)	
	ZO_PostHook("HousingEditorRequestRemoveFurniture", postHookRetrieve)
end


--[[------------------------------------------------------------------------------------------------
SFI.DepositSameFromInventory()
Inputs:				None
Outputs:			None
Description:	Deposits already existing stacks into the furnishing vault.
------------------------------------------------------------------------------------------------]]--
function SFI.DepositSameFromInventory()
	if not SFI.SV.depositSameFromInventory then return end

  local FurnitureCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_FURNITURE_VAULT)
	local backpackCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
	local count = 0

	for furnitureIndex, furnitureData in pairs(FurnitureCache) do
		local furnitureID = GetItemId(BAG_FURNITURE_VAULT, furnitureIndex)
		for backpackIndex, backpackData in pairs(backpackCache) do
			local backpackID = GetItemId(BAG_BACKPACK, backpackIndex)
			local link = GetItemLink(BAG_BACKPACK, backpackIndex)
			SFI.Chat:Debug(zo_strformat("furnitureID: <<1>>, backpackID: <<2>>", furnitureID, backpackID))
			if furnitureID == backpackID then
				if IsProtectedFunction("PickupInventoryItem") then
					CallSecureProtected("PickupInventoryItem", BAG_BACKPACK, backpackIndex)
				else
					PickupInventoryItem(BAG_BACKPACK, backpackIndex)
				end
				if IsProtectedFunction("PlaceInTransfer") then
					CallSecureProtected("PlaceInTransfer")
				else
					PlaceInTransfer()
				end
				SFI.Chat:Msg(zo_strformat("<<1>> moved to furnishing vault.", link))
				count = count + 1
			end			
		end
	end
	SFI.Chat:Msg(zo_strformat("<<1>> items moved to furnishing vault.", count))
end


--[[------------------------------------------------------------------------------------------------
SFI.DepositSameFromHouseDialog()
Inputs:				None
Outputs:			None
Description:	Starts the dialog to confirm moving furniture from the house to the furnishing vault.
------------------------------------------------------------------------------------------------]]--
function SFI.DepositSameFromHouseDialog()
	if not SFI.SV.depositSameFromHouse then return end

  local FurnitureCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_FURNITURE_VAULT)

	-- Cache house furniture
	local HouseCache = {}
	local id = GetNextPlacedHousingFurnitureId()
	while id do
		local link = GetPlacedFurnitureLink(id)
		local furniture = {
			id = id,
			link = link,
			data = GetItemLinkFurnitureDataId(link)
		}
		table.insert(HouseCache, furniture)
		id = GetNextPlacedHousingFurnitureId(id)
	end

	-- Count how many would be removed and index them
	SFI.found = {}
	for furnitureIndex, furnitureData in pairs(FurnitureCache) do
		local furnitureID = GetItemId(BAG_FURNITURE_VAULT, furnitureIndex)
		for houseIndex, houseData in pairs(HouseCache) do
			local houseID = GetItemLinkItemId(houseData.link)
			local link = houseData.link
			SFI.Chat:Debug(zo_strformat("furnitureID: <<1>>, houseID: <<2>>", furnitureID, houseID))
			if furnitureID == houseID then
				table.insert(SFI.found, houseData)
			end			
		end
	end

	-- Show confirm dialog
	if #SFI.found > 0 then
		ZO_Dialogs_ShowDialog(SFI.addonName .. "Deposit_Same_Confirm", nil, {mainTextParams={#SFI.found}}, false)
	else
		SFI.Chat:Msg("No matching furnishings found to move to the Furnishing Vault.")
	end
end


--[[------------------------------------------------------------------------------------------------
SFI.DepositSameFromHouse()
Inputs:				None
Outputs:			None
Description:	Moves furniture from the house to the furnishing vault.
------------------------------------------------------------------------------------------------]]--
function SFI.DepositSameFromHouse()
  -- If dialog passed then remove the furniture to the furnishing vault
	local currentRetrieveTo = HousingEditorGetRetrieveToBag()
	local count = 0
	local total = #SFI.found
	HousingEditorSetRetrieveToBag(BAG_FURNITURE_VAULT)
	for index, data in ipairs(SFI.found) do
		local result = HousingEditorRequestRemoveFurniture(data.id)
		ZO_AlertEvent(EVENT_HOUSING_EDITOR_REQUEST_RESULT, result)
    PlaySound(SOUNDS.DEFAULT_CLICK)
		if result == HOUSING_REQUEST_RESULT_SUCCESS then
			count = count + 1
			SFI.Chat:Msg(zo_strformat("<<1>> moved to furnishing vault from house.", data.link))
		end
	end
	SFI.Chat:Msg(zo_strformat("<<1>> items moved to furnishing vault from house.", count))
	HousingEditorSetRetrieveToBag(currentRetrieveTo)
	if count ~= total then
		SFI.Chat:Msg(zo_strformat("<<1>> items were skipped.", total - count))
	end
end


--[[------------------------------------------------------------------------------------------------
SFI.AddDepostSameKeybindButton()
Inputs:				None
Outputs:			None
Description:	Adds the Deposit Same keybinding to the strip.
------------------------------------------------------------------------------------------------]]--
function SFI.AddDepostSameKeybindButton()
	local furnitureVaultLeftKeybindStrip = {
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
		name = "Deposit Same",
		keybind = "UI_SHORTCUT_TERTIARY",
		callback = function() SFI.DepositSameFromInventory() end,
	}

	SFI.Scenes.furnitureVaultScene:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_SHOWING and SFI.SV.depositSameFromInventory then
			KEYBIND_STRIP:AddKeybindButton(furnitureVaultLeftKeybindStrip)
		elseif newState == SCENE_HIDDEN then
			KEYBIND_STRIP:RemoveKeybindButton(furnitureVaultLeftKeybindStrip)
		end
	end)
end


--[[------------------------------------------------------------------------------------------------
Main add-on event registration. Creates the global object, StaticsLetterOpener, of the LO class.
------------------------------------------------------------------------------------------------]]--
EM:RegisterForEvent(SFI.addonName, EVENT_ADD_ON_LOADED, function(eventCode, addonName)
	if addonName ~= SFI.addonName then return end
	EM:UnregisterForEvent(SFI.addonName, EVENT_ADD_ON_LOADED)
	SFI.Initialize()
end)