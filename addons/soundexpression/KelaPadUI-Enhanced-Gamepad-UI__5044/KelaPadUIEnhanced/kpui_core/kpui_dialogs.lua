-- KelaPadUI Enhanced gamepad dialogs that keep the core dialog keybind pool
-- trusted.
--
-- The core gamepad dialog builds its button descriptors from a shared pool
-- (g_keybindStripDescriptors in zo_genericdialog_gamepad.lua) the first time a
-- dialog needs that many buttons, and every later dialog reuses them. When an
-- add-on dialog is the first one shown after a reload, those descriptors are
-- created with add-on code on the callstack, and pressing a button on a later
-- core dialog that calls a private function (ready check, duel) fails with
-- "Attempt to access a private function ... from insecure code".
--
-- KelaRegisterGamepadDialog takes a normal dialog table, removes its `buttons`
-- so the core never touches the pool for it, and shows the same buttons as an
-- add-on keybind group on the dialog's keybind state instead.

local registeredGroups = {}

local function ResolveText(text, dialog)
	if type(text) == "function" then
		return text(dialog)
	elseif type(text) == "number" then
		return GetString(text)
	end
	return text
end

local function ResolveFlag(value, dialog)
	if type(value) == "function" then
		return value(dialog)
	end
	return value ~= false
end

-- Registers a gamepad dialog. `info` is the table ZO_Dialogs_RegisterCustomDialog
-- takes; its `buttons` entries keep the core shape (keybind, text, callback,
-- visible, enabled, clickSound). The first two default to DIALOG_PRIMARY and
-- DIALOG_NEGATIVE, as in core.
function KelaRegisterGamepadDialog(name, info)
	local buttons = info.buttons or {}
	info.buttons = nil

	local entry = { dialog = nil, stateIndex = nil }
	local group = { alignment = KEYBIND_STRIP_ALIGN_LEFT }
	local twoOrMore = #buttons > 1
	for index, button in ipairs(buttons) do
		local keybind = button.keybind or (index == 1 and "DIALOG_PRIMARY") or (index == 2 and "DIALOG_NEGATIVE") or nil
		local sound = button.clickSound
		if not sound and twoOrMore then
			sound = (keybind == "DIALOG_PRIMARY" and SOUNDS.DIALOG_ACCEPT) or (keybind == "DIALOG_NEGATIVE" and SOUNDS.DIALOG_DECLINE) or nil
		end
		group[#group + 1] =
		{
			keybind = keybind,
			alignment = button.alignment,
			sound = sound,
			ethereal = button.ethereal,
			name = function()
				return ResolveText(button.text or button.name, entry.dialog)
			end,
			visible = function()
				return button.visible == nil or ResolveFlag(button.visible, entry.dialog)
			end,
			enabled = function()
				return button.enabled == nil or ResolveFlag(button.enabled, entry.dialog)
			end,
			callback = function()
				local dialog = entry.dialog
				if not dialog then
					return
				end
				if button.callback then
					button.callback(dialog)
				end
				if not dialog.info.blockDialogReleaseOnPress and entry.dialog == dialog then
					ZO_Dialogs_ReleaseDialogOnButtonPress(name)
				end
			end,
		}
	end

	local onShown = info.OnShownCallback
	info.OnShownCallback = function(dialog, ...)
		entry.dialog = dialog
		if #group > 0 then
			entry.stateIndex = KEYBIND_STRIP:GetTopKeybindStateIndex()
			KEYBIND_STRIP:AddKeybindButtonGroup(group, entry.stateIndex)
		end
		if onShown then
			onShown(dialog, ...)
		end
	end

	local onHiding = info.onHidingCallback
	info.onHidingCallback = function(dialog, ...)
		if #group > 0 and entry.stateIndex then
			KEYBIND_STRIP:RemoveKeybindButtonGroup(group, entry.stateIndex)
		end
		entry.dialog = nil
		entry.stateIndex = nil
		if onHiding then
			onHiding(dialog, ...)
		end
	end

	registeredGroups[name] = { group = group, entry = entry }
	ZO_Dialogs_RegisterCustomDialog(name, info)
end

-- Replaces ZO_GenericGamepadDialog_RefreshKeybinds for dialogs registered above.
function KelaRefreshGamepadDialogKeybinds(name)
	local registered = registeredGroups[name]
	if registered and registered.entry.stateIndex then
		KEYBIND_STRIP:UpdateKeybindButtonGroup(registered.group, registered.entry.stateIndex)
	end
end

-- Select / Back buttons shared by the parametric filter dialogs: Select runs
-- the highlighted entry's callback, Back closes the dialog.
function KelaParametricSelectBackButtons(name)
	return
	{
		{
			keybind = "DIALOG_PRIMARY",
			text = SI_GAMEPAD_SELECT_OPTION,
			callback = function(dialog)
				local data = dialog.entryList and dialog.entryList:GetTargetData()
				if data and data.callback then
					data.callback(dialog)
				end
			end,
		},
		{
			keybind = "DIALOG_NEGATIVE",
			text = SI_GAMEPAD_BACK_OPTION,
			callback = function()
				ZO_Dialogs_ReleaseDialogOnButtonPress(name)
			end,
		},
	}
end

-- A yes/no question: `onConfirm` runs when the player confirms, nothing happens
-- on Cancel. The text is asked of the caller, so it can be a formatted string.
-- It can be asked from another dialog's button: the core queues it and shows
-- it once that dialog has closed.
local CONFIRM_DIALOG = "KELA_CONFIRM_DIALOG"
local confirmRegistered = false

function KelaShowConfirmDialog(text, onConfirm)
	if not confirmRegistered then
		confirmRegistered = true
		KelaRegisterGamepadDialog(CONFIRM_DIALOG,
		{
			canQueue = true,
			gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
			title = { text = KELA_CONFIRM_TITLE },
			mainText =
			{
				text = function(dialog)
					return dialog.data and dialog.data.text or ""
				end,
			},
			buttons =
			{
				{
					text = SI_DIALOG_CONFIRM,
					callback = function(dialog)
						if dialog.data and dialog.data.onConfirm then
							dialog.data.onConfirm()
						end
					end,
				},
				{ text = SI_DIALOG_CANCEL },
			},
		})
	end
	ZO_Dialogs_ShowGamepadDialog(CONFIRM_DIALOG, { text = text, onConfirm = onConfirm })
end
