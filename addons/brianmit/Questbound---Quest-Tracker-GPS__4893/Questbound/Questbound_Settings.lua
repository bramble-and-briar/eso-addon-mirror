-- Questbound_Settings.lua : settings panel (LibAddonMenu-2.0, optional).

local W = Questbound
local L = W.L

local PANEL = "QuestboundSettings"

function W.OpenSettings()
    if W.settingsPanel then
        LibAddonMenu2:OpenToPanel(W.settingsPanel)
    else
        W.Print(L("NO_LAM"))
    end
end

local function Changed()
    W.callbacks:FireCallbacks("SettingsChanged")
end

local function Check(section, key, textKey, tipKey, disabled)
    return {
        type = "checkbox",
        name = L(textKey),
        tooltip = tipKey and L(tipKey) or nil,
        getFunc = function() return (section and W.sv[section] or W.sv)[key] end,
        setFunc = function(v)
            (section and W.sv[section] or W.sv)[key] = v
            Changed()
        end,
        disabled = disabled,
    }
end

-- Dropdown over a setting; values and their text keys side by side.
local function Choice(section, key, textKey, tipKey, values, textKeys, disabled)
    local choices = {}
    for i, k in ipairs(textKeys) do choices[i] = L(k) end
    return {
        type = "dropdown",
        name = L(textKey),
        tooltip = tipKey and L(tipKey) or nil,
        choices = choices,
        choicesValues = values,
        getFunc = function() return (section and W.sv[section] or W.sv)[key] end,
        setFunc = function(v)
            (section and W.sv[section] or W.sv)[key] = v
            Changed()
        end,
        disabled = disabled,
    }
end

local function Slider(section, key, textKey, min, max, step, decimals, disabled)
    return {
        type = "slider",
        name = L(textKey),
        min = min, max = max, step = step, decimals = decimals,
        getFunc = function() return W.sv[section][key] end,
        setFunc = function(v)
            W.sv[section][key] = v
            Changed()
        end,
        disabled = disabled,
    }
end

local function Color(get, set, textKey, tipKey, disabled)
    return {
        type = "colorpicker",
        name = L(textKey),
        tooltip = tipKey and L(tipKey) or nil,
        getFunc = function() local c = get() return c.r, c.g, c.b end,
        setFunc = function(r, g, b)
            set({ r = r, g = g, b = b })
            Changed()
        end,
        disabled = disabled,
    }
end

function W.InitSettings()
    local lam = LibAddonMenu2
    if not lam then return end
    local sv = W.sv
    local noTracker = function() return not sv.tracker.shown end
    local noArrow = function() return not sv.arrow.shown end
    local noBigArrow = function() return not sv.arrow.shown or sv.arrow.style ~= "classic" end
    -- compact badge animations (off with the big arrow or with Animations: Off)
    local function FxCheck(key, textKey)
        return {
            type = "checkbox",
            name = L(textKey),
            tooltip = L(textKey .. "_TT"),
            getFunc = function() return sv.arrow.fx[key] ~= false end,
            setFunc = function(v)
                sv.arrow.fx[key] = v
                Changed()
            end,
            disabled = function() return not sv.arrow.shown or sv.arrow.style == "classic" or sv.anim == "off" end,
        }
    end
    local noText = function() return not sv.label.shown end
    local noPath = function() return not sv.path.shown or not W.Path.Supported() end

    W.settingsPanel = lam:RegisterAddonPanel(PANEL, {
        type = "panel",
        name = L("TITLE"),
        displayName = L("TITLE"),
        author = "|c00C8FFbrianmit|r",
        version = W.VERSION,
        registerForRefresh = true,
    })

    lam:RegisterOptionControls(PANEL, {
        { type = "description", text = L("SET_INFO") },

        { type = "header", name = L("SET_HDR_NAV") },
        Choice(nil, "target", "SET_TARGET", "SET_TARGET_TT", { "auto", "quest", "waypoint" },
            { "SET_TARGET_AUTO", "SET_TARGET_QUEST", "SET_TARGET_WAYPOINT" }),
        Check(nil, "banner", "SET_BANNER", "SET_BANNER_TT"),
        Check(nil, "followNewQuest", "SET_FOLLOW_NEW", "SET_FOLLOW_NEW_TT"),

        { type = "header", name = L("SET_HDR_LOOK") },
        Choice(nil, "fontStyle", "SET_FONT_STYLE", "SET_FONT_STYLE_TT", { "eso", "book", "plain" },
            { "SET_STYLE_ESO", "SET_STYLE_BOOK", "SET_STYLE_PLAIN" }),
        Color(function() return sv.theme end, function(c)
            sv.theme = c
            W.ApplyTheme()
        end, "SET_THEME", "SET_THEME_TT"),
        Choice(nil, "anim", "SET_ANIM", "SET_ANIM_TT", { "full", "subtle", "off" },
            { "SET_ANIM_FULL", "SET_ANIM_SUBTLE", "SET_ANIM_OFF" }),
        Check(nil, "combatFade", "SET_COMBAT_FADE", "SET_COMBAT_FADE_TT"),
        Choice(nil, "units", "SET_UNITS", "SET_UNITS_TT", { "metric", "imperial" },
            { "SET_UNITS_METRIC", "SET_UNITS_IMPERIAL" }),

        { type = "header", name = L("SET_HDR_LAUNCHER") },
        {
            type = "checkbox",
            name = L("SET_LAUNCHER"),
            getFunc = function() return not sv.launcher.hidden end,
            setFunc = function(v)
                sv.launcher.hidden = not v
                Changed()
            end,
        },
        {
            type = "checkbox",
            name = L("SET_LAUNCHER_COMPACT"),
            tooltip = L("SET_LAUNCHER_COMPACT_TT"),
            getFunc = function() return sv.launcher.compact end,
            setFunc = function(v) W.Launcher.SetCompact(v) end,
            disabled = function() return sv.launcher.hidden end,
        },
        Check("launcher", "combatHide", "SET_LAUNCHER_COMBAT", nil, function() return sv.launcher.hidden end),

        { type = "header", name = L("SET_HDR_TRACKER") },
        Check("tracker", "shown", "SET_TRACKER"),
        Choice("tracker", "panelStyle", "SET_PANEL", nil, { "ledger", "trail", "eso", "flat" },
            { "SET_PANEL_LEDGER", "SET_PANEL_TRAIL", "SET_PANEL_ESO", "SET_PANEL_FLAT" }, noTracker),
        {
            -- 0 % = fully see-through, 100 % = solid black; text and icons stay as they are
            type = "slider",
            name = L("SET_BG"),
            tooltip = L("SET_BG_TT"),
            min = 0, max = 100, step = 5,
            getFunc = function() return zo_round(sv.tracker.bgAlpha * 100) end,   -- left see-through, right dark
            setFunc = function(v)
                sv.tracker.bgAlpha = v / 100
                Changed()
            end,
            disabled = noTracker,
        },
        Check("tracker", "showTeleport", "SET_TELEPORT", nil, noTracker),
        Check(nil, "hideGameTracker", "SET_HIDE_GAME", "SET_HIDE_GAME_TT", noTracker),
        -- (only with Advanced UI's quest tracker running; on by default, with a one-time chat note)
        Check(nil, "hideAuiTracker", "SET_HIDE_AUI", "SET_HIDE_AUI_TT",
            function() return not sv.tracker.shown or not W.Tracker.AuiTrackerReady() end),
        Choice("tracker", "tab", "SET_TAB", nil, { "current", "main", "here", "all", "dungeons", "daily" },
            { "TAB_CURRENT_NAME", "TAB_MAIN_NAME", "TAB_HERE_NAME", "TAB_ALL_NAME", "TAB_DUNGEONS_NAME", "TAB_DAILY_NAME" }, noTracker),
        Check("tracker", "expandAll", "SET_EXPAND_ALL", "SET_EXPAND_ALL_TT", noTracker),
        Check("tracker", "showDistance", "SET_TRACKER_DIST", nil, noTracker),
        Slider("tracker", "fontSize", "SET_FONT", 12, 30, 1, 0, noTracker),
        Check("tracker", "locked", "SET_LOCK_TRACKER", nil, noTracker),

        { type = "header", name = L("SET_HDR_ARROW") },
        Check("arrow", "shown", "SET_ARROW"),
        Choice("arrow", "style", "SET_ARROW_STYLE", "SET_ARROW_STYLE_TT", { "compact", "classic" },
            { "SET_ARROW_STYLE_COMPACT", "SET_ARROW_STYLE_CLASSIC" }, noArrow),
        Choice("arrow", "design", "SET_ARROW_DESIGN", nil, W.Arrow.DESIGNS,
            { "DESIGN_ORNATE", "DESIGN_DWEMER", "DESIGN_ROSE", "DESIGN_BLADE", "DESIGN_MEDALLION", "DESIGN_ARROWHEAD",
              "DESIGN_OUTLINE", "DESIGN_TRIPLE", "DESIGN_DAEDRIC", "DESIGN_GEM", "DESIGN_WISP", "DESIGN_BANNER" }, noBigArrow),
        Slider("arrow", "size", "SET_ARROW_SIZE", 28, 128, 2, 0, noBigArrow),
        Check("arrow", "colorByAngle", "SET_ARROW_ANGLE", "SET_ARROW_ANGLE_TT", noArrow),
        FxCheck("spin", "SET_FX_SPIN"),
        FxCheck("glow", "SET_FX_GLOW"),
        FxCheck("arrive", "SET_FX_ARRIVE"),
        FxCheck("turn", "SET_FX_TURN"),
        Check("arrow", "hideInCombat", "SET_ARROW_COMBAT", "SET_ARROW_COMBAT_TT", noArrow),
        Check("arrow", "locked", "SET_LOCK_ARROW", nil, noBigArrow),   -- (compact: the text panel's lock)
        { type = "description", text = L("SET_ARROW_TIP") },

        { type = "header", name = L("SET_HDR_TEXT") },
        Check("label", "shown", "SET_TEXT"),
        Slider("label", "scale", "SET_TEXT_SIZE", 0.6, 1.8, 0.05, 2, noText),
        -- (the compact look has its own dark pill: this is for the big arrow only)
        Choice("label", "bg", "SET_TEXT_BG", "SET_TEXT_BG_TT", { "lines", "dark", "none" },
            { "SET_TEXT_BG_LINES", "SET_TEXT_BG_DARK", "SET_TEXT_BG_NONE" },
            function() return not sv.label.shown or sv.arrow.style ~= "classic" end),
        Check("arrow", "showName", "SET_ARROW_NAME", nil, noText),
        Check("arrow", "showDistance", "SET_ARROW_DIST", nil, noText),
        Check("arrow", "travelHint", "SET_TRAVEL_HINT", "SET_TRAVEL_HINT_TT", noText),
        Check("label", "locked", "SET_LOCK_TEXT", nil, noText),

        { type = "header", name = L("SET_HDR_PATH") },
        { type = "description", text = W.Path.Supported() and L("SET_PATH_NOTE") or L("NO_3D") },
        Check("path", "shown", "SET_PATH"),
        Choice("path", "style", "SET_PATH_STYLE", nil, W.Path.STYLES,
            { "SET_STYLE_SOLID", "SET_STYLE_CHEVRONS", "SET_STYLE_COMET", "SET_STYLE_DOTS", "SET_STYLE_LINE" }, noPath),
        Slider("path", "length", "SET_PATH_LENGTH", 10, 80, 5, 0, noPath),
        Slider("path", "width", "SET_PATH_WIDTH", 0.06, 0.5, 0.02, 2, noPath),
        Slider("path", "alpha", "SET_PATH_ALPHA", 0.1, 1, 0.05, 2, noPath),
        Color(function() return sv.path.color end, function(c) sv.path.color = c end, "SET_PATH_COLOR", nil, noPath),
        Check("path", "flow", "SET_PATH_FLOW", "SET_PATH_FLOW_TT", noPath),
        Check("path", "marker", "SET_PATH_MARKER", "SET_PATH_MARKER_TT", noPath),
        Check("path", "depth", "SET_PATH_DEPTH", "SET_PATH_DEPTH_TT", noPath),

        { type = "header", name = L("SET_HDR_MARKERS") },
        Check(nil, "npcMarker", "SET_NPC_MARKER", "SET_NPC_MARKER_TT"),
        Check("path", "pillar", "SET_PILLAR", "SET_PILLAR_TT"),   -- (Beacon, works without the ground line)
        Check(nil, "killArea", "SET_KILL_AREA", "SET_KILL_AREA_TT"),
        Check(nil, "killBadge", "SET_KILL_BADGE", "SET_KILL_BADGE_TT"),
        Check(nil, "minimap", "SET_MINIMAP", "SET_MINIMAP_TT", function() return not (AUI and AUI.Minimap) end),

        { type = "header", name = L("SET_HDR_ROADS") },
        { type = "description", text = L("SET_ROADS_INFO") },
        Check("path", "roads", "SET_ROADS", "SET_ROADS_TT", noPath),
        Check("path", "learn", "SET_LEARN", "SET_LEARN_TT"),
        {
            type = "button",
            name = L("SET_FORGET_ROADS"),
            tooltip = L("SET_FORGET_ROADS_TT"),
            func = function()
                W.Roads.Forget()
                W.Nav.ForgetPlaces()
            end,
            isDangerous = true,
            warning = L("SET_FORGET_ROADS_WARN"),
        },

        { type = "header", name = L("SET_HDR_MISC") },
        {
            type = "button",
            name = L("SET_RESET_CAL"),
            tooltip = L("SET_RESET_CAL_TT"),
            func = function() W.Nav.ResetCalibration() end,
            width = "half",
        },
        {
            type = "button",
            name = L("SET_RESET_POS"),
            func = function() W.ResetPositions() end,
            width = "half",
        },
    })
end
