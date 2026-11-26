-- shared
-- Skill lines (weapons, armor, guilds, world, crafting), and skill points spent and waiting.
-- The lines and their top ranks are listed in Data/Lines.lua. Ranks are saved as
--   c.lines = { ["Two Handed"] = 50, ... }   (0 = not started)
local CT = FurysCharacterTracker
local U = CT.Util

local function Rank(c, line)
    return math.min((c.lines or {})[line.name] or 0, line.max)
end

-- Columns: one per skill line, and one per group that counts its maxed lines.
local columns = {}
for _, group in ipairs(CT.GROUPS) do
    for _, line in ipairs(group.lines) do
        local what = line.name
        if line.name == "Assault" then what = "Alliance War: Assault (Support ranks with it)" end
        if line.name == "Excavation" then what = "Antiquities: Excavation (Scrying ranks with it)" end
        if line.keepPeak then what = line.name .. "\nThe game hides this line when you are cured; this shows the best rank ever seen." end
        columns[#columns + 1] = { key = "line." .. line.name, title = line.short, width = 84, max = line.max,
                                  value = function(e) return (e.c.lines or {})[line.name] or 0 end,
                                  tip = what, head = string.format("%s\nSkill line rank. The top rank is %d.", what, line.max) }
    end
    local count = #group.lines
    columns[#columns + 1] = {
        key = "group." .. group.id, title = group.short or group.title, width = 80, max = count,
        head = string.format("%s: how many of the %d %s skill lines are at their top rank.\nHover a cell for each line, or open the %s tab.",
                             group.title, count, group.title, group.title),
        value = function(e) return CT.Roster:MaxedInGroup(e.c, group) end,
        display = function(v) return U.Of(v, count) end,
        tip = function(e)
            local lines = {}
            for _, line in ipairs(group.lines) do
                lines[#lines + 1] = string.format("%s  %d / %d", line.name, Rank(e.c, line), line.max)
            end
            if group.id == "crafting" and CT.Roster:MaxedInGroup(e.c, group) >= count
               and (e.c.research or 0) >= (e.c.researchTotal or CT.RESEARCH_TOTAL) then
                lines[#lines + 1] = "Grandmaster Crafter: all 7 lines maxed and every trait researched"
            end
            return table.concat(lines, "\n")
        end }
end
columns[#columns + 1] = {
    key = "skillPoints", title = "Skill pts", width = 76, max = CT.SKILL_POINTS_MAX, value = function(e) return e.c.skillPoints or 0 end,
    head = "Skill points earned: the ones spent plus the ones not assigned yet.\nThe most a character can earn is " .. CT.SKILL_POINTS_MAX .. ".",
    tip = function(e)
        return string.format("Skill points earned: %d of %d\nNot assigned yet: %s", e.c.skillPoints or 0, CT.SKILL_POINTS_MAX, e.c.unspent or "?")
    end }
columns[#columns + 1] = {
    key = "unspent", title = "Unassigned", width = 92, value = function(e) return e.c.unspent or 0 end,
    dim = function(v) return v == 0 end, display = function(v) return v == 0 and "-" or U.Whole(v) end,
    head = "Unassigned: skill points this character has earned and not spent yet.",
    tip = function(e) return (e.c.unspent or 0) == 0 and "Every skill point is spent." or U.Count(e.c.unspent, "skill point") .. " waiting to be spent." end }

-- Game only ---------------------------------------------------------------------------------

-- Skill lines on the board: current rank, 0 if not discovered. Vampire and Werewolf vanish from
-- the skill list when cured, so those keep the best rank ever seen.
local function ReadLines(c)
    local previous, lines = c.lines or {}, {}
    for _, skillType in ipairs({ SKILL_TYPE_WEAPON, SKILL_TYPE_ARMOR, SKILL_TYPE_WORLD, SKILL_TYPE_GUILD, SKILL_TYPE_AVA, SKILL_TYPE_TRADESKILL }) do
        for lineIndex = 1, GetNumSkillLines(skillType) do
            local lineId = GetSkillLineId(skillType, lineIndex)
            -- By ID on every game language; by its English name for a line this version has no ID for.
            local name = CT.SKILL_LINE_IDS[lineId] or U.Plain(GetSkillLineNameById(lineId))
            if CT.LINE_BY_NAME[name] then
                local rank, _, _, isDiscovered = GetSkillLineDynamicInfo(skillType, lineIndex)
                lines[name] = isDiscovered and rank or 0
            end
        end
    end
    for lineName, def in pairs(CT.LINE_BY_NAME) do
        if def.keepPeak and previous[lineName] then
            lines[lineName] = math.max(lines[lineName] or 0, previous[lineName])
        end
    end
    c.lines = lines
end

-- Points spent on every skill plus the ones not spent yet. Asks the game's own skill data (what the
-- Skills window uses for respec), so morphs, passive ranks, free auto-granted skills and subclass
-- lines are all counted the way the game counts them.
local function ReadSkillPoints(c)
    local spent = 0
    -- These loops hand back (index, data), like ipairs.
    for _, skillTypeData in SKILLS_DATA_MANAGER:SkillTypeIterator() do
        for _, skillLineData in skillTypeData:SkillLineIterator() do
            for _, skillData in skillLineData:SkillIterator() do
                spent = spent + skillData:GetPointAllocator():GetNumPointsAllocated()
            end
        end
    end
    c.unspent = GetAvailableSkillPoints()
    -- Nothing spent means the skill data is not ready yet: keep the last good number.
    if spent > 0 then c.skillPoints = spent + c.unspent end
end

CT.Track({
    id = "skills",
    read = function(c)
        ReadLines(c)
        ReadSkillPoints(c)
    end,
    events = { EVENT_SKILL_RANK_UPDATE, EVENT_SKILL_LINE_ADDED, EVENT_SKILL_POINTS_CHANGED },
    columns = columns,
    summary = function(e)
        local P = CT.Trackers.Progress
        local items = { P("Skill points", e.c.skillPoints, CT.SKILL_POINTS_MAX), { "Not assigned", tostring(e.c.unspent or "-") } }
        for _, group in ipairs(CT.GROUPS) do
            if group.id == "crafting" then items[#items + 1] = P("Crafting lines at 50", CT.Roster:MaxedInGroup(e.c, group), #group.lines) end
        end
        return items
    end,
    sections = function(e)
        local sections = {}
        for _, group in ipairs(CT.GROUPS) do
            local items = {}
            for _, line in ipairs(group.lines) do
                items[#items + 1] = CT.Trackers.Progress(line.name, Rank(e.c, line), line.max)
            end
            sections[#sections + 1] = { title = string.format("%s (%d of %d maxed)", group.title, CT.Roster:MaxedInGroup(e.c, group), #group.lines),
                                        items = items }
        end
        return sections
    end,
    export = (function()
        local list = { { "Skill points", function(e) return e.c.skillPoints end }, { "Unassigned", function(e) return e.c.unspent end } }
        for _, group in ipairs(CT.GROUPS) do
            for _, line in ipairs(group.lines) do
                list[#list + 1] = { line.name, function(e) return Rank(e.c, line) end }
            end
        end
        return list
    end)(),
})
