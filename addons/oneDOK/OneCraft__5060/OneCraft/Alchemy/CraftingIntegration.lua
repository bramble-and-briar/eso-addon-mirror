local A = OneCraft.Alchemy
local C = {}
A.CraftingIntegration = C

function C.Decode(link)
    local data = link and link:match("|H%d+:item:([^|]+)|h")
    if not data then return nil end
    local fields = {}
    for field in (data .. ":"):gmatch("(.-):") do fields[#fields + 1] = field end
    local encoded = tonumber(fields[21])
    if not encoded then return nil end
    local result = {}
    for _, divisor in ipairs({65536, 256, 1}) do
        local id = math.floor(encoded / divisor) % 64
        if id ~= 0 then
            local effect = A.effectIds[id]
            if not effect then return nil end
            result[effect] = true
        end
    end
    return result
end

local function exact(solvent, reagents)
    if not solvent or not reagents[1] or not reagents[2] then return false end
    local first, second, third = unpack(reagents)
    local link, prospective = GetAlchemyResultingItemLink(solvent.bag, solvent.slot, first.bag, first.slot,
        second.bag, second.slot, third and third.bag, third and third.slot, LINK_STYLE_DEFAULT)
    if prospective == PROSPECTIVE_ALCHEMY_RESULT_UNCRAFTABLE then return false end
    local decoded = C.Decode(link)
    if prospective == PROSPECTIVE_ALCHEMY_RESULT_UNKNOWN then
        if link and link ~= "" and not decoded then return false end
        local ids = {}
        for i, item in ipairs(reagents) do ids[i] = GetItemId(item.bag, item.slot) end
        decoded = A.RecipeEngine.Effects(ids, A.reagents, A.opposites)
    end
    return A.RecipeEngine.Matches(decoded, A.selectedEffects, true)
end

function C.ExactResult(solvent, ids)
    local reagents = {}
    for i, id in ipairs(ids) do
        if not A.inventory[id] then return false end
        reagents[i] = A.inventory[id]
    end
    return exact(solvent, reagents)
end

function C.Usable(bag, slot, id)
    return bag ~= nil and slot ~= nil and GetItemId(bag, slot) == id and
        not IsItemPlayerLocked(bag, slot) and not ZO_CraftingInventory.IsLocked(ALCHEMY.inventory, bag, slot) and
        select(2, GetItemInfo(bag, slot)) > 0
end

function C.Validate()
    if not A.active or C.applying or #A.selected < 2 then return false end
    if #A.selected == 3 and not ZO_Alchemy_IsThirdAlchemySlotUnlocked() then return false end
    local level = A.SolventSelector.levels[A.level]
    if level[3] > GetNonCombatBonus(NON_COMBAT_BONUS_ALCHEMY_LEVEL) then return false end
    local bag, slot = ALCHEMY.solventSlot:GetBagAndSlot()
    if not C.Usable(bag, slot, level[3 + A.kind]) then return false end
    local solvent, reagents = {bag = bag, slot = slot}, {}
    for i = 1, 3 do
        bag, slot = ALCHEMY.reagentSlots[i]:GetBagAndSlot()
        if A.selected[i] then
            if not C.Usable(bag, slot, A.selected[i]) then return false end
            reagents[i] = {bag = bag, slot = slot}
        elseif bag ~= nil then return false end
    end
    return exact(solvent, reagents)
end

function C.Apply()
    if not A.active or A.IsBusy() then return false end
    local solvent = A.SolventSelector.Item(A.level, A.kind)
    C.applying = true
    ALCHEMY:ClearSelections(true, true)
    if #A.selected >= 2 then
        if solvent and C.Usable(solvent.bag, solvent.slot, A.SolventSelector.levels[A.level][3 + A.kind]) then
            ALCHEMY:SetSolventItem(solvent.bag, solvent.slot)
        end
        for i, id in ipairs(A.selected) do
            local item = A.inventory[id]
            if item and C.Usable(item.bag, item.slot, id) then ALCHEMY:SetReagentItem(i, item.bag, item.slot) end
        end
    end
    C.applying = false
    A.status = #A.selectedEffects == 0 and OneCraft.text.choose or
        (not A.SolventSelector.Available(A.level, A.kind) and A.text.solvent or
        (C.Validate() and A.text.ready or A.text.none))
    -- Native OnSlotChanged refreshes keybinds before updating the spinner.
    ALCHEMY:UpdateMultiCraft()
    ALCHEMY:OnSlotChanged()
    return C.Validate()
end

function C.Install()
    for _, slot in ipairs({ALCHEMY.solventSlot, unpack(ALCHEMY.reagentSlots)}) do
        local setItem = slot.SetItem
        slot.SetItem = function(self, bag, index, suppressSound, ignoreUsabilityRequirement)
            return setItem(self, bag, index, C.applying or suppressSound, ignoreUsabilityRequirement)
        end
    end
    local craftable, enabled, create = ALCHEMY.IsCraftable, ALCHEMY.ShouldCraftButtonBeEnabled, ALCHEMY.Create
    ALCHEMY.IsCraftable = function(self, ...)
        if A.active and not C.Validate() then return false end
        return craftable(self, ...)
    end
    ALCHEMY.ShouldCraftButtonBeEnabled = function(self, ...)
        if A.active and not C.Validate() then return false, A.status end
        return enabled(self, ...)
    end
    local maximum = ALCHEMY.GetMultiCraftMaxIterations
    ALCHEMY.GetMultiCraftMaxIterations = function(self, ...)
        if A.active and not C.Validate() then return 0 end
        return maximum(self, ...)
    end
    ALCHEMY.Create = function(self, iterations, ...)
        if A.active then
            if A.IsBusy() then return end
            iterations = iterations or 1
            local maximum = self:GetMultiCraftMaxIterations()
            for _, slotObject in ipairs({self.solventSlot, unpack(self.reagentSlots)}) do
                local bag, slot = slotObject:GetBagAndSlot()
                if bag then
                    local _, stackCount = GetItemInfo(bag, slot)
                    maximum = math.min(maximum, stackCount)
                end
            end
            if not C.Validate() or type(iterations) ~= "number" or iterations % 1 ~= 0 or iterations < 1 or iterations > maximum then
                A.status = A.text.conflict
                A.view:Refresh()
                return
            end
        end
        return create(self, iterations, ...)
    end
end
