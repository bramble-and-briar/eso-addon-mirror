--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local PC_FORMAT = "Lua %.1f MB Pool %.1f MB"
local CONSOLE_FORMAT = "Lua %.1f MB  Pool %.1f MB"
local owners = {}
local shown = {}

local function Text(format)
	return string.format(format, collectgarbage("count") / 1024, GetTotalUserAddOnMemoryPoolUsageMB and GetTotalUserAddOnMemoryPoolUsageMB() or 0)
end

local function Wanted()
	return next(owners) ~= nil
end

local function PcUpdate()
	shown.label:SetText(Text(PC_FORMAT))
end

local function PcShow(on)
	if on and not shown.window then
		shown.window = WINDOW_MANAGER:CreateTopLevelWindow("LibAPHMemoryDisplay")
		shown.label = WINDOW_MANAGER:CreateControl("LibAPHMemoryDisplayLabel", shown.window, CT_LABEL)
		shown.label:SetFont("ZoFontWinH2")
		shown.label:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -9, 9)
	end
	if not shown.window then return end
	shown.window:SetHidden(not on)
	if on then
		PcUpdate()
		EVENT_MANAGER:RegisterForUpdate("LibAPH_MemoryDisplay", 1000, PcUpdate)
	else
		EVENT_MANAGER:UnregisterForUpdate("LibAPH_MemoryDisplay")
	end
end

local function ConsoleHook()
	if shown.hooked then return end
	shown.hooked = true
	ZO_PostHook(ZO_AddOnMemoryDisplay, "Update", function(display, timeS)
		if Wanted() and display.nextUpdateTimeS - timeS > 0.99 then
			display.memoryLabel:SetText(Text(CONSOLE_FORMAT))
		end
	end)
end

local function ConsoleShow(on)
	local display = ADD_ON_MEMORY_DISPLAY
	if not (display and display.savedVars) then return end
	ConsoleHook()
	local control = display.control
	if on then
		if not shown.anchor then
			local _, point, relative_to, relative_point, x, y = control:GetAnchor(0)
			shown.anchor = { point, relative_to, relative_point, x, y }
			shown.was_visible = display.savedVars.isVisible and true or false
		end
		if not display.savedVars.isVisible then display:Toggle() end
		control:ClearAnchors()
		control:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -150, 30)
		display.nextUpdateTimeS = 0
	elseif shown.anchor then
		if (display.savedVars.isVisible and true or false) ~= shown.was_visible then display:Toggle() end
		control:ClearAnchors()
		control:SetAnchor(unpack(shown.anchor))
		shown.anchor, shown.was_visible = nil, nil
	end
end

function LibAPH.SetMemoryDisplay(owner, on)
	assert(type(owner) == "string", "SetMemoryDisplay(owner, on)")
	owners[owner] = on and true or nil
	local wanted = Wanted()
	if IsConsoleUI() then ConsoleShow(wanted) else PcShow(wanted) end
	return wanted
end

function LibAPH.IsMemoryDisplayShown()
	return Wanted()
end

function LibAPH.GetMemoryDisplayText()
	return Text(IsConsoleUI() and CONSOLE_FORMAT or PC_FORMAT)
end
