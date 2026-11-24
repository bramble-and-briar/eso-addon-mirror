-- The settings panel (LibHarvensAddonSettings): when Ember speaks, how she looks, where she stands.
-- The panel's rows are pooled and shared with other add-ons' panels, so every row reads its value from the saved
-- settings (getFunction) and the labels that change are functions.
--
-- While this panel is open Ember plays all of her alerts in a loop at the right of the screen (Ember.lua,
-- A:SetPreview). Following the panel is the part that needs care on a console; it is the way that PB's
-- ChatWindowCustomizer and Online Status Alert do it, which was measured there:
--
--   addon:Select()                                      fires AddonSelected, then sets .selected
--   SCENE_MANAGER:Push("LibHarvensAddonSettingsScene")  and only then shows the panel
--
-- So AddonSelected arrives while the add-on list is still the current scene, and Select() returns early for
-- the add-on that is already selected, so a second visit to the same panel fires nothing. The panel's scene
-- is the reliable signal: shown with this panel selected means the preview is wanted, hiding means it is not.
-- The scene exists only once the library has initialised (the first time the main menu opens, after every
-- add-on has loaded), so it is looked up when a panel is picked, not at load.

local A, S = PBS_COMBAT_ASSISTANT, PBS_COMBAT_ASSISTANT_STRINGS

local PANEL_SCENE_NAME = "LibHarvensAddonSettingsScene"

function A:PanelScene()
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
function A:WatchPanelScene()
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
			self:SetPreview(self.panel ~= nil and self.panel.selected == true)
		elseif newState == SCENE_HIDING then
			self:SetPreview(false)
		end
	end)
	return scene
end

-- LibHarvensAddonSettings_AddonSelected: the player picked a panel in the add-on list.
function A:OnAddonSelected(addonSettings)
	local scene = self:WatchPanelScene()
	if addonSettings ~= self.panel then
		self:SetPreview(false)
		return
	end
	-- on a console the panel's scene is not up yet and its SCENE_SHOWN does the showing
	if scene and not (type(scene.IsShowing) == "function" and scene:IsShowing()) then
		return
	end
	self:SetPreview(true)
end

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
	panel.author, panel.version, panel.allowDefaults = self.author, self.version, false

	CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", function(_, addonSettings)
		self:OnAddonSelected(addonSettings)
	end)

	local function refresh()
		if panel.UpdateControls then
			panel:UpdateControls()
		end
	end

	-- older copies of the library have no section row: a plain label is the stand-in
	local SECTION = L.ST_SECTION or L.ST_LABEL

	-- disable: a function that greys the row out (rows that belong to the other style)
	local function toggle(key, after, disable)
		panel:AddSetting({
			type = L.ST_CHECKBOX,
			label = S[key],
			disable = disable,
			default = self.defaults[key],
			getFunction = function()
				return self.sv[key]
			end,
			setFunction = function(value)
				self:Set(key, value and true or false)
				if after then
					after()
				end
			end,
		})
	end
	-- unit is a plain string the library puts after the number (a function would break its length test)
	local function slider(key, unit, step, after, disable)
		panel:AddSetting({
			type = L.ST_SLIDER,
			label = S[key],
			disable = disable,
			min = self.LIMITS[key][1],
			max = self.LIMITS[key][2],
			step = step,
			unit = unit,
			default = self.defaults[key],
			format = "%d",
			getFunction = function()
				return self.sv[key]
			end,
			setFunction = function(value)
				self:Set(key, value)
				if after then
					after()
				end
			end,
		})
	end
	local function layout()
		self:ApplyLayout()
	end
	local function tilesLayout()
		self:TilesUpdateState()
	end
	local function emberOnly()
		return self.sv.style == 2
	end
	local function tilesOnly()
		return self.sv.style ~= 2
	end
	local function restartPreview()
		if self.panel and self.panel.selected then
			self:SetPreview(false)
			self:SetPreview(true)
		end
	end

	panel:AddSetting({ type = L.ST_LABEL, label = S.note })
	toggle("enabled", function()
		self:ApplyEnabled()
		self:WatchUpdateState()
		if self.panel and self.panel.selected then
			self:SetPreview(false)
			self:SetPreview(true)
		end
	end)
	local styleItems = {
		{ name = S.styleEmber, data = 1 },
		{ name = S.styleMeru, data = 2 },
	}
	panel:AddSetting({
		type = L.ST_DROPDOWN,
		label = S.style,
		tooltip = S.styleTip,
		items = styleItems,
		getFunction = function()
			return (styleItems[self.sv.style] or styleItems[1]).name
		end,
		setFunction = function(_, _, item)
			if item and item.data and item.data ~= self.sv.style then
				self:Set("style", item.data)
				self:ApplyStyle()
				restartPreview()
				refresh()
			end
		end,
	})
	toggle("preview", function()
		if self.panel and self.panel.selected then
			self:SetPreview(false)
			self:SetPreview(true)
		end
	end)

	panel:AddSetting({ type = SECTION, label = S.condSection })
	toggle("major", tilesLayout)
	slider("majorSeconds", " s", 1, nil, emberOnly)
	toggle("minor", tilesLayout)
	slider("minorSeconds", " s", 1, nil, emberOnly)
	toggle("brutal", tilesLayout)
	slider("brutalSeconds", " s", 1, nil, emberOnly)
	toggle("hp", nil, emberOnly)
	slider("hpWarn", " %", 5, nil, emberOnly)
	slider("hpDanger", " %", 5, nil, emberOnly)
	-- crowd control: both designs (a sound; in the Ember Style she also says it)
	toggle("cc", refresh)
	local ccItems = {
		{ name = S.ccSoundNone, data = 0 },
		{ name = S.ccSound1, data = 1 },
		{ name = S.ccSound2, data = 2 },
		{ name = S.ccSound3, data = 3 },
		{ name = S.ccSound4, data = 4 },
	}
	panel:AddSetting({
		type = L.ST_DROPDOWN,
		label = S.ccSound,
		tooltip = S.ccSoundTip,
		disable = function()
			return not self.sv.cc
		end,
		items = ccItems,
		getFunction = function()
			return (ccItems[(self.sv.ccSound or 0) + 1] or ccItems[1]).name
		end,
		setFunction = function(_, _, item)
			if item and item.data then
				self:Set("ccSound", item.data)
				-- picking a sound plays it, so it can be heard before a fight
				self:PlayCcSound()
			end
		end,
	})
	toggle("combatOnly", function()
		self:WatchUpdateState()
		self:TilesUpdateState()
	end)

	panel:AddSetting({ type = SECTION, label = S.tilesSection })
	slider("tileWarn", " s", 1, tilesLayout, tilesOnly)
	toggle("tileSound", nil, tilesOnly)
	slider("tileSize", " %", 10, tilesLayout, tilesOnly)
	slider("tileX", " px", 10, tilesLayout, tilesOnly)
	slider("tileY", " px", 10, tilesLayout, tilesOnly)

	panel:AddSetting({ type = SECTION, label = S.emberSection })
	slider("size", " %", 10, layout, emberOnly)
	local sideItems = {
		{ name = S.sideLeft, data = 1 },
		{ name = S.sideRight, data = 2 },
	}
	panel:AddSetting({
		type = L.ST_DROPDOWN,
		label = S.side,
		disable = emberOnly,
		items = sideItems,
		getFunction = function()
			return (sideItems[self.sv.side] or sideItems[1]).name
		end,
		setFunction = function(_, _, item)
			if item and item.data then
				self:Set("side", item.data)
				self:ApplyLayout()
			end
		end,
	})
	slider("posX", " px", 10, layout, emberOnly)
	slider("posY", " px", 10, layout, emberOnly)
	slider("hold", " s", 1, nil, emberOnly)
	toggle("bubble", layout, emberOnly)
	toggle("sound", nil, emberOnly)

	-- What the add-on did lately: the chat window is hidden while a console menu is open, so the log is a label.
	panel:AddSetting({
		type = L.ST_LABEL,
		label = function()
			return self:LogText()
		end,
	})

	-- Typing a command on a console is awkward: the same things are buttons.
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.testLabel,
		buttonText = S.testButton,
		clickHandler = function()
			self:StartTest()
			self:Note(S.testQueued)
			refresh()
		end,
	})
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.statusLabel,
		buttonText = S.statusButton,
		clickHandler = function()
			self:PrintStatus()
		end,
	})
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.buffsLabel,
		buttonText = S.buffsButton,
		clickHandler = function()
			self:PrintBuffs()
		end,
	})
end

PBS_COMBAT_ASSISTANT_MARK("Settings")
