-- Lazy Crown travel: how long it takes you to get to a target, riding, by
-- transitus from one of our keeps you're near, or with a Keep Recall Stone, and
-- what to tell the group when a shortcut is worth it ("Transit from X to Y.").

LazyCrown = LazyCrown or {}
local T = {}
LazyCrown.Travel = T

-- Measured in game: Vlastarus to Castle Brindle (0.122 of the map, about 1.2 km)
-- took 66 seconds at full sprint without Continuous Attack.
T.SECONDS_PER_UNIT = 540
local TRANSIT_SECONDS = 15  -- the loading screen
local RECALL_SECONDS = 25   -- using the stone, then the loading screen
local SHRINE_RANGE = 0.06   -- a transitus shrine you can ride to first (about 32 seconds)
local NEAR_KEEP = 0.03      -- a recall stone doesn't work this close to a keep
local WORTH_IT = 20         -- seconds a shortcut has to save before it's mentioned
local RIGHT_THERE = 10      -- seconds of riding that need no directions

local function Results(ok, ...)
    if ok then return ... end
end

local function Safe(fn, ...)
    if not fn then return nil end
    return Results(pcall(fn, ...))
end

local AD, EP, DC = ALLIANCE_ALDMERI_DOMINION or 1, ALLIANCE_EBONHEART_PACT or 2, ALLIANCE_DAGGERFALL_COVENANT or 3
-- Each alliance's gate keeps: holding an enemy's doesn't let you use its transitus links.
local GATE_KEEPS = { [3] = DC, [4] = DC, [11] = EP, [12] = EP, [19] = AD, [20] = AD }

local COMPASS = { "east", "northeast", "north", "northwest", "west", "southwest", "south", "southeast" }

-- "Ride northwest." The time it takes is for picking, not for telling. Map y
-- grows to the south.
local function RideLine(from, to)
    local angle = math.deg(math.atan2(from.y - to.y, to.x - from.x)) % 360
    return string.format("Ride %s.", COMPASS[math.floor((angle + 22.5) / 45) % 8 + 1])
end

local function Dist(a, b)
    if not (a and b and a.x and b.x) then return nil end
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Can you travel to or from one of our keeps right now? Not while it's flagged,
-- not once all three of its resources are gone, not if the game says no.
local function Open(keepId, mine, ctx, ownerOf, resourcesOf)
    if ownerOf(keepId) ~= mine then return false end
    if Safe(GetKeepUnderAttack, keepId, ctx) == true then return false end
    if Safe(GetKeepHasResourcesForTravel, keepId, ctx) == false then return false end
    local resources, ours = resourcesOf(keepId), 0
    for _, r in ipairs(resources) do if r.owner == mine then ours = ours + 1 end end
    if #resources > 0 and ours == 0 then return false end
    return Safe(GetKeepAccessible, keepId, ctx) ~= false
end

-- Our transitus shrines (open, ours) and the links between them we own: our
-- keeps, and our alliance's gates too (not targets, so placed where the
-- network says they are).
local function Network(mine, ctx, ownerOf, spotOf, resourcesOf)
    local nodes, byIndex = {}, {}
    for i = 1, Safe(GetNumKeepTravelNetworkNodes, ctx) or 0 do
        local keepId, accessible, nodeX, nodeY = Safe(GetKeepTravelNetworkNodeInfo, i, ctx)
        if keepId and accessible ~= false and Open(keepId, mine, ctx, ownerOf, resourcesOf) then
            local spot = spotOf(keepId)
            local x, y = (spot and spot.x) or nodeX, (spot and spot.y) or nodeY
            if type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0) then
                local node = { keepId = keepId, x = x, y = y, links = {} }
                byIndex[i] = node
                table.insert(nodes, node)
            end
        end
    end
    for i = 1, Safe(GetNumKeepTravelNetworkLinks, ctx) or 0 do
        local _, owner, restricted = Safe(GetKeepTravelNetworkLinkInfo, i, ctx)
        local a, b = Safe(GetKeepTravelNetworkLinkEndpoints, i, ctx)
        local open = owner == mine and (not restricted or restricted == 0 or restricted == mine)
        local enemyGate = byIndex[a] and byIndex[b] and ((GATE_KEEPS[byIndex[a].keepId] or mine) ~= mine or (GATE_KEEPS[byIndex[b].keepId] or mine) ~= mine)
        if open and not enemyGate and byIndex[a] and byIndex[b] then
            table.insert(byIndex[a].links, byIndex[b])
            table.insert(byIndex[b].links, byIndex[a])
        end
    end
    return nodes
end

-- A Keep Recall Stone in your bag, off cooldown.
local function HaveRecallStone()
    local bag = BAG_BACKPACK
    if not (bag and SPECIALIZED_ITEMTYPE_RECALL_STONE_KEEP) then return false end
    for slot = 0, (Safe(GetBagSize, bag) or 0) - 1 do
        local _, specialized = Safe(GetItemType, bag, slot)
        if specialized == SPECIALIZED_ITEMTYPE_RECALL_STONE_KEEP then
            local remain = Safe(GetItemCooldownInfo, bag, slot)
            if not remain or remain <= 0 then return true end
        end
    end
    return false
end

-- Builds the travel picture from where you are. targets: every target, with
-- keepId, kind, owner, name, x, y. Returns a function: target -> { seconds,
-- line, ride } (line is nil when riding is the way to go; ride then says which
-- way, unless it's right there), or nil when your position isn't known.
function T.New(mine, ctx, player, targets, keepName)
    if not (player and player.x) then return nil end
    local byId = {}
    for _, t in ipairs(targets) do byId[t.keepId] = t end
    local function ownerOf(keepId)
        if byId[keepId] then return byId[keepId].owner end
        return Safe(GetKeepAlliance, keepId, ctx) -- an alliance's gate isn't a target
    end
    local function spotOf(keepId) return byId[keepId] end
    local function name(keepId) return (byId[keepId] and byId[keepId].name) or keepName(keepId) end
    local function resourcesOf(keepId)
        local out = {}
        for _, t in ipairs(targets) do if t.parent == keepId then table.insert(out, t) end end
        return out
    end

    -- Where transitus can take you: ride to a shrine nearby, then any of our
    -- keeps linked to it.
    local reach = {}
    local nodes = Network(mine, ctx, ownerOf, spotOf, resourcesOf)
    for _, start in ipairs(nodes) do
        local d = Dist(player, start)
        if d and d <= SHRINE_RANGE then
            local base = d * T.SECONDS_PER_UNIT + TRANSIT_SECONDS
            local seen, queue = { [start] = true }, { start }
            while #queue > 0 do
                local node = table.remove(queue, 1)
                if node ~= start and (not reach[node] or base < reach[node].seconds) then
                    reach[node] = { from = start, seconds = base }
                end
                for _, nextNode in ipairs(node.links) do
                    if not seen[nextNode] then seen[nextNode] = true; table.insert(queue, nextNode) end
                end
            end
        end
    end

    -- Where a recall stone can take you: any of our open keeps, unless you're
    -- right by a keep or fighting.
    local recallTo = {}
    local nearKeep = false
    for _, t in ipairs(targets) do
        if t.kind == "Keep" and Dist(player, t) and Dist(player, t) <= NEAR_KEEP then nearKeep = true end
    end
    if not nearKeep and Safe(IsUnitInCombat, "player") ~= true and HaveRecallStone() then
        for _, t in ipairs(targets) do
            if t.kind == "Keep" and t.x and Open(t.keepId, mine, ctx, ownerOf, resourcesOf) then
                table.insert(recallTo, t)
            end
        end
    end

    local cache = {}
    return function(t)
        if cache[t] then return cache[t] end
        local ride = Dist(player, t)
        if not ride then return nil end
        local best = { seconds = ride * T.SECONDS_PER_UNIT }
        local shortcut
        for node, r in pairs(reach) do
            local d = Dist(node, t)
            local s = d and r.seconds + d * T.SECONDS_PER_UNIT
            if s and (not shortcut or s < shortcut.seconds) then
                shortcut = { seconds = s, line = string.format("Transit from %s to %s.", name(r.from.keepId), name(node.keepId)) }
            end
        end
        for _, keep in ipairs(recallTo) do
            local d = Dist(keep, t)
            local s = d and RECALL_SECONDS + d * T.SECONDS_PER_UNIT
            if s and (not shortcut or s < shortcut.seconds) then
                shortcut = { seconds = s, line = string.format("Use a recall stone to %s.", name(keep.keepId)) }
            end
        end
        if shortcut and shortcut.seconds + WORTH_IT <= best.seconds then
            best = shortcut
        elseif best.seconds >= RIGHT_THERE then
            best.ride = RideLine(player, t)
        end
        cache[t] = best
        return best
    end
end
