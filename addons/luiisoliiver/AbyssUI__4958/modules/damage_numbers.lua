local ADDON_NAME = "AbyssUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_DamageNumbers"

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI
local DamageNumbers = {}
NAGA_UI.DamageNumbers = DamageNumbers

local DEFAULT_SETTINGS =
{
    enabled = true,
    unlocked = false,
    hideDefaultDamage = true,
    critSoundEnabled = true,
    fontKey = "antique",
    textEffect = "none",
    critSoundKey = "CONSOLE_GAME_ENTER",
    normalFontSize = 56,
    critFontSize = 78,
    durationMS = 820,
    spread = 118,
    drift = 55,
    bigHitThreshold = 25000,
    maxActive = 36,
    soundThrottleMS = 120,
    savedSctSettings = {},
    damageDoneMinigame =
    {
        enabled = false,
        unlocked = false,
        scale = 100,
        soundEnabled = true,
        tierSoundsEnabled = true,
        faceRight = false,
        displayMode = "damageDone",
        graceMS = 1250,
        animationIntensity = 80,
        showTimer = true,
        showModeLabel = true,
        showHitCount = true,
        showPeakLabel = true,
    },
}

local MOVEMENT_MULTIPLIER = 0.38
local BIG_HIT_MOVEMENT_MULTIPLIER = 0.08
local NORMAL_START_SCALE = 2.85
local CRIT_START_SCALE = 3.45
local NORMAL_END_SCALE = 1
local CRIT_END_SCALE = 1.18
local POP_PROGRESS_PORTION = 0.18
local DEFAULT_SPAWN_OFFSET_X = 0
local DEFAULT_SPAWN_OFFSET_Y = -45
local DEFAULT_MINIGAME_POSITION = { x = 470, y = 250 }
local MINIGAME_WIDTH = 560
local MINIGAME_HEIGHT = 280
local MINIGAME_TILT_RADIANS = math.rad(6)
local MINIGAME_SKEW_RADIANS = math.rad(4)
local MINIGAME_DRAIN_MS = 1500
local MINIGAME_COUNT_MS = 170
local MINIGAME_IMPACT_MS = 430
local MINIGAME_CRIT_IMPACT_MS = 620
local MINIGAME_FINISH_MS = 900
local MINIGAME_FEEDBACK_MS = 100
local MINIGAME_DELTA_MS = 560
local MINIGAME_SOUND_THROTTLE_MS = 110
local MINIGAME_DELTA_COUNT = 4
local MINIGAME_SPARK_COUNT = 12
local MINIGAME_HEAVY_HIT = 40000
local MINIGAME_FONT_FACE = "EsoUI/Common/Fonts/TrajanPro-Regular.slug"
local MINIGAME_EDGE_TEXTURE = "EsoUI/Art/Miscellaneous/Gamepad/edgeframeGamepadBorder_thin.dds"
local MINIGAME_HIGHLIGHT_TEXTURE = "EsoUI/Art/HUD/lootHistory_highlight.dds"

local MINIGAME_MILESTONES =
{
    damageDone = {100000, 250000, 500000, 1000000, 2500000, 5000000},
    dps = {20000, 40000, 60000, 80000, 110000, 140000},
}

local MINIGAME_SOUND_KEYS =
{
    normal = "OUTFIT_WEAPON_TYPE_RUNE",
    crit = "VENGEANCE_PERK_EQUIPPED",
    milestone = "VENGEANCE_PERK_DROP",
}

local MINIGAME_TIER_SOUND_KEYS =
{
    "CHAMPION_STAR_STAGE_UP",
    "VENGEANCE_PERK_DROP",
    "CODE_REDEMPTION_SUCCESS",
    "VENGEANCE_PERK_EQUIPPED",
    "BATTLEGROUND_ROUND_RECAP_SCREEN_WIN",
    "BATTLEGROUND_ROUND_RECAP_SCREEN_FINAL_WIN",
}

local FONT_FACES =
{
    antique = "$(ANTIQUE_FONT)",
    handwritten = "$(HANDWRITTEN_FONT)",
    stoneTablet = "$(STONE_TABLET_FONT)",
    proseAntique = "EsoUI/Common/Fonts/ProseAntiquePSMT.slug",
    trajan = "EsoUI/Common/Fonts/TrajanPro-Regular.slug",
    univers57 = "EsoUI/Common/Fonts/Univers57.slug",
    univers67 = "EsoUI/Common/Fonts/Univers67.slug",
    universCyrillic = "EsoUI/Common/Fonts/Univers57Cyrillic-Condensed.slug",
    universCyrillicBold = "EsoUI/Common/Fonts/Univers67Cyrillic-CondensedBold.slug",
    futuraLight = "EsoUI/Common/Fonts/FTN47.slug",
    futuraMedium = "EsoUI/Common/Fonts/FTN57.slug",
    futuraBold = "EsoUI/Common/Fonts/FTN87.slug",
    esoJapanese = "EsoUI/Common/Fonts/ESO_FWNTLGUDC70-DB.slug",
    esoJapaneseMedium = "EsoUI/Common/Fonts/ESO_FWUDC_70-M.slug",
    chineseMedium = "EsoUI/Common/Fonts/MYingHeiPRC-W5.slug",
    gamepadBold = "$(GAMEPAD_BOLD_FONT)",
    gamepadMedium = "$(GAMEPAD_MEDIUM_FONT)",
    gamepadLight = "$(GAMEPAD_LIGHT_FONT)",
    gamepadNumber = "$(GAMEPAD_MEDIUM_FONT_LATIN)",
    keyboardBold = "$(BOLD_FONT)",
    keyboardMedium = "$(MEDIUM_FONT)",
    chat = "$(CHAT_FONT)",
}

local SOUND_KEYS =
{
    CONSOLE_GAME_ENTER = "CONSOLE_GAME_ENTER",
    RETURNING_PLAYER_OPEN_KEYBOARD = "RETURNING_PLAYER_OPEN_KEYBOARD",
}

local TEXT_EFFECT_ALIASES =
{
    none = "none",
    None = "none",
    shadow = "shadow",
    Shadow = "shadow",
    outline = "outline",
    Outline = "outline",
}

local FALLBACK_SOUND_KEYS =
{
    "CONSOLE_GAME_ENTER",
    "RETURNING_PLAYER_OPEN_KEYBOARD",
}

local function AddFlag(target, key)
    if key ~= nil then
        target[key] = true
    end
end

local function AddSctSetting(target, key, id)
    if id ~= nil then
        table.insert(target, { key = key, id = id })
    end
end

local DAMAGE_RESULTS = {}
AddFlag(DAMAGE_RESULTS, ACTION_RESULT_DAMAGE)
AddFlag(DAMAGE_RESULTS, ACTION_RESULT_CRITICAL_DAMAGE)
AddFlag(DAMAGE_RESULTS, ACTION_RESULT_DOT_TICK)
AddFlag(DAMAGE_RESULTS, ACTION_RESULT_DOT_TICK_CRITICAL)
AddFlag(DAMAGE_RESULTS, ACTION_RESULT_DAMAGE_SHIELDED)
AddFlag(DAMAGE_RESULTS, ACTION_RESULT_BLOCKED_DAMAGE)
AddFlag(DAMAGE_RESULTS, ACTION_RESULT_FALL_DAMAGE)
AddFlag(DAMAGE_RESULTS, ACTION_RESULT_PRECISE_DAMAGE)
AddFlag(DAMAGE_RESULTS, ACTION_RESULT_WRECKING_DAMAGE)

local CRITICAL_RESULTS = {}
AddFlag(CRITICAL_RESULTS, ACTION_RESULT_CRITICAL_DAMAGE)
AddFlag(CRITICAL_RESULTS, ACTION_RESULT_DOT_TICK_CRITICAL)

local SCT_DAMAGE_SETTINGS = {}
AddSctSetting(SCT_DAMAGE_SETTINGS, "outgoingDamage", COMBAT_SETTING_SCT_OUTGOING_DAMAGE_ENABLED)
AddSctSetting(SCT_DAMAGE_SETTINGS, "outgoingDot", COMBAT_SETTING_SCT_OUTGOING_DOT_ENABLED)
AddSctSetting(SCT_DAMAGE_SETTINGS, "outgoingPetDamage", COMBAT_SETTING_SCT_OUTGOING_PET_DAMAGE_ENABLED)
AddSctSetting(SCT_DAMAGE_SETTINGS, "outgoingPetDot", COMBAT_SETTING_SCT_OUTGOING_PET_DOT_ENABLED)
AddSctSetting(SCT_DAMAGE_SETTINGS, "incomingDamage", COMBAT_SETTING_SCT_INCOMING_DAMAGE_ENABLED)
AddSctSetting(SCT_DAMAGE_SETTINGS, "incomingDot", COMBAT_SETTING_SCT_INCOMING_DOT_ENABLED)
AddSctSetting(SCT_DAMAGE_SETTINGS, "incomingPetDamage", COMBAT_SETTING_SCT_INCOMING_PET_DAMAGE_ENABLED)
AddSctSetting(SCT_DAMAGE_SETTINGS, "incomingPetDot", COMBAT_SETTING_SCT_INCOMING_PET_DOT_ENABLED)

local PLAYER_RELATED_SOURCE_TYPES = {}
AddFlag(PLAYER_RELATED_SOURCE_TYPES, COMBAT_UNIT_TYPE_PLAYER)
AddFlag(PLAYER_RELATED_SOURCE_TYPES, COMBAT_UNIT_TYPE_PLAYER_PET)
AddFlag(PLAYER_RELATED_SOURCE_TYPES, COMBAT_UNIT_TYPE_PLAYER_COMPANION)

local MINIGAME_SOURCE_TYPES = {}
AddFlag(MINIGAME_SOURCE_TYPES, COMBAT_UNIT_TYPE_PLAYER)
AddFlag(MINIGAME_SOURCE_TYPES, COMBAT_UNIT_TYPE_PLAYER_PET)

local PLAYER_RELATED_TARGET_TYPES = {}
AddFlag(PLAYER_RELATED_TARGET_TYPES, COMBAT_UNIT_TYPE_PLAYER)
AddFlag(PLAYER_RELATED_TARGET_TYPES, COMBAT_UNIT_TYPE_PLAYER_PET)
AddFlag(PLAYER_RELATED_TARGET_TYPES, COMBAT_UNIT_TYPE_PLAYER_COMPANION)

local lastCritSoundMS = -DEFAULT_SETTINGS.soundThrottleMS
local lastMinigameSoundMS = -MINIGAME_SOUND_THROTTLE_MS
local lastMinigameSoundPriority = 0

local function RegisterFilteredCombatEvent(namespace, unitFilterType, unitType, result, callback)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_COMBAT_EVENT, callback)
    EVENT_MANAGER:AddFilterForEvent(
        namespace,
        EVENT_COMBAT_EVENT,
        REGISTER_FILTER_IS_ERROR, false,
        REGISTER_FILTER_COMBAT_RESULT, result,
        unitFilterType, unitType
    )
end

local function GetSettings()
    if NAGA_UI.Settings then
        return NAGA_UI.Settings:GetDamageNumbers()
    end

    return DEFAULT_SETTINGS
end

local function GetSettingValue(key)
    local settings = GetSettings()
    local value = settings and settings[key]
    if value == nil then
        return DEFAULT_SETTINGS[key]
    end

    return value
end

local function GetMinigameSettings()
    local settings = GetSettings()
    return settings and settings.damageDoneMinigame or DEFAULT_SETTINGS.damageDoneMinigame
end

local function GetMinigameSettingValue(key)
    local settings = GetMinigameSettings()
    local value = settings and settings[key]
    if value == nil then
        return DEFAULT_SETTINGS.damageDoneMinigame[key]
    end

    return value
end

local function IsModuleEnabled()
    return not NAGA_UI.Settings or NAGA_UI.Settings:IsDamageNumbersEnabled()
end

local function IsMinigameEnabled()
    return NAGA_UI.Settings
        and NAGA_UI.Settings:IsDamageDoneMinigameEnabled()
        or false
end

local function IsMinigameUnlocked()
    return IsMinigameEnabled()
        and NAGA_UI.Settings
        and NAGA_UI.Settings:IsDamageDoneMinigameUnlocked()
end

local function AreMinigameSoundsEnabled()
    return IsMinigameEnabled() and GetMinigameSettingValue("soundEnabled") ~= false
end

local function ShouldRegisterCombatEvents()
    return IsModuleEnabled() or IsMinigameEnabled()
end

local function IsDamageEvent(result, hitValue)
    return hitValue and hitValue > 0 and DAMAGE_RESULTS[result]
end

local function IsCriticalResult(result)
    return CRITICAL_RESULTS[result] == true
end

local function IsOutgoingDamage(sourceType)
    return PLAYER_RELATED_SOURCE_TYPES[sourceType] == true
end

local function IsMinigameDamageSource(sourceType)
    return MINIGAME_SOURCE_TYPES[sourceType] == true
end

local function IsIncomingDamage(targetType)
    return PLAYER_RELATED_TARGET_TYPES[targetType] == true
end

local function EaseOutCubic(progress)
    local inverse = 1 - progress
    return 1 - inverse * inverse * inverse
end

local function EaseOutBack(progress)
    local c1 = 1.70158
    local c3 = c1 + 1
    local offset = progress - 1
    return 1 + c3 * offset * offset * offset + c1 * offset * offset
end

local function ClampNumber(value, minValue, maxValue)
    return math.min(math.max(value, minValue), maxValue)
end

local function EaseOutQuart(progress)
    local inverse = 1 - progress
    return 1 - inverse * inverse * inverse * inverse
end

local function BuildFont(size)
    local fontFace = FONT_FACES[GetSettingValue("fontKey")] or FONT_FACES.antique
    local textEffect = TEXT_EFFECT_ALIASES[GetSettingValue("textEffect")] or "none"
    if textEffect == "shadow" then
        return string.format("%s|%d|soft-shadow-thick", fontFace, size)
    end
    if textEffect == "outline" then
        return string.format("%s|%d|thick-outline", fontFace, size)
    end

    return string.format("%s|%d", fontFace, size)
end

local function FormatDamageValue(hitValue)
    return tostring(hitValue)
end

local function FormatMinigameValue(value)
    local rounded = math.max(0, math.floor((tonumber(value) or 0) + 0.5))
    if ZO_CommaDelimitNumber then
        return ZO_CommaDelimitNumber(rounded)
    end

    local formatted = tostring(rounded)
    while true do
        local replaced
        formatted, replaced = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if replaced == 0 then
            break
        end
    end
    return formatted
end

local function BuildMinigameFont(size, effect)
    return string.format("%s|%d|%s", MINIGAME_FONT_FACE, size, effect or "thick-outline")
end

local function GetMinigameMilestoneTier(value)
    local tier = 0
    local mode = GetMinigameSettingValue("displayMode") == "dps" and "dps" or "damageDone"
    for index, threshold in ipairs(MINIGAME_MILESTONES[mode]) do
        if value >= threshold then
            tier = index
        else
            break
        end
    end
    return tier
end

local function GetMinigameColors(value)
    local tier = GetMinigameMilestoneTier(value)
    if tier >= 6 then
        return 1.00, 0.96, 0.82, 1.00, 0.08, 0.025
    elseif tier == 5 then
        return 1.00, 0.46, 0.30, 0.94, 0.035, 0.06
    elseif tier == 4 then
        return 1.00, 0.68, 0.27, 1.00, 0.16, 0.03
    elseif tier == 3 then
        return 1.00, 0.82, 0.22, 1.00, 0.28, 0.04
    elseif tier == 2 then
        return 1.00, 0.87, 0.34, 1.00, 0.44, 0.06
    elseif tier == 1 then
        return 1.00, 0.91, 0.48, 0.94, 0.58, 0.12
    end

    return 0.96, 0.82, 0.40, 0.70, 0.44, 0.12
end

local function GetCritSoundThrottleMS()
    return ClampNumber(GetSettingValue("soundThrottleMS"), 0, 800)
end

local function GetCriticalHitSound()
    local configuredKey = GetSettingValue("critSoundKey")
    local soundName = SOUND_KEYS[configuredKey] or configuredKey
    if soundName and SOUNDS[soundName] then
        return SOUNDS[soundName]
    end

    for _, fallbackKey in ipairs(FALLBACK_SOUND_KEYS) do
        if SOUNDS[fallbackKey] then
            return SOUNDS[fallbackKey]
        end
    end
end

local function PlayCriticalSound()
    if NAGA_UI.Settings and not NAGA_UI.Settings:AreDamageNumberCritSoundsEnabled() then
        return
    end

    local nowMS = GetFrameTimeMilliseconds()
    if nowMS - lastCritSoundMS >= GetCritSoundThrottleMS() then
        local sound = GetCriticalHitSound()
        if sound then
            PlaySound(sound)
        end
        lastCritSoundMS = nowMS
    end
end

local function GetMinigameSound(kind, tier)
    if kind == "milestone" then
        local tierKey = MINIGAME_TIER_SOUND_KEYS[tier]
        if tierKey and SOUNDS and SOUNDS[tierKey] then
            return SOUNDS[tierKey]
        end
    end
    local key = MINIGAME_SOUND_KEYS[kind]
    return key and SOUNDS and SOUNDS[key] or nil
end

local function PlayMinigameSound(kind, tier)
    if not AreMinigameSoundsEnabled() then
        return false
    end

    local nowMS = GetFrameTimeMilliseconds()
    local priority = kind == "milestone" and (2 + (tier or 1)) or (kind == "crit" and 2 or 1)
    if nowMS - lastMinigameSoundMS < MINIGAME_SOUND_THROTTLE_MS and priority <= lastMinigameSoundPriority then
        return true
    end

    local sound = GetMinigameSound(kind, tier)
    if not sound and kind ~= "normal" then
        sound = GetMinigameSound("normal")
    end
    if sound then
        PlaySound(sound)
        lastMinigameSoundMS = nowMS
        lastMinigameSoundPriority = priority
        return true
    end
    return false
end

local function GetSpawnOriginPosition()
    if NAGA_UI.Settings then
        return NAGA_UI.Settings:GetDamageNumbersPosition()
    end

    return { x = DEFAULT_SPAWN_OFFSET_X, y = DEFAULT_SPAWN_OFFSET_Y }
end

local function GetMinigamePosition()
    if NAGA_UI.Settings and NAGA_UI.Settings.GetDamageDoneMinigamePosition then
        return NAGA_UI.Settings:GetDamageDoneMinigamePosition()
    end

    return DEFAULT_MINIGAME_POSITION
end

local function GetMinigameScale()
    return ClampNumber(GetMinigameSettingValue("scale"), 60, 180) / 100
end

local function GetMinigameDisplayMode()
    return GetMinigameSettingValue("displayMode") == "dps" and "dps" or "damageDone"
end

local function IsMinigameDpsMode()
    return GetMinigameDisplayMode() == "dps"
end

local function GetMinigameGraceMS()
    return ClampNumber(tonumber(GetMinigameSettingValue("graceMS")) or 1250, 500, 3000)
end

local function GetMinigameMotion()
    return ClampNumber(tonumber(GetMinigameSettingValue("animationIntensity")) or 80, 0, 150) / 100
end

local function GetMinigameFacingSign()
    return GetMinigameSettingValue("faceRight") == true and 1 or -1
end

local function GetMinigameBaseRotation()
    return MINIGAME_TILT_RADIANS * GetMinigameFacingSign()
end

local function GetMinigameBaseSkew()
    return MINIGAME_SKEW_RADIANS * GetMinigameFacingSign()
end

local function CalculateMinigameDps(totalDamage, startMS, nowMS)
    local elapsedMS = math.max((nowMS or 0) - (startMS or nowMS or 0), 1000)
    return math.max(0, totalDamage or 0) * 1000 / elapsedMS
end

local function IsDamageNumbersUnlocked()
    return IsModuleEnabled()
        and NAGA_UI.Settings
        and NAGA_UI.Settings:IsDamageNumbersUnlocked()
end

function DamageNumbers:GetRoot()
    if self.root then
        return self.root
    end

    local root = WINDOW_MANAGER:CreateTopLevelWindow("NAGA_UI_DamageNumbersRoot")
    ApplyTemplateToControl(root, "ZO_HUDManager_Element")
    root:SetAnchorFill(GuiRoot)
    root:SetMouseEnabled(false)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)
    self.root = root
    return root
end

function DamageNumbers:CreateLabel()
    self.nextLabelId = (self.nextLabelId or 0) + 1

    local label = WINDOW_MANAGER:CreateControl("NAGA_UI_DamageNumber" .. self.nextLabelId, self:GetRoot(), CT_LABEL)
    label:SetDimensions(320, 110)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetMouseEnabled(false)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetHidden(true)

    return label
end

function DamageNumbers:AcquireLabel()
    self.pool = self.pool or {}
    self.active = self.active or {}

    local maxActive = ClampNumber(GetSettingValue("maxActive"), 8, 80)
    if #self.active >= maxActive then
        return table.remove(self.active, 1)
    end

    local label = table.remove(self.pool)
    if not label then
        label = self:CreateLabel()
    end

    return label
end

function DamageNumbers:ReleaseLabel(index)
    local label = table.remove(self.active, index)
    if label then
        label:SetHidden(true)
        label:SetAlpha(0)
        label.activeDamageNumber = nil
        table.insert(self.pool, label)
    end
end

function DamageNumbers:UpdateLabels()
    local active = self.active
    if not active or #active == 0 then
        self:GetRoot():SetHandler("OnUpdate", nil)
        self:GetRoot():SetHidden(true)
        return
    end

    local nowMS = GetFrameTimeMilliseconds()
    for i = #active, 1, -1 do
        local label = active[i]
        local data = label.activeDamageNumber
        if not data then
            self:ReleaseLabel(i)
        else
            local progress = ClampNumber((nowMS - data.startMS) / data.durationMS, 0, 1)
            if progress >= 1 then
                self:ReleaseLabel(i)
            else
                local moveProgress = EaseOutCubic(progress)
                local alpha = progress < 0.62 and 1 or math.max(0, 1 - ((progress - 0.62) / 0.38))
                local popProgress = ClampNumber(progress / POP_PROGRESS_PORTION, 0, 1)
                local scale = data.endScale + (data.startScale - data.endScale) * (1 - EaseOutBack(popProgress))
                local x = data.startX + ((data.endX - data.startX) * moveProgress)
                local y = data.startY + ((data.endY - data.startY) * moveProgress)

                label:ClearAnchors()
                label:SetAnchor(CENTER, self:GetRoot(), TOPLEFT, x, y)
                label:SetAlpha(alpha)
                label:SetScale(scale)
            end
        end
    end
end

function DamageNumbers:StartUpdating()
    local root = self:GetRoot()
    root:SetHidden(false)
    root:SetHandler("OnUpdate", function()
        self:UpdateLabels()
    end)
end

function DamageNumbers:GetSpawnPosition(direction, spread)
    local position = GetSpawnOriginPosition()
    local centerX = GuiRoot:GetWidth() * 0.5 + position.x
    local centerY = GuiRoot:GetHeight() * 0.5 + position.y
    local directionOffsetX = direction == "incoming" and -92 or 92
    local directionOffsetY = direction == "incoming" and 44 or -34
    local spreadFloor = math.floor(spread)
    local randomX = math.random(-spreadFloor, spreadFloor)
    local randomY = math.random(-math.floor(spreadFloor * 0.52), math.floor(spreadFloor * 0.36))

    return centerX + directionOffsetX + randomX, centerY + directionOffsetY + randomY
end

function DamageNumbers:GetMover()
    if self.mover then
        return self.mover
    end

    local mover = WINDOW_MANAGER:CreateTopLevelWindow("NAGA_UI_DamageNumbersMover")
    mover:SetDimensions(280, 74)
    mover:SetClampedToScreen(true)
    mover:SetMouseEnabled(true)
    mover:SetMovable(false)
    mover:SetDrawTier(DT_HIGH)
    mover:SetHidden(true)

    local backdrop = WINDOW_MANAGER:CreateControl(nil, mover, CT_BACKDROP)
    backdrop:SetAnchorFill(mover)
    backdrop:SetCenterColor(0.02, 0.02, 0.02, 0.58)
    backdrop:SetEdgeColor(1.0, 0.88, 0.1, 0.9)
    backdrop:SetEdgeTexture("", 1, 1, 2)

    local label = WINDOW_MANAGER:CreateControl(nil, mover, CT_LABEL)
    label:SetAnchor(CENTER, mover, CENTER, 0, -8)
    label:SetFont("$(ANTIQUE_FONT)|26")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetText("680")
    label:SetColor(1.0, 0.91, 0.0, 1)
    mover.previewLabel = label

    local sublabel = WINDOW_MANAGER:CreateControl(nil, mover, CT_LABEL)
    sublabel:SetAnchor(TOP, label, BOTTOM, 0, 2)
    sublabel:SetFont("ZoFontGameSmall")
    sublabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    sublabel:SetText("Damage Number Origin")
    sublabel:SetColor(0.95, 0.86, 0.35, 1)

    mover:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:SetMovable(true)
            control:StartMoving()
        else
            control:SetMovable(false)
        end
    end)

    mover:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:StopMovingOrResizing()
        end
        control:SetMovable(false)
    end)

    mover:SetHandler("OnMoveStop", function(control)
        control:SetMovable(false)
        local x = control:GetLeft() + (control:GetWidth() * 0.5) - (GuiRoot:GetWidth() * 0.5)
        local y = control:GetTop() + (control:GetHeight() * 0.5) - (GuiRoot:GetHeight() * 0.5)
        if NAGA_UI.Settings then
            NAGA_UI.Settings:SetDamageNumbersPosition(x, y)
        end
        self:ApplyMoverState()
    end)

    self.mover = mover
    return mover
end

function DamageNumbers:ApplyMoverState()
    local mover = self:GetMover()
    local position = GetSpawnOriginPosition()

    mover:ClearAnchors()
    mover:SetAnchor(CENTER, GuiRoot, CENTER, position.x, position.y)
    if mover.previewLabel then
        mover.previewLabel:SetFont(BuildFont(26))
    end
    mover:SetHidden(not IsDamageNumbersUnlocked())
end

-- Use the same native, smoothed metalwork as the PvP badge. Convex contours
-- keep ESO's triangulation predictable at small HUD scales.
local CREST_POINTS = {{0.5, 0}, {1, 0.35}, {0.88, 0.76}, {0.5, 1}, {0.12, 0.76}, {0, 0.35}}
local SHARD_POINTS = {{0.5, 0}, {1, 0.68}, {0.5, 1}, {0, 0.68}}
local CREST_RING_POINTS = {}
for index = 0, 47 do
    local angle = index * math.pi * 2 / 48
    CREST_RING_POINTS[#CREST_RING_POINTS + 1] = {0.5 + math.cos(angle) * 0.5, 0.5 + math.sin(angle) * 0.5}
end

local function CreateMinigameGroup(parent, width, height, x, y)
    local group = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    group:SetDimensions(width, height)
    group:SetAnchor(CENTER, parent, CENTER, x, y)
    group:SetMouseEnabled(false)
    group:SetTransformNormalizedOriginPoint(0.5, 0.5)
    return group
end

local function CreateMinigamePolygon(parent, width, height, x, y, points, color, level, border)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_POLYGON)
    control:SetDimensions(width, height)
    control:SetAnchor(CENTER, parent, CENTER, x, y)
    control:SetMouseEnabled(false)
    control:SetDrawLayer(DL_CONTROLS)
    control:SetDrawLevel(level or 0)
    control:SetTransformNormalizedOriginPoint(0.5, 0.5)
    control:SetPointLayout(POLYGON_POINT_LAYOUT_CLOCKWISE)
    control:SetSmoothingEnabled(true)
    for _, point in ipairs(points) do control:AddPoint(point[1], point[2]) end
    control:SetCenterColor(color[1], color[2], color[3], color[4] or 1)
    control:SetBorderThickness(border or 0, border or 0, 1)
    control:SetBorderDirection(POLYGON_BORDER_DIRECTION_IN)
    control:SetBorderColor(0.65, 0.71, 0.72, border and 0.65 or 0)
    return control
end

function DamageNumbers:CreateMinigameCrest(visual)
    local timer = CreateMinigameGroup(visual, 330, 38, 0, 64)
    timer.wings = {}
    for _, side in ipairs({-1, 1}) do
        local wing = CreateMinigameGroup(timer, 150, 24, side * 94, 0)
        wing.side, wing.plates = side, {}
        local points = {{0, 0.18}, {0.76, 0}, {1, 0.5}, {0.76, 1}, {0, 0.82}}
        if side == -1 then
            local mirrored = {}
            for index = #points, 1, -1 do mirrored[#mirrored + 1] = {1 - points[index][1], points[index][2]} end
            points = mirrored
        end
        for index = 1, 4 do
            local x = side * ((index - 1) * 31 - 46.5)
            local height = 13 - index
            local plate = CreateMinigamePolygon(wing, 30, height, x, 0, points, {0.035, 0.045, 0.052}, 2, 0.8)
            plate.fill = CreateMinigamePolygon(wing, 26, height - 4, x, -0.5, points, {1, 0.72, 0.22}, 3)
            plate.fill:SetTransformNormalizedOriginPoint(side == 1 and 0 or 1, 0.5)
            wing.plates[index] = plate
        end
        timer.wings[#timer.wings + 1] = wing
        wing.armor = {}
        for index = 1, 3 do
            local fin = CreateMinigamePolygon(wing, 46 + index * 9, 11, side * (index * 21 - 14),
                7 + index * 5, points, {0.07, 0.035, 0.025}, 1, 1)
            fin:SetTransformRotationZ(math.rad(side * (10 + index * 7)))
            fin:SetHidden(true)
            wing.armor[index] = fin
        end
    end

    local crest = CreateMinigameGroup(timer, 38, 38, 0, 0)
    crest.shadow = CreateMinigamePolygon(crest, 42, 40, 0, 2, CREST_POINTS, {0, 0, 0, 0.5}, 4)
    crest.rim = CreateMinigamePolygon(crest, 36, 36, 0, 0, CREST_POINTS, {0.16, 0.19, 0.20}, 5, 1.2)
    crest.bevel = CreateMinigamePolygon(crest, 30, 29, 0, 0, CREST_POINTS, {0.30, 0.33, 0.32}, 6, 0.6)
    crest.face = CreateMinigamePolygon(crest, 25, 25, 0, 0, CREST_POINTS, {0.035, 0.045, 0.05}, 7)
    -- A tiny inlaid blade, rather than reusing the kill badge's skull.
    crest.blade = CreateMinigamePolygon(crest, 5, 15, 0, -3, SHARD_POINTS, {1, 0.94, 0.75}, 8)
    CreateMinigamePolygon(crest, 12, 3, 0, 3, CREST_POINTS, {0.70, 0.76, 0.77}, 8)
    CreateMinigamePolygon(crest, 3, 6, 0, 6, SHARD_POINTS, {0.90, 0.69, 0.30}, 8)
    crest.strike = CreateMinigamePolygon(crest, 32, 32, 0, 0, CREST_POINTS, {1, 0.93, 0.72}, 9)
    crest.strike:SetAlpha(0)
    crest.ranks = {}
    for index = 1, 6 do
        crest.ranks[index] = CreateMinigamePolygon(crest, 3, 3, (index - 3.5) * 5, 24,
            SHARD_POINTS, {0.65, 0.71, 0.72, 0.2}, 6)
    end
    crest.crown = {}
    for _, side in ipairs({-1, 1}) do
        local crown = CreateMinigamePolygon(crest, 9, 28, side * 23, 1,
            SHARD_POINTS, {0.12, 0.055, 0.025}, 4, 1)
        crown:SetTransformRotationZ(math.rad(side * 28))
        crown:SetHidden(true)
        crest.crown[#crest.crown + 1] = crown
    end
    crest.aura = CreateMinigamePolygon(crest, 57, 53, 0, 0,
        CREST_POINTS, {0, 0, 0, 0}, 0, 1)
    crest.aura:SetHidden(true)
    timer.runes = {}
    for index = 1, 6 do
        local rune = CreateMinigamePolygon(timer, 5, 11, 0, 0, SHARD_POINTS, {1, 0.94, 0.75}, 0, 0.5)
        rune:SetHidden(true)
        timer.runes[index] = rune
    end
    timer.crest = crest
    return timer
end

function DamageNumbers:GetMinigameRoot()
    if self.minigameRoot then
        return self.minigameRoot
    end

    local wm = WINDOW_MANAGER
    local root = wm:CreateTopLevelWindow("NAGA_UI_DamageDoneMinigameRoot")
    root:SetDimensions(MINIGAME_WIDTH, MINIGAME_HEIGHT)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(false)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)
    root:SetAlpha(0)

    local visual = wm:CreateControl(nil, root, CT_CONTROL)
    visual:SetAnchorFill(root)
    visual:SetMouseEnabled(false)
    visual:SetTransformNormalizedOriginPoint(0.5, 0.5)
    visual:SetTransformRotationZ(GetMinigameBaseRotation())
    visual:SetTransformSkewX(GetMinigameBaseSkew())
    root.visual = visual

    local outerGlow = wm:CreateControl(nil, visual, CT_TEXTURE)
    outerGlow:SetDimensions(500, 190)
    outerGlow:SetAnchor(CENTER, visual, CENTER, 0, 0)
    outerGlow:SetTexture(MINIGAME_HIGHLIGHT_TEXTURE)
    outerGlow:SetTextureCoords(0, 1, 0, 0.75)
    outerGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    outerGlow:SetDrawLayer(DL_BACKGROUND)
    outerGlow:SetAlpha(0)
    root.outerGlow = outerGlow

    root.timer = self:CreateMinigameCrest(visual)

    local shockwave = CreateMinigamePolygon(visual, 44, 44, 0, 64,
        CREST_RING_POINTS, {0, 0, 0, 0}, 1, 0.8)
    shockwave:SetBorderColor(1, 0.78, 0.36, 0.8)
    shockwave:SetAlpha(0)
    shockwave:SetHidden(true)
    root.shockwave = shockwave
    root.maxShockwave = CreateMinigamePolygon(visual, 58, 58, 0, 64,
        CREST_RING_POINTS, {0, 0, 0, 0}, 0, 1.3)
    root.maxShockwave:SetBorderColor(1, 0.15, 0.055, 0.95)
    root.maxShockwave:SetHidden(true)

    local echoRed = wm:CreateControl(nil, visual, CT_LABEL)
    echoRed:SetDimensions(540, 150)
    echoRed:SetAnchor(CENTER, visual, CENTER, 0, -1)
    echoRed:SetFont(BuildMinigameFont(86))
    echoRed:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    echoRed:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    echoRed:SetColor(1.00, 0.12, 0.02, 1)
    echoRed:SetDrawLayer(DL_CONTROLS)
    echoRed:SetTransformNormalizedOriginPoint(0.5, 0.5)
    echoRed:SetAlpha(0)
    root.echoRed = echoRed

    local echoGold = wm:CreateControl(nil, visual, CT_LABEL)
    echoGold:SetDimensions(540, 150)
    echoGold:SetAnchor(CENTER, visual, CENTER, 0, -1)
    echoGold:SetFont(BuildMinigameFont(86))
    echoGold:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    echoGold:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    echoGold:SetColor(1.00, 0.62, 0.06, 1)
    echoGold:SetDrawLayer(DL_CONTROLS)
    echoGold:SetTransformNormalizedOriginPoint(0.5, 0.5)
    echoGold:SetAlpha(0)
    root.echoGold = echoGold

    local shadowLabel = wm:CreateControl(nil, visual, CT_LABEL)
    shadowLabel:SetDimensions(540, 150)
    shadowLabel:SetAnchor(CENTER, visual, CENTER, 7, 7)
    shadowLabel:SetFont(BuildMinigameFont(86))
    shadowLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    shadowLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    shadowLabel:SetColor(0.015, 0.009, 0.006, 1)
    shadowLabel:SetDrawLayer(DL_CONTROLS)
    root.shadowLabel = shadowLabel

    local mainLabel = wm:CreateControl(nil, visual, CT_LABEL)
    mainLabel:SetDimensions(540, 150)
    mainLabel:SetAnchor(CENTER, visual, CENTER, 0, -1)
    mainLabel:SetFont(BuildMinigameFont(86))
    mainLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    mainLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    mainLabel:SetColor(0.96, 0.82, 0.40, 1)
    mainLabel:SetDrawLayer(DL_OVERLAY)
    mainLabel:SetDrawLevel(8)
    root.mainLabel = mainLabel

    local impactFlash = wm:CreateControl(nil, visual, CT_TEXTURE)
    impactFlash:SetDimensions(490, 180)
    impactFlash:SetAnchor(CENTER, visual, CENTER, 0, 0)
    impactFlash:SetTexture(MINIGAME_HIGHLIGHT_TEXTURE)
    impactFlash:SetTextureCoords(0, 1, 0, 0.75)
    impactFlash:SetBlendMode(TEX_BLEND_MODE_ADD)
    impactFlash:SetDrawLayer(DL_OVERLAY)
    impactFlash:SetDrawLevel(4)
    impactFlash:SetColor(1.00, 0.82, 0.30, 1)
    impactFlash:SetAlpha(0)
    root.impactFlash = impactFlash

    -- Keep supporting information outside the large score's silhouette.
    local caption = wm:CreateControl(nil, visual, CT_LABEL)
    caption:SetDimensions(440, 28)
    caption:SetAnchor(CENTER, visual, CENTER, 0, 104)
    caption:SetFont(BuildMinigameFont(18, "soft-shadow-thick"))
    caption:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    caption:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    caption:SetColor(0.92, 0.85, 0.66, 1)
    caption:SetDrawLayer(DL_OVERLAY)
    root.caption = caption

    root.deltas = {}
    for index = 1, MINIGAME_DELTA_COUNT do
        local delta = wm:CreateControl(nil, visual, CT_LABEL)
        delta:SetDimensions(270, 62)
        delta:SetAnchor(CENTER, visual, CENTER, 0, -70)
        delta:SetFont(BuildMinigameFont(26))
        delta:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        delta:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        delta:SetDrawLayer(DL_OVERLAY)
        delta:SetDrawLevel(10)
        delta:SetTransformNormalizedOriginPoint(0.5, 0.5)
        delta:SetAlpha(0)
        delta:SetHidden(true)
        root.deltas[index] = delta
    end

    root.sparks = {}
    for index = 1, MINIGAME_SPARK_COUNT do
        local spark = CreateMinigamePolygon(visual, 3, 12, 0, 64, SHARD_POINTS, {1, 0.85, 0.48}, 6)
        spark:SetDrawLayer(DL_OVERLAY)
        spark:SetDrawLevel(6)
        spark:SetCenterColor(1.00, 0.85, 0.48, 1)
        spark:SetTransformNormalizedOriginPoint(0.5, 0.5)
        spark:SetAlpha(0)
        spark:SetHidden(true)
        root.sparks[index] = spark
    end

    self.minigameRoot = root
    return root
end

function DamageNumbers:GetMinigameMover()
    if self.minigameMover then
        return self.minigameMover
    end

    local mover = WINDOW_MANAGER:CreateTopLevelWindow("NAGA_UI_DamageDoneMinigameMover")
    mover:SetDimensions(410, 132)
    mover:SetClampedToScreen(true)
    mover:SetMouseEnabled(true)
    mover:SetMovable(false)
    mover:SetDrawTier(DT_HIGH)
    mover:SetHidden(true)

    local backdrop = WINDOW_MANAGER:CreateControl(nil, mover, CT_BACKDROP)
    backdrop:SetAnchorFill(mover)
    backdrop:SetCenterColor(0.018, 0.012, 0.006, 0.70)
    backdrop:SetEdgeColor(0.96, 0.62, 0.12, 0.94)
    backdrop:SetEdgeTexture(MINIGAME_EDGE_TEXTURE, 128, 16, 5, 0)

    local preview = WINDOW_MANAGER:CreateControl(nil, mover, CT_LABEL)
    preview:SetDimensions(390, 82)
    preview:SetAnchor(CENTER, mover, CENTER, 0, -8)
    preview:SetFont(BuildMinigameFont(52))
    preview:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    preview:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    preview:SetText("128,450")
    preview:SetColor(1.00, 0.84, 0.28, 1)
    preview:SetTransformRotationZ(GetMinigameBaseRotation())
    mover.previewLabel = preview

    local sublabel = WINDOW_MANAGER:CreateControl(nil, mover, CT_LABEL)
    sublabel:SetAnchor(BOTTOM, mover, BOTTOM, 0, -8)
    sublabel:SetFont("ZoFontGameSmall")
    sublabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    sublabel:SetText("Damage Done Minigame")
    sublabel:SetColor(0.96, 0.78, 0.34, 1)

    mover:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:SetMovable(true)
            control:StartMoving()
        else
            control:SetMovable(false)
        end
    end)

    mover:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:StopMovingOrResizing()
        end
        control:SetMovable(false)
    end)

    mover:SetHandler("OnMoveStop", function(control)
        control:SetMovable(false)
        local x = control:GetLeft() + (control:GetWidth() * 0.5) - (GuiRoot:GetWidth() * 0.5)
        local y = control:GetTop() + (control:GetHeight() * 0.5) - (GuiRoot:GetHeight() * 0.5)
        if NAGA_UI.Settings then
            NAGA_UI.Settings:SetDamageDoneMinigamePosition(x, y)
        end
        self:ApplyMinigameLayout()
    end)

    self.minigameMover = mover
    return mover
end

function DamageNumbers:ApplyMinigameLayout()
    local position = GetMinigamePosition()
    local scale = GetMinigameScale()
    local faceRight = GetMinigameFacingSign() > 0
    local textureLeft = faceRight and 1 or 0
    local textureRight = faceRight and 0 or 1
    local root = self:GetMinigameRoot()
    local mover = self:GetMinigameMover()

    root:ClearAnchors()
    root:SetAnchor(CENTER, GuiRoot, CENTER, position.x, position.y)
    root:SetScale(scale)
    root.visual:SetTransformSkewX(GetMinigameBaseSkew())
    if not self.minigameImpact and not self.minigameFinisher then
        root.visual:SetTransformRotationZ(GetMinigameBaseRotation())
    end
    root.outerGlow:SetTextureCoords(textureLeft, textureRight, 0, 0.75)
    root.impactFlash:SetTextureCoords(textureLeft, textureRight, 0, 0.75)

    mover:ClearAnchors()
    mover:SetAnchor(CENTER, GuiRoot, CENTER, position.x, position.y)
    mover:SetScale(scale)
    mover.previewLabel:SetTransformRotationZ(GetMinigameBaseRotation())
    mover:SetHidden(not IsMinigameUnlocked())

    if IsMinigameUnlocked() and ((self.minigameScore or 0) > 0 or self.minigameFinisher) then
        root:SetHidden(false)
        root:SetAlpha(0)
    elseif IsMinigameUnlocked() then
        root:SetHidden(true)
    elseif (self.minigameScore or 0) > 0 or self.minigameFinisher then
        root:SetHidden(false)
    end
end

function DamageNumbers:ApplyMinigameText(value)
    local root = self:GetMinigameRoot()
    local text = FormatMinigameValue(value)
    local digits = string.len(tostring(math.max(0, math.floor((tonumber(value) or 0) + 0.5))))
    local size = 86
    if digits >= 11 then
        size = 54
    elseif digits >= 9 then
        size = 64
    elseif digits >= 7 then
        size = 74
    end

    if root.minigameFontSize ~= size then
        local font = BuildMinigameFont(size)
        root.mainLabel:SetFont(font)
        root.shadowLabel:SetFont(font)
        root.echoRed:SetFont(font)
        root.echoGold:SetFont(font)
        root.minigameFontSize = size
    end

    if root.minigameText ~= text then
        root.mainLabel:SetText(text)
        root.shadowLabel:SetText(text)
        root.echoRed:SetText(text)
        root.echoGold:SetText(text)
        root.minigameText = text
    end

    local r, g, b, glowR, glowG, glowB = GetMinigameColors(value)
    root.mainLabel:SetColor(r, g, b, 1)
    root.outerGlow:SetColor(glowR, glowG, glowB, 1)
end

function DamageNumbers:AcquireMinigameDelta()
    local root = self:GetMinigameRoot()
    local selected
    local oldestMS
    for _, delta in ipairs(root.deltas) do
        if not delta.minigameData then
            return delta
        end
        if not oldestMS or delta.minigameData.startMS < oldestMS then
            selected = delta
            oldestMS = delta.minigameData.startMS
        end
    end
    return selected
end

function DamageNumbers:ShowMinigameDelta(hitValue, isCrit, strength)
    local nowMS = GetFrameTimeMilliseconds()
    local delta = self.minigameLastDelta
    local data = delta and delta.minigameData
    if data and nowMS - data.startMS < MINIGAME_FEEDBACK_MS then
        -- AoE and DoT bursts share a readable delta, without losing any damage.
        data.value = data.value + hitValue
        data.isCrit = data.isCrit or isCrit
        delta:SetText("+" .. FormatMinigameValue(data.value))
        delta:SetFont(BuildMinigameFont(data.isCrit and 32 or 26))
        delta:SetColor(1, data.isCrit and 0.92 or 0.76, data.isCrit and 0.36 or 0.24, 1)
        return
    end
    delta = self:AcquireMinigameDelta()
    if not delta then
        return
    end

    local direction = ((self.nextMinigameDeltaDirection or -1) * -1)
    self.nextMinigameDeltaDirection = direction
    delta:SetFont(BuildMinigameFont(isCrit and 32 or 26))
    delta:SetText("+" .. FormatMinigameValue(hitValue))
    delta:SetColor(isCrit and 1.00 or 0.96, isCrit and 0.92 or 0.76, isCrit and 0.36 or 0.24, 1)
    delta:SetAlpha(1)
    delta:SetHidden(false)
    delta.minigameData =
    {
        startMS = nowMS,
        value = hitValue,
        durationMS = MINIGAME_DELTA_MS + (isCrit and 120 or 0),
        baseX = direction * 100,
        driftX = direction * (18 + strength * 16),
        baseY = -78,
        driftY = -(36 + strength * 18),
        startScale = isCrit and 1.42 or 1.12,
        isCrit = isCrit,
    }
    self.minigameLastDelta = delta
end

function DamageNumbers:TriggerMinigameImpact(hitValue, isCrit, isMilestone)
    local nowMS = GetFrameTimeMilliseconds()
    local tier = self.minigameHighestTier or 0
    local epic = math.max(0, tier - 3)
    local strength = ClampNumber(math.sqrt(hitValue / MINIGAME_HEAVY_HIT), 0.28, 1.55)
    if isCrit then
        strength = math.min(strength + 0.38, 1.80)
    end
    if isMilestone then
        strength = math.max(strength, 1.75)
        if tier >= 4 then
            self.minigameAscension = {startMS = nowMS, tier = tier, durationMS = 1100}
        end
    end
    strength = strength * (1 + epic * 0.14)

    self:ShowMinigameDelta(hitValue, isCrit, strength)
    local previous = self.minigameImpact
    if previous then
        local ageMS = nowMS - previous.startMS
        local priority = isMilestone and 3 or (isCrit and 2 or 1)
        local previousPriority = previous.isMilestone and 3 or (previous.isCrit and 2 or 1)
        if not (isMilestone and tier > (previous.tier or 0))
            and ((ageMS < MINIGAME_FEEDBACK_MS and priority <= previousPriority)
                or (ageMS < 220 and priority < previousPriority)) then
            return
        end
    end

    self.minigameImpactDirection = (self.minigameImpactDirection or -1) * -1
    self.minigameImpact =
    {
        startMS = nowMS,
        durationMS = (isCrit or isMilestone) and MINIGAME_CRIT_IMPACT_MS or MINIGAME_IMPACT_MS,
        strength = strength,
        direction = self.minigameImpactDirection,
        isCrit = isCrit,
        isMilestone = isMilestone,
        tier = tier,
    }

    if isCrit or isMilestone or strength >= 1 then
        self.minigameShockwave =
        {
            startMS = nowMS,
            durationMS = isMilestone and 700 or 540,
            strength = strength,
            tier = tier,
        }
        self.minigameSparks =
        {
            startMS = nowMS,
            durationMS = (isMilestone and 440 or 360) + epic * 65,
            strength = strength,
            tier = tier,
        }
    end
end

function DamageNumbers:StartMinigameUpdating()
    local root = self:GetMinigameRoot()
    self:UpdateDamageDoneMinigame()
    root:SetHandler("OnUpdate", function()
        self:UpdateDamageDoneMinigame()
    end)
end

function DamageNumbers:AddDamageDone(hitValue, isCrit, isPreview)
    if not IsMinigameEnabled() or not hitValue or hitValue <= 0 then
        return false
    end

    if not isPreview then
        if self.minigamePreviewing then
            self:ResetDamageDoneMinigame(true)
        end
        self.minigamePreviewId = (self.minigamePreviewId or 0) + 1
    end

    local nowMS = GetFrameTimeMilliseconds()
    -- Resolve the old streak at the event's timestamp, even if OnUpdate stalled.
    self:UpdateMinigameScore(nowMS)
    if self.minigameFinisher then
        self:ResetDamageDoneMinigame(false)
    end
    self.minigamePreviewing = isPreview == true
    local currentScore = math.max(0, self.minigameScore or 0)
    local previousTier = self.minigameHighestTier or 0
    local newScore

    if IsMinigameDpsMode() then
        if not self.minigameDpsStartMS then
            self.minigameDpsStartMS = nowMS
            self.minigameDpsTotalDamage = 0
            previousTier = 0
        end
        self.minigameDpsTotalDamage = (self.minigameDpsTotalDamage or 0) + hitValue
        newScore = CalculateMinigameDps(self.minigameDpsTotalDamage, self.minigameDpsStartMS, nowMS)
    else
        newScore = currentScore + hitValue
    end

    local newTier = GetMinigameMilestoneTier(newScore)
    local isMilestone = newTier > previousTier

    self.minigameScore = newScore
    self.minigameCountStartValue = math.max(0, self.minigameDisplayScore or currentScore)
    self.minigameCountTargetValue = newScore
    self.minigameCountStartMS = nowMS
    self.minigameDisplayScore = self.minigameCountStartValue
    self.minigameGraceUntilMS = nowMS + GetMinigameGraceMS()
    self.minigameDrainStartMS = nil
    self.minigameDrainStartValue = nil
    self.minigameFinisher = nil
    self.minigameHighestTier = math.max(previousTier, newTier)
    self.minigameHitCount = (self.minigameHitCount or 0) + 1
    self.minigamePeak = math.max(self.minigamePeak or 0, newScore)

    if currentScore <= 0 then
        self:ApplyMinigameLayout()
    end
    self:ApplyMinigameText(self.minigameDisplayScore)
    self:TriggerMinigameImpact(hitValue, isCrit, isMilestone)
    self:StartMinigameUpdating()

    local tierSound = isMilestone and GetMinigameSettingValue("tierSoundsEnabled") ~= false
    local soundKind = tierSound and "milestone" or (isCrit and "crit" or "normal")
    return PlayMinigameSound(soundKind, newTier)
end

function DamageNumbers:UpdateMinigameDeltas(nowMS)
    local root = self:GetMinigameRoot()
    for _, delta in ipairs(root.deltas) do
        local data = delta.minigameData
        if data then
            local progress = ClampNumber((nowMS - data.startMS) / data.durationMS, 0, 1)
            if progress >= 1 then
                delta.minigameData = nil
                delta:SetAlpha(0)
                delta:SetHidden(true)
                delta:SetTransformOffset(0, 0, 0)
                delta:SetTransformScale(1)
            else
                local eased = EaseOutCubic(progress)
                local alpha = progress < 0.56 and 1 or (1 - progress) / 0.44
                local x = data.baseX + data.driftX * eased
                local y = data.baseY + data.driftY * eased
                local scale = 1 + (data.startScale - 1) * (1 - EaseOutBack(ClampNumber(progress / 0.42, 0, 1)))
                local motion = GetMinigameMotion()
                delta:SetTransformOffset(data.baseX + (x - data.baseX) * motion, data.baseY + (y - data.baseY) * motion, 0)
                delta:SetTransformScale(1 + (scale - 1) * motion)
                delta:SetAlpha(ClampNumber(alpha, 0, 1))
            end
        end
    end
end

function DamageNumbers:UpdateMinigameSparks(nowMS)
    local root = self:GetMinigameRoot()
    local data = self.minigameSparks
    local motion = GetMinigameMotion()
    if not data or motion == 0 then
        for _, spark in ipairs(root.sparks) do
            spark:SetAlpha(0)
            spark:SetHidden(true)
        end
        return
    end

    local progress = ClampNumber((nowMS - data.startMS) / data.durationMS, 0, 1)
    if progress >= 1 then
        self.minigameSparks = nil
        for _, spark in ipairs(root.sparks) do
            spark:SetAlpha(0)
            spark:SetHidden(true)
        end
        return
    end

    local eased = EaseOutCubic(progress)
    local count = math.min(#root.sparks, 4 + (data.tier or 0) * 2)
    for index, spark in ipairs(root.sparks) do
        local side = index % 2 == 0 and 1 or -1
        local lane = math.floor((index - 1) / 2)
        local angle = math.rad((side == 1 and 0 or 180) + (lane - (count / 2 - 1) / 2) * 24)
        local distance = eased * (34 + data.strength * 12 + lane * 5) * motion
        -- Eject from the metalwork's ends, leaving the number's silhouette clear.
        local x = side * 142 + math.cos(angle) * distance
        local y = math.sin(angle) * distance * 0.75
        spark:SetTransformOffset(x, y, 0)
        spark:SetTransformRotationZ(angle + math.pi * 0.5)
        spark:SetTransformScale(0.35 + (1 - progress) * 0.65)
        spark:SetAlpha((1 - progress)^2 * math.min(1, 0.62 + data.strength * 0.22) * math.min(motion, 1))
        spark:SetHidden(index > count)
    end
end

function DamageNumbers:UpdateMinigameVisuals(nowMS)
    local root = self:GetMinigameRoot()
    local visual = root.visual
    local scale = 1
    local baseRotation = GetMinigameBaseRotation()
    local rotation = baseRotation
    local offsetX = 0
    local offsetY = 0
    local glowAlpha = self.minigameScore and self.minigameScore > 0 and 0.12 or 0
    local flashAlpha = 0
    local motion = GetMinigameMotion()
    local tier = self.minigameHighestTier or 0
    local epic = math.max(0, tier - 3)
    local ascension = self.minigameAscension
    local ascendProgress = ascension and ClampNumber((nowMS - ascension.startMS) / ascension.durationMS, 0, 1) or 1
    if ascendProgress >= 1 then self.minigameAscension = nil end
    local ascendFlash = math.sin(ClampNumber(ascendProgress / 0.22, 0, 1) * math.pi) * (ascension and 1 or 0)

    root.echoRed:SetAlpha(0)
    root.echoGold:SetAlpha(0)

    local impact = self.minigameImpact
    if impact then
        local progress = ClampNumber((nowMS - impact.startMS) / impact.durationMS, 0, 1)
        if progress >= 1 then
            self.minigameImpact = nil
            root.echoRed:SetAlpha(0)
            root.echoGold:SetAlpha(0)
            root.echoRed:SetTransformOffset(0, 0, 0)
            root.echoGold:SetTransformOffset(0, 0, 0)
            root.echoRed:SetTransformScale(1)
            root.echoGold:SetTransformScale(1)
        else
            local envelope = (1 - progress) * (1 - progress)
            local elapsed = nowMS - impact.startMS
            local settle = ClampNumber(elapsed / 190, 0, 1)
            local peak = 0.035 + impact.strength * 0.08 + (impact.isCrit and 0.06 or 0)
            -- Stamp, compress, recover once, then hold still like the PvP medal.
            if elapsed < 65 then
                scale = 1 + peak - (peak + 0.035) * EaseOutCubic(elapsed / 65)
            else
                scale = 0.965 + 0.035 * EaseOutBack(ClampNumber((elapsed - 65) / 125, 0, 1))
            end
            rotation = baseRotation + math.rad(impact.direction * 2.5) * (1 - EaseOutCubic(settle))
            offsetY = -3 * impact.strength * (1 - EaseOutCubic(settle))
            glowAlpha = math.min(1, 0.28 + envelope * (0.34 + impact.strength * 0.20))
            flashAlpha = envelope * (0.42 + impact.strength * 0.30)

            if impact.isCrit or impact.isMilestone then
                local echoAlpha = envelope * (impact.isMilestone and 0.86 or 0.64)
                root.echoRed:SetAlpha(echoAlpha * math.min(motion, 1))
                root.echoGold:SetAlpha(echoAlpha * 0.88 * math.min(motion, 1))
                root.echoRed:SetTransformOffset(-10 * impact.direction * (1 - progress), 2, 0)
                root.echoGold:SetTransformOffset(8 * impact.direction * (1 - progress), -2, 0)
                root.echoRed:SetTransformScale(1 + envelope * 0.10)
                root.echoGold:SetTransformScale(1 + envelope * 0.06)
            end
        end
    end

    local shockwave = self.minigameShockwave
    root.maxShockwave:SetHidden(true)
    if shockwave then
        local progress = ClampNumber((nowMS - shockwave.startMS) / shockwave.durationMS, 0, 1)
        if progress >= 1 then
            self.minigameShockwave = nil
            root.shockwave:SetAlpha(0)
            root.shockwave:SetHidden(true)
            root.shockwave:SetTransformScale(1)
        else
            root.shockwave:SetHidden(false)
            root.shockwave:SetTransformScale(0.90 + EaseOutCubic(progress) * (0.72 + shockwave.strength * 0.12))
            root.shockwave:SetAlpha((1 - progress)^3 * 0.55 * math.min(motion, 1))
            if (shockwave.tier or 0) >= 6 and motion > 0 then
                local secondProgress = ClampNumber((progress - 0.12) / 0.88, 0, 1)
                root.maxShockwave:SetHidden(progress <= 0.12)
                root.maxShockwave:SetTransformScale(0.8 + EaseOutCubic(secondProgress) * 1.5)
                root.maxShockwave:SetAlpha((1 - secondProgress)^2 * math.min(motion, 1) * 0.85)
            end
        end
    end

    local finisher = self.minigameFinisher
    if finisher then
        local progress = ClampNumber((nowMS - finisher.startMS) / finisher.durationMS, 0, 1)
        local exitProgress = ClampNumber((progress - 0.55) / 0.45, 0, 1)
        scale = 1 - EaseOutCubic(exitProgress) * 0.14
        rotation = baseRotation
        offsetX, offsetY = 0, -12 * EaseOutCubic(exitProgress)
        root:SetAlpha(1 - exitProgress)
        glowAlpha = (1 - progress) * 0.20
        flashAlpha = 0
    else
        root:SetAlpha(1)
    end

    visual:SetTransformScale(1 + (scale - 1) * motion)
    visual:SetTransformRotationZ(baseRotation + (rotation - baseRotation) * motion)
    visual:SetTransformOffset(offsetX * motion, offsetY * motion, 0)
    root.outerGlow:SetAlpha(ClampNumber(glowAlpha + epic * 0.045 + ascendFlash * 0.3 * motion, 0, 1))
    root.impactFlash:SetAlpha(ClampNumber((flashAlpha * 0.65 + ascendFlash * 0.7) * motion, 0, 1))
    self:UpdateMinigameDetails(nowMS)
    self:UpdateMinigameDeltas(nowMS)
    self:UpdateMinigameSparks(nowMS)
end

function DamageNumbers:UpdateMinigameDetails(nowMS)
    local root = self:GetMinigameRoot()
    local showTimer = GetMinigameSettingValue("showTimer") ~= false
    local remaining = (self.minigameGraceUntilMS or nowMS) - nowMS
    local draining = remaining < 0
    local fraction = (remaining + MINIGAME_DRAIN_MS) / (GetMinigameGraceMS() + MINIGAME_DRAIN_MS)
    if not showTimer or self.minigameFinisher then
        fraction, draining = 1, false
    end
    fraction = ClampNumber(fraction, 0, 1)
    root.timer.remainingFraction = fraction
    local r, g, b = GetMinigameColors(self.minigamePeak or 0)
    if draining then r, g, b = 1, 0.36, 0.13 end
    local motion = GetMinigameMotion()
    local tier = self.minigameHighestTier or 0
    local epic = math.max(0, tier - 3)
    local ascension = self.minigameAscension
    local ascendElapsed = ascension and nowMS - ascension.startMS or 1100
    local ascensionRecoil = (1 - EaseOutCubic(ClampNumber(ascendElapsed / 550, 0, 1))) * motion
    local impact = self.minigameImpact
    local elapsed = impact and math.max(0, nowMS - impact.startMS) or 1000
    local recoil = 1 - EaseOutCubic(ClampNumber(elapsed / 220, 0, 1))
    local flash = (1 - ClampNumber(elapsed / 150, 0, 1))^2 * motion
    for _, wing in ipairs(root.timer.wings) do
        wing:SetTransformOffset(wing.side * recoil * 12 * motion, recoil * 3 * motion, 0)
        wing:SetTransformRotationZ(math.rad(wing.side * -7) * recoil * motion)
        for index, plate in ipairs(wing.plates) do
            local fill = ClampNumber(fraction * 4 - (index - 1), 0, 1)
            plate.fill:SetTransformScaleX(math.max(0.001, fill))
            plate.fill:SetAlpha(fill > 0 and 0.78 or 0)
            plate.fill:SetCenterColor(r, g, b, 1)
            plate:SetBorderColor(0.62 + flash * 0.15, 0.68 + flash * 0.1, 0.70, 0.55)
        end
        for index, armor in ipairs(wing.armor) do
            armor:SetHidden(index > epic)
            armor:SetBorderColor(r, g, b, 0.8)
            armor:SetCenterColor(r * 0.38, g * 0.24, b * 0.20, 0.94)
            local entry = EaseOutBack(ClampNumber((ascendElapsed - index * 65) / 430, 0, 1))
            armor:SetTransformScale(1 + (entry - 1) * motion)
            armor:SetTransformOffset(wing.side * (1 - entry) * 24 * motion, (1 - entry) * -10 * motion, 0)
            armor:SetAlpha(1 - (1 - ClampNumber(entry, 0, 1)) * math.min(motion, 1))
        end
    end
    local crest = root.timer.crest
    crest:SetTransformScale(1 + epic * 0.10 + recoil * 0.18 * motion + ascensionRecoil * 0.30)
    crest:SetTransformOffset(0, -recoil * 4 * motion, 0)
    crest.rim:SetBorderColor(r, g, b, 0.95)
    crest.blade:SetCenterColor(1, 0.94, 0.75, 1)
    crest.strike:SetAlpha(ClampNumber(flash * 0.65, 0, 1))
    crest.bevel:SetCenterColor(0.30 + epic * 0.08, 0.33 + epic * 0.035, 0.32, 1)
    for _, crown in ipairs(crest.crown) do
        crown:SetHidden(tier < 5)
        crown:SetBorderColor(r, g, b, 1)
        crown:SetCenterColor(tier >= 6 and 0.75 or 0.20, 0.11, 0.035, 0.95)
    end
    crest.aura:SetHidden(tier < 4)
    crest.aura:SetBorderColor(r, g, b, 0.45)
    crest.aura:SetTransformScale(1 + ascensionRecoil * 0.5)
    crest.aura:SetTransformRotationZ(tier >= 6 and math.sin(nowMS * 0.0012) * 0.22 * motion or 0)
    for index, rune in ipairs(root.timer.runes) do
        rune:SetHidden(tier < 5 or (tier == 5 and index > 4))
        local count = tier >= 6 and 6 or 4
        local angle = (index - 1) * math.pi * 2 / count + (motion > 0 and nowMS * 0.00065 * motion or 0)
        local radius = (tier >= 6 and 43 or 36) + ascensionRecoil * 20
        rune:SetTransformOffset(math.cos(angle) * radius, math.sin(angle) * radius * 0.72, 0)
        rune:SetTransformRotationZ(angle + math.pi * 0.5)
        rune:SetCenterColor(index % 2 == 0 and r or 1, index % 2 == 0 and g or 0.30, index % 2 == 0 and b or 0.08, 0.9)
        rune:SetAlpha(0.65 + (tier >= 6 and math.sin(nowMS * 0.004 + index) * 0.25 * math.min(motion, 1) or 0))
    end
    root.caption:ClearAnchors()
    root.caption:SetAnchor(CENTER, root.visual, CENTER, 0, 104 + epic * 6)
    for index, rank in ipairs(crest.ranks) do
        rank:SetCenterColor(r, g, b, index <= (self.minigameHighestTier or 0) and 0.95 or 0.16)
    end
    local mode = IsMinigameDpsMode() and "DPS" or "DAMAGE DONE"
    local count = self.minigameHitCount or 0
    local parts = {}
    local showMode = GetMinigameSettingValue("showModeLabel") ~= false
    if self.minigameFinisher and GetMinigameSettingValue("showPeakLabel") ~= false then
        parts[#parts + 1] = showMode and ("PEAK " .. mode) or "PEAK"
    elseif showMode then
        parts[#parts + 1] = mode
    end
    if GetMinigameSettingValue("showHitCount") ~= false then
        parts[#parts + 1] = string.format("%d %s", count, count == 1 and "HIT" or "HITS")
    end
    local text = table.concat(parts, "  /  ")
    if root.captionText ~= text then
        root.caption:SetText(text)
        root.captionText = text
    end
    root.caption:SetHidden(text == "")
end

function DamageNumbers:ResetDamageDoneMinigame(cancelPreview)
    if cancelPreview ~= false then
        self.minigamePreviewId = (self.minigamePreviewId or 0) + 1
    end

    self.minigameScore = nil
    self.minigameDisplayScore = nil
    self.minigameCountStartValue = nil
    self.minigameCountTargetValue = nil
    self.minigameCountStartMS = nil
    self.minigameGraceUntilMS = nil
    self.minigameDrainStartMS = nil
    self.minigameDrainStartValue = nil
    self.minigameDpsStartMS = nil
    self.minigameDpsTotalDamage = nil
    self.minigameHighestTier = nil
    self.minigameImpact = nil
    self.minigameShockwave = nil
    self.minigameSparks = nil
    self.minigameFinisher = nil
    self.minigameAscension = nil
    self.minigameHitCount = nil
    self.minigamePeak = nil
    self.minigamePreviewing = nil
    self.minigameLastDelta = nil

    local root = self.minigameRoot
    if root then
        root:SetHandler("OnUpdate", nil)
        root:SetAlpha(0)
        root:SetHidden(true)
        root.visual:SetTransformScale(1)
        root.visual:SetTransformRotationZ(GetMinigameBaseRotation())
        root.visual:SetTransformSkewX(GetMinigameBaseSkew())
        root.visual:SetTransformOffset(0, 0, 0)
        root.outerGlow:SetAlpha(0)
        root.impactFlash:SetAlpha(0)
        root.echoRed:SetAlpha(0)
        root.echoGold:SetAlpha(0)
        root.shockwave:SetAlpha(0)
        root.shockwave:SetHidden(true)
        root.maxShockwave:SetHidden(true)
        root.maxShockwave:SetAlpha(0)
        root.timer.crest:SetTransformScale(1)
        root.timer.crest:SetTransformOffset(0, 0, 0)
        root.timer.crest.strike:SetAlpha(0)
        for _, wing in ipairs(root.timer.wings) do
            wing:SetTransformOffset(0, 0, 0)
            wing:SetTransformRotationZ(0)
        end
        for _, delta in ipairs(root.deltas) do
            delta.minigameData = nil
            delta:SetAlpha(0)
            delta:SetHidden(true)
            delta:SetTransformOffset(0, 0, 0)
            delta:SetTransformScale(1)
        end
        for _, spark in ipairs(root.sparks) do
            spark:SetAlpha(0)
            spark:SetHidden(true)
        end
    end
end

function DamageNumbers:UpdateMinigameScore(nowMS)
    local score = math.max(0, self.minigameScore or 0)
    if score <= 0 or self.minigameFinisher then
        return
    end
    local graceUntilMS = self.minigameGraceUntilMS or nowMS

    if IsMinigameDpsMode()
        and score > 0
        and not self.minigameDrainStartMS
        and self.minigameDpsStartMS then
        score = CalculateMinigameDps(self.minigameDpsTotalDamage, self.minigameDpsStartMS, math.min(nowMS, graceUntilMS))
        self.minigameScore = score
        if self.minigameCountStartMS then
            self.minigameCountTargetValue = score
        end
    end

    if nowMS >= graceUntilMS then
        if not self.minigameDrainStartMS then
            self.minigameDrainStartMS = graceUntilMS
            self.minigameDrainStartValue = score
            self.minigameCountStartMS = nil
        end

        local drainProgress = ClampNumber((nowMS - self.minigameDrainStartMS) / MINIGAME_DRAIN_MS, 0, 1)
        score = (self.minigameDrainStartValue or score) * (1 - drainProgress)
        self.minigameScore = score
        self.minigameDisplayScore = score

        if drainProgress >= 1 then
            self.minigameScore = 0
            self.minigameDisplayScore = self.minigamePeak or 0
            self.minigameFinisher =
            {
                startMS = graceUntilMS + MINIGAME_DRAIN_MS,
                durationMS = MINIGAME_FINISH_MS,
            }
        end
    elseif score > 0 and self.minigameCountStartMS then
        local countProgress = ClampNumber((nowMS - self.minigameCountStartMS) / MINIGAME_COUNT_MS, 0, 1)
        self.minigameDisplayScore = self.minigameCountStartValue
            + ((self.minigameCountTargetValue - self.minigameCountStartValue) * EaseOutQuart(countProgress))
        if countProgress >= 1 then
            self.minigameCountStartMS = nil
            self.minigameDisplayScore = self.minigameCountTargetValue
        end
    elseif score > 0 then
        self.minigameDisplayScore = score
    end
end

function DamageNumbers:UpdateDamageDoneMinigame()
    if not IsMinigameEnabled() then
        self:ResetDamageDoneMinigame(true)
        return
    end
    local nowMS = GetFrameTimeMilliseconds()
    self:UpdateMinigameScore(nowMS)

    self:ApplyMinigameText(self.minigameDisplayScore or 0)
    self:UpdateMinigameVisuals(nowMS)

    local root = self:GetMinigameRoot()
    root:SetHidden(false)
    if IsMinigameUnlocked() then
        root:SetAlpha(0)
    end
    if not self.minigamePreviewing and (HUD_SCENE or HUD_UI_SCENE)
        and not ((HUD_SCENE and HUD_SCENE:IsShowing()) or (HUD_UI_SCENE and HUD_UI_SCENE:IsShowing())) then
        -- Keep the clock running while the HUD is covered by a menu.
        root:SetAlpha(0)
    end

    if self.minigameFinisher then
        local finishProgress = (nowMS - self.minigameFinisher.startMS) / self.minigameFinisher.durationMS
        if finishProgress >= 1 then
            self:ResetDamageDoneMinigame(false)
        end
    end
end

function DamageNumbers:GetColor(direction, isCrit)
    if isCrit then
        return 1.0, 0.95, 0.02, 1
    end

    if direction == "incoming" then
        return 1.0, 0.57, 0.14, 1
    end

    return 1.0, 0.91, 0.0, 1
end

function DamageNumbers:ShowDamage(hitValue, isCrit, direction, suppressCritSound)
    if not IsModuleEnabled() or not hitValue or hitValue <= 0 then
        return
    end

    local label = self:AcquireLabel()
    local fontSize = isCrit and GetSettingValue("critFontSize") or GetSettingValue("normalFontSize")
    local durationMS = ClampNumber(GetSettingValue("durationMS"), 450, 1800)
    local spread = ClampNumber(GetSettingValue("spread"), 40, 280)
    local drift = ClampNumber(GetSettingValue("drift"), 0, 160)
    local driftFloor = math.floor(drift * MOVEMENT_MULTIPLIER)
    local bigHitThreshold = GetSettingValue("bigHitThreshold")
    local isBigHit = hitValue >= bigHitThreshold
    local driftScale = isBigHit and BIG_HIT_MOVEMENT_MULTIPLIER or 1
    local startX, startY = self:GetSpawnPosition(direction, spread)
    local driftXDirection = direction == "incoming" and -1 or 1
    local driftX = 0
    local driftY = 0
    local r, g, b, a = self:GetColor(direction, isCrit)

    if driftFloor > 0 then
        driftX = driftXDirection * math.random(math.floor(driftFloor * 0.25), driftFloor) * driftScale
        driftY = -math.random(math.floor(driftFloor * 0.35), math.max(1, math.floor(driftFloor * 0.85))) * driftScale
    end

    label:SetFont(BuildFont(fontSize))
    label:SetText(FormatDamageValue(hitValue))
    label:SetColor(r, g, b, a)
    label:SetDimensions(math.max(320, fontSize * 7), math.max(110, fontSize * 2))
    label:SetHidden(false)
    label:ClearAnchors()
    label:SetAnchor(CENTER, self:GetRoot(), TOPLEFT, startX, startY)
    label:SetScale(isCrit and CRIT_START_SCALE or NORMAL_START_SCALE)
    label:SetAlpha(1)

    label.activeDamageNumber =
    {
        startMS = GetFrameTimeMilliseconds(),
        durationMS = durationMS,
        startX = startX,
        startY = startY,
        endX = startX + driftX,
        endY = startY + driftY,
        startScale = isCrit and CRIT_START_SCALE or NORMAL_START_SCALE,
        endScale = isCrit and CRIT_END_SCALE or NORMAL_END_SCALE,
    }

    table.insert(self.active, label)
    self:StartUpdating()

    if isCrit and not suppressCritSound then
        PlayCriticalSound()
    end
end

function DamageNumbers:ClearLabels()
    if self.active then
        for i = #self.active, 1, -1 do
            self:ReleaseLabel(i)
        end
    end

    if self.root then
        self.root:SetHandler("OnUpdate", nil)
        self.root:SetHidden(true)
    end
end

function DamageNumbers:SuppressDefaultDamageNumbers()
    local settings = GetSettings()
    settings.savedSctSettings = settings.savedSctSettings or {}
    local changedSettings = false

    for _, settingData in ipairs(SCT_DAMAGE_SETTINGS) do
        if settings.savedSctSettings[settingData.key] == nil then
            settings.savedSctSettings[settingData.key] = GetSetting(SETTING_TYPE_COMBAT, settingData.id)
        end
        if GetSetting(SETTING_TYPE_COMBAT, settingData.id) ~= "0" then
            SetSetting(SETTING_TYPE_COMBAT, settingData.id, "0")
            changedSettings = true
        end
    end

    if changedSettings and ApplySettings then
        ApplySettings()
    end
end

function DamageNumbers:RestoreDefaultDamageNumbers()
    local settings = GetSettings()
    local savedSettings = settings.savedSctSettings
    if not savedSettings then
        return
    end

    local changedSettings = false
    for _, settingData in ipairs(SCT_DAMAGE_SETTINGS) do
        local savedValue = savedSettings[settingData.key]
        if savedValue ~= nil then
            if GetSetting(SETTING_TYPE_COMBAT, settingData.id) ~= savedValue then
                SetSetting(SETTING_TYPE_COMBAT, settingData.id, savedValue)
                changedSettings = true
            end
            savedSettings[settingData.key] = nil
        end
    end

    if changedSettings and ApplySettings then
        ApplySettings()
    end
end

function DamageNumbers:ApplySctSettings()
    if IsModuleEnabled() and GetSettingValue("hideDefaultDamage") then
        self:SuppressDefaultDamageNumbers()
    else
        self:RestoreDefaultDamageNumbers()
    end
end

function DamageNumbers:RegisterCombatEvents()
    if self.eventsRegistered then
        return
    end

    local callback = function(_, ...)
        self:OnCombatEvent(...)
    end

    self.eventNamespaces = {}
    for result in pairs(DAMAGE_RESULTS) do
        for unitType in pairs(PLAYER_RELATED_SOURCE_TYPES) do
            local namespace = string.format("%s_Source_%s_%s", EVENT_NAMESPACE, tostring(unitType), tostring(result))
            RegisterFilteredCombatEvent(namespace, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, unitType, result, callback)
            table.insert(self.eventNamespaces, namespace)
        end

        for unitType in pairs(PLAYER_RELATED_TARGET_TYPES) do
            local namespace = string.format("%s_Target_%s_%s", EVENT_NAMESPACE, tostring(unitType), tostring(result))
            RegisterFilteredCombatEvent(namespace, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, unitType, result, callback)
            table.insert(self.eventNamespaces, namespace)
        end
    end

    self.eventsRegistered = true
end

function DamageNumbers:UnregisterCombatEvents()
    if not self.eventsRegistered then
        return
    end

    for _, namespace in ipairs(self.eventNamespaces or {}) do
        EVENT_MANAGER:UnregisterForEvent(namespace, EVENT_COMBAT_EVENT)
    end
    self.eventNamespaces = nil
    self.eventsRegistered = nil
end

function DamageNumbers:RegisterLifecycleEvents()
    if self.lifecycleEventsRegistered then
        return
    end

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Deactivated", EVENT_PLAYER_DEACTIVATED, function()
        self:RestoreDefaultDamageNumbers()
        self:ResetDamageDoneMinigame(true)
    end)
    self.lifecycleEventsRegistered = true
end

function DamageNumbers:OnCombatEvent(result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
    if isError or not IsDamageEvent(result, hitValue) then
        return
    end

    if PLAYER_RELATED_SOURCE_TYPES[sourceType] and PLAYER_RELATED_TARGET_TYPES[targetType] then
        local nowMS = GetFrameTimeMilliseconds()
        if self.lastCombatEventMS == nowMS
            and self.lastCombatResult == result
            and self.lastCombatHitValue == hitValue
            and self.lastCombatSourceUnitId == sourceUnitId
            and self.lastCombatTargetUnitId == targetUnitId
            and self.lastCombatAbilityId == abilityId then
            return
        end
        self.lastCombatEventMS = nowMS
        self.lastCombatResult = result
        self.lastCombatHitValue = hitValue
        self.lastCombatSourceUnitId = sourceUnitId
        self.lastCombatTargetUnitId = targetUnitId
        self.lastCombatAbilityId = abilityId
    end

    local direction
    if IsOutgoingDamage(sourceType) then
        direction = "outgoing"
    elseif IsIncomingDamage(targetType) then
        direction = "incoming"
    else
        return
    end

    local isCrit = IsCriticalResult(result)
    local minigameAudioHandled = false
    if direction == "outgoing"
        and IsMinigameDamageSource(sourceType)
        and not PLAYER_RELATED_TARGET_TYPES[targetType] then
        minigameAudioHandled = self:AddDamageDone(hitValue, isCrit, false)
    end

    self:ShowDamage(hitValue, isCrit, direction, isCrit and minigameAudioHandled)
end

function DamageNumbers:RefreshSettings()
    self:RegisterLifecycleEvents()

    local displayMode = GetMinigameDisplayMode()
    if self.appliedMinigameDisplayMode and self.appliedMinigameDisplayMode ~= displayMode then
        self:ResetDamageDoneMinigame(true)
    end
    self.appliedMinigameDisplayMode = displayMode

    if ShouldRegisterCombatEvents() then
        self:RegisterCombatEvents()
    else
        self:UnregisterCombatEvents()
    end

    if not IsModuleEnabled() then
        self:ClearLabels()
    end

    if not IsMinigameEnabled() then
        self:ResetDamageDoneMinigame(true)
    end

    self:ApplySctSettings()
    self:ApplyMoverState()
    self:ApplyMinigameLayout()
end

function DamageNumbers:DebugNormal()
    self:ShowDamage(math.random(4200, 11800), false, "outgoing")
end

function DamageNumbers:DebugCrit()
    self:ShowDamage(math.random(26000, 88000), true, "outgoing")
end

function DamageNumbers:PreviewCriticalSound()
    lastCritSoundMS = -GetCritSoundThrottleMS()
    PlayCriticalSound()
end

function DamageNumbers:DebugSound()
    self:PreviewCriticalSound()
end

function DamageNumbers:DebugStorm()
    for i = 1, 18 do
        zo_callLater(function()
            local isCrit = math.random(1, 100) <= 28
            local direction = math.random(1, 100) <= 72 and "outgoing" or "incoming"
            local value = isCrit and math.random(18000, 95000) or math.random(1200, 22000)
            self:ShowDamage(value, isCrit, direction)
        end, i * 55)
    end
end

function DamageNumbers:PreviewDamageDoneMinigame(showTiers)
    if not IsMinigameEnabled() then
        return
    end

    self.minigamePreviewId = (self.minigamePreviewId or 0) + 1
    local previewId = self.minigamePreviewId
    self:ResetDamageDoneMinigame(false)

    local previewHits =
    {
        { delayMS = 0, value = 11800, isCrit = false },
        { delayMS = 40, value = 6400, isCrit = false },
        { delayMS = 520, value = 57200, isCrit = true },
        { delayMS = 550, value = 1800, isCrit = false },
        { delayMS = 1450, value = 34800, isCrit = false },
        { delayMS = 2450, value = 168600, isCrit = true },
    }

    if showTiers then
        local milestones = MINIGAME_MILESTONES[GetMinigameDisplayMode()]
        local previousTotal = milestones[1] * 0.5
        previewHits = {{delayMS = 0, value = previousTotal, isCrit = false}}
        for index, threshold in ipairs(milestones) do
            local delayMS = index * 400
            local total = IsMinigameDpsMode() and threshold * math.max(delayMS / 1000, 1) or threshold
            previewHits[#previewHits + 1] = {delayMS = delayMS, value = total - previousTotal, targetScore = threshold, isCrit = true}
            previousTotal = total
        end
    end

    for _, hit in ipairs(previewHits) do
        zo_callLater(function()
            if self.minigamePreviewId == previewId and IsMinigameEnabled() then
                local value = hit.value
                if hit.targetScore then
                    local nowMS = GetFrameTimeMilliseconds()
                    self:UpdateMinigameScore(nowMS)
                    local expired = self.minigameFinisher ~= nil
                    if IsMinigameDpsMode() then
                        local elapsedMS = not expired and self.minigameDpsStartMS and (nowMS - self.minigameDpsStartMS) or 0
                        local total = not expired and self.minigameDpsTotalDamage or 0
                        -- Use the actual callback time so a delayed frame cannot miss a tier.
                        value = math.ceil(hit.targetScore * math.max(elapsedMS, 1000) / 1000 - total)
                    else
                        value = hit.targetScore - (not expired and self.minigameScore or 0)
                    end
                end
                self:AddDamageDone(math.max(1, value), hit.isCrit, true)
            end
        end, hit.delayMS)
    end
end

function DamageNumbers:DebugMinigame()
    self:PreviewDamageDoneMinigame()
end

local DEBUG_COMMANDS =
{
    ["/nsdmg"] = function()
        DamageNumbers:DebugNormal()
    end,
    ["/nsdmgcrit"] = function()
        DamageNumbers:DebugCrit()
    end,
    ["/nsdmgsound"] = function()
        DamageNumbers:DebugSound()
    end,
    ["/nsdmgstorm"] = function()
        DamageNumbers:DebugStorm()
    end,
    ["/nsdmgmini"] = function()
        DamageNumbers:DebugMinigame()
    end,
}

local function IsDebugModeEnabled()
    return NAGA_UI.Settings and NAGA_UI.Settings:IsDebugModeEnabled()
end

local function RegisterDebugCommands()
    for command, handler in pairs(DEBUG_COMMANDS) do
        SLASH_COMMANDS[command] = IsDebugModeEnabled() and handler or nil
    end
end

function DamageNumbers:RefreshDebugCommands()
    RegisterDebugCommands()
end

NAGA_UI.OnAddonLoaded(function()
    DamageNumbers:RefreshSettings()
    RegisterDebugCommands()
end)
