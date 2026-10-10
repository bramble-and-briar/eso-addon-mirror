-- Search box for furnishing recipes: the Recipes tab at every crafting station and the Furnishings tab
-- at the provisioning station. All of them are the same keyboard ZO_Provisioner screen.

local FURNISHING = PROVISIONER_SPECIAL_INGREDIENT_TYPE_FURNISHING
-- Offsets below the top divider. Nudge these if the box overlaps the checkboxes or the list.
local BOX_OFFSET_Y, LIST_OFFSET_Y_WITH_BOX, LIST_OFFSET_Y_DEFAULT = 38, 74, 40

local function Setup()
    local filters = PROVISIONER.provisioningFiltersControl
    local topDivider = PROVISIONER.control:GetNamedChild("MenuBarDivider")
    local listDivider = filters:GetNamedChild("NavigationDivider") -- the recipe list hangs off this

    local backdrop = CreateControlFromVirtual("CraftSearchBox", filters, "ZO_InventorySearchTemplate")
    backdrop:SetWidth(300)
    backdrop:SetAnchor(TOPLEFT, topDivider, BOTTOMLEFT, 50, BOX_OFFSET_Y)
    local box = backdrop:GetNamedChild("Box")
    box:SetHandler("OnTextChanged", function() PROVISIONER:DirtyRecipeList() end)
    box:SetHandler("OnEnter", function(self) self:LoseFocus() end)

    -- Show only on the furnishing tab, pushing the recipe list down to make room.
    local function Sync(provisioner)
        local show = provisioner.filterType == FURNISHING
        backdrop:SetHidden(not show)
        listDivider:ClearAnchors()
        listDivider:SetAnchor(TOPLEFT, topDivider, BOTTOMLEFT, 0, show and LIST_OFFSET_Y_WITH_BOX or LIST_OFFSET_Y_DEFAULT)
    end
    Sync(PROVISIONER)
    ZO_PostHook(ZO_Provisioner, "OnTabFilterChanged", Sync)

    -- DoesRecipePassFilter only gets the result item id, so map ids to names first (same data call the list makes).
    local names = {}
    ZO_PreHook(ZO_Provisioner, "RefreshRecipeList", function()
        for _, list in pairs(PROVISIONER_MANAGER:GetRecipeListData(GetCraftingInteractionType())) do
            for _, recipe in ipairs(list.recipes) do
                names[recipe.resultItemId] = zo_strlower(recipe.name)
            end
        end
    end)

    -- Returning true skips the original check, which hides the recipe.
    ZO_PreHook(ZO_Provisioner, "DoesRecipePassFilter", function(self, ...)
        local text = zo_strlower(box:GetText())
        if text == "" or self.filterType ~= FURNISHING then return false end
        local resultItemId = select(10, ...)
        return not (names[resultItemId] or ""):find(text, 1, true)
    end)
end

EVENT_MANAGER:RegisterForEvent("CraftSearch", EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= "CraftSearch" then return end
    EVENT_MANAGER:UnregisterForEvent("CraftSearch", EVENT_ADD_ON_LOADED)
    Setup()
end)
