-- Addon namespace
local ADDON_NAME = "BureauOfMaterialWorth"
local SAVED_VARIABLES_NAME = "BureauOfMaterialWorth_SavedVariables"

-- Release identity. This table is the single runtime source of truth for the
-- version and release date: the footer label, the /bmw status dump and the
-- settings dashboard all format these two fields instead of carrying their own
-- copy of the text (previously the string was duplicated in both localizations
-- and drifted from the manifest). The manifest's `## Version` is the only other
-- place the number appears, because ESO exposes no API to read it back at
-- runtime -- keep the two in step when releasing.
BureauOfMaterialWorth = {
    name = ADDON_NAME,
    savedVariablesName = SAVED_VARIABLES_NAME,
    version = "4.6.202120",
    releaseDate = "05.10.2026",
    -- 0=off, 1=errors, 2=warnings, 3=info, 4=verbose. Ships at 0: a release
    -- build must stay silent in chat until the user opts into diagnostics via
    -- the settings panel or /bmw debug.
    debugMode = 0,
}

-- Local alias to the addon's global table. This file is the one that creates
-- the global, and every other module already binds `local addon = BureauOfMaterialWorth`;
-- keeping the same handle here makes the reference style consistent across files
-- and turns the repeated global lookups into cheap upvalue reads.
local addon = BureauOfMaterialWorth

local private = {}
addon.private = private

-- Hot-path global caching
-- ---------------------------------------------------------------------------
-- In Lua, every reference to a global is a hash lookup in _G. The craft-bag
-- scan touches the ESO inventory API and the standard library once per slot,
-- across potentially hundreds of slots, so those functions are bound to locals
-- (upvalues) once at load time. This turns repeated global lookups into cheap
-- upvalue reads without changing behaviour. Keep this block above the first
-- function definition so the closures below capture these locals.
local GetString     = GetString
local d             = d
local select        = select
local type          = type
local tonumber      = tonumber
local stringformat  = string.format
local stringgmatch  = string.gmatch
local stringlower   = string.lower
local tableinsert   = table.insert
local mathmax       = math.max
local mathmin       = math.min
local zo_round      = zo_round
local ZO_LocalizeDecimalNumber = ZO_LocalizeDecimalNumber

-- Localization/chat helpers
local CHAT_PREFIX = "|c6FCB9F[Bureau Of Material Worth]|r: "
local CHAT_ERROR_PREFIX = "|cFF0000[Bureau Of Material Worth]|r: "

local DEBUG_LEVEL_STRING_IDS = {
    SI_BMW_DEBUG_LEVEL_OFF,
    SI_BMW_DEBUG_LEVEL_ERRORS,
    SI_BMW_DEBUG_LEVEL_WARNINGS,
    SI_BMW_DEBUG_LEVEL_INFO,
    SI_BMW_DEBUG_LEVEL_VERBOSE,
}

local function ResolveLocalizedText(message)
    if type(message) == "number" then
        return GetString(message)
    end

    return tostring(message)
end

local function FormatLocalizedText(message, ...)
    local localizedText = ResolveLocalizedText(message)
    if select("#", ...) > 0 then
        return stringformat(localizedText, ...)
    end
    return localizedText
end

local function GetLocalizedBoolean(value)
    return GetString(value and SI_BMW_BOOL_TRUE or SI_BMW_BOOL_FALSE)
end

local function GetDebugLevelName(level)
    level = mathmax(0, mathmin(4, tonumber(level) or 0))
    return GetString(DEBUG_LEVEL_STRING_IDS[level + 1] or DEBUG_LEVEL_STRING_IDS[1])
end

local function ChatInfo(message, ...)
    d(CHAT_PREFIX .. FormatLocalizedText(message, ...))
end

local function ChatError(message, ...)
    d(CHAT_ERROR_PREFIX .. FormatLocalizedText(message, ...))
end

-- Debug logging system
-- ---------------------------------------------------------------------------
-- Log levels are defined once here. The numeric values double as the
-- debugMode thresholds (emit when debugMode >= level), so this enum is the
-- single source of truth for both the public debugMode contract and the
-- generated Log* helpers below.
local LOG_LEVEL = {
    ERROR = 1,
    WARN  = 2,
    INFO  = 3,
    DEBUG = 4,
}

-- String id per level. Kept as ids (not resolved strings) so GetString is
-- only ever called at log time -- this file stays independent of the
-- localization load order.
local LOG_LEVEL_STRING_IDS = {
    [LOG_LEVEL.ERROR] = SI_BMW_LOG_LEVEL_ERROR,
    [LOG_LEVEL.WARN]  = SI_BMW_LOG_LEVEL_WARN,
    [LOG_LEVEL.INFO]  = SI_BMW_LOG_LEVEL_INFO,
    [LOG_LEVEL.DEBUG] = SI_BMW_LOG_LEVEL_DEBUG,
}

local function Log(level, message, ...)
    if addon.debugMode < level then
        return
    end

    local stringId = LOG_LEVEL_STRING_IDS[level]
    local prefix = stringId and (GetString(stringId) .. " ") or ""
    d(CHAT_PREFIX .. prefix .. FormatLocalizedText(message, ...))
end

-- Level-specific helpers (LogError/LogWarn/LogInfo/LogDebug) are generated
-- from LOG_LEVEL so adding a level needs no extra boilerplate. They are
-- forward-declared as locals first, so closures defined later in the file
-- capture them as upvalues and tooling still resolves each name.
local LogError, LogWarn, LogInfo, LogDebug
do
    local generated = {}
    for name, level in pairs(LOG_LEVEL) do
        generated[name] = function(...) Log(level, ...) end
    end
    LogError = generated.ERROR
    LogWarn  = generated.WARN
    LogInfo  = generated.INFO
    LogDebug = generated.DEBUG
end

-- Shared helpers exposed to the other modules (Valuation/Window/Settings) via
-- the private table, so each module routes chat/log output through the same
-- localized, prefixed path instead of touching d() directly.
private.ChatInfo = ChatInfo
private.ChatError = ChatError
private.GetLocalizedBoolean = GetLocalizedBoolean
private.GetDebugLevelName = GetDebugLevelName

-- A "classic" inventory stack is 200 identical items. The craft bag itself has
-- no such limit (one material = one unbounded virtual slot), but every figure
-- that talks about moving materials into the backpack does: the stack count in
-- the panel's subtitle, the free-capacity estimate, and the withdraw dialog's
-- slot arithmetic. Previously Valuation and WithdrawDialog each declared their
-- own `local STACK_SIZE = 200`, so a future ZOS change would have to be applied
-- twice; both now bind this one value.
private.STACK_SIZE = 200

-- Guild-store selling fees: the single source of truth for the "net if sold"
-- figures shown across the addon (the grand-total hover, the detail window's
-- category/row tooltips and footer summary). Two parts, confirmed against the
-- live game economy:
--   * listing fee : 1% of the listed price, charged up front when posting and
--                   NOT refunded even if the item never sells.
--   * sales tax   : 7%, taken by the trading house only on a sale.
-- A sold item therefore nets 92% of its listed price (the addon values stacks at
-- the market/list price LibPrice reports, so that is what the cut applies to).
-- Kept here, not per-module, so a future ZOS change is a one-line edit.
private.FEE_LISTING_RATE = 0.01
private.FEE_SALES_RATE = 0.07

-- Gold left after both guild-store fees, given a gross (list-price) amount.
-- Subtracts each fee separately (rather than gross * 0.92) so a caller that also
-- itemizes the two fees gets figures that sum exactly to this net.
function private.NetAfterFees(gross)
    gross = gross or 0
    return gross - gross * private.FEE_LISTING_RATE - gross * private.FEE_SALES_RATE
end

-- House palette + gold-formatting, shared by every presentation module (Window,
-- DetailWindow, WithdrawDialog, Settings) so a color/format change is a one-line
-- edit here instead of four. Kept in `private` rather than each module's locals.
-- The eight tones are the whole palette. private.UI (UI.lua) derives its control
-- tints from exactly these strings, so a label's |c code and the fill behind it
-- can no longer describe two different colours.
private.COLOR_ACCENT = "6FCB9F"  -- brand green: titles / grand total
private.COLOR_MUTED  = "8C8A82"  -- dim grey: subtitle / footer / secondary
private.COLOR_NAME   = "DBD9D0"  -- near-white: category / material names
-- One step down from COLOR_NAME, for prose that explains rather than states: the
-- body of a tooltip under its title, a hint under a control. It has to be quieter
-- than a figure the player is reading, but is too long to sit at COLOR_MUTED and
-- stay comfortable.
private.COLOR_SOFT   = "C7C4B8"  -- soft stone: explanatory body text
private.COLOR_GOLD   = "F4D03F"  -- soft gold: gold figures
private.COLOR_WARN   = "D0905E"  -- amber: "missing price" hint
private.COLOR_GAIN    = "8FCB9F"  -- green: positive delta / price change
private.COLOR_LOSS    = "D08A8A"  -- soft red: negative delta / price change

private.GOLD_ICON = "|t16:16:EsoUI/Art/currency/currency_gold.dds|t"

-- Wrap `text` in the given hex color code.
function private.Colorize(hex, text)
    return stringformat("|c%s%s|r", hex, text)
end

-- Format a gold amount with thousands separators and the gold icon, optionally
-- in a color other than the default COLOR_GOLD (e.g. a delta's gain/loss tint).
function private.FormatGold(amount, colorOverride)
    return private.Colorize(colorOverride or private.COLOR_GOLD,
        ZO_LocalizeDecimalNumber(zo_round(amount or 0))) .. " " .. private.GOLD_ICON
end
private.LogError = LogError
private.LogWarn = LogWarn
private.LogInfo = LogInfo
private.LogDebug = LogDebug

-- Local state
local savedVars = {}

local function GetSettingsModule()
    return addon.Settings
end

local function GetValuationModule()
    return addon.Valuation
end

local function GetWindowModule()
    return addon.Window
end

local function GetDetailWindowModule()
    return addon.DetailWindow
end

local function GetWithdrawDialogModule()
    return addon.WithdrawDialog
end

-- Craft-bag visibility wiring
-- ---------------------------------------------------------------------------
-- The window is only meaningful while the craft bag is on screen, and -- per
-- the performance design -- we do no scanning work while it is closed. The
-- craft-bag fragment's StateChange callback is the single authority on
-- visibility: showing it triggers a (lazy, dirty-gated) rescan and reveals the
-- window; hiding it just hides the window. Inventory updates that arrive while
-- the bag is closed only mark the valuation dirty (handled in Valuation).
local function OnCraftBagFragmentStateChange(oldState, newState)
    local valuation = GetValuationModule()
    local window = GetWindowModule()

    if newState == SCENE_FRAGMENT_SHOWN then
        LogDebug(SI_BMW_LOG_CRAFTBAG_SHOWN)
        if valuation then
            valuation.OnCraftBagShown()
        end
        if window then
            window.Show()
        end
    elseif newState == SCENE_FRAGMENT_HIDDEN then
        LogDebug(SI_BMW_LOG_CRAFTBAG_HIDDEN)
        if valuation then
            valuation.OnCraftBagHidden()
        end
        if window then
            window.Hide()
        end
        local detail = GetDetailWindowModule()
        if detail then
            detail.OnCraftBagHidden()
        end
        local withdraw = GetWithdrawDialogModule()
        if withdraw then
            withdraw.OnCraftBagHidden()
        end
    end
end

-- Event handler for EVENT_ADD_ON_LOADED
local function OnAddonLoaded(event, addonName)
    if addonName ~= addon.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)
    LogInfo(SI_BMW_LOG_ONADDONLOADED_LOADING, addon.version)

    -- SavedVariables and the settings panel come first, deliberately BEFORE the
    -- LibPrice check below. Neither depends on a price source, and registering
    -- them unconditionally is what keeps the addon configurable on a broken
    -- install: the previous order bailed out on a missing LibPrice before the
    -- panel and /bmwsettings existed, so a user who wanted to change the debug
    -- level or read the panel's own "LibPrice is missing" explanation had no way
    -- in. The valuation engine and the window still require LibPrice.
    savedVars = GetSettingsModule().InitializeSavedVariables()
    private.savedVars = savedVars

    addon.RegisterSettingsPanel()

    -- LibPrice is the core dependency: without a price source there is nothing
    -- to sum. It is declared as a hard DependsOn, but guard anyway so a broken
    -- install fails loudly in chat instead of erroring deep in the scan. We stop
    -- before building the window/valuation, leaving the settings panel above as
    -- the one working surface.
    if not LibPrice then
        ChatError(SI_BMW_MSG_LIBPRICE_MISSING)
        return
    end

    -- Build the window and the valuation engine now that SavedVariables exist.
    if GetWindowModule() then
        GetWindowModule().Initialize()
    end
    if GetDetailWindowModule() then
        GetDetailWindowModule().Initialize()
    end
    if GetWithdrawDialogModule() then
        GetWithdrawDialogModule().Initialize()
    end
    if GetValuationModule() then
        GetValuationModule().Initialize()
    end

    -- Visibility drives all scan work: register the craft-bag fragment callback.
    CRAFT_BAG_FRAGMENT:RegisterCallback("StateChange", OnCraftBagFragmentStateChange)

    -- The settings panel is already registered above, before the LibPrice guard.

    LogInfo(SI_BMW_LOG_ADDON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)

-- Diagnostics / slash command surface
-- ---------------------------------------------------------------------------
local function DumpStatus()
    local valuation = GetValuationModule()
    ChatInfo(SI_BMW_MSG_VERSION_DEBUG,
        addon.version,
        GetDebugLevelName(addon.debugMode), addon.debugMode)

    if not valuation then
        return
    end

    local grandTotal, pricedSlots, unpricedSlots = valuation.GetStatus()
    -- grandTotal is a sum of (unit price * stack) and can be fractional;
    -- ZO_LocalizeDecimalNumber errors on non-integers, so round before formatting.
    ChatInfo(SI_BMW_MSG_STATUS_TOTAL, private.FormatGold(grandTotal or 0))
    ChatInfo(SI_BMW_MSG_STATUS_SLOTS, pricedSlots or 0, unpricedSlots or 0)

    if valuation.GetInventoryUpdateStats then
        local totalEvents, visibleEvents, rescans = valuation.GetInventoryUpdateStats()
        ChatInfo(SI_BMW_MSG_STATUS_FULL_UPDATES,
            totalEvents or 0, visibleEvents or 0, rescans or 0)
    end
end

local function SetDebugMode(level, suppressOutput)
    return GetSettingsModule().SetDebugMode(level, suppressOutput)
end

local function OpenSettingsPanel()
    return GetSettingsModule().OpenPanel()
end

function addon.RegisterSettingsPanel()
    return GetSettingsModule().RegisterSettingsPanel()
end

private.DumpStatus = DumpStatus

-- Comprehensive slash command
-- ---------------------------------------------------------------------------
-- Sub-commands are looked up in a dispatch table instead of an if/elseif
-- ladder: adding a command is a single table entry, lookup is O(1), and each
-- handler receives the parsed, lower-cased argument list. Unknown actions fall
-- through to the shared error handler.
local SLASH_HELP_STRING_IDS = {
    SI_BMW_MSG_HELP_TITLE,
    SI_BMW_MSG_HELP_STATUS,
    SI_BMW_MSG_HELP_REFRESH,
    SI_BMW_MSG_HELP_SETTINGS,
    SI_BMW_MSG_HELP_DEBUG,
    SI_BMW_MSG_HELP_HELP,
}

local SLASH_COMMAND_HANDLERS = {
    status = function(args)
        DumpStatus()
    end,
    refresh = function(args)
        local valuation = GetValuationModule()
        if valuation then
            if valuation.ForceRefresh() then
                ChatInfo(SI_BMW_MSG_REFRESH_STARTED)
            else
                ChatInfo(SI_BMW_MSG_REFRESH_BUSY)
            end
        end
    end,
    debug = function(args)
        SetDebugMode(args[2])
    end,
    settings = function(args)
        if not OpenSettingsPanel() then
            ChatError(SI_BMW_MSG_SETTINGS_UNAVAILABLE)
        end
    end,
    help = function(args)
        for index = 1, #SLASH_HELP_STRING_IDS do
            ChatInfo(SLASH_HELP_STRING_IDS[index])
        end
    end,
}

-- Convenience aliases so `/bmw ui` and `/bmw panel` also open the settings
-- window, mirroring the primary `settings` sub-command.
SLASH_COMMAND_HANDLERS.ui = SLASH_COMMAND_HANDLERS.settings
SLASH_COMMAND_HANDLERS.panel = SLASH_COMMAND_HANDLERS.settings

SLASH_COMMANDS["/bmw"] = function(cmd)
    local args = {}
    for word in stringgmatch(cmd, "%S+") do
        tableinsert(args, stringlower(word))
    end

    local action = args[1] or "status"
    local handler = SLASH_COMMAND_HANDLERS[action]
    if handler then
        handler(args)
    else
        ChatError(SI_BMW_MSG_UNKNOWN_COMMAND)
    end
end
