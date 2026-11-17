-- FurnishingCatalogScanActions.lua: builds the catalog (item ids filed by category and subcategory).
--
-- Two passes, both cut into small slices per frame and both run only while the catalog screen is
-- open:
--   seed pass  - the first open looks up the ids of the built-in list (FurnishingCatalogSeed.lua,
--                a few thousand) and files each by the game's own category. About a second.
--   full scan  - /furn scan walks every item id (no "list all furnishings" call exists) to find
--                what the built-in list lacks, and every furnishing plan with the furnishing it
--                makes. Its progress lives in saved variables, so leaving the screen pauses it
--                and /furn scan continues. Its summary says how the game's own answer stands to
--                the built-in list.
-- Every lookup builds an item-link string that is garbage right after, so each frame does a small
-- fixed amount of work, asks the collector for a step, and forces a full collection whenever
-- memory has grown GARBAGE_LIMIT_KB over its low-water mark.
--
-- The full scan's real cost is outside the Lua heap. Seen on console (0.9.0 and 0.9.1,
-- 2026-11-16): asking about an item that exists for the first time costs about 0.8 KB of the
-- add-on pool (38,309 items: +30.2 MB) which no collection returns, with the Lua heap level
-- throughout; an id that holds no item costs nothing (20,000 of them: +0.00 MB). 0.9.0 walked
-- the pool from 46 to about 85 of 100 MB and the UI went down. A UI reload gives the memory
-- back sometimes (two reloads started 40 and 15 MB up, a third at the baseline); a game restart
-- always did. The items from id 80,000 up come to about the whole pool, so the full scan
-- watches the pool and pauses itself while POOL_RESERVE_MB is still free: it takes several
-- sessions to finish (three, on the console that ran it).
local FC = FurnishingCatalog
local ScanUtils = FC.ScanUtils

local Scan = {}

local UPDATE_NAME = "FurnishingCatalogScan"
local SEED_IDS_PER_FRAME = 300
local FULL_IDS_PER_FRAME = 400
local BATCH_SIZE = 50             -- ids between two looks at the clock
local FRAME_BUDGET_MS = 4
local GC_STEP_KB = 256            -- collector work requested per frame
local GARBAGE_LIMIT_KB = 2048     -- growth over the low-water mark that forces a full collection
local PROGRESS_INTERVAL_MS = 250
local MARKER_INTERVAL_MS = 1000
local COLLECT_LOG_LIMIT = 10
local POOL_RESERVE_MB = 25        -- the full scan pauses itself while this much of the add-on pool is still free
local POOL_LOG_EVERY_IDS = 10000  -- the full scan logs the pool this often: what an id costs
local MISSING_LOG_LIMIT = 40      -- built-in ids that are no furnishing here, logged per seed pass

-- Furnishings whose real links were seen in a console log: the summary logs what a subtype-0
-- link reports for them (quality in the real link: 5, 2, 5, 2, 3, 2).
local KNOWN_SAMPLE_IDS = { 125550, 120648, 140456, 120652, 145417, 139122 }

---@type FurnishingCatalogScanProgress|nil the pass being stepped right now
local run = nil
local seedIds = nil      -- the built-in list, expanded, during a seed pass
local onProgress = nil
local onDone = nil
local onPaused = nil     -- the full scan paused itself to keep the add-on pool's reserve
local nextPoolLogId = 0
local activeSinceMs = 0
local lastProgressMs = 0
local lastMarkerMs = 0
local memory = { lowKb = nil, stepWorks = true, collectLogs = 0 }

---@return string
function Scan.Stamp()
    return tostring(GetAPIVersion()) .. "|" .. tostring(GetESOVersionString())
end

---@return string
function Scan.SeedVersion()
    return tostring(FC.Seed and FC.Seed.version)
end

---Lua memory in use, in KB (nil when the client does not report it).
---@return number|nil
function Scan.MemoryKb()
    local ok, kb = pcall(collectgarbage, "count")
    return ok and kb or nil
end

---The saved catalog, when it is from this client version.
---@return FurnishingCatalogCache|nil
function Scan.GetCatalog()
    local catalog = FC.state.savedVars.catalog
    if ScanUtils.IsCatalogUsable(catalog, Scan.Stamp(), Scan.SeedVersion()) then
        return catalog
    end
    return nil
end

---Saved progress of a paused full scan, when it can be continued.
---@return FurnishingCatalogScanProgress|nil
function Scan.GetSavedProgress()
    local progress = FC.state.savedVars.scanProgress
    if ScanUtils.IsProgressUsable(progress, Scan.Stamp()) then
        return progress
    end
    return nil
end

---Drop the saved catalog and any paused full scan: the next open starts from the built-in list.
function Scan.Reset()
    FC.state.savedVars.catalog = nil
    FC.state.savedVars.scanProgress = nil
end

---@return string|nil kind "seed" or "full" while a pass is being stepped
function Scan.RunningKind()
    return run and run.kind or nil
end

---@return boolean
function Scan.IsRunning()
    return run ~= nil
end

---Progress of the pass being stepped.
---@return { kind: string, fraction: number, found: integer }|nil
function Scan.GetProgress()
    if not run then
        return nil
    end
    local fraction
    if run.kind == "seed" then
        fraction = seedIds and #seedIds > 0 and (run.nextIndex - 1) / #seedIds or 1
    else
        fraction = ScanUtils.FullScanFraction(run.nextId, run.lastValidId)
    end
    return { kind = run.kind, fraction = fraction, found = run.total }
end

---Whether the add-on pool has room for (more of) the full scan, and what to tell the player
---when it has not.
---@return boolean hasRoom
---@return string|nil text why not
function Scan.FullScanRoom()
    local used, capacity = FC.PoolMb()
    -- No pool figures (PC), no limit to keep clear of.
    if not used or not capacity or capacity <= 0 or (capacity - used) >= POOL_RESERVE_MB then
        return true, nil
    end
    return false, FC.Fmt("add-on memory is at %d of %d MB. Checking items uses memory the game holds on to: reload the UI (restart the game if that frees too little), then /furn scan.", math.floor(used), math.floor(capacity))
end

---Keep the garbage the lookups leave behind small: a collector step every frame, and a full
---collection when memory has still grown too far over its low-water mark.
---@param r FurnishingCatalogScanProgress
local function ControlGarbage(r)
    if memory.stepWorks then
        memory.stepWorks = pcall(collectgarbage, "step", GC_STEP_KB)
    end
    local kb = Scan.MemoryKb()
    if not kb then
        return
    end
    if not memory.lowKb or kb < memory.lowKb then
        memory.lowKb = kb
    end
    if kb > (r.peakMemoryKb or 0) then
        r.peakMemoryKb = kb
    end
    if kb - memory.lowKb > GARBAGE_LIMIT_KB then
        local startedMs = GetGameTimeMilliseconds()
        collectgarbage("collect")
        local afterKb = Scan.MemoryKb() or kb
        memory.lowKb = afterKb
        r.fullCollects = (r.fullCollects or 0) + 1
        if memory.collectLogs < COLLECT_LOG_LIMIT then
            memory.collectLogs = memory.collectLogs + 1
            FC.Log("full collection #%d: %d KB -> %d KB in %d ms (step works: %s)", r.fullCollects, kb, afterKb, GetGameTimeMilliseconds() - startedMs, tostring(memory.stepWorks))
        end
    end
end

---File one furnishing. Items the client has no name for are placeholders and are left out.
---@param r FurnishingCatalogScanProgress
---Whether an item of another type than furnishing still belongs in the catalog: the game lets
---players place some of those too (Furniture Finder's field notes; on console 26 of the built-in
---list's ids were not of type furnishing, attunable crafting stations among them).
---@param link string
---@return boolean
local function IsPlaceable(link)
    local ok, placeable = pcall(IsItemLinkPlaceableFurniture, link)
    return ok and placeable == true
end

---@param itemId integer
---@param link string
local function Record(r, itemId, link)
    local name = GetItemLinkName(link)
    if name == nil or name == "" then
        r.unnamed = r.unnamed + 1
        return
    end
    local categoryId, subcategoryId
    local furnitureDataId = GetItemLinkFurnitureDataId(link)
    if furnitureDataId and furnitureDataId ~= 0 then
        categoryId, subcategoryId = GetFurnitureDataInfo(furnitureDataId)
    end
    ScanUtils.AddToTree(r.tree, categoryId, subcategoryId, itemId)
    r.total = r.total + 1
    if itemId > r.maxFurnishingId then
        r.maxFurnishingId = itemId
    end
end

---A furnishing plan met by the full scan: note the furnishing it makes.
---@param itemId integer the plan's item id
---@param link string
local function RecordPlan(r, itemId, link)
    local resultLink = GetItemLinkRecipeResultItemLink(link, LINK_STYLE_DEFAULT)
    local resultId = resultLink and resultLink ~= "" and GetItemLinkItemId(resultLink) or 0
    if resultId and resultId > 0 then
        r.plans[#r.plans + 1] = resultId
        r.plans[#r.plans + 1] = itemId
    end
end

---Stop stepping. A full scan keeps its progress in saved variables; a seed pass is dropped.
local function StopStepping()
    if run then
        run.elapsedMs = (run.elapsedMs or 0) + (GetGameTimeMilliseconds() - activeSinceMs)
    end
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    FC.state.savedVars.scanMarker = nil
    run = nil
    seedIds = nil
    onProgress = nil
    onDone = nil
    onPaused = nil
end

---The full scan, once a frame: log what the ids cost, and pause while the pool's reserve is
---still free. Progress stays in saved variables, so /furn scan continues in a later session.
---@param r FurnishingCatalogScanProgress
---@return boolean paused
local function KeepPoolReserve(r)
    if r.nextId >= nextPoolLogId then
        nextPoolLogId = (math.floor(r.nextId / POOL_LOG_EVERY_IDS) + 1) * POOL_LOG_EVERY_IDS
        FC.Log("  full scan at id %d: %d ids held an item, %d furnishings, %d plans; %s", r.nextId, r.valid or 0, r.total, math.floor(#(r.plans or {}) / 2), FC.MemText())
    end
    local hasRoom, text = Scan.FullScanRoom()
    if hasRoom then
        return false
    end
    local percent = math.floor(ScanUtils.FullScanFraction(r.nextId, r.lastValidId) * 100)
    FC.Log("full scan paused itself at id %d (%d%%, %d found) after %d frames: %s", r.nextId, percent, r.total, r.frames, FC.MemText())
    local paused = onPaused
    StopStepping()
    if paused then
        paused(FC.Fmt("Scan paused at %d%%: %s", percent, text))
    end
    return true
end

local function LogSummary(r, catalog)
    local _, numCategories, numSubcategories = ScanUtils.CountTree(catalog.tree)
    FC.Log("%s done: %d furnishings in %d categories / %d subcategories; %d ms over %d frames; %d unnamed, %d not in this client; %d full collections; peak %s KB, now %s KB",
        r.kind == "seed" and "seed pass" or "full scan", catalog.total, numCategories, numSubcategories, catalog.scanMs, catalog.scanFrames, r.unnamed, r.missing,
        r.fullCollects or 0, tostring(r.peakMemoryKb and math.floor(r.peakMemoryKb)), tostring(Scan.MemoryKb() and math.floor(Scan.MemoryKb())))
    FC.Log("  memory after the pass: %s", FC.MemText())
    if r.kind == "full" then
        FC.Log("full scan walked ids %d-%d, last item id %d, resumed %d time(s)", ScanUtils.FIRST_ID, r.nextId - 1, r.lastValidId, r.resumes or 0)
        -- The game's own answer beside the built-in list: could the list be dropped?
        local found = {}
        for _, subcategories in pairs(catalog.tree) do
            for _, ids in pairs(subcategories) do
                for _, itemId in ipairs(ids) do
                    found[#found + 1] = itemId
                    found[#found + 1] = 1
                end
            end
        end
        local listed = {}
        for _, itemId in ipairs(ScanUtils.ExpandRanges(FC.Seed and FC.Seed.ranges or {})) do
            listed[#listed + 1] = itemId
            listed[#listed + 1] = 1
        end
        local furnishings = ScanUtils.ComparePairs(ScanUtils.SortedPairs(found), listed)
        FC.Log("  scan vs built-in list, furnishings: %d in both, %d only in the scan, %d only in the list (%s)", furnishings.same, furnishings.onlyOurs, furnishings.onlyTheirs, table.concat(furnishings.examples, ", "))
        local plans = ScanUtils.ComparePairs(catalog.plans or {}, FC.Seed and FC.Seed.plans or {})
        FC.Log("  scan vs built-in list, plans: %d found; %d the same, %d naming another plan, %d only in the scan, %d only in the list (%s)", math.floor(#(catalog.plans or {}) / 2),
            plans.same, plans.different, plans.onlyOurs, plans.onlyTheirs, table.concat(plans.examples, ", "))
    end
    for _, itemId in ipairs(KNOWN_SAMPLE_IDS) do
        local link = ScanUtils.BareLink(itemId)
        FC.Log("  sample %d '%s' type=%s quality(subtype 0)=%s canPreview=%s furnitureDataId=%s", itemId, tostring(GetItemLinkName(link)),
            tostring(GetItemLinkItemType(link)), tostring(GetItemLinkDisplayQuality(link)), tostring(CanItemLinkBePreviewed(link)), tostring(GetItemLinkFurnitureDataId(link)))
    end
end

---@param r FurnishingCatalogScanProgress
local function Finish(r)
    local elapsedMs = (r.elapsedMs or 0) + (GetGameTimeMilliseconds() - activeSinceMs)
    ---@type FurnishingCatalogCache
    local catalog = {
        stamp = Scan.Stamp(),
        source = r.kind,
        seedVersion = Scan.SeedVersion(),
        total = r.total,
        maxId = r.maxFurnishingId,
        tree = r.tree,
        -- A full scan's own (furnishing, plan) pairs; a seed catalog uses the built-in ones.
        plans = r.kind == "full" and ScanUtils.SortedPairs(r.plans or {}) or nil,
        scanMs = elapsedMs,
        scanFrames = r.frames,
    }
    local done = onDone
    StopStepping()
    FC.state.savedVars.catalog = catalog
    if r.kind == "full" then
        FC.state.savedVars.scanProgress = nil
    end
    FC.SafeCall("scan summary", LogSummary, r, catalog)
    if done then
        done(catalog)
    end
end

---One frame of the seed pass: look up the next ids of the built-in list.
---@return boolean finished
local function StepSeed(r)
    local ids = seedIds
    local lastIndex = math.min(r.nextIndex + SEED_IDS_PER_FRAME - 1, #ids)
    for index = r.nextIndex, lastIndex do
        local itemId = ids[index]
        local link = ScanUtils.BareLink(itemId)
        local itemType = GetItemLinkItemType(link)
        if itemType == ITEMTYPE_FURNISHING or IsPlaceable(link) then
            Record(r, itemId, link)
        else
            r.missing = r.missing + 1
            if r.missing <= MISSING_LOG_LIMIT then
                FC.Log("  built-in id %d is no furnishing here: type=%s name='%s'", itemId, tostring(itemType), tostring(GetItemLinkName(link)))
            end
        end
    end
    r.nextIndex = lastIndex + 1
    return r.nextIndex > #ids
end

---One frame of the full scan: check the next item ids.
---@return boolean finished
local function StepFull(r, frameStartMs)
    local scannedThisFrame = 0
    repeat
        local firstId = r.nextId
        local lastId = firstId + BATCH_SIZE - 1
        for itemId = firstId, lastId do
            local link = ScanUtils.BareLink(itemId)
            local itemType = GetItemLinkItemType(link)
            if itemType and itemType ~= ITEMTYPE_NONE then
                r.lastValidId = itemId
                r.valid = (r.valid or 0) + 1
                if itemType == ITEMTYPE_FURNISHING then
                    Record(r, itemId, link)
                elseif itemType == ITEMTYPE_RECIPE and IsItemLinkFurnitureRecipe(link) then
                    RecordPlan(r, itemId, link)
                elseif IsPlaceable(link) then
                    Record(r, itemId, link)
                end
            end
        end
        r.nextId = lastId + 1
        scannedThisFrame = scannedThisFrame + BATCH_SIZE
        if ScanUtils.IsPastEnd(lastId, r.lastValidId) then
            return true
        end
    until scannedThisFrame >= FULL_IDS_PER_FRAME or (GetGameTimeMilliseconds() - frameStartMs) >= FRAME_BUDGET_MS
    return false
end

local function Step()
    local r = run
    if not r then
        return
    end
    local frameStartMs = GetGameTimeMilliseconds()
    r.frames = r.frames + 1
    local finished
    if r.kind == "seed" then
        finished = StepSeed(r)
    else
        finished = StepFull(r, frameStartMs)
    end
    ControlGarbage(r)
    if finished then
        Finish(r)
        return
    end
    if r.kind == "full" and KeepPoolReserve(r) then
        return
    end
    -- A marker in saved variables while a pass is being stepped: if the UI is torn down
    -- mid-pass, the next load finds it and reports where the pass was.
    if (frameStartMs - lastMarkerMs) >= MARKER_INTERVAL_MS then
        lastMarkerMs = frameStartMs
        FC.state.savedVars.scanMarker = { kind = r.kind, position = r.kind == "seed" and r.nextIndex or r.nextId, memoryKb = Scan.MemoryKb(), frames = r.frames }
    end
    if onProgress and (frameStartMs - lastProgressMs) >= PROGRESS_INTERVAL_MS then
        lastProgressMs = frameStartMs
        onProgress(Scan.GetProgress())
    end
end

---A step that throws would throw again every frame: stop and say so instead.
local function GuardedStep()
    local ok, err = pcall(Step)
    if not ok then
        local position = run and (run.kind == "seed" and run.nextIndex or run.nextId)
        StopStepping()
        table.insert(FC.diagnostics.errors, "scan: " .. tostring(err))
        FC.Log("ERROR scan stopped at %s: %s", tostring(position), tostring(err))
        FC.Chat(string.format("scan failed: %s", tostring(err)))
    end
end

---@param r FurnishingCatalogScanProgress
local function BeginStepping(r, progressCallback, doneCallback)
    run = r
    onProgress = progressCallback
    onDone = doneCallback
    local now = GetGameTimeMilliseconds()
    activeSinceMs, lastProgressMs, lastMarkerMs = now, now, now
    -- Start from a clean heap and take the low-water mark there, before the first frame's
    -- garbage: taken a frame later it sits a frame's worth too high, and so does the limit.
    local memoryBefore = FC.MemText()
    pcall(collectgarbage, "collect")
    memory.lowKb = Scan.MemoryKb()
    FC.Log("  memory before the pass: %s; after a full collection (%d ms): %s", memoryBefore, GetGameTimeMilliseconds() - now, FC.MemText())
    r.startMemoryKb = r.startMemoryKb or memory.lowKb
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 0, GuardedStep)
end

---Start the seed pass (the built-in list filed by category), or hand new listeners to the one running.
---@param progressCallback fun(progress: table)|nil called about four times a second
---@param doneCallback fun(catalog: FurnishingCatalogCache)|nil called once with the finished catalog
function Scan.StartSeed(progressCallback, doneCallback)
    if run then
        if run.kind == "seed" then
            onProgress, onDone = progressCallback, doneCallback
            return
        end
        StopStepping()
    end
    seedIds = ScanUtils.ExpandRanges(FC.Seed and FC.Seed.ranges or {})
    FC.Log("seed pass started: %d ids of list %s (stamp %s, memory %s KB)", #seedIds, Scan.SeedVersion(), Scan.Stamp(), tostring(Scan.MemoryKb() and math.floor(Scan.MemoryKb())))
    BeginStepping({
        kind = "seed", stamp = Scan.Stamp(), nextIndex = 1, total = 0, unnamed = 0, missing = 0, frames = 0, elapsedMs = 0, maxFurnishingId = 0, tree = {},
    }, progressCallback, doneCallback)
end

---Start the full scan, or continue the one saved in this client version's saved variables.
---The caller asks Scan.FullScanRoom() first.
---@param progressCallback fun(progress: table)|nil
---@param doneCallback fun(catalog: FurnishingCatalogCache)|nil
---@param pausedCallback fun(text: string)|nil called when the scan pauses itself for memory
function Scan.StartFull(progressCallback, doneCallback, pausedCallback)
    if run then
        if run.kind == "full" then
            onProgress, onDone, onPaused = progressCallback, doneCallback, pausedCallback
            return
        end
        StopStepping()
    end
    local progress = Scan.GetSavedProgress()
    if progress and not progress.plans then
        -- Paused by a version that did not collect plans: its first part has none.
        progress = nil
    end
    if progress then
        progress.resumes = (progress.resumes or 0) + 1
        FC.Log("full scan resumed at id %d (%d found so far, resume #%d, memory %s KB)", progress.nextId, progress.total, progress.resumes, tostring(Scan.MemoryKb() and math.floor(Scan.MemoryKb())))
    else
        progress = {
            kind = "full", stamp = Scan.Stamp(), nextId = ScanUtils.FIRST_ID, lastValidId = 0, total = 0, unnamed = 0, missing = 0, frames = 0, elapsedMs = 0,
            maxFurnishingId = 0, resumes = 0, tree = {}, plans = {},
        }
        FC.state.savedVars.scanProgress = progress
        FC.Log("full scan started at id %d (stamp %s, memory %s KB)", progress.nextId, Scan.Stamp(), tostring(Scan.MemoryKb() and math.floor(Scan.MemoryKb())))
    end
    BeginStepping(progress, progressCallback, doneCallback)
    onPaused = pausedCallback
    nextPoolLogId = progress.nextId
end

---Stop stepping (the screen closed). A full scan stays in saved variables for /furn scan.
function Scan.Pause()
    if run then
        FC.Log("%s paused at %s", run.kind == "seed" and "seed pass" or "full scan", tostring(run.kind == "seed" and run.nextIndex or run.nextId))
        StopStepping()
    end
end

---What an earlier UI session left behind, read once at load: a marker means the UI was torn
---down while a pass was being stepped (a reload at the memory limit writes saved variables; a
---hard crash does not, so no marker survives one).
---@return table|nil marker
function Scan.TakeInterruptedMarker()
    local marker = FC.state.savedVars.scanMarker
    FC.state.savedVars.scanMarker = nil
    if type(marker) == "table" then
        return marker
    end
    return nil
end

FC.Scan = Scan
