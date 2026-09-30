local PBE = PacketByteExporter
PBE.Collectors = {}
local Collectors = PBE.Collectors
local Object = PBE.Codec.Object

local function Global(name)
    return _G and _G[name] or nil
end

local function CallNamed(name, ...)
    return PBE.Safe(Global(name), ...)
end

local function MultiNamed(name, ...)
    return PBE.SafeMulti(Global(name), ...)
end

local function AddNamedConstant(target, label, constantName, fn)
    local constant = Global(constantName)
    if constant ~= nil and type(fn) == "function" then
        local value = PBE.Safe(fn, constant)
        if value ~= nil then
            target[label] = value
        end
    end
end

local function CollectSystem(profile)
    return {
        addonVersion = PBE.version,
        apiVersion = PBE.Safe(GetAPIVersion),
        capturedAt = PBE.Now(),
        gamepadMode = PBE.Safe(IsInGamepadPreferredMode),
        platformService = PBE.Safe(GetPlatformServiceType),
        profile = profile,
        schemaVersion = PBE.schemaVersion,
        world = PBE.Safe(GetWorldName),
    }
end

local function CollectIdentity()
    local settings = PBE.GetSettings()
    local raceId = PBE.Safe(GetUnitRaceId, "player")
    local classId = PBE.Safe(GetUnitClassId, "player")
    local allianceId = PBE.Safe(GetUnitAlliance, "player")
    local genderId = PBE.Safe(GetUnitGender, "player")
    local identity = {
        alliance = PBE.CleanText(PBE.Safe(GetAllianceName, allianceId)),
        allianceId = allianceId,
        characterId = tostring(PBE.Safe(GetCurrentCharacterId) or ""),
        class = PBE.CleanText(PBE.Safe(GetUnitClass, "player")),
        classId = classId,
        genderId = genderId,
        level = PBE.Safe(GetUnitLevel, "player") or 0,
        name = PBE.CleanText(PBE.Safe(GetUnitName, "player")),
        race = PBE.CleanText(PBE.Safe(GetUnitRace, "player")),
        raceId = raceId,
        title = PBE.CleanText(PBE.Safe(GetUnitTitle, "player")),
        championPointsEarned = PBE.Safe(GetPlayerChampionPointsEarned) or 0,
        experience = PBE.Safe(GetUnitXP, "player") or 0,
        experienceMax = PBE.Safe(GetUnitXPMax, "player") or 0,
    }
    if settings.includeAccountName then
        identity.accountName = PBE.Safe(GetDisplayName)
    end
    if settings.includeLocation then
        local zoneIndex = PBE.Safe(GetUnitZoneIndex, "player")
        identity.location = Object({
            subzone = PBE.CleanText(PBE.Safe(GetPlayerActiveSubzoneName)),
            zone = PBE.CleanText(PBE.Safe(GetUnitZone, "player")),
            zoneId = zoneIndex and PBE.Safe(GetZoneId, zoneIndex) or nil,
            zoneIndex = zoneIndex,
        })
    end
    return identity
end

local function CollectAttributes()
    local attributes = {
        unspent = PBE.Safe(GetAttributeUnspentPoints) or 0,
        spent = Object(),
    }
    AddNamedConstant(attributes.spent, "health", "ATTRIBUTE_HEALTH", GetAttributeSpentPoints)
    AddNamedConstant(attributes.spent, "magicka", "ATTRIBUTE_MAGICKA", GetAttributeSpentPoints)
    AddNamedConstant(attributes.spent, "stamina", "ATTRIBUTE_STAMINA", GetAttributeSpentPoints)
    return attributes
end

local statNames = {
    { "healthMax", "STAT_HEALTH_MAX" },
    { "magickaMax", "STAT_MAGICKA_MAX" },
    { "staminaMax", "STAT_STAMINA_MAX" },
    { "healthRecovery", "STAT_HEALTH_REGEN_COMBAT" },
    { "magickaRecovery", "STAT_MAGICKA_REGEN_COMBAT" },
    { "staminaRecovery", "STAT_STAMINA_REGEN_COMBAT" },
    { "weaponDamage", "STAT_POWER" },
    { "spellDamage", "STAT_SPELL_POWER" },
    { "weaponCritical", "STAT_CRITICAL_STRIKE" },
    { "spellCritical", "STAT_SPELL_CRITICAL" },
    { "physicalPenetration", "STAT_PHYSICAL_PENETRATION" },
    { "spellPenetration", "STAT_SPELL_PENETRATION" },
    { "physicalResistance", "STAT_PHYSICAL_RESIST" },
    { "spellResistance", "STAT_SPELL_RESIST" },
    { "criticalResistance", "STAT_CRITICAL_RESISTANCE" },
    { "criticalDamage", "STAT_CRITICAL_DAMAGE" },
    { "criticalHealing", "STAT_CRITICAL_HEALING" },
    { "healingDone", "STAT_HEALING_DONE" },
    { "healingTaken", "STAT_HEALING_TAKEN" },
    { "damageDone", "STAT_DAMAGE_DONE" },
    { "damageTaken", "STAT_DAMAGE_TAKEN" },
    { "blockMitigation", "STAT_BLOCK_MITIGATION" },
    { "blockCost", "STAT_BLOCK_COST" },
    { "bashDamage", "STAT_BASH_DAMAGE" },
    { "bashCost", "STAT_BASH_COST" },
    { "sprintCost", "STAT_SPRINT_COST" },
    { "sprintSpeed", "STAT_SPRINT_SPEED" },
}

local function CollectStats()
    local stats = Object()
    local function GetDisplayedStat(statType)
        return PBE.Safe(GetPlayerStat, statType, Global("STAT_BONUS_OPTION_APPLY_BONUS"))
    end
    for _, entry in ipairs(statNames) do
        AddNamedConstant(stats, entry[1], entry[2], GetDisplayedStat)
    end
    return stats
end

local function CollectEffects()
    local effects = {}
    local count = PBE.Safe(GetNumBuffs, "player") or 0
    for index = 1, count do
        local ok, name, started, ending, slot, stacks, _, _, effectType, abilityType, statusEffectType, abilityId,
            canClickOff, castByPlayer = PBE.SafeMulti(GetUnitBuffInfo, "player", index)
        if ok and name and name ~= "" then
            effects[#effects + 1] = {
                abilityId = abilityId,
                abilityType = abilityType,
                canClickOff = canClickOff,
                castByPlayer = castByPlayer,
                effectType = effectType,
                ending = ending,
                name = PBE.CleanText(name),
                slot = slot,
                stacks = stacks,
                started = started,
                statusEffectType = statusEffectType,
            }
        end
    end
    return effects
end

local equipmentSlots = {
    { "head", "EQUIP_SLOT_HEAD" },
    { "chest", "EQUIP_SLOT_CHEST" },
    { "shoulders", "EQUIP_SLOT_SHOULDERS" },
    { "waist", "EQUIP_SLOT_WAIST" },
    { "legs", "EQUIP_SLOT_LEGS" },
    { "feet", "EQUIP_SLOT_FEET" },
    { "hands", "EQUIP_SLOT_HAND" },
    { "neck", "EQUIP_SLOT_NECK" },
    { "ring1", "EQUIP_SLOT_RING1" },
    { "ring2", "EQUIP_SLOT_RING2" },
    { "mainHand", "EQUIP_SLOT_MAIN_HAND" },
    { "offHand", "EQUIP_SLOT_OFF_HAND" },
    { "backupMain", "EQUIP_SLOT_BACKUP_MAIN" },
    { "backupOff", "EQUIP_SLOT_BACKUP_OFF" },
}

local function CollectEquippedItem(label, slot, bagId)
    bagId = bagId or BAG_WORN
    local link = PBE.Safe(GetItemLink, bagId, slot, LINK_STYLE_DEFAULT) or ""
    if link == "" then
        return { slot = label, slotId = slot, empty = true }
    end

    local _, icon, stack, sellPrice, meetsRequirement, locked, equipType, itemStyleId, functionalQuality,
        displayQuality = PBE.SafeMulti(GetItemInfo, bagId, slot)
    local _, traitType, traitDescription = PBE.SafeMulti(GetItemLinkTraitInfo, link)
    local _, hasSet, setName, numBonuses, normalEquipped, maxEquipped, setId, perfectedEquipped =
        PBE.SafeMulti(GetItemLinkSetInfo, link, true)
    local _, hasCharges, enchantName, enchantDescription = PBE.SafeMulti(GetItemLinkEnchantInfo, link)

    return {
        championPoints = PBE.Safe(GetItemLinkRequiredChampionPoints, link),
        displayQuality = displayQuality,
        enchant = Object({
            description = PBE.CleanText(enchantDescription),
            hasCharges = hasCharges,
            name = PBE.CleanText(enchantName),
        }),
        equipType = equipType,
        functionalQuality = functionalQuality,
        icon = icon,
        itemId = PBE.Safe(GetItemLinkItemId, link),
        level = PBE.Safe(GetItemLinkRequiredLevel, link),
        link = link,
        locked = locked,
        meetsRequirement = meetsRequirement,
        name = PBE.CleanText(PBE.Safe(GetItemName, bagId, slot)),
        sellPrice = sellPrice,
        set = Object({
            bonuses = numBonuses,
            equipped = normalEquipped,
            hasSet = hasSet,
            id = setId,
            maxEquipped = maxEquipped,
            name = PBE.CleanText(setName),
            perfectedEquipped = perfectedEquipped,
        }),
        slot = label,
        slotId = slot,
        stack = stack,
        styleId = itemStyleId or PBE.Safe(GetItemLinkItemStyle, link),
        trait = Object({
            description = PBE.CleanText(traitDescription),
            id = traitType,
        }),
    }
end

local function CollectEquipment()
    local equipment = {}
    for _, entry in ipairs(equipmentSlots) do
        local slot = Global(entry[2])
        if slot ~= nil then
            equipment[#equipment + 1] = CollectEquippedItem(entry[1], slot)
        end
    end
    return equipment
end

local function CollectMundus()
    local mundus = {}
    local ok, firstIndex, secondIndex = PBE.SafeMulti(GetUnitActiveMundusStoneBuffIndices, "player")
    if not ok then
        return mundus
    end
    for _, buffIndex in ipairs({ firstIndex, secondIndex }) do
        if buffIndex and buffIndex > 0 then
            local buffOk, name, _, _, _, _, _, _, _, _, _, abilityId =
                PBE.SafeMulti(GetUnitBuffInfo, "player", buffIndex)
            if buffOk and name and name ~= "" then
                mundus[#mundus + 1] = {
                    abilityId = abilityId,
                    name = PBE.CleanText(name):gsub("^Boon:%s*", ""),
                }
            end
        end
    end
    return mundus
end

local function CollectCompanion()
    local hasActive = PBE.Safe(HasActiveCompanion) == true
    local companion = { hasActive = hasActive }
    if not hasActive then
        return companion
    end

    local rapport = PBE.Safe(GetActiveCompanionRapportLevel)
    companion.active = Object({
        definitionId = PBE.Safe(GetActiveCompanionDefId),
        level = PBE.Safe(GetUnitLevel, "companion"),
        name = PBE.CleanText(PBE.Safe(GetUnitName, "companion")),
        rapport = rapport,
        rapportDescription = rapport and PBE.CleanText(
            PBE.Safe(GetActiveCompanionRapportLevelDescription, rapport)
        ) or nil,
    })

    companion.bar = {}
    local category = Global("HOTBAR_CATEGORY_COMPANION")
    if category ~= nil then
        for slot = 3, 8 do
            local abilityId = PBE.Safe(GetSlotBoundId, slot, category) or 0
            companion.bar[#companion.bar + 1] = {
                abilityId = abilityId,
                name = abilityId > 0 and PBE.CleanText(PBE.Safe(GetAbilityName, abilityId, "player")) or nil,
                slot = slot,
            }
        end
    end

    companion.equipment = {}
    local bagId = Global("BAG_COMPANION_WORN")
    if bagId ~= nil then
        for _, entry in ipairs(equipmentSlots) do
            local isPlayerOnlySlot = entry[1] == "neck" or entry[1] == "ring1" or entry[1] == "ring2"
                or entry[1] == "backupMain" or entry[1] == "backupOff"
            if not isPlayerOnlySlot then
                local slot = Global(entry[2])
                if slot ~= nil then
                    companion.equipment[#companion.equipment + 1] = CollectEquippedItem(entry[1], slot, bagId)
                end
            end
        end
    end
    return companion
end

local function CollectBars()
    local startSlot, endSlot
    local ok
    ok, startSlot, endSlot = PBE.SafeMulti(GetAssignableAbilityBarStartAndEndSlots)
    if not ok then
        startSlot = 3
        endSlot = 8
    end

    local configurations = {
        { name = "primary", category = Global("HOTBAR_CATEGORY_PRIMARY") },
        { name = "backup", category = Global("HOTBAR_CATEGORY_BACKUP") },
    }
    local bars = {
        activeCategory = PBE.Safe(GetActiveHotbarCategory),
        actionBars = {},
        championBar = {},
    }

    for _, config in ipairs(configurations) do
        if config.category ~= nil then
            local bar = { name = config.name, category = config.category, slots = {} }
            for slot = startSlot, endSlot do
                local abilityId = PBE.Safe(GetSlotBoundId, slot, config.category) or 0
                bar.slots[#bar.slots + 1] = {
                    abilityId = abilityId,
                    name = abilityId > 0 and PBE.CleanText(PBE.Safe(GetAbilityName, abilityId, "player")) or nil,
                    slot = slot,
                    slotType = PBE.Safe(GetSlotType, slot, config.category),
                }
            end
            bars.actionBars[#bars.actionBars + 1] = bar
        end
    end

    local championCategory = Global("HOTBAR_CATEGORY_CHAMPION")
    local cpOk, cpStart, cpEnd = PBE.SafeMulti(GetAssignableChampionBarStartAndEndSlots)
    if cpOk and championCategory ~= nil then
        for slot = cpStart, cpEnd do
            local skillId = PBE.Safe(GetSlotBoundId, slot, championCategory) or 0
            bars.championBar[#bars.championBar + 1] = {
                name = skillId > 0 and PBE.CleanText(PBE.Safe(GetChampionSkillName, skillId)) or nil,
                skillId = skillId,
                slot = slot,
            }
        end
    end
    return bars
end

local function CollectArmory()
    local builds = {}
    local count = PBE.Safe(GetNumUnlockedArmoryBuilds) or 0
    local barOk, startSlot, endSlot = PBE.SafeMulti(GetAssignableAbilityBarStartAndEndSlots)
    if not barOk then
        startSlot = 3
        endSlot = 8
    end
    local barDefinitions = {
        { name = "primary", category = Global("HOTBAR_CATEGORY_PRIMARY") },
        { name = "backup", category = Global("HOTBAR_CATEGORY_BACKUP") },
    }

    for buildIndex = 1, count do
        local build = {
            attributes = Object(),
            bars = {},
            champion = {},
            curseType = PBE.Safe(GetArmoryBuildCurseType, buildIndex),
            equipment = {},
            iconIndex = PBE.Safe(GetArmoryBuildIconIndex, buildIndex),
            index = buildIndex,
            mundus = Object({
                primary = PBE.Safe(GetArmoryBuildPrimaryMundusStone, buildIndex),
                secondary = PBE.Safe(GetArmoryBuildSecondaryMundusStone, buildIndex),
            }),
            name = PBE.CleanText(PBE.Safe(GetArmoryBuildName, buildIndex)),
            outfitIndex = PBE.Safe(GetArmoryBuildEquippedOutfitIndex, buildIndex),
            skillPointsSpent = PBE.Safe(GetArmoryBuildSkillsTotalSpentPoints, buildIndex),
        }
        AddNamedConstant(build.attributes, "health", "ATTRIBUTE_HEALTH", function(attribute)
            return PBE.Safe(GetArmoryBuildAttributeSpentPoints, buildIndex, attribute)
        end)
        AddNamedConstant(build.attributes, "magicka", "ATTRIBUTE_MAGICKA", function(attribute)
            return PBE.Safe(GetArmoryBuildAttributeSpentPoints, buildIndex, attribute)
        end)
        AddNamedConstant(build.attributes, "stamina", "ATTRIBUTE_STAMINA", function(attribute)
            return PBE.Safe(GetArmoryBuildAttributeSpentPoints, buildIndex, attribute)
        end)

        local disciplineCount = PBE.Safe(GetNumChampionDisciplines) or 0
        for disciplineIndex = 1, disciplineCount do
            local disciplineId = PBE.Safe(GetChampionDisciplineId, disciplineIndex)
            build.champion[#build.champion + 1] = {
                id = disciplineId,
                name = PBE.CleanText(PBE.Safe(GetChampionDisciplineName, disciplineId)),
                spent = PBE.Safe(GetArmoryBuildChampionSpentPointsByDiscipline, buildIndex, disciplineId),
            }
        end

        for _, definition in ipairs(barDefinitions) do
            if definition.category ~= nil then
                local bar = { name = definition.name, category = definition.category, slots = {} }
                for slot = startSlot, endSlot do
                    local abilityId = PBE.Safe(
                        GetArmoryBuildSlotBoundId,
                        buildIndex,
                        slot,
                        definition.category
                    ) or 0
                    bar.slots[#bar.slots + 1] = {
                        abilityId = abilityId,
                        name = abilityId > 0 and PBE.CleanText(PBE.Safe(GetAbilityName, abilityId, "player")) or nil,
                        slot = slot,
                    }
                end
                build.bars[#build.bars + 1] = bar
            end
        end

        for _, entry in ipairs(equipmentSlots) do
            local equipSlot = Global(entry[2])
            if equipSlot ~= nil then
                local infoOk, state, bagId, slotIndex =
                    PBE.SafeMulti(GetArmoryBuildEquipSlotInfo, buildIndex, equipSlot)
                if infoOk then
                    local item = { slot = entry[1], slotId = equipSlot, state = state }
                    if bagId ~= nil and slotIndex ~= nil then
                        item = CollectEquippedItem(entry[1], slotIndex, bagId)
                        item.armoryState = state
                        item.equipSlotId = equipSlot
                        item.sourceBagId = bagId
                        item.sourceSlotIndex = slotIndex
                    end
                    build.equipment[#build.equipment + 1] = item
                end
            end
        end
        builds[#builds + 1] = build
    end
    return builds
end

local activeCollectibleTypes = {
    { "mount", "COLLECTIBLE_CATEGORY_TYPE_MOUNT" },
    { "pet", "COLLECTIBLE_CATEGORY_TYPE_VANITY_PET" },
    { "costume", "COLLECTIBLE_CATEGORY_TYPE_COSTUME" },
    { "hat", "COLLECTIBLE_CATEGORY_TYPE_HAT" },
    { "skin", "COLLECTIBLE_CATEGORY_TYPE_SKIN" },
    { "personality", "COLLECTIBLE_CATEGORY_TYPE_PERSONALITY" },
    { "polymorph", "COLLECTIBLE_CATEGORY_TYPE_POLYMORPH" },
    { "hair", "COLLECTIBLE_CATEGORY_TYPE_HAIR" },
    { "facialHair", "COLLECTIBLE_CATEGORY_TYPE_FACIAL_HAIR_HORNS" },
    { "adornment", "COLLECTIBLE_CATEGORY_TYPE_FACIAL_ACCESSORY" },
}

local function CollectActiveCollectibles()
    local result = Object()
    local actor = Global("GAMEPLAY_ACTOR_CATEGORY_PLAYER")
    if actor == nil then
        return result
    end
    for _, definition in ipairs(activeCollectibleTypes) do
        local categoryType = Global(definition[2])
        if categoryType ~= nil then
            local collectibleId = PBE.Safe(GetActiveCollectibleByType, categoryType, actor)
            if collectibleId and collectibleId > 0 then
                local ok, name, description, _, _, unlocked, purchasable, active =
                    PBE.SafeMulti(GetCollectibleInfo, collectibleId)
                if ok then
                    result[definition[1]] = {
                        active = active,
                        description = PBE.CleanText(description),
                        id = collectibleId,
                        name = PBE.CleanText(name),
                        nickname = PBE.CleanText(PBE.Safe(GetCollectibleNickname, collectibleId)),
                        purchasable = purchasable,
                        unlocked = unlocked,
                    }
                end
            end
        end
    end
    local outfitIndex = PBE.Safe(GetEquippedOutfitIndex, actor)
    result.outfit = Object({
        index = outfitIndex,
        name = outfitIndex and PBE.CleanText(PBE.Safe(GetOutfitName, actor, outfitIndex)) or nil,
    })
    return result
end

local function SkillTypeName(skillType)
    local value = PBE.Safe(GetString, "SI_SKILLTYPE", skillType)
    if value and value ~= "" then
        return PBE.CleanText(value)
    end
    return tostring(skillType)
end

local function CollectSkills(includeLocked)
    local result = {
        availablePoints = PBE.Safe(GetAvailableSkillPoints) or 0,
        types = {},
    }
    local typeCount = PBE.Safe(GetNumSkillTypes) or 0
    for skillType = 1, typeCount do
        local typeData = { id = skillType, name = SkillTypeName(skillType), lines = {} }
        local lineCount = PBE.Safe(GetNumSkillLines, skillType) or 0
        for lineIndex = 1, lineCount do
            local lineOk, rank, advised, active, discovered, accountSkill, inTraining =
                PBE.SafeMulti(GetSkillLineDynamicInfo, skillType, lineIndex)
            if lineOk and discovered then
                local lineId = PBE.Safe(GetSkillLineId, skillType, lineIndex)
                local xpOk, lastRankXp, nextRankXp, currentXp =
                    PBE.SafeMulti(GetSkillLineXPInfo, skillType, lineIndex)
                local line = {
                    accountSkill = accountSkill,
                    active = active,
                    advised = advised,
                    id = lineId,
                    inTraining = inTraining,
                    name = PBE.CleanText(PBE.Safe(GetSkillLineNameById, lineId)),
                    rank = rank,
                    skills = {},
                    xp = xpOk and Object({
                        current = currentXp, lastRank = lastRankXp, nextRank = nextRankXp,
                    }) or nil,
                }
                local abilityCount = PBE.Safe(GetNumSkillAbilities, skillType, lineIndex) or 0
                for abilityIndex = 1, abilityCount do
                    local abilityOk, name, _, earnedRank, passive, ultimate, purchased, progressionIndex, rankValue =
                        PBE.SafeMulti(GetSkillAbilityInfo, skillType, lineIndex, abilityIndex)
                    if abilityOk and name and (purchased or includeLocked) then
                        local progressionId = PBE.Safe(
                            GetProgressionSkillProgressionId,
                            skillType,
                            lineIndex,
                            abilityIndex
                        ) or progressionIndex
                        local morph = progressionId and PBE.Safe(GetProgressionSkillCurrentMorphSlot, progressionId) or nil
                        local upgrade, maxUpgrade
                        local upgradeOk
                        upgradeOk, upgrade, maxUpgrade = PBE.SafeMulti(
                            GetSkillAbilityUpgradeInfo,
                            skillType,
                            lineIndex,
                            abilityIndex
                        )
                        local skill = {
                            abilityId = PBE.Safe(GetSkillAbilityId, skillType, lineIndex, abilityIndex, false),
                            earnedRank = earnedRank,
                            index = abilityIndex,
                            maxUpgrade = upgradeOk and maxUpgrade or nil,
                            morph = morph,
                            name = PBE.CleanText(name),
                            passive = passive,
                            progressionId = progressionId,
                            purchased = purchased,
                            rank = rankValue,
                            ultimate = ultimate,
                            upgrade = upgradeOk and upgrade or nil,
                        }
                        local isCrafted = PBE.Safe(IsCraftedAbilitySkill, skillType, lineIndex, abilityIndex)
                        if isCrafted then
                            local craftedId = PBE.Safe(
                                GetCraftedAbilitySkillCraftedAbilityId,
                                skillType,
                                lineIndex,
                                abilityIndex
                            )
                            local scriptsOk, primaryId, secondaryId, tertiaryId =
                                PBE.SafeMulti(GetCraftedAbilityActiveScriptIds, craftedId)
                            local scriptIds = scriptsOk and { primaryId, secondaryId, tertiaryId } or {}
                            local scripts = {}
                            for _, scriptId in ipairs(scriptIds) do
                                if scriptId and scriptId > 0 then
                                    scripts[#scripts + 1] = {
                                        id = scriptId,
                                        name = PBE.CleanText(PBE.Safe(GetCraftedAbilityScriptDisplayName, scriptId)),
                                        slot = PBE.Safe(GetCraftedAbilityScriptScribingSlot, scriptId),
                                    }
                                end
                            end
                            skill.crafted = {
                                id = craftedId,
                                name = PBE.CleanText(PBE.Safe(GetCraftedAbilityDisplayName, craftedId)),
                                scripts = scripts,
                            }
                        end
                        line.skills[#line.skills + 1] = skill
                    end
                end
                line.skillsIncluded = #line.skills
                typeData.lines[#typeData.lines + 1] = line
            end
        end
        if #typeData.lines > 0 then
            result.types[#result.types + 1] = typeData
        end
    end
    return result
end

local function NewSkillsStepper(includeLocked)
    local state = {
        result = {
            availablePoints = PBE.Safe(GetAvailableSkillPoints) or 0,
            types = {},
        },
        typeCount = PBE.Safe(GetNumSkillTypes) or 0,
        typeIndex = 1,
        phase = "type",
    }
    function state:step(limit)
        local remaining = math.max(1, limit or 1)
        while remaining > 0 do
            remaining = remaining - 1
            if self.phase == "type" then
                if self.typeIndex > self.typeCount then
                    return true, self.result
                end
                self.typeData = {
                    id = self.typeIndex,
                    name = SkillTypeName(self.typeIndex),
                    lines = {},
                }
                self.lineCount = PBE.Safe(GetNumSkillLines, self.typeIndex) or 0
                self.lineIndex = 1
                self.phase = "line"
            elseif self.phase == "line" then
                if self.lineIndex > self.lineCount then
                    if #self.typeData.lines > 0 then
                        self.result.types[#self.result.types + 1] = self.typeData
                    end
                    self.typeData = nil
                    self.typeIndex = self.typeIndex + 1
                    self.phase = "type"
                else
                    local ok, rank, advised, active, discovered, accountSkill, inTraining =
                        PBE.SafeMulti(GetSkillLineDynamicInfo, self.typeIndex, self.lineIndex)
                    if ok and discovered then
                        local lineId = PBE.Safe(GetSkillLineId, self.typeIndex, self.lineIndex)
                        local xpOk, lastRankXp, nextRankXp, currentXp =
                            PBE.SafeMulti(GetSkillLineXPInfo, self.typeIndex, self.lineIndex)
                        self.line = {
                            accountSkill = accountSkill,
                            active = active,
                            advised = advised,
                            id = lineId,
                            inTraining = inTraining,
                            name = PBE.CleanText(PBE.Safe(GetSkillLineNameById, lineId)),
                            rank = rank,
                            skills = {},
                            xp = xpOk and Object({
                                current = currentXp, lastRank = lastRankXp, nextRank = nextRankXp,
                            }) or nil,
                        }
                        self.abilityCount = PBE.Safe(GetNumSkillAbilities, self.typeIndex, self.lineIndex) or 0
                        self.abilityIndex = 1
                        self.phase = "ability"
                    else
                        self.lineIndex = self.lineIndex + 1
                    end
                end
            else -- ability
                if self.abilityIndex > self.abilityCount then
                    self.line.skillsIncluded = #self.line.skills
                    self.typeData.lines[#self.typeData.lines + 1] = self.line
                    self.line = nil
                    self.lineIndex = self.lineIndex + 1
                    self.phase = "line"
                else
                    local abilityIndex = self.abilityIndex
                    self.abilityIndex = abilityIndex + 1
                    local ok, name, _, earnedRank, passive, ultimate, purchased, progressionIndex, rankValue =
                        PBE.SafeMulti(GetSkillAbilityInfo, self.typeIndex, self.lineIndex, abilityIndex)
                    if ok and name and (purchased or includeLocked) then
                        local progressionId = PBE.Safe(
                            GetProgressionSkillProgressionId,
                            self.typeIndex, self.lineIndex, abilityIndex
                        ) or progressionIndex
                        local morph = progressionId and PBE.Safe(GetProgressionSkillCurrentMorphSlot, progressionId) or nil
                        local upgrade, maxUpgrade
                        local upgradeOk
                        upgradeOk, upgrade, maxUpgrade = PBE.SafeMulti(
                            GetSkillAbilityUpgradeInfo,
                            self.typeIndex, self.lineIndex, abilityIndex
                        )
                        local skill = {
                            abilityId = PBE.Safe(GetSkillAbilityId, self.typeIndex, self.lineIndex, abilityIndex, false),
                            earnedRank = earnedRank,
                            index = abilityIndex,
                            maxUpgrade = upgradeOk and maxUpgrade or nil,
                            morph = morph,
                            name = PBE.CleanText(name),
                            passive = passive,
                            progressionId = progressionId,
                            purchased = purchased,
                            rank = rankValue,
                            ultimate = ultimate,
                            upgrade = upgradeOk and upgrade or nil,
                        }
                        local isCrafted = PBE.Safe(IsCraftedAbilitySkill, self.typeIndex, self.lineIndex, abilityIndex)
                        if isCrafted then
                            local craftedId = PBE.Safe(
                                GetCraftedAbilitySkillCraftedAbilityId,
                                self.typeIndex, self.lineIndex, abilityIndex
                            )
                            local scriptsOk, primaryId, secondaryId, tertiaryId =
                                PBE.SafeMulti(GetCraftedAbilityActiveScriptIds, craftedId)
                            local scriptIds = scriptsOk and { primaryId, secondaryId, tertiaryId } or {}
                            local scripts = {}
                            for _, scriptId in ipairs(scriptIds) do
                                if scriptId and scriptId > 0 then
                                    scripts[#scripts + 1] = {
                                        id = scriptId,
                                        name = PBE.CleanText(PBE.Safe(GetCraftedAbilityScriptDisplayName, scriptId)),
                                        slot = PBE.Safe(GetCraftedAbilityScriptScribingSlot, scriptId),
                                    }
                                end
                            end
                            skill.crafted = {
                                id = craftedId,
                                name = PBE.CleanText(PBE.Safe(GetCraftedAbilityDisplayName, craftedId)),
                                scripts = scripts,
                            }
                        end
                        self.line.skills[#self.line.skills + 1] = skill
                    end
                end
            end
        end
        return false
    end
    return state
end

local function CollectChampion()
    local champion = {
        earned = PBE.Safe(GetPlayerChampionPointsEarned) or 0,
        disciplines = {},
    }
    local disciplineCount = PBE.Safe(GetNumChampionDisciplines) or 0
    for disciplineIndex = 1, disciplineCount do
        local disciplineId = PBE.Safe(GetChampionDisciplineId, disciplineIndex)
        local discipline = {
            id = disciplineId,
            index = disciplineIndex,
            name = PBE.CleanText(PBE.Safe(GetChampionDisciplineName, disciplineId)),
            skills = {},
            spent = PBE.Safe(GetNumSpentChampionPoints, disciplineId),
            unspent = PBE.Safe(GetNumUnspentChampionPoints, disciplineId),
        }
        local skillCount = PBE.Safe(GetNumChampionDisciplineSkills, disciplineIndex) or 0
        for skillIndex = 1, skillCount do
            local skillId = PBE.Safe(GetChampionSkillId, disciplineIndex, skillIndex)
            local points = skillId and PBE.Safe(GetNumPointsSpentOnChampionSkill, skillId) or 0
            if points and points > 0 then
                discipline.skills[#discipline.skills + 1] = {
                    id = skillId,
                    max = PBE.Safe(GetChampionSkillMaxPoints, skillId),
                    name = PBE.CleanText(PBE.Safe(GetChampionSkillName, skillId)),
                    points = points,
                    type = PBE.Safe(GetChampionSkillType, skillId),
                }
            end
        end
        champion.disciplines[#champion.disciplines + 1] = discipline
    end
    champion.enlightenment = Object({
        available = PBE.Safe(IsEnlightenedAvailableForCharacter),
        pool = PBE.Safe(GetEnlightenedPool),
    })
    return champion
end

local currencyDefinitions = {
    { "gold", "CURT_MONEY", "CURRENCY_LOCATION_CHARACTER" },
    { "alliancePoints", "CURT_ALLIANCE_POINTS", "CURRENCY_LOCATION_CHARACTER" },
    { "telVar", "CURT_TELVAR_STONES", "CURRENCY_LOCATION_CHARACTER" },
    { "writVouchers", "CURT_WRIT_VOUCHERS", "CURRENCY_LOCATION_CHARACTER" },
    { "transmuteCrystals", "CURT_TRANSMUTE_CRYSTALS", "CURRENCY_LOCATION_ACCOUNT" },
    { "crowns", "CURT_CROWNS", "CURRENCY_LOCATION_ACCOUNT" },
    { "crownGems", "CURT_CROWN_GEMS", "CURRENCY_LOCATION_ACCOUNT" },
    { "endeavorSeals", "CURT_ENDEAVOR_SEALS", "CURRENCY_LOCATION_ACCOUNT" },
    { "eventTickets", "CURT_EVENT_TICKETS", "CURRENCY_LOCATION_ACCOUNT" },
    { "undauntedKeys", "CURT_UNDAUNTED_KEYS", "CURRENCY_LOCATION_ACCOUNT" },
    { "outfitTokens", "CURT_STYLE_STONES", "CURRENCY_LOCATION_ACCOUNT" },
    { "archivalFortunes", "CURT_ARCHIVAL_FORTUNES", "CURRENCY_LOCATION_ACCOUNT" },
    { "imperialFragments", "CURT_IMPERIAL_FRAGMENTS", "CURRENCY_LOCATION_ACCOUNT" },
}

local function CollectCurrencies()
    local currencies = Object()
    for _, definition in ipairs(currencyDefinitions) do
        local currencyType = Global(definition[2])
        local location = Global(definition[3])
        if currencyType ~= nil and location ~= nil then
            currencies[definition[1]] = {
                amount = PBE.Safe(GetCurrencyAmount, currencyType, location) or 0,
                max = PBE.Safe(GetMaxPossibleCurrency, currencyType, location),
                type = currencyType,
            }
        end
    end
    return currencies
end

local function CollectRiding()
    local ok, inventory, inventoryMax, stamina, staminaMax, speed, speedMax = PBE.SafeMulti(GetRidingStats)
    if not ok then
        return nil
    end
    return Object({
        inventory = inventory,
        inventoryMax = inventoryMax,
        speed = speed,
        speedMax = speedMax,
        stamina = stamina,
        staminaMax = staminaMax,
    })
end

local researchTypes = {
    { "blacksmithing", "CRAFTING_TYPE_BLACKSMITHING" },
    { "clothing", "CRAFTING_TYPE_CLOTHIER" },
    { "woodworking", "CRAFTING_TYPE_WOODWORKING" },
    { "jewelry", "CRAFTING_TYPE_JEWELRYCRAFTING" },
}

local function CollectCraftingResearch()
    local crafting = Object()
    for _, definition in ipairs(researchTypes) do
        local craftType = Global(definition[2])
        if craftType ~= nil then
            local craft = {
                id = craftType,
                name = PBE.CleanText(PBE.Safe(GetCraftingSkillName, craftType)),
                lines = {},
            }
            local lineCount = PBE.Safe(GetNumSmithingResearchLines, craftType) or 0
            for lineIndex = 1, lineCount do
                local lineOk, name, _, traitCount, nextResearchSeconds =
                    PBE.SafeMulti(GetSmithingResearchLineInfo, craftType, lineIndex)
                if lineOk then
                    local line = {
                        index = lineIndex,
                        name = PBE.CleanText(name),
                        nextResearchSeconds = nextResearchSeconds,
                        traits = {},
                    }
                    for traitIndex = 1, (traitCount or 0) do
                        local traitOk, traitType, description, known =
                            PBE.SafeMulti(GetSmithingResearchLineTraitInfo, craftType, lineIndex, traitIndex)
                        if traitOk then
                            local _, duration, remaining = PBE.SafeMulti(
                                GetSmithingResearchLineTraitTimes,
                                craftType,
                                lineIndex,
                                traitIndex
                            )
                            line.traits[#line.traits + 1] = {
                                description = PBE.CleanText(description),
                                duration = duration,
                                id = traitType,
                                index = traitIndex,
                                known = known,
                                remaining = remaining,
                            }
                        end
                    end
                    craft.lines[#craft.lines + 1] = line
                end
            end
            crafting[definition[1]] = craft
        end
    end
    return crafting
end

local function CollectInventorySummary()
    local bags = Object()
    local definitions = {
        { "backpack", "BAG_BACKPACK" },
        { "bank", "BAG_BANK" },
        { "subscriberBank", "BAG_SUBSCRIBER_BANK" },
        { "worn", "BAG_WORN" },
    }
    for _, definition in ipairs(definitions) do
        local bag = Global(definition[2])
        if bag ~= nil then
            bags[definition[1]] = {
                id = bag,
                size = PBE.Safe(GetBagSize, bag),
                used = PBE.Safe(GetNumBagUsedSlots, bag),
            }
        end
    end
    return bags
end

local function CollectQuests()
    local quests = {}
    local count = PBE.Safe(GetNumJournalQuests) or 0
    for index = 1, count do
        local ok, name, _, activeStep, activeStepType, trackerText, completed, tracked, level, pushed, questType,
            zoneDisplayType = PBE.SafeMulti(GetJournalQuestInfo, index)
        if ok and name and name ~= "" then
            quests[#quests + 1] = {
                activeStep = PBE.CleanText(activeStep),
                activeStepType = activeStepType,
                completed = completed,
                index = index,
                level = level,
                name = PBE.CleanText(name),
                pushed = pushed,
                questType = questType,
                tracked = tracked,
                trackerText = PBE.CleanText(trackerText),
                zoneDisplayType = zoneDisplayType,
            }
        end
    end
    return quests
end

local function CollectBagItems(bagConstant)
    local items = {}
    local bag = Global(bagConstant)
    if bag == nil then
        return items
    end
    local size = PBE.Safe(GetBagSize, bag) or 0
    for slot = 0, size - 1 do
        local link = PBE.Safe(GetItemLink, bag, slot, LINK_STYLE_DEFAULT) or ""
        if link ~= "" then
            local _, _, stack, sellPrice, meetsRequirement, locked, equipType, styleId, functionalQuality,
                displayQuality = PBE.SafeMulti(GetItemInfo, bag, slot)
            items[#items + 1] = {
                championPoints = PBE.Safe(GetItemLinkRequiredChampionPoints, link),
                displayQuality = displayQuality,
                equipType = equipType,
                functionalQuality = functionalQuality,
                itemId = PBE.Safe(GetItemLinkItemId, link),
                level = PBE.Safe(GetItemLinkRequiredLevel, link),
                link = link,
                locked = locked,
                meetsRequirement = meetsRequirement,
                name = PBE.CleanText(PBE.Safe(GetItemName, bag, slot)),
                sellPrice = sellPrice,
                slot = slot,
                stack = stack,
                styleId = styleId,
            }
        end
    end
    return items
end

local function NewBagItemsStepper(bagConstant)
    local bag = Global(bagConstant)
    local state = {
        bag = bag,
        items = {},
        size = bag ~= nil and (PBE.Safe(GetBagSize, bag) or 0) or 0,
        slot = 0,
    }
    function state:step(limit)
        local remaining = math.max(1, limit or 1)
        while remaining > 0 do
            if self.slot >= self.size then
                return true, self.items
            end
            remaining = remaining - 1
            local slot = self.slot
            self.slot = slot + 1
            local link = PBE.Safe(GetItemLink, self.bag, slot, LINK_STYLE_DEFAULT) or ""
            if link ~= "" then
                local _, _, stack, sellPrice, meetsRequirement, locked, equipType, styleId, functionalQuality,
                    displayQuality = PBE.SafeMulti(GetItemInfo, self.bag, slot)
                self.items[#self.items + 1] = {
                    championPoints = PBE.Safe(GetItemLinkRequiredChampionPoints, link),
                    displayQuality = displayQuality,
                    equipType = equipType,
                    functionalQuality = functionalQuality,
                    itemId = PBE.Safe(GetItemLinkItemId, link),
                    level = PBE.Safe(GetItemLinkRequiredLevel, link),
                    link = link,
                    locked = locked,
                    meetsRequirement = meetsRequirement,
                    name = PBE.CleanText(PBE.Safe(GetItemName, self.bag, slot)),
                    sellPrice = sellPrice,
                    slot = slot,
                    stack = stack,
                    styleId = styleId,
                }
            end
        end
        return false
    end
    return state
end

local function CollectCollectibles()
    local result = { categories = {}, unlocked = {} }
    local categoryCount = PBE.Safe(GetNumCollectibleCategories) or 0
    for categoryIndex = 1, categoryCount do
        local ok, name, subcategoryCount, collectibleCount, unlockedCount, totalCount, hidesLocked =
            PBE.SafeMulti(GetCollectibleCategoryInfo, categoryIndex)
        if ok then
            local category = {
                hidesLocked = hidesLocked,
                index = categoryIndex,
                name = PBE.CleanText(name),
                total = totalCount,
                unlocked = unlockedCount,
            }
            result.categories[#result.categories + 1] = category

            local function AddCollectibles(subcategoryIndex, count, subcategoryName)
                for collectibleIndex = 1, (count or 0) do
                    local collectibleId = PBE.Safe(
                        GetCollectibleId,
                        categoryIndex,
                        subcategoryIndex,
                        collectibleIndex
                    )
                    if collectibleId then
                        local infoOk, collectibleName, description, _, _, unlocked, purchasable, active, categoryType,
                            hint = PBE.SafeMulti(GetCollectibleInfo, collectibleId)
                        if infoOk and unlocked then
                            result.unlocked[#result.unlocked + 1] = {
                                active = active,
                                category = category.name,
                                categoryType = categoryType,
                                description = PBE.CleanText(description),
                                hint = PBE.CleanText(hint),
                                id = collectibleId,
                                name = PBE.CleanText(collectibleName),
                                purchasable = purchasable,
                                subcategory = PBE.CleanText(subcategoryName),
                            }
                        end
                    end
                end
            end

            AddCollectibles(nil, collectibleCount, nil)
            for subcategoryIndex = 1, (subcategoryCount or 0) do
                local subOk, subName, subCount = PBE.SafeMulti(
                    GetCollectibleSubCategoryInfo,
                    categoryIndex,
                    subcategoryIndex
                )
                if subOk then
                    AddCollectibles(subcategoryIndex, subCount, subName)
                end
            end
        end
    end
    return result
end

local function CollectAchievements()
    local result = { categories = {}, entries = {} }
    local categoryCount = PBE.Safe(GetNumAchievementCategories) or 0
    for categoryIndex = 1, categoryCount do
        local ok, name, subcategoryCount, achievementCount, earnedPoints, totalPoints, hidesPoints =
            PBE.SafeMulti(GetAchievementCategoryInfo, categoryIndex)
        if ok then
            local category = {
                earnedPoints = earnedPoints,
                hidesPoints = hidesPoints,
                index = categoryIndex,
                name = PBE.CleanText(name),
                totalPoints = totalPoints,
            }
            result.categories[#result.categories + 1] = category

            local function AddAchievements(subcategoryIndex, count, subcategoryName)
                for achievementIndex = 1, (count or 0) do
                    local achievementId = PBE.Safe(
                        GetAchievementId,
                        categoryIndex,
                        subcategoryIndex,
                        achievementIndex
                    )
                    if achievementId then
                        local infoOk, achievementName, description, points, _, completed, date, time =
                            PBE.SafeMulti(GetAchievementInfo, achievementId)
                        if infoOk and achievementName then
                            local entry = {
                                category = category.name,
                                completed = completed,
                                date = date,
                                description = PBE.CleanText(description),
                                id = achievementId,
                                name = PBE.CleanText(achievementName),
                                points = points,
                                subcategory = PBE.CleanText(subcategoryName),
                                time = time,
                                criteria = {},
                            }
                            local criteriaCount = PBE.Safe(GetAchievementNumCriteria, achievementId) or 0
                            for criterionIndex = 1, criteriaCount do
                                local criterionOk, criterionDescription, completedCount, requiredCount =
                                    PBE.SafeMulti(GetAchievementCriterion, achievementId, criterionIndex)
                                if criterionOk then
                                    entry.criteria[#entry.criteria + 1] = {
                                        completed = completedCount,
                                        description = PBE.CleanText(criterionDescription),
                                        required = requiredCount,
                                    }
                                end
                            end
                            result.entries[#result.entries + 1] = entry
                        end
                    end
                end
            end

            AddAchievements(nil, achievementCount, nil)
            for subcategoryIndex = 1, (subcategoryCount or 0) do
                local subOk, subName, subCount = PBE.SafeMulti(
                    GetAchievementSubCategoryInfo,
                    categoryIndex,
                    subcategoryIndex
                )
                if subOk then
                    AddAchievements(subcategoryIndex, subCount, subName)
                end
            end
        end
    end
    return result
end

-- A step is one category header, subcategory header, collectible, achievement,
-- or achievement criterion. In particular, criteria are not drained in the
-- same frame as their parent achievement.
local function NewCollectiblesStepper()
    local state = {
        result = { categories = {}, unlocked = {} },
        categoryCount = PBE.Safe(GetNumCollectibleCategories) or 0,
        categoryIndex = 1,
        phase = "category",
    }
    function state:step(limit)
        local remaining = math.max(1, limit or 1)
        while remaining > 0 do
            remaining = remaining - 1
            if self.phase == "category" then
                if self.categoryIndex > self.categoryCount then
                    return true, self.result
                end
                local ok, name, subcategoryCount, collectibleCount, unlockedCount, totalCount, hidesLocked =
                    PBE.SafeMulti(GetCollectibleCategoryInfo, self.categoryIndex)
                if ok then
                    self.category = {
                        hidesLocked = hidesLocked,
                        index = self.categoryIndex,
                        name = PBE.CleanText(name),
                        total = totalCount,
                        unlocked = unlockedCount,
                    }
                    self.result.categories[#self.result.categories + 1] = self.category
                    self.subcategoryCount = subcategoryCount or 0
                    self.groupIndex = 0
                    self.mainCount = collectibleCount or 0
                    self.phase = "group"
                else
                    self.categoryIndex = self.categoryIndex + 1
                end
            elseif self.phase == "group" then
                if self.groupIndex > self.subcategoryCount then
                    self.categoryIndex = self.categoryIndex + 1
                    self.phase = "category"
                else
                    self.subcategoryName = nil
                    if self.groupIndex == 0 then
                        self.groupCount = self.mainCount
                    else
                        local ok, name, count = PBE.SafeMulti(
                            GetCollectibleSubCategoryInfo, self.categoryIndex, self.groupIndex
                        )
                        self.groupCount = ok and (count or 0) or 0
                        if ok then self.subcategoryName = name end
                    end
                    self.entryIndex = 1
                    self.phase = "entry"
                end
            else -- entry
                if self.entryIndex > self.groupCount then
                    self.groupIndex = self.groupIndex + 1
                    self.phase = "group"
                else
                    local subcategoryIndex
                    if self.groupIndex > 0 then subcategoryIndex = self.groupIndex end
                    local collectibleId = PBE.Safe(
                        GetCollectibleId, self.categoryIndex, subcategoryIndex, self.entryIndex
                    )
                    self.entryIndex = self.entryIndex + 1
                    if collectibleId then
                        local ok, name, description, _, _, unlocked, purchasable, active, categoryType,
                            hint = PBE.SafeMulti(GetCollectibleInfo, collectibleId)
                        if ok and unlocked then
                            self.result.unlocked[#self.result.unlocked + 1] = {
                                active = active,
                                category = self.category.name,
                                categoryType = categoryType,
                                description = PBE.CleanText(description),
                                hint = PBE.CleanText(hint),
                                id = collectibleId,
                                name = PBE.CleanText(name),
                                purchasable = purchasable,
                                subcategory = PBE.CleanText(self.subcategoryName),
                            }
                        end
                    end
                end
            end
        end
        return false
    end
    return state
end

local function NewAchievementsStepper()
    local state = {
        result = { categories = {}, entries = {} },
        categoryCount = PBE.Safe(GetNumAchievementCategories) or 0,
        categoryIndex = 1,
        phase = "category",
    }
    function state:step(limit)
        local remaining = math.max(1, limit or 1)
        while remaining > 0 do
            remaining = remaining - 1
            if self.phase == "category" then
                if self.categoryIndex > self.categoryCount then
                    return true, self.result
                end
                local ok, name, subcategoryCount, achievementCount, earnedPoints, totalPoints, hidesPoints =
                    PBE.SafeMulti(GetAchievementCategoryInfo, self.categoryIndex)
                if ok then
                    self.category = {
                        earnedPoints = earnedPoints,
                        hidesPoints = hidesPoints,
                        index = self.categoryIndex,
                        name = PBE.CleanText(name),
                        totalPoints = totalPoints,
                    }
                    self.result.categories[#self.result.categories + 1] = self.category
                    self.subcategoryCount = subcategoryCount or 0
                    self.groupIndex = 0
                    self.mainCount = achievementCount or 0
                    self.phase = "group"
                else
                    self.categoryIndex = self.categoryIndex + 1
                end
            elseif self.phase == "group" then
                if self.groupIndex > self.subcategoryCount then
                    self.categoryIndex = self.categoryIndex + 1
                    self.phase = "category"
                else
                    self.subcategoryName = nil
                    if self.groupIndex == 0 then
                        self.groupCount = self.mainCount
                    else
                        local ok, name, count = PBE.SafeMulti(
                            GetAchievementSubCategoryInfo, self.categoryIndex, self.groupIndex
                        )
                        self.groupCount = ok and (count or 0) or 0
                        if ok then self.subcategoryName = name end
                    end
                    self.entryIndex = 1
                    self.phase = "entry"
                end
            elseif self.phase == "entry" then
                if self.entryIndex > self.groupCount then
                    self.groupIndex = self.groupIndex + 1
                    self.phase = "group"
                else
                    local subcategoryIndex
                    if self.groupIndex > 0 then subcategoryIndex = self.groupIndex end
                    local achievementId = PBE.Safe(
                        GetAchievementId, self.categoryIndex, subcategoryIndex, self.entryIndex
                    )
                    self.entryIndex = self.entryIndex + 1
                    if achievementId then
                        local ok, name, description, points, _, completed, date, time =
                            PBE.SafeMulti(GetAchievementInfo, achievementId)
                        if ok and name then
                            self.currentEntry = {
                                category = self.category.name,
                                completed = completed,
                                date = date,
                                description = PBE.CleanText(description),
                                id = achievementId,
                                name = PBE.CleanText(name),
                                points = points,
                                subcategory = PBE.CleanText(self.subcategoryName),
                                time = time,
                                criteria = {},
                            }
                            self.criteriaCount = PBE.Safe(GetAchievementNumCriteria, achievementId) or 0
                            self.criterionIndex = 1
                            self.phase = "criteria"
                        end
                    end
                end
            else -- criteria
                if self.criterionIndex > self.criteriaCount then
                    self.result.entries[#self.result.entries + 1] = self.currentEntry
                    self.currentEntry = nil
                    self.phase = "entry"
                else
                    local ok, description, completedCount, requiredCount = PBE.SafeMulti(
                        GetAchievementCriterion, self.currentEntry.id, self.criterionIndex
                    )
                    self.criterionIndex = self.criterionIndex + 1
                    if ok then
                        self.currentEntry.criteria[#self.currentEntry.criteria + 1] = {
                            completed = completedCount,
                            description = PBE.CleanText(description),
                            required = requiredCount,
                        }
                    end
                end
            end
        end
        return false
    end
    return state
end

local function CollectTitles()
    local titles = {}
    local titleCount = PBE.Safe(GetNumTitles) or 0
    for titleIndex = 1, titleCount do
        titles[#titles + 1] = {
            index = titleIndex,
            name = PBE.CleanText(PBE.Safe(GetTitle, titleIndex)),
            selected = titleIndex == PBE.Safe(GetCurrentTitleIndex),
        }
    end
    return titles
end

function Collectors.GetStages(profile)
    local includeExtended = profile == "all"
    if profile == "skills" then
        return {
            { key = "system", capture = function() return CollectSystem(profile) end },
            { key = "character", capture = CollectIdentity },
            {
                key = "skills", capture = function() return CollectSkills(false) end,
                newStepper = function() return NewSkillsStepper(false) end,
            },
        }
    elseif profile == "crafting" then
        return {
            { key = "system", capture = function() return CollectSystem(profile) end },
            { key = "character", capture = CollectIdentity },
            { key = "craftingResearch", capture = CollectCraftingResearch },
        }
    elseif profile == "quests" then
        return {
            { key = "system", capture = function() return CollectSystem(profile) end },
            { key = "character", capture = CollectIdentity },
            { key = "quests", capture = CollectQuests },
        }
    end
    if profile == "quick" then
        return {
            { key = "system", capture = function() return CollectSystem(profile) end },
            { key = "character", capture = CollectIdentity },
            { key = "attributes", capture = CollectAttributes },
            { key = "stats", capture = CollectStats },
            { key = "mundus", capture = CollectMundus },
            { key = "equipment", capture = function()
                local result = {}
                for _, item in ipairs(CollectEquipment()) do
                    result[#result + 1] = {
                        slot = item.slot,
                        empty = item.empty,
                        name = item.name,
                        itemId = item.itemId,
                        level = item.level,
                        championPoints = item.championPoints,
                        displayQuality = item.displayQuality,
                        set = item.set and Object({ name = item.set.name, id = item.set.id }) or nil,
                        trait = item.trait and Object({ id = item.trait.id, description = item.trait.description }) or nil,
                        enchant = item.enchant and Object({ name = item.enchant.name }) or nil,
                    }
                end
                return result
            end },
            { key = "bars", capture = CollectBars },
            { key = "skills", capture = function()
                return { availablePoints = PBE.Safe(GetAvailableSkillPoints) or 0, detailOmitted = true, types = {} }
            end },
            { key = "champion", capture = function()
                local champion = CollectChampion()
                champion.enlightenment = nil
                for _, discipline in ipairs(champion.disciplines) do
                    for _, skill in ipairs(discipline.skills) do
                        skill.max = nil
                        skill.type = nil
                    end
                end
                return champion
            end },
            { key = "companion", capture = function()
                local companion = CollectCompanion()
                companion.equipment = nil
                return companion
            end },
        }
    end
    local stages = {
        { key = "system", capture = function() return CollectSystem(profile) end },
        { key = "character", capture = CollectIdentity },
        { key = "attributes", capture = CollectAttributes },
        { key = "stats", capture = CollectStats },
        { key = "activeEffects", capture = CollectEffects },
        { key = "mundus", capture = CollectMundus },
        { key = "activeCollectibles", capture = CollectActiveCollectibles },
        { key = "equipment", capture = CollectEquipment },
        { key = "bars", capture = CollectBars },
        {
            key = "skills", capture = function() return CollectSkills(includeExtended) end,
            newStepper = function() return NewSkillsStepper(includeExtended) end,
        },
        { key = "champion", capture = CollectChampion },
        { key = "currencies", capture = CollectCurrencies },
        { key = "riding", capture = CollectRiding },
        { key = "companion", capture = CollectCompanion },
        { key = "craftingResearch", capture = CollectCraftingResearch },
        { key = "inventorySummary", capture = CollectInventorySummary },
        { key = "quests", capture = CollectQuests },
    }
    if includeExtended then
        stages[#stages + 1] = { key = "armoryBuilds", capture = CollectArmory }
        stages[#stages + 1] = {
            key = "backpack", capture = function() return CollectBagItems("BAG_BACKPACK") end,
            newStepper = function() return NewBagItemsStepper("BAG_BACKPACK") end,
        }
        stages[#stages + 1] = {
            key = "bank", capture = function() return CollectBagItems("BAG_BANK") end,
            newStepper = function() return NewBagItemsStepper("BAG_BANK") end,
        }
        stages[#stages + 1] = {
            key = "subscriberBank", capture = function() return CollectBagItems("BAG_SUBSCRIBER_BANK") end,
            newStepper = function() return NewBagItemsStepper("BAG_SUBSCRIBER_BANK") end,
        }
        stages[#stages + 1] = {
            key = "collectibles", capture = CollectCollectibles, newStepper = NewCollectiblesStepper,
        }
        stages[#stages + 1] = {
            key = "achievements", capture = CollectAchievements, newStepper = NewAchievementsStepper,
        }
        stages[#stages + 1] = { key = "titles", capture = CollectTitles }
    end
    return stages
end

function Collectors.Capture(profile)
    local snapshot = {}
    for _, stage in ipairs(Collectors.GetStages(profile)) do
        snapshot[stage.key] = stage.capture()
    end
    return snapshot
end
