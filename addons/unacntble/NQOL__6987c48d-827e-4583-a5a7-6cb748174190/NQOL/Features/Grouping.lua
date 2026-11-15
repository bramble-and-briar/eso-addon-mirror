NQOL = NQOL or {}
NQOL.Features = NQOL.Features or {}

local GroupingFeature = {}

local AUTO_INVITE_OFF = 0
local AUTO_INVITE_DMS_ONLY = 1
local AUTO_INVITE_ZONE_ONLY = 2
local AUTO_INVITE_DMS_AND_ZONE = 3
local AUTO_INVITE_GROUP_SIZE_MIN = 2
local AUTO_INVITE_GROUP_SIZE_MAX = 12
local AUTO_INVITE_GROUP_SIZE_DEFAULT = 12
local AUTO_INVITE_DELAY_MINUTES_MIN = 0
local AUTO_INVITE_DELAY_MINUTES_MAX = 60
local AUTO_INVITE_DECLINED_DELAY_MINUTES_DEFAULT = 60
local AUTO_INVITE_REINVITE_DELAY_MINUTES_DEFAULT = 15
local MINUTES_TO_MS = 60000
local AUTO_INVITE_RESPONSE_WINDOW_MS = 5 * MINUTES_TO_MS
local EVENT_NAMESPACE = "NQOL_Grouping"

local AUTO_INVITE_CHOICES = {
    AUTO_INVITE_OFF,
    AUTO_INVITE_DMS_ONLY,
    AUTO_INVITE_ZONE_ONLY,
    AUTO_INVITE_DMS_AND_ZONE,
}

local AUTO_INVITE_CHOICE_NAMES = NQOL.Lexicon.LocalizedList({
    "features.grouping.mode_off",
    "features.grouping.mode_dms",
    "features.grouping.mode_zone",
    "features.grouping.mode_dms_zone",
})

local VALID_AUTO_INVITE_MODES = {
    [AUTO_INVITE_OFF] = true,
    [AUTO_INVITE_DMS_ONLY] = true,
    [AUTO_INVITE_ZONE_ONLY] = true,
    [AUTO_INVITE_DMS_AND_ZONE] = true,
}

local defaults = {
    grouping = {
        autoInvite = {
            mode = AUTO_INVITE_OFF,
            triggerText = "",
            groupSize = AUTO_INVITE_GROUP_SIZE_DEFAULT,
            declinedDelayMinutes = AUTO_INVITE_DECLINED_DELAY_MINUTES_DEFAULT,
            reinviteDelayMinutes = AUTO_INVITE_REINVITE_DELAY_MINUTES_DEFAULT,
            logInChat = false,
        },
    },
}

local savedVariables
local initialized = false
local inviteResponseEventRegistered = false
local autoInvitePendingNames = {}
local autoInvitePendingTimes = {}
local autoInviteLastInviteTimes = {}
local autoInviteDeclinedTimes = {}
local RefreshInviteResponseEvent

local StripChatMarkup = NQOL.Util.StripChatMarkup

local function TrimText(value)
    return string.match(value, "^%s*(.-)%s*$") or ""
end

local function GetAutoInviteTriggerTexts(triggerText)
    local triggerTexts = {}

    if type(triggerText) ~= "string" then
        return triggerTexts
    end

    for entry in string.gmatch(triggerText, "([^,]+)") do
        local trimmedEntry = TrimText(entry)

        if trimmedEntry ~= "" then
            table.insert(triggerTexts, trimmedEntry)
        end
    end

    return triggerTexts
end

local function NormalizeAutoInviteTriggerText(triggerText)
    return table.concat(GetAutoInviteTriggerTexts(triggerText), ", ")
end

local function ClampDelayMinutes(value, defaultValue)
    value = tonumber(value)

    if value == nil then
        return defaultValue
    end

    value = zo_round and zo_round(value) or math.floor(value + 0.5)

    if value < AUTO_INVITE_DELAY_MINUTES_MIN then
        return AUTO_INVITE_DELAY_MINUTES_MIN
    elseif value > AUTO_INVITE_DELAY_MINUTES_MAX then
        return AUTO_INVITE_DELAY_MINUTES_MAX
    end

    return value
end

local function ClampGroupSize(value)
    value = tonumber(value)
    if value == nil then
        return AUTO_INVITE_GROUP_SIZE_DEFAULT
    end

    value = zo_round and zo_round(value) or math.floor(value + 0.5)
    return math.max(AUTO_INVITE_GROUP_SIZE_MIN, math.min(AUTO_INVITE_GROUP_SIZE_MAX, value))
end

local function IsAutoInviteTriggerText(rawText, triggerText)
    if type(rawText) ~= "string" then
        return false
    end

    local comparableRawText = NQOL.Util.Lower(rawText)

    for _, entry in ipairs(GetAutoInviteTriggerTexts(triggerText)) do
        if comparableRawText == NQOL.Util.Lower(entry) then
            return true
        end
    end

    return false
end

local function GetSettings()
    if not savedVariables then
        return defaults.grouping.autoInvite
    end

    local settings = NQOL.Settings.EnsurePath(savedVariables, { "grouping", "autoInvite" })
    local defaultSettings = defaults.grouping.autoInvite

    if not VALID_AUTO_INVITE_MODES[settings.mode] then
        settings.mode = defaultSettings.mode
    end

    if type(settings.triggerText) ~= "string" then
        settings.triggerText = defaultSettings.triggerText
    else
        settings.triggerText = NormalizeAutoInviteTriggerText(settings.triggerText)
    end

    settings.groupSize = ClampGroupSize(settings.groupSize)

    settings.declinedDelayMinutes = ClampDelayMinutes(settings.declinedDelayMinutes, defaultSettings.declinedDelayMinutes)
    settings.reinviteDelayMinutes = ClampDelayMinutes(settings.reinviteDelayMinutes, defaultSettings.reinviteDelayMinutes)

    settings.ignoreCase = nil

    if type(settings.logInChat) ~= "boolean" then
        settings.logInChat = defaultSettings.logInChat
    end

    return settings
end

local function IsZoneChannel(messageType)
    return messageType == CHAT_CHANNEL_ZONE
        or (CHAT_CHANNEL_ZONE_LANGUAGE_1 and messageType == CHAT_CHANNEL_ZONE_LANGUAGE_1)
        or (CHAT_CHANNEL_ZONE_LANGUAGE_2 and messageType == CHAT_CHANNEL_ZONE_LANGUAGE_2)
        or (CHAT_CHANNEL_ZONE_LANGUAGE_3 and messageType == CHAT_CHANNEL_ZONE_LANGUAGE_3)
        or (CHAT_CHANNEL_ZONE_LANGUAGE_4 and messageType == CHAT_CHANNEL_ZONE_LANGUAGE_4)
        or (CHAT_CHANNEL_ZONE_LANGUAGE_5 and messageType == CHAT_CHANNEL_ZONE_LANGUAGE_5)
        or (CHAT_CHANNEL_ZONE_LANGUAGE_6 and messageType == CHAT_CHANNEL_ZONE_LANGUAGE_6)
        or (CHAT_CHANNEL_ZONE_LANGUAGE_7 and messageType == CHAT_CHANNEL_ZONE_LANGUAGE_7)
end

local function ShouldWatchChannel(messageType, mode)
    if mode == AUTO_INVITE_DMS_ONLY then
        return messageType == CHAT_CHANNEL_WHISPER
    elseif mode == AUTO_INVITE_ZONE_ONLY then
        return IsZoneChannel(messageType)
    elseif mode == AUTO_INVITE_DMS_AND_ZONE then
        return messageType == CHAT_CHANNEL_WHISPER or IsZoneChannel(messageType)
    end

    return false
end

local function GetInviteTarget(fromName, fromDisplayName)
    local targetName = type(fromDisplayName) == "string" and fromDisplayName or ""

    if targetName == "" then
        targetName = type(fromName) == "string" and fromName or ""
    end

    return StripChatMarkup(targetName)
end

local function NormalizePlayerName(name)
    if type(name) ~= "string" then
        return ""
    end

    local normalizedName = StripChatMarkup(name)

    if zo_strformat then
        normalizedName = zo_strformat("<<1>>", normalizedName)
    end

    return NQOL.Util.Lower(normalizedName)
end

local function NamesMatch(leftName, rightName)
    return type(leftName) == "string"
        and type(rightName) == "string"
        and leftName ~= ""
        and rightName ~= ""
        and NormalizePlayerName(leftName) == NormalizePlayerName(rightName)
end

local function IsGroupedPlayer(targetName, fromName, fromDisplayName)
    if not GetGroupSize or not GetGroupUnitTagByIndex then
        return false
    end

    for index = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(index)

        if GetUnitDisplayName then
            local displayName = GetUnitDisplayName(unitTag)
            if NamesMatch(displayName, targetName) or NamesMatch(displayName, fromDisplayName) or NamesMatch(displayName, fromName) then
                return true
            end
        end

        if GetUnitName then
            local characterName = GetUnitName(unitTag)
            if NamesMatch(characterName, targetName) or NamesMatch(characterName, fromDisplayName) or NamesMatch(characterName, fromName) then
                return true
            end
        end
    end

    return false
end

local function HasReachedAutoInviteGroupSize(maxGroupSize)
    -- ESO reports zero when solo, but the player still occupies a group slot.
    local reservedSize = math.max(1, GetGroupSize and GetGroupSize() or 0)
    for _ in pairs(autoInvitePendingTimes) do reservedSize = reservedSize + 1 end
    return reservedSize >= maxGroupSize
end

local function GetNowMilliseconds()
    if GetFrameTimeMilliseconds then
        return GetFrameTimeMilliseconds()
    end

    if GetTimeStamp then
        return GetTimeStamp() * 1000
    end

    return 0
end

local function IsDelayActive(lastTimeMs, delayMinutes)
    if not lastTimeMs or delayMinutes <= 0 then
        return false
    end

    return GetNowMilliseconds() - lastTimeMs < delayMinutes * MINUTES_TO_MS
end

local function PruneAutoInviteTimes(times, maxAgeMs, nowMs)
    if not times then
        return
    end

    maxAgeMs = tonumber(maxAgeMs) or 0
    if maxAgeMs <= 0 then
        for key in pairs(times) do
            times[key] = nil
        end
        return
    end

    nowMs = nowMs or GetNowMilliseconds()
    for key, lastTimeMs in pairs(times) do
        if not lastTimeMs or nowMs - lastTimeMs >= maxAgeMs then
            times[key] = nil
        end
    end
end

local function PruneAutoInvitePendingNames()
    for nameKey, inviteKey in pairs(autoInvitePendingNames) do
        if not autoInvitePendingTimes[inviteKey] then
            autoInvitePendingNames[nameKey] = nil
        end
    end
end

local function PruneAutoInviteState(settings)
    settings = settings or GetSettings()
    local nowMs = GetNowMilliseconds()
    local declinedDelay = settings.declinedDelayMinutes or AUTO_INVITE_DECLINED_DELAY_MINUTES_DEFAULT
    local reinviteDelay = settings.reinviteDelayMinutes or AUTO_INVITE_REINVITE_DELAY_MINUTES_DEFAULT

    PruneAutoInviteTimes(autoInvitePendingTimes, AUTO_INVITE_RESPONSE_WINDOW_MS, nowMs)
    PruneAutoInviteTimes(autoInviteLastInviteTimes, reinviteDelay * MINUTES_TO_MS, nowMs)
    PruneAutoInviteTimes(autoInviteDeclinedTimes, declinedDelay * MINUTES_TO_MS, nowMs)
    PruneAutoInvitePendingNames()
end

local function TrackAutoInvite(targetName, fromName, fromDisplayName)
    local nowMs = GetNowMilliseconds()
    local targetKey = NormalizePlayerName(targetName)

    if targetKey ~= "" then
        autoInvitePendingNames[targetKey] = targetKey
        autoInvitePendingTimes[targetKey] = nowMs
        autoInviteLastInviteTimes[targetKey] = nowMs
    end

    local fromKey = NormalizePlayerName(fromName)
    if fromKey ~= "" then
        autoInvitePendingNames[fromKey] = targetKey
        autoInvitePendingTimes[targetKey] = nowMs
    end

    local displayKey = NormalizePlayerName(fromDisplayName)
    if displayKey ~= "" then
        autoInvitePendingNames[displayKey] = targetKey
        autoInvitePendingTimes[targetKey] = nowMs
    end
end

local function ClearAutoInvitePending(inviteKey)
    for nameKey, pendingInviteKey in pairs(autoInvitePendingNames) do
        if pendingInviteKey == inviteKey then
            autoInvitePendingNames[nameKey] = nil
        end
    end

    autoInvitePendingTimes[inviteKey] = nil
end

local function GetAutoInviteDelayReason(targetName, fromName, fromDisplayName, settings)
    local targetKey = NormalizePlayerName(targetName)
    local fromKey = NormalizePlayerName(fromName)
    local displayKey = NormalizePlayerName(fromDisplayName)
    local declinedDelay = settings.declinedDelayMinutes or AUTO_INVITE_DECLINED_DELAY_MINUTES_DEFAULT
    local reinviteDelay = settings.reinviteDelayMinutes or AUTO_INVITE_REINVITE_DELAY_MINUTES_DEFAULT

    if autoInvitePendingNames[targetKey] or autoInvitePendingNames[fromKey] or autoInvitePendingNames[displayKey] then
        return "invited"
    end

    if IsDelayActive(autoInviteDeclinedTimes[targetKey], declinedDelay)
        or IsDelayActive(autoInviteDeclinedTimes[fromKey], declinedDelay)
        or IsDelayActive(autoInviteDeclinedTimes[displayKey], declinedDelay) then
        return "declined"
    end

    if IsDelayActive(autoInviteLastInviteTimes[targetKey], reinviteDelay)
        or IsDelayActive(autoInviteLastInviteTimes[fromKey], reinviteDelay)
        or IsDelayActive(autoInviteLastInviteTimes[displayKey], reinviteDelay) then
        return "invited"
    end

    return nil
end

local function ReconcileAutoInviteMembers()
    -- Retain accepted reservations until the member is actually in ESO's roster.
    -- This also handles membership arriving before the acceptance response.
    for nameKey, inviteKey in pairs(autoInvitePendingNames) do
        if IsGroupedPlayer(nameKey) then ClearAutoInvitePending(inviteKey) end
    end
end

local function OnGroupInviteResponse(_, characterName, response, displayName)
    PruneAutoInviteState()

    local characterKey = NormalizePlayerName(characterName)
    local displayKey = NormalizePlayerName(displayName)
    local inviteKey = autoInvitePendingNames[characterKey] or autoInvitePendingNames[displayKey]

    if not inviteKey then
        return
    end

    if not IsDelayActive(autoInvitePendingTimes[inviteKey], AUTO_INVITE_RESPONSE_WINDOW_MS / MINUTES_TO_MS) then
        ClearAutoInvitePending(inviteKey)
        return
    end

    if response == GROUP_INVITE_RESPONSE_INVITED then return end
    if response == GROUP_INVITE_RESPONSE_ACCEPTED then
        autoInvitePendingTimes[inviteKey] = GetNowMilliseconds()
        autoInviteLastInviteTimes[inviteKey] = nil
        autoInviteDeclinedTimes[inviteKey] = nil
        ReconcileAutoInviteMembers()
    else
        -- Declines and terminal invitation errors both free the reserved slot.
        ClearAutoInvitePending(inviteKey)
        autoInviteLastInviteTimes[inviteKey] = nil
        if response == GROUP_INVITE_RESPONSE_DECLINED then
            autoInviteDeclinedTimes[inviteKey] = GetNowMilliseconds()
        end
    end
    RefreshInviteResponseEvent()
end

local function RegisterInviteResponseEvent()
    if inviteResponseEventRegistered or not EVENT_MANAGER or not EVENT_GROUP_INVITE_RESPONSE then
        return
    end

    inviteResponseEventRegistered = true
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_InviteResponse", EVENT_GROUP_INVITE_RESPONSE, OnGroupInviteResponse)
    if EVENT_GROUP_MEMBER_JOINED then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_InviteMembers", EVENT_GROUP_MEMBER_JOINED, ReconcileAutoInviteMembers)
    end
    if EVENT_GROUP_UPDATE then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_InviteMembers", EVENT_GROUP_UPDATE, ReconcileAutoInviteMembers)
    end
end

local function UnregisterInviteResponseEvent()
    if not inviteResponseEventRegistered or not EVENT_MANAGER or not EVENT_GROUP_INVITE_RESPONSE then
        return
    end

    inviteResponseEventRegistered = false
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_InviteResponse", EVENT_GROUP_INVITE_RESPONSE)
    if EVENT_GROUP_MEMBER_JOINED then
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_InviteMembers", EVENT_GROUP_MEMBER_JOINED)
    end
    if EVENT_GROUP_UPDATE then
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_InviteMembers", EVENT_GROUP_UPDATE)
    end
end

RefreshInviteResponseEvent = function()
    local settings = GetSettings()
    if (settings.mode ~= AUTO_INVITE_OFF and settings.triggerText ~= "") or next(autoInvitePendingTimes) ~= nil then
        RegisterInviteResponseEvent()
    else
        UnregisterInviteResponseEvent()
    end
end

function GroupingFeature.InitializeSavedVariables()
    savedVariables = NQOL.Settings.NewAccountWide(defaults, "$InstallationWide")
    GetSettings()
end

function GroupingFeature.Initialize()
    if initialized then
        return
    end

    initialized = true
    RefreshInviteResponseEvent()
end

function GroupingFeature.HandleChatMessage(messageType, fromName, rawText, fromDisplayName)
    local settings = GetSettings()
    local triggerText = settings.triggerText

    PruneAutoInviteState(settings)
    ReconcileAutoInviteMembers()

    if settings.mode == AUTO_INVITE_OFF or triggerText == "" then
        return
    end

    if not ShouldWatchChannel(messageType, settings.mode) then
        return
    end

    if not IsAutoInviteTriggerText(rawText, triggerText) then
        return
    end

    if NQOL.Features.Chat and NQOL.Features.Chat.IsOwnChatMessage and NQOL.Features.Chat.IsOwnChatMessage(fromName, fromDisplayName) then
        return
    end

    local targetName = GetInviteTarget(fromName, fromDisplayName)
    if targetName == "" then
        return
    end

    if IsGroupedPlayer(targetName, fromName, fromDisplayName) then
        return
    end

    if GetAutoInviteDelayReason(targetName, fromName, fromDisplayName, settings) then
        return
    end

    if HasReachedAutoInviteGroupSize(settings.groupSize) then
        return
    end

    if not GroupInviteByName then
        return
    end

    -- Reserve first: a synchronous failure/response must see this invitation.
    TrackAutoInvite(targetName, fromName, fromDisplayName)
    local ok, failure = pcall(GroupInviteByName, targetName)
    if not ok then
        local targetKey = NormalizePlayerName(targetName)
        ClearAutoInvitePending(targetKey)
        autoInviteLastInviteTimes[targetKey] = nil
        error(failure)
    end

    if settings.logInChat then
        NQOL.Chat.Message(NQOL.L("features.grouping.invited_after_request", targetName), NQOL.L("features.grouping.feature_name"))
    end
end

function GroupingFeature.GetAutoInviteMode()
    return GetSettings().mode
end

function GroupingFeature.SetAutoInviteMode(value)
    if not VALID_AUTO_INVITE_MODES[value] then
        value = defaults.grouping.autoInvite.mode
    end

    GetSettings().mode = value
    RefreshInviteResponseEvent()
end

function GroupingFeature.GetAutoInviteTriggerText()
    return GetSettings().triggerText
end

function GroupingFeature.SetAutoInviteTriggerText(value)
    GetSettings().triggerText = NormalizeAutoInviteTriggerText(value)
    RefreshInviteResponseEvent()
end

function GroupingFeature.GetAutoInviteGroupSize()
    return GetSettings().groupSize
end

function GroupingFeature.SetAutoInviteGroupSize(value)
    GetSettings().groupSize = ClampGroupSize(value)
end

function GroupingFeature.GetAutoInviteDeclinedDelayMinutes()
    return GetSettings().declinedDelayMinutes
end

function GroupingFeature.SetAutoInviteDeclinedDelayMinutes(value)
    GetSettings().declinedDelayMinutes = ClampDelayMinutes(value, defaults.grouping.autoInvite.declinedDelayMinutes)
end

function GroupingFeature.GetAutoInviteReinviteDelayMinutes()
    return GetSettings().reinviteDelayMinutes
end

function GroupingFeature.SetAutoInviteReinviteDelayMinutes(value)
    GetSettings().reinviteDelayMinutes = ClampDelayMinutes(value, defaults.grouping.autoInvite.reinviteDelayMinutes)
end

function GroupingFeature.GetAutoInviteLogInChat()
    return GetSettings().logInChat
end

function GroupingFeature.SetAutoInviteLogInChat(value)
    GetSettings().logInChat = value == true
end

function GroupingFeature.GetAutoInviteModeChoices()
    return AUTO_INVITE_CHOICES
end

function GroupingFeature.GetAutoInviteModeChoiceNames()
    return AUTO_INVITE_CHOICE_NAMES
end

function GroupingFeature.GetAutoInviteModeName()
    local mode = GroupingFeature.GetAutoInviteMode()
    for index, value in ipairs(AUTO_INVITE_CHOICES) do
        if value == mode then
            return AUTO_INVITE_CHOICE_NAMES[index]
        end
    end

    return AUTO_INVITE_CHOICE_NAMES[1]
end

function GroupingFeature.GetAutoInviteGroupSizeMin()
    return AUTO_INVITE_GROUP_SIZE_MIN
end

function GroupingFeature.GetAutoInviteGroupSizeMax()
    return AUTO_INVITE_GROUP_SIZE_MAX
end

function GroupingFeature.GetAutoInviteModeLabel()
    return NQOL.L("features.grouping.auto_invite_mode_label")
end

function GroupingFeature.GetAutoInviteModeTooltip()
    return NQOL.L("features.grouping.auto_invite_mode_tooltip")
end

function GroupingFeature.GetAutoInviteGroupSizeLabel()
    return NQOL.L("features.grouping.auto_invite_group_size_label")
end

function GroupingFeature.GetAutoInviteGroupSizeTooltip()
    return NQOL.L("features.grouping.auto_invite_group_size_tooltip")
end

function GroupingFeature.GetAutoInviteDeclinedDelayLabel()
    return NQOL.L("features.grouping.auto_invite_declined_delay_label")
end

function GroupingFeature.GetAutoInviteDeclinedDelayTooltip()
    return NQOL.L("features.grouping.auto_invite_declined_delay_tooltip")
end

function GroupingFeature.GetAutoInviteReinviteDelayLabel()
    return NQOL.L("features.grouping.auto_invite_reinvite_delay_label")
end

function GroupingFeature.GetAutoInviteReinviteDelayTooltip()
    return NQOL.L("features.grouping.auto_invite_reinvite_delay_tooltip")
end

function GroupingFeature.GetAutoInviteLogInChatLabel()
    return NQOL.L("features.grouping.auto_invite_log_in_chat_label")
end

function GroupingFeature.GetAutoInviteLogInChatTooltip()
    return NQOL.L("features.grouping.auto_invite_log_in_chat_tooltip")
end

function GroupingFeature.GetAutoInviteDelayText(delayMinutes)
    delayMinutes = ClampDelayMinutes(delayMinutes, 0)

    if delayMinutes == 0 then
        return NQOL.L("features.grouping.delay_off")
    elseif delayMinutes == 1 then
        return NQOL.L("features.grouping.delay_one")
    end

    return NQOL.L("features.grouping.delay_many", delayMinutes)
end

function GroupingFeature.GetAutoInviteDeclinedDelayText()
    return GroupingFeature.GetAutoInviteDelayText(GroupingFeature.GetAutoInviteDeclinedDelayMinutes())
end

function GroupingFeature.GetAutoInviteReinviteDelayText()
    return GroupingFeature.GetAutoInviteDelayText(GroupingFeature.GetAutoInviteReinviteDelayMinutes())
end

function GroupingFeature.GetAutoInviteDelayMin()
    return AUTO_INVITE_DELAY_MINUTES_MIN
end

function GroupingFeature.GetAutoInviteDelayMax()
    return AUTO_INVITE_DELAY_MINUTES_MAX
end

function GroupingFeature.GetAutoInviteDeclinedDelayDefault()
    return defaults.grouping.autoInvite.declinedDelayMinutes
end

function GroupingFeature.GetAutoInviteReinviteDelayDefault()
    return defaults.grouping.autoInvite.reinviteDelayMinutes
end

function GroupingFeature.GetAutoInviteLogInChatDefault()
    return defaults.grouping.autoInvite.logInChat
end

function GroupingFeature.GetAutoInviteTriggerTextLabel()
    local triggerText = GroupingFeature.GetAutoInviteTriggerText()
    if triggerText == "" then
        triggerText = NQOL.L("common.not_set")
    end

    return NQOL.L("features.grouping.trigger_text", triggerText)
end

function GroupingFeature.GetAutoInviteTriggerTextTooltip()
    return NQOL.L("features.grouping.auto_invite_trigger_text_tooltip")
end

NQOL.Features.Grouping = GroupingFeature
