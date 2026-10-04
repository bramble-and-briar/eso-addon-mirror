local ADDON_NAME = "Runenwerk"
local ADDON_VERSION = "1.0.0"

Runenwerk = Runenwerk or {}
local RW = Runenwerk

RW.name = ADDON_NAME
RW.version = ADDON_VERSION
RW.pendingCraft = nil
RW.recipeList = {}
RW.allRecipes = {}
RW.categoryFilter = "all"
RW.openedFromSettings = false
RW.openedFromMainMenu = false

local FRAME_BLUE_R = 0x7F / 255
local FRAME_BLUE_G = 0xC7 / 255
local FRAME_BLUE_B = 0xFF / 255

local IDEAL_WINDOW_WIDTH = 980
local IDEAL_WINDOW_HEIGHT = 620
local WINDOW_MARGIN = 20
local ROW_HEIGHT = 42
local ROW_SPACING = 2

local function GetLanguage()
    local language = GetCVar("language.2") or "en"
    if language == "de" then
        return "de"
    end
    return "en"
end

function RW:L(key, ...)
    local language = self.language or "en"
    local tableForLanguage = Runenwerk_Localization[language] or Runenwerk_Localization.en
    local value = tableForLanguage[key] or Runenwerk_Localization.en[key] or key
    if select("#", ...) > 0 then
        return string.format(value, ...)
    end
    return value
end

function RW:Chat(key, ...)
    if not self.saved or self.saved.chatMessages == false then
        return
    end

    local message = self:L(key, ...)
    d(string.format("|c7FC7FF%s|r: %s", ADDON_NAME, message))
end

local function SafeItemLink(bagId, slotIndex)
    if not bagId or slotIndex == nil then
        return ""
    end
    return GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT) or ""
end

local function ItemNameFromLink(itemLink)
    if not itemLink or itemLink == "" then
        return "?"
    end
    local name = GetItemLinkName(itemLink)
    if not name or name == "" then
        return "?"
    end
    return zo_strformat("<<t:1>>", name)
end

local function GetGlyphMinimumLevels(itemLink)
    if not itemLink or itemLink == "" then
        return 0, 0
    end

    -- Glyphs have their own minimum-level API. This is the value ESO uses
    -- for the glyph requirement shown in its tooltip and can differ from the
    -- generic required item level.
    if GetItemLinkGlyphMinLevels then
        local minLevel, minChampionPoints = GetItemLinkGlyphMinLevels(itemLink)
        minLevel = tonumber(minLevel) or 0
        minChampionPoints = tonumber(minChampionPoints) or 0
        if minLevel > 0 or minChampionPoints > 0 then
            return minLevel, minChampionPoints
        end
    end

    -- Defensive fallback for unexpected/older clients or malformed links.
    return tonumber(GetItemLinkRequiredLevel(itemLink)) or 0,
        tonumber(GetItemLinkRequiredChampionPoints(itemLink)) or 0
end

local function RuneRecord(bagId, slotIndex)
    if not bagId or slotIndex == nil then
        return nil
    end

    local itemId = GetItemId(bagId, slotIndex)
    if not itemId or itemId == 0 then
        return nil
    end

    local itemLink = SafeItemLink(bagId, slotIndex)
    return {
        itemId = itemId,
        itemLink = itemLink,
        name = ItemNameFromLink(itemLink),
    }
end

local function RecipeKey(potencyId, essenceId, aspectId)
    return string.format("%d:%d:%d", potencyId or 0, essenceId or 0, aspectId or 0)
end

function RW:GetRecipeForCurrentRunes(enchantingObject)
    if not self.saved or not enchantingObject or not enchantingObject.GetAllCraftingBagAndSlots then
        return nil, false
    end

    if enchantingObject.GetEnchantingMode and enchantingObject:GetEnchantingMode() ~= ENCHANTING_MODE_CREATION then
        return nil, false
    end

    local potencyBag, potencySlot, essenceBag, essenceSlot, aspectBag, aspectSlot = enchantingObject:GetAllCraftingBagAndSlots()
    if not potencyBag or potencySlot == nil or not essenceBag or essenceSlot == nil or not aspectBag or aspectSlot == nil then
        return nil, false
    end

    local potencyId = GetItemId(potencyBag, potencySlot) or 0
    local essenceId = GetItemId(essenceBag, essenceSlot) or 0
    local aspectId = GetItemId(aspectBag, aspectSlot) or 0
    if potencyId == 0 or essenceId == 0 or aspectId == 0 then
        return nil, false
    end

    local key = RecipeKey(potencyId, essenceId, aspectId)
    return self.saved.recipes[key], true
end

function RW:AppendCombinationStatusToESOResultTooltip(enchantingObject)
    if not enchantingObject or not enchantingObject.resultTooltip then
        return
    end

    if enchantingObject.IsCraftable and not enchantingObject:IsCraftable() then
        return
    end

    local recipe, hasCompleteCombination = self:GetRecipeForCurrentRunes(enchantingObject)
    if not hasCompleteCombination then
        return
    end

    local tooltip = enchantingObject.resultTooltip
    local text
    if recipe then
        text = self:L("TOOLTIP_COMBINATION_KNOWN", tonumber(recipe.craftCount) or 0)
    else
        text = self:L("TOOLTIP_COMBINATION_UNKNOWN")
    end

    tooltip:AddLine(text, "ZoFontGame", 1, 1, 1, TOP, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
end

function RW:InstallResultTooltipHook()
    if self.resultTooltipHookInstalled or not ZO_Enchanting or not ZO_Enchanting.UpdateTooltip then
        return
    end

    self.resultTooltipHookInstalled = true
    ZO_PostHook(ZO_Enchanting, "UpdateTooltip", function(enchantingObject)
        self:AppendCombinationStatusToESOResultTooltip(enchantingObject)
    end)
end

function RW:CapturePending(potencyBag, potencySlot, essenceBag, essenceSlot, aspectBag, aspectSlot, numIterations)
    local potency = RuneRecord(potencyBag, potencySlot)
    local essence = RuneRecord(essenceBag, essenceSlot)
    local aspect = RuneRecord(aspectBag, aspectSlot)

    if not potency or not essence or not aspect then
        self.pendingCraft = nil
        return false
    end

    local previewLink = GetEnchantingResultingItemLink(
        potencyBag, potencySlot,
        essenceBag, essenceSlot,
        aspectBag, aspectSlot,
        LINK_STYLE_DEFAULT
    ) or ""

    self.pendingCraft = {
        potency = potency,
        essence = essence,
        aspect = aspect,
        iterations = math.max(1, tonumber(numIterations) or 1),
        previewLink = previewLink,
    }
    return true
end

function RW:CaptureFromEnchantingObject(enchantingObject, numIterations)
    if not enchantingObject then
        return
    end

    if enchantingObject.GetEnchantingMode and enchantingObject:GetEnchantingMode() ~= ENCHANTING_MODE_CREATION then
        return
    end

    if enchantingObject.IsCraftable and not enchantingObject:IsCraftable() then
        return
    end

    if not enchantingObject.GetAllCraftingBagAndSlots then
        return
    end

    local potencyBag, potencySlot, essenceBag, essenceSlot, aspectBag, aspectSlot = enchantingObject:GetAllCraftingBagAndSlots()
    self:CapturePending(potencyBag, potencySlot, essenceBag, essenceSlot, aspectBag, aspectSlot, numIterations)
end

function RW:GetLastCraftedGlyphLink()
    local numItems = GetNumLastCraftingResultItemsAndPenalty()
    if not numItems or numItems < 1 then
        return nil
    end

    for index = 1, numItems do
        local itemLink = GetLastCraftingResultItemLink(index, LINK_STYLE_DEFAULT)
        if itemLink and itemLink ~= "" then
            local itemType = GetItemLinkItemType(itemLink)
            if itemType == ITEMTYPE_GLYPH_WEAPON
                or itemType == ITEMTYPE_GLYPH_ARMOR
                or itemType == ITEMTYPE_GLYPH_JEWELRY then
                return itemLink
            end
        end
    end

    return nil
end

function RW:SaveLearnedRecipe(itemLink)
    local pending = self.pendingCraft
    if not pending then
        return
    end

    itemLink = itemLink or pending.previewLink
    if not itemLink or itemLink == "" then
        self:Chat("UNKNOWN_RESULT")
        return
    end

    local itemType = GetItemLinkItemType(itemLink)
    if itemType ~= ITEMTYPE_GLYPH_WEAPON
        and itemType ~= ITEMTYPE_GLYPH_ARMOR
        and itemType ~= ITEMTYPE_GLYPH_JEWELRY then
        return
    end

    local key = RecipeKey(pending.potency.itemId, pending.essence.itemId, pending.aspect.itemId)
    local old = self.saved.recipes[key]
    local wasKnown = old ~= nil
    local previousCraftCount = old and old.craftCount or 0
    local minLevel, minChampionPoints = GetGlyphMinimumLevels(itemLink)

    self.saved.recipes[key] = {
        key = key,
        potency = pending.potency,
        essence = pending.essence,
        aspect = pending.aspect,
        resultLink = itemLink,
        resultItemId = GetItemLinkItemId(itemLink),
        resultName = ItemNameFromLink(itemLink),
        itemType = itemType,
        quality = GetItemLinkDisplayQuality(itemLink),
        requiredLevel = minLevel,
        requiredChampionPoints = minChampionPoints,
        learnedAt = old and old.learnedAt or GetTimeStamp(),
        lastCraftedAt = GetTimeStamp(),
        craftCount = previousCraftCount + pending.iterations,
    }

    self:RefreshRecipeList()
    self:RefreshWindow()

    local messageKey = wasKnown and "UPDATED" or "LEARNED"
    self:Chat(messageKey, itemLink)
end

function RW:OnCraftCompleted(craftingType)
    if craftingType ~= CRAFTING_TYPE_ENCHANTING or not self.pendingCraft then
        return
    end

    local resultLink = self:GetLastCraftedGlyphLink()
    self:SaveLearnedRecipe(resultLink)
    self.pendingCraft = nil

    -- Rebuild ESO's result tooltip after learning/updating the combination so
    -- the Runenwerk status and craft count are immediately current.
    zo_callLater(function()
        if ENCHANTING and ENCHANTING.UpdateTooltip and ENCHANTING.GetEnchantingMode
            and ENCHANTING:GetEnchantingMode() == ENCHANTING_MODE_CREATION then
            ENCHANTING:UpdateTooltip()
        end
        if self.window and not self.window:IsHidden() then
            self:DockESOResultTooltip()
        end
    end, 0)
end

function RW:OnCraftFailed()
    self.pendingCraft = nil
end

function RW:FindItemLocation(itemId)
    if not itemId or itemId == 0 then
        return nil, nil
    end

    local bags = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
    for _, bagId in ipairs(bags) do
        local bagSize = GetBagSize(bagId) or 0
        for slotIndex = 0, bagSize - 1 do
            if GetItemId(bagId, slotIndex) == itemId then
                local stack = GetSlotStackSize(bagId, slotIndex)
                if stack and stack > 0 then
                    return bagId, slotIndex
                end
            end
        end
    end

    if BAG_VIRTUAL and GetItemId(BAG_VIRTUAL, itemId) ~= 0 then
        return BAG_VIRTUAL, itemId
    end

    return nil, nil
end

function RW:HasRecipeMaterials(recipe)
    if not recipe then
        return false
    end

    local pBag = self:FindItemLocation(recipe.potency.itemId)
    local eBag = self:FindItemLocation(recipe.essence.itemId)
    local aBag = self:FindItemLocation(recipe.aspect.itemId)
    return pBag ~= nil and eBag ~= nil and aBag ~= nil
end

function RW:InsertRecipe(recipe)
    if not recipe then
        return
    end

    if GetCraftingInteractionType() ~= CRAFTING_TYPE_ENCHANTING then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, self:L("NEED_STATION"))
        return
    end

    local enchantingObject = ZO_Enchanting_GetVisibleEnchanting and ZO_Enchanting_GetVisibleEnchanting() or ENCHANTING
    if not enchantingObject or not enchantingObject.IsSceneShowing or not enchantingObject:IsSceneShowing() then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, self:L("NEED_STATION"))
        return
    end

    if enchantingObject.GetEnchantingMode and enchantingObject:GetEnchantingMode() ~= ENCHANTING_MODE_CREATION then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, self:L("NEED_CREATION"))
        return
    end

    local potencyBag, potencySlot = self:FindItemLocation(recipe.potency.itemId)
    local essenceBag, essenceSlot = self:FindItemLocation(recipe.essence.itemId)
    local aspectBag, aspectSlot = self:FindItemLocation(recipe.aspect.itemId)

    if not potencyBag or not essenceBag or not aspectBag then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, self:L("NEED_RUNES"))
        self:RefreshWindow()
        return
    end

    if enchantingObject.ClearSelections then
        enchantingObject:ClearSelections()
    end

    local potencySlotControl = enchantingObject.AddItemToCraft and enchantingObject:AddItemToCraft(potencyBag, potencySlot)
    local essenceSlotControl = enchantingObject.AddItemToCraft and enchantingObject:AddItemToCraft(essenceBag, essenceSlot)
    local aspectSlotControl = enchantingObject.AddItemToCraft and enchantingObject:AddItemToCraft(aspectBag, aspectSlot)

    if not potencySlotControl or not essenceSlotControl or not aspectSlotControl then
        if enchantingObject.ClearSelections then
            enchantingObject:ClearSelections()
        end
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, self:L("INSERT_FAILED"))
        return
    end

    if enchantingObject.OnSlotChanged then
        enchantingObject:OnSlotChanged()
    end

    if self.window and not self.window:IsHidden() then
        zo_callLater(function() self:DockESOResultTooltip() end, 0)
    end

    if self.window and self.saved.closeAfterInsert then
        self.window:SetHidden(true)
    end

    self:Chat("INSERTED", recipe.resultLink or recipe.resultName)
end

function RW:GetCategoryKey(itemType)
    if itemType == ITEMTYPE_GLYPH_WEAPON then
        return "weapon"
    elseif itemType == ITEMTYPE_GLYPH_ARMOR then
        return "armor"
    elseif itemType == ITEMTYPE_GLYPH_JEWELRY then
        return "jewelry"
    end
    return "other"
end

function RW:GetCategoryName(itemType)
    local categoryKey = self:GetCategoryKey(itemType)
    if categoryKey == "weapon" then
        return self:L("CATEGORY_WEAPON")
    elseif categoryKey == "armor" then
        return self:L("CATEGORY_ARMOR")
    elseif categoryKey == "jewelry" then
        return self:L("CATEGORY_JEWELRY")
    end
    return self:L("CATEGORY_OTHER")
end

function RW:RefreshRecipeMinimumLevels(recipe)
    if not recipe then
        return 0, 0
    end

    local minLevel, minChampionPoints = GetGlyphMinimumLevels(recipe.resultLink)
    if minLevel > 0 or minChampionPoints > 0 then
        -- Refresh saved recipes too, so recipes learned with older Runenwerk
        -- versions are corrected automatically without being relearned.
        recipe.requiredLevel = minLevel
        recipe.requiredChampionPoints = minChampionPoints
    else
        minLevel = tonumber(recipe.requiredLevel) or 0
        minChampionPoints = tonumber(recipe.requiredChampionPoints) or 0
    end

    return minLevel, minChampionPoints
end

local function NormalizeSortText(value)
    local text = tostring(value or "")
    text = text:gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"):gsub("ẞ", "ß")
    return string.lower(text)
end

function RW:GetSortColumnLabel(sortColumn)
    local labels = {
        glyph = self:L("COLUMN_GLYPH"),
        level = self:L("COLUMN_MIN_LEVEL"),
        runes = self:L("COLUMN_RUNES"),
        crafted = self:L("COLUMN_CRAFTED"),
        material = self:L("COLUMN_MATERIAL"),
    }
    return labels[sortColumn] or labels.glyph
end

function RW:GetSortValue(recipe, sortColumn, materialCache)
    if sortColumn == "level" then
        local level, cp = self:RefreshRecipeMinimumLevels(recipe)
        if cp > 0 then
            -- Champion ranks follow normal character levels in ESO progression.
            return 100000 + cp
        end
        return level
    elseif sortColumn == "runes" then
        return NormalizeSortText(string.format(
            "%s %s %s",
            recipe.potency and recipe.potency.name or "",
            recipe.essence and recipe.essence.name or "",
            recipe.aspect and recipe.aspect.name or ""
        ))
    elseif sortColumn == "crafted" then
        return tonumber(recipe.craftCount) or 0
    elseif sortColumn == "material" then
        if materialCache and materialCache[recipe] ~= nil then
            return materialCache[recipe] and 1 or 0
        end
        return self:HasRecipeMaterials(recipe) and 1 or 0
    end

    return NormalizeSortText(recipe.resultName or "")
end

function RW:UpdateSortHeaders()
    if not self.columnHeaderButtons then
        return
    end

    for sortColumn, button in pairs(self.columnHeaderButtons) do
        local label = button.runenwerkLabel
        if label then
            label:SetText(self:GetSortColumnLabel(sortColumn))
            if self.activeSortColumn == sortColumn then
                label:SetColor(FRAME_BLUE_R, FRAME_BLUE_G, FRAME_BLUE_B, 1)
            else
                label:SetColor(0.85, 0.85, 0.85, 1)
            end
        end
    end
end

function RW:ApplyActiveSort(sortColumn, ascending)
    self.activeSortColumn = sortColumn or "glyph"
    if ascending == nil then
        ascending = true
    end
    self.activeSortAscending = ascending
    self:RefreshRecipeList()
    self:RefreshWindow()
    self:ResetRecipeScroll()
    self:UpdateSortHeaders()
end

function RW:ResetActiveSortToSettings()
    if not self.saved then
        return
    end

    self.activeSortColumn = self.saved.sortColumn or "glyph"
    self.activeSortAscending = self.saved.sortAscending ~= false
end

function RW:SetDefaultSort(sortColumn, ascending)
    if not self.saved then
        return
    end

    self.saved.sortColumn = sortColumn or "glyph"
    if ascending == nil then
        ascending = true
    end
    self.saved.sortAscending = ascending

    -- A change in the settings menu becomes the current sort immediately.
    -- Later clicks on the table headers remain temporary until the window is
    -- closed and opened again.
    self:ApplyActiveSort(self.saved.sortColumn, self.saved.sortAscending)
end

function RW:ToggleSort(sortColumn)
    local currentColumn = self.activeSortColumn or (self.saved and self.saved.sortColumn) or "glyph"
    local currentAscending = self.activeSortAscending
    if currentAscending == nil then
        currentAscending = self.saved and self.saved.sortAscending ~= false or true
    end

    if currentColumn == sortColumn then
        self:ApplyActiveSort(sortColumn, not currentAscending)
    else
        self:ApplyActiveSort(sortColumn, true)
    end
end

function RW:RefreshCategoryButtons()
    if not self.categoryButtons then
        return
    end

    local counts = self.categoryCounts or {}
    local labels = {
        all = self:L("CATEGORY_ALL"),
        weapon = self:L("CATEGORY_WEAPONS"),
        armor = self:L("CATEGORY_ARMOR"),
        jewelry = self:L("CATEGORY_JEWELRY"),
    }

    for key, button in pairs(self.categoryButtons) do
        local text = string.format("%s (%d)", labels[key] or key, counts[key] or 0)
        if self.categoryFilter == key then
            text = "|c7FC7FF" .. text .. "|r"
        end
        button:SetText(text)
    end
end

function RW:SetCategoryFilter(categoryKey)
    self.categoryFilter = categoryKey or "all"
    self:RefreshRecipeList()
    self:RefreshWindow()
    self:ResetRecipeScroll()
end

function RW:RefreshRecipeList()
    self.allRecipes = {}
    self.categoryCounts = {
        all = 0,
        weapon = 0,
        armor = 0,
        jewelry = 0,
        other = 0,
    }

    for _, recipe in pairs(self.saved.recipes) do
        self:RefreshRecipeMinimumLevels(recipe)
        table.insert(self.allRecipes, recipe)
        local categoryKey = self:GetCategoryKey(recipe.itemType)
        self.categoryCounts[categoryKey] = (self.categoryCounts[categoryKey] or 0) + 1
    end
    self.categoryCounts.all = #self.allRecipes

    local sortColumn = self.activeSortColumn or self.saved.sortColumn or "glyph"
    local ascending = self.activeSortAscending
    if ascending == nil then
        ascending = self.saved.sortAscending ~= false
    end
    local materialCache = {}
    if sortColumn == "material" then
        for _, recipe in ipairs(self.allRecipes) do
            materialCache[recipe] = self:HasRecipeMaterials(recipe)
        end
    end

    table.sort(self.allRecipes, function(a, b)
        local aValue = self:GetSortValue(a, sortColumn, materialCache)
        local bValue = self:GetSortValue(b, sortColumn, materialCache)

        if aValue ~= bValue then
            if ascending then
                return aValue < bValue
            end
            return aValue > bValue
        end

        -- Stable, useful tie-breakers: glyph name, category, then recipe key.
        local aName = NormalizeSortText(a.resultName or "")
        local bName = NormalizeSortText(b.resultName or "")
        if aName ~= bName then
            return aName < bName
        end

        local aCategory = self:GetCategoryKey(a.itemType)
        local bCategory = self:GetCategoryKey(b.itemType)
        if aCategory ~= bCategory then
            return aCategory < bCategory
        end

        return (a.key or "") < (b.key or "")
    end)

    self.recipeList = {}
    for _, recipe in ipairs(self.allRecipes) do
        local categoryKey = self:GetCategoryKey(recipe.itemType)
        if self.categoryFilter == "all" or self.categoryFilter == categoryKey then
            table.insert(self.recipeList, recipe)
        end
    end

    self:RefreshCategoryButtons()
    self:UpdateSortHeaders()
end

function RW:FormatMinimumLevel(recipe)
    if not recipe then
        return "-"
    end

    local level, cp = self:RefreshRecipeMinimumLevels(recipe)
    if cp > 0 then
        return string.format("CP %d", cp)
    end
    if level > 0 then
        return tostring(level)
    end
    return "-"
end

function RW:HideRecipeTooltip()
    self.recipeTooltipRecipe = nil
    if PopupTooltip then
        ClearTooltip(PopupTooltip)
        PopupTooltip:SetHidden(true)
    end
end

function RW:ShowRecipeTooltip(recipe)
    if not PopupTooltip or not self.window or not recipe or not recipe.resultLink or recipe.resultLink == "" then
        return
    end

    -- PopupTooltip needs an owner. Without InitializeTooltip ESO can clear it again
    -- immediately even while the mouse is still over our recipe row.
    self.recipeTooltipRecipe = recipe
    ClearTooltip(PopupTooltip)
    InitializeTooltip(PopupTooltip, self.window, TOPRIGHT, -12, 0, TOPLEFT)
    PopupTooltip:SetLink(recipe.resultLink)

    -- Some item-tooltip layout code may touch anchors while SetLink builds the
    -- tooltip. Force our final position afterwards so it remains directly left
    -- of Runenwerk.
    PopupTooltip:ClearAnchors()
    local tooltipWidth = PopupTooltip:GetWidth() or 360
    local windowLeft = self.window:GetLeft() or 0
    if windowLeft >= tooltipWidth + 12 then
        PopupTooltip:SetAnchor(TOPRIGHT, self.window, TOPLEFT, -12, 0)
    else
        PopupTooltip:SetAnchor(TOPLEFT, self.window, TOPRIGHT, 12, 0)
    end
    PopupTooltip:SetHidden(false)
end

function RW:CreateRow(parent, index)
    local wm = WINDOW_MANAGER
    local row = wm:CreateControl("RunenwerkRow" .. index, parent, CT_CONTROL)
    row:SetDimensions(940, ROW_HEIGHT)

    if index == 1 then
        row:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    else
        row:SetAnchor(TOPLEFT, self.rows[index - 1], BOTTOMLEFT, 0, ROW_SPACING)
    end

    row.result = wm:CreateControl(nil, row, CT_LABEL)
    row.result:SetFont("ZoFontGame")
    row.result:SetAnchor(LEFT, row, LEFT, 4, 0)
    row.result:SetDimensions(340, 36)
    row.result:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.result:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.result:SetMouseEnabled(true)
    row.result:SetHandler("OnMouseEnter", function(control)
        self:ShowRecipeTooltip(control.recipe)
    end)
    row.result:SetHandler("OnMouseExit", function()
        self:HideRecipeTooltip()
    end)

    row.level = wm:CreateControl(nil, row, CT_LABEL)
    row.level:SetFont("ZoFontGameSmall")
    row.level:SetAnchor(LEFT, row, LEFT, 352, 0)
    row.level:SetDimensions(78, 36)
    row.level:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.level:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    row.runes = wm:CreateControl(nil, row, CT_LABEL)
    row.runes:SetFont("ZoFontGameSmall")
    row.runes:SetAnchor(LEFT, row, LEFT, 438, 0)
    row.runes:SetDimensions(188, 36)
    row.runes:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.runes:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    row.crafted = wm:CreateControl(nil, row, CT_LABEL)
    row.crafted:SetFont("ZoFontGameSmall")
    row.crafted:SetAnchor(LEFT, row, LEFT, 632, 0)
    row.crafted:SetDimensions(82, 36)
    row.crafted:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.crafted:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    row.status = wm:CreateControl(nil, row, CT_LABEL)
    row.status:SetFont("ZoFontGameSmall")
    row.status:SetAnchor(LEFT, row, LEFT, 720, 0)
    row.status:SetDimensions(106, 36)
    row.status:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.status:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    row.craft = wm:CreateControlFromVirtual("RunenwerkCraftButton" .. index, row, "ZO_DefaultButton")
    row.craft:SetDimensions(104, 30)
    row.craft:SetAnchor(RIGHT, row, RIGHT, -2, 0)
    row.craft:SetText(self:L("INSERT"))

    return row
end


function RW:AddBlueFrame(control, namePrefix, thickness)
    if not control then
        return
    end

    thickness = thickness or 2
    local wm = WINDOW_MANAGER
    local frame = {}

    frame.top = wm:CreateControl(namePrefix .. "Top", control, CT_TEXTURE)
    frame.top:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
    frame.top:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
    frame.top:SetHeight(thickness)

    frame.bottom = wm:CreateControl(namePrefix .. "Bottom", control, CT_TEXTURE)
    frame.bottom:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, 0, 0)
    frame.bottom:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
    frame.bottom:SetHeight(thickness)

    frame.left = wm:CreateControl(namePrefix .. "Left", control, CT_TEXTURE)
    frame.left:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
    frame.left:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, 0, 0)
    frame.left:SetWidth(thickness)

    frame.right = wm:CreateControl(namePrefix .. "Right", control, CT_TEXTURE)
    frame.right:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
    frame.right:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
    frame.right:SetWidth(thickness)

    for _, edge in pairs(frame) do
        edge:SetColor(FRAME_BLUE_R, FRAME_BLUE_G, FRAME_BLUE_B, 1)
        edge:SetDrawLayer(DL_OVERLAY)
    end

    return frame
end

function RW:GetScreenDimensions()
    local width = GuiRoot and GuiRoot:GetWidth() or IDEAL_WINDOW_WIDTH
    local height = GuiRoot and GuiRoot:GetHeight() or IDEAL_WINDOW_HEIGHT
    width = tonumber(width) or IDEAL_WINDOW_WIDTH
    height = tonumber(height) or IDEAL_WINDOW_HEIGHT
    return width, height
end

function RW:GetResponsiveDimensions()
    local screenWidth, screenHeight = self:GetScreenDimensions()

    -- ESO's UI dimensions already include the current Interface Scale. Keep a
    -- small screen margin and let the scroll area use the remaining height.
    local availableWidth = math.max(1, screenWidth - (WINDOW_MARGIN * 2))
    local availableHeight = math.max(1, screenHeight - (WINDOW_MARGIN * 2))

    local windowWidth = math.min(IDEAL_WINDOW_WIDTH, availableWidth)
    local windowHeight = math.min(IDEAL_WINDOW_HEIGHT, availableHeight)

    return windowWidth, windowHeight, screenWidth, screenHeight
end

function RW:GetColumnLayout(rowWidth)
    -- The glyph column intentionally receives the flexible remainder. Compact
    -- columns scale down with the available width, especially Runes, while
    -- keeping enough room for their short labels.
    local scale = math.min(1, math.max(0.45, rowWidth / 940))
    local gap = math.max(4, 8 * scale)
    local craftWidth = math.max(64, 104 * scale)
    local statusWidth = math.max(70, 106 * scale)
    local craftedWidth = math.max(60, 82 * scale)
    local levelWidth = math.max(60, 78 * scale)
    local runesWidth = math.max(95, 188 * scale)

    local fixedWidth = levelWidth + runesWidth + craftedWidth + statusWidth + craftWidth + (gap * 5)
    local glyphWidth = math.max(100, rowWidth - fixedWidth)

    -- If even the compact minimums do not fit, reduce the runes column first.
    local overflow = (glyphWidth + fixedWidth) - rowWidth
    if overflow > 0 then
        local reducibleRunes = math.max(0, runesWidth - 72)
        local reduce = math.min(overflow, reducibleRunes)
        runesWidth = runesWidth - reduce
        overflow = overflow - reduce
    end
    if overflow > 0 then
        glyphWidth = math.max(70, glyphWidth - overflow)
    end

    local xGlyph = 4
    local xLevel = xGlyph + glyphWidth + gap
    local xRunes = xLevel + levelWidth + gap
    local xCrafted = xRunes + runesWidth + gap
    local xStatus = xCrafted + craftedWidth + gap

    return {
        glyph = { x = xGlyph, width = glyphWidth },
        level = { x = xLevel, width = levelWidth },
        runes = { x = xRunes, width = runesWidth },
        crafted = { x = xCrafted, width = craftedWidth },
        material = { x = xStatus, width = statusWidth },
        craft = { width = craftWidth },
    }
end

function RW:ResetRecipeScroll()
    local scroll = self.recipeScroll
    if not scroll then
        return
    end

    if ZO_Scroll_ResetToTop then
        ZO_Scroll_ResetToTop(scroll)
        return
    end

    if scroll.SetVerticalScroll then
        scroll:SetVerticalScroll(0)
    end

    local scrollBar = scroll.GetNamedChild and (scroll:GetNamedChild("ScrollBar") or scroll:GetNamedChild("Scrollbar")) or nil
    if scrollBar and scrollBar.SetValue then
        scrollBar:SetValue(0)
    end
end

function RW:EnsureRowCount(count)
    if not self.rows or not self.recipeScrollChild then
        return
    end

    for index = #self.rows + 1, count do
        self.rows[index] = self:CreateRow(self.recipeScrollChild, index)
    end
end

function RW:LayoutRecipeRows()
    if not self.window or not self.recipeScroll or not self.recipeScrollChild then
        return
    end

    local windowWidth = self.window:GetWidth() or IDEAL_WINDOW_WIDTH
    local contentWidth = math.max(1, windowWidth - 40)
    local scrollBarWidth = (ZO_SCROLL_BAR_WIDTH or 18) + 6
    local rowWidth = math.max(1, contentWidth - scrollBarWidth)
    local columns = self:GetColumnLayout(rowWidth)

    if self.columnHeader then
        self.columnHeader:SetDimensions(rowWidth, 28)
    end

    if self.columnHeaderButtons then
        for key, button in pairs(self.columnHeaderButtons) do
            local layout = columns[key]
            if layout then
                button:ClearAnchors()
                button:SetAnchor(LEFT, self.columnHeader, LEFT, layout.x, 0)
                button:SetDimensions(layout.width, 26)
                if button.runenwerkLabel then
                    button.runenwerkLabel:ClearAnchors()
                    button.runenwerkLabel:SetAnchor(LEFT, self.columnHeader, LEFT, layout.x, 0)
                    button.runenwerkLabel:SetDimensions(layout.width, 26)
                end
            end
        end
    end

    for index, row in ipairs(self.rows or {}) do
        row:SetDimensions(rowWidth, ROW_HEIGHT)
        row:ClearAnchors()
        if index == 1 then
            row:SetAnchor(TOPLEFT, self.recipeScrollChild, TOPLEFT, 0, 0)
        else
            row:SetAnchor(TOPLEFT, self.rows[index - 1], BOTTOMLEFT, 0, ROW_SPACING)
        end

        row.result:ClearAnchors()
        row.result:SetAnchor(LEFT, row, LEFT, columns.glyph.x, 0)
        row.result:SetDimensions(columns.glyph.width, 36)

        row.level:ClearAnchors()
        row.level:SetAnchor(LEFT, row, LEFT, columns.level.x, 0)
        row.level:SetDimensions(columns.level.width, 36)

        row.runes:ClearAnchors()
        row.runes:SetAnchor(LEFT, row, LEFT, columns.runes.x, 0)
        row.runes:SetDimensions(columns.runes.width, 36)

        row.crafted:ClearAnchors()
        row.crafted:SetAnchor(LEFT, row, LEFT, columns.crafted.x, 0)
        row.crafted:SetDimensions(columns.crafted.width, 36)

        row.status:ClearAnchors()
        row.status:SetAnchor(LEFT, row, LEFT, columns.material.x, 0)
        row.status:SetDimensions(columns.material.width, 36)

        row.craft:SetDimensions(columns.craft.width, 30)
        row.craft:ClearAnchors()
        row.craft:SetAnchor(RIGHT, row, RIGHT, -2, 0)
    end

    local recipeCount = #self.recipeList
    local contentHeight = recipeCount > 0 and ((recipeCount * ROW_HEIGHT) + ((recipeCount - 1) * ROW_SPACING)) or 1
    local viewportHeight = self.recipeScroll:GetHeight() or 1
    self.recipeScrollChild:SetDimensions(rowWidth, math.max(viewportHeight, contentHeight))
end

function RW:ApplyResponsiveLayout()
    if not self.window then
        return
    end

    local windowWidth, windowHeight, screenWidth, screenHeight = self:GetResponsiveDimensions()
    self.window:SetDimensions(windowWidth, windowHeight)

    local contentWidth = math.max(1, windowWidth - 40)

    if self.recipeScroll then
        self.recipeScroll:ClearAnchors()
        self.recipeScroll:SetAnchor(TOPLEFT, self.window, TOPLEFT, 20, 132)
        self.recipeScroll:SetAnchor(BOTTOMRIGHT, self.window, BOTTOMRIGHT, -20, -20)
    end

    if self.categoryButtons then
        local categoryGap = 10
        local categoryWidth = math.max(1, (contentWidth - (categoryGap * 3)) / 4)
        local order = { "all", "weapon", "armor", "jewelry" }
        for index, key in ipairs(order) do
            local button = self.categoryButtons[key]
            if button then
                button:ClearAnchors()
                button:SetDimensions(categoryWidth, 30)
                button:SetAnchor(TOPLEFT, self.window, TOPLEFT, 20 + ((index - 1) * (categoryWidth + categoryGap)), 58)
            end
        end
    end

    if self.emptyLabel then
        self.emptyLabel:SetDimensions(math.max(1, contentWidth - 40), 80)
    end

    self:LayoutRecipeRows()

    -- Keep a previously saved or dragged window completely on-screen after a
    -- resolution / UI-scale change.
    local left = self.window:GetLeft()
    local top = self.window:GetTop()
    if left == nil then
        left = self.saved and self.saved.window.left or (screenWidth - windowWidth) / 2
    end
    if top == nil then
        top = self.saved and self.saved.window.top or (screenHeight - windowHeight) / 2
    end

    left = zo_clamp(left or 0, 0, math.max(0, screenWidth - windowWidth))
    top = zo_clamp(top or 0, 0, math.max(0, screenHeight - windowHeight))
    self.window:ClearAnchors()
    self.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)

    if self.saved and self.saved.window then
        self.saved.window.left = left
        self.saved.window.top = top
    end

    self:RefreshRecipeList()
    self:RefreshWindow()

    if not self.window:IsHidden() then
        self:DockESOResultTooltip()
        if self.recipeTooltipRecipe then
            self:ShowRecipeTooltip(self.recipeTooltipRecipe)
        end
    end
end

function RW:SaveWindowPosition()
    if not self.window or not self.saved or not self.saved.window then
        return
    end

    self.saved.window.left = self.window:GetLeft()
    self.saved.window.top = self.window:GetTop()
end

function RW:UpdateWindowPin()
    if not self.saved then
        return
    end

    local locked = self.saved.windowLocked == true

    if self.window then
        self.window:SetMovable(not locked)
    end

    if self.pinButton then
        local texture = locked and "Runenwerk/art/pin_fixed.dds" or "Runenwerk/art/pin_free.dds"
        self.pinButton:SetNormalTexture(texture)
        self.pinButton:SetPressedTexture(texture)
        self.pinButton:SetMouseOverTexture(texture)
    end
end

function RW:ToggleWindowPin()
    if not self.saved then
        return
    end

    self.saved.windowLocked = not (self.saved.windowLocked == true)
    self.windowDragActive = false
    if self.window then
        self.window:StopMovingOrResizing()
    end
    self:UpdateWindowPin()
end

function RW:ResetWindowPosition()
    if not self.saved or not self.saved.window then
        return
    end

    self.saved.window.left = nil
    self.saved.window.top = nil

    if self.window then
        self.window:StopMovingOrResizing()
        self.windowDragActive = false
        self.window:ClearAnchors()
        self.window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        self:ApplyResponsiveLayout()
        self:SaveWindowPosition()
        self:DockESOResultTooltip()
    end
end

function RW:CreateWindow()
    local wm = WINDOW_MANAGER
    local window = wm:CreateTopLevelWindow("RunenwerkWindow")
    self.window = window

    window:SetDimensions(980, 620)
    window:SetMouseEnabled(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:SetHidden(true)

    if self.saved.window.left and self.saved.window.top then
        window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.saved.window.left, self.saved.window.top)
    else
        window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end

    -- Moving is handled by the title drag area below. Do not let other mouse
    -- buttons start or finish a move on the top-level window itself.
    window:SetHandler("OnMouseDown", nil)
    window:SetHandler("OnMouseUp", function(control, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not self.windowDragActive then
            return
        end
        self.windowDragActive = false
        control:StopMovingOrResizing()
        self:SaveWindowPosition()
        self:DockESOResultTooltip()
    end)
    window:SetHandler("OnShow", function()
        self:ApplyResponsiveLayout()
        self:DockESOResultTooltip()
    end)
    window:SetHandler("OnHide", function()
        self.openedFromSettings = false
        self.openedFromMainMenu = false
        self:HideRecipeTooltip()
        self:RestoreESOResultTooltip()
    end)

    local backdrop = wm:CreateControlFromVirtual("RunenwerkBackdrop", window, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(window)
    if backdrop.SetEdgeColor then
        backdrop:SetEdgeColor(FRAME_BLUE_R, FRAME_BLUE_G, FRAME_BLUE_B, 1)
    end
    self.windowFrame = self:AddBlueFrame(window, "RunenwerkWindowFrame", 2)

    -- Dedicated title drag area: only the left mouse button moves the window.
    self.dragHandle = wm:CreateControl("RunenwerkDragHandle", window, CT_CONTROL)
    self.dragHandle:SetAnchor(TOPLEFT, window, TOPLEFT, 4, 4)
    self.dragHandle:SetAnchor(TOPRIGHT, window, TOPRIGHT, -4, 4)
    self.dragHandle:SetHeight(46)
    self.dragHandle:SetMouseEnabled(true)
    self.dragHandle:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or self.saved.windowLocked == true then
            return
        end
        self.windowDragActive = true
        window:StartMoving()
    end)
    self.dragHandle:SetHandler("OnMouseUp", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not self.windowDragActive then
            return
        end
        self.windowDragActive = false
        window:StopMovingOrResizing()
        self:SaveWindowPosition()
        self:DockESOResultTooltip()
    end)

    local title = wm:CreateControl(nil, window, CT_LABEL)
    title:SetFont("ZoFontWinH1")
    title:SetText("|c7FC7FF" .. self:L("TITLE") .. "|r")
    title:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 15)

    self.categoryButtons = {}
    local categoryDefinitions = {
        { key = "all", x = 20, width = 220 },
        { key = "weapon", x = 250, width = 220 },
        { key = "armor", x = 480, width = 220 },
        { key = "jewelry", x = 710, width = 220 },
    }

    for _, definition in ipairs(categoryDefinitions) do
        local categoryKey = definition.key
        local button = wm:CreateControlFromVirtual("RunenwerkCategory_" .. categoryKey, window, "ZO_DefaultButton")
        button:SetDimensions(definition.width, 30)
        button:SetAnchor(TOPLEFT, window, TOPLEFT, definition.x, 58)
        button:SetHandler("OnClicked", function()
            self:SetCategoryFilter(categoryKey)
        end)
        self.categoryButtons[categoryKey] = button
    end

    self.closeButton = wm:CreateControlFromVirtual("RunenwerkCloseButton", window, "ZO_DefaultButton")
    self.closeButton:SetDimensions(100, 30)
    self.closeButton:SetAnchor(TOPRIGHT, window, TOPRIGHT, -16, 16)
    self.closeButton:SetText(self:L("CLOSE"))
    self.closeButton:SetHandler("OnClicked", function() window:SetHidden(true) end)

    self.pinButton = wm:CreateControl("RunenwerkPinButton", window, CT_BUTTON)
    self.pinButton:SetDimensions(24, 24)
    self.pinButton:SetAnchor(RIGHT, self.closeButton, LEFT, -8, 0)
    self.pinButton:SetHandler("OnClicked", function()
        self:ToggleWindowPin()
    end)
    self.pinButton:SetHandler("OnMouseEnter", function(control)
        InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -4, TOP)
        local key = self.saved.windowLocked and "WINDOW_UNPIN_TOOLTIP" or "WINDOW_PIN_TOOLTIP"
        SetTooltipText(InformationTooltip, self:L(key))
    end)
    self.pinButton:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)
    self:UpdateWindowPin()

    self.columnHeader = wm:CreateControl("RunenwerkColumnHeader", window, CT_CONTROL)
    self.columnHeader:SetDimensions(940, 28)
    self.columnHeader:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 98)

    self.columnHeaderButtons = {}

    local function HeaderButton(sortColumn, x, width, align)
        -- Keep the visible caption separate from the clickable control. ESO's
        -- CT_BUTTON mouse-over state can otherwise replace/hide its own text.
        local label = wm:CreateControl(nil, self.columnHeader, CT_LABEL)
        label:SetFont("ZoFontGame")
        label:SetAnchor(LEFT, self.columnHeader, LEFT, x, 0)
        label:SetDimensions(width, 26)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
        label:SetMouseEnabled(false)

        local button = wm:CreateControl(nil, self.columnHeader, CT_BUTTON)
        button:SetAnchor(LEFT, self.columnHeader, LEFT, x, 0)
        button:SetDimensions(width, 26)
        button:SetHandler("OnClicked", function()
            self:ToggleSort(sortColumn)
        end)
        button.runenwerkLabel = label
        self.columnHeaderButtons[sortColumn] = button
        return button
    end

    HeaderButton("glyph", 4, 340)
    HeaderButton("level", 352, 78, TEXT_ALIGN_CENTER)
    HeaderButton("runes", 438, 188)
    HeaderButton("crafted", 632, 82, TEXT_ALIGN_CENTER)
    HeaderButton("material", 720, 106, TEXT_ALIGN_CENTER)
    self:UpdateSortHeaders()

    self.emptyLabel = wm:CreateControl(nil, window, CT_LABEL)
    self.emptyLabel:SetFont("ZoFontGame")
    self.emptyLabel:SetDimensions(900, 80)
    self.emptyLabel:SetAnchor(CENTER, window, CENTER, 0, -10)
    self.emptyLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.emptyLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.emptyLabel:SetText(self:L("EMPTY"))

    self.recipeScroll = wm:CreateControlFromVirtual("RunenwerkRecipeScroll", window, "ZO_ScrollContainer")
    self.recipeScroll:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 132)
    self.recipeScroll:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -20, -20)
    ZO_Scroll_Initialize(self.recipeScroll)

    self.recipeScrollChild = self.recipeScroll:GetNamedChild("ScrollChild")
    if self.recipeScrollChild then
        self.recipeScrollChild:SetResizeToFitDescendents(false)
    end

    self.rows = {}

    self:ApplyResponsiveLayout()
end

function RW:RefreshWindow()
    if not self.window then
        return
    end

    local recipeCount = #self.recipeList
    local totalRecipeCount = #self.allRecipes

    self.emptyLabel:SetHidden(recipeCount > 0)
    if recipeCount == 0 then
        if totalRecipeCount == 0 then
            self.emptyLabel:SetText(self:L("EMPTY"))
        else
            self.emptyLabel:SetText(self:L("NO_MATCHES"))
        end
    end

    if self.recipeScroll then
        self.recipeScroll:SetHidden(recipeCount == 0)
    end

    self:RefreshCategoryButtons()
    self:UpdateSortHeaders()
    self:EnsureRowCount(recipeCount)

    for rowIndex, row in ipairs(self.rows) do
        local recipe = self.recipeList[rowIndex]
        if recipe then
            row:SetHidden(false)

            local resultText = recipe.resultName or ItemNameFromLink(recipe.resultLink) or "?"
            if self.categoryFilter == "all" then
                row.result:SetText(string.format("[%s] %s", self:GetCategoryName(recipe.itemType), resultText))
            else
                row.result:SetText(resultText)
            end
            row.result.recipe = recipe

            local qualityColor = GetItemQualityColor(recipe.quality or ITEM_DISPLAY_QUALITY_NORMAL)
            if qualityColor then
                row.result:SetColor(qualityColor:UnpackRGBA())
            else
                row.result:SetColor(1, 1, 1, 1)
            end

            row.level:SetText(self:FormatMinimumLevel(recipe))
            row.runes:SetText(string.format(
                "%s + %s + %s",
                recipe.potency.name or "?",
                recipe.essence.name or "?",
                recipe.aspect.name or "?"
            ))
            row.crafted:SetText(string.format("%d×", recipe.craftCount or 0))

            local materialsReady = self:HasRecipeMaterials(recipe)
            if materialsReady then
                row.status:SetText("|c66CC66" .. self:L("MATERIALS_READY_SHORT") .. "|r")
            else
                row.status:SetText("|cCC6666" .. self:L("MATERIALS_MISSING_SHORT") .. "|r")
            end

            row.craft:SetEnabled(materialsReady)
            row.craft:SetHandler("OnClicked", function()
                self:InsertRecipe(recipe)
            end)
        else
            row:SetHidden(true)
            row.result.recipe = nil
            row.craft:SetHandler("OnClicked", nil)
        end
    end

    self:LayoutRecipeRows()

    if not self.window:IsHidden() then
        self:DockESOResultTooltip()
    end
end

function RW:GetESOResultTooltip()
    if ENCHANTING and ENCHANTING.resultTooltip then
        return ENCHANTING.resultTooltip
    end
    local root = _G["ZO_EnchantingTopLevel"]
    return root and root.GetNamedChild and root:GetNamedChild("Tooltip") or nil
end

function RW:CaptureESOResultTooltipAnchor()
    if self.esoResultTooltipOriginalAnchor then
        return
    end
    local tooltip = self:GetESOResultTooltip()
    if not tooltip or not tooltip.GetAnchor then
        return
    end
    local isValid, point, relativeTo, relativePoint, offsetX, offsetY = tooltip:GetAnchor(0)
    if isValid then
        self.esoResultTooltipOriginalAnchor = { point, relativeTo, relativePoint, offsetX or 0, offsetY or 0 }
    end
end

function RW:DockESOResultTooltip()
    if not self.window or self.window:IsHidden() then
        return
    end
    local tooltip = self:GetESOResultTooltip()
    if not tooltip then
        return
    end
    self:CaptureESOResultTooltipAnchor()
    tooltip:ClearAnchors()
    local tooltipWidth = tooltip:GetWidth() or 360
    local windowLeft = self.window:GetLeft() or 0
    if windowLeft >= tooltipWidth + 12 then
        tooltip:SetAnchor(BOTTOMRIGHT, self.window, BOTTOMLEFT, -12, 0)
    else
        tooltip:SetAnchor(BOTTOMLEFT, self.window, BOTTOMRIGHT, 12, 0)
    end
end

function RW:RestoreESOResultTooltip()
    local tooltip = self:GetESOResultTooltip()
    local anchor = self.esoResultTooltipOriginalAnchor
    if not tooltip or not anchor then
        return
    end
    tooltip:ClearAnchors()
    tooltip:SetAnchor(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
    self.esoResultTooltipOriginalAnchor = nil
end

local RUNENWERK_MODE_DESCRIPTOR = "RUNENWERK_RECIPE_BOOK"

function RW:GetEnchantingModeBar()
    if ENCHANTING and ENCHANTING.modeBar then
        return ENCHANTING.modeBar
    end

    local root = _G["ZO_EnchantingTopLevel"]
    if root and root.GetNamedChild then
        return root:GetNamedChild("ModeMenuBar")
    end

    return nil
end

function RW:StyleStationMenuButton(button)
    if not button or button.runenwerkStyled then
        return
    end
    button.runenwerkStyled = true

    -- Keep ESO's native menu-button dimensions and presentation untouched so
    -- the Runenwerk icon has exactly the same size as ESO's own mode icons.
end

function RW:EnsureStationButton()
    if self.stationButton then
        return true
    end

    local modeBar = self:GetEnchantingModeBar()
    if not modeBar or not ZO_MenuBar_AddButton then
        return false
    end

    local texture = "Runenwerk/art/runenwerk_icon.dds"
    local buttonData = {
        descriptor = RUNENWERK_MODE_DESCRIPTOR,
        categoryName = self:L("STATION_BUTTON_TOOLTIP"),
        normal = texture,
        pressed = texture,
        highlight = texture,
        disabled = texture,
        callback = function()
            self:ToggleWindow()
            PlaySound(SOUNDS.DEFAULT_CLICK)

            -- Runenwerk is a utility button, not a fourth enchanting mode.
            -- Hand the visual selection straight back to ESO's current mode.
            zo_callLater(function()
                if ENCHANTING and ENCHANTING.modeBar and ENCHANTING.GetEnchantingMode then
                    local currentMode = ENCHANTING:GetEnchantingMode()
                    if currentMode then
                        ZO_MenuBar_SelectDescriptor(ENCHANTING.modeBar, currentMode)
                    end
                end
            end, 0)
        end,
        onInitializeCallback = function(button)
            self:StyleStationMenuButton(button)
        end,
    }

    self.stationButton = ZO_MenuBar_AddButton(modeBar, buttonData)
    self:StyleStationMenuButton(self.stationButton)
    return self.stationButton ~= nil
end

function RW:CreateStationButton()
    -- ENCHANTING is normally initialized before user addons, but keep this
    -- tolerant so the button can also be added on first station interaction.
    self:EnsureStationButton()
end

function RW:UpdateStationButton(craftingType)
    if craftingType == CRAFTING_TYPE_INVALID then
        return
    end

    local liveCraftingType = GetCraftingInteractionType()
    craftingType = craftingType or liveCraftingType
    if (craftingType == CRAFTING_TYPE_ENCHANTING or liveCraftingType == CRAFTING_TYPE_ENCHANTING)
        and not IsInGamepadPreferredMode() then
        self:EnsureStationButton()
    end
end

function RW:OpenWindow(openedFromSettings, openedFromMainMenu)
    if not self.window then
        return
    end

    -- Every newly opened Runenwerk window starts with the persistent
    -- default sorting selected in the settings menu.
    self:ResetActiveSortToSettings()
    self:RefreshRecipeList()
    self:RefreshWindow()
    self:ResetRecipeScroll()
    self.openedFromSettings = openedFromSettings == true
    self.openedFromMainMenu = openedFromMainMenu == true
    self.window:SetHidden(false)
end

function RW:ToggleWindow()
    if not self.window then
        return
    end

    if self.window:IsHidden() then
        self:OpenWindow(false, false)
    else
        self.window:SetHidden(true)
    end
end

function RW:OpenWindowFromSettings()
    self:OpenWindow(true, false)
end

function RW:ToggleWindowFromMainMenu()
    if not self.window then
        return
    end

    if self.window:IsHidden() then
        self:OpenWindow(false, true)
    else
        self.window:SetHidden(true)
    end
end

local RUNENWERK_MAIN_MENU_DESCRIPTOR = "RUNENWERK_MAIN_MENU"

function RW:GetKeyboardMainMenu()
    if IsInGamepadPreferredMode() then
        return nil
    end

    local mainMenu = SYSTEMS and SYSTEMS:GetObject("mainMenu") or nil
    if mainMenu and mainMenu.categoryBar then
        return mainMenu
    end

    return nil
end

function RW:EnsureMainMenuButton()
    if self.mainMenuButton then
        return true
    end

    local mainMenu = self:GetKeyboardMainMenu()
    if not mainMenu or not mainMenu.categoryBar or not ZO_MenuBar_AddButton then
        return false
    end

    if not _G["SI_RUNENWERK_MAIN_MENU_CATEGORY"] then
        ZO_CreateStringId("SI_RUNENWERK_MAIN_MENU_CATEGORY", self:L("TITLE"))
    end

    local texture = "Runenwerk/art/runenwerk_icon.dds"
    local buttonData = {
        descriptor = RUNENWERK_MAIN_MENU_DESCRIPTOR,
        categoryName = _G["SI_RUNENWERK_MAIN_MENU_CATEGORY"],
        normal = texture,
        pressed = texture,
        highlight = texture,
        disabled = texture,
        visible = function()
            return not self.saved or self.saved.showMainMenuButton ~= false
        end,
        callback = function()
            self:ToggleWindowFromMainMenu()
            PlaySound(SOUNDS.DEFAULT_CLICK)

            -- Runenwerk is a utility entry, not an ESO category. Keep the
            -- actual ESO category selected so normal main-menu state stays intact.
            zo_callLater(function()
                local keyboardMainMenu = self:GetKeyboardMainMenu()
                if keyboardMainMenu and keyboardMainMenu.categoryBar and keyboardMainMenu.lastCategory then
                    ZO_MenuBar_SelectDescriptor(keyboardMainMenu.categoryBar, keyboardMainMenu.lastCategory, true)
                end
            end, 0)
        end,
    }

    self.mainMenuButton = ZO_MenuBar_AddButton(mainMenu.categoryBar, buttonData)
    self.mainMenuBar = mainMenu.categoryBar

    -- When Runenwerk was opened from the normal ESO main menu, leaving that
    -- menu closes Runenwerk as well. Other opening methods stay independent.
    if not self.mainMenuCloseHookInstalled and mainMenu.categoryBarFragment then
        self.mainMenuCloseHookInstalled = true
        mainMenu.categoryBarFragment:RegisterCallback("StateChange", function(_, newState)
            if (newState == SCENE_FRAGMENT_HIDING or newState == SCENE_FRAGMENT_HIDDEN)
                and self.openedFromMainMenu
                and self.window and not self.window:IsHidden() then
                self.window:SetHidden(true)
            end
        end)
    end

    return self.mainMenuButton ~= nil
end

function RW:UpdateMainMenuButton()
    if not IsInGamepadPreferredMode() then
        self:EnsureMainMenuButton()
    end

    if self.mainMenuBar and ZO_MenuBar_UpdateButtons then
        ZO_MenuBar_UpdateButtons(self.mainMenuBar)
    end
end

function RW:InstallEnchantingHook()
    if not ZO_SharedEnchanting or not ZO_SharedEnchanting.Create then
        return
    end

    ZO_PreHook(ZO_SharedEnchanting, "Create", function(enchantingObject, numIterations)
        self:CaptureFromEnchantingObject(enchantingObject, numIterations)
        return false
    end)
end

function RW:Initialize()
    self.language = GetLanguage()

    local defaults = {
        recipes = {},
        autoOpenAtStation = false,
        closeAfterInsert = true,
        chatMessages = true,
        showMainMenuButton = true,
        windowLocked = false,
        sortColumn = "glyph",
        sortAscending = true,
        window = {
            left = nil,
            top = nil,
        },
    }

    self.defaults = defaults

    self.saved = ZO_SavedVars:NewAccountWide(
        "RunenwerkSavedVariables",
        1,
        GetWorldName(),
        defaults
    )

    if self.saved.autoOpenAtStation == nil then
        self.saved.autoOpenAtStation = false
    end
    if self.saved.closeAfterInsert == nil then
        self.saved.closeAfterInsert = true
    end
    if self.saved.chatMessages == nil then
        self.saved.chatMessages = true
    end
    if self.saved.showMainMenuButton == nil then
        self.saved.showMainMenuButton = true
    end
    if self.saved.windowLocked == nil then
        self.saved.windowLocked = false
    end
    local validSortColumns = {
        glyph = true,
        level = true,
        runes = true,
        crafted = true,
        material = true,
    }
    if not validSortColumns[self.saved.sortColumn] then
        self.saved.sortColumn = "glyph"
    end
    if self.saved.sortAscending == nil then
        self.saved.sortAscending = true
    end

    self:ResetActiveSortToSettings()
    self:RefreshRecipeList()
    self:CreateWindow()
    if self.BuildSettings then
        self:BuildSettings()
    end
    self:CreateStationButton()
    self:UpdateMainMenuButton()
    self:InstallEnchantingHook()
    self:InstallResultTooltipHook()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CRAFTING_STATION_INTERACT, function(_, craftingType, sameStation, craftMode)
        self:UpdateStationButton(craftingType)

        if craftingType == CRAFTING_TYPE_ENCHANTING and self.saved.autoOpenAtStation then
            -- Let ESO finish showing and laying out the enchanting scene first.
            -- Then open Runenwerk without toggling it closed if another callback
            -- already made the window visible.
            zo_callLater(function()
                if GetCraftingInteractionType() ~= CRAFTING_TYPE_ENCHANTING or not self.window then
                    return
                end
                self:ResetActiveSortToSettings()
                self:RefreshRecipeList()
                self:RefreshWindow()
                self:ResetRecipeScroll()
                self.openedFromSettings = false
                self.openedFromMainMenu = false
                self.window:SetHidden(false)
            end, 100)
        end
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CRAFT_COMPLETED, function(_, craftingType)
        self:OnCraftCompleted(craftingType)
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CRAFT_FAILED, function()
        self:OnCraftFailed()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_END_CRAFTING_STATION_INTERACT, function()
        self.pendingCraft = nil

        -- Leaving the crafting station always closes Runenwerk. The close-after-insert
        -- setting only controls what happens after pressing "Insert" while still at
        -- the station.
        if self.window then
            self.window:SetHidden(true)
        end
        self:HideRecipeTooltip()
        ClearTooltip(InformationTooltip)
        self:RestoreESOResultTooltip()

        self:UpdateStationButton(CRAFTING_TYPE_INVALID)
        self:RefreshWindow()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        self:UpdateStationButton()
        self:UpdateMainMenuButton()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_SCREEN_RESIZED, function()
        zo_callLater(function()
            if self.window then
                self:ApplyResponsiveLayout()
            end
        end, 0)
    end)

    SLASH_COMMANDS["/runenwerk"] = function()
        self:ToggleWindow()
    end

    self:UpdateStationButton()
    self:UpdateMainMenuButton()

    if self.saved.chatMessages then
        d(string.format("|c7FC7FF%s|r %s - %s", ADDON_NAME, ADDON_VERSION, self:L("SLASH_HELP")))
    end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    RW:Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
