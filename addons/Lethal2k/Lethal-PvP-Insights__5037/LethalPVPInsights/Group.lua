-- Lethal PVP Insights - group history and builds
-- ESO does not let addons inspect another player's gear or skill bars. A "build" here is
-- what the game does expose: class, race, CP, role, max health, mundus, permanent buffs,
-- plus every skill/proc we observe the player using while grouped with you.
local PDI = PVPDataInsight
local Group = {}
PDI.Group = Group

local EM = EVENT_MANAGER
local NS = PDI.name .. "_Group"
local HEALTH = COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH

Group.current = {}      -- [@account] = true for members in your group right now
local charToAcct = {}   -- [charName] = @account (current roster)

local function sv() return PDI.sv end

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
-- what belongs to one character's build (kept per character in e.other when they switch)
local BUILD_FIELDS = { "char", "cls", "race", "raceId", "cp", "level", "role", "hp", "mundus", "buffs", "skills",
                       "buildSince", "last" }

local function freshBuild(e)
    e.hp, e.mundus, e.buffs, e.skills = 0, {}, {}, {}
    e.buildSince = PDI.Now()
end

function Group:Touch(acct, char)
    local g = sv().group
    local e = g[acct]
    local now = PDI.Now()
    if not e then
        e = { acct = acct, char = char, first = now, last = now, times = 1 }
        freshBuild(e)
        g[acct] = e
        self:EnforceCap()
    elseif char and e.char and char ~= e.char then
        -- another character of the same @account (maybe another class): keep the old character's build
        -- apart in e.other, and continue the new character's build from today if there is one
        e.other = e.other or {}
        local old = {}
        for _, k in ipairs(BUILD_FIELDS) do old[k] = e[k] end
        e.other[e.char] = old
        local back = e.other[char]
        e.other[char] = nil
        if back and PDI.DateKey(back.last or 0) == PDI.DateKey(now) then
            for _, k in ipairs(BUILD_FIELDS) do e[k] = back[k] end
        else
            freshBuild(e)
            e.cls = PDI.Data:ClassOf(char)
            e.race, e.raceId, e.cp, e.role, e.level = nil, nil, nil, nil, nil
        end
        for ch, o in pairs(e.other) do      -- other characters' builds are kept a week
            if now - (o.last or 0) > 7 * 86400 then e.other[ch] = nil end
        end
        e.times = (e.times or 0) + 1
    elseif not self.current[acct] then
        -- first scan of them since a regroup / reload / zoning
        local gap = now - (e.last or 0)
        -- a new day starts a new build too (only the same day's data is combined)
        if (PDI.BUILD_SPLIT_SEC and gap > PDI.BUILD_SPLIT_SEC) or PDI.DateKey(e.buildSince or e.last or now) ~= PDI.DateKey(now) then
            freshBuild(e)
        end
        if gap > 300 then e.times = (e.times or 0) + 1 end
    end
    e.char = char or e.char
    e.last = now
    return e
end

-- Used by the encounter-log import: make sure an entry exists without counting a regroup
function Group:EnsureEntry(acct, char, ts)
    local g = sv().group
    local e = g[acct]
    if e then return e, false end
    ts = ts or PDI.Now()
    e = { acct = acct, char = char, first = ts, last = ts, times = 1, source = "log" }
    freshBuild(e)
    e.buildSince = ts
    g[acct] = e
    return e, true
end

-- Clears the Group tab: history, gear imported from the encounter log and capture bookkeeping.
-- Saved builds (Builds tab) are kept. People in your group right now reappear at the next scan.
function Group:ClearHistory()
    local now = PDI.Now()
    sv().group = {}
    sv().logCoverage = {}
    sv().settings.groupClearedAt = now
    self.current = {}
    PDI.Import:ForgetBefore(now)
    if PDI.LogAssist then PDI.LogAssist.lastCycleEnd = 0 end
    PDI.Msg("Group history cleared (saved builds were kept).")
end

-- Removes one player from the Group tab together with their imported gear. Saved builds are kept.
-- Someone still in your group comes back at the next roster scan.
function Group:RemoveEntry(acct)
    if not acct then return end
    sv().group[acct] = nil
    sv().groupRemoved = sv().groupRemoved or {}
    sv().groupRemoved[acct] = PDI.Now()
    if sv().logCoverage then sv().logCoverage[acct] = nil end
    self.current[acct] = nil
    PDI.Import:Forget(acct)
end

function Group:EnforceCap()
    local g = sv().group
    local list = {}
    for acct, e in pairs(g) do list[#list + 1] = { acct = acct, last = e.last or 0 } end
    if #list <= PDI.GROUP_HISTORY_MAX then return end
    table.sort(list, function(a, b) return a.last < b.last end)
    for i = 1, #list - PDI.GROUP_HISTORY_MAX do
        if not self.current[list[i].acct] then g[list[i].acct] = nil end
    end
end

local function recordSkill(e, abilityId, abilityName, ty, value)
    local name = PDI.CleanName(abilityName)
    if (not name) and abilityId and abilityId > 0 then name = PDI.CleanName(GetAbilityName(abilityId)) end
    if not name then return end
    local key = string.lower(name)
    local s = e.skills[key]
    if not s then
        s = { n = name, id = abilityId, h = 0, m = 0, total = 0, ty = {} }
        e.skills[key] = s
    end
    s.h = s.h + 1
    value = value or 0
    if value > s.m then s.m = value end
    s.total = s.total + value
    s.ty[ty] = true
end

-- fp = fingerprint of the data being saved, so the same data shows "Unsave" instead of "Save"
function Group:FindSaved(acct, fp)
    if not fp then return nil end
    for id, b in pairs(sv().savedBuilds) do
        if b.who == acct and b.fp == fp then return id end
    end
    return nil
end

function Group:SaveBuild(acct, rec, logSnap, fp)
    local now = PDI.Now()
    local id = acct .. "|" .. now
    local copy = ZO_DeepTableCopy(rec)
    copy.log = logSnap and ZO_DeepTableCopy(logSnap) or nil
    if copy.log then copy.log.count, copy.log.idx = 1, 1 end
    sv().savedBuilds[id] = { who = acct, savedAt = now, rec = copy, fp = fp }
    return id
end

function Group:DeleteBuild(id) sv().savedBuilds[id] = nil end

function Group:CountSaved(acct)
    local n = 0
    for _, b in pairs(sv().savedBuilds) do if b.who == acct then n = n + 1 end end
    return n
end

---------------------------------------------------------------------------
-- Roster scan
---------------------------------------------------------------------------
local function scanBuffs(tag, e)
    for i = 1, GetNumBuffs(tag) do
        local buffName, timeStarted, timeEnding, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo(tag, i)
        local m = PDI.MUNDUS_IDS[abilityId]
        if not m and buffName and buffName:find("^Boon") then
            m = zo_strformat("<<1>>", buffName):gsub("^Boon:%s*", "")
        end
        if m then
            e.mundus[m] = true
        elseif buffName and buffName ~= "" and (timeEnding or 0) - (timeStarted or 0) <= 0 then
            -- permanent effects: passives, set bonuses that show as buffs, toggles
            e.buffs[PDI.CleanName(buffName) or buffName] = abilityId or true
        end
    end
end

function Group:Scan()
    local seen = {}
    if PDI.ShouldTrackGroup() and IsUnitGrouped("player") then
        for i = 1, GetGroupSize() do
            local tag = GetGroupUnitTagByIndex(i)
            if tag and DoesUnitExist(tag) and not AreUnitsEqual(tag, "player") then
                local acct = PDI.NormalizeAccount(GetUnitDisplayName(tag))
                local char = PDI.CleanName(GetUnitName(tag))
                if acct then
                    local e = self:Touch(acct, char)
                    seen[acct] = true
                    self.current[acct] = true
                    if char then charToAcct[char] = acct; PDI.Data:LearnName(char, acct, GetUnitAlliance(tag)) end
                    if IsUnitOnline(tag) then
                        local v
                        v = GetUnitClassId(tag);         if v and v ~= 0 then e.cls = v; PDI.Data:NoteClass(char, v) end
                        v = GetUnitAlliance(tag);        if v and v ~= 0 then e.al = v end
                        v = GetUnitRace(tag);            if v and v ~= "" then e.race = zo_strformat("<<1>>", v) end
                        v = GetUnitRaceId and GetUnitRaceId(tag); if v and v ~= 0 then e.raceId = v end
                        v = GetUnitChampionPoints(tag);  if v and v > 0 then e.cp = v end
                        v = GetUnitLevel(tag);           if v and v > 0 then e.level = v end
                        v = GetGroupMemberSelectedRole and GetGroupMemberSelectedRole(tag)
                        if v and v ~= 0 then e.role = v end
                        local inRange = not IsUnitInGroupSupportRange or IsUnitInGroupSupportRange(tag)
                        if inRange then
                            local _, maxHp = GetUnitPower(tag, HEALTH)
                            if maxHp and maxHp > (e.hp or 0) then e.hp = maxHp end
                            scanBuffs(tag, e)
                        end
                        e.zone = zo_strformat("<<1>>", GetUnitZone(tag) or "")
                    end
                end
            end
        end
    end
    for acct in pairs(self.current) do
        if not seen[acct] then self.current[acct] = nil end
    end
    if PDI.UI and PDI.UI.tab == "group" then PDI.UI:RefreshIfVisible() end
end

local function scanSoon()
    zo_callLater(function() Group:Scan() end, 1000)
end

---------------------------------------------------------------------------
-- Observed skills (combat events from group members)
---------------------------------------------------------------------------
local RESULT_TYPE = {}
local function map(list, ty) for _, r in ipairs(list) do if r then RESULT_TYPE[r] = ty end end end
map({ ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE, ACTION_RESULT_BLOCKED_DAMAGE,
      ACTION_RESULT_DAMAGE_SHIELDED, ACTION_RESULT_KILLING_BLOW }, "dmg")
map({ ACTION_RESULT_DOT_TICK, ACTION_RESULT_DOT_TICK_CRITICAL }, "dot")
map({ ACTION_RESULT_HEAL, ACTION_RESULT_CRITICAL_HEAL, ACTION_RESULT_HOT_TICK, ACTION_RESULT_HOT_TICK_CRITICAL }, "heal")
map({ ACTION_RESULT_EFFECT_GAINED, ACTION_RESULT_EFFECT_GAINED_DURATION }, "eff")

local function OnGroupCombat(_, result, isError, abilityName, _, _, sourceName, sourceType,
                             targetName, targetType, hitValue, _, _, _, _, _, abilityId)
    if isError then return end
    local ty = RESULT_TYPE[result]
    if not ty then return end
    local char = PDI.CleanName(sourceName)
    local acct = char and charToAcct[char]
    if not acct or not Group.current[acct] then return end
    local e = sv().group[acct]
    if e then recordSkill(e, abilityId, abilityName, ty, hitValue) end
end

---------------------------------------------------------------------------
function Group:Init()
    EM:RegisterForEvent(NS .. "Joined", EVENT_GROUP_MEMBER_JOINED, scanSoon)
    EM:RegisterForEvent(NS .. "Left", EVENT_GROUP_MEMBER_LEFT, scanSoon)
    EM:RegisterForEvent(NS .. "Update", EVENT_GROUP_UPDATE, scanSoon)
    if EVENT_GROUP_MEMBER_ROLE_CHANGED then
        EM:RegisterForEvent(NS .. "Role", EVENT_GROUP_MEMBER_ROLE_CHANGED, scanSoon)
    end
    EM:RegisterForEvent(NS .. "Activated", EVENT_PLAYER_ACTIVATED, scanSoon)

    EM:RegisterForEvent(NS .. "Combat", EVENT_COMBAT_EVENT, OnGroupCombat)
    EM:AddFilterForEvent(NS .. "Combat", EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_GROUP)

    -- periodic rescan picks up health/buff/role changes while grouped
    EM:RegisterForUpdate(NS .. "Scan", 15000, function()
        if IsUnitGrouped("player") or next(Group.current) then Group:Scan() end
    end)
    self:EnforceCap()
end
