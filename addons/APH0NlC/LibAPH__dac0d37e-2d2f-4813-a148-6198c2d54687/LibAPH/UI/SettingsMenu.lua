--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local CURRENT = "|c00FF00%s|r"
local NUMBER_CHARS = 10

local function Value(value)
	if type(value) == "function" then return value() end
	return value
end

local function Plain(text)
	text = tostring(text or "")
	if LibAPH.StripColors then return LibAPH.StripColors(text) end
	return (text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function Enabled(control)
	return control.disabled == nil or Value(control.disabled) ~= true
end

local function NumberText(value)
	if type(value) ~= "number" then return tostring(value) end
	if value == math.floor(value) then return string.format("%d", value) end
	return string.format("%.2f", value)
end

local function Snap(number, control)
	local low, high, step = Value(control.min), Value(control.max), Value(control.step)
	if type(step) == "number" and step > 0 and type(low) == "number" then
		number = low + math.floor((number - low) / step + 0.5) * step
	end
	if type(low) == "number" and number < low then number = low end
	if type(high) == "number" and number > high then number = high end
	return number
end

local Entries

local function DropdownEntry(control, name, enabled, tip)
	local names = Value(control.choices) or {}
	local values = Value(control.choicesValues) or names
	local current = control.getFunc()
	local shown = tostring(current)
	for index, value in ipairs(values) do
		if value == current then shown = tostring(names[index] or value) end
	end
	return {
		text = name .. ": " .. string.format(CURRENT, Plain(shown)),
		enabled = enabled,
		tooltip = tip,
		submenu = function()
			local list = {}
			local now = control.getFunc()
			for index, value in ipairs(values) do
				local label = Plain(names[index] or value)
				list[#list + 1] = {
					text = value == now and string.format(CURRENT, label) or label,
					onClick = function() control.setFunc(value) end,
				}
			end
			return list
		end,
	}
end

local function NumberEntry(control, name, enabled, tip, opts)
	local value = control.getFunc()
	return {
		text = name .. ": " .. string.format(CURRENT, NumberText(value)),
		enabled = enabled,
		tooltip = tip,
		onClick = function()
			local low, high = Value(control.min), Value(control.max)
			opts.askText({
				id = (opts.id or "LibAPH") .. "_Setting",
				title = Plain(name),
				body = (type(low) == "number" and type(high) == "number" and opts.rangeText)
					and string.format(opts.rangeText, NumberText(low), NumberText(high)) or Plain(tip or name),
				prompt = Plain(name),
				initial = NumberText(control.getFunc()),
				maxChars = NUMBER_CHARS,
				onConfirm = function(text)
					local number = tonumber((tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")))
					if number then control.setFunc(Snap(number, control)) end
				end,
			})
		end,
	}
end

local function ButtonEntry(control, name, enabled, tip, opts)
	local warning = Value(control.warning)
	local dangerous = control.isDangerous == true or warning ~= nil
	return {
		text = name,
		enabled = enabled,
		tooltip = tip or warning,
		danger = control.isDangerous == true or nil,
		onClick = function()
			if dangerous and opts.confirm then
				opts.confirm((opts.id or "LibAPH") .. "_SettingConfirm", Plain(name), Plain(warning or tip or name), control.func)
				return
			end
			control.func()
		end,
	}
end

local function Entry(control, opts)
	local kind = control.type
	local name = Value(control.name)
	local enabled = Enabled(control)
	local tip = Value(control.tooltip)
	if kind == "header" then
		return { text = Plain(name), header = true }
	elseif kind == "divider" then
		return { divider = true }
	elseif kind == "checkbox" then
		return {
			text = name, checkbox = true, checked = control.getFunc() == true, enabled = enabled, tooltip = tip,
			onToggle = function(on) control.setFunc(on and true or false) end,
		}
	elseif kind == "dropdown" then
		return DropdownEntry(control, name, enabled, tip)
	elseif (kind == "slider" or kind == "editbox") and opts.askText then
		return NumberEntry(control, name, enabled, tip, opts)
	elseif kind == "button" and type(control.func) == "function" then
		return ButtonEntry(control, name, enabled, tip, opts)
	elseif kind == "submenu" then
		local inner = control.controls or {}
		return { text = Plain(name), submenu = function() return Entries(inner, opts) end }
	end
	return nil
end

Entries = function(controls, opts)
	local list = {}
	for _, control in ipairs(controls or {}) do
		local entry = type(control) == "table" and Entry(control, opts) or nil
		if entry and not (entry.divider and (#list == 0 or list[#list].divider)) then list[#list + 1] = entry end
	end
	while #list > 0 and list[#list].divider do list[#list] = nil end
	return list
end

function LibAPH.SettingsMenuEntries(controls, opts)
	return Entries(controls, opts or {})
end

