-- PBS_CONSOLE_HUD_CUSTOMIZER is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_CONSOLE_HUD_CUSTOMIZER then
	return
end

local addon = PBS_CONSOLE_HUD_CUSTOMIZER

-- ---------------------------------------------------------------------------------------
-- The preview frames
--
-- The attribute bars are only drawn on the HUD, so while the settings panel is open the real
-- ones cannot be seen, and every slider would otherwise mean backing out to the HUD to look.
-- This draws where the three will be instead: an outline the size the bar will be, in that
-- bar's own colour, with its name beside it.
--
-- Built entirely from controls of our own. Nothing of the game's is shown in the menu: calling
-- the attribute bars' own show or fade code from an add-on frame is exactly what leaves client
-- closures untrusted, and these are the controls that run combat code.
-- ---------------------------------------------------------------------------------------

local preview = {
	frames = {},
}
addon.preview = preview

local NAME = "PBsConsoleHudCustomizerPreview"
local EDGE = 2
local CHECK_INTERVAL_MS = 250

-- PB's pink, the same colour as the add-on's name. Used for the caption only; each frame is
-- drawn in the colour of the bar it stands for.
local PINK = { 1, 0.41, 0.71 }

-- A named font the gamepad UI already has built, so the preview builds none of its own.
local CAPTION_FONT = "ZoFontGamepad22"

local function Texture(parent, suffix, r, g, b, a)
	local texture = WINDOW_MANAGER:CreateControl(NAME .. suffix, parent, CT_TEXTURE)
	texture:SetColor(r, g, b, a)
	return texture
end

local function Label(parent, suffix, font)
	local label = WINDOW_MANAGER:CreateControl(NAME .. suffix, parent, CT_LABEL)
	label:SetFont(font)
	return label
end

-- One outline, four one-pixel edges around a dimmed middle, the way the bar will look.
function preview:Frame(bar, index)
	local frame = self.frames[bar.key]
	if frame then
		return frame
	end

	local top = WINDOW_MANAGER:CreateControl(NAME .. "Frame" .. index, self.control, CT_CONTROL)
	local colour = bar.colour

	local fill = Texture(top, "Fill" .. index, colour[1], colour[2], colour[3], 0.35)
	fill:SetAnchorFill(top)

	local edges = {
		{ "Top", TOPLEFT, TOPRIGHT, "height" },
		{ "Bottom", BOTTOMLEFT, BOTTOMRIGHT, "height" },
		{ "Left", TOPLEFT, BOTTOMLEFT, "width" },
		{ "Right", TOPRIGHT, BOTTOMRIGHT, "width" },
	}
	for _, edge in ipairs(edges) do
		local texture = Texture(top, "Edge" .. edge[1] .. index, colour[1], colour[2], colour[3], 1)
		texture:SetAnchor(edge[2], top, edge[2], 0, 0)
		texture:SetAnchor(edge[3], top, edge[3], 0, 0)
		if edge[4] == "height" then
			texture:SetHeight(EDGE)
		else
			texture:SetWidth(EDGE)
		end
	end

	local label = Label(top, "Label" .. index, CAPTION_FONT)
	label:SetColor(1, 1, 1, 1)
	label:SetText(GetString(_G[bar.stringId]))
	label:SetAnchor(CENTER, top, CENTER, 0, 0)

	frame = { control = top, label = label }
	self.frames[bar.key] = frame
	return frame
end

function preview:Create()
	if self.control then
		return self.control
	end
	if not WINDOW_MANAGER or not GuiRoot then
		return nil
	end

	local top = WINDOW_MANAGER:CreateTopLevelWindow(NAME)
	top:SetHidden(true)
	top:SetMouseEnabled(false)
	-- Above the settings panel, which is what it is drawn over.
	top:SetDrawLayer(DL_OVERLAY)
	top:SetDrawTier(DT_HIGH)
	top:SetAnchorFill(GuiRoot)
	self.control = top

	local caption = Label(top, "Caption", CAPTION_FONT)
	caption:SetColor(PINK[1], PINK[2], PINK[3], 1)
	caption:SetText(GetString(SI_PBSCHC_PREVIEW_CAPTION))
	self.caption = caption

	for index, bar in ipairs(addon.elements) do
		self:Frame(bar, index)
	end
	-- The other weapon set's row, drawn only as an outline: it is not placed on its own, it
	-- follows the skill bar.
	self.backFrame = self:Frame({
		key = "backbar",
		colour = { 1, 0.41, 0.71 },
		stringId = "SI_PBSCHC_SECTION_BACKBAR",
	}, #addon.elements + 1)

	-- Checked a few times a second while shown: the preview goes away by itself once the panel
	-- it belongs to is no longer on screen, whichever way the player left it.
	local nextCheck = 0
	top:SetHandler("OnUpdate", function()
		local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
		if now < nextCheck then
			return
		end
		nextCheck = now + CHECK_INTERVAL_MS
		if not preview:StillWanted() then
			preview:Hide()
		end
	end)

	return top
end

function preview:IsShown()
	return self.control ~= nil and not self.control:IsHidden()
end

-- Redraws the frames for the current settings. Cheap, and a no-op while hidden.
function preview:Update()
	if not self:IsShown() then
		return
	end

	local rootWidth, rootHeight = addon:RootSize()
	local highest = rootHeight

	for index, bar in ipairs(addon.elements) do
		local frame = self:Frame(bar, index)
		local control = frame.control
		-- A skill bar this add-on has been told to leave alone is not drawn here either: the
		-- outline would promise something the panel no longer does.
		local drawn = not (bar.isActionBar and not addon:SkillBarAllowed())
		control:SetHidden(not drawn)
		if drawn then
			local position = addon:EffectivePosition(bar)
			local scale = addon:EffectiveScalePercent(bar) / 100
			control:ClearAnchors()
			control:SetAnchor(CENTER, self.control, BOTTOM, position.x, -position.y)
			control:SetDimensions(addon.GAME.barWidth * scale, addon.GAME.barHeight * scale)
			-- The name is drawn at the same scale as the bar, so a bar shrunk to half size looks
			-- half size here too rather than being filled by its own label.
			frame.label:SetScale(scale)

			local top = rootHeight - position.y - (addon.GAME.barHeight * scale) / 2
			if top < highest then
				highest = top
			end
		end
	end

	-- The other weapon set's row, above the skill bar and scaled with it.
	--
	-- The row is six slots standing over the six buttons, not a band the width of the whole bar:
	-- the bar's control is 606 wide and the buttons occupy rather less of it, with an invisible
	-- weapon swap marker taking up the left-hand end (see FINDINGS, "The gaps along the bar").
	-- Drawn at the bar's full width, as it was, the outline promised a row half again as wide as
	-- the one that appears.
	--
	-- Where the buttons sit inside the bar is measured off the real controls as a fraction of the
	-- bar's width, so it holds whatever the gaps are set to, and the fraction is free of scale --
	-- both numbers are scaled the same, and it cancels.
	if self.backFrame then
		local control = self.backFrame.control
		local shown = addon.BackBarEnabled and addon:BackBarEnabled()
		if shown then
			local skillbar = addon.barByKey.skillbar
			local left, top, width = addon:RectOf(skillbar)
			local barScale = addon:EffectiveScalePercent(skillbar) / 100
			local scale = barScale * addon:BackBarScale() / 100
			local gap = addon:BackBar().gap
			gap = (type(gap) == "number" and gap or 4) * barScale

			local rowLeft, rowWidth = left, width
			local from, to = addon:ButtonSpan()
			if from and to then
				rowLeft = left + from * width
				rowWidth = (to - from) * width
			end

			-- The slot is 52 wide and 68 tall, so a row of six covers a little more than the
			-- buttons do; the outline is the slots' own height.
			local height = 68 * scale
			control:ClearAnchors()
			control:SetAnchor(BOTTOMLEFT, self.control, TOPLEFT, rowLeft, top - gap)
			control:SetDimensions(rowWidth, height)
			control:SetHidden(false)
			self.backFrame.label:SetScale(scale)
			if top - gap - height < highest then
				highest = top - gap - height
			end
		else
			control:SetHidden(true)
		end
	end

	-- The caption sits above the highest of the four, or below it when there is no room.
	self.caption:ClearAnchors()
	if highest < 40 then
		self.caption:SetAnchor(TOP, self.control, TOP, 0, highest + 40)
	else
		self.caption:SetAnchor(BOTTOM, self.control, TOP, 0, highest - 8)
	end
end

function preview:Show()
	if not self:Create() then
		return false
	end
	self.scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene() or nil
	self.control:SetHidden(false)
	self:Update()
	return true
end

function preview:Hide()
	if self.control then
		self.control:SetHidden(true)
	end
	self.forced = false
	self.forPanel = false
end

-- Whether whatever asked for the preview is still on screen: the scene it was shown in, and for
-- the settings panel, the panel itself. LibHarvensAddonSettings marks the selected add-on's
-- panel with .selected; a copy of the library that does not is judged by the scene alone.
function preview:StillWanted()
	if not (self.forced or self.forPanel) then
		return false
	end
	local current = SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene() or nil
	if current ~= self.scene then
		return false
	end
	if self.forPanel and not self.forced then
		if not addon:Account().preview then
			return false
		end
		local panel = addon.settingsPanel
		if panel and panel.selected == false then
			return false
		end
	end
	return true
end

-- ---------------------------------------------------------------------------------------
-- Following the settings panel
--
-- On console the library opens a panel in two steps (LibHarvensAddonSettings, Console/
-- Settings.lua, the add-on list's activatedCallback):
--
--   addon:Select()                                      fires AddonSelected, then sets .selected
--   SCENE_MANAGER:Push("LibHarvensAddonSettingsScene")  and only then shows the panel
--
-- So AddonSelected arrives while the add-on list is still the current scene. A preview shown
-- there notes the wrong scene and hides itself the moment the panel comes up. And Select()
-- returns early for the add-on already selected, so a second visit to the same panel fires
-- nothing at all. The panel scene itself is the reliable signal: shown with our panel selected
-- means the preview is wanted, hiding means it is not. (Found on PS5 in PB's
-- ChatWindowCustomizer 1.0.0, and confirmed in the library's own source.)
--
-- The scene only exists once the library has initialised, which it does the first time the main
-- menu opens -- after every add-on has loaded -- so it is looked up when a panel is picked, not
-- at load. The first pick of any panel always comes before its scene is shown.
-- ---------------------------------------------------------------------------------------

local PANEL_SCENE_NAME = "LibHarvensAddonSettingsScene"

function preview:PanelScene()
	local library = LibHarvensAddonSettings
	local scene = library and library.scene
	if not scene and SCENE_MANAGER and type(SCENE_MANAGER.GetScene) == "function" then
		scene = SCENE_MANAGER:GetScene(PANEL_SCENE_NAME)
	end
	if type(scene) == "table" and type(scene.RegisterCallback) == "function" then
		return scene
	end
	return nil
end

-- Registered on the library's scene, beside the library's own callbacks. Once only.
function preview:WatchPanelScene()
	if self.panelScene then
		return self.panelScene
	end
	local scene = self:PanelScene()
	if not scene then
		return nil
	end
	self.panelScene = scene
	scene:RegisterCallback("StateChange", function(_, newState)
		if newState == SCENE_SHOWN then
			local panel = addon.settingsPanel
			self:SetPanelOpen(panel ~= nil and panel.selected == true)
		elseif newState == SCENE_HIDING then
			self:SetPanelOpen(false)
		end
	end)
	return scene
end

-- LibHarvensAddonSettings_AddonSelected. On console the panel scene is not up yet, and its
-- SCENE_SHOWN does the showing; the PC copy of the library has no such scene and shows the panel
-- in place, so there the preview goes up at once.
function preview:OnAddonSelected(addonSettings)
	local scene = self:WatchPanelScene()
	if addonSettings ~= addon.settingsPanel then
		self:SetPanelOpen(false)
		return
	end
	if scene and not (type(scene.IsShowing) == "function" and scene:IsShowing()) then
		return
	end
	self:SetPanelOpen(true)
end

-- The settings panel was opened (true) or another add-on's panel was picked (false).
function preview:SetPanelOpen(open)
	self.forPanel = open and true or false
	if self.forPanel and addon:Account().preview then
		self:Show()
	elseif not self.forced then
		self:Hide()
	end
end

-- The slash command: shows the frames wherever the player is -- on the HUD they sit on top of
-- the real bars, which is the quickest way to see that the two agree.
function preview:Toggle()
	if self:IsShown() then
		self:Hide()
		return false
	end
	self.forced = true
	return self:Show()
end
