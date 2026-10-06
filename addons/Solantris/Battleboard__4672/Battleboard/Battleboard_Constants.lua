-- Battleboard_Constants.lua  (namespace, static constants, exported helper table)
-- Part of Battleboard. Loaded before Core so later modules can bind constants and helpers.

Battleboard = Battleboard or {}
local BL = Battleboard
BL.__constants = BL.__constants or {}

local _x = BL.__constants

_x.LMM = LibMainMenu2
_x.LAM = LibAddonMenu2

_x.DEFAULT_SCENE_HISTORY = "BattleboardHistory"
_x.DEFAULT_SCENE_METRICS = "BattleboardMetrics"
_x.DEFAULT_SCENE_OBSERVATORY = "BattleboardObservatory"

_x.BG_ICON = "esoui/art/icons/class/gamepad/gp_class_dragonknight.dds"
_x.BG_ICON_DOWN = _x.BG_ICON
_x.BG_ICON_OVER = _x.BG_ICON

-- Page-tab icon states. The header tab swaps textures directly.
_x.MATCH_HISTORY_ICON          = "/esoui/art/crafting/sketches_tabicon_disabled.dds"
_x.MATCH_HISTORY_ICON_DOWN     = "/esoui/art/crafting/sketches_tabicon_down.dds"
_x.MATCH_HISTORY_ICON_OVER     = "/esoui/art/crafting/sketches_tabicon_disabled.dds"
_x.MATCH_HISTORY_ICON_SELECTED = "/esoui/art/crafting/sketches_tabicon_down.dds"

_x.STATS_ICON          = "/esoui/art/tradinghouse/tradinghouse_listings_tabicon_up.dds"
_x.STATS_ICON_DOWN     = "/esoui/art/tradinghouse/tradinghouse_listings_tabicon_down.dds"
_x.STATS_ICON_OVER     = "/esoui/art/tradinghouse/tradinghouse_listings_tabicon_up.dds"
_x.STATS_ICON_SELECTED = "/esoui/art/tradinghouse/tradinghouse_listings_tabicon_down.dds"

_x.OBSERVATORY_ICON      = "/esoui/art/tradinghouse/tradinghouse_browse_tabicon_disabled.dds"
_x.OBSERVATORY_ICON_DOWN = "/esoui/art/tradinghouse/tradinghouse_browse_tabicon_down.dds"
_x.OBSERVATORY_ICON_OVER = "/esoui/art/tradinghouse/tradinghouse_browse_tabicon_disabled.dds"

_x.MENU_ICON = "/esoui/art/battlegrounds/battlegrounds_tabicon_battlegrounds_up.dds"
_x.MENU_ICON_DOWN = "/esoui/art/battlegrounds/battlegrounds_tabicon_battlegrounds_down.dds"
_x.MENU_ICON_OVER = "/esoui/art/battlegrounds/battlegrounds_tabicon_battlegrounds_down.dds"
_x.BLANK_ICON = "/esoui/art/icons/heraldrycrests_misc_blank_01.dds"

_x.TEAM_ICON_FIRE_DRAKES = "/esoui/art/battlegrounds/battlegrounds_teamicon_orange_64.dds"
_x.TEAM_ICON_PIT_DAEMONS = "/esoui/art/battlegrounds/battlegrounds_teamicon_green_64.dds"
_x.TEAM_ICON_STORM_LORDS = "/esoui/art/battlegrounds/battlegrounds_teamicon_purple_64.dds"

_x.PLAYER_TABLE_TEAM_ICON_FIRE_DRAKES = "/esoui/art/battlegrounds/gamepad/gp_battlegrounds_teamicon_orange.dds"
_x.PLAYER_TABLE_TEAM_ICON_PIT_DAEMONS = "/esoui/art/battlegrounds/gamepad/gp_battlegrounds_teamicon_green.dds"
_x.PLAYER_TABLE_TEAM_ICON_STORM_LORDS = "/esoui/art/battlegrounds/gamepad/gp_battlegrounds_teamicon_purple.dds"

_x.OUTCOME_BANNER_RESULT_ICON_WIN = "/esoui/art/battlegrounds/battleground_spectate_green.dds"
_x.OUTCOME_BANNER_RESULT_ICON_LOSS = "/esoui/art/battlegrounds/battleground_spectate_orange.dds"
_x.OUTCOME_BANNER_RESULT_ICON_TIE = "/esoui/art/battlegrounds/battleground_spectate_purple.dds"

_x.TEAM_INDICATOR_BANNER_FIRE_DRAKES = "/esoui/art/battlegrounds/battlegrounds_teamicon_orange_64.dds"
_x.TEAM_INDICATOR_BANNER_PIT_DAEMONS = "/esoui/art/battlegrounds/battlegrounds_teamicon_green_64.dds"
_x.TEAM_INDICATOR_BANNER_STORM_LORDS = "/esoui/art/battlegrounds/battlegrounds_teamicon_purple_64.dds"

_x.PLAYER_TABLE_TEAM_HEADER_ICON = "/esoui/art/battlegrounds/battlegrounds_scoreicon_tie_three_way.dds"
_x.SORT_ICON_UP   = "/esoui/art/miscellaneous/list_sortheader_icon_neutral.dds"
_x.SORT_ICON_DOWN = "/esoui/art/miscellaneous/list_sortheader_icon_neutral.dds"

_x.ALL_CHARACTERS_KEY = "__ALL__"
_x.MAX_LOCKED_MATCHES = 20
_x.MAX_SCOREBOARD_PLAYERS = 18

_x.classIcons = {
    [1] = "esoui/art/icons/class/gamepad/gp_class_dragonknight.dds",
    [2] = "esoui/art/icons/class/gamepad/gp_class_sorcerer.dds",
    [3] = "esoui/art/icons/class/gamepad/gp_class_nightblade.dds",
    [4] = "esoui/art/icons/class/gamepad/gp_class_warden.dds",
    [5] = "esoui/art/icons/class/gamepad/gp_class_necromancer.dds",
    [6] = "esoui/art/icons/class/gamepad/gp_class_templar.dds",
    [117] = "esoui/art/icons/class/gamepad/gp_class_arcanist.dds",
}

_x.allianceOrder = {
    BATTLEGROUND_ALLIANCE_FIRE_DRAKES,
    BATTLEGROUND_ALLIANCE_PIT_DAEMONS,
    BATTLEGROUND_ALLIANCE_STORM_LORDS,
}

_x.allianceNames = {
    [BATTLEGROUND_ALLIANCE_FIRE_DRAKES] = "Fire Drakes",
    [BATTLEGROUND_ALLIANCE_PIT_DAEMONS] = "Pit Daemons",
    [BATTLEGROUND_ALLIANCE_STORM_LORDS] = "Storm Lords",
}

_x.allianceTeamIcons = {
    [BATTLEGROUND_ALLIANCE_FIRE_DRAKES] = _x.TEAM_ICON_FIRE_DRAKES,
    [BATTLEGROUND_ALLIANCE_PIT_DAEMONS] = _x.TEAM_ICON_PIT_DAEMONS,
    [BATTLEGROUND_ALLIANCE_STORM_LORDS] = _x.TEAM_ICON_STORM_LORDS,
}

_x.playerTableTeamIcons = {
    [BATTLEGROUND_ALLIANCE_FIRE_DRAKES] = _x.PLAYER_TABLE_TEAM_ICON_FIRE_DRAKES,
    [BATTLEGROUND_ALLIANCE_PIT_DAEMONS] = _x.PLAYER_TABLE_TEAM_ICON_PIT_DAEMONS,
    [BATTLEGROUND_ALLIANCE_STORM_LORDS] = _x.PLAYER_TABLE_TEAM_ICON_STORM_LORDS,
}

_x.teamIndicatorBanners = {
    [BATTLEGROUND_ALLIANCE_FIRE_DRAKES] = _x.TEAM_INDICATOR_BANNER_FIRE_DRAKES,
    [BATTLEGROUND_ALLIANCE_PIT_DAEMONS] = _x.TEAM_INDICATOR_BANNER_PIT_DAEMONS,
    [BATTLEGROUND_ALLIANCE_STORM_LORDS] = _x.TEAM_INDICATOR_BANNER_STORM_LORDS,
}

_x.allianceColours = {
    [BATTLEGROUND_ALLIANCE_FIRE_DRAKES] = {0.85, 0.40, 0.00},
    [BATTLEGROUND_ALLIANCE_PIT_DAEMONS] = {0.36, 0.60, 0.00},
    [BATTLEGROUND_ALLIANCE_STORM_LORDS] = {0.50, 0.30, 0.60},
}

_x.encounterClassOrder = {
    { key = 117, label = "Arcanist" },
    { key = 6, label = "Templar" },
    { key = 5, label = "Necromancer" },
    { key = 3, label = "Nightblade" },
    { key = 2, label = "Sorcerer" },
    { key = 1, label = "Dragon Knight" },
    { key = 4, label = "Warden" },
}

-- Detail table sizing lives here so BuildUI, ReflowDetailColumns, and RefreshDetails
-- all share the same values.
_x.DETAIL_TABLE_COLUMN_GAP = 6
_x.DETAIL_TABLE_WIDTH = 640
_x.DETAIL_PANEL_WIDTH_TRIM = 10
_x.DETAIL_TABLE_BODY_FONT = "ZoFontWinH5"

-- Shared scene layout values. The history column is pinned flush to the right.
_x.HISTORY_PANEL_WIDTH = 224
_x.HISTORY_SCROLLBAR_WIDTH = 6
_x.HISTORY_SCROLLBAR_GAP = 5
_x.HISTORY_CARD_AREA_WIDTH = _x.HISTORY_PANEL_WIDTH - _x.HISTORY_SCROLLBAR_WIDTH - _x.HISTORY_SCROLLBAR_GAP
_x.HISTORY_SCROLL_WIDTH = _x.HISTORY_CARD_AREA_WIDTH
_x.CONTENT_TOP = 44
_x.CONTENT_END = 805
_x.PAGE_ONE_FOOTER_HEIGHT = 30
_x.PAGE_ONE_PANEL_HEIGHT = 650
_x.HISTORY_VIEWPORT_HEIGHT = _x.PAGE_ONE_PANEL_HEIGHT
_x.DETAIL_PANEL_X = 0
_x.DETAIL_PANEL_WIDTH = _x.DETAIL_TABLE_WIDTH
_x.DETAIL_SEPARATOR_X = _x.DETAIL_PANEL_X + _x.DETAIL_PANEL_WIDTH + 10
_x.HISTORY_PANEL_X = _x.DETAIL_SEPARATOR_X + 8
_x.CONTENT_WIDTH = _x.HISTORY_PANEL_X + _x.HISTORY_PANEL_WIDTH + 55
_x.STRIP_WIDTH = _x.CONTENT_WIDTH
_x.PAGE_ONE_BOTTOM_Y = _x.CONTENT_TOP + _x.PAGE_ONE_PANEL_HEIGHT

_x.PAGE_TWO_PANEL_HEIGHT = _x.CONTENT_END - _x.CONTENT_TOP
_x.CONTENT_BOTTOM_Y = _x.CONTENT_END
_x.DATA_SUMMARY_STRIP_HEIGHT = 114
_x.DATA_SUMMARY_DIVIDER_GAP = 0
_x.DATA_CONTRIBUTION_PANEL_HEIGHT = 334

_x.PAGE_TAB_NORMAL_SIZE = 58
_x.PAGE_TAB_BASE_Y = 3
_x.PAGE_TAB_HOVER_OFFSET_Y = 0
_x.PAGE_TAB_GAP = 0

_x.columns = {
    {key="mvpIcon",        text="",          w=28,  sortable=false, align=TEXT_ALIGN_CENTER, skipCell=true, gap=2},
    {key="teamIcon",       text="",          w=30,  sortable=true, resetSort=true, align=TEXT_ALIGN_CENTER, kind="iconHeader", iconPath="/esoui/art/treeicons/achievements_indexicon_general_up.dds", skipCell=true},
    {key="classId",        text="",          w=30,  sortable=true, sortType="number", align=TEXT_ALIGN_CENTER, kind="classIcon", skipCell=true},
    {key="playerName",     text="Player",    w=265, sortable=true, sortType="text"},
    {key="score",   text="M", w=41, sortable=true, sortType="number", align=TEXT_ALIGN_CENTER},
    {key="kills",   text="K", w=41, sortable=true, sortType="number", align=TEXT_ALIGN_CENTER},
    {key="deaths",  text="D", w=41, sortable=true, sortType="number", align=TEXT_ALIGN_CENTER},
    {key="assists", text="A", w=41, sortable=true, sortType="number", align=TEXT_ALIGN_CENTER},
    {key="damage",  text="", w=41, sortable=true, sortType="number", align=TEXT_ALIGN_CENTER, kind="iconHeader", iconPath="/esoui/art/addons/gamepad/gp_mod_listing_category_combat.dds"},
    {key="healing", text="", w=41, sortable=true, sortType="number", align=TEXT_ALIGN_CENTER, kind="iconHeader", iconPath="/esoui/art/lfg/gamepad/lfg_roleicon_healer_down.dds"},
    {key="kd",      text="KD", w=41, sortable=true, sortType="number", align=TEXT_ALIGN_CENTER},
}
