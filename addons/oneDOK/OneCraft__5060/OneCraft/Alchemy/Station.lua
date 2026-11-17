local O, A = OneCraft, OneCraft.Alchemy
local E, C = A.RecipeEngine, A.CraftingIntegration
local effectHistory

function A.LoadSelections()
    local state = O.settings.alchemy
    if type(state) ~= "table" then state = {}; O.settings.alchemy = state end
    if type(state.history) ~= "table" then state.history = {} end
    effectHistory = state.history
    local effects = {}
    if type(state.effects) == "table" then
        for i = 1, 3 do
            local effect = state.effects[i]
            if type(effect) ~= "string" or not A.effects[effect] then break end
            effects[i] = effect
        end
    end
    A.selectedEffects, state.effects = effects, effects
    A.kind = state.kind == 2 and 2 or 1
    A.level = A.SolventSelector.levels[state.level] and state.level or 1
end

local function rememberEffects()
    for position = 1, math.min(2, #A.selectedEffects) do
        local key = table.concat(A.selectedEffects, ":", 1, position)
        local suffix = {}
        for i = position + 1, #A.selectedEffects do suffix[i] = A.selectedEffects[i] end
        effectHistory[key] = suffix
    end
end

function A.ScanInventory()
    A.inventory = {}
    local available = {}
    local function read(bag, slot)
        local crafting, itemType = GetItemCraftingInfo(bag, slot)
        if crafting ~= CRAFTING_TYPE_ALCHEMY or (itemType ~= ITEMTYPE_REAGENT and not IsAlchemySolvent(itemType)) then return end
        local id = GetItemId(bag, slot)
        if not C.Usable(bag, slot, id) then return end
        local icon, count = GetItemInfo(bag, slot)
        local old = A.inventory[id]
        if old then
            old.count = old.count + count
            if count > old.stackCount then old.bag, old.slot, old.stackCount = bag, slot, count end
        else A.inventory[id] = {bag = bag, slot = slot, count = count, stackCount = count, icon = icon} end
        if itemType == ITEMTYPE_REAGENT and A.reagents[id] then
            available[id] = true
            local info = {GetAlchemyItemTraits(bag, slot)}
            for i = 1, 4 do
                if IsAlchemyItemTraitKnown(bag, slot, i) then A.UpdateEffectName(info[(i - 1) * 5 + 1], info[(i - 1) * 5 + 2]) end
            end
        end
    end
    for _, bag in ipairs({BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK}) do
        for slot = 0, GetBagSize(bag) - 1 do read(bag, slot) end
    end
    local slot = GetNextVirtualBagSlotId(nil)
    while slot do read(BAG_VIRTUAL, slot); slot = GetNextVirtualBagSlotId(slot) end
    local thirdSlot = ZO_Alchemy_IsThirdAlchemySlotUnlocked()
    A.recipes = E.Build(available, A.reagents, A.opposites, thirdSlot)
    if not A.catalogRecipes or A.catalogThirdSlot ~= thirdSlot then
        local all = {}
        for id in pairs(A.reagents) do all[id] = true end
        A.catalogRecipes = E.Build(all, A.reagents, A.opposites, thirdSlot)
        A.catalogThirdSlot = thirdSlot
    end
end

function A.EffectOptions(position)
    local prefix = {}
    for i = 1, position - 1 do
        if not A.selectedEffects[i] then return {} end
        prefix[i] = A.selectedEffects[i]
    end
    -- Effect compatibility and recipe previews are independent of stock.
    local allowed, entries = E.Allowed(A.catalogRecipes or A.recipes, prefix), {}
    for key in pairs(allowed) do
        if not A.Contains(prefix, key) then entries[#entries + 1] = A.effects[key] end
    end
    table.sort(entries, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.name < b.name
    end)
    return entries
end

function A.Resolve()
    local solvent = A.SolventSelector.Item(A.level, A.kind)
    local chosen, preferred, preferredAvailable = nil, nil, false
    A.matches = E.Filter(A.catalogRecipes or A.recipes, A.selectedEffects)
    for _, recipe in ipairs(A.matches) do
        local available = A.SolventSelector.Available(A.level, A.kind) and
            E.CraftCount(recipe.ids, A.inventory, solvent) > 0 and C.ExactResult(solvent, recipe.ids)
        if not preferred or (available and not preferredAvailable) or
            (available == preferredAvailable and #recipe.ids < #preferred.ids) then
            preferred, preferredAvailable = recipe, available
        end
        if table.concat(recipe.ids, ":") == A.recipeKey then chosen = recipe end
    end
    chosen = chosen or preferred
    A.selected = chosen and chosen.ids or {}
    A.recipeKey = chosen and table.concat(chosen.ids, ":") or nil
end

function A.Choose(field, value)
    if not A.active or A.IsBusy() then return end
    if field == "kind" then
        if value ~= 1 and value ~= 2 then return end
        A.kind = value
    elseif field == "level" then
        if not A.SolventSelector.levels[value] then return end
        A.level = value
    else
        local position = tonumber(field:match("^effect(%d)$"))
        if not position or position > 3 then return end
        local allowed = value == false
        for _, effect in ipairs(A.EffectOptions(position)) do if effect.key == value then allowed = true end end
        if not allowed then return end
        if A.selectedEffects[position] == (value or nil) then return end
        rememberEffects()
        for i = 3, position, -1 do A.selectedEffects[i] = nil end
        if value then
            A.selectedEffects[position] = value
            local suffix = effectHistory[table.concat(A.selectedEffects, ":", 1, position)]
            if type(suffix) ~= "table" then suffix = nil end
            for i = position + 1, 3 do
                local restored = suffix and suffix[i]
                local allowed = false
                for _, effect in ipairs(A.EffectOptions(i)) do
                    if effect.key == restored then allowed = true; break end
                end
                if not allowed then break end
                A.selectedEffects[i] = restored
            end
        end
    end
    O.settings.alchemy.kind, O.settings.alchemy.level = A.kind, A.level
    rememberEffects()
    ALCHEMY:ResetMultiCraftNumIterations()
    A.Resolve()
    C.Apply()
    A.view:Refresh()
end

function A.Rows(field)
    local entries = {}
    if field == "level" then
        for i, level in ipairs(A.SolventSelector.levels) do
            local item, id = A.SolventSelector.Item(i, A.kind)
            entries[#entries + 1] = {value = i, name = A.SolventSelector.Label(i), icon = O.UI.Icon(A, id),
                count = item and item.count or 0, available = A.SolventSelector.Available(i, A.kind)}
        end
    else
        entries[1] = O.UI.Empty()
        for _, effect in ipairs(A.EffectOptions(tonumber(field:match("%d")))) do
            entries[#entries + 1] = {value = effect.key, name = effect.name, icon = effect.icon}
        end
    end
    return field == "level" and O.SortLevelEntries(entries) or entries
end

function A.Refresh()
    if not A.active or A.IsBusy() then return end
    C.applying = true
    ALCHEMY.inventory:Refresh({})
    A.ScanInventory()
    C.applying = false
    -- Keep choices when stock runs out. A skill respec can invalidate a suffix.
    for position = 1, #A.selectedEffects do
        local found = false
        for _, effect in ipairs(A.EffectOptions(position)) do
            if effect.key == A.selectedEffects[position] then found = true; break end
        end
        if not found then
            for i = 3, position, -1 do A.selectedEffects[i] = nil end
            break
        end
    end
    A.Resolve()
    C.Apply()
    A.view:Refresh()
end

function A.Initialize()
    A.BuildEffectMetadata()
    A.LoadSelections()
    C.Install()
    A.view = O.UI.Create("Alchemy", ALCHEMY, {"level", "effect1", "effect2", "effect3"},
        function(field) return field == "level" and A.text.level or string.format(O.text.effect, tonumber(field:match("%d"))) end,
        A.Rows, A.Choose, function(field) return field == "level" and A.level or A.selectedEffects[tonumber(field:match("%d"))] or false end,
        function() return ALCHEMY.mode == ZO_ALCHEMY_MODE_CREATION end)
    O.UI.Materials(A.view, {ALCHEMY.solventSlot, unpack(ALCHEMY.reagentSlots)}, function()
        if #A.selected < 2 then return {} end
        return {A.SolventSelector.levels[A.level][3 + A.kind], unpack(A.selected)}
    end)
    local bar = WINDOW_MANAGER:CreateControlFromVirtual("OneCraftAlchemyKinds", A.view.panel, "ZO_SmithingCreationTabs")
    A.kindBar = bar
    local iconPrefixes = {
        "EsoUI/Art/TradingHouse/Tradinghouse_Potions_Potionsolvent",
        "EsoUI/Art/TradingHouse/Tradinghouse_Potions_Poisonsolvent",
    }
    for kind = 1, 2 do
        local value = kind
        local prefix = iconPrefixes[kind]
        local button = ZO_MenuBar_AddButton(bar, {descriptor = kind, categoryName = kind == 1 and A.text.potion or A.text.poison,
            normal = prefix .. "_up.dds", pressed = prefix .. "_down.dds",
            highlight = prefix .. "_over.dds", disabled = prefix .. "_disabled.dds",
            alwaysShowTooltip = true,
            callback = function(data)
                bar:GetNamedChild("Active"):SetText(data.categoryName)
                if A.kind ~= value then A.Choose("kind", value) end
            end})
        button:SetHandler("OnMouseEnter", ZO_MenuBarTooltipButton_OnMouseEnter)
        button:SetHandler("OnMouseExit", ZO_MenuBarTooltipButton_OnMouseExit)
    end
    ZO_MenuBar_SelectDescriptor(bar, A.kind)
    ZO_CraftingUtils_ConnectMenuBarToCraftingProcess(bar)
    A.RecipesUI.Initialize()
end
