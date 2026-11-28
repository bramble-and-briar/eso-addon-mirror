ShadowStrikerrWaypointPathfinder = {}
local addon = ShadowStrikerrWaypointPathfinder
local arrowSpacingMeters = 2.2
local arrowSpeedMetersPerSecond = 1.4
local trailMeters = 30

-- Keep a short window of positions the player actually crossed, scoped to one map.
function addon.SampleGround(samples, player)
    local last = samples[#samples]
    if last then
        local dx, dz = player.x - last.x, player.z - last.z
        local distance = dx * dx + dz * dz
        if last.zone ~= player.zone or last.map ~= player.map or distance > 1000 ^ 2 then
            samples = {}
        elseif distance < 90 ^ 2 then
            return samples
        end
    end
    samples[#samples + 1] = player
    if #samples > 32 then table.remove(samples, 1) end
    return samples
end

local function groundHeight(player, samples, x, z, previousHeight)
    local total, weight = 0, 0
    local forwardX, forwardZ = x - player.x, z - player.z
    for index = #samples, 1, -1 do
        local sample = samples[index]
        local distance = (x - sample.x) ^ 2 + (z - sample.z) ^ 2
        local ahead = (sample.x - player.x) * forwardX + (sample.z - player.z) * forwardZ
        if distance <= 300 ^ 2 and math.abs(sample.y - previousHeight) <= 120
            and (ahead > 0 or distance <= 90 ^ 2) then
            local influence = 1 / (distance + 2500)
            total = total + sample.y * influence
            weight = weight + influence
        end
    end
    if weight > 0 then return total / weight end

    local last, previous = samples[#samples], samples[#samples - 1]
    if not previous or not last then return previousHeight end
    local dx, dz = last.x - previous.x, last.z - previous.z
    local run = math.sqrt(dx * dx + dz * dz)
    local slope = math.max(-.45, math.min(.45, (last.y - previous.y) / run))
    local along = ((x - player.x) * dx + (z - player.z) * dz) / run
    local range = 220
    local older = samples[#samples - 2]
    if older then
        local ox, oz = previous.x - older.x, previous.z - older.z
        local earlierRun = math.sqrt(ox * ox + oz * oz)
        local earlierSlope = (previous.y - older.y) / earlierRun
        local sameDirection = (dx * ox + dz * oz) / (run * earlierRun) > .9
        local followsSlope = along > 0 and along ^ 2 > .81 * ((x - player.x) ^ 2 + (z - player.z) ^ 2)
        if sameDirection and followsSlope and math.abs(earlierSlope - slope) < .15 then
            range = 650
        end
    end
    if along > range or along < -220 then return previousHeight end
    local estimate = player.y + slope * along
    return math.max(previousHeight - 100, math.min(previousHeight + 100, estimate))
end

-- World coordinates are centimeters. Trail spacing and texture sizes are meters.
function addon.GetDirectTrail(player, destination, seconds, samples)
    local dx, dz = destination.x - player.x, destination.z - player.z
    local length = math.sqrt(dx * dx + dz * dz)
    local meters = length / 100
    local trail = { distance = meters, points = {} }
    if meters <= 2 then return trail end

    trail.yaw = math.atan2(-dx, -dz)
    local extent = math.min(trailMeters, meters - 0.75)
    local phase = (meters + (seconds or 0) * arrowSpeedMetersPerSecond) % arrowSpacingMeters
    samples = samples or {}
    local height = player.y
    for offset = 1.5 + phase, extent, arrowSpacingMeters do
        local x = player.x + dx * offset / meters
        local z = player.z + dz * offset / meters
        height = groundHeight(player, samples, x, z, height)
        trail.points[#trail.points + 1] = {
            x = x,
            y = math.floor(height + 7.5),
            z = z,
            alpha = math.min(1, (offset - 1.5) / .8, (extent - offset) / 1.4),
        }
    end
    return trail
end

function addon.ApplyWalkedPath(trail, player, route, seconds, continuation)
    trail.waypoints = route
    trail.points = {}
    local entryDistance = math.sqrt((player.x - route[1].x) ^ 2 + (player.z - route[1].z) ^ 2)
    local endpoint = route[#route]
    local directLength = continuation and math.sqrt((continuation.x - endpoint.x) ^ 2
        + (continuation.z - endpoint.z) ^ 2) or 0
    local remaining = (route.length + entryDistance + directLength) / 100
    local nextArrow = 150 + ((remaining + seconds * arrowSpeedMetersPerSecond) % arrowSpacingMeters) * 100
    local extent = math.min(trailMeters * 100,
        remaining * 100)
    local start, traveled = player, 0
    for index = 1, #route + (continuation and 1 or 0) do
        local direct = index > #route
        local finish = route[index] or continuation
        local endHeight = direct and start.y or finish.y
        local dx, dz = finish.x - start.x, finish.z - start.z
        local length = math.sqrt(dx * dx + dz * dz)
        while length > 0 and nextArrow <= traveled + length and nextArrow <= extent do
            local fraction = (nextArrow - traveled) / length
            local yaw = math.atan2(-dx, -dz)
            if #trail.points == 0 then trail.yaw = yaw end
            trail.points[#trail.points + 1] = {
                x = start.x + dx * fraction,
                y = math.floor(start.y + (endHeight - start.y) * fraction + 7.5),
                z = start.z + dz * fraction,
                yaw = yaw,
                alpha = math.min(1, (nextArrow - 150) / 80, (extent - nextArrow) / 140) * (direct and .75 or 1),
            }
            nextArrow = nextArrow + arrowSpacingMeters * 100
        end
        traveled = traveled + length
        if traveled >= extent then break end
        start = finish
    end
end


