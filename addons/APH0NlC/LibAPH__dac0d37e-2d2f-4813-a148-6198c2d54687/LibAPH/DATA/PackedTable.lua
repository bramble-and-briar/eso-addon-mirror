--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local packed_rows = {}
local ROW_PATTERN = "^([^\t]*)\t?([^\t]*)\t?([^\t]*)\t?([^\t]*)\t?([^\t]*)\t?([^\t]*)\t?([^\t]*)"

local function EmptyToNil(value)
	if value == "" then return nil end
	return value
end

local function Utf8Char(code)
	code = tonumber(code)
	if not code or code < 1 or code > 0x10FFFF then return nil end
	if code < 0x80 then return string.char(code) end
	if code < 0x800 then return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40) end
	if code < 0x10000 then
		return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
	end
	return string.char(0xF0 + math.floor(code / 0x40000), 0x80 + math.floor(code / 0x1000) % 0x40,
		0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
end

local function DecodeEntities(text)
	if type(text) ~= "string" or not string.find(text, "&#", 1, true) then return text end
	text = string.gsub(text, "&#[xX](%x+);", function(hex) return Utf8Char(tonumber(hex, 16)) end)
	return (string.gsub(text, "&#(%d+);", Utf8Char))
end

LibAPH.DecodeEntities = DecodeEntities
LibAPH.PACKED_ROW_PATTERN = ROW_PATTERN
LibAPH.PackedEmptyToNil = EmptyToNil

local function ParseVersionRow(line)
	local _, required, display, esoui_id, api, full_name, short_name = string.match(line, ROW_PATTERN)
	return {
		requiredVersion = tonumber(required),
		displayVersion = EmptyToNil(display),
		esouiId = tonumber(esoui_id),
		apiVersion = EmptyToNil(api),
		fullName = EmptyToNil(DecodeEntities(full_name)),
		shortName = EmptyToNil(DecodeEntities(short_name)),
	}
end

function LibAPH.CreatePackedTable(rows, parseRow)
	rows = "\n" .. rows
	parseRow = parseRow or ParseVersionRow
	local row_start
	local packed = setmetatable({}, { __index = function(self, name)
		if not row_start then
			row_start = {}
			for start, row_name in string.gmatch(rows, "\n()([^\t\n]+)") do
				row_start[row_name] = start
			end
		end
		local start = row_start[name]
		if not start then return nil end
		local entry = parseRow(string.sub(rows, start, string.find(rows, "\n", start, true) - 1))
		rawset(self, name, entry)
		return entry
	end })
	packed_rows[packed] = rows
	return packed
end

function LibAPH.CreatePackedConsoleTable(rows)
	return LibAPH.CreatePackedTable(rows, function(line)
		local _, required, display, api, title, author, addon_id = string.match(line, ROW_PATTERN)
		return {
			requiredVersion = tonumber(required),
			displayVersion = EmptyToNil(display),
			apiVersion = EmptyToNil(api),
			title = EmptyToNil(DecodeEntities(title)),
			author = EmptyToNil(DecodeEntities(author)),
			addonId = EmptyToNil(addon_id),
			console = true,
		}
	end)
end

function LibAPH.CreatePackedListTable(rows)
	return LibAPH.CreatePackedTable(rows, function(line)
		local list = {}
		for value in string.gmatch(line, "[^\t]+") do
			list[#list + 1] = value
		end
		table.remove(list, 1)
		return list
	end)
end

function LibAPH.CreatePackedValueTable(rows)
	return LibAPH.CreatePackedTable(rows, function(line)
		return (string.match(line, "^[^\t]*\t(.*)$"))
	end)
end

function LibAPH.GetPackedTableNames(packed)
	local names = {}
	for name in string.gmatch(packed_rows[packed] or "", "\n([^\t\n]+)") do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end
