-- The settings panel (LibHarvensAddonSettings, optional). Switches, one choice, one number and three buttons (typing
-- /pbwrit on a console is awkward). Rows are pooled and shared with other add-ons' panels, so every row reads its value
-- from the saved variables.

local A, S = PBS_CRAFT_ASSIST, PBS_CRAFT_ASSIST_STRINGS

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

	local function head(text)
		panel:AddSetting({ type = L.ST_SECTION or L.ST_LABEL, label = text })
	end
	local function label(text)
		panel:AddSetting({ type = L.ST_LABEL, label = text })
	end
	local function toggle(key, text)
		panel:AddSetting({
			type = L.ST_CHECKBOX,
			label = text or S[key],
			default = self.defaults[key],
			getFunction = function()
				return self.sv[key]
			end,
			setFunction = function(value)
				self:Set(key, value)
			end,
		})
	end
	local function button(labelText, buttonText, fn)
		panel:AddSetting({ type = L.ST_BUTTON, label = labelText, buttonText = buttonText, clickHandler = fn })
	end

	label(S.note)

	head(S.headTalk)
	toggle("autoAccept")
	toggle("closeBoard")
	toggle("autoDeliver")

	head(S.headCraft)
	toggle("autoCraft")
	toggle("autoExit")
	label(S.craftsNote)
	for _, key in ipairs(self.CRAFT_ORDER) do
		toggle(key)
	end
	panel:AddSetting({
		type = L.ST_DROPDOWN,
		label = S.styleScope,
		items = function()
			local items = {}
			for i, key in ipairs(self.STYLE_SCOPES) do
				items[i] = { name = S["style_" .. key], data = key }
			end
			return items
		end,
		getFunction = function()
			return S["style_" .. tostring(self.sv.styleScope)] or S.style_basic
		end,
		setFunction = function(_, _, item)
			if item and item.data then
				self:Set("styleScope", item.data)
			end
		end,
	})
	label(S.styleNote)

	toggle("panel")
	panel:AddSetting({
		type = L.ST_DROPDOWN,
		label = S.panelPos,
		items = function()
			local items = {}
			for i, key in ipairs(self.POSITIONS) do
				items[i] = { name = S["pos_" .. key], data = key }
			end
			return items
		end,
		getFunction = function()
			return S["pos_" .. tostring(self.sv.panelPos)] or S.pos_topright
		end,
		setFunction = function(_, _, item)
			if item and item.data then
				self:Set("panelPos", item.data)
			end
		end,
	})

	head(S.headBank)
	toggle("bank")
	toggle("bankMaterials")

	head(S.headBoxes)
	toggle("boxes")
	panel:AddSetting({
		type = L.ST_SLIDER,
		label = S.boxReserve,
		min = self.MIN_RESERVE,
		max = self.MAX_RESERVE,
		step = 1,
		default = self.defaults.boxReserve,
		format = "%d",
		getFunction = function()
			return self.sv.boxReserve
		end,
		setFunction = function(value)
			self:Set("boxReserve", value)
		end,
	})
	toggle("boxOnLogin")
	button(S.openNowLabel, S.openNowButton, function()
		self:OpenNow()
	end)

	toggle("messages")
	-- what the last actions said (the chat window is hidden while a console menu is open)
	panel:AddSetting({
		type = L.ST_LABEL,
		label = function()
			return self:LogText()
		end,
	})
	button(S.statusLabel, S.statusButton, function()
		self:PrintStatus()
	end)
	button(S.retryLabel, S.retryButton, function()
		self:Retry()
		self:Print(S.retried)
	end)
end

PBS_CA_MARK("Settings")
