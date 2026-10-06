--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local TEXT_ENTRY_DIALOG = "LibAPH_GAMEPAD_TEXT_ENTRY"
local PICKER_DIALOG = "LibAPH_GAMEPAD_PICKER"
local MAX_INPUT_CHARS = 60

local text_entry = { text = "" }

local function Release(dialogId)
	ZO_Dialogs_ReleaseDialogOnButtonPress(dialogId)
end

local function SetupSubmitEntry(control, data, selected, reselectingDuringRebuild, enabled, active)
	local valid = enabled
	if data.validInput then
		valid = data.validInput()
		data.disabled = not valid
		data:SetEnabled(valid)
	end
	ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, valid, active)
end

local function RegisterTextEntry()
	if ESO_Dialogs[TEXT_ENTRY_DIALOG] then return end
	ZO_Dialogs_RegisterCustomDialog(TEXT_ENTRY_DIALOG, {
		gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
		canQueue = true,
		blockDialogReleaseOnPress = true,
		setup = function(dialog)
			text_entry.text = dialog.data.initialText or ""
			text_entry.onTextChanged = dialog.data.onTextChanged
			dialog:setupFunc()
			if text_entry.onTextChanged then text_entry.onTextChanged(text_entry.text) end
		end,
		finishedCallback = function(dialog)
			text_entry.onTextChanged = nil
			if dialog.data and dialog.data.onClosed then dialog.data.onClosed() end
		end,
		title = { text = function(dialog) return dialog.data.title end },
		mainText = { text = function(dialog) return dialog.data.prompt or "" end },
		parametricList = {
			{
				template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
				templateData = {
					nameField = true,
					textChangedCallback = function(control)
						text_entry.text = control:GetText()
						if text_entry.onTextChanged then text_entry.onTextChanged(text_entry.text) end
					end,
					setup = function(control, data, selected)
						control.highlight:SetHidden(not selected)
						control.editBoxControl.textChangedCallback = data.textChangedCallback
						control.editBoxControl:SetMaxInputChars(data.dialog.data.maxChars or MAX_INPUT_CHARS)
						control.editBoxControl:SetDefaultText(data.dialog.data.prompt or "")
						control.editBoxControl:SetText(text_entry.text)
						data.control = control
					end,
					callback = function(dialog)
						local data = dialog.entryList:GetTargetData()
						if data and data.control then data.control.editBoxControl:TakeFocus() end
					end,
					narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
				},
			},
			{
				template = "ZO_GamepadTextFieldSubmitItem",
				templateData = {
					text = GetString(SI_DIALOG_CONFIRM),
					setup = SetupSubmitEntry,
					validInput = function() return text_entry.text ~= "" end,
					callback = function(dialog)
						local text = text_entry.text
						local onConfirm = dialog.data.onConfirm
						Release(TEXT_ENTRY_DIALOG)
						if text ~= "" and onConfirm then onConfirm(text) end
					end,
				},
			},
		},
		buttons = {
			{
				keybind = "DIALOG_PRIMARY",
				text = SI_GAMEPAD_SELECT_OPTION,
				callback = function(dialog)
					local data = dialog.entryList:GetTargetData()
					if data and data.callback then data.callback(dialog) end
				end,
			},
			{
				keybind = "DIALOG_NEGATIVE",
				text = SI_DIALOG_CANCEL,
				callback = function(dialog)
					local onCancel = dialog.data.onCancel
					Release(TEXT_ENTRY_DIALOG)
					if onCancel then onCancel() end
				end,
			},
		},
		noChoiceCallback = function(dialog)
			if dialog.data and dialog.data.onCancel then dialog.data.onCancel() end
		end,
	})
end

local function RegisterPicker()
	if ESO_Dialogs[PICKER_DIALOG] then return end
	ZO_Dialogs_RegisterCustomDialog(PICKER_DIALOG, {
		gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
		canQueue = true,
		blockDialogReleaseOnPress = true,
		setup = function(dialog)
			local entries = dialog.info.parametricList
			ZO_ClearNumericallyIndexedTable(entries)
			for _, choice in ipairs(dialog.data.choices) do
				entries[#entries + 1] = {
					template = "ZO_GamepadFullWidthLeftLabelEntryTemplate",
					templateData = {
						text = choice.text,
						setup = ZO_SharedGamepadEntry_OnSetup,
						callback = function()
							Release(PICKER_DIALOG)
							choice.callback()
						end,
					},
				}
			end
			dialog:setupFunc()
		end,
		title = { text = function(dialog) return dialog.data.title end },
		parametricList = {},
		buttons = {
			{
				keybind = "DIALOG_PRIMARY",
				text = SI_GAMEPAD_SELECT_OPTION,
				callback = function(dialog)
					local data = dialog.entryList:GetTargetData()
					if data and data.callback then data.callback(dialog) end
				end,
			},
			{
				keybind = "DIALOG_NEGATIVE",
				text = SI_DIALOG_CANCEL,
				callback = function(dialog)
					local onCancel = dialog.data.onCancel
					Release(PICKER_DIALOG)
					if onCancel then onCancel() end
				end,
			},
		},
		noChoiceCallback = function(dialog)
			if dialog.data and dialog.data.onCancel then dialog.data.onCancel() end
		end,
	})
end

function LibAPH.ShowGamepadTextEntry(opts)
	RegisterTextEntry()
	ZO_Dialogs_ShowGamepadDialog(TEXT_ENTRY_DIALOG, {
		title = opts.title, prompt = opts.prompt, initialText = opts.initialText, maxChars = opts.maxChars,
		onConfirm = opts.onConfirm, onCancel = opts.onCancel,
		onTextChanged = opts.onTextChanged, onClosed = opts.onClosed,
	})
end

function LibAPH.ShowGamepadPicker(opts)
	RegisterPicker()
	ZO_Dialogs_ShowGamepadDialog(PICKER_DIALOG, { title = opts.title, choices = opts.choices or {}, onCancel = opts.onCancel })
end

LibAPH.GAMEPAD_TEXT_ENTRY_DIALOG = TEXT_ENTRY_DIALOG
LibAPH.GAMEPAD_PICKER_DIALOG = PICKER_DIALOG
