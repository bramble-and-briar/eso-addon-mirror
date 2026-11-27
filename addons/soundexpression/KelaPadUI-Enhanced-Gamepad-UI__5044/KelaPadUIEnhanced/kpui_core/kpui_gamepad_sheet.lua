-- KelaPadUI gamepad sheet: a scrolling "character sheet" panel built in Lua,
-- and a screen that pairs it with a list.
--
--   * KelaSheet draws headings, label/value rows, icon rows, bars, and plain
--     text in one or more columns inside a core scroll container, so the right
--     stick scrolls it. Controls are pooled and positioned from the content, so
--     nothing here depends on a fixed layout.
--   * KelaGamepadSheetScreen is a core parametric-list screen: a list of
--     records on the left (quadrant 1) and the sheet for the selected record on
--     the right (quadrants 2-4). L1/R1 switch the sheet's pages from the tab bar.
--
-- A source is a plain table:
--
--   GetPages(source)          { { name, Build } } where `name` is a string,
--                             string id, or function and
--                             Build(source, sheet, record) draws the page
--   GetEntries(source)        array of records, in list order
--   GetEntryInfo(source, record)  name, sub text, icon path for the list row,
--                             and optionally a ZO_ColorDef for the name
--   GetEmptyText(source)      shown on the sheet when there are no records
--
-- Call screen:Refresh() when the records change.

local STYLES = kpuiConst.TextStyles
local COLORS = kpuiConst.Colors

local ROW_HEIGHT = 36
local SUB_ROW_HEIGHT = 28
local SECTION_GAP = 22
local HEADING_HEIGHT = 38
local COLUMN_GAP = 44
local ICON_SIZE = 30
local ICON_GAP = 10
local BAR_HEIGHT = 7
local BAR_GAP = 4
local RIGHT_MARGIN = 24
local BOTTOM_PADDING = 40
local VALUE_MAX_FRACTION = 0.62
local LABEL_GAP = 16
local PARAGRAPH_MAX_LINES = 10
-- A row's label wraps over at most this many lines before it is cut.
local ROW_MAX_LINES = 3
local BAR_TRACK_COLOR = ZO_ColorDef:New(1, 1, 1, 0.14)
local BAR_FILL_COLOR = ZO_ColorDef:New("3DB8C4")
local GRAPH_HEIGHT = 56
local GRAPH_BAR_STEP = 6
local GRAPH_MARK_COLOR = ZO_ColorDef:New("E05555")
-- Labels and second lines are brighter than the shared dim style: on the dark
-- panel the dim grey was hard to read.
local BODY_STYLE = { font = "ZoFontGamepad22", color = COLORS.COLOR_WHITE }
local LABEL_STYLE = { font = "ZoFontGamepad22", color = ZO_ColorDef:New("D8D8D8") }
local HEADING_STYLE = { font = "ZoFontGamepadBold25", color = COLORS.COLOR_GOLD }
local TITLE_STYLE = STYLES.CharacterName
local DIM_VALUE_STYLE = { font = "ZoFontGamepadBold25", color = COLORS.COLOR_GOLD }

-- ---------------------------------------------------------------------------
-- Sheet
-- ---------------------------------------------------------------------------

KelaSheet = ZO_Object:Subclass()

function KelaSheet:New(...)
	local sheet = ZO_Object.New(self)
	sheet:Initialize(...)
	return sheet
end

-- `parent` is the control the sheet fills.
function KelaSheet:Initialize(name, parent)
	self.name = name
	self.parent = parent
	local scroll = CreateControlFromVirtual(name .. "Scroll", parent, "ZO_ScrollContainer_Gamepad")
	scroll:SetAnchorFill(parent)
	self.scroll = scroll

	-- Everything is drawn in the container's own scroll child, which the scroll
	-- extents are measured from. It is sized explicitly in Finish, from what
	-- was drawn, so the content can be taller than the screen.
	local holder = scroll:GetNamedChild("ScrollChild")
	holder:SetResizeToFitDescendents(false)
	holder:SetDimensions(1, 1)
	self.holder = holder

	self.labelPool = ZO_ObjectPool:New(function(pool)
		local label = CreateControl(name .. "Label" .. pool:GetNextControlId(), holder, CT_LABEL)
		label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
		label:SetMaxLineCount(1)
		label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		return label
	end, function(label)
		label:SetHidden(true)
		label:SetText("")
		label:ClearAnchors()
		label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
		label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		label:SetMaxLineCount(1)
		label:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
	end)

	self.texturePool = ZO_ObjectPool:New(function(pool)
		return CreateControl(name .. "Texture" .. pool:GetNextControlId(), holder, CT_TEXTURE)
	end, function(texture)
		texture:SetHidden(true)
		texture:SetTexture("")
		texture:SetColor(1, 1, 1, 1)
		texture:SetAlpha(1)
		texture:ClearAnchors()
	end)

	self.columns = { { x = 0, width = 0, y = 0 } }
	self.column = 1
	self.fullWidth = 0
end

-- The width the content can use: the real one once the control is laid out.
function KelaSheet:GetContentWidth()
	local width = self.scroll:GetWidth()
	if not width or width <= 0 then
		width = ZO_GAMEPAD_QUADRANT_2_3_4_WIDTH - 2 * ZO_GAMEPAD_CONTENT_INSET_X
	end
	return width - RIGHT_MARGIN
end

-- Starts a new page. `weights` gives the columns' relative widths; one column
-- when omitted.
function KelaSheet:Clear(weights)
	weights = weights or { 1 }
	self.labelPool:ReleaseAllObjects()
	self.texturePool:ReleaseAllObjects()
	local width = self:GetContentWidth()
	self.fullWidth = width
	local total = 0
	for _, weight in ipairs(weights) do
		total = total + weight
	end
	local available = width - COLUMN_GAP * (#weights - 1)
	self.columns = {}
	local x = 0
	for index, weight in ipairs(weights) do
		local columnWidth = zo_floor(available * weight / total)
		self.columns[index] = { x = x, width = columnWidth, y = 0 }
		x = x + columnWidth + COLUMN_GAP
	end
	self.column = 1
	self.scroll:ResetToTop()
end

function KelaSheet:SetColumn(index)
	self.column = zo_clamp(index, 1, #self.columns)
end

-- How far down a column has been drawn, for putting the next block where there
-- is the most room.
function KelaSheet:GetColumnHeight(index)
	local column = self.columns[index]
	return column and column.y or 0
end

local function GetLowestY(columns)
	local lowest = 0
	for _, column in ipairs(columns) do
		lowest = zo_max(lowest, column.y)
	end
	return lowest
end

-- ---- controls ----------------------------------------------------------------

function KelaSheet:AcquireLabel(x, y, width, height, style, text, align)
	local label = self.labelPool:AcquireObject()
	label:ClearAnchors()
	label:SetAnchor(TOPLEFT, self.holder, TOPLEFT, x, y)
	label:SetDimensions(width, height)
	KelaApplyTextStyle(label, BODY_STYLE)
	KelaApplyTextStyle(label, style)
	label:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
	label:SetText(text or "")
	label:SetHidden(false)
	return label
end

function KelaSheet:AcquireTexture(x, y, width, height, texture, color)
	local control = self.texturePool:AcquireObject()
	control:ClearAnchors()
	control:SetAnchor(TOPLEFT, self.holder, TOPLEFT, x, y)
	control:SetDimensions(width, height)
	control:SetTexture(texture or "")
	local r, g, b, a = 1, 1, 1, 1
	if color then
		r, g, b, a = color:UnpackRGBA()
	end
	control:SetColor(r, g, b, a)
	control:SetHidden(false)
	return control
end

-- ---- content -----------------------------------------------------------------

-- A full-width title with an optional icon and up to two dimmer lines below,
-- across all columns; the columns continue below it.
function KelaSheet:Title(text, subText, icon, subText2)
	local y = GetLowestY(self.columns)
	local x = 0
	if icon then
		self:AcquireTexture(0, y + 4, 44, 44, icon)
		x = 44 + ICON_GAP
	end
	self:AcquireLabel(x, y, self.fullWidth - x, 52, TITLE_STYLE, text)
	y = y + 52
	if subText and subText ~= "" then
		self:AcquireLabel(x, y, self.fullWidth - x, ROW_HEIGHT, LABEL_STYLE, subText)
		y = y + ROW_HEIGHT
	end
	if subText2 and subText2 ~= "" then
		self:AcquireLabel(x, y, self.fullWidth - x, ROW_HEIGHT, LABEL_STYLE, subText2)
		y = y + ROW_HEIGHT
	end
	y = y + SECTION_GAP
	for _, column in ipairs(self.columns) do
		column.y = y
	end
end

-- A full-width strip of the current filter choices, as "Label: value" in equal
-- parts, with a rule below. `items` is { { label, value }, ... }; the keybinds
-- that change them are on the screen's keybind strip.
function KelaSheet:FilterBar(items)
	local y = GetLowestY(self.columns)
	local gap = COLUMN_GAP
	local width = zo_floor((self.fullWidth - gap * (#items - 1)) / #items)
	for index, item in ipairs(items) do
		local x = (index - 1) * (width + gap)
		local text = LABEL_STYLE.color:Colorize(item.label .. ": ") .. COLORS.COLOR_GOLD:Colorize(item.value)
		self:AcquireLabel(x, y, width, ROW_HEIGHT, BODY_STYLE, text)
	end
	y = y + ROW_HEIGHT
	self:AcquireTexture(0, y, self.fullWidth, 1, nil, COLORS.COLOR_GREY)
	y = y + 1 + SECTION_GAP - 8
	for _, column in ipairs(self.columns) do
		column.y = y
	end
end

function KelaSheet:Space(pixels)
	local column = self.columns[self.column]
	column.y = column.y + pixels
end

-- A section heading with a rule below it.
function KelaSheet:Heading(text)
	local column = self.columns[self.column]
	if column.y > 0 then
		column.y = column.y + SECTION_GAP
	end
	local label = self:AcquireLabel(column.x, column.y, column.width, HEADING_HEIGHT, HEADING_STYLE, text)
	label:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
	self:AcquireTexture(column.x, column.y + HEADING_HEIGHT, column.width, 1, nil, COLORS.COLOR_GREY)
	column.y = column.y + HEADING_HEIGHT + 6
end

-- Lets a label wrap over up to `maxLines` lines and returns the height it
-- needs: one row when it fits, taller when it wraps.
-- How many lines `text` wraps to in `width`, worked out from the width of each
-- word in the label's font. The label's own text height is not used: it is
-- only right after the game lays the label out, which is after this runs, so
-- it read as one line and long notes were cut off. Text without spaces (as in
-- Chinese and Japanese) wraps anywhere, so a word wider than the line counts
-- as several lines.
local function CountWrappedLines(label, text, width)
	local scale = GetUIGlobalScale()
	local function Width(value)
		return label:GetStringWidth(value) / scale
	end
	local lines = 0
	for paragraph in (text .. "\n"):gmatch("(.-)\n") do
		local current = ""
		lines = lines + 1
		for word in paragraph:gmatch("%S+") do
			local candidate = current == "" and word or (current .. " " .. word)
			if current ~= "" and Width(candidate) > width then
				lines = lines + 1
				current = word
			else
				current = candidate
			end
			local currentWidth = Width(current)
			if currentWidth > width then
				lines = lines + zo_ceil(currentWidth / width) - 1
				current = ""
			end
		end
	end
	return zo_max(lines, 1)
end

-- Lets a label wrap over up to `maxLines` lines and returns the height it
-- needs: one row when it fits, taller when it wraps. The label still holds a
-- single line here, so its text height is one line's height.
local function FitLabelHeight(label, maxLines)
	-- The font height is known at once; the text height adds the line spacing.
	local lineHeight = zo_max(label:GetTextHeight(), label:GetFontHeight())
	local text = label:GetText() or ""
	local lines = zo_min(CountWrappedLines(label, text, label:GetWidth()), maxLines)
	label:SetMaxLineCount(maxLines)
	local height = zo_max(lines * lineHeight + (lines > 1 and 4 or 0), ROW_HEIGHT)
	label:SetHeight(height)
	return height
end

-- A line of text that wraps when it is longer than the column. `style`
-- defaults to the body style.
function KelaSheet:Text(text, style)
	local column = self.columns[self.column]
	local label = self:AcquireLabel(column.x, column.y, column.width, ROW_HEIGHT, style, text)
	column.y = column.y + FitLabelHeight(label, PARAGRAPH_MAX_LINES)
end

-- Text that wraps over as many lines as it needs, for notes.
function KelaSheet:Paragraph(text, style)
	local column = self.columns[self.column]
	local label = self:AcquireLabel(column.x, column.y, column.width, ROW_HEIGHT, style, text)
	label:SetVerticalAlignment(TEXT_ALIGN_TOP)
	column.y = column.y + FitLabelHeight(label, PARAGRAPH_MAX_LINES) + 4
end

-- A label on the left and a value on the right. `valueStyle` colours the value.
function KelaSheet:Row(label, value, valueStyle, labelStyle)
	local column = self.columns[self.column]
	local valueLabel = self:AcquireLabel(column.x, column.y, column.width, ROW_HEIGHT, valueStyle or BODY_STYLE, value, TEXT_ALIGN_RIGHT)
	local valueWidth = zo_min(valueLabel:GetTextWidth() + 4, zo_floor(column.width * VALUE_MAX_FRACTION))
	valueLabel:SetWidth(valueWidth)
	valueLabel:ClearAnchors()
	valueLabel:SetAnchor(TOPLEFT, self.holder, TOPLEFT, column.x + column.width - valueWidth, column.y)
	-- A long label (or a long translation) wraps instead of being cut; the
	-- value stays on its first line.
	local labelControl = self:AcquireLabel(column.x, column.y, column.width - valueWidth - LABEL_GAP, ROW_HEIGHT, labelStyle or LABEL_STYLE, label)
	column.y = column.y + FitLabelHeight(labelControl, ROW_MAX_LINES)
end

-- An icon, a name, and an optional dimmer line below it; `rightText` is
-- right-aligned on the name's line.
function KelaSheet:IconRow(icon, text, subText, rightText)
	local column = self.columns[self.column]
	local x = column.x
	if icon and icon ~= "" then
		self:AcquireTexture(x, column.y + zo_floor((ROW_HEIGHT - ICON_SIZE) / 2), ICON_SIZE, ICON_SIZE, icon)
		x = x + ICON_SIZE + ICON_GAP
	end
	local right = column.x + column.width
	if rightText and rightText ~= "" then
		local valueLabel = self:AcquireLabel(x, column.y, right - x, ROW_HEIGHT, BODY_STYLE, rightText, TEXT_ALIGN_RIGHT)
		local valueWidth = zo_min(valueLabel:GetTextWidth() + 4, zo_floor((right - x) * VALUE_MAX_FRACTION))
		valueLabel:SetWidth(valueWidth)
		valueLabel:ClearAnchors()
		valueLabel:SetAnchor(TOPLEFT, self.holder, TOPLEFT, right - valueWidth, column.y)
		right = right - valueWidth - LABEL_GAP
	end
	self:AcquireLabel(x, column.y, right - x, ROW_HEIGHT, BODY_STYLE, text)
	column.y = column.y + ROW_HEIGHT
	if subText and subText ~= "" then
		self:AcquireLabel(x, column.y - 4, column.x + column.width - x, SUB_ROW_HEIGHT, LABEL_STYLE, subText)
		column.y = column.y + SUB_ROW_HEIGHT - 4
	end
end

-- A label and value with a bar below showing `fraction` (0 to 1), an optional
-- icon before the label, and an optional dimmer line under the bar.
function KelaSheet:Bar(label, value, fraction, color, subText, icon)
	local column = self.columns[self.column]
	local x = column.x
	if icon and icon ~= "" then
		self:AcquireTexture(x, column.y + zo_floor((ROW_HEIGHT - ICON_SIZE) / 2), ICON_SIZE, ICON_SIZE, icon)
		x = x + ICON_SIZE + ICON_GAP
	end
	local width = column.x + column.width - x
	local valueLabel = self:AcquireLabel(x, column.y, width, ROW_HEIGHT, BODY_STYLE, value, TEXT_ALIGN_RIGHT)
	local valueWidth = zo_min(valueLabel:GetTextWidth() + 4, zo_floor(width * VALUE_MAX_FRACTION))
	valueLabel:SetWidth(valueWidth)
	valueLabel:ClearAnchors()
	valueLabel:SetAnchor(TOPLEFT, self.holder, TOPLEFT, x + width - valueWidth, column.y)
	self:AcquireLabel(x, column.y, width - valueWidth - LABEL_GAP, ROW_HEIGHT, LABEL_STYLE, label)
	column.y = column.y + ROW_HEIGHT - 4
	self:AcquireTexture(x, column.y, width, BAR_HEIGHT, nil, BAR_TRACK_COLOR)
	local fill = zo_floor(width * zo_clamp(fraction or 0, 0, 1))
	if fill > 0 then
		self:AcquireTexture(x, column.y, fill, BAR_HEIGHT, nil, color or BAR_FILL_COLOR)
	end
	column.y = column.y + BAR_HEIGHT + BAR_GAP
	if subText and subText ~= "" then
		self:AcquireLabel(x, column.y, width, SUB_ROW_HEIGHT, LABEL_STYLE, subText)
		column.y = column.y + SUB_ROW_HEIGHT
	end
	column.y = column.y + 8
end

-- A table: a label column and one right-aligned column per header. `rows` is
-- { { label, value1, value2, ..., styles = { style1, style2, ... } }, ... }.
function KelaSheet:Grid(headers, rows)
	local column = self.columns[self.column]
	local count = #headers
	local valueWidth = zo_min(zo_floor(column.width * 0.26), 170)
	local labelWidth = column.width - count * valueWidth
	for index, header in ipairs(headers) do
		self:AcquireLabel(column.x + labelWidth + (index - 1) * valueWidth, column.y, valueWidth, ROW_HEIGHT, DIM_VALUE_STYLE, header, TEXT_ALIGN_RIGHT)
	end
	self:AcquireTexture(column.x, column.y + ROW_HEIGHT, column.width, 1, nil, COLORS.COLOR_GREY)
	column.y = column.y + ROW_HEIGHT + 4
	for _, row in ipairs(rows) do
		self:AcquireLabel(column.x, column.y, labelWidth - LABEL_GAP, ROW_HEIGHT, LABEL_STYLE, row[1])
		for index = 1, count do
			local style = row.styles and row.styles[index] or BODY_STYLE
			self:AcquireLabel(column.x + labelWidth + (index - 1) * valueWidth, column.y, valueWidth, ROW_HEIGHT, style, row[index + 1] or "", TEXT_ALIGN_RIGHT)
		end
		column.y = column.y + ROW_HEIGHT
	end
end

-- A small column chart under a label row. `values` has `count` numbers per
-- step of time (they are averaged down when there are more steps than the
-- column has room for), `marks` are positions along the time axis from 0 to 1
-- drawn as thin red lines (deaths), `color` colours the columns.
function KelaSheet:Graph(label, valueText, values, count, color, marks)
	self:Row(label, valueText)
	local column = self.columns[self.column]
	local top = column.y + 2
	self:AcquireTexture(column.x, top, column.width, GRAPH_HEIGHT, nil, BAR_TRACK_COLOR)
	if count > 0 then
		local shown = zo_min(count, zo_max(zo_floor(column.width / GRAPH_BAR_STEP), 1))
		local averaged, peak = {}, 0
		for index = 1, shown do
			local first = zo_floor((index - 1) * count / shown) + 1
			local last = zo_max(zo_floor(index * count / shown), first)
			local sum = 0
			for step = first, last do
				sum = sum + (values[step] or 0)
			end
			averaged[index] = sum / (last - first + 1)
			peak = zo_max(peak, averaged[index])
		end
		local slot = column.width / shown
		local barWidth = zo_max(zo_floor(slot) - 1, 1)
		for index = 1, shown do
			local height = peak > 0 and zo_floor(averaged[index] / peak * GRAPH_HEIGHT) or 0
			if height > 0 then
				self:AcquireTexture(column.x + zo_floor((index - 1) * slot), top + GRAPH_HEIGHT - height, barWidth, height, nil, color or BAR_FILL_COLOR)
			end
		end
	end
	for _, mark in ipairs(marks or {}) do
		self:AcquireTexture(column.x + zo_floor(zo_clamp(mark, 0, 1) * (column.width - 2)), top, 2, GRAPH_HEIGHT, nil, GRAPH_MARK_COLOR)
	end
	column.y = top + GRAPH_HEIGHT + 10
end

-- Sizes the scrollable area to what was drawn.
function KelaSheet:Finish()
	self.holder:SetDimensions(self.fullWidth + RIGHT_MARGIN, GetLowestY(self.columns) + BOTTOM_PADDING)
	self.scroll:ResetToTop()
end

function KelaSheet:SetHidden(hidden)
	self.scroll:SetHidden(hidden)
end

-- ---------------------------------------------------------------------------
-- Screen
-- ---------------------------------------------------------------------------

KelaGamepadSheetScreen = ZO_Gamepad_ParametricList_Screen:Subclass()

local function ResolveText(value, ...)
	if type(value) == "function" then
		return value(...)
	elseif type(value) == "number" then
		return GetString(value)
	end
	return value or ""
end

-- `name` prefixes every control and names the screen's own scene, ready to push.
function KelaGamepadSheetScreen:New(name, source)
	local root = CreateTopLevelWindow(name .. "Root")
	root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
	root:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, 0)
	local control = CreateControlFromVirtual(name, root, "ZO_Gamepad_ParametricList_Screen")
	local screen = ZO_Object.New(self)
	screen:Initialize(control, name, root, source)
	return screen
end

function KelaGamepadSheetScreen:Initialize(control, name, root, source)
	self.name = name
	self.root = root
	self.source = source
	self.pageIndex = 1
	self.headerData = { tabBarEntries = {} }
	ZO_Gamepad_ParametricList_Screen.Initialize(self, control, ZO_GAMEPAD_HEADER_TABBAR_CREATE, true)

	-- The sheet fills quadrants 2-4.
	local detail = CreateControl(name .. "Detail", root, CT_CONTROL)
	detail:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, ZO_GAMEPAD_QUADRANT_2_LEFT_OFFSET + ZO_GAMEPAD_CONTENT_INSET_X, ZO_GAMEPAD_QUADRANT_TOP_OFFSET)
	detail:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, ZO_GAMEPAD_QUADRANT_2_LEFT_OFFSET + ZO_GAMEPAD_CONTENT_INSET_X, ZO_GAMEPAD_QUADRANT_BOTTOM_OFFSET)
	detail:SetWidth(ZO_GAMEPAD_QUADRANT_2_3_4_WIDTH - 2 * ZO_GAMEPAD_CONTENT_INSET_X)
	detail:SetHidden(true)
	self.sheet = KelaSheet:New(name .. "Sheet", detail)

	self.fragments = { ZO_FadeSceneFragment:New(control), ZO_FadeSceneFragment:New(detail) }
	for _, group in ipairs({ FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW, FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD_RIGHT }) do
		for _, fragment in pairs(group) do
			self.fragments[#self.fragments + 1] = fragment
		end
	end
	self.fragments[#self.fragments + 1] = GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT
	self.fragments[#self.fragments + 1] = GAMEPAD_NAV_QUADRANT_2_3_4_BACKGROUND_FRAGMENT
	self.fragments[#self.fragments + 1] = MINIMIZE_CHAT_FRAGMENT
	self.fragments[#self.fragments + 1] = GAMEPAD_MENU_SOUND_FRAGMENT

	local scene = ZO_Scene:New(name, SCENE_MANAGER)
	for _, fragment in ipairs(self.fragments) do
		scene:AddFragment(fragment)
	end
	scene:RegisterCallback("StateChange", function(oldState, newState)
		self:OnStateChanged(scene, newState)
	end)
	self.scene = scene
end

function KelaGamepadSheetScreen:SetupList(list)
	list:AddDataTemplate("ZO_GamepadMenuEntryTemplate", ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
end

function KelaGamepadSheetScreen:InitializeKeybindStripDescriptors()
	self.keybindStripDescriptor =
	{
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
	}
	-- A page can offer up to two actions (its filters) on the X and Y buttons:
	-- page.Actions(source, record) returns { { name, callback(screen) }, ... }.
	for index, keybind in ipairs({ "UI_SHORTCUT_SECONDARY", "UI_SHORTCUT_TERTIARY" }) do
		self.keybindStripDescriptor[#self.keybindStripDescriptor + 1] =
		{
			name = function()
				local action = self:GetPageAction(index)
				return action and ResolveText(action.name) or ""
			end,
			keybind = keybind,
			visible = function()
				return self:GetPageAction(index) ~= nil
			end,
			callback = function()
				local action = self:GetPageAction(index)
				if action then
					action.callback(self)
				end
			end,
		}
	end
	-- A source that can delete records offers it on the right stick:
	-- source:GetDeleteLabel() and source:GetDeleteOptions(record), which returns
	-- { { label, text, action }, ... } (what to delete, the question, the deed).
	self.keybindStripDescriptor[#self.keybindStripDescriptor + 1] =
	{
		name = function()
			return ResolveText(self.source.GetDeleteLabel and self.source:GetDeleteLabel() or "", self.source)
		end,
		keybind = "UI_SHORTCUT_RIGHT_STICK",
		visible = function()
			return self.source.GetDeleteOptions ~= nil and self:GetSelectedRecord() ~= nil
		end,
		callback = function()
			self:ShowDeleteOptions()
		end,
	}
	ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, function()
		SCENE_MANAGER:HideCurrentScene()
	end)
end

-- Asks what to delete, then asks again before doing it.
function KelaGamepadSheetScreen:ShowDeleteOptions()
	local record = self:GetSelectedRecord()
	if not record or not self.source.GetDeleteOptions then
		return
	end
	local options = self.source:GetDeleteOptions(record)
	local labels = {}
	for index, option in ipairs(options) do
		labels[index] = option.label
	end
	local title = ResolveText(self.source.GetDeleteLabel and self.source:GetDeleteLabel() or "", self.source)
	KelaShowChoiceDialog(title, labels, nil, function(index)
		local option = options[index]
		-- The choice list is still open; the question is queued behind it.
		KelaShowConfirmDialog(option.text, option.action)
	end)
end

-- The n-th action of the current page for the selected record, or nil.
function KelaGamepadSheetScreen:GetPageAction(index)
	local record = self:GetSelectedRecord()
	local page = self:GetPages()[self.pageIndex]
	if not (record and page and page.Actions) then
		return nil
	end
	local ok, actions = pcall(page.Actions, self.source, record)
	return ok and type(actions) == "table" and actions[index] or nil
end

function KelaGamepadSheetScreen:PerformUpdate()
	self.dirty = false
end

-- ---- pages and records -----------------------------------------------------------

function KelaGamepadSheetScreen:GetPages()
	return self.source:GetPages() or {}
end

function KelaGamepadSheetScreen:GetSelectedRecord()
	local data = self:GetMainList():GetTargetData()
	return data and data.record
end

function KelaGamepadSheetScreen:RefreshTabs()
	local entries = {}
	for index, page in ipairs(self:GetPages()) do
		entries[index] =
		{
			text = ResolveText(page.name, self.source),
			callback = function()
				self:SelectPage(index)
			end,
		}
	end
	self.headerData.tabBarEntries = entries
	ZO_GamepadGenericHeader_Refresh(self.header, self.headerData, true)
	if entries[self.pageIndex] then
		ZO_GamepadGenericHeader_SetActiveTabIndex(self.header, self.pageIndex, nil, true)
	end
end

function KelaGamepadSheetScreen:SelectPage(index)
	if index ~= self.pageIndex then
		self.pageIndex = index
		self:Rerender()
	end
end

-- Redraws the sheet and the keybind labels, after a filter changed.
function KelaGamepadSheetScreen:Rerender()
	self:RenderSheet()
	self:RefreshKeybinds()
end

-- Draws the selected record on the current page.
function KelaGamepadSheetScreen:RenderSheet()
	local sheet = self.sheet
	local record = self:GetSelectedRecord()
	sheet:Clear()
	if record == nil then
		sheet:Text(ResolveText(self.source.GetEmptyText and self.source:GetEmptyText() or "", self.source), LABEL_STYLE)
	else
		local page = self:GetPages()[self.pageIndex]
		if page then
			local ok, err = pcall(page.Build, self.source, sheet, record)
			if not ok and KelaPadUI.log then
				KelaPadUI.log:Warn("Sheet page failed: %s", tostring(err))
			end
		end
	end
	sheet:Finish()
end

function KelaGamepadSheetScreen:OnTargetChanged()
	self:RenderSheet()
	self:RefreshKeybinds()
end

function KelaGamepadSheetScreen:RefreshList()
	local list = self:GetMainList()
	list:Clear()
	for _, record in ipairs(self.source:GetEntries() or {}) do
		local name, subText, icon, nameColor = self.source:GetEntryInfo(record)
		local data = ZO_GamepadEntryData:New(name, icon)
		data.record = record
		-- White rather than the default grey, so the list stays readable,
		-- unless the source colours its records by kind.
		nameColor = nameColor or COLORS.COLOR_WHITE
		data:SetNameColors(nameColor, nameColor)
		data:SetSubLabelColors(COLORS.COLOR_WHITE, COLORS.COLOR_LIGHT_GREY)
		if subText and subText ~= "" then
			data:AddSubLabel(subText)
		end
		list:AddEntry("ZO_GamepadMenuEntryTemplate", data)
	end
	list:Commit()
	-- An empty list selects nothing, so nothing tells the sheet.
	if list:GetTargetData() == nil then
		self:RenderSheet()
	end
end

-- Called when the source's records changed.
function KelaGamepadSheetScreen:Refresh()
	if self:IsShowing() then
		self:RefreshList()
	end
end

-- ---- lifecycle -------------------------------------------------------------------

function KelaGamepadSheetScreen:OnShowing()
	self:RefreshTabs()
	ZO_GamepadGenericHeader_Activate(self.header)
	self:RefreshList()
end

function KelaGamepadSheetScreen:OnHiding()
	ZO_GamepadGenericHeader_Deactivate(self.header)
end
