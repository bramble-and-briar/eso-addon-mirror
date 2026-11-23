Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Constants = {
  ADDON_NAME    = "Verdant",
  VERSION       = "3.0.2",
  SLASH_COMMAND = "/verdant",

  DEV           = false,
  MODE          = "",
  DEBUG         = false,
  PIXEL_GRID    = true,
  GRAPH_DEFAULT_W = 718,
  GRAPH_DEFAULT_H = 472,
  GRAPH_MIN_W     = 500,
  GRAPH_MIN_H     = 240,
  GRAPH_MAX_W     = 1200,
  GRAPH_MAX_H     = 700,

  SV_TABLE   = "VerdantSavedVars",
  SV_VERSION = 1,

  ERRORS = {
    CATCH_ALL = 666,
    RANGES = {
      { from = 100, to = 199, area = "combat events" },
      { from = 200, to = 299, area = "effects and buffs" },
      { from = 300, to = 399, area = "group" },
      { from = 400, to = 499, area = "recording" },
      { from = 500, to = 599, area = "storage" },
      { from = 600, to = 699, area = "interface" },
      { from = 700, to = 799, area = "upkeep" },
      { from = 900, to = 999, area = "debug tools" },
    },
    CODES = {
      Verdant_E_HealOut       = 101,
      Verdant_E_ShieldAbs     = 102,
      Verdant_E_GroupDmg      = 103,

      Verdant_E_EffectPlayer  = 201,
      Verdant_E_WeaponPair    = 202,
      Verdant_E_EffectGroup   = 203,
      VerdantBuffWatch        = 211,
      Verdant_BuffOrigin      = 221,
      VerdantBuffCatalog      = 222,
      VerdantBuffCatalogDone  = 223,

      Verdant_E_Death         = 302,
      Verdant_E_DeathGroup    = 303,
      Verdant_E_GroupJ        = 304,
      Verdant_E_GroupL        = 305,
      Verdant_E_GroupU        = 306,
      Verdant_E_PlayerAct     = 307,

      Verdant_AR_Combat       = 401,
      Verdant_AR_Bosses       = 402,
      Verdant_AR_Zone         = 403,
      VerdantAutoRecTick      = 404,
      Verdant_AR_Start        = 405,
      Verdant_AR_Late         = 406,
      Verdant_AR_Keep         = 407,
      Verdant_E_UltPower      = 411,
      Verdant_E_UltUsed       = 412,
      Verdant_E_UltBars       = 413,
      Verdant_E_ResMag        = 414,
      Verdant_E_ResSta        = 415,
      Verdant_E_ResDeath      = 416,
      Verdant_E_CastUsed      = 417,
      Verdant_E_CastBlock     = 418,
      Verdant_E_Energize      = 419,
      VerdantTemporalSample   = 421,
      Verdant_ContentKind     = 431,

      VerdantAutosave         = 501,

      VerdantCardGuard        = 602,
      VerdantLightPoll        = 603,
      VerdantHoverPoll        = 604,
      VerdantSavingSpin       = 605,
      VerdantLibDisarm        = 606,
      VerdantLibPulse         = 607,
      VerdantSavePulse        = 608,
      VerdantRecPulse         = 609,
      Verdant_RecPanelAway    = 610,
      VerdantExportBuild      = 611,
      VerdantSliderDrag       = 612,
      Verdant_DropdownAway    = 613,
      VerdantFilmStripDrag    = 614,
      VerdantFilmStripHover   = 615,
      VerdantChartDrag        = 616,
      Verdant_ChartDragAway   = 617,
      VerdantLogLampPoll      = 618,
      Verdant_ColorPicked     = 619,

      VerdantGCStep           = 701,
      VerdantHitch            = 702,

      Verdant_Trace_CE        = 901,
      Verdant_Trace_EF        = 902,
      Verdant_Trace_CS        = 903,
      Verdant_Trace_DE        = 904,
      Verdant_Trace_WP        = 905,
      Verdant_Trace_BO        = 906,
      Verdant_Trace_GJ        = 908,
      Verdant_Trace_GL        = 909,
      Verdant_Trace_GU        = 910,
      Verdant_Trace_AU        = 911,
      Verdant_Trace_PU        = 912,
      Verdant_DiagTick        = 921,
      Verdant_CombatOut       = 931,
      Verdant_CombatIn        = 932,
      Verdant_ShieldRaw       = 933,
      Verdant_HealAbsorbed    = 934,
      Verdant_Effect          = 935,
      Verdant_EffectOnSelf    = 936,
      Verdant_CombatState     = 937,
      Verdant_Cast            = 938,
      Verdant_GroupJoined     = 939,
      Verdant_GroupLeft       = 940,
      Verdant_GroupUpdate     = 941,
      Verdant_PlayerActivated = 942,
      Verdant_BuffProbe       = 951,
      Verdant_AutoSave        = 943,
    },
  },

  PROBE = {

    SRC_COMBAT_OUT      = "Verdant_CombatOut",
    SRC_COMBAT_IN       = "Verdant_CombatIn",
    SRC_SHIELD_RAW      = "Verdant_ShieldRaw",
    SRC_HEAL_ABSORBED   = "Verdant_HealAbsorbed",
    SRC_EFFECT          = "Verdant_Effect",
    SRC_EFFECT_ON_SELF  = "Verdant_EffectOnSelf",
    SRC_COMBAT_STATE    = "Verdant_CombatState",
    SRC_CAST            = "Verdant_Cast",
    SRC_GROUP_J         = "Verdant_GroupJoined",
    SRC_GROUP_L         = "Verdant_GroupLeft",
    SRC_GROUP_U         = "Verdant_GroupUpdate",
    SRC_PLAYER          = "Verdant_PlayerActivated",
    SRC_AUTOSAVE        = "Verdant_AutoSave",


    BUFFER_LIMIT = 200,


    CHAT_INTERVAL_MS = 250,


    DUMP_HISTORY_LIMIT = 5,


    AUTOSAVE_COOLDOWN_MS = 30000,
  },

  TEMPORAL = {
    UPDATE_NAME          = "VerdantTemporalSample",
    SAMPLE_RATE_DEFAULT  = 1000,
    CAPACITY             = 1800,
    LIVE_WINDOW_S        = 60,
  },

  METRICS = {
    WINDOW_MS = 5000,
  },

  POOL = {
    EVENT_CAPACITY = 4096,
  },

  GC = {
    PACING      = true,
    STEP_KB     = 2,
    INTERVAL_MS = 0,
  },

  ABILITY_KIND = {
    HEAL         = 1,
    OVERHEAL     = 2,
    SHIELD       = 3,
    DAMAGE_GROUP = 4,
    RESTORE_MAG  = 5,
    RESTORE_STA  = 6,
  },

  PROFILER_BUDGETS_MS = {
    ["pipeline.combat_event"]            = 5.0,
    ["pipeline.effect"]                  = 2.0,
    ["pipeline.combat_event.acquisition"] = 2.0,
    ["pipeline.combat_event.filter"]     = 2.0,
    ["pipeline.combat_event.processing"] = 3.0,
    ["pipeline.render_tick"]             = 10.0,
    ["bar.refresh"]                      = 5.0,
    ["graph.sample_tick"]                = 15.0,
  },
}

Verdant.Constants.DEBUG = (Verdant.Constants.DEV == true and Verdant.Constants.MODE == "DEBUG")
