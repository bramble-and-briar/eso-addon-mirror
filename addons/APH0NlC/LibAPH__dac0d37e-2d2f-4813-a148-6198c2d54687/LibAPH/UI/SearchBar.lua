--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH
local THEME = LibAPH.THEME

local DEFAULT_WIDTH = 460
local BAR_HEIGHT = 34
local ROW_HEIGHT = 28
local HEADER_HEIGHT = 22
local FOOTER_HEIGHT = 32
local DEFAULT_ROWS = 8
local DEFAULT_EXPANDED_ROWS = 12
local DEFAULT_VISIBLE_LINES = 14
local DEFAULT_RECENT = 5
local DEFAULT_GAMEPAD_ROWS = 20
local SUGGEST_DELAY_MS = 150
local suggest_count = 0
local BAR_DRAW_LEVEL = 10
local EDGE_INSET = 8
local CHEVRON_SIZE = 16
local CHEVRON_HIT = 24
local MAX_WIDTH_PCT = 0.6
local TOP_OFFSET_PCT = 0.22
local SETTLE_MS = 50
local DEFAULT_OPACITY = 0.3
local UNSET = -1
local HIGHLIGHT_TEXT = { 1, 1, 1, 1 }
local MIN_SUB_WIDTH = 40
local CHEVRON_TEXTURE = "EsoUI/Art/Buttons/scrollbox_downArrow_up.dds"
local ARROW_TEXTURE = "EsoUI/Art/Buttons/rightarrow_up.dds"
local CHECK_INSET = 34
local ARROW_ROOM = 26
local CLEAR_TEXTURE = "EsoUI/Art/Inventory/inventory_tabIcon_trash_up.dds"
local CLEAR_TEXTURE_OVER = "EsoUI/Art/Inventory/inventory_tabIcon_trash_over.dds"
local CLEAR_SIZE = 22

local function DefaultRowText(entry)
	local where = entry.where or entry.scope or ""
	return string.format("%s  |c888888%s|r", tostring(entry.label or entry.text or ""), where)
end

local function DefaultGroup(entry)
	return entry.scope
end

local function Paint(control, color)
	control:SetColor(color[1], color[2], color[3], color[4] or 1)
end

local function TextWidth(label, text)
	return label:GetStringWidth(text) / GetUIGlobalScale()
end

function LibAPH.CreateSearchBar(opts)
	assert(type(opts) == "table" and type(opts.name) == "string", "CreateSearchBar needs opts.name")
	assert(type(opts.search) == "function", "CreateSearchBar needs opts.search(text, scope)")

	local name = opts.name
	local base_width = opts.width or DEFAULT_WIDTH
	local width = base_width
	local max_rows = opts.maxRows or DEFAULT_ROWS
	local expanded_rows = opts.expandedRows or DEFAULT_EXPANDED_ROWS
	local visible_lines = opts.visibleLines or DEFAULT_VISIBLE_LINES
	local gamepad_rows = opts.gamepadMaxRows or DEFAULT_GAMEPAD_ROWS
	local search_limit = math.max(max_rows, expanded_rows, gamepad_rows)
	local gamepad_text = opts.rowText or DefaultRowText
	local group_of = opts.groupBy or DefaultGroup
	local placeholder = opts.placeholder or "Search"

	local sb = { scope_picker_open = false, flyout_open = false }
	local suggest_token = 0
	local scope_index = 1
	local entered_ui_mode = false
	local expanded = false
	local query = ""
	local shown = {}
	local lines = {}
	local offset = 0
	local highlight = 0
	local rows = {}
	local flyout_row, flyout_key
	local bar, backdrop, edit, scope_label, chevron, chevron_icon, list, footer, footer_hints, measure_main, measure_small

	local function Store()
		local store = opts.store
		if type(store) == "function" then store = store() end
		return type(store) == "table" and store or nil
	end

	local function Scopes()
		local scopes = opts.scopes and opts.scopes()
		if type(scopes) ~= "table" or #scopes == 0 then return { opts.allScope or "All" } end
		return scopes
	end

	local function ScopeText(scope)
		if opts.scopeLabel then return opts.scopeLabel(scope) end
		return scope
	end

	local function UseGamepad()
		if opts.useGamepad then return opts.useGamepad() and true or false end
		return IsInGamepadPreferredMode() and true or false
	end

	function sb:GetControl() return bar end
	function sb:GetEdit() return edit end
	function sb:GetQuery() return query end
	function sb:GetSuggestions() return shown end
	function sb:GetLines() return lines end
	function sb:GetHighlight() return highlight end
	function sb:IsExpanded() return expanded end
	function sb:IsShown() return bar ~= nil and not bar:IsHidden() end

	function sb:GetScope()
		local scopes = Scopes()
		return scopes[scope_index] or opts.allScope or scopes[1]
	end

	local function CurrentText()
		return edit and edit:GetText() or query
	end

	function sb:CycleScope(direction)
		local scopes = Scopes()
		scope_index = scope_index + (direction or 1)
		if scope_index < 1 then scope_index = #scopes elseif scope_index > #scopes then scope_index = 1 end
		if scope_label then scope_label:SetText(ScopeText(self:GetScope())) end
		self:RunSearch(CurrentText())
		return self:GetScope()
	end

	function sb:SetScope(scope)
		for index, candidate in ipairs(Scopes()) do
			if candidate == scope then
				scope_index = index
				if scope_label then scope_label:SetText(ScopeText(scope)) end
				self:RunSearch(CurrentText())
				return true
			end
		end
		return false
	end

	function sb:RefreshScopes()
		if scope_index > #Scopes() then scope_index = 1 end
		if scope_label then scope_label:SetText(ScopeText(self:GetScope())) end
		if self:IsShown() then self:RunSearch(CurrentText()) end
		return self:GetScope()
	end

	local function BuildLines()
		lines = {}
		if not expanded then
			for index, entry in ipairs(shown) do lines[#lines + 1] = { entry = entry, item = index } end
			return
		end
		local last_group
		for index, entry in ipairs(shown) do
			local group = entry.libaph_group or group_of(entry)
			if group and group ~= last_group then
				lines[#lines + 1] = { header = ScopeText(group), clear = entry.libaph_recent == true and opts.clearRecent ~= nil }
				last_group = group
			end
			lines[#lines + 1] = { entry = entry, item = index }
		end
	end

	local function LineOfItem(item)
		for index, line in ipairs(lines) do
			if line.item == item then return index end
		end
		return 0
	end

	local function KeepHighlightVisible()
		local count = math.min(#lines, visible_lines)
		local at = LineOfItem(highlight)
		if at == 0 then
			offset = 0
			return
		end
		if at == 2 and lines[1].header then at = 1 end
		if at <= offset then offset = at - 1 end
		if at > offset + count then offset = at - count end
		offset = zo_clamp(offset, 0, #lines - count)
	end

	local function RowParts(entry)
		local left = entry.icon and 36 or 10
		if entry.libaph_checked ~= nil then left = CHECK_INSET end
		local hint = entry.libaph_hint or (opts.rowHint and opts.rowHint(entry)) or nil
		if hint == "" then hint = nil end
		if opts.rowText then return left, opts.rowText(entry), nil, hint end
		local raw_sub = entry.libaph_sub or entry.where or entry.scope
		local sub = raw_sub and ScopeText(raw_sub)
		if expanded and raw_sub == group_of(entry) then sub = nil end
		if sub == "" then sub = nil end
		return left, tostring(entry.label or entry.text or ""), sub, hint
	end

	local function NaturalWidth(entry)
		local left, text, sub, hint = RowParts(entry)
		local total = EDGE_INSET * 2 + left + TextWidth(measure_main, text) + 2 + 10
		if sub then total = total + 8 + TextWidth(measure_small, sub) + 2 end
		if hint then total = total + 12 + TextWidth(measure_small, hint) end
		if entry.libaph_submenu then total = total + ARROW_ROOM - 10 end
		return total
	end

	local function SetWidth(new_width)
		if new_width == width then return end
		width = new_width
		bar:SetWidth(width)
		list:SetWidth(width)
		for _, row in ipairs(rows) do row:SetWidth(width - EDGE_INSET * 2) end
	end

	local function FitWidth()
		if not bar then return end
		local needed = base_width
		for _, line in ipairs(lines) do
			if line.entry then needed = math.max(needed, NaturalWidth(line.entry)) end
		end
		local max_width = math.max(base_width, opts.maxWidth or math.floor(GuiRoot:GetWidth() * MAX_WIDTH_PCT))
		SetWidth(math.ceil(math.min(needed, max_width)))
	end

	function sb:GetWidth() return width end

	local function PaintRow(row, line, item_highlighted)
		row.line = line
		row.entry = line.entry
		if line.header then
			row:SetHeight(HEADER_HEIGHT)
			row.bg:SetHidden(false)
			Paint(row.bg, THEME.SECTION_BLUE)
			row.icon:SetHidden(true)
			row.sub:SetHidden(true)
			row.hint:SetHidden(true)
			row.check:SetHidden(true)
			row.arrow:SetHidden(true)
			row.label:ClearAnchors()
			row.label:SetAnchor(LEFT, row, LEFT, 10, 2)
			row.label:SetAnchor(RIGHT, row, RIGHT, -10, 2)
			row.label:SetFont("ZoFontGameSmall")
			row.label:SetText(zo_strupper(LibAPH.StripColors(tostring(line.header))))
			Paint(row.label, THEME.ACCENT)
			row.clear:SetHidden(not line.clear)
			return
		end
		row.clear:SetHidden(true)

		local entry = line.entry
		row:SetHeight(ROW_HEIGHT)
		row.label:SetFont("ZoFontGame")
		row.bg:SetHidden(not item_highlighted)
		Paint(row.bg, THEME.PICK)
		Paint(row.label, item_highlighted and HIGHLIGHT_TEXT or THEME.TEXT)

		local left, text, sub, hint = RowParts(entry)
		if entry.icon then
			row.icon:SetHidden(false)
			row.icon:SetTexture(entry.icon)
			Paint(row.icon, item_highlighted and HIGHLIGHT_TEXT or THEME.MUTED)
		else
			row.icon:SetHidden(true)
		end

		local checkbox = entry.libaph_checked ~= nil
		row.check:SetHidden(not checkbox)
		if checkbox then ZO_CheckButton_SetCheckState(row.check, entry.libaph_checked == true) end

		local right = -10
		row.arrow:SetHidden(not entry.libaph_submenu)
		if entry.libaph_submenu then
			Paint(row.arrow, item_highlighted and HIGHLIGHT_TEXT or THEME.MUTED)
			right = -ARROW_ROOM
		end
		if hint then
			row.hint:SetHidden(false)
			row.hint:SetText(hint)
			Paint(row.hint, entry.libaph_hint_color or THEME.MUTED)
			row.hint:ClearAnchors()
			row.hint:SetAnchor(RIGHT, row, RIGHT, right, 0)
			right = right - TextWidth(row.hint, hint) - 12
		else
			row.hint:SetHidden(true)
		end

		row.label:ClearAnchors()
		row.label:SetAnchor(LEFT, row, LEFT, left, 0)
		row.label:SetText(text)
		local room = width - EDGE_INSET * 2 - left + right
		local label_width = math.min(TextWidth(row.label, text) + 2, room)
		if sub and room - label_width >= MIN_SUB_WIDTH then
			row.label:SetWidth(label_width)
			row.sub:SetHidden(false)
			row.sub:SetText(sub)
			Paint(row.sub, THEME.MUTED)
			row.sub:ClearAnchors()
			row.sub:SetAnchor(LEFT, row.label, RIGHT, 8, 1)
			row.sub:SetAnchor(RIGHT, row, RIGHT, right, 1)
		else
			row.sub:SetHidden(true)
			row.label:SetAnchor(RIGHT, row, RIGHT, right, 0)
		end
	end

	local AcquireRow

	local function PaintRows()
		if not list then return end
		FitWidth()
		local count = math.min(#lines, visible_lines)
		local height = 0
		for index = 1, math.max(count, #rows) do
			local line = lines[offset + index]
			if index <= count and line then
				local row = AcquireRow(index)
				row:SetHidden(false)
				PaintRow(row, line, line.item ~= nil and line.item == highlight)
				height = height + (line.header and HEADER_HEIGHT or ROW_HEIGHT)
			elseif rows[index] then
				rows[index]:SetHidden(true)
				rows[index].entry = nil
				rows[index].line = nil
			end
		end

		local footer_height = expanded and FOOTER_HEIGHT or 0
		if footer then footer:SetHidden(not expanded) end
		list:SetHidden(count == 0 and not expanded)
		list:SetHeight(height + EDGE_INSET * 2 + footer_height)
	end

	function sb:Refresh()
		if not list then return false end
		PaintRows()
		return true
	end

	local function GroupInOrder(entries)
		local order, buckets = {}, {}
		for _, entry in ipairs(entries) do
			local group = entry.libaph_group or group_of(entry) or ""
			if not buckets[group] then
				buckets[group] = {}
				order[#order + 1] = group
			end
			local bucket = buckets[group]
			bucket[#bucket + 1] = entry
		end
		local out = {}
		for _, group in ipairs(order) do
			for _, entry in ipairs(buckets[group]) do out[#out + 1] = entry end
		end
		return out
	end

	local function RowShowing(key)
		for _, row in ipairs(rows) do
			if not row:IsHidden() and row.entry and row.entry.libaph_flyout_key == key then return row end
		end
		return nil
	end

	function sb:CloseFlyout()
		if not self.flyout_open then return false end
		self.flyout_open = false
		flyout_row, flyout_key = nil, nil
		LibAPH.CloseContextMenu()
		return true
	end

	function sb:OpenFlyout(row)
		local entry = row and row.entry
		if not entry or not entry.libaph_submenu then return false end
		if self.flyout_open and flyout_row == row and flyout_key == entry.libaph_flyout_key then return true end
		local build = entry.libaph_submenu
		LibAPH.ShowContextMenu(row, build(), {
			anchorSide = "right",
			clickThrough = true,
			rebuild = build,
			onHide = function()
				sb.flyout_open = false
				flyout_row, flyout_key = nil, nil
			end,
		})
		self.flyout_open = true
		flyout_row, flyout_key = row, entry.libaph_flyout_key
		return true
	end

	function sb:GetFlyoutRow() return flyout_row end

	local BrowseEntries

	function sb:ClearRecent()
		if not opts.clearRecent then return false end
		opts.clearRecent()
		ZO_Tooltips_HideTextTooltip()
		highlight = 1
		offset = 0
		self:RefreshInPlace()
		return true
	end

	function sb:RefreshInPlace()
		if scope_index > #Scopes() then scope_index = 1 end
		if scope_label then scope_label:SetText(ScopeText(self:GetScope())) end
		if not expanded or query ~= "" then return self:RunSearch(CurrentText()) end

		local kept = shown[highlight]
		local row_at = LineOfItem(highlight) - offset
		shown = BrowseEntries()
		BuildLines()
		for index, candidate in ipairs(shown) do
			if kept and candidate.libaph_group == kept.libaph_group and candidate.label == kept.label then
				highlight = index
				local count = math.min(#lines, visible_lines)
				offset = zo_clamp(LineOfItem(index) - row_at, 0, #lines - count)
				break
			end
		end
		PaintRows()
		return shown
	end

	function sb:GroupToggleEntry(group, title, listed)
		local toggles = opts.scopeToggles
		local key = "group:" .. tostring(group.title)
		local on_count = 0
		for _, scope in ipairs(group.scopes or {}) do
			if listed[scope] and toggles.isOn(scope) then on_count = on_count + 1 end
		end
		return {
			label = group.title,
			libaph_group = title,
			libaph_flyout_key = key,
			libaph_hint = string.format("(%d on)", on_count),
			libaph_hint_color = on_count > 0 and THEME.GREEN or THEME.MUTED,
			libaph_keep_place = true,
			libaph_submenu = function()
				local entries = {}
				for _, scope in ipairs(group.scopes or {}) do
					if listed[scope] then
						entries[#entries + 1] = {
							text = ScopeText(scope),
							checkbox = true,
							checked = toggles.isOn(scope) and true or false,
							onToggle = function(now)
								toggles.set(scope, now)
								sb:RefreshInPlace()
							end,
						}
					end
				end
				return entries
			end,
			libaph_action = function()
				local row = RowShowing(key)
				if row then sb:OpenFlyout(row) end
			end,
		}
	end

	BrowseEntries = function()
		local out = {}
		local recent = opts.recent and opts.recent() or nil
		if type(recent) == "table" then
			for index = 1, math.min(#recent, opts.recentRows or DEFAULT_RECENT) do
				local text = recent[index]
				out[#out + 1] = {
					label = text,
					libaph_group = opts.recentTitle or "Recent",
					libaph_recent = true,
					libaph_action = function()
						if edit then edit:SetText(text) end
					end,
				}
			end
		end
		out[#out + 1] = {
			label = opts.activeScopeLabel or LibAPH.L("ACTIVE_SCOPE"),
			libaph_group = opts.scopesTitle or LibAPH.L("SCOPES"),
			libaph_flyout_key = "scopes",
			libaph_hint = sb:GetScope(),
			libaph_hint_color = THEME.GREEN,
			libaph_keep_place = true,
			libaph_submenu = function() return sb:ScopeMenuEntries() end,
			libaph_action = function()
				local row = RowShowing("scopes")
				if row then sb:OpenFlyout(row) end
			end,
		}
		local toggles = opts.scopeToggles
		if toggles then
			local title = toggles.title or LibAPH.L("TURN_SCOPES_ON_OR_OFF")
			local listed, group_of_scope, anchor_of = {}, {}, {}
			for _, scope in ipairs(toggles.all()) do listed[scope] = true end
			for _, group in ipairs(toggles.groups and toggles.groups() or {}) do
				for _, scope in ipairs(group.scopes or {}) do
					if listed[scope] then
						group_of_scope[scope] = group
						anchor_of[group] = anchor_of[group] or scope
					end
				end
			end
			for _, scope in ipairs(toggles.all()) do
				local group = group_of_scope[scope]
				if group then
					if anchor_of[group] == scope then out[#out + 1] = sb:GroupToggleEntry(group, title, listed) end
				else
					local on = toggles.isOn(scope) and true or false
					out[#out + 1] = {
						label = ScopeText(scope),
						libaph_group = title,
						libaph_checked = on,
						libaph_keep_place = true,
						libaph_action = function()
							toggles.set(scope, not on)
							sb:RefreshScopes()
						end,
					}
				end
			end
		end
		return out
	end

	function sb:SetSuggestions(results)
		self:CloseFlyout()
		shown = {}
		if expanded and query == "" and #results == 0 and opts.browse ~= false then
			shown = BrowseEntries()
		else
			local cap = expanded and expanded_rows or max_rows
			for index = 1, math.min(#results, cap) do shown[index] = results[index] end
			if expanded then shown = GroupInOrder(shown) end
		end
		highlight = #shown > 0 and 1 or 0
		offset = 0
		BuildLines()
		PaintRows()
		return shown
	end

	function sb:MoveHighlight(direction)
		local count = #shown
		if count == 0 then return false end
		highlight = highlight + direction
		if highlight < 1 then highlight = count elseif highlight > count then highlight = 1 end
		KeepHighlightVisible()
		PaintRows()
		return true
	end

	function sb:Scroll(delta)
		self:CloseFlyout()
		local count = math.min(#lines, visible_lines)
		offset = zo_clamp(offset - delta, 0, #lines - count)
		PaintRows()
		return offset
	end

	function sb:Search(text)
		query = text or ""
		if opts.onQuery then opts.onQuery(query) end
		local results = opts.search(query, self:GetScope())
		return type(results) == "table" and results or {}
	end

	function sb:SearchThen(text, done)
		if not opts.searchAsync then return done(self:Search(text)) end
		query = text or ""
		if opts.onQuery then opts.onQuery(query) end
		return opts.searchAsync(query, self:GetScope(), search_limit, function(results)
			done(type(results) == "table" and results or {})
		end)
	end

	function sb:RunSearch(text)
		local results = {}
		self:SearchThen(text, function(found)
			results = found
			self:SetSuggestions(found)
		end)
		return results
	end

	local function Accept(entry)
		if entry.libaph_action then
			local first = offset
			entry.libaph_action(entry)
			if entry.libaph_keep_place then
				for index, candidate in ipairs(shown) do
					if candidate.libaph_group == entry.libaph_group and candidate.label == entry.label then
						highlight, offset = index, first
						KeepHighlightVisible()
						PaintRows()
						break
					end
				end
			end
			if edit then edit:TakeFocus() end
			return true
		end
		sb:Hide(true)
		if opts.onAccept then return opts.onAccept(entry, query) end
		return true
	end

	function sb:AcceptHighlight()
		local entry = shown[highlight]
		if not entry then return false end
		return Accept(entry)
	end

	function sb:SetExpanded(on)
		self:CloseFlyout()
		expanded = on and true or false
		if expanded and footer_hints then footer_hints:Refresh() end
		if chevron then chevron_icon:SetTextureRotation(expanded and math.pi or 0) end
		self:RunSearch(CurrentText())
		if edit then edit:TakeFocus() end
		return expanded
	end

	function sb:ToggleExpanded()
		return self:SetExpanded(not expanded)
	end

	function sb:PickScope(scope)
		for index, candidate in ipairs(Scopes()) do
			if candidate == scope then
				scope_index = index
				if scope_label then scope_label:SetText(ScopeText(scope)) end
				self:RefreshInPlace()
				return true
			end
		end
		return false
	end

	function sb:ScopeMenuEntries()
		local current = self:GetScope()
		local function ScopeEntry(scope)
			return { text = ScopeText(scope), selected = scope == current, onClick = function() sb:PickScope(scope) end }
		end

		local toggles = opts.scopeToggles
		local groups = toggles and toggles.groups and toggles.groups() or {}
		local enabled, group_of_scope, anchor_of = {}, {}, {}
		for _, scope in ipairs(Scopes()) do enabled[scope] = true end
		for _, group in ipairs(groups) do
			for _, scope in ipairs(group.scopes or {}) do
				if enabled[scope] then
					group_of_scope[scope] = group
					anchor_of[group] = anchor_of[group] or scope
				end
			end
		end

		local entries = {}
		for _, scope in ipairs(Scopes()) do
			local group = group_of_scope[scope]
			if not group then
				entries[#entries + 1] = ScopeEntry(scope)
			elseif anchor_of[group] == scope then
				local members, holds = {}, false
				for _, member in ipairs(group.scopes or {}) do
					if enabled[member] then
						members[#members + 1] = member
						if member == current then holds = true end
					end
				end
				if #members == 1 then
					entries[#entries + 1] = ScopeEntry(members[1])
				else
					entries[#entries + 1] = {
						text = group.title,
						color = holds and THEME.GREEN or nil,
						submenu = function()
							local out = {}
							for _, member in ipairs(members) do out[#out + 1] = ScopeEntry(member) end
							return out
						end,
					}
				end
			end
		end
		return entries
	end

	function sb:ShowScopePicker()
		if UseGamepad() then return self:ShowGamepadScopePicker() end
		if not scope_label then return false end
		LibAPH.ShowContextMenu(scope_label, self:ScopeMenuEntries(), {
			onHide = function()
				sb.scope_picker_open = false
				if edit and sb:IsShown() then edit:TakeFocus() end
			end,
		})
		self.scope_picker_open = true
		return true
	end

	AcquireRow = function(index)
		local row = rows[index]
		if row then return row end

		row = WINDOW_MANAGER:CreateControl(name .. "Row" .. index, list, CT_CONTROL)
		row:SetDimensions(width - EDGE_INSET * 2, ROW_HEIGHT)
		row:SetMouseEnabled(true)
		if index == 1 then
			row:SetAnchor(TOPLEFT, list, TOPLEFT, EDGE_INSET, EDGE_INSET)
		else
			row:SetAnchor(TOPLEFT, AcquireRow(index - 1), BOTTOMLEFT, 0, 0)
		end

		row.bg = WINDOW_MANAGER:CreateControl(name .. "RowBg" .. index, row, CT_TEXTURE)
		row.bg:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 1)
		row.bg:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, 0, -1)
		Paint(row.bg, THEME.HOVER)
		row.bg:SetHidden(true)

		row.icon = WINDOW_MANAGER:CreateControl(name .. "RowIcon" .. index, row, CT_TEXTURE)
		row.icon:SetDimensions(18, 18)
		row.icon:SetAnchor(LEFT, row, LEFT, 10, 0)
		row.icon:SetHidden(true)

		row.label = WINDOW_MANAGER:CreateControl(name .. "RowLabel" .. index, row, CT_LABEL)
		row.label:SetFont("ZoFontGame")
		row.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		row.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
		row.label:SetMaxLineCount(1)
		row.label:SetAnchor(LEFT, row, LEFT, 10, 0)
		row.label:SetAnchor(RIGHT, row, RIGHT, -10, 0)

		row.sub = WINDOW_MANAGER:CreateControl(name .. "RowSub" .. index, row, CT_LABEL)
		row.sub:SetFont("ZoFontGameSmall")
		row.sub:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		row.sub:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
		row.sub:SetMaxLineCount(1)
		row.sub:SetHidden(true)

		row.hint = WINDOW_MANAGER:CreateControl(name .. "RowHint" .. index, row, CT_LABEL)
		row.hint:SetFont("ZoFontGameSmall")
		row.hint:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		row.hint:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
		row.hint:SetAnchor(RIGHT, row, RIGHT, -10, 0)
		row.hint:SetHidden(true)

		row.check = WINDOW_MANAGER:CreateControlFromVirtual(name .. "RowCheck" .. index, row, "ZO_CheckButton")
		row.check:SetAnchor(LEFT, row, LEFT, 10, 0)
		row.check:SetMouseEnabled(false)
		row.check:SetHidden(true)

		row.arrow = WINDOW_MANAGER:CreateControl(name .. "RowArrow" .. index, row, CT_TEXTURE)
		row.arrow:SetTexture(ARROW_TEXTURE)
		row.arrow:SetDimensions(14, 14)
		row.arrow:SetAnchor(RIGHT, row, RIGHT, -8, 0)
		row.arrow:SetHidden(true)

		row.clear = WINDOW_MANAGER:CreateControl(name .. "RowClear" .. index, row, CT_TEXTURE)
		row.clear:SetTexture(CLEAR_TEXTURE)
		row.clear:SetDimensions(CLEAR_SIZE, CLEAR_SIZE)
		row.clear:SetAnchor(RIGHT, row, RIGHT, -6, 0)
		row.clear:SetMouseEnabled(true)
		row.clear:SetHidden(true)
		row.clear:SetHandler("OnMouseEnter", function(self)
			self:SetTexture(CLEAR_TEXTURE_OVER)
			ZO_Tooltips_ShowTextTooltip(self, TOP, LibAPH.L("CLEAR_RECENT_SEARCHES"))
		end)
		row.clear:SetHandler("OnMouseExit", function(self)
			self:SetTexture(CLEAR_TEXTURE)
			ZO_Tooltips_HideTextTooltip()
		end)
		row.clear:SetHandler("OnMouseUp", function(_, button, upInside)
			if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
			sb:ClearRecent()
		end)

		row:SetHandler("OnMouseEnter", function(self)
			if not self.line or not self.line.item then return end
			highlight = self.line.item
			PaintRows()
			if self.entry and self.entry.libaph_submenu then
				sb:OpenFlyout(self)
			else
				sb:CloseFlyout()
			end
		end)
		row:SetHandler("OnMouseUp", function(self, button, upInside)
			if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT or not self.entry then return end
			Accept(self.entry)
		end)

		rows[index] = row
		return row
	end

	function sb:SavePosition()
		local store = Store()
		if not bar or not store then return false end
		store.bar_x = bar:GetLeft()
		store.bar_y = bar:GetTop()
		return true
	end

	function sb:ApplyPosition()
		if not bar then return false end
		local store = Store() or {}
		local x, y = store.bar_x, store.bar_y
		bar:ClearAnchors()
		if type(x) ~= "number" or type(y) ~= "number" or x < 0 or y < 0 then
			bar:SetAnchor(TOP, GuiRoot, TOP, 0, GuiRoot:GetHeight() * TOP_OFFSET_PCT)
			return false
		end
		local max_x = math.max(GuiRoot:GetWidth() - base_width, 0)
		local max_y = math.max(GuiRoot:GetHeight() - BAR_HEIGHT, 0)
		bar:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, math.min(x, max_x), math.min(y, max_y))
		return true
	end

	function sb:ResetPosition()
		local store = Store()
		if store then
			store.bar_x = UNSET
			store.bar_y = UNSET
		end
		return self:ApplyPosition()
	end

	local function AttachDrag(control)
		control:SetMouseEnabled(true)
		ZO_PostHookHandler(control, "OnMouseDown", function(_, button)
			if button == MOUSE_BUTTON_INDEX_RIGHT then bar:StartMoving() end
		end)
		ZO_PostHookHandler(control, "OnMouseUp", function(_, button)
			if button ~= MOUSE_BUTTON_INDEX_RIGHT then return end
			bar:StopMovingOrResizing()
			sb:SavePosition()
		end)
	end

	function sb:SetOpacity(alpha)
		if type(alpha) ~= "number" then return false end
		alpha = zo_clamp(alpha, 0, 1)
		local store = Store()
		if store then store.bar_opacity = alpha end
		if backdrop then backdrop:SetAlpha(alpha) end
		return true
	end

	function sb:GetBackdrop() return backdrop end

	local function BuildFooter()
		footer = WINDOW_MANAGER:CreateControl(name .. "Footer", list, CT_CONTROL)
		footer:SetAnchor(BOTTOMLEFT, list, BOTTOMLEFT, 0, 0)
		footer:SetAnchor(BOTTOMRIGHT, list, BOTTOMRIGHT, 0, 0)
		footer:SetHeight(FOOTER_HEIGHT)
		footer:SetHidden(true)

		local strip = WINDOW_MANAGER:CreateControl(name .. "FooterStrip", footer, CT_TEXTURE)
		strip:SetAnchorFill(footer)
		Paint(strip, THEME.HEADER)
		local divider = WINDOW_MANAGER:CreateControl(name .. "FooterDivider", footer, CT_TEXTURE)
		divider:SetAnchor(TOPLEFT, footer, TOPLEFT, 0, 0)
		divider:SetAnchor(TOPRIGHT, footer, TOPRIGHT, 0, 0)
		divider:SetHeight(LibAPH.PixelSize())
		Paint(divider, THEME.EDGE)

		footer_hints = LibAPH.CreateKeyHints(footer, name .. "FooterHints", {
			{ keys = { KEY_UPARROW, KEY_DOWNARROW }, gamepadKeys = { KEY_GAMEPAD_DPAD_UP, KEY_GAMEPAD_DPAD_DOWN }, text = LibAPH.L("NAVIGATE") },
			{ keys = { KEY_ENTER }, gamepadKeys = { KEY_GAMEPAD_BUTTON_1 }, text = LibAPH.L("OPEN") },
			{ keys = { KEY_TAB }, text = LibAPH.L("SCOPE_2") },
			{ keys = { KEY_ESCAPE }, gamepadKeys = { KEY_GAMEPAD_BUTTON_2 }, text = LibAPH.L("CLOSE") },
		})
		footer_hints:SetAnchor(LEFT, footer, LEFT, 10, 0)
	end

	local function Build()
		bar = WINDOW_MANAGER:CreateControl(name, GuiRoot, CT_TOPLEVELCONTROL)
		bar:SetDimensions(width, BAR_HEIGHT)
		bar:SetDrawTier(DT_HIGH)
		bar:SetDrawLayer(DL_OVERLAY)
		bar:SetDrawLevel(BAR_DRAW_LEVEL)
		bar:SetMouseEnabled(true)
		bar:SetMovable(true)
		bar:SetClampedToScreen(true)
		bar:SetHidden(true)
		sb:ApplyPosition()
		bar:SetHandler("OnMoveStop", function() sb:SavePosition() end)
		AttachDrag(bar)

		local store = Store() or {}
		backdrop = LibAPH.ApplyPanelBackdrop(bar, name .. "Backdrop", THEME.BG_HUD)
		backdrop:SetAlpha(store.bar_opacity or opts.defaultOpacity or DEFAULT_OPACITY)

		measure_main = WINDOW_MANAGER:CreateControl(name .. "MeasureMain", bar, CT_LABEL)
		measure_main:SetFont("ZoFontGame")
		measure_main:SetHidden(true)
		measure_small = WINDOW_MANAGER:CreateControl(name .. "MeasureSmall", bar, CT_LABEL)
		measure_small:SetFont("ZoFontGameSmall")
		measure_small:SetHidden(true)

		chevron = WINDOW_MANAGER:CreateControl(name .. "Expand", bar, CT_BUTTON)
		chevron:SetDimensions(CHEVRON_HIT, CHEVRON_HIT)
		chevron:SetAnchor(RIGHT, bar, RIGHT, -(EDGE_INSET - (CHEVRON_HIT - CHEVRON_SIZE) / 2), 0)
		chevron:SetDrawLevel(BAR_DRAW_LEVEL + 2)
		chevron:SetMouseEnabled(true)
		chevron_icon = WINDOW_MANAGER:CreateControl(name .. "ExpandIcon", chevron, CT_TEXTURE)
		chevron_icon:SetTexture(CHEVRON_TEXTURE)
		chevron_icon:SetDimensions(CHEVRON_SIZE, CHEVRON_SIZE)
		chevron_icon:SetAnchor(CENTER, chevron, CENTER, 0, 0)
		chevron_icon:SetMouseEnabled(false)
		Paint(chevron_icon, THEME.MUTED)
		chevron:SetHandler("OnMouseEnter", function() Paint(chevron_icon, THEME.TEXT) end)
		chevron:SetHandler("OnMouseExit", function() Paint(chevron_icon, THEME.MUTED) end)
		chevron:SetHandler("OnClicked", function() sb:ToggleExpanded() end)

		scope_label = WINDOW_MANAGER:CreateControl(name .. LibAPH.L("SCOPE_2"), bar, CT_LABEL)
		scope_label:SetFont("ZoFontGameSmall")
		Paint(scope_label, THEME.ACCENT)
		scope_label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
		scope_label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		scope_label:SetAnchor(RIGHT, chevron, LEFT, -4, 0)
		scope_label:SetDrawLevel(BAR_DRAW_LEVEL + 2)
		scope_label:SetText(ScopeText(sb:GetScope()))
		scope_label:SetHidden(opts.scopes == nil)
		scope_label:SetMouseEnabled(true)
		scope_label:SetHandler("OnMouseEnter", function(self) Paint(self, THEME.TEXT) end)
		scope_label:SetHandler("OnMouseExit", function(self) Paint(self, THEME.ACCENT) end)
		scope_label:SetHandler("OnMouseUp", function(_, button, upInside)
			if upInside and (button == MOUSE_BUTTON_INDEX_LEFT or button == MOUSE_BUTTON_INDEX_RIGHT) then sb:ShowScopePicker() end
		end)

		edit = WINDOW_MANAGER:CreateControlFromVirtual(name .. "Edit", bar, "ZO_DefaultEdit")
		edit:SetAnchor(TOPLEFT, bar, TOPLEFT, EDGE_INSET + 2, 2)
		edit:SetAnchor(RIGHT, opts.scopes and scope_label or chevron, LEFT, -10, 0, ANCHOR_CONSTRAINS_X)
		edit:SetHeight(BAR_HEIGHT - 4)
		edit:SetFont("ZoFontGame")
		LibAPH.AddGhostText(edit, placeholder)
		AttachDrag(edit)

		list = WINDOW_MANAGER:CreateControl(name .. "List", bar, CT_CONTROL)
		list:SetWidth(width)
		list:SetAnchor(TOPLEFT, bar, BOTTOMLEFT, 0, 4)
		list:SetMouseEnabled(true)
		list:SetHidden(true)
		LibAPH.ApplyPanelBackdrop(list, name .. "ListBackdrop", THEME.BG)
		list:SetHandler("OnMouseWheel", function(_, delta) sb:Scroll(delta) end)
		BuildFooter()

		for index = 1, max_rows do AcquireRow(index) end

		ZO_PostHookHandler(edit, "OnTextChanged", function(self) sb:RunSearch(self:GetText()) end)
		edit:SetHandler("OnUpArrow", function()
			if sb:MenuTakesKeys() then return LibAPH.MoveContextMenuFocus(-1) end
			sb:MoveHighlight(-1)
		end)
		edit:SetHandler("OnDownArrow", function()
			if sb:MenuTakesKeys() then return LibAPH.MoveContextMenuFocus(1) end
			if not expanded and #shown == 0 then
				sb:SetExpanded(true)
				return
			end
			sb:MoveHighlight(1)
		end)
		edit:SetHandler("OnEnter", function()
			if sb:MenuTakesKeys() then return LibAPH.ActivateContextMenuFocus() end
			sb:AcceptHighlight()
		end)
		edit:SetHandler("OnTab", function() sb:CycleScope(1) end)
		edit:SetHandler("OnEscape", function()
			if sb:MenuTakesKeys() then return LibAPH.CloseContextMenu() end
			sb:Hide()
		end)
		edit:SetHandler("OnFocusLost", function()
			if sb:ShouldDismissOnFocusLost() then sb:Hide() end
		end)
		return bar
	end

	function sb:Build()
		if not bar then Build() end
		return bar
	end

	function sb:MenuTakesKeys()
		if not (self.flyout_open or self.scope_picker_open) then return false end
		return type(LibAPH.IsContextMenuOpen) == "function" and LibAPH.IsContextMenuOpen() and true or false
	end

	function sb:ShouldDismissOnFocusLost()
		if not self:IsShown() or self.scope_picker_open or expanded then return false end
		if MouseIsOver(bar, 0, 0, 0, 0) or (list and not list:IsHidden() and MouseIsOver(list, 0, 0, 0, 0)) then return false end
		return (edit and edit:GetText() or "") == ""
	end

	function sb:LeaveCurrentMenu()
		if opts.leaveMenu == false or SCENE_MANAGER:IsShowingBaseScene() then return false end
		SCENE_MANAGER:ShowBaseScene()
		return true
	end

	function sb:EnterUiMode()
		if SCENE_MANAGER:IsInUIMode() then
			entered_ui_mode = false
			return false
		end
		SCENE_MANAGER:SetInUIMode(true)
		entered_ui_mode = true
		return true
	end

	function sb:LeaveUiMode()
		if not entered_ui_mode then return false end
		entered_ui_mode = false
		SCENE_MANAGER:SetInUIMode(false)
		return true
	end

	local function Focus(seed)
		scope_label:SetText(ScopeText(sb:GetScope()))
		edit:SetText(seed or "")
		edit:TakeFocus()
		sb:RunSearch(seed or "")
	end

	function sb:GamepadResultChoices(text, results)
		results = results or self:Search(text)
		local choices = {}
		for index = 1, math.min(#results, gamepad_rows) do
			local entry = results[index]
			choices[#choices + 1] = { text = gamepad_text(entry), entry = entry, callback = function() Accept(entry) end }
		end
		if opts.scopes then
			choices[#choices + 1] = {
				text = LibAPH.L("SCOPE") .. self:GetScope(),
				callback = function() sb:ShowGamepadScopePicker(text) end,
			}
		end
		choices[#choices + 1] = {
			text = LibAPH.L("SEARCH_AGAIN"),
			callback = function() sb:ShowGamepadEntry(text) end,
		}
		return choices, results
	end

	function sb:ShowGamepadResults(text)
		local shown_results = {}
		self:SearchThen(text, function(results)
			shown_results = results
			local choices = self:GamepadResultChoices(text, results)
			local title = #results == 0 and string.format(LibAPH.L("NO_MATCHES_FOR"), text) or text
			LibAPH.ShowGamepadPicker({ title = title, choices = choices })
		end)
		return shown_results
	end

	function sb:ShowGamepadScopePicker(text)
		local choices = {}
		for _, scope in ipairs(Scopes()) do
			choices[#choices + 1] = {
				text = scope == self:GetScope() and ("|c9CD04C" .. scope .. "|r") or scope,
				callback = function()
					sb:SetScope(scope)
					if text then sb:ShowGamepadResults(text) end
				end,
			}
		end
		LibAPH.ShowGamepadPicker({ title = opts.scopeTitle or LibAPH.L("SCOPE_2"), choices = choices })
		return true
	end

	function sb:ShowGamepadSuggestions(text)
		if not text or text == "" then
			suggest_token = suggest_token + 1
			GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_DIALOG_TOOLTIP)
			return 0
		end
		suggest_token = suggest_token + 1
		local token = suggest_token
		local count = 0
		self:SearchThen(text, function(results)
			if token ~= suggest_token then return end
			count = #results
			local suggestions = {}
			for index = 1, math.min(#results, gamepad_rows) do suggestions[#suggestions + 1] = gamepad_text(results[index]) end
			if #suggestions == 0 then suggestions[1] = string.format(LibAPH.L("NO_MATCHES_FOR_YET"), text) end
			GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(GAMEPAD_LEFT_DIALOG_TOOLTIP, table.concat(suggestions, "\n"))
		end)
		return count
	end

	suggest_count = suggest_count + 1
	local suggest_namespace = "LibAPHSuggest" .. suggest_count

	function sb:ShowGamepadEntry(seed)
		LibAPH.ShowGamepadTextEntry({
			title = opts.title or placeholder,
			prompt = placeholder,
			initialText = seed or "",
			onTextChanged = function(text)
				EVENT_MANAGER:UnregisterForUpdate(suggest_namespace)
				EVENT_MANAGER:RegisterForUpdate(suggest_namespace, SUGGEST_DELAY_MS, function()
					EVENT_MANAGER:UnregisterForUpdate(suggest_namespace)
					sb:ShowGamepadSuggestions(text)
				end)
			end,
			onClosed = function()
				EVENT_MANAGER:UnregisterForUpdate(suggest_namespace)
				suggest_token = suggest_token + 1
				GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_DIALOG_TOOLTIP)
			end,
			onConfirm = function(text) sb:ShowGamepadResults(text) end,
		})
		return true
	end

	function sb:Show(seed)
		if UseGamepad() then
			if seed and seed ~= "" then
				self:ShowGamepadResults(seed)
			else
				self:ShowGamepadEntry("")
			end
			return true
		end

		self:Build()
		bar:SetHidden(false)
		if self:LeaveCurrentMenu() then
			zo_callLater(function()
				if opts.enterUiMode ~= false then sb:EnterUiMode() end
				Focus(seed)
			end, SETTLE_MS)
		else
			if opts.enterUiMode ~= false then self:EnterUiMode() end
			Focus(seed)
		end
		return true
	end

	function sb:Hide(keep_ui_mode)
		if not bar then return false end
		if self.scope_picker_open then
			self.scope_picker_open = false
			LibAPH.CloseContextMenu()
		end
		self:CloseFlyout()
		if not keep_ui_mode then self:LeaveUiMode() else entered_ui_mode = false end
		expanded = false
		chevron_icon:SetTextureRotation(0)
		edit:LoseFocus()
		edit:SetText("")
		shown = {}
		lines = {}
		highlight = 0
		offset = 0
		PaintRows()
		bar:SetHidden(true)
		return true
	end

	function sb:Toggle()
		if self:IsShown() then return self:Hide() end
		return self:Show()
	end

	return sb
end
