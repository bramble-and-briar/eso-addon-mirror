-- SlashCommandUtils.lua: parsing a slash command (pure)
local SlashCommandUtils = {}

---@param args any Raw command arguments
---@return string command Lower case; "" when none
function SlashCommandUtils.ParseCommand(args)
    return string.lower(string.match(type(args) == "string" and args or "", "^%s*(%S*)") or "")
end

ErrorCatcher.SlashCommandUtils = SlashCommandUtils
