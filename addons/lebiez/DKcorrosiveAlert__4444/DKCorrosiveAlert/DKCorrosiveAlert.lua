DKCorrosiveAlert = {}
DKCorrosiveAlert.name = "DKCorrosiveAlert"
DKCorrosiveAlert.version = "3.7"

local ADDON_NAME = DKCorrosiveAlert.name
local COMBAT_EVENT_NAME = ADDON_NAME .. "_Combat"
local TIMER_NAME = ADDON_NAME .. "_Timer"
local LOAD_EVENT_NAME = ADDON_NAME .. "_Loaded"

local CORROSIVE_TICK_ABILITY_ID = 17879
local ONSLAUGHT_ABILITY_ID = 83229

local ALERT_DURATION_MS = 3000
local ONSLAUGHT_DURATION_MS = 8000

local defaults = {
    enabled = true,
    soundAlert = true,

    -- Layout
    offsetX = 0,
    offsetY = -220,
    width = 420,
    height = 90,
    scale = 1.0,

    -- Test display
    showTestAlert = false,
}

local alertWindow = nil
local alertLabel = nil

-- Corrosive
local corrosiveEndTimeMs = 0
local corrosiveActive = false
local activeCorrosiveSources = {}

-- OnSlaught
local onslaughtEndTimeMs = 0
local onslaughtActive = false

local function GetNowMs()
    return GetFrameTimeMilliseconds()
end

local function GetActiveCorrosiveCount()
    local now = GetNowMs()
    local count = 0

    for sourceId, expireAt in pairs(activeCorrosiveSources) do
        if expireAt <= now then
            activeCorrosiveSources[sourceId] = nil
        else
            count = count + 1
        end
    end

    return count
end

local function ApplyAlertLayout()
    if not alertWindow or not DKCorrosiveAlert.savedVariables then
        return
    end

    local sv = DKCorrosiveAlert.savedVariables

    alertWindow:ClearAnchors()
    alertWindow:SetAnchor(CENTER, GuiRoot, CENTER, sv.offsetX or 0, sv.offsetY or -220)
    alertWindow:SetDimensions(sv.width or 420, sv.height or 90)
    alertWindow:SetScale(sv.scale or 1.0)
end

local function UpdateDisplayedAlert()
    if not alertLabel or not alertWindow then
        return
    end

    -- Mode test prioritaire
    if DKCorrosiveAlert.savedVariables and DKCorrosiveAlert.savedVariables.showTestAlert then
        alertLabel:SetText("TEST ALERT")
        alertWindow:SetHidden(false)
        return
    end

    local now = GetNowMs()
    local corrosiveCount = GetActiveCorrosiveCount()
    local onslaughtStillActive = onslaughtActive and now < onslaughtEndTimeMs

    -- Priorité à Corrosive
    if corrosiveCount > 0 then
        if corrosiveCount <= 1 then
            alertLabel:SetText("CORROSIVE ARMOR")
        else
            alertLabel:SetText("CORROSIVE ARMOR x" .. tostring(corrosiveCount))
        end
        alertWindow:SetHidden(false)
        return
    end

    if onslaughtStillActive then
        alertLabel:SetText("OnSlaught Ulti")
        alertWindow:SetHidden(false)
        return
    end

    alertWindow:SetHidden(true)
end

local function StopAllAlertsIfNeeded()
    local now = GetNowMs()
    local corrosiveCount = GetActiveCorrosiveCount()

    if corrosiveActive and (corrosiveCount <= 0 or now >= corrosiveEndTimeMs) then
        corrosiveActive = false
        activeCorrosiveSources = {}
        corrosiveEndTimeMs = 0
    end

    if onslaughtActive and now >= onslaughtEndTimeMs then
        onslaughtActive = false
        onslaughtEndTimeMs = 0
    end

    if not corrosiveActive and not onslaughtActive then
        EVENT_MANAGER:UnregisterForUpdate(TIMER_NAME)
    end
end

local function UpdateAlert()
    StopAllAlertsIfNeeded()
    UpdateDisplayedAlert()
end

local function EnsureUpdateLoop()
    EVENT_MANAGER:UnregisterForUpdate(TIMER_NAME)
    EVENT_MANAGER:RegisterForUpdate(TIMER_NAME, 100, UpdateAlert)
end

local function StartOrRefreshCorrosiveAlert()
    corrosiveEndTimeMs = GetNowMs() + ALERT_DURATION_MS
    corrosiveActive = true

    EnsureUpdateLoop()
    UpdateDisplayedAlert()

    if DKCorrosiveAlert.savedVariables and DKCorrosiveAlert.savedVariables.soundAlert then
        PlaySound(SOUNDS.ABILITY_MAJOR_BUFF)
    end
end

local function StartOrRefreshOnslaughtAlert()
    onslaughtEndTimeMs = GetNowMs() + ONSLAUGHT_DURATION_MS
    onslaughtActive = true

    EnsureUpdateLoop()
    UpdateDisplayedAlert()

    if DKCorrosiveAlert.savedVariables and DKCorrosiveAlert.savedVariables.soundAlert then
        PlaySound(SOUNDS.ABILITY_MAJOR_BUFF)
    end
end

local function IsDamageResult(result)
    return result == ACTION_RESULT_DAMAGE
        or result == ACTION_RESULT_CRITICAL_DAMAGE
        or result == ACTION_RESULT_DOT_TICK
        or result == ACTION_RESULT_DOT_TICK_CRITICAL
end

local function CreateUI()
    alertWindow = WINDOW_MANAGER:CreateTopLevelWindow("DKCorrosiveAlertWindow")
    alertWindow:SetDimensions(420, 90)
    alertWindow:SetAnchor(CENTER, GuiRoot, CENTER, 0, -220)
    alertWindow:SetMovable(false)
    alertWindow:SetMouseEnabled(false)
    alertWindow:SetHidden(true)
    alertWindow:SetDrawTier(DT_HIGH)
    alertWindow:SetDrawLayer(DL_OVERLAY)

    local bg = WINDOW_MANAGER:CreateControl(nil, alertWindow, CT_BACKDROP)
    bg:SetAnchorFill(alertWindow)
    bg:SetCenterColor(0, 0, 0, 0.75)
    bg:SetEdgeColor(1, 0, 0, 1)
    bg:SetEdgeTexture(nil, 2, 2, 2, 0)

    alertLabel = WINDOW_MANAGER:CreateControl(nil, alertWindow, CT_LABEL)
    alertLabel:SetFont("ZoFontWinH1")
    alertLabel:SetColor(1, 0.15, 0.15, 1)
    alertLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    alertLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    alertLabel:SetAnchor(CENTER, alertWindow, CENTER, 0, 0)
    alertLabel:SetText("CORROSIVE ARMOR")
end

local function OnCombatEvent(
    eventCode,
    result,
    isError,
    abilityName,
    abilityGraphic,
    abilityActionSlotType,
    sourceName,
    sourceType,
    targetName,
    targetType,
    hitValue,
    powerType,
    damageType,
    log,
    sourceUnitId,
    targetUnitId,
    abilityId,
    overflow
)
    if not DKCorrosiveAlert.savedVariables or not DKCorrosiveAlert.savedVariables.enabled then
        return
    end

    if isError then
        return
    end

    if targetType ~= COMBAT_UNIT_TYPE_PLAYER then
        return
    end

    if not hitValue or hitValue <= 0 then
        return
    end

    if not IsDamageResult(result) then
        return
    end

    -- Corrosive Armor
    if abilityId == CORROSIVE_TICK_ABILITY_ID then
        if sourceUnitId and sourceUnitId ~= "" then
            activeCorrosiveSources[sourceUnitId] = GetNowMs() + ALERT_DURATION_MS
        else
            activeCorrosiveSources["unknown"] = GetNowMs() + ALERT_DURATION_MS
        end

        StartOrRefreshCorrosiveAlert()
        return
    end

    -- OnSlaught Ulti
    if abilityId == ONSLAUGHT_ABILITY_ID then
        StartOrRefreshOnslaughtAlert()
        return
    end
end

function DKCorrosiveAlert:CreateSettings()
    local LAM = LibAddonMenu2
    if not LAM then
        return
    end

    local panelData = {
        type = "panel",
        name = "DK Corrosive Alert",
        displayName = "DK Corrosive Alert",
        author = "Lebiez",
        version = DKCorrosiveAlert.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LAM:RegisterAddonPanel("DKCorrosiveAlertOptions", panelData)

    local optionsTable = {
        {
            type = "checkbox",
            name = "Activate Addon",
            tooltip = "Activate or not alert abilities.",
            getFunc = function()
                return DKCorrosiveAlert.savedVariables.enabled
            end,
            setFunc = function(value)
                DKCorrosiveAlert.savedVariables.enabled = value

                if not value then
                    corrosiveEndTimeMs = 0
                    corrosiveActive = false
                    activeCorrosiveSources = {}

                    onslaughtEndTimeMs = 0
                    onslaughtActive = false

                    EVENT_MANAGER:UnregisterForUpdate(TIMER_NAME)

                    if alertWindow then
                        alertWindow:SetHidden(true)
                    end
                else
                    UpdateDisplayedAlert()
                end
            end,
            default = defaults.enabled,
        },
        {
            type = "checkbox",
            name = "Play sound",
            tooltip = "Play sound when damage from the selected ability is detected.",
            getFunc = function()
                return DKCorrosiveAlert.savedVariables.soundAlert
            end,
            setFunc = function(value)
                DKCorrosiveAlert.savedVariables.soundAlert = value
            end,
            default = defaults.soundAlert,
        },
        {
            type = "header",
            name = "Alert Layout",
        },
        {
            type = "checkbox",
            name = "Show test alert",
            tooltip = "Display a permanent alert to adjust position and size. Default is disabled.",
            getFunc = function()
                return DKCorrosiveAlert.savedVariables.showTestAlert
            end,
            setFunc = function(value)
                DKCorrosiveAlert.savedVariables.showTestAlert = value

                if value then
                    EnsureUpdateLoop()
                    if alertWindow and alertLabel then
                        alertLabel:SetText("TEST ALERT")
                        alertWindow:SetHidden(false)
                    end
                else
                    UpdateDisplayedAlert()
                end
            end,
            default = defaults.showTestAlert,
        },
        {
            type = "slider",
            name = "Horizontal position",
            tooltip = "Move alert left/right.",
            min = -1000,
            max = 1000,
            step = 5,
            getFunc = function()
                return DKCorrosiveAlert.savedVariables.offsetX
            end,
            setFunc = function(value)
                DKCorrosiveAlert.savedVariables.offsetX = value
                ApplyAlertLayout()
            end,
            default = defaults.offsetX,
        },
        {
            type = "slider",
            name = "Vertical position",
            tooltip = "Move alert up/down.",
            min = -1000,
            max = 1000,
            step = 5,
            getFunc = function()
                return DKCorrosiveAlert.savedVariables.offsetY
            end,
            setFunc = function(value)
                DKCorrosiveAlert.savedVariables.offsetY = value
                ApplyAlertLayout()
            end,
            default = defaults.offsetY,
        },
        {
            type = "slider",
            name = "Alert width",
            tooltip = "Change alert width.",
            min = 200,
            max = 1000,
            step = 10,
            getFunc = function()
                return DKCorrosiveAlert.savedVariables.width
            end,
            setFunc = function(value)
                DKCorrosiveAlert.savedVariables.width = value
                ApplyAlertLayout()
            end,
            default = defaults.width,
        },
        {
            type = "slider",
            name = "Alert height",
            tooltip = "Change alert height.",
            min = 40,
            max = 300,
            step = 5,
            getFunc = function()
                return DKCorrosiveAlert.savedVariables.height
            end,
            setFunc = function(value)
                DKCorrosiveAlert.savedVariables.height = value
                ApplyAlertLayout()
            end,
            default = defaults.height,
        },
        {
            type = "slider",
            name = "Alert scale",
            tooltip = "Scale the whole alert.",
            min = 50,
            max = 200,
            step = 5,
            getFunc = function()
                return math.floor((DKCorrosiveAlert.savedVariables.scale or 1.0) * 100)
            end,
            setFunc = function(value)
                DKCorrosiveAlert.savedVariables.scale = value / 100
                ApplyAlertLayout()
            end,
            default = defaults.scale * 100,
        },
        {
            type = "button",
            name = "Reset layout",
            tooltip = "Restore default alert position and size.",
            func = function()
                DKCorrosiveAlert.savedVariables.offsetX = defaults.offsetX
                DKCorrosiveAlert.savedVariables.offsetY = defaults.offsetY
                DKCorrosiveAlert.savedVariables.width = defaults.width
                DKCorrosiveAlert.savedVariables.height = defaults.height
                DKCorrosiveAlert.savedVariables.scale = defaults.scale
                DKCorrosiveAlert.savedVariables.showTestAlert = defaults.showTestAlert

                ApplyAlertLayout()
                UpdateDisplayedAlert()
            end,
            warning = "This will reset alert layout settings.",
        },
    }

    LAM:RegisterOptionControls("DKCorrosiveAlertOptions", optionsTable)
end

local function RegisterCombatEvent()
    EVENT_MANAGER:RegisterForEvent(COMBAT_EVENT_NAME, EVENT_COMBAT_EVENT, OnCombatEvent)

    EVENT_MANAGER:AddFilterForEvent(
        COMBAT_EVENT_NAME,
        EVENT_COMBAT_EVENT,
        REGISTER_FILTER_UNIT_TAG,
        "player"
    )
end

local function OnAddonLoaded(event, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(LOAD_EVENT_NAME, EVENT_ADD_ON_LOADED)

    DKCorrosiveAlert.savedVariables = ZO_SavedVars:NewAccountWide(
        "DKCorrosiveAlertSavedVariables",
        1,
        nil,
        defaults
    )

    CreateUI()
    ApplyAlertLayout()
    DKCorrosiveAlert:CreateSettings()
    RegisterCombatEvent()
    UpdateDisplayedAlert()
end

EVENT_MANAGER:RegisterForEvent(LOAD_EVENT_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)