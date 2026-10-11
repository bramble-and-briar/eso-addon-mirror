-- Checks a master writ and returns a Result. The tooltip asks twice per draw (once for the top status, once
-- for the details), so results are kept for a moment and reused.

local addon = CanCraftMasterWrit
local Result = addon.Result
local Util = addon.Util

local Evaluator = {}
addon.Evaluator = Evaluator

local CACHE_LIFETIME_MS = 1000
local cache = {}

local function Evaluate(itemLink)
    local writ = addon.WritParser.Parse(itemLink)
    local result = Result.New(writ)
    local checker = writ and writ.kind and addon.checks[writ.kind]
    if not checker then
        result:Unknown(Result.CATEGORY_GENERAL, GetString(SI_CCMW_UNSUPPORTED))
        return result:Finish()
    end

    -- A bug in one check must never break the game's tooltip.
    local ok, errorMessage = pcall(checker.Evaluate, writ, result)
    if not ok then
        result:Unknown(Result.CATEGORY_GENERAL, GetString(SI_CCMW_ERROR))
        Util.Debug("Error checking %s: %s", itemLink, tostring(errorMessage))
    end
    -- Requirements the player turned off in the settings neither show nor count.
    result:RemoveCategories(addon.Settings.IsCategoryChecked)
    return result:Finish()
end

-- Returns the Result for a master writ link, or nil if the link isn't a master writ.
function Evaluator.Evaluate(itemLink)
    if not addon.WritParser.IsMasterWrit(itemLink) then
        return nil
    end
    local now = GetGameTimeMilliseconds()
    local cached = cache[itemLink]
    if cached and now - cached.time < CACHE_LIFETIME_MS then
        return cached.result
    end

    local result = Evaluate(itemLink)
    -- Old entries are dropped whenever a new writ is checked, so the cache stays small.
    for link, entry in pairs(cache) do
        if now - entry.time >= CACHE_LIFETIME_MS then
            cache[link] = nil
        end
    end
    cache[itemLink] = { time = now, result = result }
    return result
end

-- Forgets every stored result, so the next tooltip is checked again from scratch.
function Evaluator.ClearCache()
    ZO_ClearTable(cache)
end
