-- -----------------------------------------------------------------------------
-- HUDitorTools - Info Box layout section and import/export/name dialogs
-- Host: ZO_HUDEditor_Keyboard_TLInfoBox (hudeditor_keyboard.xml)
-- -----------------------------------------------------------------------------
local HT = HUDitorTools

local INTERACTABLE_LEVEL = ZO_HUD_EDITOR_KEYBOARD_INFO_BOX_INTERACTABLE_ELEMENT_LEVEL
local IGNORE_CALLBACK = true

local layoutInfoBoxSection
local layoutComboBox
local suppressLayoutComboCallback = false

local importDialogControl
local exportDialogControl
local nameDialogControl
local nameDialogMode

function HT.UpdateLAMDeleteLayoutButtonDisabledState()
    if HUDITORTOOLS_LAM_DELETE_LAYOUT_BUTTON == nil or HUDITORTOOLS_LAM_DELETE_LAYOUT_BUTTON:IsHidden() then return end
    HUDITORTOOLS_LAM_DELETE_LAYOUT_BUTTON:UpdateDisabled()
end

function HT.HideLayoutDialogs()
    importDialogControl:SetHidden(true)
    exportDialogControl:SetHidden(true)
    nameDialogControl:SetHidden(true)
    ZO_Dialogs_ReleaseAllDialogsOfName("HUDITORTOOLS_LAYOUT_DELETE_CONFIRMATION")
    ZO_Dialogs_ReleaseAllDialogsOfName("HUDITORTOOLS_LAYOUT_UNSAVED_CONFIRMATION")
end

local function AnchorLayoutInfoBoxSection()
    -- ESO allows two anchors. Match Coordinates: one TOP + 90% width (LayoutDialogs.xml).
    local globalDefaults = HT.GetInfoBox():GetNamedChild("GlobalDefaults")
    layoutInfoBoxSection:ClearAnchors()
    layoutInfoBoxSection:SetAnchor(TOP, globalDefaults, BOTTOM, 0, 16)
end

local function AddLayoutComboItems(comboBox, scope, layoutList, activeLayout, selectedEntry)
    if #layoutList == 0 then
        return selectedEntry
    end
    local headerName = GetString(SI_HUDITORTOOLS_LAYOUT_ACCOUNT)
    if scope == HT.LAYOUT_SCOPE_CHARACTER then
        headerName = GetString(SI_HUDITORTOOLS_LAYOUT_CHARACTER)
    end
    local headerEntry = comboBox:CreateItemEntry(headerName, nil, false)
    comboBox:AddItem(headerEntry, ZO_COMBOBOX_SUPPRESS_UPDATE)

    for _, layoutData in ipairs(layoutList) do
        local isActive = activeLayout and activeLayout.layoutId == layoutData.layoutId and HT.GetLayoutSelection().scope == scope
        local displayName = HT.FormatLayoutChoiceName(scope, layoutData, isActive)
        local itemEntry = comboBox:CreateItemEntry(displayName, function()
            if suppressLayoutComboCallback then
                return
            end
            HT.SwitchHudLayout(scope, layoutData.layoutId)
        end)
        itemEntry.layoutScope = scope
        itemEntry.layoutId = layoutData.layoutId
        comboBox:AddItem(itemEntry, ZO_COMBOBOX_SUPPRESS_UPDATE)
        if isActive then
            selectedEntry = itemEntry
        end
    end
    return selectedEntry
end

local function RefreshLayoutComboBox()
    suppressLayoutComboCallback = true
    layoutComboBox:ClearItems()
    local activeLayout = HT.GetActiveLayout()
    local selectedEntry
    selectedEntry = AddLayoutComboItems(layoutComboBox, HT.LAYOUT_SCOPE_ACCOUNT, HT.GetAccountLayoutList(), activeLayout, selectedEntry)
    selectedEntry = AddLayoutComboItems(layoutComboBox, HT.LAYOUT_SCOPE_CHARACTER, HT.GetCharacterLayoutList(), activeLayout, selectedEntry)
    layoutComboBox:UpdateItems()
    if selectedEntry then
        layoutComboBox:SelectItem(selectedEntry, IGNORE_CALLBACK)
    end
    suppressLayoutComboCallback = false
end

local function RefreshLayoutButtons()
    local activeLayout = HT.GetActiveLayout()
    local canCreate = HT.CanCreateLayoutInScope(HT.LAYOUT_SCOPE_ACCOUNT) or HT.CanCreateLayoutInScope(HT.LAYOUT_SCOPE_CHARACTER)
    local canDelete = HT.CountAllLayoutsForCharacter() > 1

    layoutInfoBoxSection:GetNamedChild("Save"):SetEnabled(activeLayout and HT.IsLiveLayoutDirty())
    layoutInfoBoxSection:GetNamedChild("New"):SetEnabled(canCreate)
    layoutInfoBoxSection:GetNamedChild("Import"):SetEnabled(canCreate)
    layoutInfoBoxSection:GetNamedChild("Rename"):SetEnabled(activeLayout ~= nil)
    layoutInfoBoxSection:GetNamedChild("Delete"):SetEnabled(activeLayout and canDelete)
end

function HT.RefreshLayoutInfoBoxSection()
    HT.RefreshLamLayoutDropdown()
    local infoBox = HT.GetInfoBox()
    local infoBoxHidden = infoBox:IsHidden()
    layoutInfoBoxSection:SetHidden(infoBoxHidden)
    if infoBoxHidden then
        HT.HideLayoutDialogs()
        return
    end
    AnchorLayoutInfoBoxSection()
    RefreshLayoutComboBox()
    RefreshLayoutButtons()
end

local function GetImportShareEdit()
    return importDialogControl:GetNamedChild("ShareBackdrop"):GetNamedChild("Edit")
end

local function GetImportNameEdit()
    return importDialogControl:GetNamedChild("NameBackdrop"):GetNamedChild("Edit")
end

local function GetExportShareEdit()
    return exportDialogControl:GetNamedChild("ShareBackdrop"):GetNamedChild("Edit")
end

local function GetNameDialogEdit()
    return nameDialogControl:GetNamedChild("NameBackdrop"):GetNamedChild("Edit")
end

local function GetImportScope()
    if ZO_CheckButton_IsChecked(importDialogControl:GetNamedChild("CharacterCheck")) then
        return HT.LAYOUT_SCOPE_CHARACTER
    end
    return HT.LAYOUT_SCOPE_ACCOUNT
end

local function GetNameDialogScope()
    if ZO_CheckButton_IsChecked(nameDialogControl:GetNamedChild("CharacterCheck")) then
        return HT.LAYOUT_SCOPE_CHARACTER
    end
    return HT.LAYOUT_SCOPE_ACCOUNT
end

local function RefreshImportDialogState()
    local shareText = GetImportShareEdit():GetText()
    local layoutName = GetImportNameEdit():GetText()
    local payload, decodeError = HT.DecodeHudLayoutString(shareText)
    local errorLabel = importDialogControl:GetNamedChild("Error")
    local importButton = importDialogControl:GetNamedChild("Import")
    local scope = GetImportScope()
    local errorText = ""
    local canImport = false

    if zo_strtrim(shareText) ~= "" then
        if decodeError then
            errorText = decodeError
        elseif zo_strtrim(layoutName) == "" then
            errorText = GetString(SI_HUDITORTOOLS_LAYOUT_ERROR_NAME_EMPTY)
        elseif not HT.CanCreateLayoutInScope(scope) then
            errorText = GetString(SI_HUDITORTOOLS_LAYOUT_ERROR_CAP)
        elseif not HT.IsLayoutNameUnique(scope, layoutName) then
            errorText = GetString(SI_HUDITORTOOLS_LAYOUT_ERROR_NAME_TAKEN)
        else
            canImport = true
        end
    end

    errorLabel:SetText(errorText)
    importButton:SetEnabled(canImport)
end

local function RefreshNameDialogState()
    local layoutName = GetNameDialogEdit():GetText()
    local errorLabel = nameDialogControl:GetNamedChild("Error")
    local confirmButton = nameDialogControl:GetNamedChild("Confirm")
    local errorText = ""
    local canConfirm = false
    local ignoreLayoutId
    local scope = HT.LAYOUT_SCOPE_ACCOUNT

    if nameDialogMode == "rename" then
        local activeLayout, activeScope = HT.GetActiveLayout()
        ignoreLayoutId = activeLayout.layoutId
        scope = activeScope
    else
        scope = GetNameDialogScope()
    end

    if zo_strtrim(layoutName) == "" then
        errorText = GetString(SI_HUDITORTOOLS_LAYOUT_ERROR_NAME_EMPTY)
    elseif nameDialogMode == "new" and not HT.CanCreateLayoutInScope(scope) then
        errorText = GetString(SI_HUDITORTOOLS_LAYOUT_ERROR_CAP)
    elseif not HT.IsLayoutNameUnique(scope, layoutName, ignoreLayoutId) then
        errorText = GetString(SI_HUDITORTOOLS_LAYOUT_ERROR_NAME_TAKEN)
    else
        canConfirm = true
    end

    errorLabel:SetText(errorText)
    confirmButton:SetEnabled(canConfirm)
end

local function ConfirmImportLayout()
    local payload, decodeError = HT.DecodeHudLayoutString(GetImportShareEdit():GetText())
    if decodeError then
        importDialogControl:GetNamedChild("Error"):SetText(decodeError)
        return
    end
    local layoutName = GetImportNameEdit():GetText()
    local scope = GetImportScope()
    local layoutData, createError = HT.CreateHudLayout(layoutName, scope, payload)
    if createError then
        importDialogControl:GetNamedChild("Error"):SetText(createError)
        return
    end
    HT.SetActiveLayout(scope, layoutData.layoutId)
    HT.HideLayoutDialogs()
end

local function ConfirmNameDialog()
    local layoutName = GetNameDialogEdit():GetText()
    if nameDialogMode == "rename" then
        local activeLayout, activeScope = HT.GetActiveLayout()
        local renamed, renameError = HT.RenameHudLayout(activeScope, activeLayout.layoutId, layoutName)
        if not renamed then
            nameDialogControl:GetNamedChild("Error"):SetText(renameError)
            return
        end
    else
        local scope = GetNameDialogScope()
        local layoutData, createError = HT.CreateHudLayout(layoutName, scope, HT.CollectLiveHudPayload())
        if createError then
            nameDialogControl:GetNamedChild("Error"):SetText(createError)
            return
        end
        local SKIP_APPLY = true
        HT.SetActiveLayout(scope, layoutData.layoutId, SKIP_APPLY)
        HT.UpdateLAMDeleteLayoutButtonDisabledState()
    end
    HT.HideLayoutDialogs()
end

function HT.ShowLayoutImportDialog()
    HT.HideLayoutDialogs()
    GetImportShareEdit():SetText("")
    GetImportNameEdit():SetText("")
    ZO_CheckButton_SetCheckState(importDialogControl:GetNamedChild("CharacterCheck"), false)
    RefreshImportDialogState()
    importDialogControl:SetHidden(false)
    GetImportShareEdit():TakeFocus()
end

function HT.ShowLayoutExportDialog()
    HT.HideLayoutDialogs()
    local editBox = GetExportShareEdit()
    editBox:SetText(HT.EncodeHudLayoutPayload(HT.CollectLiveHudPayload()))
    exportDialogControl:SetHidden(false)
    editBox:TakeFocus()
    editBox:SelectAll()
end

function HT.ShowLayoutNameDialog(mode)
    HT.HideLayoutDialogs()
    nameDialogMode = mode
    local titleLabel = nameDialogControl:GetNamedChild("Title")
    local confirmButton = nameDialogControl:GetNamedChild("Confirm")
    local characterCheck = nameDialogControl:GetNamedChild("CharacterCheck")
    local nameEdit = GetNameDialogEdit()

    if mode == "rename" then
        titleLabel:SetText(GetString(SI_HUDITORTOOLS_LAYOUT_RENAME_TITLE))
        confirmButton:SetText(GetString(SI_HUDITORTOOLS_LAYOUT_RENAME))
        characterCheck:SetHidden(true)
        nameEdit:SetText(HT.GetActiveLayout().name)
    else
        titleLabel:SetText(GetString(SI_HUDITORTOOLS_LAYOUT_NEW_TITLE))
        confirmButton:SetText(GetString(SI_HUDITORTOOLS_LAYOUT_NEW))
        characterCheck:SetHidden(false)
        ZO_CheckButton_SetCheckState(characterCheck, false)
        nameEdit:SetText("")
    end
    RefreshNameDialogState()
    nameDialogControl:SetHidden(false)
    nameEdit:TakeFocus()
end

function HT.ShowLayoutDeleteConfirmation()
    local activeLayout, activeScope = HT.GetActiveLayout()
    ZO_Dialogs_ShowDialog("HUDITORTOOLS_LAYOUT_DELETE_CONFIRMATION", {
        scope = activeScope,
        layoutId = activeLayout.layoutId,
    }, {
        mainTextParams = { activeLayout.name },
    })
end

local function InitializeImportDialog()
    importDialogControl = HUDitorTools_LayoutImportDialog
    importDialogControl:SetDrawTier(DT_HIGH)
    importDialogControl:SetDrawLevel(INTERACTABLE_LEVEL)

    local closeButton = importDialogControl:GetNamedChild("Close")
    closeButton:SetDrawLevel(INTERACTABLE_LEVEL)
    closeButton:SetHandler("OnClicked", HT.HideLayoutDialogs)
    importDialogControl:GetNamedChild("Cancel"):SetHandler("OnClicked", HT.HideLayoutDialogs)
    importDialogControl:GetNamedChild("Import"):SetHandler("OnClicked", ConfirmImportLayout)

    ZO_CheckButton_SetLabelText(importDialogControl:GetNamedChild("CharacterCheck"), GetString(SI_HUDITORTOOLS_LAYOUT_CHARACTER_SPECIFIC))
    ZO_CheckButton_SetToggleFunction(importDialogControl:GetNamedChild("CharacterCheck"), RefreshImportDialogState)

    GetImportShareEdit():SetHandler("OnTextChanged", RefreshImportDialogState)
    GetImportNameEdit():SetHandler("OnTextChanged", RefreshImportDialogState)
    GetImportNameEdit():SetHandler("OnEnter", ConfirmImportLayout)
end

local function SelectExportShareString()
    local editBox = GetExportShareEdit()
    editBox:TakeFocus()
    editBox:SelectAll()
end

local function InitializeExportDialog()
    exportDialogControl = HUDitorTools_LayoutExportDialog
    exportDialogControl:SetDrawTier(DT_HIGH)
    exportDialogControl:SetDrawLevel(INTERACTABLE_LEVEL)

    local closeButton = exportDialogControl:GetNamedChild("Close")
    closeButton:SetDrawLevel(INTERACTABLE_LEVEL)
    closeButton:SetHandler("OnClicked", HT.HideLayoutDialogs)
    exportDialogControl:GetNamedChild("CloseBottom"):SetHandler("OnClicked", HT.HideLayoutDialogs)
    exportDialogControl:GetNamedChild("SelectAll"):SetHandler("OnClicked", SelectExportShareString)
end

local function InitializeNameDialog()
    nameDialogControl = HUDitorTools_LayoutNameDialog
    nameDialogControl:SetDrawTier(DT_HIGH)
    nameDialogControl:SetDrawLevel(INTERACTABLE_LEVEL)

    local closeButton = nameDialogControl:GetNamedChild("Close")
    closeButton:SetDrawLevel(INTERACTABLE_LEVEL)
    closeButton:SetHandler("OnClicked", HT.HideLayoutDialogs)
    nameDialogControl:GetNamedChild("Cancel"):SetHandler("OnClicked", HT.HideLayoutDialogs)
    nameDialogControl:GetNamedChild("Confirm"):SetHandler("OnClicked", ConfirmNameDialog)

    ZO_CheckButton_SetLabelText(nameDialogControl:GetNamedChild("CharacterCheck"), GetString(SI_HUDITORTOOLS_LAYOUT_CHARACTER_SPECIFIC))
    ZO_CheckButton_SetToggleFunction(nameDialogControl:GetNamedChild("CharacterCheck"), RefreshNameDialogState)

    local nameEdit = GetNameDialogEdit()
    nameEdit:SetHandler("OnTextChanged", RefreshNameDialogState)
    nameEdit:SetHandler("OnEnter", ConfirmNameDialog)
end

local function InitializeInfoBoxSection()
    local infoBox = HT.GetInfoBox()
    layoutInfoBoxSection = CreateControlFromVirtual(infoBox:GetName() .. "HUDitorToolsLayoutSection", infoBox, "HUDitorTools_LayoutInfoBoxSection")
    AnchorLayoutInfoBoxSection()

    local comboControl = layoutInfoBoxSection:GetNamedChild("ComboBox")
    layoutComboBox = ZO_ComboBox_ObjectFromContainer(comboControl)
    layoutComboBox:SetSortsItems(false)
    comboControl:SetDrawLevel(INTERACTABLE_LEVEL)

    layoutInfoBoxSection:GetNamedChild("Save"):SetHandler("OnClicked", function()
        HT.SaveActiveLayout()
    end)
    layoutInfoBoxSection:GetNamedChild("New"):SetHandler("OnClicked", function()
        HT.ShowLayoutNameDialog("new")
    end)
    layoutInfoBoxSection:GetNamedChild("Import"):SetHandler("OnClicked", HT.ShowLayoutImportDialog)
    layoutInfoBoxSection:GetNamedChild("Export"):SetHandler("OnClicked", HT.ShowLayoutExportDialog)
    layoutInfoBoxSection:GetNamedChild("Rename"):SetHandler("OnClicked", function()
        HT.ShowLayoutNameDialog("rename")
    end)
    layoutInfoBoxSection:GetNamedChild("Delete"):SetHandler("OnClicked", HT.ShowLayoutDeleteConfirmation)

    layoutInfoBoxSection:SetHidden(infoBox:IsHidden())
end

ZO_Dialogs_RegisterCustomDialog("HUDITORTOOLS_LAYOUT_DELETE_CONFIRMATION",
{
    title =
    {
        text = SI_HUDITORTOOLS_LAYOUT_DELETE_TITLE,
    },
    mainText =
    {
        text = SI_HUDITORTOOLS_LAYOUT_DELETE_BODY,
    },
    drawTier = DT_HIGH,
    canQueue = true,
    buttons =
    {
        {
            text = SI_DIALOG_CONFIRM,
            callback = function(dialog)
                HT.DeleteHudLayout(dialog.data.scope, dialog.data.layoutId)
            end,
        },
        {
            text = SI_DIALOG_CANCEL,
        },
    },
})

ZO_Dialogs_RegisterCustomDialog("HUDITORTOOLS_LAYOUT_UNSAVED_CONFIRMATION",
{
    title =
    {
        text = SI_HUDITORTOOLS_LAYOUT_UNSAVED_TITLE,
    },
    mainText =
    {
        text = SI_HUDITORTOOLS_LAYOUT_UNSAVED_BODY,
    },
    drawTier = DT_HIGH,
    canQueue = true,
    buttons =
    {
        {
            text = SI_DIALOG_CONFIRM,
            callback = function(dialog)
                HT.ConfirmSwitchHudLayout(dialog.data.scope, dialog.data.layoutId)
            end,
        },
        {
            text = SI_DIALOG_CANCEL,
        },
    },
})

function HT.InstallLayoutInfoBoxSection()
    InitializeImportDialog()
    InitializeExportDialog()
    InitializeNameDialog()
    InitializeInfoBoxSection()

    ZO_PostHook(ZO_HUDEditor_Keyboard, "RefreshInfoBox", function()
        HT.RefreshLayoutInfoBoxSection()
    end)
end
