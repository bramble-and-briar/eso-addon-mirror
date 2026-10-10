local addon = BureauOfMaterialWorth
addon.Settings = addon.Settings or {}

local Settings = addon.Settings
local private = addon.private

local GetString = GetString
local tonumber = tonumber
local zo_round = zo_round
local stringformat = string.format

local HISTORY_CLEANUP_DIALOG = "BUREAU_OF_MATERIAL_WORTH_HISTORY_CLEANUP"
local historyCleanupSummary

-- Account/server-wide defaults for presentation, diagnostics, and bounded histories.
-- priceHistory stores encoded price/time/source series per item; valueHistory is
-- a ring buffer with one total-value sample per UI session. Valuation owns codecs.
-- The comparison snapshot is created automatically after prices settle or manually
-- with Remember; visit/session baselines advance when their changes are reviewed.
local DEFAULT_SAVED_VARS = {
    -- Diagnostics are opt-in.
    debugMode = 0,
    showCategoryBreakdown = true,
    showCategoryIcons = true,
    colorScaleGold = true,
    sortByValue = false,
    detailColumnMode = "analytics",
    uiDensity = "comfortable",
    deltaMode = "visit",
    showBackground = true,
    showBorder = false,
    showValueHistory = true,
    showProfile = true,
    notificationMode = "detailed",
    showInGuildStore = true,
    windowWidth = 460,
    windowOffsetX = -25,
    windowOffsetY = 0,
    priceTrendThreshold = 20,
    priceHistory = {},
    priceTrendAlerts = {},
    valueHistory = { head = 0, entries = {} },
}

--
-- SAVEDVARIABLES SAFETY INVARIANT
-- ---------------------------------------------------------------------------
-- Everything reachable from this SavedVariables root must be an acyclic,
-- persistence-owned graph made only from numbers, booleans, strings, and newly
-- allocated plain tables. Never store addon modules, UI controls, callbacks,
-- runtime caches, library/API result tables, or references back to `addon`,
-- `private`, `_G`, or the SavedVariables root itself.
--
-- A SavedVariables-owned table must also never be passed directly to an API
-- that may mutate its input. In particular, ZO_ScrollList_CreateDataEntry adds
-- UI bookkeeping to the supplied data table, including a back-reference from
-- dataEntry.data to that same table. If the table belongs to SavedVariables,
-- this creates a cycle that ESO's serializer can expand indefinitely, growing
-- the save file to many gigabytes during one save operation.
--
-- Persistence data may be decoded or copied into detached runtime rows, but the
-- UI must receive only those new tables. When adding a saved field, keep its
-- size explicitly bounded and store scalar/encoded copies rather than borrowed
-- table references.
--
-- A prior persistence/UI cycle grew the save file to about 20 GB.
--

local function GetSavedVarsOrDefaults()
    return private.savedVars or DEFAULT_SAVED_VARS
end

function Settings.GetSavedVars()
    -- This returns the live persistence root, not a defensive copy. Callers may
    -- read/write known fields, but must preserve the safety invariant above and
    -- must not hand any returned table to UI/framework code that can mutate it.
    return private.savedVars
end

function Settings.InitializeSavedVariables()
    -- Separate settings and price histories by megaserver.
    local worldName = GetWorldName()

    -- Earlier versions saved everything under the shared "Default" profile.
    -- Seed each server from an independent copy when it is first opened. Keep
    -- the legacy bucket so a later first login on another megaserver can migrate
    -- the same settings/history without sharing mutable tables between servers.
    local raw = _G[addon.savedVariablesName]
    if type(raw) == "table" and raw["Default"] ~= nil and raw[worldName] == nil then
        raw[worldName] = ZO_DeepTableCopy(raw["Default"])
    end

    private.savedVars = ZO_SavedVars:NewAccountWide(
        addon.savedVariablesName,
        1,
        nil,
        DEFAULT_SAVED_VARS,
        worldName
    )

    -- Restore a valid persisted diagnostic level.
    local level = tonumber(private.savedVars.debugMode)
    if level and level >= 0 and level <= 4 then
        addon.debugMode = level
    end

    Settings.NormalizeWindowWidth()
    private.savedVars.priceTrendThreshold = Settings.GetPriceTrendThreshold()

    return private.savedVars
end

-- Repair, clamp, and snap the persisted width so the window and slider agree.
function Settings.NormalizeWindowWidth()
    local sv = private.savedVars
    if not sv then
        return
    end

    local minWidth = (addon.Window and addon.Window.MIN_WIDTH) or 460
    local maxWidth = (addon.Window and addon.Window.MAX_WIDTH) or 600
    local step = (addon.Window and addon.Window.WIDTH_STEP) or 10
    local default = (addon.Window and addon.Window.DEFAULT_WIDTH)
        or DEFAULT_SAVED_VARS.windowWidth

    local width = tonumber(sv.windowWidth)
    if not width then
        sv.windowWidth = default
        return
    end

    -- Slider steps are relative to the minimum, not absolute multiples.
    if step > 0 then
        width = minWidth + zo_round((width - minWidth) / step) * step
    end

    if width < minWidth then
        width = minWidth
    elseif width > maxWidth then
        width = maxWidth
    end

    sv.windowWidth = width
end

function Settings.IsCategoryBreakdownEnabled()
    return GetSavedVarsOrDefaults().showCategoryBreakdown ~= false
end

function Settings.GetNotificationMode()
    local vars = GetSavedVarsOrDefaults()
    local mode = vars.notificationMode
    if mode == "off" or mode == "summary" or mode == "important" or mode == "detailed" then
        return mode
    end

    -- Preserve the previous checkbox's behavior for existing accounts until a
    -- notification mode is selected explicitly.
    return vars.notifyOnVisit == false and "off" or "summary"
end

private.GetNotificationMode = Settings.GetNotificationMode

function Settings.GetPriceTrendThreshold()
    local threshold = tonumber(GetSavedVarsOrDefaults().priceTrendThreshold)
        or DEFAULT_SAVED_VARS.priceTrendThreshold
    threshold = zo_round(threshold / 5) * 5
    if threshold < 5 then
        return 5
    elseif threshold > 100 then
        return 100
    end
    return threshold
end

private.GetPriceTrendThreshold = Settings.GetPriceTrendThreshold

function Settings.SetDebugMode(level, suppressOutput)
    level = tonumber(level) or 0
    if level >= 0 and level <= 4 then
        addon.debugMode = level
        if private.savedVars then
            private.savedVars.debugMode = level
        end
        if not suppressOutput then
            private.ChatInfo(SI_BMW_MSG_DEBUG_MODE_SET, private.GetDebugLevelName(level), level)
        end
        return true
    end

    if not suppressOutput then
        private.ChatError(SI_BMW_MSG_INVALID_DEBUG_LEVEL)
    end
    return false
end

function Settings.GetHistoryCleanupSummary()
    return historyCleanupSummary or GetString(SI_BMW_HISTORY_CLEANUP_PENDING)
end

local function CleanPriceHistory()
    local valuation = addon.Valuation
    if not valuation or not valuation.PrunePriceHistory then
        historyCleanupSummary = GetString(SI_BMW_HISTORY_CLEANUP_UNAVAILABLE)
        private.ChatError(SI_BMW_HISTORY_CLEANUP_UNAVAILABLE)
    else
        local result = valuation.PrunePriceHistory()
        local formatCount = ZO_LocalizeDecimalNumber
        if result.materialsChecked == 0 then
            historyCleanupSummary = GetString(SI_BMW_HISTORY_CLEANUP_EMPTY)
        elseif result.pointsRemoved == 0 and result.materialsRemoved == 0
            and result.bytesRemoved == 0 then
            historyCleanupSummary = stringformat(GetString(SI_BMW_HISTORY_CLEANUP_NO_CHANGE),
                formatCount(result.materialsChecked))
        else
            historyCleanupSummary = stringformat(GetString(SI_BMW_HISTORY_CLEANUP_RESULT),
                formatCount(result.materialsChecked), formatCount(result.pointsRemoved),
                formatCount(result.materialsRemoved), formatCount(result.pointsRemaining),
                formatCount(result.bytesRemoved))
            historyCleanupSummary = historyCleanupSummary .. "\n"
                .. GetString(SI_BMW_HISTORY_CLEANUP_SAVE_NOTICE)
        end
        private.ChatInfo(historyCleanupSummary)
    end

    if CALLBACK_MANAGER and Settings.panel then
        CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", Settings.panel)
    end
end

function Settings.RegisterSettingsPanel()
    local lam = LibAddonMenu2
    if not lam then
        private.LogWarn(SI_BMW_LOG_LAM_MISSING)
        return
    end

    local panelIdentifier = addon.name .. "_Settings"
    ZO_Dialogs_RegisterCustomDialog(HISTORY_CLEANUP_DIALOG, {
        title = { text = GetString(SI_BMW_HISTORY_CLEANUP_CONFIRM_TITLE) },
        mainText = { text = GetString(SI_BMW_HISTORY_CLEANUP_CONFIRM_BODY) },
        buttons = {
            {
                text = GetString(SI_BMW_HISTORY_CLEANUP_ACCEPT),
                callback = CleanPriceHistory,
            },
            {
                text = GetString(SI_BMW_HISTORY_CLEANUP_CANCEL),
            },
        },
    })
    local debugChoices = {
        private.GetDebugLevelName(0),
        private.GetDebugLevelName(1),
        private.GetDebugLevelName(2),
        private.GetDebugLevelName(3),
        private.GetDebugLevelName(4),
    }

    -- ---------------------------------------------------------------------------
    -- Single source of truth for the panel's read side
    -- ---------------------------------------------------------------------------
    -- Shared getters for controls, status text, and dependent toggle states.
    local function IsBreakdownOn()    return Settings.IsCategoryBreakdownEnabled() end
    local function IsIconsOn()        return GetSavedVarsOrDefaults().showCategoryIcons ~= false end
    local function IsColorScaleOn()   return GetSavedVarsOrDefaults().colorScaleGold ~= false end
    local function IsSortByValueOn()  return GetSavedVarsOrDefaults().sortByValue == true end
    local function GetDetailColumnMode()
        local mode = GetSavedVarsOrDefaults().detailColumnMode
        return mode == "analytics" and "analytics" or "basic"
    end
    local function IsValueHistoryOn() return GetSavedVarsOrDefaults().showValueHistory ~= false end
    local function IsProfileOn()      return GetSavedVarsOrDefaults().showProfile ~= false end
    local function GetNotificationMode() return Settings.GetNotificationMode() end
    local function GetPriceTrendThreshold() return Settings.GetPriceTrendThreshold() end
    local function IsGuildStoreOn()   return GetSavedVarsOrDefaults().showInGuildStore ~= false end
    local function GetDeltaMode()     return GetSavedVarsOrDefaults().deltaMode or DEFAULT_SAVED_VARS.deltaMode end

    -- Icon/color/sort controls are disabled when category rows are hidden.
    local function BreakdownDisabled()
        return not IsBreakdownOn()
    end

    -- ---------------------------------------------------------------------------
    -- Live status helpers (panel dashboard + breakdown submenu title tag)
    -- ---------------------------------------------------------------------------
    -- The refreshable dashboard describes saved settings, not live inventory value.
    local STATUS_COLOR_ON   = private.COLOR_ACCENT
    local STATUS_COLOR_OFF  = private.COLOR_MUTED
    local STATUS_COLOR_MODE = private.UI.HEX.brass

    local Colorize = private.Colorize

    -- A plain colored on/off word for the dashboard rows.
    local function StatusOnOff(enabled)
        return Colorize(enabled and STATUS_COLOR_ON or STATUS_COLOR_OFF,
            GetString(enabled and SI_BMW_STATUS_ON or SI_BMW_STATUS_OFF))
    end

    -- A bracketed colored tag for a submenu title. `word` is already localized.
    local function StatusTag(enabled, word)
        return Colorize(enabled and STATUS_COLOR_ON or STATUS_COLOR_OFF, "[" .. word .. "]")
    end

    local function BoolTag(enabled)
        return StatusTag(enabled, GetString(enabled and SI_BMW_STATUS_ON or SI_BMW_STATUS_OFF))
    end

    -- A neutral-toned value for the mode rows (sort order / change baseline),
    -- which are a choice between modes rather than an on/off state.
    local function ModeValue(word)
        return Colorize(STATUS_COLOR_MODE, word)
    end

    -- "Label  value" dashboard row; the label is localized, the value pre-colored.
    local function StatusRow(labelKey, valueText)
        return string.format("%s  %s", GetString(labelKey), valueText)
    end

    -- Sort order is a mode, not on/off: show which ordering is in effect.
    local function SortWord()
        return GetString(IsSortByValueOn() and SI_BMW_STATUS_SORT_BY_VALUE
            or SI_BMW_STATUS_SORT_BY_PROFESSION)
    end

    -- The change baseline is a mode (visit/session); reuse the dropdown's own
    -- localized choice strings so the dashboard label matches the control.
    local function DeltaWord()
        return GetString(GetDeltaMode() == "session"
            and SI_BMW_SETTING_DELTA_MODE_SESSION or SI_BMW_SETTING_DELTA_MODE_VISIT)
    end

    -- One "Label  value" row per key feature/state, read through the same getters
    -- the controls below use so the block can never drift from them.
    local function BuildStatusText()
        local rows = {
            StatusRow(SI_BMW_STATUS_LABEL_BREAKDOWN,     StatusOnOff(IsBreakdownOn())),
            StatusRow(SI_BMW_STATUS_LABEL_SORT,          ModeValue(SortWord())),
            StatusRow(SI_BMW_STATUS_LABEL_COLOR_SCALE,   StatusOnOff(IsColorScaleOn())),
            StatusRow(SI_BMW_STATUS_LABEL_VALUE_HISTORY, StatusOnOff(IsValueHistoryOn())),
            StatusRow(SI_BMW_STATUS_LABEL_PROFILE,       StatusOnOff(IsProfileOn())),
            StatusRow(SI_BMW_STATUS_LABEL_NOTIFY,        ModeValue(GetString(({
                off = SI_BMW_SETTING_NOTIFY_MODE_OFF,
                summary = SI_BMW_SETTING_NOTIFY_MODE_SUMMARY,
                important = SI_BMW_SETTING_NOTIFY_MODE_IMPORTANT,
                detailed = SI_BMW_SETTING_NOTIFY_MODE_DETAILED,
            })[GetNotificationMode()]))),
            StatusRow(SI_BMW_STATUS_LABEL_GUILD_STORE,   StatusOnOff(IsGuildStoreOn())),
            StatusRow(SI_BMW_STATUS_LABEL_DELTA,         ModeValue(DeltaWord())),
        }
        return table.concat(rows, "\n")
    end

    local panelData = {
        type = "panel",
        name = GetString(SI_BMW_PANEL_NAME),
        displayName = GetString(SI_BMW_PANEL_DISPLAY_NAME),
        author = Colorize(private.COLOR_ACCENT, "meshlg") .. " @ArtieFox",
        version = addon.version,
        slashCommand = "/bmwsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "description",
            text = GetString(SI_BMW_PANEL_INTRO),
            width = "full",
        },
        {
            -- Live at-a-glance dashboard. function-valued text so LAM refreshes it
            -- on panel open and after any setting change (registerForRefresh).
            type = "description",
            title = GetString(SI_BMW_STATUS_TITLE),
            text = BuildStatusText,
            width = "full",
            reference = "BMWSettingsStatusBlock",
        },
        {
            type = "header",
            name = GetString(SI_BMW_HEADER_DISPLAY),
            width = "full",
        },
        {
            type = "dropdown",
            name = GetString(SI_BMW_SETTING_DENSITY_NAME),
            tooltip = GetString(SI_BMW_SETTING_DENSITY_TOOLTIP),
            choices = {
                GetString(SI_BMW_SETTING_DENSITY_COMFORTABLE),
                GetString(SI_BMW_SETTING_DENSITY_COMPACT),
            },
            choicesValues = { "comfortable", "compact" },
            getFunc = function()
                return GetSavedVarsOrDefaults().uiDensity == "compact" and "compact" or "comfortable"
            end,
            setFunc = function(value)
                private.savedVars.uiDensity = value == "compact" and "compact" or "comfortable"
            end,
            default = DEFAULT_SAVED_VARS.uiDensity,
            requiresReload = true,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BMW_SETTING_BACKGROUND_NAME),
            tooltip = GetString(SI_BMW_SETTING_BACKGROUND_TOOLTIP),
            getFunc = function() return GetSavedVarsOrDefaults().showBackground ~= false end,
            setFunc = function(value)
                private.savedVars.showBackground = value
                if addon.Window then
                    addon.Window.ApplyAppearance()
                end
            end,
            default = DEFAULT_SAVED_VARS.showBackground,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BMW_SETTING_BORDER_NAME),
            tooltip = GetString(SI_BMW_SETTING_BORDER_TOOLTIP),
            getFunc = function() return GetSavedVarsOrDefaults().showBorder ~= false end,
            setFunc = function(value)
                private.savedVars.showBorder = value
                if addon.Window then
                    addon.Window.ApplyAppearance()
                end
            end,
            default = DEFAULT_SAVED_VARS.showBorder,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BMW_SETTING_PROFILE_NAME),
            tooltip = GetString(SI_BMW_SETTING_PROFILE_TOOLTIP),
            getFunc = function() return IsProfileOn() end,
            setFunc = function(value)
                private.savedVars.showProfile = value
                if addon.Window then
                    addon.Window.Update()
                end
            end,
            default = DEFAULT_SAVED_VARS.showProfile,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(SI_BMW_SETTING_WIDTH_NAME),
            tooltip = GetString(SI_BMW_SETTING_WIDTH_TOOLTIP),
            min = addon.Window and addon.Window.MIN_WIDTH or 460,
            max = addon.Window and addon.Window.MAX_WIDTH or 600,
            step = addon.Window and addon.Window.WIDTH_STEP or 10,
            getFunc = function() return GetSavedVarsOrDefaults().windowWidth or DEFAULT_SAVED_VARS.windowWidth end,
            setFunc = function(value)
                private.savedVars.windowWidth = value
                if addon.Window then
                    addon.Window.ApplyWidth()
                end
            end,
            default = DEFAULT_SAVED_VARS.windowWidth,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(SI_BMW_SETTING_OFFSET_X_NAME),
            tooltip = GetString(SI_BMW_SETTING_OFFSET_X_TOOLTIP),
            min = -400,
            max = 400,
            step = 5,
            getFunc = function() return GetSavedVarsOrDefaults().windowOffsetX or -25 end,
            setFunc = function(value)
                private.savedVars.windowOffsetX = value
                if addon.Window then
                    addon.Window.ApplyAnchor()
                end
            end,
            default = DEFAULT_SAVED_VARS.windowOffsetX,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(SI_BMW_SETTING_OFFSET_Y_NAME),
            tooltip = GetString(SI_BMW_SETTING_OFFSET_Y_TOOLTIP),
            min = -400,
            max = 400,
            step = 5,
            getFunc = function() return GetSavedVarsOrDefaults().windowOffsetY or 0 end,
            setFunc = function(value)
                private.savedVars.windowOffsetY = value
                if addon.Window then
                    addon.Window.ApplyAnchor()
                end
            end,
            default = DEFAULT_SAVED_VARS.windowOffsetY,
            width = "full",
        },
        {
            type = "submenu",
            name = GetString(SI_BMW_HEADER_TABLE),
            controls = {
                {
                    -- Category-breakdown cluster. The master "show breakdown" toggle plus
                    -- the three controls (icons, color, sort) that only do anything while
                    -- it is on, grouped in a submenu whose title carries a live [on]/[off]
                    -- tag. The dependent controls gate on BreakdownDisabled so they grey
                    -- out together when the breakdown is off.
                    type = "submenu",
                    reference = "BMWSettingsBreakdownGroup",
                    name = function()
                        return GetString(SI_BMW_SUBMENU_BREAKDOWN_NAME) .. "  " .. BoolTag(IsBreakdownOn())
                    end,
                    tooltip = GetString(SI_BMW_SUBMENU_BREAKDOWN_DESCRIPTION),
                    controls = {
                        {
                            type = "description",
                            text = GetString(SI_BMW_SUBMENU_BREAKDOWN_DESCRIPTION),
                            width = "full",
                        },
                        {
                            type = "checkbox",
                            name = GetString(SI_BMW_SETTING_CATEGORY_BREAKDOWN_NAME),
                            tooltip = GetString(SI_BMW_SETTING_CATEGORY_BREAKDOWN_TOOLTIP),
                            getFunc = function() return IsBreakdownOn() end,
                            setFunc = function(value)
                                private.savedVars.showCategoryBreakdown = value
                                if addon.Window then
                                    addon.Window.Update()
                                end
                            end,
                            default = DEFAULT_SAVED_VARS.showCategoryBreakdown,
                            width = "full",
                            reference = "BMWSettingsCategoryBreakdown",
                        },
                        {
                            type = "checkbox",
                            name = GetString(SI_BMW_SETTING_CATEGORY_ICONS_NAME),
                            tooltip = GetString(SI_BMW_SETTING_CATEGORY_ICONS_TOOLTIP),
                            getFunc = function() return IsIconsOn() end,
                            setFunc = function(value)
                                private.savedVars.showCategoryIcons = value
                                if addon.Window then
                                    addon.Window.Update()
                                end
                            end,
                            default = DEFAULT_SAVED_VARS.showCategoryIcons,
                            disabled = BreakdownDisabled,
                            width = "full",
                            reference = "BMWSettingsCategoryIcons",
                        },
                        {
                            type = "checkbox",
                            name = GetString(SI_BMW_SETTING_COLOR_SCALE_NAME),
                            tooltip = GetString(SI_BMW_SETTING_COLOR_SCALE_TOOLTIP),
                            getFunc = function() return IsColorScaleOn() end,
                            setFunc = function(value)
                                private.savedVars.colorScaleGold = value
                                if addon.Window then
                                    addon.Window.Update()
                                end
                            end,
                            default = DEFAULT_SAVED_VARS.colorScaleGold,
                            disabled = BreakdownDisabled,
                            width = "full",
                            reference = "BMWSettingsColorScale",
                        },
                        {
                            type = "checkbox",
                            name = GetString(SI_BMW_SETTING_SORT_BY_VALUE_NAME),
                            tooltip = GetString(SI_BMW_SETTING_SORT_BY_VALUE_TOOLTIP),
                            getFunc = function() return IsSortByValueOn() end,
                            setFunc = function(value)
                                private.savedVars.sortByValue = value
                                if addon.Window then
                                    addon.Window.Update()
                                end
                            end,
                            default = DEFAULT_SAVED_VARS.sortByValue,
                            disabled = BreakdownDisabled,
                            width = "full",
                            reference = "BMWSettingsSortByValue",
                        },
                    },
                },
                {
                    type = "dropdown",
                    name = GetString(SI_BMW_SETTING_DETAIL_COLUMNS_NAME),
                    tooltip = GetString(SI_BMW_SETTING_DETAIL_COLUMNS_TOOLTIP),
                    choices = {
                        GetString(SI_BMW_SETTING_DETAIL_COLUMNS_BASIC),
                        GetString(SI_BMW_SETTING_DETAIL_COLUMNS_ANALYTICS),
                    },
                    choicesValues = { "basic", "analytics" },
                    getFunc = GetDetailColumnMode,
                    setFunc = function(value)
                        private.savedVars.detailColumnMode = value
                        if addon.DetailWindow then
                            addon.DetailWindow.ApplyColumnMode()
                        end
                    end,
                    default = DEFAULT_SAVED_VARS.detailColumnMode,
                    width = "full",
                },
            },
        },
        {
            type = "submenu",
            name = GetString(SI_BMW_HEADER_HISTORY),
            controls = {
                {
                    type = "slider",
                    name = GetString(SI_BMW_SETTING_PRICE_TREND_THRESHOLD_NAME),
                    tooltip = GetString(SI_BMW_SETTING_PRICE_TREND_THRESHOLD_TOOLTIP),
                    min = 5,
                    max = 100,
                    step = 5,
                    getFunc = GetPriceTrendThreshold,
                    setFunc = function(value)
                        private.savedVars.priceTrendThreshold = value
                        if addon.Window then
                            addon.Window.Update()
                        end
                        if addon.DetailWindow then
                            addon.DetailWindow.Refresh()
                        end
                    end,
                    default = DEFAULT_SAVED_VARS.priceTrendThreshold,
                    width = "full",
                },
                {
                    type = "dropdown",
                    name = GetString(SI_BMW_SETTING_DELTA_MODE_NAME),
                    tooltip = GetString(SI_BMW_SETTING_DELTA_MODE_TOOLTIP),
                    choices = { GetString(SI_BMW_SETTING_DELTA_MODE_VISIT), GetString(SI_BMW_SETTING_DELTA_MODE_SESSION) },
                    choicesValues = { "visit", "session" },
                    getFunc = function() return GetDeltaMode() end,
                    setFunc = function(value)
                        private.savedVars.deltaMode = value
                        if addon.Window then
                            addon.Window.Update()
                        end
                    end,
                    default = DEFAULT_SAVED_VARS.deltaMode,
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BMW_SETTING_VALUE_HISTORY_NAME),
                    tooltip = GetString(SI_BMW_SETTING_VALUE_HISTORY_TOOLTIP),
                    getFunc = function() return IsValueHistoryOn() end,
                    setFunc = function(value)
                        private.savedVars.showValueHistory = value
                        if addon.Window then
                            addon.Window.Update()
                        end
                    end,
                    default = DEFAULT_SAVED_VARS.showValueHistory,
                    width = "full",
                },
            },
        },
        {
            type = "submenu",
            name = GetString(SI_BMW_HEADER_NOTIFICATIONS),
            controls = {
                {
                    type = "dropdown",
                    name = GetString(SI_BMW_SETTING_NOTIFY_VISIT_NAME),
                    tooltip = GetString(SI_BMW_SETTING_NOTIFY_VISIT_TOOLTIP),
                    choices = {
                        GetString(SI_BMW_SETTING_NOTIFY_MODE_OFF),
                        GetString(SI_BMW_SETTING_NOTIFY_MODE_SUMMARY),
                        GetString(SI_BMW_SETTING_NOTIFY_MODE_IMPORTANT),
                        GetString(SI_BMW_SETTING_NOTIFY_MODE_DETAILED),
                    },
                    choicesValues = { "off", "summary", "important", "detailed" },
                    getFunc = GetNotificationMode,
                    setFunc = function(value)
                        private.savedVars.notificationMode = value
                    end,
                    default = DEFAULT_SAVED_VARS.notificationMode,
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BMW_SETTING_GUILD_STORE_NAME),
                    tooltip = GetString(SI_BMW_SETTING_GUILD_STORE_TOOLTIP),
                    getFunc = function() return IsGuildStoreOn() end,
                    setFunc = function(value)
                        private.savedVars.showInGuildStore = value
                        if addon.Window then
                            addon.Window.Show()
                        end
                    end,
                    default = DEFAULT_SAVED_VARS.showInGuildStore,
                    width = "full",
                },
            },
        },
        {
            type = "header",
            name = GetString(SI_BMW_HEADER_DIAGNOSTICS),
            width = "full",
        },
        {
            type = "dropdown",
            name = GetString(SI_BMW_SETTING_DEBUG_MODE_NAME),
            tooltip = GetString(SI_BMW_SETTING_DEBUG_MODE_TOOLTIP),
            choices = debugChoices,
            getFunc = function() return private.GetDebugLevelName(addon.debugMode) end,
            setFunc = function(value)
                for level = 0, 4 do
                    if value == private.GetDebugLevelName(level) then
                        Settings.SetDebugMode(level, true)
                        break
                    end
                end
            end,
            default = private.GetDebugLevelName(DEFAULT_SAVED_VARS.debugMode),
            width = "full",
        },
        {
            type = "button",
            name = GetString(SI_BMW_SETTING_REFRESH_NAME),
            tooltip = GetString(SI_BMW_SETTING_REFRESH_TOOLTIP),
            func = function()
                if addon.Valuation then
                    addon.Valuation.ForceRefresh()
                end
            end,
            width = "full",
        },
        {
            type = "header",
            name = GetString(SI_BMW_HEADER_SAVED_DATA),
            width = "full",
        },
        {
            type = "description",
            text = GetString(SI_BMW_HISTORY_CLEANUP_DESCRIPTION) .. "\n\n"
                .. GetString(SI_BMW_HISTORY_CLEANUP_SAVE_NOTICE),
            width = "full",
        },
        {
            type = "button",
            name = GetString(SI_BMW_HISTORY_CLEANUP_BUTTON),
            tooltip = GetString(SI_BMW_HISTORY_CLEANUP_TOOLTIP),
            func = function()
                ZO_Dialogs_ShowDialog(HISTORY_CLEANUP_DIALOG)
            end,
            disabled = function()
                return not addon.Valuation or not addon.Valuation.PrunePriceHistory
            end,
            width = "full",
        },
        {
            type = "description",
            title = GetString(SI_BMW_HISTORY_CLEANUP_RESULT_TITLE),
            text = Settings.GetHistoryCleanupSummary,
            width = "full",
        },
    }

    local panel = lam:RegisterAddonPanel(panelIdentifier, panelData)
    lam:RegisterOptionControls(panelIdentifier, optionsData)
    Settings.panel = panel
end

-- Opens the settings panel programmatically (used by the `/bmw settings` slash
-- sub-command). Returns true when the panel was opened, false when the
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
addon.RegisterSettingsPanel = Settings.RegisterSettingsPanel
addon.OpenSettingsPanel = Settings.OpenPanel
