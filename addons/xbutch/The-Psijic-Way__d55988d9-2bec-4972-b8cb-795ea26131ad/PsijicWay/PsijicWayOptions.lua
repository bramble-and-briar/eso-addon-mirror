local addon = PsijicWay
if not addon then return end

local MapPins = addon.internal and addon.internal.mapPins
local LAM = LibAddonMenu2
if not LAM then return end

local defaults = addon.defaults

local panelData = {
	type = "panel",
	name = addon.addOnDisplayName or addon.addOnName,
	author = addon.author or "",
	version = addon.version or ""
}

local optionsData = {
	{
		type = "slider",
		name = "Pin Size",
		min = 32,
		max = 128,
		step = 8,
		getFunc = function() return addon.savedVars.pinSize end,
		setFunc = function(value)
			addon.savedVars.pinSize = value
			MapPins:SetLayoutKey(addon.pinType, "size", value)
			MapPins:RefreshPins(addon.pinType)
		end,
		default = defaults.pinSize
	}
}

function addon:CreateOptions()
	LAM:RegisterAddonPanel(addon.addOnName .. "Panel", panelData)
	LAM:RegisterOptionControls(addon.addOnName .. "Panel", optionsData)
end
