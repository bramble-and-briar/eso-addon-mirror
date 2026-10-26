-- Addon namespace
MuffinsMarketManager = {}

-- Create a local shortcut for global
local MMM            = MuffinsMarketManager

-- Addon info
MMM.name             = "MuffinsMarketManager"
MMM.version          = "1.1"
MMM.author           = "Muffins714"

MMM.GlobalSavedVars  = MMM.GlobalSavedVars or {}
MMM.SavedVars        = MMM.SavedVars or {}

-- Default settings
local defaults       = {
    -- Account wide settings
    useGlobalSettings          = true,

    -- Calculator
    calculatorEnabled          = true,

    -- Guild sales window
    guildSalesAutoOpen         = true,
    unlocked                   = false,
    weeklySalesGoalEnabled     = true,
    weeklySalesGoalsByGuild    = {},
    guildRowEnabled            = {},
    -- Items listed column
    myListingsEnabled          = true,
    useCustomColors            = false,
    useCustomGoalFormat        = false,
    useAbbreviatedGoalFormat   = false,
    alertStyleDataReady        = "center",
    notifyDataReady            = true,

    -- Trader Tooltip
    tt_enabled                 = true,
    tt_displayCraftCost        = false,
    tt_showMissingWarnings     = true,

    -- Formatting
    tt_roundPrice              = true,

    -- Indicators
    tt_purchasedIndicator      = true,
    tt_backpackIndicator       = true,
    tt_goodDealIndicator       = false,
    tt_vendorIndicator         = false,

    -- Price sources
    tt_useTTC                  = false,
    tt_useMM                   = false,

    tt_shortPriceTTC           = false,
    tt_shortPriceMM            = false,

    tt_printChatTTC            = false,
    tt_printChatMM             = false,

    -- Tooltip colors, add ATT and UESP when they come back
    tt_mainColorTTC            = { r = 0.6, g = 1, b = 0.6 },
    tt_mainColorMM             = { r = 1, g = 0.85, b = 0.29 },

    -- Per source extras
    tt_showMetricsTTC          = false,
    tt_showMetricsMM           = false,
    tt_showSuggested           = false,
    tt_showUpdatedTTC          = false,
    tt_menuTTC_enabled         = true,
    tt_showCraftCostMM         = false,

    -- TTC line dropdowns
    tt_listingsModeTTC_Enabled = false,
    tt_salesModeTTC_Enabled    = false,
    tt_listingsModeTTC         = "short",
    tt_salesModeTTC            = "short",
}

-- Colors for SetColor
MMM.DEFAULT_COLORS   = {
    limeGreen   = { 0.18, 0.79, 0.19, 1 },
    red         = { 1, 0, 0, 1 },
    softGold    = { 1, 0.85, 0.4, 1 },
    white       = { 1, 1, 1, 1 },
    sand        = { 0.77, 0.76, 0.62, 1 },
    disableGray = { 0.5, 0.5, 0.5, 1 },
}

-- Colors for chat and tooltip text
MMM.HEX_COLOR        = {
    WHITE       = "|cFFFFFF",
    GOLD        = "|ceeca2a",
    SAND        = "|cc5c29e",
    RED         = "|cFF4444",
    GREEN       = "|c44FF44",
    BRIGHT_GOLD = "|cFFD700",
    LOGIN       = "|cEFFBBE",
}

-- Icons
MMM.goldIcon         = ZO_Currency_GetPlatformFormattedGoldIcon()
MMM.IconsFor         = {
    VENDOR_HF_SYMBOL = zo_iconFormat("/esoui/art/icons/servicemappins/servicepin_furnishings.dds", 28, 28),
    VENDOR_SYMBOL    = zo_iconFormat("/esoui/art/icons/servicemappins/servicepin_vendor.dds", 28, 28),
    BUYER_SYMBOL     = zo_iconFormat("/esoui/art/miscellaneous/check_icon_32.dds", 28, 28),
    BS_LOW_SALES     = zo_iconFormat("/esoui/art/miscellaneous/check.dds", 28, 28),
    MAIL_SYMBOL      = zo_iconFormat("/esoui/art/tutorial/gamepad/gp_playermenu_icon_mail.dds", 28, 28),
    BAG_SYMBOL       = zo_iconFormat("/esoui/art/inventory/gamepad/gp_inventory_icon_all.dds", 28, 28),
    GOAL_MET_ICON    = zo_iconFormat("/esoui/art/tutorial/vendor_tabicon_sell_up.dds", 24, 24),
    TRADER_ICON      = zo_iconFormat("EsoUI/Art/Guild/Gamepad/gp_ownership_icon_guildTrader.dds", 24, 24),
}

----------------------------------------------------------------------
-- Chat
----------------------------------------------------------------------
function MMM.MMMPrint(message)
    CHAT_SYSTEM:AddMessage(message)
end

----------------------------------------------------------------------
-- Player Activated
----------------------------------------------------------------------
-- Runs once per login then unregisters itself
function MMM.OnPlayerActivated(event, initial)
    MMM.MMMPrint(MMM.HEX_COLOR.LOGIN .. GetString(MUFFINS_MARKET_MANAGER_INIT) .. "|r")
    -- Restore the window lock and position
    MMM.SetupDragHandlers()
    MMM.UpdateVisibility()
    MMM.RestorePosition()
    EVENT_MANAGER:UnregisterForEvent(MMM.name, EVENT_PLAYER_ACTIVATED)
end

----------------------------------------------------------------------
-- Addon load
----------------------------------------------------------------------
--[[
function MMM.OnAddOnLoaded(event, addonName)
    if addonName ~= MMM.name then return end
    EVENT_MANAGER:UnregisterForEvent(MMM.name, EVENT_ADD_ON_LOADED)

    -- Load settings
    MMM.GlobalSavedVars = ZO_SavedVars:NewAccountWide("MMMGlobalSavedVars", 1, nil, defaults, GetWorldName())
    MMM.CharSavedVars   = ZO_SavedVars:NewCharacterIdSettings("MMMSavedVars", 1, nil, defaults, GetWorldName())

    -- defaults to account wide
    if MMM.CharSavedVars.useGlobalSettings then
        MMM.SavedVars = MMM.GlobalSavedVars
    else
        MMM.SavedVars = MMM.CharSavedVars
    end
]]

function MMM.OnAddOnLoaded(event, addonName)
    if addonName ~= MMM.name then return end
    EVENT_MANAGER:UnregisterForEvent(MMM.name, EVENT_ADD_ON_LOADED)
    -- Load settings
    MMM.GlobalSavedVars = ZO_SavedVars:NewAccountWide("MuffinsMarketManagerSavedVars", 1, nil, defaults,
        GetWorldName())
    MMM.CharSavedVars   = ZO_SavedVars:NewCharacterIdSettings("MuffinsMarketManagerSavedVars", 1, nil, defaults,
        GetWorldName())

    -- Based on Baertram's migration example. Will delete after V1.3 and remove MMMGlobalSavedVars MMMSavedVars from the manifest
    -- One time move from the old two SavedVariables into the new one
    local world         = GetWorldName()   -- NA Megaserver
    local account       = GetDisplayName() -- @Muffins714
    -- Old account settings, once per server
    if not MMM.GlobalSavedVars.migrated then
        local oldAccount = MMMGlobalSavedVars and MMMGlobalSavedVars[world] and MMMGlobalSavedVars[world][account]
            and MMMGlobalSavedVars[world][account]["$AccountWide"]
        if oldAccount then
            for key, value in pairs(oldAccount) do
                if key ~= "version" then
                    MMM.GlobalSavedVars[key] = type(value) == "table" and ZO_DeepTableCopy(value) or value
                end
            end
        end
        MMM.GlobalSavedVars.migrated = true
    end
    -- Old character settings, each character moves the first time it logs in
    if not MMM.CharSavedVars.migrated then
        local oldCharacter = MMMSavedVars and MMMSavedVars[world] and MMMSavedVars[world][account]
            and MMMSavedVars[world][account][GetCurrentCharacterId()]
        if oldCharacter then
            for key, value in pairs(oldCharacter) do
                if key ~= "version" and key ~= "$LastCharacterName" then
                    MMM.CharSavedVars[key] = type(value) == "table" and ZO_DeepTableCopy(value) or value
                end
            end
        end
        MMM.CharSavedVars.migrated = true
    end

    -- defaults to account wide
    if MMM.CharSavedVars.useGlobalSettings then
        MMM.SavedVars = MMM.GlobalSavedVars
    else
        MMM.SavedVars = MMM.CharSavedVars
    end

    -- Keybind name in the controls menu
    ZO_CreateStringId("SI_BINDING_NAME_MMM_TOGGLE_GUILD_SALES_WINDOW", GetString(MMM_ENABLE_KEYBIND))

    MMM.StartLibHistoire()

    EVENT_MANAGER:RegisterForEvent(MMM.name, EVENT_PLAYER_ACTIVATED, MMM.OnPlayerActivated)
    -- Trader Tooltip hooks only install at load so turning it on needs a reload
    local ttEnabled = MMM.GetSettings().tt_enabled
    if ttEnabled then
        EVENT_MANAGER:RegisterForEvent(MMM.name .. "_THResponse", EVENT_TRADING_HOUSE_RESPONSE_RECEIVED,
            MMM.OnTradingHouseResponse)
        -- only track backpack changes skip everything else
        EVENT_MANAGER:RegisterForEvent(MMM.name .. "_InvSlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            MMM.OnInventorySlotUpdate)
        EVENT_MANAGER:AddFilterForEvent(MMM.name .. "_InvSlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
        EVENT_MANAGER:AddFilterForEvent(MMM.name .. "_InvSlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
        -- BACKUP rescans after taking one mail item
        EVENT_MANAGER:RegisterForEvent(MMM.name .. "_MailTakeSuccess", EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS,
            MMM.OnMailTakeAttachmentSuccess)
        -- BACKUP rescans after taking all mail
        EVENT_MANAGER:RegisterForEvent(MMM.name .. "_MailTakeAllCategory",
            EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE, MMM.OnTakeAllCategoryResponse)
    end
    MMM.CreateSettingsMenu(defaults)
    -- Manual toggle
    SLASH_COMMANDS["/mmmsales"] = function() MMM.ToggleGuildSalesWindow() end

    zo_callLater(function()
        MMM.CreateUI()
        MMM.GSW_Initialize()
        -- Trader Tooltip
        if ttEnabled then
            MMM.TT_Initialize()
            MMM.InstallTooltipHooks()
            MMM.InstallCraftHooks()
        end
    end, 100)
end

EVENT_MANAGER:RegisterForEvent(MMM.name, EVENT_ADD_ON_LOADED, MMM.OnAddOnLoaded)
