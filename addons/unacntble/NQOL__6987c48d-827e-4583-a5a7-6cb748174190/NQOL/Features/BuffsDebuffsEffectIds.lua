NQOL = NQOL or {}
NQOL.Features = NQOL.Features or {}

local BuffsDebuffsEffectIds = {}

-- Applied effect IDs only. These are the abilityId values returned by
-- GetUnitBuffInfo/EVENT_EFFECT_CHANGED for the visible player effect.
--
-- Public source references used for this table:
-- https://esoitem.uesp.net/viewlog.php?record=minedSkills
-- https://esoitem.uesp.net/viewSkills.php
-- https://eso-hub.com/en/buffs-debuffs
-- Update 51 Minor Vexation:
-- https://esoitem.uesp.net/viewlog.php?action=view&record=minedSkills51pts&id=263403
-- Sorcery and Prophecy are retired in Update 51; their leftover mined records
-- must not create tracker rows or be treated as aliases for the merged buffs.
--
-- Additional effect variants were cross-checked against local addon source
-- tables from LuiData, Group Buff Panels, Fancy Action Bar, and BuffTracker.
--
-- Current NQOL names without a verified applied effect ID are intentionally
-- omitted for now: Damage Shield, Crowd Control Immunity, Unstoppable,
-- Invisible, and Stealth.
local EFFECTS_BY_ABILITY_ID = {
    [61549] = { tier = "Minor", baseName = "Vitality" },
    [61662] = { tier = "Minor", baseName = "Brutality" },
    [61665] = { tier = "Major", baseName = "Brutality" },
    [61666] = { tier = "Minor", baseName = "Savagery" },
    [61667] = { tier = "Major", baseName = "Savagery" },
    [61693] = { tier = "Minor", baseName = "Resolve" },
    [61694] = { tier = "Major", baseName = "Resolve" },
    [61697] = { tier = "Minor", baseName = "Fortitude" },
    [61698] = { tier = "Major", baseName = "Fortitude" },
    [61704] = { tier = "Minor", baseName = "Endurance" },
    [61705] = { tier = "Major", baseName = "Endurance" },
    [61706] = { tier = "Minor", baseName = "Intellect" },
    [61707] = { tier = "Major", baseName = "Intellect" },
    [61708] = { tier = "Minor", baseName = "Heroism" },
    [61709] = { tier = "Major", baseName = "Heroism" },
    [61710] = { tier = "Minor", baseName = "Mending" },
    [61711] = { tier = "Major", baseName = "Mending" },
    [61713] = { tier = "Major", baseName = "Vitality" },
    [61715] = { tier = "Minor", baseName = "Evasion" },
    [61716] = { tier = "Major", baseName = "Evasion" },
    [61721] = { tier = "Minor", baseName = "Protection" },
    [61722] = { tier = "Major", baseName = "Protection" },
    [61723] = { tier = "Minor", baseName = "Maim" },
    [61725] = { tier = "Major", baseName = "Maim" },
    [61726] = { tier = "Minor", baseName = "Defile" },
    [61727] = { tier = "Major", baseName = "Defile" },
    [61733] = { tier = "Minor", baseName = "Mangle" },
    [61735] = { tier = "Minor", baseName = "Expedition" },
    [61736] = { tier = "Major", baseName = "Expedition" },
    [61737] = { tier = nil, baseName = "Empower" },
    [61742] = { tier = "Minor", baseName = "Breach" },
    [61743] = { tier = "Major", baseName = "Breach" },
    [61744] = { tier = "Minor", baseName = "Berserk" },
    [61745] = { tier = "Major", baseName = "Berserk" },
    [61746] = { tier = "Minor", baseName = "Force" },
    [61747] = { tier = "Major", baseName = "Force" },
    [63569] = { tier = "Major", baseName = "Gallop" },
    [76518] = { tier = "Major", baseName = "Brutality" },
    [76537] = { tier = nil, baseName = "Empower" },
    [76617] = { tier = "Minor", baseName = "Slayer" },
    [76618] = { tier = "Minor", baseName = "Aegis" },
    [79717] = { tier = "Minor", baseName = "Vulnerability" },
    [79867] = { tier = "Minor", baseName = "Cowardice" },
    [79895] = { tier = "Minor", baseName = "Uncertainty" },
    [79907] = { tier = "Minor", baseName = "Enervation" },
    [86304] = { tier = "Minor", baseName = "Lifesteal" },
    [88401] = { tier = "Minor", baseName = "Magickasteal" },
    [88490] = { tier = "Minor", baseName = "Toughness" },
    [88758] = { tier = "Major", baseName = "Resolve" },
    [93109] = { tier = "Major", baseName = "Slayer" },
    [93120] = { tier = "Major", baseName = "Slayer" },
    [93123] = { tier = "Major", baseName = "Aegis" },
    [93125] = { tier = "Major", baseName = "Aegis" },
    [93442] = { tier = "Major", baseName = "Slayer" },
    [93444] = { tier = "Major", baseName = "Aegis" },
    [106754] = { tier = "Major", baseName = "Vulnerability" },
    [109966] = { tier = "Major", baseName = "Courage" },
    [121871] = { tier = "Major", baseName = "Slayer" },
    [135923] = { tier = "Major", baseName = "Slayer" },
    [135926] = { tier = "Major", baseName = "Aegis" },
    [137986] = { tier = "Major", baseName = "Slayer" },
    [137989] = { tier = "Major", baseName = "Aegis" },
    [140699] = { tier = "Minor", baseName = "Timidity" },
    [145975] = { tier = "Minor", baseName = "Brittle" },
    [145977] = { tier = "Major", baseName = "Brittle" },
    [147225] = { tier = "Minor", baseName = "Aegis" },
    [147226] = { tier = "Minor", baseName = "Slayer" },
    [147417] = { tier = "Minor", baseName = "Courage" },
    [147643] = { tier = "Major", baseName = "Cowardice" },
    [176991] = { tier = "Minor", baseName = "Resolve" },
    [177886] = { tier = "Major", baseName = "Slayer" },
    [179756] = { tier = "Major", baseName = "Aegis" },
    [181840] = { tier = "Minor", baseName = "Slayer" },
    [181841] = { tier = "Minor", baseName = "Aegis" },
    [186493] = { tier = "Minor", baseName = "Protection" },
    [193731] = { tier = "Major", baseName = "Aegis" },
    [194171] = { tier = "Major", baseName = "Aegis" },
    [214407] = { tier = "Major", baseName = "Slayer" },
    [263403] = { tier = "Minor", baseName = "Vexation" },
}

local EFFECT_NAMES = {}
local namesByBaseName = {}
for _, effect in pairs(EFFECTS_BY_ABILITY_ID) do
    namesByBaseName[effect.baseName] = true
end

for baseName in pairs(namesByBaseName) do
    EFFECT_NAMES[#EFFECT_NAMES + 1] = baseName
end
table.sort(EFFECT_NAMES)

function BuffsDebuffsEffectIds.GetEffectDefinition(abilityId)
    return EFFECTS_BY_ABILITY_ID[abilityId]
end

function BuffsDebuffsEffectIds.GetEffectNames()
    return EFFECT_NAMES
end

NQOL.Features.BuffsDebuffsEffectIds = BuffsDebuffsEffectIds
