local PBE = PacketByteExporter

local function Trim(value)
    return (value or ""):match("^%s*(.-)%s*$")
end

local function Help()
    PBE.Print("Commands:")
    PBE.Print("/pbe quick - smaller everyday snapshot (gear, bars, stats, CP)")
    PBE.Print("/pbe skills - purchased skills, passives, morphs, and scribing")
    PBE.Print("/pbe crafting - complete current trait-research status")
    PBE.Print("/pbe quests - current quest journal")
    PBE.Print("/pbe capture | build - full build, points, crafting, quests")
    PBE.Print("/pbe all - add backpack, unlocked collectibles, all achievements")
    PBE.Print("/pbe endpoint IP - set your receiver (example: /pbe endpoint 192.168.1.25)")
    PBE.Print("/pbe next | retry | rewind | status | cancel")
    PBE.Print("/pbe account on|off - include or omit account display name (default off)")
end

local function SetEndpoint(value)
    local endpoint = Trim(value)
    if endpoint == "off" or endpoint == "clear" then
        PBE.GetSettings().endpoint = ""
        PBE.Print("Receiver cleared.")
        return
    end
    local normalized, errorMessage = PBE.NormalizeEndpoint(endpoint)
    if not normalized then
        PBE.Print(errorMessage)
        return
    end
    PBE.GetSettings().endpoint = normalized
    PBE.Print("Receiver saved: " .. normalized)
end

local function SetAccountPrivacy(value)
    value = Trim(value):lower()
    if value ~= "on" and value ~= "off" then
        PBE.Print("Use /pbe account on or /pbe account off")
        return
    end
    PBE.GetSettings().includeAccountName = value == "on"
    PBE.Print("Account display name export is " .. value .. ".")
end

local function HandleCommand(text)
    local command, rest = Trim(text):match("^(%S*)%s*(.-)$")
    command = (command or ""):lower()
    if command == "quick" then
        PBE.Transport.Capture("quick")
    elseif command == "skills" or command == "crafting" or command == "quests" then
        PBE.Transport.Capture(command)
    elseif command == "capture" or command == "build" then
        PBE.Transport.Capture("build")
    elseif command == "all" then
        PBE.Print("Extended capture may take time; use /pbe status to check progress.")
        PBE.Transport.Capture("all")
    elseif command == "endpoint" then
        SetEndpoint(rest)
    elseif command == "next" or command == "submit" then
        PBE.Transport.SubmitNext()
    elseif command == "retry" then
        PBE.Transport.RetryLast()
    elseif command == "rewind" then
        PBE.Transport.Rewind()
    elseif command == "status" then
        PBE.Transport.GetStatus()
    elseif command == "cancel" then
        PBE.Transport.CancelCapture()
    elseif command == "account" then
        SetAccountPrivacy(rest)
    else
        Help()
    end
end

SLASH_COMMANDS["/pbe"] = HandleCommand

function PacketByteExporter_CaptureQuick()
    PBE.Transport.Capture("quick")
end

function PacketByteExporter_CaptureBuild()
    PBE.Transport.Capture("build")
end

function PacketByteExporter_CaptureAll()
    PBE.Print("Extended capture may take time; use /pbe status to check progress.")
    PBE.Transport.Capture("all")
end

function PacketByteExporter_SubmitNext()
    PBE.Transport.SubmitNext()
end

function PacketByteExporter_RetryLast()
    PBE.Transport.RetryLast()
end
