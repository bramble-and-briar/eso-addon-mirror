-- Run from the repository root: python3 tests/run.py tests/bootstrap_spec.lua
-- Lua 5.1-compatible contract tests; no actual UI controls or native submissions.
local localization = dofile("tests/localization_fixture.lua")
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected "
        .. tostring(expected) .. ", got " .. tostring(actual))
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function deepEqual(actual, expected, label)
    if type(expected) ~= "table" then return equal(actual, expected, label) end
    equal(type(actual), "table", label)
    for key, value in pairs(expected) do deepEqual(actual[key], value, tostring(key)) end
    for key in pairs(actual) do assert(expected[key] ~= nil, "unexpected key: " .. tostring(key)) end
end

local function rejected(ok, err)
    equal(ok, nil, "rejected result")
    assert(type(err) == "string" and err ~= "", "rejection must explain the problem")
end

local function contains(text, fragment)
    assert(type(text) == "string" and text:find(fragment, 1, true), "missing text: " .. fragment)
end

CHAT_CHANNEL_SAY, CHAT_CHANNEL_EMOTE, CHAT_CHANNEL_PARTY = 0, 13, 19
CHAT_CHANNEL_WHISPER, CHAT_CHANNEL_WHISPER_SENT = 31, 32
for index = 1, 5 do
    _G["CHAT_CHANNEL_GUILD_" .. index] = 200 + index * 3
    _G["CHAT_CHANNEL_OFFICER_" .. index] = 300 + index * 3
end
EVENT_ADD_ON_LOADED, EVENT_PLAYER_ACTIVATED = 101, 102
EVENT_PLAYER_DEACTIVATED, EVENT_CHAT_MESSAGE_CHANNEL = 103, 104

local function fixture(saved, options)
    options = options or {}
    local f = {
        saved = saved or {}, handlers = {}, registrations = {}, unregistrations = {},
        logs = {}, notices = {}, savedCalls = {}, loaded = {},
        init = 0, refresh = 0, toggle = 0, worldCalls = 0,
        starts = 0, prepares = 0, stages = 0, sends = 0, timers = {},
        controlLimit = options.controlLimit or 73, world = options.world or "EU Megaserver",
        api = options.api or 101050, draft = "PRIVATE_NATIVE_DRAFT_é_9472",
    }
    MAX_TEXT_CHAT_INPUT_CHARACTERS = options.nativeLimit or 97
    SLASH_COMMANDS = {}
    RoleplayPostSupport = { sentinel = {} }
    local root = RoleplayPostSupport
    f.localization = localization.install()
    equal(root.L, nil, "bootstrap must start without localization helper")
    local eventManager = {}
    function eventManager:RegisterForEvent(namespace, event, callback)
        equal(namespace, "RoleplayPostSupport", "event namespace")
        equal(type(callback), "function", "event callback")
        f.handlers[event] = f.handlers[event] or {}
        f.handlers[event][namespace] = callback
        f.registrations[event] = (f.registrations[event] or 0) + 1
    end
    function eventManager:UnregisterForEvent(namespace, event)
        equal(namespace, "RoleplayPostSupport", "unregister namespace")
        if f.handlers[event] then f.handlers[event][namespace] = nil end
        f.unregistrations[event] = (f.unregistrations[event] or 0) + 1
    end
    EVENT_MANAGER = eventManager
    function f:handler(event)
        return self.handlers[event] and self.handlers[event].RoleplayPostSupport
    end
    function f:emit(event, ...)
        local callback = self:handler(event)
        if callback then callback(event, ...) end
    end
    function f:activate()
        self:emit(EVENT_ADD_ON_LOADED, "RoleplayPostSupport")
        self:emit(EVENT_PLAYER_ACTIVATED)
        return self.A
    end

    GetWorldName = function() f.worldCalls = f.worldCalls + 1; return f.world end
    GetAPIVersion = function() return f.api end
    GetTimeStamp = function() return 1700000000 end
    GetDisplayName = function() return "@Local" end
    GetUnitName = function(unit) equal(unit, "player"); return "Local Hero" end
    d = function(message) f.logs[#f.logs + 1] = message end
    local savedVars = {}
    function savedVars:NewAccountWide(...)
        local args = { n = select("#", ...), ... }
        f.savedCalls[#f.savedCalls + 1] = args
        equal(args.n, 5, "account-wide argument count")
        equal(args[1], "RoleplayPostSupportSavedVariables", "SavedVars name")
        equal(args[2], 1, "SavedVars version")
        equal(args[3], nil, "SavedVars namespace")
        equal(args[5], f.world, "world profile")
        deepEqual(args[4], { prefix = "+ ", suffix = " +", sentences = true,
            debug = false, historyNewestFirst = false, window = {} }, "defaults")
        -- ESO fills missing defaults, but does not sanitize existing saved values.
        for key, value in pairs(args[4]) do
            if f.saved[key] == nil then f.saved[key] = copy(value) end
        end
        return f.saved
    end
    savedVars.NewCharacterIdSettings = function() error("settings must be account-wide") end
    ZO_SavedVars = savedVars

    local edit = { GetMaxInputChars = function() return f.controlLimit end }
    local entry = {
        GetEditControl = function() return edit end,
        GetText = function() return f.draft end,
    }
    local function forbiddenSend()
        f.sends = f.sends + 1
        error("bootstrap/commands must never submit chat")
    end
    f.chat = { textEntry = entry, currentChannel = CHAT_CHANNEL_SAY,
        SubmitTextEntry = forbiddenSend }
    ZO_GetChatSystem = function() return f.chat end
    IsInGamepadPreferredMode = function() return false end
    StartChatInput = function()
        f.stages = f.stages + 1
        error("unexpected native input preparation")
    end
    SendChatMessage, RequestChatMessage = forbiddenSend, forbiddenSend
    zo_callLater = function(callback, delay)
        f.timers[#f.timers + 1] = { callback = callback, delay = delay }
    end

    -- Follow the actual manifest, replacing only its UI module with four spies.
    for line in io.lines("RoleplayPostSupport.txt") do
        local name = line:match("^%s*(.-)%s*$")
        if name:match("%.lua$") then
            f.loaded[#f.loaded + 1] = name
            if name == "lang/$(language).lua" then
                            f.localeLoaded = f.localization:loadLanguage(options.language or "en", options.translations)
                        elseif name == "RoleplayPostSupport_UI.lua" then
                RoleplayPostSupport.UI = {
                    Init = function()
                        assert(RoleplayPostSupport.saved, "UI initialized before SavedVars")
                        f.init = f.init + 1
                    end,
                    Refresh = function() f.refresh = f.refresh + 1 end,
                    Toggle = function() f.toggle = f.toggle + 1 end,
                    Notify = function(message) f.notices[#f.notices + 1] = message end,
                }
            else
                if name == "RoleplayPostSupport.lua" then
                    equal(root.L, nil, "helper not loaded ahead of bootstrap")
                    equal(#f.localization.creates, 0, "catalog not loaded ahead of bootstrap")
                elseif name == "RoleplayPostSupport_Localization.lua" then
                    equal(#f.localization.creates, 168, "English catalog precedes helper")
                end
                dofile(name)
            end
        end
    end
    equal(RoleplayPostSupport, root, "shared namespace root")
    f.A = RoleplayPostSupport
    -- Transparent observation also catches attempted staging that native validation rejects.
    local start, prepare = f.A.Queue.Start, f.A.Chat.Prepare
    f.A.Queue.Start = function(...)
        f.starts = f.starts + 1
        return start(...)
    end
    f.A.Chat.Prepare = function(...)
        f.prepares = f.prepares + 1
        return prepare(...)
    end
    function f:noChat()
        equal(self.starts, 0, "queue starts")
        equal(self.prepares, 0, "chat preparation attempts")
        equal(self.stages, 0, "native stages")
        equal(self.sends, 0, "native submissions")
        equal(self.draft, "PRIVATE_NATIVE_DRAFT_é_9472", "native draft unchanged")
        equal(#self.timers, 0, "scheduled work")
    end
    return f
end

local function recordingSession(A)
    local session = assert(A.Sessions.Create("Evening RP", CHAT_CHANNEL_SAY))
    equal(A.Sessions.Select(session.id), session)
    assert(A.Sessions.SetRecording(true))
    return session
end

local tests = {}
local function test(name, body) tests[#tests + 1] = { name, body } end

test("manifest loads real modules; addon filtering defers slash and initialization", function()
    local f = fixture()
    deepEqual(f.loaded, { "RoleplayPostSupport.lua", "lang/default.lua", "lang/$(language).lua",
            "RoleplayPostSupport_Localization.lua", "RoleplayPostSupport_Splitter.lua",
        "RoleplayPostSupport_Sessions.lua", "RoleplayPostSupport_Queue.lua",
        "RoleplayPostSupport_Chat.lua", "RoleplayPostSupport_UI.lua" })
    equal(f.A.name, "RoleplayPostSupport")
    equal(f.A.version, "1.2.2")
    local manifestFile = assert(io.open("RoleplayPostSupport.txt", "r"))
    local manifest = manifestFile:read("*a")
    manifestFile:close()
    equal(manifest:match("## Version: ([^\r\n]+)"), f.A.version, "manifest/runtime version")
    equal(manifest:match("## AddOnVersion: (%d+)"), "10202", "numeric release version")
    for _, module in ipairs({ "Splitter", "Sessions", "Queue", "Chat" }) do
        equal(type(f.A[module]), "table", module)
    end
    equal(f.registrations[EVENT_ADD_ON_LOADED], 1)
    equal(SLASH_COMMANDS["/rps"], nil)
    equal(SLASH_COMMANDS["/lrp"], nil, "legacy command not registered")
    f:emit(EVENT_PLAYER_ACTIVATED)
    f:emit(EVENT_ADD_ON_LOADED, "SomeOtherAddon")
    f:emit(EVENT_ADD_ON_LOADED, "roleplaypostsupport")
    equal(f.A.saved, nil)
    equal(f.init, 0)
    equal(#f.savedCalls, 0)
    equal(f:handler(EVENT_PLAYER_ACTIVATED), nil)
    equal(f.unregistrations[EVENT_ADD_ON_LOADED], nil)
    equal(SLASH_COMMANDS["/rps"], nil)
    f:emit(EVENT_ADD_ON_LOADED, "RoleplayPostSupport")
    equal(type(SLASH_COMMANDS["/rps"]), "function")
    equal(SLASH_COMMANDS["/lrp"], nil, "legacy command not registered")
    equal(type(f:handler(EVENT_PLAYER_ACTIVATED)), "function")
    equal(f:handler(EVENT_ADD_ON_LOADED), nil)
    equal(f.unregistrations[EVENT_ADD_ON_LOADED], 1)
    equal(f.init, 0)
    equal(#f.savedCalls, 1)
    equal(f.A.saved, f.saved)
    equal(f.saved.nextSessionId, 1, "sessions initialized during addon-loaded")
    equal(f.saved.historyNewestFirst, false, "legacy/missing display preference defaults to oldest first")
    equal(f.saved.maxChars, nil, "native limit deferred until activation")
    f:noChat()
end)

test("all slash commands are safe before player activation", function()
    local f = fixture()
    f:emit(EVENT_ADD_ON_LOADED, "RoleplayPostSupport")
    local slash = SLASH_COMMANDS["/rps"]
    slash()
    for _, command in ipairs({ "", "test", "debug", "cancel", "pause", "resume", "next", "previous", "unknown" }) do
        slash(command)
        contains(f.notices[#f.notices], "Waiting for the player UI")
    end
    equal(#f.notices, 10)
    equal(#f.logs, 10)
    equal(f.toggle, 0)
    equal(f.refresh, 0)
    equal(f.A.saved, f.saved)
    equal(#f.savedCalls, 1)
    f:noChat()
end)

test("addon-loaded initializes world settings; activation initializes UI exactly once", function()
    local f = fixture()
    f:emit(EVENT_ADD_ON_LOADED, "RoleplayPostSupport")
    local activated = f:handler(EVENT_PLAYER_ACTIVATED)
    equal(#f.savedCalls, 1, "SavedVars must initialize in addon-loaded")
    equal(f.init, 0, "UI deferred until activation")
    f:emit(EVENT_PLAYER_ACTIVATED)
    equal(f.A.saved, f.saved)
    equal(f.saved.maxChars, 73, "runtime-derived default")
    equal(#f.savedCalls, 1)
    equal(f.worldCalls, 1)
    equal(f.init, 1)
    equal(#f.A.Chat.Destinations, 14, "real Chat.Init")
    deepEqual(f.A.Sessions.List(), {})
    equal(f.saved.nextSessionId, 1, "real Sessions.Init")
    equal(f:handler(EVENT_CHAT_MESSAGE_CHANNEL), f.A.Chat.OnMessage)
    equal(type(f:handler(EVENT_PLAYER_DEACTIVATED)), "function")
    equal(f:handler(EVENT_PLAYER_ACTIVATED), nil)
    equal(f.unregistrations[EVENT_PLAYER_ACTIVATED], 1)
    local session = recordingSession(f.A)
    f.saved.maxChars = 41
    activated(EVENT_PLAYER_ACTIVATED) -- Exercise the ready guard, not only unregistration.
    f:emit(EVENT_ADD_ON_LOADED, "RoleplayPostSupport")
    f:emit(EVENT_PLAYER_ACTIVATED)
    equal(#f.savedCalls, 1)
    equal(f.worldCalls, 1)
    equal(f.init, 1)
    equal(f.saved.maxChars, 41)
    equal(f.A.Sessions.Current(), session)
    equal(f.A.Sessions.IsRecording(), true, "sessions not reinitialized")
    equal(f.registrations[EVENT_PLAYER_ACTIVATED], 1)
    equal(f.registrations[EVENT_CHAT_MESSAGE_CHANNEL], 1)
    equal(f.registrations[EVENT_PLAYER_DEACTIVATED], 1)
    equal(#f.logs, 0, "supported API is quiet by default")
    f:noChat()
end)

test("default max follows either native limit source, not a hardcoded value", function()
    for _, options in ipairs({
        { nativeLimit = 61, controlLimit = 89 },
        { nativeLimit = 0, controlLimit = 83, world = "NA Megaserver" },
        { nativeLimit = 67, controlLimit = 0 },
    }) do
        local f = fixture(nil, options)
        f:activate()
        equal(f.saved.maxChars, options.nativeLimit > 0 and options.nativeLimit or options.controlLimit)
        equal(f.savedCalls[1][5], options.world or "EU Megaserver")
        f:noChat()
    end
end)

test("valid saved preferences and unrelated data survive activation", function()
    local saved = { maxChars = 29, prefix = "é ", suffix = " →", sentences = false,
        debug = true, historyNewestFirst = true,
        window = { left = 123, top = 45 }, custom = { keep = true } }
    local expected = copy(saved)
    local f = fixture(saved)
    f:activate()
    for key, value in pairs(expected) do deepEqual(saved[key], value, key) end
    contains(f.logs[1], "DEBUG: Initialized, runtime limit 73")
    f:noChat()
end)

test("saved history order survives activation and reload without changing the schema", function()
    for _, newestFirst in ipairs({ false, true }) do
        local saved = { historyNewestFirst = newestFirst }
        for load = 1, 2 do
            local f = fixture(saved)
            f:emit(EVENT_ADD_ON_LOADED, "RoleplayPostSupport")
            equal(f.saved.historyNewestFirst, newestFirst, "saved order before UI initialization")
            equal(f.savedCalls[1][2], 1, "unchanged SavedVars schema")
            f:emit(EVENT_PLAYER_ACTIVATED)
            equal(f.saved.historyNewestFirst, newestFirst, "saved order after activation")
            f:noChat()
        end
    end
end)

local corruptions = {
    { "string max", "maxChars", "forty" }, { "zero max", "maxChars", 0 },
    { "negative max", "maxChars", -1 }, { "fractional max", "maxChars", 12.5 },
    { "tag-only budget", "maxChars", 4 },
    { "oversized max", "maxChars", 74 }, { "infinite max", "maxChars", math.huge },
    { "NaN max", "maxChars", 0 / 0 }, { "nontext prefix", "prefix", false },
    { "nontext suffix", "suffix", {} }, { "invalid sentences", "sentences", "yes" },
    { "malformed UTF-8 marker", "prefix", string.char(255) },
    { "unsafe marker", "suffix", "|Hprivate-link|h" },
    { "oversized markers", "prefix", string.rep("é", 73) },
}
for _, corruption in ipairs(corruptions) do
    local case = corruption
    test("corrupt " .. case[1] .. " resets preferences without losing archives", function()
        local archive = { id = 7, name = "Keep me", channel = CHAT_CHANNEL_SAY,
            participants = { "@Friend" }, messages = { { text = "PRIVATE_ARCHIVE_421" } } }
        local saved = { maxChars = 37, prefix = "« ", suffix = " »", sentences = false,
            sessions = { archive }, nextSessionId = 42, window = { left = 9 }, debug = false }
        saved[case[2]] = case[3]
        local sessions, messages, expected = saved.sessions, archive.messages, copy(archive)
        local f = fixture(saved)
        f:activate()
        equal(saved.maxChars, 73)
        equal(saved.prefix, "+ ")
        equal(saved.suffix, " +")
        equal(saved.sentences, true)
        equal(saved.sessions, sessions, "archive collection identity")
        equal(saved.sessions[1], archive, "session identity")
        equal(archive.messages, messages, "message collection identity")
        deepEqual(archive, expected)
        equal(saved.nextSessionId, 42)
        deepEqual(saved.window, { left = 9 })
        equal(saved.debug, false)
        equal(f.A.Sessions.Get(7), archive)
        equal(#f.notices, 1)
        contains(f.notices[1], "Chat preferences reset")
        contains(f.notices[1], "archives were preserved")
        assert(not f.logs[1]:find("PRIVATE_ARCHIVE_421", 1, true))
        f:noChat()
    end)
end

test("ApplySettings accepts boundary values, UTF-8 markers, and sentence preferences", function()
    local f = fixture()
    local A = f:activate()
    assert(A.ApplySettings(5, "", "", false))
    deepEqual(assert(A.Preview("éñ")), { "é", "ñ" })
    assert(A.ApplySettings(73, "", "", true))
    equal(f.saved.maxChars, 73)
    assert(A.ApplySettings(9, "é ", " →", false))
    equal(f.saved.prefix, "é ")
    equal(f.saved.suffix, " →")
    equal(f.saved.sentences, false)
    deepEqual(assert(A.Preview("abcdefgh")), { "abc →", "é d →", "é e →", "é fgh" })
    assert(A.ApplySettings(22, "", "", true))
    equal(assert(A.Preview("One. two three four five six"))[1], "One.")
    assert(A.ApplySettings(22, "", "", false))
    equal(assert(A.Preview("One. two three four five six"))[1], "One. two three")
    f:noChat()
end)

test("ApplySettings rejects invalid maxima atomically, including a reduced runtime limit", function()
    local f = fixture()
    local A = f:activate()
    assert(A.ApplySettings(25, "«", "»", false))
    local before = copy(f.saved)
    for _, value in ipairs({ "25", false, {}, 0, -1, 1, 2, 3, 4, 5.5, 74, math.huge, -math.huge, 0 / 0 }) do
        rejected(A.ApplySettings(value, "+ ", " +", true))
        deepEqual(f.saved, before, "invalid max leaves settings unchanged")
    end
    rejected(A.ApplySettings(nil, "", "", true))
    f.controlLimit = 20
    rejected(A.ApplySettings(25, "", "", true))
    deepEqual(f.saved, before)
    f:noChat()
end)

test("ApplySettings rejects malformed, unsafe, and overbudget markers atomically", function()
    local f = fixture()
    local A = f:activate()
    local before = copy(f.saved)
    for _, marker in ipairs({ false, {}, string.char(255), string.char(195),
        "|cffffff", "\n", "\r", "\000", "\t", string.rep("é", 12) }) do
        rejected(A.ApplySettings(16, marker, "", false))
        deepEqual(f.saved, before)
        rejected(A.ApplySettings(16, "", marker, false))
        deepEqual(f.saved, before)
    end
    rejected(A.ApplySettings(12, nil, "", false))
    rejected(A.ApplySettings(12, "", nil, false))
    rejected(A.ApplySettings(12, " /say ", "", false))
    rejected(A.ApplySettings(8, "é ", " →", false))
    for _, preference in ipairs({ 0, "false", {} }) do
        rejected(A.ApplySettings(12, "", "", preference))
    end
    rejected(A.ApplySettings(12, "", "", nil))
    deepEqual(f.saved, before)
    f:noChat()
end)

test("Preview clamps to current runtime limit without staging, persisting, or recording drafts", function()
    local f = fixture()
    local A = f:activate()
    assert(A.ApplySettings(60, "é ", " →", false))
    local session = recordingSession(A)
    local before = copy(f.saved)
    local draft = string.rep("ñ", 20)
    f.controlLimit = 12
    local chunks = assert(A.Preview(draft))
    deepEqual(chunks, { string.rep("ñ", 6) .. " →", "é " .. string.rep("ñ", 4) .. " →",
        "é " .. string.rep("ñ", 4) .. " →", "é " .. string.rep("ñ", 6) })
    for _, chunk in ipairs(chunks) do assert(assert(A.Splitter.Length(chunk)) <= 8) end
    equal(f.saved.maxChars, 60, "clamp does not overwrite preference")
    equal(#session.messages, 0)
    deepEqual(f.saved, before)
    equal(A.Queue.active, false)
    equal(#A.Queue.chunks, 0)
    rejected(A.Preview(" /say PRIVATE_COMMAND_746"))
    rejected(A.Preview(string.char(255)))
    rejected(A.Preview("   "))
    equal(#f.logs, 0)
    f:noChat()
end)

test("Preview reserves four Unicode scalars from the lesser saved or runtime budget", function()
    for _, limits in ipairs({ { saved = 9, runtime = 12 }, { saved = 12, runtime = 9 } }) do
        local f = fixture()
        local A = f:activate()
        local S = A.Splitter
        equal(S.MESSAGE_TAG, string.rep("\226\128\139", 4), "four U+200B marker")
        equal(S.MESSAGE_TAG_LENGTH, 4)
        equal(S.Length(S.MESSAGE_TAG), 4)
        equal(#S.MESSAGE_TAG, 12, "marker bytes are not its native character budget")
        assert(A.ApplySettings(limits.saved, "é ", " →", false))
        f.controlLimit = limits.runtime
        local before = copy(f.saved)
        local chunks = assert(A.Preview("é猫😀ñøabç"))
        deepEqual(chunks, { "é猫😀 →", "é ñ →", "é ø →", "é abç" })
        for _, chunk in ipairs(chunks) do
            local body, marked = S.StripMessageTag(chunk)
            equal(body, chunk); equal(marked, false, "preview is readable and untagged")
            equal(S.Length(chunk), 5, "body includes Unicode continuation markers")
            equal(S.Length(S.MESSAGE_TAG .. chunk), 9, "total wire budget")
        end
        deepEqual(f.saved, before)
        f:noChat()
    end
end)

test("copied drafts strip exactly one known leading tag before preview validation", function()
    local f = fixture()
    local A = f:activate()
    local tag, zwsp = A.Splitter.MESSAGE_TAG, "\226\128\139"
    assert(A.ApplySettings(73, "", "", false))
    deepEqual(assert(A.Preview(tag .. "é猫😀")), { "é猫😀" })
    deepEqual(assert(A.Preview(tag .. tag .. "body")), { tag .. "body" })
    for _, draft in ipairs({ zwsp .. "body", zwsp:rep(3) .. "body", "body" .. tag .. "end" }) do
        deepEqual(assert(A.Preview(draft)), { draft }, "partial/interior tags are ordinary text")
    end
    for _, draft in ipairs({ tag, tag .. "   ", tag .. "/say unsafe", tag .. "  /reloadui" }) do
        rejected(A.Preview(draft))
        rejected(A.Start(draft, CHAT_CHANNEL_SAY))
    end
    f:noChat()
end)

test("runtime with no space beyond the tag fails before queue delegation", function()
    local f = fixture()
    local A = f:activate()
    assert(A.ApplySettings(5, "", "", false))
    deepEqual(assert(A.Preview("😀")), { "😀" }, "minimum budget leaves one scalar")
    local before = copy(f.saved)
    for limit = 1, 4 do
        f.controlLimit = limit
        rejected(A.ApplySettings(5, "", "", false))
        rejected(A.Preview("😀"))
        rejected(A.Start("😀", CHAT_CHANNEL_SAY))
        equal(A.Queue.active, false)
        deepEqual(f.saved, before)
    end
    f:noChat()
end)

test("unavailable native limit fails closed and warns without staging", function()
    local f = fixture(nil, { nativeLimit = 0, controlLimit = 0 })
    local A = f:activate()
    equal(f.init, 1)
    equal(f.saved.maxChars, nil)
    contains(f.notices[1], "Unable to read ESO's chat input limit")
    local before = copy(f.saved)
    rejected(A.ApplySettings(20, "", "", true))
    rejected(A.Preview("PRIVATE_BODY_135"))
    rejected(A.Start("PRIVATE_BODY_135", CHAT_CHANNEL_SAY))
    deepEqual(f.saved, before)
    f:noChat()
end)

test("slash test exercises the real splitter but never starts, stages, sends, or archives", function()
    local f = fixture()
    local A = f:activate()
    local session = recordingSession(A)
    local before = copy(f.saved)
    SLASH_COMMANDS["/rps"](" \tTeSt\n")
    contains(f.notices[#f.notices], "6 splitter smoke tests passed")
    contains(f.notices[#f.notices], "No chat input was prepared or sent")
    equal(#f.logs, 1)
    equal(#session.messages, 0)
    equal(A.Queue.active, false)
    deepEqual(f.saved, before)
    f:noChat()
end)

test("debug toggles status and metadata only; no native, preview, queue, or archive content", function()
    local f = fixture()
    local A = f:activate()
    local secrets = { f.draft, "PRIVATE_PREVIEW_872", "PRIVATE_QUEUE_813", "PRIVATE_ARCHIVE_659" }
    local session = recordingSession(A)
    session.messages[1] = { text = secrets[4] }
    A.Queue.chunks = { secrets[3] }
    A.Debug("disabled diagnostic")
    equal(#f.logs, 0)
    SLASH_COMMANDS["/rps"](" DeBuG ")
    equal(f.saved.debug, true)
    contains(f.logs[1], "Debug ON; API 101050, native limit 73")
    assert(A.Preview(secrets[2]))
    A.Debug("Confirmed chunk 1/2")
    contains(f.logs[2], "DEBUG: Confirmed chunk 1/2")
    SLASH_COMMANDS["/rps"]("test")
    SLASH_COMMANDS["/rps"]("debug")
    equal(f.saved.debug, false)
    contains(f.logs[#f.logs], "Debug OFF")
    local count = #f.logs
    A.Debug("disabled again")
    equal(#f.logs, count)
    for _, output in ipairs({ f.logs, f.notices }) do
        for _, message in ipairs(output) do
            for _, secret in ipairs(secrets) do
                assert(not message:find(secret, 1, true), "private content leaked into status/debug output")
            end
        end
    end
    f:noChat()
end)

test("Start delegates tagged chunks, trims whisper targets, and strips other targets", function()
    local f = fixture()
    local A = f:activate()
    assert(A.ApplySettings(12, "", "", false))
    local calls = {}
    local queueResult
    A.Queue.Start = function(chunks, channel, target)
        calls[#calls + 1] = { chunks = chunks, channel = channel, target = target }
        return queueResult, "queue sentinel refusal"
    end
    local destinations = {
        { CHAT_CHANNEL_WHISPER, " \t@Friend \r\n", "@Friend" },
        { CHAT_CHANNEL_WHISPER, "  First Last  ", "First Last" },
        { CHAT_CHANNEL_WHISPER, nil, "" },
        { CHAT_CHANNEL_WHISPER, "  \t", "" },
        { CHAT_CHANNEL_SAY, "@Discard" }, { CHAT_CHANNEL_EMOTE, "@Discard" },
        { CHAT_CHANNEL_PARTY, "@Discard" }, { CHAT_CHANNEL_GUILD_1, "@Discard" },
        { CHAT_CHANNEL_OFFICER_1, "@Discard" },
    }
    for _, destination in ipairs(destinations) do
        local ok, err = A.Start("abcdefghijk", destination[1], destination[2])
        equal(ok, nil)
        equal(err, "queue sentinel refusal", "queue result propagated")
        local call = calls[#calls]
        deepEqual(call.chunks, { A.Splitter.MESSAGE_TAG .. "abcdefgh", A.Splitter.MESSAGE_TAG .. "ijk" })
        equal(call.channel, destination[1])
        equal(call.target, destination[3])
    end
    equal(#calls, #destinations)
    rejected(A.Start("/say unsafe", CHAT_CHANNEL_WHISPER, "@Friend"))
    equal(#calls, #destinations, "failed preview must not reach queue")
    queueResult = true
    equal(A.Start("safe", CHAT_CHANNEL_SAY, "ignored"), true)
    f:noChat()
end)

test("player deactivation pauses real queue, clears staged state, and disarms recording", function()
    local f = fixture()
    local A = f:activate()
    local session = recordingSession(A)
    -- Seed queue state rather than emulate UI controls or native submission hooks.
    local Q = A.Queue
    Q.active, Q.paused, Q.current = true, false, 1
    Q.chunks, Q.channel, Q.target = { "PRIVATE_QUEUED_926", "next" }, CHAT_CHANNEL_WHISPER, "@Friend"
    Q.staged = { text = Q.chunks[1], index = 1, generation = Q.generation }
    local chunks, generation, refreshes = Q.chunks, Q.generation, f.refresh
    f:emit(EVENT_PLAYER_DEACTIVATED)
    equal(Q.active, true)
    equal(Q.paused, true)
    equal(Q.staged, nil)
    equal(Q.generation, generation + 1)
    equal(Q.chunks, chunks)
    equal(Q.current, 1)
    equal(Q.channel, CHAT_CHANNEL_WHISPER)
    equal(Q.target, "@Friend")
    contains(Q.reason, "Player deactivated / zoning")
    contains(Q.reason, "Resume explicitly")
    equal(A.Sessions.IsRecording(), false)
    equal(A.Sessions.Current(), session)
    equal(#session.messages, 0)
    assert(f.refresh > refreshes, "deactivation must refresh UI")
    f:emit(EVENT_PLAYER_ACTIVATED)
    equal(Q.paused, true, "reactivation must not auto-resume")
    equal(A.Sessions.IsRecording(), false)
    equal(f.init, 1)
    f:noChat()
end)

test("deactivation disarms recording even without an active queue", function()
    local f = fixture()
    local A = f:activate()
    recordingSession(A)
    local generation, refreshes = A.Queue.generation, f.refresh
    f:emit(EVENT_PLAYER_DEACTIVATED)
    equal(A.Sessions.IsRecording(), false)
    equal(A.Queue.active, false)
    equal(A.Queue.paused, false)
    equal(A.Queue.generation, generation)
    equal(f.refresh, refreshes + 1)
    f:noChat()
end)

test("registered chat event reaches real Sessions and stops recording after deactivation", function()
    local f = fixture()
    local A = f:activate()
    local session = recordingSession(A)
    f:emit(EVENT_CHAT_MESSAGE_CHANNEL, CHAT_CHANNEL_SAY, "Local Hero", "Observed, not a draft", false, "@Local")
    equal(#session.messages, 1)
    equal(session.messages[1].text, "Observed, not a draft")
    equal(f.refresh, 1)
    f:emit(EVENT_PLAYER_DEACTIVATED)
    f:emit(EVENT_CHAT_MESSAGE_CHANNEL, CHAT_CHANNEL_SAY, "Local Hero", "After zoning", false, "@Local")
    equal(#session.messages, 1)
    f:noChat()
end)

test("ready slash commands toggle UI, refuse idle actions, cancel safely, and do not echo unknown input", function()
    local f = fixture()
    local A = f:activate()
    local slash = SLASH_COMMANDS["/rps"]
    equal(SLASH_COMMANDS["/lrp"], nil, "legacy command not registered after activation")
    slash()
    slash(" \t\n")
    equal(f.toggle, 2)
    for _, command in ipairs({ " PaUsE ", "resume", "next", "previous" }) do
        local count = #f.notices
        slash(command)
        equal(#f.notices, count + 1)
        contains(f.notices[#f.notices], "No active queue")
    end
    slash("cancel")
    slash("cancel")
    equal(A.Queue.active, false)
    equal(#A.Queue.chunks, 0)
    equal(f.refresh, 2)
    slash("unknown PRIVATE_ARGUMENT_619 |cffffff")
    contains(f.notices[#f.notices], "/rps | test | debug")
    contains(f.notices[#f.notices], "never send")
    for _, message in ipairs(f.logs) do
        assert(not message:find("PRIVATE_ARGUMENT_619", 1, true))
        assert(not message:find("|", 1, true), "chat status must strip pipe markup")
    end
    f:noChat()
end)

test("active pause and cancel commands use real queue without staging or sending", function()
    local f = fixture()
    local A = f:activate()
    local Q = A.Queue
    Q.active, Q.current, Q.channel = true, 1, CHAT_CHANNEL_SAY
    Q.chunks, Q.staged = { "PRIVATE_QUEUE_287" }, { text = "PRIVATE_QUEUE_287" }
    SLASH_COMMANDS["/rps"]("pause")
    equal(Q.active, true)
    equal(Q.paused, true)
    equal(Q.staged, nil)
    SLASH_COMMANDS["/rps"]("cancel")
    equal(Q.active, false)
    equal(Q.paused, false)
    equal(Q.current, 0)
    equal(Q.channel, nil)
    equal(#Q.chunks, 0)
    f:noChat()
end)

test("both declared APIs initialize without a compatibility warning", function()
    for _, api in ipairs({ 101050, 101051 }) do
        local f = fixture(nil, { api = api })
        f:activate()
        equal(f.init, 1)
        equal(#f.notices, 0)
        equal(#f.logs, 0)
        f:noChat()
    end
end)

test("unsupported API reports version warning once without disabling bootstrap", function()
    local f = fixture(nil, { api = 101052 })
    f:activate()
    equal(f.init, 1)
    equal(#f.notices, 1)
    contains(f.notices[1], "Supported APIs: 101050, 101051")
    contains(f.notices[1], "this client uses 101052")
    f:emit(EVENT_PLAYER_ACTIVATED)
    equal(#f.notices, 1)
    SLASH_COMMANDS["/rps"]("")
    equal(f.toggle, 1)
    f:noChat()
end)

test("missing locale retains English and registers defaults only once through repeated events", function()
    local f = fixture(nil, { language = "zz-missing", api = 101052 })
    equal(f.localeLoaded, false)
    f:activate(); f:activate()
    equal(#f.localization.creates, 168)
    equal(#f.localization.versionCalls, 168)
    equal(#f.notices, 1)
    equal(f.notices[1], "Supported APIs: 101050, 101051; this client uses 101052. Recheck chat behavior before use.")
    f:noChat()
end)

test("in-memory locale overrides precede helper/modules and translate bootstrap warning", function()
    local f = fixture(nil, { language = "zz-test", api = 101099, translations = {
        ["zz-test"] = { CORE_UNSUPPORTED_API = "Client non pris en charge : %s (100%%).",
            CHAT_CHANNEL_SAY = "Dire" },
    } })
    equal(f.localeLoaded, true)
    f:activate()
    equal(f.A.Chat.Destinations[1].label, "Dire")
    equal(f.A.Chat.Destinations[1].channel, CHAT_CHANNEL_SAY)
    equal(f.A.Chat.Destinations[2].label, "Emote", "subset fallback")
    equal(#f.notices, 1)
    equal(f.notices[1], "Client non pris en charge : 101099 (100%).")
    equal(f.logs[1], "[RoleplayPostSupport] Client non pris en charge : 101099 (100%).")
    equal(f.saved.prefix, "+ "); equal(f.saved.suffix, " +")
    f:emit(EVENT_PLAYER_ACTIVATED)
    equal(#f.notices, 1)
    equal(#f.localization.creates, 168)
    f:noChat()
end)

local failed = 0
for _, case in ipairs(tests) do
    local ok, err = pcall(case[2])
    if ok then
        print("PASS " .. case[1])
    else
        failed = failed + 1
        print("FAIL " .. case[1] .. ": " .. tostring(err))
    end
end
print(string.format("bootstrap: %d tests, %d passed, %d failed", #tests, #tests - failed, failed))
assert(failed == 0, tostring(failed) .. " bootstrap contract test(s) failed")
