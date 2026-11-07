--[[
    LibFights - Constants
    All lookup tables are built from the game's own global constants and guarded,
    so a renamed/removed constant on a future API version never breaks loading.
]]

local LF = LibFights
local Const = {}
LF.Const = Const

local function G(name) return _G[name] end
Const.G = G

local function MakeSet(prefix, names)
    local set = {}
    for i = 1, #names do
        local v = _G[prefix .. names[i]]
        if v ~= nil then set[v] = true end
    end
    return set
end

local function MakeNameMap(prefix, names)
    local byValue, byName = {}, {}
    for i = 1, #names do
        local v = _G[prefix .. names[i]]
        if v ~= nil then
            if byValue[v] == nil then byValue[v] = names[i] end
            byName[names[i]] = v
        end
    end
    return byValue, byName
end

-- ---------------------------------------------------------------------------
-- Action results
-- ---------------------------------------------------------------------------
local RESULT_LIST = {
    "DAMAGE", "CRITICAL_DAMAGE", "DOT_TICK", "DOT_TICK_CRITICAL",
    "HEAL", "CRITICAL_HEAL", "HOT_TICK", "HOT_TICK_CRITICAL",
    "DAMAGE_SHIELDED", "BLOCKED_DAMAGE", "BLOCKED", "DODGED", "MISS", "PARRIED",
    "ABSORBED", "REFLECTED", "IMMUNE", "RESIST", "PARTIAL_RESIST", "DEFENDED",
    "INTERRUPT", "STUNNED", "KNOCKBACK", "FEARED", "SNARED", "ROOTED", "SILENCED",
    "STAGGERED", "LEVITATED", "DISORIENTED", "OFFBALANCE", "CHARMED",
    "DIED", "DIED_XP", "KILLING_BLOW", "RESURRECT", "REINCARNATING",
    "BEGIN", "BEGIN_CHANNEL", "EFFECT_GAINED", "EFFECT_GAINED_DURATION", "EFFECT_FADED",
    "POWER_ENERGIZE", "POWER_DRAIN", "FALL_DAMAGE", "FALLING",
    "PRECISE_DAMAGE", "WRECKING_DAMAGE", "CANT_SEE_TARGET", "TARGET_DEAD",
    "TARGET_OUT_OF_RANGE", "TARGET_NOT_IN_VIEW", "INSUFFICIENT_RESOURCE", "BAD_TARGET",
    "KILLED_BY_SUBZONE", "SOUL_GEM_RESURRECTION_ACCEPTED", "HEAL_ABSORBED",
}
Const.RESULT_NAME, Const.RESULT = MakeNameMap("ACTION_RESULT_", RESULT_LIST)

Const.DAMAGE_RESULTS = MakeSet("ACTION_RESULT_", { "DAMAGE", "CRITICAL_DAMAGE", "DOT_TICK", "DOT_TICK_CRITICAL", "BLOCKED_DAMAGE", "FALL_DAMAGE", "PRECISE_DAMAGE", "WRECKING_DAMAGE" })
Const.HEAL_RESULTS   = MakeSet("ACTION_RESULT_", { "HEAL", "CRITICAL_HEAL", "HOT_TICK", "HOT_TICK_CRITICAL" })
Const.CRIT_RESULTS   = MakeSet("ACTION_RESULT_", { "CRITICAL_DAMAGE", "DOT_TICK_CRITICAL", "CRITICAL_HEAL", "HOT_TICK_CRITICAL" })
Const.TICK_RESULTS   = MakeSet("ACTION_RESULT_", { "DOT_TICK", "DOT_TICK_CRITICAL", "HOT_TICK", "HOT_TICK_CRITICAL" })
Const.SHIELD_RESULTS = MakeSet("ACTION_RESULT_", { "DAMAGE_SHIELDED" })
Const.AVOID_RESULTS  = MakeSet("ACTION_RESULT_", { "DODGED", "MISS", "PARRIED", "BLOCKED", "ABSORBED", "REFLECTED", "IMMUNE", "RESIST", "DEFENDED" })
Const.CC_RESULTS     = MakeSet("ACTION_RESULT_", { "INTERRUPT", "STUNNED", "KNOCKBACK", "FEARED", "SNARED", "ROOTED", "SILENCED", "STAGGERED", "LEVITATED", "DISORIENTED", "OFFBALANCE", "CHARMED" })
Const.DEATH_RESULTS  = MakeSet("ACTION_RESULT_", { "DIED", "DIED_XP", "KILLING_BLOW" })
Const.POWER_RESULTS  = MakeSet("ACTION_RESULT_", { "POWER_ENERGIZE", "POWER_DRAIN" })
Const.CAST_RESULTS   = MakeSet("ACTION_RESULT_", { "BEGIN", "BEGIN_CHANNEL" })
Const.EFFECT_RESULTS = MakeSet("ACTION_RESULT_", { "EFFECT_GAINED", "EFFECT_GAINED_DURATION", "EFFECT_FADED" })

-- result value -> category string
Const.CATEGORY = {}
local function Assign(set, cat)
    for v in pairs(set) do
        if Const.CATEGORY[v] == nil then Const.CATEGORY[v] = cat end
    end
end
Assign(Const.SHIELD_RESULTS, "shield")
Assign(Const.DAMAGE_RESULTS, "damage")
Assign(Const.HEAL_RESULTS, "heal")
Assign(Const.AVOID_RESULTS, "avoid")
Assign(Const.CC_RESULTS, "cc")
Assign(Const.DEATH_RESULTS, "death")
Assign(Const.POWER_RESULTS, "power")
Assign(Const.CAST_RESULTS, "cast")
Assign(Const.EFFECT_RESULTS, "effect")

Const.CATEGORIES = { "damage", "heal", "shield", "avoid", "cc", "death", "power", "cast", "effect", "other" }

function Const.GetResultCategory(result)
    return Const.CATEGORY[result] or "other"
end

function Const.GetResultName(result)
    return Const.RESULT_NAME[result] or tostring(result)
end

-- ---------------------------------------------------------------------------
-- Damage types
-- ---------------------------------------------------------------------------
local DAMAGE_TYPE_LIST = { "NONE", "GENERIC", "PHYSICAL", "FIRE", "SHOCK", "OBLIVION", "COLD", "EARTH", "MAGIC", "DROWN", "DISEASE", "POISON", "BLEED" }
Const.DAMAGE_TYPE_NAME, Const.DAMAGE_TYPE = MakeNameMap("DAMAGE_TYPE_", DAMAGE_TYPE_LIST)
Const.SPELL_DAMAGE_TYPES    = MakeSet("DAMAGE_TYPE_", { "FIRE", "SHOCK", "COLD", "MAGIC" })
Const.PHYSICAL_DAMAGE_TYPES = MakeSet("DAMAGE_TYPE_", { "PHYSICAL", "POISON", "DISEASE", "BLEED" })

function Const.GetDamageTypeName(dt)
    if dt == nil then return "?" end
    local s = GetString("SI_DAMAGETYPE", dt)
    if s and s ~= "" then return s end
    return Const.DAMAGE_TYPE_NAME[dt] or tostring(dt)
end

-- ---------------------------------------------------------------------------
-- Combat unit types
-- ---------------------------------------------------------------------------
local UNIT_TYPE_LIST = { "NONE", "PLAYER", "PLAYER_PET", "GROUP", "OTHER", "TARGET_DUMMY", "PLAYER_COMPANION" }
Const.UNIT_TYPE_NAME, Const.UNIT_TYPE = MakeNameMap("COMBAT_UNIT_TYPE_", UNIT_TYPE_LIST)
Const.UT_PLAYER    = G("COMBAT_UNIT_TYPE_PLAYER")
Const.UT_PET       = G("COMBAT_UNIT_TYPE_PLAYER_PET")
Const.UT_GROUP     = G("COMBAT_UNIT_TYPE_GROUP")
Const.UT_DUMMY     = G("COMBAT_UNIT_TYPE_TARGET_DUMMY")
Const.UT_COMPANION = G("COMBAT_UNIT_TYPE_PLAYER_COMPANION")
Const.UT_OTHER     = G("COMBAT_UNIT_TYPE_OTHER")
Const.UT_NONE      = G("COMBAT_UNIT_TYPE_NONE")

function Const.IsPlayerOrPet(unitType)
    return unitType == Const.UT_PLAYER or (Const.UT_PET ~= nil and unitType == Const.UT_PET)
end

-- ---------------------------------------------------------------------------
-- Power / combat mechanic types (renamed from POWERTYPE_* to COMBAT_MECHANIC_FLAGS_*)
-- ---------------------------------------------------------------------------
Const.POWER_HEALTH   = G("COMBAT_MECHANIC_FLAGS_HEALTH")   or G("POWERTYPE_HEALTH")
Const.POWER_MAGICKA  = G("COMBAT_MECHANIC_FLAGS_MAGICKA")  or G("POWERTYPE_MAGICKA")
Const.POWER_STAMINA  = G("COMBAT_MECHANIC_FLAGS_STAMINA")  or G("POWERTYPE_STAMINA")
Const.POWER_ULTIMATE = G("COMBAT_MECHANIC_FLAGS_ULTIMATE") or G("POWERTYPE_ULTIMATE")
Const.POWER_NAME = {}
if Const.POWER_HEALTH   then Const.POWER_NAME[Const.POWER_HEALTH]   = "Health"   end
if Const.POWER_MAGICKA  then Const.POWER_NAME[Const.POWER_MAGICKA]  = "Magicka"  end
if Const.POWER_STAMINA  then Const.POWER_NAME[Const.POWER_STAMINA]  = "Stamina"  end
if Const.POWER_ULTIMATE then Const.POWER_NAME[Const.POWER_ULTIMATE] = "Ultimate" end

function Const.GetPowerName(pt)
    return Const.POWER_NAME[pt] or tostring(pt)
end

-- ---------------------------------------------------------------------------
-- Effects
-- ---------------------------------------------------------------------------
Const.EFFECT_GAINED       = G("EFFECT_RESULT_GAINED")
Const.EFFECT_FADED        = G("EFFECT_RESULT_FADED")
Const.EFFECT_UPDATED      = G("EFFECT_RESULT_UPDATED")
Const.EFFECT_FULL_REFRESH = G("EFFECT_RESULT_FULL_REFRESH")
Const.EFFECT_TRANSFER     = G("EFFECT_RESULT_TRANSFER")
Const.BUFF                = G("BUFF_EFFECT_TYPE_BUFF")
Const.DEBUFF              = G("BUFF_EFFECT_TYPE_DEBUFF")

-- ---------------------------------------------------------------------------
-- Action bar
-- ---------------------------------------------------------------------------
Const.LIGHT_ATTACK_SLOT = 1
Const.HEAVY_ATTACK_SLOT = 2
Const.FIRST_SKILL_SLOT  = (G("ACTION_BAR_FIRST_NORMAL_SLOT_INDEX") and G("ACTION_BAR_FIRST_NORMAL_SLOT_INDEX") + 1) or 3
Const.ULTIMATE_SLOT     = (G("ACTION_BAR_ULTIMATE_SLOT_INDEX") and G("ACTION_BAR_ULTIMATE_SLOT_INDEX") + 1) or 8
Const.HOTBAR_PRIMARY    = G("HOTBAR_CATEGORY_PRIMARY")
Const.HOTBAR_BACKUP     = G("HOTBAR_CATEGORY_BACKUP")
Const.HOTBAR_CHAMPION   = G("HOTBAR_CATEGORY_CHAMPION")
Const.SLOT_TYPE_LIGHT   = G("ACTION_SLOT_TYPE_LIGHT_ATTACK")
Const.SLOT_TYPE_HEAVY   = G("ACTION_SLOT_TYPE_HEAVY_ATTACK")
Const.WEAPON_PAIR_MAIN   = G("ACTIVE_WEAPON_PAIR_MAIN") or 1
Const.WEAPON_PAIR_BACKUP = G("ACTIVE_WEAPON_PAIR_BACKUP") or 2

-- ---------------------------------------------------------------------------
-- Equipment slots
-- ---------------------------------------------------------------------------
local EQUIP_LIST = {
    { "EQUIP_SLOT_HEAD", "Head" }, { "EQUIP_SLOT_NECK", "Neck" }, { "EQUIP_SLOT_CHEST", "Chest" },
    { "EQUIP_SLOT_SHOULDERS", "Shoulders" }, { "EQUIP_SLOT_MAIN_HAND", "Main Hand" },
    { "EQUIP_SLOT_OFF_HAND", "Off Hand" }, { "EQUIP_SLOT_WAIST", "Waist" }, { "EQUIP_SLOT_LEGS", "Legs" },
    { "EQUIP_SLOT_FEET", "Feet" }, { "EQUIP_SLOT_RING1", "Ring 1" }, { "EQUIP_SLOT_RING2", "Ring 2" },
    { "EQUIP_SLOT_HAND", "Hands" }, { "EQUIP_SLOT_BACKUP_MAIN", "Backup Main Hand" },
    { "EQUIP_SLOT_BACKUP_OFF", "Backup Off Hand" }, { "EQUIP_SLOT_POISON", "Poison" },
    { "EQUIP_SLOT_BACKUP_POISON", "Backup Poison" },
}
Const.EQUIP_SLOTS = {}
Const.EQUIP_SLOT_NAME = {}
for i = 1, #EQUIP_LIST do
    local key, name = EQUIP_LIST[i][1], EQUIP_LIST[i][2]
    local id = G(key)
    if id ~= nil then
        local entry = {
            id = id, key = key, name = name,
            isBackup = key:find("BACKUP", 1, true) ~= nil,
            isWeapon = (key == "EQUIP_SLOT_MAIN_HAND" or key == "EQUIP_SLOT_OFF_HAND"
                or key == "EQUIP_SLOT_BACKUP_MAIN" or key == "EQUIP_SLOT_BACKUP_OFF"),
            isPoison = key:find("POISON", 1, true) ~= nil,
        }
        Const.EQUIP_SLOTS[#Const.EQUIP_SLOTS + 1] = entry
        Const.EQUIP_SLOT_NAME[id] = name
    end
end

-- ---------------------------------------------------------------------------
-- Item set types
-- ---------------------------------------------------------------------------
local SET_TYPE_LIST = { "NONE", "WORLD", "DUNGEON", "TRIAL", "ARENA", "MONSTER", "CRAFTED", "CYRODIIL", "IMPERIAL_CITY", "BATTLEGROUND", "MYTHIC", "CLASS", "OVERLAND", "WEAPON", "SPECIAL", "ENDLESS_ARCHIVE" }
Const.SET_TYPE_NAME = MakeNameMap("ITEM_SET_TYPE_", SET_TYPE_LIST)

-- ---------------------------------------------------------------------------
-- Player stats (GetPlayerStat)
-- ---------------------------------------------------------------------------
local STAT_LIST = {
    { "maxHealth", "STAT_HEALTH_MAX", "Max Health" },
    { "maxMagicka", "STAT_MAGICKA_MAX", "Max Magicka" },
    { "maxStamina", "STAT_STAMINA_MAX", "Max Stamina" },
    { "healthRegenCombat", "STAT_HEALTH_REGEN_COMBAT", "Health Recovery (combat)" },
    { "magickaRegenCombat", "STAT_MAGICKA_REGEN_COMBAT", "Magicka Recovery (combat)" },
    { "staminaRegenCombat", "STAT_STAMINA_REGEN_COMBAT", "Stamina Recovery (combat)" },
    { "healthRegenIdle", "STAT_HEALTH_REGEN_IDLE", "Health Recovery (idle)" },
    { "magickaRegenIdle", "STAT_MAGICKA_REGEN_IDLE", "Magicka Recovery (idle)" },
    { "staminaRegenIdle", "STAT_STAMINA_REGEN_IDLE", "Stamina Recovery (idle)" },
    { "spellPower", "STAT_SPELL_POWER", "Spell Damage" },
    { "weaponPower", "STAT_POWER", "Weapon Damage" },
    { "weaponAndSpellDamage", "STAT_WEAPON_AND_SPELL_DAMAGE", "Weapon & Spell Damage" },
    { "spellCritical", "STAT_SPELL_CRITICAL", "Spell Critical" },
    { "weaponCritical", "STAT_CRITICAL_STRIKE", "Weapon Critical" },
    { "criticalChance", "STAT_CRITICAL_CHANCE", "Critical Chance" },
    { "spellPenetration", "STAT_SPELL_PENETRATION", "Spell Penetration" },
    { "physicalPenetration", "STAT_PHYSICAL_PENETRATION", "Physical Penetration" },
    { "spellResist", "STAT_SPELL_RESIST", "Spell Resistance" },
    { "physicalResist", "STAT_PHYSICAL_RESIST", "Physical Resistance" },
    { "criticalResistance", "STAT_CRITICAL_RESISTANCE", "Critical Resistance" },
    { "armorRating", "STAT_ARMOR_RATING", "Armor Rating" },
    { "attackPower", "STAT_ATTACK_POWER", "Attack Power" },
    { "mitigation", "STAT_MITIGATION", "Mitigation" },
    { "spellMitigation", "STAT_SPELL_MITIGATION", "Spell Mitigation" },
    { "block", "STAT_BLOCK", "Block" },
    { "dodge", "STAT_DODGE", "Dodge" },
    { "miss", "STAT_MISS", "Miss" },
    { "parry", "STAT_PARRY", "Parry" },
    { "healingTaken", "STAT_HEALING_TAKEN", "Healing Taken" },
    { "healingDone", "STAT_HEALING_DONE", "Healing Done" },
    { "damageDone", "STAT_DAMAGE_DONE", "Damage Done" },
    { "damageTaken", "STAT_DAMAGE_TAKEN", "Damage Taken" },
}
Const.STATS = {}
Const.STAT_LABEL = {}
for i = 1, #STAT_LIST do
    local key, global, label = STAT_LIST[i][1], STAT_LIST[i][2], STAT_LIST[i][3]
    local id = G(global)
    if id ~= nil then
        Const.STATS[#Const.STATS + 1] = { key = key, id = id, global = global, label = label }
    end
    Const.STAT_LABEL[key] = label
end
-- derived (computed by LibFights, not GetPlayerStat)
Const.STAT_LABEL.spellCritPct = "Spell Crit %"
Const.STAT_LABEL.weaponCritPct = "Weapon Crit %"
Const.STAT_LABEL.spellResistPct = "Spell Resist Mitigation %"
Const.STAT_LABEL.physicalResistPct = "Physical Resist Mitigation %"
Const.STAT_LABEL.healthCurrent = "Health"
Const.STAT_LABEL.magickaCurrent = "Magicka"
Const.STAT_LABEL.staminaCurrent = "Stamina"
Const.STAT_LABEL.ultimateCurrent = "Ultimate"

-- ---------------------------------------------------------------------------
-- Game formulas (CP 160 / level 50 values)
-- ---------------------------------------------------------------------------
Const.RESIST_PER_PERCENT         = 660      -- 660 resistance = 1% mitigation
Const.RESIST_FOR_FULL            = 66000    -- RESIST_PER_PERCENT * 100
Const.MAX_ARMOR_MITIGATION       = 0.5      -- 33,000 resistance cap
Const.DEFAULT_TARGET_RESISTANCE  = 18200    -- standard PvE boss / trial dummy resistance
Const.CRIT_RATING_PER_PERCENT    = 219.12
Const.BASE_CRIT_DAMAGE           = 0.5      -- +50% base critical damage

Const.MAX_BOSSES = G("MAX_BOSSES") or 12

-- attribute visual used by the game's shield bar (damage shields on a unit)
Const.VISUAL_SHIELD = G("ATTRIBUTE_VISUAL_POWER_SHIELDING")
