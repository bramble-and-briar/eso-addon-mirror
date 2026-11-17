-- FurnishingCatalogSearchActions.lua: finds the furnishings whose name holds every search word.
--
-- Names are not kept anywhere (the catalog stores item ids only), so a search reads each name
-- from the game: about 8,300 lookups, a few hundred per frame, and nothing is cached afterwards.
-- The result has the catalog's own shape (category -> subcategory -> item ids) with only the
-- matches in it, so the screen lists it exactly like the full catalog.
local FC = FurnishingCatalog
local ScanUtils = FC.ScanUtils
local BrowseUtils = FC.BrowseUtils

local Search = {}

local UPDATE_NAME = "FurnishingCatalogSearch"
local IDS_PER_FRAME = 400
local GC_STEP_KB = 256

---@type table|nil the search being stepped
local job = nil

local function Stop()
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    job = nil
end

local function Step()
    local j = job
    if not j then
        return
    end
    j.frames = j.frames + 1
    local budget = IDS_PER_FRAME
    local words = j.words
    while budget > 0 do
        local list = j.lists[j.listIndex]
        if not list then
            break
        end
        local ids = list.ids
        local lastIndex = math.min(j.idIndex + budget - 1, #ids)
        for index = j.idIndex, lastIndex do
            local itemId = ids[index]
            local name = zo_strlower(GetItemLinkName(ScanUtils.BareLink(itemId)) or "")
            if BrowseUtils.MatchesAll(name, words) then
                ScanUtils.AddToTree(j.tree, list.categoryId, list.subcategoryId, itemId)
                j.total = j.total + 1
            end
        end
        local done = lastIndex - j.idIndex + 1
        budget = budget - done
        j.checked = j.checked + done
        if lastIndex >= #ids then
            j.listIndex = j.listIndex + 1
            j.idIndex = 1
        else
            j.idIndex = lastIndex + 1
        end
    end
    -- Every lookup leaves a link and a name behind as garbage.
    pcall(collectgarbage, "step", GC_STEP_KB)
    if j.lists[j.listIndex] then
        if j.onProgress then
            j.onProgress(j.numIds > 0 and j.checked / j.numIds or 1)
        end
        return
    end
    local onDone = j.onDone
    Stop()
    FC.Log("search '%s': %d of %d names match; %d ms over %d frames; %s", j.text, j.total, j.numIds, GetGameTimeMilliseconds() - j.startedMs, j.frames, FC.MemText())
    if onDone then
        onDone({ text = j.text, tree = j.tree, total = j.total })
    end
end

local function GuardedStep()
    local ok, err = pcall(Step)
    if not ok then
        Stop()
        table.insert(FC.diagnostics.errors, "search: " .. tostring(err))
        FC.Log("ERROR search stopped: %s", tostring(err))
    end
end

---Search the catalog; a search already running is dropped.
---@param tree table<integer, table<integer, integer[]>> the catalog: category -> subcategory -> item ids
---@param text string the search text as shown to the player
---@param words string[] its lower-case words (BrowseUtils.SearchWords)
---@param onProgress fun(fraction: number)|nil called every frame
---@param onDone fun(result: { text: string, tree: table, total: integer }) called once
function Search.Start(tree, text, words, onProgress, onDone)
    Stop()
    -- A flat list of the catalog's id lists, so the walk can stop and continue anywhere.
    local lists = {}
    local numIds = 0
    for categoryId, subcategories in pairs(tree) do
        for subcategoryId, ids in pairs(subcategories) do
            lists[#lists + 1] = { categoryId = categoryId, subcategoryId = subcategoryId, ids = ids }
            numIds = numIds + #ids
        end
    end
    job = {
        text = text, words = words, lists = lists, listIndex = 1, idIndex = 1, numIds = numIds, checked = 0, total = 0, frames = 0, tree = {},
        startedMs = GetGameTimeMilliseconds(), onProgress = onProgress, onDone = onDone,
    }
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 0, GuardedStep)
end

---Drop the search being stepped, if any.
function Search.Cancel()
    if job then
        FC.Log("search '%s' dropped at %d of %d", job.text, job.checked, job.numIds)
        Stop()
    end
end

---@return boolean
function Search.IsRunning()
    return job ~= nil
end

FC.Search = Search
