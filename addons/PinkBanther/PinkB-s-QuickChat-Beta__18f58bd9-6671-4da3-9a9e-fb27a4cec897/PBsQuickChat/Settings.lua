-- The settings panel (LibHarvensAddonSettings): pick a slot, write its message, its wheel name and its channel,
-- empty it, and the options. The panel's rows are pooled and shared with other add-ons' panels, so every
-- row reads its value from the saved slots (UpdateControls re-reads every label and the drop-downs' items).
--
-- The slot drop-down's items are plain "Slot 1" ... "Slot 8", never the slot's name or message: editing a
-- message must not change the text of a drop-down item, because the library looks the drop-down's current
-- value up among the items it listed before (see "LHAS ST_EDIT" in PB's notes: getFunction has to return
-- something that matches an item).

local A, S = PBS_QUICK_CHAT, PBS_QUICK_CHAT_STRINGS

local CLEAR_WINDOW_MS = 6000

local function Now()
	return GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
end

-- All the slots at a glance, one line each.
function A:OverviewText()
	local lines = {}
	for i = 1, self.NUM_SLOTS do
		local slot = self:GetSlot(i)
		if slot and self:HasText(i) then
			lines[#lines + 1] = string.format(S.overviewLine, i, self:ChannelName(slot.channel), A.ShortText(slot.text, 28))
		else
			lines[#lines + 1] = string.format(S.overviewLine, i, "-", S.slotEmpty)
		end
	end
	return table.concat(lines, "\n")
end

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
	local function slotItemName(i)
		return string.format(S.slotItem, i)
	end

	panel:AddSetting({ type = L.ST_LABEL, label = S.note })

	-- Which slot the rows below work on.
	panel:AddSetting({
		type = L.ST_DROPDOWN,
		label = S.slotChoice,
		items = function()
			local items = {}
			for i = 1, self.NUM_SLOTS do
				items[i] = { name = slotItemName(i), data = i }
			end
			return items
		end,
		getFunction = function()
			return slotItemName(currentSlot())
		end,
		setFunction = function(_, _, item)
			if item and item.data then
				self:Set("slot", item.data)
				-- the rows are redrawn after the drop-down's own callback has returned
				zo_callLater(refresh, 50)
			end
		end,
	})
	-- The library calls setFunction twice for one confirm of a text box (on Enter, then when the box loses
	-- focus) and then reads every other row's value again, so these two only store the text: no game call, no
	-- redraw. The text is made of whole characters (A.CleanMessage / CleanName read bytes, never a
	-- locale-dependent class): the library puts what getFunction returns straight back into the console's text box.
	panel:AddSetting({
		type = L.ST_EDIT,
		label = S.textField,
		maxChars = A.MAX_TEXT_CHARS,
		getFunction = function()
			local slot = self:GetSlot(currentSlot())
			return slot and slot.text or ""
		end,
		setFunction = function(text)
			self:SetSlotText(currentSlot(), text)
		end,
	})
	panel:AddSetting({
		type = L.ST_EDIT,
		label = S.nameField,
		maxChars = A.MAX_NAME_CHARS,
		getFunction = function()
			local slot = self:GetSlot(currentSlot())
			return slot and slot.name or ""
		end,
		setFunction = function(text)
			self:SetSlotName(currentSlot(), text)
		end,
	})
	panel:AddSetting({
		type = L.ST_DROPDOWN,
		label = S.channelField,
		items = function()
			local items = {}
			for _, def in ipairs(self.channelList or {}) do
				items[#items + 1] = { name = self:ChannelName(def.key), data = def.key }
			end
			return items
		end,
		getFunction = function()
			local slot = self:GetSlot(currentSlot())
			return self:ChannelName(slot and slot.channel or "current")
		end,
		setFunction = function(_, _, item)
			if item and item.data then
				self:SetSlotChannel(currentSlot(), item.data)
				zo_callLater(refresh, 50)
			end
		end,
	})
	panel:AddSetting({
		type = L.ST_LABEL,
		label = function()
			local i = currentSlot()
			local slot = self:GetSlot(i)
			if not slot or not self:HasText(i) then
				return string.format(S.slotInfoEmpty, i)
			end
			return string.format(S.slotInfo, i, self:WheelName(i), self:ChannelName(slot.channel))
		end,
	})
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.clearLabel,
		buttonText = S.clearButton,
		clickHandler = function()
			local i = currentSlot()
			local slot = self:GetSlot(i)
			local used = slot and (slot.text ~= "" or slot.name ~= "")
			local armed = self.clearArmed
			if not used or (armed and armed.slot == i and Now() - armed.at <= CLEAR_WINDOW_MS) then
				self.clearArmed = nil
				self:ClearSlot(i)
				self:Note(string.format(S.cleared, i))
			else
				self.clearArmed = { slot = i, at = Now() }
				self:Note(string.format(S.clearAgain, i))
			end
			refresh()
		end,
	})
	-- Every slot on one screen, and what the last actions said (the chat window is hidden while a console menu is open).
	panel:AddSetting({
		type = L.ST_LABEL,
		label = function()
			return self:OverviewText()
		end,
	})
	panel:AddSetting({
		type = L.ST_LABEL,
		label = function()
			return self:LogText()
		end,
	})

	local function toggle(key, after)
		panel:AddSetting({
			type = L.ST_CHECKBOX,
			label = S[key],
			default = self.defaults[key],
			getFunction = function()
				return self.sv[key]
			end,
			setFunction = function(value)
				self:Set(key, value)
				if after then
					after(value)
				end
			end,
		})
	end
	toggle("wheel", function(value)
		-- turning the page on needs no reload; turning it off does (the pages already learned by the client stay)
		if value then
			zo_callLater(function()
				self:RetryWheel()
			end, 50)
		end
	end)
	toggle("wheelHead", function(value)
		-- the position is taken when the page is installed: say so when this changes what is in place
		if self.wheel.installed and (value == true) ~= (self.wheel.head == true) then
			self:Print(S.wheelHeadLater)
		end
	end)
	toggle("wheelFirst")
	toggle("coop")
	panel:AddSetting({
		type = L.ST_SLIDER,
		label = S.delay,
		min = self.MIN_DELAY_MS,
		max = self.MAX_DELAY_MS,
		step = 100,
		default = self.defaults.delayMs,
		format = "%d",
		getFunction = function()
			return self.sv.delayMs
		end,
		setFunction = function(value)
			self:Set("delayMs", value)
		end,
	})

	-- Typing /pbqc status on a console is awkward; the same report is one button here.
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.statusLabel,
		buttonText = S.statusButton,
		clickHandler = function()
			self:PrintStatus()
		end,
	})
	-- /pbqc retry as a button: a console has no comfortable way to type a command.
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
