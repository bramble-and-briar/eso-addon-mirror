-- Run from the repository root: lua5.1 tests/splitter_spec.lua
-- Mock string APIs only; no client, temporary files, or nondeterministic seeds.
local unpack = unpack or rawget(table, "unpack") -- Also runnable on newer Lua versions.
local sentinel = {}
RoleplayPostSupport = { existing = sentinel }
dofile("tests/localization_fixture.lua").load()
local S = dofile("RoleplayPostSupport_Splitter.lua")
assert(RoleplayPostSupport.Splitter == S and RoleplayPostSupport.existing == sentinel)

local tests = 0
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected "
        .. tostring(expected) .. ", got " .. tostring(actual))
end

local function test(name, run)
    local ok, err = pcall(run)
    assert(ok, name .. ": " .. tostring(err))
    tests = tests + 1
end

local function fails(text, options, pattern)
    local chunks, err = S.Split(text, options)
    equal(chunks, nil, "failed Split result")
    assert(type(err) == "string" and err:match(pattern), tostring(err))
end

local function fixture(text, options, expected)
    local chunks, err = S.Split(text, options)
    assert(chunks, err)
    equal(err, nil, "successful Split error")
    equal(#chunks, #expected, "chunk count")
    for index, chunk in ipairs(chunks) do
        equal(chunk, expected[index], "chunk " .. index)
        assert(S.Length(chunk) <= options.maxChars)
        assert(not chunk:find("[\r\n\t|]"))
    end
end

local function encode(value)
    if value < 128 then return string.char(value) end
    if value < 2048 then
        return string.char(192 + math.floor(value / 64), 128 + value % 64)
    end
    if value < 65536 then
        return string.char(224 + math.floor(value / 4096),
            128 + math.floor(value / 64) % 64, 128 + value % 64)
    end
    return string.char(240 + math.floor(value / 262144),
        128 + math.floor(value / 4096) % 64,
        128 + math.floor(value / 64) % 64, 128 + value % 64)
end

-- Independent UTF-8 checker: boundary-specific byte ranges rather than the
-- implementation's scalar decoder. Also supplies an independent length oracle.
local function referenceLength(text)
    local at, count = 1, 0
    while at <= #text do
        local a, b, c, d = text:byte(at, at + 3)
        local function continuation(value)
            return value and value >= 128 and value <= 191
        end
        local size
        if a < 128 then
            size = 1
        elseif a >= 194 and a <= 223 and continuation(b) then
            size = 2
        elseif a >= 224 and a <= 239 and continuation(b) and continuation(c)
            and (a ~= 224 or b >= 160) and (a ~= 237 or b <= 159) then
            size = 3
        elseif a >= 240 and a <= 244 and continuation(b)
            and continuation(c) and continuation(d)
            and (a ~= 240 or b >= 144) and (a ~= 244 or b <= 143) then
            size = 4
        end
        assert(size, "invalid output UTF-8 at byte " .. at)
        count, at = count + 1, at + size
    end
    return count
end

-- Conservation permits ONLY an omitted normalized space between chunks, not
-- arbitrary whitespace deletion, duplicated characters, or omitted body text.
local function conserved(canonical, chunks, options)
    local prefix = options.prefix or "+ "
    local suffix = options.suffix or " +"
    local at = 1
    for index, chunk in ipairs(chunks) do
        local length = referenceLength(chunk)
        equal(S.Length(chunk), length, "UTF-8 length")
        assert(length <= options.maxChars, "chunk over budget")
        assert(not chunk:find("[\r\n\t|]") and not chunk:match("^ */"))
        local body = chunk
        if #chunks > 1 and index > 1 and #prefix > 0 then
            equal(body:sub(1, #prefix), prefix, "prefix")
            body = body:sub(#prefix + 1)
        end
        if #chunks > 1 and index < #chunks and #suffix > 0 then
            equal(body:sub(-#suffix), suffix, "suffix")
            body = body:sub(1, #body - #suffix)
        end
        assert(#body > 0, "empty body")
        assert(not body:match("^ ") and not body:match(" $"))
        assert(not body:find("  ", 1, true))
        equal(canonical:sub(at, at + #body - 1), body, "conserved body")
        at = at + #body
        if index < #chunks and canonical:sub(at, at) == " " then
            at = at + 1
        end
    end
    equal(at, #canonical + 1, "no draft truncation")
end

test("single chunk, exact budget, no markers", function()
    fixture("hello", { maxChars = 5 }, { "hello" })
    fixture("x", { maxChars = 1 }, { "x" })
    fixture("hello", { maxChars = 5, prefix = "very long", suffix = "very long" }, { "hello" })
end)

test("default marker accounting", function()
    fixture("alpha beta gamma", { maxChars = 10 }, { "alpha +", "+ beta +", "+ gamma" })
    fixture("abcdefghijk", { maxChars = 8 }, { "abcdef +", "+ ghijk" })
    fixture("ab cd", { maxChars = 4 }, { "ab +", "+ cd" })
    fixture("é猫😀é猫😀é猫😀", { maxChars = 6 }, { "é猫😀é +", "+ 猫😀 +", "+ é猫😀" })
end)

test("newline beats sentences and whitespace", function()
    fixture("a\nDone. other words more", { maxChars = 18, prefix = "", suffix = "" },
        { "a", "Done.", "other words more" })
    fixture("one\r\nsecond word tail", { maxChars = 12, prefix = "", suffix = "" },
        { "one", "second word", "tail" })
    fixture("aa\nbb\ncc dddd", { maxChars = 8, prefix = "", suffix = "" },
        { "aa bb", "cc dddd" })
    fixture("a\nb c ddddd", { maxChars = 6, prefix = "", suffix = "", sentences = false },
        { "a", "b c", "ddddd" })
end)

test("sentences, disabling heuristic, closing quotes, ellipses", function()
    fixture("One. two three four", { maxChars = 12, prefix = "", suffix = "" },
        { "One.", "two three", "four" })
    fixture("One. two three four", { maxChars = 12, prefix = "", suffix = "", sentences = false },
        { "One. two", "three four" })
    fixture("He said, “Go!” Then more words follow.", { maxChars = 24, prefix = "", suffix = "" },
        { "He said, “Go!”", "Then more words follow." })
    for _, ending in ipairs({ ".", "!", "?", "…", "...", '..."', "?!’)]", '.»', ".›" }) do
        fixture("Wait" .. ending .. " next words go", { maxChars = 13, prefix = "", suffix = "" },
            { "Wait" .. ending, "next words go" })
    end
    fixture("One. Two! next words here", { maxChars = 15, prefix = "", suffix = "" },
        { "One. Two!", "next words here" })
end)

test("whitespace and codepoint-safe fallback", function()
    fixture("alpha beta gamma", { maxChars = 10, prefix = "", suffix = "" },
        { "alpha beta", "gamma" })
    fixture("a b", { maxChars = 1, prefix = "", suffix = "" }, { "a", "b" })
    fixture("é猫😀é", { maxChars = 1, prefix = "", suffix = "" }, { "é", "猫", "😀", "e", "́" })
end)

test("body normalization and Unicode whitespace", function()
    fixture(" \t hello\r\n\tworld \r again\n ", { maxChars = 30 }, { "hello world again" })
    local spaces = { 9, 10, 13, 32, 133, 160, 5760, 8192, 8193, 8194,
        8195, 8196, 8197, 8198, 8199, 8200, 8201, 8202, 8232, 8233, 8239, 8287, 12288 }
    for _, value in ipairs(spaces) do
        local space = encode(value)
        fixture(space .. "a" .. space .. space .. "b" .. space,
            { maxChars = 3 }, { "a b" })
    end
    for _, value in ipairs({ 10, 13, 133, 8232, 8233 }) do
        fixture("a" .. encode(value) .. "bb cc dddd", { maxChars = 8, prefix = "", suffix = "" },
            { "a", "bb cc", "dddd" })
    end
    local literal = "a" .. encode(8203) .. encode(65279) .. "b"
    fixture(literal, { maxChars = 4 }, { literal }) -- ZWSP/BOM are not whitespace.
end)

test("strict Length counts Unicode scalars, not bytes/graphemes", function()
    equal(S.Length(""), 0)
    equal(S.Length("Aé猫😀é"), 6)
    equal(S.Length("\0\t\r\n|"), 5) -- Length validates encoding, not outgoing safety.
    for _, value in ipairs({ 0, 127, 128, 2047, 2048, 55295, 57344, 65535, 65536, 1114111 }) do
        equal(S.Length(encode(value)), 1, "scalar " .. value)
    end
    for _, value in ipairs({ false, 1, {} }) do
        local count, err = S.Length(value)
        equal(count, nil)
        assert(type(err) == "string" and err:match("string"))
    end
    local count, err = S.Length(nil)
    equal(count, nil)
    assert(type(err) == "string" and err:match("string"))
end)

test("invalid UTF-8 rejected in text and even unused markers", function()
    local invalid = {
        { 128 }, { 191 }, { 192, 128 }, { 193, 191 }, { 194 }, { 194, 65 },
        { 224, 128, 128 }, { 224, 159, 191 }, { 226, 130 }, { 226, 65, 128 },
        { 237, 160, 128 }, { 237, 191, 191 }, { 240, 128, 128, 128 },
        { 240, 143, 191, 191 }, { 240, 159, 152 }, { 240, 159, 65, 128 },
        { 244, 144, 128, 128 }, { 245, 128, 128, 128 },
        { 248, 136, 128, 128, 128 }, { 252, 132, 128, 128, 128, 128 }, { 254 }, { 255 },
    }
    for _, bytes in ipairs(invalid) do
        local text = string.char(unpack(bytes))
        local count, err = S.Length("ok" .. text)
        equal(count, nil)
        assert(type(err) == "string" and err:match("UTF%-8") and err:match("byte"))
        fails("ok" .. text, { maxChars = 100 }, "UTF%-8")
        fails("x", { maxChars = 100, prefix = text }, "prefix.*UTF%-8")
        fails("x", { maxChars = 100, suffix = text }, "suffix.*UTF%-8")
    end
end)

test("input and option validation", function()
    fails("x", nil, "options")
    fails("x", false, "options")
    fails("x", {}, "maxChars")
    for _, limit in ipairs({ 0, -1, 1.5, "20", false, {}, math.huge, -math.huge, 0 / 0 }) do
        fails("x", { maxChars = limit }, "maxChars")
    end
    fails(nil, { maxChars = 20 }, "string")
    fails(12, { maxChars = 20 }, "string")
    fails("", { maxChars = 20 }, "empty")
    fails(" \t\r\n" .. encode(160), { maxChars = 20 }, "empty")
    fails("x", { maxChars = 20, sentences = 1 }, "boolean")
    fails("x", { maxChars = 20, prefix = false }, "prefix.*string")
    fails("x", { maxChars = 20, suffix = {} }, "suffix.*string")
    fails("ab", { maxChars = 1 }, "too small")
    fails("abcdef", { maxChars = 4 }, "too small")
    fails("abcdefgh", { maxChars = 5, prefix = "long", suffix = "+" }, "too small")
end)

test("reject controls, pipe markup, and unsafe markers", function()
    for value = 0, 159 do
        if value < 32 or value >= 127 then
            local char = encode(value)
            if value ~= 9 and value ~= 10 and value ~= 13 and value ~= 133 then
                fails("a" .. char .. "b", { maxChars = 20 }, "control")
            end
            fails("x", { maxChars = 20, prefix = char }, "control")
            fails("x", { maxChars = 20, suffix = char }, "control")
        end
    end
    for _, char in ipairs({ encode(8232), encode(8233) }) do
        fails("x", { maxChars = 20, prefix = char }, "newlines")
        fails("x", { maxChars = 20, suffix = char }, "newlines")
    end
    for _, text in ipairs({ "a|b", "|H1:item:123|hLink|h", "|cffffffcolor|r", "a||b" }) do
        fails(text, { maxChars = 20 }, "pipe")
    end
    fails("x", { maxChars = 20, prefix = "|" }, "prefix.*pipe")
    fails("x", { maxChars = 20, suffix = "|" }, "suffix.*pipe")
    fails("x", { maxChars = 20, prefix = "/say " }, "prefix.*command")
    fails("x", { maxChars = 20, prefix = " " .. encode(160) .. "/say " }, "prefix.*command")
end)

test("every outgoing chunk checked for native commands", function()
    fails("/say hello", { maxChars = 20 }, "chunk 1.*command")
    fails(" \t" .. encode(160) .. "/say hello", { maxChars = 20 }, "command")
    fails("aaaa /say", { maxChars = 5, prefix = "", suffix = "" }, "chunk 2.*command")
    fails("aaaa/say", { maxChars = 4, prefix = "", suffix = "" }, "chunk 2.*command")
    fails("aaaa /say", { maxChars = 6, prefix = " ", suffix = "" }, "chunk 2.*command")
    fixture("aaaaaa /say", { maxChars = 8 }, { "aaaaaa +", "+ /say" })
    fixture("a/b", { maxChars = 3 }, { "a/b" })
end)

test("marker normalization, Unicode marker lengths, no option mutation", function()
    fixture("abcdefg", { maxChars = 5, prefix = "→ ", suffix = " ←" },
        { "abc ←", "→ d ←", "→ efg" })
    local options = { maxChars = 6, prefix = "→" .. encode(160) .. "  ", suffix = "  " .. encode(8195) .. "←" }
    local originalPrefix, originalSuffix = options.prefix, options.suffix
    fixture("abcdefghij", options, { "abcd ←", "→ ef ←", "→ ghij" })
    equal(options.prefix, originalPrefix)
    equal(options.suffix, originalSuffix)
    fixture("abc def ghi", { maxChars = 5, prefix = "", suffix = "" }, { "abc", "def", "ghi" })
end)

test("large drafts are not truncated", function()
    local text = string.rep("é猫😀a word. ", 2000) .. "END"
    local options = { maxChars = 80 }
    local chunks, err = S.Split(text, options)
    assert(chunks, err)
    conserved(text, chunks, options)
end)

local seed = 1729
local function random(maximum)
    seed = seed * 48271 % 2147483647
    return seed % maximum + 1
end

test("randomized normalization, conservation, safety, and UTF-8 budgets", function()
    local letters = { "a", "Z", "é", "猫", "😀", "́", "…", ".", "!", "?", "”", "’", "-", "(", ")" }
    local spaces = { " ", "  ", "\t", "\r\n", "\n", "\r", encode(160), encode(8195), encode(8232), encode(133) }
    local prefixes, suffixes = { "", "+ ", "→ " }, { "", " +", " ←" }
    for iteration = 1, 1000 do
        local raw, expected = {}, {}
        for index = 1, random(300) do
            if random(4) == 1 then
                raw[#raw + 1] = spaces[random(#spaces)]
                expected[#expected + 1] = " "
            else
                local char = letters[random(#letters)]
                raw[#raw + 1], expected[#expected + 1] = char, char
            end
        end
        -- Always nonempty, while exercising trimming at both ends.
        raw[#raw + 1], expected[#expected + 1] = "Ω\t ", "Ω "
        local canonical = table.concat(expected):gsub(" +", " "):gsub("^ ", ""):gsub(" $", "")
        local options = {
            maxChars = random(60) + 4,
            prefix = prefixes[random(#prefixes)], suffix = suffixes[random(#suffixes)],
            sentences = random(2) == 1,
        }
        local text = table.concat(raw)
        local chunks, err = S.Split(text, options)
        assert(chunks, "iteration " .. iteration .. ": " .. tostring(err))
        conserved(canonical, chunks, options)
        equal(S.Length(text), referenceLength(text), "original UTF-8 length")
        local again = assert(S.Split(text, options))
        equal(table.concat(again, "\n"), table.concat(chunks, "\n"), "determinism")
    end
end)

test("randomized Unicode scalar lengths and hard cuts", function()
    for iteration = 1, 200 do
        local chars = {}
        for index = 1, random(100) do
            local value = random(1114112) - 1
            -- Avoid controls/whitespace/markup/commands to isolate hard cuts.
            if value < 256 or (value >= 55296 and value <= 57343)
                or value == 5760 or (value >= 8192 and value <= 8202)
                or value == 8232 or value == 8233 or value == 8239
                or value == 8287 or value == 12288 then
                value = 29483
            end
            chars[#chars + 1] = encode(value)
        end
        local text = table.concat(chars)
        equal(S.Length(text), #chars)
        local options = { maxChars = random(12), prefix = "", suffix = "" }
        local chunks, err = S.Split(text, options)
        assert(chunks, err)
        conserved(text, chunks, options)
        equal(table.concat(chunks), text, "byte-exact hard-cut conservation")
    end
end)

print("splitter_spec: " .. tests .. " tests passed (1,200 randomized cases)")
