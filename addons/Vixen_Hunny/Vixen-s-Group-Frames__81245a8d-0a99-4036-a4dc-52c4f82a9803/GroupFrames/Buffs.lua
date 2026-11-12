---------------------------------------------------------------------------
-- Buffs.lua - which effects are tracked
--
-- Loaded first, so it also creates the GroupFrames table every file shares.
-- It draws nothing; GroupFrames.lua asks it one question per effect
-- (GF.GetBuffPriority) and the settings menu uses the rest to manage the
-- player's own list of additional effects.
--
-- Three kinds of effect can be tracked:
--   1. the known Major/Minor buffs below, each with its own checkbox
--   2. other Major/Minor effects (unlisted buffs, and debuffs), by two toggles
--   3. anything the player added themselves, by name or ability id
---------------------------------------------------------------------------

GroupFrames = GroupFrames or {}
local GF = GroupFrames

-- Suffixes shared by the Major and Minor variants. Effects are matched by
-- name, so every ability that grants e.g. "Major Resolve" is picked up no
-- matter which skill or set it comes from. (English client names.)
GF.BUFF_SUFFIXES = {
    "Aegis", "Berserk", "Brutality", "Courage", "Endurance", "Evasion",
    "Expedition", "Force", "Fortitude", "Gallop", "Heroism", "Intellect",
    "Mending", "Prophecy", "Protection", "Resolve", "Savagery", "Slayer",
    "Sorcery", "Toughness", "Vitality",
}

GF.MAJOR_BUFFS = {} -- "Major Aegis", "Major Berserk", ...
GF.MINOR_BUFFS = {} -- "Minor Aegis", "Minor Berserk", ...
-- name -> sort priority (lower shows first): Major buffs get 1-21, Minor
-- buffs 101-121, so all Majors come before all Minors.
GF.BUFF_ORDER = {}

for i, suffix in ipairs(GF.BUFF_SUFFIXES) do
    local major, minor = "Major " .. suffix, "Minor " .. suffix
    GF.MAJOR_BUFFS[i] = major
    GF.MINOR_BUFFS[i] = minor
    GF.BUFF_ORDER[major] = i
    GF.BUFF_ORDER[minor] = 100 + i
end

---------------------------------------------------------------------------
-- User-added effects and the blacklist
--
-- sv.trackedEffects and sv.blacklist both map a key to a display name. The
-- key is either an ability id (number: only that exact ability) or a
-- lower-case effect name (string: every ability with that name, whatever
-- its source). The blacklist beats everything: a blacklisted effect is never
-- shown, whatever the checkboxes or the tracked list say.
---------------------------------------------------------------------------

-- Removes leading and trailing whitespace.
local function Trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Lower-case names of the listed Major/Minor buffs. Those have their own
-- checkboxes and are never put on the tracked list.
local LISTED_LOWER = {}
for name in pairs(GF.BUFF_ORDER) do LISTED_LOWER[name:lower()] = true end

-- True when `name` is one of the Major/Minor buffs with its own checkbox.
function GF.IsListedBuff(name)
    return name ~= nil and LISTED_LOWER[name:lower()] == true
end

-- Turns typed text into key, display name and effect name. Returns nil
-- plus a reason when the text is not usable.
local function ParseEffect(text)
    text = Trim(text or "")
    if text == "" then return nil, "nothing entered" end
    -- a number is an ability id, anything else an effect name
    local id = tonumber(text)
    if id then
        local name = zo_strformat("<<1>>", GetAbilityName(id))
        if name == "" then return nil, "no ability with id " .. id end
        return id, name .. " (" .. id .. ")", name
    end
    return text:lower(), text, text
end

-- True when the effect is on the blacklist, by its id or by its name.
function GF.IsBlacklisted(name, abilityId)
    local blacklist = GF.sv.blacklist
    return (abilityId ~= nil and blacklist[abilityId] ~= nil)
        or (name ~= nil and blacklist[name:lower()] ~= nil)
end

-- Remembers an ability id for an effect name so the entry can be shared.
local function RememberId(key)
    for name, abilityId in pairs(GF.seenEffects) do
        if name:lower() == key then
            GF.sv.effectIds[key] = abilityId
            return
        end
    end
end

-- Adds an effect by name or ability id. Returns the display name, or nil
-- plus a reason when nothing was added.
function GF.AddTrackedEffect(text)
    local key, display, name = ParseEffect(text)
    if not key then return nil, display end

    if GF.IsListedBuff(name) then
        return nil, name .. " has its own checkbox in the Major and Minor buff lists"
    end
    if GF.IsBlacklisted(name, type(key) == "number" and key or nil) then
        return nil, display .. " is blacklisted - remove it from the blacklist first"
    end
    local tracked = GF.sv.trackedEffects
    if tracked[key] then return nil, display .. " is already tracked" end
    tracked[key] = display
    if type(key) == "string" then RememberId(key) end
    return display
end

-- Stops tracking an effect. `key` is a key of sv.trackedEffects.
function GF.RemoveTrackedEffect(key)
    if key == nil then return end
    GF.sv.trackedEffects[key] = nil
    GF.sv.effectIds[key] = nil
end

-- Puts an effect (name or ability id) on the blacklist and drops it from
-- the tracked list and the pending shared effects. Returns the display
-- name, or nil plus a reason.
function GF.AddBlacklistEffect(text)
    local key, display, name = ParseEffect(text)
    if not key then return nil, display end

    local blacklist = GF.sv.blacklist
    if blacklist[key] then return nil, display .. " is already blacklisted" end
    blacklist[key] = display

    -- the same entry on the other lists would be pointless now
    GF.RemoveTrackedEffect(key)
    if GF.sharedEffects then GF.sharedEffects[key] = nil end
    return display
end

-- Takes an effect off the blacklist. `key` is a key of sv.blacklist.
function GF.RemoveBlacklistEffect(key)
    if key == nil then return end
    GF.sv.blacklist[key] = nil
end

-- Moves the comma separated list of version 1.0/1.1 into trackedEffects,
-- and drops tracked entries for listed Major/Minor buffs (older versions
-- let them in, which made their checkboxes useless).
function GF.MigrateCustomEffects()
    local old = GF.sv.customEffects
    if type(old) == "string" then
        for entry in string.gmatch(old, "[^,]+") do
            GF.AddTrackedEffect(entry)
        end
    end
    GF.sv.customEffects = nil

    local tracked = GF.sv.trackedEffects
    local remove = {}
    for key in pairs(tracked) do
        local name = type(key) == "number" and zo_strformat("<<1>>", GetAbilityName(key)) or key
        if GF.IsListedBuff(name) then remove[#remove + 1] = key end
    end
    for _, key in ipairs(remove) do GF.RemoveTrackedEffect(key) end
end

---------------------------------------------------------------------------
-- Effects seen in game
--
-- Typing effect names is error-prone (and painful on console), so the
-- settings offer a list of effects that were actually seen on the group.
-- These tables collect them; they are not saved and start empty each login.
---------------------------------------------------------------------------

-- Effects seen this session: name -> ability id, for everyone and per
-- member (keyed by @account name).
GF.seenEffects = {}
GF.seenByMember = {}

-- Returns the table that collects the effects seen on this unit.
function GF.GetSeenTable(unitTag)
    local key = GetUnitDisplayName(unitTag) or ""
    local seen = GF.seenByMember[key]
    if not seen then
        seen = {}
        GF.seenByMember[key] = seen
    end
    return seen
end

-- Records every effect currently on the unit, tracked or not.
local function ScanUnitForSeenEffects(unitTag)
    local seen = GF.GetSeenTable(unitTag)
    for i = 1, GetNumBuffs(unitTag) do
        local name, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo(unitTag, i)
        name = zo_strformat("<<1>>", name)
        if name ~= "" then
            seen[name] = abilityId
            GF.seenEffects[name] = abilityId
        end
    end
end

-- Calls callback(unitTag) for every group member, or just for yourself
-- when you are not in a group.
local function ForEachMember(callback)
    if IsUnitGrouped("player") then
        for i = 1, GetGroupSize() do
            local unitTag = GetGroupUnitTagByIndex(i)
            if unitTag and DoesUnitExist(unitTag) then callback(unitTag) end
        end
    else
        callback("player")
    end
end

-- Returns display names and @account keys of yourself and your groupmates.
function GF.GetGroupMembers()
    local names, keys = {}, {}
    ForEachMember(function(unitTag)
        local account = GetUnitDisplayName(unitTag) or ""
        local character = zo_strformat("<<1>>", GetUnitName(unitTag))
        if AreUnitsEqual(unitTag, "player") then character = character .. " (you)" end
        names[#names + 1] = character
        keys[#keys + 1] = account
    end)
    return names, keys
end

-- Returns every effect name in `source` that passes keep(name, abilityId),
-- sorted. Scans the group first so the lists are current.
local function SeenNames(memberKey, keep)
    ForEachMember(ScanUnitForSeenEffects)

    local source = GF.seenEffects
    if memberKey and memberKey ~= "" then
        source = GF.seenByMember[memberKey] or {}
    end

    local names = {}
    for name, abilityId in pairs(source) do
        if keep(name, abilityId) then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

-- Returns a sorted list of effect names that are not tracked yet (and are
-- not part of the Major/Minor lists, nor blacklisted). With memberKey (an
-- @account name) only effects seen on that groupmate are listed, otherwise
-- those of everyone.
function GF.GetAddableEffects(memberKey)
    local tracked = GF.sv.trackedEffects
    return SeenNames(memberKey, function(name, abilityId)
        return not GF.IsListedBuff(name) and not tracked[name:lower()]
            and not tracked[abilityId] and not GF.IsBlacklisted(name, abilityId)
    end)
end

-- Returns a sorted list of every effect seen this session that is not
-- blacklisted yet, Major/Minor buffs included.
function GF.GetBlacklistableEffects(memberKey)
    return SeenNames(memberKey, function(name, abilityId)
        return not GF.IsBlacklisted(name, abilityId)
    end)
end

---------------------------------------------------------------------------
-- The tracking decision
---------------------------------------------------------------------------

-- Returns a sort priority when the effect should be shown, nil otherwise.
-- Lower priorities are shown first:
--   1-21     listed Major buffs       200  unlisted Major/Minor buffs
--   101-121  listed Minor buffs       250  Major/Minor debuffs
--                                     300  effects the player added
-- Order of the checks: blacklist, then the Major/Minor checkboxes for the
-- listed buffs, then the player's own list, then the other toggles.
function GF.GetBuffPriority(name, abilityId, effectType)
    local sv = GF.sv

    -- the blacklist wins over everything
    if GF.IsBlacklisted(name, abilityId) then return nil end

    local isMajor = name:find("^Major ") ~= nil
    local isMinor = not isMajor and name:find("^Minor ") ~= nil

    -- a listed buff: the master switch and its own checkbox decide, even if
    -- it also ended up on the tracked list (e.g. shared by a groupmate)
    if GF.IsListedBuff(name) then
        if isMajor and not sv.trackMajor then return nil end
        if isMinor and not sv.trackMinor then return nil end
        if sv.buffs[name] == false then return nil end
        return GF.BUFF_ORDER[name] or 200
    end

    -- the player's own list
    local tracked = sv.trackedEffects
    if tracked[abilityId] or tracked[name:lower()] then
        return 300
    end

    -- everything else must be a Major or Minor effect (English names)
    if not (isMajor or isMinor) then return nil end
    if isMajor and not sv.trackMajor then return nil end
    if isMinor and not sv.trackMinor then return nil end

    -- Major/Minor effects that are not in the lists (mostly debuffs such as
    -- Major Breach or Minor Vulnerability).
    if effectType == BUFF_EFFECT_TYPE_DEBUFF then
        return sv.trackDebuffs and 250 or nil
    end
    return sv.trackOtherMajorMinor and 200 or nil
end
