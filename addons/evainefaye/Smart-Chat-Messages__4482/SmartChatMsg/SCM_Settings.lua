SmartChatMsg = SmartChatMsg or {}

SmartChatMsg.settings = SmartChatMsg.settings or {
    createMode = false,
    editMode = false,
    pendingCommand = "",
    pendingReminderMinutes = "",
    pendingAutoPopulateOnZone = false,
    pendingGuildReminderMinutes = "",
    pendingGuildReminderRetryMinutes = "0",
    pendingGuildAutoPopulateOnZone = false,
    pendingGuildRunAt = "ON_DEMAND",
    pendingGuildOpenStatusPanelOnRun = false,
    pendingGuildAutoPopulateCooldownMinutes = "60",
    pendingGuildPopulateSound = "DUEL_START",
    pendingGeneralRevertChatSeconds = "60",
    pendingImportExportText = "",
    editingOriginalCommandId = nil,

    pendingNewMessageText = "",
    pendingMessageEdits = {},
    selectedMessageEntryIds = {},

    panel = nil,
    controls = {},
    deleteDialogRegistered = false,
    deleteMessageDialogRegistered = false,
    deleteSelectedMessagesDialogRegistered = false,
    importDialogRegistered = false,
}

local LAM2 = LibAddonMenu2

local DROPDOWN_WIDTH = 280
local LABEL_WIDTH = 180
local ROW_WIDTH = 700
local MESSAGE_BOX_WIDTH = 360
local MESSAGE_BOX_HEIGHT = 90
local CHECKBOX_WIDTH = 28

local USEFUL_SOUND_KEYS = {
    "NONE",
    "DUEL_START",
    "DEFAULT_CLICK",
    "POSITIVE_CLICK",
    "NEGATIVE_CLICK",
    "DIALOG_ACCEPT",
    "DIALOG_DECLINE",
    "NEW_NOTIFICATION",
    "QUEST_SHARE_ACCEPTED",
    "BOOK_ACQUIRED",
    "ACHIEVEMENT_AWARDED",
    "BATTLEGROUND_CAPTURE_FLAG_TAKEN",
    "BATTLEGROUND_CAPTURE_FLAG_RETURNED",
    "BATTLEGROUND_MEDAL_AWARDED",
    "CHAMPION_POINT_GAINED",
    "TELVAR_GAINED",
    "TELVAR_LOST",
    "TRADE_INVITE",
    "GROUP_INVITE",
    "LFG_ACCEPTED",
    "JUSTICE_NOW_KOS",
    "JUSTICE_STATE_CHANGED",
}

local function GetUsefulSoundOptions()
    local options = {}
    local seen = {}

    for _, key in ipairs(USEFUL_SOUND_KEYS) do
        if key == "NONE" or (type(SOUNDS) == "table" and SOUNDS[key]) then
            if not seen[key] then
                table.insert(options, key)
                seen[key] = true
            end
        end
    end

    if not seen["DUEL_START"] then
        table.insert(options, "DUEL_START")
    end

    return options
end


local function GetRunAtOptions()
    return {
        { value = "ON_DEMAND", label = "On Demand" },
        { value = "STARTUP", label = "Startup" },
        { value = "SCHEDULED", label = "Scheduled" },
    }
end

local DELETE_DIALOG_NAME = "SCM_CONFIRM_DELETE_MESSAGE_TYPE"
local DELETE_MESSAGE_DIALOG_NAME = "SCM_CONFIRM_DELETE_MESSAGE_ENTRY"
local DELETE_SELECTED_MESSAGES_DIALOG_NAME = "SCM_CONFIRM_DELETE_SELECTED_MESSAGE_ENTRIES"
local IMPORT_SETTINGS_DIALOG_NAME = "SCM_CONFIRM_IMPORT_SETTINGS"

local function RegisterDeleteDialogs()
    if not SmartChatMsg.settings.deleteDialogRegistered then
        ZO_Dialogs_RegisterCustomDialog(DELETE_DIALOG_NAME, {
            title = { text = "Delete Command" },
            mainText = { text = "Are you sure you want to delete this Command? Any messages associated to this Command will also be deleted." },
            buttons = {
                {
                    text = SI_DIALOG_CONFIRM,
                    callback = function(dialog)
                        local data = dialog.data
                        if data and data.callback then
                            data.callback()
                        end
                    end,
                },
                { text = SI_DIALOG_CANCEL },
            },
        })

        SmartChatMsg.settings.deleteDialogRegistered = true
    end

    if not SmartChatMsg.settings.deleteMessageDialogRegistered then
        ZO_Dialogs_RegisterCustomDialog(DELETE_MESSAGE_DIALOG_NAME, {
            title = { text = "Delete Message" },
            mainText = { text = "Are you sure you want to delete this message?" },
            buttons = {
                {
                    text = SI_DIALOG_CONFIRM,
                    callback = function(dialog)
                        local data = dialog.data
                        if data and data.callback then
                            data.callback()
                        end
                    end,
                },
                { text = SI_DIALOG_CANCEL },
            },
        })

        SmartChatMsg.settings.deleteMessageDialogRegistered = true
    end

    if not SmartChatMsg.settings.deleteSelectedMessagesDialogRegistered then
        ZO_Dialogs_RegisterCustomDialog(DELETE_SELECTED_MESSAGES_DIALOG_NAME, {
            title = { text = "Delete Selected Messages" },
            mainText = { text = "Are you sure you want to delete the selected messages?" },
            buttons = {
                {
                    text = SI_DIALOG_CONFIRM,
                    callback = function(dialog)
                        local data = dialog.data
                        if data and data.callback then
                            data.callback()
                        end
                    end,
                },
                { text = SI_DIALOG_CANCEL },
            },
        })

        SmartChatMsg.settings.deleteSelectedMessagesDialogRegistered = true
    end

    if not SmartChatMsg.settings.importDialogRegistered then
        ZO_Dialogs_RegisterCustomDialog(IMPORT_SETTINGS_DIALOG_NAME, {
            title = { text = "Import Settings" },
            mainText = { text = "Import replaces settings and unlocked messages. Locked messages stay only if their commands remain. Continue?" },
            buttons = {
                {
                    text = SI_DIALOG_CONFIRM,
                    callback = function(dialog)
                        local data = dialog.data
                        if data and data.callback then
                            data.callback()
                        end
                    end,
                },
                { text = SI_DIALOG_CANCEL },
            },
        })

        SmartChatMsg.settings.importDialogRegistered = true
    end
end

function SmartChatMsg:HasAnyGuilds()
    for guildIndex = 1, 5 do
        local guildId = GetGuildId(guildIndex)
        if guildId and guildId ~= 0 then
            return true
        end
    end

    return false
end

function SmartChatMsg:CanUseMessagesSection()
    return self:HasCommands() and self:HasAnyGuilds()
end

function SmartChatMsg.settings:GetSelectedMessageEntryCount()
    local count = 0

    for _, isSelected in pairs(self.selectedMessageEntryIds or {}) do
        if isSelected then
            count = count + 1
        end
    end

    return count
end

function SmartChatMsg.settings:ClearSelectedMessageEntries()
    self.selectedMessageEntryIds = {}
end

function SmartChatMsg.settings:ClearPendingMessageEdits()
    self.pendingMessageEdits = {}
end

function SmartChatMsg.settings:GetPendingMessageEdit(entryId)
    if type(entryId) ~= "string" or entryId == "" then
        return nil
    end

    return self.pendingMessageEdits[entryId]
end

function SmartChatMsg.settings:GetEffectiveMessageText(entry)
    if type(entry) ~= "table" or type(entry.id) ~= "string" then
        return ""
    end

    local pendingText = self:GetPendingMessageEdit(entry.id)
    if pendingText ~= nil then
        return pendingText
    end

    return entry.text or ""
end

function SmartChatMsg.settings:IsMessageEntryDirty(entry)
    if type(entry) ~= "table" or type(entry.id) ~= "string" then
        return false
    end

    local pendingText = self:GetPendingMessageEdit(entry.id)
    if pendingText == nil then
        return false
    end

    return pendingText ~= (entry.text or "")
end

function SmartChatMsg.settings:SetPendingMessageEdit(entryId, text, originalText)
    if type(entryId) ~= "string" or entryId == "" then
        return
    end

    local value = text or ""
    local baseline = originalText or ""

    if value == baseline then
        self.pendingMessageEdits[entryId] = nil
    else
        self.pendingMessageEdits[entryId] = value
    end
end

function SmartChatMsg.settings:InitializeState()
    self.pendingCommand = ""
    self.pendingReminderMinutes = ""
    self.pendingAutoPopulateOnZone = false
    self.pendingGuildReminderMinutes = ""
    self.pendingGuildAutoPopulateOnZone = false
    self.pendingGuildAutoPopulateCooldownMinutes = "60"
    self.pendingGuildPopulateSound = "DUEL_START"
    self.pendingGeneralRevertChatSeconds = tostring(SmartChatMsg:GetRevertChatSeconds() or 60)
    self.editingOriginalCommandId = nil
    self.editMode = false
    self.pendingNewMessageText = ""
    self:ClearPendingMessageEdits()
    self:ClearSelectedMessageEntries()

    if SmartChatMsg:HasCommands() then
        self.createMode = false
    else
        self.createMode = true
    end

    SmartChatMsg:SetSelectedCommand(nil)

    if not SmartChatMsg:CanUseMessagesSection() then
        SmartChatMsg:SetMessagesSelectedCommand(nil)
        SmartChatMsg:SetSelectedGuildIndex(nil)
    elseif SmartChatMsg:IsMessagesSelectionComplete() then
        local commandId = SmartChatMsg.savedVars.selectedMessagesCommand
        local guildName = SmartChatMsg:GetSelectedGuildNameForMessages()
        local savedChannel = SmartChatMsg:GetSavedChatChannel(commandId, guildName)

        if savedChannel then
            SmartChatMsg:SetSelectedMessagesChannel(savedChannel)
        else
            SmartChatMsg:SetSelectedMessagesChannel(nil)
        end

        local reminderMinutes = SmartChatMsg:GetGuildReminderMinutes(commandId, guildName)
        self.pendingGuildReminderMinutes = reminderMinutes and tostring(reminderMinutes) or ""
        self.pendingGuildReminderRetryMinutes = tostring(SmartChatMsg:GetGuildEffectiveReminderRetryMinutes(commandId, guildName) or 0)
        self.pendingGuildAutoPopulateOnZone = SmartChatMsg:GetGuildAutoPopulateOnZone(commandId, guildName) == true
        self.pendingGuildRunAt = SmartChatMsg:GetGuildRunAt(commandId, guildName) or "ON_DEMAND"
        self.pendingGuildOpenStatusPanelOnRun = SmartChatMsg:GetGuildOpenStatusPanelOnRun(commandId, guildName) == true
        self.pendingGuildAutoPopulateCooldownMinutes = tostring(SmartChatMsg:GetGuildAutoPopulateCooldownMinutes(commandId, guildName) or 60)
        self.pendingGuildPopulateSound = SmartChatMsg:GetGuildPopulateSound(commandId, guildName) or "DUEL_START"
    else
        SmartChatMsg:SetSelectedMessagesChannel(nil)
        self.pendingGuildReminderMinutes = ""
        self.pendingGuildReminderRetryMinutes = "0"
        self.pendingGuildAutoPopulateOnZone = false
        self.pendingGuildRunAt = "ON_DEMAND"
        self.pendingGuildOpenStatusPanelOnRun = false
        self.pendingGuildAutoPopulateCooldownMinutes = "60"
        self.pendingGuildPopulateSound = "DUEL_START"
    end
end

function SmartChatMsg.settings:IsEditorVisible()
    return self.createMode or self.editMode
end

function SmartChatMsg.settings:SaveBehaviorSettings()
    if not SmartChatMsg:IsMessagesSelectionComplete() then
        return true
    end

    local commandId = SmartChatMsg.savedVars.selectedMessagesCommand
    local guildName = SmartChatMsg:GetSelectedGuildNameForMessages()

    if not commandId or not guildName then
        return true
    end

    local ok, err = SmartChatMsg:SetGuildReminderMinutes(commandId, guildName, self.pendingGuildReminderMinutes)
    if not ok then
        return false, err
    end

    ok, err = SmartChatMsg:SetGuildReminderRetryMinutes(commandId, guildName, self.pendingGuildReminderRetryMinutes)
    if not ok then
        return false, err
    end

    ok, err = SmartChatMsg:SetGuildAutoPopulateOnZone(commandId, guildName, self.pendingGuildAutoPopulateOnZone == true)
    if not ok then
        return false, err
    end

    ok, err = SmartChatMsg:SetGuildAutoPopulateCooldownMinutes(commandId, guildName, self.pendingGuildAutoPopulateCooldownMinutes)
    if not ok then
        return false, err
    end

    ok, err = SmartChatMsg:SetGuildRunAt(commandId, guildName, self.pendingGuildRunAt)
    if not ok then
        return false, err
    end

    ok, err = SmartChatMsg:SetGuildOpenStatusPanelOnRun(commandId, guildName, self.pendingGuildOpenStatusPanelOnRun == true)
    if not ok then
        return false, err
    end

    ok, err = SmartChatMsg:SetGuildPopulateSound(commandId, guildName, self.pendingGuildPopulateSound)
    if not ok then
        return false, err
    end

    return true
end

function SmartChatMsg.settings:SaveGeneralSettings()
    local ok, err = SmartChatMsg:SetRevertChatSeconds(self.pendingGeneralRevertChatSeconds)
    if not ok then
        return false, err
    end

    self.pendingGeneralRevertChatSeconds = tostring(SmartChatMsg:GetRevertChatSeconds() or 60)
    return true
end

function SmartChatMsg.settings:ResetNewMessageSection()
    self.pendingNewMessageText = ""
    self:ClearPendingMessageEdits()
    self:ClearSelectedMessageEntries()

    if self.controls.newMessageEditBox then
        self.controls.newMessageEditBox:SetText("")
    end

    if SmartChatMsg:IsMessagesSelectionComplete() then
        local commandId = SmartChatMsg.savedVars.selectedMessagesCommand
        local guildName = SmartChatMsg:GetSelectedGuildNameForMessages()
        local savedChannel = SmartChatMsg:GetSavedChatChannel(commandId, guildName)

        if savedChannel then
            SmartChatMsg:SetSelectedMessagesChannel(savedChannel)
        else
            SmartChatMsg:SetSelectedMessagesChannel(nil)
        end

        local reminderMinutes = SmartChatMsg:GetGuildReminderMinutes(commandId, guildName)
        self.pendingGuildReminderMinutes = reminderMinutes and tostring(reminderMinutes) or ""
        self.pendingGuildReminderRetryMinutes = tostring(SmartChatMsg:GetGuildEffectiveReminderRetryMinutes(commandId, guildName) or 0)
        self.pendingGuildAutoPopulateOnZone = SmartChatMsg:GetGuildAutoPopulateOnZone(commandId, guildName) == true
        self.pendingGuildRunAt = SmartChatMsg:GetGuildRunAt(commandId, guildName) or "ON_DEMAND"
        self.pendingGuildOpenStatusPanelOnRun = SmartChatMsg:GetGuildOpenStatusPanelOnRun(commandId, guildName) == true
        self.pendingGuildAutoPopulateCooldownMinutes = tostring(SmartChatMsg:GetGuildAutoPopulateCooldownMinutes(commandId, guildName) or 60)
        self.pendingGuildPopulateSound = SmartChatMsg:GetGuildPopulateSound(commandId, guildName) or "DUEL_START"
    else
        SmartChatMsg:SetSelectedMessagesChannel(nil)
        self.pendingGuildReminderMinutes = ""
        self.pendingGuildReminderRetryMinutes = "0"
        self.pendingGuildAutoPopulateOnZone = false
        self.pendingGuildRunAt = "ON_DEMAND"
        self.pendingGuildOpenStatusPanelOnRun = false
        self.pendingGuildAutoPopulateCooldownMinutes = "60"
        self.pendingGuildPopulateSound = "DUEL_START"
    end

    SmartChatMsg:RefreshSettingsUI()
end

function SmartChatMsg.settings:EnableCreateState()
    self.createMode = true
    self.editMode = false
    self.editingOriginalCommandId = nil
    self.pendingCommand = ""
    self.pendingReminderMinutes = ""

    SmartChatMsg:SetSelectedCommand(nil)

    if self.controls.commandEditBox then
        self.controls.commandEditBox:SetText("")
    end

    if self.controls.commandReminderEditBox then
        self.controls.commandReminderEditBox:SetText("")
    end

    SmartChatMsg:RefreshSettingsUI()
end

function SmartChatMsg.settings:EnableEditState(commandId)
    local command = SmartChatMsg:GetCommandById(commandId)
    if not command then
        self:ResetEditorState()
        return
    end

    self.createMode = false
    self.editMode = true
    self.editingOriginalCommandId = command.id
    self.pendingCommand = command.name or ""
    self.pendingReminderMinutes = ""
    self.pendingAutoPopulateOnZone = false

    SmartChatMsg:SetSelectedCommand(command.id)

    if self.controls.commandEditBox then
        self.controls.commandEditBox:SetText(self.pendingCommand)
    end

    if self.controls.commandReminderEditBox then
        self.controls.commandReminderEditBox:SetText(self.pendingReminderMinutes)
    end

    if self.controls.commandAutoPopulateCheckbox then
        ZO_CheckButton_SetCheckState(self.controls.commandAutoPopulateCheckbox, self.pendingAutoPopulateOnZone)
    end

    SmartChatMsg:RefreshSettingsUI()
end

function SmartChatMsg.settings:ResetEditorState()
    self.pendingCommand = ""
    self.pendingReminderMinutes = ""
    self.pendingAutoPopulateOnZone = false
    self.editingOriginalCommandId = nil
    self.editMode = false

    if SmartChatMsg:HasCommands() then
        self.createMode = false
    else
        self.createMode = true
    end

    SmartChatMsg:SetSelectedCommand(nil)

    if self.controls.commandEditBox then
        self.controls.commandEditBox:SetText("")
    end

    if self.controls.commandAutoPopulateCheckbox then
        ZO_CheckButton_SetCheckState(self.controls.commandAutoPopulateCheckbox, false)
    end

    SmartChatMsg:RefreshSettingsUI()
end

function SmartChatMsg.settings:SaveCommand()
    local text = self.pendingCommand or ""

    if self.createMode then
        local ok, err = SmartChatMsg:AddCommand(text)

        if not ok then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
            return
        end

        PlaySound(SOUNDS.DEFAULT_CLICK)
        self:ResetEditorState()
        return
    end

    if self.editMode then
        local commandId = self.editingOriginalCommandId
        local ok, err = SmartChatMsg:RenameCommand(commandId, text)

        if not ok then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
            return
        end

        PlaySound(SOUNDS.DEFAULT_CLICK)
        self:ResetEditorState()
    end
end

function SmartChatMsg.settings:ExportSettings()
    self.pendingImportExportText = SmartChatMsg:BuildExportString()

    if self.controls.importExportEditBox then
        self.controls.importExportEditBox:SetText(self.pendingImportExportText)
        self.controls.importExportEditBox:TakeFocus()
    end

    local message = "Export completed successfully."
    SmartChatMsg:AddLocalChatMessage(message)

    if CENTER_SCREEN_ANNOUNCE then
        CENTER_SCREEN_ANNOUNCE:AddMessage(EVENT_SKILL_RANK_UPDATE, CSA_EVENT_SMALL_TEXT, SOUNDS.DEFAULT_CLICK, message)
    else
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, message)
    end

    PlaySound(SOUNDS.DEFAULT_CLICK)
end

function SmartChatMsg.settings:ImportSettings()
    local rawText = self.pendingImportExportText or ""
    if SmartChatMsg:Trim(rawText) == "" then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, "Paste exported settings first.")
        return
    end

    ZO_Dialogs_ShowDialog(IMPORT_SETTINGS_DIALOG_NAME, {
        callback = function()
            local ok, err = SmartChatMsg:ImportSettingsFromString(rawText)
            if not ok then
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
                return
            end

            self:InitializeState()
            self.pendingImportExportText = ""
            if self.controls.importExportEditBox then
                self.controls.importExportEditBox:SetText("")
            end
            SmartChatMsg:RefreshSettingsUI()

            local message = "Import completed successfully."
            SmartChatMsg:AddLocalChatMessage(message)

            if CENTER_SCREEN_ANNOUNCE then
                CENTER_SCREEN_ANNOUNCE:AddMessage(EVENT_SKILL_RANK_UPDATE, CSA_EVENT_SMALL_TEXT, SOUNDS.DEFAULT_CLICK, message)
            else
                ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, message)
            end

            PlaySound(SOUNDS.MESSAGE_BROADCAST)
        end,
    })
end

function SmartChatMsg.settings:ClearImportExportText()
    self.pendingImportExportText = ""
    if self.controls.importExportEditBox then
        self.controls.importExportEditBox:SetText("")
    end
    PlaySound(SOUNDS.DEFAULT_CLICK)
end

function SmartChatMsg.settings:DeleteCurrentCommand()
    if not self.editMode or not self.editingOriginalCommandId or self.editingOriginalCommandId == "" then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, "No Command is selected to delete.")
        return
    end

    ZO_Dialogs_ShowDialog(DELETE_DIALOG_NAME, {
        callback = function()
            local ok, err = SmartChatMsg:DeleteCommand(self.editingOriginalCommandId)

            if not ok then
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
                return
            end

            PlaySound(SOUNDS.DEFAULT_CLICK)
            self:ResetEditorState()

            if not SmartChatMsg:CanUseMessagesSection() then
                SmartChatMsg:SetMessagesSelectedCommand(nil)
                SmartChatMsg:SetSelectedGuildIndex(nil)
            end
        end,
    })
end

function SmartChatMsg.settings:SaveMessagesSection()
    local selectedChannel = SmartChatMsg:GetSelectedMessagesChannel()
    if selectedChannel == "Select a Chat Channel" then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, "Select a Chat Channel first.")
        return
    end

    local ok, err = self:SaveBehaviorSettings()
    if not ok then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
        return
    end

    local rows = self.controls.savedMessageRows or {}
    for _, row in ipairs(rows) do
        if row and row.entryId and row.editBox then
            local trimmed = SmartChatMsg:Trim(row.editBox:GetText() or "")
            if trimmed == "" then
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, "Existing messages must contain at least one non-space character.")
                return
            end
        end
    end

    for _, row in ipairs(rows) do
        if row and row.entryId and row.editBox then
            local trimmed = SmartChatMsg:Trim(row.editBox:GetText() or "")
            local ok, err = SmartChatMsg:UpdateMessageEntry(row.entryId, trimmed)
            if not ok then
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
                return
            end
        end
    end

    local newText = SmartChatMsg:Trim(self.pendingNewMessageText or "")
    if newText ~= "" then
        local ok, err = SmartChatMsg:AddMessageEntryForSelection(newText)
        if not ok then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
            return
        end
    end

    PlaySound(SOUNDS.DEFAULT_CLICK)
    self.pendingNewMessageText = ""
    self:ClearSelectedMessageEntries()

    if self.controls.newMessageEditBox then
        self.controls.newMessageEditBox:SetText("")
    end

    SmartChatMsg:RefreshSettingsUI()
end

function SmartChatMsg.settings:DeleteSelectedMessages()
    local selectedIds = {}

    for entryId, isSelected in pairs(self.selectedMessageEntryIds or {}) do
        if isSelected then
            table.insert(selectedIds, entryId)
        end
    end

    if #selectedIds == 0 then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, "No messages are selected.")
        return
    end

    ZO_Dialogs_ShowDialog(DELETE_SELECTED_MESSAGES_DIALOG_NAME, {
        callback = function()
            local ok, err = SmartChatMsg:DeleteMessageEntries(selectedIds)

            if not ok then
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
                return
            end

            self:ClearSelectedMessageEntries()
            PlaySound(SOUNDS.DEFAULT_CLICK)
            SmartChatMsg:RefreshSettingsUI()
        end,
    })
end

local function BuildCommandDropdown(parent)
    local container = WINDOW_MANAGER:CreateControl("SCM_CommandDropdownContainer", parent, CT_CONTROL)
    container:SetDimensions(ROW_WIDTH, 40)

    local label = WINDOW_MANAGER:CreateControl("SCM_CommandDropdownLabel", container, CT_LABEL)
    label:SetFont("ZoFontWinH4")
    label:SetText("Command")
    label:SetDimensions(LABEL_WIDTH, 30)
    label:SetAnchor(LEFT, container, LEFT, 0, 0)

    local comboBoxControl = WINDOW_MANAGER:CreateControlFromVirtual("SCM_CommandDropdownCombo", container, "ZO_ComboBox")
    comboBoxControl:SetDimensions(DROPDOWN_WIDTH, 28)
    comboBoxControl:SetAnchor(LEFT, label, RIGHT, 10, 0)

    local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxControl)
    comboBox:SetSortsItems(false)

    local addButton = WINDOW_MANAGER:CreateControl("SCM_CommandDropdownAddButton", container, CT_BUTTON)
    addButton:SetDimensions(28, 28)
    addButton:SetAnchor(LEFT, comboBoxControl, RIGHT, 8, 0)
    addButton:SetFont("ZoFontGameLargeBold")
    addButton:SetText("+")
    addButton:SetNormalFontColor(1, 1, 1, 1)
    addButton:SetMouseOverFontColor(1, 0.9, 0.4, 1)
    addButton:SetPressedFontColor(0.7, 0.7, 0.7, 1)

    addButton:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, TOP, 0, 8)
        SetTooltipText(InformationTooltip, "Add Command")
    end)

    addButton:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    addButton:SetHandler("OnClicked", function()
        SmartChatMsg.settings:EnableCreateState()
    end)

    local function RefreshDropdown()
        comboBox:ClearItems()

        local options = SmartChatMsg:GetCommandOptions()
        local currentSelection = SmartChatMsg:GetSelectedCommand()

        for _, option in ipairs(options) do
            local entry = comboBox:CreateItemEntry(option.name, function()
                if option.mode == "create" then
                    SmartChatMsg.settings:EnableCreateState()
                elseif option.mode == "select" then
                    SmartChatMsg.settings:ResetEditorState()
                else
                    SmartChatMsg.settings:EnableEditState(option.value)
                end
            end)
            comboBox:AddItem(entry)
        end

        comboBox:SetSelectedItem(currentSelection.name)
    end

    container.RefreshDropdown = RefreshDropdown
    RefreshDropdown()

    SmartChatMsg.settings.controls.commandDropdown = container
    return container
end


local function BuildCommandEditor(parent)
    local container = WINDOW_MANAGER:CreateControl("SCM_CommandEditorContainer", parent, CT_CONTROL)
    container:SetDimensions(ROW_WIDTH, 96)

    local label = WINDOW_MANAGER:CreateControl("SCM_CommandEditorLabel", container, CT_LABEL)
    label:SetFont("ZoFontWinH4")
    label:SetText("Enter Command Name")
    label:SetDimensions(LABEL_WIDTH, 30)
    label:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual("SCM_CommandEditorBackdrop", container, "ZO_EditBackdrop")
    backdrop:SetDimensions(DROPDOWN_WIDTH, 30)
    backdrop:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, 4)

    local editBox = WINDOW_MANAGER:CreateControlFromVirtual("SCM_CommandEditorEditBox", backdrop, "ZO_DefaultEditForBackdrop")
    editBox:SetAnchorFill(backdrop)
    editBox:SetMaxInputChars(25)
    editBox:SetText("")

    editBox:SetHandler("OnTextChanged", function(self)
        local text = self:GetText() or ""

        if zo_strlen(text) > 25 then
            text = zo_strsub(text, 1, 25)
            self:SetText(text)
        end

        SmartChatMsg.settings.pendingCommand = text
    end)

    local saveButton = WINDOW_MANAGER:CreateControlFromVirtual("SCM_CommandEditorSaveButton", container, "ZO_DefaultButton")
    saveButton:SetDimensions(90, 28)
    saveButton:SetAnchor(TOPLEFT, editBox, BOTTOMLEFT, 0, 8)
    saveButton:SetHandler("OnClicked", function()
        SmartChatMsg.settings:SaveCommand()
    end)

    local resetButton = WINDOW_MANAGER:CreateControlFromVirtual("SCM_CommandEditorResetButton", container, "ZO_DefaultButton")
    resetButton:SetDimensions(90, 28)
    resetButton:SetAnchor(LEFT, saveButton, RIGHT, 8, 0)
    resetButton:SetText("Reset")
    resetButton:SetHandler("OnClicked", function()
        SmartChatMsg.settings:ResetEditorState()
    end)

    local deleteButton = WINDOW_MANAGER:CreateControlFromVirtual("SCM_CommandEditorDeleteButton", container, "ZO_DefaultButton")
    deleteButton:SetDimensions(90, 28)
    deleteButton:SetAnchor(LEFT, resetButton, RIGHT, 8, 0)
    deleteButton:SetText("Delete")
    deleteButton:SetHandler("OnClicked", function()
        SmartChatMsg.settings:DeleteCurrentCommand()
    end)

    container.RefreshEditor = function()
        if SmartChatMsg.settings.controls.commandEditBox then
            SmartChatMsg.settings.controls.commandEditBox:SetText(SmartChatMsg.settings.pendingCommand or "")
        end

        if SmartChatMsg.settings.createMode then
            saveButton:SetText("Add")
        elseif SmartChatMsg.settings.editMode then
            saveButton:SetText("Update")
        else
            saveButton:SetText("Add")
        end

        deleteButton:SetHidden(not SmartChatMsg.settings.editMode)
        container:SetHidden(not SmartChatMsg.settings:IsEditorVisible())
    end

    SmartChatMsg.settings.controls.commandEditBox = editBox
    SmartChatMsg.settings.controls.commandEditor = container

    container:RefreshEditor()
    return container
end

local function BuildMessagesCommandDropdown(parent)
    local container = WINDOW_MANAGER:CreateControl("SCM_MessagesCommandDropdownContainer", parent, CT_CONTROL)
    container:SetDimensions(ROW_WIDTH, 40)

    local label = WINDOW_MANAGER:CreateControl("SCM_MessagesCommandDropdownLabel", container, CT_LABEL)
    label:SetFont("ZoFontWinH4")
    label:SetText("Command")
    label:SetDimensions(LABEL_WIDTH, 30)
    label:SetAnchor(LEFT, container, LEFT, 0, 0)

    local comboBoxControl = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesCommandDropdownCombo", container, "ZO_ComboBox")
    comboBoxControl:SetDimensions(DROPDOWN_WIDTH, 28)
    comboBoxControl:SetAnchor(LEFT, label, RIGHT, 10, 0)

    local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxControl)
    comboBox:SetSortsItems(false)

    local function RefreshDropdown()
        comboBox:ClearItems()

        local options = SmartChatMsg:GetMessagesCommandOptions()
        local currentSelection = SmartChatMsg:GetMessagesSelectedCommand()

        for _, option in ipairs(options) do
            local entry = comboBox:CreateItemEntry(option.name, function()
                SmartChatMsg:SetMessagesSelectedCommand(option.value)
                SmartChatMsg.settings:ResetNewMessageSection()
                SmartChatMsg:RefreshSettingsUI()
            end)
            comboBox:AddItem(entry)
        end

        comboBox:SetSelectedItem(currentSelection.name)
    end

    container.RefreshDropdown = RefreshDropdown
    RefreshDropdown()

    SmartChatMsg.settings.controls.messagesCommandDropdown = container
    return container
end

local function BuildMessagesGuildDropdown(parent)
    local container = WINDOW_MANAGER:CreateControl("SCM_MessagesGuildDropdownContainer", parent, CT_CONTROL)
    container:SetDimensions(ROW_WIDTH, 40)

    local label = WINDOW_MANAGER:CreateControl("SCM_MessagesGuildDropdownLabel", container, CT_LABEL)
    label:SetFont("ZoFontWinH4")
    label:SetText("Guild")
    label:SetDimensions(LABEL_WIDTH, 30)
    label:SetAnchor(LEFT, container, LEFT, 0, 0)

    local comboBoxControl = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesGuildDropdownCombo", container, "ZO_ComboBox")
    comboBoxControl:SetDimensions(DROPDOWN_WIDTH, 28)
    comboBoxControl:SetAnchor(LEFT, label, RIGHT, 10, 0)

    local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxControl)
    comboBox:SetSortsItems(false)

    local function RefreshDropdown()
        comboBox:ClearItems()

        local options = SmartChatMsg:GetGuildOptions()
        local currentSelection = SmartChatMsg:GetSelectedGuildDisplayName()

        for _, option in ipairs(options) do
            local entry = comboBox:CreateItemEntry(option.name, function()
                SmartChatMsg:SetSelectedGuildIndex(option.value)
                SmartChatMsg.settings:ResetNewMessageSection()
                SmartChatMsg:RefreshSettingsUI()
            end)
            comboBox:AddItem(entry)
        end

        comboBox:SetSelectedItem(currentSelection)
    end

    container.RefreshDropdown = RefreshDropdown
    RefreshDropdown()

    SmartChatMsg.settings.controls.messagesGuildDropdown = container
    return container
end

local function BuildDefaultGuildDropdown(parent)
    local container = WINDOW_MANAGER:CreateControl("SCM_DefaultGuildDropdownContainer", parent, CT_CONTROL)
    container:SetDimensions(ROW_WIDTH, 40)

    local label = WINDOW_MANAGER:CreateControl("SCM_DefaultGuildDropdownLabel", container, CT_LABEL)
    label:SetFont("ZoFontWinH4")
    label:SetText("Default Guild")
    label:SetDimensions(LABEL_WIDTH, 30)
    label:SetAnchor(LEFT, container, LEFT, 0, 0)

    local comboBoxControl = WINDOW_MANAGER:CreateControlFromVirtual("SCM_DefaultGuildDropdownCombo", container, "ZO_ComboBox")
    comboBoxControl:SetDimensions(DROPDOWN_WIDTH, 28)
    comboBoxControl:SetAnchor(LEFT, label, RIGHT, 10, 0)

    local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxControl)
    comboBox:SetSortsItems(false)

    local function RefreshDropdown()
        comboBox:ClearItems()

        local options = SmartChatMsg:GetDefaultGuildOptions()
        local currentSelection = SmartChatMsg:GetDefaultGuildDisplayName()

        for _, option in ipairs(options) do
            local entry = comboBox:CreateItemEntry(option.name, function()
                SmartChatMsg:SetDefaultGuildIndex(option.value)
                SmartChatMsg:RefreshSettingsUI()
            end)
            comboBox:AddItem(entry)
        end

        comboBox:SetSelectedItem(currentSelection)
    end

    container.RefreshDropdown = RefreshDropdown
    RefreshDropdown()

    SmartChatMsg.settings.controls.defaultGuildDropdown = container
    return container
end

local function BuildMessagesChannelDropdown(parent)
    local container = WINDOW_MANAGER:CreateControl("SCM_MessagesChannelDropdownContainer", parent, CT_CONTROL)
    container:SetDimensions(ROW_WIDTH, 40)

    local label = WINDOW_MANAGER:CreateControl("SCM_MessagesChannelDropdownLabel", container, CT_LABEL)
    label:SetFont("ZoFontWinH4")
    label:SetText("Output Channel")
    label:SetDimensions(LABEL_WIDTH, 30)
    label:SetAnchor(LEFT, container, LEFT, 0, 0)

    local comboBoxControl = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesChannelDropdownCombo", container, "ZO_ComboBox")
    comboBoxControl:SetDimensions(DROPDOWN_WIDTH, 28)
    comboBoxControl:SetAnchor(LEFT, label, RIGHT, 10, 0)

    local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxControl)
    comboBox:SetSortsItems(false)

    local function RefreshDropdown()
        comboBox:ClearItems()

        local options = SmartChatMsg:GetChatChannelOptions()
        local currentSelection = SmartChatMsg:GetSelectedMessagesChannel()

        for _, optionName in ipairs(options) do
            local entry = comboBox:CreateItemEntry(optionName, function()
                SmartChatMsg:SetSelectedMessagesChannel(optionName)
                SmartChatMsg:RefreshSettingsUI()
            end)
            comboBox:AddItem(entry)
        end

        comboBox:SetSelectedItem(currentSelection)
        container:SetHidden(not SmartChatMsg:IsMessagesSelectionComplete())
    end

    container.RefreshDropdown = RefreshDropdown
    RefreshDropdown()

    SmartChatMsg.settings.controls.messagesChannelDropdown = container
    return container
end



local function BuildMessagesBehaviorSettings(parent)
    local container = WINDOW_MANAGER:CreateControl("SCM_MessagesBehaviorSettingsContainer", parent, CT_CONTROL)
    container:SetDimensions(ROW_WIDTH, 235)

    local function HasActiveRepeatAfter()
        local value = tonumber(SmartChatMsg.settings.pendingGuildReminderMinutes or "")
        return value ~= nil and value > 0
    end

    local reminderLabel = WINDOW_MANAGER:CreateControl("SCM_MessagesReminderLabel", container, CT_LABEL)
    reminderLabel:SetFont("ZoFontWinH4")
    reminderLabel:SetText("Repeat Every (mins)")
    reminderLabel:SetDimensions(180, 30)
    reminderLabel:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)

    local reminderBackdrop = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesReminderBackdrop", container, "ZO_EditBackdrop")
    reminderBackdrop:SetDimensions(120, 30)
    reminderBackdrop:SetAnchor(LEFT, reminderLabel, RIGHT, 8, 0)

    local reminderEditBox = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesReminderEditBox", reminderBackdrop, "ZO_DefaultEditForBackdrop")
    reminderEditBox:SetAnchorFill(reminderBackdrop)
    reminderEditBox:SetMaxInputChars(4)
    reminderEditBox:SetText("")
    reminderEditBox:SetHandler("OnTextChanged", function(self)
        local text = self:GetText() or ""
        local digitsOnly = text:gsub("[^%d]", "")

        if digitsOnly ~= text then
            self:SetText(digitsOnly)
            return
        end

        SmartChatMsg.settings.pendingGuildReminderMinutes = digitsOnly

        if HasActiveRepeatAfter() then
            SmartChatMsg.settings.pendingGuildAutoPopulateOnZone = false
        end

        local ok, err = SmartChatMsg.settings:SaveBehaviorSettings()
        if not ok and err then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
            return
        end

        SmartChatMsg:RefreshSettingsUI()
    end)

    local reminderRetryLabel = WINDOW_MANAGER:CreateControl("SCM_MessagesReminderRetryLabel", container, CT_LABEL)
    reminderRetryLabel:SetFont("ZoFontGame")
    reminderRetryLabel:SetText("Retry Delay (mins)")
    reminderRetryLabel:SetDimensions(135, 24)
    reminderRetryLabel:SetAnchor(LEFT, reminderBackdrop, RIGHT, 5, 0)

    local reminderRetryBackdrop = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesReminderRetryBackdrop", container, "ZO_EditBackdrop")
    reminderRetryBackdrop:SetDimensions(70, 30)
    reminderRetryBackdrop:SetAnchor(LEFT, reminderRetryLabel, RIGHT, 13, 0)

    local reminderRetryEditBox = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesReminderRetryEditBox", reminderRetryBackdrop, "ZO_DefaultEditForBackdrop")
    reminderRetryEditBox:SetAnchorFill(reminderRetryBackdrop)
    reminderRetryEditBox:SetMaxInputChars(4)
    reminderRetryEditBox:SetText("")
    reminderRetryEditBox:SetHandler("OnTextChanged", function(self)
        if not HasActiveRepeatAfter() then
            return
        end

        local text = self:GetText() or ""
        local digitsOnly = text:gsub("[^%d]", "")

        if digitsOnly ~= text then
            self:SetText(digitsOnly)
            return
        end

        SmartChatMsg.settings.pendingGuildReminderRetryMinutes = digitsOnly ~= "" and digitsOnly or "0"

        local ok, err = SmartChatMsg.settings:SaveBehaviorSettings()
        if not ok and err then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
            return
        end

        SmartChatMsg:RefreshSettingsUI()
    end)

    local function HasAutomationBehaviorEnabled()
        if SmartChatMsg.settings.pendingGuildAutoPopulateOnZone == true then
            return true
        end

        local repeatMinutes = tonumber(SmartChatMsg.settings.pendingGuildReminderMinutes or "")
        return repeatMinutes ~= nil and repeatMinutes > 0
    end

    local autoPopulateCheckbox = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesAutoPopulateCheckbox", container, "ZO_CheckButton")
    autoPopulateCheckbox:SetAnchor(TOPLEFT, reminderBackdrop, BOTTOMLEFT, -110, 14)
    ZO_CheckButton_SetLabelText(autoPopulateCheckbox, "Auto Populate Chat on Zone")
    ZO_CheckButton_SetToggleFunction(autoPopulateCheckbox, function(_, checked)
        SmartChatMsg.settings.pendingGuildAutoPopulateOnZone = checked == true

        if checked == true then
            SmartChatMsg.settings.pendingGuildReminderMinutes = ""
        end

        local ok, err = SmartChatMsg.settings:SaveBehaviorSettings()
        if not ok and err then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
            return
        end

        SmartChatMsg:RefreshSettingsUI()
    end)

    local runAtLabel = WINDOW_MANAGER:CreateControl("SCM_MessagesRunAtLabel", container, CT_LABEL)
    runAtLabel:SetFont("ZoFontWinH4")
    runAtLabel:SetText("Run At")
    runAtLabel:SetDimensions(LABEL_WIDTH, 30)
    runAtLabel:SetAnchor(TOPLEFT, autoPopulateCheckbox, BOTTOMLEFT, 0, 0)

    local runAtComboBoxControl = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesRunAtDropdown", container, "ZO_ComboBox")
    runAtComboBoxControl:SetDimensions(DROPDOWN_WIDTH, 28)
    runAtComboBoxControl:SetAnchor(LEFT, runAtLabel, RIGHT, 8, 0)

    local runAtComboBox = ZO_ComboBox_ObjectFromContainer(runAtComboBoxControl)
    runAtComboBox:SetSortsItems(false)

    local function RefreshRunAtDropdown()
        runAtComboBox:ClearItems()

        local selectedValue = SmartChatMsg.settings.pendingGuildRunAt or "ON_DEMAND"
        local selectedLabel = "On Demand"

        for _, option in ipairs(GetRunAtOptions()) do
            if option.value == selectedValue then
                selectedLabel = option.label
            end

            local entry = runAtComboBox:CreateItemEntry(option.label, function()
                SmartChatMsg.settings.pendingGuildRunAt = option.value
                if option.value=="SCHEDULED" then SmartChatMsg:ShowStatusMessage("Open Scheduling below to configure and activate this command and guild.") end

                local ok, err = SmartChatMsg.settings:SaveBehaviorSettings()
                if not ok and err then
                    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
                    return
                end

                SmartChatMsg:RefreshSettingsUI()
            end)
            runAtComboBox:AddItem(entry)
        end

        runAtComboBox:SetSelectedItem(selectedLabel)
    end

    local openStatusPanelCheckbox = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesOpenStatusPanelOnRunCheckbox", container, "ZO_CheckButton")
    openStatusPanelCheckbox:SetAnchor(TOPLEFT, autoPopulateCheckbox, BOTTOMLEFT, 0, 18)
    runAtLabel:ClearAnchors()
    runAtLabel:SetAnchor(TOPLEFT, openStatusPanelCheckbox, BOTTOMLEFT, -70, 12)
    ZO_CheckButton_SetLabelText(openStatusPanelCheckbox, "Open Status Panel on Run")
    ZO_CheckButton_SetToggleFunction(openStatusPanelCheckbox, function(_, checked)
        if not HasAutomationBehaviorEnabled() then
            SmartChatMsg.settings.pendingGuildOpenStatusPanelOnRun = false
        else
            SmartChatMsg.settings.pendingGuildOpenStatusPanelOnRun = checked == true
        end

        local ok, err = SmartChatMsg.settings:SaveBehaviorSettings()
        if not ok and err then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
            return
        end

        SmartChatMsg:RefreshSettingsUI()
    end)

    local cooldownLabel = WINDOW_MANAGER:CreateControl("SCM_MessagesAutoPopulateCooldownLabel", container, CT_LABEL)
    cooldownLabel:SetFont("ZoFontGame")
    cooldownLabel:SetText("Cooldown (mins)")
    cooldownLabel:SetDimensions(125, 24)
    cooldownLabel:SetAnchor(LEFT, autoPopulateCheckbox, RIGHT, 230, 0)

    local cooldownBackdrop = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesAutoPopulateCooldownBackdrop", container, "ZO_EditBackdrop")
    cooldownBackdrop:SetDimensions(70, 30)
    cooldownBackdrop:SetAnchor(LEFT, cooldownLabel, RIGHT, 8, 0)

    local cooldownEditBox = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesAutoPopulateCooldownEditBox", cooldownBackdrop, "ZO_DefaultEditForBackdrop")
    cooldownEditBox:SetAnchorFill(cooldownBackdrop)
    cooldownEditBox:SetMaxInputChars(4)
    cooldownEditBox:SetText("")
    cooldownEditBox:SetHandler("OnTextChanged", function(self)
        local text = self:GetText() or ""
        local digitsOnly = text:gsub("[^%d]", "")

        if digitsOnly ~= text then
            self:SetText(digitsOnly)
            return
        end

        SmartChatMsg.settings.pendingGuildAutoPopulateCooldownMinutes = digitsOnly ~= "" and digitsOnly or "60"

        local ok, err = SmartChatMsg.settings:SaveBehaviorSettings()
        if not ok and err then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
            return
        end

        SmartChatMsg:RefreshSettingsUI()
    end)

    local soundLabel = WINDOW_MANAGER:CreateControl("SCM_MessagesPopulateSoundLabel", container, CT_LABEL)
    soundLabel:SetFont("ZoFontWinH4")
    soundLabel:SetText("Notify Sound")
    soundLabel:SetDimensions(LABEL_WIDTH, 30)
    soundLabel:SetAnchor(TOPLEFT, runAtLabel, BOTTOMLEFT, 0, 18)

    local soundComboBoxControl = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesPopulateSoundDropdown", container, "ZO_ComboBox")
    soundComboBoxControl:SetDimensions(DROPDOWN_WIDTH, 28)
    soundComboBoxControl:SetAnchor(LEFT, soundLabel, RIGHT, 8, 0)

    local soundComboBox = ZO_ComboBox_ObjectFromContainer(soundComboBoxControl)
    soundComboBox:SetSortsItems(false)

    local previewButton = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesPopulateSoundPreviewButton", container, "ZO_DefaultButton")
    previewButton:SetDimensions(90, 28)
    previewButton:SetAnchor(LEFT, soundComboBoxControl, RIGHT, 8, 0)
    previewButton:SetText("Preview")
    previewButton:SetHandler("OnClicked", function()
        local soundKey = SmartChatMsg.settings.pendingGuildPopulateSound or "DUEL_START"
        if soundKey ~= "NONE" and type(SOUNDS) == "table" and SOUNDS[soundKey] then
            PlaySound(SOUNDS[soundKey])
        end
    end)

    local function RefreshSoundDropdown()
        soundComboBox:ClearItems()

        local currentSelection = SmartChatMsg.settings.pendingGuildPopulateSound or "DUEL_START"
        local options = GetUsefulSoundOptions()
        local currentIsPresent = false

        for _, soundKey in ipairs(options) do
            if soundKey == currentSelection then
                currentIsPresent = true
            end

            local entry = soundComboBox:CreateItemEntry(soundKey, function()
                SmartChatMsg.settings.pendingGuildPopulateSound = soundKey

                local ok, err = SmartChatMsg.settings:SaveBehaviorSettings()
                if not ok and err then
                    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
                    return
                end

                SmartChatMsg:RefreshSettingsUI()
            end)
            soundComboBox:AddItem(entry)
        end

        if not currentIsPresent then
            local fallbackEntry = soundComboBox:CreateItemEntry(currentSelection, function()
                SmartChatMsg.settings.pendingGuildPopulateSound = currentSelection
                SmartChatMsg.settings:SaveBehaviorSettings()
                SmartChatMsg:RefreshSettingsUI()
            end)
            soundComboBox:AddItem(fallbackEntry)
        end

        soundComboBox:SetSelectedItem(currentSelection)
    end

    container.RefreshEditor = function()
        local shouldShow = SmartChatMsg:IsMessagesSelectionComplete()

        if reminderEditBox:GetText() ~= (SmartChatMsg.settings.pendingGuildReminderMinutes or "") then
            reminderEditBox:SetText(SmartChatMsg.settings.pendingGuildReminderMinutes or "")
        end

        local reminderRetryText = SmartChatMsg.settings.pendingGuildReminderRetryMinutes or "0"
        if reminderRetryEditBox:GetText() ~= reminderRetryText then
            reminderRetryEditBox:SetText(reminderRetryText)
        end

        local cooldownText = SmartChatMsg.settings.pendingGuildAutoPopulateCooldownMinutes or "60"
        if cooldownEditBox:GetText() ~= cooldownText then
            cooldownEditBox:SetText(cooldownText)
        end

        ZO_CheckButton_SetCheckState(autoPopulateCheckbox, SmartChatMsg.settings.pendingGuildAutoPopulateOnZone == true)

        local automationEnabled = HasAutomationBehaviorEnabled()
        if not automationEnabled then
            SmartChatMsg.settings.pendingGuildOpenStatusPanelOnRun = false
        end
        ZO_CheckButton_SetCheckState(openStatusPanelCheckbox, automationEnabled and SmartChatMsg.settings.pendingGuildOpenStatusPanelOnRun == true)
        openStatusPanelCheckbox:SetMouseEnabled(automationEnabled)
        openStatusPanelCheckbox:SetAlpha(automationEnabled and 1 or 0.5)

        local repeatEnabled = HasActiveRepeatAfter()
        if not repeatEnabled then
            SmartChatMsg.settings.pendingGuildReminderRetryMinutes = "0"
            if reminderRetryEditBox:GetText() ~= "0" then
                reminderRetryEditBox:SetText("0")
            end
        end

        reminderRetryEditBox:SetMouseEnabled(repeatEnabled)
        if reminderRetryEditBox.SetEditEnabled then
            reminderRetryEditBox:SetEditEnabled(repeatEnabled)
        end
        reminderRetryBackdrop:SetAlpha(repeatEnabled and 1 or 0.5)
        reminderRetryLabel:SetAlpha(repeatEnabled and 1 or 0.5)

        RefreshRunAtDropdown()
        RefreshSoundDropdown()

        local soundIsNone = (SmartChatMsg.settings.pendingGuildPopulateSound or "DUEL_START") == "NONE"
        soundComboBoxControl:SetMouseEnabled(shouldShow)
        previewButton:SetHidden(not shouldShow)
        previewButton:SetEnabled(shouldShow and not soundIsNone)
        previewButton:SetAlpha((shouldShow and not soundIsNone) and 1 or 0.5)
        container:SetHidden(not shouldShow)
    end

    SmartChatMsg.settings.controls.messagesBehaviorReminderEditBox = reminderEditBox
    SmartChatMsg.settings.controls.messagesBehaviorReminderRetryEditBox = reminderRetryEditBox
    SmartChatMsg.settings.controls.messagesBehaviorAutoPopulateCheckbox = autoPopulateCheckbox
    SmartChatMsg.settings.controls.messagesBehaviorRunAtDropdown = runAtComboBoxControl
    SmartChatMsg.settings.controls.messagesBehaviorOpenStatusPanelOnRunCheckbox = openStatusPanelCheckbox
    SmartChatMsg.settings.controls.messagesBehaviorAutoPopulateCooldownEditBox = cooldownEditBox
    SmartChatMsg.settings.controls.messagesBehaviorPopulateSoundDropdown = soundComboBoxControl
    SmartChatMsg.settings.controls.messagesBehaviorPopulateSoundPreviewButton = previewButton
    SmartChatMsg.settings.controls.messagesBehaviorSettings = container

    container:RefreshEditor()
    return container
end

local function BuildMessagesEditor(parent)
    local container = WINDOW_MANAGER:CreateControl("SCM_MessagesEditorContainer", parent, CT_CONTROL)
    container:SetDimensions(ROW_WIDTH, 0)

    local countLabel = WINDOW_MANAGER:CreateControl("SCM_MessagesEditorCountLabel", container, CT_LABEL)
    countLabel:SetFont("ZoFontGame")
    countLabel:SetDimensions(ROW_WIDTH, 24)
    countLabel:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)

    local rowsContainer = WINDOW_MANAGER:CreateControl("SCM_ExistingMessagesRows", container, CT_CONTROL)
    rowsContainer:SetAnchor(TOPLEFT, countLabel, BOTTOMLEFT, 0, 8)
    rowsContainer:SetDimensions(ROW_WIDTH, 0)

    local addLabel = WINDOW_MANAGER:CreateControl("SCM_EnterMessageLabel", container, CT_LABEL)
    addLabel:SetFont("ZoFontWinH4")
    addLabel:SetText("Enter Message")
    addLabel:SetDimensions(LABEL_WIDTH, 30)

    local addBackdrop = WINDOW_MANAGER:CreateControlFromVirtual("SCM_EnterMessageBackdrop", container, "ZO_EditBackdrop")
    addBackdrop:SetDimensions(MESSAGE_BOX_WIDTH, MESSAGE_BOX_HEIGHT)

    local addEditBox = WINDOW_MANAGER:CreateControlFromVirtual("SCM_EnterMessageEditBox", addBackdrop, "ZO_DefaultEditMultiLineForBackdrop")
    addEditBox:SetAnchorFill(addBackdrop)
    addEditBox:SetFont("ZoFontChat")
    addEditBox:SetMaxInputChars(360)
    addEditBox:SetText("")
    addEditBox:SetHandler("OnTextChanged", function(self)
        local text = self:GetText() or ""

        if zo_strlen(text) > 360 then
            text = zo_strsub(text, 1, 360)
            self:SetText(text)
            return
        end

        SmartChatMsg.settings.pendingNewMessageText = text
    end)

    local addButton = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesEditorAddButton", container, "ZO_DefaultButton")
    addButton:SetDimensions(90, 28)
    addButton:SetText("Add")
    addButton:SetHandler("OnClicked", function()
        local trimmed = SmartChatMsg:Trim(SmartChatMsg.settings.pendingNewMessageText or "")
        if trimmed == "" then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, "Message must contain at least one non-space character.")
            return
        end

        local ok, err = SmartChatMsg:AddMessageEntryForSelection(trimmed)
        if not ok then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
            return
        end

        SmartChatMsg.settings.pendingNewMessageText = ""

        if SmartChatMsg.settings.controls.newMessageEditBox then
            SmartChatMsg.settings.controls.newMessageEditBox:SetText("")
        end

        PlaySound(SOUNDS.DEFAULT_CLICK)
        SmartChatMsg:RefreshSettingsUI()
    end)

    local resetButton = WINDOW_MANAGER:CreateControlFromVirtual("SCM_MessagesEditorResetButton", container, "ZO_DefaultButton")
    resetButton:SetDimensions(90, 28)
    resetButton:SetText("Revert")
    resetButton:SetHandler("OnClicked", function()
        SmartChatMsg.settings.pendingNewMessageText = ""

        if SmartChatMsg.settings.controls.newMessageEditBox then
            SmartChatMsg.settings.controls.newMessageEditBox:SetText("")
        end

        PlaySound(SOUNDS.DEFAULT_CLICK)
        SmartChatMsg:RefreshSettingsUI()
    end)

    SmartChatMsg.settings.controls.savedMessageRows = SmartChatMsg.settings.controls.savedMessageRows or {}
    SmartChatMsg.settings.nextSavedMessageRowControlId = SmartChatMsg.settings.nextSavedMessageRowControlId or 1

    local function SetRowTextColor(editBox, isDirty)
        if not editBox then
            return
        end

        if isDirty then
            editBox:SetColor(0.95, 0.78, 0.18, 1)
        else
            editBox:SetColor(1, 1, 1, 1)
        end
    end

    local function ClearSavedMessageRows()
        local rows = SmartChatMsg.settings.controls.savedMessageRows or {}
        for _, row in ipairs(rows) do
            if row then
                row:SetHidden(true)
            end
        end

        SmartChatMsg.settings.controls.savedMessageRows = {}
    end

    local function GetCountText(count)
        if count == 0 then
            return "No Matching Messages"
        elseif count == 1 then
            return "(1) Matching Message Found"
        end

        return string.format("(%d) Matching Messages Found", count)
    end

    local function RefreshRowState(rowData)
        if not rowData or not rowData.entry then
            return
        end

        local currentEntry = rowData.entry
        local currentText = SmartChatMsg.settings:GetEffectiveMessageText(currentEntry)
        local isDirty = SmartChatMsg.settings:IsMessageEntryDirty(currentEntry)

        if rowData.editBox:GetText() ~= currentText then
            rowData.editBox:SetText(currentText)
        end

        SetRowTextColor(rowData.editBox, isDirty)

        if rowData.statusLabel then
            if isDirty then
                rowData.statusLabel:SetText("Pending Update")
                rowData.statusLabel:SetColor(0.95, 0.78, 0.18, 1)
            else
                local schedule=SmartChatMsg:GetGuildRunAt(currentEntry.commandId,currentEntry.guildName)=="SCHEDULED" and SmartChatMsg:GetScheduleEditorDraft()
                rowData.statusLabel:SetText(schedule and SmartChatMsg:GetScheduleMessagePhaseText(currentEntry.id,schedule) or "")
                rowData.statusLabel:SetColor(0.77,0.76,0.62,1)
            end
            if currentEntry.locked==true then rowData.statusLabel:SetText("Locked · "..rowData.statusLabel:GetText()) end
        end

        if rowData.updateButton then
            rowData.updateButton:SetEnabled(isDirty)
        end

        if rowData.revertButton then
            rowData.revertButton:SetHidden(not isDirty)
        end

        if rowData.deleteButton then
            rowData.deleteButton:SetHidden(isDirty)
        end
    end

    local rowCache={}
    local function CreateSavedMessageRow(index, entry, anchorTarget, anchorPoint)
        local cached=rowCache[entry.id]
        if cached and cached.entry==entry then
            local row=cached.row;row:ClearAnchors();row:SetHidden(false)
            if anchorTarget then row:SetAnchor(TOPLEFT,anchorTarget,anchorPoint or BOTTOMLEFT,0,index==1 and 0 or 10)
            else row:SetAnchor(TOPLEFT,rowsContainer,TOPLEFT,0,0) end
            SmartChatMsg.settings.controls.savedMessageRows[#SmartChatMsg.settings.controls.savedMessageRows+1]=row
            RefreshRowState(cached)
            return row
        end
        local controlId = SmartChatMsg.settings.nextSavedMessageRowControlId
        SmartChatMsg.settings.nextSavedMessageRowControlId = controlId + 1

        local row = WINDOW_MANAGER:CreateControl(string.format("SCM_SavedMessageRow%d", controlId), rowsContainer, CT_CONTROL)
        row:SetDimensions(ROW_WIDTH, MESSAGE_BOX_HEIGHT + 44)

        if anchorTarget then
            row:SetAnchor(TOPLEFT, anchorTarget, anchorPoint or BOTTOMLEFT, 0, index == 1 and 0 or 10)
        else
            row:SetAnchor(TOPLEFT, rowsContainer, TOPLEFT, 0, 0)
        end

        local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(string.format("SCM_SavedMessageBackdrop%d", controlId), row, "ZO_EditBackdrop")
        backdrop:SetDimensions(MESSAGE_BOX_WIDTH, MESSAGE_BOX_HEIGHT)
        backdrop:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)

        local editBox = WINDOW_MANAGER:CreateControlFromVirtual(string.format("SCM_SavedMessageEditBox%d", controlId), backdrop, "ZO_DefaultEditMultiLineForBackdrop")
        editBox:SetAnchorFill(backdrop)
        editBox:SetFont("ZoFontChat")
        editBox:SetMaxInputChars(360)

        local statusLabel = WINDOW_MANAGER:CreateControl(string.format("SCM_SavedMessageStatusLabel%d", controlId), row, CT_LABEL)
        statusLabel:SetFont("ZoFontGame")
        statusLabel:SetDimensions(MESSAGE_BOX_WIDTH, 40)
        statusLabel:SetAnchor(TOPLEFT, backdrop, BOTTOMLEFT, 0, 4)

        local updateButton = WINDOW_MANAGER:CreateControlFromVirtual(string.format("SCM_SavedMessageUpdateButton%d", controlId), row, "ZO_DefaultButton")
        updateButton:SetDimensions(70, 28)
        updateButton:SetText("Update")
        updateButton:SetAnchor(TOPLEFT, backdrop, TOPRIGHT, 12, 0)

        local revertButton = WINDOW_MANAGER:CreateControlFromVirtual(string.format("SCM_SavedMessageRevertButton%d", controlId), row, "ZO_DefaultButton")
        revertButton:SetDimensions(70, 28)
        revertButton:SetText("Revert")
        revertButton:SetAnchor(LEFT, updateButton, RIGHT, 6, 0)

        local deleteButton = WINDOW_MANAGER:CreateControlFromVirtual(string.format("SCM_SavedMessageDeleteButton%d", controlId), row, "ZO_DefaultButton")
        deleteButton:SetDimensions(70, 28)
        deleteButton:SetText("Delete")
        deleteButton:SetAnchor(LEFT, updateButton, RIGHT, 6, 0)

        local rowData = {
            control = row,
            entry = entry,
            backdrop = backdrop,
            editBox = editBox,
            statusLabel = statusLabel,
            updateButton = updateButton,
            revertButton = revertButton,
            deleteButton = deleteButton,
        }
        local lockButton=WINDOW_MANAGER:CreateControlFromVirtual(string.format("SCM_SavedMessageLockButton%d",controlId),row,"ZO_DefaultButton")
        lockButton:SetDimensions(70,24)
        lockButton:SetAnchor(TOPLEFT,updateButton,BOTTOMLEFT,0,4)
        lockButton:SetText(entry.locked==true and "Unlock" or "Lock")
        lockButton:SetHandler("OnClicked",function()
            SmartChatMsg:SetMessageLocked(entry.id,entry.locked~=true)
            lockButton:SetText(entry.locked==true and "Unlock" or "Lock")
            RefreshRowState(rowData)
        end)

        editBox:SetHandler("OnTextChanged", function(self)
            local text = self:GetText() or ""

            if zo_strlen(text) > 360 then
                text = zo_strsub(text, 1, 360)
                self:SetText(text)
                return
            end

            SmartChatMsg.settings:SetPendingMessageEdit(entry.id, text, entry.text or "")
            RefreshRowState(rowData)
        end)

        updateButton:SetHandler("OnClicked", function()
            if not SmartChatMsg.settings:IsMessageEntryDirty(entry) then
                return
            end

            local text = SmartChatMsg.settings:GetEffectiveMessageText(entry)
            local trimmed = SmartChatMsg:Trim(text)

            if trimmed == "" then
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, "Message must contain at least one non-space character.")
                return
            end

            local ok, err = SmartChatMsg:UpdateMessageEntry(entry.id, trimmed)
            if not ok then
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
                return
            end

            SmartChatMsg.settings.pendingMessageEdits[entry.id] = nil
            PlaySound(SOUNDS.DEFAULT_CLICK)
            SmartChatMsg:RefreshSettingsUI()
        end)

        revertButton:SetHandler("OnClicked", function()
            SmartChatMsg.settings.pendingMessageEdits[entry.id] = nil
            rowData.editBox:SetText(entry.text or "")
            RefreshRowState(rowData)
            PlaySound(SOUNDS.DEFAULT_CLICK)
        end)

        deleteButton:SetHandler("OnClicked", function()
            ZO_Dialogs_ShowDialog(DELETE_MESSAGE_DIALOG_NAME, {
                callback = function()
                    local ok, err = SmartChatMsg:DeleteMessageEntry(entry.id)
                    if not ok then
                        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
                        return
                    end

                    SmartChatMsg.settings.pendingMessageEdits[entry.id] = nil
                    PlaySound(SOUNDS.DEFAULT_CLICK)
                    SmartChatMsg:RefreshSettingsUI()
                end,
            })
        end)

        rowData.row=row;rowCache[entry.id]=rowData
        SmartChatMsg.settings.controls.savedMessageRows[#SmartChatMsg.settings.controls.savedMessageRows + 1] = row
        RefreshRowState(rowData)

        return row
    end

    local function RefreshEditor()
        local hasCompleteSelection = SmartChatMsg:IsMessagesSelectionComplete()
        local selectedChannel = SmartChatMsg:GetSelectedMessagesChannel()
        local hasChannel = selectedChannel ~= "Select a Chat Channel"
        local entries = SmartChatMsg:GetMessageEntriesForSelection()
        if hasCompleteSelection and SmartChatMsg:GetGuildRunAt(SmartChatMsg.savedVars.selectedMessagesCommand,SmartChatMsg:GetSelectedGuildNameForMessages())=="SCHEDULED" then
            entries=SmartChatMsg:SortScheduledMessageEntries(entries,SmartChatMsg:GetScheduleEditorDraft())
        end
        local shouldShow = hasCompleteSelection and hasChannel

        if addEditBox:GetText() ~= (SmartChatMsg.settings.pendingNewMessageText or "") then
            addEditBox:SetText(SmartChatMsg.settings.pendingNewMessageText or "")
        end

        countLabel:SetText(GetCountText(#entries))

        ClearSavedMessageRows()

        if not shouldShow then
            countLabel:SetHidden(true)
            rowsContainer:SetHidden(true)
            addLabel:SetHidden(true)
            addBackdrop:SetHidden(true)
            addButton:SetHidden(true)
            resetButton:SetHidden(true)
            container:SetHidden(true)
            rowsContainer:SetHeight(0)
            container:SetHeight(0)
            return
        end

        container:SetHidden(false)
        countLabel:SetHidden(false)
        rowsContainer:SetHidden(false)
        addLabel:SetHidden(false)
        addBackdrop:SetHidden(false)
        addButton:SetHidden(false)
        resetButton:SetHidden(false)

        local lastRow = nil
        local rowsHeight = 0

        for index, entry in ipairs(entries) do
            local row = CreateSavedMessageRow(index, entry, lastRow, BOTTOMLEFT)
            lastRow = row
            rowsHeight = rowsHeight + MESSAGE_BOX_HEIGHT + 44
            if index > 1 then
                rowsHeight = rowsHeight + 10
            end
        end

        rowsContainer:SetHeight(rowsHeight)

        if lastRow then
            addLabel:SetAnchor(TOPLEFT, lastRow, BOTTOMLEFT, 0, 14)
        else
            addLabel:SetAnchor(TOPLEFT, rowsContainer, TOPLEFT, 0, 0)
        end

        addBackdrop:SetAnchor(TOPLEFT, addLabel, BOTTOMLEFT, 0, 4)
        addButton:SetAnchor(TOPLEFT, addBackdrop, TOPRIGHT, 12, 0)
        resetButton:SetAnchor(LEFT, addButton, RIGHT, 8, 0)

        local totalHeight = 24
        if rowsHeight > 0 then
            totalHeight = totalHeight + 8 + rowsHeight + 14
        else
            totalHeight = totalHeight + 8
        end

        totalHeight = totalHeight + 30 + 4 + MESSAGE_BOX_HEIGHT
        container:SetHeight(totalHeight)
    end

    container.RefreshEditor = RefreshEditor

    SmartChatMsg.settings.controls.newMessageEditBox = addEditBox
    SmartChatMsg.settings.controls.messagesEditor = container

    container:RefreshEditor()
    return container
end

local function BuildImportExportEditor(parent)
    local container = WINDOW_MANAGER:CreateControl("SCM_ImportExportContainer", parent, CT_CONTROL)
    container:SetDimensions(ROW_WIDTH, 220)

    local description = WINDOW_MANAGER:CreateControl("SCM_ImportExportDescription", container, CT_LABEL)
    description:SetFont("ZoFontGame")
    description:ClearAnchors()
    description:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
    description:SetAnchor(TOPRIGHT, container, TOPRIGHT, -130, 0)
    description:SetHeight(44)
    description:SetText("Export omits locked messages; import keeps them if their command remains.")

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual("SCM_ImportExportBackdrop", container, "ZO_EditBackdrop")
    backdrop:ClearAnchors()
    backdrop:SetAnchor(TOPLEFT, description, BOTTOMLEFT, 0, 8)
    backdrop:SetAnchor(TOPRIGHT, description, BOTTOMRIGHT, 0, 8)
    backdrop:SetHeight(120)
    
    local editBox = WINDOW_MANAGER:CreateControlFromVirtual("SCM_ImportExportEditBox", backdrop, "ZO_DefaultEditMultiLineForBackdrop")
    editBox:SetAnchorFill(backdrop)
    editBox:SetFont("ZoFontChat")
    editBox:SetMaxInputChars(20000)
    editBox:SetText("")
    editBox:SetHandler("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if zo_strlen(text) > 300000 then
            text = zo_strsub(text, 1, 300000)
            self:SetText(text)
            return
        end

        SmartChatMsg.settings.pendingImportExportText = text
    end)

    local exportButton = WINDOW_MANAGER:CreateControlFromVirtual("SCM_ExportSettingsButton", container, "ZO_DefaultButton")
    exportButton:SetDimensions(90, 28)
    exportButton:SetText("Export")
    exportButton:SetAnchor(TOPLEFT, backdrop, BOTTOMLEFT, 110, 10)
    exportButton:SetHandler("OnClicked", function()
        SmartChatMsg.settings:ExportSettings()
    end)

    local importButton = WINDOW_MANAGER:CreateControlFromVirtual("SCM_ImportSettingsButton", container, "ZO_DefaultButton")
    importButton:SetDimensions(90, 28)
    importButton:SetText("Import")
    importButton:SetAnchor(LEFT, exportButton, RIGHT, 8, 0)
    importButton:SetHandler("OnClicked", function()
        SmartChatMsg.settings:ImportSettings()
    end)

    local clearButton = WINDOW_MANAGER:CreateControlFromVirtual("SCM_ClearImportExportButton", container, "ZO_DefaultButton")
    clearButton:SetDimensions(90, 28)
    clearButton:SetText("Clear")
    clearButton:SetAnchor(LEFT, importButton, RIGHT, 8, 0)
    clearButton:SetHandler("OnClicked", function()
        SmartChatMsg.settings:ClearImportExportText()
    end)

    container.RefreshEditor = function()
        if SmartChatMsg.settings.controls.importExportEditBox and SmartChatMsg.settings.controls.importExportEditBox:GetText() ~= (SmartChatMsg.settings.pendingImportExportText or "") then
            SmartChatMsg.settings.controls.importExportEditBox:SetText(SmartChatMsg.settings.pendingImportExportText or "")
        end
    end

    SmartChatMsg.settings.controls.importExportEditBox = editBox
    SmartChatMsg.settings.controls.importExportEditor = container

    container:RefreshEditor()
    return container
end

function SmartChatMsg:RefreshSettingsUI()
    local scrollContainer=self.settings.panel and self.settings.panel.container
    local scrollSnapshot=self:CaptureMessageListScroll(scrollContainer)
    if self.settings.controls.commandDropdown and self.settings.controls.commandDropdown.RefreshDropdown then
        self.settings.controls.commandDropdown:RefreshDropdown()
    end

    if self.settings.controls.commandEditor and self.settings.controls.commandEditor.RefreshEditor then
        self.settings.controls.commandEditor:RefreshEditor()
    end

    if self.settings.controls.defaultGuildDropdown and self.settings.controls.defaultGuildDropdown.RefreshDropdown then
        self.settings.controls.defaultGuildDropdown:RefreshDropdown()
    end

    if self.settings.controls.messagesCommandDropdown and self.settings.controls.messagesCommandDropdown.RefreshDropdown then
        self.settings.controls.messagesCommandDropdown:RefreshDropdown()
    end

    if self.settings.controls.messagesGuildDropdown and self.settings.controls.messagesGuildDropdown.RefreshDropdown then
        self.settings.controls.messagesGuildDropdown:RefreshDropdown()
    end

    if self.settings.controls.messagesChannelDropdown and self.settings.controls.messagesChannelDropdown.RefreshDropdown then
        self.settings.controls.messagesChannelDropdown:RefreshDropdown()
    end

    if self.settings.controls.messagesBehaviorSettings and self.settings.controls.messagesBehaviorSettings.RefreshEditor then
        self.settings.controls.messagesBehaviorSettings:RefreshEditor()
    end

    if self.settings.controls.messagesEditor and self.settings.controls.messagesEditor.RefreshEditor then
        self.settings.controls.messagesEditor:RefreshEditor()
    end

    if self.settings.controls.importExportEditor and self.settings.controls.importExportEditor.RefreshEditor then
        self.settings.controls.importExportEditor:RefreshEditor()
    end

    if self.settings.panel then
        CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", self.settings.panel)
    end
    self:RestoreMessageListScroll(scrollContainer,scrollSnapshot)
end

local function BuildGeneralRevertSettings(parent)
    local container = WINDOW_MANAGER:CreateControl("SCM_GeneralRevertSettingsContainer", parent, CT_CONTROL)
    container:SetDimensions(ROW_WIDTH, 40)

    local label = WINDOW_MANAGER:CreateControl("SCM_GeneralRevertSettingsLabel", container, CT_LABEL)
    label:SetFont("ZoFontWinH4")
    label:SetText("Auto-Remove Pending Chat After (secs)")
    label:SetDimensions(320, 30)
    label:SetAnchor(LEFT, container, LEFT, 0, 0)

    label:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, TOP, 0, 8)
        SetTooltipText(InformationTooltip, "Time to wait before clearing chat and returning to previous chat type. Minimum valid value is 30 seconds.")
    end)

    label:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual("SCM_GeneralRevertSettingsBackdrop", container, "ZO_EditBackdrop")
    backdrop:SetDimensions(70, 30)
    backdrop:SetAnchor(LEFT, label, RIGHT, 8, 0)

    local editBox = WINDOW_MANAGER:CreateControlFromVirtual("SCM_GeneralRevertSettingsEditBox", backdrop, "ZO_DefaultEditForBackdrop")
    editBox:SetAnchorFill(backdrop)
    editBox:SetMaxInputChars(4)
    editBox:SetText("")

    editBox:SetHandler("OnTextChanged", function(self)
        local text = self:GetText() or ""
        local digitsOnly = text:gsub("[^%d]", "")

        if digitsOnly ~= text then
            self:SetText(digitsOnly)
            return
        end

        SmartChatMsg.settings.pendingGeneralRevertChatSeconds = digitsOnly

        local ok, err = SmartChatMsg.settings:SaveGeneralSettings()
        if not ok and err then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, err)
            return
        end

        SmartChatMsg:RefreshSettingsUI()
    end)

    container.RefreshEditor = function()
        local revertText = SmartChatMsg.settings.pendingGeneralRevertChatSeconds or "60"
        if editBox:GetText() ~= revertText then
            editBox:SetText(revertText)
        end
    end

    SmartChatMsg.settings.controls.generalRevertSettings = container
    SmartChatMsg.settings.controls.generalRevertSettingsEditBox = editBox

    container:RefreshEditor()
    return container
end

function SmartChatMsg:CreateSettingsPanel()
    self.settings:InitializeState()
    RegisterDeleteDialogs()

    local panelData = {
        type = "panel",
        name = "SmartChatMsg",
        displayName = "SmartChatMsg",
        author = "evainefaye",
        version = "1.10.0",
        registerForRefresh = true,
        registerForDefaults = false,
    }

    self.settings.panel = LAM2:RegisterAddonPanel("SmartChatMsgOptionsPanel", panelData)

    local commandDropdownHolder
    local commandEditorHolder
    local defaultGuildDropdownHolder
    local generalRevertSettingsHolder
    local messagesCommandDropdownHolder
    local messagesGuildDropdownHolder
    local messagesChannelDropdownHolder
    local messagesBehaviorSettingsHolder
    local messagesEditorHolder
    local importExportHolder

    local optionsTable = {
        {
            type = "description",
            text = "Allows you to create custom command(s) that can be filtered by guild and used to output one of several random messages to the appropriate chat type.",
            width = "full",
        },
        {
            type = "submenu",
            name = "Global Settings",
            controls = {
                {
                    type="dropdown",name="Scheduling timezone",choices={"Eastern (ET)","Central (CT)","Mountain (MT)","Pacific (PT)"},
                    tooltip="US daylight-saving rules are applied automatically. Guilds with an explicit timezone keep their choice. Changing this moves schedules for guilds using the global default to the same clock time in the new zone (8 PM Eastern becomes 8 PM Pacific). Explicit timezone text in messages is unchanged.",
                    getFunc=function() local code=SmartChatMsg:GetSchedulingTimeZone();return SmartChatMsg:GetSchedulingTimeZoneName(code).." ("..code..")" end,
                    setFunc=function(value)
                        local code=value:match("%((%u%u)%)")
                        local ok,reason=SmartChatMsg:SetSchedulingTimeZone(code)
                        if not ok then ZO_Alert(UI_ALERT_CATEGORY_ERROR,SOUNDS.NEGATIVE_CLICK,reason) end
                    end,
                },
                {
                    type = "custom",
                    reference = "SCM_DefaultGuildDropdownHolder",
                    createFunc = function(control)
                        control:SetHeight(40)
                        defaultGuildDropdownHolder = BuildDefaultGuildDropdown(control)
                        defaultGuildDropdownHolder:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
                    end,
                    refreshFunc = function(control)
                        if defaultGuildDropdownHolder and defaultGuildDropdownHolder.RefreshDropdown then
                            defaultGuildDropdownHolder:RefreshDropdown()
                        end

                        control:SetHeight(SmartChatMsg:HasAnyGuilds() and 40 or 0)
                    end,
                },
                {
                    type = "custom",
                    reference = "SCM_GeneralRevertSettingsHolder",
                    createFunc = function(control)
                        control:SetHeight(40)
                        generalRevertSettingsHolder = BuildGeneralRevertSettings(control)
                        generalRevertSettingsHolder:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
                    end,
                    refreshFunc = function()
                        if generalRevertSettingsHolder and generalRevertSettingsHolder.RefreshEditor then
                            generalRevertSettingsHolder:RefreshEditor()
                        end
                    end,
                },
            },
        },
        {
            type = "submenu",
            name = "Create / Edit / Delete Commands",
            controls = {
                {
                    type = "description",
                    text = "Select a command to edit, or delete it, or create a new command. You must have at least one command defined before you can create associated messages.",
                    width = "full",
                },
                {
                    type = "custom",
                    reference = "SCM_CommandDropdownHolder",
                    createFunc = function(control)
                        control:SetHeight(40)
                        commandDropdownHolder = BuildCommandDropdown(control)
                        commandDropdownHolder:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
                    end,
                    refreshFunc = function()
                        if commandDropdownHolder and commandDropdownHolder.RefreshDropdown then
                            commandDropdownHolder:RefreshDropdown()
                        end
                    end,
                },
                {
                    type = "custom",
                    reference = "SCM_CommandEditorHolder",
                    createFunc = function(control)
                        control:SetHeight(96)
                        commandEditorHolder = BuildCommandEditor(control)
                        commandEditorHolder:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
                    end,
                    refreshFunc = function(control)
                        if commandEditorHolder and commandEditorHolder.RefreshEditor then
                            commandEditorHolder:RefreshEditor()
                        end

                        if SmartChatMsg.settings:IsEditorVisible() then
                            control:SetHeight(96)
                        else
                            control:SetHeight(0)
                        end
                    end,
                },
            },
        },
        {
            type = "submenu",
            name = "Create / Edit / Delete Messages",
            disabled = function()
                return not SmartChatMsg:CanUseMessagesSection()
            end,
            controls = {
                {
                    type = "description",
                    text = "Select a Command and a Guild for which you would like this message to apply.",
                    width = "full",
                },
                {
                    type = "custom",
                    reference = "SCM_MessagesCommandDropdownHolder",
                    createFunc = function(control)
                        control:SetHeight(40)
                        messagesCommandDropdownHolder = BuildMessagesCommandDropdown(control)
                        messagesCommandDropdownHolder:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
                    end,
                    refreshFunc = function(control)
                        if messagesCommandDropdownHolder and messagesCommandDropdownHolder.RefreshDropdown then
                            messagesCommandDropdownHolder:RefreshDropdown()
                        end

                        control:SetHeight(SmartChatMsg:CanUseMessagesSection() and 40 or 0)
                    end,
                },
                {
                    type = "custom",
                    reference = "SCM_MessagesGuildDropdownHolder",
                    createFunc = function(control)
                        control:SetHeight(40)
                        messagesGuildDropdownHolder = BuildMessagesGuildDropdown(control)
                        messagesGuildDropdownHolder:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
                    end,
                    refreshFunc = function(control)
                        if messagesGuildDropdownHolder and messagesGuildDropdownHolder.RefreshDropdown then
                            messagesGuildDropdownHolder:RefreshDropdown()
                        end

                        control:SetHeight(SmartChatMsg:CanUseMessagesSection() and 40 or 0)
                    end,
                },
                {
                    type = "custom",
                    reference = "SCM_MessagesChannelDropdownHolder",
                    createFunc = function(control)
                        control:SetHeight(40)
                        messagesChannelDropdownHolder = BuildMessagesChannelDropdown(control)
                        messagesChannelDropdownHolder:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
                    end,
                    refreshFunc = function(control)
                        if messagesChannelDropdownHolder and messagesChannelDropdownHolder.RefreshDropdown then
                            messagesChannelDropdownHolder:RefreshDropdown()
                        end

                        control:SetHeight(SmartChatMsg:IsMessagesSelectionComplete() and 40 or 0)
                    end,
                },
                {
                    type = "custom",
                    reference = "SCM_MessagesBehaviorSettingsHolder",
                    minHeight = 0, maxHeight = 235,
                    createFunc = function(control)
                        control:SetHeight(235)
                        messagesBehaviorSettingsHolder = BuildMessagesBehaviorSettings(control)
                        messagesBehaviorSettingsHolder:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
                    end,
                    refreshFunc = function(control)
                        if messagesBehaviorSettingsHolder and messagesBehaviorSettingsHolder.RefreshEditor then
                            messagesBehaviorSettingsHolder:RefreshEditor()
                        end

                        control:SetHeight(SmartChatMsg:IsMessagesSelectionComplete() and 235 or 0)
                    end,
                },
                {
                    type = "custom",
                    reference = "SCM_MessagesEditorHolder",
                    minHeight = 0, maxHeight = 20000,
                    createFunc = function(control)
                        control:SetResizeToFitDescendents(false)
                        control:SetHeight(0)
                        messagesEditorHolder = BuildMessagesEditor(control)
                        messagesEditorHolder:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 30)
                    end,
                    refreshFunc = function(control)
                        if messagesEditorHolder and messagesEditorHolder.RefreshEditor then
                            messagesEditorHolder:RefreshEditor()

                            local hasChannel = SmartChatMsg:GetSelectedMessagesChannel() ~= "Select a Chat Channel"
                            local shouldShow = SmartChatMsg:IsMessagesSelectionComplete() and hasChannel

                            -- The editor is anchored 30px below this holder.
                            -- Reserve that inset and a gap for the following submenu.
                            control:SetHeight(shouldShow and (30 + messagesEditorHolder:GetHeight() + 30) or 0)
                        else
                            control:SetHeight(0)
                        end
                    end,
                },
            },
        },
        {
            type = "submenu",
            name = "Import / Export Settings",
            controls = {
                {
                    type = "custom",
                    reference = "SCM_ImportExportHolder",
                    createFunc = function(control)
                        control:SetHeight(220)
                        importExportHolder = BuildImportExportEditor(control)
                        importExportHolder:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
                    end,
                    refreshFunc = function(control)
                        if importExportHolder and importExportHolder.RefreshEditor then
                            importExportHolder:RefreshEditor()
                        end

                        control:SetHeight(220)
                    end,
                },
            },
        },
    }

    for _,section in ipairs(optionsTable) do
        if section.name=="Create / Edit / Delete Messages" then
            table.insert(section.controls, {
                type="submenu", name=function() return "Scheduling ("..SmartChatMsg:GetSchedulingTimeZoneName(SmartChatMsg:GetGuildSchedulingTimeZone(SmartChatMsg:GetSelectedGuildNameForMessages())).." Time)" end,
                tooltip="Select Scheduled in Run At above to configure automatic reminders.",
                disabled=function()
                    local id=SmartChatMsg.savedVars.selectedMessagesCommand
                    local guild=SmartChatMsg:GetSelectedGuildNameForMessages()
                    return not SmartChatMsg:IsMessagesSelectionComplete() or SmartChatMsg:GetGuildRunAt(id,guild)~="SCHEDULED"
                end,
                controls=self:BuildScheduleOptionControls(),
            })
            break
        end
    end
    LAM2:RegisterOptionControls("SmartChatMsgOptionsPanel", optionsTable)
end

function SmartChatMsg:OpenSettings()
    if self.settings and self.settings.panel then
        self.settings:InitializeState()
        LAM2:OpenToPanel(self.settings.panel)
        self:RefreshSettingsUI()
    end
end
