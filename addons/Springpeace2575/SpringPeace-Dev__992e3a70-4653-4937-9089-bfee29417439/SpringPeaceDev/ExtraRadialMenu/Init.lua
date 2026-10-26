ExtraRadialMenu = ExtraRadialMenu or {}
local ERM = ExtraRadialMenu

EVENT_MANAGER:RegisterForEvent(ERM.name, EVENT_ADD_ON_LOADED, ERM.OnAddOnLoaded)
