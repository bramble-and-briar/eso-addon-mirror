local BA = BuildAdvisor
BA.GearTracker = {}
function BA.GearTracker:GetRequirements(build, snapshot)
    local results = {}
    if not build then return results end
    for _, required in ipairs(build.sets or {}) do
        local data = BA.gearSources[required.id]
        results[#results + 1] = {
            id = required.id,
            name = data and data.name or required.id,
            pieces = required.pieces,
            source = data and data.source or "Unknown source",
            zone = data and data.zone or "Unknown zone",
            method = data and data.method or "Not documented",
            equipped = snapshot and data and BA.Scanner:GetEquippedCount(snapshot, data) or 0,
            -- TODO: collection-book status (not equivalent to having an item in inventory).
            collected = nil,
        }
    end
    return results
end
