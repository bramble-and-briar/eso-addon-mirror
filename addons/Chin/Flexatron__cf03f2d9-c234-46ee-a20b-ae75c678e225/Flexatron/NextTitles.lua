-- Next titles: the titles the player is closest to unlocking, with progress. Runs on demand.
local FT = Flexatron
local Titles = FT.Titles
local L = FT.L
local NextTitles = {}
FT.NextTitles = NextTitles

local LIMIT = 5
local lastText

-- Titles the player has, by raw name and as they read.
local function Owned()
    local raw, shown = {}, {}
    for i = 1, GetNumTitles() do
        local name = GetTitle(i)
        raw[name] = true
        shown[Titles.Format(name)] = true
    end
    return raw, shown
end

-- The closest unfinished titles: { { id, title, done, need }, ... }, one entry per title.
function NextTitles.Find(limit)
    local raw, shown = Owned()
    local candidates = {}
    for _, entry in ipairs(FT.TitleIndex.Entries()) do
        if not IsAchievementComplete(entry.id) and not raw[entry.title] and not shown[Titles.Format(entry.title)] then
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

-- The settings button: fill the label and list them in chat with achievement links.
function NextTitles.Show()
    local picked = NextTitles.Find(LIMIT)
    if #picked == 0 then
        lastText = L.NEXT_NONE
        CHAT_ROUTER:AddSystemMessage(L.NEXT_NONE)
        return
    end
    local lines = {}
    CHAT_ROUTER:AddSystemMessage(L.NEXT_HEADER)
    for _, candidate in ipairs(picked) do
        local title = Titles.Format(candidate.title)
        lines[#lines + 1] = string.format(L.NEXT_LINE, title, candidate.done, candidate.need)
        CHAT_ROUTER:AddSystemMessage(string.format(L.NEXT_CHAT, title, candidate.done, candidate.need,
            GetAchievementLink(candidate.id, LINK_STYLE_BRACKETS)))
    end
    lastText = table.concat(lines, "\n")
end

function NextTitles.Text()
    return lastText or L.NEXT_NOT_RUN
end
