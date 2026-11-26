-- High Achiever: reads every achievement's name, description and category once per session,
-- one category per frame: the console stops add-ons that use more than a second of work in one frame.
-- Only text is kept here. Whether an achievement is done is read fresh each time a list is built.

local HA = ESOC_HighAchiever
local Index = {}
HA.Index = Index

local UPDATE_NAME = "ESOCHighAchieverIndex"
local entries, categories = {}, {}
local ready, running, waiting = false, false, {}

local function add(achievementId, top, sub)
    if not achievementId or achievementId == 0 then return end
    local name, description = HA.Safe(GetAchievementInfo, achievementId)
    if type(name) ~= "string" then return end
    entries[#entries + 1] = {
        id = achievementId,
        name = HA.Lower(name),
        desc = HA.Lower(description or ""),
        top = top,
        sub = sub,
    }
end

-- Starts reading. onDone runs once everything has been read (straight away if it already has).
function Index.Start(onDone)
    if onDone then waiting[#waiting + 1] = onDone end
    if ready then
        local callbacks = waiting
        waiting = {}
        for _, callback in ipairs(callbacks) do pcall(callback) end
        return
    end
    if running then return end
    running = true
    local steps = {}
    local numCategories = HA.Safe(GetNumAchievementCategories) or 0
    for c = 1, numCategories do
        local topName, numSub, numInCategory = HA.Safe(GetAchievementCategoryInfo, c)
        local top = HA.Lower(topName or "")
        local category = { name = HA.Clean(topName or ""), subs = {} }
        categories[#categories + 1] = category
        if (numInCategory or 0) > 0 then steps[#steps + 1] = { c, nil, numInCategory, top, "" } end
        for s = 1, numSub or 0 do
            local subName, numAchievements = HA.Safe(GetAchievementSubCategoryInfo, c, s)
            category.subs[#category.subs + 1] = HA.Clean(subName or "")
            if (numAchievements or 0) > 0 then
                steps[#steps + 1] = { c, s, numAchievements, top, HA.Lower(subName or "") }
            end
        end
    end
    local nextStep = 1
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 0, function()
        local step = steps[nextStep]
        if step then
            nextStep = nextStep + 1
            for a = 1, step[3] do add(HA.Safe(GetAchievementId, step[1], step[2], a), step[4], step[5]) end
            return
        end
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
        ready, running = true, false
        HA.Place.MarkDirty()
        Index.Start()
    end)
end

function Index.Ready()
    return ready
end

function Index.Entries()
    return entries
end

function Index.Categories()
    return categories
end
