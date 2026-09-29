local CAM = CraftPawns
CAM.ResearchTiming = {}
local RT = CAM.ResearchTiming

-- ESO supplies timeRequiredForNextResearchSecs with research-line data. The
-- scanner stores that authoritative live value. Projection falls back to the
-- normal doubling curve and the live line value, keeping the formula isolated.
function RT:GetProjectedDuration(snapshot, craftType, line, projectedDepth)
    local live = line.nextDuration
    if live and live > 0 then
        local baseDepth = line.knownCount or 0
        local exponent = math.max(0, projectedDepth - baseDepth)
        local projected = live * (2 ^ exponent)
        local cap = line.durationCap
        if cap and cap > 0 then projected = math.min(projected, cap) end
        return math.floor(projected)
    end
    -- Conservative fallback used only if the client omits the line duration.
    local base = 6 * 60 * 60
    return math.min(base * (2 ^ math.max(0, projectedDepth)), 30 * 86400)
end

