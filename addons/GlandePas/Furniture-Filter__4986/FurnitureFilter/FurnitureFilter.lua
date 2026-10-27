local ADDON_NAME = "FurnitureFilter"

local FURNISHING = PROVISIONER_SPECIAL_INGREDIENT_TYPE_FURNISHING
-- ZOS anchors the recipe list's divider 40px below the tab divider; at the provisioning station we push it and the
-- filter checkboxes down to make room for the search box and a separator
local DIVIDER_OFFSET_Y = 40
local SEARCH_ROW_HEIGHT = 40
-- Same indent as ZOS's filter checkboxes
local SEARCH_OFFSET_X = 50

local searchText = ""
local nameByItemId = {}

local function MatchesSearch(resultItemId)
    local name = nameByItemId[resultItemId]
    return name ~= nil and zo_plainstrfind(name, searchText)
end

-- Runs before ZOS rebuilds the recipe tree: cache the lowercase display names of the station's furnishing recipes
local function OnRefreshRecipeList()
    ZO_ClearTable(nameByItemId)
    if searchText == "" or PROVISIONER.filterType ~= FURNISHING then
        return
    end
    for _, recipeList in pairs(PROVISIONER_MANAGER:GetRecipeListData(GetCraftingInteractionType())) do
        for _, recipe in ipairs(recipeList.recipes) do
            if recipe.specialIngredientType == FURNISHING then
                nameByItemId[recipe.resultItemId] = zo_strlower(ZO_CachedStrFormat("<<1>>", recipe.name))
            end
        end
    end
end

-- Wraps ZOS's filter: our search only narrows down recipes that already pass ZOS's own filters.
-- Wrapped by hand because ZO_PreHook/ZO_PostHook can't use or change the original's return value.
local function WrapRecipeFilter()
    local originalDoesRecipePassFilter = PROVISIONER.DoesRecipePassFilter
    function PROVISIONER:DoesRecipePassFilter(specialIngredientType, ...)
        if not originalDoesRecipePassFilter(self, specialIngredientType, ...) then
            return false
        end
        if searchText == "" or specialIngredientType ~= FURNISHING then
            return true
        end
        -- resultItemId is the last of the 10 arguments
        return MatchesSearch(select(9, ...))
    end
end

local function Initialize()
    local filters = PROVISIONER.provisioningFiltersControl
    local navigationDivider = filters:GetNamedChild("NavigationDivider")
    local menuBarDivider = PROVISIONER.control:GetNamedChild("MenuBarDivider")

    local search = CreateControlFromVirtual("FurnitureFilterSearch", PROVISIONER.control, "FurnitureFilter_SearchTemplate")
    search:SetHidden(true)

    -- Takes the recipe list divider's original place, between the search box and the checkboxes
    local separator = CreateControlFromVirtual("FurnitureFilterSeparator", PROVISIONER.control, "ZO_WideHorizontalDivider")
    separator:SetAnchor(TOPLEFT, menuBarDivider, BOTTOMLEFT, 0, DIVIDER_OFFSET_Y)
    separator:SetHidden(true)

    local searchBox = search:GetNamedChild("Box")
    searchBox:SetHandler("OnTextChanged", function(editBox)
        searchText = zo_strlower(zo_strtrim(editBox:GetText()))
        PROVISIONER:DirtyRecipeList()
    end)

    -- The provisioning station has no room on the tab row, so the box gets its own row above the checkboxes.
    -- Other stations embed only the Furnishings tab, leaving room on the tab row next to its label.
    local function UpdateLayout()
        local isFurnishing = PROVISIONER.filterType == FURNISHING
        local needsOwnRow = isFurnishing and PROVISIONER.settings == ZO_Provisioner.PROVISIONING_SETTINGS
        local shiftY = needsOwnRow and SEARCH_ROW_HEIGHT or 0
        search:SetHidden(not isFurnishing)
        separator:SetHidden(not needsOwnRow)
        search:ClearAnchors()
        if needsOwnRow then
            search:SetAnchor(BOTTOMLEFT, separator, TOPLEFT, SEARCH_OFFSET_X, -6)
        else
            search:SetAnchor(LEFT, menuBarDivider, LEFT, SEARCH_OFFSET_X, 0, ANCHOR_CONSTRAINS_X)
            search:SetAnchor(LEFT, PROVISIONER.activeTab, LEFT, 0, 0, ANCHOR_CONSTRAINS_Y)
        end
        filters:ClearAnchors()
        filters:SetAnchor(TOPLEFT, menuBarDivider, TOPLEFT, 0, shiftY)
        navigationDivider:ClearAnchors()
        navigationDivider:SetAnchor(TOPLEFT, menuBarDivider, BOTTOMLEFT, 0, DIVIDER_OFFSET_Y + shiftY)
    end

    SecurePostHook(PROVISIONER, "ConfigureFromSettings", UpdateLayout)
    SecurePostHook(PROVISIONER, "OnTabFilterChanged", UpdateLayout)
    ZO_PreHook(PROVISIONER, "RefreshRecipeList", OnRefreshRecipeList)
    WrapRecipeFilter()
    UpdateLayout()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
