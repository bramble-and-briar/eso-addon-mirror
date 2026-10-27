--[[
Original Author: Ayantir
Reworked by Armodeniz
Updated by Lykeion
Filename: LibSkillFactory.lua
Version: 26
]]--

--sigo@v4.2.1 new global library variable
--Lykeion@v6.0.0 updated for Gold Road
LibSkillsFactory = {}

local ABILITY_TYPE_ULTIMATE = 0
local ABILITY_TYPE_ACTIVE = 1
local ABILITY_TYPE_PASSIVE = 2
local ABILITY_TYPE_CRAFTED= 3

-- Class is ClassID : 1 (Dragon Knight), 2 (Sorcerer), 3 (Nightblade), 4 (Warden), 5 (Necromancer), 6 (Templar), 117 (Arcanist) -- GetUnitClassId()
-- Races MUST be : 1 Breton, 2 Redguard, 3 Orc, 4 Dunmer, 5 Nord, 6 Argonian, 7 Altmer, 8 Bosmer, 9 Khajiit, 10 Imperial -- GetUnitRaceId()

-- Init the factory ~like this :
-- LibSkillsFactory:Initialize(GetUnitClassId("player"), GetUnitRaceId("player"))

--[[

NOTE FOR TRADESKILLS :

Depending on language used at launch (not reloadui), Skilllines are not sames.
For LibSkillsFactory :  1 = Alchemy, 2 = Clothing, 3 = Provisioning, 4 = Enchanting, 5 = Blacksmithing, 6 = Jewelry Crafting, 7 = Woodworking
English :  1 = Alchemy, 2 = Blacksmithing, 3 = Clothing, 4 = Enchanting, 5 = Jewelry Crafting, 6 = Provisioning, 7 = Woodworking
German :  1 = Alchemy, 2 = Blacksmithing, 3 = Jewelry Crafting, 4 = Clothing, 5 = Woodworking, 6 = Provisioning, 7 = Enchanting
Russian:  1 = Alchemy, 2 = Enchanting, 3 = Blacksmithing, 4 = Clothing, 5 = Provisioning, 6 = Woodworking, 7 = jewelry
If 1/6 are always same, 2/3/4/5 API is divergent depending language used AT LAUNCH

]]--

local function GetCraftingMode()
    --sigo@v4.1.4 : fix to address the in-game SKILLS_DATA_MANAGER issue from patch on 3/11/2019
    --local _, blackSmithing = GetCraftingSkillLineIndices(CRAFTING_TYPE_BLACKSMITHING)
    local blackSmithing = SKILLS_DATA_MANAGER:GetCraftingSkillLineData(CRAFTING_TYPE_BLACKSMITHING)
    if blackSmithing and blackSmithing.skillLineIndex == 5 then -- FR, DE
        return 2
    else
        return 1 -- value is 2 in EN
    end

end
local ESOLSFClassSkillLineIndexMappingTable = {}
local LSFESOClassSkillLineIndexMappingTable = {}
local classPool = {
    [1] = { 1, 2, 3},
    [2] = { 4, 5, 6},
    [3] = { 7, 8, 9},
    [4] = { 13, 14, 15},
    [5] = { 16, 17, 18},
    [6] = { 10, 11, 12},
    [117] = { 19, 20, 21},
}

-- Lykeion: reverse id index table
function LibSkillsFactory:GetClassIdFromLSFSkillLineId(skillLineId)
    local idTable = {
        [ 1 ] = 1 ,-- Dragon 1
        [ 2 ] = 1 ,-- Dragon 2
        [ 3 ] = 1 ,-- Dragon 3
        [ 4 ] = 2 ,-- Sorc 1
        [ 5 ] = 2 ,-- Sorc 2
        [ 6 ] = 2,-- Sorc 3
        [ 7 ] = 3 ,-- Blade 1
        [ 8 ] = 3 ,-- Blade 2
        [ 9 ] = 3 ,-- Blade 3
        [ 10 ] = 6 ,-- Templar 1
        [ 11 ] = 6 ,-- Templar 2
        [ 12 ] = 6 ,-- Templar 3
        [ 13 ] = 4 ,-- Warden 1
        [ 14 ] = 4,-- Warden 2
        [ 15 ] = 4 ,-- Warden 3
        [ 16 ] = 5 ,-- Necro 1
        [ 17 ] = 5 ,-- Necro 2
        [ 18 ] = 5 ,-- Necro 3
        [ 19 ] = 117 ,-- Arc 1
        [ 20 ] = 117 ,-- Arc 2
        [ 21 ] = 117 ,-- Arc 3
    }
    return idTable[skillLineId]
end


-- Class Mastery: classId → staticSkillFactory[SKILL_TYPE_CLASS] index
local CLASS_MASTERY_LSF_INDEX = {
    [1] = 43,   -- Dragonknight
    [2] = 49,   -- Sorcerer
    [3] = 48,   -- Nightblade
    [4] = 46,   -- Warden
    [5] = 45,   -- Necromancer
    [6] = 47,   -- Templar
    [117] = 44, -- Arcanist
}

function LibSkillsFactory:GetClassMasterySkillLineId(classId)
    local idx = CLASS_MASTERY_LSF_INDEX[classId]
    if not idx then return nil end
    return LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][idx].skillLineId
end

function LibSkillsFactory:GetClassMasterySkillId(classId, passiveIndex)
    local idx = CLASS_MASTERY_LSF_INDEX[classId]
    if not idx then return nil end
    local entry = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][idx]
    if entry and entry[passiveIndex] and entry[passiveIndex].skillPool then
        return entry[passiveIndex].skillPool[1].id
    end
    return nil
end

function LibSkillsFactory:GetNumClassMasteryPassives(classId)
    local idx = CLASS_MASTERY_LSF_INDEX[classId]
    if not idx then return 0 end
    return #LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][idx]
end

function LibSkillsFactory:Initialize(classId, raceId)
    if not classId then classId = GetUnitClassId("player") end
    if not raceId then raceId = GetUnitRaceId("player") end
    LibSkillsFactory:InitESOLSFClassSkillLineIndexMappingTable()

    LibSkillsFactory.skillFactory = {
        [SKILL_TYPE_CLASS] = {
            [1] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[1]],
            [2] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[2]],
            [3] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[3]],
            [4] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[4]],
            [5] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[5]],
            [6] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[6]],
            [7] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[7]],
            [8] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[8]],
            [9] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[9]],
            [10] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[10]],
            [11] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[11]],
            [12] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[12]],
            [13] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[13]],
            [14] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[14]],
            [15] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[15]],
            [16] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[16]],
            [17] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[17]],
            [18] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[18]],
            [19] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[19]],
            [20] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[20]],
            [21] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][ESOLSFClassSkillLineIndexMappingTable[21]],
        },
        [SKILL_TYPE_AVA] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_AVA],
        [SKILL_TYPE_WEAPON] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WEAPON],
        [SKILL_TYPE_ARMOR] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_ARMOR],
        [SKILL_TYPE_RACIAL] = {LibSkillsFactory.staticSkillFactory[SKILL_TYPE_RACIAL][raceId]},
    }

    -- sigo@v4.3.1 - updating skill line order for greymoor
    --if GetCraftingMode() == 2 then
    if GetCVar("Language.2") == "fr" then
        LibSkillsFactory.skillFactory[SKILL_TYPE_WORLD] = {
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][2], -- legerdeman
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][1], -- excavation
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][6], -- werewolf
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][4], -- soul magic
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][3], -- scrying
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][5], -- vampire
        }
        LibSkillsFactory.skillFactory[SKILL_TYPE_GUILD] = {
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][1],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][2],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][3],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][5],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][6],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][4],
        }
        LibSkillsFactory.skillFactory[SKILL_TYPE_TRADESKILL] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL]
    elseif GetCVar("Language.2") == "de" then
        LibSkillsFactory.skillFactory[SKILL_TYPE_WORLD] = {
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][1], -- excavation
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][2], -- legerdeman
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][4], -- soul magic
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][3], -- scrying
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][5], -- vampire
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][6], -- werewolf
        }
        LibSkillsFactory.skillFactory[SKILL_TYPE_GUILD] = {
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][5],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][1],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][2],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][3],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][4],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][6],
        }
        LibSkillsFactory.skillFactory[SKILL_TYPE_AVA] = {
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_AVA][2],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_AVA][1],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_AVA][3],
        }
        LibSkillsFactory.skillFactory[SKILL_TYPE_TRADESKILL] = {
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][1],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][5],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][6],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][2],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][7],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][3],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][4],
        }
    elseif GetCVar("Language.2") == "ru" then
        LibSkillsFactory.skillFactory[SKILL_TYPE_WORLD] = {
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][5], -- vampire
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][6], -- werewolf
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][2], -- legerdeman
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][3], -- scrying
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][4], -- soul magic
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][1], -- excavation
        }
        LibSkillsFactory.skillFactory[SKILL_TYPE_GUILD] = {
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][2],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][5],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][3],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][6],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][4],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][1],
        }
        LibSkillsFactory.skillFactory[SKILL_TYPE_AVA] = {
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_AVA][2],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_AVA][3],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_AVA][1],
        }
        LibSkillsFactory.skillFactory[SKILL_TYPE_TRADESKILL] = {
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][1],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][4],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][5],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][2],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][3],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][7],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][6],
        }
    elseif GetCVar("Language.2") == "zh" or GetCVar("Language.2") == "ze" then
        LibSkillsFactory.skillFactory[SKILL_TYPE_WORLD] = {
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][6], -- werewolf
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][4], -- soul magic
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][2], -- legerdeman
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][3], -- scrying
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][1], -- excavation
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD][5], -- vampire
        }
        LibSkillsFactory.skillFactory[SKILL_TYPE_GUILD] = {
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][5],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][2],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][3],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][1],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][4],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD][6],

        }
        LibSkillsFactory.skillFactory[SKILL_TYPE_AVA] = {
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_AVA][2],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_AVA][1],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_AVA][3],
        }
        LibSkillsFactory.skillFactory[SKILL_TYPE_TRADESKILL] = {
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][5],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][4],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][1],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][7],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][3],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][2],
            LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][6],
        }
   else
        LibSkillsFactory.skillFactory[SKILL_TYPE_WORLD] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_WORLD]
        LibSkillsFactory.skillFactory[SKILL_TYPE_GUILD] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_GUILD]
        if GetCraftingMode() == 1 then
            LibSkillsFactory.skillFactory[SKILL_TYPE_TRADESKILL] = {
                LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][1],
                LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][5],
                LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][2],
                LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][4],
                LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][6],
                LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][3],
                LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL][7],
            }
        else
            LibSkillsFactory.skillFactory[SKILL_TYPE_TRADESKILL] = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_TRADESKILL]
        end
    end

end

function LibSkillsFactory:GetAbilityType(skillType, skillLineIndex, abilityIndex)

    local abilityType, maxRank
    if LibSkillsFactory.skillFactory[skillType][skillLineIndex][abilityIndex] then
        abilityType = LibSkillsFactory.skillFactory[skillType][skillLineIndex][abilityIndex].at
        if abilityType == ABILITY_TYPE_PASSIVE then
            maxRank = LibSkillsFactory.skillFactory[skillType][skillLineIndex][abilityIndex].mx
        end
    else
        d("==")
        d(skillType)
        d(LibSkillsFactory.skillFactory[skillType][skillLineIndex])
        d("--")
        return nil
    end

    return abilityType, maxRank

end
-- Armodeniz: reverse id index table
function LibSkillsFactory:GetSkillLineLSFIndexFromSkillLineId(skillLineId)
    local idTable = {
        [ 35 ] = 1 ,-- Dragon 1
        [ 36 ] = 2 ,-- Dragon 2
        [ 37 ] = 3 ,-- Dragon 3
        [ 41 ] = 4 ,-- Sorc 1
        [ 42 ] = 5 ,-- Sorc 2
        [ 43 ] = 6 ,-- Sorc 3
        [ 38 ] = 7 ,-- Blade 1
        [ 39 ] = 8 ,-- Blade 2
        [ 40 ] = 9 ,-- Blade 3
        [ 22 ] = 10 ,-- Templar 1
        [ 27 ] = 11 ,-- Templar 2
        [ 28 ] = 12 ,-- Templar 3
        [ 127 ] = 13 ,-- Warden 1
        [ 128 ] = 14 ,-- Warden 2
        [ 129 ] = 15 ,-- Warden 3
        [ 131 ] = 16 ,-- Necro 1
        [ 132 ] = 17 ,-- Necro 2
        [ 133 ] = 18 ,-- Necro 3
        [ 218 ] = 19 ,-- Arc 1
        [ 219 ] = 20 ,-- Arc 2
        [ 220 ] = 21 ,-- Arc 3
        [ 30 ] = 1 ,
        [ 29 ] = 2 ,
        [ 31 ] = 3 ,
        [ 32 ] = 4 ,
        [ 33 ] = 5 ,
        [ 34 ] = 6 ,
        [ 24 ] = 1 ,
        [ 25 ] = 2 ,
        [ 26 ] = 3 ,
        [ 157 ] = 1 ,
        [ 111 ] = 2 ,
        [ 155 ] = 3 ,
        [ 72 ] = 4 ,
        [ 51 ] = 5 ,
        [ 50 ] = 6 ,
        [ 118 ] = 1 ,
        [ 45 ] = 2 ,
        [ 44 ] = 3 ,
        [ 130 ] = 4 ,
        [ 117 ] = 5 ,
        [ 55 ] = 6 ,
        [ 48 ] = 1 ,
        [ 71 ] = 2 ,
        [ 67 ] = 3 ,
        [ 60 ] = 1 ,-- Breton
        [ 62 ] = 2 ,-- Redguard
        [ 52 ] = 3 ,-- Orc
        [ 64 ] = 4 ,-- Dunmer
        [ 65 ] = 5 ,-- Nord
        [ 63 ] = 6 ,-- Argonian
        [ 56 ] = 7 ,-- Altmer
        [ 57 ] = 8 ,-- Bosmer
        [ 58 ] = 9 ,-- Khajiit
        [ 59 ] = 10 ,-- Imperial
        [ 77 ] = 1 ,
        [ 81 ] = 2 ,
        [ 76 ] = 3 ,
        [ 78 ] = 4 ,
        [ 79 ] = 5 ,
        [ 141 ] = 6 ,
        [ 80 ] = 7 ,
    }

    return idTable[skillLineId]
end

function LibSkillsFactory:GetSkillLineIdFromLSFIndex(skillType, skillLineIndex)
    return LibSkillsFactory.staticSkillFactory[skillType][skillLineIndex].skillLineId
end

function LibSkillsFactory:GetSkillLineIdFromClass(classId, skillLineIndex)
    return LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][classPool[classId][skillLineIndex]].skillLineId
end

function LibSkillsFactory:GetSkillLineIdFromRace(raceId)
    return LibSkillsFactory.staticSkillFactory[SKILL_TYPE_RACIAL][raceId].skillLineId
end

function LibSkillsFactory:IsSkillAbilityAutoGrant(skillType, skillLineIndex, abilityIndex)

    if LibSkillsFactory.skillFactory[skillType][skillLineIndex][abilityIndex].autoGrant then
        return 1
    else
        return 0
    end
end

function LibSkillsFactory:SkillAbilityAutoGrantInfo(skillType, skillLineIndex, abilityIndex)

    if LibSkillsFactory.skillFactory[skillType][skillLineIndex][abilityIndex].autoGrant then
        return LibSkillsFactory.skillFactory[skillType][skillLineIndex][abilityIndex].autoGrant
    else
        return 0
    end
end

function LibSkillsFactory:GetSkillLineName(skillType, skillLineIndex)
    return GetSkillLineNameById(LibSkillsFactory.skillFactory[skillType][skillLineIndex].skillLineId)
end

function LibSkillsFactory:InitESOLSFClassSkillLineIndexMappingTable()
    ESOLSFClassSkillLineIndexMappingTable = {}
    for lsfIndex = 1, LibSkillsFactory:GetNumSkillLinesPerChar(SKILL_TYPE_CLASS) do
        local skillLineId = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][lsfIndex].skillLineId
        local _, esoIndex = GetSkillLineIndicesFromSkillLineId(skillLineId)
        ESOLSFClassSkillLineIndexMappingTable[esoIndex] = lsfIndex
    end
end

function LibSkillsFactory:GetESOLSFClassSkillLineIndexMappingTable()
    LibSkillsFactory:InitESOLSFClassSkillLineIndexMappingTable()
    return ESOLSFClassSkillLineIndexMappingTable
end

function LibSkillsFactory:InitLSFESOClassSkillLineIndexMappingTable()
    LSFESOClassSkillLineIndexMappingTable = {}
    for lsfIndex = 1, LibSkillsFactory:GetNumSkillLinesPerChar(SKILL_TYPE_CLASS) do
        local skillLineId = LibSkillsFactory.staticSkillFactory[SKILL_TYPE_CLASS][lsfIndex].skillLineId
        local _, esoIndex = GetSkillLineIndicesFromSkillLineId(skillLineId)
        LSFESOClassSkillLineIndexMappingTable[lsfIndex] = esoIndex
    end
end

function LibSkillsFactory:GetLSFESOClassSkillLineIndexMappingTable()
    LibSkillsFactory:InitLSFESOClassSkillLineIndexMappingTable()
    return LSFESOClassSkillLineIndexMappingTable
end

function LibSkillsFactory:GetAbilityId(skillType, skillLineIndex, abilityIndex, abilityLevel)

    local abilityType, skillPool
    -- should test against nil
    if LibSkillsFactory.skillFactory[skillType][skillLineIndex][abilityIndex] then

        skillPool = LibSkillsFactory.skillFactory[skillType][skillLineIndex][abilityIndex].skillPool

        if skillPool[abilityLevel].id then
            return skillPool[abilityLevel].id
        else
            return 0
        end
    else
        return 0
    end

end

function LibSkillsFactory:GetNumSkillLines(skillType)

    local numSkillLines =
    {
        [SKILL_TYPE_CLASS] = GetNumSkillLines(skillType),
        [SKILL_TYPE_WEAPON] = GetNumSkillLines(skillType),
        [SKILL_TYPE_ARMOR] = GetNumSkillLines(skillType),
        [SKILL_TYPE_WORLD] = 6,
        [SKILL_TYPE_GUILD] = 6,
        [SKILL_TYPE_AVA] = 3,
        [SKILL_TYPE_RACIAL] = GetNumSkillLines(skillType),
        [SKILL_TYPE_TRADESKILL] = GetNumSkillLines(skillType),
    }

    return numSkillLines[skillType]

end

--sigo:@v4.1.3
function LibSkillsFactory:GetNumSkillLinesPerChar(skillType)
    local numSkillLines =
    {
        -- [SKILL_TYPE_CLASS] = 3, --GetNumSkillLines(skillType),
        [SKILL_TYPE_CLASS] = 21, --GetNumSkillLines(skillType),
        -- [SKILL_TYPE_WEAPON] = GetNumSkillLines(skillType),
        [SKILL_TYPE_WEAPON] = 6,
        [SKILL_TYPE_ARMOR] = GetNumSkillLines(skillType),
        [SKILL_TYPE_WORLD] = 6,
        [SKILL_TYPE_GUILD] = 6,
        [SKILL_TYPE_AVA] = 3,
        [SKILL_TYPE_RACIAL] = 1, --GetNumSkillLines(skillType),
        [SKILL_TYPE_TRADESKILL] = GetNumSkillLines(skillType),
    }
    return numSkillLines[skillType]
end

function LibSkillsFactory:GetNumSkillAbilitiesFromLSFIndex(skillType, skillLineIndex)

    if LibSkillsFactory.staticSkillFactory[skillType] and LibSkillsFactory.staticSkillFactory[skillType][skillLineIndex] then
        return #LibSkillsFactory.staticSkillFactory[skillType][skillLineIndex]
    end
    return 0

end

function LibSkillsFactory:GetNumSkillAbilities(skillType, skillLineIndex)
    if LibSkillsFactory.skillFactory[skillType] and LibSkillsFactory.skillFactory[skillType][skillLineIndex] then
        return #LibSkillsFactory.skillFactory[skillType][skillLineIndex]
    end
    return 0
end

LibSkillsFactory.staticSkillFactory = {
    [SKILL_TYPE_CLASS] = {
        [1] = { 
            -- Flame
            ["skillLineId"] = 35,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 28988,},
                [1] = {["id"] = 32958,},
                [2] = {["id"] = 32947,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 23806,},
                [1] = {["id"] = 20805,},
                [2] = {["id"] = 20816,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 20657,},
                [1] = {["id"] = 20668,},
                [2] = {["id"] = 20660,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 31837,},
                [1] = {["id"] = 32792,},
                [2] = {["id"] = 32785,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 29059,},
                [1] = {["id"] = 20779,},
                [2] = {["id"] = 32710,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 28967,},
                [1] = {["id"] = 32853,},
                [2] = {["id"] = 32881,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29424,},[2] = {["id"] = 45011,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29430,},[2] = {["id"] = 45012,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29439,},[2] = {["id"] = 45023,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29451,},[2] = {["id"] = 45029,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [2] = { 
            -- Draconic
            ["skillLineId"] = 36,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 29012,},
                [1] = {["id"] = 32719,},
                [2] = {["id"] = 32715,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 20917,},
                [1] = {["id"] = 20944,},
                [2] = {["id"] = 20930,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 20245,},
                [1] = {["id"] = 20252,},
                [2] = {["id"] = 20251,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 29004,},
                [1] = {["id"] = 32744,},
                [2] = {["id"] = 32722,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 21007,},
                [1] = {["id"] = 21014,},
                [2] = {["id"] = 21017,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 20492,},
                [1] = {["id"] = 20499,},
                [2] = {["id"] = 20496,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29455,},[2] = {["id"] = 44922,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29457,},[2] = {["id"] = 44933,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29460,},[2] = {["id"] = 44951,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29462,},[2] = {["id"] = 44953,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [3] = { 
            -- Earth
            ["skillLineId"] = 37,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 15957,},
                [1] = {["id"] = 17874,},
                [2] = {["id"] = 17878,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 29032,},
                [1] = {["id"] = 31820,},
                [2] = {["id"] = 31816,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 29043,},
                [1] = {["id"] = 31874,},
                [2] = {["id"] = 31888,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 29071,},
                [1] = {["id"] = 29224,},
                [2] = {["id"] = 32673,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 29037,},
                [1] = {["id"] = 32685,},
                [2] = {["id"] = 32678,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 20319,},
                [1] = {["id"] = 20328,},
                [2] = {["id"] = 20323,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29468,},[2] = {["id"] = 44996,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29463,},[2] = {["id"] = 44984,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29473,},[2] = {["id"] = 45001,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29475,},[2] = {["id"] = 45009,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [4] = { 
            -- Dark
            ["skillLineId"] = 41,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 27706,},
                [1] = {["id"] = 28341,},
                [2] = {["id"] = 28348,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 43714,},
                [1] = {["id"] = 46331,},
                [2] = {["id"] = 46324,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 28025,},
                [1] = {["id"] = 28308,},
                [2] = {["id"] = 28311,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 24371,},
                [1] = {["id"] = 24578,},
                [2] = {["id"] = 24574,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 24584,},
                [1] = {["id"] = 24595,},
                [2] = {["id"] = 24589,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 24828,},
                [1] = {["id"] = 24842,},
                [2] = {["id"] = 24834,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31386,},[2] = {["id"] = 45176,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31383,},[2] = {["id"] = 45172,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31378,},[2] = {["id"] = 45165,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31389,},[2] = {["id"] = 45181,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [5] = { 
            -- Daedric
            ["skillLineId"] = 42,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 23634,},
                [1] = {["id"] = 23492,},
                [2] = {["id"] = 23495,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 23304,},
                [1] = {["id"] = 23319,},
                [2] = {["id"] = 23316,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 24326,},
                [1] = {["id"] = 24328,},
                [2] = {["id"] = 24330,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 24613,},
                [1] = {["id"] = 24636,},
                [2] = {["id"] = 24639,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 28418,},
                [1] = {["id"] = 29489,},
                [2] = {["id"] = 29482,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 24158,},
                [1] = {["id"] = 24165,},
                [2] = {["id"] = 24163,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31398,},[2] = {["id"] = 45198,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31396,},[2] = {["id"] = 45196,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31417,},[2] = {["id"] = 45200,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31412,},[2] = {["id"] = 45199,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [6] = { 
            -- Storm
            ["skillLineId"] = 43,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 24785,},
                [1] = {["id"] = 24806,},
                [2] = {["id"] = 24804,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 18718,},
                [1] = {["id"] = 19123,},
                [2] = {["id"] = 19109,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 23210,},
                [1] = {["id"] = 23231,},
                [2] = {["id"] = 23213,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 23182,},
                [1] = {["id"] = 23200,},
                [2] = {["id"] = 23205,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 23670,},
                [1] = {["id"] = 23674,},
                [2] = {["id"] = 23678,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 23234,},
                [1] = {["id"] = 23236,},
                [2] = {["id"] = 23277,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31419,},[2] = {["id"] = 45188,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31421,},[2] = {["id"] = 45190,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31422,},[2] = {["id"] = 45192,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31425,},[2] = {["id"] = 45195,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [7] = { 
            -- Assassination
            ["skillLineId"] = 38,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 33398,},
                [1] = {["id"] = 36508,},
                [2] = {["id"] = 36514,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 25255,},
                [1] = {["id"] = 25260,},
                [2] = {["id"] = 25267,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 18342,},
                [1] = {["id"] = 25493,},
                [2] = {["id"] = 25484,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 33386,},
                [1] = {["id"] = 34843,},
                [2] = {["id"] = 34851,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 33357,},
                [1] = {["id"] = 36968,},
                [2] = {["id"] = 36967,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 61902,},
                [1] = {["id"] = 61927,},
                [2] = {["id"] = 61919,},
            },["at"] = ABILITY_TYPE_ACTIVE,},[7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 36616,},[2] = {["id"] = 45038,},},
            ["at"] = ABILITY_TYPE_PASSIVE,},[8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 36630,},[2] = {["id"] = 45048,},},
            ["at"] = ABILITY_TYPE_PASSIVE,},[9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 36636,},[2] = {["id"] = 45053,},},
            ["at"] = ABILITY_TYPE_PASSIVE,},[10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 36641,},[2] = {["id"] = 45060,},},
            ["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [8] = { 
            -- Shadow
            ["skillLineId"] = 39,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 25411,},
                [1] = {["id"] = 36493,},
                [2] = {["id"] = 36485,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 33375,},
                [1] = {["id"] = 35414,},
                [2] = {["id"] = 35419,},
            },["at"] = ABILITY_TYPE_ACTIVE,},

            [3] = {["skillPool"] = {
                [0] = {["id"] = 25375,},
                [1] = {["id"] = 25380,},
                [2] = {["id"] = 25377,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 33195,},
                [1] = {["id"] = 36049,},
                [2] = {["id"] = 36028,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 25352,},
                [1] = {["id"] = 37470,},
                [2] = {["id"] = 37475,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 33211,},
                [1] = {["id"] = 35434,},
                [2] = {["id"] = 35441,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 36549,},[2] = {["id"] = 45103,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 18866,},[2] = {["id"] = 45071,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 36532,},[2] = {["id"] = 45084,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 36552,},[2] = {["id"] = 45115,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [9] = { 
            -- Siphon
            ["skillLineId"] = 40,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 25091,},
                [1] = {["id"] = 35508,},
                [2] = {["id"] = 35460,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 33291,},
                [1] = {["id"] = 34838,},
                [2] = {["id"] = 34835,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 33308,},
                [1] = {["id"] = 34721,},
                [2] = {["id"] = 34727,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 33326,},
                [1] = {["id"] = 36943,},
                [2] = {["id"] = 36957,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 33319,},
                [1] = {["id"] = 36908,},
                [2] = {["id"] = 36935,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 33316,},
                [1] = {["id"] = 36901,},
                [2] = {["id"] = 36891,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 36560,},[2] = {["id"] = 45135,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 36595,},[2] = {["id"] = 45150,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 36603,},[2] = {["id"] = 45155,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 36587,},[2] = {["id"] = 45145,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [10] = { 
            -- Spear
            ["skillLineId"] = 22,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 22138,},
                [1] = {["id"] = 22144,},
                [2] = {["id"] = 22139,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 26114,},
                [1] = {["id"] = 26792,},
                [2] = {["id"] = 26797,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 26158,},
                [1] = {["id"] = 26800,},
                [2] = {["id"] = 26804,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 22149,},
                [1] = {["id"] = 22161,},
                [2] = {["id"] = 15540,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 26188,},
                [1] = {["id"] = 26858,},
                [2] = {["id"] = 26869,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 22178,},
                [1] = {["id"] = 22182,},
                [2] = {["id"] = 22180,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31698,},[2] = {["id"] = 44046,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31708,},[2] = {["id"] = 44721,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31718,},[2] = {["id"] = 44730,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31565,},[2] = {["id"] = 44732,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [11] = { 
            -- Dawn
            ["skillLineId"] = 27,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 21752,},
                [1] = {["id"] = 21755,},
                [2] = {["id"] = 21758,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 21726,},
                [1] = {["id"] = 21729,},
                [2] = {["id"] = 21732,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 22057,},
                [1] = {["id"] = 22110,},
                [2] = {["id"] = 22095,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 21761,},
                [1] = {["id"] = 21765,},
                [2] = {["id"] = 21763,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 21776,},
                [1] = {["id"] = 22006,},
                [2] = {["id"] = 22004,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 63029,},
                [1] = {["id"] = 63044,},
                [2] = {["id"] = 63046,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31739,},[2] = {["id"] = 45214,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31744,},[2] = {["id"] = 45216,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31743,},[2] = {["id"] = 45215,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31721,},[2] = {["id"] = 45212,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [12] = { 
            -- Restoring
            ["skillLineId"] = 28,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 22223,},
                [1] = {["id"] = 22229,},
                [2] = {["id"] = 22226,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 22250,},
                [1] = {["id"] = 22253,},
                [2] = {["id"] = 22256,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 22304,},
                [1] = {["id"] = 22327,},
                [2] = {["id"] = 22314,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 26209,},
                [1] = {["id"] = 26807,},
                [2] = {["id"] = 26821,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 22265,},
                [1] = {["id"] = 22259,},
                [2] = {["id"] = 22262,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 22234,},
                [1] = {["id"] = 22240,},
                [2] = {["id"] = 22237,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31751,},[2] = {["id"] = 45206,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31757,},[2] = {["id"] = 45207,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31760,},[2] = {["id"] = 45208,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 31747,},[2] = {["id"] = 45202,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [13] = { 
            -- Animal
            ["skillLineId"] = 127,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 85982,},
                [1] = {["id"] = 85986,},
                [2] = {["id"] = 85990,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 85995,},
                [1] = {["id"] = 85999,},
                [2] = {["id"] = 86003,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 86009,},
                [1] = {["id"] = 86019,},
                [2] = {["id"] = 86015,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 86023,},
                [1] = {["id"] = 86027,},
                [2] = {["id"] = 86031,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 86050,},
                [1] = {["id"] = 86054,},
                [2] = {["id"] = 86058,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 86037,},
                [1] = {["id"] = 86041,},
                [2] = {["id"] = 86045,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 86064},[2] = {["id"] = 86065}},["at"] = ABILITY_TYPE_PASSIVE},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 86062},[2] = {["id"] = 86063}},["at"] = ABILITY_TYPE_PASSIVE},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 86066},[2] = {["id"] = 86067}},["at"] = ABILITY_TYPE_PASSIVE},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 86068},[2] = {["id"] = 86069}},["at"] = ABILITY_TYPE_PASSIVE}
        },
        [14] = { 
            -- Green
            ["skillLineId"] = 128,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 85532,},
                [1] = {["id"] = 85804,},
                [2] = {["id"] = 85807,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 85536,},
                [1] = {["id"] = 85862,},
                [2] = {["id"] = 85863,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 85578,},
                [1] = {["id"] = 85840,},
                [2] = {["id"] = 85845,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 85552,},
                [1] = {["id"] = 85850,},
                [2] = {["id"] = 85851,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 85539,},
                [1] = {["id"] = 85854,},
                [2] = {["id"] = 85855,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 85564,},
                [1] = {["id"] = 85859,},
                [2] = {["id"] = 85858,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 85882},[2] = {["id"] = 85883}},["at"] = ABILITY_TYPE_PASSIVE},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 85878},[2] = {["id"] = 85879}},["at"] = ABILITY_TYPE_PASSIVE},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 85876},[2] = {["id"] = 85877}},["at"] = ABILITY_TYPE_PASSIVE},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 85880},[2] = {["id"] = 85881}},["at"] = ABILITY_TYPE_PASSIVE}
        },
        [15] = { 
            -- Winter
            ["skillLineId"] = 129,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 86109,},
                [1] = {["id"] = 86113,},
                [2] = {["id"] = 86117,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 86122,},
                [1] = {["id"] = 86126,},
                [2] = {["id"] = 86130,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 86161,},
                [1] = {["id"] = 86165,},
                [2] = {["id"] = 86169,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 86148,},
                [1] = {["id"] = 86152,},
                [2] = {["id"] = 86156,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 86135,},
                [1] = {["id"] = 86139,},
                [2] = {["id"] = 86143,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 86175,},
                [1] = {["id"] = 86179,},
                [2] = {["id"] = 86183,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 86191},[2] = {["id"] = 86192}},["at"] = ABILITY_TYPE_PASSIVE},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 86189},[2] = {["id"] = 86190}},["at"] = ABILITY_TYPE_PASSIVE},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 86193},[2] = {["id"] = 86194}},["at"] = ABILITY_TYPE_PASSIVE},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 86195},[2] = {["id"] = 86196}},["at"] = ABILITY_TYPE_PASSIVE}
        },
        [16] = { 
            -- Grave
            ["skillLineId"] = 131,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 122174,},
                [1] = {["id"] = 122395,},
                [2] = {["id"] = 122388,},
            },["at"] = ABILITY_TYPE_ULTIMATE},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 114108,},
                [1] = {["id"] = 117624,},
                [2] = {["id"] = 117637,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 114860,},
                [1] = {["id"] = 117690,},
                [2] = {["id"] = 117749,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 115252,},
                [1] = {["id"] = 117805,},
                [2] = {["id"] = 117850,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 114317,},
                [1] = {["id"] = 118680,},
                [2] = {["id"] = 118726,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 115924,},
                [1] = {["id"] = 118763,},
                [2] = {["id"] = 118008,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 116186},[2] = {["id"] = 116188}},["at"] = ABILITY_TYPE_PASSIVE},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 116197},[2] = {["id"] = 116198}},["at"] = ABILITY_TYPE_PASSIVE},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 116192},[2] = {["id"] = 116194}},["at"] = ABILITY_TYPE_PASSIVE},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 116199},[2] = {["id"] = 116201}},["at"] = ABILITY_TYPE_PASSIVE},
        },
        [17] = { 
            -- Bone
            ["skillLineId"] = 132,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 115001,},
                [1] = {["id"] = 118664,},
                [2] = {["id"] = 118279,},
            },["at"] = ABILITY_TYPE_ULTIMATE},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 115115,},
                [1] = {["id"] = 118226,},
                [2] = {["id"] = 118223,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 115206,},
                [1] = {["id"] = 118237,},
                [2] = {["id"] = 118244,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 115238,},
                [1] = {["id"] = 118623,},
                [2] = {["id"] = 118639,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 115093,},
                [1] = {["id"] = 118380,},
                [2] = {["id"] = 118404,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 115177,},
                [1] = {["id"] = 118308,},
                [2] = {["id"] = 118352,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 116230},[2] = {["id"] = 116235}},["at"] = ABILITY_TYPE_PASSIVE},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 116239},[2] = {["id"] = 116240}},["at"] = ABILITY_TYPE_PASSIVE},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 116269},[2] = {["id"] = 116270}},["at"] = ABILITY_TYPE_PASSIVE},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 116271},[2] = {["id"] = 116272}},["at"] = ABILITY_TYPE_PASSIVE},
        },
        [18] = { 
            -- Death
            ["skillLineId"] = 133,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 115410,},
                [1] = {["id"] = 118367,},
                [2] = {["id"] = 118379,},
            },["at"] = ABILITY_TYPE_ULTIMATE},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 114196,},
                [1] = {["id"] = 117883,},
                [2] = {["id"] = 117888,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 115307,},
                [1] = {["id"] = 117940,},
                [2] = {["id"] = 117919,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 115315,},
                [1] = {["id"] = 118017,},
                [2] = {["id"] = 118809,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 115710,},
                [1] = {["id"] = 118912,},
                [2] = {["id"] = 118840,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 115926,},
                [1] = {["id"] = 118070,},
                [2] = {["id"] = 118122,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 116286},[2] = {["id"] = 116287}},["at"] = ABILITY_TYPE_PASSIVE},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 116273},[2] = {["id"] = 116275}},["at"] = ABILITY_TYPE_PASSIVE},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 116284},[2] = {["id"] = 116285}},["at"] = ABILITY_TYPE_PASSIVE},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 116282},[2] = {["id"] = 116283}},["at"] = ABILITY_TYPE_PASSIVE},
        },
        [19] = { 
            -- Herald
            ["skillLineId"] = 218,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 189791,},
                [1] = {["id"] = 189837,},
                [2] = {["id"] = 189867,},
            },["at"] = ABILITY_TYPE_ULTIMATE},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 185794,},
                [1] = {["id"] = 185803,},
                [2] = {["id"] = 182977,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 185805,},
                [1] = {["id"] = 183122,},
                [2] = {["id"] = 186366,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 185817,},
                [1] = {["id"] = 183006,},
                [2] = {["id"] = 185823,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 186452,},
                [1] = {["id"] = 185842,},
                [2] = {["id"] = 183047,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 185836,},
                [1] = {["id"] = 185839,},
                [2] = {["id"] = 182988,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 184844},[2] = {["id"] = 184847}},["at"] = ABILITY_TYPE_PASSIVE},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 184857},[2] = {["id"] = 184858}},["at"] = ABILITY_TYPE_PASSIVE},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 184870},[2] = {["id"] = 184873}},["at"] = ABILITY_TYPE_PASSIVE},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 184885},[2] = {["id"] = 184887}},["at"] = ABILITY_TYPE_PASSIVE},
        },
        [20] = { 
            -- Apocrypha
            ["skillLineId"] = 219,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 183676,},
                [1] = {["id"] = 192372,},
                [2] = {["id"] = 192380,},
            },["at"] = ABILITY_TYPE_ULTIMATE},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 183165,},
                [1] = {["id"] = 183430,},
                [2] = {["id"] = 186531,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 185894,},
                [1] = {["id"] = 185901,},
                [2] = {["id"] = 183241,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 183648,},
                [1] = {["id"] = 185908,},
                [2] = {["id"] = 186477,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 185912,},
                [1] = {["id"] = 183401,},
                [2] = {["id"] = 186489,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 185918,},
                [1] = {["id"] = 185921,},
                [2] = {["id"] = 183267,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 184918},[2] = {["id"] = 184923}},["at"] = ABILITY_TYPE_PASSIVE},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 185033},[2] = {["id"] = 185036}},["at"] = ABILITY_TYPE_PASSIVE},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 184930},[2] = {["id"] = 184932}},["at"] = ABILITY_TYPE_PASSIVE},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 185050},[2] = {["id"] = 185058}},["at"] = ABILITY_TYPE_PASSIVE},
        },
        [21] = { 
            -- Runeforms
            ["skillLineId"] = 220,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 183709,},
                [1] = {["id"] = 193794,},
                [2] = {["id"] = 193558,},
            },["at"] = ABILITY_TYPE_ULTIMATE},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 183261,},
                [1] = {["id"] = 186189,},
                [2] = {["id"] = 186191,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 183537,},
                [1] = {["id"] = 186193,},
                [2] = {["id"] = 186200,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 183447,},
                [1] = {["id"] = 186207,},
                [2] = {["id"] = 186209,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 183555,},
                [1] = {["id"] = 186229,},
                [2] = {["id"] = 186234,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 183542,},
                [1] = {["id"] = 186211,},
                [2] = {["id"] = 186220,},
            },["at"] = ABILITY_TYPE_ACTIVE},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 185185},[2] = {["id"] = 185186}},["at"] = ABILITY_TYPE_PASSIVE},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 185240},[2] = {["id"] = 185243}},["at"] = ABILITY_TYPE_PASSIVE},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 185238},[2] = {["id"] = 185239}},["at"] = ABILITY_TYPE_PASSIVE},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 185187},[2] = {["id"] = 185195}},["at"] = ABILITY_TYPE_PASSIVE},
        },
        [22]={
            -- Vengeance Ardent Flame
            ["skillLineld"]= 297,
            [1]= {["skilIPool"]= {[0] = {["id"] = 237627,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 237606,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 237607,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 237641,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 237788,}}},
            [6] ={["skillPool"]= {[0] = {["id"] = 237624,}}},
        },
        [23]={
            -- Vengeance Draconic Power
            ["skillLineld"]= 298,
            [1]= {["skillPool"]= {[0] = {["id"] = 237648,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 237615,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 237636,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 237638,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 237639,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 237620,}}},
        },
        [24]={
            -- Vengeance Earthen Heart
            ["skillLineld"]= 299,
            [1]= {["skillPool"]= {[0] = {["id"] = 237790,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 237781,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 237782,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 237785,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 237787,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 237630,}}},
        },
        [25]={
            -- Vengeance Assassination
            ["skillLineld"]= 300,
            [1]= {["skillPool"]= {[0] = {["id"] = 237619,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 237430,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 237601,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 237603,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 237604,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 237605,}}},
        },
        [26]={
            -- Vengeance Shadow
            ["skillLineld"]= 301,
            [1]= {["skillPool"]= {[0] = {["id"] = 237702,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 237632,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 237640,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 237647,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 237690,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 237700,}}},
        },
        [27]={
            -- Vengeance Siphoning
            ["skillLineld"]= 302,
            [1]= {["skillPool"]= {[0] = {["id"] = 237722,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 237709,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 237711,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 237713,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 237716,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 237719,}}},
        },
        [28]={
            -- Vengeance Aedric Spear
            ["skillLineld"]= 303,
            [1]= {["skillPool"]= {[0] = {["id"] = 237811,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 237861,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 237863,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 237883,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 237887,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 237890,}}},
        },
        [29]={
            -- Vengeance Dawn's Wrath
            ["skillLineld"]= 304,
            [1]= {["skillPool"]= {[0] = {["id"] = 237942,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 237949,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 237953,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 237957,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 237964,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 237974,}}},
        },
        [30]={
            -- Vengeance Restoring Light
            ["skillLineld"]= 305,
            [1]= {["skillPool"]= {[0] = {["id"] = 237994,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 238001,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 238018,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 238019,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 238026,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 238041,}}},
        },
        [31]={
            -- Vengeance Daedric Summoning
            ["skillLineld"]= 306,
            [1]= {["skillPool"]= {[0] = {["id"] = 237933,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 237865,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 237876,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 237915,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 237929,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 237930,}}},
        },
        [32]={
            -- Vengeance Dark Magic
            ["skillLineld"]= 307,
            [1]= {["skillPool"]= {[0] = {["id"] = 237856,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 237792,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 247103,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 237803,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 237808,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 237812,}}},
        },
        [33]={
            -- Vengeance Storm Calling
            ["skillLineld"]= 308,
            [1]= {["skillPool"]= {[0] = {["id"] = 237998,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 237948,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 237954,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 237959,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 237971,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 237981,}}},
        },
        [34]={
            -- Vengeance Animal Companions
            ["skillLineld"]= 309,
            [1]= {["skillPool"]= {[0] = {["id"] = 238043,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 238000,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 247093,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 238016,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 238020,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 238027,}}},
        },
        [35]={
            -- Vengeance Green Balance
            ["skillLineld"]= 310,
            [1]= {["skillPool"]= {[0] = {["id"] = 238074,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 238054,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 238055,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 238065,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 238067,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 238071,}}},
        },
        [36]={
            -- Vengeance Winter's Embrace
            ["skillLineld"]= 311,
            [1]= {["skillPool"]= {[0] = {["id"] = 238098,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 238076,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 238079,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 238088,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 238089,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 238091,}}},
        },
        [37]={
            -- Vengeance Grave Lord
            ["skillLineld"]= 312,
            [1]= {["skillPool"]= {[0] = {["id"] = 238129,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 238081,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 246057,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 238095,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 246029,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 238126,}}},
        },
        [38]={
            -- Vengeance Bone Tyrant
            ["skillLineld"]= 313,
            [1]= {["skillPool"]= {[0] = {["id"] = 238236,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 238137,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 246025,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 238141,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 238178,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 253156,}}},
        },
        [39]={
            -- Vengeance Living Death
            ["skillLineld"]= 314,
            [1]= {["skillPool"]= {[0] = {["id"] = 238316,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 238251,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 238255,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 238258,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 238265,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 238277,}}},
        },
        [40]={
            -- Vengeance Curative Runeforms
            ["skillLineld"]= 315,
            [1]= {["skillPool"]= {[0] = {["id"] = 238549,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 238429,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 238482,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 238536,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 238539,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 238545,}}},
        },
        [41]={
            -- Vengeance Soldier of Apocrypha
            ["skillLineld"]= 316,
            [1]= {["skillPool"]= {[0] = {["id"] = 238274,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 238238,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 238249,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 238256,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 238262,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 238267,}}},
        },
        [42]={
            -- Vengeance Herald of the Tome
            ["skillLineld"]= 317,
            [1]= {["skillPool"]= {[0] = {["id"] = 238228,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 238169,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 238174,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 238189,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 238191,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 238225,}}},
        },
        [43] = {
            -- Class Mastery -- Dragonknight
            ["skillLineId"] = 351,
            [1] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 238232,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [2] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 240268,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 259224,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263220,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263247,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [44] = {
            -- Class Mastery -- Arcanist
            ["skillLineId"] = 352,
            [1] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263316,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [2] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263398,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263410,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263412,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263416,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [45] = {
            -- Class Mastery -- Necromancer
            ["skillLineId"] = 353,
            [1] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263448,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [2] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263465,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263509,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263549,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263554,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [46] = {
            -- Class Mastery -- Warden
            ["skillLineId"] = 354,
            [1] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263519,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [2] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263520,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263521,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263522,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263523,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [47] = {
            -- Class Mastery -- Templar
            ["skillLineId"] = 355,
            [1] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263585,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [2] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263586,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263587,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263588,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263589,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [48] = {
            -- Class Mastery -- Nightblade
            ["skillLineId"] = 356,
            [1] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263603,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [2] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263604,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263605,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263606,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263607,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [49] = {
            -- Class Mastery -- Sorcerer
            ["skillLineId"] = 357,
            [1] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263870,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [2] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263871,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263872,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263873,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 263874,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
    },

    [SKILL_TYPE_WEAPON] = {
        [1] = { 
            -- Two Handed
            ["skillLineId"] = 30,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 83216,},
                [1] = {["id"] = 83229,},
                [2] = {["id"] = 83238,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                ["mx"] = nil,
                [0] = {["id"] = 4,},
            },["at"] = ABILITY_TYPE_CRAFTED,
            ["autoGrant"] = 1,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 28279,},
                [1] = {["id"] = 38814,},
                [2] = {["id"] = 38807,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 28448,},
                [1] = {["id"] = 38788,},
                [2] = {["id"] = 38778,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 20919,},
                [1] = {["id"] = 38745,},
                [2] = {["id"] = 38754,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 28302,},
                [1] = {["id"] = 38823,},
                [2] = {["id"] = 38819,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["skillPool"] = {
                [0] = {["id"] = 28297,},
                [1] = {["id"] = 38794,},
                [2] = {["id"] = 38802,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29387,},[2] = {["id"] = 45444,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29375,},[2] = {["id"] = 45430,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29388,},[2] = {["id"] = 45443,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [11] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29389,},[2] = {["id"] = 45446,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [12] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29391,},[2] = {["id"] = 45448,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [2] = { 
            -- One hand and shield
            ["skillLineId"] = 29,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 83272,},
                [1] = {["id"] = 83292,},
                [2] = {["id"] = 83310,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                ["mx"] = nil,
                [0] = {["id"] = 3,},
            },["at"] = ABILITY_TYPE_CRAFTED,
            ["autoGrant"] = 1,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 28306,},
                [1] = {["id"] = 38256,},
                [2] = {["id"] = 38250,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {	["skillPool"] = {
                [0] = {["id"] = 28304,},
                [1] = {["id"] = 38268,},
                [2] = {["id"] = 38264,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 28727,},
                [1] = {["id"] = 38312,},
                [2] = {["id"] = 38317,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 28719,},
                [1] = {["id"] = 38401,},
                [2] = {["id"] = 38405,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["skillPool"] = {
                [0] = {["id"] = 28365,},
                [1] = {["id"] = 38455,},
                [2] = {["id"] = 38452,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29420,},[2] = {["id"] = 45471,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29397,},[2] = {["id"] = 45452,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29415,},[2] = {["id"] = 45469,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [11] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29399,},[2] = {["id"] = 45472,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [12] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29422,},[2] = {["id"] = 45473,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [3] = { 
            -- Dual Wield
            ["skillLineId"] = 31,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 83600,},
                [1] = {["id"] = 85187,},
                [2] = {["id"] = 85179,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                ["mx"] = nil,
                [0] = {["id"] = 7,},
            },["at"] = ABILITY_TYPE_CRAFTED,
            ["autoGrant"] = 1,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 28607,},
                [1] = {["id"] = 38857,},
                [2] = {["id"] = 38846,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 28379,},
                [1] = {["id"] = 38839,},
                [2] = {["id"] = 38845,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 28591,},
                [1] = {["id"] = 38891,},
                [2] = {["id"] = 38861,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 28613,},
                [1] = {["id"] = 38901,},
                [2] = {["id"] = 38906,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["skillPool"] = {
                [0] = {["id"] = 21157,},
                [1] = {["id"] = 38914,},
                [2] = {["id"] = 38910,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 18929,},[2] = {["id"] = 45476,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30873,},[2] = {["id"] = 45477,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30872,},[2] = {["id"] = 45478,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [11] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 21114,},[2] = {["id"] = 45481,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [12] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30893,},[2] = {["id"] = 45482,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [4] = { 
            -- Bow
            ["skillLineId"] = 32,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 83465,},
                [1] = {["id"] = 85257,},
                [2] = {["id"] = 85451,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                ["mx"] = nil,
                [0] = {["id"] = 1,},
            },["at"] = ABILITY_TYPE_CRAFTED,
            ["autoGrant"] = 1,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 28882,},
                [1] = {["id"] = 38685,},
                [2] = {["id"] = 38687,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 28876,},
                [1] = {["id"] = 38689,},
                [2] = {["id"] = 38695,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 28879,},
                [1] = {["id"] = 38672,},
                [2] = {["id"] = 38669,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 31271,},
                [1] = {["id"] = 38705,},
                [2] = {["id"] = 38701,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["skillPool"] = {
                [0] = {["id"] = 28869,},
                [1] = {["id"] = 38645,},
                [2] = {["id"] = 38660,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30937,},[2] = {["id"] = 45494,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30930,},[2] = {["id"] = 45492,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30942,},[2] = {["id"] = 45493,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [11] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30936,},[2] = {["id"] = 45497,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [12] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30923,},[2] = {["id"] = 45498,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [5] = { 
            -- Destruction Staff
            ["skillLineId"] = 33,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 83619,},
                [1] = {["id"] = 84434,},
                [2] = {["id"] = 83642,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                ["mx"] = nil,
                [0] = {["id"] = 5,},
            },["at"] = ABILITY_TYPE_CRAFTED,
            ["autoGrant"] = 1,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 46340,},
                [1] = {["id"] = 46348,},
                [2] = {["id"] = 46356,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 28858,},
                [1] = {["id"] = 39052,},
                [2] = {["id"] = 39011,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 29091,},
                [1] = {["id"] = 38984,},
                [2] = {["id"] = 38937,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 29173,},
                [1] = {["id"] = 39089,},
                [2] = {["id"] = 39095,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["skillPool"] = {
                [0] = {["id"] = 28800,},
                [1] = {["id"] = 39143,},
                [2] = {["id"] = 39161,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30948,},[2] = {["id"] = 45500,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30957,},[2] = {["id"] = 45509,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30962,},[2] = {["id"] = 45512,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [11] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30959,},[2] = {["id"] = 45513,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [12] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30965,},[2] = {["id"] = 45514,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [6] = { 
            -- Restoration Staff
            ["skillLineId"] = 34,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 83552,},
                [1] = {["id"] = 83850,},
                [2] = {["id"] = 85132,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                ["mx"] = nil,
                [0] = {["id"] = 6,},
            },["at"] = ABILITY_TYPE_CRAFTED,
            ["autoGrant"] = 1,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 28385,},
                [1] = {["id"] = 40058,},
                [2] = {["id"] = 40060,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 28536,},
                [1] = {["id"] = 40076,},
                [2] = {["id"] = 40079,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 37243,},
                [1] = {["id"] = 40103,},
                [2] = {["id"] = 40094,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 37232,},
                [1] = {["id"] = 40130,},
                [2] = {["id"] = 40126,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["skillPool"] = {
                [0] = {["id"] = 31531,},
                [1] = {["id"] = 40109,},
                [2] = {["id"] = 40116,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30973,},[2] = {["id"] = 45517,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30980,},[2] = {["id"] = 45519,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30972,},[2] = {["id"] = 45520,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [11] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30869,},[2] = {["id"] = 45521,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [12] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 30981,},[2] = {["id"] = 45524,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [7]={
            -- Vengeance Two Handed
            ["skillLineld"]= 319,
            [1]= {["skillPool"]= {[0] = {["id"] = 240494,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 240453,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 240459,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 240480,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 240482,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 240483,}}},
        },
        [8]={
            -- Vengeance One Hand and Shield
            ["skillLineld"]= 320,
            [1]= {["skillPool"]= {[0] = {["id"] = 240572,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 240547,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 240558,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 240560,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 240560,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 240569,}}},
        },
        [9]={
            -- Vengeance Dual Wield
            ["skillLineld"]= 321,
            [1]= {["skillPool"]= {[0] = {["id"] = 241236,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 240585,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 240590,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 240594,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 241188,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 241234,}}},
        },
        [10]={
            -- Vengeance Bow
            ["skillLineld"]= 322,
            [1]= {["skillPool"]= {[0] = {["id"] = 241278,}}},
            [2]= {["skillPool"]= {[0] = {["id"] = 241255,}}},
            [3]= {["skillPool"]= {[0] = {["id"] = 241258,}}},
            [4]= {["skillPool"]= {[0] = {["id"] = 241261,}}},
            [5]= {["skillPool"]= {[0] = {["id"] = 241274,}}},
            [6]= {["skillPool"]= {[0] = {["id"] = 241275,}}},
        },
        [11]={
             -- Vengeance Destruction Staff
             ["skillLineld"]= 323,
             [1]= {["skillPool"]= {[0] = {["id"] = 241485,}}},
             [2]= {["skillPool"]= {[0] = {["id"] = 241291,}}},
             [3]= {["skillPool"]= {[0] = {["id"] = 241302,}}},
             [4]= {["skillPool"]= {[0] = {["id"] = 241429,}}},
             [5]= {["skillPool"]= {[0] = {["id"] = 241447,}}},
             [6]= {["skillPool"]= {[0] = {["id"] = 241454,}}},
        },
        [12]={
             -- Vengeance Restoration Staff
             ["skillLineld"]= 324,
             [1]= {["skillPool"]= {[0] = {["id"] = 241586,}}},
             [2]= {["skillPool"]= {[0] = {["id"] = 241517,}}},
             [3]= {["skillPool"]= {[0] = {["id"] = 241521,}}},
             [4]= {["skillPool"]= {[0] = {["id"] = 246616,}}},
             [5]= {["skillPool"]= {[0] = {["id"] = 241535,}}},
             [6]= {["skillPool"]= {[0] = {["id"] = 241536,}}},
        },
    },

    [SKILL_TYPE_ARMOR] = {
        [1] = { 
            -- Light
            ["skillLineId"] = 24,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 29338,},
                [1] = {["id"] = 39186,},
                [2] = {["id"] = 39182,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [2] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 150185,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [3] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 152778,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 29639,},[2] = {["id"] = 45548,},[3] = {["id"] = 45549,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29665,},[2] = {["id"] = 45557,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [6] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29663,},[2] = {["id"] = 45559,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29668,},[2] = {["id"] = 45561,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29667,},[2] = {["id"] = 45562,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [2] = { 
            -- Medium
            ["skillLineId"] = 25,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 29556,},
                [1] = {["id"] = 39195,},
                [2] = {["id"] = 39192,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [2] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 150181,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 29743,},[2] = {["id"] = 45563,},[3] = {["id"] = 45564,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29687,},[2] = {["id"] = 45565,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29738,},[2] = {["id"] = 45567,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [6] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29686,},[2] = {["id"] = 45572,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29742,},[2] = {["id"] = 45574,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [3] = { 
            -- Heavy
            ["skillLineId"] = 26,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 29552,},
                [1] = {["id"] = 39205,},
                [2] = {["id"] = 39197,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [2] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 150184,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [3] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 152780,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 29825,},[2] = {["id"] = 45531,},[3] = {["id"] = 45533,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29769,},[2] = {["id"] = 45526,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [6] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29804,},[2] = {["id"] = 45546,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29773,},[2] = {["id"] = 45528,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 29791,},[2] = {["id"] = 45529,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
    },

    [SKILL_TYPE_WORLD] = {
        [1] = { 
            -- Excavation
            ["skillLineId"] = 157,
            [1] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 139908,},[2] = {["id"] = 139909,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 139904,},[2] = {["id"] = 139905,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [3] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 139943,},[2] = {["id"] = 140093,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 140173,},[2] = {["id"] = 140174,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 139910,},[2] = {["id"] = 139911,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [6] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 139906,},[2] = {["id"] = 139907,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 139771,},[2] = {["id"] = 139772,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [2] = { 
            -- Legerdemain
            ["skillLineId"] = 111,
            [1] = {["mx"] = 4,["skillPool"] = {[1] = {["id"] = 63799,},[2] = {["id"] = 63800,},[3] = {["id"] = 63801,},[4] = {["id"] = 63802,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [2] = {["mx"] = 4,["skillPool"] = {[1] = {["id"] = 63803,},[2] = {["id"] = 63804,},[3] = {["id"] = 63805,},[4] = {["id"] = 63806,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 4,["skillPool"] = {[1] = {["id"] = 63807,},[2] = {["id"] = 63808,},[3] = {["id"] = 63809,},[4] = {["id"] = 63810,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 4,["skillPool"] = {[1] = {["id"] = 63811,},[2] = {["id"] = 63812,},[3] = {["id"] = 63813,},[4] = {["id"] = 63814,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 4,["skillPool"] = {[1] = {["id"] = 63815,},[2] = {["id"] = 63816,},[3] = {["id"] = 63817,},[4] = {["id"] = 63818,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [3] = { 
            -- Scrying
            ["skillLineId"] = 155,
            [1] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 139942,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 5,["skillPool"] = {[1] = {["id"] = 139773,},[2] = {["id"] = 139774,},[3] = {["id"] = 139775,},[4] = {["id"] = 139776,},[5] = {["id"] = 141018,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [3] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 139778,},[2] = {["id"] = 139779,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 139305,},[2] = {["id"] = 139306,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 139780,},[2] = {["id"] = 139781,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [6] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 139307,},[2] = {["id"] = 139308,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 139309,},[2] = {["id"] = 139321,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 139777,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [4] = { 
            -- Soul Magic
            ["skillLineId"] = 72,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 39270,},
                [1] = {["id"] = 40420,},
                [2] = {["id"] = 40414,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                ["mx"] = nil,
                [0] = {["id"] = 2,},
            },["at"] = ABILITY_TYPE_CRAFTED,
            ["autoGrant"] = 1,},
            [3] = {["skillPool"] = {
                ["mx"] = nil,
                [0] = {["id"] = 8,},
            },["at"] = ABILITY_TYPE_CRAFTED,
            ["autoGrant"] = 1,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 26768,},
                [1] = {["id"] = 40328,},
                [2] = {["id"] = 40317,},
            },["at"] = ABILITY_TYPE_ACTIVE, ["autoGrant"] = 0,},
            [5] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 39266,},[2] = {["id"] = 45583,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [6] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 39269,},[2] = {["id"] = 45590,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 39263,},[2] = {["id"] = 45580,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [5] = { 
            -- Vampire
            ["skillLineId"] = 51,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 32624,},
                [1] = {["id"] = 38932,},
                [2] = {["id"] = 38931,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 32893,},
                [1] = {["id"] = 38949,},
                [2] = {["id"] = 38956,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 132141,},
                [1] = {["id"] = 134160,},
                [2] = {["id"] = 135841,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 134583,},
                [1] = {["id"] = 135905,},
                [2] = {["id"] = 137259,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 128709,},
                [1] = {["id"] = 137861,},
                [2] = {["id"] = 138097,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 32986,},
                [1] = {["id"] = 38963,},
                [2] = {["id"] = 38965,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 42054,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 33095,},[2] = {["id"] = 46041,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 33096,},[2] = {["id"] = 46040,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 33093,},[2] = {["id"] = 33090,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [11] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 33091,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [12] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 132844,},[2] = {["id"] = 135218,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [6] = { 
            -- Werewolf
            ["skillLineId"] = 50,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 32455,},
                [1] = {["id"] = 39075,},
                [2] = {["id"] = 39076,},
            },["at"] = ABILITY_TYPE_ULTIMATE,["autoGrant"] = 0,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 32632,},
                [1] = {["id"] = 39105,},
                [2] = {["id"] = 39104,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 58310,},
                [1] = {["id"] = 58317,},
                [2] = {["id"] = 58325,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 32633,},
                [1] = {["id"] = 39113,},
                [2] = {["id"] = 39114,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 58405,},
                [1] = {["id"] = 58742,},
                [2] = {["id"] = 58798,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 58855,},
                [1] = {["id"] = 58864,},
                [2] = {["id"] = 58879,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 32634,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 32636,},[2] = {["id"] = 46142,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 32637,},[2] = {["id"] = 46135,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 32638,},[2] = {["id"] = 46139,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [11] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 32639,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [12] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 32641,},[2] = {["id"] = 46137,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
    },

    [SKILL_TYPE_GUILD] = {
        [1] = { 
            -- Dark Brotherhood
            ["skillLineId"] = 118,
            [1] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 78219,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 4,["skillPool"] = {[1] = {["id"] = 77392,},[2] = {["id"] = 77394,},[3] = {["id"] = 77395,},[4] = {["id"] = 79865,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 4,["skillPool"] = {[1] = {["id"] = 77397,},[2] = {["id"] = 77398,},[3] = {["id"] = 77399,},[4] = {["id"] = 79868,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 77396,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 77400,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [6] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 77401,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [2] = { 
            -- Fighters Guild
            ["skillLineId"] = 45,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 35713,},
                [1] = {["id"] = 40161,},
                [2] = {["id"] = 40158,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                ["mx"] = nil,
                [0] = {["id"] = 10,},
            },["at"] = ABILITY_TYPE_CRAFTED,
            ["autoGrant"] = 1,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 35721,},
                [1] = {["id"] = 40300,},
                [2] = {["id"] = 40336,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 35737,},
                [1] = {["id"] = 40181,},
                [2] = {["id"] = 40169,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 35762,},
                [1] = {["id"] = 40194,},
                [2] = {["id"] = 40195,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 35750,},
                [1] = {["id"] = 40382,},
                [2] = {["id"] = 40372,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 29062,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 35803,},[2] = {["id"] = 45595,},[3] = {["id"] = 45596,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 35800,},[2] = {["id"] = 45597,},[3] = {["id"] = 45599,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 40393,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [11] = {
                ["mx"] = nil,
                ["skillPool"] = {
                    [1] = {["id"] = 35804,},},
                ["at"] = ABILITY_TYPE_PASSIVE,
            },
        },
        [3] = { 
            -- Mages Guild
            ["skillLineId"] = 44,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 16536,},
                [1] = {["id"] = 40489,},
                [2] = {["id"] = 40493,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                ["mx"] = nil,
                [0] = {["id"] = 9,},
            },["at"] = ABILITY_TYPE_CRAFTED,
            ["autoGrant"] = 1,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 30920,},
                [1] = {["id"] = 40478,},
                [2] = {["id"] = 40483,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 28567,},
                [1] = {["id"] = 40457,},
                [2] = {["id"] = 40452,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 31632,},
                [1] = {["id"] = 40470,},
                [2] = {["id"] = 40465,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 31642,},
                [1] = {["id"] = 40445,},
                [2] = {["id"] = 40441,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 29061,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 40436,},[2] = {["id"] = 45601,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 40437,},[2] = {["id"] = 45602,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 40438,},[2] = {["id"] = 45603,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [11] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 43561,},[2] = {["id"] = 45607,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [4] = { 
            -- Psijic Order
            ["skillLineId"] = 130,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 103478,},
                [1] = {["id"] = 103557,},
                [2] = {["id"] = 103564,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 103488,},
                [1] = {["id"] = 104059,},
                [2] = {["id"] = 104079,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 103483,},
                [1] = {["id"] = 103571,},
                [2] = {["id"] = 103623,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 103503,},
                [1] = {["id"] = 103706,},
                [2] = {["id"] = 103710,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 103543,},
                [1] = {["id"] = 103747,},
                [2] = {["id"] = 103755,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 103492,},
                [1] = {["id"] = 103652,},
                [2] = {["id"] = 103665,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 103793,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 103809,},[2] = {["id"] = 103811,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 103819,},[2] = {["id"] = 103878,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [10] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 103888,},[2] = {["id"] = 103964,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [11] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 103972,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [5] = { 
            -- Thieves Guild
            ["skillLineId"] = 117,
            [1] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 74580,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 4,["skillPool"] = {[1] = {["id"] = 76454,},[2] = {["id"] = 76455,},[3] = {["id"] = 76456,},[4] = {["id"] = 76457,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 4,["skillPool"] = {[1] = {["id"] = 76458,},[2] = {["id"] = 76459,},[3] = {["id"] = 76460,},[4] = {["id"] = 76461,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 76451,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 76452,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [6] = {["mx"] = 1,["skillPool"] = {[1] = {["id"] = 76453,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [6] = { 
            -- Undaunted
            ["skillLineId"] = 55,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 39489,},
                [1] = {["id"] = 41967,},
                [2] = {["id"] = 41958,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [2] = {["skillPool"] = {
                [0] = {["id"] = 39425,},
                [1] = {["id"] = 41990,},
                [2] = {["id"] = 42012,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 39475,},
                [1] = {["id"] = 42056,},
                [2] = {["id"] = 42060,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 39369,},
                [1] = {["id"] = 42138,},
                [2] = {["id"] = 42176,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 39298,},
                [1] = {["id"] = 42028,},
                [2] = {["id"] = 42038,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 55584,},[2] = {["id"] = 55676,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 55366,},[2] = {["id"] = 55386,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [7]={
             -- Vengeance Fighters Guild
             ["skillLineld"]= 330,
             [1]= {["skillPool"]= {[0] = {["id"] = 246303,}}},
             [2]= {["skillPool"]= {[0] = {["id"] = 246070,}}},
             [3]= {["skillPool"]= {[0] = {["id"] = 246071,}}},
             [4]= {["skillPool"]= {[0] = {["id"] = 246091,}}},
             [5]= {["skillPool"]= {[0] = {["id"] = 246275,}}},
        },
        [8]={
             -- Vengeance Mages Guild
             ["skillLineld"]= 331,
             [1]= {["skillPool"]= {[0] = {["id"] = 246494,}}},
             [2]= {["skillPool"]= {[0] = {["id"] = 246489,}}},
             [3]= {["skillPool"]= {[0] = {["id"] = 246479,}}},
             [4]= {["skillPool"]= {[0] = {["id"] = 246482,}}},
             [5]= {["skillPool"]= {[0] = {["id"] = 246485,}}},
        },
    },

    [SKILL_TYPE_AVA] = {
        [1] = { 
            -- Assault
            ["skillLineId"] = 48,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 38563,},
                [1] = {["id"] = 40223,},
                [2] = {["id"] = 40220,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                ["mx"] = nil,
                [0] = {["id"] = 11,},
            },["at"] = ABILITY_TYPE_CRAFTED,
            ["autoGrant"] = 1,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 61503,},
                [1] = {["id"] = 61505,},
                [2] = {["id"] = 61507,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 38566,},
                [1] = {["id"] = 40211,},
                [2] = {["id"] = 40215,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 33376,},
                [1] = {["id"] = 40255,},
                [2] = {["id"] = 40242,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 61487,},
                [1] = {["id"] = 61491,},
                [2] = {["id"] = 61500,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 39248,},[2] = {["id"] = 45614,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 39254,},[2] = {["id"] = 45621,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 39252,},[2] = {["id"] = 45619,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [2] = { 
            -- Emperor
            ["skillLineId"] = 71,
            [1] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 39641,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 39625,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [3] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 39630,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [4] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 39644,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [5] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 39647,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
        },
        [3] = { 
            -- Support
            ["skillLineId"] = 67,
            [1] = {["skillPool"] = {
                [0] = {["id"] = 38573,},
                [1] = {["id"] = 40237,},
                [2] = {["id"] = 40239,},
            },["at"] = ABILITY_TYPE_ULTIMATE,},
            [2] = {["skillPool"] = {
                ["mx"] = nil,
                [0] = {["id"] = 12,},
            },["at"] = ABILITY_TYPE_CRAFTED,
            ["autoGrant"] = 1,},
            [3] = {["skillPool"] = {
                [0] = {["id"] = 38570,},
                [1] = {["id"] = 40229,},
                [2] = {["id"] = 40226,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [4] = {["skillPool"] = {
                [0] = {["id"] = 38571,},
                [1] = {["id"] = 40232,},
                [2] = {["id"] = 40234,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [5] = {["skillPool"] = {
                [0] = {["id"] = 61511,},
                [1] = {["id"] = 61536,},
                [2] = {["id"] = 61529,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [6] = {["skillPool"] = {
                [0] = {["id"] = 61489,},
                [1] = {["id"] = 61519,},
                [2] = {["id"] = 61524,},
            },["at"] = ABILITY_TYPE_ACTIVE,},
            [7] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 39255,},[2] = {["id"] = 45622,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [8] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 39259,},[2] = {["id"] = 45624,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [9] = {["mx"] = 2,["skillPool"] = {[1] = {["id"] = 39261,},[2] = {["id"] = 45625,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
        [4]={
             -- Vengeance Assault
             ["skillLineld"]= 325,
             [1]= {["skillPool"]= {[0] = {["id"] = 244644,}}},
             [2]= {["skillPool"]= {[0] = {["id"] = 244496,}}},
             [3]= {["skillPool"]= {[0] = {["id"] = 244498,}}},
             [4]= {["skillPool"]= {[0] = {["id"] = 244514,}}},
             [5]= {["skillPool"]= {[0] = {["id"] = 244541,}}},
        },
        [5]={
             -- Vengeance Support
             ["skillLineld"]= 326,
             [1]= {["skillPool"]= {[0] = {["id"] = 244725,}}},
             [2]= {["skillPool"]= {[0] = {["id"] = 244688,}}},
             [3]= {["skillPool"]= {[0] = {["id"] = 244715,}}},
             [4]= {["skillPool"]= {[0] = {["id"] = 245055,}}},
             [5]= {["skillPool"]= {[0] = {["id"] = 245049,}}},
        },
    },

    [SKILL_TYPE_RACIAL] = {
        [1] = { 
            -- Breton
            ["skillLineId"] = 60,
            [1] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 36247,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 35995,},[2] = {["id"] = 45259,},[3] = {["id"] = 45260,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36266,},[2] = {["id"] = 45261,},[3] = {["id"] = 45262,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36303,},[2] = {["id"] = 45263,},[3] = {["id"] = 45264,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [2] = { 
            -- Redguard
            ["skillLineId"] = 62,
            [1] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 84680,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36009,},[2] = {["id"] = 45277,},[3] = {["id"] = 45278,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 117752,},[2] = {["id"] = 117753,},[3] = {["id"] = 117754,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36546,},[2] = {["id"] = 45313,},[3] = {["id"] = 45315,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [3] = { 
            -- Orc
            ["skillLineId"] = 52,
            [1] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 33293,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 33301,},[2] = {["id"] = 45307,},[3] = {["id"] = 45309,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 84668,},[2] = {["id"] = 84670,},[3] = {["id"] = 84672,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 33304,},[2] = {["id"] = 45311,},[3] = {["id"] = 45312,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [4] = { 
            -- Dark-Elf
            ["skillLineId"] = 64,
            [1] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 36588,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36591,},[2] = {["id"] = 45265,},[3] = {["id"] = 45267,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36593,},[2] = {["id"] = 45269,},[3] = {["id"] = 45270,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36598,},[2] = {["id"] = 45271,},[3] = {["id"] = 45272,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [5] = { 
            -- Nord
            ["skillLineId"] = 65,
            [1] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 36626,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36627,},[2] = {["id"] = 45303,},[3] = {["id"] = 45304,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36064,},[2] = {["id"] = 45297,},[3] = {["id"] = 45298,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36628,},[2] = {["id"] = 45305,},[3] = {["id"] = 45306,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [6] = { 
            -- Argonian
            ["skillLineId"] = 63,
            [1] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 36582,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36585,},[2] = {["id"] = 45257,},[3] = {["id"] = 45258,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36583,},[2] = {["id"] = 45253,},[3] = {["id"] = 45255,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36568,},[2] = {["id"] = 45243,},[3] = {["id"] = 45247,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [7] = { 
            -- High-Elf
            ["skillLineId"] = 56,
            [1] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 35965,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 35993,},[2] = {["id"] = 45273,},[3] = {["id"] = 45274,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 117968,},[2] = {["id"] = 117969,},[3] = {["id"] = 117970,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 35998,},[2] = {["id"] = 45275,},[3] = {["id"] = 45276,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [8] = { 
            -- Wood-Elf
            ["skillLineId"] = 57,
            [1] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 36008,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36022,},[2] = {["id"] = 45295,},[3] = {["id"] = 45296,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 64279,},[2] = {["id"] = 64280,},[3] = {["id"] = 64281,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36011,},[2] = {["id"] = 45317,},[3] = {["id"] = 45319,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [9] = { 
            -- Khajit
            ["skillLineId"] = 58,
            [1] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 36063,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 70386,},[2] = {["id"] = 70388,},[3] = {["id"] = 70390,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 117846,},[2] = {["id"] = 117847,},[3] = {["id"] = 117848,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36067,},[2] = {["id"] = 45299,},[3] = {["id"] = 45301,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [10] = { 
            -- Imperial
            ["skillLineId"] = 59,
            [1] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 36312,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 50903,},[2] = {["id"] = 50906,},[3] = {["id"] = 50907,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36153,},[2] = {["id"] = 45279,},[3] = {["id"] = 45280,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 36155,},[2] = {["id"] = 45291,},[3] = {["id"] = 45293,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
    },

    [SKILL_TYPE_TRADESKILL] = {
        [1] = { 
            -- Alchemy
            ["skillLineId"] = 77,
            [1] = {["mx"] = 8,["skillPool"] = {[1] = {["id"] = 45542,},[2] = {["id"] = 45547,},[3] = {["id"] = 45550,},[4] = {["id"] = 45551,},[5] = {["id"] = 45552,},[6] = {["id"] = 49163},[7] = {["id"] = 70042},[8] = {["id"] = 70043,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 47840,},[2] = {["id"] = 47841,},[3] = {["id"] = 47842,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 45569,},[2] = {["id"] = 45571,},[3] = {["id"] = 45573,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 45577,},[2] = {["id"] = 45578,},[3] = {["id"] = 45579,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = nil,["skillPool"] = {[1] = {["id"] = 45555,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [6] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 47831,},[2] = {["id"] = 47832,},[3] = {["id"] = 47834,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [2] = { 
            -- Clothing
            ["skillLineId"] = 81,
            [1] = {["mx"] = 10,["skillPool"] = {[1] = {["id"] = 47288,},[2] = {["id"] = 47289,},[3] = {["id"] = 47290,},[4] = {["id"] = 47291,},[5] = {["id"] = 47292,},[6] = {["id"] = 47293,},[7] = {["id"] = 48187,},[8] = {["id"] = 48188,},[9] = {["id"] = 48189,},[10] = {["id"] = 70044,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 47860,},[2] = {["id"] = 47861,},[3] = {["id"] = 47862,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 48199,},[2] = {["id"] = 48200,},[3] = {["id"] = 48201,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 48193,},[2] = {["id"] = 48194,},[3] = {["id"] = 48195,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 4,["skillPool"] = {[1] = {["id"] = 48190,},[2] = {["id"] = 48191,},[3] = {["id"] = 48192,},[4] = {["id"] = 58782,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [6] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 48196,},[2] = {["id"] = 48197,},[3] = {["id"] = 48198,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [3] = { 
            -- Provisionning
            ["skillLineId"] = 76,
            [1] = {["mx"] = 6,["skillPool"] = {[1] = {["id"] = 44590,},[2] = {["id"] = 44595,},[3] = {["id"] = 44597,},[4] = {["id"] = 44598,},[5] = {["id"] = 44599,},[6] = {["id"] = 44650,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 4,["skillPool"] = {[1] = {["id"] = 44625,},[2] = {["id"] = 44630,},[3] = {["id"] = 44631,},[4] = {["id"] = 69953,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 44602,},[2] = {["id"] = 44609,},[3] = {["id"] = 44610,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 44612,},[2] = {["id"] = 44614,},[3] = {["id"] = 44615,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 44616,},[2] = {["id"] = 44617,},[3] = {["id"] = 44619,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [6] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 44620,},[2] = {["id"] = 44621,},[3] = {["id"] = 44624,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [7] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 44634,},[2] = {["id"] = 44640,},[3] = {["id"] = 44641,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [4] = { 
            -- Enchanting
            ["skillLineId"] = 78,
            [1] = {["mx"] = 10,["skillPool"] = {[1] = {["id"] = 46727,},[2] = {["id"] = 46729,},[3] = {["id"] = 46731,},[4] = {["id"] = 46735,},[5] = {["id"] = 46736,},[6] = {["id"] = 46740,},[7] = {["id"] = 49112,},[8] = {["id"] = 49113,},[9] = {["id"] = 49114,},[10] = {["id"] = 70045,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 4,["skillPool"] = {[1] = {["id"] = 46758,},[2] = {["id"] = 46759,},[3] = {["id"] = 46760,},[4] = {["id"] = 46763,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 47851,},[2] = {["id"] = 47852,},[3] = {["id"] = 47853,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 46770,},[2] = {["id"] = 46771,},[3] = {["id"] = 46772,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 46767,},[2] = {["id"] = 46768,},[3] = {["id"] = 46769,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [5] = { 
            -- Blacksmithing
            ["skillLineId"] = 79,
            [1] = {["mx"] = 10,["skillPool"] = {[1] = {["id"] = 47276,},[2] = {["id"] = 47277,},[3] = {["id"] = 47278,},[4] = {["id"] = 47279,},[5] = {["id"] = 47280,},[6] = {["id"] = 47281,},[7] = {["id"] = 48157,},[8] = {["id"] = 48158,},[9] = {["id"] = 48159,},[10] = {["id"] = 70041,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 47854,},[2] = {["id"] = 47855,},[3] = {["id"] = 47856,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 48169,},[2] = {["id"] = 48170,},[3] = {["id"] = 48171,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 48163,},[2] = {["id"] = 48164,},[3] = {["id"] = 48165,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 4,["skillPool"] = {[1] = {["id"] = 48160,},[2] = {["id"] = 48161,},[3] = {["id"] = 48162,},[4] = {["id"] = 58784,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [6] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 48166,},[2] = {["id"] = 48167,},[3] = {["id"] = 48168,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [6] = { 
            -- Jewelry Crafting
            ["skillLineId"] = 141,
            [1] = {["mx"] = 5,["skillPool"] = {[1] = {["id"] = 103632,},[2] = {["id"] = 103633,},[3] = {["id"] = 103634,},[4] = {["id"] = 103635,},[5] = {["id"] = 103636,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 103637,},[2] = {["id"] = 103638,},[3] = {["id"] = 103639,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 103643,},[2] = {["id"] = 103644,},[3] = {["id"] = 103645,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 4,["skillPool"] = {[1] = {["id"] = 103640,},[2] = {["id"] = 103641,},[3] = {["id"] = 103642,},[4] = {["id"] = 108098,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 103646,},[2] = {["id"] = 103647,},[3] = {["id"] = 103648,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },

        [7] = { 
            -- Woodworking
            ["skillLineId"] = 80,
            [1] = {["mx"] = 10,["skillPool"] = {[1] = {["id"] = 47282,},[2] = {["id"] = 47283,},[3] = {["id"] = 47284,},[4] = {["id"] = 47285,},[5] = {["id"] = 47286,},[6] = {["id"] = 47287,},[7] = {["id"] = 48172,},[8] = {["id"] = 48173,},[9] = {["id"] = 48174,},[10] = {["id"] = 70046,},},["at"] = ABILITY_TYPE_PASSIVE,["autoGrant"] = 1,},
            [2] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 47857,},[2] = {["id"] = 47858,},[3] = {["id"] = 47859,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [3] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 48184,},[2] = {["id"] = 48185,},[3] = {["id"] = 48186,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [4] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 48178,},[2] = {["id"] = 48179,},[3] = {["id"] = 48180,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [5] = {["mx"] = 4,["skillPool"] = {[1] = {["id"] = 48181,},[2] = {["id"] = 48182,},[3] = {["id"] = 48183,},[4] = {["id"] = 58783,},},["at"] = ABILITY_TYPE_PASSIVE,},
            [6] = {["mx"] = 3,["skillPool"] = {[1] = {["id"] = 48175,},[2] = {["id"] = 48176,},[3] = {["id"] = 48177,},},["at"] = ABILITY_TYPE_PASSIVE,},
        },
    },
}
