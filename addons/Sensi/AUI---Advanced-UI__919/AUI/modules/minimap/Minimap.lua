AUI.Minimap = {}

AUI_MINIMAP_MIN_ZOOM_ZONE = 1.0
AUI_MINIMAP_MAX_ZOOM_ZONE = 15
AUI_MINIMAP_MIN_ZOOM_SUBZONE = 1.0
AUI_MINIMAP_MAX_ZOOM_SUBZONE = 8
AUI_MINIMAP_MIN_ZOOM_DUNGEON = 1.0
AUI_MINIMAP_MAX_ZOOM_DUNGEON = 4
AUI_MINIMAP_MIN_ZOOM_ARENA = 1.0
AUI_MINIMAP_MAX_ZOOM_ARENA = 4

local g_isInit = false
local g_sceneFragment = nil
local g_TextureTiles = {}
local g_currentZoomValue = 0
local g_currentMapZoneType = "subzone"
local g_tileCountX = 0
local g_tileCountY = 0
local g_tileWidth = 0
local g_tileHeight = 0
local g_playerNormalizedX = 0
local g_playerNormalizedY = 0
local g_playerX = 0
local g_playerY = 0
local g_lastPlayerX = -1
local g_lastPlayerY = -1
local g_heading = 0
local g_lastHeading = 0
local g_headingCos = 0
local g_headingSin = 0
local g_containerSize = 0
local g_containerHalfWidth = 0
local g_containerHalfHeight = 0
local g_zoomStepZone = 1.0
local g_zommStepSubzone = 0.4
local g_zommStepDungeon = 0.5
local g_zommStepArena = 0.5

local function GetMapIndexList()
	local mapIndexList = 
	{
		["zone"] = {
			[0] = 0,
			[1] = 1,
			[2] = 20,
			[3] = 21,
			[4] = 30,
			[5] = 31,
			[6] = 40,
			[7] = 41,
			[8] = 50,
			[9] = 51
		},
		["subzone"] = {
			[0] = 10,
			[1] = 11
		},
		["dungeon"] = {
			[0] = 2,
			[1] = 12,
			[2] = 22,
			[3] = 32,
			[4] = 42,
			[5] = 52
		},
		["arena"] = {
			[0] = 13,
		}		
	}
	
	return mapIndexList
end

local function SetContainerSize()
	AUI.Minimap.SetCurrentZoomValue()

	g_containerSize = zo_max(AUI.Settings.Minimap.height, AUI.Settings.Minimap.width) * g_currentZoomValue	
	g_containerHalfWidth = AUI.Settings.Minimap.width / 2
	g_containerHalfHeight = AUI.Settings.Minimap.height / 2
	
	AUI.MapData.mapContainerSize = g_containerSize
	
	AUI_MapContainer:SetDimensions(g_containerSize, g_containerSize)
end

local function GetCurrentMapTypeID()
	return tonumber(GetMapType() .. GetMapContentType())
end

local function GetMapZoneType()
	local mapIndex = GetCurrentMapTypeID()

	for typ, mv in pairs(GetMapIndexList()) do
		for e, sv in pairs(mv) do
			if mapIndex == sv then
				return typ			
			end
		end
	end
		
	return nil
end

local function ReleaseAllTiles()
    for k, tile in ipairs(g_TextureTiles) do
        tile:SetHidden(true)
    end
end

local function GetTile(i)
    local tile = g_TextureTiles[i]
    if tile == nil then
        tile = CreateControlFromVirtual(AUI_MapContainer:GetName(), AUI_MapContainer, "AUI_MapTile", i)
        g_TextureTiles[i] = tile
    end
    tile:SetHidden(false)
    return tile
end

local function GetTileAnchor(iX, iY)
	local offsetX = 0
	local offsetY = 0		
	local relToControl = nil
		
	if AUI.Settings.Minimap.rotate then
		local x = ((iX-0.5) * g_tileWidth) - (g_playerX)
		local y = ((iY-0.5) * g_tileHeight) - (g_playerY)						

		offsetX = (g_headingCos * x) - (g_headingSin * y)
		offsetY = (g_headingSin * x) + (g_headingCos * y)
				
		relToControl = AUI_MapContainer
	else
		offsetX = ((iX-0.5) * g_tileWidth) - g_containerSize / 2
		offsetY = ((iY-0.5) * g_tileHeight) - g_containerSize / 2	
		relToControl = AUI_MapContainer	
	end

	return CENTER, relToControl, CENTER, offsetX, offsetY
end

local function UpdateAllTileLocations()
	if AUI.Settings.Minimap.rotate then
		AUI_Minimap_MainWindow_Map_Rotate:SetTextureRotation(-g_heading)
	end
	
	local i = 1
	for iY=1, g_tileCountX do
		for iX=1, g_tileCountY do	
			local tileControl = GetTile(i)
	
			if AUI.Settings.Minimap.rotate then
				tileControl:SetTextureRotation(-g_heading, 0.5, 0.5);		
			else
				tileControl:SetTextureRotation(0);
			end
		
			tileControl:ClearAnchors()
			tileControl:SetAnchor(GetTileAnchor(iX, iY))		
			i = i + 1
		end
	end			
end

local function RefreshAllTiles()
	ReleaseAllTiles()

	g_tileCountX, g_tileCountY = GetMapNumTiles()	
	g_tileWidth = g_containerSize / g_tileCountX
	g_tileHeight = g_containerSize / g_tileCountY
	
	if AUI.Settings.Minimap.rotate then
		AUI_Minimap_MainWindow_Map_Rotate:SetTextureRotation(-g_heading)
		
		AUI_MapContainer:ClearAnchors()
		AUI_MapContainer:SetAnchor(CENTER, nil, CENTER, 0, 0)		
	end
	
	local i = 1
	for iY=1, g_tileCountX do
		for iX=1, g_tileCountY do	
			local tileControl = GetTile(i)
	
			if AUI.Settings.Minimap.rotate then
				tileControl:SetTextureRotation(-g_heading, 0.5, 0.5);		
			else
				tileControl:SetTextureRotation(0);
			end
		
			tileControl:SetDimensions(g_tileWidth, g_tileHeight)
			tileControl:ClearAnchors()
			tileControl:SetAnchor(GetTileAnchor(iX, iY))
			tileControl:SetTexture(GetMapTileTexture(i))		
			i = i + 1
		end
	end
end

local function UpdatePlayerPin()
	local playerPin = AUI.Minimap.Pin.GetPlayerPin()
	if playerPin then
		g_playerNormalizedX, g_playerNormalizedY = GetMapPlayerPosition("player")		
		g_playerX = g_containerSize * g_playerNormalizedX
		g_playerY = g_containerSize * g_playerNormalizedY		
		g_heading = GetPlayerCameraHeading()
		
		if AUI.Settings.Minimap.rotate then
			g_headingCos = math.cos(g_heading)
			g_headingSin = math.sin(g_heading)
		end
		
		AUI.MapData.playerX = g_playerNormalizedX 
		AUI.MapData.playerY = g_playerNormalizedY		
		AUI.MapData.heading = -g_heading
		
		if AUI.Settings.Minimap.rotate then
			playerPin:SetLocation(g_playerNormalizedX, g_playerNormalizedY)	
			playerPin:SetRotation(0)	
		else
			playerPin:SetLocation(g_playerNormalizedX, g_playerNormalizedY)
			playerPin:SetRotation(g_heading)	
		end
	end
end

local function SetMapToPlayer()
	local offsetX = g_playerX
	local offsetY = g_playerY

	if offsetX <= g_containerHalfWidth then
		offsetX = g_containerHalfWidth
	elseif offsetX >= g_containerSize - g_containerHalfWidth then
		offsetX = g_containerSize - g_containerHalfWidth
	end			

	if offsetY <= g_containerHalfHeight then
		offsetY = g_containerHalfHeight
	elseif offsetY >= g_containerSize - g_containerHalfHeight then
		offsetY = g_containerSize - g_containerHalfHeight
	end		
	
	AUI_MapContainer:ClearAnchors()
	AUI_MapContainer:SetAnchor(TOPLEFT, nil, CENTER, -offsetX, -offsetY)
end

local function SetZoom(zoomValue)
	AUI.Settings.Minimap.zoom[g_currentMapZoneType] = zoomValue

	SetContainerSize()
	RefreshAllTiles()
	AUI.Minimap.Pin.UpdateAllLocationsAndSizes()
end

local function GetZoomStep()
	local zoomStep = 1

	local mapZoneType = GetMapZoneType()
				
	if mapZoneType == "zone" then
		zoomStep = g_zoomStepZone
	elseif mapZoneType == "subzone" then
		zoomStep = g_zommStepSubzone
	elseif mapZoneType == "dungeon" then	
		zoomStep = g_zommStepDungeon
	elseif mapZoneType == "arena" then	
		zoomStep = g_zommStepArena		
	end

	return zoomStep
end

local function SetZoomByStep(step)
	local zoom = AUI.Settings.Minimap.zoom[g_currentMapZoneType] + step
	
	local minZoom = AUI_MINIMAP_MIN_ZOOM_ZONE
	local maxZoom = AUI_MINIMAP_MAX_ZOOM_ZONE

	if g_currentMapZoneType == "subzone" then
		minZoom = AUI_MINIMAP_MIN_ZOOM_SUBZONE 
		maxZoom = AUI_MINIMAP_MAX_ZOOM_SUBZONE 
	elseif g_currentMapZoneType == "dungeon" then
		minZoom = AUI_MINIMAP_MIN_ZOOM_DUNGEON
		maxZoom = AUI_MINIMAP_MAX_ZOOM_DUNGEON	
	elseif g_currentMapZoneType == "arena" then
		minZoom = AUI_MINIMAP_MIN_ZOOM_ARENA
		maxZoom = AUI_MINIMAP_MAX_ZOOM_ARENA			
	end

	if zoom > maxZoom then
		zoom = maxZoom
	end
	
	if zoom < minZoom then
		zoom = minZoom
	end	
	
	if zoom >= minZoom and zoom <= maxZoom then	
		SetZoom(zoom)
	end		
end

local function OnUpdate()
	if not AUI.Minimap.DoesShow() then
		return
	end

	if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then	
		CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")			
	else
		UpdatePlayerPin()

		if g_lastHeading ~= g_heading or g_lastPlayerX ~= g_playerX or g_lastPlayerY ~= g_playerY then
			if AUI.Settings.Minimap.rotate then	
				AUI.Minimap.OnRotate()					
			else
				SetMapToPlayer()
			end
			
			g_lastHeading = g_heading
			g_lastPlayerX = g_playerX
			g_lastPlayerY = g_playerY		
		end
	end
end

function AUI.Minimap.Load()
	if g_isInit then
		return
	end

	g_isInit = true
	
	-- For the default Theme		
	local defaultThemeData = {["Default_Frame"] = true}		
	AUI.Minimap.Theme.Add("default", AUI.L10n.GetString("default"), defaultThemeData)		
	
	-- For the Blank Theme		
	local blankThemeData = {["Default_Frame"] = false}		
	AUI.Minimap.Theme.Add("blank", "Blank", blankThemeData)		
	
	AUI.Minimap.LoadSettings()		

	AUI.Minimap.Pin.Load()
	AUI.Minimap.UI.Load()	
	AUI.WorldMap.Init()	
	
	g_sceneFragment = ZO_SimpleSceneFragment:New(AUI_Minimap_MainWindow)									
	g_sceneFragment.hiddenReasons = ZO_HiddenReasons:New()		
    g_sceneFragment:SetConditional(function() return not AUI.Settings.Minimap.hidden end)
	
	HUD_SCENE:AddFragment(g_sceneFragment)
	HUD_UI_SCENE:AddFragment(g_sceneFragment)
	SIEGE_BAR_SCENE:AddFragment(g_sceneFragment)
	if SIEGE_BAR_UI_SCENE then
		SIEGE_BAR_UI_SCENE:AddFragment(g_sceneFragment)
	end
	
	EVENT_MANAGER:RegisterForUpdate("AUI_Minimap_OnUpdate", 10, OnUpdate)
	
	if AUI.Settings.Minimap.hidden then 
		AUI.Minimap.Hide() 
	else
		AUI.Minimap.Show() 
	end		
end

function AUI.Minimap.Unload()
	AUI.Minimap.Pin.Unload()
	EVENT_MANAGER:UnregisterForUpdate("AUI_Minimap_OnUpdate")
end

function AUI.Minimap.IsLoaded()
	if g_isInit then
		return true
	end
	
	return false
end

function AUI.Minimap.Show()
	g_sceneFragment:Show()	
end

function AUI.Minimap.Hide()
	g_sceneFragment:Hide()
end

function AUI.Minimap.DoesShow()
	return not AUI_Minimap_MainWindow:IsHidden()
end

function AUI.Minimap.Toggle()
	if not g_isInit then
		return
	end

	if AUI.Minimap.DoesShow() then
		AUI.Minimap.Hide()
		AUI.Settings.Minimap.hidden = true
	else
		AUI.Minimap.Show()
		AUI.Settings.Minimap.hidden = false
	end
end

function AUI.Minimap.Refresh()
	if not AUI.Minimap.IsLoaded() then
		return
	end

	SetContainerSize()
	RefreshAllTiles()
	AUI.Minimap.Pin.RefreshPins()
end

function AUI.Minimap.ZoomIn()
	if not AUI.Minimap.IsLoaded() then
		return
	end

	if AUI.Minimap.DoesShow() then
		local zoomStep = GetZoomStep()

		SetZoomByStep(-zoomStep)
	end
end

function AUI.Minimap.ZoomOut()
	if not AUI.Minimap.IsLoaded() then
		return
	end

	if AUI.Minimap.DoesShow() then
		local zoomStep = GetZoomStep()								
				
		SetZoomByStep(zoomStep)
	end
end

function AUI.Minimap.SetCurrentZoomValue()
	if not AUI.Minimap.IsLoaded() then
		return
	end

	g_currentMapZoneType = GetMapZoneType()
	
	local zoomValue = AUI.Settings.Minimap.zoom[g_currentMapZoneType]	
	if not zoomValue then
		zoomValue = 1		
	end
	
	g_currentZoomValue = zoomValue
end

function AUI.Minimap.GetCurrentZoomValue()
	return g_currentZoomValue
end

function AUI.Minimap.GetCurrentMapIndex()
	return AUI.String.ToNumber(GetMapTileTexture())
end

function AUI.Minimap.GetVersion()
	return AUI_MINIMAP_VERSION
end

function AUI.Minimap.OnRotate()
	UpdateAllTileLocations()	
	AUI.Minimap.Pin.UpdateAllLocations()
end

function AUI.Minimap.GetRotationData()
	return g_headingCos, g_headingSin
end

function AUI.Minimap.DoesRotate()
	return AUI.Settings.Minimap.rotate
end

function AUI.Minimap.GetHeading()
	return g_heading
end

function AUI.Minimap.GetMapContainer()
	return AUI_MapContainer
end

function AUI.Minimap.GetMapContainerSize()
	return g_containerSize
end

function AUI.Minimap.GetPlayerNormalizedPosition()
	return g_playerNormalizedX, g_playerNormalizedY
end

function AUI.Minimap.GetPlayerPosition()
	return g_playerX, g_playerY
end

--removed (let it for HarvestMap support)
AUI.MapData = {}
AUI.MapData.playerX = 0
AUI.MapData.playerY = 0
AUI.MapData.heading = 0
AUI.MapData.mapContainerSize = 0

AUI.Minimap.Map = {}
function AUI.Minimap.Map.Refresh()
	AUI.Minimap.Refresh()
end