-- KelaPadUI PersonalAssistant integration
-- Adds PersonalAssistant actions to the gamepad inventory actions list (the
-- dialog where "Link in Chat" lives), grouped under a "Personal Assistant"
-- header.  PersonalAssistant itself has no gamepad support, so the actions
-- are added from here:
--   * mark/unmark as permanent junk, through PA's exported junk API;
--   * add or edit a custom banking rule, in a gamepad dialog.  PA's own rule
--     window is mouse-only, so the dialog saves the rule in PA's own format
--     (the same fields its window writes) and deletes through PA's exported
--     deletePABCustomRule.
--
-- Everything in this file is optional: without PersonalAssistant installed,
-- or with PA's custom junk or banking rules disabled, no action is added.

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

-- The labels of every action this file adds, for finding them in the list.
local function GetActionTexts()
    return
    {
        [GetString(KELA_PA_JUNK_MARK)] = true,
        [GetString(KELA_PA_JUNK_UNMARK)] = true,
        [GetString(KELA_PA_BANKING_ADD)] = true,
        [GetString(KELA_PA_BANKING_EDIT)] = true,
    }
end

-- The core action list is flat, so attach the "Personal Assistant" header to
-- the first of our entries with the parametric list framework's header
-- support and rebuild the list once the core setup has finished.
local function AddPermanentJunkHeader(dialog)
    if not dialog or not dialog.info then
        return
    end

    local parametricList = dialog.info.parametricList
    if not parametricList then
        return
    end

    local ourTexts = GetActionTexts()
    for _, listItem in ipairs(parametricList) do
        local entryData = listItem.entryData
        local entryText = entryData and entryData.text
        if entryText and ourTexts[entryText] then
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

-- ---------------------------------------------------------------------------
-- Banking rules
-- ---------------------------------------------------------------------------
-- PA stores one custom rule per item in PA.Banking.SavedVars.Custom.PAItemIds,
-- keyed by its item identifier: { operator, bagAmount, itemLink, ruleEnabled }.
-- `operator` is the comparison plus five per bag (PA's PAC.OPERATOR table):
-- the backpack is 1-5, the bank 6-10, then each house bank in turn. A rule
-- reads "<bag> has exactly / at most / at least <amount>".

local BANKING_DIALOG = "KELA_PA_BANKING_RULE_DIALOG"
local OPERATOR_EXACTLY, OPERATOR_AT_MOST, OPERATOR_AT_LEAST = 1, 3, 5
local OPERATORS_PER_BAG = 5
-- PA's own limit for the amount field.
local MAXIMUM_AMOUNT = 10000
local DEFAULT_AMOUNT = 100

-- PA's bags in its operator order.
local RULE_BAGS =
{
    BAG_BACKPACK, BAG_BANK,
    BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TWO, BAG_HOUSE_BANK_THREE, BAG_HOUSE_BANK_FOUR, BAG_HOUSE_BANK_FIVE,
    BAG_HOUSE_BANK_SIX, BAG_HOUSE_BANK_SEVEN, BAG_HOUSE_BANK_EIGHT, BAG_HOUSE_BANK_NINE, BAG_HOUSE_BANK_TEN,
}

local COMPARISONS =
{
    { operator = OPERATOR_EXACTLY, text = KELA_PA_BANKING_EXACTLY },
    { operator = OPERATOR_AT_MOST, text = KELA_PA_BANKING_AT_MOST },
    { operator = OPERATOR_AT_LEAST, text = KELA_PA_BANKING_AT_LEAST },
}

-- PA's banking table and helpers, or nil when custom banking rules are not
-- available (PA or its banking module missing, no active profile, or custom
-- rules turned off in PA).
local function GetBankingRules()
    local pa = PersonalAssistant
    local banking = pa and pa.Banking
    local helpers = pa and pa.HelperFunctions
    local profiles = pa and pa.ProfileManager
    local profile = profiles and profiles.PABanking
    if not (banking and helpers and profile and type(profile.hasActiveProfile) == "function") then
        return nil
    end
    if not (helpers.getPAItemLinkIdentifier and helpers.isItemLinkCharacterBound) or not profile.hasActiveProfile() then
        return nil
    end
    local custom = banking.SavedVars and banking.SavedVars.Custom
    if not (custom and custom.customItemsEnabled == true and type(custom.PAItemIds) == "table") then
        return nil
    end
    return custom.PAItemIds, helpers
end

-- The same items PA's own menu leaves out.
local function CanHaveBankingRule(bagId, slotIndex, itemLink, helpers)
    local itemType = GetItemType(bagId, slotIndex)
    if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF or itemType == ITEMTYPE_RECIPE
        or itemType == ITEMTYPE_MASTER_WRIT or itemType == ITEMTYPE_AVA_REPAIR then
        return false
    end
    return not helpers.isItemLinkCharacterBound(itemLink)
end

-- The bag (index into RULE_BAGS) and comparison of a stored operator. Other
-- comparisons PA once had read as "exactly", as in PA's own window.
local function DecodeOperator(operator)
    operator = tonumber(operator) or OPERATOR_EXACTLY
    local bagIndex = zo_floor((operator - 1) / OPERATORS_PER_BAG) + 1
    local comparison = (operator - 1) % OPERATORS_PER_BAG + 1
    if comparison ~= OPERATOR_AT_MOST and comparison ~= OPERATOR_AT_LEAST then
        comparison = OPERATOR_EXACTLY
    end
    return zo_clamp(bagIndex, 1, #RULE_BAGS), comparison
end

local function EncodeOperator(bagIndex, comparison)
    return (bagIndex - 1) * OPERATORS_PER_BAG + comparison
end

local function GetBagName(bagId)
    local helpers = PersonalAssistant and PersonalAssistant.HelperFunctions
    local name = helpers and helpers.getBagName and helpers.getBagName(bagId)
    return (type(name) == "string" and name ~= "") and zo_strformat(SI_TOOLTIP_ITEM_NAME, name) or tostring(bagId)
end

-- The backpack, the bank, and the house banks this account has unlocked,
-- plus the rule's own bag if it is a house bank no longer unlocked.
local function GetOfferedBagIndices(selectedIndex)
    local indices = {}
    for index, bagId in ipairs(RULE_BAGS) do
        local offered = index <= 2 or index == selectedIndex
        if not offered and IsHouseBankBag(bagId) then
            local collectibleId = GetCollectibleForBag(bagId)
            offered = collectibleId ~= nil and collectibleId ~= 0 and IsCollectibleUnlocked(collectibleId)
        end
        if offered then
            indices[#indices + 1] = index
        end
    end
    return indices
end

local function RefreshPABankingList()
    local list = PersonalAssistant and PersonalAssistant.BankingRulesList
    if list and list.Refresh then
        list:Refresh()
    end
end

-- Writes the rule the way PA's own window does: a new rule starts enabled,
-- an update keeps whether it was enabled.
local function SaveBankingRule(state)
    local rules, helpers = GetBankingRules()
    if not rules then
        return
    end
    local paItemId = helpers.getPAItemLinkIdentifier(state.itemLink)
    local amount = zo_clamp(zo_floor(tonumber(state.amount) or 0), 0, MAXIMUM_AMOUNT)
    local operator = EncodeOperator(state.bagIndex, state.comparison)
    local rule = rules[paItemId]
    if rule then
        rule.operator = operator
        rule.bagAmount = amount
        rule.itemLink = state.itemLink
    else
        rules[paItemId] = { operator = operator, bagAmount = amount, itemLink = state.itemLink, ruleEnabled = true }
    end
    RefreshPABankingList()
end

local function DeleteBankingRule(itemLink)
    local rules, helpers = GetBankingRules()
    if not rules then
        return
    end
    local dialogs = PersonalAssistant.CustomDialogs
    if dialogs and type(dialogs.deletePABCustomRule) == "function" then
        dialogs.deletePABCustomRule(itemLink)
    else
        rules[helpers.getPAItemLinkIdentifier(itemLink)] = nil
        RefreshPABankingList()
    end
end

local function GetItemTitle(itemLink)
    local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink))
    return GetItemQualityColor(GetItemLinkDisplayQuality(itemLink)):Colorize(name)
end

-- A dropdown row: `items` is { { text, value } }, `get`/`set` read and
-- store the choice in the dialog's state.
local function DropdownEntry(header, getItems, get, set)
    return
    {
        header = header,
        template = "ZO_GamepadDropdownItem",
        templateData =
        {
            setup = function(control, data)
                local dropdown = control.dropdown
                data.dropdown = dropdown
                dropdown:SetSortsItems(false)
                dropdown:ClearItems()
                if SCREEN_NARRATION_MANAGER and data.dialog then
                    SCREEN_NARRATION_MANAGER:RegisterDialogDropdown(data.dialog, dropdown)
                end
                local state = data.dialog.data
                local selected = 1
                for index, item in ipairs(getItems(state)) do
                    local entry = dropdown:CreateItemEntry(item.text, function()
                        set(state, item.value)
                    end)
                    dropdown:AddItem(entry)
                    if item.value == get(state) then
                        selected = index
                    end
                end
                dropdown:SelectItemByIndex(selected, true)
                dropdown:SetHighlightedItem(selected)
            end,
            callback = function(dialog)
                local data = dialog.entryList:GetTargetData()
                if data and data.dropdown then
                    data.dropdown:Activate()
                end
            end,
            narrationText = ZO_GetDefaultParametricListDropdownNarrationText,
        },
    }
end

local function MenuEntry(text, callback, visible)
    return
    {
        template = "ZO_GamepadMenuEntryTemplate",
        templateData =
        {
            text = text,
            setup = ZO_SharedGamepadEntry_OnSetup,
            callback = callback,
            visible = visible,
        },
    }
end

local bankingDialogRegistered = false

local function RegisterBankingDialog()
    if bankingDialogRegistered then
        return
    end
    bankingDialogRegistered = true

    local bagEntry = DropdownEntry(GetString(KELA_PA_BANKING_BAG),
        function(state)
            local items = {}
            for _, index in ipairs(GetOfferedBagIndices(state.bagIndex)) do
                items[#items + 1] = { text = GetBagName(RULE_BAGS[index]), value = index }
            end
            return items
        end,
        function(state) return state.bagIndex end,
        function(state, value) state.bagIndex = value end)

    local comparisonEntry = DropdownEntry(GetString(KELA_PA_BANKING_KEEP),
        function()
            local items = {}
            for _, comparison in ipairs(COMPARISONS) do
                items[#items + 1] = { text = GetString(comparison.text), value = comparison.operator }
            end
            return items
        end,
        function(state) return state.comparison end,
        function(state, value) state.comparison = value end)

    local amountEntry =
    {
        header = GetString(KELA_PA_BANKING_AMOUNT),
        template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
        templateData =
        {
            textChangedCallback = function(editBox)
                local state = editBox.kelaBankingState
                if state then
                    state.amount = zo_clamp(tonumber(editBox:GetText()) or 0, 0, MAXIMUM_AMOUNT)
                end
            end,
            setup = function(control, data)
                local editBox = control.editBoxControl
                -- The edit box is pooled with other dialogs: point it at this rule.
                editBox.kelaBankingState = data.dialog.data
                editBox.textChangedCallback = data.textChangedCallback
                editBox:SetTextType(TEXT_TYPE_NUMERIC_UNSIGNED_INT)
                editBox:SetMaxInputChars(5)
                editBox:SetText(tostring(data.dialog.data.amount))
            end,
            callback = function(dialog)
                local control = dialog.entryList:GetTargetControl()
                if control and control.editBoxControl then
                    control.editBoxControl:TakeFocus()
                end
            end,
            narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
        },
    }

    local saveEntry = MenuEntry(
        function(dialog)
            return GetString(dialog.data.existing and KELA_PA_BANKING_UPDATE or KELA_PA_BANKING_SAVE)
        end,
        function(dialog)
            SaveBankingRule(dialog.data)
            ZO_Dialogs_ReleaseDialogOnButtonPress(BANKING_DIALOG)
        end)

    local deleteEntry = MenuEntry(GetString(KELA_PA_BANKING_DELETE),
        function(dialog)
            local itemLink = dialog.data.itemLink
            ZO_Dialogs_ReleaseDialogOnButtonPress(BANKING_DIALOG)
            -- Queued by the core until this dialog has closed.
            KelaShowConfirmDialog(zo_strformat(GetString(KELA_PA_BANKING_DELETE_TEXT), GetItemTitle(itemLink)), function()
                DeleteBankingRule(itemLink)
            end)
        end,
        function(dialog)
            return dialog.data and dialog.data.existing == true
        end)

    KelaRegisterGamepadDialog(BANKING_DIALOG,
    {
        -- The inventory actions list is still closing when the action runs.
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title =
        {
            text = function(dialog)
                return dialog.data and dialog.data.title or ""
            end,
        },
        setup = function(dialog)
            dialog:setupFunc()
        end,
        parametricList = { bagEntry, comparisonEntry, amountEntry, saveEntry, deleteEntry },
        blockDialogReleaseOnPress = true,
        buttons = KelaParametricSelectBackButtons(BANKING_DIALOG),
    })
end

local function ShowBankingRuleDialog(bagId, slotIndex)
    local rules, helpers = GetBankingRules()
    local itemLink = GetItemLink(bagId, slotIndex)
    if not rules or not itemLink or itemLink == "" then
        return
    end
    local rule = rules[helpers.getPAItemLinkIdentifier(itemLink)]
    local state =
    {
        itemLink = itemLink,
        existing = rule ~= nil,
        bagIndex = 1,
        comparison = OPERATOR_EXACTLY,
        amount = DEFAULT_AMOUNT,
    }
    if rule then
        state.bagIndex, state.comparison = DecodeOperator(rule.operator)
        state.amount = tonumber(rule.bagAmount) or DEFAULT_AMOUNT
    end
    state.title = zo_strformat(GetString(rule and KELA_PA_BANKING_EDIT_TITLE or KELA_PA_BANKING_ADD_TITLE), GetItemTitle(itemLink))
    RegisterBankingDialog()
    ZO_Dialogs_ShowGamepadDialog(BANKING_DIALOG, state)
end

local function AddBankingRuleAction(slotActions, bagId, slotIndex)
    if not IsGamepadInventory() or not IsBagIdInScope(bagId) then
        return
    end
    local rules, helpers = GetBankingRules()
    if not rules then
        return
    end
    local itemLink = GetItemLink(bagId, slotIndex)
    if not itemLink or itemLink == "" or not CanHaveBankingRule(bagId, slotIndex, itemLink, helpers) then
        return
    end
    local exists = rules[helpers.getPAItemLinkIdentifier(itemLink)] ~= nil
    slotActions:AddSlotAction(
        exists and KELA_PA_BANKING_EDIT or KELA_PA_BANKING_ADD,
        function() ShowBankingRuleDialog(bagId, slotIndex) end,
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
        AddBankingRuleAction(slotActions, bagId, slotIndex)
    end)
end

function KelaSetupPAJunk()
    if not IsPAJunkSettingEnabled() then
        return
    end

    InstallPAJunkHook()
end
