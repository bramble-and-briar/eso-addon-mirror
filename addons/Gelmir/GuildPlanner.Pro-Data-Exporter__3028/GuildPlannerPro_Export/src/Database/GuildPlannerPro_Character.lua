GuildPlannerPro_Character = {}
GuildPlannerPro_Character.__index = GuildPlannerPro_Character

function GuildPlannerPro_Character:New()
    local newObj = setmetatable({}, self)
    newObj.AvaRank = {}
    newObj.DefaultSetup = {}
    newObj.Builds = {}
    newObj.CarriedSets = {}
    newObj.Achievements = {}
    newObj.Wallet = {}

    newObj.BankedSets = {
        [BAG_BANK] = {},
        [BAG_SUBSCRIBER_BANK] = {},
        [BAG_HOUSE_BANK_ONE] = {},
        [BAG_HOUSE_BANK_TWO] = {},
        [BAG_HOUSE_BANK_THREE] = {},
        [BAG_HOUSE_BANK_FOUR] = {},
        [BAG_HOUSE_BANK_FIVE] = {},
        [BAG_HOUSE_BANK_SIX] = {},
        [BAG_HOUSE_BANK_SEVEN] = {},
        [BAG_HOUSE_BANK_EIGHT] = {},
        [BAG_HOUSE_BANK_NINE] = {},
        [BAG_HOUSE_BANK_TEN] = {},
    }

    return newObj
end

function GuildPlannerPro_Character:Initialize()
    GuildPlannerPro_Character.ExportCharacterBaseInfo(self)

    self.AvaRank = GuildPlannerPro_Character:ExportAvARank()
    self.CarriedSets = GuildPlannerPro_Character:CheckBackpackForSets()
    self.Achievements = GuildPlannerPro_Achievements:ExportAchievementsCompletionData(ACHIEVEMENT_PERSISTENCE_CHARACTER)
    self.DefaultSetup = GuildPlannerPro_Armory:ParseArmoryBuild(0, true)
    self.Wallet = GuildPlannerPro_Character:GetCurrencyAmountForGivenWallet(CURRENCY_LOCATION_CHARACTER)
end

function GuildPlannerPro_Character:CheckEquipment()
    local EQUIP_SLOTS =
    {
        EQUIP_SLOT_HEAD,
        EQUIP_SLOT_SHOULDERS,
        EQUIP_SLOT_CHEST,
        EQUIP_SLOT_HAND,
        EQUIP_SLOT_WAIST,
        EQUIP_SLOT_LEGS,
        EQUIP_SLOT_FEET,
        EQUIP_SLOT_COSTUME,
        EQUIP_SLOT_NECK,
        EQUIP_SLOT_RING1,
        EQUIP_SLOT_RING2,
        EQUIP_SLOT_MAIN_HAND,
        EQUIP_SLOT_OFF_HAND,
        EQUIP_SLOT_POISON,
        EQUIP_SLOT_BACKUP_MAIN,
        EQUIP_SLOT_BACKUP_OFF,
        EQUIP_SLOT_BACKUP_POISON,
    }
    local equipment = {}
    for _, equipSlot in ipairs(EQUIP_SLOTS) do
        GuildPlannerPro_Character:GetItemDataForEquipmentSlotOfGivenBag(equipment, BAG_WORN, equipSlot)
    end

    return equipment
end

function GuildPlannerPro_Character:GetItemDataForEquipmentSlotOfGivenBag(myTable, bag, equipSlot)
    local itemIcon, slotHasItem = GetEquippedItemInfo(equipSlot)
    if slotHasItem then
        local itemLink = GetItemLink(bag, equipSlot, LINK_STYLE_BRACKETS)
        local _, _, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)
        local traitType, traitDescription = GetItemLinkTraitInfo(itemLink)
        local _, enchantHeader, enchantDescription = GetItemLinkEnchantInfo(itemLink)
        myTable[equipSlot] = {
            ItemId = GetItemLinkItemId(itemLink),
            ItemName = zo_strformat(GetString(SI_TOOLTIP_ITEM_NAME), GetItemName(bag, equipSlot)),
            ItemDisplayQuality = GetItemDisplayQuality(bag, equipSlot),
            ItemLevel = GetItemLevel(bag, equipSlot),
            ItemRequiredLevel = GetItemRequiredLevel(bag, equipSlot),
            ItemRequiredCp = GetItemLinkRequiredChampionPoints(itemLink),
            ItemTrait = traitType,
            ItemTraitDescription = traitDescription,
            ItemTraitCategory = GetItemTraitCategory(bag, equipSlot),
            ItemTraitInformation = GetItemTraitInformation(bag, equipSlot),
            ItemEnchantType = GetEnchantSearchCategoryType(GetItemLinkFinalEnchantId(itemLink)),
            ItemEnchantHeader = enchantHeader,
            ItemEnchantDescription = enchantDescription,
            ItemGlyphMinLevels = GetItemGlyphMinLevels(bag, equipSlot),
            ItemIcon = itemIcon,
            ItemLink = itemLink,
            SetId = setId,
            EquipSlot = equipSlot,
            EquipType = GetItemLinkEquipType(itemLink),
            ArmorType = GetItemLinkArmorType(itemLink),
            WeaponType = GetItemLinkWeaponType(itemLink),
            ArmorRating = GetItemLinkArmorRating(itemLink, false),
            WeaponPower = GetItemLinkWeaponPower(itemLink),
            TimeStamp = GetTimeStamp(),
        }
    end
end

function GuildPlannerPro_Character:CheckBankForSets(bagId)
    local myTable = {}
    GuildPlannerPro_Sets:CheckGivenBag(bagId, myTable)

    return myTable
end

function GuildPlannerPro_Character:CheckBackpackForSets()
    myTable = {}
    GuildPlannerPro_Sets:CheckGivenBag(BAG_BACKPACK, myTable)

    return myTable
end

function GuildPlannerPro_Character:ExportChampionRank()
    return {
        PointsEarned = GetPlayerChampionPointsEarned(), -- TODO @deprecated
        Rank = GetPlayerChampionPointsEarned(),
    }
end

function GuildPlannerPro_Character:GetChampionSpentPoints()
    local championSpentPoints = {}
    for d = 1, GetNumChampionDisciplines() do
        table.insert(championSpentPoints, {
            ChampionDisciplineType = GetChampionDisciplineType(d),
            PointsSpent = GetNumSpentChampionPoints(d),
        })
    end

    return championSpentPoints
end

function GuildPlannerPro_Character:ExportAvARank()
    local rank = GetUnitAvARank("player")

    return {
        Rank = rank,
        Icon = GetLargeAvARankIcon(rank),
    }
end

function GuildPlannerPro_Character:ExportLevel()
    local level = {}
    level.EffectiveLevel = GetUnitEffectiveLevel("player")
    level.Level = GetUnitLevel("player")
    level.XP = GetUnitXP("player")
    level.XPMax = GetUnitXPMax("player")

    return level
end

function GuildPlannerPro_Character:ExportCharacterBaseInfo()
    local _, isEmperor = GetAchievementCriterion(935, 1)

    self.Id = GetCurrentCharacterId()
    self.Title = GetUnitTitle("player")
    self.Gender = GuildPlannerPro_Const.Gender[GetUnitGender("player")]
    self.GenderId = GetUnitGender("player")
    self.AllianceId = GetUnitAlliance("player")
    self.RaceId = GetUnitRaceId("player")
    self.ClassId = GetUnitClassId("player")
    self.SilhouetteIcon = GetUnitSilhouetteTexture("player")
    self.Level = GuildPlannerPro_Character:ExportLevel()
    self.Emperor = isEmperor
    self.AchievementPointsEarned = GetEarnedAchievementPoints()
    self.AchievementPointsTotal = GetTotalAchievementPoints()
    self.VeterancyRank = GetUnitVeterancyRank("player")
    self.AvailableSkillPoints = GetAvailableSkillPoints()
    self.ZoneId = GetZoneId(GetCurrentMapZoneIndex())
    self.RepresentedGuildId = GetRepresentedGuildId()
    self.Playtime = GetSecondsPlayed()
    self.TimeStamp = GetTimeStamp()

    self.MundusStone = GuildPlannerPro_Character:ExportMundus()
end

function GuildPlannerPro_Character:GetCurrencyAmountForGivenWallet(currencyLocation)
    local wallet = {}
    for currency = CURT_MONEY, CURT_TOME_CHALLENGE_REROLLS do
        local amount = GetCurrencyAmount(currency, currencyLocation)
        if amount > 0 then
            table.insert(wallet, {
                currency = currency,
                amount = amount,
            })
        end
    end

    return wallet
end

function GuildPlannerPro_Character:ExportMundus()
    local mundusType
    local numBuffs = GetNumBuffs("player")
    for i = 1, numBuffs do
        local _, _, _, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
        if GuildPlannerPro_Utils:TableKeyExists(id, GuildPlannerPro_Const.MundusAbilityIdMap) == true then
            mundusType = GuildPlannerPro_Const.MundusAbilityIdMap[id]
        end
    end

    return mundusType
end

function GuildPlannerPro_Character:GetAttributeSpentPoints()
    local attributeSpentPoints = {}
    for j = ATTRIBUTE_HEALTH, ATTRIBUTE_ITERATION_END do
        table.insert(attributeSpentPoints, {
            Attribute = j,
            PointsSpent = GetAttributeSpentPoints(j),
        })
    end

    return attributeSpentPoints
end

function GuildPlannerPro_Character:ExportCharacterStats()
    local Stats = {}
    Stats["Advanced Stats"] = {}
    local numAdvStats = GetNumAdvancedStatCategories()
    for categoryIndex = 1, numAdvStats do
        local categoryId = GetAdvancedStatsCategoryId(categoryIndex)
        local categoryDisplayName, numStats = GetAdvancedStatCategoryInfo(categoryId)
        for statIndex = 1, numStats do
            if Stats["Advanced Stats"][categoryId] == nil then
                Stats["Advanced Stats"][categoryId] = {
                    CategoryId = categoryId,
                    CategoryDisplayName = categoryDisplayName,
                    CategoryNumStats = numStats,
                    CategoryStats = {},
                }
            end
            local statType, statDisplayName, description, flatDescription, percentDescription = GetAdvancedStatInfo(categoryId, statIndex)
            local displayFormat, flatValue, percentValue = GetAdvancedStatValue(statType)
            Stats["Advanced Stats"][categoryId]["CategoryStats"][statType] = {
                StatType = statType,
                StatDisplayName = statDisplayName,
                StatDescription = description,
                StatFlatDescription = flatDescription,
                StatPercentDescription = percentDescription,
                StatDisplayFormat = displayFormat,
                StatFlatValue = flatValue,
                StatPercentValue = percentValue,
            }
        end
    end

    Stats["Main Stats"] = {
        ["Armor Rating"] = GetPlayerStat(STAT_ARMOR_RATING), -- Spell Resistance
        ["Critical Resistance"] = GetPlayerStat(STAT_CRITICAL_RESISTANCE),
        ["Maximum Health"] = GetPlayerStat(STAT_HEALTH_MAX, STAT_BONUS_OPTION_DONT_APPLY_BONUS),
        ["Health Regeneration"] = GetPlayerStat(STAT_HEALTH_REGEN_COMBAT, STAT_BONUS_OPTION_DONT_APPLY_BONUS),
        ["Maximum Magicka"] = GetPlayerStat(STAT_MAGICKA_MAX, STAT_BONUS_OPTION_DONT_APPLY_BONUS),
        ["Magicka Regeneration"] = GetPlayerStat(STAT_MAGICKA_REGEN_COMBAT, STAT_BONUS_OPTION_DONT_APPLY_BONUS),
        ["Physical Penetration"] = GetPlayerStat(STAT_PHYSICAL_PENETRATION),
        ["Physical Resistance"] = GetPlayerStat(STAT_PHYSICAL_RESIST),
        ["Spell Critical (Base)"] = GetPlayerStat(STAT_SPELL_CRITICAL, STAT_BONUS_OPTION_DONT_APPLY_BONUS),
        ["Spell Critical"] = GetPlayerStat(STAT_SPELL_CRITICAL), -- ?
        ["Spell Penetration"] = GetPlayerStat(STAT_SPELL_PENETRATION),
        ["Spell Damage"] = GetPlayerStat(STAT_SPELL_POWER),
        ["Spell Resistance"] = GetPlayerStat(STAT_SPELL_RESIST),
        ["Maximum Stamina"] = GetPlayerStat(STAT_STAMINA_MAX, STAT_BONUS_OPTION_DONT_APPLY_BONUS),
        ["Stamina Regeneration"] = GetPlayerStat(STAT_STAMINA_REGEN_COMBAT, STAT_BONUS_OPTION_DONT_APPLY_BONUS),
        ["Weapon Critical (Base)"] = GetPlayerStat(STAT_CRITICAL_STRIKE, STAT_BONUS_OPTION_DONT_APPLY_BONUS),
        ["Weapon Critical"] = GetPlayerStat(STAT_CRITICAL_STRIKE),
        ["Weapon Damage"] = GetPlayerStat(STAT_POWER),
    }

    return Stats
end
