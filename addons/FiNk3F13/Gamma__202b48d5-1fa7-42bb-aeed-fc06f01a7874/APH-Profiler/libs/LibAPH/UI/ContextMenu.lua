--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local THEME = LibAPH.THEME
local ROW_TYPE = 1
local DIVIDER_TYPE = 2
local HEADER_TYPE = 3
local ON_CONSOLE = IsConsoleUI()
local ROW_FONT = ON_CONSOLE and "ZoFontGamepad22" or "ZoFontGame"
local SMALL_FONT = ON_CONSOLE and "ZoFontGamepad18" or "ZoFontGameSmall"
local ROW_HEIGHT = ON_CONSOLE and 40 or 28
local DIVIDER_HEIGHT = 11
local DIVIDER_PIXELS = 2
local MARQUEE_SPEED = 45
local MARQUEE_PAUSE_MS = 700
local HEADER_HEIGHT = ON_CONSOLE and 32 or 24
local VISIBLE_ROWS = 15
local MIN_WIDTH = 160
local MAX_WIDTH = ON_CONSOLE and 760 or 520
local TEXT_PADDING = 44
local EDGE_INSET = 8
local SEARCH_HEIGHT = 28
local SUBMENU_GAP = 2
local HEADER_COLOR = THEME.MUTED
local ITEM_COLOR = THEME.TEXT
local DISABLED_COLOR = { 0.45, 0.45, 0.48, 1 }
local HINT_GAP = 24
local SCREEN_MARGIN = 12
local MAX_SCREEN_SHARE = 0.6
local ANCHOR_GAP = 4

local CLICK_THROUGH_NAMESPACE = "LibAPH_ContextMenuClickThrough"

local menus = {}
local open_depth = 0
local click_eater
local base_level = 0

local function EntryHeight(entry)
	if entry.divider then return DIVIDER_HEIGHT end
	if entry.header then return HEADER_HEIGHT end
	return ROW_HEIGHT
end

local function EntryType(entry)
	if entry.divider then return DIVIDER_TYPE end
	if entry.header then return HEADER_TYPE end
	return ROW_TYPE
end

local function Paint(control, color)
	control:SetColor(color[1], color[2], color[3], color[4] or 1)
end

local function EntryIsPickable(entry)
	return not entry.divider and not entry.header and entry.enabled ~= false
end

local function TextWidth(label, text)
	local width = label:GetStringWidth(text)
	if type(width) ~= "number" then return nil end
	return width / GetUIGlobalScale()
end

local function MeasureWidth(entries)
	local widest = MIN_WIDTH
	local label = LibAPH.context_menu_sizer
	if not label then
		label = WINDOW_MANAGER:CreateControl("LibAPH_ContextMenuSizer", GuiRoot, CT_LABEL)
		label:SetFont(ROW_FONT)
		label:SetHidden(true)
		LibAPH.context_menu_sizer = label
	end
	for _, entry in ipairs(entries) do
		if entry.text and entry.text ~= "" then
			local width = TextWidth(label, entry.text)
			if type(width) == "number" then
				local extra = TEXT_PADDING
				if entry.checkbox then extra = extra + 22 end
				if entry.icon then extra = extra + 26 end
				if entry.selected then extra = extra + 22 end
				if entry.hint and entry.hint ~= "" then
					local hint_width = TextWidth(label, entry.hint)
					if type(hint_width) == "number" then extra = extra + hint_width + HINT_GAP end
				end
				if width + extra > widest then widest = width + extra end
			end
		end
	end
	return math.min(MAX_WIDTH, math.ceil(widest))
end

local MENU_FLOOR_LEVEL = 10000
local OWNER_HANDLER = "LibAPH_ContextMenu"
local OWNER_CHECK = "LibAPH_ContextMenuOwnerCheck"
local menu_owners, hidden_owners = {}, {}
local TIP_NAME = "LibAPH_ContextMenuTip"
local TIP_WIDTH = ON_CONSOLE and 420 or 340
local TIP_PAD = 8
local TIP_LIFT = 10
local tip, tip_label

local function BuildTip()
	if tip then return end
	tip = WINDOW_MANAGER:CreateTopLevelWindow(TIP_NAME)
	tip:SetDrawTier(DT_HIGH)
	tip:SetDrawLayer(DL_OVERLAY)
	tip:SetClampedToScreen(true)
	tip:SetMouseEnabled(false)
	tip:SetHidden(true)
	LibAPH.ApplyPanelBackdrop(tip, TIP_NAME .. "BG", THEME.BG)
	tip_label = WINDOW_MANAGER:CreateControl(TIP_NAME .. "Text", tip, CT_LABEL)
	tip_label:SetFont(SMALL_FONT)
	Paint(tip_label, THEME.TEXT)
	tip_label:SetAnchor(TOPLEFT, tip, TOPLEFT, TIP_PAD, TIP_PAD)
	tip_label:SetDimensions(TIP_WIDTH - TIP_PAD * 2, 0)
end

function LibAPH.GetContextMenuTooltipText()
	if not tip or tip:IsHidden() then return nil end
	return tip_label:GetText()
end

local tooltip_shown = false

local function HideRowTooltip()
	if not tooltip_shown then return end
	tooltip_shown = false
	if tip then tip:SetHidden(true) end
end

local function ShowRowTooltip(row)
	local entry, menu = row.libaph_entry, row.libaph_menu
	local text = entry and entry.tooltip
	if type(text) == "function" then text = text() end
	if ON_CONSOLE or not menu or type(text) ~= "string" or text == "" then
		HideRowTooltip()
		return
	end
	local win = menu.win
	BuildTip()
	tip_label:SetText(text)
	tip_label:SetDimensions(TIP_WIDTH - TIP_PAD * 2, 0)
	tip:SetDimensions(TIP_WIDTH, (tip_label:GetTextHeight() or 0) + TIP_PAD * 2)
	tip:SetDrawLevel((win:GetDrawLevel() or 0) + TIP_LIFT)
	local y = (row:GetTop() or 0) - (win:GetTop() or 0)
	tip:ClearAnchors()
	if (win:GetLeft() or 0) >= TIP_WIDTH + SUBMENU_GAP then
		tip:SetAnchor(TOPRIGHT, win, TOPLEFT, -SUBMENU_GAP, y)
	else
		tip:SetAnchor(TOPLEFT, win, TOPRIGHT, SUBMENU_GAP, y)
	end
	tip:SetHidden(false)
	tooltip_shown = true
end

local function CloseFrom(depth)
	for level = #menus, depth, -1 do
		local menu = menus[level]
		if menu then
			menu.win:SetHidden(true)
			menu.entries = nil
		end
	end
	if depth <= open_depth then open_depth = depth - 1 end
end

function LibAPH.IsContextMenuOpen()
	return open_depth > 0
end

local function ReleaseOwners()
	for index = #menu_owners, 1, -1 do
		local owner = menu_owners[index]
		owner:SetHandler("OnEffectivelyHidden", nil, OWNER_HANDLER)
		owner:SetHandler("OnEffectivelyShown", nil, OWNER_HANDLER)
		menu_owners[index] = nil
	end
	for owner in pairs(hidden_owners) do hidden_owners[owner] = nil end
	EVENT_MANAGER:UnregisterForUpdate(OWNER_CHECK)
end

function LibAPH.CloseContextMenu()
	HideRowTooltip()
	ReleaseOwners()
	if open_depth == 0 then return end
	local on_hide = menus[1] and menus[1].on_hide
	CloseFrom(1)
	open_depth = 0
	if click_eater then click_eater:SetHidden(true) end
	EVENT_MANAGER:UnregisterForEvent(CLICK_THROUGH_NAMESPACE, EVENT_GLOBAL_MOUSE_UP)
	if on_hide then
		menus[1].on_hide = nil
		on_hide()
	end
end

function LibAPH.CloseContextMenuLevel()
	if open_depth <= 1 then
		LibAPH.CloseContextMenu()
		return true
	end
	CloseFrom(open_depth)
	return true
end

local function IsControl(value)
	return type(value) == "table" or type(value) == "userdata"
end

local function MouseInsideAnyMenu()
	local over = WINDOW_MANAGER:GetMouseOverControl()
	local guard = 0
	while IsControl(over) and guard < 32 do
		guard = guard + 1
		for level = 1, open_depth do
			if menus[level] and over == menus[level].win then return true end
		end
		local parent = type(over.GetParent) == "function" and over:GetParent() or nil
		if parent == over then return false end
		over = parent
	end
	return false
end

local function EnsureClickEater()
	if click_eater then return click_eater end
	click_eater = WINDOW_MANAGER:CreateTopLevelWindow("LibAPH_ContextMenuClickEater")
	click_eater:SetAnchorFill(GuiRoot)
	click_eater:SetMouseEnabled(true)
	click_eater:SetDrawLayer(DL_OVERLAY)
	click_eater:SetDrawTier(DT_HIGH)
	click_eater:SetDrawLevel(0)
	click_eater:SetHidden(true)
	click_eater:SetHandler("OnMouseUp", function()
		if MouseInsideAnyMenu() then return end
		LibAPH.CloseContextMenu()
	end)
	return click_eater
end

local function StopMarquee(row)
	local clip = row.libaph_marquee
	if not clip or clip:IsHidden() then return end
	clip:SetHandler("OnUpdate", nil)
	clip:SetHidden(true)
	row:GetNamedChild("Label"):SetHidden(false)
end

local function MarqueeOffset(elapsed, travel)
	local run = travel / MARQUEE_SPEED * 1000
	local t = elapsed % (MARQUEE_PAUSE_MS * 2 + run)
	if t < MARQUEE_PAUSE_MS then return 0 end
	if t < MARQUEE_PAUSE_MS + run then return -travel * (t - MARQUEE_PAUSE_MS) / run end
	return -travel
end
LibAPH.ContextMenuMarqueeOffset = MarqueeOffset

local function StartMarquee(row)
	local entry = row.libaph_entry
	if not entry or entry.divider or entry.header then return false end
	local label = row:GetNamedChild("Label")
	local text = label:GetText()
	local travel = label:GetStringWidth(text) / GetUIGlobalScale() - label:GetWidth()
	if travel <= 1 then return false end

	local clip = row.libaph_marquee
	if not clip then
		clip = WINDOW_MANAGER:CreateControl(row:GetName() .. "Marquee", row, CT_CONTROL)
		clip:SetAutoRectClipChildren(true)
		clip.text = WINDOW_MANAGER:CreateControl(row:GetName() .. "MarqueeText", clip, CT_LABEL)
		clip.text:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		row.libaph_marquee = clip
	end
	clip:ClearAnchors()
	clip:SetAnchor(TOPLEFT, label, TOPLEFT, 0, 0)
	clip:SetAnchor(BOTTOMRIGHT, label, BOTTOMRIGHT, 0, 0)
	clip.text:SetFont(label:GetFont())
	clip.text:SetColor(label:GetColor())
	clip.text:SetText(text)
	clip.text:ClearAnchors()
	clip.text:SetAnchor(LEFT, clip, LEFT, 0, 0)
	clip:SetHidden(false)
	label:SetHidden(true)

	local started = GetFrameTimeMilliseconds()
	clip:SetHandler("OnUpdate", function()
		clip.text:ClearAnchors()
		clip.text:SetAnchor(LEFT, clip, LEFT, MarqueeOffset(GetFrameTimeMilliseconds() - started, travel), 0)
	end)
	return true
end

local function WireRow(row)
	if row.libaph_wired then return end
	row.libaph_wired = true
	row:SetHandler("OnMouseUp", function(self, button, upInside)
		if upInside and button == MOUSE_BUTTON_INDEX_LEFT then LibAPH.ContextMenuRowClicked(self) end
	end)
	row:SetHandler("OnMouseEnter", function(self) LibAPH.ContextMenuRowEntered(self) end)
	row:SetHandler("OnMouseExit", function(self)
		StopMarquee(self)
		HideRowTooltip()
	end)
end

local function SetupRow(row, data)
	WireRow(row)
	StopMarquee(row)
	local menu = data.menu
	local entry = data.entry
	row:SetHeight(EntryHeight(entry))
	row.libaph_entry = entry
	row.libaph_menu = menu
	row.libaph_index = data.index

	local label = row:GetNamedChild("Label")
	local check = row:GetNamedChild("Check")
	local arrow = row:GetNamedChild("Arrow")
	local divider = row:GetNamedChild("Divider")
	local icon = row:GetNamedChild("Icon")
	local highlight = row:GetNamedChild("Highlight")
	local hint = row:GetNamedChild("Hint")
	local selected = row:GetNamedChild("Selected")

	Paint(highlight, THEME.HOVER)
	highlight:SetHidden(menu.focus ~= data.index)
	divider:SetHidden(not entry.divider)
	label:SetHidden(entry.divider == true)
	arrow:SetHidden(entry.submenu == nil)
	check:SetHidden(not entry.checkbox)
	hint:SetHidden(true)
	selected:SetHidden(true)
	icon:SetHidden(true)

	if entry.divider then
		Paint(divider, THEME.EDGE)
		divider:SetHeight(DIVIDER_PIXELS * LibAPH.PixelSize())
		return
	end

	label:ClearAnchors()
	if entry.header then
		label:SetFont(SMALL_FONT)
		label:SetAnchor(LEFT, row, LEFT, 10, 2)
		label:SetAnchor(RIGHT, row, RIGHT, -10, 2)
		label:SetText(zo_strupper(LibAPH.StripColors(entry.text or "")))
		Paint(label, entry.color or HEADER_COLOR)
		return
	end
	label:SetFont(ROW_FONT)

	local tint = THEME.MUTED
	if entry.danger then tint = THEME.DANGER end
	if type(entry.iconTint) == "table" then tint = entry.iconTint end
	if entry.icon then
		icon:SetHidden(false)
		icon:SetTexture(entry.icon)
		Paint(icon, tint)
	end

	local right = entry.submenu and -26 or -10
	if entry.selected then
		selected:SetHidden(false)
		Paint(selected, THEME.GREEN)
		right = -32
	end
	if entry.hint and entry.hint ~= "" and not entry.submenu then
		hint:SetHidden(false)
		hint:SetFont(SMALL_FONT)
		hint:SetText(entry.hint)
		Paint(hint, THEME.MUTED)
		hint:ClearAnchors()
		hint:SetAnchor(RIGHT, row, RIGHT, right, 0)
		right = right - (TextWidth(hint, entry.hint) or 0) - 12
	end
	Paint(arrow, THEME.MUTED)

	local left_inset = 10
	if entry.checkbox then left_inset = 34 elseif entry.icon then left_inset = 36 end
	label:SetAnchor(LEFT, row, LEFT, left_inset, 0)
	label:SetAnchor(RIGHT, row, RIGHT, right, 0)
	label:SetText(entry.text or "")

	local color = ITEM_COLOR
	if entry.danger then color = THEME.DANGER end
	if entry.enabled == false then color = DISABLED_COLOR end
	if entry.color then color = entry.color end
	Paint(label, color)

	if entry.checkbox then
		ZO_CheckButton_SetCheckState(check, entry.checked == true)
		check:SetMouseEnabled(false)
	end
end

local function RowFor(menu, index)
	for _, row in ipairs(menu.list.activeControls or {}) do
		if row.libaph_index == index then return row end
	end
	return nil
end

local function HighlightRow(menu, index)
	for _, row in ipairs(menu.list.activeControls or {}) do
		local on = row.libaph_index == index
		local highlight = row:GetNamedChild("Highlight")
		if highlight then highlight:SetHidden(not on) end
		if not on then StopMarquee(row) end
	end
	menu.focus = index
end

local ShowMenuAt

local function ScrollToFocus(menu, index)
	local list = menu.list
	local data = list and ZO_ScrollList_GetDataList(list)
	if not (data and data[index]) or type(ZO_ScrollList_ScrollDataIntoView) ~= "function" then return end
	ZO_ScrollList_ScrollDataIntoView(list, index, function() HighlightRow(menu, index) end, true)
	HighlightRow(menu, index)
end

local function OpenSubmenu(menu, row)
	local entry = row.libaph_entry
	if not entry or not entry.submenu then return end
	local level = menu.level + 1
	CloseFrom(level)
	local child_entries = entry.submenu()
	if type(child_entries) ~= "table" or #child_entries == 0 then return end
	ShowMenuAt(level, row, child_entries, { anchorToRow = true, builder = entry.submenu, enableFilter = entry.submenuFilter == true })
	menus[level].opener_index = row.libaph_index
	menus[level].parent = menu
end

local function ActivateRow(row)
	local entry = row and row.libaph_entry
	local menu = row and row.libaph_menu
	if not entry or not menu then return end
	if entry.divider or entry.header or entry.enabled == false then return end

	if entry.submenu then
		OpenSubmenu(menu, row)
		return
	end

	if entry.checkbox then
		local now = entry.checked ~= true
		entry.checked = now
		local check = row:GetNamedChild("Check")
		if check then ZO_CheckButton_SetCheckState(check, now) end
		if entry.onToggle then entry.onToggle(now) end
		LibAPH.RefreshContextMenu()
		return
	end

	local close_after = entry.closeOnClick ~= false
	if entry.onClick then entry.onClick(row) end
	if close_after then LibAPH.CloseContextMenu() end
end

local FillMenu

local function CreateMenu(level)
	local win = WINDOW_MANAGER:CreateTopLevelWindow("LibAPH_ContextMenu" .. level)
	win:SetHidden(true)
	win:SetClampedToScreen(true)
	win:SetMouseEnabled(true)
	win:SetDrawLayer(DL_OVERLAY)
	win:SetDrawTier(DT_HIGH)
	win:SetDrawLevel(level)

	LibAPH.ApplyPanelBackdrop(win, "LibAPH_ContextMenuBackdrop" .. level, THEME.BG)

	local search_bg = WINDOW_MANAGER:CreateControl("LibAPH_ContextMenuSearchBg" .. level, win, CT_CONTROL)
	LibAPH.ApplyPanelBackdrop(search_bg, "LibAPH_ContextMenuSearchFill" .. level, THEME.INSET)
	search_bg:SetAnchor(TOPLEFT, win, TOPLEFT, EDGE_INSET, EDGE_INSET)
	search_bg:SetAnchor(TOPRIGHT, win, TOPRIGHT, -EDGE_INSET, EDGE_INSET)
	search_bg:SetHeight(SEARCH_HEIGHT)
	local search = WINDOW_MANAGER:CreateControlFromVirtual("LibAPH_ContextMenuSearch" .. level, search_bg, "ZO_DefaultEditForBackdrop")
	search:SetAnchor(TOPLEFT, search_bg, TOPLEFT, 8, 4)
	search:SetAnchor(BOTTOMRIGHT, search_bg, BOTTOMRIGHT, -8, -4)
	LibAPH.AddGhostText(search, "Filter")
	search_bg:SetHidden(true)
	search:SetHidden(true)

	local list = WINDOW_MANAGER:CreateControlFromVirtual("LibAPH_ContextMenuList" .. level, win, "ZO_ScrollList")
	ZO_ScrollList_AddCommitOnHeightChange(list)
	ZO_ScrollList_AddDataType(list, ROW_TYPE, "LibAPH_ContextMenuRow", ROW_HEIGHT, SetupRow)
	ZO_ScrollList_AddDataType(list, DIVIDER_TYPE, "LibAPH_ContextMenuRow", DIVIDER_HEIGHT, SetupRow)
	ZO_ScrollList_AddDataType(list, HEADER_TYPE, "LibAPH_ContextMenuRow", HEADER_HEIGHT, SetupRow)
	LibAPH.StyleScrollList(list, "LibAPH_ContextMenuScroll" .. level)

	local menu = { win = win, list = list, search = search, search_bg = search_bg, level = level, focus = 0 }
	menus[level] = menu
	ZO_PostHookHandler(search, "OnTextChanged", function(edit)
		if not menu.show_search or not menu.entries then return end
		menu.filter = edit:GetText()
		FillMenu(menu)
	end)
	search:SetHandler("OnUpArrow", function() LibAPH.MoveContextMenuFocus(-1) end)
	search:SetHandler("OnDownArrow", function() LibAPH.MoveContextMenuFocus(1) end)
	search:SetHandler("OnEnter", function() LibAPH.ActivateContextMenuFocus() end)
	search:SetHandler("OnEscape", function() LibAPH.CloseContextMenu() end)
	return menu
end

local function VisibleEntries(menu)
	if not menu.filter or menu.filter == "" then return menu.entries end
	local needle = string.lower(menu.filter)
	local out = {}
	for _, entry in ipairs(menu.entries or {}) do
		local text = string.lower(LibAPH.StripColors(entry.text) or "")
		if entry.header or entry.divider or string.find(text, needle, 1, true) then
			out[#out + 1] = entry
		end
	end
	return out
end

FillMenu = function(menu)
	local list = menu.list
	local data = ZO_ScrollList_GetDataList(list)
	ZO_ClearNumericallyIndexedTable(data)
	local shown = VisibleEntries(menu)
	local height = 0
	for index, entry in ipairs(shown) do
		data[#data + 1] = ZO_ScrollList_CreateDataEntry(EntryType(entry), { entry = entry, menu = menu, index = index })
		height = height + EntryHeight(entry)
	end

	local top = EDGE_INSET
	if menu.show_search then top = top + SEARCH_HEIGHT + 6 end
	local cap = VISIBLE_ROWS * ROW_HEIGHT
	if menu.room then cap = zo_clamp(menu.room - top - EDGE_INSET, math.min(ROW_HEIGHT * 3, cap), cap) end
	local list_height = math.min(height, cap)
	menu.content_height = height
	local width = MeasureWidth(shown) + ZO_SCROLL_BAR_WIDTH
	list:ClearAnchors()
	list:SetAnchor(TOPLEFT, menu.win, TOPLEFT, EDGE_INSET, top)
	list:SetDimensions(width, list_height)
	menu.win:SetDimensions(width + EDGE_INSET * 2, list_height + top + EDGE_INSET)
	menu.list_height = list_height
	ZO_ScrollList_Commit(list)
	menu.row_count = #ZO_ScrollList_GetDataList(list)
end

local function Number(value)
	return type(value) == "number" and value or nil
end

local function PlaceMenu(menu, anchorTo, beside)
	local win = menu.win
	local screen = Number(GuiRoot:GetHeight())
	local top, bottom = Number(anchorTo:GetTop()), Number(anchorTo:GetBottom())
	local share = screen and screen * MAX_SCREEN_SHARE or nil
	win:ClearAnchors()
	if beside then
		menu.room = screen and math.min(share, screen - SCREEN_MARGIN * 2) or nil
		FillMenu(menu)
		local width, height = Number(win:GetWidth()) or 0, Number(win:GetHeight()) or 0
		local y = -EDGE_INSET
		if screen and top then y = math.max(math.min(y, screen - SCREEN_MARGIN - (top + height)), SCREEN_MARGIN - top) end
		local right, screen_w = Number(anchorTo:GetRight()), Number(GuiRoot:GetWidth())
		local left = Number(anchorTo:GetLeft())
		if right and screen_w and left and right + SUBMENU_GAP + width > screen_w - SCREEN_MARGIN and left - EDGE_INSET - SUBMENU_GAP - width >= SCREEN_MARGIN then
			win:SetAnchor(TOPRIGHT, anchorTo, TOPLEFT, -(EDGE_INSET + SUBMENU_GAP), y)
			menu.side, menu.side_y = "left", y
			return "left"
		end
		win:SetAnchor(TOPLEFT, anchorTo, TOPRIGHT, SUBMENU_GAP, y)
		menu.side, menu.side_y = "right", y
		return "right"
	end

	local below = screen and bottom and (screen - bottom - ANCHOR_GAP - SCREEN_MARGIN) or nil
	local above = top and (top - ANCHOR_GAP - SCREEN_MARGIN) or nil
	menu.room = below and math.min(share, below) or nil
	FillMenu(menu)
	local needed = (Number(win:GetHeight()) or 0)
	local fits_below = not below or (menu.content_height or 0) + needed - (menu.list_height or 0) <= below
	if not fits_below and above and above > below then
		menu.room = math.min(share, above)
		FillMenu(menu)
		win:SetAnchor(BOTTOMLEFT, anchorTo, TOPLEFT, 0, -ANCHOR_GAP)
		return "above"
	end
	win:SetAnchor(TOPLEFT, anchorTo, BOTTOMLEFT, 0, ANCHOR_GAP)
	return "below"
end

local function PlaceBeside(menu, window, opts)
	local win = menu.win
	local screen_w, screen_h = Number(GuiRoot:GetWidth()), Number(GuiRoot:GetHeight())
	local left, top, right, bottom = Number(window:GetLeft()), Number(window:GetTop()), Number(window:GetRight()), Number(window:GetBottom())
	if not (screen_w and screen_h and left and top and right and bottom) then return nil end
	local gap = opts.gap or ANCHOR_GAP
	local below_gap, above_gap = gap + (opts.belowGap or 0), gap + (opts.aboveGap or 0)
	local share = screen_h * MAX_SCREEN_SHARE
	local below_room = screen_h - bottom - below_gap - SCREEN_MARGIN
	local above_room = top - above_gap - SCREEN_MARGIN
	local side_room = screen_h - SCREEN_MARGIN * 2
	local least = ROW_HEIGHT * 3
	local function Fill(room)
		menu.room = math.max(math.min(share, room), least)
		FillMenu(menu)
		return (menu.content_height or 0) <= (menu.list_height or 0), Number(win:GetWidth()) or 0, Number(win:GetHeight()) or 0
	end
	local function Put(point, rel_point, x, y)
		win:ClearAnchors()
		win:SetAnchor(point, window, rel_point, x, y)
	end
	local function Side(point, rel_point, x, height)
		local y = math.max(math.min(0, screen_h - SCREEN_MARGIN - (top + height)), SCREEN_MARGIN - top)
		Put(point, rel_point, x, y)
	end
	local best, best_open
	local function Consider(side, open)
		if not best_open or open > best_open then best, best_open = side, open end
	end
	if below_room >= least and Fill(below_room) then Consider("below", (screen_h - bottom) / screen_h) end
	if above_room >= least and Fill(above_room) then Consider("above", top / screen_h) end
	local _, width = Fill(side_room)
	if left - gap - SCREEN_MARGIN >= width then Consider("left", left / screen_w) end
	if screen_w - right - gap - SCREEN_MARGIN >= width then Consider("right", (screen_w - right) / screen_w) end
	if best == "below" then
		Fill(below_room)
		Put(TOPLEFT, BOTTOMLEFT, 0, below_gap)
		return "below"
	elseif best == "above" then
		Fill(above_room)
		Put(BOTTOMLEFT, TOPLEFT, 0, -above_gap)
		return "above"
	elseif best then
		local _, _, height = Fill(side_room)
		if best == "left" then Side(TOPRIGHT, TOPLEFT, -gap, height) else Side(TOPLEFT, TOPRIGHT, gap, height) end
		return best
	end
	if below_room >= least or above_room >= least then
		if below_room >= above_room then
			Fill(below_room)
			Put(TOPLEFT, BOTTOMLEFT, 0, below_gap)
			return "below"
		end
		Fill(above_room)
		Put(BOTTOMLEFT, TOPLEFT, 0, -above_gap)
		return "above"
	end
	Fill(side_room)
	Put(TOPLEFT, TOPLEFT, gap, gap)
	return "inside"
end

function LibAPH.PlaceContextMenuBeside(window, opts)
	local menu = menus[1]
	if not (menu and window) or open_depth == 0 or type(window.GetLeft) ~= "function" then return nil end
	local placed = PlaceBeside(menu, window, opts or {})
	if placed then menu.placed = placed end
	return placed
end

ShowMenuAt = function(level, anchorTo, entries, opts)
	opts = opts or {}
	local menu = menus[level] or CreateMenu(level)
	menu.win:SetDrawLevel(base_level + 1 + level)
	menu.entries = entries
	menu.builder = opts.builder
	menu.filter = nil
	menu.focus = 0
	menu.show_search = opts.enableFilter == true

	menu.search_bg:SetHidden(not menu.show_search)
	menu.search:SetHidden(not menu.show_search)
	if menu.show_search then
		menu.search:SetText("")
	end

	menu.placed = PlaceMenu(menu, anchorTo, opts.anchorToRow)
	menu.win:SetHidden(false)
	if level > open_depth then open_depth = level end
	return menu
end

function LibAPH.RefreshContextMenu()
	local depth = open_depth
	for level = 1, depth do
		local menu = menus[level]
		if menu and menu.entries then
			if menu.builder then
				local rebuilt = menu.builder()
				if type(rebuilt) == "table" then menu.entries = rebuilt end
			end
			FillMenu(menu)
			local child = menus[level + 1]
			if level < depth and child and child.opener_index then
				local opener = RowFor(menu, child.opener_index)
				if opener then
					child.win:ClearAnchors()
					if child.side == "left" then
						child.win:SetAnchor(TOPRIGHT, opener, TOPLEFT, -(EDGE_INSET + SUBMENU_GAP), child.side_y or -EDGE_INSET)
					else
						child.win:SetAnchor(TOPLEFT, opener, TOPRIGHT, SUBMENU_GAP, child.side_y or -EDGE_INSET)
					end
				end
			end
		end
	end
end

local function OwnerLevel(control)
	local owner = control
	if control and type(control.GetOwningWindow) == "function" then
		owner = control:GetOwningWindow() or control
	end
	if not owner or type(owner.GetDrawLevel) ~= "function" then return 0 end
	return owner:GetDrawLevel() or 0
end

local function CheckOwners()
	EVENT_MANAGER:UnregisterForUpdate(OWNER_CHECK)
	if next(hidden_owners) then LibAPH.CloseContextMenu() end
end

local function OwnerHidden(owner)
	hidden_owners[owner] = true
	EVENT_MANAGER:RegisterForUpdate(OWNER_CHECK, 0, CheckOwners)
end

local function OwnerShown(owner)
	hidden_owners[owner] = nil
end

local function WatchOwners(...)
	ReleaseOwners()
	for i = 1, select("#", ...) do
		local owner = select(i, ...)
		local kind = type(owner)
		if (kind == "userdata" or kind == "table") and type(owner.SetHandler) == "function" then
			local seen = false
			for _, watched in ipairs(menu_owners) do if watched == owner then seen = true end end
			if not seen then
				menu_owners[#menu_owners + 1] = owner
				owner:SetHandler("OnEffectivelyHidden", OwnerHidden, OWNER_HANDLER)
				owner:SetHandler("OnEffectivelyShown", OwnerShown, OWNER_HANDLER)
			end
		end
	end
end

function LibAPH.ShowContextMenu(control, entries, opts)
	if type(entries) ~= "table" then return false end
	opts = opts or {}
	LibAPH.CloseContextMenu()
	base_level = math.max(OwnerLevel(control), MENU_FLOOR_LEVEL)
	EnsureClickEater():SetDrawLevel(base_level + 1)
	local menu = ShowMenuAt(1, control, entries, {
		enableFilter = opts.enableFilter,
		builder = opts.rebuild,
		anchorToRow = opts.anchorSide == "right",
	})
	menu.on_hide = opts.onHide
	open_depth = 1
	WatchOwners(control, opts.window)
	if opts.anchorSide ~= "right" then
		local placed = PlaceBeside(menu, opts.window or control, { gap = opts.gap, belowGap = opts.belowGap, aboveGap = opts.aboveGap })
		if placed then menu.placed = placed end
	end
	if opts.clickThrough then
		EVENT_MANAGER:RegisterForEvent(CLICK_THROUGH_NAMESPACE, EVENT_GLOBAL_MOUSE_UP, function()
			if MouseInsideAnyMenu() or MouseIsOver(control, 0, 0, 0, 0) then return end
			LibAPH.CloseContextMenu()
		end)
	else
		EnsureClickEater():SetHidden(false)
	end
	return true
end

function LibAPH.ContextMenuRowClicked(row)
	ActivateRow(row)
end

function LibAPH.ContextMenuRowEntered(row)
	local menu = row and row.libaph_menu
	if not menu then return end
	HighlightRow(menu, row.libaph_index)
	StartMarquee(row)
	ShowRowTooltip(row)
	CloseFrom(menu.level + 1)
	if row.libaph_entry and row.libaph_entry.submenu then OpenSubmenu(menu, row) end
end

function LibAPH.MoveContextMenuFocus(direction)
	local menu = menus[open_depth]
	if not menu or not menu.entries then return false end
	local shown = VisibleEntries(menu)
	local count = #shown
	if count == 0 then return false end
	local index = menu.focus or 0
	for _ = 1, count do
		index = index + direction
		if index < 1 then index = count elseif index > count then index = 1 end
		if EntryIsPickable(shown[index]) then
			ScrollToFocus(menu, index)
			return true
		end
	end
	return false
end

function LibAPH.ActivateContextMenuFocus()
	local menu = menus[open_depth]
	if not menu or not menu.focus or menu.focus == 0 then return false end
	local row = RowFor(menu, menu.focus)
	if not row then
		ScrollToFocus(menu, menu.focus)
		row = RowFor(menu, menu.focus)
	end
	if not row then return false end
	ActivateRow(row)
	return true
end

function LibAPH.GetContextMenuDepth()
	return open_depth
end

function LibAPH.GetContextMenuRowCount(level)
	local menu = menus[level or open_depth]
	return menu and menu.row_count or 0
end

function LibAPH.__TestRow(level, index)
	local menu = menus[level]
	if not menu then return nil end
	return RowFor(menu, index)
end

function LibAPH.GetContextMenuPlacement(level)
	local menu = menus[level or 1]
	if not menu then return nil end
	return menu.placed, menu.list_height, menu.content_height
end

function LibAPH.GroupedChoiceEntries(groups, opts)
	opts = opts or {}
	local current, mark = opts.current, opts.markColor or THEME.GREEN
	local entries = {}
	for _, group in ipairs(groups) do
		local items = group.items or {}
		if #items > 0 or group.extra or opts.keepEmpty then
			local holds = group.holds == true
			for _, item in ipairs(items) do
				if item.value == current then holds = true end
			end
			entries[#entries + 1] = {
				text = group.title,
				color = holds and mark or nil,
				submenuFilter = group.filter == true,
				submenu = function()
					local out = {}
					for _, item in ipairs(items) do
						out[#out + 1] = {
							text = item.text,
							selected = item.value == current,
							onClick = function()
								if opts.onPick then opts.onPick(item.value, item) end
							end,
						}
					end
					for _, extra in ipairs(group.extra or {}) do out[#out + 1] = extra end
					return out
				end,
			}
		end
	end
	return entries
end

function LibAPH.ShowGroupedChoiceMenu(control, groups, opts)
	return LibAPH.ShowContextMenu(control, LibAPH.GroupedChoiceEntries(groups, opts), opts)
end

function LibAPH.UseContextMenuForCombo(container, build, opts)
	local enable_filter = opts and opts.enableFilter == true
	local function Open()
		local entries = build()
		if type(entries) ~= "table" or #entries == 0 then return false end
		return LibAPH.ShowContextMenu(container, entries, { rebuild = build, enableFilter = enable_filter })
	end
	container:SetHandler("OnMouseUp", function(_, button, upInside)
		if upInside and button == MOUSE_BUTTON_INDEX_LEFT then Open() end
	end)
	local arrow = container:GetNamedChild("OpenDropdown")
	if arrow then arrow:SetHandler("OnClicked", function() Open() end) end
	return Open
end
