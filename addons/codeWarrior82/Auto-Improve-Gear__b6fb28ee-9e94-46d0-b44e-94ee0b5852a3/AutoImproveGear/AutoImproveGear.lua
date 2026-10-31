local appName = "AutoImproveGear"

--adjust this value to move all confirmation screen text up or down
local textOffsetY = 40
local materialsGap = 7

local initialized = false

--selection screen state
local selectionItems = {}
local selectionScreen
local selectionFragment
local selectionControl
local itemsHeadingControl
local materialsHeadingControl
local itemsBodyControl
local materialsBodyControl
local confirmationMessageControl
local processingMessageControl
local processingDebugControl
local selectionKeybindStateIndex
local backKeybindDescriptor

--single-item test processor state
local processingState = {
    active = false,
    awaitingCompletion = false,
    attemptId = 0,
    item = nil,
    craftingType = nil,
    previousQuality = nil,
    debugLines = {},
    succeeded = false,
    finished = false,
}
local MAX_PROCESSING_DEBUG_LINES = 9
local IMPROVEMENT_EVENT_TIMEOUT_MS = 15000
local restoreAutoImproveKeybind
local improveKeybindDescriptor

--equipment names for each crafting station
local equipmentTypes = {
    [CRAFTING_TYPE_BLACKSMITHING] = {
        "cuirass", "sabatons", "gauntlets", "helm",
        "greaves", "pauldron", "girdle", "axe",
        "mace", "sword", "battle axe", "maul",
        "greatsword", "dagger",
    },
    [CRAFTING_TYPE_CLOTHIER] = {
        "robe", "shirt", "shoes", "gloves", "hat",
        "breeches", "epaulets", "sash", "jack",
        "boots", "bracers", "helmet", "guards",
        "arm cops", "belt",
    },
    [CRAFTING_TYPE_WOODWORKING] = {
        "shield", "bow", "inferno staff", "ice staff",
        "lightning staff", "restoration staff",
    },
    [CRAFTING_TYPE_JEWELRYCRAFTING] = {
        "ring", "necklace",
    },
}

--print a message to chat
local function printMessage(msg)
    local chat = LibChatMessage(appName, "MA")
    chat:Print(msg)
end

--set to false to confirm with a normal tap instead of a hold
local requireHoldToConfirm = true

local HOLD_ACTION_NAME = "AUTOIMPROVEGEAR_CONFIRM_HOLD"
local HOLD_LAYER_NAME = "AutoImproveGearHoldLayer"
--ignore a hold that started before the confirm screen appeared
local HOLD_IGNORE_AFTER_PUSH_MS = 400

--name shown for the hold binding in the controls menu
ZO_CreateStringId("SI_BINDING_NAME_" .. HOLD_ACTION_NAME, "Confirm Improvements (Hold)")

local holdBindingReady = false
local holdLayerPushed = false
local holdLayerPushedMs = 0

--register square hold as the default key for the hold action
local function createHoldBinding()
    if type(CreateDefaultActionBind) ~= "function" or not KEY_GAMEPAD_BUTTON_3_HOLD then
        return
    end

    local ok = pcall(CreateDefaultActionBind, HOLD_ACTION_NAME, KEY_GAMEPAD_BUTTON_3_HOLD)
    if not ok then
        pcall(
            CreateDefaultActionBind,
            HOLD_ACTION_NAME,
            KEY_GAMEPAD_BUTTON_3_HOLD,
            KEY_INVALID,
            KEY_INVALID,
            KEY_INVALID,
            KEY_INVALID
        )
    end
end

--check that the hold action exists and has a key bound to it
local function refreshHoldBindingState()
    holdBindingReady = false

    if type(GetHighestPriorityActionBindingInfoFromName) ~= "function" then
        return
    end

    local ok, key = pcall(GetHighestPriorityActionBindingInfoFromName, HOLD_ACTION_NAME, true)
    if ok and key and key ~= (KEY_INVALID or 0) then
        holdBindingReady = true
    end
end

--turn the hold action layer on only while the confirm screen is showing
local function setHoldLayerActive(active)
    if active and not holdLayerPushed then
        if pcall(PushActionLayerByName, HOLD_LAYER_NAME) then
            holdLayerPushed = true
            holdLayerPushedMs = GetGameTimeMilliseconds()
        end
    elseif not active and holdLayerPushed then
        pcall(RemoveActionLayerByName, HOLD_LAYER_NAME)
        holdLayerPushed = false
    end
end

--check whether an item name matches the station list
local function isRelevantItem(itemName, craftingType)
    if not itemName or not equipmentTypes[craftingType] then
        return false
    end

    local lowerName = string.lower(itemName)

    for _, equipmentName in ipairs(equipmentTypes[craftingType]) do
        local startPosition = 1

        while true do
            local first, last = string.find(lowerName, equipmentName, startPosition, true)

            if not first then
                break
            end

            local before = first == 1 and "" or lowerName:sub(first - 1, first - 1)
            local after = last == #lowerName and "" or lowerName:sub(last + 1, last + 1)

            local beforeIsBoundary = before == "" or before:match("[^%a]") ~= nil
            local afterIsBoundary = after == "" or after:match("[^%a]") ~= nil

            if beforeIsBoundary and afterIsBoundary then
                return true
            end

            startPosition = first + 1
        end
    end

    return false
end

--check whether an item belongs to the current crafting station
local function isValidEquipmentItem(slotIndex, craftingType)
    --keep the existing name search if item type information is unavailable
    if not GetItemType or not ITEMTYPE_ARMOR or not ITEMTYPE_WEAPON then
        return true
    end

    local itemType = GetItemType(BAG_BACKPACK, slotIndex)
    local _, _, _, _, _, equipType = GetItemInfo(BAG_BACKPACK, slotIndex)

    if craftingType == CRAFTING_TYPE_BLACKSMITHING then
        if itemType == ITEMTYPE_WEAPON then
            return true
        end

        if itemType == ITEMTYPE_ARMOR and GetItemArmorType then
            return GetItemArmorType(BAG_BACKPACK, slotIndex) == ARMORTYPE_HEAVY
        end

        return false
    elseif craftingType == CRAFTING_TYPE_CLOTHIER then
        if itemType == ITEMTYPE_ARMOR and GetItemArmorType then
            local armorType = GetItemArmorType(BAG_BACKPACK, slotIndex)
            return armorType == ARMORTYPE_LIGHT or armorType == ARMORTYPE_MEDIUM
        end

        return false
    elseif craftingType == CRAFTING_TYPE_WOODWORKING then
        if itemType == ITEMTYPE_WEAPON then
            return true
        end

        if itemType == ITEMTYPE_ARMOR and GetItemWeaponType then
            return GetItemWeaponType(BAG_BACKPACK, slotIndex) == WEAPONTYPE_SHIELD
        end

        return false
    elseif craftingType == CRAFTING_TYPE_JEWELRYCRAFTING then
        if itemType == ITEMTYPE_ARMOR and equipType ~= nil
            and EQUIP_TYPE_RING and EQUIP_TYPE_NECK then
            return equipType == EQUIP_TYPE_RING or equipType == EQUIP_TYPE_NECK
        end

        return false
    end

    return false
end

--find unlocked matching items in the backpack
local function scanBackpack(craftingType)
    local items = {}

    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if GetSlotStackSize(BAG_BACKPACK, slotIndex) > 0
            and not IsItemPlayerLocked(BAG_BACKPACK, slotIndex) then

            local itemName = GetItemName(BAG_BACKPACK, slotIndex)

            --remove the trailing eso name-format suffix
            if itemName and #itemName >= 2 then
                local suffix = itemName:sub(-2)

                if suffix:sub(1, 1) == "^" then
                    itemName = itemName:sub(1, -3)
                end
            end

            if isRelevantItem(itemName, craftingType)
                and isValidEquipmentItem(slotIndex, craftingType) then
                table.insert(items, {
                    slotIndex = slotIndex,
                    itemName = itemName,
                })
            end
        end
    end

    return items
end

--create the custom selection screen class
local AutoImproveGearSelectionScreen = ZO_Gamepad_ParametricList_Screen:Subclass()

local selectionMode = "items"
local qualityOptions = {
    { name = "Fine", quality = 2 },
    { name = "Superior", quality = 3 },
    { name = "Epic", quality = 4 },
    { name = "Legendary", quality = 5 },
}
local selectedQualityName
local pendingImprovementSummary

local qualityNamesByValue = {
    [1] = "Normal",
    [2] = "Fine",
    [3] = "Superior",
    [4] = "Epic",
    [5] = "Legendary",
}

local function updateSelectionKeybinds()
    --The custom Square hold layer is active only on the existing summary screen.
    setHoldLayerActive(requireHoldToConfirm and holdBindingReady and selectionMode == "summary")

    if not selectionScreen then
        return
    end

    local primaryDescriptor = selectionScreen.primaryKeybindDescriptor
    if primaryDescriptor then
        if selectionMode == "finalConfirm" then
            primaryDescriptor.name = "Confirm and Start"
            primaryDescriptor.enabled = function()
                return pendingImprovementSummary ~= nil
                    and pendingImprovementSummary.enoughMaterials
                    and #pendingImprovementSummary.items == 1
            end
        elseif selectionMode == "processing" then
            primaryDescriptor.name = "|c808080Confirm and Start|r"
            primaryDescriptor.enabled = function() return false end
        elseif selectionMode == "complete" then
            primaryDescriptor.name = "Done"
            primaryDescriptor.enabled = function() return true end
        else
            if selectionMode == "quality" or selectionMode == "summary" then
                primaryDescriptor.name = "Select"
            else
                primaryDescriptor.name = "Select / Deselect"
            end
            primaryDescriptor.enabled = function()
                return selectionMode ~= "summary"
            end
        end
        primaryDescriptor.visible = function() return true end
    end

    if improveKeybindDescriptor then
        local holdSquareMarkup = "|t48:48:EsoUI/Art/Buttons/Gamepad/ps4/nav_ps4_square_hold.dds|t"
        if selectionMode == "summary" then
            improveKeybindDescriptor.name = "|c808080Improve Selected Items|r  " .. holdSquareMarkup .. "Confirm and Improve"
            improveKeybindDescriptor.visible = function() return true end
            improveKeybindDescriptor.enabled = function() return true end
        elseif selectionMode == "processing" then
            improveKeybindDescriptor.name = "|c808080Processing...|r  " .. holdSquareMarkup
            improveKeybindDescriptor.visible = function() return true end
            improveKeybindDescriptor.enabled = function() return false end
        elseif selectionMode == "complete" then
            --Restore the Square label's normal appearance after processing.
            improveKeybindDescriptor.name = "Upgrade Test Finished  " .. holdSquareMarkup
            improveKeybindDescriptor.visible = function() return true end
            improveKeybindDescriptor.enabled = function() return true end
        else
            improveKeybindDescriptor.name = "Improve Selected Items"
            improveKeybindDescriptor.visible = function() return selectionMode ~= "finalConfirm" end
            improveKeybindDescriptor.enabled = function() return selectionMode ~= "processing" end
        end
        improveKeybindDescriptor.keybind = "UI_SHORTCUT_SECONDARY"
    end

    if backKeybindDescriptor then
        if selectionMode == "processing" then
            backKeybindDescriptor.name = "|c808080" .. GetString(SI_GAMEPAD_BACK_OPTION) .. "|r"
            backKeybindDescriptor.enabled = function() return false end
        elseif selectionMode == "finalConfirm" then
            backKeybindDescriptor.name = "Back"
            backKeybindDescriptor.enabled = function() return true end
        elseif selectionMode == "complete" then
            backKeybindDescriptor.name = "Back to Items"
            backKeybindDescriptor.enabled = function() return true end
        else
            backKeybindDescriptor.name = GetString(SI_GAMEPAD_BACK_OPTION)
            backKeybindDescriptor.enabled = function() return true end
        end
        backKeybindDescriptor.visible = function() return true end
    end

    if selectionKeybindStateIndex then
        --Refresh the group so updated labels and enabled states are applied.
        KEYBIND_STRIP:RemoveKeybindButtonGroup(
            selectionScreen.keybindStripDescriptor,
            selectionKeybindStateIndex
        )
        KEYBIND_STRIP:AddKeybindButtonGroup(
            selectionScreen.keybindStripDescriptor,
            selectionKeybindStateIndex
        )
        KEYBIND_STRIP:UpdateKeybindButtonGroup(selectionScreen.keybindStripDescriptor)
    end
end

local function showQualitySelection()
    local selectedCount = 0

    for _, item in ipairs(selectionItems) do
        if item.selected then
            selectedCount = selectedCount + 1
        end
    end

    if selectedCount == 0 then
        return
    end

    selectionMode = "quality"
    selectedQualityName = nil
    for _, quality in ipairs(qualityOptions) do
        quality.selected = false
    end
    selectionScreen:Update()
    updateSelectionKeybinds()
end

local function getSelectedItems()
    local selected = {}

    for _, item in ipairs(selectionItems) do
        if item.selected then
            table.insert(selected, item)
        end
    end

    return selected
end

--find the rank of the improvement expertise passive for the current crafting type
local function getImprovementExpertiseRank(craftingType)
    local passiveNames = {
        [CRAFTING_TYPE_BLACKSMITHING] = "Temper Expertise",
        [CRAFTING_TYPE_CLOTHIER] = "Tannin Expertise",
        [CRAFTING_TYPE_WOODWORKING] = "Resin Expertise",
        [CRAFTING_TYPE_JEWELRYCRAFTING] = "Platings Expertise",
    }
    local passiveName = passiveNames[craftingType]

    if not passiveName or not GetNumSkillLines or not GetNumSkillAbilities
        or not GetSkillAbilityInfo or not GetSkillAbilityUpgradeInfo then
        return 0
    end

    for skillLineIndex = 1, GetNumSkillLines(SKILL_TYPE_TRADESKILL) do
        local abilityCount = GetNumSkillAbilities(SKILL_TYPE_TRADESKILL, skillLineIndex)

        for abilityIndex = 1, abilityCount do
            local abilityName, _, _, isPassive = GetSkillAbilityInfo(
                SKILL_TYPE_TRADESKILL,
                skillLineIndex,
                abilityIndex
            )

            if isPassive and abilityName == passiveName then
                local currentUpgradeLevel = GetSkillAbilityUpgradeInfo(
                    SKILL_TYPE_TRADESKILL,
                    skillLineIndex,
                    abilityIndex
                )
                return math.max(0, math.min(3, currentUpgradeLevel or 0))
            end
        end
    end

    --use the highest material requirement if the passive cannot be found
    return 0
end

--find the number of boosters needed for a guaranteed improvement on the current item quality
local function getGuaranteedBoosterCount(item, craftingType)
    local bagId = item.bagId or BAG_BACKPACK
    for boosterCount = 1, 1000 do
        local chance = GetSmithingImprovementChance(bagId, item.slotIndex, boosterCount, craftingType)
        if chance and chance >= 100 then
            return boosterCount
        end
    end

    return nil
end

--calculate the guaranteed booster count for a future quality using the passive rank
local function getBoosterCountForQuality(fromQuality, expertiseRank)
    local boosterCountsByRank = {
        { 5, 7, 10, 20 },
        { 4, 5, 7, 14 },
        { 3, 4, 5, 10 },
        { 2, 3, 4, 8 },
    }

    local rankCounts = boosterCountsByRank[expertiseRank + 1]
    return rankCounts and rankCounts[fromQuality] or nil
end

--read improvement materials supplied by the current crafting station
local function getImprovementMaterials(craftingType)
    local materials = {}
    local materialCount = GetNumSmithingImprovementItems()

    for index = 1, materialCount do
        local name, icon, stackCount = GetSmithingImprovementItemInfo(craftingType, index)
        local link = GetSmithingImprovementItemLink(craftingType, index, LINK_STYLE_DEFAULT)
        local itemId = link and GetItemLinkItemId(link)
        local available = stackCount or 0

        --count materials from the backpack, bank and craft bag
        if link and GetItemLinkInventoryCount
            and INVENTORY_COUNT_BAG_OPTION_BACKPACK_AND_BANK_AND_CRAFT_BAG then
            available = GetItemLinkInventoryCount(
                link,
                INVENTORY_COUNT_BAG_OPTION_BACKPACK_AND_BANK_AND_CRAFT_BAG
            ) or available
        elseif link and GetItemLinkStacks then
            local backpackCount, bankCount, craftBagCount = GetItemLinkStacks(link)
            available = (backpackCount or 0) + (bankCount or 0) + (craftBagCount or 0)
        end

        --remove the trailing eso name-format suffix
        if name and #name >= 2 then
            local suffix = name:sub(-2)

            if suffix:sub(1, 1) == "^" then
                name = name:sub(1, -3)
            end
        end

        if name and itemId then
            materials[index] = {
                index = index,
                name = name,
                itemId = itemId,
                available = available,
                required = 0,
                quality = index + 1,
            }
        end
    end

    return materials
end

--calculate material requirements for the selected items
local function calculateMaterialRequirements(selectedItems, targetQuality, craftingType)
    local materials = getImprovementMaterials(craftingType)
    local expertiseRank = getImprovementExpertiseRank(craftingType)

    for _, item in ipairs(selectedItems) do
        local itemQuality = select(8, GetItemInfo(BAG_BACKPACK, item.slotIndex))

        if itemQuality and targetQuality > itemQuality then
            for nextQuality = itemQuality + 1, targetQuality do
                local fromQuality = nextQuality - 1
                local material = materials[fromQuality]
                local boosterCount

                if fromQuality == itemQuality then
                    --use the game's live chance calculation for the item's current quality
                    boosterCount = getGuaranteedBoosterCount(item, craftingType)
                else
                    --future quality steps use the character's improvement expertise rank
                    boosterCount = getBoosterCountForQuality(fromQuality, expertiseRank)
                end

                if material and boosterCount then
                    material.required = material.required + boosterCount
                end
            end
        end
    end

    return materials
end

local function createImprovementItemRecord(item, craftingType, targetQuality, targetQualityName)
    local bagId = BAG_BACKPACK
    local itemLink = GetItemLink and GetItemLink(bagId, item.slotIndex, LINK_STYLE_DEFAULT) or nil
    local itemId = GetItemId and GetItemId(bagId, item.slotIndex) or (itemLink and GetItemLinkItemId and GetItemLinkItemId(itemLink))
    local instanceId = GetItemInstanceId and GetItemInstanceId(bagId, item.slotIndex) or nil
    local currentQuality = select(8, GetItemInfo(bagId, item.slotIndex))
    local itemType = GetItemType and GetItemType(bagId, item.slotIndex) or nil
    local _, _, _, _, _, equipType = GetItemInfo(bagId, item.slotIndex)

    return {
        bagId = bagId,
        slotIndex = item.slotIndex,
        itemName = item.itemName,
        itemLink = itemLink,
        itemId = itemId,
        instanceId = instanceId,
        itemType = itemType,
        equipType = equipType,
        craftingType = craftingType,
        originalQuality = currentQuality,
        currentQuality = currentQuality,
        targetQuality = targetQuality,
        targetQualityName = targetQualityName,
        boosterCountsUsed = {},
        materialsUsed = {},
        lastCraftResult = nil,
        failedReason = nil,
        completed = false,
        failed = false,
    }
end

local function confirmSelectedQuality(qualityName)
    local selectedItems = getSelectedItems()
    local selectedCount = #selectedItems

    if selectedCount == 0 then
        return
    end

    local craftingType = GetCraftingInteractionType()
    local targetQuality
    for _, quality in ipairs(qualityOptions) do
        if quality.name == qualityName then
            targetQuality = quality.quality
            break
        end
    end

    if not craftingType or not targetQuality then
        return
    end

    local materials = calculateMaterialRequirements(selectedItems, targetQuality, craftingType)

    local enoughMaterials = true
    for _, material in ipairs(materials) do
        if material.required > material.available then
            enoughMaterials = false
        end
    end

    local itemRecords = {}
    for _, item in ipairs(selectedItems) do
        table.insert(itemRecords, createImprovementItemRecord(item, craftingType, targetQuality, qualityName))
    end

    pendingImprovementSummary = {
        items = itemRecords,
        targetQuality = targetQuality,
        targetQualityName = qualityName,
        craftingType = craftingType,
        materials = materials,
        enoughMaterials = enoughMaterials,
    }
    selectionMode = "summary"
    selectionScreen:Update()
    updateSelectionKeybinds()
end

local function appendProcessingDebug(message)
    local timestamp = GetGameTimeMilliseconds and math.floor(GetGameTimeMilliseconds() / 1000) or 0
    table.insert(processingState.debugLines, string.format("[%ds] %s", timestamp, tostring(message)))

    while #processingState.debugLines > MAX_PROCESSING_DEBUG_LINES do
        table.remove(processingState.debugLines, 1)
    end

    if processingDebugControl then
        processingDebugControl:SetText(table.concat(processingState.debugLines, "\n"))
    end
end

local function finishProcessing(success, message)
    processingState.active = false
    processingState.awaitingCompletion = false
    processingState.finished = true
    processingState.succeeded = success

    if processingState.item then
        processingState.item.completed = success
        processingState.item.failed = not success
        if success then
            processingState.item.failedReason = nil
        else
            processingState.item.failedReason = message
        end
    end

    appendProcessingDebug(message)
    selectionMode = "complete"
    if processingMessageControl then
        processingMessageControl:SetText(success and "Upgrade complete" or "Upgrade stopped - see debug details below")
    end
    selectionScreen:Update()
    updateSelectionKeybinds()
end

local function getCurrentTrackedQuality(item)
    if not item or not GetItemInfo then
        return nil
    end
    return select(8, GetItemInfo(item.bagId, item.slotIndex))
end

local function verifyTrackedItemStillInSlot(item)
    if not item then
        return false, "No item record"
    end

    if not GetSlotStackSize or GetSlotStackSize(item.bagId, item.slotIndex) <= 0 then
        return false, "Recorded inventory slot is empty"
    end

    if item.itemId and GetItemId then
        local currentItemId = GetItemId(item.bagId, item.slotIndex)
        if currentItemId ~= item.itemId then
            return false, "Item ID in recorded slot no longer matches"
        end
    end

    if item.instanceId and GetItemInstanceId then
        local currentInstanceId = GetItemInstanceId(item.bagId, item.slotIndex)
        if currentInstanceId ~= item.instanceId then
            return false, "Item instance in recorded slot no longer matches"
        end
    end

    local currentName = GetItemName and GetItemName(item.bagId, item.slotIndex) or nil
    if currentName then
        local normalizedName = currentName:gsub("%^[%a]+$", "")
        if normalizedName ~= item.itemName then
            return false, "Item name in recorded slot no longer matches"
        end
    end

    return true
end

local function startNextImprovementStep()
    if not processingState.active then
        return
    end

    local item = processingState.item
    local craftingType = processingState.craftingType
    if not item then
        finishProcessing(false, "FAIL: processing item record is missing")
        return
    end

    appendProcessingDebug("Checking recorded item and inventory slot")
    local itemStillPresent, identityError = verifyTrackedItemStillInSlot(item)
    if not itemStillPresent then
        finishProcessing(false, "FAIL: " .. identityError)
        return
    end

    local currentQuality = getCurrentTrackedQuality(item)
    if not currentQuality then
        finishProcessing(false, "FAIL: unable to read current item quality")
        return
    end

    item.currentQuality = currentQuality
    appendProcessingDebug("Current quality=" .. tostring(currentQuality) .. ", target=" .. tostring(item.targetQuality))

    if currentQuality >= item.targetQuality then
        finishProcessing(true, "SUCCESS: target quality reached")
        return
    end

    if type(CanItemBeSmithingImproved) ~= "function" then
        finishProcessing(false, "FAIL: CanItemBeSmithingImproved API unavailable")
        return
    end

    local canImprove = CanItemBeSmithingImproved(item.bagId, item.slotIndex, craftingType)
    appendProcessingDebug("CanItemBeSmithingImproved=" .. tostring(canImprove))
    if not canImprove then
        finishProcessing(false, "FAIL: game reports item cannot be improved")
        return
    end

    if type(GetSmithingImprovementChance) ~= "function" then
        finishProcessing(false, "FAIL: GetSmithingImprovementChance API unavailable")
        return
    end

    local boosterCount = getGuaranteedBoosterCount({ slotIndex = item.slotIndex, bagId = item.bagId }, craftingType)
    if not boosterCount then
        finishProcessing(false, "FAIL: no 100% booster quantity found within safety limit")
        return
    end

    local chance = GetSmithingImprovementChance(item.bagId, item.slotIndex, boosterCount, craftingType)
    appendProcessingDebug("Chance check: " .. tostring(boosterCount) .. " boosters => " .. tostring(chance) .. "%")
    if not chance or chance < 100 then
        finishProcessing(false, "FAIL: calculated booster quantity is not 100%")
        return
    end

    if type(ImproveSmithingItem) ~= "function" then
        finishProcessing(false, "FAIL: ImproveSmithingItem API unavailable")
        return
    end

    processingState.previousQuality = currentQuality
    processingState.awaitingCompletion = true
    processingState.attemptId = processingState.attemptId + 1
    local attemptId = processingState.attemptId
    item.boosterCountsUsed[currentQuality] = boosterCount
    local materialName, materialIcon, materialStack
    if GetSmithingImprovementItemInfo then
        materialName, materialIcon, materialStack = GetSmithingImprovementItemInfo(craftingType, currentQuality)
    end
    local materialLink = GetSmithingImprovementItemLink
        and GetSmithingImprovementItemLink(craftingType, currentQuality, LINK_STYLE_DEFAULT) or nil
    item.materialsUsed[currentQuality] = {
        name = materialName,
        itemId = materialLink and GetItemLinkItemId and GetItemLinkItemId(materialLink) or nil,
        link = materialLink,
        quantity = boosterCount,
    }
    appendProcessingDebug("Material for this step=" .. tostring(materialName) .. ", quantity=" .. tostring(boosterCount))

    appendProcessingDebug("Calling ImproveSmithingItem(" .. tostring(item.bagId) .. ", " .. tostring(item.slotIndex) .. ", " .. tostring(boosterCount) .. ")")
    local callSucceeded, callError = pcall(ImproveSmithingItem, item.bagId, item.slotIndex, boosterCount)
    if not callSucceeded then
        processingState.awaitingCompletion = false
        finishProcessing(false, "FAIL: ImproveSmithingItem raised error: " .. tostring(callError))
        return
    end
    appendProcessingDebug("ImproveSmithingItem call returned without Lua error")

    zo_callLater(function()
        if not processingState.active or not processingState.awaitingCompletion
            or processingState.attemptId ~= attemptId then
            return
        end

        appendProcessingDebug("TIMEOUT: no crafting completion event received")
        local updatedQuality = getCurrentTrackedQuality(item)
        if updatedQuality and updatedQuality > processingState.previousQuality then
            appendProcessingDebug("Timeout fallback: item quality changed to " .. tostring(updatedQuality))
            item.currentQuality = updatedQuality
            processingState.awaitingCompletion = false
            startNextImprovementStep()
        else
            processingState.awaitingCompletion = false
            finishProcessing(false, "FAIL: completion event missing and item quality unchanged")
        end
    end, IMPROVEMENT_EVENT_TIMEOUT_MS)
end

local function handleCraftCompleted(eventCode, craftingType)
    if not processingState.active or not processingState.awaitingCompletion then
        return
    end

    if craftingType and processingState.craftingType and craftingType ~= processingState.craftingType then
        appendProcessingDebug("Ignoring unrelated craft completion event: " .. tostring(craftingType))
        return
    end

    appendProcessingDebug("EVENT_CRAFT_COMPLETED received: " .. tostring(craftingType))
    local resultName, resultStack, resultQuality, resultInstanceId
    if type(GetLastCraftingResultItemInfo) == "function" then
        local resultOk, name, icon, stack, sellPrice, meetsRequirements,
            equipType, itemType, style, quality, sound, instanceId =
            pcall(GetLastCraftingResultItemInfo, 1)
        if resultOk then
            resultName = name
            resultStack = stack
            resultQuality = quality
            resultInstanceId = instanceId
            appendProcessingDebug("GetLastCraftingResultItemInfo(1) returned data")
        else
            appendProcessingDebug("GetLastCraftingResultItemInfo failed: " .. tostring(name))
        end
    else
        appendProcessingDebug("GetLastCraftingResultItemInfo API unavailable")
    end

    appendProcessingDebug("Craft result: " .. tostring(resultName) .. ", stack=" .. tostring(resultStack)
        .. ", quality=" .. tostring(resultQuality) .. ", instance=" .. tostring(resultInstanceId))

    local item = processingState.item
    item.lastCraftResult = {
        name = resultName,
        stack = resultStack,
        quality = resultQuality,
        instanceId = resultInstanceId,
    }
    local attemptId = processingState.attemptId

    --Ignore an unrelated craft result if its identity can be distinguished.
    local currentInstanceId = GetItemInstanceId and GetItemInstanceId(item.bagId, item.slotIndex) or nil
    local resultNameMatches = false
    if resultName then
        local normalizedResultName = resultName:gsub("%^[%a]+$", "")
        resultNameMatches = normalizedResultName == item.itemName
    end
    local resultInstanceMatches = resultInstanceId and currentInstanceId
        and tostring(resultInstanceId) == tostring(currentInstanceId)
    if (resultInstanceId or resultName) and not resultInstanceMatches and not resultNameMatches then
        appendProcessingDebug("Ignoring completion: result does not match tracked item")
        return
    end

    processingState.awaitingCompletion = false

    --Allow the inventory update associated with the crafting event to settle before reading quality.
    zo_callLater(function()
        if not processingState.active or processingState.attemptId ~= attemptId then
            return
        end

        local updatedQuality = getCurrentTrackedQuality(item)
        appendProcessingDebug("Backpack quality after event=" .. tostring(updatedQuality))

        if updatedQuality and updatedQuality > processingState.previousQuality then
            item.currentQuality = updatedQuality
            local newInstanceId = GetItemInstanceId and GetItemInstanceId(item.bagId, item.slotIndex) or nil
            if newInstanceId then
                item.instanceId = newInstanceId
            end
            appendProcessingDebug("Verified item quality increased to " .. tostring(updatedQuality))
            startNextImprovementStep()
        else
            finishProcessing(false, "FAIL: craft completed but item quality did not increase")
        end
    end, 250)
end

local function handleCraftFailed(eventCode, resultCode)
    if not processingState.active or not processingState.awaitingCompletion then
        return
    end

    appendProcessingDebug("EVENT_CRAFT_FAILED received: result=" .. tostring(resultCode))
    processingState.awaitingCompletion = false
    finishProcessing(false, "FAIL: game reported crafting failure " .. tostring(resultCode))
end

local function handleCraftStarted(eventCode, craftingType)
    if not processingState.active then
        return
    end

    if craftingType and processingState.craftingType and craftingType ~= processingState.craftingType then
        return
    end

    appendProcessingDebug("EVENT_CRAFT_STARTED received: " .. tostring(craftingType))
end

local function registerImprovementEvents()
    if EVENT_CRAFT_STARTED then
        EVENT_MANAGER:RegisterForEvent(appName .. "_CraftStarted", EVENT_CRAFT_STARTED, handleCraftStarted)
    end
    if EVENT_CRAFT_COMPLETED then
        EVENT_MANAGER:RegisterForEvent(appName .. "_CraftCompleted", EVENT_CRAFT_COMPLETED, handleCraftCompleted)
    end
    if EVENT_CRAFT_FAILED then
        EVENT_MANAGER:RegisterForEvent(appName .. "_CraftFailed", EVENT_CRAFT_FAILED, handleCraftFailed)
    end
end

local function startSingleItemTest()
    if not pendingImprovementSummary then
        return
    end

    if not pendingImprovementSummary.enoughMaterials then
        appendProcessingDebug("Blocked: material requirements are not met")
        return
    end

    if #pendingImprovementSummary.items ~= 1 then
        processingState.active = false
        processingState.awaitingCompletion = false
        processingState.finished = true
        processingState.succeeded = false
        processingState.debugLines = {}
        appendProcessingDebug("TEST LIMIT: exactly one selected item is required")
        processingMessageControl:SetText("Testing currently supports one item only.\nPlease go back and select exactly one item.")
        selectionMode = "complete"
        selectionScreen:Update()
        updateSelectionKeybinds()
        return
    end

    local item = pendingImprovementSummary.items[1]
    processingState.active = true
    processingState.awaitingCompletion = false
    processingState.attemptId = 0
    processingState.item = item
    processingState.craftingType = pendingImprovementSummary.craftingType
    processingState.previousQuality = nil
    processingState.debugLines = {}
    processingState.succeeded = false
    processingState.finished = false

    selectionMode = "processing"
    processingMessageControl:SetText("Upgrading items\nPlease wait..\nDon't press any buttons..")
    processingDebugControl:SetText("")
    selectionScreen:Update()
    updateSelectionKeybinds()

    appendProcessingDebug("Test process started for one item")
    appendProcessingDebug("Item: " .. tostring(item.itemName))
    appendProcessingDebug("Item ID=" .. tostring(item.itemId) .. ", instance=" .. tostring(item.instanceId))
    appendProcessingDebug("Slot=" .. tostring(item.bagId) .. "/" .. tostring(item.slotIndex)
        .. ", station=" .. tostring(item.craftingType))
    appendProcessingDebug("Target quality=" .. tostring(item.targetQuality))
    appendProcessingDebug("Craft events available: started=" .. tostring(EVENT_CRAFT_STARTED ~= nil)
        .. ", completed=" .. tostring(EVENT_CRAFT_COMPLETED ~= nil)
        .. ", failed=" .. tostring(EVENT_CRAFT_FAILED ~= nil))

    startNextImprovementStep()
end

local function confirmImprovementSummary()
    if not pendingImprovementSummary then return end
    if not pendingImprovementSummary.enoughMaterials then
        printMessage("Not enough materials.")
        return
    end
    selectionMode = "finalConfirm"
    selectionScreen:Update()
    updateSelectionKeybinds()
end

local function returnToAvailableItems()
    processingState.active = false
    processingState.awaitingCompletion = false
    processingState.finished = false
    pendingImprovementSummary = nil
    selectionMode = "items"
    selectionScreen:Update()
    updateSelectionKeybinds()
end

local function closeSelectionOverlay()
    setHoldLayerActive(false)
    if selectionFragment then
        SCENE_MANAGER:RemoveFragment(selectionFragment)
    end
    if selectionKeybindStateIndex then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(
            selectionScreen.keybindStripDescriptor,
            selectionKeybindStateIndex
        )
        KEYBIND_STRIP:PopKeybindGroupState()
        selectionKeybindStateIndex = nil
    end
    if restoreAutoImproveKeybind then
        restoreAutoImproveKeybind()
    end
end

--called by Bindings.xml when the hold key goes down
function AutoImproveGear_OnConfirmHoldDown()
    if selectionMode ~= "summary" then
        return
    end

    if GetGameTimeMilliseconds() - holdLayerPushedMs < HOLD_IGNORE_AFTER_PUSH_MS then
        return
    end

    confirmImprovementSummary()
end

local function capitalizeFirstLetter(value)
    return (value:gsub("^%l", string.upper))
end

function AutoImproveGearSelectionScreen:InitializeKeybindStripDescriptors()
    local primaryDescriptor = {
        name = "Select / Deselect",
        keybind = "UI_SHORTCUT_PRIMARY",
        callback = function()
            if selectionMode == "processing" then
                return
            elseif selectionMode == "finalConfirm" then
                startSingleItemTest()
                return
            elseif selectionMode == "complete" then
                closeSelectionOverlay()
                return
            end

            local list = self:GetMainList()
            local entryData = list:GetSelectedData()

            if selectionMode == "summary" then
                return
            elseif selectionMode == "quality" then
                if entryData and entryData.qualityName then
                    selectedQualityName = selectedQualityName == entryData.qualityName and nil or entryData.qualityName
                    for _, quality in ipairs(qualityOptions) do
                        quality.selected = quality.name == selectedQualityName
                    end
                    self:Update()
                end
            elseif entryData and entryData.item then
                entryData.item.selected = not entryData.item.selected
                self:Update()
            end
        end,
    }

    primaryDescriptor.enabled = function()
        return selectionMode ~= "summary" and selectionMode ~= "processing"
    end

    self.primaryKeybindDescriptor = primaryDescriptor
    self.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        primaryDescriptor,
        {
            name = "Improve Selected Items",
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function()
                return selectionMode ~= "finalConfirm"
            end,
            enabled = function()
                return selectionMode ~= "processing"
            end,
            callback = function()
                if selectionMode == "processing" or selectionMode == "complete" or selectionMode == "finalConfirm" then
                    return
                end
                if selectionMode == "summary" then
                    --With the hold binding a normal press does nothing; the hold confirms.
                    if not (requireHoldToConfirm and holdBindingReady) then
                        confirmImprovementSummary()
                    end
                    return
                end

                if selectionMode == "quality" then
                    if selectedQualityName then
                        confirmSelectedQuality(selectedQualityName)
                    end
                else
                    showQualitySelection()
                end
            end,
        },
        {
            name = GetString(SI_GAMEPAD_BACK_OPTION),
            keybind = "UI_SHORTCUT_NEGATIVE",
            visible = function() return true end,
            enabled = function() return selectionMode ~= "processing" end,
            callback = function()
                if selectionMode == "processing" then
                    return
                elseif selectionMode == "finalConfirm" then
                    selectionMode = "summary"
                    self:Update()
                    updateSelectionKeybinds()
                    return
                elseif selectionMode == "complete" then
                    returnToAvailableItems()
                    return
                end

                if selectionMode == "summary" then
                    selectionMode = "quality"
                    self:Update()
                    updateSelectionKeybinds()
                    return
                end

                if selectionMode == "quality" then
                    selectionMode = "items"
                    self:Update()
                    updateSelectionKeybinds()
                    return
                end

                closeSelectionOverlay()
            end,
        },
    }
    improveKeybindDescriptor = self.keybindStripDescriptor[2]
    backKeybindDescriptor = self.keybindStripDescriptor[3]
end

function AutoImproveGearSelectionScreen:PerformUpdate()
    local list = self:GetMainList()
    list:Clear()

    if selectionMode == "finalConfirm" then
        if itemsHeadingControl then itemsHeadingControl:SetHidden(true) end
        if itemsBodyControl then itemsBodyControl:SetHidden(true) end
        if confirmationMessageControl then
            confirmationMessageControl:SetHidden(false)
            local confirmationLines = { "You are about to use" }
            if pendingImprovementSummary then
                for _, material in ipairs(pendingImprovementSummary.materials) do
                    if material.required > 0 then
                        local materialName = capitalizeFirstLetter(material.name)
                        local qualityColor = material.quality and GetItemQualityColor(material.quality)
                        if qualityColor then
                            materialName = qualityColor:Colorize(materialName)
                        end
                        table.insert(confirmationLines,
                            materialName .. " " .. tostring(material.required))
                    end
                end
                table.insert(confirmationLines,
                    "to upgrade " .. tostring(#pendingImprovementSummary.items) .. " items...")
            else
                table.insert(confirmationLines, "to upgrade 0 items...")
            end
            table.insert(confirmationLines, "")
            table.insert(confirmationLines, "Do you want to start the process ?")
            confirmationMessageControl:SetText(table.concat(confirmationLines, "\n"))
        end
        if materialsHeadingControl then materialsHeadingControl:SetHidden(true) end
        if materialsBodyControl then materialsBodyControl:SetHidden(true) end
        if processingMessageControl then processingMessageControl:SetHidden(true) end
        if processingDebugControl then processingDebugControl:SetHidden(true) end
        list:Commit()
        self.headerData = { titleText = "Confirm Upgrade" }
    elseif selectionMode == "processing" or selectionMode == "complete" then
        if itemsHeadingControl then itemsHeadingControl:SetHidden(true) end
        if materialsHeadingControl then materialsHeadingControl:SetHidden(true) end
        if itemsBodyControl then itemsBodyControl:SetHidden(true) end
        if materialsBodyControl then materialsBodyControl:SetHidden(true) end
        if confirmationMessageControl then confirmationMessageControl:SetHidden(true) end
        if processingMessageControl then processingMessageControl:SetHidden(false) end
        if processingDebugControl then processingDebugControl:SetHidden(false) end
        if selectionMode == "processing" then
            processingMessageControl:SetText("Upgrading items\nPlease wait..\nDon't press any buttons..")
        end
        list:Commit()
        self.headerData = { titleText = selectionMode == "processing" and "Upgrading Items" or "Upgrade Test Results" }
    elseif selectionMode == "summary" then
        if confirmationMessageControl then confirmationMessageControl:SetHidden(true) end
        if processingMessageControl then processingMessageControl:SetHidden(true) end
        if processingDebugControl then processingDebugControl:SetHidden(true) end
        if itemsHeadingControl then itemsHeadingControl:SetHidden(false) end
        if materialsHeadingControl then materialsHeadingControl:SetHidden(false) end
        if itemsBodyControl then itemsBodyControl:SetHidden(false) end
        if materialsBodyControl then materialsBodyControl:SetHidden(false) end

        local summary = pendingImprovementSummary
        if summary then
            local itemLines = {}
            for _, item in ipairs(summary.items) do
                local currentQuality = select(8, GetItemInfo(item.bagId or BAG_BACKPACK, item.slotIndex))
                local currentColor = currentQuality and GetItemQualityColor(currentQuality)
                local targetColor = GetItemQualityColor(summary.targetQuality)
                local itemName = currentColor and currentColor:Colorize(capitalizeFirstLetter(item.itemName)) or capitalizeFirstLetter(item.itemName)
                local targetText = targetColor and targetColor:Colorize(summary.targetQualityName) or summary.targetQualityName
                if currentQuality and currentQuality >= summary.targetQuality then
                    table.insert(itemLines, itemName .. " → No Change")
                else
                    table.insert(itemLines, itemName .. " → " .. targetText)
                end
            end

            local materialLines = {}
            for _, material in ipairs(summary.materials) do
                if material.required > 0 then
                    local color = material.quality and GetItemQualityColor(material.quality)
                    local materialName = color and color:Colorize(capitalizeFirstLetter(material.name)) or capitalizeFirstLetter(material.name)
                    table.insert(materialLines, materialName .. " " .. tostring(material.required))
                end
            end
            if #materialLines == 0 then
                table.insert(materialLines, "No improvement materials required")
            end

            if not summary.enoughMaterials then
                table.insert(materialLines, 1, "Not enough materials.")
            end

            itemsBodyControl:SetText(table.concat(itemLines, "\n"))
            materialsBodyControl:SetText(table.concat(materialLines, "\n"))

            --calculate the height needed for the selected items list
            local itemsHeight = #itemLines * 32

            --position the materials heading below the selected items
            materialsHeadingControl:ClearAnchors()
            materialsHeadingControl:SetAnchor(TOPLEFT, selectionControl, TOPLEFT, 50, 225 + itemsHeight + textOffsetY)

            --position the materials list below its heading
            materialsBodyControl:ClearAnchors()
            materialsBodyControl:SetAnchor(TOPLEFT, selectionControl, TOPLEFT, 50, 262 + itemsHeight + textOffsetY + materialsGap)
        end
        list:Commit()
        self.headerData = {
            titleText = "Confirm Improvements",
        }
    elseif selectionMode == "quality" then
        if itemsHeadingControl then itemsHeadingControl:SetHidden(true) end
        if materialsHeadingControl then materialsHeadingControl:SetHidden(true) end
        if itemsBodyControl then itemsBodyControl:SetHidden(true) end
        if materialsBodyControl then materialsBodyControl:SetHidden(true) end
        for _, quality in ipairs(qualityOptions) do
            local qualityColor = quality.quality and GetItemQualityColor(quality.quality)
            local coloredQualityName = qualityColor and qualityColor:Colorize(quality.name) or quality.name
            local qualityText = quality.selected and ("[X] " .. coloredQualityName) or "[ ] " .. coloredQualityName
            local entryData = ZO_GamepadEntryData:New(qualityText)
            entryData.qualityName = quality.name
            entryData.quality = quality.quality
            list:AddEntry("ZO_GamepadMenuEntryTemplate", entryData)
        end

        list:Commit()
        self.headerData = {
            titleText = "Choose Target Quality",
        }
    else
        local selectedCount = 0

        for _, item in ipairs(selectionItems) do
            local itemQuality = select(8, GetItemInfo(BAG_BACKPACK, item.slotIndex))
            local itemQualityColor = GetItemQualityColor(itemQuality)
            local coloredItemName = itemQualityColor and itemQualityColor:Colorize(item.itemName) or item.itemName
            local entryName = item.selected and ("[X] " .. coloredItemName) or "[ ] " .. coloredItemName
            local entryData = ZO_GamepadEntryData:New(entryName)
            entryData.item = item
            list:AddEntry("ZO_GamepadMenuEntryTemplate", entryData)

            if item.selected then
                selectedCount = selectedCount + 1
            end
        end

        list:Commit()
        self.headerData = {
            titleText = "Available Items (" .. tostring(selectedCount) .. " selected)",
        }
    end

    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)
    self.dirty = false
end

--create the overlay selection screen
local function createSelectionScreen()
    if selectionScreen then
        return
    end

    selectionControl = WINDOW_MANAGER:CreateControlFromVirtual(
        "AutoImproveGearGamepad",
        GuiRoot,
        "AutoImproveGearGamepadControl"
    )

    --position the list to the right of screen centre
    selectionControl:ClearAnchors()
    selectionControl:SetDimensions(650, 700)
    selectionControl:SetAnchor(CENTER, GuiRoot, CENTER, 250, 0)

    --add a shaded panel behind the list
    local background = WINDOW_MANAGER:CreateControl(
        "AutoImproveGearGamepadBackground",
        selectionControl,
        CT_BACKDROP
    )
    background:SetAnchorFill(selectionControl)
    background:SetDrawLayer(DL_BACKGROUND)
    background:SetCenterColor(0, 0, 0, 0.95)
    background:SetEdgeColor(0.45, 0.45, 0.45, 1)

    itemsHeadingControl = WINDOW_MANAGER:CreateControl("AutoImproveGearItemsHeading", selectionControl, CT_LABEL)
    --position and size of the items heading
    itemsHeadingControl:SetAnchor(TOPLEFT, selectionControl, TOPLEFT, 50, 140 + textOffsetY) --x and y position
    itemsHeadingControl:SetDimensions(590, 60) --width and height
    itemsHeadingControl:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_36)|soft-shadow-thick")
    itemsHeadingControl:SetText("Items to Improve")
    itemsHeadingControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    itemsHeadingControl:SetVerticalAlignment(TEXT_ALIGN_TOP)
    itemsHeadingControl:SetHidden(true)

    itemsBodyControl = WINDOW_MANAGER:CreateControl("AutoImproveGearItemsBody", selectionControl, CT_LABEL)
    --position and size of the selected items list
    itemsBodyControl:SetAnchor(TOPLEFT, selectionControl, TOPLEFT, 50, 181 + textOffsetY) --x and y position
    itemsBodyControl:SetDimensions(590, 360) --width and height
    itemsBodyControl:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_25)|soft-shadow-thick")
    itemsBodyControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    itemsBodyControl:SetVerticalAlignment(TEXT_ALIGN_TOP)
    itemsBodyControl:SetHidden(true)

    materialsHeadingControl = WINDOW_MANAGER:CreateControl("AutoImproveGearMaterialsHeading", selectionControl, CT_LABEL)
    --position and size of the materials heading
    materialsHeadingControl:SetAnchor(TOPLEFT, selectionControl, TOPLEFT, 50, 230 + textOffsetY) --initial position, may be repositioned dynamically
    materialsHeadingControl:SetDimensions(590, 60) --width and height
    materialsHeadingControl:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_36)|soft-shadow-thick")
    materialsHeadingControl:SetText("Improvement Materials Required")
    materialsHeadingControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    materialsHeadingControl:SetVerticalAlignment(TEXT_ALIGN_TOP)
    materialsHeadingControl:SetHidden(true)

    materialsBodyControl = WINDOW_MANAGER:CreateControl("AutoImproveGearMaterialsBody", selectionControl, CT_LABEL)
    --position and size of the required materials list
    materialsBodyControl:SetAnchor(TOPLEFT, selectionControl, TOPLEFT, 50, 278 + textOffsetY) --initial position, may be repositioned dynamically
    materialsBodyControl:SetDimensions(590, 220) --width and height
    materialsBodyControl:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_25)|soft-shadow-thick")
    materialsBodyControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    materialsBodyControl:SetVerticalAlignment(TEXT_ALIGN_TOP)
    materialsBodyControl:SetHidden(true)

    confirmationMessageControl = WINDOW_MANAGER:CreateControl("AutoImproveGearConfirmationMessage", selectionControl, CT_LABEL)
    confirmationMessageControl:SetAnchor(TOPLEFT, selectionControl, TOPLEFT, 50, 110 + textOffsetY)
    confirmationMessageControl:SetDimensions(590, 430)
    confirmationMessageControl:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_36)|soft-shadow-thick")
    confirmationMessageControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    confirmationMessageControl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    confirmationMessageControl:SetHidden(true)

    processingMessageControl = WINDOW_MANAGER:CreateControl("AutoImproveGearProcessingMessage", selectionControl, CT_LABEL)
    processingMessageControl:SetAnchor(TOP, selectionControl, TOP, 0, 145 + textOffsetY)
    processingMessageControl:SetDimensions(590, 190)
    processingMessageControl:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_36)|soft-shadow-thick")
    processingMessageControl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    processingMessageControl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    processingMessageControl:SetHidden(true)

    processingDebugControl = WINDOW_MANAGER:CreateControl("AutoImproveGearProcessingDebug", selectionControl, CT_LABEL)
    processingDebugControl:SetAnchor(TOPLEFT, selectionControl, TOPLEFT, 50, 430 + textOffsetY)
    processingDebugControl:SetDimensions(590, 230)
    processingDebugControl:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_18)|soft-shadow-thick")
    processingDebugControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    processingDebugControl:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    processingDebugControl:SetHidden(true)

    selectionScreen = AutoImproveGearSelectionScreen:New(
        selectionControl,
        false,
        true
    )

    selectionFragment = ZO_FadeSceneFragment:New(selectionControl)

    --connect the gamepad list to the overlay fragment for it owns navigation
    selectionScreen:SetParentFragment(selectionFragment)
end

--show the item list over the current crafting scene
local function showSelectionScreen(items)
    refreshHoldBindingState()
    selectionItems = items
    selectionMode = "items"
    pendingImprovementSummary = nil
    processingState.active = false
    processingState.awaitingCompletion = false
    processingState.finished = false
    processingState.item = nil
    processingState.debugLines = {}
    selectionScreen:Update()
    updateSelectionKeybinds()

    --show the overlay before replacing the improvement screen keybinds
    SCENE_MANAGER:AddFragment(selectionFragment)

    --isolate the overlay keybinds from the improvement screen
    if not selectionKeybindStateIndex then
        selectionKeybindStateIndex = KEYBIND_STRIP:PushKeybindGroupState()
        KEYBIND_STRIP:AddKeybindButtonGroup(
            selectionScreen.keybindStripDescriptor,
            selectionKeybindStateIndex
        )
    end
end

--open the item list from R2
local function onAutoImprovePressed()
    local craftingType = GetCraftingInteractionType()

    if not craftingType or not equipmentTypes[craftingType] then
        return
    end

    local items = scanBackpack(craftingType)

    if #items == 0 then
        return
    end

    createSelectionScreen()
    showSelectionScreen(items)
end

--initialize the addon
local function initialize()
    if initialized then
        return
    end

    if not KEYBIND_STRIP then
        return
    end

    registerImprovementEvents()

    local improvementScenes = {
        GAMEPAD_SMITHING_IMPROVEMENT_SCENE,
        GAMEPAD_JEWELRY_IMPROVEMENT_SCENE,
    }

    local improvementPanels = {}

    if SMITHING_GAMEPAD and SMITHING_GAMEPAD.improvementPanel then
        table.insert(improvementPanels, SMITHING_GAMEPAD.improvementPanel)
    end

    if JEWELRY_CRAFTING_GAMEPAD and JEWELRY_CRAFTING_GAMEPAD.improvementPanel then
        table.insert(improvementPanels, JEWELRY_CRAFTING_GAMEPAD.improvementPanel)
    end

    local function autoImproveIsVisible()
        for _, scene in ipairs(improvementScenes) do
            if scene and scene:IsShowing() then
                return true
            end
        end

        return false
    end

    --add auto improve to each improvement panel's own keybind descriptors
    for _, panel in ipairs(improvementPanels) do
        if panel and panel.keybindStripDescriptor then
            local descriptor = {
                alignment = KEYBIND_STRIP_ALIGN_LEFT,
                keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
                name = "Auto Improve",
                callback = onAutoImprovePressed,
                visible = autoImproveIsVisible,
            }

            table.insert(panel.keybindStripDescriptor, descriptor)
        end
    end

    restoreAutoImproveKeybind = function()
        if selectionKeybindStateIndex then
            return
        end

        if not autoImproveIsVisible() then
            return
        end

        --refresh the panel's own keybind group instead of registering a separate group
        for _, panel in ipairs(improvementPanels) do
            if panel and panel.keybindStripDescriptor
                and KEYBIND_STRIP:HasKeybindButtonGroup(panel.keybindStripDescriptor) then
                KEYBIND_STRIP:UpdateKeybindButtonGroup(panel.keybindStripDescriptor)
            end
        end
    end

    for _, scene in ipairs(improvementScenes) do
        if scene then
            scene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_SHOWN then
                    zo_callLater(function()
                        if restoreAutoImproveKeybind then
                            restoreAutoImproveKeybind()
                        end
                    end, 150)
                end
            end)
        end
    end

    --release the custom overlay keybinds when the main menu opens
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
        if scene and scene.name == "mainMenuGamepad" and newState == SCENE_SHOWING then
            processingState.active = false
            processingState.awaitingCompletion = false
            setHoldLayerActive(false)

            if selectionFragment then
                SCENE_MANAGER:RemoveFragment(selectionFragment)
            end

            if selectionKeybindStateIndex then
                KEYBIND_STRIP:RemoveKeybindButtonGroup(
                    selectionScreen.keybindStripDescriptor,
                    selectionKeybindStateIndex
                )
                KEYBIND_STRIP:PopKeybindGroupState()
                selectionKeybindStateIndex = nil
            end
        end

        --refresh the keybind after another scene closes over the improvement screen
        if newState == SCENE_HIDDEN then
            zo_callLater(function()
                if restoreAutoImproveKeybind then
                    restoreAutoImproveKeybind()
                end
            end, 100)
        end
    end)

    initialized = true
end

--handle addon loading
local function OnAddonLoaded(eventCode, name)
    --if not this app return
    if name ~= appName then return end
    --unregister for add-on loading notifications
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)
    --register the default hold key for the confirm action
    createHoldBinding()
    --start process
    initialize()
end

EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, OnAddonLoaded)