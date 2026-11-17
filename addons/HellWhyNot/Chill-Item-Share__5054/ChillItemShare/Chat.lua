local A = ChillItemShare
local math = math
local min, max = math.min, math.max
local now = GetFrameTimeMilliseconds
local WARNING_PAUSE_MS = 60000
local floor = math.floor
local format = string.format
local GetChatSystem = ZO_GetChatSystem
local StartChatInput, later = StartChatInput, zo_callLater
local preHook, postHook = ZO_PreHook, SecurePostHook
local MAX_SAFE_BYTES = 350
local hooks = setmetatable({}, {__mode = "k"})
function A.DelayMilliseconds()
    local seconds = tonumber(A.saved and A.saved.delaySeconds) or 3
    if seconds ~= seconds or seconds == math.huge or seconds == -math.huge then seconds = 3 end
    return floor(min(60, max(0, seconds)) * 1000 + 0.5)
end
function A.SetDelay(value)
    local seconds = tonumber(value)
    if not seconds or seconds ~= seconds or seconds == math.huge or seconds == -math.huge then return end
    A.Invalidate(nil, true)
    A.saved.delaySeconds = floor(min(60, max(0, seconds)) * 100 + 0.5) / 100
    A.nextShareAt = max(A.warningPauseUntil or 0,
        A.lastShareSubmittedAt and A.lastShareSubmittedAt + A.DelayMilliseconds() or 0)
    A.Update()
end
function A.NormalizePrefix(text)
    -- Pre-text is plain text; disallow link/control markup in this field.
    return (tostring(text or ""):gsub("[\r\n\t]", " "):gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end
function A.ChatLimit()
    local chat = GetChatSystem()
    local edit = chat and chat.textEntry and chat.textEntry.editControl
    local limit = edit and edit:GetMaxInputChars() or MAX_SAFE_BYTES
    if not limit or limit < 1 then limit = MAX_SAFE_BYTES end
    -- Raw UTF-8 byte count includes the entire link payload, not just its label.
    return min(limit, MAX_SAFE_BYTES)
end
function A.Pack(parts, limit, prefix)
    prefix = A.NormalizePrefix(prefix)
    local messages, text, hasItem = {}, prefix ~= "" and prefix .. " " or "", false
    for _, part in ipairs(parts) do
        if #part > limit then return nil, "An item link and quantity exceed the chat limit." end
        if hasItem and #text + 1 + #part > limit then
            messages[#messages+1] = text; text, hasItem = "", false
        end
        if not hasItem and #text + #part > limit then
            return nil, "Shorten the pre-text: it and the first item link do not fit together."
        end
        text = text .. (hasItem and " " or "") .. part; hasItem = true
    end
    if hasItem then messages[#messages+1] = text end
    return messages
end
function A.Plan()
    local rows, parts, signature, unavailable = A.SelectionState()
    if unavailable > 0 then
        return nil, format("%d selected stack(s) are in unavailable storage or another house. Open the container, revisit the house, or remove those selections.", unavailable), rows
    end
    if #parts == 0 then return nil, "No share list items selected. Right-click an item and choose Share item.", rows end
    local messages, err = A.Pack(parts, A.ChatLimit(), A.saved.preText)
    if not messages then return nil, err, rows end
    return {messages = messages, signature = signature, index = 1}, nil, rows
end
local function SameDestination(chat, pending)
    return chat.currentChannel == pending.channel and chat.currentTarget == pending.target
end
function A.LoadNext(queue)
    if A.queue ~= queue then return end
    A.Update()
    if A.queue ~= queue then return end
    if queue.index > #queue.messages then
        A.queue, A.pending = nil, nil
        A.Say("Done.")
        if A.RefreshUI then A.RefreshUI() end
        return
    end
    local delay = (A.nextShareAt or 0) - now()
    if delay > 0 then
        if not queue.waiting then
            queue.waiting = true
            later(function()
                queue.waiting = nil
                if A.queue == queue then A.LoadNext(queue) end
            end, delay)
        end
        return
    end
    local chat = GetChatSystem()
    A.chat = chat
    if not chat or not chat.textEntry then A.Invalidate("Chat is unavailable. Use /shareresume when ready.", true); return end
    local entry = chat.textEntry
    if entry:GetText() ~= "" then
        A.Invalidate("Sharing paused to protect your draft. Clear it and use /shareresume.", true); return
    end
    if chat.currentChannel ~= queue.channel or chat.currentTarget ~= queue.target then
        A.Invalidate("Chat destination changed. Return to the original channel and use /shareresume.", true); return
    end
    A.RegisterChatHooks()
    local text = queue.messages[queue.index]
    StartChatInput(text, queue.channel, queue.target)
    -- Catch client truncation or a blocked StartChatInput instead of handing
    -- the player a damaged hyperlink or silently advancing the queue.
    if entry:GetText() ~= text then
        if entry:GetText() ~= "" then entry:SetText("") end
        A.Invalidate(format("Part %d was not prepared. Earlier parts may have been submitted. Use /shareresume to retry this part.", queue.index), true); return
    end
    A.pending = {text = text, channel = queue.channel, target = queue.target, queue = queue, index = queue.index}

end
function A.Post()
    if (A.warningPauseUntil or 0) > now() then
        A.Say("Sharing paused after ESO's spam warning. Please wait a minute.")
        return
    end
    A.Update()
    local chat = GetChatSystem()
    A.chat = chat
    if not chat or not chat.textEntry then A.Say("Chat is not available yet."); return end
    if chat.textEntry:GetText() ~= "" then A.Say("Send or clear your chat draft first."); return end
    A.Invalidate()
    if not chat.currentChannel then chat:SetChannel(chat:GetDefaultChatChannel()) end
    local queue, err = A.Plan()
    if not queue then A.Say(err); return end
    queue.channel, queue.target = chat.currentChannel, chat.currentTarget
    A.queue = queue
    if #queue.messages == 1 then
        A.Say("ONE MESSAGE ONLY. Press Enter when the draft is ready.")
    else
        A.Say(format("%d messages queued. Press Enter for each; delay: %g seconds.", #queue.messages, A.DelayMilliseconds()/1000))
    end
    A.LoadNext(queue)
end
function A.Resume()
    if (A.warningPauseUntil or 0) > now() then
        A.Say("ESO spam-warning pause is still active. Wait before /shareresume."); return
    end
    if A.queue then A.Say("Sharing is already active. Send the current draft or wait for the next part."); return end
    local queue = A.pausedQueue
    if not queue then A.Say("No paused list to resume. Use /sharepost to start a list."); return end
    A.Update()
    local _, _, signature, unavailable = A.SelectionState()
    if unavailable > 0 then A.Say("Reopen the source storage or revisit the source house, then /shareresume."); return end
    if signature ~= queue.signature then
        A.pausedQueue = nil
        A.Say("Selected items changed. Use /sharepost to build a fresh list."); return
    end
    local chat = GetChatSystem()
    if not chat or not chat.textEntry then A.Say("Chat is unavailable. Try /shareresume when ready."); return end
    if chat.textEntry:GetText() ~= "" then A.Say("Clear your chat draft, then /shareresume."); return end
    if chat.currentChannel ~= queue.channel or chat.currentTarget ~= queue.target then
        A.Say("Return to the original chat channel and recipient, then /shareresume."); return
    end
    A.pausedQueue, A.queue = nil, queue
    A.Say(format("Resuming at part %d of %d.", queue.index, #queue.messages))
    A.LoadNext(queue)
end
function A.Advance(pending)
    if not pending or A.pending ~= pending or A.queue ~= pending.queue then return end
    local queue = pending.queue
    A.pending = nil
    queue.index = pending.index + 1
    A.lastShareSubmittedAt = now()
    local gap = A.DelayMilliseconds()
    A.nextShareAt = A.lastShareSubmittedAt + gap
    local delay = queue.index <= #queue.messages and gap or 0
    later(function() if A.queue == queue then A.LoadNext(queue) end end, delay)
end
function A.RegisterChatHooks()
    local chat = GetChatSystem()
    if not chat or hooks[chat] then return end
    hooks[chat] = true
    preHook(chat, "SubmitTextEntry", function(self)
        A.submitting = nil
        local pending = A.pending
        if not pending then return end
        A.Update()
        if A.pending ~= pending then return true end -- inventory changed: do not send a stale draft
        if self.textEntry:GetText() ~= pending.text or not SameDestination(self, pending) then
            A.Invalidate("Sharing paused after a draft or channel change. Use /shareresume to continue.", true)
            return -- allow the player's unrelated/edited message normally
        end
        if not self:ValidateChatChannel() then return end
        A.submitting = pending
    end)
    postHook(chat, "SubmitTextEntry", function()
        local pending = A.submitting
        A.submitting = nil
        if pending and chat.textEntry:GetText() == "" then A.Advance(pending) end
    end)
    -- No chat-echo listener: delayed echoes cannot advance or skip a later part.
end

function A.RegisterSpamGuards()
    local em = EVENT_MANAGER
    local chatSpam = SPAM_WARNING_TYPE_CHAT_MESSAGE
    local rateLimited = SOCIAL_RESULT_RATE_LIMIT_EXCEEDED
    local function Pause()
        local recentSubmit = A.lastShareSubmittedAt and now() - A.lastShareSubmittedAt <= 10000
        if not A.queue and not recentSubmit then return end
        A.warningPauseUntil = now() + WARNING_PAUSE_MS
        A.nextShareAt = max(A.nextShareAt or 0, A.warningPauseUntil)
        A.Invalidate("ESO's spam limit paused sharing. Wait a minute, then use /shareresume.", true)
    end
    em:RegisterForEvent(A.name .. "Spam", EVENT_SPAM_WARNING, function(_, kind)
        if kind == chatSpam then Pause() end
    end)
    em:RegisterForEvent(A.name .. "Rate", EVENT_SOCIAL_ERROR, function(_, result)
        if result == rateLimited then Pause() end
    end)
end
