-- Fury's Addons Menu: the one key of the Fury sidebar, and its saved settings. This small folder
-- ships inside every Fury addon. The game loads it once, however many Fury addons are installed,
-- so the key shows once in Controls > Keybindings, under Fury's Addons. The sidebar itself is
-- built by the addons (their Theme.lua), which put themselves on the list below.

if not rawget(_G, "FurysAddonMenu") then
    _G["FurysAddonMenu"] = { entries = {}, lib = 0 }
end

ZO_CreateStringId("SI_BINDING_NAME_FURYSADDONMENU_TOGGLE", "Show or hide the Fury sidebar")

-- The sidebar's settings (shown, place, row or column, locked, hidden in combat), one set for the
-- whole PC.
local function OnLoaded(_, name)
    if name ~= "FurysAddonMenu" then return end
    EVENT_MANAGER:UnregisterForEvent("FurysAddonMenu", EVENT_ADD_ON_LOADED)
    if not rawget(_G, "FurysAddonMenu_SV") then _G["FurysAddonMenu_SV"] = {} end
    rawget(_G, "FurysAddonMenu").sv = rawget(_G, "FurysAddonMenu_SV")
end
EVENT_MANAGER:RegisterForEvent("FurysAddonMenu", EVENT_ADD_ON_LOADED, OnLoaded)
