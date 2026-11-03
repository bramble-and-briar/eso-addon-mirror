-- ConsoleMetrics_Debug.lua
-- Diagnostic dumps triggered from slash commands and the build panel.
-- Nothing here runs during normal combat processing.

local CM = ConsoleMetrics
local Util = ConsoleMetrics.Util
local NumberText = Util.NumberText

local Build = ConsoleMetrics.Build
local BuildActionBarSnapshot = Build.BuildActionBarSnapshot
local BuildActiveBoonSnapshot = Build.BuildActiveBoonSnapshot
local BuildEquippedSetSummary = Build.BuildEquippedSetSummary
local BuildWeaponEffectSnapshot = Build.BuildWeaponEffectSnapshot

local Champion = ConsoleMetrics.Champion
local BuildChampionSnapshot = Champion.BuildChampionSnapshot


function ConsoleMetrics:DumpGameSets()
    -- Part 1: Enumerate all item sets via ESO item set API.
    local gameSetCount = 0
    if type(GetNumItemSets) == "function" then
        local numSets = 0
        local ok = pcall(function()
            numSets = GetNumItemSets()
        end)
        if ok and type(numSets) == "number" and numSets > 0 then
            gameSetCount = numSets
            self:Print(string.format("Enumerating %d item sets via GetNumItemSets...", numSets))
            for i = 1, numSets do
                local setName, numBonuses, numEquipped, maxEquipped, setId, isCrafted
                local ok2 = pcall(function()
                    setName, numBonuses, numEquipped, maxEquipped, setId, isCrafted = GetItemSetInfo(i)
                end)
                if ok2 and setName and setName ~= "" then
                    d(string.format(
                        "|cFF6A00[CM-Set]|r [%d] setId=%s name=%s bonuses=%d crafted=%s",
                        i,
                        tostring(setId or "?"),
                        setName,
                        tonumber(numBonuses) or 0,
                        tostring(isCrafted or false)
                    ))
                end
            end
        else
            self:Print("GetNumItemSets returned 0 or is unavailable in this context.")
        end
    else
        self:Print("GetNumItemSets not found in this ESO build.")
    end

    -- Part 2: Session-observed ability IDs accumulated from all combat events this session.
    local abilityCount = tonumber(self.observedAbilityCount) or 0
    if abilityCount <= 0 then
        for _ in pairs(self.observedAbilityLog or {}) do
            abilityCount = abilityCount + 1
        end
        self.observedAbilityCount = abilityCount
    end

    if abilityCount > 0 then
        self:Print(string.format("Session-observed unique abilities: %d", abilityCount))
        for abilityId, name in pairs(self.observedAbilityLog) do
            d(string.format("|cFF6A00[CM-Ability]|r id=%d name=%s", abilityId, name))
        end
    else
        self:Print("No abilities observed this session. Enter combat to populate ability ID log.")
    end

    if gameSetCount == 0 and abilityCount == 0 then
        self:Print("dumpsets: no data yet. Check ESO API availability or enter combat first.")
    end
end

function ConsoleMetrics:PrintBuildSnapshotDebug(reason)
    local source = reason or "manual"
    local frontBarCategory = type(HOTBAR_CATEGORY_PRIMARY) == "number" and HOTBAR_CATEGORY_PRIMARY or nil
    local backBarCategory = type(HOTBAR_CATEGORY_BACKUP) == "number" and HOTBAR_CATEGORY_BACKUP or nil
    local frontBar = BuildActionBarSnapshot(frontBarCategory)
    local backBar = BuildActionBarSnapshot(backBarCategory)
    local championSnapshot = BuildChampionSnapshot()
    local equippedSets = BuildEquippedSetSummary()
    local weaponEffects = BuildWeaponEffectSnapshot()
    local procTimers = self:BuildProcTimerSnapshot()
    local boons = BuildActiveBoonSnapshot()

    local function JoinOrFallback(values, fallback)
        if type(values) ~= "table" or #values == 0 then
            return fallback
        end
        return table.concat(values, ", ")
    end

    local function PrintBar(label, entries)
        self:Print(string.format("DEBUGBUILD [%s]", label))
        for i = 1, #entries do
            local entry = entries[i]
            self:Print(string.format(
                "  %s -> %s (id=%d)",
                entry.slotLabel or string.format("Slot %d", i),
                entry.abilityName or "Empty",
                entry.abilityId or 0
            ))
        end
    end

    local function PrintChampionBucket(label, entries)
        self:Print(string.format("DEBUGBUILD [%s]", label))
        if #entries == 0 then
            self:Print("  unavailable")
            return
        end
        for i = 1, #entries do
            local entry = entries[i]
            self:Print(string.format(
                "  %s pts=%s stars=%s",
                entry.name or "Unknown",
                NumberText(entry.points or 0),
                JoinOrFallback(entry.stars, "none")
            ))
            -- Print debug info when stars are missing (even if points show)
            if #(entry.stars or {}) == 0 and type(entry.debug) == "table" then
                self:Print(string.format(
                    "    probe disciplineId=%s index=%s type=%s",
                    tostring(entry.debug.disciplineId),
                    tostring(entry.debug.disciplineIndex),
                    tostring(entry.debug.disciplineType)
                ))
                local pointsProbes = entry.debug.pointsProbes or {}
                if #pointsProbes > 0 then
                    for j = 1, #pointsProbes do
                        self:Print("    " .. tostring(pointsProbes[j]))
                    end
                else
                    self:Print("    no discipline point probe results")
                end

                local skillPointProbes = entry.debug.skillPointProbes or {}
                if #skillPointProbes > 0 then
                    for j = 1, math.min(12, #skillPointProbes) do
                        self:Print("    " .. tostring(skillPointProbes[j]))
                    end
                else
                    self:Print("    no skill point probe results")
                end
            end
        end
        -- Print slot debug info at end of each bucket if any stars are missing
        if type(championSnapshot._slotDebugInfo) == "table" then
            local hasEmptyStars = false
            for i = 1, #entries do
                if #(entries[i].stars or {}) == 0 then
                    hasEmptyStars = true
                    break
                end
            end
            if hasEmptyStars then
                local foundIdsList = {}
                if type(championSnapshot._slotDebugInfo.foundIds) == "table" then
                    for id, _ in pairs(championSnapshot._slotDebugInfo.foundIds) do
                        foundIdsList[#foundIdsList + 1] = tostring(id)
                    end
                end
                self:Print(string.format(
                    "    SLOT DEBUG: numSlots=%s probeMax=%s foundIds=%s",
                    tostring(championSnapshot._slotDebugInfo.resolvedNumSlots),
                    tostring(championSnapshot._slotDebugInfo.probeMax),
                    #foundIdsList > 0 and table.concat(foundIdsList, ",") or "none"
                ))
                local probes = championSnapshot._slotDebugInfo.probes or {}
                if #probes > 0 then
                    for j = 1, math.min(12, #probes) do
                        self:Print("    " .. tostring(probes[j]))
                    end
                else
                    self:Print("    SLOT DEBUG: no probes found any slotted skills")
                end
            end
        end
    end

    self:Print(string.format(
        "DEBUGBUILD[%s] cp=%s sets=%d weapons=%d procs=%d boons=%d",
        source,
        championSnapshot.totalPoints and NumberText(championSnapshot.totalPoints) or "n/a",
        #equippedSets,
        #weaponEffects,
        #procTimers,
        #boons
    ))

    PrintBar("Front Bar", frontBar)
    PrintBar("Back Bar", backBar)
    PrintChampionBucket("Warfare", championSnapshot.warfare)
    PrintChampionBucket("Fitness", championSnapshot.fitness)
    PrintChampionBucket("Craft", championSnapshot.craft)

    self:Print("DEBUGBUILD [Equipped Sets]")
    if #equippedSets == 0 then
        self:Print("  unavailable")
    else
        for i = 1, #equippedSets do
            local entry = equippedSets[i]
            self:Print(string.format(
                "  %s (%d/%d) slots=%s",
                entry.setName or "Unknown Set",
                entry.numEquipped or 0,
                entry.maxEquipped or 0,
                JoinOrFallback(entry.slots, "none")
            ))
        end
    end

    self:Print("DEBUGBUILD [Weapon Effects]")
    if #weaponEffects == 0 then
        self:Print("  unavailable")
    else
        for i = 1, #weaponEffects do
            local entry = weaponEffects[i]
            self:Print(string.format(
                "  %s item=%s enchant=%s poison=%s",
                entry.label or string.format("Weapon %d", i),
                entry.itemText or "Unknown",
                entry.enchantText or "Unavailable",
                entry.poisonText or "None"
            ))
        end
    end

    self:Print("DEBUGBUILD [Proc Timers]")
    if #procTimers == 0 then
        self:Print("  unavailable")
    else
        for i = 1, #procTimers do
            local entry = procTimers[i]
            self:Print(string.format(
                "  %s state=%s cd=%.1fs equipped=%d/%d slots=%s pct=%s cm=%s",
                entry.label or "Unknown Proc",
                entry.stateText or "Ready",
                (entry.cooldownMs or 0) / 1000,
                entry.numEquipped or 0,
                entry.maxEquipped or 0,
                JoinOrFallback(entry.slots, "none"),
                tostring(entry.fromPCT == true),
                tostring(entry.fromCustomRule == true)
            ))
        end
    end

    self:Print("DEBUGBUILD [Boon / Mundus]")
    if #boons == 0 then
        self:Print("  unavailable")
    else
        for i = 1, #boons do
            self:Print(string.format("  %s", boons[i]))
        end
    end
end
