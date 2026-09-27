local Addon = LarvalTearMod

local QuickSettings = Addon.UI.QuickSettings
local Log = Addon.Common.Log
local Util = Addon.Common.Util
local QuickslotProfileFacade = QuickSettings.ProfileFacade
local Strings = Addon.UI.Strings
local AlchemyRecipe = Addon.Modules.AlchemyRecipe
local EnchantRecipe = Addon.Modules.EnchantRecipe
local ScribingRecipe = Addon.Modules.ScribingRecipe

local QUICK_SETTINGS_LEFT_PANE_WIDTH = 180
local QUICK_SETTINGS_PANE_GAP = 18
local QUICK_SETTINGS_MENU_ROW_HEIGHT = 34
local QUICK_SETTINGS_MENU_ROW_GAP = 6
local QUICK_SETTINGS_PANEL_PADDING = 12
local QUICK_SLOT_CARD_HEIGHT = 90
local QUICK_SLOT_CARD_GAP = 10
local QUICK_SLOT_ICON_SIZE = 40
local QUICK_SLOT_ICON_GAP = 6
local QUICK_SLOT_SETTINGS_MENU_ROW_HEIGHT = 26
-- The standard container reserves 16px; keep the previous 18px QuickSlot list gutter.
local QUICK_SLOT_SCROLLBAR_CONTENT_GAP = 2
local QUICK_SLOT_FETCH_BUTTON_DISABLED_ALPHA = 0.38
local QUICK_SLOT_FETCH_MONITOR_INTERVAL_MS = 1000
local QUICK_SLOT_FALLBACK_REFRESH_INTERVAL_COUNT = 5
local QUICK_SLOT_REFRESH_INVENTORY_EVENT_NAME = "LTM_QuickSettings_QuickSlotInventory"
local QUICK_SLOT_REFRESH_BANK_OPEN_EVENT_NAME = "LTM_QuickSettings_QuickSlotBankOpen"
local QUICK_SLOT_REFRESH_BANK_CLOSE_EVENT_NAME = "LTM_QuickSettings_QuickSlotBankClose"
local RECIPE_SHORT_REFRESH_INTERVAL_MS = 2000
local RECIPE_SHORT_REFRESH_MAX_COUNT = 15
local RECIPE_SHORT_REFRESH_STABLE_COUNT = 2
local RECIPE_REFRESH_INVENTORY_EVENT_NAME = "LTM_QuickSettings_RecipeInventory"
local RECIPE_REFRESH_CRAFT_EVENT_NAME = "LTM_QuickSettings_RecipeCraft"
local RECIPE_REFRESH_STATION_EVENT_NAME = "LTM_QuickSettings_RecipeStation"
local RECIPE_REFRESH_STATION_END_EVENT_NAME = "LTM_QuickSettings_RecipeStationEnd"
local QUICK_SLOT_FETCH_ICON_TEXTURE = "/esoui/art/icons/guildranks/guild_indexicon_misc09"
local QUICK_SLOT_FETCH_OPTIONS_TOP = 33
local QUICK_SLOT_FETCH_MODE_ROW_WIDTH = 218
local QUICK_SLOT_FETCH_PREFERENCE_LEFT = 236
local QUICK_SLOT_SAVE_BUTTON_TOP_OFFSET = 4
local QUICK_SLOT_CARD_COLUMNS = 2
local QUICK_SLOT_CARD_GRID_GAP = 10
local QUICK_SLOT_CARD_CHECKBOX_SIZE = 22
local QUICK_SLOT_CARD_ICON_BUTTON_SIZE = 24
local QUICK_SLOT_CARD_FETCH_BUTTON_SIZE = 30
local QUICK_SLOT_FETCH_MODE_MISSING = "missing"
local QUICK_SLOT_FETCH_MODE_REFILL_MAX = "refill_max"
local FOOD_CARD_SIZE = 112
local FOOD_CARD_GAP = 10
local FOOD_CARD_ICON_SIZE = 44
local FOOD_CARD_ICON_TOP = 31
local FOOD_CARD_LABEL_TOP_GAP = 21
local FOOD_CARD_DELETE_BUTTON_SIZE = 18
local FOOD_CARD_DEFAULT_COLUMNS = 4
local FOOD_PANEL_HEADER_HEIGHT = 68
local FOOD_PANEL_HEADER_TITLE_GAP = 5
local FOOD_PANEL_TITLE_HEIGHT = 32
local FOOD_AUTO_EAT_CHECKBOX_SIZE = 18
local FOOD_AUTO_EAT_LABEL_OFFSET_Y = 10
local FOOD_EMPTY_ICON_TEXTURE = "/esoui/art/crafting/provisioner_indexicon_meat_disabled.dds"
local ALCHEMY_RECIPE_CARD_HEIGHT = 106
local SCRIBING_RECIPE_CARD_HEIGHT = 134
local ALCHEMY_RECIPE_CARD_GAP = 10
local ALCHEMY_RECIPE_CARD_COLUMNS = 2
local ALCHEMY_RECIPE_ACTIVE_CHECKBOX_SIZE = 18
local ALCHEMY_RECIPE_RESULT_ICON_SIZE = 44
local ALCHEMY_RECIPE_REAGENT_ICON_SIZE = 28
local ALCHEMY_RECIPE_ICON_GAP = 6
local ALCHEMY_RECIPE_COUNT_EDIT_WIDTH = 54
local ALCHEMY_RECIPE_COUNT_EDIT_HEIGHT = 24
local ALCHEMY_RECIPE_ICON_BUTTON_SIZE = 24
local ALCHEMY_RECIPE_APPLY_BUTTON_WIDTH = 132
local ALCHEMY_RECIPE_PLACEHOLDER_ICON = "/esoui/art/icons/icon_missing.dds"
local scribingRecipeCardControlSerial = 0

local MENU_ENTRIES = {
    { id = "quick_slots", textKey = "quick_settings.menu.quick_slots" },
    { id = "food_helper", textKey = "quick_settings.menu.food_helper" },
    { id = "alchemy_recipe", textKey = "quick_settings.menu.alchemy_recipe" },
    { id = "enchant_recipe", textKey = "quick_settings.menu.enchant_recipe" },
    { id = "scribing_recipe", textKey = "quick_settings.menu.scribing_recipe" },
}

local RECIPE_DESCRIPTORS = {
    {
        menuId = "alchemy_recipe",
        recipeModule = AlchemyRecipe,
        craftingTypeName = "CRAFTING_TYPE_ALCHEMY",
        stationEventRefresh = true,
        panelField = "alchemyRecipePanel",
        headerField = "alchemyRecipeHeader",
        refreshMethod = "RefreshAlchemyRecipe",
        nameFallbackField = "resultItemLink",
        applyLogTag = "[AlchemyRecipe]",
        inventoryRefresh = true,
        cardControlPrefix = "LTM_AlchemyRecipeCard",
        pageControlName = "AlchemyRecipe",
        renameDialogId = "ALCHEMY_RECIPE_RENAME_INPUT",
    },
    {
        menuId = "enchant_recipe",
        recipeModule = EnchantRecipe,
        craftingTypeName = "CRAFTING_TYPE_ENCHANTING",
        stationEventRefresh = true,
        panelField = "enchantRecipePanel",
        headerField = "enchantRecipeHeader",
        refreshMethod = "RefreshEnchantRecipe",
        nameFallbackField = "resultItemLink",
        applyLogTag = "[EnchantRecipe]",
        inventoryRefresh = true,
        cardControlPrefix = "LTM_EnchantRecipeCard",
        pageControlName = "EnchantRecipe",
        renameDialogId = "ENCHANT_RECIPE_RENAME_INPUT",
    },
    {
        menuId = "scribing_recipe",
        recipeModule = ScribingRecipe,
        craftingTypeName = "CRAFTING_TYPE_SCRIBING",
        panelField = "scribingRecipePanel",
        headerField = "scribingRecipeHeader",
        refreshMethod = "RefreshScribingRecipe",
        nameFallbackField = "craftedAbilityName",
        applyLogTag = "[ScribingRecipe]",
    },
}
local RECIPE_DESCRIPTOR_BY_MENU_ID = {}
for _, descriptor in ipairs(RECIPE_DESCRIPTORS) do
    RECIPE_DESCRIPTOR_BY_MENU_ID[descriptor.menuId] = descriptor
end

local function GetText(key, params)
    return Strings:GetText(key, params)
end

local function CreateBackdrop(parent, name, centerR, centerG, centerB, centerA, edgeR, edgeG, edgeB, edgeA)
    local control = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    control:SetCenterColor(centerR, centerG, centerB, centerA)
    control:SetEdgeColor(edgeR, edgeG, edgeB, edgeA)
    return control
end

local function SetControlDrawOrder(control, drawTier, drawLayer, drawLevel)
    if control == nil then
        return
    end

    if drawTier ~= nil and type(control.SetDrawTier) == "function" then
        control:SetDrawTier(drawTier)
    end

    if drawLayer ~= nil and type(control.SetDrawLayer) == "function" then
        control:SetDrawLayer(drawLayer)
    end

    if drawLevel ~= nil and type(control.SetDrawLevel) == "function" then
        control:SetDrawLevel(drawLevel)
    end
end

local function CreateCardListScrollContainer(parent, topOffset, contentScrollbarGap)
    local scrollContainer = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)ScrollContainer", parent, "ZO_ScrollContainer")
    scrollContainer:ClearAnchors()
    scrollContainer:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, topOffset or 0)
    scrollContainer:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0)
    SetControlDrawOrder(scrollContainer, DT_HIGH, DL_CONTROLS, 5)

    if type(ZO_Scroll_SetUseFadeGradient) == "function" then
        ZO_Scroll_SetUseFadeGradient(scrollContainer, false)
    end
    if type(ZO_Scroll_SetHideScrollbarOnDisable) == "function" then
        ZO_Scroll_SetHideScrollbarOnDisable(scrollContainer, true)
    end

    local scroll = scrollContainer:GetNamedChild("Scroll")
    local scrollbar = scrollContainer:GetNamedChild("ScrollBar")
    local scrollChild = scrollContainer:GetNamedChild("ScrollChild")
    SetControlDrawOrder(scroll, DT_HIGH, DL_CONTROLS, 5)
    SetControlDrawOrder(scrollChild, DT_HIGH, DL_CONTROLS, 5)
    SetControlDrawOrder(scrollbar, DT_HIGH, DL_CONTROLS, 9)

    scrollChild:ClearAnchors()
    scrollChild:SetAnchor(TOPLEFT, scroll, TOPLEFT, 0, 0)
    scrollChild:SetAnchor(TOPRIGHT, scroll, TOPRIGHT, -(contentScrollbarGap or 0), 0)
    scrollChild:SetHeight(1)
    scrollChild:SetMouseEnabled(false)
    if type(scrollChild.SetResizeToFitDescendents) == "function" then
        scrollChild:SetResizeToFitDescendents(false)
    end

    if scrollbar and type(ZO_VerticalScrollbarBase_OnMouseExit) == "function" then
        ZO_VerticalScrollbarBase_OnMouseExit(scrollbar)
    end

    return {
        container = scrollContainer,
        scroll = scroll,
        scrollbar = scrollbar,
        scrollChild = scrollChild,
    }
end

local function RefreshCardListScrollContainer(scrollState, contentHeight)
    if type(scrollState) ~= "table" or scrollState.scroll == nil or scrollState.scrollChild == nil then
        return
    end

    local scroll = scrollState.scroll
    local _, previousOffset = scroll:GetScrollOffsets()
    local viewportHeight = math.max(tonumber(scroll:GetHeight()) or 0, 0)
    local totalHeight = math.max(tonumber(contentHeight) or 0, viewportHeight, 1)
    scrollState.scrollChild:SetHeight(totalHeight)

    if type(ZO_Scroll_UpdateScrollBar) == "function" then
        ZO_Scroll_UpdateScrollBar(scrollState.container, true)
    end

    local _, verticalExtents = scroll:GetScrollExtents()
    local clampedOffset = math.min(
        math.max(tonumber(previousOffset) or 0, 0),
        math.max(tonumber(verticalExtents) or 0, 0)
    )
    if clampedOffset ~= previousOffset then
        scroll:SetVerticalScroll(clampedOffset)
        if type(ZO_Scroll_UpdateScrollBar) == "function" then
            ZO_Scroll_UpdateScrollBar(scrollState.container, true)
        end
    end
end

local function BuildRecipeLayoutSignature(recipes, listRoot, scrollState)
    local listWidth = listRoot and listRoot.GetWidth and listRoot:GetWidth() or 0
    local scroll = type(scrollState) == "table" and scrollState.scroll or nil
    if type(listWidth) ~= "number" or listWidth <= 0 then
        listWidth = scroll and scroll.GetWidth and scroll:GetWidth() or 0
    end
    local viewportHeight = scroll and scroll.GetHeight and scroll:GetHeight() or 0
    local parts = {
        tostring(#recipes),
        tostring(listWidth),
        tostring(viewportHeight),
    }
    for index, recipe in ipairs(recipes) do
        local recipeId = tostring(type(recipe) == "table" and recipe.id or "")
        parts[#parts + 1] = tostring(index) .. ":" .. tostring(#recipeId) .. ":" .. recipeId
    end
    return table.concat(parts, "|")
end

local function BuildInventoryItemStateSignature(itemState)
    itemState = type(itemState) == "table" and itemState or {}
    return table.concat({
        tostring(itemState.itemId),
        tostring(itemState.found == true),
        tostring(itemState.bagId),
        tostring(itemState.slotIndex),
        tostring(tonumber(itemState.stackCount) or 0),
        tostring(tonumber(itemState.totalStackCount) or 0),
        tostring(itemState.runeType),
        tostring(itemState.runeTypeValid),
    }, ":")
end

local function SetLabelText(control, text)
    if control and control.SetText then
        control:SetText(text or "")
    end
end

local function WriteChat(text)
    Log.WriteChat(text)
end

local function SetTextTooltip(control, text)
    if control == nil then
        return
    end

    control.ltmTooltipText = text or ""
    control:SetHandler("OnMouseEnter", function(self)
        if type(InitializeTooltip) == "function" and InformationTooltip and type(self.ltmTooltipText) == "string" and self.ltmTooltipText ~= "" then
            InitializeTooltip(InformationTooltip, self, TOP, 0, 0, BOTTOM)
            if type(SetTooltipText) == "function" then
                SetTooltipText(InformationTooltip, self.ltmTooltipText)
            end
        end
    end)
    control:SetHandler("OnMouseExit", function()
        if type(ClearTooltip) == "function" and InformationTooltip then
            ClearTooltip(InformationTooltip)
        end
    end)
end

local function SetItemTooltip(control, itemLink, fallbackText)
    if control == nil then
        return
    end

    control.ltmItemLink = itemLink
    control.ltmTooltipText = fallbackText or ""
    control:SetHandler("OnMouseEnter", function(self)
        if type(self.ltmItemLink) == "string" and self.ltmItemLink ~= ""
            and type(InitializeTooltip) == "function" and ItemTooltip then
            InitializeTooltip(ItemTooltip, self, TOP, 0, 0, BOTTOM)
            ItemTooltip:SetLink(self.ltmItemLink)
        elseif type(InitializeTooltip) == "function" and InformationTooltip
            and type(self.ltmTooltipText) == "string" and self.ltmTooltipText ~= "" then
            InitializeTooltip(InformationTooltip, self, TOP, 0, 0, BOTTOM)
            if type(SetTooltipText) == "function" then
                SetTooltipText(InformationTooltip, self.ltmTooltipText)
            end
        end
    end)
    control:SetHandler("OnMouseExit", function()
        if type(ClearTooltip) == "function" then
            if ItemTooltip then
                ClearTooltip(ItemTooltip)
            end
            if InformationTooltip then
                ClearTooltip(InformationTooltip)
            end
        end
    end)
end

local function ClearScribingTooltip()
    if type(ClearTooltip) == "function" then
        if AbilityTooltip then
            ClearTooltip(AbilityTooltip)
        end
        if InformationTooltip then
            ClearTooltip(InformationTooltip)
        end
    end
end

local function ShowScribingFallbackTooltip(control, fallbackText)
    if control == nil
        or type(fallbackText) ~= "string"
        or fallbackText == ""
        or type(InitializeTooltip) ~= "function"
        or not InformationTooltip then
        return
    end

    InitializeTooltip(InformationTooltip, control, RIGHT, 0, 0, LEFT)
    if type(SetTooltipText) == "function" then
        SetTooltipText(InformationTooltip, fallbackText)
    end
end

local function NormalizeScribingId(value)
    local id = tonumber(value)
    if id ~= nil and id > 0 then
        return id
    end

    return nil
end

local function NormalizeScribingScriptId(value)
    return tonumber(value) or 0
end

local function ShowCraftedAbilityTooltip(control, craftedAbilityId, primaryScriptId, secondaryScriptId, tertiaryScriptId, fallbackText)
    craftedAbilityId = NormalizeScribingId(craftedAbilityId)
    if control == nil or craftedAbilityId == nil then
        return
    end

    if AbilityTooltip and type(InitializeTooltip) == "function" and type(AbilityTooltip.SetCraftedAbility) == "function" then
        InitializeTooltip(AbilityTooltip, control, RIGHT, 0, 0, LEFT)
        local displayFlags = rawget(_G, "SCRIBING_TOOLTIP_DISPLAY_FLAGS_SHOW_SELECTED_SCRIPTS") or 0
        local ok = pcall(
            AbilityTooltip.SetCraftedAbility,
            AbilityTooltip,
            craftedAbilityId,
            NormalizeScribingScriptId(primaryScriptId),
            NormalizeScribingScriptId(secondaryScriptId),
            NormalizeScribingScriptId(tertiaryScriptId),
            displayFlags
        )
        if ok then
            return
        end

        ClearScribingTooltip()
    end

    ShowScribingFallbackTooltip(control, fallbackText)
end

local function ShowCraftedAbilityScriptTooltip(control, craftedAbilityId, scriptId, primaryScriptId, secondaryScriptId, tertiaryScriptId, fallbackText)
    craftedAbilityId = NormalizeScribingId(craftedAbilityId)
    scriptId = NormalizeScribingId(scriptId)
    if control == nil or craftedAbilityId == nil or scriptId == nil then
        return
    end

    if AbilityTooltip and type(InitializeTooltip) == "function" and type(AbilityTooltip.SetCraftedAbilityScript) == "function" then
        InitializeTooltip(AbilityTooltip, control, RIGHT, 0, 0, LEFT)
        local displayFlags = rawget(_G, "SCRIBING_TOOLTIP_DISPLAY_FLAGS_SHOW_ACQUIRE_HINT") or 0
        local ok = pcall(
            AbilityTooltip.SetCraftedAbilityScript,
            AbilityTooltip,
            craftedAbilityId,
            scriptId,
            NormalizeScribingScriptId(primaryScriptId),
            NormalizeScribingScriptId(secondaryScriptId),
            NormalizeScribingScriptId(tertiaryScriptId),
            displayFlags
        )
        if ok then
            return
        end

        ClearScribingTooltip()
    end

    ShowScribingFallbackTooltip(control, fallbackText)
end

local function GetItemLinkFromBagSlot(bagId, slotIndex)
    if bagId == nil or slotIndex == nil or type(GetItemLink) ~= "function" then
        return nil
    end

    local linkStyle = rawget(_G, "LINK_STYLE_DEFAULT")
    local ok, itemLink
    if linkStyle ~= nil then
        ok, itemLink = pcall(GetItemLink, bagId, slotIndex, linkStyle)
    else
        ok, itemLink = pcall(GetItemLink, bagId, slotIndex)
    end
    if ok and type(itemLink) == "string" and itemLink ~= "" then
        return itemLink
    end

    return nil
end

local function GetItemLinkIconSafe(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" or type(GetItemLinkIcon) ~= "function" then
        return nil
    end

    local ok, icon = pcall(GetItemLinkIcon, itemLink)
    if ok and type(icon) == "string" and icon ~= "" then
        return icon
    end

    return nil
end

local function GetItemLinkNameSafe(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" or type(GetItemLinkName) ~= "function" then
        return nil
    end

    local ok, name = pcall(GetItemLinkName, itemLink)
    if ok and type(name) == "string" and name ~= "" then
        return name
    end

    return nil
end

local function BuildCraftingRecipeItemDisplay(itemState, fallbackItemId)
    itemState = type(itemState) == "table" and itemState or {}
    local itemLink = GetItemLinkFromBagSlot(itemState.bagId, itemState.slotIndex)
    local itemId = itemState.itemId or fallbackItemId
    return {
        itemId = itemId,
        itemLink = itemLink,
        icon = GetItemLinkIconSafe(itemLink) or ALCHEMY_RECIPE_PLACEHOLDER_ICON,
        name = GetItemLinkNameSafe(itemLink) or (itemId ~= nil and ("itemId " .. tostring(itemId)) or GetText("common.none")),
        count = tonumber(itemState.totalStackCount) or 0,
        found = itemState.found == true,
    }
end

local function CreateButton(parent, name, text, width, onClicked)
    local button = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_DefaultButton")
    button:SetDimensions(width or 120, 28)
    button:SetFont("ZoFontGameSmall")
    button:SetText(text or "")
    button:SetHandler("OnClicked", function()
        if type(onClicked) == "function" then
            onClicked()
        end
    end)
    return button
end

local function CreateIconButton(parent, name, size, texturePrefix, tooltipText, onClicked)
    local button = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    button:SetDimensions(size, size)
    button:SetMouseEnabled(true)
    button:SetClickSound(SOUNDS.DEFAULT_CLICK)
    button.ltmTexturePrefix = texturePrefix
    button:SetNormalTexture(texturePrefix .. "_up.dds")
    button:SetMouseOverTexture(texturePrefix .. "_over.dds")
    button:SetPressedTexture(texturePrefix .. "_down.dds")
    button:SetDisabledTexture(texturePrefix .. "_disabled.dds")

    SetTextTooltip(button, tooltipText)
    button:SetHandler("OnClicked", function()
        if type(onClicked) == "function" then
            onClicked(button)
        end
    end)

    return button
end

local function GetQuickSlotFetchMonitorState()
    local ui = Addon.UI
    local windowVisible = ui.window ~= nil
        and type(ui.window.IsHidden) == "function"
        and ui.window:IsHidden() == false
    local quickSettingsActive = ui:IsArmoryStationTabActive() == false
    local quickSlotsPanel = QuickSettings.quickSlotsPanel
    local quickSlotsVisible = QuickSettings.selectedMenuId == "quick_slots"
        and quickSlotsPanel ~= nil
        and type(quickSlotsPanel.IsHidden) == "function"
        and quickSlotsPanel:IsHidden() == false

    return {
        windowVisible = windowVisible,
        quickSettingsActive = quickSettingsActive,
        quickSlotsVisible = quickSlotsVisible,
    }
end

local function GetQuickSlotFetchActivityState()
    local availability = QuickslotProfileFacade:GetFetchAvailability(QuickSettings.quickSlotFetchMode, 0)

    return {
        fetchBusy = availability.busy == true,
        bankOpen = type(IsBankOpen) == "function" and IsBankOpen() == true,
    }
end

local function IsRecipeMenuId(menuId)
    return RECIPE_DESCRIPTOR_BY_MENU_ID[menuId] ~= nil
end

local function RefreshRecipePage(self, menuId)
    local descriptor = RECIPE_DESCRIPTOR_BY_MENU_ID[menuId]
    if descriptor ~= nil then
        return self[descriptor.refreshMethod](self)
    end

    return nil
end

local function IsRecipePageVisible(self, menuId)
    local state = GetQuickSlotFetchMonitorState()
    if type(state) ~= "table" or state.windowVisible ~= true or state.quickSettingsActive ~= true then
        return false
    end
    if self.selectedMenuId ~= menuId then
        return false
    end
    local descriptor = RECIPE_DESCRIPTOR_BY_MENU_ID[menuId]
    local panel = descriptor ~= nil and self[descriptor.panelField] or nil
    return panel ~= nil and type(panel.IsHidden) == "function" and panel:IsHidden() == false
end

local function GetRecipeMenuIdForCraftingType(craftingType)
    for _, descriptor in ipairs(RECIPE_DESCRIPTORS) do
        if descriptor.craftingTypeName ~= nil and craftingType == rawget(_G, descriptor.craftingTypeName) then
            return descriptor.menuId
        end
    end
    return nil
end

local function HandleRecipeResult(self, descriptor, action, outcome, detail, recipeId)
    local success
    if action == "deleted" or action == "applied" then
        success = outcome == true
    else
        success = type(outcome) == "table"
    end

    if not success then
        WriteChat(descriptor.errorText(detail))
        RefreshRecipePage(self, descriptor.menuId)
        return false
    end

    if action == "deleted" then
        WriteChat(GetText("quick_settings." .. descriptor.menuId .. ".deleted"))
    else
        local recipe = outcome
        local fallbackId
        if action == "applied" then
            recipe = type(detail) == "table" and type(detail.recipe) == "table" and detail.recipe or {}
            fallbackId = recipeId
        else
            fallbackId = recipe.id
        end
        WriteChat(GetText("quick_settings." .. descriptor.menuId .. "." .. action, {
            recipeName = recipe.name or recipe[descriptor.nameFallbackField] or fallbackId or "",
        }))
    end

    if action == "applied" then
        Log.Debug(descriptor.applyLogTag, "manualApply", "ok=true", "recipeId=" .. tostring(recipeId))
    end
    RefreshRecipePage(self, descriptor.menuId)
    if action == "applied" then
        self:StartRecipeShortRefresh(descriptor.menuId)
    end
    return true
end

local function ScheduleVisibleRecipeRefresh(self, menuId)
    if not IsRecipePageVisible(self, menuId) then
        return
    end

    self.recipeEventRefreshMenuId = menuId
    if self.recipeEventRefreshScheduled == true then
        return
    end

    self.recipeEventRefreshScheduled = true
    local function RefreshIfVisible()
        self.recipeEventRefreshScheduled = false
        local scheduledMenuId = self.recipeEventRefreshMenuId
        self.recipeEventRefreshMenuId = nil
        if IsRecipePageVisible(self, scheduledMenuId) then
            RefreshRecipePage(self, scheduledMenuId)
        end
    end

    if type(zo_callLater) == "function" then
        zo_callLater(RefreshIfVisible, 0)
    else
        RefreshIfVisible()
    end
end

local SetSelectedMenu

local function RegisterRecipeRefreshEvents(self)
    if self.recipeRefreshEventsRegistered == true then
        return
    end

    local eventManager = Util:GetEventManager()
    if eventManager == nil then
        return
    end

    self.recipeRefreshEventsRegistered = true
    local inventoryEvent = rawget(_G, "EVENT_INVENTORY_SINGLE_SLOT_UPDATE")
    if inventoryEvent ~= nil then
        eventManager:RegisterForEvent(RECIPE_REFRESH_INVENTORY_EVENT_NAME, inventoryEvent, function(_, bagId)
            if bagId == rawget(_G, "BAG_BACKPACK") or bagId == rawget(_G, "BAG_VIRTUAL") then
                local menuId = self.selectedMenuId
                local descriptor = RECIPE_DESCRIPTOR_BY_MENU_ID[menuId]
                if descriptor ~= nil and descriptor.inventoryRefresh == true then
                    ScheduleVisibleRecipeRefresh(self, menuId)
                end
            end
        end)
    end

    local craftEvent = rawget(_G, "EVENT_CRAFT_COMPLETED")
    if craftEvent ~= nil then
        eventManager:RegisterForEvent(RECIPE_REFRESH_CRAFT_EVENT_NAME, craftEvent, function(_, craftingType)
            local menuId = GetRecipeMenuIdForCraftingType(craftingType)
            local descriptor = RECIPE_DESCRIPTOR_BY_MENU_ID[menuId]
            if descriptor ~= nil and descriptor.stationEventRefresh == true and self.selectedMenuId == menuId then
                self:StartRecipeShortRefresh(menuId)
                ScheduleVisibleRecipeRefresh(self, menuId)
            end
        end)
    end

    local stationEvent = rawget(_G, "EVENT_CRAFTING_STATION_INTERACT")
    if stationEvent ~= nil then
        eventManager:RegisterForEvent(RECIPE_REFRESH_STATION_EVENT_NAME, stationEvent, function(_, craftingType)
            local menuId = GetRecipeMenuIdForCraftingType(craftingType)
            if menuId ~= nil then
                zo_callLater(function()
                    SetSelectedMenu(self, menuId)
                    local descriptor = RECIPE_DESCRIPTOR_BY_MENU_ID[menuId]
                    if descriptor.stationEventRefresh == true and IsRecipePageVisible(self, menuId) then
                        self:StartRecipeShortRefresh(menuId)
                    end
                end, 0)
            end
        end)
    end

    local stationEndEvent = rawget(_G, "EVENT_END_CRAFTING_STATION_INTERACT")
    if stationEndEvent ~= nil then
        eventManager:RegisterForEvent(RECIPE_REFRESH_STATION_END_EVENT_NAME, stationEndEvent, function(_, craftingType)
            local menuId = GetRecipeMenuIdForCraftingType(craftingType)
            local descriptor = RECIPE_DESCRIPTOR_BY_MENU_ID[menuId]
            if descriptor ~= nil and descriptor.stationEventRefresh == true then
                ScheduleVisibleRecipeRefresh(self, menuId)
            end
        end)
    end
end

local function RegisterQuickSlotRefreshEvents(self)
    if self.quickSlotRefreshEventsRegistered == true then
        return
    end

    local eventManager = Util:GetEventManager()
    if eventManager == nil then
        return
    end

    self.quickSlotRefreshEventsRegistered = true
    local inventoryEvent = rawget(_G, "EVENT_INVENTORY_SINGLE_SLOT_UPDATE")
    if inventoryEvent ~= nil then
        eventManager:RegisterForEvent(QUICK_SLOT_REFRESH_INVENTORY_EVENT_NAME, inventoryEvent, function(_, bagId)
            if bagId == rawget(_G, "BAG_BACKPACK") then
                self.quickSlotDisplayDirty = true
            end
        end)
    end

    local bankOpenEvent = rawget(_G, "EVENT_OPEN_BANK")
    if bankOpenEvent ~= nil then
        eventManager:RegisterForEvent(QUICK_SLOT_REFRESH_BANK_OPEN_EVENT_NAME, bankOpenEvent, function()
            self.quickSlotDisplayDirty = true
        end)
    end

    local bankCloseEvent = rawget(_G, "EVENT_CLOSE_BANK")
    if bankCloseEvent ~= nil then
        eventManager:RegisterForEvent(QUICK_SLOT_REFRESH_BANK_CLOSE_EVENT_NAME, bankCloseEvent, function()
            self.quickSlotDisplayDirty = true
        end)
    end
end

function QuickSettings:StopRecipeShortRefresh()
    self.recipeShortRefreshToken = (tonumber(self.recipeShortRefreshToken) or 0) + 1
    self.recipeShortRefreshMenuId = nil
    self.recipeShortRefreshCount = 0
    self.recipeShortRefreshStableCount = 0
    self.recipeShortRefreshSignature = nil
end

function QuickSettings:StartRecipeShortRefresh(menuId)
    if not IsRecipeMenuId(menuId) then
        return
    end

    self.recipeShortRefreshToken = (tonumber(self.recipeShortRefreshToken) or 0) + 1
    local token = self.recipeShortRefreshToken
    self.recipeShortRefreshMenuId = menuId
    self.recipeShortRefreshCount = 0
    self.recipeShortRefreshStableCount = 0
    self.recipeShortRefreshSignature = nil

    local function RunNext()
        if self.recipeShortRefreshToken ~= token or self.recipeShortRefreshMenuId ~= menuId then
            return
        end
        if self.recipeShortRefreshCount >= RECIPE_SHORT_REFRESH_MAX_COUNT then
            self:StopRecipeShortRefresh()
            return
        end
        if not IsRecipePageVisible(self, menuId) then
            self:StopRecipeShortRefresh()
            return
        end

        self.recipeShortRefreshCount = self.recipeShortRefreshCount + 1
        local refreshSignature = RefreshRecipePage(self, menuId)
        if refreshSignature ~= nil then
            if refreshSignature == self.recipeShortRefreshSignature then
                self.recipeShortRefreshStableCount = self.recipeShortRefreshStableCount + 1
            else
                self.recipeShortRefreshStableCount = 1
                self.recipeShortRefreshSignature = refreshSignature
            end
            if self.recipeShortRefreshStableCount >= RECIPE_SHORT_REFRESH_STABLE_COUNT then
                self:StopRecipeShortRefresh()
                return
            end
        end

        if self.recipeShortRefreshCount < RECIPE_SHORT_REFRESH_MAX_COUNT and type(zo_callLater) == "function" then
            zo_callLater(RunNext, RECIPE_SHORT_REFRESH_INTERVAL_MS)
        else
            self:StopRecipeShortRefresh()
        end
    end

    if type(zo_callLater) == "function" then
        zo_callLater(RunNext, RECIPE_SHORT_REFRESH_INTERVAL_MS)
    end
end

local function NormalizeQuickSlotFetchMode(mode)
    return QuickslotProfileFacade:NormalizeFetchMode(mode)
end

local function RefreshQuickSlotFetchModeControls()
    local mode = NormalizeQuickSlotFetchMode(QuickSettings.quickSlotFetchMode)
    if QuickSettings.quickSlotFetchModeComboBox ~= nil then
        QuickSettings.quickSlotFetchModeComboBox:SetSelectedItemText(mode == QUICK_SLOT_FETCH_MODE_REFILL_MAX
            and GetText("quick_settings.quick_slots.fetch.mode.refill_max")
            or GetText("quick_settings.quick_slots.fetch.mode.missing"))
    end
end

local function SelectQuickSlotFetchMode(mode)
    QuickSettings.quickSlotFetchMode = NormalizeQuickSlotFetchMode(mode)
    QuickslotProfileFacade:SetFetchMode(QuickSettings.quickSlotFetchMode)
    RefreshQuickSlotFetchModeControls()
    QuickSettings:RefreshQuickSlots()
end

local function GetFoodCursorBagSlot()
    if type(GetCursorContentType) ~= "function" or GetCursorContentType() ~= MOUSE_CONTENT_INVENTORY_ITEM then
        return nil, nil
    end

    if type(GetCursorBagId) ~= "function" or type(GetCursorSlotIndex) ~= "function" then
        return nil, nil
    end

    return GetCursorBagId(), GetCursorSlotIndex()
end

local function ShouldRunQuickSlotFetchMonitor(state)
    return type(state) == "table"
        and state.windowVisible == true
        and state.quickSettingsActive == true
        and state.quickSlotsVisible == true
end

local function ShouldRefreshQuickSlotDisplay(state)
    return type(state) == "table"
        and (state.displayDirty == true
            or state.fetchBusy == true
            or state.bankOpen == true
            or state.fallbackReached == true)
end

local RefreshMenuSelection
local CreateMenuRow
local CreateQuickSlotsPanel
local CreateFoodHelperPanel
local CreateCraftingRecipePage
local CreateScribingRecipePanel
local SetFoodAutoEatEnabled
local HandleFoodHelperResult
local CreateFoodCardFromCursor
local SetActiveFoodCard
local HandleFoodCardClick
local CreateFoodCard
local RefreshFoodCard
local SetScribingAutoApplyEnabled
local CaptureScribingRecipe
local RegisterScribingRecipeFromDrop
local SetActiveScribingRecipe
local ApplyScribingRecipeToStation
local DeleteScribingRecipe
local CreateScribingRecipeCard
local RefreshScribingRecipeCard
local HandleQuickSlotFetchResult
local CreateQuickSlotCard
local RefreshQuickSlotFetchButton
local RefreshQuickSlotCard

RefreshMenuSelection = function(self)
    local selectedId = self.selectedMenuId

    for _, row in ipairs(self.menuRows or {}) do
        local selected = row.menuId == selectedId
        if selected then
            row.background:SetCenterColor(0.14, 0.23, 0.32, 0.97)
            row.background:SetEdgeColor(0.76, 0.86, 0.95, 1.0)
            row.label:SetColor(1.0, 1.0, 1.0, 1.0)
        else
            row.background:SetCenterColor(0.08, 0.08, 0.10, 0.94)
            row.background:SetEdgeColor(0.30, 0.32, 0.36, 1.0)
            row.label:SetColor(0.90, 0.90, 0.94, 1.0)
        end
    end
end

SetSelectedMenu = function(self, menuId)
    local previousMenuId = self.selectedMenuId
    local selectedEntry = nil
    for _, entry in ipairs(MENU_ENTRIES) do
        if entry.id == menuId then
            selectedEntry = entry
            break
        end
    end

    if selectedEntry == nil then
        selectedEntry = MENU_ENTRIES[1]
    end

    if selectedEntry == nil then
        return
    end

    self.selectedMenuId = selectedEntry.id
    if IsRecipeMenuId(previousMenuId) and previousMenuId ~= selectedEntry.id then
        self:StopRecipeShortRefresh()
    end
    SetLabelText(self.contentTitleLabel, GetText(selectedEntry.textKey))
    RefreshMenuSelection(self)

    if self.quickSlotsPanel then
        self.quickSlotsPanel:SetHidden(selectedEntry.id ~= "quick_slots")
    end
    if self.quickSlotsHeader then
        self.quickSlotsHeader:SetHidden(selectedEntry.id ~= "quick_slots")
    end
    if self.quickSlotSaveButton then
        self.quickSlotSaveButton:SetHidden(selectedEntry.id ~= "quick_slots")
    end
    if self.foodHelperPanel then
        self.foodHelperPanel:SetHidden(selectedEntry.id ~= "food_helper")
    end
    if self.foodHelperHeader then
        self.foodHelperHeader:SetHidden(selectedEntry.id ~= "food_helper")
    end
    for _, descriptor in ipairs(RECIPE_DESCRIPTORS) do
        local panel = self[descriptor.panelField]
        if panel then
            panel:SetHidden(selectedEntry.id ~= descriptor.menuId)
        end
        local header = self[descriptor.headerField]
        if header then
            header:SetHidden(selectedEntry.id ~= descriptor.menuId)
        end
    end
    self:HideQuickSlotSettingsMenu()
    if selectedEntry.id == "quick_slots" then
        self:RefreshQuickSlots()
    elseif selectedEntry.id == "food_helper" then
        self:RefreshFoodHelper()
    else
        RefreshRecipePage(self, selectedEntry.id)
    end
end

CreateMenuRow = function(self, parent, entry, index)
    local row = WINDOW_MANAGER:CreateControl(parent:GetName() .. "Row" .. tostring(index), parent, CT_CONTROL)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, parent, TOPLEFT, QUICK_SETTINGS_PANEL_PADDING, QUICK_SETTINGS_PANEL_PADDING + ((index - 1) * (QUICK_SETTINGS_MENU_ROW_HEIGHT + QUICK_SETTINGS_MENU_ROW_GAP)))
    row:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -QUICK_SETTINGS_PANEL_PADDING, QUICK_SETTINGS_PANEL_PADDING + ((index - 1) * (QUICK_SETTINGS_MENU_ROW_HEIGHT + QUICK_SETTINGS_MENU_ROW_GAP)))
    row:SetHeight(QUICK_SETTINGS_MENU_ROW_HEIGHT)
    row:SetMouseEnabled(true)
    row.menuId = entry.id
    SetControlDrawOrder(row, DT_HIGH, DL_CONTROLS, 2)

    local background = WINDOW_MANAGER:CreateControl("$(parent)Background", row, CT_BACKDROP)
    background:ClearAnchors()
    background:SetAnchorFill(row)
    SetControlDrawOrder(background, DT_HIGH, DL_CONTROLS, 2)
    row.background = background

    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", row, CT_LABEL)
    label:ClearAnchors()
    label:SetAnchor(LEFT, row, LEFT, 10, 0)
    label:SetAnchor(RIGHT, row, RIGHT, -10, 0)
    label:SetFont("ZoFontGame")
    label:SetText(GetText(entry.textKey))
    if type(label.SetVerticalAlignment) == "function" then
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    SetControlDrawOrder(label, DT_HIGH, DL_CONTROLS, 3)
    row.label = label

    if type(label.SetMouseEnabled) == "function" then
        label:SetMouseEnabled(false)
    end

    row:SetHandler("OnMouseUp", function(_, upInside)
        if upInside then
            SetSelectedMenu(QuickSettings, entry.id)
        end
    end)

    return row
end

function QuickSettings:CreateContent(parent)
    if self.root then
        return
    end

    local root = WINDOW_MANAGER:CreateControl("$(parent)Root", parent, CT_CONTROL)
    root:ClearAnchors()
    root:SetAnchorFill(parent)
    root:SetHandler("OnEffectivelyHidden", function()
        self:StopRecipeShortRefresh()
    end)
    root:SetHandler("OnEffectivelyShown", function()
        if self.selectedMenuId == "quick_slots" then
            self:RefreshQuickSlots()
        else
            RefreshRecipePage(self, self.selectedMenuId)
        end
    end)
    self.root = root

    local leftPane = CreateBackdrop(root, "LTM_QS_LeftPane", 0.07, 0.08, 0.09, 0.94, 0.28, 0.30, 0.34, 1.0)
    leftPane:ClearAnchors()
    leftPane:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
    leftPane:SetAnchor(BOTTOMLEFT, root, BOTTOMLEFT, 0, 0)
    leftPane:SetWidth(QUICK_SETTINGS_LEFT_PANE_WIDTH)
    self.leftPane = leftPane

    local rightPane = CreateBackdrop(root, "LTM_QS_RightPane", 0.07, 0.08, 0.09, 0.94, 0.28, 0.30, 0.34, 1.0)
    rightPane:ClearAnchors()
    rightPane:SetAnchor(TOPLEFT, leftPane, TOPRIGHT, QUICK_SETTINGS_PANE_GAP, 0)
    rightPane:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, 0, 0)
    self.rightPane = rightPane

    local contentTitleLabel = WINDOW_MANAGER:CreateControl("$(parent)ContentTitle", rightPane, CT_LABEL)
    contentTitleLabel:ClearAnchors()
    contentTitleLabel:SetAnchor(TOPLEFT, rightPane, TOPLEFT, QUICK_SETTINGS_PANEL_PADDING, QUICK_SETTINGS_PANEL_PADDING)
    contentTitleLabel:SetAnchor(TOPRIGHT, rightPane, TOPRIGHT, -(QUICK_SETTINGS_PANEL_PADDING + 210), QUICK_SETTINGS_PANEL_PADDING)
    contentTitleLabel:SetHeight(32)
    contentTitleLabel:SetFont("ZoFontWinH2")
    contentTitleLabel:SetColor(1.0, 1.0, 1.0, 1.0)
    self.contentTitleLabel = contentTitleLabel

    CreateQuickSlotsPanel(self, rightPane, contentTitleLabel)
    CreateFoodHelperPanel(self, rightPane, contentTitleLabel)
    CreateCraftingRecipePage(self, rightPane, contentTitleLabel, RECIPE_DESCRIPTOR_BY_MENU_ID.alchemy_recipe)
    CreateCraftingRecipePage(self, rightPane, contentTitleLabel, RECIPE_DESCRIPTOR_BY_MENU_ID.enchant_recipe)
    CreateScribingRecipePanel(self, rightPane, contentTitleLabel)

    self.menuRows = {}
    for index, entry in ipairs(MENU_ENTRIES) do
        self.menuRows[#self.menuRows + 1] = CreateMenuRow(self, leftPane, entry, index)
    end

    SetControlDrawOrder(leftPane, DT_HIGH, DL_CONTROLS, 1)
    SetControlDrawOrder(rightPane, DT_HIGH, DL_CONTROLS, 1)
    SetSelectedMenu(self, MENU_ENTRIES[1] and MENU_ENTRIES[1].id or nil)
    RegisterRecipeRefreshEvents(self)
    RegisterQuickSlotRefreshEvents(self)
    self:StartQuickSlotFetchMonitor()
end

CreateQuickSlotsPanel = function(self, parent, titleLabel)
    local header = WINDOW_MANAGER:CreateControl("$(parent)QuickSlotsHeader", parent, CT_CONTROL)
    header:ClearAnchors()
    header:SetAnchor(TOPLEFT, titleLabel, BOTTOMLEFT, 0, 8)
    header:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -QUICK_SETTINGS_PANEL_PADDING, 8)
    header:SetHeight(74)
    self.quickSlotsHeader = header

    local panel = WINDOW_MANAGER:CreateControl("$(parent)QuickSlotsPanel", parent, CT_CONTROL)
    panel:ClearAnchors()
    panel:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 0)
    panel:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, -QUICK_SETTINGS_PANEL_PADDING, -QUICK_SETTINGS_PANEL_PADDING)
    self.quickSlotsPanel = panel

    local saveButton = CreateButton(header, "$(parent)QuickSlotSaveCurrent", GetText("quick_settings.quick_slots.save_current"), 190, function()
        self:SaveCurrentQuickSlots()
    end)
    saveButton:ClearAnchors()
    saveButton:SetAnchor(TOPRIGHT, header, TOPRIGHT, 0, QUICK_SLOT_SAVE_BUTTON_TOP_OFFSET)
    SetControlDrawOrder(saveButton, DT_HIGH, DL_CONTROLS, 4)
    self.quickSlotSaveButton = saveButton
    self.quickSlotFetchMode = QuickslotProfileFacade:GetFetchMode()
    self.quickSlotFetchPreferLowCondition = QuickslotProfileFacade:GetFetchPreferLowCondition()

    local fetchModeRow = WINDOW_MANAGER:CreateControl("LTM_QSFetchModeRow", header, CT_CONTROL)
    fetchModeRow:ClearAnchors()
    fetchModeRow:SetAnchor(TOPLEFT, header, TOPLEFT, 0, QUICK_SLOT_FETCH_OPTIONS_TOP)
    fetchModeRow:SetWidth(QUICK_SLOT_FETCH_MODE_ROW_WIDTH)
    fetchModeRow:SetHeight(30)

    local fetchModeLabel = WINDOW_MANAGER:CreateControl("$(parent)Label", fetchModeRow, CT_LABEL)
    fetchModeLabel:ClearAnchors()
    fetchModeLabel:SetAnchor(LEFT, fetchModeRow, LEFT, 0, 0)
    fetchModeLabel:SetDimensions(54, 28)
    fetchModeLabel:SetFont("ZoFontGameSmall")
    fetchModeLabel:SetText(GetText("quick_settings.quick_slots.fetch.mode.label"))
    if type(fetchModeLabel.SetVerticalAlignment) == "function" then
        fetchModeLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end

    local dropdown = WINDOW_MANAGER:CreateControlFromVirtual("LTM_QSFetchModeDropdown", fetchModeRow, "ZO_ComboBox")
    dropdown:ClearAnchors()
    dropdown:SetAnchor(LEFT, fetchModeLabel, RIGHT, 4, 0)
    dropdown:SetDimensions(150, 28)
    SetTextTooltip(dropdown, GetText("quick_settings.quick_slots.fetch.mode.dropdown.tooltip"))
    SetControlDrawOrder(dropdown, DT_HIGH, DL_CONTROLS, 4)
    SetControlDrawOrder(dropdown:GetNamedChild("BG"), DT_HIGH, DL_CONTROLS, 5)
    SetControlDrawOrder(dropdown:GetNamedChild("SelectedItemText"), DT_HIGH, DL_CONTROLS, 6)
    SetControlDrawOrder(dropdown:GetNamedChild("OpenDropdown"), DT_HIGH, DL_CONTROLS, 6)

    local comboBox = ZO_ComboBox_ObjectFromContainer(dropdown)
    comboBox:SetSortsItems(false)
    comboBox:ClearItems()
    comboBox:AddItem(comboBox:CreateItemEntry(GetText("quick_settings.quick_slots.fetch.mode.missing"), function()
        SelectQuickSlotFetchMode(QUICK_SLOT_FETCH_MODE_MISSING)
    end))
    comboBox:AddItem(comboBox:CreateItemEntry(GetText("quick_settings.quick_slots.fetch.mode.refill_max"), function()
        SelectQuickSlotFetchMode(QUICK_SLOT_FETCH_MODE_REFILL_MAX)
    end))

    self.quickSlotFetchModeRow = fetchModeRow
    self.quickSlotFetchModeDropdown = dropdown
    self.quickSlotFetchModeComboBox = comboBox
    RefreshQuickSlotFetchModeControls()

    local fetchPreferenceRow = WINDOW_MANAGER:CreateControl("LTM_QSFetchPreferenceRow", header, CT_CONTROL)
    fetchPreferenceRow:ClearAnchors()
    fetchPreferenceRow:SetAnchor(TOPLEFT, header, TOPLEFT, QUICK_SLOT_FETCH_PREFERENCE_LEFT, QUICK_SLOT_FETCH_OPTIONS_TOP)
    fetchPreferenceRow:SetAnchor(TOPRIGHT, header, TOPRIGHT, 0, QUICK_SLOT_FETCH_OPTIONS_TOP)
    fetchPreferenceRow:SetHeight(36)

    local fetchPreferenceCheckbox = WINDOW_MANAGER:CreateControlFromVirtual("LTM_QSFetchPreference", fetchPreferenceRow, "ZO_CheckButton")
    fetchPreferenceCheckbox:ClearAnchors()
    fetchPreferenceCheckbox:SetAnchor(LEFT, fetchPreferenceRow, LEFT, 0, 0)
    if type(ZO_CheckButton_SetLabelText) == "function" then
        ZO_CheckButton_SetLabelText(fetchPreferenceCheckbox, GetText("quick_settings.quick_slots.fetch.prefer_low_condition"))
    end
    SetTextTooltip(fetchPreferenceCheckbox, GetText("quick_settings.quick_slots.fetch.prefer_low_condition.tooltip"))
    if type(ZO_CheckButton_SetCheckState) == "function" then
        ZO_CheckButton_SetCheckState(fetchPreferenceCheckbox, self.quickSlotFetchPreferLowCondition)
    end
    if type(ZO_CheckButton_SetToggleFunction) == "function" then
        ZO_CheckButton_SetToggleFunction(fetchPreferenceCheckbox, function(_, isChecked)
            QuickSettings.quickSlotFetchPreferLowCondition = isChecked == true
            QuickslotProfileFacade:SetFetchPreferLowCondition(isChecked == true)
        end)
    end
    local fetchPreferenceLabel = fetchPreferenceCheckbox.GetNamedChild
        and (fetchPreferenceCheckbox:GetNamedChild("Label") or fetchPreferenceCheckbox:GetNamedChild("Text"))
        or nil
    if fetchPreferenceLabel then
        fetchPreferenceLabel:ClearAnchors()
        fetchPreferenceLabel:SetAnchor(LEFT, fetchPreferenceCheckbox, RIGHT, 6, 0)
        fetchPreferenceLabel:SetAnchor(RIGHT, fetchPreferenceRow, RIGHT, 0, 0)
        if type(fetchPreferenceLabel.SetMaxLineCount) == "function" then
            fetchPreferenceLabel:SetMaxLineCount(1)
        end
        if type(fetchPreferenceLabel.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
            fetchPreferenceLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        end
        if type(fetchPreferenceLabel.SetVerticalAlignment) == "function" then
            fetchPreferenceLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        end
    end
    SetControlDrawOrder(fetchPreferenceCheckbox, DT_HIGH, DL_CONTROLS, 4)
    self.quickSlotFetchPreferenceRow = fetchPreferenceRow
    self.quickSlotFetchPreferenceCheckbox = fetchPreferenceCheckbox

    local emptyLabel = WINDOW_MANAGER:CreateControl("$(parent)EmptyLabel", panel, CT_LABEL)
    emptyLabel:ClearAnchors()
    emptyLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
    emptyLabel:SetAnchor(TOPRIGHT, panel, TOPRIGHT, 0, 0)
    emptyLabel:SetHeight(28)
    emptyLabel:SetFont("ZoFontGame")
    emptyLabel:SetColor(0.82, 0.84, 0.88, 1.0)
    emptyLabel:SetText(GetText("quick_settings.quick_slots.empty"))
    self.quickSlotEmptyLabel = emptyLabel

    self.quickSlotListScroll = CreateCardListScrollContainer(panel, 0, QUICK_SLOT_SCROLLBAR_CONTENT_GAP)
    self.quickSlotListRoot = self.quickSlotListScroll.scrollChild
    self.quickSlotCards = {}
    self.quickSlotLayoutSignature = nil
end

CreateFoodHelperPanel = function(self, parent, titleLabel)
    local header = WINDOW_MANAGER:CreateControl("$(parent)FoodHelperHeader", parent, CT_CONTROL)
    header:ClearAnchors()
    header:SetAnchor(TOPLEFT, titleLabel, TOPLEFT, 0, 0)
    header:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -QUICK_SETTINGS_PANEL_PADDING, QUICK_SETTINGS_PANEL_PADDING)
    header:SetHeight(FOOD_PANEL_HEADER_HEIGHT)
    header:SetHidden(true)
    SetControlDrawOrder(header, DT_HIGH, DL_CONTROLS, 4)
    self.foodHelperHeader = header

    local panel = WINDOW_MANAGER:CreateControl("$(parent)FoodHelperPanel", parent, CT_CONTROL)
    panel:ClearAnchors()
    panel:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 8)
    panel:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, -QUICK_SETTINGS_PANEL_PADDING, -QUICK_SETTINGS_PANEL_PADDING)
    panel:SetMouseEnabled(true)
    panel:SetHidden(true)
    SetControlDrawOrder(panel, DT_HIGH, DL_CONTROLS, 4)
    panel:SetHandler("OnReceiveDrag", function()
        CreateFoodCardFromCursor(QuickSettings)
    end)
    panel:SetHandler("OnMouseUp", function(_, _, upInside)
        if upInside then
            CreateFoodCardFromCursor(QuickSettings)
        end
    end)
    self.foodHelperPanel = panel

    local autoEatCheckbox = WINDOW_MANAGER:CreateControlFromVirtual("LTM_FoodAutoEat", header, "ZO_CheckButton")
    autoEatCheckbox:ClearAnchors()
    autoEatCheckbox:SetAnchor(TOPLEFT, header, TOPLEFT, 0, FOOD_PANEL_TITLE_HEIGHT + FOOD_PANEL_HEADER_TITLE_GAP)
    autoEatCheckbox:SetDimensions(FOOD_AUTO_EAT_CHECKBOX_SIZE, FOOD_AUTO_EAT_CHECKBOX_SIZE)
    if type(ZO_CheckButton_SetLabelText) == "function" then
        ZO_CheckButton_SetLabelText(autoEatCheckbox, "")
    end
    SetTextTooltip(autoEatCheckbox, GetText("quick_settings.food_helper.auto_eat.tooltip"))
    if type(ZO_CheckButton_SetToggleFunction) == "function" then
        ZO_CheckButton_SetToggleFunction(autoEatCheckbox, function(_, isChecked)
            SetFoodAutoEatEnabled(QuickSettings, isChecked == true)
        end)
    end
    SetControlDrawOrder(autoEatCheckbox, DT_HIGH, DL_CONTROLS, 4)
    self.foodAutoEatCheckbox = autoEatCheckbox

    local autoEatTextLabel = WINDOW_MANAGER:CreateControl("$(parent)AutoEatLabel", header, CT_LABEL)
    autoEatTextLabel:ClearAnchors()
    autoEatTextLabel:SetAnchor(LEFT, autoEatCheckbox, RIGHT, 6, FOOD_AUTO_EAT_LABEL_OFFSET_Y)
    autoEatTextLabel:SetAnchor(RIGHT, header, RIGHT, 0, FOOD_AUTO_EAT_LABEL_OFFSET_Y)
    autoEatTextLabel:SetHeight(FOOD_AUTO_EAT_CHECKBOX_SIZE)
    autoEatTextLabel:SetFont("ZoFontGame")
    autoEatTextLabel:SetColor(0.96, 0.94, 0.84, 1.0)
    autoEatTextLabel:SetText(GetText("quick_settings.food_helper.auto_eat"))
    autoEatTextLabel:SetMouseEnabled(true)
    SetTextTooltip(autoEatTextLabel, GetText("quick_settings.food_helper.auto_eat.tooltip"))
    if type(autoEatTextLabel.SetVerticalAlignment) == "function" then
        autoEatTextLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    SetControlDrawOrder(autoEatTextLabel, DT_HIGH, DL_CONTROLS, 4)
    self.foodAutoEatLabel = autoEatTextLabel

    local emptyLabel = WINDOW_MANAGER:CreateControl("$(parent)EmptyLabel", panel, CT_LABEL)
    emptyLabel:ClearAnchors()
    emptyLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
    emptyLabel:SetAnchor(TOPRIGHT, panel, TOPRIGHT, 0, 0)
    emptyLabel:SetHeight(34)
    emptyLabel:SetFont("ZoFontGame")
    emptyLabel:SetColor(0.82, 0.84, 0.88, 1.0)
    emptyLabel:SetText(GetText("quick_settings.food_helper.empty"))
    self.foodEmptyLabel = emptyLabel

    local gridRoot = WINDOW_MANAGER:CreateControl("$(parent)Grid", panel, CT_CONTROL)
    gridRoot:ClearAnchors()
    gridRoot:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
    gridRoot:SetAnchor(TOPRIGHT, panel, TOPRIGHT, 0, 0)
    gridRoot:SetHeight(FOOD_CARD_SIZE)
    gridRoot:SetMouseEnabled(false)
    SetControlDrawOrder(gridRoot, DT_HIGH, DL_CONTROLS, 5)
    self.foodGridRoot = gridRoot
    self.foodCards = {}
end

SetFoodAutoEatEnabled = function(self, enabled)
    QuickslotProfileFacade:SetFoodAutoEatEnabled(enabled == true)
    self:RefreshFoodHelper()
end

HandleFoodHelperResult = function(self, card, err, successKey)
    if type(card) == "table" then
        WriteChat(GetText(successKey, { itemName = card.itemLink or card.name or tostring(card.itemId) }))
        self:RefreshFoodHelper()
        return true
    end

    WriteChat(GetText("quick_settings.food_helper.warning.invalid", {
        reason = Log.LocalizeErrorReason(err),
    }))
    return false
end

CreateFoodCardFromCursor = function(self)
    local bagId, slotIndex = GetFoodCursorBagSlot()
    if bagId == nil or slotIndex == nil then
        return false
    end

    local card, err = QuickslotProfileFacade:CreateFoodCardFromBagSlot(bagId, slotIndex)

    local handled = HandleFoodHelperResult(self, card, err, "quick_settings.food_helper.registered")
    if handled and type(ClearCursor) == "function" then
        ClearCursor()
    end
    return handled
end

function QuickSettings:ReplaceFoodCardFromCursor(card)
    if type(card) ~= "table" then
        return false
    end

    local cardId = type(card.foodCard) == "table" and card.foodCard.id or card.ltmFoodCardId
    if type(cardId) ~= "string" or cardId == "" then
        return false
    end

    local bagId, slotIndex = GetFoodCursorBagSlot()
    if bagId == nil or slotIndex == nil then
        return false
    end

    local updatedCard, err = QuickslotProfileFacade:ReplaceFoodCardFromBagSlot(cardId, bagId, slotIndex)

    local handled = HandleFoodHelperResult(self, updatedCard, err, "quick_settings.food_helper.replaced")
    if handled and type(ClearCursor) == "function" then
        ClearCursor()
    end
    return handled
end

SetActiveFoodCard = function(self, cardId)
    QuickslotProfileFacade:SetActiveFoodCard(cardId)
    self:RefreshFoodHelper()
end

function QuickSettings:DeleteFoodCard(cardId)
    local deleted = QuickslotProfileFacade:DeleteFoodCard(cardId)
    if deleted == true then
        self:RefreshFoodHelper()
        return true
    end

    return false
end

HandleFoodCardClick = function(self, cardId, upInside, card)
    if upInside == false or type(cardId) ~= "string" or cardId == "" then
        return false
    end

    local bagId, slotIndex = GetFoodCursorBagSlot()
    if bagId ~= nil and slotIndex ~= nil then
        return self:ReplaceFoodCardFromCursor(card)
    end

    SetActiveFoodCard(self, cardId)
    return true
end

CreateFoodCard = function(self, parent, index)
    local namePrefix = "LTM_FoodCard" .. tostring(index)
    local card = CreateBackdrop(parent, namePrefix, 0.08, 0.09, 0.10, 0.96, 0.28, 0.30, 0.34, 1.0)
    card:ClearAnchors()
    card:SetDimensions(FOOD_CARD_SIZE, FOOD_CARD_SIZE)
    card:SetMouseEnabled(true)
    SetControlDrawOrder(card, DT_HIGH, DL_CONTROLS, 8)
    card:SetHandler("OnReceiveDrag", function(selfControl)
        QuickSettings:ReplaceFoodCardFromCursor(selfControl)
    end)
    card:SetHandler("OnMouseUp", function(selfControl, _, upInside)
        HandleFoodCardClick(QuickSettings, selfControl.ltmFoodCardId, upInside, selfControl)
    end)
    SetTextTooltip(card, GetText("quick_settings.food_helper.active.tooltip"))

    local activeCheckbox = WINDOW_MANAGER:CreateControlFromVirtual(namePrefix .. "Active", card, "ZO_CheckButton")
    activeCheckbox:ClearAnchors()
    activeCheckbox:SetAnchor(TOPLEFT, card, TOPLEFT, 5, 5)
    if type(ZO_CheckButton_SetLabelText) == "function" then
        ZO_CheckButton_SetLabelText(activeCheckbox, "")
    end
    if type(ZO_CheckButton_SetToggleFunction) == "function" then
        ZO_CheckButton_SetToggleFunction(activeCheckbox, function()
            if type(activeCheckbox.ltmFoodCardId) == "string" then
                SetActiveFoodCard(QuickSettings, activeCheckbox.ltmFoodCardId)
            end
        end)
    end
    SetTextTooltip(activeCheckbox, GetText("quick_settings.food_helper.active.tooltip"))
    SetControlDrawOrder(activeCheckbox, DT_HIGH, DL_CONTROLS, 11)
    card.activeCheckbox = activeCheckbox

    local deleteButton = CreateIconButton(
        card,
        namePrefix .. "Delete",
        FOOD_CARD_DELETE_BUTTON_SIZE,
        "/esoui/art/buttons/decline",
        GetText("common.delete"),
        function(selfControl)
            QuickSettings:DeleteFoodCard(selfControl.ltmFoodCardId)
        end
    )
    deleteButton:ClearAnchors()
    deleteButton:SetAnchor(TOPRIGHT, card, TOPRIGHT, -4, 4)
    SetControlDrawOrder(deleteButton, DT_HIGH, DL_CONTROLS, 12)
    card.deleteButton = deleteButton

    local iconBox = CreateBackdrop(card, namePrefix .. "IconBox", 0.03, 0.03, 0.035, 0.98, 0.24, 0.24, 0.26, 1.0)
    iconBox:ClearAnchors()
    iconBox:SetAnchor(TOP, card, TOP, 0, FOOD_CARD_ICON_TOP)
    iconBox:SetDimensions(FOOD_CARD_ICON_SIZE, FOOD_CARD_ICON_SIZE)
    iconBox:SetMouseEnabled(true)
    iconBox:SetHandler("OnReceiveDrag", function()
        QuickSettings:ReplaceFoodCardFromCursor(card)
    end)
    iconBox:SetHandler("OnMouseUp", function(selfControl, _, upInside)
        HandleFoodCardClick(QuickSettings, selfControl.ltmFoodCardId, upInside, card)
    end)
    SetControlDrawOrder(iconBox, DT_HIGH, DL_CONTROLS, 9)
    card.iconBox = iconBox

    local texture = WINDOW_MANAGER:CreateControl(namePrefix .. "Icon", iconBox, CT_TEXTURE)
    texture:ClearAnchors()
    texture:SetAnchor(TOPLEFT, iconBox, TOPLEFT, 2, 2)
    texture:SetAnchor(BOTTOMRIGHT, iconBox, BOTTOMRIGHT, -2, -2)
    SetControlDrawOrder(texture, DT_HIGH, DL_CONTROLS, 10)
    iconBox.texture = texture

    local count = WINDOW_MANAGER:CreateControl(namePrefix .. "Count", iconBox, CT_LABEL)
    count:ClearAnchors()
    count:SetAnchor(BOTTOMRIGHT, iconBox, BOTTOMRIGHT, -2, -1)
    count:SetDimensions(36, 16)
    count:SetFont("ZoFontGameSmall")
    count:SetColor(1.0, 1.0, 1.0, 1.0)
    if type(count.SetHorizontalAlignment) == "function" then
        count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    end
    SetControlDrawOrder(count, DT_HIGH, DL_CONTROLS, 11)
    iconBox.count = count

    local label = WINDOW_MANAGER:CreateControl(namePrefix .. "Name", card, CT_LABEL)
    label:ClearAnchors()
    label:SetAnchor(TOPLEFT, iconBox, BOTTOMLEFT, -26, FOOD_CARD_LABEL_TOP_GAP)
    label:SetAnchor(TOPRIGHT, iconBox, BOTTOMRIGHT, 26, FOOD_CARD_LABEL_TOP_GAP)
    label:SetHeight(32)
    label:SetFont("ZoFontGameSmall")
    label:SetColor(0.90, 0.92, 0.96, 1.0)
    label:SetMouseEnabled(true)
    label:SetHandler("OnReceiveDrag", function()
        QuickSettings:ReplaceFoodCardFromCursor(card)
    end)
    label:SetHandler("OnMouseUp", function(selfControl, _, upInside)
        HandleFoodCardClick(QuickSettings, selfControl.ltmFoodCardId, upInside, card)
    end)
    SetTextTooltip(label, GetText("quick_settings.food_helper.active.tooltip"))
    if type(label.SetHorizontalAlignment) == "function" then
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end
    if type(label.SetVerticalAlignment) == "function" then
        label:SetVerticalAlignment(TEXT_ALIGN_TOP)
    end
    if type(label.SetMaxLineCount) == "function" then
        label:SetMaxLineCount(2)
    end
    if type(label.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    SetControlDrawOrder(label, DT_HIGH, DL_CONTROLS, 11)
    card.label = label

    return card
end

RefreshFoodCard = function(self, card, foodCard)
    card.foodCard = foodCard
    local cardId = type(foodCard) == "table" and foodCard.id or nil
    card.ltmFoodCardId = cardId
    card.activeCheckbox.ltmFoodCardId = cardId
    card.deleteButton.ltmFoodCardId = cardId
    card.iconBox.ltmFoodCardId = cardId
    card.label.ltmFoodCardId = cardId
    local active = type(foodCard) == "table" and foodCard.isActive == true
    if type(ZO_CheckButton_SetCheckState) == "function" then
        ZO_CheckButton_SetCheckState(card.activeCheckbox, active)
    end

    card:SetEdgeColor(active and 0.76 or 0.28, active and 0.86 or 0.30, active and 0.95 or 0.34, 1.0)

    local icon = type(foodCard.icon) == "string" and foodCard.icon ~= "" and foodCard.icon or FOOD_EMPTY_ICON_TEXTURE
    card.iconBox.texture:SetTexture(icon)
    card.iconBox.count:SetText(tostring(tonumber(foodCard.backpackCount) or 0))
    SetLabelText(card.label, foodCard.name or foodCard.itemLink or tostring(foodCard.itemId or ""))
    SetItemTooltip(card.iconBox, foodCard.itemLink, foodCard.name)
end

function QuickSettings:RefreshFoodHelper()
    if not self.foodHelperPanel then
        return
    end

    local autoEatEnabled = QuickslotProfileFacade:GetFoodAutoEatEnabled() == true
    if type(ZO_CheckButton_SetCheckState) == "function" and self.foodAutoEatCheckbox then
        ZO_CheckButton_SetCheckState(self.foodAutoEatCheckbox, autoEatEnabled)
    end

    local cards = QuickslotProfileFacade:GetFoodCardList()

    self.foodEmptyLabel:SetHidden(#cards > 0)
    self.foodCards = self.foodCards or {}

    local panelWidth = self.foodHelperPanel.GetWidth and self.foodHelperPanel:GetWidth() or 0
    local columns = math.max(1, math.floor(((panelWidth > 0 and panelWidth or ((FOOD_CARD_SIZE * FOOD_CARD_DEFAULT_COLUMNS) + (FOOD_CARD_GAP * (FOOD_CARD_DEFAULT_COLUMNS - 1)))) + FOOD_CARD_GAP) / (FOOD_CARD_SIZE + FOOD_CARD_GAP)))
    local rows = math.max(1, math.ceil(#cards / columns))
    if self.foodGridRoot and type(self.foodGridRoot.SetHeight) == "function" then
        self.foodGridRoot:SetHeight((rows * FOOD_CARD_SIZE) + ((rows - 1) * FOOD_CARD_GAP))
    end

    for index, foodCard in ipairs(cards) do
        local card = self.foodCards[index]
        if card == nil then
            card = CreateFoodCard(self, self.foodGridRoot, index)
            self.foodCards[index] = card
        end

        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        local left = column * (FOOD_CARD_SIZE + FOOD_CARD_GAP)
        local top = row * (FOOD_CARD_SIZE + FOOD_CARD_GAP)
        card:ClearAnchors()
        card:SetAnchor(TOPLEFT, self.foodGridRoot, TOPLEFT, left, top)
        card:SetHidden(false)
        RefreshFoodCard(self, card, foodCard)
    end

    for index = #cards + 1, #self.foodCards do
        self.foodCards[index]:SetHidden(true)
    end
end

CreateCraftingRecipePage = function(self, parent, titleLabel, descriptor)
    self.recipePages = self.recipePages or {}
    local previousPage = self.recipePages[descriptor.menuId]
    local page = { cardSerial = previousPage and previousPage.cardSerial or 0 }
    local header = WINDOW_MANAGER:CreateControl("$(parent)" .. descriptor.pageControlName .. "Header", parent, CT_CONTROL)
    header:ClearAnchors()
    header:SetAnchor(TOPLEFT, titleLabel, TOPLEFT, 0, 0)
    header:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -QUICK_SETTINGS_PANEL_PADDING, QUICK_SETTINGS_PANEL_PADDING)
    header:SetHeight(FOOD_PANEL_HEADER_HEIGHT)
    header:SetHidden(true)
    SetControlDrawOrder(header, DT_HIGH, DL_CONTROLS, 4)
    page.header = header
    self[descriptor.headerField] = header

    local panel = WINDOW_MANAGER:CreateControl("$(parent)" .. descriptor.pageControlName .. "Panel", parent, CT_CONTROL)
    panel:ClearAnchors()
    panel:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 8)
    panel:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, -QUICK_SETTINGS_PANEL_PADDING, -QUICK_SETTINGS_PANEL_PADDING)
    panel:SetMouseEnabled(true)
    panel:SetHidden(true)
    SetControlDrawOrder(panel, DT_HIGH, DL_CONTROLS, 4)
    page.panel = panel
    self[descriptor.panelField] = panel

    local autoApplyCheckbox = WINDOW_MANAGER:CreateControlFromVirtual("LTM_" .. descriptor.pageControlName .. "AutoApply", header, "ZO_CheckButton")
    autoApplyCheckbox:ClearAnchors()
    autoApplyCheckbox:SetAnchor(TOPLEFT, header, TOPLEFT, 0, FOOD_PANEL_TITLE_HEIGHT + FOOD_PANEL_HEADER_TITLE_GAP)
    autoApplyCheckbox:SetDimensions(ALCHEMY_RECIPE_ACTIVE_CHECKBOX_SIZE, ALCHEMY_RECIPE_ACTIVE_CHECKBOX_SIZE)
    if type(ZO_CheckButton_SetLabelText) == "function" then
        ZO_CheckButton_SetLabelText(autoApplyCheckbox, "")
    end
    SetTextTooltip(autoApplyCheckbox, GetText("quick_settings." .. descriptor.menuId .. ".auto_apply.tooltip"))
    if type(ZO_CheckButton_SetToggleFunction) == "function" then
        ZO_CheckButton_SetToggleFunction(autoApplyCheckbox, function(_, isChecked)
            descriptor.recipeModule:SetAutoApplyEnabled(isChecked == true)
            RefreshRecipePage(QuickSettings, descriptor.menuId)
        end)
    end
    SetControlDrawOrder(autoApplyCheckbox, DT_HIGH, DL_CONTROLS, 4)
    page.autoApplyCheckbox = autoApplyCheckbox

    local autoApplyLabel = WINDOW_MANAGER:CreateControl("$(parent)AutoApplyLabel", header, CT_LABEL)
    autoApplyLabel:ClearAnchors()
    autoApplyLabel:SetAnchor(LEFT, autoApplyCheckbox, RIGHT, 6, FOOD_AUTO_EAT_LABEL_OFFSET_Y)
    autoApplyLabel:SetAnchor(RIGHT, header, RIGHT, -210, FOOD_AUTO_EAT_LABEL_OFFSET_Y)
    autoApplyLabel:SetHeight(ALCHEMY_RECIPE_ACTIVE_CHECKBOX_SIZE)
    autoApplyLabel:SetFont("ZoFontGame")
    autoApplyLabel:SetColor(0.96, 0.94, 0.84, 1.0)
    autoApplyLabel:SetText(GetText("quick_settings." .. descriptor.menuId .. ".auto_apply"))
    autoApplyLabel:SetMouseEnabled(true)
    SetTextTooltip(autoApplyLabel, GetText("quick_settings." .. descriptor.menuId .. ".auto_apply.tooltip"))
    if type(autoApplyLabel.SetVerticalAlignment) == "function" then
        autoApplyLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    SetControlDrawOrder(autoApplyLabel, DT_HIGH, DL_CONTROLS, 4)
    page.autoApplyLabel = autoApplyLabel

    local captureButton = CreateButton(header, "$(parent)Capture" .. descriptor.pageControlName, GetText("quick_settings." .. descriptor.menuId .. ".capture"), 190, function()
        local recipe, err = descriptor.recipeModule:CaptureFromStation()
        HandleRecipeResult(self, descriptor, "saved", recipe, err)
    end)
    captureButton:ClearAnchors()
    captureButton:SetAnchor(TOPRIGHT, header, TOPRIGHT, 0, 0)
    SetTextTooltip(captureButton, GetText("quick_settings." .. descriptor.menuId .. ".capture.tooltip"))
    SetControlDrawOrder(captureButton, DT_HIGH, DL_CONTROLS, 4)
    page.captureButton = captureButton

    local emptyLabel = WINDOW_MANAGER:CreateControl("$(parent)EmptyLabel", panel, CT_LABEL)
    emptyLabel:ClearAnchors()
    emptyLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
    emptyLabel:SetAnchor(TOPRIGHT, panel, TOPRIGHT, 0, 0)
    emptyLabel:SetHeight(34)
    emptyLabel:SetFont("ZoFontGame")
    emptyLabel:SetColor(0.82, 0.84, 0.88, 1.0)
    emptyLabel:SetText(GetText("quick_settings." .. descriptor.menuId .. ".empty"))
    page.emptyLabel = emptyLabel

    page.scroll = CreateCardListScrollContainer(panel, 0, 0)
    page.listRoot = page.scroll.scrollChild
    page.cards = {}
    self.recipePages[descriptor.menuId] = page
end

local function GetAlchemyRecipeErrorText(err)
    if err == "station_not_open" then
        return GetText("quick_settings.alchemy_recipe.warning.station_not_open")
    end
    if err == "solvent_not_set" or err == "reagents_insufficient" then
        return GetText("quick_settings.alchemy_recipe.warning.slots_not_set")
    end
    return GetText("quick_settings.alchemy_recipe.warning.invalid", {
        reason = Log.LocalizeErrorReason(err),
    })
end

RECIPE_DESCRIPTOR_BY_MENU_ID.alchemy_recipe.errorText = GetAlchemyRecipeErrorText

local function SetCraftingRecipeCount(self, descriptor, recipeId, count)
    local recipe, err = descriptor.recipeModule:SetRecipeCraftCount(recipeId, count)
    if type(recipe) == "table" then
        RefreshRecipePage(self, descriptor.menuId)
        return true
    end
    WriteChat(descriptor.errorText(err))
    RefreshRecipePage(self, descriptor.menuId)
    return false
end

local function BeginCraftingRecipeCountEdit(card)
    if card == nil then
        return
    end
    card.craftCountEditing = true
    card.countLabel:SetHidden(true)
    card.craftCountEditButton:SetHidden(true)
    card.craftCountEdit:SetHidden(false)
    card.craftCountSaveButton:SetHidden(false)
    card.craftCountCancelButton:SetHidden(false)
    card.reagentRow:SetHidden(true)
    card.craftCountEdit:SetText(tostring(card.ltmCraftCount or 1))
    if type(card.craftCountEdit.TakeFocus) == "function" then
        card.craftCountEdit:TakeFocus()
    end
end

local function CancelCraftingRecipeCountEdit(card)
    if card == nil then
        return
    end
    card.craftCountEditing = false
    card.countLabel:SetHidden(false)
    card.craftCountEditButton:SetHidden(false)
    card.craftCountEdit:SetHidden(true)
    card.craftCountSaveButton:SetHidden(true)
    card.craftCountCancelButton:SetHidden(true)
    card.reagentRow:SetHidden(false)
end

local function CommitCraftingRecipeCount(self, descriptor, card)
    if card == nil or card.ltmRecipeId == nil or card.craftCountEdit == nil then
        return false
    end
    local text = type(card.craftCountEdit.GetText) == "function" and card.craftCountEdit:GetText() or ""
    local count = math.max(math.floor(tonumber(text) or 1), 1)
    if type(card.craftCountEdit.SetText) == "function" then
        card.craftCountEdit:SetText(tostring(count))
    end
    card.craftCountEditing = false
    local ok = SetCraftingRecipeCount(self, descriptor, card.ltmRecipeId, count)
    if ok == true then
        CancelCraftingRecipeCountEdit(card)
    end
    return ok
end

local function ApplyCraftingRecipeCard(self, descriptor, recipeId)
    local ok, result = descriptor.recipeModule:ApplyRecipeToStation(recipeId)
    return HandleRecipeResult(self, descriptor, "applied", ok, result, recipeId)
end

local function CreateCraftingRecipeCard(self, parent, index, descriptor, page)
    page.cardSerial = page.cardSerial + 1
    local namePrefix = descriptor.cardControlPrefix .. tostring(index) .. "_" .. tostring(page.cardSerial)
    local card = CreateBackdrop(parent, namePrefix, 0.08, 0.09, 0.10, 0.96, 0.28, 0.30, 0.34, 1.0)
    card:ClearAnchors()
    card:SetHeight(ALCHEMY_RECIPE_CARD_HEIGHT)
    card:SetMouseEnabled(true)
    card:SetHandler("OnMouseUp", function(selfControl, _, upInside)
        if upInside and selfControl.craftCountEditing ~= true then
            ApplyCraftingRecipeCard(QuickSettings, descriptor, selfControl.ltmRecipeId)
        end
    end)
    SetControlDrawOrder(card, DT_HIGH, DL_CONTROLS, 8)

    local activeCheckbox = WINDOW_MANAGER:CreateControlFromVirtual(namePrefix .. "Active", card, "ZO_CheckButton")
    activeCheckbox:ClearAnchors()
    activeCheckbox:SetAnchor(TOPLEFT, card, TOPLEFT, 8, 8)
    activeCheckbox:SetDimensions(ALCHEMY_RECIPE_ACTIVE_CHECKBOX_SIZE, ALCHEMY_RECIPE_ACTIVE_CHECKBOX_SIZE)
    if type(ZO_CheckButton_SetLabelText) == "function" then
        ZO_CheckButton_SetLabelText(activeCheckbox, "")
    end
    if type(ZO_CheckButton_SetToggleFunction) == "function" then
        ZO_CheckButton_SetToggleFunction(activeCheckbox, function(_, isChecked)
            if isChecked == true and type(activeCheckbox.ltmRecipeId) == "string" then
                local recipe, err = descriptor.recipeModule:SetActiveRecipe(activeCheckbox.ltmRecipeId)
                HandleRecipeResult(QuickSettings, descriptor, "active_set", recipe, err)
            else
                RefreshRecipePage(QuickSettings, descriptor.menuId)
            end
        end)
    end
    SetTextTooltip(activeCheckbox, GetText("quick_settings." .. descriptor.menuId .. ".active.tooltip"))
    SetControlDrawOrder(activeCheckbox, DT_HIGH, DL_CONTROLS, 11)
    card.activeCheckbox = activeCheckbox

    local activeLabel = WINDOW_MANAGER:CreateControl(namePrefix .. "ActiveStatus", card, CT_LABEL)
    activeLabel:ClearAnchors()
    activeLabel:SetAnchor(LEFT, activeCheckbox, RIGHT, 5, 0)
    activeLabel:SetDimensions(1, 20)
    activeLabel:SetFont("ZoFontGameSmall")
    activeLabel:SetColor(0.86, 0.92, 1.0, 1.0)
    activeLabel:SetText("")
    activeLabel:SetHidden(true)
    SetControlDrawOrder(activeLabel, DT_HIGH, DL_CONTROLS, 11)
    card.activeLabel = activeLabel

    local resultIconBox = CreateBackdrop(card, namePrefix .. "ResultIconBox", 0.03, 0.03, 0.035, 0.98, 0.24, 0.24, 0.26, 1.0)
    resultIconBox:ClearAnchors()
    resultIconBox:SetAnchor(TOPLEFT, card, TOPLEFT, 10, 36)
    resultIconBox:SetDimensions(ALCHEMY_RECIPE_RESULT_ICON_SIZE, ALCHEMY_RECIPE_RESULT_ICON_SIZE)
    resultIconBox:SetMouseEnabled(true)
    SetControlDrawOrder(resultIconBox, DT_HIGH, DL_CONTROLS, 9)
    card.resultIconBox = resultIconBox

    local resultIcon = WINDOW_MANAGER:CreateControl(namePrefix .. "ResultIcon", resultIconBox, CT_TEXTURE)
    resultIcon:ClearAnchors()
    resultIcon:SetAnchor(TOPLEFT, resultIconBox, TOPLEFT, 2, 2)
    resultIcon:SetAnchor(BOTTOMRIGHT, resultIconBox, BOTTOMRIGHT, -2, -2)
    SetControlDrawOrder(resultIcon, DT_HIGH, DL_CONTROLS, 10)
    resultIconBox.texture = resultIcon

    local nameLabel = WINDOW_MANAGER:CreateControl(namePrefix .. "Name", card, CT_LABEL)
    nameLabel:ClearAnchors()
    nameLabel:SetAnchor(TOPLEFT, card, TOPLEFT, 34, 10)
    nameLabel:SetAnchor(TOPRIGHT, card, TOPRIGHT, -98, 10)
    nameLabel:SetHeight(18)
    nameLabel:SetFont("ZoFontGameSmall")
    nameLabel:SetColor(0.78, 0.82, 0.88, 1.0)
    if type(nameLabel.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
        nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    SetControlDrawOrder(nameLabel, DT_HIGH, DL_CONTROLS, 11)
    card.nameLabel = nameLabel

    local resultLabel = WINDOW_MANAGER:CreateControl(namePrefix .. "Result", card, CT_LABEL)
    resultLabel:ClearAnchors()
    resultLabel:SetAnchor(TOPLEFT, card, TOPLEFT, 66, 32)
    resultLabel:SetAnchor(TOPRIGHT, card, TOPRIGHT, -10, 32)
    resultLabel:SetHeight(26)
    resultLabel:SetFont("ZoFontGame")
    resultLabel:SetColor(0.96, 0.97, 1.0, 1.0)
    resultLabel:SetMouseEnabled(true)
    SetControlDrawOrder(resultLabel, DT_HIGH, DL_CONTROLS, 11)
    card.resultLabel = resultLabel

    local countLabel = WINDOW_MANAGER:CreateControl(namePrefix .. "Count", card, CT_LABEL)
    countLabel:ClearAnchors()
    countLabel:SetAnchor(TOPLEFT, card, TOPLEFT, 66, 68)
    countLabel:SetDimensions(44, ALCHEMY_RECIPE_COUNT_EDIT_HEIGHT)
    countLabel:SetFont("ZoFontGameSmall")
    countLabel:SetColor(0.86, 0.88, 0.92, 1.0)
    if type(countLabel.SetVerticalAlignment) == "function" then
        countLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    SetControlDrawOrder(countLabel, DT_HIGH, DL_CONTROLS, 11)
    card.countLabel = countLabel

    local craftCountEditButton = CreateIconButton(card, namePrefix .. "CraftCountEditButton", ALCHEMY_RECIPE_ICON_BUTTON_SIZE, "/esoui/art/buttons/edit", GetText("quick_settings." .. descriptor.menuId .. ".craft_count.tooltip"), function()
        BeginCraftingRecipeCountEdit(card)
    end)
    craftCountEditButton:ClearAnchors()
    craftCountEditButton:SetAnchor(LEFT, countLabel, RIGHT, 2, 0)
    SetControlDrawOrder(craftCountEditButton, DT_HIGH, DL_CONTROLS, 11)
    card.craftCountEditButton = craftCountEditButton

    local craftCountEdit = WINDOW_MANAGER:CreateControlFromVirtual(namePrefix .. "CraftCountEdit", card, "ZO_DefaultEditForBackdrop")
    craftCountEdit:ClearAnchors()
    craftCountEdit:SetAnchor(TOPLEFT, countLabel, TOPLEFT, 0, 0)
    craftCountEdit:SetDimensions(ALCHEMY_RECIPE_COUNT_EDIT_WIDTH, ALCHEMY_RECIPE_COUNT_EDIT_HEIGHT)
    craftCountEdit:SetHidden(true)
    if type(craftCountEdit.SetMaxInputChars) == "function" then
        craftCountEdit:SetMaxInputChars(6)
    end
    craftCountEdit:SetHandler("OnEnter", function()
        CommitCraftingRecipeCount(QuickSettings, descriptor, card)
    end)
    craftCountEdit:SetHandler("OnEscape", function()
        CancelCraftingRecipeCountEdit(card)
    end)
    SetTextTooltip(craftCountEdit, GetText("quick_settings." .. descriptor.menuId .. ".craft_count.tooltip"))
    SetControlDrawOrder(craftCountEdit, DT_HIGH, DL_CONTROLS, 12)
    card.craftCountEdit = craftCountEdit

    local craftCountSaveButton = CreateIconButton(card, namePrefix .. "CraftCountSave", ALCHEMY_RECIPE_ICON_BUTTON_SIZE, "/esoui/art/buttons/accept", GetText("common.save"), function()
        CommitCraftingRecipeCount(QuickSettings, descriptor, card)
    end)
    craftCountSaveButton:ClearAnchors()
    craftCountSaveButton:SetAnchor(LEFT, craftCountEdit, RIGHT, 2, 0)
    craftCountSaveButton:SetHidden(true)
    SetControlDrawOrder(craftCountSaveButton, DT_HIGH, DL_CONTROLS, 12)
    card.craftCountSaveButton = craftCountSaveButton

    local craftCountCancelButton = CreateIconButton(card, namePrefix .. "CraftCountCancel", ALCHEMY_RECIPE_ICON_BUTTON_SIZE, "/esoui/art/buttons/decline", GetText("common.cancel"), function()
        CancelCraftingRecipeCountEdit(card)
    end)
    craftCountCancelButton:ClearAnchors()
    craftCountCancelButton:SetAnchor(LEFT, craftCountSaveButton, RIGHT, 2, 0)
    craftCountCancelButton:SetHidden(true)
    SetControlDrawOrder(craftCountCancelButton, DT_HIGH, DL_CONTROLS, 12)
    card.craftCountCancelButton = craftCountCancelButton

    card.reagentIcons = {}
    local reagentRow = WINDOW_MANAGER:CreateControl(namePrefix .. "ReagentRow", card, CT_CONTROL)
    reagentRow:ClearAnchors()
    reagentRow:SetAnchor(LEFT, craftCountEditButton, RIGHT, 8, 0)
    reagentRow:SetDimensions((ALCHEMY_RECIPE_REAGENT_ICON_SIZE * 3) + (ALCHEMY_RECIPE_ICON_GAP * 2), ALCHEMY_RECIPE_REAGENT_ICON_SIZE)
    SetControlDrawOrder(reagentRow, DT_HIGH, DL_CONTROLS, 8)
    card.reagentRow = reagentRow

    for reagentIndex = 1, 3 do
        local iconName = namePrefix .. "Reagent" .. tostring(reagentIndex)
        local iconBox = CreateBackdrop(reagentRow, iconName, 0.03, 0.03, 0.035, 0.98, 0.24, 0.24, 0.26, 1.0)
        iconBox:ClearAnchors()
        iconBox:SetAnchor(LEFT, reagentRow, LEFT, (reagentIndex - 1) * (ALCHEMY_RECIPE_REAGENT_ICON_SIZE + ALCHEMY_RECIPE_ICON_GAP), 0)
        iconBox:SetDimensions(ALCHEMY_RECIPE_REAGENT_ICON_SIZE, ALCHEMY_RECIPE_REAGENT_ICON_SIZE)
        iconBox:SetMouseEnabled(true)
        SetControlDrawOrder(iconBox, DT_HIGH, DL_CONTROLS, 9)

        local texture = WINDOW_MANAGER:CreateControl(iconName .. "Icon", iconBox, CT_TEXTURE)
        texture:ClearAnchors()
        texture:SetAnchor(TOPLEFT, iconBox, TOPLEFT, 2, 2)
        texture:SetAnchor(BOTTOMRIGHT, iconBox, BOTTOMRIGHT, -2, -2)
        SetControlDrawOrder(texture, DT_HIGH, DL_CONTROLS, 10)
        iconBox.texture = texture

        local count = WINDOW_MANAGER:CreateControl(iconName .. "Count", iconBox, CT_LABEL)
        count:ClearAnchors()
        count:SetAnchor(BOTTOMRIGHT, iconBox, BOTTOMRIGHT, -2, -1)
        count:SetDimensions(28, 14)
        count:SetFont("ZoFontGameSmall")
        count:SetColor(1.0, 1.0, 1.0, 1.0)
        if type(count.SetHorizontalAlignment) == "function" then
            count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        end
        SetControlDrawOrder(count, DT_HIGH, DL_CONTROLS, 11)
        iconBox.count = count
        card.reagentIcons[reagentIndex] = iconBox
    end

    local applyButton = CreateButton(card, namePrefix .. "Apply", GetText("quick_settings.recipe.set_to_station"), ALCHEMY_RECIPE_APPLY_BUTTON_WIDTH, function()
        ApplyCraftingRecipeCard(QuickSettings, descriptor, card.ltmRecipeId)
    end)
    applyButton:ClearAnchors()
    applyButton:SetAnchor(TOPRIGHT, card, TOPRIGHT, -8, 66)
    SetTextTooltip(applyButton, GetText("quick_settings." .. descriptor.menuId .. ".apply.tooltip"))
    SetControlDrawOrder(applyButton, DT_HIGH, DL_CONTROLS, 11)
    card.applyButton = applyButton

    local renameButton = CreateIconButton(card, namePrefix .. "Rename", ALCHEMY_RECIPE_ICON_BUTTON_SIZE, "/esoui/art/buttons/edit", GetText("common.rename"), function()
        if type(card.recipe) == "table" then
            Addon.UI:ShowDialog(descriptor.renameDialogId, {
                recipeId = card.recipe.id,
                recipeName = card.recipe.name or card.recipe.id,
                initialValue = card.recipe.name or card.recipe.id,
                params = {
                    recipeName = card.recipe.name or card.recipe.id or "",
                },
            })
        end
    end)
    renameButton:ClearAnchors()
    renameButton:SetAnchor(TOPRIGHT, card, TOPRIGHT, -38, 8)
    SetControlDrawOrder(renameButton, DT_HIGH, DL_CONTROLS, 11)
    card.renameButton = renameButton

    local deleteButton = CreateIconButton(card, namePrefix .. "Delete", ALCHEMY_RECIPE_ICON_BUTTON_SIZE, "/esoui/art/buttons/decline", GetText("common.delete"), function()
        local ok, err = descriptor.recipeModule:DeleteRecipe(card.ltmRecipeId)
        HandleRecipeResult(QuickSettings, descriptor, "deleted", ok, err)
    end)
    deleteButton:ClearAnchors()
    deleteButton:SetAnchor(TOPRIGHT, card, TOPRIGHT, -8, 8)
    SetControlDrawOrder(deleteButton, DT_HIGH, DL_CONTROLS, 11)
    card.deleteButton = deleteButton

    return card
end

local function GetAlchemyCardMaterials(recipe, inventoryState, recipeId)
    local reagents = type(inventoryState) == "table" and type(inventoryState.reagents) == "table" and inventoryState.reagents or {}
    local reagentItemIds = type(recipe.reagentItemIds) == "table" and recipe.reagentItemIds or {}
    local signature = table.concat({
        tostring(recipeId),
        BuildInventoryItemStateSignature(type(inventoryState) == "table" and inventoryState.solvent or nil),
        BuildInventoryItemStateSignature(reagents[1]),
        BuildInventoryItemStateSignature(reagents[2]),
        BuildInventoryItemStateSignature(reagents[3]),
        tostring(type(inventoryState) == "table" and inventoryState.allRequiredFound == true),
        tostring(type(inventoryState) == "table" and inventoryState.thirdSlotUnlocked == true),
    }, "|")
    return reagents, reagentItemIds, signature
end

local function GetEnchantCardMaterials(recipe, inventoryState, recipeId)
    local reagents = type(inventoryState) == "table" and {
        inventoryState.potency,
        inventoryState.essence,
        inventoryState.aspect,
    } or {}
    local reagentItemIds = {
        recipe.potencyItemId,
        recipe.essenceItemId,
        recipe.aspectItemId,
    }
    local signature = table.concat({
        tostring(recipeId),
        BuildInventoryItemStateSignature(type(inventoryState) == "table" and inventoryState.potency or nil),
        BuildInventoryItemStateSignature(type(inventoryState) == "table" and inventoryState.essence or nil),
        BuildInventoryItemStateSignature(type(inventoryState) == "table" and inventoryState.aspect or nil),
        tostring(type(inventoryState) == "table" and inventoryState.allRequiredFound == true),
    }, "|")
    return reagents, reagentItemIds, signature
end

RECIPE_DESCRIPTOR_BY_MENU_ID.alchemy_recipe.getCardMaterials = GetAlchemyCardMaterials
RECIPE_DESCRIPTOR_BY_MENU_ID.enchant_recipe.getCardMaterials = GetEnchantCardMaterials

local function RefreshCraftingRecipeCard(self, card, recipe, inventoryIndex, descriptor)
    card.recipe = recipe
    local recipeId = type(recipe) == "table" and recipe.id or nil
    card.ltmRecipeId = recipeId
    card.ltmCraftCount = math.max(math.floor(tonumber(recipe.craftCount) or 1), 1)
    card.activeCheckbox.ltmRecipeId = recipeId
    local active = type(recipe) == "table" and recipe.isActive == true
    if type(ZO_CheckButton_SetCheckState) == "function" then
        ZO_CheckButton_SetCheckState(card.activeCheckbox, active)
    end

    card:SetEdgeColor(active and 0.76 or 0.28, active and 0.86 or 0.30, active and 0.95 or 0.34, 1.0)
    card.activeLabel:SetHidden(true)

    SetLabelText(card.nameLabel, recipe.name or recipe.id or "")
    local resultText = type(recipe.resultItemLink) == "string" and recipe.resultItemLink ~= ""
        and recipe.resultItemLink
        or GetText("quick_settings." .. descriptor.menuId .. ".no_result_link")
    SetLabelText(card.resultLabel, resultText)
    SetItemTooltip(card.resultLabel, recipe.resultItemLink, recipe.name or recipe.id)
    local resultIcon = GetItemLinkIconSafe(recipe.resultItemLink) or ALCHEMY_RECIPE_PLACEHOLDER_ICON
    card.resultIconBox.texture:SetTexture(resultIcon)
    SetItemTooltip(card.resultIconBox, recipe.resultItemLink, recipe.name or recipe.id)
    SetLabelText(card.countLabel, "x " .. tostring(card.ltmCraftCount))
    if card.craftCountEditing ~= true and card.craftCountEdit and type(card.craftCountEdit.SetText) == "function" then
        card.craftCountEdit:SetText(tostring(card.ltmCraftCount))
    end

    local inventoryState = recipeId ~= nil
        and descriptor.recipeModule:GetRecipeInventoryState(recipeId, inventoryIndex)
        or nil
    local reagents, reagentItemIds, signature = descriptor.getCardMaterials(recipe, inventoryState, recipeId)
    for reagentIndex = 1, 3 do
        local iconBox = card.reagentIcons[reagentIndex]
        local display = BuildCraftingRecipeItemDisplay(reagents[reagentIndex], reagentItemIds[reagentIndex])
        local hasReagent = reagentItemIds[reagentIndex] ~= nil
        iconBox:SetHidden(hasReagent ~= true)
        if hasReagent then
            iconBox.texture:SetTexture(display.icon)
            SetLabelText(iconBox.count, tostring(display.count or 0))
            iconBox.count:SetHidden(false)
            SetItemTooltip(iconBox, display.itemLink, display.name)
            iconBox:SetCenterColor(display.found and 0.03 or 0.08, display.found and 0.03 or 0.02, display.found and 0.035 or 0.02, 0.98)
            iconBox:SetEdgeColor(display.found and 0.24 or 0.64, display.found and 0.24 or 0.18, display.found and 0.26 or 0.18, 1.0)
        end
    end

    return signature
end

local function RefreshCraftingRecipePage(self, descriptor)
    local page = self.recipePages and self.recipePages[descriptor.menuId]
    if not page then
        return
    end

    local autoApplyEnabled = descriptor.recipeModule:GetAutoApplyEnabled() == true
    if type(ZO_CheckButton_SetCheckState) == "function" and page.autoApplyCheckbox then
        ZO_CheckButton_SetCheckState(page.autoApplyCheckbox, autoApplyEnabled)
    end

    if page.captureButton and type(page.captureButton.SetEnabled) == "function" then
        page.captureButton:SetEnabled(descriptor.recipeModule.isStationOpen == true)
    end

    local recipes = descriptor.recipeModule:GetRecipeList()

    page.emptyLabel:SetHidden(#recipes > 0)
    local layoutSignature = BuildRecipeLayoutSignature(
        recipes,
        page.listRoot,
        page.scroll
    )
    local layoutNeedsRefresh = page.layoutSignature ~= layoutSignature
    if not layoutNeedsRefresh then
        for index = 1, #recipes do
            if page.cards[index] == nil then
                layoutNeedsRefresh = true
                break
            end
        end
    end
    local inventoryIndex = #recipes > 0
        and descriptor.recipeModule:BuildInventoryIndex()
        or nil
    local rowCount = #recipes > 0 and math.ceil(#recipes / ALCHEMY_RECIPE_CARD_COLUMNS) or 0
    local contentHeight = rowCount > 0
        and (rowCount * ALCHEMY_RECIPE_CARD_HEIGHT) + ((rowCount - 1) * ALCHEMY_RECIPE_CARD_GAP)
        or 0
    local refreshStateParts = {}

    for index, recipe in ipairs(recipes) do
        local card = page.cards[index]
        if card == nil then
            card = CreateCraftingRecipeCard(self, page.listRoot, index, descriptor, page)
            page.cards[index] = card
        end

        if layoutNeedsRefresh then
            local columnIndex = (index - 1) % ALCHEMY_RECIPE_CARD_COLUMNS
            local rowIndex = math.floor((index - 1) / ALCHEMY_RECIPE_CARD_COLUMNS)
            local y = rowIndex * (ALCHEMY_RECIPE_CARD_HEIGHT + ALCHEMY_RECIPE_CARD_GAP)
            card:ClearAnchors()
            if columnIndex == 0 then
                card:SetAnchor(TOPLEFT, page.listRoot, TOPLEFT, 0, y)
                card:SetAnchor(TOPRIGHT, page.listRoot, TOP, -(ALCHEMY_RECIPE_CARD_GAP / 2), y)
            else
                card:SetAnchor(TOPLEFT, page.listRoot, TOP, ALCHEMY_RECIPE_CARD_GAP / 2, y)
                card:SetAnchor(TOPRIGHT, page.listRoot, TOPRIGHT, 0, y)
            end
        end
        card:SetHidden(false)
        refreshStateParts[index] = RefreshCraftingRecipeCard(self, card, recipe, inventoryIndex, descriptor)
    end

    for index = #recipes + 1, #page.cards do
        page.cards[index]:SetHidden(true)
    end

    if layoutNeedsRefresh then
        RefreshCardListScrollContainer(page.scroll, contentHeight)
        page.layoutSignature = layoutSignature
    end

    return table.concat(refreshStateParts, "||")
end

function QuickSettings:RefreshAlchemyRecipe()
    return RefreshCraftingRecipePage(self, RECIPE_DESCRIPTOR_BY_MENU_ID.alchemy_recipe)
end

local function GetEnchantRecipeErrorText(err)
    if err == "station_not_open" then
        return GetText("quick_settings.enchant_recipe.warning.station_not_open")
    end
    if err == "runes_insufficient" or err == "not_in_creation_mode" then
        return GetText("quick_settings.enchant_recipe.warning.slots_not_set")
    end
    return GetText("quick_settings.enchant_recipe.warning.invalid", {
        reason = Log.LocalizeErrorReason(err),
    })
end

RECIPE_DESCRIPTOR_BY_MENU_ID.enchant_recipe.errorText = GetEnchantRecipeErrorText

function QuickSettings:RefreshEnchantRecipe()
    return RefreshCraftingRecipePage(self, RECIPE_DESCRIPTOR_BY_MENU_ID.enchant_recipe)
end

CreateScribingRecipePanel = function(self, parent, titleLabel)
    local header = WINDOW_MANAGER:CreateControl("$(parent)ScribingRecipeHeader", parent, CT_CONTROL)
    header:ClearAnchors()
    header:SetAnchor(TOPLEFT, titleLabel, TOPLEFT, 0, 0)
    header:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -QUICK_SETTINGS_PANEL_PADDING, QUICK_SETTINGS_PANEL_PADDING)
    header:SetHeight(FOOD_PANEL_HEADER_HEIGHT)
    header:SetHidden(true)
    SetControlDrawOrder(header, DT_HIGH, DL_CONTROLS, 4)
    self.scribingRecipeHeader = header

    local panel = WINDOW_MANAGER:CreateControl("$(parent)ScribingRecipePanel", parent, CT_CONTROL)
    panel:ClearAnchors()
    panel:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 8)
    panel:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, -QUICK_SETTINGS_PANEL_PADDING, -QUICK_SETTINGS_PANEL_PADDING)
    panel:SetMouseEnabled(true)
    panel:SetHidden(true)
    SetControlDrawOrder(panel, DT_HIGH, DL_CONTROLS, 4)
    self.scribingRecipePanel = panel

    local autoApplyCheckbox = WINDOW_MANAGER:CreateControlFromVirtual("LTM_ScribingRecipeAutoApply", header, "ZO_CheckButton")
    autoApplyCheckbox:ClearAnchors()
    autoApplyCheckbox:SetAnchor(TOPLEFT, header, TOPLEFT, 0, FOOD_PANEL_TITLE_HEIGHT + FOOD_PANEL_HEADER_TITLE_GAP)
    autoApplyCheckbox:SetDimensions(ALCHEMY_RECIPE_ACTIVE_CHECKBOX_SIZE, ALCHEMY_RECIPE_ACTIVE_CHECKBOX_SIZE)
    if type(ZO_CheckButton_SetLabelText) == "function" then
        ZO_CheckButton_SetLabelText(autoApplyCheckbox, "")
    end
    SetTextTooltip(autoApplyCheckbox, GetText("quick_settings.scribing_recipe.auto_apply.tooltip"))
    if type(ZO_CheckButton_SetToggleFunction) == "function" then
        ZO_CheckButton_SetToggleFunction(autoApplyCheckbox, function(_, isChecked)
            SetScribingAutoApplyEnabled(QuickSettings, isChecked == true)
        end)
    end
    SetControlDrawOrder(autoApplyCheckbox, DT_HIGH, DL_CONTROLS, 4)
    self.scribingAutoApplyCheckbox = autoApplyCheckbox

    local autoApplyLabel = WINDOW_MANAGER:CreateControl("$(parent)AutoApplyLabel", header, CT_LABEL)
    autoApplyLabel:ClearAnchors()
    autoApplyLabel:SetAnchor(LEFT, autoApplyCheckbox, RIGHT, 6, FOOD_AUTO_EAT_LABEL_OFFSET_Y)
    autoApplyLabel:SetAnchor(RIGHT, header, RIGHT, -210, FOOD_AUTO_EAT_LABEL_OFFSET_Y)
    autoApplyLabel:SetHeight(ALCHEMY_RECIPE_ACTIVE_CHECKBOX_SIZE)
    autoApplyLabel:SetFont("ZoFontGame")
    autoApplyLabel:SetColor(0.96, 0.94, 0.84, 1.0)
    autoApplyLabel:SetText(GetText("quick_settings.scribing_recipe.auto_apply"))
    autoApplyLabel:SetMouseEnabled(true)
    SetTextTooltip(autoApplyLabel, GetText("quick_settings.scribing_recipe.auto_apply.tooltip"))
    if type(autoApplyLabel.SetVerticalAlignment) == "function" then
        autoApplyLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    SetControlDrawOrder(autoApplyLabel, DT_HIGH, DL_CONTROLS, 4)
    self.scribingAutoApplyLabel = autoApplyLabel

    local captureButton = CreateButton(header, "$(parent)CaptureScribingRecipe", GetText("quick_settings.scribing_recipe.capture"), 190, function()
        CaptureScribingRecipe(self)
    end)
    captureButton:ClearAnchors()
    captureButton:SetAnchor(TOPRIGHT, header, TOPRIGHT, 0, 0)
    SetTextTooltip(captureButton, GetText("quick_settings.scribing_recipe.capture.tooltip"))
    SetControlDrawOrder(captureButton, DT_HIGH, DL_CONTROLS, 4)
    self.scribingCaptureButton = captureButton

    local dropZone = CreateBackdrop(panel, "$(parent)DropZone", 0.06, 0.065, 0.075, 0.92, 0.32, 0.36, 0.42, 1.0)
    dropZone:ClearAnchors()
    dropZone:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
    dropZone:SetAnchor(TOPRIGHT, panel, TOPRIGHT, 0, 0)
    dropZone:SetHeight(36)
    dropZone:SetMouseEnabled(true)
    dropZone:SetHandler("OnReceiveDrag", function(_, button)
        RegisterScribingRecipeFromDrop(self, button)
    end)
    SetTextTooltip(dropZone, GetText("quick_settings.scribing_recipe.drop_zone.body"))
    SetControlDrawOrder(dropZone, DT_HIGH, DL_CONTROLS, 4)
    self.scribingDropZone = dropZone

    local dropZoneLabel = WINDOW_MANAGER:CreateControl("$(parent)DropZoneLabel", dropZone, CT_LABEL)
    dropZoneLabel:ClearAnchors()
    dropZoneLabel:SetAnchor(TOPLEFT, dropZone, TOPLEFT, 8, 0)
    dropZoneLabel:SetAnchor(BOTTOMRIGHT, dropZone, BOTTOMRIGHT, -8, 0)
    dropZoneLabel:SetFont("ZoFontGameSmall")
    dropZoneLabel:SetColor(0.82, 0.86, 0.92, 1.0)
    dropZoneLabel:SetText(GetText("quick_settings.scribing_recipe.drop_zone.title"))
    if type(dropZoneLabel.SetVerticalAlignment) == "function" then
        dropZoneLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    if type(dropZoneLabel.SetHorizontalAlignment) == "function" then
        dropZoneLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end
    if type(dropZoneLabel.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
        dropZoneLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    SetControlDrawOrder(dropZoneLabel, DT_HIGH, DL_CONTROLS, 5)
    self.scribingDropZoneLabel = dropZoneLabel

    local emptyLabel = WINDOW_MANAGER:CreateControl("$(parent)EmptyLabel", panel, CT_LABEL)
    emptyLabel:ClearAnchors()
    emptyLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 48)
    emptyLabel:SetAnchor(TOPRIGHT, panel, TOPRIGHT, 0, 48)
    emptyLabel:SetHeight(34)
    emptyLabel:SetFont("ZoFontGame")
    emptyLabel:SetColor(0.82, 0.84, 0.88, 1.0)
    emptyLabel:SetText(GetText("quick_settings.scribing_recipe.empty"))
    self.scribingRecipeEmptyLabel = emptyLabel

    self.scribingRecipeListScroll = CreateCardListScrollContainer(panel, 48, 0)
    self.scribingRecipeListRoot = self.scribingRecipeListScroll.scrollChild
    self.scribingRecipeCards = {}
end

local GetScribingValidationReasonText

local function GetScribingRecipeErrorText(err)
    if err == "station_not_open" or err == "scribing_unavailable" or err == "scene_not_ready" then
        return GetText("quick_settings.scribing_recipe.warning.station_not_open")
    end
    if err == "crafted_ability_not_set" or err == "scripts_insufficient" or err == "scribing_selection_unavailable"
        or err == "active_scripts_insufficient" then
        return GetText("quick_settings.scribing_recipe.warning.slots_not_set")
    end
    if err == "scribing_drop_not_scribed_skill" then
        return GetText("quick_settings.scribing_recipe.warning.drop_not_scribed_skill")
    end
    if err == "scribing_drop_no_active_configuration" then
        return GetText("quick_settings.scribing_recipe.warning.drop_no_active_configuration")
    end
    if err == "scribing_drop_incomplete" then
        return GetText("quick_settings.scribing_recipe.warning.drop_incomplete")
    end
    if err == "scribing_drop_unsupported" then
        return GetText("quick_settings.scribing_recipe.warning.drop_unsupported")
    end
    local validationReasonText = type(GetScribingValidationReasonText) == "function"
        and GetScribingValidationReasonText(err)
        or nil
    return GetText("quick_settings.scribing_recipe.warning.invalid", {
        reason = validationReasonText
            or Log.LocalizeErrorReason(err),
    })
end

GetScribingValidationReasonText = function(reason)
    if reason == nil then
        return nil
    end
    if reason == "already_active" then
        return GetText("quick_settings.scribing_recipe.validation.already_active")
    end
    if reason == "scribing_data_manager_unavailable" or reason == "scribing_unavailable" then
        return GetText("quick_settings.scribing_recipe.validation.scribing_unavailable")
    end
    if reason == "crafted_ability_locked" then
        return GetText("quick_settings.scribing_recipe.validation.locked_grimoire")
    end
    if reason == "crafted_ability_disabled" then
        return GetText("quick_settings.scribing_recipe.validation.disabled_grimoire")
    end
    if reason == "primary_script_locked" or reason == "secondary_script_locked" or reason == "tertiary_script_locked"
        or reason == "primary_script_not_found" or reason == "secondary_script_not_found" or reason == "tertiary_script_not_found" then
        return GetText("quick_settings.scribing_recipe.validation.locked_script")
    end
    if reason == "primary_script_disabled" or reason == "secondary_script_disabled" or reason == "tertiary_script_disabled" then
        return GetText("quick_settings.scribing_recipe.validation.disabled_script")
    end
    if reason == "script_combination_invalid" then
        return GetText("quick_settings.scribing_recipe.validation.invalid_combination")
    end
    if reason == "ink_insufficient" then
        return GetText("quick_settings.scribing_recipe.validation.need_ink")
    end
    if reason == "crafted_ability_not_found" or reason == "scripts_insufficient" then
        return GetText("quick_settings.scribing_recipe.validation.invalid_combination")
    end

    return Log.LocalizeErrorReason(reason)
end

local function BuildScribingValidationSummary(validationState)
    if type(validationState) ~= "table" then
        return GetText("quick_settings.scribing_recipe.validation.scribing_unavailable"), false, nil
    end

    if validationState.reason == "ink_insufficient" then
        return GetText("quick_settings.scribing_recipe.validation.need_ink_amount", {
            cost = tostring(validationState.inkCost or "?"),
            count = tostring(validationState.inkCount or "?"),
        }), false, validationState.reason
    end

    if validationState.ok == true then
        if validationState.inkCost ~= nil and validationState.inkCount ~= nil then
            return GetText("quick_settings.scribing_recipe.validation.ready_with_ink", {
                cost = tostring(validationState.inkCost),
                count = tostring(validationState.inkCount),
            }), true, nil
        end
        return GetText("quick_settings.scribing_recipe.validation.ready"), true, nil
    end

    return GetScribingValidationReasonText(validationState.reason)
        or GetText("quick_settings.scribing_recipe.validation.scribing_unavailable"),
        false,
        validationState.reason
end

RECIPE_DESCRIPTOR_BY_MENU_ID.scribing_recipe.errorText = GetScribingRecipeErrorText

SetScribingAutoApplyEnabled = function(self, enabled)
    ScribingRecipe:SetAutoApplyEnabled(enabled == true)
    self:RefreshScribingRecipe()
end

CaptureScribingRecipe = function(self)
    local descriptor = RECIPE_DESCRIPTOR_BY_MENU_ID.scribing_recipe
    local recipe, err = descriptor.recipeModule:CaptureFromStation()
    return HandleRecipeResult(self, descriptor, "saved", recipe, err)
end

local function NormalizeCursorId(value)
    local numericValue = tonumber(value)
    if numericValue == nil or numericValue <= 0 then
        return nil
    end
    return numericValue
end

local function GetCursorTypeSafe()
    if type(GetCursorContentType) ~= "function" then
        return nil
    end

    local ok, cursorType = pcall(GetCursorContentType)
    if ok then
        return cursorType
    end
    return nil
end

local function GetCursorCraftedAbilityIdSafe()
    if type(GetCursorCraftedAbilityId) ~= "function" then
        return nil
    end

    local ok, craftedAbilityId = pcall(GetCursorCraftedAbilityId)
    if ok then
        return NormalizeCursorId(craftedAbilityId)
    end
    return nil
end

local function GetCursorAbilityIdSafe()
    if type(GetCursorAbilityId) ~= "function" then
        return nil
    end

    local ok, abilityId = pcall(GetCursorAbilityId)
    if ok then
        return NormalizeCursorId(abilityId)
    end
    return nil
end

local function GetCraftedAbilityIdFromAbilitySafe(abilityId)
    if type(GetAbilityCraftedAbilityId) ~= "function" or abilityId == nil then
        return nil
    end

    local ok, craftedAbilityId = pcall(GetAbilityCraftedAbilityId, abilityId)
    if ok then
        return NormalizeCursorId(craftedAbilityId)
    end
    return nil
end

local function GetActiveScribingScriptSlots(craftedAbilityId)
    if craftedAbilityId == nil or type(GetCraftedAbilityActiveScriptIds) ~= "function" then
        return nil, "scribing_drop_unsupported"
    end

    local ok, primaryScriptId, secondaryScriptId, tertiaryScriptId = pcall(GetCraftedAbilityActiveScriptIds, craftedAbilityId)
    if not ok then
        return nil, "scribing_drop_unsupported"
    end

    primaryScriptId = NormalizeCursorId(primaryScriptId) or 0
    secondaryScriptId = NormalizeCursorId(secondaryScriptId) or 0
    tertiaryScriptId = NormalizeCursorId(tertiaryScriptId) or 0
    if primaryScriptId == 0 or secondaryScriptId == 0 or tertiaryScriptId == 0 then
        return nil, "scribing_drop_no_active_configuration"
    end

    return {
        craftedAbilityId = craftedAbilityId,
        primaryScriptId = primaryScriptId,
        secondaryScriptId = secondaryScriptId,
        tertiaryScriptId = tertiaryScriptId,
    }
end

local function ResolveScribingRecipeDropSlots()
    local cursorType = GetCursorTypeSafe()
    if cursorType == nil then
        return nil, "scribing_drop_unsupported"
    end

    local craftedAbilityCursorType = rawget(_G, "MOUSE_CONTENT_CRAFTED_ABILITY")
    if craftedAbilityCursorType ~= nil and cursorType == craftedAbilityCursorType then
        local craftedAbilityId = GetCursorCraftedAbilityIdSafe()
        if craftedAbilityId == nil then
            return nil, "scribing_drop_not_scribed_skill"
        end
        return GetActiveScribingScriptSlots(craftedAbilityId)
    end

    local scriptCursorType = rawget(_G, "MOUSE_CONTENT_CRAFTED_ABILITY_SCRIPT")
    if scriptCursorType ~= nil and cursorType == scriptCursorType then
        return nil, "scribing_drop_incomplete"
    end

    local abilityCursorType = rawget(_G, "MOUSE_CONTENT_ABILITY")
    if abilityCursorType == nil or cursorType == abilityCursorType then
        local abilityId = GetCursorAbilityIdSafe()
        local craftedAbilityId = GetCraftedAbilityIdFromAbilitySafe(abilityId)
        if craftedAbilityId == nil then
            return nil, "scribing_drop_not_scribed_skill"
        end
        return GetActiveScribingScriptSlots(craftedAbilityId)
    end

    return nil, "scribing_drop_unsupported"
end

RegisterScribingRecipeFromDrop = function(self, button)
    local leftButton = rawget(_G, "MOUSE_BUTTON_INDEX_LEFT")
    if leftButton ~= nil and button ~= nil and button ~= leftButton then
        return false
    end

    local slots, err = ResolveScribingRecipeDropSlots()
    if type(slots) ~= "table" then
        WriteChat(GetScribingRecipeErrorText(err))
        return false
    end

    local recipe
    recipe, err = ScribingRecipe:CreateRecipeFromIds(
        nil,
        slots.craftedAbilityId,
        slots.primaryScriptId,
        slots.secondaryScriptId,
        slots.tertiaryScriptId
    )

    if type(recipe) == "table" then
        WriteChat(GetText("quick_settings.scribing_recipe.saved", {
            recipeName = recipe.name or recipe.craftedAbilityName or recipe.id or "",
        }))
        if type(ClearCursor) == "function" then
            pcall(ClearCursor)
        end
        self:RefreshScribingRecipe()
        return true
    end

    WriteChat(GetScribingRecipeErrorText(err))
    self:RefreshScribingRecipe()
    return false
end

SetActiveScribingRecipe = function(self, recipeId)
    local descriptor = RECIPE_DESCRIPTOR_BY_MENU_ID.scribing_recipe
    local recipe, err = descriptor.recipeModule:SetActiveRecipe(recipeId)
    return HandleRecipeResult(self, descriptor, "active_set", recipe, err)
end

DeleteScribingRecipe = function(self, recipeId)
    local descriptor = RECIPE_DESCRIPTOR_BY_MENU_ID.scribing_recipe
    local ok, err = descriptor.recipeModule:DeleteRecipe(recipeId)
    return HandleRecipeResult(self, descriptor, "deleted", ok, err)
end

ApplyScribingRecipeToStation = function(self, recipeId)
    local descriptor = RECIPE_DESCRIPTOR_BY_MENU_ID.scribing_recipe
    local ok, result = descriptor.recipeModule:ApplyRecipeToStation(recipeId)
    return HandleRecipeResult(self, descriptor, "applied", ok, result, recipeId)
end

CreateScribingRecipeCard = function(self, parent, index)
    scribingRecipeCardControlSerial = scribingRecipeCardControlSerial + 1
    local namePrefix = "LTM_ScribingRecipeCard" .. tostring(index) .. "_" .. tostring(scribingRecipeCardControlSerial)
    local card = CreateBackdrop(parent, namePrefix, 0.08, 0.09, 0.10, 0.96, 0.28, 0.30, 0.34, 1.0)
    card:ClearAnchors()
    card:SetHeight(SCRIBING_RECIPE_CARD_HEIGHT)
    card:SetMouseEnabled(true)
    card:SetHandler("OnMouseUp", function(selfControl, _, upInside)
        if upInside then
            ApplyScribingRecipeToStation(QuickSettings, selfControl.ltmRecipeId)
        end
    end)
    SetControlDrawOrder(card, DT_HIGH, DL_CONTROLS, 8)

    local activeCheckbox = WINDOW_MANAGER:CreateControlFromVirtual(namePrefix .. "Active", card, "ZO_CheckButton")
    activeCheckbox:ClearAnchors()
    activeCheckbox:SetAnchor(TOPLEFT, card, TOPLEFT, 8, 8)
    activeCheckbox:SetDimensions(ALCHEMY_RECIPE_ACTIVE_CHECKBOX_SIZE, ALCHEMY_RECIPE_ACTIVE_CHECKBOX_SIZE)
    if type(ZO_CheckButton_SetLabelText) == "function" then
        ZO_CheckButton_SetLabelText(activeCheckbox, "")
    end
    if type(ZO_CheckButton_SetToggleFunction) == "function" then
        ZO_CheckButton_SetToggleFunction(activeCheckbox, function(_, isChecked)
            if isChecked == true and type(activeCheckbox.ltmRecipeId) == "string" then
                SetActiveScribingRecipe(QuickSettings, activeCheckbox.ltmRecipeId)
            else
                QuickSettings:RefreshScribingRecipe()
            end
        end)
    end
    SetTextTooltip(activeCheckbox, GetText("quick_settings.scribing_recipe.active.tooltip"))
    SetControlDrawOrder(activeCheckbox, DT_HIGH, DL_CONTROLS, 11)
    card.activeCheckbox = activeCheckbox

    local nameLabel = WINDOW_MANAGER:CreateControl(namePrefix .. "Name", card, CT_LABEL)
    nameLabel:ClearAnchors()
    nameLabel:SetAnchor(TOPLEFT, card, TOPLEFT, 34, 10)
    nameLabel:SetAnchor(TOPRIGHT, card, TOPRIGHT, -98, 10)
    nameLabel:SetHeight(18)
    nameLabel:SetFont("ZoFontGameSmall")
    nameLabel:SetColor(0.78, 0.82, 0.88, 1.0)
    if type(nameLabel.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
        nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    SetControlDrawOrder(nameLabel, DT_HIGH, DL_CONTROLS, 11)
    card.nameLabel = nameLabel

    local abilityIconBox = CreateBackdrop(card, namePrefix .. "AbilityIconBox", 0.03, 0.03, 0.035, 0.98, 0.24, 0.24, 0.26, 1.0)
    abilityIconBox:ClearAnchors()
    abilityIconBox:SetAnchor(TOPLEFT, card, TOPLEFT, 10, 36)
    abilityIconBox:SetDimensions(ALCHEMY_RECIPE_RESULT_ICON_SIZE, ALCHEMY_RECIPE_RESULT_ICON_SIZE)
    abilityIconBox:SetMouseEnabled(true)
    abilityIconBox:SetHandler("OnMouseEnter", function(control)
        if type(card.recipe) == "table" then
            ShowCraftedAbilityTooltip(
                control,
                card.recipe.craftedAbilityId,
                card.recipe.primaryScriptId,
                card.recipe.secondaryScriptId,
                card.recipe.tertiaryScriptId,
                control.ltmTooltipText
            )
        end
    end)
    abilityIconBox:SetHandler("OnMouseExit", function()
        ClearScribingTooltip()
    end)
    SetControlDrawOrder(abilityIconBox, DT_HIGH, DL_CONTROLS, 9)
    card.abilityIconBox = abilityIconBox

    local abilityIcon = WINDOW_MANAGER:CreateControl(namePrefix .. "AbilityIcon", abilityIconBox, CT_TEXTURE)
    abilityIcon:ClearAnchors()
    abilityIcon:SetAnchor(TOPLEFT, abilityIconBox, TOPLEFT, 2, 2)
    abilityIcon:SetAnchor(BOTTOMRIGHT, abilityIconBox, BOTTOMRIGHT, -2, -2)
    SetControlDrawOrder(abilityIcon, DT_HIGH, DL_CONTROLS, 10)
    abilityIconBox.texture = abilityIcon

    local abilityLabel = WINDOW_MANAGER:CreateControl(namePrefix .. "Ability", card, CT_LABEL)
    abilityLabel:ClearAnchors()
    abilityLabel:SetAnchor(TOPLEFT, card, TOPLEFT, 66, 38)
    abilityLabel:SetAnchor(TOPRIGHT, card, TOPRIGHT, -184, 38)
    abilityLabel:SetHeight(36)
    abilityLabel:SetFont("ZoFontGame")
    abilityLabel:SetColor(0.96, 0.97, 1.0, 1.0)
    abilityLabel:SetMouseEnabled(true)
    abilityLabel:SetHandler("OnMouseEnter", function(control)
        if type(card.recipe) == "table" then
            ShowCraftedAbilityTooltip(
                control,
                card.recipe.craftedAbilityId,
                card.recipe.primaryScriptId,
                card.recipe.secondaryScriptId,
                card.recipe.tertiaryScriptId,
                control.ltmTooltipText
            )
        end
    end)
    abilityLabel:SetHandler("OnMouseExit", function()
        ClearScribingTooltip()
    end)
    if type(abilityLabel.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
        abilityLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    SetControlDrawOrder(abilityLabel, DT_HIGH, DL_CONTROLS, 11)
    card.abilityLabel = abilityLabel

    local validationLabel = WINDOW_MANAGER:CreateControl(namePrefix .. "Validation", card, CT_LABEL)
    validationLabel:ClearAnchors()
    validationLabel:SetAnchor(TOPLEFT, card, TOPLEFT, 66, 76)
    validationLabel:SetAnchor(TOPRIGHT, card, TOPRIGHT, -184, 76)
    validationLabel:SetHeight(20)
    validationLabel:SetFont("ZoFontGameSmall")
    validationLabel:SetColor(0.86, 0.88, 0.92, 1.0)
    validationLabel:SetMouseEnabled(true)
    if type(validationLabel.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
        validationLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    SetControlDrawOrder(validationLabel, DT_HIGH, DL_CONTROLS, 11)
    card.validationLabel = validationLabel

    card.scriptRows = {}
    for scriptIndex = 1, 3 do
        local row = WINDOW_MANAGER:CreateControl(namePrefix .. "ScriptRow" .. tostring(scriptIndex), card, CT_CONTROL)
        row:ClearAnchors()
        row:SetAnchor(TOPRIGHT, card, TOPRIGHT, -28, 34 + ((scriptIndex - 1) * 22))
        row:SetDimensions(148, 20)
        SetControlDrawOrder(row, DT_HIGH, DL_CONTROLS, 9)

        local iconBox = CreateBackdrop(row, "$(parent)IconBox", 0.03, 0.03, 0.035, 0.98, 0.24, 0.24, 0.26, 1.0)
        iconBox:ClearAnchors()
        iconBox:SetAnchor(LEFT, row, LEFT, 0, 0)
        iconBox:SetDimensions(20, 20)
        iconBox:SetMouseEnabled(true)
        iconBox:SetHandler("OnMouseEnter", function(control)
            if type(card.recipe) == "table" then
                ShowCraftedAbilityScriptTooltip(
                    control,
                    card.recipe.craftedAbilityId,
                    control.ltmScriptId,
                    card.recipe.primaryScriptId,
                    card.recipe.secondaryScriptId,
                    card.recipe.tertiaryScriptId,
                    control.ltmTooltipText
                )
            end
        end)
        iconBox:SetHandler("OnMouseExit", function()
            ClearScribingTooltip()
        end)
        SetControlDrawOrder(iconBox, DT_HIGH, DL_CONTROLS, 10)

        local icon = WINDOW_MANAGER:CreateControl("$(parent)Icon", iconBox, CT_TEXTURE)
        icon:ClearAnchors()
        icon:SetAnchor(TOPLEFT, iconBox, TOPLEFT, 2, 2)
        icon:SetAnchor(BOTTOMRIGHT, iconBox, BOTTOMRIGHT, -2, -2)
        SetControlDrawOrder(icon, DT_HIGH, DL_CONTROLS, 11)
        iconBox.texture = icon

        local label = WINDOW_MANAGER:CreateControl("$(parent)Label", row, CT_LABEL)
        label:ClearAnchors()
        label:SetAnchor(LEFT, iconBox, RIGHT, 5, 0)
        label:SetAnchor(RIGHT, row, RIGHT, 0, 0)
        label:SetHeight(20)
        label:SetFont("ZoFontGameSmall")
        label:SetColor(0.86, 0.88, 0.92, 1.0)
        label:SetMouseEnabled(true)
        label:SetHandler("OnMouseEnter", function(control)
            if type(card.recipe) == "table" then
                ShowCraftedAbilityScriptTooltip(
                    control,
                    card.recipe.craftedAbilityId,
                    control.ltmScriptId,
                    card.recipe.primaryScriptId,
                    card.recipe.secondaryScriptId,
                    card.recipe.tertiaryScriptId,
                    control.ltmTooltipText
                )
            end
        end)
        label:SetHandler("OnMouseExit", function()
            ClearScribingTooltip()
        end)
        if type(label.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
            label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        end
        if type(label.SetVerticalAlignment) == "function" then
            label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        end
        SetControlDrawOrder(label, DT_HIGH, DL_CONTROLS, 11)

        row.iconBox = iconBox
        row.label = label
        card.scriptRows[scriptIndex] = row
    end

    local applyButton = CreateButton(card, namePrefix .. "Apply", GetText("quick_settings.recipe.set_to_station"), ALCHEMY_RECIPE_APPLY_BUTTON_WIDTH, function()
        ApplyScribingRecipeToStation(QuickSettings, card.ltmRecipeId)
    end)
    applyButton:ClearAnchors()
    applyButton:SetAnchor(BOTTOMRIGHT, card, BOTTOMRIGHT, -8, -3)
    SetTextTooltip(applyButton, GetText("quick_settings.scribing_recipe.apply.tooltip"))
    SetControlDrawOrder(applyButton, DT_HIGH, DL_CONTROLS, 11)
    card.applyButton = applyButton

    local renameButton = CreateIconButton(card, namePrefix .. "Rename", ALCHEMY_RECIPE_ICON_BUTTON_SIZE, "/esoui/art/buttons/edit", GetText("common.rename"), function()
        if type(card.recipe) == "table" then
            Addon.UI:ShowDialog("SCRIBING_RECIPE_RENAME_INPUT", {
                recipeId = card.recipe.id,
                recipeName = card.recipe.name or card.recipe.id,
                initialValue = card.recipe.name or card.recipe.id,
                params = {
                    recipeName = card.recipe.name or card.recipe.id or "",
                },
            })
        end
    end)
    renameButton:ClearAnchors()
    renameButton:SetAnchor(TOPRIGHT, card, TOPRIGHT, -38, 8)
    SetControlDrawOrder(renameButton, DT_HIGH, DL_CONTROLS, 11)
    card.renameButton = renameButton

    local deleteButton = CreateIconButton(card, namePrefix .. "Delete", ALCHEMY_RECIPE_ICON_BUTTON_SIZE, "/esoui/art/buttons/decline", GetText("common.delete"), function()
        DeleteScribingRecipe(QuickSettings, card.ltmRecipeId)
    end)
    deleteButton:ClearAnchors()
    deleteButton:SetAnchor(TOPRIGHT, card, TOPRIGHT, -8, 8)
    SetControlDrawOrder(deleteButton, DT_HIGH, DL_CONTROLS, 11)
    card.deleteButton = deleteButton

    return card
end

RefreshScribingRecipeCard = function(self, card, recipe)
    card.recipe = recipe
    local recipeId = type(recipe) == "table" and recipe.id or nil
    card.ltmRecipeId = recipeId
    card.activeCheckbox.ltmRecipeId = recipeId
    local active = type(recipe) == "table" and recipe.isActive == true
    if type(ZO_CheckButton_SetCheckState) == "function" then
        ZO_CheckButton_SetCheckState(card.activeCheckbox, active)
    end

    card:SetEdgeColor(active and 0.76 or 0.28, active and 0.86 or 0.30, active and 0.95 or 0.34, 1.0)
    SetLabelText(card.nameLabel, recipe.name or recipe.id or "")

    local abilityName = recipe.craftedAbilityName or recipe.name or ("#" .. tostring(recipe.craftedAbilityId or ""))
    SetLabelText(card.abilityLabel, abilityName)
    card.abilityIconBox.texture:SetTexture(recipe.craftedAbilityIcon or ALCHEMY_RECIPE_PLACEHOLDER_ICON)
    card.abilityIconBox.ltmTooltipText = abilityName
    card.abilityLabel.ltmTooltipText = abilityName

    local scriptNames = {
        recipe.primaryScriptName,
        recipe.secondaryScriptName,
        recipe.tertiaryScriptName,
    }
    local scriptIds = {
        recipe.primaryScriptId,
        recipe.secondaryScriptId,
        recipe.tertiaryScriptId,
    }
    local scriptIcons = {
        recipe.primaryScriptIcon,
        recipe.secondaryScriptIcon,
        recipe.tertiaryScriptIcon,
    }
    local scriptLabels = {
        GetText("quick_settings.scribing_recipe.script.primary"),
        GetText("quick_settings.scribing_recipe.script.secondary"),
        GetText("quick_settings.scribing_recipe.script.tertiary"),
    }

    for scriptIndex = 1, 3 do
        local row = card.scriptRows[scriptIndex]
        local scriptName = scriptNames[scriptIndex] or ("#" .. tostring(scriptIds[scriptIndex] or ""))
        local text = scriptLabels[scriptIndex] .. ": " .. scriptName
        row.iconBox.texture:SetTexture(scriptIcons[scriptIndex] or ALCHEMY_RECIPE_PLACEHOLDER_ICON)
        SetLabelText(row.label, text)
        row.ltmScriptId = scriptIds[scriptIndex]
        row.ltmTooltipText = text
        row.iconBox.ltmScriptId = scriptIds[scriptIndex]
        row.iconBox.ltmTooltipText = scriptName
        row.label.ltmScriptId = scriptIds[scriptIndex]
        row.label.ltmTooltipText = text
    end

    local validationState = recipeId ~= nil
        and ScribingRecipe:GetRecipeValidationState(recipeId)
        or nil
    local validationText, validationOk = BuildScribingValidationSummary(validationState)
    SetLabelText(card.validationLabel, validationText)
    SetTextTooltip(card.validationLabel, validationText)
    if validationOk == true then
        card.validationLabel:SetColor(0.62, 0.95, 0.66, 1.0)
    elseif type(validationState) == "table" and validationState.reason == "already_active" then
        card.validationLabel:SetColor(0.96, 0.86, 0.50, 1.0)
    else
        card.validationLabel:SetColor(1.0, 0.58, 0.50, 1.0)
    end
end

function QuickSettings:RefreshScribingRecipe()
    if not self.scribingRecipePanel then
        return
    end

    local autoApplyEnabled = ScribingRecipe:GetAutoApplyEnabled() == true
    if type(ZO_CheckButton_SetCheckState) == "function" and self.scribingAutoApplyCheckbox then
        ZO_CheckButton_SetCheckState(self.scribingAutoApplyCheckbox, autoApplyEnabled)
    end

    if self.scribingCaptureButton and type(self.scribingCaptureButton.SetEnabled) == "function" then
        self.scribingCaptureButton:SetEnabled(ScribingRecipe.isStationOpen == true)
    end

    local recipes = ScribingRecipe:GetRecipeList()

    self.scribingRecipeEmptyLabel:SetHidden(#recipes > 0)
    self.scribingRecipeCards = self.scribingRecipeCards or {}
    local rowCount = #recipes > 0 and math.ceil(#recipes / ALCHEMY_RECIPE_CARD_COLUMNS) or 0
    local contentHeight = rowCount > 0
        and (rowCount * SCRIBING_RECIPE_CARD_HEIGHT) + ((rowCount - 1) * ALCHEMY_RECIPE_CARD_GAP)
        or 0

    for index, recipe in ipairs(recipes) do
        local card = self.scribingRecipeCards[index]
        if card == nil then
            card = CreateScribingRecipeCard(self, self.scribingRecipeListRoot, index)
            self.scribingRecipeCards[index] = card
        end

        local columnIndex = (index - 1) % ALCHEMY_RECIPE_CARD_COLUMNS
        local rowIndex = math.floor((index - 1) / ALCHEMY_RECIPE_CARD_COLUMNS)
        local y = rowIndex * (SCRIBING_RECIPE_CARD_HEIGHT + ALCHEMY_RECIPE_CARD_GAP)
        card:ClearAnchors()
        if columnIndex == 0 then
            card:SetAnchor(TOPLEFT, self.scribingRecipeListRoot, TOPLEFT, 0, y)
            card:SetAnchor(TOPRIGHT, self.scribingRecipeListRoot, TOP, -(ALCHEMY_RECIPE_CARD_GAP / 2), y)
        else
            card:SetAnchor(TOPLEFT, self.scribingRecipeListRoot, TOP, ALCHEMY_RECIPE_CARD_GAP / 2, y)
            card:SetAnchor(TOPRIGHT, self.scribingRecipeListRoot, TOPRIGHT, 0, y)
        end
        card:SetHidden(false)
        RefreshScribingRecipeCard(self, card, recipe)
    end

    for index = #recipes + 1, #self.scribingRecipeCards do
        self.scribingRecipeCards[index]:SetHidden(true)
    end

    RefreshCardListScrollContainer(self.scribingRecipeListScroll, contentHeight)
end

function QuickSettings:SaveCurrentQuickSlots()
    local profile, err = QuickslotProfileFacade:CreateFromCurrent(nil)
    if type(profile) ~= "table" then
        WriteChat(GetText("quick_settings.quick_slots.failed", { reason = tostring(err) }))
        return
    end

    WriteChat(GetText("quick_settings.quick_slots.saved", { profileName = profile.displayName or profile.name or profile.id }))
    self:RefreshQuickSlots()
end

function QuickSettings:OverwriteQuickSlotProfile(profileId)
    local profile, err = QuickslotProfileFacade:OverwriteProfileFromCurrent(profileId)
    if type(profile) ~= "table" then
        WriteChat(GetText("quick_settings.quick_slots.overwrite_failed", { reason = tostring(err) }))
        return
    end

    WriteChat(GetText("quick_settings.quick_slots.overwritten", { profileName = profile.displayName or profile.name or profile.id }))
    self:RefreshQuickSlots()
end

function QuickSettings:DeleteQuickSlotProfile(profileId)
    QuickslotProfileFacade:DeleteProfile(profileId)
    self:RefreshQuickSlots()
end

function QuickSettings:RenameQuickSlotProfile(profileId, newName)
    local profile, err = QuickslotProfileFacade:RenameProfile(profileId, newName)
    if type(profile) == "table" then
        self:RefreshQuickSlots()
    end
    return profile, err
end

function QuickSettings:RenameAlchemyRecipe(recipeId, newName)
    local descriptor = RECIPE_DESCRIPTOR_BY_MENU_ID.alchemy_recipe
    local recipe, err = descriptor.recipeModule:RenameRecipe(recipeId, newName)
    local success = HandleRecipeResult(self, descriptor, "renamed", recipe, err)
    if success then
        return recipe, nil
    end
    return recipe, err
end

function QuickSettings:RenameEnchantRecipe(recipeId, newName)
    local descriptor = RECIPE_DESCRIPTOR_BY_MENU_ID.enchant_recipe
    local recipe, err = descriptor.recipeModule:RenameRecipe(recipeId, newName)
    local success = HandleRecipeResult(self, descriptor, "renamed", recipe, err)
    if success then
        return recipe, nil
    end
    return recipe, err
end

function QuickSettings:RenameScribingRecipe(recipeId, newName)
    local descriptor = RECIPE_DESCRIPTOR_BY_MENU_ID.scribing_recipe
    local recipe, err = descriptor.recipeModule:RenameRecipe(recipeId, newName)
    local success = HandleRecipeResult(self, descriptor, "renamed", recipe, err)
    if success then
        return recipe, nil
    end
    return recipe, err
end

function QuickSettings:ApplyQuickSlotProfile(profile, confirmedMissing)
    if type(profile) ~= "table" then
        return
    end

    local activeProfile = QuickslotProfileFacade:SetActiveProfile(profile.id)
    if type(activeProfile) == "table" then
        profile = activeProfile
        self:RefreshQuickSlots()
    else
        self:RefreshQuickSlots()
        return
    end

    local applyState = QuickslotProfileFacade:GetProfileApplyState(profile)
    if type(applyState) == "table" and applyState.canCompare == true and applyState.needsApply ~= true then
        self:RefreshQuickSlots()
        return
    end

    if not confirmedMissing then
        local missingConfirm = QuickslotProfileFacade:BuildMissingConfirmModel(profile)
        if type(missingConfirm) == "table" and missingConfirm.hasMissing == true then
            Addon.UI:ShowDialog("QUICKSLOT_MISSING_CONFIRM", {
                params = {
                    items = missingConfirm.itemsText or "",
                },
                onConfirm = function()
                    QuickSettings:ApplyQuickSlotProfile(profile, true)
                end,
            })
            return
        end
    end

    QuickslotProfileFacade:BeginProfileApply(profile, function(result)
        if type(result) ~= "table" then
            return
        end

        if result.status == "full_success" then
            WriteChat(GetText("quick_settings.quick_slots.applied", { profileName = profile.displayName or profile.name or profile.id }))
        elseif result.status == "partial_success" then
            WriteChat(GetText("quick_settings.quick_slots.partial", { profileName = profile.displayName or profile.name or profile.id }))
        else
            WriteChat(GetText("quick_settings.quick_slots.failed", { reason = tostring(result.reason) }))
        end

        QuickSettings:RefreshQuickSlots()
    end)
end

function QuickSettings:ClearActiveQuickSlotProfile(profile)
    if type(profile) ~= "table" then
        return
    end

    QuickslotProfileFacade:ClearActiveProfile(profile.id)
    self:RefreshQuickSlots()
end

HandleQuickSlotFetchResult = function(self, success, reason, summary)
    if success ~= true then
        WriteChat(GetText("status.fetched_quickslot_failed", {
            reason = Log.LocalizeErrorReason(reason),
        }))
    elseif reason == "nothing_missing" then
        WriteChat(GetText("status.fetched_quickslot_already_owned"))
    elseif reason == "no_fetchable_items" then
        WriteChat(GetText("status.fetched_quickslot_none"))
    elseif reason == "already_full" then
        WriteChat(GetText("status.refilled_quickslot_already_full"))
    elseif reason == "no_refill_targets" then
        WriteChat(GetText("status.refilled_quickslot_no_targets"))
    elseif reason == "refill_completed" then
        WriteChat(GetText("status.refilled_quickslot", {
            count = tostring(type(summary) == "table" and summary.fetchedItems or 0),
        }))
    elseif reason == "refill_partial" then
        WriteChat(GetText("status.refilled_quickslot_partial", {
            count = tostring(type(summary) == "table" and summary.fetchedItems or 0),
        }))
    else
        WriteChat(GetText("status.fetched_quickslot", {
            count = tostring(type(summary) == "table" and summary.fetchedItems or 0),
        }))
    end

    self:RefreshQuickSlots()
end

function QuickSettings:FetchQuickSlotProfile(profile)
    if type(profile) ~= "table" then
        return
    end

    local ok, err, summary = QuickslotProfileFacade:BeginProfileFetch(profile, {
        mode = NormalizeQuickSlotFetchMode(self.quickSlotFetchMode),
        preferLowCondition = self.quickSlotFetchPreferLowCondition == true,
    }, function(success, completionErr, completionSummary)
        HandleQuickSlotFetchResult(QuickSettings, success, completionErr, completionSummary)
    end)

    if ok == true and err == "deferred" then
        self:RefreshQuickSlots()
        return
    end

    HandleQuickSlotFetchResult(self, ok == true, err, summary)
end

local function CreateQuickSlotSettingsMenuRow(menu, name, rowIndex, textKey, onClick)
    local row = CreateBackdrop(menu, name, 0, 0, 0, 0, 0, 0, 0, 0)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, menu, TOPLEFT, 4, 4 + ((rowIndex - 1) * QUICK_SLOT_SETTINGS_MENU_ROW_HEIGHT))
    row:SetAnchor(TOPRIGHT, menu, TOPRIGHT, -4, 4 + ((rowIndex - 1) * QUICK_SLOT_SETTINGS_MENU_ROW_HEIGHT))
    row:SetHeight(QUICK_SLOT_SETTINGS_MENU_ROW_HEIGHT)
    row:SetMouseEnabled(true)
    SetControlDrawOrder(row, DT_HIGH, DL_OVERLAY, 3)

    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", row, CT_LABEL)
    label:ClearAnchors()
    label:SetAnchor(LEFT, row, LEFT, 8, 0)
    label:SetAnchor(RIGHT, row, RIGHT, -8, 0)
    label:SetHeight(QUICK_SLOT_SETTINGS_MENU_ROW_HEIGHT)
    label:SetFont("ZoFontGame")
    label:SetColor(0.96, 0.97, 1.0, 1.0)
    label:SetText(GetText(textKey))
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetMouseEnabled(false)
    SetControlDrawOrder(label, DT_HIGH, DL_OVERLAY, 4)

    row:SetHandler("OnMouseEnter", function()
        row:SetCenterColor(0.14, 0.40, 0.70, 0.92)
    end)
    row:SetHandler("OnMouseExit", function()
        row:SetCenterColor(0, 0, 0, 0)
    end)
    row:SetHandler("OnMouseUp", function(_, _, upInside)
        if upInside then
            onClick()
        end
    end)
end

local function ToggleQuickSlotSettingsMenu(card)
    if QuickSettings.openQuickSlotSettingsCard == card then
        QuickSettings:HideQuickSlotSettingsMenu()
        return
    end

    Addon.UI:CloseActionMenus()
    QuickSettings.openQuickSlotSettingsCard = card
    card.settingsMenu:SetHidden(false)
    Addon.UI:RefreshActionMenuDismissLayer()
end

CreateQuickSlotCard = function(self, parent, index)
    local namePrefix = "LTM_QSCard" .. tostring(index)
    local card = CreateBackdrop(parent, namePrefix, 0.08, 0.09, 0.10, 0.96, 0.28, 0.30, 0.34, 1.0)
    card:ClearAnchors()
    card:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, (index - 1) * (QUICK_SLOT_CARD_HEIGHT + QUICK_SLOT_CARD_GAP))
    card:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, (index - 1) * (QUICK_SLOT_CARD_HEIGHT + QUICK_SLOT_CARD_GAP))
    card:SetHeight(QUICK_SLOT_CARD_HEIGHT)
    card:SetMouseEnabled(true)
    SetControlDrawOrder(card, DT_HIGH, DL_CONTROLS, 6)

    local applyCheckbox = WINDOW_MANAGER:CreateControlFromVirtual(namePrefix .. "ApplyCheckbox", card, "ZO_CheckButton")
    applyCheckbox:ClearAnchors()
    applyCheckbox:SetAnchor(TOPLEFT, card, TOPLEFT, 8, 9)
    applyCheckbox:SetDimensions(QUICK_SLOT_CARD_CHECKBOX_SIZE, QUICK_SLOT_CARD_CHECKBOX_SIZE)
    if type(ZO_CheckButton_SetLabelText) == "function" then
        ZO_CheckButton_SetLabelText(applyCheckbox, "")
    end
    if type(ZO_CheckButton_SetToggleFunction) == "function" then
        ZO_CheckButton_SetToggleFunction(applyCheckbox, function(_, isChecked)
            if isChecked == true then
                QuickSettings:ApplyQuickSlotProfile(card.profile)
            else
                QuickSettings:ClearActiveQuickSlotProfile(card.profile)
            end
        end)
    end
    SetTextTooltip(applyCheckbox, GetText("quick_settings.quick_slots.apply"))
    SetControlDrawOrder(applyCheckbox, DT_HIGH, DL_CONTROLS, 11)
    card.applyCheckbox = applyCheckbox

    local title = WINDOW_MANAGER:CreateControl(namePrefix .. "Title", card, CT_LABEL)
    title:ClearAnchors()
    title:SetAnchor(TOPLEFT, card, TOPLEFT, 36, 8)
    title:SetAnchor(TOPRIGHT, card, TOPRIGHT, -112, 8)
    title:SetHeight(24)
    title:SetFont("ZoFontWinH4")
    title:SetColor(1.0, 1.0, 1.0, 1.0)
    if type(title.SetVerticalAlignment) == "function" then
        title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    SetControlDrawOrder(title, DT_HIGH, DL_CONTROLS, 10)
    card.title = title

    local missing = WINDOW_MANAGER:CreateControl(namePrefix .. "Missing", card, CT_LABEL)
    missing:ClearAnchors()
    missing:SetHeight(18)
    missing:SetFont("ZoFontGameSmall")
    missing:SetColor(1.0, 0.22, 0.22, 1.0)
    SetControlDrawOrder(missing, DT_HIGH, DL_CONTROLS, 10)
    card.missing = missing

    card.icons = {}
    local iconRow = WINDOW_MANAGER:CreateControl(namePrefix .. "IconRow", card, CT_CONTROL)
    iconRow:ClearAnchors()
    iconRow:SetAnchor(BOTTOMLEFT, card, BOTTOMLEFT, 10, -10)
    iconRow:SetHeight(QUICK_SLOT_ICON_SIZE)
    iconRow:SetWidth((QUICK_SLOT_ICON_SIZE * 8) + (QUICK_SLOT_ICON_GAP * 7))
    SetControlDrawOrder(iconRow, DT_HIGH, DL_CONTROLS, 7)
    card.iconRow = iconRow

    missing:SetAnchor(LEFT, iconRow, RIGHT, 10, 0)
    missing:SetAnchor(RIGHT, card, RIGHT, -10, 0)
    if type(missing.SetVerticalAlignment) == "function" then
        missing:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end

    for slotIndex = 1, 8 do
        local slotName = namePrefix .. "S" .. tostring(slotIndex)
        local iconBox = CreateBackdrop(iconRow, slotName, 0.03, 0.03, 0.035, 0.98, 0.24, 0.24, 0.26, 1.0)
        iconBox:ClearAnchors()
        iconBox:SetAnchor(LEFT, iconRow, LEFT, (slotIndex - 1) * (QUICK_SLOT_ICON_SIZE + QUICK_SLOT_ICON_GAP), 0)
        iconBox:SetDimensions(QUICK_SLOT_ICON_SIZE, QUICK_SLOT_ICON_SIZE)
        if type(iconBox.SetMouseEnabled) == "function" then
            iconBox:SetMouseEnabled(true)
        end

        local texture = WINDOW_MANAGER:CreateControl(slotName .. "Tex", iconBox, CT_TEXTURE)
        texture:ClearAnchors()
        texture:SetAnchor(TOPLEFT, iconBox, TOPLEFT, 2, 2)
        texture:SetAnchor(BOTTOMRIGHT, iconBox, BOTTOMRIGHT, -2, -2)
        texture:SetHidden(true)
        SetControlDrawOrder(iconBox, DT_HIGH, DL_CONTROLS, 8)
        SetControlDrawOrder(texture, DT_HIGH, DL_CONTROLS, 9)
        iconBox.texture = texture

        local count = WINDOW_MANAGER:CreateControl(slotName .. "Count", iconBox, CT_LABEL)
        count:ClearAnchors()
        count:SetAnchor(BOTTOMRIGHT, iconBox, BOTTOMRIGHT, -2, -1)
        count:SetDimensions(30, 16)
        count:SetFont("ZoFontGameSmall")
        count:SetColor(1.0, 1.0, 1.0, 1.0)
        if type(count.SetHorizontalAlignment) == "function" then
            count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        end
        SetControlDrawOrder(count, DT_HIGH, DL_CONTROLS, 10)
        iconBox.count = count
        card.icons[slotIndex] = iconBox
    end

    local fetchButton = CreateIconButton(
        card,
        namePrefix .. "Fetch",
        QUICK_SLOT_CARD_FETCH_BUTTON_SIZE,
        QUICK_SLOT_FETCH_ICON_TEXTURE,
        GetText("quick_settings.quick_slots.fetch.tooltip.disabled"),
        function(button)
            if button.ltmFetchEnabled ~= true then
                return
            end

            QuickSettings:FetchQuickSlotProfile(card.profile)
        end
    )
    fetchButton:ClearAnchors()
    fetchButton:SetAnchor(TOPRIGHT, card, TOPRIGHT, -36, 4)
    SetControlDrawOrder(fetchButton, DT_HIGH, DL_CONTROLS, 10)
    card.fetchButton = fetchButton

    local settingsButton = CreateIconButton(
        card,
        namePrefix .. "Settings",
        QUICK_SLOT_CARD_ICON_BUTTON_SIZE,
        "/esoui/art/buttons/edit",
        GetText("quick_settings.quick_slots.settings"),
        function()
            if type(card.profile) == "table" then
                ToggleQuickSlotSettingsMenu(card)
            end
        end
    )
    settingsButton:ClearAnchors()
    settingsButton:SetAnchor(TOPRIGHT, card, TOPRIGHT, -68, 4)
    SetControlDrawOrder(settingsButton, DT_HIGH, DL_CONTROLS, 10)
    card.settingsButton = settingsButton

    local menu = CreateBackdrop(Addon.UI.frontOverlayRoot, namePrefix .. "SettingsMenu", 0.10, 0.10, 0.12, 0.98, 0.48, 0.52, 0.58, 1.0)
    menu:SetDimensions(180, (2 * QUICK_SLOT_SETTINGS_MENU_ROW_HEIGHT) + 8)
    menu:ClearAnchors()
    menu:SetAnchor(TOPRIGHT, settingsButton, BOTTOMRIGHT, 0, 4)
    menu:SetHidden(true)
    SetControlDrawOrder(menu, DT_HIGH, DL_OVERLAY, 2)
    card.settingsMenu = menu

    CreateQuickSlotSettingsMenuRow(menu, namePrefix .. "OverwriteRow", 1, "quick_settings.quick_slots.overwrite_card", function()
        local profileId = card.profile and card.profile.id
        QuickSettings:HideQuickSlotSettingsMenu()
        QuickSettings:OverwriteQuickSlotProfile(profileId)
    end)
    CreateQuickSlotSettingsMenuRow(menu, namePrefix .. "RenameRow", 2, "quick_settings.quick_slots.rename_card", function()
        local profile = card.profile
        QuickSettings:HideQuickSlotSettingsMenu()
        if type(profile) == "table" then
            Addon.UI:ShowDialog("QUICKSLOT_RENAME_INPUT", {
                profileId = profile.id,
                profileName = profile.displayName or profile.name or profile.id,
                initialValue = profile.displayName or profile.name or profile.id,
            })
        end
    end)

    local deleteButton = CreateIconButton(
        card,
        namePrefix .. "Delete",
        FOOD_CARD_DELETE_BUTTON_SIZE,
        "/esoui/art/buttons/decline",
        GetText("common.delete"),
        function()
            if type(card.profile) == "table" then
                QuickSettings:DeleteQuickSlotProfile(card.profile.id)
            end
        end
    )
    deleteButton:ClearAnchors()
    deleteButton:SetAnchor(TOPRIGHT, card, TOPRIGHT, -8, 9)
    SetControlDrawOrder(deleteButton, DT_HIGH, DL_CONTROLS, 10)
    card.deleteButton = deleteButton

    return card
end

RefreshQuickSlotFetchButton = function(self, card, profile, missingCount)
    local button = card and card.fetchButton or nil
    if button == nil then
        return
    end

    local hasProfile = type(profile) == "table"
    button:SetHidden(not hasProfile)
    if not hasProfile then
        return
    end

    local availability = QuickslotProfileFacade:GetFetchAvailability(self.quickSlotFetchMode, missingCount)
    local busy = availability.busy == true
    local hasMissing = availability.hasMissing == true
    local mode = NormalizeQuickSlotFetchMode(availability.mode)
    local enabled = availability.enabled == true
    local tooltipKey = enabled and (mode == QUICK_SLOT_FETCH_MODE_REFILL_MAX
            and "quick_settings.quick_slots.fetch.tooltip.refill_ready"
            or "quick_settings.quick_slots.fetch.tooltip.ready")
        or busy and "quick_settings.quick_slots.fetch.tooltip.busy"
        or mode == QUICK_SLOT_FETCH_MODE_REFILL_MAX and "quick_settings.quick_slots.fetch.tooltip.refill_disabled"
        or hasMissing and "quick_settings.quick_slots.fetch.tooltip.disabled"
        or "quick_settings.quick_slots.fetch.tooltip.none"

    button.ltmFetchEnabled = enabled
    if type(button.SetAlpha) == "function" then
        button:SetAlpha(enabled and 1.0 or QUICK_SLOT_FETCH_BUTTON_DISABLED_ALPHA)
    end
    SetTextTooltip(button, GetText(tooltipKey))
end

function QuickSettings:HasOpenQuickSlotSettingsMenu()
    return self.openQuickSlotSettingsCard ~= nil
end

function QuickSettings:HideQuickSlotSettingsMenu()
    if type(self.quickSlotCards) ~= "table" then
        self.openQuickSlotSettingsCard = nil
        return
    end

    for _, card in ipairs(self.quickSlotCards) do
        if card.settingsMenu then
            card.settingsMenu:SetHidden(true)
        end
    end
    self.openQuickSlotSettingsCard = nil
    Addon.UI:RefreshActionMenuDismissLayer()
end

RefreshQuickSlotCard = function(self, card, profile, refreshContext)
    card.profile = profile
    SetLabelText(card.title, profile.displayName or profile.name or profile.id)
    if type(ZO_CheckButton_SetCheckState) == "function" then
        ZO_CheckButton_SetCheckState(card.applyCheckbox, profile.isActive == true)
    end

    local displayModel = QuickslotProfileFacade:BuildProfileDisplayModel(profile, refreshContext)
    local displaySlots = type(displayModel.slots) == "table" and displayModel.slots or {}
    local missingCount = tonumber(displayModel.missingCount) or 0

    for slotIndex = 1, 8 do
        local iconBox = card.icons[slotIndex]
        local slotView = displaySlots[slotIndex] or {}
        local icon = slotView.icon
        SetItemTooltip(iconBox, slotView.itemLink, nil)
        if type(icon) == "string" and icon ~= "" then
            iconBox.texture:SetTexture(icon)
            iconBox.texture:SetHidden(false)
            if type(iconBox.texture.SetAlpha) == "function" then
                iconBox.texture:SetAlpha(1.0)
            end
        else
            iconBox.texture:SetHidden(true)
        end

        local isMissing = slotView.isMissing == true
        if slotView.kind == "item" then
            iconBox.count:SetText(slotView.displayCount or "")
            iconBox.count:SetColor(isMissing and 1.0 or 1.0, isMissing and 0.12 or 1.0, isMissing and 0.12 or 1.0, 1.0)
            iconBox:SetCenterColor(isMissing and 0.10 or 0.03, isMissing and 0.04 or 0.03, isMissing and 0.04 or 0.035, 0.98)
            iconBox:SetEdgeColor(isMissing and 0.92 or 0.24, isMissing and 0.12 or 0.24, isMissing and 0.12 or 0.26, 1.0)
            if type(iconBox.texture.SetColor) == "function" then
                iconBox.texture:SetColor(isMissing and 0.35 or 1.0, isMissing and 0.35 or 1.0, isMissing and 0.35 or 1.0, 1.0)
            end
        elseif slotView.kind == "simple_action" then
            iconBox.count:SetText("")
            iconBox.count:SetColor(1.0, 1.0, 1.0, 1.0)
            iconBox:SetCenterColor(0.03, 0.03, 0.035, 0.98)
            iconBox:SetEdgeColor(0.24, 0.24, 0.26, 1.0)
            if type(iconBox.texture.SetColor) == "function" then
                iconBox.texture:SetColor(1.0, 1.0, 1.0, 1.0)
            end
        elseif slotView.kind == "empty" then
            iconBox.count:SetText("")
            iconBox:SetCenterColor(0.03, 0.03, 0.035, 0.98)
            iconBox:SetEdgeColor(0.24, 0.24, 0.26, 1.0)
        else
            iconBox.count:SetText("!")
            iconBox.count:SetColor(1.0, 0.72, 0.18, 1.0)
            iconBox:SetCenterColor(0.10, 0.08, 0.03, 0.98)
            iconBox:SetEdgeColor(0.80, 0.56, 0.16, 1.0)
            if type(iconBox.texture.SetColor) == "function" then
                iconBox.texture:SetColor(1.0, 1.0, 1.0, 1.0)
            end
        end
    end

    card.missing:SetHidden(true)
    RefreshQuickSlotFetchButton(self, card, profile, missingCount)
end

local function BuildQuickSlotLayoutSignature(profiles, listWidth, viewportHeight)
    local parts = {
        tostring(#profiles),
        tostring(listWidth),
        tostring(viewportHeight),
    }
    for index, profile in ipairs(profiles) do
        local profileId = tostring(type(profile) == "table" and profile.id or "")
        parts[#parts + 1] = tostring(index) .. ":" .. tostring(#profileId) .. ":" .. profileId
    end
    return table.concat(parts, "|")
end

function QuickSettings:RefreshQuickSlots()
    if not self.quickSlotListRoot then
        return
    end

    local profiles = QuickslotProfileFacade:GetProfileList()

    self.quickSlotEmptyLabel:SetHidden(#profiles > 0)
    local listWidth = self.quickSlotListRoot.GetWidth and self.quickSlotListRoot:GetWidth() or 0
    if type(listWidth) ~= "number" or listWidth <= 0 then
        local scroll = self.quickSlotListScroll and self.quickSlotListScroll.scroll or nil
        listWidth = scroll and scroll.GetWidth and (scroll:GetWidth() - QUICK_SLOT_SCROLLBAR_CONTENT_GAP) or 0
    end
    if type(listWidth) ~= "number" or listWidth <= 0 then
        listWidth = (QUICK_SLOT_CARD_HEIGHT * 8) + QUICK_SLOT_CARD_GRID_GAP
    end
    local scroll = self.quickSlotListScroll and self.quickSlotListScroll.scroll or nil
    local viewportHeight = scroll and scroll.GetHeight and scroll:GetHeight() or 0
    local layoutSignature = BuildQuickSlotLayoutSignature(profiles, listWidth, viewportHeight)
    local layoutNeedsRefresh = self.quickSlotLayoutSignature ~= layoutSignature
    local refreshContext = #profiles > 0
        and QuickslotProfileFacade:BuildProfileListRefreshContext()
        or nil

    self.quickSlotCards = self.quickSlotCards or {}
    if not layoutNeedsRefresh then
        for index = 1, #profiles do
            if self.quickSlotCards[index] == nil then
                layoutNeedsRefresh = true
                break
            end
        end
    end

    local columns = QUICK_SLOT_CARD_COLUMNS
    local cardWidth = nil
    local contentHeight = nil
    if layoutNeedsRefresh then
        cardWidth = math.floor((listWidth - ((columns - 1) * QUICK_SLOT_CARD_GRID_GAP)) / columns)
        local rowCount = #profiles > 0 and math.ceil(#profiles / columns) or 0
        contentHeight = rowCount > 0
            and (rowCount * QUICK_SLOT_CARD_HEIGHT) + ((rowCount - 1) * QUICK_SLOT_CARD_GAP)
            or 0
    end

    for index, profile in ipairs(profiles) do
        local card = self.quickSlotCards[index]
        if card == nil then
            card = CreateQuickSlotCard(self, self.quickSlotListRoot, index)
            self.quickSlotCards[index] = card
        end
        if layoutNeedsRefresh then
            local column = (index - 1) % columns
            local row = math.floor((index - 1) / columns)
            local y = row * (QUICK_SLOT_CARD_HEIGHT + QUICK_SLOT_CARD_GAP)
            card:ClearAnchors()
            card:SetAnchor(TOPLEFT, self.quickSlotListRoot, TOPLEFT, column * (cardWidth + QUICK_SLOT_CARD_GRID_GAP), y)
            card:SetDimensions(cardWidth, QUICK_SLOT_CARD_HEIGHT)
        end
        card:SetHidden(false)
        RefreshQuickSlotCard(self, card, profile, refreshContext)
    end

    for index = #profiles + 1, #self.quickSlotCards do
        self.quickSlotCards[index]:SetHidden(true)
    end

    if layoutNeedsRefresh then
        RefreshCardListScrollContainer(self.quickSlotListScroll, contentHeight)
        self.quickSlotLayoutSignature = layoutSignature
    end

    self.quickSlotDisplayDirty = false
    self.quickSlotFallbackIntervalCount = 0
end

function QuickSettings:StartQuickSlotFetchMonitor()
    if self.quickSlotFetchMonitorStarted == true then
        return
    end

    -- Keep this monitor registered for the addon lifetime. While the QuickSlot
    -- screen is visible, dirty/activity state gates the heavy refresh and the
    -- low-frequency fallback repairs event gaps. The flag below prevents
    -- duplicate RegisterForUpdate calls after repeated content creation.
    self.quickSlotFetchMonitorStarted = true
    EVENT_MANAGER:RegisterForUpdate("LTM_QuickSlotFetchMonitor", QUICK_SLOT_FETCH_MONITOR_INTERVAL_MS, function()
        local state = GetQuickSlotFetchMonitorState()
        if not ShouldRunQuickSlotFetchMonitor(state) then
            return
        end

        self.quickSlotFallbackIntervalCount = (tonumber(self.quickSlotFallbackIntervalCount) or 0) + 1
        local activityState = GetQuickSlotFetchActivityState()
        activityState.displayDirty = self.quickSlotDisplayDirty == true
        activityState.fallbackReached = self.quickSlotFallbackIntervalCount >= QUICK_SLOT_FALLBACK_REFRESH_INTERVAL_COUNT
        if ShouldRefreshQuickSlotDisplay(activityState) then
            self:RefreshQuickSlots()
        end
    end)
end
