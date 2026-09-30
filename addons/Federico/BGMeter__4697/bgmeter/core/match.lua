
BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Match = {}

function Match.new()
    return {
        bgId       = nil,
        name       = nil,
        gameType   = nil,
        startMs    = nil,
        endMs      = nil,
        durationMs = 0,
        result     = nil,
        localTeam  = nil,
        capturedAt = nil,
        standing   = nil,
        teams      = nil,
        numRounds  = 1,
        timeline   = nil,
        killfeed   = nil,

        battle = {},

        haul = {
            apGained   = 0,
            xpGained   = 0,
            cpGained   = 0,
            medals     = 0,
            vetStart   = nil,
            vetEnd     = nil,
            vetRankUp  = false,
            apPerMin   = 0,
            apPerKill  = 0,
            xpPerMin   = 0,
        },
    }
end

function Match.new_row()
    return {
        charName    = nil,
        displayName = nil,
        team        = nil,
        classId     = nil,
        isLocal     = false,
        damage      = 0,
        healing     = 0,
        taken       = 0,
        kills       = 0,
        deaths      = 0,
        assists     = 0,
        score       = 0,
        caps        = 0,
        defPts      = 0,
        carried     = 0,
        carrierKills = 0,
        lives       = nil,
        medals      = 0,
    }
end

function Match.local_row(m)
    for _, row in ipairs(m.battle) do
        if row.isLocal then return row end
    end
    return nil
end

function Match.sort(m, key, desc)
    if desc == nil then desc = true end
    table.sort(m.battle, function(a, b)
        local av, bv = a[key] or 0, b[key] or 0
        if av == bv then return (a.damage or 0) > (b.damage or 0) end
        if desc then return av > bv end
        return av < bv
    end)
end

function Match.group_by_team(m)
    local rows = m.battle
    if not rows or #rows < 2 then return end
    local order, seen = {}, {}
    if m.localTeam and m.localTeam ~= 0 then order[1] = m.localTeam; seen[m.localTeam] = true end
    local rest = {}
    for _, r in ipairs(rows) do
        local t = r.team or 0
        if not seen[t] then seen[t] = true; rest[#rest + 1] = t end
    end
    table.sort(rest)
    for _, t in ipairs(rest) do order[#order + 1] = t end
    local out, n = {}, 0
    for _, t in ipairs(order) do
        for _, r in ipairs(rows) do
            if (r.team or 0) == t then n = n + 1; out[n] = r end
        end
    end
    for i = 1, n do rows[i] = out[i] end
end

function Match.column_max(m, key)
    local max = 0
    for _, row in ipairs(m.battle) do
        local v = row[key] or 0
        if v > max then max = v end
    end
    return max
end

function Match.played_ms(m)
    if m.playedMs and m.playedMs > 0 then return m.playedMs end
    return m.durationMs or 0
end

function Match.derive(m)
    m.durationMs = (m.endMs and m.startMs) and math.max(0, m.endMs - m.startMs) or m.durationMs
    local h = m.haul
    local F = BGMeter.Format
    local played = Match.played_ms(m)
    h.apPerMin = math.floor(F.per_minute(h.apGained, played) + 0.5)
    h.xpPerMin = math.floor(F.per_minute(h.xpGained, played) + 0.5)
    local lr = Match.local_row(m)
    local kills = lr and lr.kills or 0
    h.apPerKill = (kills > 0) and math.floor(h.apGained / kills + 0.5) or 0
    return m
end

function Match.flag_lanes(m, tspan)
    local ob = m.objectives
    if not ob or not ob.t or #ob.t == 0 or not ob.list or #ob.list == 0 then return nil end
    local CZ = BGMeter.zenimax.constants
    local packed = #ob.list > 4
    local episodes, cur_ep, seen = {}, {}, {}

    local function close_seg(ep, t1)
        if ep.cur ~= nil and t1 > ep.t0 then
            ep.segs[#ep.segs + 1] = { t0 = ep.t0, t1 = t1, own = ep.cur, name = packed and ep.name or nil }
        end
    end

    for i = 1, #ob.t do
        local li = ob.o[i]
        local info = ob.list[li]
        if info then
            local t = math.min(math.max(ob.t[i] or 0, 0), tspan)
            local evl = CZ.OBJ_EVENT_LABEL[ob.ev[i]] or (ob.ev[i] == -1 and "initial") or "?"
            local own = ob.own[i] or 0
            local absent = evl == "deactivated" or evl == "hidden" or ob.st[i] == CZ.OBJ_STATE_INACTIVE
            local ep = cur_ep[li]
            if absent then
                if ep then
                    close_seg(ep, t)
                    ep.cur, ep.w1 = nil, t
                    cur_ep[li] = nil
                end
                ep = nil
            elseif not ep then
                ep = { letter = tostring(info.letter), name = info.name, li = li,
                       segs = {}, ticks = {}, cur = 0, t0 = t, w0 = t, w1 = nil }
                episodes[#episodes + 1] = ep
                cur_ep[li] = ep
                seen[li] = true
            end
            if ep and evl == "initial" then
                if own ~= ep.cur then
                    close_seg(ep, t)
                    ep.cur, ep.t0 = own, t
                end
            elseif ep and (evl == "captured" or evl == "recaptured") then
                if own ~= ep.cur then
                    close_seg(ep, t)
                    ep.cur, ep.t0 = own, t
                    ep.ticks[#ep.ticks + 1] = { t = t, own = own, kind = "cap" }
                else
                    ep.ticks[#ep.ticks + 1] = { t = t, own = own, kind = "def" }
                end
            elseif ep and evl == "neutral" then
                if ep.cur ~= 0 then
                    close_seg(ep, t)
                    ep.cur, ep.t0 = 0, t
                end
            end
        end
    end
    for _, ep in ipairs(episodes) do
        if ep.w1 == nil then
            close_seg(ep, tspan)
            ep.w1 = tspan
        end
        ep.cur = nil
    end
    if #episodes == 0 then return nil end

    if not packed then
        local lanes = {}
        for li = 1, math.min(#ob.list, 4) do
            lanes[li] = { letter = tostring(ob.list[li].letter), name = ob.list[li].name,
                          segs = {}, ticks = {}, covered = 0 }
        end
        for _, ep in ipairs(episodes) do
            local lane = lanes[ep.li]
            if lane then
                for _, s in ipairs(ep.segs) do lane.segs[#lane.segs + 1] = s end
                for _, tk in ipairs(ep.ticks) do lane.ticks[#lane.ticks + 1] = tk end
                lane.covered = lane.covered + math.max(0, ep.w1 - ep.w0)
            end
        end
        for _, lane in ipairs(lanes) do
            if lane.covered > tspan then lane.covered = tspan end
        end
        return lanes
    end

    for _, ep in ipairs(episodes) do
        for _, tk in ipairs(ep.ticks) do tk.name, tk.letter = ep.name, ep.letter end
    end
    table.sort(episodes, function(a, b) return a.w0 < b.w0 end)
    local lanes = {}
    for _, ep in ipairs(episodes) do
        local best = nil
        for _, lane in ipairs(lanes) do
            if lane.w1 <= ep.w0 and (best == nil or lane.w1 > best.w1) then best = lane end
        end
        if not best then
            best = { letter = tostring(ep.letter), name = ep.name, li = ep.li,
                     segs = {}, ticks = {}, covered = 0, w1 = 0 }
            lanes[#lanes + 1] = best
        end
        if best.li ~= ep.li then
            best.letter, best.name, best.li = "~", nil, -1
        end
        for _, s in ipairs(ep.segs) do best.segs[#best.segs + 1] = s end
        for _, tk in ipairs(ep.ticks) do best.ticks[#best.ticks + 1] = tk end
        best.covered = best.covered + math.max(0, ep.w1 - ep.w0)
        if ep.w1 > best.w1 then best.w1 = ep.w1 end
    end
    for _, lane in ipairs(lanes) do lane.w1 = nil; lane.li = nil end
    return lanes
end

function Match.flag_occupation(lanes, tspan)
    if not lanes or #lanes == 0 or not tspan or tspan <= 0 then return nil end
    local total = 0
    for _, lane in ipairs(lanes) do
        total = total + (lane.covered or tspan)
    end
    if total <= 0 then return nil end
    local by = {}
    local neutral = 0
    for _, lane in ipairs(lanes) do
        for _, seg in ipairs(lane.segs) do
            local d = math.max(0, (seg.t1 or 0) - (seg.t0 or 0))
            if seg.own and seg.own ~= 0 then
                by[seg.own] = (by[seg.own] or 0) + d
            else
                neutral = neutral + d
            end
        end
    end
    local out = {}
    for team, ms in pairs(by) do
        out[#out + 1] = { team = team, ms = ms, pct = ms / total }
    end
    table.sort(out, function(a, b) return a.ms > b.ms end)
    return out, neutral / total
end

function Match.flag_stats(lanes)
    if not lanes or #lanes == 0 then return nil end
    local per = {}
    local function bucket(team)
        local b = per[team]
        if not b then
            b = { team = team, caps = 0, defs = 0, holdMs = 0, holds = 0 }
            per[team] = b
        end
        return b
    end
    local first = nil
    for _, lane in ipairs(lanes) do
        for _, tick in ipairs(lane.ticks) do
            if tick.own and tick.own ~= 0 then
                local bk = bucket(tick.own)
                if tick.kind == "cap" then
                    bk.caps = bk.caps + 1
                    if not first or tick.t < first.t then
                        first = { team = tick.own, t = tick.t,
                                  letter = tick.letter or lane.letter, name = tick.name or lane.name }
                    end
                else
                    bk.defs = bk.defs + 1
                end
            end
        end
        for _, seg in ipairs(lane.segs) do
            if seg.own and seg.own ~= 0 then
                local bk = bucket(seg.own)
                bk.holdMs = bk.holdMs + math.max(0, (seg.t1 or 0) - (seg.t0 or 0))
                bk.holds = bk.holds + 1
            end
        end
    end
    local out = {}
    for _, b in pairs(per) do
        b.avgHoldMs = (b.holds > 0) and math.floor(b.holdMs / b.holds) or 0
        out[#out + 1] = b
    end
    table.sort(out, function(x, y)
        if x.caps ~= y.caps then return x.caps > y.caps end
        return x.holdMs > y.holdMs
    end)
    if #out == 0 then return nil end
    return { per = out, first = first }
end

function Match.relic_lanes(m, tspan)
    local rl = m.relics
    if not rl or not rl.t or #rl.t == 0 or not rl.list or #rl.list == 0 then return nil end
    local CZ = BGMeter.zenimax.constants
    local LETTERS = { "A", "B", "C", "D" }
    local lanes = {}
    for li = 1, math.min(#rl.list, 4) do
        lanes[li] = {
            letter = LETTERS[li], name = rl.list[li].name, home = rl.list[li].home,
            segs = {}, ticks = {}, cur = 0, t0 = 0,
        }
    end
    local function close(lane, t1)
        if lane.cur and lane.cur ~= 0 and t1 > lane.t0 then
            lane.segs[#lane.segs + 1] = { t0 = lane.t0, t1 = t1, own = lane.cur, who = lane.who }
        end
        lane.who = nil
    end
    for i = 1, #rl.t do
        local lane = lanes[rl.o[i]]
        if lane then
            local t = math.min(math.max(rl.t[i] or 0, 0), tspan)
            local evl = CZ.OBJ_EVENT_LABEL[rl.ev[i]] or "?"
            if evl == "flag_taken" then
                close(lane, t)
                lane.cur, lane.t0 = rl.hold[i] or 0, t
                lane.who = rl.who and rl.who[i] or nil
                if not lane.home or lane.home == 0 then
                    lane.ticks[#lane.ticks + 1] = { t = t, own = rl.hold[i] or 0, kind = "take",
                                                    who = rl.who and rl.who[i] or nil }
                end
            elseif evl == "flag_dropped" or evl == "flag_spawned" then
                close(lane, t)
                lane.cur = 0
            elseif evl == "captured" then
                close(lane, t)
                lane.cur = 0
                local last = lane.segs[#lane.segs]
                if last and rl.who and rl.who[i] and last.t1 == t then last.who = rl.who[i] end
                lane.ticks[#lane.ticks + 1] = { t = t, own = rl.last[i] or 0, kind = "cap",
                                                who = rl.who and rl.who[i] or nil }
            elseif evl == "flag_returned" or evl == "flag_timer_return" then
                close(lane, t)
                lane.cur = 0
                if lane.home and lane.home ~= 0 then
                    lane.ticks[#lane.ticks + 1] = { t = t, own = lane.home, kind = "def" }
                end
            end
        end
    end
    for _, lane in ipairs(lanes) do
        close(lane, tspan)
        lane.cur = nil
    end
    return lanes
end

function Match.local_name(m)
    local lr = Match.local_row(m)
    local nm = lr and (lr.displayName or lr.charName)
    if not nm then return nil end
    return (nm:gsub("%^.*$", ""))
end

local CHUNK = 1500

function Match.pack_series(arr, n)
    local parts, prev = {}, 0
    for i = 1, n do
        local v = arr[i]
        if v == nil then v = prev end
        local d = v - prev
        parts[i] = (d == 0) and "" or tostring(math.floor(d + 0.5))
        prev = v
    end
    local s = table.concat(parts, ",")
    local chunks = {}
    for i = 1, #s, CHUNK do chunks[#chunks + 1] = s:sub(i, i + CHUNK - 1) end
    return chunks
end

function Match.unpack_series(chunks, n)
    if type(chunks) == "table" and type(chunks[1]) ~= "string" then return chunks end
    local s = type(chunks) == "string" and chunks or table.concat(chunks or {})
    local out, prev, i = {}, 0, 0
    for tok in (s .. ","):gmatch("([^,]*),") do
        i = i + 1
        local d = tonumber(tok) or 0
        prev = prev + d
        out[i] = prev
        if n and i >= n then break end
    end
    for k = i + 1, (n or i) do out[k] = prev end
    return out
end

function Match.pack_timeline(m)
    local tl = m and m.timeline
    if not tl then return 0 end
    local packed = 0
    if tl.p and tl.t then
        local n = #tl.t
        for _, rec in pairs(tl.p) do
            if type(rec.d) == "table" then
                rec.s = Match.pack_series(rec.d, n)
                rec.d = nil
                packed = packed + 1
            end
            rec.h = nil
        end
    end
    if tl.pt and tl.pos then
        local n = #tl.pt
        for _, rec in pairs(tl.pos) do
            if type(rec.x) == "table" and type(rec.x[1]) ~= "string" then
                rec.x = Match.pack_series(rec.x, n)
                rec.y = Match.pack_series(rec.y, n)
                packed = packed + 1
            end
        end
        for _, pin in ipairs(tl.pin or {}) do
            if type(pin.x) == "table" and type(pin.x[1]) ~= "string" then
                pin.x = Match.pack_series(pin.x, n)
                pin.y = Match.pack_series(pin.y, n)
                pin.ty = Match.pack_series(pin.ty, n)
                packed = packed + 1
            end
        end
        tl.pinIdx = nil
    end
    if tl.mt and type(tl.mx) == "table" and type(tl.mx[1]) ~= "string" then
        local n = #tl.mt
        tl.mx = Match.pack_series(tl.mx, n)
        tl.my = Match.pack_series(tl.my, n)
        tl.mt = Match.pack_series(tl.mt, n)
        packed = packed + 1
    end
    return packed
end

function Match.geo_index_of(times, n, t)
    local idx = 1
    for i = 1, n do
        if (times[i] or 0) <= t then idx = i else break end
    end
    return idx
end

function Match.geo_spline(xs, ys, n, sub, ox, oy)
    sub = sub or 3
    ox, oy = ox or {}, oy or {}
    local o = 0
    local function at(i) i = math.max(1, math.min(n, i)); return xs[i] or 0, ys[i] or 0 end
    for i = 1, n - 1 do
        local x0, y0 = at(i - 1)
        local x1, y1 = at(i)
        local x2, y2 = at(i + 1)
        local x3, y3 = at(i + 2)
        for k = 0, sub - 1 do
            local u = k / sub
            local u2, u3 = u * u, u * u * u
            o = o + 1
            ox[o] = 0.5 * ((2 * x1) + (-x0 + x2) * u + (2 * x0 - 5 * x1 + 4 * x2 - x3) * u2 + (-x0 + 3 * x1 - 3 * x2 + x3) * u3)
            oy[o] = 0.5 * ((2 * y1) + (-y0 + y2) * u + (2 * y0 - 5 * y1 + 4 * y2 - y3) * u2 + (-y0 + 3 * y1 - 3 * y2 + y3) * u3)
        end
    end
    local xl, yl = at(n)
    o = o + 1
    ox[o], oy[o] = xl, yl
    return ox, oy, o
end

function Match.geo(m)
    local tl = m and m.timeline
    if not tl or not tl.pt or #tl.pt < 2 or not tl.pos then return nil end
    local n = #tl.pt
    local team, mine = {}, Match.local_name(m)
    for _, r in ipairs(m.battle or {}) do
        local nm = r.displayName or r.charName
        if nm then team[(nm:gsub("%^.*$", ""))] = r.team end
    end
    local lr = Match.local_row(m)
    local twin = lr and lr.charName
    if not (twin and twin ~= mine and tl.pos[twin] and mine and tl.pos[mine]) then twin = nil end
    local pos, teammates = {}, 0
    for nm, rec in pairs(tl.pos) do
        if nm ~= twin then
            pos[nm] = { x = Match.unpack_series(rec.x, n), y = Match.unpack_series(rec.y, n) }
            if not team[nm] then team[nm] = m.localTeam end
            if nm ~= mine then teammates = teammates + 1 end
        end
    end
    local pins = {}
    for i, pin in ipairs(tl.pin or {}) do
        pins[i] = { name = pin.name, kind = pin.kind, keepId = pin.keepId, objectiveId = pin.objectiveId,
                    x = Match.unpack_series(pin.x, n), y = Match.unpack_series(pin.y, n), ty = Match.unpack_series(pin.ty, n) }
    end
    local stepMs = (n > 1) and math.floor((tl.pt[n] - tl.pt[1]) / (n - 1)) or 0
    local me = nil
    if tl.mt and tl.mx and tl.my then
        local mt = Match.unpack_series(tl.mt)
        local mn = #mt
        if mn >= 2 then
            me = { n = mn, t = mt, x = Match.unpack_series(tl.mx, mn), y = Match.unpack_series(tl.my, mn) }
        end
    end
    local startT = 0
    if m.playedMs and m.durationMs and m.durationMs > m.playedMs then startT = m.durationMs - m.playedMs end
    return { n = n, t = tl.pt, pos = pos, pins = pins, team = team, mine = mine, teammates = teammates, stepMs = stepMs, me = me, startT = startT }
end

local GEO_MEMO_ENTRIES = 3
local GEO_MEMO_KB = 4096
local geo_memo = { n = 0, kb = 0 }
local geo_tick = 0

local function geo_evict(i)
    local e = geo_memo[i]
    geo_memo.kb = geo_memo.kb - e.kb
    geo_memo[i] = geo_memo[geo_memo.n]
    geo_memo[geo_memo.n] = nil
    geo_memo.n = geo_memo.n - 1
end

local function geo_evict_oldest()
    local oldest, at = nil, 0
    for i = 1, geo_memo.n do
        if oldest == nil or geo_memo[i].tick < oldest then oldest, at = geo_memo[i].tick, i end
    end
    if at > 0 then geo_evict(at) end
end

function Match.geo_cached(m)
    if m == nil then return nil end
    geo_tick = geo_tick + 1
    for i = 1, geo_memo.n do
        local e = geo_memo[i]
        if e.m == m then
            e.tick = geo_tick
            return e.geo
        end
    end
    collectgarbage("stop")
    local k0 = collectgarbage("count")
    local geo = Match.geo(m)
    local kb = collectgarbage("count") - k0
    collectgarbage("restart")
    if kb < 0 then kb = 0 end
    geo_memo.n = geo_memo.n + 1
    geo_memo[geo_memo.n] = { m = m, geo = geo, kb = kb, tick = geo_tick }
    geo_memo.kb = geo_memo.kb + kb
    while geo_memo.n > GEO_MEMO_ENTRIES or (geo_memo.kb > GEO_MEMO_KB and geo_memo.n > 1) do geo_evict_oldest() end
    return geo
end

function Match.geo_cache_forget(m)
    for i = 1, geo_memo.n do
        if geo_memo[i].m == m then
            geo_evict(i)
            return true
        end
    end
    return false
end

function Match.geo_cache_has(m)
    for i = 1, geo_memo.n do
        if geo_memo[i].m == m then return true end
    end
    return false
end

function Match.geo_cache_clear()
    for i = geo_memo.n, 1, -1 do geo_memo[i] = nil end
    geo_memo.n, geo_memo.kb = 0, 0
end

function Match.geo_cache_report()
    local newest, m = -1, nil
    for i = 1, geo_memo.n do
        if geo_memo[i].tick > newest then newest, m = geo_memo[i].tick, geo_memo[i].m end
    end
    return { held = geo_memo.n > 0, entries = geo_memo.n, bytes = math.floor(geo_memo.kb * 1024 + 0.5), m = m }
end

function Match.geo_index(geo, t)
    if not geo then return 1 end
    local idx = 1
    for i = 1, geo.n do
        if (geo.t[i] or 0) <= t then idx = i else break end
    end
    return idx
end

local function heat_blur(grid, bins, passes)
    local src = grid
    for _ = 1, passes or 1 do
        local out = {}
        for by = 1, bins do
            for bx = 1, bins do
                local acc, wsum = 0, 0
                for dy = -1, 1 do
                    local yy = by + dy
                    if yy >= 1 and yy <= bins then
                        local wy = (dy == 0) and 2 or 1
                        for dx = -1, 1 do
                            local xx = bx + dx
                            if xx >= 1 and xx <= bins then
                                local w = wy * ((dx == 0) and 2 or 1)
                                local v = src[(yy - 1) * bins + xx]
                                if v then acc = acc + v * w end
                                wsum = wsum + w
                            end
                        end
                    end
                end
                if acc > 0 then out[(by - 1) * bins + bx] = acc / wsum end
            end
        end
        src = out
    end
    return src
end

local function heat_finish(grid, bins, passes, pct)
    local blurred = heat_blur(grid, bins, passes)
    local vals, max = {}, 0
    for _, v in pairs(blurred) do
        vals[#vals + 1] = v
        if v > max then max = v end
    end
    if max <= 0 then return nil end
    table.sort(vals)
    local cap = vals[math.max(1, math.floor(#vals * (pct or 0.95)))] or max
    if cap <= 0 then cap = max end
    return { grid = blurred, max = max, cap = cap, bins = bins }
end

local function heat_add(grid, bins, x, y, w)
    local bx = math.min(bins, math.floor(x / 1000 * bins) + 1)
    local by = math.min(bins, math.floor(y / 1000 * bins) + 1)
    local k = (by - 1) * bins + bx
    grid[k] = (grid[k] or 0) + (w or 1)
end

function Match.geo_heat(geo, m, bins)
    if not geo then return nil end
    bins = bins or 32
    local grid, any = {}, false
    for nm, s in pairs(geo.pos) do
        if geo.team[nm] == m.localTeam or nm == geo.mine then
            for i = 1, geo.n do
                local x, y = s.x[i], s.y[i]
                if x and y and (x > 0 or y > 0) and (geo.t[i] or 0) >= (geo.startT or 0) then
                    heat_add(grid, bins, x, y, 1)
                    any = true
                end
            end
        end
    end
    if not any then return nil end
    return heat_finish(grid, bins, 1, 0.95)
end

function Match.geo_heat_deaths(geo, m, bins)
    if not m or not m.killfeed then return nil end
    bins = bins or 32
    local grid, any = {}, false
    for _, k in ipairs(m.killfeed) do
        if k.x and k.y and k.kind then
            heat_add(grid, bins, k.x, k.y, 1)
            any = true
        end
    end
    if not any then return nil end
    return heat_finish(grid, bins, 3, 1.0)
end

function Match.damage_race(m)
    local tl = m and m.timeline
    if not tl or not tl.p or not tl.t or #tl.t < 2 then return nil end
    local n = #tl.t
    local team_of, mine = {}, nil
    for _, r in ipairs(m.battle or {}) do
        local nm = r.displayName or r.charName
        if nm then
            nm = (nm:gsub("%^.*$", ""))
            team_of[nm] = r.team
            if r.isLocal then mine = nm end
        end
    end
    local series, teams, seen, maxv = {}, {}, {}, 0
    local decoded = {}
    for nm, rec in pairs(tl.p) do
        decoded[nm] = rec.d or Match.unpack_series(rec.s, n)
        local team = team_of[nm] or rec.tm
        if team then
            if not seen[team] then seen[team] = true; teams[#teams + 1] = team; series[team] = {} end
            local row = series[team]
            local src = decoded[nm]
            for i = 1, n do
                row[i] = (row[i] or 0) + (src[i] or 0)
            end
        end
    end
    if #teams == 0 then return nil end
    table.sort(teams)
    for _, team in ipairs(teams) do
        local row = series[team]
        for i = 1, n do if row[i] > maxv then maxv = row[i] end end
    end
    local own = nil
    if mine and decoded[mine] then
        own = {}
        for i = 1, n do own[i] = decoded[mine][i] or 0 end
    end
    if maxv <= 0 then return nil end
    return { n = n, teams = teams, series = series, mine = own, max = maxv }
end

function Match.combat_momentum(killfeed, tspan, windowMs, stepMs)
    if not killfeed or #killfeed < 4 or not tspan or tspan <= 0 then return nil end
    windowMs = windowMs or 60000
    stepMs = stepMs or 5000
    local cur = {}
    local lo, hi = 1, 0
    local samples = {}
    local t = 0
    while t <= tspan do
        while hi < #killfeed and (killfeed[hi + 1].t or 0) <= t do
            hi = hi + 1
            local team = killfeed[hi].kt
            if team then cur[team] = (cur[team] or 0) + 1 end
        end
        while lo <= hi and (killfeed[lo].t or 0) < t - windowMs do
            local team = killfeed[lo].kt
            if team then cur[team] = (cur[team] or 0) - 1 end
            lo = lo + 1
        end
        local best, second, bestTeam = 0, 0, nil
        for team, c in pairs(cur) do
            if c > best then
                second = best
                best, bestTeam = c, team
            elseif c > second then
                second = c
            end
        end
        local diff = best - second
        samples[#samples + 1] = { t = t, team = (diff > 0) and bestTeam or nil, mag = diff }
        t = t + stepMs
    end
    local segs, curSeg, maxMag = {}, nil, 1
    for _, s in ipairs(samples) do
        local t1 = math.min(s.t + stepMs, tspan)
        if curSeg and curSeg.team == s.team then
            curSeg.t1 = t1
            if s.mag > curSeg.mag then curSeg.mag = s.mag end
        else
            curSeg = { t0 = s.t, t1 = t1, team = s.team, mag = s.mag }
            segs[#segs + 1] = curSeg
        end
        if s.mag > maxMag then maxMag = s.mag end
    end
    if #segs == 0 then return nil end
    return segs, maxMag, samples
end

function Match.lead_stats(tl)
    if not tl or not tl.t or #tl.t < 2 then return nil end
    local series = { tl.s1, tl.s2, tl.s3 }
    local teams = tl.teams or {}
    local changes = 0
    local leader = nil
    local maxLead = { team = nil, lead = 0, t = 0 }
    for i = 1, #tl.t do
        if i > 1 and tl.r and tl.r[i] ~= tl.r[i - 1] then leader = nil end
        local best, second, bestTeam = 0, 0, nil
        for s = 1, 3 do
            local team = teams[s]
            local v = (series[s] and series[s][i]) or 0
            if team and v > best then
                second = best
                best, bestTeam = v, team
            elseif team and v > second then
                second = v
            end
        end
        local lead = best - second
        if bestTeam and lead > 0 then
            if leader and bestTeam ~= leader then changes = changes + 1 end
            leader = bestTeam
            if lead > maxLead.lead then
                maxLead = { team = bestTeam, lead = lead, t = tl.t[i] }
            end
        end
    end
    if not maxLead.team then return nil end
    return { changes = changes, maxTeam = maxLead.team, maxLead = maxLead.lead,
             maxAt = maxLead.t, finalLeader = leader }
end

function Match.round_marks(tl)
    if not tl or not tl.t or not tl.r or #tl.t < 2 then return nil end
    local marks = {}
    for i = 2, #tl.t do
        if tl.r[i] ~= tl.r[i - 1] then
            marks[#marks + 1] = { i = i, t = tl.t[i], r = tl.r[i] }
        end
    end
    if #marks == 0 then return nil end
    return marks
end

function Match.smooth3(arr, n)
    n = n or #arr
    local out = {}
    for i = 1, n do
        local a = arr[math.max(1, i - 1)] or 0
        local b = arr[i] or 0
        local c = arr[math.min(n, i + 1)] or 0
        out[i] = (a + 2 * b + c) / 4
    end
    return out
end

function Match.kill_pressure(killfeed, tspan, binMs)
    if not killfeed or #killfeed == 0 or not tspan or tspan <= 0 then return nil end
    binMs = binMs or 60000
    local bins = math.max(1, math.ceil(tspan / binMs))
    local counts, teams, seen, maxv, total = {}, {}, {}, 0, 0
    for _, k in ipairs(killfeed) do
        local team = k.kt
        if team then
            local b = math.floor(math.max(0, math.min(k.t or 0, tspan - 1)) / binMs) + 1
            if not seen[team] then
                seen[team] = true
                teams[#teams + 1] = team
                counts[team] = {}
            end
            counts[team][b] = (counts[team][b] or 0) + 1
            if counts[team][b] > maxv then maxv = counts[team][b] end
            total = total + 1
        end
    end
    if #teams == 0 or maxv == 0 then return nil end
    table.sort(teams)
    return { bins = bins, binMs = binMs, teams = teams, counts = counts, max = maxv, total = total }
end

function Match.bloodiest_minute(killfeed, windowMs)
    if not killfeed or #killfeed == 0 then return nil end
    windowMs = windowMs or 60000
    local best = { count = 0, t0 = 0, t1 = 0 }
    local j = 1
    for i = 1, #killfeed do
        while (killfeed[i].t or 0) - (killfeed[j].t or 0) > windowMs do j = j + 1 end
        local count = i - j + 1
        if count > best.count then
            best = { count = count, t0 = killfeed[j].t or 0, t1 = killfeed[i].t or 0 }
        end
    end
    if best.count < 3 then return nil end
    return best
end

function Match.duels(m)
    local kf = m.killfeed
    if not kf or #kf == 0 then return nil end
    local killers, victims, kteam, vteam = {}, {}, {}, {}
    for _, k in ipairs(kf) do
        if k.kind == "death" and k.kn then
            killers[k.kn] = (killers[k.kn] or 0) + 1
            kteam[k.kn] = k.kt
        elseif k.kind == "kill" and k.dn then
            victims[k.dn] = (victims[k.dn] or 0) + 1
            vteam[k.dn] = k.dt
        end
    end
    local function top(map)
        local name, n = nil, 0
        for k, v in pairs(map) do
            if v > n or (v == n and name and k < name) then name, n = k, v end
        end
        return name, n
    end
    local nname, nn = top(killers)
    local pname, pn = top(victims)
    if not nname and not pname then return nil end
    return {
        nemesis = nname and { name = nname, count = nn, team = kteam[nname] } or nil,
        prey    = pname and { name = pname, count = pn, team = vteam[pname] } or nil,
    }
end

function Match.kill_streaks(killfeed, windowMs)
    if not killfeed or #killfeed == 0 then return nil end
    windowMs = windowMs or 12000
    local runs, open = {}, {}
    for _, k in ipairs(killfeed) do
        if k.kn then
            local o = open[k.kn]
            if o and (k.t or 0) - o.last <= windowMs then
                o.n = o.n + 1
                o.last = k.t or 0
            else
                if o and o.n >= 2 then runs[#runs + 1] = o end
                open[k.kn] = { name = k.kn, team = k.kt, n = 1, t = k.t or 0, last = k.t or 0 }
            end
        end
    end
    for _, o in pairs(open) do
        if o.n >= 2 then runs[#runs + 1] = o end
    end
    if #runs == 0 then return nil end
    table.sort(runs, function(a, b) return a.t < b.t end)
    return runs
end

function Match.first_blood(killfeed)
    if not killfeed then return nil end
    for _, k in ipairs(killfeed) do
        if k.kn and k.dn then return k end
    end
    return nil
end

local BALANCE_CONTESTED = 0.10
local BASE_RADIUS = 60
local RESPAWN_MS = 12000
local STOP_MS = 90000

function Match.balance(m)
    local tl = m and m.timeline
    if not tl or not tl.t or #tl.t < 4 or not m.battle then return nil end
    local n = #tl.t
    local series = { tl.s1, tl.s2, tl.s3 }
    local final = 0
    for s = 1, 3 do
        local v = (series[s] and series[s][n]) or 0
        if v > final then final = v end
    end
    local sumMargin, contested, decided, leader, changed = 0, 0, 0, nil, false
    for i = 1, n do
        local best, second, bestS = 0, 0, nil
        for s = 1, 3 do
            local v = (series[s] and series[s][i]) or 0
            if v > best then
                second = best
                best, bestS = v, s
            elseif v > second then
                second = v
            end
        end
        local margin = (final > 0) and (best - second) / final or 0
        sumMargin = sumMargin + margin
        if margin < BALANCE_CONTESTED then contested = contested + 1 end
        if i > 1 and tl.r and tl.r[i] ~= tl.r[i - 1] then leader = nil end
        if bestS and best > second then
            if leader and bestS ~= leader then
                decided = tl.t[i]
                changed = true
            end
            leader = bestS
        end
    end
    local kills, teams, kmin, kmax = {}, 0, nil, 0
    for _, r in ipairs(m.battle) do
        local t = r.team or 0
        if t ~= 0 then kills[t] = (kills[t] or 0) + (r.kills or 0) end
    end
    for _, k in pairs(kills) do
        teams = teams + 1
        if k > kmax then kmax = k end
        if kmin == nil or k < kmin then kmin = k end
    end
    local ratio = (kmax > 0) and (kmin or 0) / kmax or 1
    local margin = sumMargin / n
    local cont = contested / n
    local tspan = tl.t[n] or 0
    local score = math.floor(100 * (ratio + (1 - margin) + cont) / 3 + 0.5)
    local mine = m.localTeam
    local myKills = mine and kills[mine] or nil
    local other, otherKills = nil, -1
    for t, k in pairs(kills) do
        if t ~= mine and k > otherKills then other, otherKills = t, k end
    end
    local lean, leanTeam = 0, nil
    if myKills and other and myKills ~= otherKills then
        leanTeam = (myKills > otherKills) and mine or other
        lean = (1 - score / 100) * ((myKills > otherKills) and 1 or -1)
    elseif not myKills and other then
        leanTeam = other
        lean = -(1 - score / 100)
    end
    return {
        score = score,
        killRatio = ratio, margin = margin, contested = cont,
        decidedMs = decided, decidedPct = (tspan > 0) and decided / tspan or 0,
        leaderChanged = changed, teams = teams, tspan = tspan,
        lean = lean, leanTeam = leanTeam, mine = mine, other = other,
    }
end

function Match.experience(m)
    if not m or not m.battle then return nil end
    local teams, any = {}, false
    for _, r in ipairs(m.battle) do
        local t = r.team or 0
        if t ~= 0 then
            local e = teams[t]
            if not e then
                e = { team = t, n = 0, seen = 0, vet = 0, ava = 0, vetN = 0, avaN = 0 }
                teams[t] = e
            end
            e.n = e.n + 1
            if r.vet or r.ava then e.seen = e.seen + 1; any = true end
            if r.vet then e.vet = e.vet + r.vet; e.vetN = e.vetN + 1 end
            if r.ava then e.ava = e.ava + r.ava; e.avaN = e.avaN + 1 end
        end
    end
    if not any then return nil end
    for _, e in pairs(teams) do
        e.vetAvg = (e.vetN > 0) and e.vet / e.vetN or nil
        e.avaAvg = (e.avaN > 0) and e.ava / e.avaN or nil
    end
    local mine = m.localTeam and teams[m.localTeam] or nil
    local others = {}
    for t, e in pairs(teams) do
        if t ~= m.localTeam then others[#others + 1] = e end
    end
    table.sort(others, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.team < b.team
    end)
    return { mine = mine, other = others[1], third = others[2], others = others, teams = teams }
end

local function median_of(vals)
    local n = #vals
    if n == 0 then return nil end
    table.sort(vals)
    return vals[math.ceil(n / 2)]
end

function Match.spawn_point(m, geo)
    local me = geo and geo.me
    if not me or me.n < 1 then return nil end
    local xs, ys = {}, {}
    if (me.x[1] or 0) > 0 or (me.y[1] or 0) > 0 then xs[1], ys[1] = me.x[1], me.y[1] end
    for _, k in ipairs(m and m.killfeed or {}) do
        if k.kind == "death" then
            local target = k.t + RESPAWN_MS
            local idx = Match.geo_index_of(me.t, me.n, target)
            if (me.t[idx] or 0) < target then idx = idx + 1 end
            if idx <= me.n and ((me.x[idx] or 0) > 0 or (me.y[idx] or 0) > 0) then
                xs[#xs + 1], ys[#ys + 1] = me.x[idx], me.y[idx]
            end
        end
    end
    local x, y = median_of(xs), median_of(ys)
    if not x then return nil end
    return { x = x, y = y, samples = #xs }
end

function Match.in_play(m, t)
    local runs = m and m.runs
    if not runs or #runs == 0 then return true end
    for _, r in ipairs(runs) do
        if t >= (r.a or 0) and (r.b == nil or t <= r.b) then return true end
    end
    return false
end

function Match.surrender(m, geo)
    if not m then return nil end
    local out = { spawn = nil, base = nil, stopped = { n = 0, of = 0, at = nil } }
    local spawn = Match.spawn_point(m, geo)
    if spawn and geo then
        out.spawn = spawn
        local near, total, mineNear, mineTotal = 0, 0, 0, 0
        local startT = geo.startT or 0
        for nm, s in pairs(geo.pos) do
            if geo.team[nm] == m.localTeam or nm == geo.mine then
                for i = 1, geo.n do
                    local x, y = s.x[i], s.y[i]
                    local t = geo.t[i] or 0
                    if x and y and (x > 0 or y > 0) and t >= startT and Match.in_play(m, t) then
                        total = total + 1
                        local dx, dy = x - spawn.x, y - spawn.y
                        local isNear = (dx * dx + dy * dy) <= BASE_RADIUS * BASE_RADIUS
                        if isNear then near = near + 1 end
                        if nm == geo.mine then
                            mineTotal = mineTotal + 1
                            if isNear then mineNear = mineNear + 1 end
                        end
                    end
                end
            end
        end
        if total > 0 then
            out.base = { pct = near / total, mine = (mineTotal > 0) and mineNear / mineTotal or 0, samples = total }
        end
    end
    local tl = m.timeline
    if tl and tl.p and tl.t and #tl.t >= 2 then
        local n = #tl.t
        local tspan = tl.t[n] or 0
        local team_of = {}
        for _, r in ipairs(m.battle or {}) do
            local nm = r.displayName or r.charName
            if nm then team_of[(nm:gsub("%^.*$", ""))] = r.team end
        end
        local st = out.stopped
        for nm, rec in pairs(tl.p) do
            local team = team_of[nm] or rec.tm
            if team and team == m.localTeam then
                local d = rec.d or Match.unpack_series(rec.s, n)
                local last = 0
                if (d[1] or 0) > 0 then last = 1 end
                for i = 2, n do
                    if (d[i] or 0) > (d[i - 1] or 0) then last = i end
                end
                if last > 0 then
                    st.of = st.of + 1
                    local at = tl.t[last] or 0
                    if tspan - at >= STOP_MS then
                        st.n = st.n + 1
                        if not st.at or at < st.at then st.at = at end
                    end
                end
            end
        end
    end
    return out
end

BGMeter.Match = Match
