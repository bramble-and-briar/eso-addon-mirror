-- Lethal PVP Insights - storage, aggregation and retention
local PDI = PVPDataInsight
local Data = {}
PDI.Data = Data

PDI.session = { my = {}, feed = {} }

local function sv() return PDI.sv end

---------------------------------------------------------------------------
-- Name map (character name -> @account / alliance)
---------------------------------------------------------------------------
function Data:LearnName(char, acct, al)
    if not char then return end
    acct = PDI.NormalizeAccount(acct)
    local e = sv().names[char]
    if not e then e = {}; sv().names[char] = e end
    -- the same character under another @account: the player changed their account name
    if acct and e.acct and e.acct ~= acct and char:sub(1, 1) ~= "@" then
        local f = sv().formerAccts or {}
        sv().formerAccts = f
        f[acct] = f[acct] or {}
        f[acct][e.acct] = PDI.Now()
    end
    if acct then e.acct = acct end
    if al and al ~= 0 then e.al = al end
    e.t = PDI.Now()
    if acct then
        self:MergeOpponentAlias(char, acct)
        if char ~= acct then self:MergeKillAlias(char, acct) end
    end
end

-- Class of a character (from targeting it, grouping with it or the encounter log). One @account can
-- play several classes; the lists keep each class apart.
function Data:NoteClass(char, cls)
    if not char or not cls or cls == 0 or char:sub(1, 1) == "@" then return end
    local e = sv().names[char]
    if not e then e = { t = PDI.Now() }; sv().names[char] = e end
    e.cls = cls
end

function Data:ClassOf(char)
    if not char then return nil end
    local e = sv().names[char]
    if e and e.cls then return e.cls end
    return self:ClassIndex()[char]
end

-- character -> class, from everything recorded (rebuilt at most every few seconds for the lists)
local classIndex, classIndexAt = nil, 0
function Data:ClassIndex()
    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    if classIndex and now - classIndexAt < 3000 then return classIndex end
    local idx = {}
    local function put(ch, cls) if ch and cls and cls ~= 0 then idx[ch] = cls end end
    -- weakest first, later sources overwrite: old opponent records could carry another character's class
    local days = {}
    for dk in pairs(sv().opponents) do days[#days + 1] = dk end
    table.sort(days)
    for _, dk in ipairs(days) do
        for _, rec in pairs(sv().opponents[dk]) do
            if type(rec) == "table" then
                if not rec.chars then put(rec.char, rec.cls) end
                for ch, ce in pairs(rec.chars or {}) do put(ch, type(ce) == "table" and ce.cls) end
            end
        end
    end
    for _, b in pairs(sv().importedBuilds or {}) do
        local bb = type(b) == "table" and (b.build or b)
        if type(bb) == "table" then put(bb.char, bb.cls) end
    end
    for _, e in pairs(sv().group or {}) do
        if type(e) == "table" then
            put(e.char, e.cls)
            for ch, o in pairs(e.other or {}) do put(ch, type(o) == "table" and o.cls) end
        end
    end
    for _, e in pairs(sv().profiles or {}) do if type(e) == "table" then put(e.char, e.cls) end end
    for ch, e in pairs(sv().names) do if type(e) == "table" then put(ch, e.cls) end end
    classIndex, classIndexAt = idx, now
    return idx
end

function Data:GetAccount(char)
    local e = char and sv().names[char]
    return e and e.acct or nil
end

function Data:GetAlliance(char)
    local e = char and sv().names[char]
    return e and e.al or nil
end

-- Identity used as table key: @account when known, otherwise character name
function Data:Who(char, acct)
    acct = PDI.NormalizeAccount(acct) or self:GetAccount(char)
    return acct or char, acct
end

---------------------------------------------------------------------------
-- Kill counters (feature 1 and 2)
---------------------------------------------------------------------------
local function bump(bucket, who, field, al, char)
    local e = bucket[who]
    if not e then e = { k = 0, a = 0 }; bucket[who] = e end
    e[field] = (e[field] or 0) + 1
    if al and al ~= 0 then e.al = al end
    if char then
        e.c = char
        -- per character too (one @account can play several classes)
        e.ch = e.ch or {}
        local x = e.ch[char]
        if not x then x = {}; e.ch[char] = x end
        x[field] = (x[field] or 0) + 1
    end
end

local function dayBucket(kind, dateKey)
    local t = sv()[kind]
    local b = t[dateKey]
    if not b then b = {}; t[dateKey] = b end
    return b
end

-- field: "k" (killing blow) or "a" (assist)
function Data:AddMyKill(char, acct, al, field)
    local who
    who, acct = self:Who(char, acct)
    if not who then return end
    al = (al and al ~= 0) and al or self:GetAlliance(char)
    local today = PDI.DateKey()
    bump(PDI.session.my, who, field, al, char)
    bump(dayBucket("my", today), who, field, al, char)
    bump(sv().lifetime.my, who, field, al, char)
    return who, { who = who, date = today, field = field, char = char }
end

-- Reverse one AddMyKill (used when the kill feed corrects a combat-event guess)
local function unbump(bucket, who, field, char)
    local e = bucket and bucket[who]
    if not e then return end
    e[field] = math.max(0, (e[field] or 0) - 1)
    local x = char and e.ch and e.ch[char]
    if x then x[field] = math.max(0, (x[field] or 0) - 1) end
    if (e.k or 0) == 0 and (e.a or 0) == 0 then bucket[who] = nil end
end

-- Kills / assists counted under a character name (account not known yet) move to the @account
-- as soon as it is learned (kill feed, targeting, group), so one player never shows as two rows.
local function mergeKillRow(bucket, char, acct)
    local old = bucket and bucket[char]
    if not old then return end
    bucket[char] = nil
    local e = bucket[acct]
    if not e then
        old.c = old.c or char
        if not old.ch then old.ch = { [char] = { k = old.k, a = old.a } } end
        bucket[acct] = old
        return
    end
    e.k = (e.k or 0) + (old.k or 0)
    e.a = (e.a or 0) + (old.a or 0)
    if not e.al or e.al == 0 then e.al = old.al end
    e.c = e.c or old.c or char
    e.ch = e.ch or {}
    local och = old.ch or { [char] = { k = old.k, a = old.a } }
    for ch, x in pairs(och) do
        local y = e.ch[ch] or {}
        y.k = (y.k or 0) + (x.k or 0)
        y.a = (y.a or 0) + (x.a or 0)
        if y.k == 0 then y.k = nil end
        if y.a == 0 then y.a = nil end
        e.ch[ch] = y
    end
end

function Data:MergeKillAlias(char, acct)
    if not char or not acct or char:sub(1, 1) == "@" then return end
    local today = PDI.DateKey()
    for _, kind in ipairs({ "my", "feed" }) do
        mergeKillRow(PDI.session and PDI.session[kind], char, acct)
        mergeKillRow(sv()[kind] and sv()[kind][today], char, acct)
        mergeKillRow(sv().lifetime and sv().lifetime[kind], char, acct)
    end
end

function Data:UndoMyKill(entry)
    if not entry or not entry.who then return end
    -- the row may have moved to the @account since it was counted
    if entry.who:sub(1, 1) ~= "@" then
        local acct = self:GetAccount(entry.char or entry.who)
        if acct then entry.who = acct end
    end
    unbump(PDI.session.my, entry.who, entry.field, entry.char)
    unbump(sv().my[entry.date], entry.who, entry.field, entry.char)
    unbump(sv().lifetime.my, entry.who, entry.field, entry.char)
end

---------------------------------------------------------------------------
-- Kill event log: one record per kill feed message, so the same kill reported by many players can
-- later be matched (campaign + killer + victim + location, times within a few seconds).
-- Fields: t = UTC seconds (this PC's clock), gms = game-time ms (for ordering within a session),
--   srv = megaserver ("NA Megaserver"...), camp/campName = campaign, zone = zone you were in,
--   loc = location name from the kill feed, here = the game flagged the location as the kill spot,
--   ka/kc/kal/kr = killer @account/character/alliance/rank, va/vc/val/vr = same for the victim,
--   obs = your own map position when it arrived {x, y} (0-1 on map obsMap), obsLoc = your location name
---------------------------------------------------------------------------
PDI.KILL_EVENTS_PER_DAY_MAX = 20000

function Data:AddKillEvent(e)
    sv().killEvents = sv().killEvents or {}
    local dk = PDI.DateKey()
    local list = sv().killEvents[dk]
    if not list then list = {}; sv().killEvents[dk] = list end
    if #list >= PDI.KILL_EVENTS_PER_DAY_MAX then return end
    e.t = PDI.Now()
    e.gms = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or nil
    e.srv = GetWorldName and GetWorldName() or nil
    local camp = GetCurrentCampaignId and GetCurrentCampaignId() or 0
    if camp and camp ~= 0 then
        e.camp = camp
        e.campName = GetCampaignName and PDI.CleanName(GetCampaignName(camp)) or nil
    end
    if GetCurrentBattlegroundId then
        local bg = GetCurrentBattlegroundId()
        if bg and bg ~= 0 then e.bg = bg end
    end
    e.zone = GetUnitZone and PDI.CleanName(GetUnitZone("player")) or nil
    if IsInImperialCity and IsInImperialCity() then e.ic = true end
    if GetMapPlayerPosition then
        local ok, x, y = pcall(GetMapPlayerPosition, "player")
        if ok and x and y then e.obs = { math.floor(x * 10000) / 10000, math.floor(y * 10000) / 10000 } end
        e.obsMap = GetMapName and PDI.CleanName(GetMapName()) or nil
    end
    e.obsLoc = GetPlayerLocationName and PDI.CleanName(GetPlayerLocationName()) or nil
    list[#list + 1] = e
end

function Data:CountKillEvents()
    local days, n = 0, 0
    for _, list in pairs(sv().killEvents or {}) do days = days + 1; n = n + #list end
    return n, days
end

function Data:AddFeedKill(char, acct, al)
    local who
    who, acct = self:Who(char, acct)
    if not who then return end
    al = (al and al ~= 0) and al or self:GetAlliance(char)
    local today = PDI.DateKey()
    bump(PDI.session.feed, who, "k", al, char)
    bump(dayBucket("feed", today), who, "k", al, char)
    bump(sv().lifetime.feed, who, "k", al, char)
end

local function merge(dst, src)
    for who, e in pairs(src) do
        local d = dst[who]
        if not d then d = { k = 0, a = 0 }; dst[who] = d end
        d.k = d.k + (e.k or 0)
        d.a = d.a + (e.a or 0)
        if e.al and e.al ~= 0 then d.al = e.al end
        if e.c then d.c = e.c end
        -- per character; counts from before characters were kept apart go to that day's last character
        d.ch = d.ch or {}
        local rk, ra = e.k or 0, e.a or 0
        for ch, x in pairs(e.ch or {}) do
            local y = d.ch[ch]
            if not y then y = { k = 0, a = 0 }; d.ch[ch] = y end
            y.k = y.k + (x.k or 0); y.a = y.a + (x.a or 0)
            if x.cls then y.cls = x.cls end           -- class from esopvp.com's leaderboard
            rk = rk - (x.k or 0); ra = ra - (x.a or 0)
        end
        if (rk > 0 or ra > 0) then
            local ch = e.c or "?"
            local y = d.ch[ch]
            if not y then y = { k = 0, a = 0 }; d.ch[ch] = y end
            y.k = y.k + math.max(rk, 0); y.a = y.a + math.max(ra, 0)
        end
    end
end

local function prevMonth(dateKey)
    local y = math.floor(dateKey / 10000)
    local m = math.floor(dateKey / 100) % 100 - 1
    if m == 0 then m = 12; y = y - 1 end
    return y * 100 + m
end

-- Returns { [who] = { k=, a=, al=, c= } } for the requested period
-- Kill Feed for This Month / Last Month / Lifetime: the leaderboard esopvp.com sends with the shared data
-- (the Companion downloads it after each upload), so the addon doesn't keep months of kill feed itself.
local SERVER_FEED = { mtd = true, lastmonth = true, lifetime = true }
local function serverFeed(period)
    local s = PVPDataInsight_Shared
    local f = type(s) == "table" and type(s.feedTop) == "table" and s.feedTop or nil
    local ps = f and type(f.periods) == "table" and f.periods or nil
    -- an empty lifetime list means esopvp.com has nothing for your server (yet): keep using your own data
    if not (ps and type(ps.lifetime) == "table" and next(ps.lifetime)) then return nil end
    local p = ps[period]
    return type(p) == "table" and p or nil, f.generated
end
function Data:FeedFromServer(kind, period)
    if kind ~= "feed" or not SERVER_FEED[period] then return nil end
    local p, generated = serverFeed(period)
    return p and (generated or 0) or nil
end

-- What esopvp.com confirmed it received: the time of the saved data file the Companion uploaded (PC clock)
function Data:SentUntil()
    local c = PVPDataInsight_Companion
    local t = type(c) == "table" and tonumber(c.sent) or nil
    return (t and t > 0) and t or nil
end

function Data:GetPeriod(kind, period)
    local out = {}
    if period == "session" then merge(out, PDI.session[kind]); return out end
    if self:FeedFromServer(kind, period) then merge(out, (serverFeed(period))); return out end
    if period == "lifetime" then merge(out, sv().lifetime[kind]); return out end

    local buckets = sv()[kind]
    local now = PDI.Now()
    local today = PDI.DateKey(now)
    if period == "today" then
        if buckets[today] then merge(out, buckets[today]) end
    elseif period == "yesterday" then
        local y = PDI.DateKey(now - 86400)
        if buckets[y] then merge(out, buckets[y]) end
    elseif period == "week" then
        local seen = {}
        for i = 0, 6 do
            local dk = PDI.DateKey(now - i * 86400)
            if not seen[dk] and buckets[dk] then merge(out, buckets[dk]) end
            seen[dk] = true
        end
    elseif period == "mtd" or period == "lastmonth" then
        local ym = (period == "mtd") and math.floor(today / 100) or prevMonth(today)
        for dk, b in pairs(buckets) do
            if math.floor(dk / 100) == ym then merge(out, b) end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Opponent data (feature 3)
---------------------------------------------------------------------------
local function newRecord(char, acct)
    return {
        char = char, acct = acct, al = 0, cls = 0, hp = 0,
        mundus = {}, skills = {}, killedYou = 0,
        first = PDI.Now(), last = PDI.Now(), hit = false,
    }
end

local function mergeRecord(dst, src)
    dst.char = dst.char or src.char
    dst.acct = dst.acct or src.acct
    if (dst.al or 0) == 0 then dst.al = src.al end
    if (dst.cls or 0) == 0 then dst.cls = src.cls end
    dst.hp = math.max(dst.hp or 0, src.hp or 0)
    for m in pairs(src.mundus or {}) do dst.mundus[m] = true end
    for k, s in pairs(src.skills or {}) do
        local d = dst.skills[k]
        if not d then
            dst.skills[k] = s
        else
            d.h = (d.h or 0) + (s.h or 0)
            d.m = math.max(d.m or 0, s.m or 0)
            d.total = (d.total or 0) + (s.total or 0)
            for ty in pairs(s.ty or {}) do d.ty[ty] = true end
            if s.c then
                d.c = d.c or {}
                for ch, n in pairs(s.c) do d.c[ch] = (d.c[ch] or 0) + n end
            end
        end
    end
    for ch, v in pairs(src.chars or {}) do
        dst.chars = dst.chars or {}
        local e = dst.chars[ch] or {}
        if (e.cls or 0) == 0 then e.cls = v.cls end
        e.last = math.max(e.last or 0, v.last or 0)
        dst.chars[ch] = e
    end
    dst.killedYou = (dst.killedYou or 0) + (src.killedYou or 0)
    dst.first = math.min(dst.first or src.first, src.first or dst.first)
    dst.last = math.max(dst.last or src.last, src.last or dst.last)
    dst.hit = dst.hit or src.hit
end

-- When we learn a character's @account, fold the character-keyed record into the account record
function Data:MergeOpponentAlias(char, acct)
    local b = sv().opponents[PDI.DateKey()]
    if not b or char == acct then return end
    local old = b[char]
    if not old then return end
    b[char] = nil
    old.acct = acct
    if b[acct] then mergeRecord(b[acct], old) else b[acct] = old end
end

function Data:GetOpponent(char, acct, create)
    local who
    who, acct = self:Who(char, acct)
    if not who then return nil end
    local today = PDI.DateKey()
    local b = sv().opponents[today]
    if not b then
        if not create then return nil end
        b = {}; sv().opponents[today] = b
    end
    local rec = b[who]
    if not rec and create then
        rec = newRecord(char, acct)
        b[who] = rec
    end
    if rec then
        rec.char = char or rec.char
        rec.acct = acct or rec.acct
        -- one @account can play several characters in a day: keep track of each (class, skills)
        if char and char ~= "" and char:sub(1, 1) ~= "@" then
            rec.chars = rec.chars or {}
            local e = rec.chars[char]
            if not e then e = { cls = 0 }; rec.chars[char] = e end
            e.last = PDI.Now()
        end
        local al = self:GetAlliance(char)
        if al and (rec.al or 0) == 0 then rec.al = al end
    end
    return rec
end

-- skillType: "dmg", "dot", "kb", "eff", "cc"
function Data:RecordIncoming(char, abilityId, abilityName, skillType, hitValue)
    local rec = self:GetOpponent(char, nil, true)
    if not rec then return end
    local name = PDI.CleanName(abilityName)
    if (not name) and abilityId and abilityId > 0 then name = PDI.CleanName(GetAbilityName(abilityId)) end
    if not name then return end
    local key = string.lower(name) -- dedupe by name so morph/rank variants collapse
    local s = rec.skills[key]
    if not s then
        s = { n = name, id = abilityId, h = 0, m = 0, total = 0, ty = {} }
        rec.skills[key] = s
    end
    s.h = s.h + 1
    if char and char ~= "" and char:sub(1, 1) ~= "@" then
        s.c = s.c or {}
        s.c[char] = (s.c[char] or 0) + 1
    end
    hitValue = hitValue or 0
    if hitValue > s.m then s.m = hitValue end
    s.total = (s.total or 0) + hitValue
    s.ty[skillType] = true
    rec.hit = true
    if skillType ~= "eff" then rec.hostile = true end
    rec.last = PDI.Now()
end

function Data:RecordKilledBy(char, acct, al)
    local rec = self:GetOpponent(char, acct, true)
    if not rec then return end
    rec.killedYou = (rec.killedYou or 0) + 1
    if al and al ~= 0 then rec.al = al end
    rec.hit = true
    rec.hostile = true
    rec.last = PDI.Now()
end

function Data:RecordProfile(char, acct, al, cls, hp, mundusList)
    local rec = self:GetOpponent(char, acct, true)
    if not rec then return end
    if al and al ~= 0 then rec.al = al end
    if cls and cls ~= 0 then
        rec.cls = cls
        local e = rec.chars and char and rec.chars[char]
        if e then e.cls = cls end
        self:NoteClass(char, cls)
    end
    -- keep the latest plausible reading (the highest-ever reading picked up temporary effects/glitches)
    if hp and hp > 0 and hp <= PDI.MAX_PLAUSIBLE_HP then rec.hp = hp end
    for _, m in ipairs(mundusList or {}) do rec.mundus[m] = true end
    rec.last = PDI.Now()
end

function Data:IsHostile(char)
    local rec = self:GetOpponent(char, nil, false)
    return rec ~= nil and rec.hostile == true
end

-- Most recent opponent record for an account/character within the retention window
function Data:FindLatestOpponent(who)
    for _, dk in ipairs(self:GetOpponentDates()) do
        local b = sv().opponents[dk]
        if b[who] then return b[who], dk end
        for _, rec in pairs(b) do
            if rec.char == who or rec.acct == who then return rec, dk end
        end
    end
    return nil
end

-- v1.6 one-time cleanup: earlier versions could list group members / friendly buffers as opponents
function Data:CleanupOpponents()
    local friends = {}
    for acct, e in pairs(sv().group or {}) do
        friends[acct] = true
        if e.char then friends[e.char] = true end
    end
    local removed = 0
    for dk, b in pairs(sv().opponents) do
        for who, rec in pairs(b) do
            if rec.hostile == nil then
                local hostile = (rec.killedYou or 0) > 0
                for _, sk in pairs(rec.skills or {}) do
                    for ty in pairs(sk.ty or {}) do if ty ~= "eff" then hostile = true end end
                end
                rec.hostile = hostile
            end
            if friends[who] or (rec.char and friends[rec.char]) or (rec.acct and friends[rec.acct]) or not rec.hostile then
                b[who] = nil
                removed = removed + 1
            end
        end
    end
    return removed
end

---------------------------------------------------------------------------
-- Player profiles: anyone you target (friend or foe) - class, race, faction, health, mundus, buffs
---------------------------------------------------------------------------
function Data:RecordPlayerProfile(char, acct, p)
    sv().profiles = sv().profiles or {}
    local who
    who, acct = self:Who(char, acct)
    if not who then return end
    local e = sv().profiles[who]
    if not e then e = {}; sv().profiles[who] = e end
    -- another character of the same @account: start a fresh profile (class, mundus and buffs of the
    -- old character must not mix with the new one; esopvp.com already has the old one)
    if char and e.char and char ~= e.char and char ~= acct then
        e = { acct = e.acct, al = e.al }
        sv().profiles[who] = e
    end
    if char then
        -- fold a character-keyed profile into the account one
        if acct and char ~= acct and sv().profiles[char] then sv().profiles[char] = nil end
        e.char = char
    end
    e.acct = acct or e.acct
    if p.al and p.al ~= 0 then e.al = p.al end
    if p.cls and p.cls ~= 0 then e.cls = p.cls; self:NoteClass(char, p.cls) end
    if p.race and p.race ~= "" then e.race = p.race end
    if p.cp and p.cp > 0 then e.cp = p.cp end
    if p.hp and p.hp > 0 and p.hp <= PDI.MAX_PLAUSIBLE_HP then e.hp = p.hp end
    if p.mundus and #p.mundus > 0 then
        e.mundus = {}
        for _, m in ipairs(p.mundus) do e.mundus[m] = true end
    end
    if p.buffs then
        -- build up: every buff seen during the window is kept (one entry per name); once the window
        -- has passed, the next look starts a fresh list
        local now = PDI.Now()
        local hours = tonumber(sv().settings.buffWindowHours) or 36
        -- a new list each day too: a build seen today and one from yesterday must not mix
        -- (and after PDI.BUILD_SPLIT_SEC without targeting them, when that is set)
        if not e.buffs or not e.buffsSince or now - e.buffsSince >= hours * 3600
            or PDI.DateKey(e.buffsSince) ~= PDI.DateKey(now)
            or (PDI.BUILD_SPLIT_SEC and now - (e.t or 0) > PDI.BUILD_SPLIT_SEC) then
            e.buffs, e.buffsSince, e.mm = {}, now, nil
        end
        for name, b in pairs(p.buffs) do e.buffs[name] = b end
        for name, perm in pairs(p.mm or {}) do e.mm = e.mm or {}; e.mm[name] = perm end
    end
    e.t = PDI.Now()
end

function Data:GetProfile(who, char)
    local pr = sv().profiles
    if not pr then return nil end
    if who and pr[who] then return pr[who] end
    if char then
        local acct = self:GetAccount(char)
        if acct and pr[acct] then return pr[acct] end
        if pr[char] then return pr[char] end
    end
    return nil
end

function Data:GetOpponentDates()
    local dates = {}
    for dk in pairs(sv().opponents) do dates[#dates + 1] = dk end
    table.sort(dates, function(a, b) return a > b end)
    return dates
end

function Data:GetOpponents(dateKey)
    return sv().opponents[dateKey] or {}
end

---------------------------------------------------------------------------
-- Saved snapshots (never pruned)
---------------------------------------------------------------------------
function Data:SaveOpponent(who, dateKey, rec, logSnap)
    local id = who .. "|" .. tostring(dateKey)
    local copy = ZO_DeepTableCopy(rec)
    copy.log = logSnap and ZO_DeepTableCopy(logSnap) or nil
    if copy.log then copy.log.count, copy.log.idx = 1, 1 end
    sv().saved[id] = { who = who, date = dateKey, savedAt = PDI.Now(), rec = copy }
    return id
end

-- A friendly (or any targeted) player's profile: buffs, mundus, class... plus imported gear if any.
-- Several snapshots per player are allowed; kept until deleted, like saved opponents.
function Data:FindSavedPlayer(who, fp)
    if not fp then return nil end
    for id, e in pairs(sv().saved) do
        if e.kind == "player" and e.who == who and e.fp == fp then return id end
    end
    return nil
end

function Data:SavePlayer(who, rec, logSnap, fp)
    local now = PDI.Now()
    local id = "P|" .. who .. "|" .. tostring(now)
    local copy = ZO_DeepTableCopy(rec)
    copy.log = logSnap and ZO_DeepTableCopy(logSnap) or nil
    if copy.log then copy.log.count, copy.log.idx = 1, 1 end
    sv().saved[id] = { who = who, date = PDI.DateKey(now), savedAt = now, kind = "player", rec = copy, fp = fp }
    return id
end

function Data:DeleteSaved(id) sv().saved[id] = nil end

function Data:IsSaved(who, dateKey) return sv().saved[who .. "|" .. tostring(dateKey)] ~= nil end

---------------------------------------------------------------------------
-- Retention
---------------------------------------------------------------------------
function Data:Prune()
    local now = PDI.Now()
    local oppCut   = PDI.DateKey(now - (PDI.OPPONENT_RETENTION_DAYS - 1) * 86400)
    local dailyCut = PDI.DateKey(now - PDI.DAILY_RETENTION_DAYS * 86400)
    for dk in pairs(sv().opponents) do if dk < oppCut then sv().opponents[dk] = nil end end
    for dk in pairs(sv().my) do if dk < dailyCut then sv().my[dk] = nil end end
    -- with esopvp.com's Kill Feed leaderboard (and uploads confirmed), the addon keeps only 8 days of its own
    local sent = self:SentUntil()
    local serverHasFeed = sent and self:FeedFromServer("feed", "lifetime")
    local feedCut = serverHasFeed and PDI.DateKey(now - 8 * 86400) or dailyCut
    for dk in pairs(sv().feed) do if dk < feedCut then sv().feed[dk] = nil end end
    if serverHasFeed and sv().lifetime then sv().lifetime.feed = {} end
    local evDays = tonumber(sv().settings.killEventDays) or 7
    local evCut = PDI.DateKey(now - (evDays - 1) * 86400)
    for dk in pairs(sv().killEvents or {}) do if dk < evCut then sv().killEvents[dk] = nil end end
    -- kill events esopvp.com already has (from an upload it confirmed) are not needed here any more
    if sent then
        local cut = sent - 300
        for dk, list in pairs(sv().killEvents or {}) do
            if type(list) == "table" then
                local keep = {}
                for _, e in ipairs(list) do if type(e) == "table" and (tonumber(e.t) or 0) > cut then keep[#keep + 1] = e end end
                if #keep > 0 then sv().killEvents[dk] = keep else sv().killEvents[dk] = nil end
            end
        end
    end
    local ml = sv().mineLog
    if type(ml) == "table" and #ml > 100 then
        local keep = {}
        for i = #ml - 99, #ml do keep[#keep + 1] = ml[i] end
        sv().mineLog = keep
    end
    local nameCut = now - PDI.NAMEMAP_RETENTION_DAYS * 86400
    for char, e in pairs(sv().names) do
        if (e.t or 0) < nameCut then sv().names[char] = nil end
    end
    -- profiles: keep 14 days, at most 1500
    local pr = sv().profiles
    if pr then
        local cut = now - 14 * 86400
        local list = {}
        for who, e in pairs(pr) do
            if (e.t or 0) < cut then pr[who] = nil else list[#list + 1] = { who = who, t = e.t or 0 } end
        end
        if #list > 1500 then
            table.sort(list, function(a, b) return a.t < b.t end)
            for i = 1, #list - 1500 do pr[list[i].who] = nil end
        end
    end
end

-- One-time repair (1.9.41): a kill could also be counted as an assist on the same player. For the days
-- the kill feed log still has (7), an assist only stands if the kill feed shows someone else killing
-- that player that day; the extra assists are removed (also from Lifetime).
function Data:FixDoubleAssists()
    local me = PDI.NormalizeAccount(GetDisplayName())
    local removed = 0
    for dk, bucket in pairs(sv().my) do
        local events = sv().killEvents and sv().killEvents[dk]
        if type(events) == "table" and #events > 0 then
            for who, e in pairs(bucket) do
                if (e.k or 0) > 0 and (e.a or 0) > 0 then
                    local others = 0
                    for _, ev in ipairs(events) do
                        if not ev.duel and (ev.va == who or (e.c and ev.vc == e.c)) and ev.ka ~= me then
                            others = others + 1
                        end
                    end
                    local extra = (e.a or 0) - others
                    if extra > 0 then
                        e.a = e.a - extra
                        local left = extra
                        for _, x in pairs(e.ch or {}) do
                            local take = math.min(left, x.a or 0)
                            x.a = (x.a or 0) - take
                            left = left - take
                        end
                        local life = sv().lifetime.my[who]
                        if life then life.a = math.max(0, (life.a or 0) - extra) end
                        removed = removed + extra
                    end
                end
            end
        end
    end
    return removed
end

function Data:ResetSession()
    PDI.session = { my = {}, feed = {} }
end

-- Clear the counters of one tab ("my" | "feed") for one period, as shown in the window.
-- Day periods delete the daily buckets they cover; Lifetime clears everything for that tab.
function Data:ResetPeriod(kind, period)
    if period == "session" then PDI.session[kind] = {}; return end
    if period == "lifetime" then
        sv().lifetime[kind] = {}
        sv()[kind] = {}
        PDI.session[kind] = {}
        return
    end
    local buckets = sv()[kind]
    local now = PDI.Now()
    local today = PDI.DateKey(now)
    if period == "today" then
        buckets[today] = nil
    elseif period == "yesterday" then
        buckets[PDI.DateKey(now - 86400)] = nil
    elseif period == "week" then
        for i = 0, 6 do buckets[PDI.DateKey(now - i * 86400)] = nil end
    elseif period == "mtd" or period == "lastmonth" then
        local ym = (period == "mtd") and math.floor(today / 100) or prevMonth(today)
        for dk in pairs(buckets) do
            if math.floor(dk / 100) == ym then buckets[dk] = nil end
        end
    end
end

---------------------------------------------------------------------------
-- Following: one press of Follow keeps a daily snapshot of that player for as long as you follow them.
-- Every day you meet them (in combat, by targeting them, in your group) that day's snapshot is written
-- again with everything recorded so far that day, so it keeps growing during the day. Other players'
-- data about them arrives with esopvp.com's shared data (one entry per day, marked +).
---------------------------------------------------------------------------
Data.FOLLOW_DAYS = 30           -- automatic daily snapshots kept per player (the ones you saved by hand stay)

function Data:IsFollowed(who)
    return who ~= nil and sv().follows ~= nil and sv().follows[who] ~= nil
end

function Data:Follow(who)
    if not who then return end
    sv().follows = sv().follows or {}
    if not sv().follows[who] then sv().follows[who] = PDI.Now() end
    self:SyncFollows()
end

-- stops following and removes that player's snapshots (yours; other players' shared ones aren't stored)
function Data:Unfollow(who)
    if not who then return end
    if sv().follows then sv().follows[who] = nil end
    for id, e in pairs(sv().saved or {}) do if type(e) == "table" and e.who == who then sv().saved[id] = nil end end
    for id, e in pairs(sv().savedBuilds or {}) do if type(e) == "table" and e.who == who then sv().savedBuilds[id] = nil end end
end

-- the encounter-log capture of that day (gear and skill bars), as stored with a snapshot
local function logOfDay(who, dk)
    local b = PDI.Import and PDI.Import.builds and PDI.Import.builds[who]
    for i, v in ipairs(b and b.variants or {}) do
        if type(v) == "table" and v.seen and PDI.DateKey(v.seen) == dk then
            local snap = PDI.Import:Snapshot(who, i)
            if snap then
                snap = ZO_DeepTableCopy(snap)
                snap.count, snap.idx = 1, 1
                return snap
            end
        end
    end
    return nil
end

local function snapshot(store, id, entry, rec, dk)
    local copy = ZO_DeepTableCopy(rec)
    copy.log = logOfDay(entry.who, dk) or copy.log
    entry.rec, entry.auto = copy, true
    sv()[store][id] = entry
end

-- writes today's (and the kept days') snapshots of everyone you follow
function Data:SyncFollows()
    local follows = sv().follows
    if not follows or not next(follows) then return end
    local now = PDI.Now()
    for who, since in pairs(follows) do
        local fromDay = PDI.DateKey(math.min(tonumber(since) or now, now))
        -- in combat: the Opponents record of each day (7 days are kept there)
        for dk, bucket in pairs(sv().opponents or {}) do
            local rec = type(bucket) == "table" and bucket[who]
            if type(rec) == "table" and dk >= fromDay then
                snapshot("saved", "F|" .. who .. "|" .. dk, { who = who, date = dk, savedAt = rec.last or now }, rec, dk)
            end
        end
        -- by targeting them (friend or foe): their profile of that day
        local p = sv().profiles and sv().profiles[who]
        if type(p) == "table" and p.t then
            local dk = PDI.DateKey(p.t)
            if dk >= fromDay then
                snapshot("saved", "F|" .. who .. "|P|" .. dk, { who = who, date = dk, savedAt = p.t, kind = "player" }, p, dk)
            end
        end
        -- in your group: their group record of that day
        local g = sv().group and sv().group[who]
        if type(g) == "table" and g.last then
            local dk = PDI.DateKey(g.last)
            if dk >= fromDay then
                snapshot("savedBuilds", "F|" .. who .. "|" .. dk, { who = who, savedAt = g.last }, g, dk)
            end
        end
    end
end

-- automatic snapshots older than FOLLOW_DAYS go (the ones you saved yourself stay until you unfollow)
function Data:PruneFollows()
    local cut = PDI.DateKey(PDI.Now() - self.FOLLOW_DAYS * 86400)
    for id, e in pairs(sv().saved or {}) do
        if type(e) == "table" and e.auto and (e.date or 0) < cut then sv().saved[id] = nil end
    end
    for id, e in pairs(sv().savedBuilds or {}) do
        if type(e) == "table" and e.auto and PDI.DateKey(e.savedAt or 0) < cut then sv().savedBuilds[id] = nil end
    end
end

-- players saved before Following existed are followed from their first save on
function Data:MigrateFollows()
    sv().follows = sv().follows or {}
    if sv().settings.followsMigrated then return end
    local function add(who, t)
        if who and (not sv().follows[who] or (t and t < sv().follows[who])) then sv().follows[who] = t or PDI.Now() end
    end
    for _, e in pairs(sv().saved or {}) do if type(e) == "table" then add(e.who, e.savedAt) end end
    for _, e in pairs(sv().savedBuilds or {}) do if type(e) == "table" then add(e.who, e.savedAt) end end
    sv().settings.followsMigrated = true
end
