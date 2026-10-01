local ADDON_NAME = "NirnsteelUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_ExperienceTracker"

Nirnsteel_UI = Nirnsteel_UI or {}
local Nirnsteel_UI = Nirnsteel_UI
local ExperienceTracker = {}
Nirnsteel_UI.ExperienceTracker = ExperienceTracker

local DEFAULT_SETTINGS =
{
    enabled = true,
    unlocked = false,
    scale = 100,
    opacity = 100,
    width = 460,
    height = 56,
    durationMS = 3600,
    intensity = 100,
    visibilityMode = "fade",
    chunkSoundKey = "PROMOTIONAL_EVENT_REWARD_TO_CLAIM_PROMPT",
    levelUpSoundKey = "BATTLEGROUND_ROUND_RECAP_SCREEN_FINAL_WIN",
    showGainText = true,
    showProgressText = true,
    showChampionIcon = true,
    levelUpAnimationEnabled = true,
    levelUpIntensity = 100,
    hideBackground = false,
    hideStockProgressBar = true,
}

local DEFAULT_POSITION = { x = 30, y = 30 }
local BAR_TEXTURE = "EsoUI/Art/Miscellaneous/progressbar_genericFill_tall.dds"
local BAR_GLOSS_TEXTURE = "EsoUI/Art/Miscellaneous/timerBar_genericFill_gloss.dds"
local BAR_LEADING_EDGE_TEXTURE = "EsoUI/Art/Miscellaneous/progressbar_genericFill_leadingEdge_blunt.dds"
local EDGE_FRAME_TEXTURE = "EsoUI/Art/Miscellaneous/Gamepad/edgeframeGamepadBorder_thin.dds"
local TRACK_TEXTURE = "EsoUI/Art/Miscellaneous/progressbar_genericFill_tall.dds"
local ORNAMENT_TEXTURE = "EsoUI/Art/Miscellaneous/listItem_backdrop_white.dds"
local CHAMPION_ICON = "EsoUI/Art/Champion/champion_icon.dds"
local BAR_TEXTURE_COORDS = { 0, 1, 0, 0.8125 }
local SEGMENT_DURATION_MS = 1100
local LEVEL_UP_BURST_DURATION_MS = 1050
local TICK_IMPACT_MS = 230
local LEVEL_REVEAL_POINT = 0.24
local FADE_IN_MS = 130
local FADE_OUT_MS = 360
local GAIN_DEDUPLICATION_MS = 1000
local STOCK_HOOK_RETRY_MS = 500
local MAX_STOCK_HOOK_ATTEMPTS = 30
local MIN_CHUNKS = 3
local MAX_CHUNKS = 5
local CHUNK_PULSE_COUNT = 10
local CHUNK_PULSE_MS = 460
local STEEL_RIM = { 0.24, 0.30, 0.34, 0.55 }
local STEEL_HIGHLIGHT = { 0.48, 0.58, 0.64, 0.48 }

local CP_ICONS =
{
    [CHAMPION_DISCIPLINE_TYPE_WORLD] = "EsoUI/Art/Champion/champion_points_stamina_icon-HUD-32.dds",
    [CHAMPION_DISCIPLINE_TYPE_COMBAT] = "EsoUI/Art/Champion/champion_points_magicka_icon-HUD-32.dds",
    [CHAMPION_DISCIPLINE_TYPE_CONDITIONING] = "EsoUI/Art/Champion/champion_points_health_icon-HUD-32.dds",
}

local FALLBACK_CP_COLORS =
{
    [CHAMPION_DISCIPLINE_TYPE_WORLD] = {
        start = { 0.15, 0.78, 0.35, 0.98 },
        finish = { 0.70, 1.00, 0.46, 1.00 },
        glow = { 0.35, 1.00, 0.48 },
    },
    [CHAMPION_DISCIPLINE_TYPE_COMBAT] = {
        start = { 0.12, 0.40, 0.95, 0.98 },
        finish = { 0.44, 0.82, 1.00, 1.00 },
        glow = { 0.40, 0.78, 1.00 },
    },
    [CHAMPION_DISCIPLINE_TYPE_CONDITIONING] = {
        start = { 0.82, 0.12, 0.12, 0.98 },
        finish = { 1.00, 0.43, 0.32, 1.00 },
        glow = { 1.00, 0.28, 0.20 },
    },
}

local XP_COLORS =
{
    start = { 0.06, 0.52, 0.68, 0.98 },
    finish = { 0.36, 0.92, 1.00, 1.00 },
    glow = { 0.20, 0.90, 1.00 },
}

local function ClampNumber(value, minValue, maxValue)
    value = tonumber(value) or minValue
    return math.min(math.max(value, minValue), maxValue)
end

local function GetSettings()
    if Nirnsteel_UI.Settings then
        return Nirnsteel_UI.Settings:GetExperienceTracker()
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

local function IsModuleEnabled()
    return not Nirnsteel_UI.Settings or Nirnsteel_UI.Settings:IsExperienceTrackerEnabled()
end

local function IsModuleUnlocked()
    return IsModuleEnabled()
        and Nirnsteel_UI.Settings
        and Nirnsteel_UI.Settings:IsExperienceTrackerUnlocked()
end

local function ShouldHideStockProgressBar()
    return IsModuleEnabled()
        and (not Nirnsteel_UI.Settings or Nirnsteel_UI.Settings:ShouldExperienceTrackerHideStockProgressBar())
end

local function GetPosition()
    if Nirnsteel_UI.Settings then
        return Nirnsteel_UI.Settings:GetExperienceTrackerPosition()
    end

    return DEFAULT_POSITION
end

local function GetScale()
    return ClampNumber(GetSettingValue("scale"), 70, 160) / 100
end

local function GetAlpha()
    return ClampNumber(GetSettingValue("opacity"), 20, 100) / 100
end

local function GetConfiguredWidth()
    return ClampNumber(GetSettingValue("width"), 360, 680)
end

local function GetConfiguredHeight()
    return ClampNumber(GetSettingValue("height"), 54, 76)
end

local function GetVisibleDurationMS()
    return ClampNumber(GetSettingValue("durationMS"), 1800, 7000)
end

local function GetIntensity()
    return ClampNumber(GetSettingValue("intensity"), 0, 140) / 100
end

local function GetLevelUpIntensity()
    return ClampNumber(GetSettingValue("levelUpIntensity"), 0, 160) / 100
end

local function ShouldShowGainText()
    return GetSettingValue("showGainText") ~= false
end

local function ShouldShowProgressText()
    return GetSettingValue("showProgressText") ~= false
end

local function ShouldShowChampionIcon()
    return GetSettingValue("showChampionIcon") ~= false
end

local function ShouldPlayLevelUpAnimation()
    return GetSettingValue("levelUpAnimationEnabled") ~= false
end

local function ShouldHideBackground()
    return GetSettingValue("hideBackground") == true
end

local function IsAlwaysVisible()
    return GetSettingValue("visibilityMode") == "always"
end

local SOUND_KEY_ALIASES =
{
    None = "none",
    ["Outfit Weapon Type Rune"] = "OUTFIT_WEAPON_TYPE_RUNE",
    ["Promotional Event Reward To Claim"] = "PROMOTIONAL_EVENT_REWARD_TO_CLAIM_PROMPT",
    ["Endless Dungeon Counter Down"] = "ENDLESS_DUNGEON_COUNTER_DOWN",
    ["Battleground Round Recap Final Win"] = "BATTLEGROUND_ROUND_RECAP_SCREEN_FINAL_WIN",
    ["Battleground Round Recap Win"] = "BATTLEGROUND_ROUND_RECAP_SCREEN_WIN",
}

local function NormalizeSoundKey(key)
    if not key or key == "" then
        return nil
    end

    key = SOUND_KEY_ALIASES[key] or key
    if key == "none" or key == "None" then
        return nil
    end

    return key
end

local function GetSoundBySettingKey(settingKey)
    local key = NormalizeSoundKey(GetSettingValue(settingKey))
    if not key then
        return nil
    end

    if SOUNDS and SOUNDS[key] then
        return SOUNDS[key]
    end

    return key
end

local function GetChunkSound()
    return GetSoundBySettingKey("chunkSoundKey")
end

local function GetLevelUpSound()
    return GetSoundBySettingKey("levelUpSoundKey")
end

local function PlayLevelUpSound()
    local sound = GetLevelUpSound()
    if sound then
        PlaySound(sound)
    end
end

local function IsHudSceneShowing()
    return (HUD_SCENE and HUD_SCENE:IsShowing()) or (HUD_UI_SCENE and HUD_UI_SCENE:IsShowing())
end

local function EaseOutCubic(progress)
    local inverse = 1 - progress
    return 1 - inverse * inverse * inverse
end

local function UnpackColorTable(color, fallback)
    color = color or fallback
    return color[1], color[2], color[3], color[4] or 1
end

local function ApplyGradientFromColorDefs(statusBar, gradient)
    if statusBar and gradient and gradient[1] and gradient[2] then
        local r, g, b, a = gradient[1]:UnpackRGBA()
        local r2, g2, b2, a2 = gradient[2]:UnpackRGBA()
        statusBar:SetGradientColors(r, g, b, a, r2, g2, b2, a2)
        return true
    end

    return false
end

local function GetNextChampionPool(championPoints)
    local shownRank = tonumber(championPoints) or GetPlayerChampionPointsEarned()
    if GetNumChampionXPInChampionPoint(shownRank) ~= nil then
        shownRank = shownRank + 1
    end
    return GetChampionPointPoolForRank(shownRank)
end

local function GetModeInfo(mode, level)
    if mode == "cp" then
        local pool = GetNextChampionPool(level)
        local fallback = FALLBACK_CP_COLORS[pool] or FALLBACK_CP_COLORS[CHAMPION_DISCIPLINE_TYPE_WORLD]
        return {
            mode = mode,
            pool = pool,
            start = fallback.start,
            finish = fallback.finish,
            glow = fallback.glow,
            gradient = ZO_CP_BAR_GRADIENT_COLORS and ZO_CP_BAR_GRADIENT_COLORS[pool],
            icon = CP_ICONS[pool] or CHAMPION_ICON,
        }
    end

    return {
        mode = mode,
        start = XP_COLORS.start,
        finish = XP_COLORS.finish,
        glow = XP_COLORS.glow,
        gradient = ZO_XP_BAR_GRADIENT_COLORS,
        icon = nil,
    }
end

local function GetLevelSize(mode, level)
    if mode == "cp" then
        return GetNumChampionXPInChampionPoint(level)
    end

    return GetNumExperiencePointsInLevel(level)
end

local function FormatNumber(value)
    if ZO_CommaDelimitNumber then
        return ZO_CommaDelimitNumber(value)
    end

    return tostring(value)
end

local function FormatCompactNumber(value)
    value = math.max(tonumber(value) or 0, 0)
    local divisor
    local suffix
    if value >= 1000000 then
        divisor, suffix = 1000000, "M"
    elseif value >= 1000 then
        divisor, suffix = 1000, "K"
    else
        return tostring(math.floor(value + 0.5))
    end

    local shortened = string.format("%.1f", value / divisor):gsub("%.0$", "")
    return shortened .. suffix
end

local function FormatGainNumber(value)
    if GetConfiguredWidth() < 420 then
        return FormatCompactNumber(value)
    end

    return FormatNumber(value)
end

local function FormatProgressText(value, maxValue)
    maxValue = math.max(tonumber(maxValue) or 1, 1)
    value = zo_clamp(tonumber(value) or 0, 0, maxValue)
    value = math.floor(value + 0.5)
    if GetConfiguredWidth() < 420 then
        return string.format("%s / %s", FormatCompactNumber(value), FormatCompactNumber(maxValue))
    end
    return string.format("%s / %s", FormatNumber(value), FormatNumber(maxValue))
end

local function GetModeLabel(mode)
    if mode == "cp" then
        return "CHAMPION"
    end

    return GetString(SI_EXPERIENCE_LEVEL_LABEL) or "LEVEL"
end

local function GetLevelTextWidthHint(level)
    local text = tostring(level or "")
    local digits = math.max(#text, 2)
    return digits * 18
end

local function GetLevelFontSize(level, mode)
    local digits = #tostring(level or "")
    if digits >= 5 then
        return mode == "cp" and 26 or 28
    elseif digits >= 4 then
        return mode == "cp" and 30 or 32
    end

    return mode == "cp" and 34 or 36
end

local function ConfigureStatusBar(bar)
    bar:SetTexture(BAR_TEXTURE)
    bar:SetTextureCoords(unpack(BAR_TEXTURE_COORDS))
    bar:EnableLeadingEdge(false)
    bar:SetLeadingEdge(BAR_LEADING_EDGE_TEXTURE, 4, 12)
    bar:SetLeadingEdgeTextureCoords(0, 1, 0, 0.8125)
    bar:SetPixelRoundingEnabled(false)
end

function ExperienceTracker:GetRoot()
    if self.root then
        return self.root
    end

    local wm = WINDOW_MANAGER
    local root = wm:CreateTopLevelWindow("Nirnsteel_UI_ExperienceTrackerRoot")
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(false)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)
    root:SetAlpha(0)

    local outerShadow = wm:CreateControl(nil, root, CT_BACKDROP)
    outerShadow:SetCenterColor(0, 0, 0, 0.12)
    outerShadow:SetEdgeColor(0, 0, 0, 0.76)
    outerShadow:SetEdgeTexture(EDGE_FRAME_TEXTURE, 128, 16, 5, 0)
    outerShadow:SetDrawLayer(DL_BACKGROUND)
    root.outerShadow = outerShadow

    local panel = wm:CreateControl(nil, root, CT_BACKDROP)
    panel:SetCenterColor(0.018, 0.025, 0.030, 0.94)
    panel:SetEdgeColor(unpack(STEEL_RIM))
    panel:SetEdgeTexture("", 1, 1, 1, 0)
    panel:SetDrawLayer(DL_BACKGROUND)
    root.panel = panel

    local panelInset = wm:CreateControl(nil, root, CT_BACKDROP)
    panelInset:SetCenterColor(0, 0, 0, 0)
    panelInset:SetEdgeColor(0.16, 0.20, 0.22, 0.24)
    panelInset:SetEdgeTexture("", 1, 1, 1, 0)
    panelInset:SetDrawLayer(DL_OVERLAY)
    root.panelInset = panelInset

    local topRail = wm:CreateControl(nil, root, CT_TEXTURE)
    topRail:SetTexture(ORNAMENT_TEXTURE)
    topRail:SetColor(STEEL_HIGHLIGHT[1], STEEL_HIGHLIGHT[2], STEEL_HIGHLIGHT[3], 0.24)
    topRail:SetDrawLayer(DL_OVERLAY)
    topRail:SetAlpha(0.72)
    root.topRail = topRail

    local bottomRail = wm:CreateControl(nil, root, CT_TEXTURE)
    bottomRail:SetTexture(ORNAMENT_TEXTURE)
    bottomRail:SetColor(STEEL_RIM[1], STEEL_RIM[2], STEEL_RIM[3], 0.20)
    bottomRail:SetDrawLayer(DL_OVERLAY)
    bottomRail:SetAlpha(0.60)
    root.bottomRail = bottomRail

    local badgeGlow = wm:CreateControl(nil, root, CT_BACKDROP)
    badgeGlow:SetCenterColor(0.40, 0.65, 0.80, 0.03)
    badgeGlow:SetEdgeColor(0.40, 0.65, 0.80, 0.16)
    badgeGlow:SetEdgeTexture(EDGE_FRAME_TEXTURE, 128, 16, 6, 0)
    badgeGlow:SetDrawLayer(DL_CONTROLS)
    badgeGlow:SetAlpha(0.22)
    root.badgeGlow = badgeGlow

    local badge = wm:CreateControl(nil, root, CT_BACKDROP)
    badge:SetCenterColor(0.025, 0.034, 0.040, 0.96)
    badge:SetEdgeColor(unpack(STEEL_HIGHLIGHT))
    badge:SetEdgeTexture("", 1, 1, 1, 0)
    badge:SetDrawLayer(DL_CONTROLS)
    root.badge = badge

    local divider = wm:CreateControl(nil, root, CT_TEXTURE)
    divider:SetTexture(ORNAMENT_TEXTURE)
    divider:SetColor(STEEL_HIGHLIGHT[1], STEEL_HIGHLIGHT[2], STEEL_HIGHLIGHT[3], 0.22)
    divider:SetDrawLayer(DL_OVERLAY)
    root.divider = divider

    local levelLabel = wm:CreateControl(nil, root, CT_LABEL)
    levelLabel:SetFont("$(BOLD_FONT)|36|soft-shadow-thin")
    levelLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    levelLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    levelLabel:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
    levelLabel:SetText("45")
    root.levelLabel = levelLabel

    local nextLevelLabel = wm:CreateControl(nil, root, CT_LABEL)
    nextLevelLabel:SetFont("$(BOLD_FONT)|36|soft-shadow-thin")
    nextLevelLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    nextLevelLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    nextLevelLabel:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
    nextLevelLabel:SetAlpha(0)
    nextLevelLabel:SetHidden(true)
    root.nextLevelLabel = nextLevelLabel

    local typeLabel = wm:CreateControl(nil, root, CT_LABEL)
    typeLabel:SetFont("$(BOLD_FONT)|14|soft-shadow-thin")
    typeLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    typeLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    typeLabel:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
    typeLabel:SetText("LEVEL")
    root.typeLabel = typeLabel

    local icon = wm:CreateControl(nil, root, CT_TEXTURE)
    icon:SetHidden(true)
    icon:SetDrawLayer(DL_OVERLAY)
    root.icon = icon

    local progressLabel = wm:CreateControl(nil, root, CT_LABEL)
    progressLabel:SetFont("$(MEDIUM_FONT)|12|soft-shadow-thin")
    progressLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    progressLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    progressLabel:SetColor(0.67, 0.73, 0.76, 0.96)
    progressLabel:SetText("")
    root.progressLabel = progressLabel

    local percentLabel = wm:CreateControl(nil, root, CT_LABEL)
    percentLabel:SetFont("$(BOLD_FONT)|14|soft-shadow-thin")
    percentLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    percentLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    percentLabel:SetColor(0.91, 0.94, 0.94, 1)
    root.percentLabel = percentLabel

    local track = wm:CreateControl(nil, root, CT_BACKDROP)
    track:SetCenterColor(0.003, 0.004, 0.005, 0.94)
    track:SetEdgeColor(unpack(STEEL_RIM))
    track:SetEdgeTexture("", 1, 1, 1, 0)
    root.track = track

    local trackShade = wm:CreateControl(nil, root, CT_TEXTURE)
    trackShade:SetTexture(TRACK_TEXTURE)
    trackShade:SetTextureCoords(unpack(BAR_TEXTURE_COORDS))
    trackShade:SetColor(1, 1, 1, 0.025)
    trackShade:SetDrawLayer(DL_CONTROLS)
    root.trackShade = trackShade

    local trackInnerShadow = wm:CreateControl(nil, root, CT_BACKDROP)
    trackInnerShadow:SetCenterColor(0, 0, 0, 0.06)
    trackInnerShadow:SetEdgeColor(0, 0, 0, 0.76)
    trackInnerShadow:SetEdgeTexture(EDGE_FRAME_TEXTURE, 128, 16, 2, 0)
    trackInnerShadow:SetDrawLayer(DL_OVERLAY)
    root.trackInnerShadow = trackInnerShadow

    local impactFlash = wm:CreateControl(nil, root, CT_BACKDROP)
    impactFlash:SetCenterColor(1, 1, 1, 0)
    impactFlash:SetEdgeTexture(EDGE_FRAME_TEXTURE, 128, 16, 8, 0)
    impactFlash:SetDrawLayer(DL_OVERLAY)
    impactFlash:SetAlpha(0)
    root.impactFlash = impactFlash

    local enlightened = wm:CreateControl(nil, root, CT_STATUSBAR)
    ConfigureStatusBar(enlightened)
    enlightened:SetAlpha(0.24)
    enlightened:SetHidden(true)
    enlightened:SetDrawLayer(DL_CONTROLS)
    root.enlightened = enlightened

    local bar = wm:CreateControl(nil, root, CT_STATUSBAR)
    ConfigureStatusBar(bar)
    bar:SetDrawLayer(DL_CONTROLS)
    root.bar = bar

    local bulk = wm:CreateControl(nil, root, CT_STATUSBAR)
    ConfigureStatusBar(bulk)
    bulk:SetDrawLayer(DL_OVERLAY)
    bulk:SetAlpha(0)
    bulk:SetHidden(true)
    root.bulk = bulk

    local gloss = wm:CreateControl(nil, root, CT_STATUSBAR)
    gloss:SetTexture(BAR_GLOSS_TEXTURE)
    gloss:SetTextureCoords(unpack(BAR_TEXTURE_COORDS))
    gloss:EnableLeadingEdge(false)
    gloss:SetColor(1, 1, 1, 0.20)
    gloss:SetDrawLayer(DL_OVERLAY)
    root.gloss = gloss

    -- The tick response lives on the fill itself, separate from the sparks.
    local tickFlash = wm:CreateControl(nil, root, CT_STATUSBAR)
    ConfigureStatusBar(tickFlash)
    tickFlash:SetDrawLayer(DL_OVERLAY)
    tickFlash:SetAlpha(0)
    tickFlash:SetHidden(true)
    root.tickFlash = tickFlash

    local fillEdge = wm:CreateControl(nil, root, CT_TEXTURE)
    fillEdge:SetColor(0.85, 1, 1, 0.9)
    fillEdge:SetDrawLayer(DL_OVERLAY)
    fillEdge:SetHidden(true)
    root.fillEdge = fillEdge

    root.trackTicks = {}
    for i = 1, 3 do
        local tick = wm:CreateControl(nil, root, CT_TEXTURE)
        tick:SetColor(0.01, 0.02, 0.025, 0.35)
        tick:SetDrawLayer(DL_OVERLAY)
        root.trackTicks[i] = tick
    end

    local glow = wm:CreateControl(nil, root, CT_BACKDROP)
    glow:SetCenterColor(0, 0, 0, 0)
    glow:SetEdgeTexture(EDGE_FRAME_TEXTURE, 128, 16, 6, 0)
    glow:SetDrawLayer(DL_OVERLAY)
    glow:SetAlpha(0)
    root.glow = glow

    local shine = wm:CreateControl(nil, root, CT_TEXTURE)
    shine:SetTexture("EsoUI/Art/Miscellaneous/progressbar_texture_overlay.dds")
    shine:SetColor(1, 1, 1, 1)
    shine:SetAlpha(0)
    shine:SetDrawLayer(DL_OVERLAY)
    shine:SetHidden(true)
    root.shine = shine

    local rewardShine = wm:CreateControl(nil, root, CT_TEXTURE)
    rewardShine:SetTexture("EsoUI/Art/Miscellaneous/progressbar_texture_overlay.dds")
    rewardShine:SetColor(1, 1, 1, 1)
    rewardShine:SetAlpha(0)
    rewardShine:SetDrawLayer(DL_OVERLAY)
    rewardShine:SetHidden(true)
    root.rewardShine = rewardShine

    local levelBurst = wm:CreateControl(nil, root, CT_TEXTURE)
    levelBurst:SetTexture("EsoUI/Art/Miscellaneous/progressbar_texture_overlay.dds")
    levelBurst:SetColor(1, 1, 1, 1)
    levelBurst:SetAlpha(0)
    levelBurst:SetDrawLayer(DL_OVERLAY)
    levelBurst:SetHidden(true)
    root.levelBurst = levelBurst

    local badgeBurst = wm:CreateControl(nil, root, CT_BACKDROP)
    badgeBurst:SetCenterColor(1, 1, 1, 0)
    badgeBurst:SetEdgeTexture("", 1, 1, 1, 0)
    badgeBurst:SetDrawLayer(DL_OVERLAY)
    badgeBurst:SetAlpha(0)
    badgeBurst:SetHidden(true)
    root.badgeBurst = badgeBurst

    root.chunkPulses = {}
    for i = 1, CHUNK_PULSE_COUNT do
        local chunkPulse = wm:CreateControl(nil, root, CT_TEXTURE)
        chunkPulse:SetTexture(ORNAMENT_TEXTURE)
        chunkPulse:SetDrawLayer(DL_OVERLAY)
        chunkPulse:SetAlpha(0)
        chunkPulse:SetHidden(true)
        root.chunkPulses[i] = chunkPulse
    end

    local gainLabel = wm:CreateControl(nil, root, CT_LABEL)
    gainLabel:SetFont("$(BOLD_FONT)|14|soft-shadow-thin")
    gainLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    gainLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    gainLabel:SetAlpha(0)
    gainLabel:SetHidden(true)
    root.gainLabel = gainLabel

    self.root = root
    return root
end

function ExperienceTracker:GetMover()
    if self.mover then
        return self.mover
    end

    local mover = WINDOW_MANAGER:CreateTopLevelWindow("Nirnsteel_UI_ExperienceTrackerMover")
    mover:SetClampedToScreen(true)
    mover:SetMouseEnabled(true)
    mover:SetMovable(false)
    mover:SetDrawTier(DT_HIGH)
    mover:SetHidden(true)

    local backdrop = WINDOW_MANAGER:CreateControl(nil, mover, CT_BACKDROP)
    backdrop:SetAnchorFill(mover)
    backdrop:SetCenterColor(0.02, 0.02, 0.02, 0.55)
    backdrop:SetEdgeColor(0.48, 0.68, 0.80, 0.92)
    backdrop:SetEdgeTexture("", 1, 1, 2)

    local label = WINDOW_MANAGER:CreateControl(nil, mover, CT_LABEL)
    label:SetAnchor(CENTER, mover, CENTER, 0, 0)
    label:SetFont("ZoFontGameBold")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetText("Nirnsteel Experience Tracker")
    label:SetColor(0.76, 0.88, 0.96, 1)

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
        local x = control:GetLeft()
        local y = control:GetTop()
        if Nirnsteel_UI.Settings then
            Nirnsteel_UI.Settings:SetExperienceTrackerPosition(x, y)
        end
        self:ApplyLayout()
    end)

    self.mover = mover
    return mover
end

function ExperienceTracker:AnchorRankLabel(label, verticalOffset)
    local root = self:GetRoot()
    verticalOffset = verticalOffset or 0
    label:ClearAnchors()
    label:SetDimensions(root.rankLabelWidth or root.badge:GetWidth(), root.rankLabelHeight or root.badge:GetHeight())
    if root.rankHasIcon then
        label:SetAnchor(RIGHT, root.badge, RIGHT, -6, verticalOffset)
    else
        label:SetAnchor(CENTER, root.badge, CENTER, 0, verticalOffset)
    end
end

function ExperienceTracker:ApplyLayout()
    local root = self:GetRoot()
    local mover = self:GetMover()
    local position = GetPosition()
    local scale = GetScale()
    local width = GetConfiguredWidth()
    local height = GetConfiguredHeight()
    local pad = 8
    local mode = self.currentMode or "xp"
    local levelText = self.currentLevelText or "45"
    local badgeSize = math.max(40, height - 12)
    local iconSize = 14
    local rankHasIcon = mode == "cp" and ShouldShowChampionIcon()
    local iconSpace = rankHasIcon and (iconSize + 6) or 0
    local badgeWidth = math.max(badgeSize, GetLevelTextWidthHint(levelText) + 12 + iconSpace)
    local contentX = pad + badgeWidth + math.max(11, math.floor(height * 0.18))
    local contentWidth = math.max(150, width - contentX - pad)
    local headerHeight = 16
    local barHeight = math.max(9, math.floor(height * 0.18))
    local contentTop = math.floor((height - headerHeight - barHeight - 18) * 0.5)
    local barTop = contentTop + headerHeight + 4
    local hideBackground = ShouldHideBackground()

    root:SetDimensions(width, height)
    root:SetScale(scale)
    root:ClearAnchors()
    root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, position.x, position.y)

    root.outerShadow:ClearAnchors()
    root.outerShadow:SetAnchor(TOPLEFT, root, TOPLEFT, -4, -4)
    root.outerShadow:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, 4, 4)
    root.outerShadow:SetHidden(hideBackground)

    root.panel:ClearAnchors()
    root.panel:SetAnchorFill(root)
    root.panel:SetHidden(hideBackground)

    root.panelInset:ClearAnchors()
    root.panelInset:SetAnchor(TOPLEFT, root, TOPLEFT, 2, 2)
    root.panelInset:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, -2, -2)
    root.panelInset:SetHidden(hideBackground)

    root.topRail:ClearAnchors()
    root.topRail:SetDimensions(math.max(width - 14, 1), 1)
    root.topRail:SetAnchor(TOP, root, TOP, 0, 3)
    root.topRail:SetHidden(hideBackground)

    root.bottomRail:ClearAnchors()
    root.bottomRail:SetDimensions(math.max(width - 24, 1), 1)
    root.bottomRail:SetAnchor(BOTTOM, root, BOTTOM, 0, -3)
    root.bottomRail:SetHidden(hideBackground)

    root.badgeGlow:ClearAnchors()
    root.badgeGlow:SetDimensions(badgeWidth + 4, badgeSize + 4)
    root.badgeGlow:SetAnchor(LEFT, root, LEFT, pad - 2, 0)

    root.badge:ClearAnchors()
    root.badge:SetDimensions(badgeWidth, badgeSize)
    root.badge:SetAnchor(CENTER, root.badgeGlow, CENTER, 0, 0)

    root.divider:ClearAnchors()
    root.divider:SetDimensions(1, math.max(height - 14, 1))
    root.divider:SetAnchor(LEFT, root, LEFT, contentX - 6, 0)
    root.divider:SetHidden(hideBackground)

    root.rankLabelWidth = rankHasIcon and (badgeWidth - iconSpace - 12) or badgeWidth
    root.rankLabelHeight = badgeSize
    root.rankHasIcon = rankHasIcon
    self:AnchorRankLabel(root.levelLabel, 0)
    root.levelLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", GetLevelFontSize(levelText, mode)))
    self:AnchorRankLabel(root.nextLevelLabel, 0)
    root.nextLevelLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", GetLevelFontSize(root.nextLevelLabel:GetText(), mode)))

    root.typeLabel:ClearAnchors()
    root.typeLabel:SetDimensions(contentWidth - 48, headerHeight)
    root.typeLabel:SetAnchor(TOPLEFT, root, TOPLEFT, contentX, contentTop)

    root.icon:ClearAnchors()
    root.icon:SetDimensions(iconSize, iconSize)
    root.icon:SetAnchor(LEFT, root.badge, LEFT, 6, 0)

    root.progressLabel:ClearAnchors()
    root.progressLabel:SetDimensions(contentWidth, 13)
    root.progressLabel:SetAnchor(TOPRIGHT, root, TOPRIGHT, -pad, barTop + barHeight + 2)
    root.progressLabel:SetHidden(not ShouldShowProgressText())

    root.percentLabel:ClearAnchors()
    root.percentLabel:SetDimensions(44, headerHeight)
    root.percentLabel:SetAnchor(TOPRIGHT, root, TOPRIGHT, -pad, contentTop)
    root.percentLabel:SetHidden(not ShouldShowProgressText())

    root.track:ClearAnchors()
    root.track:SetDimensions(contentWidth, barHeight)
    root.track:SetAnchor(TOPLEFT, root, TOPLEFT, contentX, barTop)

    root.trackShade:ClearAnchors()
    root.trackShade:SetAnchorFill(root.track)

    root.trackInnerShadow:ClearAnchors()
    root.trackInnerShadow:SetAnchorFill(root.track)

    root.impactFlash:ClearAnchors()
    root.impactFlash:SetAnchor(TOPLEFT, root.track, TOPLEFT, -8, -8)
    root.impactFlash:SetAnchor(BOTTOMRIGHT, root.track, BOTTOMRIGHT, 8, 8)

    root.enlightened:ClearAnchors()
    root.enlightened:SetAnchorFill(root.track)

    self:SetFillHeight(barHeight)

    root.bulk:ClearAnchors()
    root.bulk:SetAnchorFill(root.track)


    for index, tick in ipairs(root.trackTicks) do
        tick:ClearAnchors()
        tick:SetDimensions(1, barHeight)
        tick:SetAnchor(CENTER, root.track, LEFT, contentWidth * index / 4, 0)
    end
    self:UpdateFillEdge(self.displayValue or 0, self.displayMaximum or 1)

    root.glow:ClearAnchors()
    root.glow:SetAnchor(TOPLEFT, root.track, TOPLEFT, -4, -4)
    root.glow:SetAnchor(BOTTOMRIGHT, root.track, BOTTOMRIGHT, 4, 4)

    root.shine:ClearAnchors()
    root.shine:SetDimensions(math.max(28, contentWidth * 0.12), barHeight + 2)
    root.shine:SetAnchor(LEFT, root.track, LEFT, -root.shine:GetWidth(), 0)

    root.rewardShine:ClearAnchors()
    root.rewardShine:SetDimensions(math.max(76, contentWidth * 0.34), barHeight + 18)
    root.rewardShine:SetAnchor(LEFT, root.track, LEFT, -root.rewardShine:GetWidth(), 0)

    root.levelBurst:ClearAnchors()
    root.levelBurst:SetDimensions(contentWidth, 2)
    root.levelBurst:SetAnchor(LEFT, root.track, LEFT, 0, 0)

    root.badgeBurst:ClearAnchors()
    root.badgeBurst:SetDimensions(badgeWidth - 12, 2)
    root.badgeBurst:SetAnchor(BOTTOM, root.badge, BOTTOM, 0, -2)

    for _, chunkPulse in ipairs(root.chunkPulses) do
        chunkPulse:ClearAnchors()
        chunkPulse:SetDimensions(5, barHeight + 8)
        chunkPulse:SetAnchor(CENTER, root.track, LEFT, 0, 0)
    end

    root.gainLabel:ClearAnchors()
    root.gainLabel:SetDimensions(contentWidth - 48, headerHeight)
    root.gainLabel:SetAnchor(TOPLEFT, root, TOPLEFT, contentX, contentTop)

    mover:SetDimensions(width * scale, height * scale)
    mover:ClearAnchors()
    mover:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, position.x, position.y)
    mover:SetHidden(not IsModuleUnlocked())
end

function ExperienceTracker:SetVisualMode(mode, level)
    local root = self:GetRoot()
    local info = GetModeInfo(mode, level)
    local startR, startG, startB, startA = UnpackColorTable(info.start, XP_COLORS.start)
    local endR, endG, endB, endA = UnpackColorTable(info.finish, XP_COLORS.finish)
    local glowR, glowG, glowB = UnpackColorTable(info.glow, XP_COLORS.glow)

    root.bar:SetGradientColors(startR * 0.65, startG * 0.65, startB * 0.65, startA, endR, endG, endB, endA)
    root.bulk:SetGradientColors(endR, endG, endB, 0.18, 0.9, 1, 1, 0.8)
    if not ApplyGradientFromColorDefs(root.enlightened, info.gradient) then
        root.enlightened:SetGradientColors(startR, startG, startB, 0.55, endR, endG, endB, 0.55)
    end

    root.panel:SetEdgeColor(unpack(STEEL_RIM))
    root.badge:SetEdgeColor(unpack(STEEL_HIGHLIGHT))
    root.tickFlash:SetGradientColors(endR, endG, endB, 0.36, 0.92, 0.98, 1, 1)
    root.badgeGlow:SetEdgeColor(glowR, glowG, glowB, 0.28 + 0.08 * GetIntensity())
    root.badgeGlow:SetCenterColor(glowR, glowG, glowB, 0.02 + 0.025 * GetIntensity())
    root.track:SetEdgeColor(glowR, glowG, glowB, 0.14)
    root.gloss:SetColor(1, 1, 1, 0.10 + (0.04 * GetIntensity()))
    root.glow:SetEdgeColor(glowR, glowG, glowB, 0.48 * GetIntensity())
    root.glow:SetCenterColor(glowR, glowG, glowB, 0.025 * GetIntensity())
    root.impactFlash:SetEdgeColor(glowR, glowG, glowB, 0.9)
    root.impactFlash:SetCenterColor(endR, endG, endB, 0.035)
    root.levelBurst:SetColor(zo_clamp(endR + 0.22, 0, 1), zo_clamp(endG + 0.22, 0, 1), zo_clamp(endB + 0.22, 0, 1), 1)
    root.badgeBurst:SetEdgeColor(0, 0, 0, 0)
    root.badgeBurst:SetCenterColor(endR, endG, endB, 0.95)
    root.rewardShine:SetColor(zo_clamp(endR + 0.28, 0, 1), zo_clamp(endG + 0.28, 0, 1), zo_clamp(endB + 0.28, 0, 1), 1)
    root.gainLabel:SetColor(zo_clamp(endR + 0.16, 0, 1), zo_clamp(endG + 0.16, 0, 1), zo_clamp(endB + 0.16, 0, 1), 1)
    root.typeLabel:SetColor(zo_clamp(endR + 0.10, 0, 1), zo_clamp(endG + 0.10, 0, 1), zo_clamp(endB + 0.10, 0, 1), 0.98)
    root.icon:SetColor(zo_clamp(endR + 0.12, 0, 1), zo_clamp(endG + 0.12, 0, 1), zo_clamp(endB + 0.12, 0, 1), 0.96)
    root.fillEdge:SetColor(zo_lerp(endR, 1, 0.7), zo_lerp(endG, 1, 0.7), zo_lerp(endB, 1, 0.7), 0.9)
    for _, chunkPulse in ipairs(root.chunkPulses) do
        chunkPulse:SetColor(zo_clamp(endR + 0.20, 0, 1), zo_clamp(endG + 0.20, 0, 1), zo_clamp(endB + 0.20, 0, 1), 1)
    end

    if mode == "cp" then
        local levelText = tostring(level or GetPlayerChampionPointsEarned())
        self.currentMode = mode
        self.currentLevelText = levelText
        root.levelLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", GetLevelFontSize(levelText, mode)))
        root.levelLabel:SetText(levelText)
        root.typeLabel:SetHidden(false)
        root.typeLabel:SetText(GetModeLabel(mode))
        root.icon:SetHidden(not ShouldShowChampionIcon())
        root.icon:SetTexture(info.icon)
        root.levelLabel:SetColor(0.95, 0.92, 0.84, 1)
        root.nextLevelLabel:SetColor(0.95, 0.92, 0.84, 1)
    else
        local levelText = tostring(level or GetUnitLevel("player"))
        self.currentMode = mode
        self.currentLevelText = levelText
        root.levelLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", GetLevelFontSize(levelText, mode)))
        root.levelLabel:SetText(levelText)
        root.typeLabel:SetHidden(false)
        root.typeLabel:SetText(GetModeLabel(mode))
        root.icon:SetHidden(true)
        root.levelLabel:SetColor(1, 1, 1, 1)
        root.nextLevelLabel:SetColor(1, 1, 1, 1)
    end

    self.currentTypeText = GetModeLabel(mode)
    root.typeLabel:SetAlpha(1)
    self:ApplyLayout()
end

function ExperienceTracker:RestoreHeader()
    local root = self:GetRoot()
    root.typeLabel:SetText(self.currentTypeText or GetModeLabel(self.currentMode or "xp"))
    root.typeLabel:SetHidden(false)
    root.typeLabel:SetAlpha(1)
    root.gainLabel:SetAlpha(0)
    root.gainLabel:SetScale(1)
    root.gainLabel:SetHidden(true)
end

function ExperienceTracker:SetGainHeader(text)
    local root = self:GetRoot()
    root.gainLabel:SetText(text or "")
    root.gainLabel:SetScale(1)
    root.gainLabel:SetAlpha(0)
    root.gainLabel:SetHidden(not ShouldShowGainText())
    root.typeLabel:SetAlpha(1)
end

function ExperienceTracker:ConfigureGainOverlay(segment)
    local root = self:GetRoot()
    local maximum = math.max(tonumber(segment and segment.maxValue) or 1, 1)
    local startValue = zo_clamp(tonumber(segment and segment.startValue) or 0, 0, maximum)
    local stopValue = zo_clamp(tonumber(segment and segment.stopValue) or startValue, startValue, maximum)
    local delta = math.max(stopValue - startValue, 1)
    local trackWidth = root.track:GetWidth()
    local startX = (startValue / maximum) * trackWidth
    local overlayWidth = math.max(((stopValue - startValue) / maximum) * trackWidth, 1)

    root.bulk:ClearAnchors()
    root.bulk:SetDimensions(overlayWidth, root.track:GetHeight())
    root.bulk:SetAnchor(LEFT, root.track, LEFT, startX, 0)
    root.bulk:SetMinMax(0, delta)
    root.bulk:SetValue(0)
end

function ExperienceTracker:PrepareRankReveal(segment)
    local root = self:GetRoot()
    local mode = segment and segment.mode or self.currentMode or "xp"
    local oldLevel = tonumber(segment and (segment.oldLevel or segment.level)) or tonumber(self.currentLevelText) or 0
    local newLevel = tonumber(segment and segment.newLevel) or (oldLevel + 1)
    local oldText = tostring(oldLevel)
    local newText = tostring(newLevel)

    root.levelLabel:SetText(oldText)
    root.levelLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", GetLevelFontSize(oldText, mode)))
    root.levelLabel:SetAlpha(1)
    root.nextLevelLabel:SetText(newText)
    root.nextLevelLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", GetLevelFontSize(newText, mode)))
    root.nextLevelLabel:SetAlpha(0)
    root.nextLevelLabel:SetHidden(false)

    self.currentLevelText = newText
    self.rankReveal = { mode = mode, oldText = oldText, newText = newText, committed = false }
    self:ApplyLayout()
    self:AnchorRankLabel(root.levelLabel, 0)
    self:AnchorRankLabel(root.nextLevelLabel, 8)
end

function ExperienceTracker:CommitRankReveal()
    local reveal = self.rankReveal
    if not reveal or reveal.committed then
        return
    end

    local root = self:GetRoot()
    reveal.committed = true
    root.levelLabel:SetText(reveal.newText)
    root.levelLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", GetLevelFontSize(reveal.newText, reveal.mode)))
    root.levelLabel:SetAlpha(1)
    root.levelLabel:SetScale(1)
    root.nextLevelLabel:SetAlpha(0)
    root.nextLevelLabel:SetScale(1)
    root.nextLevelLabel:SetHidden(true)
    self.currentLevelText = reveal.newText
    self:AnchorRankLabel(root.levelLabel, 0)
end

function ExperienceTracker:SetFillHeight(height)
    local root = self:GetRoot()
    for _, fill in ipairs({ root.bar, root.gloss, root.tickFlash }) do
        fill:ClearAnchors()
        fill:SetDimensions(root.track:GetWidth(), height)
        fill:SetAnchor(CENTER, root.track, CENTER, 0, 0)
    end
end

function ExperienceTracker:ResetTickImpact()
    local root = self:GetRoot()
    self.tickImpactMS = nil
    root.tickFlash:SetAlpha(0)
    root.tickFlash:SetHidden(true)
    self:SetFillHeight(root.track:GetHeight())
end

function ExperienceTracker:UpdateTickImpact(nowMS)
    if not self.tickImpactMS then return end
    local elapsed = nowMS - self.tickImpactMS
    if elapsed >= TICK_IMPACT_MS or GetIntensity() <= 0 then
        self:ResetTickImpact()
        return
    end

    local root = self:GetRoot()
    local kick = (1 - zo_clamp(elapsed / TICK_IMPACT_MS, 0, 1)) ^ 2 * GetIntensity()
    self:SetFillHeight(root.track:GetHeight() + 3 * kick)
    root.tickFlash:SetMinMax(0, self.displayMaximum or 1)
    root.tickFlash:SetValue(self.displayValue or 0)
    root.tickFlash:SetHidden(false)
    root.tickFlash:SetAlpha(zo_clamp(kick * 0.72, 0, 0.9))
    root.glow:SetAlpha(math.max(root.glow:GetAlpha(), zo_clamp(kick * 0.44, 0, 0.6)))
end

function ExperienceTracker:ResetTransientEffects()
    local root = self:GetRoot()
    self:ResetTickImpact()
    root.glow:SetAlpha(0)
    root.impactFlash:SetAlpha(0)
    root.badgeGlow:SetAlpha(0.22)
    root.topRail:SetAlpha(0.72)
    root.bottomRail:SetAlpha(0.60)
    root.badge:SetScale(1)
    root.levelLabel:SetAlpha(1)
    root.levelLabel:SetScale(1)
    root.nextLevelLabel:SetAlpha(0)
    root.nextLevelLabel:SetScale(1)
    root.nextLevelLabel:SetHidden(true)
    root.bulk:SetAlpha(0)
    root.shine:SetAlpha(0)
    root.rewardShine:SetAlpha(0)
    root.rewardShine:SetHidden(true)
    root.levelBurst:SetAlpha(0)
    root.levelBurst:SetScale(1)
    root.levelBurst:SetHidden(true)
    root.badgeBurst:SetAlpha(0)
    root.badgeBurst:SetScale(1)
    root.badgeBurst:SetHidden(true)
    for _, chunkPulse in ipairs(root.chunkPulses) do
        chunkPulse.activeMS = nil
        chunkPulse:SetAlpha(0)
        chunkPulse:SetHidden(true)
    end
    self.rankReveal = nil
end

function ExperienceTracker:UpdateFillEdge(value, maxValue)
    local root = self:GetRoot()
    local filledWidth = root.track:GetWidth() * zo_clamp(value / math.max(maxValue, 1), 0, 1)
    local edgeWidth = math.min(2, filledWidth)
    root.fillEdge:ClearAnchors()
    root.fillEdge:SetDimensions(edgeWidth, math.max(root.track:GetHeight() - 2, 1))
    root.fillEdge:SetAnchor(LEFT, root.track, LEFT, filledWidth - edgeWidth, 0)
    root.fillEdge:SetHidden(filledWidth < 1)
end

function ExperienceTracker:UpdateProgress(value, maxValue)
    self.displayValue, self.displayMaximum = value, maxValue
    local root = self:GetRoot()
    root.progressLabel:SetText(FormatProgressText(value, maxValue))
    -- Never announce completion before the bar actually reaches its endpoint.
    root.percentLabel:SetText(string.format("%d%%", math.floor(value / math.max(maxValue, 1) * 100)))
    root.progressLabel:SetHidden(not ShouldShowProgressText())
    root.percentLabel:SetHidden(not ShouldShowProgressText())
    self:UpdateFillEdge(value, maxValue)
end

function ExperienceTracker:SetBarValue(value, maxValue)
    local root = self:GetRoot()
    maxValue = math.max(tonumber(maxValue) or 1, 1)
    value = zo_clamp(tonumber(value) or 0, 0, maxValue)
    root.bar:SetMinMax(0, maxValue)
    root.bulk:SetMinMax(0, maxValue)
    root.gloss:SetMinMax(0, maxValue)
    root.enlightened:SetMinMax(0, maxValue)
    root.bar:SetValue(value)
    root.gloss:SetValue(value)
    self:UpdateProgress(value, maxValue)
end

function ExperienceTracker:RefreshEnlightened(mode, level, current, maxValue)
    local root = self:GetRoot()
    if mode ~= "cp" or not IsEnlightenedAvailableForCharacter or not IsEnlightenedAvailableForCharacter() then
        root.enlightened:SetHidden(true)
        return
    end

    local pool = GetEnlightenedPool and GetEnlightenedPool() or 0
    local multiplier = GetEnlightenedMultiplier and GetEnlightenedMultiplier() or 0
    local enlightenedPool = pool * (multiplier + 1)
    if enlightenedPool <= 0 then
        root.enlightened:SetHidden(true)
        return
    end

    maxValue = math.max(tonumber(maxValue) or 1, 1)
    root.enlightened:SetMinMax(0, maxValue)
    root.enlightened:SetValue(zo_min(maxValue, (current or 0) + enlightenedPool))
    root.enlightened:SetHidden(false)
end

function ExperienceTracker:ShowRoot()
    local root = self:GetRoot()
    if root:IsHidden() then
        root:SetAlpha(0)
        root:SetHidden(false)
    end
end

function ExperienceTracker:HideRoot()
    local root = self:GetRoot()
    self:ResetTickImpact()
    root:SetHandler("OnUpdate", nil)
    root:SetAlpha(0)
    root:SetHidden(true)
    root.glow:SetAlpha(0)
    root.impactFlash:SetAlpha(0)
    root.badgeGlow:SetAlpha(0.22)
    root.topRail:SetAlpha(0.72)
    root.bottomRail:SetAlpha(0.60)
    root.badge:SetScale(1)
    root.levelLabel:SetScale(1)
    root.levelLabel:SetAlpha(1)
    root.nextLevelLabel:SetAlpha(0)
    root.nextLevelLabel:SetScale(1)
    root.nextLevelLabel:SetHidden(true)
    root.bulk:SetAlpha(0)
    root.bulk:SetHidden(true)
    root.levelBurst:SetAlpha(0)
    root.levelBurst:SetHidden(true)
    root.badgeBurst:SetAlpha(0)
    root.badgeBurst:SetScale(1)
    root.badgeBurst:SetHidden(true)
    for _, chunkPulse in ipairs(root.chunkPulses) do
        chunkPulse:SetAlpha(0)
        chunkPulse:SetHidden(true)
        chunkPulse.activeMS = nil
    end
    root.shine:SetHidden(true)
    root.rewardShine:SetAlpha(0)
    root.rewardShine:SetHidden(true)
    self:RestoreHeader()
    self.animation = nil
    self.segmentQueue = nil
    self.rankReveal = nil
end

function ExperienceTracker:BuildSegments(mode, level, previousXP, currentXP, maxValue)
    local segments = {}
    previousXP = math.max(tonumber(previousXP) or 0, 0)
    currentXP = math.max(tonumber(currentXP) or 0, 0)
    maxValue = tonumber(maxValue)
    if not maxValue or maxValue <= 0 then
        return segments
    end

    local segmentLevel = tonumber(level) or 0
    local startValue = zo_clamp(previousXP, 0, maxValue)
    local remainingGain = currentXP - previousXP
    if remainingGain <= 0 then
        return segments
    end

    while remainingGain > 0 do
        local room = maxValue - startValue
        if room <= 0 then
            segmentLevel = segmentLevel + 1
            maxValue = GetLevelSize(mode, segmentLevel) or maxValue
            startValue = 0
            room = maxValue
        end

        local delta = math.min(remainingGain, room)
        local stopValue = startValue + delta
        table.insert(segments, {
            mode = mode,
            level = segmentLevel,
            startValue = startValue,
            stopValue = stopValue,
            maxValue = maxValue,
            wraps = stopValue >= maxValue and remainingGain > delta,
        })

        remainingGain = remainingGain - delta
        if remainingGain > 0 then
            segmentLevel = segmentLevel + 1
            maxValue = GetLevelSize(mode, segmentLevel) or maxValue
            startValue = 0
        end
    end

    return segments
end

function ExperienceTracker:QueueSegments(segments, gainAmount, mode)
    if not segments or #segments == 0 then
        return
    end

    -- Continue from the painted position when another gain arrives on the same
    -- rank. Copy the first segment so the event's original data stays intact.
    local active = self.animation and self.animation.type == "segment" and self.animation.segment
    local first = segments[1]
    if active and active.mode == first.mode and active.level == first.level
        and active.maxValue == first.maxValue and first.stopValue >= active.stopValue then
        local replacement = {}
        for key, value in pairs(first) do replacement[key] = value end
        replacement.startValue = zo_clamp(self.displayValue or active.startValue, 0, first.stopValue)
        local queue = { replacement }
        for index = 2, #segments do queue[index] = segments[index] end
        segments = queue
        gainAmount = (gainAmount or 0) + (self.totalGainAmount or 0)
    end
    self.segmentQueue = segments
    self.totalGainAmount = gainAmount
    self.totalGainMode = mode
    self:ShowRoot()
    self:StartNextSegment()
end

function ExperienceTracker:ComputeChunkCount(segment)
    local maxValue = math.max(tonumber(segment.maxValue) or 1, 1)
    local delta = math.max((tonumber(segment.stopValue) or 0) - (tonumber(segment.startValue) or 0), 1)
    local ratio = zo_clamp(delta / maxValue, 0.04, 1)
    return ClampNumber(math.floor(2 + ratio * 12), MIN_CHUNKS, MAX_CHUNKS)
end

function ExperienceTracker:TriggerChunkPulse(segment, chunkIndex, chunkCount)
    local root = self:GetRoot()
    local sound = GetChunkSound()
    if sound then PlaySound(sound) end
    if GetIntensity() <= 0 then return end
    self.tickImpactMS = GetFrameTimeMilliseconds()
    local pulses = root.chunkPulses
    if not pulses or #pulses == 0 then
        return
    end

    self.nextChunkPulseIndex = (self.nextChunkPulseIndex or 0) + 1
    if self.nextChunkPulseIndex > #pulses then
        self.nextChunkPulseIndex = 1
    end

    local pulse = pulses[self.nextChunkPulseIndex]
    local trackWidth = root.track:GetWidth()
    local x = zo_clamp((self.displayValue or segment.startValue) / math.max(segment.maxValue, 1), 0, 1) * trackWidth

    pulse.activeMS = GetFrameTimeMilliseconds()
    pulse.baseX = x
    pulse.drift = self.nextChunkPulseIndex % 2 == 0 and -1 or 1
    pulse:SetDimensions(3, 3)
    pulse:ClearAnchors()
    pulse:SetAnchor(CENTER, root.track, LEFT, x, 0)
    pulse:SetAlpha(zo_clamp(0.48 + 0.16 * GetIntensity(), 0, 0.72))
    pulse:SetHidden(false)
end

function ExperienceTracker:UpdateChunkPulses(nowMS)
    local root = self:GetRoot()
    if not root.chunkPulses then
        return
    end

    for _, pulse in ipairs(root.chunkPulses) do
        if pulse.activeMS then
            local progress = zo_clamp((nowMS - pulse.activeMS) / CHUNK_PULSE_MS, 0, 1)
            if progress >= 1 then
                pulse.activeMS = nil
                pulse:SetAlpha(0)
                pulse:SetHidden(true)
            else
                local alpha = zo_clamp((1 - progress) ^ 2 * 0.75 * GetIntensity(), 0, 0.85)
                local size = 3 - progress * 2
                pulse:SetDimensions(size, size)
                pulse:ClearAnchors()
                local x = zo_clamp((pulse.baseX or 0) - progress * 8, size / 2, root.track:GetWidth() - size / 2)
                pulse:SetAnchor(CENTER, root.track, LEFT, x, (pulse.drift or -1) * progress * 5)
                pulse:SetAlpha(alpha)
            end
        end
    end
end

function ExperienceTracker:TriggerLevelUpTicks()
    local root = self:GetRoot()
    local pulses = root.chunkPulses
    if not pulses or #pulses == 0 then
        return
    end

    local intensity = GetIntensity() * GetLevelUpIntensity()
    if intensity <= 0 then
        return
    end

    local trackWidth = root.track:GetWidth()
    local pulseCount = math.min(3, #pulses)
    for index = 1, pulseCount do
        self.nextChunkPulseIndex = (self.nextChunkPulseIndex or 0) + 1
        if self.nextChunkPulseIndex > #pulses then
            self.nextChunkPulseIndex = 1
        end

        local pulse = pulses[self.nextChunkPulseIndex]
        pulse.activeMS = GetFrameTimeMilliseconds()
        pulse.baseX = trackWidth * (0.04 + index * 0.07)
        pulse.drift = index % 2 == 0 and -1 or 1
        pulse:SetDimensions(3, 3)
        pulse:ClearAnchors()
        pulse:SetAnchor(CENTER, root.track, LEFT, pulse.baseX, 0)
        pulse:SetAlpha(1)
        pulse:SetHidden(false)
    end
end

function ExperienceTracker:StartNextSegment()
    local segment = self.segmentQueue and table.remove(self.segmentQueue, 1)
    if not segment then
        self:BeginHoldAndFade()
        return
    end

    local root = self:GetRoot()
    self:ResetTransientEffects()
    self:SetVisualMode(segment.mode, segment.level)
    self:SetBarValue(segment.startValue, segment.maxValue)
    self:RefreshEnlightened(segment.mode, segment.level, segment.startValue, segment.maxValue)

    local gainLabelText = self.totalGainMode == "cp"
        and string.format("+%s CP XP", FormatGainNumber(self.totalGainAmount or 0))
        or string.format("+%s XP", FormatGainNumber(self.totalGainAmount or 0))

    self:SetGainHeader(gainLabelText)

    root.bulk:SetHidden(false)
    self:ConfigureGainOverlay(segment)
    root.shine:SetHidden(false)
    root.impactFlash:SetAlpha(0)
    root.levelBurst:SetHidden(true)
    root.levelBurst:SetAlpha(0)

    local chunkCount = self:ComputeChunkCount(segment)

    self.animation =
    {
        type = "segment",
        segment = segment,
        chunkCount = chunkCount,
        lastChunkIndex = 0,
        startMS = GetFrameTimeMilliseconds(),
        startAlpha = root:GetAlpha(),
        durationMS = math.floor(SEGMENT_DURATION_MS * zo_lerp(0.55, 1.15,
            math.sqrt(zo_clamp((segment.stopValue - segment.startValue) / math.max(segment.maxValue, 1), 0, 1)))),
    }

    root:SetHandler("OnUpdate", function()
        self:OnUpdate()
    end)
end

function ExperienceTracker:BeginHoldAndFade()
    local root = self:GetRoot()
    self.animation =
    {
        type = "hold",
        startMS = GetFrameTimeMilliseconds(),
        durationMS = math.max(GetVisibleDurationMS() - FADE_IN_MS - FADE_OUT_MS, 300),
    }
    root:SetHandler("OnUpdate", function()
        self:OnUpdate()
    end)
end

function ExperienceTracker:BeginLevelUpBurst(segment)
    local root = self:GetRoot()
    self:ResetTransientEffects()
    self:PrepareRankReveal(segment)
    self:ConfigureGainOverlay(segment)
    root.bulk:SetHidden(false)
    if segment and segment.maxValue then
        root.bulk:SetValue(math.max((segment.stopValue or segment.maxValue) - (segment.startValue or 0), 1))
        root.bar:SetValue(segment.maxValue)
        root.gloss:SetValue(segment.maxValue)
        self:UpdateProgress(segment.maxValue, segment.maxValue)
    end

    root.enlightened:SetHidden(true)
    root.tickFlash:SetMinMax(0, 1)
    root.tickFlash:SetValue(1)
    root.tickFlash:SetHidden(false)
    local rankDelta = tonumber(self.rankReveal.newText) - tonumber(self.rankReveal.oldText)
    local milestoneText = segment.mode == "cp"
        and string.format("CHAMPION +%s", FormatNumber(rankDelta)) or "LEVEL UP"

    self.animation =
    {
        type = "levelUpBurst",
        startMS = GetFrameTimeMilliseconds(),
        durationMS = LEVEL_UP_BURST_DURATION_MS,
        segment = segment,
        milestoneText = milestoneText,
        impactPlayed = false,
    }
    root:SetHandler("OnUpdate", function()
        self:OnUpdate()
    end)
end

function ExperienceTracker:SettleToCurrent()
    local root = self:GetRoot()
    self:ResetTickImpact()
    root:SetHandler("OnUpdate", nil)
    root.glow:SetAlpha(0)
    root.impactFlash:SetAlpha(0)
    root.badgeGlow:SetAlpha(0.22)
    root.topRail:SetAlpha(0.72)
    root.bottomRail:SetAlpha(0.60)
    root.badge:SetScale(1)
    root.levelLabel:SetScale(1)
    root.levelLabel:SetAlpha(1)
    root.nextLevelLabel:SetAlpha(0)
    root.nextLevelLabel:SetScale(1)
    root.nextLevelLabel:SetHidden(true)
    root.bulk:SetAlpha(0)
    root.bulk:SetHidden(true)
    root.shine:SetAlpha(0)
    root.shine:SetHidden(true)
    root.rewardShine:SetAlpha(0)
    root.rewardShine:SetHidden(true)
    root.levelBurst:SetAlpha(0)
    root.levelBurst:SetScale(1)
    root.levelBurst:SetHidden(true)
    root.badgeBurst:SetAlpha(0)
    root.badgeBurst:SetScale(1)
    root.badgeBurst:SetHidden(true)
    self:RestoreHeader()
    self.rankReveal = nil
    self.animation = nil
    self:UpdateVisibility()
end

function ExperienceTracker:OnUpdate()
    local animation = self.animation
    if not animation then
        return
    end

    local root = self:GetRoot()
    local nowMS = GetFrameTimeMilliseconds()
    local progress = zo_clamp((nowMS - animation.startMS) / animation.durationMS, 0, 1)
    local alpha = GetAlpha()
    self:UpdateChunkPulses(nowMS)

    if animation.type == "segment" then
        local segment = animation.segment
        local chunkCount = animation.chunkCount or MIN_CHUNKS
        -- Each packet surges forward, then rests briefly before the next tick.
        -- There is no overshoot: values remain monotonic across the joins.
        local packet = progress * chunkCount
        local packetIndex = math.min(math.floor(packet), chunkCount - 1)
        local packetProgress = zo_clamp((packet - packetIndex) / 0.78, 0, 1)
        local eased = (packetIndex + EaseOutCubic(packetProgress)) / chunkCount
        local chunkIndex = math.min(math.floor(packet + 0.82), chunkCount)
        local value = zo_lerp(segment.startValue, segment.stopValue, eased)
        local envelope = math.sin(progress * math.pi)
        local glowAlpha = zo_clamp(envelope * 0.18 * GetIntensity(), 0, 0.25)
        local bulkAlpha = zo_clamp((0.12 + envelope * 0.30) * GetIntensity(), 0, 0.55)
        local filledWidth = root.track:GetWidth() * value / math.max(segment.maxValue, 1)
        local shineWidth = math.min(32, filledWidth)
        local headerElapsed = nowMS - animation.startMS
        local gainAlpha = ShouldShowGainText() and EaseOutCubic(zo_clamp((headerElapsed - 70) / 110, 0, 1)) or 0

        self:UpdateProgress(value, segment.maxValue)
        if chunkIndex > (animation.lastChunkIndex or 0) and chunkIndex <= chunkCount then
            -- A delayed frame must not play several sounds simultaneously.
            self:TriggerChunkPulse(segment, chunkIndex, chunkCount)
            animation.lastChunkIndex = chunkIndex
            animation.lastPulseMS = nowMS
        end

        root:SetAlpha(zo_lerp(animation.startAlpha or 0, alpha,
            EaseOutCubic(zo_clamp((nowMS - animation.startMS) / FADE_IN_MS, 0, 1))))
        root.glow:SetAlpha(glowAlpha)
        root.badgeGlow:SetAlpha(zo_clamp(0.22 + glowAlpha * 0.5, 0.22, 0.42))
        local impact = animation.lastPulseMS and math.max(0, 1 - (nowMS - animation.lastPulseMS) / 180) or 0
        root.impactFlash:SetAlpha(impact * 0.07 * GetIntensity())
        root.bulk:SetAlpha(bulkAlpha)
        root.bulk:SetValue(math.max(value - segment.startValue, 0))
        root.bar:SetValue(value)
        root.gloss:SetValue(value)
        root.typeLabel:SetAlpha(ShouldShowGainText() and (1 - zo_clamp(headerElapsed / 70, 0, 1)) or 1)
        root.gainLabel:SetAlpha(gainAlpha)
        root.gainLabel:SetScale(1)
        root.shine:ClearAnchors()
        root.shine:SetDimensions(shineWidth, root.track:GetHeight())
        root.shine:SetAnchor(LEFT, root.track, LEFT, filledWidth - shineWidth, 0)
        root.shine:SetAlpha(zo_clamp(envelope * 0.42 * GetIntensity(), 0, 0.60))

        if progress >= 1 then
            if segment.wraps then
                if ShouldPlayLevelUpAnimation() then
                    self:BeginLevelUpBurst(segment)
                else
                    PlayLevelUpSound()
                    self:StartNextSegment()
                end
            else
                self:StartNextSegment()
            end
        end
    elseif animation.type == "levelUpBurst" then
        local intensity = GetIntensity() * GetLevelUpIntensity()
        local charge = zo_clamp(progress / LEVEL_REVEAL_POINT, 0, 1)
        local released = progress >= LEVEL_REVEAL_POINT
        local release = zo_clamp((progress - LEVEL_REVEAL_POINT) / (1 - LEVEL_REVEAL_POINT), 0, 1)
        local impact = released and (1 - zo_clamp(release / 0.24, 0, 1)) ^ 2 or 0
        local settle = 1 - EaseOutCubic(release)
        local trackWidth = root.track:GetWidth()
        local trackHeight = root.track:GetHeight()

        -- First pull the light into the badge; the sound belongs to the reveal,
        -- not the start of the charge. A skipped frame still fires it once.
        if released and not animation.impactPlayed then
            animation.impactPlayed = true
            PlayLevelUpSound()
            self:TriggerLevelUpTicks()
            root.gainLabel:SetText(animation.milestoneText)
        end

        if self.rankReveal and not self.rankReveal.committed then
            if intensity <= 0 then
                if released then self:CommitRankReveal() end
            elseif not released then
                root.levelLabel:SetScale(1 - charge * 0.09)
                root.levelLabel:SetAlpha(1 - charge * 0.45)
                root.nextLevelLabel:SetAlpha(0)
            else
                local reveal = zo_clamp(release / 0.48, 0, 1)
                root.levelLabel:SetAlpha(0)
                self:AnchorRankLabel(root.nextLevelLabel, 5 * (1 - EaseOutCubic(reveal)))
                root.nextLevelLabel:SetAlpha(EaseOutCubic(zo_clamp(release / 0.10, 0, 1)))
                root.nextLevelLabel:SetScale(1 + 0.24 * math.exp(-5 * reveal) * math.cos(9 * reveal) * math.min(intensity, 1.4))
                if reveal >= 1 then self:CommitRankReveal() end
            end
        end

        root:SetAlpha(alpha)
        self:SetFillHeight(trackHeight + math.min(4, (released and impact * 4 or charge * 2) * intensity))
        root.tickFlash:SetAlpha(zo_clamp((released and (impact * 0.9 + settle * 0.14) or charge * 0.55) * intensity, 0, 1))
        root.glow:SetAlpha(zo_clamp((released and (impact * 0.75 + settle * 0.22) or charge * 0.40) * intensity, 0, 1))
        root.badgeGlow:SetAlpha(zo_clamp(0.22 + (released and (impact * 0.60 + settle * 0.30) or charge * 0.25) * intensity, 0.22, 1))
        root.impactFlash:SetAlpha(zo_clamp(impact * 0.65 * intensity, 0, 0.9))
        root.bulk:SetAlpha(0)
        root.badge:SetScale(1)
        root.typeLabel:SetAlpha(ShouldShowGainText() and 0 or 1)
        root.gainLabel:SetAlpha(ShouldShowGainText() and 1 or 0)
        root.gainLabel:SetScale(1)
        root.shine:SetAlpha(0)

        local sweepWidth = math.min(48, trackWidth)
        local sweepPosition = released and EaseOutCubic(zo_clamp(release / 0.68, 0, 1)) or (1 - charge * charge)
        root.rewardShine:SetHidden(false)
        root.rewardShine:ClearAnchors()
        root.rewardShine:SetDimensions(sweepWidth, trackHeight)
        root.rewardShine:SetAnchor(LEFT, root.track, LEFT, (trackWidth - sweepWidth) * sweepPosition, 0)
        root.rewardShine:SetAlpha(zo_clamp((released and settle * 0.85 or charge * 0.70) * intensity, 0, 1))

        -- Release a narrow horizontal streak, keeping the frame itself still.
        root.levelBurst:SetHidden(false)
        root.levelBurst:ClearAnchors()
        root.levelBurst:SetDimensions(math.max(1, trackWidth * EaseOutCubic(release)), 2)
        root.levelBurst:SetAnchor(LEFT, root.track, LEFT, 0, 0)
        root.levelBurst:SetScale(1)
        root.levelBurst:SetAlpha(zo_clamp((released and settle * 0.65 or 0) * intensity, 0, 0.9))
        root.badgeBurst:SetHidden(false)
        root.badgeBurst:ClearAnchors()
        root.badgeBurst:SetDimensions(math.max(1, (root.badge:GetWidth() - 12) * EaseOutCubic(zo_clamp(release / 0.3, 0, 1))), 2)
        root.badgeBurst:SetAnchor(BOTTOM, root.badge, BOTTOM, 0, -2)
        root.badgeBurst:SetScale(1)
        root.badgeBurst:SetAlpha(zo_clamp((released and settle or 0) * intensity, 0, 1))

        if progress >= 1 then
            self:CommitRankReveal()
            local newLevel = tonumber(self.currentLevelText)
            self:ResetTransientEffects()
            if self.segmentQueue and #self.segmentQueue > 0 then
                self:StartNextSegment()
            else
                self:SetVisualMode(animation.segment.mode, newLevel)
                local maximum = GetLevelSize(animation.segment.mode, newLevel) or 1
                local current = animation.segment.newLevel and animation.segment.mode == "cp" and GetPlayerChampionXP() or 0
                self:SetBarValue(current, maximum)
                self:RefreshEnlightened(animation.segment.mode, newLevel, current, maximum)
                self:SetGainHeader(animation.milestoneText)
                root.gainLabel:SetAlpha(ShouldShowGainText() and 1 or 0)
                root.typeLabel:SetAlpha(ShouldShowGainText() and 0 or 1)
                self:BeginHoldAndFade()
            end
        end
    elseif animation.type == "hold" then
        local headerElapsed = nowMS - animation.startMS
        local gainFade = 1 - zo_clamp((headerElapsed - 450) / 120, 0, 1)
        local restoreProgress = EaseOutCubic(zo_clamp((headerElapsed - 570) / 180, 0, 1))
        root:SetAlpha(alpha)
        root.glow:SetAlpha(zo_clamp((1 - progress) * 0.08 * GetIntensity(), 0, 0.10))
        root.badgeGlow:SetAlpha(zo_clamp(0.22 + (1 - progress) * 0.08 * GetIntensity(), 0.22, 0.34))
        root.impactFlash:SetAlpha(0)
        root.bulk:SetAlpha(0)
        root.shine:SetAlpha(0)
        root.typeLabel:SetAlpha(ShouldShowGainText() and restoreProgress or 1)
        root.gainLabel:SetAlpha(ShouldShowGainText() and gainFade or 0)
        if progress >= 1 then
            self:RestoreHeader()
            if IsAlwaysVisible() then
                self:SettleToCurrent()
            else
                self.animation = {
                    type = "fadeOut",
                    startMS = nowMS,
                    durationMS = FADE_OUT_MS,
                }
            end
        end
    elseif animation.type == "fadeOut" then
        root:SetAlpha(alpha * (1 - progress * progress * (3 - 2 * progress)))
        root.glow:SetAlpha(0)
        root.gainLabel:SetAlpha(0)
        root.typeLabel:SetAlpha(1)
        if progress >= 1 then
            self:HideRoot()
            self:UpdateVisibility()
        end
    end
    if self.animation and self.animation.type ~= "levelUpBurst" then
        self:UpdateTickImpact(nowMS)
    end
end

function ExperienceTracker:ShowExperienceGain(mode, level, previousXP, currentXP, championPoints, forceShow)
    if not IsModuleEnabled() then
        return
    end

    local maxValue
    if mode == "cp" then
        level = championPoints or level or GetPlayerChampionPointsEarned()
        maxValue = GetNumChampionXPInChampionPoint(level)
    else
        level = level or GetUnitLevel("player")
        maxValue = GetNumExperiencePointsInLevel(level)
    end

    if not maxValue or maxValue <= 0 or not previousXP or not currentXP or currentXP <= previousXP then
        return
    end

    if not forceShow then
        -- Some rewards report the same XP interval through multiple events.
        -- Compare the interval instead of throttling distinct rapid gains.
        local nowMS = GetFrameTimeMilliseconds()
        local recentGains = self.recentGains or {}
        self.recentGains = recentGains
        for index = #recentGains, 1, -1 do
            local gain = recentGains[index]
            if nowMS - gain.timeMS >= GAIN_DEDUPLICATION_MS then
                table.remove(recentGains, index)
            elseif gain.mode == mode and gain.level == level
                and gain.previousXP == previousXP and gain.currentXP == currentXP then
                return
            end
        end
        table.insert(recentGains, {
            timeMS = nowMS, mode = mode, level = level,
            previousXP = previousXP, currentXP = currentXP,
        })
    end

    local segments = self:BuildSegments(mode, level, previousXP, currentXP, maxValue)
    if not forceShow and not IsHudSceneShowing() then
        -- Quest turn-ins can award XP before the interaction closes. Keep the
        -- full animation until the HUD returns, including level-up segments.
        self.pendingSegments = self.pendingSegments or {}
        for _, segment in ipairs(segments) do
            table.insert(self.pendingSegments, segment)
        end
        self.pendingGainAmount = (self.pendingGainAmount or 0) + currentXP - previousXP
        self.pendingGainMode = mode
        return
    end
    self:QueueSegments(segments, currentXP - previousXP, mode)
end

function ExperienceTracker:OnExperienceGain(reason, level, previousExperience, currentExperience, championPoints)
    local mode = "xp"
    if CanUnitGainChampionPoints("player") and GetNumChampionXPInChampionPoint(championPoints) ~= nil then
        mode = "cp"
    end
    self:ShowExperienceGain(mode, level, previousExperience, currentExperience, championPoints, false)
end

function ExperienceTracker:OnDiscoveryExperience(_areaName, level, previousExperience, currentExperience, championPoints)
    self:OnExperienceGain(nil, level, previousExperience, currentExperience, championPoints)
end

function ExperienceTracker:OnQuestComplete(_questName, level, previousExperience, currentExperience, championPoints)
    self:OnExperienceGain(nil, level, previousExperience, currentExperience, championPoints)
end

function ExperienceTracker:OnObjectiveCompleted(_zoneIndex, _poiIndex, level, previousExperience, currentExperience, championPoints)
    self:OnExperienceGain(nil, level, previousExperience, currentExperience, championPoints)
end

function ExperienceTracker:OnExperienceUpdate(unitTag, currentExp, maxExp)
    if unitTag ~= "player" or not IsModuleEnabled() then
        return
    end
    self.lastKnownXP = currentExp
    self.lastKnownXPMax = maxExp
    if IsAlwaysVisible() and not self.animation then
        self:UpdateVisibility()
    end
end

function ExperienceTracker:OnChampionPointGained(pointDelta)
    if not IsModuleEnabled() or not IsHudSceneShowing() or (tonumber(pointDelta) or 0) <= 0 then
        return
    end

    local endingPoints = GetPlayerChampionPointsEarned()
    if not self.animation then
        self:PreviewCPFlash(endingPoints, pointDelta)
    end
end

function ExperienceTracker:PreviewCPFlash(level, pointDelta)
    local root = self:GetRoot()
    local endingLevel = tonumber(level) or GetPlayerChampionPointsEarned()
    local delta = math.max(tonumber(pointDelta) or 1, 1)
    local startingLevel = math.max(endingLevel - delta, 0)
    local gainText = delta == 1
        and "+1 Champion Point"
        or string.format("+%s Champion Points", FormatNumber(delta))

    self:ShowRoot()
    self:SetVisualMode("cp", startingLevel)
    self:SetBarValue(1, 1)
    self:SetGainHeader(gainText)
    root.gainLabel:SetAlpha(ShouldShowGainText() and 1 or 0)
    root.typeLabel:SetAlpha(ShouldShowGainText() and 0 or 1)
    if not ShouldPlayLevelUpAnimation() then
        PlayLevelUpSound()
        self:SetVisualMode("cp", endingLevel)
        self:SetGainHeader(gainText)
        root.gainLabel:SetAlpha(ShouldShowGainText() and 1 or 0)
        root.typeLabel:SetAlpha(ShouldShowGainText() and 0 or 1)
        self.animation =
        {
            type = "hold",
            startMS = GetFrameTimeMilliseconds(),
            durationMS = math.max(GetVisibleDurationMS() - FADE_OUT_MS, 600),
        }
        root:SetHandler("OnUpdate", function()
            self:OnUpdate()
        end)
        return
    end

    self:BeginLevelUpBurst({
        mode = "cp",
        level = startingLevel,
        oldLevel = startingLevel,
        newLevel = endingLevel,
        startValue = 0,
        stopValue = 1,
        maxValue = 1,
    })
end

function ExperienceTracker:GetCurrentSnapshot()
    if CanUnitGainChampionPoints("player") then
        local level = GetPlayerChampionPointsEarned()
        local current = GetPlayerChampionXP()
        local maxValue = GetNumChampionXPInChampionPoint(level)
        if maxValue then
            return "cp", level, current, maxValue
        end
    end

    local level = GetUnitLevel("player")
    local current = GetUnitXP("player")
    local maxValue = GetNumExperiencePointsInLevel(level) or GetUnitXPMax("player")
    return "xp", level, current, maxValue
end

function ExperienceTracker:PreviewGain()
    local mode, level, current, maxValue = self:GetCurrentSnapshot()
    maxValue = math.max(tonumber(maxValue) or 1, 1)
    local previous = zo_clamp(current or math.floor(maxValue * 0.28), 0, maxValue - 1)
    local gain = math.max(math.floor(maxValue * 0.18), 1)
    local currentPreview = previous + gain
    self:ShowExperienceGain(mode, level, previous, currentPreview, mode == "cp" and level or nil, true)
end

function ExperienceTracker:PreviewBigGain()
    local mode, level, current, maxValue = self:GetCurrentSnapshot()
    maxValue = math.max(tonumber(maxValue) or 1, 1)
    local previous = math.floor(maxValue * 0.78)
    local currentPreview = previous + math.floor(maxValue * 0.62)
    self:ShowExperienceGain(mode, level, previous, currentPreview, mode == "cp" and level or nil, true)
end

function ExperienceTracker:PreviewCPGain()
    local level = GetPlayerChampionPointsEarned and GetPlayerChampionPointsEarned() or 120
    local maxValue = GetNumChampionXPInChampionPoint(level) or 400000
    local previous = math.floor(maxValue * 0.36)
    local current = previous + math.floor(maxValue * 0.22)
    self:ShowExperienceGain("cp", level, previous, current, level, true)
end

function ExperienceTracker:PreviewChunkSound()
    local sound = GetChunkSound()
    if sound then
        PlaySound(sound)
    end
end

function ExperienceTracker:PreviewLevelUpSound()
    local sound = GetLevelUpSound()
    if sound then
        PlaySound(sound)
    end
end

function ExperienceTracker:UpdateVisibility()
    if not IsModuleEnabled() then
        self.pendingSegments = nil
        self.pendingGainAmount = nil
        self.pendingGainMode = nil
        self:HideRoot()
        self:GetMover():SetHidden(true)
        return
    end

    self:ApplyLayout()
    if IsHudSceneShowing() and self.pendingSegments then
        local segments, gainAmount, mode = self.pendingSegments, self.pendingGainAmount, self.pendingGainMode
        self.pendingSegments = nil
        self.pendingGainAmount = nil
        self.pendingGainMode = nil
        self:QueueSegments(segments, gainAmount, mode)
        return
    end
    if IsModuleUnlocked() or (IsAlwaysVisible() and IsHudSceneShowing()) then
        local mode, level, current, maxValue = self:GetCurrentSnapshot()
        self:SetVisualMode(mode, level)
        self:SetBarValue(current or 0, maxValue or 1)
        self:RefreshEnlightened(mode, level, current or 0, maxValue or 1)
        self:GetRoot():SetAlpha(GetAlpha())
        self:GetRoot():SetHidden(false)
    elseif IsAlwaysVisible() and not IsHudSceneShowing() and not self.animation then
        self:GetRoot():SetHidden(true)
    elseif not self.animation then
        self:GetRoot():SetHidden(true)
    end
end

function ExperienceTracker:CanSuppressStockProgressBar()
    return ShouldHideStockProgressBar() and IsHudSceneShowing()
end

function ExperienceTracker:HideStockProgressBar()
    if ZO_PlayerProgress and self:CanSuppressStockProgressBar() then
        ZO_PlayerProgress:SetHidden(true)
        ZO_PlayerProgress:SetAlpha(0)
    end
end

function ExperienceTracker:CallPlayerProgressOriginal(originalMethod, progressBar, ...)
    local result1, result2, result3 = originalMethod(progressBar, ...)
    if self:CanSuppressStockProgressBar() then
        self:HideStockProgressBar()
    end
    return result1, result2, result3
end

function ExperienceTracker:InstallStockHooks()
    if self.stockHooksInstalled then
        return true
    end
    if not PLAYER_PROGRESS_BAR then
        return false
    end

    self.originalPlayerProgressShow = PLAYER_PROGRESS_BAR.Show
    self.originalPlayerProgressShowIncrease = PLAYER_PROGRESS_BAR.ShowIncrease
    self.originalPlayerProgressShowCurrent = PLAYER_PROGRESS_BAR.ShowCurrent
    self.originalPlayerProgressRefreshCurrentBar = PLAYER_PROGRESS_BAR.RefreshCurrentBar

    PLAYER_PROGRESS_BAR.Show = function(progressBar, ...)
        return ExperienceTracker:CallPlayerProgressOriginal(ExperienceTracker.originalPlayerProgressShow, progressBar, ...)
    end

    PLAYER_PROGRESS_BAR.ShowIncrease = function(progressBar, ...)
        return ExperienceTracker:CallPlayerProgressOriginal(ExperienceTracker.originalPlayerProgressShowIncrease, progressBar, ...)
    end

    PLAYER_PROGRESS_BAR.ShowCurrent = function(progressBar, ...)
        return ExperienceTracker:CallPlayerProgressOriginal(ExperienceTracker.originalPlayerProgressShowCurrent, progressBar, ...)
    end

    PLAYER_PROGRESS_BAR.RefreshCurrentBar = function(progressBar, ...)
        return ExperienceTracker:CallPlayerProgressOriginal(ExperienceTracker.originalPlayerProgressRefreshCurrentBar, progressBar, ...)
    end

    self.stockHooksInstalled = true
    return true
end

function ExperienceTracker:StartStockHookWhenReady()
    if self:InstallStockHooks() then
        return
    end

    local attempts = 0
    EVENT_MANAGER:RegisterForUpdate(EVENT_NAMESPACE .. "_StockHook", STOCK_HOOK_RETRY_MS, function()
        attempts = attempts + 1
        if self:InstallStockHooks() or attempts >= MAX_STOCK_HOOK_ATTEMPTS then
            EVENT_MANAGER:UnregisterForUpdate(EVENT_NAMESPACE .. "_StockHook")
        end
    end)
end

function ExperienceTracker:RegisterEvents()
    if self.eventsRegistered then
        return
    end

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_EXPERIENCE_GAIN, function(_, ...)
        self:OnExperienceGain(...)
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Discovery", EVENT_DISCOVERY_EXPERIENCE, function(_, ...)
        self:OnDiscoveryExperience(...)
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Quest", EVENT_QUEST_COMPLETE, function(_, ...)
        self:OnQuestComplete(...)
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Objective", EVENT_OBJECTIVE_COMPLETED, function(_, ...)
        self:OnObjectiveCompleted(...)
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Update", EVENT_EXPERIENCE_UPDATE, function(_, ...)
        self:OnExperienceUpdate(...)
    end)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE .. "_Update", EVENT_EXPERIENCE_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_CPGained", EVENT_CHAMPION_POINT_GAINED, function(_, ...)
        self:OnChampionPointGained(...)
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
        self:RefreshSettings()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_ScreenResized", EVENT_SCREEN_RESIZED, function()
        self:ApplyLayout()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Gamepad", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        self:ApplyLayout()
    end)

    if HUD_SCENE then
        HUD_SCENE:RegisterCallback("StateChange", function()
            self:HideStockProgressBar()
            self:UpdateVisibility()
        end)
    end

    if HUD_UI_SCENE then
        HUD_UI_SCENE:RegisterCallback("StateChange", function()
            self:HideStockProgressBar()
            self:UpdateVisibility()
        end)
    end

    self.eventsRegistered = true
end

function ExperienceTracker:RefreshSettings()
    self:GetRoot()
    self:GetMover()
    self:ApplyLayout()
    self:StartStockHookWhenReady()
    self:HideStockProgressBar()
    self:UpdateVisibility()
end

local DEBUG_COMMANDS =
{
    ["/nsxp"] = function()
        ExperienceTracker:PreviewGain()
    end,
    ["/nsxpbig"] = function()
        ExperienceTracker:PreviewBigGain()
    end,
    ["/nsxpcp"] = function()
        ExperienceTracker:PreviewCPGain()
    end,
}

local function IsDebugModeEnabled()
    return Nirnsteel_UI.Settings and Nirnsteel_UI.Settings:IsDebugModeEnabled()
end

local function RegisterDebugCommands()
    for command, handler in pairs(DEBUG_COMMANDS) do
        SLASH_COMMANDS[command] = IsDebugModeEnabled() and handler or nil
    end
end

function ExperienceTracker:RefreshDebugCommands()
    RegisterDebugCommands()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED)
    ExperienceTracker:RegisterEvents()
    ExperienceTracker:RefreshSettings()
    RegisterDebugCommands()
    zo_callLater(function() ExperienceTracker:RefreshSettings() end, 1000)
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
