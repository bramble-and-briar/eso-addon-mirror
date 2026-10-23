-----------------------------------------------------
-- AnimatedActionBar+ Studio
-----------------------------------------------------
local WM    = WINDOW_MANAGER
local EM    = EVENT_MANAGER
local MEDIA = "AnimatedActionBarPlus/media/"

AnimatedActionBarPlus = AnimatedActionBarPlus or {}
local Studio = {}
AnimatedActionBarPlus.Studio = Studio

local api, sv, defaults

-- api gibts erst nach ADD_ON_LOADED
local function Api()
    if not api then
        api = AnimatedActionBarPlus._studioApi
        if api then
            sv       = api.GetSV()
            defaults = api.GetDefaults()
        end
    end
    return api and sv and api or nil
end

-- farben

local function Hex(h, a)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, a or 1 }
end

-- zwei designs. alles was nicht hier steht ist bei beiden gleich
-- ebenen: tile = wie viele pixel eine kachel auf dem fenster belegt, vx/vy = pixel pro sekunde
local THEMES = {
    nebula = {
        name = "SI_AAB_UI_THEME_NEBULA",
        col = {
            accent  = Hex("9d8cff"),
            accent2 = Hex("4b5fc4"),
            good    = Hex("7fe0a8"),
            bad     = Hex("ff6b8b"),
            warn    = Hex("ffc46b"),
            value   = Hex("bfd0ff"),
            dim     = Hex("8088b4"),
            text    = Hex("eef2ff"),
            cyan    = Hex("6ff0ff"),
            track   = { 0.10, 0.12, 0.26, 1 },
            panel   = { 0.025, 0.03, 0.09, 0.58 },
            stage   = { 0.0, 0.0, 0.03, 0.45 },
            field   = { 0.02, 0.025, 0.07, 0.88 },
            chip    = { 0.04, 0.05, 0.13, 0.9 },
            chipOn  = { 0.20, 0.24, 0.55, 0.95 },
            menu    = { 0.03, 0.035, 0.09, 0.97 },
            note    = { 0.02, 0.06, 0.09, 0.6 },
        },
        display = { "$(GAMEPAD_LIGHT_FONT)", "$(GAMEPAD_LIGHT_FONT)" },
        heading = { "$(MEDIUM_FONT)", "$(GAMEPAD_MEDIUM_FONT)" },
        sizes   = { kb = { 38, 28, 19, 17 }, gp = { 50, 36, 26, 22 } },
        edges = {
            frame = { "N_Frame.dds", 128, 16, 16, 4 },
            panel = { "N_Glass.dds", 128, 16, 16, 3 },
            row   = { "UI_RowEdge.dds", 128, 16, 16, 3 },
        },
        title  = "|cFFFFFFAnimated|r|cB9C8FFActionBar|r|c6FF0FF+|r",
        sep    = "|c5F6A9A•|r",
        marker = "N_Star.dds", markerF = 0.62, constellation = true,
        layers = {
            { file = "N_Nebula.dds", tile = 900, vx = -4, vy = -1.5 },
            { file = "N_Wisps.dds",  tile = 700, vx = 7, vy = 2.5, add = true, alpha = 0.8 },
            { file = "N_Stars.dds",  tile = 512, vx = -1.2, add = true },
            { file = "N_Stars.dds",  tile = 389, vx = -2.6, vy = -0.6, ox = 0.37, oy = 0.61, add = true, twinkle = 2300 },
            { file = "UI_Vignette.dds", alpha = 0.9 },
        },
        watermark = { "N_Galaxy.dds", 0.75, 0.42, true },
        comet = "N_Comet.dds",
    },
    lace = {
        name = "SI_AAB_UI_THEME_LACE",
        col = {
            accent  = Hex("c9a2e6"),
            accent2 = Hex("6e3f86"),
            good    = Hex("9fcf9a"),
            bad     = Hex("d0485f"),
            warn    = Hex("d9a46b"),
            value   = Hex("e3cdf2"),
            dim     = Hex("8f7f8d"),
            text    = Hex("f2e9ee"),
            cyan    = Hex("a9c7ff"),
            track   = { 0.18, 0.11, 0.19, 1 },
            panel   = { 0.035, 0.02, 0.04, 0.80 },
            stage   = { 0.0, 0.0, 0.0, 0.5 },
            field   = { 0.03, 0.015, 0.035, 0.9 },
            chip    = { 0.07, 0.035, 0.08, 0.9 },
            chipOn  = { 0.32, 0.16, 0.38, 0.95 },
            menu    = { 0.05, 0.025, 0.055, 0.97 },
            note    = { 0.06, 0.03, 0.07, 0.6 },
        },
        display = { "$(ANTIQUE_FONT)", "$(ANTIQUE_FONT)" },
        heading = { "$(ANTIQUE_FONT)", "$(ANTIQUE_FONT)" },
        sizes   = { kb = { 38, 28, 21, 18 }, gp = { 48, 36, 27, 23 } },
        edges = {
            frame = { "R_Frame.dds", 256, 32, 32, 0 },
            panel = { "R_Trim.dds", 128, 16, 16, 4 },
            row   = { "UI_RowEdge.dds", 128, 16, 16, 3 },
        },
        title  = "|cF2E9EEAnimated|r|cC9A2E6ActionBar|r|cD0485F+|r",
        sep    = "|c6E3F86•|r",
        marker = "R_Quill.dds", markerF = 0.78,
        layers = {
            { file = "R_Velvet.dds", tile = 512 },
            { file = "R_Mist.dds", tile = 760, vx = 5, vy = 0.8, add = true, alpha = 0.9 },
            { file = "R_Lace.dds", tile = 230, color = Hex("c9a2e6", 0.10), breathe = 4200 },
            { file = "UI_Vignette.dds", alpha = 0.95 },
        },
        watermark = { "R_Moon.dds", 0.72, 0.13 },
        corners = "R_Corner.dds",
        ornament = "R_Ornament.dds",
        feather = "R_Feather.dds",
    },
}

local T   = THEMES.nebula
local COL = T.col

local function UseTheme(id)
    T = THEMES[id] or THEMES.nebula
    COL = T.col
end

local function ThemeId()
    return (sv and THEMES[sv.uiTheme]) and sv.uiTheme or "nebula"
end

local function SetCol(ctrl, c, a)
    ctrl:SetColor(c[1], c[2], c[3], a or c[4] or 1)
end

local LAYOUT = {
    keyboard = {
        w = 1260, h = 770, pad = 18, header = 96, footer = 58,
        nav = 256, preview = 352, tabH = 44, rowH = 46, logo = 74,
        icon = 26, toggleW = 46, toggleH = 24, sliderW = 140, editW = 70, choiceW = 214,
        slot = 42, stageH = 214, chipF = 0.78,
        fTitle  = "$(BOLD_FONT)|34|soft-shadow-thick",
        fSub    = "$(MEDIUM_FONT)|14|soft-shadow-thin",
        fNav    = "$(BOLD_FONT)|17|soft-shadow-thin",
        fPage   = "$(BOLD_FONT)|26|soft-shadow-thick",
        fLabel  = "$(MEDIUM_FONT)|17|soft-shadow-thin",
        fValue  = "$(BOLD_FONT)|16|soft-shadow-thin",
        fHeader = "$(BOLD_FONT)|19|soft-shadow-thick",
        fDesc   = "$(MEDIUM_FONT)|15|soft-shadow-thin",
        fSmall  = "$(MEDIUM_FONT)|14|soft-shadow-thin",
        fChip   = "$(BOLD_FONT)|14|soft-shadow-thin",
    },
    gamepad = {
        w = 1600, h = 900, pad = 24, header = 116, footer = 70,
        nav = 330, preview = 440, tabH = 58, rowH = 64, logo = 96,
        icon = 34, toggleW = 62, toggleH = 32, sliderW = 190, editW = 96, choiceW = 280,
        slot = 54, stageH = 236, chipF = 0.68,
        fTitle  = "$(GAMEPAD_BOLD_FONT)|46|soft-shadow-thick",
        fSub    = "$(GAMEPAD_MEDIUM_FONT)|20|soft-shadow-thin",
        fNav    = "$(GAMEPAD_BOLD_FONT)|22|soft-shadow-thin",
        fPage   = "$(GAMEPAD_BOLD_FONT)|34|soft-shadow-thick",
        fLabel  = "$(GAMEPAD_MEDIUM_FONT)|24|soft-shadow-thin",
        fValue  = "$(GAMEPAD_BOLD_FONT)|22|soft-shadow-thin",
        fHeader = "$(GAMEPAD_BOLD_FONT)|26|soft-shadow-thick",
        fDesc   = "$(GAMEPAD_MEDIUM_FONT)|21|soft-shadow-thin",
        fSmall  = "$(GAMEPAD_MEDIUM_FONT)|19|soft-shadow-thin",
        fChip   = "$(GAMEPAD_BOLD_FONT)|19|soft-shadow-thin",
    },
}

-- layout pro modus + design: titel, seiten, überschriften und tabs kommen vom design
local function MakeLayout(mode, th)
    local L = {}
    for k, v in pairs(LAYOUT[mode]) do L[k] = v end
    local i = (mode == "gamepad") and 2 or 1
    local sz = (mode == "gamepad") and th.sizes.gp or th.sizes.kb
    L.fTitle  = th.display[i] .. "|" .. sz[1] .. "|soft-shadow-thick"
    L.fPage   = th.display[i] .. "|" .. sz[2] .. "|soft-shadow-thick"
    L.fHeader = th.heading[i] .. "|" .. sz[3] .. "|soft-shadow-thick"
    L.fNav    = th.heading[i] .. "|" .. sz[4] .. "|soft-shadow-thin"
    return L
end

local uid = 0
local function N(prefix)
    uid = uid + 1
    return "AABStudio_" .. prefix .. uid
end

local function Tex(parent, file, level)
    local t = WM:CreateControl(N("T"), parent, CT_TEXTURE)
    if file then t:SetTexture(file) end
    t:SetDrawLevel(level or 2)
    return t
end

local function Lbl(parent, font, color, text)
    local l = WM:CreateControl(N("L"), parent, CT_LABEL)
    l:SetDrawLevel(6)
    l:SetFont(font)
    SetCol(l, color or COL.text)
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    if text then l:SetText(text) end
    return l
end

-- kind: "row", "panel" oder "frame", die kante kommt vom design
local function Box(parent, kind, edgeCol, edgeA, centerCol, level)
    local e = T.edges[kind or "row"] or T.edges.row
    local b = WM:CreateControl(N("B"), parent, CT_BACKDROP)
    b:SetEdgeTexture(MEDIA .. e[1], e[2], e[3], e[4], 0)
    b:SetEdgeColor(edgeCol[1], edgeCol[2], edgeCol[3], edgeA or 1)
    local c = centerCol or { 0, 0, 0, 0 }
    b:SetCenterColor(c[1], c[2], c[3], c[4])
    b:SetInsets(e[5], e[5], -e[5], -e[5])
    if level then b:SetDrawLevel(level) end
    return b
end

-- große texturen merken, beim schließen wieder freigeben
local function Heavy(w, ctrl, file)
    if ctrl.SetTextureReleaseOption and RELEASE_TEXTURE_AT_ZERO_REFERENCES then
        ctrl:SetTextureReleaseOption(RELEASE_TEXTURE_AT_ZERO_REFERENCES)
    end
    ctrl:SetTexture(file)
    w.heavy[#w.heavy + 1] = { ctrl, file }
end

local function LoadHeavy(w, on)
    if w.heavyOn == on then return end
    w.heavyOn = on
    for _, h in ipairs(w.heavy) do h[1]:SetTexture(on and h[2] or "") end
end

local function Hit(parent, target, level)
    local h = WM:CreateControl(N("Hit"), parent, CT_CONTROL)
    h:SetAnchorFill(target or parent)
    h:SetDrawLevel(level or 20)
    h:SetMouseEnabled(true)
    return h
end

local function Sound(s)
    if s and PlaySound then PlaySound(s) end
end

local function Click() Sound(SOUNDS and SOUNDS.DEFAULT_CLICK) end

local function Tween(ctrl, dur, fn, done)
    local t0 = GetFrameTimeMilliseconds()
    ctrl:SetHandler("OnUpdate", function()
        local p = (GetFrameTimeMilliseconds() - t0) / dur
        if p >= 1 then p = 1 end
        fn(ZO_EaseOutQuadratic and ZO_EaseOutQuadratic(p) or p)
        if p >= 1 then
            ctrl:SetHandler("OnUpdate", nil)
            if done then done() end
        end
    end)
end

local function Lerp(a, b, t) return a + (b - a) * t end

local function CopyValue(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = x end
    return t
end

local function S(id) return GetString(id) end

-- seiten

local function Invalidate() api.InvalidateAnimTimelines() end
local function RestartPulses() api.RestartActivePulses() end
local function RefreshUlt() api.RefreshUltDisplay() end
local function NotCtrl() return sv.ultBorderStyle == "controller" end
local function IsCtrl() return sv.ultBorderStyle == "controller" and sv.ultReadyEnabled end

local PAGES

local function BuildPageDefs()
    if PAGES then return PAGES end
    PAGES = {
        {
            id = "presets", icon = "UI_Icon_Presets", title = SI_AAB_SUB_PRESETS, tip = SI_AAB_SUB_PRESETS_TT,
            demo = "press",
            controls = {
                { type = "desc", text = SI_AAB_PRESETS_DESC },
                { type = "button", name = SI_AAB_PRESET_MINIMAL, tip = SI_AAB_PRESET_MINIMAL_TT, preview = "press",
                  func = function() api.ApplyPreset("minimal") end },
                { type = "button", name = SI_AAB_PRESET_STANDARD, tip = SI_AAB_PRESET_STANDARD_TT, preview = "press",
                  func = function() api.ApplyPreset("standard") end },
                { type = "button", name = SI_AAB_PRESET_FLASHY, tip = SI_AAB_PRESET_FLASHY_TT, preview = "press",
                  func = function() api.ApplyPreset("flashy") end },
                { type = "desc", text = SI_AAB_PRESETS_NOTE },
                { type = "header", name = SI_AAB_UI_HDR_NEGATIVE },
                { type = "desc", text = SI_AAB_UI_NEG_NOTE },
            },
        },
        {
            id = "bounce", icon = "UI_Icon_Bounce", title = SI_AAB_SUB_BOUNCE, tip = SI_AAB_SUB_BOUNCE_TT,
            demo = "bounce",
            controls = {
                { type = "toggle", key = "bounceEnabled", name = SI_AAB_BOUNCE_ENABLE, tip = SI_AAB_BOUNCE_ENABLE_TT, preview = "press" },
                { type = "choice", key = "animationStyle", name = SI_AAB_ANIM_STYLE, tip = SI_AAB_ANIM_STYLE_TT, preview = "press",
                  choices = { { "bounce", SI_AAB_ANIM_BOUNCE }, { "flash", SI_AAB_ANIM_FLASH }, { "shake", SI_AAB_ANIM_SHAKE }, { "tilt", SI_AAB_ANIM_TILT } },
                  disabled = function() return not sv.bounceEnabled end },
                { type = "toggle", key = "bounceOnProc", name = SI_AAB_BOUNCE_ON_PROC, tip = SI_AAB_BOUNCE_ON_PROC_TT, preview = "proc",
                  disabled = function() return not sv.bounceEnabled end },
                { type = "slider", key = "growScale", name = SI_AAB_BOUNCE_GROW, tip = SI_AAB_BOUNCE_GROW_TT,
                  min = -2, max = 3, step = 0.05, dec = 2, apply = Invalidate, preview = "press",
                  disabled = function() return not sv.bounceEnabled end },
                { type = "slider", key = "shrinkScale", name = SI_AAB_BOUNCE_SHRINK, tip = SI_AAB_BOUNCE_SHRINK_TT,
                  min = -2, max = 2, step = 0.05, dec = 2, apply = Invalidate, preview = "press",
                  disabled = function() return not sv.bounceEnabled end },
                { type = "slider", key = "frameResetTimeMS", name = SI_AAB_BOUNCE_RESET, tip = SI_AAB_BOUNCE_RESET_TT,
                  min = -1000, max = 1000, step = 10, dec = 0, apply = Invalidate, preview = "press",
                  disabled = function() return not sv.bounceEnabled end },

                { type = "header", name = SI_AAB_UI_HDR_EXPIRE },
                { type = "desc", text = SI_AAB_EXPIRE_DESC },
                { type = "toggle", key = "expireAnimEnabled", name = SI_AAB_EXPIRE_ENABLE, tip = SI_AAB_EXPIRE_ENABLE_TT, preview = "expire" },
                { type = "choice", key = "expireAnimStyle", name = SI_AAB_EXPIRE_STYLE, tip = SI_AAB_EXPIRE_STYLE_TT, preview = "expire",
                  choices = { { "inherit", SI_AAB_EXPIRE_STYLE_INHERIT }, { "bounce", SI_AAB_ANIM_BOUNCE }, { "flash", SI_AAB_ANIM_FLASH },
                              { "shake", SI_AAB_ANIM_SHAKE }, { "tilt", SI_AAB_ANIM_TILT } },
                  disabled = function() return not sv.expireAnimEnabled end },
                { type = "slider", key = "expireStrength", name = SI_AAB_EXPIRE_STRENGTH, tip = SI_AAB_EXPIRE_STRENGTH_TT,
                  min = -3, max = 3, step = 0.05, dec = 2, apply = Invalidate, preview = "expire",
                  disabled = function() return not sv.expireAnimEnabled end },
                { type = "toggle", key = "expireGlowEnabled", name = SI_AAB_EXPIRE_GLOW_ENABLE, tip = SI_AAB_EXPIRE_GLOW_ENABLE_TT, preview = "expire",
                  disabled = function() return not sv.expireAnimEnabled end },
                { type = "color", key = "expireGlowColor", name = SI_AAB_EXPIRE_GLOW_COLOR, tip = SI_AAB_EXPIRE_GLOW_COLOR_TT, preview = "expire",
                  disabled = function() return not sv.expireAnimEnabled or not sv.expireGlowEnabled end },
                { type = "desc", text = SI_AAB_EXPIRE_SCALE_DESC },
                { type = "toggle", key = "expireScaleByDuration", name = SI_AAB_EXPIRE_SCALE_ENABLE, tip = SI_AAB_EXPIRE_SCALE_ENABLE_TT,
                  apply = Invalidate, preview = "expire",
                  disabled = function() return not sv.expireAnimEnabled end },
                { type = "slider", key = "expireScaleRefMS", name = SI_AAB_EXPIRE_SCALE_REF, tip = SI_AAB_EXPIRE_SCALE_REF_TT,
                  min = -30000, max = 30000, step = 500, dec = 0, apply = Invalidate, preview = "expire",
                  disabled = function() return not sv.expireAnimEnabled or not sv.expireScaleByDuration end },
                { type = "slider", key = "expireScaleMin", name = SI_AAB_EXPIRE_SCALE_MIN, tip = SI_AAB_EXPIRE_SCALE_MIN_TT,
                  min = -3, max = 3, step = 0.05, dec = 2, apply = Invalidate, preview = "expire",
                  disabled = function() return not sv.expireAnimEnabled or not sv.expireScaleByDuration end },
                { type = "slider", key = "expireScaleMax", name = SI_AAB_EXPIRE_SCALE_MAX, tip = SI_AAB_EXPIRE_SCALE_MAX_TT,
                  min = -3, max = 5, step = 0.05, dec = 2, apply = Invalidate, preview = "expire",
                  disabled = function() return not sv.expireAnimEnabled or not sv.expireScaleByDuration end },
                { type = "button", name = SI_AAB_EXPIRE_OVERRIDE_CLEAR, tip = SI_AAB_EXPIRE_OVERRIDE_CLEAR_TT,
                  func = function() sv.expireDurationOverride = {} end,
                  disabled = function() return not sv.expireAnimEnabled end },
                { type = "desc", text = SI_AAB_EXPIRE_OVERRIDE_NOTE },
            },
        },
        {
            id = "glow", icon = "UI_Icon_Glow", title = SI_AAB_SUB_GLOW, tip = SI_AAB_SUB_GLOW_TT,
            demo = "press",
            controls = {
                { type = "toggle", key = "glowEnabled", name = SI_AAB_GLOW_ENABLE, tip = SI_AAB_GLOW_ENABLE_TT, preview = "press" },
                { type = "color", key = "glowColor", name = SI_AAB_GLOW_COLOR, tip = SI_AAB_GLOW_COLOR_TT, preview = "press",
                  apply = RestartPulses, disabled = function() return not sv.glowEnabled end },
                { type = "slider", key = "glowDurationMS", name = SI_AAB_GLOW_DURATION, tip = SI_AAB_GLOW_DURATION_TT,
                  min = -3000, max = 3000, step = 50, dec = 0, preview = "press",
                  disabled = function() return not sv.glowEnabled end },
                { type = "slider", key = "glowPadding", name = SI_AAB_GLOW_PADDING, tip = SI_AAB_GLOW_PADDING_TT,
                  min = -40, max = 40, step = 1, dec = 0, apply = RestartPulses, preview = "press",
                  disabled = function() return not sv.glowEnabled end },
                { type = "slider", key = "glowIntensity", name = SI_AAB_GLOW_INTENSITY, tip = SI_AAB_GLOW_INTENSITY_TT,
                  min = -2, max = 3, step = 0.05, dec = 2, apply = RestartPulses, preview = "press",
                  disabled = function() return not sv.glowEnabled end },
            },
        },
        {
            id = "pulse", icon = "UI_Icon_Pulse", title = SI_AAB_SUB_PULSE, tip = SI_AAB_SUB_PULSE_TT,
            demo = "proc",
            controls = {
                { type = "toggle", key = "pulseEnabled", name = SI_AAB_PULSE_ENABLE, tip = SI_AAB_PULSE_ENABLE_TT, preview = "proc",
                  apply = function(v) if not v then api.StopAllPulses() else api.RefreshAllProcs() end end,
                  disabled = function() return not sv.glowEnabled end },
                { type = "toggle", key = "vanillaProcGlow", name = SI_AAB_PROC_VANILLA_GLOW, tip = SI_AAB_PROC_VANILLA_GLOW_TT,
                  reload = true, apply = function() api.RefreshProcGlowSuppression() end },
                { type = "toggle", key = "stopGlowOnPress", name = SI_AAB_PULSE_STOP_ON_PRESS, tip = SI_AAB_PULSE_STOP_ON_PRESS_TT,
                  disabled = function() return not sv.pulseEnabled end },
                { type = "choice", key = "pulseMode", name = SI_AAB_PULSE_STYLE, tip = SI_AAB_PULSE_STYLE_TT, preview = "proc",
                  choices = { { "smooth", SI_AAB_PULSE_STYLE_SMOOTH }, { "blink", SI_AAB_PULSE_STYLE_BLINK }, { "strobe", SI_AAB_PULSE_STYLE_STROBE } },
                  apply = RestartPulses, disabled = function() return not sv.pulseEnabled end },
                { type = "slider", key = "pulseDurationMS", name = SI_AAB_PULSE_SMOOTH_DUR, tip = SI_AAB_PULSE_SMOOTH_DUR_TT,
                  min = -2000, max = 2000, step = 50, dec = 0, apply = RestartPulses, preview = "proc",
                  disabled = function() return not sv.pulseEnabled or sv.pulseMode ~= "smooth" end },
                { type = "slider", key = "blinkIntervalMS", name = SI_AAB_PULSE_BLINK_INT, tip = SI_AAB_PULSE_BLINK_INT_TT,
                  min = -800, max = 800, step = 10, dec = 0, apply = RestartPulses, preview = "proc",
                  disabled = function() return not sv.pulseEnabled or sv.pulseMode ~= "blink" end },
                { type = "slider", key = "strobeIntervalMS", name = SI_AAB_PULSE_STROBE_INT, tip = SI_AAB_PULSE_STROBE_INT_TT,
                  min = -200, max = 200, step = 5, dec = 0, apply = RestartPulses, preview = "proc",
                  disabled = function() return not sv.pulseEnabled or sv.pulseMode ~= "strobe" end },
                { type = "slider", key = "pulseMinAlpha", name = SI_AAB_PULSE_MIN_ALPHA, tip = SI_AAB_PULSE_MIN_ALPHA_TT,
                  min = -1, max = 1, step = 0.05, dec = 2, apply = RestartPulses, preview = "proc",
                  disabled = function() return not sv.pulseEnabled end },
                { type = "slider", key = "pulseMaxAlpha", name = SI_AAB_PULSE_MAX_ALPHA, tip = SI_AAB_PULSE_MAX_ALPHA_TT,
                  min = -1, max = 1, step = 0.05, dec = 2, apply = RestartPulses, preview = "proc",
                  disabled = function() return not sv.pulseEnabled end },
                { type = "toggle", key = "colorCycleEnabled", name = SI_AAB_PULSE_COLOR_CYCLE, tip = SI_AAB_PULSE_COLOR_CYCLE_TT,
                  apply = RestartPulses, preview = "proc",
                  disabled = function() return not sv.pulseEnabled end },
                { type = "color", key = "colorCycleSecondary", name = SI_AAB_PULSE_COLOR_SECOND, tip = SI_AAB_PULSE_COLOR_SECOND_TT,
                  apply = RestartPulses, preview = "proc",
                  disabled = function() return not sv.pulseEnabled or not sv.colorCycleEnabled end },
            },
        },
        {
            id = "ult", icon = "UI_Icon_Ult", title = SI_AAB_SUB_ULT, tip = SI_AAB_SUB_ULT_TT,
            demo = "ult",
            controls = {
                { type = "header", name = SI_AAB_ULT_HEADER_EFFECTS },
                { type = "toggle", key = "ultBounceEnabled", name = SI_AAB_ULT_BOUNCE_ENABLE, tip = SI_AAB_ULT_BOUNCE_ENABLE_TT, preview = "ultpress" },
                { type = "toggle", key = "ultGlowEnabled", name = SI_AAB_ULT_GLOW_ENABLE, tip = SI_AAB_ULT_GLOW_ENABLE_TT, preview = "ultpress" },
                { type = "color", key = "ultGlowColor", name = SI_AAB_ULT_GLOW_COLOR, tip = SI_AAB_ULT_GLOW_COLOR_TT, preview = "ultpress",
                  disabled = function() return not sv.ultGlowEnabled end },
                { type = "slider", key = "ultGlowDurationMS", name = SI_AAB_ULT_GLOW_DURATION, tip = SI_AAB_ULT_GLOW_DURATION_TT,
                  min = -3000, max = 3000, step = 50, dec = 0, preview = "ultpress",
                  disabled = function() return not sv.ultGlowEnabled end },
                { type = "slider", key = "ultGlowPadding", name = SI_AAB_ULT_GLOW_PADDING, tip = SI_AAB_ULT_GLOW_PADDING_TT,
                  min = -40, max = 40, step = 1, dec = 0, preview = "ultpress",
                  disabled = function() return not sv.ultGlowEnabled end },
                { type = "slider", key = "ultGlowIntensity", name = SI_AAB_ULT_GLOW_INTENSITY, tip = SI_AAB_ULT_GLOW_INTENSITY_TT,
                  min = -2, max = 3, step = 0.05, dec = 2, preview = "ultpress",
                  disabled = function() return not sv.ultGlowEnabled end },

                { type = "header", name = SI_AAB_UI_HDR_ULTGP },
                { type = "toggle", key = "ultGpFrameEnabled", name = SI_AAB_ULTGP_ENABLE, tip = SI_AAB_ULTGP_ENABLE_TT, preview = "ult", apply = RefreshUlt },
                { type = "color", key = "ultGpFrameColor", name = SI_AAB_ULTGP_FRAMECOLOR, tip = SI_AAB_ULTGP_FRAMECOLOR_TT, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not sv.ultGpFrameEnabled end },
                { type = "color", key = "ultGpFillColor", name = SI_AAB_ULTGP_FILLCOLOR, tip = SI_AAB_ULTGP_FILLCOLOR_TT, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not sv.ultGpFrameEnabled end },
                { type = "toggle", key = "ultGpFullColorEnabled", name = SI_AAB_ULTGP_FULL_ENABLE, tip = SI_AAB_ULTGP_FULL_ENABLE_TT, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not sv.ultGpFrameEnabled end },
                { type = "color", key = "ultGpFullColor", name = SI_AAB_ULTGP_FULLCOLOR, tip = SI_AAB_ULTGP_FULLCOLOR_TT, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not sv.ultGpFrameEnabled or not sv.ultGpFullColorEnabled end },
                { type = "toggle", key = "ultGpRainbow", name = SI_AAB_ULTGP_RAINBOW, tip = SI_AAB_ULTGP_RAINBOW_TT, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not sv.ultGpFrameEnabled end },

                { type = "header", name = SI_AAB_ULT_HEADER_READY },
                { type = "toggle", key = "ultReadyEnabled", name = SI_AAB_ULT_ENABLE, tip = SI_AAB_ULT_ENABLE_TT, preview = "ult", apply = RefreshUlt },
                { type = "toggle", key = "vanillaUltShimmer", name = SI_AAB_ULT_VANILLA_SHIMMER, tip = SI_AAB_ULT_VANILLA_SHIMMER_TT, reload = true,
                  apply = function(v) if v then api.RestoreVanillaUltShimmer() else api.SuppressVanillaUltGlow() end end },
                { type = "choice", key = "ultBorderStyle", name = SI_AAB_ULT_BORDER_STYLE, tip = SI_AAB_ULT_BORDER_STYLE_TT, preview = "ult", reload = true,
                  choices = { { "custom", SI_AAB_ULT_BORDER_CUSTOM }, { "controller", SI_AAB_ULT_BORDER_CONTROLLER } },
                  apply = RefreshUlt },
                { type = "color", key = "ultReadyColor", name = SI_AAB_ULT_COLOR, tip = SI_AAB_ULT_COLOR_TT, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not sv.ultReadyEnabled end },
                { type = "toggle", key = "ultReadyPulse", name = SI_AAB_ULT_PULSE, tip = SI_AAB_ULT_PULSE_TT, preview = "ult", apply = RefreshUlt,
                  disabled = function() return NotCtrl() or not sv.ultReadyEnabled end },
                { type = "choice", key = "ultReadyMode", name = SI_AAB_ULT_PULSE_MODE, tip = SI_AAB_ULT_PULSE_MODE_TT, preview = "ult", apply = RefreshUlt,
                  choices = { { "smooth", SI_AAB_PULSE_STYLE_SMOOTH }, { "blink", SI_AAB_PULSE_STYLE_BLINK }, { "smooth-rainbow", SI_AAB_PULSE_STYLE_RAINBOW } },
                  disabled = function() return NotCtrl() or not sv.ultReadyEnabled or not sv.ultReadyPulse end },
                { type = "slider", key = "ultReadyBlinkIntMS", name = SI_AAB_ULT_BLINK_INT, tip = SI_AAB_ULT_BLINK_INT_TT,
                  min = -800, max = 800, step = 10, dec = 0, preview = "ult", apply = RefreshUlt,
                  disabled = function() return NotCtrl() or not sv.ultReadyEnabled or not sv.ultReadyPulse or sv.ultReadyMode ~= "blink" end },
                { type = "toggle", key = "ultColorCycleEnabled", name = SI_AAB_ULT_COLOR_CYCLE, tip = SI_AAB_ULT_COLOR_CYCLE_TT, preview = "ult", apply = RefreshUlt,
                  disabled = function() return NotCtrl() or not sv.ultReadyEnabled or not sv.ultReadyPulse or sv.ultReadyMode ~= "blink" end },
                { type = "color", key = "ultColorCycleSecondary", name = SI_AAB_ULT_COLOR_SECOND, tip = SI_AAB_ULT_COLOR_SECOND_TT, preview = "ult", apply = RefreshUlt,
                  disabled = function() return NotCtrl() or not sv.ultReadyEnabled or not sv.ultReadyPulse or sv.ultReadyMode ~= "blink" or not sv.ultColorCycleEnabled end },
                { type = "slider", key = "ultRainbowSaturation", name = SI_AAB_ULT_RAINBOW_SAT, tip = SI_AAB_ULT_RAINBOW_SAT_TT,
                  min = -1, max = 1, step = 0.05, dec = 2, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not sv.ultReadyEnabled or not (sv.ultReadyMode == "smooth-rainbow" or sv.ultCtrlRainbow) end },
                { type = "slider", key = "ultRainbowLightness", name = SI_AAB_ULT_RAINBOW_LIGHT, tip = SI_AAB_ULT_RAINBOW_LIGHT_TT,
                  min = -1, max = 1, step = 0.05, dec = 2, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not sv.ultReadyEnabled or not (sv.ultReadyMode == "smooth-rainbow" or sv.ultCtrlRainbow) end },
                { type = "slider", key = "ultReadyPulseDurMS", name = SI_AAB_ULT_PULSE_DUR, tip = SI_AAB_ULT_PULSE_DUR_TT,
                  min = -2000, max = 2000, step = 20, dec = 0, preview = "ult", apply = RefreshUlt,
                  disabled = function() return NotCtrl() or not sv.ultReadyEnabled or not sv.ultReadyPulse or sv.ultReadyMode ~= "smooth" end },
                { type = "slider", key = "ultReadyMinAlpha", name = SI_AAB_ULT_PULSE_MIN, tip = SI_AAB_ULT_PULSE_MIN_TT,
                  min = -1, max = 1, step = 0.05, dec = 2, preview = "ult", apply = RefreshUlt,
                  disabled = function() return NotCtrl() or not sv.ultReadyEnabled or not sv.ultReadyPulse end },
                { type = "slider", key = "ultReadyIntensity", name = SI_AAB_ULT_INTENSITY, tip = SI_AAB_ULT_INTENSITY_TT,
                  min = -2, max = 3, step = 0.05, dec = 2, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not sv.ultReadyEnabled end },
                { type = "slider", key = "ultReadyPadding", name = SI_AAB_ULT_PADDING, tip = SI_AAB_ULT_PADDING_TT,
                  min = -40, max = 40, step = 1, dec = 0, preview = "ult", apply = RefreshUlt,
                  disabled = function() return NotCtrl() or not sv.ultReadyEnabled end },

                { type = "header", name = SI_AAB_UI_HDR_ULTCTRL },
                { type = "choice", key = "ultCtrlStyle", name = SI_AAB_ULTCTRL_STYLE, tip = SI_AAB_ULTCTRL_STYLE_TT, preview = "ult", apply = RefreshUlt,
                  choices = { { "flat", SI_AAB_ULTCTRL_STYLE_FLAT }, { "bevel", SI_AAB_ULTCTRL_STYLE_BEVEL }, { "sleek", SI_AAB_ULTCTRL_STYLE_SLEEK },
                              { "chamfer", SI_AAB_ULTCTRL_STYLE_CHAMFER }, { "double", SI_AAB_ULTCTRL_STYLE_DOUBLE } },
                  disabled = function() return not IsCtrl() end },
                { type = "slider", key = "ultCtrlThickness", name = SI_AAB_ULTCTRL_THICKNESS, tip = SI_AAB_ULTCTRL_THICKNESS_TT,
                  min = -10, max = 10, step = 1, dec = 0, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not IsCtrl() end },
                { type = "slider", name = SI_AAB_ULTCTRL_CORNER, tip = SI_AAB_ULTCTRL_CORNER_TT,
                  min = -50, max = 50, step = 5, dec = 0, preview = "ult", apply = RefreshUlt,
                  get = function() return math.floor((sv.ultCtrlCornerFrac or 0.30) * 100 + 0.5) end,
                  set = function(v) sv.ultCtrlCornerFrac = v / 100 end,
                  reset = function() sv.ultCtrlCornerFrac = defaults.ultCtrlCornerFrac end,
                  disabled = function() return not IsCtrl() end },
                { type = "slider", key = "ultCtrlPadding", name = SI_AAB_ULTCTRL_PADDING, tip = SI_AAB_ULTCTRL_PADDING_TT,
                  min = -12, max = 12, step = 1, dec = 0, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not IsCtrl() end },
                { type = "toggle", key = "ultCtrlShowTrack", name = SI_AAB_ULTCTRL_TRACK, tip = SI_AAB_ULTCTRL_TRACK_TT, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not IsCtrl() end },
                { type = "toggle", key = "ultCtrlColorShift", name = SI_AAB_ULTCTRL_COLORSHIFT, tip = SI_AAB_ULTCTRL_COLORSHIFT_TT, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not IsCtrl() end },
                { type = "color", key = "ultCtrlChargingColor", name = SI_AAB_ULTCTRL_CHARGECOLOR, tip = SI_AAB_ULTCTRL_CHARGECOLOR_TT, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not IsCtrl() or not sv.ultCtrlColorShift end },
                { type = "toggle", key = "ultCtrlGlowOnFull", name = SI_AAB_ULTCTRL_GLOWFULL, tip = SI_AAB_ULTCTRL_GLOWFULL_TT, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not IsCtrl() end },
                { type = "choice", key = "ultCtrlGlowStyle", name = SI_AAB_ULTCTRL_GLOWSTYLE, tip = SI_AAB_ULTCTRL_GLOWSTYLE_TT, preview = "ult", apply = RefreshUlt,
                  choices = { { "soft", SI_AAB_ULTCTRL_GLOWSTYLE_SOFT }, { "sharp", SI_AAB_ULTCTRL_GLOWSTYLE_SHARP }, { "ring", SI_AAB_ULTCTRL_GLOWSTYLE_RING } },
                  disabled = function() return not IsCtrl() or not sv.ultCtrlGlowOnFull end },
                { type = "slider", key = "ultCtrlGlowIntensity", name = SI_AAB_ULTCTRL_GLOWINT, tip = SI_AAB_ULTCTRL_GLOWINT_TT,
                  min = -1, max = 1, step = 0.05, dec = 2, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not IsCtrl() or not sv.ultCtrlGlowOnFull end },
                { type = "slider", key = "ultCtrlGlowSpread", name = SI_AAB_UI_ULTCTRL_SPREAD, tip = SI_AAB_UI_ULTCTRL_SPREAD_TT,
                  min = -10, max = 10, step = 1, dec = 0, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not IsCtrl() or not sv.ultCtrlGlowOnFull end },
                { type = "slider", key = "ultCtrlPulseMS", name = SI_AAB_UI_ULTCTRL_PULSEMS, tip = SI_AAB_UI_ULTCTRL_PULSEMS_TT,
                  min = -2000, max = 2000, step = 10, dec = 0, preview = "ult", reload = true, apply = RefreshUlt,
                  disabled = function() return not IsCtrl() or not sv.ultCtrlGlowOnFull end },
                { type = "slider", key = "ultCtrlPollMS", name = SI_AAB_UI_ULTCTRL_POLL, tip = SI_AAB_UI_ULTCTRL_POLL_TT,
                  min = -1000, max = 1000, step = 10, dec = 0, reload = true,
                  disabled = function() return not IsCtrl() end },
                { type = "toggle", key = "ultCtrlRainbow", name = SI_AAB_ULTCTRL_RAINBOW, tip = SI_AAB_ULTCTRL_RAINBOW_TT, preview = "ult", apply = RefreshUlt,
                  disabled = function() return not IsCtrl() end },
            },
        },
        {
            id = "quick", icon = "UI_Icon_Quick", title = SI_AAB_UI_TAB_QUICK,
            demo = "quick",
            controls = {
                { type = "desc", text = SI_AAB_UI_QUICK_DESC },
                { type = "toggle", key = "quickslotBounceEnabled", name = SI_AAB_QS_BOUNCE, tip = SI_AAB_QS_BOUNCE_TT, preview = "quick",
                  disabled = function() return not sv.bounceEnabled end },
                { type = "toggle", key = "quickslotReadyEnabled", name = SI_AAB_QS_READY, tip = SI_AAB_QS_READY_TT, preview = "quick" },
            },
        },
        {
            id = "frame", icon = "UI_Icon_Frame", title = SI_AAB_SUB_FRAME, tip = SI_AAB_SUB_FRAME_TT,
            demo = "press",
            controls = {
                { type = "toggle", key = "thinFrameEnabled", name = SI_AAB_THIN_FRAME, tip = SI_AAB_THIN_FRAME_TT, reload = true, preview = "frame" },
                { type = "slider", key = "frameAlpha", name = SI_AAB_FRAME_ALPHA, tip = SI_AAB_FRAME_ALPHA_TT,
                  min = -1, max = 1, step = 0.05, dec = 2, preview = "frame",
                  apply = function() api.ApplyFrameAlpha() end,
                  disabled = function() return not sv.thinFrameEnabled end },
                { type = "choice", key = "edgeStyle", name = SI_AAB_EDGE_STYLE, tip = SI_AAB_EDGE_STYLE_TT, reload = true, preview = "frame",
                  choices = { { "classic", SI_AAB_EDGE_CLASSIC }, { "v2", SI_AAB_EDGE_V2 }, { "purple", SI_AAB_EDGE_PURPLE }, { "red", SI_AAB_EDGE_RED },
                              { "blue", SI_AAB_EDGE_BLUE }, { "aqua", SI_AAB_EDGE_AQUA }, { "darkred", SI_AAB_EDGE_DARKRED }, { "darkpurple", SI_AAB_EDGE_DARKPURPLE } },
                  apply = function() api.ApplyEdgeTexture() end,
                  disabled = function() return not sv.thinFrameEnabled end },
                { type = "toggle", key = "gamepadKeyboardLayout", name = SI_AAB_UI_GP_KBLAYOUT, tip = SI_AAB_UI_GP_KBLAYOUT_TT, reload = true,
                  apply = function() api.RefreshKeyboardLook() end },
                { type = "button", name = SI_AAB_RELOAD_UI, tip = SI_AAB_RELOAD_UI_TT, func = function() ReloadUI("ingame") end },
                { type = "desc", text = SI_AAB_FRAME_THEME_NOTE },
            },
        },
        {
            id = "perf", icon = "UI_Icon_Perf", title = SI_AAB_SUB_PERF, tip = SI_AAB_SUB_PERF_TT,
            demo = "press",
            controls = {
                { type = "desc", text = SI_AAB_PERF_DESC },
                { type = "toggle", key = "perfEffectIdFilter", name = SI_AAB_PERF_EFFECTID, tip = SI_AAB_PERF_EFFECTID_TT,
                  apply = function() api.RefreshEffectRegistration() end },
                { type = "toggle", key = "perfSlotLookupMap", name = SI_AAB_PERF_SLOTMAP, tip = SI_AAB_PERF_SLOTMAP_TT,
                  apply = function(v) if v then api.RebuildSlotLookup() end end },
                { type = "toggle", key = "perfCombatOnly", name = SI_AAB_PERF_COMBAT, tip = SI_AAB_PERF_COMBAT_TT },
                { type = "toggle", key = "perfSlowRainbow", name = SI_AAB_PERF_RAINBOW, tip = SI_AAB_PERF_RAINBOW_TT, preview = "ult",
                  apply = RefreshUlt },
                { type = "toggle", key = "perfSingleStyleHook", name = SI_AAB_PERF_STYLEHOOK, tip = SI_AAB_PERF_STYLEHOOK_TT, reload = true },
                { type = "toggle", key = "perfLimitTimelineCache", name = SI_AAB_PERF_TLCACHE, tip = SI_AAB_PERF_TLCACHE_TT, apply = Invalidate },
                { type = "desc", text = SI_AAB_PERF_NOTE },
                { type = "header", name = SI_AAB_UI_HDR_STUDIO },
                { type = "choice", key = "uiTheme", name = SI_AAB_UI_THEME, tip = SI_AAB_UI_THEME_TT,
                  choices = { { "nebula", SI_AAB_UI_THEME_NEBULA }, { "lace", SI_AAB_UI_THEME_LACE } },
                  apply = function(v) Studio.ShowTheme(v) end },
                { type = "toggle", key = "uiBgMotion", name = SI_AAB_UI_BGMOTION, tip = SI_AAB_UI_BGMOTION_TT,
                  apply = function() Studio.RefreshMotion() end },
            },
        },
        {
            id = "info", icon = "UI_Icon_Info", title = SI_AAB_SUB_INFO, tip = SI_AAB_SUB_INFO_TT,
            demo = "press",
            controls = {
                { type = "desc", text = SI_AAB_INFO_THINFRAMES },
                { type = "header", name = SI_AAB_UI_HDR_GAMEPAD },
                { type = "desc", text = SI_AAB_INFO_GAMEPAD },
            },
        },
        {
            id = "contact", icon = "UI_Icon_Heart", title = SI_AAB_SUB_CONTACT, tip = SI_AAB_SUB_CONTACT_TT,
            demo = "press",
            controls = {
                { type = "desc", text = SI_AAB_CONTACT_DESC },
                { type = "button", name = SI_AAB_CONTACT_DONATE_BTN, tip = SI_AAB_CONTACT_DONATE_BTN_TT,
                  func = function() Studio.Close(); api.OpenDonationMail() end },
            },
        },
    }
    return PAGES
end

local function PageIndex(id)
    for i, p in ipairs(BuildPageDefs()) do
        if p.id == id then return i end
    end
    return 2
end

local function GetVal(def)
    if def.get then return def.get() end
    return sv[def.key]
end

local function IsDisabled(def)
    return def.disabled and def.disabled() or false
end

local function Round(v, dec)
    local m = 10 ^ (dec or 0)
    return math.floor(v * m + 0.5) / m
end

local HARD_LIMIT = 100000

local OnValueChanged -- forward

local function SetVal(def, v)
    if def.set then def.set(v) else sv[def.key] = v end
    if def.apply then def.apply(v) end
    OnValueChanged(def)
end

local function ResetDef(def)
    if def.reset then
        def.reset()
    elseif def.key and defaults[def.key] ~= nil then
        sv[def.key] = CopyValue(defaults[def.key])
    else
        return
    end
    if def.apply then def.apply(GetVal(def)) end
    OnValueChanged(def)
end

-- ein fenster pro modus

local wins   = {}   -- mode -> window-objekt
local active = nil  -- aktuell offenes window-objekt

-- vorschau

local GLOW_TEX     = "EsoUI/Art/HUD/Gamepad/gp_skillGlow.dds"
local FALLBACK_ICON = "EsoUI/Art/Icons/icon_missing.dds"

local function MakeGlow(parent, level)
    local g = Tex(parent, GLOW_TEX, level or 20)
    g:SetTextureCoords(0.1875, 0.8125, 0.1875, 0.8125)
    g:SetAlpha(0)
    return g
end

local function AnchorPad(ctrl, target, pad)
    ctrl:ClearAnchors()
    ctrl:SetAnchor(TOPLEFT, target, TOPLEFT, -pad, -pad)
    ctrl:SetAnchor(BOTTOMRIGHT, target, BOTTOMRIGHT, pad, pad)
end

local function MakePreviewSlot(parent, size)
    local name = N("PSlot")
    local slot = WM:CreateControl(name, parent, CT_CONTROL)
    slot:SetDimensions(size, size)

    local flip = WM:CreateControl(name .. "FlipCard", slot, CT_CONTROL)
    flip:SetDimensions(size - 3, size - 3)
    flip:SetAnchor(CENTER, slot, CENTER, 0, 0)

    local iconBg = Tex(flip, nil, 2)
    iconBg:SetAnchorFill(flip)
    iconBg:SetColor(0.05, 0.04, 0.08, 1)

    local icon = WM:CreateControl(name .. "Icon", flip, CT_TEXTURE)
    icon:SetAnchorFill(flip)
    icon:SetDrawLevel(3)
    icon:SetTexture(FALLBACK_ICON)

    local bd = WM:CreateControl(name .. "Backdrop", slot, CT_BACKDROP)
    local o = math.max(2, zo_round(4 * size / 47))
    bd:SetAnchor(TOPLEFT, flip, TOPLEFT, -o, -o)
    bd:SetAnchor(BOTTOMRIGHT, flip, BOTTOMRIGHT, o, o)
    bd:SetCenterTexture("AnimatedActionBarPlus/CustomCenter.dds")
    bd:SetDrawLevel(4)

    local vanilla = Tex(slot, "EsoUI/Art/ActionBar/abilityFrame64_up.dds", 4)
    AnchorPad(vanilla, flip, math.max(2, zo_round(3 * size / 47)))
    vanilla:SetHidden(true)

    local p = {
        slot = slot, flip = flip, icon = icon, backdrop = bd, vanilla = vanilla, size = size,
        k = size / 47,
        glow   = MakeGlow(flip, 20),
        pulse  = MakeGlow(flip, 21),
        expire = MakeGlow(flip, 22),
    }
    p.adapter = { slot = slot, FlipCard = flip, icon = icon }
    return p
end

local function GlowFade(p, glowCtrl, color, intensity, padding, duration)
    local a = api.Alpha01((color[4] or 1) * (intensity or 1))
    AnchorPad(glowCtrl, p.flip, (padding or 0) * p.k)
    glowCtrl:SetColor(color[1], color[2], color[3], a)
    glowCtrl:SetAlpha(a)
    p.fades = p.fades or {}
    local tl = p.fades[glowCtrl]
    if not tl then
        tl = ANIMATION_MANAGER:CreateTimeline()
        tl:InsertAnimation(ANIMATION_ALPHA, glowCtrl)
        p.fades[glowCtrl] = tl
    end
    local an = tl:GetAnimation(1)
    an:SetAlphaValues(a, 0)
    an:SetDuration(api.SafeMS(duration, 600))
    an:SetEasingFunction(ZO_EaseInQuadratic)
    tl:PlayFromStart()
end

local function SlotIcon(slotNum, cat)
    local t = GetSlotTexture and GetSlotTexture(slotNum, cat) or ""
    if not t or t == "" then return nil end
    return t
end

local function RefreshPreviewIcons(w)
    local pv = w.preview
    for i, p in ipairs(pv.slots) do
        local slotNum = 2 + i
        local t = SlotIcon(slotNum, HOTBAR_CATEGORY_PRIMARY) or SlotIcon(slotNum, HOTBAR_CATEGORY_BACKUP)
        p.icon:SetTexture(t or FALLBACK_ICON)
    end
    local q
    if GetCurrentQuickslot then
        q = SlotIcon(GetCurrentQuickslot(), HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    end
    pv.quick.icon:SetTexture(q or "EsoUI/Art/Icons/consumable_potion_001_type_005.dds")
end

local function RefreshPreviewFrames(w)
    local pv = w.preview
    local edges = api.edgeTextures
    local file  = edges[sv.edgeStyle] or edges.classic
    local alpha = api.Alpha01(sv.frameAlpha or 1)
    local all = {}
    for _, p in ipairs(pv.slots) do all[#all + 1] = p end
    all[#all + 1] = pv.quick
    for _, p in ipairs(all) do
        if sv.thinFrameEnabled then
            p.backdrop:SetHidden(false)
            p.backdrop:SetEdgeTexture(file, 128, 16, math.max(8, zo_round(16 * p.k)), 0)
            p.backdrop:SetAlpha(alpha)
            p.vanilla:SetHidden(true)
        else
            p.backdrop:SetHidden(true)
            p.vanilla:SetHidden(false)
        end
    end
end

local function PreviewPress(w, i)
    local pv = w.preview
    local p = pv.slots[i]
    if not p then return end
    local isUlt = (i == #pv.slots)
    local bounceOn = isUlt and sv.ultBounceEnabled or (not isUlt and sv.bounceEnabled)
    if bounceOn then api.PlayPreviewAnim(p.adapter, nil, "press") end
    if isUlt then
        if sv.ultGlowEnabled then
            GlowFade(p, p.glow, sv.ultGlowColor, sv.ultGlowIntensity, sv.ultGlowPadding, sv.ultGlowDurationMS)
        end
    elseif sv.glowEnabled then
        GlowFade(p, p.glow, sv.glowColor, sv.glowIntensity, sv.glowPadding, sv.glowDurationMS)
    end
end

local function PreviewExpire(w)
    local p = w.preview.slots[5]
    if not sv.expireAnimEnabled then return end
    local scale = api.ResolveExpireScale(0, 12000)
    api.PlayPreviewAnim(p.adapter, api.ResolveExpireStyle(), "expire", scale)
    if sv.expireGlowEnabled then
        GlowFade(p, p.expire, sv.expireGlowColor, 1, sv.glowPadding, sv.glowDurationMS)
    end
end

-- proc auf slot 2
local PULSE_UPDATE = "AABStudio_PulseBlink"

local function StopPreviewPulse(w)
    local pv = w.preview
    EM:UnregisterForUpdate(PULSE_UPDATE)
    if pv.pulseTL then pv.pulseTL:Stop() end
    pv.slots[2].pulse:SetAlpha(0)
    pv.pulseOn = false
end

local function StartPreviewPulse(w)
    StopPreviewPulse(w)
    local pv = w.preview
    if not (sv.uiProcSim and sv.glowEnabled and sv.pulseEnabled) then return end
    local p = pv.slots[2]
    local glow = p.pulse
    local c1 = sv.glowColor
    local c2 = sv.colorCycleSecondary
    local intensity = sv.glowIntensity or 1
    local maxA = api.Alpha01((sv.pulseMaxAlpha or 1) * intensity)
    local minA = api.Alpha01(sv.pulseMinAlpha)
    AnchorPad(glow, p.flip, (sv.glowPadding or 12) * p.k)
    glow:SetColor(c1[1], c1[2], c1[3], maxA)
    glow:SetAlpha(maxA)
    pv.pulseOn = true

    if sv.bounceEnabled and sv.bounceOnProc then api.PlayPreviewAnim(p.adapter, nil, "press") end

    local mode = sv.pulseMode or "smooth"
    if mode == "smooth" then
        if not pv.pulseTL then
            pv.pulseTL = ANIMATION_MANAGER:CreateTimeline()
            pv.pulseTL:InsertAnimation(ANIMATION_ALPHA, glow)
            pv.pulseTL:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, LOOP_INDEFINITELY)
        end
        local a = pv.pulseTL:GetAnimation(1)
        a:SetAlphaValues(maxA, minA)
        a:SetDuration(api.SafeMS(sv.pulseDurationMS, 800))
        a:SetEasingFunction(ZO_EaseOutQuadratic)
        pv.pulseTL:PlayFromStart()
    else
        local interval = api.SafeInterval(mode == "strobe" and sv.strobeIntervalMS or sv.blinkIntervalMS, 250)
        local state = false
        local cycle = sv.colorCycleEnabled
        EM:RegisterForUpdate(PULSE_UPDATE, interval, function()
            state = not state
            if state then
                glow:SetAlpha(maxA)
                local c = cycle and c2 or c1
                glow:SetColor(c[1], c[2], c[3], api.Alpha01((c[4] or 1) * intensity))
            elseif cycle then
                glow:SetAlpha(maxA)
                glow:SetColor(c1[1], c1[2], c1[3], api.Alpha01((c1[4] or 1) * intensity))
            else
                glow:SetAlpha(minA)
            end
        end)
    end
end

local ULT_UPDATE = "AABStudio_UltLoop"

local function StopPreviewUlt(w)
    local pv = w.preview
    EM:UnregisterForUpdate(ULT_UPDATE)
    if pv.ultTL then pv.ultTL:Stop() end
    if pv.ultFullTL then pv.ultFullTL:Stop() end
    pv.ultReady:SetAlpha(0)
    for _, set in pairs(pv.bracket) do
        for _, c in pairs(set) do c:SetHidden(true) end
    end
end

local SEGS = { "L", "R", "TL", "TR", "BL", "BR" }

local GP_UPDATE = "AABStudio_GpUlt"

local function GpCell(tex, pct, mirror)
    local i = math.max(0, math.min(31, zo_floor(pct * 31 + 0.5)))
    local col, row = i % 8, zo_floor(i / 8)
    local l, r = col / 8, (col + 1) / 8
    if mirror then l, r = r, l end
    tex:SetTextureCoords(l, r, row / 4, (row + 1) / 4)
end

local function StopPreviewGpUlt(w)
    EM:UnregisterForUpdate(GP_UPDATE)
    local g = w.preview.gpUlt
    if g then
        g.frame:SetHidden(true)
        g.left:SetHidden(true)
        g.right:SetHidden(true)
    end
end

local function StartPreviewGpUlt(w)
    StopPreviewGpUlt(w)
    local g = w.preview.gpUlt
    if not g or not sv.ultGpFrameEnabled then return end
    local FILL_MS, HOLD_MS = 2600, 2400
    local t0 = GetFrameTimeMilliseconds()
    local hue = 0
    local function Paint()
        local e = GetFrameTimeMilliseconds() - t0
        if e > FILL_MS + HOLD_MS then t0 = GetFrameTimeMilliseconds(); e = 0 end
        local pct = math.min(1, e / FILL_MS)
        local full = pct >= 1
        local fc, lc = sv.ultGpFrameColor, sv.ultGpFillColor
        local fr, fg, fb, lr, lg, lb = fc[1], fc[2], fc[3], lc[1], lc[2], lc[3]
        if full and sv.ultGpRainbow then
            hue = (hue + 0.01) % 1
            local r, gg, b = api.HSLToRGB(hue, api.Clamp(sv.ultRainbowSaturation or 1, 0, 1), api.Clamp(sv.ultRainbowLightness or 0.5, 0, 1))
            fr, fg, fb, lr, lg, lb = r, gg, b, r, gg, b
        elseif full and sv.ultGpFullColorEnabled then
            local c = sv.ultGpFullColor
            fr, fg, fb, lr, lg, lb = c[1], c[2], c[3], c[1], c[2], c[3]
        end
        local fa, la = api.Alpha01(fc[4] or 1), api.Alpha01(lc[4] or 1)
        g.frame:SetEdgeColor(fr, fg, fb, fa)
        g.left:SetColor(lr, lg, lb, la)
        g.right:SetColor(lr, lg, lb, la)
        GpCell(g.left, pct, false)
        GpCell(g.right, pct, true)
    end
    Paint()
    g.frame:SetHidden(false)
    g.left:SetHidden(false)
    g.right:SetHidden(false)
    EM:RegisterForUpdate(GP_UPDATE, 33, Paint)
end

local function LayoutBracket(set, parent, pad, th, extra, cornerFrac)
    extra = extra or 0
    local p = zo_round(pad + extra)
    local t = math.max(1, zo_round(math.abs(th) + extra * 2))
    local w = parent:GetWidth() + p * 2
    local cl = zo_round(math.max(6 * (parent:GetWidth() / 50), w * cornerFrac))
    set.L:ClearAnchors(); set.L:SetAnchor(TOPLEFT, parent, TOPLEFT, -p, -p); set.L:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, -p, p); set.L:SetWidth(t)
    set.R:ClearAnchors(); set.R:SetAnchor(TOPRIGHT, parent, TOPRIGHT, p, -p); set.R:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, p, p); set.R:SetWidth(t)
    set.TL:ClearAnchors(); set.TL:SetAnchor(TOPLEFT, parent, TOPLEFT, -p + t, -p); set.TL:SetDimensions(cl, t)
    set.TR:ClearAnchors(); set.TR:SetAnchor(TOPRIGHT, parent, TOPRIGHT, p - t, -p); set.TR:SetDimensions(cl, t)
    set.BL:ClearAnchors(); set.BL:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, -p + t, p); set.BL:SetDimensions(cl, t)
    set.BR:ClearAnchors(); set.BR:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, p - t, p); set.BR:SetDimensions(cl, t)
    return p, t, cl
end

local function ColorAll(set, tex, r, g, b, a)
    for _, c in pairs(set) do
        c:SetTexture(tex)
        c:SetColor(r, g, b, a)
    end
end

local function StartPreviewUlt(w)
    StopPreviewUlt(w)
    StartPreviewGpUlt(w)
    local pv = w.preview
    if not sv.ultReadyEnabled then return end
    local p = pv.slots[#pv.slots]
    local k = p.k
    local c = sv.ultReadyColor
    local intensity = sv.ultReadyIntensity or 1
    local maxA = api.Alpha01((c[4] or 1) * intensity)

    if sv.ultBorderStyle ~= "controller" then
        local glow = pv.ultReady
        local mode = sv.ultReadyMode or "smooth"
        local pad = (sv.ultReadyPadding or 8) + ((mode == "smooth-rainbow") and 2 or 0)
        AnchorPad(glow, p.flip, pad * k)
        glow:SetColor(c[1], c[2], c[3], maxA)
        glow:SetAlpha(maxA)
        if not sv.ultReadyPulse then return end
        local minA = api.Alpha01(sv.ultReadyMinAlpha or 0.35)
        if mode == "blink" then
            local state = true
            local c2 = sv.ultColorCycleSecondary
            local cycle = sv.ultColorCycleEnabled
            EM:RegisterForUpdate(ULT_UPDATE, api.SafeInterval(sv.ultReadyBlinkIntMS, 250), function()
                state = not state
                if cycle then
                    glow:SetAlpha(maxA)
                    if state then glow:SetColor(c[1], c[2], c[3], maxA)
                    else glow:SetColor(c2[1], c2[2], c2[3], api.Alpha01((c2[4] or 1) * intensity)) end
                else
                    glow:SetColor(c[1], c[2], c[3], maxA)
                    glow:SetAlpha(state and maxA or minA)
                end
            end)
        elseif mode == "smooth-rainbow" then
            local hue = 0
            local sat = api.Clamp(sv.ultRainbowSaturation or 1, 0, 1)
            local lit = api.Clamp(sv.ultRainbowLightness or 0.5, 0, 1)
            local interval = sv.perfSlowRainbow and 33 or 16
            local stepH = 0.002 * (interval / 5)
            EM:RegisterForUpdate(ULT_UPDATE, interval, function()
                hue = (hue + stepH) % 1
                local r, g, b = api.HSLToRGB(hue, sat, lit)
                glow:SetColor(r, g, b, maxA)
            end)
        else
            if not pv.ultTL then
                pv.ultTL = ANIMATION_MANAGER:CreateTimeline()
                pv.ultTL:InsertAnimation(ANIMATION_ALPHA, glow)
                pv.ultTL:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, LOOP_INDEFINITELY)
            end
            local a = pv.ultTL:GetAnimation(1)
            a:SetAlphaValues(maxA, minA)
            a:SetDuration(api.SafeMS(sv.ultReadyPulseDurMS, 900))
            a:SetEasingFunction(ZO_EaseOutQuadratic)
            pv.ultTL:PlayFromStart()
        end
        return
    end

    -- controller-klammer
    local parent = p.slot
    local pad = (tonumber(sv.ultCtrlPadding) or 2) * k
    local th  = math.max(1, math.abs(tonumber(sv.ultCtrlThickness) or 3) * k)
    local frac = sv.ultCtrlCornerFrac or 0.3
    local tex = api.ultEdgeTextures[sv.ultCtrlStyle or "flat"] or api.ultEdgeTextures.flat
    local gtex = api.ultGlowTextures[sv.ultCtrlGlowStyle or "soft"] or api.ultGlowTextures.soft
    local gi = api.Alpha01(sv.ultCtrlGlowIntensity or 0.7)
    local B = pv.bracket

    LayoutBracket(B.track, parent, pad, th, 0, frac)
    ColorAll(B.track, tex, 0.09, 0.09, 0.11, 0.9)
    for _, ctl in pairs(B.track) do ctl:SetHidden(not sv.ultCtrlShowTrack) end
    LayoutBracket(B.glow, parent, pad, th, (tonumber(sv.ultCtrlGlowSpread) or 3) * 0.5 * k, frac)
    local p0, t, cl = LayoutBracket(B.fill, parent, pad, th, 0, frac)

    local FILL_MS, HOLD_MS = 2600, 2400
    local t0 = GetFrameTimeMilliseconds()
    local wasFull = false
    local hue = 0
    local sat = api.Clamp(sv.ultRainbowSaturation or 1, 0, 1)
    local lit = api.Clamp(sv.ultRainbowLightness or 0.5, 0, 1)

    local function Paint(pct)
        local r, g, b = c[1], c[2], c[3]
        if sv.ultCtrlColorShift then
            local cc = sv.ultCtrlChargingColor
            r, g, b = Lerp(cc[1], c[1], pct), Lerp(cc[2], c[2], pct), Lerp(cc[3], c[3], pct)
        end
        local full = pct >= 1
        if full and sv.ultCtrlRainbow then
            hue = (hue + 0.006) % 1
            r, g, b = api.HSLToRGB(hue, sat, lit)
        end
        ColorAll(B.fill, tex, r, g, b, maxA)
        local fullH = parent:GetHeight() + p0 * 2
        local side = zo_round(math.min(fullH, fullH * pct))
        local F = B.fill
        F.L:ClearAnchors(); F.L:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, -p0, p0); F.L:SetDimensions(t, side); F.L:SetHidden(side <= 1)
        F.R:ClearAnchors(); F.R:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, p0, p0); F.R:SetDimensions(t, side); F.R:SetHidden(side <= 1)
        F.BL:SetHidden(pct <= 0.02); F.BR:SetHidden(pct <= 0.02)
        F.TL:SetHidden(pct < 0.9); F.TR:SetHidden(pct < 0.9)

        local showGlow = full and sv.ultCtrlGlowOnFull
        for _, gc in pairs(B.glow) do
            gc:SetTexture(gtex)
            gc:SetColor(r, g, b, gi)
            gc:SetHidden(not showGlow)
        end
        if full and not wasFull and showGlow then
            if not pv.ultFullTL then
                pv.ultFullTL = ANIMATION_MANAGER:CreateTimeline()
                for _, seg in ipairs(SEGS) do
                    pv.ultFullTL:InsertAnimation(ANIMATION_ALPHA, B.glow[seg])
                end
            end
            for i = 1, #SEGS do
                local a = pv.ultFullTL:GetAnimation(i)
                a:SetAlphaValues(1, gi)
                a:SetDuration(api.SafeMS(sv.ultCtrlPulseMS, 450))
                a:SetEasingFunction(ZO_EaseOutQuadratic)
            end
            pv.ultFullTL:PlayFromStart()
        end
        wasFull = full
    end

    Paint(0)
    EM:RegisterForUpdate(ULT_UPDATE, 33, function()
        local e = GetFrameTimeMilliseconds() - t0
        if e > FILL_MS + HOLD_MS then
            t0 = GetFrameTimeMilliseconds()
            e = 0
            wasFull = false
        end
        Paint(math.min(1, e / FILL_MS))
    end)
end

local function PreviewQuickUse(w)
    local pv = w.preview
    local q = pv.quick
    if q.cooling then return end
    if sv.bounceEnabled and sv.quickslotBounceEnabled then api.PlayPreviewAnim(q.adapter, nil, "press") end
    if sv.glowEnabled then GlowFade(q, q.glow, sv.glowColor, sv.glowIntensity, sv.glowPadding, sv.glowDurationMS) end
    q.cooling = true
    local DUR = 3500
    local t0 = GetFrameTimeMilliseconds()
    q.cdOverlay:SetHidden(false)
    q.cdLabel:SetHidden(false)
    q.status:SetText(S(SI_AAB_UI_PV_COOLDOWN))
    SetCol(q.status, COL.dim)
    q.slot:SetHandler("OnUpdate", function()
        local e = GetFrameTimeMilliseconds() - t0
        local rem = math.max(0, DUR - e)
        q.cdOverlay:SetHeight(math.max(0.01, (q.flip:GetHeight()) * rem / DUR))
        q.cdLabel:SetText(string.format("%.1f", rem / 1000))
        if rem <= 0 then
            q.slot:SetHandler("OnUpdate", nil)
            q.cooling = false
            q.cdOverlay:SetHidden(true)
            q.cdLabel:SetHidden(true)
            q.status:SetText(S(SI_AAB_UI_PV_READY))
            SetCol(q.status, COL.good)
            if sv.quickslotReadyEnabled then
                if sv.bounceEnabled and sv.quickslotBounceEnabled then api.PlayPreviewAnim(q.adapter, nil, "press") end
                if sv.glowEnabled then GlowFade(q, q.glow, sv.glowColor, sv.glowIntensity, sv.glowPadding, sv.glowDurationMS) end
            end
        end
    end)
end

local function Preview(kind)
    local w = active
    if not w or not Api() then return end
    if kind == "press" then
        local pick = { 1, 3, 4 }
        w.preview.pressIdx = (w.preview.pressIdx or 0) % #pick + 1
        PreviewPress(w, pick[w.preview.pressIdx])
    elseif kind == "proc" then
        StartPreviewPulse(w)
    elseif kind == "expire" then
        PreviewExpire(w)
    elseif kind == "ult" then
        StartPreviewUlt(w)
    elseif kind == "ultpress" then
        PreviewPress(w, #w.preview.slots)
    elseif kind == "quick" then
        PreviewQuickUse(w)
    elseif kind == "frame" then
        RefreshPreviewFrames(w)
        PreviewPress(w, 1)
    end
end

local DEMO_UPDATE = "AABStudio_AutoDemo"
local demoTick = 0

local function StopAutoDemo()
    EM:UnregisterForUpdate(DEMO_UPDATE)
end

local function StartAutoDemo()
    StopAutoDemo()
    if not sv.uiAutoDemo then return end
    EM:RegisterForUpdate(DEMO_UPDATE, 1700, function()
        local w = active
        if not w then return end
        demoTick = demoTick + 1
        local page = BuildPageDefs()[w.pageIndex]
        local demo = page and page.demo or "press"
        if demo == "quick" then
            if demoTick % 3 == 0 then Preview("quick") end
        elseif demo == "ult" then
            if demoTick % 3 == 0 then Preview("ultpress") else Preview("press") end
        elseif demo == "bounce" then
            if demoTick % 3 == 0 then Preview("expire") else Preview("press") end
        else
            Preview("press")
        end
    end)
end

local function RefreshDemoChips(w)
    local pv = w.preview
    if pv.chipProc then pv.chipProc.SetOn(sv.uiProcSim) end
    if pv.chipAuto then pv.chipAuto.SetOn(sv.uiAutoDemo) end
end

local function RestartPreview(w)
    RefreshPreviewIcons(w)
    RefreshPreviewFrames(w)
    StartPreviewPulse(w)
    StartPreviewUlt(w)
    RefreshDemoChips(w)
    StartAutoDemo()
end

local function StopPreview(w)
    StopAutoDemo()
    StopPreviewPulse(w)
    StopPreviewUlt(w)
    StopPreviewGpUlt(w)
end

local function RowHover(row, on)
    row.hover = on
    row.UpdateHighlight()
    if on and active then
        local def = row.def
        local txt = def.tip and S(def.tip) or (def.name and S(def.name)) or ""
        if def.reload then txt = txt .. "\n|cd69a4f" .. S(SI_AAB_RELOAD_NOTE) .. "|r" end
        active.hint:SetText(txt)
    end
end

local function HookHover(ctrl, row)
    ctrl:SetMouseEnabled(true)
    ctrl:SetHandler("OnMouseEnter", function() RowHover(row, true) end)
    ctrl:SetHandler("OnMouseExit", function() RowHover(row, false) end)
end

local function MakeRowBase(w, parent, def, height)
    local L = w.L
    local row = { def = def, w = w, height = height }
    local c = WM:CreateControl(N("Row"), parent, CT_CONTROL)
    c:SetDimensions(w.rowW, height)
    row.ctrl = c

    local hl = Tex(c, MEDIA .. "UI_HGrad.dds", 2)
    hl:SetAnchorFill(c)
    SetCol(hl, COL.accent, 0)
    local bar = Tex(c, nil, 3)
    bar:SetDimensions(3, height - 12)
    bar:SetAnchor(LEFT, c, LEFT, 0, 0)
    SetCol(bar, COL.accent)
    bar:SetHidden(true)

    function row.UpdateHighlight()
        local a = 0
        if row.focused then a = 0.30 elseif row.hover then a = 0.16 end
        hl:SetAlpha(a)
        bar:SetHidden(not row.focused)
    end

    if def.name and def.type ~= "header" and def.type ~= "button" then
        local lbl = Lbl(c, L.fLabel, COL.text, S(def.name))
        lbl:SetAnchor(LEFT, c, LEFT, 14, 0)
        local wide = (def.type == "toggle" or def.type == "color")
        lbl:SetDimensions(wide and (w.rowW - L.toggleW * 2.6 - 40) or (w.rowW * 0.48), height)
        lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.label = lbl
    end
    HookHover(c, row)
    return row
end

local function ApplyDisabled(row)
    local dis = IsDisabled(row.def)
    row.disabled = dis
    row.ctrl:SetAlpha(dis and 0.38 or 1)
end

local function BuildToggle(w, parent, def)
    local L = w.L
    local row = MakeRowBase(w, parent, def, L.rowH)
    local c = row.ctrl
    local track = Tex(c, MEDIA .. "UI_Pill.dds", 2)
    track:SetDimensions(L.toggleW, L.toggleH)
    track:SetAnchor(RIGHT, c, RIGHT, -14, 0)
    local knob = Tex(c, MEDIA .. "UI_Knob.dds", 3)
    local ks = L.toggleH * 1.3
    knob:SetDimensions(ks, ks)
    local onX, offX = L.toggleW - L.toggleH / 2, L.toggleH / 2
    local cur = nil

    local function Paint(t)
        local x = Lerp(offX, onX, t)
        knob:ClearAnchors()
        knob:SetAnchor(CENTER, track, LEFT, x, 1)
        local r = Lerp(COL.track[1], COL.accent[1], t)
        local g = Lerp(COL.track[2], COL.accent[2], t)
        local b = Lerp(COL.track[3], COL.accent[3], t)
        track:SetColor(r, g, b, 1)
        knob:SetColor(Lerp(0.75, 1, t), Lerp(0.72, 1, t), Lerp(0.85, 1, t), 1)
    end

    function row.Refresh(animate)
        ApplyDisabled(row)
        local on = GetVal(def) and true or false
        if cur == on then return end
        local from = cur
        cur = on
        if animate and from ~= nil then
            Tween(knob, 140, function(p) Paint(on and p or (1 - p)) end)
        else
            Paint(on and 1 or 0)
        end
    end

    function row.Activate()
        if row.disabled then return end
        Click()
        SetVal(def, not GetVal(def))
    end

    function row.Adjust(dir)
        if row.disabled then return end
        local want = dir > 0
        if (GetVal(def) and true or false) ~= want then row.Activate() end
    end

    local hit = Hit(c, track, 20)
    hit:SetHandler("OnMouseUp", function(_, btn, inside) if inside and btn == MOUSE_BUTTON_INDEX_LEFT then row.Activate() end end)
    hit:SetHandler("OnMouseEnter", function() RowHover(row, true) end)
    hit:SetHandler("OnMouseExit", function() RowHover(row, false) end)
    c:SetHandler("OnMouseUp", function(_, btn, inside) if inside and btn == MOUSE_BUTTON_INDEX_LEFT then row.Activate() end end)
    row.focusable = true
    return row
end

local function BuildSlider(w, parent, def)
    local L = w.L
    local row = MakeRowBase(w, parent, def, L.rowH)
    local c = row.ctrl
    local min, max, step, dec = def.min, def.max, def.step, def.dec or 0

    local editBg = Box(c, "row", COL.accent2, 0.6, COL.field, 2)
    editBg:SetDimensions(L.editW, L.toggleH + 6)
    editBg:SetAnchor(RIGHT, c, RIGHT, -14, 0)
    local edit = WM:CreateControl(N("Edit"), editBg, CT_EDITBOX)
    edit:SetFont(L.fValue)
    SetCol(edit, COL.value)
    edit:SetAnchor(TOPLEFT, editBg, TOPLEFT, 8, 3)
    edit:SetAnchor(BOTTOMRIGHT, editBg, BOTTOMRIGHT, -6, -3)
    edit:SetMaxInputChars(10)
    edit:SetDrawLevel(3)

    local track = Tex(c, MEDIA .. "UI_Pill.dds", 2)
    track:SetDimensions(L.sliderW, math.max(6, zo_round(L.toggleH * 0.28)))
    track:SetAnchor(RIGHT, editBg, LEFT, -16, 0)
    SetCol(track, COL.track)
    local hit = WM:CreateControl(N("Hit"), c, CT_CONTROL)
    hit:SetDimensions(L.sliderW + 16, L.rowH - 8)
    hit:SetAnchor(CENTER, track, CENTER, 0, 0)
    hit:SetDrawLevel(5)

    local fill = Tex(c, MEDIA .. "UI_Pill.dds", 3)
    fill:SetHeight(track:GetHeight())
    local zero = Tex(c, nil, 3)
    zero:SetDimensions(2, track:GetHeight() + 10)
    SetCol(zero, COL.dim, 0.9)
    local knob = Tex(c, MEDIA .. "UI_Knob.dds", 4)
    local ks = L.toggleH * 1.05
    knob:SetDimensions(ks, ks)

    local function Pct(v) return (api.Clamp(v, min, max) - min) / (max - min) end
    local function Fmt(v) return string.format("%." .. dec .. "f", v) end

    function row.Refresh()
        ApplyDisabled(row)
        local v = tonumber(GetVal(def)) or 0
        local tw = L.sliderW
        local x = Pct(v) * tw
        local zx = Pct(0) * tw
        knob:ClearAnchors()
        knob:SetAnchor(CENTER, track, LEFT, x, 1)
        local lo, hi = math.min(x, zx), math.max(x, zx)
        fill:ClearAnchors()
        fill:SetAnchor(LEFT, track, LEFT, lo, 0)
        fill:SetWidth(math.max(1, hi - lo))
        fill:SetHidden(hi - lo < 1)
        SetCol(fill, v < 0 and COL.cyan or COL.accent)
        zero:ClearAnchors()
        zero:SetAnchor(CENTER, track, LEFT, zx, 0)
        zero:SetHidden(not (min < 0 and max > 0))
        if not edit:HasFocus() then edit:SetText(Fmt(v)) end
        SetCol(edit, v < 0 and COL.cyan or COL.value)
    end

    local function Commit(v)
        v = Round(v, dec)
        if v ~= tonumber(GetVal(def)) then SetVal(def, v) end
    end

    local function FromStep(v)
        return Round(zo_round(v / step) * step, dec)
    end

    function row.Adjust(dir)
        if row.disabled then return end
        local v = tonumber(GetVal(def)) or 0
        Commit(api.Clamp(FromStep(v + dir * step), min, max))
    end

    function row.Activate()
        if row.disabled then return end
        edit:TakeFocus()
    end

    local dragging = false
    local function DragUpdate()
        if not dragging then return end
        local mx = GetUIMousePosition()
        local left, right = track:GetLeft(), track:GetRight()
        if right <= left then return end
        local p = api.Clamp((mx - left) / (right - left), 0, 1)
        Commit(api.Clamp(FromStep(min + p * (max - min)), min, max))
    end
    hit:SetMouseEnabled(true)
    hit:SetHandler("OnMouseDown", function(_, btn)
        if btn ~= MOUSE_BUTTON_INDEX_LEFT or row.disabled then return end
        dragging = true
        DragUpdate()
        hit:SetHandler("OnUpdate", DragUpdate)
    end)
    hit:SetHandler("OnMouseUp", function()
        dragging = false
        hit:SetHandler("OnUpdate", nil)
    end)
    hit:SetHandler("OnMouseWheel", function(_, delta) row.Adjust(delta > 0 and 1 or -1) end)
    hit:SetHandler("OnMouseEnter", function() RowHover(row, true) end)
    hit:SetHandler("OnMouseExit", function() RowHover(row, false) end)
    c:SetHandler("OnMouseWheel", function(_, delta) row.Adjust(delta > 0 and 1 or -1) end)

    -- getippt darf auch außerhalb vom slider liegen
    local function CommitEdit()
        local txt = (edit:GetText() or ""):gsub(",", ".")
        local n = tonumber(txt)
        if n and not row.disabled then
            Commit(api.Clamp(n, -HARD_LIMIT, HARD_LIMIT))
        end
        row.Refresh()
    end
    edit:SetHandler("OnEnter", function(self) self:LoseFocus() end)
    edit:SetHandler("OnFocusLost", CommitEdit)
    edit:SetHandler("OnEscape", function(self) self:SetText(Fmt(tonumber(GetVal(def)) or 0)); self:LoseFocus() end)
    edit:SetHandler("OnMouseEnter", function() RowHover(row, true) end)
    edit:SetHandler("OnMouseExit", function() RowHover(row, false) end)

    row.focusable = true
    return row
end

-- dropdown-liste, eine pro fenster
local function CloseDropdown(w)
    local dd = w and w.dropdown
    if not dd or dd.box:IsHidden() then return end
    dd.box:SetHidden(true)
    dd.catcher:SetHidden(true)
    dd.owner = nil
end

local function EnsureDropdown(w)
    if w.dropdown then return w.dropdown end
    local dd = { entries = {} }
    -- fängt klicks neben der liste ab und schließt sie
    dd.catcher = Hit(w.win, w.win, 48)
    dd.catcher:SetHidden(true)
    dd.catcher:SetHandler("OnMouseUp", function() CloseDropdown(w) end)
    dd.catcher:SetHandler("OnMouseWheel", function() CloseDropdown(w) end)

    dd.box = Box(w.win, "row", COL.accent, 0.9, COL.menu, 50)
    dd.box:SetHidden(true)
    w.dropdown = dd
    return dd
end

local function OpenDropdown(w, row, anchorCtrl)
    local def = row.def
    local dd = EnsureDropdown(w)
    if dd.owner == row and not dd.box:IsHidden() then CloseDropdown(w); return end
    local L = w.L
    local entryH = zo_round(L.rowH * 0.78)
    local width = anchorCtrl:GetWidth()
    local cur = GetVal(def)

    for i, ch in ipairs(def.choices) do
        local e = dd.entries[i]
        if not e then
            e = {}
            e.ctrl = WM:CreateControl(N("DdEntry"), dd.box, CT_CONTROL)
            e.ctrl:SetDrawLevel(51)
            e.hl = Tex(e.ctrl, MEDIA .. "UI_HGrad.dds", 52)
            e.hl:SetAnchorFill(e.ctrl)
            SetCol(e.hl, COL.accent, 0)
            e.mark = Tex(e.ctrl, nil, 53)
            e.mark:SetDimensions(3, entryH - 10)
            e.mark:SetAnchor(LEFT, e.ctrl, LEFT, 4, 0)
            SetCol(e.mark, COL.accent)
            e.label = Lbl(e.ctrl, L.fValue, COL.value)
            e.label:SetDrawLevel(54)
            e.label:SetAnchor(LEFT, e.ctrl, LEFT, 14, 0)
            e.ctrl:SetMouseEnabled(true)
            e.ctrl:SetHandler("OnMouseEnter", function() e.hl:SetAlpha(0.25) end)
            e.ctrl:SetHandler("OnMouseExit", function() e.hl:SetAlpha(0) end)
            dd.entries[i] = e
        end
        e.ctrl:ClearAnchors()
        e.ctrl:SetAnchor(TOPLEFT, dd.box, TOPLEFT, 3, 3 + (i - 1) * entryH)
        e.ctrl:SetDimensions(width - 6, entryH)
        e.ctrl:SetHidden(false)
        e.hl:SetAlpha(0)
        e.label:SetText(S(ch[2]))
        local selected = ch[1] == cur
        e.mark:SetHidden(not selected)
        SetCol(e.label, selected and COL.text or COL.value)
        local value = ch[1]
        e.ctrl:SetHandler("OnMouseUp", function(_, btn, inside)
            if not inside or btn ~= MOUSE_BUTTON_INDEX_LEFT then return end
            CloseDropdown(w)
            if row.disabled then return end
            Click()
            if GetVal(def) ~= value then SetVal(def, value) end
        end)
    end
    for i = #def.choices + 1, #dd.entries do dd.entries[i].ctrl:SetHidden(true) end

    dd.box:ClearAnchors()
    dd.box:SetAnchor(TOPRIGHT, anchorCtrl, BOTTOMRIGHT, 0, 4)
    dd.box:SetDimensions(width, #def.choices * entryH + 6)
    dd.owner = row
    dd.catcher:SetHidden(false)
    dd.box:SetHidden(false)
    Click()
end

local function BuildChoice(w, parent, def)
    local L = w.L
    local row = MakeRowBase(w, parent, def, L.rowH)
    local c = row.ctrl
    local bg = Box(c, "row", COL.accent2, 0.55, COL.field, 2)
    bg:SetDimensions(L.choiceW, L.toggleH + 8)
    bg:SetAnchor(RIGHT, c, RIGHT, -14, 0)
    local ah = L.toggleH * 0.7
    local left = Tex(bg, MEDIA .. "UI_Icon_Arrow.dds", 3)
    left:SetDimensions(ah, ah)
    left:SetAnchor(LEFT, bg, LEFT, 6, 0)
    SetCol(left, COL.value)
    local right = Tex(bg, MEDIA .. "UI_Icon_Arrow.dds", 3)
    right:SetDimensions(ah, ah)
    right:SetAnchor(RIGHT, bg, RIGHT, -6, 0)
    right:SetTextureCoords(1, 0, 0, 1)
    SetCol(right, COL.value)
    local val = Lbl(bg, L.fValue, COL.value)
    val:SetAnchor(LEFT, left, RIGHT, 2, 0)
    val:SetAnchor(RIGHT, right, LEFT, -2, 0)
    val:SetHeight(L.toggleH + 8)
    val:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    val:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    local function Index()
        local v = GetVal(def)
        for i, ch in ipairs(def.choices) do
            if ch[1] == v then return i end
        end
        return 1
    end

    function row.Refresh()
        ApplyDisabled(row)
        val:SetText(S(def.choices[Index()][2]))
    end

    function row.Adjust(dir)
        if row.disabled then return end
        Click()
        local n = #def.choices
        local i = (Index() - 1 + dir) % n + 1
        SetVal(def, def.choices[i][1])
    end

    function row.Activate() row.Adjust(1) end

    -- mitte öffnet die liste, die pfeile blättern
    local mid = Hit(bg, bg, 20)
    mid:SetHandler("OnMouseUp", function(_, btn, inside)
        if not inside or row.disabled then return end
        if btn == MOUSE_BUTTON_INDEX_LEFT then OpenDropdown(w, row, bg)
        elseif btn == MOUSE_BUTTON_INDEX_RIGHT then row.Adjust(-1) end
    end)
    mid:SetHandler("OnMouseWheel", function(_, delta) row.Adjust(delta > 0 and -1 or 1) end)
    mid:SetHandler("OnMouseEnter", function() bg:SetEdgeColor(COL.accent[1], COL.accent[2], COL.accent[3], 1); RowHover(row, true) end)
    mid:SetHandler("OnMouseExit", function() bg:SetEdgeColor(COL.accent2[1], COL.accent2[2], COL.accent2[3], 0.55); RowHover(row, false) end)

    for _, pair in ipairs({ { left, -1 }, { right, 1 } }) do
        local tex, dir = pair[1], pair[2]
        local h = WM:CreateControl(N("Hit"), bg, CT_CONTROL)
        h:SetDimensions(ah + 10, L.toggleH + 8)
        h:SetAnchor(CENTER, tex, CENTER, 0, 0)
        h:SetDrawLevel(21)
        h:SetMouseEnabled(true)
        h:SetHandler("OnMouseUp", function(_, btn, inside)
            if inside and btn == MOUSE_BUTTON_INDEX_LEFT then row.Adjust(dir) end
        end)
        h:SetHandler("OnMouseEnter", function() SetCol(tex, COL.text); RowHover(row, true) end)
        h:SetHandler("OnMouseExit", function() SetCol(tex, COL.value); RowHover(row, false) end)
    end
    row.focusable = true
    return row
end

local function OpenColorPicker(def, title)
    local c = GetVal(def) or { 1, 1, 1, 1 }
    local picker = (SYSTEMS and SYSTEMS.GetObject and SYSTEMS:GetObject("colorPicker")) or COLOR_PICKER
    if not picker or not picker.Show then return end
    picker:Show(function(r, g, b, a)
        SetVal(def, { r, g, b, a or 1 })
    end, c[1], c[2], c[3], c[4] or 1, title)
end

local function BuildColor(w, parent, def)
    local L = w.L
    local row = MakeRowBase(w, parent, def, L.rowH)
    local c = row.ctrl
    local sw = L.toggleW * 1.25
    local frame = Box(c, "row", COL.value, 0.85, { 0, 0, 0, 0 }, 4)
    frame:SetDimensions(sw + 6, L.toggleH + 6)
    frame:SetAnchor(RIGHT, c, RIGHT, -14, 0)
    local checker = Tex(c, MEDIA .. "UI_Checker.dds", 2)
    checker:SetAnchor(TOPLEFT, frame, TOPLEFT, 3, 3)
    checker:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -3, -3)
    checker:SetTextureCoords(0, sw / 16, 0, L.toggleH / 16)
    local swatch = Tex(c, nil, 3)
    swatch:SetAnchorFill(checker)
    local hexLbl = Lbl(c, L.fSmall, COL.dim)
    hexLbl:SetAnchor(RIGHT, frame, LEFT, -10, 0)

    function row.Refresh()
        ApplyDisabled(row)
        local v = GetVal(def) or { 1, 1, 1, 1 }
        swatch:SetColor(v[1], v[2], v[3], v[4] or 1)
        hexLbl:SetText(string.format("#%02X%02X%02X", zo_round(v[1] * 255), zo_round(v[2] * 255), zo_round(v[3] * 255)))
    end

    function row.Activate()
        if row.disabled then return end
        Click()
        OpenColorPicker(def, def.name and S(def.name))
    end
    row.Adjust = function() end

    local hit = Hit(c, frame, 20)
    hit:SetHandler("OnMouseUp", function(_, btn, inside) if inside and btn == MOUSE_BUTTON_INDEX_LEFT then row.Activate() end end)
    hit:SetHandler("OnMouseEnter", function() frame:SetEdgeColor(COL.text[1], COL.text[2], COL.text[3], 1); RowHover(row, true) end)
    hit:SetHandler("OnMouseExit", function() frame:SetEdgeColor(COL.value[1], COL.value[2], COL.value[3], 0.85); RowHover(row, false) end)
    row.focusable = true
    return row
end

local function MakeButton(w, parent, text, width, height, onClick, accent)
    local L = w.L
    local col = accent or COL.accent
    local b = Box(parent, "row", col, 0.75, { col[1] * 0.25, col[2] * 0.2, col[3] * 0.3, 0.85 }, 3)
    b:SetDimensions(width, height)
    local lbl = Lbl(b, L.fValue, COL.text, text)
    lbl:SetAnchor(CENTER, b, CENTER, 0, 0)
    lbl:SetDrawLevel(4)
    local hit = Hit(b, b, 20)
    local btn = { ctrl = b, label = lbl, hit = hit }
    function btn.SetHot(on)
        b:SetEdgeColor(col[1], col[2], col[3], on and 1 or 0.75)
        b:SetCenterColor(col[1] * (on and 0.42 or 0.25), col[2] * (on and 0.36 or 0.2), col[3] * (on and 0.5 or 0.3), 0.9)
    end
    hit:SetHandler("OnMouseEnter", function() btn.SetHot(true) end)
    hit:SetHandler("OnMouseExit", function() btn.SetHot(false) end)
    hit:SetHandler("OnMouseUp", function(_, mb, inside)
        if inside and mb == MOUSE_BUTTON_INDEX_LEFT and onClick then Click(); onClick() end
    end)
    return btn
end

local function BuildButton(w, parent, def)
    local L = w.L
    local row = MakeRowBase(w, parent, def, L.rowH)
    local c = row.ctrl
    local btn = MakeButton(w, c, S(def.name), w.rowW - 28, L.rowH - 10, function()
        if row.disabled then return end
        def.func()
        OnValueChanged(def)
    end)
    btn.ctrl:SetAnchor(CENTER, c, CENTER, 0, 0)
    btn.hit:SetHandler("OnMouseEnter", function() btn.SetHot(true); RowHover(row, true) end)
    btn.hit:SetHandler("OnMouseExit", function() btn.SetHot(false); RowHover(row, false) end)
    function row.Refresh() ApplyDisabled(row) end
    function row.Activate()
        if row.disabled then return end
        Click()
        def.func()
        OnValueChanged(def)
    end
    row.Adjust = function() end
    row.focusable = true
    return row
end

local function BuildHeader(w, parent, def)
    local L = w.L
    local h = zo_round(L.rowH * 1.05)
    local row = { def = def, height = h }
    local c = WM:CreateControl(N("Hdr"), parent, CT_CONTROL)
    c:SetDimensions(w.rowW, h)
    row.ctrl = c
    local lbl = Lbl(c, L.fHeader, COL.accent, zo_strformat("<<Z:1>>", S(def.name)))
    lbl:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, 12, -10)
    local div = Tex(c, MEDIA .. "UI_Divider.dds", 1)
    div:SetDimensions(w.rowW - 12, 6)
    div:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, 6, -2)
    SetCol(div, COL.accent, 0.55)
    function row.Refresh() end
    return row
end

-- GetTextHeight ist beim aufbau manchmal noch 0
local function EstimateTextHeight(font, text, width)
    local px = tonumber(font:match("|(%d+)|")) or 15
    local perLine = math.max(10, math.floor(width / (px * 0.52)))
    local lines = 0
    for part in (text .. "\n"):gmatch("(.-)\n") do
        lines = lines + math.max(1, math.ceil(#part / perLine))
    end
    return lines * px * 1.32
end

local function BuildDesc(w, parent, def)
    local L = w.L
    local row = { def = def }
    local c = WM:CreateControl(N("Desc"), parent, CT_CONTROL)
    row.ctrl = c
    local lbl = Lbl(c, L.fDesc, COL.dim)
    lbl:SetVerticalAlignment(TEXT_ALIGN_TOP)
    lbl:SetWrapMode(TEXT_WRAP_MODE_WORD_WRAP)
    local tw = w.rowW - 28
    lbl:SetDimensionConstraints(tw, 0, tw, 0)
    lbl:SetAnchor(TOPLEFT, c, TOPLEFT, 14, 8)
    local text = S(def.text)
    lbl:SetText(text)
    local th = math.max(lbl:GetTextHeight() or 0, EstimateTextHeight(L.fDesc, text, tw))
    row.height = th + 18
    c:SetDimensions(w.rowW, row.height)
    function row.Refresh() end
    return row
end

local BUILDERS = {
    toggle = BuildToggle, slider = BuildSlider, choice = BuildChoice, color = BuildColor,
    button = BuildButton, header = BuildHeader, desc = BuildDesc,
}

local function ScrollChildOf(scroll)
    return GetControl(scroll, "ScrollChild") or scroll:GetNamedChild("ScrollChild") or scroll.scrollChild
end

local function BuildPage(w, index)
    local def = BuildPageDefs()[index]
    local page = { def = def, rows = {}, focusables = {} }
    local scroll = WM:CreateControlFromVirtual(N("Scroll"), w.content, "ZO_ScrollContainer")
    scroll:SetAnchor(TOPLEFT, w.pageSub, BOTTOMLEFT, -6, 8)
    scroll:SetAnchor(BOTTOMRIGHT, w.content, BOTTOMRIGHT, -8, -10)
    scroll:SetHidden(true)
    page.scroll = scroll
    local child = ScrollChildOf(scroll)
    -- das child liegt im template auf BACKGROUND, dann gehen keine klicks durch
    scroll:SetDrawLayer(DL_CONTROLS)
    child:SetDrawLayer(DL_CONTROLS)

    local y = 0
    for _, cdef in ipairs(def.controls) do
        local builder = BUILDERS[cdef.type]
        if builder then
            local row = builder(w, child, cdef)
            row.ctrl:SetAnchor(TOPLEFT, child, TOPLEFT, 0, y)
            y = y + row.height + 2
            page.rows[#page.rows + 1] = row
            if row.focusable then page.focusables[#page.focusables + 1] = row end
        end
    end
    local spacer = WM:CreateControl(N("Sp"), child, CT_CONTROL)
    spacer:SetDimensions(1, 16)
    spacer:SetAnchor(TOPLEFT, child, TOPLEFT, 0, y)
    w.pages[index] = page
    return page
end

local function RefreshPage(page, animate)
    if not page then return end
    for _, row in ipairs(page.rows) do
        if row.Refresh then row.Refresh(animate) end
    end
end

local function SetFocus(w, idx)
    local page = w.pages[w.pageIndex]
    if not page then return end
    local list = page.focusables
    if #list == 0 then w.focus = nil; return end
    idx = math.max(1, math.min(#list, idx))
    if w.focus and list[w.focusIdx] then
        list[w.focusIdx].focused = false
        list[w.focusIdx].UpdateHighlight()
    end
    w.focusIdx = idx
    local row = list[idx]
    w.focus = row
    row.focused = true
    row.UpdateHighlight()
    RowHover(row, row.hover)
    local txt = row.def.tip and S(row.def.tip) or (row.def.name and S(row.def.name)) or ""
    if row.def.reload then txt = txt .. "\n|cd69a4f" .. S(SI_AAB_RELOAD_NOTE) .. "|r" end
    w.hint:SetText(txt)
    if ZO_Scroll_ScrollControlIntoCentralView then
        ZO_Scroll_ScrollControlIntoCentralView(page.scroll, row.ctrl)
    elseif ZO_Scroll_ScrollControlIntoView then
        ZO_Scroll_ScrollControlIntoView(page.scroll, row.ctrl)
    end
    if w.keybinds and KEYBIND_STRIP then KEYBIND_STRIP:UpdateKeybindButtonGroup(w.keybinds) end
end

local function SelectPage(w, index, silent)
    CloseDropdown(w)
    local defs = BuildPageDefs()
    index = ((index - 1) % #defs) + 1
    if w.pages[w.pageIndex] then w.pages[w.pageIndex].scroll:SetHidden(true) end
    if w.focus then w.focus.focused = false; w.focus.UpdateHighlight(); w.focus = nil end
    w.pageIndex = index
    sv.uiLastPage = defs[index].id
    local page = w.pages[index] or BuildPage(w, index)
    page.scroll:SetHidden(false)
    RefreshPage(page)
    for i, tab in ipairs(w.tabs) do tab.SetSelected(i == index) end
    w.pageIcon:SetTexture(MEDIA .. defs[index].icon .. ".dds")
    w.pageTitle:SetText(S(defs[index].title))
    w.pageSub:SetText(defs[index].tip and S(defs[index].tip) or "")
    w.hint:SetText(S(w.mode == "gamepad" and SI_AAB_UI_HINT_GAMEPAD or SI_AAB_UI_HINT_KEYBOARD))
    if w.mode == "gamepad" then SetFocus(w, 1) end
    if not silent then Sound(SOUNDS and SOUNDS.MENU_BAR_CLICK) end
    local demo = defs[index].demo
    if demo == "quick" then Preview("quick")
    elseif demo == "proc" then Preview("proc")
    elseif demo == "ult" then Preview("ultpress")
    else Preview("press") end
end

OnValueChanged = function(def)
    local w = active
    if not w then return end
    RefreshPage(w.pages[w.pageIndex], true)
    RefreshPreviewFrames(w)
    local kind = def.preview
    if kind == "ult" or kind == "ultpress" then StartPreviewUlt(w) end
    if kind == "proc" or def.key == "glowColor" or def.key == "glowPadding" or def.key == "glowIntensity" or def.key == "glowEnabled" then
        StartPreviewPulse(w)
    end
    if kind then Preview(kind) end
    if def.type == "button" then
        StartPreviewPulse(w)
        StartPreviewUlt(w)
    end
end

local function BuildTabs(w)
    local L = w.L
    w.tabs = {}
    w.tabMarks = {}
    local prev
    for i, def in ipairs(BuildPageDefs()) do
        local t = WM:CreateControl(N("Tab"), w.nav, CT_CONTROL)
        t:SetDimensions(L.nav - 16, L.tabH)
        if prev then t:SetAnchor(TOPLEFT, prev, BOTTOMLEFT, 0, 4)
        else t:SetAnchor(TOPLEFT, w.nav, TOPLEFT, 8, 12) end
        prev = t
        local hl = Tex(t, MEDIA .. "UI_HGrad.dds", 2)
        hl:SetAnchorFill(t)
        SetCol(hl, COL.accent, 0)
        -- markierung: stern im sternbild bzw. feder
        local ms = zo_round(L.tabH * T.markerF)
        local mx = zo_round(L.tabH * 0.36)
        local glow = Tex(t, MEDIA .. "UI_SoftGlow.dds", 3)
        glow:SetDimensions(ms * 2.2, ms * 2.2)
        glow:SetAnchor(CENTER, t, LEFT, mx, 0)
        local mark = Tex(t, MEDIA .. T.marker, 4)
        mark:SetAnchor(CENTER, t, LEFT, mx, 0)
        local ic = Tex(t, MEDIA .. def.icon .. ".dds", 4)
        ic:SetDimensions(L.icon, L.icon)
        ic:SetAnchor(LEFT, t, LEFT, mx * 2, 0)
        SetCol(ic, COL.dim)
        local lbl = Lbl(t, L.fNav, COL.dim, S(def.title))
        lbl:SetAnchor(LEFT, ic, RIGHT, 12, 0)
        lbl:SetWidth(L.nav - L.icon - mx * 2 - 36)
        lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        w.tabMarks[i] = mark

        local tab = { ctrl = t }
        local selected, hot = false, false
        local starry = T.constellation
        local function Paint()
            hl:SetAlpha(selected and 0.30 or (hot and 0.13 or 0))
            local big = selected and ms or zo_round(ms * 0.5)
            mark:SetDimensions(big, big)
            mark:SetHidden(not (selected or starry or hot))
            SetCol(mark, selected and COL.text or COL.value, selected and 1 or (hot and 0.8 or 0.45))
            glow:SetHidden(not selected)
            SetCol(glow, COL.accent, 0.55)
            SetCol(ic, selected and COL.text or (hot and COL.value or COL.dim))
            SetCol(lbl, selected and COL.text or (hot and COL.value or COL.dim))
        end
        function tab.SetSelected(on) selected = on; Paint() end
        t:SetMouseEnabled(true)
        t:SetHandler("OnMouseEnter", function() hot = true; Paint() end)
        t:SetHandler("OnMouseExit", function() hot = false; Paint() end)
        t:SetHandler("OnMouseUp", function(_, btn, inside)
            if inside and btn == MOUSE_BUTTON_INDEX_LEFT then SelectPage(w, i) end
        end)
        w.tabs[i] = tab
    end
    -- sternbild: feine linie durch alle sterne
    if T.constellation and #w.tabMarks > 1 then
        local line = Tex(w.nav, nil, 3)
        line:SetWidth(1)
        line:SetAnchor(TOP, w.tabMarks[1], CENTER, 0, 0)
        line:SetAnchor(BOTTOM, w.tabMarks[#w.tabMarks], CENTER, 0, 0)
        SetCol(line, COL.accent, 0.28)
    end
end

local function MakeChip(w, parent, icon, text, onClick, toggle)
    local L = w.L
    local h = zo_round(L.rowH * L.chipF)
    local b = Box(parent, "row", COL.accent2, 0.7, COL.chip, 3)
    b:SetHeight(h)
    local ic = Tex(b, MEDIA .. (icon:find("%.dds$") and icon or icon .. ".dds"), 4)
    ic:SetDimensions(h * 0.5, h * 0.5)
    ic:SetAnchor(LEFT, b, LEFT, 10, 0)
    SetCol(ic, COL.value)
    local lbl = Lbl(b, L.fChip, COL.text, text)
    lbl:SetAnchor(LEFT, ic, RIGHT, 7, 0)
    lbl:SetDrawLevel(4)
    local chip = { ctrl = b, on = false, label = lbl }
    local hot = false
    local function Paint()
        local lit = hot or chip.on
        b:SetEdgeColor(COL.accent[1], COL.accent[2], COL.accent[3], lit and 1 or 0.6)
        if toggle and chip.on then
            b:SetCenterColor(COL.chipOn[1], COL.chipOn[2], COL.chipOn[3], COL.chipOn[4])
            SetCol(ic, COL.text)
        else
            b:SetCenterColor(COL.chip[1], COL.chip[2], COL.chip[3], COL.chip[4])
            SetCol(ic, hot and COL.text or COL.value)
        end
    end
    function chip.SetOn(on) chip.on = on and true or false; Paint() end
    local hit = Hit(b, b, 20)
    hit:SetHandler("OnMouseEnter", function() hot = true; Paint() end)
    hit:SetHandler("OnMouseExit", function() hot = false; Paint() end)
    hit:SetHandler("OnMouseUp", function(_, btn, inside)
        if inside and btn == MOUSE_BUTTON_INDEX_LEFT then Click(); onClick(chip) end
    end)
    Paint()
    return chip
end

local function BuildPreview(w)
    local L = w.L
    local pv = { slots = {} }
    w.preview = pv
    local panel = w.previewPanel
    local inner = L.preview - 2 * L.pad

    local title = Lbl(panel, L.fHeader, COL.accent, zo_strformat("<<Z:1>>", S(SI_AAB_UI_PREVIEW)))
    title:SetAnchor(TOPLEFT, panel, TOPLEFT, L.pad, 12)
    local sub = Lbl(panel, L.fSmall, COL.dim, S(SI_AAB_UI_PREVIEW_SUB))
    sub:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 2)
    sub:SetWidth(inner)
    sub:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    sub:SetMaxLineCount(1)

    local stage = Box(panel, "row", COL.accent2, 0.45, COL.stage, 1)
    stage:SetDimensions(inner, L.stageH)
    stage:SetAnchor(TOPLEFT, sub, BOTTOMLEFT, 0, 12)
    local light = Tex(stage, MEDIA .. "UI_SoftGlow.dds", 2)
    light:SetDimensions(inner * 1.1, L.stageH * 1.2)
    light:SetAnchor(CENTER, stage, CENTER, 0, -L.stageH * 0.12)
    SetCol(light, COL.accent2, 0.22)
    pv.stage = stage

    local S_ = L.slot
    local gap = zo_round(S_ * 0.14)
    local ultGap = zo_round(S_ * 0.34)
    local totalW = 6 * S_ + 4 * gap + ultGap
    local x0 = (inner - totalW) / 2
    local barY = zo_round(L.stageH * 0.24)
    for i = 1, 6 do
        local p = MakePreviewSlot(stage, S_)
        local x = x0 + (i - 1) * (S_ + gap) + ((i == 6) and (ultGap - gap) or 0)
        p.slot:SetAnchor(TOPLEFT, stage, TOPLEFT, x, barY)
        pv.slots[i] = p
        local key = Lbl(stage, L.fSmall, COL.dim, i == 6 and "R" or tostring(i))
        key:SetAnchor(TOP, p.slot, BOTTOM, 0, 4)
    end
    local ult = pv.slots[6]
    pv.ultReady = MakeGlow(ult.flip, 19)
    do
        local tx = api.gpUltTextures
        local k = ult.flip:GetWidth() / 67
        local inset, offY, fillW = zo_floor(12 * k), zo_floor(36 * k), zo_floor(70 * k)
        local edge = math.max(8, zo_round(16 * k))
        local frame = WM:CreateControl(N("GpFrame"), ult.slot, CT_BACKDROP)
        frame:SetEdgeTexture(tx.edge, 128, 16, edge, 0)
        frame:SetCenterColor(0, 0, 0, 0)
        frame:SetInsets(edge, edge, -edge, -edge)
        frame:SetAnchor(TOPLEFT, ult.flip, TOPLEFT, -inset, -inset)
        frame:SetAnchor(BOTTOMRIGHT, ult.flip, BOTTOMRIGHT, inset, inset)
        frame:SetDrawLevel(5)
        local fills = {}
        for i, offX in ipairs({ zo_floor(-37 * k), zo_floor(33 * k) }) do
            local t = Tex(ult.slot, tx.fill, 6)
            t:SetWidth(fillW)
            t:SetAnchor(TOPLEFT, ult.flip, TOPLEFT, offX, -offY)
            t:SetAnchor(BOTTOMLEFT, ult.flip, BOTTOMLEFT, offX, offY)
            fills[i] = t
        end
        frame:SetHidden(true)
        fills[1]:SetHidden(true)
        fills[2]:SetHidden(true)
        pv.gpUlt = { frame = frame, left = fills[1], right = fills[2] }
    end
    pv.bracket = { track = {}, fill = {}, glow = {} }
    for _, seg in ipairs(SEGS) do
        pv.bracket.track[seg] = Tex(ult.slot, nil, 6)
        pv.bracket.fill[seg]  = Tex(ult.slot, nil, 7)
        local g = Tex(ult.slot, nil, 8)
        g:SetBlendMode(TEX_BLEND_MODE_ADD)
        pv.bracket.glow[seg] = g
        pv.bracket.track[seg]:SetHidden(true)
        pv.bracket.fill[seg]:SetHidden(true)
        g:SetHidden(true)
    end

    local q = MakePreviewSlot(stage, S_)
    q.slot:SetAnchor(TOPLEFT, stage, TOPLEFT, x0, barY + S_ + zo_round(S_ * 0.6))
    local qk = Lbl(stage, L.fSmall, COL.dim, "Q")
    qk:SetAnchor(TOP, q.slot, BOTTOM, 0, 4)
    q.cdOverlay = Tex(q.flip, nil, 6)
    q.cdOverlay:SetColor(0, 0, 0, 0.65)
    q.cdOverlay:SetAnchor(BOTTOMLEFT, q.flip, BOTTOMLEFT, 0, 0)
    q.cdOverlay:SetAnchor(BOTTOMRIGHT, q.flip, BOTTOMRIGHT, 0, 0)
    q.cdOverlay:SetHidden(true)
    q.cdLabel = Lbl(q.flip, L.fValue, COL.text, "")
    q.cdLabel:SetAnchor(CENTER, q.flip, CENTER, 0, 0)
    q.cdLabel:SetDrawLevel(9)
    q.cdLabel:SetHidden(true)
    local qTitle = Lbl(stage, L.fValue, COL.text, S(SI_AAB_UI_TAB_QUICK))
    qTitle:SetAnchor(BOTTOMLEFT, q.slot, RIGHT, 14, -1)
    q.status = Lbl(stage, L.fSmall, COL.good, S(SI_AAB_UI_PV_READY))
    q.status:SetAnchor(TOPLEFT, q.slot, RIGHT, 14, 1)
    pv.quick = q

    local chipsTop = WM:CreateControl(N("Chips"), panel, CT_CONTROL)
    chipsTop:SetDimensions(inner, 1)
    chipsTop:SetAnchor(TOPLEFT, stage, BOTTOMLEFT, 0, 14)
    local chipW = (inner - 8) / 2
    local chips = {
        { "UI_Icon_Play",   SI_AAB_UI_PV_PRESS,  function() Preview("press") end },
        { "UI_Icon_Pulse",  SI_AAB_UI_PV_PROC,   function(ch) sv.uiProcSim = not sv.uiProcSim; ch.SetOn(sv.uiProcSim); StartPreviewPulse(w) end, true, "chipProc" },
        { "UI_Icon_Reset",  SI_AAB_UI_PV_EXPIRE, function() Preview("expire") end },
        { "UI_Icon_Ult",    SI_AAB_UI_PV_ULT,    function() Preview("ultpress"); StartPreviewUlt(w) end },
        { "UI_Icon_Quick",  SI_AAB_UI_PV_POTION, function() Preview("quick") end },
        { "UI_Icon_Bounce", SI_AAB_UI_PV_AUTO,   function(ch) sv.uiAutoDemo = not sv.uiAutoDemo; ch.SetOn(sv.uiAutoDemo); StartAutoDemo() end, true, "chipAuto" },
    }
    for i, cd in ipairs(chips) do
        local chip = MakeChip(w, panel, cd[1], S(cd[2]), cd[3], cd[4])
        chip.ctrl:SetWidth(chipW)
        local col = (i - 1) % 2
        local rowN = math.floor((i - 1) / 2)
        chip.ctrl:SetAnchor(TOPLEFT, chipsTop, TOPLEFT, col * (chipW + 8), rowN * (zo_round(L.rowH * L.chipF) + 8))
        if cd[5] then pv[cd[5]] = chip end
    end

    local note = Box(panel, "row", COL.cyan, 0.35, COL.note, 1)
    note:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, L.pad, -L.pad)
    note:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -L.pad, -L.pad)
    local nlbl = Lbl(note, L.fSmall, COL.value, S(SI_AAB_UI_NEG_SHORT))
    nlbl:SetVerticalAlignment(TEXT_ALIGN_TOP)
    nlbl:SetWrapMode(TEXT_WRAP_MODE_WORD_WRAP)
    nlbl:SetDimensionConstraints(inner - 24, 0, inner - 24, 0)
    nlbl:SetAnchor(TOPLEFT, note, TOPLEFT, 12, 10)
    local nh = math.max(nlbl:GetTextHeight() or 0, EstimateTextHeight(L.fSmall, S(SI_AAB_UI_NEG_SHORT), inner - 24))
    note:SetHeight(nh + 20)
end

local function SavePos(w)
    local cx, cy = w.win:GetCenter()
    local gx, gy = GuiRoot:GetCenter()
    sv[w.mode == "gamepad" and "uiPosGamepad" or "uiPosKeyboard"] = { cx - gx, cy - gy }
end

local function PlaceWindow(w)
    local L = w.L
    local sw, sh = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    local scale = math.min(1, (sw - 40) / L.w, (sh - (w.mode == "gamepad" and 140 or 40)) / L.h)
    w.win:SetScale(scale)
    w.scale = scale
    local pos = sv[w.mode == "gamepad" and "uiPosGamepad" or "uiPosKeyboard"]
    w.win:ClearAnchors()
    local yOff = (w.mode == "gamepad") and -30 or 0
    if pos and w.mode == "keyboard" then
        w.win:SetAnchor(CENTER, GuiRoot, CENTER, pos[1], pos[2])
    else
        w.win:SetAnchor(CENTER, GuiRoot, CENTER, 0, yOff)
    end
end

local ResetPage, ResetAll -- forward

-- hintergrund: kachel-ebenen die langsam wandern. nur coords, kein neuaufbau
local BG_UPDATE = "AABStudio_Bg"

local function PaintLayers(w, now)
    local L = w.L
    local t = now / 1000
    for _, ly in ipairs(w.layers) do
        local d = ly.def
        if d.tile then
            local su, sh = L.w / d.tile, L.h / d.tile
            local ou = ((d.ox or 0) + t * (d.vx or 0) / d.tile) % 1
            local ov = ((d.oy or 0) + t * (d.vy or 0) / d.tile) % 1
            ly.ctrl:SetTextureCoords(ou, ou + su, ov, ov + sh)
        end
    end
end

local function StopMotion(w, keepUpdate)
    if not keepUpdate then EM:UnregisterForUpdate(BG_UPDATE) end
    for _, tl in ipairs(w.timelines) do tl:Stop() end
    if w.comet then w.comet:SetAlpha(0) end
    for _, ly in ipairs(w.layers) do
        ly.ctrl:SetAlpha((ly.def.twinkle or ly.def.breathe) and 0.75 or 1)
    end
end

-- bewegung nur solange das fenster offen ist, sonst null kosten
local function StartMotion(w)
    StopMotion(w)
    PaintLayers(w, 0)
    if not sv.uiBgMotion then return end
    for _, tl in ipairs(w.timelines) do tl:PlayFromStart() end
    if w.moving then
        EM:RegisterForUpdate(BG_UPDATE, 33, function() PaintLayers(w, GetFrameTimeMilliseconds()) end)
    end
end

local function BuildBackground(w)
    local win, L = w.win, w.L
    w.layers, w.timelines = {}, {}
    for i, d in ipairs(T.layers) do
        local t = Tex(win, nil, i)
        t:SetDrawLayer(DL_BACKGROUND)
        t:SetAnchor(TOPLEFT, win, TOPLEFT, 2, 2)
        t:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -2, -2)
        if d.add then t:SetBlendMode(TEX_BLEND_MODE_ADD) end
        if d.tile and t.SetAddressMode and TEX_MODE_WRAP then t:SetAddressMode(TEX_MODE_WRAP) end
        SetCol(t, d.color or { 1, 1, 1, 1 }, d.alpha)
        Heavy(w, t, MEDIA .. d.file)
        if d.vx or d.vy then w.moving = true end
        local period = d.twinkle or d.breathe
        if period then
            local tl = ANIMATION_MANAGER:CreateTimeline()
            local a = tl:InsertAnimation(ANIMATION_ALPHA, t)
            a:SetAlphaValues(d.twinkle and 0.25 or 0.5, 1)
            a:SetDuration(period)
            a:SetEasingFunction(ZO_EaseInOutQuadratic)
            tl:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, LOOP_INDEFINITELY)
            w.timelines[#w.timelines + 1] = tl
        end
        w.layers[i] = { ctrl = t, def = d }
    end
    w.texScale = L.w / LAYOUT.keyboard.w

    -- sternschnuppe, läuft komplett in der engine
    if T.comet then
        local k = w.texScale
        local c = Tex(win, nil, #T.layers + 1)
        c:SetDrawLayer(DL_BACKGROUND)
        c:SetBlendMode(TEX_BLEND_MODE_ADD)
        c:SetDimensions(256 * k, 128 * k)
        Heavy(w, c, MEDIA .. T.comet)
        local x0, y0 = zo_round(L.w * 0.7), zo_round(-24 * k)
        local dx = zo_round(L.w * 0.42)
        local dy = zo_round(dx * 0.488)
        c:SetAnchor(TOPLEFT, win, TOPLEFT, x0, y0)
        c:SetAlpha(0)
        local tl = ANIMATION_MANAGER:CreateTimeline()
        local mv = tl:InsertAnimation(ANIMATION_TRANSLATE, c, 6500)
        mv:SetDuration(1300)
        mv:SetTranslateOffsets(x0, y0, x0 - dx, y0 + dy)
        local fadeIn = tl:InsertAnimation(ANIMATION_ALPHA, c, 6500)
        fadeIn:SetDuration(220)
        fadeIn:SetAlphaValues(0, 1)
        local fadeOut = tl:InsertAnimation(ANIMATION_ALPHA, c, 6900)
        fadeOut:SetDuration(900)
        fadeOut:SetAlphaValues(1, 0)
        tl:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, LOOP_INDEFINITELY)
        w.comet = c
        w.timelines[#w.timelines + 1] = tl
    end
end

local function TextW(lbl, font)
    local px = tonumber(font:match("|(%d+)|")) or 14
    return math.max(lbl:GetTextWidth() or 0, #lbl:GetText() * px * 0.6)
end

local function BuildWindow(mode, theme)
    local prevT = T
    UseTheme(theme)
    local L = MakeLayout(mode, T)
    local w = { mode = mode, theme = theme, L = L, pages = {}, pageIndex = 1, heavy = {}, heavyOn = true }
    local win = WM:CreateTopLevelWindow(N("Win_" .. mode .. "_" .. theme))
    win:SetDimensions(L.w, L.h)
    win:SetHidden(true)
    win:SetMouseEnabled(true)
    win:SetMovable(mode == "keyboard")
    win:SetClampedToScreen(true)
    win:SetHandler("OnMoveStop", function() SavePos(w) end)
    w.win = win

    local shadow = Tex(win, MEDIA .. "UI_SoftGlow.dds", 0)
    shadow:SetDrawLayer(DL_BACKGROUND)
    shadow:SetAnchor(TOPLEFT, win, TOPLEFT, -70, -60)
    shadow:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, 70, 80)
    shadow:SetColor(0, 0, 0, 0.85)

    BuildBackground(w)
    local k = w.texScale

    local border = Box(win, "frame", COL.accent, 0.9, { 0, 0, 0, 0 }, 30)
    border:SetAnchorFill(win)

    local logo = Tex(win, MEDIA .. "UI_Logo.dds", 5)
    logo:SetDimensions(L.logo, L.logo)
    logo:SetAnchor(TOPLEFT, win, TOPLEFT, L.pad, (L.header - L.logo) / 2 + 2)
    local logoGlow = Tex(win, MEDIA .. "UI_SoftGlow.dds", 4)
    logoGlow:SetDimensions(L.logo * 1.9, L.logo * 1.9)
    logoGlow:SetAnchor(CENTER, logo, CENTER, 0, 0)
    SetCol(logoGlow, COL.accent, 0.35)

    local title = Lbl(win, L.fTitle, COL.text, T.title)
    title:SetAnchor(BOTTOMLEFT, logo, RIGHT, 18, 4)
    local subtitle = Lbl(win, L.fSub, COL.dim,
        zo_strformat("<<Z:1>>", S(SI_AAB_UI_TITLE_SUB)) .. "   " .. T.sep .. "   v" .. (api.version or "?"))
    subtitle:SetAnchor(TOPLEFT, logo, RIGHT, 20, 2)

    local hdrLine = Tex(win, MEDIA .. "UI_Divider.dds", 5)
    hdrLine:SetDimensions(L.w - 2 * L.pad, 6)
    hdrLine:SetAnchor(TOPLEFT, win, TOPLEFT, L.pad, L.header - 3)
    SetCol(hdrLine, COL.accent, 0.8)
    if T.ornament then
        local orn = Tex(win, MEDIA .. T.ornament, 6)
        orn:SetDimensions(zo_round(256 * k), zo_round(64 * k))
        orn:SetAnchor(CENTER, hdrLine, CENTER, 0, 0)
        SetCol(orn, COL.accent, 0.9)
    end
    if T.constellation then
        -- ein paar funken auf der linie
        for _, f in ipairs({ { 0.34, 0.5 }, { 0.58, 0.32 }, { 0.83, 0.42 } }) do
            local st = Tex(win, MEDIA .. T.marker, 6)
            local s = zo_round(L.header * 0.22 * (0.6 + f[2]))
            st:SetDimensions(s, s)
            st:SetAnchor(CENTER, hdrLine, LEFT, (L.w - 2 * L.pad) * f[1], 0)
            SetCol(st, COL.value, math.min(1, 0.5 + f[2]))
        end
    end

    local close
    if mode == "keyboard" then
        close = Tex(win, MEDIA .. "UI_Icon_Close.dds", 6)
        close:SetDimensions(26, 26)
        close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -L.pad, L.pad)
        SetCol(close, COL.dim)
        close:SetMouseEnabled(true)
        close:SetHandler("OnMouseEnter", function() SetCol(close, COL.bad) end)
        close:SetHandler("OnMouseExit", function() SetCol(close, COL.dim) end)
        close:SetHandler("OnMouseUp", function(_, btn, inside) if inside and btn == MOUSE_BUTTON_INDEX_LEFT then Studio.Close() end end)
    end
    local chipH = zo_round(L.rowH * 0.7)
    local modeChip = Box(win, "row", COL.cyan, 0.6, COL.note, 5)
    modeChip:SetHeight(chipH)
    if close then modeChip:SetAnchor(RIGHT, close, LEFT, -16, 0)
    else modeChip:SetAnchor(TOPRIGHT, win, TOPRIGHT, -L.pad, (L.header - chipH) / 2) end
    local mIcon = Tex(modeChip, MEDIA .. "UI_Icon_Gamepad.dds", 6)
    mIcon:SetDimensions(chipH * 0.62, chipH * 0.62)
    mIcon:SetAnchor(LEFT, modeChip, LEFT, 10, 0)
    SetCol(mIcon, COL.cyan)
    local mLbl = Lbl(modeChip, L.fChip, COL.cyan, S(mode == "gamepad" and SI_AAB_UI_MODE_GP or SI_AAB_UI_MODE_KB))
    mLbl:SetAnchor(LEFT, mIcon, RIGHT, 8, 0)
    modeChip:SetWidth(chipH * 0.62 + TextW(mLbl, L.fChip) + 34)

    -- design-umschalter
    w.themeChips = {}
    local prev = modeChip
    for _, id in ipairs({ "lace", "nebula" }) do
        local th = THEMES[id]
        local chip = MakeChip(w, win, th.marker, S(_G[th.name]), function() Studio.ShowTheme(id) end, true)
        local h = zo_round(L.rowH * L.chipF)
        chip.ctrl:SetWidth(h * 0.5 + 10 + 7 + TextW(chip.label, L.fChip) + 16)
        chip.ctrl:SetAnchor(RIGHT, prev, LEFT, prev == modeChip and -16 or -6, 0)
        chip.SetOn(id == theme)
        w.themeChips[id] = chip
        prev = chip.ctrl
    end

    local bodyTop = L.header + L.pad * 0.7
    local bodyH = L.h - bodyTop - L.footer - L.pad * 0.6

    local nav = Box(win, "panel", COL.accent2, 0.5, COL.panel, 1)
    nav:SetDimensions(L.nav, bodyH)
    nav:SetAnchor(TOPLEFT, win, TOPLEFT, L.pad, bodyTop)
    w.nav = nav

    local pvPanel = Box(win, "panel", COL.accent2, 0.5, COL.panel, 1)
    pvPanel:SetDimensions(L.preview, bodyH)
    pvPanel:SetAnchor(TOPRIGHT, win, TOPRIGHT, -L.pad, bodyTop)
    w.previewPanel = pvPanel

    local contentW = L.w - 4 * L.pad - L.nav - L.preview
    local content = Box(win, "panel", COL.accent2, 0.5, COL.panel, 1)
    content:SetDimensions(contentW, bodyH)
    content:SetAnchor(TOPLEFT, nav, TOPRIGHT, L.pad, 0)
    w.content = content
    w.rowW = contentW - 2 * 12 - 18

    -- wasserzeichen unten rechts im inhalt
    local wm = T.watermark
    if wm then
        local mark = Tex(content, nil, 1)
        local s = zo_round(math.min(contentW, bodyH) * wm[2] * 0.6)
        mark:SetDimensions(s, s)
        mark:SetAnchor(BOTTOMRIGHT, content, BOTTOMRIGHT, -14, -14)
        if wm[4] then
            mark:SetBlendMode(TEX_BLEND_MODE_ADD)
            mark:SetColor(1, 1, 1, wm[3])
        else
            SetCol(mark, COL.accent, wm[3])
        end
        Heavy(w, mark, MEDIA .. wm[1])
    end

    if T.corners then
        local cs = zo_round(84 * k)
        local spots = {
            { TOPLEFT, 0, 1, 0, 1, 3, 3 }, { TOPRIGHT, 1, 0, 0, 1, -3, 3 },
            { BOTTOMLEFT, 0, 1, 1, 0, 3, -3 }, { BOTTOMRIGHT, 1, 0, 1, 0, -3, -3 },
        }
        for _, p in ipairs(spots) do
            -- unter logo und knöpfen, über den panels
            local c = Tex(win, nil, 4)
            c:SetDimensions(cs, cs)
            c:SetAnchor(p[1], win, p[1], p[6], p[7])
            c:SetTextureCoords(p[2], p[3], p[4], p[5])
            SetCol(c, COL.accent, 0.5)
            Heavy(w, c, MEDIA .. T.corners)
        end
    end

    local pageIcon = Tex(content, nil, 5)
    pageIcon:SetDimensions(L.icon * 1.15, L.icon * 1.15)
    pageIcon:SetAnchor(TOPLEFT, content, TOPLEFT, 18, 16)
    SetCol(pageIcon, COL.accent)
    w.pageIcon = pageIcon
    local pageTitle = Lbl(content, L.fPage, COL.text, "")
    pageTitle:SetAnchor(LEFT, pageIcon, RIGHT, 12, -1)
    w.pageTitle = pageTitle
    local pageSub = Lbl(content, L.fSmall, COL.dim, "")
    pageSub:SetAnchor(TOPLEFT, pageIcon, BOTTOMLEFT, 0, 6)
    pageSub:SetDimensions(contentW - 40, zo_round(L.rowH * 0.5))
    pageSub:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    w.pageSub = pageSub
    if T.feather then
        local fe = Tex(content, MEDIA .. T.feather, 4)
        fe:SetDimensions(zo_round(200 * k), zo_round(25 * k))
        fe:SetAnchor(TOPRIGHT, content, TOPRIGHT, -18, 22)
        SetCol(fe, COL.accent, 0.45)
    end

    local hint = Lbl(win, L.fSmall, COL.dim, "")
    hint:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    hint:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    hint:SetMaxLineCount(2)
    hint:SetAnchor(TOPLEFT, nav, BOTTOMLEFT, 4, 4)
    hint:SetDimensions(L.w - 2 * L.pad - (mode == "keyboard" and 3 * 200 or 0), L.footer - 6)
    w.hint = hint

    if mode == "keyboard" then
        local bw, bh = 184, L.footer - 22
        local b3 = MakeButton(w, win, S(SI_AAB_RELOAD_UI), bw, bh, function() ReloadUI("ingame") end, COL.accent2)
        b3.ctrl:SetAnchor(TOPRIGHT, pvPanel, BOTTOMRIGHT, 0, 10)
        local confirmAll = false
        local b2
        b2 = MakeButton(w, win, S(SI_AAB_UI_RESET_ALL), bw, bh, function()
            if confirmAll then
                confirmAll = false
                b2.label:SetText(S(SI_AAB_UI_RESET_ALL))
                ResetAll(w)
            else
                confirmAll = true
                b2.label:SetText(S(SI_AAB_UI_CONFIRM))
                zo_callLater(function()
                    if confirmAll then confirmAll = false; b2.label:SetText(S(SI_AAB_UI_RESET_ALL)) end
                end, 3000)
            end
        end, COL.bad)
        b2.ctrl:SetAnchor(RIGHT, b3.ctrl, LEFT, -10, 0)
        local b1 = MakeButton(w, win, S(SI_AAB_UI_RESET_PAGE), bw, bh, function() ResetPage(w) end, COL.accent)
        b1.ctrl:SetAnchor(RIGHT, b2.ctrl, LEFT, -10, 0)
    end

    local foot = Lbl(nav, L.fSmall, COL.dim, "/aab  ·  haze068")
    foot:SetAnchor(BOTTOM, nav, BOTTOM, 0, -10)
    SetCol(foot, COL.dim, 0.7)

    BuildTabs(w)
    BuildPreview(w)

    w.Select = function(i, silent) SelectPage(w, i, silent) end

    -- werte kommen in OnShowing, fenster kann skaliert sein
    w.openTL = ANIMATION_MANAGER:CreateTimeline()
    local sc = w.openTL:InsertAnimation(ANIMATION_SCALE, win)
    sc:SetDuration(180)
    sc:SetEasingFunction(ZO_EaseOutQuadratic)

    PlaceWindow(w)
    UseTheme(prevT == THEMES.lace and "lace" or "nebula")
    return w
end

ResetPage = function(w)
    local page = w.pages[w.pageIndex]
    if not page then return end
    for _, row in ipairs(page.rows) do
        local def = row.def
        if def.key or def.reset then
            if def.reset then def.reset()
            elseif defaults[def.key] ~= nil then sv[def.key] = CopyValue(defaults[def.key]) end
            if def.apply then def.apply(GetVal(def)) end
        end
    end
    Sound(SOUNDS and SOUNDS.DEFAULT_CLICK)
    OnValueChanged({ type = "button" })
end

ResetAll = function(w)
    for k, v in pairs(defaults) do
        if k ~= "infoDialogShown" and k ~= "uiPosKeyboard" and k ~= "uiPosGamepad" and k ~= "uiLastPage" and k ~= "uiTheme" then
            sv[k] = CopyValue(v)
        end
    end
    api.InvalidateAnimTimelines()
    api.RestartActivePulses()
    api.RefreshUltDisplay()
    api.ApplyFrameAlpha()
    api.ApplyEdgeTexture()
    api.RefreshProcGlowSuppression()
    api.RefreshEffectRegistration()
    Sound(SOUNDS and SOUNDS.DEFAULT_CLICK)
    OnValueChanged({ type = "button" })
end

-- controller: keybinds statt DIRECTIONAL_INPUT, das ruft IsKeyDown (privat)
local REPEAT_UPDATE = "AABStudio_NavRepeat"
local REPEAT_DELAY_MS, REPEAT_RATE_MS = 380, 70

local function NavStep(w, dir)
    if dir == "up" then
        SetFocus(w, (w.focusIdx or 2) - 1); Sound(SOUNDS and SOUNDS.GAMEPAD_MENU_UP)
    elseif dir == "down" then
        SetFocus(w, (w.focusIdx or 0) + 1); Sound(SOUNDS and SOUNDS.GAMEPAD_MENU_DOWN)
    elseif w.focus and w.focus.Adjust then
        w.focus.Adjust(dir == "right" and 1 or -1)
    end
end

local function StopRepeat()
    EM:UnregisterForUpdate(REPEAT_UPDATE)
end

local function NavKey(w, dir, up)
    StopRepeat()
    if up then return end
    NavStep(w, dir)
    local t0 = GetFrameTimeMilliseconds()
    local last = t0
    EM:RegisterForUpdate(REPEAT_UPDATE, 16, function()
        local now = GetFrameTimeMilliseconds()
        if now - t0 < REPEAT_DELAY_MS or now - last < REPEAT_RATE_MS then return end
        last = now
        if active ~= w then StopRepeat(); return end
        NavStep(w, dir)
    end)
end

local function BuildKeybinds(w)
    local function Dir(key, dir)
        return {
            name = "AAB Studio " .. dir,
            ethereal = true,
            keybind = key,
            handlesKeyUp = true,
            callback = function(up) NavKey(w, dir, up) end,
        }
    end
    local kb = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        Dir("UI_SHORTCUT_INPUT_UP", "up"),
        Dir("UI_SHORTCUT_INPUT_DOWN", "down"),
        Dir("UI_SHORTCUT_INPUT_LEFT", "left"),
        Dir("UI_SHORTCUT_INPUT_RIGHT", "right"),
        {
            name = function() return S(SI_AAB_UI_KB_CHANGE) end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function() if w.focus then w.focus.Activate() end end,
            visible = function() return w.focus ~= nil end,
        },
        {
            name = function() return S(SI_AAB_UI_KB_PREVIEW) end,
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function()
                local kind = w.focus and w.focus.def.preview
                if not kind then
                    local demo = BuildPageDefs()[w.pageIndex].demo
                    kind = (demo == "bounce") and "press" or (demo == "ult" and "ultpress" or demo)
                end
                Preview(kind)
            end,
        },
        {
            name = function() return S(SI_AAB_UI_DEFAULT) end,
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = function() if w.focus and not w.focus.disabled then ResetDef(w.focus.def) end end,
            visible = function() return w.focus ~= nil and (w.focus.def.key ~= nil or w.focus.def.reset ~= nil) end,
        },
        {
            name = function() return S(SI_AAB_UI_KB_THEME) end,
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            callback = function() Studio.ShowTheme(w.theme == "nebula" and "lace" or "nebula") end,
        },
        {
            name = function() return S(SI_AAB_UI_KB_PREV_TAB) end,
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            callback = function() w.Select(w.pageIndex - 1) end,
        },
        {
            name = function() return S(SI_AAB_UI_KB_NEXT_TAB) end,
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            callback = function() w.Select(w.pageIndex + 1) end,
        },
    }
    if KEYBIND_STRIP and KEYBIND_STRIP.GenerateGamepadBackButtonDescriptor then
        kb[#kb + 1] = KEYBIND_STRIP:GenerateGamepadBackButtonDescriptor(function() Studio.Close() end)
    else
        kb[#kb + 1] = { name = function() return S(SI_AAB_UI_KB_CLOSE) end, keybind = "UI_SHORTCUT_NEGATIVE", callback = function() Studio.Close() end }
    end
    w.keybinds = kb
end

local scenes = {}

local function SceneName(mode, theme) return "AnimatedActionBarPlusStudio_" .. mode .. "_" .. theme end

local function OnShowing(w)
    UseTheme(w.theme)
    active = w
    LoadHeavy(w, true)
    PlaceWindow(w)
    for id, chip in pairs(w.themeChips) do chip.SetOn(id == w.theme) end
    local idx = PageIndex(sv.uiLastPage or "bounce")
    w.Select(idx, true)
    RestartPreview(w)
    StartMotion(w)
    if w.openTL then
        w.openTL:GetAnimation(1):SetScaleValues(0.97 * (w.scale or 1), w.scale or 1)
        w.openTL:PlayFromStart()
    end
    if w.mode == "gamepad" then
        if not w.keybinds then BuildKeybinds(w) end
        if KEYBIND_STRIP then KEYBIND_STRIP:AddKeybindButtonGroup(w.keybinds) end
        SetFocus(w, 1)
    end
end

local function OnHidden(w)
    -- beim designwechsel kann das neue fenster schon aktiv sein, dann
    -- dessen updates nicht abmelden
    local current = (active == nil or active == w)
    CloseDropdown(w)
    StopMotion(w, not current)
    if current then StopPreview(w) end
    if w.mode == "gamepad" then
        if current then StopRepeat() end
        if KEYBIND_STRIP and w.keybinds then KEYBIND_STRIP:RemoveKeybindButtonGroup(w.keybinds) end
    end
    LoadHeavy(w, false)
    if active == w then active = nil end
end

local function EnsureScene(mode, theme)
    local key = mode .. "_" .. theme
    if scenes[key] then return scenes[key] end
    local w = BuildWindow(mode, theme)
    wins[key] = w
    local scene = ZO_Scene:New(SceneName(mode, theme), SCENE_MANAGER)
    scene:AddFragment(ZO_FadeSceneFragment:New(w.win, nil, 150))
    if FRAGMENT_GROUP then
        local grp = (mode == "gamepad") and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW or FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW
        if grp then scene:AddFragmentGroup(grp) end
    end
    if UNIFORM_BLUR_FRAGMENT then scene:AddFragment(UNIFORM_BLUR_FRAGMENT) end
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            OnShowing(w)
        elseif newState == SCENE_HIDDEN then
            OnHidden(w)
        end
    end)
    scenes[key] = scene
    return scene
end

local function CurrentMode()
    return IsInGamepadPreferredMode() and "gamepad" or "keyboard"
end

local function IsShowing(mode, theme)
    return SCENE_MANAGER and SCENE_MANAGER:IsShowing(SceneName(mode, theme or ThemeId()))
end

function Studio.Open(pageId)
    if not Api() then return end
    BuildPageDefs()
    if pageId then sv.uiLastPage = pageId end
    local mode, theme = CurrentMode(), ThemeId()
    EnsureScene(mode, theme)
    if IsShowing(mode, theme) then
        wins[mode .. "_" .. theme].Select(PageIndex(sv.uiLastPage), true)
        return
    end
    SCENE_MANAGER:Show(SceneName(mode, theme))
end

function Studio.Close()
    for key in pairs(scenes) do
        local mode, theme = key:match("^(%a+)_(%a+)$")
        if IsShowing(mode, theme) then SCENE_MANAGER:Hide(SceneName(mode, theme)) end
    end
end

function Studio.Toggle(pageId)
    if active then Studio.Close() else Studio.Open(pageId) end
end

function Studio.IsOpen()
    return active ~= nil
end

-- design wechseln, offenes fenster wird direkt getauscht
function Studio.ShowTheme(id)
    if not Api() or not THEMES[id] then return end
    sv.uiTheme = id
    local w = active
    if not w or w.theme == id then return end
    Click()
    EnsureScene(w.mode, id)
    SCENE_MANAGER:Show(SceneName(w.mode, id))
end

function Studio.RefreshMotion()
    if active then StartMotion(active) end
end

-- /aab xyz
local function Msg(id)
    d("|ca970ff[AAB+]|r " .. S(id))
end

function Studio.ToggleForcedGamepad()
    if not Api() then return end
    local setting = GAMEPAD_SETTING_INPUT_PREFERRED_MODE
    if setting and INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD then
        if sv.xyzPrevMode ~= nil then
            SetSetting(SETTING_TYPE_GAMEPAD, setting, tostring(sv.xyzPrevMode))
            sv.xyzPrevMode = nil
            Msg(SI_AAB_UI_XYZ_RESTORE)
        else
            sv.xyzPrevMode = GetSetting(SETTING_TYPE_GAMEPAD, setting)
            local toGamepad = not IsInGamepadPreferredMode()
            local target = toGamepad and INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD or INPUT_PREFERRED_MODE_ALWAYS_KEYBOARD
            SetSetting(SETTING_TYPE_GAMEPAD, setting, tostring(target))
            Msg(toGamepad and SI_AAB_UI_XYZ_GP or SI_AAB_UI_XYZ_KB)
        end
    elseif GAMEPAD_SETTING_GAMEPAD_PREFERRED then
        -- alte clients
        if sv.xyzPrevMode ~= nil then
            SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_GAMEPAD_PREFERRED, tostring(sv.xyzPrevMode))
            sv.xyzPrevMode = nil
            Msg(SI_AAB_UI_XYZ_RESTORE)
        else
            sv.xyzPrevMode = GetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_GAMEPAD_PREFERRED)
            local toGamepad = not IsInGamepadPreferredMode()
            SetSetting(SETTING_TYPE_GAMEPAD, GAMEPAD_SETTING_GAMEPAD_PREFERRED, toGamepad and "true" or "false")
            Msg(toGamepad and SI_AAB_UI_XYZ_GP or SI_AAB_UI_XYZ_KB)
        end
    else
        return
    end
    Studio.pendingOpen = true
    zo_callLater(function()
        if Studio.pendingOpen then
            Studio.pendingOpen = false
            Studio.Open()
        end
    end, 400)
end

-- moduswechsel: studio im anderen layout neu öffnen
EM:RegisterForEvent("AnimatedActionBarPlusStudio", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
    if not Api() then return end
    local wasOpen = active ~= nil
    if wasOpen then Studio.Close() end
    if wasOpen or Studio.pendingOpen then
        Studio.pendingOpen = false
        zo_callLater(function() Studio.Open() end, 250)
    end
end)
