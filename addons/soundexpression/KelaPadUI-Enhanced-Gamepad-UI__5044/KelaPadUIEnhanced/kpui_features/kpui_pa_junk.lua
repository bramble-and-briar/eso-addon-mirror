-- KelaPadUI PersonalAssistant junk integration
-- Adds a mark/unmark as permanent junk action to the gamepad inventory
-- actions list (the dialog where "Link in Chat" lives), grouped under a
-- "Personal Assistant" header.  PersonalAssistant itself has no gamepad
-- support, so the action is added from here.
--
-- Everything in this file is optional: without PersonalAssistant installed,
-- or with PA's custom junk rules disabled, no action is added.

local KELA_PA_JUNK_SETTING = KELA_SETTING_PANEL_FEATURES_PA_JUNK

local installed = false
local actionDialogHookInstalled = false

local function IsPAJunkSettingEnabled()
    return KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_PA_JUNK_SETTING)
end

-- Returns PA's junk table and its exported permanent-junk API, or nil when
-- PersonalAssistant is not loaded (or too old to export the API).
local function GetPermanentJunkAPI()
    local junk = PersonalAssistant and PersonalAssistant.Junk
    local custom = junk and junk.Custom
    if custom and custom.isItemPermanentJunk and custom.addItemLinkToPermanentJunk
        and custom.removeItemLinkFromPermanentJunk and custom.isItemLinkPermanentJunk then
        return junk, custom
    end
    return nil, nil
end

local function IsPACustomJunkEnabled(junk)
    local savedVars = junk and junk.SavedVars
    local customSavedVars = savedVars and savedVars.Custom
    return customSavedVars ~= nil and customSavedVars.customItemsEnabled == true
end

local function IsGamepadInventory()
    if ZO_IsConsoleOrGameCoreUI and ZO_IsConsoleOrGameCoreUI() then
        return true
    end
    return IsInGamepadPreferredMode and IsInGamepadPreferredMode() or false
end

-- PA's own keybind strip handles these bags, so match that scope.
local function IsBagIdInScope(bagId)
    return bagId == BAG_BACKPACK
        or bagId == BAG_BANK
        or (bagId == BAG_SUBSCRIBER_BANK and IsESOPlusSubscriber())
end

-- Gamepad inventory entries are ZO_GamepadEntryData objects which forward
-- bagId/slotIndex to their inventory data source, and keyboard slot controls
-- carry them directly.  Only fall back to resolving a slot control when the
-- values are missing.
local function GetItemBagAndSlot(inventorySlot)
    if not inventorySlot then
        return nil, nil
    end

    local bagId = inventorySlot.bagId
    local slotIndex = inventorySlot.slotIndex
    if bagId ~= nil and slotIndex ~= nil then
        return bagId, slotIndex
    end

    if type(inventorySlot.GetType) == "function" then
        local ok, buttonPart = pcall(ZO_InventorySlot_GetInventorySlotComponents, inventorySlot)
        if ok and buttonPart then
            return buttonPart.bagId, buttonPart.slotIndex
        end
    end

    return nil, nil
end

local function CanModifyPermanentJunk(bagId, slotIndex)
    local junk, custom = GetPermanentJunkAPI()
    if not custom or not IsPACustomJunkEnabled(junk) then
        return false
    end

    local helperFunctions = PersonalAssistant.HelperFunctions
    if not helperFunctions or not helperFunctions.CanItemBeMarkedAsJunkExt then
        return false
    end

    return helperFunctions.CanItemBeMarkedAsJunkExt(bagId, slotIndex) and true or false
end

local function TogglePermanentJunk(bagId, slotIndex)
    local junk, custom = GetPermanentJunkAPI()
    if not custom or not IsPACustomJunkEnabled(junk) then
        return
    end

    local itemLink = GetItemLink(bagId, slotIndex)
    if not itemLink or itemLink == "" then
        return
    end

    if custom.isItemPermanentJunk(bagId, slotIndex) then
        custom.removeItemLinkFromPermanentJunk(itemLink)
    else
        custom.addItemLinkToPermanentJunk(itemLink)
    end
end

local function GetActionTexts()
    return GetString(KELA_PA_JUNK_MARK), GetString(KELA_PA_JUNK_UNMARK)
end

-- The core action list is flat, so attach the "Personal Assistant" header to
-- our entry with the parametric list framework's header support and rebuild
-- the list once the core setup has finished.
local function AddPermanentJunkHeader(dialog)
    if not dialog or not dialog.info then
        return
    end

    local parametricList = dialog.info.parametricList
    if not parametricList then
        return
    end

    local markText, unmarkText = GetActionTexts()
    for _, listItem in ipairs(parametricList) do
        local entryData = listItem.entryData
        local entryText = entryData and entryData.text
        if entryText == markText or entryText == unmarkText then
            listItem.header = GetString(KELA_PA_JUNK_HEADER)
            ZO_GenericParametricListGamepadDialogTemplate_RebuildEntryList(dialog)
            return
        end
    end
end

local function InstallActionDialogHook()
    if actionDialogHookInstalled then
        return
    end

    local dialogName = ZO_GAMEPAD_INVENTORY_ACTION_DIALOG
    local dialogInfo = dialogName and ESO_Dialogs and ESO_Dialogs[dialogName]
    if not dialogInfo then
        return
    end
    actionDialogHookInstalled = true

    -- Dialog UI only; the secure post hook keeps it out of the keybind
    -- callback callstack that performs the selected action.
    SecurePostHook(dialogInfo, "setup", function(dialog)
        if not IsPAJunkSettingEnabled() then
            return
        end
        AddPermanentJunkHeader(dialog)
    end)
end

local function AddPermanentJunkAction(slotActions, bagId, slotIndex)
    if not IsGamepadInventory() or not IsBagIdInScope(bagId) then
        return
    end
    if not CanModifyPermanentJunk(bagId, slotIndex) then
        return
    end

    local _, custom = GetPermanentJunkAPI()
    local actionLabel = custom.isItemPermanentJunk(bagId, slotIndex) and KELA_PA_JUNK_UNMARK or KELA_PA_JUNK_MARK

    slotActions:AddSlotAction(
        actionLabel,
        function() TogglePermanentJunk(bagId, slotIndex) end,
        "secondary",
        nil,
        { visibleWhenDead = true }
    )
end

local function InstallPAJunkHook()
    if installed then
        return
    end
    installed = true

    InstallActionDialogHook()

    -- Installed even when PersonalAssistant has not loaded yet (add-on load
    -- order is not guaranteed), so the availability checks run per item.
    SecurePostHook(_G, "ZO_InventorySlot_DiscoverSlotActionsFromActionList", function(inventorySlot, slotActions)
        if not IsPAJunkSettingEnabled() then
            return
        end

        -- Retry in case the action dialog was not registered yet during load.
        InstallActionDialogHook()

        local bagId, slotIndex = GetItemBagAndSlot(inventorySlot)
        if not bagId or not slotIndex then
            return
        end

        AddPermanentJunkAction(slotActions, bagId, slotIndex)
    end)
end

function KelaSetupPAJunk()
    if not IsPAJunkSettingEnabled() then
        return
    end

    InstallPAJunkHook()
end
