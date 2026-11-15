NQOL = NQOL or {}
NQOL.Features = NQOL.Features or {}

local ProgressDungeons = {}

local EVENT_NAMESPACE = "NQOL_ProgressDungeons"
local ASYNC_BUILD_BATCH_SIZE = 2
local DRAW_LEVEL = 215
local FONT_SIZE_MIN = 10
local FONT_SIZE_MAX = 32
local DEFAULT_FONT_SIZE = FONT_SIZE_MIN + math.floor((FONT_SIZE_MAX - FONT_SIZE_MIN) * 0.5 + 0.5)
local BACKGROUND_OPACITY_MIN = 0
local BACKGROUND_OPACITY_MAX = 100
local HUD_PADDING = 12
local HEADER_HEIGHT_OFFSET = 5
local FOOTER_HEIGHT_OFFSET = -5
local FOOTER_TOP_GAP = 10
local FOOTER_DIVIDER_HEIGHT = 1
local FOOTER_DIVIDER_TEXT_GAP = 5
local FOOTER_LINE_GAP = 2
local FOOTER_COUNTER_SEPARATOR = "   "
local ROW_GAP = 2
local COLUMN_GAP = 18
local SCREEN_MARGIN = 24
local BASIC_COLUMN_WIDTH = 560
local ADVANCED_COLUMN_WIDTH = 1080
local FULL_COLUMN_WIDTH = 1980
local HUD_MAX_WIDTH = 2300
local STATUS_ICON_SIZE = 18
local STATUS_TEXT_WIDTH = 58
local ACHIEVEMENT_LABEL_WIDTH = 34
local EXTRA_BULLET_SIZE = 10
local EXTRA_BULLET_GAP = 6
local SCROLL_DEADZONE = 0.18
local SCROLL_SPEED = 680
local FULL_SCROLL_SPEED_MULTIPLIER = 2.5
local BASIC_WIDTH_SCALE = 1.1
local DLC_WIDTH_SCALE = 1.2
local FULL_HEIGHT_SCALE = 0.8
local FULL_DUNGEON_GAP_ROWS = 1
local FULL_ROW_CONTENT_INSET_X = 12
local FULL_ROW_CONTENT_INSET_Y = 12
local WATERMARK_ALPHA = 0.05
local CHECKMARK_TEXTURE = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_equipped.dds"
local CROSS_TEXTURE = "EsoUI/Art/Buttons/decline_up.dds"
local BULLET_TEXTURE = "EsoUI/Art/Miscellaneous/Gamepad/gp_bullet.dds"

local GROUP_BASE = "base"
local GROUP_DLC = "dlc"
local DETAIL_BASIC = "basic"
local DETAIL_ADVANCED = "advanced"
local DETAIL_FULL = "full"

local DETAIL_LEVELS = {
    { key = DETAIL_BASIC, name = NQOL.L("common.detail.basic") },
    { key = DETAIL_ADVANCED, name = NQOL.L("common.detail.dates") },
    { key = DETAIL_FULL, name = NQOL.L("common.detail.full") },
}
NQOL.Lexicon.RegisterTableField(DETAIL_LEVELS, "name", { "common.detail.basic", "common.detail.dates", "common.detail.full" })

local TRACKED_TYPES = {
    { key = "normal", label = NQOL.L("features.progress_dungeons.n_b51a607"), longLabel = NQOL.L("common.normal") },
    { key = "vet", label = NQOL.L("features.progress_dungeons.v_c9ee568"), longLabel = NQOL.L("common.veteran") },
    { key = "hm", label = NQOL.L("features.progress_dungeons.hm_0bdcc8f"), longLabel = NQOL.L("common.hard_mode") },
    { key = "hm1", label = NQOL.L("features.progress_dungeons.hm1_b2c1378"), longLabel = NQOL.L("common.hard_mode_number", 1) },
    { key = "hm2", label = NQOL.L("features.progress_dungeons.hm2_ce5b4ae"), longLabel = NQOL.L("common.hard_mode_number", 2) },
    { key = "sr", label = NQOL.L("features.progress_dungeons.sr_cd7216b"), longLabel = NQOL.L("common.speed") },
    { key = "nd", label = NQOL.L("features.progress_dungeons.nd_aef4184"), longLabel = NQOL.L("common.no_death") },
    { key = "ch", label = NQOL.L("features.progress_dungeons.ch_b406102"), longLabel = NQOL.L("common.challenger") },
    { key = "tri", label = NQOL.L("features.progress_dungeons.tri_2435669"), longLabel = NQOL.L("common.trifecta") },
    { key = "extra", label = NQOL.L("features.progress_dungeons.extra_2613fc9"), longLabel = NQOL.L("common.extra"), aggregate = true },
}
NQOL.Lexicon.RegisterTableField(TRACKED_TYPES, "label", {
    "features.progress_dungeons.n_b51a607", "features.progress_dungeons.v_c9ee568",
    "features.progress_dungeons.hm_0bdcc8f", "features.progress_dungeons.hm1_b2c1378",
    "features.progress_dungeons.hm2_ce5b4ae", "features.progress_dungeons.sr_cd7216b",
    "features.progress_dungeons.nd_aef4184", "features.progress_dungeons.ch_b406102",
    "features.progress_dungeons.tri_2435669", "features.progress_dungeons.extra_2613fc9",
})
NQOL.Lexicon.RegisterTableField(TRACKED_TYPES, "longLabel", {
    "common.normal", "common.veteran", "common.hard_mode", { "common.hard_mode_number", 1 },
    { "common.hard_mode_number", 2 }, "common.speed", "common.no_death", "common.challenger",
    "common.trifecta", "common.extra",
})

local FULL_STATUS_CONTROL_COUNT = 0
for _, trackedType in ipairs(TRACKED_TYPES) do
    if not trackedType.aggregate then
        FULL_STATUS_CONTROL_COUNT = FULL_STATUS_CONTROL_COUNT + 1
    end
end

local defaults = {
    progress = {
        dungeons = {
            baseDetailLevel = DETAIL_BASIC,
            baseShowWatermark = false,
            baseHorizontalPosition = 25,
            baseVerticalPosition = 18,
            baseFont = NQOL.Util.GetDefaultFont(),
            baseFontSize = DEFAULT_FONT_SIZE,
            baseBackgroundOpacity = 90,
            dlcDetailLevel = DETAIL_BASIC,
            dlcShowWatermark = false,
            dlcHorizontalPosition = 70,
            dlcVerticalPosition = 18,
            dlcFont = NQOL.Util.GetDefaultFont(),
            dlcFontSize = DEFAULT_FONT_SIZE,
            dlcBackgroundOpacity = 90,
            fullScrollPositions = {
                [GROUP_BASE] = 0,
                [GROUP_DLC] = 0,
            },
        },
    },
}

local savedVariables
local initialized = false
local eventsRegistered = false
local settingsPanelGroup
local huds = {}
local dungeonRowsByDetailLevel = {}
local fontStringCache = {}
local activeFontGroupKey = GROUP_BASE
local refreshGeneration = 0
local BuildFooter
local RefreshScrollActivation
local ApplyHudPosition
local RenderFooter
local RenderWatermark
local StandardRows = {}
local RenderVisibleFullRows
local Refresh

local Clamp = NQOL.Util.Clamp
local Round = NQOL.Util.Round

local function ParseDungeonDefinitions()
    if ProgressDungeons.dungeonDefinitions then
        return ProgressDungeons.dungeonDefinitions
    end

    local function CopyAchievementList(values)
        local copied = {}
        if type(values) ~= "table" then
            return copied
        end

        for _, achievementId in ipairs(values) do
            if type(achievementId) == "number" and achievementId > 0 then
                copied[#copied + 1] = achievementId
            end
        end

        return copied
    end

    local function GetAchievementDataSection(sectionKey)
        local achievementData = NQOL.Data and NQOL.Data.DungeonAchievements
        local section = achievementData and achievementData[sectionKey]
        if type(section) ~= "table" then
            return {}
        end

        return section
    end

    local function AddDungeonDefinitions(definitions, sectionKey, groupKey)
        for zoneId, entry in pairs(GetAchievementDataSection(sectionKey)) do
            if type(entry) == "table" then
                local achievements = type(entry.achievements) == "table" and entry.achievements or {}
                local dataZoneId = tonumber(zoneId) or tonumber(entry.zoneId)
                definitions[#definitions + 1] = {
                    group = groupKey,
                    dungeonId = dataZoneId,
                    zoneId = dataZoneId,
                    sourceName = entry.name,
                    normal = achievements.normal,
                    vet = achievements.vet,
                    hm = achievements.hm,
                    hm1 = achievements.hm1,
                    hm2 = achievements.hm2,
                    sr = achievements.sr,
                    nd = achievements.nd,
                    ch = achievements.ch,
                    tri = achievements.tri,
                    extra = CopyAchievementList(achievements.extra),
                }
            end
        end
    end

    local definitions = {}
    AddDungeonDefinitions(definitions, "dungeons", GROUP_BASE)
    AddDungeonDefinitions(definitions, "dlcDungeons", GROUP_DLC)

    ProgressDungeons.dungeonDefinitions = definitions
    return definitions
end

local function GetSettings()
    local progress = NQOL.Settings.GetSection(savedVariables, defaults, "progress")
    local dungeonDefaults = defaults.progress.dungeons

    if type(progress.dungeons) ~= "table" then
        progress.dungeons = {}
    end

    local settings = progress.dungeons
    if settings.baseEnabled == nil and settings.enabled ~= nil then
        settings.baseEnabled = settings.enabled == true and settings.showBaseGame ~= false
        settings.dlcEnabled = settings.enabled == true and settings.showDlc ~= false
        settings.baseShowInSettings = settings.showInSettings
        settings.dlcShowInSettings = settings.showInSettings
        settings.baseDetailLevel = settings.detailLevel
        settings.dlcDetailLevel = settings.detailLevel
        settings.baseShowWatermark = settings.showWatermark
        settings.dlcShowWatermark = settings.showWatermark
        settings.baseFont = settings.font
        settings.dlcFont = settings.font
        settings.baseFontSize = settings.fontSize
        settings.dlcFontSize = settings.fontSize
        settings.baseBackgroundOpacity = settings.backgroundOpacity
        settings.dlcBackgroundOpacity = settings.backgroundOpacity
        settings.enabled = nil
        settings.showInSettings = nil
        settings.detailLevel = nil
        settings.showBaseGame = nil
        settings.showDlc = nil
        settings.showWatermark = nil
        settings.font = nil
        settings.fontSize = nil
        settings.backgroundOpacity = nil
    end

    settings.baseEnabled = nil
    settings.baseShowInSettings = nil
    settings.dlcEnabled = nil
    settings.dlcShowInSettings = nil
    settings.enabled = nil
    settings.showInSettings = nil
    settings.showBaseGame = nil
    settings.showDlc = nil
    NQOL.Settings.Boolean(settings, dungeonDefaults, "baseShowWatermark")
    NQOL.Settings.ClampedNumber(settings, dungeonDefaults, "baseHorizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(settings, dungeonDefaults, "baseVerticalPosition", 0, 100)
    if not NQOL.Util.IsFontChoice(settings.baseFont) then
        settings.baseFont = dungeonDefaults.baseFont
    end
    NQOL.Settings.ClampedNumber(settings, dungeonDefaults, "baseFontSize", FONT_SIZE_MIN, FONT_SIZE_MAX, true)
    NQOL.Settings.ClampedNumber(settings, dungeonDefaults, "baseBackgroundOpacity", BACKGROUND_OPACITY_MIN, BACKGROUND_OPACITY_MAX, true)

    NQOL.Settings.Boolean(settings, dungeonDefaults, "dlcShowWatermark")
    NQOL.Settings.ClampedNumber(settings, dungeonDefaults, "dlcHorizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(settings, dungeonDefaults, "dlcVerticalPosition", 0, 100)
    if not NQOL.Util.IsFontChoice(settings.dlcFont) then
        settings.dlcFont = dungeonDefaults.dlcFont
    end
    NQOL.Settings.ClampedNumber(settings, dungeonDefaults, "dlcFontSize", FONT_SIZE_MIN, FONT_SIZE_MAX, true)
    NQOL.Settings.ClampedNumber(settings, dungeonDefaults, "dlcBackgroundOpacity", BACKGROUND_OPACITY_MIN, BACKGROUND_OPACITY_MAX, true)

    local validDetailLevels = {}
    for _, detailLevel in ipairs(DETAIL_LEVELS) do
        validDetailLevels[detailLevel.key] = true
    end
    NQOL.Settings.Choice(settings, dungeonDefaults, "baseDetailLevel", validDetailLevels)
    NQOL.Settings.Choice(settings, dungeonDefaults, "dlcDetailLevel", validDetailLevels)

    local fullScrollPositions = NQOL.Settings.EnsureTable(settings, "fullScrollPositions")
    fullScrollPositions[GROUP_BASE] = Clamp(fullScrollPositions[GROUP_BASE] or dungeonDefaults.fullScrollPositions[GROUP_BASE], 0, 1)
    fullScrollPositions[GROUP_DLC] = Clamp(fullScrollPositions[GROUP_DLC] or dungeonDefaults.fullScrollPositions[GROUP_DLC], 0, 1)

    return settings
end

local function GetGroupSettings(groupKey)
    local settings = GetSettings()
    local prefix = groupKey == GROUP_BASE and "base" or "dlc"

    return {
        detailLevel = settings[prefix .. "DetailLevel"] or DETAIL_BASIC,
        showWatermark = settings[prefix .. "ShowWatermark"] == true,
        horizontalPosition = settings[prefix .. "HorizontalPosition"],
        verticalPosition = settings[prefix .. "VerticalPosition"],
        font = settings[prefix .. "Font"],
        fontSize = settings[prefix .. "FontSize"],
        backgroundOpacity = settings[prefix .. "BackgroundOpacity"],
    }
end

local function GetSavedFullScrollRatio(groupKey)
    local fullScrollPositions = GetSettings().fullScrollPositions
    if type(fullScrollPositions) ~= "table" then
        return 0
    end

    return Clamp(tonumber(fullScrollPositions[groupKey]) or 0, 0, 1)
end

local function SaveFullScrollRatio(hud)
    if not hud or not hud.group or not hud.fullVirtualLayout then
        return
    end

    local settings = GetSettings()
    local fullScrollPositions = NQOL.Settings.EnsureTable(settings, "fullScrollPositions")
    local maxScrollOffset = tonumber(hud.maxScrollOffset) or 0
    if maxScrollOffset <= 0 then
        fullScrollPositions[hud.group] = 0
        return
    end

    fullScrollPositions[hud.group] = Clamp((tonumber(hud.scrollOffset) or 0) / maxScrollOffset, 0, 1)
end

local function RestoreFullScrollOffset(hud, layout)
    if not hud or not layout then
        return
    end

    local maxScrollOffset = tonumber(layout.maxScrollOffset) or 0
    hud.scrollOffset = Clamp(GetSavedFullScrollRatio(hud.group) * maxScrollOffset, 0, maxScrollOffset)
end

local function MoveControlAbove(targetControl, drawLevel)
    if not targetControl then
        return
    end

    if targetControl.SetDrawLayer and DL_OVERLAY then
        targetControl:SetDrawLayer(DL_OVERLAY)
    end

    if targetControl.SetDrawTier and DT_HIGH then
        targetControl:SetDrawTier(DT_HIGH)
    end

    if targetControl.SetDrawLevel then
        targetControl:SetDrawLevel(drawLevel or DRAW_LEVEL)
    end
end

local function ResolveFont(sizeOffset)
    local settings = GetGroupSettings(activeFontGroupKey)
    local size = Clamp((tonumber(settings.fontSize) or DEFAULT_FONT_SIZE) + (sizeOffset or 0), FONT_SIZE_MIN, FONT_SIZE_MAX + 8)
    local key = tostring(activeFontGroupKey) .. ":" .. tostring(settings.font) .. ":" .. tostring(size)
    if not fontStringCache[key] then
        fontStringCache[key] = NQOL.Util.CreateFontString(settings.font, size, "ZoFontGamepad18")
    end

    return fontStringCache[key]
end

local function GetFontSize(sizeOffset)
    return Clamp((tonumber(GetGroupSettings(activeFontGroupKey).fontSize) or DEFAULT_FONT_SIZE) + (sizeOffset or 0), FONT_SIZE_MIN, FONT_SIZE_MAX + 8)
end

local function GetLineHeight(sizeOffset)
    return GetFontSize(sizeOffset) + 6
end

local function GetWatermarkFontSize()
    return Clamp((tonumber(GetGroupSettings(activeFontGroupKey).fontSize) or DEFAULT_FONT_SIZE) + 8, FONT_SIZE_MIN, FONT_SIZE_MAX + 8)
end

local function ResolveWatermarkFont()
    local settings = GetGroupSettings(activeFontGroupKey)
    local size = GetWatermarkFontSize()
    local key = tostring(activeFontGroupKey) .. ":" .. tostring(settings.font) .. ":watermark:" .. tostring(size)
    if not fontStringCache[key] then
        fontStringCache[key] = NQOL.Util.CreateFontString(settings.font, size, "ZoFontGamepad18")
    end

    return fontStringCache[key]
end

local function GetScreenDimensions()
    local width = GetScreenWidth and GetScreenWidth() or nil
    local height = GetScreenHeight and GetScreenHeight() or nil
    if (not width or width <= 0) and GuiRoot and GuiRoot.GetWidth then
        width = GuiRoot:GetWidth()
    end
    if (not height or height <= 0) and GuiRoot and GuiRoot.GetHeight then
        height = GuiRoot:GetHeight()
    end

    return width or 1920, height or 1080
end

local function NormalizeName(name)
    return string.lower(tostring(name or ""))
end

local function GetAchievementData(achievementId)
    if not achievementId or not GetAchievementInfo then
        return nil
    end

    local name, description, points, icon, completed, date, time = GetAchievementInfo(achievementId)
    return {
        id = achievementId,
        name = name,
        description = description,
        points = points,
        icon = icon,
        completed = completed == true,
        date = date,
        time = time,
    }
end

local function IsAchievementIdComplete(achievementId)
    if not achievementId then
        return nil
    end

    if IsAchievementComplete then
        return IsAchievementComplete(achievementId) == true
    end

    local achievement = GetAchievementData(achievementId)
    return achievement and achievement.completed or nil
end

local function GetAchievementDate(achievementId)
    local achievement = GetAchievementData(achievementId)
    if not achievement or achievement.completed ~= true then
        return nil
    end

    local date = achievement.date
    if type(date) == "string" and date ~= "" then
        return date
    end

    if type(date) == "number" and date > 0 then
        return tostring(date)
    end

    return nil
end

local function GetAchievementName(achievementId)
    local achievement = GetAchievementData(achievementId)
    return achievement and achievement.name or ""
end

local function GetAchievementDescription(achievementId)
    local achievement = GetAchievementData(achievementId)
    return achievement and achievement.description or ""
end

local function GetDateSortKey(date)
    if not date or date == "" or date == 0 then
        return ""
    end

    local value = tostring(date)
    local year, month, day = string.match(value, "^(%d%d%d%d)%-(%d%d?)%-(%d%d?)$")
    if year and month and day then
        return string.format("%04d%02d%02d", tonumber(year), tonumber(month), tonumber(day))
    end

    month, day, year = string.match(value, "^(%d%d?)/(%d%d?)/(%d%d%d%d)$")
    if year and month and day then
        return string.format("%04d%02d%02d", tonumber(year), tonumber(month), tonumber(day))
    end

    year, month, day = string.match(value, "^(%d%d%d%d)(%d%d)(%d%d)$")
    if year and month and day then
        return string.format("%04d%02d%02d", tonumber(year), tonumber(month), tonumber(day))
    end

    return value
end

local function CompareExtraAchievements(left, right)
    local leftId = type(left) == "table" and left.id or left
    local rightId = type(right) == "table" and right.id or right
    local leftCompleted = IsAchievementIdComplete(leftId) == true
    local rightCompleted = IsAchievementIdComplete(rightId) == true

    if leftCompleted ~= rightCompleted then
        return leftCompleted
    end

    if leftCompleted then
        local leftDate = GetDateSortKey(GetAchievementDate(leftId))
        local rightDate = GetDateSortKey(GetAchievementDate(rightId))
        if leftDate ~= rightDate then
            return leftDate > rightDate
        end
    end

    local leftName = NormalizeName(GetAchievementName(leftId))
    local rightName = NormalizeName(GetAchievementName(rightId))
    if leftName ~= rightName then
        return leftName < rightName
    end

    return (tonumber(leftId) or 0) < (tonumber(rightId) or 0)
end

local function GetDungeonName(definition)
    if GetZoneNameById then
        local zoneName = GetZoneNameById(definition.zoneId)
        if zoneName and zoneName ~= "" then
            if zo_strformat and SI_ZONE_NAME then
                return zo_strformat(SI_ZONE_NAME, zoneName)
            end
            return zoneName
        end
    end

    return definition.sourceName or GetAchievementName(definition.normal) or NQOL.L("features.progress_dungeons.fallback_name", definition.dungeonId)
end

local function ShouldShow()
    return settingsPanelGroup ~= nil
end

local function ShouldShowGroup(groupKey)
    return settingsPanelGroup == groupKey
end

local function CreateLabel(parent, fontOffset, color, horizontalAlignment)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(ResolveFont(fontOffset))
    label:SetColor(color[1], color[2], color[3], color[4])
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetHorizontalAlignment(horizontalAlignment or TEXT_ALIGN_LEFT)
    if label.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    MoveControlAbove(label, DRAW_LEVEL + 9)
    return label
end

local function CreateIcon(parent)
    local icon = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    icon:SetDimensions(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
    icon:SetHidden(true)
    MoveControlAbove(icon, DRAW_LEVEL + 9)
    return icon
end

local function ApplyCompletionIcon(icon, completed)
    if not icon then
        return
    end

    if completed == nil then
        completed = false
    end

    icon:SetTexture(completed and CHECKMARK_TEXTURE or CROSS_TEXTURE)
    if icon.SetTextureCoords then
        icon:SetTextureCoords(0, 1, 0, 1)
    end
    if completed then
        icon:SetColor(0.22, 0.95, 0.36, 1)
    else
        icon:SetColor(1, 0.22, 0.22, 1)
    end
    icon:SetHidden(false)
end

local function AnchorCompletionIcon(icon, parent, x, lineHeight, completed)
    local size = completed and STATUS_ICON_SIZE or 14
    local xOffset = completed and 0 or 2
    local yOffset = ((lineHeight - size) / 2) + (completed and 0 or 2)

    icon:ClearAnchors()
    icon:SetDimensions(size, size)
    icon:SetAnchor(TOPLEFT, parent, TOPLEFT, x + xOffset, yOffset)
    ApplyCompletionIcon(icon, completed)
end

local function GetTrackedAchievementIds(definition)
    local achievementIds = {}
    local seenAchievementIds = {}
    for _, achievementId in ipairs(definition.extra or {}) do
        if not seenAchievementIds[achievementId] then
            seenAchievementIds[achievementId] = true
            achievementIds[#achievementIds + 1] = achievementId
        end
    end

    return achievementIds
end

local function GetExtraAchievementIds(definition)
    local achievementIds = {}
    local seenAchievementIds = {}
    for _, trackedType in ipairs(TRACKED_TYPES) do
        if not trackedType.aggregate and definition[trackedType.key] then
            seenAchievementIds[definition[trackedType.key]] = true
        end
    end

    for _, achievementId in ipairs(definition.extra or {}) do
        if not seenAchievementIds[achievementId] then
            seenAchievementIds[achievementId] = true
            achievementIds[#achievementIds + 1] = achievementId
        end
    end

    return achievementIds
end

local function BuildDungeonRow(definition, detailLevel)
    local extraAchievementIds = GetExtraAchievementIds(definition)
    local row = {
        definition = definition,
        group = definition.group,
        name = GetDungeonName(definition),
        statuses = {},
        extraAchievementIds = extraAchievementIds,
        extraComplete = nil,
        extraTotal = #extraAchievementIds,
        trackedAchievements = GetTrackedAchievementIds(definition),
        detailLevelLoaded = nil,
    }

    for _, trackedType in ipairs(TRACKED_TYPES) do
        if not trackedType.aggregate then
            local achievementId = definition[trackedType.key]
            local hasOnlyGenericHardMode = definition.hm ~= nil and definition.hm1 == nil and definition.hm2 == nil
            local unavailableHardMode = hasOnlyGenericHardMode and not achievementId and (trackedType.key == "hm1" or trackedType.key == "hm2")
            row.statuses[trackedType.key] = {
                id = achievementId,
                unavailable = unavailableHardMode,
            }
        end
    end

    row.statuses.extra = {
        aggregate = true,
        completed = false,
        complete = 0,
        total = row.extraTotal,
    }

    if detailLevel then
        row.extraComplete = 0
        for _, trackedType in ipairs(TRACKED_TYPES) do
            if not trackedType.aggregate then
                local status = row.statuses[trackedType.key]
                if status then
                    status.completed = IsAchievementIdComplete(status.id)
                end
            end
        end
        for _, achievementId in ipairs(row.extraAchievementIds or {}) do
            if IsAchievementIdComplete(achievementId) then
                row.extraComplete = row.extraComplete + 1
            end
        end
        row.statuses.extra.completed = row.extraTotal > 0 and row.extraComplete >= row.extraTotal
        row.statuses.extra.complete = row.extraComplete
        row.detailLevelLoaded = DETAIL_BASIC

        if detailLevel ~= DETAIL_BASIC then
            for _, trackedType in ipairs(TRACKED_TYPES) do
                if not trackedType.aggregate then
                    local status = row.statuses[trackedType.key]
                    if status then
                        status.date = GetAchievementDate(status.id)
                    end
                end
            end
            row.detailLevelLoaded = DETAIL_ADVANCED
        end

        if detailLevel == DETAIL_FULL then
            table.sort(row.trackedAchievements, CompareExtraAchievements)
            row.trackedAchievementsSorted = true
        end
    end

    return row
end

local function SortDungeonRows(rows)
    table.sort(rows, function(left, right)
        if left.group ~= right.group then
            return left.group == GROUP_BASE
        end
        return NormalizeName(left.name) < NormalizeName(right.name)
    end)
end

local function BuildDungeonRows(detailLevel)
    local rows = {}
    local definitions = ParseDungeonDefinitions()
    for _, definition in ipairs(definitions) do
        rows[#rows + 1] = BuildDungeonRow(definition, detailLevel)
    end

    SortDungeonRows(rows)

    return rows
end

local function BuildDungeonRowsAsync(generation, callback, detailLevel)
    if not zo_callLater then
        dungeonRowsByDetailLevel[detailLevel] = BuildDungeonRows(detailLevel)
        callback(generation, dungeonRowsByDetailLevel[detailLevel])
        return
    end

    local rows = {}
    local index = 1
    local definitions = ParseDungeonDefinitions()

    local function Continue()
        if generation ~= refreshGeneration then
            return
        end

        local stopIndex = math.min(index + ASYNC_BUILD_BATCH_SIZE - 1, #definitions)
        while index <= stopIndex do
            rows[#rows + 1] = BuildDungeonRow(definitions[index], detailLevel)
            index = index + 1
        end

        if index <= #definitions then
            zo_callLater(Continue, 1)
            return
        end

        SortDungeonRows(rows)
        dungeonRowsByDetailLevel[detailLevel] = rows
        callback(generation, rows)
    end

    Continue()
end

local function EnsureDungeonRows(detailLevel)
    if not dungeonRowsByDetailLevel[detailLevel] then
        dungeonRowsByDetailLevel[detailLevel] = BuildDungeonRows(detailLevel)
    end

    return dungeonRowsByDetailLevel[detailLevel]
end

local function GetRowsForGroup(groupKey, detailLevel)
    local rows = {}
    for _, row in ipairs(EnsureDungeonRows(detailLevel)) do
        if row.group == groupKey then
            rows[#rows + 1] = row
        end
    end
    return rows
end

local function GetGroupTitle(groupKey)
    if groupKey == GROUP_BASE then
        return NQOL.L("features.progress_dungeons.base")
    end
    return NQOL.L("features.progress_dungeons.dlc")
end

local function GetHeaderTimestamp()
    if GetTimeStamp and os and os.date then
        local time = os.date("*t", GetTimeStamp())
        if time then
            return string.format("%04d-%02d-%02d %02d:%02d", time.year or 0, time.month or 0, time.day or 0, time.hour or 0, time.min or 0)
        end
    end

    if os and os.date then
        local time = os.date("*t")
        if time then
            return string.format("%04d-%02d-%02d %02d:%02d", time.year or 0, time.month or 0, time.day or 0, time.hour or 0, time.min or 0)
        end
    end

    if GetDate and GetTimeString then
        local year, month, day = GetDate()
        local hour, minute = string.match(GetTimeString() or "", "^(%d%d?):(%d%d)")
        return string.format("%04d-%02d-%02d %02d:%02d", tonumber(year) or 0, tonumber(month) or 0, tonumber(day) or 0, tonumber(hour) or 0, tonumber(minute) or 0)
    end

    return "0000-00-00 00:00"
end

local function GetHeaderMetaText()
    local playerId = GetDisplayName and GetDisplayName() or ""
    if playerId == "" and GetUnitDisplayName then
        playerId = GetUnitDisplayName("player") or ""
    end

    local platformServer = string.format(
        "%s %s",
        NQOL.Util.GetConsolePlatform(),
        NQOL.Util.GetMegaserverName()
    )

    if playerId == "" then
        return string.format("%s · %s", platformServer, GetHeaderTimestamp())
    end

    if string.sub(playerId, 1, 1) ~= "@" then
        playerId = "@" .. playerId
    end

    return string.format(
        "%s · %s · %s",
        playerId,
        platformServer,
        GetHeaderTimestamp()
    )
end

local function GetWatermarkText()
    return GetHeaderMetaText()
end

local function GetFooterMetaText()
    return NQOL.L("common.version", tostring(NQOL.version or 0))
end

local function GetColumnWidth(detailLevel, groupKey)
    local width
    if detailLevel == DETAIL_FULL then
        width = FULL_COLUMN_WIDTH
    elseif detailLevel == DETAIL_ADVANCED then
        width = ADVANCED_COLUMN_WIDTH
    else
        width = math.floor(BASIC_COLUMN_WIDTH * BASIC_WIDTH_SCALE)
    end

    if groupKey == GROUP_DLC then
        width = math.floor(width * DLC_WIDTH_SCALE)
    end

    return width
end

local function GetStatusColumnWidth(detailLevel)
    if detailLevel == DETAIL_BASIC then
        return Clamp(GetFontSize(-7) * 5, STATUS_ICON_SIZE + 12, STATUS_TEXT_WIDTH)
    end
    if detailLevel == DETAIL_ADVANCED then
        return Clamp(GetFontSize(-7) * 7, 78, 104)
    end

    return Clamp(GetFontSize(-7) * 9, 132, 172)
end

local function GetNameColumnWidth(rows, detailLevel, columnWidth, statusColumnWidth, visibleTrackedTypes)
    local maxNameLength = 0
    for _, row in ipairs(rows or {}) do
        maxNameLength = math.max(maxNameLength, string.len(tostring(row.name or "")))
    end

    local availableWidth = math.max(columnWidth - (#visibleTrackedTypes * statusColumnWidth) - 8, 1)
    local fontSize = GetFontSize(-3)
    local widthFactor = 0.58
    if detailLevel == DETAIL_BASIC then
        widthFactor = 0.54
    elseif detailLevel == DETAIL_ADVANCED then
        widthFactor = 0.46
    elseif detailLevel == DETAIL_FULL then
        widthFactor = 0.46
    end
    local desiredWidth = math.ceil(maxNameLength * fontSize * widthFactor)
    local minimumWidth = math.min(math.ceil(fontSize * 7), availableWidth)

    return Clamp(desiredWidth, minimumWidth, availableWidth)
end

local function GetFullRowBackgroundWidth(layout, visibleTrackedTypes)
    local visibleStatusColumns = visibleTrackedTypes and #visibleTrackedTypes or 0
    local rowWidth = layout.nameColumnWidth + 8 + (visibleStatusColumns * layout.statusColumnWidth)
    return math.min(math.max(rowWidth, layout.nameColumnWidth), layout.contentWidth)
end

local function EstimateTextWidth(text, fontOffset, widthFactor)
    local visibleText = tostring(text or "")
    visibleText = string.gsub(visibleText, "|c%x%x%x%x%x%x", "")
    visibleText = string.gsub(visibleText, "|r", "")
    return math.ceil(string.len(visibleText) * GetFontSize(fontOffset) * (widthFactor or 0.56))
end

local function BuildRenderableRows(rows, detailLevel)
    local renderRows = {}
    for rowIndex, row in ipairs(rows) do
        local blockRows = detailLevel == DETAIL_FULL and (1 + #row.trackedAchievements) or 1
        renderRows[#renderRows + 1] = { kind = "dungeon", row = row, blockRowIndex = 1, blockRows = blockRows }
        if detailLevel == DETAIL_FULL then
            for achievementIndex, achievementId in ipairs(row.trackedAchievements) do
                renderRows[#renderRows + 1] = {
                    kind = "achievement",
                    row = row,
                    achievementId = achievementId,
                    blockRowIndex = achievementIndex + 1,
                    blockRows = blockRows,
                }
            end
            if rowIndex < #rows then
                for _ = 1, FULL_DUNGEON_GAP_ROWS do
                    renderRows[#renderRows + 1] = { kind = "spacer" }
                end
            end
        end
    end

    return renderRows
end

local function GetVisibleTrackedTypes(rows, detailLevel)
    local visibleTypes = {}
    for _, trackedType in ipairs(TRACKED_TYPES) do
        if not (detailLevel == DETAIL_FULL and trackedType.key == "extra") then
            for _, row in ipairs(rows) do
                local status = row.statuses[trackedType.key]
                if status and (status.id or (status.aggregate and status.total and status.total > 0)) then
                    visibleTypes[#visibleTypes + 1] = trackedType
                    break
                end
            end
        end
    end

    return visibleTypes
end

local function GetLayoutMetrics(renderRows, detailLevel, rows, visibleTrackedTypes, groupKey)
    local screenWidth, screenHeight = GetScreenDimensions()
    local safeWidth = math.max(screenWidth - (SCREEN_MARGIN * 2), 320)
    local safeHeight = math.max(screenHeight - (SCREEN_MARGIN * 2), 240)
    local baseRowHeight = GetLineHeight(detailLevel == DETAIL_FULL and -5 or -3)
    local rowHeight = baseRowHeight
    local headerHeight = GetLineHeight(HEADER_HEIGHT_OFFSET)
    local columnHeaderHeight = detailLevel == DETAIL_FULL and 0 or GetLineHeight(-7)
    local footerTextHeight = GetLineHeight(FOOTER_HEIGHT_OFFSET)
    local footerHeight = FOOTER_TOP_GAP + FOOTER_DIVIDER_HEIGHT + FOOTER_DIVIDER_TEXT_GAP + (footerTextHeight * 2) + FOOTER_LINE_GAP
    local maxColumnWidth = math.min(GetColumnWidth(detailLevel, groupKey), HUD_MAX_WIDTH)
    local statusColumnWidth = GetStatusColumnWidth(detailLevel)
    local nameColumnWidth = GetNameColumnWidth(rows, detailLevel, maxColumnWidth, statusColumnWidth, visibleTrackedTypes)
    local tableWidth = nameColumnWidth + 8 + (#visibleTrackedTypes * statusColumnWidth)
    local minimumColumnWidth = tableWidth
    local footerWidth = EstimateTextWidth(BuildFooter and BuildFooter(rows) or "", FOOTER_HEIGHT_OFFSET, 0.5)
    local desiredColumnWidth = detailLevel == DETAIL_BASIC and tableWidth or math.max(tableWidth, footerWidth)
    if detailLevel == DETAIL_BASIC then
        desiredColumnWidth = math.max(desiredColumnWidth, math.ceil(tableWidth * BASIC_WIDTH_SCALE))
    end
    local columnWidth = Clamp(desiredColumnWidth, minimumColumnWidth, maxColumnWidth)
    local tableViewportTop = headerHeight + 8
    local rowAreaTop = columnHeaderHeight > 0 and (columnHeaderHeight + 4) or 0
    local tableTopOffset = tableViewportTop + rowAreaTop
    local availableRowHeight = math.max(safeHeight - HUD_PADDING - tableTopOffset - footerHeight - HUD_PADDING, rowHeight)
    local rowsPerColumn = math.max(1, math.floor((availableRowHeight + ROW_GAP) / (rowHeight + ROW_GAP)))
    local columns = math.max(1, math.ceil(#renderRows / rowsPerColumn))
    if detailLevel == DETAIL_FULL then
        columns = 1
    end
    local maxColumns = math.max(1, math.floor((safeWidth - (HUD_PADDING * 2) + COLUMN_GAP) / (columnWidth + COLUMN_GAP)))
    columns = math.min(columns, maxColumns)
    rowsPerColumn = math.max(1, math.ceil(math.max(#renderRows, 1) / columns))
    local hudWidth = Clamp((HUD_PADDING * 2) + (columnWidth * columns) + (COLUMN_GAP * (columns - 1)), columnWidth, HUD_MAX_WIDTH)
    local contentWidth = hudWidth - (HUD_PADDING * 2)
    local rowsHeight = (rowsPerColumn * rowHeight) + (math.max(rowsPerColumn - 1, 0) * ROW_GAP)
    local tableContentHeight = rowAreaTop + rowsHeight
    local fullHudHeight = HUD_PADDING + tableViewportTop + tableContentHeight + footerHeight + HUD_PADDING
    local hudHeight = math.min(fullHudHeight, safeHeight)
    if detailLevel == DETAIL_FULL then
        hudHeight = math.max(math.floor(hudHeight * FULL_HEIGHT_SCALE), HUD_PADDING + tableViewportTop + rowHeight + footerHeight + HUD_PADDING)
    end
    local tableViewportHeight = math.max(hudHeight - HUD_PADDING - tableViewportTop - footerHeight - HUD_PADDING, rowHeight)

    return {
        columns = columns,
        rowsPerColumn = rowsPerColumn,
        rowHeight = rowHeight,
        headerHeight = headerHeight,
        columnHeaderHeight = columnHeaderHeight,
        rowAreaTop = rowAreaTop,
        tableViewportTop = tableViewportTop,
        tableViewportHeight = tableViewportHeight,
        tableContentHeight = tableContentHeight,
        tableTopOffset = tableTopOffset,
        footerHeight = footerHeight,
        footerTextHeight = footerTextHeight,
        columnWidth = columnWidth,
        statusColumnWidth = statusColumnWidth,
        nameColumnWidth = nameColumnWidth,
        contentWidth = contentWidth,
        fullRowBackgroundWidth = GetFullRowBackgroundWidth({
            nameColumnWidth = nameColumnWidth,
            statusColumnWidth = statusColumnWidth,
            contentWidth = contentWidth,
        }, visibleTrackedTypes),
        hudWidth = hudWidth,
        hudHeight = hudHeight,
        maxScrollOffset = math.max(tableContentHeight - tableViewportHeight, 0),
    }
end

local function HideRowControls(rowControl)
    rowControl.container:SetHidden(true)
    rowControl.name:SetHidden(true)
    for _, icon in pairs(rowControl.icons) do icon:SetHidden(true) end
    for _, label in pairs(rowControl.dates) do label:SetHidden(true) end
end

local function ClearLabelText(label)
    if label and label.SetText then
        label:SetText("")
    end
end

local function ClearTexture(textureControl)
    if textureControl and textureControl.SetTexture then
        textureControl:SetTexture(nil)
    end
end

local function ResetFullRowControl(rowControl, clearText)
    if not rowControl then
        return
    end

    rowControl.clipTop = nil
    rowControl.clipBottom = nil
    rowControl.logicalIndex = nil
    rowControl.renderGeneration = nil

    if rowControl.content then
        rowControl.content:SetHidden(true)
    end
    if rowControl.name then
        if clearText then
            ClearLabelText(rowControl.name)
        end
        rowControl.name:SetHidden(true)
    end
    if rowControl.text then
        if clearText then
            ClearLabelText(rowControl.text)
        end
        rowControl.text:SetHidden(true)
    end
    for _, label in ipairs(rowControl.statusLabels or {}) do
        if clearText then
            ClearLabelText(label)
        end
        label:SetHidden(true)
    end
    for _, icon in ipairs(rowControl.icons or {}) do
        icon:SetHidden(true)
    end
end

local function HideFullRowControl(rowControl)
    if not rowControl then
        return
    end

    if rowControl.container then
        rowControl.container:SetHidden(true)
    end
    ResetFullRowControl(rowControl, true)
end

local function HideFullRows(hud, clearVirtualState)
    if not hud then
        return
    end

    if clearVirtualState ~= false then
        hud.fullVirtualRenderRows = nil
        hud.fullVirtualLayout = nil
        hud.fullVirtualVisibleTrackedTypes = nil
        hud.fullVirtualGeneration = nil
    end

    for _, rowControl in ipairs(hud.fullSummaryRows or {}) do
        HideFullRowControl(rowControl)
    end
    for _, rowControl in ipairs(hud.fullAchievementRows or {}) do
        HideFullRowControl(rowControl)
    end
end

local function HideStandardRows(hud)
    if not hud then return end
    hud.standardData = nil
    for _, rowControl in ipairs(hud.rows or {}) do HideRowControls(rowControl) end
    for _, label in ipairs(hud.standardHeaders or {}) do label:SetHidden(true) end
end

local function UpdateRowClipVisibility(hud)
    StandardRows.Render(hud)
end

local function EnsureFullSummaryRowControl(hud, index)
    hud.fullSummaryRows = hud.fullSummaryRows or {}
    if hud.fullSummaryRows[index] then
        return hud.fullSummaryRows[index]
    end

    local rowControl = {
        parent = hud.viewport,
        statusLabels = {},
        icons = {},
    }

    rowControl.container = WINDOW_MANAGER:CreateControl(nil, hud.viewport, CT_CONTROL)
    rowControl.container:SetHidden(true)
    MoveControlAbove(rowControl.container, DRAW_LEVEL + 1)

    rowControl.content = WINDOW_MANAGER:CreateControl(nil, rowControl.container, CT_CONTROL)
    rowControl.content:SetHidden(true)
    MoveControlAbove(rowControl.content, DRAW_LEVEL + 2)

    rowControl.name = CreateLabel(rowControl.content, -3, { 1, 1, 1, 0.92 })

    for statusIndex = 1, FULL_STATUS_CONTROL_COUNT do
        rowControl.statusLabels[statusIndex] = CreateLabel(rowControl.content, -7, { 1, 1, 1, 1 }, TEXT_ALIGN_LEFT)
        rowControl.icons[statusIndex] = CreateIcon(rowControl.content)
    end

    hud.fullSummaryRows[index] = rowControl
    return rowControl
end

local function EnsureFullAchievementRowControl(hud, index)
    hud.fullAchievementRows = hud.fullAchievementRows or {}
    if hud.fullAchievementRows[index] then
        return hud.fullAchievementRows[index]
    end

    local rowControl = {
        parent = hud.viewport,
        icons = {},
    }

    rowControl.container = WINDOW_MANAGER:CreateControl(nil, hud.viewport, CT_CONTROL)
    rowControl.container:SetHidden(true)
    MoveControlAbove(rowControl.container, DRAW_LEVEL + 1)

    rowControl.content = WINDOW_MANAGER:CreateControl(nil, rowControl.container, CT_CONTROL)
    rowControl.content:SetHidden(true)
    MoveControlAbove(rowControl.content, DRAW_LEVEL + 2)

    rowControl.text = CreateLabel(rowControl.content, -6, { 1, 1, 1, 0.82 })
    rowControl.icons[1] = CreateIcon(rowControl.content)
    rowControl.icons[2] = CreateIcon(rowControl.content)

    hud.fullAchievementRows[index] = rowControl
    return rowControl
end

local function EnsureRowControl(hud, index)
    if hud.rows[index] then return hud.rows[index] end
    local rowControl = {
        container = WINDOW_MANAGER:CreateControl(nil, hud.content, CT_CONTROL),
        icons = {},
        dates = {},
    }
    MoveControlAbove(rowControl.container, DRAW_LEVEL + 2)
    rowControl.name = CreateLabel(rowControl.container, -3, { 1, 1, 1, 0.92 })
    hud.rows[index] = rowControl
    return rowControl
end

local function HideHud(hud)
    if hud and hud.control then
        SaveFullScrollRatio(hud)
        HideStandardRows(hud)
        hud.control:SetHidden(true)
        hud.hasRenderedContent = false
        if DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.IsListening and DIRECTIONAL_INPUT:IsListening(hud) then
            DIRECTIONAL_INPUT:Deactivate(hud)
        end
        hud.scrollOffset = 0
        hud.maxScrollOffset = 0
        if hud.content then
            hud.content:ClearAnchors()
            hud.content:SetAnchor(TOPLEFT, hud.viewport or hud.control, TOPLEFT, 0, 0)
        end
        if hud.footerDivider then
            hud.footerDivider:SetHidden(true)
        end
        if hud.footerCounterClip then
            hud.footerCounterClip:SetHidden(true)
        end
        for _, counter in ipairs(hud.footerCounters or {}) do
            counter:SetHidden(true)
        end
        if hud.headerMask then
            hud.headerMask:SetHidden(true)
        end
        if hud.footerMask then
            hud.footerMask:SetHidden(true)
        end
        if hud.watermarkClip then
            hud.watermarkClip:SetHidden(true)
        end
        if hud.loading then
            hud.loading:SetHidden(true)
        end
        if hud.watermark then
            hud.watermark:SetHidden(true)
        end
        HideFullRows(hud)
    end
end

local function ApplyScrollOffset(hud)
    if not hud or not hud.content or not hud.viewport then
        return
    end

    hud.scrollOffset = Clamp(tonumber(hud.scrollOffset) or 0, 0, tonumber(hud.maxScrollOffset) or 0)
    hud.content:ClearAnchors()
    hud.content:SetAnchor(TOPLEFT, hud.viewport, TOPLEFT, 0, -hud.scrollOffset)
    UpdateRowClipVisibility(hud)
    if RenderVisibleFullRows then
        RenderVisibleFullRows(hud)
    end
end

local function SetHudLoading(hud, isLoading, layout)
    if not hud then
        return
    end

    hud.isLoading = isLoading == true

    if hud.viewport then
        hud.viewport:SetHidden(hud.isLoading)
    end
    if hud.footer then
        hud.footer:SetHidden(hud.isLoading)
    end
    if hud.footerDivider then
        hud.footerDivider:SetHidden(hud.isLoading)
    end
    if hud.footerCounterClip then
        hud.footerCounterClip:SetHidden(hud.isLoading)
    end
    for _, counter in ipairs(hud.footerCounters or {}) do
        counter:SetHidden(hud.isLoading)
    end
    if hud.isLoading then
        HideStandardRows(hud)
        HideFullRows(hud)
    end

    if hud.loading then
        hud.loading:SetFont(ResolveFont(-3))
        hud.loading:SetText(NQOL.L("features.progress_dungeons.loading_dungeon_data_d46aed6"))
        hud.loading:ClearAnchors()
        if layout then
            hud.loading:SetDimensions(layout.contentWidth, layout.tableViewportHeight)
            hud.loading:SetAnchor(TOPLEFT, hud.control, TOPLEFT, HUD_PADDING, HUD_PADDING + layout.tableViewportTop)
        else
            hud.loading:SetAnchor(CENTER, hud.control, CENTER, 0, 0)
        end
        hud.loading:SetHidden(not hud.isLoading)
    end

    if hud.empty then
        hud.empty:SetHidden(true)
    end
end

local function FinishHudRender(hud, rows, layout)
    SetHudLoading(hud, false, layout)
    hud.hasRenderedContent = true
    hud.tableViewportHeight = layout.tableViewportHeight
    UpdateRowClipVisibility(hud)

    hud.empty:SetHidden(#rows > 0)
    hud.empty:ClearAnchors()
    hud.empty:SetDimensions(layout.contentWidth, layout.rowHeight)
    hud.empty:SetAnchor(TOPLEFT, hud.viewport, TOPLEFT, 0, 0)

    RenderFooter(hud, rows, layout)

    hud.control:SetHidden(false)
    RefreshScrollActivation(hud)
    ApplyHudPosition(hud)
end

RefreshScrollActivation = function(hud)
    if not hud or not hud.control or not DIRECTIONAL_INPUT then
        return
    end

    local isListening = DIRECTIONAL_INPUT.IsListening and DIRECTIONAL_INPUT:IsListening(hud)
    local shouldListen = hud.control:IsHidden() == false and (tonumber(hud.maxScrollOffset) or 0) > 0
    if shouldListen and not isListening then
        DIRECTIONAL_INPUT:Activate(hud, hud.control)
    elseif not shouldListen and isListening then
        DIRECTIONAL_INPUT:Deactivate(hud)
    end
end

local function UpdateHudScroll(hud, elapsedSeconds)
    if not hud or not hud.control or hud.control:IsHidden() or not hud.maxScrollOffset or hud.maxScrollOffset <= 0 then
        return
    end

    if not DIRECTIONAL_INPUT or not ZO_DI_RIGHT_STICK then
        return
    end

    local stickY = DIRECTIONAL_INPUT:GetY(ZO_DI_RIGHT_STICK) or 0
    if math.abs(stickY) <= SCROLL_DEADZONE then
        return
    end

    local scrollSpeed = SCROLL_SPEED
    if hud.fullVirtualLayout then
        scrollSpeed = scrollSpeed * FULL_SCROLL_SPEED_MULTIPLIER
    end

    hud.scrollOffset = Clamp((tonumber(hud.scrollOffset) or 0) - (stickY * scrollSpeed * elapsedSeconds), 0, hud.maxScrollOffset)
    ApplyScrollOffset(hud)
    SaveFullScrollRatio(hud)
    if DIRECTIONAL_INPUT.Consume then
        DIRECTIONAL_INPUT:Consume(ZO_DI_RIGHT_STICK)
    end
end

local function ApplyHudBackground(hud)
    if not hud then
        return
    end

    local opacity = GetGroupSettings(hud.group).backgroundOpacity / 100
    if hud.background then
        hud.background:SetCenterColor(0, 0, 0, opacity)
        hud.background:SetEdgeColor(0, 0, 0, 0)
    end
    if hud.headerMask then
        hud.headerMask:SetCenterColor(0, 0, 0, opacity)
        hud.headerMask:SetEdgeColor(0, 0, 0, 0)
    end
    if hud.footerMask then
        hud.footerMask:SetCenterColor(0, 0, 0, opacity)
        hud.footerMask:SetEdgeColor(0, 0, 0, 0)
    end
end

ApplyHudPosition = function(hud)
    if not hud or not hud.control or not GuiRoot then
        return
    end

    local settings = GetGroupSettings(hud.group)
    local screenWidth, screenHeight = GetScreenDimensions()
    local x = math.max(screenWidth - hud.control:GetWidth(), 0) * ((tonumber(settings.horizontalPosition) or 0) / 100)
    local y = math.max(screenHeight - hud.control:GetHeight(), 0) * ((tonumber(settings.verticalPosition) or 0) / 100)
    hud.control:ClearAnchors()
    hud.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

local function EnsureHud(groupKey)
    local hud = huds[groupKey]
    if hud or not WINDOW_MANAGER or not GuiRoot then
        return hud
    end

    hud = { group = groupKey, rows = {}, footerCounters = {}, scrollOffset = 0, maxScrollOffset = 0 }
    hud.control = WINDOW_MANAGER:CreateTopLevelWindow("NQOLProgressDungeons_" .. groupKey)
    hud.control:SetHidden(true)
    MoveControlAbove(hud.control, DRAW_LEVEL)
    hud.UpdateDirectionalInput = function(_, elapsedSeconds)
        UpdateHudScroll(hud, elapsedSeconds or 0)
    end

    hud.background = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_BACKDROP)
    hud.background:SetAnchorFill(hud.control)
    MoveControlAbove(hud.background, DRAW_LEVEL)

    hud.headerMask = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_BACKDROP)
    hud.headerMask:SetCenterColor(0, 0, 0, 0)
    hud.headerMask:SetEdgeColor(0, 0, 0, 0)
    MoveControlAbove(hud.headerMask, DRAW_LEVEL + 6)

    hud.footerMask = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_BACKDROP)
    hud.footerMask:SetCenterColor(0, 0, 0, 0)
    hud.footerMask:SetEdgeColor(0, 0, 0, 0)
    MoveControlAbove(hud.footerMask, DRAW_LEVEL + 6)

    hud.watermarkClip = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_CONTROL)
    if hud.watermarkClip.SetClipsChildren then
        hud.watermarkClip:SetClipsChildren(true)
    end
    MoveControlAbove(hud.watermarkClip, DRAW_LEVEL + 7)

    hud.viewport = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_CONTROL)
    if hud.viewport.SetClipsChildren then
        hud.viewport:SetClipsChildren(true)
    end
    MoveControlAbove(hud.viewport, DRAW_LEVEL + 1)

    hud.content = WINDOW_MANAGER:CreateControl(nil, hud.viewport, CT_CONTROL)
    MoveControlAbove(hud.content, DRAW_LEVEL + 1)

    hud.header = CreateLabel(hud.control, HEADER_HEIGHT_OFFSET, { 0.72, 0.86, 1, 1 })
    MoveControlAbove(hud.header, DRAW_LEVEL + 8)
    hud.footer = CreateLabel(hud.control, FOOTER_HEIGHT_OFFSET, { 1, 1, 1, 0.88 }, TEXT_ALIGN_RIGHT)
    MoveControlAbove(hud.footer, DRAW_LEVEL + 8)
    hud.footerCounterClip = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_CONTROL)
    if hud.footerCounterClip.SetClipsChildren then
        hud.footerCounterClip:SetClipsChildren(true)
    end
    MoveControlAbove(hud.footerCounterClip, DRAW_LEVEL + 8)
    hud.footerDivider = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_TEXTURE)
    hud.footerDivider:SetColor(0.72, 0.86, 1, 0.38)
    MoveControlAbove(hud.footerDivider, DRAW_LEVEL + 8)
    hud.empty = CreateLabel(hud.control, -3, { 1, 1, 1, 0.8 }, TEXT_ALIGN_CENTER)
    hud.empty:SetText(NQOL.L("features.progress_dungeons.no_dungeon_data_is_available_b1e357f"))
    hud.empty:SetHidden(true)
    MoveControlAbove(hud.empty, DRAW_LEVEL + 8)

    hud.loading = CreateLabel(hud.control, -3, { 1, 1, 1, 0.86 }, TEXT_ALIGN_CENTER)
    hud.loading:SetText(NQOL.L("features.progress_dungeons.loading_dungeon_data_d46aed6"))
    hud.loading:SetHidden(true)
    MoveControlAbove(hud.loading, DRAW_LEVEL + 8)

    huds[groupKey] = hud
    return hud
end

local function ShowLoadingHud(groupKey)
    if not ShouldShow() or not ShouldShowGroup(groupKey) then
        HideHud(huds[groupKey])
        return
    end

    activeFontGroupKey = groupKey

    local hud = EnsureHud(groupKey)
    if not hud then
        return
    end

    local settings = GetGroupSettings(groupKey)
    local layout = GetLayoutMetrics({}, settings.detailLevel, {}, {}, groupKey)
    local width = layout.hudWidth
    local height = math.max(layout.hudHeight, GetLineHeight(HEADER_HEIGHT_OFFSET) + GetLineHeight(-3) + (HUD_PADDING * 4), 120)

    hud.control:SetDimensions(width, height)
    ApplyHudBackground(hud)
    RenderWatermark(hud, {
        hudWidth = width,
        hudHeight = height,
        contentWidth = layout.contentWidth,
        tableViewportTop = layout.tableViewportTop,
        footerHeight = layout.footerHeight,
    })

    hud.header:SetFont(ResolveFont(HEADER_HEIGHT_OFFSET))
    hud.header:SetText(GetGroupTitle(groupKey))
    hud.header:ClearAnchors()
    hud.header:SetDimensions(layout.contentWidth, GetLineHeight(HEADER_HEIGHT_OFFSET))
    hud.header:SetAnchor(TOPLEFT, hud.control, TOPLEFT, HUD_PADDING, HUD_PADDING)
    hud.header:SetHidden(false)

    if hud.headerMask then
        hud.headerMask:SetHidden(true)
    end
    if hud.footerMask then
        hud.footerMask:SetHidden(true)
    end

    SetHudLoading(hud, true, layout)
    hud.control:SetHidden(false)
    ApplyHudPosition(hud)
end

local function EnsureFooterCounterLabel(hud, index)
    hud.footerCounters = hud.footerCounters or {}
    if hud.footerCounters[index] then
        return hud.footerCounters[index]
    end

    local label = CreateLabel(hud.footerCounterClip or hud.control, FOOTER_HEIGHT_OFFSET, { 1, 1, 1, 0.88 }, TEXT_ALIGN_LEFT)
    MoveControlAbove(label, DRAW_LEVEL + 8)
    hud.footerCounters[index] = label
    return label
end

local function EnsureWatermarkLabel(hud)
    if hud.watermark then
        return hud.watermark
    end

    local label = WINDOW_MANAGER:CreateControl(nil, hud.watermarkClip or hud.control, CT_LABEL)
    label:SetFont(ResolveWatermarkFont())
    label:SetColor(1, 1, 1, WATERMARK_ALPHA)
    label:SetVerticalAlignment(TEXT_ALIGN_TOP)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    MoveControlAbove(label, DRAW_LEVEL + 7)

    hud.watermark = label
    return label
end

local function GetWatermarkTextWidth(text)
    local width = 1
    for line in string.gmatch(tostring(text or "") .. "\n", "([^\n]*)\n") do
        width = math.max(width, math.ceil(string.len(line) * GetWatermarkFontSize() * 0.62))
    end

    return width
end

local function BuildWatermarkTextBlock(text, targetWidth, targetHeight)
    local segment = tostring(text or "")
    if segment == "" then
        return ""
    end

    local segmentWidth = math.max(GetWatermarkTextWidth(segment), 1)
    local lineHeight = GetWatermarkFontSize() + 6
    local approximateRows = math.max(math.ceil((targetHeight or 0) / math.max(lineHeight, 1)) + 2, 1)
    local repeatsPerRow = math.max(math.ceil((targetWidth or 0) / segmentWidth) + 2, 1)
    local maxRepeats = approximateRows * repeatsPerRow
    local parts = {}

    for index = 1, maxRepeats do
        parts[index] = segment
    end

    return table.concat(parts, " ")
end

local function HideWatermark(hud)
    if hud.watermarkClip then
        hud.watermarkClip:SetHidden(true)
    end

    if hud.watermark then
        hud.watermark:SetHidden(true)
    end
end

RenderWatermark = function(hud, layout)
    if not hud or not layout then
        return
    end

    local settings = GetGroupSettings(hud.group)
    if settings.showWatermark ~= true then
        HideWatermark(hud)
        return
    end

    local contentHeight = layout.hudHeight
    if hud.watermarkClip then
        hud.watermarkClip:ClearAnchors()
        hud.watermarkClip:SetDimensions(layout.hudWidth, contentHeight)
        hud.watermarkClip:SetAnchor(TOPLEFT, hud.control, TOPLEFT, 0, 0)
        hud.watermarkClip:SetHidden(false)
    end

    local watermarkText = GetWatermarkText()
    local label = EnsureWatermarkLabel(hud)
    label:SetFont(ResolveWatermarkFont())
    label:SetColor(1, 1, 1, WATERMARK_ALPHA)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetText(BuildWatermarkTextBlock(watermarkText, layout.hudWidth, contentHeight))
    label:ClearAnchors()
    label:SetDimensions(layout.hudWidth, contentHeight)
    label:SetAnchor(TOPLEFT, hud.watermarkClip or hud.control, TOPLEFT, 0, 0)
    label:SetHidden(false)
end

local function FormatDate(date)
    if not date or date == "" or date == 0 then
        return ""
    end

    local value = tostring(date)
    local year, month, day = string.match(value, "^(%d%d%d%d)%-(%d%d?)%-(%d%d?)$")
    if year and month and day then
        return string.format("%04d-%02d-%02d", tonumber(year), tonumber(month), tonumber(day))
    end

    month, day, year = string.match(value, "^(%d%d?)/(%d%d?)/(%d%d%d%d)$")
    if year and month and day then
        return string.format("%04d-%02d-%02d", tonumber(year), tonumber(month), tonumber(day))
    end

    year, month, day = string.match(value, "^(%d%d%d%d)(%d%d)(%d%d)$")
    if year and month and day then
        return string.format("%04d-%02d-%02d", tonumber(year), tonumber(month), tonumber(day))
    end

    return value
end

local function GetAdvancedDateText(status)
    if status and status.completed == true then
        local date = FormatDate(status.date)
        if date ~= "" then
            return date, true
        end
    end

    return "----/--/--", false
end

local function GetAggregateText(status)
    if not status or not status.aggregate then
        return ""
    end

    if (tonumber(status.total) or 0) <= 0 then
        return "-"
    end

    return string.format("%d/%d", tonumber(status.complete) or 0, tonumber(status.total) or 0)
end

local function BuildFooterCounters(rows)
    local normalComplete = 0
    local vetComplete = 0
    local hardModeComplete = 0
    local hardModeCounters = {
        hm1 = { label = NQOL.L("features.progress_dungeons.hm1_b2c1378"), complete = 0, total = 0 },
        hm2 = { label = NQOL.L("features.progress_dungeons.hm2_ce5b4ae"), complete = 0, total = 0 },
    }
    local speedComplete = 0
    local noDeathComplete = 0
    local triComplete = 0
    local triTotal = 0
    local extraComplete = 0
    local extraTotal = 0

    for _, row in ipairs(rows) do
        if row.statuses.normal and row.statuses.normal.completed then
            normalComplete = normalComplete + 1
        end
        if row.statuses.vet and row.statuses.vet.completed then
            vetComplete = vetComplete + 1
        end
        if row.statuses.hm and row.statuses.hm.completed then
            hardModeComplete = hardModeComplete + 1
        end
        if row.statuses.hm1 and row.statuses.hm1.id then
            hardModeCounters.hm1.total = hardModeCounters.hm1.total + 1
            if row.statuses.hm1.completed then
                hardModeCounters.hm1.complete = hardModeCounters.hm1.complete + 1
            end
        end
        if row.statuses.hm2 and row.statuses.hm2.id then
            hardModeCounters.hm2.total = hardModeCounters.hm2.total + 1
            if row.statuses.hm2.completed then
                hardModeCounters.hm2.complete = hardModeCounters.hm2.complete + 1
            end
        end
        if row.statuses.sr and row.statuses.sr.completed then
            speedComplete = speedComplete + 1
        end
        if row.statuses.nd and row.statuses.nd.completed then
            noDeathComplete = noDeathComplete + 1
        end
        if row.statuses.tri and row.statuses.tri.id then
            triTotal = triTotal + 1
            if row.statuses.tri.completed then
                triComplete = triComplete + 1
            end
        end
        extraComplete = extraComplete + (tonumber(row.extraComplete) or 0)
        extraTotal = extraTotal + (tonumber(row.extraTotal) or 0)
    end

    local function FormatCounter(label, completed, total)
        local totalValue = tonumber(total) or 0
        local complete = completed >= totalValue
        return {
            text = string.format("%s %d/%d", label, completed, totalValue),
            color = complete and { 0.2, 0.95, 0.35, 1 } or { 1, 0.22, 0.22, 1 },
            richText = string.format("%s%s %d/%d|r", complete and "|c33f05a" or "|cff3838", label, completed, totalValue),
        }
    end

    local function FormatUnavailableCounter(label)
        return {
            text = string.format("%s -", label),
            color = { 0.72, 0.72, 0.68, 0.9 },
            richText = string.format("|cb8b8ad%s -|r", label),
        }
    end

    local counters = {
        FormatCounter("N", normalComplete, #rows),
        FormatCounter("V", vetComplete, #rows),
        FormatCounter("HM", hardModeComplete, #rows),
    }

    if hardModeCounters.hm1.total > 0 then
        counters[#counters + 1] = FormatCounter(hardModeCounters.hm1.label, hardModeCounters.hm1.complete, hardModeCounters.hm1.total)
    end
    if hardModeCounters.hm2.total > 0 then
        counters[#counters + 1] = FormatCounter(hardModeCounters.hm2.label, hardModeCounters.hm2.complete, hardModeCounters.hm2.total)
    end

    counters[#counters + 1] = FormatCounter("SR", speedComplete, #rows)
    counters[#counters + 1] = FormatCounter("ND", noDeathComplete, #rows)
    if triTotal > 0 then
        counters[#counters + 1] = FormatCounter("TRI", triComplete, triTotal)
    end
    counters[#counters + 1] = extraTotal > 0 and FormatCounter("E", extraComplete, extraTotal) or FormatUnavailableCounter("E")

    return counters
end

BuildFooter = function(rows)
    local counters = BuildFooterCounters(rows)
    local parts = {}
    for index, counter in ipairs(counters) do
        parts[index] = counter.richText or counter.text or ""
    end
    return table.concat(parts, FOOTER_COUNTER_SEPARATOR)
end

RenderFooter = function(hud, rows, layout)
    local footerMetaText = GetFooterMetaText()
    local headerMetaText = GetHeaderMetaText()
    local counterClipWidth = layout.contentWidth

    hud.footerCounterClip:ClearAnchors()
    hud.footerCounterClip:SetDimensions(counterClipWidth, layout.footerTextHeight)
    hud.footerCounterClip:SetAnchor(BOTTOMLEFT, hud.control, BOTTOMLEFT, HUD_PADDING, -(HUD_PADDING + layout.footerTextHeight + FOOTER_LINE_GAP))
    hud.footerCounterClip:SetHidden(false)

    local label = EnsureFooterCounterLabel(hud, 1)
    label:SetFont(ResolveFont(FOOTER_HEIGHT_OFFSET))
    label:SetColor(1, 1, 1, 0.88)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetText(BuildFooter(rows))
    label:ClearAnchors()
    label:SetDimensions(counterClipWidth, layout.footerTextHeight)
    label:SetAnchor(TOPLEFT, hud.footerCounterClip, TOPLEFT, 0, 0)
    label:SetHidden(false)

    hud.footer:SetFont(ResolveFont(FOOTER_HEIGHT_OFFSET))
    hud.footer:SetColor(0.72, 0.72, 0.68, 0.9)
    hud.footer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    hud.footer:SetText(headerMetaText .. " · " .. footerMetaText)
    hud.footer:ClearAnchors()
    hud.footer:SetDimensions(layout.contentWidth, layout.footerTextHeight)
    hud.footer:SetAnchor(BOTTOMLEFT, hud.control, BOTTOMLEFT, HUD_PADDING, -HUD_PADDING)
    hud.footer:SetHidden(false)

    for index = 2, #(hud.footerCounters or {}) do
        hud.footerCounters[index]:SetHidden(true)
    end

    hud.footerDivider:ClearAnchors()
    hud.footerDivider:SetDimensions(layout.contentWidth, FOOTER_DIVIDER_HEIGHT)
    hud.footerDivider:SetAnchor(BOTTOMLEFT, hud.control, BOTTOMLEFT, HUD_PADDING, -(HUD_PADDING + (layout.footerTextHeight * 2) + FOOTER_LINE_GAP + FOOTER_DIVIDER_TEXT_GAP))
    hud.footerDivider:SetHidden(false)
end

local function ApplyFullRowFrame(rowControl, index, x, y, layout)
    rowControl.logicalIndex = index
    rowControl.clipTop = y
    rowControl.clipBottom = y + layout.rowHeight
    rowControl.container:ClearAnchors()
    rowControl.container:SetDimensions(layout.columnWidth, layout.rowHeight + ROW_GAP)
    rowControl.container:SetAnchor(TOPLEFT, rowControl.parent, TOPLEFT, x, y)
    rowControl.container:SetHidden(false)
end

local function ApplyFullDungeonRow(rowControl, renderRow, index, x, y, layout, visibleTrackedTypes)
    local row = renderRow.row
    local contentInsetX = FULL_ROW_CONTENT_INSET_X
    local contentInsetY = FULL_ROW_CONTENT_INSET_Y
    local primaryLineHeight = math.max(layout.rowHeight - contentInsetY, 1)
    local nameWidth = math.max(layout.nameColumnWidth - contentInsetX, 1)
    local iconStartX = layout.nameColumnWidth + 8 - contentInsetX

    ResetFullRowControl(rowControl, false)
    ApplyFullRowFrame(rowControl, index, x, y, layout)

    rowControl.content:ClearAnchors()
    rowControl.content:SetDimensions(math.max(layout.columnWidth - contentInsetX, 1), math.max(layout.rowHeight - contentInsetY, 1))
    rowControl.content:SetAnchor(TOPLEFT, rowControl.container, TOPLEFT, contentInsetX, contentInsetY)
    rowControl.content:SetHidden(false)

    rowControl.name:SetFont(ResolveFont(-3))
    rowControl.name:SetColor(1, 1, 1, 0.92)
    rowControl.name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    rowControl.name:SetText(row.name)
    rowControl.name:ClearAnchors()
    rowControl.name:SetDimensions(nameWidth, primaryLineHeight)
    rowControl.name:SetAnchor(TOPLEFT, rowControl.content, TOPLEFT, 0, 0)
    rowControl.name:SetHidden(false)

    for statusIndex, trackedType in ipairs(visibleTrackedTypes) do
        local status = row.statuses[trackedType.key]
        local label = rowControl.statusLabels[statusIndex]
        local icon = rowControl.icons[statusIndex]
        local columnX = iconStartX + ((statusIndex - 1) * layout.statusColumnWidth)

        if trackedType.aggregate then
            label:SetHidden(true)
            icon:SetHidden(true)
        elseif status and status.unavailable then
            label:SetFont(ResolveFont(-7))
            label:SetColor(0.72, 0.72, 0.68, 0.9)
            label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            label:ClearAnchors()
            label:SetDimensions(layout.statusColumnWidth, primaryLineHeight)
            label:SetAnchor(TOPLEFT, rowControl.content, TOPLEFT, columnX, 0)
            label:SetText(string.format("|cb8dbff%s:|r -", trackedType.label))
            label:SetHidden(false)
            icon:SetHidden(true)
        else
            local dateText, completed = GetAdvancedDateText(status)
            label:SetFont(ResolveFont(-7))
            label:SetColor(1, 1, 1, 1)
            label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            label:ClearAnchors()
            label:SetDimensions(layout.statusColumnWidth, primaryLineHeight)
            label:SetAnchor(TOPLEFT, rowControl.content, TOPLEFT, columnX, 0)
            if completed then
                label:SetText(string.format("|cb8dbff%s:|r |c33f05a%s|r", trackedType.label, dateText))
                icon:SetHidden(true)
            else
                label:SetText(string.format("|cb8dbff%s:|r", trackedType.label))
                AnchorCompletionIcon(icon, rowControl.content, columnX + EstimateTextWidth(trackedType.label .. ":", -7, 0.56) + 4, primaryLineHeight, false)
            end
            label:SetHidden(false)
        end
    end
end

local function ApplyFullAchievementRow(rowControl, renderRow, index, x, y, layout)
    local achievementId = renderRow.achievementId or (renderRow.achievement and renderRow.achievement.id)
    local row = renderRow.row
    row.fullAchievementData = row.fullAchievementData or {}
    local achievement = row.fullAchievementData[achievementId]
    if not achievement then
        achievement = {
            completed = IsAchievementIdComplete(achievementId),
            date = GetAchievementDate(achievementId),
            name = GetAchievementName(achievementId),
            description = GetAchievementDescription(achievementId),
        }
        row.fullAchievementData[achievementId] = achievement
    end
    local completed = achievement.completed
    local date = achievement.date
    local name = achievement.name
    local description = achievement.description
    local rowStartX = layout.nameColumnWidth + 8
    local contentLineHeight = math.max(layout.rowHeight - FULL_ROW_CONTENT_INSET_Y, 1)
    local contentX = rowStartX + EXTRA_BULLET_SIZE + EXTRA_BULLET_GAP
    local statusText = FormatDate(date)
    local statusWidth = completed and 0 or STATUS_ICON_SIZE
    local descriptionX = completed and contentX or (contentX + statusWidth + 4)

    ResetFullRowControl(rowControl, false)
    ApplyFullRowFrame(rowControl, index, x, y, layout)

    rowControl.content:ClearAnchors()
    rowControl.content:SetDimensions(layout.columnWidth, math.max(layout.rowHeight - FULL_ROW_CONTENT_INSET_Y, 1))
    rowControl.content:SetAnchor(TOPLEFT, rowControl.container, TOPLEFT, 0, FULL_ROW_CONTENT_INSET_Y)
    rowControl.content:SetHidden(false)

    rowControl.icons[1]:ClearAnchors()
    rowControl.icons[1]:SetTexture(BULLET_TEXTURE)
    rowControl.icons[1]:SetDimensions(EXTRA_BULLET_SIZE, EXTRA_BULLET_SIZE)
    rowControl.icons[1]:SetColor(0.72, 0.86, 1, 0.9)
    rowControl.icons[1]:SetAnchor(TOPLEFT, rowControl.content, TOPLEFT, rowStartX, ((contentLineHeight - EXTRA_BULLET_SIZE) / 2))
    rowControl.icons[1]:SetHidden(false)

    rowControl.text:SetFont(ResolveFont(-6))
    rowControl.text:SetColor(1, 1, 1, 0.82)
    rowControl.text:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    rowControl.text:ClearAnchors()
    if completed then
        rowControl.text:SetText(NQOL.L("features.progress_dungeons.c33f05a_d80ad69") .. statusText .. "|r " .. (name or "") .. " - " .. (description or ""))
        rowControl.text:SetDimensions(math.max(layout.columnWidth - contentX, 1), contentLineHeight)
        rowControl.text:SetAnchor(TOPLEFT, rowControl.content, TOPLEFT, contentX, 0)
    else
        AnchorCompletionIcon(rowControl.icons[2], rowControl.content, contentX, contentLineHeight, false)

        rowControl.text:SetText((name or "") .. " - " .. (description or ""))
        rowControl.text:SetDimensions(math.max(layout.columnWidth - descriptionX, 1), contentLineHeight)
        rowControl.text:SetAnchor(TOPLEFT, rowControl.content, TOPLEFT, descriptionX, 0)
    end
    rowControl.text:SetHidden(false)
end

RenderVisibleFullRows = function(hud)
    if not hud or not hud.fullVirtualRenderRows or not hud.fullVirtualLayout then
        return
    end

    activeFontGroupKey = hud.group or GROUP_BASE

    local renderRows = hud.fullVirtualRenderRows
    local layout = hud.fullVirtualLayout
    local visibleTrackedTypes = hud.fullVirtualVisibleTrackedTypes or {}
    local generation = hud.fullVirtualGeneration
    local totalRows = #renderRows
    if totalRows <= 0 then
        HideFullRows(hud, false)
        return
    end

    local rowSpan = layout.rowHeight + ROW_GAP
    local scrollTop = tonumber(hud.scrollOffset) or 0
    local scrollBottom = scrollTop + (tonumber(layout.tableViewportHeight) or 0)
    local firstIndex = math.ceil((scrollTop - layout.rowAreaTop) / rowSpan) + 1
    local lastIndex = math.floor((scrollBottom - layout.rowAreaTop - layout.rowHeight) / rowSpan) + 1
    firstIndex = Clamp(firstIndex, 1, totalRows)
    lastIndex = Clamp(lastIndex, 1, totalRows)
    if lastIndex < firstIndex then
        for _, rowControl in ipairs(hud.fullSummaryRows or {}) do
            HideFullRowControl(rowControl)
        end
        for _, rowControl in ipairs(hud.fullAchievementRows or {}) do
            HideFullRowControl(rowControl)
        end
        return
    end

    local summarySlotIndex = 1
    local achievementSlotIndex = 1
    for renderIndex = firstIndex, lastIndex do
        local renderRow = renderRows[renderIndex]
        if renderRow.kind ~= "spacer" then
            local y = layout.rowAreaTop + ((renderIndex - 1) * rowSpan)
            local viewportY = y - scrollTop
            if viewportY >= 0 and (viewportY + layout.rowHeight) <= layout.tableViewportHeight then
                if renderRow.kind == "achievement" then
                    local rowControl = EnsureFullAchievementRowControl(hud, achievementSlotIndex)
                    ApplyFullAchievementRow(rowControl, renderRow, renderIndex, 0, viewportY, layout)
                    if rowControl.renderGeneration ~= generation then
                        rowControl.renderGeneration = generation
                    end
                    achievementSlotIndex = achievementSlotIndex + 1
                else
                    local rowControl = EnsureFullSummaryRowControl(hud, summarySlotIndex)
                    ApplyFullDungeonRow(rowControl, renderRow, renderIndex, 0, viewportY, layout, visibleTrackedTypes)
                    if rowControl.renderGeneration ~= generation then
                        rowControl.renderGeneration = generation
                    end
                    summarySlotIndex = summarySlotIndex + 1
                end
            end
        end
    end

    for hiddenIndex = summarySlotIndex, #(hud.fullSummaryRows or {}) do
        HideFullRowControl(hud.fullSummaryRows[hiddenIndex])
    end
    for hiddenIndex = achievementSlotIndex, #(hud.fullAchievementRows or {}) do
        HideFullRowControl(hud.fullAchievementRows[hiddenIndex])
    end
end

-- Basic/Dates use viewport-sized row slots. Full has its own row pools below.
-- Controls persist in ESO, so unused cell types and per-row headings are never
-- allocated until needed; headings are shared by the rows in each column.
function StandardRows.Render(hud)
    local state = hud and hud.standardData
    if not state then return end
    local layout = state.layout
    local stride = layout.rowHeight + ROW_GAP
    local scrollTop = tonumber(hud.scrollOffset) or 0
    local scrollBottom = scrollTop + layout.tableViewportHeight
    local firstRow = math.max(0, math.ceil((scrollTop - layout.rowAreaTop) / stride))
    local lastRow = math.min(layout.rowsPerColumn - 1, math.floor((scrollBottom - layout.rowAreaTop - layout.rowHeight) / stride))
    if state.firstRow == firstRow and state.lastRow == lastRow then return end
    state.firstRow, state.lastRow = firstRow, lastRow

    for _, rowControl in ipairs(hud.rows) do HideRowControls(rowControl) end
    for _, label in ipairs(hud.standardHeaders or {}) do label:SetHidden(true) end
    hud.standardHeaders = hud.standardHeaders or {}
    local slot = 0
    for column = 0, layout.columns - 1 do
        local x = column * (layout.columnWidth + COLUMN_GAP)
        if firstRow == 0 and lastRow >= 0 and state.rows[column * layout.rowsPerColumn + 1] then
            for index, trackedType in ipairs(state.types) do
                local headerIndex = column * #state.types + index
                local label = hud.standardHeaders[headerIndex]
                if not label then
                    label = CreateLabel(hud.content, -7, { 0.72, 0.86, 1, 0.95 }, TEXT_ALIGN_CENTER)
                    hud.standardHeaders[headerIndex] = label
                end
                label:SetFont(ResolveFont(-7))
                label:SetText(trackedType.label)
                label:ClearAnchors()
                label:SetDimensions(layout.statusColumnWidth, layout.columnHeaderHeight)
                label:SetAnchor(TOPLEFT, hud.content, TOPLEFT, x + layout.nameColumnWidth + 8 + ((index - 1) * layout.statusColumnWidth), 0)
                label:SetHidden(false)
            end
        end
        for rowIndex = firstRow, lastRow do
            local renderRow = state.rows[column * layout.rowsPerColumn + rowIndex + 1]
            if renderRow then
                slot = slot + 1
                local rowControl = EnsureRowControl(hud, slot)
                local row = renderRow.row
                rowControl.container:ClearAnchors()
                rowControl.container:SetDimensions(layout.columnWidth, layout.rowHeight)
                rowControl.container:SetAnchor(TOPLEFT, hud.content, TOPLEFT, x, layout.rowAreaTop + rowIndex * stride)
                rowControl.container:SetHidden(false)
                rowControl.name:SetFont(ResolveFont(-3))
                rowControl.name:SetText(row.name)
                rowControl.name:ClearAnchors()
                rowControl.name:SetDimensions(layout.nameColumnWidth, layout.rowHeight)
                rowControl.name:SetAnchor(TOPLEFT, rowControl.container, TOPLEFT, 0, 0)
                rowControl.name:SetHidden(false)
                for index, trackedType in ipairs(state.types) do
                    local status = row.statuses[trackedType.key]
                    local text, red, green, blue
                    local completed = status and status.completed or false
                    if status and status.unavailable then
                        text, red, green, blue = "-", 0.72, 0.72, 0.68
                    elseif trackedType.aggregate then
                        text = GetAggregateText(status)
                        if (tonumber(status and status.total) or 0) <= 0 then
                            red, green, blue = 0.72, 0.72, 0.68
                        elseif completed then
                            red, green, blue = 0.33, 1, 0.43
                        else
                            red, green, blue = 1, 0.22, 0.22
                        end
                    elseif state.detailLevel == DETAIL_ADVANCED then
                        local hasDate
                        text, hasDate = GetAdvancedDateText(status)
                        if hasDate then
                            red, green, blue = 0.33, 1, 0.43
                        else
                            text, completed = nil, false
                        end
                    end
                    local columnX = layout.nameColumnWidth + 8 + ((index - 1) * layout.statusColumnWidth)
                    if text then
                        local label = rowControl.dates[index]
                        if not label then
                            label = CreateLabel(rowControl.container, -7, { 0.72, 0.86, 1, 0.85 }, TEXT_ALIGN_CENTER)
                            rowControl.dates[index] = label
                        end
                        label:SetFont(ResolveFont(-7))
                        label:SetColor(red, green, blue, 1)
                        label:SetText(text)
                        label:ClearAnchors()
                        label:SetDimensions(layout.statusColumnWidth, layout.rowHeight)
                        label:SetAnchor(TOPLEFT, rowControl.container, TOPLEFT, columnX, 0)
                        label:SetHidden(false)
                    else
                        local icon = rowControl.icons[index]
                        if not icon then
                            icon = CreateIcon(rowControl.container)
                            rowControl.icons[index] = icon
                        end
                        AnchorCompletionIcon(icon, rowControl.container, columnX + ((layout.statusColumnWidth - STATUS_ICON_SIZE) / 2), layout.rowHeight, completed)
                    end
                end
            end
        end
    end
end

local function RenderHud(groupKey, generation)
    if not ShouldShow() or not ShouldShowGroup(groupKey) then
        HideHud(huds[groupKey])
        return
    end

    activeFontGroupKey = groupKey

    local hud = EnsureHud(groupKey)
    if not hud then
        return
    end

    local settings = GetGroupSettings(groupKey)
    local detailLevel = settings.detailLevel
    local rows = GetRowsForGroup(groupKey, detailLevel)
    local renderRows = BuildRenderableRows(rows, detailLevel)
    local visibleTrackedTypes = GetVisibleTrackedTypes(rows, detailLevel)
    local layout = GetLayoutMetrics(renderRows, detailLevel, rows, visibleTrackedTypes, groupKey)

    hud.control:SetDimensions(layout.hudWidth, layout.hudHeight)
    hud.maxScrollOffset = layout.maxScrollOffset
    hud.scrollOffset = Clamp(tonumber(hud.scrollOffset) or 0, 0, hud.maxScrollOffset)
    ApplyHudBackground(hud)
    RenderWatermark(hud, layout)

    hud.headerMask:ClearAnchors()
    hud.headerMask:SetDimensions(layout.hudWidth, HUD_PADDING + layout.tableViewportTop)
    hud.headerMask:SetAnchor(TOPLEFT, hud.control, TOPLEFT, 0, 0)
    hud.headerMask:SetHidden(false)

    hud.footerMask:ClearAnchors()
    hud.footerMask:SetDimensions(layout.hudWidth, HUD_PADDING + layout.footerHeight)
    hud.footerMask:SetAnchor(BOTTOMLEFT, hud.control, BOTTOMLEFT, 0, 0)
    hud.footerMask:SetHidden(false)

    hud.header:SetFont(ResolveFont(HEADER_HEIGHT_OFFSET))
    hud.header:SetText(GetGroupTitle(groupKey))
    hud.header:ClearAnchors()
    hud.header:SetDimensions(layout.contentWidth, layout.headerHeight)
    hud.header:SetAnchor(TOPLEFT, hud.control, TOPLEFT, HUD_PADDING, HUD_PADDING)
    hud.header:SetHidden(false)

    hud.viewport:ClearAnchors()
    hud.viewport:SetDimensions(layout.contentWidth, layout.tableViewportHeight)
    hud.viewport:SetAnchor(TOPLEFT, hud.control, TOPLEFT, HUD_PADDING, HUD_PADDING + layout.tableViewportTop)
    hud.viewport:SetHidden(false)

    hud.renderGeneration = generation
    hud.content:SetDimensions(layout.contentWidth, layout.tableContentHeight)

    if detailLevel == DETAIL_FULL then
        HideStandardRows(hud)
        hud.fullVirtualRenderRows = renderRows
        hud.fullVirtualLayout = layout
        hud.fullVirtualVisibleTrackedTypes = visibleTrackedTypes
        hud.fullVirtualGeneration = generation
        if not hud.hasRenderedContent then
            RestoreFullScrollOffset(hud, layout)
        end
        ApplyScrollOffset(hud)
        FinishHudRender(hud, rows, layout)
        return
    end

    HideFullRows(hud)
    hud.standardData = { rows = renderRows, layout = layout, types = visibleTrackedTypes, detailLevel = detailLevel }
    SetHudLoading(hud, false, layout)
    ApplyScrollOffset(hud)

    FinishHudRender(hud, rows, layout)
end

local function HideAllHuds()
    HideHud(huds[GROUP_BASE])
    HideHud(huds[GROUP_DLC])
end

Refresh = function()
    refreshGeneration = refreshGeneration + 1
    local generation = refreshGeneration
    if not ShouldShow() then
        if huds[GROUP_BASE] or huds[GROUP_DLC] then
            HideAllHuds()
        end
        return
    end

    local groupKey = settingsPanelGroup
    local detailLevel = GetGroupSettings(groupKey).detailLevel
    local inactiveGroupKey = groupKey == GROUP_BASE and GROUP_DLC or GROUP_BASE
    HideHud(huds[inactiveGroupKey])

    local function RenderWithRows(renderGeneration)
        if renderGeneration ~= refreshGeneration or settingsPanelGroup ~= groupKey then
            return
        end

        RenderHud(groupKey, renderGeneration)
    end

    if dungeonRowsByDetailLevel[detailLevel] then
        RenderWithRows(generation)
    else
        if zo_callLater then
            if huds[groupKey] then
                huds[groupKey].hasRenderedContent = false
            end
            ShowLoadingHud(groupKey)
            BuildDungeonRowsAsync(generation, RenderWithRows, detailLevel)
        else
            dungeonRowsByDetailLevel[detailLevel] = BuildDungeonRows(detailLevel)
            RenderWithRows(generation)
        end
    end
end

local function RegisterEvents()
    if eventsRegistered or not EVENT_MANAGER then
        return
    end

    eventsRegistered = true
    if EVENT_SCREEN_RESIZED then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_ScreenResized", EVENT_SCREEN_RESIZED, Refresh)
    end
end

local function UnregisterEvents()
    if not eventsRegistered or not EVENT_MANAGER then
        return
    end

    eventsRegistered = false
    if EVENT_SCREEN_RESIZED then
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_ScreenResized", EVENT_SCREEN_RESIZED)
    end
end

function ProgressDungeons.InitializeSavedVariables()
    savedVariables = NQOL.Settings.NewAccountWide(defaults)
    GetSettings()
end

function ProgressDungeons.Initialize()
    if initialized then
        return
    end

    initialized = true
end

function ProgressDungeons.SetSettingsPanelVisible(groupKey)
    if groupKey ~= GROUP_BASE and groupKey ~= GROUP_DLC then
        groupKey = nil
    end

    if settingsPanelGroup == groupKey then
        return
    end

    settingsPanelGroup = groupKey
    if not ShouldShow() then
        UnregisterEvents()
        refreshGeneration = refreshGeneration + 1
        HideAllHuds()
        dungeonRowsByDetailLevel = {}
        fontStringCache = {}
    else
        RegisterEvents()
        Refresh()
    end
end

function ProgressDungeons.GetBaseGroupKey() return GROUP_BASE end
function ProgressDungeons.GetDlcGroupKey() return GROUP_DLC end

function ProgressDungeons.GetBaseDungeonsDetailLevel() return GetSettings().baseDetailLevel end
function ProgressDungeons.SetBaseDungeonsDetailLevel(value) GetSettings().baseDetailLevel = value; Refresh() end
function ProgressDungeons.GetDlcDungeonsDetailLevel() return GetSettings().dlcDetailLevel end
function ProgressDungeons.SetDlcDungeonsDetailLevel(value) GetSettings().dlcDetailLevel = value; Refresh() end
function ProgressDungeons.GetDungeonsDetailLevelChoices() local choices = {}; for index, value in ipairs(DETAIL_LEVELS) do choices[index] = value.key end return choices end
function ProgressDungeons.GetDungeonsDetailLevelChoiceNames() local names = {}; for index, value in ipairs(DETAIL_LEVELS) do names[index] = value.name end return names end

function ProgressDungeons.GetBaseDungeonsShowWatermark() return GetSettings().baseShowWatermark end
function ProgressDungeons.GetBaseDungeonsShowWatermarkDefault() return defaults.progress.dungeons.baseShowWatermark end
function ProgressDungeons.SetBaseDungeonsShowWatermark(value) GetSettings().baseShowWatermark = value == true; Refresh() end
function ProgressDungeons.GetDlcDungeonsShowWatermark() return GetSettings().dlcShowWatermark end
function ProgressDungeons.GetDlcDungeonsShowWatermarkDefault() return defaults.progress.dungeons.dlcShowWatermark end
function ProgressDungeons.SetDlcDungeonsShowWatermark(value) GetSettings().dlcShowWatermark = value == true; Refresh() end

function ProgressDungeons.GetBaseDungeonsHorizontalPosition() return GetSettings().baseHorizontalPosition end
function ProgressDungeons.SetBaseDungeonsHorizontalPosition(value) GetSettings().baseHorizontalPosition = Clamp(value, 0, 100); ApplyHudPosition(huds[GROUP_BASE]) end
function ProgressDungeons.GetBaseDungeonsVerticalPosition() return GetSettings().baseVerticalPosition end
function ProgressDungeons.SetBaseDungeonsVerticalPosition(value) GetSettings().baseVerticalPosition = Clamp(value, 0, 100); ApplyHudPosition(huds[GROUP_BASE]) end
function ProgressDungeons.GetDlcDungeonsHorizontalPosition() return GetSettings().dlcHorizontalPosition end
function ProgressDungeons.SetDlcDungeonsHorizontalPosition(value) GetSettings().dlcHorizontalPosition = Clamp(value, 0, 100); ApplyHudPosition(huds[GROUP_DLC]) end
function ProgressDungeons.GetDlcDungeonsVerticalPosition() return GetSettings().dlcVerticalPosition end
function ProgressDungeons.SetDlcDungeonsVerticalPosition(value) GetSettings().dlcVerticalPosition = Clamp(value, 0, 100); ApplyHudPosition(huds[GROUP_DLC]) end

function ProgressDungeons.GetDungeonsFontChoices() return NQOL.Util.GetFontChoices() end
function ProgressDungeons.GetDungeonsFontChoiceNames() return NQOL.Util.GetFontChoiceNames() end
function ProgressDungeons.GetBaseDungeonsFont() return GetSettings().baseFont end
function ProgressDungeons.SetBaseDungeonsFont(value) if not NQOL.Util.IsFontChoice(value) then value = NQOL.Util.GetDefaultFont() end; GetSettings().baseFont = value; fontStringCache = {}; Refresh() end
function ProgressDungeons.GetDlcDungeonsFont() return GetSettings().dlcFont end
function ProgressDungeons.SetDlcDungeonsFont(value) if not NQOL.Util.IsFontChoice(value) then value = NQOL.Util.GetDefaultFont() end; GetSettings().dlcFont = value; fontStringCache = {}; Refresh() end
function ProgressDungeons.GetBaseDungeonsFontSize() return GetSettings().baseFontSize end
function ProgressDungeons.SetBaseDungeonsFontSize(value) GetSettings().baseFontSize = Clamp(Round(value), FONT_SIZE_MIN, FONT_SIZE_MAX); fontStringCache = {}; Refresh() end
function ProgressDungeons.GetDlcDungeonsFontSize() return GetSettings().dlcFontSize end
function ProgressDungeons.SetDlcDungeonsFontSize(value) GetSettings().dlcFontSize = Clamp(Round(value), FONT_SIZE_MIN, FONT_SIZE_MAX); fontStringCache = {}; Refresh() end
function ProgressDungeons.GetDungeonsFontSizeMin() return FONT_SIZE_MIN end
function ProgressDungeons.GetDungeonsFontSizeMax() return FONT_SIZE_MAX end
function ProgressDungeons.GetBaseDungeonsBackgroundOpacity() return GetSettings().baseBackgroundOpacity end
function ProgressDungeons.GetBaseDungeonsBackgroundOpacityDefault() return defaults.progress.dungeons.baseBackgroundOpacity end
function ProgressDungeons.SetBaseDungeonsBackgroundOpacity(value) GetSettings().baseBackgroundOpacity = Clamp(Round(value), BACKGROUND_OPACITY_MIN, BACKGROUND_OPACITY_MAX); ApplyHudBackground(huds[GROUP_BASE]) end
function ProgressDungeons.GetDlcDungeonsBackgroundOpacity() return GetSettings().dlcBackgroundOpacity end
function ProgressDungeons.GetDlcDungeonsBackgroundOpacityDefault() return defaults.progress.dungeons.dlcBackgroundOpacity end
function ProgressDungeons.SetDlcDungeonsBackgroundOpacity(value) GetSettings().dlcBackgroundOpacity = Clamp(Round(value), BACKGROUND_OPACITY_MIN, BACKGROUND_OPACITY_MAX); ApplyHudBackground(huds[GROUP_DLC]) end
function ProgressDungeons.GetDungeonsBackgroundOpacityMin() return BACKGROUND_OPACITY_MIN end
function ProgressDungeons.GetDungeonsBackgroundOpacityMax() return BACKGROUND_OPACITY_MAX end

function ProgressDungeons.GetDungeonsDetailLevelLabel() return NQOL.L("features.progress_dungeons.dungeons_detail_level_label") end
function ProgressDungeons.GetDungeonsDetailLevelTooltip() return NQOL.L("features.progress_dungeons.dungeons_detail_level_tooltip") end
function ProgressDungeons.GetDungeonsShowWatermarkLabel() return NQOL.L("features.progress_dungeons.dungeons_show_watermark_label") end
function ProgressDungeons.GetDungeonsShowWatermarkTooltip() return NQOL.L("features.progress_dungeons.dungeons_show_watermark_tooltip") end
function ProgressDungeons.GetDungeonsHorizontalPositionLabel() return NQOL.L("features.progress_dungeons.dungeons_horizontal_position_label") end
function ProgressDungeons.GetBaseDungeonsHorizontalPositionTooltip() return NQOL.L("features.progress_dungeons.base_dungeons_horizontal_position_tooltip") end
function ProgressDungeons.GetDlcDungeonsHorizontalPositionTooltip() return NQOL.L("features.progress_dungeons.dlc_dungeons_horizontal_position_tooltip") end
function ProgressDungeons.GetDungeonsVerticalPositionLabel() return NQOL.L("features.progress_dungeons.dungeons_vertical_position_label") end
function ProgressDungeons.GetBaseDungeonsVerticalPositionTooltip() return NQOL.L("features.progress_dungeons.base_dungeons_vertical_position_tooltip") end
function ProgressDungeons.GetDlcDungeonsVerticalPositionTooltip() return NQOL.L("features.progress_dungeons.dlc_dungeons_vertical_position_tooltip") end
function ProgressDungeons.GetDungeonsFontLabel() return NQOL.L("features.progress_dungeons.dungeons_font_label") end
function ProgressDungeons.GetDungeonsFontTooltip() return NQOL.L("features.progress_dungeons.dungeons_font_tooltip") end
function ProgressDungeons.GetDungeonsFontSizeLabel() return NQOL.L("features.progress_dungeons.dungeons_font_size_label") end
function ProgressDungeons.GetDungeonsFontSizeTooltip() return NQOL.L("features.progress_dungeons.dungeons_font_size_tooltip") end
function ProgressDungeons.GetDungeonsBackgroundOpacityLabel() return NQOL.L("features.progress_dungeons.dungeons_background_opacity_label") end
function ProgressDungeons.GetDungeonsBackgroundOpacityTooltip() return NQOL.L("features.progress_dungeons.dungeons_background_opacity_tooltip") end

NQOL.Features.ProgressDungeons = ProgressDungeons
