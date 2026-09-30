-- Frostfall: Configuration Menu  (v3.4.18)
-- Uses LibAddonMenu-2.0 (LAM2).

Frostfall_ConfigMenu = Frostfall_ConfigMenu or {}
local CFG = Frostfall_ConfigMenu

local FV = Frostfall

local PANEL_DATA = {
    type             = "panel",
    -- Must NOT be the bare addon name: LibAddonMenu creates the panel
    -- control under this name, and ESO exposes every named control as a
    -- global - "Frostfall" here replaced the global Frostfall addon table
    -- with the panel control, silently breaking other addons (e.g. RND)
    -- that read Frostfall:GetEffectiveTemp(). See v3.4.34.
    name             = "FrostfallPanel",
    displayName      = "Frostfall — Temperature System",
    author           = "@Kreksar5 and Claude.ai",
    version          = FV.VERSION,
    slashCommand     = "/frostfall config",
    registerForRefresh  = true,
    registerForDefaults = true,
}

-- ============================================================
-- EMOTE DROPDOWN HELPER
-- ============================================================

-- EmoteDropdown builds against FV.EMOTE_CHOICES_LABELS / FV.EMOTE_CHOICES_VALUES
-- which are populated at Initialize() time from PLAYER_EMOTE_MANAGER.
-- Values are stable emoteIds; GetEmoteIndex() is called at play time.
local function EmoteDropdown(name, tooltip, svKey, defaultSvKey)
    return {
        type          = "dropdown",
        name          = name,
        tooltip       = tooltip,
        choices       = FV.EMOTE_CHOICES_LABELS,
        choicesValues = FV.EMOTE_CHOICES_VALUES,
        getFunc       = function()
            -- Return the saved emoteId, falling back to the resolved default
            if FV.SV and FV.SV[svKey] then
                return FV.SV[svKey]
            end
            return FV.EMOTE_DEFAULTS[defaultSvKey] or 0
        end,
        setFunc       = function(val)
            if FV.SV then FV.SV[svKey] = val end
        end,
        default       = function() return FV.EMOTE_DEFAULTS[defaultSvKey] or 0 end,
    }
end

-- ============================================================
-- OPTIONS
-- ============================================================

local function BuildOptions()
    return {

        -- ── GENERAL ──────────────────────────────────────────────────────────
        { type = "header", name = "General Settings" },
        {
            type    = "checkbox",
            name    = "Enable Frostfall",
            tooltip = "Master toggle for the entire temperature system. Turning this off "
                   .. "immediately hides the HUD and any active overlay and stops all "
                   .. "temperature checking; turning it back on resumes immediately.",
            getFunc = function() return FV.SV.enabled end,
            setFunc = function(val) FV:SetEnabled(val) end,
            default = FV.Defaults.enabled,
        },
        {
            type    = "slider",
            name    = "Temperature Update Interval (minutes)",
            tooltip = "How often Frostfall recalculates your temperature and updates the HUD and "
                   .. "overlay. Lower values are more responsive. Emotes run on a separate fast "
                   .. "15-second loop regardless of this setting. Requires /reloadui to take effect.",
            min     = 1, max = 10, step = 1,
            getFunc = function() return FV.SV.updateIntervalMinutes end,
            setFunc = function(val) FV.SV.updateIntervalMinutes = math.max(1, math.min(10, val)) end,
            default = FV.Defaults.updateIntervalMinutes,
        },
        {
            type    = "slider",
            name    = "Temperature Adaptation Rate",
            tooltip = "How fast your character's temperature drifts toward the ambient zone "
                   .. "temperature, in \xc2\xb0C per minute at neutral (50) insulation. Higher values "
                   .. "mean faster swings between hot and cold; lower values mean a slower, more "
                   .. "gradual adjustment. Actual drift speed is still scaled by your armor "
                   .. "insulation on top of this base rate.",
            min     = 0.25, max = 5.0, step = 0.25,
            getFunc = function() return FV.SV.driftRate end,
            setFunc = function(val) FV.SV.driftRate = math.max(0.25, math.min(5.0, val)) end,
            default = FV.Defaults.driftRate,
        },
        {
            type    = "checkbox",
            name    = "Display temperatures in Fahrenheit",
            tooltip = "When enabled, all temperatures on the HUD and in chat are shown in \xc2\xb0F. "
                   .. "When disabled, temperatures are shown in \xc2\xb0C. "
                   .. "Does not affect internal calculations.",
            getFunc = function() return FV.SV.useFahrenheit end,
            setFunc = function(val)
                FV.SV.useFahrenheit = val
                if Frostfall_HUD and Frostfall_HUD.controls_created then
                    Frostfall_HUD:Update(FV.State.playerTemp, FV.State)
                end
            end,
            default = FV.Defaults.useFahrenheit,
        },

        -- ── HUD ──────────────────────────────────────────────────────────────
        { type = "header", name = "Temperature HUD" },
        {
            type    = "checkbox",
            name    = "Show Thermal Status HUD",
            tooltip = "Display the temperature status window on your screen. Turn this off if "
                   .. "you'd rather rely only on temperature emotes and the top-of-screen alert "
                   .. "notifications (see \"Temperature Effects\" and \"Temperature Emotes\" "
                   .. "below) instead of a persistent on-screen window.",
            getFunc = function() return FV.SV.showHUD end,
            setFunc = function(val)
                FV.SV.showHUD = val
                if Frostfall_HUD and Frostfall_HUD.container then
                    Frostfall_HUD.container:SetHidden(not val)
                end
            end,
            default = FV.Defaults.showHUD,
        },
        {
            type = "slider", name = "HUD Scale",
            tooltip = "Scale the temperature HUD.",
            min = 0.5, max = 2.0, step = 0.05, decimals = 2,
            getFunc = function() return FV.SV.hudScale end,
            setFunc = function(val)
                FV.SV.hudScale = val
                if Frostfall_HUD and Frostfall_HUD.container then
                    Frostfall_HUD.container:SetScale(val)
                end
            end,
            default = FV.Defaults.hudScale,
        },
        {
            type = "slider", name = "HUD Opacity",
            tooltip = "Transparency of the temperature HUD — lower values make the status "
                   .. "window more see-through. Only relevant while \"Show Thermal Status HUD\" "
                   .. "above is enabled.",
            min = 0.1, max = 1.0, step = 0.05, decimals = 2,
            getFunc = function() return FV.SV.hudAlpha end,
            setFunc = function(val)
                FV.SV.hudAlpha = val
                if Frostfall_HUD and Frostfall_HUD.container then
                    Frostfall_HUD.container:SetAlpha(val)
                end
            end,
            default = FV.Defaults.hudAlpha,
        },

        -- ── EFFECTS ──────────────────────────────────────────────────────────
        { type = "header", name = "Temperature Effects" },
        {
            type    = "checkbox",
            name    = "Enable Screen Overlay",
            tooltip = "Show a blue or red vignette at extreme temperatures.",
            getFunc = function() return FV.SV.enableOverlay end,
            setFunc = function(val) FV.SV.enableOverlay = val end,
            default = FV.Defaults.enableOverlay,
        },
        {
            type = "slider", name = "Screen Overlay Max Opacity",
            tooltip = "Caps how strong the hot/cold screen vignette can get even at the most "
                   .. "extreme temperatures (Freeze Danger / Heat Danger) — the overlay still "
                   .. "fades in gradually from 0 as you approach those extremes, this just lowers "
                   .. "the ceiling it fades up to. Separate from HUD Opacity above, which only "
                   .. "affects the status window. Only relevant while \"Enable Screen Overlay\" "
                   .. "above is enabled. Default (0.75) matches the overlay's original, "
                   .. "previously-fixed strength.",
            min = 0.1, max = 1.0, step = 0.05, decimals = 2,
            getFunc = function() return FV.SV.overlayMaxOpacity end,
            setFunc = function(val) FV.SV.overlayMaxOpacity = val end,
            default = FV.Defaults.overlayMaxOpacity,
        },
        {
            type    = "checkbox",
            name    = "Show native top-screen notifications",
            tooltip = "Show Frostfall's notifications (band transitions, spell-resist reagent "
                   .. "buff, water/station warming) as the native top-of-screen alert banner.",
            getFunc = function() return FV.SV.showTopNotifications end,
            setFunc = function(val) FV.SV.showTopNotifications = val end,
            default = FV.Defaults.showTopNotifications,
        },
        {
            type    = "checkbox",
            name    = "Also log notifications to chat",
            tooltip = "Also print the same notifications to the chat window, in addition to (or "
                   .. "instead of) the top-of-screen banner above.",
            getFunc = function() return FV.SV.alsoLogChat end,
            setFunc = function(val) FV.SV.alsoLogChat = val end,
            default = FV.Defaults.alsoLogChat,
        },

        -- ── EMOTES ───────────────────────────────────────────────────────────
        { type = "header", name = "Temperature Emotes" },
        {
            type    = "checkbox",
            name    = "Enable Temperature Emotes",
            tooltip = "Automatically play an emote while your temperature is extreme. "
                   .. "The emote repeats every 15 seconds while you remain in a cold or hot band. "
                   .. "Suppressed during combat, while mounted, and when any UI panel is open.",
            getFunc = function() return FV.SV.enableEmotes end,
            setFunc = function(val) FV.SV.enableEmotes = val end,
            default = FV.Defaults.enableEmotes,
        },
        {
            type = "description",
            text = "Emotes play every 15 s while in a temperature band. "
                .. "Defaults are resolved automatically from your installed emotes at login. "
                .. "The dropdown lists every emote you own. Values are stable emote IDs "
                .. "(not raw indices), so they survive game patches. "
                .. "Ranges: Very Cold < 0°C (32°F), Cold 0–10°C (32–50°F), "
                .. "Hot 35–41°C (95–104°F), Very Hot ≥41°C (≥105°F).",
        },
        EmoteDropdown(
            "Very Cold Emote  (< 0°C / 32°F)",
            "Plays every 15 s while player temp is below 0°C (32°F). No lower cap. Default: \"Shivering Cold\" emote.",
            "emoteIdVeryCold", "very_cold"
        ),
        EmoteDropdown(
            "Cold Emote  (0–10°C / 32–50°F)",
            "Plays every 15 s while player temp is 0–10°C (32–50°F). Default: \"Shiver Cold\" emote.",
            "emoteIdCold", "cold"
        ),
        EmoteDropdown(
            "Hot Emote  (35–41°C / 95–104°F)",
            "Plays every 15 s while player temp is 35–41°C (95–104°F). Default: \"Wipe Brow\" emote.",
            "emoteIdHot", "hot"
        ),
        EmoteDropdown(
            "Very Hot Emote  (≥41°C / ≥105°F)",
            "Plays every 15 s while player temp is ≥41°C (≥105°F). Default: \"Breathless\" emote.",
            "emoteIdScorching", "scorching"
        ),

        -- ── DEBUG ─────────────────────────────────────────────────────────────
        -- Debug logging, print-status, force-update, and reset-to-default were
        -- previously checkboxes/buttons here. They're now slash commands
        -- instead: /ff debug enable|disable|status|update|reset|resetStatus
        -- (see /ff help for the full list).
        { type = "header", name = "Debug" },
        {
            type = "description",
            text = "Debug options have moved to slash commands: "
                .. "|cADD8E6/ff debug enable|r, |cADD8E6/ff debug disable|r, "
                .. "|cADD8E6/ff debug status|r, |cADD8E6/ff debug update|r, "
                .. "|cADD8E6/ff debug reset|r, |cADD8E6/ff debug resetStatus|r. "
                .. "Type |cADD8E6/ff help|r for the full command list.",
        },
    }
end

-- ============================================================
-- REGISTER
-- ============================================================

function CFG:Initialize()
    local LAM = LibAddonMenu2
    LAM:RegisterAddonPanel(PANEL_DATA.name, PANEL_DATA)
    LAM:RegisterOptionControls(PANEL_DATA.name, BuildOptions())
end

function CFG:Show()
    LAMOpenToPanel(PANEL_DATA.name)
end
