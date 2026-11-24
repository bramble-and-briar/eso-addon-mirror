-- Research across the roster: traits known and missing per craft, research slots, and timers.
-- Timers are saved as the moment they finish, so they count down on whichever character you play.
local CT = FurysCharacterTracker
local U = CT.Util
local Research = {}
CT.Research = Research

Research.CRAFTS = {
    { craft = CRAFTING_TYPE_BLACKSMITHING, short = "Smith" },
    { craft = CRAFTING_TYPE_CLOTHIER, short = "Cloth" },
    { craft = CRAFTING_TYPE_WOODWORKING, short = "Wood" },
    { craft = CRAFTING_TYPE_JEWELRYCRAFTING, short = "Jewelry" },
}

local MAX_TRAITS_LISTED = 4   -- an item missing more than this shows a count instead of names

function Research.CraftName(craft)
    return U.Plain(GetString("SI_TRADESKILLTYPE", craft))
end

-- "2d 4h", "5h 12m", "12m"
function Research.Duration(seconds)
    seconds = math.max(0, seconds)
    local days, hours, minutes = math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600), math.floor(seconds % 3600 / 60)
    if days > 0 then return string.format("%dd %dh", days, hours) end
    if hours > 0 then return string.format("%dh %dm", hours, minutes) end
    return string.format("%dm", math.max(minutes, 1))
end

function Research.Entry(c, craft)
    for _, entry in ipairs(c.researchCrafts or {}) do
        if entry.craft == craft then return entry end
    end
end

local function Complete(entry) return entry.known >= entry.total end

-- Busy slots, usable slots, seconds until the next one finishes (nil if none), and how many have
-- finished since the character was last read. Crafts with every trait known have no slots to fill.
function Research.Summary(c, now)
    now = now or GetTimeStamp()
    local busy, slots, nextIn, finished = 0, 0, nil, 0
    for _, entry in ipairs(c.researchCrafts or {}) do
        if not Complete(entry) then
            slots = slots + entry.slots
            for _, timer in ipairs(entry.timers) do
                if timer.endsAt > now then
                    busy = busy + 1
                    nextIn = math.min(nextIn or math.huge, timer.endsAt - now)
                else
                    finished = finished + 1
                end
            end
        end
    end
    return busy, slots, nextIn, finished
end

-- Hover text for one craft on one character.
function Research.CraftTip(c, craft)
    local entry = Research.Entry(c, craft)
    if not entry then return Research.CraftName(craft) .. "\nNot read yet: log in on this character." end
    local now = GetTimeStamp()
    local lines = { string.format("%s: %d of %d traits", Research.CraftName(craft), entry.known, entry.total) }
    if Complete(entry) then
        lines[#lines + 1] = "Every trait researched."
        return table.concat(lines, "\n")
    end
    local busy = 0
    for _, timer in ipairs(entry.timers) do
        if timer.endsAt > now then busy = busy + 1 end
    end
    lines[#lines + 1] = string.format("\nResearching %d of %d slots", busy, entry.slots)
    for _, timer in ipairs(entry.timers) do
        local left = timer.endsAt > now and (Research.Duration(timer.endsAt - now) .. " left") or "done (log in to update)"
        lines[#lines + 1] = string.format("  %s: %s  %s", timer.item, timer.trait, left)
    end
    lines[#lines + 1] = "\nMissing"
    for _, item in ipairs(entry.missing) do
        local traits = #item.traits > MAX_TRAITS_LISTED
            and string.format("%d of %d traits", #item.traits, item.of) or table.concat(item.traits, ", ")
        lines[#lines + 1] = string.format("  %s: %s", item.item, traits)
    end
    return table.concat(lines, "\n")
end

-- Every research slot on an account, one row each: finished and idle first (they need you),
-- then running research, soonest first. Characters with every trait known have no rows.
function Research.Rows(data, now)
    local needs, running = {}, {}
    for _, entry in ipairs(CT.Roster:List(nil, nil, data)) do
        local c = data.characters[entry.name]
        for _, def in ipairs(Research.CRAFTS) do
            local e = Research.Entry(c, def.craft)
            if e and not Complete(e) then
                local craftName, working, done = Research.CraftName(def.craft), 0, 0
                for _, timer in ipairs(e.timers) do
                    local row = { name = entry.name, craftName = craftName, item = timer.item, trait = timer.trait, endsAt = timer.endsAt }
                    if timer.endsAt > now then
                        row.kind, working = "timer", working + 1
                        running[#running + 1] = row
                    else
                        row.kind, done = "done", done + 1
                        needs[#needs + 1] = row
                    end
                end
                local idle = e.slots - working - done
                if idle > 0 then needs[#needs + 1] = { kind = "idle", name = entry.name, craftName = craftName, count = idle } end
            end
        end
    end
    table.sort(running, function(a, b) return a.endsAt < b.endsAt end)
    for _, row in ipairs(running) do needs[#needs + 1] = row end
    return needs
end

-- /fct research: every character still researching, with idle slots and the next to finish.
function Research:Print()
    local now, any = GetTimeStamp(), false
    for _, entry in ipairs(CT.Roster:List()) do
        local c = CT.Data().characters[entry.name]
        if c.researchCrafts and (c.research or 0) < (c.researchTotal or CT.RESEARCH_TOTAL) then
            any = true
            local busy, slots, nextIn = Research.Summary(c, now)
            local idle = {}
            for _, def in ipairs(Research.CRAFTS) do
                local e = Research.Entry(c, def.craft)
                if e and not Complete(e) then
                    local working = 0
                    for _, timer in ipairs(e.timers) do
                        if timer.endsAt > now then working = working + 1 end
                    end
                    if working < e.slots then idle[#idle + 1] = string.format("%s %d", def.short, e.slots - working) end
                end
            end
            U.Print("%s: %d/%d slots busy%s%s", entry.name, busy, slots,
                    nextIn and (", next done in " .. Research.Duration(nextIn)) or "",
                    #idle > 0 and (". Idle: " .. table.concat(idle, ", ")) or "")
        end
    end
    if not any then U.Print("Every character has every trait researched.") end
end

-- At login: name the characters, on every account and megaserver, whose research has finished
-- since they were last read.
function Research:LoginNotice()
    local now, done, riding = GetTimeStamp(), {}, {}
    for _, account in ipairs(CT.Accounts()) do
        local previous = CT.view
        CT.view = account
        local data = CT.Data()
        for _, entry in ipairs(CT.Roster:List(nil, nil, data)) do
            local c = data.characters[entry.name]
            local _, _, _, finished = Research.Summary(c, now)
            if c.ridingReadyAt and c.ridingReadyAt <= now then
                riding[#riding + 1] = account == CT.home and entry.name or string.format("%s (%s)", entry.name, CT.ViewLabel(account))
            end
            if finished > 0 then
                done[#done + 1] = account == CT.home and entry.name or string.format("%s (%s)", entry.name, CT.ViewLabel(account))
            end
        end
        CT.view = previous
    end
    if #done > 0 then
        U.Print("Research finished on %s. /fct research for details.", table.concat(done, ", "))
    end
    if #riding > 0 then U.Print("Riding lesson ready on %s.", table.concat(riding, ", ")) end
end
