-- Groupbound_Achieve.lua : achievements a group asks for. Leaders often want an achievement
-- ("need Godslayer"), and players asked to see what it is and whether they have it (ESO forums,
-- Group Finder feedback). Found two ways:
--   links   an achievement link in the post or listing (|H1:achievement:<id>:...|h)
--   names   the name of one of that trial's / dungeon's achievements written in the text (the
--           achievements in the journal sub-category with the run's name, e.g. Trials > Sunspire)
-- Only YOUR progress can be read: whether another player really has a linked achievement can't be
-- checked by an addon (the tooltips say so).
-- Calls read from esoui "live" achievements.lua: GetNumAchievementCategories,
-- GetAchievementCategoryInfo, GetAchievementSubCategoryInfo, GetAchievementId, GetAchievementInfo,
-- GetAchievementNumCriteria, GetAchievementCriterion, GetAchievementLink.

local G = Groupbound
local Content = G.Content
local Achieve = {}
G.Achieve = Achieve

local MAX_SHOWN = 3
local MIN_NAME = 6          -- shorter names ("Sunspire"?) are too likely to be ordinary words

-- ---------------------------------------------------------------------------
-- One achievement

function Achieve.Name(id)
    local ok, name = pcall(GetAchievementInfo, id)
    if ok and name and name ~= "" then return zo_strformat("<<1>>", name) end
end

-- name, description, points, icon, you have it
function Achieve.Info(id)
    local ok, name, desc, points, icon, done = pcall(GetAchievementInfo, id)
    if not ok or not name or name == "" then return nil end
    return zo_strformat("<<1>>", name), desc or "", points or 0, icon, done and true or false
end

-- the run's achievements for the picker: one entry per name (the game keeps some in stages under
-- the same name: "Sunspire Vanquisher" twice); of those, the one you don't have yet
function Achieve.Unique(key)
    local out, byName = {}, {}
    for _, a in ipairs(Achieve.ForContent(key)) do
        local done = Achieve.Status(a.id)
        local have = byName[a.low]
        if not have then
            local entry = { id = a.id, name = a.name, low = a.low, done = done }
            byName[a.low] = entry
            out[#out + 1] = entry
        elseif have.done and not done then
            have.id, have.done = a.id, false
        end
    end
    return out
end

function Achieve.Icon(id)
    local ok, _, _, _, icon = pcall(GetAchievementInfo, id)
    return ok and icon or nil
end

function Achieve.Link(id)
    if not GetAchievementLink then return Achieve.Name(id) end
    local ok, link = pcall(GetAchievementLink, id, LINK_STYLE_BRACKETS)
    if ok and link and link ~= "" then return link end
    return Achieve.Name(id)
end

-- you have it (true / false), and "3 / 5" when it counts something
function Achieve.Status(id)
    local ok, _, _, _, _, done = pcall(GetAchievementInfo, id)
    if not ok then return false, nil end
    if done then return true, nil end
    local okN, n = pcall(GetAchievementNumCriteria, id)
    if not okN or not n or n == 0 then return false, nil end
    local have, need = 0, 0
    for i = 1, n do
        local okC, _, numDone, numRequired = pcall(GetAchievementCriterion, id, i)
        if okC and numRequired then
            have = have + math.min(numDone or 0, numRequired)
            need = need + numRequired
        end
    end
    if need > 1 then return false, string.format("%d / %d", have, need) end
    return false, nil
end

-- ---------------------------------------------------------------------------
-- A run's achievements (the journal's sub-category with the run's name), read once

local subByName      -- [lowercase sub-category name] = { cat, sub }
local byContent = {} -- [content key] = { { id, name, low } }

local function IndexSubCategories()
    subByName = {}
    if not GetNumAchievementCategories then return end
    local okN, numCats = pcall(GetNumAchievementCategories)
    for cat = 1, (okN and numCats or 0) do
        local ok, _, numSubs = pcall(GetAchievementCategoryInfo, cat)
        for sub = 1, (ok and numSubs or 0) do
            local okSub, name = pcall(GetAchievementSubCategoryInfo, cat, sub)
            if okSub and name and name ~= "" then
                subByName[zo_strlower(zo_strformat("<<1>>", name))] = { cat = cat, sub = sub }
            end
        end
    end
end

function Achieve.ForContent(key)
    if not key then return {} end
    if byContent[key] then return byContent[key] end
    if not subByName then IndexSubCategories() end
    local list = {}
    local where = subByName[zo_strlower(Content.Name(key) or "")]
    if where then
        local ok, _, numAch = pcall(GetAchievementSubCategoryInfo, where.cat, where.sub)
        for i = 1, (ok and numAch or 0) do
            local okId, id = pcall(GetAchievementId, where.cat, where.sub, i)
            if okId and id and id ~= 0 then
                local name = Achieve.Name(id)
                if name then list[#list + 1] = { id = id, name = name, low = zo_strlower(name) } end
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    byContent[key] = list
    return list
end

-- ---------------------------------------------------------------------------
-- Finding them in a text

-- achievement ids linked in a raw text (with its |H...|h links)
function Achieve.FromLinks(raw, out, seen)
    out, seen = out or {}, seen or {}
    if not raw or raw == "" then return out, seen end
    for id in raw:gmatch("|H%d:achievement:(%d+)") do
        id = tonumber(id)
        if id and not seen[id] and #out < MAX_SHOWN then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    return out, seen
end

-- achievement ids for a text: links first, then names of the run's achievements
function Achieve.InText(raw, contentKey, out, seen)
    out, seen = Achieve.FromLinks(raw, out, seen)
    if contentKey and raw and raw ~= "" and #out < MAX_SHOWN then
        local low = zo_strlower(G.Parse.Clean(raw))
        for _, a in ipairs(Achieve.ForContent(contentKey)) do
            if #a.low >= MIN_NAME and not seen[a.id] and low:find(a.low, 1, true) then
                seen[a.id] = true
                out[#out + 1] = a.id
                if #out >= MAX_SHOWN then break end
            end
        end
    end
    return out, seen
end

-- the achievements a board entry asks for (ids, at most 3) or nil
function Achieve.Find(e)
    local out, seen = {}, {}
    -- (not ipairs over the four: a missing one would end the loop early)
    local texts = { e.title or "", e.desc or "", e.raw or "", e.chatRaw or "" }
    for i = 1, #texts do
        if texts[i] ~= "" then Achieve.InText(texts[i], e.content, out, seen) end
    end
    return #out > 0 and out or nil
end
