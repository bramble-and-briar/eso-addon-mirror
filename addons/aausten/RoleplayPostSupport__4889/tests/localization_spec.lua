-- Run from the repository root: python3 tests/run.py tests/localization_spec.lua
-- Lua 5.1-compatible; real catalog/helper/modules, no locale files or client.
local localization = dofile("tests/localization_fixture.lua")
local unpack = unpack or rawget(table, "unpack")
local tests, failed = 0, 0
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, body)
    tests = tests + 1
    local ok, err = xpcall(body, debug.traceback)
    if not ok then failed = failed + 1; print("FAIL localization: " .. name .. "\n" .. err) end
end
local function fixture(overrides)
    RoleplayPostSupport = {}
    return localization.load(overrides), RoleplayPostSupport
end
local function read(path)
    local file = assert(io.open(path, "r"))
    local text = file:read("*a")
    file:close()
    return text
end

test("default registers exactly 168 unique addon IDs, each at version one", function()
    local registry, A = fixture()
    equal(#registry.creates, 168)
    equal(#registry.versionCalls, 168)
    equal(#registry.reads, 0, "catalog/helper loading does not prefetch strings")
    local names, ids, versioned = {}, {}, {}
    for _, call in ipairs(registry.versionCalls) do
        assert(not versioned[call.id], "duplicate version registration")
        versioned[call.id] = true
        equal(call.version, 1)
    end
    for _, call in ipairs(registry.creates) do
        assert(call.name:match("^RPS_[A-Z0-9_]+$"), "unexpected namespace: " .. call.name)
        assert(not call.name:match("^SI_"), "ESO SI_ namespace must not be used")
        assert(not names[call.name], "duplicate registration: " .. call.name)
        names[call.name] = true
        local id = _G[call.name]
        equal(type(id), "number")
        assert(not ids[id], "IDs must be distinct")
        ids[id] = true
        equal(registry.ids[call.name], id)
        equal(registry.versions[id], 1)
        assert(versioned[id])
        equal(A.L(call.name:sub(5)), call.text)
    end
    equal(A.L("CHAT_CHANNEL_SAY"), "Say")
    equal(A.L("UI_DRAFT_NOTICE"), "Drafts stay in memory. Nothing here sends chat.")
end)

test("subset overrides accept equal/newer versions, reject older ones, and retain English fallback", function()
    local registry, A = fixture()
    local id = rawget(_G, "RPS_CHAT_CHANNEL_SAY")
    registry:override({ CHAT_CHANNEL_SAY = "Dire", UI_PREVIEW = "Aperçu" })
    equal(rawget(_G, "RPS_CHAT_CHANNEL_SAY"), id, "override retains ID")
    equal(A.L("CHAT_CHANNEL_SAY"), "Dire")
    equal(A.L("UI_PREVIEW"), "Aperçu")
    equal(A.L("CHAT_CHANNEL_EMOTE"), "Emote", "untranslated registered key falls back")
    SafeAddString(id, "obsolete", 0)
    equal(A.L("CHAT_CHANNEL_SAY"), "Dire")
    SafeAddString(id, "Nouvelle", 2)
    equal(registry.versions[id], 1, "translation does not raise the baseline")
    equal(A.L("CHAT_CHANNEL_SAY"), "Nouvelle")
    SafeAddString(id, "Égal", 1)
    equal(A.L("CHAT_CHANNEL_SAY"), "Égal", "equal-baseline translation replaces newer translation")
    SafeAddVersion(id, 2)
    equal(registry.versions[id], 2)
    equal(A.L("CHAT_CHANNEL_SAY"), "Égal", "baseline registration does not change text")
    SafeAddString(id, "obsolete", 1)
    equal(A.L("CHAT_CHANNEL_SAY"), "Égal", "older than explicit baseline is rejected")
    SafeAddString(id, "Version deux", 2)
    equal(A.L("CHAT_CHANNEL_SAY"), "Version deux")
    SafeAddVersion(id, 1)
    equal(registry.versions[id], 1, "baseline is assigned, not maximized")
    SafeAddString(id, "Version un", 1)
    equal(A.L("CHAT_CHANNEL_SAY"), "Version un")
end)

test("duplicate registration allocates a new ID without rewriting the previous ID", function()
    local registry, A = fixture()
    local name = "RPS_UI_PREVIEW"
    local original = rawget(_G, name)
    SafeAddVersion(original, 2)
    SafeAddString(original, "Ancien aperçu", 2)
    ZO_CreateStringId(name, "Replacement preview")
    local replacement = rawget(_G, name)
    equal(type(replacement), "number")
    assert(replacement ~= original, "native registration allocates a fresh ID on every call")
    equal(registry.ids[name], replacement)
    equal(#registry.creates, 169)
    equal(registry.creates[169].name, name)
    equal(GetString(original), "Ancien aperçu")
    equal(registry.versions[original], 2)
    equal(A.L("UI_PREVIEW"), "Replacement preview", "helper resolves the replacement ID")
    SafeAddVersion(replacement, 1)
    SafeAddString(replacement, "Nouvel aperçu", 1)
    equal(A.L("UI_PREVIEW"), "Nouvel aperçu")
    equal(GetString(original), "Ancien aperçu", "replacement overrides do not affect the old ID")
    equal(registry.versions[original], 2)
    equal(registry.versions[replacement], 1)
end)

test("helper resolves on each call and missing keys fail with the actual key", function()
    local registry, A = fixture()
    local L = A.L
    equal(L("UI_PREVIEW"), "Preview")
    registry:override({ UI_PREVIEW = "Vorschau" }, 3)
    equal(L("UI_PREVIEW"), "Vorschau")
    equal(#registry.reads, 2)
    equal(registry.reads[1], rawget(_G, "RPS_UI_PREVIEW"))
    equal(registry.reads[2], rawget(_G, "RPS_UI_PREVIEW"))
    local ok, err = pcall(L, "DELIBERATELY_MISSING")
    equal(ok, false)
    assert(tostring(err):find("Unknown localization key: DELIBERATELY_MISSING", 1, true), tostring(err))
    equal(#registry.reads, 2, "assert before GetString; no hidden English fallback")
end)

test("fixtures reset IDs, versions, overrides and addon helper independently", function()
    local first, A = fixture({ UI_PREVIEW = "Translated" })
    SafeAddVersion(rawget(_G, "RPS_UI_PREVIEW"), 42)
    SafeAddString(rawget(_G, "RPS_UI_PREVIEW"), "Newer", 42)
    ZO_CreateStringId("RPS_TEST_STALE", "stale")
    local second, B = fixture()
    assert(A ~= B and A.L ~= B.L and first ~= second)
    equal(rawget(_G, "RPS_TEST_STALE"), nil)
    equal(second.ids.RPS_TEST_STALE, nil)
    equal(second.versions[rawget(_G, "RPS_UI_PREVIEW")], 1)
    equal(#second.creates, 168)
    equal(#second.reads, 0)
    equal(B.L("UI_PREVIEW"), "Preview")
end)

test("optional unknown locales skip safely or use in-memory subset overrides", function()
    RoleplayPostSupport = {}
    local registry = localization.install()
    dofile("lang/default.lua")
    equal(registry:loadLanguage("zz-missing"), false)
    equal(registry:loadLanguage("zz-test", { ["zz-test"] = { UI_PREVIEW = "预览" } }), true)
    dofile("RoleplayPostSupport_Localization.lua")
    equal(RoleplayPostSupport.L("UI_PREVIEW"), "预览")
    equal(RoleplayPostSupport.L("UI_APPLY"), "Apply")
    equal(#registry.creates, 168, "translations only override existing IDs")
end)

test("formatting preserves percent signs, newlines, Unicode and ESO-like grammar verbatim", function()
    local _, A = fixture({
        UI_HISTORY_INCOMING = "[%s] 名=%s\n文=%s; 100%%",
        UI_DRAFT_NOTICE = "literal 100% and %s <<1>>",
    })
    local previous = zo_strformat
    zo_strformat = function() error("localization must not use ESO grammar formatting") end
    local ok, err = pcall(function()
        local time, name, message = "12%\n时", "@Zoë^Fx %s <<1>>", "雪\n100% %d |cABCDEFraw|r <<2>>"
        equal(A.L("UI_HISTORY_INCOMING", time, name, message),
            "[" .. time .. "] 名=" .. name .. "\n文=" .. message .. "; 100%")
        equal(A.L("UI_DRAFT_NOTICE"), "literal 100% and %s <<1>>", "zero args do not format")
    end)
    zo_strformat = previous
    assert(ok, err)
end)

-- Explicit signatures keep catalog edits from silently dropping a placeholder or
-- changing numeric fields to string fields (or vice versa).
local signatures = {
    UI_PREVIEW_TITLE = "ddd", UI_HISTORY_TITLE = "dddd", UI_HISTORY_OUTGOING = "sss",
    UI_HISTORY_INCOMING = "sss", UI_SESSION_TITLE = "dds", UI_NO_SESSION_SELECTED = "d",
    UI_SESSION_INFO = "s", UI_RECORDING_TITLE = "s",
    UI_RECORD_WARNING_MARKED_ON = "d", UI_RECORD_WARNING_MARKED_OFF = "d",
    UI_RECORD_WARNING_ALL_ON = "d", UI_RECORD_WARNING_ALL_OFF = "d", UI_VERSION = "s",
    UI_RUNTIME_CHAT_LIMIT = "s", UI_CHAT_LIMIT_UNAVAILABLE = "s", UI_QUEUE_TITLE_PAUSED = "dd",
    UI_QUEUE_TITLE = "dd", CORE_DEBUG_MESSAGE = "s", CORE_INVALID_MAX_LENGTH = "ss",
    CORE_TEST_FAILED = "s", CORE_DEBUG_ENABLED = "ss", CORE_DEBUG_DISABLED = "ss",
    CORE_UNSUPPORTED_API = "s", CORE_INITIALIZED = "s", CHAT_CHANNEL_GUILD = "s",
    CHAT_CHANNEL_OFFICER = "s", QUEUE_CONFIRMED_CHUNK = "ss",
    SPLITTER_UTF8_INVALID_LEADING_BYTE = "d", SPLITTER_UTF8_TRUNCATED_SEQUENCE = "d",
    SPLITTER_UTF8_INVALID_CONTINUATION_BYTE = "d", SPLITTER_UTF8_OVERLONG_SEQUENCE = "d",
    SPLITTER_UTF8_SURROGATE = "d", SPLITTER_UTF8_CODEPOINT_OUT_OF_RANGE = "d",
    SPLITTER_FIELD_MUST_BE_STRING = "s", SPLITTER_FIELD_ERROR = "ss",
    SPLITTER_FIELD_FORBIDDEN_PIPE_MARKUP = "s", SPLITTER_FIELD_NEWLINE_OR_CONTROL = "s",
    SPLITTER_FIELD_FORBIDDEN_CONTROL = "sd", SPLITTER_FIELD_STARTS_COMMAND = "s",
    SPLITTER_CHUNK_STARTS_COMMAND = "d",
}

test("every English template formats with its complete typed sample arguments", function()
    local registry, A = fixture()
    local seen = {}
    for _, call in ipairs(registry.creates) do
        local key, args, actualSignature = call.name:sub(5), {}, ""
        local text = call.text:gsub("%%%%", "")
        for conversion in text:gmatch("%%(.)") do
            assert(conversion == "s" or conversion == "d", "unsupported format in " .. key)
            actualSignature = actualSignature .. conversion
            args[#args + 1] = conversion == "d" and 7 or "@Éowyn^Fx %s\n雪 <<1>>"
        end
        equal(actualSignature, signatures[key] or "", key .. " signature")
        if signatures[key] then seen[key] = true end
        local ok, formatted = pcall(A.L, key, unpack(args))
        assert(ok, key .. ": " .. tostring(formatted))
        equal(formatted, string.format(call.text, unpack(args)), key .. " format")
    end
    for key in pairs(signatures) do assert(seen[key], "missing template: " .. key) end
end)

for _, language in ipairs({ "de", "fr" }) do
    test("shipped " .. language .. " catalog preserves IDs, formatting and UTF-8 error handling", function()
        local registry, A = fixture()
        dofile("lang/" .. language .. ".lua")
        equal(#registry.creates, 168, "translations override rather than recreate IDs")
        assert(A.L("UI_COMPOSE_TAB") ~= "Compose", "shipped translation was applied")
        for _, entry in ipairs(registry.creates) do
            local key, args, actualSignature = entry.name:sub(5), {}, ""
            local text = A.L(key):gsub("%%%%", "")
            for conversion in text:gmatch("%%(.)") do
                assert(conversion == "s" or conversion == "d", language .. ": unsupported format in " .. key)
                actualSignature = actualSignature .. conversion
                args[#args + 1] = conversion == "d" and 7 or "@Éowyn^Fx %s\n雪 <<1>>"
            end
            equal(actualSignature, signatures[key] or "", language .. ": " .. key .. " signature")
            local ok, formatted = pcall(A.L, key, unpack(args))
            assert(ok, language .. ": " .. key .. ": " .. tostring(formatted))
        end
        local S = dofile("RoleplayPostSupport_Splitter.lua")
        local length, err = S.Length("\244\144\128\128")
        equal(length, nil)
        equal(err, A.L("SPLITTER_UTF8_CODEPOINT_OUT_OF_RANGE", 1))
    end)
end

test("all runtime literal, conditional and mapped localization keys exist in the catalog", function()
    local registry = fixture()
    local references, modules = {}, 0
    local function reference(key, path)
        assert(registry.ids["RPS_" .. key], path .. " references unregistered key " .. key)
        references[key] = true
    end
    for line in io.lines("RoleplayPostSupport.txt") do
        local path = line:match("^%s*(RoleplayPostSupport[^%s]*%.lua)%s*$")
        if path and path ~= "RoleplayPostSupport_Localization.lua" then
            modules = modules + 1
            local source = read(path)
            -- Literal L("KEY") and A.L("KEY") references, including unknown prefixes.
            for key in source:gmatch("%f[%w_]L%s*%(%s*[\"']([%w_]+)[\"']") do reference(key, path) end
            -- Scan whole calls for both conditional branches and nested L calls,
            -- not unrelated quoted ESO global names elsewhere in the module.
            for arguments in source:gmatch("%f[%w_]L%s*(%b())") do
                for key in arguments:gmatch("[\"']([A-Z][A-Z0-9_]+)[\"']") do reference(key, path) end
            end
            -- UI's warningKey is assigned before being passed to L(warningKey).
            for expression in source:gmatch("warningKey%s*=%s*([^\r\n]+)") do
                for key in expression:gmatch("[\"']([A-Z][A-Z0-9_]+)[\"']") do reference(key, path) end
            end
        end
    end
    equal(modules, 6)
    local ui = read("RoleplayPostSupport_UI.lua")
    local mapping = assert(ui:match("local sessionErrorKeys%s*=%s*(%b{})"), "session mapping missing")
    local codes = { invalid_channel = true, target_required = true, invalid_saved_variables = true,
        not_initialized = true, session_limit = true, name_required = true, session_not_found = true,
        no_current_session = true, invalid_participants = true, invalid_addon_only_flag = true,
        invalid_recording_flag = true }
    local count = 0
    for code, key in mapping:gmatch("([%w_]+)%s*=%s*[\"']([%w_]+)[\"']") do
        assert(codes[code], "unknown/duplicate stable session code: " .. code)
        codes[code] = nil
        reference(key, "sessionErrorKeys")
        count = count + 1
    end
    equal(count, 11)
    equal(next(codes), nil, "all session codes mapped")
    for name in pairs(registry.ids) do assert(references[name:sub(5)], "uncovered catalog key: " .. name) end
end)

test("real splitter translates errors but never wire tags, default markers or body text", function()
    fixture({ SPLITTER_LABEL_TEXT = "texte", SPLITTER_LABEL_PREFIX = "préfixe",
        SPLITTER_FIELD_MUST_BE_STRING = "%s doit être du texte",
        SPLITTER_UTF8_INVALID_LEADING_BYTE = "octet invalide %d",
        SPLITTER_FIELD_ERROR = "%s : %s", SPLITTER_TEXT_EMPTY = "texte vide" })
    local S = dofile("RoleplayPostSupport_Splitter.lua")
    local chunks, err = S.Split({}, { maxChars = 10 })
    equal(chunks, nil); equal(err, "texte doit être du texte")
    chunks, err = S.Split("ok", { maxChars = 10, prefix = false })
    equal(chunks, nil); equal(err, "préfixe doit être du texte")
    chunks, err = S.Split("\255", { maxChars = 10 })
    equal(chunks, nil); equal(err, "texte : octet invalide 1")
    chunks, err = S.Split("  ", { maxChars = 10 })
    equal(chunks, nil); equal(err, "texte vide")
    chunks = assert(S.Split("alpha beta gamma", { maxChars = 10 }))
    equal(table.concat(chunks, "\n"), "alpha +\n+ beta +\n+ gamma")
    equal(S.MESSAGE_TAG, string.rep("\226\128\139", 4))
    equal(S.MESSAGE_TAG_LENGTH, 4)
    local raw = "@Zoë^Fx 100% <<1>> 雪"
    equal(assert(S.Split(raw, { maxChars = 100 }))[1], raw)
    local stripped, marked = S.StripMessageTag(S.MESSAGE_TAG .. raw)
    equal(stripped, raw); equal(marked, true)
end)

print(string.format("localization: %d tests, %d passed, %d failed", tests, tests - failed, failed))
assert(failed == 0, tostring(failed) .. " localization test(s) failed")
