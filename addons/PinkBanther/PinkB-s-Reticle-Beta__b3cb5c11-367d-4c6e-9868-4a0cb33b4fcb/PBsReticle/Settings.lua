local A, S = PBS_RETICLE, PBS_RETICLE_STRINGS

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
	panel.author, panel.version, panel.allowDefaults = self.author, self.version, true
	CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", function(_, selected)
		self:OnAddonSelected(selected)
	end)

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
	-- the names of the values are S["<key>_<value>"]
	local function choice(key, values)
		local items, byValue = {}, {}
		for _, value in ipairs(values) do
			local item = { name = S[key .. "_" .. value], data = value }
			items[#items + 1], byValue[value] = item, item
		end
		panel:AddSetting({
			type = L.ST_DROPDOWN,
			label = S[key],
			items = items,
			default = byValue[self.defaults[key]].name,
			getFunction = function()
				return byValue[self.sv[key]].name
			end,
			setFunction = function(_, _, item)
				if item then
					self:Set(key, item.data)
				end
			end,
		})
	end

	toggle("enabled")
	toggle("preview")
	choice("style", self.STYLES)
	choice("color", self.COLOR_NAMES)
	toggle("auto")
	slider("size", 5)
	choice("weight", self.WEIGHTS)
	slider("gap", 1)
	toggle("dot")
	slider("outline", 10)
	slider("opacity", 5)
	slider("idle", 5)
	toggle("hit")
	toggle("anim")
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.reset,
		buttonText = S.resetButton,
		clickHandler = function()
			self:Reset()
			if panel.UpdateControls then
				panel:UpdateControls()
			end
		end,
	})
end
