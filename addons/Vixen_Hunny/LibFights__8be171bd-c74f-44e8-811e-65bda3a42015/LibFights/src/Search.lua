--[[
    LibFights - Search
    One search entry point over everything the library knows, plus a raw-event
    query engine and a chainable query builder.

    LibFights.Search("query", opts)
      Free text matches names; "key:value" tokens filter / scope the search:
        in:ability|set|fight|effect|proc|target|stat|event|cast   restrict to kinds
        id:12345              exact ability / set id
        fight:7               search inside fight #7 (default: current or last fight)
      examples:  "kinras"   "in:set relequen"   "id:61665"   "in:event in:fight crushing"
]]

local LF = LibFights
local Util, Const = LF.Util, LF.Const
local Search = {}
LF.Search_ = Search

local function Result(kind, id, name, icon, detail, data)
    return { kind = kind, id = id, name = name or "", icon = icon or "", detail = detail or "", data = data }
end

function Search.Parse(query)
    local q = { terms = {}, filters = {}, kinds = nil }
    for token in tostring(query or ""):gmatch("%S+") do
        local k, v = token:match("^(%a+):(.+)$")
        if k then
            k = Util.Lower(k)
            if k == "in" or k == "kind" then
                q.kinds = q.kinds or {}
                q.kinds[Util.Lower(v)] = true
            else
                q.filters[k] = v
            end
        else
            q.terms[#q.terms + 1] = token
        end
    end
    q.text = table.concat(q.terms, " ")
    q.ltext = Util.Lower(q.text)
    return q
end

local function Want(q, kind)
    return q.kinds == nil or q.kinds[kind] == true
end

local function Match(q, name)
    if q.ltext == "" then return true end
    return Util.Contains(name, q.ltext)
end

local function ResolveFight(q, opts)
    if opts and opts.fight then return opts.fight end
    local fid = tonumber(q.filters.fight)
    if fid then return LF.Logger.GetFight(fid) end
    return LF.Logger.GetLastFight()
end

-- ---------------------------------------------------------------------------
-- Unified search
-- ---------------------------------------------------------------------------
-- opts: limit (50), fight (Fight object)
function LF.Search(query, opts)
    opts = opts or {}
    local limit = opts.limit or 50
    local q = Search.Parse(query)
    local results = {}
    local function add(r)
        if #results < limit then results[#results + 1] = r end
    end
    local exactId = tonumber(q.filters.id) or tonumber(q.text)

    -- abilities
    if Want(q, "ability") then
        local list = exactId and LF.Abilities.Search(tostring(exactId), 1) or (q.text ~= "" and LF.Abilities.Search(q.text, limit) or {})
        for _, info in ipairs(list) do
            add(Result("ability", info.id, info.name, info.icon, string.format("Ability %d", info.id), info))
        end
    end
    -- sets
    if Want(q, "set") then
        local list = exactId and LF.Sets.Search(tostring(exactId), 1) or (q.text ~= "" and LF.Sets.Search(q.text, limit) or {})
        for _, info in ipairs(list) do
            add(Result("set", info.setId, info.name, "", string.format("Set %d (%s, %s pieces)", info.setId, tostring(info.setTypeName or "?"), tostring(info.maxEquipped or "?")), info))
        end
    end
    -- stats
    if Want(q, "stat") and q.text ~= "" then
        local snap = LF.Stats.current or LF.Stats.GetSnapshot()
        for key, v in pairs(snap) do
            local label = LF.Stats.GetStatLabel(key)
            if type(v) == "number" and (Match(q, label) or Match(q, key)) then
                add(Result("stat", key, label, "", Util.CommaNumber(v), v))
            end
        end
    end
    -- fights
    if Want(q, "fight") and not q.filters.fight then
        local all = {}
        for _, f in ipairs(LF.Logger.GetFights()) do all[#all + 1] = f end
        for _, f in ipairs(LF.Storage and LF.Storage.GetSavedFights() or {}) do all[#all + 1] = f end
        for i = #all, 1, -1 do
            local f = all[i]
            local title = f:GetTitle()
            local hay = table.concat({ title, f.zoneName or "", f.character or "" }, " ")
            local matchesTarget = false
            if q.ltext ~= "" then
                for _, t in pairs(f.targets) do
                    if Util.Contains(t.name, q.ltext) then matchesTarget = true break end
                end
            end
            if q.ltext == "" or Util.Contains(hay, q.ltext) or matchesTarget then
                add(Result("fight", f.id, title, "", string.format("%s | %s | DPS %s", f.zoneName or "", Util.FormatDuration(f:GetDurationMs()), Util.FormatNumber(f:GetDPS())), f))
            end
        end
    end

    -- inside one fight
    local fight = ResolveFight(q, opts)
    if fight then
        if Want(q, "target") then
            for _, t in ipairs(fight:GetTargets()) do
                if Match(q, t.name) then add(Result("target", t.unitId, t.name, "", string.format("%s dmg (%s)", Util.FormatNumber(t.damage), Util.FormatPct(t.pct)), t)) end
            end
        end
        if Want(q, "ability") then
            for _, kind in ipairs({ "damageOut", "healOut", "damageIn", "healIn" }) do
                for _, a in pairs(fight.abilities[kind]) do
                    if (exactId and a.id == exactId) or (not exactId and q.ltext ~= "" and Match(q, a.name)) then
                        add(Result("fightAbility", a.id, a.name, a.icon, string.format("%s: %s total, %d hits, max %s", kind, Util.FormatNumber(a.total), a.hits, Util.FormatNumber(a.max)), a))
                    end
                end
            end
        end
        if Want(q, "effect") then
            for _, scope in ipairs({ "player", "target" }) do
                for _, e in ipairs(fight:GetEffectUptimes(scope)) do
                    if (exactId and e.id == exactId) or (not exactId and Match(q, e.name)) then
                        add(Result("effect", e.id, e.name, e.icon, string.format("%s uptime %s", scope, Util.FormatPct(e.uptimePct)), e))
                    end
                end
            end
        end
        if Want(q, "proc") then
            for _, p in pairs(fight.procs) do
                if (exactId and p.id == exactId) or (not exactId and (Match(q, p.name) or (p.setName and Match(q, p.setName)))) then
                    add(Result("proc", p.id, p.name, p.icon, string.format("%d procs%s", p.activations, p.setName and (" [" .. p.setName .. "]") or ""), p))
                end
            end
        end
        if Want(q, "cast") then
            for _, c in pairs(fight.casts.abilities) do
                if (exactId and c.id == exactId) or (not exactId and Match(q, c.name)) then
                    add(Result("cast", c.id, c.name, c.icon, string.format("%d casts (%s)", c.count, c.kind), c))
                end
            end
        end
        if q.kinds and q.kinds.event then
            local filter = { abilityId = exactId, abilityName = (not exactId and q.text ~= "") and q.text or nil, limit = limit }
            for _, ev in ipairs(LF.FindEvents(fight, filter)) do
                add(Result("event", ev.abilityId, ev.abilityName, ev.icon,
                    string.format("%.1fs %s %s %s -> %s", ev.tMs / 1000, ev.direction, ev.resultName, Util.CommaNumber(ev.hit), ev.target), ev))
            end
        end
    end
    return results
end

function Search.FormatResult(r)
    local icon = r.icon ~= "" and (Util.IconMarkup(r.icon, 18) .. " ") or ""
    return string.format("[%s] %s%s (%s) %s", r.kind, icon, r.name, tostring(r.id), r.detail)
end

-- ---------------------------------------------------------------------------
-- Raw event queries
-- ---------------------------------------------------------------------------
--[[
    filter fields (all optional):
      direction   "out" | "in" | "self" | "group"
      category    "damage" | "heal" | "shield" | "avoid" | "cc" | "death" | "power" | "cast" | "effect" | "other"
      result      ACTION_RESULT_* value
      abilityId   number,  abilityName  substring
      source / target  name substring,   sourceUnitId / targetUnitId
      damageType  DAMAGE_TYPE_* value
      crit        true / false
      minHit / maxHit
      fromMs / toMs   (relative to fight start)
      limit       max results (default 200)
      newestFirst true -> newest events first
]]
function LF.FindEvents(fight, filter)
    fight = fight or LF.Logger.GetLastFight()
    filter = filter or {}
    local out = {}
    if not fight then return out end
    local F = LF.EVENT_FIELDS
    local events = fight:GetEvents()
    local limit = filter.limit or 200
    local dirNum
    if filter.direction then
        for k, v in pairs(LF.Fight.DIR_NAME) do if v == filter.direction then dirNum = k end end
    end
    local lname = filter.abilityName and Util.Lower(filter.abilityName)
    local startMs = fight.startMs
    local n = #events
    local from, to, step = 1, n, 1
    if filter.newestFirst then from, to, step = n, 1, -1 end
    for i = from, to, step do
        local ev = events[i]
        local ok = true
        local t = ev[F.TIME] - startMs
        if dirNum and ev[F.DIR] ~= dirNum then ok = false end
        if ok and filter.result and ev[F.RESULT] ~= filter.result then ok = false end
        if ok and filter.category and Const.GetResultCategory(ev[F.RESULT]) ~= filter.category then ok = false end
        if ok and filter.abilityId and ev[F.ABILITY] ~= filter.abilityId then ok = false end
        if ok and filter.damageType and ev[F.DAMAGE_TYPE] ~= filter.damageType then ok = false end
        if ok and filter.sourceUnitId and ev[F.SOURCE] ~= filter.sourceUnitId then ok = false end
        if ok and filter.targetUnitId and ev[F.TARGET] ~= filter.targetUnitId then ok = false end
        if ok and filter.minHit and ev[F.HIT] < filter.minHit then ok = false end
        if ok and filter.maxHit and ev[F.HIT] > filter.maxHit then ok = false end
        if ok and filter.fromMs and t < filter.fromMs then ok = false end
        if ok and filter.toMs and t > filter.toMs then ok = false end
        if ok and filter.crit ~= nil and ((Const.CRIT_RESULTS[ev[F.RESULT]] or false) ~= filter.crit) then ok = false end
        if ok and lname and not Util.Contains(LF.Abilities.GetName(ev[F.ABILITY]), lname) then ok = false end
        if ok and filter.source and not Util.Contains(fight:GetUnitName(ev[F.SOURCE]), filter.source) then ok = false end
        if ok and filter.target and not Util.Contains(fight:GetUnitName(ev[F.TARGET]), filter.target) then ok = false end
        if ok then
            out[#out + 1] = fight:DecodeEvent(ev)
            if #out >= limit then break end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Chainable query builder
--   LibFights.NewQuery(fight):Direction("out"):Category("damage"):Crit(true):MinHit(5000):Limit(20):Run()
-- ---------------------------------------------------------------------------
local Query = {}
Query.__index = Query

function LF.NewQuery(fight)
    return setmetatable({ fight = fight, filter = {} }, Query)
end

local function setter(field)
    return function(self, v) self.filter[field] = v return self end
end
Query.Direction = setter("direction")
Query.Category = setter("category")
Query.Result = setter("result")
Query.Ability = setter("abilityId")
Query.AbilityName = setter("abilityName")
Query.Source = setter("source")
Query.Target = setter("target")
Query.DamageType = setter("damageType")
Query.Crit = setter("crit")
Query.MinHit = setter("minHit")
Query.MaxHit = setter("maxHit")
Query.From = setter("fromMs")
Query.To = setter("toMs")
Query.Limit = setter("limit")
Query.NewestFirst = function(self) self.filter.newestFirst = true return self end

function Query:Run()
    return LF.FindEvents(self.fight, self.filter)
end

function Query:Count()
    local f = Util.ShallowCopy(self.filter)
    f.limit = f.limit or 1e9
    return #LF.FindEvents(self.fight, f)
end

function Query:Sum()
    local f = Util.ShallowCopy(self.filter)
    f.limit = f.limit or 1e9
    local s = 0
    for _, e in ipairs(LF.FindEvents(self.fight, f)) do s = s + (e.hit or 0) end
    return s
end

function Query:Max()
    local f = Util.ShallowCopy(self.filter)
    f.limit = f.limit or 1e9
    local best
    for _, e in ipairs(LF.FindEvents(self.fight, f)) do
        if not best or e.hit > best.hit then best = e end
    end
    return best
end

-- Searches saved + in-memory fights with structured criteria
-- filter: zone, title, target, character (substrings), minDurationSec, minDPS, minSPS, sinceTimestamp
function LF.QueryFights(filter)
    filter = filter or {}
    local out = {}
    local all = {}
    for _, f in ipairs(LF.Logger.GetFights()) do all[#all + 1] = f end
    for _, f in ipairs(LF.Storage and LF.Storage.GetSavedFights() or {}) do all[#all + 1] = f end
    for _, f in ipairs(all) do
        local ok = true
        if filter.zone and not Util.Contains(f.zoneName, filter.zone) then ok = false end
        if ok and filter.title and not Util.Contains(f:GetTitle(), filter.title) then ok = false end
        if ok and filter.character and not Util.Contains(f.character, filter.character) then ok = false end
        if ok and filter.minDurationSec and f:GetDurationSec() < filter.minDurationSec then ok = false end
        if ok and filter.minDPS and f:GetDPS() < filter.minDPS then ok = false end
        if ok and filter.minSPS and f:GetSPS() < filter.minSPS then ok = false end
        if ok and filter.sinceTimestamp and (f.startTimestamp or 0) < filter.sinceTimestamp then ok = false end
        if ok and filter.target then
            local found = false
            for _, t in pairs(f.targets) do if Util.Contains(t.name, filter.target) then found = true break end end
            ok = found
        end
        if ok then out[#out + 1] = f end
    end
    return out
end
