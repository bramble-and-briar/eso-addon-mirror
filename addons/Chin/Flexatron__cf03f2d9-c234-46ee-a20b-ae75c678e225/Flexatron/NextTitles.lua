-- Next titles: the titles the player is closest to unlocking, with progress, for the info panel
-- beside the settings list. Worked out each time the panel shows them, so it's always current.
local FT = Flexatron
local Titles = FT.Titles
local L = FT.L
local NextTitles = {}
FT.NextTitles = NextTitles

local LIMIT = 50
local ACHIEVEMENT_COLOR = "A0A0A0" -- the achievement under each title, in grey

-- The closest unfinished titles: { { id, title, done, need }, ... }, one entry per title, leaving
-- out titles the player already has.
function NextTitles.Find(limit)
    local candidates = {}
    for _, entry in ipairs(FT.TitleIndex.Entries()) do
        if not IsAchievementComplete(entry.id) and not Titles.IndexOf(entry.title) then
            local done, need = 0, 0
            for n = 1, GetAchievementNumCriteria(entry.id) do
                local _, completed, required = GetAchievementCriterion(entry.id, n)
                required = required or 0
                need = need + required
                done = done + math.min(completed or 0, required)
            end
            if need > 0 then
                candidates[#candidates + 1] = { id = entry.id, title = entry.title, done = done, need = need }
            end
        end
    end
    table.sort(candidates, function(a, b)
        local ra, rb = a.done / a.need, b.done / b.need
        if ra ~= rb then
            return ra > rb
        end
        if a.need - a.done ~= b.need - b.done then
            return a.need - a.done < b.need - b.done
        end
        return a.id < b.id
    end)
    local picked, seen = {}, {}
    for _, candidate in ipairs(candidates) do
        local shownAs = Titles.Format(candidate.title)
        if not seen[shownAs] then
            seen[shownAs] = true
            picked[#picked + 1] = candidate
            if #picked >= (limit or LIMIT) then
                break
            end
        end
    end
    return picked
end

-- The info panel's text: how many, then each title with its progress, and the achievement that
-- grants it on the line below in grey. Closest first.
function NextTitles.PanelText()
    local picked = NextTitles.Find(LIMIT)
    if #picked == 0 then
        return L.NEXT_NONE
    end
    local lines = { string.format(L.NEXT_HEADER, #picked) }
    for _, candidate in ipairs(picked) do
        lines[#lines + 1] = string.format(L.NEXT_LINE, Titles.Format(candidate.title), candidate.done, candidate.need)
        lines[#lines + 1] = "|c" .. ACHIEVEMENT_COLOR .. zo_strformat("<<1>>", (GetAchievementInfo(candidate.id))) .. "|r"
    end
    return table.concat(lines, "\n")
end
