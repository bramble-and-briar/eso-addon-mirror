BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local P = BGMeter.Plot.primitives

local CupFx = {}

local GLINT = "EsoUI/Art/HUD/starburst.dds"
local DOT = "bgmeter/assets/dot.dds"
local PI = math.pi
local VERTS = { VERTEX_POINTS_TOPLEFT or 1, VERTEX_POINTS_TOPRIGHT or 2, VERTEX_POINTS_BOTTOMLEFT or 4, VERTEX_POINTS_BOTTOMRIGHT or 8 }

local KIND = {
    glitter = { tex = GLINT, size = 7, pps = 4, dur0 = 0.9, dur1 = 1.5, vel0 = 18, vel1 = 40, elev0 = -2.4, elev1 = -0.7, grav = 70, scale0 = 0.9, scale1 = 0.25, drag = 0.4 },
    embers  = { tex = DOT, size = 5, pps = 5, dur0 = 0.8, dur1 = 1.4, vel0 = 10, vel1 = 26, elev0 = -1.9, elev1 = -1.25, grav = -22, scale0 = 1.0, scale1 = 0.2, drag = 1.2 },
}

function CupFx.available()
    return ZO_ControlParticleSystem ~= nil and ZO_NumericalPhysicsParticle_Control ~= nil and ZO_UniformRangeGenerator ~= nil
end

function CupFx.sheen(parent, icon, tex, level)
    local s = P.icon(parent, tex)
    s:SetAnchorFill(icon)
    if s.SetBlendMode then s:SetBlendMode(TEX_BLEND_MODE_ADD) end
    if s.SetDrawLevel then s:SetDrawLevel(level or 3) end
    s:SetHidden(true)
    return s
end

function CupFx.sheen_tick(s, g)
    if not s then return end
    if g == nil then
        if not s:IsHidden() then s:SetHidden(true) end
        return
    end
    local k = math.sin(PI * g) * 0.55
    local aL, aR = k * (1 - g), k * g
    if s.SetVertexColors then
        s:SetVertexColors(VERTS[1], 1, 1, 1, aL)
        s:SetVertexColors(VERTS[3], 1, 1, 1, aL)
        s:SetVertexColors(VERTS[2], 1, 1, 1, aR)
        s:SetVertexColors(VERTS[4], 1, 1, 1, aR)
    else
        s:SetColor(1, 1, 1, k * 0.5)
    end
    s:SetHidden(false)
end

function CupFx.particles(anchor, kind, r, g, b, level)
    if not CupFx.available() then return nil end
    local k = KIND[kind]
    if not k then return nil end
    local ps = ZO_ControlParticleSystem:New(ZO_NumericalPhysicsParticle_Control)
    ps:SetParentControl(anchor)
    ps:SetParticlesPerSecond(k.pps)
    ps:SetParticleParameter("Texture", k.tex)
    ps:SetParticleParameter("BlendMode", TEX_BLEND_MODE_ADD or 1)
    ps:SetParticleParameter("DrawLevel", level or 5)
    ps:SetParticleParameter("DrawLayer", DL_CONTROLS or 1)
    ps:SetParticleParameter("AnchorPoint", CENTER)
    ps:SetParticleParameter("AnchorRelativePoint", TOP)
    ps:SetParticleParameter("Size", k.size)
    ps:SetParticleParameter("DurationS", ZO_UniformRangeGenerator:New(k.dur0, k.dur1))
    ps:SetParticleParameter("StartAlpha", 1)
    ps:SetParticleParameter("EndAlpha", 0)
    ps:SetParticleParameter("StartScale", k.scale0)
    ps:SetParticleParameter("EndScale", k.scale1)
    ps:SetParticleParameter("StartColorR", r)
    ps:SetParticleParameter("StartColorG", g)
    ps:SetParticleParameter("StartColorB", b)
    ps:SetParticleParameter("PhysicsInitialVelocityElevationRadians", ZO_UniformRangeGenerator:New(k.elev0, k.elev1))
    ps:SetParticleParameter("PhysicsInitialVelocityMagnitude", ZO_UniformRangeGenerator:New(k.vel0, k.vel1))
    ps:SetParticleParameter("PhysicsAccelerationElevationRadians1", PI / 2)
    ps:SetParticleParameter("PhysicsAccelerationMagnitude1", k.grav)
    ps:SetParticleParameter("PhysicsDragMultiplier", k.drag)
    return ps
end

function CupFx.stop(ps)
    if ps then ps:Stop() end
    return nil
end

BGMeter.UI.cupfx = CupFx
