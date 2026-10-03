------------------------------------------------------------------------------------------------------------------------
-- Global AlphaGear variable
------------------------------------------------------------------------------------------------------------------------
AG = AG or {}
AG.plugins = AG.plugins or {}

------------------------------------------------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------------------------------------------------
--Integration/Plugin coding for AlphaStyle addon.
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- Global variables
------------------------------------------------------------------------------------------------------------------------
AG.plugins.AlphaStyle = AG.plugins.AlphaStyle or {}

------------------------------------------------------------------------------------------------------------------------
-- Local variables
------------------------------------------------------------------------------------------------------------------------
--Local "speed up" variables
local AGplugAS = AG.plugins.AlphaStyle

AGplugAS.STYLE_KEEP = -1

------------------------------------------------------------------------------------------------------------------------
-- Functions
------------------------------------------------------------------------------------------------------------------------

--- Writes trace messages to the console
-- fmt with %d, %s,
local function trace(fmt, ...)
	if AG.isDebug then
		d(string.format(fmt, ...))
	end
end

--Check if the addon FCOItemSaver is enabled and if the functions to mark items in the inventory are given
function AGplugAS.isAddonReady()
	return (ASAPI ~= nil and ASAPI.GetStyles ~= nil) or false
end

function AGplugAS.useAddon()
	return AGplugAS.isAddonReady() and AG.account.Integrations.Styling.UseAlphaStyle or false
end

function AGplugAS.GetStyles()
	return ASAPI.GetStyles()
end

function AGplugAS.LoadStyle(styleId)
	if styleId ~= AGplugAS.STYLE_KEEP then
		return ASAPI.LoadStyle(styleId)
	end
end