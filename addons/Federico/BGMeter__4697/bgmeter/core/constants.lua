
BGMeter = BGMeter or {}
local BGMeter = BGMeter

local K = {}

K.ADDON_NAME = "bgmeter"
K.TITLE      = "BGmeter"
K.LOGO       = "bgmeter/assets/launcher.dds"
K.VERSION    = "0.6.1"
K.SAVED_VARS = "BGMeterSavedVars"
K.SLASH      = "/bgmeter"

K.DEBUG = false
K.MODE  = ""

function K.dev_tools()
    return K.DEBUG == true and K.MODE == "DEBUG"
end

K.COLOR = {
    bg          = { 0.04, 0.04, 0.05, 0.92 },
    panel       = { 0.08, 0.08, 0.10, 0.95 },
    text        = { 0.90, 0.90, 0.92, 1.0 },
    text_dim    = { 0.55, 0.55, 0.60, 1.0 },
    accent      = { 0.89, 0.26, 0.20, 1.0 },
    heal        = { 0.30, 0.78, 0.45, 1.0 },
    gold        = { 0.95, 0.80, 0.35, 1.0 },
    veterancy   = { 0.55, 0.50, 0.95, 1.0 },
    you         = { 1.00, 0.90, 0.55, 1.0 },
    face_with   = { 0.45, 0.80, 0.55, 1.0 },
    face_vs     = { 0.90, 0.40, 0.38, 1.0 },
    face_mixed  = { 0.62, 0.62, 0.68, 1.0 },
    medal       = { 0.95, 0.80, 0.35, 1.0 },
    team = {
        fire   = { 0.92, 0.48, 0.22, 1.0 },
        pit    = { 0.45, 0.82, 0.35, 1.0 },
        storm  = { 0.62, 0.46, 0.92, 1.0 },
    },
}

K.TEAM_ART = {
    fire  = "orange",
    pit   = "green",
    storm = "purple",
}

K.LAYOUT = {
    window_w   = 760,
    window_h   = 800,
    min_w      = 700,
    min_h      = 780,
    max_w      = 1240,
    max_h      = 980,
    row_h      = 28,
    margin     = 16,
    header_h   = 68,
    footer_h   = 32,
    gap        = 16,
    haul_w     = 220,
    resize_h   = 8,
    chart_h    = 96,
    pad        = 16,
    dyn_min_cap = 940,
    lane_h     = 12,
    lane_gap   = 8,
    ribbon_top = 20,
    pin_size   = 32,
    occ_h      = 48,
    race_h     = 48,
    kills_h    = 44,
    balance_h  = 50,
    map_h      = 560,
    map_w      = 760,
    map_min    = 280,
}

K.ALPHA = {
    map_art      = 0.24,
    score_art    = 0.22,
    footer_band  = 0.60,
    chart_bg     = 0.04,
    chart_edge   = 0.14,
    chart_grid   = 0.07,
    race_halo    = 0.18,
    race_fill    = 0.12,
    banner_glow  = 0.45,
    bar_fill     = 0.20,
    team_strip   = 0.85,
    row_hover    = 0.16,
    row_selected = 0.13,
    row_mvp      = 0.08,
    row_you      = 0.07,
    ribbon_fill    = 0.50,
    ribbon_neutral = 0.14,
}

K.ANIM = {
    window_fade_ms = 220,
    bar_ms         = 450,
    count_ms       = 520,
    pop_ms         = 460,
}

BGMeter.Constants = K
