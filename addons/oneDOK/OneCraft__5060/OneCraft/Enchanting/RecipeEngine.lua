local A = OneCraft.Enchanting
local E = {}
A.RecipeEngine = E

function E.LevelLabel(index)
    local level = A.levels[index]
    return string.format(level.cp and A.text.cpFormat or A.text.levelFormat, level.cp or level.level)
end

function E.QualityLabel(quality)
    return GetString("SI_ITEMQUALITY", quality)
end

function E.RuneName(id)
    return zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(A.ItemLink(id)))
end

function E.EffectName(effect)
    local names = A.effectNames[effect.key]
    return OneCraft.Translate(names[A.isRussian and 2 or 1])
end

function E.EquipmentType(key)
    for _, equipment in ipairs(A.equipmentTypes) do
        if equipment.key == key then return equipment.itemType end
    end
end

function E.RuneIds(selection)
    selection = selection or A.selection
    local level, effect, aspect = A.levels[selection.level], A.effects[selection.effect], A.aspects[selection.quality]
    if not level or not effect or not aspect or effect.disabled or effect.equipment ~= selection.equipment then return nil end
    return {level[effect.polarity], effect.essence, aspect}
end

function E.Count(selection)
    local ids = E.RuneIds(selection)
    if not ids then return 0 end
    local count = math.huge
    for _, id in ipairs(ids) do count = math.min(count, A.inventory[id] and A.inventory[id].count or 0) end
    return count
end

function E.Resolve(selection)
    selection = selection or A.selection
    if not selection.effect then return nil, OneCraft.text.choose end
    local ids = E.RuneIds(selection)
    if not ids then return nil, A.text.rejected end
    local locations, reason = {}, nil
    for i, id in ipairs(ids) do
        local item = A.inventory[id]
        if not item or item.count < 1 then
            reason = reason or string.format(A.text.missing, E.RuneName(id))
        elseif not DoesRunePassRequirements(item.runeType, item.rank, item.rarity) then
            reason = reason or string.format(A.text.skill, E.RuneName(id))
        end
        locations[i] = {bag = item and item.bag, slot = item and item.slot}
    end
    return {ids = ids, locations = locations, selection = A.CopySelection(selection), effect = A.effects[selection.effect]}, reason
end

function E.MatchLink(link, recipe)
    if not link or link == "" then return false end
    if GetItemLinkItemId(link) ~= recipe.effect.itemId then return false end
    if GetItemLinkItemType(link) ~= E.EquipmentType(recipe.selection.equipment) then return false end
    if GetItemLinkFunctionalQuality(link) ~= recipe.selection.quality then return false end
    local actualLevel, actualCP = GetItemLinkGlyphMinLevels(link)
    local wanted = A.levels[recipe.selection.level]
    if wanted.cp then return actualCP == wanted.cp end
    return actualLevel == wanted.level and (not actualCP or actualCP == 0)
end

function E.CheckData()
    A.invalidData = false
    for id, runeType in pairs(A.runeTypes) do
        if GetItemLinkEnchantingRuneClassification(A.ItemLink(id)) ~= runeType then A.invalidData = true end
    end
    for _, effect in ipairs(A.effectList) do
        effect.disabled = GetItemLinkItemType(A.ItemLink(effect.itemId)) ~= E.EquipmentType(effect.equipment)
        if effect.disabled then A.invalidData = true end
    end
end
