InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local groupRows = {}
local patternRows = {}
local selectedGroupName = nil

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
    if not name then return "" end
    -- Trim whitespace
    name = name:match("^%s*(.-)%s*$")
    -- Strip control characters (\0-\31, \127)
    name = name:gsub("[%z\1-\31\127]", "")
    -- Escape pipes (| to ||) to prevent ESO formatting injection
    name = name:gsub("|", "||")
    return name
end

local function HasMeaningfulOverride(groupId)
    local savedRules = this.character.useCharacterItemList and this.character.trackedRules or this.accountWide.trackedRules
    if not savedRules or not savedRules[groupId] then return false end

    local saved = savedRules[groupId]
    local base = this.preLoadedRulesets[groupId]

    if not base then return true end

    if saved.displayName ~= nil and saved.displayName ~= base.displayName then 
        return true 
    end
    
    if saved.patterns ~= nil then 
        return true 
    end

    if saved.display and saved.display.isHidden == true then 
        return true 
    end

    return false
end

local function GetSortedGroupNames()
    local activeRules = this.GetActiveTrackedRules(true)
    local groupNames = {}
    for name in pairs(activeRules) do
        table.insert(groupNames, name)
    end
	
	table.sort(groupNames, function(a, b)
        local ruleA = activeRules[a]
        local ruleB = activeRules[b]
        local nameA = (ruleA and ruleA.displayName) or a
        local nameB = (ruleB and ruleB.displayName) or b
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
    local displayName = ruleData and ruleData.displayName or groupName

    -- Apply hidden styling (Red text with "(hidden)" suffix)
    if ruleData and ruleData.display and ruleData.display.isHidden == true then
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
    if not scrollChild then return end

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

local function DoesGroupNameExist(savedRules, targetName, excludeKey)
    local activeRules = this.GetActiveTrackedRules(true)
    for key, rule in pairs(activeRules) do
        if key ~= excludeKey and rule.displayName and rule.displayName:lower() == targetName:lower() then
            return true
        end
    end
    return false
end

local function GenerateUniqueGroupName(savedRules, baseName, excludeKey)
    baseName = baseName or constants.newGroupBaseName

    if baseName ~= constants.newGroupBaseName and baseName ~= "" then
        if not DoesGroupNameExist(savedRules, baseName, excludeKey) then
            return baseName
        end
        
        local counter = 2
        while true do
            local candidate = string.format("%s %d", baseName, counter)
            if not DoesGroupNameExist(savedRules, candidate, excludeKey) then
                return candidate
            end
            counter = counter + 1
        end
    end

    local quirkyNames = GetQuirkyDefaultNames()
    for _, name in ipairs(quirkyNames) do
        if not DoesGroupNameExist(savedRules, name, excludeKey) then
            return name
        end
    end

    local counter = 5
    while true do
        local candidate = string.format("%s %d", constants.newGroupBaseName, counter)
        if not DoesGroupNameExist(savedRules, candidate, excludeKey) then
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

    local savedRules = this.character.useCharacterItemList and this.character.trackedRules or this.accountWide.trackedRules
    local finalName = GenerateUniqueGroupName(savedRules, sanitized, selectedGroupName)

    if finalName ~= sanitized then
        this.Utils.UserMessage(string.format("Group name already exists. Automatically renamed to '%s'.", finalName))
    end

    local basePredefined = this.preLoadedRulesets[selectedGroupName]

    if basePredefined then
        savedRules[selectedGroupName] = savedRules[selectedGroupName] or {}
        savedRules[selectedGroupName].displayName = finalName
        savedRules[selectedGroupName].patterns = savedRules[selectedGroupName].patterns or basePredefined.patterns
        savedRules[selectedGroupName].display = savedRules[selectedGroupName].display or {}
        for k, v in pairs(basePredefined.display) do
            if savedRules[selectedGroupName].display[k] == nil then
                savedRules[selectedGroupName].display[k] = v
            end
        end
    else
        savedRules[selectedGroupName] = savedRules[selectedGroupName] or {}
        savedRules[selectedGroupName].displayName = finalName
        savedRules[selectedGroupName].patterns = savedRules[selectedGroupName].patterns or {}
    end

    editBox:SetHidden(true)
    titleLabel:SetHidden(false)
    pencilBtn:SetHidden(false)
    this.RefreshGroupsEditor()
    if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
end

local function HandlePencilClick(titleLabel, pencilBtn, editBox, activeRules)
    local ruleData = activeRules[selectedGroupName]
    local displayName = ruleData and ruleData.displayName or selectedGroupName

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
    local savedRules = this.character.useCharacterItemList and this.character.trackedRules or this.accountWide.trackedRules
    local basePredefined = this.preLoadedRulesets[groupName]
    
    if basePredefined then
        savedRules[groupName] = savedRules[groupName] or {}
        savedRules[groupName].displayName = basePredefined.displayName
        savedRules[groupName].patterns = patterns
        savedRules[groupName].display = savedRules[groupName].display or {}
        for k, v in pairs(basePredefined.display) do
            if savedRules[groupName].display[k] == nil then
                savedRules[groupName].display[k] = v
            end
        end
    else
        savedRules[groupName] = savedRules[groupName] or {}
        savedRules[groupName].displayName = savedRules[groupName].displayName or groupName
        savedRules[groupName].patterns = patterns
    end
end

local function HandlePatternTextChanged(self, patterns, index)
    patterns[index] = self:GetText()
end

local function HandlePatternFocusLost(self, patterns, index, targetGroup)
    patterns[index] = self:GetText()
    
    if targetGroup == selectedGroupName then
        SaveRulePatterns(targetGroup, patterns)
        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
    end
end

local function HandlePatternDelete(patterns, index)
    table.remove(patterns, index)
    SaveRulePatterns(selectedGroupName, patterns)
    this.RefreshGroupsEditor()
    if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
end

local function HandleAddRule(patterns)
    table.insert(patterns, "")
    SaveRulePatterns(selectedGroupName, patterns)
    this.RefreshGroupsEditor()
end

local function ConfigureCustomGroupActionBar(btnReset, btnHide, btnDelete, actionBar, savedRules, groupId, activeRules, isHidden)
    btnReset:SetHidden(true)
    
    -- Show and position the Hide/Unhide button on the far left
    btnHide:SetHidden(false)
    btnHide:ClearAnchors()
    btnHide:SetAnchor(TOPLEFT, actionBar, TOPLEFT, 0, 0)
    
    if isHidden then
        btnHide:SetText("Unhide Group")
        btnHide:SetHandler("OnClicked", function()
            if savedRules and savedRules[groupId] and savedRules[groupId].display then
                savedRules[groupId].display.isHidden = false
            end
            this.RefreshGroupsEditor()
            if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
        end)
    else
        btnHide:SetText("Hide Group")
        btnHide:SetHandler("OnClicked", function()
            this.SetRuleFlag(groupId, "isHidden", true)
            this.RefreshGroupsEditor()
            if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
        end)
    end

    -- Show and position the Delete button to the right of the Hide button
    btnDelete:SetHidden(false)
    btnDelete:ClearAnchors()
    btnDelete:SetAnchor(TOPLEFT, btnHide, TOPRIGHT, 10, 0)
    btnDelete:SetHandler("OnClicked", function()
        local ruleData = activeRules[groupId]
        local displayName = ruleData and ruleData.displayName or groupId

        ZO_Dialogs_ShowDialog("InventoryCompanion_CONFIRM_DELETE_GROUP_DIALOG", {
            groupId = groupId,
            groupName = displayName,
        })
    end)
end

local function ConfigurePreloadedHideButton(btnHide, savedRules, groupId, isHidden)
    btnHide:SetHidden(false)
    if isHidden then
        btnHide:SetText("Unhide Group")
        btnHide:SetHandler("OnClicked", function()
            if savedRules and savedRules[groupId] and savedRules[groupId].display then
                savedRules[groupId].display.isHidden = false
            end
            this.RefreshGroupsEditor()
            if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
        end)
    else
        btnHide:SetText("Hide Group")
        btnHide:SetHandler("OnClicked", function()
            this.SetRuleFlag(groupId, "isHidden", true)
            this.RefreshGroupsEditor()
            if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
        end)
    end
end

local function ConfigurePreloadedResetButton(btnReset, btnHide, actionBar, hasOverride, savedRules, groupId, activeRules)
    if hasOverride then
        btnReset:SetHidden(false)
        btnReset:ClearAnchors()
        btnReset:SetAnchor(TOPLEFT, actionBar, TOPLEFT, 0, 0)

        btnHide:ClearAnchors()
        btnHide:SetAnchor(TOPLEFT, btnReset, TOPRIGHT, 10, 0)

        btnReset:SetHandler("OnClicked", function()
            local ruleData = activeRules[groupId]
            local displayName = ruleData and ruleData.displayName or groupId

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

local function SetActionButtons(activeRules)
    local rightPane = InventoryCompanion_GroupsWindowRightPane
    local actionBar = GetControl(rightPane, "ActionBar")
    local btnReset = GetControl(actionBar, "BtnReset")
    local btnHide = GetControl(actionBar, "BtnHide")
    local btnDelete = GetControl(actionBar, "BtnDelete")

    local groupId = selectedGroupName
    
    -- Miscellaneous can never be hidden or deleted, but can be reset if renamed
    if groupId == "miscellaneous" then
        btnHide:SetHidden(true)
        btnDelete:SetHidden(true)
        
        local hasOverride = HasMeaningfulOverride(groupId)
        if hasOverride then
            btnReset:SetHidden(false)
            btnReset:ClearAnchors()
            btnReset:SetAnchor(TOPLEFT, actionBar, TOPLEFT, 0, 0)
            btnReset:SetHandler("OnClicked", function()
                local ruleData = activeRules[groupId]
                local displayName = ruleData and ruleData.displayName or groupId

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
    local hasOverride = HasMeaningfulOverride(groupId)

    local savedRules = this.character.useCharacterItemList and this.character.trackedRules or this.accountWide.trackedRules
    local savedData = savedRules and savedRules[groupId]
    local isHidden = savedData and savedData.display and savedData.display.isHidden == true

    if not basePreloaded then
		ConfigureCustomGroupActionBar(btnReset, btnHide, btnDelete, actionBar, savedRules, groupId, activeRules, isHidden) 
    else
        btnDelete:SetHidden(true)
        ConfigurePreloadedHideButton(btnHide, savedRules, groupId, isHidden)
        ConfigurePreloadedResetButton(btnReset, btnHide, actionBar, hasOverride, savedRules, groupId, activeRules)
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
    local displayName = ruleData and ruleData.displayName or selectedGroupName

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
        if ruleData and ruleData.patterns then
            for _, p in ipairs(ruleData.patterns) do
                table.insert(patterns, p)
            end
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
        local savedRules = this.character.useCharacterItemList and this.character.trackedRules or this.accountWide.trackedRules
        local uniqueDisplayName = GenerateUniqueGroupName(savedRules, nil, nil)
        
        savedRules[timestampKey] = {
            displayName = uniqueDisplayName,
            patterns = {},
            display = {
                show = true,
                notify = false,
                bank = false,
                group = true,
                isExpanded = true,
                isHidden = false,
            }
        }
        
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
    if this.RefreshGroupsEditor then this.RefreshGroupsEditor() end
    if this.UpdateEditorLayout then this.UpdateEditorLayout() end
end)

InventoryCompanion_GroupsWindow:SetHandler("OnEffectivelyHidden", function()
    SetGameCameraUIMode(false)
    if this.UpdateEditorLayout then this.UpdateEditorLayout() end
end)
------------------------------------------------------------------
-- Custom Confirmation Dialog Registrations
------------------------------------------------------------------
local function DoDeleteGroup(dialog)
    local data = dialog.data
    local savedRules = this.character.useCharacterItemList and this.character.trackedRules or this.accountWide.trackedRules
    if savedRules then
        savedRules[data.groupId] = nil
    end
    selectedGroupName = nil
    this.RefreshGroupsEditor()
    if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
    
    zo_callLater(function() SetGameCameraUIMode(true) end, 50)
end

local function DoResetGroup(dialog)
    -- Support dialog.data being either a table with .groupId or a direct string key
    local groupId = type(dialog.data) == "table" and dialog.data.groupId or dialog.data
    if not groupId then return end
    
    local savedRules = this.character.useCharacterItemList and this.character.trackedRules or this.accountWide.trackedRules
    local ruleEntry = savedRules[groupId]
    
    if ruleEntry then
        ruleEntry.displayName = nil
        ruleEntry.patterns = nil
        if ruleEntry.display then 
            ruleEntry.display.isHidden = nil 
        end
    end
    
    this.RefreshGroupsEditor()
    if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
    
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
                "Are you sure you want to reset '%s' to its default state?\n\n|cFF5252All custom patterns for this group will be lost.|r",
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