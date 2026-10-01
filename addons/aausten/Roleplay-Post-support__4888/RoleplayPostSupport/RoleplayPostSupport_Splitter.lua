-- Lua 5.1; depends on the shared localization helper (or a standalone test fixture).
-- No chat/UI dependency. The caller must supply the runtime chat limit.
RoleplayPostSupport = RoleplayPostSupport or {}
local L = RoleplayPostSupport.L
local S = {}
RoleplayPostSupport.Splitter = S

local byte, sub, concat = string.byte, string.sub, table.concat

-- Shared wire convention: four U+200B ZERO WIDTH SPACE characters, not NUL bytes.
-- This is an opt-in classification marker, not authenticated provenance.
S.MESSAGE_TAG = string.rep("\226\128\139", 4)
S.MESSAGE_TAG_LENGTH = 4

function S.StripMessageTag(text)
    if type(text) == "string" and sub(text, 1, #S.MESSAGE_TAG) == S.MESSAGE_TAG then
        return sub(text, #S.MESSAGE_TAG + 1), true
    end
    return text, false
end

-- Returns one Unicode scalar value and the next byte offset, or nil, error.
local function decode(text, at)
    local first = byte(text, at)
    if first < 128 then
        return first, at + 1
    end

    local size, value, minimum
    if first >= 194 and first <= 223 then
        size, value, minimum = 2, first - 192, 128
    elseif first >= 224 and first <= 239 then
        size, value, minimum = 3, first - 224, 2048
    elseif first >= 240 and first <= 244 then
        size, value, minimum = 4, first - 240, 65536
    else
        return nil, L("SPLITTER_UTF8_INVALID_LEADING_BYTE", at)
    end
    if at + size - 1 > #text then
        return nil, L("SPLITTER_UTF8_TRUNCATED_SEQUENCE", at)
    end
    for offset = 1, size - 1 do
        local nextByte = byte(text, at + offset)
        if nextByte < 128 or nextByte > 191 then
            return nil, L("SPLITTER_UTF8_INVALID_CONTINUATION_BYTE", at + offset)
        end
        value = value * 64 + nextByte - 128
    end
    if value < minimum then
        return nil, L("SPLITTER_UTF8_OVERLONG_SEQUENCE", at)
    end
    if value >= 55296 and value <= 57343 then
        return nil, L("SPLITTER_UTF8_SURROGATE", at)
    end
    if value > 1114111 then
        return nil, L("SPLITTER_UTF8_CODEPOINT_OUT_OF_RANGE", at)
    end
    return value, at + size
end

function S.Length(text)
    if type(text) ~= "string" then
        return nil, L("SPLITTER_FIELD_MUST_BE_STRING", L("SPLITTER_LABEL_TEXT"))
    end
    local at, count = 1, 0
    while at <= #text do
        local value, nextAt = decode(text, at)
        if not value then
            return nil, nextAt
        end
        count, at = count + 1, nextAt
    end
    return count
end

-- Unicode White_Space (not zero-width space or BOM). NEL and Unicode line/
-- paragraph separators count as newlines, as do CR and LF (including CRLF).
local function whitespace(value)
    if value == 10 or value == 13 or value == 133
        or value == 8232 or value == 8233 then
        return 3
    end
    if value == 9 or value == 32 or value == 160 or value == 5760
        or (value >= 8192 and value <= 8202) or value == 8239
        or value == 8287 or value == 12288 then
        return 1
    end
end

local function control(value)
    return value < 32 or (value >= 127 and value <= 159)
end

-- Normalization is intentionally lossy for layout, never for non-whitespace:
-- body whitespace runs become one ASCII space, with outer whitespace removed.
-- VT/FF and other controls are rejected, not treated as whitespace. NBSP loses
-- its non-breaking property. Newline priority survives until a boundary is cut;
-- no newline is emitted. Splitting also removes the space at a chosen boundary.
-- Markers collapse horizontal whitespace too, but retain one outer space so
-- the default markers work. No Unicode composition normalization is performed.
local function normalize(text, label, marker)
    if type(text) ~= "string" then
        return nil, L("SPLITTER_FIELD_MUST_BE_STRING", label)
    end
    local chars, breaks = {}, {}
    local at, pending = 1, nil
    while at <= #text do
        local value, nextAt = decode(text, at)
        if not value then
            return nil, L("SPLITTER_FIELD_ERROR", label, nextAt)
        end
        local space = whitespace(value)
        if value == 124 then
            return nil, L("SPLITTER_FIELD_FORBIDDEN_PIPE_MARKUP", label)
        end
        if marker and (space == 3 or control(value)) then
            return nil, L("SPLITTER_FIELD_NEWLINE_OR_CONTROL", label)
        end
        if not space and control(value) then
            return nil, L("SPLITTER_FIELD_FORBIDDEN_CONTROL", label, at)
        end
        if space then
            pending = math.max(pending or 0, space)
        else
            if pending and (marker or #chars > 0) then
                chars[#chars + 1] = " "
                breaks[#chars] = pending
            end
            pending = nil
            chars[#chars + 1] = sub(text, at, nextAt - 1)
        end
        at = nextAt
    end
    if marker and pending then
        chars[#chars + 1] = " "
    end
    return chars, breaks
end

local terminators = { ["."] = true, ["!"] = true, ["?"] = true, ["…"] = true }
local closers = {
    ['"'] = true, ["'"] = true, ["”"] = true, ["’"] = true,
    ["»"] = true, ["›"] = true, [")"] = true, ["]"] = true, ["}"] = true,
}

-- A deliberately simple sentence heuristic: punctuation, optionally followed
-- by closing quotes/brackets, then whitespace. It does not parse abbreviations
-- or languages without inter-sentence spaces. Codepoints, not grapheme clusters,
-- are the unit of the chat budget (a hard cut may separate combining marks).
local function markSentences(chars, breaks)
    local ending = false
    for index, char in ipairs(chars) do
        if char == " " then
            if ending and breaks[index] ~= 3 then
                breaks[index] = 2
            end
            ending = false
        elseif terminators[char] then
            ending = true
        elseif not closers[char] then
            ending = false
        end
    end
end

local function commandLike(text)
    return text:match("^ */") ~= nil
end

-- Split(text, { maxChars = runtimeLimit, prefix = '+ ', suffix = ' +',
--               sentences = true }) -> chunks | nil, error
-- maxChars counts Unicode codepoints INCLUDING markers. First/middle/last
-- chunks use suffix / both / prefix respectively; a single chunk is unmarked.
-- Empty markers are allowed. Validation still applies to unused markers.
-- All errors are atomic: no partial chunks or truncated draft are returned.
function S.Split(text, options)
    if type(options) ~= "table" then
        return nil, L("SPLITTER_OPTIONS_MUST_BE_TABLE")
    end
    local limit = options.maxChars
    if type(limit) ~= "number" or limit ~= limit or limit == math.huge
        or limit < 1 or limit ~= math.floor(limit) then
        return nil, L("SPLITTER_MAX_CHARS_MUST_BE_POSITIVE_INTEGER")
    end
    if options.sentences ~= nil and type(options.sentences) ~= "boolean" then
        return nil, L("SPLITTER_SENTENCES_MUST_BE_BOOLEAN")
    end

    local prefix, suffix = options.prefix, options.suffix
    if prefix == nil then prefix = "+ " end
    if suffix == nil then suffix = " +" end
    local prefixChars, err = normalize(prefix, L("SPLITTER_LABEL_PREFIX"), true)
    if not prefixChars then return nil, err end
    local suffixChars
    suffixChars, err = normalize(suffix, L("SPLITTER_LABEL_SUFFIX"), true)
    if not suffixChars then return nil, err end
    prefix, suffix = concat(prefixChars), concat(suffixChars)
    if commandLike(prefix) then
        return nil, L("SPLITTER_FIELD_STARTS_COMMAND", L("SPLITTER_LABEL_PREFIX"))
    end

    local chars, breaks = normalize(text, L("SPLITTER_LABEL_TEXT"), false)
    if not chars then return nil, breaks end
    local total = #chars
    if total == 0 then
        return nil, L("SPLITTER_TEXT_EMPTY")
    end
    if options.sentences ~= false then
        markSentences(chars, breaks)
    end

    local chunks, start = {}, 1
    while start <= total do
        local leading = #chunks > 0 and prefix or ""
        local leadingLength = #chunks > 0 and #prefixChars or 0
        local available = limit - leadingLength
        local finish, nextStart, trailing
        if total - start + 1 <= available then
            finish, nextStart, trailing = total, total + 1, ""
        else
            available = available - #suffixChars
            if available < 1 then
                return nil, L("SPLITTER_MAX_CHARS_TOO_SMALL")
            end
            local best, priority = nil, 0
            -- A separator just beyond the budget can be consumed without
            -- emitting it. For equal priorities, prefer the furthest boundary.
            for index = start + 1, math.min(total, start + available) do
                local rank = breaks[index]
                if rank and rank >= priority then
                    best, priority = index, rank
                end
            end
            if best then
                finish, nextStart = best - 1, best + 1
            else
                finish, nextStart = start + available - 1, start + available
            end
            trailing = suffix
        end
        local chunk = leading .. concat(chars, "", start, finish) .. trailing
        if commandLike(chunk) then
            return nil, L("SPLITTER_CHUNK_STARTS_COMMAND", #chunks + 1)
        end
        chunks[#chunks + 1] = chunk
        start = nextStart
    end
    return chunks
end

return S
