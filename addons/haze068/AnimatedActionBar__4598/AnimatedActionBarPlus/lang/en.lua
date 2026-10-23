local strings =
{
    SI_AAB_PANEL_DESCRIPTION =
        "Adds a bounce animation and a customizable glow effect to your action bar. " ..
        "Works alongside FancyActionbar+, Bandits UI, LUI Extended, Ability Framework " ..
        "(including custom Style Packs), AlphaGear, Azurah and the vanilla UI.",

    SI_AAB_SUB_BOUNCE          = "Bounce Animation",
    SI_AAB_SUB_BOUNCE_TT       = "Settings that control the squish-and-grow animation played on your ability icons.",

    SI_AAB_ANIM_STYLE          = "Animation style",
    SI_AAB_ANIM_STYLE_TT       = "Which animation plays when an ability is used or procs. " ..
                                        "Bounce: shrink + grow. Flash: brightness blink. " ..
                                        "Shake: horizontal wobble. Tilt: brief rotation.",
    SI_AAB_ANIM_BOUNCE         = "Bounce",
    SI_AAB_ANIM_FLASH          = "Flash",
    SI_AAB_ANIM_SHAKE          = "Shake",
    SI_AAB_ANIM_TILT           = "Tilt",
    SI_AAB_SUB_GLOW            = "Glow Effect",
    SI_AAB_SUB_GLOW_TT         = "A colored highlight that fades over your ability icon when you press it.",
    SI_AAB_SUB_PULSE           = "Proc Pulse",
    SI_AAB_SUB_PULSE_TT        = "Continuous glow effect that runs while an ability is proc'd and ready to use.",

    SI_AAB_BOUNCE_ENABLE       = "Enable bounce",
    SI_AAB_BOUNCE_ENABLE_TT    = "Master switch for the bounce animation. When off, no icons will animate.",
    SI_AAB_BOUNCE_ON_PROC      = "Bounce on procs",
    SI_AAB_BOUNCE_ON_PROC_TT   = "Also play the bounce animation when an ability procs (e.g. Crystal Fragments, " ..
                                        "Assassin's Will, Grim Focus), not just when you press it.",

    SI_AAB_QS_BOUNCE           = "Bounce on quickslot",
    SI_AAB_QS_BOUNCE_TT        = "Play the bounce animation on the quickslot (Q) when you use a potion or other quickslot item.",
    SI_AAB_QS_READY            = "Quickslot ready animation",
    SI_AAB_QS_READY_TT         = "Play bounce and glow on the quickslot (Q) as soon as its cooldown is over and the potion is ready again. " ..
                                        "Uses the bounce and glow settings.",

    SI_AAB_BOUNCE_GROW         = "Grow scale",
    SI_AAB_BOUNCE_GROW_TT      = "How much the icon grows at the peak of the bounce. 1.10 = 10% larger than normal. " ..
                                        "Higher = more dramatic.",
    SI_AAB_BOUNCE_SHRINK       = "Shrink scale",
    SI_AAB_BOUNCE_SHRINK_TT    = "How much the icon shrinks at the start of the bounce. 0.90 = 10% smaller than normal. " ..
                                        "Lower = sharper squish.",
    SI_AAB_BOUNCE_RESET        = "Reset duration (ms)",
    SI_AAB_BOUNCE_RESET_TT     = "How long the icon takes to return to its normal size after the peak. " ..
                                        "Lower = snappier feel.",

    SI_AAB_GLOW_ENABLE         = "Enable glow",
    SI_AAB_GLOW_ENABLE_TT      = "Master switch for the glow effect. When off, no glow will be drawn on press.",
    SI_AAB_GLOW_COLOR          = "Glow color",
    SI_AAB_GLOW_COLOR_TT       = "Color of the glow effect. The alpha (A) slider controls maximum brightness.",
    SI_AAB_GLOW_DURATION       = "Glow duration (ms)",
    SI_AAB_GLOW_DURATION_TT    = "How long the press-glow takes to fade out. Higher = stays visible longer.",
    SI_AAB_GLOW_PADDING        = "Glow padding (px)",
    SI_AAB_GLOW_PADDING_TT     = "Extra pixels the glow extends beyond the icon edges. " ..
                                        "Higher = bigger halo around the icon.",
    SI_AAB_GLOW_INTENSITY      = "Glow strength",
    SI_AAB_GLOW_INTENSITY_TT   = "Brightness multiplier of the glow. 1.00 = default, higher = brighter/more intense. " ..
                                        "Affects press glow, proc pulse and quickslot glow.",

    SI_AAB_PULSE_ENABLE        = "Enable proc pulse",
    SI_AAB_PULSE_ENABLE_TT     = "When an ability procs, keep pulsing the glow until the proc is used or expires.",
    SI_AAB_PROC_VANILLA_GLOW       = "Vanilla ESO proc glow",
    SI_AAB_PROC_VANILLA_GLOW_TT    = "Show the original ESO highlight glow that appears on an ability the moment it procs. " ..
                                        "Turn this OFF to rely only on this addon's proc pulse and keep the bar clean. " ..
                                        "Turning this back ON requires a UI reload to restore the original texture.",
    SI_AAB_PULSE_STOP_ON_PRESS          = "Stop pulse on press",
    SI_AAB_PULSE_STOP_ON_PRESS_TT       = "Stop the pulse the instant you press the proc'd ability, instead of waiting " ..
                                        "for the game's proc-fade event (which can lag a frame).",
    SI_AAB_PULSE_STYLE         = "Pulse style",
    SI_AAB_PULSE_STYLE_TT      = "Smooth: a gentle fade in and out.\n" ..
                                        "Blink: a clearly visible on/off toggle.\n" ..
                                        "Strobe: a fast, aggressive flicker for maximum attention.",
    SI_AAB_PULSE_STYLE_SMOOTH  = "Smooth",
    SI_AAB_PULSE_STYLE_BLINK   = "Blink",
    SI_AAB_PULSE_STYLE_STROBE  = "Strobe",
    SI_AAB_PULSE_SMOOTH_DUR    = "Smooth pulse duration (ms)",
    SI_AAB_PULSE_SMOOTH_DUR_TT = "Length of one fade cycle in Smooth mode. Only applies when Pulse style is set to Smooth.",
    SI_AAB_PULSE_BLINK_INT     = "Blink interval (ms)",
    SI_AAB_PULSE_BLINK_INT_TT  = "Time between on and off in Blink mode. Lower = faster blinking. " ..
                                        "Only applies when Pulse style is set to Blink.",
    SI_AAB_PULSE_STROBE_INT    = "Strobe interval (ms)",
    SI_AAB_PULSE_STROBE_INT_TT = "Time between on and off in Strobe mode. Very low values produce a harsh flicker. " ..
                                        "Only applies when Pulse style is set to Strobe.",
    SI_AAB_PULSE_MIN_ALPHA     = "Pulse minimum alpha",
    SI_AAB_PULSE_MIN_ALPHA_TT  = "Lowest visibility the pulse fades down to. " ..
                                        "0 = fully transparent at the dim point, 1 = always fully visible.",
    SI_AAB_PULSE_MAX_ALPHA     = "Pulse maximum alpha",
    SI_AAB_PULSE_MAX_ALPHA_TT  = "Highest visibility the pulse reaches at its peak. 1 = fully opaque.",
    SI_AAB_PULSE_COLOR_CYCLE   = "Color cycle",
    SI_AAB_PULSE_COLOR_CYCLE_TT= "Alternate the pulse between the primary Glow color and the Secondary color below " ..
                                        "for a two-tone flashing effect.",
    SI_AAB_PULSE_COLOR_SECOND  = "Secondary color",
    SI_AAB_PULSE_COLOR_SECOND_TT = "Second color used when Color cycle is enabled.",

    SI_AAB_SUB_ULT             = "Ultimate",
    SI_AAB_SUB_ULT_TT          = "Dedicated settings for the ultimate slot, independent from the bounce and glow on normal slots.",

    SI_AAB_ULT_HEADER_EFFECTS  = "Ultimate effects",
    SI_AAB_ULT_BOUNCE_ENABLE   = "Bounce on ultimate",
    SI_AAB_ULT_BOUNCE_ENABLE_TT= "Play the bounce animation on the ultimate slot too.",
    SI_AAB_ULT_GLOW_ENABLE     = "Glow on ultimate",
    SI_AAB_ULT_GLOW_ENABLE_TT  = "Glow effect on press for the ultimate slot.",
    SI_AAB_ULT_GLOW_COLOR      = "Ultimate glow color",
    SI_AAB_ULT_GLOW_COLOR_TT   = "Color of the press-glow on the ultimate slot. The alpha (A) slider controls brightness.",
    SI_AAB_ULT_GLOW_DURATION   = "Ultimate glow duration (ms)",
    SI_AAB_ULT_GLOW_DURATION_TT= "How long the ultimate press-glow takes to fade out.",
    SI_AAB_ULT_GLOW_PADDING    = "Ultimate glow strength (px)",
    SI_AAB_ULT_GLOW_PADDING_TT = "Extra pixels the ultimate glow extends beyond the icon edges. " ..
                                        "Higher = larger/stronger halo, lower = subtler.",
    SI_AAB_ULT_GLOW_INTENSITY  = "Ultimate glow brightness",
    SI_AAB_ULT_GLOW_INTENSITY_TT = "Brightness multiplier of the ultimate press-glow. " ..
                                        "1.00 = default, higher = brighter/more intense.",

    SI_AAB_ULT_HEADER_READY    = "Ultimate-ready border",
    SI_AAB_ULT_VANILLA_SHIMMER = "Vanilla ESO ready shimmer",
    SI_AAB_ULT_VANILLA_SHIMMER_TT = "Show the original ESO golden shimmer/glow on the ultimate slot the moment it becomes ready. " ..
                                        "Works alongside the custom ready border below - enable one or both. " ..
                                        "Turning this OFF after it was ON requires a UI reload to fully clear the textures.",
    SI_AAB_ULT_BORDER_STYLE       = "Ready border style",
    SI_AAB_ULT_BORDER_STYLE_TT    = "Choose which border marks the ultimate slot. \"Custom\" uses this add-on's colored glow border with all the pulse/blink/rainbow options below. \"Controller\" shows a progress border that fills from the bottom as your ultimate charges. Switching to Controller disables the custom options below.",
    SI_AAB_ULT_BORDER_CUSTOM      = "Custom (glow border)",
    SI_AAB_ULT_BORDER_CONTROLLER  = "Controller (progress border)",
    SI_AAB_ULTCTRL_STYLE          = "Border texture",
    SI_AAB_ULTCTRL_STYLE_TT       = "Which frame texture the controller progress border uses.",
    SI_AAB_ULTCTRL_STYLE_BEVEL    = "Bevel (metallic 3D)",
    SI_AAB_ULTCTRL_STYLE_FLAT     = "Flat (clean line)",
    SI_AAB_ULTCTRL_STYLE_SLEEK    = "Sleek (thin double line)",
    SI_AAB_ULTCTRL_STYLE_CHAMFER  = "Chamfer (hard-edged)",
    SI_AAB_ULTCTRL_STYLE_DOUBLE   = "Double (twin ring)",
    SI_AAB_ULTCTRL_GLOWSTYLE      = "Glow style",
    SI_AAB_ULTCTRL_GLOWSTYLE_TT   = "Shape of the glow shown while the ultimate is ready.",
    SI_AAB_ULTCTRL_GLOWSTYLE_SOFT = "Soft (wide halo)",
    SI_AAB_ULTCTRL_GLOWSTYLE_SHARP = "Sharp (tight edge)",
    SI_AAB_ULTCTRL_GLOWSTYLE_RING = "Ring (outer aura)",
    SI_AAB_ULTCTRL_THICKNESS      = "Border thickness",
    SI_AAB_ULTCTRL_THICKNESS_TT   = "How thick the border line is, in pixels. Set it low for a thin outline or high for a bold frame.",
    SI_AAB_ULTCTRL_CORNER         = "Corner length",
    SI_AAB_ULTCTRL_CORNER_TT      = "How far the top and bottom corner pieces reach inward, as a percentage of the slot width. Lower = more open bracket, higher = more closed frame.",
    SI_AAB_ULTCTRL_PADDING        = "Border spacing",
    SI_AAB_ULTCTRL_PADDING_TT     = "Gap between the slot and the border, in pixels.",
    SI_AAB_ULTCTRL_TRACK          = "Show background track",
    SI_AAB_ULTCTRL_TRACK_TT       = "Show the dark unfilled frame behind the progress, so you always see the full outline.",
    SI_AAB_ULTCTRL_COLORSHIFT     = "Charge color gradient",
    SI_AAB_ULTCTRL_COLORSHIFT_TT  = "Fade the border color from the charging color up to the ready color as your ultimate fills.",
    SI_AAB_ULTCTRL_CHARGECOLOR    = "Charging color",
    SI_AAB_ULTCTRL_CHARGECOLOR_TT = "Border color at 0% when the charge gradient is enabled. The ready color is the border color above.",
    SI_AAB_ULTCTRL_GLOWFULL       = "Glow when full",
    SI_AAB_ULTCTRL_GLOWFULL_TT    = "Add a bright additive glow and a short pulse the moment your ultimate is fully charged.",
    SI_AAB_ULTCTRL_GLOWINT        = "Full glow intensity",
    SI_AAB_ULTCTRL_GLOWINT_TT     = "Brightness of the glow shown while the ultimate is ready.",
    SI_AAB_ULTCTRL_RAINBOW        = "Rainbow when full",
    SI_AAB_ULTCTRL_RAINBOW_TT     = "Cycle the progress border through the rainbow once your ultimate is fully charged. Uses the rainbow saturation and lightness sliders from the custom border section.",
    SI_AAB_ULT_ENABLE          = "Enable ultimate ready border",
    SI_AAB_ULT_ENABLE_TT       = "Show a colored border around your ultimate slot the moment you have enough " ..
                                        "ultimate power to use the slotted ability.",
    SI_AAB_ULT_COLOR           = "Border color",
    SI_AAB_ULT_COLOR_TT        = "Color of the ultimate-ready border. The alpha (A) slider controls its brightness.",
    SI_AAB_ULT_PULSE           = "Pulse the border",
    SI_AAB_ULT_PULSE_TT        = "When enabled, the border gently pulses to draw the eye. " ..
                                        "When off, it stays at a constant brightness.",
    SI_AAB_ULT_PULSE_MODE      = "Border animation",
    SI_AAB_ULT_PULSE_MODE_TT   = "Smooth: a gentle fade in and out.\n" ..
                                        "Blink: a clearly visible hard on/off toggle.",
    SI_AAB_ULT_BLINK_INT       = "Blink interval (ms)",
    SI_AAB_ULT_BLINK_INT_TT    = "Time between on and off in Blink mode. Lower = faster blinking. " ..
                                        "Only applies when Border animation is set to Blink.",
    SI_AAB_ULT_COLOR_CYCLE     = "Color cycle",
    SI_AAB_ULT_COLOR_CYCLE_TT  = "Alternate the ultimate border between the primary color and the Secondary " ..
                                        "color below instead of toggling on/off. Only applies in Blink mode.",
    SI_AAB_ULT_COLOR_SECOND    = "Secondary color",
    SI_AAB_ULT_COLOR_SECOND_TT = "Second color used for the ultimate border when Color cycle is enabled.",
    SI_AAB_ULT_PADDING         = "Border padding (px)",
    SI_AAB_ULT_PADDING_TT      = "Extra pixels the border extends beyond the icon edges. " ..
                                        "Higher = larger halo.",

    SI_AAB_ULT_PULSE_DUR       = "Pulse duration (ms)",
    SI_AAB_ULT_PULSE_DUR_TT    = "Length of one fade in/out cycle. Lower = faster pulsing.",
    SI_AAB_ULT_PULSE_MIN       = "Pulse: min visibility (alpha)",
    SI_AAB_ULT_PULSE_MIN_TT    = "Lowest visibility the pulse fades down to. " ..
                                        "Lower = stronger pulse contrast.",
    SI_AAB_ULT_INTENSITY       = "Glow strength",
    SI_AAB_ULT_INTENSITY_TT    = "Brightness multiplier of the glow. 1.00 = default, higher = brighter/more intense.",

    SI_AAB_SUB_FRAME           = "Frame Appearance",
    SI_AAB_SUB_FRAME_TT        = "Controls the frame drawn around each ability icon.",
    SI_AAB_THIN_FRAME          = "Use thin custom frame",
    SI_AAB_THIN_FRAME_TT       = "Replaces the vanilla 64px ability frame with a thin custom border " ..
                                        "(drawn from CustomEdge.dds and CustomCenter.dds). Glow effects play above this frame. " ..
                                        "Requires a UI reload to fully apply or remove.",
    SI_AAB_FRAME_ALPHA         = "Frame opacity",
    SI_AAB_FRAME_ALPHA_TT      = "0 = frame fully invisible (clean look, glow only). " ..
                                        "1 = full opacity. Lower values make the frame thinner/dimmer.",
    SI_AAB_EDGE_STYLE          = "Frame style",
    SI_AAB_EDGE_STYLE_TT       = "Selects the texture for the custom frame. " ..
                                        "Classic = the original frame, EldenRingUI = matches the EldenRingUI addon.",
    SI_AAB_EDGE_CLASSIC        = "Classic",
    SI_AAB_EDGE_V2             = "EldenRingUI",
    SI_AAB_EDGE_PURPLE         = "Purple Frames",
    SI_AAB_EDGE_RED            = "Red Frames",
    SI_AAB_EDGE_BLUE           = "Blue Frames",
    SI_AAB_EDGE_AQUA           = "Aqua Frames",
    SI_AAB_EDGE_DARKRED        = "Dark Red Frames",
    SI_AAB_EDGE_DARKPURPLE     = "Dark Purple Frames",
    SI_AAB_RELOAD_NOTE         = "A UI reload (/reloadui) is required for this change to fully take effect.",
    SI_AAB_FRAME_THEME_NOTE    = "|cAAAAAAUI creators who would like their own custom theme, please contact |r|cFFFFFFhaze.3169|r|cAAAAAA on Discord. Got ideas for more themes? Reach out there too!|r",
    SI_AAB_RELOAD_UI           = "Reload UI",
    SI_AAB_RELOAD_UI_TT        = "Reload the UI to fully apply frame changes.",

    SI_AAB_DBG_ON              = "on",
    SI_AAB_DBG_OFF             = "off",
    SI_AAB_DBG_FRAME           = "Frame",
    SI_AAB_DBG_THINFRAME       = "thin frame",
    SI_AAB_DBG_STYLE           = "style",
    SI_AAB_DBG_TEMPLATE        = "template",
    SI_AAB_DBG_ALPHA           = "alpha",
    SI_AAB_DBG_BOUNCE          = "Bounce",
    SI_AAB_DBG_ACTIVE          = "active",
    SI_AAB_DBG_ONPROC          = "on proc",
    SI_AAB_DBG_QUICKSLOT       = "quickslot",
    SI_AAB_DBG_QS_READY        = "quickslot ready",
    SI_AAB_DBG_ULTI            = "ulti",
    SI_AAB_DBG_GLOWPULSE       = "Glow / Pulse",
    SI_AAB_DBG_GLOW            = "glow",
    SI_AAB_DBG_PULSE           = "pulse",
    SI_AAB_DBG_PULSEMODE       = "pulse mode",
    SI_AAB_DBG_COLORCYCLE      = "color cycle",
    SI_AAB_DBG_VANILLAPROC     = "vanilla proc glow",
    SI_AAB_DBG_ULTFRAME        = "Ultimate frame",
    SI_AAB_DBG_READY           = "ready",
    SI_AAB_DBG_MODE            = "mode",
    SI_AAB_DBG_VANILLASHIMMER  = "vanilla shimmer",
    SI_AAB_DBG_SERVER          = "Server",

    SI_AAB_EXPIRE_DESC         = "Play an animation on the ability icon when the effect of a slotted ability expires (e.g. a buff or DoT running out).",
    SI_AAB_EXPIRE_ENABLE       = "Animate on expire",
    SI_AAB_EXPIRE_ENABLE_TT    = "Play an animation when the effect of a slotted ability runs out, so you know it's time to recast.",
    SI_AAB_EXPIRE_STYLE        = "Expire animation style",
    SI_AAB_EXPIRE_STYLE_TT     = "Which animation plays when an effect expires. Choose 'Same as press animation' to reuse the style above.",
    SI_AAB_EXPIRE_STYLE_INHERIT = "Same as press animation",
    SI_AAB_EXPIRE_STRENGTH       = "Expire animation strength",
    SI_AAB_EXPIRE_STRENGTH_TT    = "Multiplier for how strong the expire animation plays. 1.00 = same as the press animation, 2.00 = twice the motion.",
    SI_AAB_EXPIRE_GLOW_ENABLE    = "Expire glow",
    SI_AAB_EXPIRE_GLOW_ENABLE_TT = "Additionally flash a colored glow on the icon when the effect expires.",
    SI_AAB_EXPIRE_GLOW_COLOR     = "Expire glow color",
    SI_AAB_EXPIRE_GLOW_COLOR_TT  = "Color of the glow shown when an effect expires - pick something distinct from the press glow.",
    SI_AAB_DBG_EXPIRE          = "on expire",
    SI_AAB_DBG_EXPIRE_HEAD     = "Expire check (active bar)",
    SI_AAB_DBG_DURATION        = "duration",
    SI_AAB_DBG_TRACKING        = "tracking",

    SI_AAB_PULSE_STYLE_RAINBOW = "Smooth-Rainbow",
    SI_AAB_ULT_RAINBOW_SAT     = "Rainbow saturation",
    SI_AAB_ULT_RAINBOW_SAT_TT  = "Saturation of the rainbow colors. 0 = grayscale, 1 = full color.",
    SI_AAB_ULT_RAINBOW_LIGHT   = "Rainbow lightness",
    SI_AAB_ULT_RAINBOW_LIGHT_TT= "Brightness of the rainbow colors. 0 = black, 0.5 = full brightness, 1 = white.",
    SI_AAB_DBG_RAINBOW_SAT     = "rainbow sat",
    SI_AAB_DBG_RAINBOW_LIGHT   = "rainbow light",
    SI_AAB_CONF_HEAD           = "Conflict check",
    SI_AAB_CONF_FOUND          = "Other action bar addons active:",
    SI_AAB_CONF_HINT           = "If frames/glows show up twice, disable one of them for testing.",
    SI_AAB_CONF_NONE           = "No known conflicting action bar addons found.",
    SI_AAB_CONF_HOOKS          = "Own hooks",
    SI_AAB_CONF_OK             = "ok",
    SI_AAB_CONF_MISSING        = "missing",
    SI_AAB_CONF_OVERRIDDEN     = "missing (overwritten?)",
    SI_AAB_CONF_ULTFRAME       = "Vanilla ulti frame",
    SI_AAB_CONF_VISIBLE        = "visible (other addon?)",
    SI_AAB_CONF_SUPPRESSED     = "suppressed",
    SI_AAB_DBG_PROGRESS        = "progress",
    SI_AAB_DBG_BORDER          = "border",
    SI_AAB_DBG_VISIBLE         = "visible",
    SI_AAB_DBG_TEXTURE         = "texture",
    SI_AAB_DBG_THICKNESS       = "thickness",
    SI_AAB_DBG_PADDING         = "padding",
    SI_AAB_DBG_COLORSHIFT      = "color shift",
    SI_AAB_DBG_FULLGLOW        = "full glow",
    SI_AAB_DBG_GLOWSTYLE       = "glow style",
    SI_AAB_DBG_RAINBOW         = "rainbow",

    -- duration-scaled end animation
    SI_AAB_EXPIRE_SCALE_DESC       = "Couple the length of the expire animation to how long the ability lasts. Short buffs flash quickly, long ones play out a little more.",
    SI_AAB_EXPIRE_SCALE_ENABLE     = "Scale by duration",
    SI_AAB_EXPIRE_SCALE_ENABLE_TT  = "When on, the expire animation is stretched or compressed based on the slotted ability's duration.",
    SI_AAB_EXPIRE_SCALE_REF        = "Reference duration (ms)",
    SI_AAB_EXPIRE_SCALE_REF_TT     = "The duration that plays at normal speed. Abilities longer than this play slower, shorter ones faster.",
    SI_AAB_EXPIRE_SCALE_MIN        = "Min speed factor",
    SI_AAB_EXPIRE_SCALE_MIN_TT     = "Lower bound for the time factor, so very short abilities don't blink too fast to see.",
    SI_AAB_EXPIRE_SCALE_MAX        = "Max speed factor",
    SI_AAB_EXPIRE_SCALE_MAX_TT     = "Upper bound for the time factor, so very long abilities don't drag on.",
    SI_AAB_EXPIRE_OVERRIDE_CLEAR   = "Clear all overrides",
    SI_AAB_EXPIRE_OVERRIDE_CLEAR_TT= "Removes every per-ability fire timing you set via /aab setend.",
    SI_AAB_EXPIRE_OVERRIDE_NOTE    = "Per-ability fire timing can be set in chat: type /aab id to list slotted ability IDs, then /aab setend <id> <ms|auto> to make the end animation fire that many ms after cast.",

    -- slash command overview
    SI_AAB_CMD_HEAD    = "Commands",
    SI_AAB_CMD_PANEL   = "open the settings panel",
    SI_AAB_CMD_INFO    = "open the Info tab directly",
    SI_AAB_CMD_UI      = "open the AnimatedActionBar+ Studio (live preview)",

    SI_AAB_CMD_ID      = "list slotted ability IDs in chat",
    SI_AAB_CMD_SETEND  = "set when the end animation fires for one ability (ms after cast)",
    SI_AAB_CMD_DEBUG   = "print the full status dump",
    SI_AAB_ID_HINT     = "Set fire timing with: /aab setend <id> <ms|auto>  (ms after cast)",
    SI_AAB_SETEND_BADID  = "Invalid ability ID. Use /aab id to list them.",
    SI_AAB_SETEND_BADVAL = "Invalid value. Use a number of milliseconds or 'auto'.",
    SI_AAB_SETEND_SET    = "End animation for %s (id %d) will now fire %dms after cast.",
    SI_AAB_SETEND_CLEARED= "Fire-timing override for id %d cleared (back to the ability's own duration).",

    -- help / diagnostics window

    SI_AAB_CMD_LIST           = "show this command list",

    SI_AAB_TRACE_ON           = "Expire trace ON - schedule/resync/fire will be logged.",
    SI_AAB_TRACE_OFF          = "Expire trace OFF.",

    SI_AAB_SUB_PERF             = "Performance",
    SI_AAB_SUB_PERF_TT          = "Optional optimizations. All OFF by default - turn on only what you need.",
    SI_AAB_PERF_DESC            = "These options change HOW efficiently the addon works internally, not what it shows. Most players won't notice a difference; enable them if you want to squeeze out extra fps in big fights (Trials, Cyrodiil).",
    SI_AAB_PERF_EFFECTID        = "Filter effect events by ability ID",
    SI_AAB_PERF_EFFECTID_TT     = "Instead of reacting to every buff/debuff on you, only listen for your slotted abilities. Biggest saving in busy fights. Re-applies live.",
    SI_AAB_PERF_SLOTMAP         = "Fast slot lookup",
    SI_AAB_PERF_SLOTMAP_TT      = "Use a prebuilt lookup table instead of scanning all slots on every effect event. O(1) instead of a loop.",
    SI_AAB_PERF_COMBAT          = "Animate only in combat",
    SI_AAB_PERF_COMBAT_TT       = "Suspend all animations while out of combat. Saves work in towns/hubs. Animations resume the moment combat starts.",
    SI_AAB_PERF_RAINBOW         = "Economy rainbow updates",
    SI_AAB_PERF_RAINBOW_TT      = "Update the smooth-rainbow ultimate border ~30 times/sec instead of 200. Looks identical, ~85% fewer updates.",
    SI_AAB_PERF_STYLEHOOK       = "Single style hook",
    SI_AAB_PERF_STYLEHOOK_TT    = "Merge two ability-style hooks into one when the thin frame is on. Needs a reload.",
    SI_AAB_PERF_TLCACHE         = "Limit animation cache",
    SI_AAB_PERF_TLCACHE_TT      = "Cap cached animation timelines per button to keep memory low during long sessions with duration scaling.",
    SI_AAB_PERF_NOTE            = "None of these change the look of the addon. If something behaves oddly, turn the matching option back off.",

    SI_AAB_SUB_PRESETS          = "Presets",
    SI_AAB_SUB_PRESETS_TT       = "Quickly switch between preset looks.",
    SI_AAB_PRESETS_DESC         = "One click sets several effect options at once. Only the look changes - your colors and performance options stay as they are.",
    SI_AAB_PRESET_MINIMAL       = "Minimal",
    SI_AAB_PRESET_MINIMAL_TT    = "Just the bounce on cast. Glow, pulse, expire and bar-swap off. Lightest look.",
    SI_AAB_PRESET_STANDARD      = "Standard",
    SI_AAB_PRESET_STANDARD_TT   = "Bounce, glow, pulse and expire on. The default balanced look.",
    SI_AAB_PRESET_FLASHY        = "Flashy",
    SI_AAB_PRESET_FLASHY_TT     = "Everything on, plus bar-swap flash and color cycling. Maximum effect.",
    SI_AAB_PRESETS_NOTE         = "Presets are a starting point - tweak anything afterwards in the submenus below.",


    SI_AAB_SUB_CONTACT            = "Contact Creator",
    SI_AAB_SUB_CONTACT_TT         = "Support the creator with an in-game donation.",
    SI_AAB_CONTACT_DESC           = "Enjoying the addon? In-game donations are very welcome - Potions, Gold and crafting Resources all help! Click below to open a mail addressed to @haze068.",
    SI_AAB_CONTACT_DONATE_BTN     = "Donate via in-game mail",
    SI_AAB_CONTACT_DONATE_BTN_TT  = "Opens the in-game mail panel with recipient and title prefilled.",

    SI_AAB_SUB_INFO               = "Info",
    SI_AAB_SUB_INFO_TT            = "Compatibility notes for using AnimatedActionBar+ together with other addons.",
    SI_AAB_INFO_THINFRAMES        = "If you use the \"Frame Appearance: Thin Frames\" option from this addon, please turn OFF the following in FancyActionBar+ under UI Customization -> Custom Frames Keyboard:\n\n" ..
                                        "  - \"Hide Default Frames\"\n" ..
                                        "  - \"Use Thin Frames\"\n\n" ..
                                        "Both addons drawing thin frames at once causes doubled or misaligned frames.",
    SI_AAB_INFO_GAMEPAD           = "Playing on controller?\n\n" ..
                                        "If your abilities are shifted, misaligned or otherwise displayed incorrectly, please turn OFF \"Gamepad Mode\" in FancyActionBar+.\n\n" ..
                                        "Controller players should also turn OFF \"Use Thin Frame\" in both FancyActionBar+ and AnimatedActionBar+ for the best result.\n\n" ..
                                        "If that still does not fix it, please contact me on Discord (haze.3169) so we can sort the problem out together.",

    SI_AAB_DLG_TITLE              = "AnimatedActionBar+",
    SI_AAB_DLG_BODY               = "Thanks for installing AnimatedActionBar+!\n\n" ..
                                        "Using the \"Thin Frames\" frame style together with FancyActionBar+? Please read the compatibility note.\n\n" ..
                                        "Playing on controller? Please check the \"Info\" tab as well.\n\n" ..
                                        "Open the settings and check the \"Info\" tab for the details. Type /aabcmds in chat for a list of all commands.",
    SI_AAB_DLG_OK                 = "Got it",

    -- studio
    SI_AAB_UI_TITLE_SUB           = "Studio",
    SI_AAB_UI_MODE_KB             = "Keyboard",
    SI_AAB_UI_MODE_GP             = "Controller",
    SI_AAB_UI_PREVIEW             = "Live preview",
    SI_AAB_UI_PREVIEW_SUB         = "Every change shows up here instantly",
    SI_AAB_UI_PV_PRESS            = "Press",
    SI_AAB_UI_PV_PROC             = "Proc",
    SI_AAB_UI_PV_EXPIRE           = "Expire",
    SI_AAB_UI_PV_ULT              = "Ultimate",
    SI_AAB_UI_PV_POTION           = "Potion",
    SI_AAB_UI_PV_AUTO             = "Auto demo",
    SI_AAB_UI_PV_READY            = "Ready",
    SI_AAB_UI_PV_COOLDOWN         = "Cooldown...",
    SI_AAB_UI_TAB_QUICK           = "Quickslot",
    SI_AAB_UI_QUICK_DESC          = "Animations for the quickslot (Q): bounce when you drink a potion and bounce + glow as soon as it is ready again. Uses the bounce and glow settings.",
    SI_AAB_UI_HDR_EXPIRE          = "Expire animation",
    SI_AAB_UI_HDR_ULTCTRL         = "Controller frame",
    SI_AAB_UI_HDR_NEGATIVE        = "Negative values",
    SI_AAB_UI_HDR_GAMEPAD         = "Controller",
    SI_AAB_UI_NEG_NOTE            = "Every number can also be set below zero - drag the slider past the zero mark or type any value into the box.\n\n" ..
                                        "- Negative times count as their absolute value.\n" ..
                                        "- Negative paddings pull the glow or frame inside the slot.\n" ..
                                        "- Negative strength flips the expire animation (grow becomes shrink).\n" ..
                                        "- Negative alpha or brightness simply means invisible.",
    SI_AAB_UI_NEG_SHORT           = "Every value can go below zero: type it into the box or drag past the zero mark. Negative paddings move effects inside the slot, negative strength flips the animation.",
    SI_AAB_UI_ULTCTRL_SPREAD      = "Full-glow spread",
    SI_AAB_UI_ULTCTRL_SPREAD_TT   = "How far the full-ultimate glow reaches beyond the frame. Negative = glow sits inside the frame.",
    SI_AAB_UI_ULTCTRL_PULSEMS     = "Full-glow flash",
    SI_AAB_UI_ULTCTRL_PULSEMS_TT  = "Length of the flash when the ultimate becomes full (ms).",
    SI_AAB_UI_ULTCTRL_POLL        = "Update interval",
    SI_AAB_UI_ULTCTRL_POLL_TT     = "How often the controller frame follows your ultimate (ms). Lower = smoother, higher = cheaper.",
    SI_AAB_UI_RESET_PAGE          = "Reset page",
    SI_AAB_UI_RESET_ALL           = "Reset everything",
    SI_AAB_UI_CONFIRM             = "Sure? Click again",
    SI_AAB_UI_DEFAULT             = "Default",
    SI_AAB_UI_KB_CHANGE           = "Change",
    SI_AAB_UI_KB_PREVIEW          = "Preview",
    SI_AAB_UI_KB_PREV_TAB         = "Previous tab",
    SI_AAB_UI_KB_NEXT_TAB         = "Next tab",
    SI_AAB_UI_KB_CLOSE            = "Close",
    SI_AAB_UI_HINT_KEYBOARD       = "Hover a setting for details. Mouse wheel changes sliders and choices step by step.",
    SI_AAB_UI_HINT_GAMEPAD        = "Select a setting for details. Left/right changes the value.",
    SI_AAB_UI_LAM_OPEN            = "Open AnimatedActionBar+ Studio",
    SI_AAB_UI_LAM_DESC            = "Every setting is also available in the AnimatedActionBar+ Studio with live preview. Open it with /aab ui.",
    SI_AAB_UI_XYZ_GP              = "Interface switched to controller mode. Type /aab xyz again to go back.",
    SI_AAB_UI_XYZ_KB              = "Interface switched to keyboard mode. Type /aab xyz again to go back.",
    SI_AAB_UI_XYZ_RESTORE         = "Previous input mode restored.",
    SI_AAB_UI_GP_KBLAYOUT         = "PC layout in controller mode",
    SI_AAB_UI_GP_KBLAYOUT_TT      = "Keeps the action bar exactly like on PC while in controller mode: same slot sizes and spacing, radial cooldowns, no LB/RB icons on the ultimate. Turning it off needs a reload.",
    SI_AAB_UI_HDR_ULTGP           = "Gamepad ultimate frame",
    SI_AAB_UI_HDR_STUDIO          = "Studio",
    SI_AAB_UI_THEME               = "Studio design",
    SI_AAB_UI_THEME_TT            = "Look of this window. Switches live, no reload needed.",
    SI_AAB_UI_THEME_NEBULA        = "Star Nebula",
    SI_AAB_UI_THEME_LACE          = "Raven Lace",
    SI_AAB_UI_BGMOTION            = "Animated background",
    SI_AAB_UI_BGMOTION_TT         = "Drifting nebula, twinkling stars and shooting stars in the studio. Only runs while the studio is open. Turn off for a still background.",
    SI_AAB_UI_KB_THEME            = "Design",
    SI_AAB_ULTGP_ENABLE           = "Show gamepad ultimate frame",
    SI_AAB_ULTGP_ENABLE_TT        = "Shows the ultimate frame from the controller UI (like in FAB+) with its fill animation, in keyboard and controller mode. Works on top of all other ultimate effects.",
    SI_AAB_ULTGP_FRAMECOLOR       = "Frame color",
    SI_AAB_ULTGP_FRAMECOLOR_TT    = "Tint of the frame. White keeps the original colors.",
    SI_AAB_ULTGP_FILLCOLOR        = "Fill color",
    SI_AAB_ULTGP_FILLCOLOR_TT     = "Tint of the fill bars on both sides. White keeps the original colors.",
    SI_AAB_ULTGP_FULL_ENABLE      = "Own color when full",
    SI_AAB_ULTGP_FULL_ENABLE_TT   = "Frame and fill switch to a separate color as soon as the ultimate is ready.",
    SI_AAB_ULTGP_FULLCOLOR        = "Color when full",
    SI_AAB_ULTGP_FULLCOLOR_TT     = "Color of frame and fill while the ultimate is ready.",
    SI_AAB_ULTGP_RAINBOW          = "Rainbow when full",
    SI_AAB_ULTGP_RAINBOW_TT       = "Frame and fill cycle through the rainbow while the ultimate is ready. Uses the rainbow saturation and lightness.",
}

for stringId, stringValue in pairs(strings) do
    ZO_CreateStringId(stringId, stringValue)
    SafeAddVersion(stringId, 1)
end
