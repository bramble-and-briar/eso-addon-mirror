if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

------------------------------------------------------------------------------------------------------------------------
-- Chat --
------------------------------------------------------------------------------------------------------------------------

local myPlayerName = ""
local myPlayerNameRaw = ""
local myAccountName = ""
local secondsSinceMidnight = 0
local FCOCS_OnChatEventOriginal
local origNewNotificationSound = SOUNDS["NEW_NOTIFICATION"]


--Blacklist skipped messageTypes
local skippedMessageTypesForBlacklist = {
    [CHAT_CHANNEL_SYSTEM] = true,
    [CHAT_CHANNEL_MONSTER_SAY] = true,
    [CHAT_CHANNEL_MONSTER_YELL] = true,
    [CHAT_CHANNEL_MONSTER_EMOTE] = true,
    [CHAT_CHANNEL_MONSTER_WHISPER] = true,
    [CHAT_CHANNEL_EMOTE] = true,
    [CHAT_CHANNEL_WHISPER_SENT] = true,
}

--Each time a chat message comes in this function will be called
local function FCOCS_ChatMessageChannel(messageType, fromNameFormatted, msgText)
--d("FCOCS_ChatMessageChannel: [" .. tostring(fromNameFormatted) .. "] " .. tostring(msgText))
    --Do not check for friend amd don't parse message text if a monster/NPC is speaking.
    local settings = FCOChangeStuff.settingsVars.settings
    local messageText = string.gsub(msgText, '([%[%]%%%(%)%{%}%$%^%+])', '[%%%1]')
    local keyWords = FCOChangeStuff.blacklistKeyWords or { zo_strsplit("\n", settings.chatKeyWords) }
    if keyWords == nil or #keyWords == 0 then return false end
    local textFound = false
    local keyWordFound = ""
    for _,keyWord in ipairs(keyWords) do
        local keyWordEscaped = string.gsub(keyWord, '([%[%]%%%(%)%{%}%$%^%+])', '[%%%1]')
        local lowerMsgEscaped = string.lower(messageText) or "noMsgText"
        local lowerKeywordEscaped = string.lower(keyWordEscaped) or "noKeyWord"
        if string.match(lowerMsgEscaped, lowerKeywordEscaped) then
            textFound = true
            keyWordFound = keyWord
            break -- end the for...loop...
        else
            local lowerMsg = string.lower(msgText) or "noMsgText"
            local lowerKeyword = string.lower(keyWord) or "noKeyWord"
            if lowerMsg ~= lowerMsgEscaped and lowerKeyword ~= lowerKeywordEscaped then
                if string.match(lowerMsg, lowerKeyword) then
                    textFound = true
                    keyWordFound = keyWord
                    break -- end the for...loop...
                end
            end
        end
    end
    --Text was found, hide the chat text now
    if textFound then
        --Show chat output for blacklisted text?
        if settings.blacklistedTextToChat then
            local chatChannelTexts = {
                [CHAT_CHANNEL_GUILD_1] = "Guild 1",
                [CHAT_CHANNEL_GUILD_2] = "Guild 2",
                [CHAT_CHANNEL_GUILD_3] = "Guild 3",
                [CHAT_CHANNEL_GUILD_4] = "Guild 4",
                [CHAT_CHANNEL_GUILD_5] = "Guild 5",
                [CHAT_CHANNEL_OFFICER_1] = "Officer 1",
                [CHAT_CHANNEL_OFFICER_2] = "Officer 2",
                [CHAT_CHANNEL_OFFICER_3] = "Officer 3",
                [CHAT_CHANNEL_OFFICER_4] = "Officer 4",
                [CHAT_CHANNEL_OFFICER_5] = "Officer 5",
                [CHAT_CHANNEL_PARTY] = "Group",
                [CHAT_CHANNEL_SAY] = "Say",
                [CHAT_CHANNEL_USER_CHANNEL_1] = "User channel 1",
                [CHAT_CHANNEL_USER_CHANNEL_2] = "User channel 2",
                [CHAT_CHANNEL_USER_CHANNEL_3] = "User channel 3",
                [CHAT_CHANNEL_USER_CHANNEL_4] = "User channel 4",
                [CHAT_CHANNEL_USER_CHANNEL_5] = "User channel 5",
                [CHAT_CHANNEL_USER_CHANNEL_6] = "User channel 6",
                [CHAT_CHANNEL_USER_CHANNEL_7] = "User channel 7",
                [CHAT_CHANNEL_USER_CHANNEL_8] = "User channel 8",
                [CHAT_CHANNEL_USER_CHANNEL_9] = "User channel 9",
                [CHAT_CHANNEL_WHISPER] = "Whisper",
                [CHAT_CHANNEL_YELL] = "Yell",
                [CHAT_CHANNEL_ZONE] = "Zone",
                [CHAT_CHANNEL_ZONE_LANGUAGE_1] = "ZoneEN",
                [CHAT_CHANNEL_ZONE_LANGUAGE_2] = "ZoneFR",
                [CHAT_CHANNEL_ZONE_LANGUAGE_3] = "ZoneDE",
                [CHAT_CHANNEL_ZONE_LANGUAGE_4] = "ZoneJP",
            }
            local chatChannelText = chatChannelTexts[messageType] or "<unknown>"
            local isENClient = (GetCVar("Language.2") == "en") or false
            local lCLOCK_FORMAT = (isENClient and TIME_FORMAT_PRECISION_TWELVE_HOUR) or TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR
            local lTIME_FORMAT = (isENClient and TIME_FORMAT_STYLE_CLOCK_TIME) or TIME_FORMAT_STYLE_COLONS
            local postingTime = ZO_FormatTime(secondsSinceMidnight, lTIME_FORMAT, lCLOCK_FORMAT)
            d(zo_strformat("<<1>>: [FCOCS]Blacklisted \"<<2>>\" in message \"<<3>>\", posted by \"<<4>>\" in channel \"<<5>>\"", postingTime, keyWordFound, msgText, fromNameFormatted, chatChannelText))
        end
--d("<<<return FOUND=true")
        --Abort the output of the chat message
        return true
    end
    --Show the text message
    return false
end

--The blacklist method
--messageType, fromName, text, isFromCustomerService, fromDisplayName
local function FCOCS_FilterChatMessage(messageType, fromName, chatText, isFromCustomerService, fromDisplayName)
--d("[FCOChangeStuff]FilterChatMessage")
    --Format message poster
    local postingPerson   = zo_strformat(SI_UNIT_NAME, fromName)
--d("MyPlayerName: " .. myPlayerName .. " (" .. myPlayerNameRaw .. "), MyAccountName: " .. myAccountName .. " / fromName: " .. postingPerson .. " (" .. fromName .. ")")
    --Is the chat message sent by myself? Abort then
    if fromName == myAccountName or postingPerson == myAccountName or fromName == myPlayerNameRaw or postingPerson == myPlayerName then
        return false
    end
--d(">not from myself")
    local settings = FCOChangeStuff.settingsVars.settings
    --Chat blacklist is enabled for whispers?
    if not settings.enableChatBlacklistForWhispers and messageType == CHAT_CHANNEL_WHISPER then return false end
    --Chat blacklist is enabled for group?
    if not settings.enableChatBlacklistForGroup and messageType == CHAT_CHANNEL_PARTY then return false end
    --Chat blacklist is enabled for guilds?
    if not settings.enableChatBlacklistForGuilds and (
           messageType == CHAT_CHANNEL_GUILD_1
        or messageType == CHAT_CHANNEL_GUILD_2
        or messageType == CHAT_CHANNEL_GUILD_3
        or messageType == CHAT_CHANNEL_GUILD_4
        or messageType == CHAT_CHANNEL_GUILD_5
        or messageType == CHAT_CHANNEL_OFFICER_1
        or messageType == CHAT_CHANNEL_OFFICER_2
        or messageType == CHAT_CHANNEL_OFFICER_3
        or messageType == CHAT_CHANNEL_OFFICER_4
        or messageType == CHAT_CHANNEL_OFFICER_5
    ) then
        return false
    end
--d(">>got here, settings ok")
    --Filter the chta messages now
    local blacklistChatmessage = FCOCS_ChatMessageChannel(messageType, postingPerson, chatText) or false
    return blacklistChatmessage
end

--The chat message event method
local function FCOCS_OnChatMessageChannel(messageType, fromName, text, isFromCustomerService, fromDisplayName)
    --d("[FCOChangeStuff]OnChatMessageChannel-messageType: " ..tostring(messageType) .. ", fromName: " ..tostring(fromName) .. ", fromDisplayName: " .. tostring(fromDisplayName).. ", isFromCustomerService: " ..tostring(isFromCustomerService) .. ", text: " ..tostring(text))
    --Do not filter chat messages from NPCs/Monsters/Outgoing whispers etc.
    local skippedMessageType = messageType ~= nil and skippedMessageTypesForBlacklist[messageType] or false
    if skippedMessageType then return false end
--d(">>chat channel is allowed")

    --Setting enabled?
    secondsSinceMidnight = 0
    local settings = FCOChangeStuff.settingsVars.settings
    if settings.enableChatBlacklist == true and settings.chatKeyWords ~= nil and settings.chatKeyWords ~= "" then
--d("[FCOCS]FCOCS_OnChaMessageChannel - With Blacklist")
        if settings.blacklistedTextToChat == true then
            --Get the current time
            secondsSinceMidnight = GetSecondsSinceMidnight()
        end
        --Filter the incoming chat message now
        --FCOCS_FilterChatMessage(eventType, messageType, fromName, chatText, isFromCustomerService, fromDisplayName)
        local chatMessageWasBlacklisted = FCOCS_FilterChatMessage(messageType, fromName, text, isFromCustomerService, fromDisplayName) or false
--d(">chatMessageWasBlacklisted: " ..tostring(chatMessageWasBlacklisted))
        if chatMessageWasBlacklisted == true then
            --Abort the chat event function so no text is shown in the chat
            return true
        end
    end
    --Go on after the PreHook to show the chat messages in chat
    return false
end

--Enable the chat blacklist event
local chatBlacklistHookDone = false

function FCOChangeStuff.chatBlacklist()
--d("[FCOChangeStuff]chatBlacklist")
    local settings = FCOChangeStuff.settingsVars.settings
    if not settings.enableChatBlacklist then return false end
    --Was the chat hook already done once?
    if not chatBlacklistHookDone then
        --Set some addon wide varibales which do not change
        myPlayerName    = GetUnitName("player")
        myPlayerNameRaw = GetRawUnitName("player")
        myAccountName   = GetDisplayName()
--[[
        --If pChat addon is enabled then PreHook it's FormatMessage function to respect pChat's anti-spam and chat history etc. as well!
        if pChat ~= nil and pChat.MessageChannelReceiver then
d(">pChat was found! Registering hook to pChat.MessageChannelReceiver")
            ZO_PreHook(pChat, "MessageChannelReceiver", function(...)
d("[FCOChangeStuff]pChat.MessageChannelReceiver PreHook")
                --pChat.FormatMessage(chanCode, from, text, isCS, fromDisplayName, ...)
                return FCOCS_OnChatMessageChannel(...)
            end)
        else
d(">Registering hook to CHAT_ROUTER->EVENT_CHAT_MESSAGE_CHANNEL")
            local ZO_EventHandlers = CHAT_ROUTER:GetRegisteredMessageFormatters()
            if ZO_EventHandlers then
                ZO_PreHook(ZO_EventHandlers, EVENT_CHAT_MESSAGE_CHANNEL, function(...)
                    return FCOCS_OnChatMessageChannel(...)
                end)
            end
        end
]]
        --Use CHAT_ROUTER function which uses the registered chat mesasge formatters to check if a mesage should be stripped and not shown!
        --ZO_ChatRouter:FormatAndAddChatMessage(eventKey, ...)
--d(">Registering hook to CHAT_ROUTER->FormatAndAddChatMessage")
        ZO_PreHook(CHAT_ROUTER, "FormatAndAddChatMessage", function(self, eventName, ...)
--d("[FCOChangeStuff]PreHook CHAT_ROUTER:FormatAndAddChatMessage, eventName: " ..tostring(eventName))
--FCOChangeStuff._FormatAndAddChatMessageParams = {...}
            if not eventName or (eventName and eventName ~= EVENT_CHAT_MESSAGE_CHANNEL) then return false end
            return FCOCS_OnChatMessageChannel(...)
        end)
        chatBlacklistHookDone = true
    end
end

--Do the chat whisper and CSA check
local function chatWhisperCheck()
    --* GetPlayerStatus()
    --** _Returns:_ *[PlayerStatus|#PlayerStatus]* _status_
    --* PLAYER_STATUS_AWAY
    --* PLAYER_STATUS_DO_NOT_DISTURB
    --* PLAYER_STATUS_OFFLINE
    --* PLAYER_STATUS_ONLINE
    local playerStatus = GetPlayerStatus()
--d("[FCOCS]chatWhisperCheck-playerStatus: " ..tostring(playerStatus))
    if playerStatus ~= PLAYER_STATUS_OFFLINE then return end
    --Player is flagged as offline
    local alertTextWhisperButFlagegdOffline = "--- YOUR STATUS IS: \'OFFLINE\'! NO INCOMING WHISPERs POSSIBLE! ---"
    --if alertTextWhisperButFlagegdOffline ~= "" then
        --Show CSA mesage now on screen
        local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE)
        params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_DISPLAY_ANNOUNCEMENT )
        params:SetText(alertTextWhisperButFlagegdOffline)
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
    --end
end

--Enable the reminder for "offline" whispers
local chatWhisperAsOfflineHookDone = false
function FCOChangeStuff.chatWhisperAndFlaggedAsOffline()
    --Register the event for the chat
    if chatWhisperAsOfflineHookDone then return end
    ZO_PreHook(CHAT_SYSTEM, "StartTextEntry", function(ctrl, text, channel, target, showVirtualKeyboard)
        local settings = FCOChangeStuff.settingsVars.settings
        if not settings.enableChatWhisperAndFlaggedAsOfflineReminder then return false end
        --Is the channel not provided?
        local currentChannel = 0
        if channel == nil then
            --Get the current chat channel
            if CHAT_SYSTEM and CHAT_SYSTEM.currentChannel then
                currentChannel = CHAT_SYSTEM.currentChannel
            end
        end
        --d("[FCOCS]StartTextEntry, text: " ..tostring(text) .. ", channel: " ..tostring(channel) .. ", currentChannel: " ..tostring(currentChannel))
        --If we are whispering
        if channel == CHAT_CHANNEL_WHISPER or currentChannel == CHAT_CHANNEL_WHISPER then
            chatWhisperCheck()
        end
        return false
    end)
    chatWhisperAsOfflineHookDone = true
end


--Disable the chat's notification animation and sound
function FCOChangeStuff.chatDisableNotificationAnimation()
    local settings = FCOChangeStuff.settingsVars.settings
    if settings.disableChatNotificationAnimation then
        CHAT_SYSTEM.notificationPulseTimeline:Stop()
        ZO_ChatWindowNotificationsEcho:SetHidden(true)
    else
        ZO_ChatWindowNotificationsEcho:SetHidden(false)
        if CHAT_SYSTEM.currentNumNotifications and CHAT_SYSTEM.currentNumNotifications > 0 then
            CHAT_SYSTEM.notificationPulseTimeline:PlayFromStart()
        end
    end
end

--Disable the chat's notification animation and sound
function FCOChangeStuff.chatDisableNotificationSound()
    local settings = FCOChangeStuff.settingsVars.settings
    if settings.disableChatNotificationSound then
        SOUNDS["NEW_NOTIFICATION"] = SOUNDS["NONE"]
    else
        SOUNDS["NEW_NOTIFICATION"] = origNewNotificationSound
    end
end

--Disable the chat's notification animation and sound
function FCOChangeStuff.chatDisableNotificationStuff()
    FCOChangeStuff.chatDisableNotificationAnimation()
    FCOChangeStuff.chatDisableNotificationSound()
end
