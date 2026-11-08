local A, S = PBS_CABS, PBS_CABS_STRINGS

-- Choices for the numeric settings that are better picked from a list than slid across a long range
-- with a controller.
local MINUTES = { 0, 1, 5, 10, 15, 30, 60, 120, 180, 360, 720, 1200, 1440 }
local AMOUNTS = { 1, 5, 10, 25, 125 }
local HOURS = { 6, 12, 24, 48, 72, 168 }
local SIZE_STEPS = { 1, 2, 3, 4, 5, 6, 7, 8 }

local function MinutesName(minutes)
	if minutes == 0 then
		return S.none
	elseif minutes < 60 then
		return string.format(S.unitMin, minutes)
	end
	return string.format(S.unitHour, minutes / 60)
end

-- The listed value nearest to `value` (the saved one can be anything the commands allow).
local function Nearest(values, value)
	local best = values[1]
	for _, candidate in ipairs(values) do
		if math.abs(candidate - value) < math.abs(best - value) then
			best = candidate
		end
	end
	return best
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
	-- A drop-down over `values`; `name(value)` is what each is called.
	local function choice(key, values, name)
		local items, byValue = {}, {}
		for _, value in ipairs(values) do
			local item = { name = name(value), data = value }
			items[#items + 1], byValue[value] = item, item
		end
		panel:AddSetting({
			type = L.ST_DROPDOWN,
			label = S[key],
			items = items,
			default = byValue[Nearest(values, self.defaults[key])].name,
			getFunction = function()
				local current = self.sv[key]
				return (byValue[current] or byValue[Nearest(values, tonumber(current) or values[1])]).name
			end,
			setFunction = function(_, _, item)
				if item then
					self:Set(key, item.data)
				end
			end,
		})
	end
	-- A text size is a step; what is shown is the size of the font in pixels.
	local function sizeName(step)
		return tostring(A.TEXT_SIZES[step])
	end

	toggle("enabled")
	toggle("showCatalog")
	toggle("showWithoutCompanion")
	toggle("preview")
	-- Size and place of the list. The panel draws it over itself while these are changed.
	choice("textSize", SIZE_STEPS, sizeName)
	choice("headerSize", SIZE_STEPS, sizeName)
	slider("width", 10)
	slider("x", 5)
	slider("y", 5)
	slider("opacity", 5)
	slider("maxRows", 1)
	slider("columns", 1)
	choice("minAmount", AMOUNTS, function(value)
		return string.format(S.unitAmount, value)
	end)
	choice("expireHours", HOURS, function(value)
		return string.format(S.unitHour, value)
	end)
	toggle("useEstimates")
	choice("est1", MINUTES, MinutesName)
	choice("est5", MINUTES, MinutesName)
	choice("est10", MINUTES, MinutesName)
	choice("est25", MINUTES, MinutesName)
	toggle("showNegative")
	panel:AddSetting({
		type = L.ST_BUTTON,
		label = S.clear,
		buttonText = S.clearButton,
		clickHandler = function()
			self:Clear()
		end,
	})
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

if PBS_CABS_MARK then
	PBS_CABS_MARK("Settings")
end
