-- Run from the repository root: python3 tests/run.py tests/queue_chat_spec.lua
-- Lua 5.1-compatible, deterministic virtual time; never loaded by the addon.
-- These are contract tests, not expected-failure tests: real regressions fail.
local localization = dofile("tests/localization_fixture.lua")
local unpack = unpack or rawget(table, "unpack")
local function pack(...) return { n = select("#", ...), ... } end
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected "
        .. tostring(expected) .. ", got " .. tostring(actual))
end
local function rejected(ok, err)
    assert(not ok, "operation should have been refused")
    assert(type(err) == "string" and err ~= "", "refusal should explain recovery")
end

CHAT_CHANNEL_SAY, CHAT_CHANNEL_EMOTE, CHAT_CHANNEL_PARTY = 0, 13, 19
CHAT_CHANNEL_WHISPER, CHAT_CHANNEL_WHISPER_SENT = 31, 32
CHAT_CHANNEL_ZONE, CHAT_CHANNEL_SYSTEM = 23, 99
EVENT_CHAT_MESSAGE_CHANNEL, EVENT_ADD_ON_LOADED = 501, 502
for i = 1, 5 do
    _G["CHAT_CHANNEL_GUILD_" .. i] = 200 + i * 3
    _G["CHAT_CHANNEL_OFFICER_" .. i] = 300 + i * 3
end

local function fixture(translations)
    local f = { now = 0, timers = {}, sequence = 0, hardware = false,
        gamepad = false, available = true, allowStart = true, allowed = {},
        stages = {}, submits = 0, requested = 0, sent = {}, trace = {}, commands = {},
        echoMode = "none", echoDelay = 100, violations = 0, debugLog = {}, uiRefreshes = 0 }
    local entry = { text = "", open = false, history = {}, maxChars = 350 }
    local chat = { textEntry = entry, currentChannel = CHAT_CHANNEL_SAY }
    f.entry, f.chat = entry, chat
    local function trace(value) f.trace[#f.trace + 1] = value end
    local function violation(message)
        f.violations = f.violations + 1
        error(message, 2)
    end

    -- Real wrappers: prehooks may suppress; posthooks see ORIGINAL arguments,
    -- only AFTER the wrapped method returns, and cannot suppress its effects.
    local function hookArguments(object, name, callback)
        if type(object) == "string" then return _G, object, name end
        return object, name, callback
    end
    ZO_PreHook = function(object, name, callback)
        object, name, callback = hookArguments(object, name, callback)
        local original = object[name]
        assert(type(original) == "function", "missing prehook method " .. name)
        object[name] = function(...)
            if not callback(...) then return original(...) end
        end
        return original
    end
    SecurePostHook = function(object, name, callback)
        object, name, callback = hookArguments(object, name, callback)
        local original = object[name]
        assert(type(original) == "function", "missing posthook method " .. name)
        object[name] = function(...)
            local results = pack(original(...))
            trace("post:" .. name)
            callback(...)
            return unpack(results, 1, results.n)
        end
    end

    zo_callLater = function(callback, delay)
        assert(type(callback) == "function" and delay >= 0)
        f.sequence = f.sequence + 1
        f.timers[#f.timers + 1] = { at = f.now + delay, id = f.sequence, run = callback }
    end
    function f:advance(milliseconds)
        assert(milliseconds >= 0)
        local untilTime, iterations = self.now + milliseconds, 0
        while true do
            table.sort(self.timers, function(a, b)
                return a.at < b.at or (a.at == b.at and a.id < b.id)
            end)
            local timer = self.timers[1]
            if not timer or timer.at > untilTime then break end
            table.remove(self.timers, 1)
            self.now = timer.at
            iterations = iterations + 1
            assert(iterations < 1000, "runaway timer loop")
            timer.run()
        end
        self.now = untilTime
    end

    local handlers = {}
    local eventManager = {}
    function eventManager:RegisterForEvent(namespace, event, callback)
        handlers[event] = handlers[event] or {}
        handlers[event][namespace] = callback
    end
    function eventManager:UnregisterForEvent(namespace, event)
        if handlers[event] then handlers[event][namespace] = nil end
    end
    EVENT_MANAGER = eventManager
    function f:emit(channel, name, text, account, customerService)
        trace("echo")
        for _, callback in pairs(handlers[EVENT_CHAT_MESSAGE_CHANNEL] or {}) do
            callback(EVENT_CHAT_MESSAGE_CHANNEL, channel, name, text, customerService or false, account)
        end
    end
    function f:ownEcho(text, channel, target)
        channel = channel or chat.currentChannel
        if channel == CHAT_CHANNEL_WHISPER then
            self:emit(CHAT_CHANNEL_WHISPER_SENT, target or chat.currentTarget, text, "")
        else
            self:emit(channel, "Local Hero^Mx", text, "@Local")
        end
    end

    WINDOW_MANAGER = { IsHandlingHardwareEvent = function() return f.hardware end }
    IsInGamepadPreferredMode = function() return f.gamepad end
    GetTimeStamp = function() return 1700000000 + math.floor(f.now / 1000) end
    GetFrameTimeMilliseconds = function() return f.now end
    d = function(message)
        assert(type(message) == "string", "debug output must be a string")
        f.debugLog[#f.debugLog + 1] = message
    end
    GetDisplayName = function() return "@Local" end
    GetUnitName = function(unit) equal(unit, "player"); return "Local Hero^Mx" end
    zo_strformat = function(template, name)
        equal(template, "<<1>>")
        return (name:gsub("%^%a+$", ""))
    end
    MAX_TEXT_CHAT_INPUT_CHARACTERS = 350
    local info = {}
    local channels = { CHAT_CHANNEL_SAY, CHAT_CHANNEL_EMOTE, CHAT_CHANNEL_PARTY, CHAT_CHANNEL_WHISPER }
    for i = 1, 5 do
        channels[#channels + 1] = _G["CHAT_CHANNEL_GUILD_" .. i]
        channels[#channels + 1] = _G["CHAT_CHANNEL_OFFICER_" .. i]
    end
    for _, channel in ipairs(channels) do
        info[channel] = { requires = function(actual)
            equal(actual, channel, "channel requirement argument")
            return f.allowed[actual] ~= false
        end }
    end
    f.info = info
    ZO_ChatSystem_GetChannelInfo = function() return info end
    ZO_GetChatSystem = function() return chat end
    function entry:GetText() return self.text end
    function entry:SetText(text) self.text = text end
    function entry:IsOpen() return self.open end
    function entry:GetEditControl() return self end
    function entry:GetMaxInputChars() return self.maxChars end
    function entry:Open(text)
        if text and text ~= "" then self:SetText(text) end
        self.open = true
    end
    function entry:Close(keepText)
        trace("close")
        if not keepText then self:SetText("") end
        self.open = false
        -- Some integrations route entry closure back through the chat system.
        -- Re-enter once so the real CloseTextEntry posthook runs during submit.
        if f.closeThroughChat and not f.closingThroughChat then
            f.closingThroughChat = true
            chat:CloseTextEntry(keepText)
            f.closingThroughChat = false
        end
    end
    function entry:AddCommandHistory(text)
        trace("history")
        self.history[#self.history + 1] = text
    end
    function chat:SetChannel(channel, target)
        self.currentChannel, self.currentTarget = channel, target
    end
    function chat:StartTextEntry(text, channel, target)
        if not f.allowStart or not f.available then return end
        if channel ~= nil then self:SetChannel(channel, target) end
        entry:Open(text)
    end
    function chat:CloseTextEntry(keepText) entry:Close(keepText) end
    function chat:ValidateChatChannel()
        local destination = info[self.currentChannel]
        if not destination or (destination.requires and not destination.requires(self.currentChannel)) then
            self:SetChannel(CHAT_CHANNEL_SAY)
            return false
        end
        return true
    end
    SendChatMessage = function(text, channel, target)
        if not f.inNativeSend then violation("addon initiated SendChatMessage") end
        trace("send")
        f.sent[#f.sent + 1] = { text = text, channel = channel, target = target }
        if f.echoMode == "sync" then
            f:ownEcho(text, channel, target)
        elseif f.echoMode == "delayed" then
            zo_callLater(function() f:ownEcho(text, channel, target) end, f.echoDelay)
        end
    end
    function chat:SubmitTextEntry()
        f.submits = f.submits + 1
        if not f.userSubmission or f.submits ~= f.requested then
            violation("addon initiated SubmitTextEntry (only the fixture's explicit user action may do so)")
        end
        trace("submit")
        local text = entry:GetText()
        -- Stock uses entry:Close(), NOT chat:CloseTextEntry(). History receives
        -- the saved text after clearing, before validation and SendChatMessage.
        entry:Close()
        if f.available and #text > 0 then
            entry:AddCommandHistory(text)
            -- Only command/non-command routing is needed here, not ESO's full parser.
            if text:match("^%s*/") then
                local command, argument = text:match("^%s*(/%S+)%s*(.*)$")
                if f.commands[command] then
                    trace("command")
                    f.commands[command](argument)
                end
            elseif self:ValidateChatChannel() then
                f.inNativeSend = true
                SendChatMessage(text, self.currentChannel, self.currentTarget)
                f.inNativeSend = false
            end
        else
            self:ValidateChatChannel()
        end
    end
    ZO_ChatSystem_SubmitChat = function() chat:SubmitTextEntry() end
    StartChatInput = function(text, channel, target)
        f.stages[#f.stages + 1] = { text = text, channel = channel, target = target }
        chat:StartTextEntry(text, channel, target)
    end
    function f:submit(hardware)
        self.requested = self.requested + 1
        self.userSubmission, self.hardware = true, hardware ~= false
        local ok, err = pcall(function() chat:SubmitTextEntry() end)
        self.userSubmission, self.hardware, self.inNativeSend = false, false, false
        assert(ok, err)
        equal(self.submits, self.requested, "native submission not suppressed or repeated")
    end
    function f:pchat()
        local original = entry.AddCommandHistory
        function entry:AddCommandHistory(text)
            local switch = chat.currentChannel == CHAT_CHANNEL_WHISPER and "/w " .. chat.currentTarget or "/say"
            original(self, switch .. " " .. text)
        end
        ZO_PreHook(chat, "SubmitTextEntry", function()
            entry:SetText((entry:GetText():gsub(":wave:", "waves warmly")))
            -- pChat expands before stock captures the text, but does not submit.
        end)
    end

    RoleplayPostSupport = { saved = { debug = false }, Debug = function(_message) end,
        UI = { Refresh = function() f.uiRefreshes = f.uiRefreshes + 1 end } }
    f.localization = localization.load(translations)
    dofile("RoleplayPostSupport_Splitter.lua")
    dofile("RoleplayPostSupport_Sessions.lua")
    dofile("RoleplayPostSupport_Chat.lua")
    dofile("RoleplayPostSupport_Queue.lua")
    f.A, f.Q, f.C, f.S = RoleplayPostSupport, RoleplayPostSupport.Queue, RoleplayPostSupport.Chat, RoleplayPostSupport.Sessions
    f.C.Init()
    assert(f.S.Init({}))
    -- Wire the real callback as startup would without loading the bootstrap.
    EVENT_MANAGER:RegisterForEvent("RoleplayPostSupportTest", EVENT_CHAT_MESSAGE_CHANNEL, f.C.OnMessage)
    function f:loadMain()
        -- Load the real public entry points without firing SavedVars/UI startup.
        -- Direct Queue.Start fixtures remain wire-ready and need no bootstrap.
        dofile("RoleplayPostSupport.lua")
    end
    function f:start(chunks, channel, target)
        assert(self.Q.Start(chunks or { "first", "second" }, channel or CHAT_CHANNEL_SAY, target))
    end
    function f:checkNoAutomaticSend()
        equal(self.violations, 0, "unsolicited native API calls")
        equal(self.submits, self.requested, "only explicit submissions")
        assert(#self.sent <= self.requested, "addon sent extra messages")
    end
    return f
end

local tests = {}
local function test(name, body) tests[#tests + 1] = { name, body } end

test("hook wrappers run in order and preserve arguments and results", function()
    local order = {}
    local object = { method = function(self, value)
        equal(self.marker, true); equal(value, "input")
        order[#order + 1] = "native"
        return 7, nil, "last"
    end, marker = true }
    ZO_PreHook(object, "method", function() order[#order + 1] = "pre" end)
    SecurePostHook(object, "method", function(self, value)
        equal(self, object); equal(value, "input")
        order[#order + 1] = "post"
        return true -- Must not replace the native result.
    end)
    local result = pack(object:method("input"))
    equal(table.concat(order, ","), "pre,native,post")
    equal(result.n, 3); equal(result[1], 7); equal(result[2], nil); equal(result[3], "last")
    ZO_PreHook(object, "method", function() return true end)
    object:method("suppressed")
    equal(#order, 3)
end)

test("Start only stages editable native input; Enter observes the edited text", function(f)
    f:start()
    equal(f.submits, 0); equal(#f.sent, 0); equal(#f.entry.history, 0)
    equal(f.entry:GetText(), "first"); assert(f.entry:IsOpen())
    equal(f.Q.current, 1); equal(f.Q.pending, nil); assert(f.Q.staged)
    f.entry:SetText("edited by the player")
    f:submit()
    equal(f.entry:GetText(), ""); equal(f.entry:IsOpen(), false)
    equal(f.entry.history[1], "edited by the player")
    equal(f.sent[1].text, "edited by the player")
    equal(f.Q.pending.text, "edited by the player"); equal(f.Q.current, 1)
    equal(#f.stages, 1)
    f:ownEcho("first")
    assert(f.Q.pending, "staged text must not confirm edited submission")
    f:ownEcho("edited by the player")
    equal(f.Q.pending, nil); equal(f.Q.current, 2)
    f:advance(49); equal(#f.stages, 1)
    f:advance(1); equal(f.entry:GetText(), "second"); equal(#f.stages, 2)
    equal(f.submits, 1); equal(#f.sent, 1)
end)

for _, recording in ipairs({ false, true }) do
    for _, addonOnly in ipairs({ false, true }) do
        local recordEnabled, filterEnabled = recording, addonOnly
        test("A.Start tags every Unicode chunk: recording=" .. tostring(recordEnabled)
            .. " addonOnly=" .. tostring(filterEnabled), function(f)
            f:loadMain()
            local session = assert(f.S.Create("Tagged post", CHAT_CHANNEL_SAY))
            assert(f.S.Select(session.id)); assert(f.S.SetAddonOnly(filterEnabled))
            assert(f.S.SetRecording(recordEnabled))
            assert(f.A.ApplySettings(12, "é ", " →", false))
            f.entry.maxChars = 9 -- Runtime clamp includes tag and continuation markers.
            local tag = f.A.Splitter.MESSAGE_TAG
            local expected = { "é猫😀 →", "é ñ →", "é ø →", "é abç" }
            local preview = assert(f.A.Preview("é猫😀ñøabç"))
            equal(#preview, #expected)
            assert(f.A.Start("é猫😀ñøabç", CHAT_CHANNEL_SAY))
            equal(#session.messages, 0); equal(f.submits, 0)
            equal(#f.Q.chunks, #expected)
            local postId = f.Q.postId
            f.echoMode = "sync"
            for index, body in ipairs(expected) do
                equal(preview[index], body, "preview is untagged")
                equal(f.Q.chunks[index], tag .. body, "every queued chunk is tagged")
                equal(f.entry:GetText(), tag .. body, "exact native wire text")
                equal(f.A.Splitter.Length(f.entry:GetText()), 9, "tag plus Unicode body at native limit")
                equal(#f.sent, index - 1, "staging never sends")
                f:submit()
                equal(f.sent[index].text, tag .. body)
                if recordEnabled then
                    local record = session.messages[index]
                    equal(record.text, body); equal(record.addonMarked, true)
                    equal(record.outgoing, true); equal(record.postId, postId)
                    equal(record.chunkIndex, index); equal(record.chunkCount, #expected)
                end
                f:advance(50)
                equal(#f.sent, index, "continuation only prepares")
            end
            equal(#session.messages, recordEnabled and #expected or 0)
            equal(f.Q.active, false); equal(f.Q.paused, false)
            f:advance(20000)
            equal(#f.stages, #expected); equal(#f.sent, #expected)
        end)
    end
end

test("A.Start copied tagged draft has no doubled initial marker and respects saved budget", function(f)
    f:loadMain()
    assert(f.A.ApplySettings(9, "", "", false))
    f.entry.maxChars = 12
    local tag = f.A.Splitter.MESSAGE_TAG
    local draft = tag .. "é猫😀ñøab"
    local preview = assert(f.A.Preview(draft))
    equal(#preview, 2); equal(preview[1], "é猫😀ñø"); equal(preview[2], "ab")
    assert(f.A.Start(draft, CHAT_CHANNEL_SAY))
    equal(#f.Q.chunks, 2)
    f.echoMode = "sync"
    for index, body in ipairs(preview) do
        equal(f.Q.chunks[index], tag .. body)
        equal(f.entry:GetText(), tag .. body)
        assert(f.A.Splitter.Length(f.entry:GetText()) <= 9)
        f:submit(); f:advance(50)
        equal(f.sent[index].text, tag .. body)
    end
    equal(preview[1], "é猫😀ñø", "Start does not tag an earlier preview")
    equal(f.Q.active, false); equal(#f.sent, 2)
end)

test("tagged edited outgoing echo needs exact raw payload and identity before clean archival", function(f)
    f:loadMain()
    assert(f.A.ApplySettings(9, "", "", false))
    local session = assert(f.S.Create("Exact echo", CHAT_CHANNEL_SAY))
    assert(f.S.Select(session.id)); assert(f.S.SetParticipants("Friend Hero"))
    assert(f.S.SetAddonOnly(true)); assert(f.S.SetRecording(true))
    local tag = f.A.Splitter.MESSAGE_TAG
    assert(f.A.Start("abcdefghij", CHAT_CHANNEL_SAY))
    local postId, edited = f.Q.postId, tag .. "é猫😀!"
    equal(#session.messages, 0)
    f.entry:SetText(edited); f:submit()
    equal(f.sent[1].text, edited); equal(f.Q.pending.text, edited)
    equal(#session.messages, 0, "submission alone is not an archive event")
    local pending = f.Q.pending
    f:ownEcho("é猫😀!") -- The readable body alone cannot confirm the tagged payload.
    f:ownEcho("\226\128\139" .. "é猫😀!")
    equal(#session.messages, 0, "unmarked own echoes fail addon-only filtering")
    equal(f.Q.pending, pending)
    f:emit(CHAT_CHANNEL_SAY, "Friend Hero^Fx", edited, "@Friend")
    equal(#session.messages, 1)
    local remote = session.messages[1]
    equal(remote.text, "é猫😀!"); equal(remote.addonMarked, true); equal(remote.outgoing, false)
    equal(remote.postId, nil); equal(remote.chunkIndex, nil); equal(remote.chunkCount, nil)
    f:emit(CHAT_CHANNEL_SAY, "Local Hero^Mx", edited, "@Outsider")
    equal(#session.messages, 1, "marker does not establish identity")
    equal(f.Q.pending, pending); equal(f.Q.current, 1)
    f:ownEcho(tag .. "abcde") -- Original stage is no longer the submitted payload.
    f:ownEcho(edited, CHAT_CHANNEL_PARTY) -- Archives span channels, queue matching does not.
    equal(#session.messages, 3)
    for index = 2, 3 do
        equal(session.messages[index].postId, nil)
        equal(session.messages[index].addonMarked, true)
    end
    equal(f.Q.pending, pending); equal(f.Q.current, 1)
    f:advance(49); equal(#f.stages, 1); equal(#f.sent, 1)
    f:ownEcho(edited)
    local record = session.messages[4]
    equal(record.text, "é猫😀!"); equal(record.addonMarked, true); equal(record.outgoing, true)
    equal(record.postId, postId); equal(record.chunkIndex, 1); equal(record.chunkCount, 2)
    equal(f.Q.pending, nil); equal(f.Q.current, 2)
    f:advance(49); equal(#f.stages, 1)
    f:advance(1); equal(f.entry:GetText(), tag .. "fghij"); equal(#f.sent, 1)
    f.echoMode = "sync"; f:submit(); f:advance(20000)
    equal(f.Q.active, false); equal(f.Q.paused, false); equal(#session.messages, 5)
    equal(session.messages[5].text, "fghij"); equal(session.messages[5].addonMarked, true)
    equal(session.messages[5].postId, postId); equal(session.messages[5].chunkIndex, 2)
    equal(#f.stages, 2); equal(#f.sent, 2)
end)

test("addon-only incoming capture requires exact marker, participant, and eligible channel", function(f)
    local session = assert(f.S.Create("Participants", CHAT_CHANNEL_SAY))
    assert(f.S.Select(session.id)); assert(f.S.SetParticipants("Friend Hero"))
    assert(f.S.SetAddonOnly(true)); assert(f.S.SetRecording(true))
    local tag, zwsp = f.A.Splitter.MESSAGE_TAG, "\226\128\139"
    for _, text in ipairs({ "hello", zwsp .. "hello", zwsp:rep(3) .. "hello", "hello" .. tag,
        " " .. tag .. "hello" }) do
        f:emit(CHAT_CHANNEL_SAY, "Friend Hero^Fx", text, "@Friend")
        f:ownEcho(text)
    end
    f:emit(CHAT_CHANNEL_SAY, "Outsider", tag .. "hello", "@Other")
    f:emit(CHAT_CHANNEL_SYSTEM, "Friend Hero", tag .. "hello", "@Friend")
    f:emit(CHAT_CHANNEL_SAY, "Friend Hero", tag .. "hello", "@Friend", true)
    equal(#session.messages, 0)
    for _, channel in ipairs({ CHAT_CHANNEL_SAY, CHAT_CHANNEL_PARTY, CHAT_CHANNEL_WHISPER }) do
        f:emit(channel, "Friend Hero^Fx", tag .. "hello", "@Friend")
        local record = session.messages[#session.messages]
        equal(record.text, "hello"); equal(record.addonMarked, true); equal(record.outgoing, false)
        equal(record.channel, channel)
        equal(record.postId, nil); equal(record.chunkIndex, nil); equal(record.chunkCount, nil)
    end
    equal(#session.messages, 3)
    f:emit(CHAT_CHANNEL_SAY, "Friend Hero", tag .. tag .. "hello", "@Friend")
    equal(session.messages[4].text, tag .. "hello", "archive strips one leading marker only")
    equal(session.messages[4].addonMarked, true)
    assert(f.S.SetAddonOnly(false))
    f:emit(CHAT_CHANNEL_SAY, "Friend Hero", "ordinary", "@Friend")
    f:ownEcho("ordinary own")
    equal(#session.messages, 6)
    for index = 5, 6 do equal(session.messages[index].addonMarked, false) end
    equal(session.messages[5].text, "ordinary"); equal(session.messages[6].text, "ordinary own")
    equal(session.messages[6].outgoing, true)
    f:advance(20000)
    equal(f.Q.active, false); equal(#f.stages, 0); equal(#f.sent, 0)
end)

for _, addonOnly in ipairs({ false, true }) do
    local filterEnabled = addonOnly
    test("native marker removal still confirms queue: addonOnly=" .. tostring(filterEnabled), function(f)
        f:loadMain()
        assert(f.A.ApplySettings(9, "", "", false))
        local session = assert(f.S.Create("Optional marker", CHAT_CHANNEL_SAY))
        assert(f.S.Select(session.id)); assert(f.S.SetAddonOnly(filterEnabled))
        assert(f.S.SetRecording(true))
        local tag = f.A.Splitter.MESSAGE_TAG
        assert(f.A.Start("abcdefghij", CHAT_CHANNEL_SAY))
        local postId = f.Q.postId
        equal(f.entry:GetText(), tag .. "abcde")
        f.entry:SetText("abcde"); f:submit()
        equal(f.Q.pending.text, "abcde"); equal(f.sent[1].text, "abcde")
        equal(#session.messages, 0)
        f:ownEcho("abcde")
        equal(f.Q.pending, nil); equal(f.Q.current, 2); equal(f.Q.paused, false)
        equal(#session.messages, filterEnabled and 0 or 1)
        if not filterEnabled then
            local record = session.messages[1]
            equal(record.text, "abcde"); equal(record.addonMarked, false)
            equal(record.postId, postId); equal(record.chunkIndex, 1); equal(record.chunkCount, 2)
        end
        f:advance(50)
        equal(f.entry:GetText(), tag .. "fghij", "removal does not affect later chunks")
        equal(#f.sent, 1)
        f.echoMode = "sync"; f:submit(); f:advance(20000)
        equal(f.Q.active, false); equal(f.Q.paused, false)
        equal(#session.messages, filterEnabled and 1 or 2)
        local record = session.messages[#session.messages]
        equal(record.text, "fghij"); equal(record.addonMarked, true)
        equal(record.postId, postId); equal(record.chunkIndex, 2); equal(record.chunkCount, 2)
        equal(#f.stages, 2); equal(#f.sent, 2)
    end)
end

test("Chat.Prepare rejects tag-only or tag-hidden commands and counts the full wire limit", function(f)
    local tag = f.A.Splitter.MESSAGE_TAG
    for _, text in ipairs({ tag, tag .. "/say unsafe", tag .. "  /reloadui",
        tag .. "a|b", tag .. "a\nb", tag .. "a\rb", tag .. string.char(255) }) do
        rejected(f.C.Prepare(text, CHAT_CHANNEL_SAY))
        equal(#f.stages, 0); equal(f.entry:GetText(), "")
    end
    f.entry.maxChars = 4
    rejected(f.C.Prepare(tag .. "😀", CHAT_CHANNEL_SAY))
    equal(#f.stages, 0)
    f.entry.maxChars = 5
    rejected(f.C.Prepare(tag .. "😀é", CHAT_CHANNEL_SAY))
    equal(#f.stages, 0)
    assert(f.C.Prepare(tag .. "😀", CHAT_CHANNEL_SAY))
    equal(f.entry:GetText(), tag .. "😀"); equal(#f.stages, 1)
    equal(f.submits, 0); equal(#f.sent, 0)
end)

test("stock clear/history/send and synchronous echo precede Submit posthook", function(f)
    f.echoMode = "sync"
    f:start()
    f.trace = {}
    f:submit()
    equal(table.concat(f.trace, ","), "submit,close,post:Close,history,post:AddCommandHistory,send,echo,post:SubmitTextEntry")
    equal(f.Q.pending, nil); equal(f.Q.current, 2); equal(f.Q.paused, false)
    equal(f.entry:GetText(), "")
    f:advance(50); equal(f.entry:GetText(), "second")
    f:submit(); equal(f.Q.active, false)
    f:advance(10000); equal(#f.stages, 2); equal(#f.sent, 2)
end)

test("own but unobserved echo cannot advance a staged queue", function(f)
    f:start()
    f:ownEcho("first")
    f:advance(20000)
    equal(f.Q.current, 1); equal(f.Q.pending, nil); equal(#f.stages, 1)
end)

test("non-hardware submission is not associated with the queue", function(f)
    f.echoMode = "sync"
    f:start(); f:submit(false)
    equal(#f.sent, 1); equal(f.Q.current, 1); equal(f.Q.pending, nil)
    f:advance(50); equal(#f.stages, 1)
end)

test("foreign identical echo, wrong channel, and customer-service echo are rejected", function(f)
    f:start(); f:submit()
    local pending = f.Q.pending
    f:emit(CHAT_CHANNEL_SAY, "Other Hero", "first", "@Other")
    f:emit(CHAT_CHANNEL_SAY, "Local Hero^Mx", "first", "@Other")
    f:emit(CHAT_CHANNEL_SAY, "Other Hero", "first", "")
    f:ownEcho("first", CHAT_CHANNEL_PARTY)
    f:emit(CHAT_CHANNEL_SAY, "Local Hero^Mx", "first", "@Local", true)
    equal(f.Q.pending, pending); equal(f.Q.current, 1)
    f:advance(50); equal(#f.stages, 1)
    f:emit(CHAT_CHANNEL_SAY, "Local Hero^Mx", "first", "")
    equal(f.Q.current, 2); equal(f.Q.pending, nil)
end)

test("whisper_sent validates recipient, not the local sender", function(f)
    f:start(nil, CHAT_CHANNEL_WHISPER, "@Friend"); f:submit()
    local pending = f.Q.pending
    f:emit(CHAT_CHANNEL_WHISPER, "Friend Hero", "first", "@Friend")
    f:emit(CHAT_CHANNEL_WHISPER_SENT, "Local Hero", "first", "@Local")
    f:emit(CHAT_CHANNEL_WHISPER_SENT, "Other Hero", "first", "@Other")
    equal(f.Q.pending, pending)
    f:emit(CHAT_CHANNEL_WHISPER_SENT, "Friend Hero", "first", " @FRIEND ")
    equal(f.Q.pending, nil); equal(f.Q.current, 2)
    f:advance(50)
    equal(f.chat.currentChannel, CHAT_CHANNEL_WHISPER); equal(f.chat.currentTarget, "@Friend")
end)

test("whisper character recipients normalize grammar suffixes", function(f)
    f:start({ "hello" }, CHAT_CHANNEL_WHISPER, "Friend Hero")
    f:submit()
    f:emit(CHAT_CHANNEL_WHISPER_SENT, "Friend Hero^Fx", "hello", "@Friend")
    equal(f.Q.active, false)
end)

test("delayed echo is required before next staging", function(f)
    f.echoMode, f.echoDelay = "delayed", 200
    f:start(); f:submit()
    f:advance(199); equal(f.Q.current, 1); equal(#f.stages, 1)
    f:advance(1); equal(f.Q.current, 2); equal(#f.stages, 1)
    f:advance(50); equal(f.entry:GetText(), "second"); equal(f.submits, 1)
end)

test("channel change pauses and preserves remaining destination even after late echo", function(f)
    f:start(nil, CHAT_CHANNEL_WHISPER, "@Friend"); f:submit()
    f.chat:SetChannel(CHAT_CHANNEL_PARTY)
    assert(f.Q.paused); equal(f.Q.channel, CHAT_CHANNEL_WHISPER); equal(f.Q.target, "@Friend")
    f:ownEcho("first", CHAT_CHANNEL_WHISPER, "@Friend")
    f:advance(50); equal(f.Q.current, 2); equal(#f.stages, 1)
    assert(f.Q.Resume())
    equal(f.chat.currentChannel, CHAT_CHANNEL_WHISPER); equal(f.chat.currentTarget, "@Friend")
    equal(f.entry:GetText(), "second")
end)

test("changing whisper target pauses without retargeting the queue", function(f)
    f:start(nil, CHAT_CHANNEL_WHISPER, "@Friend")
    f.chat:SetChannel(CHAT_CHANNEL_WHISPER, "@Other")
    assert(f.Q.paused); equal(f.Q.target, "@Friend")
    f:submit(); equal(f.Q.pending, nil)
    f:ownEcho("first", CHAT_CHANNEL_WHISPER, "@Other")
    equal(f.Q.current, 1); equal(#f.stages, 1)
end)

test("channel change between echo and delayed stage cancels automatic staging", function(f)
    f.echoMode = "sync"; f:start(); f:submit()
    f.chat:SetChannel(CHAT_CHANNEL_PARTY)
    f:advance(50)
    assert(f.Q.paused); equal(f.Q.channel, CHAT_CHANNEL_SAY)
    equal(f.entry:GetText(), ""); equal(#f.stages, 1)
end)

test("automatic stage rechecks destination even without a SetChannel hook", function(f)
    f.echoMode = "sync"; f:start(); f:submit()
    f.chat.currentChannel = CHAT_CHANNEL_PARTY
    f:advance(50)
    assert(f.Q.paused); equal(f.Q.channel, CHAT_CHANNEL_SAY); equal(#f.stages, 1)
end)

test("Start does not overwrite an existing native draft or change its destination", function(f)
    f.chat:StartTextEntry("unrelated draft", CHAT_CHANNEL_PARTY)
    rejected(f.Q.Start({ "first" }, CHAT_CHANNEL_SAY))
    equal(f.entry:GetText(), "unrelated draft"); equal(f.chat.currentChannel, CHAT_CHANNEL_PARTY)
    equal(#f.stages, 0); assert(f.Q.paused)
end)

test("Next cannot overwrite an edited staged chunk", function(f)
    f:start(); f.entry:SetText("my edit")
    rejected(f.Q.Move(1))
    equal(f.entry:GetText(), "my edit"); equal(#f.stages, 1); assert(f.Q.paused)
    equal(f.Q.current, 2)
    f.entry:SetText(""); assert(f.Q.Resume()); equal(f.entry:GetText(), "second")
end)

test("Resume cannot overwrite edited input", function(f)
    f:start(); f.entry:SetText("my edit"); assert(f.Q.Pause())
    rejected(f.Q.Resume())
    equal(f.entry:GetText(), "my edit"); equal(#f.stages, 1); assert(f.Q.paused)
end)

test("unchanged owned text may be replaced by manual Next and Previous", function(f)
    f:start(); assert(f.Q.Move(1)); equal(f.entry:GetText(), "second")
    assert(f.Q.Move(-1)); equal(f.entry:GetText(), "first")
    rejected(f.Q.Move(-1)); rejected(f.Q.Move(2)); equal(f.submits, 0)
end)

test("new draft typed while awaiting delayed stage is preserved", function(f)
    f.echoMode = "sync"; f:start(); f:submit()
    f.entry:SetText("new native draft")
    f:advance(50)
    equal(f.entry:GetText(), "new native draft"); assert(f.Q.paused); equal(#f.stages, 1)
end)

test("native reopen revokes ownership even if text is identical", function(f)
    f:start()
    f.chat:StartTextEntry("first", CHAT_CHANNEL_SAY)
    assert(f.Q.paused)
    rejected(f.Q.Resume()); equal(f.entry:GetText(), "first"); equal(#f.stages, 1)
end)

test("native close pauses until explicit Resume", function(f)
    f:start(); f.chat:CloseTextEntry()
    assert(f.Q.paused); equal(f.entry:GetText(), "")
    f:advance(10000); equal(#f.stages, 1)
    assert(f.Q.Resume()); equal(f.entry:GetText(), "first")
end)

test("Cancel invalidates delayed staging and leaves native input untouched", function(f)
    f.echoMode = "sync"; f:start(); f:submit()
    f.entry:SetText("leave this alone"); assert(f.Q.Cancel())
    f:advance(20000)
    equal(f.Q.active, false); equal(f.Q.pending, nil)
    equal(f.entry:GetText(), "leave this alone"); equal(#f.stages, 1)
end)

test("Cancel before a delayed echo prevents revival and timeout effects", function(f)
    f.echoMode = "delayed"; f:start(); f:submit(); f.Q.Cancel()
    f:advance(20000)
    equal(f.Q.active, false); equal(f.Q.current, 0); equal(#f.stages, 1)
    assert(f.Q.reason:match("Cancelled"))
end)

test("old delayed-stage callback cannot stage a newly started queue", function(f)
    f.echoMode = "sync"; f:start(); f:submit(); f.Q.Cancel()
    f:start({ "new post", "new remainder" })
    f:advance(20000)
    equal(f.entry:GetText(), "new post"); equal(#f.stages, 2); equal(f.Q.current, 1)
end)

test("timeout pauses, Resume refuses, manual Next recovers without resending", function(f)
    f:start(); f:submit()
    f:advance(9999); equal(f.Q.paused, false)
    f:advance(1); assert(f.Q.paused and f.Q.pending)
    rejected(f.Q.Resume()); equal(#f.stages, 1)
    assert(f.Q.Move(1)); equal(f.entry:GetText(), "second"); equal(f.Q.pending, nil)
    equal(f.submits, 1); equal(#f.sent, 1)
    f:ownEcho("first"); equal(f.Q.current, 2)
    f:advance(20000); equal(f.Q.paused, false)
end)

test("echo after timeout confirms but leaves next chunk paused for Resume", function(f)
    f:start(); f:submit(); f:advance(10000)
    f:ownEcho("first"); f:advance(50)
    equal(f.Q.current, 2); equal(f.Q.pending, nil); assert(f.Q.paused)
    equal(#f.stages, 1); assert(f.Q.Resume()); equal(f.entry:GetText(), "second")
end)

test("manual Next past the last unconfirmed chunk finishes without marking sent", function(f)
    f:start({ "only" }); f:submit(); f:advance(10000)
    assert(f.Q.Move(1)); equal(f.Q.active, false)
    assert(f.Q.reason:match("not marked as sent")); equal(f.Q.pending, nil)
    f:ownEcho("only"); f:advance(50); equal(#f.stages, 1)
end)

test("duplicate successful text cannot auto-confirm a later identical chunk", function(f)
    f:start({ "same", "same", "last" }); f:submit(); f:ownEcho("same"); f:advance(50)
    f:submit(); assert(f.Q.pending.ambiguous and f.Q.paused)
    f:ownEcho("same"); f:ownEcho("same"); f:advance(50)
    equal(f.Q.current, 2); assert(f.Q.pending); equal(#f.stages, 2)
    assert(f.Q.Move(1)); equal(f.entry:GetText(), "last")
end)

test("cancelled submissions remain ambiguous across posts in the same login", function(f)
    f:start({ "same" }); f:submit(); f.Q.Cancel()
    f:start({ "same", "last" }); f:submit()
    assert(f.Q.paused and f.Q.pending.ambiguous)
    f:ownEcho("same"); f:advance(50); equal(f.Q.current, 1); equal(#f.stages, 2)
end)

test("manual skipping retires an unconfirmed fingerprint", function(f)
    f:start({ "same", "same" }); f:submit(); assert(f.Q.Move(1)); f:submit()
    assert(f.Q.pending.ambiguous)
    f:ownEcho("same"); equal(f.Q.active, true); equal(f.Q.current, 2)
end)

test("paused submission retires its edited text before a delayed identical echo", function(f)
    local session = assert(f.S.Create("RP", CHAT_CHANNEL_SAY))
    assert(f.S.Select(session.id)); assert(f.S.SetRecording(true))
    f:start({ "first", "same", "last" })
    assert(f.Q.Pause())
    f.entry:SetText("same")
    f.echoMode, f.echoDelay = "delayed", 200
    f:submit()
    equal(f.Q.pending, nil); equal(f.Q.current, 1); assert(f.Q.paused)
    f:advance(50)
    assert(f.Q.Move(1))
    f.echoDelay = 1000
    f:submit()
    local pending = f.Q.pending
    assert(pending and pending.ambiguous and f.Q.paused)
    f:advance(150) -- Echo of the unassociated first submission, not chunk 2.
    equal(f.Q.pending, pending); equal(f.Q.current, 2); equal(#f.stages, 2)
    equal(#session.messages, 1); equal(session.messages[1].postId, nil)
    f:advance(1000)
    equal(f.Q.pending, pending); equal(f.Q.current, 2); equal(#f.stages, 2)
    equal(#session.messages, 2); equal(session.messages[2].postId, nil)
    rejected(f.Q.Resume())
    assert(f.Q.Move(1)); equal(f.entry:GetText(), "last")
    equal(#f.sent, 2)
end)

test("unassociated submissions after cancellation stay retired across posts", function(f)
    f:start({ "same" }); assert(f.Q.Cancel())
    f:submit()
    equal(f.Q.pending, nil); equal(f.Q.active, false); equal(#f.timers, 0)
    f:advance(20000)
    f:start({ "same", "last" }); f:submit()
    assert(f.Q.pending.ambiguous and f.Q.paused)
    f:ownEcho("same"); f:advance(50)
    equal(f.Q.current, 1); equal(#f.stages, 2)
end)

test("non-hardware submissions retire text without associating it", function(f)
    f:start({ "same", "same" }); f:submit(false)
    equal(f.Q.pending, nil); equal(f.Q.current, 1)
    assert(f.Q.Move(1)); f:submit()
    assert(f.Q.pending.ambiguous and f.Q.paused)
    f:ownEcho("same"); equal(f.Q.current, 2); assert(f.Q.active)
end)

test("an unassociated duplicate makes an existing pending attempt ambiguous", function(f)
    f:start(); f:submit()
    local pending = f.Q.pending
    assert(f.Q.Pause())
    f.entry:SetText("first"); f:submit()
    equal(f.Q.pending, pending); assert(pending.ambiguous and f.Q.paused)
    f:ownEcho("first"); f:advance(50)
    equal(f.Q.pending, pending); equal(f.Q.current, 1); equal(#f.stages, 1)
end)

test("unassociated fingerprints retain the login lifetime cap and manual-only fallback", function(f)
    f:start(); assert(f.Q.Cancel())
    for i = 1, 4096 do
        f.entry:SetText("unassociated " .. i); f:submit()
    end
    assert(not f.Q.manualOnly)
    f.entry:SetText("unassociated 1"); f:submit()
    assert(not f.Q.manualOnly, "duplicate fingerprints must not consume capacity")
    f.entry:SetText("overflow"); f:submit()
    assert(f.Q.manualOnly); equal(#f.timers, 0)
    f:advance(20000)
    f:start({ "unique new post" }); f:submit()
    assert(f.Q.pending.ambiguous and f.Q.paused and f.Q.manualOnly)
    f:ownEcho("unique new post"); equal(f.Q.current, 1); assert(f.Q.active)
end)

test("identical text at a different destination is not conflated", function(f)
    f:start({ "same" }); f:submit(); f:ownEcho("same")
    f:start({ "same" }, CHAT_CHANNEL_PARTY); f:submit()
    assert(not f.Q.pending.ambiguous)
    f:ownEcho("same", CHAT_CHANNEL_PARTY); equal(f.Q.active, false)
end)

test("pChat-like history prefix and pre-submit expansion before lazy attachment", function(f)
    f:pchat(); f:start({ ":wave:", "last" }); f:submit()
    equal(f.entry.history[1], "/say waves warmly")
    equal(f.sent[1].text, "waves warmly"); equal(f.Q.pending.text, "waves warmly")
    f:ownEcho(":wave:"); assert(f.Q.pending)
    f:ownEcho("waves warmly"); f:advance(50); equal(f.entry:GetText(), "last")
end)

test("pChat-like history and submit overrides installed after first attachment", function(f)
    f:start({ ":wave:", "last" })
    f:pchat()
    assert(f.Q.Resume()) -- EnsureHooks explicitly detects/re-attaches changed methods.
    f:submit()
    equal(f.entry.history[1], "/say waves warmly"); equal(f.sent[1].text, "waves warmly")
    assert(f.Q.pending, "late history override must observe raw submission, not pause on stored /say prefix; reason: "
        .. tostring(f.Q.reason))
    equal(f.Q.pending.text, "waves warmly")
    f:ownEcho("waves warmly"); f:advance(50); equal(f.entry:GetText(), "last")
end)

test("paused pChat submission retires expanded text, not decorated history", function(f)
    f:pchat(); f:start({ ":wave:", "waves warmly", "last" })
    assert(f.Q.Pause()); f:submit()
    equal(f.entry.history[1], "/say waves warmly"); equal(f.Q.pending, nil)
    assert(f.Q.Move(1)); f:submit()
    assert(f.Q.pending.ambiguous and f.Q.paused)
    f:ownEcho("waves warmly"); f:advance(50)
    equal(f.Q.current, 2); equal(#f.stages, 2)
end)

test("history restoration outside submit is never treated as a send", function(f)
    f:pchat(); f:start()
    f.hardware = true -- A history UI action can itself be a hardware event.
    f.entry:AddCommandHistory("first")
    f.hardware = false
    equal(f.entry.history[1], "/say first"); equal(f.Q.pending, nil)
    f:ownEcho("first"); equal(f.Q.current, 1)
    f:submit(); f:ownEcho("first"); f:advance(50)
    f.entry:AddCommandHistory("second")
    f:ownEcho("second"); equal(f.Q.current, 2); equal(f.Q.pending, nil)
    equal(#f.sent, 1)
end)

test("repeated hook checks do not duplicate observers or timers", function(f)
    f:start()
    local submit, history = f.chat.SubmitTextEntry, f.entry.AddCommandHistory
    for _ = 1, 5 do assert(f.C.EnsureHooks()) end
    equal(f.chat.SubmitTextEntry, submit); equal(f.entry.AddCommandHistory, history)
    f:submit(); equal(#f.timers, 1); equal(#f.entry.history, 1)
end)

test("gamepad preparation and automatic continuation are refused", function(f)
    f.gamepad = true
    rejected(f.Q.Start({ "first", "second" }, CHAT_CHANNEL_SAY))
    equal(#f.stages, 0); equal(f.submits, 0)
    f.gamepad = false; assert(f.Q.Resume())
    f.echoMode = "sync"; f:submit(); f.gamepad = true; f:advance(50)
    assert(f.Q.paused); equal(#f.stages, 1); equal(f.entry:GetText(), "")
end)

test("gamepad submission cannot create a queue attempt after keyboard staging", function(f)
    f:start(); f.gamepad = true; f.echoMode = "sync"; f:submit()
    equal(f.Q.pending, nil); equal(f.Q.current, 1); equal(#f.stages, 1)
end)

test("supported destinations enforce live channel requirements and whisper target validation", function(f)
    for _, destination in ipairs(f.C.Destinations) do
        assert(f.C.ValidateDestination(destination.channel, "@Friend"))
        f.allowed[destination.channel] = false
        rejected(f.C.ValidateDestination(destination.channel, "@Friend"))
        f.allowed[destination.channel] = true
    end
    for _, channel in ipairs({ CHAT_CHANNEL_ZONE, CHAT_CHANNEL_SYSTEM, CHAT_CHANNEL_WHISPER_SENT, -1 }) do
        rejected(f.C.ValidateDestination(channel))
    end
    rejected(f.C.ValidateDestination(nil))
    for _, target in ipairs({ "", "   ", "@Friend|link", "@Friend\n", "@Friend\r" }) do
        rejected(f.C.ValidateDestination(CHAT_CHANNEL_WHISPER, target))
    end
    rejected(f.C.ValidateDestination(CHAT_CHANNEL_WHISPER, nil))
    f.info[CHAT_CHANNEL_PARTY] = nil
    rejected(f.Q.Start({ "first" }, CHAT_CHANNEL_PARTY))
    equal(f.Q.active, false); equal(#f.stages, 0)
end)

test("native channel validation can reject a staged submission without confirming", function(f)
    f:start(nil, CHAT_CHANNEL_PARTY)
    f.allowed[CHAT_CHANNEL_PARTY] = false
    f:submit()
    equal(#f.sent, 0); equal(#f.entry.history, 1)
    assert(f.Q.paused and f.Q.pending); equal(f.Q.channel, CHAT_CHANNEL_PARTY)
    f:advance(10000); equal(f.Q.current, 1); equal(#f.stages, 1)
end)

test("runtime limit is read afresh, clamped to control, and counts Unicode scalars", function(f)
    equal(f.C.GetLimit(), 350)
    f.entry.maxChars = 5; equal(f.C.GetLimit(), 5)
    MAX_TEXT_CHAT_INPUT_CHARACTERS = 3; equal(f.C.GetLimit(), 3)
    local chunks = assert(f.A.Splitter.Split("é猫😀é猫", {
        maxChars = f.C.GetLimit(), prefix = "", suffix = "" }))
    f:start(chunks); equal(f.entry:GetText(), "é猫😀")
    f.echoMode = "sync"; f:submit()
    f.entry.maxChars = 1; f:advance(50)
    equal(f.C.GetLimit(), 1); assert(f.Q.paused); equal(#f.stages, 1)
    MAX_TEXT_CHAT_INPUT_CHARACTERS, f.entry.maxChars = 10, 10
    assert(f.Q.Resume()); equal(f.entry:GetText(), "é猫")
end)

test("limit falls back to control and refuses missing or fractional limits", function(f)
    -- Deliberately simulate an absent engine constant without changing its production type.
    rawset(_G, "MAX_TEXT_CHAT_INPUT_CHARACTERS", nil); f.entry.maxChars = 120
    equal(f.C.GetLimit(), 120)
    MAX_TEXT_CHAT_INPUT_CHARACTERS = 0; equal(f.C.GetLimit(), 120)
    f.entry.maxChars = nil; rejected(f.C.GetLimit())
    MAX_TEXT_CHAT_INPUT_CHARACTERS = 3.5; rejected(f.C.GetLimit())
    rejected(f.Q.Start({ "first" }, CHAT_CHANNEL_SAY)); equal(#f.stages, 0)
end)

test("missing native chat refuses preparation without touching input", function(f)
    ZO_GetChatSystem = function() return nil end
    equal(f.C.CurrentDestination(), nil)
    rejected(f.C.EnsureHooks())
    rejected(f.Q.Start({ "first" }, CHAT_CHANNEL_SAY))
    assert(f.Q.paused)
    equal(#f.stages, 0); equal(#f.sent, 0)
end)

test("native chat disappearing during preparation fails closed", function(f)
    local validate = f.C.ValidateDestination
    for _, missing in ipairs({ "system", "entry" }) do
        ZO_GetChatSystem = function() return f.chat end
        f.C.ValidateDestination = function(channel, target)
            local ok, err = validate(channel, target)
            ZO_GetChatSystem = function()
                if missing == "entry" then return {} end
                return nil
            end
            return ok, err
        end
        rejected(f.C.Prepare("first", CHAT_CHANNEL_SAY))
        equal(#f.stages, 0); equal(#f.sent, 0)
    end
end)

test("unsafe chunks never reach StartChatInput", function(f)
    for _, text in ipairs({ "", "/say x", "  /reloadui", "a|b", "a\nb", "a\rb", string.char(255), string.rep("x", 351) }) do
        rejected(f.Q.Start({ text }, CHAT_CHANNEL_SAY))
        equal(#f.stages, 0)
        f.Q.Cancel()
    end
end)

test("editing a staged chunk into a command cannot confirm it as queued chat", function(f)
    f:start(); f.entry:SetText("/reloadui"); f:submit()
    assert(f.Q.paused); equal(f.Q.pending, nil); equal(#f.sent, 0)
    f:ownEcho("/reloadui"); equal(f.Q.current, 1)
end)

test("native /rps next dispatch preserves the new stage and its ownership", function(f)
    f.commands["/rps"] = function(argument)
        equal(argument, "next")
        assert(f.Q.paused, "command history must reject the old queued submission before dispatch")
        assert(f.Q.Move(1))
    end
    f:start({ "first", "second", "last" })
    local oldStage = f.Q.staged
    f.entry:SetText("/rps next"); f:submit()
    equal(f.Q.current, 2); equal(f.Q.paused, false); equal(f.Q.pending, nil)
    assert(f.Q.staged and f.Q.staged ~= oldStage)
    equal(f.entry:GetText(), "second"); assert(f.entry:IsOpen())
    equal(#f.sent, 0); equal(#f.stages, 2); equal(#f.timers, 0)
    -- Resume may replace unchanged owned input, but must refuse an unrelated draft.
    assert(f.Q.Resume()); equal(f.entry:GetText(), "second")
    f:submit(); equal(f.Q.pending.text, "second"); equal(#f.sent, 1)
    f:ownEcho("second"); f:advance(50)
    equal(f.entry:GetText(), "last"); equal(f.Q.current, 3)
end)

test("unavailable platform or empty submission pauses as unobservable", function(f)
    f:start(); f.available = false; f:submit()
    assert(f.Q.paused); equal(f.Q.pending, nil); equal(#f.entry.history, 0)
    f.available = true; assert(f.Q.Resume()); f.entry:SetText(""); f:submit()
    assert(f.Q.paused); equal(f.Q.pending, nil); equal(#f.sent, 0)
end)

test("failed native staging is reported without claiming ownership", function(f)
    f.allowStart = false
    rejected(f.Q.Start({ "first" }, CHAT_CHANNEL_SAY))
    equal(f.entry:IsOpen(), false); equal(f.Q.staged, nil); assert(f.Q.paused)
    f.allowStart = true; assert(f.Q.Resume()); equal(f.entry:GetText(), "first")
end)

test("missing observation methods refuse preparation", function(f)
    f.entry.AddCommandHistory = nil
    rejected(f.Q.Start({ "first" }, CHAT_CHANNEL_SAY))
    equal(#f.stages, 0); equal(f.Q.staged, nil)
end)

test("session archive gets only observed chat and metadata for confirmed queued sends", function(f)
    local session = assert(f.S.Create("RP", CHAT_CHANNEL_SAY))
    assert(f.S.Select(session.id)); assert(f.S.SetParticipants("@Friend")); assert(f.S.SetRecording(true))
    f:start(); equal(#session.messages, 0)
    local postId = f.Q.postId
    f.entry:SetText("actual edit"); f:submit(); equal(#session.messages, 0)
    f:emit(CHAT_CHANNEL_SAY, "Friend Hero", "actual edit", "@Friend")
    equal(#session.messages, 1); equal(session.messages[1].postId, nil); assert(f.Q.pending)
    f:ownEcho("actual edit")
    local record = session.messages[2]
    equal(record.text, "actual edit"); equal(record.postId, postId)
    equal(record.chunkIndex, 1); equal(record.chunkCount, 2); equal(record.outgoing, true)
    f:advance(50); equal(#session.messages, 2)
    f.Q.Cancel(); equal(#session.messages, 2)
end)

test("cross-channel archives do not relax queue destination matching", function(f)
    local session = assert(f.S.Create("All channels", CHAT_CHANNEL_SAY))
    assert(f.S.Select(session.id)); assert(f.S.SetParticipants("@Friend")); assert(f.S.SetRecording(true))
    f:start(); f:submit()
    local pending = f.Q.pending
    f:emit(CHAT_CHANNEL_PARTY, "Friend Hero", "first", "@Friend")
    f:ownEcho("first", CHAT_CHANNEL_EMOTE)
    f:emit(CHAT_CHANNEL_WHISPER, "Friend Hero", "first", "@Friend")
    f:emit(CHAT_CHANNEL_WHISPER_SENT, "Other Hero", "first", "@Other")
    equal(#session.messages, 4)
    equal(session.messages[1].channel, CHAT_CHANNEL_PARTY)
    equal(session.messages[2].channel, CHAT_CHANNEL_EMOTE)
    equal(session.messages[3].target, "@Friend")
    equal(session.messages[4].target, "@Other")
    for _, record in ipairs(session.messages) do equal(record.postId, nil) end
    equal(f.Q.pending, pending); equal(f.Q.current, 1); equal(f.Q.channel, CHAT_CHANNEL_SAY)
    f:emit(CHAT_CHANNEL_PARTY, "Bystander", "first", "@Bystander")
    equal(#session.messages, 4)
    f:ownEcho("first")
    equal(#session.messages, 5)
    equal(session.messages[5].postId, f.Q.postId)
    equal(session.messages[5].channel, CHAT_CHANNEL_SAY)
    equal(f.Q.current, 2); equal(f.Q.pending, nil)
    f:advance(50)
    equal(f.chat.currentChannel, CHAT_CHANNEL_SAY)
    equal(f.entry:GetText(), "second")
end)

-- Trace assertions use event names and relative positions, not global counter values.
local function traceField(record, name)
    return record.line:match(" " .. name .. "=([^%s]+)")
end

local function traceRecords(f)
    local records, previous = {}, 0
    for _, line in ipairs(f.debugLog) do
        local sequence, time, batch, current, count, generation, event = line:match(
            "^%[RPS TRACE #(%d+) t=(%d+) B=(%S+) C=(%d+)/(%d+) G=(%d+)%] ([A-Z_]+)")
        assert(sequence, "missing trace prefix/event: " .. line)
        assert(#sequence >= 4 and tonumber(sequence) > previous, "trace sequence must increase: " .. line)
        previous = math.floor(assert(tonumber(sequence)))
        local record = { line = line, event = event, sequence = previous, time = tonumber(time),
            batch = batch, current = tonumber(current), count = tonumber(count), generation = tonumber(generation) }
        for _, name in ipairs({ "active", "paused", "staged", "pending", "preparing", "owned" }) do
            local value = traceField(record, name)
            assert(value == "true" or value == "false", "missing boolean state " .. name .. ": " .. line)
        end
        local submission = traceField(record, "submit")
        assert(submission and (submission == "-" or submission:match("^%d+$")), "missing submission state: " .. line)
        records[#records + 1] = record
    end
    return records
end

local function traceEvent(f, event, after, fields)
    for index, record in ipairs(traceRecords(f)) do
        if index > (after or 0) and record.event == event then
            local matches = true
            for name, value in pairs(fields or {}) do
                if traceField(record, name) ~= tostring(value) then matches = false end
            end
            if matches then return record, index end
        end
    end
    error("missing trace " .. event .. " after log " .. tostring(after or 0) .. "\n" .. table.concat(f.debugLog, "\n"), 2)
end

local function traceCount(f, event)
    local count = 0
    for _, record in ipairs(traceRecords(f)) do
        if record.event == event then count = count + 1 end
    end
    return count
end

local function traceReason(record, reason)
    assert(record.line:find("reason=" .. reason, 1, true), "missing canned reason: " .. record.line)
end

test("tracing is silent by default throughout preparation, submission, and timers", function(f)
    equal(f.A.saved.debug, false)
    f.C.Trace("TEST_DEFAULT", "probe=true")
    f.echoMode = "sync"
    f:start(); f:submit(); f:advance(50); f:submit(); f:advance(10000)
    equal(f.Q.active, false); equal(#f.sent, 2); equal(#f.debugLog, 0)
end)

test("direct Trace uses d and virtual frame time without refreshing UI or routing notifications", function(f)
    f.A.saved.debug = true
    f.A.Debug = function() error("Trace must not call A.Debug") end
    f.A.Notify = function() error("Trace must not call A.Notify") end
    f.A.UI.Refresh = function() error("Trace must not refresh UI") end
    f:advance(1234)
    local generation = f.Q.generation
    f.C.Trace("TEST_DIRECT", "probe=true")
    equal(#f.debugLog, 1)
    local record = traceEvent(f, "TEST_DIRECT", nil, { probe = true, active = false, paused = false,
        staged = false, pending = false, preparing = false, submit = "-", owned = false })
    equal(record.time, f.now); equal(record.current, 0); equal(record.count, 0)
    equal(record.generation, generation); equal(f.Q.generation, generation)
    equal(#f.stages, 0); equal(#f.timers, 0); equal(f.submits, 0); equal(f.uiRefreshes, 0)
end)

test("throwing debug output cannot interrupt queued preparation, submission, or echo confirmation", function(f)
    f.A.saved.debug, f.echoMode, f.echoDelay = true, "delayed", 10
    local calls = 0
    d = function()
        calls = calls + 1
        error("simulated debug output failure")
    end
    f.C.Trace("TEST_THROWING_LOGGER")
    equal(calls, 1, "direct Trace must attempt output without propagating its error")
    f:start()
    assert(calls > 1); equal(f.entry:GetText(), "first"); equal(f.submits, 0)
    f.entry:SetText("manually edited with broken logger")
    f:submit()
    equal(f.Q.pending.text, "manually edited with broken logger")
    equal(f.sent[1].text, f.Q.pending.text); equal(f.Q.current, 1); equal(f.Q.paused, false)
    f:advance(10)
    equal(f.Q.pending, nil); equal(f.Q.current, 2); equal(#f.stages, 1)
    f:advance(49); equal(#f.stages, 1)
    f:advance(1); equal(f.entry:GetText(), "second"); equal(f.submits, 1)
    local beforeSubmit = calls
    f:submit(); f:advance(10)
    assert(calls > beforeSubmit); equal(f.Q.pending, nil); equal(f.Q.active, false)
    f:advance(20000)
    equal(#f.stages, 2); equal(#f.sent, 2); equal(#f.entry.history, 2); equal(#f.debugLog, 0)
end)

for _, debugEnabled in ipairs({ false, true }) do
    test("system replacement short-circuits stale entry readback with debug=" .. tostring(debugEnabled), function(f)
        f.A.saved.debug = debugEnabled
        local start, staleReads = StartChatInput, 0
        local replacement = { textEntry = {} }
        local function staleRead()
            staleReads = staleReads + 1
            error("old entry was invalidated by the system switch")
        end
        StartChatInput = function(text, channel, target)
            start(text, channel, target)
            f.entry.IsOpen, f.entry.GetText = staleRead, staleRead
            ZO_GetChatSystem = function() return replacement end
        end
        local ok, result, err = pcall(f.Q.Start, { "first", "second" }, CHAT_CHANNEL_SAY)
        assert(ok, "readback rejection must not throw: " .. tostring(result))
        rejected(result, err)
        equal(err, "ESO did not stage the exact chunk/destination. Check native input; Resume when ready.")
        equal(staleReads, 0, "neither validation nor diagnostic details may read the old entry")
        assert(f.Q.active and f.Q.paused); equal(f.Q.reason, err)
        equal(f.Q.staged, nil); equal(f.Q.pending, nil); equal(f.Q.current, 1)
        if debugEnabled then
            local record, rejectedAt = traceEvent(f, "PREPARE_REJECT", nil, { reason = "readback-mismatch" })
            equal(record.line:match("PREPARE_REJECT (.-) |"), "reason=readback-mismatch")
            traceReason(traceEvent(f, "PAUSE", rejectedAt), err)
            equal(traceCount(f, "PREPARE_READY"), 0)
        else
            equal(#f.debugLog, 0)
        end
        f:advance(20000)
        equal(staleReads, 0); equal(#f.stages, 1); equal(f.submits, 0); equal(#f.sent, 0)
    end)
end

test("Trace falls back to timestamp milliseconds when frame time is unavailable", function(f)
    f.A.saved.debug = true
    rawset(_G, "GetFrameTimeMilliseconds", nil)
    f:advance(2345)
    f.C.Trace("TEST_FALLBACK")
    local record = traceEvent(f, "TEST_FALLBACK")
    equal(record.time, GetTimeStamp() * 1000)
    equal(#f.debugLog, 1); equal(f.uiRefreshes, 0)
end)

test("enabled traces correlate edited successful submissions across distinct batches", function(f)
    f.A.saved.debug, f.echoMode = true, "sync"
    local previousBatch, previousSubmission, after = nil, nil, 0
    for batch = 1, 2 do
        local chunks = { "batch " .. batch .. " first", "batch " .. batch .. " second" }
        f:start(chunks)
        local start, position = traceEvent(f, "BATCH_START", after)
        assert(tonumber(start.batch), "batch serial must be numeric")
        assert(start.batch ~= previousBatch, "each batch needs a distinct trace serial")
        equal(start.current, 1); equal(start.count, 2)
        previousBatch = start.batch
        for chunk = 1, 2 do
            local _, prepared = traceEvent(f, "PREPARE_BEGIN", position)
            local _, ready = traceEvent(f, "PREPARE_READY", prepared)
            local staged, stagedAt = traceEvent(f, "STAGED", ready)
            equal(staged.batch, start.batch); equal(staged.current, chunk); equal(staged.count, 2)
            local actual = chunks[chunk] .. " manually edited"
            f.entry:SetText(actual)
            equal(f.submits, (batch - 1) * 2 + chunk - 1, "preparation must not submit")
            f:submit()
            equal(f.sent[#f.sent].text, actual); equal(f.entry.history[#f.entry.history], actual)
            local begin, beganAt = traceEvent(f, "SUBMIT_BEGIN", stagedAt,
                { hardware = true, keyboard = true, associate = true, reason = "eligible" })
            local id = traceField(begin, "id")
            assert(id and tonumber(id) and id ~= previousSubmission, "submission IDs must distinguish sends")
            assert(tonumber(traceField(begin, "hook")), "submit hook version must be visible")
            equal(traceField(begin, "submit"), id)
            previousSubmission = id
            local history, historyAt = traceEvent(f, "HISTORY_CALLBACK", beganAt, { action = "associate" })
            equal(traceField(history, "submit"), id)
            local captured, capturedAt = traceEvent(f, "SUBMISSION_CAPTURED", historyAt)
            equal(captured.batch, start.batch); equal(captured.current, chunk)
            local _, confirmedAt = traceEvent(f, "ECHO_CONFIRMED", capturedAt)
            local event = chunk == 1 and "NEXT_SCHEDULED" or "BATCH_COMPLETE"
            local _, completedAt = traceEvent(f, event, confirmedAt)
            local _, endedAt = traceEvent(f, "SUBMIT_END", completedAt,
                { histories = 1, associated = 1, stageUnchanged = false })
            if chunk == 1 then
                f:advance(49); equal(#f.stages, (batch - 1) * 2 + 1)
                f:advance(1)
                local timer
                timer, position = traceEvent(f, "NEXT_TIMER", endedAt, { action = "prepare" })
                equal(tonumber(traceField(timer, "scheduledGeneration")), timer.generation)
            else
                after = endedAt
                equal(f.Q.active, false)
            end
        end
    end
    f:advance(20000)
    equal(traceCount(f, "BATCH_START"), 2); equal(traceCount(f, "BATCH_COMPLETE"), 2)
    equal(traceCount(f, "SUBMISSION_CAPTURED"), 4); equal(traceCount(f, "ECHO_CONFIRMED"), 4)
    equal(#f.sent, 4); equal(#f.stages, 4)
end)

test("stock entry closure is traced between submit and history without a focus-loss callback", function(f)
    f.A.saved.debug, f.echoMode = true, "sync"
    assert(not f.closeThroughChat)
    f:start()
    local attachment = traceEvent(f, "HOOK_CLOSE_ATTACH", nil, { submissionOpen = false })
    assert(tonumber(traceField(attachment, "version")))
    f:submit()
    local begin, beganAt = traceEvent(f, "SUBMIT_BEGIN")
    local close, closedAt = traceEvent(f, "ENTRY_CLOSE", beganAt,
        { origin = "submitting", keepText = false, owned = true })
    equal(traceField(close, "hook"), traceField(attachment, "version"))
    equal(traceField(close, "submit"), traceField(begin, "id"))
    local _, historyAt = traceEvent(f, "HISTORY_CALLBACK", closedAt, { action = "associate" })
    traceEvent(f, "SUBMIT_END", historyAt, { histories = 1, associated = 1 })
    equal(traceCount(f, "ENTRY_CLOSE"), 1); equal(traceCount(f, "INPUT_CLOSE"), 0)
    equal(traceCount(f, "PAUSE"), 0); equal(f.Q.paused, false); equal(f.Q.current, 2)
    equal(f.entry:GetText(), ""); equal(f.entry:IsOpen(), false)
    f:advance(50); equal(f.entry:GetText(), "second"); equal(#f.stages, 2); equal(#f.sent, 1)
end)

test("entry-close reattachment is versioned and external closure preserves queue ownership", function(f)
    f.A.saved.debug = true
    f:start()
    local original = f.entry.Close
    local attachment = traceEvent(f, "HOOK_CLOSE_ATTACH", nil, { submissionOpen = false })
    local after = #f.debugLog
    for _ = 1, 3 do assert(f.C.EnsureHooks()) end
    equal(f.entry.Close, original); equal(#f.debugLog, after)
    f.entry.Close = function(self, keepText) return original(self, keepText) end
    assert(f.C.EnsureHooks())
    local reattached = traceEvent(f, "HOOK_CLOSE_ATTACH", after, { submissionOpen = false })
    assert(tonumber(traceField(reattached, "version")) > tonumber(traceField(attachment, "version")))
    local staged, generation = f.Q.staged, f.Q.generation
    f.entry:Close(true)
    local close = traceEvent(f, "ENTRY_CLOSE", after,
        { origin = "external", keepText = true, owned = true, submit = "-" })
    equal(traceField(close, "hook"), traceField(reattached, "version"))
    equal(traceCount(f, "ENTRY_CLOSE"), 1, "obsolete close hooks must not duplicate the trace")
    equal(traceCount(f, "INPUT_CLOSE"), 0); equal(traceCount(f, "PAUSE"), 0)
    equal(f.Q.staged, staged); equal(f.Q.generation, generation); equal(f.Q.paused, false)
    equal(f.entry:GetText(), "first"); equal(f.entry:IsOpen(), false)
    assert(f.Q.Resume(), "unchanged owned text must still be replaceable after entry closure")
    equal(f.entry:GetText(), "first"); equal(f.entry:IsOpen(), true); equal(#f.sent, 0)
end)

test("simulated focus-loss callback during Submit is ignored without pausing continuation", function(f)
    f.A.saved.debug, f.closeThroughChat, f.echoMode = true, true, "sync"
    f:start(); f:submit()
    local begin, beganAt = traceEvent(f, "SUBMIT_BEGIN")
    local close, closedAt = traceEvent(f, "INPUT_CLOSE", beganAt, { action = "ignore-submit" })
    equal(traceField(close, "submit"), traceField(begin, "id"))
    local _, historyAt = traceEvent(f, "HISTORY_CALLBACK", closedAt, { action = "associate" })
    local _, confirmedAt = traceEvent(f, "ECHO_CONFIRMED", historyAt)
    traceEvent(f, "SUBMIT_END", confirmedAt, { histories = 1, associated = 1 })
    equal(traceCount(f, "PAUSE"), 0); equal(f.Q.paused, false); equal(f.Q.current, 2)
    f:advance(50); equal(f.entry:GetText(), "second"); equal(#f.stages, 2); equal(#f.sent, 1)
end)

test("delayed close after Submit is traced as pause and invalidates the next timer", function(f)
    f.A.saved.debug, f.echoMode = true, "sync"
    f:start(); f:submit()
    local _, endedAt = traceEvent(f, "SUBMIT_END")
    zo_callLater(function() f.chat:CloseTextEntry() end, 1)
    f:advance(1)
    local _, closedAt = traceEvent(f, "INPUT_CLOSE", endedAt, { action = "pause", submit = "-" })
    local pause = traceEvent(f, "PAUSE", closedAt)
    traceReason(pause, f.Q.reason)
    assert(f.Q.paused); equal(f.Q.current, 2); equal(f.Q.pending, nil)
    f:advance(49)
    local timer = traceEvent(f, "NEXT_TIMER", closedAt, { action = "skip" })
    assert(tonumber(traceField(timer, "scheduledGeneration")) < timer.generation)
    equal(#f.stages, 1); equal(#f.sent, 1)
    assert(f.Q.Resume()); traceEvent(f, "RESUME", closedAt)
    equal(f.entry:GetText(), "second"); equal(#f.sent, 1)
end)

test("non-hardware trace explicitly rejects association without suppressing native send", function(f)
    f.A.saved.debug, f.echoMode = true, "sync"
    f:start(); f:submit(false)
    local _, beganAt = traceEvent(f, "SUBMIT_BEGIN", nil,
        { hardware = false, keyboard = true, associate = false, reason = "not-hardware" })
    local _, historyAt = traceEvent(f, "HISTORY_CALLBACK", beganAt,
        { action = "unassociated", reason = "ineligible-submit" })
    traceEvent(f, "SUBMIT_END", historyAt, { histories = 1, associated = 0, stageUnchanged = true })
    equal(traceCount(f, "SUBMISSION_CAPTURED"), 0); equal(traceCount(f, "ECHO_CONFIRMED"), 0)
    equal(f.Q.pending, nil); equal(f.Q.current, 1); assert(f.Q.paused)
    f:advance(20000); equal(#f.stages, 1); equal(#f.sent, 1)
end)

test("missing history callbacks are visible in submit summaries and the original pause reason", function(f)
    f.A.saved.debug = true
    f:start()
    local after = #f.debugLog
    for _, unavailable in ipairs({ true, false }) do
        f.available = not unavailable
        if not unavailable then assert(f.Q.Resume()); f.entry:SetText("") end
        f:submit()
        local _, beganAt = traceEvent(f, "SUBMIT_BEGIN", after, { associate = true, reason = "eligible" })
        local _, endedAt = traceEvent(f, "SUBMIT_END", beganAt,
            { histories = 0, associated = 0, stageUnchanged = true })
        traceReason(traceEvent(f, "PAUSE", beganAt), "Submission was not observable. Check chat and use Next if sent.")
        after = endedAt
        assert(f.Q.paused); equal(f.Q.pending, nil); equal(f.Q.current, 1)
    end
    equal(traceCount(f, "HISTORY_CALLBACK"), 0); equal(traceCount(f, "SUBMISSION_CAPTURED"), 0)
    equal(#f.entry.history, 0); equal(#f.sent, 0)
end)

test("late hook reattachment reports versions and obsolete callbacks without duplicate capture", function(f)
    f.A.saved.debug = true
    f:start({ ":wave:", "last" })
    local history = traceEvent(f, "HOOK_HISTORY_ATTACH", nil, { submissionOpen = false })
    local submit = traceEvent(f, "HOOK_SUBMIT_ATTACH", nil, { submissionOpen = false })
    local after = #f.debugLog
    for _ = 1, 3 do assert(f.C.EnsureHooks()) end
    equal(#f.debugLog, after, "unchanged methods must not emit attachment traces")
    f:pchat(); assert(f.Q.Resume())
    local newHistory = traceEvent(f, "HOOK_HISTORY_ATTACH", after, { submissionOpen = false })
    local newSubmit = traceEvent(f, "HOOK_SUBMIT_ATTACH", after, { submissionOpen = false })
    assert(tonumber(traceField(newHistory, "version")) > tonumber(traceField(history, "version")))
    assert(tonumber(traceField(newSubmit, "version")) > tonumber(traceField(submit, "version")))
    f:submit()
    local _, beganAt = traceEvent(f, "SUBMIT_BEGIN", after, { reason = "eligible" })
    local _, ignoredAt = traceEvent(f, "HISTORY_CALLBACK", beganAt,
        { action = "ignore", reason = "obsolete-hook" })
    local _, associatedAt = traceEvent(f, "HISTORY_CALLBACK", ignoredAt, { action = "associate" })
    traceEvent(f, "SUBMIT_END_IGNORED", associatedAt, { reason = "obsolete-hook" })
    traceEvent(f, "SUBMIT_END", associatedAt, { histories = 1, associated = 1 })
    equal(traceCount(f, "SUBMIT_BEGIN"), 1); equal(traceCount(f, "SUBMISSION_CAPTURED"), 1)
    equal(f.Q.pending.text, "waves warmly"); equal(f.entry.history[1], "/say waves warmly")
    f:ownEcho("waves warmly"); f:advance(50)
    equal(f.entry:GetText(), "last"); equal(#f.sent, 1)
end)

test("history outside a submission is traced as ignored and cannot confirm a chunk", function(f)
    f.A.saved.debug = true
    f:start()
    f.entry:AddCommandHistory("first")
    traceEvent(f, "HISTORY_CALLBACK", nil, { action = "ignore", reason = "no-submission", submit = "-" })
    f:ownEcho("first"); f:advance(10000)
    equal(traceCount(f, "SUBMISSION_CAPTURED"), 0); equal(traceCount(f, "ECHO_CONFIRMED"), 0)
    equal(f.Q.current, 1); equal(f.Q.pending, nil); equal(#f.stages, 1); equal(#f.sent, 0)
end)

test("preparation-time closure is ignored while idle closure stays idle", function(f)
    f.A.saved.debug = true
    local open = f.entry.Open
    f.entry.Open = function(self, text)
        f.chat:CloseTextEntry()
        return open(self, text)
    end
    f:start()
    local _, beganAt = traceEvent(f, "PREPARE_BEGIN")
    local _, entryClosedAt = traceEvent(f, "ENTRY_CLOSE", beganAt,
        { origin = "preparing", keepText = false, preparing = true, submit = "-" })
    local _, closedAt = traceEvent(f, "INPUT_CLOSE", entryClosedAt,
        { action = "ignore-prepare", preparing = true, submit = "-" })
    local _, openedAt = traceEvent(f, "INPUT_OPEN", closedAt, { preparing = true })
    traceEvent(f, "PREPARE_READY", openedAt)
    equal(traceCount(f, "PAUSE"), 0); equal(f.Q.paused, false)
    equal(f.entry:GetText(), "first"); equal(f.Q.current, 1)
    assert(f.Q.Cancel())
    local _, cancelledAt = traceEvent(f, "CANCEL")
    f.chat:CloseTextEntry()
    traceEvent(f, "INPUT_CLOSE", cancelledAt, { action = "idle", submit = "-" })
    equal(f.Q.active, false); equal(#f.sent, 0)
end)

test("trace reports channel change, native reopen, and rejected preparation without sending", function(f)
    f.A.saved.debug = true
    f:start()
    local after = #f.debugLog
    f.chat:SetChannel(CHAT_CHANNEL_PARTY)
    local _, changedAt = traceEvent(f, "CHANNEL_CHANGE", after)
    traceReason(traceEvent(f, "PAUSE", changedAt), f.Q.reason)
    equal(f.Q.channel, CHAT_CHANNEL_SAY); assert(f.Q.paused)
    f.entry:SetText(""); assert(f.Q.Resume())
    after = #f.debugLog
    f.chat:StartTextEntry("SECRET_REOPEN_DRAFT_68t", CHAT_CHANNEL_SAY)
    local _, openedAt = traceEvent(f, "INPUT_OPEN", after, { preparing = false })
    traceReason(traceEvent(f, "PAUSE", openedAt), f.Q.reason)
    after = #f.debugLog
    rejected(f.Q.Resume())
    local _, resumedAt = traceEvent(f, "RESUME", after)
    local _, beganAt = traceEvent(f, "PREPARE_BEGIN", resumedAt)
    local _, rejectedAt = traceEvent(f, "PREPARE_REJECT", beganAt)
    traceReason(traceEvent(f, "PAUSE", rejectedAt), f.Q.reason)
    equal(f.entry:GetText(), "SECRET_REOPEN_DRAFT_68t"); equal(#f.stages, 2); equal(#f.sent, 0)
    assert(not table.concat(f.debugLog, "\n"):find("SECRET_REOPEN_DRAFT_68t", 1, true))
end)

test("ignored echoes, timeout, manual recovery, and cancellation retain diagnostic reasons", function(f)
    f.A.saved.debug = true
    f:start(); f:submit()
    local pending, after = f.Q.pending, #f.debugLog
    local ignored = {
        function() f:ownEcho("not the submitted text") end,
        function() f:ownEcho("first", CHAT_CHANNEL_PARTY) end,
        function() f:emit(CHAT_CHANNEL_SAY, "Foreign Hero", "first", "@Foreign") end,
        function() f:emit(CHAT_CHANNEL_SAY, "Local Hero^Mx", "first", "@Local", true) end,
    }
    for _, emit in ipairs(ignored) do
        emit()
        local record, at = traceEvent(f, "ECHO_IGNORED", after)
        assert(traceField(record, "reason"), "ignored echo must explain why")
        equal(f.Q.pending, pending); equal(f.Q.current, 1)
        after = at
    end
    equal(traceCount(f, "ECHO_CONFIRMED"), 0)
    f:advance(9999); equal(traceCount(f, "ECHO_TIMEOUT"), 0)
    f:advance(1)
    local timeout, timedOutAt = traceEvent(f, "ECHO_TIMEOUT", after)
    equal(timeout.time, f.now)
    traceReason(traceEvent(f, "PAUSE", timedOutAt), f.Q.reason)
    equal(f.Q.pending, pending); assert(f.Q.paused); rejected(f.Q.Resume())
    assert(f.Q.Move(1))
    local _, movedAt = traceEvent(f, "MANUAL_MOVE", timedOutAt)
    traceEvent(f, "STAGED", movedAt)
    equal(f.entry:GetText(), "second"); equal(f.Q.pending, nil)
    assert(f.Q.Cancel()); traceEvent(f, "CANCEL", movedAt)
    f:advance(20000)
    equal(f.Q.active, false); equal(f.entry:GetText(), "second"); equal(#f.stages, 2); equal(#f.sent, 1)
end)

test("cancellation traces a skipped stale timer without preparing a replacement batch", function(f)
    f.A.saved.debug, f.echoMode = true, "sync"
    f:start(); f:submit()
    local scheduled, scheduledAt = traceEvent(f, "NEXT_SCHEDULED")
    assert(f.Q.Cancel())
    local _, cancelledAt = traceEvent(f, "CANCEL", scheduledAt)
    f:start({ "replacement batch" })
    local replacement = traceEvent(f, "BATCH_START", cancelledAt)
    assert(replacement.batch ~= scheduled.batch)
    f:advance(50)
    local timer = traceEvent(f, "NEXT_TIMER", cancelledAt, { action = "skip" })
    assert(tonumber(traceField(timer, "scheduledGeneration")) < timer.generation)
    equal(f.entry:GetText(), "replacement batch"); equal(f.Q.current, 1)
    equal(#f.stages, 2); equal(#f.sent, 1)
end)

test("hook attachment during an open submission is explicitly flagged", function(f)
    f.A.saved.debug = true
    f.commands["/reattach"] = function()
        f:pchat()
        assert(f.C.EnsureHooks())
    end
    f:start(); f.entry:SetText("/reattach"); f:submit()
    local begin, beganAt = traceEvent(f, "SUBMIT_BEGIN")
    local history, historyAt = traceEvent(f, "HOOK_HISTORY_ATTACH", beganAt, { submissionOpen = true })
    local submit, submitAt = traceEvent(f, "HOOK_SUBMIT_ATTACH", historyAt, { submissionOpen = true })
    equal(traceField(history, "submit"), traceField(begin, "id"))
    equal(traceField(submit, "submit"), traceField(begin, "id"))
    traceEvent(f, "SUBMIT_END_IGNORED", submitAt, { reason = "obsolete-hook" })
    -- This is diagnostic coverage, not a change to how an obsolete posthook unwinds.
    equal(f.Q.current, 1); equal(f.Q.pending, nil); assert(f.Q.paused)
    equal(#f.sent, 0); equal(#f.stages, 1)
end)

test("turning debug off silences direct traces, callbacks, timers, and later batches", function(f)
    f.A.saved.debug = true
    f:start(); f:submit()
    traceEvent(f, "SUBMISSION_CAPTURED")
    local logged = #f.debugLog
    f.A.saved.debug = false
    f.C.Trace("TEST_DISABLED")
    f:ownEcho("first"); f:advance(50)
    f.echoMode = "sync"; f:submit()
    equal(f.Q.active, false)
    f:start({ "later batch" }); f:submit(); f:advance(20000)
    equal(f.Q.active, false); equal(#f.sent, 3); equal(#f.debugLog, logged)
end)

test("trace logs never expose text, identities, whisper targets, or fingerprints", function(f)
    f.A.saved.debug = true
    local chunk, edited, nextChunk = "SECRET_CHUNK_71z", "SECRET_EDIT_82q", "SECRET_NEXT_93v"
    local target, sender, account = "@SECRET_TARGET_24w", "SECRET_HERO_35x^Mx", "@SECRET_ACCOUNT_46y"
    GetDisplayName = function() return account end
    GetUnitName = function() return sender end
    f:start({ chunk, nextChunk }, CHAT_CHANNEL_WHISPER, target)
    f.entry:SetText(edited); f:submit()
    local fingerprint = f.Q.pending.key
    f:emit(CHAT_CHANNEL_WHISPER_SENT, sender, "SECRET_WRONG_TEXT_57u", account)
    f:emit(CHAT_CHANNEL_WHISPER_SENT, target, edited, target)
    f:advance(50); f:submit()
    f:emit(CHAT_CHANNEL_WHISPER_SENT, target, nextChunk, target)
    equal(f.Q.active, false)
    -- Exercise the local-sender path as well as recipient matching.
    f:start({ chunk }, CHAT_CHANNEL_SAY); f:submit()
    f:emit(CHAT_CHANNEL_SAY, sender, chunk, account)
    equal(f.Q.active, false); equal(traceCount(f, "ECHO_CONFIRMED"), 3)
    local output = table.concat(f.debugLog, "\n")
    for _, secret in ipairs({ chunk, edited, nextChunk, target, sender, account,
        "SECRET_WRONG_TEXT_57u", "SECRET_HERO_35x", fingerprint }) do
        assert(not output:find(secret, 1, true), "trace leaked private data: " .. secret)
    end
    assert(not output:find("\031", 1, true), "trace leaked fingerprint delimiters")
    equal(#f.sent, 3)
end)

test("translated channel labels and queue reasons leave routes, payloads and developer trace IDs intact", function()
    local f = fixture({ CHAT_CHANNEL_SAY = "Dire", CHAT_CHANNEL_WHISPER = "Chuchoter",
        CHAT_CHANNEL_GUILD = "Guilde %s", CHAT_CHANNEL_OFFICER = "Officier %s",
        QUEUE_READY = "Prêt — Entrée manuelle.", QUEUE_PAUSED = "En pause.",
        QUEUE_WAITING_FOR_ECHO = "En attente.", QUEUE_ALL_CONFIRMED = "Tout confirmé.",
        CHAT_CHANNEL_UNAVAILABLE = "Canal indisponible." })
    equal(f.C.Destinations[1].label, "Dire")
    equal(f.C.Destinations[1].channel, CHAT_CHANNEL_SAY)
    equal(f.C.Destinations[2].label, "Emote", "untranslated fallback")
    equal(f.C.Destinations[4].label, "Chuchoter")
    for i = 1, 5 do
        equal(f.C.Destinations[3 + 2 * i].label, "Guilde " .. i)
        equal(f.C.Destinations[3 + 2 * i].channel, _G["CHAT_CHANNEL_GUILD_" .. i])
        equal(f.C.Destinations[4 + 2 * i].label, "Officier " .. i)
        equal(f.C.Destinations[4 + 2 * i].channel, _G["CHAT_CHANNEL_OFFICER_" .. i])
    end
    f.allowed[CHAT_CHANNEL_PARTY] = false
    local ok, err = f.C.ValidateDestination(CHAT_CHANNEL_PARTY)
    equal(ok, nil); equal(err, "Canal indisponible.")
    f.A.saved.debug = true
    local tag = string.rep("\226\128\139", 4)
    local raw, target = "100% %s <<1>> 雪", "@Zoë%s"
    f:start({ tag .. raw }, CHAT_CHANNEL_WHISPER, target)
    equal(f.Q.reason, "Prêt — Entrée manuelle.")
    equal(f.entry:GetText(), tag .. raw)
    equal(f.chat.currentTarget, target)
    equal(f.Q.target, target); equal(f.Q.channel, CHAT_CHANNEL_WHISPER)
    equal(#f.sent, 0); equal(f.submits, 0)
    assert(f.Q.Pause()); equal(f.Q.reason, "En pause.")
    assert(f.Q.Resume())
    f:submit()
    equal(f.Q.reason, "En attente.")
    equal(f.sent[1].text, tag .. raw); equal(f.sent[1].target, target)
    f:emit(CHAT_CHANNEL_WHISPER_SENT, target, tag .. raw, "")
    equal(f.Q.reason, "Tout confirmé."); equal(f.Q.active, false)
    traceEvent(f, "STAGED", nil, { automatic = false })
    traceEvent(f, "SUBMIT_BEGIN")
    traceEvent(f, "SUBMISSION_CAPTURED")
    traceEvent(f, "ECHO_CONFIRMED")
    traceEvent(f, "RESUME", nil, { action = "request" })
    for _, line in ipairs(f.debugLog) do
        assert(not line:find(raw, 1, true) and not line:find(target, 1, true), "translated trace leaked payload")
    end
    f:checkNoAutomaticSend()
end)

test("already loaded runtime modules read later overrides rather than cached English errors", function(f)
    local ok, err = f.Q.Resume()
    equal(ok, nil); equal(err, "No active queue.")
    f.localization:override({ QUEUE_NOT_ACTIVE = "Aucune file.",
        CHAT_UNSUPPORTED_DESTINATION = "Destination inconnue." }, 2)
    ok, err = f.Q.Resume()
    equal(ok, nil); equal(err, "Aucune file.")
    ok, err = f.C.ValidateDestination(-999)
    equal(ok, nil); equal(err, "Destination inconnue.")
    equal(f.submits, 0); equal(#f.stages, 0)
end)

local passed, failed = 0, 0
for _, case in ipairs(tests) do
    local ok, err = xpcall(function()
        local f = fixture()
        case[2](f)
        f:checkNoAutomaticSend()
    end, debug.traceback)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL queue_chat_spec: " .. case[1] .. "\n" .. tostring(err))
    end
end
print("queue_chat_spec: " .. passed .. " passed, " .. failed .. " failed (" .. #tests .. " tests)")
assert(failed == 0, "queue_chat_spec: " .. failed .. " contract test(s) failed")
