-- The only addon-load callback; modules register their runtime events here.
local AlabuzyaUI = AlabuzyaUI
local initialized = false
function AlabuzyaUI.Initialize()
    if initialized then return end
    initialized = true
    AlabuzyaUI.Settings.Initialize()
    AlabuzyaUI.Theme.Configure()
    AlabuzyaUI.Compatibility.Initialize()
    AlabuzyaUI.Chat.Initialize()
    AlabuzyaUI.Junk.Initialize()
    AlabuzyaUI.Maintenance.Initialize()
    AlabuzyaUI.CombatHUD.Initialize()
    AlabuzyaUI.TargetHealth.Initialize()
    AlabuzyaUI.Buffs.Initialize()
    AlabuzyaUI.GroupFrames.Initialize()
    AlabuzyaUI.Minimap.Initialize()
    AlabuzyaUI.OverlayMap.Initialize()
    AlabuzyaUI.QuestTracker.Initialize()
    AlabuzyaUI.InventoryGrid.Initialize()
    AlabuzyaUI.Core.Initialize()
    AlabuzyaUI.AssistantPanel.Initialize()
    AlabuzyaUI.GoldLedger.Initialize()
end
EVENT_MANAGER:RegisterForEvent('AlabuzyaUI', EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= 'AlabuzyaUI' then return end
    EVENT_MANAGER:UnregisterForEvent('AlabuzyaUI', EVENT_ADD_ON_LOADED)
    AlabuzyaUI.Initialize()
end)
