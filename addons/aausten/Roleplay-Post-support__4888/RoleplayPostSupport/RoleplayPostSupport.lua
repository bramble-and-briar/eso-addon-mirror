RoleplayPostSupport = RoleplayPostSupport or {}
local A = RoleplayPostSupport
local function L(...) return A.L(...) end
A.name, A.version = "RoleplayPostSupport", "1.2.2"
local ready = false

function A.Notify(message)
    -- Error/status messages only. Never echo a private draft into the chat log.
    d("[RoleplayPostSupport] " .. tostring(message):gsub("|", ""))
    if A.UI then A.UI.Notify(message) end
end

function A.Debug(message)
    if A.saved and A.saved.debug then A.Notify(L("CORE_DEBUG_MESSAGE", message)) end
end

function A.ApplySettings(maxChars, prefix, suffix, sentences)
    local limit, err = A.Chat.GetLimit()
    if not limit then return nil, err end
    if type(maxChars) ~= "number" or maxChars <= A.Splitter.MESSAGE_TAG_LENGTH or maxChars > limit or maxChars ~= math.floor(maxChars) then
        return nil, L("CORE_INVALID_MAX_LENGTH", tostring(A.Splitter.MESSAGE_TAG_LENGTH + 1), tostring(limit))
    end
    if type(prefix) ~= "string" or type(suffix) ~= "string" or type(sentences) ~= "boolean" then
        return nil, L("CORE_INVALID_PREFERENCES")
    end
    local options = { maxChars = maxChars - A.Splitter.MESSAGE_TAG_LENGTH,
        prefix = prefix, suffix = suffix, sentences = sentences }
    local chunks
    chunks, err = A.Splitter.Split(string.rep("x", maxChars * 3), options)
    if not chunks then return nil, err end
    A.saved.maxChars, A.saved.prefix, A.saved.suffix, A.saved.sentences = maxChars, prefix, suffix, sentences
    return true
end

function A.Preview(text)
    local limit, err = A.Chat.GetLimit()
    if not limit then return nil, err end
    local body = A.Splitter.StripMessageTag(text)
    return A.Splitter.Split(body, {
        maxChars = math.min(A.saved.maxChars or limit, limit) - A.Splitter.MESSAGE_TAG_LENGTH,
        prefix = A.saved.prefix, suffix = A.saved.suffix, sentences = A.saved.sentences,
    })
end

function A.Start(text, channel, target)
    local chunks, err = A.Preview(text)
    if not chunks then return nil, err end
    for index, chunk in ipairs(chunks) do chunks[index] = A.Splitter.MESSAGE_TAG .. chunk end
    if channel == CHAT_CHANNEL_WHISPER then
        target = (target or ""):gsub("^%s+", ""):gsub("%s+$", "")
    else
        target = nil
    end
    return A.Queue.Start(chunks, channel, target)
end

function A.Test()
    -- In-client smoke test only: deliberately has no chat-adapter/queue calls.
    local cases = {
        { "Short post.", 1 }, { string.rep("x", 40), 1 },
        { string.rep("x", 41), 2 }, { string.rep("word ", 100) },
        { string.rep("é—“ñ”… ", 30) }, { "First paragraph.\n\n" .. string.rep("Next paragraph. ", 10) },
    }
    for _, case in ipairs(cases) do
        local chunks, err = A.Splitter.Split(case[1], { maxChars = 40 })
        if not chunks then A.Notify(L("CORE_TEST_FAILED", err)); return end
        if case[2] and #chunks ~= case[2] then A.Notify(L("CORE_TEST_WRONG_COUNT")); return end
        for _, chunk in ipairs(chunks) do
            local length = A.Splitter.Length(chunk)
            if not length or length > 40 then A.Notify(L("CORE_TEST_UNSAFE_LENGTH")); return end
        end
    end
    A.Notify(L("CORE_TEST_PASSED"))
end

local function slash(argument)
    if not ready then A.Notify(L("CORE_WAITING_FOR_UI")); return end
    local command = (argument or ""):lower():match("^%s*(.-)%s*$")
    if command == "" then A.UI.Toggle()
    elseif command == "test" then A.Test()
    elseif command == "debug" then
        A.saved.debug = not A.saved.debug
        A.Notify(L(A.saved.debug and "CORE_DEBUG_ENABLED" or "CORE_DEBUG_DISABLED",
            tostring(GetAPIVersion()), tostring(A.Chat.GetLimit())))
    elseif command == "cancel" then A.Queue.Cancel()
    else
        local actions = {
            pause = A.Queue.Pause, resume = A.Queue.Resume,
            next = function() return A.Queue.Move(1) end,
            previous = function() return A.Queue.Move(-1) end,
        }
        if actions[command] then
            local ok, err = actions[command]()
            if not ok then A.Notify(err) end
        else
            A.Notify(L("CORE_COMMAND_HELP"))
        end
    end
end

local function activated()
    if ready then return end
    A.Chat.Init()
    local limit, err = A.Chat.GetLimit()
    if limit then
        local ok = A.ApplySettings(A.saved.maxChars or limit, A.saved.prefix, A.saved.suffix, A.saved.sentences)
        if not ok then
            A.saved.maxChars, A.saved.prefix, A.saved.suffix, A.saved.sentences = limit, "+ ", " +", true
            A.Notify(L("CORE_PREFERENCES_RESET"))
        end
    else
        A.Notify(err)
    end
    ready = true
    A.UI.Init()
    EVENT_MANAGER:RegisterForEvent(A.name, EVENT_CHAT_MESSAGE_CHANNEL, A.Chat.OnMessage)
    EVENT_MANAGER:RegisterForEvent(A.name, EVENT_PLAYER_DEACTIVATED, function()
        if A.Queue.active then A.Queue.Pause(L("CORE_PLAYER_DEACTIVATED")) end
        A.Sessions.SetRecording(false)
        A.UI.Refresh()
    end)
    EVENT_MANAGER:UnregisterForEvent(A.name, EVENT_PLAYER_ACTIVATED)
    local api = GetAPIVersion()
    if api ~= 101050 and api ~= 101051 then
        A.Notify(L("CORE_UNSUPPORTED_API", tostring(api)))
    end
    A.Debug(L("CORE_INITIALIZED", tostring(limit)))
end

EVENT_MANAGER:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= A.name then return end
    EVENT_MANAGER:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)
    -- ESO requires SavedVars construction during the add-on-loaded event to save it.
    local defaults = { prefix = "+ ", suffix = " +", sentences = true, debug = false,
        historyNewestFirst = false, window = {} }
    A.saved = ZO_SavedVars:NewAccountWide("RoleplayPostSupportSavedVariables", 1, nil, defaults, GetWorldName())
    A.Sessions.Init(A.saved)
    SLASH_COMMANDS["/rps"] = slash
    EVENT_MANAGER:RegisterForEvent(A.name, EVENT_PLAYER_ACTIVATED, activated)
end)
