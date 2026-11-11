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

GF.MAJOR_BUFFS = {}
GF.MINOR_BUFFS = {}
-- name -> sort priority (lower shows first)
GF.BUFF_ORDER = {}

for i, suffix in ipairs(GF.BUFF_SUFFIXES) do
    local major, minor = "Major " .. suffix, "Minor " .. suffix
    GF.MAJOR_BUFFS[i] = major
    GF.MINOR_BUFFS[i] = minor
    GF.BUFF_ORDER[major] = i
    GF.BUFF_ORDER[minor] = 100 + i
end

---------------------------------------------------------------------------
-- User-added effects
--
-- sv.trackedEffects maps a key to a display name. The key is either an
-- ability id (number: only that exact ability) or a lower-case effect name
-- (string: every ability with that name, whatever its source).
---------------------------------------------------------------------------

local function Trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Adds an effect by name or ability id. Returns the display name, or nil
-- plus a reason when nothing was added.
function GF.AddTrackedEffect(text)
    text = Trim(text or "")
    if text == "" then return nil, "nothing entered" end

    local tracked = GF.sv.trackedEffects
    local id = tonumber(text)
    local key, display
    if id then
        local name = zo_strformat("<<1>>", GetAbilityName(id))
        if name == "" then return nil, "no ability with id " .. id end
        key, display = id, name .. " (" .. id .. ")"
    else
        key, display = text:lower(), text
    end

    if tracked[key] then return nil, display .. " is already tracked" end
    tracked[key] = display
    if not id then
        -- remember an ability id for the name so the entry can be shared
        for name, abilityId in pairs(GF.seenEffects) do
            if name:lower() == key then
                GF.sv.effectIds[key] = abilityId
                break
            end
        end
    end
    return display
end

function GF.RemoveTrackedEffect(key)
    if key == nil then return end
    GF.sv.trackedEffects[key] = nil
    GF.sv.effectIds[key] = nil
end

-- Moves the comma separated list of version 1.0/1.1 into trackedEffects.
function GF.MigrateCustomEffects()
    local old = GF.sv.customEffects
    if type(old) == "string" then
        for entry in string.gmatch(old, "[^,]+") do
            GF.AddTrackedEffect(entry)
        end
    end
    GF.sv.customEffects = nil
end

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

-- Returns a sorted list of effect names that are not tracked yet (and are
-- not part of the Major/Minor lists). With memberKey (an @account name) only
-- effects seen on that groupmate are listed, otherwise those of everyone.
function GF.GetAddableEffects(memberKey)
    ForEachMember(ScanUnitForSeenEffects)

    local source = GF.seenEffects
    if memberKey and memberKey ~= "" then
        source = GF.seenByMember[memberKey] or {}
    end

    local sv = GF.sv
    local names = {}
    for name, abilityId in pairs(source) do
        if sv.buffs[name] == nil and not sv.trackedEffects[name:lower()]
            and not sv.trackedEffects[abilityId] then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    return names
end

-- Returns a sort priority when the effect should be shown, nil otherwise.
function GF.GetBuffPriority(name, abilityId, effectType)
    local sv = GF.sv
    local tracked = sv.trackedEffects
    if tracked[abilityId] or tracked[name:lower()] then
        return 300
    end

    local isMajor = name:find("^Major ") ~= nil
    local isMinor = not isMajor and name:find("^Minor ") ~= nil
    if not (isMajor or isMinor) then return nil end
    if isMajor and not sv.trackMajor then return nil end
    if isMinor and not sv.trackMinor then return nil end

    local known = sv.buffs[name]
    if known ~= nil then
        return known and GF.BUFF_ORDER[name] or nil
    end

    -- Major/Minor effects that are not in the list above (mostly debuffs
    -- such as Major Breach or Minor Vulnerability).
    if effectType == BUFF_EFFECT_TYPE_DEBUFF then
        return sv.trackDebuffs and 250 or nil
    end
    return sv.trackOtherMajorMinor and 200 or nil
end
