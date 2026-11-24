-- Cyrodiil Queue Status
-- Draggable Cyrodiil queue status, position / movement timer, ready and break alerts,
-- optional auto-accept, and a LibAddonMenu settings panel.
-- Requires LibAddonMenu-2.0 revision 43 or newer for the settings panel.
--
-- When ESO reports DESTINATION_WORLD_FULL during a Cyrodiil queue, the client
-- may retain a stale queue entry. Treat this as a permanent break for the current
-- game session: only a genuine relog can clear the warning, never queue progress
-- or /reloadui. The status panel is hidden while inside Cyrodiil.

local ADDON_NAME = "CyroQueueStatus"
local STATUS_REFRESH_MS = 1000
local AUTO_ACCEPT_DELAY_MS = 150
local ALERT_DURATION_MS = 8500
local REQUEUE_CONFIRM_TIMEOUT_SECONDS = 20
local PANEL_WIDTH = 328
local PANEL_INNER_WIDTH = PANEL_WIDTH - 16

local defaults = {
    x = 200,
    y = 220,
    broken = false,
    brokenCampaignId = 0,
    brokenIsGroup = false,
    -- Set when ESO actually starts logging the character out.
    requeueLogoutRequested = false,
    -- Remember the previous campaign for a one-time queue request after relog.
    requeueCampaignId = 0,
    requeueIsGroup = false,
    requeueCharacterId = "",
    requeuePending = false,
    -- Monitor an automatic requeue until ESO confirms a waiting/ready queue.
    -- Persist the watch so /reloadui does not silently lose the failure warning.
    requeueWatchCampaignId = 0,
    requeueWatchIsGroup = false,
    requeueWatchStartedAt = 0,

    -- Preserve the elapsed movement timer across /reloadui on this character.
    trackedCampaignId = 0,
    trackedIsGroup = false,
    lastQueuePosition = 0,
    lastMoveTimestamp = 0,

    -- Display settings (stored per character with the existing saved variables).
    showPanel = true,
    showPosition = true,
    showTimer = true,
    autoAccept = true,
    autoRequeue = true,
    visualAlerts = true,
    audioAlerts = true,
    readySound = "COUNTDOWN_WARNING",
    brokenSound = "GENERAL_ALERT_ERROR",
}

local saved
local window
local statusLabel
local detailsLabel
local logoutButton
local alertWindow
local alertTitle
local alertMessage
local alertBackdrop
local settingsPanel
local isInitialized = false
local firstActivationHandled = false
local logoutMarkerAtLoad = false
local displayState = "NOT_IN_QUEUE"
local readyKey
local autoAcceptKey
local alertGeneration = 0

local colors = {
    IN_QUEUE = {0.40, 1.00, 0.55},
    QUEUE_BROKEN = {1.00, 0.38, 0.38},
    NOT_IN_QUEUE = {0.85, 0.85, 0.85},
}

-- Built-in sound choices. The list contains only sounds supported by this ESO client.
-- All sounds are built-in ESO UI sounds (no external files or libraries required).
local availableSoundOptions = {
    {'None', 'NONE'},
    {'Campaign Ready Check', 'CAMPAIGN_READY_CHECK'},
    {'Countdown Warning', 'COUNTDOWN_WARNING'},
    {'New Notification', 'NEW_NOTIFICATION'},
    {'General Alert Error', 'GENERAL_ALERT_ERROR'},
    {'Quest Completed', 'QUEST_COMPLETED'},
    {'Message Broadcast', 'MESSAGE_BROADCAST'},
    {'Ultimate Ready', 'ABILITY_ULTIMATE_READY'},
    {'Alert: Achievement Awarded', 'ACHIEVEMENT_AWARDED'},
    {'Alert: Display Announcement', 'DISPLAY_ANNOUNCEMENT'},
    {'Alert: New Mail', 'NEW_MAIL'},
    {'Alert: Medal Awarded', 'MEDAL_AWARDED'},
    {'Alert: Level Up', 'LEVEL_UP'},
    {'Alert: Rank Up', 'RANK_UP'},
    {'Alert: Skyshard Gained', 'SKYSHARD_GAINED'},
    {'Alert: Scripted Event Completion', 'SCRIPTED_EVENT_COMPLETION'},
    {'Alert: Book Collection Completed', 'BOOK_COLLECTION_COMPLETED'},
    {'Alert: LFG Search Finished', 'LFG_SEARCH_FINISHED'},
    {'Alert: LFG Search Started', 'LFG_SEARCH_STARTED'},
    {'Alert: Quest Step Failed', 'QUEST_STEP_FAILED'},
    {'Alert: Objective Completed', 'OBJECTIVE_COMPLETED'},
    {'Alert: Objective Discovered', 'OBJECTIVE_DISCOVERED'},
    {'PvP: Campaign Queue Accepted', 'CAMPAIGN_QUEUE_ACCEPTED'},
    {'PvP: Campaign Queue Declined', 'CAMPAIGN_QUEUE_DECLINED'},
    {'PvP: Keep Captured', 'AVA_KEEP_CAPTURED'},
    {'PvP: Gate Opened', 'AVA_GATE_OPENED'},
    {'PvP: Gate Closed', 'AVA_GATE_CLOSED'},
    {'PvP: Guild Keep Claimed', 'GUILD_KEEP_CLAIMED'},
    {'PvP: Guild Keep Lost', 'GUILD_KEEP_LOST'},
    {'PvP: Elder Scroll Captured (AD)', 'ELDER_SCROLL_CAPTURED_BY_ALDMERI'},
    {'PvP: Elder Scroll Captured (DC)', 'ELDER_SCROLL_CAPTURED_BY_DAGGERFALL'},
    {'PvP: Elder Scroll Captured (EP)', 'ELDER_SCROLL_CAPTURED_BY_EBONHEART'},
    {'PvP: Emperor Coronated (AD)', 'EMPEROR_CORONATED_ALDMERI'},
    {'Combat: Ability Ready', 'ABILITY_READY'},
    {'Combat: Ability Failed', 'ABILITY_FAILED'},
    {'Combat: Synergy Ready', 'ABILITY_SYNERGY_READY'},
    {'Combat: Target Out of Range', 'ABILITY_TARGET_OUT_OF_RANGE'},
    {'Combat: Active Tip Shown', 'ACTIVE_COMBAT_TIP_SHOWN'},
    {'Combat: Active Tip Success', 'ACTIVE_COMBAT_TIP_SUCCESS'},
    {'Combat: Active Tip Failure', 'ACTIVE_COMBAT_TIP_FAILS'},
    {'Combat: Overland Boss Kill', 'OVERLAND_BOSS_KILL'},
    {'Combat: Trial Started', 'RAID_TRIAL_STARTED'},
    {'Combat: Trial Completed', 'RAID_TRIAL_COMPLETED'},
    {'Combat: Trial Failed', 'RAID_TRIAL_FAILED'},
    {'Combat: Trial New Best', 'RAID_TRIAL_NEW_BEST'},
    {'Quest: Accepted', 'QUEST_ACCEPTED'},
    {'Quest: Objective Complete', 'QUEST_OBJECTIVE_COMPLETE'},
    {'Quest: Objective Increment', 'QUEST_OBJECTIVE_INCREMENT'},
    {'Quest: Shared', 'QUEST_SHARED'},
    {'Group: Invite', 'GROUP_INVITE'},
    {'Group: Join', 'GROUP_JOIN'},
    {'Group: Leave', 'GROUP_LEAVE'},
    {'Group: Disband', 'GROUP_DISBAND'},
    {'Skill: Gained', 'SKILL_GAINED'},
    {'Skill: Line Leveled Up', 'SKILL_LINE_LEVELED_UP'},
    {'Skill: Morph Available', 'ABILITY_MORPH_AVAILABLE'},
    {'UI: Dialog Accept', 'DIALOG_ACCEPT'},
    {'UI: Dialog Decline', 'DIALOG_DECLINE'},
    {'UI: Dialog Show', 'DIALOG_SHOW'},
    {'UI: Dialog Hide', 'DIALOG_HIDE'},
    {'UI: Positive Click', 'POSITIVE_CLICK'},
    {'UI: Negative Click', 'NEGATIVE_CLICK'},
    {'UI: Default Click', 'DEFAULT_CLICK'},
    {'UI: Menu Bar Click', 'MENU_BAR_CLICK'},
    {'UI: Window Open', 'DEFAULT_WINDOW_OPEN'},
    {'UI: Window Close', 'DEFAULT_WINDOW_CLOSE'},
    {'UI: Map Ping', 'MAP_PING'},
    {'UI: Map Location Clicked', 'MAP_LOCATION_CLICKED'},
    {'UI: Radial Menu Selection', 'RADIAL_MENU_SELECTION'},
    {'UI: Book Page Turn', 'BOOK_PAGE_TURN'},
    {'UI: Note Page Turn', 'NOTE_PAGE_TURN'},
    {'UI: Mail Sent', 'MAIL_SENT'},
    {'UI: Notifications Window Open', 'NOTIFICATIONS_WINDOW_OPEN'},
    {'Reward: Crafting Inspiration', 'CRAFTING_GAINED_INSPIRATION'},
    {'Reward: Recipe Learned', 'RECIPE_LEARNED'},
    {'Reward: Lockpick Success', 'LOCKPICKING_SUCCESS_CELEBRATION'},
    {'Reward: Lockpick Failed', 'LOCKPICKING_FAILED'},
    {'Reward: Alchemy Success', 'ALCHEMY_CREATE_TOOLTIP_GLOW_SUCCESS'},
    {'Reward: Blacksmith Success', 'BLACKSMITH_IMPROVE_TOOLTIP_GLOW_SUCCESS'},
    {'Reward: Blacksmith Failed', 'BLACKSMITH_IMPROVE_TOOLTIP_GLOW_FAIL'},
    {'Reward: Smithing Research Finished', 'SMITHING_FINISH_RESEARCH'},
}
local soundNames, soundValues = {}, {}
for _, entry in ipairs(availableSoundOptions) do
    local name, soundKey = entry[1], entry[2]
    if soundKey == "NONE" or (SOUNDS and SOUNDS[soundKey]) then
        soundNames[#soundNames + 1] = name
        soundValues[#soundValues + 1] = soundKey
    end
end

local function IsCyrodiilCampaign(campaignId)
    if not campaignId or campaignId == 0 then
        return false
    end
    local rulesetId = GetCampaignRulesetId(campaignId)
    return rulesetId and rulesetId ~= 0
        and GetCampaignRulesetType(rulesetId) == CAMPAIGN_RULESET_TYPE_CYRODIIL
end

local function FindCyrodiilQueue()
    for index = 1, GetNumCampaignQueueEntries() do
        local campaignId, isGroup = GetCampaignQueueEntry(index)
        if IsCyrodiilCampaign(campaignId) then
            return campaignId, isGroup == true
        end
    end
    return nil, nil
end

local function IsSameQueue(campaignIdA, isGroupA, campaignIdB, isGroupB)
    return campaignIdA == campaignIdB and isGroupA == isGroupB
end

local function QueueKey(campaignId, isGroup)
    return tostring(campaignId) .. (isGroup and ":group" or ":solo")
end

local function ClearBrokenFlag()
    saved.broken = false
    saved.brokenCampaignId = 0
    saved.brokenIsGroup = false
    saved.requeueLogoutRequested = false
end

local function ClearPositionTracking()
    saved.trackedCampaignId = 0
    saved.trackedIsGroup = false
    saved.lastQueuePosition = 0
    saved.lastMoveTimestamp = 0
end

-- Only a smaller numeric position counts as progress: 187 -> 180 resets timer.
-- The first known position is a baseline; the clock starts at queue join.
local function TrackQueuePosition(campaignId, isGroup, eventPosition, isFreshJoin)
    if not campaignId then
        return false
    end
    isGroup = isGroup == true
    if isFreshJoin or not IsSameQueue(campaignId, isGroup,
        saved.trackedCampaignId, saved.trackedIsGroup) then
        saved.trackedCampaignId = campaignId
        saved.trackedIsGroup = isGroup
        saved.lastQueuePosition = 0
        saved.lastMoveTimestamp = GetTimeStamp()
    end

    local position = eventPosition
    if type(position) ~= "number" or position < 1 then
        position = GetCampaignQueuePosition(campaignId, isGroup)
    end
    if type(position) ~= "number" or position < 1 then
        return false
    end

    local previous = saved.lastQueuePosition or 0
    local movedForward = previous > 0 and position < previous
    if movedForward then
        saved.lastMoveTimestamp = GetTimeStamp()
    end
    saved.lastQueuePosition = position
    return movedForward
end

local function FormatElapsed(seconds)
    seconds = math.max(0, math.floor(seconds))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainder = seconds % 60
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, remainder)
    end
    return string.format("%02d:%02d", minutes, remainder)
end

local function GetMovementElapsedSeconds()
    local lastMove = saved.lastMoveTimestamp
    if (lastMove or 0) <= 0 then
        return nil
    end
    return math.max(0, GetTimeStamp() - lastMove)
end

local function Colored(value, hex)
    return "|c" .. hex .. tostring(value) .. "|r"
end

local function UpdateDetails()
    if not detailsLabel then
        return
    end

    local inactive = displayState == "NOT_IN_QUEUE"
    local parts = {}

    if saved.showPosition then
        local position = "--"
        local currentPosition = saved.lastQueuePosition
        if not inactive and (currentPosition or 0) > 0 then
            position = tostring(currentPosition)
        end
        local positionLabel = displayState == "QUEUE_BROKEN" and "Last:" or "Position:"
        parts[#parts + 1] = Colored(positionLabel, "A4ADBD") .. " " ..
            Colored(position, inactive and "7D8796" or "B7E8FF")
    end

    if saved.showTimer then
        local elapsedText = "--:--"
        if not inactive then
            local elapsed = GetMovementElapsedSeconds()
            if elapsed then
                elapsedText = FormatElapsed(elapsed)
            end
        end
        parts[#parts + 1] = Colored("No move:", "A4ADBD") .. " " ..
            Colored(elapsedText, inactive and "7D8796" or "FFD58C")
    end

    local hasDetails = #parts > 0
    detailsLabel:SetHidden(not hasDetails)
    detailsLabel:SetText(table.concat(parts, "  |  "))
    local normalHeight = hasDetails and 65 or 43
    local broken = displayState == "QUEUE_BROKEN"
    if logoutButton then
        logoutButton:SetHidden(not broken)
        logoutButton:ClearAnchors()
        logoutButton:SetAnchor(TOP, window, TOP, 0, normalHeight + 1)
    end
    window:SetHeight(normalHeight + (broken and 34 or 0))
end

local function UpdateWindowVisibility()
    if window then
        local insideCyrodiil = IsInCyrodiil()
        window:SetHidden(not saved.showPanel or insideCyrodiil)
    end
end

local function SetDisplay(state)
    displayState = state
    if not statusLabel then
        return
    end
    local text
    if displayState == "IN_QUEUE" then
        text = "In Queue"
    elseif displayState == "QUEUE_BROKEN" then
        text = "Queue Broken"
    else
        text = "Not In Queue"
    end
    local color = colors[displayState]
    statusLabel:SetText(text)
    statusLabel:SetColor(color[1], color[2], color[3], 1)
    UpdateDetails()
    UpdateWindowVisibility()
end

local function ApplyDisplaySettings()
    UpdateWindowVisibility()
    if detailsLabel then
        UpdateDetails()
    end
end

local function PlaySelectedSound(soundName)
    if not soundName or soundName == "NONE" then
        return
    end
    local soundId = SOUNDS and SOUNDS[soundName]
    if soundId then
        PlaySound(soundId)
    end
end

-- Open the game's native logout confirmation rather than immediately logging
-- the character out. The player still has a chance to cancel.
local function StartLogout()
    if not saved.broken then
        return
    end
    if IsInGamepadPreferredMode and IsInGamepadPreferredMode() then
        ZO_Dialogs_ShowGamepadDialog("GAMEPAD_LOG_OUT", { quit = false })
    else
        ZO_Dialogs_ShowDialog("LOG_OUT")
    end
end

local function Announce(title, message, isBroken)
    if saved.audioAlerts then
        PlaySelectedSound(isBroken and saved.brokenSound or saved.readySound)
    end

    if not saved.visualAlerts or not alertWindow then
        return
    end

    alertGeneration = alertGeneration + 1
    local thisAlert = alertGeneration
    alertTitle:SetText(title)
    alertMessage:SetText(message)
    if isBroken then
        alertTitle:SetColor(1.00, 0.38, 0.38, 1)
        alertBackdrop:SetEdgeColor(0.95, 0.26, 0.26, 0.98)
    else
        alertTitle:SetColor(0.45, 1.00, 0.63, 1)
        alertBackdrop:SetEdgeColor(0.34, 0.88, 0.52, 0.98)
    end
    alertWindow:SetHeight(112)
    alertWindow:SetHidden(false)

    zo_callLater(function()
        if alertGeneration == thisAlert and alertWindow then
            alertWindow:SetHidden(true)
        end
    end, ALERT_DURATION_MS)
end

local function HideAlert()
    alertGeneration = alertGeneration + 1
    if alertWindow then
        alertWindow:SetHidden(true)
    end
end

-- A queue request being sent is not proof that ESO accepted the player.
-- Keep the visible warning attached to the draggable panel; audio and visual
-- options are respected, and chat always receives the failure message.
local function ClearRequeueWatch()
    saved.requeueWatchCampaignId = 0
    saved.requeueWatchIsGroup = false
    saved.requeueWatchStartedAt = 0
end

local function HasRequeueWatch()
    return (saved.requeueWatchCampaignId or 0) > 0
        and (saved.requeueWatchStartedAt or 0) > 0
end

local function IsWatchedQueueConfirmed()
    if not HasRequeueWatch() then
        return false
    end
    local campaignId, isGroup = FindCyrodiilQueue()
    if not IsSameQueue(campaignId, isGroup,
        saved.requeueWatchCampaignId, saved.requeueWatchIsGroup == true) then
        return false
    end
    -- A PENDING_JOIN entry alone is not a successful server response.
    local state = GetCampaignQueueState(campaignId, isGroup)
    return state == CAMPAIGN_QUEUE_REQUEST_STATE_WAITING
        or state == CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING
end

local function ConfirmAutoRequeue()
    if HasRequeueWatch() then
        ClearRequeueWatch()
        d("[CyroQueueStatus] Automatic requeue confirmed by ESO.")
    end
end

local function NotifyAutoRequeueFailure(reason)
    ClearRequeueWatch() -- Also prevents duplicate warnings from late events.
    local explanation = reason and (" (" .. tostring(reason) .. ")") or ""
    d("[CyroQueueStatus] Automatic requeue failed" .. explanation
        .. ". Please join your Cyrodiil campaign queue manually.")
    Announce("AUTO-REQUEUE FAILED",
        "Could not join automatically. Open Campaigns and queue manually.", true)
end

local function RefreshStatus()
    if not isInitialized then
        return
    end

    -- A broken queue cannot self-recover, even if ESO later reports a position
    -- change, ready state, a queue exit, or an apparent new queue join.
    if saved.broken then
        SetDisplay("QUEUE_BROKEN")
        return
    end

    local campaignId, isGroup = FindCyrodiilQueue()
    if campaignId then
        TrackQueuePosition(campaignId, isGroup)
        SetDisplay("IN_QUEUE")
    else
        ClearPositionTracking()
        SetDisplay("NOT_IN_QUEUE")
    end
end

-- Manual recovery from invalid or stale add-on state. This deliberately does
-- not call ESO queue APIs: clearing an add-on warning cannot repair the game's
-- queue, and it must not unexpectedly leave or join a campaign.
local function ResetQueueTracking()
    ClearRequeueWatch()
    saved.requeuePending = false
    saved.requeueCampaignId = 0
    saved.requeueIsGroup = false
    saved.requeueCharacterId = ""
    saved.requeueLogoutRequested = false
    logoutMarkerAtLoad = false
    ClearBrokenFlag()
    ClearPositionTracking()
    readyKey = nil
    autoAcceptKey = nil
    HideAlert()
    RefreshStatus()
    d("[CyroQueueStatus] Queue tracking reset. ESO's actual queue was not changed.")
end

local function SaveWindowPosition()
    if window and saved then
        saved.x = math.floor(window:GetLeft() + 0.5)
        saved.y = math.floor(window:GetTop() + 0.5)
    end
end

local function CreateWindow()
    window = WINDOW_MANAGER:CreateTopLevelWindow("CyroQueueStatusWindow")
    window:SetDimensions(PANEL_WIDTH, 65)
    window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, saved.x, saved.y)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetHidden(not saved.showPanel or IsInCyrodiil())

    local background = WINDOW_MANAGER:CreateControl(
        "CyroQueueStatusBackground", window, CT_BACKDROP)
    background:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
    background:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, 0, 0)
    background:SetCenterColor(0.04, 0.04, 0.06, 0.82)
    background:SetEdgeColor(0.38, 0.38, 0.45, 0.85)
    background:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)

    statusLabel = WINDOW_MANAGER:CreateControl(
        "CyroQueueStatusLabel", window, CT_LABEL)
    statusLabel:SetAnchor(TOPLEFT, window, TOPLEFT, 8, 5)
    statusLabel:SetDimensions(PANEL_INNER_WIDTH, 30)
    statusLabel:SetFont("ZoFontGameBold")
    statusLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    statusLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    detailsLabel = WINDOW_MANAGER:CreateControl(
        "CyroQueueStatusDetailsLabel", window, CT_LABEL)
    detailsLabel:SetAnchor(TOPLEFT, window, TOPLEFT, 8, 35)
    detailsLabel:SetDimensions(PANEL_INNER_WIDTH, 24)
    detailsLabel:SetFont("ZoFontGameSmall")
    detailsLabel:SetColor(1, 1, 1, 1) -- Text color markup distinguishes labels and values.
    detailsLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    detailsLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    logoutButton = WINDOW_MANAGER:CreateControlFromVirtual(
        "CyroQueueStatusLogoutButton", window, "ZO_DefaultButton")
    logoutButton:SetDimensions(112, 26)
    logoutButton:SetFont("ZoFontGameSmall")
    logoutButton:SetText("Log Out")
    logoutButton:SetAnchor(TOP, window, TOP, 0, 66)
    logoutButton:SetHandler("OnClicked", StartLogout)
    logoutButton:SetHidden(true)

    -- Dragging either the status panel or an attached notification moves the
    -- same saved window position. Buttons retain their own click handlers.
    local function MakeDragHandle(control)
        control:SetHandler("OnMouseDown", function(_, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then
                window:StartMoving()
            end
        end)
        control:SetHandler("OnMouseUp", function(_, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then
                window:StopMovingOrResizing()
                SaveWindowPosition()
            end
        end)
    end
    MakeDragHandle(window)
    window:SetHandler("OnMoveStop", SaveWindowPosition)
end

local function CreateAlertWindow()
    -- Notifications belong to the draggable panel, not an independent
    -- screen-centered window. Hiding the panel also hides its notifications.
    alertWindow = WINDOW_MANAGER:CreateControl("CyroQueueStatusAlert", window, CT_CONTROL)
    alertWindow:SetDimensions(PANEL_WIDTH, 112)
    alertWindow:SetAnchor(TOP, window, BOTTOM, 0, 6)
    alertWindow:SetMouseEnabled(true)
    alertWindow:SetHidden(true)

    -- The notification background is also a drag handle for the main panel.
    alertWindow:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            window:StartMoving()
        end
    end)
    alertWindow:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            window:StopMovingOrResizing()
            SaveWindowPosition()
        end
    end)

    alertBackdrop = WINDOW_MANAGER:CreateControl(
        "CyroQueueStatusAlertBackdrop", alertWindow, CT_BACKDROP)
    alertBackdrop:SetAnchor(TOPLEFT, alertWindow, TOPLEFT, 0, 0)
    alertBackdrop:SetAnchor(BOTTOMRIGHT, alertWindow, BOTTOMRIGHT, 0, 0)
    alertBackdrop:SetCenterColor(0.035, 0.035, 0.055, 0.95)
    alertBackdrop:SetEdgeColor(0.95, 0.26, 0.26, 0.98)
    alertBackdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)

    alertTitle = WINDOW_MANAGER:CreateControl(
        "CyroQueueStatusAlertTitle", alertWindow, CT_LABEL)
    alertTitle:SetAnchor(TOPLEFT, alertWindow, TOPLEFT, 8, 8)
    alertTitle:SetDimensions(PANEL_INNER_WIDTH, 30)
    alertTitle:SetFont("ZoFontGameBold")
    alertTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    alertTitle:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    alertMessage = WINDOW_MANAGER:CreateControl(
        "CyroQueueStatusAlertMessage", alertWindow, CT_LABEL)
    alertMessage:SetAnchor(TOPLEFT, alertWindow, TOPLEFT, 12, 42)
    alertMessage:SetDimensions(PANEL_WIDTH - 24, 60)
    alertMessage:SetFont("ZoFontGameSmall")
    alertMessage:SetColor(0.92, 0.93, 0.96, 1)
    alertMessage:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    alertMessage:SetVerticalAlignment(TEXT_ALIGN_CENTER)
end

local function HandleQueueReady(campaignId, isGroup)
    if saved.broken or not IsCyrodiilCampaign(campaignId) then
        return
    end
    isGroup = isGroup == true
    if GetCampaignQueueState(campaignId, isGroup) ~= CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING then
        return
    end

    local key = QueueKey(campaignId, isGroup)
    if readyKey ~= key then
        readyKey = key
        Announce("CYRODIIL QUEUE READY",
            saved.autoAccept and "Accepting your campaign invitation automatically."
                or "Your campaign is ready. Accept the invitation in ESO.",
            false)
    end

    if saved.autoAccept and autoAcceptKey ~= key then
        autoAcceptKey = key -- Avoid repeated accept attempts on every poll.
        zo_callLater(function()
            if not isInitialized or not saved.autoAccept or saved.broken then
                return
            end
            local currentId, currentIsGroup = FindCyrodiilQueue()
            if IsSameQueue(currentId, currentIsGroup, campaignId, isGroup)
                and GetCampaignQueueState(campaignId, isGroup)
                    == CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING then
                -- Accept the confirmed campaign invitation.
                ConfirmCampaignEntry(campaignId, isGroup, true)
            end
        end, AUTO_ACCEPT_DELAY_MS)
    end
end

local function OnQueueJoined(_, campaignId, isGroup)
    if not IsCyrodiilCampaign(campaignId) then
        return
    end
    if saved.broken then
        SetDisplay("QUEUE_BROKEN")
        return
    end
    if HasRequeueWatch() and IsSameQueue(campaignId, isGroup == true,
        saved.requeueWatchCampaignId, saved.requeueWatchIsGroup == true) then
        ConfirmAutoRequeue() -- ESO's joined event is authoritative.
    end
    saved.requeuePending = false
    saved.requeueLogoutRequested = false
    readyKey = nil
    autoAcceptKey = nil
    HideAlert()
    TrackQueuePosition(campaignId, isGroup, nil, true)
    SetDisplay("IN_QUEUE")
    zo_callLater(RefreshStatus, 300)
end

local function OnQueueLeft(_, campaignId, isGroup)
    if saved.broken or not IsCyrodiilCampaign(campaignId) then
        return
    end
    isGroup = isGroup == true
    if IsSameQueue(campaignId, isGroup,
        saved.trackedCampaignId, saved.trackedIsGroup) then
        ClearPositionTracking()
    end
    readyKey = nil
    autoAcceptKey = nil
    SetDisplay("NOT_IN_QUEUE")
    zo_callLater(RefreshStatus, 300)
end

local function OnQueueProgress(_, campaignId, isGroup, newState)
    if saved.broken or not IsCyrodiilCampaign(campaignId) then
        return
    end
    isGroup = isGroup == true
    TrackQueuePosition(campaignId, isGroup)

    local state = newState or GetCampaignQueueState(campaignId, isGroup)
    if IsWatchedQueueConfirmed() then
        ConfirmAutoRequeue()
    end
    if state == CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING then
        HandleQueueReady(campaignId, isGroup)
    elseif state == CAMPAIGN_QUEUE_REQUEST_STATE_WAITING then
        readyKey = nil
        autoAcceptKey = nil
    end
    RefreshStatus()
end

local function OnQueuePositionChanged(_, campaignId, isGroup, position)
    if saved.broken or not IsCyrodiilCampaign(campaignId) then
        return
    end
    TrackQueuePosition(campaignId, isGroup, position)
    RefreshStatus()
end

local function OnQueueResponse(_, response)
    -- Responses to the relog requeue request are distinct from failures of an
    -- already-established campaign queue. ESO doesn't include a campaign ID in
    -- this event, so only interpret it while one request is awaiting a reply.
    if HasRequeueWatch() then
        if IsWatchedQueueConfirmed() then
            ConfirmAutoRequeue()
            return
        end
        if response == QUEUE_FOR_CAMPAIGN_RESULT_SUCCESS then
            return -- Accepted for processing; wait for a real queue entry.
        end
        NotifyAutoRequeueFailure("ESO response " .. tostring(response))
        return
    end
    if response ~= QUEUE_FOR_CAMPAIGN_RESULT_DESTINATION_WORLD_FULL or saved.broken then
        return
    end

    -- Keep the most recently observed Cyrodiil queue as a fallback: ESO may
    -- already have removed the entry when the error event reaches our handler.
    local campaignId, isGroup = FindCyrodiilQueue()
    if not campaignId then
        campaignId = saved.trackedCampaignId
        isGroup = saved.trackedIsGroup
    elseif GetCampaignQueueState(campaignId, isGroup) ~= CAMPAIGN_QUEUE_REQUEST_STATE_WAITING then
        return -- Only destination-full errors while WAITING mean a broken queue.
    end
    if not IsCyrodiilCampaign(campaignId) then
        return
    end

    saved.broken = true
    saved.brokenCampaignId = campaignId
    saved.brokenIsGroup = isGroup == true
    saved.requeueLogoutRequested = false
    saved.requeueCampaignId = campaignId
    saved.requeueIsGroup = isGroup == true
    saved.requeueCharacterId = tostring(GetCurrentCharacterId())
    saved.requeuePending = false
    ClearRequeueWatch()
    readyKey = nil
    autoAcceptKey = nil
    SetDisplay("QUEUE_BROKEN")
    Announce("CYRODIIL QUEUE BROKEN",
        "Destination is full. Log out and back in, then requeue.", true)
end

-- One request per detected relog. ESO determines whether the request can
-- actually be accepted (campaign eligibility, queue conditions, and group rules).
-- Never attempt to cancel an existing queue or bypass a broken-state latch.
local function TryRequeueAfterRelog()
    if not saved.requeuePending then
        return
    end

    -- Consume before doing any work, so zone changes and UI reloads cannot
    -- send duplicate requests. A separate watch monitors the resulting reply.
    saved.requeuePending = false
    local campaignId = saved.requeueCampaignId
    local isGroup = saved.requeueIsGroup == true
    local characterId = saved.requeueCharacterId
    saved.requeueCampaignId = 0
    saved.requeueIsGroup = false
    saved.requeueCharacterId = ""

    if not saved.autoRequeue or saved.broken
        or characterId == "" or characterId ~= tostring(GetCurrentCharacterId()) then
        return
    end
    if not IsCyrodiilCampaign(campaignId) then
        NotifyAutoRequeueFailure("campaign unavailable")
        return
    end
    if IsInCyrodiil() then
        return -- Requeue isn't needed inside Cyrodiil.
    end
    if FindCyrodiilQueue() then
        d("[CyroQueueStatus] Already in a Cyrodiil queue; automatic requeue was skipped.")
        return
    end
    if isGroup and (not IsUnitGrouped("player") or not IsUnitGroupLeader("player")) then
        NotifyAutoRequeueFailure("group queue requires the group leader")
        return
    end

    -- Register the watch before requesting, since responses can be immediate.
    ClearRequeueWatch()
    saved.requeueWatchCampaignId = campaignId
    saved.requeueWatchIsGroup = isGroup
    saved.requeueWatchStartedAt = GetTimeStamp()
    local result = QueueForCampaign(campaignId, isGroup)
    if result == false then
        if HasRequeueWatch() then
            NotifyAutoRequeueFailure("queue request rejected")
        end
    elseif HasRequeueWatch() then
        d("[CyroQueueStatus] Requested the previous Cyrodiil queue. Waiting for ESO confirmation.")
    end
end

local function OnPlayerActivated(_, firstLoad)
    -- Only the first activation after the add-on has loaded can clear a broken
    -- queue. ESO sends firstLoad=false for /reloadui, and true for a fresh
    -- world load (also for later zone changes, which we explicitly ignore).
    if not firstActivationHandled then
        firstActivationHandled = true
        if firstLoad == true and HasRequeueWatch() then
            ClearRequeueWatch()
        end
        if saved.broken and (firstLoad == true or logoutMarkerAtLoad) then
            local sameCharacter = saved.requeueCharacterId ~= ""
                and saved.requeueCharacterId == tostring(GetCurrentCharacterId())
            saved.requeuePending = saved.autoRequeue and sameCharacter
                and (saved.requeueCampaignId or 0) > 0
            ClearBrokenFlag()
            ClearPositionTracking()
            d("[CyroQueueStatus] New character session detected."
                .. (saved.requeuePending and " Restoring previous Cyrodiil queue."
                    or " Queue warning cleared."))
        end
    end
    RefreshStatus()
    zo_callLater(function()
        RefreshStatus()
        if not saved.broken then
            local campaignId, isGroup = FindCyrodiilQueue()
            if campaignId then
                HandleQueueReady(campaignId, isGroup)
            end
        end
    end, 2500)
    if saved.requeuePending then
        zo_callLater(TryRequeueAfterRelog, 2800)
    end
end

local function OnStatusTick()
    RefreshStatus()
    if HasRequeueWatch() then
        if IsWatchedQueueConfirmed() then
            ConfirmAutoRequeue()
        elseif GetTimeStamp() - saved.requeueWatchStartedAt
            >= REQUEUE_CONFIRM_TIMEOUT_SECONDS then
            NotifyAutoRequeueFailure("no queue confirmation within 20 seconds")
        end
    end
    if not saved.broken then
        local campaignId, isGroup = FindCyrodiilQueue()
        if campaignId then
            HandleQueueReady(campaignId, isGroup)
        end
    end
end

local function RegisterSettings()
    local LAM = LibAddonMenu2

    local panelId = "CyroQueueStatusOptions"
    settingsPanel = LAM:RegisterAddonPanel(panelId, {
        type = "panel",
        name = "Cyrodiil Queue Status",
        displayName = "Cyrodiil Queue Status",
        author = "HUMILIATION115",
        version = "1.4.2",
        registerForDefaults = true,
    })

    local function Checkbox(name, tooltip, field, onChange)
        return {
            type = "checkbox",
            name = name,
            tooltip = tooltip,
            width = "full",
            getFunc = function() return saved[field] end,
            setFunc = function(value)
                saved[field] = value
                if onChange then onChange() end
            end,
            default = defaults[field],
        }
    end

    LAM:RegisterOptionControls(panelId, {
        { type = "header", name = "Status Panel", width = "full" },
        Checkbox("Show Status Panel",
            "Display the draggable queue status panel and its attached notifications.",
            "showPanel", ApplyDisplaySettings),
        Checkbox("Show Queue Position",
            "Show your current queue position, or the last known position if the queue fails.",
            "showPosition", ApplyDisplaySettings),
        Checkbox("Show Time Since Progress",
            "Show the time elapsed since your position last improved.",
            "showTimer", ApplyDisplaySettings),

        { type = "header", name = "Queue Ready", width = "full" },
        Checkbox("Automatically Accept Cyrodiil Queue",
            "Automatically accept a campaign invitation when ESO reports the queue is ready.",
            "autoAccept"),
        Checkbox("Automatically Requeue After Relog",
            "Request the previous campaign queue after relogging. If ESO rejects the request, the addon will notify you to queue manually. Group requeue requires you to be the group leader.",
            "autoRequeue", function()
                if not saved.autoRequeue then
                    saved.requeuePending = false
                    ClearRequeueWatch()
                end
            end),

        { type = "header", name = "Queue Tracking", width = "full" },
        {
            type = "button",
            name = "Reset Queue Tracking",
            tooltip = "Clear saved queue status, movement timing and pending requeue requests. This does not change ESO's actual campaign queue.",
            func = ResetQueueTracking,
            width = "full",
        },

        { type = "header", name = "Alerts", width = "full" },
        Checkbox("Show On-Screen Alerts",
            "Display queue-ready and queue-failure notifications below the status panel.",
            "visualAlerts", function() if not saved.visualAlerts then HideAlert() end end),
        Checkbox("Enable Audio Alerts",
            "Play a sound when the campaign queue is ready or fails.",
            "audioAlerts"),
        {
            type = "dropdown",
            name = "Queue Ready Sound",
            tooltip = "Choose the queue-ready sound. Select None to mute this alert.",
            choices = soundNames,
            choicesValues = soundValues,
            getFunc = function() return saved.readySound end,
            setFunc = function(value) saved.readySound = value end,
            default = defaults.readySound,
            width = "full",
        },
        {
            type = "dropdown",
            name = "Queue Broken Sound",
            tooltip = "Choose the queue-failure sound. Select None to mute this alert.",
            choices = soundNames,
            choicesValues = soundValues,
            getFunc = function() return saved.brokenSound end,
            setFunc = function(value) saved.brokenSound = value end,
            default = defaults.brokenSound,
            width = "full",
        },
        {
            type = "button",
            name = "Preview Ready Sound",
            func = function() PlaySelectedSound(saved.readySound) end,
            width = "half",
        },
        {
            type = "button",
            name = "Preview Broken Sound",
            func = function() PlaySelectedSound(saved.brokenSound) end,
            width = "half",
        },
        {
            type = "description",
            text = "The Log Out button opens ESO's logout confirmation. The status panel and its notifications are hidden while inside Cyrodiil.",
            width = "full",
        },
    })
end

local function Initialize()
    saved = ZO_SavedVars:NewCharacterIdSettings(
        "CyroQueueStatusSaved", 1, nil, defaults)
    -- Remove saved test-mode metadata from pre-release installations.
    saved.requeueTestArmed = nil
    -- Use an available sound when the saved preference is unsupported.
    if saved.readySound == "CAMPAIGN_READY_CHECK"
        and not (SOUNDS and SOUNDS.CAMPAIGN_READY_CHECK) then
        saved.readySound = "COUNTDOWN_WARNING"
    end
    -- Recover a watch after /reloadui, but never reuse it across a genuine
    -- character session change. An unfinished previous-session request cannot
    -- confirm the new session's queue.
    if HasRequeueWatch() and (saved.requeueWatchStartedAt > GetTimeStamp()
        or not saved.autoRequeue) then
        ClearRequeueWatch()
    end
    -- Do not infer relogging from GetGameTimeMilliseconds: it can continue
    -- increasing between character logins in the same running ESO client.
    -- Wait for the first EVENT_PLAYER_ACTIVATED after this add-on load.
    logoutMarkerAtLoad = saved.requeueLogoutRequested == true
    if saved.broken then
        saved.requeuePending = false
    end

    -- ESO's Logout function runs after the player confirms logging out;
    -- opening the Log Out dialog alone does not mark a relog. The marker is a
    -- fallback for clients where the activation event's boolean is unusual.
    if ZO_PreHook and Logout then
        ZO_PreHook("Logout", function()
            if saved and saved.broken then
                saved.requeueLogoutRequested = true
            end
        end)
    end
    -- A UI reload never counts as relogging, even if requested after a
    -- previously deferred or denied logout.
    if ZO_PreHook and ReloadUI then
        ZO_PreHook("ReloadUI", function()
            if saved then
                saved.requeueLogoutRequested = false
            end
        end)
    end
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_LogoutDisallowed",
        EVENT_LOGOUT_DISALLOWED, function()
            if saved then saved.requeueLogoutRequested = false end
        end)
    CreateWindow()
    CreateAlertWindow()
    isInitialized = true
    RefreshStatus()
    RegisterSettings()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CAMPAIGN_QUEUE_JOINED, OnQueueJoined)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CAMPAIGN_QUEUE_LEFT, OnQueueLeft)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CAMPAIGN_QUEUE_STATE_CHANGED, OnQueueProgress)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CAMPAIGN_QUEUE_POSITION_CHANGED,
        OnQueuePositionChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEUE_FOR_CAMPAIGN_RESPONSE,
        OnQueueResponse)
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_Ticker", STATUS_REFRESH_MS, OnStatusTick)

    SLASH_COMMANDS["/cqs"] = function(command)
        command = string.lower(zo_strtrim(command or ""))
        if command == "settings" then
            LibAddonMenu2:OpenToPanel(settingsPanel)
        elseif command == "reset" then
            ResetQueueTracking()
        else
            d("[CyroQueueStatus] Commands: /cqs settings, /cqs reset")
        end
    end
end

-- The manifest loads the required library before this add-on.
local function OnAddonLoaded(_, name)
    if name ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
