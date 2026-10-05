-- Skillbound_Anim.lua : one motion language for everything (picked 2026-10-01).
-- Three curves: Out (things arriving: fast start, soft stop), In (things leaving:
-- soft start, quick end), InOut (things moving from A to B), plus Pop (up and back).
-- Fixed durations: MICRO 120 ms (hover), PRESS 80 ms, STD 220 ms (tabs, selection,
-- moving parts), OPEN 280 ms / CLOSE 180 ms (window), STAGGER 30 ms between rows.
-- sv.anim: "full", "subtle" (shorter, no decorative extras like sheens and pops) or
-- "off" (everything jumps to its end state at once).
-- All tweens run on one shared per-frame update that stops when nothing moves.

local B = Skillbound
local Anim = {}
B.Anim = Anim

Anim.MICRO, Anim.PRESS, Anim.STD, Anim.OPEN, Anim.CLOSE = 120, 80, 220, 280, 180
Anim.STAGGER, Anim.FLASH, Anim.SHEEN = 30, 450, 700

function Anim.Out(t) return 1 - (1 - t) ^ 3 end
function Anim.In(t) return t * t * t end
function Anim.InOut(t)
    if t < 0.5 then return 4 * t * t * t end
    local f = -2 * t + 2
    return 1 - f * f * f / 2
end
function Anim.Linear(t) return t end
-- 0 -> 1 -> 0 (pulses, pops, flashes that come and go)
function Anim.Pop(t) return math.sin(t * math.pi) end

local tweens = {}
local counter = 0

local function Mode() return B.sv and B.sv.anim or "full" end
function Anim.Enabled() return Mode() ~= "off" end
function Anim.Full() return Mode() == "full" end

local function Tick()
    local now = GetFrameTimeMilliseconds()
    local finished
    for key, tw in pairs(tweens) do
        if now >= tw.start then
            local t = math.min(1, (now - tw.start) / tw.dur)
            local ok = pcall(tw.fn, tw.ease(t), t)
            if t >= 1 or not ok then
                tweens[key] = nil
                if tw.done then
                    finished = finished or {}
                    finished[#finished + 1] = tw.done
                end
            end
        end
    end
    if finished then
        for _, done in ipairs(finished) do pcall(done) end
    end
    if next(tweens) == nil then B.EM:UnregisterForUpdate("Skillbound_Anim") end
end

-- Runs fn(easedProgress, rawProgress) every frame for dur ms (after delay ms).
-- key: a running tween with the same key is replaced (nil = always a new one).
-- decorative: skipped in "subtle" (only the end state is set).
function Anim.Run(key, dur, ease, fn, done, delay, decorative)
    local mode = Mode()
    if mode == "off" or (decorative and mode == "subtle") then
        if key then tweens[key] = nil end
        pcall(fn, 1, 1)
        if done then done() end
        return
    end
    if mode == "subtle" then
        dur = dur * 0.6
        delay = (delay or 0) * 0.6
    end
    if not key then
        counter = counter + 1
        key = "t" .. counter
    end
    tweens[key] = {
        start = GetFrameTimeMilliseconds() + (delay or 0),
        dur = math.max(1, dur), ease = ease or Anim.Out, fn = fn, done = done,
    }
    if (delay or 0) == 0 then pcall(fn, 0, 0) end
    B.EM:RegisterForUpdate("Skillbound_Anim", 0, Tick)
end

-- stop a tween; finish = jump to its end state first
function Anim.Stop(key, finish)
    local tw = tweens[key]
    if not tw then return end
    tweens[key] = nil
    if finish then
        pcall(tw.fn, 1, 1)
        if tw.done then pcall(tw.done) end
    end
end

function Anim.IsRunning(key) return tweens[key] ~= nil end

local function Lerp(a, b, p) return a + (b - a) * p end
Anim.Lerp = Lerp

-- ---------------------------------------------------------------------------
-- Helpers for the usual moves

function Anim.Alpha(control, from, to, dur, ease, key, done, delay, decorative)
    control:SetAlpha(from)
    Anim.Run(key, dur, ease, function(p) control:SetAlpha(Lerp(from, to, p)) end, done, delay, decorative)
end

-- Controls that move remember their anchor: Anim.Anchor(control, point, rel, relPoint, x, y),
-- then Anim.Offset(control, dx, dy) shifts them from there.
function Anim.Anchor(control, point, rel, relPoint, x, y)
    control.sbAnchor = { point, rel, relPoint, x or 0, y or 0 }
    control.sbAnchor2 = nil
    control:ClearAnchors()
    control:SetAnchor(point, rel, relPoint, x or 0, y or 0)
end

-- a second anchor (controls stretched between two points, e.g. TOPLEFT + BOTTOMRIGHT)
function Anim.Anchor2(control, point, rel, relPoint, x, y)
    control.sbAnchor2 = { point, rel, relPoint, x or 0, y or 0 }
    control:SetAnchor(point, rel, relPoint, x or 0, y or 0)
end

-- fill a parent (two anchors), with optional insets
function Anim.Fill(control, rel, left, top, right, bottom)
    Anim.Anchor(control, TOPLEFT, rel, TOPLEFT, left or 0, top or 0)
    Anim.Anchor2(control, BOTTOMRIGHT, rel, BOTTOMRIGHT, -(right or 0), -(bottom or 0))
end

function Anim.Offset(control, dx, dy)
    local a = control.sbAnchor
    if not a then return end
    control:ClearAnchors()
    control:SetAnchor(a[1], a[2], a[3], a[4] + (dx or 0), a[5] + (dy or 0))
    local a2 = control.sbAnchor2
    if a2 then control:SetAnchor(a2[1], a2[2], a2[3], a2[4] + (dx or 0), a2[5] + (dy or 0)) end
end

-- slide in from (dx, dy) to the anchor while fading in
function Anim.SlideIn(control, dx, dy, dur, key, delay, decorative)
    -- start hidden at the offset right away (with a delay it would show full for a moment)
    control:SetAlpha(0)
    Anim.Offset(control, dx, dy)
    Anim.Run(key, dur or Anim.STD, Anim.Out, function(p)
        control:SetAlpha(p)
        Anim.Offset(control, dx * (1 - p), dy * (1 - p))
    end, nil, delay, decorative)
end

-- a short scale pop (1 -> peak -> 1), e.g. the favorite diamond, the logo when done
function Anim.Pulse(control, peak, dur, key)
    Anim.Run(key, dur or 200, Anim.Linear, function(p)
        control:SetScale(1 + (peak - 1) * Anim.Pop(p))
    end, function() control:SetScale(1) end, 0, true)
end

-- a glow texture flashes up and fades out
function Anim.Flash(glow, color, dur, key)
    glow:SetHidden(false)
    if color then glow:SetColor(B.RGBA(color)) end
    Anim.Run(key, dur or Anim.FLASH, Anim.Out, function(p) glow:SetAlpha(1 - p) end,
        function() glow:SetHidden(true) end)
end

-- a sheen texture sweeps across a control (left to right). It stays inside the control
-- and fades in and out at the ends (plain controls can't clip their children).
function Anim.Sheen(sheen, over, key, delay)
    local w = sheen:GetWidth()
    local alpha = sheen.sbAlpha or sheen:GetAlpha()
    sheen.sbAlpha = alpha
    Anim.Run(key, Anim.SHEEN, Anim.InOut, function(p, raw)
        sheen:SetHidden(raw >= 1)
        sheen:SetAlpha(alpha * Anim.Pop(raw))
        sheen:ClearAnchors()
        sheen:SetAnchor(LEFT, over, LEFT, Lerp(0, math.max(0, over:GetWidth() - w), p), 0)
    end, function() sheen:SetHidden(true) end, delay, true)
end

-- a quick sideways shake (something can't be done)
function Anim.Shake(control, key)
    Anim.Run(key, 180, Anim.Linear, function(p)
        Anim.Offset(control, math.sin(p * math.pi * 4) * 3 * (1 - p), 0)
    end, function() Anim.Offset(control, 0, 0) end)
end
