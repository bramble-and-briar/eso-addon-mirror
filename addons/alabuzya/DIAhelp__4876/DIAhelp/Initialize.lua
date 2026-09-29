-- The only addon-load callback; modules register their runtime events here.
local DIAhelp = DIAhelp
local initialized = false
function DIAhelp.Initialize()
    if initialized then return end
    initialized = true
    DIAhelp.Chat.Initialize()
    DIAhelp.Junk.Initialize()
    DIAhelp.Maintenance.Initialize()
    DIAhelp.CombatHUD.Initialize()
    DIAhelp.TargetHealth.Initialize()
    DIAhelp.Buffs.Initialize()
    DIAhelp.GroupFrames.Initialize()
    DIAhelp.Minimap.Initialize()
    DIAhelp.QuestTracker.Initialize()
    DIAhelp.InventoryGrid.Initialize()
    DIAhelp.Frame.Initialize()
    if DIAhelp.UseBundledQuestArrow then DIAhelp.QuestArrow:Initialize() end
end
EVENT_MANAGER:RegisterForEvent('DIAhelp', EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= 'DIAhelp' then return end
    EVENT_MANAGER:UnregisterForEvent('DIAhelp', EVENT_ADD_ON_LOADED)
    DIAhelp.Initialize()
end)
