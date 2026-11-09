-- SkillExport.lua
-- Reads every skill line, skill, morph and passive the game exposes and turns it into
-- a list of text chunks, each small enough for one QR code. The phone (or a video of the
-- TV) collects all chunks and joins them back together.
--
-- Text format: one record per line, fields separated by tabs.
--   H  version  apiVersion  language  exportingClassId  timestamp
--   C  classId  className
--   L  skillLineId  skillType  classId  name  accessible(1/0)
--   A  skillLineId  skillIndex  kind  abilityId  baseAbilityId  rank
--        kind: B = base active, M1/M2 = morphs, U = ultimate base, P = passive (highest rank; rank = number of ranks),
--              S = scribed skill (grimoire); baseAbilityId holds the craftedAbilityId, rank is 1 if scribed
--   G  craftedAbilityId  name  icon  scribed(1/0)  activeScripts(" · ")  description   (format 3)
--   D  abilityId  name  icon  passive  ultimate  target  minRange  maxRange  radius  duration
--        castTime  channeled  costMagicka  costStamina  costHealth  costUltimate  header  description  newEffects
--        perTickMagicka  perTickStamina  perTickHealth  tickMs   (format 3: per-tick costs of channelled / toggled skills)
--
-- Each QR chunk starts with a header line:  ESOCS1 <runId> <index>/<total>

ESOC_SkillExport = ESOC_SkillExport or {}
local EX = ESOC_SkillExport

local function clean(s)
    s = tostring(s or "")
    -- drop colour codes (|cffffff...|r) and inline textures (|t...|t): about 10% of the data
    s = s:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|t[^|]*|t", "")
    s = s:gsub("\r", ""):gsub("\t", " "):gsub("\n", "\\n")
    return s
end

EX.clean = clean

local function shortIcon(path)
    path = tostring(path or "")
    path = path:gsub("^/esoui/art/icons/", ""):gsub("%.dds$", "")
    return path
end

local function safe(fn, ...)
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
    return nil
end

-- Names of the scripts currently scribed on a grimoire, e.g. "Physical Damage · Taunt · Savagery and Prophecy".
function EX.ScriptNames(craftedId)
    local names = {}
    local ids = { safe(GetCraftedAbilityActiveScriptIds, craftedId) }
    for i = 1, 3 do
        local sid = ids[i]
        if sid and sid ~= 0 then
            local n = safe(GetCraftedAbilityScriptDisplayName, sid)
            if n and n ~= "" then names[#names + 1] = n end
        end
    end
    return table.concat(names, " · ")
end

-- Build the full export text. Calls yield() between skill lines so work is spread over frames.
function EX.Collect(yield)
    yield = yield or function() end
    local out = {}
    local function row(...)
        local t = { ... }
        for i = 1, #t do t[i] = clean(t[i]) end
        out[#out + 1] = table.concat(t, "\t")
    end
    local abilitiesSeen = {}
    local function describe(id)
        if not id or id == 0 or abilitiesSeen[id] then return end
        abilitiesSeen[id] = true
        local minR, maxR = safe(GetAbilityRange, id)
        local channeled, castMs = safe(GetAbilityCastInfo, id)
        local costs = {}
        pcall(function()
            local flag = GetNextAbilityMechanicFlag(id, nil)
            local guard = 0
            while flag and guard < 8 do
                costs[flag] = GetAbilityCost(id, flag, nil, "player") or 0
                flag = GetNextAbilityMechanicFlag(id, flag)
                guard = guard + 1
            end
        end)
        local RESOURCES = { COMBAT_MECHANIC_FLAGS_MAGICKA, COMBAT_MECHANIC_FLAGS_STAMINA, COMBAT_MECHANIC_FLAGS_HEALTH, COMBAT_MECHANIC_FLAGS_ULTIMATE }
        local any = false
        for _, f in pairs(costs) do if f > 0 then any = true end end
        if not any then
            -- Some skills don't list their resource through GetNextAbilityMechanicFlag: ask for each one directly,
            -- then fall back to the base cost (which also says which resource it uses).
            for _, f in ipairs(RESOURCES) do
                local c = safe(GetAbilityCost, id, f, nil, "player")
                if c and c > 0 then costs[f] = c; any = true end
            end
            if not any then
                local base, flags = safe(GetAbilityBaseCostInfo, id, nil, "player")
                if base and base > 0 and flags then
                    for _, f in ipairs(RESOURCES) do
                        if f == flags or (BitAnd and BitAnd(flags, f) ~= 0) then costs[f] = base; break end
                    end
                end
            end
        end
        local function cost(flag)
            if flag == nil then return 0 end
            return costs[flag] or 0
        end
        -- Channelled and toggled skills (Radiant Destruction, Shadow Cloak, Meditate...) charge per tick.
        local function perTick(flag)
            if flag == nil then return 0 end
            return safe(GetAbilityCostPerTick, id, flag, nil) or 0
        end
        local newFx = {}
        pcall(function()
            local lines = { GetAbilityNewEffectLines(id) }
            for i = 1, #lines do newFx[#newFx + 1] = lines[i] end
        end)
        row("D", id,
            safe(GetAbilityName, id) or "",
            shortIcon(safe(GetAbilityIcon, id)),
            (safe(IsAbilityPassive, id) and 1 or 0),
            (safe(IsAbilityUltimate, id) and 1 or 0),
            safe(GetAbilityTargetDescription, id) or "",
            minR or 0, maxR or 0,
            safe(GetAbilityRadius, id) or 0,
            safe(GetAbilityDuration, id) or 0,
            castMs or 0, channeled and 1 or 0,
            cost(COMBAT_MECHANIC_FLAGS_MAGICKA), cost(COMBAT_MECHANIC_FLAGS_STAMINA),
            cost(COMBAT_MECHANIC_FLAGS_HEALTH), cost(COMBAT_MECHANIC_FLAGS_ULTIMATE),
            safe(GetAbilityDescriptionHeader, id) or "",
            safe(GetAbilityDescription, id) or "",
            table.concat(newFx, " || "),
            perTick(COMBAT_MECHANIC_FLAGS_MAGICKA), perTick(COMBAT_MECHANIC_FLAGS_STAMINA),
            perTick(COMBAT_MECHANIC_FLAGS_HEALTH), safe(GetAbilityFrequencyMS, id, "player") or 0)
    end

    local function exportLine(lineId, skillType, lineIndex, classId)
        local name = safe(GetSkillLineNameById, lineId) or ""
        if not skillType or not lineIndex then
            row("L", lineId, 0, classId or 0, name, 0)
            return
        end
        row("L", lineId, skillType, classId or 0, name, 1)
        local n = safe(GetNumSkillAbilities, skillType, lineIndex) or 0
        for si = 1, n do
            local _, _, _, passive, ultimate, _, progressionIndex = safe(GetSkillAbilityInfo, skillType, lineIndex, si)
            local craftedId = safe(IsCraftedAbilitySkill, skillType, lineIndex, si) and safe(GetCraftedAbilitySkillCraftedAbilityId, skillType, lineIndex, si)
            if craftedId and craftedId ~= 0 then
                -- Scribing grimoire: no morphs; its ability follows the scripts chosen at the Scribing Altar
                local id = safe(GetAbilityIdForCraftedAbilityId, craftedId)
                if id and id ~= 0 then
                    local scribed = safe(IsCraftedAbilityScribed, craftedId) and 1 or 0
                    row("A", lineId, si, "S", id, craftedId, scribed)
                    row("G", craftedId, safe(GetCraftedAbilityDisplayName, craftedId) or "", shortIcon(safe(GetCraftedAbilityIcon, craftedId)),
                        scribed, EX.ScriptNames(craftedId), safe(GetCraftedAbilityDescription, craftedId) or "")
                    describe(id)
                end
            elseif passive then
                local ranks = math.max(1, safe(GetNumPassiveSkillRanks, skillType, lineIndex, si) or 1)
                local id = safe(GetSpecificSkillAbilityInfo, skillType, lineIndex, si, 0, ranks)
                if id and id ~= 0 then
                    row("A", lineId, si, "P", id, 0, ranks)
                    describe(id)
                end
            else
                local progressionId = safe(GetProgressionSkillProgressionId, skillType, lineIndex, si)
                local baseId, m1, m2
                if progressionId and progressionId ~= 0 then
                    baseId = safe(GetProgressionSkillMorphSlotAbilityId, progressionId, MORPH_SLOT_BASE)
                    m1 = safe(GetProgressionSkillMorphSlotAbilityId, progressionId, MORPH_SLOT_MORPH_1)
                    m2 = safe(GetProgressionSkillMorphSlotAbilityId, progressionId, MORPH_SLOT_MORPH_2)
                end
                if not baseId or baseId == 0 then
                    baseId = safe(GetSpecificSkillAbilityInfo, skillType, lineIndex, si, 0, 1)
                    m1 = m1 or safe(GetSpecificSkillAbilityInfo, skillType, lineIndex, si, 1, 1)
                    m2 = m2 or safe(GetSpecificSkillAbilityInfo, skillType, lineIndex, si, 2, 1)
                end
                if baseId and baseId ~= 0 then
                    row("A", lineId, si, ultimate and "U" or "B", baseId, 0, 1)
                    describe(baseId)
                    if m1 and m1 ~= 0 then row("A", lineId, si, "M1", m1, baseId, 1) describe(m1) end
                    if m2 and m2 ~= 0 then row("A", lineId, si, "M2", m2, baseId, 1) describe(m2) end
                end
            end
        end
    end

    row("H", 3, safe(GetAPIVersion) or 0, safe(GetCVar, "language.2") or "", safe(GetUnitClassId, "player") or 0, safe(GetTimeStamp) or 0)

    local linesDone = {}
    -- Every class's skill lines (works with subclassing even for other classes, if the game allows it)
    local numClasses = safe(GetNumClasses) or 0
    for ci = 1, numClasses do
        local classId = safe(GetClassInfo, ci)
        if classId then
            local className = ""
            pcall(function() className = zo_strformat("<<1>>", GetClassName(GENDER_MALE, classId)) end)
            row("C", classId, className)
            for li = 1, (safe(GetNumSkillLinesForClass, classId) or 0) do
                local lineId = safe(GetSkillLineIdForClass, classId, li)
                if lineId and not linesDone[lineId] then
                    linesDone[lineId] = true
                    local skillType, lineIndex = safe(GetSkillLineIndicesFromSkillLineId, lineId)
                    exportLine(lineId, skillType, lineIndex, classId)
                    yield()
                end
            end
        end
    end
    -- Everything else: weapon, armor, world, guild, Alliance War, racial.
    -- Crafting and Champion lines are skipped: not needed for builds, and they add a lot of text.
    local skip = { [SKILL_TYPE_TRADESKILL or -1] = true, [SKILL_TYPE_CHAMPION or -1] = true }
    for skillType = 1, (safe(GetNumSkillTypes) or 0) do
        if not skip[skillType] then
            for lineIndex = 1, (safe(GetNumSkillLines, skillType) or 0) do
                local lineId = safe(GetSkillLineId, skillType, lineIndex)
                if lineId and not linesDone[lineId] then
                    linesDone[lineId] = true
                    exportLine(lineId, skillType, lineIndex, safe(GetSkillLineClassId, skillType, lineIndex) or 0)
                    yield()
                end
            end
        end
    end
    return table.concat(out, "\n")
end

-- Split text into chunks of at most maxBytes, never cutting through a multi-byte character.
function EX.Chunk(text, maxBytes, runId, prefix)
    prefix = prefix or "ESOCS1"
    local chunks, pos, len = {}, 1, #text
    while pos <= len do
        local stop = math.min(len, pos + maxBytes - 1)
        if stop < len then
            -- prefer to break after a newline
            local nl = text:sub(pos, stop):match(".*()\n")
            if nl and nl > maxBytes / 2 then
                stop = pos + nl - 1
            else
                -- otherwise back up to a plain ASCII byte
                while stop > pos and text:byte(stop + 1) and text:byte(stop + 1) >= 0x80 and text:byte(stop + 1) < 0xC0 do
                    stop = stop - 1
                end
            end
        end
        chunks[#chunks + 1] = text:sub(pos, stop)
        pos = stop + 1
    end
    for i = 1, #chunks do
        chunks[i] = string.format("%s %s %d/%d\n", prefix, runId, i, #chunks) .. chunks[i]
    end
    return chunks
end
