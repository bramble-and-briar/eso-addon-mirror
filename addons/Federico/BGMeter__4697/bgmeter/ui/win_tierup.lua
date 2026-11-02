BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local K = BGMeter.Constants
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local F = BGMeter.Format
local Prefs = BGMeter.Prefs

local T = {}

local NAME = "BGMeterTierUp"
local MS = 40
local IN_MS, HOLD_MS, OUT_MS = 350, 2600, 600
local STILL_MS = 3000
local BREATH_MS = 2600
local HUE_MS = 1200
local SHEEN_MS = 1600
local CUP = 96
local GLOW = 190
local TOP_Y = 150
local VERTS = { VERTEX_POINTS_TOPLEFT or 1, VERTEX_POINTS_TOPRIGHT or 2, VERTEX_POINTS_BOTTOMLEFT or 4, VERTEX_POINTS_BOTTOMRIGHT or 8 }
local VERT_HUE = { 0, 0.25, 0.75, 0.5 }

local ui = nil
local run = { on = false, still = false, t0 = 0, tier = nil, rank = 0 }

local function now()
    if GetGameTimeMilliseconds then return GetGameTimeMilliseconds() end
    return os.clock() * 1000
end

local function hue_rgb(h)
    local x = (h % 1) * 6
    local i = math.floor(x)
    local f = x - i
    if i == 0 then return 1, f, 0 end
    if i == 1 then return 1 - f, 1, 0 end
    if i == 2 then return 0, 1, f end
    if i == 3 then return 0, 1 - f, 1 end
    if i == 4 then return f, 0, 1 end
    return 1, 0, 1 - f
end

local function ease_out(t)
    t = 1 - t
    return 1 - t * t * t
end

local function build()
    if ui then return ui end
    local Z = BGMeter.zenimax.ui
    local Pn = BGMeter.UI.panel
    local root = Z.create_control(nil, GuiRoot, CT_TOPLEVELCONTROL or CT_CONTROL)
    root:SetDimensions(460, CUP + 80)
    root:SetAnchor(TOP, GuiRoot, TOP, 0, TOP_Y)
    root:SetDrawTier(DT_HIGH)
    if DL_OVERLAY and root.SetDrawLayer then root:SetDrawLayer(DL_OVERLAY) end
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    local glow = P.icon(root, "bgmeter/assets/glow.dds")
    glow:SetDimensions(GLOW, GLOW)
    glow:SetAnchor(CENTER, root, TOP, 0, CUP / 2 + 6)
    if glow.SetBlendMode then glow:SetBlendMode(TEX_BLEND_MODE_ADD) end
    if glow.SetDrawLevel then glow:SetDrawLevel(1) end
    local glass = P.icon(root, Pn.TROPHY_GLASS)
    glass:SetDimensions(CUP, CUP)
    glass:SetAnchor(CENTER, root, TOP, 0, CUP / 2 + 6)
    if glass.SetDrawLevel then glass:SetDrawLevel(2) end
    local metal = P.icon(root, Pn.TROPHY_METAL)
    metal:SetDimensions(CUP, CUP)
    metal:SetAnchor(CENTER, root, TOP, 0, CUP / 2 + 6)
    if metal.SetDrawLevel then metal:SetDrawLevel(3) end
    local sheen = BGMeter.UI.cupfx.sheen(root, metal, Pn.TROPHY_METAL, 4)
    local title = P.label(root, S.FONT.banner, K.COLOR.gold)
    title:SetAnchor(TOP, root, TOP, 0, CUP + 14)
    title:SetDimensions(460, 38)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local sub = P.label(root, S.FONT.row, K.COLOR.text_dim)
    sub:SetAnchor(TOP, title, BOTTOM, 0, 2)
    sub:SetDimensions(460, 20)
    sub:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    ui = { root = root, glow = glow, glass = glass, metal = metal, sheen = sheen, title = title, sub = sub }
    return ui
end

local function stop()
    if not run.on then return end
    run.on = false
    run.tier = nil
    BGMeter.zenimax.events.unregister_update(NAME)
    if ui then
        ui.root:SetHidden(true)
        BGMeter.UI.cupfx.sheen_tick(ui.sheen, nil)
        ui.ps = BGMeter.UI.cupfx.stop(ui.ps)
    end
end

local function tick()
    if not (run.on and ui and run.tier) then return end
    local t = now() - run.t0
    local tier = run.tier
    local a, s = 1, 1
    if run.still then
        if t >= STILL_MS then stop() return end
    elseif t < IN_MS then
        local k = ease_out(t / IN_MS)
        a, s = k, 0.6 + 0.4 * k
    elseif t < IN_MS + HOLD_MS then
        a, s = 1, 1
    elseif t < IN_MS + HOLD_MS + OUT_MS then
        a = 1 - (t - IN_MS - HOLD_MS) / OUT_MS
    else
        stop()
        return
    end
    ui.root:SetAlpha(a)
    ui.metal:SetScale(s)
    ui.glass:SetScale(s)
    if tier.sheen then
        local gs = (t % SHEEN_MS) / SHEEN_MS
        BGMeter.UI.cupfx.sheen_tick(ui.sheen, (gs < 0.5) and (gs / 0.5) or nil)
    end
    local breath = 0.80 + 0.20 * math.sin(2 * math.pi * t / BREATH_MS)
    if tier.hue then
        local u = (t % HUE_MS) / HUE_MS
        local r, g, b = hue_rgb(u)
        ui.glow:SetColor(0.45 + 0.55 * r, 0.45 + 0.55 * g, 0.45 + 0.55 * b, tier.glow * breath)
        if ui.glass.SetVertexColors then
            for i = 1, 4 do
                local r2, g2, b2 = hue_rgb(u + VERT_HUE[i])
                ui.glass:SetVertexColors(VERTS[i], 0.45 + 0.55 * r2, 0.45 + 0.55 * g2, 0.45 + 0.55 * b2, 1)
            end
        end
    else
        local c = tier.col
        ui.glow:SetColor(c[1], c[2], c[3], tier.glow * breath)
    end
end

function T.show(tier, rank)
    if not tier then return end
    local u = build()
    BGMeter.UI.panel.trophy_paint(u.metal, u.glass, tier)
    u.sheen:SetTexture((BGMeter.UI.panel.trophy_textures(tier)))
    local word = tier.word:gsub("!", "")
    u.title:SetText(word:upper())
    S.color(u.title, tier.col)
    u.sub:SetText(string.format("competitive standing  ·  rank #%s", F.commas(rank or 0)))
    run.tier, run.rank, run.t0 = tier, rank or 0, now()
    run.still = not Prefs.get("animate")
    u.root:SetAlpha(run.still and 1 or 0)
    u.metal:SetScale(1)
    u.glass:SetScale(1)
    u.root:SetHidden(false)
    u.ps = BGMeter.UI.cupfx.stop(u.ps)
    if tier.fx and not run.still then
        local c = tier.fxcol or tier.col
        u.ps = BGMeter.UI.cupfx.particles(u.metal, tier.fx, c[1], c[2], c[3], 6)
        if u.ps then u.ps:Start() end
    end
    BGMeter.Sound.play("rankup")
    if not run.on then
        run.on = true
        BGMeter.zenimax.events.register_update(NAME, MS, tick)
    end
    tick()
end

function T.hide() stop() end
function T.active() return run.on end
function T.word() return run.tier and run.tier.word or nil end

local demo_i = 0
function T.demo()
    local tiers = BGMeter.Standing.TIERS
    demo_i = demo_i % #tiers + 1
    local tier = tiers[#tiers + 1 - demo_i]
    T.show(tier, tier.max)
    BGMeter.Log.say("tier-up demo: %s", tier.word)
end

BGMeter.UI.tierup = T
