local ADDON_NAME    = "AreYouSlow"
local ADDON_TITLE   = "Are You Slow?"
local ADDON_AUTHOR  = "Th3rtythr33"
local ADDON_VERSION = "1.1.0"   -- keep in step with ## Version in the manifest

-- ESO has no native "current speed" query -- same conclusion reached while
-- building DoesThisThingGoAnyFaster (see this workspace's CLAUDE.md):
-- position sampling is the only available signal. GetUnitWorldPosition's
-- raw units have no fixed real-world conversion and the scale differs per
-- zone (confirmed via LibGPS3's source and ESOUI forum thread 9251), so
-- this reports speed in raw units/second rather than a real-world unit
-- like m/s -- there's no reliable way to convert without taking a LibGPS
-- dependency, which isn't warranted just to relabel the same number.
local POLL_MS = 200                   -- how often to sample position
local SMOOTHING_ALPHA = 0.3           -- EMA smoothing so the readout isn't jittery frame-to-frame
local MAX_PLAUSIBLE_DELTA_MS = 1000   -- ignore samples spanning a hitch/loading pause

-- ---------------------------------------------------------------------------
-- Graph tuning
-- ---------------------------------------------------------------------------
-- The graph is the LAST 30 SECONDS of raw per-poll readings, one bar per
-- poll, oldest on the left. It deliberately bypasses the smoothed value the
-- readout shows: the readout exists to be a stable number, the graph exists to
-- show what actually happened, hitch by hitch.
local GRAPH_WINDOW_MS     = 30000
local GRAPH_SAMPLES       = GRAPH_WINDOW_MS / POLL_MS    -- 150 bars
local GRAPH_BAR_WIDTH     = 2
local GRAPH_HEIGHT        = 48
local GRAPH_WIDTH         = GRAPH_SAMPLES * GRAPH_BAR_WIDTH
local GRAPH_FULL_SPEED    = 2000     -- u/s: full bar height; anything OVER this is drawn blue
local GRAPH_MIDLINE_SPEED = 1000     -- u/s: where the single reference line sits
local GRAPH_BRIGHT_SPEED  = 1940     -- u/s: the brightest green; darker shades below it
local GRAPH_MIN_GREEN     = 0.3      -- green channel at a crawl; climbs to 1.0 at GRAPH_BRIGHT_SPEED
local GRAPH_MIN_FRACTION  = 0.01     -- below 1% of full scale a bar is not drawn at all
local GRAPH_OVER_COLOR    = { 0.25, 0.55, 1.0 }   -- the "over 2000" blue

-- ---------------------------------------------------------------------------
-- Display modes and settings
-- ---------------------------------------------------------------------------
local MODE_READOUT = "readout"
local MODE_GRAPH   = "graph"

-- LHAS dropdown items MUST be {name=, data=} tables on console: the gamepad
-- horizontal list reads data.name when an entry is chosen, and its equality
-- function compares getFunction's return value against item.name. Plain
-- strings do not survive that path. Confirmed in LibHarvensAddonSettings
-- 2.2.0, Console/Settings.lua (setup) and line ~967 (equality).
local MODE_ITEMS = {
    { name = "Smoothed readout",   data = MODE_READOUT },
    { name = "Speed graph (30 s)", data = MODE_GRAPH },
}
local MODE_NAME_BY_VALUE, MODE_VALUE_BY_NAME = {}, {}
for _, item in ipairs(MODE_ITEMS) do
    MODE_NAME_BY_VALUE[item.data] = item.name
    MODE_VALUE_BY_NAME[item.name] = item.data
end

-- Must match ## SavedVariables in the manifest exactly. Account-wide: which
-- display a player prefers is a taste, not a per-character thing.
local SAVED_VARS_NAME    = "AreYouSlowSavedVars"
local SAVED_VARS_VERSION = 1
local DEFAULTS = { displayMode = MODE_READOUT }

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
local sv                                   -- ZO_SavedVars account-wide table
local rootControl, speedLabel              -- the HUD top-level and the readout
local graphControl, graphPlot              -- the graph virtual and its bar parent (nil if construction failed)
local bars = {}                            -- bar textures, index 1 = leftmost
local readings = {}                        -- ring buffer of raw u/s readings; false = no valid sample that poll
local readingsHead = 0                     -- index of the newest slot written (0 = nothing yet)
local lastZoneId, lastX, lastY, lastZ, lastTimeMs
local smoothedSpeed                        -- u/s, exponentially smoothed

-- ---------------------------------------------------------------------------
-- Readout
-- ---------------------------------------------------------------------------
local function UpdateSpeedLabel()
    if not smoothedSpeed then return end   -- nothing measured yet; keep the placeholder text
    -- %.0f rounds; %d would truncate toward zero under Lua 5.1 (see CLAUDE.md).
    speedLabel:SetText(string.format("Speed: %.0f u/s", smoothedSpeed))
end

-- ---------------------------------------------------------------------------
-- Graph
-- ---------------------------------------------------------------------------
-- Every poll pushes exactly one slot, so the ring is a time axis at POLL_MS
-- spacing: 150 slots = 30 s. A poll that produced no usable delta (first poll,
-- zone change, load screen, a hitch longer than MAX_PLAUSIBLE_DELTA_MS)
-- pushes `false` and draws as a gap rather than as a zero, because a gap is
-- "no data" and a zero is "stood still", and conflating them would be a lie.
local function PushReading(reading)
    readingsHead = (readingsHead % GRAPH_SAMPLES) + 1
    readings[readingsHead] = reading
end

-- Column c (1 = oldest, GRAPH_SAMPLES = newest) maps to ring slot
--   ((readingsHead + c - 1) % GRAPH_SAMPLES) + 1
-- so c = GRAPH_SAMPLES lands on readingsHead itself. Slots never written are
-- nil and read as gaps.
local function ReadingForColumn(c)
    return readings[((readingsHead + c - 1) % GRAPH_SAMPLES) + 1]
end

-- Height is linear in speed up to GRAPH_FULL_SPEED and clamps there. Colour
-- is a green ramp from GRAPH_MIN_GREEN to full green at GRAPH_BRIGHT_SPEED;
-- past GRAPH_FULL_SPEED the bar is blue instead, so the clamp is visible
-- rather than silently flat-topping.
local function BarStyle(speed)
    local fraction = speed / GRAPH_FULL_SPEED
    if fraction < GRAPH_MIN_FRACTION then
        return 0
    end
    if speed > GRAPH_FULL_SPEED then
        return GRAPH_HEIGHT, GRAPH_OVER_COLOR[1], GRAPH_OVER_COLOR[2], GRAPH_OVER_COLOR[3]
    end
    local height = math.floor(fraction * GRAPH_HEIGHT + 0.5)
    if height < 1 then height = 1 end
    local brightness = speed / GRAPH_BRIGHT_SPEED
    if brightness > 1 then brightness = 1 end
    local green = GRAPH_MIN_GREEN + (1 - GRAPH_MIN_GREEN) * brightness
    return height, 0, green, 0
end

-- Bars are created once, on first use, and only ever resized and recoloured
-- after that. pcall because console surfaces no Lua errors: if the virtual is
-- missing (XML failed to parse, say) the addon must degrade to the readout,
-- not die silently with its event handlers never registered.
local function EnsureBar(index)
    local bar = bars[index]
    if bar then return bar end
    local ok, created = pcall(WINDOW_MANAGER.CreateControlFromVirtual, WINDOW_MANAGER,
                              ADDON_NAME .. "Bar" .. index, graphPlot, "AreYouSlow_Bar")
    if not ok or not created then return nil end
    created:SetAnchor(BOTTOMLEFT, graphPlot, BOTTOMLEFT, (index - 1) * GRAPH_BAR_WIDTH, 0)
    bars[index] = created
    return created
end

local function RedrawGraph()
    -- Skipped while hidden (behind a menu, via the scene fragment); the next
    -- visible poll repaints everything, so at most 200 ms of staleness.
    if not graphPlot or graphControl:IsHidden() then return end
    for c = 1, GRAPH_SAMPLES do
        local bar = EnsureBar(c)
        if bar then
            local reading = ReadingForColumn(c)
            local height, r, g, b = 0
            if reading then
                height, r, g, b = BarStyle(reading)
            end
            if height > 0 then
                bar:SetDimensions(GRAPH_BAR_WIDTH, height)
                bar:SetColor(r, g, b, 1)
                bar:SetHidden(false)
            else
                bar:SetHidden(true)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Display mode
-- ---------------------------------------------------------------------------
local function ActiveMode()
    local mode = sv and sv.displayMode or MODE_READOUT
    if mode == MODE_GRAPH and not graphPlot then
        mode = MODE_READOUT    -- graph could not be built; the readout always exists
    end
    return mode
end

local function ApplyDisplayMode()
    local graphOn = ActiveMode() == MODE_GRAPH
    speedLabel:SetHidden(graphOn)
    if graphControl then
        graphControl:SetHidden(not graphOn)
    end
    if graphOn then
        RedrawGraph()
    else
        UpdateSpeedLabel()
    end
end

-- ---------------------------------------------------------------------------
-- Sampling
-- ---------------------------------------------------------------------------
-- Tracks all movement (on foot, swimming, mounted, etc.) rather than being
-- gated to a particular state -- this addon's whole purpose is a live
-- speed readout, not a mount-specific tool like its sibling.
--
-- A raw position delta from one zoneId is not safely comparable to a delta
-- from a different zoneId (confirmed via ESOUI forum thread 9251 -- the
-- world-to-map scale/offset is measured per zone and isn't even linear
-- within some zones). Requiring zoneId to match before computing a delta,
-- combined with the reset in OnPlayerActivated below, keeps every delta
-- this addon computes within a single zone and a single unbroken polling
-- run.
local function OnPositionPoll()
    local zoneId, x, y, z = GetUnitWorldPosition("player")
    local nowMs = GetGameTimeMilliseconds()
    local reading = false

    if lastTimeMs and zoneId == lastZoneId then
        local dtMs = nowMs - lastTimeMs
        if dtMs > 0 and dtMs <= MAX_PLAUSIBLE_DELTA_MS then
            local dx, dy, dz = x - lastX, y - lastY, z - lastZ
            reading = math.sqrt(dx * dx + dy * dy + dz * dz) * 1000 / dtMs   -- u/s
            smoothedSpeed = smoothedSpeed and (smoothedSpeed + SMOOTHING_ALPHA * (reading - smoothedSpeed)) or reading
        end
    end

    lastZoneId, lastX, lastY, lastZ, lastTimeMs = zoneId, x, y, z, nowMs

    PushReading(reading)
    if ActiveMode() == MODE_GRAPH then
        RedrawGraph()
    elseif reading then
        UpdateSpeedLabel()
    end
end

-- EVENT_PLAYER_ACTIVATED fires after every loading screen (initial login,
-- /reloadui, wayshrine travel, zone transfer). Clearing lastTimeMs here
-- means the very next poll just re-baselines position instead of computing
-- a delta across whatever the player's position was doing during the load
-- screen -- the same guard the sibling addon uses via ResetTracking. The
-- graph history is kept on purpose: the load screen shows up as a gap.
local function OnPlayerActivated()
    lastZoneId, lastX, lastY, lastZ, lastTimeMs = nil, nil, nil, nil, nil
end

-- ---------------------------------------------------------------------------
-- Controls
-- ---------------------------------------------------------------------------
-- Anchored to GuiRoot rather than any first-party ZOS element -- no
-- platform-specific control tree to worry about here (contrast the
-- sibling addon's mount stamina bar anchor, which does have to worry about
-- that). The one top-level control holds both displays; which is visible is
-- decided by ApplyDisplayMode.
local function CreateDisplay()
    local root = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "Display")
    root:SetDimensions(GRAPH_WIDTH, GRAPH_HEIGHT)
    root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 20, 20)

    -- The readout. Built with CreateControl rather than from a virtual because
    -- this exact code shipped in 1.0.0 and is known to work on console; the
    -- house preference for XML virtuals applies to the new controls below.
    local label = WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL)
    label:SetDimensions(200, 24)
    label:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
    -- Confirmed present in esoui/fontdefs/gamepad/defaultfontdefs_gamepad.xml
    -- (not keyboard-only) at API version 101051 (re-checked 2026-10-05) -- see
    -- this workspace's CLAUDE.md on why that check matters on console.
    label:SetFont("ZoFontGamepadBold20")
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_TOP)
    label:SetColor(1, 1, 0.4, 1)
    label:SetText("Speed: -- u/s")

    -- The graph. pcall for the same reason as EnsureBar: a missing virtual
    -- must cost the graph, not the addon.
    local graph, plot
    local ok, created = pcall(WINDOW_MANAGER.CreateControlFromVirtual, WINDOW_MANAGER,
                              ADDON_NAME .. "Graph", root, "AreYouSlow_Graph")
    if ok and created then
        graph = created
        graph:SetAnchorFill(root)
        graph:SetHidden(true)
        plot = graph:GetNamedChild("Plot")
        local mid = graph:GetNamedChild("Mid")
        if mid and plot then
            local y = math.floor(GRAPH_HEIGHT * GRAPH_MIDLINE_SPEED / GRAPH_FULL_SPEED + 0.5)
            mid:ClearAnchors()
            mid:SetAnchor(BOTTOMLEFT, plot, BOTTOMLEFT, 0, -y)
            mid:SetAnchor(BOTTOMRIGHT, plot, BOTTOMRIGHT, 0, -y)
        end
    end

    return root, label, graph, plot
end

-- ---------------------------------------------------------------------------
-- Settings menu (LibHarvensAddonSettings)
-- ---------------------------------------------------------------------------
-- Registered from EVENT_ADD_ON_LOADED because LHAS initialises lazily on the
-- first Main Menu show and snapshots its addon list then. allowRefresh is
-- deliberately absent: it is not LAM's registerForRefresh (LHAS re-reads
-- getters on panel show for free) and nothing here needs cross-control
-- refresh. The manifest declares a hard DependsOn, so the nil guard should be
-- unreachable; it is kept because the cost of being wrong on console is a
-- silently dead HUD, and the guard costs one line.
local function ResolveMode(itemName, itemData)
    if type(itemData) == "table" then itemData = itemData.data end
    if itemData ~= nil and MODE_NAME_BY_VALUE[itemData] then
        return itemData
    end
    return MODE_VALUE_BY_NAME[itemName] or MODE_READOUT
end

local function CreateSettingsMenu()
    local LHAS = LibHarvensAddonSettings
    if not LHAS then
        d("[" .. ADDON_TITLE .. "] LibHarvensAddonSettings is missing; the settings menu is unavailable.")
        return
    end

    local panel = LHAS:AddAddon(ADDON_TITLE, { allowDefaults = true })
    if not panel then return end
    -- Shown in the console header; LHAS reads but never sets these.
    panel.version = ADDON_VERSION
    panel.author  = ADDON_AUTHOR

    panel:AddSettings({
        {
            type  = LHAS.ST_LABEL,
            label = "Speed is in raw world units per second (u/s). Both displays hide while a menu is open.",
        },
        {
            type    = LHAS.ST_DROPDOWN,
            label   = "Display",
            tooltip = "Smoothed readout: one number, your current speed smoothed over roughly the last second so it holds steady. "
                   .. "Speed graph: a bar for every reading over the last 30 seconds, oldest on the left, using the raw readings rather than the smoothed value. "
                   .. "Bars scale from 0 to 2000 u/s with a line at 1000; the green brightens with speed and a bar turns blue if you go over 2000 u/s. Default: Smoothed readout.",
            items   = MODE_ITEMS,
            default = MODE_NAME_BY_VALUE[MODE_READOUT],   -- the item NAME, which is what ResetToDefaults matches on
            getFunction = function()
                return MODE_NAME_BY_VALUE[ActiveMode()]
            end,
            setFunction = function(control, itemName, itemData)
                sv.displayMode = ResolveMode(itemName, itemData)
                ApplyDisplayMode()
            end,
        },
    })
end

-- ---------------------------------------------------------------------------
-- Startup
-- ---------------------------------------------------------------------------
local function OnAddOnLoaded(_, addOnName)
    if addOnName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- Must be constructed inside EVENT_ADD_ON_LOADED or it never persists
    -- (documented in zo_savedvars.lua).
    sv = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, SAVED_VARS_VERSION, nil, DEFAULTS)
    if not MODE_NAME_BY_VALUE[sv.displayMode] then
        sv.displayMode = MODE_READOUT
    end

    rootControl, speedLabel, graphControl, graphPlot = CreateDisplay()

    -- Hide whenever a menu (inventory, map, character sheet, crafting,
    -- etc.) is open. HUD_SCENE and HUD_UI_SCENE are ZOS's own "actually in
    -- the world, no blocking menu open" scenes (confirmed via
    -- esoui/ingame/scenes/hudscene.lua) -- wrapping the control in a
    -- ZO_SimpleSceneFragment and adding it to both is the same mechanism
    -- the game's own compass/action bar/equipment status HUD elements use
    -- (see HUD_FRAGMENT_GROUP in that same file), rather than tracking
    -- every individual menu-open event by hand. Neither global is
    -- keyboard/gamepad split, so this is safe on console too.
    local speedFragment = ZO_SimpleSceneFragment:New(rootControl)
    HUD_SCENE:AddFragment(speedFragment)
    HUD_UI_SCENE:AddFragment(speedFragment)

    ApplyDisplayMode()
    CreateSettingsMenu()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "Poll", POLL_MS, OnPositionPoll)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
