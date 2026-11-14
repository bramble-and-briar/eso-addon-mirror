-- Additional gamepad recipe filters for provisioning and furnishing plans.
-- The game's own filter still decides craftability, skills and quest relevance.
local DIALOG_NAME = "KELA_RECIPE_FILTERS"
local RETRY_EVENT_NAME = "KelaPadUI_RecipeFilters"
local states =
{
    provisioning = { text = "", qualities = {}, levels = {} },
    furnishing = { text = "", qualities = {}, levels = {} },
}
local qualityOptions =
{
    { id = ITEM_DISPLAY_QUALITY_NORMAL, label = KELA_RECIPE_FILTER_NORMAL },
    { id = ITEM_DISPLAY_QUALITY_MAGIC, label = KELA_RECIPE_FILTER_FINE },
    { id = ITEM_DISPLAY_QUALITY_ARCANE, label = KELA_RECIPE_FILTER_SUPERIOR },
    { id = ITEM_DISPLAY_QUALITY_ARTIFACT, label = KELA_RECIPE_FILTER_EPIC },
    { id = ITEM_DISPLAY_QUALITY_LEGENDARY, label = KELA_RECIPE_FILTER_LEGENDARY },
}
local levelOptions =
{
    { id = "high", label = KELA_RECIPE_FILTER_CP150 },
    { id = "unique", label = KELA_RECIPE_FILTER_UNIQUE },
    { id = "other", label = KELA_RECIPE_FILTER_OTHER_LEVELS },
}
local initialized = false
local retryRegistered = false
local queues = {}

local function AnySelected(selections)
    return next(selections) ~= nil
end

-- Re-read the native provisioner saved vars so the game's own filter tables
-- match the add-on selections.  Refresh() handles DirtyRecipeList().
local function SyncBaseFilters(screen)
    if screen.SetupSavedVars then
        screen:SetupSavedVars()
    end
    ZO_SavePlayerConsoleProfile()
end

local function GetState(specialIngredientType)
    if specialIngredientType == PROVISIONER_SPECIAL_INGREDIENT_TYPE_FURNISHING then
        return states.furnishing
    end
    return states.provisioning
end

local function HasFilters(state, screen)
    local savedVars = screen.savedVars
    return state.text ~= "" or AnySelected(state.qualities) or AnySelected(state.levels)
        or (savedVars and (savedVars.haveIngredientsChecked or savedVars.haveSkillsChecked or savedVars.questsOnlyChecked))
end

-- Delicacies are the game's "unique" dishes: event and DLC recipes with unique
-- effects.  Index 15 is the current provisioning list; the English list name is
-- a fallback in case the index moves between game versions.
local DELICACIES_RECIPE_LIST = 15
local function IsDelicacy(recipe)
    return recipe.recipeListIndex == DELICACIES_RECIPE_LIST or recipe.recipeListName == "Delicacies"
end

local function MatchesRecipe(recipe, state, furnishing, screen)
    if state.text ~= "" then
        local name = recipe.name
        if type(name) ~= "string" or not zo_plainstrfind(zo_strlower(name), zo_strlower(state.text)) then
            return false
        end
    end
    if AnySelected(state.qualities) and not state.qualities[recipe.displayQuality or recipe.quality] then
        return false
    end
    local savedVars = screen.savedVars
    if savedVars and savedVars.haveIngredientsChecked and (recipe.maxIterationsForIngredients or 0) <= 0 then return false end
    if savedVars and savedVars.haveSkillsChecked and (not recipe.passesTradeskillLevelReqs or not recipe.passesQualityLevelReq) then return false end
    if savedVars and savedVars.questsOnlyChecked and not (screen.questRecipes and screen.questRecipes[recipe.resultItemId]) then return false end
    if not furnishing and AnySelected(state.levels) then
        local levelGroup = IsDelicacy(recipe) and "unique"
        if not levelGroup then
            local link = GetRecipeResultItemLink(recipe.recipeListIndex, recipe.recipeIndex)
            if not link or link == "" then
                return false
            end
            local cp = GetItemLinkRequiredChampionPoints(link)
            if type(cp) ~= "number" then
                return false
            end
            levelGroup = cp >= 150 and cp <= 160 and "high" or "other"
        end
        if not state.levels[levelGroup] then
            return false
        end
    end
    return true
end

-- RefreshRecipeList iterates these same lists and calls the pure data predicate
-- once per recipe.  Queues preserve the order even if recipes share a result ID.
local function PrepareRecipeQueues(screen, manager, craftingType)
    queues = {}
    if not GAMEPAD_PROVISIONER_CREATION_SCENE or not GAMEPAD_PROVISIONER_CREATION_SCENE:IsShowing()
        or craftingType ~= GetCraftingInteractionType() then
        return
    end
    for _, recipeList in pairs(manager.recipeLists or {}) do
        for _, recipe in ipairs(recipeList.recipes or {}) do
            if recipe.resultItemId and recipe.requiredCraftingStationType == craftingType
                and recipe.specialIngredientType == screen.filterType then
                local queue = queues[recipe.resultItemId]
                if not queue then
                    queue = { nextIndex = 1 }
                    queues[recipe.resultItemId] = queue
                end
                queue[#queue + 1] = recipe
            end
        end
    end
end

local function MakeCheckbox(label, selections, key, header, onChange, quality, screen)
    local text = GetString(label)
    if quality then text = GetItemQualityColor(quality):Colorize(text) end
    return
    {
        template = "ZO_CheckBoxTemplate_WithoutIndent_Gamepad",
        text = text,
        header = header and GetString(header) or nil,
        templateData =
        {
            checked = function()
                if screen then
                    local savedVars = screen.savedVars
                    return savedVars and savedVars[key] == true
                end
                return selections[key] == true
            end,
            setChecked = function(_, checked)
                if screen then
                    local savedVars = screen.savedVars
                    if savedVars then
                        savedVars[key] = checked == true
                        SyncBaseFilters(screen)
                    end
                else
                    selections[key] = checked and true or nil
                end
                onChange()
            end,
            setup = ZO_GamepadCheckBoxTemplate_Setup,
            callback = function(dialog)
                local control = dialog.entryList:GetTargetControl()
                if control then
                    ZO_GamepadCheckBoxTemplate_OnClicked(control)
                end
            end,
            narrationText = function(data)
                return ZO_FormatToggleNarrationText(data.text, data.checked(data))
            end,
        },
    }
end

local function RegisterDialog(screen)
    local dialogControl = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
    local function Refresh()
        zo_callLater(function()
            if GAMEPAD_PROVISIONER_CREATION_SCENE and GAMEPAD_PROVISIONER_CREATION_SCENE:IsShowing() then
                screen:DirtyRecipeList()
                KEYBIND_STRIP:UpdateKeybindButtonGroup(screen.mainKeybindStripDescriptor)
            end
        end, 0)
    end

    ZO_Dialogs_RegisterCustomDialog(DIALOG_NAME,
    {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = KELA_RECIPE_FILTER_TITLE },
        setup = function(dialog)
            local entries = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(entries)
            local draft = dialog.data
            table.insert(entries,
            {
                template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                templateData =
                {
                    setup = function(control, data, selected)
                        control.highlight:SetHidden(not selected)
                        control.editBoxControl.textChangedCallback = function(edit)
                            if dialogControl.data then
                                dialogControl.data.text = edit:GetText()
                                dialogControl.data.state.text = dialogControl.data.text
                                Refresh()
                            end
                        end
                        control.editBoxControl:SetMaxInputChars(100)
                        control.editBoxControl:SetDefaultText(GetString(KELA_RECIPE_FILTER_SEARCH_HINT))
                        control.editBoxControl:SetText(draft.text or "")
                        data.control = control
                    end,
                    callback = function(activeDialog)
                        local control = activeDialog.entryList:GetTargetControl()
                        if control and control.editBoxControl then
                            control.editBoxControl:TakeFocus()
                        end
                    end,
                    narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
                },
            })
            for index, option in ipairs(qualityOptions) do
                table.insert(entries, MakeCheckbox(option.label, draft.qualities, option.id,
                    index == 1 and KELA_RECIPE_FILTER_QUALITY_HEADER or nil, Refresh, option.id))
            end
            if not draft.furnishing then
                for index, option in ipairs(levelOptions) do
                    table.insert(entries, MakeCheckbox(option.label, draft.levels, option.id,
                        index == 1 and KELA_RECIPE_FILTER_LEVEL_HEADER or nil, Refresh))
                end
            end
            table.insert(entries, MakeCheckbox(KELA_RECIPE_FILTER_INGREDIENTS, nil, "haveIngredientsChecked",
                KELA_RECIPE_FILTER_BASE_HEADER, Refresh, nil, screen))
            table.insert(entries, MakeCheckbox(KELA_RECIPE_FILTER_SKILLS, nil, "haveSkillsChecked", nil, Refresh, nil, screen))
            table.insert(entries, MakeCheckbox(KELA_RECIPE_FILTER_QUESTS, nil, "questsOnlyChecked", nil, Refresh, nil, screen))
            table.insert(entries,
            {
                template = "ZO_GamepadMenuEntryTemplate",
                templateData =
                {
                    text = GetString(KELA_RECIPE_FILTER_CLEAR),
                    setup = ZO_SharedGamepadEntry_OnSetup,
                    callback = function(activeDialog)
                        activeDialog.data.text = ""
                        local state = activeDialog.data.state
                        state.text = ""
                        ZO_ClearTable(state.qualities)
                        ZO_ClearTable(state.levels)
                        local savedVars = screen.savedVars
                        if savedVars then
                            savedVars.haveIngredientsChecked = false
                            savedVars.haveSkillsChecked = false
                            savedVars.questsOnlyChecked = false
                            SyncBaseFilters(screen)
                        end
                        Refresh()
                        activeDialog:setupFunc()
                    end,
                },
            })
            dialog:setupFunc()
        end,
        parametricList = {},
        blockDialogReleaseOnPress = true,
        buttons =
        {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = function(dialog)
                    local data = dialog.entryList:GetTargetData()
                    if data and data.callback then
                        data.callback(dialog)
                    end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_GAMEPAD_BACK_OPTION,
                callback = function()
                    ZO_Dialogs_ReleaseDialogOnButtonPress(DIALOG_NAME)
                end,
            },
        },
    })
end

function KelaSetupRecipeFilters()
    if initialized then
        return
    end
    local screen = GAMEPAD_PROVISIONER
    if not screen or not screen.DoesRecipePassFilter or not screen.mainKeybindStripDescriptor
        or not PROVISIONER_MANAGER or not PROVISIONER_MANAGER.GetRecipeListData
        or not GAMEPAD_PROVISIONER_CREATION_SCENE then
        if not retryRegistered then
            retryRegistered = true
            EVENT_MANAGER:RegisterForEvent(RETRY_EVENT_NAME, EVENT_CRAFTING_STATION_INTERACT, function()
                zo_callLater(KelaSetupRecipeFilters, 0)
            end)
        end
        return
    end
    initialized = true
    if retryRegistered then
        EVENT_MANAGER:UnregisterForEvent(RETRY_EVENT_NAME, EVENT_CRAFTING_STATION_INTERACT)
        retryRegistered = false
    end
    RegisterDialog(screen)
    SecurePostHook(PROVISIONER_MANAGER, "GetRecipeListData", function(manager, craftingType)
        PrepareRecipeQueues(screen, manager, craftingType)
    end)
    -- This is a pure data predicate.  Returning true from the pre-hook rejects
    -- an entry; otherwise the game's own predicate still runs unchanged.
    ZO_PreHook(screen, "DoesRecipePassFilter", function(_, specialType, _, _, _, _, _, _, _, _, resultItemId)
        if not GAMEPAD_PROVISIONER_CREATION_SCENE:IsShowing() then
            return false
        end
        local queue = queues[resultItemId]
        local recipe = queue and queue[queue.nextIndex]
        if not recipe then
            return false
        end
        queue.nextIndex = queue.nextIndex + 1
        return not MatchesRecipe(recipe, GetState(specialType), specialType == PROVISIONER_SPECIAL_INGREDIENT_TYPE_FURNISHING, screen)
    end)
    table.insert(screen.mainKeybindStripDescriptor,
    {
        keybind = kpuiConst.GamepadFilterKeybind,
        name = function()
            local label = GetString(KELA_RECIPE_FILTER_TITLE)
            return HasFilters(GetState(screen.filterType), screen) and (label .. " *") or label
        end,
        visible = function()
            return GAMEPAD_PROVISIONER_CREATION_SCENE:IsShowing() and not ZO_CraftingUtils_IsPerformingCraftProcess()
        end,
        callback = function()
            local furnishing = screen.filterType == PROVISIONER_SPECIAL_INGREDIENT_TYPE_FURNISHING
            local state = GetState(screen.filterType)
            ZO_Dialogs_ShowGamepadDialog(DIALOG_NAME,
            {
                furnishing = furnishing,
                text = state.text,
                state = state,
                qualities = state.qualities,
                levels = state.levels,
            })
        end,
    })
    -- Generic dialogs restore their saved keybind state after their own hidden
    -- callbacks.  Refresh only once that restoration has completed, for both
    -- Apply and Cancel, and only while the recipe list is active.
    CALLBACK_MANAGER:RegisterCallback("OnGamepadDialogHidden", function(name)
        if name ~= DIALOG_NAME then
            return
        end
        zo_callLater(function()
            if not GAMEPAD_DIALOG_SHOWING and GAMEPAD_PROVISIONER_CREATION_SCENE:IsShowing()
                and screen.recipeList and screen.recipeList:IsActive() then
                if KEYBIND_STRIP:HasKeybindButtonGroup(screen.mainKeybindStripDescriptor) then
                    KEYBIND_STRIP:UpdateKeybindButtonGroup(screen.mainKeybindStripDescriptor)
                else
                    KEYBIND_STRIP:AddKeybindButtonGroup(screen.mainKeybindStripDescriptor)
                end
            end
        end, 0)
    end)
end
