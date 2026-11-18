-- Arclight Taunt 1.3.1 | Saved settings module
-- Loaded in manifest order; Core.lua supplies defaults and normalization helpers.
local A = ArclightTaunt
local ALERT_SOUNDS = A.ALERT_SOUNDS
local FiniteBoundedNumber = A.FiniteBoundedNumber
local MAX_PER_COLUMN = A.MAX_PER_COLUMN
local MEDIA_BAR_FLAT = A.MEDIA_BAR_FLAT
local MEDIA_BAR_SIGNAL = A.MEDIA_BAR_SIGNAL
local MEDIA_BG_NONE = A.MEDIA_BG_NONE
local MEDIA_BG_OBSIDIAN = A.MEDIA_BG_OBSIDIAN
local defaults = A.defaults

local function MigrateSettings()
    -- Migrate untouched 0.5 defaults 5/2 to 7/4 without overriding custom
    -- values. An old value equal to the old default cannot be distinguished
    -- from a manually selected identical value.
    if (tonumber(A.saved.settingsVersion) or 0) < 501 then
        if tonumber(A.saved.warningAt) == 5 then A.saved.warningAt = 7 end
        if tonumber(A.saved.dangerAt) == 2 then A.saved.dangerAt = 4 end
        A.saved.settingsVersion = 501
    end
    -- Upgrade 0.5.1 -> 0.6: the former default was "show expired".
    -- There is no explicit-change flag in older saves, so the first upgrade
    -- resets this option to the new off-by-default behavior. Afterwards it is
    -- fully user-configurable and will no longer be changed by migrations.
    if (tonumber(A.saved.settingsVersion) or 0) < 600 then
        A.saved.showExpired = false
        A.saved.settingsVersion = 600
    end
    -- Upgrade to 0.8.2: users still on the original Glatt preset get
    -- Signal once. Explicitly selected Signature/third-party media are kept.
    -- Older releases did not store whether Glatt was selected intentionally,
    -- so this one-time migration cannot tell those two cases apart.
    if (tonumber(A.saved.settingsVersion) or 0) < 802 then
        if A.saved.barKey == MEDIA_BAR_FLAT then
            A.saved.barKey = MEDIA_BAR_SIGNAL
        end
        A.saved.settingsVersion = 802
    end
    -- 0.9: restore the clean urgency-tinted background. Carbon remains
    -- explicitly available; saved custom third-party media are preserved.
    -- Previous defaults were Obsidian and a textured track; as with older
    -- migrations, explicit selections equal to those defaults cannot be told apart.
    if (tonumber(A.saved.settingsVersion) or 0) < 900 then
        if A.saved.backgroundKey == MEDIA_BG_OBSIDIAN then
            A.saved.backgroundKey = MEDIA_BG_NONE
        end
        A.saved.texturedTrack = false
        A.saved.settingsVersion = 900
    end
    -- 0.9.3: a longer, lower-on-screen boss warning for fresh installs.
    -- Migrate only the two former defaults. Explicit nondefault values survive.
    -- Older releases did not record user intent when the chosen value was
    -- identical to the default, so those exact values will also be updated.
    if (tonumber(A.saved.settingsVersion) or 0) < 903 then
        if tonumber(A.saved.bossAlertDuration) == 2.0 then
            A.saved.bossAlertDuration = 2.5
        end
        if tonumber(A.saved.bossAlertOffsetY) == 155 then
            A.saved.bossAlertOffsetY = 290
        end
        A.saved.settingsVersion = 903
    end
    for k, v in pairs(defaults) do
        if A.saved[k] == nil then A.saved[k] = v end
    end
    -- 0.9.5: move only the former early-warning default to 2.5 seconds.
    -- User-selected non-default thresholds remain unchanged. Old releases
    -- could not distinguish an explicitly chosen 2.0 from the old default.
    if (tonumber(A.saved.settingsVersion) or 0) < 905 then
        if tonumber(A.saved.bossEarlySeconds) == 2.0 then
            A.saved.bossEarlySeconds = 2.5
        end
        A.saved.settingsVersion = 905
    end
    -- 0.9.10 updated defaults without replacing existing preferences.
    if (tonumber(A.saved.settingsVersion) or 0) < 910 then
        A.saved.settingsVersion = 910
    end
    -- 1.0.0: release metadata and corrected displayed HUD-size default only.
    -- Never replace an existing player's settings when upgrading from beta.
    A.saved.settingsVersion = math.max(tonumber(A.saved.settingsVersion) or 0, 1000)
end

local function NormalizeSettings()
    -- The old pulse option was removed: no dangling UI state is needed.
    A.saved.pulseDanger = nil
    A.saved.showStunWarning = nil -- retired, unreleased experiments
    A.saved.urgencyCues = nil
    A.saved.showUnconfirmedReticle = A.saved.showUnconfirmedReticle == true
    A.saved.x = FiniteBoundedNumber(A.saved.x, defaults.x, -10000, 10000)
    A.saved.y = FiniteBoundedNumber(A.saved.y, defaults.y, -10000, 10000)
    A.saved.columns = (A.saved.columns == 2) and 2 or 1
    A.saved.limit = math.floor(FiniteBoundedNumber(A.saved.limit, defaults.limit, 4, MAX_PER_COLUMN))
    A.saved.opacity = FiniteBoundedNumber(A.saved.opacity, defaults.opacity, 0.25, 1)
    A.saved.width = math.floor(FiniteBoundedNumber(A.saved.width, defaults.width, 240, 360))
    A.saved.subtleWarningBg = A.saved.subtleWarningBg ~= false
    A.saved.showExpired = A.saved.showExpired == true
    A.saved.showBossIcon = A.saved.showBossIcon ~= false
    A.saved.highlightBossNames = A.saved.highlightBossNames ~= false
    A.saved.pinBosses = A.saved.pinBosses == true
    A.saved.bossAlertText = A.saved.bossAlertText ~= false
    A.saved.bossAlertSound = A.saved.bossAlertSound == true
    A.saved.bossAlertElites = A.saved.bossAlertElites == true
    A.saved.bossAlertDuration = math.floor(
        FiniteBoundedNumber(A.saved.bossAlertDuration, defaults.bossAlertDuration, 1, 4) * 2 + 0.5
    ) / 2
    A.saved.bossAlertOpacity = math.floor(FiniteBoundedNumber(A.saved.bossAlertOpacity, defaults.bossAlertOpacity, 60, 100) + 0.5)
    A.saved.bossAlertOffsetY = math.floor(FiniteBoundedNumber(A.saved.bossAlertOffsetY, defaults.bossAlertOffsetY, 50, 600))
    if not ALERT_SOUNDS[A.saved.bossAlertSoundKey] then
        A.saved.bossAlertSoundKey = defaults.bossAlertSoundKey
    end
    A.saved.bossEarlySound = A.saved.bossEarlySound == true
    if not ALERT_SOUNDS[A.saved.bossEarlySoundKey] then
        A.saved.bossEarlySoundKey = defaults.bossEarlySoundKey
    end
    -- Keep strict selection; the removed deadly-only tier joins the broader
    -- strong-enemy option. Existing warning preferences remain independent.
    A.saved.bossMode = A.saved.bossMode == "strict" and "strict" or defaults.bossMode
    A.saved.texturedTrack = A.saved.texturedTrack ~= false
    A.saved.sortMode = nil -- the former alternative ordering has been removed
    A.saved.showImmunity, A.saved.showTauntStacks = nil, nil -- obsolete diagnostic preferences
    A.saved.highlightTarget = A.saved.highlightTarget ~= false
    A.saved.reduceAnimations = A.saved.reduceAnimations == true
    A.saved.focusStyle = nil -- obsolete visual designs; never restore their controls
    A.saved.targetHighlightStyle = A.saved.targetHighlightStyle == "strong" and "strong" or "subtle"
    A.saved.onlyMine = nil -- remove the obsolete tracking-mode preference
    A.saved.trackPlayerTargets = A.saved.trackPlayerTargets == true
    A.saved.header = nil -- obsolete status header removed
    A.saved.rowGap = math.floor(FiniteBoundedNumber(A.saved.rowGap, defaults.rowGap, 0, 8))
    if A.saved.rowHeightExtra ~= nil then
        A.saved.rowHeightExtra = math.floor(FiniteBoundedNumber(A.saved.rowHeightExtra, 0, 0, 40) + 0.5)
    end
    -- Legacy percentage is converted once after the selected fonts are measured.
    if A.saved.rowHeightExtra == nil then
        A.saved.rowHeight = FiniteBoundedNumber(A.saved.rowHeight, 100, 80, 160)
    else
        A.saved.rowHeight = nil
    end
    A.saved.barDisplay = (A.saved.barDisplay == "full") and "full" or "compact"
    A.saved.warningAt = math.floor(FiniteBoundedNumber(A.saved.warningAt, defaults.warningAt, 5, 12))
    A.saved.dangerAt = math.floor(FiniteBoundedNumber(A.saved.dangerAt, defaults.dangerAt, 1, 8))
    if A.saved.dangerAt >= A.saved.warningAt then
        A.saved.warningAt = math.min(12, A.saved.dangerAt + 1)
    end
    A.saved.removeDead = A.saved.removeDead ~= false
    A.saved.lockPosition = A.saved.lockPosition ~= false
    A.saved.hideInMenus = A.saved.hideInMenus ~= false
    A.saved.showTauntList = A.saved.showTauntList ~= false
    A.saved.mirrorTauntList = A.saved.mirrorTauntList == true
    A.saved.highContrast = A.saved.highContrast == true
    A.saved.bossListOnly = A.saved.bossListOnly == true
    A.saved.reticleBossOnly = A.saved.reticleBossOnly == true
    A.saved.reticleCombatOnly = nil -- live indicator is always combat-only
    A.saved.reticleBossMarker = nil -- retire the unshipped visual experiment
    if A.saved.reticleStyle ~= "circle" and A.saved.reticleStyle ~= "bar" then A.saved.reticleStyle = "off" end
    -- Preserve an enabled shape; remember it across disable/enable without
    -- changing the existing style field or any saved size/placement.
    if A.saved.reticleStyle ~= "off" then A.saved.reticleLastStyle = A.saved.reticleStyle
    elseif A.saved.reticleLastStyle ~= "bar" then A.saved.reticleLastStyle = "circle" end
    local reticleDefaults = A.ReticleProfileDefaults()
    A.saved.reticleTrackOpacity = math.floor(FiniteBoundedNumber(A.saved.reticleTrackOpacity, reticleDefaults.opacity, 0, 100) + 0.5)
    A.saved.reticleSize = math.floor(FiniteBoundedNumber(A.saved.reticleSize, reticleDefaults.size, 16, 40))
    A.saved.reticleBarHeight = math.floor(FiniteBoundedNumber(A.saved.reticleBarHeight, defaults.reticleBarHeight, 2, 8) * 2 + 0.5) / 2
    A.saved.reticleRingWeight = math.floor(FiniteBoundedNumber(A.saved.reticleRingWeight, defaults.reticleRingWeight, 2, 8) * 2 + 0.5) / 2
    A.saved.reticleOffsetX = math.floor(FiniteBoundedNumber(A.saved.reticleOffsetX, reticleDefaults.x, -10000, 10000))
    A.saved.reticleOffsetY = math.floor(FiniteBoundedNumber(A.saved.reticleOffsetY, reticleDefaults.y, -10000, 10000))
    A.InitializeReticleProfiles()
    A.saved.smartTime = A.saved.smartTime ~= false
    A.saved.growUp = A.saved.growUp == true
    A.saved.fitToScreen = A.saved.fitToScreen ~= false
    -- New installs default to enabled; respect existing users who disabled it.
    A.saved.bossEarlyWarning = A.saved.bossEarlyWarning ~= false
    A.saved.bossEarlySeconds = math.floor(FiniteBoundedNumber(
        A.saved.bossEarlySeconds, defaults.bossEarlySeconds, 1, 4) * 2 + 0.5) / 2
    A.saved.scale = FiniteBoundedNumber(A.saved.scale, defaults.scale, 0.7, 1.6)
    A.saved.fontSize = math.floor(FiniteBoundedNumber(A.saved.fontSize, defaults.fontSize, 85, 115))
    A.saved.barHeight = math.floor(FiniteBoundedNumber(A.saved.barHeight, defaults.barHeight, 2, 6))
end

-- Reticle profile helpers must be loaded before Bootstrap calls this.
-- Font-dependent row-height conversion remains in ApplyMedia after font measurement.
function A.LoadSettings()
    -- Account-wide presentation preferences are intentionally shared across
    -- megaservers. No server-specific identities, combat records or progress
    -- are persisted. Keep the existing profile/schema to preserve user choices.
    -- The crosshair display is opt-in on fresh installs and upgrades alike.
    -- Explicit bar/circle selections remain ordinary saved preferences.
    local loadDefaults = {}
    for key, value in pairs(defaults) do
        if key ~= "reticleSize" and key ~= "reticleOffsetX" and key ~= "reticleOffsetY" and key ~= "reticleTrackOpacity" then
            loadDefaults[key] = value
        end
    end
    A.saved = ZO_SavedVars:NewAccountWide("ArclightTauntSaved", 1, nil, loadDefaults)
    -- Show one unobtrusive setup tip only to genuinely new installations.
    -- Older profiles already have a settingsVersion from previous migrations.
    -- Do not show a welcome banner after each update or UI reload.
    local firstInstall = A.saved.welcomeNoticeShown ~= true
        and (tonumber(A.saved.settingsVersion) or 0) == 0
    if not firstInstall then A.saved.welcomeNoticeShown = true end
    MigrateSettings()
    NormalizeSettings()
    return firstInstall
end
