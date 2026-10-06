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
