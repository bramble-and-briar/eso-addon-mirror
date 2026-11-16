TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Utilities = TacticalDisplay.Utilities or {}
local _Utilities = TacticalDisplay.Utilities

local function EncodeJSONString(value)
    local escaped = value:gsub('[%c"\\]', function(character)
        local shortEscapes = {
            ['"'] = '\\"',
            ['\\'] = '\\\\',
            ['\b'] = '\\b',
            ['\f'] = '\\f',
            ['\n'] = '\\n',
            ['\r'] = '\\r',
            ['\t'] = '\\t',
        }
        return shortEscapes[character] or string.format('\\u%04x', character:byte())
    end)
    return '"' .. escaped .. '"'
end

local function IsArray(tableValue)
    local index = 1
    for key in pairs(tableValue) do
        if key ~= index then
            return false
        end
        index = index + 1
    end
    return true
end

local function TableToJSON(value, seen)
    local valueType = type(value)

    if value == nil then
        return "null"
    elseif valueType == "boolean" then
        return tostring(value)
    elseif valueType == "number" then
        return tostring(value)
    elseif valueType == "string" then
        return EncodeJSONString(value)
    elseif valueType ~= "table" then
        error(("Cannot encode value of type %s to JSON"):format(valueType))
    end

    seen = seen or {}
    if seen[value] then
        error("Cannot encode recursive table to JSON")
    end
    seen[value] = true

    local parts = {}

    if IsArray(value) then
        for _, item in ipairs(value) do
            parts[#parts + 1] = TableToJSON(item, seen)
        end

        seen[value] = nil
        return "[" .. table.concat(parts, ",") .. "]"
    end

    for key, item in pairs(value) do
        if type(key) ~= "string" and type(key) ~= "number" then
            error("JSON object keys must be strings or numbers")
        end

        parts[#parts + 1] =
            EncodeJSONString(tostring(key)) ..
            ":" ..
            TableToJSON(item, seen)
    end

    seen[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end

function _Utilities.TableToJSON(value)
    return TableToJSON(value, {})
end

function _Utilities.LogDebug(message)
    d("[TacticalDisplay] |cCCCCCC" .. message .. "|r")
end

function _Utilities.LogError(message)
    d("[TacticalDisplay] |cFF3030" .. message .. "|r")
end
