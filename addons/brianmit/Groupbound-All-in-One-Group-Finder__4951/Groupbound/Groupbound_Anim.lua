-- Groupbound_Anim.lua : one small tween engine (like Skillbound's / Rumorbound's):
-- Anim.Run(key, ms, curve, step(p), done) runs step every frame with p going 0 -> 1 along the
-- curve; the same key again replaces the running one. sv.anim "off" = straight to the end,
-- "subtle" = shorter.

local G = Groupbound
local Anim = {}
G.Anim = Anim

Anim.MICRO, Anim.STD, Anim.OPEN, Anim.CLOSE = 120, 220, 280, 180

function Anim.Out(t) return 1 - (1 - t) ^ 3 end
function Anim.In(t) return t ^ 3 end
function Anim.InOut(t)
    if t < 0.5 then return 4 * t ^ 3 end
    return 1 - (-2 * t + 2) ^ 3 / 2
end
function Anim.Lerp(a, b, p) return a + (b - a) * p end

local running = {}
local count = 0
local NAME = "Groupbound_Anim"

local function Tick()
    local now = GetFrameTimeMilliseconds()
    local finished
    for key, a in pairs(running) do
        local t = a.ms > 0 and math.min(1, (now - a.start) / a.ms) or 1
        a.step(a.curve(t))
        if t >= 1 then
            finished = finished or {}
            finished[#finished + 1] = key
        end
    end
    -- (done callbacks may start new tweens: only after the loop, never while traversing)
    if finished then
        for _, key in ipairs(finished) do
            local a = running[key]
            if a then
                running[key] = nil
                count = count - 1
                if a.done then a.done() end
            end
        end
    end
    if count <= 0 then
        count = 0
        EVENT_MANAGER:UnregisterForUpdate(NAME)
    end
end
local SafeTick = function()
    local ok, err = pcall(Tick)
    if not ok then
        ZO_ClearTable(running)
        count = 0
        EVENT_MANAGER:UnregisterForUpdate(NAME)
        G.ReportError("Anim", err)
    end
end

function Anim.Run(key, ms, curve, step, done)
    local mode = G.sv and G.sv.anim or "full"
    if mode == "off" then ms = 0 elseif mode == "subtle" then ms = ms * 0.6 end
    if running[key] then
        running[key] = nil
        count = count - 1
    end
    if ms <= 0 then
        step(1)
        if done then done() end
        return
    end
    running[key] = { start = GetFrameTimeMilliseconds(), ms = ms, curve = curve or Anim.Out, step = step, done = done }
    count = count + 1
    if count == 1 then EVENT_MANAGER:RegisterForUpdate(NAME, 0, SafeTick) end
end

function Anim.Stop(key)
    if running[key] then
        running[key] = nil
        count = count - 1
    end
end

function Anim.IsRunning(key)
    return running[key] ~= nil
end
