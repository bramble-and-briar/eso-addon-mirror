-- Keyboard UI only. The addon calls Init after saved variables and modules are ready.
local A = RoleplayPostSupport
local L = A.L
local U = {}
A.UI = U

-- Practical editor cap in codepoints, not a chat limit; no draft is saved to disk.
local EDITOR_CAP, HISTORY_PAGE_SIZE = 1000000, 10
local c = {}
local initialized, loadingParticipants = false, false
local tab, destinationIndex, previewPage, historyPage = "compose", 1, 1, 1
local previewChunks, displayedId, deleteId, historyKey, historyNewest, historyNewestFirst
local participantDrafts = {}
local composedBatch
local sentenceSetting, notice = true, L("UI_DRAFT_NOTICE")
local edits = {}
local controlId = 0

local function controlName()
    controlId = controlId + 1
    return "RoleplayPostSupportUIControl" .. controlId
end

local function plain(value)
    return (tostring(value or ""):gsub("|", ""))
end

local function formatSender(message)
    local name = message.sender
    if type(name) ~= "string" or name == "" then name = message.displayName end
    if type(name) ~= "string" or name == "" then return L("UI_UNKNOWN_SENDER") end
    -- ESO grammar suffixes belong to character names, not account handles or message text.
    if name:sub(1, 1) ~= "@" and type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", name)
        if ok and type(formatted) == "string" and formatted ~= "" then return formatted end
    end
    return name
end

local function formatTimestamp(timestamp)
    if type(timestamp) ~= "number" or timestamp < 0 or timestamp >= math.huge
        or timestamp ~= math.floor(timestamp) then return L("UI_UNKNOWN_TIME") end
    if type(os) ~= "table" or type(os.date) ~= "function" then return L("UI_UNKNOWN_TIME") end
    local ok, text = pcall(os.date, "%Y-%m-%d %H:%M:%S", timestamp)
    if ok and type(text) == "string" and text ~= "" then return text end
    return L("UI_UNKNOWN_TIME")
end

-- Sessions exposes stable error codes; translate only at the presentation boundary.
local sessionErrorKeys = {
    invalid_channel = "UI_ERROR_INVALID_CHANNEL",
    target_required = "UI_ERROR_TARGET_REQUIRED",
    invalid_saved_variables = "UI_ERROR_INVALID_SAVED_VARIABLES",
    not_initialized = "UI_ERROR_SESSIONS_NOT_INITIALIZED",
    session_limit = "UI_ERROR_SESSION_LIMIT",
    name_required = "UI_ERROR_NAME_REQUIRED",
    session_not_found = "UI_ERROR_SESSION_NOT_FOUND",
    no_current_session = "UI_ERROR_NO_CURRENT_SESSION",
    invalid_participants = "UI_ERROR_INVALID_PARTICIPANTS",
    invalid_addon_only_flag = "UI_ERROR_INVALID_ADDON_ONLY_FLAG",
    invalid_recording_flag = "UI_ERROR_INVALID_RECORDING_FLAG",
}

local function notify(message)
    local key = sessionErrorKeys[message]
    if key then message = L(key) end
    if A.Notify then A.Notify(message) else U.Notify(message) end
end

local function result(ok, err, success)
    if not ok then notify(err or L("UI_OPERATION_FAILED"))
    elseif success then notify(success) end
    U.Refresh()
    return ok
end

local function control(parent, kind, x, y, width, height, template)
    local item
    if template then
        item = WINDOW_MANAGER:CreateControlFromVirtual(controlName(), parent, template)
    else
        item = WINDOW_MANAGER:CreateControl(controlName(), parent, kind)
    end
    item:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    item:SetDimensions(width, height)
    return item
end

local function label(parent, text, x, y, width, height)
    local item = control(parent, CT_LABEL, x, y, width, height or 24)
    ---@cast item LabelControl
    item:SetFont("ZoFontGame")
    item:SetColor(0.85, 0.82, 0.74, 1)
    item:SetText(text)
    return item
end

local function button(parent, text, x, y, width, callback)
    local item = control(parent, CT_BUTTON, x, y, width, 28, "ZO_DefaultButton")
    item:SetFont("ZoFontGame")
    item:SetText(text)
    item:SetHandler("OnClicked", callback)
    return item
end

local function edit(parent, x, y, width, height, multiline, cap)
    local backdrop = control(parent, CT_BACKDROP, x, y, width, height,
        multiline and "ZO_MultiLineEditBackdrop_Keyboard" or "ZO_SingleLineEditBackdrop_Keyboard")
    local item = WINDOW_MANAGER:CreateControlFromVirtual(controlName(), backdrop,
        multiline and "ZO_DefaultEditMultiLineForBackdrop" or "ZO_DefaultEditForBackdrop")
    item:SetMaxInputChars(cap or EDITOR_CAP)
    if multiline then item:SetNewLineEnabled(true) end
    -- Leave the templates' wheel scrolling and Escape-to-blur handlers intact.
    edits[#edits + 1] = item
    return item
end

local function blur()
    for _, item in ipairs(edits) do item:LoseFocus() end
end

local function draggable(window, title, width)
    local bar = control(window, CT_CONTROL, 8, 4, width - 48, 32)
    bar:SetMouseEnabled(true)
    label(bar, title, 10, 3, width - 80, 26):SetFont("ZoFontWinH4")
    bar:SetHandler("OnMouseDown", function(_, mouseButton)
        if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
            window:SetMovable(true)
            window:StartMoving()
        end
    end)
    bar:SetHandler("OnMouseUp", function(_, mouseButton)
        if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
            window:StopMovingOrResizing()
            window:SetMovable(false)
        end
    end)
    window:SetHandler("OnMoveStop", function() window:SetMovable(false) end)
    return bar
end

local function window(name, width, height)
    local item = WINDOW_MANAGER:CreateTopLevelWindow(name)
    item:SetDimensions(width, height)
    item:SetClampedToScreen(true)
    item:SetMouseEnabled(true)
    item:SetHidden(true)
    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(controlName(), item, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(item)
    return item
end

local function destination()
    local entry = A.Chat.Destinations[destinationIndex]
    return entry and entry.channel, c.target:GetText()
end


local function refreshDestination()
    local entry = A.Chat.Destinations[destinationIndex]
    c.destination:SetEnabled(entry ~= nil)
    if entry then
        c.destination:SelectItemByIndex(destinationIndex, true)
    else
        c.destination:SetSelectedItemText(L("UI_DESTINATION_UNAVAILABLE"))
    end
end

local function showPreview()
    local total = previewChunks and #previewChunks or 0
    previewPage = math.max(1, math.min(previewPage, total))
    c.previewTitle:SetText(total > 0 and L("UI_PREVIEW_TITLE",
        total, previewPage, total) or L("UI_PREVIEW_HELP"))
    c.preview:SetText(total > 0 and previewChunks[previewPage] or "")
    c.preview:SetTopLineIndex(1)
    c.previewPrevious:SetEnabled(total > 0 and previewPage > 1)
    c.previewNext:SetEnabled(previewPage < total)
end

local function invalidatePreview()
    previewChunks, previewPage = nil, 1
    showPreview()
end

local function changeTab(nextTab)
    blur()
    tab, deleteId = nextTab, nil
    U.Refresh()
end

local function selectRelative(delta)
    local list, current = A.Sessions.List(), A.Sessions.Current()
    if #list == 0 then return end
    local index = delta > 0 and 0 or #list + 1
    for i, session in ipairs(list) do
        if current and session.id == current.id then index = i; break end
    end
    index = math.max(1, math.min(#list, index + delta))
    local ok, err = A.Sessions.Select(list[index].id)
    result(ok, err)
end

local function refreshHistory(session)
    local messages = session and session.messages or {}
    local newest = messages[#messages]
    local newestFirst = A.saved.historyNewestFirst == true
    local orderChanged = newestFirst ~= historyNewestFirst
    c.historyOrder:SetText(L(newestFirst and "UI_HISTORY_NEWEST_FIRST" or "UI_HISTORY_OLDEST_FIRST"))
    -- Record identity detects arrivals even at the retention cap or in the same second.
    local newMessage = newest ~= historyNewest
    local followLatest = newMessage or orderChanged
    local pages = math.max(1, math.ceil(#messages / HISTORY_PAGE_SIZE))
    if followLatest then historyPage = newestFirst and 1 or pages end
    historyPage = math.max(1, math.min(historyPage, pages))
    c.historyTitle:SetText(L("UI_HISTORY_TITLE",
        historyPage, pages, #messages, session and session.dropped or 0))
    c.historyPrevious:SetEnabled(historyPage > 1)
    c.historyNext:SetEnabled(historyPage < pages)
    local first = (historyPage - 1) * HISTORY_PAGE_SIZE + 1
    local last = math.min(#messages, first + HISTORY_PAGE_SIZE - 1)
    local step = 1
    if newestFirst then
        first = #messages - (historyPage - 1) * HISTORY_PAGE_SIZE
        last, step = math.max(1, first - HISTORY_PAGE_SIZE + 1), -1
    end
    -- Unrelated queue/UI refreshes leave browsing, scrolling and review edits alone.
    local key = table.concat({ session and session.id or 0, historyPage,
        session and session.dropped or 0, #messages }, ":")
    if not followLatest and historyKey == key then return end
    local lines = {}
    for i = first, last, step do
        local message = messages[i]
        lines[#lines + 1] = L(message.outgoing and "UI_HISTORY_OUTGOING" or "UI_HISTORY_INCOMING",
            formatTimestamp(message.timestamp), formatSender(message), message.text or "")
    end
    c.history:SetText(table.concat(lines, "\n"))
    -- Native scroll extents include wrapped lines, not just message separators.
    c.history:SetTopLineIndex(followLatest and not newestFirst and #messages > 0
        and (c.history:GetScrollExtents() + 1) or 1)
    historyKey, historyNewest, historyNewestFirst = key, newest, newestFirst
end

local function refreshSessions()
    local session, list = A.Sessions.Current(), A.Sessions.List()
    local id = session and session.id
    if displayedId ~= id then
        displayedId, deleteId, historyKey, historyPage, historyNewest = id, nil, nil, 1, nil
        loadingParticipants = true
        c.participants:SetText(session and (participantDrafts[id]
            or table.concat(session.participants, "\n")) or "")
        loadingParticipants = false
    end
    local index = 0
    for i, entry in ipairs(list) do if entry.id == id then index = i; break end end
    c.sessionTitle:SetText(session and L("UI_SESSION_TITLE", index, #list, plain(session.name))
        or L("UI_NO_SESSION_SELECTED", #list))
    c.sessionPrevious:SetEnabled(#list > 0 and (index == 0 or index > 1))
    c.sessionNext:SetEnabled(#list > 0 and index < #list)
    c.sessionInfo:SetText(session and L("UI_SESSION_INFO",
        formatTimestamp(session.createdAt)) or L("UI_SESSION_HELP"))
    local dirty = session and participantDrafts[id] ~= nil
        and participantDrafts[id] ~= table.concat(session.participants, "\n")
    c.participantTitle:SetText(L(dirty and "UI_PARTICIPANTS_DIRTY" or "UI_PARTICIPANTS"))
    c.saveParticipants:SetEnabled(session ~= nil)
    local addonOnly = session ~= nil and session.addonOnly == true
    c.addonOnly:SetEnabled(session ~= nil)
    c.addonOnly:SetText(L(addonOnly and "UI_ADDON_ONLY_ON" or "UI_ADDON_ONLY_OFF"))
    c.record:SetEnabled(session ~= nil)
    c.delete:SetEnabled(session ~= nil)
    c.delete:SetText(L(deleteId and deleteId == id and "UI_CONFIRM_DELETE" or "UI_DELETE_SESSION"))
    local recording = A.Sessions.IsRecording()
    c.recordingIndicator:SetHidden(not recording)
    c.recordingTitle:SetText(L("UI_RECORDING_TITLE", session and plain(session.name) or L("UI_SESSION_FALLBACK")))
    c.record:SetText(L(recording and "UI_RECORDING_STOP" or "UI_RECORDING_START"))
    local count = session and #session.participants or 0
    local warningKey
    if addonOnly then
        warningKey = recording and "UI_RECORD_WARNING_MARKED_ON" or "UI_RECORD_WARNING_MARKED_OFF"
    else
        warningKey = recording and "UI_RECORD_WARNING_ALL_ON" or "UI_RECORD_WARNING_ALL_OFF"
    end
    c.recordWarning:SetText(L(warningKey, count))
    refreshHistory(session)
end

local function queueAction(action, argument)
    local ok, err = action(argument)
    result(ok, err)
end

local function buildIndicator()
    c.indicator = window("RoleplayPostSupportQueueIndicator", 550, 100)
    c.indicator:SetAnchor(TOP, GuiRoot, TOP, 0, 100)
    draggable(c.indicator, "", 550)
    c.queueTitle = label(c.indicator, L("UI_QUEUE_NAME"), 18, 7, 480, 26)
    c.queueReason = label(c.indicator, "", 18, 34, 514, 22)
    c.pause = button(c.indicator, L("UI_PAUSE"), 12, 63, 98, function()
        if A.Queue.paused then queueAction(A.Queue.Resume)
        else queueAction(A.Queue.Pause, L("UI_QUEUE_PAUSED_REASON")) end
    end)
    c.previous = button(c.indicator, L("UI_PREVIOUS"), 114, 63, 100, function()
        notify(L("UI_PREVIOUS_WARNING"))
        queueAction(A.Queue.Move, -1)
    end)
    c.next = button(c.indicator, L("UI_NEXT"), 218, 63, 100, function() queueAction(A.Queue.Move, 1) end)
    button(c.indicator, L("UI_CANCEL"), 322, 63, 100, function() queueAction(A.Queue.Cancel) end)
    button(c.indicator, L("UI_OPEN"), 426, 63, 110, function()
        c.main:SetHidden(false)
        U.Refresh()
    end)
end

local function buildRecordingIndicator()
    c.recordingIndicator = window("RoleplayPostSupportRecordingIndicator", 440, 100)
    c.recordingIndicator:SetAnchor(TOP, GuiRoot, TOP, 0, 210)
    draggable(c.recordingIndicator, "", 440)
    c.recordingTitle = label(c.recordingIndicator, "", 18, 7, 404, 26)
    label(c.recordingIndicator, L("UI_RECORDING_INDICATOR_HELP"),
        18, 35, 404, 22):SetFont("ZoFontGameSmall")
    button(c.recordingIndicator, L("UI_STOP"), 18, 63, 194, function()
        local ok, err = A.Sessions.SetRecording(false)
        result(ok, err, L("UI_RECORDING_OFF_NOTICE"))
    end)
    button(c.recordingIndicator, L("UI_OPEN"), 226, 63, 194, function()
        c.main:SetHidden(false)
        changeTab("sessions")
    end)
end

local function buildCompose()
    local parent = c.compose
    label(parent, L("UI_DESTINATION_LABEL"), 0, 3, 30)
    local dropdown = control(parent, CT_CONTROL, 34, 0, 196, 28, "ZO_ComboBox")
    c.destination = ZO_ComboBox_ObjectFromContainer(dropdown)
    c.destination:SetFont("ZoFontGame")
    c.destination:SetSortsItems(false)
    for index, entry in ipairs(A.Chat.Destinations) do
        local item = c.destination:CreateItemEntry(plain(entry.label), function()
            destinationIndex = index
        end)
        c.destination:AddItem(item)
    end
    label(parent, L("UI_WHISPER_TARGET"), 246, 3, 116)
    c.target = edit(parent, 370, 0, 370, 28, false)
    label(parent, L("UI_COMPOSE_HELP"),
        0, 36, 740, 24)
    c.composer = edit(parent, 0, 64, 740, 218, true)
    label(parent, L("UI_MAX_CHARS"), 0, 290, 90)
    label(parent, L("UI_PREFIX"), 104, 290, 116)
    label(parent, L("UI_SUFFIX"), 234, 290, 116)
    c.limit = label(parent, "", 364, 290, 376)
    c.maxChars = edit(parent, 0, 316, 90, 28, false, 10)
    c.prefix = edit(parent, 104, 316, 116, 28, false)
    c.suffix = edit(parent, 234, 316, 116, 28, false)
    c.sentences = button(parent, "", 364, 316, 226, function()
        sentenceSetting = not sentenceSetting
        c.sentences:SetText(L(sentenceSetting and "UI_SENTENCES_ON" or "UI_SENTENCES_OFF"))
    end)
    button(parent, L("UI_APPLY"), 606, 316, 134, function()
        local ok, err = A.ApplySettings(tonumber(c.maxChars:GetText()), c.prefix:GetText(),
            c.suffix:GetText(), sentenceSetting)
        if result(ok, err, L("UI_SETTINGS_APPLIED")) then
            c.maxChars:SetText(tostring(A.saved.maxChars))
            c.prefix:SetText(A.saved.prefix)
            c.suffix:SetText(A.saved.suffix)
            sentenceSetting = A.saved.sentences
            c.sentences:SetText(L(sentenceSetting and "UI_SENTENCES_ON" or "UI_SENTENCES_OFF"))
            invalidatePreview()
        end
    end)
    button(parent, L("UI_PREPARE_START"), 0, 358, 188, function()
        local channel, target = destination()
        local text = c.composer:GetText()
        -- Release our editors before Start gives focus to native chat, never after.
        blur()
        local previousPostId = A.Queue.postId
        local ok, err = A.Start(text, channel, target)
        -- A failed first preparation can still create a queue that Resume completes.
        if A.Queue.active and A.Queue.postId ~= previousPostId then
            composedBatch = { postId = A.Queue.postId, text = text }
        end
        result(ok, err, L("UI_QUEUE_PREPARED"))
    end)
    button(parent, L("UI_PREVIEW"), 200, 358, 110, function()
        local chunks, err = A.Preview(c.composer:GetText())
        if not chunks then notify(err or L("UI_PREVIEW_FAILED")) end
        previewChunks, previewPage = chunks, 1
        showPreview()
    end)
    label(parent, L("UI_PREPARE_HELP"), 326, 362, 414)
    c.previewTitle = label(parent, "", 0, 396, 530)
    c.previewPrevious = button(parent, "<", 628, 390, 50, function()
        previewPage = previewPage - 1
        showPreview()
    end)
    c.previewNext = button(parent, ">", 690, 390, 50, function()
        previewPage = previewPage + 1
        showPreview()
    end)
    c.preview = edit(parent, 0, 424, 740, 84, true)
    c.composer:SetHandler("OnTextChanged", function()
        -- Even editing back to the original text makes this a user-owned draft.
        composedBatch = nil
        invalidatePreview()
    end)
    c.maxChars:SetText(tostring(A.saved.maxChars or ""))
    c.prefix:SetText(A.saved.prefix)
    c.suffix:SetText(A.saved.suffix)
    sentenceSetting = A.saved.sentences
    c.sentences:SetText(L(sentenceSetting and "UI_SENTENCES_ON" or "UI_SENTENCES_OFF"))
    local channel, target = A.Chat.CurrentDestination()
    for index, entry in ipairs(A.Chat.Destinations) do
        if entry.channel == channel then destinationIndex = index; break end
    end
    c.target:SetText(target or "")
    refreshDestination()
    showPreview()
end

local function buildSessions()
    local parent = c.sessions
    c.sessionName = edit(parent, 0, 0, 424, 28, false)
    button(parent, L("UI_CREATE_SESSION"), 436, 0, 304, function()
        local channel, target = destination()
        local session, err = A.Sessions.Create(c.sessionName:GetText(), channel, target)
        if not session then result(nil, err); return end
        local ok, selectError = A.Sessions.Select(session.id)
        if result(ok, selectError, L("UI_SESSION_CREATED")) then
            c.sessionName:SetText("")
        end
    end)
    c.sessionPrevious = button(parent, L("UI_PREVIOUS"), 0, 42, 98, function() selectRelative(-1) end)
    c.sessionNext = button(parent, L("UI_NEXT"), 106, 42, 98, function() selectRelative(1) end)
    c.sessionTitle = label(parent, "", 218, 44, 522, 28)
    c.sessionInfo = label(parent, "", 0, 80, 740, 48)
    c.participantTitle = label(parent, "", 0, 130, 740)
    c.participants = edit(parent, 0, 156, 740, 76, true)
    c.participants:SetFont("ZoFontGameSmall")
    c.participants:SetHandler("OnTextChanged", function(self)
        if not loadingParticipants and displayedId then
            participantDrafts[displayedId] = self:GetText()
            refreshSessions()
        end
    end)
    c.saveParticipants = button(parent, L("UI_SAVE_PARTICIPANTS"), 0, 242, 190, function()
        local ok, err = A.Sessions.SetParticipants(c.participants:GetText())
        if result(ok, err, L("UI_PARTICIPANTS_SAVED")) then
            local session = A.Sessions.Current()
            if not session then return end
            participantDrafts[session.id] = nil
            loadingParticipants = true
            c.participants:SetText(table.concat(session.participants, "\n"))
            loadingParticipants = false
            U.Refresh()
        end
    end)
    c.record = button(parent, "", 204, 242, 260, function()
        -- Explicitly use the saved participants; never implicitly save this editor.
        local enabled = not A.Sessions.IsRecording()
        local ok, err = A.Sessions.SetRecording(enabled)
        result(ok, err, L(enabled and "UI_RECORDING_ON_NOTICE" or "UI_RECORDING_OFF_NOTICE"))
    end)
    c.delete = button(parent, L("UI_DELETE_SESSION"), 568, 242, 172, function()
        local session = A.Sessions.Current()
        if not session then return end
        if deleteId ~= session.id then
            deleteId = session.id
            notify(L("UI_DELETE_CONFIRMATION"))
            U.Refresh()
            return
        end
        local id = session.id
        local ok, err = A.Sessions.Delete(id)
        if ok then participantDrafts[id], deleteId = nil, nil end
        result(ok, err, L("UI_SESSION_DELETED"))
    end)
    c.addonOnly = button(parent, "", 0, 282, 350, function()
        local session = A.Sessions.Current()
        if not session then return end
        local ok, err = A.Sessions.SetAddonOnly(session.addonOnly ~= true)
        result(ok, err, L("UI_CAPTURE_FILTER_CHANGED"))
    end)
    label(parent, L("UI_ADDON_ONLY_HELP"), 364, 286, 376, 24):SetFont("ZoFontGameSmall")
    c.recordWarning = label(parent, "", 0, 314, 740, 40)
    c.recordWarning:SetFont("ZoFontGameSmall")
    c.historyTitle = label(parent, "", 0, 358, 412, 24)
    c.historyTitle:SetFont("ZoFontGameSmall")
    c.historyOrder = button(parent, "", 424, 354, 192, function()
        A.saved.historyNewestFirst = A.saved.historyNewestFirst ~= true
        U.Refresh()
    end)
    c.historyPrevious = button(parent, "<", 628, 354, 50, function()
        historyPage = historyPage - 1
        refreshHistory(A.Sessions.Current())
    end)
    c.historyNext = button(parent, ">", 690, 354, 50, function()
        historyPage = historyPage + 1
        refreshHistory(A.Sessions.Current())
    end)
    c.history = edit(parent, 0, 388, 740, 120, true)
    c.history:SetFont("ZoFontGameSmall")
end

function U.Init()
    if initialized then return true end
    if not A.saved or not A.Chat or not A.Queue or not A.Sessions then
        return nil, L("UI_INIT_REQUIRES_MODULES")
    end
    c.main = window("RoleplayPostSupportWindow", 780, 678)
    c.main:SetHandler("OnShow", function() SetGameCameraUIMode(true) end)
    local position = A.saved.window or {}
    if type(position.left) == "number" and type(position.top) == "number" then
        c.main:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, position.left, position.top)
    else
        c.main:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    draggable(c.main, L("UI_WINDOW_TITLE"), 780)
    c.main:SetHandler("OnMoveStop", function(self)
        self:SetMovable(false)
        A.saved.window = A.saved.window or {}
        A.saved.window.left, A.saved.window.top = self:GetLeft(), self:GetTop()
    end)
    local close = control(c.main, CT_BUTTON, 740, 6, 28, 28, "ZO_CloseButton")
    close:SetHandler("OnClicked", function() c.main:SetHidden(true) end)
    c.main:SetHandler("OnHide", function()
        blur()
        deleteId = nil
    end)
    c.composeTab = button(c.main, L("UI_COMPOSE_TAB"), 20, 46, 140, function() changeTab("compose") end)
    c.sessionsTab = button(c.main, L("UI_SESSIONS_TAB"), 170, 46, 140, function() changeTab("sessions") end)
    c.compose = control(c.main, CT_CONTROL, 20, 88, 740, 512)
    c.sessions = control(c.main, CT_CONTROL, 20, 88, 740, 512)
    c.status = label(c.main, notice, 20, 610, 740, 28)
    c.status:SetFont("ZoFontGameSmall")
    c.version = label(c.main, L("UI_VERSION", plain(A.version)), 20, 642, 740, 16)
    c.version:SetFont("ZoFontGameSmall")
    c.version:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    buildCompose()
    buildSessions()
    buildIndicator()
    buildRecordingIndicator()
    initialized = true
    U.Refresh()
    return true
end

function U.OnQueueCompleted(postId)
    if not initialized or not composedBatch or composedBatch.postId ~= postId then return end
    local text = composedBatch.text
    composedBatch = nil
    if c.composer:GetText() == text then c.composer:SetText("") end
end

function U.Refresh()
    if not initialized then return end
    c.compose:SetHidden(tab ~= "compose")
    c.sessions:SetHidden(tab ~= "sessions")
    c.composeTab:SetEnabled(tab ~= "compose")
    c.sessionsTab:SetEnabled(tab ~= "sessions")
    local limit, err = A.Chat.GetLimit()
    c.limit:SetText(limit and L("UI_RUNTIME_CHAT_LIMIT", tostring(limit))
        or L("UI_CHAT_LIMIT_UNAVAILABLE", plain(err)))
    local queue = A.Queue
    local count = queue.chunks and #queue.chunks or 0
    local current = queue.current or 0
    c.indicator:SetHidden(not queue.active)
    c.queueTitle:SetText(L(queue.paused and "UI_QUEUE_TITLE_PAUSED" or "UI_QUEUE_TITLE", current, count))
    c.queueReason:SetText(queue.reason and plain(queue.reason) or L("UI_QUEUE_HELP"))
    c.pause:SetText(L(queue.paused and "UI_RESUME" or "UI_PAUSE"))
    c.previous:SetEnabled(queue.active and current > 1)
    c.next:SetEnabled(queue.active)
    c.next:SetText(L(current >= count and "UI_FINISH" or "UI_NEXT"))
    refreshSessions()
    c.status:SetText(plain(notice))
end

function U.Toggle()
    if not initialized then return nil, L("UI_NOT_INITIALIZED") end
    c.main:SetHidden(not c.main:IsHidden())
    U.Refresh()
    return true
end

function U.Notify(message)
    -- No call back into A.Notify: the app logs and forwards notifications here.
    notice = tostring(message or "")
    if initialized then c.status:SetText(plain(notice)) end
end

return U
