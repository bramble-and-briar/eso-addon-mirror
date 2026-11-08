-- What the settings panel and the slash commands do to the saved sets. Both go through here so that they
-- behave the same.
--
-- Saving over a set that is already there asks first, in the client's own confirmation dialog (a console player
-- has no undo, and a button is easy to press twice). Deleting asks to be repeated within a few seconds. If the
-- client has no dialog to offer, an overwrite falls back to that second way.

local A, S = PBS_EQUIPMENT_CHANGER, PBS_EQUIPMENT_CHANGER_STRINGS

local ARM_MS = 6000
local DIALOG = A.name .. "_Overwrite"

-- True when the same action was asked for a moment ago; otherwise remember it, say what repeating it does
-- and return false.
function A:Armed(key, text, ...)
	local now = GetGameTimeMilliseconds()
	local armed = self.armed
	if armed and armed.key == key and now - armed.at <= ARM_MS then
		self.armed = nil
		return true
	end
	self.armed = { key = key, at = now }
	self:Print(text, ...)
	return false
end

-- ---------------------------------------------------------------------------------------
-- The confirmation dialog
--
-- The same kind PB's KillLog and MailerExtension ask "delete this?" with: one entry registered in ESO_Dialogs,
-- shown through ZO_Dialogs_ShowPlatformDialog (the settings library itself asks "reset to defaults?" the same
-- way). The question and what to do on "yes" travel in the data table of the call, so one registration serves
-- every question. Nothing here wraps or hooks client code.
-- ---------------------------------------------------------------------------------------

-- The dialog's name once it is registered; nil when this client cannot show one.
function A:EnsureDialog()
	if self.dialogName then
		return self.dialogName
	end
	if type(ESO_Dialogs) ~= "table" or type(ZO_Dialogs_ShowPlatformDialog) ~= "function" then
		return nil
	end
	if type(GAMEPAD_DIALOGS) ~= "table" or GAMEPAD_DIALOGS.BASIC == nil then
		return nil
	end
	if not ESO_Dialogs[DIALOG] then
		local info = {
			gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
			title = {
				text = function()
					return S.overwriteTitle
				end,
			},
			mainText = {
				text = function(dialog)
					return dialog and dialog.data and dialog.data.message or ""
				end,
			},
			buttons = {
				[1] = {
					text = SI_DIALOG_ACCEPT,
					callback = function(dialog)
						local accept = dialog and dialog.data and dialog.data.accept
						if type(accept) == "function" then
							pcall(accept)
						end
					end,
				},
				[2] = {
					text = SI_DIALOG_CANCEL,
				},
			},
		}
		if type(ZO_Dialogs_RegisterCustomDialog) == "function" then
			ZO_Dialogs_RegisterCustomDialog(DIALOG, info)
		else
			ESO_Dialogs[DIALOG] = info
		end
	end
	self.dialogName = DIALOG
	return DIALOG
end

-- Ask `message`; run `accept` only if the player says yes. False when no dialog could be shown (nothing is run).
function A:AskConfirm(message, accept)
	local name = self:EnsureDialog()
	if not name then
		return false
	end
	local ok = pcall(ZO_Dialogs_ShowPlatformDialog, name, { message = message, accept = accept })
	return ok
end

-- ---------------------------------------------------------------------------------------
-- Save, delete, rename
-- ---------------------------------------------------------------------------------------

-- Save what is worn and slotted now into a slot. An empty slot is saved at once; one that holds a set asks
-- first. `onSaved` runs after a save that really happened (the panel empties its name box then).
-- Returns "saved", "asked" (the dialog is up; the save happens if the player says yes) or false.
function A:ActionSave(index, name, onSaved)
	local existing = self:GetSet(index)
	name = A.CleanName(name)
	if name == "" then
		name = existing and existing.name or string.format(S.defaultName, index)
	end

	local function save()
		local ok, result = self:SaveSet(index, name)
		if not ok then
			self:Print(result)
			return false
		end
		self:Print(S.saved, index, name, self:Describe(result))
		if onSaved then
			onSaved()
		end
		return true
	end

	if not existing then
		return save() and "saved" or false
	end
	if self:AskConfirm(string.format(S.overwriteText, index, existing.name, name), save) then
		return "asked"
	end
	-- no dialog on this client: press the same button again
	if not self:Armed("save" .. index, S.confirmOverwrite, index, existing.name) then
		return false
	end
	return save() and "saved" or false
end

function A:ActionDelete(index)
	local existing = self:GetSet(index)
	if not existing then
		self:Print(S.slotIsEmpty, index)
		return false
	end
	if not self:Armed("delete" .. index, S.confirmDelete, index, existing.name) then
		return false
	end
	self:DeleteSet(index)
	self:Print(S.deleted, index, existing.name)
	return true
end

function A:ActionRename(index, name)
	local existing = self:GetSet(index)
	if not existing then
		self:Print(S.slotIsEmpty, index)
		return false
	end
	name = A.CleanName(name)
	if name == "" then
		self:Print(S.nameEmpty)
		return false
	end
	local old = existing.name
	self:RenameSet(index, name)
	self:Print(S.renamed, index, old, name)
	return true
end
