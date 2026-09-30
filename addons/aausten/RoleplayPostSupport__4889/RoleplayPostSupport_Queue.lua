local A = RoleplayPostSupport
local L = A.L
local Q = { active = false, paused = false, chunks = {}, current = 0, generation = 0 }
A.Queue = Q
local retired, retiredCount, serial = {}, 0, 0
local confirmed, confirmedCount = {}, 0
local MAX_FINGERPRINTS = 4096

local function trace(event, details)
    if A.Chat and A.Chat.Trace then A.Chat.Trace(event, details) end
end

local function refresh()
    if A.UI then A.UI.Refresh() end
end

local function fingerprint(text, channel, target)
    return tostring(channel) .. "\031" .. A.Sessions.NormalizeName(target) .. "\031" .. text
end

local function retire(attempt)
    if not attempt or retired[attempt.key] then return end
    -- Never expire ambiguous submissions within a login: the API has no message IDs.
    if retiredCount < MAX_FINGERPRINTS then
        retired[attempt.key] = true
        retiredCount = retiredCount + 1
    else
        Q.manualOnly = true
    end
end

local function invalidate()
    Q.generation = Q.generation + 1
    Q.staged = nil
end

function Q.Pause(reason)
    if not Q.active then return nil, L("QUEUE_NOT_ACTIVE") end
    trace("PAUSE", "reason=" .. (reason or L("QUEUE_PAUSED")))
    invalidate()
    Q.paused, Q.reason = true, reason or L("QUEUE_PAUSED")
    refresh()
    return true
end

function Q.Cancel()
    trace("CANCEL", "action=discard-queue-leave-native-input")
    retire(Q.pending)
    invalidate()
    Q.active, Q.paused, Q.pending = false, false, nil
    Q.chunks, Q.current, Q.channel, Q.target = {}, 0, nil, nil
    Q.reason = L("QUEUE_CANCELLED")
    A.Chat.ClearOwnership()
    refresh()
    return true
end

function Q.Stage(automatic)
    if not Q.active or Q.paused or Q.pending then return nil, L("QUEUE_NOT_READY") end
    local text = Q.chunks[Q.current]
    if not text then return nil, L("QUEUE_NO_CHUNK") end
    local ok, err = A.Chat.Prepare(text, Q.channel, Q.target, automatic)
    if not ok then Q.Pause(err); return nil, err end
    Q.staged = { text = text, index = Q.current, generation = Q.generation }
    Q.reason = L("QUEUE_READY")
    trace("STAGED", "automatic=" .. tostring(automatic == true))
    refresh()
    return true
end

function Q.Start(chunks, channel, target)
    if Q.active then return nil, L("QUEUE_ALREADY_ACTIVE") end
    if type(chunks) ~= "table" or #chunks == 0 then return nil, L("QUEUE_EMPTY") end
    local ok, err = A.Chat.ValidateDestination(channel, target)
    if not ok then return nil, err end
    invalidate()
    serial = serial + 1
    Q.postId = tostring(GetTimeStamp()) .. ":" .. tostring(serial)
    confirmed, confirmedCount = {}, 0
    Q.chunks = {}
    for i, text in ipairs(chunks) do Q.chunks[i] = text end
    Q.current, Q.channel, Q.target = 1, channel, target
    Q.active, Q.paused, Q.pending = true, false, nil
    trace("BATCH_START", "channel=" .. tostring(channel) .. " manualOnly=" .. tostring(Q.manualOnly == true))
    return Q.Stage(false)
end

function Q.Resume()
    trace("RESUME", "action=request")
    if not Q.active then return nil, L("QUEUE_NOT_ACTIVE") end
    if Q.pending then
        return nil, L("QUEUE_UNCONFIRMED_SUBMISSION")
    end
    invalidate()
    Q.paused = false
    return Q.Stage(false)
end

function Q.Move(delta)
    if not Q.active then return nil, L("QUEUE_NOT_ACTIVE") end
    if delta ~= 1 and delta ~= -1 then return nil, L("QUEUE_INVALID_MOVE") end
    local index = Q.current + delta
    if index < 1 then return nil, L("QUEUE_FIRST_CHUNK") end
    trace("MANUAL_MOVE", "delta=" .. delta .. " nextIndex=" .. index)
    retire(Q.pending)
    Q.pending = nil
    invalidate()
    if index > #Q.chunks then
        Q.active, Q.paused = false, false
        Q.reason = L("QUEUE_FINISHED_MANUALLY")
        A.Chat.ClearOwnership()
        refresh()
        return true
    end
    Q.current, Q.paused = index, false
    return Q.Stage(false)
end

-- History is not proof of a send, but an unassociated submission may still echo
-- later. Retire it conservatively without assigning queue metadata or advancing.
function Q.ObserveUnassociatedSubmission(text, channel, target)
    if text == "" or text:match("^%s*/") then return end
    trace("SUBMISSION_UNASSOCIATED", "action=remember-without-advancing")
    local key = fingerprint(text, channel, target)
    retire({ key = key })
    if Q.pending and (Q.pending.key == key or Q.manualOnly) then
        Q.pending.ambiguous = true
        Q.Pause(L("QUEUE_AMBIGUOUS_SUBMISSION"))
    end
end

-- Called only inside an observed hardware submission, with its actual edited text.
function Q.ObserveSubmission(text, channel, target)
    if not Q.active or Q.paused or not Q.staged or Q.pending then
        Q.ObserveUnassociatedSubmission(text, channel, target)
        return
    end
    if not A.Chat.SameDestination(channel, target, Q.channel, Q.target) then
        Q.ObserveUnassociatedSubmission(text, channel, target)
        Q.Pause(L("QUEUE_DESTINATION_CHANGED"))
        return
    end
    if text == "" or text:match("^%s*/") then
        Q.Pause(L("QUEUE_INVALID_SUBMISSION"))
        return
    end
    local attempt = {
        text = text, channel = channel, target = target, index = Q.current,
        postId = Q.postId, key = fingerprint(text, channel, target),
    }
    Q.staged, Q.pending = nil, attempt
    Q.reason = L("QUEUE_WAITING_FOR_ECHO")
    trace("SUBMISSION_CAPTURED", "repeated=" .. tostring(retired[attempt.key] == true)
        .. " manualOnly=" .. tostring(Q.manualOnly == true))
    if retired[attempt.key] or Q.manualOnly then
        attempt.ambiguous = true
        Q.Pause(L("QUEUE_AMBIGUOUS_SUBMISSION"))
    end
    refresh()
    zo_callLater(function()
        if Q.active and Q.pending == attempt then
            trace("ECHO_TIMEOUT", "waitMs=10000 action=pause-no-retry")
            Q.Pause(L("QUEUE_ECHO_TIMEOUT"))
        end
    end, 10000)
end

-- Returns metadata only for an observed, unambiguous queued message.
function Q.OnMessage(channel, fromName, text, isCustomerService, fromDisplayName)
    local attempt = Q.pending
    if not Q.active then return end
    if not attempt or attempt.ambiguous or isCustomerService then
        trace("ECHO_IGNORED", "reason=" .. (not attempt and "no-pending-submission"
            or attempt.ambiguous and "ambiguous-submission" or "customer-service"))
        return
    end
    if text ~= attempt.text then
        trace("ECHO_IGNORED", "reason=text-mismatch")
        return
    end
    if not A.Chat.MatchesEcho(attempt, channel, fromName, fromDisplayName) then
        trace("ECHO_IGNORED", "reason=channel-or-identity-mismatch channel=" .. tostring(channel))
        return
    end
    trace("ECHO_CONFIRMED", "matchedChunk=" .. attempt.index)
    local meta = { postId = attempt.postId, chunkIndex = attempt.index,
        chunkCount = #Q.chunks, target = attempt.target }
    retire(attempt)
    if not confirmed[attempt.index] then
        confirmed[attempt.index] = true
        confirmedCount = confirmedCount + 1
    end
    Q.pending = nil
    invalidate()
    Q.current = attempt.index + 1
    A.Debug(L("QUEUE_CONFIRMED_CHUNK", tostring(attempt.index), tostring(#Q.chunks)))
    if Q.current > #Q.chunks then
        Q.current, Q.active, Q.paused = #Q.chunks, false, false
        local allConfirmed = confirmedCount == #Q.chunks
        Q.reason = allConfirmed and L("QUEUE_ALL_CONFIRMED")
            or L("QUEUE_FINAL_CONFIRMED")
        trace("BATCH_COMPLETE", "action=finished-after-confirmed-echo allConfirmed=" .. tostring(allConfirmed))
        A.Chat.ClearOwnership()
        if allConfirmed and A.UI and A.UI.OnQueueCompleted then A.UI.OnQueueCompleted(Q.postId) end
    elseif not Q.paused then
        Q.reason = L("QUEUE_PREPARING_NEXT")
        local generation = Q.generation
        trace("NEXT_SCHEDULED", "delayMs=50 scheduledGeneration=" .. generation)
        zo_callLater(function()
            local eligible = Q.active and not Q.paused and Q.generation == generation
            trace("NEXT_TIMER", "scheduledGeneration=" .. generation .. " action=" .. (eligible and "prepare" or "skip"))
            if eligible then Q.Stage(true) end
        end, 50)
    else
        Q.reason = L("QUEUE_CONFIRMED_WHILE_PAUSED")
    end
    refresh()
    return meta
end
