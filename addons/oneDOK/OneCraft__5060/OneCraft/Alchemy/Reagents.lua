local A = OneCraft.Alchemy
-- Update 51 game facts, cross-checked against LibAlchemy 2.7's public data.
-- No library code is included or executed. See Credits.txt for the reference.
local rows = {
    {30148, "RavageMagicka", "HealAbsorption", "RestoreHealth", "Invisible"},
    {30160, "IncreaseSpellResist", "RestoreHealth", "Mending", "RestoreMagicka"},
    {77585, "RestoreHealth", "DamageShield", "LingeringHealth", "Vitality"},
    {30164, "RestoreHealth", "RestoreMagicka", "RestoreStamina", "Unstoppable"},
    {30163, "IncreaseArmor", "RestoreHealth", "Cowardice", "RestoreStamina"},
    {30158, "Force", "RestoreMagicka", "Breach", "Critical"},
    {30161, "RestoreMagicka", "IncreasePower", "RavageHealth", "Detection"},
    {30162, "IncreasePower", "RestoreStamina", "Fracture", "Critical"},
    {30157, "RestoreStamina", "IncreasePower", "HealAbsorption", "Speed"},
    {30153, "Enervation", "Speed", "Invisible", "Unstoppable"},
    {77583, "Breach", "Protection", "Vitality", "IncreaseArmor"},
    {150789, "Heroism", "Invisible", "Vulnerability", "Vitality"},
    {150731, "LingeringHealth", "Heroism", "RestoreStamina", "Defile"},
    {150671, "RestoreMagicka", "Uncertainty", "Heroism", "Speed"},
    {30151, "RavageHealth", "RavageMagicka", "RavageStamina", "Entrapment"},
    {77587, "RavageStamina", "GradualRavageHealth", "Vulnerability", "Vitality"},
    {30156, "Cowardice", "RavageStamina", "IncreaseArmor", "Enervation"},
    {30155, "RavageStamina", "RestoreHealth", "Hindrance", "Cowardice"},
    {77591, "IncreaseSpellResist", "Protection", "IncreaseArmor", "Defile"},
    {77590, "RavageHealth", "GradualRavageHealth", "Protection", "Defile"},
    {30165, "RavageHealth", "Uncertainty", "Invisible", "HealAbsorption"},
    {77589, "Vexation", "Speed", "Vulnerability", "LingeringHealth"},
    {77584, "Hindrance", "Invisible", "DamageShield", "Defile"},
    {30149, "Fracture", "RavageHealth", "Force", "RavageStamina"},
    {77581, "Fracture", "Uncertainty", "Detection", "Mending"},
    {30152, "Breach", "IncreasePower", "RavageHealth", "RavageMagicka"},
    {30166, "RestoreHealth", "Critical", "Entrapment", "DamageShield"},
    {30154, "Enervation", "RavageMagicka", "IncreaseSpellResist", "Detection"},
    {30159, "Critical", "Hindrance", "Detection", "Unstoppable"},
    {139020, "IncreaseSpellResist", "Hindrance", "Vulnerability", "Defile"},
    {139019, "Mending", "Speed", "Vitality", "Protection"},
    {150672, "Timidity", "Force", "GradualRavageHealth", "RestoreHealth"},
    {150670, "Timidity", "RavageHealth", "RestoreMagicka", "Protection"},
    {150669, "Timidity", "RavageMagicka", "Vexation", "Detection"},
    {224357, "Heroism", "IncreasePower", "Mending", "DamageShield"},
    {224358, "Defile", "HealAbsorption", "Cowardice", "Entrapment"},
    {224359, "Heroism", "RestoreStamina", "Force", "Detection"},
    {224360, "Vexation", "HealAbsorption", "Defile", "Breach"},
}
A.opposites = {}
local pairsOfEffects = {
    {"RestoreHealth", "RavageHealth"}, {"RestoreMagicka", "RavageMagicka"},
    {"RestoreStamina", "RavageStamina"}, {"IncreaseSpellResist", "Breach"},
    {"IncreaseArmor", "Fracture"}, {"IncreasePower", "Cowardice"},
    {"Critical", "Uncertainty"}, {"Force", "Enervation"},
    {"Unstoppable", "Entrapment"}, {"Detection", "Invisible"},
    {"Speed", "Hindrance"}, {"Protection", "Vulnerability"},
    {"LingeringHealth", "GradualRavageHealth"}, {"Vitality", "Defile"},
    {"Heroism", "Timidity"}, {"DamageShield", "HealAbsorption"}, {"Mending", "Vexation"},
}
for _, pair in ipairs(pairsOfEffects) do
    A.opposites[pair[1]], A.opposites[pair[2]] = pair[2], pair[1]
end
for _, row in ipairs(rows) do
    A.reagents[row[1]] = {row[2], row[3], row[4], row[5]}
end
-- The encoded alchemy result uses these game effect IDs, not UI row indices.
A.effectIds = {
    "RestoreHealth", "RavageHealth", "RestoreMagicka", "RavageMagicka",
    "RestoreStamina", "RavageStamina", "IncreaseSpellResist", "Breach",
    "IncreaseArmor", "Fracture", "IncreasePower", "Cowardice",
    "IncreasePower", "Cowardice", "Critical", "Uncertainty", "Critical", "Enervation",
    "Unstoppable", "Entrapment", "Detection", "Invisible", "Speed", "Hindrance",
    "Protection", "Vulnerability", "LingeringHealth", "GradualRavageHealth",
    "Vitality", "Defile", "Heroism", "Timidity", "DamageShield", "HealAbsorption",
    "Force", "Enervation", "Mending", "Vexation",
}

-- Built-in game asset identifiers, verified against Potion Maker 5.11.0's
-- Update 51 effect controls. Availability does not depend on character knowledge.
A.effectIconFiles = {
    RestoreHealth = "crafting_alchemy_trait_restorehealth.dds",
    RavageHealth = "crafting_alchemy_trait_ravagehealth.dds",
    RestoreMagicka = "crafting_alchemy_trait_restoremagicka.dds",
    RavageMagicka = "crafting_alchemy_trait_ravagemagicka.dds",
    RestoreStamina = "crafting_alchemy_trait_restorestamina.dds",
    RavageStamina = "crafting_alchemy_trait_ravagestamina.dds",
    IncreaseSpellResist = "crafting_alchemy_trait_increasespellresist.dds",
    Breach = "crafting_alchemy_trait_lowerspellresist.dds",
    IncreaseArmor = "crafting_alchemy_trait_increasearmor.dds",
    Fracture = "crafting_alchemy_trait_lowerarmor.dds",
    IncreasePower = "crafting_alchemy_trait_increasespellpower.dds",
    Cowardice = "crafting_alchemy_trait_lowerspellpower.dds",
    Critical = "crafting_alchemy_trait_spellcrit.dds",
    Uncertainty = "crafting_alchemy_trait_lowerspellcrit.dds",
    Force = "crafting_alchemy_trait_increaseweaponpower.dds",
    Enervation = "crafting_alchemy_trait_lowerweaponpower.dds",
    Unstoppable = "crafting_alchemy_trait_unstoppable.dds",
    Entrapment = "crafting_alchemy_trait_stun.dds",
    Detection = "crafting_alchemy_trait_detection.dds",
    Invisible = "crafting_alchemy_trait_invisible.dds",
    Speed = "crafting_alchemy_trait_speed.dds",
    Hindrance = "crafting_alchemy_trait_reducespeed.dds",
    Protection = "crafting_poison_trait_protection.dds",
    Vulnerability = "crafting_poison_trait_damage.dds",
    LingeringHealth = "crafting_poison_trait_hot.dds",
    GradualRavageHealth = "crafting_poison_trait_dot.dds",
    Vitality = "crafting_poison_trait_increasehealing.dds",
    Defile = "crafting_poison_trait_decreasehealing.dds",
    Heroism = "crafting_alchemy_trait_heroism.dds",
    Timidity = "crafting_alchemy_trait_timidity.dds",
    DamageShield = "crafting_alchemy_trait_damageshield.dds",
    HealAbsorption = "crafting_alchemy_trait_healabsorption.dds",
    Mending = "crafting_alchemy_trait_mending.dds",
    Vexation = "crafting_alchemy_trait_reducedhealing.dds",
}

local positiveEffects = {
    RestoreHealth = true, RestoreMagicka = true, RestoreStamina = true,
    IncreasePower = true, Critical = true, IncreaseSpellResist = true,
    IncreaseArmor = true, Force = true, Unstoppable = true, Detection = true,
    Invisible = true, Speed = true, Protection = true, LingeringHealth = true,
    Vitality = true, Heroism = true, DamageShield = true, Mending = true,
}
local popularEffects = {
    RestoreHealth = 1, RestoreMagicka = 2, RestoreStamina = 3,
    IncreasePower = 4, Critical = 5,
}

local effectKeysByIcon = {}
for key, file in pairs(A.effectIconFiles) do
    effectKeysByIcon[file:lower()] = key
end

function A.UpdateEffectName(name, texture)
    -- Game trait order need not match the recipe database. Identify the effect
    -- by its normal icon; never assign localized names by reagent trait index.
    local file = type(texture) == "string" and texture:lower():match("([^/\\]+)$")
    local key = file and effectKeysByIcon[file]
    if key and A.effects[key] and type(name) == "string" and name ~= "" then
        A.effects[key].name = name
    end
end

function A.BuildEffectMetadata()
    local languageIndex = GetCVar("language.2") == "ru" and 2 or 1
    for key, names in pairs(A.effectNames) do
        A.effects[key] = {key = key, name = OneCraft.Translate(names[languageIndex]),
            positive = positiveEffects[key] == true, priority = popularEffects[key] or math.huge,
            icon = "EsoUI/Art/Icons/Alchemy/" .. A.effectIconFiles[key]}
    end
    for id, key in ipairs(A.effectIds) do A.effects[key].id = id end
end
