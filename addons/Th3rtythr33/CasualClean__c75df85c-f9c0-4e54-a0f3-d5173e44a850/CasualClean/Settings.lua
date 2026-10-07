-- =============================================================================
-- CasualClean -- Settings.lua
-- =============================================================================
-- LibHarvensAddonSettings panel.
--
-- NO NIL-GUARD, BY DESIGN. LHAS is a hard `## DependsOn`, exposed as the plain
-- global LibHarvensAddonSettings (no LibStub, and it must never be vendored --
-- it errors if loaded twice). If it is missing the game disables this addon
-- before any of our code runs, so a fallback branch could only ever be dead
-- code. Same reasoning as UnderPressure/Settings.lua.
--
-- REGISTRATION TIMING IS LOAD-BEARING. LHAS initialises lazily on the first
-- Main Menu show and snapshots its addon list at that moment, so Init() must
-- be reached from EVENT_ADD_ON_LOADED or this addon never appears at all.
--
-- CONSOLE ENTRY POINT is an "Add-Ons" item injected into the gamepad Main
-- Menu (before Activity Finder), NOT Settings -> Add-Ons. It renames itself
-- "Add-Ons 2" if LibAddonMenu2 is also loaded, so the label a player sees
-- depends on their other addons.
--
-- FIELD NAMES differ from LibAddonMenu: getFunction/setFunction/label, not
-- getFunc/setFunc/name. There is no `decimals`; `format` replaces it and
-- governs the STORED value, not just the display, because the value goes
-- through tonumber(string.format(format, v)) before reaching setFunction.
-- Hence "%.0f" and never "%d" -- under Lua 5.1 %d truncates a float rather
-- than rounding, so a slider reading 64 can store 63.
--
-- Every selectable row carries a tooltip: a row without one blanks the whole
-- left tooltip quadrant when selected, which reads as broken next to its
-- neighbours.
--
-- SECTIONS ARE DRILL-DOWNS. Every ST_SECTION becomes a navigable sub-menu row
-- (house rule: never set `subMenu = false`), so the top-level screen is arrow
-- rows ("Mag/Stam Arcs", "HUD Trackers", "Companion Pin") and the controls
-- live one level down.
-- Requested that way 2026-08-08 while there was only one section, so the shape
-- was already right when the second one arrived in 1.6.6.
--
-- The consequence that constrains the copy below: on a drilled-down page the
-- header keeps showing the ADDON, and the section title is NOT redisplayed
-- anywhere. Every label therefore has to make sense with no section for
-- context -- which is why they all carry an explicit "Arc" or spell out
-- "magicka and stamina" rather than relying on the section name.
--
-- Reset to Defaults is worth knowing about: its keybind only appears once you
-- are INSIDE a section, which with this layout means it is always reachable,
-- but it resets ALL sections when pressed.
-- =============================================================================

CasualClean = CasualClean or {}
local CC = CasualClean
CC.Settings = {}

-- Resolved in Init() rather than at file scope. `## DependsOn` does guarantee
-- the library is parsed first, so a file-scope lookup would work; this is a
-- lookup, not a guard.
local LHAS

local function sv()
    return CC.sv
end

function CC.Settings.Init()
    LHAS = LibHarvensAddonSettings
    local Arcs = CC.MagStamArcs
    local Tracker = CC.QuestTracker
    local Companion = CC.Companion

    local panel = LHAS:AddAddon("CasualClean", {
        allowDefaults = true,
        -- Not LAM's registerForRefresh. LHAS refreshes on panel-show for
        -- free; allowRefresh re-runs EVERY control's getter whenever ANY
        -- control changes, which is only worth it for cross-control `disable`
        -- logic. There is none here, and its refresh path pushes into sliders
        -- without detaching OnValueChanged first.
        allowRefresh = false,
    })

    -- Built once here rather than inline in the setting, so the same table
    -- identity backs both the item list and the name lookup.
    local fillItems = {}
    for _, direction in ipairs({ Arcs.FILL_BOTTOM_UP, Arcs.FILL_TOP_DOWN, Arcs.FILL_CENTRE_OUT }) do
        fillItems[#fillItems + 1] = { name = Arcs.FILL_DIRECTION_NAMES[direction], data = direction }
    end

    panel:AddSettings({
        {
            -- No `subMenu = false`, so this renders as a drill-down row and
            -- everything after it lives on the sub-page it opens.
            type = LHAS.ST_SECTION,
            label = "Mag/Stam Arcs",
            tooltip = "The magicka and stamina arcs that flank your reticle.",
        },
        {
            -- Master switch, first in the section. Off is a hard off (see
            -- UI/MagStamArcs.lua): events unregistered, stock bars restored.
            type = LHAS.ST_CHECKBOX,
            label = "Show Mag/Stam Arcs",
            tooltip = "Turn the magicka and stamina arcs off entirely. The game's own bars come back " ..
                      "while this is off, whatever the setting below says.",
            getFunction = function() return Arcs.GetEnabled() end,
            setFunction = function(value) Arcs.SetEnabled(value) end,
            default = Arcs.DEFAULT_ENABLED,
        },
        {
            -- On console ST_DROPDOWN is rendered as a ZO_GamepadHorizontalListRow
            -- (left/right on the d-pad), not a drop-down list -- which suits a
            -- three-way choice better than a menu would.
            type = LHAS.ST_DROPDOWN,
            label = "Arc fill direction",
            tooltip = "Which way the magicka and stamina arcs drain as you spend the resource. " ..
                      "Bottom-up is conventional; centre-out thins the arc symmetrically from the middle.",
            items = fillItems,
            -- Returns the item's NAME. LHAS matches the current value with
            -- FindIndexFromData(getFunction(), equalityFunction), and that
            -- equality function's first clause is `leftData == rightData.name`
            -- -- so a plain name string is what selects the right entry on
            -- panel open. Returning the enum number here would silently fall
            -- through to the default every time the panel is reopened.
            getFunction = function() return Arcs.GetFillDirectionName() end,
            setFunction = function(_, _, item) Arcs.SetFillDirection(item.data) end,
            default = Arcs.DEFAULT_FILL_DIRECTION,
        },
        {
            type = LHAS.ST_SLIDER,
            label = "Arc distance from centre",
            tooltip = ("How far each arc sits from the centre of the screen, in pixels. Default: %d.")
                :format(Arcs.DEFAULT_ARC_OFFSET_X),
            min = 32,
            max = 300,
            step = 2,
            unit = "px",
            format = "%.0f",
            getFunction = function() return sv().arcOffsetX end,
            setFunction = function(value) Arcs.SetArcOffsetX(value) end,
            default = Arcs.DEFAULT_ARC_OFFSET_X,
        },
        {
            type = LHAS.ST_SLIDER,
            label = "Arc height",
            tooltip = ("Height of each arc in pixels. The width scales with it, so the shape is " ..
                       "preserved. Default: %d."):format(Arcs.DEFAULT_ARC_HEIGHT),
            min = 64,
            max = 320,
            step = 4,
            unit = "px",
            format = "%.0f",
            getFunction = function() return sv().arcHeight end,
            setFunction = function(value) Arcs.SetArcHeight(value) end,
            default = Arcs.DEFAULT_ARC_HEIGHT,
        },
        {
            -- Deliberately last: it is the destructive-looking one, and it is
            -- the only control here that changes something outside this
            -- addon's own UI.
            --
            -- Magicka and stamina only, not health -- those are the two the
            -- arcs actually replace, and hiding health would leave it with no
            -- readout at all.
            type = LHAS.ST_CHECKBOX,
            label = "Hide default magicka and stamina bars",
            tooltip = "Hides ESO's own magicka and stamina bars, which the arcs replace. " ..
                      "Turn this off to show both at once. Your health bar is never affected. " ..
                      "Like the arcs themselves, this applies everywhere, including Cyrodiil, " ..
                      "Battlegrounds, Dungeons and Trials.",
            getFunction = function() return Arcs.GetHideDefaultBars() end,
            setFunction = function(value) Arcs.SetHideDefaultBars(value) end,
            default = Arcs.DEFAULT_HIDE_DEFAULT_BARS,
        },

        {
            -- Second drill-down. Its one control changes something outside
            -- this addon's own UI, so the tooltip spells out what it touches
            -- and the one precondition (the game's own tracker setting).
            type = LHAS.ST_SECTION,
            label = "HUD Trackers",
            tooltip = "Keep the quest and Golden Pursuit trackers off the screen during play and see them in the menu instead.",
        },
        {
            type = LHAS.ST_CHECKBOX,
            label = "Show quest tracker only in the menu",
            tooltip = "Hides the quest tracker (and the zone story tracker) while you play, and shows it " ..
                      "on the main menu and its sub-list instead. Needs the game's own Show Quest Tracker " ..
                      "setting left on, which this add-on never changes. Deeper menu screens such as " ..
                      "Inventory and Journal are not affected.",
            getFunction = function() return Tracker.GetEnabled("quest") end,
            setFunction = function(value) Tracker.SetEnabled("quest", value) end,
            default = Tracker.DEFAULTS.questTrackerInMenu,
        },
        {
            -- ZOS's "Aspiration" tracker is one control that shows either a
            -- Golden Pursuit or an Endeavor, whichever is assisted, so this
            -- necessarily covers both; the tooltip says so. The achievement
            -- tracker linked beneath it follows along, as zone story does
            -- for quests.
            type = LHAS.ST_CHECKBOX,
            label = "Show Golden Pursuit tracker only in the menu",
            tooltip = "Hides the Golden Pursuit tracker while you play, and shows it on the main menu " ..
                      "and its sub-list instead. The game uses the same tracker for Endeavors and for " ..
                      "a tracked achievement, so those move with it.",
            getFunction = function() return Tracker.GetEnabled("pursuit") end,
            setFunction = function(value) Tracker.SetEnabled("pursuit", value) end,
            default = Tracker.DEFAULTS.pursuitTrackerInMenu,
        },
        {
            -- The peek only ever acts while a tracker above is hidden, so it
            -- is harmless with both of them off.
            type = LHAS.ST_CHECKBOX,
            label = "Peek at hidden trackers with the assist button",
            tooltip = "While a tracker is hidden, the first press of the quest assist button (right on " ..
                      "the d-pad by default) shows the hidden trackers for a few seconds instead of " ..
                      "changing the tracked quest. Pressing again while they are visible changes the " ..
                      "quest as normal.",
            getFunction = function() return Tracker.GetPeekEnabled() end,
            setFunction = function(value) Tracker.SetPeekEnabled(value) end,
            default = Tracker.DEFAULTS.trackerPeek,
        },
        {
            type = LHAS.ST_SLIDER,
            label = "Peek duration",
            tooltip = ("How long the trackers stay up after a peek, in seconds. Default: %d."):format(Tracker.DEFAULTS.trackerPeekSeconds),
            min = Tracker.PEEK_SECONDS_MIN,
            max = Tracker.PEEK_SECONDS_MAX,
            step = 1,
            unit = "s",
            format = "%.0f",
            getFunction = function() return Tracker.GetPeekSeconds() end,
            setFunction = function(value) Tracker.SetPeekSeconds(value) end,
            default = Tracker.DEFAULTS.trackerPeekSeconds,
        },

        {
            type = LHAS.ST_SECTION,
            label = "Companion Pin",
            tooltip = "The follower icon over your companion's head, and what happens to the game's companion frame.",
        },
        {
            -- Master switch. Off is a hard off: the 30 Hz position poll is
            -- unregistered and the companion frame is left as the game draws it.
            type = LHAS.ST_CHECKBOX,
            label = "Show companion pin",
            tooltip = "Turn the companion pin, its edge arrow and its death marker off entirely. " ..
                      "The game's companion frame is left alone while this is off.",
            getFunction = function() return Companion.GetEnabled() end,
            setFunction = function(value) Companion.SetEnabled(value) end,
            default = Companion.DEFAULT_MARKER,
        },
        {
            type = LHAS.ST_CHECKBOX,
            label = "Hide default companion unit frame",
            tooltip = "Hides the game's own companion frame while the pin is showing, so the pin " ..
                      "replaces it. Turn this off to keep both.",
            getFunction = function() return Companion.GetHideFrame() end,
            setFunction = function(value) Companion.SetHideFrame(value) end,
            default = Companion.DEFAULT_HIDE_FRAME,
        },
    })
end
