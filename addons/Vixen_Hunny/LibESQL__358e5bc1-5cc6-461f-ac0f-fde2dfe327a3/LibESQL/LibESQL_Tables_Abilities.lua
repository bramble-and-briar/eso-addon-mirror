-- Tables: abilities, skill_lines, skills, champion_skills, crafted_abilities,
-- scribing_scripts, effects, effects_seen, combat_log, hotbar.

local E = LibESQL
local Try, Clean, Tick = E.Try, E.CleanName, E.Tick
local EnumShort = E.EnumShort
local FUNCS = E.SQL.FUNCS

local function abilityName(id)
    local n = Try(GetAbilityName, id)
    if n == nil or n == "" then return nil end
    return Clean(n)
end
E.AbilityName = abilityName

---------------------------------------------------------------------------
-- abilities (every ability id in the game, found by scanning)
---------------------------------------------------------------------------
local function costInfo(r)
    if r._costDone then return end
    r._costDone = true
    local cost, mech, overTime = Try(GetAbilityBaseCostInfo, r.id)
    r.cost = cost or 0
    r.cost_mechanic = mech and EnumShort("COMBAT_MECHANIC_FLAGS_", mech) or nil
    r.cost_over_time = overTime and true or false
end

local function castInfo(r)
    if r._castDone then return end
    r._castDone = true
    local channeled, castMs = Try(GetAbilityCastInfo, r.id)
    r.channeled = channeled and true or false
    r.cast_ms = castMs or 0
end

local function rangeInfo(r)
    if r._rangeDone then return end
    r._rangeDone = true
    local minR, maxR = Try(GetAbilityRange, r.id)
    r.min_range = minR or 0
    r.max_range = maxR or 0
end

local function roleInfo(r)
    if r._roleDone then return end
    r._roleDone = true
    local tank, heal, dps = Try(GetAbilityRoles, r.id)
    r.role_tank, r.role_healer, r.role_dps = tank and true or false, heal and true or false, dps and true or false
end

local function skillKeys(r)
    if r._skillDone then return end
    r._skillDone = true
    local skillType, lineIndex, skillIndex, morph, rank = Try(GetSpecificSkillAbilityKeysByAbilityId, r.id)
    if skillType and skillType ~= 0 and lineIndex and lineIndex > 0 then
        r.skill_type = EnumShort("SKILL_TYPE_", skillType)
        local lineId = Try(GetSkillLineId, skillType, lineIndex)
        r.skill_line_id = lineId
        r.skill_line = lineId and Clean(Try(GetSkillLineNameById, lineId)) or nil
        r.skill_index = skillIndex
        r.morph = morph
        r.rank = rank
        r.is_player_skill = true
    else
        r.is_player_skill = false
    end
end

local function lazyField(fill, field)
    return function(r) fill(r); return r[field] end
end

-- PC keeps ability names for the session so repeated name searches are fast
-- (about 150k short strings). Console skips this to save memory.
local nameCache = not E.isConsole and {} or nil

local abilityColumns = {
    { "id", "int", "Ability id" },
    { "name", "text", "Ability name", function(r)
        local cache = nameCache
        if cache then
            local n = cache[r.id]
            if n == nil then n = abilityName(r.id) or false; cache[r.id] = n end
            return n or nil
        end
        return abilityName(r.id) end },
    { "description", "text", "Tooltip description", function(r) return Try(GetAbilityDescription, r.id) end },
    { "icon", "text", "Icon texture path", function(r) return Try(GetAbilityIcon, r.id) end },
    { "duration_ms", "int", "Duration in ms (0 = instant or none)", function(r) return Try(GetAbilityDuration, r.id) or 0 end },
    { "cast_ms", "int", "Cast or channel time in ms", lazyField(castInfo, "cast_ms") },
    { "channeled", "bool", "Channeled ability", lazyField(castInfo, "channeled") },
    { "cost", "int", "Base resource cost", lazyField(costInfo, "cost") },
    { "cost_mechanic", "text", "Resource used: magicka, stamina, health, ultimate...", lazyField(costInfo, "cost_mechanic") },
    { "cost_over_time", "bool", "Cost is paid over time", lazyField(costInfo, "cost_over_time") },
    { "cooldown_ms", "int", "Cooldown in ms", function(r) return Try(GetAbilityCooldown, r.id) or 0 end },
    { "min_range", "int", "Minimum range (cm)", lazyField(rangeInfo, "min_range") },
    { "max_range", "int", "Maximum range (cm, 2800 = 28 m)", lazyField(rangeInfo, "max_range") },
    { "radius", "int", "Area radius (cm)", function(r) return Try(GetAbilityRadius, r.id) or 0 end },
    { "angle", "int", "Cone angle", function(r) return Try(GetAbilityAngleDistance, r.id) or 0 end },
    { "target", "text", "Target description (Self, Enemy, Area...)", function(r) return Try(GetAbilityTargetDescription, r.id) end },
    { "passive", "bool", "Passive ability", function(r) return Try(IsAbilityPassive, r.id) and true or false end },
    { "permanent", "bool", "Permanent effect", function(r) return Try(IsAbilityPermanent, r.id) and true or false end },
    { "ultimate", "bool", "Ultimate ability", function(r) return Try(IsAbilityUltimate, r.id) and true or false end },
    { "toggled", "bool", "Duration is a toggle", function(r) return Try(IsAbilityDurationToggled, r.id) and true or false end },
    { "buff_type", "int", "BuffType enum value", function(r) return Try(GetAbilityBuffType, r.id) end },
    { "buff_type_name", "text", "BuffType name (major_*, minor_*...)", function(r)
        local v = Try(GetAbilityBuffType, r.id); return v and EnumShort("BUFF_TYPE_", v) end },
    { "frequency_ms", "int", "Tick interval in ms", function(r) return Try(GetAbilityFrequencyMS, r.id) end },
    { "role_tank", "bool", "Flagged as a tank ability", lazyField(roleInfo, "role_tank") },
    { "role_healer", "bool", "Flagged as a healer ability", lazyField(roleInfo, "role_healer") },
    { "role_dps", "bool", "Flagged as a damage ability", lazyField(roleInfo, "role_dps") },
    { "header", "text", "Description header", function(r) return Try(GetAbilityDescriptionHeader, r.id) end },
    { "new_effect", "text", "Morph's new effect lines", function(r) return Try(GetAbilityNewEffectLines, r.id) end },
    { "mundus", "text", "Mundus stone this ability belongs to", function(r)
        local v = Try(GetAbilityMundusStoneType, r.id)
        if not v or v == 0 then return nil end
        return EnumShort("MUNDUS_STONE_", v) end },
    { "crafted_ability_id", "int", "Scribing grimoire id", function(r)
        local v = Try(GetAbilityCraftedAbilityId, r.id); if v and v > 0 then return v end end },
    { "is_player_skill", "bool", "Part of a player skill line", lazyField(skillKeys, "is_player_skill") },
    { "skill_type", "text", "class, weapon, armor, guild, ava, racial, world, tradeskill...", lazyField(skillKeys, "skill_type") },
    { "skill_line_id", "int", "Skill line id", lazyField(skillKeys, "skill_line_id") },
    { "skill_line", "text", "Skill line name", lazyField(skillKeys, "skill_line") },
    { "skill_index", "int", "Index in the skill line", lazyField(skillKeys, "skill_index") },
    { "morph", "int", "0 = base, 1 / 2 = morphs", lazyField(skillKeys, "morph") },
    { "rank", "int", "Skill rank", lazyField(skillKeys, "rank") },
    { "link", "text", "Chat link", function(r) return Try(GetAbilityLink, r.id, LINK_STYLE_BRACKETS or 1) end },
}

E.RegisterTable({
    name = "abilities",
    desc = "Every ability id in the game (scanned once per update). Columns are read on demand.",
    key = "id",
    columns = abilityColumns,
    scan = {
        label = "ability",
        from = 1, to = 600000, gap = 60000, minTo = 250000,
        exists = function(id) return DoesAbilityExist(id) end,
        makeRow = function(id) return { id = id } end,
    },
})

FUNCS.ABILITY_NAME = function(id) id = tonumber(id); return id and abilityName(id) end
FUNCS.ABILITY_DESC = function(id) id = tonumber(id); return id and Try(GetAbilityDescription, id) end
FUNCS.ABILITY_ICON = function(id) id = tonumber(id); return id and Try(GetAbilityIcon, id) end
FUNCS.ABILITY_DURATION = function(id) id = tonumber(id); return id and Try(GetAbilityDuration, id) end
FUNCS.ABILITY_LINK = function(id) id = tonumber(id); return id and Try(GetAbilityLink, id, LINK_STYLE_BRACKETS or 1) end

---------------------------------------------------------------------------
-- skill_lines / skills
---------------------------------------------------------------------------
local function forEachSkillLine(fn)
    local numTypes = Try(GetNumSkillTypes) or 0
    for skillType = 1, numTypes do
        for lineIndex = 1, (Try(GetNumSkillLines, skillType) or 0) do
            fn(skillType, lineIndex)
        end
    end
end

E.RegisterTable({
    name = "skill_lines",
    desc = "Skill lines available to this character (class, weapon, armor, guild, world...)",
    key = "id",
    live = true,
    columns = {
        { "id", "int", "Skill line id" },
        { "name", "text", "Skill line name" },
        { "skill_type", "text", "class, weapon, armor, world, guild, ava, racial, tradeskill..." },
        { "skill_type_id", "int", "SkillType enum value" },
        { "line_index", "int", "Index within its skill type" },
        { "rank", "int", "Current rank" },
        { "active", "bool", "Line is active for this character" },
        { "discovered", "bool", "Line is discovered" },
        { "class_id", "int", "Class id for class lines" },
        { "num_skills", "int", "Number of skills in the line" },
        { "xp", "int", "Current XP in the rank", nil },
    },
    build = function(rows)
        forEachSkillLine(function(skillType, lineIndex)
            Tick()
            local id = Try(GetSkillLineId, skillType, lineIndex)
            local rank, _, active, discovered = Try(GetSkillLineDynamicInfo, skillType, lineIndex)
            local _, _, xp = Try(GetSkillLineXPInfo, skillType, lineIndex)
            rows[#rows + 1] = {
                id = id,
                name = id and Clean(Try(GetSkillLineNameById, id)) or nil,
                skill_type = EnumShort("SKILL_TYPE_", skillType),
                skill_type_id = skillType,
                line_index = lineIndex,
                rank = rank,
                active = active and true or false,
                discovered = discovered and true or false,
                class_id = Try(GetSkillLineClassId, skillType, lineIndex),
                num_skills = Try(GetNumSkillAbilities, skillType, lineIndex),
                xp = xp,
            }
        end)
    end,
})

E.RegisterTable({
    name = "skills",
    desc = "Every skill in your skill lines: one row per morph (actives) or rank (passives)",
    live = true,
    columns = {
        { "ability_id", "int", "Ability id of this morph / rank" },
        { "name", "text", "Skill name" },
        { "line_id", "int", "Skill line id" },
        { "line_name", "text", "Skill line name" },
        { "skill_type", "text", "class, weapon, armor, guild..." },
        { "skill_index", "int", "Index in the line" },
        { "morph", "int", "0 = base, 1 / 2 = morphs (actives)" },
        { "rank", "int", "Rank (passives)" },
        { "max_rank", "int", "Highest passive rank" },
        { "passive", "bool", "Passive skill" },
        { "ultimate", "bool", "Ultimate skill" },
        { "purchased", "bool", "You bought this skill" },
        { "current", "bool", "This is the morph / rank you have now" },
        { "line_rank_needed", "int", "Skill line rank needed to unlock" },
        { "progression_id", "int", "Progression id (actives)" },
        { "crafted_ability_id", "int", "Scribing grimoire id" },
        { "icon", "text", "Icon texture path" },
        { "description", "text", "Tooltip", function(r) return Try(GetAbilityDescription, r.ability_id) end },
    },
    build = function(rows)
        forEachSkillLine(function(skillType, lineIndex)
            local lineId = Try(GetSkillLineId, skillType, lineIndex)
            local lineName = lineId and Clean(Try(GetSkillLineNameById, lineId)) or nil
            local typeName = EnumShort("SKILL_TYPE_", skillType)
            for skillIndex = 1, (Try(GetNumSkillAbilities, skillType, lineIndex) or 0) do
                Tick()
                local name, icon, earnedRank, passive, ultimate, purchased, progressionIndex =
                    Try(GetSkillAbilityInfo, skillType, lineIndex, skillIndex)
                local base = {
                    name = Clean(name), icon = icon, line_id = lineId, line_name = lineName,
                    skill_type = typeName, skill_index = skillIndex,
                    passive = passive and true or false, ultimate = ultimate and true or false,
                    purchased = purchased and true or false,
                    line_rank_needed = Try(GetSkillAbilityLineRankNeededToUnlock, skillType, lineIndex, skillIndex),
                    crafted_ability_id = (function()
                        local c = Try(GetCraftedAbilitySkillCraftedAbilityId, skillType, lineIndex, skillIndex)
                        if c and c > 0 then return c end
                    end)(),
                }
                local currentId = Try(GetSkillAbilityId, skillType, lineIndex, skillIndex, false)
                if passive then
                    local curLevel, maxLevel = Try(GetSkillAbilityUpgradeInfo, skillType, lineIndex, skillIndex)
                    maxLevel = maxLevel or 1
                    for rank = 1, maxLevel do
                        local id = Try(GetSpecificSkillAbilityInfo, skillType, lineIndex, skillIndex, 0, rank)
                        if id and id > 0 then
                            local row = E.ShallowCopy(base)
                            row.ability_id, row.rank, row.max_rank, row.morph = id, rank, maxLevel, 0
                            row.current = purchased and (curLevel or 0) == rank or false
                            local n = abilityName(id)
                            if n then row.name = n end
                            rows[#rows + 1] = row
                        end
                    end
                else
                    local progressionId = Try(GetProgressionSkillProgressionId, skillType, lineIndex, skillIndex)
                    local seen = {}
                    for morph = 0, 2 do
                        local id = Try(GetSpecificSkillAbilityInfo, skillType, lineIndex, skillIndex, morph, 4)
                        if (not id or id == 0) and progressionId and progressionId > 0 then
                            id = Try(GetProgressionSkillMorphSlotAbilityId, progressionId, morph)
                        end
                        if id and id > 0 and not seen[id] then
                            seen[id] = true
                            local row = E.ShallowCopy(base)
                            row.ability_id, row.morph, row.progression_id = id, morph, progressionId
                            row.current = purchased and id == currentId or false
                            local n = abilityName(id)
                            if n then row.name = n end
                            local ic = Try(GetAbilityIcon, id)
                            if ic and ic ~= "" then row.icon = ic end
                            rows[#rows + 1] = row
                        end
                    end
                end
            end
        end)
    end,
})

---------------------------------------------------------------------------
-- champion_skills
---------------------------------------------------------------------------
E.RegisterTable({
    name = "champion_skills",
    desc = "Champion point stars in every constellation",
    key = "id",
    columns = {
        { "id", "int", "Champion skill id" },
        { "name", "text", "Star name" },
        { "discipline", "text", "Constellation (Warfare, Fitness, Craft)" },
        { "discipline_id", "int", "Discipline id" },
        { "discipline_type", "text", "combat, conditioning, world" },
        { "skill_type", "text", "normal, normal_slottable, stat_pool_slottable..." },
        { "slottable", "bool", "Can be slotted" },
        { "max_points", "int", "Max points" },
        { "ability_id", "int", "Ability id behind the star" },
        { "cluster", "text", "Cluster name, if in a cluster" },
        { "description", "text", "Tooltip at 0 extra points", function(r) return Try(GetChampionSkillDescription, r.id, 0) end },
        { "current_bonus", "text", "Current bonus text", function(r) return Try(GetChampionSkillCurrentBonusText, r.id, 0) end },
        { "x", "num", "Position in the constellation" },
        { "y", "num", "Position in the constellation" },
    },
    build = function(rows)
        for d = 1, (Try(GetNumChampionDisciplines) or 0) do
            local discId = Try(GetChampionDisciplineId, d)
            local discName = discId and Clean(Try(GetChampionDisciplineName, discId))
            local discType = discId and Try(GetChampionDisciplineType, discId)
            for s = 1, (Try(GetNumChampionDisciplineSkills, d) or 0) do
                Tick()
                local id = Try(GetChampionSkillId, d, s)
                if id then
                    local st = Try(GetChampionSkillType, id)
                    local x, y = Try(GetChampionSkillPosition, id)
                    local cluster = Try(GetChampionClusterName, id)
                    rows[#rows + 1] = {
                        id = id,
                        name = Clean(Try(GetChampionSkillName, id)),
                        discipline = discName,
                        discipline_id = discId,
                        discipline_type = discType and EnumShort("CHAMPION_DISCIPLINE_TYPE_", discType),
                        skill_type = st and EnumShort("CHAMPION_SKILL_TYPE_", st),
                        slottable = st == (CHAMPION_SKILL_TYPE_NORMAL_SLOTTABLE or 1) or st == (CHAMPION_SKILL_TYPE_STAT_POOL_SLOTTABLE or 2),
                        max_points = Try(GetChampionSkillMaxPoints, id),
                        ability_id = Try(GetChampionAbilityId, id),
                        cluster = cluster ~= "" and cluster or nil,
                        x = x, y = y,
                    }
                end
            end
        end
    end,
})

---------------------------------------------------------------------------
-- scribing
---------------------------------------------------------------------------
E.RegisterTable({
    name = "crafted_abilities",
    desc = "Scribing grimoires",
    key = "id",
    columns = {
        { "id", "int", "Crafted ability (grimoire) id" },
        { "name", "text", "Grimoire name" },
        { "description", "text", "Description" },
        { "icon", "text", "Icon" },
        { "ability_id", "int", "Representative ability id" },
        { "skill_type", "text", "Skill type it belongs to" },
        { "hint", "text", "How to acquire" },
    },
    build = function(rows)
        for i = 1, (Try(GetNumCraftedAbilities) or 0) do
            Tick()
            local id = Try(GetCraftedAbilityIdAtIndex, i)
            if id then
                local st = Try(GetSkillTypeForCraftedAbilityId, id)
                rows[#rows + 1] = {
                    id = id,
                    name = Clean(Try(GetCraftedAbilityDisplayName, id)),
                    description = Try(GetCraftedAbilityDescription, id),
                    icon = Try(GetCraftedAbilityIcon, id),
                    ability_id = Try(GetCraftedAbilityRepresentativeAbilityId, id, "player"),
                    skill_type = st and EnumShort("SKILL_TYPE_", st),
                    hint = Try(GetCraftedAbilityAcquireHint, id),
                }
            end
        end
    end,
})

E.RegisterTable({
    name = "scribing_scripts",
    desc = "Scribing scripts (focus, signature, affix)",
    key = "id",
    columns = {
        { "id", "int", "Script id" },
        { "name", "text", "Script name" },
        { "slot", "text", "primary (focus), secondary (signature), tertiary (affix)" },
        { "description", "text", "General description" },
        { "icon", "text", "Icon" },
        { "hint", "text", "How to acquire" },
    },
    build = function(rows)
        local misses = 0
        local id = 0
        while misses < 200 and id < 5000 do
            id = id + 1
            Tick()
            local name = Try(GetCraftedAbilityScriptDisplayName, id)
            if name and name ~= "" then
                misses = 0
                local slot = Try(GetCraftedAbilityScriptScribingSlot, id)
                rows[#rows + 1] = {
                    id = id,
                    name = Clean(name),
                    slot = slot and EnumShort("SCRIBING_SLOT_", slot),
                    description = Try(GetCraftedAbilityScriptGeneralDescription, id),
                    icon = Try(GetCraftedAbilityScriptIcon, id),
                    hint = Try(GetCraftedAbilityScriptAcquireHint, id),
                }
            else
                misses = misses + 1
            end
        end
    end,
})

---------------------------------------------------------------------------
-- effects (buffs / debuffs active right now)
---------------------------------------------------------------------------
local function effectUnits()
    local units = { "player", "reticleover", "companion" }
    for i = 1, 12 do units[#units + 1] = "boss" .. i end
    if Try(IsUnitGrouped, "player") then
        for i = 1, (Try(GetGroupSize) or 0) do units[#units + 1] = "group" .. i end
    end
    return units
end

E.RegisterTable({
    name = "effects",
    desc = "Buffs and debuffs active right now on you, your target, bosses, group and companion",
    live = true,
    columns = {
        { "unit", "text", "Unit tag (player, reticleover, boss1, group3...)" },
        { "unit_name", "text", "Unit name" },
        { "ability_id", "int", "Effect ability id" },
        { "name", "text", "Effect name" },
        { "stacks", "int", "Stack count" },
        { "remaining_s", "num", "Seconds left (NULL for permanent)" },
        { "duration_s", "num", "Total duration in seconds (NULL for permanent)" },
        { "start_s", "num", "Game time when it started (s)" },
        { "end_s", "num", "Game time when it ends (s)" },
        { "permanent", "bool", "No end time" },
        { "effect_type", "text", "buff or debuff" },
        { "ability_type", "text", "AbilityType name" },
        { "status_effect", "text", "Status effect (burning, poisoned, ...)" },
        { "buff_type_name", "text", "BuffType (major_*/minor_*)", function(r)
            local v = Try(GetAbilityBuffType, r.ability_id); return v and EnumShort("BUFF_TYPE_", v) end },
        { "cast_by_player", "bool", "You applied it" },
        { "can_click_off", "bool", "Can be cancelled" },
        { "slot", "int", "Buff slot" },
        { "icon", "text", "Icon" },
    },
    build = function(rows)
        local now = (GetFrameTimeSeconds and GetFrameTimeSeconds()) or 0
        for _, unit in ipairs(effectUnits()) do
            if Try(DoesUnitExist, unit) then
                local unitName = Clean(Try(GetUnitName, unit))
                for i = 1, (Try(GetNumBuffs, unit) or 0) do
                    Tick()
                    local name, started, ending, slot, stacks, icon, _, effectType, abilityType, statusType, abilityId, canClickOff, castByPlayer =
                        Try(GetUnitBuffInfo, unit, i)
                    if name then
                        local permanent = not ending or ending <= 0 or ending == started
                        rows[#rows + 1] = {
                            unit = unit, unit_name = unitName,
                            ability_id = abilityId, name = Clean(name),
                            stacks = stacks, slot = slot, icon = icon,
                            start_s = started, end_s = ending, permanent = permanent,
                            remaining_s = not permanent and math.max(0, ending - now) or nil,
                            duration_s = not permanent and (ending - started) or nil,
                            effect_type = effectType and EnumShort("BUFF_EFFECT_TYPE_", effectType),
                            ability_type = abilityType and EnumShort("ABILITY_TYPE_", abilityType),
                            status_effect = statusType and statusType ~= 0 and EnumShort("STATUS_EFFECT_TYPE_", statusType) or nil,
                            cast_by_player = castByPlayer and true or false,
                            can_click_off = canClickOff and true or false,
                        }
                    end
                end
            end
        end
    end,
})

---------------------------------------------------------------------------
-- effects_seen: every effect id observed since tracking was enabled
---------------------------------------------------------------------------
-- saved compactly: sv.effectsSeen[id] = { count, lastTs, flags, maxStacks, effectType, abilityType, statusType }
-- flags bit 1 = on you, 2 = on others, 4 = applied by you

E.EFFECTS_SEEN_MAX = E.isConsole and 3000 or 20000

local function onEffectChanged(_, changeType, _, effectName, unitTag, _, _, stackCount, _, _, effectType, abilityType, statusType, _, _, abilityId, sourceType)
    if changeType ~= EFFECT_RESULT_GAINED and changeType ~= EFFECT_RESULT_UPDATED then return end
    if not abilityId or abilityId == 0 then return end
    local store = E.sv.effectsSeen
    local e = store[abilityId]
    if not e then
        if E.effectsSeenCount >= E.EFFECTS_SEEN_MAX then return end
        e = { 0, 0, 0, 0, effectType, abilityType, statusType }
        store[abilityId] = e
        E.effectsSeenCount = E.effectsSeenCount + 1
    end
    e[1] = e[1] + 1
    e[2] = GetTimeStamp()
    local flags = e[3]
    local onPlayer = unitTag == "player"
    local bit = onPlayer and 1 or 2
    if flags % (bit * 2) < bit then flags = flags + bit end
    if sourceType == COMBAT_UNIT_TYPE_PLAYER and flags % 8 < 4 then flags = flags + 4 end
    e[3] = flags
    if (stackCount or 0) > e[4] then e[4] = stackCount end
end

function E.SetEffectTracking(on)
    E.trackEffects = on and true or false
    if E.sv then E.sv.trackEffects = E.trackEffects end
    if not EVENT_MANAGER then return end
    EVENT_MANAGER:UnregisterForEvent("ESQL_Effects", EVENT_EFFECT_CHANGED)
    if on then
        EVENT_MANAGER:RegisterForEvent("ESQL_Effects", EVENT_EFFECT_CHANGED, onEffectChanged)
    end
end

local function hasFlag(flags, bit) return (flags or 0) % (bit * 2) >= bit end

E.RegisterTable({
    name = "effects_seen",
    desc = "Every buff/debuff id seen while effect tracking is on (saved across sessions)",
    key = "ability_id",
    live = true,
    columns = {
        { "ability_id", "int", "Effect ability id" },
        { "name", "text", "Name", function(r) return abilityName(r.ability_id) end },
        { "times_seen", "int", "How often it was gained or refreshed" },
        { "last_seen", "int", "Unix time last seen" },
        { "on_player", "bool", "Seen on you" },
        { "on_others", "bool", "Seen on other units" },
        { "from_player", "bool", "Applied by you" },
        { "max_stacks", "int", "Highest stack count seen" },
        { "effect_type", "text", "buff or debuff" },
        { "ability_type", "text", "AbilityType name" },
        { "status_effect", "text", "Status effect" },
        { "duration_ms", "int", "Ability duration", function(r) return Try(GetAbilityDuration, r.ability_id) end },
        { "icon", "text", "Icon", function(r) return Try(GetAbilityIcon, r.ability_id) end },
    },
    build = function(rows)
        for id, e in pairs(E.sv and E.sv.effectsSeen or {}) do
            Tick()
            rows[#rows + 1] = {
                ability_id = id, times_seen = e[1], last_seen = e[2],
                on_player = hasFlag(e[3], 1), on_others = hasFlag(e[3], 2), from_player = hasFlag(e[3], 4),
                max_stacks = e[4],
                effect_type = e[5] and EnumShort("BUFF_EFFECT_TYPE_", e[5]),
                ability_type = e[6] and EnumShort("ABILITY_TYPE_", e[6]),
                status_effect = e[7] and e[7] ~= 0 and EnumShort("STATUS_EFFECT_TYPE_", e[7]) or nil,
            }
        end
    end,
})

---------------------------------------------------------------------------
-- combat_log: ring buffer of combat events (opt in: /esql log on)
---------------------------------------------------------------------------
E.COMBAT_LOG_MAX = E.isConsole and 5000 or 30000
E.combatLog = { first = 1, n = 0 }

local function onCombatEvent(_, result, isError, abilityName, _, slotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, _, sourceUnitId, targetUnitId, abilityId, overflow)
    local log = E.combatLog
    local entry = {
        t = GetGameTimeMilliseconds(), result = result, err = isError, name = abilityName,
        slot = slotType, src = sourceName, srcType = sourceType, tgt = targetName, tgtType = targetType,
        hit = hitValue, power = powerType, dmg = damageType, srcId = sourceUnitId, tgtId = targetUnitId,
        id = abilityId, over = overflow,
    }
    local max = E.COMBAT_LOG_MAX
    if log.n < max then
        log.n = log.n + 1
        log[log.n] = entry
    else
        log[log.first] = entry
        log.first = log.first % max + 1
    end
end

function E.SetCombatLogging(on)
    E.combatLogging = on and true or false
    if not EVENT_MANAGER then return end
    EVENT_MANAGER:UnregisterForEvent("ESQL_Combat", EVENT_COMBAT_EVENT)
    if on then
        EVENT_MANAGER:RegisterForEvent("ESQL_Combat", EVENT_COMBAT_EVENT, onCombatEvent)
    end
end

function E.ClearCombatLog() E.combatLog = { first = 1, n = 0 } end

local function unitTypeName(t)
    return t and EnumShort("COMBAT_UNIT_TYPE_", t)
end

E.RegisterTable({
    name = "combat_log",
    desc = "Combat events recorded this session while logging is on (/esql log on)",
    live = true,
    columns = {
        { "seq", "int", "Order received" },
        { "time_ms", "int", "Game time in ms" },
        { "result", "text", "damage, critical_damage, heal, dot_tick, blocked_damage, ..." },
        { "result_id", "int", "ActionResult enum value" },
        { "ability_id", "int", "Ability id" },
        { "ability", "text", "Ability name" },
        { "source", "text", "Source name" },
        { "source_type", "text", "player, group, other, player_pet..." },
        { "target", "text", "Target name" },
        { "target_type", "text", "player, group, other..." },
        { "hit", "int", "Damage / heal value" },
        { "overflow", "int", "Overkill / overheal" },
        { "damage_type", "text", "fire, shock, physical..." },
        { "power_type", "text", "Resource for power events" },
        { "is_error", "bool", "Error result" },
        { "source_unit_id", "int", "Source unit id" },
        { "target_unit_id", "int", "Target unit id" },
    },
    build = function(rows)
        local log = E.combatLog
        local max = E.COMBAT_LOG_MAX
        for k = 0, log.n - 1 do
            Tick()
            local idx = log.n < max and (k + 1) or ((log.first - 1 + k) % max + 1)
            local e = log[idx]
            rows[#rows + 1] = {
                seq = k + 1, time_ms = e.t, result_id = e.result,
                result = EnumShort("ACTION_RESULT_", e.result),
                ability_id = e.id, ability = Clean(e.name),
                source = Clean(e.src), source_type = unitTypeName(e.srcType),
                target = Clean(e.tgt), target_type = unitTypeName(e.tgtType),
                hit = e.hit, overflow = e.over,
                damage_type = e.dmg and EnumShort("DAMAGE_TYPE_", e.dmg),
                power_type = e.power and e.power >= 0 and EnumShort("COMBAT_MECHANIC_FLAGS_", e.power) or nil,
                is_error = e.err and true or false,
                source_unit_id = e.srcId, target_unit_id = e.tgtId,
            }
        end
    end,
})

---------------------------------------------------------------------------
-- hotbar
---------------------------------------------------------------------------
E.RegisterTable({
    name = "hotbar",
    desc = "Skills slotted on your front and back bars",
    live = true,
    columns = {
        { "bar", "text", "primary, backup, ..." },
        { "slot", "int", "Slot index (3-7 skills, 8 ultimate)" },
        { "ability_id", "int", "Slotted ability id" },
        { "name", "text", "Ability name" },
        { "icon", "text", "Icon", function(r) return Try(GetAbilityIcon, r.ability_id) end },
        { "active_bar", "bool", "This bar is active now" },
    },
    build = function(rows)
        local first = (ACTION_BAR_FIRST_NORMAL_SLOT_INDEX or 2) + 1
        local last = (ACTION_BAR_ULTIMATE_SLOT_INDEX or 7) + 1
        local active = Try(GetActiveHotbarCategory)
        local bars = { HOTBAR_CATEGORY_PRIMARY or 0, HOTBAR_CATEGORY_BACKUP or 1 }
        for _, extra in ipairs({ "HOTBAR_CATEGORY_OVERLOAD", "HOTBAR_CATEGORY_WEREWOLF", "HOTBAR_CATEGORY_COMPANION" }) do
            if _G[extra] then bars[#bars + 1] = _G[extra] end
        end
        for _, bar in ipairs(bars) do
            for slot = first, last do
                Tick()
                local id = Try(GetSlotBoundId, slot, bar)
                if id and id > 0 and ACTION_TYPE_CRAFTED_ABILITY and Try(GetSlotType, slot, bar) == ACTION_TYPE_CRAFTED_ABILITY then
                    id = Try(GetAbilityIdForCraftedAbilityId, id) or id
                end
                if id and id > 0 then
                    rows[#rows + 1] = {
                        bar = EnumShort("HOTBAR_CATEGORY_", bar), slot = slot, ability_id = id,
                        name = abilityName(id), active_bar = bar == active,
                    }
                end
            end
        end
    end,
})
