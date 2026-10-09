-- Trial Tagger: reads achievement completion and turns it into payload bits.

TrialTagger = TrialTagger or {}
local TT = TrialTagger
local Scanner = {}
TT.Scanner = Scanner

--- Completion state of a single achievement id.
-- Returns nil when the id does not resolve, which is how an out-of-date
-- catalog shows up (a removed or mistyped id) rather than silently reading
-- as "not earned".
function Scanner.GetAchievement(id)
    if not id or id <= 0 then return nil end
    local name, description, points, icon, completed = GetAchievementInfo(id)
    if not name or name == "" then return nil end
    -- The title an achievement grants is not the achievement's own name:
    -- "Maw of Lorkhaj: Moons' Champion" grants "Dro-m'Athra Destroyer". The
    -- catalog names roles after the title wherever one exists, and nothing in
    -- GetAchievementInfo carries it, so it has to be read separately.
    local hasTitle, title = GetAchievementRewardTitle(id)
    return {
        id = id,
        name = name,
        description = description,
        points = points,
        icon = icon,
        completed = completed == true,
        -- nil rather than "" when there is no title, so the dump does not
        -- gain an empty key on each of the ~4000 achievements that grant none.
        title = (hasTitle and title ~= "") and title or nil,
    }
end

function Scanner.IsComplete(id)
    local info = Scanner.GetAchievement(id)
    return info ~= nil and info.completed
end

--- Evaluate one slot for one trial.
-- Returns earned (boolean) and configured (boolean). A slot with no ids is
-- unconfigured: it encodes as 0 and the panel shows "?" so the player can see
-- the catalog is incomplete rather than assuming they lack the achievement.
function Scanner.EvaluateSlot(trial, slot)
    local ids = slot.ids
    if not ids or #ids == 0 then
        return false, false
    end

    local tier = TT.Catalog.tierByKey[slot.tier]
    if tier and tier.match == "any" then
        for _, id in ipairs(ids) do
            if Scanner.IsComplete(id) then return true, true end
        end
        return false, true
    end

    for _, id in ipairs(ids) do
        if not Scanner.IsComplete(id) then return false, true end
    end
    return true, true
end

--- Build the per-trial value array, the matching widths, and a UI grid.
-- Trials have different slot counts, so the encoder needs the widths to know
-- how many bits each value contributes.
function Scanner.Evaluate()
    local catalog = TT.Catalog
    local values, widths, grid = {}, {}, {}

    for _, trial in ipairs(catalog.trials) do
        local value = 0
        local row = {}
        for _, slot in ipairs(trial.slots) do
            local earned, configured = Scanner.EvaluateSlot(trial, slot)
            if earned then value = value + slot.mask end
            row[slot.key] = { earned = earned, configured = configured }
        end
        -- trial.index is 0-based (it is a bit stream position); Lua is 1-based.
        values[trial.index + 1] = value
        widths[trial.index + 1] = trial.width
        grid[trial.key] = row
    end

    return values, widths, grid
end

----------------------------------------------------------------------------
-- Harvest: walk the achievement tree to discover ids for the catalog.
----------------------------------------------------------------------------

--- Expand an achievement "line" (e.g. Vanquisher -> Conqueror -> ...).
-- The category listing only exposes the first achievement of a line, so a
-- naive walk misses most veteran and hard mode entries.
local function collectLine(firstId, out)
    local id, guard = firstId, 0
    while id and id > 0 and guard < 64 do
        local info = Scanner.GetAchievement(id)
        if info then out[#out + 1] = info end
        id = GetNextAchievementInLine(id)
        guard = guard + 1
    end
end

--- Every achievement under one category/subcategory, lines expanded.
-- Pass subCategoryIndex = nil for achievements that sit directly on the
-- category.
function Scanner.GetAchievementsIn(categoryIndex, subCategoryIndex, count)
    local out = {}
    for i = 1, count do
        local id = GetAchievementId(categoryIndex, subCategoryIndex, i)
        if id and id > 0 then
            collectLine(id, out)
        end
    end
    return out
end

--- Flat list of {categoryIndex, subCategoryIndex, name, count} pages.
function Scanner.BuildHarvestPages()
    local pages = {}
    for categoryIndex = 1, GetNumAchievementCategories() do
        local name, numSubCategories, numAchievements = GetAchievementCategoryInfo(categoryIndex)
        if numAchievements and numAchievements > 0 then
            pages[#pages + 1] = {
                categoryIndex = categoryIndex,
                subCategoryIndex = nil,
                title = name,
                count = numAchievements,
            }
        end
        for subIndex = 1, (numSubCategories or 0) do
            local subName, subCount = GetAchievementSubCategoryInfo(categoryIndex, subIndex)
            if subCount and subCount > 0 then
                pages[#pages + 1] = {
                    categoryIndex = categoryIndex,
                    subCategoryIndex = subIndex,
                    title = name .. " / " .. subName,
                    count = subCount,
                }
            end
        end
    end
    return pages
end

--- Dump every harvest page into SavedVariables.
-- Only useful on PC, where SavedVariables land in a readable .lua file. On
-- console use the in-game harvest view instead.
function Scanner.DumpToSavedVars(savedVars)
    local dump = {}
    for _, page in ipairs(Scanner.BuildHarvestPages()) do
        local entries = {}
        for _, info in ipairs(Scanner.GetAchievementsIn(page.categoryIndex, page.subCategoryIndex, page.count)) do
            -- The description and the points are what tell two achievements
            -- apart when the game gives them the same name, which it does:
            -- Sunspire has two called "Sunspire Vanquisher", and only the
            -- text and the score say which one is the veteran hard mode.
            entries[#entries + 1] = {
                id = info.id,
                name = info.name,
                description = info.description,
                points = info.points,
                completed = info.completed,
                -- Absent for most achievements. Present for the ones the
                -- catalog should be naming roles after.
                title = info.title,
            }
        end
        dump[page.title] = entries
    end
    savedVars.harvest = dump
    savedVars.harvestedAt = GetTimeStamp()
    return dump
end
