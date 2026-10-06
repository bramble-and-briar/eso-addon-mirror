-- DevSandbox3SlotActions.lua: the known spawn locations around me, and which of them have no node
--
-- Data: DevSandbox3_Data[zoneId][map][pinTypeId] = HarvestMap-Data's 8-byte records, metres = (hi*256+lo)*0.2, in the
-- SAME frame HarvestMap locates nodes in (raw world cm / 100, horizontal axes x and "y" = engine z). So a located
-- node and a slot are compared with plain subtraction, like HarvestMap's MapCache:GetMergeableNode (7 m).
--
-- Judgment (the opposite of HarvestMap's spawn filter), three states per slot in range:
--   covered  - a known node within MATCH_M                         -> no dot
--   EMPTY    - no node, and the slot is no farther than the farthest node the compass has placed right now
--              (so the engine demonstrably tracks pins at that distance)                  -> orange / purple
--   UNKNOWN  - no node, but beyond the confirmed distance: the engine may simply not have given us the pin yet
--                                                                                          -> yellow
--   confirmed distance = min(settings.unknownM, farthest node the compass has placed right now)
-- Memory (both in SavedVars, per zone and slot index, expiring after settings.checkedMin minutes; 0 = until the
-- player presses CLEAR CHECKPOINTS). Survives /reloadui and relogs.
--   CHECKPOINT: the player came within settings.checkedM of the slot -> drawn in the checkpoint colour whatever its
--               state, so already-visited empties are told apart from new ones.
--   VERDICT ("distant radar"): once a slot inside the confirmed distance has been judged - EMPTY or COVERED - that
--               verdict holds even if the confirmed distance shrinks again (a far pin vanishing must not flip orange
--               back to yellow, nor make a covered slot reappear yellow). A real change (a node appearing on an EMPTY
--               slot, or a slot's node vanishing while in confirmed range) replaces the verdict at once.
-- Recomputed every tick. The in-range list is only rebuilt when the player has moved REQUERY_M.
local SlotActions = {}

local PinTypeUtils = DevSandbox3.PinTypeUtils
local LogUtils = DevSandbox3.LogUtils

SlotActions.MATCH_M = 7           -- HarvestMap MergeDistanceInMeters
SlotActions.RANGE_M = 200         -- compass maxDistanceM; HarvestMap says detection is reliable to ~100 m - we judge
                                  -- to 200 to find the real limit (fringe false-orange = pins not yet tracked)
SlotActions.CYRODIIL = 181
local REQUERY_M = 5
local CELL = 100                  -- grid cell metres; keys are integers: cx * 100000 + cz (world fits in 0..99999 m)

SlotActions.zoneId = nil
SlotActions.count = 0
SlotActions.grid = {}             -- cellKey -> DevSandbox3Slot[]
SlotActions.inRange = {}          -- slots within RANGE_M of the last query point (reused array)
SlotActions.inRangeCount = 0
SlotActions.empty = {}            -- slot -> true  (rebuilt each tick, reused table)
SlotActions.unknown = {}          -- slot -> true  (rebuilt each tick, reused table)
SlotActions.checked = nil         -- SavedVars table for the current zone: slotIndex -> expiry os seconds (0 = until cleared)
SlotActions.verdicts = nil        -- SavedVars table for the current zone: slotIndex -> { e = 1|0, x = expiry os seconds }
SlotActions.confirmedM = 0        -- confirmed distance this tick
SlotActions.wasEmpty = {}         -- slot -> true last tick (to log empty -> covered transitions with their distance)
SlotActions.canJudge = false
local lastQx, lastQz = math.huge, math.huge

local function CellKey(cx, cz) return cx * 100000 + cz end

---Load every harvestable slot of the player's zone.
function SlotActions.LoadZone()
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    if zoneId == SlotActions.zoneId then return end
    SlotActions.zoneId, SlotActions.count, SlotActions.grid, SlotActions.inRangeCount = zoneId, 0, {}, 0
    lastQx = math.huge
    -- persisted memory for this zone, pruned of expired entries
    local sv = DevSandbox3.state.savedVars
    sv.checkpoints[zoneId] = sv.checkpoints[zoneId] or {}
    sv.verdicts[zoneId] = sv.verdicts[zoneId] or {}
    SlotActions.checked, SlotActions.verdicts = sv.checkpoints[zoneId], sv.verdicts[zoneId]
    local now = GetTimeStamp()
    for k, expiry in pairs(SlotActions.checked) do if expiry ~= 0 and expiry <= now then SlotActions.checked[k] = nil end end
    for k, v in pairs(SlotActions.verdicts) do if v.x ~= 0 and v.x <= now then SlotActions.verdicts[k] = nil end end
    local zone = DevSandbox3_Data and DevSandbox3_Data[zoneId]
    if not zone then LogUtils.Debug("no spawn data for zone %d", zoneId); return end
    local grid, n = SlotActions.grid, 0
    for _, pinTypes in pairs(zone) do
        for pinTypeId, blob in pairs(pinTypes) do
            if PinTypeUtils.HARVESTABLE[pinTypeId] then
                for i = 1, #blob, 8 do
                    local x1, x2, y1, y2, z1, z2 = blob:byte(i, i + 5)
                    n = n + 1
                    local slot = { x = (x1 * 256 + x2) * 0.2, z = (y1 * 256 + y2) * 0.2, h = (z1 * 256 + z2) * 0.2, pinTypeId = pinTypeId, index = n }
                    local k = CellKey(math.floor(slot.x / CELL), math.floor(slot.z / CELL))
                    local cell = grid[k]
                    if not cell then cell = {}; grid[k] = cell end
                    cell[#cell + 1] = slot
                end
            end
        end
    end
    SlotActions.count = n
    LogUtils.Debug("zone %d: %d spawn locations", zoneId, n)
end

---Rebuild inRange around (x, z) if the player moved far enough since the last query.
local function Requery(x, z)
    local dx, dz = x - lastQx, z - lastQz
    if dx * dx + dz * dz < REQUERY_M * REQUERY_M then return end
    lastQx, lastQz = x, z
    local out, n = SlotActions.inRange, 0
    local range = SlotActions.RANGE_M + REQUERY_M   -- pad so the cache stays valid until the next requery
    local r2 = range * range
    for cx = math.floor((x - range) / CELL), math.floor((x + range) / CELL) do
        for cz = math.floor((z - range) / CELL), math.floor((z + range) / CELL) do
            local cell = SlotActions.grid[CellKey(cx, cz)]
            if cell then
                for i = 1, #cell do
                    local s = cell[i]
                    local sx, sz = s.x - x, s.z - z
                    if sx * sx + sz * sz <= r2 then n = n + 1; out[n] = s end
                end
            end
        end
    end
    for i = #out, n + 1, -1 do out[i] = nil end
    SlotActions.inRangeCount = n
end

---Is there a known node within MATCH_M of the slot? A node named as a different type does not count.
---@param slot DevSandbox3Slot
---@return boolean
function SlotActions.HasNode(slot)
    local m2 = SlotActions.MATCH_M * SlotActions.MATCH_M
    local D = DevSandbox3.Detection
    for _, node in pairs(D.located) do
        if not node.pinTypeId or node.pinTypeId == slot.pinTypeId then
            local dx, dz = node.x - slot.x, node.z - slot.z
            if dx * dx + dz * dz <= m2 then return true end
        end
    end
    for node in pairs(D.lingering) do
        if not node.pinTypeId or node.pinTypeId == slot.pinTypeId then
            local dx, dz = node.x - slot.x, node.z - slot.z
            if dx * dx + dz * dz <= m2 then return true end
        end
    end
    return false
end

---Recompute empty / unknown for this tick. (px, pz) = player in the HarvestMap frame.
function SlotActions.Judge(px, pz)
    local D = DevSandbox3.Detection
    Requery(px, pz)
    local empty, unknown = SlotActions.empty, SlotActions.unknown
    for k in pairs(empty) do empty[k] = nil end
    for k in pairs(unknown) do unknown[k] = nil end
    -- confirmed distance: the farthest node the compass has placed for us right now
    local far2 = 0
    for _, node in pairs(D.located) do
        local dx, dz = node.x - px, node.z - pz
        local d2 = dx * dx + dz * dz
        if d2 > far2 then far2 = d2 end
    end
    for node in pairs(D.lingering) do
        local dx, dz = node.x - px, node.z - pz
        local d2 = dx * dx + dz * dz
        if d2 > far2 then far2 = d2 end
    end
    local s = DevSandbox3.state.savedVars.settings
    local cap2 = s.unknownM * s.unknownM
    if far2 > cap2 then far2 = cap2 end
    local limit2 = s.unknownLimitM * s.unknownLimitM
    SlotActions.confirmedM = math.sqrt(far2)
    local canJudge = far2 > 0
    local nowS = GetTimeStamp()
    local checked, verdicts, checked2 = SlotActions.checked, SlotActions.verdicts, s.checkedM * s.checkedM
    local expiry = s.checkedMin == 0 and 0 or (nowS + s.checkedMin * 60)
    local wasEmpty = SlotActions.wasEmpty
    local inRange = SlotActions.inRange
    for i = 1, SlotActions.inRangeCount do
        local slot = inRange[i]
        local dx, dz = slot.x - px, slot.z - pz
        local d2 = dx * dx + dz * dz
        local idx = slot.index
        if d2 <= checked2 then checked[idx] = expiry
        else
            local e = checked[idx]
            if e and e ~= 0 and nowS >= e then checked[idx] = nil end
        end
        if canJudge then
            local hasNode = SlotActions.HasNode(slot)
            local v = verdicts[idx]
            if v and v.x ~= 0 and nowS >= v.x then v = nil; verdicts[idx] = nil end
            if d2 <= far2 then
                -- inside confirmed range: judge now, and remember it
                if not v then v = {}; verdicts[idx] = v end
                v.e, v.x = hasNode and 0 or 1, expiry
                if not hasNode then empty[slot] = true end
            elseif hasNode then
                -- a node is visibly there: covered, and that is the verdict
                if not v then v = {}; verdicts[idx] = v end
                v.e, v.x = 0, expiry
            elseif v then
                -- beyond confirmed range with a remembered verdict: keep it (empty stays orange, covered stays hidden)
                if v.e == 1 then empty[slot] = true end
            elseif d2 <= limit2 then
                unknown[slot] = true
            end
            if hasNode and wasEmpty[slot] then
                -- an EMPTY dot just got covered: a node appeared there. Its distance is the number we are after -
                -- how far out the engine starts reporting pins (false-empty clears at this range).
                LogUtils.Debug("empty -> covered at %dm (type %d)", math.floor(math.sqrt(d2) + 0.5), slot.pinTypeId)
            end
        end
    end
    for k in pairs(wasEmpty) do wasEmpty[k] = nil end
    for k in pairs(empty) do wasEmpty[k] = true end
    SlotActions.canJudge = canJudge
end

---Ground height at (x, z): the nearest in-range slot within MATCH_M, else `fallback`.
function SlotActions.GroundHeight(x, z, fallback)
    local m2, best, bestH = SlotActions.MATCH_M * SlotActions.MATCH_M, nil, fallback
    local inRange = SlotActions.inRange
    for i = 1, SlotActions.inRangeCount do
        local s = inRange[i]
        local dx, dz = s.x - x, s.z - z
        local d2 = dx * dx + dz * dz
        if d2 <= m2 and (not best or d2 < best) then best, bestH = d2, s.h end
    end
    return bestH
end

---Forget every checkpoint and verdict in every zone.
function SlotActions.ClearCheckpoints()
    local sv = DevSandbox3.state.savedVars
    for zoneId in pairs(sv.checkpoints) do sv.checkpoints[zoneId] = nil end
    for zoneId in pairs(sv.verdicts) do sv.verdicts[zoneId] = nil end
    if SlotActions.zoneId then
        sv.checkpoints[SlotActions.zoneId], sv.verdicts[SlotActions.zoneId] = {}, {}
        SlotActions.checked, SlotActions.verdicts = sv.checkpoints[SlotActions.zoneId], sv.verdicts[SlotActions.zoneId]
    end
    LogUtils.Log("checkpoints cleared")
end

---Is this slot a checkpoint (player came within checkedM within the remembered duration)?
function SlotActions.IsChecked(slot)
    local e = SlotActions.checked and SlotActions.checked[slot.index]
    if not e then return false end
    return e == 0 or GetTimeStamp() < e
end

---Which marker an uncovered slot would get if confirmed empty, or nil if the slot is not one we mark at all.
---@return "wartorte"|"psijic"|nil
function SlotActions.MarkerKind(slot)
    local s = DevSandbox3.state.savedVars.settings
    if slot.pinTypeId == PinTypeUtils.ENCHANTING and s.markPsijic then return "psijic" end
    if SlotActions.zoneId == SlotActions.CYRODIIL and s.markWarTorte then return "wartorte" end
    return nil
end

function SlotActions.Initialize()
    EVENT_MANAGER:RegisterForEvent(DevSandbox3.name .. "_SlotsActivated", EVENT_PLAYER_ACTIVATED, SlotActions.LoadZone)
end

DevSandbox3.SlotActions = SlotActions
