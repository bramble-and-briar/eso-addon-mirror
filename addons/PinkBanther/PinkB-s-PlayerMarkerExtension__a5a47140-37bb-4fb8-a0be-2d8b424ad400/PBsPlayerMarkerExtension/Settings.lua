-- The settings panel (LibHarvensAddonSettings, optional: without it the add-on runs on its defaults).
local A, S = PBS_PME, PBS_PME_STRINGS

function A:InitSettings()
	local L = LibHarvensAddonSettings
	if not L then
		self.panelWhy = "LibHarvensAddonSettings is not installed"
		return
	end
	local panel = L:AddAddon(self.title)
	if not panel then
		self.panelWhy = "the library did not give a panel"
		return
	end
	self.panel = panel
	panel.author, panel.version, panel.allowDefaults = self.author, self.version, true

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
	local function slider(key, step)
		local range = self.RANGES[key]
		panel:AddSetting({
			type = L.ST_SLIDER,
			label = S[key],
			min = range[1],
			max = range[2],
			step = step,
			default = self.defaults[key],
			getFunction = function()
				return self.sv[key]
			end,
			setFunction = function(value)
				self:Set(key, value)
			end,
		})
	end
	local function button(label, text, handler)
		panel:AddSetting({
			type = L.ST_BUTTON,
			label = label,
			buttonText = text,
			clickHandler = handler,
		})
	end

	toggle("enabled")
	slider("wheelSlots", 1)

	-- which icon sits in each extra place of the wheel
	local items = {}
	for id = 1, A.ICON_COUNT do
		items[id] = { name = string.format("%d  %s", id, A.IconName(id)), data = id }
	end
	for n = 1, A.MAX_SLOTS do
		local key = "slot" .. n
		panel:AddSetting({
			type = L.ST_DROPDOWN,
			label = string.format(S.slot, n),
			items = items,
			default = items[self.defaults[key]].name,
			getFunction = function()
				return (items[self.sv[key]] or items[1]).name
			end,
			setFunction = function(_, _, item)
				self:Set(key, item.data)
			end,
		})
	end

	toggle("shareSend")
	toggle("shareReceive")
	toggle("markSelf")
	toggle("showSelf")
	toggle("frameMarks")
	toggle("throughWalls")
	slider("size", 5)
	slider("height", 10)
	slider("heightPerMetre", 1)
	slider("facingOffset", 15)
	slider("opacity", 5)
	toggle("sound")
	toggle("chat")
	button(S.test, S.testButton, function()
		local ok, why = self:StartNextTest()
		if not ok then
			A.Say(string.format(S.testNoPosition, tostring(why)))
		end
	end)
	button(S.clear, S.clearButton, function()
		self:ActClearAll()
	end)
	button(S.reset, S.resetButton, function()
		self:Reset()
		if panel.UpdateControls then
			panel:UpdateControls()
		end
	end)
end

-- Something was changed (key = nil: everything).
function A:OnSettingChanged(key)
	-- the wheel's list is built each time the wheel opens, so the next opening sees the change
	self.wheel.layout = nil
	if key == nil or key == "enabled" then
		if not self.sv.enabled then
			self.engineCheck = nil
			self:HideWorld()
		end
		-- the wheel's window goes back to where the game put it while the add-on is off (and in front again when it is on)
		pcall(self.RaiseWheel, self, not self.sv.enabled)
	end
	-- the group frames are looked at again at once (Frames.lua)
	if self.frames then
		self.frames.dirty = true
	end
end

A.MARK("Settings")
