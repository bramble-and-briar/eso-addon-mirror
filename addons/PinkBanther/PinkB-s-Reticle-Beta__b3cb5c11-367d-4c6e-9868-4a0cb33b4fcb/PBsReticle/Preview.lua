-- The demo script, and the preview shown while the settings panel is open.
--
-- The settings panel is not a HUD scene, so the game's reticle (and ours, which hangs on it) is not drawn
-- there. A second reticle in a window of its own is, over a test card: dark on one side and light on the
-- other, with the reticle on the seam, so the outline's job can be judged at a glance. It plays the demo
-- script on a loop: at rest, over something usable, over a friend, locking an enemy, three hits, a crit,
-- a kill.
local A, S = PBS_RETICLE, PBS_RETICLE_STRINGS

local PATH = "PBsReticle/assets/"
local CARD_W, CARD_H, CAPTION_H = 380, 220, 40
-- Right of the middle, where the console panel leaves room (its list is on the left). Not measured on a PS5.
local CARD_X, CARD_Y = 470, -40

-- ---------------------------------------------------------------------------------------
-- The script. `kind` and `combat` set the state from then on; `hit` fires once; `cap` is the caption.
-- ---------------------------------------------------------------------------------------

local DEMO_LENGTH = 9.4
local DEMO = {
	{ at = 0.0, kind = "none", combat = false, cap = "capNone" },
	{ at = 1.4, kind = "interact", cap = "capInteract" },
	{ at = 2.8, kind = "friendly", cap = "capFriendly" },
	{ at = 4.2, kind = "hostile", combat = true, cap = "capHostile" },
	{ at = 5.1, hit = "hit", cap = "capHit" },
	{ at = 5.5, hit = "hit" },
	{ at = 6.0, hit = "crit", cap = "capCrit" },
	{ at = 6.9, hit = "kill", kind = "dead", cap = "capKill" },
	{ at = 8.2, kind = "none", combat = false, cap = "capNone" },
}
A.DEMO, A.DEMO_LENGTH = DEMO, DEMO_LENGTH

-- Did `at` fall between the last time the script was read and now (the script loops)?
local function crossed(last, now, at)
	if now >= last then
		return at > last and at <= now
	end
	return at > last or at <= now
end

-- A source for a reticle: returns what is under it, whether to draw it at full strength, and the caption.
-- Hits are fired at the reticle as the script passes them.
function A.MakeDemo()
	local started, last
	return function(reticle, t)
		started = started or t
		local ct = (t - started) % DEMO_LENGTH
		local kind, combat, cap = "none", false, "capNone"
		for _, entry in ipairs(DEMO) do
			if entry.at <= ct then
				kind = entry.kind or kind
				if entry.combat ~= nil then
					combat = entry.combat
				end
				cap = entry.cap or cap
			end
			if entry.hit and last and crossed(last, ct, entry.at) then
				reticle:Hit(entry.hit, t)
			end
		end
		last = ct
		return kind, combat or kind ~= "none", cap
	end
end

-- ---------------------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------------------

local function Solid(name, parent, level, r, g, b)
	local c = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
	c:SetTexture(PATH .. "solid.dds")
	c:SetDrawLayer(DL_OVERLAY)
	c:SetDrawLevel(level)
	c:SetColor(r, g, b, 1)
	c:SetMouseEnabled(false)
	return c
end

function A:CreatePreview()
	local win = WINDOW_MANAGER:CreateTopLevelWindow("PBsReticlePreview")
	win:SetHidden(true)
	win:SetMouseEnabled(false)
	win:SetMovable(false)
	win:SetDimensions(CARD_W, CARD_H + CAPTION_H)
	win:SetAnchor(CENTER, GuiRoot, CENTER, CARD_X, CARD_Y)
	-- Above the settings screen: this is not a HUD scene.
	win:SetDrawTier(DT_HIGH)
	win:SetDrawLayer(DL_OVERLAY)
	win:SetDrawLevel(100)
	self.previewWin = win

	local dark = Solid("PBsReticlePreviewDark", win, 0, 0.07, 0.08, 0.1)
	dark:SetDimensions(CARD_W / 2, CARD_H)
	dark:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
	local light = Solid("PBsReticlePreviewLight", win, 0, 0.82, 0.85, 0.88)
	light:SetDimensions(CARD_W / 2, CARD_H)
	light:SetAnchor(TOPRIGHT, win, TOPRIGHT, 0, 0)
	local plate = Solid("PBsReticlePreviewPlate", win, 0, 0.04, 0.04, 0.05)
	plate:SetDimensions(CARD_W, CAPTION_H)
	plate:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 0, 0)

	local caption = WINDOW_MANAGER:CreateControl("PBsReticlePreviewCaption", win, CT_LABEL)
	caption:SetFont("ZoFontGamepad27")
	caption:SetColor(1, 1, 1, 1)
	caption:SetDrawLayer(DL_TEXT)
	caption:SetMouseEnabled(false)
	caption:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	caption:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	caption:SetDimensions(CARD_W, CAPTION_H)
	caption:SetAnchor(BOTTOM, win, BOTTOM, 0, 0)
	self.previewCaption = caption

	-- on the seam, in the middle of the card
	local reticle = A.NewReticle("PBsReticlePrev", win, win, -CAPTION_H / 2, DL_OVERLAY, 10)
	local demo = A.MakeDemo()
	local shown
	reticle:SetSource(function(r, t)
		local kind, engaged, cap = demo(r, t)
		if cap ~= shown then
			shown = cap
			caption:SetText(S[cap] or cap)
		end
		return kind, engaged
	end)
	self.preview = reticle
end

-- ---------------------------------------------------------------------------------------
-- When it is shown
-- ---------------------------------------------------------------------------------------

function A:RefreshPreview()
	local win = self.previewWin
	if not win then
		return
	end
	local show = self.panelOpen and self.sv.preview and self.sv.enabled and self.active and true or false
	win:SetHidden(not show)
end

function A:SetPanelOpen(open)
	self.panelOpen = open and true or false
	self:RefreshPreview()
end

-- On console the library fires AddonSelected before it pushes its scene, and not at all when the same
-- panel is opened again; the scene's own state changes are what to follow (PB's ChatWindowCustomizer
-- measured this on a PS5, and PB's Compass does the same). The scene exists only after the first
-- selection, so it is looked up then.
function A:WatchSettingsScene()
	local library = LibHarvensAddonSettings
	local scene = library and library.scene
	if not scene and SCENE_MANAGER then
		scene = SCENE_MANAGER:GetScene("LibHarvensAddonSettingsScene")
	end
	-- The desktop library shows its panel inside the current settings scene.
	if not scene and SCENE_MANAGER then
		scene = SCENE_MANAGER:GetCurrentScene()
	end
	if not scene or scene == HUD_SCENE or scene == HUD_UI_SCENE then
		return nil
	end
	self.watchedScenes = self.watchedScenes or {}
	if not self.watchedScenes[scene] then
		self.watchedScenes[scene] = true
		scene:RegisterCallback("StateChange", function(_, state)
			if state == SCENE_SHOWN then
				self:SetPanelOpen(self.panel and self.panel.selected == true)
			elseif state == SCENE_HIDING or state == SCENE_HIDDEN then
				self:SetPanelOpen(false)
			end
		end)
	end
	return scene
end

function A:OnAddonSelected(panel)
	local scene = self:WatchSettingsScene()
	self:SetPanelOpen(panel == self.panel and (not scene or scene:IsShowing()))
end
