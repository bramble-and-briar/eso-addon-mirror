-- shared
-- Research: traits known and missing per craft, research slots, and timers. Saved per character:
--   c.research, c.researchTotal      traits known, and how many exist
--   c.researchCrafts = { { craft =, known =, total =, slots =, need =, timers = { { item =, trait =, endsAt = } } }, ... }
-- `need` is one short text per craft: a group of digits per item in the game's order, one digit per
-- trait, 1 = known, 0 = missing ("111111110 000000000 ..."). The item and trait names are the same
-- for every character, so they are saved once per account (data.researchNames).
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

Research.CraftName = U.CraftName

function Research.Entry(c, craft)
    for _, entry in ipairs(c.researchCrafts or {}) do
        if entry.craft == craft then return entry end
    end
end

local function Complete(entry) return entry.known >= entry.total end
-- Characters read before 1.1.0 have only the total: they count as done when every trait is known.
local function AllKnown(c) return (c.research or 0) >= (c.researchTotal or CT.RESEARCH_TOTAL) end

-- Item and trait names of one craft, in the game's order: { { item =, traits = { ... } }, ... }.
-- In game they are asked from the game once per session; otherwise they come from the saved file
-- ("Axe:Powered,Charged,Precise,...", one text per item).
local names = {}
function Research.Names(craft)
    if names[craft] then return names[craft] end
    local lines = {}
    if CT.live then
        for lineIndex = 1, GetNumSmithingResearchLines(craft) do
            local itemName, _, numTraits = GetSmithingResearchLineInfo(craft, lineIndex)
            local traits = {}
            for traitIndex = 1, numTraits do
                traits[traitIndex] = U.Plain(GetString("SI_ITEMTRAITTYPE", (GetSmithingResearchLineTraitInfo(craft, lineIndex, traitIndex))))
            end
            lines[lineIndex] = { item = U.Plain(itemName), traits = traits }
        end
        names[craft] = lines
    else
        local saved = (CT.Data().researchNames or {})[craft] or {}
        for lineIndex, text in ipairs(saved) do
            local at = string.find(text, ":", 1, true)
            lines[lineIndex] = { item = at and string.sub(text, 1, at - 1) or text, traits = U.Split(at and string.sub(text, at + 1) or "", ",") }
        end
    end
    return lines
end

-- Game only: the same names into the saved file. Written only when they differ from what is saved.
function Research.SaveNames()
    local saved = CT.sv.researchNames or {}
    CT.sv.researchNames = saved
    for _, def in ipairs(Research.CRAFTS) do
        local list = saved[def.craft] or {}
        saved[def.craft] = list
        local lines = Research.Names(def.craft)
        for lineIndex, line in ipairs(lines) do
            local text = line.item .. ":" .. table.concat(line.traits, ",")
            if list[lineIndex] ~= text then list[lineIndex] = text end
        end
        for lineIndex = #lines + 1, #list do list[lineIndex] = nil end
    end
end

-- The traits one craft entry is still missing: { { item =, traits = { names }, of = }, ... }.
-- Reads the short form (`need`) and the list form saved before 1.5.0.
function Research.Missing(entry)
    if not entry.need then return entry.missing or {} end
    local lines, list, lineIndex = Research.Names(entry.craft), {}, 0
    for digits in entry.need:gmatch("%S+") do
        lineIndex = lineIndex + 1
        local line, traits = lines[lineIndex], {}
        for traitIndex = 1, #digits do
            if digits:sub(traitIndex, traitIndex) == "0" then
                traits[#traits + 1] = line and line.traits[traitIndex] or ("trait " .. traitIndex)
            end
        end
        if #traits > 0 then
            list[#list + 1] = { item = line and line.item or ("item " .. lineIndex), traits = traits, of = #digits }
        end
    end
    return list
end

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
                    if not nextIn or timer.endsAt - now < nextIn then nextIn = timer.endsAt - now end
                else
                    finished = finished + 1
                end
            end
        end
    end
    return busy, slots, nextIn, finished
end

-- Free slots per craft: { { def =, count = }, ... }, and how many research has finished.
function Research.Idle(c, now)
    local idle, finished = {}, 0
    for _, def in ipairs(Research.CRAFTS) do
        local entry = Research.Entry(c, def.craft)
        if entry and not Complete(entry) then
            local working = 0
            for _, timer in ipairs(entry.timers) do
                if timer.endsAt > now then working = working + 1 else finished = finished + 1 end
            end
            if working < entry.slots then idle[#idle + 1] = { def = def, count = entry.slots - working } end
        end
    end
    return idle, finished
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
        local left = timer.endsAt > now and (U.Duration(timer.endsAt - now) .. " left") or "done (log in to update)"
        lines[#lines + 1] = string.format("  %s: %s  %s", timer.item, timer.trait, left)
    end
    lines[#lines + 1] = "\nMissing"
    for _, item in ipairs(Research.Missing(entry)) do
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
        for _, def in ipairs(Research.CRAFTS) do
            local e = Research.Entry(entry.c, def.craft)
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

-- Game only. /fct research: every character still researching, with idle slots and the next to finish.
function Research:Print()
    local now, any = GetTimeStamp(), false
    for _, entry in ipairs(CT.Roster:List()) do
        local c = entry.c
        if c.researchCrafts and not AllKnown(c) then
            any = true
            local busy, slots, nextIn = Research.Summary(c, now)
            local idle = {}
            for _, item in ipairs((Research.Idle(c, now))) do idle[#idle + 1] = string.format("%s %d", item.def.short, item.count) end
            U.Print("%s: %d/%d slots busy%s%s", entry.name, busy, slots,
                    nextIn and (", next done in " .. U.Duration(nextIn)) or "",
                    #idle > 0 and (". Idle: " .. table.concat(idle, ", ")) or "")
        end
    end
    if not any then U.Print("Every character has every trait researched.") end
end

-- Columns --------------------------------------------------------------------------------------

local columns = {
    { key = "research", title = "Research", width = 84, max = function(e) return e.c.researchTotal or CT.RESEARCH_TOTAL end,
      value = function(e) return e.c.research or 0 end, tip = "Traits researched (smithing, clothing, woodworking, jewelry)",
      head = "Research: traits researched, out of " .. CT.RESEARCH_TOTAL .. ".\n9 traits on each of 36 items, in smithing, clothing, woodworking and jewelry." },
}
for _, def in ipairs(Research.CRAFTS) do
    columns[#columns + 1] = {
        key = "research." .. def.short, title = def.short, width = 96,
        head = function() return Research.CraftName(def.craft) .. ": traits researched in this craft.\nHover a cell for what is researching now and every trait still missing." end,
        max = function(e) local entry = Research.Entry(e.c, def.craft); return entry and entry.total or 1 end,
        value = function(e)
            local entry = Research.Entry(e.c, def.craft)
            if entry then return entry.known end
            return AllKnown(e.c) and 1 or 0
        end,
        display = function(v, e)
            local entry = Research.Entry(e.c, def.craft)
            if entry then return U.Of(v, entry.total) end
            return AllKnown(e.c) and "all" or "-"
        end,
        tip = function(e)
            if not Research.Entry(e.c, def.craft) and AllKnown(e.c) then
                return Research.CraftName(def.craft) .. "\nEvery trait researched."
            end
            return Research.CraftTip(e.c, def.craft)
        end }
end
columns[#columns + 1] = {
    key = "researchSlots", title = "Slots", width = 84,
    head = "Slots: research slots in use, out of the slots this character has.",
    max = function(e) local _, slots = Research.Summary(e.c); return slots > 0 and slots or nil end,
    value = function(e) return (Research.Summary(e.c)) end,
    display = function(v, e) local _, slots = Research.Summary(e.c); return slots > 0 and U.Of(v, slots) or "-" end,
    dim = function(_, e) local _, slots = Research.Summary(e.c); return slots == 0 end,
    tip = "Research slots busy right now, across the crafts that still have traits to learn.\nViolet = every slot working. Counts down live, even for characters you are not on." }
columns[#columns + 1] = {
    key = "researchFree", title = "Free slots", width = 84, bar = false,
    head = "Free slots: research slots with nothing in them, or with research that has finished.\nAmber = a slot is waiting for you. A dash = every slot is working, or nothing is left to research.",
    value = function(e)
        local free = 0
        for _, item in ipairs((Research.Idle(e.c, GetTimeStamp()))) do free = free + item.count end
        return free
    end,
    display = function(v) return v > 0 and U.Whole(v) or "-" end,
    dim = function(v) return v == 0 end, warn = function(v) return v > 0 end,
    tip = function(e)
        local idle = Research.Idle(e.c, GetTimeStamp())
        if #idle == 0 then return "No free research slot." end
        local lines = { "Free research slots" }
        for _, item in ipairs(idle) do lines[#lines + 1] = string.format("  %s: %d", Research.CraftName(item.def.craft), item.count) end
        return table.concat(lines, "\n")
    end }
columns[#columns + 1] = {
    key = "researchNext", title = "Next done", width = 104, bar = false,
    head = "Next done: time until this character's next research finishes.",
    value = function(e) local _, _, nextIn = Research.Summary(e.c); return nextIn or math.huge end,
    display = function(v) return v == math.huge and "-" or U.Duration(v) end,
    dim = function(v) return v == math.huge end,
    tip = function(e)
        local _, _, nextIn, finished = Research.Summary(e.c)
        local text = nextIn and ("Next research finishes in " .. U.Duration(nextIn)) or "Nothing researching"
        if finished > 0 then text = text .. string.format("\n%d finished since this character was last read", finished) end
        return text
    end }

-- Game only: reads research for the character you are on.
local function Read(c)
    local known, total, crafts = 0, 0, {}
    local now = GetTimeStamp()
    for _, def in ipairs(Research.CRAFTS) do
        local craft = def.craft
        local entry = { craft = craft, known = 0, total = 0, slots = GetMaxSimultaneousSmithingResearch(craft), timers = {} }
        local need = {}
        for lineIndex = 1, GetNumSmithingResearchLines(craft) do
            local itemName, _, numTraits = GetSmithingResearchLineInfo(craft, lineIndex)
            local digits = {}
            for traitIndex = 1, numTraits do
                local traitType, _, isKnown = GetSmithingResearchLineTraitInfo(craft, lineIndex, traitIndex)
                entry.total = entry.total + 1
                if isKnown then
                    entry.known = entry.known + 1
                    digits[traitIndex] = "1"
                else
                    digits[traitIndex] = "0"
                    local _, remaining = GetSmithingResearchLineTraitTimes(craft, lineIndex, traitIndex)
                    if remaining and remaining > 0 then
                        entry.timers[#entry.timers + 1] = { item = U.Plain(itemName), trait = U.Plain(GetString("SI_ITEMTRAITTYPE", traitType)),
                                                            endsAt = now + remaining }
                    end
                end
            end
            need[lineIndex] = table.concat(digits)
        end
        entry.need = table.concat(need, " ")
        known, total = known + entry.known, total + entry.total
        crafts[#crafts + 1] = entry
    end
    c.research, c.researchTotal, c.researchCrafts = known, total, crafts
    Research.SaveNames()
end

CT.Track({
    id = "research",
    read = Read,
    events = { EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED, EVENT_SMITHING_TRAIT_RESEARCH_STARTED,
               EVENT_SMITHING_TRAIT_RESEARCH_CANCELED, EVENT_SMITHING_TRAIT_RESEARCH_TIMES_UPDATED },
    columns = columns,
    summary = function(e)
        return { CT.Trackers.Progress("Traits researched", e.c.research, e.c.researchTotal or CT.RESEARCH_TOTAL) }
    end,
    sections = function(e)
        local c = e.c
        local section = { title = "Research", lines = {} }
        local now = GetTimeStamp()
        if not c.researchCrafts then
            section.lines[1] = AllKnown(c) and "Every trait researched." or "Research details not read yet: log in on this character once."
        end
        for _, def in ipairs(Research.CRAFTS) do
            local entry = Research.Entry(c, def.craft)
            if entry then
                section.lines[#section.lines + 1] = { string.format("%s: %d of %d traits%s", Research.CraftName(def.craft), entry.known, entry.total,
                                                      Complete(entry) and "  ·  complete" or string.format("  ·  %d research slots", entry.slots)), bold = true }
                for _, timer in ipairs(entry.timers) do
                    local left = timer.endsAt > now and (U.Duration(timer.endsAt - now) .. " left") or "done"
                    section.lines[#section.lines + 1] = { string.format("    Researching %s: %s  ·  %s", timer.item, timer.trait, left), gold = true }
                end
                for _, item in ipairs(Research.Missing(entry)) do
                    section.lines[#section.lines + 1] = string.format("    %s: %s", item.item, table.concat(item.traits, ", "))
                end
            end
        end
        return { section }
    end,
    export = { { "Research", function(e) return e.c.research end } },
})
