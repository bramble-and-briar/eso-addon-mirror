Alchemiewerk = Alchemiewerk or {}
local AW = Alchemiewerk

AW.name = "Alchemiewerk"
AW.version = "1.0.2"
AW.svVersion = 1
AW.maxRows = 10
AW.rowsPerPage = 8
AW.currentPage = 1
AW.scrollOffset = 0
AW.scrollMaxOffset = 0
AW.updatingScrollBar = false
AW.filter = "all"
AW.pendingCraft = nil
AW.atAlchemyStation = false
AW.sortColumn = "name"
AW.sortAscending = true
AW.openedFromSettings = false
AW.openedFromMainMenu = false
AW.stationDescriptor = "ALCHEMIEWERK_STATION"
AW.mainMenuDescriptor = "ALCHEMIEWERK_MAIN_MENU"
AW.expandedGroups = {}
AW.alchemyTooltipAnchors = nil
AW.hoveredRow = nil
AW.recipeTooltipRecipe = nil
AW.esoResultTooltipOriginalAnchor = nil
AW.combinationTooltipHooked = false

local BLUE_R, BLUE_G, BLUE_B = 0.498, 0.780, 1.000
local UPDATE_51_API_VERSION = 101051
local WHITE_R, WHITE_G, WHITE_B = 0.83, 0.90, 0.95

-- Visual layout intentionally mirrors Runenwerk 0.1.30.
local IDEAL_WINDOW_WIDTH = 980
local IDEAL_WINDOW_HEIGHT = 620
local WINDOW_MARGIN = 20
local ROW_HEIGHT = 42
local ROW_SPACING = 2

local ICON_TEXTURE = "Alchemiewerk/art/alchemiewerk_icon.dds"
local ICON_UP = ICON_TEXTURE
local ICON_DOWN = ICON_TEXTURE
local ICON_OVER = ICON_TEXTURE
local ICON_DISABLED = ICON_TEXTURE
local PIN_TEXTURE = "Alchemiewerk/art/alchemiewerk_pin.dds"

local function S(id, ...)
    local text = GetString(id)
    if select("#", ...) > 0 then
        return string.format(text, ...)
    end
    return text
end

local function infoChat(text)
    if AW.sv and AW.sv.settings and AW.sv.settings.chatMessages == false then return end
    d(string.format("|c7FC7FF%s|r: %s", S(SI_AW_TITLE), text))
end

local function warningChat(text)
    d(string.format("|c7FC7FF%s|r: %s", S(SI_AW_TITLE), text))
end

local function normalizeText(text)
    return zo_strlower(text or "")
end

local function itemNameFromLink(link)
    if not link or link == "" then return S(SI_AW_UNKNOWN) end
    local name = GetItemLinkName(link)
    if not name or name == "" then return S(SI_AW_UNKNOWN) end
    return zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
end

local function makeBackdrop(parent, name)
    local control = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    control:SetCenterColor(0.025, 0.025, 0.025, 0.94)
    control:SetEdgeColor(BLUE_R, BLUE_G, BLUE_B, 0.80)
    return control
end

local function makeAccentLine(parent, name)
    local line = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
    line:SetColor(BLUE_R, BLUE_G, BLUE_B, 0.95)
    return line
end

local function makeButton(parent, name, text, width, height)
    local button = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    button:SetDimensions(width, height)
    button:SetFont("ZoFontGame")
    button:SetText(text)
    button:SetNormalFontColor(WHITE_R, WHITE_G, WHITE_B, 1)
    button:SetMouseOverFontColor(1, 1, 1, 1)
    button:SetPressedFontColor(BLUE_R, BLUE_G, BLUE_B, 1)
    return button
end

function AW:AddBlueFrame(control, namePrefix, thickness)
    if not control then return nil end
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
        edge:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
        edge:SetDrawLayer(DL_OVERLAY)
    end

    return frame
end

local function captureItem(bagId, slotIndex)
    if bagId == nil or slotIndex == nil then return nil end
    local itemId = GetItemId(bagId, slotIndex)
    if not itemId or itemId == 0 then return nil end
    local link = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    return {
        itemId = itemId,
        itemLink = link,
        name = itemNameFromLink(link),
    }
end

local function sortedReagents(reagents)
    table.sort(reagents, function(a, b)
        if a.itemId == b.itemId then
            return (a.name or "") < (b.name or "")
        end
        return a.itemId < b.itemId
    end)
    return reagents
end

function AW:MakeFormulaKey(solventId, reagents)
    local ids = {}
    for i = 1, #reagents do
        ids[#ids + 1] = reagents[i].itemId
    end
    table.sort(ids)
    return tostring(solventId) .. ":" .. table.concat(ids, ":")
end

function AW:CaptureAlchemyCraft(solventBagId, solventSlotIndex,
                                reagent1BagId, reagent1SlotIndex,
                                reagent2BagId, reagent2SlotIndex,
                                reagent3BagId, reagent3SlotIndex,
                                numIterations)
    if GetCraftingInteractionType() ~= CRAFTING_TYPE_ALCHEMY then return end

    local solvent = captureItem(solventBagId, solventSlotIndex)
    local reagent1 = captureItem(reagent1BagId, reagent1SlotIndex)
    local reagent2 = captureItem(reagent2BagId, reagent2SlotIndex)
    local reagent3 = captureItem(reagent3BagId, reagent3SlotIndex)

    if not solvent or not reagent1 or not reagent2 then
        self.pendingCraft = nil
        return
    end

    local reagents = { reagent1, reagent2 }
    if reagent3 then reagents[#reagents + 1] = reagent3 end
    sortedReagents(reagents)

    self.pendingCraft = {
        solvent = solvent,
        reagents = reagents,
        numIterations = math.max(1, tonumber(numIterations) or 1),
        timestamp = GetTimeStamp(),
    }
end

function AW:GetCraftResultLink()
    local count = 1
    if GetNumLastCraftingResultItemsAndPenalty then
        local n = GetNumLastCraftingResultItemsAndPenalty()
        if type(n) == "number" and n > 0 then count = n end
    end

    for i = 1, count do
        local link = GetLastCraftingResultItemLink(i, LINK_STYLE_DEFAULT)
        if link and link ~= "" then
            local itemType = GetItemLinkItemType(link)
            if itemType == ITEMTYPE_POTION or itemType == ITEMTYPE_POISON then
                return link, itemType
            end
        end
    end
    return nil, nil
end

function AW:GetRequiredLevelData(link)
    local cp = 0
    local level = 0
    if GetItemLinkRequiredChampionPoints then
        cp = tonumber(GetItemLinkRequiredChampionPoints(link)) or 0
    end
    if GetItemLinkRequiredLevel then
        level = tonumber(GetItemLinkRequiredLevel(link)) or 0
    end

    if cp > 0 then
        return S(SI_AW_CP, cp), 10000 + cp
    end
    if level <= 0 then level = 1 end
    return S(SI_AW_LEVEL, level), level
end

function AW:OnCraftCompleted(craftSkill)
    if craftSkill ~= CRAFTING_TYPE_ALCHEMY or not self.pendingCraft then return end

    local resultLink, resultType = self:GetCraftResultLink()
    if not resultLink then
        self.pendingCraft = nil
        return
    end

    local pending = self.pendingCraft
    self.pendingCraft = nil

    local key = self:MakeFormulaKey(pending.solvent.itemId, pending.reagents)
    local existing = self.sv.recipes[key]
    local isNew = existing == nil
    local levelText, levelValue = self:GetRequiredLevelData(resultLink)
    local craftedCount = (existing and tonumber(existing.craftedCount) or 0) + pending.numIterations

    self.sv.recipes[key] = {
        solvent = pending.solvent,
        reagents = pending.reagents,
        resultLink = resultLink,
        resultName = itemNameFromLink(resultLink),
        resultType = resultType,
        learnedAt = existing and existing.learnedAt or GetTimeStamp(),
        updatedAt = GetTimeStamp(),
        craftedCount = craftedCount,
        minLevelText = levelText,
        minLevelValue = levelValue,
        validatedApiVersion = GetAPIVersion and GetAPIVersion() or UPDATE_51_API_VERSION,
        currentApiUncraftable = false,
    }

    if isNew then
        infoChat(S(SI_AW_LEARNED, resultLink))
    end

    if self.window and not self.window:IsHidden() then
        self:RefreshList()
    end
end

function AW:FindItem(itemId)
    local normalBags = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
    for _, bagId in ipairs(normalBags) do
        local size = GetBagSize(bagId) or 0
        for slotIndex = 0, size - 1 do
            if GetItemId(bagId, slotIndex) == itemId then
                local stack = GetSlotStackSize(bagId, slotIndex)
                if stack and stack > 0 then
                    return bagId, slotIndex, stack
                end
            end
        end
    end

    if HasCraftBagAccess and HasCraftBagAccess() then
        local slotIndex = GetNextVirtualBagSlotId()
        while slotIndex do
            if GetItemId(BAG_VIRTUAL, slotIndex) == itemId then
                local stack = GetSlotStackSize(BAG_VIRTUAL, slotIndex)
                if stack and stack > 0 then
                    return BAG_VIRTUAL, slotIndex, stack
                end
            end
            slotIndex = GetNextVirtualBagSlotId(slotIndex)
        end
    end

    return nil, nil, 0
end

function AW:GetMissingItems(recipe)
    local missing = {}

    local solventBag = self:FindItem(recipe.solvent.itemId)
    if not solventBag then
        missing[#missing + 1] = recipe.solvent.name or S(SI_AW_UNKNOWN)
    end

    for _, reagent in ipairs(recipe.reagents or {}) do
        local bag = self:FindItem(reagent.itemId)
        if not bag then
            missing[#missing + 1] = reagent.name or S(SI_AW_UNKNOWN)
        end
    end

    return missing
end

function AW:GetRecipeResultFromCurrentAlchemyAPI(solventBag, solventSlot, reagentSlots)
    if not GetAlchemyResultingItemLink or not solventBag or not solventSlot then
        return nil, nil
    end
    if not reagentSlots or #reagentSlots < 2 then
        return nil, nil
    end

    local reagent1 = reagentSlots[1]
    local reagent2 = reagentSlots[2]
    local reagent3 = reagentSlots[3]

    local ok, resultLink, prospectiveResult
    if reagent3 then
        ok, resultLink, prospectiveResult = pcall(
            GetAlchemyResultingItemLink,
            solventBag, solventSlot,
            reagent1.bag, reagent1.slot,
            reagent2.bag, reagent2.slot,
            reagent3.bag, reagent3.slot,
            LINK_STYLE_DEFAULT
        )
    else
        ok, resultLink, prospectiveResult = pcall(
            GetAlchemyResultingItemLink,
            solventBag, solventSlot,
            reagent1.bag, reagent1.slot,
            reagent2.bag, reagent2.slot,
            nil, nil,
            LINK_STYLE_DEFAULT
        )
    end

    if not ok then
        return nil, nil
    end

    return resultLink, prospectiveResult
end

function AW:RefreshRecipeResultFromSlots(recipe, solventBag, solventSlot, reagentSlots)
    if not recipe then return false end

    local currentApiVersion = GetAPIVersion and GetAPIVersion() or UPDATE_51_API_VERSION
    local resultLink, prospectiveResult = self:GetRecipeResultFromCurrentAlchemyAPI(
        solventBag, solventSlot, reagentSlots
    )

    if prospectiveResult == PROSPECTIVE_ALCHEMY_RESULT_UNCRAFTABLE then
        recipe.currentApiUncraftable = true
        recipe.validatedApiVersion = currentApiVersion
        return false
    end

    if not resultLink or resultLink == "" then
        return false
    end

    local resultType = GetItemLinkItemType(resultLink)
    if resultType ~= ITEMTYPE_POTION and resultType ~= ITEMTYPE_POISON then
        return false
    end

    local changed = recipe.resultLink ~= resultLink
        or recipe.resultType ~= resultType
        or recipe.resultName ~= itemNameFromLink(resultLink)

    recipe.resultLink = resultLink
    recipe.resultName = itemNameFromLink(resultLink)
    recipe.resultType = resultType
    recipe.minLevelText, recipe.minLevelValue = self:GetRequiredLevelData(resultLink)
    recipe.currentApiUncraftable = false
    recipe.validatedApiVersion = currentApiVersion

    if changed then
        recipe.updatedAt = GetTimeStamp()
    end

    return changed
end

function AW:ValidateRecipeForCurrentAPI(recipe)
    if not recipe or not recipe.solvent or not recipe.reagents then
        return false
    end

    local currentApiVersion = GetAPIVersion and GetAPIVersion() or UPDATE_51_API_VERSION
    if recipe.validatedApiVersion == currentApiVersion then
        return false
    end

    local solventBag, solventSlot = self:FindItem(recipe.solvent.itemId)
    if not solventBag then
        return false
    end

    local reagentSlots = {}
    for _, reagent in ipairs(recipe.reagents) do
        local bag, slot = self:FindItem(reagent.itemId)
        if not bag then
            return false
        end
        reagentSlots[#reagentSlots + 1] = { bag = bag, slot = slot }
    end

    return self:RefreshRecipeResultFromSlots(recipe, solventBag, solventSlot, reagentSlots)
end

function AW:ValidateKnownRecipesForCurrentAPI()
    if not self.sv or not self.sv.recipes then return false end

    local changed = false
    for _, recipe in pairs(self.sv.recipes) do
        if self:ValidateRecipeForCurrentAPI(recipe) then
            changed = true
        end
    end
    return changed
end

function AW:LoadRecipeIntoESO(recipe)
    if GetCraftingInteractionType() ~= CRAFTING_TYPE_ALCHEMY then
        warningChat(S(SI_AW_ONLY_STATION))
        return
    end

    if IsAwaitingCraftingProcessResponse and IsAwaitingCraftingProcessResponse() then
        warningChat(S(SI_AW_BUSY))
        return
    end

    local alchemy = _G.ALCHEMY
    if not alchemy or not alchemy.AddItemToCraft or not alchemy.SetSolventItem or not alchemy.SetReagentItem then
        warningChat(S(SI_AW_UI_UNAVAILABLE))
        return
    end

    if #recipe.reagents >= 3 and ZO_Alchemy_IsThirdAlchemySlotUnlocked and not ZO_Alchemy_IsThirdAlchemySlotUnlocked() then
        warningChat(S(SI_AW_THIRD_SLOT_LOCKED))
        return
    end

    local solventBag, solventSlot = self:FindItem(recipe.solvent.itemId)
    local reagentSlots = {}
    local missing = {}

    if not solventBag then
        missing[#missing + 1] = recipe.solvent.name or S(SI_AW_UNKNOWN)
    end

    for _, reagent in ipairs(recipe.reagents) do
        local bag, slot = self:FindItem(reagent.itemId)
        if not bag then
            missing[#missing + 1] = reagent.name or S(SI_AW_UNKNOWN)
        else
            reagentSlots[#reagentSlots + 1] = { bag = bag, slot = slot }
        end
    end

    if #missing > 0 then
        warningChat(S(SI_AW_MISSING, table.concat(missing, ", ")))
        return
    end

    -- Update 51 changed several reagent traits and some resulting potion/poison
    -- combinations. Re-resolve the result through ESO's current API before
    -- inserting a learned combination, so saved pre-U51 result metadata cannot
    -- misidentify what the same ingredients now produce.
    self:RefreshRecipeResultFromSlots(recipe, solventBag, solventSlot, reagentSlots)

    if recipe.currentApiUncraftable then
        warningChat(S(SI_AW_UNCRAFTABLE))
        return
    end

    alchemy:SetSolventItem(nil)
    if alchemy.reagentSlots then
        for i = 1, #alchemy.reagentSlots do
            alchemy:SetReagentItem(i, nil)
        end
    end

    alchemy:AddItemToCraft(solventBag, solventSlot)
    for _, item in ipairs(reagentSlots) do
        alchemy:AddItemToCraft(item.bag, item.slot)
    end

    -- ESO owns the crafting preview. Refresh it after we only inserted the materials.
    if alchemy.UpdateTooltip then
        alchemy:UpdateTooltip()
    end
    zo_callLater(function()
        if self.window and not self.window:IsHidden() then
            self:PositionAlchemyResultTooltip()
        end
    end, 0)

    infoChat(S(SI_AW_INSERTED, recipe.resultLink or recipe.resultName or S(SI_AW_UNKNOWN)))

    if self.sv.settings.closeAfterInsert then
        self:HideWindow()
    else
        self:RefreshList()
    end
end

function AW:CraftRecipe(recipe)
    self:LoadRecipeIntoESO(recipe)
end

function AW:GetRecipeTypeText(recipe)
    if recipe.resultType == ITEMTYPE_POISON then return S(SI_AW_POISON) end
    return S(SI_AW_POTION)
end

function AW:GetReagentsText(recipe)
    local reagents = recipe.reagents or {}
    if #reagents >= 3 then
        return S(SI_AW_INGREDIENTS_3,
            reagents[1].name or S(SI_AW_UNKNOWN),
            reagents[2].name or S(SI_AW_UNKNOWN),
            reagents[3].name or S(SI_AW_UNKNOWN))
    end
    return S(SI_AW_INGREDIENTS_2,
        reagents[1] and reagents[1].name or S(SI_AW_UNKNOWN),
        reagents[2] and reagents[2].name or S(SI_AW_UNKNOWN))
end

function AW:GetIngredientsText(recipe)
    return S(SI_AW_SOLVENT_FORMAT,
        recipe.solvent and recipe.solvent.name or S(SI_AW_UNKNOWN),
        self:GetReagentsText(recipe))
end

function AW:EnsureRecipeData(recipe)
    -- Legacy recipes were only stored after at least one successful craft.
    -- Their exact historic count cannot be reconstructed, so preserve the
    -- known minimum of one instead of displaying zero.
    if recipe.craftedCount == nil then
        recipe.craftedCount = 1
    else
        recipe.craftedCount = tonumber(recipe.craftedCount) or 0
    end
    if not recipe.resultName or recipe.resultName == "" then
        recipe.resultName = itemNameFromLink(recipe.resultLink)
    end
    if not recipe.minLevelValue or not recipe.minLevelText then
        recipe.minLevelText, recipe.minLevelValue = self:GetRequiredLevelData(recipe.resultLink or "")
    end
end

function AW:GetResultGroupKey(recipe)
    -- The complete result link is deliberately used here. Two recipes are only
    -- grouped when ESO says their actual crafted result is identical, not merely
    -- because the displayed name happens to be the same.
    if recipe.resultLink and recipe.resultLink ~= "" then
        return recipe.resultLink
    end
    return string.format("%s|%s|%s", tostring(recipe.resultType or 0), normalizeText(recipe.resultName or ""), tostring(recipe.minLevelValue or 0))
end

function AW:BuildResultGroups()
    local groupsByKey = {}
    local groups = {}

    for _, recipe in pairs(self.sv.recipes) do
        self:EnsureRecipeData(recipe)
        local key = self:GetResultGroupKey(recipe)
        local group = groupsByKey[key]
        if not group then
            group = {
                key = key,
                resultLink = recipe.resultLink,
                resultName = recipe.resultName,
                resultType = recipe.resultType,
                minLevelText = recipe.minLevelText,
                minLevelValue = recipe.minLevelValue,
                recipes = {},
                craftedCount = 0,
            }
            groupsByKey[key] = group
            groups[#groups + 1] = group
        end
        group.recipes[#group.recipes + 1] = recipe
        group.craftedCount = group.craftedCount + (tonumber(recipe.craftedCount) or 0)
    end

    for _, group in ipairs(groups) do
        table.sort(group.recipes, function(a, b)
            return normalizeText(self:GetIngredientsText(a)) < normalizeText(self:GetIngredientsText(b))
        end)
    end

    return groups
end

function AW:GetCategoryCounts()
    local counts = { all = 0, potion = 0, poison = 0 }
    for _, group in ipairs(self:BuildResultGroups()) do
        counts.all = counts.all + 1
        if group.resultType == ITEMTYPE_POISON then
            counts.poison = counts.poison + 1
        else
            counts.potion = counts.potion + 1
        end
    end
    return counts
end

function AW:IsRecipeAvailable(recipe)
    return recipe
        and recipe.currentApiUncraftable ~= true
        and #self:GetMissingItems(recipe) == 0
end

function AW:IsGroupAvailable(group)
    for _, recipe in ipairs(group.recipes or {}) do
        if self:IsRecipeAvailable(recipe) then return true end
    end
    return false
end

function AW:IsGroupUncraftable(group)
    local recipes = group and group.recipes or nil
    if not recipes or #recipes == 0 then return false end

    for _, recipe in ipairs(recipes) do
        if recipe.currentApiUncraftable ~= true then
            return false
        end
    end
    return true
end

function AW:GetGroupSortValue(group, column)
    if column == "level" then
        return tonumber(group.minLevelValue) or 0
    elseif column == "ingredients" then
        if #(group.recipes or {}) > 1 then
            return normalizeText(S(SI_AW_COMBINATIONS, #group.recipes))
        end
        return normalizeText(self:GetIngredientsText(group.recipes[1]))
    elseif column == "crafted" then
        return tonumber(group.craftedCount) or 0
    elseif column == "material" then
        return self:IsGroupAvailable(group) and 0 or 1
    end
    return normalizeText(group.resultName or "")
end

function AW:GetFilteredGroups()
    local groups = {}
    for _, group in ipairs(self:BuildResultGroups()) do
        local typeOk = self.filter == "all"
            or (self.filter == "potion" and group.resultType == ITEMTYPE_POTION)
            or (self.filter == "poison" and group.resultType == ITEMTYPE_POISON)
        if typeOk then
            groups[#groups + 1] = group
        end
    end

    local column = self.sortColumn or "name"
    local ascending = self.sortAscending ~= false
    table.sort(groups, function(a, b)
        local av = self:GetGroupSortValue(a, column)
        local bv = self:GetGroupSortValue(b, column)
        if av == bv then
            local an = normalizeText(a.resultName or "")
            local bn = normalizeText(b.resultName or "")
            if an == bn then return tostring(a.key) < tostring(b.key) end
            return an < bn
        end
        if ascending then return av < bv end
        return av > bv
    end)
    return groups
end

function AW:GetFilteredRecipes()
    -- Kept under the old function name so pagination and the surrounding UI do
    -- not need a second data path. It now returns visible display entries.
    local entries = {}
    for _, group in ipairs(self:GetFilteredGroups()) do
        if #group.recipes == 1 then
            entries[#entries + 1] = {
                entryType = "single",
                group = group,
                recipe = group.recipes[1],
            }
        else
            local expanded = self.expandedGroups[group.key] == true
            entries[#entries + 1] = {
                entryType = "group",
                group = group,
                recipe = group.recipes[1],
                expanded = expanded,
            }
            if expanded then
                for index, recipe in ipairs(group.recipes) do
                    entries[#entries + 1] = {
                        entryType = "variant",
                        group = group,
                        recipe = recipe,
                        variantIndex = index,
                    }
                end
            end
        end
    end
    return entries
end

function AW:ToggleResultGroup(groupKey)
    self.expandedGroups[groupKey] = not (self.expandedGroups[groupKey] == true)
    self:RefreshList()
end

function AW:SetFilter(filter)
    self.filter = filter
    if self.recipeScroll and ZO_Scroll_ResetToTop then
        ZO_Scroll_ResetToTop(self.recipeScroll)
    end
    self:RefreshList()
end

function AW:ResetSortToDefault()
    self.sortColumn = self.sv.settings.defaultSortColumn or "name"
    self.sortAscending = self.sv.settings.defaultSortAscending ~= false
end

function AW:SetTemporarySort(column)
    if self.sortColumn == column then
        self.sortAscending = not self.sortAscending
    else
        self.sortColumn = column
        self.sortAscending = true
    end
    if self.recipeScroll and ZO_Scroll_ResetToTop then
        ZO_Scroll_ResetToTop(self.recipeScroll)
    end
    self:RefreshList()
end

function AW:UpdateHeaderColors()
    if not self.headers then return end

    for key, button in pairs(self.headers) do
        local label = button.alchemiewerkLabel
        if label then
            if key == self.sortColumn then
                label:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
            else
                label:SetColor(0.85, 0.85, 0.85, 1)
            end
        end
    end
end

function AW:IsWindowLocked()
    return self.sv and self.sv.window and self.sv.window.locked == true
end

function AW:UpdateWindowPin()
    if not self.pinButton or not self.pinTexture then return end

    if self:IsWindowLocked() then
        self.pinTexture:SetColor(BLUE_R, BLUE_G, BLUE_B, 1)
    else
        self.pinTexture:SetColor(0.82, 0.76, 0.52, 0.88)
    end
end

function AW:SetWindowLocked(locked)
    self.sv.window.locked = locked == true

    if self.window then
        -- Keep the top-level window non-movable by default. It is made movable
        -- only for the duration of an explicit left-button drag.
        self.window:SetMovable(false)
    end

    self.windowMoveActive = false
    self:UpdateWindowPin()
end

function AW:ToggleWindowLocked()
    self:SetWindowLocked(not self:IsWindowLocked())
end

function AW:ResetWindowPosition()
    if not self.sv or not self.sv.window then return end

    self.sv.window.x = nil
    self.sv.window.y = nil

    if self.window then
        self.window:StopMovingOrResizing()
        self.window:SetMovable(false)
        self.windowMoveActive = false
        self.window:ClearAnchors()
        self.window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        self:ApplyResponsiveLayout(false)
        self:SaveWindowPosition()
        self:PositionAlchemyResultTooltip()

        if self.recipeTooltipRecipe then
            self:ShowRecipeTooltip(self.recipeTooltipRecipe)
        end
    end
end

function AW:ShowPinTooltip()
    if not self.pinButton or not InformationTooltip then return end

    InitializeTooltip(InformationTooltip, self.pinButton, BOTTOM, 0, -4, TOP)
    InformationTooltip:AddLine(
        self:IsWindowLocked() and S(SI_AW_WINDOW_UNLOCK) or S(SI_AW_WINDOW_LOCK),
        "ZoFontGame"
    )
end

function AW:CreateUI()
    if self.window then return end

    local wm = WINDOW_MANAGER
    local win = wm:CreateTopLevelWindow("AlchemiewerkWindow")
    self.window = win

    win:SetDimensions(IDEAL_WINDOW_WIDTH, IDEAL_WINDOW_HEIGHT)
    win:SetMouseEnabled(true)
    win:SetMovable(false)
    win:SetClampedToScreen(true)
    win:SetHidden(true)

    self:RestoreWindowPosition()

    -- Movement is intentionally restricted to the left mouse button.
    -- The window itself remains non-movable at all other times, so a right
    -- click can never start or continue a drag.
    win:SetHandler("OnMouseDown", function(control, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if self:IsWindowLocked() then return end

        -- Interactive title-bar controls must keep their click and must never
        -- turn into a window drag.
        if self.pinButton and MouseIsOver(self.pinButton) then return end
        if self.closeButton and MouseIsOver(self.closeButton) then return end

        self.windowMoveActive = true
        control:SetMovable(true)
        control:StartMoving()
    end)

    win:SetHandler("OnMouseUp", function(control, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if not self.windowMoveActive then return end

        self.windowMoveActive = false
        control:StopMovingOrResizing()
        control:SetMovable(false)
        self:SaveWindowPosition()
        self:PositionAlchemyResultTooltip()

        if self.recipeTooltipRecipe then
            self:ShowRecipeTooltip(self.recipeTooltipRecipe)
        end
    end)
    win:SetHandler("OnShow", function()
        self:ApplyResponsiveLayout(false)
        self:PositionAlchemyResultTooltip()
    end)
    win:SetHandler("OnHide", function()
        self.hoveredRow = nil
        self:HideRecipeTooltip()
        self:RestoreAlchemyResultTooltip()
    end)

    local backdrop = wm:CreateControlFromVirtual("AlchemiewerkBackdrop", win, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(win)
    if backdrop.SetEdgeColor then
        backdrop:SetEdgeColor(BLUE_R, BLUE_G, BLUE_B, 1)
    end
    self.windowFrame = self:AddBlueFrame(win, "AlchemiewerkWindowFrame", 2)

    local title = wm:CreateControl("AlchemiewerkTitle", win, CT_LABEL)
    title:SetFont("ZoFontWinH1")
    title:SetText("|c7FC7FF" .. S(SI_AW_TITLE) .. "|r")
    title:SetAnchor(TOPLEFT, win, TOPLEFT, 20, 15)

    self.closeButton = wm:CreateControlFromVirtual("AlchemiewerkCloseButton", win, "ZO_DefaultButton")
    self.closeButton:SetDimensions(100, 30)
    self.closeButton:SetAnchor(TOPRIGHT, win, TOPRIGHT, -16, 16)
    self.closeButton:SetText(S(SI_AW_CLOSE))
    self.closeButton:SetHandler("OnClicked", function()
        self:HideWindow()
    end)

    -- Use a real button as the click target. The previous CT_TEXTURE could be
    -- visually hovered but its click was swallowed by the movable parent window.
    self.pinButton = wm:CreateControl("AlchemiewerkPinButton", win, CT_BUTTON)
    self.pinButton:SetDimensions(32, 30)
    self.pinButton:SetAnchor(RIGHT, self.closeButton, LEFT, -6, 0)

    self.pinTexture = wm:CreateControl("AlchemiewerkPinTexture", self.pinButton, CT_TEXTURE)
    self.pinTexture:SetDimensions(20, 20)
    self.pinTexture:SetTexture(PIN_TEXTURE)
    self.pinTexture:SetAnchor(CENTER, self.pinButton, CENTER, 0, 0)
    self.pinTexture:SetMouseEnabled(false)

    self.pinButton:SetHandler("OnClicked", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            self:ToggleWindowLocked()
        end
    end)
    self.pinButton:SetHandler("OnMouseEnter", function()
        if self.pinTexture then
            self.pinTexture:SetAlpha(1)
        end
        self:ShowPinTooltip()
    end)
    self.pinButton:SetHandler("OnMouseExit", function()
        if self.pinTexture then
            self.pinTexture:SetAlpha(0.88)
        end
        ClearTooltip(InformationTooltip)
    end)
    self.pinTexture:SetAlpha(0.88)
    self:UpdateWindowPin()

    self.categoryButtons = {}
    local categoryOrder = { "all", "potion", "poison" }
    for _, key in ipairs(categoryOrder) do
        local button = wm:CreateControlFromVirtual("AlchemiewerkCategory_" .. key, win, "ZO_DefaultButton")
        button:SetDimensions(300, 30)
        button:SetHandler("OnClicked", function()
            self:SetFilter(key)
        end)
        self.categoryButtons[key] = button
    end

    self.columnHeader = wm:CreateControl("AlchemiewerkColumnHeader", win, CT_CONTROL)
    self.columnHeader:SetDimensions(940, 28)
    self.columnHeader:SetAnchor(TOPLEFT, win, TOPLEFT, 20, 98)

    self.headers = {}

    local function HeaderButton(key, sortColumn, textValue, align)
        local label = wm:CreateControl(nil, self.columnHeader, CT_LABEL)
        label:SetFont("ZoFontGame")
        label:SetDimensions(100, 26)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
        label:SetText(textValue)
        label:SetMouseEnabled(false)

        local button = wm:CreateControl(nil, self.columnHeader, CT_BUTTON)
        button:SetDimensions(100, 26)
        button:SetHandler("OnClicked", function()
            self:SetTemporarySort(sortColumn)
        end)
        button.alchemiewerkLabel = label
        self.headers[key] = button
        return button
    end

    self.resultHeader = HeaderButton("name", "name", S(SI_AW_COLUMN_RESULT), TEXT_ALIGN_LEFT)
    self.levelHeader = HeaderButton("level", "level", S(SI_AW_COLUMN_MIN_LEVEL), TEXT_ALIGN_CENTER)
    self.ingredientsHeader = HeaderButton("ingredients", "ingredients", S(SI_AW_COLUMN_INGREDIENTS), TEXT_ALIGN_LEFT)
    self.craftedHeader = HeaderButton("crafted", "crafted", S(SI_AW_COLUMN_CRAFTED), TEXT_ALIGN_CENTER)
    self.materialHeader = HeaderButton("material", "material", S(SI_AW_COLUMN_MATERIAL), TEXT_ALIGN_CENTER)

    self.emptyLabel = wm:CreateControl("AlchemiewerkEmpty", win, CT_LABEL)
    self.emptyLabel:SetFont("ZoFontGame")
    self.emptyLabel:SetDimensions(900, 80)
    self.emptyLabel:SetAnchor(CENTER, win, CENTER, 0, -10)
    self.emptyLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.emptyLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.emptyLabel:SetColor(0.85, 0.85, 0.85, 1)
    self.emptyLabel:SetHidden(true)

    self.recipeScroll = wm:CreateControlFromVirtual("AlchemiewerkRecipeScroll", win, "ZO_ScrollContainer")
    self.recipeScroll:SetAnchor(TOPLEFT, win, TOPLEFT, 20, 132)
    self.recipeScroll:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -20, -20)
    ZO_Scroll_Initialize(self.recipeScroll)

    self.recipeScrollChild = self.recipeScroll:GetNamedChild("ScrollChild")
    if self.recipeScrollChild then
        self.recipeScrollChild:SetResizeToFitDescendents(false)
    end

    self.rows = {}

    self:ApplyResponsiveLayout(true)
end

function AW:ApplyResponsiveLayout(initial)
    if not self.window then return end

    local screenWidth, screenHeight = GuiRoot:GetDimensions()
    local availableWidth = math.max(1, screenWidth - (WINDOW_MARGIN * 2))
    local availableHeight = math.max(1, screenHeight - (WINDOW_MARGIN * 2))
    local width = math.min(IDEAL_WINDOW_WIDTH, availableWidth)
    local height = math.min(IDEAL_WINDOW_HEIGHT, availableHeight)

    self.window:SetDimensions(width, height)
    local contentWidth = math.max(1, width - 40)

    if self.recipeScroll then
        self.recipeScroll:ClearAnchors()
        self.recipeScroll:SetAnchor(TOPLEFT, self.window, TOPLEFT, 20, 132)
        self.recipeScroll:SetAnchor(BOTTOMRIGHT, self.window, BOTTOMRIGHT, -20, -20)
    end

    local categoryGap = 10
    local categoryWidth = math.max(1, (contentWidth - (categoryGap * 2)) / 3)
    local order = { "all", "potion", "poison" }
    for index, key in ipairs(order) do
        local button = self.categoryButtons and self.categoryButtons[key]
        if button then
            button:ClearAnchors()
            button:SetDimensions(categoryWidth, 30)
            button:SetAnchor(TOPLEFT, self.window, TOPLEFT,
                20 + ((index - 1) * (categoryWidth + categoryGap)), 58)
        end
    end

    if self.emptyLabel then
        self.emptyLabel:SetDimensions(math.max(1, contentWidth - 40), 80)
    end

    self:LayoutRecipeRows()

    local left = self.window:GetLeft()
    local top = self.window:GetTop()
    if left == nil then left = (screenWidth - width) / 2 end
    if top == nil then top = (screenHeight - height) / 2 end

    left = zo_clamp(left or 0, 0, math.max(0, screenWidth - width))
    top = zo_clamp(top or 0, 0, math.max(0, screenHeight - height))
    self.window:ClearAnchors()
    self.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)

    if self.sv and self.sv.window then
        self.sv.window.x = zo_round(left)
        self.sv.window.y = zo_round(top)
    end

    if not initial then
        self:RefreshList()
    end
end

function AW:GetColumnLayout(rowWidth)
    local scale = math.min(1, math.max(0.45, rowWidth / 940))
    local gap = math.max(4, 8 * scale)
    local actionWidth = math.max(64, 104 * scale)
    local materialWidth = math.max(70, 106 * scale)
    local craftedWidth = math.max(60, 82 * scale)
    local levelWidth = math.max(60, 78 * scale)
    local ingredientsWidth = math.max(95, 188 * scale)

    local fixedWidth = levelWidth + ingredientsWidth + craftedWidth + materialWidth + actionWidth + (gap * 5)
    local nameWidth = math.max(100, rowWidth - fixedWidth)

    local overflow = (nameWidth + fixedWidth) - rowWidth
    if overflow > 0 then
        local reducibleIngredients = math.max(0, ingredientsWidth - 72)
        local reduce = math.min(overflow, reducibleIngredients)
        ingredientsWidth = ingredientsWidth - reduce
        overflow = overflow - reduce
    end
    if overflow > 0 then
        nameWidth = math.max(70, nameWidth - overflow)
    end

    local xName = 4
    local xLevel = xName + nameWidth + gap
    local xIngredients = xLevel + levelWidth + gap
    local xCrafted = xIngredients + ingredientsWidth + gap
    local xMaterial = xCrafted + craftedWidth + gap

    return {
        name = { x = xName, width = nameWidth },
        level = { x = xLevel, width = levelWidth },
        ingredients = { x = xIngredients, width = ingredientsWidth },
        crafted = { x = xCrafted, width = craftedWidth },
        material = { x = xMaterial, width = materialWidth },
        action = { width = actionWidth },
    }
end

function AW:CreateRow(parent, index)
    local wm = WINDOW_MANAGER
    local row = wm:CreateControl("AlchemiewerkRow" .. index, parent, CT_CONTROL)
    row:SetDimensions(940, ROW_HEIGHT)

    if index == 1 then
        row:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    else
        row:SetAnchor(TOPLEFT, self.rows[index - 1], BOTTOMLEFT, 0, ROW_SPACING)
    end

    row.name = wm:CreateControl(nil, row, CT_LABEL)
    row.name:SetFont("ZoFontGame")
    row.name:SetDimensions(340, 36)
    row.name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.name:SetMouseEnabled(true)
    row.name:SetHandler("OnMouseEnter", function(control)
        self.hoveredRow = row
        self:ShowRecipeTooltip(control.recipe)
    end)
    row.name:SetHandler("OnMouseExit", function()
        if self.hoveredRow == row then self.hoveredRow = nil end
        self:HideRecipeTooltip()
    end)

    row.level = wm:CreateControl(nil, row, CT_LABEL)
    row.level:SetFont("ZoFontGameSmall")
    row.level:SetDimensions(78, 36)
    row.level:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.level:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    row.ingredients = wm:CreateControl(nil, row, CT_LABEL)
    row.ingredients:SetFont("ZoFontGameSmall")
    row.ingredients:SetDimensions(188, 36)
    row.ingredients:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.ingredients:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    row.crafted = wm:CreateControl(nil, row, CT_LABEL)
    row.crafted:SetFont("ZoFontGameSmall")
    row.crafted:SetDimensions(82, 36)
    row.crafted:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.crafted:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    row.material = wm:CreateControl(nil, row, CT_LABEL)
    row.material:SetFont("ZoFontGameSmall")
    row.material:SetDimensions(106, 36)
    row.material:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.material:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    row.insert = wm:CreateControlFromVirtual("AlchemiewerkRowInsert" .. index, row, "ZO_DefaultButton")
    row.insert:SetDimensions(104, 30)
    row.insert:SetText(S(SI_AW_INSERT))

    return row
end

function AW:EnsureRowCount(count)
    if not self.rows or not self.recipeScrollChild then return end
    for index = #self.rows + 1, count do
        self.rows[index] = self:CreateRow(self.recipeScrollChild, index)
    end
end

function AW:LayoutRecipeRows()
    if not self.window or not self.recipeScroll or not self.recipeScrollChild then return end

    local windowWidth = self.window:GetWidth() or IDEAL_WINDOW_WIDTH
    local contentWidth = math.max(1, windowWidth - 40)
    local scrollBarWidth = (ZO_SCROLL_BAR_WIDTH or 18) + 6
    local rowWidth = math.max(1, contentWidth - scrollBarWidth)
    local columns = self:GetColumnLayout(rowWidth)

    self.columnWidths = {
        name = columns.name.width,
        level = columns.level.width,
        ingredients = columns.ingredients.width,
        crafted = columns.crafted.width,
        material = columns.material.width,
        action = columns.action.width,
    }

    if self.columnHeader then
        self.columnHeader:SetDimensions(rowWidth, 28)
    end

    if self.headers then
        for key, button in pairs(self.headers) do
            local layout = columns[key]
            if layout then
                button:ClearAnchors()
                button:SetAnchor(LEFT, self.columnHeader, LEFT, layout.x, 0)
                button:SetDimensions(layout.width, 26)
                if button.alchemiewerkLabel then
                    button.alchemiewerkLabel:ClearAnchors()
                    button.alchemiewerkLabel:SetAnchor(LEFT, self.columnHeader, LEFT, layout.x, 0)
                    button.alchemiewerkLabel:SetDimensions(layout.width, 26)
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

        local nameIndent = row.isVariant and 34 or 0
        row.name:ClearAnchors()
        row.name:SetAnchor(LEFT, row, LEFT, columns.name.x + nameIndent, 0)
        row.name:SetDimensions(math.max(40, columns.name.width - nameIndent), 36)

        row.level:ClearAnchors()
        row.level:SetAnchor(LEFT, row, LEFT, columns.level.x, 0)
        row.level:SetDimensions(columns.level.width, 36)

        row.ingredients:ClearAnchors()
        row.ingredients:SetAnchor(LEFT, row, LEFT, columns.ingredients.x, 0)
        row.ingredients:SetDimensions(columns.ingredients.width, 36)

        row.crafted:ClearAnchors()
        row.crafted:SetAnchor(LEFT, row, LEFT, columns.crafted.x, 0)
        row.crafted:SetDimensions(columns.crafted.width, 36)

        row.material:ClearAnchors()
        row.material:SetAnchor(LEFT, row, LEFT, columns.material.x, 0)
        row.material:SetDimensions(columns.material.width, 36)

        row.insert:SetDimensions(columns.action.width, 30)
        row.insert:ClearAnchors()
        row.insert:SetAnchor(RIGHT, row, RIGHT, -2, 0)
    end

    local count = 0
    for _, row in ipairs(self.rows or {}) do
        if not row:IsHidden() then count = count + 1 end
    end

    local contentHeight = count > 0 and ((count * ROW_HEIGHT) + ((count - 1) * ROW_SPACING)) or 1
    local viewportHeight = self.recipeScroll:GetHeight() or 1
    self.recipeScrollChild:SetDimensions(rowWidth, math.max(viewportHeight, contentHeight))
end

function AW:SaveWindowPosition()
    if not self.window or self.window:IsHidden() then return end
    local left, top = self.window:GetLeft(), self.window:GetTop()
    if left and top then
        self.sv.window.x = zo_round(left)
        self.sv.window.y = zo_round(top)
    end
end

function AW:RestoreWindowPosition()
    if not self.window then return end
    local x = self.sv and self.sv.window and self.sv.window.x
    local y = self.sv and self.sv.window and self.sv.window.y
    self.window:ClearAnchors()
    if type(x) == "number" and type(y) == "number" then
        self.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
        self:ClampWindowPosition(false)
    else
        self.window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
end

function AW:ClampWindowPosition(save)
    if not self.window then return end
    local rootW, rootH = GuiRoot:GetDimensions()
    local winW, winH = self.window:GetDimensions()
    local left = self.window:GetLeft() or 0
    local top = self.window:GetTop() or 0
    local x = zo_clamp(left, 0, math.max(0, rootW - winW))
    local y = zo_clamp(top, 0, math.max(0, rootH - winH))
    self.window:ClearAnchors()
    self.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    if save and self.sv and self.sv.window then
        self.sv.window.x = zo_round(x)
        self.sv.window.y = zo_round(y)
    end
end

function AW:CaptureControlAnchors(control)
    if not control or not control.GetNumAnchors or not control.GetAnchor then return nil end
    local anchors = {}
    local count = control:GetNumAnchors() or 0
    for index = 0, count - 1 do
        local isValid, point, relativeTo, relativePoint, offsetX, offsetY = control:GetAnchor(index)
        if isValid then
            anchors[#anchors + 1] = {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                offsetX = offsetX,
                offsetY = offsetY,
            }
        end
    end
    return anchors
end

function AW:RestoreControlAnchors(control, anchors)
    if not control or not anchors then return end
    control:ClearAnchors()
    for _, anchor in ipairs(anchors) do
        control:SetAnchor(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.offsetX, anchor.offsetY)
    end
end

function AW:GetCurrentAlchemyFormula()
    local alchemy = _G.ALCHEMY
    if not alchemy or not alchemy.GetAllCraftingBagAndSlots then
        return nil, nil
    end

    local solventBagId, solventSlotIndex,
          reagent1BagId, reagent1SlotIndex,
          reagent2BagId, reagent2SlotIndex,
          reagent3BagId, reagent3SlotIndex = alchemy:GetAllCraftingBagAndSlots()

    if solventBagId == nil or solventSlotIndex == nil
        or reagent1BagId == nil or reagent1SlotIndex == nil
        or reagent2BagId == nil or reagent2SlotIndex == nil then
        return nil, nil
    end

    local solventId = GetItemId(solventBagId, solventSlotIndex)
    if not solventId or solventId == 0 then
        return nil, nil
    end

    local reagents = {}

    local reagent1Id = GetItemId(reagent1BagId, reagent1SlotIndex)
    local reagent2Id = GetItemId(reagent2BagId, reagent2SlotIndex)
    if not reagent1Id or reagent1Id == 0 or not reagent2Id or reagent2Id == 0 then
        return nil, nil
    end

    reagents[#reagents + 1] = { itemId = reagent1Id }
    reagents[#reagents + 1] = { itemId = reagent2Id }

    if reagent3BagId ~= nil and reagent3SlotIndex ~= nil then
        local reagent3Id = GetItemId(reagent3BagId, reagent3SlotIndex)
        if reagent3Id and reagent3Id ~= 0 then
            reagents[#reagents + 1] = { itemId = reagent3Id }
        end
    end

    return self:MakeFormulaKey(solventId, reagents), reagents
end

function AW:AppendCombinationStatusToAlchemyTooltip()
    if not self.atAlchemyStation or not self.sv or not self.sv.recipes then
        return
    end

    local tooltip = self:GetAlchemyResultTooltip()
    if not tooltip or not tooltip.AddLine then
        return
    end

    local formulaKey = self:GetCurrentAlchemyFormula()
    if not formulaKey then
        return
    end

    local recipe = self.sv.recipes[formulaKey]
    local textLine

    if recipe then
        local craftedCount = tonumber(recipe.craftedCount) or 0
        textLine = string.format(
            "|c7FC7FF%s|r: |c66CC66%s|r · %s",
            S(SI_AW_TITLE),
            S(SI_AW_TOOLTIP_KNOWN),
            S(SI_AW_TOOLTIP_CRAFTED, craftedCount)
        )
    else
        textLine = string.format(
            "|c7FC7FF%s|r: |c7FC7FF%s|r",
            S(SI_AW_TITLE),
            S(SI_AW_TOOLTIP_UNKNOWN)
        )
    end

    tooltip:AddLine(
        textLine,
        "ZoFontGame",
        1, 1, 1,
        TOP,
        MODIFY_TEXT_TYPE_NONE,
        TEXT_ALIGN_CENTER,
        true
    )
end

function AW:InitializeCombinationTooltipHook()
    if self.combinationTooltipHooked then
        return true
    end

    local alchemy = _G.ALCHEMY
    if not alchemy or type(alchemy.UpdateTooltip) ~= "function" then
        return false
    end

    SecurePostHook(alchemy, "UpdateTooltip", function()
        self:AppendCombinationStatusToAlchemyTooltip()
    end)

    self.combinationTooltipHooked = true
    return true
end

function AW:TryInitializeCombinationTooltipHook(attempt)
    attempt = attempt or 1
    if self:InitializeCombinationTooltipHook() then
        return
    end
    if attempt < 12 then
        zo_callLater(function()
            self:TryInitializeCombinationTooltipHook(attempt + 1)
        end, 100)
    end
end

function AW:HideRecipeTooltip()
    self.recipeTooltipRecipe = nil
    if PopupTooltip then
        ClearTooltip(PopupTooltip)
        PopupTooltip:SetHidden(true)
    end
end

function AW:ShowRecipeTooltip(recipe)
    if not PopupTooltip or not self.window or not recipe or not recipe.resultLink or recipe.resultLink == "" then
        return
    end

    -- Same proven tooltip path as Runenwerk: use PopupTooltip instead of
    -- ItemTooltip so ESO's own alchemy result tooltip remains independent.
    self.recipeTooltipRecipe = recipe
    ClearTooltip(PopupTooltip)
    InitializeTooltip(PopupTooltip, self.window, TOPRIGHT, -12, 0, TOPLEFT)
    PopupTooltip:SetLink(recipe.resultLink)

    -- SetLink may rebuild the tooltip and touch its anchors. Force the final
    -- position afterwards. Prefer the left side, fall back to the right.
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

function AW:GetAlchemyResultTooltip()
    if ALCHEMY and ALCHEMY.resultTooltip then
        return ALCHEMY.resultTooltip
    end
    if ALCHEMY and ALCHEMY.tooltip then
        return ALCHEMY.tooltip
    end
    local root = _G["ZO_AlchemyTopLevel"]
    return root and root.GetNamedChild and root:GetNamedChild("Tooltip") or nil
end

function AW:CaptureAlchemyResultTooltipAnchor()
    if self.esoResultTooltipOriginalAnchor then
        return
    end
    local tooltip = self:GetAlchemyResultTooltip()
    if not tooltip or not tooltip.GetAnchor then
        return
    end
    local isValid, point, relativeTo, relativePoint, offsetX, offsetY = tooltip:GetAnchor(0)
    if isValid then
        self.esoResultTooltipOriginalAnchor = { point, relativeTo, relativePoint, offsetX or 0, offsetY or 0 }
    end
end

function AW:PositionAlchemyResultTooltip()
    if not self.window or self.window:IsHidden() or not self.atAlchemyStation then
        return
    end
    local tooltip = self:GetAlchemyResultTooltip()
    if not tooltip then
        return
    end

    self:CaptureAlchemyResultTooltipAnchor()
    tooltip:ClearAnchors()
    local tooltipWidth = tooltip:GetWidth() or 360
    local windowLeft = self.window:GetLeft() or 0
    if windowLeft >= tooltipWidth + 12 then
        tooltip:SetAnchor(BOTTOMRIGHT, self.window, BOTTOMLEFT, -12, 0)
    else
        tooltip:SetAnchor(BOTTOMLEFT, self.window, BOTTOMRIGHT, 12, 0)
    end
end

function AW:RestoreAlchemyResultTooltip()
    local tooltip = self:GetAlchemyResultTooltip()
    local anchor = self.esoResultTooltipOriginalAnchor
    if not tooltip or not anchor then
        return
    end
    tooltip:ClearAnchors()
    tooltip:SetAnchor(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
    self.esoResultTooltipOriginalAnchor = nil
end

function AW:RefreshCategoryButtons()
    if not self.categoryButtons then return end

    local counts = self:GetCategoryCounts()
    local labels = {
        all = S(SI_AW_CATEGORY_ALL),
        potion = S(SI_AW_CATEGORY_POTIONS),
        poison = S(SI_AW_CATEGORY_POISONS),
    }

    for key, button in pairs(self.categoryButtons) do
        local value = string.format("%s (%d)", labels[key] or key, counts[key] or 0)
        if self.filter == key then
            value = "|c7FC7FF" .. value .. "|r"
        end
        button:SetText(value)
    end
end

function AW:ApplyEntryHierarchy(row, isVariant)
    if not row then return end
    row.isVariant = isVariant == true
end

function AW:ScrollRows(delta)
    -- Native ZO_ScrollContainer handles mouse wheel and scrollbar movement.
end

function AW:UpdateScrollBar(totalEntries)
    -- Native ZO_ScrollContainer manages its own scrollbar.
end

function AW:RefreshList()
    if not self.window then return end

    -- Saved combinations from an older ESO API are lazily revalidated as soon
    -- as their ingredients are available. This preserves the learned database
    -- while adapting changed U51 potion/poison results to API 101051.
    self:ValidateKnownRecipesForCurrentAPI()

    local list = self:GetFilteredRecipes()
    local entryCount = #list

    self:EnsureRowCount(entryCount)

    self.emptyLabel:SetHidden(entryCount > 0)
    if entryCount == 0 then
        local anyRecipes = next(self.sv.recipes) ~= nil
        self.emptyLabel:SetText(anyRecipes and S(SI_AW_NO_MATCH) or S(SI_AW_EMPTY))
    end

    if self.recipeScroll then
        self.recipeScroll:SetHidden(entryCount == 0)
    end

    for rowIndex, row in ipairs(self.rows) do
        local entry = list[rowIndex]
        if entry then
            local recipe = entry.recipe
            local group = entry.group
            local isGroup = entry.entryType == "group"
            local isVariant = entry.entryType == "variant"
            local available

            row.entry = entry
            row.recipe = recipe
            row.isVariant = isVariant
            row:SetHidden(false)
            row.name.recipe = recipe
            row.name:SetFont("ZoFontGame")

            local resultName = (group and group.resultName)
                or recipe.resultName
                or itemNameFromLink(recipe.resultLink)

            if isGroup then
                local prefix = entry.expanded and "- " or "+ "
                if self.filter == "all" then
                    local typeText = group.resultType == ITEMTYPE_POISON and S(SI_AW_POISON) or S(SI_AW_POTION)
                    row.name:SetText(string.format("[%s] %s%s", typeText, prefix, resultName))
                else
                    row.name:SetText(prefix .. resultName)
                end
                row.level:SetText(group.minLevelText or S(SI_AW_LEVEL, 1))
                row.ingredients:SetText(S(SI_AW_COMBINATIONS, #group.recipes))
                row.crafted:SetText(string.format("%d×", group.craftedCount or 0))
                available = self:IsGroupAvailable(group)
                row.insert:SetText(entry.expanded and S(SI_AW_COLLAPSE) or S(SI_AW_SELECT))
                row.insert:SetEnabled(true)
                row.insert:SetHandler("OnClicked", function()
                    self:ToggleResultGroup(group.key)
                end)
            else
                if isVariant then
                    row.name:SetText(S(SI_AW_COMBINATION, entry.variantIndex or 1))
                else
                    if self.filter == "all" then
                        row.name:SetText(string.format("[%s] %s", self:GetRecipeTypeText(recipe), resultName))
                    else
                        row.name:SetText(resultName)
                    end
                end

                row.level:SetText(recipe.minLevelText or S(SI_AW_LEVEL, 1))
                row.ingredients:SetText(self:GetIngredientsText(recipe))
                row.crafted:SetText(string.format("%d×", recipe.craftedCount or 0))
                available = self:IsRecipeAvailable(recipe)
                row.insert:SetText(S(SI_AW_INSERT))
                row.insert:SetEnabled(available and self.atAlchemyStation)
                row.insert:SetHandler("OnClicked", function()
                    self:LoadRecipeIntoESO(recipe)
                end)
            end

            local link = (group and group.resultLink) or recipe.resultLink or ""
            local quality = nil
            if GetItemLinkDisplayQuality then
                quality = GetItemLinkDisplayQuality(link)
            elseif GetItemLinkQuality then
                quality = GetItemLinkQuality(link)
            end

            if isVariant then
                row.name:SetColor(0.85, 0.85, 0.85, 1)
            elseif quality then
                local qualityColor = GetItemQualityColor(quality)
                if qualityColor then
                    row.name:SetColor(qualityColor:UnpackRGBA())
                else
                    row.name:SetColor(1, 1, 1, 1)
                end
            else
                row.name:SetColor(1, 1, 1, 1)
            end

            local currentEntryUncraftable = isGroup
                and self:IsGroupUncraftable(group)
                or (recipe and recipe.currentApiUncraftable == true)

            if currentEntryUncraftable then
                row.material:SetText("|cCC6666" .. S(SI_AW_UNCRAFTABLE_SHORT) .. "|r")
            elseif available then
                row.material:SetText("|c66CC66" .. S(SI_AW_AVAILABLE) .. "|r")
            else
                row.material:SetText("|cCC6666" .. S(SI_AW_UNAVAILABLE) .. "|r")
            end
        else
            row.entry = nil
            row.recipe = nil
            row.isVariant = false
            row.name.recipe = nil
            row:SetHidden(true)
            row.insert:SetHandler("OnClicked", nil)
        end
    end

    self:RefreshCategoryButtons()
    self:UpdateHeaderColors()
    self:LayoutRecipeRows()

    if not self.window:IsHidden() then
        self:PositionAlchemyResultTooltip()
    end
end

function AW:ShowWindow(source)
    self:CreateUI()
    self.openedFromSettings = source == "settings"
    self.openedFromMainMenu = source == "mainmenu"
    self:ResetSortToDefault()
    self.window:SetHidden(false)
    self:ClampWindowPosition(false)
    self:RefreshList()
    zo_callLater(function() self:PositionAlchemyResultTooltip() end, 0)
end

function AW:HideWindow()
    if not self.window then return end
    self.hoveredRow = nil
    self:HideRecipeTooltip()
    self:RestoreAlchemyResultTooltip()
    self:SaveWindowPosition()
    self.window:SetHidden(true)
    self.openedFromSettings = false
    self.openedFromMainMenu = false
end

function AW:ToggleWindow(source)
    self:CreateUI()
    if self.window:IsHidden() then
        self:ShowWindow(source)
    else
        self:HideWindow()
    end
end

function AW:GetAlchemyModeBar()
    return _G.ZO_AlchemyTopLevelModeMenuBar
        or (_G.ALCHEMY and ALCHEMY.modeBar)
end

function AW:AddStationMenuButton()
    if self.stationMenuButton then return true end
    if not ZO_MenuBar_AddButton then return false end

    local alchemy = _G.ALCHEMY
    local modeBar = self:GetAlchemyModeBar()
    if not alchemy or not modeBar then return false end

    if ZO_MenuBar_GetButtonControl then
        local existing = ZO_MenuBar_GetButtonControl(modeBar, self.stationDescriptor)
        if existing then
            self.stationMenuButton = existing
            return true
        end
    end

    local buttonData = {
        activeTabText = S(SI_AW_TITLE),
        categoryName = S(SI_AW_TITLE),
        descriptor = self.stationDescriptor,
        normal = ICON_UP,
        pressed = ICON_DOWN,
        highlight = ICON_OVER,
        disabled = ICON_DISABLED,
        tooltip = S(SI_AW_STATION_TOOLTIP),
        callback = function()
            local currentMode = alchemy.mode
            self:ToggleWindow("station")
            zo_callLater(function()
                local currentBar = self:GetAlchemyModeBar()
                if currentBar and currentMode then
                    ZO_MenuBar_SelectDescriptor(currentBar, currentMode)
                end
                self:PositionAlchemyResultTooltip()
            end, 0)
        end,
    }

    local ok, result = pcall(ZO_MenuBar_AddButton, modeBar, buttonData)
    if not ok then return false end

    self.stationMenuButton = result or true
    if ZO_MenuBar_UpdateButtons then
        ZO_MenuBar_UpdateButtons(modeBar)
    end
    return true
end

function AW:TryAddStationMenuButton(attempt)
    if not self.atAlchemyStation then return end
    attempt = attempt or 1
    if self:AddStationMenuButton() then return end
    if attempt < 12 then
        zo_callLater(function() self:TryAddStationMenuButton(attempt + 1) end, 100)
    end
end

function AW:GetMainMenuBar()
    if _G.MAIN_MENU_KEYBOARD and MAIN_MENU_KEYBOARD.categoryBar then
        return MAIN_MENU_KEYBOARD.categoryBar
    end
    if _G.SYSTEMS and SYSTEMS.GetObject then
        local menu = SYSTEMS:GetObject("mainMenu")
        if menu and menu.categoryBar then return menu.categoryBar end
    end
    return _G.ZO_MainMenuCategoryBar
end

function AW:RefreshMainMenu()
    local bar = self:GetMainMenuBar()
    if not bar then return end
    if ZO_MenuBar_UpdateButtons then
        ZO_MenuBar_UpdateButtons(bar)
    end
end

function AW:InitializeMainMenu()
    if not ZO_MenuBar_AddButton then return false end
    local bar = self:GetMainMenuBar()
    if not bar then return false end

    if not _G["SI_ALCHEMIEWERK_MAIN_MENU_CATEGORY"] then
        ZO_CreateStringId("SI_ALCHEMIEWERK_MAIN_MENU_CATEGORY", S(SI_AW_TITLE))
    end

    if ZO_MenuBar_GetButtonControl then
        local existing = ZO_MenuBar_GetButtonControl(bar, self.mainMenuDescriptor)
        if existing then
            self.mainMenuButton = existing
            self.mainMenuRegistered = true
            self:RefreshMainMenu()
            return true
        end
    end

    -- A remembered flag is not enough: ESO can rebuild its category bar. If the
    -- actual control is gone, add our descriptor again exactly once to this bar.
    self.mainMenuRegistered = false

    local buttonData = {
        categoryName = _G["SI_ALCHEMIEWERK_MAIN_MENU_CATEGORY"],
        descriptor = self.mainMenuDescriptor,
        normal = ICON_UP,
        pressed = ICON_DOWN,
        highlight = ICON_OVER,
        disabled = ICON_DISABLED,
        visible = function()
            return self.sv.settings.showMainMenuIcon == true
        end,
        callback = function()
            self:ToggleWindow("mainmenu")
            PlaySound(SOUNDS.DEFAULT_CLICK)
            local previous = self.mainMenuPreviousDescriptor
            zo_callLater(function()
                local currentBar = self:GetMainMenuBar()
                if currentBar and previous and previous ~= self.mainMenuDescriptor then
                    ZO_MenuBar_SelectDescriptor(currentBar, previous, true)
                end
            end, 0)
        end,
    }

    local ok, returnedButton = pcall(ZO_MenuBar_AddButton, bar, buttonData)
    if not ok then return false end

    local button = returnedButton
    if not button and ZO_MenuBar_GetButtonControl then
        button = ZO_MenuBar_GetButtonControl(bar, self.mainMenuDescriptor)
    end

    self.mainMenuButton = button
    self.mainMenuRegistered = true

    if button and ZO_PreHookHandler then
        ZO_PreHookHandler(button, "OnMouseDown", function()
            local currentBar = self:GetMainMenuBar()
            if currentBar and ZO_MenuBar_GetSelectedDescriptor then
                local descriptor = ZO_MenuBar_GetSelectedDescriptor(currentBar)
                if descriptor and descriptor ~= self.mainMenuDescriptor then
                    self.mainMenuPreviousDescriptor = descriptor
                end
            end
            return false
        end)
    end

    if ZO_PreHookHandler and not self.mainMenuHideHooked then
        ZO_PreHookHandler(bar, "OnHide", function()
            if self.openedFromMainMenu and self.window and not self.window:IsHidden() then
                self:HideWindow()
            end
            return false
        end)
        self.mainMenuHideHooked = true
    end

    self:RefreshMainMenu()
    return true
end

function AW:TryInitializeMainMenu(attempt)
    attempt = attempt or 1
    if self:InitializeMainMenu() then return end
    if attempt < 20 then
        zo_callLater(function() self:TryInitializeMainMenu(attempt + 1) end, 150)
    end
end

function AW:InitializeSettings()
    if self.BuildSettings then
        self:BuildSettings()
    end
end

function AW:OnCraftingStationInteract(craftSkill)
    self.atAlchemyStation = craftSkill == CRAFTING_TYPE_ALCHEMY
    if not self.atAlchemyStation then return end

    zo_callLater(function()
        if not self.atAlchemyStation then return end
        self:TryInitializeCombinationTooltipHook(1)
        self:TryAddStationMenuButton(1)
        if self.sv.settings.autoOpen then
            self:ShowWindow("auto")
        elseif self.window and not self.window:IsHidden() then
            self:RefreshList()
            self:PositionAlchemyResultTooltip()
        end
    end, 150)
end

function AW:OnEndCraftingStationInteract(craftSkill)
    if craftSkill ~= CRAFTING_TYPE_ALCHEMY then return end
    self.atAlchemyStation = false
    self.pendingCraft = nil
    if self.window and not self.window:IsHidden() then
        self:HideWindow()
    else
        self:RestoreAlchemyResultTooltip()
    end
end

function AW:MigrateSavedVariables()
    self.sv.recipes = self.sv.recipes or {}
    self.sv.settings = self.sv.settings or {}
    self.sv.window = self.sv.window or {}
    if self.sv.window.locked == nil then self.sv.window.locked = false end

    local settings = self.sv.settings
    if settings.autoOpen == nil then settings.autoOpen = false end
    if settings.closeAfterInsert == nil then
        if settings.keepOpen ~= nil then
            settings.closeAfterInsert = not settings.keepOpen
        else
            settings.closeAfterInsert = true
        end
    end
    if settings.chatMessages == nil then settings.chatMessages = true end
    if settings.defaultSortColumn == nil then settings.defaultSortColumn = "name" end
    if settings.defaultSortAscending == nil then settings.defaultSortAscending = true end
    if settings.mainMenuVisibilityInitialized == nil then
        -- 0.2.0/0.2.1 stored false by default even though the standard expects
        -- the normal ESO main-menu icon to be available and user-disableable.
        settings.showMainMenuIcon = true
        settings.mainMenuVisibilityInitialized = true
    elseif settings.showMainMenuIcon == nil then
        settings.showMainMenuIcon = true
    end

    for _, recipe in pairs(self.sv.recipes) do
        self:EnsureRecipeData(recipe)
    end
end

function AW:Initialize()
    self.defaults = {
        recipes = {},
        settings = {
            autoOpen = false,
            closeAfterInsert = true,
            chatMessages = true,
            defaultSortColumn = "name",
            defaultSortAscending = true,
            showMainMenuIcon = true,
            mainMenuVisibilityInitialized = true,
        },
        window = {
            locked = false,
        },
    }

    self.sv = ZO_SavedVars:NewAccountWide("AlchemiewerkSavedVariables", self.svVersion, GetWorldName(), self.defaults)
    self:MigrateSavedVariables()

    self:CreateUI()
    self:InitializeSettings()
    self:TryInitializeMainMenu(1)
    self:TryInitializeCombinationTooltipHook(1)

    SecurePostHook("CraftAlchemyItem", function(...)
        self:CaptureAlchemyCraft(...)
    end)

    EVENT_MANAGER:RegisterForEvent(self.name .. "CraftComplete", EVENT_CRAFT_COMPLETED,
        function(_, craftSkill) self:OnCraftCompleted(craftSkill) end)

    EVENT_MANAGER:RegisterForEvent(self.name .. "StationStart", EVENT_CRAFTING_STATION_INTERACT,
        function(_, craftSkill) self:OnCraftingStationInteract(craftSkill) end)

    EVENT_MANAGER:RegisterForEvent(self.name .. "StationEnd", EVENT_END_CRAFTING_STATION_INTERACT,
        function(_, craftSkill) self:OnEndCraftingStationInteract(craftSkill) end)

    if EVENT_SCREEN_RESIZED then
        EVENT_MANAGER:RegisterForEvent(self.name .. "ScreenResize", EVENT_SCREEN_RESIZED,
            function()
                zo_callLater(function() self:ApplyResponsiveLayout(false) end, 50)
            end)
    end

    EVENT_MANAGER:RegisterForEvent(self.name .. "PlayerActivated", EVENT_PLAYER_ACTIVATED,
        function()
            self:ApplyResponsiveLayout(false)
            self:TryInitializeMainMenu(1)
            self:RefreshMainMenu()
            self:TryInitializeCombinationTooltipHook(1)
            if GetCraftingInteractionType() == CRAFTING_TYPE_ALCHEMY then
                self.atAlchemyStation = true
                self:TryAddStationMenuButton(1)
            end
        end)

    SLASH_COMMANDS["/alchemiewerk"] = function() self:ToggleWindow("slash") end
    SLASH_COMMANDS["/aw"] = function() self:ToggleWindow("slash") end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= AW.name then return end
    EVENT_MANAGER:UnregisterForEvent(AW.name, EVENT_ADD_ON_LOADED)
    AW:Initialize()
end

EVENT_MANAGER:RegisterForEvent(AW.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
