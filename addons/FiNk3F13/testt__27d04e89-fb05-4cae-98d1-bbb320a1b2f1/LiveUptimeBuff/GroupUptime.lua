LiveUptimeBuffGroup = {}
local Group = LiveUptimeBuffGroup
local Meter = LiveUptimeBuffMeter

function Group.New(now)
    return { members = {}, sampledAt = now, running = false, duration = 0, percent = 0 }
end

function Group.Update(group, observations, now, inCombat)
    if inCombat and not group.running then
        group.members = {}
        group.duration = 0
        group.percent = 0
        group.sampledAt = now
    end
    local elapsed = math.max(0, now - group.sampledAt)
    local seen = {}
    local representative
    local activeMembers, eligibleMembers = 0, 0
    local function observe(key, observation)
        local member = group.members[key]
        if not member then
            member = { meter = Meter.New(now), eligible = false }
            group.members[key] = member
        end
        local counting = group.running and member.eligible
        if counting then group.duration = group.duration + elapsed end
        local eligible = observation and observation.eligible or false
        local effect = eligible and observation.effect or nil
        Meter.Observe(member.meter, effect, now, counting, counting and eligible)
        member.eligible = eligible
        if eligible then
            eligibleMembers = eligibleMembers + 1
            if effect then
                activeMembers = activeMembers + 1
                if not representative or (effect.ends ~= 0 and (representative.ends == 0 or effect.ends < representative.ends)) then
                    representative = effect
                end
            end
        end
    end
    for _, observation in ipairs(observations) do
        seen[observation.key] = true
        observe(observation.key, observation)
    end
    for key in pairs(group.members) do
        if not seen[key] then observe(key, nil) end
    end
    local total = 0
    for _, member in pairs(group.members) do total = total + member.meter.total end
    group.percent = group.duration > 0 and math.min(100, math.max(0, total / group.duration * 100)) or 0
    group.sampledAt = now
    group.running = inCombat
    group.activeMembers, group.eligibleMembers = activeMembers, eligibleMembers
    return representative
end
