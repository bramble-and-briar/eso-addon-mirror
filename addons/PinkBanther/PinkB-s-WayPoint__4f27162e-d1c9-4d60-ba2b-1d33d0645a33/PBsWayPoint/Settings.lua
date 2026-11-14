local A, S = PBS_WAYPOINT, PBS_WAYPOINT_STRINGS

-- ---------------------------------------------------------------------------------------
-- The panel
-- ---------------------------------------------------------------------------------------

function A:InitSettings()
	local L = LibHarvensAddonSettings
	if not L then
		return
	end
	local panel = L:AddAddon(self.title)
	if not panel then
		return
	end
	self.panel = panel
	panel.author, panel.version, panel.allowDefaults = self.author, self.version, true
	CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", function(_, selected)
		self:OnAddonSelected(selected)
	end)

	panel:AddSetting({ type = L.ST_LABEL, label = S.note })

	local function toggle(key)
		panel:AddSetting({
			type = L.ST_CHECKBOX,
			label = S[key],
			default = self.defaults[key],
			getFunction = function()
				return self.sv[key]
			end,
			setFunction = function(value)
				self:Set(key, value)
			end,
		})
	end
	local function slider(key, step)
		local range = self.RANGES[key]
		panel:AddSetting({
			type = L.ST_SLIDER,
			label = S[key],
			min = range[1],
			max = range[2],
			step = step,
			default = self.defaults[key],
			getFunction = function()
				return self.sv[key]
			end,
			setFunction = function(value)
				self:Set(key, value)
			end,
		})
	end
	local function button(label, text, handler)
		panel:AddSetting({
			type = L.ST_BUTTON,
			label = label,
			buttonText = text,
			clickHandler = handler,
		})
	end

	toggle("enabled")
	toggle("addMode")
	toggle("pins")
	toggle("arrow")
	toggle("trail")
	toggle("sound")
	toggle("chat")
	toggle("preview")
	toggle("shareSend")
	toggle("shareReceive")
	toggle("resetChord")
	slider("arriveRadius", 5)
	slider("arrowSize", 4)
	slider("opacity", 5)
	slider("x", 5)
	slider("y", 5)
	slider("trailLength", 5)
	button(S.skip, S.skipButton, function()
		self:ActSkip()
	end)
	button(S.undo, S.undoButton, function()
		self:ActUndo()
	end)
	button(S.clear, S.clearButton, function()
		self:ActClear()
	end)
	button(S.reset, S.resetButton, function()
		self:Reset()
		if panel.UpdateControls then
			panel:UpdateControls()
		end
	end)
end

-- ---------------------------------------------------------------------------------------
-- The preview: while the settings panel is open the arrow is drawn over it, with a sample stop, so that each
-- change can be seen. The panel is not a HUD scene, so without this nothing would show.
-- ---------------------------------------------------------------------------------------

function A:SetPanelOpen(open)
	self.panelOpen = open and true or false
	self:ApplyLayout()
	self:RefreshVisibility()
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

A.loaded.Settings = true
