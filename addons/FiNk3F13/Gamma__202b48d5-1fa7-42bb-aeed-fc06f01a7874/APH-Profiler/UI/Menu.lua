--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHP = APHProfilerCore

local MENU_GAP = 6
local NAME_CHARS = 40
local text_dialogs = {}

local function IsPad() return IsConsoleUI() or IsInGamepadPreferredMode() end

function APHP.Danger(text)
	return "|cFF0000" .. text .. "|r"
end

function APHP.OnOff(on)
	return on and "|c00FF00" .. APHP.L("ON") .. "|r" or APHP.L("OFF")
end

function APHP.PlaceMenu(window)
	if not (window and LibAPH.PlaceContextMenuBeside) or window:IsHidden() then return false end
	return LibAPH.PlaceContextMenuBeside(window, { gap = MENU_GAP, belowGap = APHP.hint_below, aboveGap = APHP.hint_above }) ~= nil
end

function APHP.ShowMenu(control, build, window)
	local rebuild = type(build) == "function" and build or nil
	local entries = rebuild and rebuild() or build
	LibAPH.ShowScrollableMenu(control, entries, { onHide = APHP.ReleaseTip, rebuild = rebuild })
	APHP.HoldTip()
	APHP.PlaceMenu(window or control)
	return true
end

function APHP.AskText(spec)
	local hidden = {}
	for _, window in ipairs({ APHP.GetHudControl(), APHP.GetTimelineWindow and APHP.GetTimelineWindow() }) do
		if window and not window:IsHidden() then
			window:SetHidden(true)
			hidden[#hidden + 1] = window
		end
	end
	local function ComeBack()
		for _, window in ipairs(hidden) do window:SetHidden(false) end
	end
	if IsPad() then
		LibAPH.ShowGamepadTextEntry({
			title = spec.title, prompt = spec.prompt, initialText = spec.initial, maxChars = spec.maxChars,
			onConfirm = spec.onConfirm, onClosed = ComeBack,
		})
		return true
	end
	if not text_dialogs[spec.id] then
		text_dialogs[spec.id] = true
		ZO_Dialogs_RegisterCustomDialog(spec.id, {
			title = { text = spec.title },
			mainText = { text = spec.body },
			editBox = { maxInputCharacters = spec.maxChars },
			buttons = {
				{ text = SI_DIALOG_ACCEPT, callback = function(dialog) dialog.data.onConfirm(ZO_Dialogs_GetEditBoxText(dialog)) end },
				{ text = SI_DIALOG_CANCEL },
			},
			finishedCallback = function(dialog) if dialog.data and dialog.data.restore then dialog.data.restore() end end,
		})
	end
	ZO_Dialogs_ShowDialog(spec.id, { onConfirm = spec.onConfirm, restore = ComeBack }, { initialEditText = spec.initial })
	return true
end

function APHP.AskRename(run)
	return APHP.AskText({
		id = "APHProfiler_Rename", title = APHP.L("RENAME_SCAN"), body = APHP.L("RENAME_SCAN_BODY"),
		prompt = APHP.L("NAME"), initial = run.name or "", maxChars = NAME_CHARS,
		onConfirm = function(text) APHP.RenameRun(run, text) end,
	})
end

function APHP.LengthText()
	if not APHP.IsTimedScan() then return APHP.L("SCAN_LENGTH_UNTIL_STOP") end
	return string.format(APHP.L("SCAN_LENGTH_SECONDS"), APHP.ScanSeconds())
end

function APHP.SetScanLength(seconds)
	if type(seconds) ~= "number" then return false end
	if seconds <= 0 then
		APHP.saved.scan_mode = APHP.SCAN_UNTIL_STOP
	else
		local range = APHP.ScanRange()
		APHP.saved.scan_mode = APHP.SCAN_TIMED
		APHP.saved.scan_seconds = math.max(math.floor(seconds + 0.5), range.min)
	end
	APHP.ApplyScanLimits()
	APHP.RefreshHud()
	return true
end

function APHP.AskScanLength()
	local range = APHP.ScanRange()
	return APHP.AskText({
		id = "APHProfiler_Length", title = APHP.L("SCAN_LENGTH"),
		body = string.format(APHP.L("SCAN_LENGTH_BODY"), range.min),
		prompt = APHP.L("SECONDS_PROMPT"), initial = tostring(APHP.IsTimedScan() and APHP.ScanSeconds() or 0), maxChars = 7,
		onConfirm = function(text)
			local number = tonumber(zo_strtrim(text or ""))
			if not number then
				APHP.Print(string.format(APHP.L("NOT_A_NUMBER"), tostring(text)), true)
				return
			end
			APHP.SetScanLength(number)
		end,
	})
end
