NQOL = NQOL or {}
NQOL.Features = NQOL.Features or {}

local PlayerBars = NQOL.Features.PlayerBars
local Shared = PlayerBars.Shared
local C = PlayerBars.Constants
local Shadow = PlayerBars.Shadow
local defaults = Shared.defaults
local Clamp = NQOL.Util.Clamp
local Round = NQOL.Util.Round
local IsGameplaySceneShowing = Shared.IsGameplaySceneShowing
local CreateRootControl = Shared.CreateRootControl
local CreateClassicResourceWidget = Shared.CreateClassicResourceWidget
local CreateCompanionNameLabel = Shared.CreateCompanionNameLabel
local MoveAboveHud = Shared.MoveAboveHud
local ApplyRootPosition = Shared.ApplyRootPosition
local GetGroupLabelFont = Shared.GetGroupLabelFont
local FormatCurrentValue = Shared.FormatCurrentValue
local GetScreenWidth = Shared.GetScreenWidth
local GetScreenHeight = Shared.GetScreenHeight
local SetFrameVisibilityImmediate = Shared.SetFrameVisibilityImmediate
local SetFrameCombatVisibility = Shared.SetFrameCombatVisibility
local runtimeActive = false

function PlayerBars.Group.ShouldShowForCurrentScene()
    if IsGameplaySceneShowing() then
        return true
    end

    return PlayerBars.Group.settingsPanelVisible and PlayerBars.Group.GetSettings().showInSettings == true
end

function PlayerBars.Group.IsPreviewVisible()
    return PlayerBars.Group.settingsPanelVisible and PlayerBars.Group.GetSettings().showInSettings == true
end

function PlayerBars.Group.IsRuntimeActive()
    return runtimeActive
end

function PlayerBars.Group.RefreshRuntimeState()
    local wasActive = runtimeActive
    runtimeActive = PlayerBars.Group.GetSettings().showNqolGroupFrame == true or PlayerBars.Group.IsPreviewVisible()
    if wasActive and not runtimeActive then
        PlayerBars.Group.HideFrame()
        PlayerBars.Group.ClearRuntimeRows()
    end
    if PlayerBars.RefreshEventRegistrations then
        PlayerBars.RefreshEventRegistrations()
    end
    return runtimeActive
end

local function GetGroupSizeValue()
    if GetGroupSize then
        return tonumber(GetGroupSize()) or 0
    end

    return 0
end

local function GetGroupUnitTag(index)
    if GetGroupUnitTagByIndex then
        return GetGroupUnitTagByIndex(index)
    end

    return "group" .. tostring(index)
end

local function GetGroupRoleKey(unitTag)
    local role = GetGroupMemberSelectedRole and GetGroupMemberSelectedRole(unitTag) or nil
    if role == LFG_ROLE_TANK then
        return "tank"
    elseif role == LFG_ROLE_HEAL then
        return "heal"
    end

    return PlayerBars.Group.FALLBACK_ROLE
end

local function GetGroupRoleColor(settings, roleKey)
    local roleColors = settings.roleColors
    local defaultRoleColors = defaults.ui.customFrames.groupFrame.roleColors
    local value = roleColors and roleColors[roleKey]
    if not PlayerBars.Group.IsColorTable(value) then
        value = defaultRoleColors[roleKey] or defaultRoleColors[PlayerBars.Group.FALLBACK_ROLE]
    end

    return value.r, value.g, value.b, value.a or 1
end

local function CreateGroupRow(parent)
    local row = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)

    row.leaderIcon = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    row.leaderIcon:SetTexture(PlayerBars.Group.LEADER_ICON)
    row.leaderIcon:SetDimensions(PlayerBars.Group.ICON_SIZE, PlayerBars.Group.ICON_SIZE)
    row.leaderIcon:SetAnchor(RIGHT, row, LEFT, -PlayerBars.Group.ICON_GAP, 0)
    row.leaderIcon:SetDrawLevel(C.DRAW_LEVEL + 2)

    row.statusIcon = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    row.statusIcon:SetDimensions(PlayerBars.Group.ICON_SIZE, PlayerBars.Group.ICON_SIZE)
    row.statusIcon:SetAnchor(RIGHT, row, LEFT, -PlayerBars.Group.ICON_GAP, 0)
    row.statusIcon:SetDrawLevel(C.DRAW_LEVEL + 2)

    row.deathCounterIcon = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    row.deathCounterIcon:SetTexture(PlayerBars.Group.DEATH_COUNTER_ICON)
    row.deathCounterIcon:SetDimensions(PlayerBars.Group.ICON_SIZE, PlayerBars.Group.ICON_SIZE)
    row.deathCounterIcon:SetDrawLevel(C.DRAW_LEVEL + 2)

    row.deathCounterLabel = CreateCompanionNameLabel(row, GetGroupLabelFont())
    row.deathCounterLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    row.deathCounterLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    row.resurrectPendingIcon = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    row.resurrectPendingIcon:SetTexture(PlayerBars.Group.RESURRECT_PENDING_ICON)
    row.resurrectPendingIcon:SetColor(0.24, 1, 0.34, 1)
    row.resurrectPendingIcon:SetHidden(true)
    row.resurrectPendingIcon:SetDrawLevel(C.DRAW_LEVEL + 5)

    row.nameLabel = CreateCompanionNameLabel(row, GetGroupLabelFont())
    row.nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    row.nameLabel:SetAnchor(LEFT, row.statusIcon, RIGHT, PlayerBars.Group.ICON_GAP, 0)

    row.widget = CreateClassicResourceWidget(row, C.RESOURCE_HEALTH)
    row.widget:SetAnchorFill(row)

    MoveAboveHud(row)
    MoveAboveHud(row.leaderIcon)
    MoveAboveHud(row.statusIcon)
    MoveAboveHud(row.deathCounterIcon)
    MoveAboveHud(row.deathCounterLabel)
    MoveAboveHud(row.resurrectPendingIcon)
    MoveAboveHud(row.nameLabel)
    return row
end

function PlayerBars.Group.EnsureControls()
    if PlayerBars.Group.root or not WINDOW_MANAGER or not GuiRoot then
        return PlayerBars.Group.root ~= nil
    end

    PlayerBars.Group.root = CreateRootControl(PlayerBars.Group.ROOT_CONTROL_NAME)
    PlayerBars.Group.rows = {}
    for index = 1, PlayerBars.Group.MAX_ROWS do
        PlayerBars.Group.rows[index] = CreateGroupRow(PlayerBars.Group.root)
    end

    return true
end

function PlayerBars.Group.HideFrame()
    if PlayerBars.Group.root then
        SetFrameVisibilityImmediate(PlayerBars.Group.root, false)
    end

    if PlayerBars.Group.StopAllResurrectingMonitors then
        PlayerBars.Group.StopAllResurrectingMonitors(true)
    end
end

PlayerBars.Group.deathCounts = {}
PlayerBars.Group.deathStates = {}
PlayerBars.Group.companionNameCache = {}
PlayerBars.Group.supportRangeCache = {}
PlayerBars.Group.dataRows = {}
PlayerBars.Group.rowByUnitTag = {}
PlayerBars.Group.dataByUnitTag = {}
PlayerBars.Group.pendingPowerUpdates = {}
PlayerBars.Group.pendingPowerUpdatePool = {}
PlayerBars.Group.resurrectingMonitorUnitTags = {}
PlayerBars.Group.lastGroupSize = 0

local ApplyGroupRowStatus
local ApplyGroupRowValue
local ApplyGroupRowRangeStyle

local PREVIEW_GROUP_ROWS = {
    { playerId = "TankID01", customNameId = "@skinnycheeks", characterName = "Tank Character 1", roleKey = "tank", classId = 1, targetMarkerType = TARGET_MARKER_TYPE_ONE, championPoints = 2410, companionName = "Bastian Hallix", current = 46605, maximum = 50000, deathCount = 1 },
    { playerId = "TankID02", customNameId = "@LokiClermeil", characterName = "Tank Character 2", roleKey = "tank", classId = 5, championPoints = 1895, companionName = "Isobel Veloise", current = 43712, maximum = 50000 },
    { playerId = "HealerID01", customNameId = "@LikoXie", characterName = "Healer Character 1", roleKey = "heal", classId = 6, targetMarkerType = TARGET_MARKER_TYPE_FIVE, championPoints = 2217, companionName = "Ember", current = 33152, maximum = 37500, deathCount = 2, isBeingResurrected = true },
    { playerId = "HealerID02", customNameId = "@WarfireX", characterName = "Healer Character 2", roleKey = "heal", classId = 4, championPoints = 1764, companionName = "Mirri Elendis", current = 30348, maximum = 37500 },
    { playerId = "DamageID01", customNameId = "@Alcast", characterName = "Damage Character 1", roleKey = "dps", classId = 2, targetMarkerType = TARGET_MARKER_TYPE_EIGHT, championPoints = 3600, companionName = "Sharp-as-Night", current = 26560, maximum = 30000 },
    { playerId = "DamageID02", customNameId = "@andy.s", characterName = "Damage Character 2", roleKey = "dps", classId = 3, championPoints = 2142, companionName = "Azandar al-Cybiades", current = 25445, maximum = 30000 },
    { playerId = "DamageID03", customNameId = "@PK44", characterName = "Damage Character 3", roleKey = "dps", classId = 117, championPoints = 1428, companionName = "Tanlorin", current = 28380, maximum = 30000, deathCount = 4, hasResurrectPending = true },
    { playerId = "DamageID04", customNameId = "@Wheel5", characterName = "Damage Character 4", roleKey = "dps", classId = 1, championPoints = 980, companionName = "Zerith-var", current = 27240, maximum = 30000, inSupportRange = false },
    { playerId = "DamageID05", customNameId = "@m00nyONE", characterName = "Damage Character 5", roleKey = "dps", classId = 2, championPoints = 1950, companionName = "Bastian Hallix", current = 29325, maximum = 30000 },
    { playerId = "DamageID06", customNameId = "@seadotarley", characterName = "Damage Character 6", roleKey = "dps", classId = 3, championPoints = 1672, companionName = "Isobel Veloise", current = 26168, maximum = 30000 },
    { playerId = "DamageID07", customNameId = "@NefasQS", characterName = "Damage Character 7", roleKey = "dps", classId = 4, championPoints = 2391, companionName = "Ember", current = 27960, maximum = 30000 },
    { playerId = "DamageID08", customNameId = "@Solinur", characterName = "Damage Character 8", roleKey = "dps", classId = 5, championPoints = 1264, companionName = "Mirri Elendis", current = 27312, maximum = 30000 },
}

function PlayerBars.Group.IsLibCustomNamesAvailable()
    local library = _G.LibCustomNames
    return type(library) == "table" and type(library.Get) == "function"
end

local function GetCustomGroupName(displayName, colored)
    if not displayName or displayName == "" or not PlayerBars.Group.IsLibCustomNamesAvailable() then
        return nil
    end

    local name = _G.LibCustomNames.Get(displayName, colored)
    return type(name) == "string" and name ~= "" and name or nil
end

local function FormatGroupPlayerId(displayName)
    if not displayName or displayName == "" then
        return nil
    end

    if ZO_FormatUserFacingDisplayName then
        displayName = ZO_FormatUserFacingDisplayName(displayName)
    end

    return displayName
end

function PlayerBars.Group.NormalizeCounterName(name)
    if not name or name == "" then
        return nil
    end

    if zo_strformat then
        name = zo_strformat("<<1>>", name)
    end

    if ZO_FormatUserFacingDisplayName then
        name = ZO_FormatUserFacingDisplayName(name)
    end

    return name ~= "" and name or nil
end

function PlayerBars.Group.AddDeathCounterKey(keys, key)
    if not key or key == "" then
        return
    end

    if not keys.seen[key] then
        keys.seen[key] = true
        keys[#keys + 1] = key
    end

    local normalized = PlayerBars.Group.NormalizeCounterName(key)
    if normalized and not keys.seen[normalized] then
        keys.seen[normalized] = true
        keys[#keys + 1] = normalized
    end
end

function PlayerBars.Group.GetCounterKeysForNames(displayName, characterName)
    local keys = { seen = {} }
    PlayerBars.Group.AddDeathCounterKey(keys, displayName)
    PlayerBars.Group.AddDeathCounterKey(keys, FormatGroupPlayerId(displayName))
    PlayerBars.Group.AddDeathCounterKey(keys, characterName)
    keys.seen = nil
    return #keys > 0 and keys or nil
end

function PlayerBars.Group.GetDeathCounterKeys(unitTag)
    return PlayerBars.Group.GetCounterKeysForNames(
        unitTag and GetUnitDisplayName and GetUnitDisplayName(unitTag) or nil,
        unitTag and GetUnitName and GetUnitName(unitTag) or nil
    )
end

function PlayerBars.Group.GetDeathCounterKey(unitTag)
    local keys = PlayerBars.Group.GetDeathCounterKeys(unitTag)
    return keys and keys[1] or nil
end

function PlayerBars.Group.ClearDeathCounts()
    PlayerBars.Group.deathCounts = {}
    PlayerBars.Group.deathStates = {}
end

function PlayerBars.Group.ClearCompanionNameCache()
    PlayerBars.Group.companionNameCache = {}
end

function PlayerBars.Group.ClearSupportRangeCache()
    PlayerBars.Group.supportRangeCache = {}
end

function PlayerBars.Group.ClearRuntimeRows()
    if PlayerBars.Group.StopAllResurrectingMonitors then
        PlayerBars.Group.StopAllResurrectingMonitors(true)
    end
    PlayerBars.Group.dataRows = PlayerBars.Group.dataRows or {}
    for index = 1, #PlayerBars.Group.dataRows do
        PlayerBars.Group.dataRows[index] = nil
    end
    PlayerBars.Group.rowByUnitTag = {}
    PlayerBars.Group.dataByUnitTag = {}
    local pending = PlayerBars.Group.pendingPowerUpdates or {}
    local pool = PlayerBars.Group.pendingPowerUpdatePool or {}
    PlayerBars.Group.pendingPowerUpdates = pending
    PlayerBars.Group.pendingPowerUpdatePool = pool
    for unitTag, data in pairs(pending) do
        pending[unitTag] = nil
        data.current = nil
        data.maximum = nil
        data.effectiveMaximum = nil
        pool[#pool + 1] = data
    end
    PlayerBars.Group.powerUpdateQueued = false
    if EVENT_MANAGER and EVENT_MANAGER.UnregisterForUpdate then
        EVENT_MANAGER:UnregisterForUpdate(PlayerBars.Group.EVENT_NAMESPACE .. "_PowerFlush")
    end
end

function PlayerBars.Group.ResetSmoothAnimations()
    if not PlayerBars.Smooth or not PlayerBars.Group.rows then
        return
    end

    for index = 1, #PlayerBars.Group.rows do
        local row = PlayerBars.Group.rows[index]
        if row and row.widget then
            PlayerBars.Smooth.Reset(row.widget, C.RESOURCE_HEALTH)
            PlayerBars.Smooth.Reset(row.widget, C.PLAYER_SHIELD_SMOOTH_KEY)
            row.widget.nqolShieldSmoothInitialized = nil
        end
    end
end

function PlayerBars.Group.GetSupportRange(unitTag, exists, fallback)
    if not exists then
        return fallback ~= false
    end

    local cache = PlayerBars.Group.supportRangeCache
    if cache and cache[unitTag] ~= nil then
        return cache[unitTag] == true
    end

    local inRange = (not IsUnitInGroupSupportRange) or IsUnitInGroupSupportRange(unitTag) == true
    PlayerBars.Group.supportRangeCache[unitTag] = inRange
    return inRange
end

function PlayerBars.Group.RemoveDeathCountKey(key)
    if not key or key == "" or not PlayerBars.Group.deathCounts then
        return
    end

    PlayerBars.Group.deathCounts[key] = nil
    PlayerBars.Group.deathStates[key] = nil
    local formatted = FormatGroupPlayerId(key)
    if formatted then
        PlayerBars.Group.deathCounts[formatted] = nil
        PlayerBars.Group.deathStates[formatted] = nil
    end
    local normalized = PlayerBars.Group.NormalizeCounterName(key)
    if normalized then
        PlayerBars.Group.deathCounts[normalized] = nil
        PlayerBars.Group.deathStates[normalized] = nil
    end
end

function PlayerBars.Group.GetDeathCountForKeys(keys)
    local deathCount = 0
    if not keys then
        return deathCount
    end

    local counts = PlayerBars.Group.deathCounts
    if not counts then
        return deathCount
    end
    for index = 1, #keys do
        deathCount = math.max(deathCount, tonumber(counts[keys[index]]) or 0)
    end
    return deathCount
end

function PlayerBars.Group.SetDeathStateForKeys(keys, isDead, countDeath)
    if not keys then
        return false
    end

    countDeath = countDeath ~= false

    local states = PlayerBars.Group.deathStates or {}
    PlayerBars.Group.deathStates = states

    local wasDead = false
    for index = 1, #keys do
        if states[keys[index]] == true then
            wasDead = true
            break
        end
    end

    local deathCount = PlayerBars.Group.GetDeathCountForKeys(keys)
    if countDeath and isDead == true and not wasDead then
        deathCount = deathCount + 1
    end

    local counts = PlayerBars.Group.deathCounts or {}
    PlayerBars.Group.deathCounts = counts
    for index = 1, #keys do
        states[keys[index]] = isDead == true
        counts[keys[index]] = deathCount
    end

    return countDeath and isDead == true and not wasDead
end

function PlayerBars.Group.PruneDeathCounts()
    local groupSize = GetGroupSizeValue()
    if groupSize <= 0 then
        PlayerBars.Group.ClearDeathCounts()
        return
    end

    local activeKeys = {}
    for index = 1, groupSize do
        local unitTag = GetGroupUnitTag(index)
        if unitTag and (not DoesUnitExist or DoesUnitExist(unitTag) == true) then
            local keys = PlayerBars.Group.GetDeathCounterKeys(unitTag)
            if keys then
                for keyIndex = 1, #keys do
                    activeKeys[keys[keyIndex]] = true
                end
            end
        end
    end

    for key in pairs(PlayerBars.Group.deathCounts or {}) do
        if not activeKeys[key] then
            PlayerBars.Group.deathCounts[key] = nil
        end
    end

    for key in pairs(PlayerBars.Group.deathStates or {}) do
        if not activeKeys[key] then
            PlayerBars.Group.deathStates[key] = nil
        end
    end

end

function PlayerBars.Group.OnGroupMembershipChanged()
    if not runtimeActive then
        return
    end

    local previousGroupSize = tonumber(PlayerBars.Group.lastGroupSize) or 0
    local groupSize = GetGroupSizeValue()
    PlayerBars.Group.lastGroupSize = groupSize
    PlayerBars.Group.ClearCompanionNameCache()
    PlayerBars.Group.ClearSupportRangeCache()
    PlayerBars.Group.ClearRuntimeRows()
    if previousGroupSize <= 0 or groupSize <= 0 then
        PlayerBars.Group.ClearDeathCounts()
    else
        PlayerBars.Group.PruneDeathCounts()
    end
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.Group.OnGroupMemberLeft(_, _, _, isLocalPlayer, _, memberDisplayName)
    if not runtimeActive then
        return
    end

    PlayerBars.Group.lastGroupSize = GetGroupSizeValue()
    PlayerBars.Group.ClearCompanionNameCache()
    PlayerBars.Group.ClearSupportRangeCache()
    PlayerBars.Group.ClearRuntimeRows()
    if isLocalPlayer == true then
        PlayerBars.Group.ClearDeathCounts()
    else
        PlayerBars.Group.RemoveDeathCountKey(memberDisplayName)
        PlayerBars.Group.PruneDeathCounts()
    end

    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.Group.OnSupportRangeUpdate(_, unitTag, isNearby)
    if not runtimeActive or not unitTag then
        return
    end

    if ZO_Group_IsGroupUnitTag and not ZO_Group_IsGroupUnitTag(unitTag) then
        return
    end

    PlayerBars.Group.supportRangeCache[unitTag] = isNearby == true
    if not PlayerBars.Group.UpdateRowRange(unitTag, isNearby == true) then
        PlayerBars.Group.QueueRefresh()
    end
end

function PlayerBars.Group.OnDeathStateChanged(_, unitTag, isDead)
    if not runtimeActive then
        return
    end

    local isGroupUnit = unitTag and ZO_Group_IsGroupUnitTag and ZO_Group_IsGroupUnitTag(unitTag)
    if not isGroupUnit and type(unitTag) == "string" then
        isGroupUnit = unitTag:match("^group%d+$") ~= nil
    end

    if unitTag ~= "player" and not isGroupUnit then
        return
    end

    local data = PlayerBars.Group.dataByUnitTag and PlayerBars.Group.dataByUnitTag[unitTag]
    local row = PlayerBars.Group.rowByUnitTag and PlayerBars.Group.rowByUnitTag[unitTag]
    local keys = data and data.deathCounterKeys or PlayerBars.Group.GetDeathCounterKeys(unitTag)
    PlayerBars.Group.SetDeathStateForKeys(keys, isDead == true)
    if data and row and not row:IsHidden() then
        local settings = PlayerBars.Group.GetSettings()
        data.deathCounterKeys = keys
        data.deathCounterKey = keys and keys[1] or data.deathCounterKey
        data.isDead = isDead == true
        ApplyGroupRowStatus(row, data)
        ApplyGroupRowValue(row, data, settings)
        PlayerBars.Group.ApplyDeathCounter(row, data, settings, GetGroupLabelFont())
        ApplyGroupRowRangeStyle(row, data, settings)
        if isDead == true then
            PlayerBars.Group.StartResurrectingMonitor(unitTag)
        else
            PlayerBars.Group.StopResurrectingMonitor(unitTag, true)
        end
    else
        PlayerBars.Group.QueueRefresh()
    end

    if isDead == true and zo_callLater then
        zo_callLater(PlayerBars.Group.QueueRefresh, 100)
    end
end

function PlayerBars.Group.GetDeathCount(data)
    if not data then
        return 0
    end

    if data.previewRow then
        return tonumber(data.previewRow.deathCount) or 0
    end

    if data.deathCounterKeys then
        return PlayerBars.Group.GetDeathCountForKeys(data.deathCounterKeys)
    end

    local key = data.deathCounterKey
    return key and tonumber(PlayerBars.Group.deathCounts and PlayerBars.Group.deathCounts[key]) or 0
end

local function GetPreviewGroupName(index, nameDisplay)
    local row = PREVIEW_GROUP_ROWS[index]
    if not row then
        return nil
    end

    if nameDisplay == PlayerBars.Group.NAME_DISPLAY_PLAYER_ID then
        return FormatGroupPlayerId(row.playerId)
    elseif nameDisplay == PlayerBars.Group.NAME_DISPLAY_CHARACTER then
        return row.characterName
    end

    return nil
end

local function GetPreviewGroupRoleKey(index)
    local row = PREVIEW_GROUP_ROWS[index]
    return row and row.roleKey or PlayerBars.Group.FALLBACK_ROLE
end

local function GetPreviewGroupClassId(index)
    local row = PREVIEW_GROUP_ROWS[index]
    return row and row.classId or nil
end

local function GetGroupClassIcon(classId)
    classId = tonumber(classId)
    if classId and classId > 0 and ZO_GetGamepadClassIcon then
        return ZO_GetGamepadClassIcon(classId)
    end

    return nil
end

local function GetGroupCompanionDisplayName(companionTag)
    local name
    if GetRawUnitName then
        name = GetRawUnitName(companionTag)
    end
    if (not name or name == "") and GetUnitName then
        name = GetUnitName(companionTag)
    end
    if not name or name == "" then
        return nil
    end

    local companionName = string.match(name, "^@[^']+'s%s+(.+)$")
    return companionName and companionName ~= "" and companionName or name
end

function PlayerBars.Group.GetCompanionName(unitTag)
    if not unitTag or not GetCompanionUnitTagByGroupUnitTag then
        return nil
    end

    local cache = PlayerBars.Group.companionNameCache
    local cached = cache[unitTag]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local companionTag = GetCompanionUnitTagByGroupUnitTag(unitTag)
    local name
    if companionTag and DoesUnitExist and DoesUnitExist(companionTag) == true then
        name = GetGroupCompanionDisplayName(companionTag)
    end

    cache[unitTag] = name and name ~= "" and name or false
    return cache[unitTag] ~= false and cache[unitTag] or nil
end

function PlayerBars.GetUnitAttributeVisualValue(unitTag, visualType)
    if not unitTag or not GetUnitAttributeVisualizerEffectInfo or not visualType or not STAT_MITIGATION or not ATTRIBUTE_HEALTH then
        return 0
    end

    local value = GetUnitAttributeVisualizerEffectInfo(unitTag, visualType, STAT_MITIGATION, ATTRIBUTE_HEALTH, C.RESOURCE_HEALTH)
    return tonumber(value) or 0
end

function PlayerBars.Group.GetHealthVisuals(unitTag, settings, visualValues)
    if not unitTag then
        return PlayerBars.EMPTY_HEALTH_VISUALS
    end

    local showShield = settings.showShield == true
    local shield = showShield and PlayerBars.GetUnitAttributeVisualValue(unitTag, ATTRIBUTE_VISUAL_POWER_SHIELDING) or 0
    local trauma = settings.showTrauma == true and PlayerBars.GetUnitAttributeVisualValue(unitTag, ATTRIBUTE_VISUAL_TRAUMA) or 0
    local noHealing = settings.showNoHealing == true and PlayerBars.GetUnitAttributeVisualValue(unitTag, ATTRIBUTE_VISUAL_NO_HEALING) or 0
    if shield <= 0 and trauma <= 0 and noHealing <= 0 then
        return PlayerBars.EMPTY_HEALTH_VISUALS
    end

    visualValues = visualValues or {}
    visualValues.shield = shield
    visualValues.showShield = showShield
    visualValues.trauma = trauma
    visualValues.noHealing = noHealing
    visualValues.currentOverride = nil
    return visualValues
end

function PlayerBars.Group.GetPreviewHealthVisuals(current, maximum, settings, index, visualValues)
    local shield = 0
    local trauma = 0
    maximum = tonumber(maximum) or 0
    if settings.showShield == true then
        local multiplier = 0.12 + ((tonumber(index) or 1) - 1) % 4 * 0.03
        shield = math.max(1, zo_floor(maximum * multiplier))
    end
    if settings.showTrauma == true then
        local multiplier = 0.14 + ((tonumber(index) or 1) - 1) % 4 * 0.045
        trauma = math.max(1, zo_floor(maximum * multiplier))
    end

    local noHealing = settings.showNoHealing == true and 1 or 0
    if shield <= 0 and trauma <= 0 and noHealing <= 0 then
        return PlayerBars.EMPTY_HEALTH_VISUALS
    end

    visualValues = visualValues or {}
    visualValues.shield = shield
    visualValues.showShield = settings.showShield == true
    visualValues.trauma = trauma
    visualValues.noHealing = noHealing
    visualValues.currentOverride = maximum
    return visualValues
end

local function FormatGroupNameWithIcon(name, icon, height)
    if not icon or icon == "" or not zo_iconFormat then
        return name or ""
    end

    local iconSize = math.max(zo_floor((tonumber(height) or PlayerBars.Group.DEFAULT_HEIGHT) * 0.6336), 12)
    return zo_iconFormat(icon, iconSize, iconSize) .. " " .. (name or "")
end

function PlayerBars.Group.FormatNameWithCompanion(name, companionName, height)
    if not companionName or companionName == "" or not zo_iconFormat then
        return name or ""
    end

    local iconSize = math.max(zo_floor((tonumber(height) or PlayerBars.Group.DEFAULT_HEIGHT) * 0.6336), 12)
    return (name or "") .. " " .. zo_iconFormat(PlayerBars.Group.COMPANION_ICON, iconSize, iconSize) .. " " .. companionName
end

local function FormatGroupNameWithChampionPoints(name, championPoints, level, height, placement, companionName)
    championPoints = tonumber(championPoints) or 0
    level = tonumber(level) or 0

    local rankText
    if championPoints > 0 and zo_iconFormat then
        local iconSize = math.max(zo_floor((tonumber(height) or PlayerBars.Group.DEFAULT_HEIGHT) * 0.6336), 12)
        rankText = zo_iconFormat(PlayerBars.CHAMPION_ICON, iconSize, iconSize) .. tostring(championPoints)
    elseif championPoints > 0 then
        rankText = tostring(championPoints)
    elseif level > 0 then
        rankText = "L" .. tostring(level)
    else
        return name or ""
    end

    if companionName and companionName ~= "" then
        rankText = PlayerBars.Group.FormatNameWithCompanion(rankText, companionName, height)
    end

    if placement == PlayerBars.Group.CHAMPION_POINTS_AFTER then
        return (name or "") .. " " .. rankText
    end

    return rankText .. " " .. (name or "")
end

function PlayerBars.Group.GetRowNameText(data, settings, height)
    local nameText = data.name or ""
    if settings.showChampionPoints == true then
        nameText = FormatGroupNameWithChampionPoints(nameText, data.championPoints, data.level, height, settings.championPointsPlacement, settings.showCompanions == true and data.companionName or nil)
    elseif settings.showCompanions == true then
        nameText = PlayerBars.Group.FormatNameWithCompanion(nameText, data.companionName, height)
    end
    if settings.showClass == true then
        nameText = FormatGroupNameWithIcon(nameText, data.classIcon, height)
    end
    if settings.showTargetMarker == true then
        nameText = FormatGroupNameWithIcon(nameText, data.targetMarkerIcon, height)
    end
    return nameText
end

local function GetGroupRowData(index, settings, data)
    local nameDisplay = settings.nameDisplay
    local preview = PlayerBars.Group.IsPreviewVisible()
    local unitTag = preview and nil or GetGroupUnitTag(index)
    if not unitTag and not preview then
        return nil
    end

    data = data or {}
    local exists = unitTag and DoesUnitExist and DoesUnitExist(unitTag) == true
    if not exists and not preview then
        return nil
    end

    local previewRow = preview and PREVIEW_GROUP_ROWS[index] or nil
    local current, maximum, effectiveMaximum
    if exists and GetUnitPower then
        current, maximum, effectiveMaximum = GetUnitPower(unitTag, C.RESOURCE_HEALTH)
    else
        current = previewRow and previewRow.current or 100000
        maximum = previewRow and previewRow.maximum or 120000
        effectiveMaximum = maximum
    end

    current = Clamp(tonumber(current) or 0, 0, tonumber(maximum) or PlayerBars.Group.DEFAULT_WIDTH)
    maximum = tonumber(maximum) or PlayerBars.Group.DEFAULT_WIDTH
    effectiveMaximum = tonumber(effectiveMaximum) or maximum

    local name
    if nameDisplay == PlayerBars.Group.NAME_DISPLAY_PLAYER_ID then
        if exists and GetUnitDisplayName then
            name = FormatGroupPlayerId(GetUnitDisplayName(unitTag))
        end
    elseif nameDisplay == PlayerBars.Group.NAME_DISPLAY_CHARACTER then
        if exists and GetUnitName then
            name = GetUnitName(unitTag)
        end
    end
    if not name or name == "" then
        name = GetPreviewGroupName(index, nameDisplay)
    end

    local sortName = name
    if settings.showCustomNames == true and PlayerBars.Group.IsLibCustomNamesAvailable() then
        local customNameId = exists and GetUnitDisplayName and GetUnitDisplayName(unitTag) or (previewRow and previewRow.customNameId)
        local customName = GetCustomGroupName(customNameId, true)
        if customName then
            name = customName
            sortName = GetCustomGroupName(customNameId, false) or customNameId or sortName
        end
    end

    local roleKey = exists and GetGroupRoleKey(unitTag) or GetPreviewGroupRoleKey(index)
    local classId = exists and GetUnitClassId and GetUnitClassId(unitTag) or GetPreviewGroupClassId(index)
    local targetMarkerType = settings.showTargetMarker == true
        and (exists and GetUnitTargetMarkerType and GetUnitTargetMarkerType(unitTag) or (previewRow and previewRow.targetMarkerType))
        or nil
    local championPoints = exists and GetUnitEffectiveChampionPoints and GetUnitEffectiveChampionPoints(unitTag) or (previewRow and previewRow.championPoints)
    local level = exists and GetUnitLevel and GetUnitLevel(unitTag) or (previewRow and previewRow.level)
    local companionName = settings.showCompanions == true and (exists and PlayerBars.Group.GetCompanionName(unitTag) or (previewRow and previewRow.companionName)) or nil
    local isBeingResurrected = false
    local hasResurrectPending = false
    if settings.showResurrectingColor == true then
        if exists then
            isBeingResurrected = IsUnitBeingResurrected and IsUnitBeingResurrected(unitTag) == true
            hasResurrectPending = DoesUnitHaveResurrectPending and DoesUnitHaveResurrectPending(unitTag) == true
        elseif previewRow then
            isBeingResurrected = previewRow.isBeingResurrected == true
            hasResurrectPending = previewRow.hasResurrectPending == true
        end
    end
    local deathCounterKeys = exists and PlayerBars.Group.GetDeathCounterKeys(unitTag) or nil
    local isDead = exists and IsUnitDeadOrReincarnating and IsUnitDeadOrReincarnating(unitTag) == true
    if deathCounterKeys then
        PlayerBars.Group.SetDeathStateForKeys(deathCounterKeys, isDead, false)
    end

    data.unitTag = unitTag
    data.name = name
    data.previewRow = previewRow
    data.deathCounterKeys = deathCounterKeys
    data.deathCounterKey = deathCounterKeys and deathCounterKeys[1] or nil
    data.classIcon = GetGroupClassIcon(classId)
    data.targetMarkerIcon = targetMarkerType
        and targetMarkerType ~= TARGET_MARKER_TYPE_NONE
        and ZO_GetPlatformTargetMarkerIcon
        and ZO_GetPlatformTargetMarkerIcon(targetMarkerType)
        or nil
    data.championPoints = championPoints
    data.level = level
    data.companionName = companionName
    data.healthVisualCache = data.healthVisualCache or {}
    data.healthVisuals = exists
        and PlayerBars.Group.GetHealthVisuals(unitTag, settings, data.healthVisualCache)
        or PlayerBars.Group.GetPreviewHealthVisuals(current, maximum, settings, index, data.healthVisualCache)
    data.current = current
    data.maximum = maximum
    data.effectiveMaximum = effectiveMaximum
    data.roleKey = roleKey
    data.originalIndex = index
    data.sortName = string.lower(sortName or "")
    data.isLeader = exists and IsUnitGroupLeader and IsUnitGroupLeader(unitTag) == true or (preview and index == 1)
    data.isDead = isDead
    data.isBeingResurrected = isBeingResurrected
    data.hasResurrectPending = hasResurrectPending
    data.showResurrecting = isBeingResurrected or hasResurrectPending
    data.isOnline = (not exists) or (not IsUnitOnline) or IsUnitOnline(unitTag) == true
    data.inSupportRange = PlayerBars.Group.GetSupportRange(unitTag, exists, previewRow and previewRow.inSupportRange)
    data.nameText = nil
    return data
end

local function CompareGroupRows(left, right)
    local leftRole = PlayerBars.Group.ROLE_SORT_ORDER[left.roleKey] or PlayerBars.Group.ROLE_SORT_ORDER[PlayerBars.Group.FALLBACK_ROLE]
    local rightRole = PlayerBars.Group.ROLE_SORT_ORDER[right.roleKey] or PlayerBars.Group.ROLE_SORT_ORDER[PlayerBars.Group.FALLBACK_ROLE]
    if leftRole ~= rightRole then
        return leftRole < rightRole
    end

    if left.sortName ~= right.sortName then
        return left.sortName < right.sortName
    end

    return (left.originalIndex or 0) < (right.originalIndex or 0)
end

local function BuildSortedGroupRows(rowCount, settings)
    local dataRows = PlayerBars.Group.dataRows or {}
    PlayerBars.Group.dataRows = dataRows
    PlayerBars.Group.rowByUnitTag = PlayerBars.Group.rowByUnitTag or {}
    PlayerBars.Group.dataByUnitTag = PlayerBars.Group.dataByUnitTag or {}
    for index = 1, #dataRows do
        dataRows[index].row = nil
        dataRows[index].rowIndex = nil
        dataRows[index] = nil
    end
    for key in pairs(PlayerBars.Group.rowByUnitTag) do
        PlayerBars.Group.rowByUnitTag[key] = nil
    end
    for key in pairs(PlayerBars.Group.dataByUnitTag) do
        PlayerBars.Group.dataByUnitTag[key] = nil
    end

    for index = 1, rowCount do
        local data = GetGroupRowData(index, settings, PlayerBars.Group.dataByOriginalIndex and PlayerBars.Group.dataByOriginalIndex[index] or nil)
        if data then
            PlayerBars.Group.dataByOriginalIndex = PlayerBars.Group.dataByOriginalIndex or {}
            PlayerBars.Group.dataByOriginalIndex[index] = data
            dataRows[#dataRows + 1] = data
        end
    end

    table.sort(dataRows, CompareGroupRows)
    return dataRows
end

ApplyGroupRowValue = function(row, data, settings, smoothUpdate)
    local widget = row.widget
    local shieldColor = settings.shieldColor
    if widget.shield and shieldColor then
        widget.shield:SetCenterColor(shieldColor.r, shieldColor.g, shieldColor.b, shieldColor.a or 1)
    end
    local traumaColor = settings.traumaColor
    if widget.trauma and traumaColor then
        widget.trauma:SetCenterColor(traumaColor.r, traumaColor.g, traumaColor.b, traumaColor.a or 1)
    end

    local rangeMaximum = data.maximum
    if rangeMaximum < 1 then
        rangeMaximum = 1
    end

    local fillCurrent, traumaAmount, shieldAmount = PlayerBars.GetHealthSegmentValues(data, data.healthVisuals)
    if settings.smoothTransitions == true and PlayerBars.Smooth then
        fillCurrent = PlayerBars.Smooth.GetValue(widget, C.RESOURCE_HEALTH, fillCurrent, row.smoothUpdateCallback or PlayerBars.Group.QueueRefresh, rangeMaximum)
        if data.healthVisuals.showShield == true and shieldAmount > 0 then
            shieldAmount = PlayerBars.Smooth.GetValue(widget, C.PLAYER_SHIELD_SMOOTH_KEY, shieldAmount, row.smoothUpdateCallback or PlayerBars.Group.QueueRefresh, nil, false)
            widget.nqolShieldSmoothInitialized = true
        elseif widget.nqolShieldSmoothInitialized == true then
            PlayerBars.Smooth.Reset(widget, C.PLAYER_SHIELD_SMOOTH_KEY)
            widget.nqolShieldSmoothInitialized = nil
        end
    elseif PlayerBars.Smooth then
        PlayerBars.Smooth.Reset(widget, C.RESOURCE_HEALTH)
        if widget.nqolShieldSmoothInitialized == true then
            PlayerBars.Smooth.Reset(widget, C.PLAYER_SHIELD_SMOOTH_KEY)
            widget.nqolShieldSmoothInitialized = nil
        end
    end
    local percent = Clamp(fillCurrent / rangeMaximum, 0, 1)
    local width = widget:GetWidth() or settings.width
    local height = widget:GetHeight() or settings.height
    local borderSize = Clamp(settings.borderSize, C.CLASSIC_BORDER_SIZE_MIN, math.max(C.CLASSIC_BORDER_SIZE_MIN, zo_floor((height - 1) * 0.5)))
    local innerWidth = math.max(width - borderSize * 2, 0)
    local innerHeight = math.max(height - borderSize * 2, 0)
    local fillWidth = zo_floor(innerWidth * percent)
    if fillCurrent > 0 and fillWidth < 1 then
        fillWidth = 1
    end

    local red, green, blue, alpha = GetGroupRoleColor(settings, data.roleKey)
    if data.showResurrecting then
        red, green, blue, alpha = settings.resurrectingColor.r, settings.resurrectingColor.g, settings.resurrectingColor.b, settings.resurrectingColor.a or 1
        widget.track:SetCenterColor(red, green, blue, 0.38)
    else
        widget.track:SetCenterColor(0, 0, 0, 0.78)
    end
    widget.fill:SetCenterColor(red, green, blue, alpha)
    PlayerBars.ApplyLossFill(widget, C.RESOURCE_HEALTH, rangeMaximum, innerWidth, innerHeight, borderSize, settings.reverse == true, false, settings.smoothTransitions == true and settings.transitionShadow == true)
    widget.fill:ClearAnchors()
    if settings.reverse == true then
        widget.fill:SetAnchor(TOPRIGHT, widget, TOPRIGHT, -borderSize, borderSize)
    else
        widget.fill:SetAnchor(TOPLEFT, widget, TOPLEFT, borderSize, borderSize)
    end
    widget.fill:SetDimensions(fillWidth, innerHeight)
    if data.showResurrecting then
        PlayerBars.HideHealthVisualOverlays(widget)
    else
        PlayerBars.ApplyHealthVisualOverlays(widget, data, rangeMaximum, innerWidth, innerHeight, borderSize, settings.reverse == true, false, data.healthVisuals, fillCurrent, traumaAmount, shieldAmount)
    end

    local nameText = data.nameText or PlayerBars.Group.GetRowNameText(data, settings, height)
    if row.appliedNameText ~= nameText then
        widget.leftLabel:SetText(nameText)
        row.appliedNameText = nameText
    end
    if not smoothUpdate then
        local currentText = data.isDead and "" or FormatCurrentValue(data, data.maximum, settings.currentValue, false)
        if row.appliedCurrentText ~= currentText then
            widget.rightLabel:SetText(currentText)
            row.appliedCurrentText = currentText
        end
    end
end

function PlayerBars.Group.ApplyRowValueByRow(row, smoothUpdate)
    if not row or not row.groupData or row:IsHidden() then
        return false
    end

    ApplyGroupRowValue(row, row.groupData, PlayerBars.Group.GetSettings(), smoothUpdate)
    return true
end

ApplyGroupRowStatus = function(row, data)
    if data.isDead then
        row.statusIcon:SetTexture(PlayerBars.Group.DEAD_ICON)
        row.statusIcon:SetHidden(false)
    elseif not data.isOnline then
        row.statusIcon:SetTexture(PlayerBars.Group.OFFLINE_ICON)
        row.statusIcon:SetHidden(false)
    else
        row.statusIcon:SetHidden(true)
    end

    row:SetAlpha(1)
end

ApplyGroupRowRangeStyle = function(row, data, settings)
    local alpha = 1
    if not data.inSupportRange then
        alpha = Clamp((tonumber(settings.dimAwayOpacity) or PlayerBars.Group.AWAY_OPACITY_DEFAULT) * 0.01, 0, 1)
    end

    row:SetAlpha(1)
    row.widget:SetAlpha(1)

    if row.widget.track then
        row.widget.track:SetAlpha(alpha)
    end
    if row.widget.fill then
        row.widget.fill:SetAlpha(alpha)
    end
    if row.widget.loss then
        row.widget.loss:SetAlpha(alpha)
    end
    if row.widget.trauma then
        row.widget.trauma:SetAlpha(alpha)
    end
    if row.widget.leftLabel then
        row.widget.leftLabel:SetAlpha(alpha)
    end
    if row.widget.rightLabel then
        row.widget.rightLabel:SetAlpha(alpha)
    end
    if row.widget.icon then
        row.widget.icon:SetAlpha(alpha)
    end
    if row.widget.innerShadowStrips then
        for _, strip in ipairs(row.widget.innerShadowStrips) do
            strip:SetAlpha(alpha)
        end
    end
    if row.widget.noHealingFractureGlowTiles then
        for _, tile in ipairs(row.widget.noHealingFractureGlowTiles) do
            tile:SetAlpha(alpha)
        end
    end
    if row.widget.noHealingFractureTiles then
        for _, tile in ipairs(row.widget.noHealingFractureTiles) do
            tile:SetAlpha(alpha)
        end
    end
    if row.leaderIcon then
        row.leaderIcon:SetAlpha(alpha)
    end
    if row.statusIcon then
        row.statusIcon:SetAlpha(alpha)
    end
    if row.resurrectPendingIcon then
        row.resurrectPendingIcon:SetAlpha(alpha)
    end
    if row.deathCounterIcon then
        row.deathCounterIcon:SetAlpha(alpha)
    end
    if row.deathCounterLabel then
        row.deathCounterLabel:SetAlpha(alpha)
    end
end

function PlayerBars.Group.ApplyDeathCounter(row, data, settings, labelFont)
    local deathCount = settings.showDeathCounter == true and PlayerBars.Group.GetDeathCount(data) or 0
    if deathCount <= 0 then
        row.deathCounterIcon:SetHidden(true)
        row.deathCounterLabel:SetHidden(true)
        return
    end

    row.deathCounterIcon:ClearAnchors()
    row.deathCounterLabel:ClearAnchors()
    row.deathCounterLabel:SetFont(labelFont)
    row.deathCounterLabel:SetColor(1, 1, 1, 1)
    row.deathCounterLabel:SetText(tostring(deathCount))
    row.deathCounterLabel:SetDimensions(PlayerBars.Group.DEATH_COUNTER_WIDTH - PlayerBars.Group.ICON_SIZE - PlayerBars.Group.ICON_GAP, settings.height)
    local outerGap = row.deathCounterOuterGap or PlayerBars.Group.ICON_GAP

    if settings.reverse == true then
        row.deathCounterLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        row.deathCounterLabel:SetAnchor(RIGHT, row, LEFT, -outerGap, 0)
        row.deathCounterIcon:SetAnchor(RIGHT, row.deathCounterLabel, LEFT, -PlayerBars.Group.ICON_GAP, 0)
    else
        row.deathCounterIcon:SetAnchor(LEFT, row, RIGHT, outerGap, 0)
        row.deathCounterLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        row.deathCounterLabel:SetAnchor(LEFT, row.deathCounterIcon, RIGHT, PlayerBars.Group.ICON_GAP, 0)
    end

    row.deathCounterIcon:SetHidden(false)
    row.deathCounterLabel:SetHidden(false)
end

function PlayerBars.Group.UpdateRowRange(unitTag, inSupportRange)
    local row = unitTag and PlayerBars.Group.rowByUnitTag and PlayerBars.Group.rowByUnitTag[unitTag]
    local data = unitTag and PlayerBars.Group.dataByUnitTag and PlayerBars.Group.dataByUnitTag[unitTag]
    if not row or not data or row:IsHidden() then
        return false
    end

    data.inSupportRange = inSupportRange == true
    ApplyGroupRowRangeStyle(row, data, PlayerBars.Group.GetSettings())
    return true
end

local function GetResurrectingMonitorUpdateName(unitTag)
    return PlayerBars.Group.EVENT_NAMESPACE .. "_Resurrecting_" .. tostring(unitTag)
end

local function IsUnitDeadForResurrectingMonitor(unitTag)
    if not unitTag or (DoesUnitExist and DoesUnitExist(unitTag) ~= true) then
        return false
    end

    if IsUnitDeadOrReincarnating and IsUnitDeadOrReincarnating(unitTag) == true then
        return true
    end
    if IsUnitDead and IsUnitDead(unitTag) == true then
        return true
    end

    return IsUnitReincarnating and IsUnitReincarnating(unitTag) == true
end

local function ShouldMonitorResurrectingUnit(unitTag)
    local settings = PlayerBars.Group.GetSettings()
    local row = unitTag and PlayerBars.Group.rowByUnitTag and PlayerBars.Group.rowByUnitTag[unitTag]
    local data = unitTag and PlayerBars.Group.dataByUnitTag and PlayerBars.Group.dataByUnitTag[unitTag]
    return settings.showResurrectingColor == true
        and PlayerBars.Group.root
        and not PlayerBars.Group.root:IsHidden()
        and row
        and not row:IsHidden()
        and data
        and IsUnitDeadForResurrectingMonitor(unitTag)
end

function PlayerBars.Group.UpdateRowResurrectState(unitTag, data)
    if not unitTag or not data then
        return false
    end

    local settings = PlayerBars.Group.GetSettings()
    local isBeingResurrected = settings.showResurrectingColor == true and IsUnitBeingResurrected and IsUnitBeingResurrected(unitTag) == true
    local hasResurrectPending = settings.showResurrectingColor == true and DoesUnitHaveResurrectPending and DoesUnitHaveResurrectPending(unitTag) == true
    local showResurrecting = isBeingResurrected or hasResurrectPending
    if data.isBeingResurrected == isBeingResurrected
        and data.hasResurrectPending == hasResurrectPending
        and data.showResurrecting == showResurrecting
    then
        return false
    end

    data.isBeingResurrected = isBeingResurrected
    data.hasResurrectPending = hasResurrectPending
    data.showResurrecting = showResurrecting
    local row = data.row
    if row and not row:IsHidden() then
        row.resurrectPendingIcon:SetHidden(not (hasResurrectPending == true and isBeingResurrected ~= true))
        PlayerBars.Group.ApplyRowValueByRow(row)
        if data.inSupportRange == false or settings.showNoHealing == true then
            ApplyGroupRowRangeStyle(row, data, settings)
        end
    end
    return true
end

function PlayerBars.Group.StopResurrectingMonitor(unitTag, clearState)
    if not unitTag then
        return
    end

    if EVENT_MANAGER and EVENT_MANAGER.UnregisterForUpdate then
        EVENT_MANAGER:UnregisterForUpdate(GetResurrectingMonitorUpdateName(unitTag))
    end
    if PlayerBars.Group.resurrectingMonitorUnitTags then
        PlayerBars.Group.resurrectingMonitorUnitTags[unitTag] = nil
    end

    local data = PlayerBars.Group.dataByUnitTag and PlayerBars.Group.dataByUnitTag[unitTag]
    if clearState == true and data then
        data.isBeingResurrected = false
        data.hasResurrectPending = false
        data.showResurrecting = false
        local row = data.row
        if row and not row:IsHidden() then
            row.resurrectPendingIcon:SetHidden(true)
            PlayerBars.Group.ApplyRowValueByRow(row)
            ApplyGroupRowRangeStyle(row, data, PlayerBars.Group.GetSettings())
        end
    end
end

function PlayerBars.Group.StopAllResurrectingMonitors(clearState)
    local active = PlayerBars.Group.resurrectingMonitorUnitTags
    if not active then
        return
    end

    for unitTag in pairs(active) do
        PlayerBars.Group.StopResurrectingMonitor(unitTag, clearState)
    end
end

function PlayerBars.Group.MonitorResurrectingUnit(unitTag)
    local data = unitTag and PlayerBars.Group.dataByUnitTag and PlayerBars.Group.dataByUnitTag[unitTag]
    if not ShouldMonitorResurrectingUnit(unitTag) then
        PlayerBars.Group.StopResurrectingMonitor(unitTag, true)
        return
    end

    PlayerBars.Group.UpdateRowResurrectState(unitTag, data)
end

function PlayerBars.Group.StartResurrectingMonitor(unitTag)
    if not runtimeActive or not EVENT_MANAGER or not EVENT_MANAGER.RegisterForUpdate or not ShouldMonitorResurrectingUnit(unitTag) then
        PlayerBars.Group.StopResurrectingMonitor(unitTag, true)
        return
    end

    local active = PlayerBars.Group.resurrectingMonitorUnitTags or {}
    PlayerBars.Group.resurrectingMonitorUnitTags = active
    if active[unitTag] ~= true then
        EVENT_MANAGER:RegisterForUpdate(GetResurrectingMonitorUpdateName(unitTag), 500, function()
            PlayerBars.Group.MonitorResurrectingUnit(unitTag)
        end)
        active[unitTag] = true
    end

    PlayerBars.Group.MonitorResurrectingUnit(unitTag)
end

function PlayerBars.Group.RefreshResurrectingMonitors()
    local dataRows = PlayerBars.Group.dataRows
    if not dataRows or not PlayerBars.Group.root or PlayerBars.Group.root:IsHidden() or PlayerBars.Group.GetSettings().showResurrectingColor ~= true then
        PlayerBars.Group.StopAllResurrectingMonitors(true)
        return
    end

    local visibleUnits = {}
    for index = 1, #dataRows do
        local data = dataRows[index]
        if data and data.unitTag then
            visibleUnits[data.unitTag] = true
            if IsUnitDeadForResurrectingMonitor(data.unitTag) then
                PlayerBars.Group.StartResurrectingMonitor(data.unitTag)
            else
                PlayerBars.Group.StopResurrectingMonitor(data.unitTag, true)
            end
        end
    end

    for unitTag in pairs(PlayerBars.Group.resurrectingMonitorUnitTags or {}) do
        if visibleUnits[unitTag] ~= true then
            PlayerBars.Group.StopResurrectingMonitor(unitTag, true)
        end
    end
end

function PlayerBars.Group.UpdateRowHealth(unitTag, current, maximum, effectiveMaximum)
    local data = unitTag and PlayerBars.Group.dataByUnitTag and PlayerBars.Group.dataByUnitTag[unitTag]
    local row = unitTag and PlayerBars.Group.rowByUnitTag and PlayerBars.Group.rowByUnitTag[unitTag]
    if not data or not row or row:IsHidden() then
        return false
    end

    if current == nil and GetUnitPower then
        current, maximum, effectiveMaximum = GetUnitPower(unitTag, C.RESOURCE_HEALTH)
    end

    maximum = tonumber(maximum) or data.maximum or PlayerBars.Group.DEFAULT_WIDTH
    current = Clamp(tonumber(current) or 0, 0, maximum)
    effectiveMaximum = tonumber(effectiveMaximum) or maximum
    local settings = PlayerBars.Group.GetSettings()
    local changed = data.current ~= current or data.maximum ~= maximum or data.effectiveMaximum ~= effectiveMaximum
    local previousShield = data.healthVisuals and data.healthVisuals.showShield == true and data.healthVisuals.shield or 0
    data.current = current
    data.maximum = maximum
    data.effectiveMaximum = effectiveMaximum
    data.healthVisualCache = data.healthVisualCache or {}
    data.healthVisuals = PlayerBars.Group.GetHealthVisuals(unitTag, settings, data.healthVisualCache)
    local currentShield = data.healthVisuals.showShield == true and data.healthVisuals.shield or 0
    local shieldVisibilityChanged = (previousShield > 0) ~= (currentShield > 0)
    if shieldVisibilityChanged and PlayerBars.Smooth then
        PlayerBars.Smooth.Reset(row.widget, C.RESOURCE_HEALTH)
        PlayerBars.Smooth.Reset(row.widget, C.PLAYER_SHIELD_SMOOTH_KEY)
        row.widget.nqolShieldSmoothInitialized = nil
    end
    local isDead = IsUnitDeadForResurrectingMonitor(unitTag)
    local deathStateChanged = data.isDead ~= isDead
    if deathStateChanged then
        data.isDead = isDead
        PlayerBars.Group.SetDeathStateForKeys(data.deathCounterKeys, isDead, false)
        ApplyGroupRowStatus(row, data)
        if isDead then
            PlayerBars.Group.StartResurrectingMonitor(unitTag)
        else
            PlayerBars.Group.StopResurrectingMonitor(unitTag, true)
        end
    end
    PlayerBars.Group.UpdateRowResurrectState(unitTag, data)

    if changed or deathStateChanged or settings.showShield == true or settings.showTrauma == true or settings.showNoHealing == true then
        PlayerBars.Group.ApplyRowValueByRow(row)
        if data.inSupportRange == false or settings.showNoHealing == true then
            ApplyGroupRowRangeStyle(row, data, settings)
        end
    end
    return true
end

function PlayerBars.Group.FlushPowerUpdates()
    PlayerBars.Group.powerUpdateQueued = false
    local pending = PlayerBars.Group.pendingPowerUpdates
    if not pending then
        return
    end

    if not runtimeActive then
        local pool = PlayerBars.Group.pendingPowerUpdatePool
        for unitTag, data in pairs(pending) do
            pending[unitTag] = nil
            data.current = nil
            data.maximum = nil
            data.effectiveMaximum = nil
            pool[#pool + 1] = data
        end
        return
    end

    local pool = PlayerBars.Group.pendingPowerUpdatePool
    for unitTag, data in pairs(pending) do
        if not PlayerBars.Group.UpdateRowHealth(unitTag, data.current, data.maximum, data.effectiveMaximum) then
            PlayerBars.Group.QueueRefresh()
        end
        pending[unitTag] = nil
        data.current = nil
        data.maximum = nil
        data.effectiveMaximum = nil
        pool[#pool + 1] = data
    end
end

function PlayerBars.Group.OnPowerFlushUpdate()
    if EVENT_MANAGER and EVENT_MANAGER.UnregisterForUpdate then
        EVENT_MANAGER:UnregisterForUpdate(PlayerBars.Group.EVENT_NAMESPACE .. "_PowerFlush")
    end
    PlayerBars.Group.FlushPowerUpdates()
end

function PlayerBars.Group.QueuePowerUpdate(unitTag, current, maximum, effectiveMaximum)
    if not runtimeActive or not unitTag then
        return
    end

    local pending = PlayerBars.Group.pendingPowerUpdates
    local data = pending[unitTag]
    if not data then
        local pool = PlayerBars.Group.pendingPowerUpdatePool
        local poolSize = #pool
        data = pool[poolSize]
        if data then
            pool[poolSize] = nil
        else
            data = {}
        end
        pending[unitTag] = data
    end
    data.current = current
    data.maximum = maximum
    data.effectiveMaximum = effectiveMaximum

    if PlayerBars.Group.powerUpdateQueued then
        return
    end

    PlayerBars.Group.powerUpdateQueued = true
    if EVENT_MANAGER and EVENT_MANAGER.RegisterForUpdate then
        EVENT_MANAGER:RegisterForUpdate(PlayerBars.Group.EVENT_NAMESPACE .. "_PowerFlush", 16, PlayerBars.Group.OnPowerFlushUpdate)
    elseif zo_callLater then
        zo_callLater(PlayerBars.Group.FlushPowerUpdates, 16)
    else
        PlayerBars.Group.FlushPowerUpdates()
    end
end

function PlayerBars.Group.LayoutAndApplyRows()
    local settings = PlayerBars.Group.GetSettings()
    local groupSize = GetGroupSizeValue()
    local preview = PlayerBars.Group.IsPreviewVisible()
    local rowCount = preview and PlayerBars.Group.MAX_ROWS or groupSize
    rowCount = Clamp(rowCount, 0, PlayerBars.Group.MAX_ROWS)
    local width = Clamp(settings.width, PlayerBars.Group.WIDTH_MIN, PlayerBars.Group.WIDTH_MAX)
    local height = Clamp(settings.height, PlayerBars.Group.HEIGHT_MIN, PlayerBars.Group.HEIGHT_MAX)
    local rowGap = Clamp(settings.rowGap, PlayerBars.Group.ROW_GAP_MIN, PlayerBars.Group.ROW_GAP_MAX)
    local valueWidth = PlayerBars.Group.VALUE_WIDTH
    local dataRows = BuildSortedGroupRows(rowCount, settings)
    rowCount = #dataRows
    local columns = math.min(settings.columns, math.max(rowCount, 1))
    local rowsPerColumn = math.max(math.ceil(rowCount / columns), 1)
    -- Reserve the full death counter and a fixed margin on each side at zero.
    -- Status icons sit on the outside edges of a two-column frame.
    local columnGap = PlayerBars.Group.DEATH_COUNTER_WIDTH + 2 * PlayerBars.Group.ICON_GAP
        + Clamp(settings.columnGap, PlayerBars.Group.COLUMN_GAP_MIN, PlayerBars.Group.COLUMN_GAP_MAX)
    local rootWidth = columns * width + (columns - 1) * columnGap
    local rootHeight = rowsPerColumn * height + (rowsPerColumn - 1) * rowGap
    local labelFont = GetGroupLabelFont()

    PlayerBars.Group.root:SetDimensions(rootWidth, rootHeight)

    for index = 1, PlayerBars.Group.MAX_ROWS do
        local row = PlayerBars.Group.rows[index]
        local data = dataRows[index]
        if data then
            data.row = row
            data.rowIndex = index
            data.nameText = PlayerBars.Group.GetRowNameText(data, settings, height)
            row.groupData = data
            row.groupUnitTag = data.unitTag
            row.smoothUpdateCallback = row.smoothUpdateCallback or function()
                PlayerBars.Group.ApplyRowValueByRow(row, true)
            end
            if data.unitTag then
                PlayerBars.Group.rowByUnitTag[data.unitTag] = row
                PlayerBars.Group.dataByUnitTag[data.unitTag] = data
            end
            row:SetHidden(false)
            row:ClearAnchors()
            row:SetDimensions(width, height)
            local columnIndex = math.floor((index - 1) / rowsPerColumn)
            local rowIndex = (index - 1) % rowsPerColumn
            row:SetAnchor(TOPLEFT, PlayerBars.Group.root, TOPLEFT,
                columnIndex * (width + columnGap), rowIndex * (height + rowGap))

            row.deathCounterOuterGap = PlayerBars.Group.ICON_GAP

            row.statusIcon:ClearAnchors()
            row.leaderIcon:ClearAnchors()
            row.resurrectPendingIcon:ClearAnchors()
            row.deathCounterIcon:ClearAnchors()
            row.deathCounterLabel:ClearAnchors()
            local showLeader = settings.showLeader == true and data.isLeader == true
            local statusOnRight = settings.reverse == true
            if columns > 1 then
                statusOnRight = columnIndex == columns - 1
                if statusOnRight == (settings.reverse ~= true) then
                    row.deathCounterOuterGap = 2 * (PlayerBars.Group.ICON_SIZE + PlayerBars.Group.ICON_GAP)
                        + PlayerBars.Group.ICON_GAP
                end
            end
            if statusOnRight then
                row.leaderIcon:SetAnchor(LEFT, row, RIGHT, PlayerBars.Group.ICON_GAP, 0)
                if showLeader then
                    row.statusIcon:SetAnchor(LEFT, row.leaderIcon, RIGHT, PlayerBars.Group.ICON_GAP, 0)
                else
                    row.statusIcon:SetAnchor(LEFT, row, RIGHT, PlayerBars.Group.ICON_GAP, 0)
                end
            else
                row.leaderIcon:SetAnchor(RIGHT, row, LEFT, -PlayerBars.Group.ICON_GAP, 0)
                if showLeader then
                    row.statusIcon:SetAnchor(RIGHT, row.leaderIcon, LEFT, -PlayerBars.Group.ICON_GAP, 0)
                else
                    row.statusIcon:SetAnchor(RIGHT, row, LEFT, -PlayerBars.Group.ICON_GAP, 0)
                end
            end
            row.leaderIcon:SetHidden(not showLeader)

            row.widget:ClearAnchors()
            row.widget:SetDimensions(width, height)
            row.widget:SetAnchorFill(row)
            local pendingIconSize = math.max(PlayerBars.Group.ICON_SIZE, math.min(height + 6, 32))
            row.resurrectPendingIcon:SetDimensions(pendingIconSize, pendingIconSize)
            row.resurrectPendingIcon:SetAnchor(CENTER, row.widget, CENTER, 0, 0)
            row.resurrectPendingIcon:SetHidden(not (data.hasResurrectPending == true and data.isBeingResurrected ~= true))
            row.widget.leftLabel:ClearAnchors()
            row.widget.rightLabel:ClearAnchors()
            row.widget.leftLabel:SetHidden(false)
            row.widget.rightLabel:SetHidden(false)
            row.widget.leftLabel:SetDimensions(width - valueWidth - C.CLASSIC_LABEL_PADDING * 2, height)
            row.widget.rightLabel:SetDimensions(valueWidth, height)
            row.widget.leftLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            row.widget.rightLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            row.widget.leftLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            row.widget.rightLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            row.widget.leftLabel:SetFont(labelFont)
            row.widget.rightLabel:SetFont(labelFont)
            row.widget.leftLabel:SetColor(1, 1, 1, 1)
            row.widget.rightLabel:SetColor(1, 1, 1, 1)
            row.widget.leftLabel:SetAnchor(TOPLEFT, row.widget, TOPLEFT, C.CLASSIC_LABEL_PADDING, 0)
            row.widget.leftLabel:SetAnchor(BOTTOMRIGHT, row.widget, BOTTOMRIGHT, -valueWidth - C.CLASSIC_LABEL_PADDING, 0)
            row.widget.rightLabel:SetAnchor(TOPRIGHT, row.widget, TOPRIGHT, -C.CLASSIC_LABEL_PADDING, 0)
            row.widget.rightLabel:SetAnchor(BOTTOMRIGHT, row.widget, BOTTOMRIGHT, -C.CLASSIC_LABEL_PADDING, 0)

            row.nameLabel:SetHidden(true)
            row.nameLabel:SetText("")
            row.appliedNameText = nil
            row.appliedCurrentText = nil

            ApplyGroupRowStatus(row, data)
            ApplyGroupRowValue(row, data, settings)
            PlayerBars.Group.ApplyDeathCounter(row, data, settings, labelFont)
            Shadow.Layout(row.widget, width, height, settings.borderSize, settings.shadow, settings.shadowIntensity)
            ApplyGroupRowRangeStyle(row, data, settings)
            if IsUnitDeadForResurrectingMonitor(data.unitTag) then
                PlayerBars.Group.StartResurrectingMonitor(data.unitTag)
            else
                PlayerBars.Group.StopResurrectingMonitor(data.unitTag, true)
            end
        else
            PlayerBars.Group.StopResurrectingMonitor(row.groupUnitTag, true)
            row.groupData = nil
            row.groupUnitTag = nil
            row.appliedNameText = nil
            row.appliedCurrentText = nil
            PlayerBars.HideLossFill(row.widget)
            if PlayerBars.Smooth then
                PlayerBars.Smooth.Reset(row.widget, C.RESOURCE_HEALTH)
                PlayerBars.Smooth.Reset(row.widget, C.PLAYER_SHIELD_SMOOTH_KEY)
                row.widget.nqolShieldSmoothInitialized = nil
            end
            row.deathCounterIcon:SetHidden(true)
            row.deathCounterLabel:SetHidden(true)
            row.resurrectPendingIcon:SetHidden(true)
            row:SetHidden(true)
        end
    end

    ApplyRootPosition(PlayerBars.Group.root, settings)
end

function PlayerBars.Group.RefreshFrame()
    PlayerBars.Group.refreshQueued = false

    local settings = PlayerBars.Group.GetSettings()
    local previewVisible = PlayerBars.Group.IsPreviewVisible()
    local shouldShowFrame = (settings.showNqolGroupFrame == true or previewVisible)
        and PlayerBars.Group.ShouldShowForCurrentScene()
        and (GetGroupSizeValue() > 0 or previewVisible)
    local combatOnly = not previewVisible and settings.showOnlyInCombat == true

    if not shouldShowFrame then
        PlayerBars.Group.HideFrame()
        return
    end

    if combatOnly and not (IsUnitInCombat and IsUnitInCombat("player") == true) then
        SetFrameCombatVisibility(PlayerBars.Group.root, false)
        if PlayerBars.Group.StopAllResurrectingMonitors then
            PlayerBars.Group.StopAllResurrectingMonitors(true)
        end
        return
    end

    if not PlayerBars.Group.EnsureControls() then
        return
    end

    if not previewVisible then
        Shared.RestoreDrawOrder(PlayerBars.Group.root)
    end

    PlayerBars.Group.LayoutAndApplyRows()
    if previewVisible then
        Shared.SetSettingsPreviewDrawOrder(PlayerBars.Group.root)
    end
    if combatOnly then
        SetFrameCombatVisibility(PlayerBars.Group.root, true)
    else
        SetFrameVisibilityImmediate(PlayerBars.Group.root, true)
    end
    PlayerBars.Group.RefreshResurrectingMonitors()
end

function PlayerBars.Group.QueueRefresh()
    if not runtimeActive then
        PlayerBars.Group.refreshQueued = false
        return
    end

    if PlayerBars.Group.refreshQueued then
        return
    end

    PlayerBars.Group.refreshQueued = true
    if zo_callLater then
        zo_callLater(PlayerBars.Group.RefreshFrame, C.APPLY_DELAY_MS)
    else
        PlayerBars.Group.RefreshFrame()
    end
end
function PlayerBars.Group.OnAttributeVisualChanged(_, unitTag, visualType, stat, attribute, powerType)
    if not runtimeActive or not unitTag or not ZO_Group_IsGroupUnitTag or not ZO_Group_IsGroupUnitTag(unitTag) then
        return
    end

    if PlayerBars.IsPlayerHealthVisual(visualType, stat, attribute, powerType) then
        if not PlayerBars.Group.UpdateRowHealth(unitTag) then
            PlayerBars.Group.QueueRefresh()
        end
    end
end

function PlayerBars.Group.IsGroupOrGroupCompanionUnitTag(unitTag)
    if not unitTag then
        return false
    end

    if ZO_Group_IsGroupUnitTag and ZO_Group_IsGroupUnitTag(unitTag) then
        return true
    end

    return IsGroupCompanionUnitTag and IsGroupCompanionUnitTag(unitTag) == true
end
