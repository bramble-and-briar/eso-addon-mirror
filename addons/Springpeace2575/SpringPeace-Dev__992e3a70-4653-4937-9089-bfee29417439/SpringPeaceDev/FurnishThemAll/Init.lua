FurnishThemAll = FurnishThemAll or {}
local FTA = FurnishThemAll

EVENT_MANAGER:RegisterForEvent(FTA.name, EVENT_ADD_ON_LOADED, FTA.OnAddOnLoaded)
