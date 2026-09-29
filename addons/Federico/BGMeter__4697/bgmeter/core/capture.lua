BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Capture = {}

local SAMPLE_NAME = "BGMeterScoreSample"
local SAMPLE_MS   = 5000
local POS_NAME    = "BGMeterPosSample"
local POS_MS      = 3000
local ME_NAME     = "BGMeterMeSample"
local ME_MS       = 1000
local MAX_PINS    = 8
local MAX_ME      = 1500

local active = nil
local baseline = nil
local obj_lookup = {}
local obj_last = {}
local relic_lookup = {}

local MAX_OBJ_EVENTS = 600

local Prof = BGMeter.Prof
local Val = BGMeter.Validate
local MAX_SCORE_SAMPLES = 1000
local MAX_KILLS = 1000

local MAX_POS = 900

local function presize(t, n)
    for i = 1, n do t[i] = 0 end
    for i = n, 1, -1 do t[i] = nil end
    return t
end

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end

local function team_list()
    local C = BGMeter.zenimax.constants
    return { C.BATTLEGROUND_TEAM_FIRE_DRAKES, C.BATTLEGROUND_TEAM_PIT_DAEMONS, C.BATTLEGROUND_TEAM_STORM_LORDS }
end

local function current_round()
    local A = BGMeter.zenimax.api
    return safe(A.get_bg_round_index) or 1
end

local function read_score(i, stype, round)
    local A = BGMeter.zenimax.api
    local v = safe(A.get_entry_cumulative, i, stype, round)
    if v == nil then v = safe(A.get_entry_score, i, stype, round) end
    return (v or 0) + 0
end

local function clean_name(raw)
    if not raw or raw == "" then return nil end
    if type(zo_strformat) == "function" then
        local ok, f = pcall(zo_strformat, "<<1>>", raw)
        if ok and f and f ~= "" then return f end
    end
    return (raw:gsub("%^.*$", ""))
end

local function count_entry_medals(i, round)
    local A = BGMeter.zenimax.api
    local count, last, ids, counts = 0, nil, {}, {}

    safe(A.gen_cumulative_medals, i, round)
    for _ = 1, 64 do
        local id = safe(A.get_next_cumulative_medal, last)
        if not id then break end
        local n = safe(A.get_cumulative_medal_count, id) or 1
        count = count + n
        ids[#ids + 1] = id
        counts[id] = n
        last = id
    end

    if count == 0 then
        last = nil
        for _ = 1, 64 do
            local id = safe(A.get_next_entry_medal, i, round, last)
            if not id then break end
            local n = safe(A.get_entry_medal_count, i, id, round) or 1
            count = count + n
            ids[#ids + 1] = id
            counts[id] = n
            last = id
        end
    end

    return count, ids, counts
end

function Capture.read_battle(m)
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    local Match = BGMeter.Match
    local round = current_round()
    local n = safe(A.get_num_entries, round) or 0

    m.battle = {}
    for i = 1, n do
        local row = Match.new_row()
        local charName, displayName, team, isLocal = safe(A.get_entry_info, i, round)
        row.charName    = clean_name(charName)
        row.displayName = clean_name(displayName)
        row.team        = team or safe(A.get_entry_team, i, round)
        row.isLocal     = isLocal and true or false
        row.classId     = safe(A.get_entry_class, i, round)
        row.lives       = safe(A.get_entry_lives, i, round)
        row.damage      = read_score(i, C.SCORE_TRACKER_TYPE_DAMAGE_DONE, round)
        row.healing     = read_score(i, C.SCORE_TRACKER_TYPE_HEALING_DONE, round)
        row.taken       = read_score(i, C.SCORE_TRACKER_TYPE_DAMAGE_TAKEN, round)
        row.kills       = read_score(i, C.SCORE_TRACKER_TYPE_KILL, round)
        row.deaths      = read_score(i, C.SCORE_TRACKER_TYPE_DEATH, round)
        row.assists     = read_score(i, C.SCORE_TRACKER_TYPE_ASSISTS, round)
        row.score       = read_score(i, C.SCORE_TRACKER_TYPE_SCORE, round)
        row.caps        = read_score(i, C.SCORE_TRACKER_TYPE_FLAG_CAPTURED, round)
        row.defPts      = read_score(i, C.SCORE_TRACKER_TYPE_CAPTURE_DEFENSE_POINTS, round)
        row.carried     = read_score(i, C.SCORE_TRACKER_TYPE_FLAG_CARRIED_TIME, round)
        row.carrierKills = read_score(i, C.SCORE_TRACKER_TYPE_KILLED_FLAG_CARRIER, round)
        row.medals, row.medalIds, row.medalCounts = count_entry_medals(i, round)
        m.battle[#m.battle + 1] = row
    end
    return m
end

local function read_teams(m)
    local A = BGMeter.zenimax.api
    local round = current_round()
    local present = {}
    for _, row in ipairs(m.battle) do
        if row.team ~= nil then present[row.team] = true end
    end
    local order = {}
    for _, t in ipairs(team_list()) do
        if t ~= nil and (present[t] or next(present) == nil) then
            order[#order + 1] = t
        end
    end
    local teams = {}
    for _, t in ipairs(order) do
        teams[#teams + 1] = {
            team      = t,
            score     = safe(A.get_team_score, round, t) or 0,
            roundsWon = safe(A.get_rounds_won, t) or 0,
        }
    end
    m.teams = teams
    m.numRounds = (m.bgId and safe(A.get_num_rounds, m.bgId)) or 1
end

local function read_result(localTeam)
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    if localTeam == nil then return nil end
    local r = safe(A.get_result_for_team, localTeam)
    if r == nil then return nil end
    return C.RESULT_LABEL[r]
end

local function obj_key(keepId, objectiveId)
    return tostring(keepId) .. ":" .. tostring(objectiveId)
end

local function register_objective(keepId, objectiveId, ctx, name)
    if not active or not active.objectives then return nil end
    local key = obj_key(keepId, objectiveId)
    local idx = obj_lookup[key]
    if idx then
        local cleaned = clean_name(name)
        if cleaned then active.objectives.list[idx].name = cleaned end
        return idx
    end
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    local list = active.objectives.list
    idx = #list + 1
    local desig = safe(A.get_objective_designation, keepId, objectiveId, ctx)
    list[idx] = {
        keepId = keepId,
        objectiveId = objectiveId,
        ctx = ctx,
        letter = (desig ~= nil and C.OBJ_LETTER[desig]) or tostring(idx),
        name = clean_name(name),
    }
    obj_lookup[key] = idx
    return idx
end

local function record_obj_event(idx, controlEvent, controlState, owner)
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    local ob = active.objectives
    if #ob.t >= MAX_OBJ_EVENTS then return false end
    local last = obj_last[idx]
    if controlEvent == C.OBJ_EVENT_INFLUENCE and last
        and last.st == controlState and last.own == owner then
        return false
    end
    local slot = obj_last[idx]
    if slot then
        slot.st, slot.own = controlState, owner
    else
        obj_last[idx] = { st = controlState, own = owner }
    end
    local i = #ob.t + 1
    ob.t[i]   = (safe(A.now_ms) or 0) - (active.startMs or 0)
    ob.r[i]   = current_round()
    ob.o[i]   = idx
    ob.ev[i]  = controlEvent or -1
    ob.st[i]  = controlState or -1
    ob.own[i] = owner or -1
    return true
end

local function scan_objectives(reason)
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    local Log = BGMeter.Log
    local n = safe(A.get_num_objectives) or 0
    for i = 1, n do
        local keepId, objectiveId, ctx = safe(A.get_objective_ids, i)
        if keepId and objectiveId then
            local isBg = safe(A.is_bg_objective, keepId, objectiveId, ctx)
            local otype = safe(A.get_objective_type, keepId, objectiveId, ctx)
            local name = safe(A.get_objective_info, keepId, objectiveId, ctx)
            if isBg and otype == C.OBJECTIVE_CAPTURE_AREA then
                local idx = register_objective(keepId, objectiveId, ctx, name)
                if idx then
                    local st = safe(A.get_objective_control_state, keepId, objectiveId, ctx)
                    local owner = safe(A.get_capture_area_owner, keepId, objectiveId, ctx)
                    record_obj_event(idx, -1, st, owner)
                    Log.debug("scan: [%s] %s st=%s own=%s ids=%s:%s",
                        tostring(active.objectives.list[idx].letter), tostring(clean_name(name)),
                        tostring(C.OBJ_STATE_LABEL[st] or st), tostring(owner),
                        tostring(keepId), tostring(objectiveId))
                end
            elseif isBg then
                Log.debug("scan: skipped non-capture-area objective type=%s name=%s ids=%s:%s",
                    tostring(otype), tostring(clean_name(name)), tostring(keepId), tostring(objectiveId))
            end
        end
    end
    Log.debug("objective scan (%s): %d total, %d capture areas tracked",
        tostring(reason), n, active and #active.objectives.list or 0)
end

function Capture.on_objective(_, keepId, objectiveId, ctx, name, controlEvent, controlState, owner)
    if not active or not active.objectives then return end
    local idx = register_objective(keepId, objectiveId, ctx, name)
    if not idx then return end
    if record_obj_event(idx, controlEvent, controlState, owner) then
        local C = BGMeter.zenimax.constants
        BGMeter.Log.debug("obj %s ev=%s st=%s own=%s",
            tostring(active.objectives.list[idx].letter),
            tostring(C.OBJ_EVENT_LABEL[controlEvent] or controlEvent),
            tostring(C.OBJ_STATE_LABEL[controlState] or controlState),
            tostring(owner))
    end
end

local function obj_elapsed()
    local A = BGMeter.zenimax.api
    return (safe(A.now_ms) or 0) - ((active and active.startMs) or 0)
end

local MAX_RELIC_EVENTS = 400
local caps_snap = {}

local function snap_caps()
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    local round = current_round()
    local n = safe(A.get_num_entries, round) or 0
    for i = 1, n do
        local charName, disp = safe(A.get_entry_info, i, round)
        local nm = clean_name(disp or charName)
        if nm then
            caps_snap[nm] = read_score(i, C.SCORE_TRACKER_TYPE_FLAG_CAPTURED, round)
        end
    end
end

local function scan_goal(rl, evIdx, team)
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    local round = current_round()
    local n = safe(A.get_num_entries, round) or 0
    local bestName, bestDelta = nil, 0
    for i = 1, n do
        local charName, disp, eteam = safe(A.get_entry_info, i, round)
        local nm = clean_name(disp or charName)
        if nm then
            local caps = read_score(i, C.SCORE_TRACKER_TYPE_FLAG_CAPTURED, round)
            local d = caps - (caps_snap[nm] or 0)
            caps_snap[nm] = caps
            if d > bestDelta and (not team or team == 0 or eteam == team) then
                bestName, bestDelta = nm, d
            end
        end
    end
    if bestName then
        rl.who[evIdx] = bestName
        BGMeter.Log.debug("goal attribution: %s (+%d caps) -> relic event %d", bestName, bestDelta, evIdx)
    else
        BGMeter.Log.debug("goal attribution: no caps delta visible for relic event %d", evIdx)
    end
end

local function record_relic_event(keepId, objectiveId, name, home, controlEvent, hold, last)
    local rl = active.relics
    if not rl or #rl.t >= MAX_RELIC_EVENTS then return nil end
    local key = obj_key(keepId, objectiveId)
    local idx = relic_lookup[key]
    if not idx then
        idx = #rl.list + 1
        rl.list[idx] = { keepId = keepId, objectiveId = objectiveId, name = clean_name(name), home = home }
        relic_lookup[key] = idx
    elseif home and home ~= 0 and not rl.list[idx].home then
        rl.list[idx].home = home
    end
    local i = #rl.t + 1
    rl.t[i]    = obj_elapsed()
    rl.r[i]    = current_round()
    rl.o[i]    = idx
    rl.ev[i]   = controlEvent or -1
    rl.hold[i] = hold or 0
    rl.last[i] = last or 0
    return i
end

function Capture.on_flag(_, keepId, objectiveId, ctx, name, controlEvent, controlState, origOwner, holder, lastHolder, pinType)
    if not active then return end
    local C = BGMeter.zenimax.constants
    local ei = record_relic_event(keepId, objectiveId, name, origOwner, controlEvent, holder, lastHolder)
    local evl = C.OBJ_EVENT_LABEL[controlEvent]
    if evl == "flag_taken" then
        snap_caps()
    elseif evl == "captured" and ei then
        local rl = active.relics
        local team = lastHolder
        local function attribute()
            if rl.who[ei] == nil then scan_goal(rl, ei, team) end
        end
        if type(zo_callLater) == "function" then
            zo_callLater(attribute, 800)
            zo_callLater(attribute, 2500)
            zo_callLater(attribute, 6000)
        else
            attribute()
        end
    end
    BGMeter.Log.debug("relic t=%s %s ev=%s st=%s orig=%s hold=%s last=%s pin=%s ids=%s:%s",
        BGMeter.Format.duration(obj_elapsed()), tostring(clean_name(name)),
        tostring(C.OBJ_EVENT_LABEL[controlEvent] or controlEvent),
        tostring(C.OBJ_STATE_LABEL[controlState] or controlState),
        tostring(origOwner), tostring(holder), tostring(lastHolder),
        tostring(pinType), tostring(keepId), tostring(objectiveId))
end

function Capture.on_murderball(_, keepId, objectiveId, ctx, name, controlEvent, controlState, holder, lastHolder, holderRaw, holderDisp, lastRaw, lastDisp, pinType)
    if not active then return end
    local C = BGMeter.zenimax.constants
    local ei = record_relic_event(keepId, objectiveId, name, nil, controlEvent, holder, lastHolder)
    if ei and C.OBJ_EVENT_LABEL[controlEvent] == "flag_taken" then
        active.relics.who[ei] = clean_name(holderDisp or holderRaw)
    end
    BGMeter.Log.debug("ball t=%s %s ev=%s st=%s hold=%s(%s) last=%s(%s) pin=%s ids=%s:%s",
        BGMeter.Format.duration(obj_elapsed()), tostring(clean_name(name)),
        tostring(C.OBJ_EVENT_LABEL[controlEvent] or controlEvent),
        tostring(C.OBJ_STATE_LABEL[controlState] or controlState),
        tostring(holder), tostring(clean_name(holderDisp) or clean_name(holderRaw) or "?"),
        tostring(lastHolder), tostring(clean_name(lastDisp) or clean_name(lastRaw) or "?"),
        tostring(pinType), tostring(keepId), tostring(objectiveId))
end

local function sample_players(tl, i, round)
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    local n = safe(A.get_num_entries, round) or 0
    if n <= 0 then return end
    tl.p = tl.p or {}
    for e = 1, n do
        local charName, displayName, team = safe(A.get_entry_info, e, round)
        local nm = clean_name(displayName or charName)
        if nm then
            local rec = tl.p[nm]
            if not rec then rec = { d = presize({}, MAX_SCORE_SAMPLES) }; tl.p[nm] = rec end
            rec.d[i] = read_score(e, C.SCORE_TRACKER_TYPE_DAMAGE_DONE, round)
            if team and team ~= 0 then rec.tm = team end
        end
    end
end

local function q(v)
    if type(v) ~= "number" then return nil end
    return math.floor(math.max(0, math.min(1, v)) * 1000 + 0.5)
end

local function read_map()
    local A = BGMeter.zenimax.api
    if safe(A.map_matches_player) == false then
        if safe(A.world_map_showing) then return nil end
        safe(A.set_map_to_player)
        if safe(A.map_matches_player) == false then return nil end
    end
    local nx, ny = safe(A.get_map_num_tiles)
    nx, ny = tonumber(nx) or 0, tonumber(ny) or 0
    if nx <= 0 or ny <= 0 or nx * ny > 36 then return nil end
    local tex = {}
    for i = 1, nx * ny do
        tex[i] = safe(A.get_map_tile_texture, i) or ""
    end
    return { id = safe(A.get_current_map_id), name = clean_name(safe(A.get_map_name)), nx = nx, ny = ny, tex = tex }
end

local function pin_slot(tl, keepId, objectiveId, ctx)
    local key = obj_key(keepId, objectiveId)
    local idx = tl.pinIdx[key]
    if idx then return idx end
    if #tl.pin >= MAX_PINS then return nil end
    local A = BGMeter.zenimax.api
    local C = BGMeter.zenimax.constants
    local name, otype = safe(A.get_objective_info, keepId, objectiveId, ctx)
    idx = #tl.pin + 1
    tl.pin[idx] = { keepId = keepId, objectiveId = objectiveId, name = clean_name(name),
                    kind = (otype == C.OBJECTIVE_CAPTURE_AREA) and "area" or "carry",
                    x = presize({}, MAX_POS), y = presize({}, MAX_POS), ty = presize({}, MAX_POS) }
    tl.pinIdx[key] = idx
    return idx
end

local function sample_positions()
    if not active or not active.timeline then return end
    local A = BGMeter.zenimax.api
    local tl = active.timeline
    if not tl.pt then
        tl.pt, tl.pos, tl.pin, tl.pinIdx = presize({}, MAX_POS), {}, {}, {}
    end
    local i = #tl.pt + 1
    if i > MAX_POS then return end
    local now = (safe(A.now_ms) or 0) - (active.startMs or 0)
    if i > 1 and tl.pt[i - 1] == now then return end
    Val.monotonic("pos", tl.pt[i - 1], now)
    tl.pt[i] = now
    local function put(name, x, y, inMap)
        if not name or x == nil or inMap == false then return end
        local rec = tl.pos[name]
        if not rec then rec = { x = presize({}, MAX_POS), y = presize({}, MAX_POS) }; tl.pos[name] = rec end
        rec.x[i], rec.y[i] = q(x), q(y)
    end
    local px, py, _, pin = safe(A.get_map_player_position, "player")
    put(active.localName, px, py, pin)
    local n = safe(A.get_group_size) or 0
    for g = 1, math.min(n, 8) do
        local tag = safe(A.get_group_unit_tag, g)
        if tag and safe(A.are_units_equal, tag, "player") ~= true then
            local nm = clean_name(safe(A.get_unit_display_name, tag)) or clean_name(safe(A.get_unit_name, tag))
            if nm and nm ~= active.localName then
                local gx, gy, _, gin = safe(A.get_map_player_position, tag)
                put(nm, gx, gy, gin)
            end
        end
    end
    for _, rec in pairs(tl.pos) do
        if rec.x[i] == nil then rec.x[i], rec.y[i] = 0, 0 end
    end
    local nobj = safe(A.get_num_objectives) or 0
    for o = 1, math.min(nobj, MAX_PINS) do
        local keepId, objectiveId, ctx = safe(A.get_objective_ids, o)
        if keepId and objectiveId and safe(A.is_bg_objective, keepId, objectiveId, ctx) then
            local idx = pin_slot(tl, keepId, objectiveId, ctx)
            if idx then
                local ty, ox, oy = safe(A.get_objective_pin_info, keepId, objectiveId, ctx)
                local pin = tl.pin[idx]
                pin.x[i], pin.y[i], pin.ty[i] = q(ox) or 0, q(oy) or 0, ty or 0
            end
        end
    end
    if not active.map or not active.map.tex or active.map.tex[1] == "" then
        active.map = read_map() or active.map
    end
end

local function discover_roster()
    if not active or not active.timeline then return end
    local A = BGMeter.zenimax.api
    local tl = active.timeline
    local round = current_round()
    local n = safe(A.get_num_entries, round) or 0
    if n > 0 then
        tl.p = tl.p or {}
        for e = 1, n do
            local charName, displayName, team = safe(A.get_entry_info, e, round)
            local nm = clean_name(displayName or charName)
            if nm and not tl.p[nm] then
                tl.p[nm] = { d = presize({}, MAX_SCORE_SAMPLES), tm = (team and team ~= 0) and team or nil }
            end
        end
    end
    if not tl.pt then
        tl.pt, tl.pos, tl.pin, tl.pinIdx = presize({}, MAX_POS), {}, {}, {}
    end
    if active.localName and not tl.pos[active.localName] then
        tl.pos[active.localName] = { x = presize({}, MAX_POS), y = presize({}, MAX_POS) }
    end
    local g = safe(A.get_group_size) or 0
    for i = 1, math.min(g, 8) do
        local tag = safe(A.get_group_unit_tag, i)
        if tag and safe(A.are_units_equal, tag, "player") ~= true then
            local nm = clean_name(safe(A.get_unit_display_name, tag)) or clean_name(safe(A.get_unit_name, tag))
            if nm and nm ~= active.localName and not tl.pos[nm] then
                tl.pos[nm] = { x = presize({}, MAX_POS), y = presize({}, MAX_POS) }
            end
        end
    end
end

local function discover_pins()
    if not active or not active.timeline then return end
    local A = BGMeter.zenimax.api
    local tl = active.timeline
    if not tl.pt then
        tl.pt, tl.pos, tl.pin, tl.pinIdx = presize({}, MAX_POS), {}, {}, {}
    end
    local nobj = safe(A.get_num_objectives) or 0
    for o = 1, math.min(nobj, MAX_PINS) do
        local keepId, objectiveId, ctx = safe(A.get_objective_ids, o)
        if keepId and objectiveId and safe(A.is_bg_objective, keepId, objectiveId, ctx) then
            pin_slot(tl, keepId, objectiveId, ctx)
        end
    end
end

local function sample_me()
    if not active or not active.timeline then return end
    local A = BGMeter.zenimax.api
    local tl = active.timeline
    if not tl.mt then tl.mt, tl.mx, tl.my = presize({}, MAX_ME), presize({}, MAX_ME), presize({}, MAX_ME) end
    local i = #tl.mt + 1
    if i > MAX_ME then return end
    local now = (safe(A.now_ms) or 0) - (active.startMs or 0)
    if i > 1 and tl.mt[i - 1] == now then return end
    local px, py = safe(A.get_map_player_position, "player")
    local qx, qy = q(px), q(py)
    if not qx or not qy then return end
    Val.monotonic("me", tl.mt[i - 1], now)
    tl.mt[i], tl.mx[i], tl.my[i] = now, qx, qy
end

local function note_experience(tag, name)
    if not active or not active.exp then return end
    local A = BGMeter.zenimax.api
    local nm = name or clean_name(safe(A.get_unit_display_name, tag)) or clean_name(safe(A.get_unit_name, tag))
    if not nm then return end
    local vet = safe(A.get_unit_veterancy_rank_of, tag)
    local ava = safe(A.get_unit_ava_rank_of, tag)
    local team = safe(A.get_unit_bg_team, tag)
    local e = active.exp[nm]
    if not e then e = {}; active.exp[nm] = e end
    if type(vet) == "number" and vet > 0 then e.vet = vet end
    if type(ava) == "number" and ava > 0 then e.ava = ava end
    if team and team ~= 0 then e.tm = team end
end

local function scan_group_experience()
    if not active then return end
    local A = BGMeter.zenimax.api
    note_experience("player", active.localName)
    local n = safe(A.get_group_size) or 0
    for g = 1, math.min(n, 8) do
        local tag = safe(A.get_group_unit_tag, g)
        if tag and safe(A.are_units_equal, tag, "player") ~= true then note_experience(tag) end
    end
end

function Capture.on_reticle_player()
    if not active then return end
    local A = BGMeter.zenimax.api
    if safe(A.is_unit_player, "reticleover") ~= true then return end
    note_experience("reticleover")
end

local function attach_experience(m)
    local exp = m.exp
    if not exp then return end
    for _, row in ipairs(m.battle or {}) do
        local e = (row.displayName and exp[row.displayName]) or (row.charName and exp[row.charName])
        if e then
            row.vet = e.vet
            row.ava = e.ava
        end
    end
    m.exp = nil
end

local function sample_scores()
    if not active or not active.timeline then return end
    local A = BGMeter.zenimax.api
    local tl = active.timeline
    local round = current_round()
    if active.lastRound and round ~= active.lastRound then
        BGMeter.Log.debug("round change: r%s -> r%s (rescanning objectives)",
            tostring(active.lastRound), tostring(round))
        scan_objectives("round change")
    end
    active.lastRound = round
    local i = #tl.t + 1
    tl.t[i] = (safe(A.now_ms) or 0) - (active.startMs or 0)
    Val.monotonic("score", tl.t[i - 1], tl.t[i])
    tl.r[i] = round
    local teams = team_list()
    tl.s1[i] = (teams[1] ~= nil and safe(A.get_team_score, round, teams[1])) or 0
    tl.s2[i] = (teams[2] ~= nil and safe(A.get_team_score, round, teams[2])) or 0
    tl.s3[i] = (teams[3] ~= nil and safe(A.get_team_score, round, teams[3])) or 0
    if not tl.p_off then
        local ok, err = pcall(sample_players, tl, i, round)
        if not ok then
            tl.p_off = true
            BGMeter.Log.debug("player sampling disabled for this match: %s", tostring(err))
        end
    end
end

local function start_sampler()
    BGMeter.zenimax.events.register_update(SAMPLE_NAME, SAMPLE_MS, sample_scores)
    BGMeter.zenimax.events.register_update(POS_NAME, POS_MS, function()
        local ok, err = pcall(sample_positions)
        if not ok then BGMeter.Log.debug("position sampling failed: %s", tostring(err)) end
    end)
    BGMeter.zenimax.events.register_update(ME_NAME, ME_MS, function() pcall(sample_me) end)
end

local function stop_sampler()
    BGMeter.zenimax.events.unregister_update(SAMPLE_NAME)
    BGMeter.zenimax.events.unregister_update(POS_NAME)
    BGMeter.zenimax.events.unregister_update(ME_NAME)
end

local function open_run(now)
    if not active then return end
    active.runs = active.runs or {}
    local last = active.runs[#active.runs]
    if last and last.b == nil then return end
    active.runs[#active.runs + 1] = { a = now - (active.startMs or 0) }
end

local function close_run(now)
    if not active or not active.runs then return end
    local last = active.runs[#active.runs]
    if last and last.b == nil then last.b = math.max(last.a, now - (active.startMs or 0)) end
end

function Capture.begin()
    local A = BGMeter.zenimax.api
    local Match = BGMeter.Match
    local Vet = BGMeter.Veterancy

    active = Match.new()
    active.startMs   = safe(A.now_ms) or 0
    active.bgId      = safe(A.get_bg_id)
    active.name      = clean_name(active.bgId and safe(A.get_bg_name, active.bgId) or nil)
    active.gameType  = safe(A.get_bg_game_type)
    active.localTeam = safe(A.get_local_team)
    active.localName = clean_name(safe(A.get_display_name)) or clean_name(safe(A.get_char_name))
    active.teamSize  = active.bgId and safe(A.get_bg_team_size, active.bgId) or nil
    active.numTeams  = active.bgId and safe(A.get_bg_num_teams, active.bgId) or nil
    if active.teamSize then active.competitive = (active.teamSize == 4) end
    active.timeline  = { t = presize({}, MAX_SCORE_SAMPLES), r = presize({}, MAX_SCORE_SAMPLES),
                         s1 = presize({}, MAX_SCORE_SAMPLES), s2 = presize({}, MAX_SCORE_SAMPLES), s3 = presize({}, MAX_SCORE_SAMPLES),
                         teams = team_list() }
    active.killfeed  = presize({}, MAX_KILLS)
    active.exp       = {}
    active.objectives = { list = {}, t = presize({}, MAX_OBJ_EVENTS), r = presize({}, MAX_OBJ_EVENTS), o = presize({}, MAX_OBJ_EVENTS),
                          ev = presize({}, MAX_OBJ_EVENTS), st = presize({}, MAX_OBJ_EVENTS), own = presize({}, MAX_OBJ_EVENTS) }
    active.relics = { list = {}, t = presize({}, MAX_RELIC_EVENTS), r = presize({}, MAX_RELIC_EVENTS), o = presize({}, MAX_RELIC_EVENTS),
                      ev = presize({}, MAX_RELIC_EVENTS), hold = presize({}, MAX_RELIC_EVENTS), last = presize({}, MAX_RELIC_EVENTS), who = {} }
    obj_lookup = {}
    obj_last = {}
    relic_lookup = {}
    caps_snap = {}

    baseline = {
        ap  = safe(A.get_alliance_points) or 0,
        cp  = safe(A.get_cp_earned) or 0,
        vet = Vet.snapshot(),
    }
    active.haul.vetStart = baseline.vet

    active.map = read_map()
    start_sampler()
    pcall(discover_roster)
    pcall(discover_pins)
    sample_scores()
    pcall(sample_positions)
    pcall(sample_me)
    pcall(scan_group_experience)

    local C = BGMeter.zenimax.constants
    if safe(A.get_bg_state) == C.BATTLEGROUND_STATE_RUNNING then
        active.runMs = active.startMs
        open_run(active.startMs)
    end
    BGMeter.Log.debug("match begin: bg=%s id=%s gameType=%s rounds=%s localTeam=%s teamSize=%s competitive=%s ap0=%d",
        tostring(active.name), tostring(active.bgId),
        tostring(C.GAME_TYPE_LABEL[active.gameType] or active.gameType),
        tostring(active.bgId and safe(A.get_num_rounds, active.bgId)),
        tostring(active.localTeam), tostring(active.teamSize), tostring(active.competitive), baseline.ap)
    scan_objectives("match begin")
end

function Capture.on_ap(_, alliancePoints, _playSound, difference)
    if not active or not difference then return end
    active.haul.apGained = active.haul.apGained + difference
end

function Capture.on_xp(_, reason, _level, prev, current)
    if not active or not prev or not current then return end
    active.haul.xpGained = active.haul.xpGained + math.max(0, current - prev)
end

function Capture.on_cp(_, delta)
    if not active or not delta then return end
    active.haul.cpGained = active.haul.cpGained + delta
end

function Capture.on_reward_track(_, rewardTrackType, _trackId, prevTier, newTier)
    if not active then return end
    local C = BGMeter.zenimax.constants
    if rewardTrackType ~= C.REWARD_TRACK_TYPE_AVA_VETERANCY then return end
    if newTier and prevTier and newTier > prevTier then
        active.haul.vetRankUp = true
        BGMeter.Log.debug("veterancy tier up: %s -> %s", tostring(prevTier), tostring(newTier))
    end
end

function Capture.on_kill(_, killedChar, killedDisp, killedTeam, killerChar, killerDisp, killerTeam, killType)
    if not active or not active.killfeed then return end
    local A = BGMeter.zenimax.api
    local killer = clean_name(killerDisp or killerChar)
    local killed = clean_name(killedDisp or killedChar)
    BGMeter.Log.debug("bg kill: %s (t%s) killed %s (t%s) type=%s",
        tostring(killer), tostring(killerTeam),
        tostring(killed), tostring(killedTeam), tostring(killType))
    local myDisp = safe(A.get_display_name)
    local myChar = safe(A.get_char_name)
    local kind = nil
    if (killerDisp and killerDisp == myDisp) or (killerChar and killerChar == myChar) then
        kind = "kill"
    elseif (killedDisp and killedDisp == myDisp) or (killedChar and killedChar == myChar) then
        kind = "death"
    end
    local t = (safe(A.now_ms) or 0) - (active.startMs or 0)
    local entry = {
        t = t, kind = kind,
        kn = killer, dn = killed,
        kt = killerTeam, dt = killedTeam,
        ty = killType,
    }
    if kind then
        local px, py = safe(A.get_map_player_position, "player")
        local qx, qy = q(px), q(py)
        if qx and qy then entry.x, entry.y = qx, qy end
    end
    active.killfeed[#active.killfeed + 1] = entry
end

function Capture.finalize()
    if not active then return nil end
    local A = BGMeter.zenimax.api
    local Match = BGMeter.Match

    stop_sampler()
    Prof.enter("cap:finalize.sample")
    local ok, err = pcall(sample_scores)
    if not ok then BGMeter.Log.debug("final sample failed: %s", tostring(err)) end
    pcall(sample_positions)
    pcall(sample_me)
    Prof.exit("cap:finalize.sample")
    Val.roundtrip("finalize", active)
    Prof.enter("cap:finalize.pack")
    pcall(Match.pack_timeline, active)
    Prof.exit("cap:finalize.pack")

    active.endMs = safe(A.now_ms) or active.startMs
    close_run(active.endMs)
    if active.runs and #active.runs == 0 then active.runs = nil end
    active.playedMs = math.max(0, active.endMs - (active.runMs or active.startMs))
    active.capturedAt = safe(A.get_timestamp)
    active.result = read_result(active.localTeam)

    Prof.enter("cap:finalize.battle")
    pcall(scan_group_experience)
    Capture.read_battle(active)
    read_teams(active)
    attach_experience(active)
    Prof.exit("cap:finalize.battle")

    if baseline then
        local apNow = safe(A.get_alliance_points)
        local cpNow = safe(A.get_cp_earned)
        if apNow then active.haul.apGained = math.max(active.haul.apGained, apNow - baseline.ap) end
        if cpNow then active.haul.cpGained = math.max(active.haul.cpGained, cpNow - baseline.cp) end
    end

    active.haul.vetEnd = BGMeter.Veterancy.snapshot()
    local vs, ve = active.haul.vetStart, active.haul.vetEnd
    if vs and ve and (ve.laps or 0) > (vs.laps or 0) then active.haul.vetRankUp = true end
    local lr = Match.local_row(active)
    if lr then active.haul.medals = lr.medals end

    Match.derive(active)
    local balOk, bal = pcall(Match.balance, active)
    if balOk and bal then active.bal = bal.score end

    local tl = active.timeline
    Val.cap("score", #tl.t, MAX_SCORE_SAMPLES)
    Val.cap("pos", tl.pt and #tl.pt or 0, MAX_POS)
    Val.cap("me", tl.mt and (type(tl.mt[1]) == "number" and #tl.mt or 0) or 0, MAX_ME)
    Val.cap("objectives", #active.objectives.t, MAX_OBJ_EVENTS)
    Val.cap("relics", #active.relics.t, MAX_RELIC_EVENTS)
    Val.cap("kills", #active.killfeed, MAX_KILLS)
    Val.finite("match", active)

    local finished = active
    active, baseline = nil, nil
    return finished
end

function Capture.on_scoreboard()
    if not active then return end
    pcall(discover_roster)
    pcall(discover_pins)
end

function Capture.rescan(reason)
    if not active then return end
    scan_objectives(reason)
end

function Capture.mark_running()
    if not active then return end
    local A = BGMeter.zenimax.api
    local now = safe(A.now_ms) or active.startMs
    open_run(now)
    pcall(discover_roster)
    pcall(discover_pins)
    if active.runMs then return end
    active.runMs = now
    BGMeter.Log.debug("gates open at %s", BGMeter.Format.duration(active.runMs - (active.startMs or 0)))
end

function Capture.mark_paused()
    if not active then return end
    local A = BGMeter.zenimax.api
    close_run(safe(A.now_ms) or active.startMs)
end

function Capture.abort()
    if not active then return end
    stop_sampler()
    BGMeter.Log.debug("capture aborted (left battleground mid-match)")
    active, baseline = nil, nil
end

function Capture.is_active() return active ~= nil end

function Capture.live()
    if not active then return nil end
    local A = BGMeter.zenimax.api
    return active.name, (safe(A.now_ms) or 0) - (active.startMs or 0)
end

function Capture.snapshot_now()
    local A = BGMeter.zenimax.api
    local Match = BGMeter.Match
    local Vet = BGMeter.Veterancy
    local m = Match.new()
    m.bgId     = safe(A.get_bg_id)
    m.name     = clean_name(m.bgId and safe(A.get_bg_name, m.bgId) or nil)
    m.gameType = safe(A.get_bg_game_type)
    m.localTeam = safe(A.get_local_team)
    m.teamSize = m.bgId and safe(A.get_bg_team_size, m.bgId) or nil
    m.numTeams = m.bgId and safe(A.get_bg_num_teams, m.bgId) or nil
    if m.teamSize then m.competitive = (m.teamSize == 4) end
    m.result   = read_result(m.localTeam)
    Capture.read_battle(m)
    read_teams(m)
    m.haul.vetEnd = Vet.snapshot()
    return m
end

BGMeter.Capture = Capture
