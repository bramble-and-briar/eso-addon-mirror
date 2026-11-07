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

	-- The guild store's Quality choices: "any", then Normal ... Legendary. `data` 0 is "any".
	local function QualityItems()
		local items = { { name = self.QualityName(nil), data = 0 } }
		for _, quality in ipairs(self.QualityValues()) do
			items[#items + 1] = { name = self.QualityName(quality), data = quality }
		end
		return items
	end

	local function QualityRow(label, tooltip, getQuality, setQuality)
		local items = QualityItems()
		return {
			type = LHAS.ST_DROPDOWN,
			label = label,
			tooltip = tooltip,
			items = items,
			default = items[1].name,
			getFunction = function()
				local quality = getQuality() or 0
				for _, item in ipairs(items) do
					if item.data == quality then
						return item.name
					end
				end
				return items[1].name
			end,
			setFunction = function(_, _, item)
				setQuality(item.data ~= 0 and item.data or nil)
			end,
		}
	end

	settings:AddSetting(QualityRow(GetString(SI_PBSLPF_QUALITY_ROW), GetString(SI_PBSLPF_QUALITY_ROW_TOOLTIP), function()
		return self.sv.addQuality
	end, function(quality)
		self.sv.addQuality = quality
	end))

	if LHAS.ST_EDIT then
		pcall(function()
			settings:AddSetting({
				type = LHAS.ST_EDIT,
				label = GetString(SI_PBSLPF_ADD_EDIT),
				tooltip = GetString(SI_PBSLPF_ADD_EDIT_TOOLTIP),
				default = "",
				-- The newest name searched in the guild store that is not watched yet (the first one /lpf history
				-- lists), with the quality chosen there, is filled in: confirming the row watches it. Nothing to
				-- fill in: empty.
				getFunction = function()
					local ok, text = pcall(function()
						local choices = self:HistoryChoices()
						return choices and choices[1] and self:EntryInputText(choices[1], self.sv.addQuality) or ""
					end)
					return ok and text or ""
				end,
				setFunction = function(value)
					if value and value ~= "" and self:AddWatch(value, self.sv.addQuality) then
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
		local function PositionOf(entry)
			local position
			for candidate, existing in ipairs(watch) do
				if existing == entry then
					position = candidate
				end
			end
			return position
		end
		for index, entry in ipairs(watch) do
			-- the quality it is searched in, as the guild store's own choices
			rows[#rows + 1] = QualityRow(string.format("%d. %s", index, self:WatchLabel(entry, true)), GetString(SI_PBSLPF_QUALITY_ITEM_TOOLTIP), function()
				return entry.quality
			end, function(quality)
				local position = PositionOf(entry)
				if position then
					local ok, _, other = self:SetWatchQuality(position, quality)
					if not ok and other then
						ADDON.Print(ADDON.Format(SI_PBSLPF_ADD_DUP, self:WatchLabel(other)))
					end
				end
				panel:Refresh()
				Refresh()
			end)
			rows[#rows + 1] = {
				type = LHAS.ST_BUTTON,
				label = ADDON.Format(SI_PBSLPF_REMOVE_ROW, index),
				tooltip = GetString(SI_PBSLPF_REMOVE_TOOLTIP),
				buttonText = GetString(SI_PBSLPF_REMOVE_BUTTON),
				clickHandler = function()
					local position = PositionOf(entry)
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

		-- the names searched in the guild store lately (not watched yet), to pick from instead of typing
		rows[#rows + 1] = { type = LHAS.ST_SECTION or LHAS.ST_LABEL, label = GetString(SI_PBSLPF_SECTION_HISTORY) }
		local choices = self:HistoryChoices()
		if choices == nil then
			rows[#rows + 1] = { type = LHAS.ST_LABEL, label = GetString(SI_PBSLPF_HISTORY_ROW_UNREADABLE) }
			key[#key + 1] = "history:unreadable"
		elseif #choices == 0 then
			rows[#rows + 1] = { type = LHAS.ST_LABEL, label = GetString(SI_PBSLPF_HISTORY_ROW_EMPTY) }
			key[#key + 1] = "history:none"
		end
		for _, choice in ipairs(choices or {}) do
			rows[#rows + 1] = {
				type = LHAS.ST_BUTTON,
				label = self:WatchLabel(choice),
				tooltip = GetString(SI_PBSLPF_HISTORY_TOOLTIP),
				buttonText = GetString(SI_PBSLPF_HISTORY_BUTTON),
				clickHandler = function()
					if self:AddEntry(choice) then
						panel:Refresh()
						self:RebuildSettingsRows()
						Refresh()
					end
				end,
			}
			key[#key + 1] = "history:" .. self:WatchKey(choice)
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
					-- the panel is already drawn on a revisit: the text row's filled-in name is read again
					Refresh()
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
