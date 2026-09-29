local CAM = CraftPawns
CAM.Scanner = {}
local S = CAM.Scanner

local function scanCraftLine(craft)
    local item = { key=craft.key, name=craft.name, rank=0, maxRank=50, passives={} }
    if type(GetCraftingSkillLineIndices) == "function" then
        local ok, skillType, lineIndex = pcall(GetCraftingSkillLineIndices, craft.type)
        if ok and skillType and lineIndex then
            local _, rank = GetSkillLineInfo(skillType, lineIndex)
            item.rank = tonumber(rank) or 0
            for abilityIndex=1, GetNumSkillAbilities(skillType, lineIndex) do
                local name, _, _, passive, _, purchased, _, abilityRank = GetSkillAbilityInfo(skillType, lineIndex, abilityIndex)
                if passive then item.passives[name] = { rank=purchased and (tonumber(abilityRank) or 1) or 0, index=abilityIndex } end
            end
        end
    end
    return item
end

function S:ScanResearchCraft(craftType)
    local result = { lines={}, slotCount=1, valid=false }
    if type(GetNumSmithingResearchLines) ~= "function" then return result end
    local ok, count = pcall(GetNumSmithingResearchLines, craftType)
    if not ok or not count or count < 1 then return result end
    local activeCount = 0
    for lineIndex=1, count do
        local success, name, icon, numTraits, nextDuration = pcall(GetSmithingResearchLineInfo, craftType, lineIndex)
        if success and numTraits then
            local line = { index=lineIndex, name=name, icon=icon, traits={}, knownCount=0, nextDuration=tonumber(nextDuration) }
            for traitIndex=1, numTraits do
                local tOk, traitType, _, known = pcall(GetSmithingResearchLineTraitInfo, craftType, lineIndex, traitIndex)
                if tOk then
                    local trait = { index=traitIndex, type=traitType, name=CAM:GetTraitName(traitType), known=known == true }
                    if trait.known then line.knownCount = line.knownCount + 1 end
                    if type(GetSmithingResearchLineTraitTimes) == "function" then
                        local timeOk, duration, remaining = pcall(GetSmithingResearchLineTraitTimes, craftType, lineIndex, traitIndex)
                        if timeOk and tonumber(remaining) and remaining > 0 then
                            trait.researching = true
                            line.currentResearch = { traitIndex=traitIndex, traitType=traitType,
                                name=(name or "Item").." — "..trait.name, duration=duration,
                                requisiteTime=duration, remaining=remaining,
                                startedAt=GetTimeStamp()-math.max(0,(duration or remaining)-remaining),
                                endsAt=GetTimeStamp()+remaining }
                            activeCount = activeCount + 1
                        end
                    end
                    line.traits[#line.traits+1] = trait
                end
            end
            result.lines[#result.lines+1] = line
        end
    end
    if type(GetMaxSimultaneousSmithingResearch) == "function" then
        local sOk, slots = pcall(GetMaxSimultaneousSmithingResearch, craftType)
        if sOk and tonumber(slots) then result.slotCount = math.max(1, slots) end
    else
        result.slotCount = math.max(1, activeCount)
    end
    result.activeCount = activeCount
    result.availableSlots = math.max(0,(result.slotCount or 1)-activeCount)
    result.valid = #result.lines == count
    return result
end

function S:BuildSnapshot()
    local id = tostring(GetCurrentCharacterId())
    local snapshot = { id=id, name=zo_strformat(SI_UNIT_NAME, GetUnitName("player")),
        account=GetDisplayName(), server=CAM.serverKey, scannedAt=GetTimeStamp(),
        version=CAM.snapshotVersion, schemaVersion=CAM.schemaVersion, crafts={}, research={} }
    for _, craft in ipairs(CAM.CRAFTS) do snapshot.crafts[craft.type] = scanCraftLine(craft) end
    for _, craftType in ipairs(CAM.RESEARCH_CRAFTS) do snapshot.research[craftType] = self:ScanResearchCraft(craftType) end
    snapshot.runes = CAM.Knowledge:ScanEnchanting()
    snapshot.alchemy = CAM.Knowledge:ScanAlchemy()
    snapshot.motifs = CAM.Knowledge:ScanMotifs()
    snapshot.provisioningRecipes = CAM.Knowledge:ScanProvisioningRecipes()
    snapshot.skillBuild = CAM.SkillPreset:Scan()
    snapshot.unspentPoints = CAM.SkillPreset:GetUnspentPoints()
    snapshot.totalAcquired = CAM.SkillPreset:GetTotalAcquired(snapshot.skillBuild)
    return snapshot
end

function S:Validate(snapshot)
    if not snapshot or not snapshot.id then return false, "Missing identity" end
    local craftCount=0; for _ in pairs(snapshot.crafts or {}) do craftCount=craftCount+1 end
    if craftCount ~= 7 then return false, "Not all seven craft lines initialized" end
    for _, craftType in ipairs(CAM.RESEARCH_CRAFTS) do
        if not snapshot.research[craftType] or not snapshot.research[craftType].valid then return false, "Research data incomplete" end
    end
    if not snapshot.runes or not snapshot.alchemy or not snapshot.motifs or not snapshot.skillBuild then return false, "Knowledge or skill data incomplete" end
    return true
end

function S:ScanAndCommit()
    local id = tostring(GetCurrentCharacterId())
    local ok, snapshot = pcall(function() return self:BuildSnapshot() end)
    if not ok then CAM.SavedData:MarkScanFailure(id, snapshot); return false, tostring(snapshot) end
    local valid, reason = self:Validate(snapshot)
    if not valid then
        -- Preserve any previously valid research section, but still allow a
        -- fresh identity/skills/knowledge scan to replace stale values.
        local old = CAM.server.characters[id] and CAM.server.characters[id].snapshot
        if old and old.research then
            snapshot.research = old.research
            snapshot.validationWarning = reason.."; previous research data retained"
            valid = true
        end
    end
    if not valid then CAM.SavedData:MarkScanFailure(id, reason); return false, reason end
    CAM.SavedData:CommitSnapshot(id, snapshot)
    if CAM.UI then CAM.UI:Refresh() end
    return true, "Scan complete"
end

function S:Initialize()
    local function delayedScan() zo_callLater(function() S:ScanAndCommit() end, 3500) end
    EVENT_MANAGER:RegisterForEvent(CAM.name.."Player", EVENT_PLAYER_ACTIVATED, delayedScan)
    local events = { EVENT_SKILL_RANK_UPDATE, EVENT_SKILL_POINTS_CHANGED, EVENT_SMITHING_TRAIT_RESEARCH_STARTED,
        EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED, EVENT_CRAFT_COMPLETED }
    for i, eventCode in ipairs(events) do
        if eventCode then EVENT_MANAGER:RegisterForEvent(CAM.name.."Live"..i, eventCode, function() zo_callLater(function() S:ScanAndCommit() end, 750) end) end
    end
end
