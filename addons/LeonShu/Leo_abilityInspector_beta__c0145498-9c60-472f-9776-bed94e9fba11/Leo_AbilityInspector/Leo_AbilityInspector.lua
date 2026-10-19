local ADDON_NAME = "Leo_AbilityInspector"
local DISPLAY_NAME = "Leo Ability Inspector"
local AUTHOR_NAME = "Leo_Kujo"
local SETTINGS_ID = ADDON_NAME .. "_Settings"

local PLAYER_EVENT_NAME = ADDON_NAME .. "_PlayerEffects"
local TARGET_EVENT_NAME = ADDON_NAME .. "_TargetEffects"
local TARGET_CHANGED_EVENT_NAME = ADDON_NAME .. "_TargetChanged"
local SCAN_UPDATE_NAME = ADDON_NAME .. "_Scan"
local SESSION_UPDATE_NAME = ADDON_NAME .. "_Session"

local RECORDING_DURATION_MS = 30000
local SCAN_INTERVAL_MS = 250
local MAX_RECORDED_EFFECTS = 100
local MAX_DROPPED_RECORDS = 1000

local settingsPanel
local settingsRegistered = false

local recording = false
local recordingStartedAt = 0
local recordingStoppedAt = 0
local records = {}
local recordsByKey = {}
local droppedRecords = 0
local eventsRegistered = false
local updatesRegistered = false

local StopRecording
local ShowResults
local RefreshSettings

local function AddChatLine(text)
    local message = "[Leo Ability Inspector] " .. tostring(text)
    if d then
        d(message)
    elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage(message)
    end
end

local function NowMilliseconds()
    if GetGameTimeMilliseconds then
        return GetGameTimeMilliseconds()
    end

    return GetFrameTimeMilliseconds()
end

local function SafeText(value, fallback)
    if value == nil or tostring(value) == "" then
        return fallback or "?"
    end

    return tostring(value)
end

local function NormalizeEndTime(endTime)
    if not endTime or endTime <= 0 then
        return nil
    end

    -- ESO aura timestamps are seconds; internal timestamps are milliseconds.
    return endTime * 1000
end

local function GetEffectCategory(effectType)
    if BUFF_EFFECT_TYPE_DEBUFF and effectType == BUFF_EFFECT_TYPE_DEBUFF then
        return "DEBUFF"
    end

    if BUFF_EFFECT_TYPE_BUFF and effectType == BUFF_EFFECT_TYPE_BUFF then
        return "BUFF"
    end

    return "OTHER"
end

local function GetEffectName(effectName, abilityId)
    if effectName and tostring(effectName) ~= "" then
        return tostring(effectName)
    end

    if GetAbilityName and abilityId then
        local success, name = pcall(GetAbilityName, abilityId)
        if success and name and tostring(name) ~= "" then
            return tostring(name)
        end
    end

    return "Unknown effect"
end

local function GetSourceStatus(scope, castByPlayer, sourceType)
    if scope ~= "target" then
        return nil
    end

    if castByPlayer == true then
        return "player"
    end

    if castByPlayer == false then
        return "other"
    end

    if COMBAT_UNIT_TYPE_PLAYER and sourceType == COMBAT_UNIT_TYPE_PLAYER then
        return "player"
    end

    return "unknown"
end

local function MergeSourceStatus(oldStatus, newStatus)
    if newStatus == "player" or oldStatus == nil then
        return newStatus
    end

    if oldStatus == "player" then
        return oldStatus
    end

    if newStatus == "other" or oldStatus == nil then
        return newStatus
    end

    return oldStatus or "unknown"
end

local function MakeRecordKey(scope, category, abilityId)
    local subject = scope == "player" and "player" or "target"
    return subject .. ":" .. category .. ":" .. tostring(abilityId)
end

local function ClearRecords()
    records = {}
    recordsByKey = {}
    droppedRecords = 0
end

local function RecordEffect(scope, unitName, unitId, effectName, endTime, effectType, abilityId, castByPlayer, sourceType)
    if not recording or not abilityId or tonumber(abilityId) == nil then
        return nil
    end

    abilityId = tonumber(abilityId)
    if abilityId <= 0 then
        return nil
    end

    local category = GetEffectCategory(effectType)
    local key = MakeRecordKey(scope, category, abilityId)
    local now = NowMilliseconds()
    local record = recordsByKey[key]

    if not record then
        if #records >= MAX_RECORDED_EFFECTS then
            if droppedRecords < MAX_DROPPED_RECORDS then
                droppedRecords = droppedRecords + 1
            end
            return nil
        end

        record = {
            key = key,
            scope = scope,
            category = category,
            abilityId = abilityId,
            name = GetEffectName(effectName, abilityId),
            targetName = scope == "target" and SafeText(unitName, "Current target") or nil,
            endTimeMs = nil,
            source = GetSourceStatus(scope, castByPlayer, sourceType),
            firstSeenAt = now,
            lastSeenAt = now,
            endedAt = nil,
        }
        records[#records + 1] = record
        recordsByKey[key] = record
    else
        if effectName and tostring(effectName) ~= "" then
            record.name = tostring(effectName)
        end
        if scope == "target" and unitName and tostring(unitName) ~= "" then
            record.targetName = tostring(unitName)
        end
    end

    local normalizedEndTime = NormalizeEndTime(endTime)
    if normalizedEndTime then
        record.endTimeMs = normalizedEndTime
    else
        -- An effect can change from timed to stack/state-only. Do not keep a stale timer.
        record.endTimeMs = nil
    end

    record.source = MergeSourceStatus(record.source, GetSourceStatus(scope, castByPlayer, sourceType))
    record.lastSeenAt = now
    record.endedAt = nil
    return record
end

local function MarkEffectFaded(scope, unitName, unitId, effectType, abilityId)
    if not recording or not abilityId then
        return
    end

    local category = GetEffectCategory(effectType)
    local record = recordsByKey[MakeRecordKey(scope, category, abilityId)]
    if record then
        record.endedAt = NowMilliseconds()
    end
end

local function ScanUnit(scope, unitTag)
    if not DoesUnitExist(unitTag) then
        return
    end

    local unitName = GetUnitName and GetUnitName(unitTag) or nil
    local buffCount = GetNumBuffs(unitTag) or 0
    for buffIndex = 1, buffCount do
        local effectName, _, endTime, _, _, _, _, effectType, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo(unitTag, buffIndex)
        if abilityId then
            RecordEffect(scope, unitName, nil, effectName, endTime, effectType, abilityId, castByPlayer, nil)
        end
    end
end

local function OnEffectChanged(_, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
    if not recording then
        return
    end

    local scope
    if unitTag == "player" then
        scope = "player"
    elseif unitTag == "reticleover" then
        scope = "target"
    else
        return
    end

    if changeType == EFFECT_RESULT_FADED then
        MarkEffectFaded(scope, unitName, unitId, effectType, abilityId)
        return
    end

    RecordEffect(scope, unitName, unitId, effectName, endTime, effectType, abilityId, nil, sourceType)
end

local function OnTargetChanged()
    if recording then
        ScanUnit("target", "reticleover")
    end
end

local function RegisterRecordingEvents()
    if eventsRegistered then
        return
    end

    EVENT_MANAGER:RegisterForEvent(PLAYER_EVENT_NAME, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:RegisterForEvent(TARGET_EVENT_NAME, EVENT_EFFECT_CHANGED, OnEffectChanged)

    if EVENT_MANAGER.AddFilterForEvent and REGISTER_FILTER_UNIT_TAG then
        EVENT_MANAGER:AddFilterForEvent(PLAYER_EVENT_NAME, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
        EVENT_MANAGER:AddFilterForEvent(TARGET_EVENT_NAME, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "reticleover")
    end

    EVENT_MANAGER:RegisterForEvent(TARGET_CHANGED_EVENT_NAME, EVENT_RETICLE_TARGET_CHANGED, OnTargetChanged)
    eventsRegistered = true
end

local function UnregisterRecordingEvents()
    if not eventsRegistered then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(PLAYER_EVENT_NAME, EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(TARGET_EVENT_NAME, EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(TARGET_CHANGED_EVENT_NAME, EVENT_RETICLE_TARGET_CHANGED)
    eventsRegistered = false
end

local function StartRecording()
    if recording then
        return
    end

    ClearRecords()
    recording = true
    recordingStartedAt = NowMilliseconds()
    recordingStoppedAt = 0

    RegisterRecordingEvents()
    ScanUnit("player", "player")
    ScanUnit("target", "reticleover")

    if not updatesRegistered then
        EVENT_MANAGER:RegisterForUpdate(SCAN_UPDATE_NAME, SCAN_INTERVAL_MS, function()
            if recording then
                ScanUnit("player", "player")
                ScanUnit("target", "reticleover")
            end
        end)

        EVENT_MANAGER:RegisterForUpdate(SESSION_UPDATE_NAME, 250, function()
            if recording and NowMilliseconds() - recordingStartedAt >= RECORDING_DURATION_MS then
                StopRecording(true)
            end
        end)
        updatesRegistered = true
    end

    RefreshSettings()
end

StopRecording = function(autoStopped)
    if not recording then
        return
    end

    recording = false
    recordingStoppedAt = NowMilliseconds()
    UnregisterRecordingEvents()

    if updatesRegistered then
        EVENT_MANAGER:UnregisterForUpdate(SCAN_UPDATE_NAME)
        EVENT_MANAGER:UnregisterForUpdate(SESSION_UPDATE_NAME)
        updatesRegistered = false
    end

    RefreshSettings()
end

local function FormatRemaining(record)
    if record.endedAt then
        return "ended"
    end

    if not record.endTimeMs then
        return "unknown"
    end

    local remaining = (record.endTimeMs - NowMilliseconds()) / 1000
    if remaining <= 0 then
        return "expired"
    end

    return string.format("%.1f sec", remaining)
end

local CATEGORY_ORDER = {
    BUFF = 1,
    DEBUFF = 2,
    OTHER = 3,
}

local SCOPE_ORDER = {
    player = 1,
    target = 2,
}

local function GetScopeLabel(scope)
    if scope == "player" then
        return "PLAYER"
    end

    return "TARGET"
end

local function GetCategoryLabel(category)
    if category == "BUFF" then
        return "BUFFS"
    elseif category == "DEBUFF" then
        return "DEBUFFS"
    end

    return "OTHER EFFECTS"
end

local function PrintResults()
    local duration = 0
    if recordingStartedAt > 0 then
        local stoppedAt = recordingStoppedAt > 0 and recordingStoppedAt or NowMilliseconds()
        duration = math.max(0, math.min(RECORDING_DURATION_MS, stoppedAt - recordingStartedAt)) / 1000
    end

    AddChatLine(string.format("Recorded %.1f sec | unique effects=%d", duration, #records))

    if droppedRecords > 0 then
        AddChatLine(string.format("Buffer limit reached; skipped new unique effects=%d", droppedRecords))
    end

    local ordered = {}
    for _, record in ipairs(records) do
        ordered[#ordered + 1] = record
    end

    table.sort(ordered, function(left, right)
        local leftScope = SCOPE_ORDER[left.scope] or 99
        local rightScope = SCOPE_ORDER[right.scope] or 99
        if leftScope ~= rightScope then
            return leftScope < rightScope
        end

        local leftCategory = CATEGORY_ORDER[left.category] or 99
        local rightCategory = CATEGORY_ORDER[right.category] or 99
        if leftCategory ~= rightCategory then
            return leftCategory < rightCategory
        end

        return left.firstSeenAt < right.firstSeenAt
    end)

    local lastHeader
    for _, record in ipairs(ordered) do
        local header = GetScopeLabel(record.scope) .. " — " .. GetCategoryLabel(record.category)
        if header ~= lastHeader then
            AddChatLine("[" .. header .. "]")
            lastHeader = header
        end

        local targetSuffix = ""
        if record.scope == "target" then
            targetSuffix = string.format(" | target=%s", SafeText(record.targetName, "Current target"))
        end

        local sourceSuffix = ""
        if record.scope == "target" and record.source then
            sourceSuffix = " | source=" .. record.source
        end

        AddChatLine(string.format(
            "%s — ID: %d — time: %s%s%s",
            SafeText(record.name, "Unknown effect"),
            record.abilityId,
            FormatRemaining(record),
            targetSuffix,
            sourceSuffix
        ))
    end

    if #records == 0 then
        AddChatLine("No visible effects were recorded.")
    end
end

ShowResults = function()
    if recording then
        StopRecording(false)
    end

    PrintResults()
    ClearRecords()
    recordingStartedAt = 0
    recordingStoppedAt = 0
    RefreshSettings()
end

local function GetStatusText()
    if recording then
        local elapsed = (NowMilliseconds() - recordingStartedAt) / 1000
        return string.format("Recording: %.1f / 30.0 sec", math.max(0, math.min(30, elapsed)))
    end

    if #records > 0 then
        return string.format("Recording stopped. Results ready: %d unique effects.", #records)
    end

    return "Recording inactive."
end

RefreshSettings = function()
    if CALLBACK_MANAGER and settingsPanel then
        CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", settingsPanel)
    end

    if LibAddonMenu2 and IsKeyboardUISupported and not IsKeyboardUISupported() and LibAddonMenu2.LHASConversion and LibAddonMenu2.LHASConversion.settingTables then
        local consoleSettings = LibAddonMenu2.LHASConversion.settingTables[SETTINGS_ID]
        if consoleSettings and consoleSettings.RefreshSettings then
            consoleSettings:RefreshSettings()
        end
    end
end

local function SetRecording(value)
    if value then
        StartRecording()
    else
        StopRecording(false)
    end
end

local function ClearRecordingFromSettings()
    if recording then
        StopRecording(false)
    end

    ClearRecords()
    recordingStartedAt = 0
    recordingStoppedAt = 0
    RefreshSettings()
end

local function HandleSlashCommand(argument)
    local command = tostring(argument or ""):lower():match("^%s*(.-)%s*$")
    if command == "record" or command == "start" then
        StartRecording()
        AddChatLine("Recording started for up to 30 seconds.")
    elseif command == "scan" or command == "show" then
        ShowResults()
    elseif command == "stop" then
        StopRecording(false)
        AddChatLine("Recording stopped. Use /leoid scan to show the result.")
    elseif command == "clear" then
        ClearRecordingFromSettings()
        AddChatLine("Recorded effects cleared.")
    else
        AddChatLine("Commands: /leoid record, /leoid scan, /leoid stop, /leoid clear")
    end
end

SLASH_COMMANDS["/leoid"] = HandleSlashCommand

local function InitializeSettings()
    if not LibAddonMenu2 then
        AddChatLine("LibAddonMenu-2.0 is missing; settings are unavailable.")
        return
    end

    local panelRegistered, panelOrError = pcall(function()
        return LibAddonMenu2:RegisterAddonPanel(SETTINGS_ID, {
            type = "panel",
            name = DISPLAY_NAME,
            displayName = DISPLAY_NAME,
            author = AUTHOR_NAME,
            version = "0.1.1",
            registerForRefresh = true,
            registerForDefaults = false,
        })
    end)

    if panelRegistered then
        settingsPanel = panelOrError
    else
        AddChatLine("settings panel registration failed: " .. tostring(panelOrError))
    end

    local options = {
        {
            type = "description",
            text = "Records visible buffs and debuffs on you and your current target for up to 30 seconds. This is a read-only diagnostic tool.",
        },
        {
            type = "description",
            text = GetStatusText,
        },
        {
            type = "checkbox",
            name = "Record effects",
            tooltip = "Start or stop a 30-second recording session.",
            getFunc = function() return recording end,
            setFunc = SetRecording,
            default = false,
        },
        {
            type = "button",
            name = "Show results in chat",
            tooltip = "Print the recorded effects and clear the temporary buffer.",
            func = ShowResults,
            width = "full",
        },
        {
            type = "button",
            name = "Clear recorded data",
            tooltip = "Stop recording and erase all temporary data without printing it.",
            func = ClearRecordingFromSettings,
            width = "full",
        },
        {
            type = "header",
            name = "Chat commands",
        },
        {
            type = "description",
            text = "/leoid record — start recording; /leoid scan — show and clear; /leoid stop — stop; /leoid clear — erase.",
        },
    }

    local optionsRegistered, optionsError = pcall(function()
        LibAddonMenu2:RegisterOptionControls(SETTINGS_ID, options)
    end)

    if optionsRegistered then
        settingsRegistered = true
    else
        AddChatLine("settings option registration failed: " .. tostring(optionsError))
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    InitializeSettings()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
