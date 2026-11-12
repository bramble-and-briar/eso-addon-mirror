-- kela saved variables
kpuiSVSettingsDefault = {}
kpuiSVSettingsSaved = {}
kpuiSVSettingsCurrent = {}
KELA_SAVE_CURRENT 	= 1
KELA_RESTORE_SAVED 	= 2
KELA_LOAD_DEFAULT 	= 3
KELA_SETTINGS_DIRTY = 1
KELA_SETTINGS_DIRTY_DEFAULT = 2


-- Setting codes.
-- Every KelaPadUI setting ID is private to SETTING_TYPE_KELA and stored in
-- kpuiSavedVariables.settingsAccountWide; the ZOS GetSetting/SetSetting API is
-- never called with these numbers. Block allocation (see docs/SETTINGS.md):
--   7000       SETTING_TYPE_KELA (system id, not a setting)
--   7001-7299  reserved buffer; do not allocate
--   7300-7399  core panels
--   7400-7499  feature toggles
--   7500-7599  trading
--   7600-7699  next module family
--   7700-7999  reserve
SETTING_TYPE_KELA = 7000

-- SETS
KELA_SETTING_PANEL_SETS 						= 7300 
KELA_SETTING_PANEL_SETS_ENABLED 				= 7301
-- TRAIT RESEARCH
KELA_SETTING_PANEL_TRAIT_RESEARCH 				= 7302
KELA_SETTING_PANEL_TRAIT_RESEARCH_ENABLED 		= 7303
-- FEATURES
KELA_SETTING_PANEL_FEATURES 					= 7400
KELA_SETTING_PANEL_FEATURES_COMPANION 			= 7401
KELA_SETTING_PANEL_FEATURES_DUNGEON_FINDER 		= 7402
KELA_SETTING_PANEL_FEATURES_CHAT_TOOLS 			= 7403
KELA_SETTING_PANEL_FEATURES_MAP_RALLY 			= 7404
KELA_SETTING_PANEL_FEATURES_ANTIQUITY_LEADS 	= 7406
KELA_SETTING_PANEL_FEATURES_MAIN_MENU_SHORTCUTS = 7408
KELA_SETTING_PANEL_FEATURES_MAIN_MENU_DASHBOARD = 7409
KELA_SETTING_PANEL_FEATURES_PA_JUNK = 7410
KELA_SETTING_PANEL_FEATURES_PS5_BUTTONS = 7411
KELA_SETTING_PANEL_FEATURES_GAMEPAD_FILTERS = 7412
KELA_SETTING_PANEL_FEATURES_BASE_GAME_FIXES = 7413
-- TRADING
KELA_SETTING_PANEL_TRADE 						= 7500 
KELA_SETTING_PANEL_TRADE_ENABLED 				= 7501
KELA_SETTING_PANEL_TRADE_ATT_PERIOD 			= 7502
KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE	= 7504
KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK			= 7505
KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE			= 7506
KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING		= 7507
KELA_SETTING_PANEL_TRADE_TOOLTIP_GUILDSTAT		= 7508
KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO		= 7509
KELA_SETTING_PANEL_TRADE_TOOLTIP_LISTINGS		= 7510
KELA_SETTING_PANEL_TRADE_TOOLTIP_QUALITY		= 7511
KELA_SETTING_PANEL_TRADE_TOOLTIP_PRODUCTION		= 7512
KELA_SETTING_PANEL_TRADE_TOOLTIP_COMPONENTS		= 7513

-- IDs that appeared in a public release must never be reused. The audit
-- rejects any live setting ID listed here.
KELA_RETIRED_SETTING_IDS = {}

-- settings table for the auto-list
KELA_SETTINGS_DATA =
{
	-- FEATURES
    [KELA_SETTING_PANEL_FEATURES] =
    {
        {
            panel = KELA_SETTING_PANEL_FEATURES,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_FEATURES_COMPANION,
        },
        {
            panel = KELA_SETTING_PANEL_FEATURES,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_FEATURES_DUNGEON_FINDER,
        },
        {
            panel = KELA_SETTING_PANEL_FEATURES,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_FEATURES_CHAT_TOOLS,
        },
        {
            panel = KELA_SETTING_PANEL_FEATURES,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_FEATURES_MAP_RALLY,
        },
        {
            panel = KELA_SETTING_PANEL_FEATURES,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_FEATURES_GAMEPAD_FILTERS,
        },
        {
            panel = KELA_SETTING_PANEL_FEATURES,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_FEATURES_ANTIQUITY_LEADS,
        },
        {
            panel = KELA_SETTING_PANEL_FEATURES,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_FEATURES_MAIN_MENU_SHORTCUTS,
        },
        {
            panel = KELA_SETTING_PANEL_FEATURES,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_FEATURES_MAIN_MENU_DASHBOARD,
        },
        {
            panel = KELA_SETTING_PANEL_FEATURES,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_FEATURES_PA_JUNK,
        },
        {
            panel = KELA_SETTING_PANEL_FEATURES,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_FEATURES_PS5_BUTTONS,
        },
        {
            panel = KELA_SETTING_PANEL_FEATURES,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_FEATURES_BASE_GAME_FIXES,
        },
    },
	-- TRAIT RESEARCH
    [KELA_SETTING_PANEL_TRAIT_RESEARCH] =
    {
        {
            panel = KELA_SETTING_PANEL_TRAIT_RESEARCH,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_TRAIT_RESEARCH_ENABLED,
        },
    },
	-- SETS
    [KELA_SETTING_PANEL_SETS] =
    {
        {
            panel = KELA_SETTING_PANEL_SETS,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_SETS_ENABLED,
        },
    },
	-- TRADING
    [KELA_SETTING_PANEL_TRADE] =
    {
        {
            panel = KELA_SETTING_PANEL_TRADE,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_TRADE_ENABLED,
        },
        {
            panel = KELA_SETTING_PANEL_TRADE,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_TRADE_ATT_PERIOD,
        },
        {
            panel = KELA_SETTING_PANEL_TRADE,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE,
            header = KELA_SETTING_TRADE_TOOLTIP_HEADER,
        },
        {
            panel = KELA_SETTING_PANEL_TRADE,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK,
        },
        {
            panel = KELA_SETTING_PANEL_TRADE,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE,
        },		
        {
            panel = KELA_SETTING_PANEL_TRADE,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING,
        },
        {
            panel = KELA_SETTING_PANEL_TRADE,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_GUILDSTAT,
            header = KELA_SETTING_TRADE_TOOLTIP_GUILDSTAT_HEADER,
        },
        {
            panel = KELA_SETTING_PANEL_TRADE,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO,
        },
        {
            panel = KELA_SETTING_PANEL_TRADE,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_LISTINGS,
        },
        {
            panel = KELA_SETTING_PANEL_TRADE,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_QUALITY,
        },
        {
            panel = KELA_SETTING_PANEL_TRADE,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_PRODUCTION,
        },
        {
            panel = KELA_SETTING_PANEL_TRADE,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_COMPONENTS,
        },
		
    },

}


-- control data table for the auto-list
kela_SettingsData = 
{
    [KELA_SETTING_PANEL_TRAIT_RESEARCH] =
    {
		[SETTING_TYPE_KELA] =
		{
			[KELA_SETTING_PANEL_TRAIT_RESEARCH_ENABLED] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_TRAIT_RESEARCH,
				settingId = KELA_SETTING_PANEL_TRAIT_RESEARCH_ENABLED,
				text = KELA_SETTINGS_TRAIT_RESEARCH_ENABLED,
				tooltipText = KELA_SETTINGS_TRAIT_RESEARCH_ENABLED_TOOLTIP,
				requiresReload = true,
			},
		},
	},
    [KELA_SETTING_PANEL_SETS] =
    {
		[SETTING_TYPE_KELA] =
		{
			[KELA_SETTING_PANEL_SETS_ENABLED] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_SETS,
				settingId = KELA_SETTING_PANEL_SETS_ENABLED,
				text = KELA_SETTINGS_SETS_ENABLED,
				tooltipText = KELA_SETTINGS_SETS_ENABLED_TOOLTIP,
			},
		},
	},
    [KELA_SETTING_PANEL_FEATURES] =
    {
		[SETTING_TYPE_KELA] =
		{
			[KELA_SETTING_PANEL_FEATURES_COMPANION] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_FEATURES,
				settingId = KELA_SETTING_PANEL_FEATURES_COMPANION,
				text = KELA_SETTINGS_FEATURES_COMPANION,
				tooltipText = KELA_SETTINGS_FEATURES_COMPANION_TOOLTIP,
				requiresReload = true,
			},
			[KELA_SETTING_PANEL_FEATURES_DUNGEON_FINDER] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_FEATURES,
				settingId = KELA_SETTING_PANEL_FEATURES_DUNGEON_FINDER,
				text = KELA_SETTINGS_FEATURES_DUNGEON_FINDER,
				tooltipText = KELA_SETTINGS_FEATURES_DUNGEON_FINDER_TOOLTIP,
				requiresReload = true,
			},
			[KELA_SETTING_PANEL_FEATURES_CHAT_TOOLS] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_FEATURES,
				settingId = KELA_SETTING_PANEL_FEATURES_CHAT_TOOLS,
				text = KELA_SETTINGS_FEATURES_CHAT_TOOLS,
				tooltipText = KELA_SETTINGS_FEATURES_CHAT_TOOLS_TOOLTIP,
				requiresReload = true,
			},
			[KELA_SETTING_PANEL_FEATURES_MAP_RALLY] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_FEATURES,
				settingId = KELA_SETTING_PANEL_FEATURES_MAP_RALLY,
				text = KELA_SETTINGS_FEATURES_MAP_RALLY,
				tooltipText = KELA_SETTINGS_FEATURES_MAP_RALLY_TOOLTIP,
				requiresReload = true,
			},
			[KELA_SETTING_PANEL_FEATURES_ANTIQUITY_LEADS] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_FEATURES,
				settingId = KELA_SETTING_PANEL_FEATURES_ANTIQUITY_LEADS,
				text = KELA_SETTINGS_FEATURES_ANTIQUITY_LEADS,
				tooltipText = KELA_SETTINGS_FEATURES_ANTIQUITY_LEADS_TOOLTIP,
				requiresReload = true,
			},
			[KELA_SETTING_PANEL_FEATURES_GAMEPAD_FILTERS] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_FEATURES,
				settingId = KELA_SETTING_PANEL_FEATURES_GAMEPAD_FILTERS,
				text = KELA_SETTINGS_FEATURES_GAMEPAD_FILTERS,
				tooltipText = KELA_SETTINGS_FEATURES_GAMEPAD_FILTERS_TOOLTIP,
				requiresReload = true,
			},
			[KELA_SETTING_PANEL_FEATURES_MAIN_MENU_SHORTCUTS] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_FEATURES,
				settingId = KELA_SETTING_PANEL_FEATURES_MAIN_MENU_SHORTCUTS,
				text = KELA_SETTINGS_FEATURES_MAIN_MENU_SHORTCUTS,
				tooltipText = KELA_SETTINGS_FEATURES_MAIN_MENU_SHORTCUTS_TOOLTIP,
				requiresReload = true,
			},
			[KELA_SETTING_PANEL_FEATURES_MAIN_MENU_DASHBOARD] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_FEATURES,
				settingId = KELA_SETTING_PANEL_FEATURES_MAIN_MENU_DASHBOARD,
				text = KELA_SETTINGS_FEATURES_MAIN_MENU_DASHBOARD,
				tooltipText = KELA_SETTINGS_FEATURES_MAIN_MENU_DASHBOARD_TOOLTIP,
				requiresReload = true,
			},
			[KELA_SETTING_PANEL_FEATURES_PA_JUNK] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_FEATURES,
				settingId = KELA_SETTING_PANEL_FEATURES_PA_JUNK,
				text = KELA_SETTINGS_FEATURES_PA_JUNK,
				tooltipText = KELA_SETTINGS_FEATURES_PA_JUNK_TOOLTIP,
				requiresReload = true,
			},
			[KELA_SETTING_PANEL_FEATURES_PS5_BUTTONS] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_FEATURES,
				settingId = KELA_SETTING_PANEL_FEATURES_PS5_BUTTONS,
				text = KELA_SETTINGS_FEATURES_PS5_BUTTONS,
				tooltipText = KELA_SETTINGS_FEATURES_PS5_BUTTONS_TOOLTIP,
				events =
				{
					[true] = "KELA_PS5_BUTTON_MAP_CHANGED",
					[false] = "KELA_PS5_BUTTON_MAP_CHANGED",
				},
			},
			[KELA_SETTING_PANEL_FEATURES_BASE_GAME_FIXES] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_FEATURES,
				settingId = KELA_SETTING_PANEL_FEATURES_BASE_GAME_FIXES,
				text = KELA_SETTINGS_FEATURES_BASE_GAME_FIXES,
				tooltipText = KELA_SETTINGS_FEATURES_BASE_GAME_FIXES_TOOLTIP,
				requiresReload = true,
			},
		},
	},
    [KELA_SETTING_PANEL_TRADE] =
    {
		[SETTING_TYPE_KELA] =
		{
			[KELA_SETTING_PANEL_TRADE_ENABLED] =
			{
				controlType = OPTIONS_CHECKBOX,
				enabled = function()
					return TamrielTradeCentre ~= nil or ArkadiusTradeTools ~= nil
                end,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_TRADE,
				settingId = KELA_SETTING_PANEL_TRADE_ENABLED,
				text = KELA_SETTINGS_TRADE_ENABLED,
				tooltipText = KELA_SETTINGS_TRADE_ENABLED_TOOLTIP,
				gamepadHasEnabledDependencies = true,			
			},
			[KELA_SETTING_PANEL_TRADE_ATT_PERIOD] =
			{
				controlType = OPTIONS_SLIDER,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_TRADE,
				settingId = KELA_SETTING_PANEL_TRADE_ATT_PERIOD,
				text = KELA_SETTINGS_TRADE_ATTGRAPH_PERIOD,
				tooltipText = KELA_SETTINGS_TRADE_ATTGRAPH_PERIOD_TOOLTIP,
				valueFormat = "%d",
				minValue = 1,
				maxValue = 30,
				gamepadValueStep = 1,
				showValue = true,
				visible  = function()
                    return KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ENABLED) and ArkadiusTradeTools ~= nil
                end,
			},
			[KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_TRADE,
				settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE,
				text = KELA_SETTING_TRADE_TOOLTIP_TRADINGHOUSE,
				tooltipText = KELA_SETTING_TRADE_TOOLTIP_TRADINGHOUSE_TOOLTIP,
				visible  = function()
                    return KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ENABLED)
                end,
				gamepadHasEnabledDependencies = true,
			},
			[KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_TRADE,
				settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK,
				text = KELA_SETTING_TRADE_TOOLTIP_BANK,
				tooltipText = KELA_SETTING_TRADE_TOOLTIP_BANK_TOOLTIP,
				visible  = function()
                    return KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ENABLED)
                end,
				gamepadHasEnabledDependencies = true,
			},
			[KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_TRADE,
				settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE,
				text = KELA_SETTING_TRADE_TOOLTIP_STORE,
				tooltipText = KELA_SETTING_TRADE_TOOLTIP_STORE_TOOLTIP,
				visible  = function()
                    return KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ENABLED)
                end,
				gamepadHasEnabledDependencies = true,
			},
			[KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_TRADE,
				settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING,
				text = KELA_SETTING_TRADE_TOOLTIP_CRAFTING,
				tooltipText = KELA_SETTING_TRADE_TOOLTIP_CRAFTING_TOOLTIP,
				visible  = function()
                    return KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ENABLED)
                end,
				gamepadHasEnabledDependencies = true,
			},
			[KELA_SETTING_PANEL_TRADE_TOOLTIP_GUILDSTAT] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_TRADE,
				settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_GUILDSTAT,
				text = KELA_SETTING_TRADE_TOOLTIP_GUILDSTAT,
				tooltipText = KELA_SETTING_TRADE_TOOLTIP_GUILDSTAT_TOOLTIP,
				visible  = function()
                    return ArkadiusTradeTools ~= nil and (KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE)) and KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ENABLED)
                end,
			},
			[KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_TRADE,
				settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO,
				text = KELA_SETTING_TRADE_TOOLTIP_ATTINFO,
				tooltipText = KELA_SETTING_TRADE_TOOLTIP_ATTINFO_TOOLTIP,
				visible  = function()
                    return ArkadiusTradeTools ~= nil and (KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE)) and KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ENABLED)
                end,
			},
			[KELA_SETTING_PANEL_TRADE_TOOLTIP_LISTINGS] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_TRADE,
				settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_LISTINGS,
				text = KELA_SETTING_TRADE_TOOLTIP_LISTINGS,
				tooltipText = KELA_SETTING_TRADE_TOOLTIP_LISTINGS_TOOLTIP,
				visible  = function()
                    return (KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE)) and KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ENABLED)
                end,
			},
			[KELA_SETTING_PANEL_TRADE_TOOLTIP_QUALITY] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_TRADE,
				settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_QUALITY,
				text = KELA_SETTING_TRADE_TOOLTIP_QUALITY,
				tooltipText = KELA_SETTING_TRADE_TOOLTIP_QUALITY_TOOLTIP,
				visible  = function()
                    return (KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE)) and KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ENABLED)
                end,
			},
			[KELA_SETTING_PANEL_TRADE_TOOLTIP_PRODUCTION] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_TRADE,
				settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_PRODUCTION,
				text = KELA_SETTING_TRADE_TOOLTIP_PRODUCTION,
				tooltipText = KELA_SETTING_TRADE_TOOLTIP_PRODUCTION_TOOLTIP,
				visible  = function()
                    return (KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE)) and KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ENABLED)
                end,
			},
			[KELA_SETTING_PANEL_TRADE_TOOLTIP_COMPONENTS] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_TRADE,
				settingId = KELA_SETTING_PANEL_TRADE_TOOLTIP_COMPONENTS,
				text = KELA_SETTING_TRADE_TOOLTIP_COMPONENTS,
				tooltipText = KELA_SETTING_TRADE_TOOLTIP_COMPONENTS_TOOLTIP,
				visible  = function()
                    return ArkadiusTradeTools ~= nil and (KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING) or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE)) and KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ENABLED)
                end,
			},

		},
	},

}

KELA_SETTINGS_DEFAULTS =
{
	[SETTING_TYPE_KELA] =
	{
		-- SETS
		[KELA_SETTING_PANEL_SETS_ENABLED] 				= "true",
		-- TRAIT RESEARCH
		[KELA_SETTING_PANEL_TRAIT_RESEARCH_ENABLED] 	= "true",
		-- FEATURES
		[KELA_SETTING_PANEL_FEATURES_COMPANION] 		= "true",
		[KELA_SETTING_PANEL_FEATURES_DUNGEON_FINDER] 	= "true",
		[KELA_SETTING_PANEL_FEATURES_CHAT_TOOLS] 		= "true",
		[KELA_SETTING_PANEL_FEATURES_MAP_RALLY] 		= "true",
		[KELA_SETTING_PANEL_FEATURES_GAMEPAD_FILTERS] = "true",
		[KELA_SETTING_PANEL_FEATURES_ANTIQUITY_LEADS] 	= "true",
		[KELA_SETTING_PANEL_FEATURES_MAIN_MENU_SHORTCUTS] = "true",
		[KELA_SETTING_PANEL_FEATURES_MAIN_MENU_DASHBOARD] = "true",
		[KELA_SETTING_PANEL_FEATURES_PA_JUNK] 			= "true",
		[KELA_SETTING_PANEL_FEATURES_PS5_BUTTONS] 		= "false",
		[KELA_SETTING_PANEL_FEATURES_BASE_GAME_FIXES] 	= "true",
		-- TRADING
		[KELA_SETTING_PANEL_TRADE_ENABLED] 				= "true",
		[KELA_SETTING_PANEL_TRADE_ATT_PERIOD] 			= "15",
		[KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE]	= "true",
		[KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK] 		= "true",
		[KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE] 		= "true",
		[KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING] 	= "true",
		-- trading modules
		[KELA_SETTING_PANEL_TRADE_TOOLTIP_GUILDSTAT] 	= "true",
		[KELA_SETTING_PANEL_TRADE_TOOLTIP_ATTINFO] 		= "true",
		[KELA_SETTING_PANEL_TRADE_TOOLTIP_LISTINGS] 	= "true",
		[KELA_SETTING_PANEL_TRADE_TOOLTIP_QUALITY]		= "true",
		[KELA_SETTING_PANEL_TRADE_TOOLTIP_PRODUCTION] 	= "true",
		[KELA_SETTING_PANEL_TRADE_TOOLTIP_COMPONENTS] 	= "true",
	}
}

local function ApplyMissingSettingDefaults(settings)
	if type(settings) ~= "table" then
		return
	end

	for system, defaults in pairs(KELA_SETTINGS_DEFAULTS) do
		local systemSettings = settings[system]
		if type(systemSettings) ~= "table" then
			systemSettings = {}
			settings[system] = systemSettings
		end
		for settingId, value in pairs(defaults) do
			if systemSettings[settingId] == nil then
				systemSettings[settingId] = value
			end
		end
	end
end

-- One-time removal of settings keys used only in pre-release builds. These IDs
-- never shipped, so no migration is needed. The saved-variable marker keeps the
-- purge from running again; the audit rejects any live constant that still uses
-- one of these numbers, so remove it from this list before reusing the ID.
local KELA_LEGACY_SETTING_IDS = { 7405, 7503, 7100, 7101, 7102, 7103, 7104 }

local function PurgeLegacySettingIds(settings)
	if type(settings) ~= "table" then
		return
	end
	local systemSettings = settings[SETTING_TYPE_KELA]
	if type(systemSettings) ~= "table" then
		return
	end
	for _, settingId in ipairs(KELA_LEGACY_SETTING_IDS) do
		systemSettings[settingId] = nil
	end
end

-- initialize setting variables
function KelaInitializeSettings()
	local sv = ZO_SavedVars:NewAccountWide('kpuiSavedVariables', 0.52, nil, KELA_SETTINGS_DEFAULTS)
	if not kpuiSavedVariables["settingsAccountWide"] or next(kpuiSavedVariables["settingsAccountWide"]) == nil or kpuiSavedVariables["settingsAccountWide"]["version"] ~= kpuiSavedVariables["Default"][GetDisplayName()]["$AccountWide"]["version"] then
        kpuiSavedVariables["settingsAccountWide"] = nil
        kpuiSavedVariables["settingsAccountWide"] = kpuiSavedVariables["Default"][GetDisplayName()]["$AccountWide"]
    end
	
	kpuiSVSettingsDefault 	= kpuiSavedVariables["Default"][GetDisplayName()]["$AccountWide"]
	kpuiSVSettingsSaved 	= kpuiSavedVariables["settingsAccountWide"]
	kpuiSVSettingsCurrent 	= KelaGetTableCopy(kpuiSavedVariables["settingsAccountWide"])

	if not kpuiSavedVariables.settingsLegacyPurge then
		PurgeLegacySettingIds(kpuiSVSettingsDefault)
		PurgeLegacySettingIds(kpuiSVSettingsSaved)
		PurgeLegacySettingIds(kpuiSVSettingsCurrent)
		kpuiSavedVariables.settingsLegacyPurge = 1
	end

	-- Add newly introduced settings for existing characters without resetting user choices.
	ApplyMissingSettingDefaults(kpuiSVSettingsDefault)
	ApplyMissingSettingDefaults(kpuiSVSettingsSaved)
	ApplyMissingSettingDefaults(kpuiSVSettingsCurrent)
end

-- settings helper functions
local function IsSettingsDirty (need)
	if need == KELA_SETTINGS_DIRTY_DEFAULT then
		return not KelaDeepCompare(kpuiSVSettingsDefault, kpuiSVSettingsSaved, true)
	elseif need == KELA_SETTINGS_DIRTY then 
		return not KelaDeepCompare(kpuiSVSettingsCurrent, kpuiSVSettingsSaved, true)			
	end
end
local function SaveSettings (whatDo)
	if IsSettingsDirty(KELA_SETTINGS_DIRTY) or IsSettingsDirty(KELA_SETTINGS_DIRTY_DEFAULT) then 
		if whatDo == KELA_SAVE_CURRENT then
			kpuiSavedVariables["settingsAccountWide"] = kpuiSVSettingsCurrent
		end
		if whatDo == KELA_RESTORE_SAVED then
			kpuiSavedVariables["settingsAccountWide"] = kpuiSVSettingsSaved
		end
		if whatDo == KELA_LOAD_DEFAULT then
			kpuiSavedVariables["settingsAccountWide"] = kpuiSVSettingsDefault
		end
		kpuiSVSettingsSaved = kpuiSavedVariables["settingsAccountWide"]
		kpuiSVSettingsCurrent = KelaGetTableCopy(kpuiSavedVariables["settingsAccountWide"])
	end
end

-- True when a setting that requires a reload differs from the saved value.
-- Evaluated before the options scene saves, so leaving the options can prompt
-- the player to reload the UI.
local function KelaSettingsNeedReload()
	-- kela_SettingsData is [panel][system][settingId], so every level has to be
	-- walked with pairs. The previous ipairs over the system table (keyed by
	-- SETTING_TYPE_KELA) ran zero iterations, so the prompt never appeared.
	for _, panelData in pairs(kela_SettingsData) do
		for _, systemData in pairs(panelData) do
			for _, data in pairs(systemData) do
				if data.requiresReload then
					local currentSystem = kpuiSVSettingsCurrent[data.system]
					local savedSystem = kpuiSVSettingsSaved[data.system]
					local currentValue = currentSystem and currentSystem[data.settingId]
					local savedValue = savedSystem and savedSystem[data.settingId]
					-- KelaSetSetting stores strings while the defaults table holds
					-- booleans and numbers; compare string forms so reverting a
					-- toggle to its saved value does not prompt.
					if tostring(currentValue) ~= tostring(savedValue) then
						return true
					end
				end
			end
		end
	end
	return false
end

function KelaGetSetting(system, settingId)
	local systemSettings = kpuiSVSettingsCurrent[system]
	return systemSettings and systemSettings[settingId]
end
function KelaGetSetting_Bool(system, settingId)
	local value = KelaGetSetting(system, settingId)
    local isChecked = false
	if type(value) == "boolean" then
        isChecked = value
    elseif type(value) == "string" then
        isChecked = (value == "true") or (value == "t") or (value == "1") or (value == "y")
    elseif type(value) == "number" then
        isChecked = value > 0
    end
	return isChecked
end
function KelaGetSetting_Number(system, settingId)
	local value = KelaGetSetting(system, settingId)
    local checkStateType = type(value) 
	local isValue
	if checkStateType == "boolean" then
    elseif checkStateType == "string" then
        isValue = tonumber(value)
    elseif checkStateType == "number" then
        isValue = value
    end
	return isValue
end

function KelaGetATTAnalysisPeriod()
    local days = KelaGetSetting_Number(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ATT_PERIOD) or 15
    return math.max(1, math.min(30, days))
end

local function GetControlType(control)
    return control.optionsManager:GetControlTypeFromControl(control)
end
function KelaSetSetting(system, settingId, strValue, andSave)
	if type(strValue) ~= "string" then strValue = tostring(strValue) end
	local systemSettings = kpuiSVSettingsCurrent[system]
	if not systemSettings then
		systemSettings = {}
		kpuiSVSettingsCurrent[system] = systemSettings
	end
	systemSettings[settingId] = strValue
	if andSave then SaveSettings (KELA_SAVE_CURRENT) end
	if settingId == KELA_SETTING_PANEL_TRADE_ATT_PERIOD then
		KelaUpdateGuildATTStat()
	end
end
local function KelaGetSettingFromControl(control)
    local data = control.data
    if data.GetSettingOverride then
        return data.GetSettingOverride(control)
    end
    if GetControlType(control) == OPTIONS_CHECKBOX then
        return KelaGetSetting_Bool(data.system, data.settingId)
    end
    if GetControlType(control) == OPTIONS_SLIDER then
        return KelaGetSetting_Number(data.system, data.settingId)
    end
    return KelaGetSetting(data.system, data.settingId)
end
local function KelaSetSettingFromControl(control, value)
    local data = control.data
    if data.SetSettingOverride then
        data.SetSettingOverride(control, value)
    end
    KelaSetSetting(data.system, data.settingId, tostring(value))
end


-- slider functions
local function GetSliderOptionValues(control, value)
    local data = control.data
    local oldValueString = KelaGetSettingFromControl(control)
    local valueFormat = data.valueFormat or "%d"
    local formattedValueString = string.format(valueFormat, value)
    local formattedValue = tonumber(formattedValueString)

    return oldValueString, formattedValueString, formattedValue
end
-- NOTE: Sliders do not support value-based events
local function OptionsSlider_SelectChoice(control, value, eventReason)
    local data = control.data
    local oldValueString, formattedValueString, formattedValue = GetSliderOptionValues(control, value)
    KelaSetSettingFromControl(control, formattedValueString)


	local valueLabelControl = GetControl(control, "Name")
	if data.showValue and valueLabelControl then
		local text = nil
		if type(data.text) == "string" then
			text = data.text
		elseif type(data.text) == "function" then
			text = data.text(control)
		else
			text = GetString(data.text)
		end
		valueLabelControl:SetText(text.." ("..formattedValueString..")")
	end

end
function Kela_Options_SliderOnValueChanged(sliderControl, value, eventReason)
    OptionsSlider_SelectChoice(sliderControl:GetParent(), value, eventReason)
end

-- button-press handlers
local DEFAULT_SLIDER_VALUE_STEP_PERCENT = 6.66
local updateControlFromSettings =
{
    [OPTIONS_DROPDOWN] = function(control)
                                local data = control.data
                                local currentSetting = KelaGetSettingFromControl(control)
                                local currentChoice = tonumber(currentSetting) or currentSetting
                                local isValidNumber = type(currentChoice) == "number"

                                local dropdownControl = GetControl(control, "Dropdown")
                                local dropdown = ZO_ComboBox_ObjectFromContainer(dropdownControl)
                                if data.itemText then
                                    dropdown:SetSelectedItemText(data.itemText[GetValidIndexFromCurrentChoice(data.valid, currentChoice)])
                                elseif data.valueStringPrefix and isValidNumber then
                                    dropdown:SetSelectedItemText(GetString(data.valueStringPrefix, currentChoice))
                                elseif data.valueStrings then
                                    dropdown:SetSelectedItemText(GetValueString(data.valueStrings[GetValidIndexFromCurrentChoice(data.valid, currentChoice)]))
                                else
                                    dropdown:SetSelectedItemText(tostring(currentChoice))
                                end
                                return currentChoice
                            end,
    [OPTIONS_HORIZONTAL_SCROLL_LIST] = function(control)
                            local data = control.data
                            local currentSetting = KelaGetSettingFromControl(control)
                            local currentChoice = tonumber(currentSetting) or currentSetting
                            local index = 0
                            for i = 1, #data.valid do 
                                if currentChoice == data.valid[i] then
                                    index = i
                                    break
                                end
                            end
                            local ALLOW_EVEN_IF_DISABLED = true
                            local NO_ANIMATION = true
                            control.horizontalListObject:SetSelectedDataIndex(index, ALLOW_EVEN_IF_DISABLED, NO_ANIMATION)
                            control.horizontalListObject:SetOnSelectedDataChangedCallback(OptionsScrollListSelectionChanged)
                            return currentChoice
                        end,
    [OPTIONS_CHECKBOX] = function(control)
                                local currentChoice = KelaGetSettingFromControl(control)
                                local checkBoxControl = GetControl(control, "Checkbox")
                                ZO_CheckButton_SetCheckState(checkBoxControl, currentChoice)
                                local enabled = control.data.enabled
                                if type(enabled) == "function" then
                                    enabled = control.data.enabled()
                                end
								if enabled == false then
									checkBoxControl:SetText(GetString(SI_CHECK_BUTTON_DISABLED))
									ZO_CheckButton_Disable(checkBoxControl)
								else
									checkBoxControl.checkedText = GetString(SI_CHECK_BUTTON_ON)
									checkBoxControl.uncheckedText = GetString(SI_CHECK_BUTTON_OFF)
									ZO_CheckButton_Enable(checkBoxControl)
								end
								local onLabel = control:GetNamedChild("On")
								local offLabel = control:GetNamedChild("Off")
								onLabel:SetColor((currentChoice and ZO_SELECTED_TEXT or ZO_DISABLED_TEXT):UnpackRGBA())
								offLabel:SetColor((currentChoice and ZO_DISABLED_TEXT or ZO_SELECTED_TEXT):UnpackRGBA())
								local selected = checkBoxControl.selected
								checkBoxControl:SetHidden(selected)
								onLabel:SetHidden(not selected)
								offLabel:SetHidden(not selected)
                                return currentChoice
                            end,
    [OPTIONS_SLIDER] =   function(control)
                                local data = control.data
                                local currentChoice = tonumber(KelaGetSettingFromControl(control))
                                local slider = GetControl(control, "Slider")
                                --We remove the OnValueChanged handler while we set up the slider because
                                --SetMinMax, SetValue, and SetValueStep can all potentially fire the OnValueChanged event
                                --which fires a callback that will actually set whatever setting the slider is attached too.
                                slider:SetHandler("OnValueChanged", nil)
                                slider:SetMinMax(data.minValue, data.maxValue)

								local stepValue
								if data.gamepadValueStep ~= nil then
									stepValue = data.gamepadValueStep
								else	
									stepValue = (data.maxValue - data.minValue) * ((data.gamepadValueStepPercent or DEFAULT_SLIDER_VALUE_STEP_PERCENT) / 100)
                                end
								slider:SetValueStep(stepValue)

                                slider:SetValue(currentChoice)
                                slider:SetHandler("OnValueChanged", Kela_Options_SliderOnValueChanged)
								
                                local valueLabelControl = GetControl(control, "Name")
                                if data.showValue and valueLabelControl then
									local text = nil
									if type(data.text) == "string" then
										text = data.text
									elseif type(data.text) == "function" then
										text = data.text(control)
									else
										text = GetString(data.text)
									end
									valueLabelControl:SetText(text.." ("..currentChoice..")")
                                end
								
                                return currentChoice
                            end,
    [OPTIONS_COLOR] =       function(control)
                                local data = control.data
                                local currentChoice = KelaGetSettingFromControl(control)
                                local color = ZO_ColorDef.FromARGBHexadecimal(currentChoice)
                                if color then
                                    control:GetNamedChild("Color"):SetColor(color:UnpackRGB())
                                end
                            end,
    [OPTIONS_CHAT_COLOR] =  function(control)
                                local data = control.data
                                local currentRed, currentGreen, currentBlue = GetChatCategoryColor(data.chatChannelCategory)
                                control:GetNamedChild("Color"):SetColor(currentRed, currentGreen, currentBlue)
                            end,
}


--MODULE INITIALIZATION
Kela_GamepadOptions = ZO_Object.MultiSubclass(ZO_SharedOptions, ZO_Gamepad_ParametricList_Screen)

function Kela_GamepadOptions:New(...)
    local options = ZO_Object.New(self)
    options:Initialize(...)
    return options
end
function Kela_GamepadOptions:Initialize(control)	
	ZO_SharedOptions.Initialize(self)
    local ACTIVATE_ON_SHOW = true
    ZO_Gamepad_ParametricList_Screen.Initialize(self, control, ZO_GAMEPAD_HEADER_TABBAR_DONT_CREATE, ACTIVATE_ON_SHOW)
    KELA_OPTIONS_FRAGMENT = ZO_SimpleSceneFragment:New(control)
    self.isGamepadOptions = true
	self:InitializeScenes()
	self:InitializeSaveReloadDialog()	
end

function Kela_GamepadOptions:InitializeScenes()
    KELA_OPTIONS_ROOT_SCENE = ZO_Scene:New("kela_options_root", SCENE_MANAGER)
    self:SetScene(KELA_OPTIONS_ROOT_SCENE)
    KELA_OPTIONS_ROOT_SCENE:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            RefreshSettings()
            self:RefreshOptionsList()
            self:RefreshHeader()
            self:SetCurrentList(self.optionsList)
            KEYBIND_STRIP:AddKeybindButtonGroup(self.optionsKeybindDescriptor)
        elseif newState == SCENE_HIDDEN then
            self:DeactivateSelectedControl()
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.optionsKeybindDescriptor)
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.primaryActionDescriptor)
            self:SaveCachedSettings()
            ZO_SavePlayerConsoleProfile()
            SetCameraOptionsPreviewModeEnabled(false, CAMERA_OPTIONS_PREVIEW_NONE)
            local reloadRequired = KelaSettingsNeedReload()
            SaveSettings(KELA_SAVE_CURRENT)
            if reloadRequired then
                -- Deferred so the prompt is never shown inside the scene
                -- transition callstack.
                zo_callLater(function() ZO_Dialogs_ShowPlatformDialog("KELA_OPTIONS_RELOAD_REQUIRED") end, 50)
            end
        end
    end)
end

function Kela_GamepadOptions:PerformUpdate()
    -- Include update functionality here if the screen uses self.dirty to track needing to update
    self.dirty = false
end

function Kela_GamepadOptions:DeactivateSelectedControl()
    local selectedControl = self.optionsList:GetSelectedControl()
    if selectedControl then
        if selectedControl.slider then
            selectedControl.slider:Deactivate()
        elseif selectedControl.horizontalListObject then
            selectedControl.horizontalListObject:Deactivate()
        end
    end
    self.isPrimaryActionActive = false
end

function Kela_GamepadOptions:OnDeferredInitialize()
    self:InitializeHeader()
    self:InitializeOptionsLists()
    self:InitializeKeybindStrip()
end

function Kela_GamepadOptions:InitializeHeader()


    ZO_GamepadGenericHeader_SetDataLayout(self.header, ZO_GAMEPAD_HEADER_LAYOUTS.DATA_PAIRS_TOGETHER)
    self:RefreshHeader()
end

function Kela_GamepadOptions:RefreshHeader()
    local headerData =
    {
        titleText = GetString(SI_GAMEPAD_OPTIONS_MENU),
    }
    ZO_GamepadGenericHeader_RefreshData(self.header, headerData)
end

do

    function Kela_GamepadOptions:InitializeKeybindStrip()
        
		self.keybindStripDescriptor =
        {
			{
				alignment = KEYBIND_STRIP_ALIGN_LEFT,
				name = GetString(SI_DIALOG_DISMISS),
				keybind = "UI_SHORTCUT_SECONDARY",
				visible = function()
						return IsSettingsDirty(KELA_SETTINGS_DIRTY)
					end,
				callback = function()
						ZO_Dialogs_ShowPlatformDialog("KELA_OPTIONS_RESET_TO_SAVED")
					end,
			},
			{
				alignment = KEYBIND_STRIP_ALIGN_RIGHT,
				name = GetString(SI_OPTIONS_DEFAULTS),
				keybind = "UI_SHORTCUT_QUATERNARY",
				visible = function()
						return IsSettingsDirty(KELA_SETTINGS_DIRTY_DEFAULT)
					end,
				callback = function()
						ZO_Dialogs_ShowPlatformDialog("KELA_OPTIONS_RESET_TO_DEFAULTS")
					end,
			},			
        }
        ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, function() SCENE_MANAGER:HideCurrentScene() end)
    
        self.optionsKeybindDescriptor =
        {
        }
        ZO_Gamepad_AddListTriggerKeybindDescriptors(self.optionsKeybindDescriptor, self.optionsList)

        self.primaryActionDescriptor = 
        {
            {
                alignment = KEYBIND_STRIP_ALIGN_LEFT,
                name = function()
                    local control = self.optionsList:GetSelectedControl()
                    if control and self:GetControlTypeFromControl(control) == OPTIONS_CHECKBOX then
                        return GetString(SI_GAMEPAD_TOGGLE_OPTION)
                    else
                        return GetString(SI_GAMEPAD_SELECT_OPTION)
                    end
                end,
                keybind = "UI_SHORTCUT_PRIMARY",
                order = -500,
                callback = function()
                    self:Select()
                end,
            },
        }
    end
end


local function ReleaseControl(control)
    control.state = nil
end

local function ReleaseSlider(control)
    control.slider:Deactivate()
    ReleaseControl(control)
end

local function ReleaseHorizontalList(control)
    control.horizontalListObject:Deactivate()
    ReleaseControl(control)
end

local KELA_OPTIONS_HEADER_SELECTED_PADDING = -20

function Kela_GamepadOptions:SetupList(list)
    list:AddDataTemplate("ZO_GamepadMenuEntryTemplate", ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
    list:AddDataTemplateWithHeader("ZO_GamepadMenuEntryTemplate", ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadMenuEntryHeaderTemplate")
end

function Kela_GamepadOptions:SetupOptionsList(list)
    local function OptionsSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
        control.data = data
        self:InitializeControl(control, selected)
    end

    list:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING, KELA_OPTIONS_HEADER_SELECTED_PADDING)

    list:AddDataTemplate("ZO_GamepadOptionsSliderRow", OptionsSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)    
    list:AddDataTemplateWithHeader("ZO_GamepadOptionsSliderRow", OptionsSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadOptionsHeaderTemplate")
    list:SetDataTemplateReleaseFunction("ZO_GamepadOptionsSliderRow", ReleaseSlider)
    list:SetDataTemplateWithHeaderReleaseFunction("ZO_GamepadOptionsSliderRow", ReleaseSlider)

    list:AddDataTemplate("ZO_GamepadOptionsCheckboxRow", OptionsSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)    
    list:AddDataTemplateWithHeader("ZO_GamepadOptionsCheckboxRow", OptionsSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadOptionsHeaderTemplate")
    list:SetDataTemplateReleaseFunction("ZO_GamepadOptionsCheckboxRow", ReleaseControl)
    list:SetDataTemplateWithHeaderReleaseFunction("ZO_GamepadOptionsCheckboxRow", ReleaseControl)

    list:AddDataTemplate("ZO_GamepadOptionsHorizontalListRow", OptionsSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)    
    list:AddDataTemplateWithHeader("ZO_GamepadOptionsHorizontalListRow", OptionsSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadOptionsHeaderTemplate")
    list:SetDataTemplateReleaseFunction("ZO_GamepadOptionsHorizontalListRow", ReleaseHorizontalList)
    list:SetDataTemplateWithHeaderReleaseFunction("ZO_GamepadOptionsHorizontalListRow", ReleaseHorizontalList)

    list:AddDataTemplate("ZO_GamepadOptionsLabelRow", OptionsSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)    
    list:AddDataTemplateWithHeader("ZO_GamepadOptionsLabelRow", OptionsSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadOptionsHeaderTemplate")
    list:SetDataTemplateReleaseFunction("ZO_GamepadOptionsLabelRow", ReleaseControl)
    list:SetDataTemplateWithHeaderReleaseFunction("ZO_GamepadOptionsLabelRow", ReleaseControl)

    list:AddDataTemplate("ZO_GamepadOptionsColorRow", OptionsSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
    list:AddDataTemplateWithHeader("ZO_GamepadOptionsColorRow", OptionsSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadOptionsHeaderTemplate")
    list:SetDataTemplateReleaseFunction("ZO_GamepadOptionsColorRow", ReleaseControl)
    list:SetDataTemplateWithHeaderReleaseFunction("ZO_GamepadOptionsColorRow", ReleaseControl)
end

function Kela_GamepadOptions:InitializeOptionsLists()
    self.optionsList = self:GetMainList()
    self:SetupOptionsList(self.optionsList)
end

do
    local CONTROL_TYPES_WITH_PRIMARY_ACTION =
    {
        [OPTIONS_CHECKBOX] = true,
        [OPTIONS_INVOKE_CALLBACK] = true,
        [OPTIONS_COLOR] = true,
        [OPTIONS_CHAT_COLOR] = true,
    }

    local function FormatSettingDefault(data)
        local defaultsForSystem = KELA_SETTINGS_DEFAULTS[data.system]
        local defaultValue = defaultsForSystem and defaultsForSystem[data.settingId]
        if defaultValue == nil then
            return nil
        end

        local defaultText
        if defaultValue == true or defaultValue == "true" then
            defaultText = GetString(KELA_SETTING_INFO_ON)
        elseif defaultValue == false or defaultValue == "false" then
            defaultText = GetString(KELA_SETTING_INFO_OFF)
        elseif data.valueFormat then
            defaultText = string.format(data.valueFormat, tonumber(defaultValue) or 0)
        else
            defaultText = tostring(defaultValue)
        end

        return zo_strformat(GetString(KELA_SETTING_INFO_DEFAULT), defaultText)
    end

    local function GetSettingInfoText(data)
        local lines = {}

        local defaultText = FormatSettingDefault(data)
        if defaultText then
            lines[#lines + 1] = defaultText
        end

        if data.settingId then
            lines[#lines + 1] = data.requiresReload and GetString(KELA_SETTING_INFO_RELOAD) or GetString(KELA_SETTING_INFO_IMMEDIATE)
        end

        if data.requiresText then
            local requiresText = data.requiresText
            if type(requiresText) == "number" then
                requiresText = GetString(requiresText)
            end
            lines[#lines + 1] = requiresText
        end

        if #lines == 0 then
            return nil
        end

        return table.concat(lines, "\n")
    end

    function Kela_GamepadOptions:OnSelectionChanged(list)
        local control = list:GetSelectedControl()
        if control == nil or control.data == nil then
        
		else
			local controlType = self:GetControlTypeFromControl(control)
			local enabled = control.data.enabled
			if CONTROL_TYPES_WITH_PRIMARY_ACTION[controlType] and enabled ~= false then
				if not self.isPrimaryActionActive then 
					KEYBIND_STRIP:AddKeybindButtonGroup(self.primaryActionDescriptor)
					self.isPrimaryActionActive = true
				else
					--Update incase its name changed based on it being a different control type
					KEYBIND_STRIP:UpdateKeybindButtonGroup(self.primaryActionDescriptor)
				end
			else
				KEYBIND_STRIP:RemoveKeybindButtonGroup(self.primaryActionDescriptor)
				self.isPrimaryActionActive = false
			end
			
		end
		
        local data = list:GetTargetData()
        if not data then
            GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
            return
        end

        local tooltipText
        if type(data.tooltipText) == "number" then
            tooltipText = GetString(data.tooltipText)
        else
            tooltipText = data.tooltipText
        end

        local infoText = GetSettingInfoText(data)
        if infoText then
            tooltipText = tooltipText and (tooltipText .. "\n\n" .. infoText) or infoText
        end

        if tooltipText then
            if data.gamepadCustomTooltipFunction then
                data.gamepadCustomTooltipFunction(GAMEPAD_LEFT_TOOLTIP, tooltipText)
            else
                GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(GAMEPAD_LEFT_TOOLTIP, tooltipText)
            end
        else
            GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        end
    end
end

local function SetSelectedStateOnControl(control, selected)
    control:SetAlpha(ZO_GamepadMenuEntryTemplate_GetAlpha(selected))
    local enabled = control.data.enabled ~= false

    local color = ZO_GamepadMenuEntryTemplate_GetLabelColor(selected, not enabled)
    local r, g, b, a = color:UnpackRGBA()

    local label = control:GetNamedChild("Name")
    label:SetColor(r, g, b, 1)
    SetMenuEntryFontFace(label, selected)

    local slider = control:GetNamedChild("Slider")
    if slider then
        slider:SetColor(r,g,b,a)
        slider:GetNamedChild("Left"):SetColor(r,g,b,a)
        slider:GetNamedChild("Right"):SetColor(r,g,b,a)
        slider:GetNamedChild("Center"):SetColor(r,g,b,a)
    end
    local checkBox = control:GetNamedChild("Checkbox")
    if checkBox then
        checkBox.selected = selected and enabled
    end

    if control.horizontalListControl then
        control.horizontalListObject:SetSelectedFromParent(selected)
    end
end

local function GetTextEntry(text)
    if type(text) == "string" then
        return text
    else
        return GetString(text)
    end
end

function Kela_Options_UpdateOption(control)
    local data = control.data
    local controlType = GetControlType(control)
    local updateFn = updateControlFromSettings[controlType]
    local currentChoice
    local previousChoice = data.currentChoice
    if updateFn then
        currentChoice = updateFn(control)
    end
    -- Fire events
    if currentChoice ~= previousChoice then
        data.currentChoice = currentChoice
        if data.events and data.events[currentChoice] then
            CALLBACK_MANAGER:FireCallbacks(data.events[currentChoice])
        end
    end
    return currentChoice
end


function Kela_GamepadOptions:KelaOnOptionWithDependenciesChanged()
    if SCENE_MANAGER:IsShowing("kela_options_root") then
        KELA_OPTIONS:RefreshOptionsList()
    end
end

function Kela_GamepadOptions:Select()
    local control = self.optionsList:GetSelectedControl()
    local controlType = self:GetControlTypeFromControl(control)
    if controlType == OPTIONS_CHECKBOX then
        ZO_CheckButton_OnClicked(control:GetNamedChild("Checkbox"))
        --When a checkbox is toggled that controls subsettings refreshVisible to show the dependent controls in their disabled state
        if control.data.gamepadHasEnabledDependencies then
			KELA_OPTIONS:KelaOnOptionWithDependenciesChanged()
        end
    elseif controlType == OPTIONS_INVOKE_CALLBACK then
        ZO_Options_InvokeCallback(control)
    elseif controlType == OPTIONS_COLOR then
        ZO_Options_ColorOnClicked(control)
    elseif controlType == OPTIONS_CHAT_COLOR then
        ZO_Options_Social_ChatColorOnClicked(control)
    end
end

local function KelaOptionsCheckBox_SelectChoice(control, boxIsChecked)
    local data = control.data
    local oldValue = KelaGetSettingFromControl(control)
    local value = boxIsChecked
    KelaSetSettingFromControl(control, value)
    if data.mustPushApply then
        local checkBoxControl = GetControl(control, "Checkbox")
        ZO_CheckButton_SetCheckState(checkBoxControl, boxIsChecked)
        local mouseOverControl = WINDOW_MANAGER:GetMouseOverControl()
        local nameControl = GetControl(control, "Name")
        if data.events and data.events[boxIsChecked] then
            CALLBACK_MANAGER:FireCallbacks(data.events[boxIsChecked])
        end
        CheckEnableApplyButton(oldValue, value)
    else
        Kela_Options_UpdateOption(control)
    end
    if data.mustReloadSettings then
        KEYBOARD_OPTIONS:UpdateCurrentPanelOptions(DONT_SAVE_CURRENT_VALUES)
    end
end
local function CheckBoxToggleFunction(checkBoxControl, boxIsChecked)
    local control = checkBoxControl:GetParent()
    KelaOptionsCheckBox_SelectChoice(control, boxIsChecked)
end

function Kela_Options_SetupCheckBox(control)
    local data = control.data
    local checkBoxControl = GetControl(control, "Checkbox")
    ZO_CheckButton_SetToggleFunction(checkBoxControl, CheckBoxToggleFunction)
end
function Kela_Options_SetupSlider(control, selected)
    local data = control.data

    -- Sliders need a min/max value so verify that they are set here
    data.minValue = data.minValue or 0
    data.maxValue = data.maxValue or 1

    local slider = GetControl(control, "Slider")

    if selected ~= nil then
        slider:SetActive(selected and control.data.enabled ~= false)
    end

    data.events = nil -- Sliders don't support events

    if data.defaultMarker and not IsGamepadOption(control) then
        local defaultMarkerControl = CreateControlFromVirtual("$(parent)DefaultMarker", slider, "ZO_Options_DefaultMarker")
        local offsetX = zo_clampedPercentBetween(data.minValue, data.maxValue, data.defaultMarker) * slider:GetWidth()
        defaultMarkerControl:SetAnchor(TOP, slider, LEFT, offsetX + .25, 6)

        defaultMarkerControl:SetHandler("OnClicked", function(self, button)
            PlaySound(SOUNDS.SINGLE_SETTING_RESET_TO_DEFAULT)
            slider:SetValue(data.defaultMarker)
            ZO_Options_SliderOnValueChanged(slider, slider:GetValue())
        end)
    end
end
function Kela_GamepadOptions:InitializeControl(control, selected)
    local label = control:GetNamedChild("Name")

    -- Determine if this control should be disabled because of a dependency
    if control.data.gamepadIsEnabledCallback then
        control.data.enabled = control.data.gamepadIsEnabledCallback()
    end
    SetSelectedStateOnControl(control, selected)
	
	local function KelaInitializeControl(control, selected, isKeyboardControl)
		local data = control.data
		local text = nil

		if type(data.text) == "string" then
			text = data.text
		elseif type(data.text) == "function" then
			text = data.text(control)
		else
			text = GetString(data.text)
		end

		local controlType = ZO_SharedOptions:GetControlTypeFromControl(control)
		control.optionsManager = ZO_SharedOptions

		if controlType == OPTIONS_SECTION_TITLE then
			GetControl(control, "Label"):SetText(text)
		elseif controlType == OPTIONS_DROPDOWN then
			GetControl(control, "Name"):SetText(text)
			ZO_Options_SetupDropdown(control)
		elseif controlType == OPTIONS_HORIZONTAL_SCROLL_LIST then
			GetControl(control, "Name"):SetText(text)
			ZO_Options_SetupScrollList(control, selected)
		elseif controlType == OPTIONS_CHECKBOX then
			GetControl(control, "Name"):SetText(text)
			Kela_Options_SetupCheckBox(control)
		elseif controlType == OPTIONS_SLIDER then
			GetControl(control, "Name"):SetText(text)
			Kela_Options_SetupSlider(control, selected)
		elseif controlType == OPTIONS_INVOKE_CALLBACK  then
			ZO_Options_SetupInvokeCallback(control, selected, text)
		elseif controlType == OPTIONS_COLOR then
			GetControl(control, "Name"):SetText(text)
		elseif controlType == OPTIONS_CHAT_COLOR then
			GetControl(control, "Name"):SetText(text)
			data.customResetToDefaultsFunction = ZO_OptionsPanel_Social_ResetChatColorToDefault
		elseif controlType == OPTIONS_CUSTOM then
			if data.customSetupFunction then
				data.customSetupFunction(control, selected)
			end
		end

		if data.onInitializeFunction then
			data.onInitializeFunction(control, isKeyboardControl)
		end

		
	end

    local IS_GAMEPAD_CONTROL = true
	KelaInitializeControl(control, selected, IS_GAMEPAD_CONTROL)
		
		
    if not control.data.enabled and control.data.disabledText then
        label:SetText(GetTextEntry(control.data.disabledText))
    else
        if IsConsoleUI() and control.data.consoleTextOverride then
            label:SetText(GetTextEntry(control.data.consoleTextOverride))
        elseif control.data.gamepadTextOverride then
            label:SetText(GetTextEntry(control.data.gamepadTextOverride))
        end
    end
	
	
    Kela_Options_UpdateOption(control)
end

function Kela_GamepadOptions_OnInitialize(control)
    KELA_OPTIONS = Kela_GamepadOptions:New(control)
    SYSTEMS:RegisterGamepadObject("kelaOptions", KELA_OPTIONS)
end

local TEMPLATE_NAMES = 
{
    [OPTIONS_HORIZONTAL_SCROLL_LIST] = "ZO_GamepadOptionsHorizontalListRow",
    [OPTIONS_SLIDER] = "ZO_GamepadOptionsSliderRow",
    [OPTIONS_CHECKBOX] = "ZO_GamepadOptionsCheckboxRow",
    [OPTIONS_INVOKE_CALLBACK] = "ZO_GamepadOptionsLabelRow",
    [OPTIONS_COLOR] = "ZO_GamepadOptionsColorRow",
    [OPTIONS_CHAT_COLOR] = "ZO_GamepadOptionsColorRow",
}

local KELA_SETTINGS_CATEGORY_ORDER =
{
    KELA_SETTING_PANEL_FEATURES,
    KELA_SETTING_PANEL_TRAIT_RESEARCH,
    KELA_SETTING_PANEL_SETS,
    KELA_SETTING_PANEL_TRADE,
}

-- The trait research help text names LibCharacterKnowledge and reports whether
-- the library was found.  It is rebuilt on every list refresh so the status is
-- accurate without restarting the add-on.
local function KelaTraitResearchTooltip()
    local statusText
    if LibCharacterKnowledge ~= nil then
        statusText = kpuiConst.Colors.COLOR_LIGHT_GREEN:Colorize(GetString(KELA_SETTINGS_TRAIT_RESEARCH_LCK_AVAILABLE))
    else
        statusText = kpuiConst.Colors.COLOR_LIGHT_RED:Colorize(GetString(KELA_SETTINGS_TRAIT_RESEARCH_LCK_NOTFOUND))
    end

    return GetString(KELA_SETTINGS_TRAIT_RESEARCH_ENABLED_TOOLTIP)
        .. "\n\n"
        .. GetString(KELA_SETTINGS_TRAIT_RESEARCH_LCK_STATUS) .. ": " .. statusText
end

function Kela_GamepadOptions:RefreshOptionsList()
    self.optionsList:Clear()
    local traitResearchData = kela_SettingsData[KELA_SETTING_PANEL_TRAIT_RESEARCH]
    if traitResearchData then
        local data = traitResearchData[SETTING_TYPE_KELA][KELA_SETTING_PANEL_TRAIT_RESEARCH_ENABLED]
        if data then
            data.tooltipText = KelaTraitResearchTooltip()
        end
    end
    for _, panelId in ipairs(KELA_SETTINGS_CATEGORY_ORDER) do
        self:AddSettingGroup(panelId, GetString("KELA_SETTINGSYSTEMPANEL", panelId))
    end
    self.optionsList:Commit()
end

function Kela_GamepadOptions:KelaGetSettingsData(panel, system, settingId)
    return kela_SettingsData[panel][system][settingId]
end

function Kela_GamepadOptions:AddSettingGroup(panelId, categoryHeader)
    local settings = KELA_SETTINGS_DATA[panelId]
    if settings then
        local lastHeader = nil
        local categoryHeaderPending = categoryHeader
        for i, setting in ipairs(settings) do
            local data = self:KelaGetSettingsData(setting.panel, setting.system, setting.settingId)
            local isVisible = data.visible == nil or data.visible
            if type(isVisible) == "function" then
                isVisible = isVisible()
            end
            if isVisible then
                local header
                if categoryHeaderPending then
                    header = categoryHeaderPending
                    categoryHeaderPending = nil
                elseif setting.header then
                    if type(setting.header) == "function" then
                        -- Clear header data when calling header function so the previous result of function is not retained
                        data.header = nil
                        header = setting.header(setting)
                    else
                        header = GetString(setting.header)
                    end
                end
                local controlType = self:GetControlType(data.controlType)
                if controlType == OPTIONS_CUSTOM then
                    controlType = data.customControlType
                end
                local templateName = TEMPLATE_NAMES[controlType]
                local newHeader = header or data.header
                if newHeader and newHeader ~= lastHeader then 
                    templateName = templateName .. "WithHeader"
                    if not data.header then
                        data.header = header
                    end
                end
                lastHeader = newHeader
                self.optionsList:AddEntry(templateName, data)
            end
        end
    end
end

function Kela_GamepadOptions:InitializeSaveReloadDialog()
	-- close lists when leaving the dialog unexpectedly
    local noChoiceCallback = function(dialog)
	end	
    ZO_Dialogs_RegisterCustomDialog("KELA_OPTIONS_RESET_TO_SAVED",
    {
        gamepadInfo =
        {
            dialogType = GAMEPAD_DIALOGS.BASIC,
        },
		title =
		{
			text = KELA_OPTIONS_CANCEL_TITLE,
		},
		mainText = 
		{
			text = 	function(dialog)
						return GetString(KELA_OPTIONS_CANCEL_ALL_PROMPT)
					end,
		},	
        buttons =
        {
			[1] =
			{
				text = SI_DIALOG_DISMISS,
				callback =  function(dialog)
								SaveSettings(KELA_RESTORE_SAVED)
								KELA_OPTIONS:KelaOnOptionWithDependenciesChanged()
							end
			},
			[2] =
			{
				text = SI_DIALOG_CANCEL,
			},
        },
        noChoiceCallback = noChoiceCallback,
    })

    ZO_Dialogs_RegisterCustomDialog("KELA_OPTIONS_RESET_TO_DEFAULTS",
    {
		mustChoose = true,
		gamepadInfo =
		{
			dialogType = GAMEPAD_DIALOGS.BASIC,
		},
		title =
		{
			text = SI_OPTIONS_RESET_TITLE,
		},
		mainText = 
		{
			text =  SI_OPTIONS_RESET_ALL_PROMPT,
		},
		buttons =
		{
			[1] =
			{
				text = SI_OPTIONS_RESET,
				callback =  function(dialog)
								SaveSettings(KELA_LOAD_DEFAULT)
								KELA_OPTIONS:KelaOnOptionWithDependenciesChanged()
							end
			},
			[2] =
			{
				text = SI_DIALOG_CANCEL,
			},
		},
    })

    ZO_Dialogs_RegisterCustomDialog("KELA_OPTIONS_RELOAD_REQUIRED",
    {
        gamepadInfo =
        {
            dialogType = GAMEPAD_DIALOGS.BASIC,
        },
        title =
        {
            text = KELA_OPTIONS_RELOAD_TITLE,
        },
        mainText =
        {
            text = KELA_OPTIONS_RELOAD_MESSAGE,
        },
        buttons =
        {
            [1] =
            {
                text = KELA_OPTIONS_RELOAD_NOW,
                callback =  function(dialog)
                                ReloadUI("ingame")
                            end
            },
            [2] =
            {
                text = KELA_OPTIONS_RELOAD_LATER,
            },
        },
    })

end
