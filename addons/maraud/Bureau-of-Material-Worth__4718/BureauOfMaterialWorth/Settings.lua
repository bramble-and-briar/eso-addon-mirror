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

-- Default account-wide configuration. Kept deliberately small: this addon has
-- no gameplay-affecting state, only presentation/diagnostics.
--   debugMode             chat verbosity (mirrors the core's debugMode contract)
--   showCategoryBreakdown show per-profession subtotals under the grand total
--   showCategoryIcons     draw a profession icon left of each category name
--   colorScaleGold        tint gold figures by magnitude (dim -> hot) instead of flat gold
--   sortByValue           order category rows by descending value (vs profession order)
--   detailColumnMode      "basic" (name/qty/value) or "analytics" (adds cumulative share and price change)
--   deltaMode             footer-change baseline: "visit" (until manually viewed, persists) or "session" (until manually viewed or reloadui/logout)
--   showBackground        draw the panel's dark background fill
--   showBorder            draw the panel's border edge
--   windowWidth           panel width in px (see Window MIN/MAX/STEP bounds)
--   windowOffsetX/Y       fine-tune the window position relative to ZO_CraftBag
--   detailWindowLeft/Top  saved absolute position of the material detail window
--   withdrawWindowLeft/Top saved absolute position of the unified withdraw window
--   showInGuildStore      show the panel while the guild store is open (shifted clear of the store UI)
--   lastVisitGold         grand total at the last manually acknowledged visit baseline
--   lastVisitItems        item count at that baseline, retained for legacy-save migration
--   priceHistory          [itemId] = compact bounded series "price~time~source|..."
--   priceTrendThreshold   minimum absolute movement shown in the seven-day price trend view
--   priceTrendAlerts      compact per-item notification state for deduplication/cooldown
--   showValueHistory      draw the grand-total sparkline (Craft Bag value over time) in the footer
--   showProfile           show the @account handle + character name on the panel's title line
--   notificationMode      "off", "summary", "important", or "detailed" chat notification mode
--   valueHistory          ring buffer of grand-total samples; { head = <last index, 0 = empty>,
--                         entries = { { t = unix, gold, items }, ... } }. One point per UI
--                         session (login or /reloadui); later Craft Bag opens do not add
--                         another. See Valuation's RecordValuePoint/GetValueHistory.
--   snapshot              manual single snapshot of bag composition for the detail window's
--                         diff view; nil until "Remember" is pressed (then overwritten). Material
--                         entries are compact strings decoded by Valuation's CaptureSnapshot/GetDiffMaterials.
local DEFAULT_SAVED_VARS = {
    -- Silent by default (0=off), matching the core's shipping debugMode. A fresh
    -- install must not print diagnostics into chat; the user raises this from the
    -- settings panel or /bmw debug when reporting a problem.
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

-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
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
-- Bureau archive incident 20-GB: one persistent record entered UI service.
-- The serializer converted the user's free disk space into paperwork. All of it.
--
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

local function GetSavedVarsOrDefaults()
    return private.savedVars or DEFAULT_SAVED_VARS
end

function Settings.GetSavedVars()
    -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    -- This returns the live persistence root, not a defensive copy. Callers may
    -- read/write known fields, but must preserve the safety invariant above and
    -- must not hand any returned table to UI/framework code that can mutate it.
    -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    return private.savedVars
end

function Settings.InitializeSavedVariables()
    -- Per-server storage. A nil profile makes ZO_SavedVars fall back to the
    -- "Default" bucket, which is shared across every megaserver, so NA/EU/PTS
    -- would overwrite each other (and, worse, share one priceHistory even
    -- though prices differ per server). Passing GetWorldName() as the profile
    -- segregates the data per megaserver.
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

    -- Adopt the persisted debug level as the live one on load, so the core's
    -- debugMode reflects the saved choice (the slash command can still override
    -- it at runtime).
    local level = tonumber(private.savedVars.debugMode)
    if level and level >= 0 and level <= 4 then
        addon.debugMode = level
    end

    Settings.NormalizeWindowWidth()
    private.savedVars.priceTrendThreshold = Settings.GetPriceTrendThreshold()

    return private.savedVars
end

-- Bring a saved windowWidth back inside the layout's supported range.
-- ---------------------------------------------------------------------------
-- Window.CurrentWidth() clamps defensively every time it reads the value, so a
-- bad save never broke the layout -- but it only clamped the *reading*, leaving
-- the out-of-range number in SavedVariables. The slider's getFunc reads the raw
-- save, so a width carried over from a build with different bounds (or edited by
-- hand) showed one number in the settings panel while the panel rendered
-- another, and the mismatch persisted until the user happened to drag the
-- slider. Normalizing once on load makes the saved value, the slider and the
-- rendered width agree from the first frame.
--
-- Also snaps to the slider's step so the stored value is one the slider can
-- actually represent, and repairs a non-numeric entry (a corrupt or
-- hand-edited save) by falling back to the default rather than leaving a string
-- where the layout expects a number.
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

    -- Snap to the step relative to the range's floor, so the snapped values line
    -- up with the slider's own stops (min, min+step, ...) instead of multiples of
    -- the step in absolute terms.
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
    -- Every control's getFunc, the status dashboard, and the breakdown submenu's
    -- gating all read these, so the three can never disagree. Defaults mirror
    -- DEFAULT_SAVED_VARS (the same ~= false / == true sense the window uses).
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

    -- The icon/color/sort controls only do anything while the breakdown is shown
    -- (see Window.Update, which renders category rows solely inside that branch),
    -- so they gate on this shared condition rather than going dim only globally.
    local function BreakdownDisabled()
        return not IsBreakdownOn()
    end

    -- ---------------------------------------------------------------------------
    -- Live status helpers (panel dashboard + breakdown submenu title tag)
    -- ---------------------------------------------------------------------------
    -- LAM re-reads function-valued `text`/`name` on every setting change and on
    -- panel open (registerForRefresh is set), so these read live each time. The
    -- block reflects the saved configuration, not the live bag value: the
    -- valuation only runs while the Craft Bag is open, so a value readout here
    -- would be stale or zero. On = the shipped green, off = the muted label grey;
    -- mode rows (order/baseline are not on/off) use the neutral label tone.
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
            type = "description",
            text = GetString(SI_BMW_PANEL_OVERVIEW),
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

    local byName, diagnostics = {}, {}
    local inDiagnostics = false
    for index = 4, #optionsData do
        local option = optionsData[index]
        if option.type == "header" and option.name == GetString(SI_BMW_HEADER_DIAGNOSTICS) then
            inDiagnostics = true
        elseif inDiagnostics then
            diagnostics[#diagnostics + 1] = option
        elseif option.type ~= "header" then
            byName[option.reference or option.name] = option
        end
    end
    local sections = {
        { title = SI_BMW_HEADER_DISPLAY, names = {
            GetString(SI_BMW_SETTING_DENSITY_NAME), GetString(SI_BMW_SETTING_BACKGROUND_NAME),
            GetString(SI_BMW_SETTING_BORDER_NAME), GetString(SI_BMW_SETTING_PROFILE_NAME),
            GetString(SI_BMW_SETTING_WIDTH_NAME), GetString(SI_BMW_SETTING_OFFSET_X_NAME),
            GetString(SI_BMW_SETTING_OFFSET_Y_NAME),
        } },
        { title = SI_BMW_HEADER_TABLE, names = {
            "BMWSettingsBreakdownGroup", GetString(SI_BMW_SETTING_DETAIL_COLUMNS_NAME),
        } },
        { title = SI_BMW_HEADER_HISTORY, names = {
            GetString(SI_BMW_SETTING_PRICE_TREND_THRESHOLD_NAME),
            GetString(SI_BMW_SETTING_DELTA_MODE_NAME), GetString(SI_BMW_SETTING_VALUE_HISTORY_NAME),
        } },
        { title = SI_BMW_HEADER_NOTIFICATIONS, names = {
            GetString(SI_BMW_SETTING_NOTIFY_VISIT_NAME), GetString(SI_BMW_SETTING_GUILD_STORE_NAME),
        } },
    }
    local groupedOptions = { optionsData[1], optionsData[3] }
    for index = 1, #sections do
        local section = sections[index]
        local controls = {}
        for nameIndex = 1, #section.names do
            controls[#controls + 1] = byName[section.names[nameIndex]]
        end
        if section.title == SI_BMW_HEADER_DISPLAY then
            groupedOptions[#groupedOptions + 1] = {
                type = "header", name = GetString(section.title), width = "full",
            }
            for controlIndex = 1, #controls do
                groupedOptions[#groupedOptions + 1] = controls[controlIndex]
            end
        else
            groupedOptions[#groupedOptions + 1] = {
                type = "submenu", name = GetString(section.title), controls = controls,
            }
        end
    end
    groupedOptions[#groupedOptions + 1] = {
        type = "header", name = GetString(SI_BMW_HEADER_DIAGNOSTICS), width = "full",
    }
    for index = 1, #diagnostics do
        groupedOptions[#groupedOptions + 1] = diagnostics[index]
    end

    local panel = lam:RegisterAddonPanel(panelIdentifier, panelData)
    lam:RegisterOptionControls(panelIdentifier, groupedOptions)
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
