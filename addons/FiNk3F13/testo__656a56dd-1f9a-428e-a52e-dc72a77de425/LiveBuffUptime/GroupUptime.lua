LiveBuffUptimeGroup = {}
local Group = LiveBuffUptimeGroup
local Meter = LiveBuffUptimeMeter

function Group.New(now)
    return { members = {}, sampledAt = now, running = false, duration = 0, percent = 0 }
end

function Group.Update(group, observations, now, inCombat, window, sampleOnly)
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
            member = { meter = Meter.New(now), excluded = Meter.New(now), eligibility = Meter.New(now), eligible = false }
            group.members[key] = member
        end
        local counting = group.running and member.eligible
        if counting then group.duration = group.duration + elapsed end
        local eligible = observation and observation.eligible or false
        local effect = eligible and observation.effect or nil
        Meter.Observe(member.meter, effect, now, counting, counting and eligible)
        Meter.Observe(member.excluded, eligible and observation.excluded or nil, now, counting, counting and eligible)
        Meter.Observe(member.eligibility, eligible and { starts = now, ends = 0 } or nil, now, group.running, false)
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
    if not sampleOnly and window then
        local starts, ends = window.starts, window.ends
        local duration, covered, excluded = 0, 0, 0
        for _, member in pairs(group.members) do
            duration = duration + Meter.IntervalTotal(member.eligibility.intervals, starts, ends)
            covered = covered + Meter.IntervalTotal(member.meter.intervals, starts, ends)
            excluded = excluded + Meter.ExcludedTotal(member.meter.intervals, member.excluded, starts, ends)
        end
        group.percent = duration > 0 and math.min(100, math.max(0, covered / duration * 100)) or 0
        local eligible = duration - excluded
        group.adjustedPercent = eligible > 0 and math.min(100, math.max(0, covered / eligible * 100)) or 0
    elseif not sampleOnly then
        local total, excludedTime = 0, 0
        for _, member in pairs(group.members) do
            total = total + member.meter.total
            excludedTime = excludedTime + Meter.ExcludedTotal(member.meter.intervals, member.excluded, member.meter.since, now)
        end
        group.percent = group.duration > 0 and math.min(100, math.max(0, total / group.duration * 100)) or 0
        local eligibleDuration = group.duration - excludedTime
        group.adjustedPercent = eligibleDuration > 0 and math.min(100, math.max(0, total / eligibleDuration * 100)) or 0
    end
    group.sampledAt = now
    group.running = inCombat
    group.activeMembers, group.eligibleMembers = activeMembers, eligibleMembers
    return representative
end
