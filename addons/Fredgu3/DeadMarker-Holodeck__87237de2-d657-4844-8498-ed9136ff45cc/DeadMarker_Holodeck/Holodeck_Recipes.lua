--=====================================================================
-- Holodeck_Recipes.lua — per-trial overlay (own 200-local chunk).
-- Keep ghosts in fights/*.lua. Furniture, shouts, and HP clocks live here.
--=====================================================================

Holodeck = Holodeck or {}
Holodeck.Recipes = Holodeck.Recipes or {}

local FLY_R_M = 12
local FLY_MIN_SEC = 2.5
local FLY_MERGE_SEC = 4

local function blob(fight)
    return string.lower(tostring(fight.id or "") .. " " .. tostring(fight.boss or "")
        .. " " .. tostring(fight.name or "") .. " " .. tostring(fight.trial or ""))
end

local function findRecipe(fight)
    if type(fight) ~= "table" then return nil end
    local id = fight.id
    if id and Holodeck.Recipes[id] then return Holodeck.Recipes[id] end
    local s = blob(fight)
    for _, rec in pairs(Holodeck.Recipes) do
        if type(rec) == "table" and type(rec.match) == "string" then
            if s:find(rec.match, 1, true) then return rec end
        end
    end
    return nil
end

local function addCentroid(fight)
    local ents = fight.entities
    if type(ents) ~= "table" then return 0, 0 end
    local sx, sz, n = 0, 0, 0
    local i = 1
    while i <= #ents do
        local e = ents[i]
        local lab = string.lower(tostring((e and e.label) or "") .. " " .. tostring((e and e.id) or ""))
        local kind = e and e.kind
        if e and (kind == "trash" or kind == "mini") and not lab:find("atronach", 1, true) then
            local tr = e.track
            if type(tr) == "table" and tr[1] and tr[1].x ~= nil then
                sx = sx + (tr[1].x or 0)
                sz = sz + (tr[1].z or 0)
                n = n + 1
            end
        end
        i = i + 1
    end
    -- Lokkestiiz is atronachs only. Second pass so pads still sit on the platform.
    if n < 1 then
        i = 1
        while i <= #ents do
            local e = ents[i]
            local kind = e and e.kind
            if e and (kind == "trash" or kind == "mini") then
                local tr = e.track
                if type(tr) == "table" and tr[1] and tr[1].x ~= nil then
                    sx = sx + (tr[1].x or 0)
                    sz = sz + (tr[1].z or 0)
                    n = n + 1
                end
            end
            i = i + 1
        end
    end
    if n < 1 then return 0, 0 end
    return sx / n, sz / n
end

local function bossTrack(fight)
    local ents = fight.entities
    if type(ents) ~= "table" then return nil end
    local i = 1
    while i <= #ents do
        local e = ents[i]
        if e and e.kind == "boss" and type(e.track) == "table" then
            return e.track
        end
        i = i + 1
    end
    return nil
end

-- Boss path far from the add blob = fly / untargetable. HP freezes there.
local function flyWindows(fight)
    local tr = bossTrack(fight)
    if type(tr) ~= "table" or #tr < 2 then return {} end
    local cx, cz = addCentroid(fight)
    local wins, cur = {}, nil
    local i = 1
    while i <= #tr do
        local k = tr[i]
        local flying = false
        if k and k.x ~= nil then
            local r = math.sqrt((k.x - cx) * (k.x - cx) + ((k.z or 0) - cz) * ((k.z or 0) - cz))
            flying = r >= FLY_R_M
        end
        local t = (k and k.t) or 0
        if flying then
            if not cur then
                cur = { t0 = t, t1 = t }
            else
                cur.t1 = t
            end
        elseif cur then
            -- Extend to the landing sample so a single far keyframe still counts.
            cur.t1 = t
            wins[#wins + 1] = cur
            cur = nil
        end
        i = i + 1
    end
    if cur then wins[#wins + 1] = cur end
    local merged = {}
    i = 1
    while i <= #wins do
        local w = wins[i]
        local last = merged[#merged]
        if last and (w.t0 - last.t1) <= FLY_MERGE_SEC then
            last.t1 = w.t1
        else
            merged[#merged + 1] = { t0 = w.t0, t1 = w.t1 }
        end
        i = i + 1
    end
    local out = {}
    i = 1
    while i <= #merged do
        local w = merged[i]
        if (w.t1 - w.t0) >= FLY_MIN_SEC then
            out[#out + 1] = w
        end
        i = i + 1
    end
    return out
end

local function groundPark(fight)
    local tr = bossTrack(fight)
    local cx, cz = addCentroid(fight)
    if type(tr) ~= "table" then return { x = cx, z = cz } end
    local sx, sz, n = 0, 0, 0
    local i = 1
    while i <= #tr do
        local k = tr[i]
        if k and k.x ~= nil then
            local dx = k.x - cx
            local dz = (k.z or 0) - cz
            local r = math.sqrt(dx * dx + dz * dz)
            if r < FLY_R_M then
                sx = sx + k.x
                sz = sz + (k.z or 0)
                n = n + 1
            end
        end
        i = i + 1
    end
    if n < 1 then return { x = cx, z = cz } end
    return { x = sx / n, z = sz / n }
end

-- When the dragon is not in a fly window, pin him on the platform (log XYZ wanders).
function Holodeck.GroundBossAt(fight, tSec)
    if type(fight) ~= "table" then return nil end
    local park = fight._groundPark
    if type(park) ~= "table" then return nil end
    tSec = tonumber(tSec) or 0
    local wins = fight._flyWindows
    if type(wins) == "table" then
        local i = 1
        while i <= #wins do
            local w = wins[i]
            if tSec >= (w.t0 or 0) and tSec < (w.t1 or 0) then
                return nil
            end
            i = i + 1
        end
    end
    return park.x, park.z
end

local function flyBefore(wins, tSec)
    local g = 0
    local i = 1
    while i <= #wins do
        local w = wins[i]
        local a, b = w.t0 or 0, w.t1 or 0
        if b <= tSec then
            g = g + (b - a)
        elseif a < tSec then
            g = g + (tSec - a)
        end
        i = i + 1
    end
    return g
end

function Holodeck.RemainHp(fight, tSec)
    if type(fight) ~= "table" then return nil end
    local wins = fight._flyWindows
    if type(wins) ~= "table" or #wins < 1 then return nil end
    local dur = tonumber(fight.durationSec) or 0
    if dur < 1 then dur = 1 end
    tSec = tonumber(tSec) or 0
    if tSec < 0 then tSec = 0 end
    if tSec > dur then tSec = dur end
    local flyTot = flyBefore(wins, dur)
    local ground = dur - flyTot
    if ground < 1 then ground = 1 end
    local g = tSec - flyBefore(wins, tSec)
    if g < 0 then g = 0 end
    local remain = 100 * (1 - (g / ground))
    if remain < 0 then remain = 0 end
    if remain > 100 then remain = 100 end
    return remain
end

local function timeAtPct(fight, pct)
    local dur = tonumber(fight.durationSec) or 0
    if dur < 1 then return nil end
    local t, prev, step = 0, 100, 0.25
    while t <= dur do
        local r = Holodeck.RemainHp(fight, t)
        if r == nil then
            r = 100 * (1 - (t / dur))
        end
        if r <= pct and prev > pct then return t end
        prev = r
        t = t + step
    end
    return nil
end

local function alkoshWaves(fight)
    local ents = fight.entities
    if type(ents) ~= "table" then return {} end
    local spans = {}
    local i = 1
    while i <= #ents do
        local e = ents[i]
        local lab = string.lower(tostring((e and e.label) or "") .. " " .. tostring((e and e.id) or ""))
        local kind = e and e.kind
        local isAdd = (kind == "trash" or kind == "mini")
            and (lab:find("alkosh", 1, true) or lab:find("fate", 1, true)
                or lab:find("fury", 1, true) or lab:find("ruin", 1, true)
                or lab:find("will", 1, true))
            and not lab:find("atronach", 1, true)
        if isAdd and type(e.track) == "table" then
            local tOn, tOff = nil, nil
            local j = 1
            while j <= #e.track do
                local kf = e.track[j]
                local vis = kf and kf.visible ~= false and not kf.dead and kf.x ~= nil
                if vis then
                    if not tOn then tOn = kf.t or 0 end
                    tOff = kf.t or 0
                elseif tOn then
                    spans[#spans + 1] = { t0 = tOn, t1 = (kf and kf.t) or tOff }
                    tOn = nil
                end
                j = j + 1
            end
            if tOn then spans[#spans + 1] = { t0 = tOn, t1 = (tOff or tOn) + 4 } end
        end
        i = i + 1
    end
    if #spans < 1 then return {} end
    table.sort(spans, function(a, b) return a.t0 < b.t0 end)
    local waves = {}
    i = 1
    while i <= #spans do
        local sp = spans[i]
        local w = waves[#waves]
        if not w or sp.t0 > (w.t1 + 8) then
            waves[#waves + 1] = { t0 = sp.t0, t1 = sp.t1 }
        elseif sp.t1 > w.t1 then
            w.t1 = sp.t1
        end
        i = i + 1
    end
    return waves
end

local function applyNahviintaas(fight, rec)
    fight._flyWindows = flyWindows(fight)
    fight._groundPark = groundPark(fight)
    local cx, cz = addCentroid(fight)
    fight._arena = { x = cx, z = cz }
    local pads = {}
    -- Four vigil statues on a diamond around the add blob (NW matches the hide huddle).
    local statue = {
        { -5.2, 5.2 }, { 5.2, 5.2 }, { 5.2, -5.2 }, { -5.2, -5.2 },
    }
    local i = 1
    while i <= 4 do
        pads[#pads + 1] = {
            id = "_statue_" .. i,
            kind = "safe",
            x = cx + statue[i][1],
            z = cz + statue[i][2],
            slot = 9,
            label = "S" .. i,
        }
        i = i + 1
    end
    -- Three floor breaches, shallow arc on the hide side (+Z).
    local portal = { { -4.0, 3.2 }, { 0, 4.4 }, { 4.0, 3.2 } }
    i = 1
    while i <= 3 do
        pads[#pads + 1] = {
            id = "_breach_" .. i,
            kind = "portal",
            x = cx + portal[i][1],
            z = cz + portal[i][2],
            slot = 1,
            label = tostring(i),
        }
        i = i + 1
    end
    fight._pads = pads

    local cues = {}
    local portalTs = {}
    local hpCues = rec.hpCues or {}
    i = 1
    while i <= #hpCues do
        local hc = hpCues[i]
        local t = timeAtPct(fight, hc.pct)
        if t then
            cues[#cues + 1] = {
                t = t, dur = hc.dur or 8, kind = hc.kind, text = hc.text,
                slot = hc.slot, pct = hc.pct,
            }
            if hc.kind == "portal" then
                portalTs[#portalTs + 1] = t
            end
        end
        i = i + 1
    end

    local wins = fight._flyWindows
    i = 1
    while i <= #wins do
        local w = wins[i]
        local durW = (w.t1 or 0) - (w.t0 or 0)
        -- Opener (100%, in the air) freezes HP but is not a FLY! call.
        -- Short far-keyframe blips freeze HP without a shout.
        local opener = (i == 1 and (w.t0 or 0) < 25)
        if not opener and durW >= 10 then
            cues[#cues + 1] = {
                t = w.t0, dur = 8, kind = "fly", text = "FLY!",
            }
        end
        local tLand = w.t1 or 0
        if tLand > (w.t0 or 0) + 1 then
            cues[#cues + 1] = {
                t = tLand, dur = 4, kind = "land", text = "LAND!",
            }
        end
        i = i + 1
    end

    local waves = alkoshWaves(fight)
    i = 1
    while i <= #waves do
        local tHide = (waves[i].t1 or 0) + 2
        cues[#cues + 1] = {
            t = tHide, dur = 6, kind = "hide", text = "HIDE!", slot = 9,
        }
        i = i + 1
    end

    -- Portal after hide, not on top of it.
    i = 1
    while i <= #cues do
        local c = cues[i]
        if c and c.kind == "portal" then
            local j = 1
            while j <= #cues do
                local h = cues[j]
                if h and h.kind == "hide" then
                    local hideEnd = (h.t or 0) + (h.dur or 6)
                    local pt = c.t or 0
                    if (h.t or 0) <= pt + 1 and hideEnd + 2 > pt then
                        if hideEnd + 3 > pt then
                            c.t = hideEnd + 3
                        end
                    end
                end
                j = j + 1
            end
        end
        i = i + 1
    end
    portalTs = {}
    i = 1
    while i <= #cues do
        if cues[i] and cues[i].kind == "portal" then
            portalTs[#portalTs + 1] = cues[i].t
        end
        i = i + 1
    end

    table.sort(cues, function(a, b) return (a.t or 0) < (b.t or 0) end)
    fight._cues = cues

    -- Boss-only: tag the trainer on each portal window. Player packs: three DPS.
    if type(fight._tags) ~= "table" then fight._tags = {} end
    local dps = {}
    local ents = fight.entities
    if type(ents) == "table" then
        i = 1
        while i <= #ents do
            local e = ents[i]
            if e and (e.kind == "dps") and e.id then
                dps[#dps + 1] = e.id
            end
            i = i + 1
        end
    end
    i = 1
    while i <= #portalTs do
        local t0 = portalTs[i]
        local t1 = t0 + 90
        if #dps >= 1 then
            local ids = {}
            local n = #dps
            if n > 3 then n = 3 end
            local p = 1
            while p <= n do
                ids[#ids + 1] = dps[p]
                p = p + 1
            end
            fight._tags[#fight._tags + 1] = { t0 = t0, t1 = t1, ids = ids }
        else
            fight._tags[#fight._tags + 1] = { t0 = t0, t1 = t1, ids = { "_you" }, you = true }
        end
        i = i + 1
    end
end

local function inFly(wins, t)
    if type(wins) ~= "table" then return false end
    local i = 1
    while i <= #wins do
        local w = wins[i]
        if t >= (w.t0 or 0) and t < (w.t1 or 0) then return true end
        i = i + 1
    end
    return false
end

-- Self-consistent with RemainHp: fly starts when grounded HP hits pct.
-- hold = seconds, or a table of per-flight holds.
local function hpFlyWindows(fight, pcts, hold)
    local dur = tonumber(fight.durationSec) or 0
    local holds, flyTot = {}, 0
    local i = 1
    while i <= #pcts do
        local h
        if type(hold) == "table" then
            h = hold[i] or 16
        else
            h = hold or 16
        end
        holds[i] = h
        flyTot = flyTot + h
        i = i + 1
    end
    local ground = dur - flyTot
    if ground < 1 then ground = 1 end
    local wins, flown = {}, 0
    i = 1
    while i <= #pcts do
        local t0 = ground * (1 - (pcts[i] / 100)) + flown
        if t0 < 1 then t0 = 1 end
        wins[#wins + 1] = { t0 = t0, t1 = t0 + holds[i] }
        flown = flown + holds[i]
        i = i + 1
    end
    return wins
end

-- Path XYZ only if it actually looks like the aerials (count + duration).
-- Yol/Lok hover in place; log hops are too short, so fall back to HP windows.
local function pickFlyWindows(fight, pcts, hold)
    local path = flyWindows(fight)
    local need = #pcts
    local minDur = 8
    if type(hold) == "number" then
        minDur = hold * 0.5
    elseif type(hold) == "table" and hold[1] then
        minDur = (hold[1] or 16) * 0.4
    end
    local ok = 0
    if type(path) == "table" then
        local i = 1
        while i <= #path do
            local w = path[i]
            if ((w.t1 or 0) - (w.t0 or 0)) >= minDur then
                ok = ok + 1
            end
            i = i + 1
        end
    end
    if ok >= need then return path end
    return hpFlyWindows(fight, pcts, hold)
end

local function tagYou(fight, t0, t1)
    if type(fight._tags) ~= "table" then fight._tags = {} end
    fight._tags[#fight._tags + 1] = { t0 = t0, t1 = t1, ids = { "_you" }, you = true }
end

local function spawnWaveTimes(fight, needle, mergeSec)
    local times = {}
    local ents = fight.entities
    if type(ents) ~= "table" then return times end
    local i = 1
    while i <= #ents do
        local e = ents[i]
        local lab = string.lower(tostring((e and e.label) or "") .. " " .. tostring((e and e.id) or ""))
        if e and lab:find(needle, 1, true) then
            local t0 = 0
            if type(e.track) == "table" and e.track[1] then
                t0 = tonumber(e.track[1].t) or 0
            end
            times[#times + 1] = t0
        end
        i = i + 1
    end
    table.sort(times)
    local waves = {}
    i = 1
    while i <= #times do
        local t = times[i]
        local last = waves[#waves]
        if not last or (t - last) > (mergeSec or 12) then
            waves[#waves + 1] = t
        end
        i = i + 1
    end
    return waves
end

local function applyYolnahkriin(fight, rec)
    fight._flyWindows = pickFlyWindows(fight, { 75, 50, 25 }, 16)
    fight._groundPark = groundPark(fight)
    local cx, cz = addCentroid(fight)
    if fight._groundPark then
        cx, cz = fight._groundPark.x or cx, fight._groundPark.z or cz
    end
    fight._arena = { x = cx, z = cz }
    local pads = {
        { id = "_stack_a", kind = "stack", x = cx - 4.2, z = cz + 0.5, slot = 1, label = "A" },
        { id = "_stack_b", kind = "stack", x = cx + 4.2, z = cz + 0.5, slot = 2, label = "B" },
    }
    local rim = { { -8.5, 8.5 }, { 8.5, 8.5 }, { 8.5, -8.5 }, { -8.5, -8.5 } }
    local i = 1
    while i <= 4 do
        pads[#pads + 1] = {
            id = "_rim_" .. i, kind = "safe",
            x = cx + rim[i][1], z = cz + rim[i][2], slot = 8, label = "RIM",
        }
        i = i + 1
    end
    fight._pads = pads

    local cues = {}
    local wins = fight._flyWindows
    i = 1
    while i <= #wins do
        local w = wins[i]
        cues[#cues + 1] = { t = w.t0, dur = 8, kind = "fly", text = "FLY!" }
        cues[#cues + 1] = { t = (w.t0 or 0) + 2, dur = 12, kind = "rim", text = "RIM!", slot = 8 }
        local tLand = w.t1 or 0
        if tLand > (w.t0 or 0) + 1 then
            cues[#cues + 1] = { t = tLand, dur = 4, kind = "land", text = "LAND!" }
            cues[#cues + 1] = { t = tLand + 4, dur = 6, kind = "burn", text = "BURN IRON!" }
        end
        i = i + 1
    end

    local dur = tonumber(fight.durationSec) or 0
    local t = 14
    local slot = 1
    while t + 6 < dur do
        if not inFly(wins, t) then
            cues[#cues + 1] = { t = t, dur = 6, kind = "stack", text = "STACK!", slot = slot }
            tagYou(fight, t, t + 6)
            slot = (slot == 1) and 2 or 1
        end
        t = t + 34
    end

    table.sort(cues, function(a, b) return (a.t or 0) < (b.t or 0) end)
    fight._cues = cues
end

local function applyLokkestiiz(fight, rec)
    -- Aerials are long (two atro sets + Storm Fury). Holds cover beamDelay + beam.
    fight._flyWindows = pickFlyWindows(fight, { 80, 50, 20 }, { 48, 16, 40 })
    fight._groundPark = groundPark(fight)
    local cx, cz = addCentroid(fight)
    if fight._groundPark then
        cx, cz = fight._groundPark.x or cx, fight._groundPark.z or cz
    end
    fight._arena = { x = cx, z = cz }
    -- Tombs spawn on the back edge, opposite the dragon.
    local pads = {
        { id = "_tomb_1", kind = "soak", x = cx - 5.0, z = cz + 7.0, slot = 1, label = "T1" },
        { id = "_tomb_2", kind = "soak", x = cx,       z = cz + 8.0, slot = 2, label = "T2" },
        { id = "_tomb_3", kind = "soak", x = cx + 5.0, z = cz + 7.0, slot = 3, label = "T3" },
    }
    fight._pads = pads

    local cues = {}
    local wins = fight._flyWindows
    local beamDelay = { 40, 5, 30 }
    local i = 1
    while i <= #wins do
        local w = wins[i]
        cues[#cues + 1] = { t = w.t0, dur = 8, kind = "fly", text = "FLY!" }
        local tLand = w.t1 or 0
        local tBlock = (w.t0 or 0) + (beamDelay[i] or 12)
        if tBlock > tLand - 3 then
            tBlock = (w.t0 or 0) + 4
            if tBlock > tLand - 3 then tBlock = tLand - 6 end
        end
        if tBlock < (w.t0 or 0) then tBlock = w.t0 or 0 end
        cues[#cues + 1] = { t = tBlock, dur = 6, kind = "block", text = "BLOCK!" }
        if tLand > (w.t0 or 0) + 1 then
            cues[#cues + 1] = { t = tLand, dur = 4, kind = "land", text = "LAND!" }
        end
        i = i + 1
    end

    local dur = tonumber(fight.durationSec) or 0
    local t = 12
    local slot = 1
    while t + 8 < dur do
        if not inFly(wins, t) then
            cues[#cues + 1] = { t = t, dur = 8, kind = "tomb", text = "TOMB!", slot = slot }
            tagYou(fight, t, t + 8)
            slot = slot + 1
            if slot > 3 then slot = 1 end
        end
        t = t + 24
    end

    -- Kill storms (shock traps); OT walks frost through the traps.
    local storms = spawnWaveTimes(fight, "storm atronach", 12)
    i = 1
    while i <= #storms do
        cues[#cues + 1] = { t = storms[i], dur = 5, kind = "storm", text = "KILL STORM!" }
        cues[#cues + 1] = { t = storms[i] + 5, dur = 5, kind = "frost", text = "FROST THRU!" }
        i = i + 1
    end

    table.sort(cues, function(a, b) return (a.t or 0) < (b.t or 0) end)
    fight._cues = cues
end

Holodeck.Recipes.nahviintaas = {
    match = "nahviintaas",
    hpClock = "grounded-minus-fly",
    hpCues = {
        { pct = 90, kind = "portal", text = "PORTAL DOWN!", dur = 12, slot = 1 },
        { pct = 70, kind = "portal", text = "PORTAL DOWN!", dur = 12, slot = 1 },
        { pct = 50, kind = "portal", text = "PORTAL DOWN!", dur = 12, slot = 1 },
        { pct = 33, kind = "execute", text = "TAKE IT OUT!", dur = 6 },
    },
    apply = applyNahviintaas,
}

Holodeck.Recipes.yolnahkriin = {
    match = "yolnahkriin",
    hpClock = "grounded-minus-fly",
    apply = applyYolnahkriin,
}

Holodeck.Recipes.lokkestiiz = {
    match = "lokkestiiz",
    hpClock = "grounded-minus-fly",
    apply = applyLokkestiiz,
}

function Holodeck.ApplyRecipe(fight)
    if type(fight) ~= "table" then return end
    local rec = findRecipe(fight)
    if not rec then return end
    if type(rec.apply) == "function" then
        rec.apply(fight, rec)
    end
end

-- Same Holodeck pin art as trash/mini; tint + short plate distinguish families.
-- (ESO ability icons stretched blocky on world pins.)
local LOOK_GROUP = {
    fire  = { color = { 1.00, 0.42, 0.10 } },
    frost = { color = { 0.42, 0.82, 1.00 } },
    storm = { color = { 0.55, 0.72, 1.00 } },
}

local function lookOf(group, short, important, sizeM, color)
    local g = LOOK_GROUP[group] or {}
    return {
        color = color or g.color,
        short = short,
        important = important == true,
        sizeM = sizeM,
    }
end

-- Twins "Will of / Rage of" keep lunar/shadow tints; do not steal those names.
function Holodeck.LookupActorLook(label, id, kind)
    local s = string.lower(tostring(label or "") .. " " .. tostring(id or ""))
    if s == " " or s == "" then return nil end
    if s:find("will of", 1, true) or s:find("rage of", 1, true) then return nil end
    if s:find("iron servant", 1, true) then
        return { color = { 0.78, 0.52, 0.32 }, short = "Iron", important = true, sizeM = 1.32 }
    end
    if s:find("lava", 1, true) then
        return { color = { 1.00, 0.32, 0.08 }, short = "Lava", important = true, sizeM = 1.05 }
    end
    if s:find("flame atronach", 1, true) then
        return lookOf("fire", "Atro", true, 0.88)
    end
    if s:find("frost atronach", 1, true) then
        return lookOf("frost", "Frost", true, 0.95)
    end
    if s:find("storm atronach", 1, true) then
        return lookOf("storm", "Storm", true, 0.95)
    end
    if s:find("frost well", 1, true) then
        return lookOf("frost", "Well", true, 0.95)
    end
    if s:find("alkosh's fate", 1, true) or s:find("alkosh_s_fate", 1, true) then
        return {
            color = { 1.00, 0.82, 0.28 },
            short = "Fate",
            important = true,
            sizeM = 1.32,
        }
    end
    if s:find("alkosh's will", 1, true) or s:find("alkosh_s_will", 1, true) then
        return lookOf("storm", "Will", true, 1.22)
    end
    if s:find("ruin of alkosh", 1, true) then
        return lookOf("fire", "Ruin", true, 1.22)
    end
    if s:find("fury of alkosh", 1, true) then
        return lookOf("fire", "Fury", true, 1.22)
    end
    if s:find("eternal servant", 1, true) then
        return { color = { 1.00, 0.55, 0.18 }, short = "Servant", important = true, sizeM = 1.35 }
    end
    if s:find("vigil statue", 1, true) then
        return { color = { 0.72, 0.70, 0.62 }, short = "Statue", important = true, sizeM = 1.10 }
    end
    return nil
end

-- Boss hpEnc is "t_cs pct;..." (integer percent). Step-hold on playback.
function Holodeck.DecodeHp(enc)
    if type(enc) ~= "string" or enc == "" then return nil end
    local curve = {}
    for seg in string.gmatch(enc, "[^;]+") do
        local tcs, pct = string.match(seg, "^(-?%d+)%s+(-?%d+)$")
        tcs = tonumber(tcs)
        pct = tonumber(pct)
        if tcs and pct then
            curve[#curve + 1] = { t = tcs / 100, pct = pct }
        end
    end
    if #curve < 1 then return nil end
    return curve
end

function Holodeck.SampleHp(curve, tSec)
    if type(curve) ~= "table" or #curve < 1 then return nil end
    tSec = tonumber(tSec) or 0
    local pct = curve[1].pct
    local i = 1
    while i <= #curve do
        local s = curve[i]
        if s and (s.t or 0) <= tSec then
            pct = s.pct
        else
            break
        end
        i = i + 1
    end
    return pct
end

-- Time of the first sample that is at or under the threshold after one above it.
function Holodeck.HpCrossTime(curve, threshold)
    if type(curve) ~= "table" or #curve < 2 then return nil end
    threshold = tonumber(threshold)
    if not threshold then return nil end
    local i = 2
    while i <= #curve do
        local a, b = curve[i - 1], curve[i]
        local ap = a and tonumber(a.pct)
        local bp = b and tonumber(b.pct)
        if ap and bp and ap > threshold and bp <= threshold then
            return b.t or 0
        end
        i = i + 1
    end
    return nil
end

-- colorChange rules become banner cues. Needs the decoded boss curve for pct rules.
-- Runs after BuildPortalLayout, which clears _cues when a pack has no teleports.
function Holodeck.ApplyColorChange(fight)
    if type(fight) ~= "table" then return end
    local rules = fight.colorChange
    if type(rules) ~= "table" or #rules < 1 then return end
    local cues = fight._cues
    if type(cues) ~= "table" then
        cues = {}
    else
        local kept = {}
        local i = 1
        while i <= #cues do
            local c = cues[i]
            local k = c and c.kind
            if k ~= "mirror" and k ~= "mirrorswap" and k ~= "room" then
                kept[#kept + 1] = c
            end
            i = i + 1
        end
        cues = kept
    end
    fight._cues = cues
    local curve = nil
    local bossTrack = nil
    local ents = fight.entities
    if type(ents) == "table" then
        local i = 1
        while i <= #ents and (curve == nil or bossTrack == nil) do
            local e = ents[i]
            if type(e) == "table" and e.kind == "boss" then
                if bossTrack == nil and type(e.track) == "table" then bossTrack = e.track end
                if curve == nil and type(e.hp) == "table" and #e.hp > 0 then curve = e.hp end
            end
            i = i + 1
        end
    end
    local r = 1
    while r <= #rules do
        local rule = rules[r]
        if type(rule) == "table" then
            local t0 = tonumber(rule.t)
            if t0 == nil and curve and rule.pct ~= nil then
                t0 = Holodeck.HpCrossTime(curve, rule.pct)
            end
            if t0 ~= nil then
                local hold = tonumber(rule.hold) or 5
                if hold < 0.5 then hold = 0.5 end
                cues[#cues + 1] = {
                    t = t0,
                    dur = hold,
                    kind = "mirror",
                    text = rule.text or "MIRROR SWAP IN",
                }
                if not rule.quiet then
                    cues[#cues + 1] = {
                        t = t0 + hold,
                        dur = 2,
                        kind = "mirrorswap",
                        text = "SWAP!",
                    }
                end
            end
        end
        r = r + 1
    end

    -- Compass pins on the boss path. Default is log +x east, +z north.
    -- room.door = "south" shares Holodeck.CompassAxes with the yellow frame.
    -- Corners are the opening four. E/W appear at 90%, N/S at 60%.
    local cx, cz, n = 0, 0, 0
    if type(bossTrack) == "table" then
        local i = 1
        while i <= #bossTrack do
            local kf = bossTrack[i]
            if kf and kf.x ~= nil then
                cx = cx + (kf.x or 0)
                cz = cz + (kf.z or 0)
                n = n + 1
            end
            i = i + 1
        end
    end
    if n > 0 then
        cx, cz = cx / n, cz / n
        local far = 0
        local i = 1
        while i <= #bossTrack do
            local kf = bossTrack[i]
            if kf and kf.x ~= nil then
                local dx = (kf.x or 0) - cx
                local dz = (kf.z or 0) - cz
                local d = math.sqrt(dx * dx + dz * dz)
                if d > far then far = d end
            end
            i = i + 1
        end
        local radius = far * 0.88
        if radius < 8 then radius = 8 end
        local padsOk = true
        local oldPads = fight._pads
        if type(oldPads) == "table" then
            local p = 1
            while p <= #oldPads do
                if oldPads[p] and oldPads[p].kind ~= "mirror" then padsOk = false end
                p = p + 1
            end
        end
        if padsOk then
            local t90 = curve and Holodeck.HpCrossTime(curve, 90)
            local t60 = curve and Holodeck.HpCrossTime(curve, 60)
            local nx, nz, ex, ez = Holodeck.CompassAxes(fight)
            -- sn/se are steps along North and East. Diagonals are normalized below.
            local spots = {
                { lab = "NE", sn = 1, se = 1, at = 0 },
                { lab = "NW", sn = 1, se = -1, at = 0 },
                { lab = "SE", sn = -1, se = 1, at = 0 },
                { lab = "SW", sn = -1, se = -1, at = 0 },
                { lab = "E", sn = 0, se = 1, at = t90 },
                { lab = "W", sn = 0, se = -1, at = t90 },
                { lab = "N", sn = 1, se = 0, at = t60 },
                { lab = "S", sn = -1, se = 0, at = t60 },
            }
            local pads = {}
            local s = 1
            while s <= #spots do
                local sp = spots[s]
                if sp.at ~= nil then
                    local ux = sp.sn * nx + sp.se * ex
                    local uz = sp.sn * nz + sp.se * ez
                    local ulen = math.sqrt(ux * ux + uz * uz)
                    if ulen > 0.001 then
                        ux, uz = ux / ulen, uz / ulen
                    end
                    pads[#pads + 1] = {
                        id = "_mirror_" .. sp.lab,
                        kind = "mirror",
                        label = sp.lab,
                        x = cx + ux * radius,
                        z = cz + uz * radius,
                        showAt = sp.at,
                    }
                end
                s = s + 1
            end
            fight._pads = pads
        end
    end

    -- Light adds die in the dark. Dark adds (ruinachs first) die in the light.
    local room = fight.room
    if type(room) == "table" and type(ents) == "table" then
        local hits = {}
        local i = 1
        while i <= #ents do
            local e = ents[i]
            local lab = string.lower(tostring((e and e.label) or ""))
            local tr = e and e.track
            local tSpawn = (type(tr) == "table" and tr[1] and tonumber(tr[1].t)) or nil
            if tSpawn and lab ~= "" then
                local dark, light = false, false
                local needles = room.vulnerableInDark
                if type(needles) == "table" then
                    local k = 1
                    while k <= #needles do
                        local needle = string.lower(tostring(needles[k] or ""))
                        if needle ~= "" and lab:find(needle, 1, true) then dark = true end
                        k = k + 1
                    end
                end
                needles = room.vulnerableInLight
                if type(needles) == "table" then
                    local k = 1
                    while k <= #needles do
                        local needle = string.lower(tostring(needles[k] or ""))
                        if needle ~= "" and lab:find(needle, 1, true) then light = true end
                        k = k + 1
                    end
                end
                if dark or light then
                    hits[#hits + 1] = {
                        t = tSpawn,
                        dark = dark,
                        light = light,
                        ruin = lab:find("ruinach", 1, true) and true or false,
                    }
                end
            end
            i = i + 1
        end
        table.sort(hits, function(a, b) return (a.t or 0) < (b.t or 0) end)
        local groups = {}
        i = 1
        while i <= #hits do
            local h = hits[i]
            local g = groups[#groups]
            if not g or (h.t or 0) > (g.t1 or 0) + 12 then
                g = { t0 = h.t or 0, t1 = h.t or 0, dark = false, light = false, ruin = false }
                groups[#groups + 1] = g
            else
                if (h.t or 0) > (g.t1 or 0) then g.t1 = h.t or 0 end
            end
            if h.dark then g.dark = true end
            if h.light then g.light = true end
            if h.ruin then g.ruin = true end
            i = i + 1
        end
        i = 1
        while i <= #groups do
            local g = groups[i]
            local text = nil
            if g.ruin then
                text = "RUINACHS  ·  FLIP LIGHT"
            elseif g.light then
                text = "FLIP LIGHT"
            elseif g.dark then
                text = "FLIP DARK"
            end
            if text and (g.t0 or 0) >= 1 then
                local hold = (g.t1 or g.t0) - (g.t0 or 0) + 4
                if hold < 5 then hold = 5 end
                if hold > 10 then hold = 10 end
                cues[#cues + 1] = { t = g.t0, dur = hold, kind = "room", text = text }
            end
            i = i + 1
        end
    end

    table.sort(cues, function(a, b) return (tonumber(a.t) or 0) < (tonumber(b.t) or 0) end)
end

-- Hall of Fleshcraft. Portal jumps are ~11m, under the Count 14m test, and
-- the pads there are Count-only. A landing past the Shaper ring is a go.
-- Banner counts down to the jump. The pad stays until the team ports back.
function Holodeck.ApplyFleshPortals(fight)
    if type(fight) ~= "table" then return end
    local blob = string.lower(tostring(fight.id or "") .. " " .. tostring(fight.boss or "")
        .. " " .. tostring(fight.name or ""))
    if not blob:find("fleshcraft", 1, true) then return end
    local ents = fight.entities
    if type(ents) ~= "table" then return end

    local cx, cz, nb = 0, 0, 0
    local hops = {}
    local i = 1
    while i <= #ents do
        local e = ents[i]
        local kind = e and e.kind
        local tr = e and e.track
        if kind == "boss" and type(tr) == "table" and tr[1] and tr[1].x ~= nil then
            cx = cx + (tr[1].x or 0)
            cz = cz + (tr[1].z or 0)
            nb = nb + 1
        elseif (kind == "tank" or kind == "healer" or kind == "dps") and type(tr) == "table" then
            local prev = nil
            local j = 1
            while j <= #tr do
                local kf = tr[j]
                if kf and kf.x ~= nil then
                    if prev then
                        local dx = (kf.x or 0) - (prev.x or 0)
                        local dz = (kf.z or 0) - (prev.z or 0)
                        local dist = math.sqrt(dx * dx + dz * dz)
                        local dt = (kf.t or 0) - (prev.t or 0)
                        if dist >= 8 and dt >= 0 and dt <= 3.5 then
                            hops[#hops + 1] = { t = kf.t or 0, x = kf.x or 0, z = kf.z or 0 }
                        end
                    end
                    prev = kf
                end
                j = j + 1
            end
        end
        i = i + 1
    end
    if nb > 0 then
        cx, cz = cx / nb, cz / nb
    end
    if #hops < 1 then return end
    table.sort(hops, function(a, b) return (a.t or 0) < (b.t or 0) end)

    local clusters = {}
    i = 1
    while i <= #hops do
        local hp = hops[i]
        local cl = clusters[#clusters]
        if not cl or (hp.t - cl[1].t) >= 8 then
            clusters[#clusters + 1] = { hp }
        else
            cl[#cl + 1] = hp
        end
        i = i + 1
    end

    local trips, backs = {}, {}
    i = 1
    while i <= #clusters do
        local cl = clusters[i]
        local sx, sz, n = 0, 0, #cl
        local k = 1
        while k <= n do
            sx = sx + (cl[k].x or 0)
            sz = sz + (cl[k].z or 0)
            k = k + 1
        end
        sx, sz = sx / n, sz / n
        local away = math.sqrt((sx - cx) * (sx - cx) + (sz - cz) * (sz - cz))
        local row = { t = cl[1].t or 0, x = sx, z = sz }
        if away >= 12 then
            trips[#trips + 1] = row
        else
            backs[#backs + 1] = row
        end
        i = i + 1
    end
    if #trips < 1 then return end

    local cues = fight._cues
    if type(cues) ~= "table" then cues = {} end
    local kept = {}
    i = 1
    while i <= #cues do
        local c = cues[i]
        if not (type(c) == "table" and c.text == "PORTAL TEAM, GO") then
            kept[#kept + 1] = c
        end
        i = i + 1
    end

    local pads = {}
    i = 1
    while i <= #trips do
        local trip = trips[i]
        local tHop = trip.t or 0
        local t0 = tHop - 6
        if t0 < 1 then t0 = 1 end
        local nextGo = 1e9
        if trips[i + 1] then nextGo = trips[i + 1].t or nextGo end
        local hide = tHop + 25
        local r = 1
        while r <= #backs do
            local rt = backs[r].t or 0
            if rt > tHop and rt < nextGo then hide = rt end
            r = r + 1
        end
        kept[#kept + 1] = {
            t = t0, dur = tHop - t0, kind = "portal", text = "PORTAL TEAM, GO", slot = i,
        }
        pads[#pads + 1] = {
            id = "_fleshpad_" .. tostring(i),
            kind = "portal",
            label = "Portal",
            x = trip.x, z = trip.z,
            slot = i,
            showAt = t0,
            hideAt = hide,
        }
        i = i + 1
    end
    table.sort(kept, function(a, b) return (tonumber(a.t) or 0) < (tonumber(b.t) or 0) end)
    fight._cues = kept
    fight._pads = pads
end
