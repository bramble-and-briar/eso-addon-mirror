if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS
local INTERACT_TYPE_FRIEND_REQUEST = 6

--[[
local function OnKeyboardAccept(data)
    FCOChangeStuff._friendsDataAccept = data

    --TODO: Accept friends request and remove friend request from notifications
end

local function OnKeyboardDecline(data)
    FCOChangeStuff._friendsDataDecline = data

    --TODO: Decline friends request and remove friend request from notifications
end


--Show/hide the HUD zone quest helper
local function OnFriendsRequest(eventName, displayName)
d("[FCOCS]Friends request added - displayname: " .. displayName)
    local libN = FCOChangeStuff.LibNotifications
    local settings = FCOChangeStuff.settingsVars.settings
    if libN ~= nil and settings.moveFriendRequestToNotificationArea then
        --Is the notification provider given?
        local libNNp = FCOChangeStuff.notificationsProvider
        libNNp = libNNp or libN:CreateProvider()
        if not libNNp then return end
        local addonVars = FCOChangeStuff.addonVars
        --The current time or the time the request was sent from the SavedVariables
        local requestSentString = ""
        local requestSentDateTime = 0
        local data = settings.friendsRequestData
        if data and data[displayName] then
            requestSentDateTime = data[displayName].requestDateTime
        else
            data[displayName] = {}
            data[displayName].requestDateTime = GetTimeStamp()
        end
        requestSentDateTime = requestSentDateTime or 0
        if requestSentDateTime == 0 then
            requestSentDateTime = data[displayName].requestDateTime
        end
        requestSentString = FCOChangeStuff.getDateTimeFormatted(requestSentDateTime)

        local note = string.format("%s %q %s", "The following account requested to add you to it's friendlist:\n", displayName, "\nRequest made: " .. requestSentString)
        local customMessage = displayName .. " requested to be your friend!"

        --Move the friends request to the notification area using LibNotifications
        local newFriendsRequestMessage = {
            dataType                = NOTIFICATIONS_REQUEST_DATA,       --accept, decline buttons
            secsSinceRequest        = ZO_NormalizeSecondsSince(0),
            note                    = note,
            message                 = customMessage,
            heading                 = addonVars.addonName,
            texture                 = "/esoui/art/chatwindow/chat_friendsonline_up.dds",
            shortDisplayText        = customMessage,
            controlsOwnSounds       = true,
            keyboardAcceptCallback  = OnKeyboardAccept,
            keybaordDeclineCallback = OnKeyboardDecline,
            gamepadAcceptCallback   = OnKeyboardAccept,
            gamepadDeclineCallback  = OnKeyboardDecline,
            data = {
            }, -- Place any custom data you want to store here
        }
        table.insert(libNNp.notifications, newFriendsRequestMessage)
        data[displayName].notificationTableIndex = table.getn(libNNp.notifications)
        libNNp:UpdateNotifications()

        --Abort the event here now
        return true
    end
    return false
end

local function OnFriendsRequestRemoved(eventName, displayName)
d("[FCOCS]Friends request removed - displayname: " .. displayName)
    local libN = FCOChangeStuff.LibNotifications
    local settings = FCOChangeStuff.settingsVars.settings
    if libN ~= nil and settings.moveFriendRequestToNotificationArea then
        local data = settings.friendsRequestData
        if data and data[displayName] then
            local libNNp = FCOChangeStuff.notificationsProvider
            libNNp = libNNp or libN:CreateProvider()
            if not libNNp then return end
            --Remove the entry from the notifications area notifications table
            table.remove(libNNp.notifications, data[displayName].notificationTableIndex)
            --Remove the displayName from the request sent table
            data[displayName] = nil
            --Update the notifications area
            libNNp:UpdateNotifications()
        end
    end
end


local function OnFriendsRequestNoteUpdated(eventName, displayName, newNoteText)
d("[FCOCS]Friends request note update - displayname: " .. displayName .. ", noteText: " ..tostring(newNoteText))
    local libN = FCOChangeStuff.LibNotifications
    local settings = FCOChangeStuff.settingsVars.settings
    if libN ~= nil and settings.moveFriendRequestToNotificationArea then
        local data = settings.friendsRequestData
        if data and data[displayName] then
            local note = data[displayName].note
            if note == nil or (note and note ~= newNoteText) then
                data[displayName].note = newNoteText
                local libNNp = FCOChangeStuff.notificationsProvider
                libNNp = libNNp or libN:CreateProvider()
                if not libNNp then return end
                --Todo: Set the new notification text to the notification inside the notification area
                -->Todo: HOW?
                --Update the notifications area
                --libNNp:UpdateNotifications()
            end
        end
    end
end
]]

local function PreHookedPlayerToPlayerTryShowingResponseLabel()
--d("[FCOCS]PreHookedPlayerToPlayerTryShowingResponseLabel")
    --Only for friends requests
    local p2p = PLAYER_TO_PLAYER
    local doAbort = false
    if p2p and p2p.incomingQueue and #p2p.incomingQueue > 0 then
        local iq1 = p2p.incomingQueue[1] -- get first entry in queue
        if iq1 and iq1.pendingResponse and iq1.incomingType == INTERACT_TYPE_FRIEND_REQUEST then -- friends request?
            local goOn = true
            --Check for expiration
            if iq1.messageFormat and iq1.expiresAtS then
                if GetFrameTimeSeconds() > iq1.expiresAtS then
                    goOn = false
                end
            end
            if goOn then
                iq1.seen = true

                p2p:SetHidden(true)
                p2p.promptKeybindButton1:SetHidden(true)
                p2p.promptKeybindButton2:SetHidden(true)
                if (not p2p.isInteracting) or (not IsConsoleUI()) then
                    p2p.gamerID:SetHidden(true)
                end
                p2p.actionKeybindButton:SetHidden(true)
                p2p.actionKeybindButton:SetEnabled(true)
                p2p.additionalInfo:SetHidden(true)
                p2p.targetLabel:SetHidden(true)

                p2p.currentTargetCharacterName = nil
                p2p.currentTargetCharacterNameRaw = nil
                p2p.currentTargetDisplayName = nil
                p2p.showingResponsePrompt = false
                p2p.promptKeybindButton1.shouldHide = true
                p2p.promptKeybindButton2.shouldHide = true
                p2p.shouldShowNotificationKeybindLayer = false

                local notificationsKeybindLayerName = GetString(SI_KEYBINDINGS_LAYER_NOTIFICATIONS)
                if IsActionLayerActiveByName(notificationsKeybindLayerName) then
                    RemoveActionLayerByName(notificationsKeybindLayerName)
                end
                doAbort = true
            end
        end
    end
    --False: Run original code / True: Abort PreHook and do not run original code afterwards
    return doAbort
end

--======== Friends ===========================================================
function FCOChangeStuff.friendsStuff()
    local addonVars = FCOChangeStuff.addonVars
    local settings = FCOChangeStuff.settingsVars.settings
    --[[
--Register the event for the friends request
    if settings.moveFriendRequestToNotificationArea then
        EVENT_MANAGER:UnregisterForEvent(addonVars.addonName,   EVENT_INCOMING_FRIEND_INVITE_ADDED)
        EVENT_MANAGER:UnregisterForEvent(addonVars.addonName,   EVENT_INCOMING_FRIEND_INVITE_REMOVED)
        EVENT_MANAGER:UnregisterForEvent(addonVars.addonName,   EVENT_INCOMING_FRIEND_INVITE_NOTE_UPDATED)
        EVENT_MANAGER:RegisterForEvent(addonVars.addonName,     EVENT_INCOMING_FRIEND_INVITE_ADDED,         OnFriendsRequest)
        EVENT_MANAGER:RegisterForEvent(addonVars.addonName,     EVENT_INCOMING_FRIEND_INVITE_REMOVED,       OnFriendsRequestRemoved)
        EVENT_MANAGER:RegisterForEvent(addonVars.addonName,     EVENT_INCOMING_FRIEND_INVITE_NOTE_UPDATED,  OnFriendsRequestNoteUpdated)

        --Load library LibNotifications (if needed)
        FCOChangeStuff.LibNotifications = LibNotifications
        if FCOChangeStuff.LibNotifications == nil and LibStub then
            FCOChangeStuff.LibNotifications = LibStub("LibNotifications", true)
        end
    end
    ]]
    if settings.hideFriendRequestAcceptDeclinePanel then
        ZO_PreHook(PLAYER_TO_PLAYER, "TryShowingResponseLabel", PreHookedPlayerToPlayerTryShowingResponseLabel)
    end
end