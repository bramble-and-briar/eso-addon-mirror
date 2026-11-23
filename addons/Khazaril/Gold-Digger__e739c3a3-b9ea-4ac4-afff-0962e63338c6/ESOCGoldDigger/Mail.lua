-- Gold Digger mail sending. One mail per button press, never retried and never sent by itself.
-- Follows the game's own steps: the console privacy check, open the mailbox, send, close it.

local GP = ESOC_GoldDigger
local Mail = {}
GP.Mail = Mail

local TIMEOUT_MS = 10000
local EVENT_NAME = "ESOCGoldDiggerMail"

local job
local jobNumber = 0

local function finish(ok)
    if not job then return end
    local done = job
    job = nil
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_MAIL_INBOX_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_MAIL_SEND_SUCCESS)
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_MAIL_SEND_FAILED)
    if done.opened then pcall(CloseMailbox) end
    pcall(done.callback, ok)
end

local function deliver()
    if not job or job.sent then return end
    job.sent = true
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_MAIL_INBOX_UPDATE)
    if not pcall(SendMail, job.to, job.subject, job.body) then finish(false) end
end

local function openAndSend()
    if not job then return end
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_MAIL_INBOX_UPDATE, deliver)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_MAIL_SEND_SUCCESS, function() finish(true) end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_MAIL_SEND_FAILED, function() finish(false) end)
    job.opened = true
    if not pcall(RequestOpenMailbox) then finish(false) end
end

-- Returns false if another mail is still being sent. The callback gets true or false.
function Mail.Send(to, subject, body, callback)
    if job then return false end
    jobNumber = jobNumber + 1
    local thisJob = jobNumber
    job = { to = to, subject = subject, body = body, callback = callback }
    zo_callLater(function()
        if job and jobNumber == thisJob then finish(false) end
    end, TIMEOUT_MS)

    if ZO_IsConsoleOrGameCoreUI and ZO_IsConsoleOrGameCoreUI() and ZO_ConsoleAttemptCommunicateOrError then
        local ok = pcall(ZO_ConsoleAttemptCommunicateOrError, function(allowed)
            if allowed then openAndSend() else finish(false) end
        end, to, ZO_PLAYER_CONSOLE_INFO_REQUEST_BLOCK, ZO_CONSOLE_CAN_COMMUNICATE_ERROR_DIALOG, ZO_ID_REQUEST_TYPE_DISPLAY_NAME, to)
        if not ok then finish(false) end
    else
        openAndSend()
    end
    return true
end
