local ADDON_NAME = "EldenRingUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_SimpleChat"

local FRIEND_STATUS_MESSAGES = {
    (zo_strformat(SI_FRIENDS_LIST_FRIEND_LOGGED_ON):gsub("%.", "")),
    (zo_strformat(SI_FRIENDS_LIST_FRIEND_LOGGED_OFF):gsub("%.", "")),
    (zo_strformat(SI_FRIENDS_LIST_FRIEND_CHARACTER_LOGGED_ON):gsub("%.", "")),
    (zo_strformat(SI_FRIENDS_LIST_FRIEND_CHARACTER_LOGGED_OFF):gsub("%.", "")),
}

local function IsFriendStatusMessage(message)
    for _, text in ipairs(FRIEND_STATUS_MESSAGES) do
        if string.find(message, text) then return true end
    end
    return false
end

local function SetupHooksAndSettings()
    ZO_PreHook("ZO_Dialogs_ShowPlatformDialog", function(name, _, textParams)
        if name == "CONFIRM_DESTROY_ITEM_PROMPT" then
            ZO_Dialogs_ShowPlatformDialog("DESTROY_ITEM_PROMPT", nil, textParams)
            return true
        end
    end)

    ZO_PreHook(SharedChatSystem, "OnFormattedChatMessage", function(_, message, category)
        if category == 9 and IsFriendStatusMessage(message) then
            return true
        end
    end)

    SetSetting(SETTING_TYPE_TUTORIAL, TUTORIAL_ENABLED_SETTING_ID, 0)
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED)
    SetupHooksAndSettings()
end

local function OnPlayerActivated()
    zo_callLater(function()
        CHAT_SYSTEM:Minimize()
    end, 10)
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, OnAddonLoaded)
EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)