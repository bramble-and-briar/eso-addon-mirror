-- The settings panel (LibHarvensAddonSettings): save the current gear and skills into a slot under a name,
-- load a slot, rename or delete it, and the options. The panel is rebuilt from the saved sets every time
-- an action changes them (UpdateControls re-reads every label and the dropdown's items).

local A, S = PBS_EQUIPMENT_CHANGER, PBS_EQUIPMENT_CHANGER_STRINGS

A.draftName = ""

function A:InitSettings()
	local L = LibHarvensAddonSettings
	if not L then
		return
	end
	local panel = L:AddAddon(self.title)
	if not panel then
		return
	end
	self.panel = panel
	panel.author, panel.version, panel.allowDefaults = self.author, self.version, false

	local function refresh()
		if panel.UpdateControls then
			panel:UpdateControls()
		end
	end
	local function currentSlot()
		return self.sv.slot
	end

	panel:AddSetting({ type = L.ST_LABEL, label = S.note })

	-- Which slot the buttons below work on. The names are read again whenever the panel is refreshed.
	panel:AddSetting({
		type = L.ST_DROPDOWN,
		label = S.slotChoice,
		items = function()
			local items = {}
			for i = 1, self.NUM_SLOTS do
				items[i] = { name = self:SlotLabel(i), data = i }
			end
			return items
		end,
		getFunction = function()
			return self:SlotLabel(currentSlot())
		end,
		setFunction = function(_, _, item)
			if item and item.data then
				self:Set("slot", item.data)
				-- not from inside the drop-down's own callback
				zo_callLater(refresh, 50)
			end
		end,
	})
	panel:AddSetting({
		type = L.ST_LABEL,
		label = function()
			local set = self:GetSet(currentSlot())
			if not set then
				return string.format(S.slotInfoEmpty, currentSlot())
			end
			return string.format(S.slotInfo, currentSlot(), set.name, self:Describe(set))
		end,
	})
	panel:AddSetting({
		type = L.ST_EDIT,
		label = S.nameField,
		maxChars = A.MAX_NAME_CHARS,
		getFunction = function()
			return self.draftName
		end,
		-- The library calls this twice for one confirm (on Enter, then when the box loses focus) and then reads
		-- every other row's value again, so it only keeps the text: no game call, no redraw. The text is made of
		-- whole characters (A.CleanName reads bytes, never a locale-dependent class): the library puts what
		-- getFunction returns straight back into the console's text box.
		setFunction = function(text)
			self.draftName = A.CleanName(text)
		end,
	})
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.saveLabel,
		buttonText = S.saveButton,
		clickHandler = function()
			-- an occupied slot asks first; the name box is emptied only when the save really happens
			self:ActionSave(currentSlot(), self.draftName, function()
				self.draftName = ""
			end)
			refresh()
		end,
	})
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.loadLabel,
		buttonText = S.loadButton,
		clickHandler = function()
			self:Load(currentSlot(), "settings")
		end,
	})
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.renameLabel,
		buttonText = S.renameButton,
		clickHandler = function()
			if self:ActionRename(currentSlot(), self.draftName) then
				self.draftName = ""
			end
			refresh()
		end,
	})
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.deleteLabel,
		buttonText = S.deleteButton,
		clickHandler = function()
			self:ActionDelete(currentSlot())
			refresh()
		end,
	})
	-- What the last actions said: the chat window is hidden while a console menu is open.
	panel:AddSetting({
		type = L.ST_LABEL,
		label = function()
			return self:LogText()
		end,
	})

	local function toggle(key)
		panel:AddSetting({
			type = L.ST_CHECKBOX,
			label = S[key],
			default = self.defaults[key],
			getFunction = function()
				return self.sv[key]
			end,
			setFunction = function(value)
				self:Set(key, value)
			end,
		})
	end
	toggle("wheel")
	toggle("wheelFirst")
	toggle("saveGear")
	toggle("saveSkills")
	toggle("saveChampion")
	toggle("applyGear")
	toggle("applySkills")
	toggle("applyChampion")
	toggle("clearSkills")
	toggle("unequipEmpty")

	-- Typing /pbec status on a console is awkward; the same report is one button here.
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.statusLabel,
		buttonText = S.statusButton,
		clickHandler = function()
			self:PrintStatus()
		end,
	})

	-- /pbec retry as a button: a console has no comfortable way to type a command.
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.retryLabel,
		buttonText = S.retryButton,
		clickHandler = function()
			self:Retry()
			self:Print(S.retried)
			self:RetryWheel()
		end,
	})
end
