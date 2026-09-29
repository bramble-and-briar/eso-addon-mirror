local SF = LibSFUtils

rChatData = {
    name = "rChatData",

    cache = {},
    cmds = {},

    evtmgr = SF.EvtMgr:New("rChatData"),
}

local MAX_HISTORY_LENGTH = 5000
local TRIMMED_HISTORY_LENGTH = 4000

local cache = rChatData.cache
local cmds = rChatData.cmds

-- ------------------------------------------------------
-- Entries functions
--

function rChatData.resetLineNumber()
	cache.lineNumber = 0
    if cache.Entries then
        cache.lineNumber = #cache.Entries
    end
    return cache.lineNumber + 1
end

-- get the number of entries saved in the chat cache
function rChatData.getChatCacheSize()
    if cache.Entries == nil then return 0 end
    if cache.lineNumber == nil or cache.lineNumber == 1 then return 0 end
    return cache.lineNumber - 1
end

-- only returns an entry for previously written entries, nil otherwise
-- returns entrytable, index
function rChatData.getCacheEntry(linenum)
    if cache.Entries == nil then return nil, 0 end
    if not linenum or linenum < 1 then return nil, 0 end
    if linenum >= cache.lineNumber then return nil, 0 end
    if not cache.Entries[linenum] then return nil, 0 end
    return cache.Entries[linenum], linenum
end

-- Returns reference to a new entry for populating
-- (and increments line count in cache)
function rChatData.getNewCacheEntry(channel)
    if cache.Entries == nil then
        cache.Entries = {}
    end
    if not cache.lineNumber or cache.lineNumber <= 1 then
        cache.lineNumber = #cache.Entries + 1
    end
    local lineno = cache.lineNumber
    cache.lineNumber = cache.lineNumber + 1
    cache.Entries[lineno] = {
        timestamp = GetTimeStamp(),
        channel = channel,
        rawLine = "",
        displayed = "",
  }
    cache.Entries[lineno].rawT = {}
    cache.Entries[lineno].displayT = {}

    return cache.Entries[lineno], lineno
end

-- iterator function to iterate through the chat cache
function rChatData.iterCache()
    return ipairs(cache.Entries)
end

-- empty and reset the cache
function rChatData.clearCache()
    cache.Entries = {}
    cache.lineNumber = 1
end

-- set the specified index with a new entry table
-- (populated correctly). Returns the index that
-- the entry was added into (since index is an
-- optional parameter that defaults to the end of
-- the cache if not specified).
-- If an entry for index already exists it will be overwritten.
-- Note: Primarily used for unit tests
function rChatData.SetLine(index, entry)
    if type(index) ~= "number" then
        entry = index
        index = nil
    end
    if not index then
        if cache.lineNumber == nil then rChatData.clearCache() end
        index = cache.lineNumber
        cache.lineNumber = cache.lineNumber + 1
    end
    cache.Entries[index] = entry
    return index
end


-- filter out the chat entries from the specified channels
-- in the excludeChannels table (key = channel id, value=anything)
function rChatData.filterChannels(excludeChannels)
    cache.Entries = SF.safeTable(cache.Entries)
    local tbl = cache.Entries
    if not excludeChannels or type(excludeChannels) ~= "table" then return tbl, cache.lineNumber end
    if not next(excludeChannels) then return tbl, cache.lineNumber end
    if cache.lineNumber < 2 then return cache.Entries, cache.lineNumber end

    local tmptbl = {}
    for _,v in ipairs(tbl) do
        if not excludeChannels[v.channel] then
            table.insert(tmptbl, v)  -- still young enough
        end
    end
    cache.Entries = tmptbl
    cache.lineNumber = #tmptbl+1

    return cache.Entries, cache.lineNumber
end

-- filter out the chat entries that are over a certain age (in seconds)
-- keep the entries that do not have a timestamp
function rChatData.filterAged(maxage)
    local tbl = cache.Entries
    if not tbl or type(tbl) ~= "table" then return tbl,0 end
    if cache.lineNumber < 2 then return cache.Entries,cache.lineNumber end
    if not maxage then return tbl,cache.lineNumber end

    local currentTime= GetTimeStamp()
    local minCreate = currentTime - maxage - 1
    local tmptbl = {}
    for _,v in ipairs(tbl) do
        if type(v.timestamp) ~= "number" or v.timestamp > minCreate then
            table.insert(tmptbl, v)  -- still young enough
        end
    end
    cache.Entries = tmptbl
    cache.lineNumber = #tmptbl+1

    return cache.Entries, cache.lineNumber
end

-- filter overflow entries from a table
-- maxlen is the maximum number of records allowed,
-- trunclen is the maximum remaining records after
--   we've finished throwing some away
-- trunclen is always less than maxlen!
function rChatData.filterSize(maxlen, trunclen)
    local tbl = cache.Entries
    if not tbl then return nil,0 end
    if not next(tbl) then return cache.Entries,cache.lineNumber end
    if #tbl < maxlen then return tbl, cache.lineNumber end
    if maxlen <= trunclen then trunclen = zo_floor(maxlen * .8) end

    local tmptbl = {}
    local start = #tbl - trunclen + 1
    if start < 1 then start = 1 end
    for i = start, #tbl do
        table.insert(tmptbl, tbl[i])
    end
    cache.Entries = tmptbl
    cache.lineNumber = #tmptbl+1

    return cache.Entries, cache.lineNumber
end

-- initialize cache if none was saved
function rChatData.initCache(maxage)
    if not rChatData.cache then
        rChatData.cache = { Entries = {}, lineNumber = 1, }
    end
    local cache = rChatData.cache
    if not cache.Entries then
        cache.Entries = {}
        cache.lineNumber = 1
        return      -- don't need to prune
    end
    if not cache.lineNumber or type(cache.lineNumber) ~= "number" then
        cache.lineNumber = #cache.Entries + 1
    end

    -- prune if necessary
    rChatData.filterSize(MAX_HISTORY_LENGTH, TRIMMED_HISTORY_LENGTH)
    rChatData.filterAged(maxage)
end

-- Load data from saved variables
local function OnDataLoaded(_, addonName)

    --Protect
    if addonName ~= "rChatData" then return end

    local cacheDefault = {
        Entries = {},
        lineNumber = 1,
    }

    -- Saved variables
    rChatData.cache = ZO_SavedVars:NewAccountWide("RCHAT_CACHE", 1, GetWorldName(), cacheDefault)
    cache = rChatData.cache

    rChatData.cmds = ZO_SavedVars:NewAccountWide("RCHAT_CMDS", 1, GetWorldName(), {})
    cmds = rChatData.cmds
end

rChatData.evtmgr:registerEvt(EVENT_ADD_ON_LOADED, OnDataLoaded)
