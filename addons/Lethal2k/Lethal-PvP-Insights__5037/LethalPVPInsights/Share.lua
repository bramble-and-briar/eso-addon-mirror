-- Lethal PVP Insights - data sharing preferences (for the shared database that comes later).
-- Nothing is uploaded by the addon itself; these settings are stored with the saved data so a future
-- uploader can filter by them. Opponents' combat data is always shared.
local PDI = PVPDataInsight
local Share = {}
PDI.Share = Share

Share.MAX_GUILDS = 5
Share.MODES = { "all", "faction", "guild", "friends", "none" }
Share.MODE_LABELS = { "All", "Your Faction", "Guild Members", "Friends", "None" }
Share.CATEGORIES = {
    { key = "groupBuilds", label = "Share Group Builds", default = "friends",
      tooltip = "Builds of players you grouped with (Group tab), including gear imported from the encounter log." },
    { key = "savedBuilds", label = "Share Followed Players", default = "friends",
      tooltip = "Players you follow (Following tab)." },
    { key = "friendly", label = "Share Friendly Players", default = "faction",
      tooltip = "What you recorded when targeting players of your own alliance (buffs, mundus, class, health)." },
}

local DEFAULTS = {}
for _, c in ipairs(Share.CATEGORIES) do DEFAULTS[c.key] = c.default end

-- settings.share[key] = { mode = "friends", guilds = { [guildId] = true }, chosen = true }
-- `chosen` marks a mode the player picked; until then the category follows the default
-- (Friendly Players: Your Faction; Group and Saved Builds: Friends).
function Share:Get(key)
    local st = PDI.sv.settings
    st.share = st.share or {}
    local e = st.share[key]
    if type(e) ~= "table" then e = { guilds = {} }; st.share[key] = e end
    if not e.chosen then e.mode = DEFAULTS[key] or "none" end
    e.mode = e.mode or "none"
    e.guilds = e.guilds or {}
    return e
end

function Share:SetMode(key, mode)
    local e = self:Get(key)
    e.mode = mode
    e.chosen = true
end

function Share:GuildAt(slot)
    if not (GetNumGuilds and GetGuildId and GetGuildName) then return nil end
    if slot > GetNumGuilds() then return nil end
    local id = GetGuildId(slot)
    if not id or id == 0 then return nil end
    return { id = id, name = GetGuildName(id) }
end

local function inGuild(guildId, acct)
    if not (GetNumGuildMembers and GetGuildMemberInfo) then return false end
    for i = 1, GetNumGuildMembers(guildId) do
        local name = GetGuildMemberInfo(guildId, i)
        if name == acct then return true end
    end
    return false
end

local function isFriend(acct)
    if IsFriend then return IsFriend(acct) == true end
    return false
end

-- May data of kind `key` about player `acct` (alliance `al`) be shared?
function Share:Allows(key, acct, al)
    local e = self:Get(key)
    if e.mode == "all" then return true end
    if e.mode == "none" or not acct then return false end
    if e.mode == "faction" then return al ~= nil and al == GetUnitAlliance("player") end
    if e.mode == "friends" then return isFriend(acct) end
    if e.mode == "guild" then
        for gid in pairs(e.guilds) do
            if inGuild(gid, acct) then return true end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Who is uploading: the LPI Companion sends this file to esopvp.com (only after you agreed in the
-- Companion). The server needs your alliance per character (for "Your Faction"), your guild names
-- (for "Guild Members") and your friends list (for "Friends"); it stores friends only as hashes.
---------------------------------------------------------------------------
Share.SESSIONS_MAX = 300

local function cleanName(s) return s and PDI.CleanName(s) or nil end

function Share:RecordMe()
    local sv = PDI.sv
    local me = sv.me or {}
    sv.me = me
    me.ver = PDI.version
    me.world = GetWorldName and GetWorldName() or me.world
    me.acct = PDI.NormalizeAccount(GetDisplayName())
    me.char = cleanName(GetUnitName("player"))
    me.al = GetUnitAlliance("player")
    me.cls = GetUnitClassId and GetUnitClassId("player") or nil
    me.t = PDI.Now()
    me.epoch = tonumber(sv.dataEpoch) or 0
    me.resetSeen = tonumber(sv.resetSeen) or nil    -- the esopvp.com data reset already applied here
    -- character sessions: which character (and alliance) was played from when
    me.sessions = me.sessions or {}
    local last = me.sessions[#me.sessions]
    if not last or last.char ~= me.char or last.al ~= me.al or last.world ~= me.world then
        me.sessions[#me.sessions + 1] = { t = me.t, char = me.char, al = me.al, world = me.world }
        while #me.sessions > self.SESSIONS_MAX do table.remove(me.sessions, 1) end
    end
    -- guild names (by guild id) and friends
    me.guilds = {}
    if GetNumGuilds and GetGuildId and GetGuildName then
        for i = 1, GetNumGuilds() do
            local id = GetGuildId(i)
            if id and id ~= 0 then me.guilds[id] = GetGuildName(id) end
        end
    end
    if GetNumFriends and GetFriendInfo then
        me.friends = {}
        for i = 1, GetNumFriends() do
            local name = GetFriendInfo(i)
            if name and name ~= "" then me.friends[#me.friends + 1] = PDI.NormalizeAccount(name) end
        end
    end
    self:CacheSetNames()
    zo_callLater(function() self:CacheCategories() end, 5000)
end

-- Set names for the gear imported from the encounter log (the website shows names, not set ids)
local function setName(id)
    local ok, name = false, nil
    if GetItemSetName then ok, name = pcall(GetItemSetName, id) end
    if (not ok or not name or name == "") and GetItemSetInfo then ok, name = pcall(GetItemSetInfo, id) end
    if ok and type(name) == "string" and name ~= "" then return zo_strformat("<<1>>", name) end
    return nil
end

function Share:CacheSetNames()
    local sv = PDI.sv
    sv.setNames = sv.setNames or {}
    -- also writes what each item is (g.it: "Inferno Staff", "Heavy Chest") for the website's Item column;
    -- returns true when it added any, so that build is sent again
    local function scan(build)
        if type(build) ~= "table" then return false end
        local added = false
        for _, v in pairs(build.variants or {}) do
            for _, g in pairs(type(v) == "table" and v.gear or {}) do
                local id = type(g) == "table" and tonumber(g.set) or nil
                if id and id > 0 and not sv.setNames[id] then sv.setNames[id] = setName(id) end
                if type(g) == "table" and not g.it and tonumber(g.item) then
                    local ok, it = pcall(PDI.Import.ItemType, tonumber(g.item))
                    if ok and it then g.it = it; added = true end
                end
            end
        end
        return added
    end
    for _, e in pairs(sv.importedBuilds or {}) do
        if type(e) == "table" and scan(e.build) then e.storedAt = PDI.Now() end
    end
    for _, e in pairs(sv.savedBuilds or {}) do scan(type(e) == "table" and e.rec and e.rec.log) end
    for _, e in pairs(sv.saved or {}) do scan(type(e) == "table" and e.rec and e.rec.log) end
    pcall(self.CacheDescriptions, self)
end

-- Full descriptions of the skills and sets seen (the website shows them when hovering a skill or a set).
-- Built a little at a time, once per game update; sent with the data like the set names.
local DESC_MAX, DESC_STEP = 4000, 150
function Share:CacheDescriptions()
    local sv = PDI.sv
    local api = GetAPIVersion and GetAPIVersion() or 0
    if type(sv.descs) ~= "table" or sv.descs.api ~= api then sv.descs = { api = api, a = {}, s = {} } end
    local D = sv.descs
    local abil, sets = {}, {}
    local function addA(id) id = tonumber(id); if id and id > 0 and D.a[id] == nil then abil[id] = true end end
    local function scanLog(build)
        if type(build) ~= "table" then return end
        for _, v in pairs(build.variants or {}) do
            if type(v) == "table" then
                for _, id in pairs(v.bar1 or {}) do addA(id) end
                for _, id in pairs(v.bar2 or {}) do addA(id) end
                for _, g in pairs(v.gear or {}) do
                    local sid = type(g) == "table" and tonumber(g.set)
                    if sid and sid > 0 and D.s[sid] == nil and tonumber(g.item) then sets[sid] = tonumber(g.item) end
                end
            end
        end
    end
    local function scanRec(rec)
        if type(rec) ~= "table" then return end
        for _, sk in pairs(rec.skills or {}) do if type(sk) == "table" then addA(sk.id) end end
        for _, b in pairs(rec.buffs or {}) do addA(type(b) == "table" and b.id or b) end
        for _, o in pairs(rec.other or {}) do if type(o) == "table" then scanRec(o) end end
        scanLog(rec.log)
    end
    for _, e in pairs(sv.importedBuilds or {}) do scanLog(type(e) == "table" and e.build) end
    for _, day in pairs(sv.opponents or {}) do for _, r in pairs(type(day) == "table" and day or {}) do scanRec(r) end end
    for _, r in pairs(sv.group or {}) do scanRec(r) end
    for _, r in pairs(sv.profiles or {}) do scanRec(r) end
    for _, e in pairs(sv.saved or {}) do scanRec(type(e) == "table" and e.rec) end
    for _, e in pairs(sv.savedBuilds or {}) do scanRec(type(e) == "table" and e.rec) end

    local todoA, todoS = {}, {}
    for id in pairs(abil) do todoA[#todoA + 1] = id end
    for sid, item in pairs(sets) do todoS[#todoS + 1] = { sid, item } end
    local count = 0
    for _ in pairs(D.a) do count = count + 1 end
    local i, j = 1, 1
    local function step()
        local n = 0
        while j <= #todoS and n < DESC_STEP do
            local sid, item = todoS[j][1], todoS[j][2]
            local link = PDI.Import.ItemLink(item)
            local lines = {}
            local ok, hasSet, _, numBonuses = pcall(GetItemLinkSetInfo, link, false)
            if ok and hasSet then
                for b = 1, numBonuses or 0 do
                    local ok2, _, desc = pcall(GetItemLinkSetBonusInfo, link, false, b)
                    if ok2 and type(desc) == "string" and desc ~= "" then lines[#lines + 1] = zo_strformat("<<1>>", desc) end
                end
            end
            D.s[sid] = #lines > 0 and table.concat(lines, "\n") or false
            j, n = j + 1, n + 1
        end
        while i <= #todoA and n < DESC_STEP and count < DESC_MAX do
            local id = todoA[i]
            local ok, desc = pcall(GetAbilityDescription, id)
            D.a[id] = (ok and type(desc) == "string" and desc ~= "") and zo_strformat("<<1>>", desc) or false
            count = count + 1
            i, n = i + 1, n + 1
        end
        if j <= #todoS or (i <= #todoA and count < DESC_MAX) then zo_callLater(step, 200) end
    end
    zo_callLater(step, 8000)
end

-- What the Companion last reported (LPI_Companion.lua, read at UI load)
function Share:UploadInfo()
    local c = PVPDataInsight_Companion or {}
    local up = type(c.upload) == "table" and c.upload or nil
    return c.identifier, up
end

---------------------------------------------------------------------------
-- Clear local data after it reached esopvp.com. Everything stays on the server (saved builds too).
-- 1. The button stores a token and reloads: the game saves the file with the token in it.
-- 2. The Companion uploads that file; the server answers with the token, and the Companion writes
--    it into LPI_Companion.lua ("uploaded").
-- 3. At a later UI load the addon sees its token there and only then clears the local data.
---------------------------------------------------------------------------
-- saved builds ("saved", "savedBuilds") are kept
Share.CLEAR_KEYS = { "my", "feed", "opponents", "group", "profiles",
                     "importedBuilds", "killEvents", "logCoverage", "groupRemoved" }

function Share:RequestClearAfterUpload()
    local c = PVPDataInsight_Companion or {}
    if not c.identifier then
        PDI.Msg("Clearing after upload needs the LPI Companion with \"Upload to esopvp.com\" switched on.")
        return false
    end
    PDI.sv.wipePending = { token = PDI.Now() }
    PDI.Msg("Saving and uploading your data first - the UI reloads now.")
    zo_callLater(function() ReloadUI("ingame") end, 300)
    return true
end

function Share:CancelClear()
    PDI.sv.wipePending = nil
    PDI.Msg("Clearing local data was cancelled.")
end

function Share:ClearLocal()
    local sv = PDI.sv
    for _, k in ipairs(self.CLEAR_KEYS) do sv[k] = {} end
    sv.lifetime = { my = {}, feed = {} }
    sv.dataEpoch = (tonumber(sv.dataEpoch) or 0) + 1
    if sv.me then sv.me.epoch = sv.dataEpoch end
    sv.settings.groupClearedAt = PDI.Now()     -- gear imported from the encounter log before now is ignored
    if PDI.Import and PDI.Import.builds then PDI.Import:ForgetBefore(sv.settings.groupClearedAt) end
    PDI.Data:ResetSession()
    sv.wipePending = nil
end

-- esopvp.com was reset (all data deleted): start from scratch here too, saved builds included.
-- Settings, right-click type choices and the Companion's registration are kept.
function Share:ResetAll(t)
    local sv = PDI.sv
    self:ClearLocal()
    sv.saved, sv.savedBuilds, sv.follows = {}, {}, {}
    sv.sharedKept, sv.names, sv.mineLog = {}, {}, {}
    sv.importedBuilds, sv.captureStarts = {}, {}
    sv.resetSeen = t
    if sv.me then sv.me.resetSeen = t end
end

-- Called once at UI load
function Share:CheckPendingClear()
    local comp = PVPDataInsight_Companion or {}
    -- esopvp.com data reset (the Companion passes it on after an upload)
    local rs = tonumber(comp.reset)
    if rs and rs > (tonumber(PDI.sv.resetSeen) or 0) then
        self:ResetAll(rs)
        PDI.sv.clearSeen = math.max(tonumber(PDI.sv.clearSeen) or 0, tonumber(comp.clear) or 0)
        zo_callLater(function()
            PDI.Msg("esopvp.com was reset: all collected data on this PC was cleared too (saved builds included). " ..
                    "Settings are kept.")
            if PDI.UI and PDI.UI.RefreshIfVisible then PDI.UI:RefreshIfVisible() end
        end, 2000)
        return
    end
    -- "Clear collected data" in the Companion
    local req = tonumber(comp.clear)
    if req and req > (tonumber(PDI.sv.clearSeen) or 0) then
        PDI.sv.clearSeen = req
        self:ClearLocal()
        zo_callLater(function()
            PDI.Msg("Collected data cleared (asked in the LPI Companion). Saved builds and settings are kept.")
            if PDI.UI and PDI.UI.RefreshIfVisible then PDI.UI:RefreshIfVisible() end
        end, 2000)
        return
    end
    local wp = PDI.sv.wipePending
    if type(wp) ~= "table" or not wp.token then return end
    local c = PVPDataInsight_Companion or {}
    local me = PDI.NormalizeAccount(GetDisplayName())
    local done = type(c.uploaded) == "table" and tonumber(c.uploaded[me]) == wp.token
    if done then
        self:ClearLocal()
        zo_callLater(function()
            PDI.Msg("Local data cleared. Everything you uploaded stays on esopvp.com.")
            if PDI.UI and PDI.UI.RefreshIfVisible then PDI.UI:RefreshIfVisible() end
        end, 2000)
    else
        zo_callLater(function()
            PDI.Msg("Clearing local data is waiting for the upload to esopvp.com. Wait ~10 seconds, then type " ..
                "/reloadui (it finishes then). |cFFFFFF/pvpdi clearlocal cancel|r stops it.")
        end, 2000)
    end
end

---------------------------------------------------------------------------
-- Categories for esopvp.com: the website shows skills and buffs with the same types (and colours)
-- as this addon, including your right-click corrections. Classifying needs the game's skill data,
-- so it's done here, a few names per frame, and saved as sv.catCache = { s = {...}, b = {...} }.
---------------------------------------------------------------------------
local CAT_BATCH = 40
Share.CAT_VERSION = 8      -- bump when Skills.lua's lists change, so every name is classified again

function Share:CacheCategories()
    local sv = PDI.sv
    sv.catCache = sv.catCache or {}
    if sv.catCache.ver ~= self.CAT_VERSION then sv.catCache = { ver = self.CAT_VERSION } end
    local cache = sv.catCache
    cache.s = cache.s or {}
    cache.b = cache.b or {}
    -- right-click corrections always win
    for k, v in pairs(sv.skillCat or {}) do cache.s[k] = v end
    for k, v in pairs(sv.buffCat or {}) do cache.b[k] = v end
    local todo = {}
    local function addSkills(skills)
        for _, sk in pairs(type(skills) == "table" and skills or {}) do
            local key = type(sk) == "table" and sk.n and string.lower(sk.n)
            if key and not cache.s[key] and not todo["s" .. key] then todo["s" .. key] = { "s", key, sk } end
        end
    end
    local function addBuffs(buffs)
        for name, b in pairs(type(buffs) == "table" and buffs or {}) do
            local key = string.lower(name)
            if not cache.b[key] and not todo["b" .. key] then
                todo["b" .. key] = { "b", key, { name = name, id = type(b) == "table" and b.id or b,
                                                 perm = type(b) == "table" and b.perm or nil } }
            end
        end
    end
    for _, day in pairs(sv.opponents or {}) do for _, rec in pairs(day) do addSkills(rec.skills) end end
    for _, e in pairs(sv.saved or {}) do if e.rec then addSkills(e.rec.skills); addBuffs(e.rec.buffs) end end
    for _, rec in pairs(sv.profiles or {}) do addBuffs(rec.buffs) end
    for _, rec in pairs(sv.group or {}) do if type(rec) == "table" then addSkills(rec.skills); addBuffs(rec.buffs) end end
    for _, e in pairs(sv.savedBuilds or {}) do if e.rec then addSkills(e.rec.skills); addBuffs(e.rec.buffs) end end
    -- the game's own skill / passive / set names (once per version and game update)
    local api = GetAPIVersion and GetAPIVersion() or 0
    if cache.gApi ~= api or not cache.g then
        local ok, names = pcall(PDI.Skills.GameNames, PDI.Skills)
        if ok and next(names) then cache.g = names; cache.gApi = api end
    end

    local list = {}
    for _, item in pairs(todo) do list[#list + 1] = item end
    if #list == 0 then return end
    local i = 0
    EVENT_MANAGER:UnregisterForUpdate(PDI.name .. "CatCache")
    EVENT_MANAGER:RegisterForUpdate(PDI.name .. "CatCache", 50, function()
        for _ = 1, CAT_BATCH do
            i = i + 1
            local it = list[i]
            if not it then
                EVENT_MANAGER:UnregisterForUpdate(PDI.name .. "CatCache")
                return
            end
            local ok, cat = pcall(function()
                if it[1] == "s" then return PDI.Skills:Classify(it[3]) end
                return (PDI.Skills:ClassifyBuff(it[3].name, it[3].id, it[3].perm))
            end)
            if ok and cat then cache[it[1]][it[2]] = cat end
        end
    end)
end

---------------------------------------------------------------------------
-- Data shared by other players (LPI_Shared.lua, downloaded by the Companion from
-- esopvp.com after each upload; read at /reloadui). One combined profile per player:
--   { c, cls, al, race, cp, hp, role, t, up = uploaders, mundus = {..}, sk = {{n,id,h,ty}}, bf = {[name]={id,perm}},
--     v = {gear, bar1, bar2, effects, zone, seen}, names = {[abilityId] = name} }
-- Players you saved a build of keep everything that was ever shared about them (sv.sharedKept), so a
-- newer download that no longer lists them loses nothing.
---------------------------------------------------------------------------
local function mergeProfile(dst, src)
    if type(src) ~= "table" then return dst end
    dst = dst or {}
    local newer = (src.t or 0) >= (dst.t or 0)
    -- another character of the same @account, or another day (builds change): keep only the newest
    local otherDay = dst.t and src.t and PDI.DateKey(dst.t) ~= PDI.DateKey(src.t)
    if (dst.c and src.c and dst.c ~= src.c) or (dst.cls and src.cls and dst.cls ~= src.cls) or otherDay then
        if not newer then return dst end
        dst = {}
    end
    for _, k in ipairs({ "c", "cls", "al", "race", "cp", "hp", "role" }) do
        if src[k] ~= nil and (dst[k] == nil or newer) then dst[k] = src[k] end
    end
    dst.t = math.max(dst.t or 0, src.t or 0)
    dst.up = math.max(dst.up or 0, src.up or 0)
    -- skills: by name, keep the highest hit count
    local byName = {}
    for i, s in ipairs(dst.sk or {}) do byName[string.lower(s.n or "")] = i end
    dst.sk = dst.sk or {}
    for _, s in ipairs(src.sk or {}) do
        local key = string.lower(s.n or "")
        local i = byName[key]
        if not i then
            dst.sk[#dst.sk + 1] = s
            byName[key] = #dst.sk
        elseif (s.h or 0) > (dst.sk[i].h or 0) then
            dst.sk[i] = s
        end
    end
    dst.bf = dst.bf or {}
    for n, b in pairs(src.bf or {}) do if dst.bf[n] == nil then dst.bf[n] = b end end
    local m = {}
    for _, x in ipairs(dst.mundus or {}) do m[x] = true end
    for _, x in ipairs(src.mundus or {}) do m[x] = true end
    dst.mundus = {}
    for x in pairs(m) do dst.mundus[#dst.mundus + 1] = x end
    table.sort(dst.mundus)
    -- gear and bars: the newest capture
    if src.v and (not dst.v or (src.v.seen or 0) >= (dst.v.seen or 0)) then
        dst.v = src.v
        dst.names = src.names
    end
    return dst
end

function Share:KeepSaved()
    local sv = PDI.sv
    sv.sharedKept = sv.sharedKept or {}
    local shared = (PVPDataInsight_Shared and PVPDataInsight_Shared.players) or {}
    local savedWho = {}
    for _, e in pairs(sv.saved or {}) do if type(e) == "table" and e.who then savedWho[e.who] = true end end
    for _, e in pairs(sv.savedBuilds or {}) do if type(e) == "table" and e.who then savedWho[e.who] = true end end
    for who in pairs(sv.follows or {}) do savedWho[who] = true end
    for who in pairs(savedWho) do
        if shared[who] then sv.sharedKept[who] = mergeProfile(sv.sharedKept[who], shared[who]) end
    end
    for who in pairs(sv.sharedKept) do if not savedWho[who] then sv.sharedKept[who] = nil end end
end

-- The shared profile of a player: what the last download says, plus what was kept for saved players
function Share:Shared(who, cls)
    if not who then return nil end
    local S = PVPDataInsight_Shared or {}
    local cur = S.players and S.players[who]
    -- one profile per class: players[who] is their newest class, byClass[who][cls] the others
    if cls and cls ~= 0 and cur and cur.cls and cur.cls ~= cls then
        cur = S.byClass and S.byClass[who] and S.byClass[who][cls] or nil
    end
    local kept = PDI.sv.sharedKept and PDI.sv.sharedKept[who]
    if kept and cls and cls ~= 0 and kept.cls and kept.cls ~= cls then kept = nil end
    if not kept then return cur end
    if not cur then return kept end
    return mergeProfile(mergeProfile({}, kept), cur)
end

-- Builds other players saved and share with you: kinds "enemy", "player", "group"
function Share:SharedSaved(...)
    local want = {}
    for _, k in ipairs({ ... }) do want[k] = true end
    local out = {}
    local list = PVPDataInsight_Shared and PVPDataInsight_Shared.saved
    for _, w in ipairs(type(list) == "table" and list or {}) do
        if type(w) == "table" and want[w.kind] and w.who then out[#out + 1] = w end
    end
    return out
end

-- A newer addon on esopvp.com (the Companion brings the newest version number with the shared data)
local function verParts(v)
    local t = {}
    for n in tostring(v or ""):gmatch("%d+") do t[#t + 1] = tonumber(n) end
    return t
end
function Share:NewerAddon()
    local s = PVPDataInsight_Shared
    local latest = type(s) == "table" and s.latestAddon
    if type(latest) ~= "string" or latest == "" then return nil end
    local a, b = verParts(latest), verParts(PDI.version)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x > y and latest or nil end
    end
    return nil
end

-- Former @account names of a player (renamed accounts): seen by you, or by other uploaders
function Share:FormerAccounts(acct)
    if not acct then return nil end
    local list, seen = {}, {}
    local function add(a) if a and a ~= acct and not seen[a] then seen[a] = true; list[#list + 1] = a end end
    for a in pairs((PDI.sv.formerAccts or {})[acct] or {}) do add(a) end
    local s = PVPDataInsight_Shared
    for _, a in ipairs(type(s) == "table" and type(s.renamed) == "table" and s.renamed[acct] or {}) do add(a) end
    table.sort(list)
    return #list > 0 and list or nil
end

function Share:SharedInfo()
    local s = PVPDataInsight_Shared
    if type(s) ~= "table" or not s.generated or s.generated == 0 then return nil end
    local n = 0
    for _ in pairs(s.players or {}) do n = n + 1 end
    return s.generated, n
end
