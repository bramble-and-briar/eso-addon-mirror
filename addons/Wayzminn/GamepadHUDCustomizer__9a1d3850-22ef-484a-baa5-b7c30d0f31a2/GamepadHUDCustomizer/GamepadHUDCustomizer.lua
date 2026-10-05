-- Gamepad HUD Customizer | Wayzmin + OpenAI
GamepadHUDCustomizer = GamepadHUDCustomizer or {}
local ADDON = GamepadHUDCustomizer
local L = ADDON.L

ADDON.name = "GamepadHUDCustomizer"
ADDON.displayName = L.ADDON_NAME
ADDON.author = "Wayzmin + OpenAI"
ADDON.version = "0.3.2"
ADDON.savedVarName = "GamepadHUDCustomizer_SV"

local DEFAULTS = {
    controllerStyle = "auto", -- auto / xbox / dualsense

    barsEnabled = true,
    barsWidth = 280,
    barsSpacing = 180,
    barsOffsetX = 0,
    barsOffsetY = -105,

    independentScaleEnabled = false,
    healthScaleEnabled = true,
    magickaScaleEnabled = true,
    staminaScaleEnabled = true,
    healthScalePercent = 100,
    magickaScalePercent = 100,
    staminaScalePercent = 100,

    combatTipsEnabled = true,
    combatTipsOffsetX = 0,
    combatTipsOffsetY = -340,
    combatTipsScaleEnabled = false,
    combatTipsScalePercent = 100,

    playerInteractionEnabled = true,
    playerInteractionOffsetX = 0,
    playerInteractionOffsetY = -285,
    playerInteractionScaleEnabled = false,
    playerInteractionScalePercent = 100,

    -- off / manual / auto
    refreshNameplatesMode = "manual",

    -- standard / transitions / disabled
    hpGainGlowMode = "standard",

    flatGamepadUI = false,
}

local BLANK_TEXTURE = "/esoui/art/icons/blank.dds"

-- Only gamepad-specific texture paths are redirected.
-- Shared keyboard/nameplate texture paths are deliberately not touched.
local SAFE_GAMEPAD_GLOSS_TEXTURES = {
    "esoui/art/unitattributevisualizer/gamepad/gp_targetbar_dynamic_leadingedge_gloss.dds",
    "esoui/art/unitattributevisualizer/gamepad/gp_targetbar_dynamic_fill_gloss.dds",

    "esoui/art/unitattributevisualizer/gamepad/gp_attributebar_small_fill_leadingedge_gloss.dds",
    "esoui/art/unitattributevisualizer/gamepad/gp_attributebar_small_fill_center_gloss.dds",
    "esoui/art/unitattributevisualizer/gamepad/gp_attributebar_dynamic_leadingedge_gloss.dds",
    "esoui/art/unitattributevisualizer/gamepad/gp_attributebar_dynamic_fill_gloss.dds",

    "esoui/art/miscellaneous/gamepad/gp_dynamicbar30_leadingedge_gloss.dds",
    "esoui/art/miscellaneous/gamepad/gp_dynamicbar_medium_leadingedge_gloss.dds",
    "esoui/art/miscellaneous/gamepad/gp_dynamicbar30_gloss.dds",
    "esoui/art/miscellaneous/gamepad/gp_dynamicbar_medium_gloss.dds",

    "esoui/art/miscellaneous/gamepad/gp_championbar_leadingedge_gloss.dds",
    "esoui/art/miscellaneous/gamepad/gp_championbar_fill_gloss.dds",
}

local BAR_INDEX_HEALTH = 1
local BAR_INDEX_SIEGE_HEALTH = 2
local BAR_INDEX_MAGICKA = 3
local BAR_INDEX_WEREWOLF = 4
local BAR_INDEX_STAMINA = 5
local BAR_INDEX_MOUNT_STAMINA = 6

local PRIMARY_BAR_INDICES = {
    BAR_INDEX_HEALTH,
    BAR_INDEX_MAGICKA,
    BAR_INDEX_STAMINA,
}

local previewState = {
    bars = false,
    combatTips = false,
    playerInteraction = false,
}

-- Visual-only redirects: engine gamepad queries and input bindings stay native.
-- Explicit semantic pairs from Baertram/FCOGamepadButtonTextures (main).
-- Missing/ambiguous PS5 resources are deliberately omitted; do not invent paths.
local BUTTON_TEXTURE_FAMILIES = { "xbox", "scarlett", "ps4", "ps5" }
local BUTTON_TEXTURE_LANGUAGES = { "en", "de", "fr", "jp", "ru" }
-- Columns: Xbox One, Xbox Series, PS4, PS5. %s denotes the SAME language
-- on both sides, including localized hold and hold_greyedout resources.
local BUTTON_TEXTURE_PAIRS = {
    { "console_art_xb1.dds", "console_art_xb1.dds", "console_art_ps4.dds", "console_art_ps5.dds" },
    { "nav_xbone_a.dds", "nav_scarlett_a.dds", "nav_ps4_x.dds", "nav_ps5_x.dds" },
    { "nav_xbone_a_hold.dds", "nav_scarlett_a_hold.dds", "nav_ps4_x_hold.dds", "nav_ps5_x_hold.dds" },
    { "nav_xbone_a_hold_%s.dds", "nav_scarlett_a_hold_%s.dds", "nav_ps4_x_hold_%s.dds", "nav_ps5_x_hold_%s.dds" },
    { "nav_xbone_a_hold_greyedout_%s.dds", "nav_scarlett_a_hold_greyedout_%s.dds", "nav_ps4_x_hold_greyedout_%s.dds", "nav_ps5_x_hold_greyedout_%s.dds" },
    { "nav_xbone_b.dds", "nav_scarlett_b.dds", "nav_ps4_circle.dds", "nav_ps5_circle.dds" },
    { "nav_xbone_b_hold.dds", "nav_scarlett_b_hold.dds", "nav_ps4_circle_hold.dds", "nav_ps5_circle_hold.dds" },
    { "nav_xbone_b_hold_%s.dds", "nav_scarlett_b_hold_%s.dds", "nav_ps4_circle_hold_%s.dds", "nav_ps5_circle_hold_%s.dds" },
    { "nav_xbone_b_hold_greyedout_%s.dds", "nav_scarlett_b_hold_greyedout_%s.dds", "nav_ps4_circle_hold_greyedout_%s.dds", "nav_ps5_circle_hold_greyedout_%s.dds" },
    { "nav_xbone_dpad.dds", "nav_scarlett_dpad.dds", "nav_ps4_dpad.dds", "nav_ps5_dpad.dds" },
    { "nav_xbone_dpad_down_hold.dds", "nav_scarlett_dpad_down_hold.dds", "nav_ps4_dpad_down_hold.dds", "nav_ps5_dpad_down_hold.dds" },
    { "nav_xbone_dpad_down_hold_%s.dds", "nav_scarlett_dpad_down_hold_%s.dds", "nav_ps4_dpad_down_hold_%s.dds", "nav_ps5_dpad_down_hold_%s.dds" },
    { "nav_xbone_dpad_down_hold_greyedout_%s.dds", "nav_scarlett_dpad_down_hold_greyedout_%s.dds", "nav_ps4_dpad_down_hold_greyedout_%s.dds", "nav_ps5_dpad_down_hold_greyedout_%s.dds" },
    { "nav_xbone_dpad_left_hold.dds", "nav_scarlett_dpad_left_hold.dds", "nav_ps4_dpad_left_hold.dds", "nav_ps5_dpad_left_hold.dds" },
    { "nav_xbone_dpad_left_hold_%s.dds", "nav_scarlett_dpad_left_hold_%s.dds", "nav_ps4_dpad_left_hold_%s.dds", "nav_ps5_dpad_left_hold_%s.dds" },
    { "nav_xbone_dpad_left_hold_greyedout_%s.dds", "nav_scarlett_dpad_left_hold_greyedout_%s.dds", "nav_ps4_dpad_left_hold_greyedout_%s.dds", "nav_ps5_dpad_left_hold_greyedout_%s.dds" },
    { "nav_xbone_dpad_right_hold.dds", "nav_scarlett_dpad_right_hold.dds", "nav_ps4_dpad_right_hold.dds", "nav_ps5_dpad_right_hold.dds" },
    { "nav_xbone_dpad_right_hold_%s.dds", "nav_scarlett_dpad_right_hold_%s.dds", "nav_ps4_dpad_right_hold_%s.dds", "nav_ps5_dpad_right_hold_%s.dds" },
    { "nav_xbone_dpad_right_hold_greyedout_%s.dds", "nav_scarlett_dpad_right_hold_greyedout_%s.dds", "nav_ps4_dpad_right_hold_greyedout_%s.dds", "nav_ps5_dpad_right_hold_greyedout_%s.dds" },
    { "nav_xbone_dpad_up_hold.dds", "nav_scarlett_dpad_up_hold.dds", "nav_ps4_dpad_up_hold.dds", "nav_ps5_dpad_up_hold.dds" },
    { "nav_xbone_dpad_up_hold_%s.dds", "nav_scarlett_dpad_up_hold_%s.dds", "nav_ps4_dpad_up_hold_%s.dds", "nav_ps5_dpad_up_hold_%s.dds" },
    { "nav_xbone_dpad_up_hold_greyedout_%s.dds", "nav_scarlett_dpad_up_hold_greyedout_%s.dds", "nav_ps4_dpad_up_hold_greyedout_%s.dds", "nav_ps5_dpad_up_hold_greyedout_%s.dds" },
    { "nav_xbone_dpaddown.dds", "nav_scarlett_dpaddown.dds", "nav_ps4_dpaddown.dds", "nav_ps5_dpaddown.dds" },
    { "nav_xbone_dpaddown_hold.dds", "nav_scarlett_dpaddown_hold.dds", "nav_ps4_dpaddown_hold.dds", "nav_ps5_dpaddown_hold.dds" },
    { "nav_xbone_dpaddown_hold_rs.dds", "nav_scarlett_dpaddown_hold_rs.dds", "nav_ps4_dpaddown_hold_rs.dds", "nav_ps5_dpaddown_hold_rs.dds" },
    { "nav_xbone_dpadleft.dds", "nav_scarlett_dpadleft.dds", "nav_ps4_dpadleft.dds", "nav_ps5_dpadleft.dds" },
    { "nav_xbone_dpadleft_hold.dds", "nav_scarlett_dpadleft_hold.dds", "nav_ps4_dpadleft_hold.dds", "nav_ps5_dpadleft_hold.dds" },
    { "nav_xbone_dpadright.dds", "nav_scarlett_dpadright.dds", "nav_ps4_dpadright.dds", "nav_ps5_dpadright.dds" },
    { "nav_xbone_dpadright_hold.dds", "nav_scarlett_dpadright_hold.dds", "nav_ps4_dpadright_hold.dds", "nav_ps5_dpadright_hold.dds" },
    { "nav_xbone_dpadrightb.dds", "nav_scarlett_dpadrightb.dds", "nav_ps4_dpadrightcircle.dds", "nav_ps5_dpadrightcircle.dds" },
    { "nav_xbone_dpadup.dds", "nav_scarlett_dpadup.dds", "nav_ps4_dpadup.dds", "nav_ps5_dpadup.dds" },
    { "nav_xbone_dpadup_hold.dds", "nav_scarlett_dpadup_hold.dds", "nav_ps4_dpadup_hold.dds", "nav_ps5_dpadup_hold.dds" },
    { "nav_xbone_hold_lt_press_rt.dds", "nav_scarlett_hold_lt_press_rt.dds", "nav_ps4_hold_l2_press_r2.dds", "nav_ps5_hold_l2_press_r2.dds" },
    { "nav_xbone_hold_lt_press_rt_%s.dds", "nav_scarlett_hold_lt_press_rt_%s.dds", "nav_ps4_hold_l2_press_r2_%s.dds", "nav_ps5_hold_l2_press_r2_%s.dds" },
    { "nav_xbone_lb.dds", "nav_scarlett_lb.dds", "nav_ps4_l1.dds", "nav_ps5_l1.dds" },
    { "nav_xbone_lb_hold.dds", "nav_scarlett_lb_hold.dds", "nav_ps4_l1_hold.dds", "nav_ps5_l1_hold.dds" },
    { "nav_xbone_lba.dds", "nav_scarlett_lba.dds", "nav_ps4_l1x.dds", "nav_ps5_l1x.dds" },
    { "nav_xbone_lbb.dds", "nav_scarlett_lbb.dds", "nav_ps4_l1circle.dds", "nav_ps5_l1circle.dds" },
    { "nav_xbone_lbdpaddown.dds", "nav_scarlett_lbdpaddown.dds", "nav_ps4_l1dpaddown.dds", "nav_ps5_l1dpaddown.dds" },
    { "nav_xbone_lbdpadleft.dds", "nav_scarlett_lbdpadleft.dds", "nav_ps4_l1dpadleft.dds", "nav_ps5_l1dpadleft.dds" },
    { "nav_xbone_lbrb.dds", "nav_scarlett_lbrb.dds", "nav_ps4_l1r1.dds", "nav_ps5_l1r1.dds" },
    { "nav_xbone_lbrs_press.dds", "nav_scarlett_lbrs_press.dds", "nav_ps4_l1rs_press.dds", "nav_ps5_l1rs_press.dds" },
    { "nav_xbone_lbrs_right.dds", "nav_scarlett_lbrs_right.dds", "nav_ps4_l1rs_right.dds", "nav_ps5_l1rs_right.dds" },
    { "nav_xbone_lbrt.dds", "nav_scarlett_lbrt.dds", "nav_ps4_l1r2.dds", "nav_ps5_l1r2.dds" },
    { "nav_xbone_lbx.dds", "nav_scarlett_lbx.dds", "nav_ps4_l1square.dds", "nav_ps5_l1square.dds" },
    { "nav_xbone_lby.dds", "nav_scarlett_lby.dds", "nav_ps4_l1triangle.dds", "nav_ps5_l1triangle.dds" },
    { "nav_xbone_left_shoulder_hold.dds", "nav_scarlett_left_shoulder_hold.dds", "nav_ps4_left_shoulder_hold.dds", "nav_ps5_left_shoulder_hold.dds" },
    { "nav_xbone_left_shoulder_hold_%s.dds", "nav_scarlett_left_shoulder_hold_%s.dds", "nav_ps4_left_shoulder_hold_%s.dds", "nav_ps5_left_shoulder_hold_%s.dds" },
    { "nav_xbone_left_shoulder_hold_greyedout_%s.dds", "nav_scarlett_left_shoulder_hold_greyedout_%s.dds", "nav_ps4_left_shoulder_hold_greyedout_%s.dds", "nav_ps5_left_shoulder_hold_greyedout_%s.dds" },
    { "nav_xbone_left_trigger_hold.dds", "nav_scarlett_left_trigger_hold.dds", "nav_ps4_left_trigger_hold.dds", "nav_ps5_left_trigger_hold.dds" },
    { "nav_xbone_left_trigger_hold_%s.dds", "nav_scarlett_left_trigger_hold_%s.dds", "nav_ps4_left_trigger_hold_%s.dds", "nav_ps5_left_trigger_hold_%s.dds" },
    { "nav_xbone_left_trigger_hold_greyedout_%s.dds", "nav_scarlett_left_trigger_hold_greyedout_%s.dds", "nav_ps4_left_trigger_hold_greyedout_%s.dds", "nav_ps5_left_trigger_hold_greyedout_%s.dds" },
    { "nav_xbone_leftarrowrightarrow.dds", "nav_scarlett_leftarrowrightarrow.dds", "nav_ps4_trackpadoptions.dds", "nav_ps5_trackpadoptions.dds" },
    { "nav_xbone_ls.dds", "nav_scarlett_ls.dds", "nav_ps4_ls.dds", "nav_ps5_ls.dds" },
    { "nav_xbone_ls_click.dds", "nav_scarlett_ls_click.dds", "nav_ps4_ls_click.dds", "nav_ps5_ls_click.dds" },
    { "nav_xbone_ls_down.dds", "nav_scarlett_ls_down.dds", "nav_ps4_ls_down.dds", "nav_ps5_ls_down.dds" },
    { "nav_xbone_ls_hold.dds", "nav_scarlett_ls_hold.dds", "nav_ps4_ls_hold.dds", "nav_ps5_ls_hold.dds" },
    { "nav_xbone_ls_hold_%s.dds", "nav_scarlett_ls_hold_%s.dds", "nav_ps4_ls_hold_%s.dds", "nav_ps5_ls_hold_%s.dds" },
    { "nav_xbone_ls_left.dds", "nav_scarlett_ls_left.dds", "nav_ps4_ls_left.dds", "nav_ps5_ls_left.dds" },
    { "nav_xbone_ls_press.dds", "nav_scarlett_ls_press.dds", "nav_ps4_ls_press.dds", "nav_ps5_ls_press.dds" },
    { "nav_xbone_ls_right.dds", "nav_scarlett_ls_right.dds", "nav_ps4_ls_right.dds", "nav_ps5_ls_right.dds" },
    { "nav_xbone_ls_scroll.dds", "nav_scarlett_ls_scroll.dds", "nav_ps4_ls_scroll.dds", "nav_ps5_ls_scroll.dds" },
    { "nav_xbone_ls_slide.dds", "nav_scarlett_ls_slide.dds", "nav_ps4_ls_slide.dds", "nav_ps5_ls_slide.dds" },
    { "nav_xbone_ls_slide_scroll.dds", "nav_scarlett_ls_slide_scroll.dds", "nav_ps4_ls_slide_scroll.dds", "nav_ps5_ls_slide_scroll.dds" },
    { "nav_xbone_ls_up.dds", "nav_scarlett_ls_up.dds", "nav_ps4_ls_up.dds", "nav_ps5_ls_up.dds" },
    { "nav_xbone_lsrs.dds", "nav_scarlett_lsrs.dds", "nav_ps4_lsrs.dds", "nav_ps5_lsrs.dds" },
    { "nav_xbone_lsrs_click.dds", "nav_scarlett_lsrs_click.dds", "nav_ps4_lsrs_click.dds", "nav_ps5_lsrs_click.dds" },
    { "nav_xbone_lsrs_press.dds", "nav_scarlett_lsrs_press.dds", "nav_ps4_lsrs_press.dds", "nav_ps5_lsrs_press.dds" },
    { "nav_xbone_lt.dds", "nav_scarlett_lt.dds", "nav_ps4_l2.dds", "nav_ps5_l2.dds" },
    { "nav_xbone_lt_dim.dds", "nav_scarlett_lt_dim.dds", "nav_ps4_l2_dim.dds", "nav_ps5_l2_dim.dds" },
    { "nav_xbone_lta.dds", "nav_scarlett_lta.dds", "nav_ps4_l2x.dds", "nav_ps5_l2x.dds" },
    { "nav_xbone_ltb.dds", "nav_scarlett_ltb.dds", "nav_ps4_l2circle.dds", "nav_ps5_l2circle.dds" },
    { "nav_xbone_ltrt.dds", "nav_scarlett_ltrt.dds", "nav_ps4_l2r2.dds", "nav_ps5_l2r2.dds" },
    { "nav_xbone_ltx.dds", "nav_scarlett_ltx.dds", "nav_ps4_l2square.dds", "nav_ps5_l2square.dds" },
    { "nav_xbone_lty.dds", "nav_scarlett_lty.dds", "nav_ps4_l2triangle.dds", "nav_ps5_l2triangle.dds" },
    { "nav_xbone_menu_button_hold.dds", "nav_scarlett_menu_button_hold.dds", "nav_ps4_options_hold.dds", "nav_ps5_options_hold.dds" },
    { "nav_xbone_menu_button_hold_%s.dds", "nav_scarlett_menu_button_hold_%s.dds", "nav_ps4_options_hold_%s.dds", "nav_ps5_options_hold_%s.dds" },
    { "nav_xbone_menu_button_hold_greyedout_%s.dds", "nav_scarlett_menu_button_hold_greyedout_%s.dds", "nav_ps4_options_hold_greyedout_%s.dds", "nav_ps5_options_hold_greyedout_%s.dds" },
    { "nav_xbone_rb.dds", "nav_scarlett_rb.dds", "nav_ps4_r1.dds", "nav_ps5_r1.dds" },
    { "nav_xbone_rba.dds", "nav_scarlett_rba.dds", "nav_ps4_r1x.dds", "nav_ps5_r1x.dds" },
    { "nav_xbone_rbb.dds", "nav_scarlett_rbb.dds", "nav_ps4_r1circle.dds", "nav_ps5_r1circle.dds" },
    { "nav_xbone_rbx.dds", "nav_scarlett_rbx.dds", "nav_ps4_r1square.dds", "nav_ps5_r1square.dds" },
    { "nav_xbone_rby.dds", "nav_scarlett_rby.dds", "nav_ps4_r1triangle.dds", "nav_ps5_r1triangle.dds" },
    { "nav_xbone_right_shoulder_hold.dds", "nav_scarlett_right_shoulder_hold.dds", "nav_ps4_right_shoulder_hold.dds", "nav_ps5_right_shoulder_hold.dds" },
    { "nav_xbone_right_shoulder_hold_%s.dds", "nav_scarlett_right_shoulder_hold_%s.dds", "nav_ps4_right_shoulder_hold_%s.dds", "nav_ps5_right_shoulder_hold_%s.dds" },
    { "nav_xbone_right_shoulder_hold_greyedout_%s.dds", "nav_scarlett_right_shoulder_hold_greyedout_%s.dds", "nav_ps4_right_shoulder_hold_greyedout_%s.dds", "nav_ps5_right_shoulder_hold_greyedout_%s.dds" },
    { "nav_xbone_right_trigger_hold.dds", "nav_scarlett_right_trigger_hold.dds", "nav_ps4_right_trigger_hold.dds", "nav_ps5_right_trigger_hold.dds" },
    { "nav_xbone_right_trigger_hold_%s.dds", "nav_scarlett_right_trigger_hold_%s.dds", "nav_ps4_right_trigger_hold_%s.dds", "nav_ps5_right_trigger_hold_%s.dds" },
    { "nav_xbone_right_trigger_hold_greyedout_%s.dds", "nav_scarlett_right_trigger_hold_greyedout_%s.dds", "nav_ps4_right_trigger_hold_greyedout_%s.dds", "nav_ps5_right_trigger_hold_greyedout_%s.dds" },
    { "nav_xbone_rs.dds", "nav_scarlett_rs.dds", "nav_ps4_rs.dds", "nav_ps5_rs.dds" },
    { "nav_xbone_rs_click.dds", "nav_scarlett_rs_click.dds", "nav_ps4_rs_click.dds", "nav_ps5_rs_click.dds" },
    { "nav_xbone_rs_down.dds", "nav_scarlett_rs_down.dds", "nav_ps4_rs_down.dds", "nav_ps5_rs_down.dds" },
    { "nav_xbone_rs_hold.dds", "nav_scarlett_rs_hold.dds", "nav_ps4_rs_hold.dds", "nav_ps5_rs_hold.dds" },
    { "nav_xbone_rs_hold_%s.dds", "nav_scarlett_rs_hold_%s.dds", "nav_ps4_rs_hold_%s.dds", "nav_ps5_rs_hold_%s.dds" },
    { "nav_xbone_rs_left.dds", "nav_scarlett_rs_left.dds", "nav_ps4_rs_left.dds", "nav_ps5_rs_left.dds" },
    { "nav_xbone_rs_press.dds", "nav_scarlett_rs_press.dds", "nav_ps4_rs_press.dds", "nav_ps5_rs_press.dds" },
    { "nav_xbone_rs_right.dds", "nav_scarlett_rs_right.dds", "nav_ps4_rs_right.dds", "nav_ps5_rs_right.dds" },
    { "nav_xbone_rs_scroll.dds", "nav_scarlett_rs_scroll.dds", "nav_ps4_rs_scroll.dds", "nav_ps5_rs_scroll.dds" },
    { "nav_xbone_rs_slide.dds", "nav_scarlett_rs_slide.dds", "nav_ps4_rs_slide.dds", "nav_ps5_rs_slide.dds" },
    { "nav_xbone_rs_slide_scroll.dds", "nav_scarlett_rs_slide_scroll.dds", "nav_ps4_rs_slide_scroll.dds", "nav_ps5_rs_slide_scroll.dds" },
    { "nav_xbone_rs_up.dds", "nav_scarlett_rs_up.dds", "nav_ps4_rs_up.dds", "nav_ps5_rs_up.dds" },
    { "nav_xbone_rt.dds", "nav_scarlett_rt.dds", "nav_ps4_r2.dds", "nav_ps5_r2.dds" },
    { "nav_xbone_rt_dim.dds", "nav_scarlett_rt_dim.dds", "nav_ps4_r2_dim.dds", "nav_ps5_r2_dim.dds" },
    { "nav_xbone_view.dds", "nav_scarlett_view.dds", "nav_ps4_trackpad_press.dds", "nav_ps5_trackpad_press.dds" },
    { "nav_xbone_view_button_hold.dds", "nav_scarlett_view_button_hold.dds", "nav_ps4_touchpad_hold.dds", "nav_ps5_touchpad_hold.dds" },
    { "nav_xbone_view_button_hold_%s.dds", "nav_scarlett_view_button_hold_%s.dds", "nav_ps4_touchpad_hold_%s.dds", "nav_ps5_touchpad_hold_%s.dds" },
    { "nav_xbone_view_button_hold_greyedout_%s.dds", "nav_scarlett_view_button_hold_greyedout_%s.dds", "nav_ps4_touchpad_hold_greyedout_%s.dds", "nav_ps5_touchpad_hold_greyedout_%s.dds" },
    { "nav_xbone_x.dds", "nav_scarlett_x.dds", "nav_ps4_square.dds", "nav_ps5_square.dds" },
    { "nav_xbone_x_hold.dds", "nav_scarlett_x_hold.dds", "nav_ps4_square_hold.dds", "nav_ps5_square_hold.dds" },
    { "nav_xbone_x_hold_%s.dds", "nav_scarlett_x_hold_%s.dds", "nav_ps4_square_hold_%s.dds", "nav_ps5_square_hold_%s.dds" },
    { "nav_xbone_x_hold_greyedout_%s.dds", "nav_scarlett_x_hold_greyedout_%s.dds", "nav_ps4_square_hold_greyedout_%s.dds", "nav_ps5_square_hold_greyedout_%s.dds" },
    { "nav_xbone_y.dds", "nav_scarlett_y.dds", "nav_ps4_triangle.dds", "nav_ps5_triangle.dds" },
    { "nav_xbone_y_hold.dds", "nav_scarlett_y_hold.dds", "nav_ps4_triangle_hold.dds", "nav_ps5_triangle_hold.dds" },
    { "nav_xbone_y_hold_%s.dds", "nav_scarlett_y_hold_%s.dds", "nav_ps4_triangle_hold_%s.dds", "nav_ps5_triangle_hold_%s.dds" },
    { "nav_xbone_y_hold_greyedout_%s.dds", "nav_scarlett_y_hold_greyedout_%s.dds", "nav_ps4_triangle_hold_greyedout_%s.dds", "nav_ps5_triangle_hold_greyedout_%s.dds" },
    { "nav_xbone_yb.dds", "nav_scarlett_yb.dds", "nav_ps4_trianglecircle.dds", "nav_ps5_trianglecircle.dds" },
    { "rightarrow_down.dds", "rightarrow_down.dds", "nav_ps4_options.dds", "nav_ps5_options.dds" },
}

local function BuildButtonTexturePaths(familyIndex)
    local base = "/esoui/art/buttons/gamepad/" .. BUTTON_TEXTURE_FAMILIES[familyIndex] .. "/"
    local paths = {}
    for _, pair in ipairs(BUTTON_TEXTURE_PAIRS) do
        local filename = pair[familyIndex]
        if filename:find("%s", 1, true) then
            for _, language in ipairs(BUTTON_TEXTURE_LANGUAGES) do
                paths[#paths + 1] = base .. string.format(filename, language)
            end
        else
            paths[#paths + 1] = base .. filename
        end
    end
    return paths
end

local ownedButtonRedirects = {}
local appliedControllerStyle
local function ApplyControllerButtonTextures()
    if not ADDON.sv or type(RedirectTexture) ~= "function" then return end
    local style = ADDON.sv.controllerStyle
    if style == appliedControllerStyle then return end

    -- Reset every redirect we own before choosing a new destination.
    -- This prevents Xbox -> PS5 -> Xbox redirect chains/cycles.
    for path in pairs(ownedButtonRedirects) do
        RedirectTexture(path, path)
    end
    ownedButtonRedirects = {}

    local targetFamily
    if style == "xbox" then
        targetFamily = 1
    elseif style == "dualsense" then
        targetFamily = 4
    end
    if targetFamily then
        local targetPaths = BuildButtonTexturePaths(targetFamily)
        for family in ipairs(BUTTON_TEXTURE_FAMILIES) do
            local sourcePaths = BuildButtonTexturePaths(family)
            for index, path in ipairs(sourcePaths) do
                if path ~= targetPaths[index] then
                    RedirectTexture(path, targetPaths[index])
                    ownedButtonRedirects[path] = true
                end
            end
        end
    end
    -- Auto leaves texture selection to ESO after undoing our redirects.
    appliedControllerStyle = style
end

local function GetBarControl(index)
    if not PLAYER_ATTRIBUTE_BARS or not PLAYER_ATTRIBUTE_BARS.bars then
        return nil
    end

    local bar = PLAYER_ATTRIBUTE_BARS.bars[index]
    return bar and bar.control or nil
end

local function SetControlWidth(control, width)
    if not control then
        return
    end

    local minWidth, minHeight, maxWidth, maxHeight = control:GetDimensionConstraints()

    -- Preserve the native height constraints while taking ownership of width only.
    control:SetDimensionConstraints(width, minHeight, width, maxHeight)
    control:SetWidth(width)

    local bg = control:GetNamedChild("BgContainer")
    if bg then
        local _, bgMinHeight, _, bgMaxHeight = bg:GetDimensionConstraints()
        bg:SetDimensionConstraints(width, bgMinHeight, width, bgMaxHeight)
        bg:SetWidth(width)
    end
end

local function ApplyAttributeBarWidth()
    if not ADDON.sv or not ADDON.sv.barsEnabled then
        return
    end

    local width = tonumber(ADDON.sv.barsWidth) or DEFAULTS.barsWidth

    for _, index in ipairs(PRIMARY_BAR_INDICES) do
        SetControlWidth(GetBarControl(index), width)
    end
end


local BAR_SCALE_GROUPS = {
    health = {
        BAR_INDEX_HEALTH,
        BAR_INDEX_SIEGE_HEALTH,
    },
    magicka = {
        BAR_INDEX_MAGICKA,
        BAR_INDEX_WEREWOLF,
    },
    stamina = {
        BAR_INDEX_STAMINA,
        BAR_INDEX_MOUNT_STAMINA,
    },
}

local function CaptureOriginalBarScale(index)
    ADDON.originalBarScales = ADDON.originalBarScales or {}

    if ADDON.originalBarScales[index] ~= nil then
        return ADDON.originalBarScales[index]
    end

    local control = GetBarControl(index)
    local scale = 1

    if control and control.GetScale then
        scale = control:GetScale()
    end

    ADDON.originalBarScales[index] = scale or 1
    return ADDON.originalBarScales[index]
end

local function ApplyScaleToGroup(groupName, enabled, percent)
    local indices = BAR_SCALE_GROUPS[groupName]
    if not indices then
        return
    end

    for _, index in ipairs(indices) do
        local control = GetBarControl(index)
        if control and control.SetScale then
            local originalScale = CaptureOriginalBarScale(index)
            local scale = originalScale

            if ADDON.sv.independentScaleEnabled and enabled then
                scale = originalScale * ((tonumber(percent) or 100) / 100)
            end

            control:SetScale(scale)
        end
    end
end

local function ApplyAttributeBarScale()
    if not ADDON.sv then
        return
    end

    ApplyScaleToGroup(
        "health",
        ADDON.sv.healthScaleEnabled,
        ADDON.sv.healthScalePercent
    )
    ApplyScaleToGroup(
        "magicka",
        ADDON.sv.magickaScaleEnabled,
        ADDON.sv.magickaScalePercent
    )
    ApplyScaleToGroup(
        "stamina",
        ADDON.sv.staminaScaleEnabled,
        ADDON.sv.staminaScalePercent
    )
end

local function ApplyAttributeBarPosition()
    if not ADDON.sv or not ADDON.sv.barsEnabled then
        return
    end

    local health = GetBarControl(BAR_INDEX_HEALTH)
    local magicka = GetBarControl(BAR_INDEX_MAGICKA)
    local stamina = GetBarControl(BAR_INDEX_STAMINA)

    if not health or not magicka or not stamina then
        return
    end

    local offsetX = tonumber(ADDON.sv.barsOffsetX) or DEFAULTS.barsOffsetX
    local offsetY = tonumber(ADDON.sv.barsOffsetY) or DEFAULTS.barsOffsetY
    local spacing = tonumber(ADDON.sv.barsSpacing) or DEFAULTS.barsSpacing

    -- The health bar becomes the independent root. It is anchored to GuiRoot,
    -- not to the action bar or to the HUD editor's resource frame.
    health:ClearAnchors()
    health:SetAnchor(CENTER, GuiRoot, BOTTOM, offsetX, offsetY)

    magicka:ClearAnchors()
    magicka:SetAnchor(RIGHT, health, LEFT, -spacing, 0)

    stamina:ClearAnchors()
    stamina:SetAnchor(LEFT, health, RIGHT, spacing, 0)

    -- Siege Health / Werewolf / Mount Stamina keep ESO's native anchors to their
    -- corresponding primary bar, so they automatically follow the new position.
end

local function ApplyAttributeBars()
    ApplyAttributeBarWidth()
    ApplyAttributeBarScale()
    ApplyAttributeBarPosition()
end

local function GetCombatTipControl()
    if ACTIVE_COMBAT_TIP_SYSTEM and ACTIVE_COMBAT_TIP_SYSTEM.tip then
        return ACTIVE_COMBAT_TIP_SYSTEM.tip
    end
    return ZO_ActiveCombatTipsTip
end

local function CaptureOriginalControlScale(key, control)
    ADDON.originalControlScales = ADDON.originalControlScales or {}

    if ADDON.originalControlScales[key] ~= nil then
        return ADDON.originalControlScales[key]
    end

    local scale = 1
    if control and control.GetScale then
        scale = control:GetScale() or 1
    end

    ADDON.originalControlScales[key] = scale
    return scale
end

local function ApplyCombatTipsScale()
    if not ADDON.sv then
        return
    end

    local tip = GetCombatTipControl()
    if not tip or not tip.SetScale then
        return
    end

    local originalScale = CaptureOriginalControlScale("combatTips", tip)
    local scale = originalScale
    if ADDON.sv.combatTipsScaleEnabled then
        scale = originalScale * ((tonumber(ADDON.sv.combatTipsScalePercent) or 100) / 100)
    end
    tip:SetScale(scale)
end

local function ApplyCombatTipsPosition()
    if not ADDON.sv or not ADDON.sv.combatTipsEnabled then
        return
    end

    local tip = GetCombatTipControl()
    if not tip then
        return
    end

    local x = tonumber(ADDON.sv.combatTipsOffsetX) or DEFAULTS.combatTipsOffsetX
    local y = tonumber(ADDON.sv.combatTipsOffsetY) or DEFAULTS.combatTipsOffsetY

    tip:ClearAnchors()
    tip:SetAnchor(BOTTOM, GuiRoot, BOTTOM, x, y)
end

local function ApplyCombatTipsLayout()
    ApplyCombatTipsScale()
    ApplyCombatTipsPosition()
end

local function GetPlayerInteractionControl()
    if ZO_PlayerToPlayerAreaPromptContainer then
        return ZO_PlayerToPlayerAreaPromptContainer
    end

    if ZO_PlayerToPlayerArea and ZO_PlayerToPlayerArea.GetNamedChild then
        return ZO_PlayerToPlayerArea:GetNamedChild("PromptContainer")
    end

    return nil
end

local function ApplyPlayerInteractionScale()
    if not ADDON.sv then
        return
    end

    local prompt = GetPlayerInteractionControl()
    if not prompt or not prompt.SetScale then
        return
    end

    local originalScale = CaptureOriginalControlScale("playerInteraction", prompt)
    local scale = originalScale
    if ADDON.sv.playerInteractionScaleEnabled then
        scale = originalScale * ((tonumber(ADDON.sv.playerInteractionScalePercent) or 100) / 100)
    end
    prompt:SetScale(scale)
end

local function ApplyPlayerInteractionPosition()
    if not ADDON.sv or not ADDON.sv.playerInteractionEnabled then
        return
    end

    local prompt = GetPlayerInteractionControl()
    if not prompt then
        return
    end

    local x = tonumber(ADDON.sv.playerInteractionOffsetX) or DEFAULTS.playerInteractionOffsetX
    local y = tonumber(ADDON.sv.playerInteractionOffsetY) or DEFAULTS.playerInteractionOffsetY

    prompt:ClearAnchors()
    prompt:SetAnchor(BOTTOM, GuiRoot, BOTTOM, x, y)
end

local function ApplyPlayerInteractionLayout()
    ApplyPlayerInteractionScale()
    ApplyPlayerInteractionPosition()
end

local function SetPlayerAttributeGlossHidden(hidden)
    if not PLAYER_ATTRIBUTE_BARS or not PLAYER_ATTRIBUTE_BARS.bars then
        return
    end

    for _, bar in ipairs(PLAYER_ATTRIBUTE_BARS.bars) do
        if bar.barControls then
            for _, subBar in ipairs(bar.barControls) do
                local gloss = subBar and subBar:GetNamedChild("Gloss")
                if gloss then
                    gloss:SetHidden(hidden)
                end
            end
        end
    end
end

local function ApplyFlatGamepadUI()
    if not ADDON.sv then
        return
    end

    local flat = ADDON.sv.flatGamepadUI == true

    if type(RedirectTexture) == "function" then
        for _, texture in ipairs(SAFE_GAMEPAD_GLOSS_TEXTURES) do
            RedirectTexture(texture, flat and BLANK_TEXTURE or texture)
        end
    end

    -- For player attributes, also hide the actual child controls. This is local to
    -- PLAYER_ATTRIBUTE_BARS and does not globally affect NPC/player nameplates.
    SetPlayerAttributeGlossHidden(flat)
end

-- --------------------------------------------------------------------------
-- Nameplate refresh workaround
-- --------------------------------------------------------------------------

local function RefreshNameplatesNow()
    if not ADDON.sv or ADDON.sv.refreshNameplatesMode == "off" then
        return false
    end

    if IsUnitInCombat and IsUnitInCombat("player") then
        ADDON.pendingNameplateRefresh = true
        d(L.CE6C35CGAMEPAD_HUD_CUSTOMIZER_R_NAMEPLATE_REFRESH_QUEUE)
        return false
    end

    if not GetSetting_Bool(SETTING_TYPE_NAMEPLATES, NAMEPLATE_TYPE_ALL_HEALTHBARS) then
        -- If health bars are intentionally disabled, there is nothing useful to refresh.
        return false
    end

    ADDON.pendingNameplateRefresh = false
    local originalValue = GetSetting(SETTING_TYPE_NAMEPLATES, NAMEPLATE_TYPE_ALL_HEALTHBARS)

    SetSetting(SETTING_TYPE_NAMEPLATES, NAMEPLATE_TYPE_ALL_HEALTHBARS, "false")
    zo_callLater(function()
        SetSetting(SETTING_TYPE_NAMEPLATES, NAMEPLATE_TYPE_ALL_HEALTHBARS, originalValue)
    end, 75)

    return true
end

-- --------------------------------------------------------------------------
-- Player Health gain-glow control
-- --------------------------------------------------------------------------

local HEALTH_GAIN_GLOW_SUPPRESS_MS = 500

local function GetPlayerHealthBarObject()
    if not PLAYER_ATTRIBUTE_BARS or not PLAYER_ATTRIBUTE_BARS.bars then
        return nil
    end
    return PLAYER_ATTRIBUTE_BARS.bars[BAR_INDEX_HEALTH]
end

local function SetHealthGainGlowNative()
    local healthBar = GetPlayerHealthBarObject()
    if not healthBar or not healthBar.barControls then
        return
    end

    local r, g, b, a = GetInterfaceColor(
        INTERFACE_COLOR_TYPE_POWER_FADE_IN,
        COMBAT_MECHANIC_FLAGS_HEALTH
    )

    for _, control in ipairs(healthBar.barControls) do
        if control and control.SetFadeOutGainColor then
            control:SetFadeOutGainColor(r, g, b, a)
        end
    end
end

local function SetHealthGainGlowHidden()
    local healthBar = GetPlayerHealthBarObject()
    if not healthBar or not healthBar.barControls then
        return
    end

    for _, control in ipairs(healthBar.barControls) do
        if control and control.SetFadeOutGainColor then
            control:SetFadeOutGainColor(0, 0, 0, 0)
        end
    end
end

local function ApplyHealthGainGlowMode()
    if not ADDON.sv then
        return
    end

    if ADDON.sv.hpGainGlowMode == "disabled" then
        ADDON.healthGainGlowSuppressed = true
        SetHealthGainGlowHidden()
    elseif ADDON.sv.hpGainGlowMode == "transitions" and ADDON.healthGainGlowSuppressed then
        SetHealthGainGlowHidden()
    else
        ADDON.healthGainGlowSuppressed = false
        SetHealthGainGlowNative()
    end
end

local function SuppressHealthGainGlowTemporarily()
    if not ADDON.sv or ADDON.sv.hpGainGlowMode ~= "transitions" then
        return
    end

    ADDON.healthGainGlowSuppressionToken = (ADDON.healthGainGlowSuppressionToken or 0) + 1
    local token = ADDON.healthGainGlowSuppressionToken
    ADDON.healthGainGlowSuppressed = true
    SetHealthGainGlowHidden()

    zo_callLater(function()
        if token ~= ADDON.healthGainGlowSuppressionToken then
            return
        end
        if ADDON.sv and ADDON.sv.hpGainGlowMode == "transitions" then
            ADDON.healthGainGlowSuppressed = false
            SetHealthGainGlowNative()
        end
    end, HEALTH_GAIN_GLOW_SUPPRESS_MS)
end


-- --------------------------------------------------------------------------
-- Player Health attribute-visualizer glow control
--
-- The bright white halo around the full Health bar is NOT the StatusBar
-- FadeOutGainColor effect. ESO's Unit Attribute Visualizer attaches separate
-- Increased Power / Unwavering effects to the player's Health control.
--
-- In "disabled" mode we suppress only those effects on PLAYER_ATTRIBUTE_BARS
-- Health. Target bars, NPC/player nameplates, damage shields and the other
-- attribute visualizer modules are left alone.
-- --------------------------------------------------------------------------

local function IsPlayerHealthControl(control)
    local healthBar = GetPlayerHealthBarObject()
    return healthBar and healthBar.control == control
end

local function StopAnimationInstantly(animation)
    if not animation then
        return
    end

    animation.instant = ANIMATION_INSTANT
    ZO_Animation_PlayBackwardOrInstantlyToStart(animation, ANIMATION_INSTANT)
end

local function StopExistingPlayerHealthAttributeGlows()
    if not PLAYER_ATTRIBUTE_BARS
        or not PLAYER_ATTRIBUTE_BARS.attributeVisualizer
        or not PLAYER_ATTRIBUTE_BARS.attributeVisualizer.visualModules
    then
        return
    end

    local healthControl = GetPlayerHealthBarObject()
    healthControl = healthControl and healthControl.control
    if not healthControl then
        return
    end

    for _, module in pairs(PLAYER_ATTRIBUTE_BARS.attributeVisualizer.visualModules) do
        -- Increased STAT_POWER glow.  The player bars create this module with
        -- ZO_IncreasedPowerGlowArrow as its glow template.
        if module.layoutData
            and module.layoutData.increasedPowerGlowTemplate == "ZO_IncreasedPowerGlowArrow"
            and module.barControls
            and module.barControls[STAT_POWER] == healthControl
            and module.barInfo
            and module.barInfo[STAT_POWER]
        then
            local info = module.barInfo[STAT_POWER]
            if info.currentAnimation then
                StopAnimationInstantly(info.currentAnimation)
                info.currentAnimation = nil
            end
            info.lastValue = info.value
        end

        -- Unwavering white overlay.  This is a separate visual from damage
        -- shielding and is also attached only to the player's Health bar here.
        if module.layoutData
            and module.layoutData.overlayContainerTemplate == "ZO_UnwaveringOverlayContainerArrow"
            and module.barControls
            and module.barControls[ATTRIBUTE_HEALTH] == healthControl
            and module.barInfo
            and module.barInfo[ATTRIBUTE_HEALTH]
        then
            local info = module.barInfo[ATTRIBUTE_HEALTH]
            if info.animation then
                StopAnimationInstantly(info.animation)
            end
            info.lastValue = info.value
        end
    end
end

local function InstallPlayerHealthAttributeGlowHooks()
    if ADDON.playerHealthAttributeGlowHooksInstalled then
        return
    end
    ADDON.playerHealthAttributeGlowHooksInstalled = true

    -- Increased Power: this is the broad white halo seen when STAT_POWER is
    -- increased.  ESO deliberately maps STAT_POWER visuals to healthBarControl.
    if ZO_UnitVisualizer_ArmorDamage and ZO_UnitVisualizer_ArmorDamage.OnValueChanged then
        ZO_PreHook(ZO_UnitVisualizer_ArmorDamage, "OnValueChanged",
            function(self, bar, info, stat, instant)
                if ADDON.sv
                    and ADDON.sv.hpGainGlowMode == "disabled"
                    and stat == STAT_POWER
                    and IsPlayerHealthControl(bar)
                then
                    if info.currentAnimation then
                        StopAnimationInstantly(info.currentAnimation)
                        info.currentAnimation = nil
                    end
                    info.lastValue = info.value
                    return true
                end
            end
        )
    end

    -- Unwavering is a different white overlay.  Suppress it as well only in the
    -- fully-disabled mode.  Damage-shield visuals are handled by another module
    -- and are intentionally untouched.
    if ZO_UnitVisualizer_UnwaveringModule and ZO_UnitVisualizer_UnwaveringModule.OnValueChanged then
        ZO_PreHook(ZO_UnitVisualizer_UnwaveringModule, "OnValueChanged",
            function(self, bar, info, instant)
                if ADDON.sv
                    and ADDON.sv.hpGainGlowMode == "disabled"
                    and IsPlayerHealthControl(bar)
                then
                    if info.animation then
                        StopAnimationInstantly(info.animation)
                    end
                    info.lastValue = info.value
                    return true
                end
            end
        )
    end
end

local function ApplyAllHUDSettings()
    if not IsInGamepadPreferredMode() then
        return
    end

    ApplyAttributeBars()
    ApplyCombatTipsLayout()
    ApplyPlayerInteractionLayout()
    ApplyFlatGamepadUI()
    ApplyHealthGainGlowMode()
    if ADDON.sv and ADDON.sv.hpGainGlowMode == "disabled" then
        StopExistingPlayerHealthAttributeGlows()
    end
end

-- --------------------------------------------------------------------------
-- Preview overlay
-- --------------------------------------------------------------------------

local function EnsurePreviewRoot()
    if ADDON.previewRoot then
        return
    end

    local wm = WINDOW_MANAGER

    local root = wm:CreateTopLevelWindow("GamepadHUDCustomizerPreviewRoot")
    root:SetAnchorFill(GuiRoot)
    root:SetDrawTier(DT_HIGH)
    root:SetDrawLayer(DL_OVERLAY)
    root:SetMouseEnabled(false)
    root:SetHidden(false)
    ADDON.previewRoot = root

    local function MakePromptBox(name, text)
        local box = wm:CreateControl(name, root, CT_BACKDROP)
        box:SetCenterColor(0.025, 0.025, 0.035, 0.88)
        box:SetEdgeColor(0.82, 0.86, 0.92, 0.88)
        box:SetEdgeTexture(nil, 1, 1, 1)
        box:SetMouseEnabled(false)
        box:SetHidden(true)

        local label = wm:CreateControl(name .. "Label", box, CT_LABEL)
        label:SetAnchor(CENTER)
        label:SetFont("ZoFontGamepad34")
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetText(text)
        label:SetColor(1, 1, 1, 1)

        box.label = label
        return box
    end

    local function MakeAttributeBar(name, labelText, r, g, b, fillPercent, compact)
        local bar = wm:CreateControl(name, root, CT_BACKDROP)
        bar:SetCenterColor(0.012, 0.012, 0.018, 0.94)
        bar:SetEdgeColor(0.68, 0.70, 0.76, 0.96)
        bar:SetEdgeTexture(nil, 1, 1, 1)
        bar:SetMouseEnabled(false)
        bar:SetHidden(true)

        local inner = wm:CreateControl(name .. "Inner", bar, CT_BACKDROP)
        inner:SetAnchor(TOPLEFT, bar, TOPLEFT, 3, 3)
        inner:SetAnchor(BOTTOMRIGHT, bar, BOTTOMRIGHT, -3, -3)
        inner:SetCenterColor(0.02, 0.02, 0.025, 0.92)
        inner:SetEdgeTexture(nil, 1, 1, 0)

        local fill = wm:CreateControl(name .. "Fill", inner, CT_BACKDROP)
        fill:SetAnchor(TOPLEFT, inner, TOPLEFT, 0, 0)
        fill:SetAnchor(BOTTOMLEFT, inner, BOTTOMLEFT, 0, 0)
        fill:SetCenterColor(r, g, b, 0.92)
        fill:SetEdgeTexture(nil, 1, 1, 0)

        local shadow = wm:CreateControl(name .. "Shadow", fill, CT_BACKDROP)
        shadow:SetAnchor(BOTTOMLEFT, fill, BOTTOMLEFT, 0, 0)
        shadow:SetAnchor(BOTTOMRIGHT, fill, BOTTOMRIGHT, 0, 0)
        shadow:SetHeight(compact and 4 or 7)
        shadow:SetCenterColor(0, 0, 0, 0.22)
        shadow:SetEdgeTexture(nil, 1, 1, 0)

        local gloss = wm:CreateControl(name .. "Gloss", fill, CT_BACKDROP)
        gloss:SetAnchor(TOPLEFT, fill, TOPLEFT, 0, 0)
        gloss:SetAnchor(TOPRIGHT, fill, TOPRIGHT, 0, 0)
        gloss:SetHeight(compact and 4 or 8)
        gloss:SetCenterColor(1, 1, 1, 0.10)
        gloss:SetEdgeTexture(nil, 1, 1, 0)

        local label = wm:CreateControl(name .. "Name", bar, CT_LABEL)
        label:SetAnchor(LEFT, bar, LEFT, compact and 8 or 12, 0)
        label:SetFont("ZoFontGamepad27")
        label:SetScale(compact and 0.68 or 0.82)
        label:SetText(labelText)
        label:SetColor(1, 1, 1, 0.96)

        local value = wm:CreateControl(name .. "Value", bar, CT_LABEL)
        value:SetAnchor(RIGHT, bar, RIGHT, compact and -8 or -12, 0)
        value:SetFont("ZoFontGamepad27")
        value:SetScale(compact and 0.62 or 0.78)
        value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        value:SetText(compact and "" or L.PREVIEW_82)
        value:SetColor(1, 1, 1, 0.92)

        bar.inner = inner
        bar.fill = fill
        bar.gloss = gloss
        bar.nameLabel = label
        bar.valueLabel = value
        bar.fillPercent = fillPercent or 0.82
        bar.compact = compact and true or false

        return bar
    end

    ADDON.previewHealth = MakeAttributeBar(
        "GamepadHUDCustomizerPreviewHealth",
        L.HEALTH,
        0.66, 0.08, 0.08,
        0.82,
        false
    )
    ADDON.previewMagicka = MakeAttributeBar(
        "GamepadHUDCustomizerPreviewMagicka",
        L.MAGICKA,
        0.08, 0.26, 0.68,
        0.70,
        false
    )
    ADDON.previewStamina = MakeAttributeBar(
        "GamepadHUDCustomizerPreviewStamina",
        L.STAMINA,
        0.12, 0.52, 0.16,
        0.91,
        false
    )

    ADDON.previewSiege = MakeAttributeBar(
        "GamepadHUDCustomizerPreviewSiege",
        L.SIEGE,
        0.62, 0.13, 0.08,
        0.64,
        true
    )
    ADDON.previewWerewolf = MakeAttributeBar(
        "GamepadHUDCustomizerPreviewWerewolf",
        L.WEREWOLF,
        0.44, 0.16, 0.58,
        0.76,
        true
    )
    ADDON.previewMount = MakeAttributeBar(
        "GamepadHUDCustomizerPreviewMount",
        L.MOUNT,
        0.55, 0.43, 0.08,
        0.58,
        true
    )

    ADDON.previewCombat = MakePromptBox(
        "GamepadHUDCustomizerPreviewCombat",
        L.BLOCK_INTERRUPT
    )
    ADDON.previewInteraction = MakePromptBox(
        "GamepadHUDCustomizerPreviewInteraction",
        L.PLAYER_NHOLD_TO_INTERACT
    )
end

local function UpdatePreviewBarVisual(bar, width, height, scale, flat)
    if not bar then
        return
    end

    bar:SetDimensions(width, height)
    bar:SetScale(scale or 1)

    local innerWidth = zo_max(1, width - 6)
    bar.fill:SetWidth(innerWidth * (bar.fillPercent or 0.82))
    bar.gloss:SetHidden(flat == true)
end

local function GetPreviewScale(enabled, percent)
    if not ADDON.sv or not ADDON.sv.independentScaleEnabled or not enabled then
        return 1
    end
    return (tonumber(percent) or 100) / 100
end

local function UpdateAttributePreview()
    EnsurePreviewRoot()

    local bars = {
        ADDON.previewHealth,
        ADDON.previewMagicka,
        ADDON.previewStamina,
        ADDON.previewSiege,
        ADDON.previewWerewolf,
        ADDON.previewMount,
    }

    for _, bar in ipairs(bars) do
        bar:SetHidden(not previewState.bars)
    end

    if not previewState.bars or not ADDON.sv then
        return
    end

    local width = tonumber(ADDON.sv.barsWidth) or DEFAULTS.barsWidth
    local spacing = tonumber(ADDON.sv.barsSpacing) or DEFAULTS.barsSpacing
    local x = tonumber(ADDON.sv.barsOffsetX) or DEFAULTS.barsOffsetX
    local y = tonumber(ADDON.sv.barsOffsetY) or DEFAULTS.barsOffsetY

    local healthScale = GetPreviewScale(
        ADDON.sv.healthScaleEnabled,
        ADDON.sv.healthScalePercent
    )
    local magickaScale = GetPreviewScale(
        ADDON.sv.magickaScaleEnabled,
        ADDON.sv.magickaScalePercent
    )
    local staminaScale = GetPreviewScale(
        ADDON.sv.staminaScaleEnabled,
        ADDON.sv.staminaScalePercent
    )

    local height = 38
    local smallHeight = 18
    local flat = ADDON.sv.flatGamepadUI == true

    UpdatePreviewBarVisual(ADDON.previewHealth, width, height, healthScale, flat)
    UpdatePreviewBarVisual(ADDON.previewMagicka, width, height, magickaScale, flat)
    UpdatePreviewBarVisual(ADDON.previewStamina, width, height, staminaScale, flat)

    ADDON.previewHealth:ClearAnchors()
    ADDON.previewHealth:SetAnchor(CENTER, GuiRoot, BOTTOM, x, y)

    ADDON.previewMagicka:ClearAnchors()
    ADDON.previewMagicka:SetAnchor(RIGHT, ADDON.previewHealth, LEFT, -spacing, 0)

    ADDON.previewStamina:ClearAnchors()
    ADDON.previewStamina:SetAnchor(LEFT, ADDON.previewHealth, RIGHT, spacing, 0)

    local smallWidth = zo_max(90, width * 0.72)

    UpdatePreviewBarVisual(ADDON.previewSiege, smallWidth, smallHeight, healthScale, flat)
    UpdatePreviewBarVisual(ADDON.previewWerewolf, smallWidth, smallHeight, magickaScale, flat)
    UpdatePreviewBarVisual(ADDON.previewMount, smallWidth, smallHeight, staminaScale, flat)

    ADDON.previewSiege:ClearAnchors()
    ADDON.previewSiege:SetAnchor(TOP, ADDON.previewHealth, BOTTOM, 0, -1)

    ADDON.previewWerewolf:ClearAnchors()
    ADDON.previewWerewolf:SetAnchor(TOPRIGHT, ADDON.previewMagicka, BOTTOMRIGHT, 0, -1)

    ADDON.previewMount:ClearAnchors()
    ADDON.previewMount:SetAnchor(TOPLEFT, ADDON.previewStamina, BOTTOMLEFT, 0, -1)
end

local function UpdateCombatPreview()
    EnsurePreviewRoot()

    ADDON.previewCombat:SetHidden(not previewState.combatTips)
    if not previewState.combatTips or not ADDON.sv then
        return
    end

    local real = GetCombatTipControl()
    local width = real and real:GetWidth() or 620
    local height = real and real:GetHeight() or 80
    if width <= 0 then width = 620 end
    if height <= 0 then height = 80 end

    ADDON.previewCombat:SetDimensions(width, height)
    local combatScale = 1
    if ADDON.sv.combatTipsScaleEnabled then
        combatScale = (tonumber(ADDON.sv.combatTipsScalePercent) or 100) / 100
    end
    ADDON.previewCombat:SetScale(combatScale)
    ADDON.previewCombat:ClearAnchors()
    ADDON.previewCombat:SetAnchor(
        BOTTOM,
        GuiRoot,
        BOTTOM,
        tonumber(ADDON.sv.combatTipsOffsetX) or DEFAULTS.combatTipsOffsetX,
        tonumber(ADDON.sv.combatTipsOffsetY) or DEFAULTS.combatTipsOffsetY
    )
end

local function GetInteractionPreviewText()
    local buttonText = nil

    if ZO_Keybindings_GetHighestPriorityBindingStringFromAction then
        buttonText = ZO_Keybindings_GetHighestPriorityBindingStringFromAction("PLAYER_TO_PLAYER_INTERACT")
    end

    if not buttonText or buttonText == "" then
        buttonText = L.INTERACTION_BUTTON_FALLBACK
    end

    return string.format(L.PLAYER_N_S_HOLD_TO_INTERACT, buttonText)
end

local function UpdateInteractionPreview()
    EnsurePreviewRoot()

    ADDON.previewInteraction:SetHidden(not previewState.playerInteraction)
    if not previewState.playerInteraction or not ADDON.sv then
        return
    end

    local real = GetPlayerInteractionControl()
    local width = real and real:GetWidth() or 870
    local height = real and real:GetHeight() or 90
    if width <= 0 then width = 870 end
    if height <= 0 then height = 90 end

    ADDON.previewInteraction:SetDimensions(width, height)
    local interactionScale = 1
    if ADDON.sv.playerInteractionScaleEnabled then
        interactionScale = (tonumber(ADDON.sv.playerInteractionScalePercent) or 100) / 100
    end
    ADDON.previewInteraction:SetScale(interactionScale)
    ADDON.previewInteraction.label:SetText(GetInteractionPreviewText())
    ADDON.previewInteraction:ClearAnchors()
    ADDON.previewInteraction:SetAnchor(
        BOTTOM,
        GuiRoot,
        BOTTOM,
        tonumber(ADDON.sv.playerInteractionOffsetX) or DEFAULTS.playerInteractionOffsetX,
        tonumber(ADDON.sv.playerInteractionOffsetY) or DEFAULTS.playerInteractionOffsetY
    )
end

local function RefreshPreviews()
    UpdateAttributePreview()
    UpdateCombatPreview()
    UpdateInteractionPreview()
end

local function SetPreview(kind, enabled)
    previewState[kind] = enabled and true or false
    RefreshPreviews()
end

local function HideAllPreviews()
    previewState.bars = false
    previewState.combatTips = false
    previewState.playerInteraction = false
    RefreshPreviews()
end

-- --------------------------------------------------------------------------
-- Runtime hooks
-- --------------------------------------------------------------------------

local function RefreshControllerStyle()
    ApplyControllerButtonTextures()
    if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
        KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
    end
    UpdateInteractionPreview()
end

local function InstallHooks()
    if ADDON.hooksInstalled then
        return
    end
    ADDON.hooksInstalled = true

    InstallPlayerHealthAttributeGlowHooks()

    if HUD_MANAGER and HUD_MANAGER.PropagateSettings then
        ZO_PostHook(HUD_MANAGER, "PropagateSettings", function()
            if IsInGamepadPreferredMode() then
                zo_callLater(ApplyAllHUDSettings, 0)
            end
        end)
    end

    if PLAYER_ATTRIBUTE_BARS then
        if PLAYER_ATTRIBUTE_BARS.ApplyStyle then
            ZO_PostHook(PLAYER_ATTRIBUTE_BARS, "ApplyStyle", function()
                if IsInGamepadPreferredMode() then
                    zo_callLater(function()
                        ApplyAttributeBars()
                        ApplyFlatGamepadUI()
                    end, 0)
                end
            end)
        end

        if PLAYER_ATTRIBUTE_BARS.OnScreenResized then
            ZO_PostHook(PLAYER_ATTRIBUTE_BARS, "OnScreenResized", function()
                if IsInGamepadPreferredMode() then
                    zo_callLater(ApplyAttributeBars, 0)
                end
            end)
        end
    end

    if ACTIVE_COMBAT_TIP_SYSTEM and ACTIVE_COMBAT_TIP_SYSTEM.ApplyStyle then
        ZO_PostHook(ACTIVE_COMBAT_TIP_SYSTEM, "ApplyStyle", function()
            if IsInGamepadPreferredMode() then
                zo_callLater(ApplyCombatTipsLayout, 0)
            end
        end)
    end

    EVENT_MANAGER:RegisterForEvent(
        ADDON.name .. "_PreferredMode",
        EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,
        function()
            zo_callLater(function()
                ApplyAllHUDSettings()
                RefreshControllerStyle()
                RefreshPreviews()
            end, 50)
        end
    )

    if EVENT_GAMEPAD_TYPE_CHANGED then
    EVENT_MANAGER:RegisterForEvent(
        ADDON.name .. "_GamepadType",
        EVENT_GAMEPAD_TYPE_CHANGED,
        function()
            RefreshControllerStyle()
            RefreshPreviews()
        end
    )
    end

    if EVENT_MOST_RECENT_GAMEPAD_TYPE_CHANGED then
    EVENT_MANAGER:RegisterForEvent(
        ADDON.name .. "_RecentGamepadType",
        EVENT_MOST_RECENT_GAMEPAD_TYPE_CHANGED,
        function()
            RefreshControllerStyle()
            RefreshPreviews()
        end
    )
    end

    local healthBar = GetPlayerHealthBarObject()
    if healthBar then
        if healthBar.OnPlayerActivated then
            ZO_PreHook(healthBar, "OnPlayerActivated", function()
                SuppressHealthGainGlowTemporarily()
            end)
        end

        if healthBar.RefreshColor then
            ZO_PostHook(healthBar, "RefreshColor", function()
                ApplyHealthGainGlowMode()
            end)
        end
    end

    EVENT_MANAGER:RegisterForEvent(
        ADDON.name .. "_WeaponPairChanged",
        EVENT_ACTIVE_WEAPON_PAIR_CHANGED,
        function()
            SuppressHealthGainGlowTemporarily()
        end
    )

    EVENT_MANAGER:RegisterForEvent(
        ADDON.name .. "_CombatState",
        EVENT_PLAYER_COMBAT_STATE,
        function(_, inCombat)
            if not inCombat and ADDON.pendingNameplateRefresh then
                zo_callLater(RefreshNameplatesNow, 100)
            end
        end
    )

    EVENT_MANAGER:RegisterForEvent(
        ADDON.name .. "_PlayerActivated",
        EVENT_PLAYER_ACTIVATED,
        function()
            zo_callLater(function()
                ApplyAllHUDSettings()
                RefreshControllerStyle()
                RefreshPreviews()
            end, 100)
        end
    )
end

-- --------------------------------------------------------------------------
-- Settings
-- --------------------------------------------------------------------------

local function RegisterSettings()
    local LAM = LibAddonMenu2
    local keyboardSupported = not IsKeyboardUISupported or IsKeyboardUISupported()
    if not keyboardSupported and not LibHarvensAddonSettings then LAM = nil end
    if not LAM then d(L.MENU_UNAVAILABLE) end

    local panelName = "GamepadHUDCustomizerOptions"

    local panelData = {
        type = "panel",
        name = ADDON.displayName,
        displayName = ADDON.displayName,
        author = ADDON.author,
        version = ADDON.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    if LAM then
        ADDON.settingsPanel = LAM:RegisterAddonPanel(panelName, panelData) or _G[panelName]
    end

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if not ADDON.settingsPanel or panel ~= ADDON.settingsPanel then
            return
        end

        HideAllPreviews()
        if ADDON.sv and ADDON.sv.refreshNameplatesMode == "auto" then
            zo_callLater(RefreshNameplatesNow, 150)
        end
    end)

    local controllerChoices = {
        L.AUTO,
        L.XBOX,
        L.DUALSENSE_PS5,
    }

    local controllerValues = {
        "auto",
        "xbox",
        "dualsense",
    }

    local options = {
        {
            type = "description",
            text = L.CUSTOMIZE_THE_GAMEPAD_HUD_ATTRIBUTE_BARS_PROMPTS_BUTTON,
        },

        {
            type = "header",
            name = L.CONTROLLER,
        },
        {
            type = "dropdown",
            name = L.BUTTON_ICONS,
            tooltip = L.SWITCH_XBOX_AND_PLAYSTATION_BUTTON_TEXTURES_INCLUDING_A,
            choices = controllerChoices,
            choicesValues = controllerValues,
            settingKey = "controllerStyle",
            getFunc = function()
                return ADDON.sv.controllerStyle
            end,
            setFunc = function(value)
                ADDON.sv.controllerStyle = value
                RefreshControllerStyle()
                RefreshPreviews()
            end,
            default = DEFAULTS.controllerStyle,
            width = "full",
        },
        {
            type = "button",
            name = L.RELOAD_UI,
            tooltip = L.REBUILD_THE_INTERFACE_RELOADING_THE_UI_MAY_NOT_CLEAR_RE,
            func = function()
                ReloadUI()
            end,
            width = "half",
        },

        {
            type = "header",
            name = L.HEALTH_MAGICKA_STAMINA,
        },
        {
            type = "checkbox",
            name = L.CUSTOM_POSITION_AND_SIZE,
            settingKey = "barsEnabled",
            getFunc = function()
                return ADDON.sv.barsEnabled
            end,
            setFunc = function(value)
                ADDON.sv.barsEnabled = value
                if value then
                    ApplyAttributeBars()
                end
                RefreshPreviews()
            end,
            default = DEFAULTS.barsEnabled,
            width = "full",
        },
        {
            type = "slider",
            name = L.BAR_WIDTH,
            min = 160,
            max = 600,
            step = 5,
            settingKey = "barsWidth",
            getFunc = function()
                return ADDON.sv.barsWidth
            end,
            setFunc = function(value)
                ADDON.sv.barsWidth = value
                ApplyAttributeBarWidth()
                RefreshPreviews()
            end,
            default = DEFAULTS.barsWidth,
            disabled = function()
                return not ADDON.sv.barsEnabled
            end,
            width = "full",
        },
        {
            type = "slider",
            name = L.SPACING_FROM_HEALTH_TO_MAGICKA_STAMINA,
            min = 0,
            max = 500,
            step = 5,
            settingKey = "barsSpacing",
            getFunc = function()
                return ADDON.sv.barsSpacing
            end,
            setFunc = function(value)
                ADDON.sv.barsSpacing = value
                ApplyAttributeBarPosition()
                RefreshPreviews()
            end,
            default = DEFAULTS.barsSpacing,
            disabled = function()
                return not ADDON.sv.barsEnabled
            end,
            width = "full",
        },
        {
            type = "slider",
            name = L.BAR_HORIZONTAL_POSITION,
            min = -1000,
            max = 1000,
            step = 5,
            settingKey = "barsOffsetX",
            getFunc = function()
                return ADDON.sv.barsOffsetX
            end,
            setFunc = function(value)
                ADDON.sv.barsOffsetX = value
                ApplyAttributeBarPosition()
                RefreshPreviews()
            end,
            default = DEFAULTS.barsOffsetX,
            disabled = function()
                return not ADDON.sv.barsEnabled
            end,
            width = "full",
        },
        {
            type = "slider",
            name = L.BAR_VERTICAL_POSITION,
            tooltip = L.NEGATIVE_VALUES_MOVE_THE_BARS_UP_FROM_THE_BOTTOM_OF_THE,
            min = -1000,
            max = 200,
            step = 5,
            settingKey = "barsOffsetY",
            getFunc = function()
                return ADDON.sv.barsOffsetY
            end,
            setFunc = function(value)
                ADDON.sv.barsOffsetY = value
                ApplyAttributeBarPosition()
                RefreshPreviews()
            end,
            default = DEFAULTS.barsOffsetY,
            disabled = function()
                return not ADDON.sv.barsEnabled
            end,
            width = "full",
        },
        {
            type = "header",
            name = L.INDEPENDENT_ATTRIBUTE_SCALING,
        },
        {
            type = "checkbox",
            name = L.ENABLE_INDEPENDENT_SCALING,
            tooltip = L.SCALE_HEALTH_MAGICKA_AND_STAMINA_SEPARATELY_SIEGE_HEALT,
            settingKey = "independentScaleEnabled",
            getFunc = function()
                return ADDON.sv.independentScaleEnabled
            end,
            setFunc = function(value)
                ADDON.sv.independentScaleEnabled = value
                ApplyAttributeBarScale()
                ApplyAttributeBarPosition()
                RefreshPreviews()
            end,
            default = DEFAULTS.independentScaleEnabled,
            width = "full",
        },
        {
            type = "checkbox",
            name = L.CUSTOM_HEALTH_SCALE,
            settingKey = "healthScaleEnabled",
            getFunc = function()
                return ADDON.sv.healthScaleEnabled
            end,
            setFunc = function(value)
                ADDON.sv.healthScaleEnabled = value
                ApplyAttributeBarScale()
                ApplyAttributeBarPosition()
                RefreshPreviews()
            end,
            default = DEFAULTS.healthScaleEnabled,
            disabled = function()
                return not ADDON.sv.independentScaleEnabled
            end,
            width = "half",
        },
        {
            type = "slider",
            name = L.HEALTH_SCALE,
            min = 50,
            max = 200,
            step = 5,
            settingKey = "healthScalePercent",
            getFunc = function()
                return ADDON.sv.healthScalePercent
            end,
            setFunc = function(value)
                ADDON.sv.healthScalePercent = value
                ApplyAttributeBarScale()
                ApplyAttributeBarPosition()
                RefreshPreviews()
            end,
            default = DEFAULTS.healthScalePercent,
            disabled = function()
                return not ADDON.sv.independentScaleEnabled or not ADDON.sv.healthScaleEnabled
            end,
            width = "half",
        },
        {
            type = "checkbox",
            name = L.CUSTOM_MAGICKA_SCALE,
            settingKey = "magickaScaleEnabled",
            getFunc = function()
                return ADDON.sv.magickaScaleEnabled
            end,
            setFunc = function(value)
                ADDON.sv.magickaScaleEnabled = value
                ApplyAttributeBarScale()
                ApplyAttributeBarPosition()
                RefreshPreviews()
            end,
            default = DEFAULTS.magickaScaleEnabled,
            disabled = function()
                return not ADDON.sv.independentScaleEnabled
            end,
            width = "half",
        },
        {
            type = "slider",
            name = L.MAGICKA_SCALE,
            min = 50,
            max = 200,
            step = 5,
            settingKey = "magickaScalePercent",
            getFunc = function()
                return ADDON.sv.magickaScalePercent
            end,
            setFunc = function(value)
                ADDON.sv.magickaScalePercent = value
                ApplyAttributeBarScale()
                ApplyAttributeBarPosition()
                RefreshPreviews()
            end,
            default = DEFAULTS.magickaScalePercent,
            disabled = function()
                return not ADDON.sv.independentScaleEnabled or not ADDON.sv.magickaScaleEnabled
            end,
            width = "half",
        },
        {
            type = "checkbox",
            name = L.CUSTOM_STAMINA_SCALE,
            settingKey = "staminaScaleEnabled",
            getFunc = function()
                return ADDON.sv.staminaScaleEnabled
            end,
            setFunc = function(value)
                ADDON.sv.staminaScaleEnabled = value
                ApplyAttributeBarScale()
                ApplyAttributeBarPosition()
                RefreshPreviews()
            end,
            default = DEFAULTS.staminaScaleEnabled,
            disabled = function()
                return not ADDON.sv.independentScaleEnabled
            end,
            width = "half",
        },
        {
            type = "slider",
            name = L.STAMINA_SCALE,
            min = 50,
            max = 200,
            step = 5,
            settingKey = "staminaScalePercent",
            getFunc = function()
                return ADDON.sv.staminaScalePercent
            end,
            setFunc = function(value)
                ADDON.sv.staminaScalePercent = value
                ApplyAttributeBarScale()
                ApplyAttributeBarPosition()
                RefreshPreviews()
            end,
            default = DEFAULTS.staminaScalePercent,
            disabled = function()
                return not ADDON.sv.independentScaleEnabled or not ADDON.sv.staminaScaleEnabled
            end,
            width = "half",
        },
        {
            type = "button",
            name = L.RESET_SCALING,
            func = function()
                ADDON.sv.independentScaleEnabled = DEFAULTS.independentScaleEnabled
                ADDON.sv.healthScaleEnabled = DEFAULTS.healthScaleEnabled
                ADDON.sv.magickaScaleEnabled = DEFAULTS.magickaScaleEnabled
                ADDON.sv.staminaScaleEnabled = DEFAULTS.staminaScaleEnabled
                ADDON.sv.healthScalePercent = DEFAULTS.healthScalePercent
                ADDON.sv.magickaScalePercent = DEFAULTS.magickaScalePercent
                ADDON.sv.staminaScalePercent = DEFAULTS.staminaScalePercent
                ApplyAttributeBarScale()
                ApplyAttributeBarPosition()
                RefreshPreviews()
            end,
            width = "half",
        },

        {
            type = "checkbox",
            name = L.PREVIEW_BARS,
            tooltip = L.SHOW_A_SAFE_OVERLAY_OF_ATTRIBUTE_BARS_AND_THE_RELATED_S,
            getFunc = function()
                return previewState.bars
            end,
            setFunc = function(value)
                SetPreview("bars", value)
            end,
            default = false,
            width = "full",
        },
        {
            type = "button",
            name = L.RESET_BARS,
            func = function()
                ADDON.sv.barsWidth = DEFAULTS.barsWidth
                ADDON.sv.barsSpacing = DEFAULTS.barsSpacing
                ADDON.sv.barsOffsetX = DEFAULTS.barsOffsetX
                ADDON.sv.barsOffsetY = DEFAULTS.barsOffsetY
                ADDON.sv.barsEnabled = DEFAULTS.barsEnabled
                ADDON.sv.independentScaleEnabled = DEFAULTS.independentScaleEnabled
                ADDON.sv.healthScaleEnabled = DEFAULTS.healthScaleEnabled
                ADDON.sv.magickaScaleEnabled = DEFAULTS.magickaScaleEnabled
                ADDON.sv.staminaScaleEnabled = DEFAULTS.staminaScaleEnabled
                ADDON.sv.healthScalePercent = DEFAULTS.healthScalePercent
                ADDON.sv.magickaScalePercent = DEFAULTS.magickaScalePercent
                ADDON.sv.staminaScalePercent = DEFAULTS.staminaScalePercent
                ApplyAttributeBars()
                RefreshPreviews()
            end,
            width = "half",
        },

        {
            type = "header",
            name = L.COMBAT_TIPS,
        },
        {
            type = "checkbox",
            name = L.CUSTOM_BLOCK_INTERRUPT_POSITION,
            settingKey = "combatTipsEnabled",
            getFunc = function()
                return ADDON.sv.combatTipsEnabled
            end,
            setFunc = function(value)
                ADDON.sv.combatTipsEnabled = value
                if value then
                    ApplyCombatTipsPosition()
                end
                RefreshPreviews()
            end,
            default = DEFAULTS.combatTipsEnabled,
            width = "full",
        },
        {
            type = "slider",
            name = L.COMBAT_TIPS_X,
            min = -1000,
            max = 1000,
            step = 5,
            settingKey = "combatTipsOffsetX",
            getFunc = function()
                return ADDON.sv.combatTipsOffsetX
            end,
            setFunc = function(value)
                ADDON.sv.combatTipsOffsetX = value
                ApplyCombatTipsPosition()
                RefreshPreviews()
            end,
            default = DEFAULTS.combatTipsOffsetX,
            disabled = function()
                return not ADDON.sv.combatTipsEnabled
            end,
            width = "full",
        },
        {
            type = "slider",
            name = L.COMBAT_TIPS_Y,
            min = -1000,
            max = 200,
            step = 5,
            settingKey = "combatTipsOffsetY",
            getFunc = function()
                return ADDON.sv.combatTipsOffsetY
            end,
            setFunc = function(value)
                ADDON.sv.combatTipsOffsetY = value
                ApplyCombatTipsPosition()
                RefreshPreviews()
            end,
            default = DEFAULTS.combatTipsOffsetY,
            disabled = function()
                return not ADDON.sv.combatTipsEnabled
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = L.CUSTOM_COMBAT_TIPS_SCALE,
            settingKey = "combatTipsScaleEnabled",
            getFunc = function()
                return ADDON.sv.combatTipsScaleEnabled
            end,
            setFunc = function(value)
                ADDON.sv.combatTipsScaleEnabled = value
                ApplyCombatTipsScale()
                RefreshPreviews()
            end,
            default = DEFAULTS.combatTipsScaleEnabled,
            width = "half",
        },
        {
            type = "slider",
            name = L.COMBAT_TIPS_SCALE,
            min = 50,
            max = 200,
            step = 5,
            settingKey = "combatTipsScalePercent",
            getFunc = function()
                return ADDON.sv.combatTipsScalePercent
            end,
            setFunc = function(value)
                ADDON.sv.combatTipsScalePercent = value
                ApplyCombatTipsScale()
                RefreshPreviews()
            end,
            default = DEFAULTS.combatTipsScalePercent,
            disabled = function()
                return not ADDON.sv.combatTipsScaleEnabled
            end,
            width = "half",
        },
        {
            type = "checkbox",
            name = L.PREVIEW_COMBAT_TIP,
            getFunc = function()
                return previewState.combatTips
            end,
            setFunc = function(value)
                SetPreview("combatTips", value)
            end,
            default = false,
            width = "full",
        },
        {
            type = "button",
            name = L.RESET_COMBAT_TIPS,
            func = function()
                ADDON.sv.combatTipsOffsetX = DEFAULTS.combatTipsOffsetX
                ADDON.sv.combatTipsOffsetY = DEFAULTS.combatTipsOffsetY
                ADDON.sv.combatTipsEnabled = DEFAULTS.combatTipsEnabled
                ADDON.sv.combatTipsScaleEnabled = DEFAULTS.combatTipsScaleEnabled
                ADDON.sv.combatTipsScalePercent = DEFAULTS.combatTipsScalePercent
                ApplyCombatTipsLayout()
                RefreshPreviews()
            end,
            width = "half",
        },

        {
            type = "header",
            name = L.PLAYER_INTERACTION,
        },
        {
            type = "checkbox",
            name = L.CUSTOM_PLAYER_INTERACTION_POSITION,
            settingKey = "playerInteractionEnabled",
            getFunc = function()
                return ADDON.sv.playerInteractionEnabled
            end,
            setFunc = function(value)
                ADDON.sv.playerInteractionEnabled = value
                if value then
                    ApplyPlayerInteractionPosition()
                end
                RefreshPreviews()
            end,
            default = DEFAULTS.playerInteractionEnabled,
            width = "full",
        },
        {
            type = "slider",
            name = L.PLAYER_INTERACTION_X,
            min = -1000,
            max = 1000,
            step = 5,
            settingKey = "playerInteractionOffsetX",
            getFunc = function()
                return ADDON.sv.playerInteractionOffsetX
            end,
            setFunc = function(value)
                ADDON.sv.playerInteractionOffsetX = value
                ApplyPlayerInteractionPosition()
                RefreshPreviews()
            end,
            default = DEFAULTS.playerInteractionOffsetX,
            disabled = function()
                return not ADDON.sv.playerInteractionEnabled
            end,
            width = "full",
        },
        {
            type = "slider",
            name = L.PLAYER_INTERACTION_Y,
            min = -1000,
            max = 200,
            step = 5,
            settingKey = "playerInteractionOffsetY",
            getFunc = function()
                return ADDON.sv.playerInteractionOffsetY
            end,
            setFunc = function(value)
                ADDON.sv.playerInteractionOffsetY = value
                ApplyPlayerInteractionPosition()
                RefreshPreviews()
            end,
            default = DEFAULTS.playerInteractionOffsetY,
            disabled = function()
                return not ADDON.sv.playerInteractionEnabled
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = L.CUSTOM_PLAYER_INTERACTION_SCALE,
            settingKey = "playerInteractionScaleEnabled",
            getFunc = function()
                return ADDON.sv.playerInteractionScaleEnabled
            end,
            setFunc = function(value)
                ADDON.sv.playerInteractionScaleEnabled = value
                ApplyPlayerInteractionScale()
                RefreshPreviews()
            end,
            default = DEFAULTS.playerInteractionScaleEnabled,
            width = "half",
        },
        {
            type = "slider",
            name = L.PLAYER_INTERACTION_SCALE,
            min = 50,
            max = 200,
            step = 5,
            settingKey = "playerInteractionScalePercent",
            getFunc = function()
                return ADDON.sv.playerInteractionScalePercent
            end,
            setFunc = function(value)
                ADDON.sv.playerInteractionScalePercent = value
                ApplyPlayerInteractionScale()
                RefreshPreviews()
            end,
            default = DEFAULTS.playerInteractionScalePercent,
            disabled = function()
                return not ADDON.sv.playerInteractionScaleEnabled
            end,
            width = "half",
        },
        {
            type = "checkbox",
            name = L.PREVIEW_PLAYER_INTERACTION,
            getFunc = function()
                return previewState.playerInteraction
            end,
            setFunc = function(value)
                SetPreview("playerInteraction", value)
            end,
            default = false,
            width = "full",
        },
        {
            type = "button",
            name = L.RESET_PLAYER_INTERACTION,
            func = function()
                ADDON.sv.playerInteractionOffsetX = DEFAULTS.playerInteractionOffsetX
                ADDON.sv.playerInteractionOffsetY = DEFAULTS.playerInteractionOffsetY
                ADDON.sv.playerInteractionEnabled = DEFAULTS.playerInteractionEnabled
                ADDON.sv.playerInteractionScaleEnabled = DEFAULTS.playerInteractionScaleEnabled
                ADDON.sv.playerInteractionScalePercent = DEFAULTS.playerInteractionScalePercent
                ApplyPlayerInteractionLayout()
                RefreshPreviews()
            end,
            width = "half",
        },

        {
            type = "header",
            name = L.NAMEPLATE_REFRESH,
        },
        {
            type = "dropdown",
            name = L.HEALTH_BAR_NAME_REFRESH,
            tooltip = L.WORK_AROUND_MISSING_NAMEPLATE_HEALTH_BARS_AFTER_UI_CHAN,
            choices = {
                L.OFF,
                L.MANUAL_ONLY,
                L.AUTOMATICALLY_AFTER_CLOSING_SETTINGS,
            },
            choicesValues = {
                "off",
                "manual",
                "auto",
            },
            settingKey = "refreshNameplatesMode",
            getFunc = function()
                return ADDON.sv.refreshNameplatesMode
            end,
            setFunc = function(value)
                ADDON.sv.refreshNameplatesMode = value
            end,
            default = DEFAULTS.refreshNameplatesMode,
            width = "full",
        },
        {
            type = "button",
            name = L.REFRESH_NAMEPLATES_NOW,
            tooltip = L.BRIEFLY_TOGGLE_THE_BUILT_IN_ALL_HEALTH_BARS_SETTING_AND,
            func = function()
                RefreshNameplatesNow()
            end,
            disabled = function()
                return ADDON.sv.refreshNameplatesMode == "off"
            end,
            width = "half",
        },

        {
            type = "header",
            name = L.HEALTH_GLOW_EFFECTS,
        },
        {
            type = "dropdown",
            name = L.PLAYER_HEALTH_GLOW,
            tooltip = L.CONTROL_GLOW_EFFECTS_ON_THE_PLAYER_HEALTH_BAR_FULLY_DIS,
            choices = {
                L.STANDARD,
                L.NO_FLASH_ON_LOADING_WEAPON_SWAP,
                L.FULLY_DISABLED,
            },
            choicesValues = {
                "standard",
                "transitions",
                "disabled",
            },
            settingKey = "hpGainGlowMode",
            getFunc = function()
                return ADDON.sv.hpGainGlowMode
            end,
            setFunc = function(value)
                ADDON.sv.hpGainGlowMode = value
                ADDON.healthGainGlowSuppressionToken = (ADDON.healthGainGlowSuppressionToken or 0) + 1
                ADDON.healthGainGlowSuppressed = false
                ApplyHealthGainGlowMode()
                if value == "disabled" then
                    zo_callLater(StopExistingPlayerHealthAttributeGlows, 0)
                end
            end,
            default = DEFAULTS.hpGainGlowMode,
            width = "full",
        },
        {
            type = "description",
            text = L.NO_FLASH_SUPPRESSES_FADE_IN_GAIN_FOR_0_5_SECONDS_AFTER_,
        },

        {
            type = "header",
            name = L.APPEARANCE,
        },
        {
            type = "checkbox",
            name = L.FLAT_GAMEPAD_UI_HIDE_GLOSS,
            tooltip = L.REDIRECT_ONLY_TEXTURES_SPECIFIC_TO_THE_GAMEPAD_UI_HIDE_,
            settingKey = "flatGamepadUI",
            getFunc = function()
                return ADDON.sv.flatGamepadUI
            end,
            setFunc = function(value)
                ADDON.sv.flatGamepadUI = value
                ApplyFlatGamepadUI()
                RefreshPreviews()
            end,
            default = DEFAULTS.flatGamepadUI,
            width = "full",
        },

        {
            type = "header",
            name = L.PREVIEW,
        },
        {
            type = "button",
            name = L.SHOW_ALL,
            func = function()
                previewState.bars = true
                previewState.combatTips = true
                previewState.playerInteraction = true
                RefreshPreviews()
            end,
            width = "half",
        },
        {
            type = "button",
            name = L.HIDE_ALL,
            func = function()
                HideAllPreviews()
            end,
            width = "half",
        },
    }

    ADDON.optionsByKey = {}
    for _, option in ipairs(options) do
        if option.settingKey then ADDON.optionsByKey[option.settingKey] = option end
    end
    if LAM then LAM:RegisterOptionControls(panelName, options) end
end

-- Controller-accessible fallback: uses the same option setters as the menu.
local function RegisterChatCommands()
    if not SLASH_COMMANDS then return end
    SLASH_COMMANDS["/ghc"] = function(text)
        local command, key, raw = string.match(text or "", "^%s*(%S*)%s*(%S*)%s*(.-)%s*$")
        command = string.lower(command)
        if command == "preview" then
            previewState.bars = true
            previewState.combatTips = true
            previewState.playerInteraction = true
            RefreshPreviews()
        elseif command == "hide" then
            HideAllPreviews()
            if ADDON.sv.refreshNameplatesMode == "auto" then RefreshNameplatesNow() end
        elseif command == "refresh" then
            RefreshNameplatesNow()
        elseif command == "keys" then
            local keys = {}
            for name in pairs(ADDON.optionsByKey) do keys[#keys + 1] = name end
            table.sort(keys)
            d(string.format(L.COMMAND_KEYS, table.concat(keys, ", ")))
        elseif command == "get" or command == "set" then
            local option = ADDON.optionsByKey[key]
            if not option then d(L.COMMAND_INVALID) return end
            if command == "get" then
                d(string.format(L.COMMAND_SAVED, key, tostring(option.getFunc())))
                return
            end
            local value
            if option.type == "checkbox" then
                if raw == "true" then value = true elseif raw == "false" then value = false end
            elseif option.type == "slider" then
                value = tonumber(raw)
                if value and (value ~= value or value < option.min or value > option.max
                    or (value - option.min) % option.step ~= 0) then value = nil end
            elseif option.type == "dropdown" then
                for _, allowed in ipairs(option.choicesValues) do
                    if raw == allowed then value = allowed break end
                end
            end
            if value == nil then d(L.COMMAND_INVALID) return end
            option.setFunc(value)
            d(string.format(L.COMMAND_SAVED, key, tostring(value)))
            if ADDON.sv.refreshNameplatesMode == "auto" then RefreshNameplatesNow() end
        else
            d(L.COMMAND_HELP)
        end
    end
end

local function Initialize()
    ADDON.sv = ZO_SavedVars:NewAccountWide(
        ADDON.savedVarName,
        1,
        nil,
        DEFAULTS
    )

    if ADDON.sv.controllerStyle ~= "auto" and ADDON.sv.controllerStyle ~= "xbox"
        and ADDON.sv.controllerStyle ~= "dualsense" then
        ADDON.sv.controllerStyle = DEFAULTS.controllerStyle
    end
    ApplyControllerButtonTextures()

    EnsurePreviewRoot()
    InstallHooks()
    RegisterSettings()
    RegisterChatCommands()

    zo_callLater(function()
        ApplyAllHUDSettings()
        ApplyHealthGainGlowMode()
        RefreshControllerStyle()
        RefreshPreviews()
    end, 100)
end

EVENT_MANAGER:RegisterForEvent(
    ADDON.name,
    EVENT_ADD_ON_LOADED,
    function(_, addonName)
        if addonName ~= ADDON.name then
            return
        end

        EVENT_MANAGER:UnregisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED)
        Initialize()
    end
)
