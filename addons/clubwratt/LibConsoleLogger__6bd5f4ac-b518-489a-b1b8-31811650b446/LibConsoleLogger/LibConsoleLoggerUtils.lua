-- LibConsoleLoggerUtils.lua: helper utilities (pure)

LibConsoleLogger = LibConsoleLogger or {}
LibConsoleLogger.Utils = LibConsoleLogger.Utils or {}

local Utils = LibConsoleLogger.Utils

---@param value any
---@return string
function Utils.Trim(value)
    local s = tostring(value or "")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

---@param value any
---@return string
function Utils.NormalizeLine(value)
    local s = tostring(value or "")
    if s == "" then
        return "[Empty String]"
    end
    return s
end

---Trim and default the scheme: "192.168.1.50:7878" becomes "http://192.168.1.50:7878".
---An explicit scheme (http://, https://, ...) is left untouched.
---@param value any
---@return string
function Utils.NormalizeUrl(value)
    local url = Utils.Trim(value)
    if url == "" then
        return url
    end
    if url:find("^%a[%w+.%-]*://") then
        return url
    end
    return "http://" .. url
end

---A timestamp as wall-clock text, "2026-11-14 21:03:05"; "t=<stamp>" where the game offers no formatter.
---@param stamp number Seconds, as GetTimeStamp returns
---@return string
function Utils.WallClock(stamp)
    local osLib = rawget(_G, "os")
    if type(osLib) == "table" and type(osLib.date) == "function" then
        local ok, formatted = pcall(osLib.date, "%Y-%m-%d %H:%M:%S", stamp)
        if ok and type(formatted) == "string" then return formatted end
    elseif GetDateStringFromTimestamp and GetTimeString then
        local ok, formatted = pcall(function() return GetDateStringFromTimestamp(stamp) .. " " .. GetTimeString() end)
        if ok and type(formatted) == "string" then return formatted end
    end
    return "t=" .. tostring(stamp)
end

-- The game does not save a string of 2000 bytes or more, and on the console a saved table that holds one
-- fails the whole save ("the auto save file is corrupted", 2026-11-24). Everything this library keeps in its
-- saved variables is held in strings of at most this many bytes.
Utils.MAX_SAVED_STRING_BYTES = 1900

---Text cut into pieces of at most maxBytes, never inside a UTF-8 character; joined they are the text again.
---@param text string
---@param maxBytes number
---@return string[] pieces At least one, also for ""
function Utils.Pieces(text, maxBytes)
    local pieces = {}
    local pos, length = 1, #text
    while length - pos + 1 > maxBytes do
        local stop = pos + maxBytes - 1
        -- A byte of the form 10xxxxxx continues a character: the cut moves back to before the character.
        while stop > pos do
            local following = string.byte(text, stop + 1)
            if following < 128 or following >= 192 then
                break
            end
            stop = stop - 1
        end
        pieces[#pieces + 1] = string.sub(text, pos, stop)
        pos = stop + 1
    end
    pieces[#pieces + 1] = string.sub(text, pos)
    return pieces
end

---@param webExport table|nil
---@return boolean
function Utils.HasConfiguredUrl(webExport)
    if not (webExport and webExport.GetUrl) then
        return false
    end
    local url = Utils.Trim(webExport.GetUrl(nil))
    return url ~= ""
end

---@param sink fun(line: any): boolean accepted
---@param t table
---@param indent string|nil
---@param tableHistory table<table, boolean>|nil
---@return boolean acceptedAny
function Utils.WalkTableWithSink(sink, t, indent, tableHistory)
    indent = indent or "."
    tableHistory = tableHistory or {}

    local acceptedAny = false
    for k, v in pairs(t) do
        local vType = type(v)
        acceptedAny = sink(string.format("%s(%s): %s = %s", indent, vType, tostring(k), tostring(v))) or acceptedAny
        if vType == "table" then
            if tableHistory[v] then
                acceptedAny = sink(indent .. "Avoiding cycle on table...") or acceptedAny
            else
                tableHistory[v] = true
                acceptedAny = Utils.WalkTableWithSink(sink, v, indent .. "  ", tableHistory) or acceptedAny
            end
        end
    end
    return acceptedAny
end
