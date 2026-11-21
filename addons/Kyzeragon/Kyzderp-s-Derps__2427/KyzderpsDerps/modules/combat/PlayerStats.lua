local KD = KyzderpsDerps
KD.Combat.PlayerStats = {}
local KDS = KD.Combat.PlayerStats

--[[
* EVENT_ABILITY_PROGRESSION_RANK_UPDATE (*luaindex* _progressionIndex_, *integer* _rank_, *integer* _maxRank_, *integer* _morph_)
GetProgressionSkillProgressionIndex(*[SkillType|#SkillType]* _skillType_, *luaindex* _skillLineIndex_, *luaindex* _skillIndex_)
** _Returns:_ *luaindex:nilable* _progressionIndex_
* GetSkillLineProgressionAbilityRank(*[SkillType|#SkillType]* _skillType_, *luaindex* _skillLineIndex_, *luaindex* _skillIndex_, *integer* _morphChoice_)
** _Returns:_ *integer* _rank_
]]
local cachedRank
local function GetOnslaughtRank()
    if (cachedRank) then return cachedRank end

    for skillLineIndex = 1, GetNumSkillLines(SKILL_TYPE_WEAPON) do
        local skillLineId = GetSkillLineId(SKILL_TYPE_WEAPON, skillLineIndex)
        local _, _, isActive = GetSkillLineDynamicInfo(SKILL_TYPE_WEAPON, skillLineIndex)
        -- d(zo_strformat("<<1>> id: <<2>> index: <<3>>", GetSkillLineNameById(skillLineId), skillLineId, skillLineIndex))

        -- Two Handed
        if (isActive and skillLineId == 30) then
            for skillIndex = 1, GetNumSkillAbilities(SKILL_TYPE_WEAPON, skillLineIndex) do
                local progressionId = GetProgressionSkillProgressionId(SKILL_TYPE_WEAPON, skillLineIndex, skillIndex)
                -- Berserker Strike
                if (progressionId == 417) then
                    local progressionIndex = GetProgressionSkillProgressionIndex(SKILL_TYPE_WEAPON, skillLineIndex, skillIndex)

                    local name, morph, rank = GetAbilityProgressionInfo(progressionIndex)
                    -- d(zo_strformat("<<1>> id: <<2>> index: <<3>> morph: <<4>> rank: <<5>>", name, progressionId, progressionIndex, morph, rank))
                    if (morph == MORPH_SLOT_MORPH_1) then
                        KD:dbg("caching onslaught rank " .. rank)
                        cachedRank = rank
                        return rank
                    else
                        return -- If wrong morph, ignore, but this shouldn't be possible because we only call this on Onslaught
                    end
                end
            end
        end
    end
end
KDS.GetOnslaughtRank = GetOnslaughtRank
-- /script KyzderpsDerps.Combat.PlayerStats.GetOnslaughtRank()

local lastOnslaught = 0
local prevPen = 0
local function OnStatsUpdated()
    local pen = GetPlayerStat(STAT_PHYSICAL_PENETRATION, STAT_BONUS_OPTION_APPLY_BONUS)
    if (pen ~= prevPen) then
        -- Only print if onslaught hit recently
        if (GetGameTimeMilliseconds() - lastOnslaught < 10000) then
            local change = pen - prevPen
            local arrow
            if (pen > prevPen) then
                arrow = "|c00FF00↑ +"
            else
                arrow = "|cFF0000↓ "
            end

            KD:msg(string.format("Pen: %d → %d %s%d", prevPen, pen, arrow, change))
        end

        prevPen = pen
    end
end
-- GetPlayerStat(STAT_PHYSICAL_PENETRATION, STAT_BONUS_OPTION_APPLY_BONUS)

local function OnOnslaught(_, _, _, _, _, _, _, _, targetName, _, hitValue, _, _, _, _, targetUnitId)
    if (GetOnslaughtRank() == 4) then
        KD:msg(string.format("|t100%%:100%%:esoui/art/icons/ability_2handed_006_a.dds|t %s (%d) for %d ", targetName, targetUnitId, hitValue))
        lastOnslaught = GetGameTimeMilliseconds()
    end
end

function KDS.Initialize()
    EVENT_MANAGER:UnregisterForEvent(KD.name .. "CombatStatsPowerUpdate", EVENT_STATS_UPDATED)
    EVENT_MANAGER:UnregisterForEvent(KD.name .. "CombatStatsOnslaught", EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForEvent(KD.name .. "CombatStatsOnslaughtRank", EVENT_ABILITY_PROGRESSION_RANK_UPDATE)

    if (not KD.savedOptions.combat.printOnslaught) then return end

    EVENT_MANAGER:RegisterForEvent(KD.name .. "CombatStatsPowerUpdate", EVENT_STATS_UPDATED, OnStatsUpdated)
    EVENT_MANAGER:AddFilterForEvent(KD.name .. "CombatStatsPowerUpdate", EVENT_STATS_UPDATED, REGISTER_FILTER_UNIT_TAG, "player")
    OnStatsUpdated()

    EVENT_MANAGER:RegisterForEvent(KD.name .. "CombatStatsOnslaught", EVENT_COMBAT_EVENT, OnOnslaught)
    EVENT_MANAGER:AddFilterForEvent(KD.name .. "CombatStatsOnslaught", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 83229)
    EVENT_MANAGER:AddFilterForEvent(KD.name .. "CombatStatsOnslaught", EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    EVENT_MANAGER:AddFilterForEvent(KD.name .. "CombatStatsOnslaught", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_CRITICAL_DAMAGE)

    EVENT_MANAGER:RegisterForEvent(KD.name .. "CombatStatsOnslaughtRank", EVENT_ABILITY_PROGRESSION_RANK_UPDATE, function(_, progressionIndex)
        cachedRank = nil -- just dirty it
    end)
end
