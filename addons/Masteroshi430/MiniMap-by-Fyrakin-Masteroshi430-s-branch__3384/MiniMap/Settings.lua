------------------------------------------------------------
-- Settings
------------------------------------------------------------
function MM_SetPPStyle(value)
	if value == nil then return end
	if value == "Classic" then -- Upgrade from version 2.24 or earlier
		value = GetString(SI_MM_STRING_CLASSIC)
	end
	if value == "Separate Player & Camera" then -- Upgrade from version 2.24 or earlier
		value = GetString(SI_MM_STRING_PLAYERANDCAMERA)
	end
	FyrMM.SV.PPStyle = value
	if value == GetString(SI_MM_STRING_PLAYERANDCAMERA) then
		Fyr_MM_Camera:SetHidden(false)
	else
		Fyr_MM_Camera:SetHidden(true)
	end
end

function MM_Upgrade_MapList()
	if FyrMM.SV.MapSettings == nil then return end
	FyrMM.SV.MapTable = {}
	for i, v in pairs(FyrMM.SV.MapSettings) do
		FyrMM.SV.MapTable[v.FileName] = {ZoomLevel = v.ZoomLevel, MapSize = v.MapSize}
	end
	FyrMM.SV.MapSettings = nil
end

function MM_SetPPTextures(value)
	if value == nil then return end
	FyrMM.SV.PPTextures = value
	if value == "ESO UI Worldmap" then
		Fyr_MM_Player:SetTexture("EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds")
		Fyr_MM_Camera:SetTexture("/MiniMap/Textures/ui-worldmapplayercamerapip.dds")
		Fyr_MM_Camera:SetBlendMode(TEX_BLEND_MODE_ADD)
		Fyr_MM_Player:SetDimensions(20,20)
		Fyr_MM_Player:SetScale(1)
		Fyr_MM_Camera:SetScale(1)
	else
		if value == "Vixion Regular" then
			Fyr_MM_Player:SetTexture("/MiniMap/Textures/VixionPlayerPointer_arrow.dds")
			Fyr_MM_Camera:SetTexture("/MiniMap/Textures/VixionCameraPointer_glow.dds")
			Fyr_MM_Camera:SetBlendMode(TEX_BLEND_MODE_ADD)
			Fyr_MM_Player:SetScale(1)
			Fyr_MM_Camera:SetScale(1)
		else
			if value == "Vixion Gold" then
				Fyr_MM_Player:SetTexture("/MiniMap/Textures/VixionPlayerPointer_arrow_gold.dds")
				Fyr_MM_Camera:SetTexture("/MiniMap/Textures/VixionCameraPointer_glow.dds")
				Fyr_MM_Camera:SetBlendMode(TEX_BLEND_MODE_ADD)
				Fyr_MM_Player:SetScale(1)
				Fyr_MM_Camera:SetScale(1)
			else
				Fyr_MM_Player:SetTexture("/MiniMap/Textures/PlayerPointer.dds")
				Fyr_MM_Camera:SetTexture("/MiniMap/Textures/CameraPointer.dds")
				Fyr_MM_Camera:SetBlendMode(TEX_BLEND_MODE_ADD)
				local scale = 0.75
				Fyr_MM_Player:SetScale(scale)
				Fyr_MM_Camera:SetScale(scale)
			end
		end
	
		if FyrMM.SV.PinScale ~= nil then
			local scale = FyrMM.SV.PinScale/100
			Fyr_MM_Player:SetScale(scale)
		    Fyr_MM_Camera:SetScale(scale)
		end

	end
	Fyr_MM_Player:SetHidden(false)
end


function MM_SetBorderPins(value)
	if value == nil then return end
	FyrMM.SV.BorderPins = value
	if not FyrMM.Initialized then return end
	Fyr_MM_Axis_Control:SetHidden(not (FyrMM.SV.RotateMap or FyrMM.SV.BorderPins))
	Fyr_MM_Axis_Control:SetTopmost(FyrMM.SV.RotateMap or FyrMM.SV.BorderPins)
	FyrMM.PlaceBorderPins()
end

function MM_SetUseOriginalAPI(value)
	if value == nil then return end
	FyrMM.SV.UseOriginalAPI = value
	FyrMM.API_Check()
end

function MM_SetShowUnexploredPins(value)
	if value == nil then return end
	FyrMM.SV.ShowUnexploredPins = value
	if FyrMM.Initialized then
		FyrMM.Reload()
	end
end

function MM_SetMapRefreshRate(value)
	if value == nil then return end
	FyrMM.SV.MapRefreshRate = value
	if not FyrMM.Initialized then return end
	EVENT_MANAGER:UnregisterForUpdate("OnUpdateFyrMMMapPosition")
	EVENT_MANAGER:RegisterForUpdate("OnUpdateFyrMMMapPosition", FyrMM.SV.MapRefreshRate, FyrMM.PositionUpdate)
end

function MM_SetPinRefreshRate(value)
	if value == nil then return end
	FyrMM.SV.PinRefreshRate = value
	if not FyrMM.Initialized then return end
	EVENT_MANAGER:UnregisterForUpdate("OnUpdateFyrMMMapPins")
	EVENT_MANAGER:RegisterForUpdate("OnUpdateFyrMMMapPins", FyrMM.SV.PinRefreshRate, FyrMM.PinUpdate)
end

function MM_SetViewRefreshRate(value)
	if value == nil then return end
	FyrMM.SV.ViewRefreshRate = value
	if not FyrMM.Initialized then return end
	EVENT_MANAGER:UnregisterForUpdate("OnUpdateFyrMMMapView")
	EVENT_MANAGER:RegisterForUpdate("OnUpdateFyrMMMapView", FyrMM.SV.ViewRefreshRate, FyrMM.UpdateMapTiles)
end

-- function MM_SetZoneRefreshRate(value)
	-- if value == nil then return end
	-- FyrMM.SV.ZoneRefreshRate = value
	-- if not FyrMM.Initialized then return end
	-- EVENT_MANAGER:UnregisterForUpdate("OnUpdateFyrMMMapZone")
	-- EVENT_MANAGER:RegisterForUpdate("OnUpdateFyrMMMapZone", FyrMM.SV.ZoneRefreshRate, FyrMM.ZoneUpdate)
-- end

-- function MM_SetKeepNetworkRefreshRate(value)
	-- if value == nil then return end
	-- if value < 900 then value = 2000 end
	-- FyrMM.SV.KeepNetworkRefreshRate = value
	-- if not FyrMM.Initialized then return end
	-- EVENT_MANAGER:UnregisterForUpdate("OnUpdateFyrMMMapKeepNetwork")
	-- EVENT_MANAGER:RegisterForUpdate("OnUpdateFyrMMMapKeepNetwork", FyrMM.SV.KeepNetworkRefreshRate, FyrMM.UpdateKeepNetwork)
-- end


function MM_GetMapHeight()
	local mheight = Fyr_MM_Scroll:GetHeight()
	return mheight
end

function MM_GetMapWidth()
	local mwidth = Fyr_MM_Scroll:GetWidth()
	return mwidth
end

function MM_SetMapHeight(value)
if value == nil or FyrMM.SV.WheelMap then return end
if FyrMM.SV.LockResizing and FyrMM.Initialized then return end 
	FyrMM.SV.MapHeight = value
	Fyr_MM_Scroll:SetHeight(value)
	Fyr_MM_Border:SetHeight(value+8)
	Fyr_MM:SetHeight(value)
	Fyr_MM_Scroll_Fill:SetHeight(value)
	FyrMM.MapHalfDiagonal()
	MM_RearrangeMenu()
end

function MM_SetMapWidth(value)
if value == nil then return end
	if FyrMM.SV.LockResizing and FyrMM.Initialized then return end 
	FyrMM.SV.MapWidth = value
	Fyr_MM_Scroll:SetWidth(value)
	Fyr_MM_Border:SetWidth(value+8)
	Fyr_MM_Frame_Wheel:SetDimensions(value+8, value+8)
	Fyr_MM_Frame_RoundMenu:SetDimensions(value, value/4)
	Fyr_MM_Frame_RoundMenu:ClearAnchors()
	Fyr_MM_Frame_RoundMenu:SetAnchor(TOPLEFT, Fyr_MM, TOPLEFT, 0, value - value/9)
	Fyr_MM_Frame_SquareMenu:SetDimensions(value, value/4)
	Fyr_MM_Wheel_Background:SetDimensions(value+8, value+8)
	Fyr_MM:SetWidth(value)
	Fyr_MM_Scroll_Fill:SetWidth(value)
	if FyrMM.SV.WheelMap then
		FyrMM.SV.MapHeight = value
		Fyr_MM_Scroll:SetHeight(value)
		Fyr_MM_Border:SetHeight(value+8)
		Fyr_MM:SetHeight(value)
		Fyr_MM_Scroll_Fill:SetHeight(value)
		FyrMM.MapHalfDiagonal()
	end
	MM_RearrangeMenu()
end

function MM_GetPinScale()
	local scale = FyrMM.SV.PinScale
	return scale
end

function MM_SetPinScale(value)
if value == nil then return end
	FyrMM.pScale = value
	FyrMM.pScalePercent = FyrMM.pScale / 100
	MM_SetPPTextures(FyrMM.SV.PPTextures)
	FyrMM.SV.PinScale = value
end

function MM_GetMapAlpha()
	return FyrMM.SV.MapAlpha
end

function MM_SetMapAlpha(value)
if value == nil then return end
	local newAlphaPercent = value / 100
	FyrMM.SV.MapAlpha = value
	Fyr_MM_Wheel_Background:SetAlpha(newAlphaPercent+.10)
	Fyr_MM:SetAlpha(newAlphaPercent)
	Fyr_MM_Scroll_WheelWE:SetAlpha(newAlphaPercent)
	Fyr_MM_Scroll_WheelNS:SetAlpha(newAlphaPercent)
	Fyr_MM_Scroll_WheelCenter:SetAlpha(newAlphaPercent)
end

function MM_GetShowPosition()
	return FyrMM.SV.ShowPosition
end

function MM_SetShowPosition(value)
if value == nil then return end
	FyrMM.SV.ShowPosition = value
	Fyr_MM_Coordinates:SetHidden(not FyrMM.SV.ShowPosition)
	if not FyrMM.SV.ShowPosition then MM_SetPositionBackground(false) end
end

function MM_GetMapZoom()
	local MM_zoom = FyrMM.SV.MapZoom
	if MM_zoom == nil then
		FyrMM.SV.MapZoom = FyrMM_DEFAULT_ZOOM_LEVEL
		MM_zoom = FyrMM_DEFAULT_ZOOM_LEVEL
	end

	return MM_zoom
end

function MM_GetHideCompass()
	return FyrMM.SV.hideCompass
end

function MM_SetHideCompass(value)
    if value == nil then return end
	FyrMM.SV.hideCompass = value
	ZO_CompassFrame:SetHidden(not value)
	if FyrMM.SV.hideCompass == true then
	   FyrMM.SV.miniCompassOption = false
	   FyrMM.SV.ShowCompassInAvAZoneOnly = false
    else
        FyrMM.compassDefaultWidth = FyrMM.compassDefaultWidth or 650	
        ZO_CompassFrame:SetWidth(FyrMM.compassDefaultWidth) 	
	end
end

function MM_GetShowCompassInAvAZoneOnly()
	return FyrMM.SV.ShowCompassInAvAZoneOnly
end

function MM_SetShowCompassInAvAZoneOnly(value)
    if value == nil then return end
	FyrMM.SV.ShowCompassInAvAZoneOnly = value
	if FyrMM.SV.ShowCompassInAvAZoneOnly == true then
	   FyrMM.SV.hideCompass = false
	end
end

function MM_GetMiniCompassOption()
    return FyrMM.SV.miniCompassOption
end

function MM_SetMiniCompassOption(value)
if value == nil then return end
	FyrMM.SV.miniCompassOption = value
	if FyrMM.SV.miniCompassOption == false then
		ZO_CompassFrame:ClearAnchors()
		ZO_CompassFrame:SetAnchor(9,GuiRoot,nil,-630,40)
		ZO_CompassFrame:SetMovable(false)
		ZO_CompassFrame:SetMouseEnabled(false)
		ZO_CompassFrame:SetClampedToScreen(false)
		ZO_CompassFrame:SetScale(1)
		ZO_CompassCenterOverPinLabel:SetScale(1)
		ZO_CompassFrameLeft:SetDimensions(10,35)
		ZO_CompassFrameRight:SetDimensions(10,35)
		ZO_CompassFrame:SetDimensions(650,35)
		ZO_CompassCenterOverPinLabel:SetHidden(false)
		ZO_Compass:SetScale(1)
    end	
end

function MM_SetMiniCompassLocation(value)
	if value == nil then return end
	FyrMM.SV.miniCompassLocation = value
end

function MM_GetNoBossBar()
    return	FyrMM.SV.miniCompassNoBossBar
end

function MM_SetNoBossBar(value)
if value == nil then return end
	FyrMM.SV.miniCompassNoBossBar = value
end

function MM_SetRotateMap(value)
if value == nil then return end
	FyrMM.SV.RotateMap = value
	Fyr_MM_Axis_Control:SetHidden(not FyrMM.SV.RotateMap)
	FyrMM.AxisPins()
	if FyrMM.SV.WheelMap and not FyrMM.SV.RotateMap then
		Fyr_MM_Frame_Wheel:SetTextureRotation(0)
		Fyr_MM_Frame_Wheel:SetTextureCoordsRotation(0)
	end
	if not FyrMM.SV.RotateMap then
		FyrMM.UpdateMapTiles()
		FyrMM.Reload()
	end
end

function MM_SetCardinalPoints(value)
if value == nil then return end
   FyrMM.SV.CardinalPoints = value
end

function MM_RearrangeMenu()
	local scale = zo_round(Fyr_MM:GetWidth()/3.41)/100
	Fyr_MM_Time:SetScale(scale)
	Fyr_MM_ZoomIn:SetScale(scale)
	Fyr_MM_ZoomOut:SetScale(scale)
	Fyr_MM_PinDown:SetScale(scale)
	Fyr_MM_PinUp:SetScale(scale)
	Fyr_MM_Reload:SetScale(scale)
	Fyr_MM_Settings:SetScale(scale)
	if FyrMM.SV.WheelMap then
		Fyr_MM_Time:ClearAnchors()
		Fyr_MM_Time:SetDrawLayer(4)
		Fyr_MM_Time:SetAnchor(CENTER, Fyr_MM_Frame_RoundMenu, CENTER, 0, Fyr_MM_Frame_RoundMenu:GetHeight()/5.5)
		Fyr_MM_PinDown:ClearAnchors()
		Fyr_MM_PinDown:SetAnchor(CENTER, Fyr_MM_Frame_RoundMenu, CENTER, -Fyr_MM_Time:GetWidth()/1.4-Fyr_MM_ZoomIn:GetWidth()/1.5, Fyr_MM_Frame_RoundMenu:GetHeight()/11)
		Fyr_MM_PinUp:ClearAnchors()
		Fyr_MM_PinUp:SetAnchor(CENTER, Fyr_MM_Frame_RoundMenu, CENTER, -Fyr_MM_Time:GetWidth()/1.4-Fyr_MM_ZoomIn:GetWidth()/1.5, Fyr_MM_Frame_RoundMenu:GetHeight()/11)
		Fyr_MM_Reload:ClearAnchors()
		Fyr_MM_Reload:SetAnchor(CENTER, Fyr_MM_Frame_RoundMenu, CENTER, Fyr_MM_Time:GetWidth()/1.4+Fyr_MM_ZoomOut:GetWidth()/1.5, Fyr_MM_Frame_RoundMenu:GetHeight()/11)
		Fyr_MM_Settings:ClearAnchors()
		Fyr_MM_Settings:SetAnchor(CENTER, Fyr_MM_Frame_RoundMenu, CENTER, Fyr_MM_Time:GetWidth()/1.4+2*(Fyr_MM_ZoomOut:GetWidth()/1.5), -Fyr_MM_Frame_RoundMenu:GetHeight()/32)
		Fyr_MM_ZoomIn:ClearAnchors()
		Fyr_MM_ZoomIn:SetAnchor(CENTER, Fyr_MM_Frame_RoundMenu, CENTER, -Fyr_MM_Time:GetWidth()/1.4, Fyr_MM_Frame_RoundMenu:GetHeight()/6.5)
		Fyr_MM_ZoomOut:ClearAnchors()
		Fyr_MM_ZoomOut:SetAnchor(CENTER, Fyr_MM_Frame_RoundMenu, CENTER, Fyr_MM_Time:GetWidth()/1.4, Fyr_MM_Frame_RoundMenu:GetHeight()/6.5)
		Fyr_MM_Menu:SetDimensions(Fyr_MM_Frame_RoundMenu:GetDimensions())
		Fyr_MM_Menu:ClearAnchors()
		Fyr_MM_Menu:SetAnchor(TOPLEFT, Fyr_MM, TOPLEFT, 0, Fyr_MM:GetHeight() - Fyr_MM:GetHeight()/9)
	else
		Fyr_MM_Frame_SquareMenu:ClearAnchors()
		Fyr_MM_Frame_SquareMenu:SetAnchor(TOPLEFT, Fyr_MM, TOPLEFT, 0, Fyr_MM:GetHeight() - Fyr_MM_Frame_SquareMenu:GetHeight()/4.5)
		Fyr_MM_Time:ClearAnchors()
		Fyr_MM_Time:SetDrawLayer(4)
		Fyr_MM_Time:SetAnchor(CENTER, Fyr_MM_Frame_SquareMenu, CENTER, 0, Fyr_MM_Frame_SquareMenu:GetHeight()/32)
		Fyr_MM_PinDown:ClearAnchors()
		Fyr_MM_PinDown:SetAnchor(CENTER, Fyr_MM_Frame_SquareMenu, CENTER, -Fyr_MM_Time:GetWidth()/1.4-Fyr_MM_ZoomIn:GetWidth()/1.5, Fyr_MM_Frame_SquareMenu:GetHeight()/48)
		Fyr_MM_PinUp:ClearAnchors()
		Fyr_MM_PinUp:SetAnchor(CENTER, Fyr_MM_Frame_SquareMenu, CENTER, -Fyr_MM_Time:GetWidth()/1.4-Fyr_MM_ZoomIn:GetWidth()/1.5, Fyr_MM_Frame_SquareMenu:GetHeight()/48)
		Fyr_MM_Reload:ClearAnchors()
		Fyr_MM_Reload:SetAnchor(CENTER, Fyr_MM_Frame_SquareMenu, CENTER, Fyr_MM_Time:GetWidth()/1.4+Fyr_MM_ZoomOut:GetWidth()/1.5, Fyr_MM_Frame_SquareMenu:GetHeight()/48)
		Fyr_MM_Settings:ClearAnchors()
		Fyr_MM_Settings:SetAnchor(CENTER, Fyr_MM_Frame_SquareMenu, CENTER, Fyr_MM_Time:GetWidth()/1.4+2*(Fyr_MM_ZoomOut:GetWidth()/1.5), Fyr_MM_Frame_SquareMenu:GetHeight()/48)
		Fyr_MM_ZoomIn:ClearAnchors()
		Fyr_MM_ZoomIn:SetAnchor(CENTER, Fyr_MM_Frame_SquareMenu, CENTER, -Fyr_MM_Time:GetWidth()/1.4, Fyr_MM_Frame_SquareMenu:GetHeight()/48)
		Fyr_MM_ZoomOut:ClearAnchors()
		Fyr_MM_ZoomOut:SetAnchor(CENTER, Fyr_MM_Frame_SquareMenu, CENTER, Fyr_MM_Time:GetWidth()/1.4, Fyr_MM_Frame_SquareMenu:GetHeight()/48)
		Fyr_MM_Menu:SetDimensions(Fyr_MM_Frame_SquareMenu:GetDimensions())
		Fyr_MM_Menu:ClearAnchors()
		Fyr_MM_Menu:SetAnchor(TOPLEFT, Fyr_MM, TOPLEFT, 0, Fyr_MM:GetHeight() - Fyr_MM_Frame_SquareMenu:GetHeight()/4.5)
	end
end

function MM_SetWheelMap(value)
if value == nil then return end
	if value ~= FyrMM.SV.WheelMap and Fyr_MM:GetWidth() ~= Fyr_MM:GetHeight() then
		FyrMM.SV.WheelMap = value
		MM_SetMapWidth(Fyr_MM:GetWidth())
	end
	FyrMM.SV.WheelMap = value
	Fyr_MM_Border:SetHidden(FyrMM.SV.WheelMap)
	Fyr_MM_Frame_Wheel:SetHidden(not FyrMM.SV.WheelMap)
	Fyr_MM_Wheel_Background:SetHidden(not FyrMM.SV.WheelMap)
	Fyr_MM_Frame_RoundMenu:SetHidden(not FyrMM.SV.WheelMap)
	Fyr_MM_Frame_SquareMenu:SetHidden(FyrMM.SV.WheelMap)
	Fyr_MM_Scroll_Fill:SetHidden(FyrMM.SV.WheelMap)
	MM_RearrangeMenu()
	FyrMM.UpdateMapTiles(true)
	FyrMM.Reload()
	Fyr_MM_Frame_Wheel:SetHidden(not FyrMM.SV.WheelMap)
	Fyr_MM_Frame_Control:SetHidden(not FyrMM.SV.WheelMap)
	if FyrMM.SV.WheelMap then
		FyrMM.Show_WheelScrolls()
	end
end

function MM_GetShowBorder()
	return FyrMM.SV.ShowBorder
end

function MM_SetShowBorder(value)
if value == nil then return end
	FyrMM.SV.ShowBorder = value
	if FyrMM.SV.ShowBorder ~= true then Fyr_MM_Border:SetAlpha(0) else Fyr_MM_Border:SetAlpha(100) end
end

function MM_GetHeading()
	return FyrMM.SV.Heading
end

function MM_SetHeading(value)
if value == nil then return end
	FyrMM.SV.Heading = value
end

function MM_GetMapHeading()
	return FyrMM.SV.MapHeading
end

function MM_SetMapHeading(value)
if value == nil then return end
	FyrMM.SV.MapHeading = value
end

-- function MM_GetClampedToScreen()
 -- return FyrMM.SV.ClampedToScreen
-- end

-- function MM_SetClampedToScreen(value)
-- if value == nil then return end
 -- FyrMM.SV.ClampedToScreen = value
 -- Fyr_MM:SetClampedToScreen(value)
-- end

function MM_GetMapRefreshRate()
 return FyrMM.SV.MapRefreshRate
end

function MM_GetPinRefreshRate()
 return FyrMM.SV.PinRefreshRate
end

function MM_GetViewRefreshRate()
 return FyrMM.SV.ViewRefreshRate
end

-- function MM_GetZoneRefreshRate()
 -- return FyrMM.SV.ZoneRefreshRate
-- end

-- function MM_GetKeepNetworkRefreshRate()
 -- return FyrMM.SV.KeepNetworkRefreshRate
-- end

function MM_GetPinTooltips()
	return FyrMM.SV.PinTooltips
end

function MM_SetBorderPinsOnlyAssisted(value)
	if value == nil then return end
	FyrMM.SV.BorderPinsOnlyAssisted = value
	if not FyrMM.Initialized then return end
	FyrMM.PlaceBorderPins()
end

function MM_SetBorderPinsOnlyLeader(value)
if value == nil then return end
	FyrMM.SV.BorderPinsOnlyLeader = value
	if not FyrMM.Initialized then return end
	FyrMM.PlaceBorderPins()
end

function MM_SetBorderPinsWaypoint(value)
if value == nil then return end
	FyrMM.SV.BorderPinsWaypoint = value
	if not FyrMM.Initialized then return end
	FyrMM.PlaceBorderPins()
end

function MM_SetPinTooltips(value)
if value == nil then return end
	FyrMM.SV.PinTooltips = value
end

function MM_GetMapStepping()
	if FyrMM.SV.MapStepping == nil then
		FyrMM.SV.MapStepping = 2
	end
	return FyrMM.SV.MapStepping
end


function MM_SetMapStepping(value)
if value == nil then return end
	FyrMM.SV.MapStepping = value
end


function MM_GetFastTravelEnabled()
	return FyrMM.SV.FastTravelEnabled
end

function MM_SetFastTravelEnabled(value)
if value == nil then return end
	FyrMM.SV.FastTravelEnabled = value
end

function MM_GetHidePvPPins()
	return FyrMM.SV.HidePvPPins
end

function MM_SetHidePvPPins(value)
    if value == nil then return end
	FyrMM.SV.HidePvPPins = value

    if FyrMM.SV.HidePvPPins then 
	     FyrMM.KeepNetworkCleanupReminder(1, Fyr_MM_Scroll_Map_Keeps)
	     FyrMM.KeepNetworkCleanupReminder(1, Fyr_MM_Scroll_Map_Keeps_Under_Attack)
		 FyrMM.KeepNetworkCleanupReminder(1, Fyr_MM_Scroll_Map_ForwardCamps)
		 FyrMM.KeepNetworkCleanupReminder(1, Fyr_MM_Scroll_Map_Kill_Locations)
		 FyrMM.KeepNetworkCleanupReminder(1, Fyr_MM_Scroll_Map_Objectives)
	else FyrMM.RequestKeepRefresh()
	end
end

function MM_GetMouseWheel()
	return FyrMM.SV.MouseWheel
end

function MM_SetMouseWheel(value)
if value == nil then return end
	FyrMM.SV.MouseWheel = value
end

function MM_GetHideZoneLabel()
	return FyrMM.SV.HideZoneLabel
end

function MM_SetHideZoneLabel(value)
if value == nil then return end
	FyrMM.SV.HideZoneLabel = value
	Fyr_MM_ZoneFrame:SetHidden(value)
end

function MM_SetInCombatAutoHide(value)
if value == nil then return end
	FyrMM.SV.InCombatAutoHide = value
end

function MM_SetAfterCombatUnhideDelay(value)
if value == nil then return end
	FyrMM.SV.AfterCombatUnhideDelay = value
end

function MM_SetInHouseAutoHide(value)
if value == nil then return end
	FyrMM.SV.InHouseAutoHide = value
end

function MM_SetInEndlessDungeonAutoHide(value)
if value == nil then return end
	FyrMM.SV.InEndlessDungeonAutoHide = value
end

function MM_GetHideZoomLevel()
	return FyrMM.SV.HideZoomLevel
end

function MM_SetHideZoomLevel(value)
if value == nil then return end
	FyrMM.SV.HideZoomLevel = value
	if FyrMM.SV.HideZoomLevel == true then Fyr_MM_ZoomLevel:SetAlpha(0) else Fyr_MM_ZoomLevel:SetAlpha(100) end
end

function  MM_SetShowClock(value)
if value == nil then return end
	FyrMM.SV.ShowClock = value
end

function  MM_SetLeaderPin(value)
if value == nil then return end
	FyrMM.SV.LeaderPin = value
end

function  MM_SetLeaderPinSize(value)
if value == nil then return end
	FyrMM.SV.LeaderPinSize = value
end

function MM_SetLeaderPinColor(r, g, b, a)
if r == nil then return end
	FyrMM.SV.LeaderPinColor.r = r
	FyrMM.SV.LeaderPinColor.g = g
	FyrMM.SV.LeaderPinColor.b = b
	FyrMM.SV.LeaderPinColor.a = a
end

function MM_SetLeaderDeadPinColor(r, g, b, a)
if r == nil then return end
	FyrMM.SV.LeaderDeadPinColor.r = r
	FyrMM.SV.LeaderDeadPinColor.g = g
	FyrMM.SV.LeaderDeadPinColor.b = b
	FyrMM.SV.LeaderDeadPinColor.a = a
end

function  MM_SetMemberPin(value)
if value == nil then return end
	FyrMM.SV.MemberPin = value
end

function MM_SetLockResizing(value)
	if value == nil then return end
	FyrMM.SV.LockResizing = value
	if FyrMM.SV.LockResizing then
		Fyr_MM_PinDown:SetHidden(true)
		Fyr_MM_PinUp:SetHidden(false)
	else
		Fyr_MM_PinDown:SetHidden(false)
		Fyr_MM_PinUp:SetHidden(true)
	end
end

function  MM_SetMemberPinSize(value)
if value == nil then return end
	FyrMM.SV.MemberPinSize = value
end

function MM_SetMemberPinColor(r, g, b, a)
if r == nil then return end
	FyrMM.SV.MemberPinColor.r = r
	FyrMM.SV.MemberPinColor.g = g
	FyrMM.SV.MemberPinColor.b = b
	FyrMM.SV.MemberPinColor.a = a
end

function MM_SetMemberDeadPinColor(r, g, b, a)
if r == nil then return end
	FyrMM.SV.MemberDeadPinColor.r = r
	FyrMM.SV.MemberDeadPinColor.g = g
	FyrMM.SV.MemberDeadPinColor.b = b
	FyrMM.SV.MemberDeadPinColor.a = a
end

function MM_SetDpsPinColor(r, g, b, a)
if r == nil then return end
	FyrMM.SV.MemberRolesDpsColor.r = r
	FyrMM.SV.MemberRolesDpsColor.g = g
	FyrMM.SV.MemberRolesDpsColor.b = b
	FyrMM.SV.MemberRolesDpsColor.a = a
end

function MM_SetDpsDeadPinColor(r, g, b, a)
if r == nil then return end
	FyrMM.SV.MemberRolesDeadDpsColor.r = r
	FyrMM.SV.MemberRolesDeadDpsColor.g = g
	FyrMM.SV.MemberRolesDeadDpsColor.b = b
	FyrMM.SV.MemberRolesDeadDpsColor.a = a
end

function MM_SetHealPinColor(r, g, b, a)
if r == nil then return end
	FyrMM.SV.MemberRolesHealColor.r = r
	FyrMM.SV.MemberRolesHealColor.g = g
	FyrMM.SV.MemberRolesHealColor.b = b
	FyrMM.SV.MemberRolesHealColor.a = a
end

function  MM_SetHealDeadPinColor(r, g, b, a)
if r == nil then return end
	FyrMM.SV.MemberRolesDeadHealColor.r = r
	FyrMM.SV.MemberRolesDeadHealColor.g = g
	FyrMM.SV.MemberRolesDeadHealColor.b = b
	FyrMM.SV.MemberRolesDeadHealColor.a = a
end

function MM_SetTankPinColor(r, g, b, a)
if r == nil then return end
	FyrMM.SV.MemberRolesTankColor.r = r
	FyrMM.SV.MemberRolesTankColor.g = g
	FyrMM.SV.MemberRolesTankColor.b = b
	FyrMM.SV.MemberRolesTankColor.a = a
end

function MM_SetTankDeadPinColor(r, g, b, a)
if r == nil then return end
	FyrMM.SV.MemberRolesDeadTankColor.r = r
	FyrMM.SV.MemberRolesDeadTankColor.g = g
	FyrMM.SV.MemberRolesDeadTankColor.b = b
	FyrMM.SV.MemberRolesDeadTankColor.a = a
end

function MM_SetUndiscoveredPOIPinColor(r, g, b, a)
if r == nil then return end
	FyrMM.SV.UndiscoveredPOIPinColor.r = r
	FyrMM.SV.UndiscoveredPOIPinColor.g = g
	FyrMM.SV.UndiscoveredPOIPinColor.b = b
	FyrMM.SV.UndiscoveredPOIPinColor.a = a
end

function MM_SetMapSettings(Table)
	if Table == nil then return end
	FyrMM.SV.MapSettings = Table
end

function MM_SetZoneNameColor(r, g, b, a)
if r == nil then return end
	FyrMM.SV.ZoneNameColor.r = r
	FyrMM.SV.ZoneNameColor.g = g
	FyrMM.SV.ZoneNameColor.b = b
	FyrMM.SV.ZoneNameColor.a = a
	Fyr_MM_Zone:SetColor(r, g, b, a)
	Fyr_MM_Axis_N_Label:SetColor(r, g, b, a)
	Fyr_MM_Axis_NE_Label:SetColor(r, g, b, a)
	Fyr_MM_Axis_E_Label:SetColor(r, g, b, a)
	Fyr_MM_Axis_SE_Label:SetColor(r, g, b, a)
	Fyr_MM_Axis_S_Label:SetColor(r, g, b, a)
	Fyr_MM_Axis_SW_Label:SetColor(r, g, b, a)
	Fyr_MM_Axis_W_Label:SetColor(r, g, b, a)
	Fyr_MM_Axis_NW_Label:SetColor(r, g, b, a)
end

function MM_SetPositionColor(r, g, b, a)
if r == nil then return end
	FyrMM.SV.PositionColor.r = r
	FyrMM.SV.PositionColor.g = g
	FyrMM.SV.PositionColor.b = b
	FyrMM.SV.PositionColor.a = a
	Fyr_MM_Position:SetColor(r, g, b, a)
end

function MM_SetSpeedColor(r, g, b, a)
if r == nil then return end
	FyrMM.SV.SpeedColor.r = r
	FyrMM.SV.SpeedColor.g = g
	FyrMM.SV.SpeedColor.b = b
	FyrMM.SV.SpeedColor.a = a
	Fyr_MM_SpeedLabel:SetColor(r, g, b, a)
end

function MM_SetCoordinatesLocation(value)
	if value == nil then return end
	FyrMM.SV.CoordinatesLocation = value
	if FyrMM.SV.CoordinatesLocation == "Free" then
			Fyr_MM_Coordinates:SetMovable(true)
			Fyr_MM_Coordinates:SetMouseEnabled(true)
			if FyrMM.SV.CoordinatesAnchor ~= nil then
				MM_SetCoordinatesAnchor(FyrMM.SV.CoordinatesAnchor)
			end
	else
		if FyrMM.SV.CoordinatesLocation == "Top" then
			Fyr_MM_Coordinates:ClearAnchors()
			Fyr_MM_Coordinates:SetAnchor(TOP, Fyr_MM, TOP, 0, 0)
			Fyr_MM_Position:ClearAnchors()
			Fyr_MM_Position:SetAnchor(CENTER, Fyr_MM_Coordinates, CENTER, 0, 0)
			Fyr_MM_Position_Background:ClearAnchors()
			Fyr_MM_Position_Background:SetAnchor(CENTER, Fyr_MM_Position, CENTER, 0, 0)
			Fyr_MM_Coordinates:SetMovable(false)
		else
			Fyr_MM_Coordinates:ClearAnchors()
			Fyr_MM_Coordinates:SetAnchor(BOTTOM, Fyr_MM, BOTTOM, 0, 0)
			Fyr_MM_Position:ClearAnchors()
			Fyr_MM_Position:SetAnchor(CENTER, Fyr_MM_Coordinates, CENTER, 0, 0)
			Fyr_MM_Position_Background:ClearAnchors()
			Fyr_MM_Position_Background:SetAnchor(CENTER, Fyr_MM_Position, CENTER, 0, 0)
			Fyr_MM_Coordinates:SetMovable(false)
		end
	end
end

function MM_GetCoordinatesAnchor()
	return FyrMM.SV.CoordinatesAnchor[1], GetControl(FyrMM.SV.CoordinatesAnchor[2]), FyrMM.SV.CoordinatesAnchor[3], FyrMM.SV.CoordinatesAnchor[4], FyrMM.SV.CoordinatesAnchor[5]
end

function MM_SetCoordinatesAnchor(anchor)
	if anchor == nil then return end
	if not anchor[2] then anchor[2] = "Fyr_MM" end
	FyrMM.SV.CoordinatesAnchor = anchor
	if GetControl(FyrMM.SV.CoordinatesAnchor[2]) ~= nil and FyrMM.SV.CoordinatesLocation == "Free" then
		Fyr_MM_Coordinates:ClearAnchors()
		Fyr_MM_Coordinates:SetClampedToScreen(true)
		Fyr_MM_Coordinates:SetAnchor(MM_GetCoordinatesAnchor())
	end
end

function MM_SetPositionBackground(value)
	if value == nil then return end
	FyrMM.SV.PositionBackground = value
	Fyr_MM_Position_Background:SetHidden(not FyrMM.SV.PositionBackground)
end

function MM_SetSpeedBackground(value)
	if value == nil then return end
	FyrMM.SV.SpeedBackground = value
	Fyr_MM_Speed_Background:SetHidden(not FyrMM.SV.SpeedBackground)
end

function MM_GetZoneFrameAnchor()
	return FyrMM.SV.ZoneFrameAnchor[1], GetControl(FyrMM.SV.ZoneFrameAnchor[2]), FyrMM.SV.ZoneFrameAnchor[3], FyrMM.SV.ZoneFrameAnchor[4], FyrMM.SV.ZoneFrameAnchor[5]
end

function MM_GetSpeedAnchor()
	return FyrMM.SV.SpeedAnchor[1], GetControl(FyrMM.SV.SpeedAnchor[2]), FyrMM.SV.SpeedAnchor[3], FyrMM.SV.SpeedAnchor[4], FyrMM.SV.SpeedAnchor[5]
end

function MM_SetShowZoneBackground(value)
	if value == nil then return end
	FyrMM.SV.ShowZoneBackground = value
	Fyr_MM_Zone_Background:SetHidden(not FyrMM.SV.ShowZoneBackground)
end

function MM_SetZoneFrameLocationOption(value)
	if value == nil then return end
	FyrMM.SV.ZoneFrameLocationOption = value
	if FyrMM.SV.ZoneFrameLocationOption == "Default" then
		Fyr_MM_ZoneFrame:ClearAnchors()
		if FyrMM.SV.MenuDisabled then
			Fyr_MM_ZoneFrame:SetAnchor(TOP, Fyr_MM_Border, BOTTOM)
		else 
		    if FyrMM.SV.WheelMap then
			    Fyr_MM_ZoneFrame:SetAnchor(TOP, Fyr_MM_Menu, BOTTOM, 0, -Fyr_MM_Menu:GetHeight()/5)
			else
			    Fyr_MM_ZoneFrame:SetAnchor(TOP, Fyr_MM_Menu, BOTTOM, 0, -Fyr_MM_Menu:GetHeight()/3)
			end
			
		end
		Fyr_MM_ZoneFrame:SetMovable(false)
	else
		if FyrMM.SV.ZoneFrameAnchor ~= nil then
			Fyr_MM_ZoneFrame:ClearAnchors()
			Fyr_MM_ZoneFrame:SetMovable(true)
			Fyr_MM_ZoneFrame:SetMouseEnabled(true)
			Fyr_MM_ZoneFrame:SetAnchor(MM_GetZoneFrameAnchor())
		end
	end 
end

function MM_SetSpeedLocationOption(value)
	if value == nil then return end
	FyrMM.SV.SpeedLocationOption = value
	if FyrMM.SV.SpeedLocationOption == "Default" then
		Fyr_MM_Speed:ClearAnchors()
		Fyr_MM_Speed:SetAnchor(TOP, Fyr_MM_Coordinates, BOTTOM)
		Fyr_MM_Speed:SetMovable(false)
	else
		if FyrMM.SV.SpeedAnchor ~= nil then
			Fyr_MM_Speed:ClearAnchors()
			Fyr_MM_Speed:SetMovable(true)
			Fyr_MM_Speed:SetMouseEnabled(true)
			Fyr_MM_Speed:SetAnchor(MM_GetSpeedAnchor())
		end
	end 
end

function MM_SetZoneFrameAnchor(anchor)
	if anchor == nil then return end
	if not anchor[2] then anchor[2] = "Fyr_MM" end
	FyrMM.SV.ZoneFrameAnchor = anchor
	if GetControl(FyrMM.SV.ZoneFrameAnchor[2]) ~= nil and FyrMM.SV.ZoneFrameLocationOption == "Free" then
		Fyr_MM_ZoneFrame:ClearAnchors()
		Fyr_MM_ZoneFrame:SetClampedToScreen(true)
		Fyr_MM_ZoneFrame:SetAnchor(MM_GetZoneFrameAnchor())
	end
end

function MM_SetSpeedAnchor(anchor)
	if anchor == nil then return end
	if not anchor[2] then anchor[2] = "Fyr_MM" end
	FyrMM.SV.SpeedAnchor = anchor
	if GetControl(FyrMM.SV.SpeedAnchor[2]) ~= nil and FyrMM.SV.SpeedLocationOption == "Free" then
		Fyr_MM_Speed:ClearAnchors()
		Fyr_MM_Speed:SetClampedToScreen(true)
		Fyr_MM_Speed:SetAnchor(MM_GetSpeedAnchor())
	end
end

function MM_SetZoneFont()
	if FyrMM.SV.ZoneFont and FyrMM.SV.ZoneFontHeight and FyrMM.SV.ZoneFontStyle then
		Fyr_MM_Zone:SetFont(FyrMM.Fonts[FyrMM.SV.ZoneFont].."|"..tostring(FyrMM.SV.ZoneFontHeight).."|"..FyrMM.SV.ZoneFontStyle)
	end
end

function MM_SetPositionFont()
	if FyrMM.SV.PositionFont and FyrMM.SV.PositionHeight and FyrMM.SV.PositionFontStyle then
		Fyr_MM_Position:SetFont(FyrMM.Fonts[FyrMM.SV.PositionFont].."|"..tostring(FyrMM.SV.PositionHeight).."|"..FyrMM.SV.PositionFontStyle)
	end
end

function MM_SetSpeedFont()
	if FyrMM.SV.SpeedFont and FyrMM.SV.SpeedHeight and FyrMM.SV.SpeedFontStyle then
		Fyr_MM_SpeedLabel:SetFont(FyrMM.Fonts[FyrMM.SV.SpeedFont].."|"..tostring(FyrMM.SV.SpeedHeight).."|"..FyrMM.SV.SpeedFontStyle)
	end
end

function MM_SetWheelTexture(value)
	if value == nil then return end
	FyrMM.SV.WheelTexture = value
	if FyrMM.WheelTextures[FyrMM.SV.WheelTexture] then
		Fyr_MM_Frame_Wheel:SetTexture(FyrMM.WheelTextures[FyrMM.SV.WheelTexture])
	end
end

function MM_SetMenuTexture(value)
	if value == nil then return end
	FyrMM.SV.MenuTexture = value
	if FyrMM.MenuTextures[FyrMM.SV.MenuTexture] then
		Fyr_MM_Frame_RoundMenu:SetTexture(FyrMM.MenuTextures[FyrMM.SV.MenuTexture].Round)
		Fyr_MM_Frame_SquareMenu:SetTexture(FyrMM.MenuTextures[FyrMM.SV.MenuTexture].Square)
	end
end

function MM_WheelModeDefaults()
	MM_SetWheelMap(true)
	MM_SetWheelTexture("Moosetrax Astro Wheel")
	MM_SetBorderPins(true)
	MM_SetBorderPinsOnlyAssisted(true)
	MM_SetRotateMap(false)
end

function MM_SquareModeDefaults()
	MM_SetWheelMap(false)
	MM_SetBorderPins(true)
	MM_SetBorderPinsOnlyAssisted(true)
	MM_SetRotateMap(false)
	FyrMM.UpdateMapTiles(true)
end

function MM_CreateDataTables()
FyrMM.Defaults = {
		["HideZoneLabel"] = false,
		["HideZoomLevel"] = false,
		["ShowBorder"] = true,
		["ClampedToScreen"] = true,
		["MapHeight"] = 280,
		["MapWidth"] = 280,
		["position"] = {
			["point"] = TOPLEFT,
			["relativePoint"] = TOPLEFT,
			["offsetX"] = 0,
			["offsetY"] = 0
		},
		["MapAlpha"] = 100,
		["Heading"] = "CAMERA",
		["MapHeading"] = "CAMERA",
		["CardinalPoints"] = false,
		["PinScale"] = 75,
		["autoResizePin"] = false,
		["PinTooltips"] = true,
		["ShowPosition"] = false,
		["FastTravelEnabled"] = false,
		["HidePvPPins"] = false,
		["MouseWheel"] = true,
		["MapRefreshRate"] = 40,
		["PinRefreshRate"] = 100,
		["ViewRefreshRate"] = 1200,
		--["ZoneRefreshRate"] = 100,
		--["KeepNetworkRefreshRate"] = 2000,
		["ShowClock"] = false,
		["InCombatState"] =true,
		["LeaderPin"] = "Default",
		["LeaderPinSize"] = 32,
		["ViewRangeFiltering"] = false,	
		["CustomPinViewRange"] = 250,
		["PPStyle"] = "Separate Player & Camera",
		["PPTextures"] = "ESO UI Worldmap",
		["MenuDisabled"] = false,
		["MenuTexture"] = "Default",
		["LeaderPinColor"] = {
			["r"] = 1,
			["g"] = 1,
			["b"] = 1,
			["a"] = 1
		},
		["LeaderDeadPinColor"] = {
			["r"] = 1,
			["g"] = 1,
			["b"] = 1,
			["a"] = 1
		},
		["MemberPin"] = "Default",
		["MemberPinSize"] = 32,
		["MemberRolesColor"] = false,
		["MemberPinColor"] = {
			["r"] = 1,
			["g"] = 1,
			["b"] = 1,
			["a"] = 1
		},
		["MemberDeadPinColor"] = {
			["r"] = 1,
			["g"] = 1,
			["b"] = 1,
			["a"] = 1
		},
		["MemberRolesDpsColor"] = {
			["r"] = 1,
			["g"] = 1,
			["b"] = 1,
			["a"] = 1
		},
		["MemberRolesDeadDpsColor"] = {
			["r"] = 1,
			["g"] = 1,
			["b"] = 1,
			["a"] = 1
		},
		["MemberRolesHealColor"] = {
			["r"] = 1,
			["g"] = 1,
			["b"] = 1,
			["a"] = 1
		},
		["MemberRolesDeadHealColor"] = {
			["r"] = 1,
			["g"] = 1,
			["b"] = 1,
			["a"] = 1
		},
		["MemberRolesTankColor"] = {
			["r"] = 1,
			["g"] = 1,
			["b"] = 1,
			["a"] = 1
		},
		["MemberRolesDeadTankColor"] = {
			["r"] = 1,
			["g"] = 1,
			["b"] = 1,
			["a"] = 1
		},
		["ShowGroupLabels"] = false,
		["PositionColor"] = {
			["a"] = 1,
			["r"] = 0.8588235378,
			["b"] = 0.4352941215,
			["g"] = 0.6823529601,
		},
		["SpeedColor"] = {
			["a"] = 1,
			["r"] = 0.8588235378,
			["b"] = 0.4352941215,
			["g"] = 0.6823529601,
		},
		["ZoneNameColor"] = {
			["a"] = 1,
			["r"] = 0.8588235378,
			["b"] = 0.4352941215,
			["g"] = 0.6823529601,
		},
		["UndiscoveredPOIPinColor"] = {
			["r"] = .7,
			["g"] = .7,
			["b"] = .3,
			["a"] = .6
		},
		["MapTable"] = {},
		["MapStepping"] = 2,
		["ZoomIncrement"] = 1,
		["DefaultZoomLevel"] = 10,
		["InCombatAutoHide"] = false,
		["AfterCombatUnhideDelay"] = 5,
        ["InHouseAutoHide"] = false,
		["InEndLessDungeonAutoHide"] = false,
		["LockResizing"] = false,
		["UseOriginalAPI"] = true,
		["ShowUnexploredPins"] = true,
		["ShowUndiscoveredSkyshards"] = false,
		["RotateMap"] = false,
		["BorderPins"] = false,
		["BorderPinsWaypoint"] = false,
		["BorderPinsBank"] = false,
		["BorderPinsStables"] = false,
		["BorderWayshrine"] = false,
		["BorderKeep"] = true,
		["BorderSkyshard"] = false,
		["BorderTreasures"] = false,
		["BorderQuestGivers"] = false,
		["BorderCrafting"] = false,
		["WorldEvents"] = false,
		["borderAVABG"] = false,
		["WheelMap"] = false,
		["CoordinatesLocation"] = "Top",
		["ZoneNameContents"] = "Classic (Map only)",
		["ForceAreaOnlyInCyro"] = false,
		["ZoneFontHeight"] = 18,
		["ZoneFont"] = "Univers 57",
		["ZoneFontStyle"] = "soft-shadow-thick",
		["ZoneFrameLocationOption"] = "Default",
		["SpeedLocationOption"] = "Default",
		["PositionHeight"] = 18,
		["PositionFont"] = "Univers 57",
		["SpeedHeight"] = 18,
		["SpeedFont"] = "Univers 57",
		["StartupInfo"] = false,
		["noEyeFK"] = false,
		["PositionFontStyle"] = "soft-shadow-thick",
		["SpeedFontStyle"] = "soft-shadow-thick",
		["Siege"] = false,
		["ShowSpeed"] = false,
		["SpeedUnit"] = "ft/s",
		--["ChunkSize"] = 200,
		--["ChunkDelay"] = 10,
		--["WorldMapRefresh"] = true,
		["MapSizes"] = {},
		["ZoomTable"] = {},}

		FyrMM.WheelTextures = {
		["Deathangel RMM Wheel"] = "MiniMap/Textures/Wheelframes/wheel.dds",
		["Moosetrax Normal Wheel"] = "MiniMap/Textures/Wheelframes/MNormalWheel.dds",
		["Moosetrax Astro Wheel"] = "MiniMap/Textures/Wheelframes/MAstroWheel.dds",
		["Vixion Black"] = "MiniMap/Textures/Wheelframes/Vixion_Black.dds",
		["Vixion Black Flat"] = "MiniMap/Textures/Wheelframes/Vixion_BlackFlat.dds",
		["Vixion Black Gold"] = "MiniMap/Textures/Wheelframes/Vixion_BlackGold.dds",
		["Vixion Flat"] = "MiniMap/Textures/Wheelframes/Vixion_Flat.dds",
		["Vixion Gold"] = "MiniMap/Textures/Wheelframes/Vixion_Gold.dds",
		["Vixion Normal"] = "MiniMap/Textures/Wheelframes/Vixion_Normal.dds",
		["Vixion Gloss"] = "MiniMap/Textures/Wheelframes/Vixion_Gloss.dds",
		["Vixion Shiny"] = "MiniMap/Textures/Wheelframes/Vixion_Shiny.dds",
		["Vixion Shiny Gold"] = "MiniMap/Textures/Wheelframes/Vixion_ShinyGold.dds",
		["Vixion Smooth"] = "MiniMap/Textures/Wheelframes/Vixion_Smooth.dds",
		["Vixion Simple"] = "MiniMap/Textures/Wheelframes/Vixion_Simple.dds",
		["Vixion Optic"] = "MiniMap/Textures/Wheelframes/Vixion_Optic.dds",
		["Vixion Noble"] = "MiniMap/Textures/Wheelframes/Vixion_Noble.dds",
		["Vixion Noble Gold"] = "MiniMap/Textures/Wheelframes/Vixion_Noble_Gold.dds",
		["Rhymer Gold"] = "MiniMap/Textures/Wheelframes/Rhymer_Gold.dds",
		["Rhymer Steel"] = "MiniMap/Textures/Wheelframes/Rhymer_Steel.dds",
		["Rhymer Wood"] = "MiniMap/Textures/Wheelframes/Rhymer_Wood.dds",
    ["Weird Wheel"] = "MiniMap/Textures/Wheelframes/weirdWheel.dds",
		["Chrome Wheel"] = "MiniMap/Textures/Wheelframes/chromeWheel.dds",
		["Chrome Wheel Black"] = "MiniMap/Textures/Wheelframes/chromeWheelBlack.dds",
		["Ouroboros Rotate"] = "MiniMap/Textures/Wheelframes/ouroborosRotate.dds",
		["Ouroboros Rotate Black"] = "MiniMap/Textures/Wheelframes/ouroborosRotateBlack.dds",
		["Ouroboros Steady"] = "MiniMap/Textures/Wheelframes/ouroborosSteady.dds",
		["Ouroboros Steady Black"] = "MiniMap/Textures/Wheelframes/ouroborosSteadyBlack.dds",
		["newroboros"] = "MiniMap/Textures/Wheelframes/newroboros.dds",
		["newroboros Black"] = "MiniMap/Textures/Wheelframes/newroborosBlack.dds",
		["Daedric"] = "MiniMap/Textures/Wheelframes/Daedric.dds",
		["Daedric Two"] = "MiniMap/Textures/Wheelframes/Daedric_Two.dds",
		["Clockwork"] = "MiniMap/Textures/Wheelframes/Clockwork.dds",
		["TransmuteStation"] = "MiniMap/Textures/Wheelframes/TransmuteStation.dds",
		["HighElf"] = "MiniMap/Textures/Wheelframes/HighElf.dds",
		["Brotherhood"] = "MiniMap/Textures/Wheelframes/Brotherhood.dds",
		["Xinchei-Konu"] = "MiniMap/Textures/Wheelframes/Xinchei-Konu.dds",
		["CatsEye"] = "MiniMap/Textures/Wheelframes/CatsEye.dds",
		["Vvardenfell"] = "MiniMap/Textures/Wheelframes/Vvardenfell.dds",
		["AntiquariansEye"] = "MiniMap/Textures/Wheelframes/AntiquariansEye.dds",
		["AntiquariansEye Two"] = "MiniMap/Textures/Wheelframes/AntiquariansEye_Two.dds",
		["Mora"] = "MiniMap/Textures/Wheelframes/Mora.dds",
		["GoldHeads"] = "MiniMap/Textures/Wheelframes/GoldHeads.dds",
		["Ouroboros2024"] = "MiniMap/Textures/Wheelframes/Ouroboros2024.dds",
		["Ouroboros2024 Dark"] = "MiniMap/Textures/Wheelframes/Ouroboros2024dark.dds",
		}

		FyrMM.WheelTextureList = {"AntiquariansEye", "AntiquariansEye Two", "Brotherhood", "CatsEye", "Chrome Wheel", "Chrome Wheel Black", "Clockwork", "Daedric" , "Daedric Two", "Deathangel RMM Wheel", "GoldHeads", "HighElf",   
		                          "Moosetrax Normal Wheel", "Moosetrax Astro Wheel", "Mora", "newroboros", "newroboros Black", "Ouroboros2024", "Ouroboros2024 Dark", "Ouroboros Rotate", "Ouroboros Rotate Black",
								  "Ouroboros Steady","Ouroboros Steady Black","Rhymer Gold", "Rhymer Steel", "Rhymer Wood","TransmuteStation", "Vixion Black","Vixion Black Flat", "Vixion Black Gold", "Vixion Flat",
								  "Vixion Gold", "Vixion Normal", "Vixion Gloss", "Vixion Shiny", "Vixion Shiny Gold", "Vixion Smooth", "Vixion Simple", "Vixion Optic", "Vixion Noble", "Vixion Noble Gold", "Vvardenfell",
								  "Weird Wheel", "Xinchei-Konu"}

		FyrMM.FontList = {"Arial Narrow", "Consola","ESO Cartographer","Fontin Bold","Fontin Italic","Fontin Regular","Fontin SmallCaps", "Futura Std Condensed", "Futura Std Condensed Bold",
		                   "Futura Std Condensed Light","ProseAntique","Skyrim Handwritten","Trajan Pro","Univers 55","Univers 57","Univers 67",}
		FyrMM.FontStyles = {"normal", "outline", "thick-outline", "shadow", "soft-shadow-thick", "soft-shadow-thin"}
		FyrMM.MenuTextures = {	["Default"] = {["Square"] = "MiniMap/Textures/MiniMap_SquareMenuFrame_Default.dds", ["Round"] = "MiniMap/Textures/MiniMap_RoundMenuFrame_Default.dds",},
								["Black"] = {["Square"] = "MiniMap/Textures/MiniMap_SquareMenuFrame_Black.dds", ["Round"] = "MiniMap/Textures/MiniMap_RoundMenuFrame_Black.dds",},
								["Red"] = {["Square"] = "MiniMap/Textures/MiniMap_SquareMenuFrame_Red.dds", ["Round"] = "MiniMap/Textures/MiniMap_RoundMenuFrame_Red.dds",},
								["Gold"] = {["Square"] = "MiniMap/Textures/MiniMap_SquareMenuFrame_Gold.dds", ["Round"] = "MiniMap/Textures/MiniMap_RoundMenuFrame_Gold.dds",},}
		FyrMM.MenuTextureList = {"Default", "Black", "Red", "Gold",}
		FyrMM.CSProviders = {"Clothing", "Schneidertisch", "couture", "Blacksmithing", "Schmiedestelle", "forge", "Woodworking", "Schreinerbank", "bois", "Alchemy", "Alchemietisch", "d'alchimie", "Enchanting", "Verzauberungstisch", "d'enchantement",}
		FyrMM.SpeedUnits = {"ft/s", "m/s", "%",}
		FyrMM.MapSizes = {
						[1] = 4964, -- glenumbra_base_0
						[2] = 401, -- edraldundercroft_base_0
						[3] = 1, -- volenfell_base_0
						[4] = 535, -- rawlkhatemple_base_0
						[7] = 4771, -- stonefalls_base_0
						[8] = 594, -- bleakrockvillage_base_0
						[9] = 4624, -- grahtwood_base_0
						[10] = 4062, -- rivenspire_base_0
						[12] = 4682, -- stormhaven_base_0
						[13] = 5348, -- deshaan_base_0
						[16] = 13065, -- ava_whole_0
						[20] = 4345, -- bangkorai_base_0
						[22] = 4327, -- malabaltor_base_0
						[24] = 956, -- davonswatch_base_0
						[26] = 4037, -- shadowfen_base_0
						[28] = 1, -- eldenhollow_base_0
						[29] = 351, -- greenhillcatacombs_base_0
						[30] = 4680, -- alikr_base_0
						[31] = 100, -- bonesnapruins_base_0
						[33] = 927, -- wayrest_base_0
						[34] = 583, -- alcairecastle_base_0
						[36] = 632, -- emericsdream_base_0
						[37] = 538, -- godrunsdream_base_0
						[41] = 1,
						[42] = 380, -- obsidianscar_base_0
						[43] = 1, -- zehtswatercavelower_base_0
						[44] = 1, -- zehtswatercaveupper_base_0
						[46] = 490, -- wayrestsewers_base_0
						[47] = 1,
						[48] = 1,
						[49] = 1,
						[50] = 210, -- yokudanpalace_base_0
						[51] = 645, -- ashaba_base_0
						[52] = 1,
						[53] = 1,
						[54] = 1, -- southruins_base_0
						[56] = 403, -- dhalmora_base_0
						[57] = 153, -- doomcragmiddle_base_0
						[58] = 162, -- doomcragground_base_0
						[59] = 414, -- doomcragshroudedpass_base_0
						[61] = 5350, -- eastmarch_base_0
						[63] = 1040, -- daggerfall_base_0
						[64] = 447, -- cathbedraud_base_0
						[65] = 532, -- badmanscave_base_0
						[66] = 1, -- apocryphasgate_base_0
						[67] = 1,
						[68] = 1,
						[69] = 1,
						[70] = 421, -- ashmountain_base_0
						[71] = 656, -- razakswheel_base_0
						[72] = 695, -- crowswood_base_0
						[74] = 1963, -- bleakrock_base_0
						[75] = 1697, -- balfoyen_base_0
						[76] = 939, -- lostcity_base_0
						[77] = 653, -- fungalgrotto_base_0
						[79] = 1, -- coloviancrossing_base_0
						[80] = 334, -- orrery_base_0
						[81] = 231, -- lostprospect_base_0
						[82] = 266, -- welloflostsouls_base_0
						[83] = 1106, -- sentinel_base_0
						[84] = 750, -- evermore_base_0
						[85] = 630, -- shornhelm_base_0
						[86] = 274, -- fortarand_base_0
						[87] = 435, -- orkeyshollow_base_0
						[88] = 352, -- hozzinsfolley_base_0
						[89] = 555, -- lastresortbarrow_base_0
						[90] = 482, -- innerseaarmature_base_0
						[91] = 298, -- iliathtempletunnels_base_0
						[92] = 353, -- heimlynkeepreliquary_base_0
						[93] = 306, -- davonswatchcrypt_base_0
						[94] = 374, -- housedrescrypts_base_0
						[95] = 218, -- coralheartchamber_base_0
						[97] = 361, -- hightidehollow_base_0
						[98] = 278, -- badmansend_base_0
						[99] = 278, -- badmansstart_base_0
						[100] = 1080, -- foundryofwoe_base_0
						[101] = 427, -- hallsofsubmission_base_0
						[102] = 576, -- mzendeldt_base_0
						[103] = 762, -- theearthforge_base_0
						[104] = 259, -- ragnthar_base_0
						[105] = 600, -- cheesemongershollow_base_0
						[106] = 771, -- circusofcheerfulslaughter_base_0
						[107] = 819, -- chateauravenousrodent_base_0
						[108] = 837, -- eyevea_base_0
						[109] = 213, -- fortvirakruin_base_0
						[110] = 463, -- softloamcavern_base_0
						[111] = 373, -- silumm_base_0
						[112] = 504, -- emberflintmine_base_0
						[113] = 494, -- sheogorathstongue_base_0
						[114] = 407, -- mephalasnest_base_0
						[115] = 444, -- forgottencrypts_base_0
						[116] = 592, -- fortsphinxmoth_base_0
						[117] = 434, -- eidolonshollow2_base_0
						[118] = 652, -- darkshadecaverns_base_0
						[119] = 305, -- kwamacolony_base_0
						[120] = 370, -- triplecirclemine_base_0
						[121] = 338, -- lowerbthanuel_base_0
						[122] = 375, -- unexploredcrag_base_0
						[123] = 304, -- desolatecave_base_0
						[124] = 295, -- corpsegarden_base_0
						[125] = 5350, -- therift_base_0
						[126] = 460, -- deepcragden_base_0
						[127] = 398, -- mzithumz_base_0
						[128] = 306, -- tribunaltemple_base_0
						[129] = 218, -- shadastula_base_0
						[131] = 402, -- taldeiccrypts_base_0
						[132] = 442, -- stormholdayleidruin_base_0
						[133] = 265, -- stillrisevillage_base_0
						[134] = 1, -- shadowscaleenclave_base_0
						[135] = 235, -- skinstealerlair_base_0
						[136] = 294, -- sunscaleenclave_base_0
						[137] = 280, -- templeofsul_base_0
						[138] = 356, -- whiteroseprison_base_0
						[139] = 669, -- loriasel_base_0
						[140] = 660, -- hallofthedead_base_0
						[141] = 1, -- arxcorinium_base_0
						[142] = 1203, -- thelionsden_base_0
						[143] = 5350, -- auridon_base_0
						[144] = 571, -- sanguinesdemesne_base_0
						[146] = 349, -- atanazruins_base_0
						[147] = 363, -- onkobrakwamamine_base_0
						[148] = 362, -- chidmoskaruins_base_0
						[149] = 266, -- shrineofblackworm_base_0
						[150] = 375, -- gandranen_base_0
						[151] = 603, -- cryptofhearts_base_0
						[153] = 444, -- fortmorvunskar_base_0
						[154] = 371, -- bonestrewncrest_base_0
						[155] = 270, -- brokentuskcave_base_0
						[156] = 435, -- lostknifecave_base_0
						[157] = 469, -- mistwatchtower_base_0
						[158] = 326, -- cragwallow_base_0
						[159] = 781, -- mzulft_base_0
						[160] = 713, -- windhelm_base_0
						[161] = 1, -- direfrostkeepheroic_base_0
						[162] = 200, -- direfrostkeepsummit_base_0
						[163] = 379, -- thechillhollow_base_0
						[164] = 406, -- icehammersvault_base_0
						[165] = 432, -- oldsordscave_base_0
						[166] = 332, -- thefrigidgrotto_base_0
						[167] = 432, -- thebastardstomb_base_0
						[168] = 334, -- stormcragcrypt_base_0
						[169] = 267, -- avancheznel_base_0
						[171] = 179, -- giantsrun_base_0
						[172] = 1,
						[173] = 1,
						[174] = 523, -- spindleclutch_base_0
						[175] = 572, -- crimsoncove_base_0
						[176] = 508, -- trolhettacave_base_0
						[177] = 394, -- northwindmine_base_0
						[178] = 434, -- delsclaim_base_0
						[179] = 372, -- ondil_base_0
						[180] = 362, -- bewan_base_0
						[181] = 418, -- wansalen_base_0
						[182] = 368, -- mehrunesspite_base_0
						[183] = 1, -- thevaultofexile_base_0
						[184] = 1, -- phaercatacombs_base_0
						[186] = 538, -- entilasfolly_base_0
						[187] = 468, -- innertanzelwil_base_0
						[188] = 258, -- veiledkeepbase_0
						[189] = 607, -- bonesnapruinssecret_base_0
						[190] = 550, -- ezduiin_base_0
						[191] = 426, -- bthanual_base_0
						[192] = 1, -- fungalgrottosecretroom_base_0
						[193] = 286, -- buraniim_base_0
						[194] = 328, -- norvulkruins_base_0
						[195] = 1,
						[197] = 1,
						[198] = 758, -- riften_base_0
						[199] = 395, -- blackvineruins_base_0
						[200] = 318, -- orcsfingerruins_base_0
						[201] = 1983, -- strosmkai_base_0
						[202] = 381, -- koeglinmine_base_0
						[203] = 579, -- enduum_base_0
						[204] = 305, -- erokii_base_0
						[205] = 1105, -- mournhold_base_0
						[206] = 373, -- shaelruins_base_0
						[207] = 1,
						[208] = 1,
						[209] = 1,
						[210] = 339, -- fardirsfolly_base_0
						[211] = 296, -- shroudhearth_base_0
						[212] = 352, -- cryptoftheexiles_base_0
						[213] = 278, -- khajrawlith_base_0
						[214] = 395, -- ebonmeretower_base_0
						[215] = 302, -- eboncrypt_base_0
						[216] = 241, -- flyleafcatacombs_base_0
						[217] = 635, -- stormhold_base_0
						[218] = 494, -- pinepeakcaverns_base_0
						[219] = 269, -- pariahcatacombs_base_0
						[220] = 250, -- tribulationcrypt_base_0
						[221] = 401, -- tomboftheapostates_base_0
						[222] = 427, -- deadmansdrop_base_0
						[223] = 318, -- bearclawmine_base_0
						[224] = 413, -- coldrockdiggings_base_0
						[225] = 360, -- crestshademine_base_0
						[226] = 397, -- divadschagrinmine_base_0
						[227] = 2232, -- betnihk_base_0
						[228] = 435, -- minesofkhuras_base_0
						[229] = 387, -- murciensclaim_base_0
						[230] = 407, -- sandblownmine_base_0
						[231] = 495, -- aldunz_base_0
						[232] = 473, -- jaggerjaw_base_0
						[233] = 405, -- yldzuun_base_0
						[234] = 1, -- saltspray_base_0
						[235] = 465, -- cryptwatchfort_base_0
						[236] = 263, -- viridianwatch_base_0
						[237] = 372, -- ilessantower_base_0
						[238] = 256, -- portdunwatch_base_0
						[239] = 388, -- trollstoothpick_base_0
						[240] = 227, -- viridianhideaway_base_0
						[241] = 230, -- stonefang_base_0
						[243] = 1065, -- vulkhelguard_base_0
						[244] = 357, -- hildunessecretrefuge_base_0
						[245] = 401, -- rubblebutte_base_0
						[246] = 452, -- santaki_base_0
						[247] = 298, -- bthzark_base_0
						[248] = 231, -- thegrave_base_0
						[249] = 240, -- farangelsdelve_base_0
						[250] = 539, -- crosswychmine_base_0
						[252] = 1,
						[253] = 378, -- tomboflostkings_base_0
						[254] = 244, -- fortgreenwall_base_0
						[255] = 5622, -- coldharbour_base_0
						[256] = 4440, -- reapersmarch_base_0
						[257] = 476, -- bloodthornlair_base_0
						[258] = 1, -- khenarthisroost_base_0
						[260] = 1371, -- carzogsdemise_base_0
						[261] = 548, -- depravedgrotto_base_0
						[262] = 434, -- hoarvorpit_base_0
						[263] = 436, -- wailingmaw_base_0
						[265] = 407, -- snaplegcave_base_0
						[266] = 369, -- aba-loria_base_0
						[267] = 487, -- rootsofsilvenar_base_0
						[268] = 730, -- toothmaulgully_base_0
						[270] = 658, -- shrineofmauloch_base_0
						[271] = 354, -- abamath_base_0
						[272] = 500, -- thehuntinggrounds_base_0
						[273] = 311, -- ouze_base_0
						[274] = 253, -- tenmaurwolk_base_0
						[275] = 993, -- velynharbor_base_0
						[276] = 642, -- therefugeofdread_base_0
						[277] = 452, -- shorsstonemine_base_0
						[278] = 504, -- rulanyilsfall_base_0
						[279] = 549, -- thebanishedcells_base_0
						[280] = 1,
						[281] = 1,
						[282] = 637, -- baandaritradingpost_base_0
						[283] = 485, -- rootsunder_base_0
						[284] = 461, -- stormwardenundercroft_base_0
						[285] = 1, -- breakneckcave_base_0
						[286] = 1, -- haynotecave_base_0
						[287] = 1, -- muckvalleycavern_base_0
						[288] = 1, -- underpallcave_base_0
						[289] = 1, -- redrubycave_base_0
						[290] = 1, -- lipsandtarn_base_0
						[291] = 1, -- potholecavern_base_0
						[292] = 1350, -- tempestisland_base_0
						[293] = 1, -- toadstoolhollow_base_0
						[294] = 1, -- toadstoolhollowlower_base_0
						[295] = 218, -- goblinminesstart_base_0
						[296] = 340, -- goblinminesend_base_0
						[297] = 413, -- windridgecave_base_0
						[298] = 341, -- aphrenshold_base_0
						[299] = 1, -- vahtacen_base_0
						[300] = 3916, -- greenshade_base_0
						[301] = 431, -- clawsstrike_base_0
						[302] = 460, -- dokrintemple_base_0
						[303] = 541, -- hallsofichor_base_0
						[304] = 437, -- jodeslight_base_0
						[305] = 336, -- rendrocaverns_base_0
						[306] = 444, -- moonmonttemple_base_0
						[307] = 383, -- weepingwindcave_base_0
						[308] = 229, -- planeofjodetemple_base_0
						[309] = 299, -- planeofjodecave_base_0
						[310] = 918, -- planeofjodehubhillbos_base_0
						[311] = 442, -- planeofjodedenoflorkhaj_base_0
						[312] = 559, -- rawlkha_base_0
						[314] = 1,
						[315] = 1,
						[316] = 1,
						[317] = 596, -- thevilemansefirstfloor_base_0
						[318] = 594, -- thevilemansesecondfloor_base_0
						[319] = 114, -- gladeofthedivineshivering_base_0
						[320] = 674, -- gladeofthedivineasakala_base_0
						[321] = 480, -- gladeofthedivinevuldngrav_base_0
						[322] = 437, -- malsorrastomb_base_0
						[323] = 356, -- thibautscairn_base_0
						[324] = 347, -- wittestadrcrypts_base_0
						[325] = 227, -- vernimwood_base_0
						[326] = 1010, -- cityofashmain_base_0
						[327] = 1010, -- cityofashboss_base_0
						[328] = 1, -- catseyequay_base_0
						[329] = 1, -- templeofthemourningspring_base_0
						[330] = 1, -- darkshadecavernsheroic_base_0
						[331] = 385, -- spindleclutchheroic_base_0
						[332] = 1, -- eldenhollowheroic1_base_0
						[333] = 1, -- eldenhollowheroic2_base_0
						[334] = 772, -- selenesweb_base_0
						[335] = 972, -- seleneswebfinalbossarea_base_0
						[336] = 275, -- salasen_base_0
						[337] = 265, -- imperviousvault_base_0
						[338] = 1, -- loriasellowerlevel_base_0
						[339] = 1504, -- villageofthelost_base_0
						[340] = 1, -- kingscrest_base_0
						[341] = 1,
						[342] = 1,
						[343] = 417, -- kunasdelve_base_0
						[344] = 1, -- blackhearthavenarea4_base_0
						[345] = 1, -- blackhearthavenarea3_base_0
						[346] = 1, -- blackhearthavenarea2_base_0
						[347] = 1, -- blackhearthavenarea1_base_0
						[348] = 810, -- direfrostkeep_base_0
						[350] = 331, -- libraryofdusk_base_0
						[351] = 407, -- hajuxith_base_0
						[352] = 328, -- vaultofhamanforgefire_base_0
						[353] = 508, -- thevilelaboratory_base_0
						[354] = 586, -- lightlessoubliette_base_0
						[355] = 586, -- lightlessoubliettelava_base_0
						[356] = 457, -- grundasgatehousemain_base_0
						[357] = 457, -- grundasgatehouseroom_base_0
						[358] = 725, -- themanorofrevelry_base_0
						[359] = 464, -- shademistenclave_base_0
						[360] = 943, -- hallinsstand_base_0
						[361] = 549, -- theendlessstair_base_0
						[362] = 881, -- hectahamegrottomain_base_0
						[363] = 881, -- hectahamegrottoarmory_base_0
						[364] = 881, -- hectahamegrottoritual_base_0
						[365] = 881, -- hectahamegrottoarboretum_base_0
						[366] = 596, -- hectahamegrottovalenheart_base_0
						[367] = 431, -- nereidtemple_base_0
						[368] = 740, -- lightlesscell_base_0
						[369] = 468, -- ilmyris_base_0
						[370] = 949, -- silatar_base_0
						[371] = 1081, -- blackforge_base_0
						[372] = 1081, -- blackforge_base_0
						[373] = 1081, -- blackforge_base_0
						[374] = 630, -- serpentsgrotto_base_0
						[375] = 376, -- imperialundergroundpart2_base_0
						[376] = 154, -- imperialundergroundpart1_base_0
						[377] = 1,
						[378] = 452, -- shroudedhollowarea1_base_0
						[379] = 452, -- shroudedhollowarea2_base_0
						[380] = 391, -- barrowtrench_base_0
						[382] = 389, -- gurzagsmine_base_0
						[383] = 332, -- harridanslair_base_0
						[384] = 394, -- theunderroot_base_0
						[385] = 830, -- islesoftorment_base_0
						[386] = 333, -- caracdena_base_0
						[387] = 580, -- marbruk_base_0
						[388] = 1,
						[389] = 1,
						[390] = 1,
						[391] = 405, -- narilnagaia_base_0
						[392] = 406, -- mournholdsewers_base_0
						[393] = 334, -- vindeathcave_base_0
						[394] = 381, -- dessicatedcave_base_0
						[395] = 395, -- mobarmine_base_0
						[396] = 389, -- burrootkwamamine_base_0
						[397] = 1, -- blessedcrucible1_base_0
						[398] = 1, -- blessedcrucible2_base_0
						[399] = 1, -- blessedcrucible3_base_0
						[400] = 1, -- blessedcrucible4_base_0
						[401] = 1, -- blessedcrucible5_base_0
						[402] = 740, -- blessedcrucible6_base_0
						[403] = 1, -- blessedcrucible7_base_0
						[404] = 290, -- nesalas_base_0
						[405] = 1, -- caveofbrokensails_base_0
						[406] = 537, -- reliquaryofstars_base_0
						[407] = 1, -- southpoint_base_0
						[408] = 428, -- havensewers_base_0
						[409] = 347, -- laeloriaruins_base_0
						[410] = 451, -- ossuaryoftelacar_base_0
						[411] = 1, -- brackenleaf_base_0
						[412] = 353, -- rajhinsvault_base_0
						[413] = 90, -- rajhinsvaultsmallroom_base_0
						[414] = 319, -- wormrootdepths_base_0
						[415] = 726, -- stirk_base_0
						[417] = 183, -- bangkoraigarrisontop_base_0
						[418] = 452, -- sunkenroad_base_0
						[419] = 306, -- nilataruins_base_0
						[420] = 734, -- hallofheroes_base_0
						[421] = 734, -- hallofheroes_base_0
						[422] = 659, -- hollowcity_base_0
						[426] = 486, -- thefarshores_base_0
						[428] = 1, -- boneorchard_base_0
						[430] = 240, -- tombofanahbi_base_0
						[431] = 452, -- onsisbreathmine_base_0
						[437] = 357, -- visionofthecompanions_base_0
						[438] = 209, -- albeceansea_base_0
						[439] = 1, -- mundus_base_0
						[440] = 1,
						[441] = 1,
						[442] = 115, -- doomcragtop_base_0
						[443] = 1,
						[445] = 1014, -- eldenrootgroundfloor_base_0
						[446] = 245, -- eldenrootcrafting_base_0
						[447] = 245, -- eldenrootfightersguildup_base_0
						[448] = 245, -- eldenrootmagesguild_base_0
						[449] = 245, -- eldenrootmagesguilddown_base_0
						[450] = 293, -- eldenrootservices_base_0
						[451] = 245, -- eldenrootthroneroom_base_0
						[452] = 453, -- themiddens_base_0
						[454] = 336, -- vaultsofmadness1_base_0
						[455] = 338, -- vaultsofmadness2_base_0
						[458] = 1, -- bloodmatronscryptgroup_base_0
						[459] = 1, -- bloodmatronscryptsingle_base_0
						[460] = 279, -- fallowstonevault_base_0
						[461] = 257, -- mistwatchcrevassecrypt_base_0
						[462] = 230, -- halloftrials_base_0
						[463] = 203, -- forelhost_base_0
						[464] = 341, -- nimaltenpart1_base_0
						[465] = 165, -- nimaltenpart2_base_0
						[466] = 1, -- serpenthollowcave_base_0
						[467] = 1, -- nisincave_base_0
						[468] = 1, -- newtcave_base_0
						[469] = 1, -- bloodmaynecave_base_0
						[470] = 1, -- capstonecave_base_0
						[471] = 1, -- quickwatercave_base_0
						[472] = 1, -- quickwaterdepths_base_0
						[473] = 1, -- echocave_base_0
						[474] = 1, -- crackedwoodcave_base_0
						[475] = 246, -- moriseli_base_0
						[476] = 315, -- shadowfatecavern_base_0
						[477] = 243, -- shroudedpass_base_0
						[478] = 263, -- breaghafinupper_base_0
						[479] = 306, -- breaghafinlower_base_0
						[480] = 329, -- lorkrataruinsa_base_0
						[481] = 329, -- lorkrataruinsb_base_0
						[482] = 227, -- thewormsretreat_base_0
						[483] = 1, -- wailingprison1_base_0
						[484] = 1, -- wailingprison2_base_0
						[485] = 1, -- wailingprison3_base_0
						[486] = 1, -- wailingprison4_base_0
						[487] = 1, -- wailingprison5_base_0
						[488] = 1, -- wailingprison6_base_0
						[489] = 1, -- wailingprison7_base_0
						[490] = 421, -- castleoftheworm1_base_0
						[491] = 427, -- castleoftheworm2_base_0
						[492] = 241, -- castleoftheworm3_base_0
						[493] = 937, -- castleoftheworm4_base_0
						[494] = 1, -- castleoftheworm5_base_0
						[495] = 373, -- sancretor1_base_0
						[496] = 260, -- sancretor2_base_0
						[497] = 247, -- sancretor3_base_0
						[498] = 243, -- sancretor4_base_0
						[499] = 221, -- sancretor5_base_0
						[500] = 212, -- sancretor6_base_0
						[501] = 280, -- sancretor7_base_0
						[502] = 218, -- sancretor8_base_0
						[503] = 696, -- heartsgrief1_base_0
						[504] = 503, -- heartsgrief2_base_0
						[505] = 503, -- heartsgrief2_base_0
						[506] = 722, -- heartsgrief3_base_0
						[507] = 609, -- hallsoftorment1_base_0
						[508] = 609, -- hallsoftorment1_base_0
						[509] = 351, -- taarengrav_base_0
						[510] = 799, -- kragenmoor_base_0
						[511] = 1007, -- ebonheart_base_0
						[512] = 943, -- haven_base_0
						[513] = 635, -- northpoint_base_0
						[516] = 671, -- valleyofblades1_base_0
						[517] = 289, -- valleyofblades2_base_0
						[518] = 1, -- torinaan1_base_0
						[519] = 1, -- torinaan2_base_0
						[520] = 1, -- torinaan3_base_0
						[521] = 1, -- torinaan4_base_0
						[522] = 1, -- torinaan5_base_0
						[523] = 285, -- coromount_base_0
						[524] = 265, -- karthdar_base_0
						[525] = 512, -- hollowlair_base_0
						[526] = 255, -- oldmerchantcaves_base_0
						[527] = 261, -- senelana_base_0
						[528] = 395, -- hoarfrost_base_0
						[529] = 1027, -- woodhearth_base_0
						[530] = 830, -- porthunding_base_0
						[531] = 666, -- aldcroft_base_0
						[532] = 551, -- koeglinvillage_base_0
						[533] = 875, -- dune_base_0
						[534] = 716, -- vulkwasten_base_0
						[535] = 833, -- arenthia_base_0
						[536] = 475, -- redfurtradingpost_base_0
						[537] = 636, -- narsis_base_0
						[538] = 674, -- kozanset_base_0
						[539] = 715, -- bergama_base_0
						[540] = 877, -- firsthold_base_0
						[541] = 828, -- crosswych_base_0
						[542] = 752, -- shorsstone_base_0
						[543] = 940, -- nimalten_base_0
						[544] = 812, -- altencorimont_base_0
						[545] = 909, -- skywatch_base_0
						[546] = 274, -- narsisruins_base_0
						[547] = 461, -- obsidiangorge_base_0
						[548] = 327, -- rage_base_0
						[549] = 280, -- blisstop_base_0
						[550] = 112, -- blisslower_base_0
						[551] = 224, -- despair_base_0
						[552] = 17, -- temple_base_0
						[553] = 268, -- kulatimines-a_base_0
						[554] = 148, -- kulatimines-b_base_0
						[555] = 320, -- dourstonevault_base_0
						[556] = 281, -- themondmine_base_0
						[557] = 251, -- sren-ja_base_0
						[558] = 184, -- sren-ja1_base_0
						[559] = 161, -- sren-ja2_base_0
						[560] = 274, -- shroudedpass2_base_0
						[561] = 286, -- mudtreemine_base_0
						[562] = 318, -- visionofthehist_base_0
						[563] = 455, -- abagarlas_base_0
						[564] = 1, -- greymire_base_0
						[565] = 362, -- toweroflies_base_0
						[567] = 723, -- mistral_base_0
						[568] = 328, -- falinesticave_base_0
						[569] = 426, -- quarantineserk_base_0
						[571] = 245, -- eldenrootfightersguildown_base_0
						[572] = 1, -- northhighrockgate_base_0
						[573] = 1, -- northmorrowgate_base_0
						[574] = 1, -- southmorrowgate_base_0
						[575] = 1, -- southhighrockgate_base_0
						[576] = 600, -- westelsweyrgate_base_0
						[577] = 807, -- eastelsweyrgate_base_0
						[578] = 658, -- fortamol_base_0
						[580] = 311, -- lostprospect2_base_0
						[581] = 1, -- whitefallmountain_base_0
						[583] = 1, -- theearthforgepublic_base_0
						[584] = 1, -- hircineswoods_base_0
						[585] = 1004, -- greatshackle1_base_0
						[586] = 1004, -- greatshackle1_base_0
						[587] = 264, -- themooring_base_0
						[588] = 141, -- tsanji_base_0
						[589] = 452, -- urcelmosbetrayal_base_0
						[590] = 506, -- arcwindpoint_base_0
						[591] = 772, -- bisnensel_base_0
						[592] = 227, -- shroudedhollowcenter_base_0
						[593] = 449, -- caveoftrophies_base_0
						[594] = 1, -- caveoftrophiesupper_base_0
						[595] = 404, -- abandonedmine_base_0
						[596] = 1, -- tempestislandswcave_base_0
						[597] = 1, -- tempestislandsecave_base_0
						[598] = 1, -- tempestislandncave_base_0
						[599] = 310, -- nchuduabtharthreshold_base_0
						[600] = 163, -- chateaumasterbedroom_base_0
						[601] = 722, -- jodeplane_base_0
						[602] = 369, -- tormentedspireinstance_base_0
						[603] = 273, -- reliquaryvaultbottom_base_0
						[604] = 120, -- reliquaryvaulttop_base_0
						[605] = 1, -- hazikslair_base_0
						[614] = 1, -- helracitadel_base_0
						[615] = 1, -- helracitadelentry_base_0
						[616] = 1, -- helracitadelhallofwarrior_base_0
						[618] = 1, -- rahniza_2_0
						[621] = 1, -- rahniza_3_0
						[630] = 1, -- balamathairmonarchcham_base_0
						[631] = 1, -- balamathlibrary_base_0
						[637] = 452, -- kardala_base_0
						[638] = 1, -- seekersarchiveup_base_0
						[639] = 1, -- seekersarchivedown_base_0
						[640] = 1, -- aetherianarchiveend_base_0
						[641] = 1, -- aetherianarchiveislandc_base_0
						[642] = 1, -- aetherianarchiveislanda_base_0
						[644] = 1, -- aetherianarchiveislandb_base_0
						[645] = 1, -- aetherianarchivemiddle_base_0
						[646] = 1, -- aetherianarchivebottom_base_0
						[647] = 270, -- edraldundercroftdomed_base_0
						[648] = 673, -- howlingsepulchersoverland_base_0
						[649] = 744, -- stonetoothfortress_base_0
						[650] = 158, -- mudshallowcave_base_0
						[651] = 263, -- crgwamasucave_base_0
						[652] = 1, -- frostmonarchlair_base_0
						[653] = 603, -- cryptofheartsheroic_base_0
						[654] = 1, -- cryptofheartsheroicboss_0
						[655] = 359, -- trolhettasummit_base_0
						[656] = 239, -- ilthagsundertower_base_0
						[657] = 1, -- imperialsewershub_base_0
						[658] = 1, -- eyeschamber_base_0
						[659] = 1, -- guardiansorbit_base_0
						[660] = 1, -- imperialcity_base_0
						[661] = 1, -- emericsdreampart2_base_0
						[662] = 303, -- bangkoraigarrisonsewer_base_0
						[665] = 443, -- angofssanctum_base_0
						[666] = 451, -- fearfang_base_0
						[667] = 4687, -- wrothgar_base_0
						[668] = 1, -- skyreachtemple_base_0
						[669] = 170, -- lionsden_hiddentunnel_base_0
						[670] = 247, -- ilthagsundertower02_base_0
						[671] = 192, -- howlingsepulcherscave_base_0
						[672] = 1, -- skyreachpinnacle_base_0
						[673] = 189, -- skyreachhold1_base_0
						[674] = 195, -- skyreachhold2_base_0
						[675] = 187, -- skyreachhold3_base_0
						[676] = 236, -- skyreachhold4_base_0
						[680] = 458, -- craglorn_dragonstar_base_0
						[681] = 1, -- dragonstararena09crypt_base_0
						[682] = 1, -- gladiatorsassembly_base_0
						[683] = 1, -- dragonstararena01_base_0
						[684] = 1, -- dragonstararena02_base_0
						[685] = 1, -- dragonstararena03_base_0
						[686] = 1, -- dragonstararena04_base_0
						[687] = 1, -- dragonstararena05_base_0
						[688] = 1, -- dragonstararena06_base_0
						[689] = 1, -- dragonstararena07_base_0
						[690] = 1, -- dragonstararena08_base_0
						[691] = 1, -- dragonstararena09_base_0
						[692] = 1, -- dragonstararena10_base_0
						[693] = 1, -- howlingsepulchersscrying_base_0
						[695] = 1, -- skyreachcatacombs2_base_0
						[696] = 1, -- skyreachcatacombs3_base_0
						[697] = 1, -- skyreachcatacombs4_base_0
						[698] = 1, -- skyreachcatacombs5_base_0
						[699] = 1200, -- vetcirtyash01_base_0
						[700] = 1, -- vetcirtyash02_base_0
						[701] = 1, -- vetcirtyash03_base_0
						[702] = 1, -- vetcirtyash04_base_0
						[703] = 374, -- brokenhelm_base_0
						[704] = 1, -- trl_so_map01_base_0
						[705] = 1, -- trl_so_map02_base_0
						[706] = 1, -- trl_so_map03_base_0
						[707] = 1, -- trl_so_map04_base_0
						[708] = 1, -- dragonstararenavault_base_0
						[709] = 215, -- nilataruinsboss_base_0
						[710] = 207, -- yokudanpalace02_base_0
						[712] = 241, -- desolationsend_base_0
						[713] = 144, -- smugglertunnel_base_0
						[714] = 124, -- theshrineofstveloth_base_0
						[715] = 148, -- apothacarium_base_0
						[716] = 191, -- stormholdguildhall_map_0
						[717] = 1, -- starvedplanes_base_0
						[718] = 345, -- rootsoftreehenge_base_0
						[719] = 145, -- crowswooddungeon_base_0
						[720] = 127, -- stormholdmortuary_map_0
						[722] = 193, -- sf_percolatingmire_map_0
						[723] = 174, -- hissmirruins_map_0
						[724] = 265, -- dresankeep_base_0
						[726] = 161, -- skyshroudbarrow_base_0
						[727] = 98, -- ateliertwicebornstar_base_0
						[728] = 121, -- magistratesbasement_base_0
						[729] = 93, -- the_masters_crypt_base_0
						[730] = 151, -- vineduckvillage_base_0
						[731] = 294, -- vineduckvillagecorridor_base_0
						[732] = 1, -- volenfell_pledge_base_0
						[733] = 187, -- campgushnukbur_base_0
						[734] = 249, -- suturahs_crypt_base_0
						[735] = 1, -- vulkel_guard_prison_base_0
						[736] = 181, -- the_daggerfall_harborage_0
						[737] = 162, -- the_ebonheart_harborage_base_0
						[738] = 151, -- courtofcontempt_base_0
						[739] = 160, -- theeverfullflagon_base_0
						[740] = 176, -- reavercitadelpyramid_base_0
						[741] = 181, -- thelibrarydusk_base_0
						[742] = 175, -- thelostfleet_base_0
						[743] = 1, -- themangroves_base_0
						[744] = 1, -- shatteredshoals_base_0
						[745] = 226, -- barkbitecave_base_0
						[746] = 182, -- barkbitemine_base_0
						[747] = 170, -- valeoftheghostsnake_base_0
						[748] = 212, -- faltoniasmine_base_0
						[749] = 220, -- sacredleapgrotto_base_0
						[750] = 81, -- cormountprison_base_0
						[751] = 130, -- manorofrevelryint01_base_0
						[752] = 130, -- manorofrevelryint02_base_0
						[753] = 123, -- manorofrevelryint03_base_0
						[754] = 123, -- manorofrevelryint04_base_0
						[755] = 74, -- manorofrevelryint05_base_0
						[756] = 1, -- gilvardelleabandoncave_0
						[757] = 100, -- silvenarthroneroom_base_0
						[758] = 1, -- thefivefingerdance_0
						[759] = 158, -- emericsdquagmireportion_base_0
						[760] = 191, -- coloredrooms_base_0
						[761] = 147, -- lair_base_0
						[762] = 1, -- oldcreepycave_base_0
						[763] = 72, -- vilemansehouse01_base_0
						[764] = 72, -- vilemansehouse02_base_0
						[765] = 1, -- imperialprisondistrictdun_base_0
						[766] = 682, -- charredridge_base_0
						[767] = 1, -- imperialprisondunint01_base_0
						[768] = 1, -- imperialprisondunint02_base_0
						[769] = 1, -- imperialprisondunint02_base_0
						[770] = 1, -- imperialprisondunint03_base_0
						[771] = 1, -- imperialprisondunint04_base_0
						[772] = 153, -- the_aldmiri_harborage_map_base_0
						[773] = 287, -- smugglerkingtunnel_base_0
						[774] = 178, -- shorecave_base_0
						[775] = 165, -- rkulftzel_base_0
						[776] = 178, -- the_portal_chamber_map_base_0
						[777] = 1, -- imperialsewersald1_base_0
						[781] = 1, -- imperialsewersebon1_base_0
						[782] = 1, -- imperialsewersebon2_base_0
						[785] = 1, -- imperialsewershub_base_0
						[786] = 643, -- tormented_spire_base_0
						[787] = 286, -- manorofrevelrycave_base_0
						[788] = 311, -- fevered_mews_base_0
						[789] = 128, -- fevered_mews_subzone_base_0
						[790] = 1, -- secret_tunnel_base_0
						[791] = 1, -- the_guardians_skull_base_0
						[792] = 1371, -- ancientcarzogsdemise_base_0
						[793] = 1, -- iccoldharboraboretum1_base_0
						[794] = 1, -- iccoldharboraboretum2_base_0
						[795] = 1, -- iccoldharboraboretum3_base_0
						[796] = 1, -- iccoldharbormarket1_base_0
						[797] = 1, -- iccoldharbormarket2_base_0
						[798] = 1, -- iccoldharbormarket3_base_0
						[799] = 166, -- south_hut_portal_cave_base_0
						[800] = 337, -- smugglerstunnel_base_0
						[801] = 168, -- east_hut_portal_cave_base_0
						[802] = 201, -- west_hut_portal_cave_base_0
						[803] = 149, -- north_hut_portal_cave_base_0
						[804] = 1, -- iccoldharbonobels1_base_0
						[805] = 1, -- iccoldharbonobels2_base_0
						[806] = 1, -- iccoldharbonobels3_base_0
						[807] = 282, -- glenumbraoutlawrefuge_base_0
						[808] = 207, -- auridonoutlawrefuge_base_0
						[809] = 195, -- grahtwoodoutlawrefuge_base_0
						[810] = 229, -- alkiroutlawrefuge_base_0
						[811] = 347, -- shadowfenoutlawrefuge_base_0
						[812] = 148, -- rivenspireoutlaw_base_0
						[813] = 169, -- bangkoraioutlawrefuge_base_0
						[814] = 237, -- stonefallsoutlawrefuge_base_0
						[815] = 246, -- riftoutlaw_base_0
						[816] = 320, -- stormhavenoutlawrefuge_base_0
						[817] = 270, -- marbrukoutlawsrefuge_base_0
						[818] = 195, -- craglornoutlawrefuge_base_0
						[819] = 348, -- mournholdoutlawsrefuge_base_0
						[820] = 259, -- malabaltoroutlawrefuge_base_0
						[821] = 1,
						[822] = 248, -- eastmarchrefuge_base_0
						[823] = 266, -- reapersmarchoutlawrefuge_base_0
						[825] = 1, -- banditdenoneone_base_0
						[826] = 1, -- banditden1_main_base_0
						[827] = 403, -- secludedsewers_base_0
						[828] = 1, -- banditden4_base_0
						[829] = 1,
						[830] = 1, -- banditden5_base_0
						[831] = 1,
						[832] = 1, -- banditden7_base_0
						[833] = 1, -- banditden8_base_0
						[834] = 1,
						[835] = 1,
						[836] = 1,
						[837] = 1, -- banditden13_base_0
						[838] = 1, -- banditden11f2_base_0
						[839] = 1, -- banditden11r1_base_0
						[840] = 1, -- banditden11r2_base_0
						[841] = 1, -- banditden11r3_base_0
						[842] = 1,
						[843] = 1,
						[844] = 1,
						[845] = 1,
						[846] = 1,
						[847] = 1,
						[848] = 1,
						[849] = 1,
						[850] = 1,
						[851] = 1, -- banditden4_room1_base_0
						[852] = 1, -- banditden4_room2_base_0
						[853] = 1, -- banditden4_room3_base_0
						[854] = 1, -- banditden4_room4_base_0
						[855] = 1, -- banditden4_room5_base_0
						[856] = 1, -- banditden4_room6_base_0
						[860] = 1, -- banditden5_room1_base_0
						[861] = 1, -- banditden5_room2_base_0
						[862] = 1, -- banditden5_room3_base_0
						[863] = 1, -- banditden5_room4_base_0
						[864] = 1,
						[865] = 1,
						[866] = 1,
						[867] = 1,
						[868] = 1, -- banditden8_room1_base_0
						[869] = 1, -- banditden8_room2_base_0
						[870] = 1, -- banditden8_room3_base_0
						[871] = 1,
						[872] = 1,
						[873] = 1,
						[874] = 1,
						[875] = 1,
						[876] = 1,
						[877] = 1,
						[878] = 1,
						[879] = 1,
						[880] = 1,
						[881] = 1,
						[882] = 1,
						[883] = 1,
						[884] = 1,
						[885] = 1,
						[886] = 1,
						[887] = 1,
						[888] = 1,
						[889] = 610, -- bonerock_caverns_base_0
						[890] = 1, -- imperialsewers_ebon1_base_0
						[891] = 1, -- imperialsewers_ebon2_base_0
						[893] = 1, -- hircineswoods_group_base_0
						[894] = 164, -- bangkoraigarrisonbtm_base_0
						[895] = 894, -- orsinium_base_0
						[896] = 1, -- glenumbracamlornkeep_base_0
						[897] = 1, -- imperialsewers_aldmeri1_base_0
						[898] = 1, -- imperialsewers_aldmeri2_base_0
						[899] = 1, -- imperialsewers_aldmeri3_base_0
						[900] = 1, -- imperialsewer_daggerfall1_base_0
						[901] = 1, -- imperialsewer_daggerfall2_base_0
						[902] = 1, -- imperialsewer_daggerfall3_base_0
						[903] = 1, -- imperialsewer_ebonheart3_base_0
						[904] = 1, -- imperialsewer_ebonheart3b_base_0
						[905] = 1, -- imperialsewer_dagfall3b_base_0
						[906] = 1, -- imperialsewer_ebonheart3m_base_0
						[907] = 1, -- wgtpalacesewers_base_0
						[908] = 434, -- wgtgreenemporerway_base_0
						[909] = 1, -- wgtimperialthroneroom_base_0
						[910] = 1, -- wgtimperialguardquarters_base_0
						[911] = 1, -- wgtlibraryhall_base_0
						[912] = 1, -- wgtlibrarymain_base_0
						[913] = 1, -- wgtvoid1_base_0
						[914] = 1, -- wgtbattlemage_base_0
						[915] = 1, -- wgtvoid2_base_0
						[916] = 1, -- wgtregentsquarters_base_0
						[917] = 1, -- wgtpinnacle_base_0
						[918] = 1, -- wgtpinnacleboss_base_0
						[919] = 1, -- imperial_dragonfire_tunne_base_0
						[920] = 1, -- imperial_dragonfire_cath_base_0
						[923] = 157, -- fharunstronghold01_base_0
						[924] = 109, -- fharunstronghold02_base_0
						[925] = 1, -- fharunstronghold03_base_0
						[926] = 173, -- fharunstronghold03b_base_0
						[927] = 169, -- wrothgaroutlawrefuge_base_0
						[929] = 398, -- fharunprison_base_0
						[930] = 173, -- orsiniumtemplelower_base_0
						[931] = 176, -- orsiniumtempleupper_base_0
						[932] = 124, -- orsiniumthroneroom_base_0
						[933] = 234, -- scarpkeeplower_base_0
						[934] = 234, -- scarpkeepupper_base_0
						[935] = 1,
						[936] = 1, -- sanctumofprowess_base_0
						[937] = 899, -- rkindaleftoutside_base_0
						[938] = 468, -- rkindaleftint01_base_0
						[939] = 1, -- rkindaleftint02_base_0
						[940] = 178, -- rkindaleftint03_base_0
						[941] = 757, -- kennelrun_base_0
						[942] = 355, -- bloodyknoll_base_0
						[943] = 427, -- honorsrestleft_base_0
						[944] = 331, -- honorsrestright_base_0
						[945] = 476, -- zthenganaz_base_0
						[946] = 36, -- honorsrestdesert_base_0
						[947] = 84, -- honorsrestorc_base_0
						[948] = 190, -- honorsrestfinalc_base_0
						[949] = 460, -- honorsrestfinalv_base_0
						[950] = 488, -- paragonsrememberance_base_0
						[951] = 647, -- graystonequarrytop_base_0
						[952] = 715, -- graystonequarrybottom_base_0
						[953] = 715, -- graystonequarrybottom_base_0
						[954] = 482, -- morkul_base_0
						[955] = 153, -- rectory01_base_0
						[956] = 489, -- coldperchcavern_base_0
						[957] = 437, -- thukozods_base_0
						[958] = 500, -- argentmine2_base_0
						[959] = 581, -- pathtothemoot_base_0
						[960] = 458, -- exilesbarrow_map_base_0
						[961] = 545, -- frostbreakfortint_map_base_0
						[962] = 395, -- chambersofloyalty_base_0
						[963] = 325, -- arenasclockworkint_base_0
						[964] = 698, -- sorrowext_base_0
						[965] = 154, -- sorrowint01_base_0
						[966] = 275, -- sorrowint02_base_0
						[967] = 297, -- sorrowint03_base_0
						[968] = 597, -- watchershold_base_0
						[969] = 274, -- iceheartslair_map_base_0
						[970] = 1, -- arenasclockwork2_base_0
						[971] = 521, -- morkuldescent_map_base_0
						[972] = 420, -- morkuldin_map_base_0
						[973] = 1, -- arenasmephalaexterior_base_0
						[974] = 533, -- bonegrinder_base_0
						[975] = 313, -- oldorsiniummap01_base_0
						[976] = 1, -- arenaswrothgarexterior_base_0
						[977] = 469, -- arenaslobbyexterior_base_0
						[978] = 1, -- arenasmurkmireexterior_base_0
						[979] = 554, -- oldorsiniummap02_base_0
						[980] = 262, -- oldorsiniummap03_base_0
						[981] = 363, -- oldorsiniummap04_base_0
						[982] = 247, -- oldorsiniummap05_base_0
						[983] = 399, -- oldorsiniummap06_base_0
						[984] = 411, -- oldorsiniummap07_base_0
						[985] = 1, -- arenasoblivionexterior_base_0
						[986] = 1, -- arenaslavacaveinterior_base_0
						[987] = 1, -- arenasmurkmirecaveint_base_0
						[988] = 628, -- arenasshiveringisles_base_0
						[989] = 313, -- oldorsiniummap01_base_0
						[990] = 1,
						[991] = 1,
						[992] = 260, -- ogrimsyawn_base_0
						[993] = 1179, -- abahslanding_base_0
						[994] = 3330, -- hewsbane_base_0
						[995] = 105, -- pathtothemoo_library_base_0
						[996] = 540, -- fulstromhomestead_base_0
						[997] = 633, -- maw_of_lorkaj_base_0
						[998] = 1,
						[999] = 1,
						[1000] = 1,
						[1001] = 312, -- hiradirgecitadeltg3_base_0
						[1002] = 1,
						[1003] = 555, -- bahrahasgloom_base_0
						[1005] = 496, -- garlasagea_base_0
						[1006] = 3342, -- goldcoast_base_0
						[1007] = 371, -- hrotacave_base_0
						[1008] = 1,
						[1009] = 239, -- goldcoastrefuge_base_0
						[1010] = 419, -- fulstromcatacombs_base_0
						[1011] = 1,
						[1013] = 335, -- safehouse_base_0
						[1014] = 1,
						[1015] = 1,
						[1016] = 1,
						[1017] = 1,
						[1018] = 1,
						[1019] = 1,
						[1020] = 1,
						[1021] = 1,
						[1022] = 1,
						[1024] = 1,
						[1025] = 635, -- sharktoothgrotto1_base_0
						[1026] = 1,
						[1027] = 1,
						[1028] = 1,
						[1029] = 1,
						[1030] = 635, -- sharktoothgrotto2_base_0
						[1031] = 1,
						[1032] = 172, -- sulimamansion_floor1_0
						[1033] = 172, -- sulimamansion_floor1_hidden_0
						[1034] = 172, -- sulimamansion_floor2_0
						[1035] = 172, -- sulimamansion_floor2_hidden_0
						[1036] = 1,
						[1037] = 1,
						[1038] = 1179, -- abahslanding_sulima_base_0
						[1039] = 1179, -- abahslanding_velmont_base_0
						[1040] = 1,
						[1041] = 1,
						[1042] = 1,
						[1044] = 1,
						[1045] = 1,
						[1046] = 1,
						[1047] = 1,
						[1048] = 1,
						[1049] = 1,
						[1050] = 1,
						[1051] = 1,
						[1052] = 1,
						[1053] = 1,
						[1054] = 1,
						[1055] = 1,
						[1056] = 1,
						[1057] = 1,
						[1058] = 1,
						[1059] = 1,
						[1060] = 6020, -- vvardenfell_base_0
						[1061] = 1,
						[1062] = 1,
						[1063] = 1,
						[1064] = 648, -- kvatchcity_base_0
						[1065] = 129, -- hrotacave02_base_0
						[1066] = 1,
						[1067] = 1,
						[1068] = 1,
						[1069] = 282, -- tribunesfolly_base_0
						[1070] = 1,
						[1071] = 1,
						[1072] = 1,
						[1073] = 1,
						[1074] = 757, -- anvilcity_base_0
						[1075] = 1,
						[1076] = 441, -- thaliasretreat_base_0
						[1077] = 442, -- mtharnaz_base_0
						[1078] = 1, -- cryptoftarishzi2_base_0
						[1079] = 351, -- cryptoftarishzi_base_0
						[1080] = 799, -- cryptoftarishzizone_base_0
						[1081] = 670, -- hircineshaunt_base_0
						[1082] = 1, -- rahniza_1_0
						[1083] = 1, -- rahniza_2_0
						[1084] = 1, -- shadahallofworship_base_0
						[1085] = 1, -- shadamaincity_base_0
						[1086] = 1, -- rahniza_3_0
						[1087] = 1, -- shadacitydistrict_base_0
						[1088] = 1, -- shadaburialgrounds_base_0
						[1089] = 388, -- rkhardahrk_0
						[1090] = 402, -- rkundzelft_base_0
						[1091] = 332, -- elinhirmagevision_base_0
						[1092] = 1, -- elinhirsewerworks_base_0
						[1093] = 567, -- burriedsands_base_0
						[1094] = 526, -- balamath_base_0
						[1095] = 1, -- balamathairmonarchcham_base_0
						[1096] = 1, -- balamathlibrary_base_0
						[1097] = 764, -- themagesstaff_base_0
						[1098] = 1, -- stormlair_base_0
						[1099] = 382, -- molavar_base_0
						[1100] = 435, -- haddock_base_0
						[1101] = 424, -- chiselshriek_base_0
						[1102] = 452, -- kardala_base_0
						[1103] = 1, -- seekersarchiveup_base_0
						[1104] = 1, -- seekersarchivedown_base_0
						[1105] = 1, -- reinholdsretreatcave_base_0
						[1106] = 673, -- howlingsepulchersoverland_base_0
						[1107] = 263, -- crgwamasucave_base_0
						[1108] = 1, -- frostmonarchlair_base_0
						[1109] = 239, -- ilthagsundertower_base_0
						[1110] = 451, -- fearfang_base_0
						[1111] = 1, -- skyreachtemple_base_0
						[1112] = 247, -- ilthagsundertower02_base_0
						[1113] = 192, -- howlingsepulcherscave_base_0
						[1114] = 1, -- skyreachpinnacle_base_0
						[1115] = 556, -- serpentsnest_base_0
						[1116] = 488, -- lothna_base_0
						[1117] = 565, -- exarchsstronghold_base_0
						[1118] = 1, -- howlingsepulchersscrying_base_0
						[1119] = 1, -- skyreachcatacombs1_base_0
						[1120] = 1, -- skyreachcatacombs2_base_0
						[1121] = 1, -- skyreachcatacombs3_base_0
						[1122] = 1, -- skyreachcatacombs4_base_0
						[1123] = 1, -- skyreachcatacombs5_base_0
						[1124] = 98, -- ateliertwicebornstar_base_0
						[1125] = 195, -- craglornoutlawrefuge_base_0
						[1126] = 4682, -- craglorn_base_0
						[1127] = 1,
						[1128] = 1,
						[1129] = 1,
						[1130] = 1,
						[1131] = 659, -- belkarth_base_0
						[1132] = 458, -- craglorn_dragonstar_base_0
						[1133] = 346, -- ui_cradleofshadowsint_001_base_0
						[1134] = 400, -- ui_cradleofshadowsint_002_base_0
						[1135] = 306, -- ui_cradleofshadowsint_003_base_0
						[1136] = 280, -- ui_cradleofshadowsint_004_base_0
						[1137] = 572, -- ui_cradleofshadowsint_005_base_0
						[1138] = 189, -- skyreachhold1_base_0
						[1140] = 1,
						[1141] = 1,
						[1142] = 332, -- elinhirmagevision_base_0
						[1143] = 1, -- eldenhollow_base_0
						[1146] = 1, -- eldenhollowheroic1_base_0
						[1147] = 1, -- eldenhollowheroic2_base_0
						[1148] = 549, -- thebanishedcells_base_0
						[1149] = 490, -- wayrestsewers_base_0
						[1150] = 653, -- fungalgrotto_base_0
						[1151] = 1, -- fungalgrottosecretroom_base_0
						[1152] = 652, -- darkshadecaverns_base_0
						[1153] = 1, -- darkshadecavernsheroic_base_0
						[1154] = 603, -- cryptofhearts_base_0
						[1156] = 523, -- spindleclutch_base_0
						[1157] = 488, -- khartagpoint_base_0
						[1158] = 230, -- ashalmawia_base_0
						[1159] = 600, -- zainsipilu_base_0
						[1160] = 560, -- matusakin_base_0
						[1161] = 320, -- pulklower_base_0
						[1162] = 244, -- nchuleft_base_0
						[1178] = 1,
						[1201] = 1,
						[1202] = 1,
						[1203] = 1,
						[1204] = 1,
						[1207] = 1,
						[1208] = 1,
						[1209] = 1,
						[1210] = 1,
						[1211] = 1,
						[1212] = 1,
						[1213] = 1,
						[1214] = 1,
						[1215] = 1,
						[1216] = 1,
						[1217] = 1,
						[1218] = 1,
						[1219] = 1,
						[1220] = 1,
						[1221] = 1,
						[1222] = 1,
						[1224] = 1,
						[1225] = 1,
						[1230] = 1,
						[1231] = 1,
						[1232] = 1,
						[1233] = 1,
						[1234] = 1,
						[1235] = 1,
						[1236] = 1,
						[1237] = 1,
						[1238] = 1,
						[1239] = 1,
						[1240] = 1,
						[1241] = 1,
						[1242] = 1,
						[1243] = 1,
						[1244] = 1,
						[1245] = 1,
						[1246] = 1,
						[1247] = 1,
						[1248] = 1,
						[1249] = 1,
						[1250] = 1,
						[1251] = 1,
						[1252] = 1,
						[1253] = 1,
						[1254] = 1,
						[1255] = 1,
						[1256] = 1,
						[1257] = 1,
						[1258] = 1,
						[1259] = 1,
						[1260] = 1,
						[1261] = 1,
						[1262] = 1,
						[1263] = 1,
						[1264] = 1,
						[1265] = 1,
						[1266] = 1,
						[1267] = 1,
						[1268] = 1,
						[1269] = 1,
						[1270] = 1,
						[1271] = 1,
						[1272] = 1,
						[1273] = 1,
						[1274] = 374, -- ashalmawia02_base_0
						[1275] = 374, -- ashalmawia03_base_0
						[1276] = 780, -- forgottenwastesext_base_0
						[1277] = 440, -- cavernsofkogoruhnfw03_base_0
						[1278] = 350, -- forgottendepthsfw04_base_0
						[1279] = 246, -- koradurfw02_base_0
						[1280] = 184, -- drinithtombfw01_base_0
						[1281] = 1,
						[1282] = 186, -- nchuleft2_base_0
						[1283] = 320, -- nchuleftdepths_base_0
						[1284] = 1,
						[1285] = 1,
						[1286] = 1,
						[1287] = 1138, -- viviccity_base_0
						[1288] = 1,
						[1289] = 1,
						[1290] = 1,
						[1291] = 1,
						[1292] = 1,
						[1293] = 1,
						[1294] = 1,
						[1295] = 1,
						[1296] = 1,
						[1297] = 1,
						[1298] = 1,
						[1299] = 1,
						[1300] = 340, -- pulkupper_base_0
						[1301] = 1,
						[1307] = 1,
						[1308] = 1,
						[1309] = 1,
						[1310] = 218, -- nchuleftingth1_base_0
						[1311] = 690, -- nchuleftingth2_base_0
						[1312] = 690, -- nchuleftingth3_base_0
						[1313] = 3334, -- clockwork_base_0
						[1314] = 670, -- nchuleftingth4_base_0
						[1315] = 478, -- nchuleftingth5_base_0
						[1316] = 478, -- nchuleftingth5_base_0
						[1317] = 1,
						[1318] = 278, -- nchuleftingth7_base_0
						[1319] = 1,
						[1320] = 1,
						[1321] = 1,
						[1322] = 1,
						[1323] = 1,
						[1324] = 1,
						[1325] = 1,
						[1326] = 1260, -- evergloam_base_0
						[1327] = 1,
						[1328] = 1,
						[1329] = 1,
						[1330] = 1,
						[1331] = 1,
						[1332] = 1,
						[1333] = 564, -- ventralterminus01_base_0
						[1334] = 422, -- ccq5_fl2_base_0
						[1335] = 1,
						[1336] = 336, -- ccq7_map1_base_0
						[1337] = 364, -- ccq7_map2_base_0
						[1338] = 376, -- ccq7_map3_base_0
						[1339] = 174, -- ccq7_map4_base_0
						[1340] = 260, -- oasis_map1_base_0
						[1341] = 535, -- oasis_map2_base_0
						[1342] = 1,
						[1343] = 757, -- anvilcity_base_0
						[1344] = 1,
						[1345] = 6020, -- vvardenfell_base_0
						[1346] = 1,
						[1347] = 1,
						[1348] = 1194, -- brassfortress_base_0
						[1349] = 7040, -- summerset_base_0
						[1350] = 1,
						[1351] = 1,
						[1352] = 1,
						[1353] = 1,
						[1354] = 1,
						[1355] = 1,
						[1356] = 1,
						[1357] = 1,
						[1358] = 1,
						[1359] = 1,
						[1360] = 1,
						[1361] = 1,
						[1362] = 656, -- ccunderground02_base_0
						[1363] = 564, -- ventralterminus02_base_0
						[1364] = 1,
						[1365] = 4964, -- glenumbra_base_0
						[1366] = 638, -- kingshavenext_base_0
						[1367] = 460, -- kingshavenint1_base_0
						[1368] = 1,
						[1369] = 1,
						[1370] = 1,
						[1371] = 1,
						[1372] = 486, -- etonnir_01_base_0
						[1373] = 126, -- etonnir_02_base_0
						[1374] = 1,
						[1375] = 1,
						[1376] = 1,
						[1377] = 504, -- torhamekhard_01_base_0
						[1378] = 504, -- torhamekhard_02_base_0
						[1379] = 422, -- ccq5_fl1_base_0
						[1380] = 628, -- sinkhole_base_0
						[1381] = 1,
						[1382] = 1,
						[1383] = 1,
						[1384] = 360, -- ccq7_map5_base_0
						[1385] = 226, -- basilica_01_base_0
						[1386] = 226, -- basilica_02_base_0
						[1387] = 100, -- basilica_03_base_0
						[1388] = 240, -- psijicrelicvaults01_base_0
						[1389] = 1,
						[1390] = 1,
						[1391] = 1,
						[1392] = 1,
						[1393] = 544, -- sq5mephalaext01_base_0
						[1394] = 134, -- sq5mephalaint01_base_0
						[1395] = 268, -- sq5mephalaint02_base_0
						[1396] = 268, -- sq5mephalaint02b_base_0
						[1397] = 1300, -- sum_karnwasten_base_0
						[1398] = 1,
						[1399] = 1,
						[1400] = 1,
						[1401] = 1,
						[1402] = 1,
						[1403] = 632, -- sq6evergloam_base_0
						[1404] = 640, -- ebonstadmont_base_0
						[1405] = 416, -- sq7courtofbedlamruins_base_0
						[1406] = 1,
						[1407] = 1,
						[1408] = 1,
						[1409] = 1,
						[1410] = 1,
						[1411] = 254, -- sq4sapiarch01_base_0
						[1412] = 166, -- sq4sapiarch02_base_0
						[1413] = 530, -- crystaltower_approach_base_0
						[1414] = 254, -- crystaltower_entryway_base_0
						[1415] = 234, -- crystaltower_trophy02_base_0
						[1416] = 310, -- crystaltower_library_base_0
						[1417] = 184, -- crystaltower_mausoleum_base_0
						[1418] = 118, -- crystaltower_barrier_base_0
						[1419] = 162, -- crystaltower_top_base_0
						[1420] = 432, -- ceytarncaveext01_base_0
						[1421] = 202, -- ceytarncaveint01_base_0
						[1422] = 1,
						[1423] = 1,
						[1424] = 1,
						[1425] = 1,
						[1426] = 1,
						[1427] = 1,
						[1428] = 3342, -- goldcoast_base_0
						[1429] = 2040, -- artaeum_base_0
						[1430] = 764, -- alinor_base_0
						[1431] = 1044, -- shimmerene_base_0
						[1432] = 508, -- ui_map_scalecaller001_base_0
						[1433] = 1,
						[1434] = 1,
						[1435] = 1,
						[1436] = 1,
						[1437] = 1,
						[1438] = 1170, -- sunhold_base_0
						[1439] = 1,
						[1440] = 1,
						[1441] = 1,
						[1442] = 1,
						[1443] = 1,
						[1444] = 1,
						[1445] = 140, -- alinorroyalpalace1_base_0
						[1446] = 1,
						[1447] = 1,
						[1448] = 1,
						[1449] = 1,
						[1450] = 1,
						[1453] = 1,
						[1454] = 1,
						[1455] = 630, -- lillandrill_base_0
						[1457] = 148, -- sum_wgtthroneroom_base_0
						[1458] = 1,
						[1459] = 1,
						[1460] = 1,
						[1461] = 380, -- monasteryoshfloor03_base_0
						[1462] = 1,
						[1463] = 1,
						[1464] = 1,
						[1465] = 1,
						[1466] = 166, -- ebonstadmont02_base_0
						[1467] = 166, -- ebonstadmont03_base_0
						[1468] = 1,
						[1469] = 1100, -- wastencoraldale_base_0
						[1470] = 102, -- dreamingcave01_base_0
						[1471] = 1,
						[1472] = 1,
						[1473] = 1,
						[1474] = 1,
						[1475] = 1,
						[1476] = 230, -- dreamingcave02_base_0
						[1477] = 1,
						[1478] = 1,
						[1479] = 1,
						[1480] = 1,
						[1482] = 1,
						[1483] = 1,
						[1484] = 3378, -- murkmire_base_0
						[1485] = 1,
						[1486] = 188, -- crystaltower_entryway02_base_0
						[1487] = 254, -- crystaltower_unfolding_base_0
						[1488] = 140, -- dreamingcave03_base_0
						[1489] = 140, -- dreamingcave03_base_0
						[1490] = 140, -- dreamingcave03_base_0
						[1491] = 234, -- crystaltower_trophy01_base_0
						[1492] = 216, -- collegeofpsijicsruins_base_0
						[1493] = 1,
						[1495] = 296, -- crystaltower_top02_base_0
						[1496] = 1,
						[1497] = 350, -- sq5mephalaint03_base_0
						[1498] = 1,
						[1499] = 134, -- sq5mephalaint01b_base_0
						[1500] = 1,
						[1502] = 1,
						[1503] = 216, -- collegeofpsijicsruins_base_0
						[1504] = 654, -- colossalaldmerigrotto_base_0
						[1505] = 1,
						[1506] = 584, -- ui_map_tsofeercavern01_0
						[1507] = 226, -- teethofsithis01_base_0
						[1508] = 306, -- teethofsithis02a_base_0
						[1509] = 1,
						[1510] = 1,
						[1511] = 1,
						[1512] = 1,
						[1513] = 316, -- uprootedhideout_ad1_base_0
						[1514] = 1,
						[1515] = 1,
						[1516] = 1,
						[1517] = 1,
						[1518] = 1,
						[1519] = 1810, -- marchodsacrifices_base_0
						[1520] = 1,
						[1521] = 364, -- swampisland_base_0
						[1522] = 1,
						[1523] = 1,
						[1524] = 1,
						[1525] = 1,
						[1526] = 1,
						[1527] = 1,
						[1528] = 1,
						[1529] = 1,
						[1530] = 1,
						[1531] = 1,
						[1532] = 1,
						[1533] = 1,
						[1534] = 1,
						[1535] = 316, -- uprootedhideout_ad2_base_0
						[1536] = 1,
						[1537] = 1,
						[1538] = 1,
						[1539] = 1,
						[1540] = 1,
						[1541] = 1,
						[1542] = 1,
						[1543] = 1,
						[1544] = 1,
						[1545] = 558, -- psijicmanor_ext1_base_0
						[1546] = 204, -- psijicmanor_int1_base_0
						[1547] = 204, -- psijicmanor_int1_base_0
						[1548] = 204, -- psijicmanor_int1_base_0
						[1549] = 204, -- psijicmanor_int2_base_0
						[1550] = 1,
						[1551] = 1,
						[1552] = 684, -- swampisland_ext_base_0
						[1553] = 1810, -- marchodsacrifices_base_0
						[1555] = 6308, -- elsweyr_base_0
						[1556] = 630, -- ui_map_blackroseprison01_base_0
						[1557] = 1,
						[1558] = 1,
						[1559] = 1,
						[1560] = 902, -- lilmothcity_base_0
						[1561] = 358, -- brightthroatvillage_base_0
						[1562] = 546, -- deadwatervillage_base_0
						[1563] = 1,
						[1564] = 1,
						[1565] = 1,
						[1566] = 1,
						[1567] = 1,
						[1568] = 1,
						[1569] = 1,
						[1572] = 1,
						[1573] = 1,
						[1574] = 1,
						[1576] = 906, -- rimmen_base_0
						[1579] = 1,
						[1580] = 1,
						[1581] = 1,
						[1582] = 1,
						[1583] = 1,
						[1588] = 1,
						[1589] = 1,
						[1596] = 1,
						[1597] = 1,
						[1598] = 1,
						[1599] = 1,
						[1600] = 1,
						[1601] = 1,
						[1602] = 1,
						[1603] = 1,
						[1604] = 1,
						[1605] = 1,
						[1606] = 1,
						[1607] = 1,
						[1621] = 1,
						[1622] = 1,}
FyrMM.Panel = {
	type = "panel",
	name = "MiniMap by Fyrakin",
	displayName = GetString(SI_MM_STRING_SETTINGS),
	author = "|c3CB371@Masteroshi430|r, |c006600Fyrakin|r, Zerorez, deathangel1479",
	version = "2026.09.28",
	website = "https://www.esoui.com/downloads/info3384-MiniMapbyFyrakinMasteroshi430sbranch.html",
	slashCommand = "/fyrmmset",
	registerForRefresh = true,
	registerForDefaults = true,
}

	FyrMM.Options = {
	[1] = { type = "checkbox", name = GetString(SI_MM_SETTING_ZYGOR), tooltip = GetString(SI_MM_SETTING_ZYGOR_TOOLTIP),
			getFunc = function() return FyrMM.SV.UseOriginalAPI end,
			setFunc = function(value) MM_SetUseOriginalAPI(value) end,
			width = "full",	default = true,	},
	[2] = { type = "checkbox", name = GetString(SI_MM_SETTING_STARTUP), tooltip = GetString(SI_MM_SETTING_STARTUP_TOOLTIP),
		getFunc = function() return FyrMM.SV.StartupInfo end,
		setFunc = function(value) FyrMM.SV.StartupInfo = value end,
		width = "half", default = false, }, 
	[3] = { type = "checkbox", name = GetString(SI_MM_SETTING_EYEFK), tooltip = GetString(SI_MM_SETTING_EYEFK_TOOLTIP),
		getFunc = function() return FyrMM.SV.noEyeFK end,
		setFunc = function(value) FyrMM.SV.noEyeFK = value end,
		width = "half", default = false, }, 	
	[4] = { type = "checkbox", name = GetString(SI_MM_SETTING_MENU), tooltip = GetString(SI_MM_SETTING_MENU_TOOLTIP),
			getFunc = function() return FyrMM.SV.MenuDisabled end,
			setFunc = function(value) FyrMM.SV.MenuDisabled = value if value then Fyr_MM_Menu:SetHidden(true) MM_SetZoneFrameLocationOption(FyrMM.SV.ZoneFrameLocationOption) else Fyr_MM_Menu:SetHidden(false) MM_SetZoneFrameLocationOption(FyrMM.SV.ZoneFrameLocationOption) end end,
			width = "half", default = false, },
	[5] = { type = "checkbox", name = GetString(SI_MM_SETTING_MENUAUTOHIDE), tooltip = GetString(SI_MM_SETTING_MENUAUTOHIDE_TOOLTIP),
			getFunc = function() return FyrMM.SV.MenuAutoHide end,
			setFunc = function(value) FyrMM.SV.MenuAutoHide = value if not value then Fyr_MM_Menu:SetAlpha(1) else FyrMM.MenuFadeOut() end end,
			width = "half", default = false, disabled = function() return FyrMM.SV.MenuDisabled end },
	[6] = { type = "button", name = GetString(SI_MM_SETTING_WHEELDEFAULTS), tooltip = GetString(SI_MM_SETTING_WHEELDEFAULTS_TOOLTIP),
								func = function() MM_WheelModeDefaults() end, width = "half", },
	[7] = { type = "button", name = GetString(SI_MM_SETTING_SQUAREDEFAULTS), tooltip = GetString(SI_MM_SETTING_SQUAREDEFAULTS_TOOLTIP),
								func = function() MM_SquareModeDefaults() end, width = "half", },
								
	[8] = { type = "submenu", name = GetString(SI_MM_SETTING_COMPASSOPTIONS),							
			controls = {
						[1] = { type = "checkbox", name = GetString(SI_MM_SETTING_COMPASS), tooltip = GetString(SI_MM_SETTING_COMPASS_TOOLTIP),
								getFunc = function() return MM_GetHideCompass() end,
								setFunc = function(value) MM_SetHideCompass(value) end,
								width = "half", default = false, },
						[2] = { type = "checkbox", name = GetString(SI_MM_SETTING_COMPASS_IN_AVA_ZONE_ONLY), tooltip = GetString(SI_MM_SETTING_COMPASS_IN_AVA_ZONE_ONLY_TOOLTIP),
								getFunc = function() return MM_GetShowCompassInAvAZoneOnly() end,
								setFunc = function(value) MM_SetShowCompassInAvAZoneOnly(value) end,
								width = "half", default = false, },
						[3] = { type = "checkbox", name = GetString(SI_MM_SETTING_MINI_COMPASS), tooltip = GetString(SI_MM_SETTING_MINI_COMPASS_TOOLTIP),
								getFunc = function() return MM_GetMiniCompassOption() end,
								setFunc = function(value) MM_SetMiniCompassOption(value) end,
								width = "half", default = false, disabled = function() return MM_GetHideCompass() end },
						[4] = {	type = "dropdown", name = GetString(SI_MM_SETTING_MINI_COMPASS_LOCATION), tooltip = GetString(SI_MM_SETTING_MINI_COMPASS_LOCATION_TOOLTIP),
								choices = {"Top", "Bottom"},
								getFunc = function() return FyrMM.SV.miniCompassLocation end,
								setFunc = function(value) MM_SetMiniCompassLocation(value) end,
								width = "half", default = "Top", disabled = function() return not MM_GetMiniCompassOption() end},
						[5] = { type = "checkbox", name = GetString(SI_MM_SETTING_NO_BOSS_BAR), tooltip = GetString(SI_MM_SETTING_NO_BOSS_BAR_TOOLTIP),
								getFunc = function() return MM_GetNoBossBar() end,
								setFunc = function(value) MM_SetNoBossBar(value) end,
								width = "half", default = false, disabled = function() return not MM_GetMiniCompassOption() end }, }, },
								
	[9] = { type = "submenu", name = GetString(SI_MM_SETTING_SIZEOPTIONS),
			controls = {
						[1] = { type = "slider", name = GetString(SI_MM_SETTING_WIDTH), tooltip = GetString(SI_MM_SETTING_WIDTH_TOOLTIP),
								min = 50, max = zo_round(GuiRoot:GetWidth()), step = 1,
								getFunc = function() return MM_GetMapWidth() end,
								setFunc = function(value) MM_SetMapWidth(value) end,
								width = "half",	disabled = function() return FyrMM.SV.LockResizing end, default = 280, },
						[2] = {	type = "slider", name = GetString(SI_MM_SETTING_HEIGHT), tooltip = GetString(SI_MM_SETTING_HEIGHT_TOOLTIP),
								min = 50, max = zo_round(GuiRoot:GetHeight()), step = 1,
								getFunc = function() return MM_GetMapHeight() end,
								setFunc = function(value) MM_SetMapHeight(value) end,
								width = "half",	 disabled = function() return FyrMM.SV.LockResizing end, default = 280, },
						[3] = { type = "checkbox", name = GetString(SI_MM_SETTING_LOCK), tooltip = GetString(SI_MM_SETTING_LOCK_TOOLTIP),
								getFunc = function() return FyrMM.SV.LockResizing end,
								setFunc = function(value) MM_SetLockResizing(value) end,
								width = "half",	default = false, },
                }, },
								
	[10] = { type = "submenu", name = GetString(SI_MM_SETTING_MODEOPTIONS),
			controls = {
						[1] = { type = "slider", name = GetString(SI_MM_SETTING_ALPHA), tooltip = GetString(SI_MM_SETTING_ALPHA_TOOLTIP),
								min = 5, max = 100, step = 1,
								getFunc = function() return MM_GetMapAlpha() end,
								setFunc = function(value) MM_SetMapAlpha(value) end,
								width = "half",	default = 100, },
						[2] = { type = "slider", name = GetString(SI_MM_SETTING_DEFAULTZOOM), tooltip = GetString(SI_MM_SETTING_DEFAULTZOOM_TOOLTIP),
								min = FYRMM_ZOOM_MIN, max = FYRMM_ZOOM_MAX, step = FYRMM_ZOOM_INCREMENT_AMOUNT,
								getFunc = function() return FYRMM_DEFAULT_ZOOM_LEVEL end,
								setFunc = function(value) FYRMM_DEFAULT_ZOOM_LEVEL = value FyrMM.SV.DefaultZoomLevel = value end,
								width = "half",	default = 10, },
						[3] = { type = "slider", name = GetString(SI_MM_SETTING_CURRENTZOOM), tooltip = GetString(SI_MM_SETTING_CURRENTZOOM_TOOLTIP),
								min = FYRMM_ZOOM_MIN, max = FYRMM_ZOOM_MAX, step = FYRMM_ZOOM_INCREMENT_AMOUNT,
								getFunc = function() return FyrMM.currentMap.ZoomLevel end,
								setFunc = function(value) FyrMM.SetCurrentMapZoom(value) end,
								width = "half",	default = FYRMM_DEFAULT_ZOOM_LEVEL, },
						[4] = { type = "slider", name = GetString(SI_MM_SETTING_ZOOMSTEPPING), tooltip = GetString(SI_MM_SETTING_ZOOMSTEPPING_TOOLTIP),
								min = 0.1, max = 2, step = 0.1,
								getFunc = function() return FYRMM_ZOOM_INCREMENT_AMOUNT end,
								setFunc = function(value) value = ("%1.1f"):format(value) FYRMM_ZOOM_INCREMENT_AMOUNT = tonumber(value) FyrMM.SV.ZoomIncrement = tonumber(value) end,
								width = "half",	default = 1, },
						[5] = {	type = "slider", name = GetString(SI_MM_SETTING_PINSCALE), tooltip = GetString(SI_MM_SETTING_PINSCALE_TOOLTIP),
								min = 25, max = 150, step = 1,
								getFunc = function() return MM_GetPinScale() end,
								setFunc = function(value) MM_SetPinScale(value) end,
								width = "half",	default = 75, },
						[6] = { type = "checkbox", name = GetString(SI_MM_SETTING_AUTORESIZEPIN), tooltip = GetString(SI_MM_SETTING_AUTORESIZEPIN_TOOLTIP),
								getFunc = function() return FyrMM.SV.autoResizePin end,
								setFunc = function(value) FyrMM.SV.autoResizePin = value end,
								width = "half",	default = false, },		
						[7] = {	type = "dropdown", name = GetString(SI_MM_SETTING_HEADING), tooltip = GetString(SI_MM_SETTING_HEADING_TOOLTIP),
								choices = {"CAMERA", "PLAYER", "MIXED"},
								getFunc = function() return MM_GetHeading() end,
								setFunc = function(value) MM_SetHeading(value) end,
								width = "half", default = "CAMERA", disabled = function() return FyrMM.SV.RotateMap end,},
						[8] = { type = "checkbox", name = GetString(SI_MM_SETTING_PVP), tooltip = GetString(SI_MM_SETTING_PVP_TOOLTIP),
								getFunc = function() return MM_GetHidePvPPins() end,
								setFunc = function(value) MM_SetHidePvPPins(value) end,
								width = "half",	default = false, },
						[9] = { type = "checkbox", name = GetString(SI_MM_SETTING_ROTATION), tooltip = GetString(SI_MM_SETTING_ROTATION_TOOLTIP),
								getFunc = function() return FyrMM.SV.RotateMap end,
								setFunc = function(value) MM_SetRotateMap(value) if not value then FyrMM.PendingRotatePins = {} end end,
								width = "half",	default = false,	},
						[10] = { type = "checkbox", name = GetString(SI_MM_SETTING_WHEEL), tooltip = GetString(SI_MM_SETTING_WHEEL_TOOLTIP),
								getFunc = function() return FyrMM.SV.WheelMap end,
								setFunc = function(value) MM_SetWheelMap(value) if not value then FyrMM.PendingWheelPins = {} end end,
								width = "half",	default = false,	},
						[11] = { type = "checkbox", name = GetString(SI_MM_SETTING_VIEWRANGE), tooltip = GetString(SI_MM_SETTING_VIEWRANGE_TOOLTIP),
								getFunc = function() return FyrMM.SV.ViewRangeFiltering end,
								setFunc = function(value) FyrMM.SV.ViewRangeFiltering = value end,
								width = "half",	default = false,	},
						[12] = { type = "slider", name = GetString(SI_MM_SETTING_RANGE), tooltip = GetString(SI_MM_SETTING_RANGE_TOOLTIP),
								min = 50, max = 1000, step = 1,
								getFunc = function() return FyrMM.SV.CustomPinViewRange end,
								setFunc = function(value) FyrMM.SV.CustomPinViewRange = value end,
								width = "half",	default = 250, disabled = function() return not FyrMM.SV.ViewRangeFiltering end },
                        [13] = { type = "dropdown", name = GetString(SI_MM_SETTING_MAP_HEADING), tooltip = GetString(SI_MM_SETTING_MAP_HEADING_TOOLTIP),
								choices = {"CAMERA", "PLAYER"},
								getFunc = function() return MM_GetMapHeading() end,
								setFunc = function(value) MM_SetMapHeading(value) end,
								width = "half", default = "CAMERA", disabled = function() return not FyrMM.SV.RotateMap end,},
						[14] = { type = "checkbox", name = GetString(SI_MM_SETTING_CARDINAL_POINTS), tooltip = GetString(SI_MM_SETTING_CARDINAL_POINTS_TOOLTIP),
								getFunc = function() return FyrMM.SV.CardinalPoints end,
								setFunc = function(value) MM_SetCardinalPoints(value) end,
								width = "half",	default = false, disabled = function() return not FyrMM.SV.WheelMap or not FyrMM.SV.RotateMap end},	
						[15] = { type = "dropdown", name = GetString(SI_MM_SETTING_WHEELTEXTURE), tooltip = GetString(SI_MM_SETTING_WHEELTEXTURE_TOOLTIP),
								choices = FyrMM.WheelTextureList,
								getFunc = function() return FyrMM.SV.WheelTexture end,
								setFunc = function(value) MM_SetWheelTexture(value) end,
								width = "full", default = "Deathangel RMM Wheel", disabled = function() return not FyrMM.SV.WheelMap end,},
						[16]  = { type = "dropdown", name = GetString(SI_MM_SETTING_MENUTEXTURE), tooltip = GetString(SI_MM_SETTING_MENUTEXTURE_TOOLTIP),
								choices = FyrMM.MenuTextureList,
								getFunc = function() return FyrMM.SV.MenuTexture end,
								setFunc = function(value) MM_SetMenuTexture(value) end,
								width = "full", default = "Default" },
						[17] = { type = "checkbox", name = GetString(SI_MM_SETTING_UNDISCOVERED_SKYSHARDS), tooltip = GetString(SI_MM_SETTING_UNDISCOVERED_SKYSHARDS_TOOLTIP),
								getFunc = function() return FyrMM.SV.ShowUndiscoveredSkyshards end,
								setFunc = function(value) FyrMM.SV.ShowUndiscoveredSkyshards = value FyrMM.skyshardPins() end,
								width = "full",	default = false, disabled = function() return SkyShards ~= nil or SimpleSkyshards ~= nil end,},
						[18] = { type = "checkbox", name = GetString(SI_MM_SETTING_UNEXPLORED), tooltip = GetString(SI_MM_SETTING_UNEXPLORED_TOOLTIP),
								getFunc = function() return FyrMM.SV.ShowUnexploredPins end,
								setFunc = function(value) MM_SetShowUnexploredPins(value) end,
								width = "half",	default = true,	},
						[19] = { type = "colorpicker", name = GetString(SI_MM_SETTING_UNEXPLOREDCOLOR), tooltip = GetString(SI_MM_SETTING_UNEXPLOREDCOLOR_TOOLTIP),
								getFunc = function() return FyrMM.SV.UndiscoveredPOIPinColor.r, FyrMM.SV.UndiscoveredPOIPinColor.g, FyrMM.SV.UndiscoveredPOIPinColor.b, FyrMM.SV.UndiscoveredPOIPinColor.a end,
								setFunc = function(r,g,b,a) MM_SetUndiscoveredPOIPinColor(r, g, b, a) end,
								width = "half",disabled = function() return not FyrMM.SV.ShowUnexploredPins end,  },
						[20] = { type = "checkbox", name = GetString(SI_MM_SETTING_TOOLTIPS), tooltip = GetString(SI_MM_SETTING_TOOLTIPS_TOOLTIP),
								getFunc = function() return MM_GetPinTooltips() end,
								setFunc = function(value) MM_SetPinTooltips(value) end,
								width = "half",	default = true,	},
						[21] = { type = "checkbox", name = GetString(SI_MM_SETTING_FASTTRAVEL), tooltip = GetString(SI_MM_SETTING_FASTTRAVEL_TOOLTIP),
								getFunc = function() return MM_GetFastTravelEnabled() end,
								setFunc = function(value) MM_SetFastTravelEnabled(value) end,
								width = "half",	default = true,	},
						[22] = { type = "checkbox", name = GetString(SI_MM_SETTING_MOUSEZOOM), tooltip = GetString(SI_MM_SETTING_MOUSEZOOM_TOOLTIP),
								getFunc = function() return MM_GetMouseWheel() end,
								setFunc = function(value) MM_SetMouseWheel(value) end,
								width = "half",	default = true,	},
						[23] = { type = "checkbox", name = GetString(SI_MM_SETTING_BORDER), tooltip = GetString(SI_MM_SETTING_BORDER_TOOLTIP),
								getFunc = function() return MM_GetShowBorder() end,
								setFunc = function(value) MM_SetShowBorder(value) end,
								width = "half",	default = true,	disabled = function() return FyrMM.SV.WheelMap end,},
						[24] = { type = "checkbox", name = GetString(SI_MM_SETTING_COMBATHIDE), tooltip = GetString(SI_MM_SETTING_COMBATHIDE_TOOLTIP),
								getFunc = function() return FyrMM.SV.InCombatAutoHide end,
								setFunc = function(value) MM_SetInCombatAutoHide(value) end,
								width = "half",	default = true,	},
						[25] = { type = "slider", name = GetString(SI_MM_SETTING_AUTOSHOW), tooltip = GetString(SI_MM_SETTING_AUTOSHOW_TOOLTIP),
								min = 1, max = 60, step = 1,
								getFunc = function() return FyrMM.SV.AfterCombatUnhideDelay end,
								setFunc = function(value) MM_SetAfterCombatUnhideDelay(value) end,
								width = "half",	default = 5, disabled = function() return not FyrMM.SV.InCombatAutoHide end },
						[26] = { type = "checkbox", name = GetString(SI_MM_SETTING_HOUSEHIDE), tooltip = GetString(SI_MM_SETTING_HOUSEHIDE_TOOLTIP),
								getFunc = function() return FyrMM.SV.InHouseAutoHide end,
								setFunc = function(value) MM_SetInHouseAutoHide(value) end,
								width = "half",	default = true,	},	
						[27] = { type = "checkbox", name = GetString(SI_MM_SETTING_EAHIDE), tooltip = GetString(SI_MM_SETTING_EAHIDE_TOOLTIP),
								getFunc = function() return FyrMM.SV.InEndlessDungeonAutoHide end,
								setFunc = function(value) MM_SetInEndlessDungeonAutoHide(value) end,
								width = "half",	default = true,	},
						[28] = { type = "checkbox", name = GetString(SI_MM_SETTING_SIEGE), tooltip = GetString(SI_MM_SETTING_SIEGE_TOOLTIP),
								getFunc = function() return FyrMM.SV.Siege end,
								setFunc = function(value) FyrMM.SV.Siege = value end,
								width = "half",	default = true, }, 
						[29] = { type = "checkbox", name = GetString(SI_MM_SETTING_SUBZONE), tooltip = GetString(SI_MM_SETTING_SUBZONE_TOOLTIP),
								getFunc = function() return FyrMM.SV.DisableSubzones end,
								setFunc = function(value) FyrMM.SV.DisableSubzones = value FyrMM.DisableSubzones = value end,
								width = "half",	default = false,	}, }, },
								
	[11] = { type = "submenu", name = GetString(SI_MM_SETTING_INFOOPTIONS),
			controls = {
						[1] = { type = "checkbox", name = GetString(SI_MM_SETTING_ZOOMLABEL), tooltip = GetString(SI_MM_SETTING_ZOOMLABEL_TOOLTIP),
								getFunc = function() return MM_GetHideZoomLevel() end,
								setFunc = function(value) MM_SetHideZoomLevel(value) end,
								width = "half",	default = false, },								
						[2] = { type = "checkbox", name = GetString(SI_MM_SETTING_CLOCK), tooltip = GetString(SI_MM_SETTING_CLOCK_TOOLTIP),
								getFunc = function() return FyrMM.SV.ShowClock end,
								setFunc = function(value) FyrMM.SV.ShowClock = value end,
								width = "half",	default = false, disabled = function() return FyrMM.SV.MenuDisabled end}, 
						[3] = { type = "header", name = "Coordinates", },	
						[4] = { type = "checkbox", name = GetString(SI_MM_SETTING_POSITION), tooltip = GetString(SI_MM_SETTING_POSITION_TOOLTIP),
								getFunc = function() return MM_GetShowPosition() end,
								setFunc = function(value) MM_SetShowPosition(value) end,
								width = "half",	default = true,	},
						[5] = { type = "checkbox", name = GetString(SI_MM_SETTING_POSITIONBACKGROUND), tooltip = GetString(SI_MM_SETTING_POSITIONBACKGROUND_TOOLTIP),
								getFunc = function() return FyrMM.SV.PositionBackground end,
								setFunc = function(value) MM_SetPositionBackground(value) end,
								width = "half",	default = true, disabled = function() return not MM_GetShowPosition() end},		
						[6] = {	type = "dropdown", name = GetString(SI_MM_SETTING_POSITIONLOCATION), tooltip = GetString(SI_MM_SETTING_POSITIONLOCATION_TOOLTIP),
								choices = {"Top", "Bottom", "Free"},
								getFunc = function() return FyrMM.SV.CoordinatesLocation end,
								setFunc = function(value) MM_SetCoordinatesLocation(value) end,
								width = "half", default = "Top", disabled = function() return not MM_GetShowPosition() end},
						[7] = { type = "colorpicker", name = GetString(SI_MM_SETTING_POSITIONCOLOR), tooltip = GetString(SI_MM_SETTING_POSITIONCOLOR_TOOLTIP),
								getFunc = function() return FyrMM.SV.PositionColor.r, FyrMM.SV.PositionColor.g, FyrMM.SV.PositionColor.b, FyrMM.SV.PositionColor.a end,
								setFunc = function(r,g,b,a) MM_SetPositionColor(r, g, b, a) end,
								width = "half", disabled = function() return not MM_GetShowPosition() end},
						[8] = {	type = "dropdown", name = GetString(SI_MM_SETTING_POSITIONFONT), tooltip = GetString(SI_MM_SETTING_POSITIONFONT_TOOLTIP),
								choices = FyrMM.FontList,
								getFunc = function() return FyrMM.SV.PositionFont end,
								setFunc = function(value) if value ~= nil then FyrMM.SV.PositionFont = value MM_SetPositionFont() end end,
								width = "half", default = "Univers 57", disabled = function() return not MM_GetShowPosition() end},
						[9] = { type = "slider", name = GetString(SI_MM_SETTING_POSITIONSIZE), tooltip = GetString(SI_MM_SETTING_POSITIONSIZE_TOOLTIP),
								min = 6, max = 50, step = 1,
								getFunc = function() return FyrMM.SV.PositionHeight end,
								setFunc = function(value) if value ~= nil then FyrMM.SV.PositionHeight = value MM_SetPositionFont() end end,
								width = "half",	default = 18, disabled = function() return not MM_GetShowPosition() end},
						[10] = {type = "dropdown", name = GetString(SI_MM_SETTING_POSITIONSTYLE), tooltip = GetString(SI_MM_SETTING_POSITIONSTYLE_TOOLTIP),
								choices = FyrMM.FontStyles,
								getFunc = function() return FyrMM.SV.PositionFontStyle end,
								setFunc = function(value) if value ~= nil then FyrMM.SV.PositionFontStyle = value MM_SetPositionFont() end end,
								width = "half", default = "normal", disabled = function() return not MM_GetShowPosition() end},
						[11] = { type = "header", name = "Zone Name", },	
						[12] = { type = "checkbox", name = GetString(SI_MM_SETTING_MAPNAME), tooltip = GetString(SI_MM_SETTING_MAPNAME_TOOLTIP),
								getFunc = function() return not MM_GetHideZoneLabel() end,
								setFunc = function(value) MM_SetHideZoneLabel(not value) end,
								width = "half", default = true, },
						[13] = { type = "checkbox", name = GetString(SI_MM_SETTING_MAPNAMEBACKGROUND), tooltip = GetString(SI_MM_SETTING_MAPNAMEBACKGROUND_TOOLTIP),
								getFunc = function() return FyrMM.SV.ShowZoneBackground end,
								setFunc = function(value) MM_SetShowZoneBackground(value) end,
								width = "half", default = true, disabled = function() return MM_GetHideZoneLabel() end},
						[14] = {	type = "dropdown", name = GetString(SI_MM_SETTING_MAPNAMELOCATION), tooltip = GetString(SI_MM_SETTING_MAPNAMELOCATION_TOOLTIP),
								choices = {"Default", "Free"},
								getFunc = function() return FyrMM.SV.ZoneFrameLocationOption end,
								setFunc = function(value) MM_SetZoneFrameLocationOption(value) end,
								width = "half", default = "Top", disabled = function() return MM_GetHideZoneLabel() end},
						[15] = { type = "colorpicker", name = GetString(SI_MM_SETTING_MAPNAMECOLOR), tooltip = GetString(SI_MM_SETTING_MAPNAMECOLOR_TOOLTIP),
								getFunc = function() return FyrMM.SV.ZoneNameColor.r, FyrMM.SV.ZoneNameColor.g, FyrMM.SV.ZoneNameColor.b, FyrMM.SV.ZoneNameColor.a end,
								setFunc = function(r,g,b,a) MM_SetZoneNameColor(r, g, b, a) end,
								width = "half", disabled = function() return MM_GetHideZoneLabel() end},
						[16] = {	type = "dropdown", name = GetString(SI_MM_SETTING_MAPNAMEFONT), tooltip = GetString(SI_MM_SETTING_MAPNAMEFONT_TOOLTIP),
								choices = FyrMM.FontList,
								getFunc = function() return FyrMM.SV.ZoneFont end,
								setFunc = function(value) if value ~= nil then FyrMM.SV.ZoneFont = value MM_SetZoneFont() end end,
								width = "half", default = "Univers 57", disabled = function() return MM_GetHideZoneLabel() end},
						[17] = { type = "slider", name = GetString(SI_MM_SETTING_MAPNAMESIZE), tooltip = GetString(SI_MM_SETTING_MAPNAMESIZE_TOOLTIP),
								min = 6, max = 50, step = 1,
								getFunc = function() return FyrMM.SV.ZoneFontHeight end,
								setFunc = function(value) if value ~= nil then FyrMM.SV.ZoneFontHeight = value MM_SetZoneFont() end end,
								width = "half",	default = 18, disabled = function() return MM_GetHideZoneLabel() end},
						[18] = {type = "dropdown", name = GetString(SI_MM_SETTING_MAPNAMEFONTSTYLE), tooltip = GetString(SI_MM_SETTING_MAPNAMEFONTSTYLE_TOOLTIP),
								choices = FyrMM.FontStyles,
								getFunc = function() return FyrMM.SV.ZoneFontStyle end,
								setFunc = function(value) if value ~= nil then FyrMM.SV.ZoneFontStyle = value MM_SetZoneFont() end end,
								width = "half", default = "normal", disabled = function() return MM_GetHideZoneLabel() end},
						[19] = { type = "dropdown", name = GetString(SI_MM_SETTING_MAPNAMESTYLE), tooltip = GetString(SI_MM_SETTING_MAPNAMESTYLE_TOOLTIP),
								choices = {"Classic (Map only)", "Map & Area", "Area only"},
								getFunc = function() return FyrMM.SV.ZoneNameContents end,
								setFunc = function(value) if value ~= nil then FyrMM.SV.ZoneNameContents = value FyrMM.UpdateLabels() end end,
								width = "half", default = "Classic (Map only)", disabled = function() return MM_GetHideZoneLabel() end},
						[20] = { type = "checkbox", name = GetString(SI_MM_SETTING_FORCE_AREA_CYRO), tooltip = GetString(SI_MM_SETTING_FORCE_AREA_CYRO_TOOLTIP),
								getFunc = function() return FyrMM.SV.ForceAreaOnlyInCyro end,
								setFunc = function(value) FyrMM.SV.ForceAreaOnlyInCyro = value end,
								width = "half",	default = false, disabled = function() return  FyrMM.SV.HideZoneLabel or FyrMM.SV.ZoneNameContents ~= "Classic (Map only)" end},	
						[21] = { type = "header", name = "Speed", },	
						[22] = { type = "checkbox", name = GetString(SI_MM_SETTING_SPEED), tooltip = GetString(SI_MM_SETTING_SPEED_TOOLTIP),
								getFunc = function() return FyrMM.SV.ShowSpeed end,
								setFunc = function(value) FyrMM.SV.ShowSpeed = value Fyr_MM_Speed:SetHidden(not value) end,
								width = "half",	default = false, },
						[23] = { type = "checkbox", name = GetString(SI_MM_SETTING_SPEEDBACKGROUND), tooltip = GetString(SI_MM_SETTING_SPEEDBACKGROUND_TOOLTIP),
								getFunc = function() return FyrMM.SV.SpeedBackground end,
								setFunc = function(value) MM_SetSpeedBackground(value) end,
								width = "half",	default = true, disabled = function() return not FyrMM.SV.ShowSpeed end},
						[24] = {type = "dropdown", name = GetString(SI_MM_SETTING_SPEEDLOCATION), tooltip = GetString(SI_MM_SETTING_SPEEDLOCATION_TOOLTIP),
								choices = {"Default", "Free"},
								getFunc = function() return FyrMM.SV.SpeedLocationOption end,
								setFunc = function(value) MM_SetSpeedLocationOption(value) end,	
                                width = "half", default = "Top", disabled = function() return not FyrMM.SV.ShowSpeed end},
						[25] = { type = "colorpicker", name = GetString(SI_MM_SETTING_SPEEDCOLOR), tooltip = GetString(SI_MM_SETTING_SPEEDCOLOR_TOOLTIP),
								getFunc = function() return FyrMM.SV.SpeedColor.r, FyrMM.SV.SpeedColor.g, FyrMM.SV.SpeedColor.b, FyrMM.SV.SpeedColor.a end,
								setFunc = function(r,g,b,a) MM_SetSpeedColor(r, g, b, a) end,
								width = "half", disabled = function() return not FyrMM.SV.ShowSpeed end},
						[26] = { type = "dropdown", name = GetString(SI_MM_SETTING_SPEEDFONT), tooltip = GetString(SI_MM_SETTING_SPEEDFONT_TOOLTIP),
								choices = FyrMM.FontList,
								getFunc = function() return FyrMM.SV.SpeedFont end,
								setFunc = function(value) if value ~= nil then FyrMM.SV.SpeedFont = value MM_SetSpeedFont() end end,
								width = "half", default = "Univers 57", disabled = function() return not FyrMM.SV.ShowSpeed end},
						[27] = { type = "slider", name = GetString(SI_MM_SETTING_SPEEDSIZE), tooltip = GetString(SI_MM_SETTING_SPEEDSIZE_TOOLTIP),
								min = 6, max = 50, step = 1,
								getFunc = function() return FyrMM.SV.SpeedHeight end,
								setFunc = function(value) if value ~= nil then FyrMM.SV.SpeedHeight = value MM_SetSpeedFont() end end,
								width = "half",	default = 18, disabled = function() return not FyrMM.SV.ShowSpeed end},
						[28] = { type = "dropdown", name = GetString(SI_MM_SETTING_SPEEDSTYLE), tooltip = GetString(SI_MM_SETTING_SPEEDSTYLE_TOOLTIP),
								choices = FyrMM.FontStyles,
								getFunc = function() return FyrMM.SV.SpeedFontStyle end,
								setFunc = function(value) if value ~= nil then FyrMM.SV.SpeedFontStyle = value MM_SetSpeedFont() end end,
								width = "half", default = "normal", disabled = function() return not FyrMM.SV.ShowSpeed end},
						[29] = { type = "dropdown", name = GetString(SI_MM_SETTING_SPEEDUNITS), tooltip = GetString(SI_MM_SETTING_SPEEDUNITS_TOOLTIP),
								choices = FyrMM.SpeedUnits,
								getFunc = function() return FyrMM.SV.SpeedUnit end,
								setFunc = function(value) if value ~= nil then FyrMM.SV.SpeedUnit = value end end,
								width = "half", default = "ft/s", disabled = function() return not FyrMM.SV.ShowSpeed end}, }, },
	[12] = { type = "submenu", name = GetString(SI_MM_SETTING_GROUPOPTIONS),
			controls = {
						[1] = {	type = "dropdown", name = GetString(SI_MM_SETTING_PLAYERSTYLE), tooltip = GetString(SI_MM_SETTING_PLAYERSTYLE_TOOLTIP),
								choices = {GetString(SI_MM_STRING_CLASSIC), GetString(SI_MM_STRING_PLAYERANDCAMERA)},
								getFunc = function() return FyrMM.SV.PPStyle end,
								setFunc = function(value) MM_SetPPStyle(value) end,
								width = "half", default = GetString(SI_MM_PLAYERANDCAMERA) },
						[2] = {	type = "dropdown", name = GetString(SI_MM_SETTING_PLAYERTEXTURE), tooltip = GetString(SI_MM_SETTING_PLAYERTEXTURE_TOOLTIP),
								choices = {"ESO UI Worldmap", "MiniMap", "Vixion Regular", "Vixion Gold"},
								getFunc = function() return FyrMM.SV.PPTextures end,
								setFunc = function(value) MM_SetPPTextures(value) end,
								width = "half", default = "ESO UI Worldmap" },
						[3] = { type = "checkbox", name = GetString(SI_MM_SETTING_COMBATSTATE), tooltip = GetString(SI_MM_SETTING_COMBATSTATE_TOOLTIP),
								getFunc = function() return FyrMM.SV.InCombatState end,
								setFunc = function(value) FyrMM.SV.InCombatState = value end,
								width = "half",	default = true,	},
						[4] = { type = "checkbox", name = GetString(SI_INTERFACE_OPTIONS_NAMEPLATES_TARGET_MARKERS), tooltip = GetString(SI_MM_TARGET_MARKERS_TOOLTIP),
								getFunc = function() return FyrMM.SV.GroupTargetMarkers end,
								setFunc = function(value) FyrMM.SV.GroupTargetMarkers = value end,
								width = "half",	default = false,	},	
						[5] = { type = "dropdown", name = GetString(SI_MM_SETTING_LEADER), tooltip = GetString(SI_MM_SETTING_LEADER_TOOLTIP),
								choices = {"Default", "Role", "Class"},
								getFunc = function() return FyrMM.SV.LeaderPin end,
								setFunc = function(value) MM_SetLeaderPin(value) end,
								width = "half", default = "Default", warning = GetString(SI_MM_SETTING_UIWARNING) },
						[6] = { type = "slider", name = GetString(SI_MM_SETTING_LEADERSIZE), tooltip = GetString(SI_MM_SETTING_LEADERSIZE_TOOLTIP),
								min = 8, max = 32, step = 1,
								getFunc = function() return FyrMM.SV.LeaderPinSize end,
								setFunc = function(value) MM_SetLeaderPinSize(value) end,
								width = "half",	default = 32, },
						[7] = { type = "colorpicker", name = GetString(SI_MM_SETTING_LEADERCOLOR), tooltip = GetString(SI_MM_SETTING_LEADERCOLOR_TOOLTIP),
								getFunc = function() return FyrMM.SV.LeaderPinColor.r, FyrMM.SV.LeaderPinColor.g, FyrMM.SV.LeaderPinColor.b, FyrMM.SV.LeaderPinColor.a end,
								setFunc = function(r,g,b,a) MM_SetLeaderPinColor(r, g, b, a) end,
								width = "half", disabled = function() return FyrMM.SV.MemberRolesColor end,},
						[8] = { type = "colorpicker", name = GetString(SI_MM_SETTING_LEADERDEADCOLOR), tooltip = GetString(SI_MM_SETTING_LEADERDEADCOLOR_TOOLTIP),
								getFunc = function() return FyrMM.SV.LeaderDeadPinColor.r, FyrMM.SV.LeaderDeadPinColor.g, FyrMM.SV.LeaderDeadPinColor.b, FyrMM.SV.LeaderDeadPinColor.a end,
								setFunc = function(r,g,b,a) MM_SetLeaderDeadPinColor(r, g, b, a) end,
								width = "half", disabled = function() return FyrMM.SV.MemberRolesColor end,},
						[9] = { type = "dropdown", name = GetString(SI_MM_SETTING_MEMBER), tooltip = GetString(SI_MM_SETTING_MEMBER_TOOLTIP),
								choices = {"Default", "Role", "Class"},
								getFunc = function() return FyrMM.SV.MemberPin end,
								setFunc = function(value) MM_SetMemberPin(value) end,
								width = "half", default = "Default", warning = GetString(SI_MM_SETTING_UIWARNING) },
						[10] = { type = "slider", name = GetString(SI_MM_SETTING_MEMBERSIZE), tooltip = GetString(SI_MM_SETTING_MEMBERSIZE_TOOLTIP),
								min = 8, max = 32, step = 1,
								getFunc = function() return FyrMM.SV.MemberPinSize end,
								setFunc = function(value) MM_SetMemberPinSize(value) end,
								width = "half",	default = 32, },
						[11] = { type = "colorpicker", name = GetString(SI_MM_SETTING_MEMBERCOLOR), tooltip = GetString(SI_MM_SETTING_MEMBERCOLOR_TOOLTIP),
								getFunc = function() return FyrMM.SV.MemberPinColor.r, FyrMM.SV.MemberPinColor.g, FyrMM.SV.MemberPinColor.b, FyrMM.SV.MemberPinColor.a end,
								setFunc = function(r,g,b,a) MM_SetMemberPinColor(r, g, b, a) end,
								width = "half", disabled = function() return FyrMM.SV.MemberRolesColor end,},
						[12] = { type = "colorpicker", name = GetString(SI_MM_SETTING_MEMBERDEADCOLOR), tooltip = GetString(SI_MM_SETTING_MEMBERDEADCOLOR_TOOLTIP),
								getFunc = function() return FyrMM.SV.MemberDeadPinColor.r, FyrMM.SV.MemberDeadPinColor.g, FyrMM.SV.MemberDeadPinColor.b, FyrMM.SV.MemberDeadPinColor.a end,
								setFunc = function(r,g,b,a) MM_SetMemberDeadPinColor(r, g, b, a) end,
								width = "half", disabled = function() return FyrMM.SV.MemberRolesColor end,},
						[13] = { type = "checkbox", name = GetString(SI_MM_SETTING_MEMBERROLESCOLOR), tooltip = GetString(SI_MM_SETTING_MEMBERROLESCOLOR_TOOLTIP),
								getFunc = function() return FyrMM.SV.MemberRolesColor end,
								setFunc = function(value) FyrMM.SV.MemberRolesColor = value end,
								width = "full",	default = false,	},
						[14] = { type = "colorpicker", name = GetString(SI_MM_SETTING_DPSCOLOR), tooltip = GetString(SI_MM_SETTING_DPSCOLOR_TOOLTIP),
								getFunc = function() return FyrMM.SV.MemberRolesDpsColor.r, FyrMM.SV.MemberRolesDpsColor.g, FyrMM.SV.MemberRolesDpsColor.b, FyrMM.SV.MemberRolesDpsColor.a end,
								setFunc = function(r,g,b,a) MM_SetDpsPinColor(r, g, b, a) end,
								width = "half", disabled = function() return not FyrMM.SV.MemberRolesColor end,},
						[15] = { type = "colorpicker", name = GetString(SI_MM_SETTING_DPSDEADCOLOR), tooltip = GetString(SI_MM_SETTING_DPSDEADCOLOR_TOOLTIP),
								getFunc = function() return FyrMM.SV.MemberRolesDeadDpsColor.r, FyrMM.SV.MemberRolesDeadDpsColor.g, FyrMM.SV.MemberRolesDeadDpsColor.b, FyrMM.SV.MemberRolesDeadDpsColor.a end,
								setFunc = function(r,g,b,a) MM_SetDpsDeadPinColor(r, g, b, a) end,
								width = "half", disabled = function() return not FyrMM.SV.MemberRolesColor end,},	
						[16] = { type = "colorpicker", name = GetString(SI_MM_SETTING_HEALCOLOR), tooltip = GetString(SI_MM_SETTING_HEALCOLOR_TOOLTIP),
								getFunc = function() return FyrMM.SV.MemberRolesHealColor.r, FyrMM.SV.MemberRolesHealColor.g, FyrMM.SV.MemberRolesHealColor.b, FyrMM.SV.MemberRolesHealColor.a end,
								setFunc = function(r,g,b,a) MM_SetHealPinColor(r, g, b, a) end,
								width = "half", disabled = function() return not FyrMM.SV.MemberRolesColor end,},
						[17] = { type = "colorpicker", name = GetString(SI_MM_SETTING_HEALDEADCOLOR), tooltip = GetString(SI_MM_SETTING_HEALDEADCOLOR_TOOLTIP),
								getFunc = function() return FyrMM.SV.MemberRolesDeadHealColor.r, FyrMM.SV.MemberRolesDeadHealColor.g, FyrMM.SV.MemberRolesDeadHealColor.b, FyrMM.SV.MemberRolesDeadHealColor.a end,
								setFunc = function(r,g,b,a) MM_SetHealDeadPinColor(r, g, b, a) end,
								width = "half", disabled = function() return not FyrMM.SV.MemberRolesColor end,},
						[18] = { type = "colorpicker", name = GetString(SI_MM_SETTING_TANKCOLOR), tooltip = GetString(SI_MM_SETTING_TANKCOLOR_TOOLTIP),
								getFunc = function() return FyrMM.SV.MemberRolesTankColor.r, FyrMM.SV.MemberRolesTankColor.g, FyrMM.SV.MemberRolesTankColor.b, FyrMM.SV.MemberRolesTankColor.a end,
								setFunc = function(r,g,b,a) MM_SetTankPinColor(r, g, b, a) end,
								width = "half", disabled = function() return not FyrMM.SV.MemberRolesColor end,},
						[19] = { type = "colorpicker", name = GetString(SI_MM_SETTING_TANKDEADCOLOR), tooltip = GetString(SI_MM_SETTING_TANKDEADCOLOR_TOOLTIP),
								getFunc = function() return FyrMM.SV.MemberRolesDeadTankColor.r, FyrMM.SV.MemberRolesDeadTankColor.g, FyrMM.SV.MemberRolesDeadTankColor.b, FyrMM.SV.MemberRolesDeadTankColor.a end,
								setFunc = function(r,g,b,a) MM_SetTankDeadPinColor(r, g, b, a) end,
								width = "half", disabled = function() return not FyrMM.SV.MemberRolesColor end,},								
						[20] = { type = "checkbox", name = GetString(SI_MM_SETTING_SHOWGROUPLABELS), tooltip = GetString(SI_MM_SETTING_SHOWGROUPLABELS_TOOLTIP),
								getFunc = function() return FyrMM.SV.ShowGroupLabels end,
								setFunc = function(value) FyrMM.SV.ShowGroupLabels = value end,
								width = "full",	default = false,	},
						[21] = { type = "button", name = GetString(SI_MM_SETTING_RELOADUI), tooltip = GetString(SI_MM_SETTING_RELOADUI_TOOLTIP),
								func = function() ReloadUI("ingame") end, width = "full", }, }, },
	[13] = { type = "submenu", name = GetString(SI_MM_SETTING_BORDEROPTIONS),
			controls = {
						[1] = { type = "checkbox", name = GetString(SI_MM_SETTING_BORDERPINS), tooltip = GetString(SI_MM_SETTING_BORDERPINS_TOOLTIP),
							getFunc = function() return FyrMM.SV.BorderPins end,
							setFunc = function(value) MM_SetBorderPins(value) end,
							width = "full",	default = true,	},
						[2] = { type = "checkbox", name = GetString(SI_MM_SETTING_ASSISTED), tooltip = GetString(SI_MM_SETTING_ASSISTED_TOOLTIP),
							getFunc = function() return FyrMM.SV.BorderPinsOnlyAssisted end,
							setFunc = function(value) MM_SetBorderPinsOnlyAssisted(value) end,
							width = "half",	default = true,	disabled = function() return not FyrMM.SV.BorderPins end,},
						[3] = { type = "checkbox", name = GetString(SI_MM_SETTING_LEADERONLY), tooltip = GetString(SI_MM_SETTING_LEADERONLY_TOOLTIP),
							getFunc = function() return FyrMM.SV.BorderPinsOnlyLeader end,
							setFunc = function(value) MM_SetBorderPinsOnlyLeader(value) end,
							width = "half",	default = true,	disabled = function() return not FyrMM.SV.BorderPins end,},
						[4] = { type = "checkbox", name = GetString(SI_MM_SETTING_WAYPOINT), tooltip = GetString(SI_MM_SETTING_WAYPOINT_TOOLTIP),
							getFunc = function() return FyrMM.SV.BorderPinsWaypoint end,
							setFunc = function(value) MM_SetBorderPinsWaypoint(value) end,
							width = "half",	default = true,	disabled = function() return not FyrMM.SV.BorderPins end,},
						[5] = { type = "checkbox", name = GetString(SI_MM_SETTING_BANK), tooltip = GetString(SI_MM_SETTING_BANK_TOOLTIP),
							getFunc = function() return FyrMM.SV.BorderPinsBank end,
							setFunc = function(value) FyrMM.SV.BorderPinsBank = value end,
							width = "half",	default = true,	disabled = function() return not FyrMM.SV.BorderPins end,},
						[6] = { type = "checkbox", name = GetString(SI_MM_SETTING_STABLES), tooltip = GetString(SI_MM_SETTING_STABLES_TOOLTIP),
							getFunc = function() return FyrMM.SV.BorderPinsStables end,
							setFunc = function(value) FyrMM.SV.BorderPinsStables = value end,
							width = "half",	default = true,	disabled = function() return not FyrMM.SV.BorderPins end,},							
						[7] = { type = "checkbox", name = GetString(SI_MM_SETTING_WAYSHRINE), tooltip = GetString(SI_MM_SETTING_WAYSHRINE_TOOLTIP),
							getFunc = function() return FyrMM.SV.BorderWayshrine end,
							setFunc = function(value) FyrMM.SV.BorderWayshrine = value end,
							width = "half",	default = true,	disabled = function() return not FyrMM.SV.BorderPins end,},								
						[8] = { type = "checkbox", name = GetString(SI_MM_SETTING_TREASURE), tooltip = GetString(SI_MM_SETTING_TREASURE_TOOLTIP),
							getFunc = function() return FyrMM.SV.BorderTreasures end,
							setFunc = function(value) FyrMM.SV.BorderTreasures = value end,
							width = "half",	default = true,	disabled = function() return not FyrMM.SV.BorderPins end,},
						[9] = { type = "checkbox", name = GetString(SI_MM_SETTING_QUESTGIVERS), tooltip = GetString(SI_MM_SETTING_QUESTGIVERS_TOOLTIP),
							getFunc = function() return FyrMM.SV.BorderQuestGivers end,
							setFunc = function(value) FyrMM.SV.BorderQuestGivers = value end,
							width = "half",	default = true,	disabled = function() return not FyrMM.SV.BorderPins end,},
						[10] = { type = "checkbox", name = GetString(SI_MM_SETTING_CRAFTING), tooltip = GetString(SI_MM_SETTING_CRAFTING_TOOLTIP),
							getFunc = function() return FyrMM.SV.BorderCrafting end,
							setFunc = function(value) FyrMM.SV.BorderCrafting = value end,
							width = "half",	default = false, disabled = function() return not FyrMM.SV.BorderPins end,}, 							
						[11] = { type = "checkbox", name = GetString(SI_MM_SETTING_WORLDEVENTS), tooltip = GetString(SI_MM_SETTING_WORLDEVENTS_TOOLTIP),
							getFunc = function() return FyrMM.SV.WorldEvents end,
							setFunc = function(value) FyrMM.SV.WorldEvents = value end,
							width = "half",	default = false, disabled = function() return not FyrMM.SV.BorderPins end,},
						[12] = { type = "checkbox", name = GetString(SI_MM_SETTING_AVABG), tooltip = GetString(SI_MM_SETTING_AVABG_TOOLTIP),
							getFunc = function() return FyrMM.SV.borderAVABG end,
							setFunc = function(value) FyrMM.SV.borderAVABG = value end,
							width = "full",	default = false, disabled = function() return not FyrMM.SV.BorderPins end,},
						[13] = { type = "checkbox", name = GetString(SI_MM_SETTING_KEEP), tooltip = GetString(SI_MM_SETTING_KEEP_TOOLTIP),
							getFunc = function() return FyrMM.SV.BorderKeep end,
							setFunc = function(value) FyrMM.SV.BorderKeep = value end,
							width = "half",	default = true,	disabled = function() return not FyrMM.SV.BorderPins end,},
						[14] = { type = "checkbox", name = GetString(SI_MM_SETTING_SKYSHARD), tooltip = GetString(SI_MM_SETTING_SKYSHARD_TOOLTIP),
							getFunc = function() return FyrMM.SV.BorderSkyshard end,
							setFunc = function(value) FyrMM.SV.BorderSkyshard = value FyrMM.skyshardPins() end,
							width = "half",	default = true,	disabled = function() return (not FyrMM.SV.BorderPins) or SkyShards ~= nil or SimpleSkyshards ~= nil end,},
							}, },
	[14] = { type = "submenu", name = GetString(SI_MM_SETTING_PERFORMANCEOPTIONS),
			controls = {
						[1] = { type = "slider", name = GetString(SI_MM_SETTING_POSITIONREFRESH), tooltip = GetString(SI_MM_SETTING_POSITIONREFRESH_TOOLTIP),
								min = 10, max = 250, step = 1,
								getFunc = function() return MM_GetMapRefreshRate() end,
								setFunc = function(value) MM_SetMapRefreshRate(value) end,
								width = "half",	default = 10, },
						[2] = { type = "slider", name = GetString(SI_MM_SETTING_PINREFRESH), tooltip = GetString(SI_MM_SETTING_PINREFRESH_TOOLTIP),
								min = 100, max = 2000, step = 1,
								getFunc = function() return MM_GetPinRefreshRate() end,
								setFunc = function(value) MM_SetPinRefreshRate(value) end,
								width = "half",	default = 100, },
--						[3] = { type = "slider", name = GetString(SI_MM_SETTING_TEXTUREREFRESH), tooltip = GetString(SI_MM_SETTING_TEXTUREREFRESH_TOOLTIP),
--								min = 300, max = 5000, step = 1,
--								getFunc = function() return MM_GetViewRefreshRate() end,
--								setFunc = function(value) MM_SetViewRefreshRate(value) end,
--								width = "half",	default = 2500,	},
						-- [3] = { type = "slider", name = GetString(SI_MM_SETTING_ZONEREFRESH), tooltip = GetString(SI_MM_SETTING_ZONEREFRESH_TOOLTIP),
								-- min = 25, max = 600, step = 1,
								-- getFunc = function() return MM_GetZoneRefreshRate() end,
								-- setFunc = function(value) MM_SetZoneRefreshRate(value) end,
								-- width = "half",	default = 100, },
						-- [4] = { type = "slider", name = GetString(SI_MM_SETTING_AVAREFRESH), tooltip = GetString(SI_MM_SETTING_AVA_REFRESH_TOOLTIP),
								-- min = 900, max = 8000, step = 1,
								-- getFunc = function() return MM_GetKeepNetworkRefreshRate() end,
								-- setFunc = function(value) MM_SetKeepNetworkRefreshRate(value) end,
								-- width = "half",	default = 2000, },
--						[5] = { type = "slider", name = GetString(SI_MM_SETTING_SCROLLSTEPPING), tooltip = GetString(SI_MM_SETTING_SCROLLSTEPPING_TOOLTIP),
--								min = 0.1, max = 5, step = 0.1,
--								getFunc = function() return MM_GetMapStepping() end,
--								setFunc = function(value) MM_SetMapStepping(value) end,
--								width = "half",	default = 2, },
						[3] = { type = "slider", name = GetString(SI_MM_SETTING_CHUNKDELAY), tooltip = GetString(SI_MM_SETTING_CHUNKDELAY_TOOLTIP),
								min = 10, max = 150, step = 1,
								getFunc = function() return FyrMM.SV.ChunkDelay end,
								setFunc = function(value) FyrMM.SV.ChunkDelay = value end,
								width = "half",	default = 10, },
						[4] = { type = "slider", name = GetString(SI_MM_SETTING_CHUNKSIZE), tooltip = GetString(SI_MM_SETTING_CHUNKSIZE_TOOLTIP),
								min = 10, max = 200, step = 1,
								getFunc = function() return FyrMM.SV.ChunkSize end,
								setFunc = function(value) FyrMM.SV.ChunkSize = value end,
								width = "half",	default = 10, },
   						-- [5] = { type = "checkbox", name = GetString(SI_MM_SETTING_WORLDMAPREFRESH), tooltip = GetString(SI_MM_SETTING_WORLDMAPREFRESH_TOOLTIP),
								-- getFunc = function() return FyrMM.SV.WorldMapRefresh end,
								-- setFunc = function(value) FyrMM.SV.WorldMapRefresh = value end,
								-- width = "half",	default = true,	}, 
								}, },
	}
end

function MM_ResetToDefaults() -- Hardcoded reset
	MM_SetLockResizing(false)
	FyrMM.SV.HideZoneLabel = false
	FyrMM.SV.HideZoomLevel = false
	FyrMM.SV.ShowBorder = true
	--FyrMM.SV.ClampedToScreen = true
	local pos = {}
	pos.anchorTo = GetControl(pos.anchorTo)
	--Fyr_MM:SetAnchor(TOPLEFT, pos.anchorTo, TOPLEFT, 0, 0)
	FyrMM.SV.MapHeight = 280
	FyrMM.SV.MapWidth = 280
	MM_SetMapHeight(280)
	MM_SetMapWidth(280)
	Fyr_MM_Border:SetWidth(288)
	Fyr_MM_Border:SetHeight(288)
	FyrMM.SV.MapAlpha = 100
	FyrMM.SV.Heading = "CAMERA"
	FyrMM.SV.PinScale = 75
	FyrMM.SV.PinTooltips = true
	FyrMM.SV.ShowPosition = false
	FyrMM.SV.HidePvPPins = false
	FyrMM.SV.MouseWheel = true
	MM_SetMapRefreshRate(40)
	MM_SetPinRefreshRate(100)
	MM_SetViewRefreshRate(1200)
	FyrMM.SV.hideCompass = false
	MM_SetHideCompass(false)
	FyrMM.SV.ShowCompassInAvAZoneOnly = false
	MM_SetShowCompassInAvAZoneOnly(false)
	MM_SetMiniCompassOption(false)
	MM_SetMiniCompassLocation("Top")
	MM_SetNoBossBar(false)
	FyrMM.SV.ShowClock = false
	FyrMM.SV.InCombatState = true
	FyrMM.SV.FastTravelEnabled = false
	FyrMM.SV.LeaderPin = "Default"
	FyrMM.SV.LeaderPinSize = 32
	FyrMM.SV.MemberPin = "Default"
	FyrMM.SV.MemberPinSize = 32
	MM_SetLeaderPinColor(1, 1, 1, 1)
	MM_SetLeaderDeadPinColor(1, 1, 1, 1)
	MM_SetMemberPinColor(1, 1, 1, 1)
	MM_SetMemberDeadPinColor(1, 1, 1, 1)
	FyrMM.SV.MemberRolesColor = false
	MM_SetMemberRolesDpsColor(1, 1, 1, 1)
	MM_SetMemberRolesDeadDpsColor(1, 1, 1, 1)
	MM_SetMemberRolesHealColor(1, 1, 1, 1)
	MM_SetMemberRolesDeadHealColor(1, 1, 1, 1)
	MM_SetMemberRolesTankColor(1, 1, 1, 1)
	MM_SetMemberRolesDeadTankColor(1, 1, 1, 1)
	FyrMM.SV.ZoomTable = {}
	FyrMM.SV.MapStepping = 2
	FyrMM_ZOOM_INCREMENT_AMOUNT = 1
	FyrMM.SV.ZoomIncrement = 1
	FyrMM.SV.InCombatAutoHide = false
	FyrMM.SV.InHouseAutoHide = false
	FyrMM.SV.AfterCombatUnhideDelay = 5
	FyrMM.SV.UseOriginalAPI = true
	MM_SetShowUnexploredPins(true)
	MM_SetUndiscoveredPOIPinColor(.7,.7,.3,.6)
	MM_SetPositionColor(0.996078431372549, 0.92, 0.3137254901960784, 1)
	FyrMM.SV.RotateMap = false
	MM_SetWheelMap(false)
	FyrMM.SV.BorderPins = false
	FyrMM.SV.BorderPinsWaypoint = false
	MM_SetCoordinatesLocation("Top")
	FyrMM.SV.StartupInfo = false
	FyrMM.SV.noEyeFK = false
	FyrMM.SV.ZoneNameContents = "Classic (Map only)"
	FyrMM.SV.ForceAreaOnlyInCyro = false
end

function MM_LoadSavedVars()	
	if FyrMM.SV.position ~= nil then
		local pos = {}
		pos.anchorTo = GetControl(pos.anchorTo)
		--Fyr_MM:SetAnchor(FyrMM.SV.position.point, pos.anchorTo, FyrMM.SV.position.relativePoint, FyrMM.SV.position.offsetX, FyrMM.SV.position.offsetY)
		Fyr_MM_Bg:SetAnchorFill(Fyr_MM)
	end
	if FyrMM.SV.ZoneList ~= nil then FyrMM.SV.ZoneList = nil end
	if FyrMM.SV.MapHeight ~= nil then MM_SetMapHeight(FyrMM.SV.MapHeight) end
	if FyrMM.SV.MapWidth ~= nil then MM_SetMapWidth(FyrMM.SV.MapWidth) end
	if FyrMM.SV.MapAlpha ~= nil then MM_SetMapAlpha(FyrMM.SV.MapAlpha) end
	if FyrMM.SV.PinScale ~= nil then MM_SetPinScale(FyrMM.SV.PinScale) end
	if FyrMM.SV.ShowBorder ~= nil then MM_SetShowBorder(FyrMM.SV.ShowBorder) end
	if FyrMM.SV.Heading ~= nil then MM_SetHeading(FyrMM.SV.Heading) end
	if FyrMM.SV.MapHeading ~= nil then MM_SetMapHeading(FyrMM.SV.MapHeading) end
	--if FyrMM.SV.ClampedToScreen ~= nil then MM_SetClampedToScreen(FyrMM.SV.ClampedToScreen) end
	if FyrMM.SV.hideCompass ~= nil then MM_SetHideCompass(FyrMM.SV.hideCompass) end
	if FyrMM.SV.ShowCompassInAvAZoneOnly ~= nil then MM_SetShowCompassInAvAZoneOnly(FyrMM.SV.ShowCompassInAvAZoneOnly) end
	if FyrMM.SV.miniCompassOption ~= nil then MM_SetMiniCompassOption(FyrMM.SV.miniCompassOption) end
	if FyrMM.SV.miniCompassLocation ~= nil then MM_SetMiniCompassLocation(FyrMM.SV.miniCompassLocation) end
	if FyrMM.SV.miniCompassNoBossBar ~= nil then MM_SetNoBossBar(FyrMM.SV.miniCompassNoBossBar) end 
	if FyrMM.SV.ShowPosition ~= nil then MM_SetShowPosition(FyrMM.SV.ShowPosition) end
	if FyrMM.SV.PositionBackground ~= nil then MM_SetPositionBackground(FyrMM.SV.PositionBackground) end
	if FyrMM.SV.PositionColor ~= nil then MM_SetPositionColor(FyrMM.SV.PositionColor.r, FyrMM.SV.PositionColor.g, FyrMM.SV.PositionColor.b, FyrMM.SV.PositionColor.a) end
	if FyrMM.SV.SpeedColor ~= nil then MM_SetSpeedColor(FyrMM.SV.SpeedColor.r, FyrMM.SV.SpeedColor.g, FyrMM.SV.SpeedColor.b, FyrMM.SV.SpeedColor.a) end
	if FyrMM.SV.PinTooltips ~= nil then MM_SetPinTooltips(FyrMM.SV.PinTooltips) end
	if FyrMM.SV.FastTravelEnabled ~= nil then MM_SetFastTravelEnabled(FyrMM.SV.FastTravelEnabled) end
	if FyrMM.SV.HidePvPPins ~= nil then MM_SetHidePvPPins(FyrMM.SV.HidePvPPins) end
	if FyrMM.SV.MouseWheel ~= nil then MM_SetMouseWheel(FyrMM.SV.MouseWheel) end
	if FyrMM.SV.WheelTexture ~= nil then MM_SetWheelTexture(FyrMM.SV.WheelTexture) end
	if FyrMM.SV.MapRefreshRate ~= nil then MM_SetMapRefreshRate(FyrMM.SV.MapRefreshRate) end
	if FyrMM.SV.PinRefreshRate ~= nil then MM_SetPinRefreshRate(FyrMM.SV.PinRefreshRate) end
	if FyrMM.SV.ViewRefreshRate ~= nil then MM_SetViewRefreshRate(FyrMM.SV.ViewRefreshRate) end
	if FyrMM.SV.HideZoneLabel ~= nil then MM_SetHideZoneLabel(FyrMM.SV.HideZoneLabel) end
	if FyrMM.SV.ShowZoneBackground ~= nil then MM_SetShowZoneBackground(FyrMM.SV.ShowZoneBackground) end
	if FyrMM.SV.ZoneFrameLocationOption ~= nil then MM_SetZoneFrameLocationOption(FyrMM.SV.ZoneFrameLocationOption) end
	if FyrMM.SV.SpeedLocationOption ~= nil then MM_SetSpeedLocationOption(FyrMM.SV.SpeedLocationOption) end
	if FyrMM.SV.ZoneFrameAnchor ~= nil then MM_SetZoneFrameAnchor(FyrMM.SV.ZoneFrameAnchor) end
	if FyrMM.SV.SpeedAnchor ~= nil then MM_SetSpeedAnchor(FyrMM.SV.SpeedAnchor) end
	if FyrMM.SV.ZoneFontHeight ~= nil then MM_SetZoneFont() end
	if FyrMM.SV.ZoneFont ~= nil then MM_SetZoneFont() end
	if FyrMM.SV.ZoneFontStyle ~= nil then MM_SetZoneFont() end
	if FyrMM.SV.PositionFont ~= nil then MM_SetPositionFont() end
	if FyrMM.SV.PositionHeight ~= nil then MM_SetPositionFont() end
	if FyrMM.SV.PositionFontStyle ~= nil then MM_SetPositionFont() end
	if FyrMM.SV.SpeedFont ~= nil then MM_SetSpeedFont() end
	if FyrMM.SV.SpeedHeight ~= nil then MM_SetSpeedFont() end
	if FyrMM.SV.SpeedFontStyle ~= nil then MM_SetSpeedFont() end
	if FyrMM.SV.ZoneNameColor ~= nil then MM_SetZoneNameColor(FyrMM.SV.ZoneNameColor.r, FyrMM.SV.ZoneNameColor.g, FyrMM.SV.ZoneNameColor.b, FyrMM.SV.ZoneNameColor.a) end
	if FyrMM.SV.HideZoomLevel ~= nil then MM_SetHideZoomLevel(FyrMM.SV.HideZoomLevel) end
	if FyrMM.SV.ShowClock ~= nil then MM_SetShowClock(FyrMM.SV.ShowClock) end
	if FyrMM.SV.LeaderPin ~= nil then MM_SetLeaderPin(FyrMM.SV.LeaderPin) end
	if FyrMM.SV.LeaderPinSize ~= nil then MM_SetLeaderPinSize(FyrMM.SV.LeaderPinSize) end
	if FyrMM.SV.LeaderPinColor ~= nil then MM_SetLeaderPinColor(FyrMM.SV.LeaderPinColor.r, FyrMM.SV.LeaderPinColor.g, FyrMM.SV.LeaderPinColor.b, FyrMM.SV.LeaderPinColor.a) end
	if FyrMM.SV.LeaderDeadPinColor ~= nil then MM_SetLeaderDeadPinColor(FyrMM.SV.LeaderDeadPinColor.r, FyrMM.SV.LeaderDeadPinColor.g, FyrMM.SV.LeaderDeadPinColor.b, FyrMM.SV.LeaderDeadPinColor.a) end
	if FyrMM.SV.MemberPin ~= nil then MM_SetMemberPin(FyrMM.SV.MemberPin) end
	if FyrMM.SV.MemberPinSize ~= nil then MM_SetMemberPinSize(FyrMM.SV.MemberPinSize) end
	if FyrMM.SV.MemberPinColor ~= nil then MM_SetMemberPinColor(FyrMM.SV.MemberPinColor.r, FyrMM.SV.MemberPinColor.g, FyrMM.SV.MemberPinColor.b, FyrMM.SV.MemberPinColor.a) end
	if FyrMM.SV.MemberDeadPinColor ~= nil then MM_SetMemberDeadPinColor(FyrMM.SV.MemberDeadPinColor.r, FyrMM.SV.MemberDeadPinColor.g, FyrMM.SV.MemberDeadPinColor.b, FyrMM.SV.MemberDeadPinColor.a) end
	
	if FyrMM.SV.MemberRolesDpsColor ~= nil then MM_SetDpsPinColor(FyrMM.SV.MemberRolesDpsColor.r, FyrMM.SV.MemberRolesDpsColor.g, FyrMM.SV.MemberRolesDpsColor.b, FyrMM.SV.MemberRolesDpsColor.a) end
	if FyrMM.SV.MemberRolesDeadDpsColor ~= nil then MM_SetDpsDeadPinColor(FyrMM.SV.MemberRolesDeadDpsColor.r, FyrMM.SV.MemberRolesDeadDpsColor.g, FyrMM.SV.MemberRolesDeadDpsColor.b, FyrMM.SV.MemberRolesDeadDpsColor.a) end

	if FyrMM.SV.MemberRolesHealColor ~= nil then MM_SetHealPinColor(FyrMM.SV.MemberRolesHealColor.r, FyrMM.SV.MemberRolesHealColor.g, FyrMM.SV.MemberRolesHealColor.b, FyrMM.SV.MemberRolesHealColor.a) end
	if FyrMM.SV.MemberRolesDeadHealColor ~= nil then MM_SetHealDeadPinColor(FyrMM.SV.MemberRolesDeadHealColor.r, FyrMM.SV.MemberRolesDeadHealColor.g, FyrMM.SV.MemberRolesDeadHealColor.b, FyrMM.SV.MemberRolesDeadHealColor.a) end

	if FyrMM.SV.MemberRolesTankColor ~= nil then MM_SetTankPinColor(FyrMM.SV.MemberRolesTankColor.r, FyrMM.SV.MemberRolesTankColor.g, FyrMM.SV.MemberRolesTankColor.b, FyrMM.SV.MemberRolesTankColor.a) end
	if FyrMM.SV.MemberRolesDeadTankColor ~= nil then MM_SetTankDeadPinColor(FyrMM.SV.MemberRolesDeadTankColor.r, FyrMM.SV.MemberRolesDeadTankColor.g, FyrMM.SV.MemberRolesDeadTankColor.b, FyrMM.SV.MemberRolesDeadTankColor.a) end	
	
	
	
	if FyrMM.SV.MapStepping ~=nil then MM_SetMapStepping(FyrMM.SV.MapStepping) end
	if FyrMM.SV.ZoomIncrement ~=nil then FYRMM_ZOOM_INCREMENT_AMOUNT = tonumber(FyrMM.SV.ZoomIncrement) FyrMM.SV.ZoomIncrement = FYRMM_ZOOM_INCREMENT_AMOUNT end
	if FyrMM.SV.DefaultZoomLevel ~= nil then FYRMM_DEFAULT_ZOOM_LEVEL = tonumber(FyrMM.SV.DefaultZoomLevel) FyrMM.SV.DefaultZoomLevel = FYRMM_DEFAULT_ZOOM_LEVEL end
	if FyrMM.SV.InCombatAutoHide ~=nil then MM_SetInCombatAutoHide(FyrMM.SV.InCombatAutoHide) end
	if FyrMM.SV.InHouseAutoHide ~=nil then MM_SetInHouseAutoHide(FyrMM.SV.InHouseAutoHide) end	
	if FyrMM.SV.AfterCombatUnhideDelay ~=nil then MM_SetAfterCombatUnhideDelay(FyrMM.SV.AfterCombatUnhideDelay) end
	if FyrMM.SV.LockResizing ~=nil then MM_SetLockResizing(FyrMM.SV.LockResizing) end
	if FyrMM.SV.UseOriginalAPI ~= nil then MM_SetUseOriginalAPI(FyrMM.SV.UseOriginalAPI) end
	if FyrMM.SV.ShowUnexploredPins ~= nil then MM_SetShowUnexploredPins(FyrMM.SV.ShowUnexploredPins) end
	if FyrMM.SV.RotateMap ~= nil then MM_SetRotateMap(FyrMM.SV.RotateMap) end
	if FyrMM.SV.CardinalPoints ~= nil then MM_SetCardinalPoints(FyrMM.SV.CardinalPoints) end
	if FyrMM.SV.WheelMap ~= nil then MM_SetWheelMap(FyrMM.SV.WheelMap) end
	if FyrMM.SV.BorderPins ~= nil then MM_SetBorderPins(FyrMM.SV.BorderPins) end
	if FyrMM.SV.BorderPinsWaypoint ~= nil then MM_SetBorderPinsWaypoint(FyrMM.SV.BorderPinsWaypoint) end
	if FyrMM.SV.CoordinatesLocation ~= nil then MM_SetCoordinatesLocation(FyrMM.SV.CoordinatesLocation) end
	if FyrMM.SV.CoordinatesAnchor ~= nil then MM_SetCoordinatesAnchor(FyrMM.SV.CoordinatesAnchor) end
	if FyrMM.SV.PPStyle ~= nil then MM_SetPPStyle(FyrMM.SV.PPStyle) end
	if FyrMM.SV.PPTextures ~= nil then MM_SetPPTextures(FyrMM.SV.PPTextures) end
	if FyrMM.SV.MenuDisabled ~= nil then Fyr_MM_Menu:SetHidden(FyrMM.SV.MenuDisabled) end
	if FyrMM.SV.MenuTexture ~= nil then MM_SetMenuTexture(FyrMM.SV.MenuTexture) end
	if FyrMM.SV.ShowSpeed ~= nil then Fyr_MM_Speed:SetHidden(not FyrMM.SV.ShowSpeed) end
	if FyrMM.SV.MapSettings ~= nil then MM_Upgrade_MapList() end -- Upgrade from version earlier to v2.15
	if FyrMM.SV.DisableSubzones ~= nil then FyrMM.DisableSubzones = FyrMM.SV.DisableSubzones end
	if FyrMM.SV.UndiscoveredPOIPinColor ~= nil then MM_SetUndiscoveredPOIPinColor(FyrMM.SV.UndiscoveredPOIPinColor.r, FyrMM.SV.UndiscoveredPOIPinColor.g, FyrMM.SV.UndiscoveredPOIPinColor.b, FyrMM.SV.UndiscoveredPOIPinColor.a) end
	if FyrMM.SV.TimeFormat ~= nil then FyrMM.TimeFormat = FyrMM.SV.TimeFormat end
end

function MM_RefreshPanel()
 	 if FyrMM.AreFyrmmSettingsShowing then FyrMM.LAM:OpenToPanel(FyrMM.CPL) end -- If Settings are open, have to refresh them
   FyrMM.HideCheck()
end

function FyrMM_CommandHandler(text)
	if text == "help" or text == "hel" then
		d(GetString(SI_MM_STRING_COMMANDHELP1))
		d("/fyrmm help - "..GetString(SI_MM_STRING_COMMANDHELP3))
		d("/fyrmm hide - "..GetString(SI_MM_STRING_COMMANDHELP4))
		d("/fyrmm location - "..GetString(SI_MM_STRING_COMMANDHELP5))
		d("/fyrmm reset - "..GetString(SI_MM_STRING_COMMANDHELP6))
		d("/fyrmm unhide - "..GetString(SI_MM_STRING_COMMANDHELP7))
		d("/fyrmm version - "..GetString(SI_MM_STRING_COMMANDHELP8))
		d("/fyrmm debug - "..GetString(SI_MM_STRING_COMMANDHELP9))
		d("/fyrmmset - "..GetString(SI_MM_STRING_COMMANDHELP10))
	elseif text == "reset" or text == "res" then
		MM_ResetToDefaults()
		MM_RefreshPanel()
		FyrMM.Reload()
	elseif text == "hide" or text == "hid" then
		FyrMM.Visible = false
	elseif text == "show" or text == "unhide" or text == "sho" or text == "unh" then
		FyrMM.Visible = true
	elseif text == "version" or text == "info" or text == "ver" or text == "inf" then
		d("|ceeeeeeMiniMap by Fyrakin continued by |c3CB371@Masteroshi430|r |ceeeeee v"..FyrMM.Panel.version.."|r")
	elseif text == "loc" or text == "location" then
		local x, y, heading = GetMapPlayerPosition("player")
		d(string.format(GetString(SI_MM_STRING_COORDINATES).." x=%g, y=%g @ %s",("%05.04f"):format(zo_round(x*1000000)/10000),("%05.04f"):format(zo_round(y*1000000)/10000), Fyr_MM_Zone:GetText()))
	elseif text == "debug" or text == "deb" then
		if FyrMM.MovementSpeedMax == nil then FyrMM.MovementSpeedMax = 0 end
		d("Map: "..FyrMM.currentMap.filename.." Id:"..GetCurrentMapId()..", Stored size: "..string.format("%g",("%05.04f"):format(zo_round(FyrMM.currentMap.TrueMapSize*100)/100))..", suggested size: "..string.format("%g",("%05.04f"):format(zo_round(FyrMM.currentMap.TrueMapSize*100*(9/(FyrMM.MovementSpeedMax*100)))/100)))
	elseif text == "pos" then
		local id, wx, wy, wz = GetUnitWorldPosition("player")
		local di = 0
		if FyrMM.wxP then
			di = math.sqrt((FyrMM.wxP -wx)*(FyrMM.wxP -wx)+(FyrMM.wyP -wy)*(FyrMM.wyP -wy)+(FyrMM.wzP -wz)*(FyrMM.wzP -wz))
		end
		d(GetZoneNameById(id).." X = "..wx.." Y = "..wy.." Z = "..wz.." D = "..string.format("%g",("%05.04f"):format(zo_round(di*100)/100)))
		FyrMM.wxP = wx
		FyrMM.wyP = wy
		FyrMM.wzP = wz
		
	  else
		d("/fyrmm help - "..GetString(SI_MM_STRING_COMMANDHELP11))
	end
end

SLASH_COMMANDS["/fyrmm"] = FyrMM_CommandHandler