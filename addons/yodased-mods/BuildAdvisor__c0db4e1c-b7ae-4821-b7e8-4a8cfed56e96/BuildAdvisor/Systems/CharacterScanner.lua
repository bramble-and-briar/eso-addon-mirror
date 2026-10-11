local BA = BuildAdvisor
BA.Scanner = {}

-- Stat constants are looked up by name so a renamed/removed enum is skipped instead of erroring.
local STATS = {
    { key = "maxHealth", const = "STAT_HEALTH_MAX", label = "Max Health" },
    { key = "maxMagicka", const = "STAT_MAGICKA_MAX", label = "Max Magicka" },
    { key = "maxStamina", const = "STAT_STAMINA_MAX", label = "Max Stamina" },
    { key = "spellDamage", const = "STAT_SPELL_POWER", label = "Spell Damage" },
    { key = "weaponDamage", const = "STAT_POWER", label = "Weapon Damage" },
    { key = "spellCrit", const = "STAT_SPELL_CRITICAL", label = "Spell Critical (rating)" },
    { key = "weaponCrit", const = "STAT_CRITICAL_STRIKE", label = "Weapon Critical (rating)" },
    { key = "spellPen", const = "STAT_SPELL_PENETRATION", label = "Spell Penetration (sheet)" },
    { key = "physPen", const = "STAT_PHYSICAL_PENETRATION", label = "Physical Penetration (sheet)" },
    { key = "spellResist", const = "STAT_SPELL_RESIST", label = "Spell Resistance" },
    { key = "physResist", const = "STAT_PHYSICAL_RESIST", label = "Physical Resistance" },
}
BA.Scanner.STATS = STATS

local CLASS_IDS = {
    dragonknight = 1, sorcerer = 2, nightblade = 3, warden = 4,
    necromancer = 5, templar = 6, arcanist = 117,
}
BA.Scanner.CLASS_IDS = CLASS_IDS

-- Set names are compared loosely: formatting codes, case and "Perfected" are ignored.
function BA.Scanner.NormalizeSetName(name)
    if not name or name == "" then return "" end
    local text = zo_strformat("<<1>>", name):lower()
    text = text:gsub("^perfected%s+", "")
    return text
end

-- Mundus boons by buff ability ID; the "Boon:" name prefix is the fallback.
-- IDs need in-game validation.
local MUNDUS_IDS = {
    [13940] = "The Warrior", [13943] = "The Mage", [13974] = "The Serpent", [13975] = "The Thief",
    [13976] = "The Lady", [13977] = "The Steed", [13978] = "The Lord", [13979] = "The Apprentice",
    [13980] = "The Ritual", [13981] = "The Lover", [13982] = "The Atronach", [13984] = "The Shadow",
    [13985] = "The Tower",
}

local ARMOR_WEIGHTS = { "light", "medium", "heavy" }

local function Format(text)
    if not text or text == "" then return "" end
    return zo_strformat("<<1>>", text)
end

-- Each section runs in pcall: console has made "public" functions private before, and
-- one failing call shouldn't lose the rest of the scan. Failures land in result.errors.
local function Section(result, name, fn)
    local ok, err = pcall(fn)
    if not ok then result.errors[name] = tostring(err) end
end

local function ScanCharacter(result)
    result.className = Format(GetUnitClass("player"))
    result.classId = GetUnitClassId("player")
    result.raceName = Format(GetUnitRace("player"))
    result.level = GetUnitLevel("player")
    result.cp = GetUnitChampionPoints("player")
    result.attributes = {
        health = GetAttributeSpentPoints(ATTRIBUTE_HEALTH),
        magicka = GetAttributeSpentPoints(ATTRIBUTE_MAGICKA),
        stamina = GetAttributeSpentPoints(ATTRIBUTE_STAMINA),
    }
end

local function ScanStats(result)
    for _, stat in ipairs(STATS) do
        local statType = _G[stat.const]
        if statType then
            local ok, value = pcall(GetPlayerStat, statType, STAT_BONUS_OPTION_APPLY_BONUS)
            if ok and value then result.stats[stat.key] = value end
        end
    end
    -- TODO: distinguish sheet penetration from skill-specific bypass and target debuffs.
end

local function ScanGear(result)
    for slot = 0, GetBagSize(BAG_WORN) - 1 do
        local link = GetItemLink(BAG_WORN, slot)
        if link and link ~= "" then
            local piece = { slot = slot, link = link, name = Format(GetItemLinkName(link)) }
            local traitType = GetItemLinkTraitInfo(link)
            if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE then
                piece.trait = GetString("SI_ITEMTRAITTYPE", traitType)
            end
            local _, enchantHeader = GetItemLinkEnchantInfo(link)
            piece.enchant = Format(enchantHeader)
            local armorType = GetItemLinkArmorType(link)
            piece.armorWeight = ARMOR_WEIGHTS[armorType]
            if piece.armorWeight then
                result.armorWeights[piece.armorWeight] = result.armorWeights[piece.armorWeight] + 1
            end
            local weaponType = GetItemLinkWeaponType(link)
            if weaponType and weaponType ~= WEAPONTYPE_NONE then
                piece.weaponType = GetString("SI_WEAPONTYPE", weaponType)
            end
            result.slots[#result.slots + 1] = piece

            local hasSet, setName, _, numNormal, maxEquipped, setId, numPerfected = GetItemLinkSetInfo(link, true)
            if hasSet then
                local key = BA.Scanner.NormalizeSetName(setName)
                local equipped = (numNormal or 0) + (numPerfected or 0)
                local entry = result.sets[key]
                if not entry then
                    entry = { name = Format(setName), setId = setId, equipped = 0, max = maxEquipped }
                    result.sets[key] = entry
                end
                -- The API already reports the active count for the set, so keep the highest seen.
                entry.equipped = zo_max(entry.equipped, equipped)
            end
        end
    end
end

local function ScanMundus(result)
    for i = 1, GetNumBuffs("player") do
        local buffName, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        local mundus = MUNDUS_IDS[abilityId]
        if not mundus and buffName and buffName:find("^Boon:") then
            mundus = Format(buffName:gsub("^Boon:%s*", ""))
        end
        if mundus then result.mundus[#result.mundus + 1] = mundus end
    end
end

-- Slotted champion stars (the champion bar has 12 slots: 4 per discipline).
local function ScanChampion(result)
    result.cpEarned = GetPlayerChampionPointsEarned()
    for slot = 1, 12 do
        local skillId = GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION)
        if skillId and skillId ~= 0 then
            result.champion[#result.champion + 1] = {
                id = skillId,
                name = Format(GetChampionSkillName(skillId)),
                points = GetNumPointsSpentOnChampionSkill(skillId),
            }
        end
    end
end

-- Skills on both bars: slots 3-7 are skills, 8 is the ultimate.
local function ScanSkills(result)
    for _, bar in ipairs({ { key = "front", category = HOTBAR_CATEGORY_PRIMARY }, { key = "back", category = HOTBAR_CATEGORY_BACKUP } }) do
        local skills = {}
        for slot = 3, 8 do
            local abilityId = GetSlotBoundId(slot, bar.category)
            if abilityId and abilityId ~= 0 then
                skills[#skills + 1] = { id = abilityId, name = Format(GetAbilityName(abilityId)), ultimate = (slot == 8) }
            end
        end
        result.bars[bar.key] = skills
    end
end

function BA.Scanner:Snapshot()
    local result = {
        className = "Unknown", classId = 0, raceName = "Unknown", level = 0, cp = 0, cpEarned = 0,
        attributes = {}, stats = {}, slots = {}, sets = {},
        armorWeights = { light = 0, medium = 0, heavy = 0 },
        mundus = {}, champion = {}, bars = { front = {}, back = {} },
        errors = {},
    }
    Section(result, "character", function() ScanCharacter(result) end)
    Section(result, "stats", function() ScanStats(result) end)
    Section(result, "gear", function() ScanGear(result) end)
    Section(result, "mundus", function() ScanMundus(result) end)
    Section(result, "champion", function() ScanChampion(result) end)
    Section(result, "skills", function() ScanSkills(result) end)
    return result
end

function BA.Scanner:MatchesClass(snapshot, className)
    local wanted = CLASS_IDS[className or ""]
    if not wanted or not snapshot or snapshot.classId == 0 then return nil end
    return snapshot.classId == wanted
end

function BA.Scanner:GetEquippedCount(snapshot, setData)
    if not snapshot or not setData then return 0 end
    if setData.setId then
        for _, set in pairs(snapshot.sets) do
            if set.setId == setData.setId then return set.equipped end
        end
    end
    local set = snapshot.sets[BA.Scanner.NormalizeSetName(setData.name)]
    return set and set.equipped or 0
end
