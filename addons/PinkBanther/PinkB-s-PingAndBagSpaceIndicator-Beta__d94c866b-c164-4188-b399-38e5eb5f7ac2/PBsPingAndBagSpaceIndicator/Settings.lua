-- The settings panel (LibHarvensAddonSettings): what to show, where, how big, and when a value turns yellow or
-- red. The panel's rows are pooled and shared with other add-ons' panels, so every row reads its value from the
-- saved settings (getFunction).
--
-- While this panel is open the readout is shown at its place (Hud.lua, A:SetPreview). Following the panel is the
-- part that needs care on a console; it is the way PB's ChatWindowCustomizer does it, which was measured there:
--
--   addon:Select()                                      fires AddonSelected, then sets .selected
--   SCENE_MANAGER:Push("LibHarvensAddonSettingsScene")  and only then shows the panel
--
-- So AddonSelected arrives while the add-on list is still the current scene, and Select() returns early for the
-- add-on that is already selected, so a second visit to the same panel fires nothing. The panel's scene is the
-- reliable signal: shown with this panel selected means the preview is wanted, hiding means it is not. The scene
-- exists only once the library has initialised, so it is looked up when a panel is picked, not at load.

local A, S = PBS_PBSI, PBS_PBSI_STRINGS

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
	scene:RegisterCallback("StateChange", A.Guard(function(_, newState)
		if newState == SCENE_SHOWN then
			self:SetPreview(self.panel ~= nil and self.panel.selected == true)
		elseif newState == SCENE_HIDING then
			self:SetPreview(false)
		end
	end))
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

	CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", A.Guard(function(_, addonSettings)
		self:OnAddonSelected(addonSettings)
	end))

	-- a changed setting shows at once (guarded: the library calls this from its own rows)
	local changed = A.Guard(function()
		self:HudSettingsChanged()
	end)

	-- older copies of the library have no section row: a plain label is the stand-in
	local SECTION = L.ST_SECTION or L.ST_LABEL

	panel:AddSetting({ type = L.ST_LABEL, label = S.note })

	local function toggle(key, label)
		panel:AddSetting({
			type = L.ST_CHECKBOX,
			label = label,
			default = self.defaults[key],
			getFunction = function()
				return self.sv[key]
			end,
			setFunction = function(value)
				self:Set(key, value and true or false)
				changed()
			end,
		})
	end
	-- unit is a plain string the library puts after the number (a function would break its length test)
	local function slider(key, label, unit, step)
		local limits = self.LIMITS[key]
		panel:AddSetting({
			type = L.ST_SLIDER,
			label = label,
			min = limits[1],
			max = limits[2],
			step = step,
			unit = unit,
			default = self.defaults[key],
			format = "%d",
			getFunction = function()
				return self.sv[key]
			end,
			setFunction = function(value)
				self:Set(key, value)
				changed()
			end,
		})
	end
	-- a drop-down over a list of names; the saved value is the position in the list
	local function choice(key, label, names)
		local items = {}
		for i, name in ipairs(names) do
			items[i] = { name = name, data = i }
		end
		panel:AddSetting({
			type = L.ST_DROPDOWN,
			label = label,
			items = items,
			getFunction = function()
				return (items[self.sv[key]] or items[self.defaults[key]]).name
			end,
			setFunction = function(_, _, item)
				if item and item.data then
					self:Set(key, item.data)
					changed()
				end
			end,
		})
	end

	toggle("enabled", S.enabled)

	panel:AddSetting({ type = SECTION, label = S.itemsSection })
	toggle("showPing", S.showPing)
	toggle("showFps", S.showFps)
	toggle("showBag", S.showBag)
	toggle("showBank", S.showBank)
	toggle("showGold", S.showGold)
	toggle("showBankGold", S.showBankGold)
	choice("bagMode", S.bagMode, { S.bagModeUsed, S.bagModeFree })

	panel:AddSetting({ type = SECTION, label = S.lookSection })
	choice("layout", S.layout, { S.layoutLine, S.layoutColumn })
	choice("size", S.size, { S.sizeSmall, S.sizeMedium, S.sizeLarge })
	slider("bgAlpha", S.bgAlpha, " %", 5)

	panel:AddSetting({ type = SECTION, label = S.placeSection })
	choice("anchor", S.anchor, { S.anchorTopLeft, S.anchorTop, S.anchorTopRight, S.anchorBottomLeft, S.anchorBottom, S.anchorBottomRight })
	slider("posX", S.posX, " px", 10)
	slider("posY", S.posY, " px", 10)
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.resetLabel,
		buttonText = S.resetButton,
		clickHandler = function()
			self:ResetPlace()
			changed()
			if panel.UpdateControls then
				panel:UpdateControls()
			end
		end,
	})

	panel:AddSetting({ type = SECTION, label = S.colorSection })
	slider("pingWarn", S.pingWarn, " ms", 10)
	slider("pingBad", S.pingBad, " ms", 10)
	slider("fpsWarn", S.fpsWarn, " fps", 1)
	slider("fpsBad", S.fpsBad, " fps", 1)
	slider("bagWarn", S.bagWarn, "", 1)

	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.statusLabel,
		buttonText = S.statusButton,
		clickHandler = function()
			self:PrintStatus()
		end,
	})
end

PBS_PBSI_MARK("Settings")
