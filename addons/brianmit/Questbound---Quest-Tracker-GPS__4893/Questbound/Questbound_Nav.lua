-- Questbound_Nav.lua : works out where to go. Every frame it reads your position,
-- picks the target (map marker or the nearest objective of the followed quest)
-- and hands the result to the arrow and the ground line.
--
-- Quest objective positions come from the same request the world map uses
-- (RequestJournalQuestConditionAssistance), in map coordinates (0..1).
-- The ground line needs world coordinates, and the game has no call that
-- converts between the two, so each map's size is learned while you walk:
-- two positions known both on the map and in the world give scale and offset.
-- Learned sizes are saved (sv.cal), so it only happens once per map.

local W = Questbound
local L = W.L
local Nav = {}
W.Nav = Nav

local NAME = "Questbound_Nav"
local ARRIVE_M = 6          -- closer than this = "you're there"
local CAL_MIN_M = 25        -- walk this far to learn a map's size
local CAL_BETTER = 1.5      -- learn again when a baseline this much longer is available
local CAL_MAX_ERROR_M = 20  -- a saved size this wrong for this map is thrown away
local REFRESH_MS = 8000     -- ask for quest positions again (moving NPCs, late answers)

-- Everything the arrow, the line and the tracker read.
local nav = {
    valid = false,          -- false while the world map shows another map
    mapKey = nil,           -- GetCurrentMapId() of the player's map
    px = 0, py = 0,         -- player on the map (0..1)
    heading = 0,            -- camera heading, radians, counter-clockwise from north
    wx = 0, wy = 0, wz = 0, -- player in the world (cm; wy = height)
    cal = nil,              -- this map's learned size, see Calibrate
    questIndex = nil,       -- followed (assisted) quest
    questName = nil,
    target = nil,           -- { x, y, radius, name, text, kind = "quest"/"waypoint", other }
    distMap = 0,            -- distance in map units
    dist = nil,             -- meters (nil until the map size is known)
    radiusM = 0,            -- objective area radius in meters
    rel = 0,                -- direction relative to where you look (radians, + = to the left)
    arrived = false,
    speed = 0,              -- m/s, smoothed
    eta = nil,              -- seconds
}
Nav.state = nav

local function MapShowing()
    return ZO_WorldMap_IsWorldMapShowing ~= nil and ZO_WorldMap_IsWorldMapShowing()
end

local function WrapAngle(a)
    while a > math.pi do a = a - 2 * math.pi end
    while a < -math.pi do a = a + 2 * math.pi end
    return a
end
Nav.WrapAngle = WrapAngle

-- ---------------------------------------------------------------------------
-- Map size (map coordinates <-> world coordinates)
-- world x = ox + sx * s * mapX ; world z = oz + sz * s * mapY  (s = cm per map, sx/sz = +1 or -1)

local anchor    -- first position seen on this map: { nx, ny, wx, wz }
local badCal = 0

function Nav.MapToWorld(x, y)
    local c = nav.cal
    if not c then return nil end
    return c.ox + c.sx * c.s * x, c.oz + c.sz * (c.s2 or c.s) * y
end

-- World position (cm) -> map spot (0..1).
function Nav.WorldToMap(wx, wz)
    local c = nav.cal
    if not c then return nil end
    return (wx - c.ox) / (c.sx * c.s), (wz - c.oz) / (c.sz * (c.s2 or c.s))
end

-- Exact map size straight from the game: GetRawNormalizedWorldPosition turns a
-- world position into a spot on the current map, so three positions 100 m apart
-- give scale and offset at once (no walking, no few-meter error). s2 = scale of
-- the map's y (world z) when it differs. nil when the game's answer doesn't fit
-- the map you're on (then the size is learned by walking as before).
local EXACT_CM = 10000
local function ExactCalibration(zoneId, wx, wy, wz, px, py)
    local f = GetRawNormalizedWorldPosition
    if type(f) ~= "function" then return nil end
    local x0, y0 = f(zoneId, wx, wy, wz)
    local x1, y1 = f(zoneId, wx + EXACT_CM, wy, wz)
    local x2, y2 = f(zoneId, wx, wy, wz + EXACT_CM)
    if not (x0 and y0 and x1 and y1 and x2 and y2) then return nil end
    local ax, az = x1 - x0, y2 - y0
    if math.abs(ax) < 1e-6 or math.abs(az) < 1e-6 then return nil end
    -- the map must not be turned (world x only moves map x, world z only map y)
    if math.abs(y1 - y0) > math.abs(ax) * 0.02 or math.abs(x2 - x0) > math.abs(az) * 0.02 then return nil end
    -- and it must be the map you're on (same spot as GetMapPlayerPosition)
    if math.abs(x0 - px) > 0.003 or math.abs(y0 - py) > 0.003 then return nil end
    local s, s2 = EXACT_CM / math.abs(ax), EXACT_CM / math.abs(az)
    local sx, sz = ax > 0 and 1 or -1, az > 0 and 1 or -1
    return {
        s = s, s2 = s2, sx = sx, sz = sz,
        ox = wx - sx * s * x0, oz = wz - sz * s2 * y0,
        base = 1e9, exact = true,   -- (no math.huge: it doesn't survive the saved variables file)
    }
end

local exactTried = {}   -- [mapKey] = time of the last try
local function TryExact(zoneId, wx, wy, wz, px, py, now)
    if nav.cal and nav.cal.exact then return end
    -- (no size yet: try often, right after a loading screen the positions settle quickly)
    if exactTried[nav.mapKey] and now - exactTried[nav.mapKey] < (nav.cal and 2 or 0.2) then return end
    exactTried[nav.mapKey] = now
    local c = ExactCalibration(zoneId, wx, wy, wz, px, py)
    if c then
        nav.cal = c
        W.sv.cal[nav.mapKey] = c
    end
end

local function Calibrate(nx, ny, wx, wz)
    if nav.cal and nav.cal.exact then return end   -- from the game: nothing to learn
    local cal = nav.cal
    -- a saved size that doesn't fit (other instance of the same map...) is dropped
    if cal then
        local ex, ez = Nav.MapToWorld(nx, ny)
        local err = math.sqrt((ex - wx) ^ 2 + (ez - wz) ^ 2) / 100
        if err > CAL_MAX_ERROR_M then
            badCal = badCal + 1
            if badCal > 30 then
                nav.cal, cal = nil, nil
                W.sv.cal[nav.mapKey] = nil
                anchor = nil
                badCal = 0
            end
        else
            badCal = 0
        end
    end

    if not anchor then
        anchor = { nx = nx, ny = ny, wx = wx, wz = wz }
        return
    end
    local dwx, dwz = wx - anchor.wx, wz - anchor.wz
    local dnx, dny = nx - anchor.nx, ny - anchor.ny
    local base = math.sqrt(dwx * dwx + dwz * dwz)
    local nd = math.sqrt(dnx * dnx + dny * dny)
    if base < CAL_MIN_M * 100 or nd <= 0 then return end
    if cal and base < cal.base * CAL_BETTER then return end

    local s = base / nd
    local sx, sz = cal and cal.sx or 1, cal and cal.sz or 1
    if math.abs(dnx) > nd * 0.3 then sx = (dwx * dnx < 0) and -1 or 1 end
    if math.abs(dny) > nd * 0.3 then sz = (dwz * dny < 0) and -1 or 1 end
    cal = { s = s, sx = sx, sz = sz, ox = wx - sx * s * nx, oz = wz - sz * s * ny, base = base }
    nav.cal = cal
    W.sv.cal[nav.mapKey] = cal
end

function Nav.ResetCalibration()
    ZO_ClearTable(W.sv.cal)
    ZO_ClearTable(exactTried)
    nav.cal, anchor = nil, nil
end

-- ---------------------------------------------------------------------------
-- Quest objective positions

local gen = 0
local resultsGen = 0
local pending = {}   -- [taskId] = { gen, text }
local results = {}   -- answers for the latest request: { x, y, radius, inside, breadcrumb, text }

-- Is this objective about killing monsters? (the constant names differ between game versions)
local KILL_TYPES = {}
for _, name in ipairs({ "QUEST_CONDITION_TYPE_KILL", "QUEST_CONDITION_TYPE_KILL_MONSTER",
    "QUEST_CONDITION_TYPE_KILL_MONSTER_GROUP", "QUEST_CONDITION_TYPE_KILL_UNIQUE" }) do
    if _G[name] then KILL_TYPES[_G[name]] = true end
end
function Nav.IsKillCondition(conditionType)
    return conditionType ~= nil and KILL_TYPES[conditionType] == true
end

-- Objectives the game gives no position for ("Investigate the East Gate"...): when
-- one is done, where you stood is saved (sv.spots[mapId][quest|objective]), and
-- next time (any character, or any player once shipped) it's the target.
local function SpotKey(qi, text)
    return zo_strlower(zo_strformat("<<1>>", GetJournalQuestName(qi) or "")) .. "|"
        .. zo_strlower(zo_strformat("<<1>>", text or ""))
end

function Nav.LearnedSpot(qi, text)
    local list = W.sv.spots and nav.mapKey and W.sv.spots[nav.mapKey]
    return list and list[SpotKey(qi, text)]
end

-- ---------------------------------------------------------------------------
-- Puzzle steps and hints. "/wf mark" saves where you stand as the next step of the
-- objective the arrow is on (sv.marks[mapId]["quest|objective"] = { {x, y, wy}, ... }),
-- "/wf hint <text>" a short tip for it (sv.hints["quest|objective"]). Both are shipped
-- to other players with the route data. The arrow then leads step by step (1 -> 2 -> 3)
-- and the tip shows under the objective in the tracker.

local MARK_REACHED_M = 3
local markDone = {}   -- [key] = steps reached this session

function Nav.ObjectiveKey(qi, text) return SpotKey(qi, text) end

local function MarksFor(key)
    local list = W.sv.marks and nav.mapKey and W.sv.marks[nav.mapKey]
    return list and list[key]
end

function Nav.HintFor(qi, text)
    if not qi or not text then return nil end
    local key = SpotKey(qi, text)
    return (W.sv.hints and W.sv.hints[key]) or (W.Hints and W.Hints[key])
end

-- The objective the arrow is on (the game's objective, not a step spot).
local function CurrentObjective()
    local t = nav.target
    if not (t and t.kind == "quest" and t.text and nav.questIndex) then return nil end
    return SpotKey(nav.questIndex, t.text)
end

function Nav.AddMark()
    local key = CurrentObjective()
    if not key or not nav.valid or not nav.mapKey then return nil end
    W.sv.marks = W.sv.marks or {}
    local map = W.sv.marks[nav.mapKey] or {}
    W.sv.marks[nav.mapKey] = map
    local list = map[key] or {}
    map[key] = list
    list[#list + 1] = { x = nav.px, y = nav.py, wy = nav.groundY or nav.wy }
    markDone[key] = #list   -- you're standing on it: don't lead back here now
    return #list
end

function Nav.ClearMarks()
    local key = CurrentObjective()
    local map = key and W.sv.marks and W.sv.marks[nav.mapKey]
    if not map or not map[key] then return false end
    map[key] = nil
    markDone[key] = nil
    return true
end

function Nav.SetHint(text)
    local key = CurrentObjective()
    if not key then return false end
    W.sv.hints = W.sv.hints or {}
    W.sv.hints[key] = (text and text ~= "") and text or nil
    return true
end

-- The next step spot of an objective (or nil when it has none / all reached).
local function NextMark(qi, text)
    local key = SpotKey(qi, text)
    local list = MarksFor(key)
    if not list or #list == 0 or not nav.cal then return nil end
    local i = (markDone[key] or 0) + 1
    while i <= #list do
        local m = list[i]
        local d = math.sqrt((m.x - nav.px) ^ 2 + (m.y - nav.py) ^ 2) * nav.cal.s / 100
        if d > MARK_REACHED_M then return m, i, #list end
        markDone[key] = i
        i = i + 1
    end
    return nil
end
Nav.NextMark = NextMark
function Nav.ForgetMarkProgress() ZO_ClearTable(markDone) end

local function OnConditionChanged(_, qi, _, conditionText, _, _, _, _, isFail, _, _, _, isConditionComplete)
    if isFail or not isConditionComplete or not nav.valid or not nav.mapKey then return end
    W.sv.spots = W.sv.spots or {}
    local list = W.sv.spots[nav.mapKey] or {}
    W.sv.spots[nav.mapKey] = list
    local key = SpotKey(qi, conditionText)
    if not list[key] then
        list[key] = { x = nav.px, y = nav.py, wy = nav.groundY or nav.wy }
    end
end
Nav.OnConditionChanged = OnConditionChanged

-- The pin position the game's world map holds for an objective (the world map and
-- minimap addons read it from WORLD_MAP_QUEST_BREADCRUMBS), or nil.
local function MapSteps(qi)
    local bc = WORLD_MAP_QUEST_BREADCRUMBS
    if not (bc and bc.GetSteps) then return nil end
    local ok, steps = pcall(bc.GetSteps, bc, qi)
    return ok and type(steps) == "table" and steps or nil
end

-- Every pin the world map holds for a quest: { { step, cond, data } }
function Nav.MapPinsOf(qi)
    local out = {}
    for s, conds in pairs(MapSteps(qi) or {}) do
        if type(conds) == "table" then
            for c, d in pairs(conds) do
                if type(d) == "table" and d.xLoc and d.yLoc and (d.xLoc ~= 0 or d.yLoc ~= 0) then
                    out[#out + 1] = { step = s, cond = c, data = d }
                end
            end
        end
    end
    return out
end

function Nav.MapPinFor(qi, step, cond)
    local steps = MapSteps(qi)
    local c = steps and steps[step] and steps[step][cond]
    if type(c) == "table" and c.xLoc and c.yLoc and (c.xLoc ~= 0 or c.yLoc ~= 0) then return c end
    -- the indexes may differ from the journal's: with one open objective, any pin will do
    local all = Nav.MapPinsOf(qi)
    if #all == 1 then return all[1].data end
    return nil
end

-- /wf obj: what the world map holds for the followed quest
function Nav.MapPinsText(qi)
    local bc = WORLD_MAP_QUEST_BREADCRUMBS
    if not bc then return "no WORLD_MAP_QUEST_BREADCRUMBS" end
    local steps = MapSteps(qi)
    if not steps then return "nothing for this quest" end
    local parts = {}
    for s, conds in pairs(steps) do
        for c, d in pairs(type(conds) == "table" and conds or {}) do
            parts[#parts + 1] = string.format("step %s cond %s: %s", tostring(s), tostring(c),
                type(d) == "table" and string.format("%.3f, %.3f%s", d.xLoc or -1, d.yLoc or -1,
                    d.insideCurrentMapWorld == false and " (other map)" or "") or tostring(d))
        end
    end
    return #parts > 0 and table.concat(parts, "; ") or "empty"
end

-- clear = drop the old answers now (other quest / map); else they stay until new ones arrive
function Nav.RequestPositions(clear)
    gen = gen + 1
    -- (answers still on their way from an earlier request for this quest stay welcome,
    -- see OnPosition; only a real change throws them away)
    if clear then ZO_ClearTable(pending) end
    if clear then ZO_ClearTable(results) end
    local qi = nav.questIndex
    Nav.reqInfo = { asked = 0, noId = 0 }
    Nav.openTexts = {}
    if not qi or not IsValidQuestIndex(qi) or MapShowing() or Nav.busy then
        Nav.reqInfo.skipped = not qi and "no quest followed" or MapShowing() and "world map open"
            or Nav.busy and "teleport lookup busy" or "quest gone"
        return
    end
    Nav.stepText, Nav.stepTalk = nil, false
    for step = 1, GetJournalQuestNumSteps(qi) do
        local _, visibility, stepType, overrideText, numConditions = GetJournalQuestStepInfo(qi, step)
        if visibility ~= QUEST_STEP_VISIBILITY_HIDDEN then
            -- a step whose text is its own (turn-in steps: "Talk to Snaruga at the Camp") and
            -- that has no objective to ask about: its text still names the target (the
            -- world-map-pin fallback in PickTarget uses it), a turn-in = someone to talk to
            if overrideText and overrideText ~= "" and not Nav.stepText then
                Nav.stepText = zo_strformat("<<1>>", overrideText)
                Nav.stepTalk = stepType == QUEST_STEP_TYPE_END
            end
            for cond = 1, numConditions or 0 do
                local text, _, _, isFail, isComplete, _, isVisible, conditionType = GetJournalQuestConditionInfo(qi, step, cond)
                if text and text ~= "" and not isFail and not isComplete and isVisible ~= false then
                    local taskId = RequestJournalQuestConditionAssistance(qi, step, cond, true)
                        or RequestJournalQuestConditionAssistance(qi, step, cond)
                    Nav.reqInfo.asked = Nav.reqInfo.asked + 1
                    Nav.openTexts[#Nav.openTexts + 1] = zo_strformat("<<1>>", text)
                    if not taskId then
                        Nav.reqInfo.noId = Nav.reqInfo.noId + 1
                        -- the game's world map already asked for this one (it then gives
                        -- no second answer): its pin position, like the map shows it
                        local bc = Nav.MapPinFor(qi, step, cond)
                        local spot = not bc and Nav.LearnedSpot(qi, text)
                        if bc then
                            if resultsGen ~= gen then
                                ZO_ClearTable(results)
                                resultsGen = gen
                            end
                            results[#results + 1] = {
                                x = bc.xLoc, y = bc.yLoc, radius = bc.areaRadius or 0,
                                inside = bc.insideCurrentMapWorld, breadcrumb = bc.isBreadcrumb,
                                pin = bc.pinType, fromMap = true,
                                text = zo_strformat("<<1>>", text),
                                talk = conditionType == QUEST_CONDITION_TYPE_TALK_TO or stepType == QUEST_STEP_TYPE_END,
                                kill = Nav.IsKillCondition(conditionType),
                            }
                            Nav.reqInfo.fromMap = (Nav.reqInfo.fromMap or 0) + 1
                        elseif spot then
                            if resultsGen ~= gen then
                                ZO_ClearTable(results)
                                resultsGen = gen
                            end
                            results[#results + 1] = {
                                x = spot.x, y = spot.y, radius = 0, learned = true,
                                text = zo_strformat("<<1>>", text),
                                talk = conditionType == QUEST_CONDITION_TYPE_TALK_TO,
                            }
                        end
                    end
                    if taskId then
                        pending[taskId] = {
                            gen = gen, qi = qi, text = zo_strformat("<<1>>", text),
                            -- someone to talk to (also the hand-in at the end): NPC marker
                            talk = conditionType == QUEST_CONDITION_TYPE_TALK_TO or stepType == QUEST_STEP_TYPE_END,
                            -- monsters to kill: red hunting area
                            kill = Nav.IsKillCondition(conditionType),
                        }
                    end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Positions of every quest on this map (distances in the tracker, nearest
-- first, shift-click map marker). Asked again every ALL_MS.

local ALL_MS = 10000
local allGen = 0
local allPending = {}   -- [taskId] = { gen, qi }
local allSeen = {}      -- [qi] = gen of the answers now in questPos
Nav.questPos = {}       -- [qi] = { x, y } nearest objective on this map

function Nav.RequestAll()
    if MapShowing() or Nav.busy or not nav.mapKey then return end
    allGen = allGen + 1
    ZO_ClearTable(allPending)
    for qi = 1, MAX_JOURNAL_QUESTS do
        -- (not the followed quest: it has its own request, and asking the game twice
        -- for the same objective can cancel the first answer)
        if IsValidQuestIndex(qi) and qi ~= nav.questIndex then
            for step = 1, GetJournalQuestNumSteps(qi) do
                local _, visibility, _, _, numConditions = GetJournalQuestStepInfo(qi, step)
                if visibility ~= QUEST_STEP_VISIBILITY_HIDDEN and visibility ~= QUEST_STEP_VISIBILITY_OPTIONAL then
                    for cond = 1, numConditions or 0 do
                        local text, _, _, isFail, isComplete, _, isVisible = GetJournalQuestConditionInfo(qi, step, cond)
                        if text and text ~= "" and not isFail and not isComplete and isVisible ~= false then
                            local taskId = RequestJournalQuestConditionAssistance(qi, step, cond, false)
                            if taskId then allPending[taskId] = { gen = allGen, qi = qi } end
                        end
                    end
                end
            end
        end
    end
end

local function OnAllPosition(taskId, x, y, inside, isBreadcrumb)
    local p = allPending[taskId]
    allPending[taskId] = nil
    -- breadcrumbs = "go through this exit": the same spot for every quest elsewhere, not a distance
    if p.gen ~= allGen or inside == false or isBreadcrumb or (x == 0 and y == 0) then return end
    local qi = p.qi
    local old = Nav.questPos[qi]
    if allSeen[qi] ~= allGen then
        allSeen[qi] = allGen
        old = nil   -- first answer of this round replaces last round's
    end
    local d = (x - nav.px) ^ 2 + (y - nav.py) ^ 2
    if not old or d < ((old.x - nav.px) ^ 2 + (old.y - nav.py) ^ 2) then
        Nav.questPos[qi] = { x = x, y = y }
    end
end

-- Where a quest really is, for "next area" / other-zone texts: the journal's place
-- for it (objective name, else its point of interest) and, when that's in another
-- zone than yours, the zone ("Orsinium, Wrothgar"). nil when the journal names nothing.
function Nav.DestinationName(qi)
    if not qi or not IsValidQuestIndex(qi) then return nil end
    local zoneName, objectiveName, zoneIndex, poiIndex = GetJournalQuestLocationInfo(qi)
    local place = objectiveName
    if (not place or place == "") and zoneIndex and poiIndex and poiIndex > 0 then
        place = GetPOIInfo(zoneIndex, poiIndex)
    end
    place = (place and place ~= "") and zo_strformat("<<1>>", place) or nil
    local zone = (zoneName and zoneName ~= "") and zo_strformat("<<1>>", zoneName) or nil
    if not place then return zone end
    if zone and zone ~= place and zoneIndex ~= GetUnitZoneIndex("player") then
        return place .. ", " .. zone
    end
    return place
end

-- Meters to a quest's nearest objective on this map (nil when unknown).
function Nav.QuestDistance(qi)
    if qi == nav.questIndex and nav.target and nav.target.kind == "quest" then return nav.dist end
    local p = Nav.questPos[qi]
    if not p or not nav.cal then return nil end
    return math.sqrt((p.x - nav.px) ^ 2 + (p.y - nav.py) ^ 2) * nav.cal.s / 100
end

-- Map marker on a quest's objective (shift-click in the tracker).
function Nav.MarkQuest(qi)
    local p = Nav.questPos[qi]
    if qi == nav.questIndex and nav.target and nav.target.kind == "quest" then p = nav.target end
    if not p then return false end
    PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, p.x, p.y)
    return true
end

local function OnPosition(_, taskId, pinType, x, y, radius, inside, isBreadcrumb)
    -- the same request can belong to both lists (the game may reuse task ids for the
    -- same objective): each list gets the answer
    if allPending[taskId] then
        OnAllPosition(taskId, x, y, inside, isBreadcrumb)
    end
    local p = pending[taskId]
    if not p then return end   -- the world map's own requests
    pending[taskId] = nil
    -- an older request's answer is still good while it's the same quest
    if p.gen ~= gen and p.qi ~= nav.questIndex then return end
    if resultsGen ~= gen then
        ZO_ClearTable(results)
        resultsGen = gen
    end
    -- the same objective answered twice (two requests): keep one
    for k = #results, 1, -1 do
        if results[k].text == p.text and not results[k].fromMap and not results[k].learned then
            table.remove(results, k)
        end
    end
    results[#results + 1] = {
        x = x, y = y, radius = radius or 0,
        inside = inside, breadcrumb = isBreadcrumb, text = p.text, talk = p.talk, kill = p.kill,
        pin = pinType,
    }
end

-- ---------------------------------------------------------------------------
-- Followed quest

local function FindAssisted()
    for i = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(i) and GetTrackedIsAssisted(TRACK_TYPE_QUEST, i) then return i end
    end
end

-- Your own map marker wins over the quest; choosing a quest to follow (or taking a
-- new one) means you want the quest now, so the marker is taken off the map.
local function DropWaypoint()
    local x, y = GetMapPlayerWaypoint()
    if x and y and (x ~= 0 or y ~= 0) then RemovePlayerWaypoint() end
end
Nav.DropWaypoint = DropWaypoint

local assistKnown = false   -- false until the first check after logging in (keeps a saved marker)
local questRemovedAt = -100 -- a quest just finished / abandoned: the game picks the next one itself
local function CheckAssisted(force)
    local qi = FindAssisted()
    if qi ~= nav.questIndex and qi and assistKnown and GetFrameTimeSeconds() - questRemovedAt > 3 then
        DropWaypoint()
    end
    assistKnown = true
    if qi ~= nav.questIndex or force then
        if qi ~= nav.questIndex and Nav.ForgetCompassSpots then Nav.ForgetCompassSpots() end
        nav.questIndex = qi
        nav.questName = qi and zo_strformat("<<1>>", GetJournalQuestName(qi)) or nil
        Nav.RequestPositions(true)
        W.callbacks:FireCallbacks("TargetChanged")
    end
end

function Nav.Assist(questIndex)
    if not questIndex or not IsValidQuestIndex(questIndex) then return end
    DropWaypoint()   -- also when clicking the quest you already follow
    if FOCUSED_QUEST_TRACKER and FOCUSED_QUEST_TRACKER.ForceAssist then
        FOCUSED_QUEST_TRACKER:ForceAssist(questIndex)
    else
        SetTrackedIsAssisted(TRACK_TYPE_QUEST, true, questIndex)
    end
    CheckAssisted()
end

-- Next quest in the tracker's order (journal order when the tracker has none).
function Nav.AssistNext()
    local order = W.Tracker and W.Tracker.QuestOrder and W.Tracker.QuestOrder() or {}
    if #order == 0 then
        for i = 1, MAX_JOURNAL_QUESTS do
            if IsValidQuestIndex(i) then order[#order + 1] = i end
        end
    end
    if #order == 0 then return end
    local pick = order[1]
    for n, qi in ipairs(order) do
        if qi == nav.questIndex then
            pick = order[n % #order + 1]
            break
        end
    end
    Nav.Assist(pick)
end

-- ---------------------------------------------------------------------------
-- Target

local waypointTarget = { kind = "waypoint", radius = 0 }
local questTarget = { kind = "quest" }

local chosen       -- objective text clicked in the tracker (goes first while it's open)
local lastPicked   -- objective picked last time
-- Does a person's name ("sir jarnot", lowercase) appear in an objective's text?
local function NameMatches(name, text)
    local want = zo_strlower(zo_strformat("<<1>>", text or ""))
    for w in name:gmatch("[^%s%-]+") do
        if #w >= 3 and want:find(w, 1, true) then return true end
    end
    return false
end

-- People you've just talked to: their "talk to" objective can stay open in the
-- journal (the game finishes it later, or it needs more), but you've been there,
-- so the arrow moves on to the next one. Cleared when the quest moves on.
-- Saved (sv.talked[quest name][objective] = true), so it survives /reloadui and
-- logging out while the quest is still on that step.
local function Talked()
    local qi = nav.questIndex
    if not qi then return {} end
    W.sv.talked = W.sv.talked or {}
    local key = zo_strformat("<<1>>", GetJournalQuestName(qi) or "")
    local list = W.sv.talked[key]
    if not list then
        list = {}
        W.sv.talked[key] = list
    end
    return list
end
local talked = setmetatable({}, { __index = function(_, k) return Talked()[k] end })
Nav.lastChatter = nil   -- /wf debug
local chatterName
local function OnChatterBegin()
    local n = GetUnitName("interact")
    if not n or n == "" then n = GetUnitName("reticleover") end
    chatterName = zo_strlower(zo_strformat("<<1>>", n or ""))
    Nav.lastChatter = chatterName
end
local function OnChatterEnd()
    local name = chatterName
    chatterName = nil
    if not name or name == "" then return end
    local list = Talked()
    for _, r in ipairs(results) do
        if r.talk and NameMatches(name, r.text) then
            list[r.text] = true
            if chosen == r.text then chosen = nil end
        end
    end
end
Nav.OnChatterBegin, Nav.OnChatterEnd = OnChatterBegin, OnChatterEnd
-- the quest moved on to its next step: start over (only for that quest)
function Nav.ForgetTalked(qi)
    if not W.sv.talked then return end
    if qi and IsValidQuestIndex(qi) then
        W.sv.talked[zo_strformat("<<1>>", GetJournalQuestName(qi) or "")] = nil
    end
end

-- Objectives the game shows on the compass but gives no position for through the
-- quest request ("Investigate the Bjoulsae Queen (Below)"): when that pin is under
-- the compass center, the game says how far it is, and your view gives the
-- direction, so its spot is known. Averaged over every look; used when the game
-- marks nothing else. (Only the pins under the center right now, never the label:
-- the label lingers after you look away, that went wrong in 0.6.7.)
local compassSpots = {}   -- [objective text] = { x, y, n }
Nav.openTexts = {}        -- open objectives of the followed quest (from RequestPositions)
function Nav.ForgetCompassSpots() ZO_ClearTable(compassSpots) end

function Nav.WatchCompass()
    local container = COMPASS and COMPASS.container
    if not (container and container.GetNumCenterOveredPins and nav.cal and nav.valid) then return end
    for i = 1, container:GetNumCenterOveredPins() do
        local desc = zo_strlower(zo_strformat("<<1>>", container:GetCenterOveredPinDescription(i) or ""))
        desc = zo_strtrim((desc:gsub("|c%w%w%w%w%w%w", ""):gsub("|r", "")))
        local dist = container.GetCenterOveredPinDistance and container:GetCenterOveredPinDistance(i)
        if desc ~= "" and dist and dist > 300 then
            for _, text in ipairs(Nav.openTexts) do
                local want = zo_strlower(text)
                if desc:find(want, 1, true) == 1 then
                    local h = nav.heading
                    local u = dist / nav.cal.s
                    local x, y = nav.px - math.sin(h) * u, nav.py - math.cos(h) * u
                    local s = compassSpots[text]
                    if not s then
                        compassSpots[text] = { x = x, y = y, n = 1 }
                    elseif s.n < 40 then
                        s.n = s.n + 1
                        s.x, s.y = s.x + (x - s.x) / s.n, s.y + (y - s.y) / s.n
                    end
                end
            end
        end
    end
end

local chosenQuest
function Nav.ChooseObjective(text)
    chosen = (chosen ~= text) and text or nil
    chosenQuest = nav.questIndex
    lastPicked = chosen or lastPicked
end

local function PickTarget()
    if chosenQuest ~= nav.questIndex then chosen = nil end   -- other quest followed
    local mode = W.sv.target
    if mode ~= "quest" then
        local x, y = GetMapPlayerWaypoint()
        if x and y and (x ~= 0 or y ~= 0) then
            waypointTarget.x, waypointTarget.y = x, y
            waypointTarget.name = L("WAYPOINT")
            waypointTarget.text = L("WAYPOINT")
            return waypointTarget
        end
    end
    if mode == "waypoint" or not nav.questIndex then return nil end

    -- nearest objective in this map's world; real objectives before "go through here" hints;
    -- the one you clicked in the tracker before all others. The current one is kept
    -- unless another is clearly nearer (no flipping back and forth between two).
    local best, bestD, bestRank
    local chosenThere = false
    for _, r in ipairs(results) do
        if chosen and r.text == chosen then chosenThere = true end
    end
    if chosen and not chosenThere and #results > 0 then chosen = nil end   -- done or gone: back to the nearest
    for _, r in ipairs(results) do
        if r.inside ~= false then
            local rank = r.breadcrumb and 2 or 1
            if talked[r.text] then rank = rank + 1.5 end   -- already talked to: the others first
            -- learned spots (the game gives no position right now) only when the game marks
            -- nothing else: an objective it doesn't mark is often "not yet" (talk to the Crow first)
            if r.learned then rank = rank + 3 end
            if chosen then rank = (r.text == chosen) and 0 or rank + 2 end
            local dx, dy = r.x - nav.px, r.y - nav.py
            local d = dx * dx + dy * dy
            -- staying on the current one: another must be 30 % nearer to take over
            if r.text == lastPicked then d = d * 0.49 end
            if not best or rank < bestRank or (rank == bestRank and d < bestD) then
                best, bestD, bestRank = r, d, rank
            end
        end
    end
    -- nothing (or only learned guesses): a spot read from the compass
    if not best or best.learned then
        for _, text in ipairs(Nav.openTexts) do
            local s = compassSpots[text]
            if s then
                local d = (s.x - nav.px) ^ 2 + (s.y - nav.py) ^ 2
                if not best or best.learned or d < bestD then
                    best, bestD = { x = s.x, y = s.y, radius = 0, text = text, compass = true }, d
                end
            end
        end
    end
    -- 0.15.10: still nothing, but the quest is in your zone ("Talk to Snaruga at the Camp
    -- (Below)": the game marks the spot as another map level / part, a cave or a camp
    -- under you, and those answers were skipped): 1) such an answer, when its spot lies
    -- on this map; 2) else the world map's own pin for the quest
    if not best then
        local _, _, questZone = GetJournalQuestLocationInfo(nav.questIndex)
        local sameZone = not questZone or questZone <= 0 or questZone == GetUnitZoneIndex("player")
        if sameZone then
            for _, r in ipairs(results) do
                if r.inside == false and not r.breadcrumb and r.x >= 0 and r.x <= 1 and r.y >= 0 and r.y <= 1
                    and (r.x ~= 0 or r.y ~= 0) then
                    local d = (r.x - nav.px) ^ 2 + (r.y - nav.py) ^ 2
                    if not best or d < bestD then best, bestD = r, d end
                end
            end
            if not best then
                for _, p in ipairs(Nav.MapPinsOf(nav.questIndex)) do
                    local m = p.data
                    if m.insideCurrentMapWorld ~= false then
                        local d = (m.xLoc - nav.px) ^ 2 + (m.yLoc - nav.py) ^ 2
                        if not best or d < bestD then
                            -- named after the open objective, else the step's own text
                            -- ("Talk to Snaruga at the Camp"; a turn-in = someone to talk to)
                            best, bestD = {
                                x = m.xLoc, y = m.yLoc, radius = m.areaRadius or 0, breadcrumb = m.isBreadcrumb,
                                text = Nav.openTexts[1] or Nav.stepText or nav.questName, fromMap = true,
                                talk = not Nav.openTexts[1] and Nav.stepTalk and not m.isBreadcrumb,
                            }, d
                        end
                    end
                end
            end
        end
    end
    if not best then return nil end
    lastPicked = best.text
    questTarget.x, questTarget.y, questTarget.radius = best.x, best.y, best.radius
    questTarget.bx, questTarget.by = best.x, best.y   -- as the game gave it
    -- "go through here": the door you went through there before, when known
    local door = best.breadcrumb and Nav.DoorFor(best.x, best.y)
    questTarget.door = door or nil
    if door then questTarget.x, questTarget.y, questTarget.radius = door.x, door.y, 0 end
    -- someone to talk to, seen under the crosshair before: their own spot and height
    questTarget.npcY, questTarget.npcSnap = nil, nil
    if best.talk and not best.breadcrumb then
        local nx, ny, nh = Nav.NpcSpot(best.x, best.y)
        if nx then
            questTarget.x, questTarget.y, questTarget.radius, questTarget.npcY = nx, ny, 0, nh
            questTarget.npcSnap = true
        end
    end
    questTarget.name = nav.questName
    questTarget.text = best.text
    questTarget.other = best.breadcrumb
    questTarget.talk = best.talk and not best.breadcrumb
    questTarget.kill = best.kill and not best.breadcrumb
    -- recorded puzzle steps for this objective: lead to the next one
    questTarget.markStep, questTarget.markTotal = nil, nil
    local m, i, n = NextMark(nav.questIndex, best.text)
    if m then
        questTarget.x, questTarget.y, questTarget.radius = m.x, m.y, 0
        questTarget.npcY, questTarget.npcSnap = m.wy, nil
        questTarget.talk, questTarget.kill, questTarget.other, questTarget.door = nil, nil, nil, nil
        questTarget.markStep, questTarget.markTotal = i, n
    end
    return questTarget
end

-- ---------------------------------------------------------------------------
-- Map sync (slow) and per-frame update

local function SyncMap(force)
    if MapShowing() or Nav.busy then return end   -- busy: teleport lookup has the map
    if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
        CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    end
    local key = GetCurrentMapId()
    if key ~= nav.mapKey or force then
        nav.mapKey = key
        nav.cal = W.sv.cal[key]
        anchor, badCal = nil, 0
        ZO_ClearTable(Nav.questPos)
        Nav.RequestPositions(true)
        Nav.RequestAll()
        W.callbacks:FireCallbacks("MapChanged")
    end
end

-- Runs a per-frame part; an error is shown once in chat instead of stopping the others.
local failed = {}
function Nav.Run(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not failed[name] then
        failed[name] = true
        W.Print("|cE0603C" .. name .. " error:|r " .. tostring(err))
    end
end

local lastTime
local lastTarget, lastTargetText
local lastKey

local function Update()
    local now = GetFrameTimeSeconds()
    local dt = lastTime and math.min(now - lastTime, 0.5) or 0
    lastTime = now

    nav.valid = nav.mapKey ~= nil and not MapShowing() and GetCurrentMapId() == nav.mapKey
    if nav.valid then
        local px, py = GetMapPlayerPosition("player")
        local zoneId, wx, wy, wz = GetUnitRawWorldPosition("player")
        nav.zoneId = zoneId
        if dt > 0 then
            local mx, mz = (wx - nav.wx) / 100, (wz - nav.wz) / 100
            local v = math.sqrt(mx * mx + mz * mz) / dt
            if v < 60 then   -- ignore teleports
                nav.speed = nav.speed + (v - nav.speed) * math.min(1, dt * 1.5)
            end
        end
        nav.px, nav.py = px, py
        nav.wx, nav.wy, nav.wz = wx, wy, wz
        nav.heading = GetPlayerCameraHeading()
        TryExact(zoneId, wx, wy, wz, px, py, now)
        Calibrate(px, py, wx, wz)

        local t = PickTarget()
        nav.target = t
        Nav.Run("floor", Nav.ReadFloor)
        if t then
            local dx, dy = t.x - px, t.y - py
            nav.distMap = math.max(0, math.sqrt(dx * dx + dy * dy) - (t.radius or 0))
            -- straight at the objective (the ground arrows show the way round)
            nav.rel = WrapAngle(math.atan2(-dx, -dy) - nav.heading)
            if nav.cal then
                nav.dist = nav.distMap * nav.cal.s / 100
                nav.radiusM = (t.radius or 0) * nav.cal.s / 100
                -- standing under / over it on another floor isn't "there" yet
                local otherFloor = nav.targetLevel == "above" or nav.targetLevel == "below"
                nav.arrived = nav.dist <= ARRIVE_M and not otherFloor
                nav.eta = (nav.speed > 1) and nav.dist / nav.speed or nil
            else
                nav.dist, nav.radiusM, nav.eta = nil, 0, nil
                nav.arrived = nav.distMap <= 0.002
            end
        end
        -- (also when the same target moves on to another objective: the tracker marks it)
        local tText = t and t.text
        if t ~= lastTarget or tText ~= lastTargetText then
            lastTarget, lastTargetText = t, tText
            Nav.Run("tracker", W.callbacks.FireCallbacks, W.callbacks, "TargetChanged")
        end
        -- new objective (other text or moved more than a little): animations start over
        -- (the game's own spot: a corrected spot moving a little isn't a new objective)
        local key = t and ((t.text or "") .. "|" .. zo_round((t.bx or t.x) * 500) .. "|" .. zo_round((t.by or t.y) * 500)) or nil
        if key ~= lastKey then
            lastKey = key
            nav.targetSince = now
        end
    end

    if nav.valid then
        Nav.Run("streets", W.Roads.Record, nav, now)
        Nav.Run("doors", Nav.WatchInteract, now)
        Nav.Run("npc", Nav.WatchReticle)
        Nav.Run("compass", Nav.WatchCompass)
    end
    Nav.Run("arrow", W.Arrow.Update, nav, dt, now)
    Nav.Run("line", W.Path.Update, nav, dt, now)
    Nav.Run("markers", W.Beacon.Update, nav, dt, now)
    Nav.Run("minimap", W.Minimap.Update, nav)
end

-- ---------------------------------------------------------------------------
-- Upstairs / downstairs. Quest positions are flat (map x, y), but the game's
-- compass adds "(Above)" / "(Below)" to the pin label when the objective is on
-- another floor. When you face the objective, that label is read here.

-- English, German, French (au-dessus / en dessous), Spanish
local ABOVE_WORDS = { "above", "oben", "dessus", "arriba", "encima" }
local BELOW_WORDS = { "below", "unten", "dessous", "abajo", "debajo" }

local function Contains(text, words)
    for _, w in ipairs(words) do
        if text:find(w, 1, true) then return true end
    end
    return false
end

-- What the compass said is kept as world heights (cm), not as "above you", so it
-- stays right after you climb the stairs:
--   floor.y         = the objective's height, from the compass's distance to the pin
--                     (a straight line, so height = sqrt(distance^2 - flat distance^2))
--   floor.min / max = somewhere above / below that height (when no height could be worked out)
-- Heights are saved per map and spot (sv.floors), so every objective only has to
-- be in front of you once; after that it's right from the start, also after /reloadui.
local FLOOR_CM = 400      -- one floor, when that floor was never walked
local FLOOR_GAP = 200     -- "above" / "below" means at least this much higher / lower
local SAME_M = 20         -- compass says "same floor" this close: that's its height
local LEVEL_NEAR_M = 40   -- "upstairs / downstairs" only for objectives this close
local SPOT_M = 4          -- saved heights this close (flat) belong to the same objective
local MAX_SAVED = 300     -- saved spots per map
local floor = {}
local floorText, floorX, floorY
Nav.compassSeen = nil     -- last center-overed pin texts (for /wf debug)

-- Saved spot for this objective on this map (created when create is set). Keyed by
-- the spot the game gives (t.bx, t.by), not a corrected one.
local function SavedSpot(t, create)
    if not nav.mapKey or not t then return nil end
    local bx, by = t.bx or t.x, t.by or t.y
    W.sv.floors = W.sv.floors or {}
    local list = W.sv.floors[nav.mapKey]
    local limit = (nav.cal and (SPOT_M * 100 / nav.cal.s) or 0.004) ^ 2
    if list then
        for _, s in ipairs(list) do
            if (s.x - bx) ^ 2 + (s.z - by) ^ 2 <= limit then return s end
        end
    end
    if not create then return nil end
    if not list then
        list = {}
        W.sv.floors[nav.mapKey] = list
    end
    if #list >= MAX_SAVED then table.remove(list, 1) end
    local s = { x = bx, z = by }
    list[#list + 1] = s
    return s
end

-- The NPC's real position. The spot the game gives for "talk to X" is a fixed
-- point near them, not the NPC. When your crosshair is on someone whose name is
-- in the objective ("Merric" in "Talk to Merric"), their own position is saved
-- with the spot (s.nx / s.ny map units, s.nh height cm) and used from then on.
local NPC_NEAR_M = 40      -- the NPC must be this close to the game's spot
Nav.reticleSeen = nil      -- /wf debug
-- (0.7.6 pulled the spot onto your line of sight where no position is given; it
-- dragged the ring along with the crosshair, so it's gone: spots it saved have
-- s.sight and are dropped in Nav.NpcSpot.)
function Nav.WatchReticle()
    local t = nav.target
    if not (nav.cal and nav.questIndex and DoesUnitExist("reticleover")) then return end
    local name = zo_strlower(zo_strformat("<<1>>", GetUnitName("reticleover") or ""))
    if name == "" then return end
    -- any open "talk to" objective of the followed quest (not only the one the arrow
    -- is on right now: you may look at Sir Jarnot while it points at the Crow)
    local hits = {}
    for _, r in ipairs(results) do
        if r.talk and not r.breadcrumb and not r.learned and NameMatches(name, r.text) then hits[#hits + 1] = r end
    end
    local match = #hits > 0
    -- The game answers differently per place (in the open world the first one gave
    -- 0, 0, 0), so three ways are tried: raw world position, world position (turned
    -- into a map spot by the game), and the map spot itself.
    local c = nav.cal
    local mx, my, wy, how
    local zoneId, rx, ry, rz = GetUnitRawWorldPosition("reticleover")
    if rx and (rx ~= 0 or rz ~= 0) and zoneId == nav.zoneId then
        mx = (rx - c.ox) / (c.sx * c.s)
        my = (rz - c.oz) / (c.sz * (c.s2 or c.s))
        wy, how = ry, "raw"
    end
    if not mx and GetUnitWorldPosition and GetNormalizedWorldPosition then
        local z2, ux, uy, uz = GetUnitWorldPosition("reticleover")
        if ux and (ux ~= 0 or uz ~= 0) then
            local nx, ny = GetNormalizedWorldPosition(z2, ux, uy, uz)
            if nx and (nx ~= 0 or ny ~= 0) then
                -- height: same offset as between your own two positions
                local _, _, pwy = GetUnitWorldPosition("player")
                mx, my, wy, how = nx, ny, uy + (nav.wy - (pwy or uy)), "world"
            end
        end
    end
    if not mx then
        local nx, ny = GetMapPlayerPosition("reticleover")
        if nx and (nx ~= 0 or ny ~= 0) then
            mx, my, wy, how = nx, ny, nil, "map"
        end
    end
    Nav.reticleSeen = string.format("%s: %s  (%s)", name,
        mx and string.format("found by %s (%.4f, %.4f)", how, mx, my) or "the game gives no position here",
        match and "matches the objective" or "not the objective")
    if not match or not mx then return end   -- (no position given here: the game's quest spot stays)
    -- the game answering with your own spot = it doesn't give this NPC's position
    if math.abs(mx - nav.px) * c.s < 50 and math.abs(my - nav.py) * c.s < 50 then return end
    for _, r in ipairs(hits) do
        if math.sqrt((mx - r.x) ^ 2 + (my - r.y) ^ 2) * c.s / 100 <= NPC_NEAR_M then
            local s = SavedSpot({ x = r.x, y = r.y }, true)
            s.nx, s.ny, s.nh, s.sight = mx, my, wy, nil
            if t and t.text == r.text then floor.y = wy end
        end
    end
end

-- The NPC's saved position for the game's spot (bx, by): map x, y and height (cm), or nil.
function Nav.NpcSpot(bx, by)
    local s = SavedSpot({ x = bx, y = by })
    if s and s.sight then s.nx, s.ny, s.nh, s.sight = nil, nil, nil, nil end   -- 0.7.6 guess
    if s and s.nx then return s.nx, s.ny, s.nh end
end

local function SaveFloor(t)
    local s = SavedSpot(t, true)
    if s then
        s.y, s.min, s.max = floor.y, floor.min, floor.max
        s.cx, s.cy = nil, nil   -- 0.6.7's compass correction (went wrong): dropped
    end
end

local function Ground()
    return nav.groundY or nav.wy
end

-- The label without "(Above)" etc.: every pin text in brackets at the end.
local function StripSuffix(desc)
    local base = desc
    for _ = 1, 3 do
        local s = base:gsub("%s*[%(%[][^%(%)%[%]]*[%)%]]%s*$", "")
        if s == base then break end
        base = s
    end
    return zo_strtrim(base)
end

local function ForgetFloor()
    ZO_ClearTable(floor)
    nav.targetLevel = nil
end

local function ReadCompassLevel()
    local t = nav.target
    -- new objective (other text, or moved more than a few meters): forget the old floor
    local tbx, tby = t and (t.bx or t.x), t and (t.by or t.y)
    local moved = t and floorX and ((tbx - floorX) ^ 2 + (tby - floorY) ^ 2) > 0.0001
    if not t or t.text ~= floorText or moved then
        ForgetFloor()
        floorText = t and t.text
        floorX, floorY = tbx, tby
        -- seen before: its saved height
        local s = SavedSpot(t)
        if s then floor.y, floor.min, floor.max = s.nh or s.y, s.min, s.max end
    end
    if not t or not t.text then return end
    if not COMPASS then return end
    -- the label the compass shows (first: that's what you see), then the pins under
    -- its center (those also give the distance)
    local texts, dists = {}, {}
    local label = COMPASS.centerOverPinLabel
    if label and label.GetText and not label:IsHidden() and label:GetAlpha() > 0.5 then
        texts[#texts + 1] = label:GetText()
    end
    local container = COMPASS.container
    if container and container.GetNumCenterOveredPins then
        for i = 1, container:GetNumCenterOveredPins() do
            texts[#texts + 1] = container:GetCenterOveredPinDescription(i)
            dists[#texts] = container.GetCenterOveredPinDistance and container:GetCenterOveredPinDistance(i)
        end
    end
    local want = zo_strlower(t.text)
    local seen, level, dist
    for n, text in ipairs(texts) do
        local desc = zo_strlower(zo_strformat("<<1>>", text or ""))
        -- the compass colors "(Above)": drop color codes (|cRRGGBB ... |r) first
        desc = zo_strtrim((desc:gsub("|c%w%w%w%w%w%w", ""):gsub("|r", "")))
        if desc ~= "" then
            seen = seen and (seen .. " | " .. desc) or desc
            local base = StripSuffix(desc)
            local at = desc:find(want, 1, true)
            if base == want or at or (#base >= 4 and want:find(base, 1, true)) then
                if not level then
                    local suffix = at and desc:sub(at + #want) or desc:sub(#base + 1)
                    if Contains(suffix, BELOW_WORDS) then
                        level = "below"
                    elseif Contains(suffix, ABOVE_WORDS) then
                        level = "above"
                    elseif zo_strtrim(suffix) == "" then
                        level = "same"
                    end
                end
                dist = dist or dists[n]
            end
        end
    end
    if seen then Nav.compassSeen = seen end
    if not level then return end

    local g = Ground()
    local flat = nav.cal and math.sqrt((t.x - nav.px) ^ 2 + (t.y - nav.py) ^ 2) * nav.cal.s
    if level == "same" then
        -- close by on your floor: that's its height; far away the compass is too rough
        if flat and flat <= SAME_M * 100 then
            floor.y, floor.min, floor.max = g, nil, nil
        elseif floor.y and math.abs(floor.y - g) > FLOOR_GAP then
            floor.y = nil
        else
            floor.min, floor.max = nil, nil
        end
    else
        local up = level == "above"
        -- height from the straight-line distance, when the compass gave one
        local h
        if dist and flat and dist > flat then
            local rise = math.sqrt(dist * dist - flat * flat)
            if rise >= FLOOR_GAP then h = nav.wy + (up and rise or -rise) end
        end
        if h then
            floor.y, floor.min, floor.max = h, nil, nil
        elseif up then
            floor.min = math.max(floor.min or -math.huge, g + FLOOR_GAP)
            if floor.max and floor.max < floor.min then floor.max = nil end
            if floor.y and floor.y < floor.min then floor.y = nil end
        else
            floor.max = math.min(floor.max or math.huge, g - FLOOR_GAP)
            if floor.min and floor.min > floor.max then floor.min = nil end
            if floor.y and floor.y > floor.max then floor.y = nil end
        end
    end
    SaveFloor(t)
end

-- Where the objective is compared with you now: "above", "below", "same" or nil (not known).
local function UpdateLevel()
    local g = Ground()
    local level
    if floor.y then
        local d = floor.y - g
        level = (d > FLOOR_GAP) and "above" or (d < -FLOOR_GAP) and "below" or "same"
    elseif floor.min and g < floor.min - 50 then
        level = "above"
    elseif floor.max and g > floor.max + 50 then
        level = "below"
    end
    -- floors only mean something close by; far away the land just rises or falls
    if nav.dist and nav.dist > LEVEL_NEAR_M then level = nil end
    nav.targetLevel = level
end

-- Height (cm) of the objective's floor: learned ground on that floor, else
-- about one floor from where the compass said so. nil when it's on your floor
-- (or not known).
function Nav.TargetFloorHeight(tx, tz)
    local level = nav.targetLevel
    if level ~= "above" and level ~= "below" then return nil end
    local x, z = tx / 100, tz / 100
    if floor.y then
        -- ground you walked there beats the compass estimate (that can be a few meters off):
        -- the walked floor on the right side of you, up to a bit past the estimate
        local g = Ground() / 100
        local h
        if level == "above" then
            h = W.Roads.HeightAtLevel(x, z, 6, g + 2, floor.y / 100 + 2)
        else
            h = W.Roads.HeightAtLevel(x, z, 6, floor.y / 100 - 2, g - 2)
        end
        return h and h * 100 or floor.y
    end
    local minY = floor.min and floor.min / 100
    local maxY = floor.max and floor.max / 100
    local step = FLOOR_CM / 100
    -- walked ground there: the nearest floor past the bound first, then any inside the bounds
    local h
    if level == "above" then
        h = W.Roads.HeightAtLevel(x, z, 6, minY, math.min(minY + step, maxY or math.huge))
            or W.Roads.HeightAtLevel(x, z, 6, minY, maxY)
        if h then return h * 100 end
        return floor.min + FLOOR_CM - FLOOR_GAP
    end
    h = W.Roads.HeightAtLevel(x, z, 6, math.max(maxY - step, minY or -math.huge), maxY)
        or W.Roads.HeightAtLevel(x, z, 6, minY, maxY)
    if h then return h * 100 end
    return floor.max - FLOOR_CM + FLOOR_GAP
end

-- Every frame: read the compass, then where the objective is compared with you.
function Nav.ReadFloor()
    -- "next area" (a door): the compass's floor is the NPC's behind it, not the door's
    local t = nav.target
    if t and t.other then
        nav.targetLevel = nil
        return
    end
    ReadCompassLevel()
    UpdateLevel()
end

function Nav.FloorDebugText()
    local c = nav.cal
    return string.format("[0.6.8] map size %s, floor %s  (height %s, min %s, max %s, you %.1f m)  compass: %s",
        c and (c.exact and "exact (from the game)" or "learned by walking") or "unknown", tostring(nav.targetLevel),
        floor.y and string.format("%.1f", floor.y / 100) or "-",
        floor.min and string.format("%.1f", floor.min / 100) or "-",
        floor.max and string.format("%.1f", floor.max / 100) or "-",
        Ground() / 100, Nav.compassSeen or "nothing faced yet")
end

-- ---------------------------------------------------------------------------
-- Doors. "Follow the marker to the next area" points near a door (or a ship,
-- a carriage...), not at it, and the game has no door positions. So when a
-- loading screen starts while such a spot is close, you just went through it:
-- your spot (a step ahead, where you looked) and height are saved as its door
-- (sv.doors[mapId]). Next time the objective goes straight to the door.

local DOOR_NEAR_M = 25    -- went through a door this close to the "next area" spot
local DOOR_MATCH_M = 8    -- the game's spot moves a little between answers
local DOOR_AHEAD_M = 1.2  -- the door is about this far in front of you when you open it
local MAX_DOORS = 200

local function DoorList(create)
    if not nav.mapKey then return nil end
    W.sv.doors = W.sv.doors or {}
    local list = W.sv.doors[nav.mapKey]
    if not list and create then
        list = {}
        W.sv.doors[nav.mapKey] = list
    end
    return list
end

local DOOR_VERSION = 2    -- doors saved before 0.5.7 could be a /reloadui spot: ignored
local USE_S = 2.5         -- a loading screen this soon after "Open" on the crosshair = went through it

-- Saved door for the game's "next area" spot (bx, by) on this map, or nil.
function Nav.DoorFor(bx, by)
    local list = DoorList()
    if not list or not nav.cal then return nil end
    local limit = (DOOR_MATCH_M * 100 / nav.cal.s) ^ 2
    local best, bestD
    for _, d in ipairs(list) do
        if d.v == DOOR_VERSION then
            local dd = (d.bx - bx) ^ 2 + (d.by - by) ^ 2
            if dd <= limit and (not best or dd < bestD) then best, bestD = d, dd end
        end
    end
    return best
end

-- Last time something usable (a door...) was on the crosshair, and where you were.
local lastUse = {}
local function WatchInteract(now)
    if not GetGameCameraInteractableActionInfo then return end
    local action = GetGameCameraInteractableActionInfo()
    if action and action ~= "" then
        lastUse.time = now
        lastUse.px, lastUse.py = nav.px, nav.py
        lastUse.heading = nav.heading
        lastUse.wy = nav.groundY or nav.wy
    end
end

local function RememberDoor()
    local t = nav.target
    if not (nav.valid and t and t.other and t.bx and nav.cal) then return end
    -- only a loading screen right after using something (not /reloadui, logout...)
    if not lastUse.time or GetFrameTimeSeconds() - lastUse.time > USE_S then return end
    -- how far you were from the game's spot (not from an already saved door)
    local flat = math.sqrt((t.bx - lastUse.px) ^ 2 + (t.by - lastUse.py) ^ 2) * nav.cal.s / 100
    if flat > DOOR_NEAR_M then return end
    local step = DOOR_AHEAD_M * 100 / nav.cal.s
    local h = lastUse.heading
    local door = Nav.DoorFor(t.bx, t.by)
    if not door then
        local list = DoorList(true)
        -- old (pre-0.5.7) doors go
        for k = #list, 1, -1 do
            if list[k].v ~= DOOR_VERSION then table.remove(list, k) end
        end
        if #list >= MAX_DOORS then table.remove(list, 1) end
        door = { v = DOOR_VERSION }
        list[#list + 1] = door
    end
    door.bx, door.by = t.bx, t.by
    door.x, door.y = lastUse.px - math.sin(h) * step, lastUse.py - math.cos(h) * step
    door.wy = lastUse.wy
end
Nav.WatchInteract = WatchInteract

-- Doors and floor heights shipped with the addon (Questbound_RouteData.lua) join
-- your own once per map and data version (only ones you don't have yet).
local MERGE_NEAR = 0.002   -- map units: this close = the same door / spot
local function MergePlaces()
    local ship = W.RouteData
    local key = nav.mapKey
    if not ship or not key then return end
    W.sv.placesMerged = W.sv.placesMerged or {}
    if W.sv.placesMerged[key] == ship.version then return end
    W.sv.placesMerged[key] = ship.version
    local function Has(list, x, y, kx, ky)
        for _, d in ipairs(list) do
            if d[kx] and math.abs(d[kx] - x) < MERGE_NEAR and math.abs(d[ky] - y) < MERGE_NEAR then return true end
        end
        return false
    end
    local doors = ship.doors and ship.doors[key]
    if doors then
        local list = DoorList(true)
        for _, d in ipairs(doors) do
            if d.v == DOOR_VERSION and not Has(list, d.bx, d.by, "bx", "by") then
                list[#list + 1] = ZO_ShallowTableCopy(d)
            end
        end
    end
    local marks = ship.marks and ship.marks[key]
    if marks then
        W.sv.marks = W.sv.marks or {}
        local mine = W.sv.marks[key] or {}
        W.sv.marks[key] = mine
        for k, list in pairs(marks) do
            if not mine[k] then
                local copy = {}
                for i, m in ipairs(list) do copy[i] = ZO_ShallowTableCopy(m) end
                mine[k] = copy
            end
        end
    end
    local learned = ship.spots and ship.spots[key]
    if learned then
        W.sv.spots = W.sv.spots or {}
        local mine = W.sv.spots[key] or {}
        W.sv.spots[key] = mine
        for k, s in pairs(learned) do
            if not mine[k] then mine[k] = ZO_ShallowTableCopy(s) end
        end
    end
    local spots = ship.floors and ship.floors[key]
    if spots then
        W.sv.floors = W.sv.floors or {}
        local list = W.sv.floors[key] or {}
        W.sv.floors[key] = list
        for _, s in ipairs(spots) do
            if not Has(list, s.x, s.z, "x", "z") then list[#list + 1] = ZO_ShallowTableCopy(s) end
        end
    end
end

-- Settings > Forget streets: also this map's doors and floor heights.
function Nav.ForgetPlaces()
    if not nav.mapKey then return end
    if W.sv.doors then W.sv.doors[nav.mapKey] = nil end
    if W.sv.floors then W.sv.floors[nav.mapKey] = nil end
    if W.sv.placesMerged then W.sv.placesMerged[nav.mapKey] = nil end   -- shipped ones come back
    ForgetFloor()
    floorText = nil
end

-- The teleport lookup borrows the map (Nav.busy). If it ever gets stuck (an error
-- halfway), positions would never be asked again: after 6 s it's released.
local busySince
-- After a loading screen (door, town, instance, house) the first request can come
-- too early and get nothing: while a quest is followed but has no target yet, ask
-- again every 0.5 s (normally only every REFRESH_MS) for up to 20 s.
local noTargetSince, lastAllRetry = nil, 0
local function FastRetry()
    if nav.questIndex and not nav.target and W.sv.target ~= "waypoint" then
        local now = GetFrameTimeSeconds()
        noTargetSince = noTargetSince or now
        if now - noTargetSince < 20 then
            Nav.RequestPositions()
            -- the tracker's distances too, a little less often
            if not next(Nav.questPos) and now - lastAllRetry > 2 then
                lastAllRetry = now
                Nav.RequestAll()
            end
        end
    else
        noTargetSince = nil
    end
end

local function Slow()
    if Nav.busy then
        busySince = busySince or GetFrameTimeSeconds()
        if GetFrameTimeSeconds() - busySince > 6 then
            Nav.busy = false
            busySince = nil
            Nav.RequestPositions(true)
            Nav.RequestAll()
        end
    else
        busySince = nil
    end
    SyncMap()
    CheckAssisted()
    Nav.Run("shipped places", MergePlaces)
    Nav.Run("fast retry", FastRetry)
end

local function QuestsChanged()
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Changed")
    EVENT_MANAGER:RegisterForUpdate(NAME .. "Changed", 250, function()
        EVENT_MANAGER:UnregisterForUpdate(NAME .. "Changed")
        CheckAssisted(true)
        Nav.RequestAll()
        W.callbacks:FireCallbacks("QuestsChanged")
    end)
end

-- /wf obj: only the objective lines (the full /wf debug scrolls them out of the chat)
function Nav.DebugObjectives()
    local parts = {}
    for _, r in ipairs(results) do
        parts[#parts + 1] = string.format("%s: pin %s%s%s", r.text or "?", tostring(r.pin),
            talked[r.text] and ", TALKED TO" or "", (chosen == r.text) and ", CLICKED" or "")
    end
    W.Print("[0.8.8] objectives: " .. (#parts > 0 and table.concat(parts, "  |  ") or "none"))
    W.Print("[0.8.8] last conversation with: " .. (Nav.lastChatter or "nobody since /reloadui")
        .. "  |  arrow on: " .. tostring(nav.target and nav.target.text))
    local ri = Nav.reqInfo or {}
    W.Print(string.format("[0.9.1] %d objectives asked, %d got no answer from the game, %d taken from the world map's pins",
        ri.asked or 0, ri.noId or 0, ri.fromMap or 0))
    W.Print("[0.9.2] world map pins: " .. (nav.questIndex and Nav.MapPinsText(nav.questIndex) or "no quest"))
end

function Nav.Debug()
    local c = nav.cal
    W.Print(string.format("map %s  pos %.4f, %.4f  quest %s  answers %d  size %s",
        tostring(nav.mapKey), nav.px, nav.py, tostring(nav.questName), #results,
        c and string.format("%.0f m (from %.0f m walk)", c.s / 100, c.base / 100) or "not measured yet"))
    if nav.target then
        W.Print(string.format("target %s (%.4f, %.4f)  %s  arrived %s", nav.target.text or "?", nav.target.x, nav.target.y,
            nav.dist and W.FormatDistance(nav.dist) or "?", tostring(nav.arrived)))
    else
        W.Print("no target (objective not on this map?)")
    end
    -- [0.8.1] what the game answered for the followed quest's objectives
    local waiting = 0
    for _ in pairs(pending) do waiting = waiting + 1 end
    local parts = {}
    for _, r in ipairs(results) do
        parts[#parts + 1] = string.format("%s (%.3f, %.3f, pin %s%s%s%s)", r.text or "?", r.x, r.y, tostring(r.pin),
            r.inside == false and ", other map" or "", r.breadcrumb and ", next area" or "",
            talked[r.text] and ", talked to" or "")
    end
    W.Print(string.format("[0.8.1] objectives: %d answers, %d still waiting: %s", #results, waiting,
        #parts > 0 and table.concat(parts, "; ") or "-"))
    W.Print("[0.8.7] last conversation with: " .. (Nav.lastChatter or "nobody since /reloadui"))
    local ri = Nav.reqInfo or {}
    W.Print(string.format("[0.9.1] last request: %s, %d objectives asked, %d got no request id, %d taken from the world map's pins",
        ri.skipped and ("skipped (" .. ri.skipped .. ")") or "sent", ri.asked or 0, ri.noId or 0, ri.fromMap or 0))
    W.Print(Nav.FloorDebugText())
    local t = nav.target
    W.Print("[0.7.5] crosshair: " .. (Nav.reticleSeen or "no one looked at yet")
        .. ((t and t.npcSnap) and "  |  objective uses the NPC's own position" or "  |  objective uses the game's quest spot")
        .. ((t and t.npcY) and string.format(" (feet %.1f m, you %.1f m)", t.npcY / 100, (nav.groundY or nav.wy) / 100) or ""))
    if t and t.other then
        W.Print(t.door and string.format("[0.5.7] next area: door learned (threshold %.1f m)", t.door.wy / 100)
            or "[0.5.7] next area: door not learned yet (go through it once)")
    end
    if W.Arrow.DebugText then W.Print(W.Arrow.DebugText()) end
    if W.Path.DebugText then W.Print(W.Path.DebugText()) end
    if W.Minimap.DebugText then W.Print(W.Minimap.DebugText()) end
    W.Print(W.Roads.DebugText())
    W.Print(W.TextureReport())
end

function Nav.Init()
    local em = EVENT_MANAGER
    em:RegisterForEvent(NAME, EVENT_QUEST_POSITION_REQUEST_COMPLETE, OnPosition)
    for _, event in ipairs({
        EVENT_QUEST_ADDED, EVENT_QUEST_REMOVED, EVENT_QUEST_ADVANCED, EVENT_QUEST_COMPLETE,
        EVENT_QUEST_CONDITION_COUNTER_CHANGED, EVENT_QUEST_OPTIONAL_STEP_ADVANCED, EVENT_QUEST_LIST_UPDATED,
    }) do
        em:RegisterForEvent(NAME, event, QuestsChanged)
    end
    em:RegisterForEvent(NAME .. "Spots", EVENT_QUEST_CONDITION_COUNTER_CHANGED, OnConditionChanged)
    -- the world map got new pin positions for a quest: ask again (so ours use them too)
    if WORLD_MAP_QUEST_BREADCRUMBS and WORLD_MAP_QUEST_BREADCRUMBS.RegisterCallback then
        WORLD_MAP_QUEST_BREADCRUMBS:RegisterCallback("QuestAvailable", function(qi)
            if qi == nav.questIndex then Nav.RequestPositions() end
        end)
    end
    em:RegisterForEvent(NAME .. "Chat", EVENT_CHATTER_BEGIN, OnChatterBegin)
    em:RegisterForEvent(NAME .. "Chat", EVENT_CHATTER_END, OnChatterEnd)
    -- the quest moved on (next step) or another one is followed: talked-to list starts over
    em:RegisterForEvent(NAME .. "Talked", EVENT_QUEST_ADVANCED, function(_, qi)
        Nav.ForgetTalked(qi)
        Nav.ForgetCompassSpots()
        Nav.ForgetMarkProgress()
    end)
    em:RegisterForEvent(NAME .. "Talked", EVENT_QUEST_REMOVED, function(_, _, _, questName)
        if W.sv.talked and questName then W.sv.talked[zo_strformat("<<1>>", questName)] = nil end
    end)
    -- a new quest: follow it, not your old map marker
    -- a quest you just accepted (from an NPC, a letter...) becomes the one you follow
    -- (setting followNewQuest); otherwise only your map marker goes. A quest you pick in
    -- the tracker afterwards stays followed until you accept the next one.
    em:RegisterForEvent(NAME .. "Added", EVENT_QUEST_ADDED, function(_, journalIndex)
        DropWaypoint()
        if W.sv.followNewQuest and journalIndex then
            -- a moment later: the game finishes adding it (and may focus it itself)
            zo_callLater(function()
                if IsValidQuestIndex(journalIndex) then Nav.Assist(journalIndex) end
            end, 300)
        end
    end)
    -- a finished quest: the game follows the next one by itself; that isn't your choice,
    -- so your map marker stays
    em:RegisterForEvent(NAME .. "Removed", EVENT_QUEST_REMOVED, function() questRemovedAt = GetFrameTimeSeconds() end)
    em:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
        SyncMap(true)
        CheckAssisted(true)
        W.callbacks:FireCallbacks("QuestsChanged")
    end)
    em:RegisterForEvent(NAME, EVENT_ZONE_CHANGED, function() SyncMap() end)
    em:RegisterForEvent(NAME, EVENT_PLAYER_DEACTIVATED, function() Nav.Run("doors", RememberDoor) end)
    em:RegisterForUpdate(NAME .. "Slow", 500, Slow)
    em:RegisterForUpdate(NAME .. "Refresh", REFRESH_MS, function() Nav.RequestPositions() end)
    em:RegisterForUpdate(NAME .. "All", ALL_MS, function() Nav.RequestAll() end)
    em:RegisterForUpdate(NAME, 0, Update)
end
