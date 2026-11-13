local AAQ = AutoAcceptQ

local function Toggle(key, name, tooltip, recheck)
    return {
        type = "checkbox",
        name = name,
        tooltip = tooltip,
        getFunc = function() return AAQ.sv[key] end,
        setFunc = function(value)
            AAQ.sv[key] = value
            if value and recheck then AAQ.CheckPending() end
        end,
        default = AAQ.defaults[key],
        disabled = key ~= "enabled" and function() return not AAQ.sv.enabled end or nil,
    }
end

function AAQ.BuildSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    LAM:RegisterAddonPanel("AutoAcceptQPanel", {
        type = "panel",
        name = AAQ.displayName,
        displayName = "|c66CCFFAutoAccept|rQ",
        author = "Vixen Hunny",
        version = AAQ.version,
        slashCommand = "/aaqsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LAM:RegisterOptionControls("AutoAcceptQPanel", {
        Toggle("enabled", "Enable AutoAcceptQ", "Master switch. Also toggled with /aaq (or /aaq on, /aaq off).", true),

        { type = "header", name = "Auto Accept" },
        Toggle("dungeons", "Dungeon Queue", "Accept group finder ready checks for normal and veteran dungeons.", true),
        Toggle("battlegrounds", "Battlegrounds", "Accept ready checks for all battleground queues.", true),
        Toggle("cyrodiil", "Cyrodiil", "Automatically enter the campaign when your Cyrodiil queue pops.", true),
        Toggle("imperialCity", "Imperial City", "Automatically enter the campaign when your Imperial City queue pops.", true),
        Toggle("jerallPass", "Jerall Pass", "Automatically enter the campaign when your Jerall Pass queue pops.", true),
        Toggle("tribute", "Tales of Tribute", "Accept Tales of Tribute matchmaking ready checks.", true),
        Toggle("other", "Other Activities", "Accept ready checks for any other group finder activity not covered above.", true),

        { type = "header", name = "Behaviour" },
        {
            type = "slider",
            name = "Accept Delay (seconds)",
            tooltip = "How long to wait before accepting. You get an on-screen warning when the queue pops. 0 = instant. Shortened automatically if the pop would expire first.",
            min = 0, max = 60, step = 1,
            getFunc = function() return AAQ.sv.delay end,
            setFunc = function(value) AAQ.sv.delay = value end,
            default = AAQ.defaults.delay,
            disabled = function() return not AAQ.sv.enabled end,
        },
        Toggle("announce", "On-Screen Warning", "Show a center-screen message when a queue pops, saying how many seconds until it is auto-accepted."),
        Toggle("chatMessages", "Chat Messages", "Print a chat message when something is auto-accepted."),
    })
end
