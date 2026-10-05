local Azurah		= _G['Azurah']				-- grab addon table from global
local Watcher		= _G['Azurah_BagWatcher']	-- grab bag watcher control
local WatcherScene	= ZO_HUDFadeSceneFragment:New(Watcher, 0, 0)
local LMP			= LibMediaProvider

-- UPVALUES --
local BAG_BACKPACK			= BAG_BACKPACK
local SmoothTransition		= ZO_StatusBar_SmoothTransition
local GetNumBagUsedSlots	= GetNumBagUsedSlots
local GetBagSize			= GetBagSize

local VISIBLE_TIME_HOLD		= 2500
local VISIBLE_TIME_FADE_OUT	= 400

local firstLoad				= true
local bagMax				= 0
local bagCurrent, bagNew	= 0, 0
local FormatOverlay
local db


local function ShowWatcher()
	Watcher:SetAlpha(1) -- make sure watcher is fully visible

	if (db.lowSpaceLock and (bagMax - bagCurrent) <= db.lowSpaceTrigger) then -- low space triggered, we should stay visible
		if (Watcher.fader:IsPlaying()) then
			Watcher.fader:Stop() -- stop fader anim if playing
		end
	else -- not in low space or not locking on low space, start (or restart) fader
		Watcher.fader:PlayFromStart()
	end
end


-- ------------------------
-- EVENT HANDLERS
-- ------------------------
local function OnBagSizeChanged(code, prevSize, currentSize)
	if (prevSize == currentSize) then return end -- just make sure they aren't the same

	bagMax		= currentSize -- set new backpack size
	bagCurrent	= GetNumBagUsedSlots(BAG_BACKPACK)

	Watcher.bar:SetMinMax(0, bagMax)
	Watcher.bar.gloss:SetMinMax(0, bagMax)

	ShowWatcher()

	SmoothTransition(Watcher.bar, bagCurrent, bagMax, false, false, 0.05)
	Watcher.overlay:SetText(FormatOverlay(bagCurrent, nil, bagMax))
end

local function OnBagUpdate(code, bagID)
	if (bagID ~= BAG_BACKPACK) then return end -- we only care about the backpack

	bagNew = GetNumBagUsedSlots(BAG_BACKPACK)

	if (bagNew == bagCurrent) then return end -- available slots didn't actually change

	bagCurrent = bagNew -- available slots have changed, proceed

	Watcher.bar:SetValue(bagNew-1)
	SmoothTransition(Watcher.bar, bagCurrent, bagMax, false, false, 0.05)
	Watcher.overlay:SetText(FormatOverlay(bagCurrent, nil, bagMax))
	ShowWatcher()
end

local function SceneOnShown()
	if (Watcher.fader:IsPlaying()) then
		Watcher.fader:Stop() -- stop fader anim if playing
	end

	if (db.lowSpaceLock and (bagMax - bagCurrent) <= db.lowSpaceTrigger) then -- low space triggered, we should stay visible
		Watcher:SetAlpha(1) -- make sure we're fully visible
	else -- shouldnt' be visible right now
		Watcher:SetAlpha(0)
	end

end


-- ------------------------
-- CONSTRUCTION
-- ------------------------
local function AddControl(parent, cType, level)
	local c = WINDOW_MANAGER:CreateControl(nil, parent, cType)
	c:SetDrawLayer(DL_CONTROLS)
	c:SetDrawLevel(level)
	return c, c
end

local function BuildWatcher()
	local ctrl
	-- ICON
	Watcher.icon, ctrl = AddControl(Watcher, CT_TEXTURE, 3)
	ctrl:SetDimensions(56, 56)
	ctrl:SetTexture([[/esoui/art/mainmenu/menuBar_inventory_up.dds]])
	ctrl:SetTextureCoords(0.0625, 0.9375, 0.0625, 0.9375)
	-- BAR
	Watcher.bar, ctrl = AddControl(Watcher, CT_STATUSBAR, 2)
	ZO_StatusBar_SetGradientColor(ctrl, ZO_XP_BAR_GRADIENT_COLORS)
	ctrl:EnableLeadingEdge(true)
	ctrl:SetHandler('OnValueChanged', function(bar, value) bar.gloss:SetValue(value) end) -- change gloss value as main bar changes
	-- BAR GLOSS
	Watcher.bar.gloss, ctrl = AddControl(Watcher.bar, CT_STATUSBAR, 3)
	ctrl:SetAnchor(TOPLEFT)
	ctrl:EnableLeadingEdge(true)
	-- BAR FRAME
	Watcher.bar.borderL, ctrl = AddControl(Watcher.bar, CT_TEXTURE, 4)
	Watcher.bar.borderR, ctrl = AddControl(Watcher.bar, CT_TEXTURE, 4)
	Watcher.bar.borderM, ctrl = AddControl(Watcher.bar, CT_TEXTURE, 4)
	-- BAR BACKDROP
	Watcher.bar.backdropEnd, ctrl = AddControl(Watcher.bar, CT_TEXTURE, 1)
	Watcher.bar.backdrop, ctrl = AddControl(Watcher.bar, CT_TEXTURE, 1)
	-- OVERLAY
	Watcher.overlay = Azurah:CreateOverlay(Watcher, CENTER, CENTER, 0, 0, nil, nil, nil, TEXT_ALIGN_LEFT) -- will be reanchored later by configure
	-- ANIMATION TIMELINE
	ctrl = ANIMATION_MANAGER:CreateTimeline()
	ctrl:SetPlaybackType(ANIMATION_PLAYBACK_ONE_SHOT)
	Watcher.fader = ctrl
	ctrl = Watcher.fader:InsertAnimation(ANIMATION_ALPHA, Watcher, VISIBLE_TIME_HOLD)
	ctrl:SetDuration(VISIBLE_TIME_FADE_OUT)
	ctrl:SetEasingFunction(ZO_LinearEase)
	ctrl:SetAlphaValues(1, 0)

	HUD_SCENE:AddFragment(WatcherScene)
	HUD_UI_SCENE:AddFragment(WatcherScene)
	LOOT_SCENE:AddFragment(WatcherScene)

	WatcherScene:SetConditional(function() return Azurah.db.bagWatcher.enabled end)
	WatcherScene.OnShown = SceneOnShown
end


-- ------------------------
-- CONFIGURATION
-- ------------------------
function Azurah:ConfigureBagWatcherKeyboard()
	Watcher:SetDimensions(375, 56)

	if (not Watcher.bar) then return end -- bar isn't built yet (is disabled), abort

	Watcher.icon:ClearAnchors()
	Watcher.overlay:SetHidden(false)
	Watcher.overlay:ClearAnchors()
	Watcher.bar:ClearAnchors()
	Watcher.bar.borderL:ClearAnchors()
	Watcher.bar.borderR:ClearAnchors()
	Watcher.bar.borderM:ClearAnchors()
	Watcher.bar.backdropEnd:ClearAnchors()
	Watcher.bar.backdrop:ClearAnchors()

	Watcher.bar:SetDimensions(315, 20)
	Watcher.bar:SetTexture([[/esoui/art/miscellaneous/progressbar_genericfill.dds]])
	Watcher.bar:SetTextureCoords(0, 1, 0, 0.625)
	Watcher.bar:SetLeadingEdge([[/esoui/art/miscellaneous/progressbar_genericfill_leadingedge.dds]], 10, 20)
	Watcher.bar:SetLeadingEdgeTextureCoords(0, 1, 0, 0.625)

	Watcher.bar.gloss:SetDimensions(315, 20)
	Watcher.bar.gloss:SetTexture([[/esoui/art/miscellaneous/progressbar_genericfill_gloss.dds]])
	Watcher.bar.gloss:SetTextureCoords(0, 1, 0, 0.625)
	Watcher.bar.gloss:SetLeadingEdge([[/esoui/art/miscellaneous/progressbar_genericfill_leadingedge_gloss.dds]], 10, 20)
	Watcher.bar.gloss:SetLeadingEdgeTextureCoords(0, 1, 0, 0.625)

	Watcher.bar.borderL:SetDimensions(10, 20)
	Watcher.bar.borderL:SetAnchor(TOPLEFT)
	Watcher.bar.borderL:SetTexture([[/esoui/art/miscellaneous/progressbar_frame.dds]])

	Watcher.bar.borderR:SetDimensions(10, 20)
	Watcher.bar.borderR:SetAnchor(TOPRIGHT)
	Watcher.bar.borderR:SetTexture([[/esoui/art/miscellaneous/progressbar_frame.dds]])

	Watcher.bar.borderM:SetDimensions(295, 20)
	Watcher.bar.borderM:SetAnchor(TOPLEFT, Watcher.bar, TOPLEFT, 10, 0)
	Watcher.bar.borderM:SetTexture([[/esoui/art/miscellaneous/progressbar_frame.dds]])
	Watcher.bar.borderM:SetTextureCoords(0.019500000402331, 0.58980000019073, 0, 0.625)

	Watcher.bar.backdropEnd:SetDimensions(10, 20)
	Watcher.bar.backdropEnd:SetTexture([[/esoui/art/miscellaneous/progressbar_frame_bg.dds]])

	Watcher.bar.backdrop:SetDimensions(305, 20)
	Watcher.bar.backdrop:SetTexture([[/esoui/art/miscellaneous/progressbar_frame_bg.dds]])
	Watcher.bar.backdrop:SetTextureCoords(0.019500000402331, 0.58980000019073, 0, 0.625)

	if (db.reverseAlignment) then
		Watcher.icon:SetAnchor(TOPRIGHT, Watcher, TOPRIGHT, 10, 7)
		Watcher.overlay:SetAnchor(BOTTOMRIGHT, Watcher.bar, TOPRIGHT, -4, -2)
		Watcher.bar:SetAnchor(BOTTOMRIGHT, Watcher.icon, BOTTOMLEFT, 7, -8)
		Watcher.bar:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
		Watcher.bar.gloss:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
		Watcher.bar.borderL:SetTextureCoords(0.6133000254631, 0.59380000829697, 0, 0.625)
		Watcher.bar.borderR:SetTextureCoords(0.019500000402331, 0, 0, 0.625)
		Watcher.bar.backdropEnd:SetAnchor(TOPLEFT, Watcher.bar, TOPLEFT, 0, 0)
		Watcher.bar.backdropEnd:SetTextureCoords(0.6133000254631, 0.59380000829697, 0, 0.625)
		Watcher.bar.backdrop:SetAnchor(TOPRIGHT, Watcher.bar, TOPRIGHT, 0, 0)
	else
		Watcher.icon:SetAnchor(TOPLEFT, Watcher, TOPLEFT, -10, 7)
		Watcher.overlay:SetAnchor(BOTTOMLEFT, Watcher.bar, TOPLEFT, 4, -2)
		Watcher.bar:SetAnchor(BOTTOMLEFT, Watcher.icon, BOTTOMRIGHT, -7, -8)
		Watcher.bar:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
		Watcher.bar.gloss:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
		Watcher.bar.borderL:SetTextureCoords(0, 0.019500000402331, 0, 0.625)
		Watcher.bar.borderR:SetTextureCoords(0.59380000829697, 0.6133000254631, 0, 0.625)
		Watcher.bar.backdropEnd:SetAnchor(TOPRIGHT, Watcher.bar, TOPRIGHT, 0, 0)
		Watcher.bar.backdropEnd:SetTextureCoords(0.59380000829697, 0.6133000254631, 0, 0.625)
		Watcher.bar.backdrop:SetAnchor(TOPLEFT, Watcher.bar, TOPLEFT, 0, 0)
	end
end

function Azurah:ConfigureBagWatcherGamepad()
	Watcher:SetDimensions(255, 56)

	if (not Watcher.bar) then return end -- bar isn't built yet (is disabled), abort

	Watcher.icon:ClearAnchors()
	Watcher.overlay:SetHidden(false) -- no overlay in gamepad mode
	Watcher.overlay:ClearAnchors()
	Watcher.bar:ClearAnchors()
	Watcher.bar.borderL:ClearAnchors()
	Watcher.bar.borderR:ClearAnchors()
	Watcher.bar.borderM:ClearAnchors()
	Watcher.bar.backdropEnd:ClearAnchors()
	Watcher.bar.backdrop:ClearAnchors()

	Watcher.bar:SetDimensions(205, 22)
	Watcher.bar:SetTexture([[/esoui/art/miscellaneous/gamepad/gp_dynamicbar_medium_fill.dds]])
	Watcher.bar:SetTextureCoords(0, 1, 0.15625, 0.84375)
	Watcher.bar:SetLeadingEdge([[/esoui/art/miscellaneous/gamepad/gp_dynamicbar_medium_leadingedge.dds]], 16, 32)
	Watcher.bar:SetLeadingEdgeTextureCoords(0, 0.5, 0.15625, 0.84375)

	Watcher.bar.gloss:SetDimensions(205, 22)
	Watcher.bar.gloss:SetTexture([[/esoui/art/miscellaneous/gamepad/gp_dynamicbar_medium_gloss.dds]])
	Watcher.bar.gloss:SetTextureCoords(0, 1, 0.15625, 0.84375)
	Watcher.bar.gloss:SetLeadingEdge([[/esoui/art/miscellaneous/gamepad/gp_dynamicbar_medium_leadingedge_gloss.dds]], 16, 32)
	Watcher.bar.gloss:SetLeadingEdgeTextureCoords(0, 0.5, 0.15625, 0.84375)

	Watcher.bar.borderL:SetDimensions(7, 22)
	Watcher.bar.borderL:SetTexture([[/esoui/art/miscellaneous/gamepad/gp_dynamicbar_medium_frame.dds]])

	Watcher.bar.borderR:SetDimensions(11, 22)
	Watcher.bar.borderR:SetTexture([[/esoui/art/miscellaneous/gamepad/gp_dynamicbar_medium_frame.dds]])

	Watcher.bar.borderM:SetDimensions(191, 22)
	Watcher.bar.borderM:SetTexture([[/esoui/art/miscellaneous/gamepad/gp_dynamicbar_medium_frame.dds]])
	Watcher.bar.borderM:SetTextureCoords(0.6875, 0.4375, 0.15625, 0.84375)

	Watcher.bar.backdropEnd:SetDimensions(11, 22)
	Watcher.bar.backdropEnd:SetTexture([[/esoui/art/miscellaneous/gamepad/gp_dynamicbar_medium_bg.dds]])

	Watcher.bar.backdrop:SetDimensions(198, 22)
	Watcher.bar.backdrop:SetTexture([[/esoui/art/miscellaneous/gamepad/gp_dynamicbar_medium_bg.dds]])
	Watcher.bar.backdrop:SetTextureCoords(0.6875, 0.4375, 0.15625, 0.84375)

	if (db.reverseAlignment) then
		Watcher.icon:SetAnchor(TOPRIGHT, Watcher, TOPRIGHT, 9, 7)
		Watcher.overlay:SetAnchor(BOTTOMRIGHT, Watcher.bar, TOPRIGHT, -4, 1)
		Watcher.bar:SetAnchor(BOTTOMRIGHT, Watcher.icon, BOTTOMLEFT, 7, -15)
		Watcher.bar:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
		Watcher.bar.gloss:SetBarAlignment(BAR_ALIGNMENT_REVERSE)

		Watcher.bar.borderL:SetAnchor(TOPRIGHT, Watcher.bar, TOPRIGHT, 2, 0)
		Watcher.bar.borderL:SetTextureCoords(0.71875, 0.9375, 0.15625, 0.84375)

		Watcher.bar.borderR:SetAnchor(TOPLEFT, Watcher.bar, TOPLEFT, -2, 0)
		Watcher.bar.borderR:SetTextureCoords(0.0625, 0.40625, 0.15625, 0.84375)

		Watcher.bar.borderM:SetAnchor(TOPRIGHT, Watcher.bar, TOPRIGHT, -5, 0)

		Watcher.bar.backdropEnd:SetAnchor(TOPLEFT, Watcher.bar, TOPLEFT, -2, 0)
		Watcher.bar.backdropEnd:SetTextureCoords(0.0625, 0.40625, 0.15625, 0.84375)

		Watcher.bar.backdrop:SetAnchor(TOPRIGHT, Watcher.bar, TOPRIGHT, 2, 0)
	else
		Watcher.icon:SetAnchor(TOPLEFT, Watcher, TOPLEFT, -9, 0)
		Watcher.overlay:SetAnchor(BOTTOMLEFT, Watcher.bar, TOPLEFT, 4, 1)
		Watcher.bar:SetAnchor(BOTTOMLEFT, Watcher.icon, BOTTOMRIGHT, -7, -15)
		Watcher.bar:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
		Watcher.bar.gloss:SetBarAlignment(BAR_ALIGNMENT_NORMAL)

		Watcher.bar.borderL:SetAnchor(TOPLEFT, Watcher.bar, TOPLEFT, -2, 0)
		Watcher.bar.borderL:SetTextureCoords(0.9375, 0.71875, 0.15625, 0.84375)

		Watcher.bar.borderR:SetAnchor(TOPRIGHT, Watcher.bar, TOPRIGHT, 2, 0)
		Watcher.bar.borderR:SetTextureCoords(0.40625, 0.0625, 0.15625, 0.84375)

		Watcher.bar.borderM:SetAnchor(TOPLEFT, Watcher.bar, TOPLEFT, 5, 0)

		Watcher.bar.backdropEnd:SetAnchor(TOPRIGHT, Watcher.bar, TOPRIGHT, 2, 0)
		Watcher.bar.backdropEnd:SetTextureCoords(0.40625, 0.0625, 0.15625, 0.84375)

		Watcher.bar.backdrop:SetAnchor(TOPLEFT, Watcher.bar, TOPLEFT, -2, 0)
	end
end

function Azurah:ConfigureBagWatcher(onLoad)
	if (not db.enabled) then -- not using bag watcher
		-- unregister watcher events
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'BagWatcher', EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'BagWatcher', EVENT_INVENTORY_BAG_CAPACITY_CHANGED)
	else -- using bag watcher
		if (not Watcher.bar) then -- need to build the watcher gui
			BuildWatcher()
		end

		-- configure bag watcher appearance
		Watcher.overlay:SetFont(string.format('%s|%d|%s', LMP:Fetch('font', db.fontFace), db.fontSize, db.fontOutline))
		Watcher.overlay:SetColor(db.fontColour.r, db.fontColour.g, db.fontColour.b, db.fontColour.a)


		if (IsInGamepadPreferredMode()) then
			self:ConfigureBagWatcherGamepad()
		else
			self:ConfigureBagWatcherKeyboard()
		end

		bagMax			= GetBagSize(BAG_BACKPACK)
		bagCurrent		= GetNumBagUsedSlots(BAG_BACKPACK)

		FormatOverlay	= self.overlayFuncs[db.overlay]

		Watcher.bar:SetMinMax(0, bagMax)
		Watcher.bar.gloss:SetMinMax(0, bagMax)

		EVENT_MANAGER:RegisterForEvent(self.name .. 'BagWatcher', EVENT_INVENTORY_SINGLE_SLOT_UPDATE,	OnBagUpdate)
		EVENT_MANAGER:RegisterForEvent(self.name .. 'BagWatcher', EVENT_INVENTORY_BAG_CAPACITY_CHANGED,	OnBagSizeChanged)

	-- First load fillup not working, needs investigation...
	--	if (firstLoad) then -- first load, fillup bar to current level nicely
	--		firstLoad = false

	--		Watcher.bar:SetValue(0)
	--		SmoothTransition(Watcher.bar, bagCurrent, bagMax, false, false, 0.05)
	--		ShowWatcher()
	--	else
			Watcher.bar:SetValue(bagCurrent)
	--	end

		Watcher.overlay:SetText(FormatOverlay(bagCurrent, nil, bagMax))
	end
end


-- ------------------------
-- INITIALIZATION
-- ------------------------
function Azurah:InitializeBagWatcher()
	db = self.db.bagWatcher		-- local db reference
	
	self:ConfigureBagWatcher()
end
