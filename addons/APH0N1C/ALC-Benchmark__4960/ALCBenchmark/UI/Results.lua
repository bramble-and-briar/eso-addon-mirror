--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local FONT_FACE, FONT_SIZE, MIN_FONT, MAX_FONT, WIN, THEME = AB.FONT_FACE, AB.FONT_SIZE, AB.MIN_FONT, AB.MAX_FONT, AB.WIN, AB.THEME
local view, HEADER_LINES, Tint, ROWS, CellText, BAD = AB.view, AB.HEADER_LINES, AB.Tint, AB.ROWS, AB.CellText, AB.BAD
local GOOD, DeltaText = AB.GOOD, AB.DeltaText

AB.scale = 1

local function Font()
	return FONT_FACE .. "|" .. zo_clamp(zo_round(FONT_SIZE * AB.scale), MIN_FONT, MAX_FONT) .. "|soft-shadow-thin"
end

local function Label(parent, suffix)
	local label = WINDOW_MANAGER:CreateControl(WIN .. suffix, parent, CT_LABEL)
	label:SetFont(Font())
	label:SetColor(THEME.TEXT[1], THEME.TEXT[2], THEME.TEXT[3], 1)
	label:SetMaxLineCount(1)
	label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	return label
end

AB.line_pool, AB.line_count = {}, 0

local function NextLine()
	AB.line_count = AB.line_count + 1
	local line = AB.line_pool[AB.line_count]
	if not line then
		line = {}
		AB.line_pool[AB.line_count] = line
	end
	for c in pairs(line) do line[c] = nil end
	return line
end

local cache = { header = {}, lines = {}, cells = {} }

local function Final(c)
	local test = AB.test
	if not test or test.before_pending then return false end
	if c == 1 then return (test.index or 0) >= 1 end
	return c - 1 < (test.index or 0) and c <= #test.phases + 1
end

local function Lines()
	if cache.owner ~= AB.test then cache.owner, cache.header, cache.lines, cache.cells = AB.test, {}, {}, {} end
	AB.line_count = 0
	local head = NextLine()
	head[1] = ""
	view.header_lines = 1
	local failed = AB.UI.FailedColumns(view.columns, not view.cross and view.shown or nil)
	for c, column in ipairs(view.columns) do
		if not (Final(c) and cache.header[c]) then
			local parts, text = {}, tostring(column.label or "")
			local reason = failed[column]
			local color = reason and BAD or THEME.ACCENT
			text = text:gsub(" %+ ", "\n+ "):gsub(", ", "\n")
			for part in text:gmatch("[^\n]+") do
				if #parts < HEADER_LINES then parts[#parts + 1] = Tint(part, color) end
			end
			if reason then
				local tag = Tint("(" .. reason .. ")", BAD)
				if #parts < HEADER_LINES then parts[#parts + 1] = tag else parts[#parts] = parts[#parts] .. " " .. tag end
			end
			cache.header[c], cache.lines[c] = table.concat(parts, "\n"), #parts
		end
		view.header_lines = math.max(view.header_lines, cache.lines[c])
		head[c + 1] = cache.header[c]
	end
	local console = AB.UI.ConsoleView()
	for row_index, row in ipairs(ROWS) do
		if row.section then
			local shown = not row.key and not row.when
			for _, column in ipairs(view.columns) do
				if row.key and column[row.key] ~= nil then shown = true end
				if row.when and row.when(column) then shown = true end
			end
			if shown then NextLine()[1] = Tint(row.section, THEME.ACCENT) end
		else
			local used = not row.optional and not row.hide_zero and not row.when
			for _, column in ipairs(view.columns) do
				if row.when then
					if row.when(column) then used = true end
				elseif row.hide_zero then
					if type(column[row[2]]) == "number" and column[row[2]] > 0 then used = true end
				elseif column[row[2]] ~= nil then
					used = true
				end
			end
			if row.console and not console then used = false end
			if used then
				local line = NextLine()
				line[1] = row[1]
				for c, column in ipairs(view.columns) do
					local final = Final(c)
					local text = final and cache.cells[row_index * 1000 + c + 500]
					if not text then
						text = row.text and row.text(column) or CellText(row[3], column[row[2]])
						if row[3] == "time" and text ~= "" and column.timer then text = Tint(text, column.timer == "active" and BAD or GOOD) end
						local ref = view.compare[c]
						local other = type(ref) == "table" and ref or (ref and view.columns[ref])
						if other and not row.text then text = text .. DeltaText(row[3], column[row[2]], other[row[2]], nil, column.after and AB.SAME_MARGIN[row[3]] or nil) end
						if final then cache.cells[row_index * 1000 + c + 500] = text end
					end
					line[c + 1] = text
				end
			end
		end
	end
	return AB.line_pool, AB.line_count
end
AB.Font, AB.Label, AB.NextLine, AB.Lines = Font, Label, NextLine, Lines
