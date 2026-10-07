local ADDON_NAME    = "DoesThisThingGoAnyFaster"
local ADDON_TITLE   = "Does This Thing Go Any Faster?"
local ADDON_AUTHOR  = "Th3rtythr33"
local ADDON_VERSION = "1.12.0"   -- keep in step with ## Version in the manifest

-- ESO has no direct "is sprinting" query or raw speed function, and the
-- obvious alternative -- watching stamina-cost combat events
-- (ACTION_RESULT_SPRINTING) -- doesn't work here: the "War Mount" Champion
-- Point passive removes mount stamina drain entirely while out of combat,
-- so no cost event ever fires in exactly the situation this addon is for.
-- Confirmed there's no better native signal either: no IsUnitSprinting-style
-- query exists, ZOS's own UI has no live "sprinting" hook to piggyback on,
-- and the sprint keybind (both keyboard and gamepad) dispatches straight
-- from raw input into a private engine function with no public event
-- anywhere in the chain -- not even a keypress event exists for this.
-- Position sampling is genuinely the only signal available.
--
-- Earlier versions tried to detect sprint automatically via an adaptive
-- EMA "cruise speed" baseline and a fixed ratio threshold (e.g. "1.13x
-- baseline = sprinting"). That approach went through three rounds of bugs
-- (acceleration-ramp false triggers, baseline convergence lag, and finally
-- discovering the real sprint/cruise ratio isn't even consistent between
-- characters -- it depends on each character's own speed bonuses, not just
-- the zone) before concluding a universal ratio can't work for "any player
-- on any character," which is what this addon is meant to support.
--
-- Current approach: explicit per-zone calibration, auto-triggered rather
-- than requiring the player to type /speedcal. The moment the player
-- mounts in a zone with no stored ceiling yet, calibration ARMS (chat
-- message shown) but doesn't start ticking yet -- it stays paused until
-- the player actually starts moving, so the full window is spent riding
-- rather than partly wasted while stationary. Once moving, the highest
-- smoothed speed seen over CALIBRATION_DURATION_MS is stored (in
-- SavedVariables, per character) as "the ceiling of normal riding" for
-- that zone. From then on in that zone, any reading above the stored
-- ceiling is treated as sprinting. This is simpler and more robust than
-- the old adaptive-ratio approach: it needs no convergence period (the
-- measurement is complete and exact the moment calibration ends), and it's
-- automatically correct for this specific character's speed bonuses, since
-- they were live when the measurement was taken. /speedcal is still
-- available too, as a manual override to force a fresh recalibration of the
-- current zone (e.g. after a build change shifts the character's own speed
-- bonuses enough that the old ceiling stops being accurate) -- it arms the
-- same way, still paused until movement starts, rather than starting the
-- clock immediately.
--
-- A note on units (2026-10-06): world positions are in CENTIMETRES in every
-- zone (ZOS's housing code and LibGPS both convert them to metres with a
-- constant /100), so the per-zone key above is not actually needed for unit
-- reasons -- see Docs/DoesThisThingGoAnyFaster.md, "Units and the per-zone
-- key". It is kept for now; collapsing to one ceiling per character is a
-- planned change. The same-zone check in OnPositionPoll IS still needed,
-- because GetUnitWorldPosition is zone-local and a delta across a zone
-- change is a position jump, not a speed.
local POLL_MS = 200                    -- how often to sample position
local FAST_ALPHA = 0.3                  -- smoothing for the displayed/compared speed
local MAX_PLAUSIBLE_DELTA_MS = 1000     -- ignore samples spanning a hitch/loading pause
local CALIBRATION_DURATION_MS = 8000    -- how long /speedcal watches before locking in a ceiling

-- ---------------------------------------------------------------------------
-- Display settings
-- ---------------------------------------------------------------------------
-- What the indicator says while sprinting. The defaults reproduce 1.11.0
-- exactly: "WEEEE!" on the bar and the bar fill in gold. "No added text"
-- leaves only the gold (if that is on) as the cue.
--
-- LHAS dropdown items MUST be {name=, data=} tables on console: the gamepad
-- horizontal list reads data.name when an entry is chosen, and its equality
-- function compares getFunction's return value against item.name. Plain
-- strings do not survive that path. Confirmed in LibHarvensAddonSettings
-- 2.2.0, Console/Settings.lua (see AreYouSlow for the same contract).
local TEXT_SPRINTING = "SPRINTING"
local TEXT_WEEEE     = "WEEEE!"
local TEXT_NONE      = ""
local TEXT_ITEMS = {
    { name = "SPRINTING",     data = TEXT_SPRINTING },
    { name = "WEEEE!",        data = TEXT_WEEEE },
    { name = "No added text", data = TEXT_NONE },
}
local TEXT_NAME_BY_VALUE, TEXT_VALUE_BY_NAME = {}, {}
for _, item in ipairs(TEXT_ITEMS) do
    TEXT_NAME_BY_VALUE[item.data] = item.name
    TEXT_VALUE_BY_NAME[item.name] = item.data
end

local GOLD_GRADIENT = { 1, 0.82, 0.15, 1, 0.95, 0.6, 0.05, 1 }

-- ---------------------------------------------------------------------------
-- Enthusiasm mode
-- ---------------------------------------------------------------------------
-- A hidden setting (no row in the settings menu) toggled by /ohyesitdoes.
-- While on, every sprint splashes "WEEEEEE!" with a random number of E's at
-- a random size, position and colour all over the screen, each one fading
-- and drifting upward before it is recycled. Pure celebration; nothing here
-- affects detection.
--
-- The command key is lowercase on purpose: ZOS's DoCommand
-- (esoui/ingame/slashcommands/slashcommands_shared.lua) runs the typed
-- command through zo_strlower before the SLASH_COMMANDS lookup, so a
-- mixed-case key would never match. Typing /OhYesItDoes works because of
-- that same lowercasing.
local ENTHUSIASM_COMMAND       = "/ohyesitdoes"
local ENTHUSIASM_TICK_MS       = 50       -- animation tick while splashing
local ENTHUSIASM_SPAWN_MIN_MS  = 120      -- time between new splashes...
local ENTHUSIASM_SPAWN_MAX_MS  = 260      -- ...picked at random in this range
local ENTHUSIASM_LIFE_MIN_MS   = 900      -- how long one splash lives...
local ENTHUSIASM_LIFE_MAX_MS   = 1600     -- ...picked at random in this range
local ENTHUSIASM_MIN_ES        = 3        -- "WEEE!" at the least...
local ENTHUSIASM_MAX_ES        = 14       -- ..."WEEEEEEEEEEEEEE!" at the most
local ENTHUSIASM_POOL          = 14       -- labels are recycled; never more than this many exist
local ENTHUSIASM_RISE_PX       = 60       -- upward drift over a splash's life
local ENTHUSIASM_MARGIN        = 0.1      -- fraction of the screen kept clear at each edge
-- The whole gamepad bold ladder, so sizes vary from "small" to "very".
-- Every name confirmed in esoui/fontdefs/gamepad/defaultfontdefs_gamepad.xml
-- on the live branch at API 101051 (2026-10-06); SetFont is pcall-wrapped
-- regardless so a future ladder change costs a size, not the feature.
local ENTHUSIASM_FONTS = {
    "ZoFontGamepadBold18", "ZoFontGamepadBold20", "ZoFontGamepadBold22",
    "ZoFontGamepadBold25", "ZoFontGamepadBold27", "ZoFontGamepadBold34",
    "ZoFontGamepadBold42", "ZoFontGamepadBold48", "ZoFontGamepadBold54",
}
local ENTHUSIASM_COLORS = {
    { 0.4, 1, 0.4 },        -- the indicator's green
    { 1, 0.82, 0.15 },      -- the bar's gold
    { 1, 1, 1 },            -- white
    { 0.4, 0.9, 1 },        -- sky blue
}

-- Must match ## SavedVariables in the manifest exactly. One table, two
-- stores: calibration ceilings are per character (they depend on the
-- character's own speed bonuses); how the indicator looks is a taste, so it
-- is account-wide under its own namespace.
local SAVED_VARS_NAME    = "DoesThisThingGoAnyFasterSaved"
local SAVED_VARS_VERSION = 1
local CALIBRATION_DEFAULTS = { thresholds = {} }
local DISPLAY_NAMESPACE    = "Display"
local DISPLAY_DEFAULTS     = { labelText = TEXT_WEEEE, goldBar = true, enthusiasmMode = false }

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
local isMounted = false
local sprintActive = false
local mountStaminaIndicator
local mountStaminaLabel
local mountStaminaBar
local mountStaminaOriginalGradient  -- snapshotted once at load; nil if that wasn't possible (see SnapshotMountStaminaGradient)
local savedVars                     -- per-character: calibration ceilings
local displayVars                   -- account-wide: labelText, goldBar, enthusiasmMode

local enthusiasmRoot                -- full-screen parent for the splashes; nil if it could not be created
local splashes = {}                 -- pool of { label=, bornMs=, lifeMs=, x=, y= }; bornMs == nil means free
local enthusiasmActive = false      -- the tick is registered and splashes are being spawned
local nextSpawnMs = 0

local lastZoneId, lastX, lastY, lastZ, lastTimeMs
local fastSpeed

local calibrating = false       -- 8s window actively running (timer + peak-tracking)
local calibrationArmed = false  -- waiting for the player to start moving before the timer begins
local calibrationEndMs = 0
local calibrationPeakSpeed = 0

-- ---------------------------------------------------------------------------
-- Indicator
-- ---------------------------------------------------------------------------
-- Small secondary indicator anchored to the game's own mount stamina bar,
-- so there's something to glance at right where the player's eyes already
-- are while riding. Only ever visible while actually sprinting -- silent
-- otherwise, since it's meant to augment a HUD element the player's
-- already watching, not add noise to it.
--
-- Alongside the text, the bar's own fill color also switches to gold while
-- sprinting. ZOS colors these bars via SetGradientColors (a start/end RGBA
-- pair), set once at initial setup rather than refreshed per-frame or tied
-- to the current stamina value (confirmed via ZO_PlayerAttributeBar:
-- RefreshColor in the live source, called exactly once, at construction)
-- -- so our own SetGradientColors call won't get fought or overwritten by
-- the game re-asserting its own color on some later tick.
--
-- If the original gradient could not be snapshotted at load, the bar is
-- left alone entirely: never turned gold, never "restored". A gold bar we
-- cannot put back would be worse than no gold bar. (An earlier build fell
-- back to ClearGradientColors(), which StatusBarControl does not have.)
--
-- Only written on a transition. This runs every poll, and 1.11.0 re-applied
-- the gradient five times a second; harmless, but it also meant the bar was
-- written at load before any sprint. Now the first write is the first sprint.
local barIsGold = false
local function ApplyMountStaminaBarColor(gold)
    if not mountStaminaBar or not mountStaminaOriginalGradient then
        return
    end

    gold = gold and true or false
    if gold == barIsGold then
        return
    end
    barIsGold = gold

    local g = gold and GOLD_GRADIENT or mountStaminaOriginalGradient
    mountStaminaBar:SetGradientColors(g[1], g[2], g[3], g[4], g[5], g[6], g[7], g[8])
end

-- ---------------------------------------------------------------------------
-- Enthusiasm splashes
-- ---------------------------------------------------------------------------
local function RandomBetween(lo, hi)
    return lo + math.random() * (hi - lo)
end

local function RandomWeee()
    return "W" .. string.rep("E", math.random(ENTHUSIASM_MIN_ES, ENTHUSIASM_MAX_ES)) .. "!"
end

-- Finds a free pool slot, creating one if the pool is not yet full. Returns
-- nil when every slot is busy, which just means this spawn is skipped.
local function AcquireSplash()
    for _, s in ipairs(splashes) do
        if not s.bornMs then return s end
    end
    if #splashes >= ENTHUSIASM_POOL then return nil end

    local ok, label = pcall(WINDOW_MANAGER.CreateControl, WINDOW_MANAGER, nil, enthusiasmRoot, CT_LABEL)
    if not ok or not label then return nil end
    label:SetDimensions(800, 80)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetHidden(true)

    local s = { label = label }
    splashes[#splashes + 1] = s
    return s
end

local function PlaceSplash(s, progress)
    s.label:ClearAnchors()
    s.label:SetAnchor(CENTER, GuiRoot, TOPLEFT, s.x, s.y - ENTHUSIASM_RISE_PX * progress)
end

local function SpawnSplash(nowMs)
    local w, h = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    if not w or not h or w <= 0 or h <= 0 then return end

    local s = AcquireSplash()
    if not s then return end

    s.bornMs = nowMs
    s.lifeMs = RandomBetween(ENTHUSIASM_LIFE_MIN_MS, ENTHUSIASM_LIFE_MAX_MS)
    s.x = RandomBetween(w * ENTHUSIASM_MARGIN, w * (1 - ENTHUSIASM_MARGIN))
    s.y = RandomBetween(h * ENTHUSIASM_MARGIN, h * (1 - ENTHUSIASM_MARGIN))

    local font = ENTHUSIASM_FONTS[math.random(#ENTHUSIASM_FONTS)]
    if not pcall(s.label.SetFont, s.label, font) then
        pcall(s.label.SetFont, s.label, ENTHUSIASM_FONTS[1])
    end
    local c = ENTHUSIASM_COLORS[math.random(#ENTHUSIASM_COLORS)]
    s.label:SetColor(c[1], c[2], c[3], 1)
    s.label:SetText(RandomWeee())
    s.label:SetAlpha(1)
    PlaceSplash(s, 0)
    s.label:SetHidden(false)
end

local function RetireSplash(s)
    s.bornMs = nil
    s.label:SetHidden(true)
end

local function EnthusiasmTick()
    local nowMs = GetGameTimeMilliseconds()

    if nowMs >= nextSpawnMs then
        SpawnSplash(nowMs)
        nextSpawnMs = nowMs + RandomBetween(ENTHUSIASM_SPAWN_MIN_MS, ENTHUSIASM_SPAWN_MAX_MS)
    end

    for _, s in ipairs(splashes) do
        if s.bornMs then
            local progress = (nowMs - s.bornMs) / s.lifeMs
            if progress >= 1 then
                RetireSplash(s)
            else
                s.label:SetAlpha(1 - progress)
                PlaceSplash(s, progress)
            end
        end
    end
end

-- Starts or stops the splash tick. The tick only exists while sprinting with
-- the mode on, so an idle addon costs nothing extra. Root visibility is left
-- to the HUD scene fragment (see OnAddOnLoaded); this only governs the labels.
local function SetEnthusiasmActive(active)
    active = active and enthusiasmRoot ~= nil
    if active == enthusiasmActive then return end
    enthusiasmActive = active

    if active then
        nextSpawnMs = GetGameTimeMilliseconds()   -- first splash on the first tick
        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "Enthusiasm", ENTHUSIASM_TICK_MS, EnthusiasmTick)
    else
        EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "Enthusiasm")
        for _, s in ipairs(splashes) do
            if s.bornMs then RetireSplash(s) end
        end
    end
end

local function UpdateMountStaminaIndicator()
    local sprinting = isMounted and sprintActive
    local showText = sprinting and displayVars.labelText ~= TEXT_NONE
    mountStaminaIndicator:SetHidden(not showText)
    ApplyMountStaminaBarColor(sprinting and displayVars.goldBar)
    SetEnthusiasmActive(sprinting and displayVars.enthusiasmMode)
end

local function ApplyLabelText()
    mountStaminaLabel:SetText(displayVars.labelText)
    UpdateMountStaminaIndicator()
end

-- ---------------------------------------------------------------------------
-- Calibration
-- ---------------------------------------------------------------------------
local function ResetTracking()
    lastZoneId, lastX, lastY, lastZ, lastTimeMs = nil, nil, nil, nil, nil
    fastSpeed = nil
    sprintActive = false
    -- Clears a pending arm-but-never-moved attempt on every mount/dismount
    -- so it can't dangle across an unrelated later mount in a different
    -- zone and wrongly suppress that zone's own arm check. Deliberately
    -- doesn't touch `calibrating` -- an already-*running* window keeps
    -- running through a dismount, same as before this change.
    calibrationArmed = false
end

-- Arms calibration -- fires automatically on mount (see OnMountedStateChanged)
-- or manually via /speedcal; either way it doesn't start the 8s window
-- immediately. It stays paused (calibrationArmed) until OnPositionPoll
-- sees actual movement, so the whole window is spent riding rather than
-- partly wasted while stationary. Only measures the non-sprint ceiling --
-- the player is explicitly asked not to sprint, so there's nothing to
-- measure on the sprint side here; detection afterward is purely "did the
-- reading exceed the measured ceiling."
local function ArmCalibration(isAutomatic)
    if not IsMounted() then
        d("DoesThisThingGoAnyFaster: mount up first, then run /speedcal again.")
        return
    end

    if calibrating or calibrationArmed then
        return
    end

    if isAutomatic then
        d("DoesThisThingGoAnyFaster: no calibration data for this zone -- ride without sprinting for at least " ..
            (CALIBRATION_DURATION_MS / 1000) .. " seconds to calibrate. Calibration begins automatically as soon as you start moving.")
    else
        d("DoesThisThingGoAnyFaster: ride without sprinting for at least " .. (CALIBRATION_DURATION_MS / 1000) ..
            " seconds to calibrate. Calibration begins as soon as you start moving.")
    end

    calibrationArmed = true
end

local function FinishCalibration(zoneId)
    calibrating = false

    if calibrationPeakSpeed <= 0 then
        d("DoesThisThingGoAnyFaster: calibration failed -- no movement detected. Make sure you're mounted and moving, then try /speedcal again.")
        return
    end

    savedVars.thresholds[zoneId] = calibrationPeakSpeed
    local zoneName = GetPlayerActiveZoneName()
    d(string.format("DoesThisThingGoAnyFaster: calibration complete for %s. Non-sprint ceiling: %du/s -- anything faster than that now counts as sprinting here. Run /speedcal to calibrate again.",
        zoneName, math.floor(calibrationPeakSpeed * 1000 + 0.5)))
end

-- ---------------------------------------------------------------------------
-- Sampling
-- ---------------------------------------------------------------------------
local function OnPositionPoll()
    local zoneId, x, y, z = GetUnitWorldPosition("player")
    local nowMs = GetGameTimeMilliseconds()

    if lastTimeMs and zoneId == lastZoneId then
        local dtMs = nowMs - lastTimeMs
        if dtMs > 0 and dtMs <= MAX_PLAUSIBLE_DELTA_MS then
            local dx, dy, dz = x - lastX, y - lastY, z - lastZ
            local instSpeed = math.sqrt(dx * dx + dy * dy + dz * dz) / dtMs

            fastSpeed = fastSpeed and (fastSpeed + FAST_ALPHA * (instSpeed - fastSpeed)) or instSpeed

            if calibrating then
                calibrationPeakSpeed = math.max(calibrationPeakSpeed, fastSpeed)
                if nowMs >= calibrationEndMs then
                    FinishCalibration(zoneId)
                end
            elseif calibrationArmed and fastSpeed > 0 then
                -- Movement just started -- actually begin the window now,
                -- rather than back when it armed, so it's not spent partly
                -- stationary.
                calibrationArmed = false
                calibrating = true
                calibrationPeakSpeed = fastSpeed
                calibrationEndMs = nowMs + CALIBRATION_DURATION_MS
            end

            local ceiling = savedVars.thresholds[zoneId]
            sprintActive = ceiling ~= nil and fastSpeed > ceiling

            UpdateMountStaminaIndicator()
        end
    end

    lastZoneId, lastX, lastY, lastZ, lastTimeMs = zoneId, x, y, z, nowMs
end

local function OnMountedStateChanged(_, mounted)
    isMounted = mounted
    ResetTracking()

    if mounted then
        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "Poll", POLL_MS, OnPositionPoll)
    else
        EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "Poll")
    end

    -- Auto-calibration trigger: arm it right at the mount moment if the
    -- zone the player is standing in has no ceiling yet. Reads position
    -- directly rather than waiting on OnPositionPoll, since this should
    -- fire as soon as the player mounts, not after the next poll happens
    -- to land.
    if mounted then
        local zoneId = GetUnitWorldPosition("player")
        if savedVars.thresholds[zoneId] == nil then
            ArmCalibration(true)
        end
    end

    UpdateMountStaminaIndicator()
end

local function OnPlayerActivated()
    OnMountedStateChanged(nil, IsMounted())
end

-- ---------------------------------------------------------------------------
-- Controls
-- ---------------------------------------------------------------------------
-- ZOS builds ZO_POWER_BAR_GRADIENT_COLORS (esoui/libraries/globals/
-- defaultcolordefs.lua) from GetInterfaceColor(INTERFACE_COLOR_TYPE_POWER_START
-- / _END, powerType) and applies it with SetGradientColors once, at
-- construction. Reading the same two natives directly gives the identical
-- colours without depending on a ZOS Lua table. Wrapped in pcall so a wrong
-- guess here can't throw and take down anything else in OnAddOnLoaded; on
-- any failure this returns nil and ApplyMountStaminaBarColor leaves the bar
-- alone entirely.
local function SnapshotMountStaminaGradient()
    local success, result = pcall(function()
        local r, g, b, a = GetInterfaceColor(INTERFACE_COLOR_TYPE_POWER_START, COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA)
        local r2, g2, b2, a2 = GetInterfaceColor(INTERFACE_COLOR_TYPE_POWER_END, COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA)
        assert(type(r) == "number" and type(a) == "number" and type(r2) == "number" and type(a2) == "number")
        return { r, g, b, a, r2, g2, b2, a2 }
    end)
    if success then
        return result
    end
    return nil
end

-- Anchored to ZOS's own mount stamina bar (ZO_PlayerAttribute's "MountStamina"
-- named child -- confirmed via the live esoui source: a single, unified
-- control tree for both keyboard and gamepad, just with a different visual
-- template applied per platform, not a separate copy per mode). This is a
-- first-party UI element, not a documented addon-facing API, so it's worth
-- knowing this is a little more fragile than anchoring to GuiRoot -- if ZOS
-- ever restructures the player attribute bars, this anchor could break. That
-- said, health/magicka/stamina bars are about as stable a piece of UI as ESO
-- has, essentially unchanged since launch, so this is a low-risk bet, not a
-- reckless one. The bar itself is only 12px tall (ZO_PlayerAttributeContainerSmall),
-- hence the small font and hidden-unless-sprinting text instead of a
-- persistent readout -- there's no room for that here, and it would clash
-- visually with a HUD element the player didn't ask to have decorated.
local function CreateMountStaminaIndicator()
    local anchorTarget = ZO_PlayerAttribute:GetNamedChild("MountStamina")
    mountStaminaBar = anchorTarget:GetNamedChild("Bar")
    mountStaminaOriginalGradient = SnapshotMountStaminaGradient()

    local control = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "MountStaminaIndicator")
    control:SetDimensions(120, 16)
    control:SetAnchor(CENTER, anchorTarget, CENTER, 0, 0)
    control:SetHidden(true)

    local label = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    label:SetAnchorFill(control)
    -- Confirmed present in esoui/fontdefs/gamepad/defaultfontdefs_gamepad.xml
    -- at API 101051 (re-checked 2026-10-06); see CLAUDE.md on why a gamepad
    -- font is mandatory on console.
    label:SetFont("ZoFontGamepadBold18")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(0.4, 1, 0.4, 1)

    return control, label
end

-- Full-screen, click-through parent for the splashes, anchored to GuiRoot.
-- Wrapped in pcall: if it cannot be made, enthusiasm mode silently never
-- activates and everything else is unaffected.
local function CreateEnthusiasmRoot()
    local ok, control = pcall(function()
        local c = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "Enthusiasm")
        c:SetAnchorFill(GuiRoot)
        return c
    end)
    if ok then return control end
    return nil
end

-- ---------------------------------------------------------------------------
-- Settings menu (LibHarvensAddonSettings, optional)
-- ---------------------------------------------------------------------------
-- The library is OptionalDependsOn: without it the addon runs on the
-- defaults, which are exactly 1.11.0's behaviour, and says nothing about it
-- (a player who chose not to install the library does not need a chat line
-- every login). Registered from EVENT_ADD_ON_LOADED because LHAS initialises
-- lazily on the first Main Menu show and snapshots its addon list then.
-- allowRefresh is deliberately absent: it is not LAM's registerForRefresh and
-- nothing here needs cross-control refresh.
local function ResolveLabelText(itemName, itemData)
    if type(itemData) == "table" then itemData = itemData.data end
    if itemData ~= nil and TEXT_NAME_BY_VALUE[itemData] then
        return itemData
    end
    return TEXT_VALUE_BY_NAME[itemName] or TEXT_WEEEE
end

local function CreateSettingsMenu()
    local LHAS = LibHarvensAddonSettings
    if not LHAS then return end

    local panel = LHAS:AddAddon(ADDON_TITLE, { allowDefaults = true })
    if not panel then return end
    -- Shown in the console header; LHAS reads but never sets these.
    panel.version = ADDON_VERSION
    panel.author  = ADDON_AUTHOR

    panel:AddSettings({
        {
            type  = LHAS.ST_LABEL,
            label = "The indicator sits on your mount stamina bar and only appears while your mount is sprinting. "
                 .. "Type /speedcal in chat to recalibrate the current zone.",
        },
        {
            type    = LHAS.ST_DROPDOWN,
            label   = "Sprint text",
            tooltip = "The text shown on the mount stamina bar while sprinting. "
                   .. "No added text leaves only the gold bar (if that is on) as the cue. Default: WEEEE!",
            items   = TEXT_ITEMS,
            default = TEXT_NAME_BY_VALUE[TEXT_WEEEE],   -- the item NAME, which is what ResetToDefaults matches on
            getFunction = function()
                return TEXT_NAME_BY_VALUE[displayVars.labelText]
            end,
            setFunction = function(control, itemName, itemData)
                displayVars.labelText = ResolveLabelText(itemName, itemData)
                ApplyLabelText()
            end,
        },
        {
            type    = LHAS.ST_CHECKBOX,
            label   = "Turn the mount stamina bar gold while sprinting",
            tooltip = "Recolours the fill of the game's own mount stamina bar gold while your mount is sprinting, "
                   .. "and puts the normal colour back the moment you slow down. Default: on.",
            default = DISPLAY_DEFAULTS.goldBar,
            getFunction = function() return displayVars.goldBar end,
            setFunction = function(value)
                displayVars.goldBar = value and true or false
                UpdateMountStaminaIndicator()
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

    -- Both stores must be created here (in EVENT_ADD_ON_LOADED) for the
    -- saved file to persist correctly (documented in zo_savedvars.lua).
    savedVars   = ZO_SavedVars:New(SAVED_VARS_NAME, SAVED_VARS_VERSION, nil, CALIBRATION_DEFAULTS)
    displayVars = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, SAVED_VARS_VERSION, DISPLAY_NAMESPACE, DISPLAY_DEFAULTS)
    if not TEXT_NAME_BY_VALUE[displayVars.labelText] then
        displayVars.labelText = TEXT_WEEEE
    end
    if type(displayVars.goldBar) ~= "boolean" then
        displayVars.goldBar = DISPLAY_DEFAULTS.goldBar
    end
    if type(displayVars.enthusiasmMode) ~= "boolean" then
        displayVars.enthusiasmMode = DISPLAY_DEFAULTS.enthusiasmMode
    end

    mountStaminaIndicator, mountStaminaLabel = CreateMountStaminaIndicator()

    -- The splash parent hides whenever a menu is open: HUD_SCENE and
    -- HUD_UI_SCENE are ZOS's own "in the world, no blocking menu" scenes
    -- (esoui/ingame/scenes/hudscene.lua), and a ZO_SimpleSceneFragment in
    -- both is the same mechanism the game's HUD elements use. Neither global
    -- is keyboard/gamepad split, so this is console-safe (AreYouSlow ships it).
    enthusiasmRoot = CreateEnthusiasmRoot()
    if enthusiasmRoot then
        local fragment = ZO_SimpleSceneFragment:New(enthusiasmRoot)
        HUD_SCENE:AddFragment(fragment)
        HUD_UI_SCENE:AddFragment(fragment)
    end

    ApplyLabelText()
    CreateSettingsMenu()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_MOUNTED_STATE_CHANGED, OnMountedStateChanged)

    SLASH_COMMANDS["/speedcal"] = function() ArmCalibration(false) end
    SLASH_COMMANDS[ENTHUSIASM_COMMAND] = function()
        displayVars.enthusiasmMode = not displayVars.enthusiasmMode
        if displayVars.enthusiasmMode then
            d("DoesThisThingGoAnyFaster: enthusiasm mode ON. Oh yes it does.")
        else
            d("DoesThisThingGoAnyFaster: enthusiasm mode off.")
        end
        UpdateMountStaminaIndicator()
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
