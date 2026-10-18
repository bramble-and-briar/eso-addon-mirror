--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHCR = APHCodeRunnerCore

local errors_status

function APHCR.UpdateErrorsBadge()
	if not APHCR.errors_btn then return end
	local count = #APHCR.error_log
	APHCR.errors_btn:SetText(count > 0 and string.format("Errors (%d)", count) or "Errors")
	LibAPH.FitButtonText(APHCR.errors_btn, { font = IsConsoleUI() and "ZoFontGamepad22" or "ZoFontGameBold" })
end
APHCR.on_error_logged = APHCR.UpdateErrorsBadge

local function BuildErrorsText(limit)
	local blocks = {}
	for index, entry in ipairs(APHCR.error_log) do
		local repeats = entry.count > 1 and string.format(" (x%d)", entry.count) or ""
		local source = entry.run == 0 and "CodeRunner" or ("Run " .. entry.run)
		blocks[index] = { entry = entry, text = string.format("[%s] %s%s: %s", entry.time, source, repeats, entry.message) }
	end
	local first_shown = 1
	local function Total()
		local total = 0
		for index = first_shown, #blocks do total = total + #blocks[index].text + 2 end
		return total
	end
	while first_shown < #blocks and Total() > limit - 100 do first_shown = first_shown + 1 end
	local parts = {}
	if first_shown > 1 then
		parts[1] = string.format("(%d older errors hidden: ESO edit boxes hold at most %d characters)", first_shown - 1, limit)
	end
	for index = first_shown, #blocks do
		local text = blocks[index].text
		if #text > limit - 100 then text = text:sub(1, limit - 100) end
		parts[#parts + 1] = text
	end
	if #parts == 0 then parts[1] = "No errors." end
	return table.concat(parts, "\n\n")
end

local function RefreshErrors()
	local text = BuildErrorsText(APHCR.errors_view.max_chars)
	errors_status:SetText(string.format("%d error(s) - updates every second", #APHCR.error_log))
	APHCR.errors_view:SetText(text, true)
end

local function BuildErrorsWindow()
	APHCR.errors_window, errors_status = APHCR.MakeTextWindow("APHCodeRunnerErrors", "Errors")
	local clear_btn = APHCR.MakeButton("APHCodeRunnerErrorsClear", APHCR.errors_window, "Clear", 80, function()
		APHCR.ClearErrors()
		RefreshErrors()
	end)
	clear_btn:SetAnchor(TOPLEFT, APHCR.errors_window, TOPLEFT, 12, 40)

	APHCR.errors_view = APHCR.MakeScrollText(APHCR.errors_window, "APHCodeRunnerErrors", { read_only = true })
	APHCR.errors_view.area:SetAnchor(TOPLEFT, clear_btn, BOTTOMLEFT, 0, 8)
	APHCR.errors_view.area:SetAnchor(BOTTOMRIGHT, errors_status, TOPRIGHT, 0, -8)

	APHCR.On(APHCR.errors_window, "OnShow", function()
		APHCR.errors_view:Relayout()
		RefreshErrors()
		APHCR.Every("APHCodeRunnerErrors", APHCR.VIEWER_REFRESH_MS, RefreshErrors)
	end, "errors show")
	APHCR.On(APHCR.errors_window, "OnHide", function()
		EVENT_MANAGER:UnregisterForUpdate("APHCodeRunnerErrors")
	end, "errors hide")
end

APHCR.STACK_GAP = 6
local STACK_MIN_HEIGHT = 260
local CASCADE_OFFSET = 36

function APHCR.PlaceErrorsWindow()
	APHCR.errors_window.libaph_dock = nil
	APHCR.errors_window:ClearAnchors()
	if not (APHCR.viewer and not APHCR.viewer:IsHidden()) then
		LibAPH.DockWindowBeside(APHCR.errors_window, APHCR.win, APHCR.STACK_GAP, "left")
		return
	end
	local room_below = GuiRoot:GetHeight() - APHCR.viewer:GetBottom() - APHCR.STACK_GAP - 10
	if room_below >= STACK_MIN_HEIGHT then
		APHCR.errors_window:SetDimensions(APHCR.viewer:GetWidth(), math.min(APHCR.errors_window:GetHeight(), room_below))
		APHCR.errors_window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, APHCR.viewer:GetLeft(), APHCR.viewer:GetBottom() + APHCR.STACK_GAP)
	elseif APHCR.viewer:GetLeft() >= APHCR.errors_window:GetWidth() + APHCR.STACK_GAP then
		APHCR.errors_window:SetAnchor(TOPRIGHT, GuiRoot, TOPLEFT, APHCR.viewer:GetLeft() - APHCR.STACK_GAP, APHCR.viewer:GetTop())
	else
		APHCR.errors_window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, APHCR.viewer:GetLeft() + CASCADE_OFFSET, APHCR.viewer:GetTop() + CASCADE_OFFSET)
	end
end

function APHCR.ToggleErrors()
	if not APHCR.errors_window then BuildErrorsWindow() end
	if APHCR.errors_window:IsHidden() then APHCR.PlaceErrorsWindow() end
	APHCR.errors_window:SetHidden(not APHCR.errors_window:IsHidden())
	APHCR.LeaveUIModeIfIdle()
end
