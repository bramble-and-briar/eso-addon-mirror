if InventoryCompanion ~= nil then
    local message = "|cFF0000InventoryCompanion: DEV and release are both enabled! Select only one in your add-on profile, then reload the UI. This session may not work correctly.|r"
    d(message)

    local eventName = "InventoryCompanion_DuplicateLoadWarning"
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_PLAYER_ACTIVATED)
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.GENERAL_ALERT_ERROR, message)
        d(message)
    end)
end
