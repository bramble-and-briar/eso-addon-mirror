-- Questbound_Teleport.lua : "teleport near this quest". Finds the known wayshrine
-- (or dungeon entrance) closest to the quest's open objectives and offers to
-- travel there, with the cost and recall cooldown.
--
-- How: the map is switched to the quest's zone (SetMapToQuestZone), objective
-- positions are asked for on that map (same request the world map uses) and
-- compared with the fast travel nodes shown on it. A map without wayshrines
-- (delve, dungeon, city) is zoomed out and asked again. Quests without a
-- position fall back to their journal location, then to a node with the
-- quest zone's name (dungeons / trials). The player's map is restored after.

local W = Questbound
local L = W.L
local Tele = {}
W.Teleport = Tele

local NAME = "Questbound_Teleport"
local DIALOG = "QUESTBOUND_TELEPORT"
local WAIT_MS = 500        -- max wait for objective positions on one map
local MAX_ZOOM_OUT = 2
local DUNGEON_PENALTY = 0.01   -- prefer a wayshrine over a dungeon entrance at about the same spot

local job
local Decide

local function Alert(text)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, text)
end

local function Squash(text)
    text = zo_strlower(zo_strformat("<<1>>", text or ""))
    text = text:gsub("^the%s+", "")
    return (text:gsub("[^%w]", ""))
end

-- Known, usable travel nodes (onMapOnly: only those on the current map, with positions).
local function Nodes(onMapOnly)
    local list = {}
    for i = 1, GetNumFastTravelNodes() do
        local known, name, x, y, _, _, poiType, shown, locked = GetFastTravelNodeInfo(i)
        if known and not locked and (poiType == POI_TYPE_WAYSHRINE or poiType == POI_TYPE_GROUP_DUNGEON)
            and (shown or not onMapOnly) then
            list[#list + 1] = {
                node = i, name = zo_strformat("<<1>>", name), x = x, y = y,
                dungeon = poiType == POI_TYPE_GROUP_DUNGEON,
            }
        end
    end
    return list
end

local function Blocked()
    if IsUnitDead("player") then return L("TP_DEAD") end
    if IsUnitInCombat("player") then return L("TP_COMBAT") end
    if IsInAvAZone() then return L("TP_PVP") end
end

-- Node named like the quest's zone (dungeons, trials): "Frostvault" -> "Frostvault" node.
local function ByName(qi)
    local key = Squash((GetJournalQuestLocationInfo(qi)))
    if key == "" then return nil end
    local nodes = Nodes(false)
    for _, exact in ipairs({ true, false }) do
        for _, n in ipairs(nodes) do
            local nk = Squash(n.name)
            if nk ~= "" and (nk == key or (not exact and (nk:find(key, 1, true) or key:find(nk, 1, true)))) then
                return { node = n.node, name = n.name }
            end
        end
    end
end

local function Request()
    job.pending, job.points, job.poi = {}, {}, nil
    local qi = job.qi
    for step = 1, GetJournalQuestNumSteps(qi) do
        local _, visibility, _, _, numConditions = GetJournalQuestStepInfo(qi, step)
        if visibility ~= QUEST_STEP_VISIBILITY_HIDDEN then
            for cond = 1, numConditions or 0 do
                local text, _, _, isFail, isComplete, _, isVisible = GetJournalQuestConditionInfo(qi, step, cond)
                if text and text ~= "" and not isFail and not isComplete and isVisible ~= false then
                    local taskId = RequestJournalQuestConditionAssistance(qi, step, cond, false)
                    if taskId then job.pending[taskId] = true end
                end
            end
        end
    end
    -- the journal's location for the quest, used when no objective has a position
    local _, _, zoneIndex, poiIndex = GetJournalQuestLocationInfo(qi)
    if zoneIndex and poiIndex and poiIndex > 0 then
        local x, y, _, _, shown = GetPOIMapInfo(zoneIndex, poiIndex)
        if shown and x and (x ~= 0 or y ~= 0) then job.poi = { x = x, y = y } end
    end
    if next(job.pending) == nil then
        Decide()
    else
        EVENT_MANAGER:RegisterForUpdate(NAME, WAIT_MS, function() Decide() end)
    end
end

local function OnPosition(_, taskId, _, x, y, _, inside, isBreadcrumb)
    if not job or not job.pending or not job.pending[taskId] then return end
    job.pending[taskId] = nil
    -- breadcrumbs point at an exit ("follow the marker to the next area"), not the objective
    if inside ~= false and not isBreadcrumb and (x ~= 0 or y ~= 0) then
        job.points[#job.points + 1] = { x = x, y = y }
    end
    if next(job.pending) == nil then Decide() end
end

-- Is the map now shown the quest's zone (or the zone around its delve / city)?
local function MapFits()
    if not job.zoneIndex then return true end
    local z = GetCurrentMapZoneIndex()
    return z == job.zoneIndex or (job.parentIndex ~= nil and z == job.parentIndex)
end

-- Opens the map of the zone the journal gives for the quest.
local function SetQuestZoneMap(qi)
    local function ToZone(zoneId)
        if not zoneId or zoneId == 0 or not GetMapIndexByZoneId then return false end
        local mapIndex = GetMapIndexByZoneId(zoneId)
        if not mapIndex then return false end
        return SetMapToMapListIndex(mapIndex) ~= SET_MAP_RESULT_FAILED and MapFits()
    end
    if job.zoneIndex then
        if ToZone(GetZoneId(job.zoneIndex)) then return true end
    end
    if SetMapToQuestZone(qi) ~= SET_MAP_RESULT_FAILED and MapFits() then return true end
    if job.parentId and ToZone(job.parentId) then return true end
    return false
end

local function FormatGold(amount)
    if ZO_Currency_FormatKeyboard then
        return ZO_Currency_FormatKeyboard(CURT_MONEY, amount, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
    end
    return L("TP_GOLD", amount)
end

local function Confirm(result, questName)
    local lines = { L("TP_TO", result.name) }
    if result.dist then lines[#lines + 1] = L("TP_DIST", W.FormatDistance(result.dist)) end
    if result.closer then lines[#lines + 1] = "|cE39A3B" .. L("TP_CLOSER") .. "|r" end
    if result.rough then lines[#lines + 1] = "|c8E8C86" .. L("TP_ROUGH", result.rough) .. "|r" end
    if GetInteractionType() == INTERACTION_FAST_TRAVEL then
        lines[#lines + 1] = L("TP_FREE")
    else
        lines[#lines + 1] = L("TP_COST", FormatGold(GetRecallCost(result.node)))
        local remain = GetRecallCooldown()
        if remain and remain > 0 then
            local s = zo_ceil(remain / 1000)
            lines[#lines + 1] = "|cE39A3B" .. L("TP_COOLDOWN", string.format("%d:%02d", zo_floor(s / 60), s % 60)) .. "|r"
        end
    end
    ZO_Dialogs_ShowDialog(DIALOG, { node = result.node }, {
        titleParams = { questName },
        mainTextParams = { table.concat(lines, "\n") },
    })
end

-- noneKnown: the quest's zone map was shown but you know no wayshrine on it yet
-- (you can only travel to wayshrines you've discovered): say so, with the zone.
local function Finish(result, noneKnown)
    local qi, questName, zoneName, silent = job.qi, job.name, job.zoneName, job.silent
    job = nil
    SetMapToPlayerLocation()
    CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    W.Nav.busy = false
    W.Nav.RequestPositions()
    -- background lookup (the arrow text's travel hint): only a known wayshrine near
    -- the quest's objective counts, no guesses, nothing shown
    if silent then
        silent((result and not result.rough and not result.closer) and result or nil)
        return
    end
    if not result then result = ByName(qi) end
    if result then
        Confirm(result, questName)
    elseif noneKnown and zoneName and zoneName ~= "" then
        Alert(L("TP_NONE_ZONE", zoneName))
    else
        Alert(L("TP_NONE"))
    end
end

Decide = function(failed)
    EVENT_MANAGER:UnregisterForUpdate(NAME)
    if not job then return end
    job.pending = nil   -- late answers are ignored

    local fits = not failed and MapFits()
    local points = job.points or {}
    if #points == 0 and job.poi then points = { job.poi } end
    -- only wayshrines of the quest's own zone, never the one you happen to be in
    local nodes = fits and Nodes(true) or {}

    local best, bestP, bestScore, bestD
    for _, p in ipairs(points) do
        for _, n in ipairs(nodes) do
            local d = math.sqrt((p.x - n.x) ^ 2 + (p.y - n.y) ^ 2)
            local score = d + (n.dungeon and DUNGEON_PENALTY or 0)
            if not best or score < bestScore then
                best, bestP, bestScore, bestD = n, p, score, d
            end
        end
    end

    -- no wayshrines on this map (delve, dungeon, city): look one map up, if that's
    -- still the quest's zone
    if not best and not failed and #nodes == 0 and job.zoom < MAX_ZOOM_OUT
        and MapZoomOut() == SET_MAP_RESULT_MAP_CHANGED and MapFits() then
        job.zoom = job.zoom + 1
        Request()
        return
    end

    local result
    if best then
        result = { node = best.node, name = best.name }
        local cal = W.sv.cal[GetCurrentMapId()]
        if cal then result.dist = bestD * cal.s / 100 end
        -- already in the quest's zone and closer than the wayshrine?
        if GetCurrentMapZoneIndex() == GetUnitZoneIndex("player") then
            local px, py = GetMapPlayerPosition("player")
            if math.sqrt((bestP.x - px) ^ 2 + (bestP.y - py) ^ 2) < bestD then result.closer = true end
        end
    elseif fits and #nodes > 0 then
        -- the quest has no spot on the map yet: a known wayshrine of its zone, near the middle
        local mid
        for _, n in ipairs(nodes) do
            local d = (n.x - 0.5) ^ 2 + (n.y - 0.5) ^ 2
            if not mid or d < mid.d then mid = { n = n, d = d } end
        end
        result = { node = mid.n.node, name = mid.n.name, rough = job.zoneName or "" }
    end
    Finish(result, fits and #nodes == 0)
end

function Tele.Start(qi)
    if job or not qi or not IsValidQuestIndex(qi) then return end
    -- dungeon quests: queue for the dungeon instead of travelling to its entrance
    if W.Dungeon.Offer(qi) then return end
    if ZO_WorldMap_IsWorldMapShowing and ZO_WorldMap_IsWorldMapShowing() then
        Alert(L("TP_MAP_OPEN"))
        return
    end
    local why = Blocked()
    if why then
        Alert(why)
        return
    end
    Tele.Begin(qi)
end

-- Starts the lookup; silent = function(result or nil) for a background lookup
-- (no dialog, no messages).
function Tele.Begin(qi, silent)
    job = { qi = qi, zoom = 0, name = zo_strformat("<<1>>", GetJournalQuestName(qi)), silent = silent }
    -- the zone the journal names for the quest is the one that counts
    local zoneName, _, zoneIndex = GetJournalQuestLocationInfo(qi)
    if zoneIndex and zoneIndex > 0 then
        job.zoneIndex = zoneIndex
        job.zoneName = zo_strformat("<<1>>", zoneName)
        local parentId = GetParentZoneId(GetZoneId(zoneIndex))
        if parentId and parentId ~= 0 and parentId ~= GetZoneId(zoneIndex) then
            job.parentId = parentId
            job.parentIndex = GetZoneIndex(parentId)
        end
    end
    W.Nav.busy = true
    if not SetQuestZoneMap(qi) then
        Decide(true)
        return
    end
    Request()
end

-- Known wayshrine nearest a quest's objective, looked up in the background once per
-- quest step (the lookup switches the map for a moment, so never while the map is
-- open, in combat or busy). Returns the result { node, name, dist }, or nil while
-- unknown / when there is none. Forgotten when you discover a wayshrine.
local found = {}   -- [quest name | step text] = result or false (false also = lookup running)

function Tele.NearestKnown(qi)
    if not qi or not IsValidQuestIndex(qi) then return nil end
    local name, _, stepText = GetJournalQuestInfo(qi)
    local key = (name or "") .. "|" .. (stepText or "")
    local r = found[key]
    if r == nil and not job and not W.Nav.busy and not IsUnitInCombat("player")
        and not (ZO_WorldMap_IsWorldMapShowing and ZO_WorldMap_IsWorldMapShowing()) then
        found[key] = false
        Tele.Begin(qi, function(result) found[key] = result or false end)
    end
    return r or nil
end

-- A wayshrine already picked (the arrow text's "faster by wayshrine" hint): straight
-- to the confirm dialog with cost and cooldown.
function Tele.OfferNode(node, name, dist, questName)
    if job then return end
    local why = Blocked()
    if why then
        Alert(why)
        return
    end
    Confirm({ node = node, name = name, dist = dist }, questName or "")
end

-- Keybind: teleport near the followed quest.
function Tele.StartFollowed()
    local qi = W.Nav.state.questIndex
    if qi then Tele.Start(qi) else Alert(L("TP_NO_QUEST")) end
end

function Tele.Init()
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_QUEST_POSITION_REQUEST_COMPLETE, OnPosition)
    -- a newly discovered wayshrine can change every answer
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_FAST_TRAVEL_NETWORK_UPDATED, function() ZO_ClearTable(found) end)
    ZO_Dialogs_RegisterCustomDialog(DIALOG, {
        title = { text = "<<1>>" },
        mainText = { text = "<<1>>" },
        buttons = {
            {
                text = L("TP_GO"),
                callback = function(dialog)
                    local node = dialog.data and dialog.data.node
                    if node then FastTravelToNode(node) end
                end,
            },
            { text = SI_DIALOG_CANCEL },
        },
    })
end
