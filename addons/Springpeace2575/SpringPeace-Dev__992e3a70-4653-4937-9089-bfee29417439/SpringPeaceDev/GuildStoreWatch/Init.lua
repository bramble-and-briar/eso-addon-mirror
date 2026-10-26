GuildStoreWatch = GuildStoreWatch or {}
local GSW = GuildStoreWatch

EVENT_MANAGER:RegisterForEvent(GSW.name, EVENT_ADD_ON_LOADED, GSW.OnAddOnLoaded)
