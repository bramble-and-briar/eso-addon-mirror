-- SimpleWarhornTimer - buff timer UI plus standalone chat uptime.
-- Standalone buff uptime for chat; lightweight UI for active buff timers.

local ADDON_NAME = "SimpleWarhornTimer"
local ADDON_VERSION = "1.4.19"
local wm = WINDOW_MANAGER
local DAMAGE_INACTIVITY_MS = 2000
local LIBCOMBAT_RETRY_DELAY_MS = 1000
local LIBCOMBAT_MAX_RETRIES = 8
local AUTO_DETECT_MAX_DURATION_MS = 180000
local AUTO_DETECT_DATA_VERSION = 2
local MAIN_UI_MOVE_MODE_TIMEOUT_MS = 3000
local MAIN_UI_MOVE_SPEED = 22
local SUMMARY_WINDOW_WIDTH = 520
local SUMMARY_WINDOW_MIN_HEIGHT = 180
local SUMMARY_WINDOW_INNER_WIDTH = 480
local SUMMARY_WINDOW_ROW_TOP = 102
local SUMMARY_WINDOW_ROW_SPACING = 30
local SUMMARY_WINDOW_ROW_HEIGHT = 28
local SUMMARY_WINDOW_BOTTOM_PADDING = 22

---------------------------------------------------------
-- Buff configuration
---------------------------------------------------------
local trackedBuffs = {
    [38564]  = { name = "Warhorn",             color = {0.4, 0.6, 1.0, 1} },
    [93109]  = { name = "Major Slayer",        color = {1.0, 0.4, 0.0, 1} },
    [61745]  = { name = "Major Berserk",       color = {1.0, 0.2, 0.6, 1} },
    [61771]  = { name = "Powerful Assault",    color = {0.5, 1.0, 0.3, 1} },
    [61665]  = { name = "Major Brutality",     color = {1.0, 0.5, 0.0, 1} },
    [109966] = { name = "Major Courage",       color = {0.6, 0.4, 1.0, 1} },
    [61747]  = { name = "Major Force",         color = {0.2, 0.9, 0.9, 1} },
    [172055] = { name = "Pillager's Profit",   color = {1.0, 0.9, 0.2, 1} },
    [147417] = { name = "Minor Courage",       color = {0.6, 0.2, 1.0, 1} },
    [61744]  = { name = "Minor Berserk",       color = {0.8, 0.2, 0.8, 1} },
    [61693]  = { name = "Minor Resolve",       color = {0.4, 1.0, 0.7, 1} },
}

local trackedBuffOrder = {
    38564,
    93109,
    61745,
    61771,
    61665,
    109966,
    61747,
    172055,
    147417,
    61744,
    61693,
}

local mainUIBuffOrder = {}
for i, id in ipairs(trackedBuffOrder) do
    mainUIBuffOrder[i] = id
end

local trackedAliases = {
    -- Major Slayer
    [93120] = 93109,
    [93442] = 93109,
    [121871] = 93109,
    [137986] = 93109,
    [177886] = 93109,
    [214407] = 93109,
    -- Major Berserk
    [36973] = 61745,
    [62195] = 61745,
    [84310] = 61745,
    [134094] = 61745,
    [134433] = 61745,
    [137206] = 61745,
    [143992] = 61745,
    [147421] = 61745,
    [150757] = 61745,
    [172866] = 61745,
    [188408] = 61745,
    [219674] = 61745,
    [221601] = 61745,
    [237956] = 61745,
    -- Major Brutality
    [23673] = 61665,
    [36903] = 61665,
    [45228] = 61665,
    [45393] = 61665,
    [61670] = 61665,
    [62060] = 61665,
    [62147] = 61665,
    [62387] = 61665,
    [62415] = 61665,
    [63768] = 61665,
    [64554] = 61665,
    [64555] = 61665,
    [68807] = 61665,
    [72936] = 61665,
    [76518] = 61665,
    [81517] = 61665,
    [86695] = 61665,
    [89110] = 61665,
    [95419] = 61665,
    [104013] = 61665,
    [116371] = 61665,
    [126647] = 61665,
    [126670] = 61665,
    [131340] = 61665,
    [131341] = 61665,
    [131342] = 61665,
    [131343] = 61665,
    [131346] = 61665,
    [131350] = 61665,
    [137193] = 61665,
    [163656] = 61665,
    [168273] = 61665,
    [168282] = 61665,
    [168447] = 61665,
    [176701] = 61665,
    [183049] = 61665,
    [207429] = 61665,
    [215505] = 61665,
    [228041] = 61665,
    [228043] = 61665,
    [228045] = 61665,
    [237721] = 61665,
    [217790] = 61665,
    [238025] = 61665,
    -- Major Courage
    [66902] = 109966,
    [109994] = 109966,
    [110020] = 109966,
    [120015] = 109966,
    [172867] = 109966,
    [187904] = 109966,
    [221536] = 109966,
    [214431] = 109966,
    -- Major Force
    [46522] = 61747,
    [46533] = 61747,
    [46536] = 61747,
    [46539] = 61747,
    [5159289] = 61747,
    [40225] = 61747,
    [85154] = 61747,
    [120013] = 61747,
    [154830] = 61747,
    [176849] = 61747,
    [214424] = 61747,
    [221602] = 61747,
    [238550] = 61747,
    -- Minor Courage
    [121878] = 147417,
    [137348] = 147417,
    [159310] = 147417,
    [159341] = 147417,
    [159352] = 147417,
    [159356] = 147417,
    [160394] = 147417,
    [175664] = 147417,
    [172721] = 147417,
    [176883] = 147417,
    [177885] = 147417,
    [187940] = 147417,
    [183579] = 147417,
    [186230] = 147417,
    [186235] = 147417,
    [214410] = 147417,
    [217967] = 147417,
    [236475] = 147417,
    -- Minor Berserk
    [62636] = 61744,
    [80471] = 61744,
    [80481] = 61744,
    [114862] = 61744,
    [120008] = 61744,
    [150782] = 61744,
    [174982] = 61744,
    [175655] = 61744,
    [176704] = 61744,
    [196184] = 61744,
    [123323] = 61744,
    [218988] = 61744,
    [214428] = 61744,
    [237972] = 61744,
    [238541] = 61744,
    -- Minor Resolve has many source IDs that belong to the same effect.
    [37247] = 61693,
    [61817] = 61693,
    [62626] = 61693,
    [62634] = 61693,
    [108856] = 61693,
    [159311] = 61693,
    [159340] = 61693,
    [159350] = 61693,
    [159358] = 61693,
    [174981] = 61693,
    [176991] = 61693,
    [183424] = 61693,
    [185913] = 61693,
    [186490] = 61693,
    [221104] = 61693,
    [228053] = 61693,
    [228054] = 61693,
    [228063] = 61693,
    [238264] = 61693,
}

---------------------------------------------------------
-- Saved vars / settings
---------------------------------------------------------
local defaults = {
    showGroupUptime = true,
    posX = 300,
    posY = 300,
    summaryPosX = 520,
    summaryPosY = 260,
    summaryScale = 1.0,
    scale = 1.0,
    showUI = true,
    chatSummary = true,
    autoDetectBuffs = true,
    autoDetectPlayerSourceOnly = false,
    debug = false,
    autoDetectDataVersion = AUTO_DETECT_DATA_VERSION,
    lastSummary = {},
    enabledBuffs = {},
    detectedBuffs = {},
    customTrackedBuffs = {},
}
-- enable all tracked buffs by default
do
    if defaults.enabledBuffs == nil then defaults.enabledBuffs = {} end
    for _, id in ipairs(trackedBuffOrder) do
        defaults.enabledBuffs[tostring(id)] = true
    end
end

local settings

---------------------------------------------------------
-- Fight state & interval storage
---------------------------------------------------------
local fightStartTime = nil
local fightEndTime = nil
local activeStartTime = nil
local activeEndTime = nil
local inactiveCheckToken = 0

local playerSourceUnitScopes = {}
local groupUnitScopes = {}
local playerReceivedScopes = {}
local playerReceivedSourceScopes = {}
local seenGroupUnits = {}
local damageCombatResults = {}
local preFightEffectBuffer = {}
local useLibCombat = false
local libCombatBuffData = {}
local libCombatEffectLog = {}
local libCombatEffectSeq = 0
local libCombatPrebuffBackfilled = false
local libCombatBackfillSlots = {}
local libCombatActiveAtStart = {}
local fightDurationOverrideMS = nil
local summaryPrinted = false
local lastSummaryData = { durationMS = 0, entries = {} }
local refreshSummaryWindow
local refreshTrackedSettingsMenu
local settingsAddon
local libCombatRegistered = false
local rawModeRegistered = false
local libCombatRetryCount = 0
local libCombatRetryScheduled = false

---------------------------------------------------------
-- Utils
---------------------------------------------------------
local function nowMS() return GetGameTimeMilliseconds() end

local function insertInterval(t, s, e)
    if s and e and e > s then
        t[#t + 1] = { s, e }
    end
end

local function mergeIntervals(intervals)
    if not intervals or #intervals == 0 then return {} end
    table.sort(intervals, function(a,b) return a[1] < b[1] end)
    local merged = { { intervals[1][1], intervals[1][2] } }
    for i = 2, #intervals do
        local prev = merged[#merged]
        local cur  = intervals[i]
        if cur[1] <= prev[2] then
            if cur[2] > prev[2] then prev[2] = cur[2] end
        else
            merged[#merged + 1] = { cur[1], cur[2] }
        end
    end
    return merged
end

local function clipToFightWindowAndMerge(intervals, fs, fe)
    if not intervals or not fs or not fe then return {} end
    local clipped = {}
    for _, iv in ipairs(intervals) do
        local s, e = iv[1], iv[2]
        if not e then e = fe end
        if e > fs and s < fe then
            if s < fs then s = fs end
            if e > fe then e = fe end
            if e > s then insertInterval(clipped, s, e) end
        end
    end
    return mergeIntervals(clipped)
end

local function totalDuration(intervals)
    local sum = 0
    for _, iv in ipairs(intervals) do
        sum = sum + (iv[2] - iv[1])
    end
    return sum
end

local function pctInt(p)
    if not p or p < 0 then return 0 end
    return math.floor(p)
end

local function countInt(value)
    if not value or value < 0 then return 0 end
    return math.floor(value + 0.5)
end

local function isGroupTag(tag)
    return tag == "player" or (type(tag) == "string" and string.match(tag, "^group%d+$") ~= nil)
end

local function formatDisplayName(name)
    if not name or name == "" then return nil end
    return zo_strformat("<<t:1>>", name)
end

local function normalizeName(name)
    local formattedName = formatDisplayName(name)
    if not formattedName or formattedName == "" then return nil end
    return string.lower(formattedName)
end

local trackedIdCache = {}
local trackedNameLookup = nil

local function getTrackedNameLookup()
    if trackedNameLookup then return trackedNameLookup end

    trackedNameLookup = {}
    for id, info in pairs(trackedBuffs) do
        local abilityName = GetAbilityName and GetAbilityName(id)
        local normalizedAbilityName = normalizeName(abilityName)
        local fallbackName = normalizeName(info.name)

        if normalizedAbilityName then trackedNameLookup[normalizedAbilityName] = id end
        if fallbackName then trackedNameLookup[fallbackName] = id end
    end

    return trackedNameLookup
end

local function getTrackedId(abilityId)
    if not abilityId then return nil end
    if trackedAliases[abilityId] then return trackedAliases[abilityId] end
    if trackedBuffs[abilityId] then return abilityId end

    local cached = trackedIdCache[abilityId]
    if cached ~= nil then
        return cached or nil
    end

    local abilityName = normalizeName(GetAbilityName and GetAbilityName(abilityId))
    local trackedId = abilityName and getTrackedNameLookup()[abilityName] or nil
    trackedIdCache[abilityId] = trackedId or false
    return trackedId
end

local function isTrackedEnabled(abilityId)
    local trackedId = getTrackedId(abilityId)
    return trackedId and settings and settings.enabledBuffs and settings.enabledBuffs[tostring(trackedId)], trackedId
end

local function addDamageResultConstant(name)
    local value = _G[name]
    if value ~= nil then
        damageCombatResults[value] = true
    end
end

addDamageResultConstant("ACTION_RESULT_DAMAGE")
addDamageResultConstant("ACTION_RESULT_CRITICAL_DAMAGE")
addDamageResultConstant("ACTION_RESULT_DOT_TICK")
addDamageResultConstant("ACTION_RESULT_DOT_TICK_CRITICAL")
addDamageResultConstant("ACTION_RESULT_BLOCKED_DAMAGE")
addDamageResultConstant("ACTION_RESULT_DAMAGE_SHIELDED")
addDamageResultConstant("ACTION_RESULT_PRECISE_DAMAGE")
addDamageResultConstant("ACTION_RESULT_WRECKING_DAMAGE")

local function isCombatUnitType(unitType, constantName)
    local value = _G[constantName]
    return value ~= nil and unitType == value
end

local function isFriendlyCombatType(unitType)
    return isCombatUnitType(unitType, "COMBAT_UNIT_TYPE_PLAYER")
        or isCombatUnitType(unitType, "COMBAT_UNIT_TYPE_PLAYER_PET")
        or isCombatUnitType(unitType, "COMBAT_UNIT_TYPE_GROUP")
        or isCombatUnitType(unitType, "COMBAT_UNIT_TYPE_GROUP_PET")
end

local function isPlayerSourceType(unitType)
    return isCombatUnitType(unitType, "COMBAT_UNIT_TYPE_PLAYER")
        or isCombatUnitType(unitType, "COMBAT_UNIT_TYPE_PLAYER_PET")
end

local function isRelevantCombatEvent(result, sourceType, targetType, hitValue)
    if not damageCombatResults[result] then return false end
    if hitValue and hitValue <= 0 then return false end

    local sourceFriendly = isFriendlyCombatType(sourceType)
    local targetFriendly = isFriendlyCombatType(targetType)
    return sourceFriendly and not targetFriendly
end

local function touchActiveCombat(timeMS)
    if not fightStartTime then
        fightStartTime = timeMS
    end
    if not activeStartTime then
        activeStartTime = timeMS
    end
    activeEndTime = timeMS
end

local function getGroupTags()
    local tags = { "player" }
    local added = { player = true }
    local groupSize = GetGroupSize and GetGroupSize() or 0

    for i = 1, groupSize do
        local tag = GetGroupUnitTagByIndex and GetGroupUnitTagByIndex(i) or ("group" .. i)
        local isPlayer = AreUnitsEqual and AreUnitsEqual(tag, "player")
        if tag and DoesUnitExist(tag) and not isPlayer and not added[tag] then
            tags[#tags + 1] = tag
            added[tag] = true
        end
    end

    return tags
end

local function getSlotKey(unitTag, abilityId, effectSlot)
    if effectSlot and effectSlot ~= 0 then
        return tostring(unitTag) .. ":" .. tostring(effectSlot)
    end
    return tostring(unitTag) .. ":" .. tostring(abilityId)
end

local function isBuffStillActive(endTime)
    if not endTime or endTime <= 0 or not GetFrameTimeSeconds then return false end
    return endTime > GetFrameTimeSeconds()
end

local function getDisplayName(abilityId)
    local info = trackedBuffs[abilityId]
    local name = formatDisplayName(GetAbilityName(abilityId))
    if not name or name == "" then
        name = formatDisplayName(info and info.name) or tostring(abilityId)
    end
    return name
end

local CUSTOM_TRACKED_COLORS = {
    { 0.94, 0.76, 0.24, 1.0 },
    { 0.30, 0.82, 1.00, 1.0 },
    { 0.60, 0.88, 0.38, 1.0 },
    { 0.96, 0.46, 0.28, 1.0 },
    { 0.82, 0.48, 0.96, 1.0 },
    { 0.98, 0.88, 0.38, 1.0 },
}

local function resetTrackedLookups()
    trackedIdCache = {}
    trackedNameLookup = nil
end

local function getAutoTrackedColor(abilityId)
    local paletteIndex = ((tonumber(abilityId) or 0) % #CUSTOM_TRACKED_COLORS) + 1
    local color = CUSTOM_TRACKED_COLORS[paletteIndex]
    return { color[1], color[2], color[3], color[4] }
end

local function isBuffEffectType(effectType)
    local buffTypeConstant = _G.BUFF_EFFECT_TYPE_BUFF
    if buffTypeConstant == nil or effectType == nil then
        return true
    end
    return effectType == buffTypeConstant
end

local function hasReasonableDetectDuration(beginTime, endTime)
    if not beginTime or not endTime or beginTime <= 0 or endTime <= 0 then
        return true
    end

    local durationMS = math.floor((endTime - beginTime) * 1000 + 0.5)
    if durationMS <= 0 then
        return false
    end

    return durationMS <= AUTO_DETECT_MAX_DURATION_MS
end

local function isAutoDetectActive()
    return fightStartTime ~= nil
        or activeStartTime ~= nil
        or (IsUnitInCombat and IsUnitInCombat("player"))
end

local function ensureSettingsTables()
    if not settings then return end
    settings.enabledBuffs = settings.enabledBuffs or {}
    settings.detectedBuffs = settings.detectedBuffs or {}
    settings.customTrackedBuffs = settings.customTrackedBuffs or {}
end

local function registerTrackedBuff(abilityId, name, color, persist)
    abilityId = tonumber(abilityId)
    if not abilityId or abilityId <= 0 then return nil end

    local existing = trackedBuffs[abilityId]
    local resolvedName = formatDisplayName(name)
        or formatDisplayName(GetAbilityName and GetAbilityName(abilityId))
        or (existing and existing.name)
        or tostring(abilityId)
    local resolvedColor = color
        or (existing and existing.color)
        or getAutoTrackedColor(abilityId)

    trackedBuffs[abilityId] = {
        name = resolvedName,
        color = { unpack(resolvedColor) },
    }

    local alreadyTracked = false
    for _, trackedId in ipairs(trackedBuffOrder) do
        if trackedId == abilityId then
            alreadyTracked = true
            break
        end
    end
    if not alreadyTracked then
        trackedBuffOrder[#trackedBuffOrder + 1] = abilityId
    end

    if settings then
        ensureSettingsTables()
        if settings.enabledBuffs[tostring(abilityId)] == nil then
            settings.enabledBuffs[tostring(abilityId)] = true
        end

        if persist then
            settings.customTrackedBuffs[tostring(abilityId)] = {
                id = abilityId,
                name = resolvedName,
                color = { unpack(resolvedColor) },
                addedAt = GetTimeStamp and GetTimeStamp() or 0,
            }
        end
    end

    resetTrackedLookups()
    return trackedBuffs[abilityId]
end

local function loadCustomTrackedBuffs()
    if not settings or type(settings.customTrackedBuffs) ~= "table" then return end

    local customEntries = {}
    for key, entry in pairs(settings.customTrackedBuffs) do
        local entryId = tonumber((type(entry) == "table" and entry.id) or key)
        if entryId and entryId > 0 then
            customEntries[#customEntries + 1] = {
                id = entryId,
                name = type(entry) == "table" and entry.name or nil,
                color = type(entry) == "table" and entry.color or nil,
                addedAt = type(entry) == "table" and (tonumber(entry.addedAt) or 0) or 0,
            }
        end
    end

    table.sort(customEntries, function(a, b)
        if a.addedAt ~= b.addedAt then
            return a.addedAt < b.addedAt
        end
        return a.id < b.id
    end)

    for _, entry in ipairs(customEntries) do
        registerTrackedBuff(entry.id, entry.name, entry.color, false)
    end
end

local function rememberDetectedBuff(abilityId, sourceType, unitTag, castByPlayer, effectType, beginTime, endTime)
    if not settings or not settings.autoDetectBuffs then return end
    abilityId = tonumber(abilityId)
    if not abilityId or abilityId <= 0 then return end
    if unitTag and unitTag ~= "group" and not isGroupTag(unitTag) then return end
    if not isAutoDetectActive() then return end
    if not isBuffEffectType(effectType) then return end
    if not hasReasonableDetectDuration(beginTime, endTime) then return end
    local existingTrackedId = getTrackedId(abilityId)
    if existingTrackedId then return existingTrackedId end

    local fromPlayer = castByPlayer == true or isPlayerSourceType(sourceType)
    if settings.autoDetectPlayerSourceOnly and not fromPlayer then return end

    local name = formatDisplayName(GetAbilityName and GetAbilityName(abilityId))
    if not name or name == "" then return end

    ensureSettingsTables()

    local key = tostring(abilityId)
    local entry = settings.detectedBuffs[key] or {
        id = abilityId,
        name = name,
        icon = "",
        seenCount = 0,
        lastSeenAt = 0,
        seenOnPlayer = false,
        seenOnGroup = false,
        seenFromPlayer = false,
    }

    entry.id = abilityId
    entry.name = name
    entry.icon = (GetAbilityIcon and GetAbilityIcon(abilityId)) or entry.icon or ""
    entry.seenCount = (tonumber(entry.seenCount) or 0) + 1
    entry.lastSeenAt = GetTimeStamp and GetTimeStamp() or 0
    entry.seenOnPlayer = entry.seenOnPlayer or unitTag == "player"
    entry.seenOnGroup = entry.seenOnGroup
        or unitTag == "group"
        or (type(unitTag) == "string" and string.match(unitTag, "^group%d+$") ~= nil)
    entry.seenFromPlayer = entry.seenFromPlayer or fromPlayer

    settings.detectedBuffs[key] = entry
    registerTrackedBuff(abilityId, entry.name, nil, true)

    if refreshTrackedSettingsMenu then
        if zo_callLater then
            zo_callLater(refreshTrackedSettingsMenu, 0)
        else
            refreshTrackedSettingsMenu()
        end
    end

    if refreshSummaryWindow then
        if zo_callLater then
            zo_callLater(refreshSummaryWindow, 0)
        else
            refreshSummaryWindow()
        end
    end

    return abilityId
end

local function cloneSummaryData(summaryData)
    local copy = {
        durationMS = 0,
        entries = {},
    }

    if type(summaryData) ~= "table" then
        return copy
    end

    copy.durationMS = tonumber(summaryData.durationMS) or 0

    for _, entry in ipairs(summaryData.entries or {}) do
        copy.entries[#copy.entries + 1] = {
            id = tonumber(entry.id) or 0,
            name = formatDisplayName(entry.name) or "",
            playerPct = tonumber(entry.playerPct) or 0,
            groupPct = tonumber(entry.groupPct) or 0,
            playerCount = tonumber(entry.playerCount) or 0,
            groupCount = tonumber(entry.groupCount) or 0,
            color = { unpack(entry.color or {1, 1, 1, 1}) },
        }
    end

    return copy
end

local function setLastSummaryData(summaryData)
    lastSummaryData = cloneSummaryData(summaryData)
    if settings then
        settings.lastSummary = cloneSummaryData(lastSummaryData)
    end
    if refreshSummaryWindow then
        refreshSummaryWindow()
    end
end

local function ensureScope(scopeTable, abilityId)
    local scope = scopeTable[abilityId]
    if not scope then
        scope = {
            intervals = {},
            activeSlots = {},
            activeCount = 0,
            startTime = nil,
        }
        scopeTable[abilityId] = scope
    end
    return scope
end

local function openScope(scopeTable, abilityId, slotKey, timeMS)
    local scope = ensureScope(scopeTable, abilityId)
    if scope.activeSlots[slotKey] then return end

    if scope.activeCount == 0 then
        scope.startTime = timeMS
    end

    scope.activeSlots[slotKey] = true
    scope.activeCount = scope.activeCount + 1
end

local function closeScope(scopeTable, abilityId, slotKey, timeMS)
    local scope = scopeTable[abilityId]
    if not scope or not scope.activeSlots[slotKey] then return end

    scope.activeSlots[slotKey] = nil
    scope.activeCount = math.max(0, scope.activeCount - 1)

    if scope.activeCount == 0 and scope.startTime then
        insertInterval(scope.intervals, scope.startTime, timeMS)
        scope.startTime = nil
    end
end

local function closeAllScopes(scopeTable, timeMS)
    for _, scope in pairs(scopeTable) do
        if scope.activeCount > 0 and scope.startTime then
            insertInterval(scope.intervals, scope.startTime, timeMS)
        end
        scope.activeSlots = {}
        scope.activeCount = 0
        scope.startTime = nil
    end
end

local function ensureUnitScopes(scopeTable, unitTag)
    local unit = scopeTable[unitTag]
    if not unit then
        unit = { abilities = {} }
        scopeTable[unitTag] = unit
    end
    return unit.abilities
end

local function openUnitScope(scopeTable, unitTag, abilityId, slotKey, timeMS)
    seenGroupUnits[unitTag] = true
    openScope(ensureUnitScopes(scopeTable, unitTag), abilityId, slotKey, timeMS)
end

local function closeUnitScope(scopeTable, unitTag, abilityId, slotKey, timeMS)
    seenGroupUnits[unitTag] = true
    local unit = scopeTable[unitTag]
    if not unit then return end
    closeScope(unit.abilities, abilityId, slotKey, timeMS)
end

local function closeAllUnitScopes(scopeTable, timeMS)
    for _, unit in pairs(scopeTable) do
        closeAllScopes(unit.abilities, timeMS)
    end
end

local function getLiveScopeIntervals(scopeTable, abilityId, startTime, endTime)
    local intervals = {}
    local scope = scopeTable[abilityId]
    if not scope then return {} end

    for _, interval in ipairs(scope.intervals or {}) do
        intervals[#intervals + 1] = { interval[1], interval[2] }
    end

    if scope.activeCount > 0 and scope.startTime then
        intervals[#intervals + 1] = { scope.startTime, endTime }
    end

    return clipToFightWindowAndMerge(intervals, startTime, endTime)
end

local function getLiveScopeTotal(scopeTable, abilityId, startTime, endTime)
    return totalDuration(getLiveScopeIntervals(scopeTable, abilityId, startTime, endTime))
end

local function getLiveScopeCount(scopeTable, abilityId, startTime, endTime)
    return #getLiveScopeIntervals(scopeTable, abilityId, startTime, endTime)
end

local function getLiveGroupTotal(scopeTable, abilityId, startTime, endTime)
    local total = 0
    for _, unit in pairs(scopeTable) do
        total = total + getLiveScopeTotal(unit.abilities, abilityId, startTime, endTime)
    end
    return total
end

local function countSeenUnits()
    local count = 0
    for _ in pairs(seenGroupUnits) do
        count = count + 1
    end
    return count
end

local function getGroupUnitCount()
    return math.max(1, countSeenUnits(), #getGroupTags())
end

local function getFightWindow()
    local startTime = activeStartTime or fightStartTime
    local endTime = activeEndTime or fightEndTime or nowMS()
    if not startTime then return nil, nil, 0 end

    if fightEndTime and endTime > fightEndTime then
        endTime = fightEndTime
    end

    return startTime, endTime, fightDurationOverrideMS or math.max(1000, endTime - startTime)
end

local function getBuffStartMS(beginTime, fallbackMS)
    if beginTime and beginTime > 0 and GetFrameTimeSeconds then
        local elapsedMS = math.max(0, (GetFrameTimeSeconds() - beginTime) * 1000)
        return nowMS() - elapsedMS
    end
    return fallbackMS
end

-- Backfill active buffs at the first real player combat action.
---------------------------------------------------------
local function backfillActiveBuffsAtCombatStart(startMS)
    local fs = startMS or activeStartTime or fightStartTime or nowMS()
    local unitTag = "player"

    local buffCount = GetNumBuffs(unitTag) or 0
    for i = 1, buffCount do
        local _, beginTime, endTime, effectSlot, _, _, _, effectType, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo(unitTag, i)
        local enabled, trackedId = isTrackedEnabled(abilityId)
        if not enabled then
            trackedId = rememberDetectedBuff(abilityId, nil, unitTag, castByPlayer, effectType, beginTime, endTime) or trackedId
            enabled = trackedId and settings.enabledBuffs[tostring(trackedId)]
        end
        if enabled and isBuffStillActive(endTime) then
            local slotKey = getSlotKey(unitTag, abilityId, effectSlot)
            local startMS = math.max(fs, getBuffStartMS(beginTime, fs))
            openUnitScope(groupUnitScopes, unitTag, trackedId, slotKey, startMS)
            openScope(playerReceivedScopes, trackedId, slotKey, startMS)
            if castByPlayer then
                openUnitScope(playerSourceUnitScopes, unitTag, trackedId, slotKey, startMS)
                openScope(playerReceivedSourceScopes, trackedId, slotKey, startMS)
            end
        end
    end

    for key, data in pairs(preFightEffectBuffer) do
        if isBuffStillActive(data.endTime) then
            openUnitScope(groupUnitScopes, data.unitTag, data.trackedId, data.slotKey, fs)
            if isPlayerSourceType(data.sourceType) then
                openUnitScope(playerSourceUnitScopes, data.unitTag, data.trackedId, data.slotKey, fs)
            end
        end
        preFightEffectBuffer[key] = nil
    end
end

---------------------------------------------------------
-- Event handlers
---------------------------------------------------------
local function onEffectChanged(_, changeType, effectSlot, _, unitTag, beginTime, endTime, _, _, _, effectType, _, _, _, _, abilityId, sourceType)
    local enabled, trackedId = isTrackedEnabled(abilityId)
    if not enabled then
        if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
            trackedId = rememberDetectedBuff(abilityId, sourceType, unitTag, false, effectType, beginTime, endTime) or trackedId
            enabled = trackedId and settings.enabledBuffs[tostring(trackedId)]
        end
        if not enabled then
            return
        end
    end

    local t = nowMS()
    local slotKey = getSlotKey(unitTag, abilityId, effectSlot)

    if not fightStartTime then
        if isGroupTag(unitTag) and unitTag ~= "player" then
            if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
                if isBuffStillActive(endTime) then
                    preFightEffectBuffer[slotKey] = {
                        unitTag = unitTag,
                        trackedId = trackedId,
                        slotKey = slotKey,
                        sourceType = sourceType,
                        endTime = endTime,
                    }
                else
                    preFightEffectBuffer[slotKey] = nil
                end
            elseif changeType == EFFECT_RESULT_FADED then
                preFightEffectBuffer[slotKey] = nil
            end
        end
        return
    end

    if isGroupTag(unitTag) then
        if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
            openUnitScope(groupUnitScopes, unitTag, trackedId, slotKey, t)
            if unitTag == "player" then
                openScope(playerReceivedScopes, trackedId, slotKey, t)
            end
            if isPlayerSourceType(sourceType) then
                openUnitScope(playerSourceUnitScopes, unitTag, trackedId, slotKey, t)
                if unitTag == "player" then
                    openScope(playerReceivedSourceScopes, trackedId, slotKey, t)
                end
            end
            if settings.debug then d(string.format("[%s] open %d as %d %s slot %s", ADDON_NAME, abilityId, trackedId, unitTag, tostring(effectSlot))) end
        elseif changeType == EFFECT_RESULT_FADED then
            closeUnitScope(groupUnitScopes, unitTag, trackedId, slotKey, t)
            closeUnitScope(playerSourceUnitScopes, unitTag, trackedId, slotKey, t)
            if unitTag == "player" then
                closeScope(playerReceivedScopes, trackedId, slotKey, t)
                closeScope(playerReceivedSourceScopes, trackedId, slotKey, t)
            end
            if settings.debug then d(string.format("[%s] close %d as %d %s slot %s", ADDON_NAME, abilityId, trackedId, unitTag, tostring(effectSlot))) end
        end
    end
end

local function finalizeOpenIntervalsAtCombatEnd(fe)
    closeAllUnitScopes(groupUnitScopes, fe)
    closeAllUnitScopes(playerSourceUnitScopes, fe)
    closeAllScopes(playerReceivedScopes, fe)
    closeAllScopes(playerReceivedSourceScopes, fe)
end

local function resetUptime()
    fightStartTime = nil
    fightEndTime = nil
    activeStartTime = nil
    activeEndTime = nil
    inactiveCheckToken = inactiveCheckToken + 1
    playerSourceUnitScopes = {}
    groupUnitScopes = {}
    playerReceivedScopes = {}
    playerReceivedSourceScopes = {}
    seenGroupUnits = {}
    preFightEffectBuffer = {}
    libCombatBuffData = {}
    libCombatEffectLog = {}
    libCombatEffectSeq = 0
    libCombatPrebuffBackfilled = false
    libCombatBackfillSlots = {}
    libCombatActiveAtStart = {}
    fightDurationOverrideMS = nil
    summaryPrinted = false
end

local function buildUptimeSummaryData()
    local fs, fe, fightDur = getFightWindow()
    if not fs then return nil end

    local summaryData = {
        durationMS = fightDur,
        entries = {},
    }

    for _, id in ipairs(trackedBuffOrder) do
        if settings.enabledBuffs[tostring(id)] then
            local info = trackedBuffs[id]
            local playerPct = (getLiveScopeTotal(playerReceivedSourceScopes, id, fs, fe) / fightDur) * 100
            local groupPct = (getLiveScopeTotal(playerReceivedScopes, id, fs, fe) / fightDur) * 100
            local playerCount = getLiveScopeCount(playerReceivedSourceScopes, id, fs, fe)
            local groupCount = getLiveScopeCount(playerReceivedScopes, id, fs, fe)
            local libData = useLibCombat and libCombatBuffData[id]
            if libData then
                playerPct = (libData.uptime / fightDur) * 100
                groupPct = (libData.groupUptime / fightDur) * 100
                playerCount = countInt(libData.count)
                groupCount = countInt(libData.groupCount)
            end

            summaryData.entries[#summaryData.entries + 1] = {
                id = id,
                name = getDisplayName(id),
                playerPct = pctInt(math.min(100, math.max(0, playerPct))),
                groupPct = pctInt(math.min(100, math.max(0, groupPct))),
                playerCount = countInt(playerCount),
                groupCount = countInt(groupCount),
                color = { unpack((info and info.color) or {1, 1, 1, 1}) },
            }
        end
    end

    table.sort(summaryData.entries, function(a, b)
        local aScore = math.max(a.playerPct or 0, a.groupPct or 0)
        local bScore = math.max(b.playerPct or 0, b.groupPct or 0)
        if aScore == bScore then
            return (a.name or "") < (b.name or "")
        end
        return aScore > bScore
    end)

    return summaryData
end

local function getSummaryWindowData()
    if fightStartTime and not summaryPrinted then
        return buildUptimeSummaryData(), true
    end

    return lastSummaryData or { durationMS = 0, entries = {} }, false
end

local function printUptimeSummary(summaryData)
    summaryData = summaryData or buildUptimeSummaryData()
    if not summaryData then return end

    local shownAny = false

    d(string.format("|c88CCFF[%s]|r Kampfende (%ds). Buff-Uptime:", ADDON_NAME, math.floor((summaryData.durationMS / 1000) + 0.5)))

    for _, entry in ipairs(summaryData.entries) do
        if entry.playerPct > 0 or entry.groupPct > 0 or entry.playerCount > 0 or entry.groupCount > 0 then
            if settings.showGroupUptime then
                d(string.format(" - %s: Du %d%% (%dx) / Gruppe %d%% (%dx)", entry.name, entry.playerPct, entry.playerCount, entry.groupPct, entry.groupCount))
            else
                d(string.format(" - %s: Du %d%% (%dx)", entry.name, entry.playerPct, entry.playerCount))
            end
            shownAny = true
        end
    end

    if not shownAny then
        d(" - Keine getrackten Buffs gesehen.")
    end
end

local function finalizeUptimeSummaryOnce()
    if summaryPrinted then return end
    local summaryData = buildUptimeSummaryData()
    if not summaryData then return end
    summaryPrinted = true
    setLastSummaryData(summaryData)
    if settings.chatSummary then
        printUptimeSummary(summaryData)
    end
end

local function finishInactiveFight(token, expectedEndTime)
    if token ~= inactiveCheckToken then return end
    if not fightStartTime or not activeStartTime or not activeEndTime then return end
    if activeEndTime ~= expectedEndTime then return end

    if IsUnitInCombat and IsUnitInCombat("player") then
        zo_callLater(function()
            finishInactiveFight(token, expectedEndTime)
        end, DAMAGE_INACTIVITY_MS)
        return
    end

    local elapsed = nowMS() - activeEndTime
    if elapsed < DAMAGE_INACTIVITY_MS then
        zo_callLater(function()
            finishInactiveFight(token, expectedEndTime)
        end, DAMAGE_INACTIVITY_MS - elapsed)
        return
    end

    fightEndTime = activeEndTime
    finalizeOpenIntervalsAtCombatEnd(fightEndTime)

    finalizeUptimeSummaryOnce()

    if settings.debug then
        d(string.format("[%s] inactive fight end %d", ADDON_NAME, fightEndTime))
    end

    resetUptime()
end

local function scheduleInactiveFightEnd()
    if not zo_callLater or not activeEndTime then return end

    inactiveCheckToken = inactiveCheckToken + 1
    local token = inactiveCheckToken
    local expectedEndTime = activeEndTime

    zo_callLater(function()
        finishInactiveFight(token, expectedEndTime)
    end, DAMAGE_INACTIVITY_MS)
end

local function onCombatEvent(_, result, isError, _, _, _, _, sourceType, _, targetType, hitValue)
    if isError or not settings then return end
    if not isRelevantCombatEvent(result, sourceType, targetType, hitValue) then return end

    local t = nowMS()
    if not fightStartTime then
        fightStartTime = t
    end
    if not activeStartTime then
        backfillActiveBuffsAtCombatStart(t)
    end
    touchActiveCombat(t)
    scheduleInactiveFightEnd()
end

local function onPlayerCombatState(_, inCombat)
    if inCombat then
        if not fightStartTime then
            resetUptime()
            fightStartTime = nowMS()
            activeStartTime = fightStartTime
            activeEndTime = fightStartTime
            backfillActiveBuffsAtCombatStart(fightStartTime)
        end
        if settings.debug then d(string.format("[%s] combat state start", ADDON_NAME)) end
    else
        if fightStartTime then
            fightEndTime = nowMS()
            activeEndTime = fightEndTime
            if settings.debug then d(string.format("[%s] combat end %d", ADDON_NAME, fightEndTime)) end

            finalizeOpenIntervalsAtCombatEnd(fightEndTime)

            if activeStartTime then
                finalizeUptimeSummaryOnce()
            end
        end
        resetUptime()
    end
end

-- LibCombat path. Uses only the combat event library for accurate fight timing.
---------------------------------------------------------
local function getLibCombatConstant(name)
    local LC = LibCombat
    return _G["LIBCOMBAT_" .. name]
        or (LC and LC["LIBCOMBAT_" .. name])
        or (LC and LC[name])
end

local function getLibCombatSlotKey(unitId, abilityId, effectSlot)
    return string.format("lc:%s:%s:%s", tostring(unitId or ""), tostring(abilityId or 0), tostring(effectSlot or 0))
end

local function getLibCombatBackfillSlotKey(abilityId)
    return string.format("prebuff:%s", tostring(abilityId or 0))
end

local function ensureLibCombatBuffData(abilityId)
    local data = libCombatBuffData[abilityId]
    if not data then
        data = {
            uptime = 0,
            count = 0,
            groupUptime = 0,
            groupCount = 0,
            firstStartTime = nil,
            firstGroupStartTime = nil,
            slots = {},
        }
        libCombatBuffData[abilityId] = data
    end
    return data
end

local function countLibCombatSlots(slots)
    local slotCount = 0
    local groupSlotCount = 0

    for _, slotData in pairs(slots) do
        if slotData.isPlayerSource then
            slotCount = slotCount + 1
        end
        groupSlotCount = groupSlotCount + 1
    end

    return slotCount, groupSlotCount
end

local function addLibCombatDuration(data, key, countKey, startTime, endTime, count)
    if startTime and endTime and endTime > startTime then
        data[key] = data[key] + (endTime - startTime)
        data[countKey] = data[countKey] + (count or 1)
    end
end

local function processLibCombatBuffData(abilityId, slotKey, timeMS, changeType, sourceType)
    local data = ensureLibCombatBuffData(abilityId)
    local slots = data.slots
    local slotCount, groupSlotCount = countLibCombatSlots(slots)
    local slotData = slots[slotKey]
    local isPlayerSource = isPlayerSourceType(sourceType)

    if (changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED) and (not fightEndTime or timeMS < fightEndTime) then
        if fightStartTime and timeMS < fightStartTime and not libCombatActiveAtStart[abilityId] then
            return
        end

        local startTime = math.max(timeMS, fightStartTime or timeMS)
        if slotCount == 0 and isPlayerSource then
            data.firstStartTime = startTime
        end
        if groupSlotCount == 0 then
            data.firstGroupStartTime = startTime
        end
        if not slotData then
            slots[slotKey] = {
                isPlayerSource = isPlayerSource,
            }
        elseif isPlayerSource and not slotData.isPlayerSource then
            if slotCount == 0 then
                data.firstStartTime = startTime
            end
            slotData.isPlayerSource = true
        end
    elseif changeType == EFFECT_RESULT_FADED then
        slots[slotKey] = nil
        if slotData and (not fightStartTime or timeMS > fightStartTime) then
            local endTime = fightEndTime and math.min(timeMS, fightEndTime) or timeMS

            if slotData.isPlayerSource then
                slotCount = slotCount - 1
            end
            groupSlotCount = groupSlotCount - 1

            if slotCount == 0 and data.firstStartTime then
                addLibCombatDuration(data, "uptime", "count", data.firstStartTime, endTime, 1)
                data.firstStartTime = nil
            end
            if groupSlotCount == 0 and data.firstGroupStartTime then
                addLibCombatDuration(data, "groupUptime", "groupCount", data.firstGroupStartTime, endTime, 1)
                data.firstGroupStartTime = nil
            end
        end
    end
end

local function rebuildLibCombatBuffData()
    libCombatBuffData = {}

    table.sort(libCombatEffectLog, function(a, b)
        if a.timeMS == b.timeMS then
            return a.seq < b.seq
        end
        return a.timeMS < b.timeMS
    end)

    for _, event in ipairs(libCombatEffectLog) do
        processLibCombatBuffData(event.abilityId, event.slotKey, event.timeMS, event.changeType, event.sourceType)
    end
end

local function logLibCombatEffectEvent(abilityId, slotKey, timeMS, changeType, sourceType)
    libCombatEffectSeq = libCombatEffectSeq + 1
    libCombatEffectLog[#libCombatEffectLog + 1] = {
        abilityId = abilityId,
        slotKey = slotKey,
        timeMS = timeMS,
        changeType = changeType,
        sourceType = sourceType,
        seq = libCombatEffectSeq,
    }
end

local function hasOpenLibCombatEffect(abilityId)
    local openSlots = {}

    for _, event in ipairs(libCombatEffectLog) do
        if event.abilityId == abilityId then
            if event.changeType == EFFECT_RESULT_GAINED or event.changeType == EFFECT_RESULT_UPDATED then
                openSlots[event.slotKey] = true
            elseif event.changeType == EFFECT_RESULT_FADED then
                openSlots[event.slotKey] = nil
            end
        end
    end

    for _ in pairs(openSlots) do
        return true
    end
    return false
end

local function backfillLibCombatPlayerBuffs(timeMS)
    if libCombatPrebuffBackfilled then return end
    libCombatPrebuffBackfilled = true

    local buffCount = GetNumBuffs("player") or 0
    for i = 1, buffCount do
        local _, beginTime, endTime, effectSlot, _, _, _, effectType, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo("player", i)
        local enabled, trackedId = isTrackedEnabled(abilityId)
        if not enabled then
            trackedId = rememberDetectedBuff(abilityId, nil, "player", castByPlayer, effectType, beginTime, endTime) or trackedId
            enabled = trackedId and settings.enabledBuffs[tostring(trackedId)]
        end
        if enabled and isBuffStillActive(endTime) then
            libCombatActiveAtStart[trackedId] = true
        end

        if enabled and isBuffStillActive(endTime) and not hasOpenLibCombatEffect(trackedId) then
            local sourceType = castByPlayer and COMBAT_UNIT_TYPE_PLAYER or COMBAT_UNIT_TYPE_NONE
            local slotKey = getLibCombatBackfillSlotKey(trackedId)
            libCombatBackfillSlots[trackedId] = {
                slotKey = slotKey,
                sourceType = sourceType,
            }
            logLibCombatEffectEvent(trackedId, slotKey, timeMS, EFFECT_RESULT_GAINED, sourceType)
            openScope(playerReceivedScopes, trackedId, slotKey, timeMS)
            if isPlayerSourceType(sourceType) then
                openScope(playerReceivedSourceScopes, trackedId, slotKey, timeMS)
            end
        end
    end
end

local function finalizeLibCombatBuffData(endTime)
    for _, data in pairs(libCombatBuffData) do
        local slotCount, groupSlotCount = countLibCombatSlots(data.slots)

        if groupSlotCount > 0 and fightStartTime ~= 0 then
            if slotCount > 0 and data.firstStartTime then
                addLibCombatDuration(data, "uptime", "count", data.firstStartTime, endTime, slotCount)
            end
            if data.firstGroupStartTime then
                addLibCombatDuration(data, "groupUptime", "groupCount", data.firstGroupStartTime, endTime, groupSlotCount)
            end
        end

        data.firstStartTime = nil
        data.firstGroupStartTime = nil
        data.slots = {}
    end
end

local function startLibCombatFight(timeMS)
    if not fightStartTime then
        resetUptime()
        fightStartTime = timeMS
    end
end

local function onLibCombatMessage(_, timeMS, combatMessage)
    if combatMessage == getLibCombatConstant("MESSAGE_COMBATSTART") then
        startLibCombatFight(timeMS)
        if settings.debug then d(string.format("[%s] LibCombat fight start %d", ADDON_NAME, timeMS)) end
    end
end

local function onLibCombatDamage(_, timeMS)
    startLibCombatFight(timeMS)
    if not activeStartTime then
        backfillLibCombatPlayerBuffs(timeMS)
    end
    touchActiveCombat(timeMS)
end

local function onLibCombatEffect(callbackType, timeMS, unitId, abilityId, changeType, effectType, _, sourceType, effectSlot)
    local enabled, trackedId = isTrackedEnabled(abilityId)
    if not enabled then
        if callbackType == getLibCombatConstant("EVENT_EFFECTS_IN")
            and (changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED) then
            trackedId = rememberDetectedBuff(abilityId, sourceType, "group", false, effectType, nil, nil) or trackedId
            enabled = trackedId and settings.enabledBuffs[tostring(trackedId)]
        end
        if not enabled then
            return
        end
    end

    startLibCombatFight(timeMS)

    local slotKey = getLibCombatSlotKey(unitId, abilityId, effectSlot)
    if callbackType == getLibCombatConstant("EVENT_EFFECTS_IN") then
        logLibCombatEffectEvent(trackedId, slotKey, timeMS, changeType, sourceType)
        if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
            openScope(playerReceivedScopes, trackedId, slotKey, timeMS)
            if isPlayerSourceType(sourceType) then
                openScope(playerReceivedSourceScopes, trackedId, slotKey, timeMS)
            end
        elseif changeType == EFFECT_RESULT_FADED then
            closeScope(playerReceivedScopes, trackedId, slotKey, timeMS)
            closeScope(playerReceivedSourceScopes, trackedId, slotKey, timeMS)

            local backfill = libCombatBackfillSlots[trackedId]
            if backfill then
                logLibCombatEffectEvent(trackedId, backfill.slotKey, timeMS, EFFECT_RESULT_FADED, backfill.sourceType)
                closeScope(playerReceivedScopes, trackedId, backfill.slotKey, timeMS)
                closeScope(playerReceivedSourceScopes, trackedId, backfill.slotKey, timeMS)
                libCombatBackfillSlots[trackedId] = nil
            end
        end
    end
end

local function onLibCombatFightSummary(_, fight)
    if not fightStartTime or not fight then return end

    local startTime = fight.starttime or fight.dpsstart or fight.hpsstart or activeStartTime or fightStartTime
    local endTime = fight.endtime or fight.dpsend or fight.hpsend or activeEndTime or nowMS()
    if not startTime or not endTime or endTime <= startTime then
        resetUptime()
        return
    end

    fightStartTime = startTime
    activeStartTime = startTime
    activeEndTime = endTime
    fightEndTime = endTime
    fightDurationOverrideMS = math.max(1000, (math.max(fight.activetime or 0, fight.dpstime or 0, fight.hpstime or 0) * 1000))

    rebuildLibCombatBuffData()
    finalizeLibCombatBuffData(fightEndTime)
    finalizeOpenIntervalsAtCombatEnd(fightEndTime)
    finalizeUptimeSummaryOnce()

    if settings.debug then d(string.format("[%s] LibCombat fight end %d", ADDON_NAME, fightEndTime)) end
    resetUptime()
end

local function getLibCombatAvailability()
    local LC = LibCombat
    if not LC then
        return false, "LibCombat global fehlt"
    end
    if type(LC.RegisterForCombatEvent) ~= "function" then
        return false, "RegisterForCombatEvent fehlt"
    end

    local requiredConstants = {
        "EVENT_MESSAGES",
        "EVENT_FIGHTSUMMARY",
        "EVENT_DAMAGE_OUT",
        "EVENT_DAMAGE_SELF",
        "EVENT_HEAL_OUT",
        "EVENT_HEAL_SELF",
        "EVENT_EFFECTS_IN",
        "MESSAGE_COMBATSTART",
    }

    local missing = {}
    for _, constantName in ipairs(requiredConstants) do
        if getLibCombatConstant(constantName) == nil then
            missing[#missing + 1] = constantName
        end
    end

    if #missing > 0 then
        return false, "Konstanten fehlen: " .. table.concat(missing, ", ")
    end

    return true, string.format("Version %s", tostring(LC.version or "?"))
end

local function registerLibCombat()
    if libCombatRegistered then
        useLibCombat = true
        return true
    end

    local LC = LibCombat
    local available, reason = getLibCombatAvailability()
    if not available then
        if settings and settings.debug then
            d(string.format("[%s] LibCombat nicht bereit: %s", ADDON_NAME, reason))
        end
        return false
    end

    local eventMessages = getLibCombatConstant("EVENT_MESSAGES")
    local eventFightSummary = getLibCombatConstant("EVENT_FIGHTSUMMARY")
    local eventDamageOut = getLibCombatConstant("EVENT_DAMAGE_OUT")
    local eventDamageSelf = getLibCombatConstant("EVENT_DAMAGE_SELF")
    local eventHealOut = getLibCombatConstant("EVENT_HEAL_OUT")
    local eventHealSelf = getLibCombatConstant("EVENT_HEAL_SELF")
    local eventEffectsIn = getLibCombatConstant("EVENT_EFFECTS_IN")

    useLibCombat = true
    LC:RegisterForCombatEvent(ADDON_NAME, eventMessages, onLibCombatMessage)
    LC:RegisterForCombatEvent(ADDON_NAME, eventFightSummary, onLibCombatFightSummary)
    LC:RegisterForCombatEvent(ADDON_NAME, eventDamageOut, onLibCombatDamage)
    LC:RegisterForCombatEvent(ADDON_NAME, eventDamageSelf, onLibCombatDamage)
    LC:RegisterForCombatEvent(ADDON_NAME, eventHealOut, onLibCombatDamage)
    LC:RegisterForCombatEvent(ADDON_NAME, eventHealSelf, onLibCombatDamage)
    LC:RegisterForCombatEvent(ADDON_NAME, eventEffectsIn, onLibCombatEffect)
    libCombatRegistered = true

    if settings and settings.debug then
        d(string.format("[%s] LibCombat mode aktiv (%s)", ADDON_NAME, reason))
    end
    return true
end

local function registerRawMode()
    if rawModeRegistered then return end
    useLibCombat = false
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED, onEffectChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME.."CombatEvents", EVENT_COMBAT_EVENT, onCombatEvent)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME.."Combat", EVENT_PLAYER_COMBAT_STATE, onPlayerCombatState)
    rawModeRegistered = true
    if settings and settings.debug then
        d(string.format("[%s] raw ESO event mode aktiv", ADDON_NAME))
    end
end

local function unregisterRawMode()
    if not rawModeRegistered then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME.."CombatEvents", EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME.."Combat", EVENT_PLAYER_COMBAT_STATE)
    rawModeRegistered = false
end

local function tryActivateCombatBackend(reason)
    if libCombatRegistered then
        return true
    end

    local playerInCombat = IsUnitInCombat and IsUnitInCombat("player")
    if rawModeRegistered and (fightStartTime or playerInCombat) then
        if zo_callLater and not libCombatRetryScheduled and libCombatRetryCount < LIBCOMBAT_MAX_RETRIES then
            libCombatRetryScheduled = true
            libCombatRetryCount = libCombatRetryCount + 1
            zo_callLater(function()
                libCombatRetryScheduled = false
                tryActivateCombatBackend((reason or "retry") .. " #" .. tostring(libCombatRetryCount))
            end, LIBCOMBAT_RETRY_DELAY_MS)
        end
        return false
    end

    if registerLibCombat() then
        if not fightStartTime and not playerInCombat then
            unregisterRawMode()
        end
        return true
    end

    registerRawMode()

    if zo_callLater and not libCombatRetryScheduled and libCombatRetryCount < LIBCOMBAT_MAX_RETRIES then
        libCombatRetryScheduled = true
        libCombatRetryCount = libCombatRetryCount + 1
        zo_callLater(function()
            libCombatRetryScheduled = false
            tryActivateCombatBackend((reason or "retry") .. " #" .. tostring(libCombatRetryCount))
        end, LIBCOMBAT_RETRY_DELAY_MS)
    end

    return false
end

---------------------------------------------------------
-- Lightweight UI (active buff timers for player)
---------------------------------------------------------
local mainWindow
local buffControls = {}
local mainMoveOverlay
local mainMoveHintBackdrop
local mainMoveHintLabel
local mainMoveMode = false
local mainMoveLastInputAt = nil
local mainMovePreviousInUIMode = nil
local mainMovePreviousCameraUIMode = nil
local summaryWindow
local summaryMoveOverlay
local summaryMoveHintBackdrop
local summaryMoveHintLabel
local summaryMoveMode = false
local summaryMoveLastInputAt = nil
local summaryMovePreviousInUIMode = nil
local summaryMovePreviousCameraUIMode = nil
local summaryRows = {}
local summaryDurationLabel
local summaryEmptyLabel
local summarySceneCallbackRegistered = false
local summaryBackKeybindInstalled = false
local summaryBackKeybindDescriptor = nil
local summaryBackOriginalCallback = nil
local closeSummaryWindow
local setSummaryMoveMode
local updateUI
local startBuffTimer

local function saveMainWindowPosition()
    if not mainWindow or not settings then return end
    settings.posX = math.floor((mainWindow:GetLeft() or settings.posX or 0) + 0.5)
    settings.posY = math.floor((mainWindow:GetTop() or settings.posY or 0) + 0.5)
end

local function refreshMainWindowAnchor()
    if not mainWindow or not settings then return end
    mainWindow:ClearAnchors()
    mainWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, settings.posX, settings.posY)
end

local function saveSummaryWindowPosition()
    if not summaryWindow or not settings then return end
    settings.summaryPosX = math.floor((summaryWindow:GetLeft() or settings.summaryPosX or 0) + 0.5)
    settings.summaryPosY = math.floor((summaryWindow:GetTop() or settings.summaryPosY or 0) + 0.5)
end

local function refreshSummaryWindowAnchor()
    if not summaryWindow or not settings then return end
    summaryWindow:ClearAnchors()
    summaryWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, settings.summaryPosX, settings.summaryPosY)
end

local function setMainMoveOverlayHidden(hidden)
    if mainMoveOverlay then
        mainMoveOverlay:SetHidden(hidden)
    end
end

local function setSummaryMoveOverlayHidden(hidden)
    if summaryMoveOverlay then
        summaryMoveOverlay:SetHidden(hidden)
    end
end

local function refreshMainUIUpdateLoop()
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME.."UI")
    if settings and (settings.showUI or mainMoveMode) then
        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME.."UI", 250, updateUI)
    end
end

local function setMainMoveMode(enabled)
    enabled = enabled and true or false
    if mainMoveMode == enabled then
        if enabled then
            mainMoveLastInputAt = nowMS()
            updateUI()
        end
        return
    end

    mainMoveMode = enabled
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME.."MainMoveMode")

    if enabled then
        mainMoveLastInputAt = nowMS()
        setMainMoveOverlayHidden(false)

        if SCENE_MANAGER and SCENE_MANAGER.IsInUIMode and SCENE_MANAGER.SetInUIMode then
            mainMovePreviousInUIMode = SCENE_MANAGER:IsInUIMode()
            if not mainMovePreviousInUIMode then
                SCENE_MANAGER:SetInUIMode(true)
            end
        end

        if SetGameCameraUIMode then
            mainMovePreviousCameraUIMode = IsGameCameraUIModeActive and IsGameCameraUIModeActive() or false
            if not mainMovePreviousCameraUIMode then
                SetGameCameraUIMode(true)
            end
        end

        refreshMainUIUpdateLoop()
        updateUI()

        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME.."MainMoveMode", 16, function()
            if not mainWindow then
                return
            end

            local now = nowMS()

            if SCENE_MANAGER and SCENE_MANAGER.IsInUIMode and SCENE_MANAGER.SetInUIMode and not SCENE_MANAGER:IsInUIMode() then
                SCENE_MANAGER:SetInUIMode(true)
            end
            if SetGameCameraUIMode and IsGameCameraUIModeActive and not IsGameCameraUIModeActive() then
                SetGameCameraUIMode(true)
            end

            if not GetGamepadRightStickX or not GetGamepadRightStickY then
                return
            end

            local stickX = GetGamepadRightStickX(GAMEPAD_INCLUDE_DEADZONE)
            local stickY = GetGamepadRightStickY(GAMEPAD_INCLUDE_DEADZONE)
            if stickX == nil or stickY == nil then
                return
            end

            local absX = math.abs(stickX)
            local absY = math.abs(stickY)
            if absX < 0.05 and absY < 0.05 then
                if mainMoveLastInputAt and (now - mainMoveLastInputAt) >= MAIN_UI_MOVE_MODE_TIMEOUT_MS then
                    setMainMoveMode(false)
                end
                return
            end

            local offsetX = math.floor((stickX * MAIN_UI_MOVE_SPEED) + (stickX >= 0 and 0.5 or -0.5))
            local adjustedStickY = -stickY
            local offsetY = math.floor((adjustedStickY * MAIN_UI_MOVE_SPEED) + (adjustedStickY >= 0 and 0.5 or -0.5))
            if offsetX == 0 and offsetY == 0 then
                return
            end

            settings.posX = (settings.posX or 0) + offsetX
            settings.posY = (settings.posY or 0) + offsetY
            mainMoveLastInputAt = now
            refreshMainWindowAnchor()
            saveMainWindowPosition()
        end)
    else
        setMainMoveOverlayHidden(true)

        if SCENE_MANAGER and SCENE_MANAGER.SetInUIMode and mainMovePreviousInUIMode == false then
            SCENE_MANAGER:SetInUIMode(false)
        end
        mainMovePreviousInUIMode = nil

        if SetGameCameraUIMode and mainMovePreviousCameraUIMode == false then
            SetGameCameraUIMode(false)
        end
        mainMovePreviousCameraUIMode = nil

        mainMoveLastInputAt = nil
        saveMainWindowPosition()
        refreshMainUIUpdateLoop()
        updateUI()
    end
end

local function findSummaryBackKeybind()
    local LHAS = LibHarvensAddonSettings
    local descriptorGroup = LHAS and LHAS.scrollList and LHAS.scrollList.keybindStripDescriptor
    if not descriptorGroup then
        return nil, nil
    end

    for _, descriptor in ipairs(descriptorGroup) do
        if descriptor.keybind == "UI_SHORTCUT_NEGATIVE" then
            return descriptor, descriptorGroup
        end
    end

    return nil, descriptorGroup
end

local function removeSummaryKeybinds()
end

local function addSummaryKeybinds()
    if summaryBackKeybindInstalled then
        return
    end

    local descriptor = findSummaryBackKeybind()
    if not descriptor or type(descriptor.callback) ~= "function" then
        return
    end

    summaryBackKeybindDescriptor = descriptor
    summaryBackOriginalCallback = descriptor.callback

    descriptor.callback = function(...)
        if summaryWindow and not summaryWindow:IsHidden() then
            closeSummaryWindow()
            return
        end
        return summaryBackOriginalCallback(...)
    end

    summaryBackKeybindInstalled = true
end

closeSummaryWindow = function()
    if summaryMoveMode and setSummaryMoveMode then
        setSummaryMoveMode(false)
    end
    if summaryWindow then
        summaryWindow:SetHidden(true)
    end
end

setSummaryMoveMode = function(enabled)
    enabled = enabled and true or false
    if summaryMoveMode == enabled then
        if enabled then
            summaryMoveLastInputAt = nowMS()
            refreshSummaryWindow()
        end
        return
    end

    summaryMoveMode = enabled
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME.."SummaryMoveMode")

    if enabled then
        if summaryWindow then
            refreshSummaryWindow()
            summaryWindow:SetHidden(false)
        end

        summaryMoveLastInputAt = nowMS()
        setSummaryMoveOverlayHidden(false)
        if summaryMoveHintBackdrop then
            summaryMoveHintBackdrop:SetHidden(false)
        end
        if summaryMoveHintLabel then
            summaryMoveHintLabel:SetHidden(false)
        end

        if SCENE_MANAGER and SCENE_MANAGER.IsInUIMode and SCENE_MANAGER.SetInUIMode then
            summaryMovePreviousInUIMode = SCENE_MANAGER:IsInUIMode()
            if not summaryMovePreviousInUIMode then
                SCENE_MANAGER:SetInUIMode(true)
            end
        end

        if SetGameCameraUIMode then
            summaryMovePreviousCameraUIMode = IsGameCameraUIModeActive and IsGameCameraUIModeActive() or false
            if not summaryMovePreviousCameraUIMode then
                SetGameCameraUIMode(true)
            end
        end

        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME.."SummaryMoveMode", 16, function()
            if not summaryWindow or summaryWindow:IsHidden() then
                return
            end

            local now = nowMS()

            if SCENE_MANAGER and SCENE_MANAGER.IsInUIMode and SCENE_MANAGER.SetInUIMode and not SCENE_MANAGER:IsInUIMode() then
                SCENE_MANAGER:SetInUIMode(true)
            end
            if SetGameCameraUIMode and IsGameCameraUIModeActive and not IsGameCameraUIModeActive() then
                SetGameCameraUIMode(true)
            end

            if not GetGamepadRightStickX or not GetGamepadRightStickY then
                return
            end

            local stickX = GetGamepadRightStickX(GAMEPAD_INCLUDE_DEADZONE)
            local stickY = GetGamepadRightStickY(GAMEPAD_INCLUDE_DEADZONE)
            if stickX == nil or stickY == nil then
                return
            end

            local absX = math.abs(stickX)
            local absY = math.abs(stickY)
            if absX < 0.05 and absY < 0.05 then
                if summaryMoveLastInputAt and (now - summaryMoveLastInputAt) >= MAIN_UI_MOVE_MODE_TIMEOUT_MS then
                    setSummaryMoveMode(false)
                end
                return
            end

            local offsetX = math.floor((stickX * MAIN_UI_MOVE_SPEED) + (stickX >= 0 and 0.5 or -0.5))
            local adjustedStickY = -stickY
            local offsetY = math.floor((adjustedStickY * MAIN_UI_MOVE_SPEED) + (adjustedStickY >= 0 and 0.5 or -0.5))
            if offsetX == 0 and offsetY == 0 then
                return
            end

            settings.summaryPosX = (settings.summaryPosX or 0) + offsetX
            settings.summaryPosY = (settings.summaryPosY or 0) + offsetY
            summaryMoveLastInputAt = now
            refreshSummaryWindowAnchor()
            saveSummaryWindowPosition()
        end)
    else
        setSummaryMoveOverlayHidden(true)
        if summaryMoveHintBackdrop then
            summaryMoveHintBackdrop:SetHidden(true)
        end
        if summaryMoveHintLabel then
            summaryMoveHintLabel:SetHidden(true)
        end

        if SCENE_MANAGER and SCENE_MANAGER.SetInUIMode and summaryMovePreviousInUIMode == false then
            SCENE_MANAGER:SetInUIMode(false)
        end
        summaryMovePreviousInUIMode = nil

        if SetGameCameraUIMode and summaryMovePreviousCameraUIMode == false then
            SetGameCameraUIMode(false)
        end
        summaryMovePreviousCameraUIMode = nil

        summaryMoveLastInputAt = nil
        saveSummaryWindowPosition()
        refreshSummaryWindow()
    end
end

local function isSceneState(state, ...)
    for i = 1, select("#", ...) do
        local candidate = select(i, ...)
        if state == candidate or state == _G[candidate] then
            return true
        end
    end
    return false
end

local function registerSummarySceneClose()
    if summarySceneCallbackRegistered or not SCENE_MANAGER or not SCENE_MANAGER.RegisterCallback then
        return
    end

    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, newState)
        if not summaryWindow or summaryWindow:IsHidden() or not scene or not scene.GetName then
            return
        end

        local sceneName = scene:GetName()
        local leavingAddonSettings = sceneName == "LibHarvensAddonSettingsScene"
            and isSceneState(newState, "SCENE_HIDING", "SCENE_HIDDEN", "hiding", "hidden")
        local enteringOtherScene = sceneName ~= "LibHarvensAddonSettingsScene"
            and isSceneState(newState, "SCENE_SHOWING", "SCENE_SHOWN", "showing", "shown")

        if leavingAddonSettings or enteringOtherScene then
            closeSummaryWindow()
        end
    end)

    summarySceneCallbackRegistered = true
end

local function getBuffRemaining(abilityId)
    for i = 1, GetNumBuffs("player") do
        local _, startTime, endTime, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
        if getTrackedId(id) == abilityId then
            return endTime - GetFrameTimeSeconds(), endTime - startTime
        end
    end
    return 0, 0
end

local function createBuffControl(yOffset, abilityId)
    local info = trackedBuffs[abilityId]
    local color = info and info.color or {1,1,1,1}

    local ctrl = wm:CreateControl(nil, mainWindow, CT_CONTROL)
    ctrl:SetDimensions(380, 40)
    ctrl:SetAnchor(TOPLEFT, mainWindow, TOPLEFT, 0, yOffset)
    ctrl:SetHidden(false)

    local icon = wm:CreateControl(nil, ctrl, CT_TEXTURE)
    icon:SetDimensions(40, 40)
    icon:SetAnchor(LEFT, ctrl, LEFT, 0, 0)
    icon:SetTexture(GetAbilityIcon(abilityId))

    local bar = wm:CreateControl(nil, ctrl, CT_STATUSBAR)
    bar:SetAnchor(LEFT, ctrl, LEFT, 50, 0)
    bar:SetDimensions(240, 40)
    bar:SetMinMax(0, 30)
    bar:SetValue(0)
    bar:SetColor(unpack(color))

    local label = wm:CreateControl(nil, bar, CT_LABEL)
    label:SetAnchor(CENTER, bar, CENTER, 0, 0)
    label:SetFont("$(BOLD_FONT)|35|soft-shadow-thin")
    label:SetColor(1, 1, 0, 1)
    label:SetText("0")

    local uptimeLabel = wm:CreateControl(nil, ctrl, CT_LABEL)
    uptimeLabel:SetAnchor(LEFT, bar, RIGHT, 10, 0)
    uptimeLabel:SetDimensions(80, 40)
    uptimeLabel:SetFont("$(BOLD_FONT)|26|soft-shadow-thin")
    uptimeLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    uptimeLabel:SetColor(1, 1, 1, 1)
    uptimeLabel:SetText("0%")

    return { ctrl = ctrl, bar = bar, label = label, uptimeLabel = uptimeLabel, icon = icon, abilityId = abilityId }
end

updateUI = function()
    local uptimeStart = activeStartTime or fightStartTime
    local uptimeEnd = fightEndTime or nowMS()
    local uptimeDuration = uptimeStart and math.max(1000, uptimeEnd - uptimeStart) or 0
    local activeBuffs = {}
    for _, abilityId in ipairs(mainUIBuffOrder) do
        if settings.enabledBuffs[tostring(abilityId)] then
            local remaining, total = getBuffRemaining(abilityId)
            if remaining > 0 then
                table.insert(activeBuffs, { id = abilityId, remaining = remaining, total = total })
            end
        end
    end

    table.sort(activeBuffs, function(a, b) return a.remaining > b.remaining end)

    for _, ctrl in ipairs(buffControls) do ctrl.ctrl:SetHidden(true) end
    local rowOffset = 0

    for i, buff in ipairs(activeBuffs) do
        local item = buffControls[i]
        if not item then
            item = createBuffControl(rowOffset + ((i - 1) * 45), buff.id)
            buffControls[i] = item
        else
            item.ctrl:SetAnchor(TOPLEFT, mainWindow, TOPLEFT, 0, rowOffset + ((i - 1) * 45))
            if item.abilityId ~= buff.id then
                item.abilityId = buff.id
                item.icon:SetTexture(GetAbilityIcon(buff.id))
                local color = trackedBuffs[buff.id] and trackedBuffs[buff.id].color or {1,1,1,1}
                item.bar:SetColor(unpack(color))
            end
            item.ctrl:SetHidden(false)
        end
        item.bar:SetMinMax(0, buff.total)
        item.bar:SetValue(buff.remaining)
        item.label:SetText(string.format("%.1f", buff.remaining))
        local uptimePct = 0
        if uptimeStart then
            uptimePct = getLiveScopeTotal(playerReceivedScopes, buff.id, uptimeStart, uptimeEnd) / uptimeDuration * 100
        end
        item.uptimeLabel:SetText(string.format("%d%%", pctInt(math.min(100, math.max(0, uptimePct)))))
    end

    local hasActiveBuffs = #activeBuffs > 0
    local windowHeight = hasActiveBuffs and (rowOffset + (#activeBuffs * 45)) or 52
    mainWindow:SetDimensions(380, windowHeight)

    if mainMoveHintBackdrop then
        mainMoveHintBackdrop:SetHidden(not mainMoveMode)
    end
    if mainMoveHintLabel then
        mainMoveHintLabel:SetHidden(not mainMoveMode or hasActiveBuffs)
    end

    local shouldShow = mainMoveMode or (settings.showUI and hasActiveBuffs)
    mainWindow:SetHidden(not shouldShow)
end

startBuffTimer = function()
    refreshMainUIUpdateLoop()
    updateUI()
end

local function getSummaryWindowHeight(entryCount)
    entryCount = math.max(0, tonumber(entryCount) or 0)
    if entryCount == 0 then
        return SUMMARY_WINDOW_MIN_HEIGHT
    end

    local rowsHeight = ((entryCount - 1) * SUMMARY_WINDOW_ROW_SPACING) + SUMMARY_WINDOW_ROW_HEIGHT
    return math.max(SUMMARY_WINDOW_MIN_HEIGHT, SUMMARY_WINDOW_ROW_TOP + rowsHeight + SUMMARY_WINDOW_BOTTOM_PADDING)
end

local function formatSummaryFightSeconds(durationMS)
    local seconds = math.max(0, (tonumber(durationMS) or 0) / 1000)
    local formatted = string.format("%.1f", seconds)
    return string.gsub(formatted, "%.", ",")
end

local function formatSummaryFightDurationText(durationMS)
    return string.format("%ss", formatSummaryFightSeconds(durationMS))
end

local function createSummaryRow(index)
    local row = wm:CreateControl(nil, summaryWindow, CT_CONTROL)
    row:SetDimensions(SUMMARY_WINDOW_INNER_WIDTH, SUMMARY_WINDOW_ROW_HEIGHT)
    row:SetAnchor(TOPLEFT, summaryWindow, TOPLEFT, 18, SUMMARY_WINDOW_ROW_TOP + ((index - 1) * SUMMARY_WINDOW_ROW_SPACING))

    local backdrop = wm:CreateControl(nil, row, CT_BACKDROP)
    backdrop:SetAnchorFill(row)
    backdrop:SetCenterTexture("EsoUI/Art/Miscellaneous/centerscreen_left.dds")
    backdrop:SetEdgeTexture("EsoUI/Art/Miscellaneous/centerscreen_left.dds", 1, 1, 1, 0)
    backdrop:SetCenterColor(0.08, 0.08, 0.1, 0.45)
    backdrop:SetEdgeColor(0, 0, 0, 0)

    local icon = wm:CreateControl(nil, row, CT_TEXTURE)
    icon:SetDimensions(22, 22)
    icon:SetAnchor(LEFT, row, LEFT, 8, 0)

    local name = wm:CreateControl(nil, row, CT_LABEL)
    name:SetAnchor(LEFT, icon, RIGHT, 10, 0)
    name:SetDimensions(170, 24)
    name:SetFont("$(BOLD_FONT)|18|soft-shadow-thin")
    name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

    local player = wm:CreateControl(nil, row, CT_LABEL)
    player:SetAnchor(LEFT, row, LEFT, 250, 0)
    player:SetDimensions(56, 24)
    player:SetFont("$(MEDIUM_FONT)|18|soft-shadow-thin")
    player:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local playerCount = wm:CreateControl(nil, row, CT_LABEL)
    playerCount:SetAnchor(LEFT, row, LEFT, 315, 0)
    playerCount:SetDimensions(44, 24)
    playerCount:SetFont("$(MEDIUM_FONT)|18|soft-shadow-thin")
    playerCount:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local group = wm:CreateControl(nil, row, CT_LABEL)
    group:SetAnchor(LEFT, row, LEFT, 370, 0)
    group:SetDimensions(56, 24)
    group:SetFont("$(MEDIUM_FONT)|18|soft-shadow-thin")
    group:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local groupCount = wm:CreateControl(nil, row, CT_LABEL)
    groupCount:SetAnchor(LEFT, row, LEFT, 435, 0)
    groupCount:SetDimensions(44, 24)
    groupCount:SetFont("$(MEDIUM_FONT)|18|soft-shadow-thin")
    groupCount:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    summaryRows[index] = {
        control = row,
        backdrop = backdrop,
        icon = icon,
        name = name,
        player = player,
        playerCount = playerCount,
        group = group,
        groupCount = groupCount,
    }

    return summaryRows[index]
end

refreshSummaryWindow = function()
    if not summaryWindow then return end

    local summaryData, isLiveFight = getSummaryWindowData()
    local entries = summaryData and summaryData.entries or {}
    local fightDurationMS = (summaryData and summaryData.durationMS) or 0
    summaryWindow:SetDimensions(SUMMARY_WINDOW_WIDTH, getSummaryWindowHeight(#entries))

    if fightDurationMS > 0 then
        local fightDurationText = formatSummaryFightDurationText(fightDurationMS)
        if isLiveFight then
            summaryDurationLabel:SetText(string.format("Aktueller Kampf: %s", fightDurationText))
        else
            summaryDurationLabel:SetText(string.format("Letzter Kampf: %s", fightDurationText))
        end
    else
        summaryDurationLabel:SetText("Letzter Kampf: noch keine Daten")
    end

    for i = 1, #entries do
        local entry = entries[i]
        local row = summaryRows[i] or createSummaryRow(i)
        local color = entry.color or {1, 1, 1, 1}

        row.icon:SetTexture(GetAbilityIcon(entry.id))
        row.name:SetText(entry.name ~= "" and entry.name or getDisplayName(entry.id))
        row.name:SetColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
        row.player:SetText(string.format("%d%%", entry.playerPct or 0))
        row.playerCount:SetText(string.format("%dx", entry.playerCount or 0))
        row.group:SetText(string.format("%d%%", entry.groupPct or 0))
        row.groupCount:SetText(string.format("%dx", entry.groupCount or 0))
        row.backdrop:SetCenterColor(i % 2 == 0 and 0.11 or 0.08, 0.08, 0.12, 0.52)
        row.control:SetHidden(false)
    end

    for i = #entries + 1, #summaryRows do
        summaryRows[i].control:SetHidden(true)
    end

    summaryEmptyLabel:SetHidden(#entries > 0)
end

local function showSummaryWindow()
    refreshSummaryWindow()
    summaryWindow:SetHidden(false)
end

---------------------------------------------------------
-- Settings (LibHarvensAddonSettings)
---------------------------------------------------------
local function buildSettingsDescriptor()
    local LHAS = LibHarvensAddonSettings
    local settingsDescriptor = {
        { type = LHAS.ST_CHECKBOX, label = "UI anzeigen",
          getFunction = function() return settings.showUI end,
          setFunction = function(value)
              settings.showUI = value
              refreshMainUIUpdateLoop()
              updateUI()
          end },

        { type = LHAS.ST_BUTTON, label = "Main UI verschieben",
          buttonText = "Starten",
          clickHandler = function() setMainMoveMode(true) end },

        { type = LHAS.ST_SLIDER, label = "UI Skalierung",
          min = 0.5, max = 1.3, step = 0.05,
          getFunction = function() return settings.scale end,
          setFunction = function(value)
              settings.scale = value
              mainWindow:SetScale(settings.scale)
          end },

        { type = LHAS.ST_CHECKBOX, label = "Uptime-Zusammenfassung im Chat",
          getFunction = function() return settings.chatSummary end,
          setFunction = function(value) settings.chatSummary = value end },

        { type = LHAS.ST_CHECKBOX, label = "Gruppen-Uptime im Chat anzeigen",
          getFunction = function() return settings.showGroupUptime end,
          setFunction = function(value) settings.showGroupUptime = value end },

        { type = LHAS.ST_SECTION, label = "Uptime Menue" },

        { type = LHAS.ST_BUTTON, label = "Letzte Uptime-Statistik",
          buttonText = "Fenster oeffnen",
          clickHandler = function() showSummaryWindow() end },

        { type = LHAS.ST_BUTTON, label = "Uptime Menue verschieben",
          buttonText = "Starten",
          clickHandler = function()
              showSummaryWindow()
              setSummaryMoveMode(true)
          end },

        { type = LHAS.ST_SLIDER, label = "Uptime Menue Skalierung",
          min = 0.7, max = 1.4, step = 0.05,
          getFunction = function() return settings.summaryScale or 1.0 end,
          setFunction = function(value)
              settings.summaryScale = value
              if summaryWindow then
                  summaryWindow:SetScale(settings.summaryScale)
              end
          end },

        { type = LHAS.ST_SECTION, label = "Auto-Erkennung" },

        { type = LHAS.ST_CHECKBOX, label = "Neue Buffs automatisch erkennen",
          getFunction = function() return settings.autoDetectBuffs end,
          setFunction = function(value) settings.autoDetectBuffs = value end },

        { type = LHAS.ST_CHECKBOX, label = "Nur eigene Buff-Quellen merken",
          getFunction = function() return settings.autoDetectPlayerSourceOnly end,
          setFunction = function(value) settings.autoDetectPlayerSourceOnly = value end },

        { type = LHAS.ST_LABEL,
          label = "Erkannte Buffs werden direkt ins Tracking und in die Uptime-Statistik uebernommen." },
    }

    table.insert(settingsDescriptor, {
        type = LHAS.ST_SECTION,
        label = "Getrackte Buffs",
    })

    for _, id in ipairs(trackedBuffOrder) do
        local trackedId = id
        table.insert(settingsDescriptor, {
            type = LHAS.ST_CHECKBOX,
            label = function() return getDisplayName(trackedId) end,
            getFunction = function() return settings.enabledBuffs[tostring(trackedId)] end,
            setFunction = function(value) settings.enabledBuffs[tostring(trackedId)] = value end,
        })
    end

    return settingsDescriptor
end

refreshTrackedSettingsMenu = function()
    if not settingsAddon then return end
    settingsAddon:RemoveAllSettings(false)
    settingsAddon:AddSettings(buildSettingsDescriptor(), nil, false)
end

local function initSettings()
    local LHAS = LibHarvensAddonSettings
    if not LHAS then return end

    settingsAddon = settingsAddon or LHAS:AddAddon(ADDON_NAME, { allowRefresh = true })
    refreshTrackedSettingsMenu()
end

---------------------------------------------------------
-- UI container
---------------------------------------------------------
local function createUI()
    mainMoveOverlay = wm:CreateTopLevelWindow(ADDON_NAME.."MainMoveOverlay")
    mainMoveOverlay:SetAnchorFill(GuiRoot)
    mainMoveOverlay:SetDrawLayer(DL_OVERLAY)
    mainMoveOverlay:SetDrawTier(DT_HIGH)
    mainMoveOverlay:SetMouseEnabled(false)
    mainMoveOverlay:SetHidden(true)

    local overlayDim = wm:CreateControl(nil, mainMoveOverlay, CT_BACKDROP)
    overlayDim:SetAnchorFill(mainMoveOverlay)
    overlayDim:SetCenterColor(0, 0, 0, 0.10)
    overlayDim:SetEdgeColor(0, 0, 0, 0)

    local function createMainOverlayLine(anchorPoint, anchorTo, relativePoint, offsetX, offsetY, width, height, alpha)
        local line = wm:CreateControl(nil, mainMoveOverlay, CT_BACKDROP)
        line:SetAnchor(anchorPoint, anchorTo, relativePoint, offsetX, offsetY)
        line:SetDimensions(width, height)
        line:SetCenterColor(1, 1, 1, alpha or 0.25)
        line:SetEdgeColor(0, 0, 0, 0)
        return line
    end

    createMainOverlayLine(CENTER, mainMoveOverlay, CENTER, 0, 0, GuiRoot:GetWidth(), 2, 0.45)
    createMainOverlayLine(CENTER, mainMoveOverlay, CENTER, 0, 0, 2, GuiRoot:GetHeight(), 0.45)
    createMainOverlayLine(CENTER, mainMoveOverlay, CENTER, 0, -220, GuiRoot:GetWidth(), 1, 0.18)
    createMainOverlayLine(CENTER, mainMoveOverlay, CENTER, 0, 220, GuiRoot:GetWidth(), 1, 0.18)
    createMainOverlayLine(CENTER, mainMoveOverlay, CENTER, -220, 0, 1, GuiRoot:GetHeight(), 0.18)
    createMainOverlayLine(CENTER, mainMoveOverlay, CENTER, 220, 0, 1, GuiRoot:GetHeight(), 0.18)

    local mainMoveOverlayLabel = wm:CreateControl(nil, mainMoveOverlay, CT_LABEL)
    mainMoveOverlayLabel:SetFont("$(GAMEPAD_BOLD_FONT)|28|soft-shadow-thick")
    mainMoveOverlayLabel:SetColor(1, 1, 1, 0.95)
    mainMoveOverlayLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    mainMoveOverlayLabel:SetAnchor(TOP, mainMoveOverlay, TOP, 0, 80)
    mainMoveOverlayLabel:SetText("Main UI verschieben")

    mainWindow = wm:CreateTopLevelWindow(ADDON_NAME.."Main")
    mainWindow:SetDimensions(380, 200)
    refreshMainWindowAnchor()
    mainWindow:SetScale(settings.scale)
    mainWindow:SetMouseEnabled(true)
    mainWindow:SetMovable(true)
    mainWindow:SetClampedToScreen(true)
    mainWindow:SetHidden(true)
    mainWindow:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:StartMoving()
        end
    end)
    mainWindow:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:StopMovingOrResizing()
            saveMainWindowPosition()
        end
    end)

    mainMoveHintBackdrop = wm:CreateControl(nil, mainWindow, CT_BACKDROP)
    mainMoveHintBackdrop:SetAnchorFill(mainWindow)
    mainMoveHintBackdrop:SetCenterColor(0.06, 0.08, 0.12, 0.72)
    mainMoveHintBackdrop:SetEdgeColor(0.85, 0.9, 1.0, 0.75)
    mainMoveHintBackdrop:SetEdgeTexture("EsoUI/Art/Miscellaneous/centerscreen_left.dds", 1, 1, 2, 0)
    mainMoveHintBackdrop:SetHidden(true)

    mainMoveHintLabel = wm:CreateControl(nil, mainMoveHintBackdrop, CT_LABEL)
    mainMoveHintLabel:SetAnchor(CENTER, mainMoveHintBackdrop, CENTER, 0, 0)
    mainMoveHintLabel:SetDimensions(280, 36)
    mainMoveHintLabel:SetFont("$(GAMEPAD_BOLD_FONT)|22|soft-shadow-thick")
    mainMoveHintLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    mainMoveHintLabel:SetColor(1, 1, 1, 1)
    mainMoveHintLabel:SetText("Rechten Stick bewegen")
end

local function createSummaryWindow()
    summaryMoveOverlay = wm:CreateTopLevelWindow(ADDON_NAME.."SummaryMoveOverlay")
    summaryMoveOverlay:SetAnchorFill(GuiRoot)
    summaryMoveOverlay:SetDrawLayer(DL_OVERLAY)
    summaryMoveOverlay:SetDrawTier(DT_HIGH)
    summaryMoveOverlay:SetMouseEnabled(false)
    summaryMoveOverlay:SetHidden(true)

    local summaryOverlayDim = wm:CreateControl(nil, summaryMoveOverlay, CT_BACKDROP)
    summaryOverlayDim:SetAnchorFill(summaryMoveOverlay)
    summaryOverlayDim:SetCenterColor(0, 0, 0, 0.10)
    summaryOverlayDim:SetEdgeColor(0, 0, 0, 0)

    local function createSummaryOverlayLine(anchorPoint, anchorTo, relativePoint, offsetX, offsetY, width, height, alpha)
        local line = wm:CreateControl(nil, summaryMoveOverlay, CT_BACKDROP)
        line:SetAnchor(anchorPoint, anchorTo, relativePoint, offsetX, offsetY)
        line:SetDimensions(width, height)
        line:SetCenterColor(1, 1, 1, alpha or 0.25)
        line:SetEdgeColor(0, 0, 0, 0)
        return line
    end

    createSummaryOverlayLine(CENTER, summaryMoveOverlay, CENTER, 0, 0, GuiRoot:GetWidth(), 2, 0.45)
    createSummaryOverlayLine(CENTER, summaryMoveOverlay, CENTER, 0, 0, 2, GuiRoot:GetHeight(), 0.45)
    createSummaryOverlayLine(CENTER, summaryMoveOverlay, CENTER, 0, -220, GuiRoot:GetWidth(), 1, 0.18)
    createSummaryOverlayLine(CENTER, summaryMoveOverlay, CENTER, 0, 220, GuiRoot:GetWidth(), 1, 0.18)
    createSummaryOverlayLine(CENTER, summaryMoveOverlay, CENTER, -220, 0, 1, GuiRoot:GetHeight(), 0.18)
    createSummaryOverlayLine(CENTER, summaryMoveOverlay, CENTER, 220, 0, 1, GuiRoot:GetHeight(), 0.18)

    local summaryMoveOverlayLabel = wm:CreateControl(nil, summaryMoveOverlay, CT_LABEL)
    summaryMoveOverlayLabel:SetFont("$(GAMEPAD_BOLD_FONT)|28|soft-shadow-thick")
    summaryMoveOverlayLabel:SetColor(1, 1, 1, 0.95)
    summaryMoveOverlayLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    summaryMoveOverlayLabel:SetAnchor(TOP, summaryMoveOverlay, TOP, 0, 80)
    summaryMoveOverlayLabel:SetText("Uptime Menue verschieben")

    summaryWindow = wm:CreateTopLevelWindow(ADDON_NAME.."Summary")
    summaryWindow:SetDimensions(SUMMARY_WINDOW_WIDTH, SUMMARY_WINDOW_MIN_HEIGHT)
    refreshSummaryWindowAnchor()
    summaryWindow:SetScale(settings.summaryScale or 1.0)
    summaryWindow:SetHidden(true)
    summaryWindow:SetMouseEnabled(true)
    summaryWindow:SetMovable(true)
    summaryWindow:SetClampedToScreen(true)
    summaryWindow:SetDrawLayer(DL_OVERLAY)
    summaryWindow:SetDrawTier(DT_HIGH)

    summaryWindow:SetHandler("OnEffectivelyShown", function()
        addSummaryKeybinds()
    end)

    summaryWindow:SetHandler("OnEffectivelyHidden", function()
        if summaryMoveMode and setSummaryMoveMode then
            setSummaryMoveMode(false)
        end
        if zo_callLater then
            zo_callLater(removeSummaryKeybinds, 0)
        else
            removeSummaryKeybinds()
        end
    end)

    registerSummarySceneClose()

    summaryWindow:SetHandler("OnMouseDown", function(self, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            self:StartMoving()
        end
    end)

    summaryWindow:SetHandler("OnMouseUp", function(self, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            self:StopMovingOrResizing()
            saveSummaryWindowPosition()
        end
    end)

    summaryWindow:SetHandler("OnMoveStop", saveSummaryWindowPosition)

    local backdrop = wm:CreateControl(nil, summaryWindow, CT_BACKDROP)
    backdrop:SetAnchorFill(summaryWindow)
    backdrop:SetCenterTexture("EsoUI/Art/Miscellaneous/centerscreen_left.dds")
    backdrop:SetEdgeTexture("EsoUI/Art/Miscellaneous/centerscreen_left.dds", 1, 1, 2, 0)
    backdrop:SetCenterColor(0.03, 0.04, 0.05, 0.96)
    backdrop:SetEdgeColor(0.72, 0.78, 0.9, 0.95)

    local title = wm:CreateControl(nil, summaryWindow, CT_LABEL)
    title:SetAnchor(TOPLEFT, summaryWindow, TOPLEFT, 20, 18)
    title:SetFont("$(BOLD_FONT)|26|soft-shadow-thick")
    title:SetColor(0.88, 0.95, 1, 1)
    title:SetText("Uptime Menue")

    summaryDurationLabel = wm:CreateControl(nil, summaryWindow, CT_LABEL)
    summaryDurationLabel:SetAnchor(TOPLEFT, summaryWindow, TOPLEFT, 20, 48)
    summaryDurationLabel:SetFont("$(MEDIUM_FONT)|18|soft-shadow-thin")
    summaryDurationLabel:SetColor(0.8, 0.84, 0.9, 1)

    local closeButton = wm:CreateControlFromVirtual(nil, summaryWindow, "ZO_DefaultButton")
    closeButton:SetDimensions(120, 28)
    closeButton:SetAnchor(TOPRIGHT, summaryWindow, TOPRIGHT, -20, 16)
    closeButton:SetText("Schliessen")
    closeButton:SetHandler("OnClicked", function() closeSummaryWindow() end)

    summaryMoveHintBackdrop = wm:CreateControl(nil, summaryWindow, CT_BACKDROP)
    summaryMoveHintBackdrop:SetAnchorFill(summaryWindow)
    summaryMoveHintBackdrop:SetCenterColor(0.06, 0.08, 0.12, 0.72)
    summaryMoveHintBackdrop:SetEdgeColor(0.85, 0.9, 1.0, 0.75)
    summaryMoveHintBackdrop:SetEdgeTexture("EsoUI/Art/Miscellaneous/centerscreen_left.dds", 1, 1, 2, 0)
    summaryMoveHintBackdrop:SetHidden(true)

    summaryMoveHintLabel = wm:CreateControl(nil, summaryMoveHintBackdrop, CT_LABEL)
    summaryMoveHintLabel:SetAnchor(CENTER, summaryMoveHintBackdrop, CENTER, 0, 0)
    summaryMoveHintLabel:SetDimensions(420, 40)
    summaryMoveHintLabel:SetFont("$(GAMEPAD_BOLD_FONT)|22|soft-shadow-thick")
    summaryMoveHintLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    summaryMoveHintLabel:SetColor(1, 1, 1, 1)
    summaryMoveHintLabel:SetText("Rechten Stick bewegen")

    local headerBar = wm:CreateControl(nil, summaryWindow, CT_BACKDROP)
    headerBar:SetDimensions(SUMMARY_WINDOW_INNER_WIDTH, SUMMARY_WINDOW_ROW_HEIGHT)
    headerBar:SetAnchor(TOPLEFT, summaryWindow, TOPLEFT, 18, 68)
    headerBar:SetCenterTexture("EsoUI/Art/Miscellaneous/centerscreen_left.dds")
    headerBar:SetEdgeTexture("EsoUI/Art/Miscellaneous/centerscreen_left.dds", 1, 1, 1, 0)
    headerBar:SetCenterColor(0.16, 0.2, 0.28, 0.9)
    headerBar:SetEdgeColor(0, 0, 0, 0)

    local buffHeader = wm:CreateControl(nil, summaryWindow, CT_LABEL)
    buffHeader:SetAnchor(LEFT, headerBar, LEFT, 14, 0)
    buffHeader:SetFont("$(BOLD_FONT)|18|soft-shadow-thin")
    buffHeader:SetColor(1, 1, 1, 1)
    buffHeader:SetText("Buff")

    local playerHeader = wm:CreateControl(nil, summaryWindow, CT_LABEL)
    playerHeader:SetAnchor(LEFT, headerBar, LEFT, 250, 0)
    playerHeader:SetDimensions(56, 24)
    playerHeader:SetFont("$(BOLD_FONT)|18|soft-shadow-thin")
    playerHeader:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    playerHeader:SetColor(1, 1, 1, 1)
    playerHeader:SetText("Du %")

    local playerCountHeader = wm:CreateControl(nil, summaryWindow, CT_LABEL)
    playerCountHeader:SetAnchor(LEFT, headerBar, LEFT, 315, 0)
    playerCountHeader:SetDimensions(44, 24)
    playerCountHeader:SetFont("$(BOLD_FONT)|18|soft-shadow-thin")
    playerCountHeader:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    playerCountHeader:SetColor(1, 1, 1, 1)
    playerCountHeader:SetText("x")

    local groupHeader = wm:CreateControl(nil, summaryWindow, CT_LABEL)
    groupHeader:SetAnchor(LEFT, headerBar, LEFT, 370, 0)
    groupHeader:SetDimensions(56, 24)
    groupHeader:SetFont("$(BOLD_FONT)|18|soft-shadow-thin")
    groupHeader:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    groupHeader:SetColor(1, 1, 1, 1)
    groupHeader:SetText("Grp %")

    local groupCountHeader = wm:CreateControl(nil, summaryWindow, CT_LABEL)
    groupCountHeader:SetAnchor(LEFT, headerBar, LEFT, 435, 0)
    groupCountHeader:SetDimensions(44, 24)
    groupCountHeader:SetFont("$(BOLD_FONT)|18|soft-shadow-thin")
    groupCountHeader:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    groupCountHeader:SetColor(1, 1, 1, 1)
    groupCountHeader:SetText("x")

    summaryEmptyLabel = wm:CreateControl(nil, summaryWindow, CT_LABEL)
    summaryEmptyLabel:SetAnchor(TOPLEFT, summaryWindow, TOPLEFT, 20, SUMMARY_WINDOW_ROW_TOP + 12)
    summaryEmptyLabel:SetDimensions(SUMMARY_WINDOW_INNER_WIDTH - 10, 44)
    summaryEmptyLabel:SetFont("$(MEDIUM_FONT)|20|soft-shadow-thin")
    summaryEmptyLabel:SetColor(0.85, 0.85, 0.88, 1)
    summaryEmptyLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    summaryEmptyLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    summaryEmptyLabel:SetText("Noch keine Uptime-Daten vorhanden.")
    summaryMoveHintBackdrop:SetDrawLayer(DL_OVERLAY)
    summaryMoveHintBackdrop:SetDrawTier(DT_HIGH)
    summaryMoveHintLabel:SetDrawLayer(DL_OVERLAY)
    summaryMoveHintLabel:SetDrawTier(DT_HIGH)

    refreshSummaryWindow()
end

---------------------------------------------------------
-- Addon bootstrap
---------------------------------------------------------
local function onAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    settings = ZO_SavedVars:NewAccountWide("SimpleWarhornTimer_SavedVariables", 1, nil, defaults)
    ensureSettingsTables()
    if settings.autoDetectDataVersion ~= AUTO_DETECT_DATA_VERSION then
        settings.detectedBuffs = {}
        settings.autoDetectDataVersion = AUTO_DETECT_DATA_VERSION
    end
    loadCustomTrackedBuffs()

    -- make sure enabledBuffs exists (avoid nil index)
    for _, id in ipairs(trackedBuffOrder) do
        if settings.enabledBuffs[tostring(id)] == nil then
            settings.enabledBuffs[tostring(id)] = true
        end
    end
    createUI()
    createSummaryWindow()
    setLastSummaryData(settings.lastSummary)
    initSettings()
    if settings.showUI then startBuffTimer() end

    tryActivateCombatBackend("addon loaded")
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME.."LibCombatRetry", EVENT_PLAYER_ACTIVATED, function()
        tryActivateCombatBackend("player activated")
        if libCombatRegistered then
            EVENT_MANAGER:UnregisterForEvent(ADDON_NAME.."LibCombatRetry", EVENT_PLAYER_ACTIVATED)
        end
    end)
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, onAddonLoaded)
