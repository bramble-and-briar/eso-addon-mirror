ICT.ui = {
	opened = false,
	mapid = 0,
	timetable = ZO_SimpleSceneFragment:New(ICTTimeTable),
	maptimers = ZO_SimpleSceneFragment:New(ICTMapTimers),
	
	districts = {
		[GetString(SI_ICTHENEXTBOSS_MEMORIALDISTRICT)] = ICTMemorialDistrictLabel,
		[GetString(SI_ICTHENEXTBOSS_ARENADISTRICT)] = ICTArenaDistrictLabel,
		[GetString(SI_ICTHENEXTBOSS_ARBORETUMDISTRICT)] = ICTArboretumDistrictLabel,
		[GetString(SI_ICTHENEXTBOSS_TEMPLEDISTRICT)] = ICTTempleDistrictLabel,
		[GetString(SI_ICTHENEXTBOSS_NOBLESDISTRICT)] = ICTNoblesDistrictLabel,
		[GetString(SI_ICTHENEXTBOSS_ELVENGARDENSDISTRICT)] = ICTElvenGardensDistrictLabel,
	}
}

function ICT.disableMapMouseWheelZoom()
	
	local function disableZoom(self, delta, force)
		if force ~= nil then return false end
		if ICT.running == true and ICT.savedVariables.maptimers == true and ICT.ui.mapid == 660 then
			ZO_WorldMapZoom_OnMouseWheel(-1000, _, true)
			return true
		end
	end
	
	ZO_PreHook('ZO_WorldMap_MouseWheel', disableZoom)
	ZO_PreHook('ZO_WorldMapZoom_OnMouseWheel', disableZoom)
	ZO_PreHook('ZO_WorldMapZoomMinus_OnClicked', disableZoom)
	ZO_PreHook('ZO_WorldMapZoomPlus_OnClicked', disableZoom)
end

function ICT.disableMapZoomSlider(boolean)
	ZO_WorldMapZoomSliderButton1:SetEnabled(not boolean)
	ZO_WorldMapZoomSliderButton2:SetEnabled(not boolean)
	ZO_WorldMapZoomSliderButton3:SetEnabled(not boolean)
	ZO_WorldMapZoomSliderButton4:SetEnabled(not boolean)
	ZO_WorldMapZoomSliderButton5:SetEnabled(not boolean)
	ZO_WorldMapZoomSliderButton6:SetEnabled(not boolean)
	ZO_WorldMapZoomSliderButton7:SetEnabled(not boolean)
	ZO_WorldMapZoomSliderButton8:SetEnabled(not boolean)
	ZO_WorldMapZoomSliderButton9:SetEnabled(not boolean)
	ZO_WorldMapZoomSliderButton10:SetEnabled(not boolean)
	ZO_WorldMapZoomSliderButton11:SetEnabled(not boolean)
	ZO_WorldMapZoomMinus:SetEnabled(not boolean)
	ZO_WorldMapZoomPlus:SetEnabled(not boolean)
end

function ICT.onMapOpen()
	
	local function check()
		if ICT.running == true and ICT.ui.opened == true and ICT.savedVariables.maptimers == true and ICT.ui.mapid == 660 then
			ICTMapTimers:SetHidden(false)
			ICT.disableMapZoomSlider(true)
		else
			ICTMapTimers:SetHidden(true)
			ICT.disableMapZoomSlider(false)
		end
	end
	
	WORLD_MAP_SCENE:RegisterCallback("StateChange", function(oldState, newState)
	
		ICT.ui.mapid = GetCurrentMapId()
		
		if newState == SCENE_SHOWN or newState == SCENE_SHOWING then
			ICT.ui.opened = true
		else
			ICT.ui.opened = false
		end
		
		check()
	end)
	
	CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
		ICT.ui.mapid = GetCurrentMapId()
		check()
	end)
end

function ICT.setPanelMover(enabled)
    -- On PlayStation use the LAM X/Y sliders; mouse-drag is for mouse UI only.
    local canDrag = enabled == true and type(IsKeyboardUISupported) == "function" and IsKeyboardUISupported()
    ICTTimeTable:SetMouseEnabled(canDrag)
    ICTTimeTable:SetMovable(canDrag)
end

function ICT.configurePanelDimensions()
    -- Explicit native dimensions are required: scaling the container alone is not
    -- sufficient when the source labels use small keyboard UI fonts.
    ICTTimeTable:SetDimensions(870, 330)
    ICTFlagLabel:SetFont("ZoFontGamepad34")
    ICTFlagLabel:SetDimensions(170, 290)
    ICTDistricLabel:SetFont("ZoFontGamepad34")
    ICTTimerLabel:SetFont("ZoFontGamepad34")
    ICTDistricLabel:SetDimensions(480, 290)
    ICTTimerLabel:SetDimensions(155, 290)
end

function ICT.applyPanelScale()
    local value = tonumber(ICT.savedVariables.timetableScale) or 1.8
    value = math.max(0.5, math.min(4.0, value))
    ICT.configurePanelDimensions()
    ICTTimeTable:SetScale(value)
    ICT.restoreUIPosition()
end

function ICT.onTableMove()
	ICT.savedVariables.timetableTop = math.floor(ICTTimeTable:GetTop())
	ICT.savedVariables.timetableLeft = math.floor(ICTTimeTable:GetLeft())
end

function ICT.restoreUIPosition()
	ICTTimeTable:ClearAnchors()
	local scale = tonumber(ICT.savedVariables.timetableScale) or 1.8
    local maxX = math.max(0, GuiRoot:GetWidth() - ICTTimeTable:GetWidth() * scale)
    local maxY = math.max(0, GuiRoot:GetHeight() - ICTTimeTable:GetHeight() * scale)
    local x = math.min(math.max(0, tonumber(ICT.savedVariables.timetableLeft) or 0), maxX)
    local y = math.min(math.max(0, tonumber(ICT.savedVariables.timetableTop) or 0), maxY)
    ICTTimeTable:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

function ICT.secondsToClock(sec)
	return string.format("%02d:%02d", math.floor(sec / 60), (sec % 60))
end