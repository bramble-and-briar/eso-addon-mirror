-- The readout on the game screen. The window itself is in PBsPingAndBagSpaceIndicator.xml.
--
-- ---------------------------------------------------------------------------------------
-- WHEN IT IS ON SCREEN
-- ---------------------------------------------------------------------------------------
--
-- The window belongs to a scene fragment that sits in the HUD scenes (HUD_SCENE and HUD_UI_SCENE), the way PB's
-- other HUD add-ons put their windows there, so it is on the game screen and nowhere else: a menu, the map or a
-- loading screen hides it.
--
-- The numbers are read by a RegisterForUpdate that exists only while the readout is up (the game screen, or the
-- settings panel's preview) and switched on: nothing runs while it is hidden. The label's text is set only when
-- it changed.
--
-- ---------------------------------------------------------------------------------------
-- THE PREVIEW
-- ---------------------------------------------------------------------------------------
--
-- While the add-on's settings panel is open the readout is shown over the panel, at the place it will be, and it
-- follows the position, size and item options as they are changed (Settings.lua says when the panel is open).
-- The window is shown by hand then; the fragment owns it the rest of the time.

local A = PBS_PBSI
local em = EVENT_MANAGER

local WINDOW_NAME = "PBsPingAndBagSpaceIndicatorWindow"
local TICK_NAME = A.name .. "Tick"

local hud = {
	shown = false, -- the game screen is showing
	preview = false, -- the settings panel's preview is up
	ticking = false,
	lastText = nil, -- what the label shows
	ticks = 0, -- for /pbping status
	textSets = 0,
}
A.hud = hud

-- ---------------------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------------------

local function Controls()
	if hud.window then
		return hud.window
	end
	local window = _G[WINDOW_NAME]
	if not window then
		return nil
	end
	hud.window = window
	hud.text = window:GetNamedChild("Text")
	hud.back = window:GetNamedChild("Background")
	return window
end

local function AnyItem(sv)
	return sv.showPing or sv.showFps or sv.showBag or sv.showBank or sv.showGold or sv.showBankGold
end

-- Is the readout to be drawn now?
function A:HudVisible()
	local sv = self.sv
	return sv ~= nil and sv.enabled and (hud.shown or hud.preview) and AnyItem(sv) and true or false
end

local function ContentHidden(hidden)
	if not Controls() then
		return
	end
	hud.text:SetHidden(hidden)
	-- a background at 0 % is not drawn at all
	hud.back:SetHidden(hidden or A.sv.bgAlpha <= 0)
end

-- Font, place and background from the saved settings.
function A:ApplyLayout()
	if not Controls() then
		return
	end
	local sv = self.sv
	local size = self.SIZES[sv.size] or self.SIZES[2]
	local point = _G[self.ANCHORS[sv.anchor] or "BOTTOMRIGHT"]

	hud.text:SetFont(size.font)
	hud.text:ClearAnchors()
	hud.text:SetAnchor(point, GuiRoot, point, sv.posX, sv.posY)

	hud.back:ClearAnchors()
	hud.back:SetAnchor(TOPLEFT, hud.text, TOPLEFT, -size.padX, -size.padY)
	hud.back:SetAnchor(BOTTOMRIGHT, hud.text, BOTTOMRIGHT, size.padX, size.padY)
	hud.back:SetAlpha(sv.bgAlpha / 100)

	if self:HudVisible() then
		ContentHidden(false)
	end
end

-- Reads the game and puts the text up when it changed.
function A:Refresh()
	if not Controls() then
		return
	end
	local text = self:Compose(self.Read())
	if text ~= hud.lastText then
		hud.lastText = text
		hud.textSets = hud.textSets + 1
		hud.text:SetText(text)
	end
end

local function Tick()
	hud.ticks = hud.ticks + 1
	A:Refresh()
end
local SafeTick = A.Guard(Tick)

-- Shows or hides the content and starts or stops the reading, from the current state.
function A:HudUpdateState()
	local visible = self:HudVisible()
	if visible then
		self:Refresh()
		ContentHidden(false)
	else
		ContentHidden(true)
	end
	if visible and not hud.ticking then
		hud.ticking = true
		em:RegisterForUpdate(TICK_NAME, self.TICK_MS, SafeTick)
	elseif not visible and hud.ticking then
		hud.ticking = false
		em:UnregisterForUpdate(TICK_NAME)
	end
end

-- A setting changed: lay out, re-read and re-show at once instead of at the next tick.
function A:HudSettingsChanged()
	if not self.sv then
		return
	end
	hud.lastText = nil
	self:ApplyLayout()
	self:HudUpdateState()
end

function A:SetPreview(on)
	on = on and true or false
	if hud.preview == on then
		if on then
			self:HudSettingsChanged()
		end
		return
	end
	hud.preview = on
	local window = Controls()
	if not window then
		return
	end
	if on then
		window:SetHidden(false)
	else
		-- back to what the game screen is doing
		window:SetHidden(not hud.shown)
	end
	self:HudSettingsChanged()
end

-- ---------------------------------------------------------------------------------------
-- Start-up
-- ---------------------------------------------------------------------------------------

function A:InitHud()
	local window = Controls()
	if not window then
		error("the readout window is missing: PBsPingAndBagSpaceIndicator.xml did not load")
	end
	if not (ZO_SimpleSceneFragment and HUD_SCENE and HUD_UI_SCENE) then
		error("the game screen's scenes are not there")
	end
	self:ApplyLayout()
	ContentHidden(true)
	local fragment = ZO_SimpleSceneFragment:New(window)
	hud.fragment = fragment
	-- guarded: an error here would reach the game as an error screen every time a menu opens or closes
	fragment:RegisterCallback("StateChange", A.Guard(function(_, newState)
		if newState == SCENE_FRAGMENT_SHOWN then
			hud.shown = true
		elseif newState == SCENE_FRAGMENT_HIDING or newState == SCENE_FRAGMENT_HIDDEN then
			hud.shown = false
		end
		A:HudUpdateState()
	end))
	HUD_SCENE:AddFragment(fragment)
	HUD_UI_SCENE:AddFragment(fragment)
end

PBS_PBSI_MARK("Hud")
