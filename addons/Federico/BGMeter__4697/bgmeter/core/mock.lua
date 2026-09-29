BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Mock = {}
BGMeter.Mock = Mock

local ROSTER = {
    "Velladocuments", "@StormLord", "Shadowmend", "Brakka gro-Mug",
    "Lyra Heartwood", "@FrostCaller", "Dro-mathra", "@HealBot",
    "@NightAxe", "Serenna Vox", "@Kagouti", "Tullius Rane",
    "@BogBlossom", "Yrsa Frost", "@PortalMonk", "Vexara",
    "@Ashfall", "Nerien'eth Vale",
}

local function rev(map, label)
    for k, v in pairs(map) do
        if v == label then return k end
    end
    return nil
end

local function jit(i, a, b)
    local x = math.sin(i * 12.9898) * 43758.5453
    local f = x - math.floor(x)
    return math.floor(a + f * (b - a))
end

local function make_rows(m, n, teams, tracker)
    local Match = BGMeter.Match
    for i = 1, n do
        local r = Match.new_row()
        r.displayName = ROSTER[i]
        r.isLocal = (i == 5)
        r.team = teams[((i - 1) % #teams) + 1]
        r.damage  = jit(i, 40000, 420000)
        r.healing = (i % 4 == 0) and jit(i + 30, 180000, 700000) or jit(i + 60, 2000, 90000)
        r.taken   = math.floor(r.damage * 0.6)
        r.kills, r.deaths, r.assists = jit(i + 1, 0, 12), jit(i + 2, 1, 9), jit(i + 3, 2, 20)
        r.score  = (r.kills * 400) + jit(i + 4, 0, 2500)
        r.medals = jit(i + 5, 2, 18)
        if tracker then tracker(r, i) end
        m.battle[#m.battle + 1] = r
    end
end

local function make_timeline(m, teams, dur, rounds, top1, top2, step, top3)
    local tl = { t = {}, r = {}, s1 = {}, s2 = {}, s3 = {}, teams = teams }
    local n = 72
    for i = 1, n do
        local p = i / n
        local rnd = math.min(rounds, math.floor(p * rounds) + 1)
        local rp = (p * rounds) - (rnd - 1)
        tl.t[i] = math.floor(p * dur)
        tl.r[i] = rnd
        if step then
            tl.s1[i] = math.floor(top1 * (p * 0.92) / step + 0.001) * step
            tl.s2[i] = math.floor(top2 * p / step + 0.001) * step
            tl.s3[i] = top3 and math.floor(top3 * (p * 0.97) / step + 0.001) * step or 0
        else
            tl.s1[i] = math.floor(top1 * rp * (0.85 + 0.15 * math.sin(p * 9)))
            tl.s2[i] = math.floor(top2 * rp * (0.90 + 0.10 * math.sin(3 + p * 7)))
            tl.s3[i] = top3 and math.floor(top3 * rp * (0.88 + 0.12 * math.sin(5 + p * 8))) or 0
        end
    end
    m.timeline = tl
end

local function make_killfeed(m, dur, teams, bias)
    m.killfeed = {}
    local n = math.min(#m.battle, #ROSTER)
    for i = 1, 34 do
        local ki = jit(i + 200, 1, n)
        if bias and teams[bias] and jit(i + 500, 0, 100) < 74 then
            local tries = 0
            while m.battle[ki].team ~= teams[bias] and tries < 8 do
                ki = (ki % n) + 1
                tries = tries + 1
            end
        end
        local di = ((ki + jit(i + 300, 0, n - 2)) % n) + 1
        local kr, dr = m.battle[ki], m.battle[di]
        if kr and dr and kr.team ~= dr.team then
            local kind
            if kr.isLocal then kind = "kill" elseif dr.isLocal then kind = "death" end
            m.killfeed[#m.killfeed + 1] = {
                t = math.floor(dur * i / 36), kind = kind,
                kn = kr.displayName, kt = kr.team,
                dn = dr.displayName, dt = dr.team,
            }
        end
    end
end

local function make_objectives(m, flags, script)
    local CZ = BGMeter.zenimax.constants
    local ob = { list = {}, t = {}, r = {}, o = {}, ev = {}, st = {}, own = {} }
    for i, f in ipairs(flags) do
        ob.list[i] = { letter = f[1], name = f[2], keepId = 0, objectiveId = 550 + i }
    end
    for _, e in ipairs(script) do
        local i = #ob.t + 1
        ob.t[i], ob.r[i], ob.o[i] = e[1], 1, e[2]
        ob.ev[i] = (e[3] == -1) and -1 or (rev(CZ.OBJ_EVENT_LABEL, e[3]) or -1)
        ob.st[i], ob.own[i] = -1, e[4]
    end
    m.objectives = ob
end

local function make_relics(m, list, script)
    local CZ = BGMeter.zenimax.constants
    local rl = { list = {}, t = {}, r = {}, o = {}, ev = {}, hold = {}, last = {}, who = {} }
    for i, e in ipairs(list) do
        rl.list[i] = { keepId = 0, objectiveId = 520 + i, name = e.name, home = e.home }
    end
    table.sort(script, function(a, z) return a[1] < z[1] end)
    for _, e in ipairs(script) do
        local i = #rl.t + 1
        rl.t[i], rl.r[i], rl.o[i] = e[1], 1, e[2]
        rl.ev[i] = rev(CZ.OBJ_EVENT_LABEL, e[3]) or -1
        rl.hold[i], rl.last[i] = e[4] or 0, e[5] or 0
        rl.who[i] = e[6]
    end
    m.relics = rl
end

local function relic_run(script, o, tTake, holdSec, team, outcome, who)
    script[#script + 1] = { tTake * 1000, o, "flag_taken", team, 0 }
    local tEnd = (tTake + holdSec) * 1000
    if outcome == "goal" then
        script[#script + 1] = { tEnd, o, "captured", 0, team, who }
        script[#script + 1] = { tEnd + 20000, o, "flag_spawned", 0, team }
    else
        script[#script + 1] = { tEnd, o, "flag_dropped", 0, team }
        script[#script + 1] = { tEnd + 5000, o, "flag_returned", 0, team }
        script[#script + 1] = { tEnd + 5000, o, "flag_spawned", 0, team }
    end
end

local function flag_cycle(script, o, t0, own1, own2)
    local s = function(dt, ev, own) script[#script + 1] = { t0 + dt, o, ev, own } end
    s(0,      "neutral",            0)
    s(6000,   "lost",               own1)
    s(12000,  "captured",           own1)
    s(20000,  "fully_held",         own1)
    s(34000,  "under_attack",       own1)
    s(40000,  "assaulted",          own1)
    s(41000,  "neutral",            0)
    s(45000,  "lost",               own2)
    s(52000,  "captured",           own2)
    s(58000,  "captured",           own2)
    s(64000,  "deactivate_pending", own2)
    s(74000,  "deactivated",        0)
end

local function finish(m, mode)
    local Match = BGMeter.Match
    local A = BGMeter.zenimax.api
    m.capturedAt = (type(A.get_timestamp) == "function") and A.get_timestamp() or 0
    local medalIds = BGMeter.Icons.scan_medal_ids(300, 6)
    local lr = Match.local_row(m)
    if lr and #medalIds > 0 then
        lr.medalIds, lr.medalCounts = medalIds, {}
        local total = 0
        for i, id in ipairs(medalIds) do
            local c = (i % 3 == 0) and 3 or 1
            lr.medalCounts[id] = c
            total = total + c
        end
        lr.medals = total
    end
    m.haul.apGained, m.haul.xpGained, m.haul.cpGained, m.haul.medals = 9800, 41200, 1, lr and lr.medals or 6
    m.haul.vetStart = { rank = 14, tier = 14, percent = 0.73, progressToNext = 3650, tierTotal = 5000, seasonName = "Whitestrake's Mayhem", secondsLeft = 387600, inZone = true }
    m.haul.vetEnd   = { rank = 14, tier = 14, percent = 0.79, progressToNext = 3950, tierTotal = 5000, rankTitle = "Veteran Lieutenant", seasonName = "Whitestrake's Mayhem", secondsLeft = 387600, inZone = true }
    Match.derive(m)
    if m.competitive then
        m.standing = { rank = 214, prevRank = 221, rankDelta = 7, score = 5350, prevScore = 5105, scoreDelta = 245, mmr = 1580, impacts = true }
    end
    BGMeter.Session.record(m)
    BGMeter.History.push(m)
    BGMeter.UI.window.show_match(1)
    if m.result == "WIN" then BGMeter.Sound.play("win") end
    BGMeter.Log.say("mock %s injected -- %d players, %s, %s",
        mode, #m.battle, m.competitive and "competitive" or "casual", m.result)
end

local BUILDERS = {}

function BUILDERS.deathmatch()
    local CZ = BGMeter.zenimax.constants
    local m = BGMeter.Match.new()
    local teams = { CZ.BATTLEGROUND_TEAM_FIRE_DRAKES, CZ.BATTLEGROUND_TEAM_PIT_DAEMONS }
    m.name, m.result = "Foyada Quarry DM", "WIN"
    m.gameType = rev(CZ.GAME_TYPE_LABEL, "deathmatch")
    m.teamSize, m.competitive = 4, true
    m.localTeam = teams[1]
    m.startMs, m.endMs = 0, 12 * 60000
    m.numRounds = 3
    m.teams = {
        { team = teams[1], score = 500, roundsWon = 2 },
        { team = teams[2], score = 500, roundsWon = 1 },
    }
    make_rows(m, 8, teams)
    make_timeline(m, teams, 12 * 60000, 3, 500, 460)
    make_killfeed(m, 12 * 60000, teams)
    finish(m, "deathmatch")
end

function BUILDERS.domination()
    local CZ = BGMeter.zenimax.constants
    local m = BGMeter.Match.new()
    local teams = { CZ.BATTLEGROUND_TEAM_FIRE_DRAKES, CZ.BATTLEGROUND_TEAM_PIT_DAEMONS }
    m.name, m.result = "Istirus Outpost DOM", "WIN"
    m.gameType = rev(CZ.GAME_TYPE_LABEL, "domination")
    m.teamSize, m.competitive = 4, true
    m.localTeam = teams[1]
    m.startMs, m.endMs = 0, 13 * 60000
    m.numRounds = 1
    m.teams = {
        { team = teams[1], score = 512, roundsWon = 0 },
        { team = teams[2], score = 430, roundsWon = 0 },
    }
    make_rows(m, 8, teams, function(r, i)
        r.caps   = jit(i + 70, 0, 13)
        r.defPts = r.caps * jit(i + 80, 30, 60)
    end)
    make_timeline(m, teams, 13 * 60000, 1, 512, 430)
    make_killfeed(m, 13 * 60000, teams)
    local script = {}
    local flip = { { 90, 1 }, { 150, 2 }, { 260, 1 }, { 300, 2 }, { 420, 1 }, { 540, 2 }, { 620, 1 } }
    for fi, flag in ipairs({ "West Flag", "East Flag" }) do
        local s = function(t, ev, own) script[#script + 1] = { t * 1000, fi, ev, own } end
        s(54 + fi * 4, "neutral", 0)
        for k, e in ipairs(flip) do
            local own = (fi == 2) and (3 - e[2]) or e[2]
            s(e[1] + fi * 6,      "lost",       own)
            s(e[1] + fi * 6 + 8,  "captured",   own)
            s(e[1] + fi * 6 + 16, "fully_held", own)
            if k % 3 == 0 then s(e[1] + fi * 6 + 30, "captured", own) end
        end
    end
    table.sort(script, function(a, z) return a[1] < z[1] end)
    make_objectives(m, { { "A", "West Flag" }, { "B", "East Flag" } }, script)
    finish(m, "domination")
end

function BUILDERS.crazy_king()
    local CZ = BGMeter.zenimax.constants
    local m = BGMeter.Match.new()
    local teams = { CZ.BATTLEGROUND_TEAM_FIRE_DRAKES, CZ.BATTLEGROUND_TEAM_PIT_DAEMONS }
    m.name, m.result = "City CK 50", "LOSS"
    m.gameType = rev(CZ.GAME_TYPE_LABEL, "crazy_king")
    m.teamSize, m.competitive = 8, false
    m.localTeam = teams[1]
    m.startMs, m.endMs = 0, 11 * 60000
    m.numRounds = 1
    m.teams = {
        { team = teams[1], score = 411, roundsWon = 0 },
        { team = teams[2], score = 500, roundsWon = 0 },
    }
    make_rows(m, 16, teams, function(r, i)
        r.caps   = jit(i + 90, 0, 11)
        r.defPts = r.caps * jit(i + 95, 25, 55)
    end)
    make_timeline(m, teams, 11 * 60000, 1, 411, 500)
    make_killfeed(m, 11 * 60000, teams)
    local flags = {
        { "A", "Central Plaza Flag" }, { "D", "Fire Drake Plaza Flag" },
        { "C", "Pit Daemon Plaza Flag" }, { "B", "Church Plaza Flag" },
        { "A", "West Alley Flag" }, { "D", "South Alley Flag" },
        { "C", "Market Plaza Flag" }, { "B", "Dufort Inn Flag" },
    }
    local script = {}
    for o = 1, #flags do
        local own1 = (o % 2 == 0) and 2 or 1
        flag_cycle(script, o, 55000 + (o - 1) * 76000, own1, 3 - own1)
    end
    flag_cycle(script, 1, 500000, 2, 1)
    flag_cycle(script, 2, 300000, 1, 2)
    table.sort(script, function(a, z) return a[1] < z[1] end)
    make_objectives(m, flags, script)
    finish(m, "crazy king")
end

function BUILDERS.murderball()
    local CZ = BGMeter.zenimax.constants
    local m = BGMeter.Match.new()
    local teams = { CZ.BATTLEGROUND_TEAM_FIRE_DRAKES, CZ.BATTLEGROUND_TEAM_PIT_DAEMONS }
    m.name, m.result = "City Streets Chaosball", "WIN"
    m.gameType = rev(CZ.GAME_TYPE_LABEL, "murderball")
    m.teamSize, m.competitive = 8, false
    m.localTeam = teams[1]
    m.startMs, m.endMs = 0, 10 * 60000
    m.numRounds = 1
    m.teams = {
        { team = teams[1], score = 500, roundsWon = 0 },
        { team = teams[2], score = 377, roundsWon = 0 },
    }
    make_rows(m, 16, teams, function(r, i)
        if i == 7 then
            r.carried, r.caps, r.carrierKills = 0, 0, 8
        else
            r.carried = jit(i + 100, 0, 240)
            r.caps = math.floor(r.carried * (0.8 + (i % 5) * 0.12))
            r.carrierKills = jit(i + 110, 0, 3)
        end
    end)
    make_timeline(m, teams, 10 * 60000, 1, 500, 377)
    make_killfeed(m, 10 * 60000, teams)
    local balls = { { name = "Chaosball" }, { name = "Chaosball" }, { name = "Chaosball" } }
    local carriers = {
        { "Velladocuments", "Shadowmend", "Lyra Heartwood", "@NightAxe" },
        { "@StormLord", "Brakka gro-Mug", "@FrostCaller", "Serenna Vox" },
    }
    local script = {}
    for o = 1, 3 do
        local t = 22000 + o * 4000
        script[#script + 1] = { t - 3000, o, "flag_spawned", 0, 0 }
        local ti = (o % 2 == 0) and 2 or 1
        while t < 560000 do
            local hold = jit(o * 100 + t, 18, 65) * 1000
            local tm = teams[ti]
            local who = carriers[ti][jit(o * 400 + t, 1, 5)]
            script[#script + 1] = { t, o, "flag_taken", tm, 0, who }
            script[#script + 1] = { t + hold, o, "flag_dropped", 0, tm }
            local loose = jit(o * 200 + t, 4, 22) * 1000
            script[#script + 1] = { t + hold + loose, o, "flag_timer_return", 0, tm }
            t = t + hold + loose + jit(o * 300 + t, 3, 14) * 1000
            ti = 3 - ti
        end
    end
    make_relics(m, balls, script)
    finish(m, "chaosball")
end

function BUILDERS.capture_the_flag()
    local CZ = BGMeter.zenimax.constants
    local m = BGMeter.Match.new()
    local teams = { CZ.BATTLEGROUND_TEAM_FIRE_DRAKES, CZ.BATTLEGROUND_TEAM_PIT_DAEMONS }
    m.name, m.result = "Sewer CTF 50", "LOSS"
    m.gameType = rev(CZ.GAME_TYPE_LABEL, "capture_the_flag")
    m.teamSize, m.competitive = 8, false
    m.localTeam = teams[1]
    m.startMs, m.endMs = 0, math.floor(14.6 * 60000)
    m.numRounds = 1
    m.teams = {
        { team = teams[1], score = 200, roundsWon = 0 },
        { team = teams[2], score = 500, roundsWon = 0 },
    }
    local capsPlan = { [2] = 300, [4] = 100, [6] = 100, [9] = 100, [13] = 100 }
    make_rows(m, 16, teams, function(r, i)
        r.caps = capsPlan[i] or 0
        r.carried = (r.caps > 0) and jit(i + 120, 40, 430) or ((i % 4 == 1) and jit(i + 130, 0, 150) or 0)
        r.carrierKills = (i % 6 == 0) and jit(i + 140, 1, 2) or 0
    end)
    make_timeline(m, teams, math.floor(14.6 * 60000), 1, 200, 500, 100)
    make_killfeed(m, math.floor(14.6 * 60000), teams, 1)
    local relics = {
        { name = "Fire Drakes Relic", home = teams[1] },
        { name = "Pit Daemons Relic", home = teams[2] },
    }
    local script = {}
    relic_run(script, 1, 109, 279, teams[2], "stopped")
    relic_run(script, 1, 401, 50,  teams[2], "goal", "@StormLord")
    relic_run(script, 1, 487, 103, teams[2], "goal", "@StormLord")
    relic_run(script, 1, 615, 21,  teams[2], "goal", "Brakka gro-Mug")
    relic_run(script, 1, 661, 25,  teams[2], "goal", "@FrostCaller")
    relic_run(script, 1, 862, 15,  teams[2], "goal", "@StormLord")
    relic_run(script, 2, 117, 260, teams[1], "stopped")
    relic_run(script, 2, 460, 45,  teams[1], "goal", "@NightAxe")
    relic_run(script, 2, 700, 30,  teams[1], "goal", "@BogBlossom")
    relic_run(script, 2, 800, 30,  teams[1], "stopped")
    make_relics(m, relics, script)
    finish(m, "capture the relic")
end

local TRI = {}

local function tri_base(name, gt, dur, scores)
    local CZ = BGMeter.zenimax.constants
    local Match = BGMeter.Match
    local m = Match.new()
    local teams = { CZ.BATTLEGROUND_TEAM_FIRE_DRAKES, CZ.BATTLEGROUND_TEAM_PIT_DAEMONS, CZ.BATTLEGROUND_TEAM_STORM_LORDS }
    m.name = name
    m.gameType = rev(CZ.GAME_TYPE_LABEL, gt)
    m.teamSize, m.competitive, m.numTeams = 6, false, 3
    m.startMs, m.endMs = 0, dur
    m.numRounds = 1
    m.teams = {}
    for i = 1, 3 do m.teams[i] = { team = teams[i], score = scores[i], roundsWon = 0 } end
    return m, teams
end

local function tri_close(m, teams, mode)
    local lr = BGMeter.Match.local_row(m)
    m.localTeam = lr and lr.team or teams[1]
    local best = 0
    for i = 1, 3 do if m.teams[i].score > best then best = m.teams[i].score end end
    local mine = 0
    for i = 1, 3 do if m.teams[i].team == m.localTeam then mine = m.teams[i].score end end
    m.result = (mine >= best) and "WIN" or "LOSS"
    finish(m, mode)
end

function TRI.deathmatch()
    local dur = 12 * 60000
    local m, teams = tri_base("Foyada Quarry TDM", "deathmatch", dur, { 500, 431, 377 })
    make_rows(m, 18, teams)
    make_timeline(m, teams, dur, 1, 500, 431, nil, 377)
    make_killfeed(m, dur, teams)
    tri_close(m, teams, "deathmatch 6v6v6")
end

function TRI.domination()
    local dur = 13 * 60000
    local m, teams = tri_base("Istirus Outpost DOM", "domination", dur, { 412, 500, 366 })
    make_rows(m, 18, teams, function(r, i)
        r.caps   = jit(i + 70, 0, 11)
        r.defPts = r.caps * jit(i + 80, 30, 60)
    end)
    make_timeline(m, teams, dur, 1, 412, 500, nil, 366)
    make_killfeed(m, dur, teams)
    local script = {}
    local flags = { { "A", "North Flag" }, { "B", "East Flag" }, { "C", "South Flag" } }
    for fi = 1, 3 do
        local s = function(t, ev, own) script[#script + 1] = { t * 1000, fi, ev, own } end
        s(50 + fi * 4, "neutral", 0)
        local own = fi
        for k = 1, 7 do
            local t = 60 + (k - 1) * 100 + fi * 7
            s(t,      "lost",       own)
            s(t + 8,  "captured",   own)
            s(t + 16, "fully_held", own)
            own = (own % 3) + 1
        end
    end
    table.sort(script, function(a, z) return a[1] < z[1] end)
    make_objectives(m, flags, script)
    tri_close(m, teams, "domination 6v6v6")
end

function TRI.crazy_king()
    local dur = 11 * 60000
    local m, teams = tri_base("Deeping Drome CK", "crazy_king", dur, { 388, 500, 455 })
    make_rows(m, 18, teams, function(r, i)
        r.caps   = jit(i + 90, 0, 9)
        r.defPts = r.caps * jit(i + 95, 25, 55)
    end)
    make_timeline(m, teams, dur, 1, 388, 500, nil, 455)
    make_killfeed(m, dur, teams)
    local flags = {
        { "A", "Ruined Gate Flag" }, { "B", "Cistern Flag" }, { "C", "Drome Floor Flag" },
        { "A", "Balcony Flag" }, { "B", "Sluice Flag" }, { "C", "Stairwell Flag" },
    }
    local script = {}
    for o = 1, #flags do
        local own1 = ((o - 1) % 3) + 1
        flag_cycle(script, o, 55000 + (o - 1) * 76000, own1, (own1 % 3) + 1)
    end
    flag_cycle(script, 1, 520000, 3, 2)
    flag_cycle(script, 2, 300000, 2, 3)
    table.sort(script, function(a, z) return a[1] < z[1] end)
    make_objectives(m, flags, script)
    tri_close(m, teams, "crazy king 6v6v6")
end

function TRI.murderball()
    local dur = 10 * 60000
    local m, teams = tri_base("City Streets Chaosball", "murderball", dur, { 500, 402, 318 })
    make_rows(m, 18, teams, function(r, i)
        r.carried = jit(i + 100, 0, 200)
        r.caps = math.floor(r.carried * (0.8 + (i % 5) * 0.12))
        r.carrierKills = jit(i + 110, 0, 3)
    end)
    make_timeline(m, teams, dur, 1, 500, 402, nil, 318)
    make_killfeed(m, dur, teams)
    local balls = { { name = "Chaosball" }, { name = "Chaosball" }, { name = "Chaosball" } }
    local carriers = {
        { "Velladocuments", "Brakka gro-Mug", "Dro-mathra", "Serenna Vox", "@BogBlossom", "Vexara" },
        { "@StormLord", "Lyra Heartwood", "@HealBot", "@Kagouti", "Yrsa Frost", "@Ashfall" },
        { "Shadowmend", "@FrostCaller", "@NightAxe", "Tullius Rane", "@PortalMonk", "Nerien'eth Vale" },
    }
    local script = {}
    for o = 1, 3 do
        local t = 22000 + o * 4000
        script[#script + 1] = { t - 3000, o, "flag_spawned", 0, 0 }
        local ti = o
        while t < 560000 do
            local hold = jit(o * 100 + t, 18, 65) * 1000
            local tm = teams[ti]
            local who = carriers[ti][jit(o * 400 + t, 1, 7)]
            script[#script + 1] = { t, o, "flag_taken", tm, 0, who }
            script[#script + 1] = { t + hold, o, "flag_dropped", 0, tm }
            local loose = jit(o * 200 + t, 4, 22) * 1000
            script[#script + 1] = { t + hold + loose, o, "flag_timer_return", 0, tm }
            t = t + hold + loose + jit(o * 300 + t, 3, 14) * 1000
            ti = (ti % 3) + 1
        end
    end
    make_relics(m, balls, script)
    tri_close(m, teams, "chaosball 6v6v6")
end

function TRI.capture_the_flag()
    local dur = math.floor(14.6 * 60000)
    local m, teams = tri_base("Sewer CTF", "capture_the_flag", dur, { 300, 500, 200 })
    local capsPlan = { [2] = 200, [4] = 100, [6] = 100, [9] = 100, [13] = 100, [17] = 100, [3] = 100, [7] = 200 }
    make_rows(m, 18, teams, function(r, i)
        r.caps = capsPlan[i] or 0
        r.carried = (r.caps > 0) and jit(i + 120, 40, 430) or ((i % 4 == 1) and jit(i + 130, 0, 150) or 0)
        r.carrierKills = (i % 6 == 0) and jit(i + 140, 1, 2) or 0
    end)
    make_timeline(m, teams, dur, 1, 300, 500, 100, 200)
    make_killfeed(m, dur, teams, 2)
    local relics = {
        { name = "Fire Drakes Relic", home = teams[1] },
        { name = "Pit Daemons Relic", home = teams[2] },
        { name = "Storm Lords Relic", home = teams[3] },
    }
    local script = {}
    relic_run(script, 1, 109, 60,  teams[2], "goal", "@StormLord")
    relic_run(script, 1, 401, 50,  teams[3], "goal", "Shadowmend")
    relic_run(script, 1, 615, 21,  teams[2], "stopped")
    relic_run(script, 2, 117, 80,  teams[1], "goal", "@NightAxe")
    relic_run(script, 2, 460, 45,  teams[3], "goal", "@FrostCaller")
    relic_run(script, 2, 700, 30,  teams[1], "stopped")
    relic_run(script, 3, 150, 70,  teams[2], "goal", "@StormLord")
    relic_run(script, 3, 330, 40,  teams[2], "goal", "Brakka gro-Mug")
    relic_run(script, 3, 520, 55,  teams[1], "goal", "Velladocuments")
    relic_run(script, 3, 760, 30,  teams[2], "stopped")
    make_relics(m, relics, script)
    tri_close(m, teams, "capture the relic 6v6v6")
end

local ALIAS = {
    dm = "deathmatch", deathmatch = "deathmatch",
    dom = "domination", domination = "domination",
    ck = "crazy_king", crazyking = "crazy_king", king = "crazy_king",
    ball = "murderball", chaosball = "murderball", murderball = "murderball", mb = "murderball",
    relic = "capture_the_flag", ctf = "capture_the_flag", flag = "capture_the_flag",
}

function Mock.run(arg)
    local a = (arg or ""):lower()
    local tri = a:match("^%s*tri") ~= nil
    if tri then a = a:gsub("^%s*tri", "") end
    local mode = ALIAS[a:gsub("%s+", "")]
    if not mode then
        BGMeter.Log.say("mock modes: dm  dom  ck  ball  relic  ·  three-sided: tri dm  tri dom  tri ck  tri ball  tri relic")
        return
    end
    if tri then TRI[mode]() else BUILDERS[mode]() end
end

local VET_PRESETS = {
    below = { rank = 37,  cur = 37,  prog = 120000, total = 168000, claimed = 0 },
    r34   = { rank = 34,  cur = 34,  prog = 12000,  total = 168000, claimed = 0, rewards = { [30] = 1, [34] = 2 }, unclaimed = { [30] = true, [34] = true } },
    cap   = { rank = 100, cur = 100, prog = 150000, total = 168000, claimed = 0 },
    h1    = { rank = 104, cur = 104, prog = 50627,  total = 168000, claimed = 3, claimable = 1 },
    h2    = { rank = 101, cur = 101, prog = 218527, total = 168000, claimed = 1, claimable = 0 },
    h3    = { rank = 101, cur = 101, prog = 50627,  total = 168000, claimed = 3, claimable = 2 },
}
local VET_ORDER = { "below", "r34", "cap", "h1", "h2", "h3" }
local vet_saved = nil

local function vet_install(p)
    local A = BGMeter.zenimax.api
    if not vet_saved then
        vet_saved = {}
        for _, k in ipairs({ "is_veterancy_season_active", "get_season_id", "get_season_name",
            "get_season_time_remaining", "is_in_veterancy_zone", "get_unit_veterancy_rank",
            "get_veterancy_rank_title", "get_active_ref_track_ids", "get_ref_track_index",
            "get_reward_track_id_from_ref", "get_info_for_reward_track", "get_tier_total_progress",
            "get_num_base_tiers", "has_repeatable_tier", "get_repeatable_tier", "get_repeatable_claimed",
            "get_num_rewards_at_tier", "get_reward_claimed_state", "has_unclaimed_rewards", "claim_all_rewards" }) do
            vet_saved[k] = A[k]
        end
    end
    A.is_veterancy_season_active = function() return true end
    A.get_season_id              = function() return 1 end
    A.get_season_name            = function() return "Mock Season" end
    A.get_season_time_remaining  = function() return 387600 end
    A.is_in_veterancy_zone       = function() return true end
    A.get_unit_veterancy_rank    = function() return p.rank end
    A.get_veterancy_rank_title   = function(r) return r >= 100 and "Sovereign" or ("Veteran " .. r) end
    A.get_active_ref_track_ids   = function() return 5 end
    A.get_ref_track_index        = function() return 1 end
    A.get_reward_track_id_from_ref = function() return 9 end
    A.get_info_for_reward_track  = function() return 9, p.cur, p.prog, 0 end
    A.get_tier_total_progress    = function(_, idx) return idx <= 101 and p.total or 0 end
    A.get_num_base_tiers         = function() return 100 end
    A.has_repeatable_tier        = function() return true end
    A.get_repeatable_tier        = function() return 101 end
    A.get_repeatable_claimed     = function() return p.claimed, p.claimable or 0 end
    A.get_num_rewards_at_tier    = function(_, tier) return (p.rewards and p.rewards[tier]) or 0 end
    A.get_reward_claimed_state   = function(_, _, tier) return not (p.unclaimed and p.unclaimed[tier]) end
    A.has_unclaimed_rewards      = function()
        if (p.claimable or 0) > 0 then return true end
        for _ in pairs(p.unclaimed or {}) do return true end
        return false
    end
    A.claim_all_rewards          = function()
        p.unclaimed = {}
        p.claimed = p.claimed + (p.claimable or 0)
        p.claimable = 0
        if BGMeter.UI and BGMeter.UI.panel then BGMeter.UI.panel.mark_vet_dirty() end
        if BGMeter.UI and BGMeter.UI.menu then BGMeter.UI.menu.refresh_if_visible() end
    end
end

local function vet_restore()
    if not vet_saved then return end
    local A = BGMeter.zenimax.api
    for k, fn in pairs(vet_saved) do A[k] = fn end
    vet_saved = nil
end

function Mock.vet(arg)
    local Log = BGMeter.Log
    local key = (arg or ""):lower():gsub("%s+", "")
    if key == "off" then
        vet_restore()
        if BGMeter.UI.menu then BGMeter.UI.menu.refresh() end
        Log.say("vetmock off -- live API restored")
        return
    end
    local p = VET_PRESETS[key]
    if not p then
        Log.say("vetmock presets: %s  off", table.concat(VET_ORDER, "  "))
        return
    end
    vet_install(p)
    local Vet = BGMeter.Veterancy
    local before = Vet.snapshot()
    local m = BGMeter.History.get(1)
    if m then
        m.haul.vetStart = before
        m.haul.vetEnd = Vet.snapshot()
        m.haul.vetRankUp = false
        BGMeter.UI.window.show_match(1)
    end
    if BGMeter.UI.panel then BGMeter.UI.panel.mark_vet_dirty() end
    if BGMeter.UI.menu then BGMeter.UI.menu.refresh() end
    Log.say("vetmock %s: rank=%d cur=%d prog=%s total=%s claimed=%d -> laps=%s within=%s pct=%.2f",
        key, p.rank, p.cur, tostring(p.prog), tostring(p.total), p.claimed,
        tostring(before.laps), tostring(before.progressToNext), before.percent or 0)
end

Mock.vet_presets = VET_PRESETS
