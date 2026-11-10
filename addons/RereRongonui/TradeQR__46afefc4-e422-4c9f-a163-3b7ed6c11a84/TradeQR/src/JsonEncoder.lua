-- Minimal JSON encoder for flat objects with string / number / boolean values.
-- Keys are given as an ordered list of { key, value } pairs, so the output is deterministic.
local JsonEncoder = ZO_InitializingObject:Subclass()

-- Characters that must be escaped inside a JSON string.
local ESCAPES = {
    ["\""] = "\\\"",
    ["\\"] = "\\\\",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
}

function JsonEncoder:EncodeString(text)
    local escaped = string.gsub(text, "[%c\"\\]", function(char)
        return ESCAPES[char] or string.format("\\u%04x", string.byte(char))
    end)
    return "\"" .. escaped .. "\""
end

function JsonEncoder:EncodeNumber(number)
    -- "%.0f" keeps integer53 values (event ids, timestamps) exact; tostring() would use %.14g.
    if number == math.floor(number) then
        return string.format("%.0f", number)
    end
    return tostring(number)
end

function JsonEncoder:EncodeValue(value)
    local valueType = type(value)
    if valueType == "string" then
        return self:EncodeString(value)
    elseif valueType == "number" then
        return self:EncodeNumber(value)
    elseif valueType == "boolean" then
        return value and "true" or "false"
    end
    return "null"
end

function JsonEncoder:EncodeObject(orderedPairs)
    local parts = {}
    for _, pair in ipairs(orderedPairs) do
        parts[#parts + 1] = self:EncodeString(pair[1]) .. ":" .. self:EncodeValue(pair[2])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

TradeQR.JsonEncoder = JsonEncoder
