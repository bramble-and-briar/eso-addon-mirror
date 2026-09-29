local AlabuzyaUI = AlabuzyaUI
-- Bundled QuestArrow 0.2.2 by alabuzya.
if not AlabuzyaUI.UseBundledQuestArrow then return end
-- Pure geometry: distances are fractions of map height, NOT metres.
AlabuzyaUI.QuestArrow = AlabuzyaUI.QuestArrow or {}
local P = {}
AlabuzyaUI.QuestArrow.Planner = P

function P.ValidPoint(p)
    return p and type(p.x) == "number" and type(p.y) == "number"
        and p.x == p.x and p.y == p.y
        and p.x >= 0 and p.x <= 1 and p.y >= 0 and p.y <= 1
end

function P.Distance(a, b, aspect)
    local dx, dy = (b.x - a.x) * (aspect or 1), b.y - a.y
    return math.sqrt(dx * dx + dy * dy)
end

function P.Atan2(y, x)
    if x > 0 then return math.atan(y / x) end
    if x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi) end
    if y > 0 then return math.pi / 2 end
    if y < 0 then return -math.pi / 2 end
    return 0
end

-- Map y points south. Screen angles are clockwise from north.
-- ESO camera heading is counterclockwise from north.
function P.Angle(player, target, aspect, cameraHeading)
    local bearing = P.Atan2((target.x - player.x) * (aspect or 1), player.y - target.y)
    return (bearing + cameraHeading + math.pi) % (2 * math.pi) - math.pi
end

function P.Interval(nodes, aspect)
    local nearest = {}
    for i, a in ipairs(nodes) do
        local best
        for j, b in ipairs(nodes) do
            if i ~= j then
                local distance = P.Distance(a, b, aspect)
                if distance > 0.0001 and (not best or distance < best) then best = distance end
            end
        end
        if best then nearest[#nearest + 1] = best end
    end
    if #nearest < 2 then return nil end
    table.sort(nearest)
    local mid = math.floor(#nearest / 2)
    if #nearest % 2 == 0 then return (nearest[mid] + nearest[mid + 1]) / 2 end
    return nearest[mid + 1]
end

function P.Plan(player, target, nodes, aspect, settings, previous, now, interval)
    if not P.ValidPoint(player) or not P.ValidPoint(target) then return nil end
    local direct = P.Distance(player, target, aspect)
    local plan = { mode = "quest", target = target, distance = direct }
    -- A geographical breadcrumb can be a distant entrance on the overland map.
    -- Indoor/PvP restrictions are applied by the node provider instead.
    if not settings.travel then plan.reason = "travel_disabled" return plan end
    if target.radius > 0 then plan.reason = "search_area" return plan end
    if #nodes < 2 then plan.reason = "not_enough_nodes" return plan end
    local spacing = interval or P.Interval(nodes, aspect)
    if not spacing or spacing <= 0 then plan.reason = "no_spacing" return plan end
    local old = previous and previous.mode == "travel" and previous.target.key == target.key and previous or nil
    local threshold = spacing * settings.threshold * (old and 0.8 or 1.2)
    plan.spacing, plan.threshold = spacing, threshold
    if direct < threshold then plan.reason = "below_threshold" return plan end

    local function cost(a, b)
        return P.Distance(player, a, aspect) + P.Distance(b, target, aspect) + 0.15 * spacing
    end
    local function useful(a, b, ratio)
        return a and b and a.id ~= b.id and not b.outbound
            and cost(a, b) <= direct * ratio and direct - cost(a, b) >= 0.15 * spacing
    end
    local a, b, da, db
    local oldA, oldB
    for _, node in ipairs(nodes) do
        local from, to = P.Distance(player, node, aspect), P.Distance(node, target, aspect)
        if not da or from < da then a, da = node, from end
        if not node.outbound and (not db or to < db) then b, db = node, to end
        if old and node.id == old.a.id then oldA = node end
        if old and node.id == old.b.id then oldB = node end
    end
    if useful(oldA, oldB, 0.9) then
        local oldCost = cost(oldA, oldB)
        if now - old.since < 8 or not useful(a, b, 0.75) or cost(a, b) > oldCost * 0.8 then
            a, b = oldA, oldB
        end
    end
    local retained = old and a and b and a.id == old.a.id and b.id == old.b.id
    if not useful(a, b, retained and 0.9 or 0.75) then
        plan.reason = "no_useful_transfer"
        if a and b then plan.travelCost = cost(a, b) end
        return plan
    end
    local approach = P.Distance(player, a, aspect)
    return { mode = "travel", target = target, a = a, b = b, distance = approach,
        waiting = approach < math.min(0.008, spacing * 0.05),
        since = retained and old.since or now, spacing = spacing, threshold = threshold,
        directDistance = direct, travelCost = cost(a, b), reason = "useful_transfer" }
end
