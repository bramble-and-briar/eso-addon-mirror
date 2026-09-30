local AH = _G.EASArchiveHelper

AH.MissingAbilities = {}

function AH.GetAchievementsList()
    local list = {}

    for _, info in pairs(AH.ABILITIES) do
        for _, achievementId in ipairs(info.ids) do
            if (not ZO_IsElementInNumericallyIndexedTable(list, achievementId)) then
                table.insert(list, achievementId)
            end
        end
    end

    return list
end

function AH.GetAbilities(achievementIdToFind)
    local abilities = {}

    for abilityId, info in pairs(AH.ABILITIES) do
        if (ZO_IsElementInNumericallyIndexedTable(info.ids, achievementIdToFind)) then
            if (not AH.IsRecorded(abilityId, abilities)) then
                local name
                if (AH.EXCEPTIONS[abilityId]) then
                    name = GetString(AH.EXCEPTIONS[abilityId])
                else
                    name = GetAbilityName(abilityId, "player")
                end

                if (name and name ~= "") then
                    table.insert(abilities, { id = abilityId, name = AH.LC.Format(name) })
                end
            end
        end
    end

    return abilities
end

function AH.CheckAbilities(text, abilities)
    for _, ability in ipairs(abilities) do
        if (text:find(ability.name, 1, true)) then
            return ability.id
        end
    end

    return 0
end

AH.IncompleteAchievements = {}

function AH.FindMissingAbilityIds(event, id)
    if (event == EVENT_ACHIEVEMENT_UPDATED) then
        AH.EventNotifier(id)

        if (ZO_IsElementInNumericallyIndexedTable(AH.ACHIEVEMENTS.LIMIT, id)) then
            return
        end
    end

    local achievementIds = AH.GetAchievementsList()
    local incomplete = {}

    ZO_ClearNumericallyIndexedTable(AH.MissingAbilities)

    for _, achievementId in ipairs(achievementIds) do
        local status = AH.GetAchievementStatus(achievementId)

        if (status ~= _G.ZO_ACHIEVEMENTS_COMPLETION_STATUS.COMPLETE) then
            table.insert(incomplete, achievementId)
        end
    end

    if (#incomplete == 0) then
        AH.IncompleteAchievements = {}

        return
    end

    for _, achievementId in ipairs(incomplete) do
        local abilities = AH.GetAbilities(achievementId)
        local numCriteria = GetAchievementNumCriteria(achievementId)

        for criterionNumber = 1, numCriteria do
            local description, completed, required = GetAchievementCriterion(achievementId, criterionNumber)

            if (completed ~= required) then
                local aid = AH.CheckAbilities(description, abilities)

                if (not AH.IsRecorded(aid, AH.MissingAbilities, achievementId)) then
                    table.insert(AH.MissingAbilities, { id = aid, achievementId = achievementId })
                end
            end
        end
    end

    AH.IncompleteAchievements = incomplete
end

function AH.GetAbilityNeededForGeneralAchievement(abilityId)
    local achievements = AH.ABILITIES[abilityId].ids
    local neededFor = {}

    for _, achievementId in ipairs(achievements) do
        if (ZO_IsElementInNumericallyIndexedTable(AH.GENERAL, achievementId)) then
            local status = AH.GetAchievementStatus(achievementId)

            if (status ~= _G.ZO_ACHIEVEMENTS_COMPLETION_STATUS.COMPLETE) then
                table.insert(neededFor, achievementId)
            end
        end
    end

    return neededFor
end
