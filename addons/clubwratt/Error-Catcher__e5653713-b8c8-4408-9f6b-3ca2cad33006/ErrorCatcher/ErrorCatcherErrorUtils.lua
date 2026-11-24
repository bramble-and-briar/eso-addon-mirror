-- ErrorCatcherErrorUtils.lua: one Lua error as one line (pure)
--
-- The game words a refused private call as "... became untrusted N stack frame(s) from the top". N counts down
-- from the function that raised (frame 0): the frame it lands on is the untrusted function, and where that
-- function is created names the fault.
local ErrorUtils = {}

local TraceUtils = ErrorCatcher.TraceUtils

local MAX_CHAIN_FRAMES = 14
local MAX_MARKED_CHAIN_FRAMES = 24
local MAX_MESSAGE_CHARS = 160

-- Files whose functions are built once and shared, so one untrusted build spoils every later use.
local SHARED_NOTES = {
    ["ZO_GenericDialog_Gamepad.lua"] = " (the button object every gamepad dialog shares)",
}

---@param text string
---@return number|nil depth Frames below the raising function, when the error is a refused private call
function ErrorUtils.UntrustedDepth(text)
    return tonumber(string.match(text, "became untrusted (%d+) stack frame"))
end

---One line for an error text that carries a stack trace; nil for text without one (the game also sends
---plain notices, such as the low memory warning, as errors).
---@param text any
---@return string|nil
function ErrorUtils.Describe(text)
    if type(text) ~= "string" then
        return nil
    end
    local frames = TraceUtils.Frames(text)
    if #frames == 0 then
        return nil
    end
    local addons = TraceUtils.ListOrNone(TraceUtils.Addons(frames))
    local depth = ErrorUtils.UntrustedDepth(text)
    if depth then
        local landing = frames[depth + 1]
        local landingText = landing
            and (TraceUtils.Short(landing) .. (SHARED_NOTES[landing.file] or ""))
            or string.format("below the %d frames reported", #frames)
        return string.format("insecure call '%s' at %s | untrusted frame %d: %s | addons in trace: %s | frames: %s",
            string.match(text, "private function '([^']+)'") or "?",
            TraceUtils.Short(frames[1]),
            depth,
            landingText,
            addons,
            TraceUtils.Chain(frames, math.min(math.max(MAX_CHAIN_FRAMES, depth + 1), MAX_MARKED_CHAIN_FRAMES), depth + 1))
    end
    local message = TraceUtils.Trim(string.match(text, "^[^\r\n]*") or "")
    return string.format("error: %s | addons in trace: %s | frames: %s",
        TraceUtils.Clip(message, MAX_MESSAGE_CHARS), addons, TraceUtils.Chain(frames, MAX_CHAIN_FRAMES))
end

ErrorCatcher.ErrorUtils = ErrorUtils
