-- PB's Proc Set Timer -- the settings panel (LibHarvensAddonSettings, optional)
--
-- PBS_PROCSETTIMER is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_PROCSETTIMER then
	return
end

local addon = PBS_PROCSETTIMER

function addon:InitSettings()
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

	local function Heading(label)
		settings:AddSetting({ type = LHAS.ST_SECTION or LHAS.ST_LABEL, label = GetString(label) })
	end

	local function Checkbox(key, label, tooltip)
		settings:AddSetting(
			{
				type = LHAS.ST_CHECKBOX,
				label = GetString(label),
				tooltip = tooltip and GetString(tooltip) or nil,
				default = self.DEFAULTS[key],
				getFunction = function()
					return self.sv[key]
				end,
				setFunction = function(value)
					self:Set(key, value)
				end
			}
		)
	end

	local function Slider(key, label, tooltip, min, max, step)
		settings:AddSetting(
			{
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
					self:Set(key, value)
				end
			}
		)
	end

	-- The sizes of the gamepad fonts the client has; the stored value is the size itself.
	local function FontSize(key)
		local items = {}
		for _, size in ipairs(self.FONT_SIZES) do
			items[#items + 1] = { name = tostring(size), data = size }
		end
		settings:AddSetting(
			{
				type = LHAS.ST_DROPDOWN,
				label = GetString(SI_PBSPST_ELEM_FONT),
				items = items,
				default = tostring(self.DEFAULTS[key]),
				getFunction = function()
					return tostring(self.sv[key])
				end,
				setFunction = function(_, _, item)
					self:Set(key, item.data)
				end
			}
		)
	end

	-- One element of a row: shown or not, where, and how big.
	--   prefix  "name" | "bar" | "text", the start of its saved-variable keys
	--   sizes   which of width / height / font the element has
	local function Element(prefix, section, sizes)
		Heading(section)
		Checkbox(prefix .. "Show", SI_PBSPST_ELEM_SHOW)
		Slider(prefix .. "X", SI_PBSPST_ELEM_X, SI_PBSPST_ELEM_X_TOOLTIP, -300, 1200, 2)
		Slider(prefix .. "Y", SI_PBSPST_ELEM_Y, SI_PBSPST_ELEM_Y_TOOLTIP, -60, 60, 1)
		Slider(prefix .. "Width", SI_PBSPST_ELEM_WIDTH, nil, 20, 700, 5)
		if sizes.height then
			Slider(prefix .. "Height", SI_PBSPST_ELEM_HEIGHT, nil, 2, 60, 1)
		end
		if sizes.font then
			FontSize(prefix .. "Font")
		end
	end

	settings:AddSetting({ type = LHAS.ST_LABEL, label = GetString(SI_PBSPST_EXPLANATION) })
	settings:AddSetting({ type = LHAS.ST_LABEL, label = GetString(SI_PBSPST_SETS_HINT) })

	-- ---- the sets to follow ---------------------------------------------------------------
	local function Refresh()
		if settings.UpdateControls then
			settings:UpdateControls()
		end
	end

	Heading(SI_PBSPST_SECTION_SETS)
	Checkbox("trackNew", SI_PBSPST_TRACK_NEW, SI_PBSPST_TRACK_NEW_TOOLTIP)
	for _, button in ipairs({
		{ label = SI_PBSPST_TRACK_ALL, text = SI_PBSPST_TRACK_ALL_BUTTON, tooltip = SI_PBSPST_TRACK_ALL_TOOLTIP, value = true },
		{ label = SI_PBSPST_TRACK_NONE, text = SI_PBSPST_TRACK_NONE_BUTTON, tooltip = SI_PBSPST_TRACK_NONE_TOOLTIP, value = false },
	}) do
		settings:AddSetting(
			{
				type = LHAS.ST_BUTTON,
				label = GetString(button.label),
				tooltip = GetString(button.tooltip),
				buttonText = GetString(button.text),
				clickHandler = function()
					self:SetAllTracked(button.value)
					Refresh()
				end
			}
		)
	end

	-- The list itself is as long as the sets worn, so it is a run of rows that is taken out and put
	-- back whenever the sets change (the same way PBsKillLog does it). Nothing but this run sits
	-- between the buttons above and the next section.
	local MAX_SET_ROWS = 40
	local dynamicStart = #settings.settings + 1
	local dynamicCount = 0
	local lastKey

	local function SetRows(noScan)
		local list = self:TrackableSets(noScan)
		local rows, key = {}, {}
		if #list == 0 then
			rows[1] = { type = LHAS.ST_LABEL, label = GetString(SI_PBSPST_NO_SETS) }
		end
		for index = 1, zo_min(#list, MAX_SET_ROWS) do
			local entry = list[index]
			local label = entry.name
			if not entry.worn then
				label = label .. "  " .. GetString(SI_PBSPST_SET_NOT_WORN)
			end
			rows[#rows + 1] = {
				type = LHAS.ST_CHECKBOX,
				label = label,
				tooltip = GetString(SI_PBSPST_SET_ROW_TOOLTIP),
				default = true,
				getFunction = function()
					return self:IsTracked(entry.setId)
				end,
				setFunction = function(value)
					self:SetTracked(entry.setId, value)
				end
			}
			key[#key + 1] = entry.setId .. (entry.worn and "w" or "n")
		end
		if #list > MAX_SET_ROWS then
			rows[#rows + 1] = { type = LHAS.ST_LABEL, label = string.format(GetString(SI_PBSPST_MORE_SETS), #list - MAX_SET_ROWS) }
		end
		return rows, table.concat(key, ",")
	end

	-- Does nothing when the list is the one already drawn.
	local function RebuildSetRows(noScan)
		local rows, key = SetRows(noScan)
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
	RebuildSetRows(true)

	-- On console a panel opens in two steps: AddonSelected fires before the library draws it, so the
	-- list is made current there; but selecting the panel that is already selected fires nothing, so
	-- the panel's scene being shown is watched too. The scene exists only once the library has
	-- initialised, which is after every add-on has loaded: it is looked up at the first AddonSelected.
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
				pcall(RebuildSetRows)
			end
		end)
	end

	CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", function(_, addonSettings)
		WatchScene()
		if addonSettings == settings then
			RebuildSetRows()
		end
	end)

	Heading(SI_PBSPST_SECTION_DISPLAY)
	Checkbox("enabled", SI_PBSPST_ENABLED, SI_PBSPST_ENABLED_TOOLTIP)
	Checkbox("combatOnly", SI_PBSPST_COMBAT_ONLY, SI_PBSPST_COMBAT_ONLY_TOOLTIP)
	Checkbox("onlyDetected", SI_PBSPST_ONLY_DETECTED, SI_PBSPST_ONLY_DETECTED_TOOLTIP)
	Checkbox("soundReady", SI_PBSPST_SOUND_READY, SI_PBSPST_SOUND_READY_TOOLTIP)
	settings:AddSetting(
		{
			type = LHAS.ST_CHECKBOX,
			label = GetString(SI_PBSPST_PREVIEW),
			tooltip = GetString(SI_PBSPST_PREVIEW_TOOLTIP),
			default = false,
			getFunction = function()
				return self.preview
			end,
			setFunction = function(value)
				self:SetPreview(value)
			end
		}
	)

	Heading(SI_PBSPST_SECTION_BLOCK)
	Slider("posX", SI_PBSPST_POS_X, SI_PBSPST_POS_X_TOOLTIP, -960, 960, 5)
	Slider("posY", SI_PBSPST_POS_Y, SI_PBSPST_POS_Y_TOOLTIP, -540, 540, 5)
	Slider("scale", SI_PBSPST_SCALE, SI_PBSPST_SCALE_TOOLTIP, 50, 200, 5)
	Slider("rowHeight", SI_PBSPST_ROW_HEIGHT, SI_PBSPST_ROW_HEIGHT_TOOLTIP, 16, 80, 2)

	Element("name", SI_PBSPST_SECTION_NAME, { font = true })
	Element("bar", SI_PBSPST_SECTION_BAR, { height = true })
	Element("text", SI_PBSPST_SECTION_TEXT, { font = true })

	-- Red, green and blue of each state's colour. Sliders, not the library's colour picker: that one
	-- opens a dialog of the client's own, which this add-on has no reason to trust on a console.
	Heading(SI_PBSPST_SECTION_COLORS)
	settings:AddSetting({ type = LHAS.ST_LABEL, label = GetString(SI_PBSPST_COLORS_HINT) })
	local STATE_LABELS = {
		active = { SI_PBSPST_COLOR_ACTIVE, SI_PBSPST_COLOR_ACTIVE_TOOLTIP },
		cooldown = { SI_PBSPST_COLOR_COOLDOWN, SI_PBSPST_COLOR_COOLDOWN_TOOLTIP },
		ready = { SI_PBSPST_COLOR_READY, SI_PBSPST_COLOR_READY_TOOLTIP },
		idle = { SI_PBSPST_COLOR_IDLE, SI_PBSPST_COLOR_IDLE_TOOLTIP },
		flash = { SI_PBSPST_COLOR_FLASH, SI_PBSPST_COLOR_FLASH_TOOLTIP },
	}
	local CHANNELS = {
		{ "R", SI_PBSPST_COLOR_RED },
		{ "G", SI_PBSPST_COLOR_GREEN },
		{ "B", SI_PBSPST_COLOR_BLUE },
	}
	for _, state in ipairs(self.COLOR_STATES) do
		for _, channel in ipairs(CHANNELS) do
			local key = "color" .. self.COLOR_NAMES[state] .. channel[1]
			settings:AddSetting(
				{
					type = LHAS.ST_SLIDER,
					label = GetString(STATE_LABELS[state][1]) .. " " .. GetString(channel[2]),
					tooltip = GetString(STATE_LABELS[state][2]),
					min = 0,
					max = 255,
					step = 5,
					default = self.DEFAULTS[key],
					getFunction = function()
						return self.sv[key]
					end,
					setFunction = function(value)
						self:Set(key, value)
					end
				}
			)
		end
	end
	settings:AddSetting(
		{
			type = LHAS.ST_BUTTON,
			label = GetString(SI_PBSPST_COLORS_RESET),
			buttonText = GetString(SI_PBSPST_COLORS_RESET_BUTTON),
			clickHandler = function()
				self:ResetColors()
				Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LHAS.ST_BUTTON,
			label = GetString(SI_PBSPST_RESET),
			buttonText = GetString(SI_PBSPST_RESET_BUTTON),
			clickHandler = function()
				self:Reset()
				if settings.UpdateControls then
					settings:UpdateControls()
				end
			end
		}
	)
end
