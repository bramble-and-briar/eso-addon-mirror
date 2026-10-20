
local PinController = {}
LoreLibrary:RegisterModule("pinController", PinController)

--[[
This file handles creation and maintenance of texture controls, i.e., map pins.
It also handles compatibility between different kind of maps, such as
main map or the various minimap addons.
Adapted from HarvestMap Console's Pins/MapPinController.lua.

The map can show pins from more than one ZoneCache at once (the viewed map's
zone and the player's zone - see MapPins.lua), so each pin type gets one
PinTypeManager (and one composite control) per "cache slot" instead of just
one. A cache slot is an arbitrary caller-chosen key (MapPins.lua uses
"viewed"/"player") identifying which ZoneCache a PinTypeManager is currently
bound to; PinController itself doesn't care what the key means.
self.pinTypeManagers is therefore keyed [pinTypeId][cacheSlot].
]]--

local NO_MAP_MODE, MAIN_MAP_MODE, VOTAN_MODE, FYR_MODE, AUI_MODE, LUIE_MODE

local PinTypeManager = ZO_Object:Subclass()

function PinController:Initialize()

	self.MAP_WIDTH = 0
	self.MAP_HEIGHT = 0
	self.pinTypeManagers = {}

	self.scroll = CreateControl("LL_Scroll", ZO_WorldMap, CT_SCROLL)
	self.scroll:SetAnchor(TOPLEFT, ZO_WorldMapScroll, TOPLEFT, 0, 0)
	self.scroll:SetAnchor(BOTTOMRIGHT, ZO_WorldMapScroll, BOTTOMRIGHT, 0, 0)

	self.container = CreateControl("LL_Container", self.scroll, CT_CONTROL)
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


	self:InitializeMouseHandling()
	--self:InitializeGamepadMagnetism()
end

--[[
Calls func(self, pinTypeId, cacheSlot, pinTypeManager, ...) for every
registered PinTypeManager, forwarding any extra arguments given here.

func must be a predefined (module-level local) function, never an anonymous
function created at the call site: some callers (the mouse-hover poll, the
AUI minimap hook) run this every frame or several times a second, and a
`function(...) ... end` literal at the call site allocates a brand new
closure on every single call. Passing state through as extra arguments (or,
where a running "best match" needs to be accumulated across iterations,
through fields on self) avoids that allocation entirely.
]]--
function PinController:ForEachPinTypeManager(func, ...)
	for pinTypeId, managers in pairs(self.pinTypeManagers) do
		for cacheSlot, pinTypeManager in pairs(managers) do
			func(self, pinTypeId, cacheSlot, pinTypeManager, ...)
		end
	end
end

function PinController:InitializeMouseHandling()
	self.onClickHandlers = {}
	self.mouseOverPin = CreateControl("LL-mouseover", self.container, CT_TEXTURE)
	self.mouseOverPin:SetHidden(true)
	self.mouseOverPin:SetDrawTier(DT_HIGH)
	self.mouseOverPin:SetPixelRoundingEnabled(false)

	if ZO_IsConsoleOrGameCoreUI() then return end

	ZO_PreHook("ZO_WorldMap_MouseEnter", function()

		-- check 20/second if mouse is over a pin
		EVENT_MANAGER:RegisterForUpdate("LoreLibrary-MouseOver", 50, function()
			local pinIndex, pinTypeId, cacheSlot = self:GetMouseOverPinIndexAndType()
			if not pinIndex then return end
			self:ShowSelectionControl(pinIndex, pinTypeId, cacheSlot)
		end)
	end)

	ZO_PreHook("ZO_WorldMap_MouseExit", function()
		EVENT_MANAGER:UnregisterForUpdate("LoreLibrary-MouseOver")
	end)

	self.mouseOverPin:SetHandler("OnMouseEnter", function()
		self.mouseOverPin:SetScale(1.3)
		local title = self:GetBookTitle(self.mouseOverPin.pinTypeId, self.mouseOverPin.cacheSlot, self.mouseOverPin.pinIndex)
		if title then
			ZO_Tooltips_ShowTextTooltip(self.mouseOverPin, TOP, title)
		end
	end)
	self.mouseOverPin:SetHandler("OnMouseExit", function()
		self.mouseOverPin:SetScale(1)
		self.mouseOverPin:SetHidden(true)
		self.mouseOverPin:SetMouseEnabled(false)
		ZO_Tooltips_HideTextTooltip()
	end)
	self.mouseOverPin:SetHandler("OnMouseUp", function(control, button)
		if button ~= MOUSE_BUTTON_INDEX_LEFT then
			return
		end

		local pinIndex, pinTypeId, cacheSlot = self:GetMouseOverPinIndexAndType()
		if not pinIndex then return end

		for i, handler in ipairs(self.onClickHandlers) do
			if (not handler.isActive) or handler.isActive() then
				if (not handler.show) or handler.show(pinIndex, pinTypeId, cacheSlot, self) then
					handler.callback(pinIndex, pinTypeId, cacheSlot, self)
					return
				end
			end
		end
	end)
end

function PinController:SetClickHandlers(handlers)
	self.onClickHandlers = handlers
end

-- returns the title of the book drawn at pinIndex within the (pinTypeId, cacheSlot) pin type manager, or nil if it can't be resolved
function PinController:GetBookTitle(pinTypeId, cacheSlot, pinIndex)
	local pinTypeManager = self.pinTypeManagers[pinTypeId][cacheSlot]
	local zoneCache = pinTypeManager.zoneCache
	local bookId = zoneCache and zoneCache.bookId[pinTypeManager.nodeId[pinIndex]]
	if not bookId then return nil end
	return LoreLibrary.GetBookTitle(bookId)
end

function PinController:ShowSelectionControl(pinIndex, pinTypeId, cacheSlot)
	local composite = self.pinTypeManagers[pinTypeId][cacheSlot].composite
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
	self.mouseOverPin.cacheSlot = cacheSlot
	self.mouseOverPin.pinIndex = pinIndex
end

-- accumulates the closest match so far into self.min* - see
-- PinController:ForEachPinTypeManager for why this isn't an inline closure
local function AccumulateClosestMouseOverPin(self, pinTypeId, cacheSlot, pinTypeManager, x, y)
	local pinIndex, pinDist = pinTypeManager:GetMouseOverPinAndDistance(x, y)
	if pinDist and pinDist < self.minPinDistance then
		self.minPinDistance = pinDist
		self.minPinTypeId = pinTypeId
		self.minCacheSlot = cacheSlot
		self.minPinIndex = pinIndex
	end
end

function PinController:GetMouseOverPinIndexAndType()
	local x, y = GetUIMousePosition()
	x = x - ZO_WorldMapContainer:GetLeft()
	y = y - ZO_WorldMapContainer:GetTop()
	self.minPinDistance = math.huge
	self.minPinTypeId, self.minCacheSlot, self.minPinIndex = nil, nil, nil
	self:ForEachPinTypeManager(AccumulateClosestMouseOverPin, x, y)
	return self.minPinIndex, self.minPinTypeId, self.minCacheSlot
end

--[[
Gamepad/console equivalent of the mouse-hover handling above: in gamepad
mode, ZO_WorldMapPins_Manager:BuildMouseOverPinLists (mappin_manager.lua)
re-checks proximity to the fixed reticle (ZO_WorldMapScroll's center) every
time it runs, drives the native "sticky pin" magnetism (panning the map onto
whatever's nearest) and feeds the gamepad info tooltip - but only for real
ZO_MapPin objects registered with the pin manager, which our composite-based
pins aren't. Rather than duck-typing a full ZO_MapPin (a large, fragile
surface used every frame for every pin on the map), we hook that same
function to additionally run our own equivalent proximity check afterward,
using the exact cursor position it already computed, and drive the same two
public effects (pan to it, show its title in the gamepad tooltip) ourselves.
If a real pin already won magnetism this frame, we defer to it.
]]--

-- like GetMouseOverPinIndexAndType above, but takes container-relative
-- coordinates directly instead of always reading the mouse position, has no
-- small icon-radius gate (uses GetNearestPinAndDistance, not
-- GetMouseOverPinAndDistance), and also returns the winning (squared,
-- screen-pixel) distance - so callers can apply their own, much larger,
-- magnetism threshold and compare against the native sticky pin's candidate
-- accumulates the closest match so far into self.min* - see
-- PinController:ForEachPinTypeManager for why this isn't an inline closure
local function AccumulateNearestPin(self, pinTypeId, cacheSlot, pinTypeManager, x, y)
	local pinIndex, pinDist = pinTypeManager:GetNearestPinAndDistance(x, y)
	if pinDist and pinDist < self.minPinDistance then
		self.minPinDistance = pinDist
		self.minPinTypeId = pinTypeId
		self.minCacheSlot = cacheSlot
		self.minPinIndex = pinIndex
	end
end

function PinController:FindNearestPinAt(x, y)
	self.minPinDistance = math.huge
	self.minPinTypeId, self.minCacheSlot, self.minPinIndex = nil, nil, nil
	self:ForEachPinTypeManager(AccumulateNearestPin, x, y)
	return self.minPinIndex, self.minPinTypeId, self.minCacheSlot, self.minPinDistance
end

--[[
A time-based cooldown on its own only delays the chain, it doesn't stop it:
BuildMouseOverPinLists recomputes the native sticky candidate every ~0.3s
using the CURRENT (screen-fixed) reticle position, so once we've panned onto
one of our own book pins, a real pin that happens to sit close to it on the
map will legitimately become the new nearest-candidate a tick or two later -
and after any fixed cooldown expires, GamepadMap:UpdateDirectionalInput's own
idle loop will snap onto it via MoveToStickyPin, same as it always does once
idle+settled. That data point (a real pin near where WE just parked the view)
only exists because of our own pan, not because the player asked to go there.

So instead of a timer, track *who currently holds gamepad map focus* - "ours"
or "native" - and simply don't let the other side contest it. Once the player
actually moves the stick, native's own ClearStickyPin call (hooked below)
naturally releases "native"; our own re-evaluation naturally releases "ours"
once nothing of ours is within range any more (see ClearGamepadFocus). Only
when nobody currently holds focus can either side claim it.
]]--
function PinController:InitializeGamepadMagnetism()
	ZO_PostHook(ZO_WorldMapPins_Manager, "BuildMouseOverPinLists", function(mgr, cursorPositionX, cursorPositionY)
		self:OnGamepadMouseOverPinsBuilt(cursorPositionX, cursorPositionY)
	end)

	local stickyPin = ZO_WorldMap_GetStickyPin()

	local originalMoveToStickyPin = stickyPin.MoveToStickyPin
	stickyPin.MoveToStickyPin = function(pinSelf, ...)
		if self.gamepadFocusOwner == "ours" then
			return -- we're still holding focus on one of our own pins; don't let native steal it back
		end
		self.gamepadFocusOwner = "native"
		return originalMoveToStickyPin(pinSelf, ...)
	end

	local originalClearStickyPin = stickyPin.ClearStickyPin
	stickyPin.ClearStickyPin = function(pinSelf, ...)
		if self.gamepadFocusOwner == "native" then
			self.gamepadFocusOwner = nil
		end
		return originalClearStickyPin(pinSelf, ...)
	end
end

function PinController:OnGamepadMouseOverPinsBuilt(cursorPositionX, cursorPositionY)
	if not IsInGamepadPreferredMode() then return end
	if not self.zoom:ReachedTargetOffset() then return end
	if self.gamepadFocusOwner == "native" then return end -- native currently holds focus; don't contest it

	local x = cursorPositionX - ZO_WorldMapContainer:GetLeft()
	local y = cursorPositionY - ZO_WorldMapContainer:GetTop()
	local pinIndex, pinTypeId, cacheSlot, pinDistance = self:FindNearestPinAt(x, y)

	local stickyPin = ZO_WorldMap_GetStickyPin()
	if pinIndex and pinDistance > stickyPin.thresholdDistanceSq then
		-- outside the native magnetism radius (the same one real pins use,
		-- which already scales with zoom) - too far to count as "nearby"
		pinIndex = nil
	end

	if pinIndex then
		-- at most zoom levels some real pin (a zone label, POI, wayshrine...)
		-- is within the native sticky-pin radius almost all the time, so only
		-- defer to it if it's actually closer to the reticle than ours is
		if stickyPin:GetStickyPin() and stickyPin.nearestCandidateDistanceSq < pinDistance then
			pinIndex = nil
		end
	end

	if not pinIndex then
		self:ClearGamepadFocus()
		return
	end

	local pinTypeManager = self.pinTypeManagers[pinTypeId][cacheSlot]
	local nodeId = pinTypeManager.nodeId[pinIndex]
	local zoneCache = pinTypeManager.zoneCache
	if self.gamepadFocusedZoneCache == zoneCache and self.gamepadFocusedNodeId == nodeId then
		return -- already focused on this one; don't keep re-panning/re-showing every tick
	end
	self.gamepadFocusedZoneCache = zoneCache
	self.gamepadFocusedNodeId = nodeId
	self.gamepadFocusOwner = "ours"

	-- reuse the same mouseOverPin highlight control the keyboard hover uses
	-- (created in InitializeMouseHandling regardless of ZO_IsConsoleOrGameCoreUI), so the
	-- currently-focused pin is visibly highlighted in gamepad mode too
	self:ShowSelectionControl(pinIndex, pinTypeId, cacheSlot)
	self.mouseOverPin:SetScale(1.3)

	local normalizedX, normalizedY = zoneCache:GetLocal(nodeId)
	ZO_WorldMap_PanToNormalizedPosition(normalizedX, normalizedY)

	local title = self:GetBookTitle(pinTypeId, cacheSlot, pinIndex)
	if title then
		-- ZO_WorldMap_ShowGamepadTooltip returns ZO_MapLocationTooltip_Gamepad,
		-- which lays out content as sections (AcquireSection/AddSection) via
		-- its .tooltip sub-object and ZO_MapInformationTooltip_Gamepad_Mixin,
		-- not a plain AddLine - mirrors maptooltips.lua's AppendSkyshardHint.
		-- It only clears its own previous content the first time it's shown
		-- (or after being fully hidden), so hopping from one of our pins
		-- straight to another needs an explicit ClearLines or the new title
		-- just gets appended below the old one.
		local mapTooltip = ZO_WorldMap_ShowGamepadTooltip(true)
		if mapTooltip and mapTooltip.tooltip then
			local RESET_SCROLL = true
			mapTooltip:ClearLines(RESET_SCROLL)
			local section = mapTooltip.tooltip:AcquireSection(mapTooltip.tooltip:GetStyle("skyshardMainSection"))
			mapTooltip:LayoutStringLine(section, title, mapTooltip.tooltip:GetStyle("skyshardHint"))
			mapTooltip.tooltip:AddSection(section)
		end
	end
end

function PinController:ClearGamepadFocus()
	if not self.gamepadFocusedNodeId then return end
	self.gamepadFocusedNodeId = nil
	self.gamepadFocusedZoneCache = nil
	if self.gamepadFocusOwner == "ours" then
		self.gamepadFocusOwner = nil
	end
	self.mouseOverPin:SetScale(1)
	self.mouseOverPin:SetHidden(true)
	ZO_WorldMap_HideAllTooltips()
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
		end
	end
end

-- see PinController:ForEachPinTypeManager for why this isn't an inline closure
local function UpdateAllPinLocationsOfManager(self, pinTypeId, cacheSlot, pinManager)
	for pinIndex, nodeId in pairs(pinManager.nodeId) do
		pinManager:UpdateLocationOfPinWithIndex(pinIndex)
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

			self:ForEachPinTypeManager(UpdateAllPinLocationsOfManager)
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

-- see PinController:ForEachPinTypeManager for why this isn't an inline closure
local function UpdateManagerSizeAndPinLocations(self, pinTypeId, cacheSlot, pinManager)
	pinManager:UpdateSize()
	for pinIndex, nodeId in pairs(pinManager.nodeId) do
		pinManager:UpdateLocationOfPinWithIndex(pinIndex)
	end
end

function PinController:OnMapSizeChange(width, height)
	assert(width and height)
	self.MAP_WIDTH = width
	self.MAP_HEIGHT = height
	self:CheckMapMode()

	self:ForEachPinTypeManager(UpdateManagerSizeAndPinLocations)

	if not self.mouseOverPin:IsHidden() then
		local composite = self.pinTypeManagers[self.mouseOverPin.pinTypeId][self.mouseOverPin.cacheSlot].composite
		local x, _, y, _ = composite:GetInsets(self.mouseOverPin.pinIndex)
		self.mouseOverPin:SetAnchor(CENTER, self.container, TOPLEFT, x, y)
	end
end

-- see PinController:ForEachPinTypeManager for why these aren't inline closures
local function RemoveAllPinsOfManager(self, pinTypeId, cacheSlot, pinTypeManager)
	pinTypeManager:RemoveAllPins()
end

local function RefreshLayoutOfManager(self, pinTypeId, cacheSlot, pinTypeManager)
	pinTypeManager:RefreshLayout()
end

function PinController:RemoveAllPins()
	self:ForEachPinTypeManager(RemoveAllPinsOfManager)
end

function PinController:RefreshLayout()
	self:ForEachPinTypeManager(RefreshLayoutOfManager)
end

function PinController:RegisterPinType(pinTypeId, cacheSlot, layout)
	self.pinTypeManagers[pinTypeId] = self.pinTypeManagers[pinTypeId] or {}
	self.pinTypeManagers[pinTypeId][cacheSlot] = PinTypeManager:New(layout, pinTypeId)
end

function PinController:CreatePinForNodeId(pinTypeId, cacheSlot, nodeId)
	self.pinTypeManagers[pinTypeId][cacheSlot]:GetNewPinForNodeId(nodeId)
end

-- see PinController:ForEachPinTypeManager for why this isn't an inline closure
local function SetZoneCacheOfMatchingSlot(self, pinTypeId, managerCacheSlot, pinTypeManager, cacheSlot, zoneCache)
	if managerCacheSlot == cacheSlot then
		pinTypeManager:SetZoneCache(zoneCache)
	end
end

function PinController:SetZoneCache(cacheSlot, zoneCache)
	self:ForEachPinTypeManager(SetZoneCacheOfMatchingSlot, cacheSlot, zoneCache)
end

function PinController:RemovePinForNodeId(pinTypeId, cacheSlot, nodeId)
	self.pinTypeManagers[pinTypeId][cacheSlot]:RemovePinForNodeId(nodeId)
end

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
	if layout.tint then
		self.composite:SetColor(pinIndex, layout.tint:UnpackRGB())
	else
		self.composite:SetColor(pinIndex, 1, 1, 1, 1)
	end
	self:UpdateLocationOfPinWithIndex(pinIndex)
end

function PinTypeManager:UpdateLocationOfPinWithIndex(pinIndex)
	local x, y = self.zoneCache:GetLocal(self.nodeId[pinIndex])
	self.composite:SetInsets(pinIndex, x * PinController.MAP_WIDTH, x * PinController.MAP_WIDTH, y * PinController.MAP_WIDTH, y * PinController.MAP_WIDTH)
end
local OriginalUpdateLocation = PinTypeManager.UpdateLocationOfPinWithIndex

function PinTypeManager:UpdateSize()
	local layout = self.layout
	local size = layout.size / GetUICustomScale()
	if VOTANS_MINIMAP and VOTANS_MINIMAP.scale and WORLD_MAP_MANAGER:IsInMode(MAP_MODE_VOTANS_MINIMAP) then
		size = size * VOTANS_MINIMAP:CalculateScale("Others")
	elseif FyrMM and not ZO_WorldMap_IsWorldMapShowing() then
		size = size * FyrMM.pScalePercent
	end
	layout.currentPinSize = size
	self.composite:SetDimensions(size, size)
end

function PinTypeManager:GetMouseOverPinAndDistance(x, y)
	local size = self.layout.currentPinSize
	local minDist = math.huge
	local minPinIndex = nil
	local dist = 0
	for i = 1, self.composite:GetNumSurfaces() do
		local pinX, _, pinY, _ = self.composite:GetInsets(i)
		dist = (x - pinX) * (x - pinX) + (y - pinY) * (y - pinY)
		if dist < minDist then
			minDist = dist
			minPinIndex = i
		end
	end
	if minDist < (size / 2) * (size / 2) then
		return minPinIndex, minDist
	end
end

-- like GetMouseOverPinAndDistance, but returns the nearest pin and its
-- distance unconditionally, without gating on the (small, precise-mouse-
-- hover-sized) icon radius - for callers that want to apply their own,
-- possibly much larger, threshold instead (see PinController:FindNearestPinAt)
function PinTypeManager:GetNearestPinAndDistance(x, y)
	local minDist = math.huge
	local minPinIndex = nil
	for i = 1, self.composite:GetNumSurfaces() do
		local pinX, _, pinY, _ = self.composite:GetInsets(i)
		local dist = (x - pinX) * (x - pinX) + (y - pinY) * (y - pinY)
		if dist < minDist then
			minDist = dist
			minPinIndex = i
		end
	end
	if minPinIndex then
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

function PinTypeManager:SetZoneCache(zoneCache)
	assert(self.composite:GetNumSurfaces() == 0, "still displaying pins of previous cache!")
	if self.zoneCache then
		self.zoneCache:UnregisterAccess(self)
	end
	self.zoneCache = zoneCache
	if self.zoneCache then
		self.zoneCache:RegisterAccess(self)
	end
end

function PinTypeManager:GetNewPinForNodeId(nodeId)
	self.composite:AddSurface(0, 1, 0, 1)
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
		local x, y = self.zoneCache:GetLocal(self.nodeId[pinIndex])
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
		local x, y = self.zoneCache:GetLocal(self.nodeId[pinIndex])
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
