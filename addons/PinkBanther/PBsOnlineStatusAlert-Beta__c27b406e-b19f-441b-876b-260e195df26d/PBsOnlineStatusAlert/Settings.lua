-- The settings panel (LibHarvensAddonSettings): which guilds to watch, what to show, how the banner looks.
-- The panel's rows are pooled and shared with other add-ons' panels, so every row reads its value from the saved
-- settings (getFunction) and the labels that change are functions.
--
-- While this panel is open a sample banner is shown at the place the alerts will appear (Alert.lua,
-- A:SetPreview). Following the panel is the part that needs care on a console; it is the way that PB's
-- ChatWindowCustomizer does it, which was measured there:
--
--   addon:Select()                                      fires AddonSelected, then sets .selected
--   SCENE_MANAGER:Push("LibHarvensAddonSettingsScene")  and only then shows the panel
--
-- So AddonSelected arrives while the add-on list is still the current scene, and Select() returns early for
-- the add-on that is already selected, so a second visit to the same panel fires nothing. The panel's scene
-- is the reliable signal: shown with this panel selected means the sample is wanted, hiding means it is not.
-- The scene exists only once the library has initialised (the first time the main menu opens, after every
-- add-on has loaded), so it is looked up when a panel is picked, not at load.

local A, S = PBS_OSA, PBS_OSA_STRINGS

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

-- "Guild 2: Name" for the row of slot i, or the row of an empty slot.
function A:GuildRowLabel(i)
	local id = self:GuildIdAt(i)
	if not id then
		return string.format(S.guildRow, i, S.guildNone)
	end
	return string.format(S.guildRow, i, self:GuildName(id, i))
end

function A:WatchSummary()
	local names = self:WatchedNames()
	if #names == 0 then
		return S.watchingNone
	end
	return string.format(S.watching, table.concat(names, ", "))
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

	panel:AddSetting({ type = L.ST_LABEL, label = S.note })

	panel:AddSetting({
		type = L.ST_CHECKBOX,
		label = S.enabled,
		default = self.defaults.enabled,
		getFunction = function()
			return self.sv.enabled
		end,
		setFunction = function(value)
			self:Set("enabled", value and true or false)
			self:ApplyListening()
		end,
	})

	-- The guilds: one row for each of the five slots. The rows are fixed; a slot without a guild is disabled.
	panel:AddSetting({ type = SECTION, label = S.guildSection })
	for i = 1, self.MAX_GUILDS do
		panel:AddSetting({
			type = L.ST_CHECKBOX,
			label = function()
				return self:GuildRowLabel(i)
			end,
			default = false,
			disable = function()
				return self:GuildIdAt(i) == nil
			end,
			getFunction = function()
				local id = self:GuildIdAt(i)
				return id ~= nil and self:IsWatched(id)
			end,
			setFunction = function(value)
				local id = self:GuildIdAt(i)
				if id then
					self:SetWatched(id, value)
					self:RefreshPreview()
				end
			end,
		})
	end
	panel:AddSetting({
		type = L.ST_LABEL,
		label = function()
			return self:WatchSummary()
		end,
	})

	panel:AddSetting({ type = SECTION, label = S.alertSection })
	local function toggle(key, after)
		panel:AddSetting({
			type = L.ST_CHECKBOX,
			label = S[key],
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
	toggle("notifyOnline")
	toggle("notifyOffline")
	toggle("showGuildName", function()
		self:RefreshPreview()
	end)
	toggle("showCharacter", function()
		self:RefreshPreview()
	end)
	toggle("sound")

	panel:AddSetting({ type = SECTION, label = S.displaySection })
	-- unit is a plain string the library puts after the number (a function would break its length test)
	local function slider(key, label, unit, min, max, step, after)
		panel:AddSetting({
			type = L.ST_SLIDER,
			label = label,
			min = min,
			max = max,
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
	slider("duration", S.duration, " s", self.LIMITS.duration[1], self.LIMITS.duration[2], 1)

	local sizeItems = {
		{ name = S.sizeSmall, data = 1 },
		{ name = S.sizeMedium, data = 2 },
		{ name = S.sizeLarge, data = 3 },
	}
	panel:AddSetting({
		type = L.ST_DROPDOWN,
		label = S.size,
		items = sizeItems,
		getFunction = function()
			return (sizeItems[self.sv.size] or sizeItems[2]).name
		end,
		setFunction = function(_, _, item)
			if item and item.data then
				self:Set("size", item.data)
				self:ApplyLayout()
			end
		end,
	})
	slider("posX", S.posX, " px", self.LIMITS.posX[1], self.LIMITS.posX[2], 10, function()
		self:ApplyLayout()
	end)
	slider("posY", S.posY, " px", self.LIMITS.posY[1], self.LIMITS.posY[2], 10, function()
		self:ApplyLayout()
	end)
	slider("quiet", S.quiet, " s", self.LIMITS.quiet[1], self.LIMITS.quiet[2], 1)

	-- What the add-on did lately: the chat window is hidden while a console menu is open, so the log is a label.
	panel:AddSetting({
		type = L.ST_LABEL,
		label = function()
			return self:LogText()
		end,
	})

	-- Typing a command on a console is awkward: the same two things are buttons.
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.testLabel,
		buttonText = S.testButton,
		clickHandler = function()
			self:QueueTest()
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
end

PBS_OSA_MARK("Settings")
