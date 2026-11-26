--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local DEFAULT_TICK_STEPS = { 1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600 }

function LibAPH.NiceGraphStep(range)
	if range <= 0 then return 1 end
	local magnitude = 10 ^ math.floor(math.log10(range))
	for _, factor in ipairs({ 1, 2, 2.5, 5, 10 }) do
		if factor * magnitude >= range then return factor * magnitude end
	end
	return 10 * magnitude
end

function LibAPH.GraphTickStep(span, target, steps)
	steps = steps or DEFAULT_TICK_STEPS
	for _, step in ipairs(steps) do
		if span / step <= (target or 8) then return step end
	end
	return steps[#steps]
end

function LibAPH.FormatClock(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

function LibAPH.CreateGraphCanvas(area, opts)
	opts = opts or {}
	local levels = opts.levels or {}
	local canvas = { pools = {}, used = {}, labels = {}, label_used = {} }

	function canvas:Texture(kind)
		local list = self.pools[kind]
		if not list then
			list = {}
			self.pools[kind] = list
		end
		local index = (self.used[kind] or 0) + 1
		self.used[kind] = index
		local texture = list[index]
		if not texture then
			texture = WINDOW_MANAGER:CreateControl(nil, area, CT_TEXTURE)
			texture:SetDrawLayer(DL_CONTROLS)
			list[index] = texture
		end
		texture:SetDrawLevel(levels[kind] or 2)
		return texture
	end

	function canvas:Rect(kind, x, y, w, h, color)
		local texture = self:Texture(kind)
		texture:ClearAnchors()
		texture:SetAnchor(TOPLEFT, area, TOPLEFT, x, y)
		texture:SetDimensions(math.max(w, 1), math.max(h, 1))
		texture:SetColor(color[1], color[2], color[3], color[4] or 1)
		texture:SetHidden(false)
		return texture
	end

	function canvas:Text(kind, text, color)
		local list = self.labels[kind]
		if not list then
			list = {}
			self.labels[kind] = list
		end
		local index = (self.label_used[kind] or 0) + 1
		self.label_used[kind] = index
		local label = list[index]
		if not label then
			label = WINDOW_MANAGER:CreateControl(nil, area, CT_LABEL)
			LibAPH.RaiseLabel(label, { layer = DL_CONTROLS, level = levels.text or 9, backdrop = false })
			list[index] = label
		end
		color = color or opts.textColor or { 1, 1, 1, 1 }
		label:SetFont(opts.font and opts.font() or (IsConsoleUI() and "ZoFontGamepad18" or "ZoFontGameSmall"))
		label:SetColor(color[1], color[2], color[3], color[4] or 1)
		label:SetText(text)
		label:SetHidden(false)
		return label
	end

	function canvas:Line(plot, values, low, high, color_of, thickness)
		thickness = thickness or 2
		local slices = #values
		local bar_w = plot.w / slices
		local previous
		for slot = 1, slices do
			local value = values[slot]
			if value then
				local y = plot.y + plot.h - zo_clamp((value - low) / (high - low), 0, 1) * plot.h
				local color = color_of(value)
				self:Rect("line", plot.x + (slot - 1) * bar_w, y - thickness / 2, bar_w, thickness, color)
				if previous and math.abs(previous - y) >= 1 then
					self:Rect("line", plot.x + (slot - 1) * bar_w - thickness / 2, math.min(previous, y), thickness, math.abs(previous - y), color)
				end
				previous = y
			else
				previous = nil
			end
		end
	end

	function canvas:Begin()
		for kind in pairs(self.used) do self.used[kind] = 0 end
		for kind in pairs(self.label_used) do self.label_used[kind] = 0 end
	end

	function canvas:Finish()
		for kind, list in pairs(self.pools) do
			for index = (self.used[kind] or 0) + 1, #list do list[index]:SetHidden(true) end
		end
		for kind, list in pairs(self.labels) do
			for index = (self.label_used[kind] or 0) + 1, #list do list[index]:SetHidden(true) end
		end
	end

	return canvas
end
