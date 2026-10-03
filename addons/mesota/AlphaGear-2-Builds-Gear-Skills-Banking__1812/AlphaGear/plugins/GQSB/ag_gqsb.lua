------------------------------------------------------------------------------------------------------------------------
-- Global AlphaGear variable
------------------------------------------------------------------------------------------------------------------------
AG = AG or {}
AG.plugins = AG.plugins or {}

------------------------------------------------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------------------------------------------------
--Integration/Plugin coding for Greymind Quick Slot Bar
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- Global variables
------------------------------------------------------------------------------------------------------------------------
AG.plugins.GQSB = AG.plugins.GQSB or {}

------------------------------------------------------------------------------------------------------------------------
-- const
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- Local variables
------------------------------------------------------------------------------------------------------------------------
--Local "speed up" variables
local AGplugGQSB = AG.plugins.GQSB
AGplugGQSB.PRESET_ID_KEEP = -1

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

--Check if the addon Greymind QuickSlotBar is enabled and if the functions to mark items in the inventory are given
function AGplugGQSB.isAddonReady()
	return (QSB_P1 ~= nil and QSB_P2 ~= nil and QSB_P3 ~= nil and QSB_P4 ~= nil and QSB_P5 ~= nil) or false
end

function AGplugGQSB.useAddon()
	return AGplugGQSB.isAddonReady() and AG.account.Integrations.QuickSlot.UseGQCB or false
end

function AGplugGQSB.LoadQSPreset(presetId)
	if not AGplugGQSB.useAddon() then
		return
	end

	if presetId ~= AGplugGQSB.PRESET_ID_KEEP and presetId ~= nil and presetId ~= "" then
		if presetId == 1 then
			QSB_P1()
		elseif presetId == 2 then
			QSB_P2()
		elseif presetId == 3 then
			QSB_P3()
		elseif presetId == 4 then
			QSB_P4()
		elseif presetId == 5 then
			QSB_P5()
		else 
			d(zo_strformat("|cFF0000CP Quickslot preset <<1>> was not found...|r", presetId)) 
			return
		end
		
		d(zo_strformat("|cFFFFFFCP Quickslot preset <<1>> loaded.|r", presetId)) 
	end
end



function AGplugGQSB.GetQSPresets()
	local QSPresets = {}
	
	-- there are 5 presets. 
	for i = 1, 5  do
		local presetInfo = {}

		presetInfo.label = 'Preset '..i
		presetInfo.id = i

		QSPresets[i] = presetInfo
	end

    return QSPresets
end
