-- Group members (trigger "Group members", 5.23.0): one entry per member of your group -- offline and dead ones too --
-- and their companions, with everything a group frame shows: health, damage shield, trauma, "can't be healed", role,
-- class, leader, dead / being resurrected / waiting to accept a resurrection / ghost, online, in support range.
--
-- Read on demand every update, like resources (the engine evaluates ~10x a second; every call here is a cheap read
-- of the game's own unit data), so nothing is listened to. Shown by the "Group frames" display (Display/Frames.lua),
-- or by any other display (bars of the group's health, icons of who's dead...). Rules see all of it.
--
-- The game's own reads, as its unit frames and group list use them (esoui unitframes.lua, zo_grouplist_keyboard.lua,
-- playertoplayer.lua): IsUnitOnline, IsUnitDead, IsUnitGroupLeader, IsUnitInGroupSupportRange,
-- GetGroupMemberSelectedRole (yours: GetSelectedLFGRole), IsUnitBeingResurrected, DoesUnitHaveResurrectPending,
-- ZO_GetClassIcon(classId), GetCompanionUnitTagByGroupUnitTag.

local DT = DebuffTracker
local Grp = DT.Group
local U = DT.Util

local ROLE_RANK = { tank = 1, healer = 2, dps = 3, [""] = 4 }
Grp.ROLE_RANK = ROLE_RANK

local function Fn(name) local f = rawget(_G, name); return type(f) == "function" and f or nil end

local function RoleOf(tag)
    local id
    if tag == "player" or (type(AreUnitsEqual) == "function" and AreUnitsEqual(tag, "player")) then
        local f = Fn("GetSelectedLFGRole")
        id = f and f()
    else
        local f = Fn("GetGroupMemberSelectedRole")
        id = f and f(tag)
    end
    if id == nil then return "", nil end
    if LFG_ROLE_TANK and id == LFG_ROLE_TANK then return "tank", id end
    if LFG_ROLE_HEAL and id == LFG_ROLE_HEAL then return "healer", id end
    if LFG_ROLE_DPS and id == LFG_ROLE_DPS then return "dps", id end
    return "", id
end
Grp.RoleOf = RoleOf

function Grp.ClassIcon(classId)
    if not classId or classId == 0 then return nil end
    local f = Fn("ZO_GetClassIcon")
    return f and f(classId) or nil
end

local function IsMe(tag)
    return tag == "player" or (Fn("AreUnitsEqual") ~= nil and AreUnitsEqual(tag, "player")) or false
end

-- dead / "ressing" (someone is resurrecting them) / "pending" (a resurrection waits for them to accept) / "ghost"
-- (reincarnating at a wayshrine) / nil
local function RezState(tag, dead)
    local being, pending, ghost = Fn("IsUnitBeingResurrected"), Fn("DoesUnitHaveResurrectPending"), Fn("IsUnitReincarnating")
    if dead then
        if being and being(tag) then return "ressing" end
        if pending and pending(tag) then return "pending" end
        return nil
    end
    if ghost and ghost(tag) then return "ghost" end
    return nil
end

-- The units, in group order: { tag, companion = bool, owner = tag }. Your own companion when you're not grouped.
function Grp.Tags(tr)
    local out = {}
    local size = GetGroupSize() or 0
    local compTag = Fn("GetCompanionUnitTagByGroupUnitTag")
    if size > 0 then
        for i = 1, size do
            local tag = GetGroupUnitTagByIndex(i)
            if tag and DoesUnitExist(tag) and (tr.groupSelf or not IsMe(tag)) then
                out[#out + 1] = { tag = tag, index = i }
            end
        end
        if tr.groupCompanions and compTag then
            for i = 1, size do
                local tag = GetGroupUnitTagByIndex(i)
                local ctag = tag and compTag(tag)
                if ctag and DoesUnitExist(ctag) then out[#out + 1] = { tag = ctag, index = 100 + i, companion = true, owner = tag } end
            end
        end
    elseif tr.groupSolo then
        out[1] = { tag = "player", index = 1 }
        if tr.groupCompanions and DoesUnitExist("companion") then out[2] = { tag = "companion", index = 2, companion = true, owner = "player" } end
    end
    return out
end

-- your own companion: its name; another member's: "<owner>'s companion" (the game gives a group member's companion
-- no name of its own -- GetUnitName on it read back as the owner's @name: "@red_sea's @red_sea" -- Yarden's screenshot)
local COMPANION_ICON = "/esoui/art/companion/gamepad/gp_category_u30_allies.dds"
Grp.COMPANION_ICON = COMPANION_ICON
local function CompanionName(u, names)
    if u.tag == "companion" or (u.owner and IsMe(u.owner)) then
        local active, nameOf = Fn("GetActiveCompanionDefId"), Fn("GetCompanionName")
        if active and nameOf then
            local n = nameOf(active())
            if n and n ~= "" then return U.CleanName(n) end
        end
        return DT.L("Companion")
    end
    local owner = u.owner or ""
    local who = names == "account" and GetUnitDisplayName(owner) or U.CleanName(GetUnitName(owner))
    if not who or who == "" then who = GetUnitDisplayName(owner) or "" end
    if who == "" then return DT.L("Companion") end
    return DT.L("<<1>>'s companion", who)
end

-- One member's entry. `names` = "account" | "character".
function Grp.State(u, tr)
    local tag = u.tag
    local online = u.companion or not Fn("IsUnitOnline") or IsUnitOnline(tag) == true
    local dead = online and IsUnitDead(tag) == true
    local cur, max = GetUnitPower(tag, POWERTYPE_HEALTH)
    cur, max = tonumber(cur) or 0, tonumber(max) or 0
    if dead or not online then cur = 0 end
    local account = (not u.companion) and GetUnitDisplayName(tag) or ""
    local character = u.companion and CompanionName(u, tr.groupNames) or U.CleanName(GetUnitName(tag))
    local role, roleId = "", nil
    if not u.companion then role, roleId = RoleOf(tag) end
    local classId = (not u.companion) and GetUnitClassId(tag) or 0
    local shown = character
    if tr.groupNames == "account" and account ~= "" then shown = account end

    local s = {
        key = "member:" .. tag, unitTag = tag, name = shown, unitName = shown, account = account, character = character,
        icon = u.companion and COMPANION_ICON or Grp.ClassIcon(classId) or "/esoui/art/lfg/gamepad/gp_lfg_menuicon_random.dds",
        start = 0, expire = 0, duration = 0, stacks = 0, active = true,
        value = cur, max = max, pct = max > 0 and (cur / max * 100) or 0,
        member = true, online = online, dead = dead, rez = online and RezState(tag, dead) or nil,
        leader = (not u.companion) and Fn("IsUnitGroupLeader") ~= nil and IsUnitGroupLeader(tag) == true or false,
        role = role, roleId = roleId, classId = classId, companion = u.companion == true, owner = u.owner,
        isMe = IsMe(tag), inRange = IsMe(tag) or not Fn("IsUnitInGroupSupportRange") or IsUnitInGroupSupportRange(tag) == true,
        mine = IsMe(tag), isTarget = false, isBoss = false,
        groupIndex = u.index,
    }
    if tr.healthVisuals and online and not dead then
        s.shield, s.trauma, s.noHeal = DT.Resources.HealthVisuals(tag)
        s.healthVisuals = true
    else
        s.shield, s.trauma, s.noHeal = 0, 0, false
        s.healthVisuals = tr.healthVisuals == true
    end
    return s
end

-- Places: by role (tanks, healers, damage, no role; companions after the players), in group order, or by name.
function Grp.Order(list, how)
    if how == "group" then
        table.sort(list, function(a, b) return (a.groupIndex or 0) < (b.groupIndex or 0) end)
    elseif how == "name" then
        table.sort(list, function(a, b)
            if a.companion ~= b.companion then return not a.companion end
            local na, nb = U.Lower(a.unitName or ""), U.Lower(b.unitName or "")
            if na ~= nb then return na < nb end
            return (a.groupIndex or 0) < (b.groupIndex or 0)
        end)
    else
        table.sort(list, function(a, b)
            if a.companion ~= b.companion then return not a.companion end
            local ra, rb = ROLE_RANK[a.role or ""] or 4, ROLE_RANK[b.role or ""] or 4
            if ra ~= rb then return ra < rb end
            return (a.groupIndex or 0) < (b.groupIndex or 0)
        end)
    end
    for i, s in ipairs(list) do s.fixedPos, s.order, s.slot = i, i, i end
    return list
end

function Grp.States(tracker, out)
    local tr = tracker.trigger
    local list = {}
    for _, u in ipairs(Grp.Tags(tr)) do list[#list + 1] = Grp.State(u, tr) end
    Grp.Order(list, tr.groupSort)
    for _, s in ipairs(list) do out[#out + 1] = s end
    return out
end

-- Sample group for the editor / move mode when you're not grouped: you first (so trackers shown "On group frames",
-- whose samples sit on you when solo, line up with a frame), then a made-up group showing every state once.
-- (the classes are the game's own list, GetClassInfo -- the same list ZO_GetClassIcon is built from -- not IDs typed in)
local SAMPLE = {
    { "Tankyboi", "tank", 1, 0.92, { leader = true, shield = 0.35 } },
    { "Healz", "healer", 2, 0.78, { trauma = 0.12 } },
    { "Stabby", "dps", 3, 0.55, {} },
    { "Zappy", "dps", 4, 0.0, { dead = true, rez = "ressing" } },
    { "Archie", "dps", 5, 0.64, { inRange = false } },
    { "Bonesy", "dps", 6, 0.4, { noHeal = true } },
    { "Leafy", "dps", 7, 0.0, { online = false } },
}
local function SampleClassId(n)
    local count = Fn("GetNumClasses") and GetNumClasses() or 0
    if count <= 0 or not Fn("GetClassInfo") then return 0 end
    return (GetClassInfo((n - 1) % count + 1)) or 0
end
function Grp.SampleStates(tracker, now)
    local tr = tracker.trigger
    local size = GetGroupSize() or 0
    if size > 0 then
        local out = Grp.States(tracker, {})
        for _, s in ipairs(out) do s.preview = true end
        if #out > 0 then return out end
    end
    local out = {}
    local max = 30000
    for i, m in ipairs(SAMPLE) do
        local o = m[5]
        local wobble = (o.dead or o.online == false) and 0 or (0.08 * math.sin(now / 1.7 + i))
        local frac = U.Clamp(m[4] + wobble, 0, 1)
        local tag = i == 1 and "player" or ("preview" .. i)
        local classId = i == 1 and (GetUnitClassId("player") or 0) or SampleClassId(m[3])
        local s = {
            key = "member:" .. tag, unitTag = i == 1 and "player" or nil, memberTag = tag,
            name = m[1], unitName = (i == 1 and U.CleanName(GetUnitName("player")) ~= "") and U.CleanName(GetUnitName("player")) or m[1],
            account = "@" .. m[1], character = m[1],
            icon = Grp.ClassIcon(classId) or "/esoui/art/lfg/gamepad/gp_lfg_menuicon_random.dds",
            start = 0, expire = 0, duration = 0, stacks = 0, active = true,
            value = frac * max, max = max, pct = frac * 100, member = true,
            online = o.online ~= false, dead = o.dead == true, rez = o.rez, leader = o.leader == true,
            role = m[2], classId = classId, companion = false, isMe = i == 1, mine = i == 1,
            inRange = o.inRange ~= false, isTarget = false, isBoss = false, groupIndex = i, preview = true,
            shield = (o.shield or 0) * max, trauma = (o.trauma or 0) * max, noHeal = o.noHeal == true,
            healthVisuals = tr.healthVisuals == true,
        }
        out[#out + 1] = s
    end
    if tr.groupCompanions then
        out[#out + 1] = { key = "member:previewcomp", memberTag = "previewcomp", name = DT.L("Companion"), unitName = DT.L("Companion"),
            account = "", character = DT.L("Companion"), icon = "/esoui/art/companion/gamepad/gp_category_u30_allies.dds",
            start = 0, expire = 0, duration = 0, stacks = 0, active = true, value = 0.85 * max, max = max, pct = 85, member = true,
            online = true, dead = false, leader = false, role = "", companion = true, inRange = true, isMe = false,
            isTarget = false, isBoss = false, groupIndex = 101, preview = true, shield = 0, trauma = 0, noHeal = false,
            healthVisuals = tr.healthVisuals == true }
    end
    return Grp.Order(out, tr.groupSort)
end
