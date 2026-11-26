-- shared
-- Class skill lines. A character uses three: its own class's, or (with subclassing) up to two
-- swapped for another class's. Other lines it has trained are kept too. Saved one text per line:
--   c.classLines = { "skill line id|line name|rank|class id|class name|state", ... }
-- state: "a" one of the three in use, "t" being trained, "" trained earlier and not in use.
-- Class mastery is not kept as a line: it is not earned or ranked, it simply comes with using all
-- three of your own class's lines, so the board only says which build was picked (pure class or
-- subclassing). 1.5.0 to 1.5.3 saved it with state "m"; those rows are skipped.
local CT = FurysCharacterTracker
local U = CT.Util
local MAX = CT.CLASS_LINE_MAX

-- The saved lines of a character, split up: in use (game order) and the rest (highest rank first).
local function Lines(c)
    local active, other = {}, {}
    for _, text in ipairs(c.classLines or {}) do
        local p = U.Split(text, "|")
        local line = { id = tonumber(p[1]), name = p[2], rank = tonumber(p[3]) or 0, classId = tonumber(p[4]), class = p[5], state = p[6] or "" }
        if line.state == "a" then
            active[#active + 1] = line
        elseif line.state ~= "m" then
            other[#other + 1] = line
        end
    end
    table.sort(other, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.name < b.name
    end)
    return active, other
end

-- How many of the three lines in use come from another class (0 = a pure class build).
local function Borrowed(c)
    local n = 0
    for _, line in ipairs((Lines(c))) do
        if line.classId ~= c.classId then n = n + 1 end
    end
    return n
end

-- The build that was picked, in words.
local function BuildText(c)
    local n = Borrowed(c)
    if n == 0 then return "Pure " .. (c.class or "class") .. ": all three lines are its own, so it has class mastery." end
    return string.format("Subclassing: %s from another class, so no class mastery.", U.Count(n, "line"))
end
CT.ClassLines = Lines

local STATE = { t = "in training" }
local function Describe(line, ownClassId)
    local text = string.format("%s  %d / %d", line.name, math.min(line.rank, MAX), MAX)
    if line.classId ~= ownClassId and line.class and line.class ~= "" then text = text .. "  (" .. line.class .. ")" end
    if STATE[line.state] then text = text .. "  ·  " .. STATE[line.state] end
    return text
end

local NOT_READ = "Not read yet: log in on this character once."

local function LineColumn(index)
    return { key = "classLine" .. index, title = "Class line " .. index, width = 156, max = MAX,
             head = "A class skill line this character is using, and its rank (the top rank is " .. MAX .. ").\nWith subclassing, up to two of the three can come from another class.",
             value = function(e) local line = Lines(e.c)[index]; return line and line.rank or 0 end,
             display = function(v, e)
                 local line = Lines(e.c)[index]
                 if not line then return "-" end
                 return line.name .. "  " .. U.Whole(math.min(v, MAX))
             end,
             dim = function(_, e) return Lines(e.c)[index] == nil end,
             tip = function(e)
                 local line = Lines(e.c)[index]
                 if not e.c.classLines then return NOT_READ end
                 return line and Describe(line, e.c.classId) or "No class line here."
             end }
end

CT.Track({
    id = "classLines",
    read = function(c)
        local gender, list = GetUnitGender("player"), {}
        local skillType = SKILL_TYPE_CLASS
        for lineIndex = 1, GetNumSkillLines(skillType) do
            local rank, _, isActive, isDiscovered, _, isInTraining, isClassMastery = GetSkillLineDynamicInfo(skillType, lineIndex)
            local classId = GetSkillLineClassId(skillType, lineIndex)
            local lineId = GetSkillLineId(skillType, lineIndex)
            local state = (isActive and "a") or (isInTraining and "t") or ""
            -- A line that is neither in use nor trained is one of the other classes' untouched lines.
            local keep = not isClassMastery and (isActive or isInTraining or (isDiscovered and rank > 1))
            if keep then
                list[#list + 1] = table.concat({ lineId, U.Clean(U.Plain(GetSkillLineNameById(lineId))), rank, classId,
                                                 U.Clean(U.Plain(GetClassName(gender, classId))), state }, "|")
            end
        end
        -- Nothing found means the skill data is not ready yet: keep what was saved.
        if #list > 0 then c.classLines = list end
    end,
    events = { EVENT_SKILL_RANK_UPDATE, EVENT_SKILL_LINE_ADDED, EVENT_SKILLS_FULL_UPDATE },
    columns = {
        LineColumn(1), LineColumn(2), LineColumn(3),
        { key = "classBuild", title = "Build", width = 82, align = "left",
          head = "Build: Pure when all three class lines in use are the character's own, Subclass when one or two come from another class.\nA pure class build has class mastery; subclassing gives it up.",
          value = function(e) return e.c.classLines and Borrowed(e.c) or -1 end,
          display = function(v) return v < 0 and "-" or (v == 0 and "Pure" or "Subclass") end,
          dim = function(v) return v < 0 end,
          tip = function(e)
              if not e.c.classLines then return NOT_READ end
              return BuildText(e.c)
          end },
        { key = "classMaxed", title = "Maxed", width = 62, max = 3,
          head = "Maxed: how many of the three class lines in use are at rank " .. MAX .. ".",
          value = function(e)
              local n = 0
              for _, line in ipairs(Lines(e.c)) do if line.rank >= MAX then n = n + 1 end end
              return n
          end,
          display = function(v, e) return e.c.classLines and U.Of(v, 3) or "-" end,
          dim = function(_, e) return not e.c.classLines end,
          tip = function(e)
              if not e.c.classLines then return NOT_READ end
              local lines = {}
              for _, line in ipairs(Lines(e.c)) do lines[#lines + 1] = Describe(line, e.c.classId) end
              return table.concat(lines, "\n")
          end },
        { key = "classOther", title = "Other class lines", width = 110, align = "left",
          head = "Other class lines this character has: lines in training, and lines trained earlier that are not in use now.\nHover a cell for the whole list.",
          value = function(e) local _, other = Lines(e.c); return #other end,
          display = function(v, e)
              if v == 0 then return "-" end
              local _, other = Lines(e.c)
              local names = {}
              for i, line in ipairs(other) do
                  names[i] = line.name .. " " .. U.Whole(math.min(line.rank, MAX))
              end
              return table.concat(names, "  ·  ")
          end,
          dim = function(v) return v == 0 end,
          tip = function(e)
              if not e.c.classLines then return NOT_READ end
              local _, other = Lines(e.c)
              if #other == 0 then return "No other class lines trained." end
              local lines = {}
              for _, line in ipairs(other) do lines[#lines + 1] = Describe(line, e.c.classId) end
              return table.concat(lines, "\n")
          end },
    },
    sections = function(e)
        if not e.c.classLines then return nil end
        local active, other = Lines(e.c)
        local items = {}
        for _, line in ipairs(active) do items[#items + 1] = CT.Trackers.Progress(line.name, math.min(line.rank, MAX), MAX) end
        for _, line in ipairs(other) do
            items[#items + 1] = CT.Trackers.Progress(string.format("%s (%s)", line.name, STATE[line.state] or "not in use"), math.min(line.rank, MAX), MAX)
        end
        return { { title = "Class lines", items = items, lines = { BuildText(e.c) } } }
    end,
    export = {
        { "Class line 1", function(e) local l = Lines(e.c)[1]; return l and (l.name .. " " .. U.Whole(l.rank)) end },
        { "Class line 2", function(e) local l = Lines(e.c)[2]; return l and (l.name .. " " .. U.Whole(l.rank)) end },
        { "Class line 3", function(e) local l = Lines(e.c)[3]; return l and (l.name .. " " .. U.Whole(l.rank)) end },
        { "Build", function(e) return e.c.classLines and (Borrowed(e.c) == 0 and "Pure" or "Subclass") end },
    },
})
