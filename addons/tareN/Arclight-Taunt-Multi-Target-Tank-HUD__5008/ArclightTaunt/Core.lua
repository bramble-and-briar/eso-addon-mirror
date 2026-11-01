-- Arclight Taunt 1.0.3 | Core module
-- Lua implementation is original; uses only the public ESO UI API.
local ADDON = "ArclightTaunt"
local EM, WM = EVENT_MANAGER, WINDOW_MANAGER
local A = { targets = {}, rows = {}, demo = false, moving = false, activeTarget = nil, dragActive = false, nextOrder = 0 }
A.bossAlerts = { expired = { kind = "expired" }, early = { kind = "early" } }
local TAUNT_IDS = { [38541] = true, [38254] = true }

local COLUMN_GAP = 8
local ROW_HEIGHT, HEADER_HEIGHT, FOOTER_HEIGHT = 25, 20, 18
local MAX_PER_COLUMN = 12
local MAX_TRACKED_TARGETS = 128 -- safety cap; never discard active targets for old losses
local UPDATE_MS, EXPIRED_LINGER = 100, 2.0 -- used when persistent lost-taunt display is off
local ALERT_BATCH_SECONDS = 0.35 -- combine nearly simultaneous boss taunt expirations
local ALERT_SOUND_COOLDOWN = 4.0
local SMART_TIME_DECIMAL_AT = 5 -- full seconds above 5; tenths at 5 and below
-- Only negatively associated native UI sound identifiers from ESO's
-- SoundIds.lua. Identifiers existing in SOUNDS do not guarantee audible output;
-- our test button lets users confirm them in their own client.
local ALERT_SOUNDS = {
    ["Allgemeiner Alarm"] = "GENERAL_ALERT_ERROR",
    ["Countdown-Warnung"] = "COUNTDOWN_WARNING",
    ["Duell-Grenzwarnung"] = "DUEL_BOUNDARY_WARNING",
    ["Rüstung beschädigt"] = "HUD_ARMOR_BROKEN",
    ["Prüfung gescheitert"] = "RAID_TRIAL_FAILED",
    ["Questschritt gescheitert"] = "QUEST_STEP_FAILED",
    ["Entdeckt"] = "STEALTH_DETECTED",
    ["Gesucht"] = "JUSTICE_NOW_KOS",
    ["Fähigkeit fehlgeschlagen"] = "ABILITY_FAILED_IN_COMBAT",
    ["Todesstoß"] = "DEATH_RECAP_KILLING_BLOW_SHOWN",
}
local ALERT_SOUND_CHOICES = {
    "Allgemeiner Alarm", "Countdown-Warnung", "Duell-Grenzwarnung",
    "Rüstung beschädigt", "Prüfung gescheitert",
    "Questschritt gescheitert", "Entdeckt", "Gesucht",
    "Fähigkeit fehlgeschlagen", "Todesstoß",
}
local RETICLE_SCAN_INTERVAL = 0.25 -- do not scan reticle buffs every HUD redraw
local IMMUNITY_STACK_THRESHOLD = 5
-- Only explicit, unambiguous effect names. These are NOT arbitrary ability IDs.
-- Some translations/patches may use different labels: show nothing if unmatched.
-- Later, confirmed ability IDs can replace this compatibility fallback.
local COUNTER_NAMES = {
    ["taunt counter"] = true,
    ["spottzähler"] = true,
    ["spott-zähler"] = true,
    ["verspottungszähler"] = true,
    ["verspottungs-zähler"] = true,
}
local IMMUNITY_NAMES = {
    ["taunt immunity"] = true,
    ["spottimmunität"] = true,
    ["spott-immunität"] = true,
    ["verspottungsimmunität"] = true,
    ["verspottungs-immunität"] = true,
}
local function CanonicalEffectName(value)
    if type(value) ~= "string" then return "" end
    return value:lower():gsub("^%s+", ""):gsub("%s+$", "")
end
local C = {
    white      = {0.96, 0.97, 1.00, 1},
    muted      = {0.67, 0.73, 0.79, 1},
    header     = {0.025, 0.037, 0.055, 0.84},
    row        = {0.025, 0.039, 0.055, 1},
    warningRow = {0.095, 0.067, 0.029, 1},
    dangerRow  = {0.108, 0.035, 0.045, 1},
    selected   = {0.53, 0.82, 1.00, 1},
    track      = {0.22, 0.25, 0.29, 0.60},
    safe       = {0.17, 0.94, 0.75, 1},
    warning    = {1.00, 0.71, 0.12, 1},
    danger     = {1.00, 0.26, 0.33, 1},
    -- Full-row progress uses darker tints than the text/bar colours, keeping
    -- white and champagne-gold names legible while making time progression clear.
    fullSafe   = {0.06, 0.33, 0.27, 0.64},
    fullWarning= {0.46, 0.28, 0.04, 0.64},
    fullDanger = {0.43, 0.07, 0.13, 0.64},
    moveTint   = {0.18, 0.40, 0.57, 0.27},
    immunity   = {0.76, 0.52, 1.00, 1},
    focus      = {0.90, 0.95, 1.00, 1},
    focusWash  = {0.27, 0.53, 0.78, 0.19},
    focusLine  = {0.68, 0.86, 1.00, 0.88},
    focusWashFull = {0.20, 0.44, 0.65, 0.32},
    focusLineFull = {0.83, 0.94, 1.00, 1.00},
    -- Soft champagne: bright on turquoise/yellow/red rows, but distinct
    -- from the saturated yellow *timer*. Never colour-code boss names
    -- by remaining time; countdown and severity stripe keep that role.
    bossName   = {0.985, 0.898, 0.722, 1},
    bossIcon   = {0.98, 0.94, 0.84, 1}, -- pale bone-ivory: clearer than white names, distinct from purple immunity
    -- Alert visuals are fixed across all profiles. Native textures and labels
    -- retain a high contrast independently of the taunt timer colours.
    alertBackground = {1, 1, 1, 1},
    alertEdge = {1.00, 0.20, 0.33, 1},
    alertHairline = {1.00, 0.32, 0.44, 0.90},
    alertTitle = {1.00, 0.94, 0.94, 1},
    alertEarlyTitle = {0.78, 1.00, 0.94, 1},
    alertEarlyHairline = {0.20, 0.95, 0.78, 0.95},
}
local defaults = {
    x = 1507, y = 370, scale = 1.25, onlyMine = true,
    columns = 1, limit = 10, header = false, opacity = 0.72, width = 280, rowGap = 2,
    subtleWarningBg = true, warningAt = 7, dangerAt = 4, removeDead = true,
    showExpired = false, sortMode = "remaining", showBossIcon = true,
    highlightBossNames = true, pinBosses = false, bossMode = "comprehensive",
    showImmunity = false, showTauntStacks = false, highlightTarget = true, focusStyle = "strong",
    fontKey = "Arclight (Standard)", timerFontKey = "Wie Gegnername",
    barKey = "Arclight (Signal)", fontSize = 100,
    barHeight = 4, barDisplay = "compact", backgroundKey = "Ohne Textur", texturedTrack = false,
    bossAlertText = true, bossAlertSound = true,
    bossAlertSoundKey = "Todesstoß", bossAlertDuration = 2.5,
    bossAlertOpacity = 100, bossAlertOffsetY = 290, bossAlertElites = false,
    hideInMenus = true, smartTime = true, growUp = false, fitToScreen = true,
    bossEarlyWarning = true, bossEarlySeconds = 2.5,
}
local FONT_NAME = "$(BOLD_FONT)|14|soft-shadow-thin"
local FONT_TIME = "$(BOLD_FONT)|15|soft-shadow-thin"
local FONT_HEADER = "$(BOLD_FONT)|13|soft-shadow-thin"
local FONT_MORE = "$(MEDIUM_FONT)|12|soft-shadow-thin"

-- LibMediaProvider-1.1 offers names and texture/font paths, not UI widgets.
-- Preserve our original CT_TEXTURE solid fill as the default; an empty LMP
-- statusbar path must NEVER be passed to SetTexture (white rectangle bug).
local MEDIA_FONT_DEFAULT = "Arclight (Standard)"
local MEDIA_TIMER_INHERIT = "Wie Gegnername"
local MEDIA_BAR_FLAT = "Arclight (Glatt)"
local MEDIA_BAR_DEFAULT = "Arclight (Signal)"
local MEDIA_BAR_ESO = "Arclight Taunt - ESO-Verlauf"
local MEDIA_BAR_SIGNATURE = "Arclight (Signatur)"
local MEDIA_BAR_SIGNAL = "Arclight (Signal)"
local MEDIA_TEXTURE_SIGNATURE = "ArclightTaunt/Textures/ArclightSignatur.dds"
local MEDIA_TEXTURE_SIGNAL = "ArclightTaunt/Textures/ArclightSignal.dds"
local BOSS_ICON_TEXTURE = "ArclightTaunt/Textures/ArclightBoss.dds"
local BOSS_WARNING_TEXTURE = "ArclightTaunt/Textures/ArclightBossWarning.dds"
local BOSS_EARLY_TEXTURE = "ArclightTaunt/Textures/ArclightBossEarly.dds"
local MEDIA_BG_NONE = "Ohne Textur"
local MEDIA_BG_OBSIDIAN = "Arclight (Obsidian)"
local MEDIA_BG_CARBON = "Arclight (Carbon)"
local MEDIA_BG_OBSIDIAN_PATH = "ArclightTaunt/Textures/ArclightObsidianBG.dds"
local MEDIA_BG_CARBON_PATH = "ArclightTaunt/Textures/ArclightCarbonBG.dds"
local MEDIA_TRACK_PATH = "ArclightTaunt/Textures/ArclightTrack.dds"

-- EVENT_EFFECT_CHANGED times are in the GetFrameTimeSeconds() timebase.
local function Now()
    return GetFrameTimeSeconds()
end
local function Clamp(n, low, high)
    return math.max(low, math.min(high, n))
end
local function FiniteBoundedNumber(value, default, low, high)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return default
    end
    return Clamp(value, low, high)
end
local function SetColor(control, rgba, alphaOverride)
    control:SetColor(rgba[1], rgba[2], rgba[3], alphaOverride or rgba[4])
end

-- ESO's CT_TEXTURE supports a plain solid colour without a texture path.
-- Avoid CT_BACKDROP edge textures: the old 0.1 UI showed white outlines.
local function Solid(parent, rgba)
    local t = WM:CreateControl(nil, parent, CT_TEXTURE)
    SetColor(t, rgba)
    return t
end
local function Label(parent, font, rgba, alignment)
    local l = WM:CreateControl(nil, parent, CT_LABEL)
    l:SetFont(font)
    SetColor(l, rgba)
    l:SetHorizontalAlignment(alignment or TEXT_ALIGN_LEFT)
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    l:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return l
end

local function Chat(message)
    d("|c36E4C0[Arclight Taunt]|r " .. message)
end

-- All addon-owned visibility writes share this cache, including media changes.
local hiddenStates = setmetatable({}, { __mode = "k" })
function A.SetHidden(control, hidden)
    hidden = not not hidden
    if hiddenStates[control] ~= hidden then
        control:SetHidden(hidden)
        hiddenStates[control] = hidden
    end
end

-- The first effect in a frame draws immediately; later effects share the next
-- scheduled redraw. The periodic callback sleeps when no work remains.
function A.RefreshUpdateState()
    local needed = A.demo or A.moving or A.effectTickPending or next(A.targets) ~= nil
        or A.bossAlerts.expired.visibleUntil ~= nil or A.bossAlerts.early.visibleUntil ~= nil
        or A.pendingBossPreview ~= nil
        or (A.pendingBossWarnings and next(A.pendingBossWarnings) ~= nil)
    needed = not not needed
    if needed == (A.updateRunning == true) then return end
    A.updateRunning = needed
    if needed then
        EM:RegisterForUpdate(ADDON .. "_Update", UPDATE_MS, function() A.Tick() end)
    else
        EM:UnregisterForUpdate(ADDON .. "_Update")
    end
end

-- Store every effect immediately, but draw at most once per effect frame.
-- A pending final redraw also keeps the callback alive after the last removal.
-- Duplicate data does not bypass the regular reticle scan interval.
function A.RequestEffectTick(observationChanged)
    if observationChanged ~= false then
        A.reticleDirty, A.earlyWarningDirty = true, true
    end
    local now = Now()
    if A.lastEffectTickAt ~= now then
        A.lastEffectTickAt = now
        A.Tick()
    else
        A.effectTickPending = true
        A.RefreshUpdateState()
    end
end

-- The sole addon namespace; all other files use this shared state.
A.ADDON = ADDON
A.EM = EM
A.WM = WM
A.TAUNT_IDS = TAUNT_IDS
A.COLUMN_GAP = COLUMN_GAP
A.ROW_HEIGHT = ROW_HEIGHT
A.HEADER_HEIGHT = HEADER_HEIGHT
A.FOOTER_HEIGHT = FOOTER_HEIGHT
A.MAX_PER_COLUMN = MAX_PER_COLUMN
A.MAX_TRACKED_TARGETS = MAX_TRACKED_TARGETS
A.UPDATE_MS = UPDATE_MS
A.EXPIRED_LINGER = EXPIRED_LINGER
A.ALERT_BATCH_SECONDS = ALERT_BATCH_SECONDS
A.ALERT_SOUND_COOLDOWN = ALERT_SOUND_COOLDOWN
A.SMART_TIME_DECIMAL_AT = SMART_TIME_DECIMAL_AT
A.ALERT_SOUNDS = ALERT_SOUNDS
A.ALERT_SOUND_CHOICES = ALERT_SOUND_CHOICES
A.RETICLE_SCAN_INTERVAL = RETICLE_SCAN_INTERVAL
A.IMMUNITY_STACK_THRESHOLD = IMMUNITY_STACK_THRESHOLD
A.COUNTER_NAMES = COUNTER_NAMES
A.IMMUNITY_NAMES = IMMUNITY_NAMES
A.CanonicalEffectName = CanonicalEffectName
A.C = C
A.defaults = defaults
A.FONT_NAME = FONT_NAME
A.FONT_TIME = FONT_TIME
A.FONT_HEADER = FONT_HEADER
A.FONT_MORE = FONT_MORE
A.MEDIA_FONT_DEFAULT = MEDIA_FONT_DEFAULT
A.MEDIA_TIMER_INHERIT = MEDIA_TIMER_INHERIT
A.MEDIA_BAR_FLAT = MEDIA_BAR_FLAT
A.MEDIA_BAR_DEFAULT = MEDIA_BAR_DEFAULT
A.MEDIA_BAR_ESO = MEDIA_BAR_ESO
A.MEDIA_BAR_SIGNATURE = MEDIA_BAR_SIGNATURE
A.MEDIA_BAR_SIGNAL = MEDIA_BAR_SIGNAL
A.MEDIA_TEXTURE_SIGNATURE = MEDIA_TEXTURE_SIGNATURE
A.MEDIA_TEXTURE_SIGNAL = MEDIA_TEXTURE_SIGNAL
A.BOSS_ICON_TEXTURE = BOSS_ICON_TEXTURE
A.BOSS_WARNING_TEXTURE = BOSS_WARNING_TEXTURE
A.BOSS_EARLY_TEXTURE = BOSS_EARLY_TEXTURE
A.MEDIA_BG_NONE = MEDIA_BG_NONE
A.MEDIA_BG_OBSIDIAN = MEDIA_BG_OBSIDIAN
A.MEDIA_BG_CARBON = MEDIA_BG_CARBON
A.MEDIA_BG_OBSIDIAN_PATH = MEDIA_BG_OBSIDIAN_PATH
A.MEDIA_BG_CARBON_PATH = MEDIA_BG_CARBON_PATH
A.MEDIA_TRACK_PATH = MEDIA_TRACK_PATH
A.Now = Now
A.Clamp = Clamp
A.FiniteBoundedNumber = FiniteBoundedNumber
A.SetColor = SetColor
A.Solid = Solid
A.Label = Label
A.Chat = Chat
ArclightTaunt = A
