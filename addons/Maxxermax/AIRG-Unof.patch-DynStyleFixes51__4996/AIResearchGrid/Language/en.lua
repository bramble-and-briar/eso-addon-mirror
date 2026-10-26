--[[
	EN Language file, made by Ayantir
]]

local strings = {
	AIRG_OPTIONS_RELATIVE					= "Set Relative to:",
	AIRG_OPTIONS_RELATIVE_TO				= "|c4AFF6ERelative to:|r",
	AIRG_OPTIONS_ALL							= "#ALL",
	AIRG_KEYBIND_TOGGLE						= "Toggle AI Research Grid",
}

for stringId, stringValue in pairs(strings) do
   ZO_CreateStringId(stringId, stringValue)
   SafeAddVersion(stringId, 1)
end