local LCA = LibCombatAlerts
local Internal = LibCombatAlertsInternal


--[[ Texture Paramaters --------------------------------------------------------
texture: either the ID of a predefined LCA texture or the path of a .dds file
size: number s for "s x s" or table { w, h } or "w x h"
	units: cm
	default: 100
color: 0xRRGGBBAA
	default: 0xFFFFFFFF
disableDepthBuffers: texture will render in front of objects in the world
	default: false
playerFacing: true for player-facing floating texture, false for ground texture
	default: false (ground texture)
pos: table { x, y, z } world position or string unitTag
elevation: additional distance above ground
	units: cm
	default: 4 for ground texture, 350 for playerFacing unitTag, 0 for all else
groundAngle: angle of texture (ground only)
	units: radians
groundOverlay: parameters for texture to be overlaid (ground only)
	texture, size, color: see above
	offsetH, offsetV: position offset from the parent texture, in cm
update: callback function for update polling
	parameters: elementId, updateParam
	returns: true to skip standard update call
updateParam: optional parameter to pass to callback function
]]


--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local DEFAULT_ELEVATION_GROUND = 4
local DEFAULT_ELEVATION_FLOATING_UNIT = 350
local BASE_GROUND_DRAW_LEVEL = -0x1000000

local QPI = ZO_PI / 4

LCA.DIRECTIONS = {
	{ "n" ,       0,  0, -1 },
	{ "nw",     QPI, -1, -1 },
	{ "w" , 2 * QPI, -1,  0 },
	{ "sw", 3 * QPI, -1,  1 },
	{ "s" , 4 * QPI,  0,  1 },
	{ "se", 5 * QPI,  1,  1 },
	{ "e" , 6 * QPI,  1,  0 },
	{ "ne", 7 * QPI,  1, -1 },
}


--------------------------------------------------------------------------------
-- LCA_WorldDrawing
--------------------------------------------------------------------------------

local BASE = { }

local LCA_WorldDrawing = Internal.BaseControlObject:Subclass()
LCA.WorldDrawing = LCA_WorldDrawing

-- Preserve GuiRoot to guard against redefinition
local GuiRoot = GuiRoot


--------------------------------------------------------------------------------
-- Public interface
--------------------------------------------------------------------------------

function LCA_WorldDrawing:New( )
	local obj = Internal.BaseControlObject.New(self, "LCA_WorldDrawing")
	obj.base = BASE.Initialize()
	obj.elements = { }
	return obj
end

function LCA_WorldDrawing:PlaceTexture( params )
	local elementId, element = self:CreateElement()
	element.params = params or { }
	BASE.UpdateTextureElement(elementId, element, true, true, true)
	return elementId
end

function LCA_WorldDrawing:UpdateTexture( elementId, ... )
	local element = self:GetElement(elementId)
	if (element) then
		local elevationOrig = element.params.elevation
		LCA.UpdateOptions(element.params, ...)
		BASE.UpdateTextureElement(elementId, element, elevationOrig ~= element.params.elevation, true)
	end
end

function LCA_WorldDrawing:RemoveElement( elementId )
	local element = self:GetElement(elementId)
	if (element) then
		for _, texture in ipairs(element.textures) do
			BASE.DestroyTexture(texture)
		end
		BASE.UnregisterElementForUpdate(elementId)
		self.elements[elementId] = nil
	end
end

function LCA_WorldDrawing:Clear( )
	for elementId in pairs(self.elements) do
		self:RemoveElement(elementId)
	end
end

function LCA_WorldDrawing:PlaceGrowingCircularTelegraph( target, radius, duration, isFriendly, useClipping )
	-- target can be either a unitTag or a { x, y, z } position
	-- radius is in cm
	-- duration is in ms

	local color = LCA.GetTelegraphColor(isFriendly)
	local elevation = nil
	if (type(target) == "string") then
		elevation = tonumber(string.match(target, "^group(%d+)$"))
	end

	local groundOverlay = {
		texture = "world-circle",
		color = color,
		size = 0,
	}

	self:PlaceTexture({
		pos = target,
		texture = "world-ring",
		color = color,
		size = radius * 2,
		elevation = elevation and (2 * elevation + DEFAULT_ELEVATION_GROUND),
		groundOverlay = groundOverlay,
		disableDepthBuffers = useClipping ~= true,
		update = function( elementId, startTime )
			local elapsed = GetGameTimeMilliseconds() - startTime
			if (elapsed >= duration) then
				self:RemoveElement(elementId)
			else
				groundOverlay.size = elapsed * radius * 2 / duration
				self:UpdateTexture(elementId, "groundOverlay", groundOverlay)
			end
			return true
		end,
		updateParam = GetGameTimeMilliseconds(),
	})
end


--------------------------------------------------------------------------------
-- Private functions; do not call these externally
--------------------------------------------------------------------------------

function LCA_WorldDrawing:CreateElement( )
	local elementId = BASE.GetNextElementId()
	local element = { textures = { } }
	self.elements[elementId] = element
	return elementId, element
end

function LCA_WorldDrawing:GetElement( elementId )
	return elementId and self.elements[elementId]
end


--------------------------------------------------------------------------------
-- Each consumer should have their own instance of a LCA_WorldDrawing canvas (so
-- that a canvas can be cleared independently of other canvases), but internally
-- there only needs to be a single canvas and control pool and the instances are
-- thus virtual; element IDs should also be unique across instances since update
-- polling is also shared across instances
--------------------------------------------------------------------------------

do
	-- Canvas, control pool, and camera ----------------------------------------

	local initialized = false
	local texturePool
	local camera = { }

	function BASE.Initialize( )
		if (not initialized) then
			initialized = true
			local root = WINDOW_MANAGER:CreateControlFromVirtual("LCA_WorldDrawing_Root", GuiRoot, "LCA_WorldDrawing")
			texturePool = ZO_ControlPool:New("LCA_WorldTexture", root)
			camera.control = root:GetNamedChild("Camera")
			camera.control:Create3DRenderSpace()
			camera.name = camera.control:GetName()

			-- Limit to valid scenes; omitted "treasureMapInventory", "treasureMapQuickSlot", "treasureMapInventoryGamepad", "treasureMapQuickSlotGamepad"
			LCA.ToggleUIFragment(ZO_SimpleSceneFragment:New(root), true, { "loot", "lootGamepad", "worldMap", "gamepad_worldMap", "housingEditorHud", "housingEditorHudUI", "gameMenuInGame" })
		end
		return BASE
	end

	-- Unique element ID across all instances ----------------------------------

	local nextElementId = 0

	function BASE.GetNextElementId( )
		nextElementId = nextElementId + 1
		return nextElementId
	end

	-- Textures ----------------------------------------------------------------

	function BASE.CreateTexture( element )
		local control, key = texturePool:AcquireObject()
		local texture = { control = control, key = key }
		table.insert(element.textures, texture)
		control:Create3DRenderSpace()
		return texture
	end

	function BASE.DestroyTexture( texture )
		texture.control:SetHidden(true)
		texture.control:Destroy3DRenderSpace()
		texturePool:ReleaseObject(texture.key)
	end

	local function SetTextureParams( texture, params )
		local p = params

		-- Texture
		if (texture.texture ~= p.texture) then
			texture.texture = p.texture
			if (zo_strlower(zo_strsub(p.texture, -4)) == ".dds") then
				texture.control:SetTexture(p.texture)
				texture.control:SetTextureCoords(0, 1, 0, 1)
			else
				LCA.SetTexture(texture.control, p.texture)
			end
		end

		-- Size
		local w, h = 1, 1
		if (type(p.size) == "number") then
			w = p.size / 100
			h = w
		elseif (type(p.size) == "table") then
			w = p.size[1] / 100
			h = p.size[2] / 100
		end

		if (texture.w ~= w or texture.h ~= h) then
			texture.w, texture.h = w, h
			texture.control:Set3DLocalDimensions(w, h)
		end

		-- Color
		local color = p.color or 0xFFFFFFFF
		if (texture.color ~= color) then
			texture.color = color
			texture.control:SetColor(LCA.UnpackRGBA(color))
		end

		-- Depth buffers
		local depthBuffers = p.disableDepthBuffers ~= true
		if (texture.depthBuffers ~= depthBuffers) then
			texture.depthBuffers = depthBuffers
			texture.control:Set3DRenderSpaceUsesDepthBuffer(depthBuffers)
		end
	end

	function BASE.UpdateTextureElement( elementId, element, refreshElevation, refreshUpdate, refreshCamera )
		local p = element.params
		local texture, texture2 = unpack(element.textures)
		local redrawOverlay = false

		-- Elevation

		if (refreshElevation) then
			if (type(p.elevation) == "number") then
				element.elevation = p.elevation
			elseif (not p.playerFacing) then
				element.elevation = DEFAULT_ELEVATION_GROUND
			elseif (type(p.pos) == "string") then
				element.elevation = DEFAULT_ELEVATION_FLOATING_UNIT
			else
				element.elevation = 0
			end
		end

		-- Primary texture

		if (not texture) then
			texture = BASE.CreateTexture(element)
		end
		SetTextureParams(texture, p)

		-- Positioning

		local x, y, z, _

		if (type(p.pos) == "table") then
			x, y, z = unpack(p.pos)
		elseif (type(p.pos) == "string") then
			_, x, y, z = GetUnitRawWorldPosition(p.pos)
		else
			x, y, z = 0, 0, 0
		end
		y = y + element.elevation

		if (element.x ~= x or element.y ~= y or element.z ~= z) then
			element.x, element.y, element.z = x, y, z
			texture.control:Set3DRenderSpaceOrigin(WorldPositionToGuiRender3DPosition(x, y, z))
			redrawOverlay = true
		end

		-- Orientation

		local yaw = (not p.playerFacing and p.groundAngle) and p.groundAngle or 0

		if (element.yaw ~= yaw) then
			element.yaw = yaw
			texture.control:Set3DRenderSpaceOrientation(p.playerFacing and 0 or -ZO_HALF_PI, yaw, 0)
			redrawOverlay = true
		end

		-- Special handling: player-facing textures and ground overlay textures

		if (p.playerFacing) then
			local c = camera
			if (refreshCamera or not c.valid) then
				Set3DRenderSpaceToCurrentCamera(c.name)
				c.xf, c.yf, c.zf = c.control:Get3DRenderSpaceForward()
				c.xr, c.yr, c.zr = c.control:Get3DRenderSpaceRight()
				c.xu, c.yu, c.zu = c.control:Get3DRenderSpaceUp()
				c.xo, c.yo, c.zo = GuiRender3DPositionToWorldPosition(c.control:Get3DRenderSpaceOrigin())
				c.valid = true
			end
			texture.control:Set3DRenderSpaceForward(c.xf, c.yf, c.zf)
			texture.control:Set3DRenderSpaceRight(c.xr, c.yr, c.zr)
			texture.control:Set3DRenderSpaceUp(c.xu, c.yu, c.zu)
			texture.control:SetDrawLevel(-10 - zo_floor(LCA.GetDistanceSquared(x, y, z, c.xo, c.yo, c.zo)))
		else
			-- Assume that ground textures are on the ground, below the player's eyes
			local drawLevel = BASE_GROUND_DRAW_LEVEL + y
			texture.control:SetDrawLevel(drawLevel)

			if (p.groundOverlay) then
				local overlay = p.groundOverlay
				overlay.disableDepthBuffers = p.disableDepthBuffers

				if (not texture2) then
					texture2 = BASE.CreateTexture(element)
				end
				SetTextureParams(texture2, overlay)
				texture2.control:SetDrawLevel(drawLevel + 1)

				local dh, dv = 0, 0
				if (overlay.offsetH or overlay.offsetV) then
					local cos = math.cos(-yaw)
					local sin = math.sin(-yaw)
					dh = (overlay.offsetH or 0) * cos - (overlay.offsetV or 0) * sin
					dv = (overlay.offsetH or 0) * sin + (overlay.offsetV or 0) * cos
				end

				if (texture2.dh ~= dh or texture2.dv ~= dv) then
					texture2.dh, texture2.dv = dh, dv
					redrawOverlay = true
				end

				if (redrawOverlay) then
					texture2.control:Set3DRenderSpaceOrigin(WorldPositionToGuiRender3DPosition(x + dh, y + 1, z + dv))
					texture2.control:Set3DRenderSpaceOrientation(-ZO_HALF_PI, yaw, 0)
				end
			end
		end

		-- Update polling

		if (refreshUpdate) then
			if (p.playerFacing or type(p.pos) == "string" or type(p.update) == "function") then
				BASE.RegisterElementForUpdate(elementId, element)
			else
				BASE.UnregisterElementForUpdate(elementId)
			end
		end
	end

	-- Update polling ----------------------------------------------------------

	local UPD_NAME = "LCA_WorldDrawing_Updates"
	local updActive = false
	local updRegistrants = { }

	local function ElementsUpdatePoll( )
		camera.valid = false
		for elementId, element in pairs(updRegistrants) do
			local fn = element.params.update
			if (type(fn) == "function" and fn(elementId, element.params.updateParam)) then
				-- Skip standard update call
			else
				BASE.UpdateTextureElement(elementId, element)
			end
		end
	end

	function BASE.RegisterElementForUpdate( elementId, element )
		updRegistrants[elementId] = element
		if (not updActive and next(updRegistrants)) then
			updActive = true
			-- RegisterForUpdate can tick at most once per frame, so this will never exceed the frame rate
			EVENT_MANAGER:RegisterForUpdate(UPD_NAME, 0, ElementsUpdatePoll)
		end
	end

	function BASE.UnregisterElementForUpdate( elementId )
		updRegistrants[elementId] = nil
		if (updActive and not next(updRegistrants)) then
			updActive = false
			EVENT_MANAGER:UnregisterForUpdate(UPD_NAME)
		end
	end
end
