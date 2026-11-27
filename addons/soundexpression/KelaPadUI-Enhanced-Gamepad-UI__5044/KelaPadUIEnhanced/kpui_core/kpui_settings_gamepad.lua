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
--   7600-7699  fixes and patches
--   7700-7799  account-wide game settings
--   7800-7899  action bar
--   7900-7999  reserve
SETTING_TYPE_KELA = 7000

-- JOURNALS AND BROWSERS
-- One panel for the menu screens. The sets and trait research toggles keep the
-- IDs they shipped with; their old one-row panels (7300, 7302) are retired.
KELA_SETTING_PANEL_JOURNALS 					= 7304
KELA_SETTING_PANEL_SETS_ENABLED 				= 7301
KELA_SETTING_PANEL_TRAIT_RESEARCH_ENABLED 		= 7303
-- FEATURES
KELA_SETTING_PANEL_FEATURES 					= 7400
KELA_SETTING_PANEL_FEATURES_COMPANION 			= 7401
KELA_SETTING_PANEL_FEATURES_DUNGEON_FINDER 		= 7402
KELA_SETTING_PANEL_FEATURES_CHAT_TOOLS 			= 7403
KELA_SETTING_PANEL_FEATURES_MAP_RALLY 			= 7404
KELA_SETTING_PANEL_FEATURES_ANTIQUITY_LEADS 	= 7406
-- 7407 (Extended Journal) is retired; Loot Log, Collectibles Tracker, and
-- Raidificator each have their own toggle.
KELA_SETTING_PANEL_FEATURES_MAIN_MENU_SHORTCUTS = 7408
KELA_SETTING_PANEL_FEATURES_MAIN_MENU_DASHBOARD = 7409
KELA_SETTING_PANEL_FEATURES_PA_JUNK = 7410
KELA_SETTING_PANEL_FEATURES_PS5_BUTTONS = 7411
KELA_SETTING_PANEL_FEATURES_GAMEPAD_FILTERS = 7412
KELA_SETTING_PANEL_FEATURES_CHARACTER_KNOWLEDGE = 7414
KELA_SETTING_PANEL_FEATURES_LOOT_LOG = 7415
KELA_SETTING_PANEL_FEATURES_COLLECTIBLES_TRACKER = 7416
KELA_SETTING_PANEL_FEATURES_RAIDIFICATOR = 7417
KELA_SETTING_PANEL_FEATURES_FIGHT_STATS = 7418
KELA_SETTING_PANEL_FIGHT_STATS_PVE = 7419
KELA_SETTING_PANEL_FIGHT_STATS_BATTLEGROUNDS = 7420
KELA_SETTING_PANEL_FIGHT_STATS_KEPT = 7421
-- FIXES AND PATCHES
KELA_SETTING_PANEL_FIXES 						= 7600
KELA_SETTING_PANEL_FIXES_GROUP_MENU 			= 7601
-- 7413 keeps the number it shipped with so saved values survive the move from
-- the Features panel into Fixes and Patches.
KELA_SETTING_PANEL_FIXES_BG_U51 				= 7413
-- ACCOUNT-WIDE GAME SETTINGS
KELA_SETTING_PANEL_ACCOUNT 						= 7700
KELA_SETTING_PANEL_ACCOUNT_SYNC_COMBAT 				= 7701
KELA_SETTING_PANEL_ACCOUNT_SYNC_CAMERA 				= 7702
KELA_SETTING_PANEL_ACCOUNT_SYNC_INTERFACE 			= 7703
KELA_SETTING_PANEL_ACCOUNT_SYNC_NAMEPLATES 			= 7704
KELA_SETTING_PANEL_ACCOUNT_SYNC_SOCIAL 				= 7705
-- ACTION BAR
KELA_SETTING_PANEL_ACTIONBAR 						= 7800
KELA_SETTING_PANEL_ACTIONBAR_ENABLED 				= 7801
KELA_SETTING_PANEL_ACTIONBAR_STACKS 				= 7802
KELA_SETTING_PANEL_ACTIONBAR_EXPIRY_WARNING 		= 7803
KELA_SETTING_PANEL_ACTIONBAR_RAISE 					= 7804
KELA_SETTING_PANEL_ACTIONBAR_SECONDS 				= 7805
KELA_SETTING_PANEL_ACTIONBAR_RESOURCE_SHIFT 		= 7806
KELA_SETTING_PANEL_ACTIONBAR_ALWAYS_SHOW 			= 7807
KELA_SETTING_PANEL_ACTIONBAR_BAR 					= 7808
KELA_SETTING_PANEL_ACTIONBAR_HEALTH_RAISE 			= 7809
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
KELA_RETIRED_SETTING_IDS =
{
	7300, -- Item sets panel, merged into Journals and Browsers
	7302, -- Trait research panel, merged into Journals and Browsers
	7407, -- Extended Journal, replaced by one screen per add-on (7415-7417)
}

-- Other add-ons that settings depend on. `name` is the add-on's own title and
-- is not translated; `isLoaded` checks the global the feature itself reads.
local KELA_ADDONS =
{
	LCK = { name = "LibCharacterKnowledge", isLoaded = function() return LibCharacterKnowledge ~= nil end },
	LL = { name = "Loot Log", isLoaded = function() return LootLog ~= nil end },
	CT = { name = "Collectibles Tracker", isLoaded = function() return CollectiblesTracker ~= nil end },
	RCR = { name = "Raidificator", isLoaded = function() return Raidificator ~= nil end },
	LC = { name = "LibCombat", isLoaded = function() return LibCombat ~= nil end },
	PA = { name = "PersonalAssistant", isLoaded = function() return PersonalAssistant ~= nil end },
	TTC = { name = "Tamriel Trade Centre", isLoaded = function() return TamrielTradeCentre ~= nil end },
	ATT = { name = "Arkadius Trade Tools", isLoaded = function() return ArkadiusTradeTools ~= nil end },
	MM = { name = "Master Merchant", isLoaded = function() return MasterMerchant ~= nil end },
	LIL = { name = "LibItemLink", isLoaded = function() return LIB_ITEM_LINK ~= nil end },
	LCM = { name = "LibCustomMenu", isLoaded = function() return LibCustomMenu ~= nil end },
	USPF = { name = "Urich's Skill Point Finder", isLoaded = function() return USPF ~= nil end },
	FAB = { name = "Fancy Action Bar+", isLoaded = function() return FancyActionBar ~= nil end },
	ADR = { name = "Action Duration Reminder", isLoaded = function() return ActionDurationReminder ~= nil end },
}

-- The Fight Stats options follow its master toggle.
local function KelaFightStatsSettingsEnabled()
	return KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_FEATURES_FIGHT_STATS)
end

-- A row's `enabled` is either a value or a function that returns one; only an
-- explicit false disables it.
local function KelaIsSettingEnabled(data)
	local enabled = data.enabled
	if type(enabled) == "function" then
		enabled = enabled()
	end
	return enabled ~= false
end

-- Trading rows show only while a price provider is installed and the trading
-- feature is on; the provider check keeps a saved "on" from exposing rows when
-- none of TTC, ATT or Master Merchant is loaded.
local function KelaHasTradeProvider()
	return TamrielTradeCentre ~= nil or ArkadiusTradeTools ~= nil or MasterMerchant ~= nil
end

local function KelaTradeShown()
	return KelaHasTradeProvider() and KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ENABLED)
end

-- Action bar sub-options show while the master switch is on.
local function KelaActionBarShown()
	return KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_ACTIONBAR_ENABLED)
end

local function KelaAnyTradeTooltipShown()
	return KelaTradeShown() and (KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_TRADINGHOUSE)
		or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_BANK)
		or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_CRAFTING)
		or KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_TOOLTIP_STORE))
end

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
    },
	-- FIXES AND PATCHES
    [KELA_SETTING_PANEL_FIXES] =
    {
        {
            panel = KELA_SETTING_PANEL_FIXES,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_FIXES_GROUP_MENU,
        },
        {
            panel = KELA_SETTING_PANEL_FIXES,
            system = SETTING_TYPE_KELA,
            settingId = KELA_SETTING_PANEL_FIXES_BG_U51,
        },
    },
	-- ACCOUNT-WIDE GAME SETTINGS
    [KELA_SETTING_PANEL_ACCOUNT] =
    {
        { panel = KELA_SETTING_PANEL_ACCOUNT, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_ACCOUNT_SYNC_CAMERA },
        { panel = KELA_SETTING_PANEL_ACCOUNT, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_ACCOUNT_SYNC_INTERFACE },
        { panel = KELA_SETTING_PANEL_ACCOUNT, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_ACCOUNT_SYNC_NAMEPLATES },
        { panel = KELA_SETTING_PANEL_ACCOUNT, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_ACCOUNT_SYNC_SOCIAL },
        { panel = KELA_SETTING_PANEL_ACCOUNT, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_ACCOUNT_SYNC_COMBAT },
    },
	-- ACTION BAR
    [KELA_SETTING_PANEL_ACTIONBAR] =
    {
        { panel = KELA_SETTING_PANEL_ACTIONBAR, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_ACTIONBAR_ENABLED },
        { panel = KELA_SETTING_PANEL_ACTIONBAR, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_ACTIONBAR_STACKS },
        { panel = KELA_SETTING_PANEL_ACTIONBAR, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_ACTIONBAR_ALWAYS_SHOW },
        { panel = KELA_SETTING_PANEL_ACTIONBAR, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_ACTIONBAR_EXPIRY_WARNING },
        { panel = KELA_SETTING_PANEL_ACTIONBAR, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_ACTIONBAR_RAISE },
        { panel = KELA_SETTING_PANEL_ACTIONBAR, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_ACTIONBAR_BAR },
        { panel = KELA_SETTING_PANEL_ACTIONBAR, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_ACTIONBAR_SECONDS },
        { panel = KELA_SETTING_PANEL_ACTIONBAR, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_ACTIONBAR_RESOURCE_SHIFT },
        { panel = KELA_SETTING_PANEL_ACTIONBAR, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_ACTIONBAR_HEALTH_RAISE },
    },
	-- JOURNALS AND BROWSERS
    [KELA_SETTING_PANEL_JOURNALS] =
    {
        { panel = KELA_SETTING_PANEL_JOURNALS, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_SETS_ENABLED },
        { panel = KELA_SETTING_PANEL_JOURNALS, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_TRAIT_RESEARCH_ENABLED },
        { panel = KELA_SETTING_PANEL_JOURNALS, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_FEATURES_CHARACTER_KNOWLEDGE },
        { panel = KELA_SETTING_PANEL_JOURNALS, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_FEATURES_LOOT_LOG },
        { panel = KELA_SETTING_PANEL_JOURNALS, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_FEATURES_COLLECTIBLES_TRACKER },
        { panel = KELA_SETTING_PANEL_JOURNALS, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_FEATURES_RAIDIFICATOR },
        { panel = KELA_SETTING_PANEL_JOURNALS, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_FEATURES_FIGHT_STATS },
        { panel = KELA_SETTING_PANEL_JOURNALS, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_FIGHT_STATS_PVE },
        { panel = KELA_SETTING_PANEL_JOURNALS, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_FIGHT_STATS_BATTLEGROUNDS },
        { panel = KELA_SETTING_PANEL_JOURNALS, system = SETTING_TYPE_KELA, settingId = KELA_SETTING_PANEL_FIGHT_STATS_KEPT },
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


-- One "share this Options panel" checkbox. It applies without a reload: the
-- account settings module acts on the toggle event. The label and tooltip use
-- the game's own panel name.
local function KelaAccountSyncRow(settingId, gamePanel)
	local function PanelName()
		return GetString("SI_SETTINGSYSTEMPANEL", gamePanel)
	end
	return
	{
		controlType = OPTIONS_CHECKBOX,
		system = SETTING_TYPE_KELA,
		panel = KELA_SETTING_PANEL_ACCOUNT,
		settingId = settingId,
		text = function()
			return zo_strformat(GetString(KELA_SETTINGS_ACCOUNT_SYNC_CATEGORY), PanelName())
		end,
		tooltipText = function()
			return zo_strformat(GetString(KELA_SETTINGS_ACCOUNT_SYNC_TOOLTIP), PanelName())
		end,
		events =
		{
			[true] = "KELA_ACCOUNT_SETTINGS_TOGGLED",
			[false] = "KELA_ACCOUNT_SETTINGS_TOGGLED",
		},
	}
end

-- control data table for the auto-list
kela_SettingsData = 
{
    [KELA_SETTING_PANEL_JOURNALS] =
    {
		[SETTING_TYPE_KELA] =
		{
			[KELA_SETTING_PANEL_SETS_ENABLED] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_JOURNALS,
				settingId = KELA_SETTING_PANEL_SETS_ENABLED,
				text = KELA_SETTINGS_SETS_ENABLED,
				tooltipText = KELA_SETTINGS_SETS_ENABLED_TOOLTIP,
			},
			[KELA_SETTING_PANEL_TRAIT_RESEARCH_ENABLED] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_JOURNALS,
				settingId = KELA_SETTING_PANEL_TRAIT_RESEARCH_ENABLED,
				text = KELA_SETTINGS_TRAIT_RESEARCH_ENABLED,
				tooltipText = KELA_SETTINGS_TRAIT_RESEARCH_ENABLED_TOOLTIP,
				requiresReload = true,
				addons = { optional = { KELA_ADDONS.LCK } },
			},
			[KELA_SETTING_PANEL_FEATURES_CHARACTER_KNOWLEDGE] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_JOURNALS,
				settingId = KELA_SETTING_PANEL_FEATURES_CHARACTER_KNOWLEDGE,
				text = KELA_SETTINGS_FEATURES_CHARACTER_KNOWLEDGE,
				tooltipText = KELA_SETTINGS_FEATURES_CHARACTER_KNOWLEDGE_TOOLTIP,
				addons = { required = { KELA_ADDONS.LCK } },
			},
			[KELA_SETTING_PANEL_FEATURES_LOOT_LOG] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_JOURNALS,
				settingId = KELA_SETTING_PANEL_FEATURES_LOOT_LOG,
				text = KELA_SETTINGS_FEATURES_LOOT_LOG,
				tooltipText = KELA_SETTINGS_FEATURES_LOOT_LOG_TOOLTIP,
				addons = { required = { KELA_ADDONS.LL } },
			},
			[KELA_SETTING_PANEL_FEATURES_COLLECTIBLES_TRACKER] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_JOURNALS,
				settingId = KELA_SETTING_PANEL_FEATURES_COLLECTIBLES_TRACKER,
				text = KELA_SETTINGS_FEATURES_COLLECTIBLES_TRACKER,
				tooltipText = KELA_SETTINGS_FEATURES_COLLECTIBLES_TRACKER_TOOLTIP,
				addons = { required = { KELA_ADDONS.CT } },
			},
			[KELA_SETTING_PANEL_FEATURES_RAIDIFICATOR] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_JOURNALS,
				settingId = KELA_SETTING_PANEL_FEATURES_RAIDIFICATOR,
				text = KELA_SETTINGS_FEATURES_RAIDIFICATOR,
				tooltipText = KELA_SETTINGS_FEATURES_RAIDIFICATOR_TOOLTIP,
				addons = { required = { KELA_ADDONS.RCR } },
			},
			[KELA_SETTING_PANEL_FEATURES_FIGHT_STATS] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_JOURNALS,
				settingId = KELA_SETTING_PANEL_FEATURES_FIGHT_STATS,
				text = KELA_SETTINGS_FEATURES_FIGHT_STATS,
				tooltipText = KELA_SETTINGS_FEATURES_FIGHT_STATS_TOOLTIP,
				events = { [true] = "KELA_FIGHT_STATS_SETTINGS_CHANGED", [false] = "KELA_FIGHT_STATS_SETTINGS_CHANGED" },
				addons = { required = { KELA_ADDONS.LC } },
			},
			[KELA_SETTING_PANEL_FIGHT_STATS_PVE] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_JOURNALS,
				settingId = KELA_SETTING_PANEL_FIGHT_STATS_PVE,
				text = KELA_SETTINGS_FIGHT_STATS_PVE,
				tooltipText = KELA_SETTINGS_FIGHT_STATS_PVE_TOOLTIP,
				events = { [true] = "KELA_FIGHT_STATS_SETTINGS_CHANGED", [false] = "KELA_FIGHT_STATS_SETTINGS_CHANGED" },
				enabled = KelaFightStatsSettingsEnabled,
			},
			[KELA_SETTING_PANEL_FIGHT_STATS_BATTLEGROUNDS] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_JOURNALS,
				settingId = KELA_SETTING_PANEL_FIGHT_STATS_BATTLEGROUNDS,
				text = KELA_SETTINGS_FIGHT_STATS_BATTLEGROUNDS,
				tooltipText = KELA_SETTINGS_FIGHT_STATS_BATTLEGROUNDS_TOOLTIP,
				events = { [true] = "KELA_FIGHT_STATS_SETTINGS_CHANGED", [false] = "KELA_FIGHT_STATS_SETTINGS_CHANGED" },
				enabled = KelaFightStatsSettingsEnabled,
			},
			[KELA_SETTING_PANEL_FIGHT_STATS_KEPT] =
			{
				controlType = OPTIONS_SLIDER,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_JOURNALS,
				settingId = KELA_SETTING_PANEL_FIGHT_STATS_KEPT,
				text = KELA_SETTINGS_FIGHT_STATS_KEPT,
				changedEvent = "KELA_FIGHT_STATS_SETTINGS_CHANGED",
				-- Defined with the screen, which loads later; read when the help shows.
				tooltipText = function()
					return KelaGetFightStatsKeptTooltip and KelaGetFightStatsKeptTooltip() or ""
				end,
				valueFormat = "%d",
				minValue = 1,
				maxValue = 40,
				gamepadValueStep = 1,
				showValue = true,
				enabled = KelaFightStatsSettingsEnabled,
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
				-- The player context-menu actions need it; the slash commands do not.
				addons = { optional = { KELA_ADDONS.LCM } },
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
				-- Supplies the skill point totals.
				addons = { optional = { KELA_ADDONS.USPF } },
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
				addons = { required = { KELA_ADDONS.PA } },
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
		},
	},
    [KELA_SETTING_PANEL_FIXES] =
    {
		[SETTING_TYPE_KELA] =
		{
			[KELA_SETTING_PANEL_FIXES_GROUP_MENU] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_FIXES,
				settingId = KELA_SETTING_PANEL_FIXES_GROUP_MENU,
				text = KELA_SETTINGS_FIXES_GROUP_MENU,
				tooltipText = KELA_SETTINGS_FIXES_GROUP_MENU_TOOLTIP,
				requiresReload = true,
			},
			[KELA_SETTING_PANEL_FIXES_BG_U51] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_FIXES,
				settingId = KELA_SETTING_PANEL_FIXES_BG_U51,
				text = KELA_SETTINGS_FEATURES_BASE_GAME_FIXES,
				tooltipText = KELA_SETTINGS_FEATURES_BASE_GAME_FIXES_TOOLTIP,
				requiresReload = true,
			},
		},
	},
    [KELA_SETTING_PANEL_ACCOUNT] =
    {
		[SETTING_TYPE_KELA] =
		{
			[KELA_SETTING_PANEL_ACCOUNT_SYNC_CAMERA] = KelaAccountSyncRow(KELA_SETTING_PANEL_ACCOUNT_SYNC_CAMERA, SETTING_PANEL_CAMERA),
			[KELA_SETTING_PANEL_ACCOUNT_SYNC_INTERFACE] = KelaAccountSyncRow(KELA_SETTING_PANEL_ACCOUNT_SYNC_INTERFACE, SETTING_PANEL_INTERFACE),
			[KELA_SETTING_PANEL_ACCOUNT_SYNC_NAMEPLATES] = KelaAccountSyncRow(KELA_SETTING_PANEL_ACCOUNT_SYNC_NAMEPLATES, SETTING_PANEL_NAMEPLATES),
			[KELA_SETTING_PANEL_ACCOUNT_SYNC_SOCIAL] = KelaAccountSyncRow(KELA_SETTING_PANEL_ACCOUNT_SYNC_SOCIAL, SETTING_PANEL_SOCIAL),
			[KELA_SETTING_PANEL_ACCOUNT_SYNC_COMBAT] = KelaAccountSyncRow(KELA_SETTING_PANEL_ACCOUNT_SYNC_COMBAT, SETTING_PANEL_COMBAT),
		},
	},
    [KELA_SETTING_PANEL_ACTIONBAR] =
    {
		[SETTING_TYPE_KELA] =
		{
			-- Installs the action bar hooks at load; the options below apply live.
			[KELA_SETTING_PANEL_ACTIONBAR_ENABLED] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_ACTIONBAR,
				settingId = KELA_SETTING_PANEL_ACTIONBAR_ENABLED,
				text = KELA_SETTINGS_ACTIONBAR_ENABLED,
				tooltipText = function()
					return zo_strformat(GetString(KELA_SETTINGS_ACTIONBAR_ENABLED_TOOLTIP), GetString(SI_INTERFACE_OPTIONS_ACTION_BAR_TIMERS), GetString(SI_INTERFACE_OPTIONS_ACTION_BAR_BACK_ROW), GetString("SI_SETTINGSYSTEMPANEL", SETTING_PANEL_COMBAT), KELA_ADDONS.FAB.name, KELA_ADDONS.ADR.name)
				end,
				requiresReload = true,
				gamepadHasEnabledDependencies = true,
				-- Both replace the back row; kpui_action_bar.lua stays off while either is loaded.
				addons = { conflicts = { KELA_ADDONS.FAB, KELA_ADDONS.ADR } },
			},
			[KELA_SETTING_PANEL_ACTIONBAR_STACKS] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_ACTIONBAR,
				settingId = KELA_SETTING_PANEL_ACTIONBAR_STACKS,
				text = KELA_SETTINGS_ACTIONBAR_STACKS,
				events = { [true] = "KELA_ACTIONBAR_SETTINGS_CHANGED", [false] = "KELA_ACTIONBAR_SETTINGS_CHANGED" },
				tooltipText = function()
					-- Seething Fury (122658) on Molten Whip (20805), named in the client's language.
					return zo_strformat(GetString(KELA_SETTINGS_ACTIONBAR_STACKS_TOOLTIP), GetAbilityName(122658), GetAbilityName(20805))
				end,
				visible = KelaActionBarShown,
			},
			[KELA_SETTING_PANEL_ACTIONBAR_ALWAYS_SHOW] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_ACTIONBAR,
				settingId = KELA_SETTING_PANEL_ACTIONBAR_ALWAYS_SHOW,
				text = KELA_SETTINGS_ACTIONBAR_ALWAYS_SHOW,
				events = { [true] = "KELA_ACTIONBAR_SETTINGS_CHANGED", [false] = "KELA_ACTIONBAR_SETTINGS_CHANGED" },
				tooltipText = function()
					return zo_strformat(GetString(KELA_SETTINGS_ACTIONBAR_ALWAYS_SHOW_TOOLTIP), GetString(SI_INTERFACE_OPTIONS_ACTION_BAR_TIMERS), GetString(SI_INTERFACE_OPTIONS_ACTION_BAR_BACK_ROW))
				end,
				visible = KelaActionBarShown,
			},
			[KELA_SETTING_PANEL_ACTIONBAR_EXPIRY_WARNING] =
			{
				controlType = OPTIONS_SLIDER,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_ACTIONBAR,
				settingId = KELA_SETTING_PANEL_ACTIONBAR_EXPIRY_WARNING,
				text = KELA_SETTINGS_ACTIONBAR_EXPIRY_WARNING,
				changedEvent = "KELA_ACTIONBAR_SETTINGS_CHANGED",
				tooltipText = KELA_SETTINGS_ACTIONBAR_EXPIRY_WARNING_TOOLTIP,
				valueFormat = "%d",
				minValue = 0,
				maxValue = 5,
				gamepadValueStep = 1,
				showValue = true,
				visible = KelaActionBarShown,
			},
			[KELA_SETTING_PANEL_ACTIONBAR_RAISE] =
			{
				controlType = OPTIONS_SLIDER,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_ACTIONBAR,
				settingId = KELA_SETTING_PANEL_ACTIONBAR_RAISE,
				text = KELA_SETTINGS_ACTIONBAR_RAISE,
				changedEvent = "KELA_ACTIONBAR_SETTINGS_CHANGED",
				tooltipText = KELA_SETTINGS_ACTIONBAR_RAISE_TOOLTIP,
				valueFormat = "%d",
				minValue = 0,
				maxValue = 40,
				gamepadValueStep = 1,
				showValue = true,
				visible = KelaActionBarShown,
			},
			[KELA_SETTING_PANEL_ACTIONBAR_BAR] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_ACTIONBAR,
				settingId = KELA_SETTING_PANEL_ACTIONBAR_BAR,
				text = KELA_SETTINGS_ACTIONBAR_BAR,
				events = { [true] = "KELA_ACTIONBAR_SETTINGS_CHANGED", [false] = "KELA_ACTIONBAR_SETTINGS_CHANGED" },
				tooltipText = KELA_SETTINGS_ACTIONBAR_BAR_TOOLTIP,
				visible = KelaActionBarShown,
			},
			[KELA_SETTING_PANEL_ACTIONBAR_SECONDS] =
			{
				controlType = OPTIONS_CHECKBOX,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_ACTIONBAR,
				settingId = KELA_SETTING_PANEL_ACTIONBAR_SECONDS,
				text = KELA_SETTINGS_ACTIONBAR_SECONDS,
				events = { [true] = "KELA_ACTIONBAR_SETTINGS_CHANGED", [false] = "KELA_ACTIONBAR_SETTINGS_CHANGED" },
				tooltipText = KELA_SETTINGS_ACTIONBAR_SECONDS_TOOLTIP,
				visible = KelaActionBarShown,
			},
			-- Independent of the master switch; applies live.
			[KELA_SETTING_PANEL_ACTIONBAR_RESOURCE_SHIFT] =
			{
				controlType = OPTIONS_SLIDER,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_ACTIONBAR,
				settingId = KELA_SETTING_PANEL_ACTIONBAR_RESOURCE_SHIFT,
				text = KELA_SETTINGS_ACTIONBAR_RESOURCE_SHIFT,
				changedEvent = "KELA_ACTIONBAR_SETTINGS_CHANGED",
				tooltipText = function()
					return zo_strformat(GetString(KELA_SETTINGS_ACTIONBAR_RESOURCE_SHIFT_TOOLTIP), GetString(SI_GAME_MENU_EDIT_HUD))
				end,
				valueFormat = "%d",
				minValue = -100,
				maxValue = 400,
				gamepadValueStep = 5,
				showValue = true,
			},
			-- Independent of the master switch; applies live.
			[KELA_SETTING_PANEL_ACTIONBAR_HEALTH_RAISE] =
			{
				controlType = OPTIONS_SLIDER,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_ACTIONBAR,
				settingId = KELA_SETTING_PANEL_ACTIONBAR_HEALTH_RAISE,
				text = KELA_SETTINGS_ACTIONBAR_HEALTH_RAISE,
				changedEvent = "KELA_ACTIONBAR_SETTINGS_CHANGED",
				tooltipText = function()
					return zo_strformat(GetString(KELA_SETTINGS_ACTIONBAR_HEALTH_RAISE_TOOLTIP), GetString(SI_GAME_MENU_EDIT_HUD))
				end,
				valueFormat = "%d",
				minValue = -100,
				maxValue = 200,
				gamepadValueStep = 5,
				showValue = true,
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
				enabled = KelaHasTradeProvider,
				requiresReload = true,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_TRADE,
				settingId = KELA_SETTING_PANEL_TRADE_ENABLED,
				text = KELA_SETTINGS_TRADE_ENABLED,
				tooltipText = KELA_SETTINGS_TRADE_ENABLED_TOOLTIP,
				gamepadHasEnabledDependencies = true,
				addons = { oneOf = { KELA_ADDONS.TTC, KELA_ADDONS.ATT, KELA_ADDONS.MM } },
			},
			[KELA_SETTING_PANEL_TRADE_ATT_PERIOD] =
			{
				controlType = OPTIONS_SLIDER,
				system = SETTING_TYPE_KELA,
				panel = KELA_SETTING_PANEL_TRADE,
				settingId = KELA_SETTING_PANEL_TRADE_ATT_PERIOD,
				text = KELA_SETTINGS_TRADE_ATTGRAPH_PERIOD,
				tooltipText = KELA_SETTINGS_TRADE_ATTGRAPH_PERIOD_TOOLTIP,
				addons = { required = { KELA_ADDONS.ATT } },
				valueFormat = "%d",
				minValue = 1,
				maxValue = 30,
				gamepadValueStep = 1,
				showValue = true,
				visible  = function()
                    return KelaTradeShown() and ArkadiusTradeTools ~= nil
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
                    return KelaTradeShown()
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
                    return KelaTradeShown()
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
                    return KelaTradeShown()
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
                    return KelaTradeShown()
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
				addons = { required = { KELA_ADDONS.ATT } },
				visible  = function()
                    return ArkadiusTradeTools ~= nil and KelaAnyTradeTooltipShown()
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
				addons = { required = { KELA_ADDONS.ATT } },
				visible  = function()
                    return ArkadiusTradeTools ~= nil and KelaAnyTradeTooltipShown()
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
                    return KelaAnyTradeTooltipShown()
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
				addons = { required = { KELA_ADDONS.LIL } },
				visible  = function()
                    return KelaAnyTradeTooltipShown()
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
                    return KelaAnyTradeTooltipShown()
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
                    return ArkadiusTradeTools ~= nil and KelaAnyTradeTooltipShown()
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
		[KELA_SETTING_PANEL_FEATURES_CHARACTER_KNOWLEDGE] = "true",
		[KELA_SETTING_PANEL_FEATURES_LOOT_LOG] 			= "true",
		[KELA_SETTING_PANEL_FEATURES_COLLECTIBLES_TRACKER] = "true",
		[KELA_SETTING_PANEL_FEATURES_RAIDIFICATOR] 		= "true",
		[KELA_SETTING_PANEL_FEATURES_FIGHT_STATS] 		= "true",
		[KELA_SETTING_PANEL_FIGHT_STATS_PVE] 			= "true",
		[KELA_SETTING_PANEL_FIGHT_STATS_BATTLEGROUNDS] 	= "true",
		[KELA_SETTING_PANEL_FIGHT_STATS_KEPT] 			= "10",
		[KELA_SETTING_PANEL_FEATURES_PA_JUNK] 			= "true",
		[KELA_SETTING_PANEL_FEATURES_PS5_BUTTONS] 		= "false",
		-- FIXES AND PATCHES
		[KELA_SETTING_PANEL_FIXES_GROUP_MENU] 			= "true",
		[KELA_SETTING_PANEL_FIXES_BG_U51] 				= "true",
		-- ACCOUNT-WIDE GAME SETTINGS
		[KELA_SETTING_PANEL_ACCOUNT_SYNC_COMBAT] 				= "false",
		[KELA_SETTING_PANEL_ACCOUNT_SYNC_CAMERA] 				= "false",
		[KELA_SETTING_PANEL_ACCOUNT_SYNC_INTERFACE] 			= "false",
		[KELA_SETTING_PANEL_ACCOUNT_SYNC_NAMEPLATES] 			= "false",
		[KELA_SETTING_PANEL_ACCOUNT_SYNC_SOCIAL] 				= "false",
		-- ACTION BAR
		[KELA_SETTING_PANEL_ACTIONBAR_ENABLED] 				= "false",
		[KELA_SETTING_PANEL_ACTIONBAR_STACKS] 				= "true",
		[KELA_SETTING_PANEL_ACTIONBAR_ALWAYS_SHOW] 			= "false",
		[KELA_SETTING_PANEL_ACTIONBAR_EXPIRY_WARNING] 		= "3",
		[KELA_SETTING_PANEL_ACTIONBAR_RAISE] 				= "10",
		[KELA_SETTING_PANEL_ACTIONBAR_BAR] 					= "true",
		[KELA_SETTING_PANEL_ACTIONBAR_SECONDS] 				= "false",
		[KELA_SETTING_PANEL_ACTIONBAR_RESOURCE_SHIFT] 		= "0",
		[KELA_SETTING_PANEL_ACTIONBAR_HEALTH_RAISE] 		= "0",
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
	-- Reset loads the shipped defaults into the working copy only; leaving the
	-- options saves it, so reload-gated toggles changed by the reset still
	-- prompt. The stored ZO_SavedVars defaults can predate a changed default.
	if whatDo == KELA_LOAD_DEFAULT then
		for system, defaults in pairs(KELA_SETTINGS_DEFAULTS) do
			kpuiSVSettingsCurrent[system] = KelaGetTableCopy(defaults)
		end
		return
	end
	if IsSettingsDirty(KELA_SETTINGS_DIRTY) or IsSettingsDirty(KELA_SETTINGS_DIRTY_DEFAULT) then 
		if whatDo == KELA_SAVE_CURRENT then
			kpuiSavedVariables["settingsAccountWide"] = kpuiSVSettingsCurrent
		end
		if whatDo == KELA_RESTORE_SAVED then
			kpuiSavedVariables["settingsAccountWide"] = kpuiSVSettingsSaved
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
		KelaRequestGuildATTStatUpdate()
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
    -- A slider's `changedEvent` fires whenever its value actually changes, so a
    -- feature can preview the change while the menu is open.
    if data.changedEvent and tonumber(oldValueString) ~= formattedValue then
        CALLBACK_MANAGER:FireCallbacks(data.changedEvent)
    end


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
    [OPTIONS_CHECKBOX] = function(control)
                                local currentChoice = KelaGetSettingFromControl(control)
                                local checkBoxControl = GetControl(control, "Checkbox")
                                ZO_CheckButton_SetCheckState(checkBoxControl, currentChoice)
                                local enabled = KelaIsSettingEnabled(control.data)
								if not enabled then
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
            self:RefreshOptionsList()
            self:RefreshHeader()
            self:SetCurrentList(self.optionsList)
            KEYBIND_STRIP:AddKeybindButtonGroup(self.optionsKeybindDescriptor)
        elseif newState == SCENE_HIDDEN then
            self:DeactivateSelectedControl()
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.optionsKeybindDescriptor)
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.primaryActionDescriptor)
            self:SaveCachedSettings()
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

end

function Kela_GamepadOptions:InitializeOptionsLists()
    self.optionsList = self:GetMainList()
    self:SetupOptionsList(self.optionsList)
end

do
    local CONTROL_TYPES_WITH_PRIMARY_ACTION =
    {
        [OPTIONS_CHECKBOX] = true,
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

    -- Each group lists its add-ons under a heading, with a colored status that is
    -- read every time the tooltip is drawn. `good` is the status that lets the
    -- setting work: installed, or (for a conflict) not loaded.
    local ADDON_GROUPS =
    {
        { key = "required", header = KELA_SETTING_ADDON_REQUIRES, missingColor = kpuiConst.Colors.COLOR_LIGHT_RED },
        { key = "oneOf", header = KELA_SETTING_ADDON_REQUIRES_ONE },
        { key = "optional", header = KELA_SETTING_ADDON_OPTIONAL, missingColor = kpuiConst.Colors.COLOR_OFF_WHITE },
        { key = "conflicts", header = KELA_SETTING_ADDON_CONFLICTS, isConflict = true },
    }

    local function GetAddOnStatusText(addons)
        local lines = {}
        for _, group in ipairs(ADDON_GROUPS) do
            local list = addons[group.key]
            if list and #list > 0 then
                local missingColor = group.missingColor
                if group.key == "oneOf" then
                    -- Missing entries are fine while another one is loaded.
                    local anyLoaded = false
                    for _, addon in ipairs(list) do
                        anyLoaded = anyLoaded or addon.isLoaded()
                    end
                    missingColor = anyLoaded and kpuiConst.Colors.COLOR_OFF_WHITE or kpuiConst.Colors.COLOR_LIGHT_RED
                end
                lines[#lines + 1] = GetString(group.header) .. ":"
                for _, addon in ipairs(list) do
                    local isLoaded = addon.isLoaded()
                    local statusText
                    if group.isConflict then
                        statusText = isLoaded
                            and kpuiConst.Colors.COLOR_LIGHT_RED:Colorize(GetString(KELA_SETTING_ADDON_LOADED))
                            or kpuiConst.Colors.COLOR_LIGHT_GREEN:Colorize(GetString(KELA_SETTING_ADDON_NOT_LOADED))
                    elseif isLoaded then
                        statusText = kpuiConst.Colors.COLOR_LIGHT_GREEN:Colorize(GetString(KELA_SETTING_ADDON_FOUND))
                    else
                        statusText = missingColor:Colorize(GetString(KELA_SETTING_ADDON_NOT_FOUND))
                    end
                    lines[#lines + 1] = addon.name .. ": " .. statusText
                end
            end
        end
        if #lines == 0 then
            return nil
        end
        return table.concat(lines, "\n")
    end

    local function GetSettingInfoText(data)
        local lines = {}

        if data.addons then
            local addonText = GetAddOnStatusText(data.addons)
            if addonText then
                lines[#lines + 1] = addonText
                lines[#lines + 1] = ""
            end
        end

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
			if CONTROL_TYPES_WITH_PRIMARY_ACTION[controlType] and KelaIsSettingEnabled(control.data) then
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
        elseif type(data.tooltipText) == "function" then
            tooltipText = data.tooltipText(data)
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
    local enabled = KelaIsSettingEnabled(control.data)

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
    end
end

local function KelaOptionsCheckBox_SelectChoice(control, boxIsChecked)
    local data = control.data
    KelaSetSettingFromControl(control, boxIsChecked)
    Kela_Options_UpdateOption(control)
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
        slider:SetActive(selected and KelaIsSettingEnabled(control.data))
    end

    data.events = nil -- Sliders don't support events
end
function Kela_GamepadOptions:InitializeControl(control, selected)
    local label = control:GetNamedChild("Name")

    -- Determine if this control should be disabled because of a dependency
    if control.data.gamepadIsEnabledCallback then
        control.data.enabled = control.data.gamepadIsEnabledCallback()
    end
    SetSelectedStateOnControl(control, selected)
	
	-- Kela settings only use checkboxes and sliders.
	local data = control.data
	local text
	if type(data.text) == "function" then
		text = data.text(control)
	else
		text = GetTextEntry(data.text)
	end
	control.optionsManager = ZO_SharedOptions
	local controlType = ZO_SharedOptions:GetControlTypeFromControl(control)
	if controlType == OPTIONS_CHECKBOX then
		label:SetText(text)
		Kela_Options_SetupCheckBox(control)
	elseif controlType == OPTIONS_SLIDER then
		label:SetText(text)
		Kela_Options_SetupSlider(control, selected)
	end

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
    [OPTIONS_SLIDER] = "ZO_GamepadOptionsSliderRow",
    [OPTIONS_CHECKBOX] = "ZO_GamepadOptionsCheckboxRow",
}

local KELA_SETTINGS_CATEGORY_ORDER =
{
    KELA_SETTING_PANEL_FEATURES,
    KELA_SETTING_PANEL_FIXES,
    KELA_SETTING_PANEL_ACCOUNT,
    KELA_SETTING_PANEL_ACTIONBAR,
    KELA_SETTING_PANEL_JOURNALS,
    KELA_SETTING_PANEL_TRADE,
}

function Kela_GamepadOptions:RefreshOptionsList()
    self.optionsList:Clear()
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
    KelaRegisterGamepadDialog("KELA_OPTIONS_RESET_TO_SAVED",
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

    KelaRegisterGamepadDialog("KELA_OPTIONS_RESET_TO_DEFAULTS",
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

    KelaRegisterGamepadDialog("KELA_OPTIONS_RELOAD_REQUIRED",
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
