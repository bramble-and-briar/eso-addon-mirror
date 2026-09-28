local SlashCommandUtils = {}

---Split command arguments into command and remaining args
---@param args string|nil Raw command arguments
---@return string command The parsed command (lowercase)
---@return string remaining The remaining arguments after the command
function SlashCommandUtils.ParseCommand(args)
    if not args or args == "" then
        return "", ""
    end

    local command = string.lower(string.match(args, "^%s*(%S+)")) or ""
    local remaining = string.match(args, "^%s*%S+%s+(.+)$") or ""

    return command, remaining
end

DevSandbox3.SlashCommandUtils = SlashCommandUtils
