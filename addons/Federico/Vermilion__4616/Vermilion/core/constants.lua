Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Constants = {
  ADDON_NAME    = "Vermilion",
  VERSION       = "2.0.0",
  SLASH_COMMAND = "/vermilion",

  DEV           = false,
  MODE          = "",
  DEBUG         = false,

  PIXEL_GRID      = true,
  GRAPH_DEFAULT_W = 718,
  GRAPH_DEFAULT_H = 472,
  GRAPH_MIN_W     = 500,
  GRAPH_MIN_H     = 240,

  SV_TABLE   = "VermilionSavedVars",
  SV_VERSION = 1,

  PROBE = {
    SRC_DAMAGE_OUT      = "Vermilion_DamageOut",
    SRC_SHIELD_OUT      = "Vermilion_ShieldOut",
    SRC_COMBAT_STATE    = "Vermilion_CombatState",
    SRC_CAST            = "Vermilion_Cast",
    SRC_PLAYER          = "Vermilion_PlayerActivated",
    SRC_AUTOSAVE        = "Vermilion_AutoSave",

    BUFFER_LIMIT = 200,

    CHAT_INTERVAL_MS = 250,

    DUMP_HISTORY_LIMIT = 5,

    AUTOSAVE_COOLDOWN_MS = 30000,
  },

  TEMPORAL = {
    UPDATE_NAME          = "VermilionTemporalSample",
    SAMPLE_RATE_DEFAULT  = 1000,
    CAPACITY             = 1800,
    LIVE_WINDOW_S        = 60,
  },

  METRICS = {
    DAMAGE_WINDOW_MS = 5000,
    SHIELD_WINDOW_MS = 5000,
  },

  POOL = {
    EVENT_CAPACITY = 4096,
  },

  -- GC pacing (ported from Verditer): drive a little GC each frame so the incremental
  -- collector never bursts into a render-frame hitch. STEP_KB = step size; INTERVAL_MS
  -- 0 = every frame. PACING=false disables (A/B).
  GC = {
    PACING      = true,
    STEP_KB     = 2,
    INTERVAL_MS = 0,
  },

  ABILITY_KIND = {
    DAMAGE_OUT = 1,   -- this is (eDPS)
    SHIELD_OUT = 2,   -- (ShDPS)
  },

  PROFILER_BUDGETS_MS = {
    ["pipeline.combat_event"]             = 5.0,
    ["pipeline.combat_event.acquisition"] = 2.0,
    ["pipeline.combat_event.filter"]      = 2.0,
    ["pipeline.combat_event.processing"]  = 3.0,
    ["pipeline.render_tick"]              = 10.0,
    ["graph.sample_tick"]                 = 15.0,
    ["viz.spans"]                         = 2.0,
    ["viz.stems"]                         = 1.0,
    ["viz.scatter"]                       = 1.0,
    ["viz.ring"]                          = 0.5,
    ["graph.record_start"]                = 10.0,
    ["graph.record_stop"]                 = 25.0,
    ["VermilionGCStep"]                   = 3.0,
    ["VermilionAutosave"]                 = 8.0,
  },
}

Vermilion.Constants.DEBUG = (Vermilion.Constants.DEV == true and Vermilion.Constants.MODE == "DEBUG")
