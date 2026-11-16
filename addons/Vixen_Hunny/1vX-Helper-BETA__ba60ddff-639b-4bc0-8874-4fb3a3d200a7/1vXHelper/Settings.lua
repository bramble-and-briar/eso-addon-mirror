-- 1vX Helper - LibAddonMenu-2.0 settings panel
local addon = OneVXHelper
local S = {}
addon.Settings = S

local PANEL_ID = "OneVXHelper_Panel"

function addon.OpenSettings()
    if addon.lamPanel then LibAddonMenu2:OpenToPanel(addon.lamPanel) end
end

-- small builders --------------------------------------------------------------
local function Checkbox(group, key, name, tooltip, apply, disabled)
    return {
        type = "checkbox", name = name, tooltip = tooltip,
        getFunc = function() return addon.sv[group][key] end,
        setFunc = function(v) addon.sv[group][key] = v; if apply then apply() end end,
        default = addon.defaults[group][key], disabled = disabled,
    }
end

local function Slider(group, key, name, min, max, step, tooltip, apply, disabled, decimals)
    return {
        type = "slider", name = name, tooltip = tooltip, min = min, max = max, step = step,
        decimals = decimals, clampInput = true,
        getFunc = function() return addon.sv[group][key] end,
        setFunc = function(v) addon.sv[group][key] = v; if apply then apply() end end,
        default = addon.defaults[group][key], disabled = disabled,
    }
end

local function BuildSoundList()
    local candidates = {
        "DUEL_START", "GENERAL_ALERT_ERROR", "NEW_NOTIFICATION", "ABILITY_ULTIMATE_READY",
        "OBJECTIVE_DISCOVERED", "RAID_TRIAL_FAILED", "LOCKPICKING_BREAK", "QUEST_ABANDONED",
        "CHAMPION_POINTS_COMMITTED", "BATTLEGROUND_COUNTDOWN_FINISH", "TELVAR_GAINED",
    }
    local list = {}
    for _, n in ipairs(candidates) do
        if SOUNDS and SOUNDS[n] then list[#list + 1] = n end
    end
    if #list == 0 then list[1] = "NONE" end
    return list
end

function S.Init()
    local LAM = LibAddonMenu2
    if not LAM then
        error("LibAddonMenu-2.0 not found - install/enable it (Minion) and /reloadui")
    end

    local burstApply   = function() addon.Burst.Apply() end
    local pinsApply    = function() addon.Pins.Apply() end
    local trackApply   = function() addon.Tracker.Apply() end
    local extrasApply  = function() addon.Extras.Apply() end

    local burstOff = function() return not addon.sv.burst.enabled end
    local pinsOff  = function() return not addon.sv.pins.enabled end
    local trackOff = function() return not addon.sv.tracker.enabled end

    local sounds = BuildSoundList()
    local soundOk = false
    for _, n in ipairs(sounds) do if n == addon.sv.burst.sound then soundOk = true end end
    if not soundOk then addon.sv.burst.sound = sounds[1] end

    local panelData = {
        type = "panel",
        name = "1vX Helper",
        displayName = addon.displayName,
        author = "Vixen Hunny",
        version = addon.version,
        slashCommand = "/1vxsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local options = {
        { type = "description", text = "Gamepad: main menu > 1vX Map Pins. Slash: /1vx. Keybinds are under Controls > Keybindings > 1vX Helper." },

        -----------------------------------------------------------------------
        { type = "submenu", name = "General / UI", controls = {
            {
                type = "checkbox", name = "Unlock UI (drag elements)",
                tooltip = "Shows every enabled element with a red frame, on top of this menu too, so you can drag it right away. Not saved - resets on reload.",
                getFunc = function() return addon.unlocked end,
                setFunc = function(v) addon.SetUnlocked(v) end,
                default = false,
            },
            { type = "button", name = "Reset Positions", func = function() addon.UI.ResetPositions() end, width = "half" },
        }},

        -----------------------------------------------------------------------
        { type = "submenu", name = "|cFF3333Burst Monitor|r", controls = {
            Checkbox("burst", "enabled", "Enable Burst Monitor", "Warns you to kite when incoming damage in the burst window reaches your threshold.", burstApply),
            {
                type = "dropdown", name = "Threshold Type",
                tooltip = "Flat damage number, or a percentage of your max health.",
                choices = { "Flat damage", "% of max health" }, choicesValues = { "absolute", "percent" },
                getFunc = function() return addon.sv.burst.mode end,
                setFunc = function(v) addon.sv.burst.mode = v; burstApply() end,
                default = addon.defaults.burst.mode, disabled = burstOff,
            },
            Slider("burst", "absThreshold", "Burst Threshold (damage)", 1000, 80000, 500,
                "Damage taken within the burst window that triggers the KITE alert.", burstApply,
                function() return burstOff() or addon.sv.burst.mode ~= "absolute" end),
            Slider("burst", "pctThreshold", "Burst Threshold (% max health)", 5, 100, 1,
                "Percent of your max health taken within the burst window that triggers the KITE alert.", burstApply,
                function() return burstOff() or addon.sv.burst.mode ~= "percent" end),
            Slider("burst", "window", "Burst Window (seconds)", 0.5, 3, 0.1, "How far back incoming damage is summed. Default 1s.", burstApply, burstOff, 1),
            Slider("burst", "alertDuration", "Kite Alert Duration (seconds)", 0.5, 6, 0.1, "How long the flashing KITE text stays up. Default 2s.", burstApply, burstOff, 1),
            Slider("burst", "graceDuration", "Grace Period (seconds)", 0, 6, 0.1, "After the alert ends, it can't retrigger for this long. Default 2s.", burstApply, burstOff, 1),
            Checkbox("burst", "extendOnRepeat", "Extend alert on repeat burst", "If the threshold is hit again while the alert is up, restart the alert timer.", burstApply, burstOff),
            { type = "header", name = "What counts as burst" },
            Checkbox("burst", "countDots", "Count DoT ticks", nil, burstApply, burstOff),
            Checkbox("burst", "countBlocked", "Count blocked damage", "Damage you took while blocking.", burstApply, burstOff),
            Checkbox("burst", "countShielded", "Count shielded damage", "Damage absorbed by your shields - you're still being bursted.", burstApply, burstOff),
            Checkbox("burst", "pvpOnly", "Only in PvP zones", "Only track in Cyrodiil, Imperial City and Battlegrounds.", burstApply, burstOff),
            { type = "header", name = "Display" },
            {
                type = "editbox", name = "Alert Text",
                getFunc = function() return addon.sv.burst.alertText end,
                setFunc = function(v) addon.sv.burst.alertText = (v ~= "" and v) or addon.defaults.burst.alertText; burstApply() end,
                default = addon.defaults.burst.alertText, disabled = burstOff, isMultiline = false,
            },
            Slider("burst", "alertSize", "Alert Text Size", 24, 96, 2, nil, burstApply, burstOff),
            Checkbox("burst", "showGraceText", "Show grace countdown", "Shows an amber GRACE countdown after the kite alert.", burstApply, burstOff),
            Checkbox("burst", "showMeter", "Show live burst meter", "Small bar with current burst vs threshold and SAFE / KITE / GRACE state.", burstApply, burstOff),
            Checkbox("burst", "playSound", "Play sound on alert", nil, burstApply, burstOff),
            {
                type = "dropdown", name = "Alert Sound", choices = sounds,
                getFunc = function() return addon.sv.burst.sound end,
                setFunc = function(v) addon.sv.burst.sound = v; if SOUNDS[v] then PlaySound(SOUNDS[v]) end end,
                default = sounds[1],
                disabled = function() return burstOff() or not addon.sv.burst.playSound end,
            },
            { type = "button", name = "Test Alert", func = function() addon.Burst.Test() end, disabled = burstOff },
        }},

        -----------------------------------------------------------------------
        { type = "submenu", name = "|c33FF4DMap Pins|r", controls = {
            { type = "description", text = "Drop pins at your current position with keybinds, the gamepad screen or /1vx kite|safe|choke <note>. Pins are saved per map, account-wide." },
            Checkbox("pins", "enabled", "Show 1vX pins on map", "Master toggle for all 1vX map pins.", pinsApply),
            Checkbox("pins", "kite",  "|c33FF4DKite Spots|r",   "Pillars, rocks, LoS spots, tower loops.", pinsApply, pinsOff),
            Checkbox("pins", "safe",  "|c4DB8FFSafe Places|r",  "Spots to reset / heal / break combat.", pinsApply, pinsOff),
            Checkbox("pins", "choke", "|cFF8C1AChoke Points|r", "Bridges, doorways, narrow paths where groups funnel.", pinsApply, pinsOff),
            Slider("pins", "size", "Pin Size", 16, 48, 1, nil, pinsApply, pinsOff),
            { type = "button", name = "List pins (current map)", func = function() addon.Pins.ListCurrentMap() end, width = "half" },
            { type = "button", name = "Clear current map", isDangerous = true, warning = "Deletes every 1vX pin on the map you're on.",
              func = function() addon.Pins.ClearCurrentMap() end, width = "half" },
            { type = "button", name = "Clear ALL pins", isDangerous = true, warning = "Deletes every 1vX pin on every map. Can't be undone.",
              func = function() addon.Pins.ClearAll() end, width = "half" },
        }},

        -----------------------------------------------------------------------
        { type = "submenu", name = "|c4DB8FFSpot Tracker|r", controls = {
            Checkbox("tracker", "enabled", "Enable Spot Tracker", "Shows distance and clock direction to your nearest pins.", trackApply),
            Checkbox("tracker", "kite",  "Track Kite Spots",   nil, trackApply, trackOff),
            Checkbox("tracker", "safe",  "Track Safe Places",  nil, trackApply, trackOff),
            Checkbox("tracker", "choke", "Track Choke Points", nil, trackApply, trackOff),
            Slider("tracker", "maxRange", "Max Range (m)", 50, 2000, 25, "Pins further than this aren't listed.", trackApply, trackOff),
            Checkbox("tracker", "chokeWarn", "Choke point proximity warning", "Shows an orange warning when you're close to a choke point.", trackApply, trackOff),
            Slider("tracker", "chokeWarnRange", "Choke warning range (m)", 5, 100, 1, nil, trackApply,
                function() return trackOff() or not addon.sv.tracker.chokeWarn end),
            Checkbox("tracker", "flipDirection", "Flip direction", "Turn on if the o'clock directions look mirrored left/right.", trackApply, trackOff),
        }},

        -----------------------------------------------------------------------
        { type = "submenu", name = "|cB088FFGamepad|r", controls = {
            { type = "description", text = "In gamepad mode, open the main menu: '1vX Map Pins' sits right above Inventory with Map Choke Here, Map Safe Here and Kite Here. Map pins and their tooltips show on the gamepad world map." },
            Checkbox("gamepad", "menuEntry", "Gamepad menu entry (above Inventory)", "Adds the 1vX Map Pins screen to the gamepad main menu.",
                function() addon.Gamepad.Apply() end),
            { type = "button", name = "Open Gamepad Pin Screen", func = function() addon.Gamepad.Show() end,
              disabled = function() return not IsInGamepadPreferredMode() end },
        }},

        -----------------------------------------------------------------------
        { type = "submenu", name = "|c999999Performance (CPU)|r", controls = {
            { type = "description", text = "Lower = smoother timers, higher = less CPU. The burst monitor only runs its fast timer while you're taking damage or an alert is up; outside fights it drops to a 1s idle refresh." },
            Slider("burst", "updateRate", "Burst timer rate (ms)", 50, 500, 25,
                "How often the burst window, KITE/GRACE countdown and meter update while active. Damage is still counted the instant it lands. Default 100.",
                burstApply, burstOff),
            Slider("tracker", "updateRate", "Tracker update rate (ms)", 100, 2000, 50,
                "How often distances / directions refresh. Default 250.", trackApply, trackOff),
            Checkbox("tracker", "skipWhenStill", "Tracker: skip while standing still",
                "Don't recalculate when you haven't moved or turned your camera.", trackApply, trackOff),
            {
                type = "button", name = "Low CPU preset",
                tooltip = "Burst 200ms, tracker 750ms, skip while still on.",
                func = function()
                    addon.sv.burst.updateRate = 200
                    addon.sv.tracker.updateRate = 750
                    addon.sv.tracker.skipWhenStill = true
                    burstApply(); trackApply()
                end, width = "half",
            },
            {
                type = "button", name = "Default preset",
                func = function()
                    addon.sv.burst.updateRate = addon.defaults.burst.updateRate
                    addon.sv.tracker.updateRate = addon.defaults.tracker.updateRate
                    addon.sv.tracker.skipWhenStill = addon.defaults.tracker.skipWhenStill
                    burstApply(); trackApply()
                end, width = "half",
            },
        }},

        -----------------------------------------------------------------------
        { type = "submenu", name = "|cFFC020Extra 1vX Tools|r", controls = {
            Checkbox("lowHealth", "enabled", "Low Health Warning", "Big warning text when your health drops below the threshold.", extrasApply),
            Slider("lowHealth", "threshold", "Low Health Threshold (%)", 10, 80, 1, nil, extrasApply,
                function() return not addon.sv.lowHealth.enabled end),
            Checkbox("combatTimer", "enabled", "Combat Timer", "Shows how long you've been in the current fight.", extrasApply),
        }},
    }

    addon.lamPanel = LAM:RegisterAddonPanel(PANEL_ID, panelData)
    LAM:RegisterOptionControls(PANEL_ID, options)
end
