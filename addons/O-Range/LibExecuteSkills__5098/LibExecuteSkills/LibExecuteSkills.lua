--[[
    LibExecuteSkills
    Author: O-Range
    Version: 1.1.0

    Community execute-skill database for Elder Scrolls Online addons.
]]

local LIB_NAME = "LibExecuteSkills"
local LIB_VERSION = 1.1

local existing = _G[LIB_NAME]
if existing and existing.version and existing.version >= LIB_VERSION then
    return
end

local LibExecuteSkills = existing or {}
LibExecuteSkills.name = LIB_NAME
LibExecuteSkills.version = LIB_VERSION
_G[LIB_NAME] = LibExecuteSkills

----------------------------------------------------------
-- Execute Skill Database
----------------------------------------------------------

local EXECUTE_SKILLS = {
    ------------------------------------------------------
    -- Nightblade
    ------------------------------------------------------
    [33386] = {
        id = 33386,
        name = "Assassin's Blade",
        class = "Nightblade",
        skillLine = "Assassination",
        category = "Class",
        executePercent = 25,
        scalingType = "flat",
    },
    [34843] = {
        id = 34843,
        name = "Killer's Blade",
        class = "Nightblade",
        skillLine = "Assassination",
        category = "Class",
        executePercent = 50,
        scalingType = "linear",
    },
    [34851] = {
        id = 34851,
        name = "Impale",
        class = "Nightblade",
        skillLine = "Assassination",
        category = "Class",
        executePercent = 25,
        scalingType = "flat",
    },

    ------------------------------------------------------
    -- Templar
    ------------------------------------------------------
    [63029] = {
        id = 63029,
        name = "Radiant Destruction",
        class = "Templar",
        skillLine = "Dawn's Wrath",
        category = "Class",
        executePercent = 50,
        scalingType = "linear",
    },
    [63044] = {
        id = 63044,
        name = "Radiant Oppression",
        class = "Templar",
        skillLine = "Dawn's Wrath",
        category = "Class",
        executePercent = 50,
        scalingType = "linear",
    },
    [63046] = {
        id = 63046,
        name = "Radiant Glory",
        class = "Templar",
        skillLine = "Dawn's Wrath",
        category = "Class",
        executePercent = 50,
        scalingType = "linear",
    },

    ------------------------------------------------------
    -- Sorcerer
    ------------------------------------------------------
    [18718] = {
        id = 18718,
        name = "Mage's Fury",
        class = "Sorcerer",
        skillLine = "Storm Calling",
        category = "Class",
        executePercent = 20,
        scalingType = "explosion",
    },
    [19123] = {
        id = 19123,
        name = "Mage's Wrath",
        class = "Sorcerer",
        skillLine = "Storm Calling",
        category = "Class",
        executePercent = 20,
        scalingType = "explosion",
    },
    [19109] = {
        id = 19109,
        name = "Endless Fury",
        class = "Sorcerer",
        skillLine = "Storm Calling",
        category = "Class",
        executePercent = 20,
        scalingType = "explosion",
    },

    ------------------------------------------------------
    -- Warden
    ------------------------------------------------------
    [85982] = {
        id = 85982,
        name = "Feral Guardian",
        class = "Warden",
        skillLine = "Animal Companions",
        category = "Class",
        executePercent = 25,
        scalingType = "flat",
    },
    [85986] = {
        id = 85986,
        name = "Eternal Guardian",
        class = "Warden",
        skillLine = "Animal Companions",
        category = "Class",
        executePercent = 25,
        scalingType = "flat",
    },
    [85990] = {
        id = 85990,
        name = "Wild Guardian",
        class = "Warden",
        skillLine = "Animal Companions",
        category = "Class",
        executePercent = 25,
        scalingType = "flat",
    },

    ------------------------------------------------------
    -- Two Handed
    ------------------------------------------------------
    [28279] = {
        id = 28279,
        name = "Reverse Slash",
        class = "Weapon",
        skillLine = "Two Handed",
        category = "Weapon",
        executePercent = 50,
        scalingType = "linear",
    },
    [38814] = {
        id = 38814,
        name = "Executioner",
        class = "Weapon",
        skillLine = "Two Handed",
        category = "Weapon",
        executePercent = 50,
        scalingType = "linear",
    },
    [38807] = {
        id = 38807,
        name = "Reverse Slice",
        class = "Weapon",
        skillLine = "Two Handed",
        category = "Weapon",
        executePercent = 50,
        scalingType = "linear",
    },

    ------------------------------------------------------
    -- Dual Wield
    ------------------------------------------------------
    [28591] = {
        id = 28591,
        name = "Whirlwind",
        class = "Weapon",
        skillLine = "Dual Wield",
        category = "Weapon",
        executePercent = 50,
        scalingType = "linear",
    },
    [38891] = {
        id = 38891,
        name = "Whirling Blades",
        class = "Weapon",
        skillLine = "Dual Wield",
        category = "Weapon",
        executePercent = 50,
        scalingType = "linear",
    },
    [38861] = {
        id = 38861,
        name = "Steel Tornado",
        class = "Weapon",
        skillLine = "Dual Wield",
        category = "Weapon",
        executePercent = 50,
        scalingType = "linear",
    },

    ------------------------------------------------------
    -- Bow
    ------------------------------------------------------
    [38660] = {
        id = 38660,
        name = "Poison Injection",
        class = "Weapon",
        skillLine = "Bow",
        category = "Weapon",
        executePercent = 50,
        scalingType = "linear",
    },
}

----------------------------------------------------------
-- Internal Helpers
----------------------------------------------------------

local function NormalizeAbilityId(abilityId)
    if abilityId == nil then
        return nil
    end

    local idType = type(abilityId)

    if idType == "number" then
        if abilityId > 0 then
            return abilityId
        end
        return nil
    end

    if idType == "string" then
        local num = tonumber(abilityId)
        if num and num > 0 then
            return num
        end
        return nil
    end

    return nil
end

local function CopyEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local copy = {}
    for k, v in pairs(entry) do
        copy[k] = v
    end
    return copy
end

local function IsValidSkillData(data)
    if type(data) ~= "table" then
        return false
    end

    if type(data.name) ~= "string" or data.name == "" then
        return false
    end

    if type(data.executePercent) ~= "number" or data.executePercent < 0 or data.executePercent > 100 then
        return false
    end

    return true
end

----------------------------------------------------------
-- Public API
----------------------------------------------------------

function LibExecuteSkills:IsExecuteSkill(abilityId)
    local id = NormalizeAbilityId(abilityId)
    if not id then
        return false
    end
    return EXECUTE_SKILLS[id] ~= nil
end

function LibExecuteSkills:GetSkillData(abilityId)
    local id = NormalizeAbilityId(abilityId)
    if not id then
        return nil
    end
    return CopyEntry(EXECUTE_SKILLS[id])
end

function LibExecuteSkills:GetExecutePercent(abilityId)
    local id = NormalizeAbilityId(abilityId)
    if not id then
        return nil
    end

    local entry = EXECUTE_SKILLS[id]
    if not entry then
        return nil
    end

    return entry.executePercent
end

function LibExecuteSkills:GetScalingType(abilityId)
    local id = NormalizeAbilityId(abilityId)
    if not id then
        return nil
    end

    local entry = EXECUTE_SKILLS[id]
    if not entry then
        return nil
    end

    return entry.scalingType
end

function LibExecuteSkills:GetAllSkills()
    local results = {}
    for id, data in pairs(EXECUTE_SKILLS) do
        results[id] = CopyEntry(data)
    end
    return results
end

function LibExecuteSkills:GetExecuteSkillIds()
    return self:GetAllSkills()
end

function LibExecuteSkills:GetSkillCount()
    local count = 0
    for _ in pairs(EXECUTE_SKILLS) do
        count = count + 1
    end
    return count
end

function LibExecuteSkills:GetSkillsByClass(className)
    if type(className) ~= "string" or className == "" then
        return {}
    end

    local results = {}
    for abilityId, data in pairs(EXECUTE_SKILLS) do
        if data.class == className then
            results[abilityId] = CopyEntry(data)
        end
    end
    return results
end

function LibExecuteSkills:GetSkillsByCategory(category)
    if type(category) ~= "string" or category == "" then
        return {}
    end

    local results = {}
    for abilityId, data in pairs(EXECUTE_SKILLS) do
        if data.category == category then
            results[abilityId] = CopyEntry(data)
        end
    end
    return results
end

function LibExecuteSkills:RegisterSkill(abilityId, data)
    local id = NormalizeAbilityId(abilityId)
    if not id then
        return false, "Invalid abilityId"
    end

    if not IsValidSkillData(data) then
        return false, "Invalid skill data table"
    end

    EXECUTE_SKILLS[id] = {
        id = id,
        name = data.name,
        class = data.class or "Unknown",
        skillLine = data.skillLine or "Unknown",
        category = data.category or "Other",
        executePercent = data.executePercent,
        scalingType = data.scalingType or "flat",
    }

    return true
end

function LibExecuteSkills:GetVersion()
    return self.version
end