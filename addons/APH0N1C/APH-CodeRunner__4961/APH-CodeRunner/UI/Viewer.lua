--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHCR = APHCodeRunnerCore

local VIEWER_MAX_DEPTH = 10
APHCR.VIEWER_REFRESH_MS = 1000
local viewer_status

local function LatestLiveSession()
	for index = #APHCR.sessions, 1, -1 do
		if APHCR.sessions[index].alive then return APHCR.sessions[index] end
	end
	return nil
end

local function SortedKeys(tbl)
	local keys = {}
	for key in pairs(tbl) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b)
		if type(a) == type(b) and (type(a) == "number" or type(a) == "string") then return a < b end
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function FormatValue(value)
	if type(value) == "string" then
		if #value > 200 then value = value:sub(1, 200) .. "..." end
		return string.format("%q", value)
	end
	return tostring(value)
end

local function DumpTable(lines, budget, tbl, indent, depth, seen)
	for _, key in ipairs(SortedKeys(tbl)) do
		if budget.cut then return end
		local value = tbl[key]
		local label = indent .. "[" .. FormatValue(key) .. "] = "
		local function Add(line)
			budget.used = budget.used + #line + 2
			if budget.used > budget.limit then
				budget.cut = true
				return false
			end
			lines[#lines + 1] = line
			return true
		end
		if type(value) == "table" then
			if seen[value] then
				Add(label .. "{...} (already shown)")
			elseif depth >= VIEWER_MAX_DEPTH then
				Add(label .. "{...} (too deep)")
			elseif Add(label .. "{") then
				seen[value] = true
				DumpTable(lines, budget, value, indent .. "    ", depth + 1, seen)
				if not budget.cut then Add(indent .. "}") end
			end
		else
			Add(label .. FormatValue(value))
		end
	end
end

local function BuildViewerText(limit)
	local session = LatestLiveSession()
	if not session then return "No run is active.", "Run All first; its sandboxed SavedVariables show here." end
	local roots = {}
	for _, key in ipairs(SortedKeys(session.saved)) do roots[#roots + 1] = { key, session.saved[key] } end
	if #roots == 0 then return "This run has no SavedVariables yet.", string.format("Run %d sandbox", session.id) end
	local lines = {}
	local budget = { used = 0, limit = limit - 200, cut = false }
	for _, root in ipairs(roots) do
		if budget.cut then break end
		if type(root[2]) == "table" then
			lines[#lines + 1] = root[1] .. " = {"
			DumpTable(lines, budget, root[2], "    ", 1, { [root[2]] = true })
			if not budget.cut then lines[#lines + 1] = "}" end
		else
			lines[#lines + 1] = root[1] .. " = " .. FormatValue(root[2])
		end
	end
	if budget.cut then
		lines[#lines + 1] = string.format("... cut here: ESO edit boxes hold at most %d characters", limit)
	end
	return table.concat(lines, "\n"), string.format("Run %d sandbox", session.id)
end

local function RefreshViewer()
	local text, source = BuildViewerText(APHCR.viewer_view.max_chars)
	viewer_status:SetText(source .. " - updates every second")
	APHCR.viewer_view:SetText(text, true)
end

function APHCR.MakeTextWindow(name, title)
	local window = WINDOW_MANAGER:CreateTopLevelWindow(name)
	window:SetDimensions(480, 540)
	window:SetClampedToScreen(true)
	window:SetMouseEnabled(true)
	window:SetMovable(true)
	window:SetDrawTier(DT_MEDIUM)
	window:SetDrawLayer(DL_OVERLAY)
	window:SetDrawLevel(9100)
	window:SetHidden(true)
	LibAPH.ApplyPanelBackdrop(window, name .. "BG", LibAPH.THEME.BG)
	LibAPH.CreateHeaderStrip(window, name .. "Header", 30)
	LibAPH.CreateThemedCloseButton(window, name .. "Close", function()
		window:SetHidden(true)
		APHCR.LeaveUIModeIfIdle()
	end, 12, 10)
	LibAPH.MakeWindowResizable(window, { minWidth = 320, minHeight = 260 })
	APHCR.MakeLabel(window, title, 16):SetAnchor(TOPLEFT, window, TOPLEFT, 12, 8)

	local status = APHCR.MakeLabel(window, "", 13, LibAPH.THEME.MUTED)
	status:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 12, -10)
	status:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -12, -10)
	return window, status
end

function APHCR.BuildViewer()
	APHCR.viewer, viewer_status = APHCR.MakeTextWindow("APHCodeRunnerViewer", "SavedVariables Viewer")

	local reset_viewer_search
	local search_bg, viewer_search = APHCR.MakeLineEdit("APHCodeRunnerViewerSearch", APHCR.viewer, "Search saved variables - Enter next, Shift+Enter previous", function()
		if reset_viewer_search then reset_viewer_search() end
	end)
	search_bg:SetAnchor(TOPLEFT, APHCR.viewer, TOPLEFT, 12, 40)
	search_bg:SetAnchor(TOPRIGHT, APHCR.viewer, TOPRIGHT, -70, 40)
	local viewer_search_status = APHCR.MakeLabel(APHCR.viewer, "", 13, LibAPH.THEME.MUTED)
	viewer_search_status:SetAnchor(LEFT, search_bg, RIGHT, 8, 0)

	APHCR.viewer_view = APHCR.MakeScrollText(APHCR.viewer, "APHCodeRunnerViewer", { read_only = true })
	APHCR.viewer_view.area:SetAnchor(TOPLEFT, search_bg, BOTTOMLEFT, 0, 8)
	APHCR.viewer_view.area:SetAnchor(BOTTOMRIGHT, viewer_status, TOPRIGHT, 0, -8)
	reset_viewer_search = APHCR.AttachSearch(viewer_search, viewer_search_status, APHCR.viewer_view.box, function(line)
		APHCR.viewer_view:ScrollToLine(line)
	end)

	APHCR.On(APHCR.viewer, "OnShow", function()
		APHCR.viewer_view:Relayout()
		RefreshViewer()
		APHCR.Every("APHCodeRunnerViewer", APHCR.VIEWER_REFRESH_MS, RefreshViewer)
	end, "viewer show")
	APHCR.On(APHCR.viewer, "OnHide", function()
		EVENT_MANAGER:UnregisterForUpdate("APHCodeRunnerViewer")
	end, "viewer hide")
end
