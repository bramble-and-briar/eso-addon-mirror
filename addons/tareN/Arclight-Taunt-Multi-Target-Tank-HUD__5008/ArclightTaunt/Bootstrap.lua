-- Arclight Taunt 1.0.3 | Bootstrap module
-- Loaded in manifest order; requires Core.lua and uses its shared namespace.
local A = ArclightTaunt
local T = A.T
local ADDON = A.ADDON
local ALERT_SOUNDS = A.ALERT_SOUNDS
local EM = A.EM
local FiniteBoundedNumber = A.FiniteBoundedNumber
local MAX_PER_COLUMN = A.MAX_PER_COLUMN
local MEDIA_BAR_ESO = A.MEDIA_BAR_ESO
local MEDIA_BAR_FLAT = A.MEDIA_BAR_FLAT
local MEDIA_BAR_SIGNAL = A.MEDIA_BAR_SIGNAL
local MEDIA_BAR_SIGNATURE = A.MEDIA_BAR_SIGNATURE
local MEDIA_BG_CARBON = A.MEDIA_BG_CARBON
local MEDIA_BG_CARBON_PATH = A.MEDIA_BG_CARBON_PATH
local MEDIA_BG_NONE = A.MEDIA_BG_NONE
local MEDIA_BG_OBSIDIAN = A.MEDIA_BG_OBSIDIAN
local MEDIA_BG_OBSIDIAN_PATH = A.MEDIA_BG_OBSIDIAN_PATH
local MEDIA_TEXTURE_SIGNAL = A.MEDIA_TEXTURE_SIGNAL
local MEDIA_TEXTURE_SIGNATURE = A.MEDIA_TEXTURE_SIGNATURE
local MEDIA_TRACK_PATH = A.MEDIA_TRACK_PATH
local TAUNT_IDS = A.TAUNT_IDS
local defaults = A.defaults

local function OnLoaded(_, name)
    if name ~= ADDON then return end
    EM:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    A.saved = ZO_SavedVars:NewAccountWide("ArclightTauntSaved", 1, nil, defaults)
    -- Show one unobtrusive setup tip only to genuinely new installations.
    -- Older profiles already have a settingsVersion from previous migrations.
    -- Do not show a welcome banner after each update or UI reload.
    local firstInstall = A.saved.welcomeNoticeShown ~= true
        and (tonumber(A.saved.settingsVersion) or 0) == 0
    if not firstInstall then A.saved.welcomeNoticeShown = true end
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
    -- 0.8.6 removes the redundant status header from the live HUD. Older
    -- saves never stored whether the former default was chosen intentionally;
    -- migrate once to the new default, while leaving the checkbox available.
    if (tonumber(A.saved.settingsVersion) or 0) < 806 then
        A.saved.header = false
        A.saved.settingsVersion = 806
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
    -- 0.9.10 updates defaults only (larger fresh-install HUD, immunity/stack
    -- badges off by default) and deliberately preserves existing preferences.
    if (tonumber(A.saved.settingsVersion) or 0) < 910 then
        A.saved.settingsVersion = 910
    end
    -- 1.0.0: release metadata and corrected displayed HUD-size default only.
    -- Never replace an existing player's settings when upgrading from beta.
    A.saved.settingsVersion = math.max(tonumber(A.saved.settingsVersion) or 0, 1000)
    -- The old pulse option was removed: no dangling UI state is needed.
    A.saved.pulseDanger = nil
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
    A.saved.bossAlertOpacity = math.floor(FiniteBoundedNumber(A.saved.bossAlertOpacity, defaults.bossAlertOpacity, 60, 100) / 5 + 0.5) * 5
    A.saved.bossAlertOffsetY = math.floor(FiniteBoundedNumber(A.saved.bossAlertOffsetY, defaults.bossAlertOffsetY, 50, 600))
    if not ALERT_SOUNDS[A.saved.bossAlertSoundKey] then
        A.saved.bossAlertSoundKey = defaults.bossAlertSoundKey
    end
    A.saved.bossMode = ({strict=true, dangerous=true, comprehensive=true})[A.saved.bossMode]
        and A.saved.bossMode or defaults.bossMode
    A.saved.texturedTrack = A.saved.texturedTrack ~= false
    A.saved.sortMode = (A.saved.sortMode == "stable") and "stable" or "remaining"
    A.saved.showImmunity = A.saved.showImmunity ~= false
    A.saved.showTauntStacks = A.saved.showTauntStacks ~= false
    A.saved.highlightTarget = A.saved.highlightTarget ~= false
    A.saved.focusStyle = (A.saved.focusStyle == "subtle") and "subtle" or "strong"
    A.saved.onlyMine = A.saved.onlyMine ~= false
    A.saved.header = A.saved.header == true
    A.saved.rowGap = math.floor(FiniteBoundedNumber(A.saved.rowGap, defaults.rowGap, 0, 8))
    A.saved.barDisplay = (A.saved.barDisplay == "full") and "full" or "compact"
    A.saved.warningAt = math.floor(FiniteBoundedNumber(A.saved.warningAt, defaults.warningAt, 5, 12))
    A.saved.dangerAt = math.floor(FiniteBoundedNumber(A.saved.dangerAt, defaults.dangerAt, 1, 8))
    if A.saved.dangerAt >= A.saved.warningAt then
        A.saved.warningAt = math.min(12, A.saved.dangerAt + 1)
    end
    A.saved.removeDead = A.saved.removeDead ~= false
    A.saved.hideInMenus = A.saved.hideInMenus ~= false
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
    A.LMP = LibMediaProvider
    if A.LMP then
        -- Only original files created for Arclight Taunt are bundled.
        -- A.LMP exposes them to Arclight and any other addon that supports statusbars.
        -- Do not call SetTexture with an invalid/unresolved resource path.
        A.LMP:Register("statusbar", MEDIA_BAR_SIGNATURE, MEDIA_TEXTURE_SIGNATURE)
        A.LMP:Register("statusbar", MEDIA_BAR_SIGNAL, MEDIA_TEXTURE_SIGNAL)
        A.LMP:Register("background", MEDIA_BG_OBSIDIAN, MEDIA_BG_OBSIDIAN_PATH)
        A.LMP:Register("background", MEDIA_BG_CARBON, MEDIA_BG_CARBON_PATH)
        A.LMP:Register("background", "Arclight (Fassung)", MEDIA_TRACK_PATH)
        A.LMP:Register("statusbar", MEDIA_BAR_ESO,
            "EsoUI/Art/miscellaneous/progressbar_genericfill_tall.dds")
    end
    -- Missing providers may register later or return after an update. Keep
    -- valid saved keys; Media.lua resolves a temporary display fallback.
    for _, key in ipairs({"fontKey", "timerFontKey", "backgroundKey", "barKey"}) do
        if type(A.saved[key]) ~= "string" or A.saved[key] == "" then A.saved[key] = defaults[key] end
    end
    A.inCombat = type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true or false
    A.MakeUI()
    A.ApplyMedia()
    A.MakeSettings()
    if CALLBACK_MANAGER and type(CALLBACK_MANAGER.RegisterCallback) == "function" then
        CALLBACK_MANAGER:RegisterCallback("LibMediaProvider_Registered", function(mediaType, key)
            local selected = (mediaType == "font" and (key == A.saved.fontKey or key == A.saved.timerFontKey))
                or (mediaType == "statusbar" and key == A.saved.barKey)
                or (mediaType == "background" and key == A.saved.backgroundKey)
            if selected then
                if A.RefreshMediaChoices then A.RefreshMediaChoices(mediaType) end
                A.ApplyMedia()
                A.Tick()
            end
        end)
    end
    for id in pairs(TAUNT_IDS) do
        local eventName = ADDON .. "_Effect_" .. tostring(id)
        EM:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, A.EffectChanged)
        EM:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id)
    end
    EM:RegisterForEvent(ADDON .. "_Combat", EVENT_PLAYER_COMBAT_STATE, A.CombatChanged)
    EM:RegisterForEvent(ADDON .. "_Reticle", EVENT_RETICLE_TARGET_CHANGED, A.ReticleChanged)
    local deathResults = {ACTION_RESULT_DIED, ACTION_RESULT_DIED_XP}
    for i, result in ipairs(deathResults) do
        if result then
            local deathEvent = ADDON .. "_Death_" .. i
            EM:RegisterForEvent(deathEvent, EVENT_COMBAT_EVENT, A.CombatDeath)
            EM:AddFilterForEvent(deathEvent, EVENT_COMBAT_EVENT,
                REGISTER_FILTER_COMBAT_RESULT, result)
        end
    end
    EM:RegisterForEvent(ADDON .. "_ReticleDeath", EVENT_UNIT_DEATH_STATE_CHANGED, A.ReticleDeath)
    if EVENT_BOSSES_CHANGED then
        EM:RegisterForEvent(ADDON .. "_Bosses", EVENT_BOSSES_CHANGED, function()
            A.TargetChanged()
            A.Tick()
        end)
    end
    -- Tick starts periodic updates only when there is work to do.
    if firstInstall and EVENT_PLAYER_ACTIVATED then
        local welcomeEvent = ADDON .. "_Welcome"
        EM:RegisterForEvent(welcomeEvent, EVENT_PLAYER_ACTIVATED, function()
            EM:UnregisterForEvent(welcomeEvent, EVENT_PLAYER_ACTIVATED)
            if A.saved.welcomeNoticeShown then return end
            A.saved.welcomeNoticeShown = true
            A.Chat(T("Welcome! Tip: Open ESC > Settings > Add-ons > Arclight Taunt to customize the HUD."))
        end)
    end
    A.Tick()
end
EM:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnLoaded)

-- Public entry points used across modules.
