-- Pure Lua ledger. Every entry is an estimate unless its creation, lifetime,
-- identity, and consumption have all been independently verified.
CorpseTracker = CorpseTracker or {}
local CT = CorpseTracker
CT.name, CT.version = "CorpseTracker", "0.3.6"
local Ledger = {}
Ledger.__index = Ledger

local function Finite(value)
    return type(value) == "number" and value == value and
        value ~= math.huge and value ~= -math.huge
end

function CT.NewLedger(mode)
    local ledger = setmetatable({ bodies = {}, seen = {}, created = 0, consumed = 0,
        expired = 0, unmatched = 0, untrackedConsumed = 0, guessed = 0, serial = 0,
        possibilities = { {} }, units = {}, entries = {}, uncertainSpends = {} }, Ledger)
    ledger:SetMode(mode)
    return ledger
end

function Ledger:SetMode(mode)
    local light = mode == "light"
    if self.light == light then return end
    self.light, self.boundsBroad = light, false
    self.possibilities = {}
    if not light then
        local world, included = {}, {}
        for i, body in ipairs(self.bodies) do world[i], included[body.id] = body, true end
        -- Switching views of the ledger cannot turn an earlier guess into
        -- confirmed inventory. Widen the worlds when Light retained choices.
        for _, estimate in ipairs(self.uncertainSpends) do
            for id in pairs(estimate.candidates) do
                local body = self.entries[id]
                if body and not body.exactConsumed then
                    self.boundsBroad = true
                    if not included[id] then
                        world[#world + 1], included[id] = body, true
                    end
                end
            end
        end
        table.sort(world, function(a,b) return a.id < b.id end)
        self.possibilities[1] = world
    end
end

local function Primary(body)
    return body.source == "blastbones" or body.source == "skull?"
end

local function Selected(body, mode)
    return mode ~= "primary" or Primary(body)
end

local function Signature(world)
    local ids = {}
    for i, body in ipairs(world) do ids[i] = tostring(body.id) end
    return table.concat(ids, ",")
end

local function Union(worlds)
    local bodies, seen = {}, {}
    for _, world in ipairs(worlds) do
        for _, body in ipairs(world) do
            if not seen[body.id] then
                bodies[#bodies + 1], seen[body.id] = body, true
            end
        end
    end
    table.sort(bodies, function(a, b) return a.id < b.id end)
    return bodies
end

-- Preserve every possible physical-corpse choice, independently of the FIFO
-- point estimate. Bound the work; overflow widens the range instead of hiding
-- a possible survivor. All bounds still depend on observed creations and TTL.
function Ledger:AdvancePossibilities(allowUntracked, maxBodyId)
    if self.light or self.boundsBroad then return end
    local worlds, seen = {}, {}
    for _, world in ipairs(self.possibilities) do
        -- An unidentified Yard can choose a body absent from this ledger.
        -- Keep that possibility rather than assuming it spent one of ours.
        local picks = {}
        if allowUntracked then picks[#picks + 1] = 0 end
        for i, body in ipairs(world) do
            if not maxBodyId or body.id <= maxBodyId then picks[#picks + 1] = i end
        end
        if #picks == 0 then picks[1] = 0 end
        for _, pick in ipairs(picks) do
            local nextWorld = {}
            for i, body in ipairs(world) do
                if i ~= pick then nextWorld[#nextWorld + 1] = body end
            end
            local key = Signature(nextWorld)
            if not seen[key] then
                if #worlds >= 64 then
                    self.possibilities = { Union(self.possibilities) }
                    self.boundsBroad = true
                    return
                end
                seen[key], worlds[#worlds + 1] = true, nextWorld
            end
        end
    end
    self.possibilities = worlds
end

function Ledger:Accept(key, now, window)
    if key and self.seen[key] and now - self.seen[key] < (window or 0.25) then
        return false
    end
    if key then self.seen[key] = now end
    return true
end

function Ledger:Expire(now)
    for id, body in pairs(self.entries) do
        if body.expires <= now then self.entries[id] = nil end
    end
    for i = #self.uncertainSpends, 1, -1 do
        if self.uncertainSpends[i].expires <= now then table.remove(self.uncertainSpends, i) end
    end
    for i = #self.bodies, 1, -1 do
        if self.bodies[i].expires <= now then
            table.remove(self.bodies, i)
            self.expired = self.expired + 1
        end
    end
    if not self.light then
        local worlds, seen = {}, {}
        for _, world in ipairs(self.possibilities) do
            for i = #world, 1, -1 do
                if world[i].expires <= now then table.remove(world, i) end
            end
            local key = Signature(world)
            if not seen[key] then seen[key], worlds[#worlds + 1] = true, world end
        end
        self.possibilities = worlds
        if self.boundsBroad and #worlds[1] == 0 then self.boundsBroad = false end
    end
    for key, stamp in pairs(self.seen) do
        if now - stamp > 60 then self.seen[key] = nil end
    end
    for unitId, body in pairs(self.units) do
        if now - body.expires > 60 then self.units[unitId] = nil end
    end
end

function Ledger:BindIdentity(body, unitId)
    if body and Finite(unitId) and unitId > 0 and unitId == math.floor(unitId) then
        body.unitId = unitId
        self.units[unitId] = body
        return true
    end
    return false
end

function Ledger:Add(source, now, ttl, position, key, window, unitId)
    if not Finite(now) or not Finite(ttl) or ttl <= 0 or ttl > 60 then return false end
    self:Expire(now)
    if not ttl or ttl <= 0 or not self:Accept(key, now, window) then return false end
    self.serial = self.serial + 1
    local body = { id = self.serial, source = source,
        created = now, expires = now + ttl, position = position }
    self.bodies[#self.bodies + 1] = body
    self.entries[body.id] = body
    for _, world in ipairs(self.possibilities) do world[#world + 1] = body end
    self:BindIdentity(body, unitId)
    self.created = self.created + 1
    return true
end

-- Exact identity can invalidate several consecutive guesses. Move the
-- assignments along an eligible chain; a later-born corpse is reached only
-- through a later spend that actually had it available, never retroactively.
function Ledger:ReconcileSpend(target)
    local active, visited = {}, { [target.id] = true }
    for index, body in ipairs(self.bodies) do active[body.id] = index end
    local function Assign(estimate)
        local candidates = {}
        for id in pairs(estimate.candidates) do
            local body = self.entries[id]
            if body and not body.exactConsumed and not visited[id] then
                candidates[#candidates + 1] = body
            end
        end
        table.sort(candidates, function(a,b)
            return a.expires < b.expires or (a.expires == b.expires and a.id < b.id)
        end)
        for _, body in ipairs(candidates) do
            visited[body.id] = true
            local index = active[body.id]
            local other = body.spendEstimate
            if not index and other and other ~= estimate and other.assigned == body then
                index = Assign(other)
            end
            if index then
                local previous = estimate.assigned
                if previous and previous.spendEstimate == estimate then
                    previous.spendEstimate, previous.estimatedSpend = nil, nil
                end
                estimate.assigned = body
                body.spendEstimate, body.estimatedSpend = estimate, estimate.candidates
                return index
            end
        end
    end
    return target.spendEstimate and Assign(target.spendEstimate)
end

-- Unknown identity: oldest expiry is a heuristic, not the game's targeting rule.
-- This method must be called once per successful consumption, never per damage hit.
function Ledger:Consume(amount, now, key, ambiguous, targetUnitId, options)
    if not Finite(now) or not Finite(amount) or amount < 1 or amount > 10 then return false end
    self:Expire(now)
    if not self:Accept(key, now) then return false end
    amount = math.max(0, math.floor(amount or 0))
    self.consumed = self.consumed + amount
    if ambiguous then self.guessed = self.guessed + amount end
    local target = amount == 1 and targetUnitId and self.units[targetUnitId]
    if not target and options and options.strictTarget and
            type(targetUnitId) == "number" and targetUnitId > 0 then
        self.untrackedConsumed = self.untrackedConsumed + amount
        return true, "untracked"
    end
    if target then
        if self.light then
            for i, body in ipairs(self.bodies) do
                if body.id == target.id then
                    table.remove(self.bodies, i)
                    target.exactConsumed = true
                    return true, "identified", target.source
                end
            end
            -- An exact Siphon can prove that our earlier unidentified spend
            -- chose the wrong corpse. Reassign that estimate only to a body
            -- eligible at the original spend; never consume a later creation.
            if target.estimatedSpend and not target.exactConsumed and target.expires > now then
                local pick = self:ReconcileSpend(target)
                if pick then
                    table.remove(self.bodies, pick)
                    target.estimatedSpend, target.exactConsumed = nil, true
                    return true, "reconciled", target.source
                end
            end
            if target.expires > now then target.exactConsumed = true end
            self.unmatched = self.unmatched + 1
            return true, "known-unavailable", target.source
        end
        local worlds, seen = {}, {}
        for _, world in ipairs(self.possibilities) do
            local nextWorld, found = {}, false
            for _, body in ipairs(world) do
                if body.id == target.id then found = true
                else nextWorld[#nextWorld + 1] = body end
            end
            if found then
                local signature = Signature(nextWorld)
                if not seen[signature] then
                    seen[signature], worlds[#worlds + 1] = true, nextWorld
                end
            end
        end
        if #worlds == 0 then
            -- A stale/reused/expired identified body must not spend a different
            -- tracked corpse merely to make the aggregate totals look plausible.
            self.unmatched = self.unmatched + 1
            return true, "known-unavailable", target.source
        end
        self.possibilities = worlds
        local found
        for i, body in ipairs(self.bodies) do
            if body.id == target.id then table.remove(self.bodies, i); found = true; break end
        end
        if not found and self.boundsBroad and target.estimatedSpend then
            local pick = self:ReconcileSpend(target)
            if pick then table.remove(self.bodies, pick); found = true end
        end
        if not found and not self.boundsBroad then
            -- A later exact Siphon target can resolve an earlier ambiguous Yard
            -- choice and invalidate the FIFO point estimate.
            self.bodies = {}
            for _, body in ipairs(worlds[1]) do self.bodies[#self.bodies + 1] = body end
        end
        self.expired = math.max(0, self.created -
            (self.consumed - self.unmatched - self.untrackedConsumed) - #self.bodies)
        target.estimatedSpend, target.exactConsumed = nil, true
        return true, "identified", target.source
    end
    for _ = 1, amount do
        self:AdvancePossibilities(options and options.allowUntracked, options and options.maxBodyId)
        local candidates, candidateCount, lastExpiry
        do
            candidates, candidateCount, lastExpiry = {}, 0, now
            -- Earlier unidentified spends may have chosen different bodies.
            -- Include all still-live creations, even if the point estimate
            -- removed one of them; exact consumers exclude their targets.
            for id, body in pairs(self.entries) do
                if not body.exactConsumed and
                        (not options or not options.maxBodyId or id <= options.maxBodyId) then
                    candidates[id] = true
                    candidateCount = candidateCount + 1
                    lastExpiry = math.max(lastExpiry, body.expires)
                end
            end
        end
        local pick
        for i, corpse in ipairs(self.bodies) do
            if (not options or not options.maxBodyId or corpse.id <= options.maxBodyId) and
                    (not pick or corpse.expires < self.bodies[pick].expires) then pick = i end
        end
        local estimate
        if candidateCount > 0 then
            estimate = { assigned = pick and self.bodies[pick], candidates = candidates,
                expires = lastExpiry }
            self.uncertainSpends[#self.uncertainSpends + 1] = estimate
        end
        if pick then
            self.bodies[pick].spendEstimate = estimate
            self.bodies[pick].estimatedSpend = candidates
            table.remove(self.bodies, pick)
        else self.unmatched = self.unmatched + 1 end
    end
    return true, "unknown"
end

-- A conservative lower bound on selected survivors, without ledger worlds.
-- Match unknown spends to distinct live candidates, including bodies removed
-- only by an earlier guess. Exact consumers and expiries leave this pool.
-- Unmatched historical spends can only make this bound lower, never falsely
-- guarantee a corpse. Later births are excluded by the original candidate IDs.
function Ledger:GuaranteedCount(now, mode, total, include)
    if total == 0 or #self.uncertainSpends == 0 then return total end
    local eligible, matched, live = {}, {}, 0
    for id, body in pairs(self.entries) do
        if not body.exactConsumed and Selected(body, mode) and (not include or include(body)) then
            eligible[id], live = true, live + 1
        end
    end
    local function Match(index, visited)
        for id in pairs(self.uncertainSpends[index].candidates) do
            if eligible[id] and not visited[id] then
                visited[id] = true
                if not matched[id] or Match(matched[id], visited) then
                    matched[id] = index
                    return true
                end
            end
        end
        return false
    end
    local losses = 0
    for index = 1, #self.uncertainSpends do
        if Match(index, {}) then losses = losses + 1 end
    end
    return math.min(total, math.max(0, live - losses))
end

-- Range is a projection: moving or changing settings never deletes bodies.
local function Location(body, player, radius)
    local p = body.position
    if not p or p.estimated or not player or p.zone ~= player.zone then return "unknown" end
    local dx, dy, dz = p.x - player.x, p.y - player.y, p.z - player.z
    return dx * dx + dy * dy + dz * dz <= (radius * 100) ^ 2 and "inside" or "outside"
end

function Ledger:Count(now, playerPosition, radiusMeters, mode, filter)
    self:Expire(now)
    if self.light then
        local total, nextExpiry = 0, nil
        local breakdown = { bb = 0, skull = 0, other = 0 }
        for _, body in ipairs(self.bodies) do
            local category = body.source == "blastbones" and "bb" or
                body.source == "skull?" and "skull" or "other"
            breakdown[category] = breakdown[category] + 1
            if Selected(body, mode) then
                total = total + 1
                nextExpiry = math.min(nextExpiry or body.expires, body.expires)
            end
        end
        local guaranteed = self:GuaranteedCount(now, mode, total)
        return { total = total, all = #self.bodies, inside = 0, outside = 0,
            unknown = 0, minimum = guaranteed, maximum = total, boundsBroad = false,
            light = true, uncertain = total > 0 and guaranteed == 0, breakdown = breakdown,
            nextExpiry = nextExpiry and nextExpiry - now }
    end
    local inside, outside, unknown, total, nextExpiry = 0, 0, 0, 0, nil
    local function Included(body)
        if not Selected(body, mode) then return false end
        if not filter or not filter.enabled then return true end
        local location = Location(body, playerPosition, filter.range)
        return location == "inside" or (location == "unknown" and filter.includeUnknown)
    end
    local breakdown = { bb = 0, skull = 0, other = 0 }
    for _, corpse in ipairs(self.bodies) do
        local category = corpse.source == "blastbones" and "bb" or
            corpse.source == "skull?" and "skull" or "other"
        breakdown[category] = breakdown[category] + 1
        if Selected(corpse, mode) then
            local location = Location(corpse, playerPosition,
                filter and filter.enabled and filter.range or radiusMeters)
            if location == "inside" then inside = inside + 1
            elseif location == "outside" then outside = outside + 1
            else unknown = unknown + 1 end
            if Included(corpse) then
                total = total + 1
                nextExpiry = math.min(nextExpiry or corpse.expires, corpse.expires)
            end
        end
    end
    local minimum, maximum
    for _, world in ipairs(self.possibilities) do
        local count = 0
        for _, body in ipairs(world) do if Included(body) then count = count + 1 end end
        minimum, maximum = math.min(minimum or count, count), math.max(maximum or count, count)
    end
    if self.boundsBroad then minimum = self:GuaranteedCount(now, mode, total, Included) end
    return { total = total, all = #self.bodies, inside = inside, outside = outside,
        unknown = unknown, minimum = minimum, maximum = maximum,
        boundsBroad = self.boundsBroad, breakdown = breakdown,
        nextExpiry = nextExpiry and nextExpiry - now }
end

-- Independent evidence never silently replaces the ledger.
function CT.ValidateSnapshot(count, radius, verified, now, sampledAt)
    if type(count) ~= "number" or count ~= count or count < 0 or
        count > 2147483647 or count ~= math.floor(count) then return nil end
    if type(radius) ~= "number" or radius ~= radius or radius <= 0 or radius == math.huge then
        return nil
    end
    sampledAt = sampledAt or now
    if type(sampledAt) ~= "number" or sampledAt ~= sampledAt or
        sampledAt > now or sampledAt < now - 60 then return nil end
    return { count = count, radius = radius, verified = verified == true, at = sampledAt }
end
