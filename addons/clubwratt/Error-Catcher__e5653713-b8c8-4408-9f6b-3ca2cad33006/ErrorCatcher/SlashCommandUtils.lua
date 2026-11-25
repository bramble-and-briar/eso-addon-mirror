-- SlashCommandUtils.lua: parsing a slash command (pure)
local SlashCommandUtils = {}

---@param args any Raw command arguments
---@return string command Lower case; "" when none
---@return string argument The word after it, lower case; "" when none
function SlashCommandUtils.ParseCommand(args)
    local command, argument = string.match(type(args) == "string" and args or "", "^%s*(%S*)%s*(%S*)")
    return string.lower(command or ""), string.lower(argument or "")
end

ErrorCatcher.SlashCommandUtils = SlashCommandUtils
