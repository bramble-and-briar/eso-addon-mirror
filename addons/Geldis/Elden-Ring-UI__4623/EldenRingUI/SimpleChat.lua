local ADDON_NAME = "EldenRingUI" 

local fl_on = zo_strformat(SI_FRIENDS_LIST_FRIEND_LOGGED_ON):gsub("%.",'')
local fl_off = zo_strformat(SI_FRIENDS_LIST_FRIEND_LOGGED_OFF):gsub("%.",'')
local flc_on = zo_strformat(SI_FRIENDS_LIST_FRIEND_CHARACTER_LOGGED_ON):gsub("%.",'')
local flc_off = zo_strformat(SI_FRIENDS_LIST_FRIEND_CHARACTER_LOGGED_OFF):gsub("%.",'')

local function SetupHooksAndSettings()
    ZO_PreHook("ZO_Dialogs_ShowPlatformDialog", function(name, data, textParams)
        if name == "CONFIRM_DESTROY_ITEM_PROMPT" then
            ZO_Dialogs_ShowPlatformDialog("DESTROY_ITEM_PROMPT", nil, textParams)
            return true
        end
    end)

    ZO_PreHook(SharedChatSystem, "OnFormattedChatMessage", function(self, message, category, targetChannel, fromDisplayName, rawMessageText)
        if category == 9 then
            if string.find(message, fl_on) ~= nil then return true end
            if string.find(message, fl_off) ~= nil then return true end
            if string.find(message, flc_on) ~= nil then return true end
            if string.find(message, flc_off) ~= nil then return true end
        end
    end)

    SetSetting(SETTING_TYPE_TUTORIAL, TUTORIAL_ENABLED_SETTING_ID, 0)
end

local function OnPlayerActivated()
    zo_callLater(function()
        CHAT_SYSTEM:Minimize()
    end, 10)
end

local function OnAddonLoaded(event, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_SimpleChat", EVENT_ADD_ON_LOADED)
    
    SetupHooksAndSettings()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_SimpleChat", EVENT_ADD_ON_LOADED, OnAddonLoaded)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_SimpleChat", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)