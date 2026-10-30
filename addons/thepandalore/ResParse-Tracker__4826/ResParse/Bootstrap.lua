ResParse = ResParse or {}
local RP = ResParse

RP.bootstrapLoaded = true
RP.bootstrapLog = RP.bootstrapLog or {}

local function BootPrint(message)
    -- Bootstrap diagnostics are retained for inspection but never emitted
    -- automatically. Chat output occurs only through explicitly invoked
    -- diagnostic/scoresheet slash commands in ResParse.lua.
    RP.bootstrapLog[#RP.bootstrapLog + 1] = tostring(message)
end

RP.BootPrint = BootPrint

local function Dispatch(text)
    if type(RP.SlashCommand) == "function" then
        local ok, err = pcall(function()
            RP:SlashCommand(text or "")
        end)
        if not ok then
            BootPrint("slash command error: " .. tostring(err))
        end
    else
        BootPrint("bootstrap is alive, but ResParse.lua did not load; main addon unavailable")
    end
end

local function PrintScoresheet()
    if type(RP.PrintScoresheet) == "function" then
        local ok, err = pcall(function()
            RP:PrintScoresheet()
        end)
        if not ok then
            BootPrint("scoresheet print error: " .. tostring(err))
        end
    else
        BootPrint("bootstrap is alive, but ResParse.lua did not load; scoresheet unavailable")
    end
end

SLASH_COMMANDS["/resparse"] = Dispatch
SLASH_COMMANDS["/resparsers"] = PrintScoresheet
