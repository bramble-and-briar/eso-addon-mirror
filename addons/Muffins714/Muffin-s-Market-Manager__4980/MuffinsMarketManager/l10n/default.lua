local strings = {
    ----------------------------------------------------------------------
    -- MMM Menu
    ----------------------------------------------------------------------
    -- Core
    MUFFINS_MARKET_MANAGER_INIT       = "Muffins Market Manager Initialized!",

    MMM_SUBHEADER_GENERAL             = "GENERAL SETTINGS",
    MMM_SUBHEADER_CALCULATOR          = "CALCULATOR SETTINGS",
    MMM_SUBHEADER_GUILD_SALES         = "GUILD SALES WINDOW SETTINGS",
    MMM_SUBHEADER_TRADER_TOOLTIP      = "TRADER TOOLTIP SETTINGS",

    -- sub submenu labels
    MMM_GSW_GOAL_FORMAT               = "GOAL SETTINGS",
    MMM_GSW_COLUMN_COLORS             = "COLUMN COLORS",
    MMM_TT_SUBHEADER_TTC              = "TAMRIEL TRADE CENTRE",
    MMM_TT_SUBHEADER_MM               = "MASTER MERCHANT",

    -- Global settings
    MMM_GLOBAL                        = "Use the same settings for all characters?",
    MMM_WARNING                       = "Changing this will reload the UI",

    -- Multi used
    MMM_USE_CUSTOM_COLORS             = "Use custom colors",

    ----------------------------------------------------------------------
    -- Calculator
    ----------------------------------------------------------------------
    MMM_CALCULATOR_PER_ITEM           = "Price Calculator",
    MMM_CALCULATOR_ITEM_LISTED        = "Last price listed as (per item)",
    MMM_CALCULATOR_STOP_EDITING       = "Stop Editing Price",
    MMM_CALCULATOR_SET_PRICE          = "Set Price Per Item",
    -- Menu
    MMM_CALCULATOR_DESC               = "Remembers your per item price and multiplies it by your stack size",
    MMM_CALCULATOR_ENABLED            = "Use Calculator?",

    ----------------------------------------------------------------------
    -- Guild Sales Window
    ----------------------------------------------------------------------

    MMM_TAXES_COLLECTED               = "Taxes",
    MMM_SELLER_GOAL                   = "Goal",
    MMM_TITLE_HEADER                  = "Weekly Sales Summary",

    MMM_NO_GUILDS_FOUND               =
    "No guilds found yet if you're in a guild, try reopening this menu after fully loading into the game",
    MMM_ITEMS_LISTED                  = "Listed",
    MMM_NOTIFY_DATA_UI                = "Muffins Market Manager Sales data updated!",

    -- Keybind
    MMM_ENABLE_KEYBIND                = "Toggle Guild Sales Window",

    -----------------------------------
    -- Guild Sales Menu
    -----------------------------------
    MMM_AUTO_OPEN_GSW                 = "Auto open window?",
    MMM_AUTO_OPEN_TOOLTIP             = "Automatically opens window when you enter the sell/listing tab",

    MMM_UNLOCK_UI                     = "Unlock UI",
    MMM_UNLOCK_UI_TOOLTIP             = "Set your position for window",
    MMM_PLACEMENT_TOP                 = "Top",
    MMM_PLACEMENT_CENTER              = "Center",

    MMM_MY_LISTINGS_ENABLED           = "Show active items listed?",
    MMM_MY_LISTINGS_TOOLTIP           = "Updates when you visit a trader and decreases as items sell",

    MMM_NOTIFY_DATA_READY             = "Notify when sales data updates",
    MMM_NOTIFY_DATA_READY_TOOLTIP     = "Notifies you when sales history finishes loading or syncing",
    MMM_NOTIFY_UI_PLACEMENT_DATA      = "Data ready placement",

    MMM_GOAL_ENABLED                  = "Set weekly sale goal?",
    MMM_USE_CUSTOM_GOAL               = "Use custom goal format",
    MMM_USE_ABBREVIATED_GOAL          = "Use abbreviated format",
    MMM_USE_ABBREVIATED_GOAL_TOOLTIP  = "Rounds numbers and uses k or mil for display. Goal stays unchanged",
    MMM_RESET_GOAL                    = "Reset Goal?",

    -- Column Colors
    MMM_PROFIT_COLOR                  = "Profit color",
    MMM_TAXES_COLOR                   = "Taxes color",
    MMM_GOAL_COLOR                    = "Goal color",

    ----------------------------------------------------------------------
    -- TraderTooltip
    ----------------------------------------------------------------------
    -- Crafting stations
    MMM_CRAFT_TOTAL_MAT_COST          = "Total Mat Cost",
    MMM_CRAFT_MARKET_VALUE            = "Market Value Per Item",
    MMM_NO_TTC_DATA                   = "No TTC Data",

    -- Tooltip lines
    MMM_TT_TTC_SALES_AVG              = "TTC Sales Avg",
    MMM_TT_TTC_SUGGESTED              = "TTC Suggested",
    MMM_TT_AVG                        = "Avg:",
    MMM_TT_MIN                        = "Min:",
    MMM_TT_MAX                        = "Max:",
    MMM_TT_LISTINGS                   = "Listings",
    MMM_TT_ITEMS                      = "Items",
    MMM_TT_SALES                      = "Sales",
    MMM_TT_DAYS                       = "Days",
    MMM_TT_MM_CRAFT_COST              = "MM craft cost:",
    MMM_TT_VENDOR                     = "Vendor",
    MMM_TT_SELLS_FOR                  = "Sells for",
    MMM_TT_NOT_AVAILABLE              = "not available",
    MMM_TT_NO_SALES_DATA              = "No Sales Data",

    -- Price to chat
    MMM_TT_PRICE_MENU_TITLE           = "Price to chat",
    MMM_TT_PRICE_CHAT_TTC_SHORT       = "Tamriel Trade Centre (short)",
    MMM_TT_PRICE_CHAT_TTC_LONG        = "Tamriel Trade Centre (long)",
    MMM_TT_PRICE_CHAT_MM              = "Master Merchant",
    MMM_TT_PRICE_FOR                  = "Price for",
    MMM_TT_CHAT_SALES_AVG             = "Sales Avg",
    MMM_TT_CHAT_SUGGESTED             = "Suggested",

    -- Gamepad keybinds
    MMM_TT_ACTION_MENU_TITLE_KEYBIND  = "TTC OPTIONS",
    MMM_TT_ACTION_MENU_TITLE          = "Tamriel Trade Centre",
    MMM_TT_ACTION_MENU_PROMPT         = "Selecting any of the options below will open URL in Browser",
    -----------------------------------
    -- TraderTooltip Menu
    -----------------------------------
    -- Trader tooltip Toggle
    MMM_TT_ENABLED                    = "Enable Trader Tooltip",
    MMM_TT_ENABLED_TT                 = "Shows price info on item tooltips",

    MMM_TT_ROUND                      = "Round to nearest gold",
    MMM_TT_ROUND_TT                   = "Rounds price nearest whole gold. Craft costs always display as whole gold",

    MMM_TT_SHOW_WARNINGS              = "Show not available warnings",

    MMM_TT_PURCHASED_INDICATOR_HEADER = "Resets with ReloadUI or logging out",
    MMM_TT_PURCHASED_INDICATOR        = "Highlight purchased items",
    MMM_TT_PURCHASED_INDICATOR_TT     = "Grays out purchased items in the guild browser to help prevent duplicate purchases",

    MMM_TT_BACKPACK_INDICATOR         = "In backpack",
    MMM_TT_BACKPACK_INDICATOR_TT      =
    "Taken from the mailbox and currently in your backpack. Clears once it leaves your bag",

    -- Price indicators
    MMM_TT_INDICATORS_HEADER          = "Price indicators",
    MMM_TT_INDICATORS_REQUIRE_TTC     = "These require Tamriel Trade Centre",

    MMM_TT_VENDOR_INDICATOR           = "Vendor indicator",
    MMM_TT_VENDOR_INDICATOR_TT        = "Shows NPC vendor price and location. Green = good deal, red = cheaper with NPC",

    MMM_TT_GOOD_DEAL_INDICATOR        = "Good deal indicator",
    MMM_TT_GOOD_DEAL_INDICATOR_TT     =
    "Icon 1 = good deal. Icon 2 = less than 10 sales but still good deal",

    MMM_TT_DISPLAY_CRAFT              = "Display cost info at crafting stations?",
    MMM_TT_DISPLAY_CRAFT_TT           =
    "Shows the average crafting cost and market value of item. Doesn't account for multi craft yield bonuses",
    MMM_TT_USE_TTC_MENU               = "Show TTC Menu for website?",
    MMM_TT_USE_TTC_MENU_TT            =
    "Adds action menu for TTC search online and price history",

    -- Price sources
    -- ??? gets replaced with key sources
    MMM_TT_USE_SOURCE                 = "Use ???",
    MMM_TT_MAIN_SOURCE_COLOR          = "??? price line color",
    MMM_TT_SHORT_PRICE                = "Show ??? shorten price data?",
    MMM_TT_PRINT_TO_CHAT              = "Use ??? print to chat?",

    -- TTC settings
    MMM_TT_SHOW_METRICS_TTC           = "Show TTC avg / min / max",
    MMM_TT_SHOW_METRICS_TTC_TT        = "Shows the average, min, and max listing price from TTC",

    MMM_TT_SALES_MODE                 = "TTC sales info for shorten price (AVG SALES)",
    MMM_TT_SALES_MODE_TT              = "Count only shows sale count. Count and total also shows item count",

    MMM_TT_LISTINGS_MODE              = "TTC listings info (? Sales / ? Items)",
    MMM_TT_LISTINGS_MODE_TT           = "Count only shows listing count. Count and total also shows item count",

    MMM_TT_SUGGESTED                  = "Suggested price",

    MMM_TT_SHOW_UPDATED               = "Show TTC updated data line",
    MMM_TT_SHOW_UPDATED_TT            = "Shows when TTC's price data was last updated",

    -- MM settings
    MMM_TT_SHOW_METRICS_MM            = "Show MM Sales / Items / Days",

    MMM_TT_SHOW_CRAFT_COST_MM         = "Show MM craft cost line",
    MMM_TT_SHOW_CRAFT_COST_MM_TT      =
    "Shows MM cost to craft. Separate from the material cost shown at crafting stations",

    -- Shared dropdown choices
    MMM_TT_MODE_SHORT                 = "Count only",
    MMM_TT_MODE_FULL                  = "Count and total",

}

for stringId, stringValue in pairs(strings) do
    ZO_CreateStringId(stringId, stringValue)
    SafeAddVersion(stringId, 1)
end
