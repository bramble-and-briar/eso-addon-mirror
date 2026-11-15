NQOL = NQOL or {}
NQOL.Features = NQOL.Features or {}

local SlashCommands = {}

local FEATURE_NAME = NQOL.L("features.slash_commands.feature_name")
local HELP_COMMAND = "/nqol"
local COMMAND_PREFIX = "/nqol:"
local GPS_LOG_COMMAND = "gpslog"
local WRIT_STATUS_COMMAND = "writs-status"
local LOADOUT_COMMAND = "loadout"
local gpsLogDescription = NQOL.L("features.slash_commands.gps_log")
local writStatusDescription = NQOL.L("features.slash_commands.writ_status")
local loadoutDescription = NQOL.L("features.slash_commands.loadout")

local COMMANDS = {
    { "remount", NQOL.L("features.slash_commands.remain_mounted"), "Mounts", "GetRemainMounted", "SetRemainMounted" },
    { "autoeye", NQOL.L("features.slash_commands.auto_eye"), "Antiquities", "GetAutoEye", "SetAutoEye" },
    { "charge", NQOL.L("features.slash_commands.auto_charge"), "Gear", "GetAutoCharge", "SetAutoCharge" },
    { "repair", NQOL.L("features.slash_commands.auto_repair"), "Gear", "GetAutoRepair", "SetAutoRepair" },
    { "bind", NQOL.L("features.slash_commands.auto_bind"), "Gear", "GetAutoBound", "SetAutoBound" },
    { "autofood", NQOL.L("features.slash_commands.auto_food"), "Provisioning", "GetAutoFood", "SetAutoFood" },
    { "reel", NQOL.L("features.slash_commands.reel"), "Fishing", "GetReelNotification", "SetReelNotification" },
    { "bait", NQOL.L("features.slash_commands.bait"), "Fishing", "GetAutoSelectBait", "SetAutoSelectBait" },
    { "chat", NQOL.L("features.slash_commands.chat"), "Chat", "GetKeepHudOpen", "SetKeepHudOpen" },
    { "reminders", NQOL.L("features.slash_commands.reminders"), "ChatReminders", "GetShowInGame", "SetShowInGame" },
    { "friends", NQOL.L("features.slash_commands.friends"), "Friends", "GetEnabled", "SetEnabled" },
    { "ticker", NQOL.L("features.slash_commands.ticker"), "Ticker", "GetEnabled", "SetEnabled" },
    { "xp", NQOL.L("features.slash_commands.xp"), "Progress", "GetXpEnabled", "SetXpEnabled" },
    { "gold", NQOL.L("features.slash_commands.gold"), "ProgressGold", "GetGoldEnabled", "SetGoldEnabled" },
    { "buffs", NQOL.L("features.slash_commands.buffs"), "BuffsDebuffs", "GetEnabled", "SetEnabled" },
    { "ultfront", NQOL.L("features.slash_commands.ult_front"), "UltimateCountdown", "GetEnabled", "SetEnabled", "frontBar" },
    { "ultback", NQOL.L("features.slash_commands.ult_back"), "UltimateCountdown", "GetEnabled", "SetEnabled", "backBar" },
    { "gps", NQOL.L("features.slash_commands.gps"), "GPS", "GetEnabled", "SetEnabled", nil, "IsAvailable" }
}
NQOL.Lexicon.RegisterRefreshCallback(function()
    FEATURE_NAME = NQOL.L("features.slash_commands.feature_name")
    gpsLogDescription = NQOL.L("features.slash_commands.gps_log")
    writStatusDescription = NQOL.L("features.slash_commands.writ_status")
    loadoutDescription = NQOL.L("features.slash_commands.loadout")
    local keys = {
        "features.slash_commands.remain_mounted", "features.slash_commands.auto_eye",
        "features.slash_commands.auto_charge", "features.slash_commands.auto_repair",
        "features.slash_commands.auto_bind", "features.slash_commands.auto_food",
        "features.slash_commands.reel", "features.slash_commands.bait", "features.slash_commands.chat",
        "features.slash_commands.reminders", "features.slash_commands.friends", "features.slash_commands.ticker",
        "features.slash_commands.xp", "features.slash_commands.gold", "features.slash_commands.buffs",
        "features.slash_commands.ult_front", "features.slash_commands.ult_back", "features.slash_commands.gps",
    }
    for index, key in ipairs(keys) do COMMANDS[index][2] = NQOL.L(key) end
end)

local function Chat(message)
    NQOL.Chat.Message(message, FEATURE_NAME)
end

local function FormatState(value)
    if value == true then
        return NQOL.L("features.slash_commands.on")
    end

    return NQOL.L("features.slash_commands.off")
end

local function ResolveFeature(entry)
    return NQOL.Features and NQOL.Features[entry[3]]
end

local function CallGetter(feature, entry)
    if entry[6] ~= nil then
        return feature[entry[4]](entry[6])
    end

    return feature[entry[4]]()
end

local function CallSetter(feature, entry, value)
    if entry[6] ~= nil then
        feature[entry[5]](entry[6], value)
        return
    end

    feature[entry[5]](value)
end

local function MakeHandler(entry)
    return function(args)
        local feature = ResolveFeature(entry)
        if not feature or type(feature[entry[4]]) ~= "function" or type(feature[entry[5]]) ~= "function" then
            Chat(NQOL.L("features.slash_commands.unavailable", entry[2]))
            return
        end
        if entry[7] ~= nil and (type(feature[entry[7]]) ~= "function" or feature[entry[7]]() ~= true) then
            Chat(NQOL.L("features.slash_commands.unavailable", entry[2]))
            return
        end

        if tostring(args or ""):match("%S") then
            Chat(NQOL.L("features.slash_commands.current", COMMAND_PREFIX, entry[1], FormatState(CallGetter(feature, entry))))
            return
        end

        local value = CallGetter(feature, entry) ~= true
        CallSetter(feature, entry, value)
        Chat(NQOL.L("features.slash_commands.changed", entry[2], FormatState(CallGetter(feature, entry))))
    end
end

local function ShowHelp()
    Chat(NQOL.L("features.slash_commands.help", COMMAND_PREFIX))

    for _, entry in ipairs(COMMANDS) do
        Chat(NQOL.L("features.slash_commands.help_entry", COMMAND_PREFIX, entry[1], entry[2]))
    end

    Chat(NQOL.L("features.slash_commands.help_entry", COMMAND_PREFIX, GPS_LOG_COMMAND, gpsLogDescription))
    Chat(NQOL.L("features.slash_commands.help_entry", COMMAND_PREFIX, WRIT_STATUS_COMMAND, writStatusDescription))
    Chat(NQOL.L("features.slash_commands.help_entry", COMMAND_PREFIX, LOADOUT_COMMAND, loadoutDescription))
end

local function LogGPSCoordinates()
    local gps = NQOL.Features and NQOL.Features.GPS
    if not gps or type(gps.IsAvailable) ~= "function" or gps.IsAvailable() ~= true then
        Chat(NQOL.L("features.slash_commands.unavailable", NQOL.L("features.slash_commands.gps")))
        return
    end
    if type(gps.GetCoordinateValues) ~= "function" then
        Chat(NQOL.L("features.slash_commands.unavailable", gpsLogDescription))
        return
    end

    local xText, yText, zText = gps.GetCoordinateValues()
    if not xText then
        NQOL.Chat.Message(NQOL.L("features.gps.location_unavailable"), gps.GetName())
        return
    end

    NQOL.Chat.Message(NQOL.L("features.gps.plain_text_horizontal_format", xText, yText, zText), gps.GetName())
end

local function ShowWritStatus()
    local writStatus = NQOL.Features and NQOL.Features.WritStatus
    if not writStatus or type(writStatus.Show) ~= "function" then
        Chat(NQOL.L("features.slash_commands.unavailable", writStatusDescription))
        return
    end

    local shown = writStatus.Show()
    if shown ~= true then
        Chat(NQOL.L("features.slash_commands.unavailable", writStatusDescription))
    end
end

local function Register(command, handler)
    if type(SLASH_COMMANDS) ~= "table" then
        return
    end

    SLASH_COMMANDS[command] = handler
end

function SlashCommands.Initialize()
    Register(HELP_COMMAND, ShowHelp)

    for _, entry in ipairs(COMMANDS) do
        Register(COMMAND_PREFIX .. entry[1], MakeHandler(entry))
    end

    Register(COMMAND_PREFIX .. GPS_LOG_COMMAND, LogGPSCoordinates)
    Register(COMMAND_PREFIX .. WRIT_STATUS_COMMAND, ShowWritStatus)
    Register(COMMAND_PREFIX .. LOADOUT_COMMAND, function(args)
        NQOL.Features.AddonLoadouts.Load(args)
    end)
end

NQOL.Features.SlashCommands = SlashCommands
