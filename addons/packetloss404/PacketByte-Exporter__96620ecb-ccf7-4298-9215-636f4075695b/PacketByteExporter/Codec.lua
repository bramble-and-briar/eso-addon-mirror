local PBE = PacketByteExporter
PBE.Codec = {}
local Codec = PBE.Codec

local base64url = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local objectMarker = {}

-- Lua's empty table is ambiguous. Mark collector maps without adding a field
-- to the exported JSON; ordinary empty lists still serialize as [].
function Codec.Object(value)
    value = value or {}
    if type(value) ~= "table" then
        error("JSON object marker requires a table")
    end
    return setmetatable(value, objectMarker)
end

function Codec.ObjectMarked(value)
    return type(value) == "table" and getmetatable(value) == objectMarker
end

local function IsArray(value)
    if Codec.ObjectMarked(value) then
        return false
    end
    local count = 0
    local max = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        count = count + 1
        if key > max then
            max = key
        end
    end
    return count == max
end

local function SortedObjectEntries(value)
    local entries = {}
    for key in pairs(value) do
        entries[#entries + 1] = { key = key, text = tostring(key) }
    end
    table.sort(entries, function(left, right)
        return left.text < right.text
    end)
    for index = 2, #entries do
        if entries[index - 1].text == entries[index].text then
            error("JSON object keys collide after string conversion: " .. entries[index].text)
        end
    end
    return entries
end

local function EscapeString(value)
    return value:gsub('[%z\1-\31\\"]', function(char)
        local escapes = {
            ['"'] = '\\"',
            ['\\'] = '\\\\',
            ['\b'] = '\\b',
            ['\f'] = '\\f',
            ['\n'] = '\\n',
            ['\r'] = '\\r',
            ['\t'] = '\\t',
        }
        return escapes[char] or string.format("\\u%04x", string.byte(char))
    end)
end

local function EncodeJson(value, stack)
    local valueType = type(value)
    if value == nil then
        return "null"
    elseif valueType == "boolean" then
        return value and "true" or "false"
    elseif valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return "null"
        end
        return tostring(value)
    elseif valueType == "string" then
        return '"' .. EscapeString(value) .. '"'
    elseif valueType ~= "table" then
        return '"' .. EscapeString(tostring(value)) .. '"'
    end

    if stack[value] then
        error("cannot encode a cyclic table")
    end
    stack[value] = true

    local output = {}
    if IsArray(value) then
        for index = 1, #value do
            output[#output + 1] = EncodeJson(value[index], stack)
        end
        stack[value] = nil
        return "[" .. table.concat(output, ",") .. "]"
    end

    for _, entry in ipairs(SortedObjectEntries(value)) do
        output[#output + 1] = '"' .. EscapeString(entry.text) .. '":' .. EncodeJson(value[entry.key], stack)
    end
    stack[value] = nil
    return "{" .. table.concat(output, ",") .. "}"
end

function Codec.JsonEncode(value)
    return EncodeJson(value, {})
end

-- The console capture uses this stateful encoder so even large nested sections
-- can be serialized over multiple frames instead of one slash-command frame.
local function AppendJson(state, part)
    state.parts[#state.parts + 1] = part
    if #state.parts >= 256 then
        state.chunks[#state.chunks + 1] = table.concat(state.parts)
        state.parts = {}
    end
end

function Codec.NewJsonEncoder(value, keyTransform)
    return {
        active = {},
        chunks = {},
        done = false,
        keyTransform = keyTransform,
        parts = {},
        stack = { { kind = "value", value = value } },
    }
end

function Codec.JsonEncoderStep(state, maxOperations)
    if state.done then
        return true
    end
    for _ = 1, maxOperations do
        local frame = state.stack[#state.stack]
        if not frame then
            state.done = true
            break
        end

        if frame.kind == "value" then
            state.stack[#state.stack] = nil
            local value = frame.value
            local valueType = type(value)
            if value == nil then
                AppendJson(state, "null")
            elseif valueType == "boolean" then
                AppendJson(state, value and "true" or "false")
            elseif valueType == "number" then
                if value ~= value or value == math.huge or value == -math.huge then
                    AppendJson(state, "null")
                else
                    AppendJson(state, tostring(value))
                end
            elseif valueType == "string" then
                AppendJson(state, '"' .. EscapeString(value) .. '"')
            elseif valueType ~= "table" then
                AppendJson(state, '"' .. EscapeString(tostring(value)) .. '"')
            else
                if state.active[value] then
                    error("cannot encode a cyclic table")
                end
                state.active[value] = true
                if IsArray(value) then
                    AppendJson(state, "[")
                    state.stack[#state.stack + 1] = {
                        kind = "array", value = value, index = 1, count = #value,
                    }
                else
                    local entries = SortedObjectEntries(value)
                    AppendJson(state, "{")
                    state.stack[#state.stack + 1] = {
                        kind = "object", value = value, index = 1, entries = entries,
                    }
                end
            end
        elseif frame.kind == "array" then
            if frame.index > frame.count then
                AppendJson(state, "]")
                state.active[frame.value] = nil
                state.stack[#state.stack] = nil
            else
                if frame.index > 1 then
                    AppendJson(state, ",")
                end
                local value = frame.value[frame.index]
                frame.index = frame.index + 1
                state.stack[#state.stack + 1] = { kind = "value", value = value }
            end
        else
            if frame.index > #frame.entries then
                AppendJson(state, "}")
                state.active[frame.value] = nil
                state.stack[#state.stack] = nil
            else
                if frame.index > 1 then
                    AppendJson(state, ",")
                end
                local entry = frame.entries[frame.index]
                frame.index = frame.index + 1
                local encodedKey = state.keyTransform and state.keyTransform(entry.text) or entry.text
                AppendJson(state, '"' .. EscapeString(encodedKey) .. '":')
                state.stack[#state.stack + 1] = { kind = "value", value = frame.value[entry.key] }
            end
        end
    end
    if #state.stack == 0 then
        state.done = true
    end
    return state.done
end

function Codec.JsonEncoderResult(state)
    if not state.done then
        error("JSON encoding is not complete")
    end
    if #state.parts > 0 then
        state.chunks[#state.chunks + 1] = table.concat(state.parts)
        state.parts = {}
    end
    return table.concat(state.chunks)
end

local function EncodeCode(code)
    local a = math.floor(code / 4096) % 64
    local b = math.floor(code / 64) % 64
    local c = code % 64
    return base64url:sub(a + 1, a + 1)
        .. base64url:sub(b + 1, b + 1)
        .. base64url:sub(c + 1, c + 1)
end

-- A small, dependency-free LZW codec. Codes are fixed-width, URL-safe triples.
-- The corresponding decoder lives in receiver/lib/codec.mjs.
function Codec.Compress(value)
    if value == "" then
        return ""
    end

    local dictionary = {}
    for code = 0, 255 do
        dictionary[string.char(code)] = code
    end

    local nextCode = 256
    local output = {}
    local current = ""
    for index = 1, #value do
        local char = value:sub(index, index)
        local candidate = current .. char
        if dictionary[candidate] ~= nil then
            current = candidate
        else
            output[#output + 1] = EncodeCode(dictionary[current])
            if nextCode <= 65535 then
                dictionary[candidate] = nextCode
                nextCode = nextCode + 1
            end
            current = char
        end
    end
    if current ~= "" then
        output[#output + 1] = EncodeCode(dictionary[current])
    end
    return table.concat(output)
end

function Codec.NewCompressor()
    local dictionary = {}
    for code = 0, 255 do
        dictionary[string.char(code)] = code
    end
    return {
        current = "",
        dictionary = dictionary,
        done = false,
        index = 1,
        nextCode = 256,
        output = {},
    }
end

function Codec.CompressStep(state, value, maxBytes)
    if state.done then
        return true
    end
    local stop = math.min(#value, state.index + maxBytes - 1)
    for index = state.index, stop do
        local char = value:sub(index, index)
        local candidate = state.current .. char
        if state.dictionary[candidate] ~= nil then
            state.current = candidate
        else
            state.output[#state.output + 1] = EncodeCode(state.dictionary[state.current])
            if state.nextCode <= 65535 then
                state.dictionary[candidate] = state.nextCode
                state.nextCode = state.nextCode + 1
            end
            state.current = char
        end
    end
    state.index = stop + 1
    if state.index > #value then
        if state.current ~= "" then
            state.output[#state.output + 1] = EncodeCode(state.dictionary[state.current])
            state.current = ""
        end
        state.done = true
    end
    return state.done
end

function Codec.CompressorResult(state)
    if not state.done then
        error("compression is not complete")
    end
    return table.concat(state.output)
end

-- Version 2 packs variable-width LZW codes directly into URL-safe sextets.
-- The first four sextets hold the number of codes, so a truncated stream
-- cannot masquerade as a shorter, valid stream. Version 1 remains unchanged.
local function PackedEmit(state, code)
    state.bitBuffer = state.bitBuffer * (2 ^ state.width) + code
    state.bitCount = state.bitCount + state.width
    while state.bitCount >= 6 do
        state.bitCount = state.bitCount - 6
        local divisor = 2 ^ state.bitCount
        local digit = math.floor(state.bitBuffer / divisor)
        state.output[#state.output + 1] = base64url:sub(digit + 1, digit + 1)
        state.bitBuffer = state.bitBuffer % divisor
    end
    state.codeCount = state.codeCount + 1
end

function Codec.NewPackedCompressor()
    local dictionary = {}
    for code = 0, 255 do
        dictionary[string.char(code)] = code
    end
    return {
        bitBuffer = 0,
        bitCount = 0,
        codeCount = 0,
        current = "",
        dictionary = dictionary,
        done = false,
        index = 1,
        nextCode = 256,
        output = {},
        width = 9,
    }
end

function Codec.PackedCompressStep(state, value, maxBytes)
    if state.done then
        return true
    end
    if maxBytes < 1 then
        error("maxBytes must be positive")
    end
    local stop = math.min(#value, state.index + maxBytes - 1)
    for index = state.index, stop do
        local char = value:sub(index, index)
        local candidate = state.current .. char
        if state.dictionary[candidate] ~= nil then
            state.current = candidate
        else
            PackedEmit(state, state.dictionary[state.current])
            if state.nextCode <= 65535 then
                state.dictionary[candidate] = state.nextCode
                state.nextCode = state.nextCode + 1
                if state.nextCode > 2 ^ state.width and state.width < 16 then
                    state.width = state.width + 1
                end
            end
            state.current = char
        end
    end
    state.index = stop + 1
    if state.index > #value then
        if state.current ~= "" then
            PackedEmit(state, state.dictionary[state.current])
            state.current = ""
        end
        if state.bitCount > 0 then
            local digit = state.bitBuffer * (2 ^ (6 - state.bitCount))
            state.output[#state.output + 1] = base64url:sub(digit + 1, digit + 1)
            state.bitBuffer = 0
            state.bitCount = 0
        end
        state.done = true
    end
    return state.done
end

function Codec.PackedCompressorResult(state)
    if not state.done then
        error("compression is not complete")
    end
    if state.codeCount > 16777215 then
        error("packed payload exceeds 24-bit code count")
    end
    local count = state.codeCount
    local header = {}
    for index = 4, 1, -1 do
        local digit = count % 64
        header[index] = base64url:sub(digit + 1, digit + 1)
        count = math.floor(count / 64)
    end
    return table.concat(header) .. table.concat(state.output)
end

function Codec.Adler32(value)
    local a = 1
    local b = 0
    for index = 1, #value do
        a = (a + string.byte(value, index)) % 65521
        b = (b + a) % 65521
    end
    return string.format("%08x", b * 65536 + a)
end

function Codec.NewChecksum()
    return { a = 1, b = 0, done = false, index = 1 }
end

function Codec.ChecksumStep(state, value, maxBytes)
    if state.done then
        return true
    end
    local stop = math.min(#value, state.index + maxBytes - 1)
    for index = state.index, stop do
        state.a = (state.a + string.byte(value, index)) % 65521
        state.b = (state.b + state.a) % 65521
    end
    state.index = stop + 1
    if state.index > #value then
        state.done = true
    end
    return state.done
end

function Codec.ChecksumResult(state)
    if not state.done then
        error("checksum is not complete")
    end
    return string.format("%08x", state.b * 65536 + state.a)
end

function Codec.Split(value, chunkSize)
    local chunks = {}
    for index = 1, #value, chunkSize do
        chunks[#chunks + 1] = value:sub(index, index + chunkSize - 1)
    end
    return chunks
end
