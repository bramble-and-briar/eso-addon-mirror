local HideFriendStatus = {
    name = "HideFriendStatus"
}

function HideFriendStatus.SuppressStatusMessages()
    -- 1. Unregister the event from the base game chat manager
    EVENT_MANAGER:UnregisterForEvent("ChatSystem_OnEventId" .. EVENT_FRIEND_PLAYER_STATUS_CHANGED, EVENT_FRIEND_PLAYER_STATUS_CHANGED)

    -- 2. Overwrite global chat handlers (targets default UI and baseline addons)
    if CHATHANDLERS and CHATHANDLERS[EVENT_FRIEND_PLAYER_STATUS_CHANGED] then
        CHATHANDLERS[EVENT_FRIEND_PLAYER_STATUS_CHANGED] = function() return true end
    end

    -- 3. Overwrite pChat handlers directly
    if pChat then
        if pChat.OnFriendPlayerStatusChanged then
            pChat.OnFriendPlayerStatusChanged = function() return true end
        elseif pChat.OnFriendStatusChanged then
            pChat.OnFriendStatusChanged = function() return true end
        end
    end

    -- 4. Clear out the UI notification center (targets LibNotification provider triggers)
    -- This intercepts the notification payload before it gets added to the UI provider table
    if ZO_NotificationManager then
        ZO_PreHook(ZO_NotificationManager, "AddNotificationOnScreen", function(self, notificationData)
            if notificationData and (notificationData.heading == "Friends" or notificationData.dataType == NOTIFICATIONS_ALERT_DATA) then
                -- Return true to completely block the on-screen alert construction
                return true 
            end
        end)
    end
end

-- Delay code execution until all addon tables (like pChat & LibNotification) are fully initialized in memory
function HideFriendStatus.OnPlayerActivated(event)
    EVENT_MANAGER:UnregisterForEvent(HideFriendStatus.name, EVENT_PLAYER_ACTIVATED)
    HideFriendStatus.SuppressStatusMessages()
end

-- Initialize sequence 
function HideFriendStatus.OnAddOnLoaded(event, addonName)
    if addonName == HideFriendStatus.name then
        EVENT_MANAGER:UnregisterForEvent(HideFriendStatus.name, EVENT_ADD_ON_LOADED)
        EVENT_MANAGER:RegisterForEvent(HideFriendStatus.name, EVENT_PLAYER_ACTIVATED, HideFriendStatus.OnPlayerActivated)
    end
end

EVENT_MANAGER:RegisterForEvent(HideFriendStatus.name, EVENT_ADD_ON_LOADED, HideFriendStatus.OnAddOnLoaded)
