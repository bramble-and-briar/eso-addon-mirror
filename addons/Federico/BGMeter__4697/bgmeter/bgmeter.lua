
BGMeter = BGMeter or {}
local BGMeter = BGMeter

local K = BGMeter.Constants

local function cmd_dump()
    local A   = BGMeter.zenimax.api
    local Log = BGMeter.Log
    local F   = BGMeter.Format

    local ok, apiVer = pcall(A.get_api_version)
    if not ok then apiVer = "?" end
    Log.say("API %s  ·  BG active=%s  state=%s",
        tostring(apiVer), tostring(A.is_active_bg and A.is_active_bg() or "?"),
        tostring(A.get_bg_state and A.get_bg_state() or "?"))

    local m = BGMeter.Capture.snapshot_now()
    Log.say("%s  ·  %d players  ·  result=%s",
        tostring(m.name or "Battleground"), #m.battle, tostring(m.result or "—"))
    BGMeter.Match.sort(m, "damage", true)
    for i, r in ipairs(m.battle) do
        Log.say("  %d. %s  dmg=%s heal=%s  %d/%d/%d  pts=%s  medals=%d  caps=%d def=%d carry=%d fkill=%d%s",
            i, tostring(r.displayName or r.charName or "?"),
            F.abbrev(r.damage), F.abbrev(r.healing),
            r.kills, r.deaths, r.assists, F.abbrev(r.score), r.medals or 0,
            r.caps or 0, r.defPts or 0, r.carried or 0, r.carrierKills or 0,
            r.isLocal and "  <- you" or "")
    end

    local vet = m.haul.vetEnd
    if vet and vet.rank then
        Log.say("veterancy: rank=%s tier=%s pct=%.1f%%  season=%s  inZone=%s",
            tostring(vet.rank), tostring(vet.tier), (vet.percent or 0) * 100,
            tostring(vet.seasonName or "—"), tostring(vet.inZone))
    else
        Log.say("veterancy: no data (season inactive or not in a veterancy zone)")
    end
    Log.say("progression now: AP=%s  XP=%s/%s  CP=%s",
        F.commas(A.get_alliance_points() or 0),
        F.commas(A.get_unit_xp() or 0), F.commas(A.get_unit_xp_max() or 0),
        F.commas(A.get_cp_earned() or 0))

    if A.query_bg_leaderboard then
        pcall(A.query_bg_leaderboard, BGMeter.zenimax.constants.BATTLEGROUND_LEADERBOARD_TYPE_COMPETITIVE)
    end
    local st = BGMeter.Standing.read()
    Log.say("standing: rank=%s  score=%s  mmr=%s  impactsMMR=%s",
        st.rank > 0 and ("#" .. st.rank) or "unranked",
        tostring(st.score), tostring(st.mmr or "—"), tostring(st.impacts))
end

local function cmd_demo(two_teams)
    local Match = BGMeter.Match
    local A = BGMeter.zenimax.api
    local m = Match.new()
    m.name, m.gameType, m.result = two_teams and "Ularra Temple" or "Mournhold Sewers", nil, "WIN"
    m.startMs, m.endMs = 0, 14 * 60000
    m.localTeam = BGMeter.zenimax.constants.BATTLEGROUND_TEAM_FIRE_DRAKES
    m.capturedAt = (type(A.get_timestamp) == "function") and A.get_timestamp() or 0

    local sample = {
        { "Velladocuments",  412331, 38120,  9,  4, 12, 5, 3, true,  3, 2 },
        { "@StormLord",      390887,  2010, 11,  6,  7, 4, 1, false, 2, 0 },
        { "Shadowmend",      301044, 95210,  5,  3, 15, 6, 2, false, 1, 1 },
        { "Brakka gro-Mug",  288190, 14002,  8,  5,  6, 3, 0, false, 2, 1 },
        { "Lyra Heartwood",  150220, 188400, 2,  2, 19, 7, 2, false, 1, 0 },
        { "@FrostCaller",    260110,  9100,  7,  7,  5, 2, 0, false, 0, 3 },
        { "Dro-mathra",      198320, 22110,  4,  8,  9, 1, 0, false, 1, 0 },
        { "@HealBot",         54000, 240300, 1,  1, 22, 8, 4, false, 0, 2 },
    }
    local C = BGMeter.zenimax.constants
    local teams = { C.BATTLEGROUND_TEAM_FIRE_DRAKES, C.BATTLEGROUND_TEAM_PIT_DAEMONS, C.BATTLEGROUND_TEAM_STORM_LORDS }
    local nteams = two_teams and 2 or 3
    for i, s in ipairs(sample) do
        local r = Match.new_row()
        r.displayName, r.damage, r.healing = s[1], s[2], s[3]
        r.taken = math.floor(s[2] * 0.55)
        r.kills, r.deaths, r.assists, r.score, r.medals = s[4], s[5], s[6], s[7] * 1000, s[8]
        r.isLocal = s[9]
        r.caps, r.defPts = s[10], s[11]
        r.team = teams[((i - 1) % nteams) + 1]
        m.battle[#m.battle + 1] = r
    end

    m.numRounds = two_teams and 3 or 1
    m.teams = {
        { team = teams[1], score = 512, roundsWon = two_teams and 2 or 0 },
        { team = teams[2], score = 430, roundsWon = two_teams and 1 or 0 },
    }
    if not two_teams then
        m.teams[3] = { team = teams[3], score = 381, roundsWon = 0 }
    end

    m.timeline = { t = {}, r = {}, s1 = {}, s2 = {}, s3 = {}, teams = teams }
    for i = 1, 60 do
        local p = i / 60
        m.timeline.t[i]  = math.floor(p * 14 * 60000)
        m.timeline.r[i]  = 1
        m.timeline.s1[i] = math.floor(512 * p * (0.85 + 0.15 * math.sin(p * 9)))
        m.timeline.s2[i] = math.floor(430 * p * (0.90 + 0.10 * math.sin(3 + p * 7)))
        m.timeline.s3[i] = two_teams and 0 or math.floor(381 * p * (0.88 + 0.12 * math.sin(1.5 + p * 11)))
    end

    m.killfeed = {}
    local function pushk(t, kind, kn, kt, dn, dt)
        m.killfeed[#m.killfeed + 1] = { t = t, kind = kind, kn = kn, kt = kt, dn = dn, dt = dt }
    end
    local ME, ENEMY = teams[1], teams[2]
    pushk(42000,  "kill",  "Velladocuments", ME,    "@FrostCaller",   ENEMY)
    pushk(85000,  nil,     "@StormLord",     ENEMY, "Dro-mathra",     ME)
    pushk(91000,  nil,     "@StormLord",     ENEMY, "@HealBot",       ME)
    pushk(98000,  nil,     "@StormLord",     ENEMY, "Lyra Heartwood", ME)
    pushk(130000, "death", "@StormLord",     ENEMY, "Velladocuments", ME)
    pushk(180000, "kill",  "Velladocuments", ME,    "@FrostCaller",   ENEMY)
    pushk(260000, "death", "@StormLord",     ENEMY, "Velladocuments", ME)
    pushk(420000, nil,     "Brakka gro-Mug", ME,    "Shadowmend",     ENEMY)
    pushk(425000, nil,     "@FrostCaller",   ENEMY, "Brakka gro-Mug", ME)
    pushk(432000, "kill",  "Velladocuments", ME,    "@FrostCaller",   ENEMY)
    pushk(438000, nil,     "Dro-mathra",     ME,    "@StormLord",     ENEMY)
    pushk(510000, "death", "@StormLord",     ENEMY, "Velladocuments", ME)
    pushk(600000, "kill",  "Velladocuments", ME,    "@FrostCaller",   ENEMY)

    do
        local CZ = BGMeter.zenimax.constants
        local function ev_id(label)
            for k, v in pairs(CZ.OBJ_EVENT_LABEL) do
                if v == label then return k end
            end
            return -1
        end
        local CAP, NEU = ev_id("captured"), ev_id("neutral")
        local ob = { list = {}, t = {}, r = {}, o = {}, ev = {}, st = {}, own = {} }
        local letters = { "A", "B", "C" }
        local nflags = two_teams and 2 or 3
        for i = 1, nflags do
            ob.list[i] = { letter = letters[i], name = "Flag " .. letters[i], keepId = 100 + i, objectiveId = 1 }
        end
        local function push(t, o, ev, own)
            local i = #ob.t + 1
            ob.t[i], ob.r[i], ob.o[i], ob.ev[i], ob.st[i], ob.own[i] = t, 1, o, ev, -1, own
        end
        local dur = 14 * 60000
        for i = 1, nflags do push(60000, i, -1, 0) end
        local script = {
            { 0.10, 1, CAP, teams[1] }, { 0.12, 2, CAP, teams[2] }, { 0.15, 3, CAP, teams[1] },
            { 0.25, 2, NEU, 0 },        { 0.28, 2, CAP, teams[1] },
            { 0.35, 1, CAP, teams[1] },
            { 0.45, 3, NEU, 0 },        { 0.48, 3, CAP, teams[2] },
            { 0.55, 1, NEU, 0 },        { 0.58, 1, CAP, teams[2] },
            { 0.70, 2, CAP, teams[1] },
            { 0.78, 3, NEU, 0 },        { 0.81, 3, CAP, teams[3] },
            { 0.90, 1, NEU, 0 },        { 0.93, 1, CAP, teams[1] },
        }
        for _, e in ipairs(script) do
            if e[2] <= nflags then push(math.floor(e[1] * dur), e[2], e[3], e[4]) end
        end
        m.objectives = ob
    end

    local medalIds = BGMeter.Icons.scan_medal_ids(300, 6)
    if #medalIds > 0 then
        local lr = Match.local_row(m)
        if lr then
            lr.medalIds = medalIds
            lr.medalCounts = {}
            local total = 0
            for i, id in ipairs(medalIds) do
                local n = (i % 3 == 0) and 3 or 1
                lr.medalCounts[id] = n
                total = total + n
            end
            lr.medals = total
        end
    end

    m.haul.apGained, m.haul.xpGained, m.haul.cpGained, m.haul.medals = 14200, 38400, 2, 3
    m.haul.vetStart = { rank = 14, tier = 14, percent = 0.73, progressToNext = 3650, tierTotal = 5000, seasonName = "Whitestrake's Mayhem", secondsLeft = 387600, inZone = true }
    m.haul.vetEnd   = { rank = 14, tier = 14, percent = 0.81, progressToNext = 4050, tierTotal = 5000, rankTitle = "Veteran Lieutenant", seasonName = "Whitestrake's Mayhem", secondsLeft = 387600, inZone = true }
    Match.derive(m)
    m.standing = { rank = 3, prevRank = 5, rankDelta = 2, score = 1840, prevScore = 1795, scoreDelta = 45, mmr = 1620, impacts = true }
    m.records  = { damage = true, ap = true, rank = true }

    BGMeter.History.push(m)
    BGMeter.UI.window.show_match(1)
    BGMeter.Sound.play("win")

    BGMeter.Log.say("demo match injected -- window shown")
end

local function cmd_faces()
    local Faces = BGMeter.Faces
    local list = Faces.list(nil, 30)
    local lines = {}
    if #list == 0 then
        lines[1] = "no familiar faces yet -- they fill in as you finish battlegrounds"
    else
        lines[1] = string.format("familiar faces: %d known, top %d by matches", Faces.count(), #list)
        for i, e in ipairs(list) do
            lines[#lines + 1] = string.format("%2d. %s  x%d  (%d with, %d against)%s", i, e.name, e.w + e.a, e.w, e.a,
                (e.chr and e.chr ~= "") and ("  as " .. e.chr) or "")
        end
    end
    BGMeter.UI.export.show_text(table.concat(lines, "\n"))
end

local function cmd_ap()
    local Ava = BGMeter.Ava
    local Log = BGMeter.Log
    local F   = BGMeter.Format

    Ava.probe = not Ava.probe
    Log.say("AP probe %s  ·  in AvA=%s  ·  session %s",
        Ava.probe and "|c5cc85fON|r" or "|ce34234OFF|r",
        tostring(Ava.in_ava()), tostring(Ava.session.active))

    local s = Ava.session
    Log.say("session AP=%s  XP=%s  AP/hr=%s  (%d gains)",
        F.commas(s.ap), F.commas(s.xp), F.commas(Ava.ap_per_hour()), s.gains)
    local bd = Ava.breakdown()
    if #bd == 0 then
        Log.say("  no AP earned yet -- the split fills as you play")
    else
        for _, e in ipairs(bd) do
            Log.say("  %s: %s  (%d%%)", e.label, F.commas(e.ap), math.floor(e.pct * 100 + 0.5))
        end
    end
    if Ava.probe then Log.say("  earn some AP now -- each gain prints its reason code") end
end

local function cmd_report()
    local A = BGMeter.zenimax.api
    local F = BGMeter.Format
    local lines = {}
    local function add(fmt, ...)
        if select("#", ...) > 0 then lines[#lines + 1] = string.format(fmt, ...)
        else lines[#lines + 1] = fmt end
    end
    local function safe(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, a = pcall(fn, ...)
        if not ok then return nil end
        return a
    end

    add("BGmeter diagnostic report -- v%s", K.VERSION)
    add("api=%s  world=%s", tostring(safe(A.get_api_version)), tostring(safe(GetWorldName)))
    local round = safe(A.get_bg_round_index)
    add("bg: active=%s  state=%s  round=%s  numRounds=%s",
        tostring(safe(A.is_active_bg)), tostring(safe(A.get_bg_state)),
        tostring(round), tostring(safe(A.get_num_rounds, safe(A.get_bg_id))))
    add("")

    add("--- live medal probe (local player) ---")
    round = round or 1
    local nEntries = safe(A.get_num_entries, round) or 0
    local localIdx = safe(A.get_local_entry_index, round)
    add("scoreboard entries=%d  localIndex=%s", nEntries, tostring(localIdx))
    if localIdx and localIdx > 0 and localIdx <= nEntries then
        safe(A.gen_cumulative_medals, localIdx, round)
        local last, found = nil, 0
        for _ = 1, 32 do
            local id = safe(A.get_next_cumulative_medal, last)
            if not id then break end
            found = found + 1
            local n = safe(A.get_cumulative_medal_count, id) or 1
            local info = BGMeter.Icons.medal_info(id)
            add("  cumulative: id=%d x%d  %s", id, n, info and info.name or "?")
            last = id
        end
        add("  cumulative path found: %d", found)
        last, found = nil, 0
        for _ = 1, 32 do
            local id = safe(A.get_next_entry_medal, localIdx, round, last)
            if not id then break end
            found = found + 1
            add("  per-round: id=%d", id)
            last = id
        end
        add("  per-round path found: %d", found)
    else
        add("  (no scoreboard data right now -- run this at match end or on the scoreboard screen)")
    end
    add("")

    local CZ = BGMeter.zenimax.constants
    add("--- objectives probe (live) ---")
    local nObj = safe(A.get_num_objectives) or 0
    add("numObjectives=%d", nObj)
    for i = 1, nObj do
        local ok, keepId, objectiveId, ctx = pcall(A.get_objective_ids, i)
        if ok and keepId and safe(A.is_bg_objective, keepId, objectiveId, ctx) then
            local otype = safe(A.get_objective_type, keepId, objectiveId, ctx)
            local name  = safe(A.get_objective_info, keepId, objectiveId, ctx)
            local desig = safe(A.get_objective_designation, keepId, objectiveId, ctx)
            local st    = safe(A.get_objective_control_state, keepId, objectiveId, ctx)
            local owner = safe(A.get_capture_area_owner, keepId, objectiveId, ctx)
            add("  [%s] %s  type=%s st=%s own=%s ids=%s:%s",
                tostring(desig ~= nil and CZ.OBJ_LETTER[desig] or "?"), tostring(name),
                tostring(otype), tostring(CZ.OBJ_STATE_LABEL[st] or st),
                tostring(owner), tostring(keepId), tostring(objectiveId))
        end
    end
    add("")

    local midx = (BGMeter.UI.window.current and BGMeter.UI.window.current()) or 1
    local m = BGMeter.History.get(midx)
    if not m then
        midx = 1
        m = BGMeter.History.most_recent()
    end
    add("--- stored match %d of %d (as shown in window) ---", midx, BGMeter.History.count())
    if m then
        local lr = BGMeter.Match.local_row(m)
        local tids = {}
        if m.teams then
            for _, t in ipairs(m.teams) do tids[#tids + 1] = tostring(t.team) end
        end
        add("name=%s  result=%s  rounds=%s  teams=%d (ids: %s)  rows=%d",
            tostring(m.name), tostring(m.result), tostring(m.numRounds),
            m.teams and #m.teams or 0, table.concat(tids, ","), #m.battle)
        add("gameType=%s  duration=%s  localTeam=%s  teamSize=%s  competitive=%s",
            tostring(CZ.GAME_TYPE_LABEL[m.gameType] or m.gameType),
            F.duration(m.durationMs or 0), tostring(m.localTeam),
            tostring(m.teamSize), tostring(m.competitive))
        add("bgId=%s", tostring(m.bgId))
        add("local: medals=%s  medalIds=%d  timeline=%d samples  killfeed=%d",
            tostring(lr and lr.medals), lr and lr.medalIds and #lr.medalIds or 0,
            m.timeline and m.timeline.t and #m.timeline.t or 0,
            m.killfeed and #m.killfeed or 0)
        add("objective trackers per player (caps/def/carry/fkill):")
        for _, r in ipairs(m.battle) do
            add("  %s: %d/%d/%d/%d%s", tostring(r.displayName or r.charName or "?"),
                r.caps or 0, r.defPts or 0, r.carried or 0, r.carrierKills or 0,
                r.isLocal and "  <- you" or "")
        end
        local ob = m.objectives
        if ob and ob.t and #ob.t > 0 then
            add("objectives: %d tracked, %d events", #ob.list, #ob.t)
            for _, o in ipairs(ob.list) do
                add("  [%s] %s (%s:%s)", tostring(o.letter), tostring(o.name),
                    tostring(o.keepId), tostring(o.objectiveId))
            end
            local counts = {}
            for i = 1, #ob.ev do
                local lbl = CZ.OBJ_EVENT_LABEL[ob.ev[i]]
                    or (ob.ev[i] == -1 and "initial" or tostring(ob.ev[i]))
                counts[lbl] = (counts[lbl] or 0) + 1
            end
            local parts = {}
            for k, v in pairs(counts) do parts[#parts + 1] = string.format("%s=%d", k, v) end
            table.sort(parts)
            add("  events by type: %s", table.concat(parts, "  "))
            for i = 1, #ob.t do
                local o = ob.list[ob.o[i]]
                add("  %s r%s [%s %s] %s st=%s own=%s",
                    F.duration(ob.t[i] or 0), tostring(ob.r and ob.r[i] or "?"),
                    o and tostring(o.letter) or "?", o and tostring(o.name) or "?",
                    tostring(CZ.OBJ_EVENT_LABEL[ob.ev[i]]
                        or (ob.ev[i] == -1 and "initial" or ob.ev[i])),
                    tostring(CZ.OBJ_STATE_LABEL[ob.st[i]] or ob.st[i]),
                    tostring(ob.own[i]))
            end
        else
            add("objectives: (none captured)")
        end
        local rl = m.relics
        if rl and rl.t and #rl.t > 0 then
            add("relics/balls: %d tracked, %d events", #rl.list, #rl.t)
            for _, o in ipairs(rl.list) do
                add("  %s (home=%s ids=%s:%s)", tostring(o.name),
                    tostring(o.home), tostring(o.keepId), tostring(o.objectiveId))
            end
            for i = 1, #rl.t do
                local o = rl.list[rl.o[i]]
                add("  %s %s %s hold=%s last=%s%s",
                    F.duration(rl.t[i] or 0), o and tostring(o.name) or "?",
                    tostring(CZ.OBJ_EVENT_LABEL[rl.ev[i]] or rl.ev[i]),
                    tostring(rl.hold[i]), tostring(rl.last[i]),
                    rl.who and rl.who[i] and ("  by " .. rl.who[i]) or "")
            end
        end
    else
        add("(none)")
    end
    add("")

    if BGMeter.Diag and BGMeter.Diag.on then
        for _, l in ipairs(BGMeter.Diag.lines()) do lines[#lines + 1] = l end
        add("")
    end

    add("--- log tail (%d lines, [d]=debug [s]=say [e]=error) ---", #BGMeter.Log.lines())
    for _, l in ipairs(BGMeter.Log.lines()) do
        lines[#lines + 1] = l
    end

    BGMeter.UI.export.show_text(table.concat(lines, "\n"))
end

local function on_slash(args)
    args = (args or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local Log = BGMeter.Log

    if args == "vet" then
        BGMeter.UI.export.show_text(table.concat(BGMeter.Veterancy.raw_lines(), "\n"))
        return
    end

    if not K.dev_tools() then
        BGMeter.UI.menu.toggle()
        return
    end

    if args == "vet claim" or args == "vetclaim" then
        local ok = BGMeter.Veterancy.claim()
        Log.say(ok and "vet claim: reward claim requested" or "vet claim: nothing claimable")
        return
    end

    if args == "" then
        BGMeter.UI.menu.toggle()
        return
    elseif args == "report" then
        cmd_report()
        return
    end

    if args == "show" then
        BGMeter.UI.window.show()
    elseif args == "hide" then
        BGMeter.UI.window.hide()
    elseif args == "toggle" then
        BGMeter.UI.window.toggle()
    elseif args == "dump" then
        cmd_dump()
    elseif args == "ap" then
        cmd_ap()
    elseif args == "demo" then
        cmd_demo(false)
    elseif args == "demo2" or args == "demo 2" then
        cmd_demo(true)
    elseif args == "faces" then
        cmd_faces()
    elseif args == "forget faces" then
        local n = BGMeter.Faces.forget()
        BGMeter.UI.export.show_text(string.format("familiar faces forgotten: %d names dropped", n))
    elseif args == "last" then
        if BGMeter.History.count() == 0 then Log.say("no matches recorded yet")
        else BGMeter.UI.window.show_match(1) end
    elseif args == "layers" then
        BGMeter.UI.window.toggle_layers_debug()
    elseif args == "clear" then
        BGMeter.UI.window.confirm_clear()
    elseif args == "debug" then
        Log.DEBUG = not Log.DEBUG
        Log.say("debug %s", Log.DEBUG and "ON" or "OFF")
    elseif args:find("^vetmock") == 1 and BGMeter.Mock then
        BGMeter.Mock.vet(args:match("^vetmock%s*(.*)$"))
    elseif args:find("^mock") == 1 and BGMeter.Mock then
        BGMeter.Mock.run(args:match("^mock%s*(.*)$"))
    elseif args == "prof" and BGMeter.Prof and BGMeter.Prof.on then
        BGMeter.UI.export.show_text(table.concat(BGMeter.Prof.lines(), "\n"))
    elseif args == "prof reset" and BGMeter.Prof and BGMeter.Prof.on then
        BGMeter.Prof.reset()
        Log.say("profiler reset")
    elseif args == "validate" and BGMeter.Validate and BGMeter.Validate.on then
        BGMeter.UI.export.show_text(table.concat(BGMeter.Validate.lines(), "\n"))
    elseif args == "validate reset" and BGMeter.Validate and BGMeter.Validate.on then
        BGMeter.Validate.reset()
        Log.say("validation layer reset")
    elseif args == "perf" and BGMeter.Diag and BGMeter.Diag.on then
        BGMeter.UI.export.show_text(table.concat(BGMeter.Diag.lines(), "\n"))
    elseif args == "perf reset" and BGMeter.Diag and BGMeter.Diag.on then
        BGMeter.Diag.reset()
        Log.say("perf counters reset")
    elseif args:find("^probe anchors") == 1 and BGMeter.Diag and BGMeter.Diag.on then
        BGMeter.UI.export.show_text(table.concat(BGMeter.Diag.probe_anchors(tonumber(args:match("(%d+)"))), "\n"))
    elseif args:find("^gcprobe") == 1 and BGMeter.Diag and BGMeter.Diag.on then
        BGMeter.Diag.gcprobe(tonumber(args:match("(%d+)")))
    elseif args:find("^geo") == 1 and BGMeter.Geo then
        BGMeter.Geo.command(args:match("^geo%s*(.*)$"))
    elseif args:find("^sound") == 1 then
        BGMeter.Sound.audition(args:match("^sound%s*(.*)$"))
    elseif args:find("^csa") == 1 then
        BGMeter.Standing.celebrate(tonumber(args:match("(%d+)")) or 87)
    elseif args == "trophy" then
        BGMeter.UI.menu.demo_trophy()
    else
        Log.say("dev: show, hide, toggle, last, demo, demo2, ap, dump, clear, debug, layers, mock <dm/dom/ck/ball/relic>, vet, vet claim, vetmock <below/r34/cap/h1/h2/h3/off>, perf, prof, prof reset, validate, validate reset, gcprobe [sec], sound [name], csa [rank], trophy, geo [on/off/dump/clear/mark]")
    end
end

local function on_addon_loaded()
    BGMeter.zenimax.savedvars.init(K.SAVED_VARS, 1)
    BGMeter.Faces.backfill()
    BGMeter.Faces.backfill_kills()
    BGMeter.Ledger.backfill()
    BGMeter.Ledger.backfill_balance()
    BGMeter.Ledger.stamp_balance()
    do
        local data = BGMeter.zenimax.savedvars.get()
        for _, m in ipairs((data and data.matches) or {}) do pcall(BGMeter.Match.pack_timeline, m) end
    end

    if K.dev_tools() and BGMeter.Diag then BGMeter.Diag.install() end

    BGMeter.Pipeline.acquisition.init()
    if BGMeter.Geo then BGMeter.Geo.init() end
    BGMeter.Ava.init()
    BGMeter.UI.window.init()
    BGMeter.UI.menu.init()

    SLASH_COMMANDS[K.SLASH] = on_slash

    BGMeter.Log.debug("v%s loaded  ·  %s for commands", K.VERSION, K.SLASH)
end

BGMeter._slash = on_slash
BGMeter.zenimax.events.register_addon_loaded(K.ADDON_NAME, on_addon_loaded)
