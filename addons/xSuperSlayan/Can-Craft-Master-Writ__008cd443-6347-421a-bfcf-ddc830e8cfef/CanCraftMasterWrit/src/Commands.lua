-- Chat: the "Loaded!" message, the /ccmw command and the /ru shortcut.
--   /ccmw debug        turn debug messages on or off
--   /ccmw scan         check every master writ in the backpack
--   /ccmw link <link>  check one writ from a chat link
--   /ccmw new          show the What's New pop-up
--   /ru                reload the UI

local addon = CanCraftMasterWrit
local Result = addon.Result
local Evaluator = addon.Evaluator

local Commands = {}
addon.Commands = Commands

local function Print(text)
    CHAT_ROUTER:AddSystemMessage(text)
end

---------------------------------------------------------------------------------------------------
-- Loaded message
---------------------------------------------------------------------------------------------------

function Commands.PrintLoadedMessage()
    Print(addon.Util.FallGradient(zo_strformat(SI_CCMW_LOADED, addon.name, addon.version)))
end

---------------------------------------------------------------------------------------------------
-- /ccmw
---------------------------------------------------------------------------------------------------

local STATE_PREFIX = {
    [Result.STATE_PASS] = "|c00FF00+|r ",
    [Result.STATE_FAIL] = "|cFF4040x|r ",
    [Result.STATE_UNKNOWN] = "|cAAAAAA?|r ",
    [Result.STATE_INFO] = "  ",
}

local function PrintResult(itemLink, result, onlyProblems)
    Print(string.format("%s: %s", itemLink, addon.Tooltip.GetStatusText(result)))
    for _, check in ipairs(result.checks) do
        if not onlyProblems or check.state == Result.STATE_FAIL or check.state == Result.STATE_UNKNOWN then
            Print(STATE_PREFIX[check.state] .. check.text)
            for _, detail in ipairs(check.details) do
                Print("      " .. detail.text)
            end
        end
    end
end

local function Scan()
    local found = false
    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local itemLink = GetItemLink(BAG_BACKPACK, slotIndex)
        local result = Evaluator.Evaluate(itemLink)
        if result then
            found = true
            PrintResult(itemLink, result, true)
        end
    end
    if not found then
        Print(GetString(SI_CCMW_COMMAND_SCAN_NONE))
    end
end

local function OnSlashCommand(arguments)
    arguments = arguments or ""
    local command = zo_strlower(zo_strsplit(" ", arguments) or "")
    if command == "debug" then
        addon.debug = not addon.debug
        Print(zo_strformat(SI_CCMW_COMMAND_DEBUG, GetString(addon.debug and SI_CCMW_COMMAND_ON or SI_CCMW_COMMAND_OFF)))
    elseif command == "scan" then
        Evaluator.ClearCache()
        Scan()
    elseif command == "link" then
        local itemLink = arguments:match("|H.-|h.-|h")
        local result = itemLink and Evaluator.Evaluate(itemLink)
        if result then
            PrintResult(itemLink, result, false)
        end
    elseif command == "new" then
        addon.Popup.ShowWhatsNew()
    else
        Print(GetString(SI_CCMW_COMMAND_HELP))
    end
end

function Commands.Initialize()
    SLASH_COMMANDS["/ccmw"] = OnSlashCommand
    -- /ru is a common shortcut. Another add-on that already registered it keeps it, so nothing changes for its users.
    if not SLASH_COMMANDS["/ru"] then
        SLASH_COMMANDS["/ru"] = function()
            ReloadUI("ingame")
        end
    end
end
