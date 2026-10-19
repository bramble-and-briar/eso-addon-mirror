
local PinController = Harvest.pinController
local CallbackManager = Harvest.callbackManager
local Events = Harvest.events

local MapPins = {}
Harvest:RegisterModule("mapPins", MapPins)

--[[
There are many modules that interact with pins: settings, filters, moving around, etc
This files keeps track of all the relevant settings/modes etc,
and then forwards that information to the MapPinController, which handles the actual
pin texture controls.
]]--

function MapPins:Initialize()
	-- coords of the last pin update for the "display only nearby pins" option
	self.lastViewedX = -10
	self.lastViewedY = -10
	self.filterProfile = Harvest.filterProfiles:GetMapProfile()
	
	-- register callbacks for events, that affect map pins
	-- creating/updating a node (after harvesting something) or deletion of a node (via debug tools)
	local callback = function(...) self:OnNodeChangedCallback(...) end
	CallbackManager:RegisterForEvent(Events.NODE_DELETED, callback)
	CallbackManager:RegisterForEvent(Events.NODE_UPDATED, callback)
	CallbackManager:RegisterForEvent(Events.NODE_ADDED, callback)
	CallbackManager:RegisterForEvent(Events.NODE_COMPASS_LINK_CHANGED, callback)
	-- when a map related setting is changed
	CallbackManager:RegisterForEvent(Events.SETTING_CHANGED, function(...) self:OnSettingsChanged(...) end)
	CallbackManager:RegisterForEvent(Events.FILTER_PROFILE_CHANGED, function(event, profile, pinTypeId, visible)
		if profile == self.filterProfile then
			self:RedrawPins()
		end
	end)
	
	CallbackManager:RegisterForEvent(Events.MAP_MODE_CHANGED, function(event, newMode)
		self:RefreshVisibleDistance()
	end)
	
	-- player switched map (left/right click)
	ZO_PreHook("ZO_WorldMap_UpdateMap", function() self:RedrawPins() end)
	
	self.resourcePinTypeIds = {}
	local emptyFunction = function() end
	for _, pinTypeId in ipairs(Harvest.PINTYPES) do
		-- only register the resource pins, not hidden resources like psijic portals
		if not Harvest.HIDDEN_PINTYPES[pinTypeId] then
			local layout = Harvest.GetMapPinLayout(pinTypeId)
			-- create the pin type for this resource
			PinController:RegisterPinType(pinTypeId, layout)
			table.insert(self.resourcePinTypeIds, pinTypeId)
		end
	end
	self:RefreshVisibleDistance()
	
	-- when the debug mode is enabled, this is the description of what happens if the player clicks on a pin.
	-- if a pin is clicked, the node is deleted.
	self.clickHandlers = {-- debugHandler = {
		{
			name = MapPins.nameFunction,
			callback = function(pinIndex, pinTypeId, controller)
				-- remove this callback if the debug mode is disabled
				if not Harvest.IsPinDeletionEnabled() or IsInGamepadPreferredMode() then
					return
				end
				-- otherwise request the node to be deleted
				local nodeId = controller:GetNodeId(pinIndex, pinTypeId)
				local mapCache = MapPins.mapCache
				local worldX = mapCache.worldX[nodeId]
				local worldY = mapCache.worldY[nodeId]
				local worldZ = mapCache.worldZ[nodeId]
				local mapMetaData = mapCache.mapMetaData
					
				CallbackManager:FireCallbacks(Events.NODE_DELETION_REQUEST, 
					mapMetaData, worldX, worldY, worldZ, pinTypeId)
				
			end,
			isActive = function() return Harvest.IsPinDeletionEnabled() and not IsInGamepadPreferredMode() end,
		}
	}
	PinController:SetClickHandlers(self.clickHandlers)
end

function MapPins:AddClickHandler(handler)
	assert(handler)
	local n = #self.clickHandlers
	for i = 1, n do
		self.clickHandlers[n - i + 2] = self.clickHandlers[n - i + 1]
	end
	self.clickHandlers[1] = handler
end

-- called whenever a resource is harvested (which adds a node or updates an already existing node)
-- or when a node is deleted by the debug tool
function MapPins:OnNodeChangedCallback(event, mapCache, nodeId)
	local nodeAdded = (event == Events.NODE_ADDED)
	local nodeUpdated = (event == Events.NODE_UPDATED or event == Events.NODE_COMPASS_LINK_CHANGED)
	local nodeDeleted = (event == Events.NODE_DELETED)
	
	-- when the heatmap is active, the map pins aren't used
	if Harvest.IsHeatmapActive() then
		return
	end
	
	local validMapMode = Harvest.AreMapPinsVisible() and not Harvest.mapMode:IsInMinimapMode()
	local validMinimapMode = Harvest.AreMinimapPinsVisible() and Harvest.mapMode:IsInMinimapMode()
	if not (validMapMode or validMinimapMode) then return end
	
	-- the node isn't on the currently displayed map
	if not (self.mapCache == mapCache) then
		return
	end
	
	if mapCache.mapMetaData.isBlacklisted then return end
	
	local pinTypeId = mapCache.pinTypeId[nodeId]
	assert(pinTypeId)
	-- if the node's pin type is visible, then we do not have to manipulate any pins
	if not self.filterProfile[pinTypeId] then
		return
	end
	
	-- refresh a single pin by removing and recreating it
	if not nodeAdded then
		--self:Info("remove single map pin")
		self:RemoveNode(nodeId, pinTypeId)
	end
	if not nodeDeleted then
		--self:Info("add single map pin")
		self:AddNode(nodeId, pinTypeId)
	end
end

function MapPins:RefreshVisibleDistance(newVisibleDistance)
	if not newVisibleDistance then
		newVisibleDistance = 0
		if Harvest.mapMode:IsInMinimapMode() or (Harvest.HasPinVisibleDistance() and Harvest.AreMapPinsVisible()) then
			-- check for AreMapPinsVisible, because when map pins are disabled, we have to refresh the pins
			-- when switching from mini to world map
			newVisibleDistance = Harvest.GetPinVisibleDistance()
		end
	end
	
	self.visibleDistance = newVisibleDistance
	self:RedrawPins()
	EVENT_MANAGER:UnregisterForUpdate("HarvestMap-VisibleRange")
	if newVisibleDistance > 0 then
		EVENT_MANAGER:RegisterForUpdate("HarvestMap-VisibleRange", 2500, MapPins.UpdateVisibleMapPins)
	end
end

function MapPins:RedrawPins(shouldRefreshLayout)
	self:Debug("Refresh of pins requested.")
	PinController:RemoveAllPins()
	if shouldRefreshLayout then
		PinController:RefreshLayout()
	end
	
	if Harvest.IsHeatmapActive() then
		self:Debug("pins could not be refreshed, heatmap is active" )
		return
	end
	
	local validMapMode = Harvest.AreMapPinsVisible() and not Harvest.mapMode:IsInMinimapMode()
	local validMinimapMode = Harvest.AreMinimapPinsVisible() and Harvest.mapMode:IsInMinimapMode()
	
	if not (validMapMode or validMinimapMode) then return end
	
	-- remove old cache and load the new one
	if self.mapCache then
		self.mapCache:UnregisterAccess(self)
	end
	
	local mapMetaData = Harvest.mapTools:GetViewedMapMetaData()
	self.currentMap = mapMetaData.map
	local newMapCache = Harvest.Data:GetMapCache(mapMetaData)
	local newMap = (self.mapCache ~= newMapCache)
	self.mapCache = newMapCache
	-- if no data is available for this map, abort.
	if not self.mapCache then
		if newMap then
			CallbackManager:FireCallbacks(Events.MAP_CHANGE)
		end
		return
	end
	self.mapCache:RegisterAccess(self)
	
	PinController:RemoveAllPins() -- called again because creation of new cache could have created new unknown pins
	PinController:SetMapCache(self.mapCache)
	self:DrawNodes()
	
	if newMap then
		CallbackManager:FireCallbacks(Events.MAP_CHANGE)
	end
end

-- called every few seconds to update the pins in the visible range
function MapPins.UpdateVisibleMapPins()
	local self = Harvest.mapPins
	
	if Harvest.IsHeatmapActive() then return end
	if self.mapCache == nil then return end
	
	local validMapMode = Harvest.AreMapPinsVisible() and not Harvest.mapMode:IsInMinimapMode()
	local validMinimapMode = Harvest.AreMinimapPinsVisible() and Harvest.mapMode:IsInMinimapMode()
	if not (validMapMode or validMinimapMode) then return end
	if Harvest.IsHeatmapActive() then return end
	
	local x, y = Harvest.GetPlayer3DPosition()
	local dx = self.lastViewedX - x
	local dy = self.lastViewedY - y
	if dx * dx + dy * dy < 10 * 10 then return end
	
	self.lastViewedX = x
	self.lastViewedY = y
	
	PinController:RemoveAllPins()
	self:DrawNodes()
end

function MapPins:IsActiveMap(map)
	if not self.mapCache then return false end
	return (self.mapCache.map == map)
end

local drawnode = function(mapCache, pinTypeId, nodeId)
	PinController:CreatePinForNodeId(pinTypeId, nodeId)
end

function MapPins:DrawNodes()
	local PinController = PinController
	
	-- get spawn filter settings
	local showOnlySpawnedNodes = Harvest.IsMapSpawnFilterEnabled()
	local spawnFilterForPinType = Harvest.settings.savedVars.settings.isSpawnFilterUsedForPinType
	if Harvest.mapMode:IsInMinimapMode() then
		showOnlySpawnedNodes = Harvest.IsMinimapSpawnFilterEnabled()
	end
	
	-- todo, incorporate self.visibleDistance, self.lastViewedX etc
	local mapCache = self.mapCache
	if self.visibleDistance > 0 then
		-- draw only nearby nodes
		for _, pinTypeId in ipairs(Harvest.PINTYPES) do
			if self.filterProfile[pinTypeId] then
				-- draw all nodes that are not filtered
				if not(showOnlySpawnedNodes and spawnFilterForPinType[pinTypeId] and Harvest.HARVEST_NODES[pinTypeId]) then
					mapCache:ForAllNodesInDivisionRange(self.lastViewedX, self.lastViewedY, self.visibleDistance, pinTypeId, drawnode)
				end
			end
		end
		local pinTypeId
		if showOnlySpawnedNodes then
			-- draw nodes that have spawn filter active
			for nodeId, _ in pairs(mapCache.hasCompassPin) do
				pinTypeId = mapCache.pinTypeId[nodeId]
				if self.filterProfile[pinTypeId] and spawnFilterForPinType[pinTypeId] and Harvest.HARVEST_NODES[pinTypeId] then
					PinController:CreatePinForNodeId(pinTypeId, nodeId)
				end
			end
		end
	else
		-- draw all nodes
		for _, pinTypeId in ipairs(Harvest.PINTYPES) do
			if not Harvest.HIDDEN_PINTYPES[pinTypeId] then
				if self.filterProfile[pinTypeId] then
					--firstOfPinType = mapCache.nodesOfPinTypeStart[pinTypeId]
					--lastOfPinType = mapCache.nodesOfPinTypeEnd[pinTypeId]
					if showOnlySpawnedNodes and spawnFilterForPinType[pinTypeId] and Harvest.HARVEST_NODES[pinTypeId] then
						-- if spawn filter is used for this pin type, check if resource is spawned
						for _, nodeId in pairs(mapCache.nodesOfPinType[pinTypeId]) do
							if mapCache.hasCompassPin[nodeId] then
								PinController:CreatePinForNodeId(pinTypeId, nodeId)
							end
						end
					else
						-- if spawn filter is no used, we can draw all pins directly
						for _, nodeId in pairs(mapCache.nodesOfPinType[pinTypeId]) do
							PinController:CreatePinForNodeId(pinTypeId, nodeId)
						end
					end
				end
			end
		end
	end
end

function MapPins:AddNode(nodeId, pinTypeId)
	-- get spawn filter settings
	local showOnlySpawnedNodes = Harvest.IsMapSpawnFilterEnabled()
	local spawnFilterForPinType = Harvest.settings.savedVars.settings.isSpawnFilterUsedForPinType
	if Harvest.mapMode:IsInMinimapMode() then
		showOnlySpawnedNodes = Harvest.IsMinimapSpawnFilterEnabled()
	end
	
	-- if we should filter by spawn and resource is not spawned, then break
	if showOnlySpawnedNodes and spawnFilterForPinType[pinTypeId] and Harvest.HARVEST_NODES[pinTypeId] and not self.mapCache.hasCompassPin[nodeId] then
		return
	end
	-- otherwise, add the new pin
	PinController:CreatePinForNodeId(pinTypeId, nodeId)
end

function MapPins:RemoveNode(nodeId, pinTypeId)
	PinController:RemovePinForNodeId(pinTypeId, nodeId)
end


-- these settings are handled by simply refreshing the map pins.
local redrawOnSetting = {
	--hasVisibleDistance = true,
	--visibleDistance = true,
	heatmapActive = true,
	mapPinsVisible = true,
	minimapPinsVisible = true,
	mapPinTypeVisible = true,
	mapSpawnFilter = true,
	minimapSpawnFilter = true,
}
local refreshOnSetting = {
	pinTypeSize = true,
	mapPinTexture = true,
	pinTypeColor = true,
	pinAbovePoi = true,
}
function MapPins:OnSettingsChanged(event, setting, ...)
	if redrawOnSetting[setting] then
		self:RedrawPins()
	elseif refreshOnSetting[setting] then
		local shouldRefreshLayout = true
		self:RedrawPins(shouldRefreshLayout)
	elseif setting == "hasVisibleDistance" or setting == "visibleDistance" then
		self:RefreshVisibleDistance()
	elseif setting == "mapFilterProfile" then
		self.filterProfile = Harvest.filterProfiles:GetMapProfile()
		self:RedrawPins()
		if Harvest.IsHeatmapActive() then
			HarvestHeat.RefreshHeatmap()
		end
	elseif setting == "cacheCleared" then
		local map = ...
		if map == self.currentMap or not map then
			self:RedrawPins()
		end
	end
end
