--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local LibAPH = LibAPH

local KEYBOARD_FONTS = { "ZoFontWinH4", "ZoFontWinH5", "ZoFontGameBold", "ZoFontGame", "ZoFontGameSmall", "$(BOLD_FONT)|11|soft-shadow-thin" }
local GAMEPAD_FONTS = { "ZoFontGamepad22", "ZoFontGamepad20", "ZoFontGamepad18", "$(GAMEPAD_MEDIUM_FONT)|16|soft-shadow-thick", "$(GAMEPAD_MEDIUM_FONT)|14|soft-shadow-thick" }
local KEYBIND_FONTS = { "ZoFontDialogKeybindDescription", "ZoFontGame", "ZoFontGameSmall", "$(BOLD_FONT)|11|soft-shadow-thin" }
local BUTTON_PADDING = 14
local MIN_BUTTON_WIDTH = 40

local row_counter = 0

LibAPH.FIT_FONTS = KEYBOARD_FONTS
LibAPH.FIT_FONTS_GAMEPAD = GAMEPAD_FONTS

local function TextWidth(label, text)
	return label:GetStringWidth(text) / GetUIGlobalScale()
end

local function FontLadder(opts)
	if opts and opts.fonts then return opts.fonts end
	return IsInGamepadPreferredMode() and GAMEPAD_FONTS or KEYBOARD_FONTS
end

local function StartAt(fonts, font)
	for i = 1, #fonts do
		if fonts[i] == font then return i end
	end
	return 1
end

local function KeybindLabel(button)
	return button.GetNamedChild and button:GetNamedChild("NameLabel")
end

function LibAPH.FitButtonText(button, opts)
	if not button then return nil end
	opts = opts or {}
	local label = button.GetLabelControl and button:GetLabelControl()
	if not label then return nil end
	local fonts = FontLadder(opts)
	button.libaph_fit_font = button.libaph_fit_font or opts.font
	local text = label:GetText() or ""
	local room = button:GetWidth() - (opts.padding or BUTTON_PADDING)
	local chosen = fonts[#fonts]
	for i = StartAt(fonts, opts.font or button.libaph_fit_font), #fonts do
		button:SetFont(fonts[i])
		if TextWidth(label, text) <= room then
			chosen = fonts[i]
			break
		end
	end
	button:SetFont(chosen)
	return chosen
end

local KEY_GAP = 15

local function KeybindWidth(button, label, font, text)
	label:SetFont(font)
	local key = button:GetNamedChild("KeyLabel")
	local key_text = key and key:GetText() or ""
	local key_part = key and key_text ~= "" and (TextWidth(key, key_text) + KEY_GAP) or 0
	return key_part + TextWidth(label, text)
end

function LibAPH.FitButtonRow(container, buttons, opts)
	opts = opts or {}
	local gap = opts.gap or 10
	local preferred = {}
	for i, button in ipairs(buttons) do
		preferred[i] = button:GetWidth()
	end
	local last_room

	local function Room()
		if opts.room then return opts.room() end
		return container:GetWidth() - 2 * (opts.margin or 0)
	end

	local function Fit()
		local room = Room() - gap * math.max(0, #buttons - 1)
		if room <= 0 or room == last_room then return end
		last_room = room
		local fonts = opts.keybindFonts or KEYBIND_FONTS

		local fixed_total = 0
		for i, button in ipairs(buttons) do
			if button.GetLabelControl then fixed_total = fixed_total + preferred[i] end
		end

		local chosen = fonts[1]
		for f = 1, #fonts do
			chosen = fonts[f]
			local total = fixed_total
			for _, button in ipairs(buttons) do
				local label = KeybindLabel(button)
				if label and not button.GetLabelControl then
					total = total + KeybindWidth(button, label, chosen, label:GetText() or "")
				end
			end
			if total <= room then break end
		end

		local keybind_total = 0
		for _, button in ipairs(buttons) do
			local label = KeybindLabel(button)
			if label and not button.GetLabelControl then
				label:SetFont(chosen)
				keybind_total = keybind_total + KeybindWidth(button, label, chosen, label:GetText() or "")
			end
		end

		local scale = fixed_total > 0 and math.min(1, math.max(0, room - keybind_total) / fixed_total) or 1
		for i, button in ipairs(buttons) do
			if button.GetLabelControl then
				button:SetWidth(math.max(MIN_BUTTON_WIDTH, math.floor(preferred[i] * scale)))
				LibAPH.FitButtonText(button, opts)
			end
		end
	end

	function opts.Refit()
		last_room = nil
		Fit()
	end

	row_counter = row_counter + 1
	container:SetHandler("OnRectChanged", Fit, "LibAPH_FitRow" .. row_counter)
	Fit()
	return opts.Refit
end

local function Plain(text)
	return (tostring(text or ""):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function PlainWidth(label, text)
	return label:GetStringWidth(Plain(text)) / GetUIGlobalScale()
end

local function Trim(text)
	return (text:gsub("%s+$", ""))
end

local function Split(text, sep)
	local parts, from = {}, 1
	while true do
		local at = text:find(sep, from, true)
		if not at then
			parts[#parts + 1] = text:sub(from)
			return parts
		end
		parts[#parts + 1] = text:sub(from, at + #sep - 1)
		from = at + #sep
	end
end

local WRAP_SEPARATORS = { ", ", " " }

local function WrapPiece(label, text, width, separators, level, lines)
	if level > #separators or PlainWidth(label, text) <= width then
		lines[#lines + 1] = text
		return PlainWidth(label, text) > width
	end
	local current, overflow = nil, false
	for _, piece in ipairs(Split(text, separators[level])) do
		local candidate = current and (current .. piece) or piece
		if current and PlainWidth(label, Trim(candidate)) > width then
			overflow = WrapPiece(label, Trim(current), width, separators, level + 1, lines) or overflow
			current = piece
		else
			current = candidate
		end
	end
	if current then overflow = WrapPiece(label, Trim(current), width, separators, level + 1, lines) or overflow end
	return overflow
end

function LibAPH.WrapText(label, text, width, opts)
	text = tostring(text or "")
	if text == "" then return "", 1, false end
	local separators = opts and opts.separators or WRAP_SEPARATORS
	local lines, overflow = {}, false
	for paragraph in (text .. "\n"):gmatch("(.-)\n") do
		overflow = WrapPiece(label, paragraph, width, separators, 1, lines) or overflow
	end
	return table.concat(lines, "\n"), #lines, overflow
end

function LibAPH.FitLabelText(label, text, opts)
	if not label then return false end
	opts = opts or {}
	label.libaph_fit_font = opts.font or label.libaph_fit_font or label:GetFont()
	local base = label.libaph_fit_font
	label:SetText(text)
	local room = opts.width or label:GetWidth()
	local face, size, effect = tostring(base):match("^(.-)|(%d+)|?(.*)$")
	if face then
		for step = tonumber(size), opts.minSize or 8, -1 do
			label:SetFont(face .. "|" .. step .. (effect ~= "" and ("|" .. effect) or ""))
			if PlainWidth(label, text) <= room then return true end
		end
		return false
	end
	local fonts = opts.fonts
	if not fonts then
		for _, ladder in ipairs({ GAMEPAD_FONTS, KEYBOARD_FONTS, KEYBIND_FONTS }) do
			for _, name in ipairs(ladder) do
				if name == base then fonts = ladder break end
			end
			if fonts then break end
		end
	end
	if not fonts then
		label:SetFont(base)
		return PlainWidth(label, text) <= room
	end
	for i = StartAt(fonts, base), #fonts do
		label:SetFont(fonts[i])
		if PlainWidth(label, text) <= room then return true end
	end
	return false
end

function LibAPH.RaiseLabel(label, opts)
	if not label then return nil end
	opts = opts or {}
	local level = opts.level or 20
	local layer = opts.layer or label:GetDrawLayer()
	if opts.layer then label:SetDrawLayer(opts.layer) end
	label:SetDrawLevel(level)
	if opts.backdrop == false then return nil end
	local back = label.libaph_backdrop
	if not back then
		back = WINDOW_MANAGER:CreateControl(nil, label, CT_TEXTURE)
		label.libaph_backdrop = back
		local pad_x, pad_y = opts.padX or 3, opts.padY or 1
		back:SetAnchor(TOPLEFT, label, TOPLEFT, -pad_x, -pad_y)
		back:SetAnchor(BOTTOMRIGHT, label, BOTTOMRIGHT, pad_x, pad_y)
	end
	local color = opts.color or { 0, 0, 0, 0.75 }
	back:SetColor(color[1], color[2], color[3], color[4] or 1)
	if layer then back:SetDrawLayer(layer) end
	back:SetDrawLevel(level - 1)
	return back
end
