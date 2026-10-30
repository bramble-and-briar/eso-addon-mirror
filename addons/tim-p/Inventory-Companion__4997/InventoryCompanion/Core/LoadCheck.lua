ZO_Dialogs_RegisterCustomDialog("InventoryCompanion_DUPLICATE_LOAD_WARNING", {
    gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
    title = { text = "|cFF5252InventoryCompanion: conflicting versions|r" },
    mainText = {
        text = "|cFF5252Both DEV and release are enabled.\n\nInventoryCompanion is not safe to use in this session.|r\n\nDisable one version in your add-on profile, then reload the UI.\n\nClosing this warning does not resolve the conflict.",
    },
    buttons = {
        [1] = { text = "Close" },
    },
})

if InventoryCompanion ~= nil then
    local message = "|cFF0000InventoryCompanion: DEV and release are both enabled! Select only one in your add-on profile, then reload the UI. This session may not work correctly.|r"
    d(message)

    local eventName = "InventoryCompanion_DuplicateLoadWarning"
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_PLAYER_ACTIVATED)
        ZO_Dialogs_ShowDialog("InventoryCompanion_DUPLICATE_LOAD_WARNING")
        d(message)
    end)
end
