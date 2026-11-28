--[[------------------------------------------------------------------------------------------------
Title:					Static's Letter Opener
Author:					Static_Recharge
Version:			  1.2.0
Description:		Opens master writs and survey letters automatically
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local EM = EVENT_MANAGER
local SM = SCENE_MANAGER


--[[------------------------------------------------------------------------------------------------
Static Values
------------------------------------------------------------------------------------------------]]--
local Containers = {
	["surveys"] = {
		[219849] = true,			-- blacksmithing
		[219850] = true,			-- clothing
		[219851] = true,			-- woodworking
		[219852] = true,			-- enchanting
		[219853] = true,			-- alchemy
		[219854] = true,			-- jewelry
	},

	["masterWrits"] = {
		[217917] = true,			-- blacksmithing
		[217918] = true,			-- clothing
		[217919] = true,			-- woodworking
		[217920] = true,			-- enchanting
		[217921] = true,			-- provisioning
		[217922] = true,			-- alchemy
		[217923] = true,			-- jewelry
	},

	["maps"] = {
		[224681] = true, 			-- treasure map
	},

	["ic"] = {
		[212219] = true, 			-- jewelrycrafting pouch
		[212230] = true, 			-- furnishing materials trunk
		[212238] = true, 			-- sack of provisions
		[212247] = true, 			-- carpentry crate
		[212248] = true, 			-- chest of runes
		[212249] = true, 			-- smithy case
		[212251] = true, 			-- alchemical sachet
		[212252] = true, 			-- clothier coffer
	},
}


--[[------------------------------------------------------------------------------------------------
StaticsLetterOpener Class Initialization
StaticsLetterOpener    														- Parent object containing all functions, tables, variables, constants and other data managers.
├─ :IsInitialized()                               - Returns true if the object has been successfully initialized.
├─ :OnInventorySingleSlotUpdate(eventCode, bagId, slotId, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange)
│              																		- Adds found items to the Que and starts the opening event.
├─ :Open()                												- Opens the next item in the Que.
├─ :GetInventoryIndex()                           - Searches for and returns the slot number of the next item in the Que.
└─ :Test(...)                                     - For internal add-on testing only.
------------------------------------------------------------------------------------------------]]--
StaticsLetterOpener = {}
local SLO = StaticsLetterOpener

-- Static definitions
SLO.addonName = "StaticsLetterOpener"
SLO.addonVersion = "1.2.0"
SLO.author = "|CFF0000Static_Recharge|r"
SLO.varsVersion = 1


--[[------------------------------------------------------------------------------------------------
SLO.Initialize()
Inputs:				None
Outputs:			None
Description:	Initializes all of the variables, object managers, slash commands and main event
							callbacks.
------------------------------------------------------------------------------------------------]]--
function SLO.Initialize()
	SLO.Defaults = {
		surveys = true,
		masterWrits = false,
		maps = false,
		ic = false,
		openAll = false,
		chatEnabled = true,
		debugEnabled = false,
		settingsChanged = true,
	}

	-- Session variables
	SLO.Que = {}
	SLO.started = false

	-- Saved variables initialization
	SLO.SV = ZO_SavedVars:NewAccountWide("StaticsLetterOpenerAccountWideVars", SLO.varsVersion, nil, SLO.Defaults, GetWorldName())

	-- Library initialization
	local Options = {
		addonIdentifier = "Letter Opener",
		prefixColor = "FFFFFF",
		textColor = "FFFFFF",
		chatEnabled = SLO.SV.chatEnabled,
		debugEnabled = SLO.SV.debugEnabled,
	}
	SLO.Chat = LibStatic.ChatNew(Options)

	-- Module initilization
	SLO.Settings.Initialize()
	
	-- Event Registrations
	EM:RegisterForEvent(SLO.addonName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, SLO.OnInventorySingleSlotUpdate)
	EM:AddFilterForEvent(SLO.addonName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
	EM:AddFilterForEvent(SLO.addonName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
	EM:RegisterForEvent(SLO.addonName, EVENT_LOOT_UPDATED, SLO.OnLootUpdated)

	--SLASH_COMMANDS["/slotest"] = function(...) self:Test(...) end

	SLO.initialized = true
end


--[[------------------------------------------------------------------------------------------------
SLO.IsInitialized()
Inputs:				None
Outputs:			initialized                         - bool for object initialized state
Description:	Returns true if the object has been successfully initialized.
------------------------------------------------------------------------------------------------]]--
function SLO.IsInitialized()
  return SLO.initialized
end


--[[------------------------------------------------------------------------------------------------
SLO.OnInventorySingleSlotUpdate(eventCode, bagId, slotId, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange)
Inputs:				eventCode														- Internal ZOS event code, not used here.
							bagId																- Number for which bag was affected (use globals)
							slotId 															- Slot number for the item that was affected
							isNewItem 													- True if the item is new to the player
							itemSoundCategory 									- Sound information for the item
							inventoryUpdateReason 							- Global reason for inventory change
							stackCountChange 										- new stack count
Outputs:			None
Description: 	Adds found items to the Que and starts the opening event.
------------------------------------------------------------------------------------------------]]--
function SLO.OnInventorySingleSlotUpdate(eventCode, bagId, slotId, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange)
	-- If open all is disabled and the item isn't new then exit as there's nothing to do.
	if not SLO.SV.openAll and not isNewItem then return end

	local itemData = {
		id = GetItemId(bagId, slotId),
		link = GetItemLink(bagId, slotId),
	}

	-- search through containers and ids for a match
	for category, container in pairs(Containers) do
		if container[itemData.id] and SLO.SV[category] then
			table.insert(SLO.Que, itemData)
			SLO.Chat:Debug(zo_strformat("<<1>> Qued", itemData.link))
			if not SLO.started then
				if category == "ic" then SM:Show("hudui") end
				EM:RegisterForUpdate(SLO.addonName, 500, SLO.Open)
				SLO.started = true
			end
		end
	end
end


--[[------------------------------------------------------------------------------------------------
SLO.Open()
Inputs:				None
Outputs:			None
Description:	Opens the next item in the Que.
------------------------------------------------------------------------------------------------]]--
function SLO.Open()
	local bag = BAG_BACKPACK
	if #SLO.Que == 0 then
		EM:UnregisterForUpdate(SLO.addonName)
		SLO.started = false
		return
	end
	if GetSlotCooldownInfo(1) == 0 then
		local slotId = SLO.GetInventoryIndex()
		if slotId then
			SLO.Chat:Debug(zo_strformat("Item Found: slotId: <<1>>, bag: <<2>>, <<3>>", slotId, bag, GetItemLink(bag, slotId)))
			if IsProtectedFunction("UseItem") then
				CallSecureProtected("UseItem", bag, slotId)
			else
				UseItem(bag, slotId)
			end
			SLO.Chat:Msg(zo_strformat("<<1>> Opened", SLO.Que[1].link))
		else
			SLO.Chat:Msg(zo_strformat("<<1>> Not found", SLO.Que[1].link))
		end
		table.remove(SLO.Que, 1)
	end
end


--[[------------------------------------------------------------------------------------------------
SLO.GetInventoryIndex()
Inputs:				None
Outputs:			slotIndex 													- The slot containing the next item in the Que
Description:	Searches for and returns the slot number of the next item in the Que.
------------------------------------------------------------------------------------------------]]--
function SLO.GetInventoryIndex()
	local bag = BAG_BACKPACK
	local bagData = SHARED_INVENTORY:GetOrCreateBagCache(bag)
	if not ZO_IsTableEmpty(bagData) then
		local queOne = SLO.Que[1]
		for slotIndex, slotData in pairs(bagData) do
			if HasItemInSlot(bag, slotIndex) and GetItemId(bag, slotIndex) == queOne.id then
				SLO.Chat:Debug(zo_strformat("<<1>> Found", queOne.link))
				return slotIndex
			end
		end
	end
end


--[[------------------------------------------------------------------------------------------------
SLO.OnLootUpdated(eventCode)
Inputs:				None
Outputs:			None
Description:	Loots the container.
------------------------------------------------------------------------------------------------]]--
function SLO.OnLootUpdated(eventCode)
	if SLO.started then
		LootAll()
		SM:ShowBaseScene()
	end
end


--[[------------------------------------------------------------------------------------------------
SLO.Test()
Inputs:				None
Outputs:			None
Description:	
------------------------------------------------------------------------------------------------]]--
function SLO.Test(...)
	d("test")
end


--[[------------------------------------------------------------------------------------------------
Main add-on event registration. Creates the global object, StaticsLetterOpener, of the LO class.
------------------------------------------------------------------------------------------------]]--
EM:RegisterForEvent(SLO.addonName, EVENT_ADD_ON_LOADED, function(eventCode, addonName)
	if addonName ~= SLO.addonName then return end
	EM:UnregisterForEvent(SLO.addonName, EVENT_ADD_ON_LOADED)
	SLO.Initialize()
end)