KnownVendorFilter = KnownVendorFilter or {}
local addon = KnownVendorFilter
addon.name = "KnownVendorFilter"
addon.version = "1.0.4"
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
function addon:IsKnownItem(link)
    if type(link) ~= "string" or link == "" then return false end
    local category = self:GetItemCategory(link)
    if not category or not self.saved.categories[category] then return false end
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
    local button = WINDOW_MANAGER:CreateControlFromVirtual("KnownVendorFilterButton", ZO_StoreWindow, "ZO_DefaultButton")
    button:SetDimensions(235, 30)
    button:SetAnchor(TOPRIGHT, ZO_StoreWindow, TOPLEFT, -10, 54)
    button:SetHandler("OnClicked", function() self:Toggle() end)
    self.button = button
    self:RefreshButton()
    self:CreateOptionsButton(ZO_StoreWindow, button, "Store")
end

local function isBankWithdrawShowing()
    return BANK_FRAGMENT and (BANK_FRAGMENT:IsShowing() or BANK_FRAGMENT.state == SCENE_FRAGMENT_SHOWN)
end

function addon:RefreshLists()
    if STORE_WINDOW and STORE_WINDOW.UpdateList and ZO_StoreWindow and not ZO_StoreWindow:IsHidden() then STORE_WINDOW:UpdateList() end
    if isBankWithdrawShowing() then PLAYER_INVENTORY:UpdateList(INVENTORY_BANK) end
end

function addon:RefreshOptions()
    self.updatingOptions = true
    for _, key in ipairs(categoryKeys) do
        local checkbox = KnownVendorFilterOptions:GetNamedChild(key)
        ZO_CheckButton_SetCheckState(checkbox, self.saved.categories[key])
    end
    self.updatingOptions = false
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
end

function addon:CreateOptionsButton(parent, anchor, suffix)
    local button = WINDOW_MANAGER:CreateControlFromVirtual("KnownVendorFilter" .. suffix .. "OptionsButton", parent, "ZO_DefaultButton")
    button:SetDimensions(235, 28)
    button:SetAnchor(TOP, anchor, BOTTOM, 0, 5)
    button:SetText(self.text.options)
    button:SetHandler("OnClicked", function() self:ToggleOptions() end)
end

function addon:InitializeOptions()
    KnownVendorFilterOptionsTitle:SetText(self.text.title)
    KnownVendorFilterOptionsDescription:SetText(self.text.description)
    KnownVendorFilterOptionsNote:SetText(self.text.note)
    KnownVendorFilterOptionsClose:SetText(self.text.close)
    KnownVendorFilterOptionsClose:SetHandler("OnClicked", function() KnownVendorFilterOptions:SetHidden(true) end)
    for _, key in ipairs(categoryKeys) do
        local category = key
        local checkbox = KnownVendorFilterOptions:GetNamedChild(category)
        ZO_CheckButton_SetLabelText(checkbox, self.text[category])
        ZO_CheckButton_SetToggleFunction(checkbox, function(_, checked)
            if not self.updatingOptions then self:SetCategory(category, checked) end
        end)
    end
    self:RefreshOptions()
    ZO_PreHookHandler(ZO_StoreWindow, "OnHide", function() KnownVendorFilterOptions:SetHidden(true) end)
end

function addon:InitializeAddonSettings()
    if not LibAddonMenu2 then return end
    local panel = self.name .. "Settings"
    LibAddonMenu2:RegisterAddonPanel(panel, { type = "panel", name = "Known Vendor Filter", displayName = "Known Vendor Filter", author = "Ypselon", version = self.version, registerForRefresh = true, registerForDefaults = true })
    local options = { { type = "description", text = self.text.note } }
    for _, key in ipairs(categoryKeys) do
        local category = key
        options[#options + 1] = { type = "checkbox", name = self.text[category], default = true,
            getFunc = function() return self.saved.categories[category] end,
            setFunc = function(value) self:SetCategory(category, value) end }
    end
    LibAddonMenu2:RegisterOptionControls(panel, options)
end

function addon:AllowBankEntry(data)
    if not self.saved.bankEnabled or (IsInGamepadPreferredMode and IsInGamepadPreferredMode()) then return true end
    if not isBankWithdrawShowing() then return true end
    if type(data) ~= "table" or (data.bagId ~= BAG_BANK and data.bagId ~= BAG_SUBSCRIBER_BANK)
        or type(data.slotIndex) ~= "number" or data.slotIndex < 0 then return true end
    return not self:IsKnownItem(GetItemLink(data.bagId, data.slotIndex, LINK_STYLE_DEFAULT))
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
    local button = WINDOW_MANAGER:CreateControlFromVirtual("KnownVendorFilterBankButton", ZO_PlayerBank, "ZO_DefaultButton")
    button:SetDimensions(235, 30)
    button:SetAnchor(TOPRIGHT, ZO_PlayerBank, TOPLEFT, -10, 54)
    button:SetHandler("OnClicked", function() self:ToggleBank() end)
    self.bankButton = button
    self:RefreshBankButton()
    self:CreateOptionsButton(ZO_PlayerBank, button, "Bank")
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

function addon:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide("KnownVendorFilterSavedVars", 1, nil, { enabled = false, bankEnabled = false, categories = categoryDefaults })
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
    self:InitializeAddonSettings()
    BANK_FRAGMENT:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_HIDDEN then KnownVendorFilterOptions:SetHidden(true) end
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
