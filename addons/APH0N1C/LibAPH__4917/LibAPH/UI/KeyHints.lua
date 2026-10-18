--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH
local THEME = LibAPH.THEME

local ICON_SIZE = 20
local CAP_HEIGHT = 18
local CAP_PADDING = 6
local KEY_GAP = 2
local LABEL_GAP = 5
local HINT_GAP = 14

local function KeyIcon(key, gamepad)
	if gamepad then return GetGamepadIconPathForKeyCode(key) end
	return GetKeyboardIconPathForKeyCode(key) or GetMouseIconPathForKeyCode(key)
end

LibAPH.GetKeyIconPath = KeyIcon

local function Paint(control, color)
	control:SetColor(color[1], color[2], color[3], color[4] or 1)
end

local function TextWidth(label, text)
	return label:GetStringWidth(text) / GetUIGlobalScale()
end

local function KeySlot(parent, name)
	local slot = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
	slot.icon = WINDOW_MANAGER:CreateControl(name .. "Icon", slot, CT_TEXTURE)
	slot.icon:SetDimensions(ICON_SIZE, ICON_SIZE)
	slot.icon:SetAnchor(CENTER, slot, CENTER, 0, 0)
	slot.cap = WINDOW_MANAGER:CreateControl(name .. "Cap", slot, CT_CONTROL)
	slot.cap:SetAnchorFill(slot)
	LibAPH.ApplyPanelBackdrop(slot.cap, name .. "CapFill", THEME.INSET)
	slot.cap.text = WINDOW_MANAGER:CreateControl(name .. "CapText", slot.cap, CT_LABEL)
	slot.cap.text:SetFont("ZoFontGameSmall")
	slot.cap.text:SetAnchor(CENTER, slot.cap, CENTER, 0, 0)
	Paint(slot.cap.text, THEME.TEXT)
	return slot
end

local function FillSlot(slot, key, gamepad)
	local path = KeyIcon(key, gamepad)
	if path then
		slot.icon:SetTexture(path)
		slot.icon:SetHidden(false)
		slot.cap:SetHidden(true)
		slot:SetDimensions(ICON_SIZE, ICON_SIZE)
		slot.shows_icon = true
		return ICON_SIZE
	end
	local text = GetKeyName(key)
	if not text or text == "" then text = tostring(key) end
	slot.icon:SetHidden(true)
	slot.cap:SetHidden(false)
	slot.cap.text:SetText(text)
	local width = TextWidth(slot.cap.text, text) + CAP_PADDING * 2
	slot:SetDimensions(width, CAP_HEIGHT)
	slot.shows_icon = false
	return width
end

function LibAPH.CreateKeyHints(parent, name, hints)
	local row = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
	row:SetHeight(ICON_SIZE)
	row.hints = {}

	for index, hint in ipairs(hints) do
		local hint_name = name .. "Hint" .. index
		local entry = { spec = hint, slots = {} }
		entry.control = WINDOW_MANAGER:CreateControl(hint_name, row, CT_CONTROL)
		entry.control:SetHeight(ICON_SIZE)
		local most = math.max(#(hint.keys or {}), #(hint.gamepadKeys or {}))
		for slot_index = 1, most do
			entry.slots[slot_index] = KeySlot(entry.control, hint_name .. "Key" .. slot_index)
		end
		entry.label = WINDOW_MANAGER:CreateControl(hint_name .. "Label", entry.control, CT_LABEL)
		entry.label:SetFont("ZoFontGameSmall")
		entry.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		Paint(entry.label, THEME.MUTED)
		entry.label:SetText(hint.text or "")
		row.hints[index] = entry
	end

	function row:Refresh()
		local gamepad = IsInGamepadPreferredMode() and true or false
		local previous
		local total = 0
		for _, entry in ipairs(self.hints) do
			local keys = entry.spec.keys
			if gamepad then keys = entry.spec.gamepadKeys end
			local shown = keys ~= nil and #keys > 0
			entry.control:SetHidden(not shown)
			if shown then
				local x = 0
				for slot_index, slot in ipairs(entry.slots) do
					local key = keys[slot_index]
					if key then
						local width = FillSlot(slot, key, gamepad)
						slot:SetHidden(false)
						slot:ClearAnchors()
						slot:SetAnchor(LEFT, entry.control, LEFT, x, 0)
						x = x + width + KEY_GAP
					else
						slot:SetHidden(true)
					end
				end
				entry.label:ClearAnchors()
				entry.label:SetAnchor(LEFT, entry.control, LEFT, x - KEY_GAP + LABEL_GAP, 0)
				local width = x - KEY_GAP + LABEL_GAP + TextWidth(entry.label, entry.spec.text or "")
				entry.control:SetWidth(width)
				entry.control:ClearAnchors()
				if previous then
					entry.control:SetAnchor(LEFT, previous, RIGHT, HINT_GAP, 0)
					total = total + HINT_GAP
				else
					entry.control:SetAnchor(LEFT, self, LEFT, 0, 0)
				end
				total = total + width
				previous = entry.control
			end
		end
		self:SetWidth(total)
		self.gamepad = gamepad
		return total
	end

	row:Refresh()
	return row
end

local PAD_HINT_PAD = 6
local PAD_HINT_GAP = 4
local PAD_HINT_SPACING = 18
local PAD_HINT_ROW_GAP = 2
local PAD_HINT_ROW_MIN = 30
local PAD_HINT_MIN_WIDTH = 300
local PAD_HINT_LEVEL_STEP = 10

local function WindowOf(control)
	if not control then return nil end
	local window = control.GetOwningWindow and control:GetOwningWindow()
	if type(window) ~= "table" and type(window) ~= "userdata" then window = control end
	return window
end

local function DrawOrder(control)
	local window = WindowOf(control)
	if not (window and window.GetDrawTier) then return nil end
	local tier, layer, level = window:GetDrawTier(), window:GetDrawLayer(), window:GetDrawLevel()
	if type(tier) ~= "number" or type(layer) ~= "number" or type(level) ~= "number" then return nil end
	return tier, layer, level
end

local function DrawAbove(box, controls)
	local tier, layer, level
	for _, control in ipairs(controls) do
		if type(control) == "function" then control = control() end
		local t, l, v = DrawOrder(control)
		if t and (not tier or t > tier or (t == tier and (l > layer or (l == layer and v > level)))) then
			tier, layer, level = t, l, v
		end
	end
	if not tier then return end
	box:SetDrawTier(tier)
	box:SetDrawLayer(layer)
	box:SetDrawLevel(level + PAD_HINT_LEVEL_STEP)
end

function LibAPH.CreatePadHintBar(name, opts)
	opts = opts or {}
	local bar = { labels = {}, text = nil, wanted = false }
	local box = WINDOW_MANAGER:CreateTopLevelWindow(name)
	box:SetDrawTier(DT_HIGH)
	box:SetHidden(true)
	LibAPH.ApplyPanelBackdrop(box, name .. "BG", THEME.BG_HUD)
	bar.box = box
	if opts.parent and ZO_PostHookHandler then
		ZO_PostHookHandler(opts.parent, "OnEffectivelyHidden", function() box:SetHidden(true) end)
		ZO_PostHookHandler(opts.parent, "OnEffectivelyShown", function()
			if bar.wanted and bar.owner and not bar.owner:IsHidden() then box:SetHidden(false) end
		end)
	end

	local function Label(index)
		local label = bar.labels[index]
		if not label then
			label = WINDOW_MANAGER:CreateControl(name .. "Hint" .. index, box, CT_LABEL)
			label:SetFont(opts.font or "ZoFontGamepad18")
			label:SetColor(0.9, 0.9, 0.9, 1)
			label:SetMaxLineCount(1)
			bar.labels[index] = label
		end
		return label
	end

	function bar:Hide()
		box:SetHidden(true)
		self.text, self.owner, self.wanted = nil, nil, false
		return 0, 0
	end

	function bar:Show(owner, parts)
		if not owner or #parts == 0 then return self:Hide() end
		if opts.parent and opts.parent:IsHidden() then return self:Hide() end
		local above = { owner, opts.parent }
		for _, extra in ipairs(opts.above or {}) do above[#above + 1] = extra end
		DrawAbove(box, above)
		local width = math.max(owner:GetWidth(), opts.minWidth or PAD_HINT_MIN_WIDTH)
		local inner = width - PAD_HINT_PAD * 2
		local rows, row = {}, { items = {}, width = 0, height = PAD_HINT_ROW_MIN }
		for index, text in ipairs(parts) do
			local label = Label(index)
			label:SetText(text)
			label:SetHidden(false)
			local item_w, item_h = label:GetTextWidth(), label:GetTextHeight()
			if #row.items > 0 and row.width + PAD_HINT_SPACING + item_w > inner then
				rows[#rows + 1] = row
				row = { items = {}, width = 0, height = PAD_HINT_ROW_MIN }
			end
			row.width = row.width + (#row.items > 0 and PAD_HINT_SPACING or 0) + item_w
			row.items[#row.items + 1] = { label = label, width = item_w }
			row.height = math.max(row.height, item_h)
		end
		rows[#rows + 1] = row
		for index = #parts + 1, #self.labels do self.labels[index]:SetHidden(true) end
		local y = PAD_HINT_PAD
		for _, line in ipairs(rows) do
			local x = PAD_HINT_PAD
			for _, item in ipairs(line.items) do
				item.label:ClearAnchors()
				item.label:SetAnchor(LEFT, box, TOPLEFT, x, y + line.height / 2)
				x = x + item.width + PAD_HINT_SPACING
			end
			y = y + line.height + PAD_HINT_ROW_GAP
		end
		local height = y - PAD_HINT_ROW_GAP + PAD_HINT_PAD
		box:SetDimensions(width, height)
		box:ClearAnchors()
		self.text, self.owner, self.rows, self.wanted = table.concat(parts, "   "), owner, #rows, true
		box:SetHidden(false)
		if owner:GetBottom() + PAD_HINT_GAP + height > GuiRoot:GetHeight() then
			box:SetAnchor(BOTTOMLEFT, owner, TOPLEFT, 0, -PAD_HINT_GAP)
			return 0, height + PAD_HINT_GAP
		end
		box:SetAnchor(TOPLEFT, owner, BOTTOMLEFT, 0, PAD_HINT_GAP)
		return height + PAD_HINT_GAP, 0
	end

	function bar:GetText()
		if box:IsHidden() then return nil end
		return self.text
	end

	function bar:IsShown()
		return not box:IsHidden()
	end

	return bar
end
