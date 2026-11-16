-- The settings panel (LibHarvensAddonSettings). It is only switches, two numbers and four buttons; the buttons are
-- there because typing /pbal on a console is awkward. The rows are pooled and shared with other add-ons' panels, so
-- every row reads its value from the saved variables.

local A, S = PBS_AUTO_LOOT, PBS_AUTO_LOOT_STRINGS

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

	panel:AddSetting({ type = L.ST_LABEL, label = S.note })

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
	local function slider(key, label, min, max, step)
		panel:AddSetting({
			type = L.ST_SLIDER,
			label = label,
			min = min,
			max = max,
			step = step,
			default = self.defaults[key],
			format = "%d",
			getFunction = function()
				return self.sv[key]
			end,
			setFunction = function(value)
				self:Set(key, value)
			end,
		})
	end

	toggle("loot")
	-- the two bind switches come right after the loot switch (the order PB asked for)
	toggle("collect")
	toggle("collectTradeable")
	-- stolen items: one choice of three (the drop-down lists the labels; getFunction must return the label of the
	-- current item, which is what the library matches against its items)
	panel:AddSetting({
		type = L.ST_DROPDOWN,
		label = S.stolenMode,
		items = function()
			local items = {}
			for i, key in ipairs(self.STOLEN_MODES) do
				items[i] = { name = S["stolen_" .. key], data = key }
			end
			return items
		end,
		getFunction = function()
			return S["stolen_" .. tostring(self.sv.stolenMode)] or S.stolen_game
		end,
		setFunction = function(_, _, item)
			if item and item.data then
				self:Set("stolenMode", item.data)
			end
		end,
	})
	panel:AddSetting({ type = L.ST_LABEL, label = S.stolenNote })
	toggle("boxes")
	slider("boxReserve", S.boxReserve, self.MIN_RESERVE, self.MAX_RESERVE, 1)
	slider("boxGapMs", S.boxGap, self.MIN_GAP_MS, self.MAX_GAP_MS, 100)
	toggle("boxOnLogin")
	toggle("collectOnLogin")
	toggle("skipLocked")
	toggle("messages")

	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.openNowLabel,
		buttonText = S.openNowButton,
		clickHandler = function()
			self:SweepBoxesNow()
		end,
	})
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.bindNowLabel,
		buttonText = S.bindNowButton,
		clickHandler = function()
			self:SweepBindsNow()
		end,
	})
	-- What the last actions said (the chat window is hidden while a console menu is open).
	panel:AddSetting({
		type = L.ST_LABEL,
		label = function()
			return self:LogText()
		end,
	})
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.statusLabel,
		buttonText = S.statusButton,
		clickHandler = function()
			self:PrintStatus()
		end,
	})
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.retryLabel,
		buttonText = S.retryButton,
		clickHandler = function()
			self:Retry()
			self:Print(S.retried)
		end,
	})
end

PBS_AL_MARK("Settings")
