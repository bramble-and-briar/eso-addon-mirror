-- Your stats, and your penetration / critical damage AGAINST an enemy (5.15.0).
--
-- Sheet values: GetPlayerStat(stat, STAT_BONUS_OPTION_APPLY_BONUS) -- the character sheet shows STAT_SPELL_PENETRATION and
-- STAT_PHYSICAL_PENETRATION (esoui zo_stats_keyboard.lua). Critical damage: GetAdvancedStatValue(CRITICAL_DAMAGE)'s
-- percent + the 50 % every character has (as DynamicStats).
--
-- Against an enemy = sheet + what the debuffs on it add. The table is the one Combat Metrics uses (Solinur's StatDebuffs,
-- matched by NAME so every variant counts), cross-checked with DynamicStats, EZOMetter and Bandits UI:
--   Major Breach 5948, Minor Breach 2974, Crusher 2108 (infused; settable), Roar of Alkosh up to 6000 (scales with the
--   wearer's weapon damage; settable), Crimson Oath 3541, Runic Sunder 2200, Tremorscale 2640, Crystal Weapon 1000,
--   poison "Resistance Reduction" 1320 (spell 79087 / physical 79090), and with the champion star Force of Nature (276)
--   slotted 660 for every status effect on the enemy (DynamicStats checks the star; Combat Metrics: WrathOfNaturePen).
--   Critical damage: Minor Brittle 10, Major Brittle 20, Flame / Frost / Shock Weakness 5 each and Elemental Catalyst 15
--   (that group capped at 15, as EZOMetter).
-- Nothing here runs unless a tracker or a rule asks for it; values are worked out once per update.

local DT = DebuffTracker
local St = DT.Stats
local U = DT.Util

local PEN_IDS = {
    { 61743, 5948 },            -- Major Breach
    { 61742, 2974 },            -- Minor Breach
    { 17906, "crusher" },       -- Crusher
    { 120007, "crusher" },      -- Crusher (target dummy)
    { 76667, "alkosh" },        -- Roar of Alkosh
    { 120018, "alkosh" },       -- Roar of Alkosh (target dummy)
    { 159288, 3541 },           -- Crimson Oath
    { 187742, 2200 },           -- Runic Sunder
    { 80866, "tremorscale" },   -- Tremorscale (scales with the tank's armor -- Hyperioxes; 2640 in Combat Metrics)
    { 143808, 1000 },           -- Crystal Weapon
    -- Anthelmir's Construct (monster set): 215153, the debuff on the enemy -- recorded in game by Yarden (5.17.1: "by you",
    -- 5 s, on a target dummy; 215155 of the same name is a buff on its own unit). 2000 (Skooma-Tools' calculator); it
    -- scales with the wearer's weapon damage (Hyperioxes): settable.
    { 215153, "anthelmir" },
}
local POISON_PEN = { [79087] = "spell", [79090] = "physical" }      -- 1320 each, for that damage type
-- Force of Nature: 660 per status effect on the enemy. Some status effects leave no effect the game lists (Combat
-- Metrics / DynamicStats mark Overcharged, Sundered and Diseased "not working"); Meterskull counts the Minor debuff each of
-- them applies instead. Each status counts once, whichever of its effects is seen.
local FON_STATUS = {
    burning = { 18084 }, poisoned = { 21929 }, hemorrhaging = { 148801 },
    chill = { 95136, 145975 },          -- Chill / Minor Brittle
    concussion = { 95134, 79717 },      -- Concussion / Minor Vulnerability
    sundered = { 178123, 61742 },       -- Sundered / Minor Breach
    overcharged = { 178118, 88401 },    -- Overcharged / Minor Magickasteal
    diseased = { 178127, 61726 },       -- Diseased / Minor Defile
}
local FON_STAR, FON_PEN = 276, 660
local BACKSTABBER_STAR, BACKSTABBER_CRIT = 31, 10   -- up to +10 % critical damage

-- Backstabber gives 2 % per full 10 points spent in it, up to 10 % at 50 (LibCombat GetCritBonusFromCP, Solinur).
-- Meterskull / DynamicStats added a flat 10 whenever it was slotted, too much below 50 points.
local function BackstabberBonus()
    if type(GetNumPointsSpentOnChampionSkill) ~= "function" then return BACKSTABBER_CRIT end
    local points = tonumber(GetNumPointsSpentOnChampionSkill(BACKSTABBER_STAR)) or 0
    return math.min(BACKSTABBER_CRIT, 2 * math.floor(points / 10))
end
St.BackstabberBonus = BackstabberBonus

-- The Shadow mundus with Divines armour: the critical damage the game reports for the mundus doesn't count the
-- Divines trait. LibCombat (GetShadowBonus) works out what it should be -- 11 % x (1 + the Divines %s of your
-- worn armour) -- and adds the difference to what the game says (the number in the mundus's own description).
local SHADOW_MUNDUS, SHADOW_BASE = 13984, 11
local DIVINES_SLOTS = { "EQUIP_SLOT_HEAD", "EQUIP_SLOT_SHOULDERS", "EQUIP_SLOT_CHEST", "EQUIP_SLOT_HAND",
    "EQUIP_SLOT_WAIST", "EQUIP_SLOT_LEGS", "EQUIP_SLOT_FEET" }
-- the white number in a tooltip text: "|cffffff9.1|r%" -> 9.1 (LibCombat's ParseDescriptionBonus)
local function DescriptionNumber(text)
    if type(text) ~= "string" then return nil end
    local a, b = text:match("cffffff[un ]*(%d+)%p?(%d*)[%%|][r|]")
    if not a then return nil end
    return tonumber(b ~= "" and (a .. "." .. b) or a)
end
St.DescriptionNumber = DescriptionNumber
local shadowCache = { at = -10, value = 0 }
local function ShadowMundusOffset(now)
    if now - shadowCache.at < 2 then return shadowCache.value end     -- worked out at most every 2 s
    shadowCache.at = now
    local value = 0
    if type(GetUnitBuffInfo) == "function" and type(GetAbilityEffectDescription) == "function" then
        for i = 1, GetNumBuffs("player") do
            local _, _, _, effectSlot, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
            if abilityId == SHADOW_MUNDUS then
                local divines = 0
                if type(GetItemLinkTraitInfo) == "function" and ITEM_TRAIT_TYPE_ARMOR_DIVINES then
                    for _, name in ipairs(DIVINES_SLOTS) do
                        local slot = _G[name]
                        if slot then
                            local trait, desc = GetItemLinkTraitInfo(GetItemLink(BAG_WORN, slot, LINK_STYLE_DEFAULT))
                            if trait == ITEM_TRAIT_TYPE_ARMOR_DIVINES then divines = divines + (DescriptionNumber(desc) or 0) end
                        end
                    end
                end
                local game = DescriptionNumber(GetAbilityEffectDescription(effectSlot)) or 0
                value = math.floor(SHADOW_BASE * (1 + divines / 100)) - game
                break
            end
        end
    end
    shadowCache.value = value
    return value
end
St.ResetShadowCache = function() shadowCache.at = -10 end
local CRIT_IDS = {
    { 145975, 10 },             -- Minor Brittle
    { 145977, 20 },             -- Major Brittle
    { 142610, 5, "ec" },        -- Flame Weakness
    { 142652, 5, "ec" },        -- Frost Weakness
    { 142653, 5, "ec" },        -- Shock Weakness
    { 181606, 15, "ec" },       -- Elemental Catalyst
}
local EC_CAP = 15

St.STATS = DT.Const.STATS

local byName            -- [lowercase name] = { pen = value|"crusher"|"alkosh" } / { crit = value, group = "ec" } / { poison = kind } / { fon = true }
local function Names()
    if byName then return byName end
    byName = {}
    local function Put(id, t)
        local n = U.Lower(GetAbilityName(id) or "")         -- (as the scanned entries' lname)
        if n ~= "" then byName[n] = byName[n] or {}; for k, v in pairs(t) do byName[n][k] = v end end
    end
    for _, p in ipairs(PEN_IDS) do Put(p[1], { pen = p[2] }) end
    for id, kind in pairs(POISON_PEN) do Put(id, { poison = kind }) end
    for status, ids in pairs(FON_STATUS) do
        for _, id in ipairs(ids) do Put(id, { fon = status }) end
    end
    for _, c in ipairs(CRIT_IDS) do Put(c[1], { crit = c[2], group = c[3] }) end
    return byName
end
St.Names = Names

local function Setting(key, default)
    local st = DT.Profiles and DT.Profiles.Settings and DT.Profiles.Settings()
    local v = st and tonumber(st[key])
    return v or default
end
-- The enemy's armour (Hyperioxes' penetration calculator, U51): instanced enemies 18200, overland 9100, dragons 13650.
-- Setting 0 = automatic by zone: dungeons, trials, houses (the trial dummy) and PvP 18200, overland and delves 9100.
function St.TargetResistance()
    local v = Setting("penTargetResist", 0)
    if v > 0 then return v end
    local zt = DT.Load and DT.Load.zone and DT.Load.zone.type
    if zt == "overland" or zt == "delve" then return 9100 end
    return 18200
end
function St.CritCap() return 125 end

local function Stat(name)
    local id = _G[name]
    if not id or type(GetPlayerStat) ~= "function" then return 0 end
    return GetPlayerStat(id, STAT_BONUS_OPTION_APPLY_BONUS) or 0
end

-- per update: sheet values and per-unit results are worked out once
local cache = { at = -1 }
local function Fresh(now)
    if cache.at ~= now then cache = { at = now, units = {} } end
    return cache
end

function St.Sheet(now)
    local c = Fresh(now)
    if c.sheet then return c.sheet end
    local s = {
        physPen = Stat("STAT_PHYSICAL_PENETRATION"), spellPen = Stat("STAT_SPELL_PENETRATION"),
        weapon = Stat("STAT_POWER"), spell = Stat("STAT_SPELL_POWER"),
        weaponCrit = Stat("STAT_CRITICAL_STRIKE"), spellCrit = Stat("STAT_SPELL_CRITICAL"),
        physResist = Stat("STAT_PHYSICAL_RESIST"), spellResist = Stat("STAT_SPELL_RESIST"),
    }
    s.pen = math.max(s.physPen, s.spellPen)
    -- which damage type the higher penetration is (the poison debuffs count for their own type only)
    s.penKind = s.spellPen > s.physPen and "spell" or "physical"
    local crit = 0
    if type(GetAdvancedStatValue) == "function" and ADVANCED_STAT_DISPLAY_TYPE_CRITICAL_DAMAGE then
        local _, _, pct = GetAdvancedStatValue(ADVANCED_STAT_DISPLAY_TYPE_CRITICAL_DAMAGE)
        crit = tonumber(pct) or 0
    end
    -- 50 % base + the sheet; Backstabber (champion) isn't on the sheet (it needs you to be flanking: counted when
    -- slotted, by the points spent in it); the Shadow mundus's Divines part (LibCombat)
    local cp = DT.Load and DT.Load.ChampionSlotted and DT.Load.ChampionSlotted() or {}
    s.critDamage = 50 + crit + (cp[BACKSTABBER_STAR] and BackstabberBonus() or 0) + ShadowMundusOffset(now)
    -- crit chance: rating / 219.18 (Hyperioxes: "divide your rating by 21918"; Meterskull 219.12); the sheet rating
    -- already includes the base 10 %
    s.critChance = math.max(s.weaponCrit, s.spellCrit) / 219.18
    s.critResist = Stat("STAT_CRITICAL_RESISTANCE")
    s.healthRegen = Stat("STAT_HEALTH_REGEN_COMBAT")
    s.magickaRegen = Stat("STAT_MAGICKA_REGEN_COMBAT")
    s.staminaRegen = Stat("STAT_STAMINA_REGEN_COMBAT")
    s.damage = math.max(s.weapon, s.spell)
    c.sheet = s
    return s
end

-- what the effects on a unit (unit tag) add: { pen = n, crit = n, list = { "Major Breach 5948", ... } }
function St.OnUnit(tag, now)
    local c = Fresh(now)
    local r = c.units[tag]
    if r then return r end
    r = { pen = 0, crit = 0, list = {} }
    c.units[tag] = r
    if not tag or not DoesUnitExist(tag) then return r end
    local names = Names()
    local sheet = St.Sheet(now)
    local fon = DT.Load and DT.Load.ChampionSlotted and DT.Load.ChampionSlotted()[FON_STAR]
    local seen, ec, statuses = {}, 0, {}
    -- players: what you'd need against them differs (PvP armour); only enemies' debuffs are counted (as Meterskull)
    if type(IsUnitPlayer) == "function" and IsUnitPlayer(tag) then return r end
    for _, e in ipairs(DT.Effects.Scan(tag, now)) do
        local d = names[e.lname]
        if d and not seen[e.lname] and (e.finish <= e.begin or e.finish > now) then
            seen[e.lname] = true
            local add = 0
            -- (one effect can count twice: Minor Breach is 2974 penetration AND the Sundered status for Force of Nature)
            if d.pen then
                add = d.pen == "crusher" and Setting("penCrusher", 2108) or d.pen == "alkosh" and Setting("penAlkosh", 6000)
                    or d.pen == "tremorscale" and Setting("penTremorscale", 2640)
                    or d.pen == "anthelmir" and Setting("penAnthelmir", 2000) or d.pen
            elseif d.poison then
                if d.poison == sheet.penKind then add = 1320 end
            end
            if add > 0 then
                r.pen = r.pen + add
                r.list[#r.list + 1] = string.format("%s %d", e.name, add)
            end
            if d.fon and fon and not statuses[d.fon] then
                statuses[d.fon] = true
                r.pen = r.pen + FON_PEN
                r.list[#r.list + 1] = string.format("%s (Force of Nature) %d", e.name, FON_PEN)
            end
            if d.crit then
                if d.group == "ec" then ec = ec + d.crit else r.crit = r.crit + d.crit end
            end
        end
    end
    r.crit = r.crit + math.min(ec, EC_CAP)
    return r
end

-- Your target for a moment: sweeping the camera off the boss mid-fight shouldn't drop the value to your sheet alone
-- (Meterskull keeps the last one for 1 s in combat).
local HOLD = 1
local lastTarget = { at = -10 }
local function TargetResult(tag, now)
    tag = tag or "reticleover"
    if tag ~= "reticleover" then return St.OnUnit(tag, now) end
    local hasEnemy = DoesUnitExist("reticleover") and not (type(IsUnitPlayer) == "function" and IsUnitPlayer("reticleover"))
    if hasEnemy then
        local u = St.OnUnit("reticleover", now)
        lastTarget = { at = now, u = u }
        return u
    end
    if lastTarget.u and now - lastTarget.at <= HOLD and type(IsUnitInCombat) == "function" and IsUnitInCombat("player") then
        return lastTarget.u
    end
    return St.OnUnit("reticleover", now)
end

-- value, max (the cap it's compared with) for a stat; tag = the unit for "vs. my target"
function St.Value(stat, now, tag)
    local s = St.Sheet(now)
    if stat == "penTarget" then
        local u = TargetResult(tag, now)
        return s.pen + u.pen, St.TargetResistance(), u
    elseif stat == "critTarget" then
        local u = TargetResult(tag, now)
        return s.critDamage + u.crit, St.CritCap(), u
    elseif stat == "pen" then return s.pen, St.TargetResistance()
    elseif stat == "critDamage" then return s.critDamage, St.CritCap()
    elseif stat == "weaponDamage" then return s.damage, 0
    elseif stat == "critChance" then return s.critChance, 0
    elseif stat == "physResist" then return s.physResist, 33100
    elseif stat == "spellResist" then return s.spellResist, 33100
    elseif stat == "critResist" then return s.critResist, 0
    elseif stat == "critResistPct" then
        -- UESP (Online:Critical Resistance): % = critical resistance / the player's level, capped at 66 (CP 160)
        local lvl = type(GetUnitEffectiveLevel) == "function" and tonumber(GetUnitEffectiveLevel("player")) or 66
        lvl = math.max(1, math.min(66, lvl or 66))
        return s.critResist / lvl, 0
    elseif stat == "lowestResist" then
        -- the lower of the two (Meterskull's "hybrid armour"); the 3rd value says which
        if s.physResist <= s.spellResist then return s.physResist, 33100, nil, "physical" end
        return s.spellResist, 33100, nil, "spell"
    elseif stat == "ultPerSecond" then return DT.Resources.UltPerSecond(now, 10), 0
    elseif stat == "healthRegen" then return s.healthRegen, 0
    elseif stat == "magickaRegen" then return s.magickaRegen, 0
    elseif stat == "staminaRegen" then return s.staminaRegen, 0
    end
    return 0, 0
end
