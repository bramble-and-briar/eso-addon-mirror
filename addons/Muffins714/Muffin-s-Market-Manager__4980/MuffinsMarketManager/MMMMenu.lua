-- Create a local shortcut for global
local MMM           = MuffinsMarketManager

-- Dependencies
local LAM           = LibAddonMenu2

MMM.SavedVars       = MMM.SavedVars or {}
MMM.GlobalSavedVars = MMM.GlobalSavedVars or {}

-- Returns account or character settings based on the global toggle
local function GetSettings()
    return MMM.SavedVars
end

MMM.GetSettings = GetSettings

-- Converts DEFAULT_COLORS
local function ToSavedColor(color)
    return { r = color[1], g = color[2], b = color[3], a = color[4] }
end

function MMM.CreateSettingsMenu(defaults)
    local panelName = MMM.name .. "SettingsPanel"
    local panel = {
        type                = "panel",
        name                = "Muffins Market Manager",
        author              = MMM.author,
        version             = "" .. MMM.version,
        slashCommand        = "/MMM",
        website             = MMM.website,
        registerForRefresh  = true,
        registerForDefaults = true,
    }
    LAM:RegisterAddonPanel(panelName, panel)

    ----------------------------------------------------------------------
    -- Calculator submenu
    ----------------------------------------------------------------------
    local CalculatorSubmenu = {
        {
            type = "description",
            text = GetString(MMM_CALCULATOR_DESC),
        },
        -- Calculator on/off
        {
            type    = "checkbox",
            name    = GetString(MMM_CALCULATOR_ENABLED),
            getFunc = function() return GetSettings().calculatorEnabled end,
            setFunc = function(state)
                GetSettings().calculatorEnabled = state
            end,
            default = defaults.calculatorEnabled,
            width   = "full",
        },
    }

    ----------------------------------------------------------------------
    -- Guild Sales Window submenu
    ----------------------------------------------------------------------
    -- One checkbox goal slider and reset button per guild with a trader
    local function BuildPerGuildGoalControls()
        local controls = {}
        for guildIndex = 1, GetNumGuilds() do
            local guildId = GetGuildId(guildIndex)
            if guildId and GetGuildOwnedKioskInfo(guildId) then
                local guildName = GetGuildName(guildId)

                -- Show this guild in the window
                table.insert(controls, {
                    type    = "checkbox",
                    name    = guildName,
                    getFunc = function()
                        local perGuild = GetSettings().guildRowEnabled
                        local isEnabled = perGuild and perGuild[guildId]
                        if isEnabled == nil then isEnabled = true end
                        return isEnabled
                    end,
                    setFunc = function(state)
                        local settings = GetSettings()
                        settings.guildRowEnabled = settings.guildRowEnabled or {}
                        settings.guildRowEnabled[guildId] = state
                        MMM.RefreshGuildSalesWindow()
                    end,
                    default = true,
                    width   = "full",
                })
                -- Weekly goal for this guild
                table.insert(controls, {
                    type     = "slider",
                    name     = guildName .. " " .. GetString(MMM_SELLER_GOAL),
                    min      = 1000,
                    max      = 2000000,
                    step     = 1000,
                    getFunc  = function()
                        local perGuild = GetSettings().weeklySalesGoalsByGuild
                        return (perGuild and perGuild[guildId]) or 0
                    end,
                    setFunc  = function(value)
                        local settings = GetSettings()
                        settings.weeklySalesGoalsByGuild = settings.weeklySalesGoalsByGuild or {}
                        settings.weeklySalesGoalsByGuild[guildId] = value
                        MMM.RefreshGuildSalesWindow()
                    end,
                    default  = 0,
                    disabled = function() return not GetSettings().weeklySalesGoalEnabled end,
                    width    = "half",
                })
                -- Reset this guild's goal to 0
                table.insert(controls, {
                    type  = "button",
                    name  = GetString(MMM_RESET_GOAL),
                    func  = function()
                        local settings = GetSettings()
                        settings.weeklySalesGoalsByGuild = settings.weeklySalesGoalsByGuild or {}
                        settings.weeklySalesGoalsByGuild[guildId] = 0
                        MMM.RefreshGuildSalesWindow()
                    end,
                    width = "half",
                })
            end
        end
        -- Message when no guilds with a trader are found
        if #controls == 0 then
            table.insert(controls, {
                type = "description",
                text = GetString(MMM_NO_GUILDS_FOUND),
                width = "full",
            })
        end
        return controls
    end

    local perGuildGoalControls = BuildPerGuildGoalControls()

    -- Goal Format submenu
    local GoalFormatSubmenu = {
        -- Weekly goal on/off
        {
            type    = "checkbox",
            name    = GetString(MMM_GOAL_ENABLED),
            getFunc = function() return GetSettings().weeklySalesGoalEnabled end,
            setFunc = function(state)
                GetSettings().weeklySalesGoalEnabled = state
                MMM.RefreshGuildSalesWindow()
            end,
            default = defaults.weeklySalesGoalEnabled,
            width   = "full",
        },
        -- Custom goal format
        {
            type     = "checkbox",
            name     = GetString(MMM_USE_CUSTOM_GOAL),
            getFunc  = function() return GetSettings().useCustomGoalFormat end,
            setFunc  = function(state)
                GetSettings().useCustomGoalFormat = state
                MMM.RefreshGuildSalesWindow()
            end,
            default  = defaults.useCustomGoalFormat,
            disabled = function() return not GetSettings().weeklySalesGoalEnabled end,
            width    = "half",
        },
        -- Abbreviated goal like 1.5k
        {
            type     = "checkbox",
            name     = GetString(MMM_USE_ABBREVIATED_GOAL),
            tooltip  = GetString(MMM_USE_ABBREVIATED_GOAL_TOOLTIP),
            getFunc  = function() return GetSettings().useAbbreviatedGoalFormat end,
            setFunc  = function(state)
                GetSettings().useAbbreviatedGoalFormat = state
                MMM.RefreshGuildSalesWindow()
            end,
            default  = defaults.useAbbreviatedGoalFormat,
            disabled = function() return not GetSettings().useCustomGoalFormat end,
            width    = "half",
        },
    }

    -- Column Colors submenu
    local ColumnColorsSubmenu = {
        -- Custom colors on/off
        {
            type    = "checkbox",
            name    = GetString(MMM_USE_CUSTOM_COLORS),
            getFunc = function() return GetSettings().useCustomColors end,
            setFunc = function(state)
                local settings = GetSettings()
                settings.useCustomColors = state

                -- Fill in default colors the first time it gets turned on
                if state then
                    settings.profitColor = settings.profitColor or ToSavedColor(MMM.DEFAULT_COLORS.limeGreen)
                    settings.taxesColor  = settings.taxesColor or ToSavedColor(MMM.DEFAULT_COLORS.red)
                    settings.goalColor   = settings.goalColor or ToSavedColor(MMM.DEFAULT_COLORS.softGold)
                end

                MMM.RefreshGuildSalesWindow()
            end,
            default = defaults.useCustomColors,
            width   = "half",
        },
        -- Profit color
        {
            type     = "colorpicker",
            name     = GetString(MMM_PROFIT_COLOR),
            getFunc  = function()
                local c = GetSettings().profitColor
                if c then return c.r, c.g, c.b, c.a end
                return unpack(MMM.DEFAULT_COLORS.limeGreen)
            end,
            setFunc  = function(r, g, b, a)
                GetSettings().profitColor = { r = r, g = g, b = b, a = a }
                MMM.RefreshGuildSalesWindow()
            end,
            disabled = function() return not GetSettings().useCustomColors end,
            width    = "half",
        },
        -- Taxes color
        {
            type     = "colorpicker",
            name     = GetString(MMM_TAXES_COLOR),
            getFunc  = function()
                local c = GetSettings().taxesColor
                if c then return c.r, c.g, c.b, c.a end
                return unpack(MMM.DEFAULT_COLORS.red)
            end,
            setFunc  = function(r, g, b, a)
                GetSettings().taxesColor = { r = r, g = g, b = b, a = a }
                MMM.RefreshGuildSalesWindow()
            end,
            disabled = function() return not GetSettings().useCustomColors end,
            width    = "half",
        },
        -- Goal color
        {
            type     = "colorpicker",
            name     = GetString(MMM_GOAL_COLOR),
            getFunc  = function()
                local c = GetSettings().goalColor
                if c then return c.r, c.g, c.b, c.a end
                return unpack(MMM.DEFAULT_COLORS.softGold)
            end,
            setFunc  = function(r, g, b, a)
                GetSettings().goalColor = { r = r, g = g, b = b, a = a }
                MMM.RefreshGuildSalesWindow()
            end,
            disabled = function() return not GetSettings().useCustomColors end,
            width    = "half",
        },
    }

    -- Top level Guild Sales Window submenu
    local GuildSalesSubmenu = {
        -- Auto open with the guild store
        {
            type    = "checkbox",
            name    = GetString(MMM_AUTO_OPEN_GSW),
            tooltip = GetString(MMM_AUTO_OPEN_TOOLTIP),
            getFunc = function() return GetSettings().guildSalesAutoOpen end,
            setFunc = function(state)
                GetSettings().guildSalesAutoOpen = state
            end,
            default = defaults.guildSalesAutoOpen,
            width   = "half",
        },
        -- Unlock to move the window
        {
            type = "checkbox",
            name = GetString(MMM_UNLOCK_UI),
            tooltip = GetString(MMM_UNLOCK_UI_TOOLTIP),
            getFunc = function()
                return GetSettings().unlocked
            end,
            setFunc = function(value)
                GetSettings().unlocked = value
                MMM.UpdateVisibility()
            end,
            width = "half",
            default = defaults.unlocked,
        },
        -- Data ready alert on/off
        {
            type    = "checkbox",
            name    = GetString(MMM_NOTIFY_DATA_READY),
            tooltip = GetString(MMM_NOTIFY_DATA_READY_TOOLTIP),
            getFunc = function() return GetSettings().notifyDataReady end,
            setFunc = function(state) GetSettings().notifyDataReady = state end,
            default = defaults.notifyDataReady,
            width   = "half",
        },
        -- Data ready alert placement
        {
            type = "dropdown",
            name = GetString(MMM_NOTIFY_UI_PLACEMENT_DATA),
            choices = { GetString(MMM_PLACEMENT_TOP), GetString(MMM_PLACEMENT_CENTER) },
            choicesValues = { "top", "center" },
            getFunc = function() return GetSettings().alertStyleDataReady end,
            setFunc = function(state) GetSettings().alertStyleDataReady = state end,
            default = defaults.alertStyleDataReady,
            disabled = function() return not GetSettings().notifyDataReady end,
            width = "half",
        },
        -- Items listed column
        {
            type    = "checkbox",
            name    = GetString(MMM_MY_LISTINGS_ENABLED),
            tooltip = GetString(MMM_MY_LISTINGS_TOOLTIP),
            getFunc = function() return GetSettings().myListingsEnabled end,
            setFunc = function(state)
                GetSettings().myListingsEnabled = state
                MMM.RefreshGuildSalesWindow()
            end,
            default = defaults.myListingsEnabled,
            width   = "full",
        },
        {
            type     = "submenu",
            name     = GetString(MMM_GSW_GOAL_FORMAT),
            controls = GoalFormatSubmenu,
        },
        {
            type     = "submenu",
            name     = GetString(MMM_GSW_COLUMN_COLORS),
            controls = ColumnColorsSubmenu,
        },
    }

    -- Add the per guild controls to the Goal Format submenu
    for _, control in ipairs(perGuildGoalControls) do
        table.insert(GoalFormatSubmenu, control)
    end

    ----------------------------------------------------------------------
    -- TraderTooltip submenu
    ----------------------------------------------------------------------
    -- Grays out every tooltip option when the tooltip is off
    local function IsTraderTooltipOff()
        return not GetSettings().tt_enabled
    end

    -- Shared source options plus that source's extras
    local function BuildSourceSubmenu(source, extraControls)
        local key = source.key
        -----------------------------
        -- Shared by every source
        -----------------------------
        local controls = {
            -- Use this source
            {
                type     = "checkbox",
                name     = GetString(MMM_TT_USE_SOURCE):gsub("%?%?%?", key),
                getFunc  = function() return GetSettings()["tt_use" .. key] end,
                setFunc  = function(state) GetSettings()["tt_use" .. key] = state end,
                default  = defaults["tt_use" .. key],
                disabled = IsTraderTooltipOff,
                width    = "half",
            },
            -- Main price line color
            {
                type     = "colorpicker",
                name     = GetString(MMM_TT_MAIN_SOURCE_COLOR):gsub("%?%?%?", key),
                getFunc  = function()
                    local c = GetSettings()["tt_mainColor" .. key]
                    if c then return c.r, c.g, c.b end
                    return 0.6, 1, 0.6
                end,
                setFunc  = function(r, g, b)
                    GetSettings()["tt_mainColor" .. key] = { r = r, g = g, b = b }
                end,
                disabled = function() return IsTraderTooltipOff() or not GetSettings()["tt_use" .. key] end,
                width    = "half",
            },
            -- Short price line
            {
                type     = "checkbox",
                name     = GetString(MMM_TT_SHORT_PRICE):gsub("%?%?%?", key),
                getFunc  = function() return GetSettings()["tt_shortPrice" .. key] end,
                setFunc  = function(state) GetSettings()["tt_shortPrice" .. key] = state end,
                default  = defaults["tt_shortPrice" .. key],
                disabled = function() return IsTraderTooltipOff() or not GetSettings()["tt_use" .. key] end,
                width    = "half",
            },
            -- Print to chat
            {
                type     = "checkbox",
                name     = GetString(MMM_TT_PRINT_TO_CHAT):gsub("%?%?%?", key),
                getFunc  = function() return GetSettings()["tt_printChat" .. key] end,
                setFunc  = function(state) GetSettings()["tt_printChat" .. key] = state end,
                default  = defaults["tt_printChat" .. key],
                disabled = function() return IsTraderTooltipOff() or not GetSettings()["tt_use" .. key] end,
                width    = "half",
            },
        }

        -----------------------------
        -- PER SOURCE extras
        -----------------------------
        if extraControls then
            for _, c in ipairs(extraControls) do table.insert(controls, c) end
        end
        return controls
    end

    -----------------------------
    -- TAMRIEL TRADE CENTRE ONLY
    -----------------------------
    local TTCExtra = {
        -- Updated today line
        {
            type     = "checkbox",
            name     = GetString(MMM_TT_SHOW_UPDATED),
            tooltip  = GetString(MMM_TT_SHOW_UPDATED_TT),
            getFunc  = function() return GetSettings().tt_showUpdatedTTC end,
            setFunc  = function(state) GetSettings().tt_showUpdatedTTC = state end,
            default  = defaults.tt_showUpdatedTTC,
            disabled = function() return IsTraderTooltipOff() or not GetSettings().tt_useTTC end,
            width    = "half",
        },
        -- Sales line on/off
        {
            type     = "checkbox",
            name     = GetString(MMM_TT_SALES_MODE),
            tooltip  = GetString(MMM_TT_SALES_MODE_TT),
            getFunc  = function() return GetSettings().tt_salesModeTTC_Enabled end,
            setFunc  = function(state) GetSettings().tt_salesModeTTC_Enabled = state end,
            default  = defaults.tt_salesModeTTC_Enabled,
            disabled = function() return IsTraderTooltipOff() or not GetSettings().tt_shortPriceTTC end,
            width    = "full",
        },
        -- Sales line mode
        {
            type          = "dropdown",
            name          = "", -- the checkbox above is the title
            choices       = { GetString(MMM_TT_MODE_SHORT), GetString(MMM_TT_MODE_FULL) },
            choicesValues = { "short", "full" },
            getFunc       = function() return GetSettings().tt_salesModeTTC end,
            setFunc       = function(value) GetSettings().tt_salesModeTTC = value end,
            default       = defaults.tt_salesModeTTC,
            disabled      = function() return IsTraderTooltipOff() or not GetSettings().tt_salesModeTTC_Enabled end,
            width         = "full",
        },
        -- Listings line on/off
        {
            type     = "checkbox",
            name     = GetString(MMM_TT_LISTINGS_MODE),
            tooltip  = GetString(MMM_TT_LISTINGS_MODE_TT),
            getFunc  = function() return GetSettings().tt_listingsModeTTC_Enabled end,
            setFunc  = function(state) GetSettings().tt_listingsModeTTC_Enabled = state end,
            default  = defaults.tt_listingsModeTTC_Enabled,
            disabled = function() return IsTraderTooltipOff() or not GetSettings().tt_useTTC end,
            width    = "full",
        },
        -- Listings line mode
        {
            type          = "dropdown",
            name          = "", -- the checkbox above is the title
            choices       = { GetString(MMM_TT_MODE_SHORT), GetString(MMM_TT_MODE_FULL) },
            choicesValues = { "short", "full" },
            getFunc       = function() return GetSettings().tt_listingsModeTTC end,
            setFunc       = function(value) GetSettings().tt_listingsModeTTC = value end,
            default       = defaults.tt_listingsModeTTC,
            disabled      = function() return IsTraderTooltipOff() or not GetSettings().tt_listingsModeTTC_Enabled end,
            width         = "full",
        },
        -- Suggested price line
        {
            type     = "checkbox",
            name     = GetString(MMM_TT_SUGGESTED),
            getFunc  = function() return GetSettings().tt_showSuggested end,
            setFunc  = function(state) GetSettings().tt_showSuggested = state end,
            default  = defaults.tt_showSuggested,
            disabled = function() return IsTraderTooltipOff() or not GetSettings().tt_useTTC end,
            width    = "half",
        },
        -- Avg / Min / Max line
        {
            type     = "checkbox",
            name     = GetString(MMM_TT_SHOW_METRICS_TTC),
            tooltip  = GetString(MMM_TT_SHOW_METRICS_TTC_TT),
            getFunc  = function() return GetSettings().tt_showMetricsTTC end,
            setFunc  = function(state) GetSettings().tt_showMetricsTTC = state end,
            default  = defaults.tt_showMetricsTTC,
            disabled = function() return IsTraderTooltipOff() or not GetSettings().tt_useTTC end,
            width    = "half",
        },
    }

    -----------------------------
    -- MASTER MERCHANT ONLY
    -----------------------------
    local MMExtra = {
        -- Craft cost line
        {
            type     = "checkbox",
            name     = GetString(MMM_TT_SHOW_CRAFT_COST_MM),
            tooltip  = GetString(MMM_TT_SHOW_CRAFT_COST_MM_TT),
            getFunc  = function() return GetSettings().tt_showCraftCostMM end,
            setFunc  = function(state) GetSettings().tt_showCraftCostMM = state end,
            default  = defaults.tt_showCraftCostMM,
            disabled = function() return IsTraderTooltipOff() or not GetSettings().tt_useMM end,
            width    = "half",
        },
        -- Sales / items / days line
        {
            type     = "checkbox",
            name     = GetString(MMM_TT_SHOW_METRICS_MM),
            getFunc  = function() return GetSettings().tt_showMetricsMM end,
            setFunc  = function(state) GetSettings().tt_showMetricsMM = state end,
            default  = defaults.tt_showMetricsMM,
            disabled = function() return IsTraderTooltipOff() or not GetSettings().tt_useMM end,
            width    = "full",
        },
    }

    -- Finds a source in MMM.TT_Sources by key
    local function GetSource(key)
        for _, s in ipairs(MMM.TT_Sources) do
            if s.key == key then return s end
        end
    end

    local TraderTooltipSubmenu = {
        -- Trader tooltip on/off
        {
            type    = "checkbox",
            name    = GetString(MMM_TT_ENABLED),
            tooltip = GetString(MMM_TT_ENABLED_TT),
            warning = GetString(MMM_WARNING),
            getFunc = function() return GetSettings().tt_enabled end,
            setFunc = function(state)
                local settings = GetSettings()
                if settings.tt_enabled == state then return end
                settings.tt_enabled = state
                zo_callLater(ReloadUI, 100)
            end,
            default = defaults.tt_enabled,
            width   = "full",
        },
        -- Round prices
        {
            type     = "checkbox",
            name     = GetString(MMM_TT_ROUND),
            tooltip  = GetString(MMM_TT_ROUND_TT),
            getFunc  = function() return GetSettings().tt_roundPrice end,
            setFunc  = function(state) GetSettings().tt_roundPrice = state end,
            default  = defaults.tt_roundPrice,
            disabled = IsTraderTooltipOff,
            width    = "half",
        },
        -- Missing data warnings
        {
            type     = "checkbox",
            name     = GetString(MMM_TT_SHOW_WARNINGS),
            getFunc  = function() return GetSettings().tt_showMissingWarnings end,
            setFunc  = function(state) GetSettings().tt_showMissingWarnings = state end,
            default  = defaults.tt_showMissingWarnings,
            disabled = IsTraderTooltipOff,
            width    = "half",
        },
        {
            type = "description",
            text = GetString(MMM_TT_PURCHASED_INDICATOR_HEADER),
        },
        -- Purchased indicator
        {
            type     = "checkbox",
            name     = GetString(MMM_TT_PURCHASED_INDICATOR) .. " " .. MMM.IconsFor.MAIL_SYMBOL,
            tooltip  = GetString(MMM_TT_PURCHASED_INDICATOR_TT),
            getFunc  = function() return GetSettings().tt_purchasedIndicator end,
            setFunc  = function(state) GetSettings().tt_purchasedIndicator = state end,
            default  = defaults.tt_purchasedIndicator,
            disabled = IsTraderTooltipOff,
            width    = "half",
        },
        -- Backpack indicator
        {
            type     = "checkbox",
            name     = GetString(MMM_TT_BACKPACK_INDICATOR) .. " " .. MMM.IconsFor.BAG_SYMBOL,
            tooltip  = GetString(MMM_TT_BACKPACK_INDICATOR_TT),
            getFunc  = function() return GetSettings().tt_backpackIndicator end,
            setFunc  = function(state) GetSettings().tt_backpackIndicator = state end,
            default  = defaults.tt_backpackIndicator,
            disabled = function() return IsTraderTooltipOff() or not GetSettings().tt_purchasedIndicator end,
            width    = "half",
        },
        { type = "header", name = GetString(MMM_TT_INDICATORS_HEADER) },
        {
            type = "description",
            text = GetString(MMM_TT_INDICATORS_REQUIRE_TTC),
        },
        -- Vendor price indicator
        {
            type     = "checkbox",
            name     = GetString(MMM_TT_VENDOR_INDICATOR) ..
                " " .. MMM.IconsFor.VENDOR_HF_SYMBOL .. MMM.IconsFor.VENDOR_SYMBOL,
            tooltip  = GetString(MMM_TT_VENDOR_INDICATOR_TT),
            getFunc  = function() return GetSettings().tt_vendorIndicator end,
            setFunc  = function(state) GetSettings().tt_vendorIndicator = state end,
            default  = defaults.tt_vendorIndicator,
            disabled = function() return IsTraderTooltipOff() or not GetSettings().tt_useTTC end,
            width    = "half",
        },
        -- Good deal indicator
        {
            type     = "checkbox",
            name     = GetString(MMM_TT_GOOD_DEAL_INDICATOR) ..
                " " .. MMM.IconsFor.BUYER_SYMBOL .. " " .. MMM.IconsFor.BS_LOW_SALES,
            tooltip  = GetString(MMM_TT_GOOD_DEAL_INDICATOR_TT),
            getFunc  = function() return GetSettings().tt_goodDealIndicator end,
            setFunc  = function(state) GetSettings().tt_goodDealIndicator = state end,
            default  = defaults.tt_goodDealIndicator,
            disabled = function() return IsTraderTooltipOff() or not GetSettings().tt_useTTC end,
            width    = "half",
        },
        -- Craft cost line
        {
            type     = "checkbox",
            name     = GetString(MMM_TT_DISPLAY_CRAFT),
            tooltip  = GetString(MMM_TT_DISPLAY_CRAFT_TT),
            getFunc  = function() return GetSettings().tt_displayCraftCost end,
            setFunc  = function(state) GetSettings().tt_displayCraftCost = state end,
            default  = defaults.tt_displayCraftCost,
            disabled = function() return IsTraderTooltipOff() or not GetSettings().tt_useTTC end,
            width    = "half",
        },
        -- TTC menu button
        {
            type     = "checkbox",
            name     = GetString(MMM_TT_USE_TTC_MENU),
            tooltip  = GetString(MMM_TT_USE_TTC_MENU_TT),
            getFunc  = function() return GetSettings().tt_menuTTC_enabled end,
            setFunc  = function(state) GetSettings().tt_menuTTC_enabled = state end,
            default  = defaults.tt_menuTTC_enabled,
            disabled = function() return IsTraderTooltipOff() or not GetSettings().tt_useTTC end,
            width    = "half",
        },
        {
            type     = "submenu",
            name     = GetString(MMM_TT_SUBHEADER_TTC),
            controls = BuildSourceSubmenu(GetSource("TTC"), TTCExtra),
        },
        {
            type     = "submenu",
            name     = GetString(MMM_TT_SUBHEADER_MM),
            controls = BuildSourceSubmenu(GetSource("MM"), MMExtra),
        },
    }

    ----------------------------------------------------------------------
    -- Main options
    ----------------------------------------------------------------------
    local options = {
        {
            type = "header",
            name = GetString(MMM_SUBHEADER_GENERAL),
        },
        -- Account wide settings
        {
            type    = "checkbox",
            name    = GetString(MMM_GLOBAL),
            warning = GetString(MMM_WARNING),
            getFunc = function() return MMM.CharSavedVars.useGlobalSettings end,
            setFunc = function(state)
                if MMM.CharSavedVars.useGlobalSettings == state then return end
                MMM.CharSavedVars.useGlobalSettings = state
                zo_callLater(function() ReloadUI() end, 100)
            end,
            default = defaults.useGlobalSettings,
            width   = "full",
        },

        ----------------------------------------------------------------------
        -- Submenus
        ----------------------------------------------------------------------
        {
            type     = "submenu",
            name     = GetString(MMM_SUBHEADER_CALCULATOR),
            controls = CalculatorSubmenu,
        },
        {
            type     = "submenu",
            name     = GetString(MMM_SUBHEADER_GUILD_SALES),
            controls = GuildSalesSubmenu,
        },
        {
            type     = "submenu",
            name     = GetString(MMM_SUBHEADER_TRADER_TOOLTIP),
            controls = TraderTooltipSubmenu,
        },
    }

    LAM:RegisterOptionControls(panelName, options)
end
