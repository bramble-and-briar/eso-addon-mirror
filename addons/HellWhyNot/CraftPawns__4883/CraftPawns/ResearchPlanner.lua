local CAM = CraftPawns
CAM.ResearchPlanner = {}
local RP = CAM.ResearchPlanner

local function copySet(source)
    local out = {}
    for k, v in pairs(source or {}) do out[k] = v end
    return out
end

local function nextUnknown(line, reserved)
    for traitIndex, trait in ipairs(line.traits or {}) do
        local finishedByStoredTimer = trait.researching and line.currentResearch
            and line.currentResearch.traitIndex == traitIndex
            and line.currentResearch.endsAt and line.currentResearch.endsAt <= GetTimeStamp()
        if not trait.known and not trait.researching and not reserved[traitIndex] and not finishedByStoredTimer then
            return traitIndex, trait
        end
    end
end

function RP:ChooseTarget(lines, reservations)
    local best, bestDepth
    for lineIndex, line in ipairs(lines or {}) do
        local reserved = reservations[lineIndex] or {}
        local traitIndex, trait = nextUnknown(line, reserved)
        if traitIndex then
            local count = line.knownCount or 0
            if line.currentResearch then count = count + 1 end
            for _ in pairs(reserved) do count = count + 1 end
            if not best or count < bestDepth or (count == bestDepth and lineIndex < best.lineIndex) then
                bestDepth = count
                best = { lineIndex=lineIndex, traitIndex=traitIndex, trait=trait, line=line }
            end
        end
    end
    return best, bestDepth
end

function RP:BuildCraftPlan(snapshot, craftType, days)
    local research = snapshot.research and snapshot.research[craftType]
    if not research then return { error="Research data unavailable", items={}, slots={} } end
    local horizon = math.max(0, tonumber(days) or 7) * 86400
    local now = GetTimeStamp()
    local slots = {}
    for i = 1, math.max(1, research.slotCount or 1) do slots[i] = { index=i, available=0, entries={} } end
    local active = {}
    for _, line in ipairs(research.lines or {}) do
        if line.currentResearch then active[#active + 1] = line.currentResearch end
    end
    table.sort(active, function(a,b) return (a.remaining or 0) < (b.remaining or 0) end)
    for i, entry in ipairs(active) do
        if slots[i] then
            slots[i].available = math.max(0, entry.endsAt and (entry.endsAt-now) or (entry.remaining or 0))
            slots[i].entries[#slots[i].entries+1] = { active=true, name=entry.name, duration=slots[i].available }
        end
    end
    local reservations, items = {}, {}
    for i = 1, #(research.lines or {}) do reservations[i] = {} end
    while true do
        table.sort(slots, function(a,b) if a.available == b.available then return a.index < b.index end return a.available < b.available end)
        local slot = slots[1]
        if not slot or slot.available >= horizon then break end
        local target, depth = self:ChooseTarget(research.lines, reservations)
        if not target then break end
        reservations[target.lineIndex][target.traitIndex] = true
        local duration = CAM.ResearchTiming:GetProjectedDuration(snapshot, craftType, target.line, depth)
        local item = {
            craftType=craftType, lineIndex=target.lineIndex, traitIndex=target.traitIndex,
            lineName=target.line.name, traitType=target.trait.type,
            traitName=target.trait.name, startsIn=slot.available, duration=duration,
            slot=slot.index,
        }
        items[#items+1] = item
        slot.entries[#slot.entries+1] = item
        slot.available = slot.available + duration
    end
    table.sort(slots, function(a,b) return a.index < b.index end)
    return { craftType=craftType, days=days, horizon=horizon, items=items, slots=slots,
        complete=(#items == 0 and self:IsComplete(research)), generatedAt=now }
end

function RP:IsComplete(research)
    for _, line in ipairs(research.lines or {}) do
        for traitIndex, trait in ipairs(line.traits or {}) do
            local finishedByStoredTimer = trait.researching and line.currentResearch
                and line.currentResearch.traitIndex == traitIndex
                and line.currentResearch.endsAt and line.currentResearch.endsAt <= GetTimeStamp()
            if not trait.known and not finishedByStoredTimer then return false end
        end
    end
    return true
end

function RP:BuildPlan(snapshot, days)
    local plan = { characterId=snapshot.id, days=days, generatedAt=GetTimeStamp(), crafts={} }
    for _, craftType in ipairs(CAM.RESEARCH_CRAFTS) do
        plan.crafts[craftType] = self:BuildCraftPlan(snapshot, craftType, days)
    end
    return plan
end
