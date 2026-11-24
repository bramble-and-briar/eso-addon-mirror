-- ErrorCatcherTraceUtils.lua: reading a stack trace (pure)
--
-- A trace is the text debug.traceback returns, or the tail of an error text. On a console an add-on file
-- reads "percache:/AddOnsManaged/<listing id>/<AddOn>/File.lua", on a PC "user:/AddOns/<AddOn>/File.lua",
-- and a game file "/EsoUI/...". The game interleaves "<Locals> ... </Locals>" lines, which are no frames.
local TraceUtils = {}

local TRACE_MARKER = "stack traceback:"
-- The file ZO_PreHook and ZO_PostHook build their wrappers in: a frame there is a wrapped game function.
local HOOK_FILE = "ZO_Hook.lua"
local PLAIN = true

---@param text string
---@return string
function TraceUtils.Trim(text)
    return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

---@param text string
---@param max number
---@return string
function TraceUtils.Clip(text, max)
    if #text > max then
        return string.sub(text, 1, max) .. "..."
    end
    return text
end

---@param source string
---@return string|nil addon
function TraceUtils.AddonOf(source)
    return string.match(source, "AddOnsManaged/[^/]+/([^/]+)/") or string.match(source, "AddOns/([^/]+)/")
end

---@param what string The part of a frame line after ": in "
---@return string
local function FunctionName(what)
    local named = string.match(what, "^function '(.-)'$")
    if named then
        return named
    end
    if string.match(what, "^function <.->$") then
        return "anonymous"
    end
    return what
end

---@param line string One trimmed line of a trace
---@return ErrorCatcherFrame|nil
local function ParseFrame(line)
    local source, lineNumber, what = string.match(line, "^(.-):(%d+): in (.+)$")
    if not source then
        what = string.match(line, "^%[C%]: in (.+)$")
        if what then
            source = "[C]"
        elseif string.sub(line, 1, 11) == "(tail call)" then
            source, what = "(tail call)", "?"
        else
            return nil
        end
    end
    return {
        source = source,
        file = string.match(source, "([^/\\]+)$") or source,
        line = tonumber(lineNumber),
        fn = FunctionName(what),
        addon = TraceUtils.AddonOf(source),
    }
end

---The frames of a trace, the raising function first. Text without a trace gives none.
---@param text any
---@return ErrorCatcherFrame[]
function TraceUtils.Frames(text)
    local frames = {}
    if type(text) ~= "string" then
        return frames
    end
    local started = false
    local inLocals = false
    for rawLine in string.gmatch(text, "[^\r\n]+") do
        local line = TraceUtils.Trim(rawLine)
        if not started then
            started = string.find(line, TRACE_MARKER, 1, PLAIN) ~= nil
        elseif inLocals then
            inLocals = string.find(line, "</Locals>", 1, PLAIN) == nil
        elseif string.find(line, "<Locals>", 1, PLAIN) then
            inLocals = string.find(line, "</Locals>", 1, PLAIN) == nil
        else
            local frame = ParseFrame(line)
            if frame then
                frames[#frames + 1] = frame
            end
        end
    end
    return frames
end

---Frames with one add-on's own left out, and without the C frames that led to them: what was on the stack
---when that add-on's hook ran.
---@param frames ErrorCatcherFrame[]
---@param ownAddon string
---@return ErrorCatcherFrame[]
function TraceUtils.Foreign(frames, ownAddon)
    local foreign = {}
    for _, frame in ipairs(frames) do
        local leadingC = #foreign == 0 and frame.source == "[C]"
        if frame.addon ~= ownAddon and not leadingC then
            foreign[#foreign + 1] = frame
        end
    end
    return foreign
end

---@param frame ErrorCatcherFrame
---@return string
function TraceUtils.Short(frame)
    if frame.line then
        return string.format("%s:%d '%s'", frame.file, frame.line, frame.fn)
    end
    return string.format("%s '%s'", frame.file, frame.fn)
end

---Add-ons with a frame in the trace, in the order met.
---@param frames ErrorCatcherFrame[]
---@return string[]
function TraceUtils.Addons(frames)
    local addons, seen = {}, {}
    for _, frame in ipairs(frames) do
        if frame.addon and not seen[frame.addon] then
            seen[frame.addon] = true
            addons[#addons + 1] = frame.addon
        end
    end
    return addons
end

---Game functions on the stack that run inside a ZO_PreHook / ZO_PostHook wrapper.
---@param frames ErrorCatcherFrame[]
---@return string[]
function TraceUtils.Wrapped(frames)
    local wrapped, seen = {}, {}
    for _, frame in ipairs(frames) do
        if frame.file == HOOK_FILE and not seen[frame.fn] then
            seen[frame.fn] = true
            wrapped[#wrapped + 1] = frame.fn
        end
    end
    return wrapped
end

---Frames as one line, nearest first; the frame at markIndex ends in "*".
---@param frames ErrorCatcherFrame[]
---@param max number
---@param markIndex number|nil
---@return string
function TraceUtils.Chain(frames, max, markIndex)
    local parts = {}
    for index = 1, math.min(#frames, max) do
        parts[#parts + 1] = TraceUtils.Short(frames[index]) .. (index == markIndex and "*" or "")
    end
    if #frames > max then
        parts[#parts + 1] = string.format("(+%d more)", #frames - max)
    end
    return table.concat(parts, " < ")
end

---@param names string[]
---@return string
function TraceUtils.ListOrNone(names)
    return #names > 0 and table.concat(names, ", ") or "none"
end

---Who was on the stack, as one line: add-ons, wrapped game functions, then the frames.
---@param frames ErrorCatcherFrame[]
---@param max number
---@return string
function TraceUtils.Summary(frames, max)
    if #frames == 0 then
        return "no stack reported"
    end
    return string.format("addons on stack: %s | wrapped by a hook: %s | frames: %s",
        TraceUtils.ListOrNone(TraceUtils.Addons(frames)),
        TraceUtils.ListOrNone(TraceUtils.Wrapped(frames)),
        TraceUtils.Chain(frames, max))
end

ErrorCatcher.TraceUtils = TraceUtils
