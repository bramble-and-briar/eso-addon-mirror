-- LibConsoleLoggerErrors.lua: the game's Lua errors, recorded under the "Errors" scope
--
-- A console shows no error window, so an error from any addon or from the game's own UI is otherwise silent.
-- While logging is enabled each one is buffered here, as if the game had logged it through this library.

LibConsoleLogger = LibConsoleLogger or {}
LibConsoleLogger.Errors = LibConsoleLogger.Errors or {}

local Errors = LibConsoleLogger.Errors

local EVENT_NAMESPACE = "LibConsoleLogger_Errors"
-- An error text carries its stack trace; the head of it names the fault and the frames nearest to it.
local MAX_ERROR_CHARS = 1000
-- How many distinct errors are told apart at once; past that the tally starts over.
local MAX_DISTINCT_ERRORS = 200

-- Times each error text was seen this UI load. An error raised every frame is recorded once in full, then as
-- a count at 10, 100, 1000... so it cannot push every other line out of the buffer.
---@type table<string, number>
local seen = {}
local distinct = 0

---@param text string
---@return string[] lines
local function HeadLines(text)
    if #text > MAX_ERROR_CHARS then
        text = string.sub(text, 1, MAX_ERROR_CHARS) .. " ..."
    end
    local lines = {}
    for line in string.gmatch(text, "[^\r\n]+") do
        lines[#lines + 1] = line
    end
    return lines
end

---@param n number
---@return boolean
local function IsPowerOfTen(n)
    local power = 10
    while power < n do
        power = power * 10
    end
    return power == n
end

---@param errorText any
local function Record(errorText)
    local text = tostring(errorText)
    local count = (seen[text] or 0) + 1
    if count == 1 then
        if distinct >= MAX_DISTINCT_ERRORS then
            seen, distinct = {}, 0
        end
        distinct = distinct + 1
    end
    seen[text] = count

    local logger = LibConsoleLogger:For(LibConsoleLogger.errorsScope)
    if count == 1 then
        logger:Buffer(unpack(HeadLines(text)))
    elseif IsPowerOfTen(count) then
        logger:Buffer(string.format("x%d: %s", count, HeadLines(text)[1] or ""))
    end
end

local recording = false

---Record one Lua error (the handler of EVENT_LUA_ERROR). It never raises: an error inside it would come
---straight back as another event.
---@param errorText any
function Errors.Record(errorText)
    if recording or not LibConsoleLogger:IsEnabled() then
        return
    end
    recording = true
    pcall(Record, errorText)
    recording = false
end

---Start listening for the game's errors, and list the Errors scope. Called once the library has loaded.
function Errors.Register()
    LibConsoleLogger:For(LibConsoleLogger.errorsScope)
    if EVENT_MANAGER and EVENT_LUA_ERROR then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_LUA_ERROR, function(_eventId, errorText)
            Errors.Record(errorText)
        end)
    end
end
