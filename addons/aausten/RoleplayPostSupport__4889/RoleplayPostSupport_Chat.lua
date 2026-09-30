local A = RoleplayPostSupport
local L = A.L
local C = { Destinations = {} }
A.Chat = C
local attached = setmetatable({}, { __mode = "k" })
local preparing, submitting, owned
local traceSequence, submissionSequence = 0, 0

-- Temporary diagnostics: use local chat output, never Notify/UI refresh or private payloads.
function C.Trace(event, details)
    if not A.saved or not A.saved.debug then return end
    pcall(function()
        traceSequence = traceSequence + 1
        local q = A.Queue or {}
        local time = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds()
            or GetTimeStamp() * 1000
        local batch = q.postId and q.postId:match(":(%d+)$") or "-"
        d(string.format("[RPS TRACE #%04d t=%d B=%s C=%d/%d G=%d] %s%s | active=%s paused=%s staged=%s pending=%s preparing=%s submit=%s owned=%s",
            traceSequence, time, batch, q.current or 0, #(q.chunks or {}), q.generation or 0,
            event, details and (" " .. details) or "", tostring(q.active == true), tostring(q.paused == true),
            tostring(q.staged ~= nil), tostring(q.pending ~= nil), tostring(preparing == true),
            submitting and tostring(submitting.traceId) or "-", tostring(owned ~= nil)))
    end)
end

local function normal(value) return A.Sessions.NormalizeName(value) end
local function system() return ZO_GetChatSystem() end
local function keyboard()
    return not IsInGamepadPreferredMode()
end

function C.Init()
    C.Destinations = {
        { label = L("CHAT_CHANNEL_SAY"), channel = CHAT_CHANNEL_SAY },
        { label = L("CHAT_CHANNEL_EMOTE"), channel = CHAT_CHANNEL_EMOTE },
        { label = L("CHAT_CHANNEL_PARTY"), channel = CHAT_CHANNEL_PARTY },
        { label = L("CHAT_CHANNEL_WHISPER"), channel = CHAT_CHANNEL_WHISPER },
    }
    for i = 1, 5 do
        C.Destinations[#C.Destinations + 1] = { label = L("CHAT_CHANNEL_GUILD", tostring(i)), channel = _G["CHAT_CHANNEL_GUILD_" .. i] }
        C.Destinations[#C.Destinations + 1] = { label = L("CHAT_CHANNEL_OFFICER", tostring(i)), channel = _G["CHAT_CHANNEL_OFFICER_" .. i] }
    end
end

function C.CurrentDestination()
    local chat = system()
    if not chat then return end
    return chat.currentChannel, chat.currentTarget
end

function C.SameDestination(channel, target, expectedChannel, expectedTarget)
    return channel == expectedChannel and (channel ~= CHAT_CHANNEL_WHISPER or normal(target) == normal(expectedTarget))
end

function C.GetLimit()
    local chat = system()
    ---@type number|nil
    local limit = MAX_TEXT_CHAT_INPUT_CHARACTERS
    local entry = chat and chat.textEntry
    local edit = entry and entry:GetEditControl()
    local controlLimit = edit and edit:GetMaxInputChars()
    if type(limit) ~= "number" or limit <= 0 then limit = controlLimit end
    if type(controlLimit) == "number" and controlLimit > 0 and type(limit) == "number" then
        limit = math.min(limit, controlLimit)
    end
    if type(limit) ~= "number" or limit < 1 or limit ~= math.floor(limit) then
        return nil, L("CHAT_LIMIT_UNAVAILABLE")
    end
    return limit
end

function C.ValidateDestination(channel, target)
    local supported = false
    for _, destination in ipairs(C.Destinations) do
        if channel ~= nil and channel == destination.channel then supported = true; break end
    end
    if not supported then return nil, L("CHAT_UNSUPPORTED_DESTINATION") end
    if channel == CHAT_CHANNEL_WHISPER and (normal(target) == "" or target:find("[|\r\n]")) then
        return nil, L("CHAT_INVALID_WHISPER_TARGET")
    end
    local info = ZO_ChatSystem_GetChannelInfo()[channel]
    if not info or (info.requires and not info.requires(channel)) then
        return nil, L("CHAT_CHANNEL_UNAVAILABLE")
    end
    return true
end

function C.ClearOwnership() owned = nil end

function C.MatchesEcho(attempt, channel, fromName, fromDisplayName)
    if attempt.channel == CHAT_CHANNEL_WHISPER then
        if channel ~= CHAT_CHANNEL_WHISPER_SENT then return false end
        local recipient = normal(attempt.target)
        return recipient ~= "" and (recipient == normal(fromName) or recipient == normal(fromDisplayName))
    end
    if channel ~= attempt.channel then return false end
    local account = normal(fromDisplayName)
    if account ~= "" then return account == normal(GetDisplayName()) end
    local sender = normal(fromName)
    return sender ~= "" and (sender == normal(GetDisplayName()) or sender == normal(GetUnitName("player")))
end

-- Read native state only; all population goes through StartChatInput. These hooks
-- observe stock keyboard submission without replacing a router or formatter.
function C.EnsureHooks()
    if not keyboard() then return nil, L("CHAT_KEYBOARD_REQUIRED") end
    local chat = system()
    local entry = chat and chat.textEntry
    if not chat or not entry or type(entry.AddCommandHistory) ~= "function" or type(chat.SubmitTextEntry) ~= "function" then
        return nil, L("CHAT_OBSERVATION_UNAVAILABLE")
    end
    local state = attached[chat]
    if not state then
        state = {}
        attached[chat] = state
        SecurePostHook(chat, "StartTextEntry", function()
            C.Trace("INPUT_OPEN", "action=" .. (preparing and "ignore-prepare" or A.Queue.active and "pause" or "idle"))
            if not preparing then
                owned = nil
                if A.Queue.active then A.Queue.Pause(L("CHAT_INPUT_REOPENED")) end
            end
        end)
        SecurePostHook(chat, "CloseTextEntry", function(_, keepText)
            C.Trace("INPUT_CLOSE", "keepText=" .. tostring(keepText == true) .. " action="
                .. (preparing and "ignore-prepare" or submitting and "ignore-submit" or A.Queue.active and "pause" or "idle"))
            if not preparing and not submitting then
                owned = nil
                if A.Queue.active then A.Queue.Pause(L("CHAT_INPUT_CLOSED")) end
            end
        end)
        SecurePostHook(chat, "SetChannel", function()
            C.Trace("CHANNEL_CHANGE", "channel=" .. tostring(chat.currentChannel) .. " routeMatchesQueue="
                .. tostring(C.SameDestination(chat.currentChannel, chat.currentTarget, A.Queue.channel, A.Queue.target)))
            if not preparing and A.Queue.active and not C.SameDestination(chat.currentChannel,
                chat.currentTarget, A.Queue.channel, A.Queue.target) then
                owned = nil
                A.Queue.Pause(L("CHAT_DESTINATION_CHANGED"))
            end
        end)
    end
    -- Stock submission closes the entry directly, bypassing CloseTextEntry.
    -- This additional observer is trace-only: it never pauses or changes ownership.
    if type(entry.Close) == "function" and state.close ~= entry.Close then
        state.closeVersion = (state.closeVersion or 0) + 1
        local version = state.closeVersion
        C.Trace("HOOK_CLOSE_ATTACH", "version=" .. version .. " submissionOpen=" .. tostring(submitting ~= nil))
        SecurePostHook(entry, "Close", function(_, keepText)
            if state.closeVersion == version then
                C.Trace("ENTRY_CLOSE", "hook=" .. version .. " keepText=" .. tostring(keepText == true)
                    .. " origin=" .. (preparing and "preparing" or submitting and "submitting" or "external"))
            end
        end)
        state.close = entry.Close
    end
    -- pChat overrides history and prehooks SubmitTextEntry. Install lazily, after
    -- addon startup, and observe the final method's incoming text, not its storage.
    if state.history ~= entry.AddCommandHistory then
        state.historyVersion = (state.historyVersion or 0) + 1
        local version = state.historyVersion
        C.Trace("HOOK_HISTORY_ATTACH", "version=" .. version .. " submissionOpen=" .. tostring(submitting ~= nil))
        SecurePostHook(entry, "AddCommandHistory", function(_, text)
            if state.historyVersion == version and submitting and submitting.chat == chat and not preparing then
                submitting.traceHistories = submitting.traceHistories + 1
                if submitting.associate and A.Queue.staged == submitting.staged then
                    submitting.traceAssociated = submitting.traceAssociated + 1
                    C.Trace("HISTORY_CALLBACK", "hook=" .. version .. " action=associate")
                    A.Queue.ObserveSubmission(text, chat.currentChannel, chat.currentTarget)
                else
                    C.Trace("HISTORY_CALLBACK", "hook=" .. version .. " action=unassociated reason="
                        .. (not submitting.associate and "ineligible-submit" or "stage-changed"))
                    A.Queue.ObserveUnassociatedSubmission(text, chat.currentChannel, chat.currentTarget)
                end
            else
                local reason = state.historyVersion ~= version and "obsolete-hook" or not submitting and "no-submission"
                    or submitting.chat ~= chat and "wrong-system" or "preparing"
                C.Trace("HISTORY_CALLBACK", "hook=" .. version .. " action=ignore reason=" .. reason)
            end
        end)
        state.history = entry.AddCommandHistory
    end
    if state.submit ~= chat.SubmitTextEntry then
        state.submitVersion = (state.submitVersion or 0) + 1
        local version = state.submitVersion
        C.Trace("HOOK_SUBMIT_ATTACH", "version=" .. version .. " submissionOpen=" .. tostring(submitting ~= nil))
        ZO_PreHook(chat, "SubmitTextEntry", function()
            if state.submitVersion ~= version then
                C.Trace("SUBMIT_BEGIN_IGNORED", "hook=" .. version .. " reason=obsolete-hook")
                return
            end
            -- Observe all submissions for ambiguity, but associate only an eligible
            -- hardware submission with the stage that existed at its start.
            local inKeyboard = keyboard()
            local hardware = inKeyboard and WINDOW_MANAGER:IsHandlingHardwareEvent()
            submissionSequence = submissionSequence + 1
            submitting = { chat = chat, staged = A.Queue.staged, owned = owned, previous = submitting,
                associate = inKeyboard and hardware and A.Queue.active and not A.Queue.paused and A.Queue.staged ~= nil,
                traceId = submissionSequence, traceHistories = 0, traceAssociated = 0 }
            local reason = not inKeyboard and "gamepad" or not hardware and "not-hardware"
                or not A.Queue.active and "inactive" or A.Queue.paused and "paused"
                or not A.Queue.staged and "no-stage" or "eligible"
            C.Trace("SUBMIT_BEGIN", "id=" .. submissionSequence .. " hook=" .. version .. " hardware="
                .. tostring(hardware) .. " keyboard=" .. tostring(inKeyboard) .. " associate="
                .. tostring(submitting.associate) .. " reason=" .. reason .. " nested=" .. tostring(submitting.previous ~= nil))
            -- No truthy return: never suppress or initiate the native submission.
        end)
        SecurePostHook(chat, "SubmitTextEntry", function()
            if state.submitVersion == version and submitting and submitting.chat == chat then
                local finished = submitting
                C.Trace("SUBMIT_END", "id=" .. finished.traceId .. " hook=" .. version .. " histories="
                    .. finished.traceHistories .. " associated=" .. finished.traceAssociated .. " stageUnchanged="
                    .. tostring(finished.staged ~= nil and A.Queue.staged == finished.staged))
                submitting = finished.previous
                -- A native command may have prepared a new chunk before returning.
                if owned == finished.owned then owned = nil end
                if A.Queue.active and finished.staged and A.Queue.staged == finished.staged then
                    A.Queue.Pause(L("CHAT_SUBMISSION_UNOBSERVABLE"))
                end
            else
                C.Trace("SUBMIT_END_IGNORED", "hook=" .. version .. " reason="
                    .. (state.submitVersion ~= version and "obsolete-hook" or not submitting and "no-submission" or "wrong-system"))
            end
        end)
        state.submit = chat.SubmitTextEntry
    end
    return true
end

function C.Prepare(text, channel, target, automatic)
    C.Trace("PREPARE_BEGIN", "automatic=" .. tostring(automatic == true) .. " channel=" .. tostring(channel))
    local ok, err = C.EnsureHooks()
    if not ok then C.Trace("PREPARE_REJECT", "reason=observation-unavailable"); return nil, err end
    ok, err = C.ValidateDestination(channel, target)
    if not ok then C.Trace("PREPARE_REJECT", "reason=destination-unavailable"); return nil, err end
    local limit = C.GetLimit()
    local length = A.Splitter.Length(text)
    local body = A.Splitter.StripMessageTag(text)
    if not limit or not length or length > limit or body == "" or body:match("^%s*/") or text:find("[|\r\n]") then
        C.Trace("PREPARE_REJECT", "reason=unsafe-chunk-or-limit")
        return nil, L("CHAT_UNSAFE_CHUNK")
    end
    local chat = system()
    if not chat or not chat.textEntry then
        C.Trace("PREPARE_REJECT", "reason=native-chat-unavailable")
        return nil, L("CHAT_NATIVE_UNAVAILABLE")
    end
    if automatic and not C.SameDestination(chat.currentChannel, chat.currentTarget, channel, target) then
        C.Trace("PREPARE_REJECT", "reason=destination-changed")
        return nil, L("CHAT_DESTINATION_CHANGED_WAITING")
    end
    local existing = chat.textEntry:GetText()
    if existing ~= "" and not (owned and owned.chat == chat and existing == owned.text
        and C.SameDestination(chat.currentChannel, chat.currentTarget, owned.channel, owned.target)) then
        C.Trace("PREPARE_REJECT", "reason=unowned-or-edited-draft")
        return nil, L("CHAT_EXISTING_DRAFT")
    end
    preparing = true
    StartChatInput(text, channel, target)
    preparing = false
    if system() ~= chat or not chat.textEntry:IsOpen() or chat.textEntry:GetText() ~= text
        or not C.SameDestination(chat.currentChannel, chat.currentTarget, channel, target) then
        C.Trace("PREPARE_REJECT", "reason=readback-mismatch")
        owned = nil
        return nil, L("CHAT_STAGE_MISMATCH")
    end
    owned = { chat = chat, text = text, channel = channel, target = target }
    C.Trace("PREPARE_READY", "automatic=" .. tostring(automatic == true))
    return true
end

function C.OnMessage(_, channel, fromName, text, isCustomerService, fromDisplayName)
    local meta = A.Queue.OnMessage(channel, fromName, text, isCustomerService, fromDisplayName)
    if A.Sessions.Capture(channel, fromName, text, isCustomerService, fromDisplayName, meta) then
        if A.UI then A.UI.Refresh() end
    end
end
