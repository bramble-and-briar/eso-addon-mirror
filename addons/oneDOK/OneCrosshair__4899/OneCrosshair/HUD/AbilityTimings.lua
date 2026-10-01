local O = OneCrosshair
local A = { entries = {}, maxActiveRank = 4 }
O.AbilityTimings = A

-- The client catalog is the source of truth, including unlocked classes,
-- morphs/ranks and the currently configured scribed ability. No guessed IDs.
function A.Refresh(id)
    if type(id) ~= "number" or id <= 0 then return nil end
    local channel, duration = GetAbilityCastInfo(id, nil, "player")
    if type(duration) ~= "number" or duration ~= duration or duration == math.huge or duration <= 0 then
        A.entries[id] = nil
        return nil
    end
    local data = O.HeavyChannelData
    local row = { abilityId = id, name = GetAbilityName(id), channeled = channel,
        baseDuration = duration, duration = duration,
        excluded = data.unbounded[id] or data.mendWounds[id] or false }
    if data.fatecarver[id] then
        row.crux = data.Crux()
        row.duration = duration + row.crux * data.cruxExtensionMs
    end
    A.entries[id] = row
    return row
end

function A.Rebuild()
    A.entries = {}
    for skillType = 1, GetNumSkillTypes() do
        for line = 1, GetNumSkillLines(skillType) do
            for skill = 1, GetNumSkillAbilities(skillType, line) do
                -- Crafted skills have no conventional progression; branch first.
                if IsCraftedAbilitySkill(skillType, line, skill) then
                    A.Refresh(GetAbilityIdForCraftedAbilityId(GetCraftedAbilitySkillCraftedAbilityId(skillType, line, skill)))
                elseif not IsSkillAbilityPassive(skillType, line, skill) then
                    A.Refresh(GetSkillAbilityId(skillType, line, skill, false))
                    local progression = GetProgressionSkillProgressionId(skillType, line, skill)
                    if progression and progression > 0 then
                        for _, morph in ipairs({ MORPH_SLOT_BASE, MORPH_SLOT_MORPH_1, MORPH_SLOT_MORPH_2 }) do
                            for rank = 1, A.maxActiveRank do
                                A.Refresh(GetSpecificSkillAbilityInfo(skillType, line, skill, morph, rank))
                            end
                            for _, id in ipairs({ GetProgressionSkillMorphSlotChainedAbilityIds(progression, morph) }) do
                                A.Refresh(id)
                            end
                        end
                    end
                end
            end
        end
    end
end

function A.Initialize()
    for _, event in ipairs({ EVENT_PLAYER_ACTIVATED, EVENT_SKILLS_FULL_UPDATE,
        EVENT_SKILL_LINE_ADDED, EVENT_END_CRAFTING_STATION_INTERACT }) do
        EVENT_MANAGER:RegisterForEvent(O.name .. "AbilityTimings", event, A.Rebuild)
    end
end
