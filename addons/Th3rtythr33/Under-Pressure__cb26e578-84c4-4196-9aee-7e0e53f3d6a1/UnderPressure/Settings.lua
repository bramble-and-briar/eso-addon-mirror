-- =============================================================================
-- Under Pressure -- Settings.lua
-- =============================================================================
-- LibHarvensAddonSettings panel. Ported from LibAddonMenu-2.0 in 0.3.3.
--
-- WHY LHAS. LAM does resolve on the Bethesda.net console catalogue, but its
-- console support is a partial auto-conversion INTO LibHarvensAddonSettings,
-- and not every control type survives that translation. Depending on LHAS
-- directly removes the conversion layer rather than adding a dependency.
--
-- NO NIL-GUARD, BY DESIGN. LHAS is a hard "## DependsOn", exposed as the plain
-- global LibHarvensAddonSettings (no LibStub, and it must never be vendored).
-- If it is missing the game disables this addon before any of our code runs, so
-- a fallback branch here could only ever be dead code -- and dead code that
-- claims to handle a case it cannot reach is worse than none. The LAM version
-- of this file carried exactly such a branch, complete with a comment
-- describing a manifest directive the manifest did not use.
--
-- CONSOLE LAYOUT. LHAS turns every ST_SECTION into a navigable sub-menu row, so
-- the top-level screen for this addon is SEVEN arrow rows (five through 0.3.3;
-- Plague Indicator joined in 0.4.0, Pull Indicator in 0.4.2; a No More Oopsies
-- row existed for one day in 0.5.5) and every actual control lives one level down. Two consequences drove the copy below:
--
--   * The screen header keeps showing the ADDON name/version/author on those
--     sub-pages -- the section name is NOT redisplayed anywhere. So each label
--     has to make sense without its section for context. That is why the six
--     time sliders carry unit = "s" and the two offsets carry unit = "px": the
--     "(seconds)" in the section title is invisible from the page it titles.
--   * A row with no tooltip blanks the whole left tooltip quadrant when it is
--     selected. Under LAM a missing tooltip was a missing nicety; here it reads
--     as broken next to its neighbours. Every selectable row has one.
--
-- Reset to Defaults is worth knowing about and is not configurable: the keybind
-- only appears once you are INSIDE a section (the top-level list holds no
-- control with a `default`), but it resets ALL sections when pressed.
-- =============================================================================

UP = UP or {}
UP.Settings = {}

-- Resolved in Init(), not here. `## DependsOn` does guarantee the library is
-- loaded before this file is parsed, so a file-scope lookup would work -- but
-- everything else in this file was moved off the parse-time path (see
-- buildOptions), and leaving the one cross-ADDON global behind would be the
-- odd one out. It is a lookup, not a guard: if the library is absent the addon
-- is disabled and none of this runs.
local LHAS

-- Defaults for settings stored directly on sv() rather than sv().tunables.
-- These have no UP.Defaults entry -- they are UI placement/display settings,
-- not engine tunables -- so they are named once here and referenced from the
-- getFunction fallback, the LHAS "default" field, AND the tooltip's
-- "Default: N" text below, rather than three separate hardcoded copies free to
-- drift apart. Keep in sync with DEFAULT_SAVED in UnderPressure.lua.
local UI_DEFAULT_SCALE             = 1.0
local UI_DEFAULT_OFFSET_X          = 0
local UI_DEFAULT_OFFSET_Y          = -140
local UI_DEFAULT_COUNTER_FONT_SIZE = 27

local function sv()
    return UP.sv
end

-- Tunable access is split read/write. The LAM version used a single tun()
-- accessor that invalidated the engine's tunables cache on BOTH paths,
-- justified by "getFunc only runs while the panel is open" -- a claim about the
-- settings library, and porting the settings library is exactly when such a
-- premise stops holding silently. LHAS re-runs every control's getFunction on
-- panel show, and would re-run all of them on every slider STEP if allowRefresh
-- were enabled.
--
-- The property that motivated the single accessor -- no individual setter can
-- forget to invalidate -- is preserved and strengthened: the write IS the
-- invalidation, so there is no longer an order to get wrong.
local function tunGet(key, fallback)
    local t = sv().tunables
    local v = t and t[key]
    if v == nil then return fallback end
    return v
end

local function tunSet(key, value)
    sv().tunables = sv().tunables or {}
    sv().tunables[key] = value
    if UP.Engine and UP.Engine.MarkTunablesDirty then
        UP.Engine.MarkTunablesDirty()
    end
end

-- ---------------------------------------------------------------------------
-- TTD section "Defaults" button (0.4.2)
-- ---------------------------------------------------------------------------
-- The five sliders in the TTD thresholds section, in page order, with the
-- format each slider itself uses so the tooltip and the dialog print the same
-- figures the sliders do. Read from UP.Defaults at draw time, never typed.
local TTD_KEYS = {
    { key = "red_three_ttd",            label = "Three triangles (lethal) below", fmt = "%.1fs" },
    { key = "red_two_ttd",              label = "Two triangles below",            fmt = "%.1fs" },
    { key = "red_one_ttd",              label = "One triangle below",             fmt = "%.1fs" },
    { key = "yellow_filled_ttd",        label = "Filled yellow circle below",     fmt = "%.1fs" },
    { key = "recent_pressure_window_s", label = "Recent-pressure window",         fmt = "%.0fs" },
}

local function ttdDefaultLines()
    local D = UP.Defaults
    local lines = {}
    for _, e in ipairs(TTD_KEYS) do
        lines[#lines + 1] = ("%s: %s"):format(e.label, (e.fmt):format(D[e.key]))
    end
    return table.concat(lines, "\n")
end

-- Clears the five stored overrides rather than writing the default values in.
-- The visible result is identical (every getter falls back to UP.Defaults), and
-- it is strictly better for the player: a later retune of UP.Defaults then
-- reaches them, exactly as it reaches anyone who never touched a slider (see
-- "Defaults vs. saved overrides" in Docs/UnderPressure-Reference.md). Writing
-- the numbers in would freeze today's defaults into their file for ever.
local function applyTtdDefaults()
    for _, e in ipairs(TTD_KEYS) do
        tunSet(e.key, nil)
    end
    -- Redraw the sliders on the page the player is looking at. LHAS's
    -- UpdateControls re-runs every getter for the current section and
    -- refreshes the list; its own Reset-to-Defaults path does the same.
    local panel = UP.Settings.panel
    if panel and panel.UpdateControls then
        pcall(panel.UpdateControls, panel)
    end
end

local TTD_DEFAULTS_DIALOG = "UNDERPRESSURE_TTD_DEFAULTS"

-- Mirrors LibHarvensAddonSettings' own "LibHarvensAddonSettings_Defaults"
-- dialog (gamepadInfo BASIC, two buttons) and EasyMark's account-wide switch
-- dialog, both of which run on console. mainText is a function so the figures
-- are read from UP.Defaults when the dialog opens.
local function registerTtdDefaultsDialog()
    if type(ZO_Dialogs_RegisterCustomDialog) ~= "function" then return end
    ZO_Dialogs_RegisterCustomDialog(TTD_DEFAULTS_DIALOG,
    {
        canQueue = true,
        gamepadInfo =
        {
            dialogType = GAMEPAD_DIALOGS.BASIC,
        },
        title =
        {
            text = "Under Pressure: TTD thresholds",
        },
        mainText =
        {
            text = function()
                return "Are you sure you want to set these settings to the default settings?\n\n"
                    .. ttdDefaultLines()
            end,
        },
        buttons =
        {
            {
                keybind = "DIALOG_PRIMARY",
                text = "Reset",
                callback = function() applyTtdDefaults() end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = "Cancel",
            },
        },
    })
end

local function showTtdDefaultsDialog()
    if type(ZO_Dialogs_ShowPlatformDialog) == "function" then
        ZO_Dialogs_ShowPlatformDialog(TTD_DEFAULTS_DIALOG)
    elseif type(ZO_Dialogs_ShowGamepadDialog) == "function" then
        ZO_Dialogs_ShowGamepadDialog(TTD_DEFAULTS_DIALOG)
    end
end

-- Built at Init() rather than at file scope. The LAM version read
-- UP.Fonts.MIN_SIZE/MAX_SIZE and UP.Defaults while this file was being PARSED,
-- which made the manifest's load order load-bearing in a way nothing announced.
-- Building here removes both parse-time dependencies, and lets the panel
-- version come from UP.version instead of a third hand-copied literal.
local function buildOptions()
    local D = UP.Defaults

    return {
        -- -------------------------------------------------------------------
        {
            type = LHAS.ST_SECTION, label = "Display",
            tooltip = "Where the Threat Indicator sits, how big it is, and whether it shows at all.",
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Threat Indicator",
            tooltip = "Master toggle. Set to Off to hide the Threat Indicator at all times and under all conditions.",
            getFunction = function() return not (sv().hidden or false) end,
            setFunction = function(v)
                sv().hidden = not v
                if UP.UI and UP.UI.UpdateVisibility then UP.UI.UpdateVisibility() end
            end,
            default = true,
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Always show indicator",
            tooltip = "By default the Threat Indicator is hidden when you are out of combat or dead. Turn this on to keep it on screen at all times (subject to the master 'Threat Indicator' toggle above).",
            getFunction = function() return sv().always_show == true end,
            setFunction = function(v)
                sv().always_show = v
                if UP.UI and UP.UI.UpdateVisibility then UP.UI.UpdateVisibility() end
            end,
            default = false,
        },
        {
            type = LHAS.ST_SLIDER, label = "Indicator scale",
            -- LHAS has no `decimals`; `format` replaces it, and it does more --
            -- the value is passed through tonumber(string.format(format, v))
            -- before it reaches setFunction, so this governs what is STORED,
            -- not just what is displayed.
            min = 0.5, max = 2.5, step = 0.05, format = "%.2f",
            tooltip = ("Uniform scale applied to the whole indicator, including the attacker counter. Default: %.2f."):format(UI_DEFAULT_SCALE),
            getFunction = function() return sv().scale or UI_DEFAULT_SCALE end,
            setFunction = function(v)
                sv().scale = v
                if UP.UI and UP.UI.ApplyAnchor then
                    UP.UI.ApplyAnchor(sv().offset_x or UI_DEFAULT_OFFSET_X, sv().offset_y or UI_DEFAULT_OFFSET_Y, v)
                end
            end,
            default = UI_DEFAULT_SCALE,
        },
        {
            type = LHAS.ST_SLIDER, label = "Horizontal offset",
            -- "%.0f" and NOT "%d": Lua 5.1's %d TRUNCATES a float, so a slider
            -- handing back -139.9999 on a step of 5 would be stored as -139.
            -- %.0f rounds. Applies to every integer slider in this file.
            min = -800, max = 800, step = 5, format = "%.0f", unit = "px",
            tooltip = ("Horizontal offset in pixels from screen center. Positive moves right. Default: %d."):format(UI_DEFAULT_OFFSET_X),
            getFunction = function() return sv().offset_x or UI_DEFAULT_OFFSET_X end,
            setFunction = function(v)
                sv().offset_x = v
                if UP.UI and UP.UI.ApplyAnchor then
                    UP.UI.ApplyAnchor(v, sv().offset_y or UI_DEFAULT_OFFSET_Y, sv().scale or UI_DEFAULT_SCALE)
                end
            end,
            default = UI_DEFAULT_OFFSET_X,
        },
        {
            type = LHAS.ST_SLIDER, label = "Vertical offset",
            min = -500, max = 500, step = 5, format = "%.0f", unit = "px",
            tooltip = ("Vertical offset in pixels from screen center. Negative moves down, toward the reticle. Default: %d."):format(UI_DEFAULT_OFFSET_Y),
            getFunction = function() return sv().offset_y or UI_DEFAULT_OFFSET_Y end,
            setFunction = function(v)
                sv().offset_y = v
                if UP.UI and UP.UI.ApplyAnchor then
                    UP.UI.ApplyAnchor(sv().offset_x or UI_DEFAULT_OFFSET_X, v, sv().scale or UI_DEFAULT_SCALE)
                end
            end,
            default = UI_DEFAULT_OFFSET_Y,
        },

        -- -------------------------------------------------------------------
        {
            type = LHAS.ST_SECTION, label = "Attacker counter",
            tooltip = "The number beside the Threat Indicator showing how many units are attacking you.",
        },
        {
            -- Wording deliberately tracks the published description (see
            -- ## Description in UnderPressure.addon and Docs/UnderPressure.md).
            --
            -- ST_LABEL is the nearest thing LHAS has to LAM's "description" --
            -- it is really a list row, not a prose control. With no tooltip its
            -- canSelect resolves false, so the cursor skips it, which is what
            -- prose wants. Adding a tooltip here would silently make it
            -- focusable.
            type = LHAS.ST_LABEL,
            label = "A counter beside the Threat Indicator shows how many distinct units are attacking you. Counts only units whose damage is landing on you.",
        },
        {
            -- Label dropped its "(sec)" suffix in 0.3.3: `unit` now supplies it,
            -- and the two together read "Counter window (sec)  3s".
            type = LHAS.ST_SLIDER, label = "Counter window",
            min = 1, max = 5, step = 1, format = "%.0f", unit = "s",
            tooltip = ("Rolling window used to count distinct recent attackers. Default: %.0fs."):format(D.attacker_window_s),
            getFunction = function() return tunGet("attacker_window_s", D.attacker_window_s) end,
            setFunction = function(v) tunSet("attacker_window_s", v) end,
            default = D.attacker_window_s,
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Show counter",
            -- Tooltip added in 0.3.3; see the blanked-quadrant note in the file
            -- header for why a tooltipless row is a console problem and was not
            -- a LAM one.
            tooltip = "Set to Off to hide the attacker count without hiding the Threat Indicator itself.",
            getFunction = function() return sv().show_counter ~= false end,
            setFunction = function(v)
                sv().show_counter = v
                if UP.UI and UP.UI.SetCounter then UP.UI.SetCounter(0) end
            end,
            default = true,
        },
        {
            type = LHAS.ST_SLIDER, label = "Counter text size",
            -- Range comes from the gamepad font ladder (UI/Fonts.lua), not from
            -- arbitrary pixel bounds. Values snap to the nearest font that
            -- actually exists on console, so the on-screen size moves in steps.
            min = UP.Fonts.MIN_SIZE, max = UP.Fonts.MAX_SIZE, step = 1, format = "%.0f",
            tooltip = ("Size of the counter number. Snaps to the nearest available console font size, so small adjustments may not change anything visible. Default: %d."):format(UI_DEFAULT_COUNTER_FONT_SIZE),
            getFunction = function() return sv().counter_font_size or UI_DEFAULT_COUNTER_FONT_SIZE end,
            setFunction = function(v)
                sv().counter_font_size = v
                if UP.UI and UP.UI.ApplyCounterFontSize then
                    UP.UI.ApplyCounterFontSize(v)
                end
            end,
            default = UI_DEFAULT_COUNTER_FONT_SIZE,
        },

        -- -------------------------------------------------------------------
        {
            type = LHAS.ST_SECTION, label = "Silence Indicator",
            tooltip = "The ring shown below your reticle while you are silenced.",
        },
        {
            type = LHAS.ST_LABEL,
            label = "A ring appears just below your reticle whenever you are silenced, and stays until the silence ends. Silence blocks every ability, including the heal or shield you would normally answer trouble with.",
        },
        {
            -- Its own switch, NOT gated on the Threat Indicator master toggle:
            -- that toggle's help text promises to hide the Threat Indicator
            -- specifically, and this is a separate indicator.
            type = LHAS.ST_CHECKBOX, label = "Silence Indicator",
            tooltip = "Set to Off to never show the silence ring. Independent of the Threat Indicator toggle -- turning the threat shape off leaves this running.",
            getFunction = function() return sv().silence_ring ~= false end,
            setFunction = function(v)
                sv().silence_ring = v
                if UP.SilenceRing and UP.SilenceRing.UpdateVisibility then
                    UP.SilenceRing.UpdateVisibility()
                end
            end,
            default = true,
        },
        {
            -- PREVIEW BUTTONS (0.4.0). An LHAS button row: on console the A
            -- press runs clickHandler and the keybind strip shows buttonText
            -- (LibHarvensAddonSettings/Console/Settings.lua, keybind
            -- descriptor). Replaces the /up-visual-test slash command. The
            -- preview draws while this menu is still open -- the HUD-scene gate
            -- is bypassed for it, see UI/SilenceRing.lua -- so the player sees
            -- the ring without backing out. Bypasses the toggle above too: a
            -- preview that did nothing while the feature is off would read as
            -- broken, and this is where you turn it back on.
            type = LHAS.ST_BUTTON, label = "Preview the silence ring",
            buttonText = "Preview",
            tooltip = "Shows the silence ring for 10 seconds so you can see where it sits and how it pulses, without needing to be silenced. Works even while the indicator is set to Off.",
            clickHandler = function()
                if UP.SilenceRing and UP.SilenceRing.RunPreview then UP.SilenceRing.RunPreview() end
            end,
        },

        -- -------------------------------------------------------------------
        {
            type = LHAS.ST_SECTION, label = "Plague Indicator",
            tooltip = "Triggered when afflicted with Plague Carrier (Plaguebreak).",
        },
        {
            type = LHAS.ST_LABEL,
            label = "Triggered when afflicted with Plague Carrier (Plaguebreak).",
        },
        {
            -- The default plague visual (0.4.2). Independent of the Threat
            -- Indicator master toggle, like the ring.
            type = LHAS.ST_CHECKBOX, label = "Plague corner icons",
            tooltip = "Shows the Plague Carrier icon in all four corners of the screen, slowly flashing, for as long as the plague is on you. Default: On.",
            getFunction = function() return sv().plague_icon_corners ~= false end,
            setFunction = function(v)
                sv().plague_icon_corners = v
                if UP.PlagueIcon and UP.PlagueIcon.UpdateVisibility then
                    UP.PlagueIcon.UpdateVisibility()
                end
                -- The "You died with" note follows the set of enabled visuals.
                if UP.PlagueTint and UP.PlagueTint.UpdateVisibility then
                    UP.PlagueTint.UpdateVisibility()
                end
            end,
            default = true,
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Plague centre icon",
            tooltip = "Shows one Plague Carrier icon below the reticle, just under where the silence ring appears, with a slow pulse. Default: Off.",
            getFunction = function() return sv().plague_icon_center == true end,
            setFunction = function(v)
                sv().plague_icon_center = v
                if UP.PlagueIcon and UP.PlagueIcon.UpdateVisibility then
                    UP.PlagueIcon.UpdateVisibility()
                end
                if UP.PlagueTint and UP.PlagueTint.UpdateVisibility then
                    UP.PlagueTint.UpdateVisibility()
                end
            end,
            default = false,
        },
        {
            -- Was the only visual, and on by default, in 0.4.0 and 0.4.1;
            -- opt-in since 0.4.2 (see migratePlagueDefaults in UnderPressure.lua).
            type = LHAS.ST_CHECKBOX, label = "Plague edge glow (screen tint)",
            tooltip = "Tints the edges of the screen smoky green for as long as the plague is on you. Default: Off. The chat report below is separate.",
            getFunction = function() return sv().plague_tint == true end,
            setFunction = function(v)
                sv().plague_tint = v
                if UP.PlagueTint and UP.PlagueTint.UpdateVisibility then
                    UP.PlagueTint.UpdateVisibility()
                end
            end,
            default = false,
        },
        {
            type = LHAS.ST_SLIDER, label = "Plague edge glow strength",
            -- Range comes from UI/PlagueTint.lua so the slider can never ask
            -- for more than the tint will apply (it clamps too).
            min = UP.PlagueTint.MIN_STRENGTH, max = UP.PlagueTint.MAX_STRENGTH, step = 0.05, format = "%.2f",
            tooltip = ("How dense the green edge glow is, when it is on. Default: %.2f."):format(UP.PlagueTint.DEFAULT_STRENGTH),
            getFunction = function() return sv().plague_tint_strength or UP.PlagueTint.DEFAULT_STRENGTH end,
            setFunction = function(v)
                sv().plague_tint_strength = v
                if UP.PlagueTint and UP.PlagueTint.ApplyStrength then
                    UP.PlagueTint.ApplyStrength(v)
                end
            end,
            default = UP.PlagueTint.DEFAULT_STRENGTH,
        },
        {
            -- The one place this add-on prints to chat without being asked by a
            -- command. Default on because the report is the feature; the
            -- switch exists for anyone who only wants the tint.
            type = LHAS.ST_CHECKBOX, label = "Explosion report in chat",
            tooltip = "When a plague on you is removed early, print who removed it, what with, and the explosion damage this client saw. Set to Off for the tint alone.",
            getFunction = function() return sv().plague_report ~= false end,
            setFunction = function(v) sv().plague_report = v end,
            default = true,
        },
        {
            -- See the silence Preview button above for the mechanism.
            type = LHAS.ST_BUTTON, label = "Preview the plague indicators",
            buttonText = "Preview",
            tooltip = "Shows the plague visuals you have switched on above (corner icons, centre icon, edge glow) for 10 seconds, without needing a Plaguebreak wearer to hit you. If all three are off, it shows the corner icons.",
            clickHandler = function()
                if UP.PlagueTint and UP.PlagueTint.RunPreview then UP.PlagueTint.RunPreview() end
            end,
        },
        -- Groupmate plague (0.5.7, EXPERIMENTAL). A plague on someone else
        -- explodes on everyone within 8 m of THEM, so knowing who carries one
        -- is knowing who to stand clear of. Detection is a hard switch (the
        -- subscriptions exist only while it is on); the two outputs are
        -- separate so either can be silenced.
        {
            type = LHAS.ST_LABEL,
            label = "Experimental: groupmate plague detection. A plague on someone else in your group explodes on everyone within 8 metres of them if it is removed early. With this on, the add-on watches your group for Plague Carrier and tells you who has it, on screen and/or in chat. Off by default until it is proven on console.",
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Groupmate plague detection (Experimental)",
            tooltip = "Set to On to watch your group for Plague Carrier. Needs testing on console: the API audit under Debug shows whether group effect events are arriving. Default: Off.",
            getFunction = function() return sv().plague_group_detect == true end,
            setFunction = function(v)
                sv().plague_group_detect = v
                if UP.Ingest and UP.Ingest.SetGroupPlagueDetection then UP.Ingest.SetGroupPlagueDetection(v) end
            end,
            default = false,
        },
        {
            type = LHAS.ST_CHECKBOX, label = "On-screen message",
            tooltip = "When a groupmate becomes a Plague Carrier, shows \"<name> tested positive for the plague!\" as a centre-screen announcement. Default: On.",
            getFunction = function() return sv().plague_group_screen ~= false end,
            setFunction = function(v) sv().plague_group_screen = v end,
            default = true,
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Chat lines",
            tooltip = "When a groupmate becomes a Plague Carrier, prints who and how long it lasts to chat, and prints again when it ends or is removed early. Default: On.",
            getFunction = function() return sv().plague_group_alert ~= false end,
            setFunction = function(v) sv().plague_group_alert = v end,
            default = true,
        },

        -- -------------------------------------------------------------------
        -- Pull Indicator (0.4.2). ONE detection switch for every pull the
        -- tracker knows about, off by default; three display switches that
        -- only shape the warning. See Engine/PullTracker.lua for what is
        -- detected and Docs/PullDetection-*.md for the evidence.
        {
            type = LHAS.ST_SECTION, label = "Pull Indicator",
            tooltip = "Warns you a moment before an enemy's Rush of Agony or Dark Convergence pulls you.",
        },
        {
            type = LHAS.ST_LABEL,
            label = "Warns you just before an enemy's pull lands, while there is still time to block or move: about 0.8 seconds before a Rush of Agony pull and about 1 second before a Dark Convergence pull. Off by default. Scribing pulls will join the same switch if they prove detectable. The warning can be shown as flashing icons in the four corners, one icon beside the reticle, and flashing bars down the left and right edges of the screen.",
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Pull detection",
            tooltip = "Set to On to detect incoming Rush of Agony and Dark Convergence pulls and show the warning displays chosen below. One switch covers every pull this add-on can detect. Default: Off.",
            getFunction = function() return sv().pull_detect == true end,
            setFunction = function(v)
                sv().pull_detect = v
                -- Turning it off mid-warning clears the warning.
                if not v and UP.Pull and UP.Pull.Clear then UP.Pull.Clear() end
            end,
            default = false,
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Pull corner icons",
            tooltip = "Shows the pull warning icon in all four corners of the screen, flashing, while a pull is incoming. Default: On.",
            getFunction = function() return sv().pull_icon_corners ~= false end,
            setFunction = function(v)
                sv().pull_icon_corners = v
                if UP.PullIndicator and UP.PullIndicator.UpdateVisibility then UP.PullIndicator.UpdateVisibility() end
            end,
            default = true,
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Pull centre icon",
            tooltip = "Shows one pull warning icon just to the right of the reticle, pulsing, while a pull is incoming. Default: Off.",
            getFunction = function() return sv().pull_icon_center == true end,
            setFunction = function(v)
                sv().pull_icon_center = v
                if UP.PullIndicator and UP.PullIndicator.UpdateVisibility then UP.PullIndicator.UpdateVisibility() end
            end,
            default = false,
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Pull side borders",
            tooltip = "Flashes a sharp-edged orange bar down the full left and right edges of the screen while a pull is incoming. Default: Off.",
            getFunction = function() return sv().pull_border == true end,
            setFunction = function(v)
                sv().pull_border = v
                if UP.PullIndicator and UP.PullIndicator.UpdateVisibility then UP.PullIndicator.UpdateVisibility() end
            end,
            default = false,
        },
        {
            type = LHAS.ST_BUTTON, label = "Preview the pull warning",
            buttonText = "Preview",
            tooltip = "Shows the pull warning displays you have switched on above for 10 seconds, without waiting to be pulled. Works even while Pull detection is Off, so you can see what you would get. If all three displays are off, it shows the corner icons.",
            clickHandler = function()
                if UP.PullIndicator and UP.PullIndicator.RunPreview then UP.PullIndicator.RunPreview() end
            end,
        },

        -- -------------------------------------------------------------------
        {
            type = LHAS.ST_SECTION, label = "TTD thresholds (seconds)",
            tooltip = "Estimated time-to-die values at which the indicator changes shape.",
        },
        {
            type = LHAS.ST_SLIDER, label = "Three triangles (lethal) below",
            min = 0.3, max = 2.0, step = 0.1, format = "%.1f", unit = "s",
            tooltip = ("Below this estimated time-to-die, the indicator shows three stacked red triangles -- immediately lethal. Default: %.1fs."):format(D.red_three_ttd),
            getFunction = function() return tunGet("red_three_ttd", D.red_three_ttd) end,
            setFunction = function(v) tunSet("red_three_ttd", v) end,
            default = D.red_three_ttd,
        },
        {
            type = LHAS.ST_SLIDER, label = "Two triangles below",
            min = 0.5, max = 4.0, step = 0.1, format = "%.1f", unit = "s",
            tooltip = ("Below this estimated time-to-die, the indicator shows two stacked red triangles -- extreme. Default: %.1fs."):format(D.red_two_ttd),
            getFunction = function() return tunGet("red_two_ttd", D.red_two_ttd) end,
            setFunction = function(v) tunSet("red_two_ttd", v) end,
            default = D.red_two_ttd,
        },
        {
            type = LHAS.ST_SLIDER, label = "One triangle below",
            min = 1.0, max = 6.0, step = 0.1, format = "%.1f", unit = "s",
            tooltip = ("Below this estimated time-to-die, the indicator shows one red triangle -- high. Default: %.1fs."):format(D.red_one_ttd),
            getFunction = function() return tunGet("red_one_ttd", D.red_one_ttd) end,
            setFunction = function(v) tunSet("red_one_ttd", v) end,
            default = D.red_one_ttd,
        },
        {
            type = LHAS.ST_SLIDER, label = "Filled yellow circle below",
            min = 2.0, max = 12.0, step = 0.1, format = "%.1f", unit = "s",
            tooltip = ("Below this estimated time-to-die, the indicator fills solid yellow -- moderate. Default: %.1fs."):format(D.yellow_filled_ttd),
            getFunction = function() return tunGet("yellow_filled_ttd", D.yellow_filled_ttd) end,
            setFunction = function(v) tunSet("yellow_filled_ttd", v) end,
            default = D.yellow_filled_ttd,
        },
        {
            type = LHAS.ST_SLIDER, label = "Recent-pressure window",
            min = 3, max = 30, step = 1, format = "%.0f", unit = "s",
            tooltip = ("After the last hit or debuff, how long the indicator keeps showing the yellow ring (recent pressure, not currently lethal) before dropping to the green square. Default: %.0fs."):format(D.recent_pressure_window_s),
            getFunction = function() return tunGet("recent_pressure_window_s", D.recent_pressure_window_s) end,
            setFunction = function(v) tunSet("recent_pressure_window_s", v) end,
            default = D.recent_pressure_window_s,
        },
        {
            -- Section-scoped reset (0.4.2). The tooltip is the point: it shows
            -- the five current defaults beside the sliders without touching
            -- anything, and it is a function so it reads UP.Defaults when the
            -- row is selected. Pressing A opens a confirmation dialog; only
            -- the dialog's Reset button writes. Distinct from LHAS's own
            -- Reset-to-Defaults keybind, which resets every section at once.
            type = LHAS.ST_BUTTON, label = "Defaults",
            buttonText = "Reset",
            tooltip = function()
                return "Current defaults for this section:\n\n" .. ttdDefaultLines()
                    .. "\n\nPress to set all five sliders back to these values. You will be asked to confirm. "
                    .. "Only this section is affected."
            end,
            clickHandler = function() showTtdDefaultsDialog() end,
        },

        -- The "Pressure weighting" section was removed in 0.2.9: nine sliders for
        -- the window weights, burst multiplier, debuff risk-bonus weight, pressure
        -- DPS floor and state persistence. The model is tuned and the controls only
        -- gave users a way to un-tune it. The tunables still exist in UP.Defaults
        -- and are still read by the engine every tick -- only the UI is gone, so
        -- restoring a slider is a matter of re-adding the entry here.
        --
        -- Saved overrides written by 0.2.8 users are cleared once on upgrade (see
        -- REMOVED_TUNABLES in UnderPressure.lua); without that they would persist
        -- forever with no control left to change or reset them.

        -- -------------------------------------------------------------------
        {
            type = LHAS.ST_SECTION, label = "Debug",
            tooltip = "Diagnostic read-out. Not needed for normal play.",
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Show debug overlay",
            tooltip = "Shows a diagnostic read-out of pressure, time-to-die, attacker count, silence and plague state, and recent events.",
            getFunction = function() return sv().debug or false end,
            setFunction = function(v)
                sv().debug = v
                if UP.Debug and UP.Debug.SetVisible then UP.Debug.SetVisible(v) end
            end,
            default = false,
        },
        {
            -- Replaces /upfont (0.4.0), which was never persisted. Same ladder
            -- snapping as the counter text size.
            type = LHAS.ST_SLIDER, label = "Debug text size",
            min = UP.Fonts.MIN_SIZE, max = UP.Fonts.MAX_SIZE, step = 1, format = "%.0f",
            tooltip = ("Text size of the debug overlay. Snaps to the nearest available console font size. Default: %d."):format(UP.Debug.DEFAULT_FONT_SIZE),
            getFunction = function() return sv().debug_font_size or UP.Debug.DEFAULT_FONT_SIZE end,
            setFunction = function(v)
                sv().debug_font_size = v
                if UP.Debug and UP.Debug.ApplyFontSize then UP.Debug.ApplyFontSize(v) end
            end,
            default = UP.Debug.DEFAULT_FONT_SIZE,
        },
        {
            -- Replaces /up-api-audit (0.4.0). Prints to chat because the audit
            -- is a multi-line diagnostic read-out, and chat is the one place a
            -- console player can scroll back through it. Pressing the button
            -- IS the request, so the no-unasked-chat rule is honoured.
            type = LHAS.ST_BUTTON, label = "Print API audit to chat",
            buttonText = "Print",
            tooltip = "Prints which game capabilities the add-on detected at load, the startup notes, and whether the Plaguebreak ability ids still resolve. Diagnostic only.",
            clickHandler = function()
                if UP.RunApiAudit then UP.RunApiAudit() end
            end,
        },
    }
end

-- Exposed for Tools/tests/underpressure_settings.lua. Not used by the add-on.
UP.Settings._ttdDefaultLines  = ttdDefaultLines
UP.Settings._applyTtdDefaults = applyTtdDefaults
UP.Settings._TTD_DIALOG       = TTD_DEFAULTS_DIALOG

function UP.Settings.Init()
    LHAS = LibHarvensAddonSettings

    -- allowRefresh is deliberately NOT set, and it is not the equivalent of
    -- LAM's registerForRefresh. LAM's flag meant "re-read every getFunc when
    -- the panel is shown"; LHAS does that unconditionally and for free, via its
    -- own fragment state-change hook. LHAS's allowRefresh means something else:
    -- re-run EVERY control's getFunction whenever ANY control changes, which a
    -- slider does on every step while the stick is held. Nothing in this panel
    -- is conditional on another control, so it would buy nothing -- and its
    -- refresh path pushes values into sliders WITHOUT first detaching their
    -- OnValueChanged handler (the library's own update path is careful to
    -- detach), i.e. it invites a change cascade between our ten sliders.
    --
    -- allowDefaults IS wanted: it is the LHAS equivalent of registerForDefaults.
    local panel = LHAS:AddAddon("Under Pressure", {
        allowDefaults = true,
    })

    -- The console header reads panel.version and panel.author, but LHAS never
    -- sets them -- they are ours to fill in. Sourced from UP.* rather than
    -- literals so they cannot drift: through 0.2.7 the manifest, the main entry
    -- and the panel disagreed four ways.
    panel.version = UP.version
    panel.author  = UP.author

    -- Safe to call immediately: until the panel is selected, AddSettings is
    -- pure table manipulation and creates no controls. It must, however, happen
    -- before the player first opens the gamepad Main Menu -- LHAS initialises
    -- lazily on that first show and snapshots its addon list then, so anything
    -- registering later never appears at all. Init() runs from
    -- EVENT_ADD_ON_LOADED, which is comfortably early.
    panel:AddSettings(buildOptions())

    UP.Settings.panel = panel

    -- Confirmation dialog for the TTD section's Defaults button (0.4.2).
    registerTtdDefaultsDialog()
end
