local O = OneCraft
local P = {types = {}, slots = {}, slotOrder = {}, extraCount = 10}
O.Equipment = P
local function text(ru, en) return O.isRussian and ru or O.Translate(en) end
P.Text = text
P.words = {
    title = text("Конструктор снаряжения", "Equipment planner"),
    set = text("Сет", "Set"), type = text("Предмет / тяжесть", "Item / weight"),
    trait = text("Трейт", "Trait"), enchant = text("Зачарование", "Enchantment"),
    quality = text("Качество", "Quality"), style = text("Стиль", "Style"), level = text("Уровень", "Level"),
    apply = text("Применить к слоту", "Apply to slot"), remove = text("Очистить слот", "Clear slot"),
    clear = text("Очистить всё", "Clear all"),
    extras = text("Дополнительные предметы", "Additional items"), materials = text("Материалы — нужно / есть", "Materials — needed / owned"),
    submit = text("Отправить на крафт", "Queue crafting"), cancel = text("Отменить очередь", "Cancel queue"),
    close = text("К станку", "Back to station"), none = text("Без сета", "No set"),
    noEnchant = text("Без зачарования", "No enchantment"),
    move = text("Перетаскивайте предметы между слотами и дополнительным контейнером.", "Drag items between equipment slots and the additional container."),
    incompatible = text("Предметы не подходят этим слотам. Сначала освободите вторую руку для двуручного оружия.", "Items do not fit these slots. Clear the off hand before choosing a two-handed weapon."),
    busy = text("Дождитесь завершения текущего крафта.", "Wait for the current craft to finish."),
    invalid = text("Проверьте параметры предмета.", "Check the item parameters."),
    queued = text("Очередь: %d / %d готово", "Queue: %d / %d complete"),
    waiting = text("Очередь ожидает подходящую станцию, материалы или изучение рецепта.", "Queue is waiting for a matching station, materials or crafting knowledge."),
    failed = text("Крафт приостановлен. Проверьте материалы, свободное место и изученные трейты/стили.", "Crafting paused. Check materials, free space and known traits/styles."),
    sameSet = text("Новые слоты сохраняют совместимые параметры", "New slots keep compatible parameters"),
}

local armor = {
    {"Chest", EQUIP_TYPE_CHEST, 1}, {"Foot", EQUIP_TYPE_FEET, 2}, {"Glove", EQUIP_TYPE_HAND, 3},
    {"Head", EQUIP_TYPE_HEAD, 4}, {"Leg", EQUIP_TYPE_LEGS, 5},
    {"Shoulder", EQUIP_TYPE_SHOULDERS, 6}, {"Belt", EQUIP_TYPE_WAIST, 7},
}
local function addType(key, station, pattern, equip, category, name, twoHand, offOnly)
    local entry = {key = key, station = station, pattern = pattern, equip = equip,
        category = category, name = name, twoHand = twoHand, offOnly = offOnly}
    P.types[key] = entry
    P.typeOrder[#P.typeOrder + 1] = entry
end
P.typeOrder = {}
for _, row in ipairs(armor) do
    for _, weight in ipairs({{ARMORTYPE_LIGHT, CRAFTING_TYPE_CLOTHIER, row[3] + 1},
        {ARMORTYPE_MEDIUM, CRAFTING_TYPE_CLOTHIER, row[3] + 8},
        {ARMORTYPE_HEAVY, CRAFTING_TYPE_BLACKSMITHING, row[3] + 7}}) do
        addType(row[1] .. weight[1], weight[2], weight[3], row[2], "armor",
            GetString("SI_ARMORTYPE", weight[1]) .. " — " .. GetString("SI_EQUIPTYPE", row[2]))
        P.types[row[1] .. weight[1]].weight = weight[1]
    end
end
local weapons = {
    {WEAPONTYPE_AXE, 1, 1}, {WEAPONTYPE_HAMMER, 1, 2}, {WEAPONTYPE_SWORD, 1, 3},
    {WEAPONTYPE_TWO_HANDED_AXE, 1, 4, true}, {WEAPONTYPE_TWO_HANDED_HAMMER, 1, 5, true},
    {WEAPONTYPE_TWO_HANDED_SWORD, 1, 6, true}, {WEAPONTYPE_DAGGER, 1, 7},
    {WEAPONTYPE_BOW, 6, 1, true}, {WEAPONTYPE_SHIELD, 6, 2, false, true},
    {WEAPONTYPE_FIRE_STAFF, 6, 3, true}, {WEAPONTYPE_FROST_STAFF, 6, 4, true},
    {WEAPONTYPE_LIGHTNING_STAFF, 6, 5, true}, {WEAPONTYPE_HEALING_STAFF, 6, 6, true},
}
for _, row in ipairs(weapons) do
    addType("weapon" .. row[1], row[2] == 1 and CRAFTING_TYPE_BLACKSMITHING or CRAFTING_TYPE_WOODWORKING,
        row[3], row[5] and EQUIP_TYPE_OFF_HAND or (row[4] and EQUIP_TYPE_TWO_HAND or EQUIP_TYPE_ONE_HAND),
        row[5] and "armor" or "weapon", GetString("SI_WEAPONTYPE", row[1]), row[4], row[5])
    P.types["weapon" .. row[1]].weaponType = row[1]
end
addType("ring", CRAFTING_TYPE_JEWELRYCRAFTING, 1, EQUIP_TYPE_RING, "jewelry", GetString("SI_EQUIPTYPE", EQUIP_TYPE_RING))
addType("neck", CRAFTING_TYPE_JEWELRYCRAFTING, 2, EQUIP_TYPE_NECK, "jewelry", GetString("SI_EQUIPTYPE", EQUIP_TYPE_NECK))

for _, row in ipairs(armor) do P.slots[row[1]] = {equip = row[2]} end
P.slots.Neck, P.slots.Ring1, P.slots.Ring2 = {equip = EQUIP_TYPE_NECK}, {equip = EQUIP_TYPE_RING}, {equip = EQUIP_TYPE_RING}
P.slots.MainHand, P.slots.OffHand = {weapon = true, pair = "OffHand"}, {weapon = true, off = true, pair = "MainHand"}
P.slots.BackupMain, P.slots.BackupOff = {weapon = true, pair = "BackupOff"}, {weapon = true, off = true, pair = "BackupMain"}
P.slotIds = {Head = EQUIP_SLOT_HEAD, Shoulder = EQUIP_SLOT_SHOULDERS, Chest = EQUIP_SLOT_CHEST,
    Glove = EQUIP_SLOT_HAND, Belt = EQUIP_SLOT_WAIST, Leg = EQUIP_SLOT_LEGS, Foot = EQUIP_SLOT_FEET,
    Neck = EQUIP_SLOT_NECK, Ring1 = EQUIP_SLOT_RING1, Ring2 = EQUIP_SLOT_RING2,
    MainHand = EQUIP_SLOT_MAIN_HAND, OffHand = EQUIP_SLOT_OFF_HAND, BackupMain = EQUIP_SLOT_BACKUP_MAIN, BackupOff = EQUIP_SLOT_BACKUP_OFF}
P.slotOrder = {"Head", "Shoulder", "Chest", "Glove", "Belt", "Leg", "Foot", "Neck", "Ring1", "Ring2", "MainHand", "OffHand", "BackupMain", "BackupOff"}
for i = 1, P.extraCount do
    local key = "extra" .. i
    P.slots[key] = {extra = true}
    P.slotOrder[#P.slotOrder + 1] = key
end

function P.Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = P.Copy(v) end
    return result
end

function P.Fits(key, item)
    local slot, kind = P.slots[key], item and P.types[item.type]
    if not slot then return false end
    if not item then return true end
    if not kind then return false end
    if slot.extra then return true end
    if slot.weapon then
        return (kind.category == "weapon" or kind.offOnly) and (not slot.off or not kind.twoHand) and (slot.off or not kind.offOnly)
    end
    return slot.equip == kind.equip
end

function P.ValidLayout(items)
    for key, item in pairs(items) do
        if not P.Fits(key, item) then return false end
        local slot, kind = P.slots[key], P.types[item.type]
        if slot.weapon and not slot.off and kind.twoHand and items[slot.pair] then return false end
    end
    return true
end

function P.Move(from, to)
    from = P.OccupiedSlot(from)
    if not from or from == to or not P.saved.items[from] or not P.slots[to] then return false end
    local items = P.Copy(P.saved.items)
    items[from], items[to] = items[to], items[from]
    if not P.ValidLayout(items) then return false, P.words.incompatible end
    P.saved.items = items
    return true
end

-- The off-hand image belongs to the main-hand request, never a second craft.
function P.OccupiedSlot(key)
    local slot = P.slots[key]
    local main = slot and slot.off and P.saved.items[slot.pair]
    return main and P.types[main.type].twoHand and slot.pair or key
end

function P.SlotItem(key)
    return P.saved.items[P.OccupiedSlot(key)]
end

function P.TypesForSlot(key)
    local result = {}
    for _, kind in ipairs(P.typeOrder) do if P.Fits(key, {type = kind.key}) then result[#result + 1] = kind end end
    return result
end

function P.DefaultItem(key)
    local last = P.saved.last or {}
    local kinds, previous = P.TypesForSlot(key), P.types[last.type]
    local kind = kinds[1]
    for _, candidate in ipairs(kinds) do
        if candidate.key == last.type then kind = candidate; break end
        if previous and previous.weight and candidate.weight == previous.weight then kind = candidate end
    end
    local sameCategory = previous and previous.category == kind.category
    return {type = kind.key, set = last.set or 0, trait = sameCategory and last.trait or 0,
        style = last.style or GetUnitRaceId("player"), quality = last.quality or 1,
        level = last.level or 160, cp = last.cp ~= false, enchant = sameCategory and last.enchant or false}
end

function P.GlyphSelection(item)
    if not item.enchant then return nil end
    local kind = P.types[item.type]
    local index = 1
    for i, level in ipairs(O.Enchanting.levels) do
        if item.cp and level.cp and level.cp <= item.level or not item.cp and level.level and level.level <= item.level then index = i end
    end
    return {equipment = kind.category, level = index, effect = item.enchant, quality = item.quality}
end

function P.ValidItem(item)
    local kind = item and P.types[item.type]
    if not kind or not P.Engine.Sets()[item.set] or not P.client.isSmithingLevelValid(item.cp, item.level) then return false end
    if type(item.quality) ~= "number" or item.quality < 1 or item.quality > 5 or item.quality % 1 ~= 0 then return false end
    if type(item.style) ~= "number" or item.style < 1 then return false end
    local validTrait = item.trait == 0
    for i = 1, GetNumSmithingTraitItems() do
        local trait = GetSmithingTraitItemInfo(i)
        if trait == item.trait and ZO_CraftingUtils_GetSmithingFilterFromTrait(trait) ==
            (kind.category == "weapon" and SMITHING_FILTER_TYPE_WEAPONS or kind.category == "jewelry" and SMITHING_FILTER_TYPE_JEWELRY or SMITHING_FILTER_TYPE_ARMOR) then validTrait = true end
    end
    if not validTrait then return false end
    if item.enchant then
        local effect = O.Enchanting.effects[item.enchant]
        if not effect or effect.equipment ~= kind.category or not O.Enchanting.RecipeEngine.RuneIds(P.GlyphSelection(item)) then return false end
    end
    return true
end

function P.Apply(key, item)
    if not P.ValidItem(item) then return false, P.words.invalid end
    local items = P.Copy(P.saved.items)
    items[key] = P.Copy(item)
    if not P.ValidLayout(items) then return false, P.words.incompatible end
    P.saved.items, P.saved.last = items, P.Copy(item)
    return true
end

-- A graph preserves the shared request objects used by smithing + enchanting.
-- ESO SavedVariables cannot save id64 userdata; encode it losslessly as a string.
function P.EncodeQueue(queue)
    local nodes, seen = {}, {}
    local function encode(value)
        if type(value) == "userdata" then return {id64 = Id64ToString(value)} end
        if type(value) ~= "table" then return value end
        if seen[value] then return {node = seen[value]} end
        local id = #nodes + 1
        seen[value], nodes[id] = id, {}
        for k, v in pairs(value) do
            if type(v) ~= "function" then nodes[id][#nodes[id] + 1] = {key = encode(k), value = encode(v)} end
        end
        return {node = id}
    end
    local root = encode(queue)
    return {version = 1, root = root, nodes = nodes}
end

function P.DecodeQueue(snapshot)
    if not snapshot or snapshot.version ~= 1 then return nil end
    local nodes = {}
    for i in ipairs(snapshot.nodes) do nodes[i] = {} end
    local function decode(value)
        if type(value) ~= "table" then return value end
        if value.id64 then return StringToId64(value.id64) end
        return nodes[value.node]
    end
    for i, entries in ipairs(snapshot.nodes) do
        for _, entry in ipairs(entries) do nodes[i][decode(entry.key)] = decode(entry.value) end
    end
    return decode(snapshot.root)
end
