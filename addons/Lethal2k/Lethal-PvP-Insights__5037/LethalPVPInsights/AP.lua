-- Lethal PVP Insights - Alliance Points history
-- A chronological feed of what gave (or cost) you Alliance Points: "Capturing Alessia Keep 8,000",
-- "Capturing Chalman Mine 1,900"... AP from player kills is summed into one "AP from player kills" line.
-- Today and yesterday keep every line; older days are kept only as daily totals per kind ("Capturing
-- Keeps", "Capturing Resources", "Player Kills"...), which the longer periods show.
local PDI = PVPDataInsight
local AP = {}
PDI.AP = AP

local EM = EVENT_MANAGER
local NS = PDI.name .. "_AP"
AP.EVENTS_MAX = 3000          -- line by line: today and yesterday only (kills are summed)
AP.KILLS = "Player Kills"
AP.REPAIRS = "Repairs"
-- sources added up into one line per period (shown at the bottom, in this order, before the kills lines)
AP.AGG = { ["Repairs"] = 1, ["Resurrecting players"] = 2, ["Spent at vendors"] = 3, ["Spent (buyback)"] = 4 }

-- the game's reason codes -> readable names (built from the CURRENCY_CHANGE_REASON_* constants)
local REASON = {}
local NICE = {
    PVP_KILL_TRANSFER = "Player Kills", KILL = "Player Kills", PVP_RESURRECT = "Resurrecting players",
    KEEP_REWARD = "Keep / resource capture", OFFENSIVE_KEEP_REWARD = "Keep / resource capture (attack)",
    DEFENSIVE_KEEP_REWARD = "Keep / resource defense", KEEP_REPAIR = "Repairs",
    BATTLEGROUND = "Battlegrounds", QUESTREWARD = "Quests", QUEST = "Quests", MEDAL = "Medals",
    CAMPAIGN_REWARD = "Campaign reward", ARTIFACT_CAPTURE = "Scroll capture", ARTIFACT_RETURN = "Scroll return",
    VENDOR = "Spent at vendors", BUYBACK = "Spent (buyback)", LOOT = "Loot", REWARD = "Rewards",
    SIEGE_PLACEMENT = "Siege", CONSUME_FOOD_DRINK = "Consumables",
}
local function titleCase(s)
    s = string.lower(s or ""):gsub("_", " ")
    return (s:gsub("^%l", string.upper))
end
for short, name in pairs(NICE) do
    local v = _G["CURRENCY_CHANGE_REASON_" .. short]
    if type(v) == "number" and not REASON[v] then REASON[v] = name end
end
-- reasons not in the list above get their constant's name, looked up the first time they're seen
local looked = {}
local function lookUp(r)
    if looked[r] then return end
    looked[r] = true
    for k, v in pairs(_G) do
        if v == r and type(k) == "string" and k:find("^CURRENCY_CHANGE_REASON_") then REASON[r] = titleCase(k:sub(24)); return end
    end
end
function AP.ReasonName(r)
    if r and not REASON[r] then pcall(lookUp, r) end
    return REASON[r] or ("Other (" .. tostring(r) .. ")")
end

local function sv() return PDI.sv end

-- Keep / resource / outpost / town names for the capture and defense rewards: the game's AP event has no
-- place in it, so the keep that changed hands (or stopped being under attack) just before is used
local recentKeeps = {}          -- { id, t, kind = "capture" | "defense" }
local KEEP_WINDOW = 120         -- seconds between the flag / the end of the attack and the reward
local function keepName(id)
    local n = GetKeepName and GetKeepName(id)
    return (n and n ~= "") and zo_strformat("<<1>>", n) or nil
end
local function noteKeep(id, kind)
    recentKeeps[#recentKeeps + 1] = { id = id, t = PDI.Now(), kind = kind }
    while #recentKeeps > 30 do table.remove(recentKeeps, 1) end
end
-- what kind of place a keep id is: "Keeps", "Outposts", "Resources", "Towns"...
local KEEP_KIND = {}
for const, label in pairs({ KEEPTYPE_KEEP = "Keeps", KEEPTYPE_OUTPOST = "Outposts", KEEPTYPE_RESOURCE = "Resources",
                            KEEPTYPE_TOWN = "Towns", KEEPTYPE_ARTIFACT_KEEP = "Scroll Temples",
                            KEEPTYPE_IMPERIAL_CITY_DISTRICT = "Imperial City Districts",
                            KEEPTYPE_BRIDGE = "Bridges & Milegates", KEEPTYPE_MILEGATE = "Bridges & Milegates",
                            KEEPTYPE_ARTIFACT_GATE = "Scroll Gates" }) do
    local v = _G[const]
    if type(v) == "number" then KEEP_KIND[v] = label end
end
local function keepKind(id)
    local ok, t = pcall(GetKeepType, id)
    return ok and KEEP_KIND[t] or nil
end
-- -> place name, kind of place. When several places fit (a keep and its farm both stop being under attack
-- at the end of a fight), the size of the reward decides: keeps, towns and scroll temples pay far more
-- (tens of thousands) than resources and outposts (a few thousand).
local BIG = { Keeps = true, Towns = true, ["Scroll Temples"] = true }
local BIG_REWARD = 15000
local closest
local lastPick                  -- how the last place name was found ("near" / "flag" / "none"), kept with the line
local NEAR = 0.06               -- how close (share of the Cyrodiil map) you must be to a place for its reward
local NEAR_RESOURCE = 0.03      -- a resource's reward needs you in that resource's own area
local NEAR_BIG = 0.10           -- a keep's (or town's) area is larger
local RESOURCE_MAX = 10000      -- more AP than this is a keep / town / outpost, not a farm, mine or lumbermill
-- your position on the Cyrodiil map, and the keep / resource closest to it among the candidates
local function playerPos()
    if not (GetMapPlayerPosition and GetMapName) then return nil end
    if ZO_WorldMap_IsWorldMapShowing and ZO_WorldMap_IsWorldMapShowing() then
        -- (the open world map shows what you're looking at: only use it when it is Cyrodiil itself)
    elseif SetMapToPlayerLocation then
        pcall(SetMapToPlayerLocation)
    end
    local name = PDI.CleanName(GetMapName())
    if name ~= "Cyrodiil" then return nil end
    local ok, x, y = pcall(GetMapPlayerPosition, "player")
    if ok and x and y and (x ~= 0 or y ~= 0) then return x, y end
    return nil
end
-- may this place be the one a reward of `diff` AP was for, at squared distance d from you?
local function fits(id, d, diff)
    local res = keepKind(id) == "Resources"
    if math.abs(diff or 0) >= RESOURCE_MAX then             -- big reward: never a resource
        return not res and d <= NEAR_BIG * NEAR_BIG
    end
    return d <= (res and NEAR_RESOURCE or NEAR) ^ 2          -- a resource only when you're in its area
end
closest = function(cands, diff)
    if not GetKeepPinInfo then return nil, "nopos" end
    local px, py = playerPos()
    if not px then return nil, "nopos" end
    local best, bestD
    for _, i in ipairs(cands) do
        local id = recentKeeps[i].id
        local ok, _, kx, ky = pcall(GetKeepPinInfo, id, BGQUERY_LOCAL or 1)
        if ok and kx and ky and (kx ~= 0 or ky ~= 0) then
            local d = (kx - px) ^ 2 + (ky - py) ^ 2
            if fits(id, d, diff) and (not bestD or d < bestD) then best, bestD = i, d end
        end
    end
    return best, best and nil or "far"
end

-- the place nearest to you (within NEAR) among the keeps / resources / outposts / towns of the campaign map
local function nearestKeep(diff)
    if not (GetNumKeeps and GetKeepKeysByIndex and GetKeepPinInfo) then return nil end
    local px, py = playerPos()
    if not px then return nil end
    local best, bestD
    for i = 1, GetNumKeeps() do
        local ok, id = pcall(GetKeepKeysByIndex, i)
        if ok and id then
            local ok2, _, kx, ky = pcall(GetKeepPinInfo, id, BGQUERY_LOCAL or 1)
            if ok2 and kx and ky and (kx ~= 0 or ky ~= 0) then
                local d = (kx - px) ^ 2 + (ky - py) ^ 2
                if fits(id, d, diff) and (not bestD or d < bestD) then best, bestD = id, d end
            end
        end
    end
    return best
end

-- -> name and kind of the place a capture / defense reward was for, or nil when it can't be told. The game
-- reports keeps changing hands and attacks ending all over Cyrodiil, so only a place near you counts: the
-- nearest one to you on the map that fits the reward: a farm, mine or lumbermill only when you're in its own
-- area, and never for a big reward (10,000 AP or more).
local function placeFor(kind, diff)
    local now = PDI.Now()
    local cands, seen = {}, {}
    for i = #recentKeeps, 1, -1 do
        local k = recentKeeps[i]
        if now - k.t > KEEP_WINDOW then break end
        if k.kind == kind and not seen[k.id] then seen[k.id] = true; cands[#cands + 1] = i end
    end
    -- 1. the place you're standing at: the nearest fitting one on the map (you must be at a resource for its
    --    reward, so this is the most reliable - the game may tell about the flag only after the reward)
    local id = nearestKeep(diff)
    if id then
        for i = #recentKeeps, 1, -1 do if recentKeeps[i].id == id and recentKeeps[i].kind == kind then table.remove(recentKeeps, i) end end
        lastPick = "near"
        return keepName(id), keepKind(id)
    end
    -- 2. no position (another map): in Imperial City, the district that just changed
    if IsInImperialCity and IsInImperialCity() then
        for _, i in ipairs(cands) do
            if keepKind(recentKeeps[i].id) == "Imperial City Districts" then
                id = recentKeeps[i].id
                table.remove(recentKeeps, i)
                lastPick = "flag"
                return keepName(id), keepKind(id)
            end
        end
    end
    lastPick = "none"
    return nil, nil
end
local CAPTURE = { ["Keep / resource capture"] = true, ["Keep / resource capture (attack)"] = true }
local DEFENSE = { ["Keep / resource defense"] = true }
-- one event -> the line's text ("Capturing Alessia Keep") and its kind for the daily totals ("Capturing Keeps")
local function label(name, diff)
    local low = string.lower(name or "")
    if not CAPTURE[name] and not DEFENSE[name] and (low:find("keep") or low:find("objective") or low:find("resource")) then
        if low:find("defen") then DEFENSE[name] = true else CAPTURE[name] = true end
    end
    for verb, list in pairs({ Capturing = CAPTURE, Defending = DEFENSE }) do
        if list[name] then
            local place, kind = placeFor(verb == "Capturing" and "capture" or "defense", diff)
            return place and (verb .. " " .. place) or (verb .. " (keep / resource)"),
                   verb .. " " .. (kind or "Keeps & Resources")
        end
    end
    return name, name
end
-- totals kept by older versions under the game's reason names
AP.OLD_KINDS = { ["Keep / resource capture"] = "Capturing Keeps & Resources",
                 ["Keep / resource capture (attack)"] = "Capturing Keeps & Resources",
                 ["Keep / resource defense"] = "Defending Keeps & Resources" }

-- where a kill's AP came from (the kills lines are kept apart per place)
AP.KILL_PLACES = { "Cyrodiil", "Imperial City", "Battlegrounds", "Duels" }
local function killPlace()
    if GetDuelInfo and DUEL_STATE_DUELING and GetDuelInfo() == DUEL_STATE_DUELING then return "Duels" end
    if IsActiveWorldBattleground and IsActiveWorldBattleground() then return "Battlegrounds" end
    if IsInImperialCity and IsInImperialCity() then return "Imperial City" end
    if IsPlayerInAvAWorld and IsPlayerInAvAWorld() then return "Cyrodiil" end
    return nil
end
function AP.KillsLabel(place) return "AP from player kills" .. (place and (" (" .. place .. ")") or "") end
-- a daily-total name -> place of the kills, or false when it isn't a kills total
local function killsKind(name)
    if name == "Kills" or name == AP.KILLS then return nil end
    local place = type(name) == "string" and name:match("^" .. AP.KILLS .. ": (.+)$")
    if place then return place end
    return false
end
AP.KillsKind = killsKind

-- one change: +amount earned or -amount spent
function AP:Record(diff, reason)
    if not diff or diff == 0 then return end
    local name = self.ReasonName(reason)
    if diff < 0 and not name:find("^Spent") then name = "Spent: " .. name end
    local text, kind = label(name, diff)
    local place = (name == self.KILLS) and killPlace() or nil
    if place then kind = self.KILLS .. ": " .. place end
    local function bump(t)
        local e = t[kind]
        if not e then e = { k = 0, a = 0 }; t[kind] = e end
        e.k = e.k + diff
        e.a = e.a + 1
    end
    local s = sv()
    s.ap = s.ap or {}
    local dk = PDI.DateKey()
    s.ap[dk] = s.ap[dk] or {}
    bump(s.ap[dk])
    s.lifetime.ap = s.lifetime.ap or {}
    bump(s.lifetime.ap)
    PDI.session.ap = PDI.session.ap or {}
    bump(PDI.session.ap)
    s.apEvents = s.apEvents or {}
    local ev = s.apEvents
    local now = PDI.Now()
    local zone = GetUnitZone and PDI.CleanName(GetUnitZone("player")) or nil
    local last = ev[#ev]
    local agg = self.AGG[name] and name or nil
    local sameDay = type(last) == "table" and PDI.DateKey(last.t or 0) == PDI.DateKey(now)
    if (name == self.KILLS and sameDay and last.kill and last.p == place)
            or (agg and sameDay and (last.agg == agg or (agg == self.REPAIRS and last.rep))) then
        -- kills / repairs in a row: one entry that keeps growing (the feed shows them as one line per period anyway)
        last.v, last.n, last.t = (last.v or 0) + diff, (last.n or 1) + 1, now
    else
        local how = (text ~= name) and lastPick or nil          -- (for checking a place name later)
        ev[#ev + 1] = { t = now, v = diff, r = name, e = text, z = zone, kill = (name == self.KILLS) or nil, p = place, agg = agg, how = how }
    end
    -- optional chat line for AP from keeps, outposts and resources
    if diff > 0 and PDI.sv.settings.apChat and (text:find("^Capturing") or text:find("^Defending")) then
        PDI.Msg(string.format("|c66DD66+%s AP|r %s", PDI.Num and PDI.Num(diff) or tostring(diff), text))
    end
    if #ev > self.EVENTS_MAX + 100 then
        local keep = {}
        for i = #ev - self.EVENTS_MAX + 1, #ev do keep[#keep + 1] = ev[i] end
        s.apEvents = keep
    end
    if PDI.UI and PDI.UI.tab == "ap" and PDI.UI.RefreshIfVisible then PDI.UI:RefreshIfVisible() end
end

-- the latest events of one source (nil = all) between two times, newest first
function AP:Events(name, from, to, max)
    local out = {}
    local ev = sv().apEvents or {}
    for i = #ev, 1, -1 do
        local e = ev[i]
        if type(e) == "table" and (not name or e.r == name) and (not from or (e.t or 0) >= from) and (not to or (e.t or 0) < to) then
            out[#out + 1] = e
            if max and #out >= max then break end
        end
    end
    return out
end

-- The feed for a period (inPeriod(t) -> true): [{ t, e = text, v = AP, z }] oldest first, and the lines
-- added up over the period, shown last: Repairs, Resurrecting players, Spent at vendors, then the kills,
-- one line per place (Cyrodiil, Imperial City, Battlegrounds, Duels)
local function killOrder(p)
    for i, x in ipairs(AP.KILL_PLACES) do if x == p then return 10 + i end end
    return 19
end
function AP:Feed(inPeriod)
    local rows, byKey, list = {}, {}, {}
    local function sum(key, e, label, ord, isKill, p)
        local k = byKey[key]
        if not k then
            k = { e = label, v = 0, n = 0, ord = ord, kill = isKill, p = p, z = e.z }
            byKey[key] = k; list[#list + 1] = k
        end
        k.v, k.n, k.t = k.v + (e.v or 0), k.n + (e.n or 1), e.t
    end
    for _, e in ipairs(sv().apEvents or {}) do
        if type(e) == "table" and (not inPeriod or inPeriod(e.t or 0)) then
            local agg = e.agg or (e.rep and self.REPAIRS) or (self.AGG[e.r or ""] and e.r)
            if agg then
                sum("a:" .. agg, e, agg, self.AGG[agg] or 9, false)
            elseif e.kill or e.r == self.KILLS or e.r == "Kills" then
                sum("k:" .. (e.p or ""), e, self.KillsLabel(e.p), killOrder(e.p), true, e.p)
            else
                rows[#rows + 1] = { t = e.t, e = e.e or e.r or "?", v = e.v or 0, z = e.z }
            end
        end
    end
    table.sort(list, function(a, b) return a.ord < b.ord end)
    return rows, list
end

-- line by line only for today and yesterday; older days live on as daily totals
function AP:Prune()
    local yesterday = PDI.DateKey(PDI.Now() - 86400)
    local ev, keep = sv().apEvents or {}, {}
    for _, e in ipairs(ev) do if type(e) == "table" and PDI.DateKey(e.t or 0) >= yesterday then keep[#keep + 1] = e end end
    sv().apEvents = keep
end

-- totals per kind for a period (from the daily totals): [{ e = kind, v = AP, n = times }], and the kills
-- totals per place (shown last)
function AP:Summary(period)
    local by, kills = {}, {}
    for name, e in pairs(PDI.Data:GetPeriod("ap", period)) do
        local place = killsKind(name)
        local kind = place ~= false and ("\1" .. (place or "")) or (self.OLD_KINDS[name] or name)
        local x = by[kind]
        if not x then x = { e = kind, v = 0, n = 0, kill = place ~= false, p = place or nil }; by[kind] = x end
        x.v, x.n = x.v + (e.k or 0), x.n + (e.a or 0)
    end
    local rows = {}
    for kind, x in pairs(by) do
        if x.kill then x.e = self.KillsLabel(x.p); x.ord = killOrder(x.p); kills[#kills + 1] = x
        elseif self.AGG[kind] then x.ord = self.AGG[kind]; kills[#kills + 1] = x
        else rows[#rows + 1] = x end
    end
    table.sort(rows, function(a, b) return a.v > b.v end)
    table.sort(kills, function(a, b) return a.ord < b.ord end)
    return rows, kills
end

-- Not every AP "update" is AP you earned or spent: the game also sends the whole balance when you log in or
-- change zone (from 0 to your total, for the character and for the bank), and moves between the character and
-- the bank. Only changes of the character's own AP, from a real reason, are counted.
local IGNORE = {}
for _, short in ipairs({ "PLAYER_INIT", "BANK_DEPOSIT", "BANK_WITHDRAWAL", "GUILD_BANK_DEPOSIT", "GUILD_BANK_WITHDRAWAL",
                         "BANK_FEE", "CHARACTER_TRANSFER", "ACCOUNT_TRANSFER" }) do
    local v = _G["CURRENCY_CHANGE_REASON_" .. short]
    if type(v) == "number" then IGNORE[v] = true end
end
function AP:IsReal(location, newAmount, oldAmount, reason)
    local why
    if CURRENCY_LOCATION_CHARACTER and location ~= nil and location ~= CURRENCY_LOCATION_CHARACTER then why = "not the character"
    elseif IGNORE[reason] then why = "bank / init"
    elseif (oldAmount or 0) == 0 then why = "balance reload"                    -- the balance being (re)loaded
    elseif self.ReasonName(reason) == "Player init" then why = "init"
    elseif math.abs((newAmount or 0) - (oldAmount or 0)) >= 2000000 then why = "too big"   -- no PvP event is worth millions
    elseif (newAmount or 0) == (oldAmount or 0) then why = "no change" end
    -- the character's balance as the game reports it (to check the totals), and what was left out (last 30)
    local s = sv()
    if (location == nil or location == CURRENCY_LOCATION_CHARACTER) and newAmount and newAmount > 0 then
        s.apBalance = { t = PDI.Now(), v = newAmount }
    end
    if why and why ~= "no change" then
        s.apSkipped = s.apSkipped or {}
        local l = s.apSkipped
        l[#l + 1] = { t = PDI.Now(), loc = location, old = oldAmount, new = newAmount, r = reason, why = why }
        while #l > 30 do table.remove(l, 1) end
    end
    return why == nil
end

-- 1.9.75-1.9.77 counted the balance refreshes as AP: remove those entries once
function AP:FixOld()
    local s = sv()
    if s.settings.apFixed1 then return end
    local function bad(name) return name == "Player init" or (type(name) == "string" and name:find("^Other %(")) end
    for _, bucket in pairs(s.ap or {}) do
        for name in pairs(bucket) do if bad(name) then bucket[name] = nil end end
    end
    for name in pairs(s.lifetime.ap or {}) do if bad(name) then s.lifetime.ap[name] = nil end end
    local keep = {}
    for _, e in ipairs(s.apEvents or {}) do
        if type(e) == "table" and not bad(e.r) and math.abs(e.v or 0) < 2000000 then keep[#keep + 1] = e end
    end
    s.apEvents = keep
    s.settings.apFixed1 = true
end

-- 1.9.81-1.9.82 could name a keep's defense reward after its farm / mine / lumbermill: fix those lines once
function AP:FixPlaces()
    local s = sv()
    if s.settings.apFixed2 then return end
    s.settings.apFixed2 = true
    for _, e in ipairs(s.apEvents or {}) do
        local verb, keep
        if type(e.e) == "string" then verb, keep = e.e:match("^(%a+) (.+ Keep) %a+$") end
        local res = type(e.e) == "string" and (e.e:find(" Farm$") or e.e:find(" Mine$") or e.e:find(" Lumbermill$"))
        if verb and res and math.abs(e.v or 0) >= BIG_REWARD then
            e.e = verb .. " " .. keep
            local from, to = verb .. " Resources", verb .. " Keeps"
            for _, t in ipairs({ s.ap and s.ap[PDI.DateKey(e.t or 0)], s.lifetime.ap }) do
                local a = t and t[from]
                if a and (a.k or 0) >= (e.v or 0) then
                    a.k, a.a = a.k - e.v, math.max(0, (a.a or 1) - 1)
                    if a.a == 0 then t[from] = nil end
                    local b = t[to] or { k = 0, a = 0 }
                    b.k, b.a = b.k + e.v, b.a + 1
                    t[to] = b
                end
            end
        end
    end
end

-- one line you checked by hand (11 Nov): the 7,980 AP was for Blue Road Keep, not its farm
function AP:FixBRK()
    local s = sv()
    if s.settings.apFixed3 then return end
    s.settings.apFixed3 = true
    for _, e in ipairs(s.apEvents or {}) do
        if e.e == "Defending Blue Road Keep Farm" and e.v == 7980 and PDI.DateKey(e.t or 0) == 20261111 then
            e.e = "Defending Blue Road Keep"
            for _, t in ipairs({ s.ap and s.ap[20261111], s.lifetime.ap }) do
                local a = t and t["Defending Resources"]
                if a and (a.k or 0) >= 7980 then
                    a.k, a.a = a.k - 7980, math.max(0, (a.a or 1) - 1)
                    if a.a == 0 then t["Defending Resources"] = nil end
                    local b = t["Defending Keeps"] or { k = 0, a = 0 }
                    b.k, b.a = b.k + 7980, b.a + 1
                    t["Defending Keeps"] = b
                end
            end
        end
    end
end

function AP:Init()
    local s = sv()
    s.ap = s.ap or {}
    s.apEvents = s.apEvents or {}
    s.lifetime.ap = s.lifetime.ap or {}
    PDI.session.ap = PDI.session.ap or {}
    pcall(self.FixOld, self)
    pcall(self.FixPlaces, self)
    pcall(self.FixBRK, self)
    self:Prune()
    if EVENT_KEEP_ALLIANCE_OWNER_CHANGED then
        EM:RegisterForEvent(NS .. "Keep", EVENT_KEEP_ALLIANCE_OWNER_CHANGED, function(_, keepId, _, owner)
            if owner and owner == GetUnitAlliance("player") then noteKeep(keepId, "capture") end
        end)
    end
    if EVENT_KEEP_UNDER_ATTACK_CHANGED then
        EM:RegisterForEvent(NS .. "Attack", EVENT_KEEP_UNDER_ATTACK_CHANGED, function(_, keepId, _, underAttack)
            if not underAttack then noteKeep(keepId, "defense") end
        end)
    end
    if EVENT_CURRENCY_UPDATE and CURT_ALLIANCE_POINTS then
        EM:RegisterForEvent(NS, EVENT_CURRENCY_UPDATE, function(_, currencyType, location, newAmount, oldAmount, reason)
            if currencyType ~= CURT_ALLIANCE_POINTS then return end
            if not self:IsReal(location, newAmount, oldAmount, reason) then return end
            self:Record((newAmount or 0) - (oldAmount or 0), reason)
        end)
    elseif EVENT_ALLIANCE_POINT_UPDATE then
        EM:RegisterForEvent(NS, EVENT_ALLIANCE_POINT_UPDATE, function(_, _, _, diff, reason) self:Record(diff, reason) end)
    end
end
