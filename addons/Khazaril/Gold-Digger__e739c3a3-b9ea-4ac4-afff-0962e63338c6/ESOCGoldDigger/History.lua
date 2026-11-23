-- Gold Digger price history storage. Each item keeps its history as short lines of text instead of
-- many small tables, which is what keeps saved data small. It's unpacked only while being used.

local GP = ESOC_GoldDigger
local History = {}
GP.History = History

History.KEEP_DAYS = 35
History.KEEP_WEEKS = 58

local function whole(value)
    return string.format("%.0f", value)
end

local function cents(value)
    return whole(math.floor((value or 0) * 100 + 0.5))
end

local function fields(entry)
    local out = {}
    for field in string.gmatch(entry, "[^,]+") do out[#out + 1] = field end
    return out
end

local function packPrices(map)
    local parts = {}
    for key, b in pairs(map or {}) do
        if b.c and b.c > 0 then
            parts[#parts + 1] = table.concat({ tostring(key), whole(b.c), cents(b.s), cents(b.l or 0), cents(b.h or 0), b.e and "1" or "0" }, ",")
        end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, ";")
end

local function unpackPrices(text, numericKeys)
    local map = {}
    for entry in string.gmatch(text or "", "[^;]+") do
        local f = fields(entry)
        local key = numericKeys and tonumber(f[1]) or f[1]
        local low, high = tonumber(f[4]) / 100, tonumber(f[5]) / 100
        map[key] = { c = tonumber(f[2]), s = tonumber(f[3]) / 100, l = low > 0 and low or nil, h = high > 0 and high or nil,
            e = f[6] == "1" or nil }
    end
    return map
end

local function packSales(map)
    local parts = {}
    for day, b in pairs(map or {}) do
        parts[#parts + 1] = table.concat({ tostring(day), whole(b.n), whole(b.q), whole(b.g), b.e and "1" or "0" }, ",")
    end
    if #parts == 0 then return nil end
    return table.concat(parts, ";")
end

local function unpackSales(text)
    local map = {}
    for entry in string.gmatch(text or "", "[^;]+") do
        local f = fields(entry)
        map[tonumber(f[1])] = { n = tonumber(f[2]), q = tonumber(f[3]), g = tonumber(f[4]), e = f[5] == "1" or nil }
    end
    return map
end

-- A working copy with ordinary tables. An item that isn't packed yet is returned as it is.
function History.View(item)
    if item.days then return item end
    return {
        name = item.name, t = item.t, r = item.r, last = item.last,
        days = unpackPrices(item.D, true), weeks = unpackPrices(item.W, true),
        sales = unpackSales(item.S), ev = unpackPrices(item.E, false),
    }
end

-- Moves days past the limit into weekly summaries and drops what's too old to matter.
function History.Compact(view, today)
    for day, bucket in pairs(view.days) do
        if day < today - History.KEEP_DAYS then
            -- Event prices are already kept per event, so weekly history stays "normal"
            if not bucket.e then
                local week = math.floor(day / 7)
                local summary = view.weeks[week] or { c = 0, s = 0 }
                summary.c, summary.s = summary.c + bucket.c, summary.s + bucket.s
                if bucket.l and (not summary.l or bucket.l < summary.l) then summary.l = bucket.l end
                if bucket.h and (not summary.h or bucket.h > summary.h) then summary.h = bucket.h end
                view.weeks[week] = summary
            end
            view.days[day] = nil
        end
    end
    for week in pairs(view.weeks) do
        if week < math.floor(today / 7) - History.KEEP_WEEKS then view.weeks[week] = nil end
    end
    for day in pairs(view.sales) do
        if day < today - History.KEEP_DAYS then view.sales[day] = nil end
    end
end

-- Packs a working copy back into the saved item.
function History.Store(item, view)
    local seen, oldest = 0, nil
    for day, bucket in pairs(view.days) do
        seen = seen + bucket.c
        if not oldest or day < oldest then oldest = day end
    end
    for _, bucket in pairs(view.weeks) do seen = seen + bucket.c end
    for day in pairs(view.sales) do
        if not oldest or day < oldest then oldest = day end
    end
    local days, weeks, sales, ev = view.days, view.weeks, view.sales, view.ev
    item.D, item.W, item.S, item.E = packPrices(days), packPrices(weeks), packSales(sales), packPrices(ev)
    item.n, item.o = seen, oldest
    item.days, item.weeks, item.sales, item.ev = nil, nil, nil, nil
end

-- Roughly what this item costs in memory.
function History.Bytes(item)
    return 220 + #(item.name or "") + #(item.D or "") + #(item.W or "") + #(item.S or "") + #(item.E or "")
end
