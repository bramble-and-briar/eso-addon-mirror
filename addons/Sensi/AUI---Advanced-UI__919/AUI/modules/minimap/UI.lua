AUI.Minimap.UI = {}

local g_isInit = false
local gHeightAsWidth = false

local function OnMouseDown(_eventCode, _button, _ctrl, _alt, _shift)
	if _button == 1 and not AUI.Settings.Minimap.lock_window then
		AUI_Minimap_MainWindow:SetMovable(true)
		AUI_Minimap_MainWindow:StartMoving()
	end		
end

local function OnMouseUp(_eventCode, _button, _ctrl, _alt, _shift)
	AUI_Minimap_MainWindow:SetMovable(false)

	if _button == 1 and not AUI.Settings.Minimap.lock_window then	
		_, AUI.Settings.Minimap.anchor.point, _, AUI.Settings.Minimap.anchor.relativePoint, AUI.Settings.Minimap.anchor.offsetX, AUI.Settings.Minimap.anchor.offsetY = AUI_Minimap_MainWindow:GetAnchor()
	end
end

local function OnMouseWheel(self, delta, ctrl, alt, shift)
    if delta > 0 then
		AUI.Minimap.ZoomOut()
    elseif delta < 0 then
        AUI.Minimap.ZoomIn()
    end
end

local function GetLocationAnchorPoints()
	local point = TOP
	local rPoint = TOP

	if AUI.Settings.Minimap.location_Position == "bottom" then
		point = BOTTOM
		rPoint = BOTTOM
	elseif AUI.Settings.Minimap.location_Position == "top" then
		point = TOP	
		rPoint = TOP		
	end	
		
	return point, rPoint
end

local function GetCoordsAnchorPoints()
	local point = TOP
	local rPoint = TOP

	if AUI.Settings.Minimap.coords_Position == "bottom" then
		point = BOTTOM
		rPoint = BOTTOM
	elseif AUI.Settings.Minimap.coords_Position== "top" then
		point = TOP	
		rPoint = TOP		
	end	
		
	return point, rPoint
end

local function GetMapContainerPosition()	
	local paddingX = 0
	local paddingY = 0

	if AUI.Settings.Minimap.preview_locationName then
		if AUI.Settings.Minimap.location_Position == "top" then
			paddingY = AUI.Settings.Minimap.location_FontSize + 5
		end
	end
	
	if AUI.Settings.Minimap.preview_coords then
		if AUI.Settings.Minimap.location_Position == "top" and AUI.Settings.Minimap.coords_Position == "top" then
			paddingY = paddingY + AUI.Settings.Minimap.coords_FontSize + 5
		elseif AUI.Settings.Minimap.coords_Position == "top" then
			paddingY = AUI.Settings.Minimap.coords_FontSize + 5
		end
	end	
		
	return paddingX, paddingY
end

local function GetRootContainerSize()
	local width = AUI.Settings.Minimap.width
	local height = AUI.Settings.Minimap.height

	if AUI.Settings.Minimap.preview_locationName then
		height = (height + AUI.Settings.Minimap.location_FontSize) + 5
	end

	if AUI.Settings.Minimap.preview_coords then
		height = (height + AUI.Settings.Minimap.coords_FontSize) + 5	
	end
		
	return width, height
end

local function SetDimensions()
	local rootWidth, rootHeight = GetRootContainerSize()

	local mapWidth = AUI.Settings.Minimap.width
	
	if gHeightAsWidth then
		AUI.Settings.Minimap.height = AUI.Settings.Minimap.width	
	end
	
	local mapHeight = AUI.Settings.Minimap.height
	
	AUI_Minimap_MainWindow:SetDimensions(rootWidth, rootHeight)	
	AUI_Minimap_MainWindow_Map:SetDimensions(mapWidth, mapHeight)	
end

local function SetPosition(point, rPoint, x, y)
	AUI_Minimap_MainWindow:ClearAnchors()
    AUI_Minimap_MainWindow:SetAnchor(point, nil, rPoint, x, y)

	local point, rPoint = GetCoordsAnchorPoints()
	
	AUI_Coords:ClearAnchors()
	AUI_Coords:SetAnchor(point, AUI_Minimap_MainWindow, rPoint, 0, 0)	
	
	local point, rPoint = GetLocationAnchorPoints()
		
	local locationNamePosY =  0
		
	if AUI.Settings.Minimap.preview_locationName then
		if AUI.Settings.Minimap.location_Position == "top" then
			locationNamePosY = AUI.Settings.Minimap.coords_FontSize + 8
		elseif AUI.Settings.Minimap.location_Position == "bottom" then
			locationNamePosY = AUI.Settings.Minimap.coords_FontSize - 4
		end
	end
	
	AUI_Location_Name:ClearAnchors()
	AUI_Location_Name:SetAnchor(point, AUI_Minimap_MainWindow, rPoint, 0, locationNamePosY)		
	
	local mapX, mapY =  GetMapContainerPosition()
	
	AUI_Minimap_MainWindow_Map:ClearAnchors()
	AUI_Minimap_MainWindow_Map:SetAnchor(TOPLEFT, AUI_Minimap_MainWindow, TOPLEFT, mapX, mapY)
end

local function SetTheme()
	local theme = AUI.Minimap.Theme.GetActive()
	
	if theme ~= nil then
		local showDefaultFrame = theme["Default_Frame"]
	
		if showDefaultFrame then
			AUI_Minimap_MainWindow_MapFrame:SetHidden(false)
		else
			AUI_Minimap_MainWindow_MapFrame:SetHidden(true)
		end
	
		local overlayTexture = theme["Overlay_Texture"]
	
		if overlayTexture ~= nil and not AUI.String.IsEmpty(overlayTexture) then
			AUI_Minimap_MainWindow_Map_Overlay:SetTexture(overlayTexture)
			AUI_Minimap_MainWindow_Map_Overlay:SetHidden(false)
		else
			AUI_Minimap_MainWindow_Map_Overlay:SetHidden(true)
		end
		
		local backgroundTexture = theme["Background_Texture"]
		
		if backgroundTexture ~= nil and not AUI.String.IsEmpty(backgroundTexture) then
			AUI_Minimap_MainWindow_Map_Background:SetTexture(backgroundTexture)
		end	
		
		local rotateTexture = theme["Rotate_Texture"]
		
		if rotateTexture ~= nil and not AUI.String.IsEmpty(rotateTexture) then
			AUI_Minimap_MainWindow_Map_Rotate:SetTexture(rotateTexture)
			AUI_Minimap_MainWindow_Map_Rotate:SetHidden(false)
		else
			AUI_Minimap_MainWindow_Map_Rotate:SetHidden(true)
		end		
	
		gHeightAsWidth = theme["Fixed_Size"]		
	end
end

local function UpdateLocationName()
	local locationName = GetPlayerLocationName()
	if not AUI.String.IsEmpty(locationName) then
		AUI_Location_Name:SetText(AUI.String.FirstToUpper(GetPlayerLocationName()))
	end
end

local function UpdateCoords()
	local x, y = AUI.Minimap.GetPlayerNormalizedPosition()

	if x ~= lastPlayerX or y ~= lastPlayerY then
		x = AUI.Math.Round(x * 10000) / 100
		y = AUI.Math.Round(y * 10000) / 100

		AUI_Coords:SetText("X: " .. x .. "   Y: " .. y)	
	
		lastPlayerX = x
		lastPlayerY = y
	end
end
local function OnUpdate()
	if AUI.Settings.Minimap.preview_coords then
		UpdateCoords()		
	end
	
	if AUI.Settings.Minimap.preview_locationName then
		UpdateLocationName()	
	end		
end

function AUI.Minimap.UI.Update()
	if not g_isInit or not AUI.Minimap.IsLoaded() then
		return
	end

	SetDimensions()
	SetPosition(AUI.Settings.Minimap.anchor.point, AUI.Settings.Minimap.anchor.relativePoint, AUI.Settings.Minimap.anchor.offsetX, AUI.Settings.Minimap.anchor.offsetY)

	AUI_Location_Name:SetFont(AUI.Settings.Minimap.location_fontArt .. "|" .. AUI.Settings.Minimap.location_FontSize .. "|" .. AUI.Settings.Minimap.location_FontStyle)	
	AUI_Location_Name:SetHidden(not AUI.Settings.Minimap.preview_locationName)
	AUI_Location_Name:SetColor(AUI.Settings.Minimap.location_FontColor.r, AUI.Settings.Minimap.location_FontColor.g, AUI.Settings.Minimap.location_FontColor.b, AUI.Settings.Minimap.location_FontColor.a)		
		
	AUI_Coords:SetFont(AUI.Settings.Minimap.coords_fontArt .. "|" .. AUI.Settings.Minimap.coords_FontSize .. "|" .. AUI.Settings.Minimap.coords_FontStyle)	
	AUI_Coords:SetHidden(not AUI.Settings.Minimap.preview_coords)
	AUI_Coords:SetColor(AUI.Settings.Minimap.coords_FontColor.r, AUI.Settings.Minimap.coords_FontColor.g, AUI.Settings.Minimap.coords_FontColor.b, AUI.Settings.Minimap.coords_FontColor.a)		
	
	local mapAlpha = 1
	if AUI.Settings.Minimap.opacity then
		mapAlpha = AUI.Settings.Minimap.opacity
	end
	
	AUI_Minimap_MainWindow:SetAlpha(mapAlpha)
	
	SetTheme()	
end

function AUI.Minimap.UI.Load()
	if g_isInit then
		return
	end

	g_isInit = true
	
	SetTheme()
	
	AUI_Minimap_MainWindow:SetHandler("OnMouseDown", OnMouseDown)
	AUI_Minimap_MainWindow:SetHandler("OnMouseUp", OnMouseUp)
	AUI_Minimap_MainWindow:SetHandler("OnMouseWheel", OnMouseWheel) 

	EVENT_MANAGER:RegisterForUpdate("AUI_Minimap_UI_OnUpdate", 200, OnUpdate)
end

