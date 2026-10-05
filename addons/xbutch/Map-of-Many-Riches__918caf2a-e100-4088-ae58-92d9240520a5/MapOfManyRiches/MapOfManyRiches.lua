-- Minimal Map of Many Riches
-- NOTE: The string below MUST exactly match the filename portion of this addon's manifest entry
-- (the .addon file without extension) for EVENT_ADD_ON_LOADED filtering to succeed.
-- The manifest lists this file as MapOfManyRiches.addon (case-sensitive).
local ADDON_NAME = "MapOfManyRiches"
local PIN_TYPE = "MOMR_Pin"
local MapPins = MOMR.internal and MOMR.internal.mapPins
MOMR.pinType = PIN_TYPE

MOMR.defaults = {
	showTreasure = true,
	showSurveys = true,
	backpackOnly = true,
	pinSize = 24
}
MOMR.variableVersion = 3

local PIN_ICONS = {
	treasure = "EsoUI/Art/WorldMap/map_indexicon_key_down.dds",
	survey = "EsoUI/Art/WorldMap/map_indexicon_locations_down.dds"
}

local WAYPOINT_TEXT = "Set Waypoint"
local buttonGroup
local currentKeybindBag, currentKeybindSlot

local function RemoveWaypointKeybind()
	if buttonGroup then
		KEYBIND_STRIP:RemoveKeybindButtonGroup(buttonGroup)
		buttonGroup = nil
	end
	currentKeybindBag, currentKeybindSlot = nil, nil
end

-- keep track of the last zone we reported counts for
local lastZoneMapId

-- cache for backpack lookups
local lastBackpackMapId
local cachedBackpackItems
local backpackCacheValid = false

-- incremental backpack index of relevant itemIds
local presentItemIds = {} -- [itemId] = true when present in backpack (any amount)
local presentItemIdSlotCounts = {} -- [itemId] = number of slots containing this itemId (>0 stack)
local slotRelevantItemId = {} -- [slotIndex] = itemId if this slot has a relevant itemId

-- track the last map we refreshed pins for
local lastRefreshedMapId
local refreshPending = false

local addonInitialized = false -- new: guard to ensure per-character init runs exactly once

--------------------------------------------------------------------
-- DEBUG Helper : simple debug print (disabled in release if needed)
--------------------------------------------------------------------
-- ===== Early debug ring buffer (captures messages before /ac_debug) =====
local preDebugBuffer = {}
local preDebugBufferMax = 200
local function bufferDebugLine(txt)
	if #preDebugBuffer >= preDebugBufferMax then table.remove(preDebugBuffer, 1) end
	preDebugBuffer[#preDebugBuffer + 1] = txt
end

local debugEnabled = false -- shared flag everyone sees
local debugCount = 0

local function dbg(msg)
	-- capture everything in buffer (even if debug off) for later review
	bufferDebugLine(msg)
	if debugEnabled then
		debugCount = debugCount + 1
		if type(d) == 'function' then d('|c99CCFF[MOMR ' .. debugCount .. ']|r ' .. msg) end
	end
end

local function SwitchDebugMode()
	if debugEnabled then
		dbg('Debug disabled')
		debugEnabled = false
		debugCount = 0
	else
		debugEnabled = true
		dbg('Debug enabled')
		-- flush buffered lines (without double-buffering)
		if #preDebugBuffer > 0 then
			for _, ln in ipairs(preDebugBuffer) do
				debugCount = debugCount + 1
				if type(d) == 'function' then d('|c99CCFF[MOMR PRE ' .. debugCount .. ']|r ' .. ln) end
			end
		end
		if not addonInitialized then dbg('Addon not initialized yet (waiting for PLAYER_ACTIVATED).') end
	end
end

local function PrintPlayerCoordinates()
	local mapId = GetCurrentMapId() or 0
	local x, y = GetMapPlayerPosition("player")
	x = x or 0
	y = y or 0

	local msg = string.format("[MOMR] Player coordinates: mapId=%d x=%.6f y=%.6f", mapId, x, y)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(msg)
	elseif type(d) == "function" then
		d(msg)
	end
end

-- Build a lookup of itemIds that belong to the given mapId
local function BuildMapItemLookup(mapId)
	local treasure = MOMR.internal and MOMR.internal.treasure
	local pins = treasure and treasure.GetMapIdData(mapId)
	local lookup = {}
	if pins then for _, pin in ipairs(pins) do if pin.itemId then lookup[pin.itemId] = pin.pinType or true end end end
	return lookup
end

-- Initial scan to index relevant items in backpack once
local function IndexBackpack()
	dbg("IndexBackpack: Scanning backpack for relevant items")

	-- reset state
	dbg("IndexBackpack: reset states")
	presentItemIds = {}
	presentItemIdSlotCounts = {}
	slotRelevantItemId = {}

	dbg("IndexBackpack: GetBagSize")
	local bagSize = GetBagSize(BAG_BACKPACK)
	for slotIndex = 0, bagSize - 1 do
		local itemLink = GetItemLink(BAG_BACKPACK, slotIndex, LINK_STYLE_DEFAULT)
		if itemLink ~= "" then
			local itemId = GetItemLinkItemId(itemLink)
			local treasure = MOMR.internal and MOMR.internal.treasure
			local data = treasure and treasure.GetItemIdData and treasure.GetItemIdData(itemId)
			if data then
				slotRelevantItemId[slotIndex] = itemId
				presentItemIdSlotCounts[itemId] = (presentItemIdSlotCounts[itemId] or 0) + 1
				presentItemIds[itemId] = true
			end
		end
	end
	backpackCacheValid = true
end

local function OnSingleSlotChanged(slotIndex)
	dbg("OnSingleSlotChanged: slot " .. slotIndex)
	-- update our incremental index for a single slot
	local prev = slotRelevantItemId[slotIndex]
	local itemLink = GetItemLink(BAG_BACKPACK, slotIndex, LINK_STYLE_DEFAULT)
	local cur
	if itemLink ~= "" then
		local itemId = GetItemLinkItemId(itemLink)
		local treasure = MOMR.internal and MOMR.internal.treasure
		local data = treasure and treasure.GetItemIdData and treasure.GetItemIdData(itemId)
		dbg("OnSingleSlotChanged: itemId " .. tostring(itemId or "nil") .. (data and " is relevant" or " not relevant"))
		if data then cur = itemId end
	end

	if prev == cur then return end

	if prev then
		local c = (presentItemIdSlotCounts[prev] or 1) - 1
		if c <= 0 then
			presentItemIdSlotCounts[prev] = nil
			presentItemIds[prev] = nil
		else
			presentItemIdSlotCounts[prev] = c
		end
		slotRelevantItemId[slotIndex] = nil
	end

	if cur then
		slotRelevantItemId[slotIndex] = cur
		presentItemIdSlotCounts[cur] = (presentItemIdSlotCounts[cur] or 0) + 1
		presentItemIds[cur] = true
	end
end

-- Count how many relevant items in the player's backpack belong to the given mapId
local function CountItemsForMap(mapId)
	local counts = {
		treasure = 0,
		survey = 0
	}
	local mapItems = BuildMapItemLookup(mapId)
	local bagSize = GetBagSize(BAG_BACKPACK)
	for slotIndex = 0, bagSize - 1 do
		local itemLink = GetItemLink(BAG_BACKPACK, slotIndex, LINK_STYLE_DEFAULT)
		if itemLink ~= "" then
			local itemId = GetItemLinkItemId(itemLink)
			local pinType = mapItems[itemId]
			if pinType and counts[pinType] ~= nil then counts[pinType] = counts[pinType] + GetSlotStackSize(BAG_BACKPACK, slotIndex) end
		end
	end
	return counts
end

-- Print a chat message about items for the player's current zone
local function PrintZoneItemCounts()
	local mapId = GetCurrentMapId()
	if mapId == lastZoneMapId or mapId == 0 then return end
	lastZoneMapId = mapId

	local counts = CountItemsForMap(mapId)
	local total = counts.treasure + counts.survey
	if total == 0 then return end

	local parts = {}
	if counts.survey > 0 then table.insert(parts, string.format("%d surveys", counts.survey)) end
	if counts.treasure > 0 then table.insert(parts, string.format("%d treasure maps", counts.treasure)) end
	local msg = string.format("You have %s for this zone in your backpack.", table.concat(parts, ", "))
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(msg)
	elseif type(d) == "function" then
		d(msg)
	end
end

--------------------------------------------------------------------
-- 2.  Inventory
--------------------------------------------------------------------
local function ShowWaypointAnnouncement(text)
	if CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.CreateMessageParams then
		local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE)
		params:SetText(text)
		CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
	end
end

local function GetPinDataForItem(itemId, mapId)
	local treasure = MOMR.internal and MOMR.internal.treasure
	local pins = treasure and treasure.GetMapIdData(mapId)
	if pins then for _, pin in ipairs(pins) do if pin.itemId == itemId then return pin end end end
	return nil
end

local function SetItemWaypoint(bagId, slotIndex)
	local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
	if itemLink == "" then return end
	local itemId = GetItemLinkItemId(itemLink)
	local currentMapId = GetCurrentMapId()
	local pinData = GetPinDataForItem(itemId, currentMapId)
	if not pinData then
		local treasure = MOMR.internal and MOMR.internal.treasure
		pinData = treasure and treasure.GetItemIdData(itemId, currentMapId)
	end
	if not pinData or not pinData.mapId or not pinData.x or not pinData.y then return end

	dbg(string.format("Setting waypoint for itemId %d", itemId))
	if SetMapToMapId(pinData.mapId) == SET_MAP_RESULT_MAP_CHANGED then
		PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, pinData.x, pinData.y)
		if currentMapId ~= pinData.mapId then SetMapToMapId(currentMapId) end
	else
		PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, pinData.x, pinData.y)
	end

	local msg = string.format("Waypoint set to %s", pinData.tooltip or GetItemLinkName(itemLink))
	ShowWaypointAnnouncement(msg)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(msg)
	elseif type(d) == "function" then
		d(msg)
	end
end

local function ShouldHandleItem(bagId, slotIndex)
	local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
	if itemLink == "" then
		dbg("ShouldHandleItem: empty item link")
		return false
	end

	local itemId = GetItemLinkItemId(itemLink)
	local treasure = MOMR.internal and MOMR.internal.treasure
	local data = treasure and treasure.GetItemIdData(itemId)

	if not data then
		dbg("ShouldHandleItem: no treasure data for itemId " .. tostring(itemId))
		return false
	end
	local ok = (data.pinType == MOMR_PIN_TYPE_TREASURE or data.pinType == MOMR_PIN_TYPE_SURVEYS)
	-- dbg(string.format("ShouldHandleItem: itemId=%s pinType=%s ok=%s", tostring(itemId), tostring(data.pinType), tostring(ok)))
	return ok
end

local function shouldKeyBeVisible()
	-- Gamepad / console only: inventory root scene
	if not (IsInGamepadPreferredMode() or IsConsoleUI()) then return false end
	if not SCENE_MANAGER or not SCENE_MANAGER:IsShowing("gamepad_inventory_root") then return false end

	local backpackInventory = PLAYER_INVENTORY and PLAYER_INVENTORY.inventories and PLAYER_INVENTORY.inventories[INVENTORY_BACKPACK]
	if not backpackInventory then return false end
	local listView = backpackInventory.listView or (PLAYER_INVENTORY.GetActiveList and PLAYER_INVENTORY.GetActiveList(PLAYER_INVENTORY))
	if not listView or not listView.GetTargetData then return false end
	local data = listView:GetTargetData()
	if not data or not data.bagId or not data.slotIndex then return false end
	if data.bagId ~= BAG_BACKPACK then return false end
	local _, specializedItemType = GetItemType(data.bagId, data.slotIndex)
	-- Only surveys & treasure maps
	return specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT or specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP
end

local function InventorySlotActionHook(inventoryInfo, slotActions)
	if not (IsInGamepadPreferredMode() or IsConsoleUI()) then return end
	-- Remove keybind immediately if the inventory scene is not showing (e.g. bank, trading house, or any other scene)
	if not SCENE_MANAGER or not SCENE_MANAGER:IsShowing("gamepad_inventory_root") then
		RemoveWaypointKeybind()
		return
	end
	if not inventoryInfo then
		dbg("InventoryHook: nil inventoryInfo")
		RemoveWaypointKeybind()
		return
	end
	-- Keyboard inventory stores data under .dataSource; gamepad list entries use .itemData.
	local source = inventoryInfo.dataSource or inventoryInfo.itemData or inventoryInfo
	local bag = source.bagId
	local slot = source.slotIndex
	if not bag or not slot then
		dbg("InventoryHook: missing bag/slot")
		RemoveWaypointKeybind()
		return
	end
	if bag ~= BAG_BACKPACK then
		dbg("InventoryHook: not backpack")
		RemoveWaypointKeybind();
		return
	end

	if not ShouldHandleItem(bag, slot) then
		dbg("InventoryHook: ShouldHandleItem false")
		RemoveWaypointKeybind();
		return
	end

	if slotActions and slotActions.AddSlotAction then slotActions:AddSlotAction(WAYPOINT_TEXT, function() SetItemWaypoint(bag, slot) end, "keybind3") end

	if currentKeybindBag == bag and currentKeybindSlot == slot and buttonGroup then return end

	-- Remove existing keybind
	RemoveWaypointKeybind()

	-- Wait for the next frame to add the keybind
	zo_callLater(function()
		-- Scene check only: don't add keybind if user navigated away during the 10ms delay.
		-- We use the closed-over bag/slot (not listView:GetTargetData) because the list view
		-- state may not yet reflect the focused item when this callback fires.
		if not SCENE_MANAGER or not SCENE_MANAGER:IsShowing("gamepad_inventory_root") then return end
		if not (IsInGamepadPreferredMode() or IsConsoleUI()) then return end
		if bag ~= BAG_BACKPACK then return end
		if not ShouldHandleItem(bag, slot) then return end
		buttonGroup = {
			{
				name = WAYPOINT_TEXT,
				alignment = KEYBIND_STRIP_ALIGN_RIGHT,
				keybind = "UI_SHORTCUT_QUATERNARY",
				ethHold = true,
				holdDuration = 1000,
				callback = function() SetItemWaypoint(bag, slot) end
			}
		}
		currentKeybindBag, currentKeybindSlot = bag, slot
		KEYBIND_STRIP:AddKeybindButtonGroup(buttonGroup)
		-- dbg(string.format("Waypoint keybind added (bag=%d slot=%d)", bag, slot))
	end, 10)
end

local function OnPlayerActivated()
	dbg("OnPlayerActivated")

	dbg("OnPlayerActivated: Hooking gamepad inventory slot action discovery")
	SecurePostHook(_G, "ZO_InventorySlot_DiscoverSlotActionsFromActionList", InventorySlotActionHook)

	-- Register scene state change callbacks once to ensure keybind is removed when inventory closes
	local function RegisterSceneHideRemoval(sceneName)
		if not SCENE_MANAGER then return end
		local scene = SCENE_MANAGER:GetScene(sceneName)
		if scene and not scene.momrWaypointHooked then
			scene:RegisterCallback("StateChange", function(_, newState) if newState == SCENE_HIDDEN then RemoveWaypointKeybind() end end)
			scene.momrWaypointHooked = true
		end
	end
	RegisterSceneHideRemoval("inventory") -- keyboard inventory scene
	RegisterSceneHideRemoval("gamepad_inventory_root") -- gamepad inventory root scene

	lastBackpackMapId = nil
	cachedBackpackItems = nil

	dbg("OnPlayerActivated: Indexing backpack")
	IndexBackpack()
	lastRefreshedMapId = nil

	dbg("OnPlayerActivated: Refreshing pins " .. PIN_TYPE)
	MapPins:RefreshPins(PIN_TYPE)

	dbg("OnPlayerActivated: Printing zone item counts")
	PrintZoneItemCounts()

	dbg("OnPlayerActivated: Unregistering PLAYER_ACTIVATED")
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)
end

--------------------------------------------------------------------
-- 3.  Callbacks
--------------------------------------------------------------------
local function AddPins()
	-- do not create pins on world, alliance and cosmic maps
	if (GetMapType() > MAPTYPE_ZONE) then
		dbg("Not creating pins on world, alliance and cosmic maps")
		return
	end

	local mapId = GetCurrentMapId()
	-- Mark this map as refreshed early so a near-simultaneous OnWorldMapChanged callback
	-- does not immediately trigger a second MapPins:RefreshPins for the same map.
	if lastRefreshedMapId ~= mapId then
		lastRefreshedMapId = mapId
		-- (debug) indicate we recorded the refresh source
		dbg("AddPins: set lastRefreshedMapId to " .. mapId)
	end
	dbg("Adding pins for mapId " .. mapId)

	local treasure = MOMR.internal and MOMR.internal.treasure
	local pins = treasure and treasure.GetMapIdData(mapId)
	if not pins then
		dbg("No data for mapId " .. mapId)
		return
	end
	dbg("Loaded " .. #pins .. " pins")

	local counts = {
		survey = 0,
		treasure = 0
	}

	local sv = MOMR.savedVars
	if sv.backpackOnly then
		-- If nothing relevant is present at all, skip quickly without scanning the bag
		if next(presentItemIds) == nil then
			dbg("No relevant items in backpack; skipping pin scan")
			return
		end
	end
	-- Helper function to determine if a pin should be skipped
	local function ShouldSkipPin(pType, pinData, sv)
		if pType ~= MOMR_PIN_TYPE_TREASURE and pType ~= MOMR_PIN_TYPE_SURVEYS then
			return true
		elseif pType == MOMR_PIN_TYPE_TREASURE and not sv.showTreasure then
			return true
		elseif pType == MOMR_PIN_TYPE_SURVEYS and not sv.showSurveys then
			return true
		elseif sv.backpackOnly and pinData.itemId and not presentItemIds[pinData.itemId] then
			return true
		end
		return false
	end

	for _, pinData in ipairs(pins) do
		local pType = pinData.pinType
		if counts[pType] ~= nil then
			if ShouldSkipPin(pType, pinData, sv) then
				-- skip
			else
				-- quiet
				counts[pType] = counts[pType] + 1
				local x, y, itemId, tooltip = pinData.x, pinData.y, pinData.itemId, pinData.tooltip
				local pinTag = {
					itemId = itemId,
					x = x,
					y = y,
					pinType = pType,
					tooltip = tooltip
				}
				dbg(string.format("CreatePin type %s %s, (%s, %s), %s", pType, itemId, x, y, tostring(tooltip)))
				MapPins:CreatePin(PIN_TYPE, pinTag, x, y)
			end
		end
	end

	local total = counts.survey + counts.treasure
	if total == 0 then
		dbg("No pins for mapId " .. mapId)
	else
		dbg(string.format("Loaded %d surveys, %d treasure maps", counts.survey, counts.treasure))
	end
end

local function InitializeAddon()
	if addonInitialized then
		dbg('InitializeAddon: already initialized, skipping')
		return
	end
	addonInitialized = true

	-- Ensure embedded libraries are available
	local treasure = MOMR.internal and MOMR.internal.treasure
	if not MapPins or not (treasure and treasure.GetMapIdData) then
		dbg("InitializeAddon: embedded libraries missing.")
		return
	end

	-- Load saved variables
	MOMR.savedVars = ZO_SavedVars:NewAccountWide("MOMR_SavedVars", MOMR.variableVersion, nil, MOMR.defaults)

	if MOMR.CreateOptions then MOMR:CreateOptions() end

	dbg("InitializeAddon: Get pin texture function")
	local function GetPinTexture(pin)
		local tag = select(2, pin:GetPinTypeAndTag())
		return PIN_ICONS[tag.pinType] or PIN_ICONS.survey
	end

	dbg("InitializeAddon: Pin tooltip creator")
	local pinTooltipCreator = {
		tooltip = ZO_MAP_TOOLTIP_MODE.INFORMATION,
		creator = function(pin)
			local tag = select(2, pin:GetPinTypeAndTag())
			local text = tag.tooltip
			if not text then return end
			if IsInGamepadPreferredMode() then
				local InformationTooltip = ZO_MapLocationTooltip_Gamepad
				local baseSection = InformationTooltip.tooltip
				InformationTooltip:LayoutIconStringLine(baseSection, nil, text, baseSection:GetStyle("mapLocationTooltipContentName"))
			else
				InformationTooltip:ClearLines()
				InformationTooltip:AddLine(text)
			end
		end
	}

	dbg("InitializeAddon: Pin layout")
	local layout = {
		level = 50,
		size = MOMR.savedVars.pinSize,
		texture = GetPinTexture
	}

	dbg("InitializeAddon: Registering pin type")
	MapPins:AddPinType(PIN_TYPE, AddPins, nil, layout, pinTooltipCreator)

	dbg("InitializeAddon: Registering inventory events")
	local function OnInventoryUpdate(_, bagId, slotIndex)
		-- Update incremental index for the changed slot only
		OnSingleSlotChanged(slotIndex)
		backpackCacheValid = false
		lastBackpackMapId = nil
		cachedBackpackItems = nil
		if not refreshPending then
			refreshPending = true
			zo_callLater(function()
				refreshPending = false
				MapPins:RefreshPins(PIN_TYPE)
			end, 100)
		end
	end
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_INV", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventoryUpdate)
	EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "_INV", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)

	CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
		local mapId = GetCurrentMapId()
		dbg("OnWorldMapChanged: mapId " .. mapId)
		if mapId ~= lastRefreshedMapId or not backpackCacheValid then
			dbg("OnWorldMapChanged: Refreshing pins " .. PIN_TYPE)
			lastRefreshedMapId = mapId
			MapPins:RefreshPins(PIN_TYPE)
		end
	end)

	dbg("InitializeAddon: Registering PLAYER_ACTIVATED for gamepad inventory hook")
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

	-- Defer initial pin creation to PLAYER_ACTIVATED and/or first OnWorldMapChanged callback
end

local function OnAddOnLoaded(_, addonName)
	if addonName ~= ADDON_NAME then return end
	dbg('OnAddOnLoaded called for ' .. GetUnitName('player'))

	dbg('OnAddOnLoaded: Initializing addon')
	InitializeAddon()

	dbg('OnAddOnLoaded: Unregistering for EVENT_ADD_ON_LOADED')
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
end

SLASH_COMMANDS["/momr_debug"] = SwitchDebugMode
SLASH_COMMANDS["/momr_pingme"] = PrintPlayerCoordinates

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
