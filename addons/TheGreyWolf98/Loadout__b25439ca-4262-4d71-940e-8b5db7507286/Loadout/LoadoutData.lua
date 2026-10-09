-- Loadout: reads your current build only. No equipment or settings are changed.
Loadout = { name = "Loadout", version = "1.0.0" }
local L = Loadout
local function packed(...) return { n = select("#", ...), ... } end

-- Optional/new APIs are checked at the boundary. A failed read is never shown as 0.
function L.Read(api, ...)
    local f = _G[api]
    if type(f) ~= "function" then return nil end
    local values = packed(pcall(f, ...))
    if not values[1] then return nil end
    return unpack(values, 2, values.n)
end

function L.Text(value)
    if value == nil or value == "" then return "Unavailable" end
    return zo_strformat("<<1>>", tostring(value))
end

local function enumText(group, value)
    if value == nil then return "Unavailable" end
    return L.Text(L.Read("GetString", group, value))
end

local gearSlots = {
    { "Head", "EQUIP_SLOT_HEAD" }, { "Shoulders", "EQUIP_SLOT_SHOULDERS" },
    { "Chest", "EQUIP_SLOT_CHEST" }, { "Hands", "EQUIP_SLOT_HAND" },
    { "Waist", "EQUIP_SLOT_WAIST" }, { "Legs", "EQUIP_SLOT_LEGS" },
    { "Feet", "EQUIP_SLOT_FEET" }, { "Neck", "EQUIP_SLOT_NECK" },
    { "Ring 1", "EQUIP_SLOT_RING1" }, { "Ring 2", "EQUIP_SLOT_RING2" },
    { "Front main", "EQUIP_SLOT_MAIN_HAND" }, { "Front off", "EQUIP_SLOT_OFF_HAND" },
    { "Back main", "EQUIP_SLOT_BACKUP_MAIN" }, { "Back off", "EQUIP_SLOT_BACKUP_OFF" },
}

function L.CaptureGear()
    local rows = {}
    for _, entry in ipairs(gearSlots) do
        local row = { slot = entry[1] }
        local slotId = _G[entry[2]]
        local link = slotId and L.Read("GetItemLink", BAG_WORN, slotId, LINK_STYLE_DEFAULT)
        row.link = link
        if link == nil then
            row.name, row.detail = "Unavailable", "This slot could not be read"
        elseif link == "" then
            row.name, row.detail, row.empty = "Empty", "No item equipped", true
        else
            row.name = L.Text(L.Read("GetItemLinkName", link))
            row.icon = L.Read("GetItemLinkInfo", link)
            row.quality = L.Read("GetItemLinkDisplayQuality", link)
            local hasSet, setName = L.Read("GetItemLinkSetInfo", link, true)
            row.setName = hasSet and L.Text(setName) or "No set"
            local trait = L.Read("GetItemLinkTraitInfo", link)
            row.trait = enumText("SI_ITEMTRAITTYPE", trait)
            local _, header, description = L.Read("GetItemLinkEnchantInfo", link)
            row.enchant = (header and header ~= "") and L.Text(header) or "No enchantment"
            row.enchantDescription = description or ""
            local cp = L.Read("GetItemLinkRequiredChampionPoints", link)
            local level = L.Read("GetItemLinkRequiredLevel", link)
            row.level = cp and cp > 0 and ("CP " .. cp) or ("Lv " .. (level or "?"))
            local armor = L.Read("GetItemLinkArmorType", link)
            local weapon = L.Read("GetItemLinkWeaponType", link)
            row.itemType = armor and armor ~= ARMORTYPE_NONE and enumText("SI_ARMORTYPE", armor)
                or weapon and weapon ~= WEAPONTYPE_NONE and enumText("SI_WEAPONTYPE", weapon) or "Jewellery"
            row.detail = table.concat({ row.level, row.itemType, row.trait, row.enchant }, "  /  ")
        end
        rows[#rows + 1] = row
    end
    return rows
end

function L.CaptureBar(category)
    local rows = {}
    for slot = 3, 8 do
        local row = { slot = slot, ultimate = slot == 8 }
        local id = L.Read("GetSlotBoundId", slot, category)
        local kind = L.Read("GetSlotType", slot, category)
        row.id = id
        if id == nil then
            row.name = "Unavailable"
        elseif id == 0 or kind == ACTION_TYPE_NOTHING then
            row.name, row.empty = "Empty", true
        else
            row.name = L.Text(L.Read("GetSlotName", slot, category))
            row.icon = L.Read("GetSlotTexture", slot, category)
            local craftedId
            if kind == ACTION_TYPE_CRAFTED_ABILITY then
                craftedId = id -- crafted slot IDs are grimoire IDs, not ordinary ability IDs
            elseif kind == ACTION_TYPE_ABILITY then
                craftedId = L.Read("GetAbilityCraftedAbilityId", id)
            end
            if craftedId and craftedId > 0 then
                local a, b, c = L.Read("GetCraftedAbilityActiveScriptIds", craftedId)
                local scripts = {}
                for _, script in ipairs({ a or 0, b or 0, c or 0 }) do
                    scripts[#scripts + 1] = script > 0 and L.Text(L.Read("GetCraftedAbilityScriptDisplayName", script)) or "Unavailable"
                end
                row.scripts = table.concat(scripts, " / ")
            end
        end
        rows[#rows + 1] = row
    end
    return rows
end

function L.CaptureCP()
    local rows = {}
    local first, last = L.Read("GetAssignableChampionBarStartAndEndSlots")
    if first == nil or last == nil then return rows end
    for slot = first, last do
        local id = L.Read("GetSlotBoundId", slot, HOTBAR_CATEGORY_CHAMPION)
        local discipline = L.Read("GetRequiredChampionDisciplineIdForSlot", slot, HOTBAR_CATEGORY_CHAMPION)
        rows[#rows + 1] = {
            discipline = L.Read("GetChampionDisciplineType", discipline),
            name = id and id > 0 and L.Text(L.Read("GetChampionSkillName", id)) or id == 0 and "Empty" or "Unavailable",
            points = id and id > 0 and L.Read("GetNumPointsSpentOnChampionSkill", id) or nil,
        }
    end
    return rows
end

local stats = {
    { "Health", "STAT_HEALTH_MAX" }, { "Magicka", "STAT_MAGICKA_MAX" }, { "Stamina", "STAT_STAMINA_MAX" },
    { "Weapon dmg", "STAT_POWER" }, { "Spell dmg", "STAT_SPELL_POWER" },
    { "Weapon crit", "STAT_CRITICAL_STRIKE", true }, { "Spell crit", "STAT_SPELL_CRITICAL", true },
    { "Physical pen", "STAT_PHYSICAL_PENETRATION" }, { "Spell pen", "STAT_SPELL_PENETRATION" },
    { "Physical resist", "STAT_PHYSICAL_RESIST" }, { "Spell resist", "STAT_SPELL_RESIST" },
    { "Health regen", "STAT_HEALTH_REGEN_COMBAT" }, { "Magicka regen", "STAT_MAGICKA_REGEN_COMBAT" },
    { "Stamina regen", "STAT_STAMINA_REGEN_COMBAT" },
}

function L.CaptureStats()
    local rows = {}
    for _, stat in ipairs(stats) do
        local value = _G[stat[2]] and L.Read("GetPlayerStat", _G[stat[2]], STAT_BONUS_OPTION_APPLY_BONUS)
        if stat[3] and value ~= nil then
            local chance = L.Read("GetCriticalStrikeChance", value)
            value = chance and string.format("%.1f%%", chance) or "Unavailable"
        end
        rows[#rows + 1] = { name = stat[1], value = value ~= nil and tostring(value) or "Unavailable" }
    end
    return rows
end

function L.CaptureBuffs()
    local buffs, mundus = {}, {}
    for i = 1, L.Read("GetNumBuffs", "player") or 0 do
        local name, _, ending, _, _, _, _, _, _, _, id = L.Read("GetUnitBuffInfo", "player", i)
        if name and name ~= "" then
            local stone = id and L.Read("GetAbilityMundusStoneType", id)
            if stone and stone ~= MUNDUS_STONE_INVALID then
                mundus[#mundus + 1] = L.Text(name)
            else
                buffs[#buffs + 1] = { name = L.Text(name), ending = ending }
            end
        end
    end
    return buffs, #mundus > 0 and table.concat(mundus, " + ") or "None detected"
end

function L.CaptureClassLines()
    local lines, masteries = {}, {}
    local masteryReadable = false
    for i = 1, L.Read("GetNumSkillLines", SKILL_TYPE_CLASS) or 0 do
        local _, _, active, _, _, _, masteryFlag = L.Read("GetSkillLineDynamicInfo", SKILL_TYPE_CLASS, i)
        local id = L.Read("GetSkillLineId", SKILL_TYPE_CLASS, i)
        local isMastery = masteryFlag == true or L.Read("IsClassMasterySkillLine", id) == true
        if isMastery and active then
            local count = L.Read("GetNumSkillAbilities", SKILL_TYPE_CLASS, i)
            if count then
                masteryReadable = true
                for index = 1, count do
                    local name, texture, _, _, _, purchased = L.Read("GetSkillAbilityInfo", SKILL_TYPE_CLASS, i, index)
                    if purchased == nil then masteryReadable = false end
                    if purchased then
                        local rank, maxRank = L.Read("GetSkillAbilityUpgradeInfo", SKILL_TYPE_CLASS, i, index)
                        masteries[#masteries + 1] = { name = L.Text(name), icon = texture, rank = rank, maxRank = maxRank }
                    end
                end
            end
        elseif active and not isMastery then
            lines[#lines + 1] = L.Text(L.Read("GetSkillLineNameById", id))
        end
    end
    return lines, masteries, masteryReadable
end

function L.Capture()
    local buffs, mundus = L.CaptureBuffs()
    local lines, masteries, masteryReadable = L.CaptureClassLines()
    local front, back = L.CaptureBar(HOTBAR_CATEGORY_PRIMARY), L.CaptureBar(HOTBAR_CATEGORY_BACKUP)
    -- Full script combinations also appear on the wide effects detail page.
    local effects = {}
    for bar, rows in ipairs({front, back}) do
        for _, row in ipairs(rows) do
            if row.scripts then effects[#effects + 1] = { name = (bar == 1 and "Front: " or "Back: ") .. row.name .. " — " .. row.scripts } end
        end
    end
    for _, row in ipairs(buffs) do effects[#effects + 1] = row end
    for _, row in ipairs(masteries) do
        effects[#effects + 1] = { name = "Class Mastery: " .. row.name
            .. (row.rank and row.maxRank and row.maxRank > 1 and (" — Rank " .. row.rank .. "/" .. row.maxRank) or "") }
    end
    local poisons = {}
    for _, slotName in ipairs({ "EQUIP_SLOT_POISON", "EQUIP_SLOT_BACKUP_POISON" }) do
        local link = _G[slotName] and L.Read("GetItemLink", BAG_WORN, _G[slotName], LINK_STYLE_DEFAULT)
        poisons[#poisons + 1] = link == "" and "None" or link and L.Text(L.Read("GetItemLinkName", link)) or "Unavailable"
    end
    local activePair, pairLocked = L.Read("GetActiveWeaponPairInfo")
    return {
        name = L.Text(L.Read("GetUnitName", "player")), race = L.Text(L.Read("GetUnitRace", "player")),
        class = L.Text(L.Read("GetUnitClass", "player")), level = L.Read("GetUnitLevel", "player") or "?",
        cp = L.Read("GetUnitChampionPoints", "player") or "?", lines = table.concat(lines, " / "),
        masteries = masteries, masteryReadable = masteryReadable,
        attributes = {
            L.Read("GetAttributeSpentPoints", ATTRIBUTE_HEALTH), L.Read("GetAttributeSpentPoints", ATTRIBUTE_MAGICKA),
            L.Read("GetAttributeSpentPoints", ATTRIBUTE_STAMINA),
        },
        activePair = activePair, pairLocked = pairLocked, activeCategory = L.Read("GetActiveHotbarCategory"),
        gear = L.CaptureGear(), front = front, back = back, poisons = poisons,
        champion = L.CaptureCP(), stats = L.CaptureStats(), buffs = effects, mundus = mundus,
        timestamp = L.Read("GetTimeString") or "",
    }
end
