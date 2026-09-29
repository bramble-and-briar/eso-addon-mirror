
BGMeter = BGMeter or {}
local BGMeter = BGMeter

local History = {}

local function sv()
    return BGMeter.zenimax.savedvars.get()
end

local HEAVY_KEEP = 10
local PIN_CAP = 10
History.HEAVY_KEEP = HEAVY_KEEP
History.PIN_CAP = PIN_CAP

local function strip_detail(m)
    m.timeline = nil
    m.killfeed = nil
    m.objectives = nil
    m.relics = nil
end

local function unpinned_count(matches)
    local n = 0
    for i = 1, #matches do
        if not matches[i].pinned then n = n + 1 end
    end
    return n
end

History._rev = 0

function History.rev() return History._rev end

function History.push(match)
    History._rev = History._rev + 1
    local data = sv()
    if not data then return end
    data.matches = data.matches or {}
    table.insert(data.matches, 1, match)
    local cap = (data.prefs and data.prefs.max_history) or 50
    local i = #data.matches
    while i >= 1 and unpinned_count(data.matches) > cap do
        if not data.matches[i].pinned then table.remove(data.matches, i) end
        i = i - 1
    end
    local heavy = 0
    for k = 1, #data.matches do
        local m = data.matches[k]
        if not m.pinned then
            heavy = heavy + 1
            if heavy > HEAVY_KEEP then strip_detail(m) end
        end
    end
    BGMeter.Log.debug("history push -> %d stored", #data.matches)
end

function History.count()
    local data = sv()
    return (data and data.matches) and #data.matches or 0
end

function History.get(index)
    local data = sv()
    if not data or not data.matches then return nil end
    return data.matches[index]
end

function History.most_recent()
    return History.get(1)
end

function History.delete(index)
    History._rev = History._rev + 1
    local data = sv()
    if not data or not data.matches or not data.matches[index] then return false end
    local gone = data.matches[index]
    table.remove(data.matches, index)
    if BGMeter.Match.geo_cache_forget then BGMeter.Match.geo_cache_forget(gone) end
    return true
end

function History.clear()
    History._rev = History._rev + 1
    local data = sv()
    if data then data.matches = {} end
    if BGMeter.Match.geo_cache_clear then BGMeter.Match.geo_cache_clear() end
end

function History.has_detail(m)
    return m ~= nil and m.timeline ~= nil
end

function History.is_pinned(index)
    local m = History.get(index)
    return m ~= nil and m.pinned == true
end

function History.pinned_count()
    local data = sv()
    if not data or not data.matches then return 0 end
    return #data.matches - unpinned_count(data.matches)
end

function History.pin(index)
    local m = History.get(index)
    if not m then return false, "missing" end
    if m.pinned then return true end
    if History.pinned_count() >= PIN_CAP then return false, "full" end
    m.pinned = true
    return true
end

function History.unpin(index)
    local m = History.get(index)
    if not m or not m.pinned then return false end
    m.pinned = nil
    return true
end

function History.pinned()
    local out = {}
    local data = sv()
    if not data or not data.matches then return out end
    for i, m in ipairs(data.matches) do
        if m.pinned then out[#out + 1] = { index = i, m = m } end
    end
    return out
end

function History.index_of(m)
    local data = sv()
    if not data or not data.matches then return nil end
    for i, x in ipairs(data.matches) do
        if x == m then return i end
    end
    return nil
end

BGMeter.History = History
