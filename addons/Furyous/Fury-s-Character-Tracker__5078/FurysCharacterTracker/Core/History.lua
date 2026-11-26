-- shared
-- Progress over time. One short text per character per day it was played, oldest first:
--   data.history[id] = { "20261125;gold;skill points;hours played;achievement points;traits researched", ... }
-- The Progress tab compares today with the line from 7 and 30 days ago.
local CT = FurysCharacterTracker
local U = CT.Util
local History = {}
CT.History = History

History.MAX_DAYS = 400   -- lines kept per character: over a year of playing it every day
-- Where each number sits in a line (the day is first).
History.FIELDS = { gold = 2, skillPoints = 3, playedHours = 4, achievementPoints = 5, research = 6 }

function History.Day(timestamp)
    return os.date("%Y%m%d", timestamp)
end

function History.Line(c, timestamp)
    return table.concat({ History.Day(timestamp), c.gold or 0, c.skillPoints or 0, c.playedHours or 0,
                          c.achievementPoints or 0, c.research or 0 }, ";")
end

-- Called after every read of a character: today's line is added, or replaced if there is one.
function History.Record(data, id, c, now)
    now = now or GetTimeStamp()
    local list = data.history[id] or {}
    data.history[id] = list
    local line = History.Line(c, now)
    local last = list[#list]
    if last and string.sub(last, 1, 8) == string.sub(line, 1, 8) then
        list[#list] = line
    else
        list[#list + 1] = line
        if #list > History.MAX_DAYS then table.remove(list, 1) end
    end
end

-- The line to compare with: the newest one from `days` ago or before. A character tracked for
-- less time than that is compared with its first line.
-- Returns the line's numbers as a list and its day ("YYYYMMDD"), or nil when nothing is saved.
function History.Baseline(list, days, now)
    if not list or #list == 0 then return nil end
    local target = History.Day(now - days * 86400)
    local found = list[1]
    for index = #list, 1, -1 do
        if string.sub(list[index], 1, 8) <= target then
            found = list[index]
            break
        end
    end
    local parts = U.Split(found, ";")
    for index = 2, #parts do parts[index] = tonumber(parts[index]) or 0 end
    return parts, parts[1]
end

-- How much `field` grew over the last `days` days, and the day it is counted from.
function History.Delta(data, id, c, field, days, now)
    local base, day = History.Baseline(data.history[id], days, now or GetTimeStamp())
    if not base then return nil end
    return (c[field] or 0) - (base[History.FIELDS[field]] or 0), day
end

-- "20261125" -> "2026-11-25"
function History.DayText(day)
    return string.sub(day, 1, 4) .. "-" .. string.sub(day, 5, 6) .. "-" .. string.sub(day, 7, 8)
end

-- The first day a character has a line for, or nil.
function History.Since(data, id)
    local list = data.history[id]
    return list and list[1] and string.sub(list[1], 1, 8) or nil
end
