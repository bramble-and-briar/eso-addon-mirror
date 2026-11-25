-- Skill Point Finder: the text for each tab of the screen.

local SP = ESOC_SkillPointFinder
local Data = SP.Data
local Lists = {}
SP.Lists = Lists

local C = SP.Colour

local function points(n)
    if n == math.floor(n) then
        return string.format("%d", n) .. (n == 1 and " point" or " points")
    end
    return string.format("about %.1f points", n)
end

local function easeText(ease)
    return Data.EASE_NAMES[ease] or "?"
end

local function plural(n, word)
    return n .. " " .. word .. (n == 1 and "" or "s")
end

-- Totals used by the Overview and the Settings summary.
function Lists.Totals(state)
    local t = { shardsMissing = 0, shardsPvP = 0, publicsDone = 0, publicsTotal = 0,
        dungeonsDone = 0, dungeonsTotal = 0, dungeonsLocked = 0, story = 0, storyZones = 0 }
    for _, zone in ipairs(state.zoneList) do
        if zone.isPvP and SP.sv.options.hidePvP then
            t.shardsPvP = t.shardsPvP + zone.shardsMissing
        else
            t.shardsMissing = t.shardsMissing + zone.shardsMissing
        end
        if zone.story and not zone.story.finished then
            t.story = t.story + zone.story.points
            t.storyZones = t.storyZones + 1
        end
    end
    for _, public in ipairs(state.publics) do
        t.publicsTotal = t.publicsTotal + 1
        if public.done then t.publicsDone = t.publicsDone + 1 end
    end
    for _, dungeon in ipairs(state.dungeons) do
        t.dungeonsTotal = t.dungeonsTotal + 1
        if dungeon.questDone then
            t.dungeonsDone = t.dungeonsDone + 1
        elseif not dungeon.owned then
            t.dungeonsLocked = t.dungeonsLocked + 1
        end
    end
    t.publicsMissing = t.publicsTotal - t.publicsDone
    t.dungeonsMissing = t.dungeonsTotal - t.dungeonsDone
    t.shardPoints = t.shardsMissing / 3
    t.dungeonsOpen = t.dungeonsMissing - t.dungeonsLocked
    local dungeonPoints = SP.sv.options.hideLocked and t.dungeonsOpen or t.dungeonsMissing
    t.total = math.floor(t.shardPoints + t.publicsMissing + dungeonPoints + t.story)
    return t
end

function Lists.Summary(state)
    local t = Lists.Totals(state)
    return "About " .. t.total .. " skill points still waiting on this character."
end

function Lists.Overview(state)
    local t = Lists.Totals(state)
    local lines = {
        C(SP.GOLD, "Skill points to spend now: " .. (SP.Safe(GetAvailableSkillPoints) or 0)),
        "",
        C(SP.GOLD, "Still waiting to be collected"),
        "Skyshards: " .. state.shardsFound .. " of " .. state.shardsTotal .. " found. " .. plural(t.shardsMissing, "skyshard") .. " left = " .. points(t.shardPoints) .. " (3 skyshards = 1 point).",
        "Public dungeon group events: " .. t.publicsDone .. " of " .. t.publicsTotal .. " done = " .. points(t.publicsMissing) .. " waiting.",
        "Group dungeon quests: " .. t.dungeonsDone .. " of " .. t.dungeonsTotal .. " done = " .. points(t.dungeonsMissing) .. " waiting.",
        "Zone storylines: up to " .. points(t.story) .. " in " .. plural(t.storyZones, "zone") .. " (an estimate: the game can't say which story quests give a point).",
        "",
        C(SP.GOLD, "Total: about " .. t.total .. " skill points."),
    }
    if t.shardsPvP > 0 then
        lines[#lines + 1] = C(SP.GREY, plural(t.shardsPvP, "skyshard") .. " in Cyrodiil and Imperial City are hidden (PvP). Change it in Settings.")
    end
    if t.dungeonsLocked > 0 then
        lines[#lines + 1] = C(SP.GREY, plural(t.dungeonsLocked, "dungeon") .. (t.dungeonsLocked == 1 and " needs" or " need") .. " a DLC you don't have" .. (SP.sv.options.hideLocked and " (not in the total)." or "."))
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = C(SP.GOLD, "Not tracked yet")
    for _, text in ipairs(Data.NOT_TRACKED) do lines[#lines + 1] = C(SP.GREY, text) end
    lines[#lines + 1] = ""
    lines[#lines + 1] = C(SP.GREY, "LT and RT change tab. LB and RB change page.")
    return table.concat(lines, "\n")
end

-- Everything missing, easiest first. Skyshards are grouped per zone.
function Lists.Items(state)
    local items = {}
    -- Skyshards are one line: how many are left, not where (By zone shows which zones)
    -- Group-delve zones such as Craglorn get their own line, rated Medium: soloable but tougher.
    local shardsLeft, shardZones = 0, 0
    for _, zone in ipairs(state.zoneList) do
        if zone.shardsMissing > 0 and not (zone.isPvP and SP.sv.options.hidePvP) then
            if Data.GROUP_SHARD_ZONES[zone.key] then
                items[#items + 1] = {
                    ease = 3, points = zone.shardsMissing / 3, zone = zone.name,
                    text = "Skyshards in " .. zone.name .. ": " .. zone.shardsMissing .. " left, mostly in group delves: soloable but tougher (" .. points(zone.shardsMissing / 3) .. ")",
                }
            else
                shardsLeft = shardsLeft + zone.shardsMissing
                shardZones = shardZones + 1
            end
        end
    end
    if shardsLeft > 0 then
        items[#items + 1] = {
            ease = 5, points = shardsLeft / 3, zone = "",
            text = "Skyshards: " .. shardsLeft .. " left in " .. plural(shardZones, "zone") .. " (" .. points(shardsLeft / 3) .. ")",
        }
    end
    for _, zone in ipairs(state.zoneList) do
        if zone.story and not zone.story.finished then
            items[#items + 1] = {
                ease = 1, points = zone.story.points, zone = zone.name,
                text = zone.name .. " storyline: " .. zone.story.done .. " of " .. zone.story.total .. " story quests done (up to " .. points(zone.story.points) .. ")",
            }
        end
    end
    for _, public in ipairs(state.publics) do
        if not public.done then
            items[#items + 1] = {
                ease = public.ease, points = 1, zone = public.zone.name,
                text = "Group event: " .. public.name .. ", " .. public.zone.name .. (public.zone.isBase and " (soloable)" or " (DLC, can be tough)"),
            }
        end
    end
    for _, dungeon in ipairs(state.dungeons) do
        if not dungeon.questDone and (dungeon.owned or not SP.sv.options.hideLocked) then
            local note = dungeon.inJournal and " (quest in your journal)" or " (needs a group)"
            if not dungeon.owned then note = " (needs DLC)" end
            items[#items + 1] = {
                ease = dungeon.owned and 3 or 1, points = 1, zone = dungeon.name,
                text = "Dungeon quest: " .. dungeon.name .. note,
            }
        end
    end
    table.sort(items, function(a, b)
        if a.ease ~= b.ease then return a.ease > b.ease end
        if a.points ~= b.points then return a.points > b.points end
        return a.zone < b.zone
    end)
    return items
end

function Lists.Easiest(state)
    local items = Lists.Items(state)
    if #items == 0 then return "Nothing missing. Every tracked skill point is collected." end
    local lines, lastEase = {}, nil
    for _, item in ipairs(items) do
        if item.ease ~= lastEase then
            if lastEase then lines[#lines + 1] = "" end
            lines[#lines + 1] = C(SP.GOLD, easeText(item.ease))
            lastEase = item.ease
        end
        lines[#lines + 1] = item.text
    end
    return table.concat(lines, "\n")
end

function Lists.Zones(state)
    local rows = {}
    for _, zone in ipairs(state.zoneList) do
        local left = SP.Scan.ZoneLeft(zone)
        if left.points > 0 then rows[#rows + 1] = { zone = zone, left = left } end
    end
    table.sort(rows, function(a, b)
        if a.left.points ~= b.left.points then return a.left.points > b.left.points end
        return a.zone.name < b.zone.name
    end)
    if #rows == 0 then return "No zone has anything left." end
    local lines = { C(SP.GOLD, "Zones with the most skill points left") }
    for _, row in ipairs(rows) do
        local parts = {}
        if row.left.shards > 0 then
            parts[#parts + 1] = plural(row.left.shards, "skyshard") .. (Data.GROUP_SHARD_ZONES[row.zone.key] and " in group delves" or "")
        end
        if row.left.publics > 0 then parts[#parts + 1] = plural(row.left.publics, "group event") end
        if row.left.story > 0 then parts[#parts + 1] = "story up to " .. row.left.story end
        lines[#lines + 1] = row.zone.name .. ": " .. points(row.left.points) .. C(SP.GREY, " (" .. table.concat(parts, ", ") .. ")")
    end
    return table.concat(lines, "\n")
end

local function status(done, partial)
    if done then return C(SP.GREEN, "Done") end
    if partial then return C(SP.YELLOW, partial) end
    return C(SP.RED, "Missing")
end

function Lists.Checklist(state)
    local t = Lists.Totals(state)
    local missingOnly = SP.sv.options.missingOnly
    local lines = {
        C(SP.GOLD, "Public dungeon group events: " .. t.publicsDone .. " of " .. t.publicsTotal .. " done"),
    }
    if not state.indexReady then lines[#lines + 1] = C(SP.YELLOW, "Still reading achievements: this list updates in a moment.") end
    local publics = {}
    for _, public in ipairs(state.publics) do publics[#publics + 1] = public end
    table.sort(publics, function(a, b)
        if a.zone.isBase ~= b.zone.isBase then return a.zone.isBase end
        if a.zone.name ~= b.zone.name then return a.zone.name < b.zone.name end
        return a.name < b.name
    end)
    for _, public in ipairs(publics) do
        if not (missingOnly and public.done) then
            local note = ""
            lines[#lines + 1] = status(public.done) .. "  " .. public.name .. C(SP.GREY, ", " .. public.zone.name) .. (public.done and "" or C(SP.GREY, "  1 skill point")) .. note
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = C(SP.GOLD, "Group dungeon quests: " .. t.dungeonsDone .. " of " .. t.dungeonsTotal .. " done")
    for _, dungeon in ipairs(state.dungeons) do
        local hidden = (missingOnly and dungeon.questDone) or (not dungeon.owned and not dungeon.questDone and SP.sv.options.hideLocked)
        if not hidden then
            local partial = dungeon.inJournal and "In journal" or nil
            local extra = ""
            if not dungeon.questDone then extra = C(SP.GREY, "  1 skill point") end
            if not dungeon.owned then extra = extra .. C(SP.GREY, "  needs DLC") end
            if dungeon.source == "manual" then extra = extra .. C(SP.GREY, "  marked by hand") end
            lines[#lines + 1] = status(dungeon.questDone, partial) .. "  " .. dungeon.name .. extra
        end
    end
    if missingOnly then
        lines[#lines + 1] = ""
        lines[#lines + 1] = C(SP.GREY, "Showing missing only. X shows everything.")
    end
    return table.concat(lines, "\n")
end

-- The zone you're standing in: counts only.
function Lists.Here(state)
    local zoneId = SP.RootZone(SP.PlayerZoneId())
    local dungeon = state.dungeonByZone[SP.PlayerZoneId()]
    local lines = {}
    if dungeon then
        lines[#lines + 1] = C(SP.GOLD, dungeon.name)
        if dungeon.questDone then
            lines[#lines + 1] = "Dungeon quest: " .. C(SP.GREEN, "done") .. " on this character."
        elseif dungeon.inJournal then
            lines[#lines + 1] = "Dungeon quest: " .. C(SP.YELLOW, "in your journal") .. ". Finish it for 1 skill point."
        else
            lines[#lines + 1] = "Dungeon quest: " .. C(SP.RED, "not done") .. ". Talk to the quest giver near the start: it's worth 1 skill point."
        end
        return table.concat(lines, "\n")
    end
    local zone = state.zones[zoneId]
    if not zone then return "This zone has no skyshards, group events or story points." end
    lines[#lines + 1] = C(SP.GOLD, zone.name)
    lines[#lines + 1] = "Skyshards: " .. (zone.shardsTotal - zone.shardsMissing) .. " of " .. zone.shardsTotal .. " found, " .. zone.shardsMissing .. " left (" .. points(zone.shardsMissing / 3) .. ")."
    for _, public in ipairs(zone.publics) do
        lines[#lines + 1] = "Group event, " .. public.name .. ": " .. status(public.done)
    end
    if zone.story then
        local s = zone.story
        lines[#lines + 1] = "Storyline: " .. s.done .. " of " .. s.total .. " story quests done" .. (s.finished and "" or (", up to " .. points(s.points) .. " left"))
    end
    return table.concat(lines, "\n")
end

-- For the Xbox tests: what the add-on could and couldn't match. Counts first, so one photo is enough.
function Lists.Check(state)
    local c = state.check
    local noQuest = {}
    for _, dungeon in ipairs(state.dungeons) do
        if not dungeon.storyQuest then noQuest[#noQuest + 1] = dungeon.name end
    end
    local found, perCharacter, guideDone, noAchievement = 0, 0, 0, {}
    for _, public in ipairs(state.publics) do
        if public.achievementDone == nil then
            noAchievement[#noAchievement + 1] = public.name
        else
            found = found + 1
            if public.perCharacter then perCharacter = perCharacter + 1 end
        end
        if public.guideDone then guideDone = guideDone + 1 end
    end
    local unusedEvents = {}
    local index = SP.Scan.Achievements()
    for _, event in ipairs(index.groupEventList) do
        if not c.usedGroupEvents[event.id] then unusedEvents[#unusedEvents + 1] = event.name end
    end

    local lines = {
        C(SP.GOLD, "Detection check") .. C(SP.GREY, "  (RB shows the next page)"),
        "Group events: " .. #state.publics .. " in the Zone Guide, " .. found .. " paired with an achievement (" .. perCharacter .. " per character).",
        "Group Event achievements in the game: " .. #index.groupEventList .. ", not paired: " .. #unusedEvents .. ".",
        "Dungeons: " .. #state.dungeons .. " in the Dungeon Finder, " .. #noQuest .. " with no quest name on file, " .. c.matchedByName .. " quests found done by name.",
        "Other dungeon quests in history: " .. c.historyDungeonQuests .. ", not matched: " .. #c.unmatched .. ".",
        "",
    }
    if #noAchievement > 0 then
        lines[#lines + 1] = C(SP.GOLD, "Group events with no achievement paired")
        lines[#lines + 1] = table.concat(noAchievement, ", ")
        lines[#lines + 1] = ""
    end
    if #unusedEvents > 0 then
        lines[#lines + 1] = C(SP.GOLD, "Group Event achievements not paired")
        lines[#lines + 1] = table.concat(unusedEvents, ", ")
        lines[#lines + 1] = ""
    end
    if #noQuest > 0 then
        lines[#lines + 1] = C(SP.GOLD, "Dungeons with no quest name on file")
        lines[#lines + 1] = table.concat(noQuest, ", ")
        lines[#lines + 1] = ""
    end
    if #c.unmatched + #c.journalUnmatched > 0 then
        lines[#lines + 1] = C(SP.GOLD, "Dungeon quests not matched to a dungeon")
        for _, q in ipairs(c.unmatched) do lines[#lines + 1] = C(SP.GREY, q.name .. " | " .. q.zone .. " | " .. q.objective) end
        for _, q in ipairs(c.journalUnmatched) do lines[#lines + 1] = C(SP.GREY, "In journal: " .. q.name .. " | " .. q.zone) end
    end
    return table.concat(lines, "\n")
end

Lists.TABS = {
    { name = "Overview", build = Lists.Overview },
    { name = "Easiest first", build = Lists.Easiest },
    { name = "By zone", build = Lists.Zones },
    { name = "Checklist", build = Lists.Checklist },
    { name = "This zone", build = Lists.Here },
    { name = "Check", build = Lists.Check },
}
