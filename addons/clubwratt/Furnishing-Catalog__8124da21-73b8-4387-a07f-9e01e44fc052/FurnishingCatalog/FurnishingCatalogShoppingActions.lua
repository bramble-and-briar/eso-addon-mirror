-- FurnishingCatalogShoppingActions.lua: the shopping lists' store and their three dialogs.
--
-- Dialogs are stock gamepad dialogs, shaped after the game's own:
--   add to a list  - a parametric list of the lists, like the inventory's Actions dialog
--                    (GAMEPAD_INVENTORY_ACTIONS_DIALOG in ingamedialogs.lua);
--   name a list    - one text field, like the outfit rename dialog (GAMEPAD_RENAME_OUFIT in
--                    outfit_selector_gamepad.lua);
--   delete a list  - a basic confirmation.
local FC = FurnishingCatalog
local ShoppingUtils = FC.ShoppingUtils
local BrowseUtils = FC.BrowseUtils

local Shopping = {}

Shopping.ADD_DIALOG = "FURNISHING_CATALOG_ADD_TO_LIST"
Shopping.NAME_DIALOG = "FURNISHING_CATALOG_NAME_LIST"
Shopping.DELETE_DIALOG = "FURNISHING_CATALOG_DELETE_LIST"

local dialogsRegistered = false

---The lists, from saved variables (created with the default list on first use).
---@return FurnishingCatalogShoppingStore
function Shopping.Store()
    local savedVars = FC.state.savedVars
    local store = ShoppingUtils.Normalize(savedVars.shopping)
    savedVars.shopping = store
    return store
end

---Tell the player something in the alert corner; chat if alerts are not there.
---@param text string
function Shopping.Notify(text)
    local alert = rawget(_G, "ZO_Alert")
    if not (alert and pcall(alert, UI_ALERT_CATEGORY_ALERT, nil, "<<1>>", text)) then
        FC.Chat(text)
    end
end

---Put an item on a list and say so.
---@param list FurnishingCatalogShoppingList
---@param item FurnishingCatalogItem
---@return boolean added
function Shopping.AddItem(list, item)
    local store = Shopping.Store()
    local added = ShoppingUtils.Add(list, item.id)
    store.lastUsedId = list.id
    if added then
        Shopping.Notify(FC.Fmt("%s added to %s", item.name, list.name))
    else
        Shopping.Notify(FC.Fmt("%s is already on %s", item.name, list.name))
    end
    FC.Log("shopping: %s %d '%s' -> list %d '%s' (%d on it)", added and "added" or "already has", item.id, item.name, list.id, list.name, #list.items)
    return added
end

-- ---------------------------------------------------------------- dialogs

local function RegisterAddDialog()
    local function Setup(dialog, data)
        local parametricList = dialog.info.parametricList
        ZO_ClearNumericallyIndexedTable(parametricList)
        local store = Shopping.Store()
        for _, list in ipairs(ShoppingUtils.OfferOrder(store)) do
            local label = BrowseUtils.CountLabel(list.name, #list.items)
            if ShoppingUtils.IndexOf(list, data.item.id) then
                label = label .. "  (has it)"
            end
            local entryData = ZO_GamepadEntryData:New(label)
            entryData.shoppingList = list
            entryData.setup = ZO_SharedGamepadEntry_OnSetup
            table.insert(parametricList, { template = "ZO_GamepadItemEntryTemplate", entryData = entryData })
        end
        local newEntry = ZO_GamepadEntryData:New("New List")
        newEntry.newShoppingList = true
        newEntry.setup = ZO_SharedGamepadEntry_OnSetup
        table.insert(parametricList, { template = "ZO_GamepadItemEntryTemplate", entryData = newEntry })
        dialog:setupFunc()
    end

    ZO_Dialogs_RegisterCustomDialog(Shopping.ADD_DIALOG,
    {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog, data) FC.SafeCall("AddDialogSetup", Setup, dialog, data) end,
        title = { text = "Add to List" },
        mainText = { text = function(dialog) return dialog.data and dialog.data.item and dialog.data.item.name or "" end },
        parametricList = {}, -- filled on setup
        buttons =
        {
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(SI_DIALOG_CANCEL),
            },
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
                callback = FC.Guard("AddDialogSelect", function(dialog)
                    local data = dialog.data
                    local target = dialog.entryList:GetTargetData()
                    if not (data and target) then
                        return
                    end
                    if target.newShoppingList then
                        -- Name the new list first; the item goes onto it once it exists.
                        Shopping.ShowNameDialog({ item = data.item, onDone = data.onDone })
                    elseif target.shoppingList then
                        Shopping.AddItem(target.shoppingList, data.item)
                        if data.onDone then
                            data.onDone()
                        end
                    end
                end),
            },
        },
    })
end

local function RegisterNameDialog()
    local parametricDialog = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)

    local function Save(dialog)
        local data = dialog.data
        local store = Shopping.Store()
        local list, reason
        if data.list then
            list, reason = ShoppingUtils.Rename(store, data.list.id, data.name)
        else
            list, reason = ShoppingUtils.Create(store, data.name)
        end
        if not list then
            -- The dialog stays open (blockDialogReleaseOnPress) so the name can be changed.
            Shopping.Notify(ShoppingUtils.ReasonText(reason))
            return
        end
        FC.Log("shopping: list %d %s '%s'", list.id, data.list and "renamed to" or "created as", list.name)
        ZO_Dialogs_ReleaseDialogOnButtonPress(Shopping.NAME_DIALOG)
        if data.item then
            Shopping.AddItem(list, data.item)
        end
        if data.onDone then
            data.onDone(list)
        end
    end

    ZO_Dialogs_RegisterCustomDialog(Shopping.NAME_DIALOG,
    {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog) dialog:setupFunc() end,
        title = { text = function(dialog) return dialog.data and dialog.data.list and "Rename List" or "New List" end },
        mainText = { text = FC.Fmt("Up to %d characters.", ShoppingUtils.MAX_NAME_LENGTH) },
        parametricList =
        {
            {
                template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                templateData =
                {
                    nameField = true,
                    textChangedCallback = function(control)
                        if parametricDialog.data then
                            parametricDialog.data.name = control:GetText()
                        end
                    end,
                    setup = function(control, data, selected, reselectingDuringRebuild, enabled, active)
                        control.editBoxControl.textChangedCallback = data.textChangedCallback
                        control.editBoxControl:SetMaxInputChars(ShoppingUtils.MAX_NAME_LENGTH)
                        data.control = control
                        if parametricDialog.data then
                            control.editBoxControl:SetText(parametricDialog.data.name or "")
                        end
                    end,
                    narrationText = rawget(_G, "ZO_GetDefaultParametricListEditBoxNarrationText"),
                },
            },
        },
        blockDialogReleaseOnPress = true,
        buttons =
        {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = FC.Guard("NameDialogEdit", function(dialog)
                    local target = dialog.entryList:GetTargetData()
                    if target and target.control then
                        target.control.editBoxControl:TakeFocus()
                    end
                end),
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = "Save",
                callback = FC.Guard("NameDialogSave", Save),
                clickSound = SOUNDS.DIALOG_ACCEPT,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = function()
                    ZO_Dialogs_ReleaseDialogOnButtonPress(Shopping.NAME_DIALOG)
                end,
            },
        },
    })
end

local function RegisterDeleteDialog()
    ZO_Dialogs_RegisterCustomDialog(Shopping.DELETE_DIALOG,
    {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = "Delete List" },
        mainText =
        {
            text = function(dialog)
                local list = dialog.data and dialog.data.list
                if not list then
                    return ""
                end
                return FC.Fmt("Delete \"%s\" and the %d furnishing(s) on it?", list.name, #list.items)
            end,
        },
        buttons =
        {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_DIALOG_ACCEPT,
                callback = FC.Guard("DeleteDialogAccept", function(dialog)
                    local data = dialog.data
                    local deleted, reason = ShoppingUtils.Delete(Shopping.Store(), data.list.id)
                    if not deleted then
                        Shopping.Notify(ShoppingUtils.ReasonText(reason))
                        return
                    end
                    FC.Log("shopping: list %d '%s' deleted", data.list.id, data.list.name)
                    if data.onDone then
                        data.onDone()
                    end
                end),
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
            },
        },
    })
end

---Register the dialogs, once. Called when the catalog screen is created.
---@return boolean registered
function Shopping.RegisterDialogs()
    if dialogsRegistered then
        return true
    end
    if not (rawget(_G, "ZO_Dialogs_RegisterCustomDialog") and rawget(_G, "GAMEPAD_DIALOGS")) then
        FC.Log("shopping: the gamepad dialog system is not there; lists cannot be edited")
        return false
    end
    RegisterAddDialog()
    RegisterNameDialog()
    RegisterDeleteDialog()
    dialogsRegistered = true
    return true
end

---Ask which list an item goes onto.
---@param item FurnishingCatalogItem
---@param onDone fun()|nil called after the item was put on a list (or found on it already)
function Shopping.ShowAddDialog(item, onDone)
    if Shopping.RegisterDialogs() then
        ZO_Dialogs_ShowGamepadDialog(Shopping.ADD_DIALOG, { item = item, onDone = onDone })
    end
end

---Ask for a list name: a new list, or a new name for options.list.
---@param options { list: FurnishingCatalogShoppingList|nil, item: FurnishingCatalogItem|nil, onDone: fun(list: FurnishingCatalogShoppingList)|nil }
function Shopping.ShowNameDialog(options)
    if Shopping.RegisterDialogs() then
        ZO_Dialogs_ShowGamepadDialog(Shopping.NAME_DIALOG, { list = options.list, item = options.item, onDone = options.onDone, name = options.list and options.list.name or "" })
    end
end

---Ask before deleting a list.
---@param list FurnishingCatalogShoppingList
---@param onDone fun()|nil called after the list was deleted
function Shopping.ShowDeleteDialog(list, onDone)
    if list.id == ShoppingUtils.DEFAULT_ID then
        Shopping.Notify(ShoppingUtils.ReasonText("default"))
        return
    end
    if Shopping.RegisterDialogs() then
        ZO_Dialogs_ShowGamepadDialog(Shopping.DELETE_DIALOG, { list = list, onDone = onDone })
    end
end

FC.Shopping = Shopping
