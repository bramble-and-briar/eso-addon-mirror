local O, A = OneCraft, OneCraft.Enchanting
local E, C = A.RecipeEngine, A.CraftingIntegration

function A.Choose(field, value)
    if not A.active or A.IsBusy() then return end
    if field == "level" then
        if not A.levels[value] then return end
    elseif field == "quality" then
        if not A.aspects[value] then return end
    elseif field == "equipment" then
        if not E.EquipmentType(value) then return end
        if A.selection.equipment ~= value then A.selection.effect = false end
    elseif field == "effect" then
        local effect = A.effects[value]
        if value ~= false and (not effect or effect.disabled or effect.equipment ~= A.selection.equipment) then return end
    else return end
    A.selection[field] = value
    ENCHANTING:ResetMultiCraftNumIterations()
    C.Apply()
    A.view:Refresh()
end

function A.Rows(field)
    local entries = {}
    local function add(value, name, id, quality)
        local item = id and A.inventory[id]
        local available = not item or DoesRunePassRequirements(item.runeType, item.rank, item.rarity)
        entries[#entries + 1] = {value = value, name = name, icon = id and O.UI.Icon(A, id),
            count = item and item.count, quality = quality, available = available}
    end
    if field == "equipment" then
        for _, equipment in ipairs(A.equipmentTypes) do add(equipment.key, A.text[equipment.key], equipment.glyphId) end
    elseif field == "level" then
        local effect = A.effects[A.selection.effect]
        for index, level in ipairs(A.levels) do add(index, E.LevelLabel(index), level[effect and effect.polarity or "positive"]) end
    elseif field == "effect" then
        entries[1] = O.UI.Empty()
        local effects = {}
        for _, effect in ipairs(A.effectList) do
            if effect.equipment == A.selection.equipment and not effect.disabled then effects[#effects + 1] = effect end
        end
        table.sort(effects, function(a, b) return E.EffectName(a) < E.EffectName(b) end)
        for _, effect in ipairs(effects) do add(effect.key, E.EffectName(effect), effect.itemId) end
    else
        for quality, id in ipairs(A.aspects) do add(quality, E.QualityLabel(quality), id, quality) end
    end
    return field == "level" and O.SortLevelEntries(entries) or entries
end

function A.Refresh()
    if not A.active or A.IsBusy() then return end
    C.applying = true
    ENCHANTING.inventory:Refresh({})
    A.Inventory.Scan()
    C.applying = false
    if not A.suspended then C.Apply() end
    A.view:Refresh()
end

-- The native tooltip supplies real values whenever the game can resolve the runes.
-- An empty/unknown recipe gets a neutral explanation without fabricated stats.
A.EnchantingUI = {}
function A.EnchantingUI.Preview()
    if not A.active or C.applying or A.IsBusy() then return end
    local valid, _, link = C.Validate()
    if valid and link and link ~= "" then C.OriginalTooltip(ENCHANTING); return end
    local tooltip, effect = ENCHANTING.resultTooltip, A.effects[A.selection.effect]
    tooltip:ClearLines()
    tooltip:GetNamedChild("Icon"):SetTexture(effect and O.UI.Icon(A, effect.itemId) or O.noneTexture)
    tooltip:AddLine(effect and E.EffectName(effect) or O.text.choose, "ZoFontWinH2", 1, 1, 1)
    if effect then tooltip:AddLine(A.status or A.text.predicted, "ZoFontGame", 0.8, 0.8, 0.8) end
    tooltip:SetHidden(false)
end
function A.EnchantingUI.Refresh()
    if A.view then A.view:Refresh(); A.EnchantingUI.Preview() end
end

function A.Initialize()
    E.CheckData()
    C.Install()
    A.view = O.UI.Create("Enchanting", ENCHANTING, {"equipment", "level", "effect", "quality"},
        function(field) return A.text[field] end, A.Rows, A.Choose, function(field) return A.selection[field] end,
        function() return ENCHANTING:GetEnchantingMode() == ENCHANTING_MODE_CREATION end)
    O.UI.Materials(A.view, {ENCHANTING.runeSlots[ENCHANTING_RUNE_POTENCY],
        ENCHANTING.runeSlots[ENCHANTING_RUNE_ESSENCE], ENCHANTING.runeSlots[ENCHANTING_RUNE_ASPECT]}, function()
        if A.suspended then return {} end
        return E.RuneIds() or {}
    end)
    ZO_PostHook(ENCHANTING, "OnSlotChanged", function() if A.active then A.EnchantingUI.Preview() end end)
end
