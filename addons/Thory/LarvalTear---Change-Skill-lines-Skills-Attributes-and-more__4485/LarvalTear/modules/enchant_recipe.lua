local Addon = LarvalTearMod
local EnchantRecipe = Addon.Modules.EnchantRecipe
local Log = Addon.Common.Log
local Util = Addon.Common.Util
local RecipeStore = Addon.Modules.RecipeStore
local RecipeWatcher = Addon.Modules.RecipeWatcher

RecipeStore:Attach(EnchantRecipe, "enchantRecipeByCharacter", "enchant_recipe_not_found", true)

local function Debug(...)
    Log.Debug("[EnchantRecipe]", ...)
end

local function GetItemIdFromBagSlot(bagId, slotIndex)
    if bagId == nil or slotIndex == nil or type(GetItemId) ~= "function" then
        return nil
    end

    local ok, itemId = pcall(GetItemId, bagId, slotIndex)
    itemId = ok and tonumber(itemId) or nil
    return itemId ~= nil and itemId > 0 and itemId or nil
end

local function IsValidItemId(itemId)
    return type(itemId) == "number" and itemId > 0
end

local function HasBagSlot(bagId, slotIndex)
    return bagId ~= nil and slotIndex ~= nil
end

local function GetEnchantingObject()
    if type(IsInGamepadPreferredMode) == "function" and IsInGamepadPreferredMode() == true then
        local gamepadEnchanting = rawget(_G, "GAMEPAD_ENCHANTING")
        if type(gamepadEnchanting) == "table" then
            return gamepadEnchanting
        end
    end

    local enchanting = rawget(_G, "ENCHANTING")
    if type(enchanting) == "table" then
        return enchanting
    end

    enchanting = rawget(_G, "GAMEPAD_ENCHANTING")
    return type(enchanting) == "table" and enchanting or nil
end

local function GetRuneConstant(name)
    return rawget(_G, name)
end

local function GetRuneSlot(enchanting, runeType)
    local runeSlots = type(enchanting) == "table" and enchanting.runeSlots or nil
    local slot = type(runeSlots) == "table" and runeSlots[runeType] or nil
    return type(slot) == "table" and slot or nil
end

local function GetEnchantingMode(enchanting)
    if type(enchanting) ~= "table" or type(enchanting.GetEnchantingMode) ~= "function" then
        return nil
    end

    local ok, mode = pcall(enchanting.GetEnchantingMode, enchanting)
    return ok and mode or nil
end

local function IsCreationMode(enchanting)
    local creationMode = rawget(_G, "ENCHANTING_MODE_CREATION")
    if creationMode == nil then
        return true
    end

    return GetEnchantingMode(enchanting) == creationMode
end

local function ReadRuneSlot(enchanting, runeConstantName)
    local runeType = GetRuneConstant(runeConstantName)
    local runeSlot = GetRuneSlot(enchanting, runeType)
    if type(runeSlot) ~= "table" or type(runeSlot.GetBagAndSlot) ~= "function" then
        return nil, nil, nil
    end

    local ok, bagId, slotIndex = pcall(runeSlot.GetBagAndSlot, runeSlot)
    if not ok then
        return nil, nil, nil
    end

    return bagId, slotIndex, GetItemIdFromBagSlot(bagId, slotIndex)
end

local function ReadCurrentStationSlots()
    local enchanting = GetEnchantingObject()
    if type(enchanting) ~= "table" or not IsCreationMode(enchanting) then
        return nil
    end

    local potencyBag, potencySlot, potencyItemId = ReadRuneSlot(enchanting, "ENCHANTING_RUNE_POTENCY")
    local essenceBag, essenceSlot, essenceItemId = ReadRuneSlot(enchanting, "ENCHANTING_RUNE_ESSENCE")
    local aspectBag, aspectSlot, aspectItemId = ReadRuneSlot(enchanting, "ENCHANTING_RUNE_ASPECT")

    return {
        potencyBag = potencyBag,
        potencySlot = potencySlot,
        potencyItemId = potencyItemId,
        essenceBag = essenceBag,
        essenceSlot = essenceSlot,
        essenceItemId = essenceItemId,
        aspectBag = aspectBag,
        aspectSlot = aspectSlot,
        aspectItemId = aspectItemId,
    }
end

local function GetSearchBagsForCrafting()
    local bags = {}
    local backpackBag = rawget(_G, "BAG_BACKPACK")
    if backpackBag ~= nil then
        bags[#bags + 1] = backpackBag
    end

    local virtualBag = rawget(_G, "BAG_VIRTUAL")
    if virtualBag ~= nil then
        bags[#bags + 1] = virtualBag
    end

    return bags
end

local function GetSlotStackCount(bagId, slotIndex)
    if bagId == nil or slotIndex == nil then
        return 0
    end

    if type(GetSlotStackSize) == "function" then
        local ok, stackCount = pcall(GetSlotStackSize, bagId, slotIndex)
        if ok and tonumber(stackCount) ~= nil then
            return tonumber(stackCount) or 0
        end
    end

    if type(GetItemTotalCount) == "function" then
        local ok, stackCount = pcall(GetItemTotalCount, bagId, slotIndex)
        if ok and tonumber(stackCount) ~= nil then
            return tonumber(stackCount) or 0
        end
    end

    return 0
end

local function GetCraftingRuneType(bagId, slotIndex)
    if bagId == nil or slotIndex == nil or type(GetItemCraftingInfo) ~= "function" then
        return nil
    end

    local ok, _, _, runeType = pcall(GetItemCraftingInfo, bagId, slotIndex)
    return ok and runeType or nil
end

local function AddBagToInventoryIndex(inventoryIndex, bagId)
    local function AddSlot(slotIndex)
        local itemId = GetItemIdFromBagSlot(bagId, slotIndex)
        if itemId == nil or itemId <= 0 then
            return
        end

        local stackCount = GetSlotStackCount(bagId, slotIndex)
        local itemEntry = inventoryIndex.itemsByItemId[itemId]
        if type(itemEntry) ~= "table" then
            inventoryIndex.itemsByItemId[itemId] = {
                bagId = bagId,
                slotIndex = slotIndex,
                stackCount = stackCount,
                totalStackCount = stackCount,
            }
        else
            itemEntry.totalStackCount = (tonumber(itemEntry.totalStackCount) or 0) + stackCount
        end
    end

    if type(ZO_IterateBagSlots) == "function" then
        for slotIndex in ZO_IterateBagSlots(bagId) do
            AddSlot(slotIndex)
        end
    elseif type(GetBagSize) == "function" then
        local ok, bagSize = pcall(GetBagSize, bagId)
        bagSize = ok and tonumber(bagSize) or 0
        for slotIndex = 0, bagSize - 1 do
            AddSlot(slotIndex)
        end
    end
end

local function BuildCraftingInventoryIndex()
    local inventoryIndex = {
        itemsByItemId = {},
    }
    for _, bagId in ipairs(GetSearchBagsForCrafting()) do
        AddBagToInventoryIndex(inventoryIndex, bagId)
    end
    return inventoryIndex
end

local function BuildInventoryItemState(itemId, expectedRuneType, inventoryIndex)
    itemId = tonumber(itemId)
    if itemId == nil or itemId <= 0 then
        return {
            itemId = itemId,
            found = false,
            runeTypeValid = false,
            bagId = nil,
            slotIndex = nil,
            stackCount = 0,
            totalStackCount = 0,
        }
    end

    local itemEntry = type(inventoryIndex) == "table"
        and type(inventoryIndex.itemsByItemId) == "table"
        and inventoryIndex.itemsByItemId[itemId]
        or nil
    local bagId = type(itemEntry) == "table" and itemEntry.bagId or nil
    local slotIndex = type(itemEntry) == "table" and itemEntry.slotIndex or nil
    if type(itemEntry) == "table" and itemEntry.runeTypeRead ~= true then
        itemEntry.runeType = GetCraftingRuneType(bagId, slotIndex)
        itemEntry.runeTypeRead = true
    end
    local runeType = type(itemEntry) == "table" and itemEntry.runeType or nil
    local runeTypeValid = expectedRuneType == nil or runeType == expectedRuneType
    return {
        itemId = itemId,
        found = bagId ~= nil and slotIndex ~= nil and runeTypeValid == true,
        runeTypeValid = runeTypeValid,
        runeType = runeType,
        bagId = bagId,
        slotIndex = slotIndex,
        stackCount = type(itemEntry) == "table" and (tonumber(itemEntry.stackCount) or 0) or 0,
        totalStackCount = type(itemEntry) == "table" and (tonumber(itemEntry.totalStackCount) or 0) or 0,
    }
end

local function GetMissingRequiredInventoryReason(inventoryState)
    if type(inventoryState) ~= "table" then
        return "inventory_unavailable"
    end
    if type(inventoryState.potency) ~= "table" or inventoryState.potency.found ~= true then
        return "item_not_found:potency"
    end
    if type(inventoryState.essence) ~= "table" or inventoryState.essence.found ~= true then
        return "item_not_found:essence"
    end
    if type(inventoryState.aspect) ~= "table" or inventoryState.aspect.found ~= true then
        return "item_not_found:aspect"
    end

    return nil
end

local function CallEnchantingMethod(enchanting, methodName, ...)
    local method = type(enchanting) == "table" and enchanting[methodName] or nil
    if type(method) ~= "function" then
        return false, "enchanting_method_unavailable:" .. tostring(methodName)
    end

    local ok, result = pcall(method, enchanting, ...)
    if not ok then
        return false, result
    end

    return true, result
end

local function ApplyCraftCountToEnchantingSpinner(count)
    if type(IsInGamepadPreferredMode) == "function" and IsInGamepadPreferredMode() == true then
        return false, "gamepad_spinner_skipped"
    end

    local enchanting = GetEnchantingObject()
    if type(enchanting) ~= "table" then
        return false, "enchanting_unavailable"
    end

    local spinner = rawget(enchanting, "multiCraftSpinner")
    if type(spinner) ~= "table" or type(spinner.SetValue) ~= "function" then
        return false, "spinner_unavailable"
    end

    local ok, result = pcall(spinner.SetValue, spinner, RecipeStore.NormalizeCraftCount(count))
    if not ok then
        return false, "spinner_set_failed"
    end

    return true, result
end

local function GetEnchantingScene()
    local scene = rawget(_G, "ENCHANTING_SCENE")
    if scene ~= nil then
        return scene
    end
    return rawget(_G, "GAMEPAD_ENCHANTING_CREATION_SCENE")
end

local function GetResultingItemLink(slots)
    if type(slots) ~= "table" or type(GetEnchantingResultingItemLink) ~= "function" then
        return nil
    end

    if not HasBagSlot(slots.potencyBag, slots.potencySlot)
        or not HasBagSlot(slots.essenceBag, slots.essenceSlot)
        or not HasBagSlot(slots.aspectBag, slots.aspectSlot) then
        return nil
    end

    local ok, itemLink = pcall(
        GetEnchantingResultingItemLink,
        slots.potencyBag,
        slots.potencySlot,
        slots.essenceBag,
        slots.essenceSlot,
        slots.aspectBag,
        slots.aspectSlot
    )
    if ok and type(itemLink) == "string" and itemLink ~= "" then
        return itemLink
    end

    return nil
end

local function OnEnchantingSceneStateChange(_, newState)
    if not RecipeWatcher.IsSceneShowingState(newState) then
        return
    end
    if EnchantRecipe:GetAutoApplyEnabled() ~= true then
        return
    end

    local recipeId = EnchantRecipe:GetActiveRecipeId()
    if recipeId == nil then
        return
    end

    local ok, result = EnchantRecipe:ApplyRecipeToStation(recipeId)
    if ok then
        Debug("autoApply", "succeeded=true", "recipeId=" .. tostring(recipeId))
    else
        Debug("autoApply", "succeeded=false", "recipeId=" .. tostring(recipeId), "reason=" .. tostring(result))
    end
end

local function GetItemLinkDisplayName(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" or type(GetItemLinkName) ~= "function" then
        return nil
    end

    local ok, displayName = pcall(GetItemLinkName, itemLink)
    if ok then
        return Util:NormalizeDisplayName(displayName)
    end

    return nil
end

RecipeWatcher.Attach(EnchantRecipe, {
    stationInteractName = "LTM_EnchantRecipe_StationInteract",
    stationEndName = "LTM_EnchantRecipe_StationEnd",
    craftingTypeName = "CRAFTING_TYPE_ENCHANTING",
    updateName = "LTM_EnchantRecipe_EnchantingSceneRetry",
    callbackRegisteredField = "enchantingSceneCallbackRegistered",
    retryScheduledField = "enchantingSceneCallbackRetryScheduled",
    getScene = GetEnchantingScene,
    onSceneStateChange = OnEnchantingSceneStateChange,
    debug = Debug,
    retryExhaustedMessage = "EnchantingSceneCallback retry exhausted",
})

function EnchantRecipe:Initialize(savedVars)
    self.savedVars = savedVars
    RecipeWatcher.Initialize(self)
end

function EnchantRecipe:NormalizeRecipe(recipe)
    if type(recipe) ~= "table" then
        return nil
    end

    recipe.id = RecipeStore.NormalizeRecipeId(recipe.id)
    recipe.name = Util:NormalizeDisplayName(recipe.name) or recipe.id or "Recipe"
    recipe.potencyItemId = tonumber(recipe.potencyItemId)
    recipe.essenceItemId = tonumber(recipe.essenceItemId)
    recipe.aspectItemId = tonumber(recipe.aspectItemId)
    recipe.craftCount = RecipeStore.NormalizeCraftCount(recipe.craftCount)
    return recipe
end

function EnchantRecipe:IsStationOpen()
    return GetEnchantingObject() ~= nil and RecipeWatcher.IsSceneOpen(self, GetEnchantingScene())
end

function EnchantRecipe:BuildInventoryIndex()
    return BuildCraftingInventoryIndex()
end

function EnchantRecipe:GetRecipeInventoryState(recipeId, inventoryIndex)
    local recipe, err = RecipeStore.GetRecipe(self, recipeId)
    if type(recipe) ~= "table" then
        return nil, err or "recipe_not_found"
    end

    if type(inventoryIndex) ~= "table" or type(inventoryIndex.itemsByItemId) ~= "table" then
        inventoryIndex = BuildCraftingInventoryIndex()
    end

    local potencyType = GetRuneConstant("ENCHANTING_RUNE_POTENCY")
    local essenceType = GetRuneConstant("ENCHANTING_RUNE_ESSENCE")
    local aspectType = GetRuneConstant("ENCHANTING_RUNE_ASPECT")
    local potencyState = BuildInventoryItemState(recipe.potencyItemId, potencyType, inventoryIndex)
    local essenceState = BuildInventoryItemState(recipe.essenceItemId, essenceType, inventoryIndex)
    local aspectState = BuildInventoryItemState(recipe.aspectItemId, aspectType, inventoryIndex)

    return {
        potency = potencyState,
        essence = essenceState,
        aspect = aspectState,
        allRequiredFound = potencyState.found == true
            and essenceState.found == true
            and aspectState.found == true,
    }
end

local function SetRuneSlotItem(enchanting, runeConstantName, itemState)
    local runeType = GetRuneConstant(runeConstantName)
    local runeSlot = GetRuneSlot(enchanting, runeType)
    if type(runeSlot) ~= "table" or type(runeSlot.SetItem) ~= "function" then
        return false, "rune_slot_unavailable:" .. tostring(runeConstantName)
    end
    if type(itemState) ~= "table" or not HasBagSlot(itemState.bagId, itemState.slotIndex) then
        return false, "item_slot_unavailable:" .. tostring(runeConstantName)
    end

    local itemRuneType = GetCraftingRuneType(itemState.bagId, itemState.slotIndex)
    if itemRuneType ~= runeType then
        return false, "rune_type_mismatch:" .. tostring(runeConstantName)
    end

    local ok, err = pcall(runeSlot.SetItem, runeSlot, itemState.bagId, itemState.slotIndex)
    if not ok then
        return false, err
    end

    return true
end

function EnchantRecipe:ApplyRecipeToStation(recipeId)
    local enchanting = GetEnchantingObject()
    if type(enchanting) ~= "table" then
        return false, "enchanting_unavailable"
    end
    if self:IsStationOpen() ~= true then
        return false, "station_not_open"
    end
    if not IsCreationMode(enchanting) then
        return false, "not_in_creation_mode"
    end
    if type(enchanting.runeSlots) ~= "table" or type(enchanting.ClearSelections) ~= "function" then
        return false, "enchanting_methods_unavailable"
    end

    local recipe, recipeErr = RecipeStore.GetRecipe(self, recipeId)
    if type(recipe) ~= "table" then
        return false, recipeErr or "recipe_not_found"
    end

    local inventoryState, inventoryErr = self:GetRecipeInventoryState(recipe.id)
    if type(inventoryState) ~= "table" then
        return false, inventoryErr or "inventory_unavailable"
    end

    local missingReason = GetMissingRequiredInventoryReason(inventoryState)
    if missingReason ~= nil then
        return false, missingReason
    end

    local ok, err = CallEnchantingMethod(enchanting, "ClearSelections")
    if not ok then
        return false, err or "clear_selections_failed"
    end

    ok, err = SetRuneSlotItem(enchanting, "ENCHANTING_RUNE_POTENCY", inventoryState.potency)
    if not ok then
        return false, err or "set_potency_failed"
    end

    ok, err = SetRuneSlotItem(enchanting, "ENCHANTING_RUNE_ESSENCE", inventoryState.essence)
    if not ok then
        return false, err or "set_essence_failed"
    end

    ok, err = SetRuneSlotItem(enchanting, "ENCHANTING_RUNE_ASPECT", inventoryState.aspect)
    if not ok then
        return false, err or "set_aspect_failed"
    end

    local craftCount = RecipeStore.NormalizeCraftCount(recipe.craftCount)
    local spinnerOk, spinnerErr = ApplyCraftCountToEnchantingSpinner(craftCount)
    if spinnerOk ~= true then
        Debug(
            "craftCountSpinner",
            "skipped=true",
            "recipeId=" .. tostring(recipe.id),
            "craftCount=" .. tostring(craftCount),
            "reason=" .. tostring(spinnerErr)
        )
    end

    return true, {
        recipeId = recipe.id,
        recipe = Util:DeepCopy(recipe),
        craftCount = craftCount,
        inventoryState = inventoryState,
        potencyBag = inventoryState.potency.bagId,
        potencySlot = inventoryState.potency.slotIndex,
        essenceBag = inventoryState.essence.bagId,
        essenceSlot = inventoryState.essence.slotIndex,
        aspectBag = inventoryState.aspect.bagId,
        aspectSlot = inventoryState.aspect.slotIndex,
    }
end

function EnchantRecipe:UpsertRecipeFromSlots(slots, name)
    if type(slots) ~= "table" then
        return nil, "invalid_slots"
    end
    if not IsValidItemId(slots.potencyItemId)
        or not IsValidItemId(slots.essenceItemId)
        or not IsValidItemId(slots.aspectItemId) then
        return nil, "invalid_rune_item"
    end

    local bucket = self:EnsureCharacterBucketForWrite()
    if type(bucket) ~= "table" then
        return nil, "saved_vars_unavailable"
    end

    local recipeId = self:GenerateRecipeId(bucket)
    if recipeId == nil then
        return nil, "recipe_id_unavailable"
    end

    local timestamp = Util:GetTimestamp()
    local recipe = {
        id = recipeId,
        name = Util:NormalizeDisplayName(name)
            or GetItemLinkDisplayName(slots.resultItemLink)
            or RecipeStore.BuildDefaultRecipeName(recipeId),
        notes = "",
        potencyItemId = slots.potencyItemId,
        essenceItemId = slots.essenceItemId,
        aspectItemId = slots.aspectItemId,
        resultItemLink = slots.resultItemLink,
        craftCount = 1,
        createdAt = timestamp,
        updatedAt = timestamp,
    }

    return RecipeStore.AddRecipe(self, bucket, recipe)
end

function EnchantRecipe:CaptureFromStation(name)
    if self.isStationOpen ~= true then
        return nil, "station_not_open"
    end

    local enchanting = GetEnchantingObject()
    if type(enchanting) ~= "table" then
        return nil, "enchanting_unavailable"
    end
    if not IsCreationMode(enchanting) then
        return nil, "not_in_creation_mode"
    end

    local slots = ReadCurrentStationSlots()
    if type(slots) ~= "table" then
        return nil, "enchanting_unavailable"
    end

    if not HasBagSlot(slots.potencyBag, slots.potencySlot)
        or not HasBagSlot(slots.essenceBag, slots.essenceSlot)
        or not HasBagSlot(slots.aspectBag, slots.aspectSlot) then
        return nil, "runes_insufficient"
    end
    if not IsValidItemId(slots.potencyItemId)
        or not IsValidItemId(slots.essenceItemId)
        or not IsValidItemId(slots.aspectItemId) then
        return nil, "invalid_rune_item"
    end

    slots.resultItemLink = GetResultingItemLink(slots)
    return self:UpsertRecipeFromSlots(slots, name)
end
