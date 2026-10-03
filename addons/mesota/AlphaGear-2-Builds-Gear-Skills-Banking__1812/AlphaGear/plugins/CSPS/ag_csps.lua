------------------------------------------------------------------------------------------------------------------------
-- Global AlphaGear variable
------------------------------------------------------------------------------------------------------------------------
AG = AG or {}
AG.plugins = AG.plugins or {}

------------------------------------------------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------------------------------------------------
--Integration/Plugin coding for Champion Point Slots addon.
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- Global variables
------------------------------------------------------------------------------------------------------------------------
AG.plugins.CSPS = AG.plugins.CSPS or {}

------------------------------------------------------------------------------------------------------------------------
-- const
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- Local variables
------------------------------------------------------------------------------------------------------------------------
--Local "speed up" variables
local AGplugCSPS = AG.plugins.CSPS
AGplugCSPS.GROUP_ID_KEEP = -1

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

-- Check if CSPS is loaded
function AGplugCSPS.isAddonReady()
	return (CSPS ~= nil and CSPS.setCPBuild ~= nil) or false
end

function AGplugCSPS.useAddon()
	return AGplugCSPS.isAddonReady() and AG.account.Integrations.Champion.UseCSPS or false
end

function AGplugCSPS.LoadCPSGroup(groupId, groupName)
	if not AGplugCSPS.useAddon() then
		return
	end

	if groupId ~= AGplugCSPS.GROUP_ID_KEEP and groupId ~= nil and groupId ~= "" then

		if groupId > 0 and groupId < 21 then
			CSPS.groupApply(groupId)
			d(zo_strformat("|cFFFFFFCP set <<1>> / <<2>> loaded.|r", groupId, groupName)) 
			return
		end

		-- host/profile was not found
		d(zo_strformat("|cFF0000CP set <<1>> / <<2>> was not found...|r", groupId, groupName)) 
	end
end


function AGplugCSPS.GetCPSGroups()
	local CPSGroups = {}
	
	-- there are 20 groupe. 
	for i = 1, 20  do
		local groupInfo = {}

		groupInfo.label = 'Group '..i
		groupInfo.id = 1

		CPSGroups[i] = groupInfo
	end

    return CPSGroups
end


