-- pabloco's reticles: definitions. Designs live in the Figma board "pabloco's reticles":
-- https://www.figma.com/design/AiLjGJ3BgutfnEPz18VZcG
--
-- A reticle is a list of PARTS drawn bottom to top about the screen centre. Each part is one texture whose
-- properties are numbers, or functions of the animation state:
--     x, y      offset in px from the centre              rot    degrees clockwise (see "Flip rotation" setting)
--     scale     uniform, multiplies w and h               alpha  0..1, parts at 0 are hidden
--     w, h      px (default: the texture's own size)      color  "rrggbb", or a function returning r, g, b
--     size      shortcut for w = h                        frame  atlas parts only: 0-based frame index
-- Orbiting a piece is a rotation, growing its radius is a scale, sliding is x / y.
--
-- The state `s` handed to a function has s.l (left click 0..1, eased), s.r (right click / block 0..1, eased)
-- and s.t (seconds, for things that keep moving). K and CK build the common case:
--     K(rest, left, right [, opts])   linear mix of three numbers.  opts.l / opts.r = {a, b} restricts that
--                                     state's motion to the a..b part of its run, for staggering.
--     CK(rest, left, right)           the same for "rrggbb" colours.
-- left / right = { dur = seconds to reach the state, ease = linear | in | out | inout | sinein }. The engine
-- eases back to rest over the same time on release.
-- Textures: tools/build-parts.py (parts) and tools/build-textures.py (the original Dragon Knight atlases).
PablocosReticles = PablocosReticles or {}
PablocosReticles.reticles, PablocosReticles.reticleOrder = PablocosReticles.reticles or {}, PablocosReticles.reticleOrder or {}

function PablocosReticles.RegisterReticle(def)
    PablocosReticles.reticles[def.id] = def
    table.insert(PablocosReticles.reticleOrder, def.id)
end

local function Seg(e, a, b)
    if e <= a then return 0 elseif e >= b then return 1 end
    return (e - a) / (b - a)
end

local function Mix(n, l, r, s, o)
    local el = (o and o.l) and Seg(s.l, o.l[1], o.l[2]) or s.l
    local er = (o and o.r) and Seg(s.r, o.r[1], o.r[2]) or s.r
    local v = n + ((l or n) - n) * el
    return v + ((r or n) - v) * er
end

local function K(n, l, r, o) return function(s) return Mix(n, l, r, s, o) end end

local function Hex(h)
    return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end

local function CK(n, l, r, o)
    local cn, cl, cr = { Hex(n) }, { Hex(l or n) }, { Hex(r or n) }
    return function(s)
        local el = (o and o.l) and Seg(s.l, o.l[1], o.l[2]) or s.l
        local er = (o and o.r) and Seg(s.r, o.r[1], o.r[2]) or s.r
        local out = {}
        for i = 1, 3 do
            local v = cn[i] + (cl[i] - cn[i]) * el
            out[i] = v + (cr[i] - v) * er
        end
        return out[1], out[2], out[3]
    end
end

local function Both(fa, fb) return function(s) return fa(s) * fb(s) end end   -- multiply two functions
local function Flick(hz, phase) return function(s) return (math.floor(s.t * hz) % 2 == phase) and 1 or 0 end end
local function Rad(d) return d * math.pi / 180 end
local function Polar(r, a)  -- r may be a function; returns x and y functions for a fixed angle a (degrees clockwise from +x)
    local rf = type(r) == "function" and r or function() return r end
    return function(s) return rf(s) * math.cos(Rad(a)) end, function(s) return rf(s) * math.sin(Rad(a)) end
end

-- =========================================================================================================
-- Dragon Knight, Embers: the original. Left click is the 16-frame bloom flipbook (atlas parts); block lets the
-- arcs ease to r17, four extension pieces slide out from under their ends, and a gold ring takes over.
-- =========================================================================================================
do
    local ATLAS = { cols = 4, frames = 16 }
    local frame = K(0, 15, 15)         -- frame 15 = bloomed (r23): block grows to the same radius as the left click
    local ext = {
        { key = "ur", start = 40.6 }, { key = "lr", start = -40.6 },
        { key = "ul", start = -40.6 }, { key = "ll", start = 40.6 },
    }
    -- The flipbook arcs run r15 (frame 0) to r23 (frame 15); frame 15 = r23 for both left click and block. Each extension piece is baked at
    -- r17.13, so scaling it by r / 17.13 keeps it on the arc's radius the whole time, and starting it rotated back under
    -- the arc end means it is never faded in: it just slides out from underneath.
    local function onArc(s) return (15 + 8 * frame(s) / 15) / 17.13 end
    local slide = function(e) return function(s) return e.start * (1 - s.r) end end
    local arcColor = CK("f46e35", "f46e35", "ffc24a", { r = { 0.2, 1 } })
    local parts = {
        { tex = "glow", w = 24, h = 24, color = "c81e1e", alpha = K(0.35, 0.35, 0.5), size = K(24, 24, 34) },
        { tex = "arc_halo", atlas = ATLAS, w = 64, h = 64, frame = frame, color = "c81e1e", alpha = 0.28 },
        { tex = "arc_halo", atlas = ATLAS, w = 64, h = 64, frame = frame, color = "1c0505", alpha = 0.56 },
    }
    for _, e in ipairs(ext) do
        table.insert(parts, { tex = "dke_ext_" .. e.key .. "_o", color = "1c0505", alpha = 0.56, scale = onArc, rot = slide(e) })
    end
    table.insert(parts, { tex = "arc_core", atlas = ATLAS, w = 64, h = 64, frame = frame, color = arcColor, alpha = 1 })
    for _, e in ipairs(ext) do
        table.insert(parts, { tex = "dke_ext_" .. e.key, color = arcColor, alpha = 1, scale = onArc, rot = slide(e) })
    end
    -- the block ring is thicker than the flipbook line; this only thickens it over the last stretch of the motion
    local thick = K(0, 0, 1, { r = { 0.65, 1 } })
    table.insert(parts, { tex = "dke_gold_o", color = "1c0505", scale = onArc, alpha = Both(thick, function() return 0.56 end) })
    table.insert(parts, { tex = "dke_gold", color = "ffc24a", scale = onArc, alpha = thick })
    table.insert(parts, { tex = "dot_a", w = 16, h = 16, color = CK("ff9736", "ff9736", "ffe08a"), alpha = 1 })
    table.insert(parts, { tex = "dot_b", size = K(10, 20, 10), color = CK("ffffff", "ff0000", "ffffff"), alpha = K(0.48, 0.19, 0.48) })
    PablocosReticles.RegisterReticle({
        id = "dragonknight", name = "Dragon Knight (Embers)", scale = 1.25,
        left = { dur = 0.2, ease = "sinein" }, right = { dur = 0.14, ease = "out" },
        parts = parts,
    })
end

-- =========================================================================================================
-- Dragon Knight, Talons: four talons clamp in on left click; on block they sweep out to the diagonals while the
-- wing arches swing in from the sides.
-- =========================================================================================================
do
    local quads = {
        { key = "ur", a = -45, wing = 40 }, { key = "ul", a = -135, wing = -40 },
        { key = "lr", a = 45, wing = -40 }, { key = "ll", a = 135, wing = 40 },
    }
    local parts = {
        { tex = "disc_soft", size = K(10, 16, 14), color = CK("c81e1e", "ff5a1f", "c81e1e"), alpha = K(0.4, 0.45, 0.45) },
    }
    for _, q in ipairs(quads) do
        local rt = K(13, 7, 22, { r = { 0, 0.8 } })
        local x, y = Polar(rt, q.a)
        table.insert(parts, { tex = "talon", x = x, y = y, rot = q.a, size = nil,
            scale = K(1, 1.1, 1.2), color = CK("f46e35", "ffc24a", "ffc24a"),
            alpha = K(1, 1, 0, { r = { 0.2, 0.75 } }) })
    end
    for _, q in ipairs(quads) do
        local sweep = function(s) return q.wing * (1 - s.r) end
        table.insert(parts, { tex = "wing_o_" .. q.key .. "_o", color = "1c0505", rot = sweep, scale = K(0.8, 0.8, 1),
            alpha = function(s) return 0.55 * Seg(s.r, 0.1, 0.7) end })
        table.insert(parts, { tex = "wing_o_" .. q.key, color = "ffc24a", rot = sweep, scale = K(0.8, 0.8, 1),
            alpha = function(s) return Seg(s.r, 0.1, 0.7) end })
        table.insert(parts, { tex = "wing_i_" .. q.key, color = "f46e35", rot = function(s) return -q.wing * (1 - s.r) end,
            scale = K(1.2, 1.2, 1), alpha = function(s) return 0.8 * Seg(s.r, 0.3, 0.9) end })
    end
    -- sparks fly out along the axes on left click and burn out
    for _, a in ipairs({ 0, 90, 180, 270 }) do
        local x, y = Polar(K(14, 27, 14, { l = { 0, 1 } }), a)
        table.insert(parts, { tex = "disc_hard", x = x, y = y, size = 3, color = "ffe08a",
            alpha = function(s) return math.sin(math.min(1, s.l) * math.pi) * (1 - s.r) end })
    end
    table.insert(parts, { tex = "disc_hard", size = K(4, 5.2, 4), color = CK("ff9736", "ffe9b0", "ffe08a"), alpha = 1 })
    PablocosReticles.RegisterReticle({
        id = "dktalons", name = "Dragon Knight (Talons)",
        left = { dur = 0.09, ease = "in" }, right = { dur = 0.16, ease = "out" },
        parts = parts,
    })
end

-- =========================================================================================================
-- Sorcerer: brackets twist and swell on left click while lightning forks out and re-rolls; block crossfades
-- (spinning in) to the double ring, which you liked as a fade.
-- =========================================================================================================
do
    local twist = function(s) return 28 * math.sin(math.min(1, s.l) * math.pi) end
    local grow = K(1, 1.56, 1.25)
    local noBlock = function(s) return 1 - Seg(s.r, 0, 0.6) end
    local bolt = K(0.25, 1, 0.25, { l = { 0, 1 } })
    PablocosReticles.RegisterReticle({
        id = "sorcerer", name = "Sorcerer (Storm)",
        left = { dur = 0.12, ease = "out" }, right = { dur = 0.16, ease = "out" },
        parts = {
            { tex = "disc_soft", size = K(22, 30, 22), color = "5fd7ff", alpha = Both(K(0.35, 0.5, 0.35), noBlock) },
            { tex = "sorc_brackets", rot = twist, scale = grow, color = CK("8f7bff", "e0daff", "8f7bff"), alpha = noBlock },
            { tex = "sorc_sparks", rot = twist, scale = grow, color = "5fd7ff", alpha = Both(K(1, 0, 0), noBlock) },
            { tex = "sorc_bolts_a", scale = bolt, color = "5fd7ff", alpha = function(s) return Seg(s.l, 0, 0.3) * (1 - s.r) * Flick(18, 0)(s) end },
            { tex = "sorc_bolts_b", scale = bolt, color = "5fd7ff", alpha = function(s) return Seg(s.l, 0, 0.3) * (1 - s.r) * Flick(18, 1)(s) end },
            { tex = "disc_hard", size = 34, color = "8f7bff", alpha = K(0, 0, 0.13, { r = { 0.1, 1 } }) },
            { tex = "sorc_ring_o", color = "8f7bff", rot = K(-60, -60, 0), scale = K(0.8, 0.8, 1), alpha = K(0, 0, 1, { r = { 0.1, 1 } }) },
            { tex = "sorc_ring_i", color = "5fd7ff", rot = K(-60, -60, 0), scale = K(0.8, 0.8, 1), alpha = K(0, 0, 1, { r = { 0.1, 1 } }) },
            { tex = "sorc_nodes", color = "5fd7ff", rot = K(-60, -60, 0), scale = K(0.8, 0.8, 1), alpha = K(0, 0, 1, { r = { 0.1, 1 } }) },
            { tex = "disc_hard", size = K(4, 6.5, 4), color = CK("5fd7ff", "ffffff", "5fd7ff"), alpha = Both(K(1, 1, 1), noBlock) },
        },
    })
end

-- =========================================================================================================
-- Templar: ticks stretch into rays on left click; on block the ticks fold into the centre as the sun halo
-- spins in and the diamond turns into the cross.
-- =========================================================================================================
do
    local tickAlpha = K(1, 1, 0, { r = { 0, 0.7 } })
    local len = K(8, 22, 2)
    local mid = K(18, 25, 4)
    local parts = {
        { tex = "disc_soft", size = K(10, 34, 28), color = "ffd25e", alpha = K(0, 0.3, 0.3) },
        { tex = "tpl_dots", alpha = K(1, 0, 0, { l = { 0, 0.5 } }), color = "ffd25e" },
        { tex = "tpl_halo", color = "ffd25e", scale = K(0.5, 0.5, 1), rot = K(-45, -45, 0), alpha = K(0, 0, 1, { r = { 0.1, 0.9 } }) },
        { tex = "disc_hard", size = 40, color = "ffd25e", alpha = K(0, 0, 0.1, { r = { 0.4, 1 } }) },
        { tex = "tpl_rays", color = "fff4c9", scale = K(0.55, 1, 0.55), rot = K(-20, 0, 0), alpha = K(0, 0.85, 0, { l = { 0, 0.7 } }) },
        { tex = "tpl_diamond", color = CK("ffd25e", "fff4c9", "ffd25e"), scale = K(1, 1.15, 0.4), rot = K(0, 0, 45), alpha = K(1, 1, 0, { r = { 0.2, 0.8 } }) },
        { tex = "tpl_diamond_fill", color = "ffffff", scale = K(1, 1.15, 0.4), alpha = K(0, 0.9, 0) },
        { tex = "tpl_cross", color = "fff4c9", scale = K(0.4, 0.4, 1), rot = K(-90, -90, 0), alpha = K(0, 0, 1, { r = { 0.3, 1 } }) },
    }
    for _, a in ipairs({ 0, 90, 180, 270 }) do
        local dx, dy = math.cos(Rad(a)), math.sin(Rad(a))
        local horiz = (a == 0 or a == 180)
        local pos = function(s) return mid(s) end
        table.insert(parts, {
            tex = horiz and "tick_h" or "tick_v", color = "ffd25e", alpha = tickAlpha,
            x = function(s) return dx * pos(s) end, y = function(s) return dy * pos(s) end,
            w = horiz and function(s) return len(s) + 6 end or 12, h = horiz and 12 or function(s) return len(s) + 6 end,
        })
    end
    PablocosReticles.RegisterReticle({
        id = "templar", name = "Templar",
        left = { dur = 0.12, ease = "out" }, right = { dur = 0.18, ease = "out" },
        parts = parts,
    })
end

-- =========================================================================================================
-- Warden: leaves unfurl and turn on left click while seeds fly out; block spins the leaves into the frost ring.
-- =========================================================================================================
do
    local parts = {
        { tex = "disc_soft", size = K(8, 10, 12), color = "aef0ff", alpha = K(0.5, 0.5, 0.7) },
        { tex = "ward_leaves", color = CK("54d68a", "54d68a", "aef0ff"), scale = K(1, 1.5, 1.15),
          rot = K(0, 20, 40), alpha = K(1, 1, 0, { r = { 0.2, 0.8 } }) },
        { tex = "ward_ring", color = "aef0ff", scale = K(0.85, 0.85, 1), rot = K(-40, -40, 0), alpha = K(0, 0, 1, { r = { 0.2, 1 } }) },
        { tex = "ward_hex", color = "aef0ff", scale = K(0.85, 0.85, 1), rot = K(-40, -40, 0), alpha = K(0, 0, 1, { r = { 0.2, 1 } }) },
    }
    for _, c in ipairs({ -90, 30, 150 }) do
        local x, y = Polar(K(6, 36, 6, { l = { 0, 1 } }), c + 20)
        table.insert(parts, { tex = "disc_hard", x = x, y = y, size = 4.4, color = "aef0ff",
            alpha = function(s) return Seg(s.l, 0.05, 0.5) * (1 - Seg(s.l, 0.9, 1)) * (1 - s.r) end })
    end
    table.insert(parts, { tex = "disc_hard", size = K(4, 4, 4.8), color = CK("aef0ff", "aef0ff", "ffffff"), alpha = 1 })
    PablocosReticles.RegisterReticle({
        id = "warden", name = "Warden",
        left = { dur = 0.2, ease = "out" }, right = { dur = 0.2, ease = "inout" },
        parts = parts,
    })
end

-- =========================================================================================================
-- Arcanist: the triangle turns 60 degrees and swells with beams out to the orbs; on block it shrinks into the
-- inner triangle while turning, the orbs slide out into the gaps of the shell that sweeps in around it.
-- =========================================================================================================
do
    local triScale = K(1, 1.64, 0.71)
    local triRot = K(0, 60, 120)
    local orbR = K(14, 23, 21)
    local parts = {
        { tex = "arc_shell", color = "43e07a", scale = K(0.6, 0.6, 1), rot = K(60, 60, 0), alpha = K(0, 0, 1, { r = { 0.1, 0.8 } }) },
        { tex = "arc_trifill", color = "43e07a", scale = triScale, rot = triRot, alpha = K(0, 0, 0.14, { r = { 0.5, 1 } }) },
        { tex = "arc_tri", color = CK("43e07a", "43e07a", "c6f24a"), scale = triScale, rot = triRot, alpha = 1 },
    }
    for i = 0, 2 do
        local a0 = -90 + i * 120
        local function pos(s) local a = Rad(a0 + triRot(s)); local r = orbR(s); return r * math.cos(a), r * math.sin(a) end
        table.insert(parts, { tex = "disc_soft", size = K(10, 13, 11), color = "c6f24a", alpha = 0.5,
            x = function(s) return (pos(s)) end, y = function(s) local _, y = pos(s); return y end })
        table.insert(parts, { tex = "disc_hard", size = K(4.4, 6, 4.8), color = "c6f24a", alpha = 1,
            x = function(s) return (pos(s)) end, y = function(s) local _, y = pos(s); return y end })
    end
    table.insert(parts, { tex = "disc_hard", size = 3, color = "f4ffd0", alpha = 1 })
    PablocosReticles.RegisterReticle({
        id = "arcanist", name = "Arcanist",
        left = { dur = 0.16, ease = "inout" }, right = { dur = 0.2, ease = "out" },
        parts = parts,
    })
end

-- =========================================================================================================
-- Nightblade: two purple crescents facing a crimson point. Left click turns them red and widens them outward;
-- block rotates them 90 degrees so they close over and under the core.
-- =========================================================================================================
do
    local fire = K(0, 1, 0)                                   -- 1 only while left is held and block is not
    local blades = function(side)
        return {
            tex = side < 0 and "nb_blade_l" or "nb_blade_r",
            x = K(0, side * 9, 0, { l = { 0, 1 } }), scale = K(1, 1.08, 0.95),
            rot = K(0, 0, 90),
            color = CK("a64dff", "ff3b6b", "b46bff"), alpha = 1,
        }
    end
    PablocosReticles.RegisterReticle({
        id = "nightblade", name = "Nightblade",
        left = { dur = 0.07, ease = "out" }, right = { dur = 0.15, ease = "out" },
        parts = {
            { tex = "disc_soft", size = 30, color = "a64dff", alpha = K(0, 0, 0.2) },
            { tex = "disc_soft", size = K(10, 16, 10), color = "ff3b6b", alpha = K(0.45, 0.6, 0) },
            blades(-1), blades(1),
            { tex = "ring_small", w = 16, h = 16, color = "ff3b6b", alpha = K(0, 0, 1, { r = { 0.3, 1 } }) },
            { tex = "disc_hard", size = K(3.6, 4, 3.6), color = CK("ff3b6b", "ff6a8a", "ff3b6b"), alpha = K(1, 1, 0, { r = { 0, 0.5 } }) },
        },
    })
end

-- =========================================================================================================
-- Necromancer: two thin pale scythes bowing around the core with plenty of room. Left click works like the
-- Nightblade's: same pose, brighter colour, blades widen outward. Block: the blades grow taller and a guard ring
-- rings the core.
-- =========================================================================================================
do
    local function blade(side)
        return {
            tex = side < 0 and "nec_blade_l" or "nec_blade_r",
            x = K(side * 2, side * 10, 0), scale = K(1, 1, 1.5),
            color = CK("9fdcff", "c6ebff", "bfe6ff"), alpha = 1,
        }
    end
    PablocosReticles.RegisterReticle({
        id = "necromancer", name = "Necromancer",
        left = { dur = 0.08, ease = "out" }, right = { dur = 0.15, ease = "out" },
        parts = {
            { tex = "disc_soft", size = K(8, 16, 8), color = "9fdcff", alpha = K(0, 0.45, 0) },
            blade(-1), blade(1),
            { tex = "ring_small", w = 16, h = 16, scale = 2, color = "eaf6ff", alpha = K(0, 0, 1, { r = { 0.3, 1 } }) },
            { tex = "disc_hard", size = K(3.6, 4.8, 3.6), color = CK("eaf6ff", "ffffff", "eaf6ff"), alpha = 1 },
        },
    })
end

-- =========================================================================================================
-- Sorcerer, Calm: the same brackets and double-ring block as the Storm one, without the lightning. Left click is
-- a clean swell and twist with one thin pulse ring and a core flare. Nothing flickers.
-- =========================================================================================================
do
    local noBlock = function(s) return 1 - Seg(s.r, 0, 0.6) end
    PablocosReticles.RegisterReticle({
        id = "sorcerer_calm", name = "Sorcerer (Calm)",
        left = { dur = 0.14, ease = "out" }, right = { dur = 0.16, ease = "out" },
        parts = {
            { tex = "disc_soft", size = K(20, 30, 20), color = "5fd7ff", alpha = Both(K(0.35, 0.55, 0.35), noBlock) },
            { tex = "ring_thin", scale = K(0.55, 1.45, 0.55), color = "5fd7ff",
              alpha = function(s) return 0.7 * math.sin(math.min(1, s.l) * math.pi) * (1 - s.r) end },
            { tex = "sorc_brackets", rot = K(0, 22, 0), scale = K(1, 1.4, 1.25), color = CK("8f7bff", "e0daff", "8f7bff"), alpha = noBlock },
            { tex = "sorc_sparks", rot = K(0, 22, 0), scale = K(1, 1.4, 1.25), color = "5fd7ff", alpha = Both(K(1, 0.4, 0), noBlock) },
            { tex = "disc_hard", size = 34, color = "8f7bff", alpha = K(0, 0, 0.13, { r = { 0.1, 1 } }) },
            { tex = "sorc_ring_o", color = "8f7bff", rot = K(-60, -60, 0), scale = K(0.8, 0.8, 1), alpha = K(0, 0, 1, { r = { 0.1, 1 } }) },
            { tex = "sorc_ring_i", color = "5fd7ff", rot = K(-60, -60, 0), scale = K(0.8, 0.8, 1), alpha = K(0, 0, 1, { r = { 0.1, 1 } }) },
            { tex = "sorc_nodes", color = "5fd7ff", rot = K(-60, -60, 0), scale = K(0.8, 0.8, 1), alpha = K(0, 0, 1, { r = { 0.1, 1 } }) },
            { tex = "disc_hard", size = K(4, 6, 4), color = CK("5fd7ff", "ffffff", "5fd7ff"), alpha = noBlock },
        },
    })
end

-- =========================================================================================================
-- Fire and Ice: fire is the offence, ice the defence. Four short arcs around one small central dot: fire left and
-- right, ice top and bottom. Left click is fire: the two fire arcs scale up and rotate one way while the ice arcs
-- turn a little the other way, and the dot (same small size) turns orange. Right click is ice: every arc lengthens into its quarter of the outer ring (each
-- short arc is two half arcs that slide apart) and the Warden's crystal turns in at the middle.
-- Colourways: the fire arcs take the colourway's hue and the ice arcs sit about 25 degrees away from it (hueSpread
-- 0.15 instead of the usual 0.4), so it stays two-toned in every colourway.
-- =========================================================================================================
do
    local FIRE, ICE = "ff7a2d", "aef0ff"
    local SHORT = 18                                      -- degrees each half arc is slid inward at rest (arc = +-18)
    local fireScale = K(1, 1.53, 1.27)
    local iceScale = K(1, 1, 1.27)
    -- The fire and ice arcs start 90 degrees apart, so counter-rotating them by 45 degrees each would put them in the
    -- same spot. 25 degrees each way keeps them clearly apart while they visibly turn opposite ways.
    local twist = function(s) return 25 * s.l * (1 - s.r) end           -- fire arcs turn one way on left click
    local counter = function(s) return -25 * s.l * (1 - s.r) end        -- ice arcs turn the other way
    local parts = {
        { tex = "disc_soft", size = 16, color = FIRE, alpha = K(0.25, 0.4, 0.1) },
        { tex = "disc_soft", size = 26, color = ICE, alpha = K(0.18, 0.18, 0.3) },
    }
    for _, seg in ipairs({ { "t", true }, { "b", true }, { "l", false }, { "r", false } }) do
        local name, isIce = seg[1], seg[2]
        local scale = isIce and iceScale or fireScale
        local color = isIce and ICE or FIRE
        local turn = isIce and counter or twist
        table.insert(parts, { tex = "fi_h_" .. name .. "_p", scale = scale, color = color, alpha = 1,
            rot = function(s) return turn(s) - SHORT * (1 - s.r) end })
        table.insert(parts, { tex = "fi_h_" .. name .. "_m", scale = scale, color = color,
            alpha = K(0, 0, 1, { r = { 0, 0.4 } }),
            rot = function(s) return turn(s) + SHORT * (1 - s.r) end })
    end
    table.insert(parts, { tex = "ward_hex", color = ICE, scale = K(0.67, 0.67, 1), rot = K(0, 0, 60), alpha = K(0, 0, 1, { r = { 0.2, 1 } }) })
    table.insert(parts, { tex = "disc_hard", size = K(3.8, 3.8, 4.4), color = CK("ffffff", FIRE, "ffffff"), alpha = 1 })
    PablocosReticles.RegisterReticle({
        id = "fireice", name = "Special: Fire & Ice", baseHue = 20, hueSpread = 0.15,
        left = { dur = 0.2, ease = "out" }, right = { dur = 0.2, ease = "inout" },
        parts = parts,
    })
end

-- =========================================================================================================
-- Plain Dot: one dot and nothing else. White in Classic; any other colourway makes it that colour (recolorNeutral
-- tells the engine to recolour this design's white, which colourways normally leave alone). No animation, so left
-- and right click do nothing visible. Opacity and Scale in Settings tune it.
-- =========================================================================================================
PablocosReticles.RegisterReticle({
    id = "plaindot", name = "Special: Plain Dot", recolorNeutral = true,
    left = { dur = 0.1, ease = "linear" }, right = { dur = 0.1, ease = "linear" },
    parts = {
        { tex = "disc_hard", size = 4, color = "ffffff", alpha = 1 },
    },
})

-- =========================================================================================================
-- Classes, designs and colourways.
-- Every texture is white and tinted at draw time, so any design can wear any colourway. A colourway moves each
-- part's hue to the colourway's hue, keeping the lightness and saturation the design chose. Hues the design
-- uses for contrast (the lime in the Arcanist, the cyan in the Sorcerer) stay a little off the main hue so the
-- reticle does not collapse into one flat colour; neutrals (whites) and near-blacks (outlines) never change.
-- baseHue is the design's own main hue in degrees.
-- =========================================================================================================
PablocosReticles.classOrder = { "Dragon Knight", "Sorcerer", "Nightblade", "Templar", "Warden", "Necromancer", "Arcanist", "Special" }

local META = {
    dragonknight  = { class = "Dragon Knight", design = "Embers",   baseHue = 20 },
    dktalons      = { class = "Dragon Knight", design = "Talons",   baseHue = 20 },
    sorcerer      = { class = "Sorcerer",      design = "Storm",    baseHue = 255 },
    sorcerer_calm = { class = "Sorcerer",      design = "Calm",     baseHue = 255 },
    nightblade    = { class = "Nightblade",    design = "Crescents", baseHue = 270 },
    templar       = { class = "Templar",       design = "Sun",      baseHue = 45 },
    warden        = { class = "Warden",        design = "Leaves",   baseHue = 140 },
    necromancer   = { class = "Necromancer",   design = "Scythes",  baseHue = 205 },
    arcanist      = { class = "Arcanist",      design = "Crux",     baseHue = 140 },
}
PablocosReticles.reticles.fireice.class, PablocosReticles.reticles.fireice.design = "Special", "Fire & Ice"
PablocosReticles.reticles.plaindot.class, PablocosReticles.reticles.plaindot.design = "Special", "Plain Dot"
for id, m in pairs(META) do
    local def = PablocosReticles.reticles[id]
    def.class, def.design, def.baseHue = m.class, m.design, m.baseHue
    def.name = m.class .. ": " .. m.design
end

-- hue in degrees; `white` desaturates instead of shifting hue
PablocosReticles.colorways = {
    { id = "classic", name = "Classic (each class's own)" },
    { id = "red",     name = "Red",     hue = 355 },
    { id = "orange",  name = "Orange",  hue = 25 },
    { id = "yellow",  name = "Yellow",  hue = 48 },
    { id = "green",   name = "Green",   hue = 135 },
    { id = "cyan",    name = "Cyan",    hue = 186 },
    { id = "blue",    name = "Blue",    hue = 214 },
    { id = "purple",  name = "Purple",  hue = 275 },
    { id = "pink",    name = "Pink",    hue = 325 },
    { id = "white",   name = "White",   white = true },
}
PablocosReticles.colorwayById = {}
for _, c in ipairs(PablocosReticles.colorways) do PablocosReticles.colorwayById[c.id] = c end
