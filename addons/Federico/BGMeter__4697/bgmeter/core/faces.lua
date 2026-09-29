BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Faces = {}

local CAP = 1500
local MIN_FAMILIAR = 2
Faces.CAP = CAP

local function sv()
    return BGMeter.zenimax.savedvars.get()
end

local function ledger()
    local data = sv()
    if not data then return nil end
    data.faces = data.faces or {}
    return data.faces
end

local function clean(s)
    if type(s) ~= "string" or s == "" then return nil end
    return (s:gsub("%^.*$", ""))
end

local function key_of(row)
    return clean(row.displayName)
end

local function prune(L)
    local n = 0
    for _ in pairs(L) do n = n + 1 end
    if n <= CAP then return 0 end
    local keys = {}
    for k in pairs(L) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return (L[a].last or 0) < (L[b].last or 0) end)
    local drop = n - CAP
    for i = 1, drop do L[keys[i]] = nil end
    return drop
end

function Faces.count_kills(L, killfeed)
    local n = 0
    for _, k in ipairs(killfeed or {}) do
        if k.kind == "kill" and k.dn and L[k.dn] then
            L[k.dn].k = (L[k.dn].k or 0) + 1
            n = n + 1
        elseif k.kind == "death" and k.kn and L[k.kn] then
            L[k.kn].dk = (L[k.kn].dk or 0) + 1
            n = n + 1
        end
    end
    return n
end

Faces._rev = 0

function Faces.rev() return Faces._rev end

function Faces.record(match)
    Faces._rev = Faces._rev + 1
    local L = ledger()
    if not L or not match or not match.battle then return 0 end
    local mine = match.localTeam
    local ts = match.capturedAt or 0
    local seen, n = {}, 0
    for _, r in ipairs(match.battle) do
        local k = (not r.isLocal) and key_of(r) or nil
        if k and not seen[k] then
            seen[k] = true
            local e = L[k]
            if not e then
                e = { w = 0, a = 0, last = 0 }
                L[k] = e
            end
            if mine ~= nil and r.team == mine then e.w = e.w + 1 else e.a = e.a + 1 end
            e.last = ts
            e.chr = clean(r.charName)
            n = n + 1
        end
    end
    Faces.count_kills(L, match.killfeed)
    local dropped = prune(L)
    BGMeter.Log.debug("faces: %d players recorded, %d pruned", n, dropped)
    return n
end

function Faces.get(row)
    local L = ledger()
    if not L then return nil end
    local k = key_of(row)
    return k and L[k] or nil
end

function Faces.total(e)
    return (e.w or 0) + (e.a or 0)
end

function Faces.is_familiar(e)
    return e ~= nil and Faces.total(e) >= MIN_FAMILIAR
end

function Faces.lean(e)
    local w, a = e.w or 0, e.a or 0
    if w > a then return "with" end
    if a > w then return "against" end
    return "mixed"
end

function Faces.count()
    local L = ledger()
    if not L then return 0 end
    local n = 0
    for _ in pairs(L) do n = n + 1 end
    return n
end

function Faces.list(filter, limit)
    local L = ledger()
    local out = {}
    if not L then return out end
    local needle = filter and filter ~= "" and filter:lower() or nil
    for k, e in pairs(L) do
        if not needle or k:lower():find(needle, 1, true) or (e.chr and e.chr:lower():find(needle, 1, true)) then
            out[#out + 1] = { name = k, chr = e.chr, w = e.w or 0, a = e.a or 0, last = e.last or 0, k = e.k or 0, dk = e.dk or 0 }
        end
    end
    table.sort(out, function(x, y)
        local tx, ty = x.w + x.a, y.w + y.a
        if tx ~= ty then return tx > ty end
        if x.last ~= y.last then return x.last > y.last end
        return x.name < y.name
    end)
    if limit and #out > limit then
        for i = #out, limit + 1, -1 do out[i] = nil end
    end
    return out
end

function Faces.forget()
    Faces._rev = Faces._rev + 1
    local data = sv()
    if not data then return 0 end
    local n = Faces.count()
    data.faces = {}
    return n
end

local function ago(ts) return BGMeter.Format.ago(ts) end

local function good(v) return "|c" .. BGMeter.Format.hexc(BGMeter.Constants.COLOR.face_with) .. tostring(v) .. "|r" end
local function bad(v) return "|c" .. BGMeter.Format.hexc(BGMeter.Constants.COLOR.face_vs) .. tostring(v) .. "|r" end

function Faces.describe(e)
    local t = Faces.total(e)
    local line = string.format("Familiar face: %d %s, %s with you, %s against", t, (t == 1) and "match" or "matches", good(e.w or 0), bad(e.a or 0))
    local when = ago(e.last)
    if when then line = line .. "\nLast met " .. when end
    if e.chr and e.chr ~= "" then line = line .. "\nLast seen as " .. e.chr end
    local k, dk = e.k or 0, e.dk or 0
    if k > 0 or dk > 0 then
        line = line .. string.format("\nYou killed them %s %s, they killed you %s", good(k), (k == 1) and "time" or "times", bad(dk))
    end
    return line
end

function Faces.brief(e)
    local parts = { string.format("%s with  ·  %s against", good(e.w or 0), bad(e.a or 0)) }
    local when = ago(e.last)
    if when then parts[#parts + 1] = when end
    return table.concat(parts, "  ·  ")
end

function Faces.backfill_kills()
    Faces._rev = Faces._rev + 1
    local data = sv()
    if not data or data.faces_kills_seeded then return 0 end
    data.faces_kills_seeded = true
    local L = ledger()
    if not L then return 0 end
    local matches = data.matches or {}
    local n = 0
    for i = #matches, 1, -1 do
        n = n + Faces.count_kills(L, matches[i].killfeed)
    end
    BGMeter.Log.debug("faces: kill exchanges seeded from stored kill feeds, %d entries", n)
    return n
end

function Faces.backfill()
    Faces._rev = Faces._rev + 1
    local data = sv()
    if not data or data.faces_seeded then return 0 end
    data.faces_seeded = true
    local matches = data.matches or {}
    local n = 0
    for i = #matches, 1, -1 do
        n = n + Faces.record(matches[i])
    end
    BGMeter.Log.debug("faces: seeded from %d stored matches, %d rows", #matches, n)
    return n
end

BGMeter.Faces = Faces
