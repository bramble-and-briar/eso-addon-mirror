--[[
    LibFights - Build reader
    Reads the complete build of the current character: identity, attributes, stats,
    every equipped item (set, trait, quality, enchant, weight), equipped sets & active
    bonuses, both action bars (incl. scribed / crafted skills), champion slottables,
    mundus stone, active buffs, skill lines.  Also compares two builds.
]]

local LF = LibFights
local Util, Const = LF.Util, LF.Const
local Build = {}
LF.Build = Build

local Try = Util.Try

-- ---------------------------------------------------------------------------
-- Character
-- ---------------------------------------------------------------------------
function Build.ReadCharacter()
    local c = {}
    c.name = Util.Fmt(GetUnitName("player"))
    c.displayName = GetDisplayName()
    c.level = GetUnitLevel("player")
    c.championPoints = Try(GetUnitChampionPoints, "player") or Try(GetPlayerChampionPointsEarned) or 0
    c.classId = Try(GetUnitClassId, "player")
    c.className = Util.Fmt(GetUnitClass("player"))
    c.raceId = Try(GetUnitRaceId, "player")
    c.raceName = Util.Fmt(GetUnitRace("player"))
    c.alliance = Try(GetUnitAlliance, "player")
    c.allianceName = c.alliance and Util.Fmt(Try(GetAllianceName, c.alliance) or "") or ""
    c.gender = Try(GetUnitGender, "player")
    c.zoneName = Util.Fmt(GetUnitZone("player"))
    c.zoneId = Try(GetZoneId, Try(GetUnitZoneIndex, "player"))
    c.inGroup = IsUnitGrouped("player") and true or false
    c.groupSize = Try(GetGroupSize) or 0
    c.isVampire = Try(IsUnitVampire, "player")
    c.isWerewolf = Try(IsWerewolf)
    return c
end

function Build.ReadAttributes()
    return {
        health = Try(GetAttributeSpentPoints, ATTRIBUTE_HEALTH) or 0,
        magicka = Try(GetAttributeSpentPoints, ATTRIBUTE_MAGICKA) or 0,
        stamina = Try(GetAttributeSpentPoints, ATTRIBUTE_STAMINA) or 0,
        unspent = Try(GetAttributeUnspentPoints) or 0,
    }
end

-- ---------------------------------------------------------------------------
-- Gear
-- ---------------------------------------------------------------------------
function Build.ReadItem(bagId, slotIndex)
    local link = GetItemLink(bagId, slotIndex)
    if not link or link == "" then return nil end
    local it = { link = link }
    it.name = Util.Fmt(GetItemLinkName(link))
    it.itemId = Try(GetItemLinkItemId, link)
    it.icon = Try(GetItemLinkInfo, link) or ""
    local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(link, true)
    if hasSet then it.setId = setId; it.setName = Util.Fmt(setName) end
    local traitType, traitDesc = Try(GetItemLinkTraitInfo, link)
    it.traitType = traitType
    it.traitName = traitType and GetString("SI_ITEMTRAITTYPE", traitType) or ""
    it.traitDescription = traitDesc or ""
    it.quality = Try(GetItemLinkFunctionalQuality, link) or Try(GetItemLinkQuality, link)
    it.displayQuality = Try(GetItemLinkDisplayQuality, link) or it.quality
    it.armorType = Try(GetItemLinkArmorType, link)
    it.weaponType = Try(GetItemLinkWeaponType, link)
    it.equipType = Try(GetItemLinkEquipType, link)
    local _, enchantHeader, enchantDesc = Try(GetItemLinkEnchantInfo, link)
    it.enchantHeader = enchantHeader or ""
    it.enchantDescription = enchantDesc or ""
    it.requiredLevel = Try(GetItemLinkRequiredLevel, link) or 0
    it.requiredCP = Try(GetItemLinkRequiredChampionPoints, link) or 0
    it.armorRating = Try(GetItemLinkArmorRating, link, false) or 0
    it.weaponPower = Try(GetItemLinkWeaponPower, link) or 0
    it.isMythic = (it.setId and Try(GetItemSetType, it.setId) == Const.G("ITEM_SET_TYPE_MYTHIC")) or false
    return it
end

function Build.ReadGear()
    local gear, armorCounts = {}, { light = 0, medium = 0, heavy = 0 }
    for _, slot in ipairs(Const.EQUIP_SLOTS) do
        local it = Build.ReadItem(BAG_WORN, slot.id)
        if it then
            it.slot = slot.id
            it.slotName = slot.name
            it.isBackup = slot.isBackup
            gear[slot.id] = it
            if it.armorType == ARMORTYPE_LIGHT then armorCounts.light = armorCounts.light + 1
            elseif it.armorType == ARMORTYPE_MEDIUM then armorCounts.medium = armorCounts.medium + 1
            elseif it.armorType == ARMORTYPE_HEAVY then armorCounts.heavy = armorCounts.heavy + 1 end
        end
    end
    return gear, armorCounts
end

-- ---------------------------------------------------------------------------
-- Action bars
-- ---------------------------------------------------------------------------
local function ResolveSlotAbility(slot, category)
    local id = Try(GetSlotBoundId, slot, category)
    if not id or id == 0 then return nil end
    local slotType = Try(GetSlotType, slot, category)
    local crafted = false
    if Const.G("ACTION_TYPE_CRAFTED_ABILITY") and slotType == ACTION_TYPE_CRAFTED_ABILITY then
        crafted = true
        local resolved = Try(GetAbilityIdForCraftedAbilityId, id) or Try(GetCraftedAbilityRepresentativeAbilityId, id)
        if resolved and resolved ~= 0 then id = resolved end
    end
    return id, crafted, slotType
end

function Build.ReadBar(category)
    local bar = {}
    if category == nil then return bar end
    for slot = Const.FIRST_SKILL_SLOT, Const.ULTIMATE_SLOT do
        local id, crafted, slotType = ResolveSlotAbility(slot, category)
        if id then
            local info = LF.Abilities.GetInfo(id)
            bar[slot] = {
                slot = slot, abilityId = id, crafted = crafted, slotType = slotType,
                name = info and info.name or "", icon = (info and info.icon) or Try(GetSlotTexture, slot, category) or "",
                isUltimate = slot == Const.ULTIMATE_SLOT,
            }
        end
    end
    return bar
end

function Build.ReadBars()
    return {
        front = Build.ReadBar(Const.HOTBAR_PRIMARY),
        back = Build.ReadBar(Const.HOTBAR_BACKUP),
    }
end

-- ---------------------------------------------------------------------------
-- Champion points
-- ---------------------------------------------------------------------------
function Build.ReadChampion()
    local out = { slotted = {}, totalEarned = Try(GetPlayerChampionPointsEarned) or 0 }
    local cat = Const.HOTBAR_CHAMPION
    if cat == nil then return out end
    local first, last = 1, 12
    local a, b = Try(GetAssignableChampionBarStartAndEndSlots)
    if a and b then first, last = a, b end
    for slot = first, last do
        local id = Try(GetSlotBoundId, slot, cat)
        if id and id ~= 0 then
            out.slotted[#out.slotted + 1] = {
                slot = slot, championSkillId = id,
                name = Util.Fmt(Try(GetChampionSkillName, id) or ""),
                points = Try(GetNumPointsSpentOnChampionSkill, id) or 0,
            }
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Buffs / mundus
-- ---------------------------------------------------------------------------
function Build.ReadBuffs(unitTag)
    unitTag = unitTag or "player"
    local list = {}
    local now = GetFrameTimeSeconds()
    for i = 1, (GetNumBuffs(unitTag) or 0) do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer = GetUnitBuffInfo(unitTag, i)
        if buffName then
            local remaining = (timeEnding and timeEnding > 0) and (timeEnding - now) or nil
            list[#list + 1] = {
                name = Util.CleanAbilityName(buffName), abilityId = abilityId, icon = iconFilename or "",
                stacks = stackCount or 0, effectType = effectType, abilityType = abilityType,
                statusEffectType = statusEffectType, buffSlot = buffSlot, canClickOff = canClickOff,
                castByPlayer = castByPlayer and true or false,
                remainingSec = remaining, permanent = (timeEnding == timeStarted) or (timeEnding == 0),
            }
        end
    end
    return list
end

local function IsMundus(buff)
    local icon = Util.Lower(buff.icon)
    if icon:find("mundus", 1, true) then return true end
    local name = buff.name or ""
    return name:find("^Boon:") ~= nil
end

function Build.ReadMundus(buffs)
    buffs = buffs or Build.ReadBuffs("player")
    local out = {}
    for _, b in ipairs(buffs) do
        if IsMundus(b) then out[#out + 1] = { name = b.name, abilityId = b.abilityId, icon = b.icon } end
    end
    return out
end

-- long-running buffs (food/drink/xp scrolls usually have 30-120 minute durations)
function Build.ReadLongBuffs(buffs)
    buffs = buffs or Build.ReadBuffs("player")
    local out = {}
    for _, b in ipairs(buffs) do
        if b.remainingSec and b.remainingSec >= 600 and not IsMundus(b) then out[#out + 1] = b end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Whole build
-- ---------------------------------------------------------------------------
-- detail: "basic" (default) or "full" (adds every purchased skill)
function Build.Read(detail)
    local b = { timestamp = GetTimeStamp(), apiVersion = GetAPIVersion(), libVersion = LF.version, console = LF.isConsole }
    b.character = Build.ReadCharacter()
    b.attributes = Build.ReadAttributes()
    b.stats = LF.Stats.GetSnapshot()
    b.gear, b.armorCounts = Build.ReadGear()
    b.sets = LF.Sets.GetEquippedSets()
    b.activeWeaponPair = Try(GetActiveWeaponPairInfo) or Const.WEAPON_PAIR_MAIN
    b.bars = Build.ReadBars()
    b.champion = Build.ReadChampion()
    b.buffs = Build.ReadBuffs("player")
    b.mundus = Build.ReadMundus(b.buffs)
    b.longBuffs = Build.ReadLongBuffs(b.buffs)
    if detail == "full" then
        b.skills = LF.Abilities.GetPlayerSkillAbilities(false)
    end
    b.signature = Build.GetSignature(b)
    return b
end

-- A string that changes whenever gear / bars / CP / mundus change.
function Build.GetSignature(b)
    local parts = {}
    for _, slot in ipairs(Const.EQUIP_SLOTS) do
        local it = b.gear and b.gear[slot.id]
        parts[#parts + 1] = it and string.format("%s:%s:%s", tostring(it.itemId), tostring(it.traitType), tostring(it.setId)) or "-"
    end
    for _, barName in ipairs({ "front", "back" }) do
        local bar = b.bars and b.bars[barName] or {}
        for slot = Const.FIRST_SKILL_SLOT, Const.ULTIMATE_SLOT do
            parts[#parts + 1] = bar[slot] and tostring(bar[slot].abilityId) or "0"
        end
    end
    for _, cp in ipairs(b.champion and b.champion.slotted or {}) do parts[#parts + 1] = tostring(cp.championSkillId) end
    for _, m in ipairs(b.mundus or {}) do parts[#parts + 1] = tostring(m.abilityId) end
    return table.concat(parts, "|")
end

-- Slotted ability ids & names of a build (used for proc detection)
function Build.GetSlottedLookup(b)
    local ids, names = {}, {}
    if b and b.bars then
        for _, bar in pairs(b.bars) do
            for _, s in pairs(bar) do
                ids[s.abilityId] = true
                if s.name and s.name ~= "" then names[Util.Lower(s.name)] = true end
            end
        end
    end
    return ids, names
end

-- Differences between two builds (stats, gear, bars, sets, cp)
function Build.Compare(a, b)
    local diff = { stats = {}, gear = {}, bars = {}, sets = {}, champion = {} }
    if not a or not b then return diff end
    for k, v in pairs(b.stats or {}) do
        local old = a.stats and a.stats[k]
        if type(v) == "number" and type(old) == "number" and v ~= old and k ~= "timestampMs" and not k:find("Current$") then
            diff.stats[k] = { old = old, new = v, delta = v - old }
        end
    end
    for _, slot in ipairs(Const.EQUIP_SLOTS) do
        local x, y = a.gear and a.gear[slot.id], b.gear and b.gear[slot.id]
        local xs = x and (tostring(x.itemId) .. ":" .. tostring(x.traitType)) or ""
        local ys = y and (tostring(y.itemId) .. ":" .. tostring(y.traitType)) or ""
        if xs ~= ys then diff.gear[slot.name] = { old = x and x.name or "", new = y and y.name or "" } end
    end
    for _, barName in ipairs({ "front", "back" }) do
        for slot = Const.FIRST_SKILL_SLOT, Const.ULTIMATE_SLOT do
            local x = a.bars and a.bars[barName] and a.bars[barName][slot]
            local y = b.bars and b.bars[barName] and b.bars[barName][slot]
            local xi, yi = x and x.abilityId or 0, y and y.abilityId or 0
            if xi ~= yi then diff.bars[#diff.bars + 1] = { bar = barName, slot = slot, old = x and x.name or "", new = y and y.name or "" } end
        end
    end
    for setId, s in pairs(b.sets or {}) do
        local old = a.sets and a.sets[setId]
        if not old or old.equipped ~= s.equipped then
            diff.sets[s.name] = { old = old and old.equipped or 0, new = s.equipped }
        end
    end
    for setId, s in pairs(a.sets or {}) do
        if not (b.sets and b.sets[setId]) then diff.sets[s.name] = { old = s.equipped, new = 0 } end
    end
    return diff
end
