--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

function LibAPH.SetTextIfChanged(label, text)
	if label.aph_text == text then return false end
	label.aph_text = text
	label:SetText(text)
	return true
end

local STACK_GAP = 4
local stacks = {}

local function Restack(group)
	local above
	for _, entry in ipairs(stacks[group]) do
		if entry.window and not entry.window:IsHidden() then
			entry.Place(above)
			entry.stacked = true
			above = entry.label
		end
	end
end

local function JoinStack(group, line, order)
	local list = stacks[group]
	if not list then
		list = {}
		stacks[group] = list
	end
	for index = #list, 1, -1 do
		if list[index].name == line.name then table.remove(list, index) end
	end
	line.order = order or (#list + 1)
	local at = #list + 1
	for index, entry in ipairs(list) do
		if line.order < entry.order then
			at = index
			break
		end
	end
	table.insert(list, at, line)
end

function LibAPH.CreateStatusLine(name, opts)
	opts = opts or {}
	local line = { name = name }

	local function Window() return line.window or _G[name] end
	local function Label() return line.label or _G[name .. "Text"] end

	function line.Place(above)
		local point = opts.point or TOPRIGHT
		local relative_point = opts.relativePoint or point
		local x, y = opts.offsetX or -9, opts.offsetY or 40
		if IsConsoleUI() then x, y = opts.consoleOffsetX or -150, opts.consoleOffsetY or 60 end
		local target = opts.relativeTo or GuiRoot
		if type(target) == "string" then target = _G[target] or GuiRoot end
		line.label:ClearAnchors()
		if above then
			line.label:SetAnchor(point, above, relative_point, 0, opts.gap or STACK_GAP)
		else
			line.label:SetAnchor(point, target, relative_point, x, y)
		end
	end

	local function Build()
		if line.window then return end
		line.window = _G[name] or WINDOW_MANAGER:CreateTopLevelWindow(name)
		line.label = _G[name .. "Text"] or WINDOW_MANAGER:CreateControl(name .. "Text", line.window, CT_LABEL)
		line.label:SetFont(opts.font or "ZoFontGameMedium")
		line.label:SetHorizontalAlignment(opts.align or TEXT_ALIGN_RIGHT)
		line.label:SetWidth(opts.width or 640)
		line.Place()
	end

	if opts.stack then JoinStack(opts.stack, line, opts.order) end

	function line:Set(text)
		Build()
		local was_hidden = self.window:IsHidden()
		self.window:SetHidden(false)
		LibAPH.SetTextIfChanged(self.label, text)
		if opts.stack and (was_hidden or not line.stacked) then Restack(opts.stack) end
	end

	function line:Hide()
		local window = Window()
		if not window or window:IsHidden() then return end
		window:SetHidden(true)
		if opts.stack then Restack(opts.stack) end
	end

	function line:GetText()
		local window, label = Window(), Label()
		if not (window and label) or window:IsHidden() then return nil end
		return label:GetText()
	end

	return line
end
