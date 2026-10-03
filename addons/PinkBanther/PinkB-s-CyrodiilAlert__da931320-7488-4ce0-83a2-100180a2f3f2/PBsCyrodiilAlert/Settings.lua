-- PBS_CYRODIIL_ALERT is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_CYRODIIL_ALERT then
	return
end

local addon = PBS_CYRODIIL_ALERT

-- The dropdown lists. LibHarvensAddonSettings takes items as { name = <shown>, data = <value> }
-- and hands the whole item back to setFunction, so the stored value never has to be recovered
-- from the label -- which matters here, where the labels are translated and the values are
-- font aliases and hex codes.
--
-- Built once, at panel build time rather than at load, because every name in them comes out of
-- GetString and the language files are what decide what that returns.
local lists = {
	faces = {}, faceByAlias = {},
	styles = {}, styleByToken = {},
	positions = {}, positionByToken = {},
	destinations = {}, destinationByToken = {},
	draws = {}, drawByToken = {},
	colours = {}, colourByHex = {},
}

local function BuildLists()
	for _, face in ipairs(addon.FACES or {}) do
		local entry = { name = GetString(_G[face.label]), data = face.alias }
		lists.faces[#lists.faces + 1] = entry
		lists.faceByAlias[face.alias] = entry
	end
	for _, style in ipairs(addon.STYLES or {}) do
		local entry = { name = GetString(_G[style.label]), data = style.token }
		lists.styles[#lists.styles + 1] = entry
		lists.styleByToken[style.token] = entry
	end
	for _, position in ipairs(addon.POSITIONS or {}) do
		local entry = { name = GetString(_G[position.label]), data = position.token }
		lists.positions[#lists.positions + 1] = entry
		lists.positionByToken[position.token] = entry
	end
	for _, destination in ipairs({
		{ token = "window", label = "SI_PBSCA_LOG_TO_WINDOW" },
		{ token = "chat", label = "SI_PBSCA_LOG_TO_CHAT" },
		{ token = "both", label = "SI_PBSCA_LOG_TO_BOTH" },
	}) do
		local entry = { name = GetString(_G[destination.label]), data = destination.token }
		lists.destinations[#lists.destinations + 1] = entry
		lists.destinationByToken[destination.token] = entry
	end
	for _, draw in ipairs(addon.DRAW_ORDERS or {}) do
		local entry = { name = GetString(_G[draw.label]), data = draw.token }
		lists.draws[#lists.draws + 1] = entry
		lists.drawByToken[draw.token] = entry
	end
	for _, colour in ipairs(addon.PALETTE or {}) do
		local entry = { name = GetString(_G[colour.label]), data = colour.hex }
		lists.colours[#lists.colours + 1] = entry
		lists.colourByHex[colour.hex] = entry
	end
end

-- One row per alert, for one surface. A dropdown handed nil has nothing to select and falls
-- back to showing its first item, which reads as the setting having reset itself -- so a hex
-- set through /pbalert that is not in the palette comes back as the hex itself.
local function AddColourRow(self, settings, LibHarvensAddonSettings, surface, kind)
	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(_G[kind.label]),
			items = lists.colours,
			default = (lists.colourByHex[kind.colour] or {}).name,
			getFunction = function()
				-- Colour() answers with what is really drawn, which while the screen is
				-- following chat is chat's colour. The row showing a stored value nothing is
				-- using would be a row that lies.
				local hex = self:Colour(surface, kind.key)
				local entry = lists.colourByHex[hex]
				return entry and entry.name or hex
			end,
			setFunction = function(combobox, name, item)
				self:SetColour(surface, kind.key, item.data)
				-- A screen colour takes the surfaces apart, and the switch above has to
				-- redraw to say so.
				self:RefreshPanel()
			end
		}
	)
end

-- The panel is the whole configuration surface: a master switch, two numbers, four kinds of
-- holding, three habits. The chat command exists for the console cases the panel is awkward
-- for -- checking what is actually being watched in the middle of a fight -- not the other way
-- round.
--
-- Unlike the guild panel in PB's ChatFilter, nothing here is named after live game data, so it
-- can be built at load. It is still built at EVENT_PLAYER_ACTIVATED, for one reason: the reset
-- button and the sliders read defaults out of the add-on, and having exactly one moment where
-- the panel comes into existence is one fewer order-of-loading question to answer later.

local function AddHeading(settings, LibHarvensAddonSettings, label)
	settings:AddSetting(
		{
			-- ST_SECTION draws a real divider with a heading; older copies of the library only
			-- have ST_LABEL, and the heading text reads as a heading either way.
			type = LibHarvensAddonSettings.ST_SECTION or LibHarvensAddonSettings.ST_LABEL,
			label = label
		}
	)
end

function addon:InitSettings()
	local LibHarvensAddonSettings = LibHarvensAddonSettings
	if not LibHarvensAddonSettings then
		return
	end

	BuildLists()

	local settings = LibHarvensAddonSettings:AddAddon(self.title)
	if not settings then
		return
	end
	self.settingsControls = settings
	settings.allowDefaults = true
	settings.author = self.author
	settings.version = self.version

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = GetString(SI_PBSCA_EXPLANATION)
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCA_ENABLED),
			tooltip = GetString(SI_PBSCA_ENABLED_TOOLTIP),
			default = self.DEFAULTS.enabled,
			getFunction = function()
				return self.sv.enabled
			end,
			setFunction = function(value)
				self:SetEnabled(value)
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCA_INTERVAL),
			tooltip = GetString(SI_PBSCA_INTERVAL_TOOLTIP),
			min = self.MIN_INTERVAL,
			max = self.MAX_INTERVAL,
			step = 1,
			default = self.DEFAULTS.intervalSeconds,
			format = "%d",
			unit = GetString(SI_PBSCA_UNIT_SECONDS),
			getFunction = function()
				return self:IntervalSeconds()
			end,
			setFunction = function(value)
				-- Re-registers the timer with the new period. Dragging the slider therefore
				-- changes the real interval as it moves, which is what makes the number on it
				-- worth trusting.
				self:SetInterval(value)
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCA_REPEAT),
			tooltip = GetString(SI_PBSCA_REPEAT_TOOLTIP),
			min = self.MIN_REPEAT,
			max = self.MAX_REPEAT,
			step = 5,
			default = self.DEFAULTS.repeatSeconds,
			format = "%d",
			unit = GetString(SI_PBSCA_UNIT_SECONDS),
			getFunction = function()
				return self:RepeatSeconds()
			end,
			setFunction = function(value)
				self:SetRepeat(value)
			end
		}
	)

	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCA_SECTION_WHAT))

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = GetString(SI_PBSCA_SECTION_WHAT_NOTE)
		}
	)

	-- One switch per kind, in the order they are worth being woken up for. The key is
	-- captured rather than the loop variable, so each row keeps meaning its own kind.
	for _, group in ipairs(self.GROUPS) do
		local key = group.key
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_CHECKBOX,
				label = GetString(_G[group.label]),
				tooltip = GetString(_G[group.tooltip]),
				default = self.DEFAULTS.groups[key],
				getFunction = function()
					return self:GroupEnabled(key)
				end,
				setFunction = function(value)
					self:SetGroupEnabled(key, value)
				end
			}
		)
	end

	-- The offensive half gets its own section rather than a fifth checkbox among the kinds:
	-- the four above answer "which holdings", this one answers "whose", and the note under it
	-- is the one place the add-on admits what the client will not tell it.
	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCA_SECTION_OFFENSE))

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = GetString(SI_PBSCA_SECTION_OFFENSE_NOTE)
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCA_OFFENSE),
			tooltip = GetString(SI_PBSCA_OFFENSE_TOOLTIP),
			default = self.DEFAULTS.offense,
			getFunction = function()
				return self.sv.offense
			end,
			setFunction = function(value)
				self.sv.offense = value
				self:Forget()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCA_OFFENSE_OURS),
			tooltip = GetString(SI_PBSCA_OFFENSE_OURS_TOOLTIP),
			default = self.DEFAULTS.offenseOursOnly,
			getFunction = function()
				return self.sv.offenseOursOnly
			end,
			setFunction = function(value)
				self.sv.offenseOursOnly = value
				-- Changing what counts as reportable changes what the entries being carried
				-- would have said, so they are dropped and read again.
				self:Forget()
			end
		}
	)

	-- ---- the scrolls -----------------------------------------------------------------
	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCA_SECTION_SCROLLS))

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = GetString(SI_PBSCA_SECTION_SCROLLS_NOTE)
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCA_SCROLLS),
			tooltip = GetString(SI_PBSCA_SCROLLS_TOOLTIP),
			default = self.DEFAULTS.scrolls,
			getFunction = function()
				return self.sv.scrolls
			end,
			setFunction = function(value)
				self.sv.scrolls = value
			end
		}
	)

	-- ---- the second surface ----------------------------------------------------------
	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCA_SECTION_HUD))

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = GetString(SI_PBSCA_SECTION_HUD_NOTE)
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCA_HUD_ENABLED),
			tooltip = GetString(SI_PBSCA_HUD_ENABLED_TOOLTIP),
			default = self.DEFAULTS.hud.enabled,
			getFunction = function()
				return self.sv.hud.enabled
			end,
			setFunction = function(value)
				self.sv.hud.enabled = value
				self.hud:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = GetString(SI_PBSCA_HUD_WHICH)
		}
	)

	-- One switch per alert. The key is captured, not the loop variable.
	for _, kind in ipairs(self.KINDS) do
		local kindKey = kind.key
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_CHECKBOX,
				label = GetString(_G[kind.label]),
				tooltip = GetString(SI_PBSCA_HUD_KIND_TOOLTIP),
				default = self.DEFAULTS.hud.kinds[kindKey],
				getFunction = function()
					-- Reads the stored value, not HudShows: this row is about this alert's own
					-- switch, and it must not read as off just because the display is.
					local kinds = self.sv.hud.kinds
					local value = kinds and kinds[kindKey]
					if value == nil then
						return self.DEFAULTS.hud.kinds[kindKey] or false
					end
					return value
				end,
				setFunction = function(value)
					self:SetHudShows(kindKey, value)
				end
			}
		)
	end

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCA_HUD_SECONDS),
			tooltip = GetString(SI_PBSCA_HUD_SECONDS_TOOLTIP),
			min = self.MIN_HUD_SECONDS,
			max = self.MAX_HUD_SECONDS,
			step = 1,
			default = self.DEFAULTS.hud.seconds,
			format = "%d",
			unit = GetString(SI_PBSCA_UNIT_SECONDS),
			getFunction = function()
				return self.hud:Seconds()
			end,
			setFunction = function(value)
				self.sv.hud.seconds = value
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_BUTTON,
			label = GetString(SI_PBSCA_HUD_TEST),
			tooltip = GetString(SI_PBSCA_HUD_TEST_TOOLTIP),
			buttonText = GetString(SI_PBSCA_HUD_TEST_BUTTON),
			clickHandler = function()
				self:ShowTest()
			end
		}
	)

	-- ---- what it looks like ----------------------------------------------------------
	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCA_SECTION_HUD_LOOK))

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSCA_HUD_FACE),
			tooltip = GetString(SI_PBSCA_HUD_FACE_TOOLTIP),
			items = lists.faces,
			default = (lists.faceByAlias[self.DEFAULTS.hud.face] or {}).name,
			getFunction = function()
				local entry = lists.faceByAlias[self.hud:Face()]
				return entry and entry.name
			end,
			setFunction = function(combobox, name, item)
				self.sv.hud.face = item.data
				self.hud:Refresh()
				-- The summary draws in the same face and outline, so it has to be told too.
				self.board:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCA_HUD_SIZE),
			tooltip = GetString(SI_PBSCA_HUD_SIZE_TOOLTIP),
			min = self.MIN_FONT_SIZE,
			max = self.MAX_FONT_SIZE,
			step = 1,
			default = self.DEFAULTS.hud.size,
			format = "%d",
			unit = "",
			getFunction = function()
				return self.hud:Size()
			end,
			setFunction = function(value)
				self.sv.hud.size = value
				self.hud:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSCA_HUD_STYLE),
			tooltip = GetString(SI_PBSCA_HUD_STYLE_TOOLTIP),
			items = lists.styles,
			default = (lists.styleByToken[self.DEFAULTS.hud.style] or {}).name,
			getFunction = function()
				local entry = lists.styleByToken[self.hud:Style()]
				return entry and entry.name
			end,
			setFunction = function(combobox, name, item)
				self.sv.hud.style = item.data
				self.hud:Refresh()
				-- The summary draws in the same face and outline, so it has to be told too.
				self.board:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSCA_HUD_POSITION),
			tooltip = GetString(SI_PBSCA_HUD_POSITION_TOOLTIP),
			items = lists.positions,
			default = (lists.positionByToken[self.DEFAULTS.hud.position] or {}).name,
			getFunction = function()
				local entry = lists.positionByToken[self.hud:Position()]
				return entry and entry.name
			end,
			setFunction = function(combobox, name, item)
				self.sv.hud.position = item.data
				self.hud:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCA_HUD_OFFSET_X),
			tooltip = GetString(SI_PBSCA_HUD_OFFSET_X_TOOLTIP),
			min = -self.MAX_OFFSET_X,
			max = self.MAX_OFFSET_X,
			step = 5,
			default = self.DEFAULTS.hud.offsetX,
			format = "%d",
			unit = GetString(SI_PBSCA_UNIT_PIXELS),
			getFunction = function()
				return self.hud:OffsetX()
			end,
			setFunction = function(value)
				self.sv.hud.offsetX = value
				self.hud:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCA_HUD_OFFSET_Y),
			tooltip = GetString(SI_PBSCA_HUD_OFFSET_Y_TOOLTIP),
			min = -self.MAX_OFFSET_Y,
			max = self.MAX_OFFSET_Y,
			step = 5,
			default = self.DEFAULTS.hud.offsetY,
			format = "%d",
			unit = GetString(SI_PBSCA_UNIT_PIXELS),
			getFunction = function()
				return self.hud:OffsetY()
			end,
			setFunction = function(value)
				self.sv.hud.offsetY = value
				self.hud:Refresh()
			end
		}
	)

	-- ---- where the add-on speaks -----------------------------------------------------
	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCA_SECTION_LOG))

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = GetString(SI_PBSCA_SECTION_LOG_NOTE)
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSCA_LOG_WHERE),
			tooltip = GetString(SI_PBSCA_LOG_WHERE_TOOLTIP),
			items = lists.destinations,
			default = (lists.destinationByToken[self.DEFAULTS.log.destination] or {}).name,
			getFunction = function()
				local entry = lists.destinationByToken[self.sv.log.destination]
				return entry and entry.name
			end,
			setFunction = function(combobox, name, item)
				self.sv.log.destination = item.data
				self.log:Refresh()
			end
		}
	)

	local function AddLogSlider(label, tooltip, field, minimum, maximum, step, unit)
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_SLIDER,
				label = GetString(_G[label]),
				tooltip = GetString(_G[tooltip]),
				min = minimum,
				max = maximum,
				step = step,
				default = self.DEFAULTS.log[field],
				format = "%d",
				unit = unit,
				getFunction = function()
					-- The stored value, with the shipped one as the floor. This used to build
					-- the name of a reader out of the field name, which is how "lines" went
					-- looking for log:Lines() -- a method that does not exist, because the
					-- window calls it MaxLines. A row that cannot be read takes the whole
					-- settings panel down with it, so there is nothing clever left here.
					local value = self.sv.log[field]
					if value == nil then
						return self.DEFAULTS.log[field]
					end
					return value
				end,
				setFunction = function(value)
					self.sv.log[field] = value
					self.log:Refresh()
				end
			}
		)
	end

	AddLogSlider("SI_PBSCA_LOG_WIDTH", "SI_PBSCA_LOG_WIDTH_TOOLTIP", "width",
		self.MIN_LOG_WIDTH, self.MAX_LOG_WIDTH, 10, GetString(SI_PBSCA_UNIT_PIXELS))
	AddLogSlider("SI_PBSCA_LOG_HEIGHT", "SI_PBSCA_LOG_HEIGHT_TOOLTIP", "height",
		self.MIN_LOG_HEIGHT, self.MAX_LOG_HEIGHT, 10, GetString(SI_PBSCA_UNIT_PIXELS))
	AddLogSlider("SI_PBSCA_LOG_SIZE", "SI_PBSCA_LOG_SIZE_TOOLTIP", "size",
		self.MIN_FONT_SIZE, self.MAX_FONT_SIZE, 1, "")
	AddLogSlider("SI_PBSCA_LOG_LINES", "SI_PBSCA_LOG_LINES_TOOLTIP", "lines",
		self.MIN_LOG_LINES, self.MAX_LOG_LINES, 1, "")
	AddLogSlider("SI_PBSCA_LOG_OPACITY", "SI_PBSCA_LOG_OPACITY_TOOLTIP", "opacity", 0, 100, 5, "%")

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSCA_LOG_POSITION),
			tooltip = GetString(SI_PBSCA_LOG_POSITION_TOOLTIP),
			items = lists.positions,
			default = (lists.positionByToken[self.DEFAULTS.log.position] or {}).name,
			getFunction = function()
				local entry = lists.positionByToken[self.log:Position()]
				return entry and entry.name
			end,
			setFunction = function(combobox, name, item)
				self.sv.log.position = item.data
				self.log:Refresh()
			end
		}
	)

	AddLogSlider("SI_PBSCA_LOG_OFFSET_X", "SI_PBSCA_LOG_OFFSET_X_TOOLTIP", "offsetX",
		-self.MAX_OFFSET_X, self.MAX_OFFSET_X, 5, GetString(SI_PBSCA_UNIT_PIXELS))
	AddLogSlider("SI_PBSCA_LOG_OFFSET_Y", "SI_PBSCA_LOG_OFFSET_Y_TOOLTIP", "offsetY",
		-self.MAX_OFFSET_Y, self.MAX_OFFSET_Y, 5, GetString(SI_PBSCA_UNIT_PIXELS))

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSCA_LOG_DRAW),
			tooltip = GetString(SI_PBSCA_LOG_DRAW_TOOLTIP),
			items = lists.draws,
			default = (lists.drawByToken[self.DEFAULTS.log.draw] or {}).name,
			getFunction = function()
				local entry = lists.drawByToken[self.log:Draw()]
				return entry and entry.name
			end,
			setFunction = function(combobox, name, item)
				self.sv.log.draw = item.data
				self.log:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_BUTTON,
			label = GetString(SI_PBSCA_LOG_CLEAR),
			tooltip = GetString(SI_PBSCA_LOG_CLEAR_TOOLTIP),
			buttonText = GetString(SI_PBSCA_LOG_CLEAR_BUTTON),
			clickHandler = function()
				self.log:Clear()
			end
		}
	)

	-- ---- the overview map -----------------------------------------------------------
	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCA_SECTION_MAP))

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = GetString(SI_PBSCA_SECTION_MAP_NOTE)
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCA_MAP_ENABLED),
			tooltip = GetString(SI_PBSCA_MAP_ENABLED_TOOLTIP),
			default = self.DEFAULTS.map.enabled,
			getFunction = function()
				return self.sv.map.enabled
			end,
			setFunction = function(value)
				self.sv.map.enabled = value
				self.map:Refresh()
			end
		}
	)

	-- Same shape as the output window's sliders: the stored value, the shipped one as the floor,
	-- and nothing derived from the field's name.
	local function AddMapSlider(label, tooltip, field, minimum, maximum, step, unit)
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_SLIDER,
				label = GetString(_G[label]),
				tooltip = GetString(_G[tooltip]),
				min = minimum,
				max = maximum,
				step = step,
				default = self.DEFAULTS.map[field],
				format = "%d",
				unit = unit,
				getFunction = function()
					local value = self.sv.map[field]
					if value == nil then
						return self.DEFAULTS.map[field]
					end
					return value
				end,
				setFunction = function(value)
					self.sv.map[field] = value
					self.map:Refresh()
				end
			}
		)
	end

	AddMapSlider("SI_PBSCA_MAP_SIZE", "SI_PBSCA_MAP_SIZE_TOOLTIP", "size",
		self.MIN_MAP_SIZE, self.MAX_MAP_SIZE, 10, GetString(SI_PBSCA_UNIT_PIXELS))
	AddMapSlider("SI_PBSCA_MAP_PIN", "SI_PBSCA_MAP_PIN_TOOLTIP", "pinSize",
		self.MIN_MAP_PIN, self.MAX_MAP_PIN, 1, GetString(SI_PBSCA_UNIT_PIXELS))
	AddMapSlider("SI_PBSCA_MAP_OPACITY", "SI_PBSCA_MAP_OPACITY_TOOLTIP", "opacity", 10, 100, 5, "%")

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSCA_MAP_POSITION),
			tooltip = GetString(SI_PBSCA_MAP_POSITION_TOOLTIP),
			items = lists.positions,
			default = (lists.positionByToken[self.DEFAULTS.map.position] or {}).name,
			getFunction = function()
				-- The stored value, not the map's reader: the panel must not depend on
				-- Map.lua having loaded.
				local entry = lists.positionByToken[self.sv.map.position]
					or lists.positionByToken[self.DEFAULTS.map.position]
				return entry and entry.name
			end,
			setFunction = function(combobox, name, item)
				self.sv.map.position = item.data
				self.map:Refresh()
			end
		}
	)

	AddMapSlider("SI_PBSCA_MAP_OFFSET_X", "SI_PBSCA_MAP_OFFSET_X_TOOLTIP", "offsetX",
		-self.MAX_OFFSET_X, self.MAX_OFFSET_X, 5, GetString(SI_PBSCA_UNIT_PIXELS))
	AddMapSlider("SI_PBSCA_MAP_OFFSET_Y", "SI_PBSCA_MAP_OFFSET_Y_TOOLTIP", "offsetY",
		-self.MAX_OFFSET_Y, self.MAX_OFFSET_Y, 5, GetString(SI_PBSCA_UNIT_PIXELS))

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSCA_MAP_DRAW),
			tooltip = GetString(SI_PBSCA_MAP_DRAW_TOOLTIP),
			items = lists.draws,
			default = (lists.drawByToken[self.DEFAULTS.map.draw] or {}).name,
			getFunction = function()
				local entry = lists.drawByToken[self.sv.map.draw]
					or lists.drawByToken[self.DEFAULTS.map.draw]
				return entry and entry.name
			end,
			setFunction = function(combobox, name, item)
				self.sv.map.draw = item.data
				self.map:Refresh()
			end
		}
	)

	-- ---- the campaign summary --------------------------------------------------------
	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCA_SECTION_BOARD))

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = GetString(SI_PBSCA_SECTION_BOARD_NOTE)
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCA_BOARD_ENABLED),
			tooltip = GetString(SI_PBSCA_BOARD_ENABLED_TOOLTIP),
			default = self.DEFAULTS.board.enabled,
			getFunction = function()
				return self.sv.board.enabled
			end,
			setFunction = function(value)
				self.sv.board.enabled = value
				self.board:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCA_BOARD_SIZE),
			tooltip = GetString(SI_PBSCA_BOARD_SIZE_TOOLTIP),
			min = self.MIN_FONT_SIZE,
			max = self.MAX_FONT_SIZE,
			step = 1,
			default = self.DEFAULTS.board.size,
			format = "%d",
			unit = "",
			getFunction = function()
				return self.board:Size()
			end,
			setFunction = function(value)
				self.sv.board.size = value
				self.board:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSCA_BOARD_POSITION),
			tooltip = GetString(SI_PBSCA_BOARD_POSITION_TOOLTIP),
			items = lists.positions,
			default = (lists.positionByToken[self.DEFAULTS.board.position] or {}).name,
			getFunction = function()
				local entry = lists.positionByToken[self.board:Position()]
				return entry and entry.name
			end,
			setFunction = function(combobox, name, item)
				self.sv.board.position = item.data
				self.board:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCA_BOARD_OFFSET_X),
			tooltip = GetString(SI_PBSCA_BOARD_OFFSET_X_TOOLTIP),
			min = -self.MAX_OFFSET_X,
			max = self.MAX_OFFSET_X,
			step = 5,
			default = self.DEFAULTS.board.offsetX,
			format = "%d",
			unit = GetString(SI_PBSCA_UNIT_PIXELS),
			getFunction = function()
				return self.board:OffsetX()
			end,
			setFunction = function(value)
				self.sv.board.offsetX = value
				self.board:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCA_BOARD_OFFSET_Y),
			tooltip = GetString(SI_PBSCA_BOARD_OFFSET_Y_TOOLTIP),
			min = -self.MAX_OFFSET_Y,
			max = self.MAX_OFFSET_Y,
			step = 5,
			default = self.DEFAULTS.board.offsetY,
			format = "%d",
			unit = GetString(SI_PBSCA_UNIT_PIXELS),
			getFunction = function()
				return self.board:OffsetY()
			end,
			setFunction = function(value)
				self.sv.board.offsetY = value
				self.board:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSCA_BOARD_DRAW),
			tooltip = GetString(SI_PBSCA_BOARD_DRAW_TOOLTIP),
			items = lists.draws,
			default = (lists.drawByToken[self.DEFAULTS.board.draw] or {}).name,
			getFunction = function()
				local entry = lists.drawByToken[self.board:Draw()]
				return entry and entry.name
			end,
			setFunction = function(combobox, name, item)
				self.sv.board.draw = item.data
				self.board:Refresh()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCA_BOARD_POP_TEXT),
			tooltip = GetString(SI_PBSCA_BOARD_POP_TEXT_TOOLTIP),
			default = self.DEFAULTS.board.populationText,
			getFunction = function()
				return self.sv.board.populationText
			end,
			setFunction = function(value)
				self.sv.board.populationText = value
				self.board:Refresh()
			end
		}
	)

	-- ---- colours ---------------------------------------------------------------------
	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCA_SECTION_COLOURS_CHAT))

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = GetString(SI_PBSCA_COLOURS_NOTE)
		}
	)

	for _, kind in ipairs(self.KINDS) do
		AddColourRow(self, settings, LibHarvensAddonSettings, self.SURFACE_CHAT, kind)
	end

	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCA_SECTION_COLOURS_HUD))

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCA_COLOURS_FOLLOW),
			tooltip = GetString(SI_PBSCA_COLOURS_FOLLOW_TOOLTIP),
			default = self.DEFAULTS.hudFollowsChatColours,
			getFunction = function()
				return self.sv.hudFollowsChatColours
			end,
			setFunction = function(value)
				self.sv.hudFollowsChatColours = value
				self.hud:Refresh()
				-- The rows under this one were showing chat's colours a moment ago, or are
				-- about to start; either way what they display has changed.
				self:RefreshPanel()
			end
		}
	)

	-- The rows below are ignored while the switch above is on. Setting one of them turns that
	-- switch off (SetColour does it), which is why they are left visible and usable rather than
	-- being greyed out: touching one is how you ask for the two surfaces to differ.
	for _, kind in ipairs(self.KINDS) do
		AddColourRow(self, settings, LibHarvensAddonSettings, self.SURFACE_HUD, kind)
	end

	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCA_SECTION_GENERAL))

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCA_ONLY_AVA),
			tooltip = GetString(SI_PBSCA_ONLY_AVA_TOOLTIP),
			default = self.DEFAULTS.onlyInAvA,
			getFunction = function()
				return self.sv.onlyInAvA
			end,
			setFunction = function(value)
				self.sv.onlyInAvA = value
				-- Starts or stops the timer there and then: switching this on while standing
				-- in a city has to stop the watch, not merely stop it finding anything.
				self:ApplyTimer()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCA_ANNOUNCE_EXISTING),
			tooltip = GetString(SI_PBSCA_ANNOUNCE_EXISTING_TOOLTIP),
			default = self.DEFAULTS.announceExisting,
			getFunction = function()
				return self.sv.announceExisting
			end,
			setFunction = function(value)
				self.sv.announceExisting = value
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCA_BANNER),
			tooltip = GetString(SI_PBSCA_BANNER_TOOLTIP),
			default = self.DEFAULTS.banner,
			getFunction = function()
				return self.sv.banner
			end,
			setFunction = function(value)
				self.sv.banner = value
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_BUTTON,
			label = GetString(SI_PBSCA_RESET),
			tooltip = GetString(SI_PBSCA_RESET_TOOLTIP),
			buttonText = GetString(SI_PBSCA_RESET_BUTTON),
			clickHandler = function()
				self:ResetSettings()
				-- The rows were built from the old values, so they have to be told to re-read
				-- them or the panel keeps showing what was just discarded.
				self:RefreshPanel()
			end
		}
	)
end
