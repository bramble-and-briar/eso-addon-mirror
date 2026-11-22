-- Furniture Vault filters (formerly the standalone addon FurnitureVaultFilters).
-- Adds the housing editor's multi-select filter dropdown (Bound State + Furnishing Limit Type)
-- to both Furniture Vault panels: Withdraw (vault list) and Deposit (backpack in the vault layout).
--
-- The dropdown itself is built by the game's own ZO_HousingSettingsFilters_SetupDropdown
-- (EsoUI/Ingame/HousingEditor/Keyboard/FurnitureClasses_Keyboard.lua), so the options and
-- their labels are exactly the ones from the housing editor. The matching logic mirrors
-- ZO_PlaceableFurnitureItem:GetPassesFurnitureFilters (FurnitureClasses_Shared.lua).

local SHT = SchrodisHousingTools

local BOUND = ZO_HOUSING_FURNITURE_FILTER_CATEGORY.BOUND
local LIMIT = ZO_HOUSING_FURNITURE_FILTER_CATEGORY.LIMIT

local DROPDOWN_WIDTH = 200
local DROPDOWN_OFFSET_X = 55

-- Filter state per panel ("withdraw" / "deposit"); session-only, like the housing editor.
local filters = {}
local dropdowns = {}

local function NewFilterState()
    return
    {
        bound = HOUSING_FURNITURE_BOUND_FILTER_ALL,
        limit = ZO_HOUSING_FURNITURE_LIMIT_TYPE_FILTER_ALL,
    }
end
filters.withdraw = NewFilterState()
filters.deposit = NewFilterState()

local function IsFilterActive(state)
    return state.bound > HOUSING_FURNITURE_BOUND_FILTER_ALL
        or state.limit > ZO_HOUSING_FURNITURE_LIMIT_TYPE_FILTER_ALL
end

local function DoesSlotPass(state, bagId, slotIndex)
    local boundFilters = state.bound
    if boundFilters > HOUSING_FURNITURE_BOUND_FILTER_ALL then
        local matchBound = ZO_FlagHelpers.MaskHasFlag(boundFilters, HOUSING_FURNITURE_BOUND_FILTER_BOUND)
        local matchUnbound = ZO_FlagHelpers.MaskHasFlag(boundFilters, HOUSING_FURNITURE_BOUND_FILTER_UNBOUND)
        if not (matchBound and matchUnbound) then
            if IsItemBound(bagId, slotIndex) then
                if not matchBound then
                    return false
                end
            elseif not matchUnbound then
                return false
            end
        end
    end

    local limitFilters = state.limit
    if limitFilters > ZO_HOUSING_FURNITURE_LIMIT_TYPE_FILTER_ALL then
        local furnitureDataId = GetItemFurnitureDataId(bagId, slotIndex)
        if not furnitureDataId or furnitureDataId == 0 then
            return false
        end
        local _, _, _, limitType = GetFurnitureDataInfo(furnitureDataId)
        local limitTypeFilterValue = limitType and ZO_HOUSING_FURNITURE_LIMIT_FILTERS[limitType + 1]
        if not limitTypeFilterValue or not ZO_FlagHelpers.MaskHasFlag(limitFilters, limitTypeFilterValue) then
            return false
        end
    end

    return true
end

local function IsVaultDepositLayoutApplied()
    return PLAYER_INVENTORY.appliedLayout == BACKPACK_FURNITURE_VAULT_LAYOUT_FRAGMENT.layoutData
end

-- Returns the filter state that applies to this inventory right now, or nil.
local function GetStateForInventory(inventory)
    local inventories = PLAYER_INVENTORY.inventories
    if inventory == inventories[INVENTORY_FURNITURE_VAULT] then
        return filters.withdraw
    elseif inventory == inventories[INVENTORY_BACKPACK] and IsVaultDepositLayoutApplied() then
        return filters.deposit
    end
    return nil
end

local function CreateDropdown(key, parent, rowAnchorControl, inventoryType)
    local dropdown = CreateControlFromVirtual("SchrodisHousingToolsVaultFilter_" .. key, parent, "ZO_ComboBox")
    dropdown:SetWidth(DROPDOWN_WIDTH)
    -- X from the panel's left edge, Y centered on the top category tab row (empty in the vault layouts;
    -- the subcategory icon row has no free space left of its "active filter" label).
    dropdown:SetAnchor(LEFT, parent, LEFT, DROPDOWN_OFFSET_X, 0, ANCHOR_CONSTRAINS_X)
    dropdown:SetAnchor(LEFT, rowAnchorControl, LEFT, 0, 0, ANCHOR_CONSTRAINS_Y)

    local state = filters[key]
    local function OnFiltersChanged(comboBox)
        local values =
        {
            [BOUND] = HOUSING_FURNITURE_BOUND_FILTER_ALL,
            [LIMIT] = ZO_HOUSING_FURNITURE_LIMIT_TYPE_FILTER_ALL,
        }
        -- Same accumulation as the housing editor: the "All" value acts as 0, selected entries add their flag.
        for _, item in ipairs(comboBox:GetSelectedItemData()) do
            local category = item.filterCategory
            if category and values[category] then
                values[category] = values[category] + item.filterValue
            end
        end

        if values[BOUND] ~= state.bound or values[LIMIT] ~= state.limit then
            state.bound = values[BOUND]
            state.limit = values[LIMIT]
            PLAYER_INVENTORY:UpdateList(inventoryType)
        end
    end

    local INCLUDE_LOCATION_FILTERS = false
    ZO_HousingSettingsFilters_SetupDropdown(dropdown, INCLUDE_LOCATION_FILTERS, OnFiltersChanged)

    dropdowns[key] = dropdown
    return dropdown
end

-- The tab row's "active category" label (ZO_InventoryTabs > $(parent)Active) is mouse-enabled
-- (ZO_TooltipIfTruncatedLabel) and anchored from the panel's left edge all the way to the tab
-- buttons, so it sits on top of the dropdown and swallows its clicks. While the dropdown is shown,
-- start the label at the dropdown's right edge instead; otherwise restore the stock anchors
-- from inventorytemplates.xml.
local function SetActiveLabelAvoidsDropdown(tabs, dropdown, avoid)
    local label = tabs:GetNamedChild("Active")
    if not label then
        return
    end
    label:ClearAnchors()
    if avoid then
        label:SetAnchor(LEFT, dropdown, RIGHT, 10, 0, ANCHOR_CONSTRAINS_X)
    else
        label:SetAnchor(LEFT, tabs:GetParent(), LEFT, -10, 0, ANCHOR_CONSTRAINS_X)
    end
    label:SetAnchor(RIGHT, tabs, LEFT, -20, 0)
end

local function UpdateDepositDropdownVisibility()
    local dropdown = dropdowns.deposit
    if not dropdown then
        return
    end
    local show = IsVaultDepositLayoutApplied()
    if not show then
        ZO_ComboBox_ObjectFromContainer(dropdown):HideDropdown()
    end
    if show == dropdown:IsHidden() then
        SetActiveLabelAvoidsDropdown(ZO_PlayerInventoryTabs, dropdown, show)
    end
    dropdown:SetHidden(not show)
end

function SHT.InitializeFurnitureVault()
    -- Withdraw: the vault's own list.
    local withdraw = CreateDropdown("withdraw", ZO_FurnitureVault, ZO_FurnitureVaultTabs, INVENTORY_FURNITURE_VAULT)
    SetActiveLabelAvoidsDropdown(ZO_FurnitureVaultTabs, withdraw, true)

    -- Deposit: the backpack, only while the furniture vault layout is applied.
    CreateDropdown("deposit", ZO_PlayerInventory, ZO_PlayerInventoryTabs, INVENTORY_BACKPACK):SetHidden(true)
    SecurePostHook(PLAYER_INVENTORY, "ApplyBackpackLayout", UpdateDepositDropdownVisibility)
    UpdateDepositDropdownVisibility()

    -- Returning true from a ZO_PreHook skips the original and returns nil, i.e. the slot is rejected.
    ZO_PreHook(PLAYER_INVENTORY, "DoesSlotPassAdditionalFilters", function(_, inventory, slot)
        local state = GetStateForInventory(inventory)
        if state and IsFilterActive(state) and slot and slot.bagId then
            return not DoesSlotPass(state, slot.bagId, slot.slotIndex)
        end
        return false
    end)
end
