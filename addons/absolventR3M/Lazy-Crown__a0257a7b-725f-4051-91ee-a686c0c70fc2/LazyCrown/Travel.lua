LazyCrown=LazyCrown or {}
LazyCrown.later=LazyCrown.later or {}
table.insert(LazyCrown.later,{name="Travel.lua",code=[=[
LazyCrown = LazyCrown or {}
local T = {}
LazyCrown.Travel = T
T.SECONDS_PER_UNIT = 540
local TRANSIT_SECONDS = 15
local RECALL_SECONDS = 25
local SHRINE_RANGE = 0.06
local NEAR_KEEP = 0.03
local WORTH_IT = 20
local RIGHT_THERE = 10
local function Results(ok, ...)
if ok then return ... end
end
local function Safe(fn, ...)
if not fn then return nil end
return Results(pcall(fn, ...))
end
local AD, EP, DC = ALLIANCE_ALDMERI_DOMINION or 1, ALLIANCE_EBONHEART_PACT or 2, ALLIANCE_DAGGERFALL_COVENANT or 3
local GATE_KEEPS = { [3] = DC, [4] = DC, [11] = EP, [12] = EP, [19] = AD, [20] = AD }
local COMPASS = { "east", "northeast", "north", "northwest", "west", "southwest", "south", "southeast" }
local function RideLine(from, to)
local angle = math.deg(math.atan2(from.y - to.y, to.x - from.x)) % 360
return string.format("Ride %s.", COMPASS[math.floor((angle + 22.5) / 45) % 8 + 1])
end
function T.Eta(seconds)
if seconds < 90 then
return string.format("about %d seconds", math.max(5, math.floor(seconds / 5 + 0.5) * 5))
end
return string.format("about %d minutes", math.floor(seconds / 60 + 0.5))
end
local function Dist(a, b)
if not (a and b and a.x and b.x) then return nil end
local dx, dy = a.x - b.x, a.y - b.y
return math.sqrt(dx * dx + dy * dy)
end
local function Open(keepId, mine, ctx, ownerOf, resourcesOf, underAttack)
if ownerOf(keepId) ~= mine then return false end
if underAttack then
if underAttack(keepId) then return false end
elseif Safe(GetKeepUnderAttack, keepId, ctx) == true then
return false
end
if Safe(GetKeepHasResourcesForTravel, keepId, ctx) == false then return false end
local resources, ours = resourcesOf(keepId), 0
for _, r in ipairs(resources) do if r.owner == mine then ours = ours + 1 end end
if #resources > 0 and ours == 0 then return false end
return Safe(GetKeepAccessible, keepId, ctx) ~= false
end
local linkEnds = {}
local function LinkEnds(ctx, nodeCount, linkCount)
if linkEnds.ctx ~= ctx or linkEnds.nodes ~= nodeCount or linkEnds.links ~= linkCount then
linkEnds = { ctx = ctx, nodes = nodeCount, links = linkCount }
for i = 1, linkCount do
local a, b = Safe(GetKeepTravelNetworkLinkEndpoints, i, ctx)
linkEnds[i] = { a, b }
if a == nil or b == nil then linkEnds.links = nil end
end
end
return linkEnds
end
local function Network(mine, ctx, ownerOf, spotOf, resourcesOf, underAttack)
local nodes, byIndex = {}, {}
local nodeCount = Safe(GetNumKeepTravelNetworkNodes, ctx) or 0
for i = 1, nodeCount do
local keepId, accessible, nodeX, nodeY = Safe(GetKeepTravelNetworkNodeInfo, i, ctx)
if keepId and accessible ~= false and Open(keepId, mine, ctx, ownerOf, resourcesOf, underAttack) then
local spot = spotOf(keepId)
local x, y = (spot and spot.x) or nodeX, (spot and spot.y) or nodeY
if type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0) then
local node = { keepId = keepId, x = x, y = y, links = {} }
byIndex[i] = node
table.insert(nodes, node)
end
end
end
local linkCount = Safe(GetNumKeepTravelNetworkLinks, ctx) or 0
local ends = LinkEnds(ctx, nodeCount, linkCount)
for i = 1, linkCount do
local _, owner, restricted = Safe(GetKeepTravelNetworkLinkInfo, i, ctx)
local a, b = ends[i][1], ends[i][2]
local open = owner == mine and (not restricted or restricted == 0 or restricted == mine)
local enemyGate = byIndex[a] and byIndex[b] and ((GATE_KEEPS[byIndex[a].keepId] or mine) ~= mine or (GATE_KEEPS[byIndex[b].keepId] or mine) ~= mine)
if open and not enemyGate and byIndex[a] and byIndex[b] then
table.insert(byIndex[a].links, byIndex[b])
table.insert(byIndex[b].links, byIndex[a])
end
end
return nodes
end
function T.New(mine, ctx, player, targets, keepName, underAttack)
if not (player and player.x) then return nil end
local byId = {}
for _, t in ipairs(targets) do byId[t.keepId] = t end
local function ownerOf(keepId)
if byId[keepId] then return byId[keepId].owner end
return Safe(GetKeepAlliance, keepId, ctx)
end
local function spotOf(keepId) return byId[keepId] end
local function name(keepId) return (byId[keepId] and byId[keepId].name) or keepName(keepId) end
local function resourcesOf(keepId)
local out = {}
for _, t in ipairs(targets) do if t.parent == keepId then table.insert(out, t) end end
return out
end
local reach = {}
local nodes = Network(mine, ctx, ownerOf, spotOf, resourcesOf, underAttack)
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
local recallTo = {}
local nearKeep = false
for _, t in ipairs(targets) do
if t.kind == "Keep" and Dist(player, t) and Dist(player, t) <= NEAR_KEEP then nearKeep = true end
end
if not nearKeep and Safe(IsUnitInCombat, "player") ~= true then
for _, t in ipairs(targets) do
if t.kind == "Keep" and t.x and Open(t.keepId, mine, ctx, ownerOf, resourcesOf, underAttack) then
table.insert(recallTo, t)
end
end
for _, node in ipairs(nodes) do
if not byId[node.keepId] then table.insert(recallTo, node) end
end
end
local cache = {}
return function(t)
if cache[t] then return cache[t] end
local ride = Dist(player, t)
if not ride then return nil end
local best = { seconds = ride * T.SECONDS_PER_UNIT, rideAfter = ride, from = player }
local via, viaSeconds, viaRide
for node, r in pairs(reach) do
local d = Dist(node, t)
local s = d and r.seconds + d * T.SECONDS_PER_UNIT
if s and (not viaSeconds or s < viaSeconds) then via, viaSeconds, viaRide = node, s, d end
end
local shortcut = via and { seconds = viaSeconds, rideAfter = viaRide, from = { x = via.x, y = via.y },
line = string.format("Transit from %s to %s.", name(reach[via].from.keepId), name(via.keepId)) }
local stone, stoneSeconds
for _, keep in ipairs(recallTo) do
local d = Dist(keep, t)
local s = d and RECALL_SECONDS + d * T.SECONDS_PER_UNIT
if s and (not stoneSeconds or s < stoneSeconds) then stone, stoneSeconds = keep, s end
end
local recall = stone and { seconds = stoneSeconds, line = string.format("Use a recall stone to %s.", name(stone.keepId)) }
if shortcut and shortcut.seconds + WORTH_IT <= best.seconds then
best = shortcut
elseif best.seconds >= RIGHT_THERE then
best.ride = RideLine(player, t)
end
if recall and recall.seconds + WORTH_IT <= best.seconds then
best.line, best.recall = recall.line, true
end
cache[t] = best
return best
end
end
]=]})
