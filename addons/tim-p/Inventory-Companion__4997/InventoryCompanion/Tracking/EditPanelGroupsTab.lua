local this = InventoryCompanion

local groupRows = {}
local patternRows = {}
local selectedGroupName = nil
local SetActionButtons

------------------------------------------------------------------
-- Constants
------------------------------------------------------------------
local constants = {
    newGroupBaseName = "New Group",
	quirkyNameList = {"%s","Another %s", "Yet another %s", "Now you are starting to annoy me"}
}

------------------------------------------------------------------
-- Sanitization & Commit Logic
------------------------------------------------------------------
local function SanitizeGroupName(name)
    -- Trim whitespace
    name = name:match("^%s*(.-)%s*$")
    -- Strip control characters (\0-\31, \127)
    name = name:gsub("[%z\1-\31\127]", "")
    -- Escape pipes (| to ||) to prevent ESO formatting injection
    name = name:gsub("|", "||")
    return name
end

local function GetSortedGroupNames()
    local activeRules = this.GetActiveTrackedRules(true)
    local groupNames = {}
    for name in pairs(activeRules) do
        table.insert(groupNames, name)
    end
	
	table.sort(groupNames, function(a, b)
        local nameA = activeRules[a].displayName
        local nameB = activeRules[b].displayName
        return nameA:lower() < nameB:lower()
    end)
    
    return groupNames, activeRules
end

------------------------------------------------------------------
-- Populate Group List Pane
------------------------------------------------------------------
local function HideAllGroupRows()
    for _, row in ipairs(groupRows) do
        row:SetHidden(true)
    end
end

local function GetOrCreateGroupRow(scrollChild, index)
    local row = groupRows[index]
    if not row then
        row = CreateControlFromVirtual("InventoryCompanion_GroupRow_", scrollChild, "InventoryCompanion_GroupRow_Template", index)
        table.insert(groupRows, row)
    end
    return row
end

local function PopulateGroupRow(row, groupName, index, scrollChild, activeRules)
    local rowHeight = 32
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, 0, (index - 1) * rowHeight)
    row:SetHidden(false)

    local isSelected = (groupName == selectedGroupName)
    local nameLabel = GetControl(row, "Name")

    local ruleData = activeRules[groupName]
    local displayName = ruleData.displayName

    -- Apply hidden styling (Red text with "(hidden)" suffix)
    if ruleData.display.isHidden == true then
        displayName = string.format("|cFF5252%s (hidden)|r", displayName)
    end

    nameLabel:SetText(displayName)

    -- Styling based on selection state
    if isSelected then
        nameLabel:SetFont("ZoFontGameBold")
        nameLabel:SetColor(0.95, 0.95, 0.95, 1.0)
    else
        nameLabel:SetFont("ZoFontGame")
        nameLabel:SetColor(0.60, 0.60, 0.60, 1.0)
    end

    local bgTex = GetControl(row, "BG")
    bgTex:SetAlpha(isSelected and 0.4 or 0.0)

    -- Mouse handlers for hover and click effects
    row:SetHandler("OnMouseEnter", function()
        if not isSelected then
            nameLabel:SetColor(0.85, 0.85, 0.85, 1.0)
            bgTex:SetAlpha(0.2)
        end
    end)

    row:SetHandler("OnMouseExit", function()
        if not isSelected then
            nameLabel:SetColor(0.60, 0.60, 0.60, 1.0)
            bgTex:SetAlpha(0.0)
        end
    end)

    row:SetHandler("OnMouseDown", function()
        selectedGroupName = groupName
        this.RefreshGroupsEditor()
    end)
end

local function PopulateGroupListPane(groupNames, activeRules)
    HideAllGroupRows()

    local scrollChild = GetControl(InventoryCompanion_GroupsWindowLeftPane, "ScrollChild")
    assert(scrollChild, "Groups editor is missing its group-list ScrollChild")

    if not selectedGroupName or not activeRules[selectedGroupName] then
        selectedGroupName = groupNames[1]
    end

    for index, groupName in ipairs(groupNames) do
        local row = GetOrCreateGroupRow(scrollChild, index)
        PopulateGroupRow(row, groupName, index, scrollChild, activeRules)
    end
end

------------------------------------------------------------------
-- Group Name Editing
------------------------------------------------------------------
local function GetQuirkyDefaultNames()
    local base = constants.newGroupBaseName
    local names = {}
    for _, pattern in ipairs(constants.quirkyNameList) do
        if pattern:find("%%s") then
            table.insert(names, string.format(pattern, base))
        else
            table.insert(names, pattern)
        end
    end
    return names
end

local function DoesGroupNameExist(targetName, excludeKey)
    local activeRules = this.GetActiveTrackedRules(true)
    for key, rule in pairs(activeRules) do
        if key ~= excludeKey and rule.displayName:lower() == targetName:lower() then
            return true
        end
    end
    return false
end

local function GenerateUniqueGroupName(baseName, excludeKey)
    baseName = baseName or constants.newGroupBaseName

    if baseName ~= constants.newGroupBaseName and baseName ~= "" then
        if not DoesGroupNameExist(baseName, excludeKey) then
            return baseName
        end
        
        local counter = 2
        while true do
            local candidate = string.format("%s %d", baseName, counter)
            if not DoesGroupNameExist(candidate, excludeKey) then
                return candidate
            end
            counter = counter + 1
        end
    end

    local quirkyNames = GetQuirkyDefaultNames()
    for _, name in ipairs(quirkyNames) do
        if not DoesGroupNameExist(name, excludeKey) then
            return name
        end
    end

    local counter = 5
    while true do
        local candidate = string.format("%s %d", constants.newGroupBaseName, counter)
        if not DoesGroupNameExist(candidate, excludeKey) then
            return candidate
        end
        counter = counter + 1
    end
end

local function CommitGroupNameEdit(editBox, titleLabel, pencilBtn)
    local rawText = editBox:GetText()
    local sanitized = SanitizeGroupName(rawText)

    if sanitized == "" then
        this.Utils.UserWarning("Group name cannot be empty. Changes reverted.")
        editBox:SetHidden(true)
        titleLabel:SetHidden(false)
        pencilBtn:SetHidden(false)
        this.RefreshGroupsEditor()
        return
    end

    local finalName = GenerateUniqueGroupName(sanitized, selectedGroupName)

    if finalName ~= sanitized then
        this.Utils.UserMessage(string.format("Group name already exists. Automatically renamed to '%s'.", finalName))
    end

    this.UpdateRuleProperty(selectedGroupName, "displayName", finalName)

    editBox:SetHidden(true)
    titleLabel:SetHidden(false)
    pencilBtn:SetHidden(false)
    this.RefreshGroupsEditor()
    this.RefreshItemTrackerPanel()
end

local function HandlePencilClick(titleLabel, pencilBtn, editBox, activeRules)
    local ruleData = activeRules[selectedGroupName]
    local displayName = ruleData.displayName

    editBox:SetText(displayName)
    titleLabel:SetHidden(true)
    pencilBtn:SetHidden(true)
    editBox:SetHidden(false)
    editBox:TakeFocus()
end

------------------------------------------------------------------
-- PopulateSingleGroupPane (Pattern Helpers & Handlers)
------------------------------------------------------------------
local function HideAllPatternRows()
    for _, row in ipairs(patternRows) do
        row:SetHidden(true)
    end
end

local function GetOrCreatePatternRow(scrollChild, index)
    local row = patternRows[index]
    if not row then
        row = CreateControlFromVirtual("InventoryCompanion_PatternEditRow_", scrollChild, "InventoryCompanion_PatternEditRow_Template", index)
        table.insert(patternRows, row)
    end
    return row
end

local function SaveRulePatterns(groupName, patterns)
    this.UpdateRulePatterns(groupName, patterns)
end

local function HandlePatternTextChanged(self, patterns, index)
    patterns[index] = self:GetText()
end

local function HandlePatternFocusLost(self, patterns, index, targetGroup)
    patterns[index] = self:GetText()
    
    if targetGroup == selectedGroupName then
        SaveRulePatterns(targetGroup, patterns)
        this.RefreshItemTrackerPanel()
        SetActionButtons(this.GetActiveTrackedRules(true))
    end
end

local function HandlePatternDelete(patterns, index)
    table.remove(patterns, index)
    SaveRulePatterns(selectedGroupName, patterns)
    this.RefreshGroupsEditor()
    this.RefreshItemTrackerPanel()
end

local function HandleAddRule(patterns)
    table.insert(patterns, "")
    SaveRulePatterns(selectedGroupName, patterns)
    this.RefreshGroupsEditor()
end

local function ConfigureCustomGroupActionBar(btnReset, btnHide, btnDelete, actionBar, groupId, activeRules, isHidden)
    btnReset:SetHidden(true)
    
    -- Show and position the Hide/Unhide button on the far left
    btnHide:SetHidden(false)
    btnHide:ClearAnchors()
    btnHide:SetAnchor(TOPLEFT, actionBar, TOPLEFT, 0, 0)
    
    if isHidden then
        btnHide:SetText("Unhide Group")
        btnHide:SetHandler("OnClicked", function()
            this.SetRuleFlag(groupId, "isHidden", false)
            this.RefreshGroupsEditor()
            this.RefreshItemTrackerPanel()
        end)
    else
        btnHide:SetText("Hide Group")
        btnHide:SetHandler("OnClicked", function()
            this.SetRuleFlag(groupId, "isHidden", true)
            this.RefreshGroupsEditor()
            this.RefreshItemTrackerPanel()
        end)
    end

    -- Show and position the Delete button to the right of the Hide button
    btnDelete:SetHidden(false)
    btnDelete:ClearAnchors()
    btnDelete:SetAnchor(TOPLEFT, btnHide, TOPRIGHT, 10, 0)
    btnDelete:SetHandler("OnClicked", function()
        local ruleData = activeRules[groupId]
        local displayName = ruleData.displayName

        ZO_Dialogs_ShowDialog("InventoryCompanion_CONFIRM_DELETE_GROUP_DIALOG", {
            groupId = groupId,
            groupName = displayName,
        })
    end)
end

local function ConfigurePreloadedHideButton(btnHide, groupId, isHidden)
    btnHide:SetHidden(false)
    if isHidden then
        btnHide:SetText("Unhide Group")
        btnHide:SetHandler("OnClicked", function()
            this.SetRuleFlag(groupId, "isHidden", false)
            this.RefreshGroupsEditor()
            this.RefreshItemTrackerPanel()
        end)
    else
        btnHide:SetText("Hide Group")
        btnHide:SetHandler("OnClicked", function()
            this.SetRuleFlag(groupId, "isHidden", true)
            this.RefreshGroupsEditor()
            this.RefreshItemTrackerPanel()
        end)
    end
end

local function ConfigurePreloadedResetButton(btnReset, btnHide, actionBar, hasOverride, groupId, activeRules)
    if hasOverride then
        btnReset:SetHidden(false)
        btnReset:ClearAnchors()
        btnReset:SetAnchor(TOPLEFT, actionBar, TOPLEFT, 0, 0)

        btnHide:ClearAnchors()
        btnHide:SetAnchor(TOPLEFT, btnReset, TOPRIGHT, 10, 0)

        btnReset:SetHandler("OnClicked", function()
            local ruleData = activeRules[groupId]
            local displayName = ruleData.displayName

            ZO_Dialogs_ShowDialog("InventoryCompanion_CONFIRM_RESET_GROUP_DIALOG", {
                groupId = groupId,
                groupName = displayName,
            })
        end)
    else
        btnReset:SetHidden(true)
        btnHide:ClearAnchors()
        btnHide:SetAnchor(TOPLEFT, actionBar, TOPLEFT, 0, 0)
    end
end

SetActionButtons = function(activeRules)
    local rightPane = InventoryCompanion_GroupsWindowRightPane
    local actionBar = GetControl(rightPane, "ActionBar")
    local btnReset = GetControl(actionBar, "BtnReset")
    local btnHide = GetControl(actionBar, "BtnHide")
    local btnDelete = GetControl(actionBar, "BtnDelete")

    local groupId = selectedGroupName
    
    -- Miscellaneous can never be hidden or deleted.
    if groupId == "miscellaneous" then
        btnHide:SetHidden(true)
        btnDelete:SetHidden(true)
        
        local hasOverride = this.HasResettableRuleOverrides(groupId)
        if hasOverride then
            btnReset:SetHidden(false)
            btnReset:ClearAnchors()
            btnReset:SetAnchor(TOPLEFT, actionBar, TOPLEFT, 0, 0)
            btnReset:SetHandler("OnClicked", function()
                local ruleData = activeRules[groupId]
                local displayName = ruleData.displayName

                ZO_Dialogs_ShowDialog("InventoryCompanion_CONFIRM_RESET_GROUP_DIALOG", {
                    groupId = groupId,
                    groupName = displayName,
                })
            end)
        else
            btnReset:SetHidden(true)
        end
        return
    end

    local basePreloaded = this.preLoadedRulesets[groupId]
    local hasOverride = this.HasResettableRuleOverrides(groupId)

    local ruleData = activeRules[groupId]
    local isHidden = ruleData.display.isHidden == true

    if not basePreloaded then
		ConfigureCustomGroupActionBar(btnReset, btnHide, btnDelete, actionBar, groupId, activeRules, isHidden)
    else
        btnDelete:SetHidden(true)
        ConfigurePreloadedHideButton(btnHide, groupId, isHidden)
        ConfigurePreloadedResetButton(btnReset, btnHide, actionBar, hasOverride, groupId, activeRules)
    end	
end

local function PopulateSingleGroupPane(activeRules)
    if not selectedGroupName then return end

    local rightPane = InventoryCompanion_GroupsWindowRightPane
    local titleLabel = GetControl(rightPane, "GroupTitleLabel")
    local editBox = GetControl(rightPane, "GroupEditBox")
    local pencilBtn = GetControl(rightPane, "BtnEditGroupName")
    local descLabel = GetControl(rightPane, "DescriptionLabel")
    local patternScrollContainer = GetControl(rightPane, "PatternScrollContainer")
    local btnAddRule = GetControl(rightPane, "BtnAddRule")

    editBox:SetHidden(true)
    titleLabel:SetHidden(false)
    pencilBtn:SetHidden(false)

    local ruleData = activeRules[selectedGroupName]
    local displayName = ruleData.displayName

    if selectedGroupName == "miscellaneous" then
        titleLabel:SetText(string.format("Group Name: %s (Special Group)", displayName))

        patternScrollContainer:SetHidden(true)
        btnAddRule:SetHidden(true)
        HideAllPatternRows()

        descLabel:SetText("This is a special catch-all group which collects items not matched by any other active group. It does not use custom pattern rules, but you can customize its display name above.")
        descLabel:SetHidden(false)
    else
        descLabel:SetHidden(true)
        patternScrollContainer:SetHidden(false)
        btnAddRule:SetHidden(false)

        local patterns = {}
        for _, p in ipairs(ruleData.patterns) do
            table.insert(patterns, p)
        end

        titleLabel:SetText(string.format("Group Name: %s (%d patterns/rules)", displayName, #patterns))

        HideAllPatternRows()
        local patternScrollChild = GetControl(patternScrollContainer, "ScrollChild")
        local rowHeight = 36
        for i, patternText in ipairs(patterns) do
            local row = GetOrCreatePatternRow(patternScrollChild, i)
            row:ClearAnchors()
            row:SetAnchor(TOPLEFT, patternScrollChild, TOPLEFT, 0, (i - 1) * rowHeight)
            row:SetHidden(false)

            local rowEditBox = GetControl(row, "Edit")
            rowEditBox:SetHandler("OnTextChanged", nil)
            rowEditBox:SetHandler("OnFocusLost", nil)
            rowEditBox:SetText(patternText)
            
            local targetGroup = selectedGroupName

            rowEditBox:SetHandler("OnTextChanged", function(self) HandlePatternTextChanged(self, patterns, i) end)
            rowEditBox:SetHandler("OnFocusLost", function(self) HandlePatternFocusLost(self, patterns, i, targetGroup) end)

            local btnDelete = GetControl(row, "BtnDelete")
            btnDelete:SetHandler("OnClicked", function() HandlePatternDelete(patterns, i) end)
        end

        btnAddRule:SetHandler("OnClicked", function() HandleAddRule(patterns) end)
    end

    pencilBtn:SetHandler("OnClicked", function() HandlePencilClick(titleLabel, pencilBtn, editBox, activeRules) end)
    editBox:SetHandler("OnFocusLost", function() CommitGroupNameEdit(editBox, titleLabel, pencilBtn) end)
    editBox:SetHandler("OnEnter", function(self)
        self:LoseFocus()
        CommitGroupNameEdit(editBox, titleLabel, pencilBtn)
    end)
end

------------------------------------------------------------------
--	Refresh Groups Editor
------------------------------------------------------------------
local function InitEditItemsButton()
    local btnEditItems = GetControl(InventoryCompanion_GroupsWindow, "BtnEditItems")
	btnEditItems:SetHandler("OnClicked", function() this.OpenEditItemsPanel() end)
end

local function InitNewGroupButton()
    local topBar = GetControl(InventoryCompanion_GroupsWindow, "TopActionBar")
    local btnNewGroup = GetControl(topBar, "BtnNewGroup")
    
    btnNewGroup:SetHandler("OnClicked", function()
        local timestampKey = string.format("custom_%d", GetGameTimeMilliseconds())
        local uniqueDisplayName = GenerateUniqueGroupName(nil, nil)
        
        this.CreateCustomRule(timestampKey, uniqueDisplayName)
        
        selectedGroupName = timestampKey
        this.RefreshGroupsEditor()

        local rightPane = InventoryCompanion_GroupsWindowRightPane
        local titleLabel = GetControl(rightPane, "GroupTitleLabel")
        local editBox = GetControl(rightPane, "GroupEditBox")
        local pencilBtn = GetControl(rightPane, "BtnEditGroupName")

        editBox:SetText(uniqueDisplayName)
        titleLabel:SetHidden(true)
        pencilBtn:SetHidden(true)
        editBox:SetHidden(false)
        editBox:TakeFocus()
        editBox:SelectAll()

        this.RefreshItemTrackerPanel()
    end)
end

local function InitToolbar()
    InitEditItemsButton()
    InitNewGroupButton()
end

function this.RefreshGroupsEditor()
    InitToolbar()

    local groupNames, activeRules = GetSortedGroupNames()

    PopulateGroupListPane(groupNames, activeRules)
    PopulateSingleGroupPane(activeRules)
	SetActionButtons(activeRules)
end

------------------------------------------------------------------
-- Scene Integration & Endpoints
------------------------------------------------------------------
local groupsScene = ZO_Scene:New("InventoryCompanion_GroupsScene", SCENE_MANAGER)
groupsScene:AddFragment(ZO_FadeSceneFragment:New(InventoryCompanion_GroupsWindow))

--these don't seem to ever fire...
groupsScene:RegisterCallback(SCENE_SHOWING, function()
    SetGameCameraUIMode(true)
    this.RefreshGroupsEditor()
	this.UpdateEditorLayout()
end)

groupsScene:RegisterCallback(SCENE_HIDDEN, function()
    SetGameCameraUIMode(false)
	this.UpdateEditorLayout()
end)

-- ...so I put these in
InventoryCompanion_GroupsWindow:SetHandler("OnEffectivelyShown", function()
    SetGameCameraUIMode(true)
    this.RefreshGroupsEditor()
    this.UpdateEditorLayout()
end)

InventoryCompanion_GroupsWindow:SetHandler("OnEffectivelyHidden", function()
    SetGameCameraUIMode(false)
    this.UpdateEditorLayout()
end)
------------------------------------------------------------------
-- Custom Confirmation Dialog Registrations
------------------------------------------------------------------
local function DoDeleteGroup(dialog)
    local data = dialog.data
    this.DeleteCustomRule(data.groupId)
    selectedGroupName = nil
    this.RefreshGroupsEditor()
    this.RefreshItemTrackerPanel()
    
    zo_callLater(function() SetGameCameraUIMode(true) end, 50)
end

local function DoResetGroup(dialog)
    -- Support dialog.data being either a table with .groupId or a direct string key
    local groupId = type(dialog.data) == "table" and dialog.data.groupId or dialog.data
    assert(type(groupId) == "string" and groupId ~= "", "Reset dialog requires a group ID")
    
    this.ResetRule(groupId)
    
    this.RefreshGroupsEditor()
    this.RefreshItemTrackerPanel()
    
    zo_callLater(function() SetGameCameraUIMode(true) end, 50)
end

ZO_Dialogs_RegisterCustomDialog("InventoryCompanion_CONFIRM_DELETE_GROUP_DIALOG", {
    gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
    title = { text = "Confirm Group Deletion" },
    mainText = {
        text = function(dialog)
            local data = dialog.data
            return string.format(
                "Are you sure you want to delete the custom group '%s'?\n\n|cFF5252This action cannot be undone.|r",
                data.groupName
            )
        end
    },
    buttons = {
        [1] = {
            text = "Delete",
            callback = DoDeleteGroup
        },
        [2] = {
            text = SI_DIALOG_CANCEL,
            callback = function(dialog)
                zo_callLater(function() SetGameCameraUIMode(true) end, 50)
            end
        }
    }
})

ZO_Dialogs_RegisterCustomDialog("InventoryCompanion_CONFIRM_RESET_GROUP_DIALOG", {
    gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
    title = { text = "Confirm Group Reset" },
    mainText = {
        text = function(dialog)
            local data = dialog.data
            return string.format(
                "Are you sure you want to reset the name and patterns for '%s' to their defaults?\n\n|cFF5252Its custom name and pattern edits will be cleared. Display settings will be kept.|r",
                data.groupName
            )
        end
    },
    buttons = {
        [1] = {
            text = "Reset",
            callback = DoResetGroup
        },
        [2] = {
            text = SI_DIALOG_CANCEL,
            callback = function(dialog)
                zo_callLater(function() SetGameCameraUIMode(true) end, 50)
            end
        }
    }
})