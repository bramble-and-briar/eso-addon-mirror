local appName = "AutoImproveGear"

--adjust this value to move all confirmation screen text up or down
local textOffsetY = 40

local initialized = false

--selection screen state
local selectionItems = {}
local selectionScreen
local selectionFragment
local selectionControl
local summaryTextControl
local itemsHeadingControl
local materialsHeadingControl
local itemsBodyControl
local materialsBodyControl
local selectionKeybindStateIndex
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
    if msg ~= "Confirmed by user" then return end
    local chat = LibChatMessage(appName, "MA")
    chat:Print(msg)
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

            if isRelevantItem(itemName, craftingType) then
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
local pendingMaterialRequirements
local pendingSelectedCount
local pendingImprovementSummary

local qualityNamesByValue = {
    [1] = "Normal",
    [2] = "Fine",
    [3] = "Superior",
    [4] = "Epic",
    [5] = "Legendary",
}

local function updateSelectionKeybinds()
    if not selectionScreen then
        return
    end

    local primaryDescriptor = selectionScreen.primaryKeybindDescriptor
    if primaryDescriptor then
        if selectionMode == "quality" or selectionMode == "summary" then
            primaryDescriptor.name = "Select"
        else
            primaryDescriptor.name = "Select / Deselect"
        end
        primaryDescriptor.visible = function()
            return true
        end
        primaryDescriptor.enabled = function()
            return selectionMode ~= "summary"
        end
    end

    if improveKeybindDescriptor then
        improveKeybindDescriptor.name = selectionMode == "summary" and "Confirm and Improve" or "Improve Selected Items"
    end

    if selectionKeybindStateIndex then
        --refresh the group so updated labels and enabled state are applied
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
        printMessage("No items selected")
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
    for boosterCount = 1, 1000 do
        local chance = GetSmithingImprovementChance(BAG_BACKPACK, item.slotIndex, boosterCount, craftingType)
        if chance and chance >= 100 then
            return boosterCount
        end
    end

    return nil
end

--calculate the guaranteed booster count for a future quality using the passive rank
local function getBoosterCountForQuality(fromQuality, craftingType, expertiseRank)
    local boosterCountsByRank

    if craftingType == CRAFTING_TYPE_JEWELRYCRAFTING then
        boosterCountsByRank = {
            { 3, 5, 7, 10 },
            { 2, 4, 5, 7 },
            { 2, 3, 4, 5 },
            { 1, 2, 3, 4 },
        }
    else
        boosterCountsByRank = {
            { 5, 7, 10, 20 },
            { 4, 5, 7, 14 },
            { 3, 4, 5, 10 },
            { 2, 3, 4, 8 },
        }
    end

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

        if name and itemId then
            materials[index] = {
                index = index,
                name = name,
                itemId = itemId,
                available = stackCount or 0,
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
                    boosterCount = getBoosterCountForQuality(fromQuality, craftingType, expertiseRank)
                end

                if material and boosterCount then
                    material.required = material.required + boosterCount
                end
            end
        end
    end

    return materials
end

local function printMaterialSummary(materials)
    local anyMaterials = false

    for _, material in ipairs(materials) do
        if material.required > 0 then
            anyMaterials = true
            local color = GetItemQualityColor(material.quality)
            local coloredName = color and color:Colorize(material.name) or material.name
            printMessage(coloredName .. ": " .. tostring(material.required) .. " required, " .. tostring(material.available) .. " available")
        end
    end

    if not anyMaterials then
        printMessage("No improvement materials required for the selected items")
    end
end

local function confirmSelectedQuality(qualityName)
    local selectedItems = getSelectedItems()
    local selectedCount = #selectedItems

    if selectedCount == 0 then
        printMessage("No items selected")
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
        printMessage("Unable to calculate improvement materials")
        return
    end

    local materials = calculateMaterialRequirements(selectedItems, targetQuality, craftingType)
    printMessage("Materials for " .. tostring(selectedCount) .. " item(s) to reach " .. qualityName .. " quality")
    printMaterialSummary(materials)

    local enoughMaterials = true
    local maxAffordable = selectedCount
    for _, material in ipairs(materials) do
        if material.required > material.available then
            enoughMaterials = false
            if material.required > 0 then
                maxAffordable = math.min(maxAffordable, math.floor(selectedCount * material.available / material.required))
            end
        end
    end

    if not enoughMaterials then
        printMessage("Not enough materials to improve all selected items")
        printMessage("You have enough materials to improve approximately " .. tostring(maxAffordable) .. " of the " .. tostring(selectedCount) .. " selected item(s)")
        selectionMode = "items"
        selectionScreen:Update()
        updateSelectionKeybinds()
        return
    end

    pendingImprovementSummary = {
        items = selectedItems,
        targetQuality = targetQuality,
        targetQualityName = qualityName,
        materials = materials,
    }
    pendingMaterialRequirements = materials
    pendingSelectedCount = selectedCount
    selectionMode = "summary"
    selectionScreen:Update()
    updateSelectionKeybinds()
end

local function confirmImprovementSummary()
    if not pendingImprovementSummary then return end
    printMessage("Confirmed by user")
end

local function capitalizeFirstLetter(value)
    return (value:gsub("^%l", string.upper))
end

function AutoImproveGearSelectionScreen:InitializeKeybindStripDescriptors()
    local primaryDescriptor = {
        name = "Select / Deselect",
        keybind = "UI_SHORTCUT_PRIMARY",
        callback = function()
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
        return selectionMode ~= "summary"
    end

    self.primaryKeybindDescriptor = primaryDescriptor
    self.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        primaryDescriptor,
        {
            name = "Improve Selected Items",
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function()
                return true
            end,
            callback = function()
                if selectionMode == "summary" then
                    confirmImprovementSummary()
                    return
                end
                if selectionMode == "quality" then
                    if selectedQualityName then
                        confirmSelectedQuality(selectedQualityName)
                    else
                        printMessage("Select a target quality")
                    end
                else
                    showQualitySelection()
                end
            end,
        },
        {
            name = GetString(SI_GAMEPAD_BACK_OPTION),
            keybind = "UI_SHORTCUT_NEGATIVE",
            visible = function()
                return true
            end,
            callback = function()
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

                --restore the auto improve button after returning from the overlay
                if restoreAutoImproveKeybind then
                    restoreAutoImproveKeybind()
                end
            end,
        },
    }
    improveKeybindDescriptor = self.keybindStripDescriptor[2]
end

function AutoImproveGearSelectionScreen:PerformUpdate()
    local list = self:GetMainList()
    list:Clear()

    if selectionMode == "summary" then
        if summaryTextControl then summaryTextControl:SetHidden(true) end
        if itemsHeadingControl then itemsHeadingControl:SetHidden(false) end
        if materialsHeadingControl then materialsHeadingControl:SetHidden(false) end
        if itemsBodyControl then itemsBodyControl:SetHidden(false) end
        if materialsBodyControl then materialsBodyControl:SetHidden(false) end

        local summary = pendingImprovementSummary
        if summary then
            local itemLines = {}
            for _, item in ipairs(summary.items) do
                local currentQuality = select(8, GetItemInfo(BAG_BACKPACK, item.slotIndex))
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

            itemsBodyControl:SetText(table.concat(itemLines, "\n"))
            materialsBodyControl:SetText(table.concat(materialLines, "\n"))

            --calculate the height needed for the selected items list
            local itemsHeight = #itemLines * 32

            --position the materials heading below the selected items
            materialsHeadingControl:ClearAnchors()
            materialsHeadingControl:SetAnchor(TOPLEFT, selectionControl, TOPLEFT, 50, 225 + itemsHeight + textOffsetY)

            --position the materials list below its heading
            materialsBodyControl:ClearAnchors()
            materialsBodyControl:SetAnchor(TOPLEFT, selectionControl, TOPLEFT, 50, 262 + itemsHeight + textOffsetY)
        end
        list:Commit()
        self.headerData = {
            titleText = "Confirm Improvements",
        }
    elseif selectionMode == "quality" then
        if summaryTextControl then summaryTextControl:SetHidden(true) end
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
        if summaryTextControl then
            summaryTextControl:SetHidden(true)
        end

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

    summaryTextControl = WINDOW_MANAGER:CreateControl(
        "AutoImproveGearSummaryText",
        selectionControl,
        CT_LABEL
    )
    summaryTextControl:SetAnchor(TOPLEFT, selectionControl, TOPLEFT, 15, 130 + textOffsetY)
    summaryTextControl:SetDimensions(590, 550)
    summaryTextControl:SetFont("ZoFontGamepad27")
    summaryTextControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    summaryTextControl:SetVerticalAlignment(TEXT_ALIGN_TOP)
    summaryTextControl:SetHidden(true)

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
    materialsHeadingControl:SetAnchor(TOPLEFT, selectionControl, TOPLEFT, 50, 232 + textOffsetY) --initial position, may be repositioned dynamically
    materialsHeadingControl:SetDimensions(590, 60) --width and height
    materialsHeadingControl:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_36)|soft-shadow-thick")
    materialsHeadingControl:SetText("Improvement Materials Required")
    materialsHeadingControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    materialsHeadingControl:SetVerticalAlignment(TEXT_ALIGN_TOP)
    materialsHeadingControl:SetHidden(true)

    materialsBodyControl = WINDOW_MANAGER:CreateControl("AutoImproveGearMaterialsBody", selectionControl, CT_LABEL)
    --position and size of the required materials list
    materialsBodyControl:SetAnchor(TOPLEFT, selectionControl, TOPLEFT, 50, 282 + textOffsetY) --initial position, may be repositioned dynamically
    materialsBodyControl:SetDimensions(590, 220) --width and height
    materialsBodyControl:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_25)|soft-shadow-thick")
    materialsBodyControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    materialsBodyControl:SetVerticalAlignment(TEXT_ALIGN_TOP)
    materialsBodyControl:SetHidden(true)

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
    selectionItems = items
    selectionMode = "items"
    pendingImprovementSummary = nil
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
        printMessage("Unable to identify the current crafting station")
        return
    end

    local items = scanBackpack(craftingType)

    if #items == 0 then
        printMessage("No matching unlocked items found")
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
    printMessage("Auto Improve Gear: improvement hooks registered")
end

--handle addon loading
local function OnAddonLoaded(eventCode, name)
    --if not this app return
    if name ~= appName then return end
    --unregister for add-on loading notifications
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)
    --start process
    initialize()
end

EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, OnAddonLoaded)