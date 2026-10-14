
local AutoCat = AutoCategory

-- [bagId][categoryName] = generation
local seen = {}

-- [bagId] = generation
local generation = {}

-- Last expiry setting observed during this session.
local lastCollapseExpiryDuration

local DEFAULT_COLLAPSE_EXPIRY = 7 * 24 * 60 * 60

--[[ Ensure the collapse-related SavedVars tables exist. ]]
local function ensureCollapseSavedVars()
    local saved = AutoCat.saved

    saved.collapses = saved.collapses or {}
    saved.collapseExpiry = saved.collapseExpiry or {}
end

--[[ Return the configured expiry duration in seconds, or "never". ]]
local function getCollapseExpiryDuration()
    local duration =
        AutoCat.saved.general["CATEGORY_COLLAPSE_EXPIRY_SECONDS"]

    if duration == "never" then
        return "never"
    end

    if type(duration) ~= "number" or duration < 0 then
        return DEFAULT_COLLAPSE_EXPIRY
    end

    return duration
end

--[[ Get the runtime collapse-state table for a bag.

    Entries exist only for categories currently present in the bag.
    true means collapsed; false means expanded.
--]]
local function getCategoryState(bagId)
    local state = AutoCat.categoryState[bagId]

    if not state then
        state = {}
        AutoCat.categoryState[bagId] = state
    end

    return state
end

--[[ Get the generation-tracking table for a bag. ]]
local function getSeenState(bagId)
    local state = seen[bagId]

    if not state then
        state = {}
        seen[bagId] = state
    end

    return state
end

--[[ Remove a category's expiry timestamp and its empty bag table. ]]
local function clearCollapseExpiry(bagId, categoryName)
    local allExpiry = AutoCat.saved.collapseExpiry
    local expiry = allExpiry[bagId]

    if not expiry then
        return
    end

    expiry[categoryName] = nil

    if next(expiry) == nil then
        allExpiry[bagId] = nil
    end
end

--[[ Start an expiry countdown for an absent collapsed category.

    Existing countdowns are preserved. "never" disables expiry.
--]]
local function startCollapseExpiry(bagId, categoryName, now)
    local duration = getCollapseExpiryDuration()

    if duration == "never" then
        clearCollapseExpiry(bagId, categoryName)
        return
    end

    local allExpiry = AutoCat.saved.collapseExpiry
    local expiry = allExpiry[bagId]

    if not expiry then
        expiry = {}
        allExpiry[bagId] = expiry
    end

    if expiry[categoryName] == nil then
        expiry[categoryName] = now + duration
    end
end

--[[ Refresh countdowns when the configured duration changes.

    Only absent collapsed categories are affected. A duration of
    "never" removes expiry timestamps without deleting preferences.
--]]
local function refreshCollapseExpiry(duration)
    local now = GetTimeStamp()
    local allExpiry = AutoCat.saved.collapseExpiry

    for bagId, collapses in pairs(AutoCat.saved.collapses) do
        local state = AutoCat.categoryState[bagId]
        local expiry = allExpiry[bagId]

        for categoryName, collapsed in pairs(collapses) do
            local isPresent =
                state ~= nil and state[categoryName] ~= nil

            if collapsed == true and not isPresent then
                if duration == "never" then
                    if expiry then
                        expiry[categoryName] = nil
                    end
                else
                    if not expiry then
                        expiry = {}
                        allExpiry[bagId] = expiry
                    end

                    expiry[categoryName] = now + duration
                end
            end
        end

        if expiry and next(expiry) == nil then
            allExpiry[bagId] = nil
        end
    end
end

--[[ Detect a change to the configured expiry duration.

    The first observation establishes a baseline rather than
    restarting existing countdowns, preserving expiry across reloads.
--]]
local function checkCollapseExpiryDuration()
    local duration = getCollapseExpiryDuration()

    if lastCollapseExpiryDuration == nil then
        lastCollapseExpiryDuration = duration
        return
    end

    if duration ~= lastCollapseExpiryDuration then
        refreshCollapseExpiry(duration)
        lastCollapseExpiryDuration = duration
    end
end

--[[ Load and initialize category collapse state.

    If collapse persistence is disabled, clear saved collapse
    preferences and runtime states.
--]]
function AutoCat.LoadCollapse()
    ensureCollapseSavedVars()

    lastCollapseExpiryDuration = getCollapseExpiryDuration()

    if not AutoCat.saved.general["SAVE_CATEGORY_COLLAPSE_STATUS"] then
        AutoCat.ResetCollapse(AutoCat.saved.collapses)
    end
end

--[[ Remove expanded categories from saved collapse state. ]]
function AutoCat.PruneCollapse(collapses)
    if not collapses then
        return
    end

    for _, bagcol in pairs(collapses) do
        if bagcol then
            for categoryName in pairs(bagcol) do
                if bagcol[categoryName] == false then
                    bagcol[categoryName] = nil
                end
            end
        end
    end
end

--[[ Reset all saved and runtime category collapse states. ]]
function AutoCat.ResetCollapse(collapses)
    if collapses then
        for _, bagcol in pairs(collapses) do
            if bagcol then
                for categoryName in pairs(bagcol) do
                    bagcol[categoryName] = nil
                end
            end
        end
    end

    ensureCollapseSavedVars()

    for bagId in pairs(AutoCat.saved.collapseExpiry) do
        AutoCat.saved.collapseExpiry[bagId] = nil
    end

    for _, state in pairs(AutoCat.categoryState) do
        for categoryName in pairs(state) do
            state[categoryName] = false
        end
    end
end

--[[ Determine whether a category is collapsed.

    Missing bags and categories default to expanded.
--]]
function AutoCat.IsCategoryCollapsed(bagTypeId, categoryName)
    if bagTypeId == nil or categoryName == nil then
        return false
    end

    local state = AutoCat.categoryState
    local bagState = state and state[bagTypeId]

    return bagState ~= nil
        and bagState[categoryName] == true
        or false
end

--[[ Set the collapse state of an existing category.

    Missing categories are not created by this function.
--]]
function AutoCat.SetCategoryCollapsed(bagTypeId, categoryName, collapsed)
    if bagTypeId == nil or categoryName == nil then
        return
    end

    ensureCollapseSavedVars()

    local state = AutoCat.categoryState[bagTypeId]

    if not state or state[categoryName] == nil then
        return
    end

    local isCollapsed = collapsed == true
    local collapses = AutoCat.saved.collapses[bagTypeId]

    state[categoryName] = isCollapsed

    if isCollapsed then
        if not collapses then
            collapses = {}
            AutoCat.saved.collapses[bagTypeId] = collapses
        end

        collapses[categoryName] = true
        clearCollapseExpiry(bagTypeId, categoryName)
    else
        if collapses then
            collapses[categoryName] = nil

            if next(collapses) == nil then
                AutoCat.saved.collapses[bagTypeId] = nil
            end
        end

        clearCollapseExpiry(bagTypeId, categoryName)
    end
end

--[[ Reconcile runtime state with the categories currently present.

    Existing categories retain their runtime state.
    New categories restore their saved collapse preference.
    Absent categories are removed from runtime state, but collapsed
    preferences remain saved until their expiry time.
--]]
function AutoCat.UpdateCategoryState(bagId, categories)
    if bagId == nil or not categories then
        return
    end

    ensureCollapseSavedVars()
    checkCollapseExpiryDuration()

    local state = getCategoryState(bagId)
    local bagSeen = getSeenState(bagId)
    local collapses = AutoCat.saved.collapses[bagId]
    local now = GetTimeStamp()

    local gen = (generation[bagId] or 0) + 1
    generation[bagId] = gen

    -- Mark present categories and initialize new categories.
    for categoryName in pairs(categories) do
        bagSeen[categoryName] = gen

        if state[categoryName] == nil then
            state[categoryName] =
                collapses ~= nil
                and collapses[categoryName] == true
                or false
        end

        -- A returning category no longer needs an expiry.
        clearCollapseExpiry(bagId, categoryName)
    end

    -- Remove categories no longer present from runtime state.
    for categoryName in pairs(state) do
        if bagSeen[categoryName] ~= gen then
            state[categoryName] = nil

            if collapses and collapses[categoryName] == true then
                startCollapseExpiry(bagId, categoryName, now)
            end

            bagSeen[categoryName] = nil
        end
    end

    -- Expire saved preferences for absent categories.
    local duration = getCollapseExpiryDuration()

    if duration ~= "never" then
        local expiry = AutoCat.saved.collapseExpiry[bagId]

        if expiry then
            for categoryName, expiresAt in pairs(expiry) do
                if expiresAt <= now then
                    expiry[categoryName] = nil

                    if collapses then
                        collapses[categoryName] = nil
                    end
                end
            end

            if next(expiry) == nil then
                AutoCat.saved.collapseExpiry[bagId] = nil
            end
        end
    end

    -- Remove empty saved collapse tables.
    collapses = AutoCat.saved.collapses[bagId]

    if collapses and next(collapses) == nil then
        AutoCat.saved.collapses[bagId] = nil
    end
end

--[[ Collapse every category currently present in a bag. ]]
function AutoCat:CollapseAllCategories(bagId)
    if bagId == nil then
        return
    end

    ensureCollapseSavedVars()

    local state = AutoCat.categoryState[bagId]
    if not state then
        return
    end

    local collapses = AutoCat.saved.collapses[bagId]

    if not collapses then
        collapses = {}
        AutoCat.saved.collapses[bagId] = collapses
    end

    for categoryName in pairs(state) do
        state[categoryName] = true
        collapses[categoryName] = true
        clearCollapseExpiry(bagId, categoryName)
    end
end

--[[ Expand every category currently present in a bag. ]]
function AutoCat:ExpandAllCategories(bagId)
    if bagId == nil then
        return
    end

    ensureCollapseSavedVars()

    local state = AutoCat.categoryState[bagId]
    if not state then
        return
    end

    local collapses = AutoCat.saved.collapses[bagId]

    for categoryName in pairs(state) do
        state[categoryName] = false

        if collapses then
            collapses[categoryName] = nil
        end

        clearCollapseExpiry(bagId, categoryName)
    end

    if collapses and next(collapses) == nil then
        AutoCat.saved.collapses[bagId] = nil
    end
end

--[[ Call when the expiry setting changes in the options menu.

    Starts a fresh countdown for all absent collapsed categories.
--]]
function AutoCat.OnCollapseExpiryDurationChanged()
    ensureCollapseSavedVars()

    local duration = getCollapseExpiryDuration()

    if duration ~= lastCollapseExpiryDuration then
        refreshCollapseExpiry(duration)
        lastCollapseExpiryDuration = duration
    end
end
