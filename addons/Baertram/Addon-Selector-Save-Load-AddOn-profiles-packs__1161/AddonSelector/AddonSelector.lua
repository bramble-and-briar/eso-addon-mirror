--[[
------------------------------------------------------------------------------------------------------------------------
 Changelog
------------------------------------------------------------------------------------------------------------------------
2026-10-03
AddonSelector v3.23


------------------------------------------------------------------------------------------------------------------------
 Known bugs - Max: 19
------------------------------------------------------------------------------------------------------------------------
20251117 - #18 Selecting a keybind at the keybind submenu at the context menu of a saved pack will close the context menu after the 2nd keybind has changed in that menu.
-->Workaround: After changing one keybind at the context menu's keybind submenu, select any other entry in the main context menu e.g. and then reopen the submenu for keybinds.



Feature requests:
20251010 - Show missing (non installed) dependencies, of all addons, at a collapsible UI at the addon manager
20251112 - Add slash command /asnone to disable all addons and reload the UI

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
]]

local AS = AddonSelectorGlobal

--Addon internal variables
local ADDON_NAME = AS.name

local utility = AS.utility

--Object variables
local ADDON_MANAGER
local ADDON_MANAGER_OBJECT


--ZOs reference variables
local EM = EVENT_MANAGER

--local tos = tostring

--local AddonSelector_GetLocalizedText = AddonSelector_GetLocalizedText

------------------------------------------------------------------------------------------------------------------------
-- Addon Selector
---------------------------------------------------------------------------------------------------------------------------
ADDON_MANAGER        = utility.GetAddonManager()
ADDON_MANAGER_OBJECT = utility.GetAddonManagerObject() --maybe nil here, updated later at EVENT_ADD_ON_LOADED again

---------------------------------------------------------------------
--  Register Events --
---------------------------------------------------------------------
EM:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, AS.OnAddOnLoaded)