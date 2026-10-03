-- SnipersFriendSlashUtils.lua: Pure helpers for slash commands and logging

local SlashUtils = {}

---Split command arguments into command and remaining args
---@param args string|nil Raw command arguments
---@return string command The parsed command (lowercase)
---@return string remaining The remaining arguments after the command
function SlashUtils.ParseCommand(args)
    if not args or args == "" then
        return "", ""
    end
    local command = string.lower(string.match(args, "^%s*(%S+)") or "")
    local remaining = string.match(args, "^%s*%S+%s+(.+)$") or ""
    return command, remaining
end

---@param s string
---@return string[]
function SlashUtils.SplitWords(s)
    local out = {}
    for w in string.gmatch(s or "", "%S+") do
        out[#out + 1] = w
    end
    return out
end

---@param fmt string
---@param ... any
function SlashUtils.Log(fmt, ...)
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    local line = string.format("[%s] %s", SnipersFriend.displayName, msg)
    local CL = _G["LibConsoleLogger"]
    if CL and CL.Log then
        CL:Log(line)
    else
        d(line)
    end
end

---@param fmt string
---@param ... any
function SlashUtils.Debug(fmt, ...)
    local state = SnipersFriend.state
    if state and state.savedVars and state.savedVars.debug then
        SlashUtils.Log(fmt, ...)
    end
end

SnipersFriend.SlashUtils = SlashUtils
