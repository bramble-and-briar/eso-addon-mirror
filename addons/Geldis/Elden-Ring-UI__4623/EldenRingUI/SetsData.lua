EldenRingUI = EldenRingUI or {}

EldenRingUI.COOLDOWN_DATA = {
    ["Roar of Alkosh"] = {
        abilityId = 78835,
        result = 2240,
        cooldownMs = 10000,
        isCooldown = false,
    },
    ["Arkasis's Genius"] = {
        abilityId = 142660,
        result = 2240,
        cooldownMs = 30000,
        isCooldown = true,
    },
    ["Ansuul's Torment"] = {
        abilityId = 194105,
        result = 2240,
        cooldownMs = 30000,
        isCooldown = false,
    },
    ["Sul-Xan's Torment"] = {
        abilityId = 154737,
        result = 2240,
        cooldownMs = 30000,
        isCooldown = false,
        secondary = {
            abilityId = 157738,
            result = 2245,
            fallbackMs = 6000,
        },
    },
    ["Mechanical Acuity"] = {
        abilityId = 99204,
        isEffectChanged = true,
        cooldownTrigger = {
            abilityId = 164087,
            result = 2245,
            cooldownMs = 25000,
        },
    },
    ["War Machine"] = {
        abilityId = 93109,
        isEffectChanged = true,
    },
    ["Huntsman's Warmask"] = {
        abilityId = 252050,
        isEffectChanged = true,
    },
}