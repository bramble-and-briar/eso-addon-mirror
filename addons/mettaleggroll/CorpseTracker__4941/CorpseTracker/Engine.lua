-- Pure Lua ledger. Every entry is an estimate unless its creation, lifetime,
-- identity, and consumption have all been independently verified.
CorpseTracker = CorpseTracker or {}
local CT = CorpseTracker
CT.name, CT.version = "CorpseTracker", "0.4.3"
local math, table, string = math, table, string
local Ledger = {}
Ledger.__index = Ledger

local function Finite(value)
    return type(value) == "number" and value == value and
        value ~= math.huge and value ~= -math.huge
end

-- Display selection only. Creation and consumption always retain every source.
CT.sourceKeys = { "bb", "skull", "skeletal", "spirit", "armor", "promise", "banner", "rules" }
local defaultSources = { bb=true, skull=true }
local sourceLabels = { bb="SOURCE_BB", skull="SOURCE_SKULL", skeletal="SOURCE_ARCHER", spirit="SOURCE_SPIRIT",
    armor="SOURCE_ARMOR", promise="SOURCE_PROMISE", banner="SOURCE_BANNER", rules="SOURCE_RULES" }
local function CopySelection(selection)
    local copy = {}
    for _, key in ipairs(CT.sourceKeys) do copy[key] = selection[key] == true end
    return copy
end
-- Read retired saved profiles once. The active legacy mode takes precedence
-- over a remembered, inactive custom mask. Never change the SavedVars schema.
function CT.NormalizeSourceSettings(saved)
    local mode, selection = saved.sourceMode, saved.sourceSelection
    if type(saved.sourceRules) ~= "boolean" then
        saved.sourceRules = mode == "all" or
            ((mode == "custom" or mode == nil) and type(selection) == "table" and selection.rules == true) or false
    end
    if mode == "all" then
        selection = { bb=true, skull=true, skeletal=true, spirit=true, armor=true, promise=true, banner=true }
    elseif mode == "physical" then
        selection = { bb=true, skull=true, skeletal=true, spirit=true, banner=true }
    elseif mode == "virtual" then
        selection = { armor=true, promise=true }
    elseif mode ~= nil and mode ~= "custom" then
        selection = defaultSources
    end
    if type(selection) ~= "table" then selection = defaultSources end
    -- One source switch per skill. Merge old per-morph display choices once;
    -- an explicit new-family false must survive subsequent normalizations.
    local grouped = CopySelection(selection)
    if type(selection.spirit) ~= "boolean" then
        grouped.spirit = selection.guardian == true or selection.mender == true
    end
    saved.sourceSelection = grouped
    saved.sourceSelection.rules = saved.sourceRules
    saved.sourceMode = nil
end
function CT.GetSourceSelection(saved)
    saved = saved or CT.saved
    if not saved then return defaultSources end
    if type(saved.sourceSelection) ~= "table" then CT.NormalizeSourceSettings(saved) end
    saved.sourceSelection.rules = saved.sourceRules == true
    return saved.sourceSelection
end
function CT.CopySourceSelection()
    return CopySelection(CT.GetSourceSelection())
end
function CT.SetSourceEnabled(key, enabled)
    if not sourceLabels[key] then return false end
    local selection = CT.CopySourceSelection()
    selection[key] = enabled == true
    if key == "rules" then CT.saved.sourceRules = enabled == true end
    CT.saved.sourceSelection = selection
    return true
end
local cachedSelection, cachedLanguage, cachedLabel
function CT.SourceLabel()
    local selection = CT.GetSourceSelection()
    if selection ~= cachedSelection or CT.language ~= cachedLanguage then
        local labels = {}
        for _, key in ipairs(CT.sourceKeys) do
            if selection[key] then labels[#labels + 1] = CT.T(sourceLabels[key]) end
        end
        cachedLabel = #labels > 0 and table.concat(labels, ", ") or CT.T("NO_SOURCES")
        cachedSelection, cachedLanguage = selection, CT.language
    end
    return cachedLabel
end

function CT.NewLedger(mode)
    local ledger = setmetatable({ bodies = {}, seen = {}, created = 0, consumed = 0,
        expired = 0, unmatched = 0, untrackedConsumed = 0, guessed = 0, serial = 0,
        possibilities = { {} }, units = {}, entries = {}, uncertainSpends = {} }, Ledger)
    ledger:SetMode(mode)
    return ledger
end

-- A Living Corpse is one effect on the player, not a physical world corpse.
-- Keep it outside the physical ledger and do not infer quantity from stacks=0.
local Living = {}
Living.__index = Living
function CT.NewLivingCorpse()
    return setmetatable({ created = 0, consumed = 0, expired = 0 }, Living)
end
function Living:Expire(now)
    if self.active and self.active.ending <= now then
        self.active = nil
        self.expired = self.expired + 1
    end
    if self.faded and now - self.faded.at > 0.8 then self.faded = nil end
end
function Living:Effect(phase, slot, beginning, ending, now)
    self:Expire(now)
    if phase == "gained" or phase == "updated" then
        if not Finite(ending) or ending <= now or ending > now + 60 then return end
        local refresh = self.active or (self.faded and not self.faded.used and
            math.abs(now - self.faded.at) <= 0.05)
        if not refresh then self.created = self.created + 1 end
        self.active = { slot = slot, beginning = beginning, ending = ending }
        -- A same-frame FADED/GAINED is replacement, not a second spendable item.
        self.faded = nil
        return refresh and "refreshed" or "created"
    elseif phase == "faded" and self.active and self.active.slot == slot then
        local previous = self.active
        self.active = nil
        self.faded = { at = now, ending = previous.ending, beginning = previous.beginning,
            early = previous.ending - now > 0.05 }
        return "faded"
    end
end
function Living:Relevant(now)
    self:Expire(now)
    return self.active ~= nil or (self.faded and now - self.faded.at <= 0.25)
end
function Living:TryConsume(at, now)
    local fade = self.faded
    if not fade or fade.used or not fade.early or math.abs(fade.at - at) > 0.25 or
            now - fade.at > 0.8 or (Finite(fade.beginning) and fade.beginning > at) then return false end
    fade.used = true
    self.consumed = self.consumed + 1
    return true
end
function Living:Project(count, now, selected)
    self:Expire(now)
    if not self.active then count.virtual = 0; return count end
    count.all = count.all + 1
    count.breakdown.other = count.breakdown.other + 1
    count.virtual = selected and 1 or 0
    if selected then
        count.total = count.total + 1
        count.minimum, count.maximum = (count.minimum or 0) + 1, (count.maximum or 0) + 1
        if not count.light then count.inside = count.inside + 1 end
        count.nextExpiry = math.min(count.nextExpiry or math.huge, self.active.ending - now)
        if count.light then count.uncertain = count.total > 0 and count.minimum == 0 end
    end
    return count
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
    if type(mode) == "table" then
        local key = body.source == "blastbones" and "bb" or body.source == "skull?" and "skull" or
            body.source == "skeletal?" and "skeletal" or
            (body.source == "guardian" or body.source == "mender") and "spirit" or
            body.source == "banner" and "banner" or
            (type(body.source) == "string" and body.source:match("^rule:") and "rules")
        return key ~= nil and mode[key] == true
    end
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
        -- Reassign an earlier guessed spend before choosing a replacement
        -- point estimate. Otherwise worlds[1] can be the untracked-consumption
        -- hypothesis and silently restore a corpse already paid for.
        -- Keep those wider possibilities for bounds, not as the point estimate.
        if not found and target.estimatedSpend then
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

-- Malevolent Promise is a target-bound virtual resource. A same-frame fade /
-- gain can spend the old mark and create a new one, so retain faded generations
-- independently of the active marks. Never add them to physical FIFO choices.
local Promise = {}
Promise.__index = Promise
function CT.NewPromise()
    return setmetatable({ marks = {}, recent = {}, serial = 0,
        created = 0, consumed = 0, expired = 0 }, Promise)
end
function Promise:Expire(now)
    for unit, mark in pairs(self.marks) do
        if mark.ending <= now then
            self.marks[unit] = nil
            mark.at, mark.expired = mark.ending, true
            self.recent[#self.recent + 1] = mark
            self.expired = self.expired + 1
        end
    end
    for i = #self.recent, 1, -1 do
        if now - self.recent[i].at > 0.8 then table.remove(self.recent, i) end
    end
end
function Promise:Effect(phase, unit, slot, beginning, ending, now, position)
    self:Expire(now)
    if not Finite(unit) or unit <= 0 or unit ~= math.floor(unit) then return end
    local previous = self.marks[unit]
    if phase == "gained" or phase == "updated" then
        if not Finite(beginning) or not Finite(ending) or ending <= now or
                ending > now + 10 or beginning > now + 0.1 then return end
        -- Updates and duplicate unit-tag routes describe the same active mark.
        if previous and math.abs(previous.beginning - beginning) < 0.01 then
            previous.ending, previous.position = ending, position or previous.position
            return "updated"
        end
        self.serial, self.created = self.serial + 1, self.created + 1
        self.marks[unit] = { unit = unit, slot = slot, beginning = beginning,
            ending = ending, generation = self.serial, position = position }
        return "created"
    elseif phase == "faded" and previous and previous.slot == slot then
        if Finite(beginning) and beginning > 0 and math.abs(beginning - previous.beginning) > 0.01 then return end
        if Finite(ending) and ending > 0 and math.abs(ending - previous.ending) > 0.01 then return end
        self.marks[unit] = nil
        previous.at, previous.early = now, previous.ending - now > 0.05
        self.recent[#self.recent + 1] = previous
        return "faded"
    end
end
function Promise:Relevant(now, unit)
    self:Expire(now)
    if unit and self.marks[unit] then return true end
    if not unit and next(self.marks) then return true end
    for _, mark in ipairs(self.recent) do
        if not mark.used and (not unit or mark.unit == unit) and now - mark.at <= 0.25 then return true end
    end
    return false
end
function Promise:Size(now)
    self:Expire(now)
    local size = 0
    for _ in pairs(self.marks) do size = size + 1 end
    return size
end
function Promise:Snapshot(now)
    self:Expire(now)
    local marks = {}
    for _, mark in pairs(self.marks) do
        marks[#marks + 1] = { unit = mark.unit, beginning = mark.beginning,
            ending = mark.ending, slot = mark.slot, position = mark.position }
    end
    return marks
end
function Promise:TryConsume(at, now, unit, cutoff)
    self:Expire(now)
    local chosen, distance
    for _, mark in ipairs(self.recent) do
        local age = math.abs(mark.at - at)
        if not mark.used and (not unit or mark.unit == unit) and
                (not cutoff or mark.generation <= cutoff) and mark.beginning <= at and
                age <= 0.25 and (mark.early or (unit and mark.ending > at)) and
                (not distance or age < distance) then chosen, distance = mark, age end
    end
    -- An exact application to an observed marked unit is consumption evidence,
    -- even if its FADED callback is missing. A self effect alone is not.
    if not chosen and unit then
        local mark = self.marks[unit]
        if mark and mark.beginning <= at and (not cutoff or mark.generation <= cutoff) then
            chosen = mark
            self.marks[unit] = nil
            mark.at = at
            self.recent[#self.recent + 1] = mark
        end
    end
    if not chosen then return false end
    chosen.used = true
    if chosen.expired then self.expired = self.expired - 1 end
    self.consumed = self.consumed + 1
    return true, chosen.unit
end
function Promise:Project(count, now, selected, playerPosition, radius, filter)
    self:Expire(now)
    count.promise = 0
    for _, mark in pairs(self.marks) do
        count.all, count.breakdown.other = count.all + 1, count.breakdown.other + 1
        if selected then
            local included = true
            if not count.light then
                local location = Location(mark, playerPosition, filter and filter.enabled and filter.range or radius)
                count[location] = count[location] + 1
                included = not filter or not filter.enabled or location == "inside" or
                    (location == "unknown" and filter.includeUnknown)
            end
            if included then
                count.total, count.promise = count.total + 1, count.promise + 1
                count.minimum, count.maximum = (count.minimum or 0) + 1, (count.maximum or 0) + 1
                count.nextExpiry = math.min(count.nextExpiry or math.huge, mark.ending - now)
            end
        end
    end
    if count.light then count.uncertain = count.total > 0 and count.minimum == 0 end
    return count
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

-- Guardian helpers.
do
-- Timed pets (Spirit Guardian / Intensive Mender): cache the own-pet summon,
-- then require a death callback
-- near its recorded end. Recasting/despawning alone never creates a corpse.
local CT = CorpseTracker
local math, pairs, type = math, pairs, type
local Tracker = {}
Tracker.__index = Tracker
local GRACE = 0.25

local function Finite(value)
    return type(value) == "number" and value == value and
        value ~= math.huge and value ~= -math.huge
end

function CT.NewGuardianTracker()
    return setmetatable({ tags = {} }, Tracker)
end

function Tracker:Track(tag, unitId, beginning, ending, now)
    if type(tag) ~= "string" or not tag:match("^playerpet%d+$") or
            not Finite(unitId) or unitId <= 0 or unitId ~= math.floor(unitId) or
            not Finite(beginning) or not Finite(ending) or not Finite(now) or
            beginning > now + GRACE or ending <= beginning or ending - beginning > 60 or
            ending < now - GRACE or ending > now + 60 then return false end
    local previous = self.tags[tag]
    if previous and previous.unitId == unitId and
            math.abs(previous.beginning - beginning) <= GRACE then
        -- Duplicate/updated effect routes must retain the death deduplication.
        previous.ending = ending
        return true
    end
    self.tags[tag] = { unitId = unitId, beginning = beginning, ending = ending }
    return true
end

function Tracker:Death(tag, now)
    local summon = self.tags[tag]
    if not summon or summon.counted or not Finite(now) then return nil end
    summon.counted = true
    if math.abs(now - summon.ending) > GRACE then return nil end
    return summon
end

function Tracker:Forget(tag)
    self.tags[tag] = nil
end

function Tracker:Cleanup(now)
    for tag, summon in pairs(self.tags) do
        if now > summon.ending + 60 then self.tags[tag] = nil end
    end
end

end

-- Consumers helpers.
do
-- Aggregate confirmed consumer markers before reconciling virtual/physical
-- resources. UI casts, healing hits and duration values never enter this queue.
local CT = CorpseTracker
local math, type, ipairs, table = math, type, ipairs, table
local Queue = {}
Queue.__index = Queue
local SETTLE, GROUP_WINDOW = 0.25, 0.35
local EMPTY_READY = {}
local targeted = { blood = true, tether = true, harvest = true }
local function Finite(value)
    return type(value) == "number" and value == value and
        value ~= math.huge and value ~= -math.huge
end

function CT.NewConsumerQueue()
    return setmetatable({ pending = {}, recent = {}, serial = 0 }, Queue)
end

function Queue:Add(kind, now, amount, target, targetType, bodyCutoff, promiseCutoff)
    if (not targeted[kind] and kind ~= "enduring" and kind ~= "renewing") or not Finite(now) or
            not Finite(amount) or amount < 1 or amount > 10 or amount ~= math.floor(amount) then return end
    if kind == "renewing" and amount ~= 1 then return end
    if targeted[kind] and (amount ~= 1 or not Finite(target) or target <= 0 or
            target ~= math.floor(target)) then return end
    for index = #self.recent, 1, -1 do
        local previous = self.recent[index]
        if now - previous.at > GROUP_WINDOW then table.remove(self.recent, index)
        elseif previous.kind == kind and now >= previous.at and
                (not targeted[kind] or (previous.target == target and previous.targetType == targetType)) then
            return -- a duplicate after an immediate/settled commit
        end
    end
    for _, transaction in ipairs(self.pending) do
        if transaction.kind == kind and now >= transaction.at and
                now - transaction.at <= GROUP_WINDOW and
                (not targeted[kind] or (transaction.target == target and transaction.targetType == targetType)) then
            transaction.amount = math.max(transaction.amount, amount)
            transaction.lastAt = now
            return transaction
        end
    end
    if #self.pending >= 32 then return end
    self.serial = self.serial + 1
    local transaction = { serial = self.serial, kind = kind, at = now, lastAt = now,
        amount = amount, target = target, targetType = targetType,
        bodyCutoff = bodyCutoff, promiseCutoff = promiseCutoff }
    self.pending[#self.pending + 1] = transaction
    return transaction
end

function Queue:TakeReady(now, force)
    -- Normal play usually has no pending confirmations. Reuse the read-only
    -- empty result instead of allocating two tables on every HUD refresh.
    if #self.pending == 0 then return EMPTY_READY end
    local ready, retained = {}, {}
    for _, transaction in ipairs(self.pending) do
        if force or now - transaction.lastAt >= SETTLE then
            ready[#ready + 1] = transaction
            self.recent[#self.recent + 1] = transaction
        else retained[#retained + 1] = transaction end
    end
    self.pending = retained
    return ready
end

function Queue:Take(transaction)
    for index, pending in ipairs(self.pending) do
        if pending == transaction then
            table.remove(self.pending, index)
            self.recent[#self.recent + 1] = pending
            return pending
        end
    end
end

end
