--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local NAME, UI = AB.NAME, AB.UI

local line = LibAPH.CreateStatusLine(NAME .. "StatusLine", {
	font = IsConsoleUI() and "ZoFontGamepad27" or "ZoFontGameMedium",
	width = IsConsoleUI() and 1100 or 900,
	align = TEXT_ALIGN_CENTER,
	point = TOP, relativeTo = "ZO_CompassFrame", relativePoint = BOTTOM,
	offsetX = 0, offsetY = 8, consoleOffsetX = 0, consoleOffsetY = 8,
	stack = "compass", order = 1,
})

function UI.SetStatusLine(text)
	if not UI.On("status_line") then return line:Hide() end
	line:Set(text)
end
function UI.HideStatusLine() line:Hide() end
function UI.StatusLineText() return line:GetText() end
