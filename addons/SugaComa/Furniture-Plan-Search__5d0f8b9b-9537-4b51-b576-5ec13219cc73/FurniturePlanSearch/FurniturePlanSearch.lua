-- Furniture Plan Search 0.2.3 - Update 51 / API 101051 PS5 UAT candidate.
local ADDON_NAME = "FurniturePlanSearch"

local searchText = ""
local patched = false
local stationActive = false
local activeStationType = nil

local function IsSupportedRecipeCategory(provisioner)
    if provisioner.settings == ZO_GamepadProvisioner.EMBEDDED_SETTINGS then
        return provisioner.filterType == PROVISIONER_SPECIAL_INGREDIENT_TYPE_FURNISHING
    end

    if provisioner.settings == ZO_GamepadProvisioner.PROVISIONING_SETTINGS
        and GetCraftingInteractionType() == CRAFTING_TYPE_PROVISIONING then
        return provisioner.filterType == PROVISIONER_SPECIAL_INGREDIENT_TYPE_SPICES
            or provisioner.filterType == PROVISIONER_SPECIAL_INGREDIENT_TYPE_FLAVORING
            or provisioner.filterType == PROVISIONER_SPECIAL_INGREDIENT_TYPE_FURNISHING
    end

    return false
end

local function IsSearchableRecipeMenu(provisioner)
    if not stationActive
        or not IsInGamepadPreferredMode()
        or not provisioner
        or not provisioner.recipeList
        or not GAMEPAD_PROVISIONER_CREATION_SCENE
        or not GAMEPAD_PROVISIONER_CREATION_SCENE:IsShowing() then
        return false
    end

    if GetCraftingInteractionMode() == CRAFTING_INTERACTION_MODE_CONSOLIDATED_STATION then
        return false
    end

    return IsSupportedRecipeCategory(provisioner)
end

local function BuildCurrentCategoryItemNames(stationType, specialIngredientType)
    local namesByItemId = {}
    local recipeLists = PROVISIONER_MANAGER:GetRecipeListData(stationType)

    for _, recipeList in pairs(recipeLists) do
        for _, recipe in ipairs(recipeList.recipes) do
            if recipe.specialIngredientType == specialIngredientType
                and recipe.requiredCraftingStationType == stationType then
                local itemName = zo_strformat(SI_PROVISIONER_RECIPE_NAME_COUNT_NONE, recipe.name)
                if itemName and itemName ~= "" then
                    namesByItemId[recipe.resultItemId] = zo_strlower(itemName)
                end
            end
        end
    end

    return namesByItemId
end

local function RefreshSearchableState()
    local provisioner = GAMEPAD_PROVISIONER
    if not provisioner or not provisioner.searchHeaderFocus then
        return
    end

    local showSearch = IsSearchableRecipeMenu(provisioner)
    provisioner.searchHeaderControl:SetHidden(not showSearch)

    if showSearch then
        local stationType = GetCraftingInteractionType()
        local filterType = provisioner.filterType
        if provisioner.searchStationType ~= stationType or provisioner.searchFilterType ~= filterType then
            provisioner.searchStationType = stationType
            provisioner.searchFilterType = filterType
            provisioner.searchItemNames = nil
        end
        ZO_GamepadGenericHeader_SetHeaderFocusControl(provisioner.header, provisioner.searchHeaderControl, provisioner.searchHeaderFocus)
    else
        provisioner.searchHeaderFocus:Deactivate()
        ZO_GamepadGenericHeader_SetHeaderFocusControl(provisioner.header, nil, nil)
        provisioner.searchStationType = nil
        provisioner.searchFilterType = nil
        provisioner.searchItemNames = nil
    end
end

local function RefreshHeaderAndKeybinds()
    local provisioner = GAMEPAD_PROVISIONER
    if not provisioner then
        return
    end

    RefreshSearchableState()
    ZO_GamepadCraftingUtils_RefreshGenericHeaderData(provisioner)
    KEYBIND_STRIP:UpdateKeybindButtonGroup(provisioner.mainKeybindStripDescriptor)
end

local function ScheduleRecipeMenuRefresh(expectedStationType)
    zo_callLater(function()
        if not stationActive
            or GetCraftingInteractionType() ~= expectedStationType
            or not GAMEPAD_PROVISIONER_CREATION_SCENE
            or not GAMEPAD_PROVISIONER_CREATION_SCENE:IsShowing() then
            return
        end

        RefreshHeaderAndKeybinds()
    end, 0)
end

local function OnSearchTextChanged()
    local provisioner = GAMEPAD_PROVISIONER
    if not provisioner or not provisioner.searchHeaderFocus then
        return
    end

    searchText = zo_strlower(zo_strtrim(provisioner.searchHeaderFocus:GetText()))
    if IsSearchableRecipeMenu(provisioner) then
        provisioner:DirtyRecipeList()
    end
end

local function AddSearchHeader(provisioner)
    if provisioner.searchHeaderControl then
        return
    end

    local searchControl = CreateControlFromVirtual("$(parent)StationPlanSearch", provisioner.header, "ZO_Gamepad_TextSearch_HeaderEditbox")
    provisioner.searchHeaderControl = searchControl
    provisioner.searchHeaderFocus = ZO_TextSearch_Header_Gamepad:New(searchControl, OnSearchTextChanged)
    searchControl:SetDimensions(365, 71)
    provisioner.searchHeaderFocus:RegisterCallback("EditBoxFocusLost", function()
        provisioner.searchHeaderFocus:Deactivate()
        if IsSearchableRecipeMenu(provisioner)
            and not ZO_CraftingUtils_IsPerformingCraftProcess()
            and not ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
            provisioner.recipeList:SetActive(true)
            SCREEN_NARRATION_MANAGER:QueueParametricListEntry(provisioner.recipeList)
        end
    end)
    searchControl:SetHidden(true)
end

local function InstallRecipeFilter()
    if patched or not ZO_SharedProvisioner or not GAMEPAD_PROVISIONER then
        return
    end

    local originalFilter = GAMEPAD_PROVISIONER.DoesRecipePassFilter
    GAMEPAD_PROVISIONER.DoesRecipePassFilter = function(self, specialIngredientType, shouldRequireIngredients, maxIterationsForIngredients, shouldRequireSkills, tradeskillsLevelReqs, qualityReq, craftingInteractionType, requiredCraftingStationType, shouldFilterQuests, resultItemId)
        if not originalFilter(self, specialIngredientType, shouldRequireIngredients, maxIterationsForIngredients, shouldRequireSkills, tradeskillsLevelReqs, qualityReq, craftingInteractionType, requiredCraftingStationType, shouldFilterQuests, resultItemId) then
            return false
        end

        if self == GAMEPAD_PROVISIONER and searchText ~= "" and IsSearchableRecipeMenu(self) then
            if craftingInteractionType ~= self.searchStationType
                or requiredCraftingStationType ~= self.searchStationType
                or specialIngredientType ~= self.searchFilterType then
                return false
            end

            if not self.searchItemNames then
                -- Native RefreshRecipeList has already refreshed the manager. Never
                -- consume its dirty flags inside RecipeDataUpdated callbacks.
                self.searchItemNames = BuildCurrentCategoryItemNames(self.searchStationType, self.searchFilterType)
            end
            local itemName = self.searchItemNames[resultItemId]
            if not itemName or not string.find(itemName, searchText, 1, true) then
                return false
            end
        end

        return true
    end

    patched = true
end

local function InstallSearchKeybind(provisioner)
    for _, descriptor in ipairs(provisioner.mainKeybindStripDescriptor) do
        if descriptor.name == "Furniture Plan Search" then
            return
        end
    end

    table.insert(provisioner.mainKeybindStripDescriptor, {
        name = "Furniture Plan Search",
        keybind = "UI_SHORTCUT_LEFT_STICK",
        gamepadOrder = 1015,
        visible = function()
            return IsSearchableRecipeMenu(provisioner)
                and not ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled()
                and not ZO_CraftingUtils_IsPerformingCraftProcess()
        end,
        callback = function()
            if IsSearchableRecipeMenu(provisioner)
                and not ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled()
                and not ZO_CraftingUtils_IsPerformingCraftProcess() then
                provisioner.recipeList:SetActive(false)
                provisioner.searchHeaderFocus:Activate()
                SCREEN_NARRATION_MANAGER:QueueTextSearchHeader(provisioner.searchHeaderFocus)
                provisioner.searchHeaderFocus:SetFocused(true)
            end
        end,
    })
end

local function ClearStationSearch(provisioner)
    searchText = ""
    activeStationType = nil

    if not provisioner or not provisioner.searchHeaderFocus then
        return
    end

    provisioner.searchHeaderFocus:Deactivate()
    provisioner.searchHeaderFocus:GetEditBox():SetText("", true)
    provisioner.searchHeaderControl:SetHidden(true)
    provisioner.searchStationType = nil
    provisioner.searchFilterType = nil
    provisioner.searchItemNames = nil
    ZO_GamepadGenericHeader_SetHeaderFocusControl(provisioner.header, nil, nil)
    provisioner:DirtyRecipeList()
end

local function OnStationInteract(_, craftingType)
    stationActive = true
    if activeStationType ~= craftingType or searchText ~= "" then
        ClearStationSearch(GAMEPAD_PROVISIONER)
        stationActive = true
    end
    activeStationType = craftingType
end

local function OnEndStationInteract()
    stationActive = false
    ClearStationSearch(GAMEPAD_PROVISIONER)
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    if not GAMEPAD_PROVISIONER or not ZO_SharedProvisioner then
        d("Furniture Plan Search: Update 51 gamepad provisioner UI was not available.")
        return
    end

    AddSearchHeader(GAMEPAD_PROVISIONER)
    InstallSearchKeybind(GAMEPAD_PROVISIONER)
    InstallRecipeFilter()

    local originalTabFilterChanged = GAMEPAD_PROVISIONER.OnTabFilterChanged
    GAMEPAD_PROVISIONER.OnTabFilterChanged = function(self, filterType)
        originalTabFilterChanged(self, filterType)
        RefreshSearchableState()
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor)
        ZO_GamepadCraftingUtils_RefreshGenericHeaderData(self)
    end

    -- Alchemy, enchanting and smithing enter recipes through their own native
    -- mode selectors, then converge here. The native function pushes the scene
    -- before it applies EMBEDDED_SETTINGS, so refresh only after it returns.
    ZO_PostHook(GAMEPAD_PROVISIONER, "EmbedInCraftingScene", function()
        ScheduleRecipeMenuRefresh(GetCraftingInteractionType())
    end)

    GAMEPAD_PROVISIONER_CREATION_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            ScheduleRecipeMenuRefresh(GetCraftingInteractionType())
        elseif newState == SCENE_SHOWN then
            -- The keybind group is fully presented only after the scene transition.
            -- Refresh here so L3 is visible before the player moves the recipe list.
            RefreshHeaderAndKeybinds()
        elseif newState == SCENE_HIDDEN then
            if GAMEPAD_PROVISIONER.searchHeaderFocus then
                GAMEPAD_PROVISIONER.searchHeaderFocus:Deactivate()
                GAMEPAD_PROVISIONER.searchHeaderControl:SetHidden(true)
                ZO_GamepadGenericHeader_SetHeaderFocusControl(GAMEPAD_PROVISIONER.header, nil, nil)
            end
        end
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CRAFTING_STATION_INTERACT, OnStationInteract)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_END_CRAFTING_STATION_INTERACT, OnEndStationInteract)
    PROVISIONER_MANAGER:RegisterCallback("RecipeDataUpdated", function()
        if IsSearchableRecipeMenu(GAMEPAD_PROVISIONER) then
            GAMEPAD_PROVISIONER.searchItemNames = nil
            GAMEPAD_PROVISIONER:DirtyRecipeList()
        end
    end)

    CALLBACK_MANAGER:RegisterCallback("CraftingAnimationsStopped", function()
        if GAMEPAD_PROVISIONER_CREATION_SCENE and GAMEPAD_PROVISIONER_CREATION_SCENE:IsShowing() then
            RefreshHeaderAndKeybinds()
        end
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
