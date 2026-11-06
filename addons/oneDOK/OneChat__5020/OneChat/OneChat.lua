local A = OneChat

local function initialize()
    EVENT_MANAGER:UnregisterForEvent(A.name, EVENT_PLAYER_ACTIVATED)
    A.chat = KEYBOARD_CHAT_SYSTEM
    if not A.chat or not A.chat.primaryContainer or not A.sv then return end
    A:BuildChannels()
    A:InstallInput()
    A:InstallTabs()
    A:InstallMessages()
    A:RestoreChatHistory()
    A:InstallOptions()
    A:InstallToolbar()
    A:InstallSettings()
    EVENT_MANAGER:RegisterForEvent(A.name, EVENT_PLAYER_DEACTIVATED, function() A:SnapshotTabs() end)
    for _, event in ipairs({ EVENT_GUILD_SELF_JOINED_GUILD, EVENT_GUILD_SELF_LEFT_GUILD,
        EVENT_GUILD_DATA_LOADED, EVENT_GUILD_RANK_CHANGED, EVENT_GROUP_UPDATE }) do
        EVENT_MANAGER:RegisterForEvent(A.name, event, function() A:RefreshMembership() end)
    end
    EVENT_MANAGER:RegisterForEvent(A.name, EVENT_GUILD_MEMBER_RANK_CHANGED, function(_, _, displayName)
        if displayName == GetDisplayName() then A:RefreshMembership() end
    end)
    EVENT_MANAGER:RegisterForEvent(A.name, EVENT_INTERFACE_SETTING_CHANGED, function() A:RefreshMembership() end)
end

EVENT_MANAGER:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= A.name then return end
    EVENT_MANAGER:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)
    if not A:InitializeSavedVariables() then return end
    EVENT_MANAGER:RegisterForEvent(A.name, EVENT_PLAYER_ACTIVATED, initialize)
end)
