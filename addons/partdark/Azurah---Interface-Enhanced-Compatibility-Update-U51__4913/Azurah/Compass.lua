local Azurah	= _G['Azurah'] -- grab addon table from global


local hasMoved = false

local function LoadSettings()
	local frame, userData
	frame = "ZO_CompassFrame"
	userData = (IsInGamepadPreferredMode()) and Azurah.db.uiData.gamepad or Azurah.db.uiData.keyboard
	local compassPoint				= 1
	local compassOffsetX			= 0
	local compassOffsetY			= 0
	local combatModification		= false
	local combatOpacity				= 1
	if userData[frame] then
		compassPoint				= (userData[frame].point) ~= nil and userData[frame].point or 1
		compassOffsetX				= (userData[frame].x) ~= nil and userData[frame].x or 0
		compassOffsetY				= (userData[frame].y) ~= nil and userData[frame].y or 0
		combatModification			= (userData[frame].altcombat) ~= nil and userData[frame].altcombat or false
		combatOpacity				= (userData[frame].copacity) ~= nil and userData[frame].copacity or 1
		hasMoved = true
	else
		hasMoved = false
	end
	return compassPoint, compassOffsetX, compassOffsetY, combatModification, combatOpacity
end

local function HandleCompass()
	local compassPoint, compassOffsetX, compassOffsetY, combatModification, combatOpacity = LoadSettings()
	local globalOpacityOn = Azurah.db.globalOpacityOn
	local db = Azurah.db.compass

	if (not db.compassEnabled) and (not globalOpacityOn) then
		ZO_Compass:SetAlpha( 0 )
		ZO_CompassFrameCenter:SetHidden( true )
		ZO_CompassFrameLeft:SetHidden( true )
		ZO_CompassFrameRight:SetHidden( true )
		ZO_CompassCenterOverPinLabel:SetHidden( true )
	else
		if db.compassHideBackground then
			ZO_CompassFrameCenter:SetHidden( true )
			ZO_CompassFrameLeft:SetHidden( true )
			ZO_CompassFrameRight:SetHidden( true )
		else
			ZO_CompassFrameCenter:SetHidden( false )
			ZO_CompassFrameLeft:SetHidden( false )
			ZO_CompassFrameRight:SetHidden( false )
		end

		if (db.compassHidePinLabel) then
			ZO_CompassCenterOverPinLabel:SetHidden(true)
		else
			ZO_CompassCenterOverPinLabel:SetHidden(false)
		end

		if hasMoved then
			ZO_CompassFrame:ClearAnchors()
			ZO_CompassFrame:SetAnchor(compassPoint, GuiRoot, compassPoint, compassOffsetX, compassOffsetY)
		end
		ZO_CompassCenterOverPinLabel:ClearAnchors()
		ZO_CompassCenterOverPinLabel:SetAnchor(BOTTOM, ZO_Compass, TOP, 0, -5 - db.compassPinLabelY)

		ZO_CompassFrameLeft:SetDimensions(10,db.compassHeight)
		ZO_CompassFrameRight:SetDimensions(10,db.compassHeight)
		ZO_Compass:SetDimensionConstraints(db.compassWidth, db.compassHeight, db.compassWidth, db.compassHeight)
		ZO_CompassFrame:SetDimensionConstraints(db.compassWidth, db.compassHeight, db.compassWidth, db.compassHeight)
		ZO_CompassCenterOverPinLabel:SetScale( db.compassLabelScale )

		if (globalOpacityOn) then
			ZO_Compass:SetAlpha(1)
			ZO_CompassFrameCenter:SetAlpha(1)
			ZO_CompassFrameLeft:SetAlpha(1)
			ZO_CompassFrameRight:SetAlpha(1)
			ZO_CompassCenterOverPinLabel:SetAlpha(1)
		else
			if (IsUnitInCombat("player")) and (Azurah.db.combatOpacityOn) then
				if (combatModification) then
					ZO_Compass:SetAlpha( combatOpacity )
					ZO_CompassFrameCenter:SetAlpha( combatOpacity )
					ZO_CompassFrameLeft:SetAlpha( combatOpacity )
					ZO_CompassFrameRight:SetAlpha( combatOpacity )
					ZO_CompassCenterOverPinLabel:SetAlpha( combatOpacity )
				else
					ZO_Compass:SetAlpha( db.compassOpacity )
					ZO_CompassFrameCenter:SetAlpha( db.compassOpacity )
					ZO_CompassFrameLeft:SetAlpha( db.compassOpacity )
					ZO_CompassFrameRight:SetAlpha( db.compassOpacity )
					ZO_CompassCenterOverPinLabel:SetAlpha( db.compassOpacity )
				end
			else
				ZO_Compass:SetAlpha( db.compassOpacity )
				ZO_CompassFrameCenter:SetAlpha( db.compassOpacity )
				ZO_CompassFrameLeft:SetAlpha( db.compassOpacity )
				ZO_CompassFrameRight:SetAlpha( db.compassOpacity )
				ZO_CompassCenterOverPinLabel:SetAlpha( db.compassOpacity )
			end
		end
	end
end

local function CompassLoad()
	local lastRun = 0
	ZO_CompassFrame:SetHandler("OnUpdate", function(self, tRun)
		if (tRun - lastRun) >= 5 then
			lastRun = tRun
			HandleCompass()
		end
	end)
end

-- ---------------------------------
-- CONFIGURE COMPASS
-- ---------------------------------
function Azurah:InitializeCompass(update, reset)
	if reset then
		local frame, userData
		frame = "ZO_CompassFrame"
		userData = (IsInGamepadPreferredMode()) and Azurah.db.uiData.gamepad or Azurah.db.uiData.keyboard
		if userData[frame] then
			userData[frame] = nil
		end
		Azurah.db.compass = nil
		ReloadUI()
	else
		if not update then
			ZO_PostHook(COMPASS, 'OnUpdate', -- EXPERIMENTAL: prevent text label re-appearing with no target when compass is resized (Phinix)
			function()
				if COMPASS.container:GetNumCenterOveredPins() == 0 then
					COMPASS.centerOverPinLabel:SetText("")
				end
			end)
			EVENT_MANAGER:RegisterForEvent(self.name .. 'Compass', EVENT_ZONE_CHANGED,		CompassLoad)
			EVENT_MANAGER:RegisterForEvent(self.name .. 'Compass', EVENT_PLAYER_ACTIVATED,	HandleCompass)
			CompassLoad() -- initialize after setting change or reload
		end
	end
	HandleCompass()
end
