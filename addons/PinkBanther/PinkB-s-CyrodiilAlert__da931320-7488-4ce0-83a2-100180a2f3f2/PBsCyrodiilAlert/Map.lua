-- PB's CyrodiilAlert -- the Cyrodiil overview map
--
-- PBS_CYRODIIL_ALERT is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_CYRODIIL_ALERT then
	return
end

local addon = PBS_CYRODIIL_ALERT

-- ---------------------------------------------------------------------------------------
-- The whole of Cyrodiil, small, in a corner.
--
-- PB's MiniMap (and Votan's, which it follows) works by parking the game's own world map on
-- the HUD. This cannot: the world map is one control showing one map at one zoom, and if both
-- add-ons are installed the second to borrow it takes it away from the first. So this draws
-- its own map out of the same parts the world map is built from, and never touches ZO_WorldMap
-- or the scenes it lives in.
--
-- Everything it needs can be asked for by map id, without changing the map the world map is
-- showing:
--
--     GetCyrodiilMapIndex / GetMapIdByIndex          which map Cyrodiil is
--     GetMapNumTilesForMapId / GetMapTileTextureForMapId   its tiles, laid out row-major
--                                                      exactly as worldmaptiles_manager.lua:29
--     GetUniversallyNormalizedMapInfo(mapId)         where any map sits in one shared space
--
-- The last one is what makes the pins work. GetKeepPinInfo and GetMapPlayerPosition answer in
-- the coordinates of whatever map the world map currently has set -- Cyrodiil, a city inside
-- it, or whatever a minimap add-on has zoomed to. Taking that map's place in the shared space
-- and Cyrodiil's place in it converts one into the other, so the pins land right whatever the
-- world map happens to be showing.
--
-- Keeps do not move, so a keep's position is kept once known and only its owner and attack
-- state are read again. The player is read on a short timer, and only while the map is up.
-- ---------------------------------------------------------------------------------------

local map = addon.map

local WINDOW_NAME = "PBsCyrodiilAlertMap"
local TICK_NAME = "PBsCyrodiilAlertMapTick"
local TICK_MS = 200

-- What appears on it. Keeps, outposts, towns, scroll temples and the border keeps -- the
-- holdings the campaign is fought over, and the three home gates for bearings. Resources are
-- left off: at this scale there are three of them crowded against every keep, and they would
-- turn each keep into a smudge.
local SHOWN_TYPE = {}
local function DeclareShownType(keepType)
	if keepType ~= nil then
		SHOWN_TYPE[keepType] = true
	end
end
DeclareShownType(KEEPTYPE_KEEP)
DeclareShownType(KEEPTYPE_OUTPOST)
DeclareShownType(KEEPTYPE_TOWN)
DeclareShownType(KEEPTYPE_ARTIFACT_KEEP)
DeclareShownType(KEEPTYPE_BORDER_KEEP)

-- Carried things that matter to the whole campaign: the scrolls and the Daedric artifact. The
-- same three the world map itself shows in AvA (worldmap.lua, IS_OBJECTIVE_TYPE_SHOWN_IN_AVA).
local SHOWN_OBJECTIVE = {}
local function DeclareShownObjective(objectiveType)
	if objectiveType ~= nil then
		SHOWN_OBJECTIVE[objectiveType] = true
	end
end
DeclareShownObjective(OBJECTIVE_ARTIFACT_OFFENSIVE)
DeclareShownObjective(OBJECTIVE_ARTIFACT_DEFENSIVE)
DeclareShownObjective(OBJECTIVE_DAEDRIC_WEAPON)

local PLAYER_TEXTURE = "EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds"
local ATTACK_TEXTURE = "EsoUI/Art/MapPins/AvA_attackBurst_64.dds"

-- The game's own pin art, read out of its pin table. Only a plain string is used: some entries
-- carry a function instead, and calling client code to get a texture is not something this
-- add-on does.
local function PinTexture(pinType, fallback)
	local data = ZO_MapPin and ZO_MapPin.PIN_DATA and pinType and ZO_MapPin.PIN_DATA[pinType]
	if data and type(data.texture) == "string" and data.texture ~= "" then
		return data.texture
	end
	return fallback
end

-- ---------------------------------------------------------------------------------------
-- Settings, read defensively
-- ---------------------------------------------------------------------------------------

local function Settings()
	return addon.sv and addon.sv.map or addon.DEFAULTS.map
end

local function Clamp(value, low, high)
	value = tonumber(value)
	if not value then
		return nil
	end
	if value < low then
		return low
	elseif value > high then
		return high
	end
	return value
end

function map:Size()
	return Clamp(Settings().size, addon.MIN_MAP_SIZE, addon.MAX_MAP_SIZE) or addon.DEFAULTS.map.size
end

function map:PinSize()
	return Clamp(Settings().pinSize, addon.MIN_MAP_PIN, addon.MAX_MAP_PIN) or addon.DEFAULTS.map.pinSize
end

function map:Opacity()
	return Clamp(Settings().opacity, 10, 100) or addon.DEFAULTS.map.opacity
end

function map:OffsetX()
	return Clamp(Settings().offsetX, -addon.MAX_OFFSET_X, addon.MAX_OFFSET_X) or 0
end

function map:OffsetY()
	return Clamp(Settings().offsetY, -addon.MAX_OFFSET_Y, addon.MAX_OFFSET_Y) or 0
end

function map:Position()
	local wanted = Settings().position
	if addon.AnchorFor(wanted) then
		return wanted
	end
	return addon.DEFAULTS.map.position
end

function map:Draw()
	local wanted = Settings().draw
	if addon.IsDrawOrder(wanted) then
		return wanted
	end
	return "FRONT"
end

-- ---------------------------------------------------------------------------------------
-- Where things are
-- ---------------------------------------------------------------------------------------

function map:CyrodiilMapId()
	if self.cyrodiilMapId then
		return self.cyrodiilMapId
	end
	if not (GetCyrodiilMapIndex and GetMapIdByIndex) then
		return nil
	end
	local index = GetCyrodiilMapIndex()
	if not index then
		return nil
	end
	local mapId = GetMapIdByIndex(index)
	if mapId and mapId ~= 0 then
		self.cyrodiilMapId = mapId
	end
	return self.cyrodiilMapId
end

local function Universal(mapId)
	if not (mapId and GetUniversallyNormalizedMapInfo) then
		return nil
	end
	local x, y, width, height = GetUniversallyNormalizedMapInfo(mapId)
	if not (x and y and width and height) or width <= 0 or height <= 0 then
		return nil
	end
	return x, y, width, height
end

-- A point in the current map's coordinates, as a point on Cyrodiil's. Nil when either map's
-- place in the shared space is unknown -- a pin with no trustworthy position is left where it
-- was last seen rather than drawn somewhere invented.
function map:ToCyrodiil(x, y)
	if not (x and y) then
		return nil
	end
	local cyrodiil = self:CyrodiilMapId()
	if not cyrodiil then
		return nil
	end
	local current = GetCurrentMapId and GetCurrentMapId() or nil
	if current == cyrodiil then
		return x, y
	end
	local currentX, currentY, currentWidth, currentHeight = Universal(current)
	local cyroX, cyroY, cyroWidth, cyroHeight = Universal(cyrodiil)
	if not (currentX and cyroX) then
		return nil
	end
	return (currentX + x * currentWidth - cyroX) / cyroWidth,
		(currentY + y * currentHeight - cyroY) / cyroHeight
end

local function OnMap(x, y)
	return x and y and x >= -0.02 and x <= 1.02 and y >= -0.02 and y <= 1.02
end

-- Cyrodiil itself, not the Imperial City. The IC campaigns are fought on a different map
-- entirely, and this one would be a picture of somewhere else.
function map:ShouldShow()
	if not (addon.sv and addon.sv.map and addon.sv.map.enabled and addon.sv.enabled) then
		return false
	end
	if IsInCyrodiil then
		if not IsInCyrodiil() then
			return false
		end
	elseif not addon:InAvAZone() then
		return false
	end
	return not addon:InImperialCityCampaign()
end

-- Only over the game, never over a menu. The scene is read, not touched: nothing is added to
-- or taken from the client's scenes, so nothing here can leave one of them in a state it did
-- not expect.
function map:IsHudShowing()
	if not (SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene) then
		return true
	end
	local scene = SCENE_MANAGER:GetCurrentScene()
	if not scene then
		return true
	end
	return scene == HUD_SCENE or scene == HUD_UI_SCENE
		or scene == SIEGE_BAR_SCENE or scene == SIEGE_BAR_UI_SCENE
end

-- ---------------------------------------------------------------------------------------
-- The control
-- ---------------------------------------------------------------------------------------

map.keepPins = {}
map.objectivePins = {}
map.keepPositions = {}

local function NewTexture(name, parent, level)
	local texture = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
	texture:SetMouseEnabled(false)
	if texture.SetDrawLevel then
		texture:SetDrawLevel(level)
	end
	return texture
end

function map:Create()
	if self.window then
		return true
	end
	if self.failed then
		return false
	end

	local wm = WINDOW_MANAGER
	local mapId = self:CyrodiilMapId()
	if not (wm and wm.CreateTopLevelWindow and CT_TEXTURE and GuiRoot and mapId
		and GetMapNumTilesForMapId and GetMapTileTextureForMapId) then
		self.failed = true
		return false
	end

	local ok, window = pcall(function()
		return wm:CreateTopLevelWindow(WINDOW_NAME)
	end)
	if not ok or not window then
		self.failed = true
		return false
	end
	window:SetMouseEnabled(false)
	window:SetMovable(false)
	window:SetHidden(true)
	self.window = window

	-- The tiles, row-major, the way the world map lays them out.
	local across, down = GetMapNumTilesForMapId(mapId)
	across, down = math.max(1, across or 1), math.max(1, down or 1)
	self.across, self.down = across, down
	self.tiles = {}
	for index = 1, across * down do
		local tile = NewTexture(WINDOW_NAME .. "Tile" .. index, window, 1)
		tile:SetTexture(GetMapTileTextureForMapId(mapId, index))
		self.tiles[index] = tile
	end

	self.player = NewTexture(WINDOW_NAME .. "Player", window, 9)
	self.player:SetTexture(PLAYER_TEXTURE)

	self:Apply()
	return true
end

function map:Available()
	return self.window ~= nil and not self.failed
end

function map:Apply()
	if not self.window then
		return
	end
	local size = self:Size()
	local anchor = addon.AnchorFor(self:Position())
	self.window:SetDimensions(size, size)
	self.window:ClearAnchors()
	self.window:SetAnchor(anchor, GuiRoot, anchor, self:OffsetX(), self:OffsetY())
	self.window:SetAlpha(self:Opacity() / 100)

	local tileWidth, tileHeight = size / self.across, size / self.down
	for index, tile in ipairs(self.tiles) do
		tile:SetDimensions(tileWidth, tileHeight)
		tile:ClearAnchors()
		tile:SetAnchor(TOPLEFT, self.window, TOPLEFT,
			((index - 1) % self.across) * tileWidth, math.floor((index - 1) / self.across) * tileHeight)
	end

	local pin = self:PinSize()
	self.player:SetDimensions(pin, pin)
	for _, keep in pairs(self.keepPins) do
		keep.icon:SetDimensions(pin, pin)
		keep.burst:SetDimensions(pin * 1.6, pin * 1.6)
	end
	for _, objective in pairs(self.objectivePins) do
		objective:SetDimensions(pin, pin)
	end

	self.drawOrderRefused = not addon.ApplyDrawOrder(self.window, self:Draw())
	self:PlaceAll()
end

local function Place(control, parent, size, x, y)
	control:ClearAnchors()
	control:SetAnchor(CENTER, parent, TOPLEFT, x * size, y * size)
end

function map:PlaceAll()
	local size = self:Size()
	for keepId, keep in pairs(self.keepPins) do
		local position = self.keepPositions[keepId]
		if position then
			Place(keep.icon, self.window, size, position.x, position.y)
			Place(keep.burst, self.window, size, position.x, position.y)
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- The pins
-- ---------------------------------------------------------------------------------------

function map:KeepPin(keepId)
	local keep = self.keepPins[keepId]
	if keep then
		return keep
	end
	local name = WINDOW_NAME .. "Keep" .. tostring(keepId)
	-- The burst sits under the keep, as the world map draws it (attack pins at level 30, keeps
	-- at 50, mappin.lua).
	keep = {
		burst = NewTexture(name .. "Attack", self.window, 3),
		icon = NewTexture(name, self.window, 5),
	}
	keep.burst:SetTexture(PinTexture(MAP_PIN_TYPE_KEEP_ATTACKED_LARGE, ATTACK_TEXTURE))
	local pin = self:PinSize()
	keep.icon:SetDimensions(pin, pin)
	keep.burst:SetDimensions(pin * 1.6, pin * 1.6)
	self.keepPins[keepId] = keep
	return keep
end

-- Owners and attacks, from the same reads the watch makes. Called after every pass.
function map:RefreshKeeps()
	if not self.window or self.window:IsHidden() then
		return
	end
	if not (GetNumKeeps and GetKeepKeysByIndex and GetKeepPinInfo and GetKeepType) then
		return
	end
	local seen = {}
	for index = 1, (GetNumKeeps() or 0) do
		local keepId, bgContext = GetKeepKeysByIndex(index)
		if keepId and addon.IsThisCampaign(bgContext) and SHOWN_TYPE[GetKeepType(keepId)] then
			local pinType, x, y = GetKeepPinInfo(keepId, bgContext)
			if pinType and pinType ~= MAP_PIN_TYPE_INVALID then
				local cx, cy = self:ToCyrodiil(x, y)
				-- A keep does not move. A position that lands on the map is kept; one that does
				-- not (the world map showing somewhere the conversion cannot reach) is ignored
				-- and the last good one stands.
				if OnMap(cx, cy) then
					self.keepPositions[keepId] = { x = cx, y = cy }
				end
				local position = self.keepPositions[keepId]
				if position then
					seen[keepId] = true
					local keep = self:KeepPin(keepId)
					-- No usable art for this pin type: no icon, rather than some other icon
					-- standing in for it. An attack burst still shows if it is under attack.
					local texture = PinTexture(pinType, nil)
					if texture then
						keep.icon:SetTexture(texture)
					end
					keep.icon:SetHidden(texture == nil)
					local attacked = GetKeepUnderAttack and GetKeepUnderAttack(keepId, bgContext)
					keep.burst:SetHidden(not attacked)
					Place(keep.icon, self.window, self:Size(), position.x, position.y)
					Place(keep.burst, self.window, self:Size(), position.x, position.y)
				end
			end
		end
	end
	for keepId, keep in pairs(self.keepPins) do
		if not seen[keepId] then
			keep.icon:SetHidden(true)
			keep.burst:SetHidden(true)
		end
	end
	self:RefreshObjectives()
end

function map:RefreshObjectives()
	for _, pin in pairs(self.objectivePins) do
		pin:SetHidden(true)
	end
	if not (GetNumObjectives and GetObjectiveIdsForIndex and GetObjectiveType and GetObjectivePinInfo) then
		return
	end
	local count = 0
	for index = 1, (GetNumObjectives() or 0) do
		local keepId, objectiveId, bgContext = GetObjectiveIdsForIndex(index)
		if keepId and addon.IsThisCampaign(bgContext)
			and SHOWN_OBJECTIVE[GetObjectiveType(keepId, objectiveId, bgContext)] then
			local pinType, x, y = GetObjectivePinInfo(keepId, objectiveId, bgContext)
			local texture = PinTexture(pinType, nil)
			local cx, cy = self:ToCyrodiil(x, y)
			if texture and OnMap(cx, cy) then
				count = count + 1
				local pin = self.objectivePins[count]
				if not pin then
					pin = NewTexture(WINDOW_NAME .. "Objective" .. count, self.window, 7)
					local size = self:PinSize()
					pin:SetDimensions(size, size)
					self.objectivePins[count] = pin
				end
				pin:SetTexture(texture)
				Place(pin, self.window, self:Size(), cx, cy)
				pin:SetHidden(false)
			end
		end
	end
end

function map:RefreshPlayer()
	if not (self.player and GetMapPlayerPosition) then
		return
	end
	local x, y = GetMapPlayerPosition("player")
	local cx, cy = self:ToCyrodiil(x, y)
	if not OnMap(cx, cy) then
		self.player:SetHidden(true)
		return
	end
	Place(self.player, self.window, self:Size(), cx, cy)
	if self.player.SetTextureRotation and GetPlayerCameraHeading then
		self.player:SetTextureRotation(GetPlayerCameraHeading())
	end
	self.player:SetHidden(false)
end

-- ---------------------------------------------------------------------------------------
-- Showing and hiding
-- ---------------------------------------------------------------------------------------

-- The short tick that moves the player arrow, and hides the map while a menu is up. It only
-- exists while the map can be shown at all: outside Cyrodiil, or switched off, nothing runs.
function map:StartTick()
	if self.ticking then
		return
	end
	self.ticking = true
	EVENT_MANAGER:RegisterForUpdate(TICK_NAME, TICK_MS, function()
		self:Tick()
	end)
end

function map:StopTick()
	if not self.ticking then
		return
	end
	self.ticking = false
	EVENT_MANAGER:UnregisterForUpdate(TICK_NAME)
end

function map:Tick()
	if not self.window then
		return
	end
	local wasHidden = self.window:IsHidden()
	local show = self:IsHudShowing()
	self.window:SetHidden(not show)
	if show then
		if wasHidden then
			self:RefreshKeeps()
		end
		self:RefreshPlayer()
	end
end

function map:Refresh()
	if not self:ShouldShow() then
		self:StopTick()
		if self.window then
			self.window:SetHidden(true)
		end
		return
	end
	if not self:Create() then
		return
	end
	self:Apply()
	self.window:SetHidden(not self:IsHudShowing())
	self:RefreshKeeps()
	self:RefreshPlayer()
	self:StartTick()
end

-- What the map is working with, for the one question a console test round has to answer: do
-- the pins land where the keeps are.
function map:Probe()
	local lines = {}
	local cyrodiil = self:CyrodiilMapId()
	local current = GetCurrentMapId and GetCurrentMapId() or nil
	lines[#lines + 1] = string.format("map: cyrodiil=%s current=%s tiles=%sx%s shown=%s",
		tostring(cyrodiil), tostring(current), tostring(self.across), tostring(self.down),
		tostring(self.window and not self.window:IsHidden()))
	lines[#lines + 1] = string.format("universal cyrodiil=%s current=%s",
		table.concat({ tostring(select(1, Universal(cyrodiil))), tostring(select(3, Universal(cyrodiil))) }, "/"),
		table.concat({ tostring(select(1, Universal(current))), tostring(select(3, Universal(current))) }, "/"))
	if GetMapPlayerPosition then
		local x, y = GetMapPlayerPosition("player")
		local cx, cy = self:ToCyrodiil(x, y)
		lines[#lines + 1] = string.format("player: current=%.3f,%.3f cyrodiil=%s,%s",
			x or -1, y or -1, cx and string.format("%.3f", cx) or "nil", cy and string.format("%.3f", cy) or "nil")
	end
	local known = 0
	for _ in pairs(self.keepPositions) do
		known = known + 1
	end
	lines[#lines + 1] = string.format("keeps placed: %d", known)
	return lines
end
