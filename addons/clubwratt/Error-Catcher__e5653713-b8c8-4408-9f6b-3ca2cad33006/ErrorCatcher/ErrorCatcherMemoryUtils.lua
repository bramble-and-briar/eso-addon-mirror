-- ErrorCatcherMemoryUtils.lua: when a memory reading is worth a line, and wording it (pure)
--
-- The pool is every add-on's memory together; the game warns at 70% of its capacity and disables add-ons at
-- the capacity. Garbage makes it rise and fall by megabytes within seconds, so a line is written on a new
-- high, not on every change, and each line carries the range of the last minute.
local MemoryUtils = {}

-- A new high this far above the last one written is a line.
MemoryUtils.STEP_MB = 2
-- A whole minute this far below the last high written is a line, and growth is counted anew from there.
MemoryUtils.DROP_MB = 10
-- This many more map pin controls built is a line.
MemoryUtils.PIN_STEP = 500
-- Readings the range is taken over (one every SAMPLE_SECONDS).
MemoryUtils.RANGE_SAMPLES = 12

MemoryUtils.REASON_HIGH = "new high"
MemoryUtils.REASON_DROP = "dropped"
MemoryUtils.REASON_PINS = "map pins"

---The figures of the game's low memory notice ("Low Add-On memory: 70 MB/100 MB."); nil for other text.
---@param text any
---@return number|nil used, number|nil capacity
function MemoryUtils.ParseNotice(text)
    if type(text) ~= "string" or string.find(text, "stack traceback", 1, true) then
        return nil, nil
    end
    local used, capacity = string.match(text, "(%d+) MB/(%d+) MB")
    if not used then
        return nil, nil
    end
    return tonumber(used), tonumber(capacity)
end

---Add a reading to the ring of recent ones and return their range.
---@param ring ErrorCatcherMemoryRing
---@param used number
---@return number low, number high, boolean full The ring holds a whole minute
function MemoryUtils.Range(ring, used)
    ring.values[ring.next] = used
    ring.next = ring.next % MemoryUtils.RANGE_SAMPLES + 1
    local low, high = used, used
    for index = 1, #ring.values do
        local value = ring.values[index]
        if value < low then low = value end
        if value > high then high = value end
    end
    return low, high, #ring.values >= MemoryUtils.RANGE_SAMPLES
end

---Why a reading is worth a line; nil when it is not.
---@param sample ErrorCatcherMemorySample
---@param mark ErrorCatcherMemoryMark What the last line written said
---@param rangeFull boolean
---@return string|nil reason
function MemoryUtils.Reason(sample, mark, rangeFull)
    if sample.used >= mark.high + MemoryUtils.STEP_MB then
        return MemoryUtils.REASON_HIGH
    end
    if rangeFull and sample.rangeHigh <= mark.high - MemoryUtils.DROP_MB then
        return MemoryUtils.REASON_DROP
    end
    if sample.pinsBuilt and sample.pinsBuilt >= mark.pinsBuilt + MemoryUtils.PIN_STEP then
        return MemoryUtils.REASON_PINS
    end
    return nil
end

---@param megabytes number
---@return string
local function Signed(megabytes)
    return string.format("%s%.1f", megabytes >= 0 and "+" or "", megabytes)
end

---One reading as a line.
---@param label string Why it is written
---@param sample ErrorCatcherMemorySample
---@param mark ErrorCatcherMemoryMark|nil The line before, for the change since
---@return string
function MemoryUtils.Line(label, sample, mark)
    local parts = {}
    local pool = string.format("add-on pool %.1f/%s MB", sample.used, sample.capacity and string.format("%d", sample.capacity) or "?")
    local notes = {}
    if mark and mark.used then
        notes[#notes + 1] = string.format("%s in %d s", Signed(sample.used - mark.used), math.max(0, sample.age - mark.age))
    end
    if sample.rangeLow and sample.rangeHigh and sample.rangeHigh - sample.rangeLow >= 0.05 then
        notes[#notes + 1] = string.format("last minute %.1f to %.1f", sample.rangeLow, sample.rangeHigh)
    end
    if #notes > 0 then
        pool = pool .. " (" .. table.concat(notes, "; ") .. ")"
    end
    parts[#parts + 1] = pool
    if sample.heap then
        parts[#parts + 1] = string.format("Lua heap %.1f MB", sample.heap)
    end
    if sample.pinsBuilt then
        parts[#parts + 1] = string.format("map pins %d in use / %d built", sample.pinsActive or 0, sample.pinsBuilt)
    end
    return string.format("memory (%s): %s | %d s after UI load, zone=%s scene=%s",
        label, table.concat(parts, ", "), sample.age, sample.zone or "?", sample.scene or "?")
end

---What each add-on loaded after this one added, largest first, as names for a listing.
---@param entries ErrorCatcherLoadCost[] In load order
---@param minMB number A smaller change is counted, not named
---@return string[] names "AddOn +1.2"
---@return number restCount, number restMB
function MemoryUtils.ByAddon(entries, minMB)
    local sorted = {}
    local restCount, restMB = 0, 0
    for _, entry in ipairs(entries) do
        if math.abs(entry.delta) >= minMB then
            sorted[#sorted + 1] = entry
        else
            restCount = restCount + 1
            restMB = restMB + entry.delta
        end
    end
    table.sort(sorted, function(left, right)
        if left.delta ~= right.delta then
            return left.delta > right.delta
        end
        return left.name < right.name
    end)
    local names = {}
    for index, entry in ipairs(sorted) do
        names[index] = string.format("%s %s", entry.name, Signed(entry.delta))
    end
    return names, restCount, restMB
end

---The add-ons whose saved variables take the most room on disk, largest first, as names for a listing.
---@param entries ErrorCatcherDiskUse[]
---@param maxNames number
---@param minMB number
---@return string[] names "AddOn 1.2"
function MemoryUtils.Largest(entries, maxNames, minMB)
    local sorted = {}
    for _, entry in ipairs(entries) do
        if entry.megabytes >= minMB then
            sorted[#sorted + 1] = entry
        end
    end
    table.sort(sorted, function(left, right)
        if left.megabytes ~= right.megabytes then
            return left.megabytes > right.megabytes
        end
        return left.name < right.name
    end)
    local names = {}
    for index = 1, math.min(#sorted, maxNames) do
        names[index] = string.format("%s %.2f", sorted[index].name, sorted[index].megabytes)
    end
    return names
end

ErrorCatcher.MemoryUtils = MemoryUtils
