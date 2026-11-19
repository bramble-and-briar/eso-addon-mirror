-- FurnishingCatalogEditorActions.lua: the shopping lists in the housing editor.
--
-- On the Place tab of the housing editor's furniture browser (gamepad) a Shopping Lists button
-- opens a prompt with the lists. Choosing one shows only the furnishings on it, in the game's
-- own categories, until All Furnishings is chosen, the game's Reset Filters is pressed or the
-- house changes (which is when the game drops its own filters).
--
-- The filter uses the game's own seam: the Place tab's tree is built by
-- SHARED_FURNITURE:BuildCategoryTreeData, which takes an optional test per furnishing. Beside
-- it, three more methods of that one object are wrapped so the game counts the list as one of
-- its filters: "is the tree filtered", "is there anything to reset" and "reset".
-- Set up when the add-on loads: it has to work without the catalog having been opened.
local FC = FurnishingCatalog
local EditorUtils = FC.EditorUtils
local ShoppingUtils = FC.ShoppingUtils
local Shopping = FC.Shopping

local Editor = {}

Editor.PICK_DIALOG = "FURNISHING_CATALOG_EDITOR_PICK"
Editor.KEYBIND = "UI_SHORTCUT_SECONDARY" -- free on the Place tab's two lists and on its search box

local EVENT_NAMESPACE = "FurnishingCatalogEditor"

local hooked = false
local hookState = "not set up yet"
local dialogRegistered = false
local activeListId = nil     -- the list being shown
local appliedSignature = nil -- that list's contents when the Place tab's tree was last asked to rebuild
local pendingChoice = nil    -- { listId } chosen in the prompt, applied once the prompt has closed

---@return table|nil manager the game's furniture manager
local function Manager()
    local manager = rawget(_G, "SHARED_FURNITURE")
    return type(manager) == "table" and manager or nil
end

---@return table|nil browser the housing editor's gamepad furniture browser
local function Browser()
    local browser = rawget(_G, "GAMEPAD_HOUSING_FURNITURE_BROWSER")
    return type(browser) == "table" and browser or nil
end

---The item id of a furnishing of the Place tab; a collectible has none.
---@param furniture table a ZO_PlaceableFurnitureItem or ZO_PlaceableFurnitureCollectible
---@return integer|nil
local function ItemIdOf(furniture)
    if furniture.bagId and furniture.slotIndex then
        return GetItemId(furniture.bagId, furniture.slotIndex)
    end
    return nil
end

---The item ids of every furnishing the player has to place (backpack, bank, storage).
---@return table<integer, boolean>
local function HeldIds()
    local held = {}
    local manager = Manager()
    if not manager then
        return held
    end
    for _, bag in pairs(manager:GetPlaceableFurnitureCache(ZO_PLACEABLE_TYPE_ITEM)) do
        for _, furniture in pairs(bag) do
            local itemId = ItemIdOf(furniture)
            if itemId then
                held[itemId] = true
            end
        end
    end
    return held
end

---The list being shown; nil while everything shows, and once that list has been deleted.
---@return FurnishingCatalogShoppingList|nil
function Editor.ActiveList()
    if not activeListId then
        return nil
    end
    return (ShoppingUtils.Find(Shopping.Store(), activeListId))
end

---Show only the furnishings on a list on the Place tab, or everything again.
---@param listId integer|nil
function Editor.Show(listId)
    local manager, browser = Manager(), Browser()
    if not (hooked and manager and browser) then
        return
    end
    activeListId = listId
    local list = Editor.ActiveList()
    if not list then
        activeListId = nil
    end
    appliedSignature = EditorUtils.Signature(list)
    -- The cursor remembered per category is a row of the tree as it was.
    browser.placementPanel:ResetSavedPositions()
    -- What the game does when one of its own filters changes: rebuild the tree, tell the lists.
    manager:OnPlacementFiltersChanged()
    -- With nothing to show the cursor sits in the search box, whose buttons are on the strip then.
    local searchButtons = browser.textSearchKeybindStripDescriptor
    if KEYBIND_STRIP:HasKeybindButtonGroup(searchButtons) then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(searchButtons)
    end
    FC.Log("editor: the Place tab shows %s", list and FC.Fmt("list %d '%s' (%d on it)", list.id, list.name, #list.items) or "everything")
end

-- ---------------------------------------------------------------- the prompt

local function RegisterDialog()
    if dialogRegistered then
        return true
    end
    if not (rawget(_G, "ZO_Dialogs_RegisterCustomDialog") and rawget(_G, "GAMEPAD_DIALOGS")) then
        return false
    end

    local function Setup(dialog)
        local parametricList = dialog.info.parametricList
        ZO_ClearNumericallyIndexedTable(parametricList)
        local activeList = Editor.ActiveList()
        local rows = EditorUtils.Rows(Shopping.Store(), activeList and activeList.id or nil, HeldIds())
        for _, row in ipairs(rows) do
            local entryData = ZO_GamepadEntryData:New(row.label)
            entryData.shoppingList = row.list
            entryData.showAll = row.showAll
            entryData.setup = ZO_SharedGamepadEntry_OnSetup
            table.insert(parametricList, { template = "ZO_GamepadItemEntryTemplate", entryData = entryData })
        end
        dialog:setupFunc()
        FC.Log("editor: prompt with %d row(s), showing %s", #rows, activeList and activeList.name or "everything")
    end

    ZO_Dialogs_RegisterCustomDialog(Editor.PICK_DIALOG,
    {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog) FC.SafeCall("EditorDialogSetup", Setup, dialog) end,
        title = { text = EditorUtils.BUTTON_NAME },
        mainText = { text = "Show only the furnishings on one list. Each list says how many of its furnishings you have to place." },
        parametricList = {}, -- filled on setup
        -- Called once the prompt has closed and the Place tab has its buttons back: the lists
        -- are rebuilt then, as they would be under no prompt.
        finishedCallback = FC.Guard("EditorDialogFinished", function()
            local pending = pendingChoice
            pendingChoice = nil
            if pending then
                Editor.Show(pending.listId)
            end
        end),
        buttons =
        {
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(SI_DIALOG_CANCEL),
            },
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
                callback = FC.Guard("EditorChoose", function(dialog)
                    local target = dialog.entryList:GetTargetData()
                    if target and target.shoppingList then
                        pendingChoice = { listId = target.shoppingList.id }
                    elseif target and target.showAll then
                        pendingChoice = { listId = nil }
                    end
                end),
            },
        },
    })
    dialogRegistered = true
    return true
end

---Open the prompt (the Shopping Lists button on the housing editor's Place tab).
---@return boolean shown
function Editor.ShowPicker()
    pendingChoice = nil
    if not Editor.ActiveList() and ShoppingUtils.NumListed(Shopping.Store()) == 0 then
        Shopping.Notify("Your shopping lists are empty. Add furnishings in the catalog: /furn")
        return false
    end
    if not RegisterDialog() then
        FC.Log("editor: the gamepad dialog system is not there; no prompt")
        return false
    end
    ZO_Dialogs_ShowGamepadDialog(Editor.PICK_DIALOG, {})
    return true
end

-- ---------------------------------------------------------------- set-up

---The test the Place tab's tree is built with: the game's own, narrowed to the list being shown.
---@param manager table
---@param categoryTreeData table the tree being built
---@param filterFunction (fun(furniture: table): boolean)|nil the game's own optional test
---@return (fun(furniture: table): boolean)|nil
local function FilterFor(manager, categoryTreeData, filterFunction)
    if categoryTreeData ~= manager.placeableFurnitureCategoryTreeData then
        return filterFunction
    end
    local list = Editor.ActiveList()
    if not list then
        return filterFunction
    end
    return EditorUtils.ComposeFilter(EditorUtils.IdSet(list), ItemIdOf, filterFunction)
end

---Wrap the four methods of the game's furniture manager that make up a filter. The wrappers sit
---on the object itself; its class is left as the game made it.
---@param manager table
local function HookManager(manager)
    local buildTree = manager.BuildCategoryTreeData
    manager.BuildCategoryTreeData = function(self, categoryTreeData, data, theme, filterFunction)
        local ok, narrowed = FC.SafeCall("EditorFilter", FilterFor, self, categoryTreeData, filterFunction)
        if ok then
            filterFunction = narrowed
        end
        return buildTree(self, categoryTreeData, data, theme, filterFunction)
    end

    -- "Is the Place tab's tree filtered": the game asks when a furnishing leaves a tree it is
    -- not in, and a filtered tree is allowed to lack it.
    local refreshFilterState = manager.RefreshPlacementFilterState
    manager.RefreshPlacementFilterState = function(self)
        refreshFilterState(self)
        if activeListId then
            self.isPlaceableFiltered = true
        end
    end

    -- "Is there anything to reset": the Reset Filters button of the game's Options prompt.
    local canReset = manager.CanResetFurnitureFilters
    manager.CanResetFurnitureFilters = function(self)
        return activeListId ~= nil or canReset(self)
    end

    -- "Reset": that button, and every change of house.
    local reset = manager.ResetFurnitureFilters
    manager.ResetFurnitureFilters = function(self)
        local wasShowingList = activeListId ~= nil
        activeListId, appliedSignature = nil, nil
        reset(self)
        if wasShowingList then
            -- The game rebuilds the tree only where one of its own filters changed.
            self:OnPlacementFiltersChanged()
        end
    end
end

---@param browser table|nil nil for a button that is always there; the browser for one that shows on the Place tab only
---@return table descriptor
local function NewButton(browser)
    return {
        name = function() return EditorUtils.ButtonName(Editor.ActiveList()) end,
        keybind = Editor.KEYBIND,
        callback = FC.Guard("EditorShowPicker", function() Editor.ShowPicker() end),
        visible = browser and function() return browser:GetMode() == HOUSING_BROWSER_MODE.PLACEMENT end or nil,
    }
end

---Put the Shopping Lists button on the Place tab: on its category list, on its furnishing list,
---and on the browser's search box, where the cursor sits while a list has nothing to show.
---@param browser table
---@return boolean added
local function HookKeybinds(browser)
    local panel = browser.placementPanel
    local groups = { panel.categoryKeybindStripDescriptor, panel.furnitureKeybindStripDescriptor, browser.textSearchKeybindStripDescriptor }
    for index = 1, 3 do
        if type(groups[index]) ~= "table" then
            hookState = "the housing editor's Place tab has no buttons to add to"
            return false
        end
        for _, descriptor in ipairs(groups[index]) do
            if type(descriptor) == "table" and descriptor.keybind == Editor.KEYBIND then
                hookState = "its button is taken on the housing editor's Place tab"
                return false
            end
        end
    end
    for index, group in ipairs(groups) do
        -- A group that is on the strip right now is taken off around the change, so the strip
        -- never holds a group it has not seen whole.
        local onStrip = KEYBIND_STRIP:HasKeybindButtonGroup(group)
        if onStrip then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
        end
        -- The search box is every tab's; the two lists are the Place tab's own.
        table.insert(group, NewButton(index == 3 and browser or nil))
        if onStrip then
            KEYBIND_STRIP:AddKeybindButtonGroup(group)
        end
    end
    return true
end

---A list edited in the catalog while it is being shown here: the Place tab catches up as the
---browser opens.
local function OnBrowserSceneStateChange(_oldState, newState)
    if newState == SCENE_SHOWING and activeListId and EditorUtils.Signature(Editor.ActiveList()) ~= appliedSignature then
        Editor.Show(activeListId)
    end
end

---@return boolean hooked
local function SetUp()
    if hooked then
        return true
    end
    local manager, browser = Manager(), Browser()
    local scene = rawget(_G, "GAMEPAD_HOUSING_FURNITURE_BROWSER_SCENE")
    if not (manager and manager.BuildCategoryTreeData and browser and type(browser.placementPanel) == "table" and type(scene) == "table") then
        hookState = "the housing editor's furniture browser is not there"
        return false
    end
    if not HookKeybinds(browser) then
        return false
    end
    HookManager(manager)
    scene:RegisterCallback("StateChange", FC.Guard("EditorSceneState", OnBrowserSceneStateChange))
    hooked = true
    hookState = "Shopping Lists button on the housing editor's Place tab"
    return true
end

---Set up at load; tried again each time the housing editor changes mode, until it holds.
function Editor.Initialize()
    SetUp()
    FC.Log("editor: %s", hookState)
    if not hooked then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_HOUSING_EDITOR_MODE_CHANGED, function()
            local ok, isHooked = FC.SafeCall("EditorSetUp", SetUp)
            if ok and isHooked then
                EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_HOUSING_EDITOR_MODE_CHANGED)
            end
            FC.Log("housing editor changed mode: %s", hookState)
        end)
    end
end

---@return string
function Editor.StateText()
    local list = Editor.ActiveList()
    if list then
        return FC.Fmt("%s, showing %s", hookState, list.name)
    end
    return hookState
end

FC.Editor = Editor
