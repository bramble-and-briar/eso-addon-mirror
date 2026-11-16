-- Ability search by name. The game has no name -> ID lookup, so on first use we build an index by
-- walking the ability ID range in small chunks spread over frames (no hitch), then search it in
-- memory. The index lives for the session only.

local DT = DebuffTracker
local AS = DT.AbilitySearch
local U = DT.Util

local MAX_ID = 300000
local CHUNK = 2500

AS.ids = {}
AS.names = {}       -- lowercase, parallel to ids
AS.state = "idle"   -- idle | building | ready
AS.progress = 0
local nextId = 1
local listeners = {}

function AS.OnProgress(fn) listeners[#listeners + 1] = fn end
local function Notify() for _, fn in ipairs(listeners) do fn(AS.state, AS.progress) end end

local function Step()
    local last = math.min(nextId + CHUNK - 1, MAX_ID)
    local ids, names = AS.ids, AS.names
    for id = nextId, last do
        local name = GetAbilityName(id)
        if name and name ~= "" then
            ids[#ids + 1] = id
            names[#names + 1] = U.Lower(name)
        end
    end
    nextId = last + 1
    AS.progress = nextId / MAX_ID
    if nextId > MAX_ID then
        EVENT_MANAGER:UnregisterForUpdate("DebuffTracker5_AbilityIndex")
        AS.state = "ready"
        AS.progress = 1
        -- entries matched by name can now get their icon from the index (see AS.IconForName)
        AS.iconCache = {}
        if DT.Triggers and DT.Triggers.ClearCache then DT.Triggers.ClearCache() end
        if DT.Engine and DT.Engine.RequestUpdate then DT.Engine.RequestUpdate() end
        if DT.UI and DT.UI.IsShowing and DT.UI.IsShowing() and DT.UI.Refresh then DT.UI.Refresh() end
    end
    Notify()
end

function AS.Build()
    if AS.state ~= "idle" then return end
    AS.state = "building"
    nextId = 1
    EVENT_MANAGER:RegisterForUpdate("DebuffTracker5_AbilityIndex", 0, Step)
end

-- The icon of an effect a tracker matches by NAME (Yarden: the ability search already finds the IDs of a
-- name -- use them instead of a placeholder icon). Every ability with exactly that name is looked at and
-- the icon most of them share is used (a Major buff exists under dozens of IDs, a few with their source
-- skill's icon). Starts building the index the first time it's needed (spread over frames, about 2 s);
-- until it's ready this returns nil. The result is remembered (Effects' learned icons, saved variables),
-- so the index isn't needed again for that name.
AS.iconCache = {}
function AS.IconForName(lname)
    lname = U.Lower(U.Trim(lname or ""))
    if lname == "" then return nil end
    local cached = AS.iconCache[lname]
    if cached ~= nil then return cached or nil end
    if AS.state ~= "ready" then
        if AS.state == "idle" then AS.Build() end
        return nil
    end
    local count, best, bestN = {}, nil, 0
    for i = 1, #AS.ids do
        if AS.names[i] == lname then
            local icon = GetAbilityIcon(AS.ids[i])
            if icon and icon ~= "" and icon ~= DT.Const.DEFAULT_ICON then
                local n = (count[icon] or 0) + 1
                count[icon] = n
                if n > bestN then best, bestN = icon, n end
            end
        end
    end
    AS.iconCache[lname] = best or false
    if best and DT.Effects.LearnIcon then DT.Effects.LearnIcon(lname, best) end
    return best
end

-- Every ability ID with exactly this name (Srendarr's "add by name" does the same scan: FindIDByName walks the ID
-- range comparing names). nil while the index is still being built (started here if needed).
function AS.IdsForName(name)
    local lname = U.Lower(U.Trim(name or ""))
    if lname == "" then return {} end
    if AS.state ~= "ready" then
        if AS.state == "idle" then AS.Build() end
        return nil
    end
    local out = {}
    for i = 1, #AS.ids do
        if AS.names[i] == lname then out[#out + 1] = AS.ids[i] end
    end
    return out
end

-- Returns up to `limit` results { id, name, icon, duration }.
-- Numeric queries match the ID directly (works before the index is built).
function AS.Search(query, limit)
    limit = limit or 60
    query = U.Trim(query or "")
    local results = {}
    if query == "" then return results end
    local n = tonumber(query)
    if n then
        local name = GetAbilityName(n)
        if name and name ~= "" then
            results[1] = { id = n, name = U.CleanName(name), icon = GetAbilityIcon(n), duration = (GetAbilityDuration(n) or 0) / 1000 }
        end
        return results
    end
    local needle = U.Lower(query)
    local exact, partial = {}, {}
    for i = 1, #AS.ids do
        local nm = AS.names[i]
        if nm == needle then exact[#exact + 1] = i
        elseif nm:find(needle, 1, true) then partial[#partial + 1] = i end
        if #exact + #partial > 4000 then break end
    end
    local function Add(i)
        local id = AS.ids[i]
        results[#results + 1] = { id = id, name = U.CleanName(GetAbilityName(id)), icon = GetAbilityIcon(id),
                                  duration = (GetAbilityDuration(id) or 0) / 1000 }
    end
    for _, i in ipairs(exact) do if #results >= limit then break end; Add(i) end
    table.sort(partial, function(a, b)
        if AS.names[a] ~= AS.names[b] then return AS.names[a] < AS.names[b] end
        return AS.ids[a] < AS.ids[b]
    end)
    for _, i in ipairs(partial) do if #results >= limit then break end; Add(i) end
    return results
end
