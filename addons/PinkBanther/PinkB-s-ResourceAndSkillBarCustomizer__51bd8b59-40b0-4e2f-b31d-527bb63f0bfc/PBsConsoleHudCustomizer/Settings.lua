-- PBS_CONSOLE_HUD_CUSTOMIZER is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_CONSOLE_HUD_CUSTOMIZER then
	return
end

local addon = PBS_CONSOLE_HUD_CUSTOMIZER

-- Positions move in fives: a d-pad press that moved a bar one unit at a time would take a
-- minute to cross the screen, and nobody can see the difference between 940 and 943.
local POSITION_STEP = 5
local SCALE_STEP = 5

local function AddHeading(settings, LibHarvensAddonSettings, label)
	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SECTION or LibHarvensAddonSettings.ST_LABEL,
			label = label
		}
	)
end

local function AddLabel(settings, LibHarvensAddonSettings, stringId)
	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = GetString(_G[stringId])
		}
	)
end

-- A slider over one bar's x or y. Every one of them switches the add-on back on when moved:
-- moving a slider and seeing nothing happen because of a switch further up reads as a bug.
local function AddPositionSlider(self, settings, LibHarvensAddonSettings, bar, key, label, tooltip, min, max)
	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = label,
			tooltip = tooltip,
			min = min,
			max = max,
			step = POSITION_STEP,
			default = self:GamePosition(bar)[key],
			format = "%d",
			unit = "",
			getFunction = function()
				return self:Position(bar)[key]
			end,
			setFunction = function(value)
				-- Both values are saved together: a position is a pair, and half of one saved
				-- against the other half still being the game's reads as a bar that jumped.
				local position = self:Position(bar)
				self:SetPositionValue(bar, "x", position.x)
				self:SetPositionValue(bar, "y", position.y)
				self:SetPositionValue(bar, key, addon.Round(value))
				self:Account().enabled = true
				self:Refresh()
			end
		}
	)
end

function addon:InitSettings()
	local LibHarvensAddonSettings = LibHarvensAddonSettings
	if not LibHarvensAddonSettings then
		return
	end

	local settings = LibHarvensAddonSettings:AddAddon(self.title)
	if not settings then
		return
	end
	self.settingsPanel = settings
	settings.allowDefaults = true
	settings.author = self.author
	settings.version = self.version

	-- The preview follows the panel -- see "Following the settings panel" in Preview.lua for why
	-- this callback alone is not enough on console. Registered on the client's callback manager,
	-- beside everyone else's.
	CALLBACK_MANAGER:RegisterCallback(
		"LibHarvensAddonSettings_AddonSelected",
		function(_, addonSettings)
			if self.preview then
				self.preview:OnAddonSelected(addonSettings)
			end
		end
	)

	-- The sliders' ranges are the screen. GuiRoot is the space the anchor offsets are measured
	-- in, so its size is as far as any bar can usefully go: sideways, half the width each way
	-- from the middle; upwards, the whole height.
	local rootWidth, rootHeight = self:RootSize()
	local halfWidth = addon.Round(rootWidth / 2)
	rootHeight = addon.Round(rootHeight)

	AddLabel(settings, LibHarvensAddonSettings, "SI_PBSCHC_EXPLANATION")

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHC_ENABLED),
			tooltip = GetString(SI_PBSCHC_ENABLED_TOOLTIP),
			default = true,
			getFunction = function()
				return self:Account().enabled
			end,
			setFunction = function(value)
				self:Account().enabled = value
				self:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHC_PREVIEW),
			tooltip = GetString(SI_PBSCHC_PREVIEW_TOOLTIP),
			default = true,
			getFunction = function()
				return self:Account().preview
			end,
			setFunction = function(value)
				self:Account().preview = value
				if self.preview then
					self.preview:SetPanelOpen(true)
				end
			end
		}
	)

	-- ---- The look of the resource bars -------------------------------------------------------
	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCHC_SECTION_STYLE))

	local styleItems = {}
	local styleByKey = {}
	for _, style in ipairs(self.BAR_STYLES) do
		local item = { name = GetString(_G["SI_PBSCHC_STYLE_" .. style:upper()]), data = style }
		styleItems[#styleItems + 1] = item
		styleByKey[style] = item
	end

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSCHC_STYLE),
			tooltip = GetString(SI_PBSCHC_STYLE_TOOLTIP),
			items = styleItems,
			default = styleByKey.standard.name,
			getFunction = function()
				return (styleByKey[self:BarStyle()] or styleByKey.standard).name
			end,
			setFunction = function(combobox, name, item)
				self:SetBarStyle(item.data)
				self:Account().enabled = true
				self:Refresh()
				-- Which of the size rows are live depends on the style.
				if settings.UpdateControls then
					settings:UpdateControls()
				end
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCHC_PLAIN_OPACITY),
			tooltip = GetString(SI_PBSCHC_PLAIN_OPACITY_TOOLTIP),
			min = self.MIN_PLAIN_OPACITY,
			max = self.MAX_PLAIN_OPACITY,
			step = 5,
			default = self.DEFAULT_PLAIN_OPACITY,
			format = "%d",
			unit = "%",
			getFunction = function()
				return self:PlainOpacity()
			end,
			setFunction = function(value)
				self:SetPlainOpacity(value)
				self:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHC_PLAIN_BORDER),
			tooltip = GetString(SI_PBSCHC_PLAIN_BORDER_TOOLTIP),
			default = true,
			getFunction = function()
				return self:PlainBorder()
			end,
			setFunction = function(value)
				self:SetPlainBorder(value)
				self:Refresh()
			end
		}
	)

	local borderItems, borderByKey = {}, {}
	for _, key in ipairs(self.BORDER_COLOURS) do
		local item = { name = GetString(_G["SI_PBSCHC_BORDER_" .. key:upper()]), data = key }
		borderItems[#borderItems + 1] = item
		borderByKey[key] = item
	end
	settings:AddSetting({
		type = LibHarvensAddonSettings.ST_DROPDOWN,
		label = GetString(SI_PBSCHC_BORDER_COLOUR),
		tooltip = GetString(SI_PBSCHC_BORDER_COLOUR_TOOLTIP),
		items = borderItems,
		default = borderByKey.black.name,
		getFunction = function() return borderByKey[self:PlainBorderColour()].name end,
		setFunction = function(combobox, name, item)
			self:SetPlainBorderColour(item.data)
			self:Refresh()
		end,
	})

	local alignItems, alignByKey = {}, {}
	for _, key in ipairs(self.RESOURCE_TEXT_ALIGNMENTS) do
		local item = { name = GetString(_G["SI_PBSCHC_RESOURCE_ALIGN_" .. key:upper()]), data = key }
		alignItems[#alignItems + 1] = item
		alignByKey[key] = item
	end
	settings:AddSetting({
		type = LibHarvensAddonSettings.ST_DROPDOWN,
		label = GetString(SI_PBSCHC_RESOURCE_ALIGN),
		tooltip = GetString(SI_PBSCHC_RESOURCE_ALIGN_TOOLTIP),
		items = alignItems,
		default = alignByKey.left.name,
		getFunction = function() return alignByKey[self:ResourceTextAlignment()].name end,
		setFunction = function(combobox, name, item)
			self:SetResourceTextAlignment(item.data)
			self:Refresh()
		end,
		disable = function() return not self:BarsAreMuraHige() end,
	})

	-- ---- One section per bar, all three the same three rows --------------------------------
	for _, bar in ipairs(self.elements) do
		local barName = GetString(_G[bar.stringId])
		AddHeading(settings, LibHarvensAddonSettings, barName)

		-- The skill bar can be handed back whole, for an install that has another add-on laying
		-- it out. Everything below in this section, and the gaps, the other weapon set's row, the
		-- text on the icons and the shade, all go with it.
		if bar.isActionBar then
			settings:AddSetting(
				{
					type = LibHarvensAddonSettings.ST_CHECKBOX,
					label = GetString(SI_PBSCHC_SKILLBAR_ENABLED),
					tooltip = GetString(SI_PBSCHC_SKILLBAR_ENABLED_TOOLTIP),
					default = true,
					getFunction = function()
						return self:Account().skillBar ~= false
					end,
					setFunction = function(value)
						self:SetSkillBarAllowed(value)
						self:Refresh()
						if settings.UpdateControls then
							settings:UpdateControls()
						end
					end
				}
			)
		end

		AddPositionSlider(self, settings, LibHarvensAddonSettings, bar, "x",
			zo_strformat(GetString(SI_PBSCHC_POSITION_X), barName), GetString(SI_PBSCHC_POSITION_X_TOOLTIP),
			-halfWidth, halfWidth)
		AddPositionSlider(self, settings, LibHarvensAddonSettings, bar, "y",
			zo_strformat(GetString(SI_PBSCHC_POSITION_Y), barName), GetString(SI_PBSCHC_POSITION_Y_TOOLTIP),
			0, rootHeight)

		-- MURA-HIGE Style draws the bar itself, so it can be given a size rather than a
		-- multiple of the game's. The two live beside the scale, and say which style they are
		-- for: the panel's rows are built once, and a row that comes and goes is worse to use
		-- than one that says when it applies.
		if not bar.isActionBar then
			settings:AddSetting(
				{
					type = LibHarvensAddonSettings.ST_SLIDER,
					label = zo_strformat(GetString(SI_PBSCHC_BAR_WIDTH), barName),
					tooltip = GetString(SI_PBSCHC_BAR_WIDTH_TOOLTIP),
					min = self.MIN_BAR_WIDTH,
					max = self.MAX_BAR_WIDTH,
					step = 2,
					default = self.GAME_BAR_WIDTH,
					format = "%d",
					unit = "",
					getFunction = function()
						return (self:BarSize(bar))
					end,
					setFunction = function(value)
						self:SetBarSize(bar, "width", value)
						self:Account().enabled = true
						self:Refresh()
					end,
					-- Only MURA-HIGE Style draws a bar at a size; the others scale the game's.
					disable = function()
						return not self:BarsAreMuraHige()
					end
				}
			)
			settings:AddSetting(
				{
					type = LibHarvensAddonSettings.ST_SLIDER,
					label = zo_strformat(GetString(SI_PBSCHC_BAR_HEIGHT), barName),
					tooltip = GetString(SI_PBSCHC_BAR_HEIGHT_TOOLTIP),
					min = self.MIN_BAR_HEIGHT,
					max = self.MAX_BAR_HEIGHT,
					step = 1,
					default = self.GAME_BAR_HEIGHT,
					format = "%d",
					unit = "",
					getFunction = function()
						return select(2, self:BarSize(bar))
					end,
					setFunction = function(value)
						self:SetBarSize(bar, "height", value)
						self:Account().enabled = true
						self:Refresh()
					end,
					disable = function()
						return not self:BarsAreMuraHige()
					end
				}
			)
		end

		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_SLIDER,
				label = zo_strformat(GetString(SI_PBSCHC_SCALE), barName),
				tooltip = GetString(SI_PBSCHC_SCALE_TOOLTIP),
				min = self.MIN_SCALE,
				max = self.MAX_SCALE,
				step = SCALE_STEP,
				default = self.DEFAULT_SCALE,
				format = "%d",
				unit = "%",
				getFunction = function()
					return self:ScalePercent(bar)
				end,
				setFunction = function(value)
					self:SetScalePercent(bar, value)
					self:Account().enabled = true
					self:Refresh()
				end,
				-- A bar drawn at a width and a height has no use for a percentage as well, and
				-- offering both invites the two to fight. The skill bar is always scaled.
				disable = function()
					return not bar.isActionBar and self:BarsAreMuraHige()
				end
			}
		)

		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_BUTTON,
				label = zo_strformat(GetString(SI_PBSCHC_RESET_BAR), barName),
				tooltip = GetString(SI_PBSCHC_RESET_BAR_TOOLTIP),
				buttonText = GetString(SI_PBSCHC_RESET_BUTTON),
				clickHandler = function()
					self:ResetBar(bar)
					self:Refresh()
					-- The rows were built from the old values, so they have to be told to
					-- re-read them or the panel keeps showing what was just discarded.
					if settings.UpdateControls then
						settings:UpdateControls()
					end
				end
			}
		)
	end

	-- ---- The gaps along the skill bar --------------------------------------------------------
	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCHC_SECTION_GAPS))
	AddLabel(settings, LibHarvensAddonSettings, "SI_PBSCHC_GAPS_EXPLANATION")

	local gapRows = {
		{ key = "skill", label = SI_PBSCHC_GAP_SKILL, tooltip = SI_PBSCHC_GAP_SKILL_TOOLTIP },
		{ key = "ultimate", label = SI_PBSCHC_GAP_ULTIMATE, tooltip = SI_PBSCHC_GAP_ULTIMATE_TOOLTIP },
		{ key = "item", label = SI_PBSCHC_GAP_ITEM, tooltip = SI_PBSCHC_GAP_ITEM_TOOLTIP },
	}
	for _, row in ipairs(gapRows) do
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_SLIDER,
				label = GetString(row.label),
				tooltip = GetString(row.tooltip),
				min = self.MIN_GAP,
				max = self.MAX_GAP,
				step = 1,
				default = self:GameGap(row.key),
				format = "%d",
				unit = "",
				getFunction = function()
					return self:Gap(row.key)
				end,
				setFunction = function(value)
					self:SetGap(row.key, value)
					self:Account().enabled = true
					self:Refresh()
				end
			}
		)
	end

	-- ---- The other weapon set ----------------------------------------------------------------
	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCHC_SECTION_BACKBAR))
	AddLabel(settings, LibHarvensAddonSettings, "SI_PBSCHC_BACKBAR_EXPLANATION")

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHC_BACKBAR_ENABLED),
			tooltip = GetString(SI_PBSCHC_BACKBAR_ENABLED_TOOLTIP),
			default = true,
			getFunction = function()
				return self:BackBar().enabled ~= false
			end,
			setFunction = function(value)
				self:BackBar().enabled = value
				self:Account().enabled = true
				self:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHC_BACKBAR_EMPTY),
			tooltip = GetString(SI_PBSCHC_BACKBAR_EMPTY_TOOLTIP),
			default = true,
			getFunction = function()
				return self:BackBar().showEmpty ~= false
			end,
			setFunction = function(value)
				self:BackBar().showEmpty = value
				self:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCHC_BACKBAR_SCALE),
			tooltip = GetString(SI_PBSCHC_BACKBAR_SCALE_TOOLTIP),
			min = self.MIN_SCALE,
			max = self.MAX_SCALE,
			step = SCALE_STEP,
			default = self.DEFAULT_SCALE,
			format = "%d",
			unit = "%",
			getFunction = function()
				return self:BackBarScale()
			end,
			setFunction = function(value)
				self:SetBackBarScale(value)
				self:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCHC_BACKBAR_GAP),
			tooltip = GetString(SI_PBSCHC_BACKBAR_GAP_TOOLTIP),
			min = 0,
			max = 200,
			step = 2,
			default = 4,
			format = "%d",
			unit = "",
			getFunction = function()
				local gap = self:BackBar().gap
				return type(gap) == "number" and gap or 4
			end,
			setFunction = function(value)
				self:BackBar().gap = addon.Round(value)
				self:Refresh()
			end
		}
	)

	-- ---- The text on the icons ---------------------------------------------------------------
	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCHC_SECTION_TEXT))
	AddLabel(settings, LibHarvensAddonSettings, "SI_PBSCHC_TEXT_EXPLANATION")

	local timerModeItems = {}
	local timerModeByKey = {}
	for _, mode in ipairs(self.TIMER_MODES) do
		local item = { name = GetString(_G["SI_PBSCHC_TIMER_MODE_" .. mode:upper()]), data = mode }
		timerModeItems[#timerModeItems + 1] = item
		timerModeByKey[mode] = item
	end

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSCHC_TIMER_MODE),
			tooltip = GetString(SI_PBSCHC_TIMER_MODE_TOOLTIP),
			items = timerModeItems,
			default = timerModeByKey.addon.name,
			getFunction = function()
				local item = timerModeByKey[self:TimerMode()] or timerModeByKey.addon
				return item.name
			end,
			setFunction = function(combobox, name, item)
				self:Text().timerMode = item.data
				self:Refresh()
			end
		}
	)

	-- One slider per bar, for each of the two numbers. The other weapon set's follows this bar
	-- until it is moved, so an install that never touches it keeps one size for both.
	local function AddSizeSlider(which, isBack, label, tooltip, default)
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_SLIDER,
				label = GetString(label),
				tooltip = GetString(tooltip),
				min = self.MIN_TEXT_SIZE,
				max = self.MAX_TEXT_SIZE,
				step = 1,
				default = default,
				format = "%d",
				unit = "",
				getFunction = function()
					return self:TextSize(which, isBack)
				end,
				setFunction = function(value)
					self:SetTextSize(which, value, isBack)
					self:Refresh()
					-- The front bar's slider moves the row's with it while the row has no size
					-- of its own, so the panel has to re-read them.
					if not isBack and not self:TextSizeIsOwn(which) and settings.UpdateControls then
						settings:UpdateControls()
					end
				end
			}
		)
	end

	AddSizeSlider("timer", false, SI_PBSCHC_TIMER_SIZE, SI_PBSCHC_TIMER_SIZE_TOOLTIP, self.DEFAULT_TIMER_SIZE)
	AddSizeSlider("timer", true, SI_PBSCHC_TIMER_SIZE_BACK, SI_PBSCHC_TIMER_SIZE_BACK_TOOLTIP, self.DEFAULT_TIMER_SIZE)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHC_TIMER_DECIMALS),
			tooltip = GetString(SI_PBSCHC_TIMER_DECIMALS_TOOLTIP),
			default = true,
			getFunction = function()
				return self:Text().decimals ~= false
			end,
			setFunction = function(value)
				self:Text().decimals = value
				self:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHC_COUNT_ENABLED),
			tooltip = GetString(SI_PBSCHC_COUNT_ENABLED_TOOLTIP),
			default = true,
			getFunction = function()
				return self:Text().showCounts ~= false
			end,
			setFunction = function(value)
				self:Text().showCounts = value
				self:Refresh()
			end
		}
	)

	AddSizeSlider("count", false, SI_PBSCHC_COUNT_SIZE, SI_PBSCHC_COUNT_SIZE_TOOLTIP, self.DEFAULT_COUNT_SIZE)
	AddSizeSlider("count", true, SI_PBSCHC_COUNT_SIZE_BACK, SI_PBSCHC_COUNT_SIZE_BACK_TOOLTIP, self.DEFAULT_COUNT_SIZE)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_BUTTON,
			label = GetString(SI_PBSCHC_TEXT_SIZE_MATCH),
			tooltip = GetString(SI_PBSCHC_TEXT_SIZE_MATCH_TOOLTIP),
			buttonText = GetString(SI_PBSCHC_RESET_BUTTON),
			clickHandler = function()
				self:ClearBackTextSize("timer")
				self:ClearBackTextSize("count")
				self:Refresh()
				if settings.UpdateControls then
					settings:UpdateControls()
				end
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHC_COUNT_FROM_ONE),
			tooltip = GetString(SI_PBSCHC_COUNT_FROM_ONE_TOOLTIP),
			default = false,
			getFunction = function()
				return self:Text().countFromOne == true
			end,
			setFunction = function(value)
				self:Text().countFromOne = value
				self:Refresh()
			end
		}
	)

	-- ---- The shade over a skill ---------------------------------------------------------------
	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCHC_SECTION_SHADE))
	AddLabel(settings, LibHarvensAddonSettings, "SI_PBSCHC_SHADE_EXPLANATION")

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHC_SHADE_ENABLED),
			tooltip = GetString(SI_PBSCHC_SHADE_ENABLED_TOOLTIP),
			default = true,
			getFunction = function()
				return self:Shade().enabled ~= false
			end,
			setFunction = function(value)
				self:Shade().enabled = value
				self:Account().enabled = true
				self:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCHC_SHADE_DARKNESS),
			tooltip = GetString(SI_PBSCHC_SHADE_DARKNESS_TOOLTIP),
			min = 0,
			max = 100,
			step = 5,
			default = 60,
			format = "%d",
			unit = "%",
			getFunction = function()
				return self:ShadeDarkness()
			end,
			setFunction = function(value)
				self:SetShadeDarkness(value)
				self:Refresh()
			end
		}
	)

	local shadeItems = {}
	local shadeByKey = {}
	for _, direction in ipairs(self.SHADE_DIRECTIONS) do
		local item = { name = GetString(_G["SI_PBSCHC_SHADE_DIRECTION_" .. direction:upper()]), data = direction }
		shadeItems[#shadeItems + 1] = item
		shadeByKey[direction] = item
	end

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSCHC_SHADE_DIRECTION),
			tooltip = GetString(SI_PBSCHC_SHADE_DIRECTION_TOOLTIP),
			items = shadeItems,
			default = shadeByKey.down.name,
			getFunction = function()
				return (shadeByKey[self:ShadeDirection()] or shadeByKey.down).name
			end,
			setFunction = function(combobox, name, item)
				self:Shade().direction = item.data
				self:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHC_SHADE_EDGE),
			tooltip = GetString(SI_PBSCHC_SHADE_EDGE_TOOLTIP),
			default = true,
			getFunction = function()
				return self:Shade().leadingEdge ~= false
			end,
			setFunction = function(value)
				self:Shade().leadingEdge = value
				self:Refresh()
			end
		}
	)

	-- ---- Everything ------------------------------------------------------------------------
	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCHC_SECTION_GENERAL))

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_BUTTON,
			label = GetString(SI_PBSCHC_RESET),
			tooltip = GetString(SI_PBSCHC_RESET_TOOLTIP),
			buttonText = GetString(SI_PBSCHC_RESET_BUTTON),
			clickHandler = function()
				self:ResetAll()
				if settings.UpdateControls then
					settings:UpdateControls()
				end
			end
		}
	)

	-- ---- Measurement -----------------------------------------------------------------------
	-- Two buttons rather than a slash command, because "/pbhud trace on" on a console means the
	-- on-screen keyboard, and the whole point of this is that a measurement should cost the
	-- player nothing. It registers nothing until Start is pressed (Trace.lua).
	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCHC_SECTION_TRACE))
	AddLabel(settings, LibHarvensAddonSettings, "SI_PBSCHC_TRACE_HINT")

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_BUTTON,
			label = GetString(SI_PBSCHC_TRACE_START),
			tooltip = GetString(SI_PBSCHC_TRACE_START_TOOLTIP),
			buttonText = GetString(SI_PBSCHC_TRACE_START_BUTTON),
			clickHandler = function()
				if self.trace then
					self.trace:Command("clear")
					self.trace:Command("on")
				end
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_BUTTON,
			label = GetString(SI_PBSCHC_TRACE_SHOW),
			tooltip = GetString(SI_PBSCHC_TRACE_SHOW_TOOLTIP),
			buttonText = GetString(SI_PBSCHC_TRACE_SHOW_BUTTON),
			clickHandler = function()
				if self.trace then
					self.trace:Command("off")
					self.trace:Command("")
				end
			end
		}
	)

	AddLabel(settings, LibHarvensAddonSettings, "SI_PBSCHC_GAME_SETTINGS_HINT")
end
