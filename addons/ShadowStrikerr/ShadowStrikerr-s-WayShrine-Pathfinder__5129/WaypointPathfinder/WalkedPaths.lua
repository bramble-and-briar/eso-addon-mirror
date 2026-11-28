local addon = ShadowStrikerrWaypointPathfinder
local maxTracks, maxPoints, maxMaps = 10, 800, 24
local recordingRevision = 0

local function distance(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

function addon.RecordWalkedPoint(store, recording, player)
    local key = string.format("%d:%d", player.zone, player.map)
    local last = recording and recording.last
    if last and (recording.key ~= key or distance(last, player) > 450 or math.abs(last.y - player.y) > 160) then
        recording, last = nil, nil
    end
    if not recording then return { key = key, last = player } end

    local step = distance(last, player)
    if step < 85 and (step < 45 or math.abs(last.y - player.y) < 45) then return recording end
    if not recording.track then
        local tracks = store[key]
        if not tracks then
            tracks = {}
            store[key] = tracks
        end
        store.order = store.order or {}
        for index = #store.order, 1, -1 do
            if store.order[index] == key then table.remove(store.order, index) end
        end
        store.order[#store.order + 1] = key
        if #store.order > maxMaps then store[table.remove(store.order, 1)] = nil end

        recording.track = { { x = last.x, y = last.y, z = last.z } }
        tracks[#tracks + 1] = recording.track
        if #tracks > maxTracks then table.remove(tracks, 1) end
    end
    local track = recording.track
    track[#track + 1] = { x = player.x, y = player.y, z = player.z }
    if #track > maxPoints then table.remove(track, 1) end
    recording.last = player
    recordingRevision = recordingRevision + 1
    return recording
end

local function closestPoint(a, b, player)
    local dx, dz = b.x - a.x, b.z - a.z
    local lengthSquared = dx * dx + dz * dz
    local t = lengthSquared > 0
        and math.max(0, math.min(1, ((player.x - a.x) * dx + (player.z - a.z) * dz) / lengthSquared)) or 0
    local x, y, z = a.x + t * dx, a.y + t * (b.y - a.y), a.z + t * dz
    local separation = (x - player.x) ^ 2 + (z - player.z) ^ 2
    if separation > 95 ^ 2 or math.abs(y - player.y) > 100 then return end
    return x, y, z, separation
end

local cellSize, joinRadius, joinHeight = 100, 85, 45
local graphCache

local function cellKey(x, z)
    return x .. ":" .. z
end

local function addEdge(graph, a, b, cost)
    graph.links[a][#graph.links[a] + 1] = { node = b, cost = cost }
    graph.links[b][#graph.links[b] + 1] = { node = a, cost = cost }
end

local function buildGraph(tracks)
    local graph = { nodes = {}, links = {}, segments = {} }
    local cells = {}
    for trackIndex, track in ipairs(tracks) do
        local previous
        for _, point in ipairs(track) do
            local id = #graph.nodes + 1
            graph.nodes[id], graph.links[id] = point, {}
            local cx, cz = math.floor(point.x / cellSize), math.floor(point.z / cellSize)
            local junctions = {}
            for x = cx - 1, cx + 1 do
                for z = cz - 1, cz + 1 do
                    local nearby = cells[cellKey(x, z)]
                    if nearby then
                        for _, item in ipairs(nearby) do
                            -- Rejoining the same walk after looping is useful too.
                            if item.track ~= trackIndex or id - item.id > 6 then
                                local other = graph.nodes[item.id]
                                local gap = distance(point, other)
                                local nearest = junctions[item.track]
                                if gap <= joinRadius and math.abs(point.y - other.y) <= joinHeight
                                    and (not nearest or gap < nearest.gap) then
                                    junctions[item.track] = { id = item.id, gap = gap }
                                end
                            end
                        end
                    end
                end
            end
            for _, junction in pairs(junctions) do
                addEdge(graph, id, junction.id, math.max(1, junction.gap) + 25)
            end
            if previous then
                local a = graph.nodes[previous]
                local gap = distance(a, point)
                if gap <= 450 and math.abs(a.y - point.y) <= 160 then
                    addEdge(graph, previous, id, math.max(1, gap))
                    graph.segments[#graph.segments + 1] = { previous, id }
                end
            end
            local key = cellKey(cx, cz)
            cells[key] = cells[key] or {}
            cells[key][#cells[key] + 1] = { id = id, track = trackIndex }
            previous = id
        end
    end
    return graph
end

local function getGraph(store, key, seconds)
    local cache = graphCache
    local sameMap = cache and cache.store == store and cache.key == key
    if sameMap and (cache.revision == recordingRevision
        or seconds and cache.time and seconds < cache.time + .5) then
        return cache.graph
    end
    local graph = buildGraph(store[key] or {})
    graphCache = { store = store, key = key, revision = recordingRevision, time = seconds, graph = graph }
    return graph
end

local function push(queue, item)
    local index = #queue + 1
    while index > 1 do
        local parent = math.floor(index / 2)
        if queue[parent].priority <= item.priority then break end
        queue[index] = queue[parent]
        index = parent
    end
    queue[index] = item
end

local function pop(queue)
    local first = queue[1]
    local last = table.remove(queue)
    local index = 1
    while index * 2 <= #queue do
        local child = index * 2
        if queue[child + 1] and queue[child + 1].priority < queue[child].priority then child = child + 1 end
        if queue[child].priority >= last.priority then break end
        queue[index] = queue[child]
        index = child
    end
    if #queue > 0 then queue[index] = last end
    return first
end

local function findEntry(graph, player)
    local entry, segment, best
    for _, link in ipairs(graph.segments) do
        local a, b = graph.nodes[link[1]], graph.nodes[link[2]]
        local x, y, z, separation = closestPoint(a, b, player)
        if separation then
            local score = separation + (player.y - y) ^ 2
            if not best or score < best then
                entry, segment, best = { x = x, y = y, z = z }, link, score
            end
        end
    end
    return entry, segment
end

function addon.FindWalkedPath(store, player, target, seconds)
    local key = string.format("%d:%d", player.zone, player.map)
    if not store[key] then return end
    local graph = getGraph(store, key, seconds)
    local entry, segment = findEntry(graph, player)
    if not entry then return end

    local initialDistance = distance(player, target)
    local minimumProgress = math.min(900, initialDistance * .5)
    local queue, costs, parents = {}, {}, {}
    for _, id in ipairs(segment) do
        local point = graph.nodes[id]
        local cost = distance(player, entry) + distance(entry, point)
        costs[id] = cost
        push(queue, { id = id, cost = cost, priority = cost + distance(point, target) })
    end

    local best, bestScore, complete
    while #queue > 0 do
        local item = pop(queue)
        if item.cost == costs[item.id] then
            local point = graph.nodes[item.id]
            local remaining = distance(point, target)
            local correctLevel = not target.y or math.abs(point.y - target.y) <= 150
            if remaining <= 250 and correctLevel then
                best, complete = item.id, true
                break
            end
            local progress = initialDistance - remaining
            local score = progress - item.cost * .22
            if progress >= minimumProgress and score > 0 and (not bestScore or score > bestScore) then
                best, bestScore = item.id, score
            end
            for _, edge in ipairs(graph.links[item.id]) do
                local cost = item.cost + edge.cost
                if cost <= 90000 and (not costs[edge.node] or cost < costs[edge.node]) then
                    costs[edge.node], parents[edge.node] = cost, item.id
                    local estimate = distance(graph.nodes[edge.node], target)
                    push(queue, { id = edge.node, cost = cost, priority = cost + estimate })
                end
            end
        end
    end
    if not best then return end
    local reverse = {}
    while best do
        reverse[#reverse + 1] = graph.nodes[best]
        best = parents[best]
    end

    local route = { entry, length = 0, complete = complete == true, cursor = 1 }
    for index = #reverse, 1, -1 do
        local point = reverse[index]
        local span = distance(route[#route], point)
        if span > 1 then
            route.length = route.length + span
            route[#route + 1] = point
        end
    end
    if route.length > 80 then return route end
end
-- Advance along the selected recording in order. A nearby later segment at a
-- hairpin must not send the player backward or jump across the turn.
function addon.AdvanceWalkedPath(route, player)
    local index = route.cursor
    local entry
    while index < #route do
        local a, b = route[index], route[index + 1]
        local dx, dz = b.x - a.x, b.z - a.z
        local lengthSquared = dx * dx + dz * dz
        local t = lengthSquared > 0
            and ((player.x - a.x) * dx + (player.z - a.z) * dz) / lengthSquared or 1
        if t >= 1 and distance(player, b) <= 125 and math.abs(player.y - b.y) <= 100 then
            index = index + 1
        else
            local x, y, z = closestPoint(a, b, player)
            if not x then return end
            entry = { x = x, y = y, z = z }
            break
        end
    end
    if not entry then return end
    route.cursor = index
    local view = { entry, length = 0, complete = route.complete }
    for nextIndex = index + 1, #route do
        local point = route[nextIndex]
        view.length = view.length + distance(view[#view], point)
        view[#view + 1] = point
    end
    if view.length > 80 then return view end
end


