--[[

Dialog to import from other servers, accounts, or characters

--]]

AGImportDlg = {}


------------------------------------------------------
--
------------------------------------------------------
local selectedAccount, selectedCharacter, selectedProfile

local function SetUpProfileDropdown(contentControl, accountName, charName)
    local comboParent = contentControl:GetNamedChild("ProfileDropdown")
    local combo = ZO_ComboBox_ObjectFromContainer(comboParent)

    combo:ClearItems()
    if (not accountName or not charName) then return end

    local function OnProfileSelected(_, _, entry)
        selectedProfile = entry.profile
    end

    for profileNum, profileData in pairs(AGX2_Character.Default[accountName][charName].profiles) do
        local entry = ZO_ComboBox:CreateItemEntry(profileData.name, OnProfileSelected)
        entry.profile = profileNum
        combo:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
    end
    combo:UpdateItems()
end

local function SetUpCharacterDropdown(contentControl, accountName)
    local comboParent = contentControl:GetNamedChild("CharacterDropdown")
    local combo = ZO_ComboBox_ObjectFromContainer(comboParent)

    combo:ClearItems()
    if (not accountName) then return end

    local function OnCharSelected(_, _, entry)
        selectedCharacter = entry.charName
        SetUpProfileDropdown(contentControl, accountName, entry.charName)
    end

    for charName, _ in pairs(AGX2_Character.Default[accountName]) do
        local entry = ZO_ComboBox:CreateItemEntry(charName, OnCharSelected)
        entry.charName = charName
        combo:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
    end
    combo:UpdateItems()
end

local function SetUpAccountDropdown(contentControl)
    local comboParent = contentControl:GetNamedChild("AccountDropdown")
    local combo = ZO_ComboBox_ObjectFromContainer(comboParent)

    local function OnAccountSelected(_, _, entry)
        selectedAccount = entry.accName
        SetUpCharacterDropdown(contentControl, entry.accName)
    end

    combo:ClearItems()
    for accName, _ in pairs(AGX2_Character.Default) do
        local entry = ZO_ComboBox:CreateItemEntry(accName, OnAccountSelected)
        entry.accName = accName
        combo:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
    end
    combo:UpdateItems()
end


------------------------------------------------------
-- Common Settings
------------------------------------------------------
local function Commit()
    AG.ImportProfile(selectedAccount, selectedCharacter, selectedProfile)
end

local function SetUp()
    local control = AGImportDialog

    SetUpAccountDropdown(GetControl(control, "Content"))
    SetUpCharacterDropdown(GetControl(control, "Content"))
    SetUpProfileDropdown(GetControl(control, "Content"))
end


function AGImportDlg.Initialize()
    local control = AGImportDialog

    ZO_Dialogs_RegisterCustomDialog("AG_IMPORT_DIALOG", {
        customControl = control,
        title = { text = "Import Profile" },
        setup = SetUp,
        buttons =
        {
            {
                control = GetControl(control, "Accept"),
                text = "Import",
                keybind = "DIALOG_PRIMARY",
                callback = Commit,
            },  
            {
                control = GetControl(control, "Cancel"),
                text = SI_DIALOG_CANCEL,
                keybind = "DIALOG_NEGATIVE",
                callback = function() end,
            },
        },
    })
end
