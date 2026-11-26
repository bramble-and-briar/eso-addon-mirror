--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

LibAPH.THEME = {
	BG = { 0.04, 0.04, 0.05, 1 },
	BG_HUD = { 0.04, 0.04, 0.05, 0.85 },
	EDGE = { 0.26, 0.26, 0.3, 1 },
	HEADER = { 1, 1, 1, 0.06 },
	INSET = { 0.08, 0.08, 0.1, 1 },
	STRIPE = { 1, 1, 1, 0.03 },
	SECTION = { 1, 1, 1, 0.08 },
	TRACK = { 1, 1, 1, 0.12 },
	THUMB = { 0.8, 0.8, 0.8, 0.7 },
	TEXT = { 0.85, 0.85, 0.85, 1 },
	MUTED = { 0.62, 0.62, 0.66, 1 },
	ACCENT = { 0.65, 0.78, 1, 1 },
	HIGHLIGHT = { 0.35, 0.45, 0.6, 0.45 },
	SELECTED = { 1, 1, 0.3, 1 },
	HOVER = { 1, 1, 1, 0.08 },
	PICK = { 0.45, 0.75, 0.25, 0.3 },
	SECTION_BLUE = { 0.3, 0.45, 0.8, 0.22 },
	DANGER = { 1, 0.35, 0.35, 1 },
	GREEN = { 0.61, 0.82, 0.3, 1 },
	TITLE_HEX = "9CD04C",
	HEADER_H = 30,
	CLOSE_SIZE = 20,
	BUTTON_GAP = 6,
	SCROLLBAR_W = 6,
	MIN_THUMB_H = 16,
}
local THEME = LibAPH.THEME
local CLOSED_REASON = "LibAPHClosed"

local function Paint(control, color)
	control:SetColor(color[1], color[2], color[3], color[4] or 1)
end

local pixel_lines = setmetatable({}, { __mode = "k" })

function LibAPH.PixelSize()
	local scale = GetUIGlobalScale()
	if type(scale) ~= "number" or scale <= 0 then return 1 end
	return 1 / scale
end

local function SizeLine(line)
	local size = LibAPH.PixelSize()
	if line.libaph_vertical then line:SetWidth(size) else line:SetHeight(size) end
end

local BORDER_SIDES = {
	{ "Top", TOPLEFT, TOPRIGHT, false },
	{ "Bottom", BOTTOMLEFT, BOTTOMRIGHT, false },
	{ "Left", TOPLEFT, BOTTOMLEFT, true },
	{ "Right", TOPRIGHT, BOTTOMRIGHT, true },
}

function LibAPH.AddPixelBorder(control, name, color)
	color = color or THEME.EDGE
	local lines = {}
	for _, side in ipairs(BORDER_SIDES) do
		local line = WINDOW_MANAGER:CreateControl(name and (name .. side[1]), control, CT_TEXTURE)
		Paint(line, color)
		line:SetMouseEnabled(false)
		line:SetAnchor(side[2], control, side[2], 0, 0)
		line:SetAnchor(side[3], control, side[3], 0, 0)
		line.libaph_vertical = side[4]
		SizeLine(line)
		pixel_lines[line] = true
		lines[side[1]:lower()] = line
	end
	return lines
end

EVENT_MANAGER:RegisterForEvent("LibAPH_PixelBorders", EVENT_ALL_GUI_SCREENS_RESIZED, function()
	for line in pairs(pixel_lines) do SizeLine(line) end
end)

function LibAPH.ApplyPanelBackdrop(win, name, fill)
	local backdrop = WINDOW_MANAGER:CreateControl(name, win, CT_BACKDROP)
	local center = fill or THEME.BG
	backdrop:SetAnchorFill(win)
	backdrop:SetCenterColor(center[1], center[2], center[3], center[4] or 1)
	backdrop:SetEdgeTexture("", 1, 1, 1)
	backdrop:SetEdgeColor(0, 0, 0, 0)
	backdrop.libaph_border = LibAPH.AddPixelBorder(backdrop, name and (name .. "Edge"))
	return backdrop
end

local green_hooked = false

local function TintSelection(dropdown, control)
	local highlight = control.m_selectionHighlight
	if not highlight then return end
	if dropdown.owner and dropdown.owner.libaph_text_selection then
		highlight:SetHidden(true)
		return
	end
	local color = dropdown.owner and dropdown.owner.libaph_green_selection and THEME.SELECTED or nil
	if color then
		highlight:SetCenterColor(color[1], color[2], color[3], color[4])
		highlight:SetEdgeColor(color[1], color[2], color[3], color[4])
	else
		highlight:SetCenterColor(1, 1, 1, 1)
		highlight:SetEdgeColor(1, 1, 1, 1)
	end
end

local function HookSelectionTint()
	local dropdown = ZO_COMBO_BOX_DROPDOWN_KEYBOARD
	if not green_hooked and dropdown then
		green_hooked = true
		ZO_PostHook(dropdown, "SetupEntryBase", TintSelection)
	end
end

function LibAPH.UseGreenSelection(combo)
	if not combo then return false end
	combo.libaph_green_selection = true
	HookSelectionTint()
	return true
end

function LibAPH.UseTextSelection(combo)
	if not combo then return false end
	combo.libaph_text_selection = true
	local selected
	local base = combo.GetItemNormalColor
	combo.GetItemNormalColor = function(self, item)
		if item.enabled ~= false then
			local source = item.GetDataSource and item:GetDataSource() or item
			if self:IsItemSelected(source) then
				selected = selected or ZO_ColorDef:New(THEME.SELECTED[1], THEME.SELECTED[2], THEME.SELECTED[3], THEME.SELECTED[4])
				return selected
			end
		end
		return base(self, item)
	end
	HookSelectionTint()
	return true
end

function LibAPH.CreateHeaderStrip(win, name, height)
	local strip = WINDOW_MANAGER:CreateControl(name, win, CT_TEXTURE)
	Paint(strip, THEME.HEADER)
	strip:SetMouseEnabled(false)
	strip:SetAnchor(TOPLEFT, win, TOPLEFT, 1, 1)
	strip:SetAnchor(TOPRIGHT, win, TOPRIGHT, -1, 1)
	strip:SetHeight(height or THEME.HEADER_H)
	return strip
end

function LibAPH.CreateThemedCloseButton(win, name, onClick, right, top)
	local close = WINDOW_MANAGER:CreateControlFromVirtual(name, win, "ZO_CloseButton")
	close:ClearAnchors()
	close:SetDimensions(THEME.CLOSE_SIZE, THEME.CLOSE_SIZE)
	close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -(right or 8), top or 8)
	close:SetHandler("OnClicked", onClick)
	return close
end

function LibAPH.StyleRowBackground(texture, index, is_section)
	if is_section then
		Paint(texture, THEME.SECTION)
		texture:SetHidden(false)
	elseif index % 2 == 0 then
		Paint(texture, THEME.STRIPE)
		texture:SetHidden(false)
	else
		texture:SetHidden(true)
	end
end

local SILENT_FADE = {
	Stop = function() end,
	PlayFromStart = function() end,
	SetAlphaValues = function() end,
}

function LibAPH.StyleScrollList(list, name)
	local bar = list:GetNamedChild("ScrollBar")
	if not bar then return nil end
	bar:SetAlpha(0)
	bar.timeline = SILENT_FADE
	bar.alphaAnimation = SILENT_FADE

	local track = WINDOW_MANAGER:CreateControl(name and (name .. "Track"), list, CT_TEXTURE)
	Paint(track, THEME.TRACK)
	track:SetMouseEnabled(false)
	local thumb = WINDOW_MANAGER:CreateControl(name and (name .. "Thumb"), list, CT_TEXTURE)
	Paint(thumb, THEME.THUMB)
	thumb:SetMouseEnabled(false)
	thumb:SetDrawLevel(2)

	local mirror = { bar = bar, track = track, thumb = thumb }
	function mirror:Sync()
		bar:SetAlpha(0)
		local shown = not bar:IsHidden()
		track:SetHidden(not shown)
		thumb:SetHidden(not shown)
		if not shown then return false end

		local top, bottom = bar:GetTop(), bar:GetBottom()
		local span = math.max((bottom or 0) - (top or 0), 1)
		track:ClearAnchors()
		track:SetAnchor(TOPRIGHT, bar, TOPRIGHT, -((bar:GetWidth() - THEME.SCROLLBAR_W) / 2), 0)
		track:SetDimensions(THEME.SCROLLBAR_W, span)

		local min, max = bar:GetMinMax()
		local value = bar:GetValue()
		local native_thumb = bar:GetThumbTextureControl()
		local thumb_h = native_thumb and native_thumb:GetHeight() or THEME.MIN_THUMB_H
		thumb_h = zo_clamp(thumb_h, math.min(THEME.MIN_THUMB_H, span), span)
		local fraction = (max or 0) > (min or 0) and (value - min) / (max - min) or 0
		thumb:ClearAnchors()
		thumb:SetAnchor(TOPLEFT, track, TOPLEFT, 0, (span - thumb_h) * fraction)
		thumb:SetDimensions(THEME.SCROLLBAR_W, thumb_h)
		self.fraction, self.thumb_h = fraction, thumb_h
		return true
	end

	local function Sync() mirror:Sync() end
	ZO_PostHookHandler(bar, "OnValueChanged", Sync)
	ZO_PostHookHandler(bar, "OnEffectivelyShown", Sync)
	ZO_PostHookHandler(bar, "OnEffectivelyHidden", Sync)
	ZO_PostHookHandler(bar, "OnRectChanged", Sync)
	mirror:Sync()
	return mirror
end

function LibAPH.CreateStickyFragment(control, scenes)
	local fragment = ZO_HUDFadeSceneFragment:New(control)
	fragment:SetHiddenForReason(CLOSED_REASON, true)
	LibAPH.AddFragmentToScenes(fragment, scenes or { "hud", "hudui" })
	local sticky = { fragment = fragment, control = control }
	function sticky:Open()
		fragment:SetHiddenForReason(CLOSED_REASON, false)
		control:SetHidden(false)
	end
	function sticky:Close()
		fragment:SetHiddenForReason(CLOSED_REASON, true)
		control:SetHidden(true)
	end
	function sticky:IsOpen()
		return not control:IsHidden()
	end
	return sticky
end
