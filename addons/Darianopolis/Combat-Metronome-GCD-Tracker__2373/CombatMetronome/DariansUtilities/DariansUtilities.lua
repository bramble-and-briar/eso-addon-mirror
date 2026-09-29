DariansUtilities = {
	name = "DariansUtilities",
	major = 8,
	minor = 7,
	version = "1.8.7"
}
local Util = DariansUtilities

function Util.onLoad(addon, onLoad)
	EVENT_MANAGER:RegisterForEvent(addon.name.."Load ", EVENT_ADD_ON_LOADED, function(_, name)
	    if addon.loaded or name ~= addon.name then return end

		-- Util:Log("AddonLoad: ", name)
	    onLoad(addon)
	        
	    addon.loaded = true
	end)
end

Util.prelog = { }

function Util:Log(...)
	local output = ""
	local segments = { ... }
	for _, segment in pairs(segments) do
		output = output..tostring(segment)
	end

	if self.prelog then
		self.prelog[#self.prelog + 1] = output
	else
		d(output)
	end
end

function Util:Write()
	for _, o in ipairs(self.prelog) do
		d(o)
	end
	self.prelog = nil
end

EVENT_MANAGER:RegisterForUpdate("DariansUtilitiesPrelog", 1000, function()
	Util:Write()
	EVENT_MANAGER:UnregisterForUpdate("DariansUtilitiesPrelog")
end)