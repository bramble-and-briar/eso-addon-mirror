-- ConsoleMetrics_Sets.lua
-- Set proc detection: the curated popular-set catalog, heuristic proc
-- classification, user-defined custom set rules, PvPCooldownTracker import
-- and the proc timer snapshot shown on the build panel.

local CM = ConsoleMetrics
local Util = ConsoleMetrics.Util
local SafeAbilityId = Util.SafeAbilityId
local TrimText = Util.TrimText

local Build = ConsoleMetrics.Build
local BuildEquippedSetSummary = Build.BuildEquippedSetSummary


---------------------------------------------------------------------------
-- Curated set catalog
---------------------------------------------------------------------------
-- Curated set aliases used to classify common PvE/PvP proc names in combat events.
local POPULAR_SET_CATALOG = {
    { label = "Pillar of Nirn", scene = "PvE", aliases = { "pillar of nirn", "nirn" } },
    { label = "Whorl of the Depths", scene = "PvE", aliases = { "whorl of the depths", "whorl" } },
    { label = "Arms of Relequen", scene = "PvE", aliases = { "arms of relequen", "relequen" } },
    { label = "Aegis Caller", scene = "PvE", aliases = { "aegis caller", "aegis" } },
    { label = "Mantle of Siroria", scene = "PvE", aliases = { "mantle of siroria", "siroria" } },
    { label = "Zaan", scene = "PvE", aliases = { "zaan" } },
    { label = "Coral Riptide", scene = "PvE", aliases = { "coral riptide", "riptide" } },
    { label = "Kinras's Wrath", scene = "PvE", aliases = { "kinras", "kinras's wrath" } },
    { label = "Bahsei's Mania", scene = "PvE", aliases = { "bahsei", "bahsei's mania" } },
    { label = "Azureblight Reaper", scene = "PvE", aliases = { "azureblight", "azureblight reaper" } },
    { label = "Rallying Cry", scene = "PvP", aliases = { "rallying cry", "rallying" } },
    { label = "Mara's Balm", scene = "PvP", aliases = { "mara's balm", "maras balm" } },
    { label = "Daedric Trickery", scene = "PvP", aliases = { "daedric trickery", "trickery" } },
    { label = "Plaguebreak", scene = "PvP", aliases = { "plaguebreak" } },
    { label = "Vicious Death", scene = "PvP", aliases = { "vicious death" } },
    { label = "Dark Convergence", scene = "PvP", aliases = { "dark convergence", "convergence" } },
    { label = "Wretched Vitality", scene = "PvP", aliases = { "wretched vitality", "wretched" } },
    { label = "Mark of the Pariah", scene = "PvP", aliases = { "pariah", "mark of the pariah" } },
    { label = "Hrothgar's Chill", scene = "PvP", aliases = { "hrothgar", "hrothgar's chill" } },
    { label = "Balorgh", scene = "PvP", aliases = { "balorgh" } },
}

-- Heuristic keywords to surface likely set procs beyond the curated catalog.
local LIKELY_SET_PROC_KEYWORDS = {
    "set",
    "proc",
    "nirn",
    "relequen",
    "siroria",
    "balorgh",
    "pariah",
    "hrothgar",
    "trickery",
    "vitality",
    "convergence",
    "plague",
    "semblance",
    "opportunist",
    "slayer",
    "whisper",
    "ward",
}

-- Bounded memo cache for ClassifyLikelySetProc (keyed by lower-cased ability name).
local LIKELY_SET_PROC_CACHE = {}
local LIKELY_SET_PROC_CACHE_SIZE = 0
local LIKELY_SET_PROC_CACHE_MAX = 512

function ConsoleMetrics:ResetLikelySetProcCache()
    LIKELY_SET_PROC_CACHE = {}
    LIKELY_SET_PROC_CACHE_SIZE = 0
end


---------------------------------------------------------------------------
-- Set matching and proc classification
---------------------------------------------------------------------------
local function MatchPopularSet(abilityName)
    if not abilityName or abilityName == "" then
        return nil
    end

    local lower = string.lower(abilityName)
    for i = 1, #POPULAR_SET_CATALOG do
        local entry = POPULAR_SET_CATALOG[i]
        for j = 1, #entry.aliases do
            local alias = entry.aliases[j]
            if string.find(lower, alias, 1, true) ~= nil then
                return entry
            end
        end
    end

    return nil
end

local function NormalizeCustomSetScene(scene)
    local lower = string.lower(TrimText(scene))
    if lower == "" then
        return "PvP"
    end
    if lower == "pve" then
        return "PvE"
    end
    if lower == "pvp" then
        return "PvP"
    end
    return "Custom"
end

local function BuildCustomAliasList(abilityName)
    local aliases = {}
    local base = string.lower(TrimText(abilityName))
    if base == "" then
        return aliases
    end

    aliases[#aliases + 1] = base
    for token in string.gmatch(base, "[^,%|;]+") do
        local clean = TrimText(token)
        if clean ~= "" then
            local exists = false
            for i = 1, #aliases do
                if aliases[i] == clean then
                    exists = true
                    break
                end
            end
            if not exists then
                aliases[#aliases + 1] = clean
            end
        end
    end

    return aliases
end

local function ClassifyLikelySetProc(abilityName)
    if not abilityName or abilityName == "" then
        return false, nil, 0
    end

    local lower = string.lower(abilityName)
    local cached = LIKELY_SET_PROC_CACHE[lower]
    if cached then
        return cached.matched, cached.reason, cached.score
    end

    local function CacheResult(matched, reason, score)
        LIKELY_SET_PROC_CACHE[lower] = {
            matched = matched,
            reason = reason,
            score = score,
        }
        LIKELY_SET_PROC_CACHE_SIZE = LIKELY_SET_PROC_CACHE_SIZE + 1
        if LIKELY_SET_PROC_CACHE_SIZE > LIKELY_SET_PROC_CACHE_MAX then
            LIKELY_SET_PROC_CACHE = {}
            LIKELY_SET_PROC_CACHE_SIZE = 0
        end
        return matched, reason, score
    end

    -- Keep curated matching authoritative and separate from heuristic rows.
    if MatchPopularSet(abilityName) then
        return CacheResult(false, nil, 0)
    end

    local score = 0
    local reasons = {}

    for i = 1, #LIKELY_SET_PROC_KEYWORDS do
        local keyword = LIKELY_SET_PROC_KEYWORDS[i]
        if string.find(lower, keyword, 1, true) ~= nil then
            score = score + 1
            reasons[#reasons + 1] = keyword
        end
    end

    if string.find(lower, "'s ", 1, true) ~= nil then
        score = score + 1
        reasons[#reasons + 1] = "possessive"
    end

    if string.find(lower, " of ", 1, true) ~= nil then
        score = score + 0.5
        reasons[#reasons + 1] = "name pattern"
    end

    if score < 1.5 then
        return CacheResult(false, nil, score)
    end

    return CacheResult(true, table.concat(reasons, ", "), score)
end

---------------------------------------------------------------------------
-- Custom set rules and PvPCooldownTracker import
---------------------------------------------------------------------------
local function RuleToMatchResult(rule, safeId)
    return {
        label            = rule.label or string.format("Custom Set %d", safeId),
        scene            = NormalizeCustomSetScene(rule.scene),
        fromCustom       = not rule.fromPCT,
        fromPCT          = rule.fromPCT or false,
        cooldownDurationMs = rule.cooldownDurationMs,
        procType         = rule.procType,
        result           = rule.result,
        texture          = rule.texture,
        showFrame        = rule.showFrame,
        description      = rule.description,
        settingsColor    = rule.settingsColor,
    }
end

function ConsoleMetrics:MatchCustomSetRule(abilityId, abilityName)
    if not self.saved or type(self.saved.customSetRules) ~= "table" then
        return nil
    end

    local safeId = SafeAbilityId(abilityId)
    local lowerName = string.lower(abilityName or "")

    -- Prefer exact abilityId match first; check primary abilityId and all entries in abilityIds.
    if safeId > 0 then
        for i = 1, #self.saved.customSetRules do
            local rule = self.saved.customSetRules[i]
            -- Check primary stored ID.
            if SafeAbilityId(rule.abilityId) == safeId then
                return RuleToMatchResult(rule, safeId)
            end
            -- Check multi-ID list (PCT sets like Pirate Skeleton).
            if type(rule.abilityIds) == "table" then
                for k = 1, #rule.abilityIds do
                    if SafeAbilityId(rule.abilityIds[k]) == safeId then
                        return RuleToMatchResult(rule, safeId)
                    end
                end
            end
        end
    end

    if lowerName == "" then
        return nil
    end

    for i = 1, #self.saved.customSetRules do
        local rule = self.saved.customSetRules[i]
        local aliases = rule.aliases
        if type(aliases) ~= "table" then
            aliases = BuildCustomAliasList(rule.abilityName)
            rule.aliases = aliases
        end
        for j = 1, #aliases do
            local alias = aliases[j]
            if alias ~= "" and string.find(lowerName, alias, 1, true) ~= nil then
                return RuleToMatchResult(rule, SafeAbilityId(rule.abilityId))
            end
        end
    end

    return nil
end

function ConsoleMetrics:InvalidateTrackedSetMatchCache()
    self.trackedSetMatchById = {}
    self.trackedSetMatchByName = {}
end

function ConsoleMetrics:MatchTrackedSet(abilityId, abilityName)
    local byId = self.trackedSetMatchById
    if type(byId) ~= "table" then
        byId = {}
        self.trackedSetMatchById = byId
    end

    local byName = self.trackedSetMatchByName
    if type(byName) ~= "table" then
        byName = {}
        self.trackedSetMatchByName = byName
    end

    local safeId = SafeAbilityId(abilityId)
    if safeId > 0 then
        local cachedById = byId[safeId]
        if cachedById ~= nil then
            return cachedById or nil
        end
    end

    local lowerName = string.lower(abilityName or "")
    if lowerName ~= "" then
        local cachedByName = byName[lowerName]
        if cachedByName ~= nil then
            if safeId > 0 then
                byId[safeId] = cachedByName
            end
            return cachedByName or nil
        end
    end

    local matched = self:MatchCustomSetRule(safeId, abilityName)
    if not matched then
        matched = MatchPopularSet(abilityName)
    end

    local cachedValue = matched or false
    if safeId > 0 then
        byId[safeId] = cachedValue
    end
    if lowerName ~= "" then
        byName[lowerName] = cachedValue
    end

    return matched
end

function ConsoleMetrics:AddCustomSetRule(label, scene, abilityId, abilityName)
    if not self.saved then
        return false, "Settings are not initialized yet."
    end

    self.saved.customSetRules = self.saved.customSetRules or {}

    local cleanName = TrimText(abilityName)
    local cleanLabel = TrimText(label)
    local safeId = SafeAbilityId(abilityId)
    local normalizedScene = NormalizeCustomSetScene(scene)

    if cleanLabel == "" then
        if cleanName ~= "" then
            cleanLabel = cleanName
        elseif safeId > 0 then
            cleanLabel = string.format("Custom Set %d", safeId)
        else
            return false, "Add Custom Set: provide ability ID and/or ability name."
        end
    end

    if safeId <= 0 and cleanName == "" then
        return false, "Add Custom Set: provide ability ID and/or ability name."
    end

    local aliases = BuildCustomAliasList(cleanName)
    for i = 1, #self.saved.customSetRules do
        local existing = self.saved.customSetRules[i]
        local existingId = SafeAbilityId(existing.abilityId)
        local existingName = string.lower(TrimText(existing.abilityName))
        if safeId > 0 and existingId == safeId then
            return false, string.format("Custom set already exists for ability ID %d.", safeId)
        end
        if cleanName ~= "" and existingName ~= "" and existingName == string.lower(cleanName) then
            return false, string.format("Custom set already exists for ability name '%s'.", cleanName)
        end
    end

    self.saved.customSetRules[#self.saved.customSetRules + 1] = {
        label    = cleanLabel,
        scene    = normalizedScene,
        abilityId = safeId,
        abilityIds = { safeId },
        abilityName = cleanName,
        aliases  = aliases,
        fromCustom = true,
    }

    self:InvalidateTrackedSetMatchCache()

    return true, string.format("Added custom set rule: %s (scene=%s, id=%d, name=%s)", cleanLabel, normalizedScene, safeId, cleanName ~= "" and cleanName or "n/a")
end

-- Import one full PvPCooldownTracker Data.Sets entry by set name key.
-- Handles id as number or array, carries all PCT fields verbatim.
function ConsoleMetrics:AddPCTSetEntry(setName, entry)
    if not self.saved then
        return false, "Settings not initialized."
    end

    self.saved.customSetRules = self.saved.customSetRules or {}

    local cleanLabel = TrimText(setName)
    if cleanLabel == "" then
        return false, "PCT entry has no set name."
    end

    -- Deduplicate by normalized label.
    local lowerLabel = string.lower(cleanLabel)
    for i = 1, #self.saved.customSetRules do
        if string.lower(TrimText(self.saved.customSetRules[i].label)) == lowerLabel then
            return false, string.format("Already have rule for '%s'.", cleanLabel)
        end
    end

    -- Normalise id: may be number or array of numbers.
    local primaryId = 0
    local allIds = {}
    if type(entry.id) == "table" then
        for _, v in ipairs(entry.id) do
            local sid = SafeAbilityId(v)
            if sid > 0 then
                allIds[#allIds + 1] = sid
            end
        end
        primaryId = allIds[1] or 0
    else
        primaryId = SafeAbilityId(entry.id)
        if primaryId > 0 then
            allIds[1] = primaryId
        end
    end

    -- Derive scene from procType (synergies/passives -> PvE leaning; sets -> PvP default).
    local scene = "PvP"
    if type(entry.procType) == "string" then
        local pt = string.lower(entry.procType)
        if pt == "synergy" or pt == "passive" then
            scene = "PvE"
        end
    end

    self.saved.customSetRules[#self.saved.customSetRules + 1] = {
        label              = cleanLabel,
        scene              = scene,
        abilityId          = primaryId,
        abilityIds         = allIds,
        abilityName        = "",
        aliases            = {},
        fromPCT            = true,
        -- Full PCT fields preserved:
        cooldownDurationMs = tonumber(entry.cooldownDurationMs),
        procType           = type(entry.procType) == "string" and entry.procType or nil,
        result             = tonumber(entry.result),
        texture            = type(entry.texture) == "string" and entry.texture or nil,
        showFrame          = entry.showFrame ~= false,
        description        = type(entry.description) == "string" and entry.description or nil,
        settingsColor      = type(entry.settingsColor) == "string" and entry.settingsColor or nil,
    }

    self:InvalidateTrackedSetMatchCache()

    return true, string.format("Imported: %s (id=%d, cooldown=%sms)",
        cleanLabel, primaryId, tostring(tonumber(entry.cooldownDurationMs) or "?"))
end

function ConsoleMetrics:ImportSetsFromPvPCooldownTracker()
    if not self.saved then
        return 0, "Settings are not initialized yet."
    end

    -- Primary path: PvPCooldownTracker.Data.Sets is the canonical structured source.
    -- Each key is the set display name; value contains id, cooldownDurationMs, procType, result, etc.
    local g = type(_G) == "table" and _G or nil
    local pct = g and g.PvPCooldownTracker or nil
    local dataTable = pct and type(pct.Data) == "table" and pct.Data.Sets or nil

    if type(dataTable) ~= "table" then
        return 0, "PvPCooldownTracker.Data.Sets not found. Ensure PvPCooldownTracker is loaded before importing."
    end

    local addedCount = 0
    local skippedCount = 0
    local messages = {}

    for setName, entry in pairs(dataTable) do
        if type(setName) == "string" and type(entry) == "table" then
            local ok, msg = self:AddPCTSetEntry(setName, entry)
            if ok then
                addedCount = addedCount + 1
            else
                skippedCount = skippedCount + 1
                -- Only collect non-duplicate skip messages for debugging.
                if not string.find(msg, "Already have rule", 1, true) then
                    messages[#messages + 1] = msg
                end
            end
        end
    end

    if addedCount == 0 and skippedCount == 0 then
        return 0, "PvPCooldownTracker.Data.Sets is empty."
    end

    if addedCount == 0 then
        return 0, string.format("No new entries imported (%d already present).", skippedCount)
    end

    local summary = string.format("Imported %d set rules from PvPCooldownTracker", addedCount)
    if skippedCount > 0 then
        summary = summary .. string.format(" (%d already present, skipped)", skippedCount)
    end
    summary = summary .. "."

    if #messages > 0 then
        for i = 1, math.min(5, #messages) do
            self:Print("PCT import: " .. messages[i])
        end
    end

    return addedCount, summary
end

---------------------------------------------------------------------------
-- Proc timers
---------------------------------------------------------------------------
function ConsoleMetrics:FindCustomSetRuleByLabel(label)
    if type(label) ~= "string" or label == "" then
        return nil
    end
    if not self.saved or type(self.saved.customSetRules) ~= "table" then
        return nil
    end

    local lowerLabel = string.lower(TrimText(label))
    for i = 1, #self.saved.customSetRules do
        local rule = self.saved.customSetRules[i]
        if type(rule) == "table" and string.lower(TrimText(rule.label or "")) == lowerLabel then
            return rule
        end
    end

    return nil
end

function ConsoleMetrics:BuildProcTimerSnapshot(nowMs)
    local entries = {}
    local seen = {}
    local currentMs = nowMs
    if type(currentMs) ~= "number" then
        if type(GetGameTimeMilliseconds) == "function" then
            currentMs = GetGameTimeMilliseconds()
        else
            currentMs = GetFrameTimeMilliseconds()
        end
    end

    local g = type(_G) == "table" and _G or nil
    local pctData = g and g.PvPCooldownTracker and g.PvPCooldownTracker.Data and g.PvPCooldownTracker.Data.Sets or nil
    local equippedSets = BuildEquippedSetSummary()

    local function AddEntry(label, equippedInfo)
        if type(label) ~= "string" or label == "" then
            return
        end

        local lowerLabel = string.lower(label)
        if seen[lowerLabel] then
            return
        end

        local rule = self:FindCustomSetRuleByLabel(label)
        local pctEntry = pctData and pctData[label] or nil
        local track = self.fight and self.fight.setEffects and self.fight.setEffects[lowerLabel] or nil
        if not rule and not pctEntry and not track then
            return
        end

        seen[lowerLabel] = true
        local cooldownMs = tonumber((pctEntry and pctEntry.cooldownDurationMs) or (rule and rule.cooldownDurationMs)) or 0
        local onCooldown = pctEntry and pctEntry.onCooldown or false
        local procTimeMs = tonumber(pctEntry and pctEntry.timeOfProc) or 0
        local remainingMs = 0
        if onCooldown and cooldownMs > 0 and procTimeMs > 0 then
            remainingMs = math.max(0, (procTimeMs + cooldownMs) - currentMs)
        end

        local stateText = "Ready"
        if track and track.activeSinceMs then
            if remainingMs > 0 then
                stateText = string.format("Active | Ready %.1fs", remainingMs / 1000)
            else
                stateText = "Active"
            end
        elseif remainingMs > 0 then
            stateText = string.format("Ready %.1fs", remainingMs / 1000)
        end

        entries[#entries + 1] = {
            label = label,
            stateText = stateText,
            cooldownMs = cooldownMs,
            remainingMs = remainingMs,
            numEquipped = equippedInfo and equippedInfo.numEquipped or 0,
            maxEquipped = equippedInfo and equippedInfo.maxEquipped or 0,
            slots = equippedInfo and equippedInfo.slots or {},
            fromPCT = pctEntry ~= nil,
            fromCustomRule = rule ~= nil,
        }
    end

    for i = 1, #equippedSets do
        AddEntry(equippedSets[i].setName, equippedSets[i])
    end

    for i = 1, #(self.saved and self.saved.customSetRules or {}) do
        local rule = self.saved.customSetRules[i]
        if type(rule) == "table" and type(rule.label) == "string" and rule.label ~= "" then
            AddEntry(rule.label, nil)
        end
    end

    table.sort(entries, function(a, b)
        local function Rank(entry)
            if string.find(entry.stateText or "", "Active", 1, true) ~= nil then
                return 1
            end
            if (entry.remainingMs or 0) > 0 then
                return 2
            end
            return 3
        end

        local rankA = Rank(a)
        local rankB = Rank(b)
        if rankA == rankB then
            return tostring(a.label) < tostring(b.label)
        end
        return rankA < rankB
    end)

    return entries
end

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------

ConsoleMetrics.Sets = {
    BuildCustomAliasList = BuildCustomAliasList,
    ClassifyLikelySetProc = ClassifyLikelySetProc,
    LIKELY_SET_PROC_KEYWORDS = LIKELY_SET_PROC_KEYWORDS,
    MatchPopularSet = MatchPopularSet,
    NormalizeCustomSetScene = NormalizeCustomSetScene,
    POPULAR_SET_CATALOG = POPULAR_SET_CATALOG,
    RuleToMatchResult = RuleToMatchResult,
}
