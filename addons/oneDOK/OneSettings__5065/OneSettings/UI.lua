local OS = OneSettings
local UI = {}
OS.UI = UI

local function button(name, parent, text, callback)
    local control = CreateControlFromVirtual(name, parent, "ZO_DefaultButton")
    control:SetDimensions(150, 28)
    control:SetText(text)
    control:SetHandler("OnClicked", callback)
    return control
end

function UI:InstallSettings()
    local LAM = LibAddonMenu2
    self.settingsPanel = LAM:RegisterAddonPanel("OneSettingsOptions", {
        type = "panel", name = OS.name, displayName = OS.name, author = "oneDOK", version = OS.version,
        registerForRefresh = true, registerForDefaults = true,
    })
    local options = {}
    for _, category in ipairs({ "settings", "bindings", "windows", "addons" }) do
        local key = category
        options[#options + 1] = {
            type = "checkbox", name = OS.strings[key], tooltip = OS.strings[key .. "Tip"], default = false,
            warning = key == "addons" and OS.strings.reloadTooltip or nil,
            getFunc = function() return OS:Enabled(key) end,
            setFunc = function(value) OS:SetEnabled(key, value) end,
        }
    end
    LAM:RegisterOptionControls("OneSettingsOptions", options)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function()
        self.settingsOpen = true
        if self.settingsFragment then return end
        self.settingsFragment = LAM:GetAddonSettingsFragment()
        self.settingsFragment:RegisterCallback("StateChange", function(_, state)
            self.settingsOpen = state ~= SCENE_FRAGMENT_HIDDEN
            if not self.settingsOpen and OS.reloadPending then
                OS:Later("Reload", function() OS:TryReload() end)
            end
        end)
    end)
end

function UI:ShowReloadWarning()
    if self.reloadDialogOpen then return end
    self.reloadDialogOpen = true
    ZO_Dialogs_ShowDialog("OneSettingsReload")
end

function UI:ShowName(oldName)
    ZO_Dialogs_ShowDialog("OneSettingsName", { oldName = oldName }, {
        titleParams = { oldName and OS.strings.renameTitle or OS.strings.saveTitle },
        initialEditText = oldName or "",
    })
end

function UI:RefreshPresets(preferred)
    local combo = self.combo
    combo:ClearItems()
    self.selected = nil
    local first, preferredEntry
    for _, name in ipairs(OS.Presets:List()) do
        local entry = combo:CreateItemEntry(name, function(_, _, selected) self.selected = selected.preset end)
        entry.preset = name
        combo:AddItem(entry)
        first = first or entry
        if name == preferred then preferredEntry = entry end
    end
    if first then combo:SelectItem(preferredEntry or first)
    else combo:SetSelectedItemText(OS.strings.noPresets) end
    local enabled = first ~= nil
    self.rename:SetEnabled(enabled)
    self.delete:SetEnabled(enabled)
    self.load:SetEnabled(enabled)
end

function UI:ShowPresets(preferred)
    ZO_Dialogs_ShowDialog("OneSettingsLoad")
    self:RefreshPresets(preferred)
end

function UI:InstallDialogs()
    local function later()
        self.reloadDialogOpen = false
        OS.reloadNeedsWarning = false
        OS.reloadPending = false
        OS:CancelLater("Reload")
    end
    ZO_Dialogs_RegisterCustomDialog("OneSettingsReload", {
        canQueue = true, title = { text = OS.strings.reloadTitle },
        mainText = { text = OS.strings.reloadWarning },
        buttons = {
            { text = OS.strings.reloadNow, callback = function()
                self.reloadDialogOpen = false
                OS.reloadNeedsWarning = false
                OS:TryReload()
            end },
            { text = OS.strings.reloadLater, callback = later },
        },
        noChoiceCallback = later,
    })
    ZO_Dialogs_RegisterCustomDialog("OneSettingsName", {
        title = { text = "<<1>>" }, mainText = { text = OS.strings.presetName },
        editBox = { maxInputCharacters = 128 }, warning = { text = "" },
        buttons = {
            { text = OS.strings.save, noReleaseOnClick = true, callback = function(dialog)
                local name = ZO_Dialogs_GetEditBoxText(dialog)
                local old = dialog.data.oldName
                local ok, err
                if old then ok, err = OS.Presets:Rename(old, name)
                else ok, err = OS.Presets:Save(name) end
                if not ok then
                    ZO_Dialogs_UpdateDialogWarningText(dialog, { text = OS.strings[err] })
                    return
                end
                ZO_Dialogs_ReleaseDialog("OneSettingsName")
                if old then self:ShowPresets(OS.Presets:Name(name)) end
            end },
            { text = OS.strings.cancel },
        },
    })
    local control = CreateControlFromVirtual("OneSettingsLoadDialog", GuiRoot, "ZO_CustomDialogBase")
    control:SetDimensions(470, 245)
    control:SetHidden(true)
    local container = CreateControlFromVirtual("OneSettingsPresetCombo", control, "ZO_ComboBox")
    container:SetDimensions(390, 30)
    container:SetAnchor(TOPLEFT, control, TOPLEFT, 40, 80)
    self.combo = ZO_ComboBox_ObjectFromContainer(container)
    self.combo:SetSortsItems(false)
    self.rename = button("OneSettingsRename", control, OS.strings.rename, function()
        local name = self.selected
        if not name then return end
        ZO_Dialogs_ReleaseDialog("OneSettingsLoad")
        self:ShowName(name)
    end)
    self.rename:SetAnchor(TOPLEFT, container, BOTTOMLEFT, 0, 15)
    self.delete = button("OneSettingsDelete", control, OS.strings.delete, function()
        if self.selected then OS.Presets:Delete(self.selected); self:RefreshPresets() end
    end)
    self.delete:SetAnchor(TOPRIGHT, container, BOTTOMRIGHT, 0, 15)
    self.load = CreateControlFromVirtual("OneSettingsLoadConfirm", control, "ZO_CustomDialogButton")
    local close = CreateControlFromVirtual("OneSettingsLoadCancel", control, "ZO_CustomDialogButton")
    ZO_Dialogs_RegisterCustomDialog("OneSettingsLoad", {
        customControl = control, title = { text = OS.strings.loadTitle }, mainText = { text = "" },
        buttons = {
            { control = self.load, text = OS.strings.load, keybind = "DIALOG_PRIMARY", callback = function()
                if self.selected then OS.Presets:Load(self.selected) end
            end },
            { control = close, text = OS.strings.cancel, keybind = "DIALOG_NEGATIVE" },
        },
    })
end

function UI:InstallButtons()
    if self.saveButton or not ADD_ON_MANAGER then return end
    local control = ADD_ON_MANAGER.control
    local divider = control:GetNamedChild("Divider")
    self.saveButton = button("OneSettingsSave", control, OS.strings.save, function() self:ShowName() end)
    self.loadButton = button("OneSettingsLoad", control, OS.strings.load, function() self:ShowPresets() end)
    self.saveButton:SetAnchor(BOTTOMRIGHT, divider, TOPRIGHT, -160, -8)
    self.loadButton:SetAnchor(BOTTOMRIGHT, divider, TOPRIGHT, 0, -8)
end

function UI:StyleDependencyRow(row, data)
    if not data.hasDependencyError or not data.addOnFileName then return end
    if not OS.Dependencies.Check(OS.modules.addons.catalog, data.addOnFileName) then return end
    -- Installed dependencies can be switched off without being missing.
    -- Change presentation only; retain the native dependency flags and checks.
    for _, child in ipairs({ "Name", "Author", "State", "Dependencies" }) do
        local label = row:GetNamedChild(child)
        local text = label:GetText() or ""
        label:SetText((text:gsub("|[cC]%x%x%x%x%x%x", ""):gsub("|[rR]", "")))
        label:SetColor(ZO_DEFAULT_DISABLED_COLOR:UnpackRGBA())
    end
end

function UI:AllowDependencyEnable(row, data)
    if not data.hasDependencyError or not data.addOnFileName then return end
    local addons = OS.modules.addons
    local node = addons.catalog[data.addOnFileName]
    if not node or node.library or not addons.manager:AreAddOnsEnabled()
        or not HasAgreedToEULA(EULA_TYPE_ADDON_EULA) then return end
    -- Even broken/partly installed modules must remain possible to turn off.
    if data.addOnEnabled then row:GetNamedChild("Enabled"):SetHidden(false); return end
    local _, compatible = OS.Dependencies.Check(addons.catalog, data.addOnFileName)
    if compatible then row:GetNamedChild("Enabled"):SetHidden(false) end
end

function UI:PatchRows(list)
    self.rowSetups = self.rowSetups or {}
    for typeId, dataType in pairs(list.dataTypes or {}) do
        if typeId ~= 2 and dataType.setupCallback and dataType.setupCallback ~= self.rowSetups[dataType] then
            local original = dataType.setupCallback
            local wrapper = function(row, data, ...)
                original(row, data, ...)
                self:StyleDependencyRow(row, data)
                self:AllowDependencyEnable(row, data)
            end
            self.rowSetups[dataType] = wrapper
            dataType.setupCallback = wrapper
        end
    end
end

function UI:Initialize()
    self:InstallSettings()
    self:InstallDialogs()
    self:InstallButtons()
    if ADD_ON_MANAGER and ADD_ON_MANAGER.list then self:PatchRows(ADD_ON_MANAGER.list) end
    SecurePostHook(_G, "ZO_ScrollList_AddDataType", function(list)
        if ADD_ON_MANAGER and list == ADD_ON_MANAGER.list then self:PatchRows(list) end
    end)
    SecurePostHook(ZO_AddOnManager, "OnShow", function() self:InstallButtons() end)
end
