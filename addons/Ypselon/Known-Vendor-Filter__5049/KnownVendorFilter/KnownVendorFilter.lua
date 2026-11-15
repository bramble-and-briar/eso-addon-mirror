KnownVendorFilter = KnownVendorFilter or {}
local addon = KnownVendorFilter
addon.name = "KnownVendorFilter"
addon.version = "1.1"
local categoryKeys = { "recipes", "plans", "motifs", "stylePages", "scribing", "collectibles", "sets" }
local categoryDefaults = { recipes = true, plans = true, motifs = true, stylePages = true, scribing = true, collectibles = true, sets = true }

local function isFurnishingRecipe(subtype)
    return subtype and (subtype == SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING
        or subtype == SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING
        or subtype == SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING
        or subtype == SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING
        or subtype == SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING
        or subtype == SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING
        or subtype == SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING)
end

function addon:GetItemCategory(link)
    if type(link) ~= "string" or link == "" then return nil end
    local itemType, subtype = GetItemLinkItemType(link)
    if itemType == ITEMTYPE_RECIPE then return isFurnishingRecipe(subtype) and "plans" or "recipes" end
    if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then return "motifs" end
    if (ITEMTYPE_CRAFTED_ABILITY and itemType == ITEMTYPE_CRAFTED_ABILITY)
        or (ITEMTYPE_CRAFTED_ABILITY_SCRIPT and itemType == ITEMTYPE_CRAFTED_ABILITY_SCRIPT) then return "scribing" end
    if subtype and ((SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE and subtype == SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE)
        or (SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE and subtype == SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE)) then return "stylePages" end
    local collectibleId = GetItemLinkContainerCollectibleId(link)
    if collectibleId and collectibleId > 0 then return "collectibles" end
    if IsItemLinkSetCollectionPiece(link) then return "sets" end
    return nil
end

-- Only a positive, specific known/owned result hides an entry. Other items,
-- ambiguous containers and temporarily unavailable offers remain visible.
function addon:IsKnownItem(link, ignoreCategoryOptions)
    if type(link) ~= "string" or link == "" then return false end
    local category = self:GetItemCategory(link)
    if not category or (not ignoreCategoryOptions and not self.saved.categories[category]) then return false end
    local itemType = GetItemLinkItemType(link)
    if itemType == ITEMTYPE_RECIPE then
        return IsItemLinkRecipeKnown(link) == true
    elseif itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
        return IsItemLinkBookKnown(link) == true
    elseif ITEMTYPE_CRAFTED_ABILITY and itemType == ITEMTYPE_CRAFTED_ABILITY then
        local id = GetItemLinkItemUseReferenceId(link)
        return id and id > 0 and IsCraftedAbilityUnlocked(id) == true or false
    elseif ITEMTYPE_CRAFTED_ABILITY_SCRIPT and itemType == ITEMTYPE_CRAFTED_ABILITY_SCRIPT then
        local id = GetItemLinkItemUseReferenceId(link)
        return id and id > 0 and IsCraftedAbilityScriptUnlocked(id) == true or false
    end

    local collectibleId = GetItemLinkContainerCollectibleId(link)
    if collectibleId and collectibleId > 0 then
        return IsCollectibleUnlocked(collectibleId) == true
    end
    if IsItemLinkSetCollectionPiece(link) then
        local pieceId = GetItemLinkItemId(link)
        return pieceId and pieceId > 0 and IsItemSetCollectionPieceUnlocked(pieceId) == true or false
    end
    return false
end

function addon:IsKnownStoreEntry(data)
    if type(data) ~= "table" or type(data.slotIndex) ~= "number" or data.slotIndex < 1 then return false end
    if data.entryType == STORE_ENTRY_TYPE_COLLECTIBLE then
        if not self.saved.categories.collectibles then return false end
        local id, owned = GetStoreCollectibleInfo(data.slotIndex)
        return owned == true or (id and id > 0 and IsCollectibleUnlocked(id) == true) or false
    end
    if data.entryType ~= STORE_ENTRY_TYPE_ITEM then return false end
    local link = GetStoreItemLink(data.slotIndex, LINK_STYLE_DEFAULT)
    local category = self:GetItemCategory(link)
    if category and not self.saved.categories[category] then return false end
    if data.buyStoreFailure and ((STORE_FAILURE_ALREADY_HAVE_COLLECTIBLE and data.buyStoreFailure == STORE_FAILURE_ALREADY_HAVE_COLLECTIBLE)
        or (STORE_FAILURE_AWARDS_ALREADY_OWNED_COLLECTIBLE and data.buyStoreFailure == STORE_FAILURE_AWARDS_ALREADY_OWNED_COLLECTIBLE)) then
        return self.saved.categories[category or "collectibles"] == true
    end
    return self:IsKnownItem(link)
end

function addon:AllowEntry(data)
    if not self.saved.enabled then return true end
    -- This version provides its button in the keyboard merchant UI only.
    if IsInGamepadPreferredMode and IsInGamepadPreferredMode() then return true end
    return not self:IsKnownStoreEntry(data)
end

function addon:RefreshButton()
    if self.button then self.button:SetText(self.saved.enabled and self.text.on or self.text.off) end
end

function addon:Toggle()
    self.saved.enabled = not self.saved.enabled
    self:RefreshButton()
    if STORE_WINDOW and STORE_WINDOW.UpdateList and ZO_StoreWindow and not ZO_StoreWindow:IsHidden() then
        STORE_WINDOW:UpdateList()
    end
end

function addon:CreateButton()
    local group = self:CreateButtonGroup("Store", ZO_StoreWindow)
    local button = WINDOW_MANAGER:CreateControlFromVirtual("KnownVendorFilterButton", group, "ZO_DefaultButton")
    button:SetDimensions(235, 30)
    button:SetAnchor(TOPLEFT, group, TOPLEFT, 0, 0)
    button:SetHandler("OnClicked", function() self:Toggle() end)
    self.button = button
    self:CreateOptionsButton(group, button, "Store")
    self:FinishButtonGroup("Store", group, "showStoreButtons")
    self:RefreshButton()
end

local function isBankWithdrawShowing()
    return BANK_FRAGMENT and (BANK_FRAGMENT:IsShowing() or BANK_FRAGMENT.state == SCENE_FRAGMENT_SHOWN)
end

function addon:RefreshLists()
    if STORE_WINDOW and STORE_WINDOW.UpdateList and ZO_StoreWindow and not ZO_StoreWindow:IsHidden() then STORE_WINDOW:UpdateList() end
    if isBankWithdrawShowing() then PLAYER_INVENTORY:UpdateList(INVENTORY_BANK) end
    self:RefreshGuildResults()
end

function addon:RefreshOptions()
    self.updatingOptions = true
    for _, key in ipairs(categoryKeys) do
        local checkbox = KnownVendorFilterOptions:GetNamedChild(key)
        ZO_CheckButton_SetCheckState(checkbox, self.saved.categories[key])
    end
    ZO_CheckButton_SetCheckState(KnownVendorFilterOptionsStoreButtons, self.saved.showStoreButtons)
    ZO_CheckButton_SetCheckState(KnownVendorFilterOptionsBankButtons, self.saved.showBankButtons)
    ZO_CheckButton_SetCheckState(KnownVendorFilterOptionsGuildButtons, self.saved.showGuildButtons)
    self.updatingOptions = false
end

function addon:SetButtonsShown(context, value)
    local shownKey = "show" .. context .. "Buttons"
    self.saved[shownKey] = value == true
    if not value then
        if context == "Store" then self.saved.enabled = false
        elseif context == "Bank" then self.saved.bankEnabled = false
        else self.saved.guildEnabled = false end
    end
    self.guildGeneration = (self.guildGeneration or 0) + 1
    self:UpdateButtonGroups()
    self:RefreshButton()
    self:RefreshBankButton()
    self:UpdateGuildButtons()
    self:RefreshLists()
    self:RefreshOptions()
end

function addon:SetGuildButtonsShown(value)
    self:SetButtonsShown("Guild", value)
end

function addon:SetCategory(key, enabled)
    if not categoryDefaults[key] then return end
    self.saved.categories[key] = enabled == true
    self:RefreshOptions()
    self:RefreshLists()
end

function addon:ToggleOptions()
    self:RefreshOptions()
    KnownVendorFilterOptions:SetHidden(not KnownVendorFilterOptions:IsHidden())
    self:UpdatePositioningOverlays()
end

function addon:CreateOptionsButton(parent, anchor, suffix)
    local button = WINDOW_MANAGER:CreateControlFromVirtual("KnownVendorFilter" .. suffix .. "OptionsButton", parent, "ZO_DefaultButton")
    button:SetDimensions(235, 28)
    button:SetAnchor(TOP, anchor, BOTTOM, 0, 5)
    button:SetText(self.text.options)
    button:SetHandler("OnClicked", function() self:ToggleOptions() end)
    return button
end

-- Each window has an independent group. Its transparent drag surface is only
-- active while the options window is open, keeping normal buttons clickable.
function addon:CreateButtonGroup(context, parent)
    self.buttonGroups = self.buttonGroups or {}
    local group = WINDOW_MANAGER:CreateControl("KnownVendorFilter" .. context .. "Group", parent, CT_CONTROL)
    group:SetDimensions(235, 63)
    local pos = self.saved.positions[context]
    group:SetAnchor(TOPLEFT, parent, TOPLEFT, pos and pos.x or -245, pos and pos.y or 54)
    self.buttonGroups[context] = { control = group, parent = parent }
    return group
end

function addon:FinishButtonGroup(context, group, showKey)
    local entry = self.buttonGroups[context]
    local overlay = WINDOW_MANAGER:CreateControl("KnownVendorFilter" .. context .. "Drag", group, CT_CONTROL)
    overlay:SetAnchorFill(group)
    overlay:SetDrawLayer(DL_OVERLAY)
    overlay:SetMouseEnabled(true)
    overlay:SetHandler("OnMouseDown", function(_, mouseButton)
        if mouseButton == MOUSE_BUTTON_INDEX_LEFT then self:StartButtonDrag(context) end
    end)
    overlay:SetHandler("OnMouseUp", function(_, mouseButton)
        if mouseButton == MOUSE_BUTTON_INDEX_LEFT then self:StopButtonDrag() end
    end)
    entry.overlay, entry.showKey = overlay, showKey
    group:SetHidden(not self.saved[showKey])
    self:UpdatePositioningOverlays()
end

-- Move the child group by updating its anchor, instead of using the native
-- window-moving operation (which may re-anchor a non-top-level control).
function addon:StartButtonDrag(context)
    if not KnownVendorFilterOptions or KnownVendorFilterOptions:IsHidden()
        or type(GetUIMousePosition) ~= "function" then return end
    self:StopButtonDrag()
    local entry = self.buttonGroups and self.buttonGroups[context]
    if not entry then return end
    local x, y = GetUIMousePosition()
    local left, top = entry.control:GetLeft(), entry.control:GetTop()
    local parentLeft, parentTop = entry.parent:GetLeft(), entry.parent:GetTop()
    if not x or not y or not left or not top or not parentLeft or not parentTop then return end
    self.activeButtonDrag = { context = context, entry = entry, mouseX = x, mouseY = y,
        left = left, top = top, x = left - parentLeft, y = top - parentTop }
    entry.overlay:SetHandler("OnUpdate", function() self:UpdateButtonDrag() end)
    if EVENT_GLOBAL_MOUSE_UP then
        EVENT_MANAGER:RegisterForEvent(self.name .. "Drag", EVENT_GLOBAL_MOUSE_UP, function(_, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then self:StopButtonDrag() end
        end)
    end
end

function addon:UpdateButtonDrag()
    local drag = self.activeButtonDrag
    if not drag then return end
    local mouseX, mouseY = GetUIMousePosition()
    local parentLeft, parentTop = drag.entry.parent:GetLeft(), drag.entry.parent:GetTop()
    if not mouseX or not mouseY or not parentLeft or not parentTop then return end
    local left = drag.left + mouseX - drag.mouseX
    local top = drag.top + mouseY - drag.mouseY
    -- Keep all buttons reachable even if the cursor leaves the game window.
    local rootLeft, rootTop = GuiRoot:GetLeft() or 0, GuiRoot:GetTop() or 0
    local rootWidth, rootHeight = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    local width, height = drag.entry.control:GetWidth(), drag.entry.control:GetHeight()
    if rootWidth and rootWidth > 0 and width then
        left = math.max(rootLeft, math.min(left, rootLeft + math.max(0, rootWidth - width)))
    end
    if rootHeight and rootHeight > 0 and height then
        top = math.max(rootTop, math.min(top, rootTop + math.max(0, rootHeight - height)))
    end
    drag.x, drag.y = left - parentLeft, top - parentTop
    drag.entry.control:ClearAnchors()
    drag.entry.control:SetAnchor(TOPLEFT, drag.entry.parent, TOPLEFT, drag.x, drag.y)
end

function addon:StopButtonDrag()
    local drag = self.activeButtonDrag
    if not drag then return end
    self:UpdateButtonDrag()
    self.activeButtonDrag = nil
    drag.entry.overlay:SetHandler("OnUpdate", nil)
    if EVENT_GLOBAL_MOUSE_UP then EVENT_MANAGER:UnregisterForEvent(self.name .. "Drag", EVENT_GLOBAL_MOUSE_UP) end
    self.saved.positions[drag.context] = { x = drag.x, y = drag.y }
end

function addon:UpdatePositioningOverlays()
    local unlocked = KnownVendorFilterOptions and not KnownVendorFilterOptions:IsHidden()
    if not unlocked then self:StopButtonDrag() end
    for _, entry in pairs(self.buttonGroups or {}) do
        if entry.overlay then entry.overlay:SetHidden(not unlocked) end
    end
end

function addon:UpdateButtonGroups()
    for _, entry in pairs(self.buttonGroups or {}) do
        entry.control:SetHidden(not self.saved[entry.showKey])
    end
    self:UpdateGuildButtons()
    self:UpdatePositioningOverlays()
end

function addon:ResetButtonPositions()
    self:StopButtonDrag()
    self.saved.positions = {}
    for _, entry in pairs(self.buttonGroups or {}) do
        entry.control:ClearAnchors()
        entry.control:SetAnchor(TOPLEFT, entry.parent, TOPLEFT, -245, 54)
    end
end

function addon:InitializeOptions()
    KnownVendorFilterOptionsTitle:SetText(self.text.title)
    KnownVendorFilterOptionsDescription:SetText(self.text.description)
    KnownVendorFilterOptionsNote:SetText(self.text.positionHint)
    KnownVendorFilterOptionsCompatibility:SetText(self.text.guildCompatibility)
    KnownVendorFilterOptionsButtonsTitle:SetText(self.text.buttonsTitle)
    KnownVendorFilterOptionsReset:SetText(self.text.resetPositions)
    KnownVendorFilterOptionsReset:SetHandler("OnClicked", function() self:ResetButtonPositions() end)
    KnownVendorFilterOptionsClose:SetText(self.text.close)
    KnownVendorFilterOptionsClose:SetHandler("OnClicked", function() KnownVendorFilterOptions:SetHidden(true); self:UpdatePositioningOverlays() end)
    for _, key in ipairs(categoryKeys) do
        local category = key
        local checkbox = KnownVendorFilterOptions:GetNamedChild(category)
        ZO_CheckButton_SetLabelText(checkbox, self.text[category])
        ZO_CheckButton_SetToggleFunction(checkbox, function(_, checked)
            if not self.updatingOptions then self:SetCategory(category, checked) end
        end)
    end
    for _, context in ipairs({ "Store", "Bank", "Guild" }) do
        local ctx = context
        local checkbox = KnownVendorFilterOptions:GetNamedChild(ctx .. "Buttons")
        ZO_CheckButton_SetLabelText(checkbox, self.text[ctx:lower() .. "Show"])
        ZO_CheckButton_SetToggleFunction(checkbox, function(_, checked)
            if not self.updatingOptions then self:SetButtonsShown(ctx, checked) end
        end)
    end
    self:RefreshOptions()
    ZO_PreHookHandler(ZO_StoreWindow, "OnHide", function() KnownVendorFilterOptions:SetHidden(true); self:UpdatePositioningOverlays() end)
end

function addon:InitializeAddonSettings()
    if not LibAddonMenu2 then return end
    local panel = self.name .. "Settings"
    LibAddonMenu2:RegisterAddonPanel(panel, { type = "panel", name = "Known Vendor Filter", displayName = "Known Vendor Filter", author = "Ypselon", version = self.version, registerForRefresh = true, registerForDefaults = true })
    local options = { { type = "header", name = self.text.description }, { type = "description", text = self.text.note } }
    for _, key in ipairs(categoryKeys) do
        local category = key
        options[#options + 1] = { type = "checkbox", name = self.text[category], default = true,
            getFunc = function() return self.saved.categories[category] end,
            setFunc = function(value) self:SetCategory(category, value) end }
    end
    options[#options + 1] = { type = "header", name = self.text.buttonsTitle }
    for _, context in ipairs({ "Store", "Bank", "Guild" }) do
        local ctx = context
        options[#options + 1] = { type = "checkbox", name = self.text[ctx:lower() .. "Show"], default = true,
            getFunc = function() return self.saved["show" .. ctx .. "Buttons"] end,
            setFunc = function(value) self:SetButtonsShown(ctx, value) end }
    end
    options[#options + 1] = { type = "description", text = self.text.positionHint }
    options[#options + 1] = { type = "button", name = self.text.resetPositions, func = function() self:ResetButtonPositions() end }
    options[#options + 1] = { type = "description", text = self.text.guildCompatibility }
    LibAddonMenu2:RegisterOptionControls(panel, options)
end

function addon:AllowBankEntry(data)
    if not self.saved.bankEnabled or (IsInGamepadPreferredMode and IsInGamepadPreferredMode()) then return true end
    if not isBankWithdrawShowing() then return true end
    if type(data) ~= "table" or (data.bagId ~= BAG_BANK and data.bagId ~= BAG_SUBSCRIBER_BANK)
        or type(data.slotIndex) ~= "number" or data.slotIndex < 0 then return true end
    local link = GetItemLink(data.bagId, data.slotIndex, LINK_STYLE_DEFAULT)
    return not self:IsKnownItem(link)
end

function addon:RefreshBankButton()
    if self.bankButton then self.bankButton:SetText(self.saved.bankEnabled and self.text.on or self.text.off) end
end

function addon:ToggleBank()
    self.saved.bankEnabled = not self.saved.bankEnabled
    self:RefreshBankButton()
    if isBankWithdrawShowing() then PLAYER_INVENTORY:UpdateList(INVENTORY_BANK) end
end

function addon:CreateBankButton()
    local group = self:CreateButtonGroup("Bank", ZO_PlayerBank)
    local button = WINDOW_MANAGER:CreateControlFromVirtual("KnownVendorFilterBankButton", group, "ZO_DefaultButton")
    button:SetDimensions(235, 30)
    button:SetAnchor(TOPLEFT, group, TOPLEFT, 0, 0)
    button:SetHandler("OnClicked", function() self:ToggleBank() end)
    self.bankButton = button
    self:CreateOptionsButton(group, button, "Bank")
    self:FinishButtonGroup("Bank", group, "showBankButtons")
    self:RefreshBankButton()
end

function addon:InstallBankFilter()
    if LibFilters3 and LF_BANK_WITHDRAW then
        LibFilters3:InitializeLibFilters()
        if LibFilters3:RegisterFilter(self.name .. "Bank", LF_BANK_WITHDRAW, function(data) return self:AllowBankEntry(data) end) then
            self.bankFilterMode = "libfilters"
            return
        end
    end

    -- Standalone fallback: keep the existing inventory predicate, and apply our
    -- filter only to the personal-bank withdrawal list.
    local previous = PLAYER_INVENTORY.ShouldAddSlotToList
    PLAYER_INVENTORY.ShouldAddSlotToList = function(inventoryManager, inventory, slot)
        if not previous(inventoryManager, inventory, slot) then return false end
        if inventory == inventoryManager.inventories[INVENTORY_BANK] then return self:AllowBankEntry(slot) end
        return true
    end
    self.bankFilterMode = "standalone"
end

function addon:InstallFilter()
    if LibFilters3 and LF_VENDOR_BUY then
        LibFilters3:InitializeLibFilters()
        if LibFilters3:RegisterFilter(self.name, LF_VENDOR_BUY, function(data) return self:AllowEntry(data) end) then
            self.filterMode = "libfilters"
            return
        end
    end

    -- No library is required. Preserve the previously installed store filter.
    local previous = STORE_WINDOW.ShouldAddItemToList
    STORE_WINDOW.ShouldAddItemToList = function(store, data)
        return previous(store, data) and self:AllowEntry(data)
    end
    self.filterMode = "standalone"
end

-- AwesomeGuildStore supplies its own filters and owns its result list.
-- Keep this integration entirely inactive when it is loaded.
function addon:GuildAvailable()
    return self.saved and self.saved.showGuildButtons and not AwesomeGuildStore
        and TRADING_HOUSE and TRADING_HOUSE_SEARCH
        and not (IsInGamepadPreferredMode and IsInGamepadPreferredMode())
end

function addon:GuildBrowsing()
    return self:GuildAvailable() and TRADING_HOUSE.GetCurrentMode
        and TRADING_HOUSE:GetCurrentMode() == ZO_TRADING_HOUSE_MODE_BROWSE
end

function addon:UpdateGuildButtons()
    local show = self:GuildBrowsing()
    if self.guildButton then
        self.guildButton:SetHidden(not show)
        self.guildButton:SetText(self.saved.guildEnabled and self.text.on or self.text.off)
    end
    if self.buttonGroups and self.buttonGroups.Guild then self.buttonGroups.Guild.control:SetHidden(not show) end
end

function addon:RefreshGuildResults()
    if TRADING_HOUSE and TRADING_HOUSE_SEARCH and not AwesomeGuildStore
        and TRADING_HOUSE.GetCurrentMode and TRADING_HOUSE:GetCurrentMode() == ZO_TRADING_HOUSE_MODE_BROWSE
        and not (IsInGamepadPreferredMode and IsInGamepadPreferredMode())
        and ZO_TradingHouse and not ZO_TradingHouse:IsHidden()
        and TRADING_HOUSE_SEARCH.GetSearchState
        and TRADING_HOUSE_SEARCH:GetSearchState() == TRADING_HOUSE_SEARCH_STATE_COMPLETE
        and not TRADING_HOUSE_SEARCH:ShouldShowGuildSpecificItems()
        and TRADING_HOUSE.RebuildSearchResultsPage then
        TRADING_HOUSE:RebuildSearchResultsPage()
    end
end

function addon:ToggleGuild()
    self.saved.guildEnabled = not self.saved.guildEnabled
    self.guildGeneration = (self.guildGeneration or 0) + 1
    self.guildAutoPages = 0
    self:UpdateGuildButtons()
    self:RefreshGuildResults()
    if self.saved.guildEnabled then self:MaybeSkipEmptyGuildPage(true) end
end

function addon:FilterGuildResults(manager, isInitialResults)
    if not self:GuildBrowsing() or not self.saved.guildEnabled or isInitialResults
        or TRADING_HOUSE_SEARCH:ShouldShowGuildSpecificItems() then return end
    local list = manager.searchResultsList
    if not list then return end
    local rows = ZO_ScrollList_GetDataList(list)
    local removed = 0
    for index = #rows, 1, -1 do
        local data = rows[index] and rows[index].data
        local remove = data and type(data.itemLink) == "string" and self:IsKnownItem(data.itemLink)
        if remove then
            table.remove(rows, index)
            removed = removed + 1
        end
    end
    if removed > 0 then
        ZO_ScrollList_Commit(list)
        if manager.resultCount then manager.resultCount:SetText(zo_strformat(SI_TRADING_HOUSE_RESULT_COUNT, #rows)) end
    end
end

function addon:MaybeSkipEmptyGuildPage(allowSkip)
    if AwesomeGuildStore or not allowSkip or not self:GuildBrowsing() or not self.saved.guildEnabled
        or not TRADING_HOUSE_SCENE or not TRADING_HOUSE_SCENE:IsShowing()
        or TRADING_HOUSE_SEARCH:ShouldShowGuildSpecificItems()
        or TRADING_HOUSE_SEARCH:GetSearchState() ~= TRADING_HOUSE_SEARCH_STATE_COMPLETE
        or not TRADING_HOUSE_SEARCH:HasNextPage() then return end
    local list = TRADING_HOUSE.searchResultsList
    if not list or #ZO_ScrollList_GetDataList(list) ~= 0 then return end
    -- Bound consecutive requests; ESO's own search handles its request cooldown.
    if (self.guildAutoPages or 0) >= 10 then return end
    local page = TRADING_HOUSE_SEARCH:GetPage()
    local generation = (self.guildGeneration or 0) + 1
    self.guildGeneration = generation
    zo_callLater(function()
        if self.guildGeneration ~= generation or not self:GuildBrowsing() or not self.saved.guildEnabled
            or not TRADING_HOUSE_SCENE:IsShowing() or TRADING_HOUSE_SEARCH:GetPage() ~= page
            or TRADING_HOUSE_SEARCH:GetSearchState() ~= TRADING_HOUSE_SEARCH_STATE_COMPLETE
            or not TRADING_HOUSE_SEARCH:HasNextPage()
            or #ZO_ScrollList_GetDataList(TRADING_HOUSE.searchResultsList) ~= 0 then return end
        self.guildAutoPages = (self.guildAutoPages or 0) + 1
        TRADING_HOUSE_SEARCH:SearchNextPage()
    end, 100)
end

function addon:InitializeGuildFilter()
    if not TRADING_HOUSE or not TRADING_HOUSE_SEARCH or not ZO_TradingHouse then return end
    local group = self:CreateButtonGroup("Guild", ZO_TradingHouse)
    local button = WINDOW_MANAGER:CreateControlFromVirtual("KnownVendorFilterGuildButton", group, "ZO_DefaultButton")
    button:SetDimensions(235, 30)
    button:SetAnchor(TOPLEFT, group, TOPLEFT, 0, 0)
    button:SetHandler("OnClicked", function() self:ToggleGuild() end)
    self.guildButton = button
    self.guildOptionsButton = self:CreateOptionsButton(group, button, "Guild")
    self:FinishButtonGroup("Guild", group, "showGuildButtons")
    if not AwesomeGuildStore then
        ZO_PostHook(TRADING_HOUSE, "RebuildSearchResultsPage", function(manager, isInitialResults)
            self:FilterGuildResults(manager, isInitialResults)
        end)
    end
    ZO_PostHook(TRADING_HOUSE, "SetCurrentMode", function() self:UpdateGuildButtons() end)
    TRADING_HOUSE_SEARCH:RegisterCallback("OnSearchStateChanged", function(state)
        if state ~= TRADING_HOUSE_SEARCH_STATE_COMPLETE or not self:GuildBrowsing() then return end
        local page = TRADING_HOUSE_SEARCH:GetPage()
        local forward = self.guildLastPage == nil or page >= self.guildLastPage
        if self.guildLastPage == nil or page <= self.guildLastPage then self.guildAutoPages = 0 end
        self.guildLastPage = page
        self:MaybeSkipEmptyGuildPage(forward)
    end)
    TRADING_HOUSE_SCENE:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWING then
            self.guildLastPage, self.guildAutoPages = nil, 0
            self:UpdateGuildButtons()
        elseif state == SCENE_HIDING then
            self.guildGeneration = (self.guildGeneration or 0) + 1
            KnownVendorFilterOptions:SetHidden(true)
            self:UpdatePositioningOverlays()
        end
    end)
    self:UpdateGuildButtons()
end

function addon:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide("KnownVendorFilterSavedVars", 1, nil, { enabled = false, bankEnabled = false, guildEnabled = false, showStoreButtons = true, showBankButtons = true, showGuildButtons = true, positions = {}, categories = categoryDefaults })
    self.saved.positions = self.saved.positions or {}
    self.saved.categories = self.saved.categories or {}
    for _, key in ipairs(categoryKeys) do
        if self.saved.categories[key] == nil then self.saved.categories[key] = true end
    end
    self.text = self:GetTranslation(GetCVar("language.2"))
    self:InstallFilter()
    self:InstallBankFilter()
    self:CreateButton()
    self:CreateBankButton()
    self:InitializeOptions()
    self:InitializeGuildFilter()
    self:InitializeAddonSettings()
    SLASH_COMMANDS["/kvf"] = function() self:ToggleOptions() end
    BANK_FRAGMENT:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_HIDDEN then KnownVendorFilterOptions:SetHidden(true); self:UpdatePositioningOverlays() end
        if newState == SCENE_FRAGMENT_SHOWN and self.saved.bankEnabled
            and not (IsInGamepadPreferredMode and IsInGamepadPreferredMode()) then
            PLAYER_INVENTORY:UpdateList(INVENTORY_BANK)
        end
    end)
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= addon.name then return end
    EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)
    addon:Initialize()
end)
