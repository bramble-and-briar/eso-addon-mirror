local CAM = CraftPawns
CAM.Settings = {}
function CAM.Settings:Initialize()
    -- Kept dependency-free. Core settings live in SavedVariables; commands are
    -- intentionally small so the addon works without LibAddonMenu.
    SLASH_COMMANDS["/craftpawnresetorder"] = function() CAM.SavedData:ResetOrder(); CAM.UI:Refresh() end
    SLASH_COMMANDS["/craftpawndebug"] = function() CAM.sv.settings.debug=not CAM.sv.settings.debug; d("[CraftPawns] Debug "..(CAM.sv.settings.debug and "on" or "off")) end
    SLASH_COMMANDS["/craftpawn"] = function() CAM.UI:Toggle() end
end
