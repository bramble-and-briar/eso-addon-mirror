local addon = BureauOfAcceptableViews
addon.Settings = addon.Settings or {}

local Settings = addon.Settings
local private = addon.private

local constants = private.constants or {}
local ZOOM_MAX = constants.ZOOM_MAX or 10.0
local ZOOM_MIN_MOUNTED = constants.ZOOM_MIN_MOUNTED or 2.0
local LASTZOOM_THRESHOLD = constants.LASTZOOM_THRESHOLD or 2.0
local ZOOM_FPV = constants.ZOOM_FPV or 0.0
local ZOOM_STEP = constants.ZOOM_STEP or 0.45
local PRESERVE_FPV_BETWEEN_ZONES = constants.PRESERVE_FPV_BETWEEN_ZONES
local ZOOM_STEP_MIN = constants.ZOOM_STEP_MIN or 0.05
local ZOOM_STEP_MAX = constants.ZOOM_STEP_MAX or 2.25
local CONFIG_MIN_THIRD_PERSON_ZOOM = constants.CONFIG_MIN_THIRD_PERSON_ZOOM or 0.10
local DEBUG_MODE_DEFAULT = constants.DEBUG_MODE_DEFAULT or 0
local DEBUG_MODE_MIN = constants.DEBUG_MODE_MIN or 0
local DEBUG_MODE_MAX = constants.DEBUG_MODE_MAX or 4
local LEGACY_ZOOM_STEP_DEFAULT = 0.30
local ZOOM_STEP_DEFAULT_REVISION = 1
local PVP_ZOOM_STEP_DEFAULT = 0.5
local CAMERA_RESPONSE_DEFAULT = "responsive"

local CAMERA_RESPONSE_DEFINITIONS = {
    { id = "native",     nameKey = SI_BAV_SETTING_CAMERA_RESPONSE_NATIVE },
    { id = "instant",    nameKey = SI_BAV_SETTING_CAMERA_RESPONSE_INSTANT },
    { id = "responsive", nameKey = SI_BAV_SETTING_CAMERA_RESPONSE_RESPONSIVE },
    { id = "smooth",     nameKey = SI_BAV_SETTING_CAMERA_RESPONSE_SMOOTH },
}

local CAMERA_RESPONSE_IDS = {}
for _, def in ipairs(CAMERA_RESPONSE_DEFINITIONS) do
    CAMERA_RESPONSE_IDS[def.id] = true
end

-- Single source of truth for context-preset states: drives the SavedVariables
-- defaults, the SetPresetState validity guard, and the settings-panel checkbox
-- grid. Order here is the order shown in the UI. Adding a new state means
-- adding one row here (plus its localized name/tooltip strings).
local PRESET_STATE_DEFINITIONS = {
    { id = "combat",   nameKey = SI_BAV_SETTING_PRESET_STATE_COMBAT_NAME,   tooltipKey = SI_BAV_SETTING_PRESET_STATE_COMBAT_TOOLTIP,   reference = "BAVSettingsPresetStateCombat" },
    { id = "werewolf", nameKey = SI_BAV_SETTING_PRESET_STATE_WEREWOLF_NAME, tooltipKey = SI_BAV_SETTING_PRESET_STATE_WEREWOLF_TOOLTIP, reference = "BAVSettingsPresetStateWerewolf" },
    { id = "stealth",     nameKey = SI_BAV_SETTING_PRESET_STATE_STEALTH_NAME,     tooltipKey = SI_BAV_SETTING_PRESET_STATE_STEALTH_TOOLTIP,     reference = "BAVSettingsPresetStateStealth" },
    { id = "interaction", nameKey = SI_BAV_SETTING_PRESET_STATE_INTERACTION_NAME, tooltipKey = SI_BAV_SETTING_PRESET_STATE_INTERACTION_TOOLTIP, reference = "BAVSettingsPresetStateInteraction" },
    { id = "mounted",     nameKey = SI_BAV_SETTING_PRESET_STATE_MOUNTED_NAME,     tooltipKey = SI_BAV_SETTING_PRESET_STATE_MOUNTED_TOOLTIP,     reference = "BAVSettingsPresetStateMounted" },
    { id = "swimming",    nameKey = SI_BAV_SETTING_PRESET_STATE_SWIMMING_NAME,    tooltipKey = SI_BAV_SETTING_PRESET_STATE_SWIMMING_TOOLTIP,    reference = "BAVSettingsPresetStateSwimming" },
    { id = "sprint",      nameKey = SI_BAV_SETTING_PRESET_STATE_SPRINT_NAME,      tooltipKey = SI_BAV_SETTING_PRESET_STATE_SPRINT_TOOLTIP,      reference = "BAVSettingsPresetStateSprint" },
}

-- Valid context-preset state ids, used to guard SetPresetState against stale UI
-- references writing junk keys into SavedVariables. Derived from the definitions
-- above so the two can never drift apart.
local PRESET_STATE_IDS = {}
for _, def in ipairs(PRESET_STATE_DEFINITIONS) do
    PRESET_STATE_IDS[def.id] = true
end

-- Style id meaning "this state does nothing". Kept as a literal here (rather
-- than calling ContextPresets.GetOffStyleId at file-parse time) so the defaults
-- table below can be built regardless of module load order; it is asserted to
-- match the controller's value the first time styles are normalized.
local PRESET_STYLE_OFF = "off"

-- Maps a style id to the localized string constant for its display name, used
-- to label the per-state dropdown choices. Kept here next to the state list so
-- adding a style is a one-line change. Unknown ids fall back to the raw id text
-- so a newly-added controller style is still selectable before its string lands.
local PRESET_STYLE_NAME_KEYS = {
    off       = SI_BAV_SETTING_PRESET_STYLE_OFF_NAME,
    subtle    = SI_BAV_SETTING_PRESET_STYLE_SUBTLE_NAME,
    cinematic = SI_BAV_SETTING_PRESET_STYLE_CINEMATIC_NAME,
    action    = SI_BAV_SETTING_PRESET_STYLE_ACTION_NAME,
}

local function StyleNameKey(styleId)
    return PRESET_STYLE_NAME_KEYS[styleId] or tostring(styleId)
end

-- Selectable per-state release-delay values (ms) for the settings dropdowns. 0 is
-- always "Off" (release immediately). Combat gets a coarser, longer list because
-- it is the state that flickers over seconds; every other state gets a finer list
-- skewed toward small debounces. Both are user-facing only -- the controller just
-- stores whatever ms value is picked.
local PRESET_COALESCE_VALUES_COMBAT = { 0, 1000, 1500, 2500, 3500, 5000 }
local PRESET_COALESCE_VALUES_DEFAULT = { 0, 25, 50, 75, 100, 150, 500, 1000, 1500, 3000 }

-- Build the display labels parallel to a values list: 0 -> "Off", sub-second
-- values -> "<n> ms", whole/decimal seconds -> "<n> s" (via %g so 1, 1.5, 3 read
-- cleanly). Localized via the format strings so other languages control the unit.
local function BuildCoalesceLabels(values)
    local labels = {}
    for i = 1, #values do
        local ms = values[i]
        if ms <= 0 then
            labels[i] = GetString(SI_BAV_SETTING_PRESET_COALESCE_OFF)
        elseif ms < 1000 then
            labels[i] = string.format(GetString(SI_BAV_SETTING_PRESET_COALESCE_MS_FORMAT), ms)
        else
            labels[i] = string.format(GetString(SI_BAV_SETTING_PRESET_COALESCE_S_FORMAT), ms / 1000)
        end
    end
    return labels
end

if PRESERVE_FPV_BETWEEN_ZONES == nil then
    PRESERVE_FPV_BETWEEN_ZONES = true
end

---@class BAVSavedVars
---@field currentZoom number
---@field lastThirdPersonZoom number
---@field zoomStep number
---@field zoomStepDefaultRevision number|nil
---@field lastZoomThreshold number
---@field zoomMinMounted number
---@field preserveFpvBetweenZones boolean
---@field zoom number|nil
---@field cameraResponseMode string|nil
---@field dynamicFovEnabled boolean
---@field dynamicFovNear number|nil
---@field dynamicFovFar number|nil
---@field dynamicFovSmooth boolean
---@field dynamicFovBaseSnapshot number|nil
---@field presetsEnabled boolean
---@field presetIntensity number
---@field presetSmoothTransitions boolean
---@field presetStates table<string, string>
---@field presetStateIntensities table<string, number>
---@field presetStateCoalesce table<string, number>
---@field presetRestoreSnapshot table|nil
---@field shoulderMode string
---@field shoulderOffset number
---@field shoulderAutoSide string
---@field shoulderManualSide string
---@field shoulderAutoStates table<string, boolean>
---@field shoulderBaseSnapshot number|nil
---@field pvpModeEnabled boolean
---@field pvpCameraShake boolean
---@field pvpZoomStep number
---@field pvpScreenShakeSnapshot number|nil
---@field offsetNudgeSpeed number
---@field offsetNudgeOverlay boolean
---@field offsetNudgeHome table|nil
---@field debugMode number

---@type BAVSavedVars
local DEFAULT_SAVED_VARS = {
    -- Chat log verbosity (0=off .. 4=verbose). Persisted so the panel slider and
    -- /bav debug survive a /reloadui; the shipped default is 0 (silent) -- true
    -- user-facing failures still go through ChatError, which ignores this level.
    debugMode = DEBUG_MODE_DEFAULT,
    currentZoom = ZOOM_MIN_MOUNTED,
    lastThirdPersonZoom = ZOOM_MIN_MOUNTED,
    zoomStep = ZOOM_STEP,
    lastZoomThreshold = LASTZOOM_THRESHOLD,
    zoomMinMounted = ZOOM_MIN_MOUNTED,
    preserveFpvBetweenZones = PRESERVE_FPV_BETWEEN_ZONES,
    -- cameraResponseMode is intentionally absent here. NormalizeSavedSettings
    -- writes it once after migrating the two legacy smoothing flags; putting a
    -- default value here could hide the difference between an old install and a
    -- fresh explicit choice depending on how ZO_SavedVars materializes defaults.
    -- Optional camera features. Dynamic FOV ships ON by default (with smoothing)
    -- so a fresh install gets the eased zoom feel out of the box; it still does
    -- nothing on clients where the FOV property is unsupported. Context presets
    -- stay OFF by default -- a disabled module registers no events.
    dynamicFovEnabled = true,
    dynamicFovNear = nil,   -- nil => DynamicFov resolves to the engine FOV range
    dynamicFovFar = nil,
    dynamicFovSmooth = true,  -- glide FOV between zoom steps instead of snapping
    -- Runtime recovery (NOT a user setting): the player's manual third-person
    -- FOV captured before Dynamic FOV first overrides it. Persisted so disabling
    -- the feature after /reloadui can still restore the real value.
    dynamicFovBaseSnapshot = nil,
    presetsEnabled = false,
    presetIntensity = 1.0,
    -- Ease context-preset state changes (spatial framing + FOV) over a short
    -- glide instead of snapping. Defaults ON, matching the Dynamic FOV smoothing
    -- precedent; turning it off restores instant transitions.
    presetSmoothTransitions = true,
    -- Each state holds a STYLE id (not a boolean): "off" disables the state,
    -- other ids ("subtle"/"cinematic"/"action") pick how strong its framing is.
    -- All default to "off" so a fresh install applies nothing until the user
    -- both enables presets and picks a style per state.
    presetStates = {
        combat = PRESET_STYLE_OFF,
        werewolf = PRESET_STYLE_OFF,
        stealth = PRESET_STYLE_OFF,
        interaction = PRESET_STYLE_OFF,
        mounted = PRESET_STYLE_OFF,
        swimming = PRESET_STYLE_OFF,
        sprint = PRESET_STYLE_OFF,
    },
    -- Per-state intensity multiplier (0..1) layered on top of the global
    -- presetIntensity and the state's chosen style strength. All default to 1.0
    -- so a state runs at its full style strength until the user dials it down;
    -- an install that predates this key reads missing entries as 1.0 too, so the
    -- behavior is unchanged on upgrade.
    presetStateIntensities = {
        combat = 1.0,
        werewolf = 1.0,
        stealth = 1.0,
        interaction = 1.0,
        mounted = 1.0,
        swimming = 1.0,
        sprint = 1.0,
    },
    -- Per-state release delay (ms): how long leaving that state is deferred so a
    -- fast out-and-back collapses to a no-op instead of jolting the camera. All
    -- default to 0 (release immediately, no coalescing) so presets do not damp
    -- state exits until the user opts a state into a delay in the panel; an
    -- install predating this key reads missing entries as 0 too, so upgrades are
    -- seamless.
    presetStateCoalesce = {
        combat = 0,
        werewolf = 0,
        stealth = 0,
        interaction = 0,
        mounted = 0,
        swimming = 0,
        sprint = 0,
    },
    -- Runtime recovery (NOT a user setting): the player's own camera captured
    -- the moment a context preset first overrode it. Persisted so a /reloadui,
    -- logout, or crash WHILE a preset is active can hand the real camera back
    -- next session instead of leaving the preset's offsets baked into the
    -- player's settings (and then re-snapshotting those dirty values, which
    -- compounds every session). nil whenever no preset is overriding the camera.
    presetRestoreSnapshot = nil,
    -- Over-the-shoulder (shoulder swap). OFF by default -- a disabled module
    -- registers no events and writes nothing. Mode is one of "off"/"auto"/"manual";
    -- the two active modes are mutually exclusive (auto = by-state, manual = slash).
    -- offset is the OTS magnitude (0..1 onto the shoulder range). autoStates picks
    -- which states trigger the auto swing; all off until the user opts in.
    shoulderMode = "off",
    shoulderOffset = 0.00,
    shoulderAutoSide = "right",
    shoulderManualSide = "right",
    shoulderAutoStates = {
        combat = false,
        stealth = false,
        mounted = false,
        swimming = false,
        sprint = false,
    },
    -- Runtime recovery (NOT a user setting): the player's own shoulder captured the
    -- moment a swing first overrode it, persisted so a reloadui/logout/crash while
    -- swung hands the real shoulder back next session. nil whenever not swung.
    shoulderBaseSnapshot = nil,
    -- PvP world mode ships ON, but remains fully inert outside AvA/Battlegrounds.
    -- It never applies automatic camera profiles; it only selects the dedicated
    -- manual zoom step and can suppress camera shake while the player is in PvP.
    pvpModeEnabled = true,
    pvpCameraShake = false,
    pvpZoomStep = PVP_ZOOM_STEP_DEFAULT,
    -- Runtime recovery: the player's camera-shake value captured before PvP
    -- suppression. Persisted so /reloadui can restore it safely.
    pvpScreenShakeSnapshot = nil,
    -- Live hold-to-nudge for horizontal/vertical camera offsets. Speed is a
    -- multiplier on the module's units-per-second rates (0.5..2.0). Overlay
    -- shows both axes while a bind is held and for two seconds after.
    offsetNudgeSpeed = 1.0,
    offsetNudgeOverlay = true,
    -- Single remembered horizontal/vertical pose. nil until the player
    -- explicitly captures it from the settings panel; without it, offset
    -- binds refuse to move the camera.
    offsetNudgeHome = nil,
}

---@type BAVSavedVars|nil (accessible via private.savedVars after initialization)

local function GetSavedVarsOrDefaults()
    return private.savedVars or DEFAULT_SAVED_VARS
end

local function NormalizeBoolean(value, defaultValue)
    if value == nil then
        return defaultValue
    end
    if value == true or value == false then
        return value
    end

    value = string.lower(tostring(value))
    if value == "1" or value == "true" or value == "on" or value == "yes" then
        return true
    end
    if value == "0" or value == "false" or value == "off" or value == "no" then
        return false
    end

    return defaultValue
end

local function ParseBooleanArgument(value)
    if value == nil then
        return nil
    end

    return NormalizeBoolean(value, nil)
end

function Settings.GetSavedVars()
    return private.savedVars
end

function Settings.InitializeSavedVariables()
    private.savedVars = ZO_SavedVars:NewAccountWide(
        addon.savedVariablesName,
        1,
        nil,
        DEFAULT_SAVED_VARS
    )

    Settings.NormalizeSavedSettings()
    return private.savedVars
end

function Settings.GetConfiguredZoomStep()
    local vars = GetSavedVarsOrDefaults()
    return private.NormalizeZoomNumber(
        private.ClampNumber(tonumber(vars.zoomStep) or ZOOM_STEP, ZOOM_STEP_MIN, ZOOM_STEP_MAX),
        ZOOM_STEP
    )
end

function Settings.GetPvpZoomStep()
    local vars = GetSavedVarsOrDefaults()
    return private.NormalizeZoomNumber(
        private.ClampNumber(
            tonumber(vars.pvpZoomStep) or PVP_ZOOM_STEP_DEFAULT,
            ZOOM_STEP_MIN,
            ZOOM_STEP_MAX),
        PVP_ZOOM_STEP_DEFAULT
    )
end

function Settings.GetConfiguredLastZoomThreshold()
    local vars = GetSavedVarsOrDefaults()
    return private.NormalizeZoomNumber(
        private.ClampNumber(tonumber(vars.lastZoomThreshold) or LASTZOOM_THRESHOLD, ZOOM_FPV, ZOOM_MAX),
        LASTZOOM_THRESHOLD
    )
end

function Settings.GetConfiguredMinMountedZoom()
    local vars = GetSavedVarsOrDefaults()
    return private.NormalizeZoomNumber(
        private.ClampNumber(tonumber(vars.zoomMinMounted) or ZOOM_MIN_MOUNTED, CONFIG_MIN_THIRD_PERSON_ZOOM, ZOOM_MAX),
        ZOOM_MIN_MOUNTED
    )
end

function Settings.ShouldPersistFPVBetweenZones()
    local vars = GetSavedVarsOrDefaults()
    return NormalizeBoolean(vars.preserveFpvBetweenZones, PRESERVE_FPV_BETWEEN_ZONES)
end

local function NormalizeCameraResponseMode(value)
    if CAMERA_RESPONSE_IDS[value] then
        return value
    end
    return CAMERA_RESPONSE_DEFAULT
end

function Settings.GetCameraResponseMode()
    return NormalizeCameraResponseMode(GetSavedVarsOrDefaults().cameraResponseMode)
end

function Settings.SetCameraResponseMode(value)
    local vars = Settings.GetSavedVars()
    if not vars then
        return
    end
    vars.cameraResponseMode = NormalizeCameraResponseMode(value)
    Settings.ApplyOptionalFeatureConfig()
end

-- ---------------------------------------------------------------------------
-- Optional feature getters (Dynamic FOV + Context Presets)
-- ---------------------------------------------------------------------------

function Settings.IsDynamicFovEnabled()
    local vars = GetSavedVarsOrDefaults()
    return NormalizeBoolean(vars.dynamicFovEnabled, true)
end

-- Whether FOV changes between zoom steps should glide rather than snap. Purely
-- cosmetic; defaults on, matching the shipped Dynamic FOV default. The nil
-- fallback here only matters if the key is somehow absent.
function Settings.IsDynamicFovSmooth()
    local vars = GetSavedVarsOrDefaults()
    return NormalizeBoolean(vars.dynamicFovSmooth, true)
end

-- nil near/far are intentional: DynamicFov.Configure resolves them to the
-- engine FOV range, so we don't hardcode FOV limits in two places.
function Settings.GetDynamicFovNear()
    local vars = GetSavedVarsOrDefaults()
    return tonumber(vars.dynamicFovNear)
end

function Settings.GetDynamicFovFar()
    local vars = GetSavedVarsOrDefaults()
    return tonumber(vars.dynamicFovFar)
end

function Settings.GetDynamicFovBaseSnapshot()
    local vars = GetSavedVarsOrDefaults()
    return tonumber(vars.dynamicFovBaseSnapshot)
end

function Settings.SetDynamicFovBaseSnapshot(value)
    local vars = Settings.GetSavedVars()
    if not vars then
        return
    end
    if value == nil then
        vars.dynamicFovBaseSnapshot = nil
        return
    end
    local fov = tonumber(value)
    if fov ~= nil then
        vars.dynamicFovBaseSnapshot = fov
    end
end

-- Engine third-person FOV range, used as both the slider bounds and the
-- fallback for unset near/far values. We read it from CameraSettings (the
-- single source of truth for the clamp limits) and only fall back to the
-- documented 35..65 literals when the property cannot be resolved on this
-- client build, so the two never silently drift apart.
local DYNAMIC_FOV_RANGE_FALLBACK_MIN = 35
local DYNAMIC_FOV_RANGE_FALLBACK_MAX = 65

function Settings.GetDynamicFovRange()
    local CameraSettings = addon.CameraSettings
    if CameraSettings and CameraSettings.GetRange then
        local minFov, maxFov, decimals = CameraSettings.GetRange("thirdPersonFov")
        if minFov and maxFov then
            return minFov, maxFov, decimals or 2
        end
    end
    return DYNAMIC_FOV_RANGE_FALLBACK_MIN, DYNAMIC_FOV_RANGE_FALLBACK_MAX, 2
end

-- Slider-friendly accessors: resolve an unset (nil) near/far to the engine FOV
-- range endpoints so the control always shows a concrete value. nearFov maps to
-- the closest zoom, farFov to the farthest -- mirroring DynamicFov's own model.
function Settings.GetDynamicFovNearResolved()
    local minFov, maxFov = Settings.GetDynamicFovRange()
    local value = Settings.GetDynamicFovNear() or minFov
    return private.ClampNumber(value, minFov, maxFov)
end

function Settings.GetDynamicFovFarResolved()
    local minFov, maxFov = Settings.GetDynamicFovRange()
    local value = Settings.GetDynamicFovFar() or maxFov
    return private.ClampNumber(value, minFov, maxFov)
end

function Settings.IsPvpModeEnabled()
    local vars = GetSavedVarsOrDefaults()
    return NormalizeBoolean(vars.pvpModeEnabled, true)
end

function Settings.IsPvpCameraShakeEnabled()
    return NormalizeBoolean(GetSavedVarsOrDefaults().pvpCameraShake, false)
end

function Settings.GetPvpScreenShakeSnapshot()
    local value = tonumber(GetSavedVarsOrDefaults().pvpScreenShakeSnapshot)
    if value == nil then
        return nil
    end
    return private.ClampNumber(value, 0, 1)
end

function Settings.SetPvpScreenShakeSnapshot(value)
    local vars = Settings.GetSavedVars()
    if not vars then
        return
    end
    value = tonumber(value)
    vars.pvpScreenShakeSnapshot = value ~= nil
        and private.ClampNumber(value, 0, 1) or nil
end

-- Hold-to-nudge speed multiplier (0.5..2.0) on the module's units-per-second
-- rates. 1.0 is the shipped, responsive default.
function Settings.GetOffsetNudgeSpeed()
    local vars = GetSavedVarsOrDefaults()
    return private.ClampNumber(tonumber(vars.offsetNudgeSpeed) or 1.0, 0.5, 2.0)
end

function Settings.IsOffsetNudgeOverlayEnabled()
    local vars = GetSavedVarsOrDefaults()
    return NormalizeBoolean(vars.offsetNudgeOverlay, true)
end

local function NormalizeOffsetHome(home)
    if type(home) ~= "table" then
        return nil
    end
    local horizontal = tonumber(home.horizontal)
    local vertical = tonumber(home.vertical)
    if horizontal == nil or vertical == nil then
        return nil
    end
    return {
        horizontal = private.ClampNumber(horizontal, -1, 1),
        vertical = private.ClampNumber(vertical, -0.3, 0.5),
    }
end

function Settings.GetOffsetNudgeHome()
    return NormalizeOffsetHome(GetSavedVarsOrDefaults().offsetNudgeHome)
end

function Settings.HasOffsetNudgeHome()
    return Settings.GetOffsetNudgeHome() ~= nil
end

function Settings.SetOffsetNudgeHome(home)
    local vars = Settings.GetSavedVars()
    if not vars then
        return
    end
    vars.offsetNudgeHome = NormalizeOffsetHome(home)
end

function Settings.ArePresetsEnabled()
    local vars = GetSavedVarsOrDefaults()
    return NormalizeBoolean(vars.presetsEnabled, false)
end

function Settings.GetPresetIntensity()
    local vars = GetSavedVarsOrDefaults()
    return private.ClampNumber(tonumber(vars.presetIntensity) or 1.0, 0, 1)
end

-- Whether context-preset state changes should glide rather than snap. Cosmetic;
-- defaults on, mirroring Settings.IsDynamicFovSmooth. The nil fallback only
-- matters if the key is somehow absent.
function Settings.ArePresetTransitionsSmooth()
    local vars = GetSavedVarsOrDefaults()
    return NormalizeBoolean(vars.presetSmoothTransitions, true)
end

-- Lazily-built lookup of valid style ids -> true, plus the resolved off/default
-- ids, sourced from ContextPresets so Settings never hardcodes the style list.
-- Built on first use (not at file load) because ContextPresets may not be
-- available yet at parse time depending on manifest order.
local presetStyleLookup       -- { [styleId] = true } or nil until built
local presetStyleOffId        -- resolved "off" id

local function EnsurePresetStyleInfo()
    if presetStyleLookup then
        return
    end
    presetStyleLookup = {}
    presetStyleOffId = PRESET_STYLE_OFF

    local cp = addon.ContextPresets
    if cp and cp.GetStyleIds then
        for _, id in ipairs(cp.GetStyleIds()) do
            presetStyleLookup[id] = true
        end
        presetStyleOffId = cp.GetOffStyleId and cp.GetOffStyleId() or PRESET_STYLE_OFF
    else
        -- Fallback if the module isn't loaded: only the off id is known-valid.
        presetStyleLookup[PRESET_STYLE_OFF] = true
    end
end

-- Coerce a stored value into a valid style id. Unknown values fall back to off
-- so a state never applies an undefined profile.
local function NormalizePresetStyle(value)
    EnsurePresetStyleInfo()
    if value == nil then
        return presetStyleOffId
    elseif type(value) == "string" and presetStyleLookup[value] then
        return value
    end
    return presetStyleOffId
end

local function GetPresetStateMap(key, normalize)
    local vars = GetSavedVarsOrDefaults()
    local saved = type(vars[key]) == "table" and vars[key] or {}
    local result = {}
    for _, def in ipairs(PRESET_STATE_DEFINITIONS) do
        result[def.id] = normalize(saved[def.id])
    end
    return result
end

local function SetPresetStateValue(key, stateId, value, normalize)
    local vars = Settings.GetSavedVars()
    if not vars then
        return
    end
    if type(vars[key]) ~= "table" then
        vars[key] = {}
    end
    if vars[key][stateId] == nil and not PRESET_STATE_IDS[stateId] then
        return
    end
    vars[key][stateId] = normalize(value)
    Settings.ApplyOptionalFeatureConfig()
end

-- Returns the per-state style map with every state present (defaults to the off
-- style), so callers and ContextPresets.Configure get a complete table.
function Settings.GetPresetStates()
    return GetPresetStateMap("presetStates", NormalizePresetStyle)
end

-- Returns a single preset state's style id (defaults to the off style). Used by
-- the per-state dropdowns so each getFunc avoids allocating the full table.
function Settings.GetPresetState(stateId)
    local vars = GetSavedVarsOrDefaults()
    local saved = type(vars.presetStates) == "table" and vars.presetStates or nil
    return NormalizePresetStyle(saved ~= nil and saved[stateId] or nil)
end

-- Set a single preset state's style id and push the change to the module.
-- Unknown state ids are ignored so a stale UI reference can't corrupt savedvars;
-- the value is normalized so only valid style ids are ever stored.
function Settings.SetPresetState(stateId, style)
    SetPresetStateValue("presetStates", stateId, style, NormalizePresetStyle)
end

-- Coerce a stored per-state intensity into a 0..1 number. A missing or
-- non-numeric value (including installs predating this key) reads as 1.0, so a
-- state runs at full style strength until the user dials it down.
local function NormalizePresetIntensity(value)
    return private.ClampNumber(tonumber(value) or 1.0, 0, 1)
end

-- Returns the per-state intensity map with every state present (defaults to
-- 1.0), so ContextPresets.Configure receives a complete table.
function Settings.GetPresetStateIntensities()
    return GetPresetStateMap("presetStateIntensities", NormalizePresetIntensity)
end

-- Returns a single preset state's intensity (defaults to 1.0). Used by the
-- per-state sliders so each getFunc avoids allocating the full table.
function Settings.GetPresetStateIntensity(stateId)
    local vars = GetSavedVarsOrDefaults()
    local saved = type(vars.presetStateIntensities) == "table" and vars.presetStateIntensities or nil
    return NormalizePresetIntensity(saved ~= nil and saved[stateId] or nil)
end

-- Set a single preset state's intensity (0..1) and push the change to the
-- module. Unknown state ids are ignored so a stale UI reference can't corrupt
-- savedvars; the value is clamped so only valid intensities are ever stored.
function Settings.SetPresetStateIntensity(stateId, value)
    SetPresetStateValue("presetStateIntensities", stateId, value, NormalizePresetIntensity)
end

-- Coerce a stored per-state coalesce delay into a non-negative number of ms. A
-- missing or non-numeric value (including installs predating this key) reads as 0,
-- meaning "release immediately, no coalescing".
local function NormalizePresetCoalesce(value)
    local ms = tonumber(value) or 0
    if ms < 0 then
        ms = 0
    end
    return ms
end

-- Returns the per-state release-delay map (ms) with every state present (defaults
-- to 0), so ContextPresets.Configure receives a complete table.
function Settings.GetPresetStateCoalesces()
    return GetPresetStateMap("presetStateCoalesce", NormalizePresetCoalesce)
end

-- Returns a single preset state's release delay in ms (defaults to 0). Used by the
-- per-state dropdowns so each getFunc avoids allocating the full table.
function Settings.GetPresetStateCoalesce(stateId)
    local vars = GetSavedVarsOrDefaults()
    local saved = type(vars.presetStateCoalesce) == "table" and vars.presetStateCoalesce or nil
    return NormalizePresetCoalesce(saved ~= nil and saved[stateId] or nil)
end

-- Set a single preset state's release delay (ms) and push the change to the
-- module. Unknown state ids are ignored so a stale UI reference can't corrupt
-- savedvars; the value is normalized so only non-negative ms are ever stored.
function Settings.SetPresetStateCoalesce(stateId, value)
    SetPresetStateValue("presetStateCoalesce", stateId, value, NormalizePresetCoalesce)
end

-- ---------------------------------------------------------------------------
-- Preset restore-snapshot persistence (recovery, not a user setting)
-- ---------------------------------------------------------------------------
-- ContextPresets owns WHAT goes in the snapshot; Settings owns persistence.
-- These two functions are the whole contract: the controller pushes its
-- in-memory snapshot here whenever it captures or clears it, and reads it back
-- once on load to recover a camera that a preset was overriding when the
-- session ended. Storing nil clears it.

-- Returns the persisted restore snapshot (a plain camera-values table) or nil.
function Settings.GetPresetRestoreSnapshot()
    local vars = GetSavedVarsOrDefaults()
    local snapshot = vars.presetRestoreSnapshot
    if type(snapshot) ~= "table" then
        return nil
    end
    return snapshot
end

-- Persist (or clear, when snapshot is nil) the restore snapshot. A non-table,
-- non-nil argument is rejected so a bad caller cannot poison savedvars.
function Settings.SetPresetRestoreSnapshot(snapshot)
    local vars = Settings.GetSavedVars()
    if not vars then
        return
    end
    if snapshot == nil then
        vars.presetRestoreSnapshot = nil
        return
    end
    if type(snapshot) ~= "table" then
        return
    end
    vars.presetRestoreSnapshot = snapshot
end

-- ---------------------------------------------------------------------------
-- Over-the-shoulder (shoulder swap) getters/setters
-- ---------------------------------------------------------------------------

local SHOULDER_MODES = { off = true, auto = true, manual = true }
local SHOULDER_SIDES = { left = true, right = true, center = true }
local SHOULDER_STATE_IDS = { "combat", "stealth", "mounted", "swimming", "sprint" }

-- Coerce a stored shoulder mode to a known id, defaulting to "off".
local function NormalizeShoulderMode(value)
    if type(value) == "string" and SHOULDER_MODES[value] then
        return value
    end
    return "off"
end

function Settings.GetShoulderMode()
    local vars = GetSavedVarsOrDefaults()
    return NormalizeShoulderMode(vars.shoulderMode)
end

function Settings.GetShoulderOffset()
    local vars = GetSavedVarsOrDefaults()
    return private.ClampNumber(tonumber(vars.shoulderOffset) or 0.00, 0, 1)
end

function Settings.GetShoulderAutoSide()
    local vars = GetSavedVarsOrDefaults()
    local side = vars.shoulderAutoSide
    return (side == "left" or side == "right") and side or "right"
end

function Settings.GetShoulderManualSide()
    local vars = GetSavedVarsOrDefaults()
    local side = vars.shoulderManualSide
    return (type(side) == "string" and SHOULDER_SIDES[side]) and side or "right"
end

-- Persist the current manual side (called by ShoulderControl on a /bav shoulder
-- toggle so the side survives a reload). Does NOT re-push config: the module
-- already applied the side itself.
function Settings.SetShoulderManualSide(side)
    local vars = Settings.GetSavedVars()
    if not vars then
        return
    end
    if type(side) == "string" and SHOULDER_SIDES[side] then
        vars.shoulderManualSide = side
    end
end

-- Full auto-trigger map with every state present (defaults false), so
-- ShoulderControl.Configure receives a complete table.
function Settings.GetShoulderAutoStates()
    local vars = GetSavedVarsOrDefaults()
    local saved = type(vars.shoulderAutoStates) == "table" and vars.shoulderAutoStates or {}
    local result = {}
    for _, id in ipairs(SHOULDER_STATE_IDS) do
        result[id] = saved[id] and true or false
    end
    return result
end

function Settings.GetShoulderAutoState(stateId)
    local vars = GetSavedVarsOrDefaults()
    local saved = type(vars.shoulderAutoStates) == "table" and vars.shoulderAutoStates or nil
    return (saved ~= nil and saved[stateId]) and true or false
end

function Settings.SetShoulderAutoState(stateId, value)
    local vars = Settings.GetSavedVars()
    if not vars then
        return
    end
    if type(vars.shoulderAutoStates) ~= "table" then
        vars.shoulderAutoStates = {}
    end
    -- Guard against stale UI references writing junk keys.
    local known = false
    for _, id in ipairs(SHOULDER_STATE_IDS) do
        if id == stateId then known = true break end
    end
    if not known then
        return
    end
    vars.shoulderAutoStates[stateId] = value and true or false
    Settings.ApplyOptionalFeatureConfig()
end

-- Recovery snapshot persistence for ShoulderControl (parallels the preset restore
-- snapshot pair). The base is a single number; storing nil clears it.
function Settings.GetShoulderBaseSnapshot()
    local vars = GetSavedVarsOrDefaults()
    return tonumber(vars.shoulderBaseSnapshot)
end

function Settings.SetShoulderBaseSnapshot(value)
    local vars = Settings.GetSavedVars()
    if not vars then
        return
    end
    if value == nil then
        vars.shoulderBaseSnapshot = nil
        return
    end
    local num = tonumber(value)
    if num ~= nil then
        vars.shoulderBaseSnapshot = num
    end
end

function Settings.NormalizeSavedSettings()
    local savedVars = private.savedVars
    if not savedVars then
        return
    end

    -- One-time default migration for installs that still carry the previous
    -- shipped 0.30 step. Any other value is treated as an explicit user choice.
    if savedVars.zoomStepDefaultRevision == nil then
        local storedStep = tonumber(savedVars.zoomStep)
        if storedStep ~= nil and math.abs(storedStep - LEGACY_ZOOM_STEP_DEFAULT) < 0.001 then
            savedVars.zoomStep = ZOOM_STEP
        end
        savedVars.zoomStepDefaultRevision = ZOOM_STEP_DEFAULT_REVISION
    end

    -- Replace the two former smoothing checkboxes with one global response
    -- profile. Existing users who explicitly disabled BOTH old glides keep
    -- instant behavior; every other installation adopts the responsive mode.
    if rawget(savedVars, "cameraResponseMode") == nil then
        local dynamicSmooth = NormalizeBoolean(savedVars.dynamicFovSmooth, true)
        local presetSmooth = NormalizeBoolean(savedVars.presetSmoothTransitions, true)
        savedVars.cameraResponseMode = (not dynamicSmooth and not presetSmooth)
            and "instant" or CAMERA_RESPONSE_DEFAULT
    end

    savedVars.zoomStep = Settings.GetConfiguredZoomStep()
    savedVars.pvpZoomStep = Settings.GetPvpZoomStep()
    savedVars.lastZoomThreshold = Settings.GetConfiguredLastZoomThreshold()
    savedVars.zoomMinMounted = Settings.GetConfiguredMinMountedZoom()
    savedVars.preserveFpvBetweenZones = Settings.ShouldPersistFPVBetweenZones()
    savedVars.cameraResponseMode = Settings.GetCameraResponseMode()
    savedVars.pvpModeEnabled = Settings.IsPvpModeEnabled()
    savedVars.pvpCameraShake = Settings.IsPvpCameraShakeEnabled()
    savedVars.pvpScreenShakeSnapshot = Settings.GetPvpScreenShakeSnapshot()
    savedVars.pvpScouting = nil
    savedVars.pvpMountedScouting = nil
    savedVars.pvpPursuit = nil
    savedVars.pvpPressure = nil
    savedVars.pvpStabilityLock = nil
    savedVars.pvpZoomAssist = nil
    savedVars.pvpManualZoomOverride = nil
    savedVars.pvpLowHealthThreshold = nil
    savedVars.pvpCriticalHealthThreshold = nil
    savedVars.pvpBurstThreshold = nil
    savedVars.pvpHudEnabled = nil
    savedVars.pvpHudLeft = nil
    savedVars.pvpHudTop = nil
    savedVars.pvpHudLayout = nil
    savedVars.offsetNudgeSpeed = Settings.GetOffsetNudgeSpeed()
    savedVars.offsetNudgeOverlay = Settings.IsOffsetNudgeOverlayEnabled()
    savedVars.offsetNudgeHome = Settings.GetOffsetNudgeHome()

    -- Verbosity is a live runtime value as well as a stored one, so normalizing it
    -- also pushes it back onto the addon table: this is what makes the persisted
    -- level take effect on load (suppressOutput -- no chat noise at startup).
    savedVars.debugMode = Settings.GetDebugMode()
    addon.debugMode = savedVars.debugMode
end

-- Read the persisted verbosity, clamped to the valid range. Used at load to seed
-- addon.debugMode and by the panel slider's getFunc.
function Settings.GetDebugMode()
    local vars = GetSavedVarsOrDefaults()
    local level = tonumber(vars.debugMode)
    if level == nil then
        return DEBUG_MODE_DEFAULT
    end
    return math.floor(private.ClampNumber(level, DEBUG_MODE_MIN, DEBUG_MODE_MAX))
end

function Settings.SetDebugMode(level, suppressOutput)
    level = tonumber(level) or 0
    if level >= DEBUG_MODE_MIN and level <= DEBUG_MODE_MAX then
        level = math.floor(level)
        addon.debugMode = level
        -- Persist it: without this the panel slider and /bav debug both died on
        -- /reloadui, so a verbose session could never survive a UI reload.
        if private.savedVars then
            private.savedVars.debugMode = level
        end
        if not suppressOutput then
            private.ChatInfo(SI_BAV_MSG_DEBUG_MODE_SET, private.GetDebugLevelName(level), level)
        end
        return true
    end

    if not suppressOutput then
        private.ChatError(SI_BAV_MSG_INVALID_DEBUG_LEVEL)
    end
    return false
end

function Settings.PrintConfiguration()
    private.ChatInfo(SI_BAV_MSG_CONFIG_SUMMARY,
        Settings.GetConfiguredZoomStep(), Settings.GetConfiguredLastZoomThreshold(), Settings.GetConfiguredMinMountedZoom(),
        private.GetLocalizedBoolean(Settings.ShouldPersistFPVBetweenZones()))
end

-- Push the optional-feature settings into their
-- modules. Centralized here so both the load path and any settings change go
-- through one place. Safe when a module is absent (load-order guard).
function Settings.ApplyOptionalFeatureConfig()
    local addon = BureauOfAcceptableViews

    if addon.CameraResponse and addon.CameraResponse.Configure then
        addon.CameraResponse.Configure({ mode = Settings.GetCameraResponseMode() })
    end

    if addon.DynamicFov and addon.DynamicFov.Configure then
        addon.DynamicFov.Configure({
            enabled = Settings.IsDynamicFovEnabled(),
            nearFov = Settings.GetDynamicFovNear(),
            farFov  = Settings.GetDynamicFovFar(),
        })
    end

    -- ShoulderControl must establish ownership before ContextPresets can take its
    -- first snapshot or apply a bundle. Otherwise a stealth preset could write
    -- shoulder first and have that value captured as the OTS player's base.
    if addon.ShoulderControl and addon.ShoulderControl.Configure then
        addon.ShoulderControl.Configure({
            mode       = Settings.GetShoulderMode(),
            offset     = Settings.GetShoulderOffset(),
            autoSide   = Settings.GetShoulderAutoSide(),
            manualSide = Settings.GetShoulderManualSide(),
            autoStates = Settings.GetShoulderAutoStates(),
            responseMode = Settings.GetCameraResponseMode(),
        })
    end

    if addon.ContextPresets and addon.ContextPresets.Configure then
        addon.ContextPresets.Configure({
            enabled   = Settings.ArePresetsEnabled(),
            intensity = Settings.GetPresetIntensity(),
            states    = Settings.GetPresetStates(),
            stateIntensities = Settings.GetPresetStateIntensities(),
            stateCoalesce = Settings.GetPresetStateCoalesces(),
        })
    end

    if addon.PvpMode and addon.PvpMode.Configure then
        addon.PvpMode.Configure({
            enabled = Settings.IsPvpModeEnabled(),
            cameraShake = Settings.IsPvpCameraShakeEnabled(),
        })
    end

    if addon.OffsetNudge and addon.OffsetNudge.Configure then
        addon.OffsetNudge.Configure({
            speed = Settings.GetOffsetNudgeSpeed(),
            overlay = Settings.IsOffsetNudgeOverlayEnabled(),
            home = Settings.GetOffsetNudgeHome() or false,
        })
    end

end

function Settings.ApplyConfigurationChanges()
    Settings.NormalizeSavedSettings()

    if not private.IsValidThirdPersonZoom(private.GetLastZoom()) then
        private.SetLastZoom(Settings.GetConfiguredMinMountedZoom())
    end

    private.NormalizeSavedCurrentZoom()
    private.SaveCameraState()

    Settings.ApplyOptionalFeatureConfig()
end

function Settings.ResetConfigurationToDefaults(suppressOutput)
    local savedVars = private.savedVars
    if not savedVars then
        return
    end

    savedVars.zoomStep = ZOOM_STEP
    savedVars.lastZoomThreshold = LASTZOOM_THRESHOLD
    savedVars.zoomMinMounted = ZOOM_MIN_MOUNTED
    savedVars.preserveFpvBetweenZones = PRESERVE_FPV_BETWEEN_ZONES
    savedVars.cameraResponseMode = CAMERA_RESPONSE_DEFAULT
    -- Reset deliberately switches the optional features OFF (an inert, neutral
    -- camera) rather than restoring the shipped "on" defaults: a reset is the
    -- user's escape hatch back to vanilla behavior. dynamicFovSmooth is left
    -- untouched -- it's greyed out and irrelevant while Dynamic FOV is off.
    savedVars.dynamicFovEnabled = false
    savedVars.dynamicFovNear = nil
    savedVars.dynamicFovFar = nil
    savedVars.presetsEnabled = false
    savedVars.presetIntensity = 1.0
    -- Store the off STYLE id so a reset leaves the same string-keyed shape every
    -- other write produces.
    savedVars.presetStates = {
        combat = PRESET_STYLE_OFF, werewolf = PRESET_STYLE_OFF, stealth = PRESET_STYLE_OFF,
        interaction = PRESET_STYLE_OFF, mounted = PRESET_STYLE_OFF, swimming = PRESET_STYLE_OFF,
        sprint = PRESET_STYLE_OFF,
    }
    savedVars.presetStateIntensities = {
        combat = 1.0, werewolf = 1.0, stealth = 1.0, interaction = 1.0,
        mounted = 1.0, swimming = 1.0, sprint = 1.0,
    }
    savedVars.presetStateCoalesce = {
        combat = 0, werewolf = 0, stealth = 0, interaction = 0,
        mounted = 0, swimming = 0, sprint = 0,
    }
    -- Reset turns the optional features OFF too (the neutral, vanilla camera the
    -- user expects from a reset). Pushing the off-state through
    -- ApplyConfigurationChanges restores any swung shoulder and stops its events.
    -- Offset/side are left at their stored values -- they are inert while off.
    savedVars.shoulderMode = "off"
    savedVars.shoulderAutoStates = {
        combat = false, stealth = false, mounted = false, swimming = false, sprint = false,
    }
    savedVars.shoulderBaseSnapshot = nil
    savedVars.pvpModeEnabled = false
    savedVars.pvpCameraShake = false
    savedVars.pvpZoomStep = PVP_ZOOM_STEP_DEFAULT
    savedVars.pvpScreenShakeSnapshot = nil
    savedVars.offsetNudgeSpeed = 1.0
    savedVars.offsetNudgeOverlay = true
    savedVars.offsetNudgeHome = nil
    savedVars.zoomStepDefaultRevision = ZOOM_STEP_DEFAULT_REVISION
    -- Verbosity is part of "back to shipped defaults" too: a reset silences the
    -- log again (ApplyConfigurationChanges -> NormalizeSavedSettings pushes this
    -- onto addon.debugMode).
    savedVars.debugMode = DEBUG_MODE_DEFAULT
    Settings.ApplyConfigurationChanges()

    if not suppressOutput then
        private.ChatInfo(SI_BAV_MSG_CONFIG_RESET)
        Settings.PrintConfiguration()
    end
end

function Settings.HandleConfigCommand(args)
    local savedVars = private.savedVars
    if not savedVars then
        return
    end

    local option = args[2]
    local value = args[3]

    if not option or option == "show" or option == "list" then
        Settings.PrintConfiguration()
        private.ChatInfo(SI_BAV_MSG_CONFIG_USAGE)
        return
    end

    if option == "reset" then
        Settings.ResetConfigurationToDefaults()
        return
    end

    if option == "step" then
        local numericValue = tonumber(value)
        if not numericValue then
            private.ChatError(SI_BAV_MSG_USAGE_CONFIG_STEP)
            return
        end
        savedVars.zoomStep = numericValue
        Settings.ApplyConfigurationChanges()
        private.ChatInfo(SI_BAV_MSG_CONFIG_STEP_SET, Settings.GetConfiguredZoomStep())
        Settings.PrintConfiguration()
        return
    end

    if option == "threshold" then
        local numericValue = tonumber(value)
        if not numericValue then
            private.ChatError(SI_BAV_MSG_USAGE_CONFIG_THRESHOLD)
            return
        end
        savedVars.lastZoomThreshold = numericValue
        Settings.ApplyConfigurationChanges()
        private.ChatInfo(SI_BAV_MSG_CONFIG_THRESHOLD_SET, Settings.GetConfiguredLastZoomThreshold())
        Settings.PrintConfiguration()
        return
    end

    if option == "minmounted" or option == "mountedmin" or option == "min" then
        local numericValue = tonumber(value)
        if not numericValue then
            private.ChatError(SI_BAV_MSG_USAGE_CONFIG_MINMOUNTED)
            return
        end
        savedVars.zoomMinMounted = numericValue
        Settings.ApplyConfigurationChanges()
        private.ChatInfo(SI_BAV_MSG_CONFIG_MINMOUNTED_SET, Settings.GetConfiguredMinMountedZoom())
        Settings.PrintConfiguration()
        return
    end

    if option == "preservefpv" or option == "persistfpv" then
        local booleanValue = ParseBooleanArgument(value)
        if booleanValue == nil then
            private.ChatError(SI_BAV_MSG_USAGE_CONFIG_PRESERVEFPV)
            return
        end
        savedVars.preserveFpvBetweenZones = booleanValue
        Settings.ApplyConfigurationChanges()
        private.ChatInfo(SI_BAV_MSG_CONFIG_PRESERVE_SET,
            private.GetLocalizedBoolean(Settings.ShouldPersistFPVBetweenZones()))
        Settings.PrintConfiguration()
        return
    end

    private.ChatError(SI_BAV_MSG_CONFIG_UNKNOWN_OPTION)
end

function Settings.RegisterSettingsPanel()
    local lam = LibAddonMenu2
    if not lam then
        private.LogWarn(SI_BAV_LOG_LAM_MISSING)
        return
    end

    local panelIdentifier = addon.name .. "_Settings"
    local debugChoices = {
        private.GetDebugLevelName(0),
        private.GetDebugLevelName(1),
        private.GetDebugLevelName(2),
        private.GetDebugLevelName(3),
        private.GetDebugLevelName(4),
    }

    -- Resolve the engine FOV range once for the Dynamic FOV sliders so their
    -- bounds always match what the engine will actually accept (35..65 today),
    -- and the user can never push the values outside acceptable limits.
    local dynamicFovMin, dynamicFovMax = Settings.GetDynamicFovRange()

    local function PresetsDisabled()
        return not Settings.ArePresetsEnabled()
    end

    local function DynamicFovDisabled()
        return not Settings.IsDynamicFovEnabled()
    end

    local function PvpModeDisabled()
        return not Settings.IsPvpModeEnabled()
    end

    -- Shoulder-swap control gating: the offset slider is greyed when the mode is
    -- Off; the auto-side dropdown and auto-trigger checkboxes are greyed unless the
    -- mode is Auto (they are meaningless in Off and Manual).
    local function ShoulderDisabled()
        return Settings.GetShoulderMode() == "off"
    end

    local function ShoulderAutoDisabled()
        return Settings.GetShoulderMode() ~= "auto"
    end

    -- ---------------------------------------------------------------------------
    -- Live status helpers (panel dashboard + submenu title tags)
    -- ---------------------------------------------------------------------------
    -- LAM refreshes function-valued `text`/`name` on every setting change and on
    -- panel open (registerForRefresh is set), so these read live each time. The
    -- camera zoom is a snapshot at those moments, not a per-frame ticker -- fine
    -- for an at-a-glance readout. On = the shipped green, off = the muted label
    -- grey, matching the section descriptions' palette.
    local STATUS_COLOR_ON  = "6FCB9F"
    local STATUS_COLOR_OFF = "8C8A82"

    local function Colorize(colorHex, text)
        return string.format("|c%s%s|r", colorHex, text)
    end

    -- A plain colored on/off word for the dashboard rows.
    local function StatusOnOff(enabled)
        return Colorize(enabled and STATUS_COLOR_ON or STATUS_COLOR_OFF,
            GetString(enabled and SI_BAV_STATUS_ON or SI_BAV_STATUS_OFF))
    end

    -- A bracketed colored tag for a submenu title. `word` is already localized.
    local function StatusTag(enabled, word)
        return Colorize(enabled and STATUS_COLOR_ON or STATUS_COLOR_OFF, "[" .. word .. "]")
    end

    local function BoolTag(enabled)
        return StatusTag(enabled, GetString(enabled and SI_BAV_STATUS_ON or SI_BAV_STATUS_OFF))
    end

    -- Shoulder has three states (off/auto/manual); off is muted, the two active
    -- modes share the on color. Used by both the dashboard (word) and the title
    -- tag (bracketed) so they never disagree.
    local function ShoulderModeWord()
        local mode = Settings.GetShoulderMode()
        if mode == "auto" then return GetString(SI_BAV_STATUS_SHOULDER_AUTO) end
        if mode == "manual" then return GetString(SI_BAV_STATUS_SHOULDER_MANUAL) end
        return GetString(SI_BAV_STATUS_OFF)
    end

    local function ShoulderStatusWord()
        local active = Settings.GetShoulderMode() ~= "off"
        return Colorize(active and STATUS_COLOR_ON or STATUS_COLOR_OFF, ShoulderModeWord())
    end

    local function ShoulderTag()
        return StatusTag(Settings.GetShoulderMode() ~= "off", ShoulderModeWord())
    end

    local function OffsetNudgeTag()
        return StatusTag(Settings.HasOffsetNudgeHome(),
            GetString(Settings.HasOffsetNudgeHome() and SI_BAV_STATUS_ON or SI_BAV_STATUS_OFF))
    end

    local function OffsetHomeDisabled()
        return not Settings.HasOffsetNudgeHome()
    end

    local function FormatHomeAxis(key, value)
        local minValue, maxValue
        if addon.CameraSettings and addon.CameraSettings.GetRange then
            minValue, maxValue = addon.CameraSettings.GetRange(key)
        end
        if minValue == nil or value == nil then
            return GetString(SI_BAV_NUDGE_OVERLAY_CENTER)
        end
        local span = value >= 0 and maxValue or math.abs(minValue)
        if span <= 0 then
            return GetString(SI_BAV_NUDGE_OVERLAY_CENTER)
        end
        local percent = zo_round((math.abs(value) / span) * 100)
        if percent <= 0 then
            return GetString(SI_BAV_NUDGE_OVERLAY_CENTER)
        end
        local arrow = "."
        if key == "horizontalOffset" then
            arrow = value < 0 and "<" or ">"
        else
            arrow = value < 0 and "v" or "^"
        end
        return string.format("%s %s", arrow, string.format(GetString(SI_BAV_NUDGE_OVERLAY_PERCENT), percent))
    end

    local function BuildOffsetHomeStatus()
        local home = Settings.GetOffsetNudgeHome()
        if not home then
            return GetString(SI_BAV_SETTING_OFFSET_HOME_STATUS_NONE)
        end
        return string.format(GetString(SI_BAV_SETTING_OFFSET_HOME_STATUS_SET),
            FormatHomeAxis("horizontalOffset", home.horizontal),
            FormatHomeAxis("verticalOffset", home.vertical))
    end

    -- Build the dashboard text: one "Label  value" row per line. The camera row
    -- shows first person when at/under the FPV sentinel, else the third-person
    -- distance. Reads through the same getters the panel controls use, so the
    -- block can never disagree with the controls below it.
    local function StatusRow(labelKey, valueText)
        return string.format("%s  %s", GetString(labelKey), valueText)
    end

    local function BuildStatusText()
        local zoom = (private.GetCameraZoom and private.GetCameraZoom()) or 0
        local cameraValue
        if zoom <= ZOOM_FPV then
            cameraValue = Colorize(STATUS_COLOR_ON, GetString(SI_BAV_STATUS_CAM_FIRST_PERSON))
        else
            cameraValue = string.format("%.2f (%s)", zoom, GetString(SI_BAV_STATUS_CAM_THIRD_PERSON))
        end

        local rows = {
            StatusRow(SI_BAV_STATUS_LABEL_CAMERA, cameraValue),
            StatusRow(SI_BAV_STATUS_LABEL_DYNAMIC_FOV, StatusOnOff(Settings.IsDynamicFovEnabled())),
            StatusRow(SI_BAV_STATUS_LABEL_PRESETS, StatusOnOff(Settings.ArePresetsEnabled())),
            StatusRow(SI_BAV_STATUS_LABEL_SHOULDER, ShoulderStatusWord()),
            StatusRow(SI_BAV_STATUS_LABEL_OFFSET_NUDGE, StatusOnOff(Settings.HasOffsetNudgeHome())),
            StatusRow(SI_BAV_STATUS_LABEL_PVP_MODE, StatusOnOff(Settings.IsPvpModeEnabled())),
        }
        return table.concat(rows, "\n")
    end


    -- Build the per-state preset dropdowns from PRESET_STATE_DEFINITIONS so the
    -- state list stays a single source of truth. Each state picks a STYLE (Off /
    -- Subtle / Cinematic / Action) rather than a plain on/off toggle. Returned as
    -- a flat list that is spliced directly into the Context Presets submenu below.
    local function BuildPresetStateControls()
        local controls = {
            {
                type = "description",
                text = GetString(SI_BAV_LABEL_PRESET_STATES),
                width = "full",
                disabled = PresetsDisabled,
                reference = "BAVSettingsPresetStatesLabel",
            },
        {
            type = "description",
            text = GetString(SI_BAV_LABEL_PRESET_STATES_HELP),
            width = "full",
            disabled = PresetsDisabled,
            reference = "BAVSettingsPresetStatesHelp",
        },
    }

    -- Style id list + parallel display-name list, shared by every dropdown.
    -- Built once here from ContextPresets so the choices always match the
    -- styles the controller actually understands.
    local cp = addon.ContextPresets
    local styleIds = (cp and cp.GetStyleIds)
        and cp.GetStyleIds() or { PRESET_STYLE_OFF }
    local styleNames = {}
    for i = 1, #styleIds do
        styleNames[i] = GetString(StyleNameKey(styleIds[i]))
    end

    for _, def in ipairs(PRESET_STATE_DEFINITIONS) do
        local stateId = def.id

        -- Small vertical spacer before each state group for visual separation
        -- between categories (combat, werewolf, etc.).
        controls[#controls + 1] = {
            type = "description",
            text = " ",
            width = "full",
            disabled = PresetsDisabled,
        }

        controls[#controls + 1] = {
            type = "dropdown",
            name = GetString(def.nameKey),
            tooltip = GetString(def.tooltipKey),
            choices = styleNames,
            choicesValues = styleIds,
            getFunc = function() return Settings.GetPresetState(stateId) end,
            setFunc = function(value) Settings.SetPresetState(stateId, value) end,
            width = "half",
            default = PRESET_STYLE_OFF,
            disabled = PresetsDisabled,
            reference = def.reference,
        }
        -- Per-state intensity, paired on the same row as the style dropdown.
        -- Greyed out both when presets are off globally and when this state's
        -- style is Off (no effect to scale), so the slider can't imply it is
        -- doing something while the state contributes nothing.
        controls[#controls + 1] = {
            type = "slider",
            name = GetString(SI_BAV_SETTING_PRESET_STATE_INTENSITY_NAME),
            tooltip = GetString(SI_BAV_SETTING_PRESET_STATE_INTENSITY_TOOLTIP),
            min = 0,
            max = 100,
            step = 5,
            getFunc = function() return zo_round(Settings.GetPresetStateIntensity(stateId) * 100) end,
            setFunc = function(value) Settings.SetPresetStateIntensity(stateId, value / 100) end,
            width = "half",
            default = 100,
            disabled = function()
                return PresetsDisabled() or Settings.GetPresetState(stateId) == PRESET_STYLE_OFF
            end,
            reference = def.reference .. "Intensity",
        }
        -- Per-state release delay, placed on its own full-width row below the
        -- style+intensity pair so each state's controls form a clear visual
        -- group instead of cramming three half-width items together. Combat uses
        -- the coarse seconds-scale list; every other state uses the fine ms-scale
        -- list. Greyed both when presets are off globally and when this state's
        -- style is Off -- a state that applies no preset has nothing to delay the
        -- release of, so it mirrors the intensity slider's gating above. Defaults
        -- to 0 ("Off").
        local coalesceValues = (stateId == "combat")
            and PRESET_COALESCE_VALUES_COMBAT or PRESET_COALESCE_VALUES_DEFAULT
        controls[#controls + 1] = {
            type = "dropdown",
            name = GetString(SI_BAV_SETTING_PRESET_COALESCE_NAME),
            tooltip = GetString(SI_BAV_SETTING_PRESET_COALESCE_TOOLTIP),
            choices = BuildCoalesceLabels(coalesceValues),
            choicesValues = coalesceValues,
            getFunc = function() return Settings.GetPresetStateCoalesce(stateId) end,
            setFunc = function(value) Settings.SetPresetStateCoalesce(stateId, value) end,
            width = "full",
            default = 0,
            disabled = function()
                return PresetsDisabled() or Settings.GetPresetState(stateId) == PRESET_STYLE_OFF
            end,
            reference = def.reference .. "Coalesce",
        }
    end
    return controls
end

    local panelData = {
        type = "panel",
        name = GetString(SI_BAV_PANEL_NAME),
        displayName = GetString(SI_BAV_PANEL_DISPLAY_NAME),
        author = "|c6FCB9Fmeshlg|r @ArtieFox",
        version = addon.version,
        registerForRefresh = true,
        registerForDefaults = false,
    }

    local optionsData = {
        {
            type = "description",
            text = GetString(SI_BAV_PANEL_INTRO),
            width = "full",
        },
        {
            type = "description",
            text = GetString(SI_BAV_PANEL_OVERVIEW),
            width = "full",
        },
        {
            type = "description",
            text = GetString(SI_BAV_SLASH_HINT),
            width = "full",
        },
        {
            -- Live at-a-glance dashboard. function-valued text so LAM refreshes it
            -- on panel open and after any setting change (registerForRefresh).
            type = "description",
            title = GetString(SI_BAV_STATUS_TITLE),
            text = BuildStatusText,
            width = "full",
            reference = "BAVSettingsStatusBlock",
        },
        {
            type = "header",
            name = GetString(SI_BAV_HEADER_CAMERA),
        },
        {
            type = "description",
            text = GetString(SI_BAV_SECTION_CAMERA_DESCRIPTION),
            width = "full",
        },
        {
            type = "dropdown",
            name = GetString(SI_BAV_SETTING_CAMERA_RESPONSE_NAME),
            tooltip = GetString(SI_BAV_SETTING_CAMERA_RESPONSE_TOOLTIP),
            choices = {
                GetString(CAMERA_RESPONSE_DEFINITIONS[1].nameKey),
                GetString(CAMERA_RESPONSE_DEFINITIONS[2].nameKey),
                GetString(CAMERA_RESPONSE_DEFINITIONS[3].nameKey),
                GetString(CAMERA_RESPONSE_DEFINITIONS[4].nameKey),
            },
            choicesValues = {
                CAMERA_RESPONSE_DEFINITIONS[1].id,
                CAMERA_RESPONSE_DEFINITIONS[2].id,
                CAMERA_RESPONSE_DEFINITIONS[3].id,
                CAMERA_RESPONSE_DEFINITIONS[4].id,
            },
            getFunc = function() return Settings.GetCameraResponseMode() end,
            setFunc = function(value) Settings.SetCameraResponseMode(value) end,
            default = CAMERA_RESPONSE_DEFAULT,
            width = "full",
            reference = "BAVSettingsCameraResponse",
        },
        {
            type = "slider",
            name = GetString(SI_BAV_SETTING_ZOOM_STEP_NAME),
            tooltip = GetString(SI_BAV_SETTING_ZOOM_STEP_TOOLTIP),
            min = ZOOM_STEP_MIN,
            max = ZOOM_STEP_MAX,
            step = 0.05,
            decimals = 2,
            getFunc = function() return Settings.GetConfiguredZoomStep() end,
            setFunc = function(value)
                local vars = private.savedVars
                if not vars then
                    return
                end

                vars.zoomStep = value
                Settings.ApplyConfigurationChanges()
            end,
            default = ZOOM_STEP,
            width = "full",
            reference = "BAVSettingsZoomStep",
        },
        {
            type = "slider",
            name = GetString(SI_BAV_SETTING_THRESHOLD_NAME),
            tooltip = GetString(SI_BAV_SETTING_THRESHOLD_TOOLTIP),
            min = ZOOM_FPV,
            max = ZOOM_MAX,
            step = 0.05,
            decimals = 2,
            getFunc = function() return Settings.GetConfiguredLastZoomThreshold() end,
            setFunc = function(value)
                local vars = private.savedVars
                if not vars then
                    return
                end

                vars.lastZoomThreshold = value
                Settings.ApplyConfigurationChanges()
            end,
            default = LASTZOOM_THRESHOLD,
            width = "full",
            reference = "BAVSettingsThreshold",
        },
        {
            type = "slider",
            name = GetString(SI_BAV_SETTING_MIN_MOUNTED_NAME),
            tooltip = GetString(SI_BAV_SETTING_MIN_MOUNTED_TOOLTIP),
            min = CONFIG_MIN_THIRD_PERSON_ZOOM,
            max = ZOOM_MAX,
            step = 0.05,
            decimals = 2,
            getFunc = function() return Settings.GetConfiguredMinMountedZoom() end,
            setFunc = function(value)
                local vars = private.savedVars
                if not vars then
                    return
                end

                vars.zoomMinMounted = value
                Settings.ApplyConfigurationChanges()
            end,
            default = ZOOM_MIN_MOUNTED,
            width = "full",
            reference = "BAVSettingsMountedFallback",
        },
        {
            type = "submenu",
            name = function()
                return GetString(SI_BAV_HEADER_OFFSET_NUDGE) .. "  " .. OffsetNudgeTag()
            end,
            tooltip = GetString(SI_BAV_SECTION_OFFSET_NUDGE_DESCRIPTION),
            controls = {
        {
            type = "description",
            text = GetString(SI_BAV_SECTION_OFFSET_NUDGE_DESCRIPTION),
            width = "full",
        },
        {
            type = "description",
            text = BuildOffsetHomeStatus,
            width = "full",
            reference = "BAVSettingsOffsetHomeStatus",
        },
        {
            type = "button",
            name = GetString(SI_BAV_SETTING_OFFSET_HOME_REMEMBER_NAME),
            tooltip = GetString(SI_BAV_SETTING_OFFSET_HOME_REMEMBER_TOOLTIP),
            func = function()
                local nudge = addon.OffsetNudge
                if nudge and nudge.RememberHome then
                    nudge.RememberHome()
                end
                if Settings.panel then
                    CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", Settings.panel)
                end
            end,
            width = "full",
            reference = "BAVSettingsOffsetHomeRemember",
        },
        {
            type = "button",
            name = GetString(SI_BAV_SETTING_OFFSET_HOME_RESTORE_NAME),
            tooltip = GetString(SI_BAV_SETTING_OFFSET_HOME_RESTORE_TOOLTIP),
            func = function()
                local nudge = addon.OffsetNudge
                if nudge and nudge.Recenter then
                    nudge.Recenter()
                end
                if Settings.panel then
                    CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", Settings.panel)
                end
            end,
            width = "half",
            disabled = OffsetHomeDisabled,
            reference = "BAVSettingsOffsetHomeRestore",
        },
        {
            type = "button",
            name = GetString(SI_BAV_SETTING_OFFSET_HOME_CLEAR_NAME),
            tooltip = GetString(SI_BAV_SETTING_OFFSET_HOME_CLEAR_TOOLTIP),
            func = function()
                local nudge = addon.OffsetNudge
                if nudge and nudge.ClearHome then
                    nudge.ClearHome()
                end
                if Settings.panel then
                    CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", Settings.panel)
                end
            end,
            width = "half",
            isDangerous = true,
            warning = GetString(SI_BAV_SETTING_OFFSET_HOME_CLEAR_CONFIRM),
            disabled = OffsetHomeDisabled,
            reference = "BAVSettingsOffsetHomeClear",
        },
        {
            type = "slider",
            name = GetString(SI_BAV_SETTING_OFFSET_NUDGE_SPEED_NAME),
            tooltip = GetString(SI_BAV_SETTING_OFFSET_NUDGE_SPEED_TOOLTIP),
            min = 50,
            max = 200,
            step = 10,
            getFunc = function() return zo_round(Settings.GetOffsetNudgeSpeed() * 100) end,
            setFunc = function(value)
                local vars = private.savedVars
                if not vars then
                    return
                end

                vars.offsetNudgeSpeed = private.ClampNumber(value / 100, 0.5, 2.0)
                Settings.ApplyOptionalFeatureConfig()
            end,
            default = 100,
            width = "full",
            disabled = OffsetHomeDisabled,
            reference = "BAVSettingsOffsetNudgeSpeed",
        },
        {
            type = "checkbox",
            name = GetString(SI_BAV_SETTING_OFFSET_NUDGE_OVERLAY_NAME),
            tooltip = GetString(SI_BAV_SETTING_OFFSET_NUDGE_OVERLAY_TOOLTIP),
            getFunc = function() return Settings.IsOffsetNudgeOverlayEnabled() end,
            setFunc = function(value)
                local vars = private.savedVars
                if not vars then
                    return
                end

                vars.offsetNudgeOverlay = value and true or false
                Settings.ApplyOptionalFeatureConfig()
            end,
            default = true,
            width = "full",
            reference = "BAVSettingsOffsetNudgeOverlay",
        },
            },
        },
        {
            type = "header",
            name = GetString(SI_BAV_HEADER_BEHAVIOR),
        },
        {
            type = "description",
            text = GetString(SI_BAV_SECTION_BEHAVIOR_DESCRIPTION),
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BAV_SETTING_PRESERVE_FPV_NAME),
            tooltip = GetString(SI_BAV_SETTING_PRESERVE_FPV_TOOLTIP),
            getFunc = function() return Settings.ShouldPersistFPVBetweenZones() end,
            setFunc = function(value)
                local vars = private.savedVars
                if not vars then
                    return
                end

                vars.preserveFpvBetweenZones = value
                Settings.ApplyConfigurationChanges()
            end,
            default = PRESERVE_FPV_BETWEEN_ZONES,
            width = "full",
            reference = "BAVSettingsPreserveFPV",
        },
        {
            type = "submenu",
            name = function()
                return GetString(SI_BAV_HEADER_DYNAMIC_FOV) .. "  " .. BoolTag(Settings.IsDynamicFovEnabled())
            end,
            tooltip = GetString(SI_BAV_SECTION_DYNAMIC_FOV_DESCRIPTION),
            controls = {
        {
            type = "description",
            text = GetString(SI_BAV_SECTION_DYNAMIC_FOV_DESCRIPTION),
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BAV_SETTING_DYNAMIC_FOV_ENABLED_NAME),
            tooltip = GetString(SI_BAV_SETTING_DYNAMIC_FOV_ENABLED_TOOLTIP),
            getFunc = function() return Settings.IsDynamicFovEnabled() end,
            setFunc = function(value)
                local vars = Settings.GetSavedVars()
                if vars then vars.dynamicFovEnabled = value and true or false end
                Settings.ApplyOptionalFeatureConfig()
            end,
            width = "full",
            default = true,
            reference = "BAVSettingsDynamicFovEnabled",
        },
        {
            -- FOV applied when zoomed all the way in. Bounds come from the
            -- engine FOV range, so the value can never leave acceptable limits.
            -- Disabled (greyed) unless the feature itself is on.
            type = "slider",
            name = GetString(SI_BAV_SETTING_DYNAMIC_FOV_NEAR_NAME),
            tooltip = GetString(SI_BAV_SETTING_DYNAMIC_FOV_NEAR_TOOLTIP),
            min = dynamicFovMin,
            max = dynamicFovMax,
            step = 1,
            decimals = 0,
            getFunc = function() return Settings.GetDynamicFovNearResolved() end,
            setFunc = function(value)
                local vars = Settings.GetSavedVars()
                if vars then vars.dynamicFovNear = value end
                Settings.ApplyOptionalFeatureConfig()
            end,
            default = dynamicFovMin,
            disabled = DynamicFovDisabled,
            width = "full",
            reference = "BAVSettingsDynamicFovNear",
        },
        {
            -- FOV applied when zoomed all the way out. Same engine-bounded range
            -- as the near value; spreading the two apart strengthens the effect,
            -- bringing them together softens it, equal values flatten it.
            type = "slider",
            name = GetString(SI_BAV_SETTING_DYNAMIC_FOV_FAR_NAME),
            tooltip = GetString(SI_BAV_SETTING_DYNAMIC_FOV_FAR_TOOLTIP),
            min = dynamicFovMin,
            max = dynamicFovMax,
            step = 1,
            decimals = 0,
            getFunc = function() return Settings.GetDynamicFovFarResolved() end,
            setFunc = function(value)
                local vars = Settings.GetSavedVars()
                if vars then vars.dynamicFovFar = value end
                Settings.ApplyOptionalFeatureConfig()
            end,
            default = dynamicFovMax,
            disabled = DynamicFovDisabled,
            width = "full",
            reference = "BAVSettingsDynamicFovFar",
        },
        {
            -- One-tap return to the engine endpoints (the widest, most neutral
            -- spread). Clears the saved overrides so near/far fall back to the
            -- resolved range again.
            type = "button",
            name = GetString(SI_BAV_SETTING_DYNAMIC_FOV_RESET_NAME),
            tooltip = GetString(SI_BAV_SETTING_DYNAMIC_FOV_RESET_TOOLTIP),
            func = function()
                local vars = Settings.GetSavedVars()
                if vars then
                    vars.dynamicFovNear = nil
                    vars.dynamicFovFar = nil
                end
                Settings.ApplyOptionalFeatureConfig()
            end,
            disabled = DynamicFovDisabled,
            width = "half",
            reference = "BAVSettingsDynamicFovReset",
        },
            },
        },
        {
            type = "submenu",
            name = function()
                return GetString(SI_BAV_HEADER_CONTEXT_PRESETS) .. "  " .. BoolTag(Settings.ArePresetsEnabled())
            end,
            tooltip = GetString(SI_BAV_SECTION_CONTEXT_PRESETS_DESCRIPTION),
            controls = {
        {
            type = "description",
            text = GetString(SI_BAV_SECTION_CONTEXT_PRESETS_DESCRIPTION),
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BAV_SETTING_PRESETS_ENABLED_NAME),
            tooltip = GetString(SI_BAV_SETTING_PRESETS_ENABLED_TOOLTIP),
            getFunc = function() return Settings.ArePresetsEnabled() end,
            setFunc = function(value)
                local vars = Settings.GetSavedVars()
                if vars then vars.presetsEnabled = value and true or false end
                Settings.ApplyOptionalFeatureConfig()
            end,
            width = "full",
            default = false,
            reference = "BAVSettingsPresetsEnabled",
        },
        {
            type = "slider",
            name = GetString(SI_BAV_SETTING_PRESET_INTENSITY_NAME),
            tooltip = GetString(SI_BAV_SETTING_PRESET_INTENSITY_TOOLTIP),
            min = 0,
            max = 100,
            step = 5,
            getFunc = function() return zo_round(Settings.GetPresetIntensity() * 100) end,
            setFunc = function(value)
                local vars = Settings.GetSavedVars()
                if vars then vars.presetIntensity = private.ClampNumber(value / 100, 0, 1) end
                Settings.ApplyOptionalFeatureConfig()
            end,
            width = "full",
            default = 100,
            disabled = function() return not Settings.ArePresetsEnabled() end,
            reference = "BAVSettingsPresetIntensity",
        },
            },
        },
        {
            type = "submenu",
            name = function()
                return GetString(SI_BAV_HEADER_SHOULDER) .. "  " .. ShoulderTag()
            end,
            tooltip = GetString(SI_BAV_SECTION_SHOULDER_DESCRIPTION),
            controls = {
        {
            type = "description",
            text = GetString(SI_BAV_SECTION_SHOULDER_DESCRIPTION),
            width = "full",
        },
        {
            type = "dropdown",
            name = GetString(SI_BAV_SETTING_SHOULDER_MODE_NAME),
            tooltip = GetString(SI_BAV_SETTING_SHOULDER_MODE_TOOLTIP),
            choices = {
                GetString(SI_BAV_SETTING_SHOULDER_MODE_OFF),
                GetString(SI_BAV_SETTING_SHOULDER_MODE_AUTO),
                GetString(SI_BAV_SETTING_SHOULDER_MODE_MANUAL),
            },
            choicesValues = { "off", "auto", "manual" },
            getFunc = function() return Settings.GetShoulderMode() end,
            setFunc = function(value)
                local vars = Settings.GetSavedVars()
                if vars then vars.shoulderMode = value end
                Settings.ApplyOptionalFeatureConfig()
            end,
            width = "full",
            default = "off",
            reference = "BAVSettingsShoulderMode",
        },
        {
            type = "slider",
            name = GetString(SI_BAV_SETTING_SHOULDER_OFFSET_NAME),
            tooltip = GetString(SI_BAV_SETTING_SHOULDER_OFFSET_TOOLTIP),
            min = 0,
            max = 100,
            step = 5,
            getFunc = function() return zo_round(Settings.GetShoulderOffset() * 100) end,
            setFunc = function(value)
                local vars = Settings.GetSavedVars()
                if vars then vars.shoulderOffset = private.ClampNumber(value / 100, 0, 1) end
                Settings.ApplyOptionalFeatureConfig()
            end,
            width = "full",
            default = 0,
            disabled = ShoulderDisabled,
            reference = "BAVSettingsShoulderOffset",
        },
        {
            type = "dropdown",
            name = GetString(SI_BAV_SETTING_SHOULDER_SIDE_NAME),
            tooltip = GetString(SI_BAV_SETTING_SHOULDER_SIDE_TOOLTIP),
            choices = {
                GetString(SI_BAV_SETTING_SHOULDER_SIDE_LEFT),
                GetString(SI_BAV_SETTING_SHOULDER_SIDE_RIGHT),
            },
            choicesValues = { "left", "right" },
            getFunc = function() return Settings.GetShoulderAutoSide() end,
            setFunc = function(value)
                local vars = Settings.GetSavedVars()
                if vars then vars.shoulderAutoSide = value end
                Settings.ApplyOptionalFeatureConfig()
            end,
            width = "full",
            default = "right",
            disabled = ShoulderAutoDisabled,
            reference = "BAVSettingsShoulderSide",
        },
        {
            type = "description",
            text = GetString(SI_BAV_SETTING_SHOULDER_AUTO_STATES_LABEL),
            width = "full",
            disabled = ShoulderAutoDisabled,
            reference = "BAVSettingsShoulderAutoStatesLabel",
        },
        {
            type = "description",
            text = GetString(SI_BAV_SETTING_SHOULDER_AUTO_HELP),
            width = "full",
            disabled = ShoulderAutoDisabled,
            reference = "BAVSettingsShoulderAutoHelp",
        },
        {
            type = "checkbox",
            name = GetString(SI_BAV_SETTING_PRESET_STATE_COMBAT_NAME),
            tooltip = GetString(SI_BAV_SETTING_SHOULDER_STATE_COMBAT_TOOLTIP),
            getFunc = function() return Settings.GetShoulderAutoState("combat") end,
            setFunc = function(value) Settings.SetShoulderAutoState("combat", value) end,
            width = "half",
            default = false,
            disabled = ShoulderAutoDisabled,
            reference = "BAVSettingsShoulderStateCombat",
        },
        {
            type = "checkbox",
            name = GetString(SI_BAV_SETTING_PRESET_STATE_STEALTH_NAME),
            tooltip = GetString(SI_BAV_SETTING_SHOULDER_STATE_STEALTH_TOOLTIP),
            getFunc = function() return Settings.GetShoulderAutoState("stealth") end,
            setFunc = function(value) Settings.SetShoulderAutoState("stealth", value) end,
            width = "half",
            default = false,
            disabled = ShoulderAutoDisabled,
            reference = "BAVSettingsShoulderStateStealth",
        },
        {
            type = "checkbox",
            name = GetString(SI_BAV_SETTING_PRESET_STATE_MOUNTED_NAME),
            tooltip = GetString(SI_BAV_SETTING_SHOULDER_STATE_MOUNTED_TOOLTIP),
            getFunc = function() return Settings.GetShoulderAutoState("mounted") end,
            setFunc = function(value) Settings.SetShoulderAutoState("mounted", value) end,
            width = "half",
            default = false,
            disabled = ShoulderAutoDisabled,
            reference = "BAVSettingsShoulderStateMounted",
        },
        {
            type = "checkbox",
            name = GetString(SI_BAV_SETTING_PRESET_STATE_SWIMMING_NAME),
            tooltip = GetString(SI_BAV_SETTING_SHOULDER_STATE_SWIMMING_TOOLTIP),
            getFunc = function() return Settings.GetShoulderAutoState("swimming") end,
            setFunc = function(value) Settings.SetShoulderAutoState("swimming", value) end,
            width = "half",
            default = false,
            disabled = ShoulderAutoDisabled,
            reference = "BAVSettingsShoulderStateSwimming",
        },
        {
            type = "checkbox",
            name = GetString(SI_BAV_SETTING_PRESET_STATE_SPRINT_NAME),
            tooltip = GetString(SI_BAV_SETTING_SHOULDER_STATE_SPRINT_TOOLTIP),
            getFunc = function() return Settings.GetShoulderAutoState("sprint") end,
            setFunc = function(value) Settings.SetShoulderAutoState("sprint", value) end,
            width = "half",
            default = false,
            disabled = ShoulderAutoDisabled,
            reference = "BAVSettingsShoulderStateSprint",
        },
            },
        },
        {
            type = "submenu",
            name = function()
                return GetString(SI_BAV_HEADER_PVP_MODE) .. "  " .. BoolTag(Settings.IsPvpModeEnabled())
            end,
            tooltip = GetString(SI_BAV_SECTION_PVP_MODE_DESCRIPTION),
            controls = {
                {
                    type = "description",
                    text = GetString(SI_BAV_SECTION_PVP_MODE_DESCRIPTION),
                    width = "full",
                },
                {
                    type = "description",
                    title = GetString(SI_BAV_PVP_TESTING_FEEDBACK_TITLE),
                    text = GetString(SI_BAV_PVP_TESTING_FEEDBACK_DESCRIPTION),
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BAV_SETTING_PVP_ENABLED_NAME),
                    tooltip = GetString(SI_BAV_SETTING_PVP_ENABLED_TOOLTIP),
                    getFunc = function() return Settings.IsPvpModeEnabled() end,
                    setFunc = function(value)
                        local vars = Settings.GetSavedVars()
                        if vars then vars.pvpModeEnabled = value and true or false end
                        Settings.ApplyOptionalFeatureConfig()
                    end,
                    default = true,
                    width = "full",
                    reference = "BAVSettingsPvpEnabled",
                },
                {
                    type = "slider",
                    name = GetString(SI_BAV_SETTING_PVP_ZOOM_STEP_NAME),
                    tooltip = GetString(SI_BAV_SETTING_PVP_ZOOM_STEP_TOOLTIP),
                    min = ZOOM_STEP_MIN,
                    max = ZOOM_STEP_MAX,
                    step = 0.05,
                    decimals = 2,
                    getFunc = function() return Settings.GetPvpZoomStep() end,
                    setFunc = function(value)
                        local vars = Settings.GetSavedVars()
                        if vars then vars.pvpZoomStep = value end
                        Settings.ApplyConfigurationChanges()
                    end,
                    default = PVP_ZOOM_STEP_DEFAULT,
                    disabled = PvpModeDisabled,
                    width = "full",
                    reference = "BAVSettingsPvpZoomStep",
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BAV_SETTING_PVP_CAMERA_SHAKE_NAME),
                    tooltip = GetString(SI_BAV_SETTING_PVP_CAMERA_SHAKE_TOOLTIP),
                    getFunc = function() return Settings.IsPvpCameraShakeEnabled() end,
                    setFunc = function(value)
                        local vars = Settings.GetSavedVars()
                        if vars then vars.pvpCameraShake = value and true or false end
                        Settings.ApplyOptionalFeatureConfig()
                    end,
                    default = false,
                    disabled = PvpModeDisabled,
                    width = "full",
                    reference = "BAVSettingsPvpCameraShake",
                },
            },
        },
        {
            type = "header",
            name = GetString(SI_BAV_HEADER_CONFIGURATION),
        },
        {
            type = "description",
            text = GetString(SI_BAV_SECTION_CONFIGURATION_DESCRIPTION),
            width = "full",
        },
        {
            type = "button",
            name = GetString(SI_BAV_SETTING_PRINT_CONFIG_NAME),
            tooltip = GetString(SI_BAV_SETTING_PRINT_CONFIG_TOOLTIP),
            func = function() Settings.PrintConfiguration() end,
            width = "half",
            reference = "BAVSettingsPrintConfig",
        },
        {
            type = "button",
            name = GetString(SI_BAV_SETTING_RESET_CONFIG_NAME),
            tooltip = GetString(SI_BAV_SETTING_RESET_CONFIG_TOOLTIP),
            func = function() Settings.ResetConfigurationToDefaults() end,
            width = "half",
            isDangerous = true,
            warning = GetString(SI_BAV_SETTING_RESET_CONFIG_CONFIRM),
            reference = "BAVSettingsResetConfig",
        },
        {
            type = "submenu",
            name = GetString(SI_BAV_HEADER_CAMERA_ACTIONS),
            tooltip = GetString(SI_BAV_SECTION_CAMERA_ACTIONS_DESCRIPTION),
            controls = {
                {
                    type = "description",
                    text = GetString(SI_BAV_SECTION_CAMERA_ACTIONS_DESCRIPTION),
                    width = "full",
                },
                {
                    type = "button",
                    name = GetString(SI_BAV_SETTING_RESET_CAMERA_NAME),
                    tooltip = GetString(SI_BAV_SETTING_RESET_CAMERA_TOOLTIP),
                    func = function() private.ResetCameraState() end,
                    width = "half",
                    isDangerous = true,
                    warning = GetString(SI_BAV_SETTING_RESET_CAMERA_CONFIRM),
                    reference = "BAVSettingsResetCamera",
                },
                {
                    type = "description",
                    text = GetString(SI_BAV_SETTING_RESET_CAMERA_NOTE),
                    width = "full",
                    reference = "BAVSettingsResetCameraNote",
                },
            },
        },
        {
            type = "submenu",
            name = GetString(SI_BAV_HEADER_DEBUG),
            tooltip = GetString(SI_BAV_SECTION_DEBUG_DESCRIPTION),
            controls = {
                {
                    type = "description",
                    text = GetString(SI_BAV_SECTION_DEBUG_DESCRIPTION),
                    width = "full",
                },
                {
                    type = "dropdown",
                    name = GetString(SI_BAV_SETTING_DEBUG_MODE_NAME),
                    tooltip = GetString(SI_BAV_SETTING_DEBUG_MODE_TOOLTIP),
                    choices = debugChoices,
                    choicesValues = {0, 1, 2, 3, 4},
                    -- Read the persisted value (addon.debugMode mirrors it, but the
                    -- stored key is the source of truth the panel's default compares
                    -- against).
                    getFunc = function() return Settings.GetDebugMode() end,
                    setFunc = function(value) Settings.SetDebugMode(value, true) end,
                    default = DEBUG_MODE_DEFAULT,
                    width = "full",
                    reference = "BAVSettingsDebugMode",
                },
            },
        }
    }

    -- Splice the per-state preset checkboxes into the Context Presets submenu,
    -- right after the intensity slider, so the panel layout stays declarative
    -- while the state list (PRESET_STATE_DEFINITIONS) remains a single source of
    -- truth. We locate the submenu by the intensity slider it contains rather
    -- than by position, so reordering sections above can't break it.
    for _, control in ipairs(optionsData) do
        if control.type == "submenu" and control.controls then
            local hasIntensity = false
            for _, child in ipairs(control.controls) do
                if child.reference == "BAVSettingsPresetIntensity" then
                    hasIntensity = true
                    break
                end
            end
            if hasIntensity then
                for _, stateControl in ipairs(BuildPresetStateControls()) do
                    control.controls[#control.controls + 1] = stateControl
                end
                break
            end
        end
    end

    local panel = lam:RegisterAddonPanel(panelIdentifier, panelData)
    lam:RegisterOptionControls(panelIdentifier, optionsData)
    Settings.panel = panel
end

-- Opens the settings panel programmatically (used by the `/bav settings`
-- slash sub-command). Returns true when the panel was opened, false when the
-- LibAddonMenu dependency is unavailable so the caller can report it.
function Settings.OpenPanel()
    local lam = LibAddonMenu2
    if not lam or not Settings.panel then
        return false
    end

    lam:OpenToPanel(Settings.panel)
    return true
end

addon.SetDebugMode = Settings.SetDebugMode
addon.PrintConfiguration = Settings.PrintConfiguration
addon.HandleConfigCommand = Settings.HandleConfigCommand
addon.RegisterSettingsPanel = Settings.RegisterSettingsPanel
addon.OpenSettingsPanel = Settings.OpenPanel
