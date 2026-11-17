local A = OneCraft.Enchanting
-- Rune IDs and glyph IDs are game facts cross-checked against LibLazyCrafting.
-- No library source is bundled or required. See Credits.txt.
A.levels = {
    {level = 1, positive = 45855, negative = 45817},
    {level = 5, positive = 45856, negative = 45818},
    {level = 10, positive = 45857, negative = 45819},
    {level = 15, positive = 45806, negative = 45820},
    {level = 20, positive = 45807, negative = 45821},
    {level = 25, positive = 45808, negative = 45822},
    {level = 30, positive = 45809, negative = 45823},
    {level = 35, positive = 45810, negative = 45824},
    {level = 40, positive = 45811, negative = 45825},
    {cp = 10, positive = 45812, negative = 45826},
    {cp = 30, positive = 45813, negative = 45827},
    {cp = 50, positive = 45814, negative = 45828},
    {cp = 70, positive = 45815, negative = 45829},
    {cp = 100, positive = 45816, negative = 45830},
    {cp = 150, positive = 64509, negative = 64508},
    {cp = 160, positive = 68341, negative = 68340},
}
A.aspects = {45850, 45851, 45852, 45853, 45854}
A.equipmentTypes = {
    {key = "armor", itemType = ITEMTYPE_GLYPH_ARMOR, glyphId = 26580},
    {key = "weapon", itemType = ITEMTYPE_GLYPH_WEAPON, glyphId = 26848},
    {key = "jewelry", itemType = ITEMTYPE_GLYPH_JEWELRY, glyphId = 26581},
}
-- Essence ID, negative effect/glyph/equipment, positive effect/glyph/equipment.
local rows = {
    {45831, "absorbHealth", 43573, "weapon", "health", 26580, "armor"},
    {45832, "absorbMagicka", 45868, "weapon", "magicka", 26582, "armor"},
    {45833, "absorbStamina", 45867, "weapon", "stamina", 26588, "armor"},
    {45834, "decreaseHealth", 45869, "weapon", "healthRecovery", 26581, "jewelry"},
    {45835, "reduceMagicka", 45870, "jewelry", "magickaRecovery", 26583, "jewelry"},
    {45836, "reduceStamina", 45871, "jewelry", "staminaRecovery", 26589, "jewelry"},
    {45837, "poisonResist", 26586, "jewelry", "poison", 26587, "weapon"},
    {45838, "flameResist", 26849, "jewelry", "flame", 26848, "weapon"},
    {45839, "frostResist", 5364, "jewelry", "frost", 5365, "weapon"},
    {45840, "shockResist", 43570, "jewelry", "shock", 26844, "weapon"},
    {45841, "diseaseResist", 26847, "jewelry", "disease", 26841, "weapon"},
    {45842, "crushing", 26845, "weapon", "hardening", 5366, "weapon"},
    {45843, "weakening", 26591, "weapon", "weaponDamage", 54484, "weapon"},
    {45846, "potionSpeed", 45875, "jewelry", "potionBoost", 45874, "jewelry"},
    {45847, "physicalResist", 45885, "jewelry", "physicalHarm", 45883, "jewelry"},
    {45848, "spellResist", 45886, "jewelry", "magicalHarm", 45884, "jewelry"},
    {45849, "shielding", 45873, "jewelry", "bashing", 45872, "jewelry"},
    {68342, "prismaticOnslaught", 68344, "weapon", "prismaticDefense", 68343, "armor"},
    {166045, "reduceSkillCost", 166046, "jewelry", "prismaticRecovery", 166047, "jewelry"},
}
A.effects, A.effectList, A.runeTypes = {}, {}, {}
for _, level in ipairs(A.levels) do
    A.runeTypes[level.positive], A.runeTypes[level.negative] = ENCHANTING_RUNE_POTENCY, ENCHANTING_RUNE_POTENCY
end
for _, id in ipairs(A.aspects) do A.runeTypes[id] = ENCHANTING_RUNE_ASPECT end
for _, row in ipairs(rows) do
    A.runeTypes[row[1]] = ENCHANTING_RUNE_ESSENCE
    for _, column in ipairs({2, 5}) do
        local effect = {key = row[column], itemId = row[column + 1], equipment = row[column + 2],
            essence = row[1], polarity = column == 2 and "negative" or "positive"}
        A.effects[effect.key] = effect
        A.effectList[#A.effectList + 1] = effect
    end
end
