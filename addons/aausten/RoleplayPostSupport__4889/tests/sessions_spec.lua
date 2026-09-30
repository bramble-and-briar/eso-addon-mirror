-- Pure Lua 5.1 tests; run from the project root: lua5.1 tests/sessions_spec.lua
-- No ESO client, third-party test framework, filesystem writes, or network required.
local modulePath = "RoleplayPostSupport_Sessions.lua"
local localization = dofile("tests/localization_fixture.lua")
local zeroWidthSpace = "\226\128\139"
local messageTag = string.rep(zeroWidthSpace, 4)

-- Deliberately non-contiguous constants, including SAY = 0.
CHAT_CHANNEL_SAY = 0
CHAT_CHANNEL_YELL = 7
CHAT_CHANNEL_EMOTE = 13
CHAT_CHANNEL_PARTY = 19
CHAT_CHANNEL_ZONE = 23
CHAT_CHANNEL_WHISPER = 31
CHAT_CHANNEL_WHISPER_SENT = 32
CHAT_CHANNEL_SYSTEM = 99
CHAT_CHANNEL_MONSTER_SAY = 101
for index = 1, 5 do
    _G["CHAT_CHANNEL_GUILD_" .. index] = 200 + index * 3
    _G["CHAT_CHANNEL_OFFICER_" .. index] = 300 + index * 3
end
for index = 1, 7 do _G["CHAT_CHANNEL_ZONE_LANGUAGE_" .. index] = 400 + index end
local CHAT_CHANNEL_GUILD_1 = _G["CHAT_CHANNEL_GUILD_1"]

local CHAT_CHANNEL_GUILD_5 = _G["CHAT_CHANNEL_GUILD_5"]
local CHAT_CHANNEL_OFFICER_1 = _G["CHAT_CHANNEL_OFFICER_1"]
local CHAT_CHANNEL_OFFICER_5 = _G["CHAT_CHANNEL_OFFICER_5"]
local CHAT_CHANNEL_ZONE_LANGUAGE_7 = _G["CHAT_CHANNEL_ZONE_LANGUAGE_7"]

local now = 1700000000
local function equal(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual), 2)
    end
end

local function deepEqual(actual, expected, label)
    if type(expected) ~= "table" then return equal(actual, expected, label) end
    equal(type(actual), "table", label)
    for key, value in pairs(expected) do deepEqual(actual[key], value, tostring(key)) end
    for key in pairs(actual) do
        if expected[key] == nil then error("unexpected key: " .. tostring(key), 2) end
    end
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local Sessions, sv
local function reset()
    now = 1700000000
    GetTimeStamp = function() return now end
    GetDisplayName = function() return "@Local" end
    GetUnitName = function(unit)
        equal(unit, "player")
        return "Local Hero^Mx"
    end
    zo_strformat = function(template, name)
        equal(template, "<<1>>")
        return (name:gsub("%^%a+$", ""))
    end
    RoleplayPostSupport = { sentinel = true }
    localization.load()
    dofile("RoleplayPostSupport_Splitter.lua")
    Sessions = dofile(modulePath)
    equal(RoleplayPostSupport.Sessions, Sessions)
    equal(RoleplayPostSupport.sentinel, true)
    sv = {}
    assert(Sessions.Init(sv))
end

local function start(channel, target, participants)
    local session = assert(Sessions.Create("Evening RP", channel or CHAT_CHANNEL_SAY, target))
    equal(Sessions.Select(session.id), session)
    assert(Sessions.SetParticipants(participants or "@Friend, Other Hero"))
    assert(Sessions.SetRecording(true))
    return session
end

local function capture(channel, name, account, text, meta)
    return Sessions.Capture(channel, name, text or "raw message", false, account, meta)
end

local tests = {}
local function test(name, body) tests[#tests + 1] = { name, body } end

test("uninitialized API and invalid arguments fail without throwing", function()
    Sessions = dofile(modulePath)
    deepEqual(Sessions.List(), {})
    equal(Sessions.Get(1), nil)
    equal(Sessions.Current(), nil)
    equal(Sessions.IsRecording(), false)
    local result, err = Sessions.Create("Name", CHAT_CHANNEL_SAY)
    equal(result, nil); equal(err, "not_initialized")
    equal(Sessions.Capture(CHAT_CHANNEL_SAY, "Local Hero", "text", false, "@Local"), nil)
    result, err = Sessions.Init(nil)
    equal(result, nil); equal(err, "invalid_saved_variables")
    assert(Sessions.Init(sv))
    result, err = Sessions.Create("  ", CHAT_CHANNEL_SAY)
    equal(result, nil); equal(err, "name_required")
    result, err = Sessions.SetParticipants("@Friend")
    equal(result, nil); equal(err, "no_current_session")
    result, err = Sessions.SetRecording(true)
    equal(result, nil); equal(err, "no_current_session")
    equal(Sessions.SetRecording(false), true)
    result, err = Sessions.SetRecording("true")
    equal(result, nil); equal(err, "invalid_recording_flag")
end)

test("creation schema, monotonic IDs, lookups and independent list arrays", function()
    deepEqual(sv, { sessions = {}, nextSessionId = 1 })
    local a = assert(Sessions.Create("  Tavern  ", CHAT_CHANNEL_SAY, "ignored"))
    deepEqual(a, {
        id = 1, name = "Tavern", createdAt = now, channel = CHAT_CHANNEL_SAY,
        participants = {}, addonOnly = false, messages = {}, dropped = 0,
    })
    local b = assert(Sessions.Create("Tavern", CHAT_CHANNEL_PARTY))
    equal(b.id, 2)
    equal(sv.nextSessionId, 3)
    equal(Sessions.Current(), nil)
    equal(Sessions.IsRecording(), false)
    equal(Sessions.Get(a.id), a)
    equal(Sessions.Get("1"), nil)
    local list = Sessions.List()
    equal(list[1], a); equal(list[2], b)
    table.remove(list, 1)
    equal(#sv.sessions, 2)
end)

test("destinations validate player channels and required whisper targets", function()
    local bad = { -1, 9999, CHAT_CHANNEL_SYSTEM, CHAT_CHANNEL_MONSTER_SAY, "0", false }
    for _, channel in ipairs(bad) do
        local value, err = Sessions.Create("bad", channel)
        equal(value, nil); equal(err, "invalid_channel")
    end
    equal(Sessions.Create("bad", nil), nil)
    for _, target in ipairs({ "", " \r\n\t", false }) do
        local value, err = Sessions.Create("bad", CHAT_CHANNEL_WHISPER, target)
        equal(value, nil); equal(err, "target_required")
    end
    equal(Sessions.Create("bad", CHAT_CHANNEL_WHISPER), nil)
    equal(sv.nextSessionId, 1)
    local supported = {
        CHAT_CHANNEL_SAY, CHAT_CHANNEL_YELL, CHAT_CHANNEL_EMOTE, CHAT_CHANNEL_PARTY,
        CHAT_CHANNEL_ZONE, CHAT_CHANNEL_GUILD_1, CHAT_CHANNEL_GUILD_5,
        CHAT_CHANNEL_OFFICER_1, CHAT_CHANNEL_OFFICER_5, CHAT_CHANNEL_ZONE_LANGUAGE_7,
    }
    for _, channel in ipairs(supported) do assert(Sessions.Create("valid", channel)) end
    local session = assert(Sessions.Create("whisper", CHAT_CHANNEL_WHISPER_SENT, " Other Hero^Fx "))
    equal(session.channel, CHAT_CHANNEL_WHISPER)
    equal(session.target, "Other Hero")
end)

test("participant parsing trims and formats exact chunks without guessing groups", function()
    start()
    deepEqual(Sessions.SetParticipants(" \r\n @Friend , Other Hero^Fx\r\n\n,  Third Hero , @FRIEND, One Two Three "),
        { "@Friend", "Other Hero", "Third Hero", "@FRIEND", "One Two Three" })
    equal(Sessions.NormalizeName("  OTHER Hero^Fx \t"), "other hero")
    equal(Sessions.NormalizeName(" @Friend "), "@friend")
    equal(Sessions.NormalizeName(nil), "")
    equal(Sessions.NormalizeName(123), "")
    local old = Sessions.Current().participants
    local result, err = Sessions.SetParticipants({ "@Intruder" })
    equal(result, nil); equal(err, "invalid_participants")
    equal(Sessions.Current().participants, old)
    deepEqual(Sessions.SetParticipants(" ,\r\n "), {})
end)

test("name normalization works without ESO formatter and invents no suffix rules", function()
    rawset(_G, "zo_strformat", nil)
    local session = start(CHAT_CHANNEL_SAY, nil, " Hero^Fx , @Friend ")
    deepEqual(session.participants, { "Hero^Fx", "@Friend" })
    equal(Sessions.NormalizeName(" Hero^Fx "), "hero^fx")
    assert(capture(CHAT_CHANNEL_SAY, "HERO^FX", "@Someone"))
    equal(capture(CHAT_CHANNEL_SAY, "Hero", "@Someone"), nil)
end)

test("say captures local and exact account or character participants only", function()
    local session = start()
    now = now + 17
    local text = "  |cFFFFFFRaw|r\ntext, [1/2]  "
    local own = assert(capture(CHAT_CHANNEL_SAY, "Local Hero^Mx", "@LOCAL", text))
    deepEqual(own, {
        text = text, sender = "Local Hero^Mx", displayName = "@LOCAL",
        channel = CHAT_CHANNEL_SAY, timestamp = now, outgoing = true, addonMarked = false,
    })
    equal(capture(CHAT_CHANNEL_SAY, "Any Hero", " @fRiEnD ").outgoing, false)
    equal(capture(CHAT_CHANNEL_SAY, " other HERO^Fx ", "@Another").outgoing, false)
    assert(capture(CHAT_CHANNEL_SAY, "@Friend", ""))
    equal(capture(CHAT_CHANNEL_SAY, "Other", "@Another"), nil)
    equal(capture(CHAT_CHANNEL_SAY, "Other Hero Extra", "@Another"), nil)
    equal(capture(CHAT_CHANNEL_SAY, "Other  Hero", "@Another"), nil)
    equal(capture(CHAT_CHANNEL_SAY, "Unknown", "@FriendExtra"), nil)
    equal(capture(CHAT_CHANNEL_SAY, "Friend", ""), nil)
    equal(capture(CHAT_CHANNEL_SAY, "Unknown", "Other Hero"), nil)
    equal(Sessions.Capture(CHAT_CHANNEL_SAY, "Other Hero", "CS", true, "@Friend"), nil)
    equal(#session.messages, 4)
end)

test("local identity fallback never overrides a disagreeing account", function()
    start(CHAT_CHANNEL_SAY, nil, "")
    equal(capture(CHAT_CHANNEL_SAY, "Local Hero^Mx", "").outgoing, true)
    equal(capture(CHAT_CHANNEL_SAY, "@local", nil).outgoing, true)
    equal(capture(CHAT_CHANNEL_SAY, "Local Hero^Mx", "@Impostor"), nil)
    rawset(_G, "GetDisplayName", nil)
    rawset(_G, "GetUnitName", nil)
    equal(capture(CHAT_CHANNEL_SAY, "", ""), nil)
    equal(capture(CHAT_CHANNEL_SAY, "Unknown", nil), nil)
end)

test("say and whisper sessions capture all player channels with exact identity filters", function()
    local channels = {
        CHAT_CHANNEL_SAY, CHAT_CHANNEL_YELL, CHAT_CHANNEL_EMOTE,
        CHAT_CHANNEL_PARTY, CHAT_CHANNEL_ZONE,
    }
    for index = 1, 5 do
        channels[#channels + 1] = _G["CHAT_CHANNEL_GUILD_" .. index]
        channels[#channels + 1] = _G["CHAT_CHANNEL_OFFICER_" .. index]
    end
    for index = 1, 7 do
        channels[#channels + 1] = _G["CHAT_CHANNEL_ZONE_LANGUAGE_" .. index]
    end
    for _, initial in ipairs({ CHAT_CHANNEL_SAY, CHAT_CHANNEL_WHISPER }) do
        local session = start(initial, "@Stale")
        for _, channel in ipairs(channels) do
            local own = assert(capture(channel, "Local Hero^Mx", "@Local"))
            equal(own.outgoing, true)
            equal(own.channel, channel)
            equal(own.target, nil)
            equal(capture(channel, "Local Hero^Mx", "").outgoing, true)
            equal(capture(channel, "Local Hero^Mx", "@Impostor"), nil)
            local peer = assert(capture(channel, "Friend Hero", " @FRIEND "))
            equal(peer.outgoing, false)
            equal(peer.channel, channel)
            equal(peer.target, nil)
            equal(capture(channel, " other HERO^Fx ", "@Other").outgoing, false)
            equal(capture(channel, "Bystander", "@Unknown"), nil)
            equal(capture(channel, "Friend Hero", "@FriendExtra"), nil)
            equal(capture(channel, "Other Hero Extra", "@Other"), nil)
            equal(capture(channel, "Unknown", "Other Hero"), nil)
            equal(Sessions.Capture(channel, "Local Hero", "CS", true, "@Local"), nil)
        end
        equal(#session.messages, #channels * 4)
        equal(session.channel, initial)
        equal(session.target, initial == CHAT_CHANNEL_WHISPER and "@Stale" or nil)
    end
end)

test("system, monster, invalid and unavailable channels never record", function()
    local session = start()
    local bad = { CHAT_CHANNEL_SYSTEM, CHAT_CHANNEL_MONSTER_SAY, -1, 9999, "0", false, {}, math.huge, 0 / 0 }
    for _, channel in ipairs(bad) do
        equal(capture(channel, "Local Hero", "@Local"), nil)
        equal(capture(channel, "Other Hero", "@Friend"), nil)
    end
    equal(capture(nil, "Local Hero", "@Local"), nil)
    local guild = _G.CHAT_CHANNEL_GUILD_5
    rawset(_G, "CHAT_CHANNEL_GUILD_5", nil)
    local result = capture(guild, "Local Hero", "@Local")
    rawset(_G, "CHAT_CHANNEL_GUILD_5", guild)
    equal(result, nil)
    equal(#session.messages, 0)
end)

test("incoming whispers use each sender as target and require exact participants", function()
    for _, initial in ipairs({ CHAT_CHANNEL_SAY, CHAT_CHANNEL_WHISPER }) do
        local session = start(initial, "@Stale", "@Friend, Other Hero")
        local text = "  |cFFFFFFRaw whisper|r\n[1/2]  "
        local message = assert(capture(CHAT_CHANNEL_WHISPER, "Friend Hero^Mx", " @FRIEND ", text))
        deepEqual(message, {
            text = text, sender = "Friend Hero^Mx", displayName = " @FRIEND ",
            channel = CHAT_CHANNEL_WHISPER, timestamp = now, outgoing = false, target = "@FRIEND",
            addonMarked = false,
        })
        equal(capture(CHAT_CHANNEL_WHISPER, "OTHER HERO^Fx", "@Other").target, "@Other")
        equal(capture(CHAT_CHANNEL_WHISPER, " Other Hero^Fx ", " \t").target, "Other Hero")
        equal(capture(CHAT_CHANNEL_WHISPER, "@Friend", nil).target, "@Friend")
        equal(capture(CHAT_CHANNEL_WHISPER, "Other", "@Other"), nil)
        equal(capture(CHAT_CHANNEL_WHISPER, "Unknown", "Other Hero"), nil)
        equal(capture(CHAT_CHANNEL_WHISPER, "Friend", ""), nil)
        equal(capture(CHAT_CHANNEL_WHISPER, "Bystander", "@Stale"), nil)
        equal(capture(CHAT_CHANNEL_WHISPER, nil, nil), nil)
        equal(#session.messages, 4)
    end
end)

test("incoming whispers are never own even with conflicting local identity", function()
    start(CHAT_CHANNEL_WHISPER, "@Friend", "")
    equal(capture(CHAT_CHANNEL_WHISPER, "Friend Hero", "@Local"), nil)
    equal(capture(CHAT_CHANNEL_WHISPER, "Local Hero^Mx", ""), nil)
    assert(Sessions.SetParticipants("Friend Hero, @Local"))
    local meta = { postId = 1, chunkIndex = 1, chunkCount = 1 }
    local message = assert(capture(CHAT_CHANNEL_WHISPER, "Friend Hero", "@Local", "incoming", meta))
    equal(message.outgoing, false)
    equal(message.sender, "Friend Hero")
    equal(message.target, "@Local")
    equal(message.postId, nil)
    equal(capture(CHAT_CHANNEL_WHISPER, "Local Hero^Mx", "@Local").outgoing, false)
end)

test("outgoing whispers always archive own sender and each recipient without participants", function()
    local peers = {
        { "Friend Hero^Mx", " @FRIEND ", "@FRIEND" },
        { "Other Hero", "@Other", "@Other" },
        { " Third Hero^Fx ", " \t", "Third Hero" },
        { "@Friend", "", "@Friend" },
        { "Friend Hero", "@Local", "@Local" },
        { "Friend", nil, "Friend" },
        { "Ignored", " Display Peer^Fx ", "Display Peer" },
        { "", "" },
        {},
        { false, false },
    }
    for _, initial in ipairs({ CHAT_CHANNEL_SAY, CHAT_CHANNEL_WHISPER }) do
        local session = start(initial, "@Stale", "")
        for _, peer in ipairs(peers) do
            local message = assert(capture(CHAT_CHANNEL_WHISPER_SENT, peer[1], peer[2]))
            deepEqual(message, {
                text = "raw message", sender = "Local Hero^Mx", displayName = "@Local",
                channel = CHAT_CHANNEL_WHISPER_SENT, timestamp = now, outgoing = true, target = peer[3],
                addonMarked = false,
            })
        end
        equal(Sessions.Capture(CHAT_CHANNEL_WHISPER_SENT, "Other Hero", "CS", true, "@Other"), nil)
        equal(Sessions.Capture(CHAT_CHANNEL_WHISPER, "Other Hero", "CS", true, "@Other"), nil)
        equal(#session.messages, #peers)
        equal(capture(CHAT_CHANNEL_SAY, "Local Hero", "@Local").target, nil)
    end
    GetUnitName = function() return "" end
    equal(capture(CHAT_CHANNEL_WHISPER_SENT, "Peer", nil).sender, "@Local")
    rawset(_G, "GetDisplayName", nil)
    rawset(_G, "GetUnitName", nil)
    local message = assert(capture(CHAT_CHANNEL_WHISPER_SENT, "Peer", nil))
    equal(message.outgoing, true)
    equal(message.sender, "")
    equal(message.displayName, "")
    equal(message.target, "Peer")
end)

test("queue metadata is copied only for own events and cannot bypass filters", function()
    local session = start()
    local meta = {
        postId = "post-7", chunkIndex = 1, chunkCount = 3,
        target = "@Wrong", draft = "NEVER SAVE", queue = { "NEVER SAVE" },
    }
    local own = assert(capture(CHAT_CHANNEL_SAY, "Local Hero", "@Local", "chunk", meta))
    deepEqual(own, {
        text = "chunk", sender = "Local Hero", displayName = "@Local", channel = CHAT_CHANNEL_SAY,
        timestamp = now, outgoing = true, postId = "post-7", chunkIndex = 1, chunkCount = 3,
        addonMarked = false,
    })
    meta.chunkIndex = 2
    equal(own.chunkIndex, 1)
    local incoming = assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", "[1/3] raw", meta))
    equal(incoming.postId, nil)
    equal(incoming.chunkIndex, nil)
    equal(incoming.text, "[1/3] raw")
    equal(capture(CHAT_CHANNEL_SAY, "Unknown", "@Unknown", "chunk", meta), nil)
    equal(capture(CHAT_CHANNEL_PARTY, "Local Hero", "@Local", "chunk", meta).postId, "post-7")
    equal(capture(CHAT_CHANNEL_SYSTEM, "Local Hero", "@Local", "chunk", meta), nil)
    local malformed = capture(CHAT_CHANNEL_SAY, "Local Hero", "@Local", "chunk", { postId = {}, chunkIndex = 1 })
    equal(malformed.postId, nil)
    equal(#session.messages, 4)
    session = start(CHAT_CHANNEL_WHISPER, "@Friend", "")
    local whisper = assert(capture(CHAT_CHANNEL_WHISPER_SENT, "Friend Hero", "@Friend", "chunk", meta))
    equal(whisper.postId, "post-7")
    equal(whisper.target, "@Friend")
    meta.target = "@Friend"
    local other = assert(capture(CHAT_CHANNEL_WHISPER_SENT, "Other Hero", "@Other", "chunk", meta))
    equal(other.target, "@Other")
    equal(other.postId, "post-7")
    equal(capture(CHAT_CHANNEL_WHISPER, "Other Hero", "@Other", "chunk", meta), nil)
end)

test("identical messages and participant chunks are never deduplicated or grouped", function()
    local session = start()
    local first = assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", "same"))
    local second = assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", "same"))
    equal(first == second, false)
    deepEqual(first, second)
    assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", "[1/2] chunk"))
    assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", "[2/2] chunk"))
    equal(#session.messages, 4)
    equal(session.messages[3].postId, nil)
    equal(session.messages[4].chunkCount, nil)
end)

test("recording is opt-in and selection disarms regardless of initial destination", function()
    local a = start()
    assert(Sessions.SetRecording(false))
    equal(capture(CHAT_CHANNEL_SAY, "Local Hero", "@Local"), nil)
    assert(Sessions.SetRecording(true))
    equal(Sessions.Select(a.id), a)
    equal(Sessions.IsRecording(), false)
    local b = assert(Sessions.Create("Second", CHAT_CHANNEL_PARTY))
    assert(Sessions.SetRecording(true))
    assert(Sessions.Select(b.id))
    equal(Sessions.Current(), b)
    equal(Sessions.IsRecording(), false)
    assert(Sessions.SetRecording(true))
    local result, err = Sessions.Select(999)
    equal(result, nil); equal(err, "session_not_found")
    equal(Sessions.Current(), b)
    equal(Sessions.IsRecording(), false)
    equal(capture(CHAT_CHANNEL_SAY, "Local Hero", "@Local"), nil)
    assert(Sessions.SetRecording(true))
    assert(capture(CHAT_CHANNEL_SAY, "Local Hero", "@Local"))
    equal(#a.messages, 0)
    equal(#b.messages, 1)
    equal(capture(CHAT_CHANNEL_SYSTEM, "Local Hero", "@Local"), nil)
end)

test("legacy destinations and records remain intact and do not gate recording", function()
    local routes = {
        { channel = CHAT_CHANNEL_SYSTEM, target = "@Old" },
        { channel = CHAT_CHANNEL_WHISPER, target = "" },
        { channel = "obsolete", target = "@Old" },
        {},
    }
    for _, route in ipairs(routes) do
        local legacy = {
            id = 7, name = "Legacy", createdAt = 123,
            channel = route.channel, target = route.target,
            participants = { "@Friend" }, dropped = 2,
            messages = {
                { text = messageTag .. "old", sender = "Friend Hero^Mx", displayName = "@Friend",
                    channel = CHAT_CHANNEL_WHISPER, target = "@Historical", timestamp = 124, outgoing = false },
                { text = "old public", sender = "Local Hero", displayName = "@Local",
                    channel = CHAT_CHANNEL_SAY, target = "@Stale", timestamp = 125, outgoing = true },
            },
        }
        local persisted = { sessions = { legacy }, nextSessionId = 8, otherOwner = { keep = true } }
        local expected = copy(persisted)
        assert(Sessions.Init(persisted))
        deepEqual(persisted, expected)
        equal(Sessions.Get(7), legacy)
        equal(Sessions.Current(), nil)
        equal(Sessions.IsRecording(), false)
        assert(Sessions.Select(7))
        equal(legacy.addonOnly, nil)
        assert(Sessions.SetRecording(true))
        equal(capture(CHAT_CHANNEL_SAY, "Local Hero", "@Local").target, nil)
        equal(capture(CHAT_CHANNEL_WHISPER, "Friend Hero", "@Friend").target, "@Friend")
        equal(capture(CHAT_CHANNEL_WHISPER_SENT, "Other Hero", "@Other").target, "@Other")
        equal(capture(CHAT_CHANNEL_SYSTEM, "Local Hero", "@Local"), nil)
        assert(Sessions.SetRecording(false))
        equal(capture(CHAT_CHANNEL_PARTY, "Local Hero", "@Local"), nil)
        equal(#legacy.messages, 5)
        equal(legacy.addonOnly, nil)
        for index = 3, 5 do equal(legacy.messages[index].addonMarked, false) end
        for index = 1, 2 do deepEqual(legacy.messages[index], expected.sessions[1].messages[index]) end
        local archived = copy(legacy)
        archived.messages = expected.sessions[1].messages
        deepEqual(archived, expected.sessions[1])
        deepEqual(persisted.otherOwner, expected.otherOwner)
        equal(persisted.nextSessionId, 8)
    end
end)

test("reload preserves only archive data, never selection or recording", function()
    local session = start()
    assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", "saved"))
    equal(sv.recording, nil)
    equal(sv.selectedId, nil)
    equal(sv.draft, nil)
    equal(sv.queue, nil)
    local persisted = copy(sv)
    local expected = copy(sv)
    Sessions = dofile(modulePath)
    assert(Sessions.Init(persisted))
    equal(Sessions.Current(), nil)
    equal(Sessions.IsRecording(), false)
    deepEqual(persisted, expected)
    deepEqual(Sessions.Get(session.id), session)
    assert(Sessions.Select(session.id))
    equal(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", "not saved"), nil)
    equal(#Sessions.Current().messages, 1)
    assert(Sessions.SetRecording(true))
    assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", "new"))
    assert(Sessions.Init(persisted))
    equal(Sessions.Current(), nil)
    equal(Sessions.IsRecording(), false)
end)

test("Init repairs ID counter and ignores legacy armed flags without touching other owners", function()
    local a = start()
    local b = assert(Sessions.Create("Second", CHAT_CHANNEL_SAY))
    sv.nextSessionId = 1.5
    sv.recording, sv.selectedId, sv.otherOwner = true, a.id, { setting = "keep" }
    assert(Sessions.Init(sv))
    equal(sv.nextSessionId, b.id + 1)
    equal(Sessions.IsRecording(), false)
    equal(Sessions.Current(), nil)
    deepEqual(sv.otherOwner, { setting = "keep" })
    sv.nextSessionId = 42
    assert(Sessions.Init(sv))
    equal(Sessions.Create("Third", CHAT_CHANNEL_SAY).id, 42)
    for _, invalid in ipairs({ false, "bad", -4, math.huge, 0 / 0 }) do
        local data = { sessions = false, nextSessionId = invalid }
        assert(Sessions.Init(data))
        deepEqual(data, { sessions = {}, nextSessionId = 1 })
    end
end)

test("deletion removes records, disarms, clears deleted selection and does not reuse IDs", function()
    local a = start()
    assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend"))
    local b = assert(Sessions.Create("Second", CHAT_CHANNEL_PARTY))
    assert(Sessions.Delete(b.id))
    equal(Sessions.Current(), a)
    equal(Sessions.IsRecording(), false)
    assert(Sessions.SetRecording(true))
    assert(Sessions.Delete(a.id))
    equal(Sessions.Get(a.id), nil)
    equal(Sessions.Current(), nil)
    equal(Sessions.IsRecording(), false)
    deepEqual(sv.sessions, {})
    equal(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend"), nil)
    local result, err = Sessions.Delete(a.id)
    equal(result, nil); equal(err, "session_not_found")
    equal(Sessions.Create("Third", CHAT_CHANNEL_SAY).id, 3)
end)

test("50 session cap refuses creation instead of evicting archives", function()
    local first = start()
    for index = 2, 50 do assert(Sessions.Create("Session " .. index, CHAT_CHANNEL_SAY)) end
    local value, err = Sessions.Create("Overflow", CHAT_CHANNEL_SAY)
    equal(value, nil); equal(err, "session_limit")
    equal(#Sessions.List(), 50)
    equal(Sessions.Get(1), first)
    equal(Sessions.Current(), first)
    equal(Sessions.IsRecording(), true)
    equal(sv.nextSessionId, 51)
    assert(Sessions.Delete(25))
    equal(Sessions.Create("Replacement", CHAT_CHANNEL_SAY).id, 51)
end)

test("record cap evicts oldest, counts drops and is independent per session", function()
    local session = start()
    for index = 1, 2002 do
        now = now + 1
        assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", tostring(index)))
    end
    equal(#session.messages, 2000)
    equal(session.dropped, 2)
    equal(session.messages[1].text, "3")
    equal(session.messages[2000].text, "2002")
    equal(session.messages[2000].timestamp, now)
    local other = start()
    assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend"))
    equal(#other.messages, 1)
    equal(other.dropped, 0)
    equal(#session.messages, 2000)
    assert(Sessions.Init(sv))
    equal(Sessions.Get(session.id).dropped, 2)
end)

test("message limit is bytes, accepts boundary and skips oversized without mutation", function()
    local session = start()
    local boundary = string.rep("x", 8192)
    equal(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", boundary).text, boundary)
    equal(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", boundary .. "x"), nil)
    local utf8 = string.char(195, 169)
    assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", string.rep(utf8, 4096)))
    equal(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", string.rep(utf8, 4097)), nil)
    equal(Sessions.Capture(CHAT_CHANNEL_SAY, "Other Hero", {}, false, "@Friend"), nil)
    equal(Sessions.Capture(CHAT_CHANNEL_SAY, "Other Hero", nil, false, "@Friend"), nil)
    equal(#session.messages, 2)
    equal(session.dropped, 0)
end)

test("addonOnly validates selection and boolean without mutating live state", function()
    Sessions = dofile(modulePath)
    local result, err = Sessions.SetAddonOnly(true)
    equal(result, nil); equal(err, "no_current_session")
    assert(Sessions.Init(sv))
    result, err = Sessions.SetAddonOnly(false)
    equal(result, nil); equal(err, "no_current_session")
    local session = start()
    local participants = session.participants
    local function invalid(value)
        local before = copy(sv)
        result, err = Sessions.SetAddonOnly(value)
        equal(result, nil); equal(err, "invalid_addon_only_flag")
        deepEqual(sv, before)
        equal(Sessions.Current(), session)
        equal(Sessions.IsRecording(), true)
        equal(session.participants, participants)
    end
    for _, enabled in ipairs({ false, true }) do
        equal(Sessions.SetAddonOnly(enabled), true)
        invalid(nil)
        for _, value in ipairs({ "true", "false", 0, 1, {}, function() end }) do invalid(value) end
        equal(session.addonOnly, enabled)
    end
    assert(Sessions.Delete(session.id))
    result, err = Sessions.SetAddonOnly(true)
    equal(result, nil); equal(err, "no_current_session")
end)

test("addonOnly toggles live per session, persists and never rewrites archives", function()
    local a = start()
    local participants, messages = a.participants, a.messages
    equal(a.addonOnly, false)
    assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", "before"))
    local original = copy(messages)
    assert(Sessions.SetAddonOnly(true))
    equal(sv.sessions[1].addonOnly, true)
    equal(Sessions.IsRecording(), true)
    equal(a.participants, participants)
    equal(a.messages, messages)
    deepEqual(messages, original)
    equal(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", "blocked"), nil)
    assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", messageTag .. "during"))
    original = copy(messages)
    assert(Sessions.SetAddonOnly(false))
    equal(Sessions.IsRecording(), true)
    equal(a.participants, participants)
    deepEqual(messages, original)
    assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", "after"))
    local b = start()
    equal(b.addonOnly, false)
    assert(Sessions.Select(a.id))
    assert(Sessions.SetAddonOnly(true))
    equal(Sessions.IsRecording(), false)
    equal(b.addonOnly, false)
    local persisted = copy(sv)
    local expected = copy(persisted)
    Sessions = dofile(modulePath)
    assert(Sessions.Init(persisted))
    deepEqual(persisted, expected)
    equal(Sessions.Current(), nil)
    equal(Sessions.IsRecording(), false)
    assert(Sessions.Select(a.id))
    assert(Sessions.SetRecording(true))
    equal(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", "blocked after reload"), nil)
    assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", messageTag .. "reloaded"))
    assert(Sessions.Select(b.id))
    assert(Sessions.SetRecording(true))
    assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", "still off"))
end)

test("only an exact leading tag qualifies and exactly one tag is stripped even OFF", function()
    equal(RoleplayPostSupport.Splitter.MESSAGE_TAG, messageTag)
    equal(RoleplayPostSupport.Splitter.MESSAGE_TAG_LENGTH, 4)
    local session = start()
    local cases = {
        { "", "", false },
        { "plain", "plain", false },
        { messageTag, "", true },
        { messageTag .. "body", "body", true },
        { messageTag .. messageTag .. "body", messageTag .. "body", true },
        { messageTag .. zeroWidthSpace .. "body", zeroWidthSpace .. "body", true },
        { "body" .. messageTag, "body" .. messageTag, false },
        { " " .. messageTag .. "body", " " .. messageTag .. "body", false },
        { messageTag .. "body" .. messageTag, "body" .. messageTag, true },
        { messageTag:sub(1, -2) .. "body", messageTag:sub(1, -2) .. "body", false },
    }
    for count = 1, 3 do
        local partial = string.rep(zeroWidthSpace, count) .. "body"
        cases[#cases + 1] = { partial, partial, false }
    end
    for _, enabled in ipairs({ false, true }) do
        assert(Sessions.SetAddonOnly(enabled))
        for _, case in ipairs(cases) do
            local before = #session.messages
            local record = capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", case[1])
            if enabled and not case[3] then
                equal(record, nil)
                equal(#session.messages, before)
            else
                equal(record.text, case[2])
                equal(record.addonMarked, case[3])
                equal(record.postId, nil)
            end
        end
    end
end)

test("addonOnly applies to every eligible sender and channel, never authorizes outsiders", function()
    local channels = { CHAT_CHANNEL_SAY, CHAT_CHANNEL_YELL, CHAT_CHANNEL_EMOTE,
        CHAT_CHANNEL_PARTY, CHAT_CHANNEL_ZONE, CHAT_CHANNEL_WHISPER, CHAT_CHANNEL_WHISPER_SENT }
    for index = 1, 5 do
        channels[#channels + 1] = _G["CHAT_CHANNEL_GUILD_" .. index]
        channels[#channels + 1] = _G["CHAT_CHANNEL_OFFICER_" .. index]
    end
    for index = 1, 7 do channels[#channels + 1] = _G["CHAT_CHANNEL_ZONE_LANGUAGE_" .. index] end
    local senders = {
        { "Local Hero^Mx", "@Local", true },
        { "Local Hero^Mx", "", true },
        { "@local", "", true },
        { "Friend Hero", "@FRIEND", false },
        { "other HERO^Fx", "@Other", false },
        { "@Friend", "", false },
        { "Bystander", "@Unknown" },
        { "Friend Hero", "@FriendExtra" },
        { "Other Hero Extra", "@Other" },
        { "Unknown", "Other Hero" },
        { "Local Hero^Mx", "@Impostor" },
    }
    for _, initial in ipairs({ CHAT_CHANNEL_SAY, CHAT_CHANNEL_WHISPER }) do
        local session = start(initial, "@Stale")
        for _, enabled in ipairs({ false, true }) do
            assert(Sessions.SetAddonOnly(enabled))
            for _, channel in ipairs(channels) do
                for _, sender in ipairs(senders) do
                    local own = channel == CHAT_CHANNEL_WHISPER_SENT
                        or (channel ~= CHAT_CHANNEL_WHISPER and sender[3] == true)
                    local eligible = own or sender[3] == false
                    for _, marked in ipairs({ false, true }) do
                        local text = (marked and messageTag or "") .. "body"
                        local record = capture(channel, sender[1], sender[2], text)
                        if eligible and (not enabled or marked) then
                            assert(record)
                            equal(record.text, "body")
                            equal(record.addonMarked, marked)
                            equal(record.outgoing, own)
                            equal(record.channel, channel)
                        else
                            equal(record, nil)
                        end
                        equal(Sessions.Capture(channel, sender[1], text, true, sender[2]), nil)
                    end
                end
            end
            for _, channel in ipairs({ CHAT_CHANNEL_SYSTEM, CHAT_CHANNEL_MONSTER_SAY, -1, "0" }) do
                equal(capture(channel, "Local Hero", "@Local", messageTag .. "body"), nil)
                equal(capture(channel, "Other Hero", "@Friend", messageTag .. "body"), nil)
            end
        end
        equal(session.dropped, 0)
    end
end)

test("marked clean chunks preserve own metadata without requiring queue provenance", function()
    start()
    local meta = { postId = "post-9", chunkIndex = 2, chunkCount = 3, draft = "NEVER SAVE" }
    for _, enabled in ipairs({ false, true }) do
        assert(Sessions.SetAddonOnly(enabled))
        for _, channel in ipairs({ CHAT_CHANNEL_SAY, CHAT_CHANNEL_WHISPER_SENT }) do
            local record = assert(capture(channel, "Local Hero", "@Local", messageTag .. "[2/3] chunk", meta))
            deepEqual(record, {
                text = "[2/3] chunk", addonMarked = true, sender = channel == CHAT_CHANNEL_SAY
                    and "Local Hero" or "Local Hero^Mx", displayName = "@Local",
                channel = channel, timestamp = now, outgoing = true,
                target = channel == CHAT_CHANNEL_WHISPER_SENT and "@Local" or nil,
                postId = "post-9", chunkIndex = 2, chunkCount = 3,
            })
            equal(capture(channel, "Local Hero", "@Local", messageTag .. "no queue").postId, nil)
            equal(capture(channel, "Local Hero", "@Local", messageTag .. "bad queue", {}).postId, nil)
            local plain = capture(channel, "Local Hero", "@Local", "no marker", meta)
            if enabled then equal(plain, nil) else equal(plain.addonMarked, false) end
        end
        for _, channel in ipairs({ CHAT_CHANNEL_SAY, CHAT_CHANNEL_WHISPER }) do
            local peer = assert(capture(channel, "Other Hero", "@Friend", messageTag .. "peer", meta))
            equal(peer.text, "peer")
            equal(peer.addonMarked, true)
            equal(peer.outgoing, false)
            equal(peer.postId, nil); equal(peer.chunkIndex, nil); equal(peer.chunkCount, nil)
            equal(capture(channel, "Unknown", "@Unknown", messageTag .. "outsider", meta), nil)
        end
    end
end)

test("wire byte cap includes the tag before stripping in both modes", function()
    local session = start()
    local body = string.rep("x", 8192 - #messageTag)
    for _, enabled in ipairs({ false, true }) do
        assert(Sessions.SetAddonOnly(enabled))
        local record = assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", messageTag .. body))
        equal(record.text, body)
        equal(record.addonMarked, true)
        local before = copy(session)
        equal(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", messageTag .. body .. "x"), nil)
        equal(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", messageTag .. string.rep("x", 8192)), nil)
        deepEqual(session, before)
    end
end)

test("addonOnly rejects do not evict records and accepted marked records retain the cap", function()
    local session = start()
    assert(Sessions.SetAddonOnly(true))
    for index = 1, 2000 do
        assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", messageTag .. tostring(index)))
    end
    local first = session.messages[1]
    equal(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", "unmarked"), nil)
    equal(capture(CHAT_CHANNEL_SAY, "Unknown", "@Unknown", messageTag .. "outsider"), nil)
    equal(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", messageTag .. string.rep("x", 8192)), nil)
    equal(session.messages[1], first)
    equal(session.dropped, 0)
    assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", messageTag .. "2001"))
    equal(#session.messages, 2000)
    equal(session.dropped, 1)
    equal(session.messages[1].text, "2")
    equal(session.messages[2000].text, "2001")
    equal(session.messages[2000].addonMarked, true)
    assert(Sessions.SetAddonOnly(false))
    assert(capture(CHAT_CHANNEL_SAY, "Other Hero", "@Friend", "2002"))
    equal(#session.messages, 2000)
    equal(session.dropped, 2)
    equal(session.messages[1].text, "3")
    equal(session.messages[2000].addonMarked, false)
end)

local failures = 0
for _, case in ipairs(tests) do
    local ok, err = pcall(function() reset(); case[2]() end)
    if ok then
        print("ok - " .. case[1])
    else
        failures = failures + 1
        print("not ok - " .. case[1] .. "\n  " .. tostring(err))
    end
end
print(string.format("%d tests, %d failures (%s)", #tests, failures, _VERSION))
if failures > 0 then error("sessions_spec failed", 0) end
