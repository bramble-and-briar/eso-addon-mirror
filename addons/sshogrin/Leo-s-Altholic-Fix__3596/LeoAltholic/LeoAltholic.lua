
LeoAltholic.timerQueue = {}
LeoAltholic.charList = {}
LeoAltholic.lastUpdatedCharList = nil
LeoAltholic.initialized = false
LeoAltholic.numUpdates = 0

LeoAltholic.maxTraits = select(3,GetSmithingResearchLineInfo(1,1))
LeoAltholic.jewelryMaxTraits = select(3,GetSmithingResearchLineInfo(7,1))

local DARK_BROTHERHOOD = 118
local THIEVES_GUILD = 117
local LEGERDEMAIN = 111
local SOUL_MAGIC = 72

function LeoAltholic.GetMaxRank(skillType, skillLine)
    if skillType == SKILL_TYPE_AVA or
        skillType == SKILL_TYPE_GUILD or
		skillType == SKILL_TYPE_WORLD then
        local _, _, _, skillLineId = GetSkillLineInfo(skillType, skillLine)
        if skillLineId == THIEVES_GUILD then
            return 12
        end
        if skillLineId == DARK_BROTHERHOOD then
            return 12
		end
		if skillLineId == LEGERDEMAIN then
            return 20
		end
		if skillLineId == SOUL_MAGIC then
			return 6
		end
        return 10
	end
    return 50
end

local function loadPlayerDataPart(skillType, baseElem)
    if skillType == nil then
        return
    end
    local numSkillLines = GetNumSkillLines(skillType)
    for i = 1, numSkillLines do
        local name, rank, discovered, lineId, advised, unlockText = GetSkillLineInfo(skillType,i)
        if name == nil then
            name = i;
        end
        if discovered then
            baseElem[i]    = {}
            local baseElemTable = baseElem[i]
            local qty = GetNumSkillAbilities(skillType, i)
            baseElemTable.name = name
            baseElemTable.id = i
            baseElemTable.qty = qty
            baseElemTable.rank = rank
            baseElemTable.lineId = lineId

            baseElemTable.list = {}

            for aj = 1, qty do
                local name2, icon, earnedRank, passive, ultimate, purchased, progressionIndex = GetSkillAbilityInfo(skillType, i, aj)
                local currentUpgradeLevel, maxUpgradeLevel = GetSkillAbilityUpgradeInfo(skillType, i, aj)
                if rank >= earnedRank then
                    local _, _, nextUpgradeEarnedRank = GetSkillAbilityNextUpgradeInfo(skillType, i, aj)
                    local plainName = ZO_CachedStrFormat(SI_ABILITY_NAME, name2)
                    name2 = ZO_Skills_GenerateAbilityName(SI_ABILITY_NAME_AND_UPGRADE_LEVELS, name2, currentUpgradeLevel, maxUpgradeLevel, progressionIndex)
                    baseElemTable.list[aj] = {}
                    local selL = baseElemTable.list[aj]
                    selL.plainName = plainName
                    selL.name = name2
                    selL.earnedRank = earnedRank or 0
                    selL.level = currentUpgradeLevel
                    selL.maxLevel = maxUpgradeLevel
                    selL.nextUpgradeEarnedRank = nextUpgradeEarnedRank
                    if passive then
                        selL.passive = passive
                    end
                    if ultimate then
                        selL.ultimate = ultimate
                    end
                end
            end
        end
    end
end

local SKILL_TYPE_TO_KEY = {
    [SKILL_TYPE_ARMOR]      = "armor",
    [SKILL_TYPE_WORLD]      = "world",
    [SKILL_TYPE_CLASS]      = "class",
    [SKILL_TYPE_GUILD]      = "guild",
    [SKILL_TYPE_RACIAL]     = "racial",
    [SKILL_TYPE_WEAPON]     = "weapon",
    [SKILL_TYPE_AVA]        = "ava",
    [SKILL_TYPE_TRADESKILL] = "craft",
}

local function getActiveCharData()
    return (LeoAltholic.GetMyself and LeoAltholic.GetMyself())
        or (LeoAltholic.globalData and LeoAltholic.globalData.CharList and LeoAltholic.globalData.CharList[GetUnitName("player")])
end

local function stampCharacterOrder()
    if not (LeoAltholic.globalData and LeoAltholic.globalData.CharList) then return end
    for i = 1, GetNumCharacters() do
        local rawName = GetCharacterInfo(i)
        local charName = zo_strformat("<<1>>", rawName)
        local charEntry = LeoAltholic.globalData.CharList[charName]
        if charEntry then
            charEntry.bio = charEntry.bio or {}
            charEntry.bio.charIndex = i
        end
    end
end

function LeoAltholic.GetSortedCharList()
    local list = {}
    if not (LeoAltholic.globalData and LeoAltholic.globalData.CharList) then
        return list
    end

    for _, charData in pairs(LeoAltholic.globalData.CharList) do
        table.insert(list, charData)
    end

    local mode = (LeoAltholic.globalData.settings and LeoAltholic.globalData.settings.charSortOrder) or "creation"

    table.sort(list, function(a, b)
        local nameA = tostring(a.bio and a.bio.name or ""):lower()
        local nameB = tostring(b.bio and b.bio.name or ""):lower()

        if mode == "alpha_asc" then
            return nameA < nameB
        elseif mode == "alpha_desc" then
            return nameA > nameB
        else -- "creation"
            local idxA = (a.bio and a.bio.charIndex) or 999
            local idxB = (b.bio and b.bio.charIndex) or 999
            if idxA ~= idxB then
                return idxA < idxB
            end
            return nameA < nameB
        end
    end)

    return list
end

local function refreshSkillUI()
    if LeoAltholicUI and LeoAltholicWindow and not LeoAltholicWindow:IsHidden() then
        if LeoAltholicUI.skillsList then
            LeoAltholicUI.skillsList:RefreshData()
            LeoAltholicUI.skillsList:RefreshFilters()
        end
        if LeoAltholicUI.skills2List then
            LeoAltholicUI.skills2List:RefreshData()
            LeoAltholicUI.skills2List:RefreshFilters()
        end
    end
end


local function refreshSkillCategory(skillType)
    local skillKey = SKILL_TYPE_TO_KEY[skillType]
    if not skillKey then
        return
    end

    local char = getActiveCharData()
    if char and char.skills then
        char.skills.unspent = GetAvailableSkillPoints()
        char.skills.skyShards = GetNumSkyShards()
        char.skills[skillKey] = {}
        loadPlayerDataPart(skillType, char.skills[skillKey])
        refreshSkillUI()
    end
end

-- 1. Standard skill line rank-ups
EVENT_MANAGER:RegisterForEvent("LeosAltholic_LiveSkillRankRefresh", EVENT_SKILL_RANK_UPDATE, function(_, skillType)
    refreshSkillCategory(skillType)
end)

-- 2. Scrying, Excavation, and XP-driven skill lines (throttled to 1.5s)
local pendingXpSkillTypes = {}
EVENT_MANAGER:RegisterForEvent("LeosAltholic_LiveSkillXpRefresh", EVENT_SKILL_XP_UPDATE, function(_, skillType)
    if not SKILL_TYPE_TO_KEY[skillType] or pendingXpSkillTypes[skillType] then
        return
    end
    pendingXpSkillTypes[skillType] = true

    zo_callLater(function()
        pendingXpSkillTypes[skillType] = nil
        refreshSkillCategory(skillType)
    end, 1500)
end)

-- 3. Skill points spent/refunded (passives & morphs)
local fullSkillRefreshPending = false
EVENT_MANAGER:RegisterForEvent("LeosAltholic_LiveSkillPointsRefresh", EVENT_SKILL_POINTS_CHANGED, function()
    if fullSkillRefreshPending then
        return
    end
    fullSkillRefreshPending = true

    zo_callLater(function()
        fullSkillRefreshPending = false
        local char = getActiveCharData()
        if char and char.skills then
            char.skills.unspent = GetAvailableSkillPoints()
            char.skills.skyShards = GetNumSkyShards()
            for skillType, skillKey in pairs(SKILL_TYPE_TO_KEY) do
                char.skills[skillKey] = {}
                loadPlayerDataPart(skillType, char.skills[skillKey])
            end
            refreshSkillUI()
        end
    end, 250)
end)

function LeoAltholic.GetCraftFromQuest(questName)
    if not string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_WRIT))) then return nil end

    if string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_ALCHEMIST))) then return CRAFTING_TYPE_ALCHEMY end
    if string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_BLACKSMITH))) then return CRAFTING_TYPE_BLACKSMITHING end
    if string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_CLOTHIER))) then return CRAFTING_TYPE_CLOTHIER end
    if string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_ENCHANTER))) then return CRAFTING_TYPE_ENCHANTING end
    if string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_JEWELRY))) then return CRAFTING_TYPE_JEWELRYCRAFTING end
    if string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_PROVISIONER))) then return CRAFTING_TYPE_PROVISIONING end
    if string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_WOODWORKER))) then return CRAFTING_TYPE_WOODWORKING end

    return nil
end

local function createQuestEntry(questId)
    local questName,backgroundText,activeStepText,activeStepType, activeStepTrackerOverrideText, completed, tracked, questLevel,pushed,questType,instanceDisplayType = GetJournalQuestInfo(questId)
    local repeatType = GetJournalQuestRepeatType(questId)
    local locationInfo
    if questType == QUEST_TYPE_GUILD then
        locationInfo = GetString(SI_QUESTTYPE3)
    elseif questType == QUEST_TYPE_MAIN_STORY then
        locationInfo = GetString(SI_QUESTTYPE2)
    else
        locationInfo = GetJournalQuestLocationInfo(questId)
    end
    local quest = {
        name = questName,
        backgroundText = backgroundText,
        activeStepText = activeStepText,
        activeStepType = activeStepType,
        activeStepTrackerOverrideText = activeStepTrackerOverrideText,
        questLevel = questLevel,
        questType = questType,
        instanceDisplayType = instanceDisplayType,
        location = locationInfo,
        repeatType = repeatType,
        isDaily = repeatType == QUEST_REPEAT_DAILY,
        isCrafting = questType == QUEST_TYPE_CRAFTING,
        questIndex = questId
    }
    if quest.isCrafting then
        quest.craft = LeoAltholic.GetCraftFromQuest(quest.name)
    end
    return quest
end

local function checkQuestForWrits(questName)
    for i,trackedQuest in pairs(LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs) do
        if (trackedQuest.name == questName) then
            LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastStarted = GetTimeStamp()
            LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastPreDeliver = nil
            LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastUpdated = nil
            LeoAltholicChecklistUI.startedWrit(trackedQuest.craft)
            local numConditions = GetJournalQuestNumConditions(trackedQuest.questIndex, QUEST_MAIN_STEP_INDEX)
            local hasUpdated = false
            for condition = 1, numConditions do
                local current, max =  GetJournalQuestConditionValues(trackedQuest.questIndex, QUEST_MAIN_STEP_INDEX, condition)
                if hasUpdated == false and current > 0 then
                    hasUpdated = true
                end
                local condText = GetJournalQuestConditionInfo(trackedQuest.questIndex, QUEST_MAIN_STEP_INDEX, condition)
                if string.find(condText, GetString(LEOALT_DELIVER)) then
                    LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastPreDeliver = GetTimeStamp()
                    LeoAltholicChecklistUI.preDeliverWrit(trackedQuest.craft)
                    hasUpdated = false
                    break
                end
            end
            if hasUpdated then
                LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastUpdated = GetTimeStamp()
                LeoAltholicChecklistUI.updateWrit(trackedQuest.craft)
            end
            LeoAltholicUI.writsList:RefreshData()
            return
        end
    end
end

local function initAccountData()
    if LeoAltholic.globalData.AccountData == nil then LeoAltholic.globalData.AccountData = {} end

    if LeoAltholic.globalData.AccountData.inventory == nil then
        LeoAltholic.globalData.AccountData.inventory = {}
        LeoAltholic.globalData.AccountData.inventory[BAG_BANK] = {
            size = GetBagSize(BAG_BANK),
            used = GetNumBagUsedSlots(BAG_BANK),
            free = GetNumBagFreeSlots(BAG_BANK),
            list = {}
        }
        LeoAltholic.globalData.AccountData.inventory[BAG_SUBSCRIBER_BANK] = {
            size = GetBagSize(BAG_SUBSCRIBER_BANK),
            used = GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK),
            free = GetNumBagFreeSlots(BAG_SUBSCRIBER_BANK),
            list = {}
        }
    end
    if LeoAltholic.globalData.AccountData.inventory[BAG_BANK].list == nil then
        LeoAltholic.globalData.AccountData.inventory[BAG_BANK].list = {}
        LeoAltholic.globalData.AccountData.inventory[BAG_SUBSCRIBER_BANK].list = {}
    end

    LeoAltholic.globalData.AccountData.inventory[BAG_BANK].size = GetBagSize(BAG_BANK)
    LeoAltholic.globalData.AccountData.inventory[BAG_BANK].used = GetNumBagUsedSlots(BAG_BANK)
    LeoAltholic.globalData.AccountData.inventory[BAG_BANK].free = GetNumBagFreeSlots(BAG_BANK)

    LeoAltholic.globalData.AccountData.inventory[BAG_SUBSCRIBER_BANK].size = GetBagSize(BAG_SUBSCRIBER_BANK)
    LeoAltholic.globalData.AccountData.inventory[BAG_SUBSCRIBER_BANK].used = GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK)
    LeoAltholic.globalData.AccountData.inventory[BAG_SUBSCRIBER_BANK].free = GetNumBagFreeSlots(BAG_SUBSCRIBER_BANK)

    LeoAltholic.globalData.AccountData.inventory.money = GetBankedMoney()
    LeoAltholic.globalData.AccountData.inventory.ap = GetCurrencyAmount(CURT_ALLIANCE_POINTS, CURRENCY_LOCATION_BANK)
    LeoAltholic.globalData.AccountData.inventory.telvar = GetCurrencyAmount(CURT_TELVAR_STONES, CURRENCY_LOCATION_BANK)
    LeoAltholic.globalData.AccountData.inventory.writVoucher = GetCurrencyAmount(CURT_WRIT_VOUCHERS, CURRENCY_LOCATION_BANK)
    LeoAltholic.globalData.AccountData.inventory.soulGemFilled = LeoAltholic.globalData.AccountData.inventory.soulGemFilled or 0
    LeoAltholic.globalData.AccountData.inventory.soulGemEmpty = LeoAltholic.globalData.AccountData.inventory.soulGemEmpty or 0
end

local function initCharsData()

    if LeoAltholic.globalData.CharList == nil then LeoAltholic.globalData.CharList = {} end

    LeoAltholic.CharName = GetUnitName("player")

    local function getStat(stat) return GetPlayerStat(stat, STAT_BONUS_OPTION_APPLY_BONUS) end

    local numChars = GetNumCharacters()
    for k, v in pairs(LeoAltholic.globalData.CharList) do
        local deleted = true
        for i = 1, numChars do
            local charName = GetCharacterInfo(i)
            charName = charName:gsub("%^.+", "")
            if k == charName then
                deleted = false
                break
            end
        end
        if deleted then
            LeoAltholic.globalData.CharList[k] = nil
        end
    end

    LeoAltholic.CharNum = 0
    local char = LeoAltholic.globalData.CharList[LeoAltholic.CharName] or {
        bio = {},
        quests = {
            actives = {},
            tracked = {},
            writs = {}
        }
    }

    char.bio.name = LeoAltholic.CharName
    char.bio.gender = GetUnitGender("player")
    if char.bio.gender == 1 then
        char.bio.genderName = GetString(SI_GENDER1)
    else
        char.bio.genderName = GetString(SI_GENDER2)
    end
    char.bio.level = GetUnitLevel("player")
    char.bio.effectiveLevel = GetUnitEffectiveLevel("player")
    char.bio.isChampion = IsUnitChampion("player")
    char.bio.canChampion = CanUnitGainChampionPoints("player")
    char.bio.championPoints = GetPlayerChampionPointsEarned("player")
    char.bio.race = GetUnitRace("player")
    char.bio.raceId = GetUnitRaceId("player")
    char.bio.class = GetUnitClass("player")
    char.bio.classId = GetUnitClassId("player")
    char.bio.alliance = {
        id = GetUnitAlliance("player"),
        name = GetAllianceName(GetUnitAlliance("player")),
        rank = GetUnitAvARank("player"),
        points = GetCarriedCurrencyAmount(CURT_ALLIANCE_POINTS)
    }
    char.secondsPlayed = GetSecondsPlayed()
    char.bounty = GetBounty()

    local riding = {GetRidingStats()}
    local ridetime = GetTimeUntilCanBeTrained()/1000 or 0
    if ridetime > 1 then ridetime = ridetime + GetTimeStamp() end

    if char.attributes and char.attributes.riding and char.attributes.riding.time and char.attributes.riding.time > 0 and
            GetDiffBetweenTimeStamps(char.attributes.riding.time - GetTimeStamp()) < 0 then
        local data = {
            id = '$M' .. char.bio.name,
            charName = char.bio.name,
            info = ZO_CachedStrFormat(GetString(LEOALT_MOUNT_FINISHED), char.bio.name),
            time = char.attributes.riding.time
        }
        LeoAltholic.AddToQueue(data)
    end

    char.attributes = {
        unspent = GetAttributeUnspentPoints(),
        health = {
            points = GetAttributeSpentPoints(ATTRIBUTE_HEALTH),
            max = getStat(STAT_HEALTH_MAX),
            recovery = getStat(STAT_HEALTH_REGEN_COMBAT)
        },
        magicka = {
            points = GetAttributeSpentPoints(ATTRIBUTE_MAGICKA),
            max = getStat(STAT_MAGICKA_MAX),
            recovery = getStat(STAT_MAGICKA_REGEN_COMBAT)
        },
        stamina = {
            points = GetAttributeSpentPoints(ATTRIBUTE_STAMINA),
            max = getStat(STAT_STAMINA_MAX),
            recovery = getStat(STAT_STAMINA_REGEN_COMBAT)
        },
        riding = {
            capacity = riding[1],
            capacityMax = riding[2],
            stamina = riding[3],
            staminaMax = riding[4],
            speed = riding[5],
            speedMax = riding[6],
            time = ridetime
        },
        weapon = {
            damage = getStat(STAT_WEAPON_POWER),
            critical = getStat(STAT_CRITICAL_STRIKE),
            criticalChance = GetCriticalStrikeChance(getStat(STAT_CRITICAL_STRIKE))
        },
        spell = {
            damage = getStat(STAT_SPELL_POWER),
            critical = getStat(STAT_SPELL_CRITICAL),
            criticalChance = GetCriticalStrikeChance(getStat(STAT_SPELL_CRITICAL))
        }
    }
    char.attributes.total = char.attributes.unspent + char.attributes.health.points + char.attributes.magicka.points + char.attributes.stamina.points

    char.resistances = {
        armor             = getStat(STAT_ARMOR_RATING),
        spell      = getStat(STAT_SPELL_RESIST),
        crit       = getStat(STAT_CRITICAL_RESISTANCE),
        cold       = getStat(STAT_DAMAGE_RESIST_COLD),
        disease    = getStat(STAT_DAMAGE_RESIST_DISEASE),
        drown      = getStat(STAT_DAMAGE_RESIST_DROWN),
        earth      = getStat(STAT_DAMAGE_RESIST_EARTH),
        fire       = getStat(STAT_DAMAGE_RESIST_FIRE),
        generic    = getStat(STAT_DAMAGE_RESIST_GENERIC),
        magic      = getStat(STAT_DAMAGE_RESIST_MAGIC),
        oblivion   = getStat(STAT_DAMAGE_RESIST_OBLIVION),
        resistPhysical   = getStat(STAT_DAMAGE_RESIST_PHYSICAL),
        poison     = getStat(STAT_DAMAGE_RESIST_POISON),
        shock      = getStat(STAT_DAMAGE_RESIST_SHOCK),
        start      = getStat(STAT_DAMAGE_RESIST_START),
        mitigation        = getStat(STAT_MITIGATION),
        physical   = getStat(STAT_PHYSICAL_RESIST),
        spell_mitigation  = getStat(STAT_SPELL_MITIGATION),
        miss              = getStat(STAT_MISS),
        parry             = getStat(STAT_PARRY),
        block             = getStat(STAT_BLOCK),
        dodge             = getStat(STAT_DODGE)
    }

    char.skills = { }
    char.skills.unspent = GetAvailableSkillPoints()
    char.skills.skyShards = GetNumSkyShards()

    local skillType = SKILL_TYPE_ARMOR
    char.skills.armor = {}
    local baseElem = char.skills.armor
    loadPlayerDataPart(skillType,baseElem)

    --
    skillType = SKILL_TYPE_WORLD
    char.skills.world = {}
    baseElem = char.skills.world
    loadPlayerDataPart(skillType,baseElem)

    --
    skillType = SKILL_TYPE_CLASS
    char.skills.class = {}
    baseElem = char.skills.class
    loadPlayerDataPart(skillType,baseElem)

    --
    skillType = SKILL_TYPE_GUILD
    char.skills.guild = {}
    baseElem = char.skills.guild
    loadPlayerDataPart(skillType,baseElem)

    --
    skillType = SKILL_TYPE_RACIAL
    char.skills.racial = {}
    baseElem = char.skills.racial
    loadPlayerDataPart(skillType,baseElem)

    --
    skillType = SKILL_TYPE_WEAPON
    char.skills.weapon = {}
    baseElem = char.skills.weapon
    loadPlayerDataPart(skillType,baseElem)

    --
    skillType = SKILL_TYPE_AVA
    char.skills.ava = {}
    baseElem = char.skills.ava
    loadPlayerDataPart(skillType,baseElem)

    skillType = SKILL_TYPE_TRADESKILL
    char.skills.craft = {}
    baseElem = char.skills.craft
    loadPlayerDataPart(skillType,baseElem)

    local function GetCraftBonus(craft)
        local skillType0, skillId = GetCraftingSkillLineIndices(craft)
        local _, rank = GetSkillLineInfo(skillType0,skillId)
        return {rank = rank, max = GetMaxSimultaneousSmithingResearch(craft) or 1}
    end

    if char.research ~= nil and char.research.doing ~= nil then
        for _,craft in pairs(LeoAltholic.craftResearch) do
            if char.research.doing[craft] ~= nil then
                for line = 1, GetNumSmithingResearchLines(craft) do
                    local lineName, lineIcon = GetSmithingResearchLineInfo(craft, line)
                    for trait = 1, LeoAltholic.maxTraits do
                        local traitType, _, known = GetSmithingResearchLineTraitInfo(craft, line, trait)
                        if known then
                            char.research.done[craft][line][trait] = true
                        else
                            local _,remaining = GetSmithingResearchLineTraitTimes(craft,line,trait)
                            if remaining and remaining > 0 then
                                table.insert(char.research.doing[craft], {
                                    craft = craft,
                                    line = line,
                                    trait = trait,
                                    remaining = remaining,
                                    doneAt = remaining + GetTimeStamp()
                                })
                                local data = {
                                    id = '$R' .. char.bio.name..craft..line..trait,
                                    charName = char.bio.name,
                                    info = ZO_CachedStrFormat(
                                            GetString(LEOALT_RESEARCH_FINISHED) .. ': |c00FF00<<C:2>> <<C:3>>|r.',
                                            char.bio.name,
                                            GetString('SI_ITEMTRAITTYPE',traitType),
                                            lineName
                                    ),
                                    time = remaining + GetTimeStamp()
                                }
                                LeoAltholic.AddToQueue(data)
                            end
                        end
                    end
                end
                table.sort(char.research.doing[craft], function(a, b)
                    if a.remaining == nil then a.remaining = 0 end
                    if b.remaining == nil then b.remaining = 0 end
                    return a.remaining < b.remaining
                end)
            end
        end
    end

    char.research = {}
    char.research.done = {}
    char.research.doing = {}
    for _,craft in pairs(LeoAltholic.craftResearch) do
        char.research.done[craft] = GetCraftBonus(craft)
        char.research.doing[craft] = {}
        for line = 1, GetNumSmithingResearchLines(craft) do
            char.research.done[craft][line] = {}
            local lineName, lineIcon = GetSmithingResearchLineInfo(craft, line)
            for trait = 1, LeoAltholic.maxTraits do
                local traitType, _, known = GetSmithingResearchLineTraitInfo(craft, line, trait)
                if known then
                    char.research.done[craft][line][trait] = true
                else
                    local _,remaining = GetSmithingResearchLineTraitTimes(craft,line,trait)
                    if remaining and remaining > 0 then
                        table.insert(char.research.doing[craft], {
                            craft = craft,
                            line = line,
                            trait = trait,
                            remaining = remaining,
                            doneAt = remaining + GetTimeStamp()
                        })
                        local data = {
                            id = '$R' .. char.bio.name..craft..line..trait,
                            charName = char.bio.name,
                            info = ZO_CachedStrFormat(
                                    GetString(LEOALT_RESEARCH_FINISHED) .. ': |c00FF00<<C:2>> <<C:3>>|r.',
                                    char.bio.name,
                                    GetString('SI_ITEMTRAITTYPE',traitType),
                                    lineName
                            ),
                            time = remaining + GetTimeStamp()
                        }
                        LeoAltholic.AddToQueue(data)
                    end
                end
            end
        end
        table.sort(char.research.doing[craft], function(a, b)
            return a.remaining < b.remaining
        end)
    end

    char.champion = {}
    for disciplineIndex = 1, GetNumChampionDisciplines() do
        local disciplineId = GetChampionDisciplineId(disciplineIndex)
        char.champion[disciplineIndex] = {
            spent = GetNumSpentChampionPoints(disciplineId),
            unspent = GetNumUnspentChampionPoints(disciplineId),
            skills = {}
        }
        for skill = 1, GetNumChampionDisciplineSkills(disciplineIndex) do
            local id = GetChampionSkillId(disciplineIndex, skill)
            char.champion[disciplineIndex].skills[skill] = GetNumPointsSpentOnChampionSkill(id)
        end
    end

    char.inventory = {}
    char.inventory.size = GetBagSize(BAG_BACKPACK)
    char.inventory.used = GetNumBagUsedSlots(BAG_BACKPACK)
    char.inventory.free = GetNumBagFreeSlots(BAG_BACKPACK)

    local _, _, soulGemEmpty = GetSoulGemInfo(SOUL_GEM_TYPE_EMPTY, char.bio.level, true)
    local _, _, soulGemFilled = GetSoulGemInfo(SOUL_GEM_TYPE_FILLED, char.bio.level, true)
    char.inventory.soulGemEmpty = soulGemEmpty
    char.inventory.soulGemFilled = soulGemFilled

    char.inventory.ap = GetAlliancePoints()
    char.inventory.gold = GetCurrentMoney()
    char.inventory.telvar = GetCarriedCurrencyAmount(CURT_TELVAR_STONES)
    char.inventory.writVoucher = GetCarriedCurrencyAmount(CURT_WRIT_VOUCHERS)

    local ARMOR_TYPE_NAMES = {
        [ARMORTYPE_LIGHT]  = "Light",
        [ARMORTYPE_MEDIUM] = "Medium",
        [ARMORTYPE_HEAVY]  = "Heavy",
    }

    char.inventory[BAG_WORN] = {}
    char.inventory[BAG_BACKPACK] = {}
    if LeoAltholic.globalData.settings.inventory.enabled then
        local bag = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_WORN, BAG_BACKPACK)
        for _, data in pairs(bag) do
            local itemLink = GetItemLink(data.bagId, data.slotIndex)
            local traitType = GetItemLinkTraitInfo(itemLink)
            local traitName = (traitType ~= ITEM_TRAIT_TYPE_NONE) and GetString("SI_ITEMTRAITTYPE", traitType) or "-"

            local hasEnchant, enchantHeader = GetItemLinkEnchantInfo(itemLink)
            local enchantName = "-"
            if hasEnchant and enchantHeader and enchantHeader ~= "" then
                enchantName = zo_strformat("<<1>>", enchantHeader):gsub("^Enchantment:%s*", ""):gsub("%s+Enchantment$", "")
            end

            local armorType = GetItemLinkArmorType(itemLink)
            local weightName = ARMOR_TYPE_NAMES[armorType] or "-"

            char.inventory[data.bagId][data.slotIndex] = {
                link = itemLink,
                name = data.name,
                count = data.stackCount,
                trait = traitName,
                enchant = enchantName,
                weight = weightName,
            }
        end
    end



    if char.stats == nil then char.stats = {} end

    if char.quests == nil then
        char.quests = {
            actives = {},
            tracked = {},
            writs = {}
        }
    end

    if char.quests.writs == nil then char.quests.writs = {} end
    if char.quests.tracked == nil then char.quests.tracked = {} end

    local n = 0
    char.quests.actives = {}
    for i = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(i) then
            local quest = createQuestEntry(i)
            table.insert(char.quests.actives, quest)
            n = n + 1
        end
    end
    --char.achievements = createCharDataAchievements()

    LeoAltholic.globalData.CharList[LeoAltholic.CharName] = char
end

--[[
local function parseAchievementLinkId(link)

    if (link == nil or link == "") then
        return -1, 0, 0
    end

    local linkType, itemText, achId, achData, achTimestamp = link:match("|H(.-):(.-):(.-):(.-):(.-)|h|h")

    if (achId == nil or achData == nil or achTimestamp == nil) then
        return -1, 0, 0
    end

    return achId, tonumber(achData), tonumber(achTimestamp)
end

local function createCharDataAchievements()
    local achievements = {}
    local numTopLevelCategories = GetNumAchievementCategories()
    local countCategory = 1

    for topLevelIndex = 1, numTopLevelCategories do
        local cateName, numCategories, numCateAchievements, earnedPoints, totalPoints, hidesPoints = GetAchievementCategoryInfo(topLevelIndex)

        if earnedPoints > 0 then

            achievements[countCategory] = {
                id = topLevelIndex,
                name = cateName,
                earnedPoints = earnedPoints,
                totalPoints = totalPoints,
                subCategory = {}
            }

            local countSub = 1

            for categoryIndex = 1, numCategories do
                local subcategoryName, numAchievements, earnedSubSubPoints, totalSubSubPoints, hidesSubSubPoints = GetAchievementSubCategoryInfo(topLevelIndex, categoryIndex)

                if earnedSubSubPoints > 0 then
                    achievements[countCategory].subCategory[countSub] = {
                        name = subcategoryName,
                        earnedPoints = earnedSubSubPoints,
                        totalPoints = totalSubSubPoints,
                        achievements = {}
                    }
                    earnedPoints = earnedPoints - earnedSubSubPoints
                    totalPoints = totalPoints - totalSubSubPoints

                    local countAchiev = 1

                    for achievementIndex = 1, numAchievements do
                        local achId = GetAchievementId(topLevelIndex, categoryIndex, achievementIndex)
                        local currentId = GetFirstAchievementInLine(achId)

                        if (currentId == 0) then currentId = achId end

                        while (currentId ~= nil and currentId > 0) do
                            local achLink = GetAchievementLink(currentId)
                            local _, progress, timestamp = parseAchievementLinkId(achLink)

                            if (progress ~= 0 or timestamp ~= 0) then
                                achievements[countCategory].subCategory[countSub].achievements[countAchiev] = {
                                    id = currentId,
                                    name = GetAchievementNameFromLink(achLink),
                                    progress = progress,
                                    timestamp = timestamp,
                                    completed = IsAchievementComplete(currentId),
                                    numCriteria =  GetAchievementNumCriteria(currentId),
                                    numCriteriaDone = 0
                                }
                                local numCriteria = achievements[countCategory].subCategory[countSub].achievements[countAchiev].numCriteria
                                local numCriteriaDone = achievements[countCategory].subCategory[countSub].achievements[countAchiev].numCriteriaDone
                                for critIndex = 1, numCriteria do
                                    local _, numCompleted, numRequired = GetAchievementCriterion(currentId, critIndex)
                                    if numCompleted == numRequired then
                                        numCriteriaDone = numCriteriaDone + 1
                                    end
                                end
                                achievements[countCategory].subCategory[countSub].achievements[countAchiev].numCriteriaDone = numCriteriaDone
                                countAchiev = countAchiev + 1
                            end

                            currentId = GetNextAchievementInLine(currentId)
                        end
                    end
                    countSub = countSub + 1
                end
            end
            countCategory = countCategory + 1
        end
    end

    achievements.earnedPoints = GetEarnedAchievementPoints()
    achievements.totalPoints = GetTotalAchievementPoints()

    return achievements
end
]]

local function copy(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
    return res
end

function LeoAltholic.GetCharacters(forceUpdate)
    if #LeoAltholic.charList == 0 or forceUpdate == true or GetTimeStamp() - LeoAltholic.lastUpdatedCharList > 60 then

        LeoAltholic.charList = {}
        local i = 1
        for k, v in pairs(LeoAltholic.globalData.CharList) do
            if k ~= nil and type(v) == "table" then
                LeoAltholic.charList[i] = v
                i = i + 1
            end
        end

        local sortMode = (LeoAltholic.globalData.settings and LeoAltholic.globalData.settings.charSortOrder) or "creation"
        table.sort(LeoAltholic.charList, function(a, b)
            local nameA = a.bio and a.bio.name or ""
            local nameB = b.bio and b.bio.name or ""
            if sortMode == "alpha_asc" then
                return nameA < nameB
            elseif sortMode == "alpha_desc" then
                return nameA > nameB
            else -- "creation"
                local idxA = (a.bio and a.bio.charIndex) or 999
                local idxB = (b.bio and b.bio.charIndex) or 999
                if idxA ~= idxB then
                    return idxA < idxB
                end
                return nameA < nameB
            end
        end)

        LeoAltholic.lastUpdatedCharList = GetTimeStamp()
    end
    return LeoAltholic.charList
end

function LeoAltholic.GetItems(char, bagId)
    local itemLines =  {}
    local i = 1
    local list
    if char ~= nil and bagId >= 0 then
        list = char.inventory[bagId]
    else
        list = {}
        local n = 0
        for _,v in ipairs(LeoAltholic.globalData.AccountData.inventory[BAG_BANK].list) do n=n+1; list[n]=v end
        for _,v in ipairs(LeoAltholic.globalData.AccountData.inventory[BAG_SUBSCRIBER_BANK].list) do n=n+1; list[n]=v end
    end
    for k, v in pairs(list) do
        if k == nil then return end
        itemLines[i] = copy(v)
        i = i + 1
    end
    table.sort(itemLines, function(a, b)
        return a.name < b.name
    end)

    return itemLines
end

local function formatMessage(message)
    return LeoAltholic.chatPrefix .. message
end

function LeoAltholic.log(message)
    d(formatMessage(message))
end

local function onResearchStarted(eventCode, craft, line, trait)
    local _,remaining = GetSmithingResearchLineTraitTimes(craft,line,trait)
    table.insert(LeoAltholic.globalData.CharList[LeoAltholic.CharName].research.doing[craft], {
        craft = craft,
        line = line,
        trait = trait,
        remaining = remaining,
        doneAt = remaining + GetTimeStamp()
    })
    if LeoAltholic.IsTabVisible(LeoAltholic.TAB_RESEARCH) then
        LeoAltholicUI.researchList:RefreshData()
    end
end

local function onResearchCanceled(eventCode, craft, line, trait)
    for i, research in pairs(LeoAltholic.globalData.CharList[LeoAltholic.CharName].research.doing[craft]) do
        if research.line == line and research.trait == trait then
            table.remove(LeoAltholic.globalData.CharList[LeoAltholic.CharName].research.doing[craft], i)
            if LeoAltholic.IsTabVisible(LeoAltholic.TAB_RESEARCH) then
                LeoAltholicUI.researchList:RefreshData()
            end
            return
        end
    end
end

local function onResearchCompleted(eventCode, craft, line, trait)
    LeoAltholic.globalData.CharList[LeoAltholic.CharName].research.done[craft][line][trait] = true
    for i, research in pairs(LeoAltholic.globalData.CharList[LeoAltholic.CharName].research.doing[craft]) do
        if research.line == line and research.trait == trait then
            table.remove(LeoAltholic.globalData.CharList[LeoAltholic.CharName].research.doing[craft], i)
            break
        end
    end

    local lineName = GetSmithingResearchLineInfo(craft, line)
    local traitType = GetSmithingResearchLineTraitInfo(craft, line, trait)

    local name = GetUnitName("player")
    local msg = ZO_CachedStrFormat(
            GetString(LEOALT_RESEARCH_FINISHED) .. ': |c00FF00<<C:2>> <<C:3>>|r.',
            name,
            GetString('SI_ITEMTRAITTYPE',traitType),
            lineName
    )
    if LeoAltholic.globalData.settings.completedResearch.screen == true then
        local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, SOUNDS.SMITHING_FINISH_RESEARCH)
        messageParams:SetText(formatMessage(msg))
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
    end
    if LeoAltholic.globalData.settings.completedResearch.chat == true then
        LeoAltholic.log(msg)
    end
    if LeoAltholic.IsTabVisible(LeoAltholic.TAB_RESEARCH) then
        LeoAltholicUI.researchList:RefreshData()
    end
end

function LeoAltholic.AddToQueue(data)
    for x,queue in pairs(LeoAltholic.timerQueue) do
        if queue.id == data.id then
            return
        end
    end
    table.insert(LeoAltholic.timerQueue, data)
end

local function charStillExists(charName)
    for _, char in pairs(LeoAltholic.GetCharacters()) do
        if char.bio.name ~= charName then
            return true
        end
    end
    return false
end

local function processQueue()
    for i, data in pairs(LeoAltholic.timerQueue) do
        if charStillExists(data.charName) and not data.announced and GetDiffBetweenTimeStamps(data.time, GetTimeStamp()) <= 0 then
            if data.charName ~= LeoAltholic.CharName and LeoAltholic.globalData.settings.completedResearch.chat == true then
                LeoAltholic.log(data.info)
            end
            if data.charName == LeoAltholic.CharName and LeoAltholic.globalData.settings.completedResearch.screen == true then
                local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, SOUNDS.SMITHING_FINISH_RESEARCH)
                messageParams:SetText(formatMessage(data.info))
                CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
            end
            LeoAltholic.timerQueue[i].announced = true
            --table.remove(LeoAltholic.timerQueue, x)
        end
    end
end

local function createMessageQueue()
    for _, char in pairs(LeoAltholic.GetCharacters()) do
        if char.bio.name ~= LeoAltholic.CharName then
            if GetDiffBetweenTimeStamps(char.attributes.riding.time - GetTimeStamp()) < 0 then
                local data = {
                    id = '$M' .. char.bio.name,
                    charName = char.bio.name,
                    info = ZO_CachedStrFormat(GetString(LEOALT_MOUNT_FINISHED), char.bio.name),
                    time = char.attributes.riding.time
                }
                LeoAltholic.AddToQueue(data)
            end
            for _, craft in pairs(LeoAltholic.craftResearch) do
                if char.research.doing[craft] then
                    for _, research in pairs(char.research.doing[craft]) do
                        local lineName, lineIcon = GetSmithingResearchLineInfo(research.craft, research.line)
                        local traitType = GetSmithingResearchLineTraitInfo(research.craft, research.line, research.trait)
                        if research.doneAt ~= nil then
                            local data = {
                                id = '$R' .. char.bio.name..research.craft..research.line..research.trait,
                                charName = char.bio.name,
                                info = ZO_CachedStrFormat(
                                        GetString(LEOALT_RESEARCH_FINISHED) .. ': |c00FF00<<C:2>> <<C:3>>|r.',
                                        char.bio.name,
                                        GetString('SI_ITEMTRAITTYPE',traitType),
                                        lineName
                                ),
                                time = research.doneAt
                            }
                            LeoAltholic.AddToQueue(data)
                        end
                    end
                end
            end
        end
    end
end

--[[ Preparing for hirering timers
local function onMailRedable()
    for mailId in ZO_GetNextMailIdIter do
        senderDisplayName, senderCharacterName, subject, icon, unread, fromSystem, fromCustomerService, returned, numAttachments, attachedMoney, codAmount, expiresInDays, secsSinceReceived = GetMailItemInfo(mailId)

        if(subject == GetString(LEOALT_MAIL_BLACKSMITH) and fromSystem) then
            d(GetTimeStamp() - secsSinceReceived)
        elseif(subject == GetString(LEOALT_MAIL_CLOTHIER) and fromSystem) then
            d(GetTimeStamp() - secsSinceReceived)
        elseif(subject == GetString(LEOALT_MAIL_WOODWORKER) and fromSystem) then
            d(GetTimeStamp() - secsSinceReceived)
        elseif(subject == GetString(LEOALT_MAIL_ENCHANTER) and fromSystem) then
            d(GetTimeStamp() - secsSinceReceived)
        elseif(subject == GetString(LEOALT_MAIL_PROVISIONER) and fromSystem) then
            d(GetTimeStamp() - secsSinceReceived)
        end
    end
end
]]

local function updateMyself()
    LeoAltholic.globalData.CharList[LeoAltholic.CharName].inventory.size = GetBagSize(BAG_BACKPACK)
    LeoAltholic.globalData.CharList[LeoAltholic.CharName].inventory.used = GetNumBagUsedSlots(BAG_BACKPACK)
    LeoAltholic.globalData.CharList[LeoAltholic.CharName].inventory.free = GetNumBagFreeSlots(BAG_BACKPACK)
end

local function onUpdate()

    processQueue()

    updateMyself()
    LeoAltholicChecklistUI.checkReset()
    LeoAltholicToolbarUI:update()

    LeoAltholic.numUpdates = LeoAltholic.numUpdates + 1

    if LeoAltholic.numUpdates >= 1800 then -- 3600 seconds = 1h, forces update every hour
        LeoAltholic.numUpdates = 1
        if LeoAltholic.IsTabVisible(LeoAltholic.TAB_RESEARCH) then
            LeoAltholicUI.researchList:RefreshData()
        end
    end

    if LeoAltholic.isHidden() then return end

    if LeoAltholic.IsTabVisible(LeoAltholic.TAB_BIO) then
        LeoAltholicUI:updateBio()
    end
    if LeoAltholic.IsTabVisible(LeoAltholic.TAB_RESEARCH) then
        LeoAltholicUI:updateResearch()
    end
    if LeoAltholic.IsTabVisible(LeoAltholic.TAB_INVENTORY) then
        LeoAltholicUI.UpdateInventory()
    end

    --[[
    if LeoAltholic.numUpdates >= 30 then -- 60 seconds
        LeoAltholic.numUpdates = 1
        LeoAltholicChecklistUI.update()
        For reference only!!
        LeoAltholicUI.bioList:RefreshData()
        LeoAltholicUI.statsList:RefreshData()
        LeoAltholicUI.championList:RefreshData()
        LeoAltholicUI.invList:RefreshData()
        LeoAltholicUI.skillsList:RefreshData()
        LeoAltholicUI.skills2List:RefreshData()
        LeoAltholicUI.researchList:RefreshData()
        LeoAltholicUI.writsList:RefreshData()
    else
        if LeoAltholic.IsTabVisible(LeoAltholic.TAB_RESEARCH) then
            LeoAltholicUI:updateResearch()
        end
    end
    ]]
end

local function trackQuest(questId, automatically)
    local type = GetJournalQuestRepeatType(questId)
    if type ~= QUEST_REPEAT_DAILY then
        if automatically ~= true then
            LeoAltholic.log(GetString(LEOALT_TRACK_ONLY_DAILY))
        end
        return
    end
    local lookInto
    local quest = createQuestEntry(questId)
    if quest.isCrafting then
        lookInto = LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs
    else
        lookInto = LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.tracked
    end
    for trackedIndex,trackedQuest in pairs(lookInto) do
        if (trackedQuest.name == quest.name) then
            if quest.isCrafting then
                LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[trackedIndex].questIndex = questId
            else
                LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.tracked[trackedIndex].questIndex = questId
            end
            if automatically ~= true then
                LeoAltholic.log(ZO_CachedStrFormat(GetString(LEOALT_QUEST_ALREADY_TRACKED), quest.name))
            end
            return
        end
    end
    quest.lastDone = nil
    if quest.isCrafting then
        table.insert(LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs, quest)
    else
        table.insert(LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.tracked, quest)
    end
    LeoAltholic.log(GetString(LEOALT_TRACKING) .. " " .. quest.name .. "...")
    if quest.isCrafting then
        LeoAltholicUI.writsList:RefreshData()
    end
end

function LeoAltholic.trackQuest(questId)
    trackQuest(questId)
end

local function onQuestAdded(eventCode, journalQuestIndex, questName, objectiveName)
    local quest = createQuestEntry(journalQuestIndex)
    if quest.isDaily == false then return end
    if LeoAltholic.globalData.settings.tracked.allDaily == true or
            (quest.questType == QUEST_TYPE_CRAFTING and LeoAltholic.globalData.settings.tracked.dailyWrits == true) then
        trackQuest(journalQuestIndex, true)
    end

    checkQuestForWrits(questName)
end

local function onQuestCounterChanged(eventCode, journalQuestIndex, questName, conditionText, conditionType, currConditionVal, newConditionVal, conditionMax, isFailCondition, stepOverrideText, isPushed, isComplete, isConditionComplete, isStepHidden)
    for i,trackedQuest in pairs(LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs) do
        if (trackedQuest.name == questName) then
            LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastUpdated = GetTimeStamp()
            LeoAltholicChecklistUI.updateWrit(trackedQuest.craft)

            local numConditions = GetJournalQuestNumConditions(journalQuestIndex, QUEST_MAIN_STEP_INDEX)
            for condition = 1, numConditions do
                local cur, max =  GetJournalQuestConditionValues(journalQuestIndex, QUEST_MAIN_STEP_INDEX, condition)
                local condText = GetJournalQuestConditionInfo(journalQuestIndex, QUEST_MAIN_STEP_INDEX, condition)
                if string.find(condText, GetString(LEOALT_DELIVER)) then
                    LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastPreDeliver = GetTimeStamp()
                    LeoAltholicChecklistUI.preDeliverWrit(trackedQuest.craft)
                    break
                end
            end
            LeoAltholicUI.writsList:RefreshData()

            return
        end
    end
end

local function onQuestRemoved(eventCode, isCompleted, journalQuestIndex, questName, zoneIndex, poiIndex)
    if not isCompleted then
        for i,trackedQuest in pairs(LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs) do
            if (trackedQuest.name == questName) then
                LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastStarted = nil
                LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastPreDeliver = nil
                LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastUpdated = nil
                LeoAltholicChecklistUI.stoppedWrit(trackedQuest.craft)
                LeoAltholicUI.writsList:RefreshData()
                return
            end
        end
    end
end

local function onQuestComplete(eventCode, questName, level, previousExperience, currentExperience, rank, previousPoints, currentPoints)
    for i,trackedQuest in pairs(LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs) do
        if (trackedQuest.name == questName) then
            LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.writs[i].lastDone = GetTimeStamp()
            LeoAltholic.log(ZO_CachedStrFormat(GetString(LEOALT_QUEST_DONE_TODAY), questName))
            LeoAltholicUI.writsList:RefreshData()
            LeoAltholicChecklistUI.doneWrit(trackedQuest.craft)
            return
        end
    end
    for i,trackedQuest in pairs(LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.tracked) do
        if (trackedQuest.name == questName) then
            LeoAltholic.globalData.CharList[LeoAltholic.CharName].quests.tracked[i].lastDone = GetTimeStamp()
            LeoAltholic.log(ZO_CachedStrFormat(GetString(LEOALT_QUEST_DONE_TODAY), questName))
            return
        end
    end
end

local function addToBank(bagId, slotIndex, itemLink, name, stackCount)

    if name == nil then name = GetItemName(bagId, slotIndex) end

    table.insert(LeoAltholic.globalData.AccountData.inventory[bagId].list, {
        slotIndex = slotIndex,
        link = itemLink,
        name = name,
        count = stackCount
    })
end

local function removeFromBank(bagId, slotIndex)
    for i, item in pairs(LeoAltholic.globalData.AccountData.inventory[bagId].list) do
        if item.slotIndex == slotIndex then
            table.remove(LeoAltholic.globalData.AccountData.inventory[bagId].list, i)
            return
        end
    end
end

local function updateBank(bagId, slotIndex, stackCount)
    for i, item in pairs(LeoAltholic.globalData.AccountData.inventory[bagId].list) do
        if item.slotIndex == slotIndex then
            LeoAltholic.globalData.AccountData.inventory[bagId].list[i].count =
                LeoAltholic.globalData.AccountData.inventory[bagId].list[i].count + stackCount
            return
        end
    end
end

local function scanBank()
    LeoAltholic.globalData.AccountData.inventory[BAG_BANK].list = {}
    LeoAltholic.globalData.AccountData.inventory[BAG_SUBSCRIBER_BANK].list = {}
    local numEmptySoulGems = 0
    local numFilledSoulGems = 0

    local bagCache = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BANK, BAG_SUBSCRIBER_BANK)
    for _, data in pairs(bagCache) do
        local itemLink = GetItemLink(data.bagId, data.slotIndex)
        if IsItemSoulGem(SOUL_GEM_TYPE_FILLED, data.bagId, data.slotIndex) then
            numFilledSoulGems = numFilledSoulGems + data.stackCount
        elseif IsItemSoulGem(SOUL_GEM_TYPE_EMPTY, data.bagId, data.slotIndex) then
            numEmptySoulGems = numEmptySoulGems + data.stackCount
        end
        addToBank(data.bagId, data.slotIndex, itemLink, data.name, data.stackCount)
    end

    LeoAltholic.globalData.AccountData.inventory.soulGemEmpty = numEmptySoulGems
    LeoAltholic.globalData.AccountData.inventory.soulGemFilled = numFilledSoulGems
end

local function findIteminBank(bagId, slotIndex)
    for _, item in pairs(LeoAltholic.globalData.AccountData.inventory[bagId].list) do
        if item.slotIndex == slotIndex then return item.link end
    end
end

local function onUpdateBank(eventCode, bagId, slotId, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange)
    if inventoryUpdateReason ~= INVENTORY_UPDATE_REASON_DEFAULT or (bagId ~= BAG_BANK and bagId ~= BAG_SUBSCRIBER_BANK) then return end

    local itemLink = GetItemLink(bagId, slotId)
    local removed = false
    local found = findIteminBank(bagId, slotId)

    if itemLink == nil or itemLink == "" then
        removed = true
        itemLink = findIteminBank(bagId, slotId)
    end

    if not found and stackCountChange > 0 then
        addToBank(bagId, slotId, itemLink, nil, stackCountChange)
    elseif found and not removed then
        updateBank(bagId, slotId, stackCountChange)
    elseif found and removed then
        removeFromBank(bagId, slotId)
    end
end

local function onCloseBank(eventCode, bagId)
    EVENT_MANAGER:UnregisterForEvent(LeoAltholic.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
end

local function onOpenBank(eventCode, bagId)
    if bagId ~= BAG_BANK and bagId ~= BAG_SUBSCRIBER_BANK or not LeoAltholic.globalData.settings.inventory.enabled then return end
    EVENT_MANAGER:UnregisterForEvent(LeoAltholic.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, onUpdateBank)
    scanBank()
end

local function migrateDataToV2()
    LeoAltholic.globalData.settings.toolbar = {
        enabled = false
    }
    if LeoAltholic.globalData.CharList == nil then return end -- fresh install?
    for charName, char in pairs(LeoAltholic.globalData.CharList) do
        local oldResearch = char.research
        LeoAltholic.globalData.CharList[charName].research = {}
        LeoAltholic.globalData.CharList[charName].research.done = {}
        LeoAltholic.globalData.CharList[charName].research.doing = {}
        for _,craft in pairs(LeoAltholic.craftResearch) do
            LeoAltholic.globalData.CharList[charName].research.done[craft] = {
                max = oldResearch[craft].max or 0
            }
            LeoAltholic.globalData.CharList[charName].research.doing[craft] = {}
            for line = 1, GetNumSmithingResearchLines(craft) do
                LeoAltholic.globalData.CharList[charName].research.done[craft][line] = {}
                local lineName, _, numTraits = GetSmithingResearchLineInfo(craft, line)
                for trait = 1, numTraits do
                    if oldResearch[craft][line][trait] == true then
                        LeoAltholic.globalData.CharList[charName].research.done[craft][line][trait] = true
                    end
                end
            end
        end
    end
end

local function migrateDataToV3()
    if LeoAltholic.globalData.CharList == nil then return end -- fresh install?
    for charName, char in pairs(LeoAltholic.globalData.CharList) do
        for i = 1, GetNumChampionDisciplines() do
            if LeoAltholic.globalData.CharList[charName].champion[i].disciplines or not LeoAltholic.globalData.CharList[charName].champion[i].spent then
                LeoAltholic.globalData.CharList[charName].champion[i] = {
                    spent = 0,
                    unspent = 0,
                    skills = {}
                }
            end
        end
    end
end

local function initializeVars()
    local charDefault = {
        settings = {
            checklist = {
                enabled = true,
                hidden = false,
                craft = {},
                riding = true
            },
            inventory = {
                enabled = true
            }
        }
    }
    charDefault.settings.checklist.craft[CRAFTING_TYPE_ALCHEMY] = true
    charDefault.settings.checklist.craft[CRAFTING_TYPE_BLACKSMITHING] = true
    charDefault.settings.checklist.craft[CRAFTING_TYPE_CLOTHIER] = true
    charDefault.settings.checklist.craft[CRAFTING_TYPE_ENCHANTING] = true
    charDefault.settings.checklist.craft[CRAFTING_TYPE_JEWELRYCRAFTING] = true
    charDefault.settings.checklist.craft[CRAFTING_TYPE_PROVISIONING] = true
    charDefault.settings.checklist.craft[CRAFTING_TYPE_WOODWORKING] = true

    LeoAltholic.charData = ZO_SavedVars:NewCharacterIdSettings("LeoAltholicCharVariables", 2, nil, charDefault)
    LeoAltholic.globalData = ZO_SavedVars:NewAccountWide("LeoAltholicSavedVariables", 2, nil, nil, GetWorldName())
    if not LeoAltholic.globalData.settings or LeoAltholic.globalData.settings == nil then
        LeoAltholic.globalData.settings = {
            tracked = {
                dailyWrits = true,
                allDaily = false
            },
            completedResearch = {
                chat = true,
                screen = true
            },
            toolbar = {
                enabled = false
            },
            checklist = {
                fontScale = 100,
                upwards = false
            },
            inventory = {
                enabled = true
            }
        }
    end

    LeoAltholicChecklistUI.normalizeSettings()
    LeoAltholicToolbarUI.normalizeSettings()

    if not LeoAltholic.globalData.dataVersion or LeoAltholic.globalData.dataVersion < 2 then
        migrateDataToV2()
        LeoAltholic.globalData.dataVersion = 2
    end
    if LeoAltholic.globalData.dataVersion < 3 then
        migrateDataToV3()
        LeoAltholic.globalData.dataVersion = 3
    end
    if LeoAltholic.globalData.settings.inventory == nil then
        LeoAltholic.globalData.settings.inventory = {
            enabled = true
        }
    end

    initCharsData()
    initAccountData()
end

local function onGameMenuEnter()
    LeoAltholicChecklist:SetHidden(true)
end

local function onGameMenuExit()
    LeoAltholicChecklistUI:CheckHide()
end

local function initialize()

    local showButton, feedbackWindow = LibFeedback:initializeFeedbackWindow(LeoAltholic,
        LeoAltholic.name,LeoAltholicWindow, "@LeandroSilva",
        {TOPRIGHT, LeoAltholicWindow, TOPRIGHT,-50,3},
        {0,1000,10000,"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=Y9KM4PZU2UZ6A"},
        "If you found a bug, have a request or a suggestion, or simply wish to donate, send a mail.")
    LeoAltholic.feedback = feedbackWindow
    LeoAltholic.feedback:SetDrawLayer(DL_OVERLAY)
    LeoAltholic.feedback:SetDrawTier(DT_MEDIUM)

    LeoAltholic.RestorePosition()
    LeoAltholicToolbarUI.RestorePosition()
    LeoAltholicChecklistUI.RestorePosition()

    LeoAltholicUI.InitPanels()
    createMessageQueue()

    --[[
    local keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = "Track with " .. LeoAltholic.displayName,
            keybind = "LEOALTHOLIC_TRACK_QUEST",
            enabled = function() return true end,
            visible = function()
                if not LeoAltholic.questSceneOpened then return false end
                local questIndex = QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex()
                return GetJournalQuestRepeatType(questIndex) == QUEST_REPEAT_DAILY
            end,
            order = 100,
            callback = function()
                trackQuest(QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex())
            end,
        }
    }

    QUEST_JOURNAL_SCENE:RegisterCallback("StateChange",
            function(oldState, newState)
                KEYBIND_STRIP:RemoveKeybindButtonGroup(keybindStripDescriptor)
                if newState == SCENE_SHOWING then
                    LeoAltholic.questSceneOpened = true
                elseif(newState == SCENE_SHOWN) then
                    KEYBIND_STRIP:AddKeybindButtonGroup(keybindStripDescriptor)
                else
                    LeoAltholic.questSceneOpened = false
                end
            end)

    QUEST_JOURNAL_KEYBOARD:RegisterCallback("QuestSelected",
            function(questId)
                local type = GetJournalQuestRepeatType(questId)
                if type == QUEST_REPEAT_DAILY then
                    KEYBIND_STRIP:AddKeybindButtonGroup(keybindStripDescriptor)
                else
                    KEYBIND_STRIP:RemoveKeybindButtonGroup(keybindStripDescriptor)
                end
            end)
    ]]

    LeoAltholic.settings = LeoAltholic_Settings:New()
    LeoAltholic.settings:CreatePanel()

    LeoAltholic.initialized = true
    CALLBACK_MANAGER:FireCallbacks("LeoAltholicInitialized")
    LeoAltholicToolbarUI:update()
    LeoAltholicChecklistUI.initializeQuests()
    LeoAltholicChecklistUI.update()
    LeoAltholicUI:updateResearch()
    LeoAltholicUI.InitInventory()
end

local orig_ZO_QuestJournalNavigationEntry_OnMouseUp = ZO_QuestJournalNavigationEntry_OnMouseUp

function ZO_QuestJournalNavigationEntry_OnMouseUp(label, button, upInside)
    orig_ZO_QuestJournalNavigationEntry_OnMouseUp(label, button, upInside)
    if button == MOUSE_BUTTON_INDEX_RIGHT and upInside then
        local questIndex = label.node.data.questIndex
        if questIndex and GetJournalQuestRepeatType(questIndex) == QUEST_REPEAT_DAILY then
            AddMenuItem("Track with " .. LeoAltholic.displayName, function()
                trackQuest(questIndex)
            end)
            ShowMenu(label)
        end
    end
end

local function onNewMovementInUIMode(eventCode)
    if not LeoAltholicWindow:IsHidden() then LeoAltholic.CloseUI() end
end

local function onChampionPerksSceneStateChange(oldState,newState)
    if newState == SCENE_SHOWING then
        if not LeoAltholicWindow:IsHidden() then LeoAltholic.CloseUI() end
    end
end

local function onPlayerDeactivated(event, addonName)
    EVENT_MANAGER:UnregisterForEvent(LeoAltholic.Name, EVENT_PLAYER_DEACTIVATED)
    initCharsData()
    initAccountData()
end

local function onRidingSkillImprovement(ridingSkill, previous, current, source)
    local riding = {GetRidingStats()}
    local ridetime = GetTimeUntilCanBeTrained()/1000 or 0
    if ridetime > 1 then ridetime = ridetime + GetTimeStamp() end

    LeoAltholic.globalData.CharList[LeoAltholic.CharName].attributes.riding = {
        capacity = riding[1],
        capacityMax = riding[2],
        stamina = riding[3],
        staminaMax = riding[4],
        speed = riding[5],
        speedMax = riding[6],
        time = ridetime
    }
    LeoAltholicChecklistUI.doneRiding()
    LeoAltholicUI.bioList:RefreshData()
end

local function onChampionPointsChanged()
    LeoAltholic.globalData.CharList[LeoAltholic.CharName].champion = {}
    for disciplineIndex = 1, GetNumChampionDisciplines() do
        local disciplineId = GetChampionDisciplineId(disciplineIndex)
        LeoAltholic.globalData.CharList[LeoAltholic.CharName].champion[disciplineIndex] = {
            spent = GetNumSpentChampionPoints(disciplineId),
            unspent = GetNumUnspentChampionPoints(disciplineId),
            skills = {}
        }
        for skill = 1, GetNumChampionDisciplineSkills(disciplineIndex) do
            local id = GetChampionSkillId(disciplineIndex, skill)
            LeoAltholic.globalData.CharList[LeoAltholic.CharName].champion[disciplineIndex].skills[skill] = GetNumPointsSpentOnChampionSkill(id)
        end
    end
    LeoAltholicUI.championList:RefreshData()
end

local function onAddOnLoaded(event, addonName)
    if addonName ~= LeoAltholic.name then return end

    EVENT_MANAGER:UnregisterForEvent(LeoAltholic.name, EVENT_ADD_ON_LOADED)
    SCENE_MANAGER:RegisterTopLevel(LeoAltholicWindow, false)
    SCENE_MANAGER:RegisterTopLevel(LeoAltholicInventoryWindow, false)

    if GetDisplayName() == "@LeandroSilva" then
        SLASH_COMMANDS["/rr"] = function(cmd) ReloadUI() end
    end
    SLASH_COMMANDS["/leoalt"] = function(cmd)
        if not cmd or cmd == "" then
            LeoAltholic:ToggleUI()
            return
        end

        if cmd == "checklist" then
            LeoAltholicChecklistUI.ToggleUI()
            return
        end
    end

    initializeVars()
    stampCharacterOrder()
    
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED, onResearchCompleted)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_SMITHING_TRAIT_RESEARCH_STARTED, onResearchStarted)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_SMITHING_TRAIT_RESEARCH_CANCELED, onResearchCanceled)

    initialize()

    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_PLAYER_DEACTIVATED, onPlayerDeactivated)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_QUEST_COMPLETE, onQuestComplete)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_QUEST_ADDED, onQuestAdded)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_QUEST_REMOVED, onQuestRemoved)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_QUEST_CONDITION_COUNTER_CHANGED, onQuestCounterChanged)

    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_OPEN_BANK, onOpenBank)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_CLOSE_BANK, onCloseBank)

    --EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_MAIL_READABLE, onMailRedable)
    --EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_SKILL_POINTS_CHANGED, onUpdateSkills)
    EVENT_MANAGER:RegisterForUpdate(LeoAltholic.name, 2000, onUpdate)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_NEW_MOVEMENT_IN_UI_MODE, onNewMovementInUIMode)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_RIDING_SKILL_IMPROVEMENT, onRidingSkillImprovement)
    CHAMPION_PERKS_SCENE:RegisterCallback('StateChange', onChampionPerksSceneStateChange)

    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_CRAFTING_STATION_INTERACT, onGameMenuEnter)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_END_CRAFTING_STATION_INTERACT, onGameMenuExit)
    ZO_PreHookHandler(ZO_GameMenu_InGame, "OnShow", onGameMenuEnter)
    ZO_PreHookHandler(ZO_GameMenu_InGame, "OnHide", onGameMenuExit)
    ZO_PreHookHandler(ZO_InteractWindow, "OnShow", onGameMenuEnter)
    ZO_PreHookHandler(ZO_InteractWindow, "OnHide", onGameMenuExit)
    ZO_PreHookHandler(ZO_KeybindStripControl, "OnShow", onGameMenuEnter)
    ZO_PreHookHandler(ZO_KeybindStripControl, "OnHide", onGameMenuExit)
    ZO_PreHookHandler(ZO_MainMenuCategoryBar, "OnShow", onGameMenuEnter)
    ZO_PreHookHandler(ZO_MainMenuCategoryBar, "OnHide", onGameMenuExit)

    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_CHAMPION_PURCHASE_RESULT, onChampionPointsChanged)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_CHAMPION_POINT_GAINED, onChampionPointsChanged)

    LeoAltholic.log("started.")
end

EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_ADD_ON_LOADED, onAddOnLoaded)
