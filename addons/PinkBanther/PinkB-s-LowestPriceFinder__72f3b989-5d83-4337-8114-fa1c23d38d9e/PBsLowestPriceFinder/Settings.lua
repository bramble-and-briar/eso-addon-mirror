PBsLowestPriceFinder = PBsLowestPriceFinder or {}
local ADDON = PBsLowestPriceFinder

---------------------------------------------------------------------------------------------------
-- The settings panel (LibHarvensAddonSettings, optional)
--
-- The watched items are a run of rows (one "remove" button each) that is taken out and put back when
-- the list changes, the way PB's Proc Set Timer and Kill Log do it (measured on PS5). Adding an item
-- is /lpf add in chat, which is the route that is known to work on a console; a text box is offered
-- as well, wrapped in pcall, because whether the library's text row works on a console is not known.
---------------------------------------------------------------------------------------------------

function ADDON:InitializeSettings()
	local LHAS = LibHarvensAddonSettings
	if not LHAS then
		return
	end
	local settings = LHAS:AddAddon(self.title)
	if not settings then
		return
	end
	settings.allowDefaults = true
	settings.author = self.author
	settings.version = self.version

	local panel = self.panel

	local function Refresh()
		if settings.UpdateControls then
			settings:UpdateControls()
		end
	end

	local function Heading(label)
		settings:AddSetting({ type = LHAS.ST_SECTION or LHAS.ST_LABEL, label = GetString(label) })
	end

	-- `showPanel`: also show the panel, so the effect of a layout setting can be seen as it is changed.
	local function Set(key, value, showPanel)
		self.sv[key] = value
		if showPanel then
			panel:Show()
		else
			panel:Refresh()
		end
	end

	local function Checkbox(key, label, tooltip)
		settings:AddSetting({
			type = LHAS.ST_CHECKBOX,
			label = GetString(label),
			tooltip = tooltip and GetString(tooltip) or nil,
			default = self.DEFAULTS[key],
			getFunction = function()
				return self.sv[key]
			end,
			setFunction = function(value)
				Set(key, value)
			end,
		})
	end

	local function Slider(key, label, tooltip, min, max, step, showPanel)
		settings:AddSetting({
			type = LHAS.ST_SLIDER,
			label = GetString(label),
			tooltip = tooltip and GetString(tooltip) or nil,
			min = min,
			max = max,
			step = step,
			default = self.DEFAULTS[key],
			getFunction = function()
				return self.sv[key]
			end,
			setFunction = function(value)
				Set(key, value, showPanel)
			end,
		})
	end

	local function Button(label, text, tooltip, handler)
		settings:AddSetting({
			type = LHAS.ST_BUTTON,
			label = GetString(label),
			tooltip = tooltip and GetString(tooltip) or nil,
			buttonText = GetString(text),
			clickHandler = handler,
		})
	end

	settings:AddSetting({ type = LHAS.ST_LABEL, label = GetString(SI_PBSLPF_EXPLANATION) })

	-- ---- search -----------------------------------------------------------------------------
	Heading(SI_PBSLPF_SECTION_SEARCH)
	Checkbox("autoScan", SI_PBSLPF_AUTO, SI_PBSLPF_AUTO_TOOLTIP)
	Slider("rescanMinutes", SI_PBSLPF_RESCAN, SI_PBSLPF_RESCAN_TOOLTIP, 0, 240, 5)
	Slider("maxAgeDays", SI_PBSLPF_MAX_AGE, SI_PBSLPF_MAX_AGE_TOOLTIP, 0, 30, 1)

	-- ---- the watched items ------------------------------------------------------------------
	Heading(SI_PBSLPF_SECTION_ITEMS)
	if LHAS.ST_EDIT then
		pcall(function()
			settings:AddSetting({
				type = LHAS.ST_EDIT,
				label = GetString(SI_PBSLPF_ADD_EDIT),
				tooltip = GetString(SI_PBSLPF_ADD_EDIT_TOOLTIP),
				default = "",
				getFunction = function()
					return ""
				end,
				setFunction = function(value)
					if value and value ~= "" and self:AddWatch(value) then
						panel:Refresh()
						self:RebuildSettingsRows()
					end
				end,
			})
		end)
	end

	local dynamicStart = #settings.settings + 1
	local dynamicCount = 0
	local lastKey

	local function ItemRows()
		local rows, key = {}, {}
		local watch = self.sv.watch
		if #watch == 0 then
			rows[1] = { type = LHAS.ST_LABEL, label = GetString(SI_PBSLPF_NO_ITEMS) }
		end
		for index, entry in ipairs(watch) do
			rows[#rows + 1] = {
				type = LHAS.ST_BUTTON,
				label = string.format("%d. %s", index, self:WatchLabel(entry)),
				tooltip = GetString(SI_PBSLPF_REMOVE_TOOLTIP),
				buttonText = GetString(SI_PBSLPF_REMOVE_BUTTON),
				clickHandler = function()
					local position = self:FindWatch(index)
					if position then
						self:RemoveWatch(position)
					end
					panel:Refresh()
					self:RebuildSettingsRows()
					Refresh()
				end,
			}
			key[#key + 1] = self:WatchKey(entry)
		end
		return rows, table.concat(key, "\n")
	end

	-- Does nothing when the list is the one already drawn.
	function self:RebuildSettingsRows()
		local rows, key = ItemRows()
		if key == lastKey then
			return
		end
		if dynamicCount > 0 then
			settings:RemoveSettings(dynamicStart, dynamicCount)
		end
		settings:AddSettings(rows, dynamicStart)
		dynamicCount = #rows
		lastKey = key
	end
	self:RebuildSettingsRows()

	-- On console a panel opens in two steps: AddonSelected fires before the library draws it, so the
	-- list is made current there; selecting the panel that is already selected fires nothing, so the
	-- panel's scene being shown is watched too (it exists only once the library has initialised).
	local watched = false
	local function WatchScene()
		if watched then
			return
		end
		local scene = LHAS.scene
		if not scene and SCENE_MANAGER and type(SCENE_MANAGER.GetScene) == "function" then
			scene = SCENE_MANAGER:GetScene("LibHarvensAddonSettingsScene")
		end
		if type(scene) ~= "table" or type(scene.RegisterCallback) ~= "function" then
			return
		end
		watched = true
		scene:RegisterCallback("StateChange", function(_, newState)
			if newState == SCENE_SHOWN and settings.selected == true then
				pcall(function()
					self:RebuildSettingsRows()
				end)
			end
		end)
	end
	CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", function(_, addonSettings)
		WatchScene()
		if addonSettings == settings then
			self:RebuildSettingsRows()
		end
	end)

	-- ---- the panel --------------------------------------------------------------------------
	Heading(SI_PBSLPF_SECTION_PANEL)
	Checkbox("panel", SI_PBSLPF_PANEL, SI_PBSLPF_PANEL_TOOLTIP)
	Slider("panelHoldSec", SI_PBSLPF_PANEL_HOLD, nil, 5, 120, 5)
	Slider("panelSize", SI_PBSLPF_PANEL_SIZE, nil, 1, panel.NUM_SIZES, 1, true)
	Slider("panelLeft", SI_PBSLPF_PANEL_LEFT, nil, 0, 1800, 10, true)
	Slider("panelTop", SI_PBSLPF_PANEL_TOP, nil, 0, 1000, 10, true)
	Button(SI_PBSLPF_PANEL_PREVIEW, SI_PBSLPF_PANEL_PREVIEW_BUTTON, nil, function()
		panel:Show()
	end)

	-- ---- data -------------------------------------------------------------------------------
	Heading(SI_PBSLPF_SECTION_DATA)
	Button(SI_PBSLPF_FORGET, SI_PBSLPF_FORGET_BUTTON, SI_PBSLPF_FORGET_TOOLTIP, function()
		self:ForgetData()
		panel:Refresh()
	end)
	Button(SI_PBSLPF_CLEAR, SI_PBSLPF_CLEAR_BUTTON, nil, function()
		self:ClearWatch()
		panel:Refresh()
		self:RebuildSettingsRows()
		Refresh()
	end)
end
