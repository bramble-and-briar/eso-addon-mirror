local A = OneCraft.Enchanting
local C = {}
A.CraftingIntegration = C

function C.OwnsStation()
    return A.active and ENCHANTING:GetEnchantingMode() == ENCHANTING_MODE_CREATION
end

function C.Check(recipe, locations)
    if not recipe or not locations or A.IsBusy() then return false, A.text.unavailable end
    local arguments, maximum = {}, math.huge
    for index, id in ipairs(recipe.ids) do
        local location = locations[index]
        if not location or not A.Inventory.Usable(location.bag, location.slot, id) then return false, A.text.unavailable end
        local crafting, _, runeType, rank, rarity = GetItemCraftingInfo(location.bag, location.slot)
        if crafting ~= CRAFTING_TYPE_ENCHANTING or runeType ~= A.runeTypes[id] then return false, A.text.rejected end
        if not DoesRunePassRequirements(runeType, rank, rarity) then return false, A.text.unavailable end
        arguments[#arguments + 1], arguments[#arguments + 2] = location.bag, location.slot
        local _, stackCount = GetItemInfo(location.bag, location.slot)
        maximum = math.min(maximum, stackCount)
    end
    local known = AreAllEnchantingRunesKnown(unpack(arguments))
    local gameMaximum = GetMaxIterationsPossibleForEnchantingItem(unpack(arguments))
    if not gameMaximum or gameMaximum < 1 then return false, A.text.unavailable end
    maximum = math.min(maximum, gameMaximum)
    if not known then maximum = math.min(maximum, 1) end
    arguments[7] = LINK_STYLE_DEFAULT
    local link = GetEnchantingResultingItemLink(unpack(arguments))
    if link and link ~= "" then
        if not A.RecipeEngine.MatchLink(link, recipe) then return false, A.text.rejected end
    elseif known then
        return false, A.text.rejected
    end
    return true, known and A.text.ready or A.text.unknown, link, known, maximum
end

function C.Validate()
    if not C.OwnsStation() or C.applying or A.suspended then return false, A.text.clear end
    local recipe, reason = A.RecipeEngine.Resolve()
    if not recipe then return false, reason end
    local locations = {}
    for index, runeType in ipairs({ENCHANTING_RUNE_POTENCY, ENCHANTING_RUNE_ESSENCE, ENCHANTING_RUNE_ASPECT}) do
        local bag, slot = ENCHANTING.runeSlots[runeType]:GetBagAndSlot()
        locations[index] = {bag = bag, slot = slot}
    end
    return C.Check(recipe, locations)
end

function C.Apply()
    if not C.OwnsStation() or A.IsBusy() then return false end
    A.suspended = false
    local recipe, reason = A.RecipeEngine.Resolve()
    local valid, status = false, reason
    if recipe then valid, status = C.Check(recipe, recipe.locations) end
    C.applying = true
    ENCHANTING:ClearSelections()
    if recipe then
        for i, location in ipairs(recipe.locations) do
            if A.Inventory.Usable(location.bag, location.slot, recipe.ids[i]) then
                local _, _, runeType, rank, rarity = GetItemCraftingInfo(location.bag, location.slot)
                if DoesRunePassRequirements(runeType, rank, rarity) then ENCHANTING:AddItemToCraft(location.bag, location.slot) end
            end
        end
    end
    C.applying = false
    if valid then valid, status = C.Validate() end
    A.status = status or A.text.rejected
    ENCHANTING:UpdateMultiCraft()
    ENCHANTING:OnSlotChanged()
    return valid
end

function C.Install()
    for _, slot in pairs(ENCHANTING.runeSlots) do
        local setItem = slot.SetItem
        slot.SetItem = function(self, bag, index)
            if not C.applying then return setItem(self, bag, index) end
            local placeSound, removeSound = self.placeSound, self.pendingRemoveSound
            self.placeSound, self.pendingRemoveSound = SOUNDS.NONE, SOUNDS.NONE
            local ok, result = pcall(setItem, self, bag, index)
            self.placeSound, self.pendingRemoveSound = placeSound, removeSound
            if not ok then error(result, 0) end
            return result
        end
    end
    local originalCraftable = ENCHANTING.IsCraftable
    ENCHANTING.IsCraftable = function(self, ...)
        if C.OwnsStation() and not C.Validate() then return false end
        return originalCraftable(self, ...)
    end
    local originalEnabled = ENCHANTING.ShouldCraftButtonBeEnabled
    ENCHANTING.ShouldCraftButtonBeEnabled = function(self, ...)
        if C.OwnsStation() then
            local valid, reason = C.Validate()
            if not valid then return false, reason end
        end
        return originalEnabled(self, ...)
    end
    local originalMaximum = ENCHANTING.GetMultiCraftMaxIterations
    ENCHANTING.GetMultiCraftMaxIterations = function(self, ...)
        if C.OwnsStation() then
            local valid, _, _, _, maximum = C.Validate()
            if not valid then return 0 end
            return math.min(originalMaximum(self, ...), maximum)
        end
        return originalMaximum(self, ...)
    end
    local originalCreate = ENCHANTING.Create
    ENCHANTING.Create = function(self, iterations, ...)
        if C.OwnsStation() then
            local valid, _, _, _, maximum = C.Validate()
            if iterations == nil then iterations = 1 end
            if not valid or type(iterations) ~= "number" or iterations ~= math.floor(iterations) or iterations < 1 or iterations > maximum then
                A.status = A.text.conflict
                A.EnchantingUI.Refresh()
                return
            end
        end
        return originalCreate(self, iterations, ...)
    end
    local originalClear = ENCHANTING.ClearSelections
    ENCHANTING.ClearSelections = function(self, ...)
        if C.OwnsStation() and not C.applying then A.suspended, A.status = true, A.text.clear end
        return originalClear(self, ...)
    end
    local originalTooltip = ENCHANTING.UpdateTooltip
    C.OriginalTooltip = originalTooltip
    ENCHANTING.UpdateTooltip = function(self, ...)
        if C.OwnsStation() then
            if not C.applying then A.EnchantingUI.Preview() end
            return
        end
        return originalTooltip(self, ...)
    end
    ZO_PostHook(ENCHANTING, "OnSlotChanged", function()
        if C.OwnsStation() and not C.applying then
            local valid, reason = C.Validate()
            if not A.suspended then A.status = reason or (valid and A.text.ready or A.text.conflict) end
            A.EnchantingUI.Refresh()
        end
    end)
end
