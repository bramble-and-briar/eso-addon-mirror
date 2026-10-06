--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local LibAPH = LibAPH

local KEYBOARD_FONTS = { "ZoFontWinH4", "ZoFontWinH5", "ZoFontGameBold", "ZoFontGame", "ZoFontGameSmall", "ZoFontGameTiny" }
local GAMEPAD_FONTS = { "ZoFontGamepad22", "ZoFontGamepad20", "ZoFontGamepad18", "ZoFontGamepad16", "ZoFontGamepad14" }
local KEYBIND_FONTS = { "ZoFontDialogKeybindDescription", "ZoFontGame", "ZoFontGameSmall", "ZoFontGameTiny" }
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
