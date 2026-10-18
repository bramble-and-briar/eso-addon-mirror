--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local FG = APHFPSGraphCore

local MENU_GAP = 6
local NAME_CHARS = 40
local RECORD_MIN = 10
local text_dialogs = {}

FG.RECORD_MIN = RECORD_MIN

local function IsPad() return IsConsoleUI() or IsInGamepadPreferredMode() end

function FG.Danger(text)
	return "|cFF0000" .. text .. "|r"
end

function FG.OnOff(on)
	return on and "|c00FF00" .. FG.L("ON") .. "|r" or FG.L("OFF")
end

function FG.PlaceMenu(window)
	if not (window and LibAPH.PlaceContextMenuBeside) or window:IsHidden() then return false end
	return LibAPH.PlaceContextMenuBeside(window, { gap = MENU_GAP, belowGap = FG.hint_below, aboveGap = FG.hint_above }) ~= nil
end

local function OpenWindows()
	local list = {}
	for _, window in ipairs({ FG.Graph.Window(), FG.Summary.Window(), FG.Timeline.Window() }) do
		if window and not window:IsHidden() then list[#list + 1] = window end
	end
	return list
end

function FG.AskText(spec)
	local hidden = OpenWindows()
	for _, window in ipairs(hidden) do window:SetHidden(true) end
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

function FG.Confirm(id, title, body, onConfirm)
	LibAPH.ShowDialogHidingWindows({ FG.Graph.Window, FG.Summary.Window, FG.Timeline.Window }, id, title, body, {
		{ text = SI_DIALOG_CONFIRM, callback = onConfirm },
		{ text = SI_DIALOG_CANCEL },
	})
	return true
end

function FG.AskRename(run)
	return FG.AskText({
		id = "APHFPSGraph_Rename", title = FG.L("RENAME_RUN"), body = FG.L("RENAME_RUN_BODY"),
		prompt = FG.L("NAME"), initial = run.name or "", maxChars = NAME_CHARS,
		onConfirm = function(text) FG.RenameRun(run, text) end,
	})
end

function FG.RecordLengthText()
	local seconds = FG.saved.record_seconds or 0
	if seconds <= 0 then return FG.L("RECORD_LENGTH_UNTIL_STOP") end
	return FG.L("RECORD_LENGTH_SECONDS", seconds)
end

function FG.SetRecordLength(seconds)
	if type(seconds) ~= "number" then return false end
	if seconds <= 0 then
		FG.saved.record_seconds = 0
	else
		FG.saved.record_seconds = math.max(math.floor(seconds + 0.5), RECORD_MIN)
	end
	return true
end

function FG.AskRecordLength()
	return FG.AskText({
		id = "APHFPSGraph_Length", title = FG.L("RECORD_LENGTH"), body = FG.L("RECORD_LENGTH_BODY", RECORD_MIN),
		prompt = FG.L("SECONDS_PROMPT"), initial = tostring(FG.saved.record_seconds or 0), maxChars = 7,
		onConfirm = function(text)
			local number = tonumber(zo_strtrim(text or ""))
			if not number then
				FG.Print(FG.L("NOT_A_NUMBER", tostring(text)), true)
				return
			end
			FG.SetRecordLength(number)
		end,
	})
end
