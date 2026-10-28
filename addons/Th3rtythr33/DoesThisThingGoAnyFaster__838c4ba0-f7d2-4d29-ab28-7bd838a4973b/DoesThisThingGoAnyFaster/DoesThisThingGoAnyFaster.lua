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
-- Current approach: one calibrated ceiling per character, auto-triggered
-- rather than requiring the player to type /speedcal. The moment a character
-- with no stored ceiling mounts, calibration ARMS (chat message shown) but
-- doesn't start ticking yet -- it stays paused until the player actually
-- starts moving, so the full window is spent riding rather than partly
-- wasted while stationary. Once moving, the highest smoothed speed seen over
-- CALIBRATION_DURATION_MS is stored (in SavedVariables, per character) as
-- "the ceiling of normal riding". From then on, in every zone, a reading more
-- than SPRINT_MARGIN above it is treated as sprinting. It needs no
-- convergence period (the measurement is complete the moment calibration
-- ends), and it's automatically correct for this character's speed bonuses,
-- since they were live when the measurement was taken. /speedcal is still
-- available as a manual override, e.g. after a build change shifts the
-- character's speed bonuses enough that the old ceiling stops being accurate.
--
-- Until 1.12.0 the ceiling was stored PER ZONE. That rested on a belief that
-- world units differ in size between zones, which turned out to be a
-- misreading of LibGPS: world positions are in CENTIMETRES in every zone
-- (ZOS's housing code and LibGPS both convert them to metres with a constant
-- /100). See Docs/DoesThisThingGoAnyFaster.md, "Units and the per-zone key".
-- The old per-zone table is discarded on load. The same-zone check in
-- OnPositionPoll IS still needed, because GetUnitWorldPosition is zone-local
-- and a delta across a zone change is a position jump, not a speed.
--
-- Experimental (2026-10-27): with "Auto Calibration (Experimental)" on, the addon
-- also watches steady riding and looks for TWO distinct speeds in it, normal
-- and sprinting, then puts the line halfway between them. See the learner
-- section below for how and why it does not assume a fixed ratio.
local POLL_MS = 200                    -- how often to sample position
local FAST_ALPHA = 0.3                  -- smoothing for the displayed/compared speed
local MAX_PLAUSIBLE_DELTA_MS = 1000     -- ignore samples spanning a hitch/loading pause
local CALIBRATION_DURATION_MS = 8000    -- how long /speedcal watches before locking in a ceiling

-- Sprint margin (2026-10-21). The stored ceiling is the PEAK smoothed speed
-- seen while riding normally, so normal riding afterwards sits right at it
-- and ordinary jitter pushed readings over the line: false "sprinting"
-- flickers in play. A reading now has to beat the ceiling by this much
-- before it counts. Applied at detection time, not baked into the stored
-- ceiling, so every calibration already saved gets it and raising it later
-- needs no recalibration. Speeds are kept in u/ms internally (world units
-- are centimetres, so 5 u/s is 5 cm/s, about half a percent of a gallop).
local SPRINT_MARGIN_UPS = 5                      -- u/s above the ceiling
local SPRINT_MARGIN     = SPRINT_MARGIN_UPS / 1000   -- the same, in u/ms

-- ---------------------------------------------------------------------------
-- Auto Calibration (experimental)
-- ---------------------------------------------------------------------------
-- There is no API for mounted sprint speed: GetRidingStats reports only the
-- riding-training percentage, and ADVANCED_STAT_DISPLAY_TYPE_SPRINT_SPEED is
-- an on-foot stat (ESOUIDocumentation.txt, 101051). And the sprint/normal
-- ratio is NOT a constant -- it differs per character with their speed
-- bonuses, which is what killed the adaptive-ratio approach before 1.11.0.
-- So the learner does not look for "normal x some ratio". It looks for two
-- separate clusters of STEADY speeds in recent riding and only accepts them
-- if they look like two genuinely different speeds:
--
--   * steady = the raw reading is within LEARN_STEADY_TOLERANCE of the
--     smoothed one, which drops acceleration ramps, turns and bumps;
--   * the best two-way split of the steady speeds (Otsu's method: the split
--     that pulls the two groups' averages furthest apart) is accepted only if
--     each side has LEARN_MIN_CLASS samples, the faster average is between
--     LEARN_MIN_RATIO and LEARN_MAX_RATIO times the slower, and the two
--     averages sit at least LEARN_SEPARATION spreads apart. That last test
--     is what rejects one wide cluster (rough terrain at one speed) split in
--     half, which would otherwise pass the ratio test: split down the middle,
--     a bell curve gives about 2.7 spreads, an even spread about 3.5, and a
--     slow smooth swell between two speeds about 4.1. Real cruise and sprint
--     clusters 13% apart pass at 5 as long as each is steadier than about
--     2.3%, which the steady filter is there to ensure.
--
-- The ratio band is a sanity gate, not a prediction. 1.08 sits under the
-- smallest ratio ever tuned in this addon's history (about 1.13) and 1.6 is
-- comfortably above any plausible sprint bonus; both are guesses to revisit
-- from what Auto Calibration reports in chat.
--
-- The detection line is the midpoint of the two averages. Learned values are
-- per character, kept across sessions, and keep updating as you ride.
local LEARN_BUFFER_SIZE      = 600     -- steady samples kept: 2 min of steady riding at 200 ms
local LEARN_ANALYSE_EVERY    = 25      -- re-analyse after this many new steady samples (5 s)
local LEARN_MIN_SAMPLES      = 100     -- no analysis before 20 s of steady riding
local LEARN_MIN_CLASS        = 25      -- each speed needs 5 s of steady riding in the buffer
local LEARN_STEADY_TOLERANCE = 0.03    -- raw within 3% of smoothed counts as steady
local LEARN_MIN_SPEED        = 0.1     -- u/ms (100 u/s); slower is standing or creeping
local LEARN_MIN_RATIO        = 1.08
local LEARN_MAX_RATIO        = 1.6
local LEARN_SEPARATION       = 5       -- averages must be this many spreads apart
local LEARN_REPORT_CHANGE    = 0.03    -- announce a re-learn only when the line moves 3%

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
-- stores: calibration is per character (it depends on the character's own
-- speed bonuses) and holds `ceiling` plus, with Auto Calibration on, `learnedCruise`
-- and `learnedSprint`, all in u/ms and all optional; preferences are a taste,
-- so they are account-wide under their own namespace (named "Display" for
-- historical reasons; autoLearn lives there too).
local SAVED_VARS_NAME    = "DoesThisThingGoAnyFasterSaved"
local SAVED_VARS_VERSION = 1
local CALIBRATION_DEFAULTS = {}
local DISPLAY_NAMESPACE    = "Display"
local DISPLAY_DEFAULTS     = { labelText = TEXT_WEEEE, goldBar = true, enthusiasmMode = false, autoLearn = false }

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
local isMounted = false
local sprintActive = false
local mountStaminaIndicator
local mountStaminaLabel
local mountStaminaBar
local mountStaminaOriginalGradient  -- snapshotted once at load; nil if that wasn't possible (see SnapshotMountStaminaGradient)
local savedVars                     -- per-character: ceiling, learnedCruise, learnedSprint
local displayVars                   -- account-wide: labelText, goldBar, enthusiasmMode, autoLearn

local learnSamples = {}             -- ring of steady smoothed speeds (u/ms); not saved
local learnHead, learnCount = 0, 0
local learnSinceAnalysis = 0

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
    -- Clears a pending arm-but-never-moved attempt on every mount/dismount.
    calibrationArmed = false
    -- A RUNNING window is cancelled too. Until 1.12.0 it was left running
    -- through a dismount, and because polling stops while dismounted, the
    -- first poll after the next mount found the window long expired and
    -- stored whatever partial peak it had (under the wrong zone, back when
    -- ceilings were per zone). Cancelling keeps any previous ceiling; with
    -- none, the next mount arms again.
    if calibrating then
        calibrating = false
        if savedVars.ceiling then
            d("DoesThisThingGoAnyFaster: calibration interrupted, so your previous calibration is still in use. Run /speedcal to try again.")
        elseif displayVars.autoLearn then
            d("DoesThisThingGoAnyFaster: calibration interrupted. Run /speedcal to try again, or keep riding and let Auto Calibration learn your speeds.")
        else
            d("DoesThisThingGoAnyFaster: calibration interrupted. It will start again the next time you ride.")
        end
    end
end

-- Arms calibration -- fires automatically on mount (see OnMountedStateChanged)
-- or manually via /speedcal; either way it doesn't start the 8s window
-- immediately. It stays paused (calibrationArmed) until OnPositionPoll
-- sees actual movement, so the whole window is spent riding rather than
-- partly wasted while stationary. Only measures the non-sprint ceiling --
-- the player is explicitly asked not to sprint, so there's nothing to
-- measure on the sprint side here; detection afterward is purely "did the
-- reading exceed the measured ceiling."
-- Returns true if it armed, so /speedcal knows whether to reset the learner.
local function ArmCalibration(isAutomatic)
    if not IsMounted() then
        d("DoesThisThingGoAnyFaster: mount up first, then run /speedcal again.")
        return false
    end

    if calibrating or calibrationArmed then
        return false
    end

    if isAutomatic then
        d("DoesThisThingGoAnyFaster: not calibrated yet -- ride without sprinting for at least " ..
            (CALIBRATION_DURATION_MS / 1000) .. " seconds to calibrate. Calibration begins automatically as soon as you start moving.")
    else
        d("DoesThisThingGoAnyFaster: ride without sprinting for at least " .. (CALIBRATION_DURATION_MS / 1000) ..
            " seconds to calibrate. Calibration begins as soon as you start moving.")
    end

    calibrationArmed = true
    return true
end

local function FinishCalibration()
    calibrating = false

    if calibrationPeakSpeed <= 0 then
        d("DoesThisThingGoAnyFaster: calibration failed -- no movement detected. Make sure you're mounted and moving, then try /speedcal again.")
        return
    end

    savedVars.ceiling = calibrationPeakSpeed
    d(string.format("DoesThisThingGoAnyFaster: calibration complete. Normal riding tops out at %.0fu/s, so anything over %.0fu/s now counts as sprinting, in every zone. Run /speedcal to calibrate again.",
        calibrationPeakSpeed * 1000, (calibrationPeakSpeed + SPRINT_MARGIN) * 1000))
end

-- ---------------------------------------------------------------------------
-- Auto Calibration (experimental)
-- ---------------------------------------------------------------------------
local function LearnedThreshold()
    local cruise, sprint = savedVars.learnedCruise, savedVars.learnedSprint
    if cruise and sprint then
        return (cruise + sprint) / 2
    end
    return nil
end

-- The line detection uses. Learned speeds win while Auto Calibration is on; the
-- /speedcal ceiling is the fallback until they exist, and the only source
-- with Auto Calibration off.
local function SprintThreshold()
    if displayVars.autoLearn then
        local learned = LearnedThreshold()
        if learned then return learned end
    end
    if savedVars.ceiling then
        return savedVars.ceiling + SPRINT_MARGIN
    end
    return nil
end

local function ClearLearnBuffer()
    learnSamples = {}
    learnHead, learnCount, learnSinceAnalysis = 0, 0, 0
end

local function ResetLearning()
    ClearLearnBuffer()
    savedVars.learnedCruise, savedVars.learnedSprint = nil, nil
end

-- Mean and standard deviation of sorted[first..last].
local function MeanAndSpread(sorted, first, last)
    local n, sum = last - first + 1, 0
    for i = first, last do sum = sum + sorted[i] end
    local mean = sum / n
    local sq = 0
    for i = first, last do
        local dv = sorted[i] - mean
        sq = sq + dv * dv
    end
    return mean, math.sqrt(sq / n)
end

-- Looks for two distinct speeds in values[1..n]. Returns cruise, sprint (u/ms)
-- if the riding shows two convincing clusters, or nil if it does not (yet).
local function FindTwoSpeeds(values, n)
    local sorted = {}
    for i = 1, n do sorted[i] = values[i] end
    table.sort(sorted)

    local total = 0
    for i = 1, n do total = total + sorted[i] end

    -- Otsu's split: maximise (size low * size high * gap between means^2),
    -- only over splits that leave both sides big enough to count.
    local bestScore, bestK, sumLow = -1, nil, 0
    for k = 1, n - 1 do
        sumLow = sumLow + sorted[k]
        if k >= LEARN_MIN_CLASS and n - k >= LEARN_MIN_CLASS then
            local gap = (total - sumLow) / (n - k) - sumLow / k
            local score = k * (n - k) * gap * gap
            if score > bestScore then bestScore, bestK = score, k end
        end
    end
    if not bestK then return nil end

    local cruise, cruiseSpread = MeanAndSpread(sorted, 1, bestK)
    local sprint, sprintSpread = MeanAndSpread(sorted, bestK + 1, n)
    if cruise <= 0 then return nil end

    local ratio = sprint / cruise
    if ratio < LEARN_MIN_RATIO or ratio > LEARN_MAX_RATIO then return nil end
    if sprint - cruise < LEARN_SEPARATION * math.max(cruiseSpread, sprintSpread) then return nil end

    return cruise, sprint
end

local function AnalyseLearnBuffer()
    local cruise, sprint = FindTwoSpeeds(learnSamples, learnCount)
    if not cruise then return end

    local previous = LearnedThreshold()
    savedVars.learnedCruise, savedVars.learnedSprint = cruise, sprint
    local threshold = LearnedThreshold()

    if not previous or math.abs(threshold - previous) > LEARN_REPORT_CHANGE * previous then
        d(string.format("DoesThisThingGoAnyFaster (experimental): Auto Calibration learned your mount speeds -- normal %.0fu/s, sprinting %.0fu/s. Sprinting now means over %.0fu/s.",
            cruise * 1000, sprint * 1000, threshold * 1000))
    end
end

local function LearnFromSample(speed)
    learnHead = (learnHead % LEARN_BUFFER_SIZE) + 1
    learnSamples[learnHead] = speed
    if learnCount < LEARN_BUFFER_SIZE then learnCount = learnCount + 1 end

    learnSinceAnalysis = learnSinceAnalysis + 1
    if learnCount >= LEARN_MIN_SAMPLES and learnSinceAnalysis >= LEARN_ANALYSE_EVERY then
        learnSinceAnalysis = 0
        AnalyseLearnBuffer()
    end
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
                    FinishCalibration()
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

            if displayVars.autoLearn and fastSpeed >= LEARN_MIN_SPEED
               and math.abs(instSpeed - fastSpeed) <= LEARN_STEADY_TOLERANCE * fastSpeed then
                LearnFromSample(fastSpeed)
            end

            local threshold = SprintThreshold()
            sprintActive = threshold ~= nil and fastSpeed > threshold

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

    -- Auto-calibration trigger: arm it right at the mount moment if this
    -- character has no ceiling yet. Skipped while Auto Calibration is on,
    -- because the point of the learner is not to ask.
    if mounted and savedVars.ceiling == nil and not displayVars.autoLearn then
        ArmCalibration(true)
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
                 .. "Type /speedcal in chat to recalibrate. One calibration covers every zone.",
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
        {
            type    = LHAS.ST_CHECKBOX,
            label   = "Auto Calibration (Experimental)",
            tooltip = "Instead of asking you to ride without sprinting, the add-on watches your riding and learns "
                   .. "your normal and sprinting speeds by itself. It needs to see both: a couple of minutes of riding "
                   .. "that includes a few seconds of steady sprinting. Until then it uses your /speedcal calibration, "
                   .. "if you have one. It says in chat what it learned. Experimental: a speed buff such as Major Gallop can "
                   .. "confuse it. Default: off.",
            default = DISPLAY_DEFAULTS.autoLearn,
            getFunction = function() return displayVars.autoLearn end,
            setFunction = function(value)
                displayVars.autoLearn = value and true or false
                if displayVars.autoLearn then
                    calibrationArmed = false   -- a pending "ride without sprinting" prompt is moot now
                else
                    ClearLearnBuffer()         -- learned speeds are kept for next time; samples are not
                    if isMounted and savedVars.ceiling == nil then
                        ArmCalibration(true)
                    end
                end
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
    if type(displayVars.autoLearn) ~= "boolean" then
        displayVars.autoLearn = DISPLAY_DEFAULTS.autoLearn
    end

    -- Per-zone ceilings (1.11.0 and the first 1.12.0 builds) are discarded:
    -- one ceiling per character replaces them, and the next mount arms a fresh
    -- calibration. Anything else malformed is dropped rather than trusted.
    savedVars.thresholds = nil
    local function positive(v) return type(v) == "number" and v > 0 end
    if not positive(savedVars.ceiling) then savedVars.ceiling = nil end
    if not (positive(savedVars.learnedCruise) and positive(savedVars.learnedSprint)
            and savedVars.learnedSprint > savedVars.learnedCruise) then
        savedVars.learnedCruise, savedVars.learnedSprint = nil, nil
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

    -- With Auto Calibration on, /speedcal also throws away what was learned, so a
    -- bad learned line can always be reset from chat.
    SLASH_COMMANDS["/speedcal"] = function()
        if ArmCalibration(false) and displayVars.autoLearn then
            ResetLearning()
            d("DoesThisThingGoAnyFaster (experimental): Auto Calibration's learned speeds cleared too; they will be learned again as you ride.")
        end
    end
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
