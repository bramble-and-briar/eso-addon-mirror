
local PinController = {}
Harvest:RegisterModule("pinController", PinController)

--[[
This file handles creation and maintenance of texture controls, i.e., map pins.
It also handles compatibility between different kind of maps, such as
main map or the various minimap addons
]]--


local MIN_PIN_SIZE = 8
local NO_MAP_MODE, MAIN_MAP_MODE, VOTAN_MODE, FYR_MODE, AUI_MODE, LUIE_MODE

local PinTypeManager = ZO_Object:Subclass()

function PinController:Initialize()
	
	self.MAP_WIDTH = 0
	self.MAP_HEIGHT = 0
	self.pinTypeManagers = {}
	
	self.scroll = CreateControl("QP_Scroll" , ZO_WorldMap, CT_SCROLL)
	self.scroll:SetAnchor(TOPLEFT, ZO_WorldMapScroll, TOPLEFT, 0, 0)
	self.scroll:SetAnchor(BOTTOMRIGHT, ZO_WorldMapScroll, BOTTOMRIGHT, 0, 0)
	
	self.container = CreateControl("QP_Container" , self.scroll, CT_CONTROL)
	self.container:SetAnchor(TOPLEFT, ZO_WorldMapContainer, TOPLEFT, 0, 0)
	
	self.zoom = ZO_WorldMap_GetPanAndZoom()
	PinController.minZoom, PinController.maxZoom = self.zoom.minZoom, self.zoom.maxZoom
		
	ZO_PreHook(ZO_WorldMapPins_Manager, "UpdatePinsForMapSizeChange", function() 
		PinController:CheckMapMode()
		PinController:OnMapSizeChange(ZO_WorldMapContainer:GetDimensions()) 
	end)
	ZO_PreHook(PinController.zoom, "SetZoomMinMax", function(self, min, max)
		PinController.minZoom = min
		PinController.maxZoom = max
		PinController:CheckMapMode()
		PinController:OnMapSizeChange(ZO_WorldMapContainer:GetDimensions())
	end)
	
	WORLD_MAP_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_FRAGMENT_HIDDEN then
			self:CheckMapMode()
			local width, height = self.activeMode:GetDimensions()
			if self.MAP_WIDTH ~= width or self.MAP_HEIGHT ~= height then
				PinController:OnMapSizeChange(width, height)
			end
		end
	end)
	
	self:InitializeFyr()
	self:InitializeAUI()
	self:InitializeLUIE()
	
	ZO_PreHook("ZO_WorldMap_MouseEnter", function() 
	
		-- dont do anything if no handler cares about clicks
		local hasAnyActiveHandlers = false
		for i, handler in ipairs(self.onClickHandlers) do
			if (not handler.isActive) or handler.isActive() then
				hasAnyActiveHandlers = true
			end
		end 
		if not hasAnyActiveHandlers then return end
		
		-- check 20/second if mouse is over a pin
		EVENT_MANAGER:RegisterForUpdate("HarvestMap-MouseOver", 50, function()
			local pinIndex, pinTypeId = self:GetMouseOverPinIndexAndType()
			if not pinIndex then return end
			self:ShowSelectionControl(pinIndex, pinTypeId)
		end)
	end)
	
	ZO_PreHook("ZO_WorldMap_MouseExit", function()
		EVENT_MANAGER:UnregisterForUpdate("HarvestMap-MouseOver")
		--self:ExitPin()
	end)
	
	self.mouseOverPin = CreateControl("HM-mouseover", self.container, CT_TEXTURE)
	self.mouseOverPin:SetHidden(true)
	self.mouseOverPin:SetDrawTier(DT_HIGH)
	self.mouseOverPin:SetHandler("OnMouseEnter",  function() 
		self.mouseOverPin:SetScale(1.3) 
	end)
	self.mouseOverPin:SetHandler("OnMouseExit",  function() 
		self.mouseOverPin:SetScale(1)
		self.mouseOverPin:SetHidden(true)
		self.mouseOverPin:SetMouseEnabled(false)
	end)
	self.mouseOverPin:SetHandler("OnMouseUp", function(control, button)
		if button ~= MOUSE_BUTTON_INDEX_LEFT then
			return
		end
		
		local pinIndex, pinTypeId = self:GetMouseOverPinIndexAndType()
		if not pinIndex then return end
		
		--self.pinTypeManagers[pinTypeId].composite:SetColor(pinIndex, 1,1,1,1)
		for i, handler in ipairs(self.onClickHandlers) do
			if (not handler.isActive) or handler.isActive() then
				if (not handler.show) or handler.show(pinIndex, pinTypeId, self) then
					handler.callback(pinIndex, pinTypeId, self)
					return
				end
			end
		end 
	end)
	self.mouseOverPin:SetPixelRoundingEnabled(false)
end

function PinController:SetClickHandlers(handlers)
	self.onClickHandlers = handlers
end

function PinController:GetNodeId(pinIndex, pinTypeId)
	return self.pinTypeManagers[pinTypeId].nodeId[pinIndex]
end

function PinController:ShowSelectionControl(pinIndex, pinTypeId)
	local composite = self.pinTypeManagers[pinTypeId].composite
	local x, _, y, _ = composite:GetInsets(pinIndex)
	self.mouseOverPin:SetAnchor(CENTER, self.container, TOPLEFT, x, y)
	self.mouseOverPin:SetDimensions(composite:GetDimensions())
	local inset = self.mouseOverPin:GetWidth() * 0.25
	self.mouseOverPin:SetHitInsets(inset, inset, -inset, -inset)
	self.mouseOverPin:SetHidden(false)
	self.mouseOverPin:SetTexture(composite:GetTextureFileName())
	self.mouseOverPin:SetColor(composite:GetColor(pinIndex))
	self.mouseOverPin:SetDrawLevel(composite:GetDrawLevel() + 1)
	self.mouseOverPin:SetMouseEnabled(true)
	self.mouseOverPin.pinTypeId = pinTypeId
	self.mouseOverPin.pinIndex = pinIndex
end

function PinController:GetMouseOverPinIndexAndType()
	local x, y = GetUIMousePosition()
	x = x - ZO_WorldMapContainer:GetLeft()
	y = y - ZO_WorldMapContainer:GetTop()
	local minPinDistance = math.huge
	local minPinTypeId, minPinIndex
	for pinTypeId, pinTypeManager in pairs(self.pinTypeManagers) do
		local pinIndex, pinDist = pinTypeManager:GetMouseOverPinAndDistance(x, y)
		if pinDist then
			if pinDist < minPinDistance then
				minPinDistance = pinDist
				minPinTypeId = pinTypeId
				minPinIndex = pinIndex
			end
		end
	end
	return minPinIndex, minPinTypeId
end

function PinController:SetMouseEnabled(isEnabled)
	self.isMouseEnabled = isEnabled
end

function PinController:IsMouseEnabled()
	return self.isMouseEnabled
end

function PinController:InitializeFyr()
	if not Fyr_MM then return end
	self:HookMinimap(Fyr_MM_Scroll_Map)
	
	local orig = FyrMM.UpdateMapTiles
	function FyrMM.UpdateMapTiles(...)
		orig(...)
		if self.activeMode == FYR_MODE and FyrMM.SV.RotateMap and FyrMM.currentMap.Heading then
			
			FYR_MODE.cos = math.cos(-FyrMM.currentMap.Heading)
			FYR_MODE.sin = math.sin(-FyrMM.currentMap.Heading)
			FYR_MODE.offsetX = FyrMM.currentMap.PlayerX
			FYR_MODE.offsetY = FyrMM.currentMap.PlayerY
			--[[
			for pinType, pinManager in pairs(self.pinTypeManagers) do
				local pins = pinManager:GetActiveObjects()
				for pinKey, pin in pairs(pins) do
					pin:UpdateLocation()
				end
			end
			]]
		end
	end
end


function PinController:InitializeAUI()
	if not (AUI and AUI.Minimap) then return end
	self:HookMinimap(AUI_MapContainer)
	
	ZO_PreHook(AUI.Minimap.Pin, "UpdateAllLocations", function()
		if self.activeMode == AUI_MODE and AUI.Settings.Minimap.rotate then
			AUI_MODE.cos = math.cos(-AUI.MapData.heading)
			AUI_MODE.sin = math.sin(-AUI.MapData.heading)
			AUI_MODE.offsetX = AUI.MapData.mapContainerSize * AUI.MapData.playerX
			AUI_MODE.offsetY = AUI.MapData.mapContainerSize * AUI.MapData.playerY
			
			for pinTypeId, pinManager in pairs(self.pinTypeManagers) do
				for pinIndex, nodeId in pairs(pinManager.nodeId) do
					pinManager:UpdateLocationOfPinWithIndex(pinIndex)
				end
			end
		end
	end)
end

function PinController:InitializeLUIE()
	if self.luieMinimapHooked then return end
	if not LUIE or not LUIE.MiniMap or not LUIE.MiniMap.MAP_MODE_LUIE_MINIMAP then return end
	if not LUIE_MiniMap_Scroll_Map or not LUIE_MiniMap_Scroll_Map_Pins then return end
	self:HookMinimap(LUIE_MiniMap_Scroll_Map)
	self.luieMinimapHooked = true
end


function PinController:SetMode(mode)
	assert(mode)
	local previousMode = self.activeMode
	self.activeMode = mode
	if self.activeMode ~= previousMode then
		self.activeMode:Activate()
	end
end

function PinController:CheckMapMode()
	local mode = MAIN_MAP_MODE
	if not ZO_WorldMap_IsWorldMapShowing() then -- minimap
		mode = NO_MAP_MODE
		if FyrMM then
			mode = FYR_MODE
		end
		if (AUI and AUI.Minimap:IsEnabled()) then
			mode = AUI_MODE
		end
		if VOTANS_MINIMAP then
			mode = VOTAN_MODE
		end
		if LUIE and LUIE.MiniMap and LUIE.MiniMap.Enabled and LUIE.MiniMap.MAP_MODE_LUIE_MINIMAP and LUIE_MiniMap_Scroll_Map_Pins then
			self:InitializeLUIE()
			mode = LUIE_MODE
		end

	end
	self:SetMode(mode)
end

function PinController:OnMapSizeChange(width, height)
	assert(width and height)
	self.MAP_WIDTH = width
	self.MAP_HEIGHT = height
	self:CheckMapMode()
	
	for pinTypeId, pinManager in pairs(self.pinTypeManagers) do
		pinManager:UpdateSize()
		for pinIndex, nodeId in pairs(pinManager.nodeId) do
			pinManager:UpdateLocationOfPinWithIndex(pinIndex)
		end
	end
	
	if not self.mouseOverPin:IsHidden() then
		local composite = self.pinTypeManagers[self.mouseOverPin.pinTypeId].composite
		local x, _, y, _ = composite:GetInsets(self.mouseOverPin.pinIndex)
		self.mouseOverPin:SetAnchor(CENTER, self.container, TOPLEFT, x, y)
	end
end

function PinController:RemoveAllPins()
	for pinTypeId, pinTypeManager in pairs(self.pinTypeManagers) do
		pinTypeManager:RemoveAllPins()
	end
end

function PinController:RefreshLayout()
	for pinTypeId, pinTypeManager in pairs(self.pinTypeManagers) do
		pinTypeManager:RefreshLayout()
	end
end

function PinController:RegisterPinType(pinTypeId, layout)
	local pinTypeManager = PinTypeManager:New(layout, pinTypeId)
	self.pinTypeManagers[pinTypeId] = pinTypeManager
end

function PinController:CreatePinForNodeId(pinTypeId, nodeId)
	self.pinTypeManagers[pinTypeId]:GetNewPinForNodeId(nodeId)
end

function PinController:SetMapCache(mapCache)
	for pinTypeId, pinTypeManager in pairs(self.pinTypeManagers) do
		pinTypeManager:SetMapCache(mapCache)
	end
end

function PinController:RemovePinForNodeId(pinTypeId, nodeId)
	self.pinTypeManagers[pinTypeId]:RemovePinForNodeId(nodeId)
end
-- same syntax as LMP
PinController.RemoveCustomPin = PinController.RemovePin
PinController.FindCustomPin = function() end



function PinController:HookMinimap(minimapContainer)
			
	local oldDimensions = minimapContainer.SetDimensions
	minimapContainer.SetDimensions = function(self, width, height, ...)
		if not ZO_WorldMap_IsWorldMapShowing() then
			PinController:OnMapSizeChange(width, height) 
		end
		oldDimensions(self, width, height, ...)
	end
	
end








PinTypeManager.lastPinId = 0

function PinTypeManager:New(...)
	local obj = ZO_Object.New(self)
	obj:Initialize(...)
	return obj
end

function PinTypeManager:Initialize(layout, pinTypeId)
	self.layout = layout
	self.pinTypeId = pinTypeId
	self.nodeId = {}
	self.lastUnusedIndex = 0
	
	local composite = PinController.container:CreateControl(nil, CT_TEXTURECOMPOSITE)
	composite:SetDrawTier(2)
	composite:SetAnchor(CENTER, PinController.container, TOPLEFT, 0, 0)
	composite:SetPixelRoundingEnabled(false)
	--composite:SetInheritScale(false)
	--composite:SetDimensions(20,20)
	self.composite = composite
	self:RefreshLayout()
end

function PinTypeManager:RefreshLayout()
	local layout = self.layout
	self.composite:SetDrawLevel(zo_max(layout.level, 1))
	self.composite:SetTexture(layout.texture)
	
	self:UpdateSize()
	for pinIndex, nodeId in pairs(self.nodeId) do
		self:RefreshLayoutOfPin(pinIndex)
	end
end

function PinTypeManager:RefreshLayoutOfPin(pinIndex)
	local layout = self.layout
	if(layout.tint) then
		self.composite:SetColor(pinIndex, layout.tint:UnpackRGB())
	else
		self.composite:SetColor(pinIndex, 1, 1, 1, 1)
	end
	self:UpdateLocationOfPinWithIndex(pinIndex)
end

function PinTypeManager:UpdateLocationOfPinWithIndex(pinIndex)
	local x, y = self.mapCache:GetLocal(self.nodeId[pinIndex])
	self.composite:SetInsets(pinIndex, x * PinController.MAP_WIDTH, x * PinController.MAP_WIDTH, y * PinController.MAP_WIDTH, y * PinController.MAP_WIDTH)
end
local OriginalUpdateLocation = PinTypeManager.UpdateLocationOfPinWithIndex

function PinTypeManager:UpdateSize()
    local layout = self.layout
    local size = layout.size / GetUICustomScale()
    --Scale map pins at Votans Minimap depending on the MiniMap scaling
    if VOTANS_MINIMAP and VOTANS_MINIMAP.scale and WORLD_MAP_MANAGER:IsInMode(MAP_MODE_VOTANS_MINIMAP) then
        size = size * VOTANS_MINIMAP:CalculateScale("Others")
	elseif FyrMM and not ZO_WorldMap_IsWorldMapShowing() then
		size = size * FyrMM.pScalePercent
    end
    layout.currentPinSize = size
	--d(size)
	self.composite:SetDimensions(size, size)
end

function PinTypeManager:GetMouseOverPinAndDistance(x, y)
	local zo_abs = zo_abs
	local zo_max = zo_max
	local size = self.layout.currentPinSize
	local minDist = math.huge
	local minPinIndex = nil
	local dist = 0
	for i = 1, self.composite:GetNumSurfaces() do
		local pinX, _, pinY, _ = self.composite:GetInsets(i)
		dist = (x - pinX)*(x - pinX) + (y - pinY)*(y - pinY)
		if dist < minDist then
			minDist = dist
			minPinIndex = i
		end
	end
	if minDist < (size/2)*(size/2) then
		return minPinIndex, minDist
	end
end

function PinTypeManager:RemoveAllPins()
	self.composite:ClearAllSurfaces()
	ZO_ClearTable(self.nodeId)
end

function PinTypeManager:RemovePinForNodeId(nodeId)
	for pinIndex, pinNodeId in pairs(self.nodeId) do
		if nodeId == pinNodeId then
			local lastIndex = self.composite:GetNumSurfaces()
			self.nodeId[pinIndex] = self.nodeId[lastIndex]
			self.nodeId[lastIndex] = nil
			self.composite:RemoveSurface(lastIndex)
			if lastIndex ~= pinIndex then
				self:UpdateLocationOfPinWithIndex(pinIndex)
			end
			break
		end
	end
end

function PinTypeManager:SetMapCache(mapCache)
	assert(self.composite:GetNumSurfaces() == 0, "still displaying pins of previous cache!")
	if self.mapCache then
		self.mapCache:UnregisterAccess(self)
	end
	self.mapCache = mapCache
	if self.mapCache then
		self.mapCache:RegisterAccess(self)
	end
end

local WINDOW_MANAGER = GetWindowManager()
function PinTypeManager:GetNewPinForNodeId(nodeId)
	self.composite:AddSurface(0,1,0,1)
	local pinIndex = self.composite:GetNumSurfaces()
	self.nodeId[pinIndex] = nodeId
	self:RefreshLayoutOfPin(pinIndex)
end

MAIN_MAP_MODE = {
	Activate = function(self)
		PinController.container:ClearAnchors()
		PinController.container:SetAnchor(TOPLEFT, ZO_WorldMapContainer, TOPLEFT, 0, 0)
		PinController.container:SetParent(ZO_WorldMapContainer)
		PinTypeManager.UpdateLocationOfPinWithIndex = OriginalUpdateLocation
	end,
	GetDimensions = function(self)
		return ZO_WorldMapContainer:GetDimensions()
	end,
}
NO_MAP_MODE = {
	Activate = function(self) end,
	GetDimensions = function(self)
		return ZO_WorldMapContainer:GetDimensions()
	end,
}
VOTAN_MODE = {
	Activate = function(self)
		PinController.container:SetAnchor(TOPLEFT, ZO_WorldMapContainer, TOPLEFT, 0, 0)
		PinController.container:SetParent(ZO_WorldMapContainer)
	end,
	GetDimensions = function(self)
		return ZO_WorldMapContainer:GetDimensions()
	end,
}
FYR_MODE = {
	Activate = function(self)
		if FyrMM.SV.WheelMap then
			PinController.container:SetParent(PinController.scroll)
			PinController.scroll:SetParent(Fyr_MM_Scroll_CW_Map_Pins)
			PinController.scroll:SetAnchor(TOPLEFT, Fyr_MM_Scroll_WheelCenter, TOPLEFT, 0, 0)
			PinController.scroll:SetAnchor(BOTTOMRIGHT, Fyr_MM_Scroll_WheelCenter, BOTTOMRIGHT, 0, 0)
		else
			PinController.container:SetParent(Fyr_MM_Scroll_Map)
		end
		if FyrMM.SV.RotateMap then
			PinController.container:ClearAnchors()
			PinController.container:SetAnchor(CENTER, Fyr_MM_Scroll, CENTER, 0, 0)
			PinTypeManager.UpdateLocationOfPinWithIndex = self.UpdateLocationOfPinWithIndex
			if FyrMM.currentMap.Heading then
				FYR_MODE.cos = math.cos(-FyrMM.currentMap.Heading)
				FYR_MODE.sin = math.sin(-FyrMM.currentMap.Heading)
				FYR_MODE.offsetX = FyrMM.currentMap.PlayerX
				FYR_MODE.offsetY = FyrMM.currentMap.PlayerY
			else
				FYR_MODE.cos = 0
				FYR_MODE.sin = 0
				FYR_MODE.offsetX = 0
				FYR_MODE.offsetY = 0
			end
		else
			PinController.container:ClearAnchors()
			PinController.container:SetAnchor(TOPLEFT, Fyr_MM_Scroll_Map, TOPLEFT, 0, 0)
			PinTypeManager.UpdateLocationOfPinWithIndex = OriginalUpdateLocation
		end
	end,
	GetDimensions = function(self)
		return Fyr_MM_Scroll_Map:GetDimensions()
	end,
	UpdateLocationOfPinWithIndex = function(self, pinIndex)
		local x, y = self.mapCache:GetLocal(self.nodeId[pinIndex])
		x = x * PinController.MAP_WIDTH - FYR_MODE.offsetX
		y = y * PinController.MAP_WIDTH - FYR_MODE.offsetY
		local rotatedX = FYR_MODE.cos * x - FYR_MODE.sin * y
		local rotatedY = FYR_MODE.sin * x + FYR_MODE.cos * y
		self.composite:SetInsets(pinIndex, rotatedX, rotatedX, rotatedY, rotatedY)
	end,
}
AUI_MODE = {
	Activate = function(self)
		PinController.container:SetParent(AUI_MapContainer)
		if AUI.Settings.Minimap.rotate then
			PinController.container:ClearAnchors()
			PinController.container:SetAnchor(CENTER, AUI_Minimap_Map_Scroll, CENTER, 0, 0)
			PinTypeManager.UpdateLocationOfPinWithIndex = self.UpdateLocationOfPinWithIndex
			if AUI.MapData.heading then
				AUI_MODE.cos = math.cos(-AUI.MapData.heading)
				AUI_MODE.sin = math.sin(-AUI.MapData.heading)
				AUI_MODE.offsetX = AUI.MapData.mapContainerSize * AUI.MapData.playerX
				AUI_MODE.offsetY = AUI.MapData.mapContainerSize * AUI.MapData.playerY
			else
				AUI_MODE.cos = 0
				AUI_MODE.sin = 0
				AUI_MODE.offsetX = 0
				AUI_MODE.offsetY = 0
			end
		else
			PinController.container:ClearAnchors()
			PinController.container:SetAnchor(TOPLEFT, AUI_MapContainer, TOPLEFT, 0, 0)
			PinTypeManager.UpdateLocationOfPinWithIndex = OriginalUpdateLocation
		end
		
	end,
	GetDimensions = function(self)
		return AUI_MapContainer:GetDimensions()
	end,
	UpdateLocationOfPinWithIndex = function(self, pinIndex)
		local x, y = self.mapCache:GetLocal(self.nodeId[pinIndex])
		x = x * PinController.MAP_WIDTH - AUI_MODE.offsetX
		y = y * PinController.MAP_WIDTH - AUI_MODE.offsetY
		local rotatedX = AUI_MODE.cos * x - AUI_MODE.sin * y
		local rotatedY = AUI_MODE.sin * x + AUI_MODE.cos * y
		self.composite:SetInsets(pinIndex, rotatedX, rotatedX, rotatedY, rotatedY)
	end,
}
LUIE_MODE = {
	Activate = function(self)
		PinController.container:ClearAnchors()
		PinController.container:SetParent(LUIE_MiniMap_Scroll_Map_Pins)
		PinController.container:SetAnchor(TOPLEFT, LUIE_MiniMap_Scroll_Map_Pins, TOPLEFT, 0, 0)
		PinTypeManager.UpdateLocationOfPinWithIndex = OriginalUpdateLocation
	end,
	GetDimensions = function(self)
		if LUIE_MiniMap_Scroll_Map then
			local width, height = LUIE_MiniMap_Scroll_Map:GetDimensions()
			if width > 0 and height > 0 then
				return width, height
			end
		end
		return ZO_WorldMapContainer:GetDimensions()
	end,
}
