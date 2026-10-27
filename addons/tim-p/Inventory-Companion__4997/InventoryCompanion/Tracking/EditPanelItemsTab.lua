InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local editorRows = {}
local searchQuery = ""

------------------------------------------------------------------
-- DBCopy Helpers & Data Migration Logic
------------------------------------------------------------------
local function GetCurrentCharacterProfileKey()
    local sv = _G[this.SettingsName]
    local playerName = GetUnitName("player")
    if sv and sv.Default then
        for _, accData in pairs(sv.Default) do
            for profileName, profileData in pairs(accData) do
                if profileName ~= "$AccountWide" and profileData and profileData["$LastCharacterName"] == playerName then
                    return profileName
                end
            end
        end
    end
    return playerName
end

local function GetCurrentDestinationKey()
    if this.character and this.character.useCharacterItemList == true then
        return GetCurrentCharacterProfileKey()
    else
        return "$AccountWide"
    end
end

local function GetCurrentDestinationDisplayName()
    if this.character and this.character.useCharacterItemList == true then
        return GetUnitName("player") .. " (Character List)"
    else
        return "[Account Wide]"
    end
end

local function GetAvailableProfiles()
    local profiles = {}
    local sv = _G[this.SettingsName]
    local currentDestinationKey = GetCurrentDestinationKey()
    
    local accountWideEntry = nil

    if sv and sv.Default then
        for _, accData in pairs(sv.Default) do
            for profileName, profileData in pairs(accData) do
                if profileName ~= currentDestinationKey then
                    if profileName == "$AccountWide" then
                        accountWideEntry = {
                            key = profileName,
                            name = "[Account Wide]",
                        }
                    else
                        local charName = profileData and profileData["$LastCharacterName"]
                        local displayName = (charName and charName ~= "") and charName or string.format("Character (%s)", profileName)

                        table.insert(profiles, {
                            key = profileName,
                            name = displayName,
                        })
                    end
                end
            end
        end
    end
    
    table.sort(profiles, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    if accountWideEntry then
        table.insert(profiles, 1, accountWideEntry)
    end
    
    return profiles
end

local function GetProfileDetailedCounts(profileKey)
    local total, showCount, notifyCount, bankCount, groupCount = 0, 0, 0, 0, 0
    local sv = _G[InventoryCompanion.SettingsName]
    if sv and sv.Default then
        for _, accData in pairs(sv.Default) do
            local block = (profileKey == "$AccountWide") and accData["$AccountWide"] or accData[profileKey]
            if block and block.trackedItems then
                for _, data in pairs(block.trackedItems) do
                    total = total + 1
                    local display = data.display
                    if display.show ~= false then showCount = showCount + 1 end
                    if display.notify then notifyCount = notifyCount + 1 end
                    if display.bank then bankCount = bankCount + 1 end
                    if display.group then groupCount = groupCount + 1 end
                end
            end
        end
    end
    return total, showCount, notifyCount, bankCount, groupCount
end

local function BuildImportPreviewText(sourceKey)
    local sourceCount = GetProfileDetailedCounts(sourceKey)
    local currentList = InventoryCompanion.GetActiveTrackedItems()
    local destCount = 0
    if currentList then
        for _ in pairs(currentList) do destCount = destCount + 1 end
    end
    return string.format("Replace %d entries with %d", destCount, sourceCount)
end

local function ExecuteCopy(sourceKey)
    local success = InventoryCompanion.CopyProfile(sourceKey)

    if success then
        this.Utils.UserMessage("Profile and rule overrides imported successfully!", "Item Tracker Imported")
        if this.RefreshTrackedItemsEditor then this.RefreshTrackedItemsEditor() end
        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
    else
        this.Utils.UserError("Failed to access source or destination saved variables.", "Import Error")
    end
end

local function OnCopyButton(sourceKey, sourceDisplayName)
    local destDisplayName = GetCurrentDestinationDisplayName()
    local destTotal, destShow, destNotify, destBank, destGroup = GetProfileDetailedCounts(GetCurrentDestinationKey() == "$AccountWide" and "$AccountWide" or GetCurrentDestinationKey())
    
    if destTotal == 0 then
        local currentList = InventoryCompanion.GetActiveTrackedItems()
        if currentList then
            for _, data in pairs(currentList) do
                destTotal = destTotal + 1
                local display = data.display or {}
                if display.show ~= false then destShow = destShow + 1 end
                if display.notify then destNotify = destNotify + 1 end
                if display.bank then destBank = destBank + 1 end
                if display.group then destGroup = destGroup + 1 end
            end
        end
    end

    local sourceTotal, sourceShow, sourceNotify, sourceBank, sourceGroup = GetProfileDetailedCounts(sourceKey)

    ZO_Dialogs_ShowDialog("InventoryCompanion_CONFIRM_IMPORT_DIALOG", {
        sourceKey = sourceKey,
        sourceName = sourceDisplayName,
        destName = destDisplayName,
        sourceTotal = sourceTotal,
        sourceShow = sourceShow,
        sourceNotify = sourceNotify,
        destTotal = destTotal,
        destShow = destShow,
        destNotify = destNotify,
    })
end

------------------------------------------------------------------
-- Toolbar Initialization
------------------------------------------------------------------
local function InitCopyDropdown(topBar)
    local btnImportToggle = GetControl(topBar, "BtnImportToggle")
    local copyDropdownControl = GetControl(topBar, "CopyDropdown")
    local btnExecuteCopy = GetControl(topBar, "BtnExecuteCopy")
    local lblImportPreview = GetControl(topBar, "LblImportPreview")

    if not btnImportToggle or not copyDropdownControl or not btnExecuteCopy or not lblImportPreview then return end

    local comboBox = ZO_ComboBox_ObjectFromContainer(copyDropdownControl)
    if not comboBox then return end

    comboBox:SetSortsItems(false)

    local selectedSourceKey = nil
    local selectedSourceName = nil

    local function CollapseImportUI()
        selectedSourceKey = nil
        selectedSourceName = nil
        copyDropdownControl:SetHidden(true)
        btnExecuteCopy:SetHidden(true)
        lblImportPreview:SetHidden(true)
        lblImportPreview:SetText("")
        btnImportToggle:SetText("Import from:")
    end

    local function PopulateDropdownProfiles()
        comboBox:ClearItems()
        local profiles = GetAvailableProfiles()
        
        for index, profile in ipairs(profiles) do
            local entry = comboBox:CreateItemEntry(profile.name, function(comboBoxObj, itemName, itemData, selectionChanged, oldItem)
                if selectionChanged and itemData then
                    selectedSourceKey = itemData.key
                    selectedSourceName = profile.name
                    lblImportPreview:SetText(BuildImportPreviewText(selectedSourceKey))
                    lblImportPreview:SetHidden(false)
                end
            end)
            entry.key = profile.key
            comboBox:AddItem(entry)

            if index == 1 then
                selectedSourceKey = profile.key
                selectedSourceName = profile.name
                comboBox:SetSelectedItem(profile.name)
                lblImportPreview:SetText(BuildImportPreviewText(selectedSourceKey))
                lblImportPreview:SetHidden(false)
            end
        end
    end

    btnImportToggle:SetHandler("OnClicked", function()
        if copyDropdownControl:IsHidden() then
            PopulateDropdownProfiles()
            copyDropdownControl:SetHidden(false)
            btnExecuteCopy:SetHidden(false)
            btnImportToggle:SetText("Cancel")
        else
            CollapseImportUI()
        end
    end)

    btnExecuteCopy:SetHandler("OnClicked", function()
        if selectedSourceKey then
            OnCopyButton(selectedSourceKey, selectedSourceName)
            CollapseImportUI()
        else
            this.Utils.UserWarning("Please select a source profile from the dropdown first.")
        end
    end)
end

local function InitCharacterToggle(topBar)
    local chkUseChar = GetControl(topBar, "ChkUseChar")
    local lblUseChar = GetControl(topBar, "LblUseChar")

    ZO_CheckButton_SetCheckState(chkUseChar, this.character.useCharacterItemList == true)

    local function ApplyUseChar(checked)
        this.character.useCharacterItemList = checked
        
        local copyDropdownControl = GetControl(topBar, "CopyDropdown")
        local btnExecuteCopy = GetControl(topBar, "BtnExecuteCopy")
        local lblImportPreview = GetControl(topBar, "LblImportPreview")
        local btnImportToggle = GetControl(topBar, "BtnImportToggle")
        if copyDropdownControl then copyDropdownControl:SetHidden(true) end
        if btnExecuteCopy then btnExecuteCopy:SetHidden(true) end
        if lblImportPreview then lblImportPreview:SetHidden(true); lblImportPreview:SetText("") end
        if btnImportToggle then btnImportToggle:SetText("Import from:") end

        this.RefreshTrackedItemsEditor()
        if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
    end

    ZO_CheckButton_SetToggleFunction(chkUseChar, function(control, checked)
        ApplyUseChar(checked)
    end)

    lblUseChar:SetHandler("OnMouseDown", function()
        local newState = not (this.character.useCharacterItemList == true)
        this.character.useCharacterItemList = newState
        ZO_CheckButton_SetCheckState(chkUseChar, newState)
        ApplyUseChar(newState)
    end)
end

local function InitFilterBar(filterBar)
    local chkShow = GetControl(filterBar, "ChkShow")
    local chkNotify = GetControl(filterBar, "ChkNotify")
    local chkMute = GetControl(filterBar, "ChkMute")
    local chkUntracked = GetControl(filterBar, "ChkUntracked")
	local findBox = GetControl(filterBar, "FindBox")
    
    local lblShow   = GetControl(filterBar, "LblShow")
    local lblNotify = GetControl(filterBar, "LblNotify")
    local lblMute   = GetControl(filterBar, "LblMute")
    local lblUntracked = GetControl(filterBar, "LblUntracked")

    ZO_CheckButton_SetCheckState(chkShow, this.character.filterShow ~= false)
    ZO_CheckButton_SetCheckState(chkNotify, this.character.filterNotify ~= false)
    ZO_CheckButton_SetCheckState(chkMute, this.character.filterMute ~= false)
    ZO_CheckButton_SetCheckState(chkUntracked, this.character.filterUntracked == true)

    local function ToggleFilter(chkControl, key)
        local newState = not (this.character[key] ~= false)
        if key == "filterUntracked" then
            newState = not (this.character[key] == true)
        end
        this.character[key] = newState
        ZO_CheckButton_SetCheckState(chkControl, newState)
        this.RefreshTrackedItemsEditor()
    end

    ZO_CheckButton_SetToggleFunction(chkShow, function(control, checked)
        this.character.filterShow = checked
        this.RefreshTrackedItemsEditor()
    end)

    ZO_CheckButton_SetToggleFunction(chkNotify, function(control, checked)
        this.character.filterNotify = checked
        this.RefreshTrackedItemsEditor()
    end)

    ZO_CheckButton_SetToggleFunction(chkMute, function(control, checked)
        this.character.filterMute = checked
        this.RefreshTrackedItemsEditor()
    end)
   
    ZO_CheckButton_SetToggleFunction(chkUntracked, function(control, checked)
        this.character.filterUntracked = checked
        this.RefreshTrackedItemsEditor()
    end)

    lblShow:SetHandler("OnMouseDown", function() ToggleFilter(chkShow, "filterShow") end)
    lblNotify:SetHandler("OnMouseDown", function() ToggleFilter(chkNotify, "filterNotify") end)
    lblMute:SetHandler("OnMouseDown", function() ToggleFilter(chkMute, "filterMute") end)
    lblUntracked:SetHandler("OnMouseDown", function() ToggleFilter(chkUntracked, "filterUntracked") end)

    findBox:SetText(searchQuery)
    findBox:SetHandler("OnTextChanged", function(self) searchQuery = self:GetText() this.RefreshTrackedItemsEditor() end)
end

local function InitEditGroupsButton(topBar)
    local btnEditGroups = GetControl(InventoryCompanion_TrackedItemsWindow, "BtnEditGroups")
    if btnEditGroups then
        btnEditGroups:SetHandler("OnClicked", function()
            this.OpenEditGroupsPanel()
        end)
    end
end

local function InitToolbar()
    local topBar = GetControl(InventoryCompanion_TrackedItemsWindow, "TopActionBar")
    local filterBar = GetControl(InventoryCompanion_TrackedItemsWindow, "FilterBar")

    InitCopyDropdown(topBar)
    InitCharacterToggle(topBar)
	InitEditGroupsButton(topBar)
    InitFilterBar(filterBar)	
end

------------------------------------------------------------------
-- Custom Confirmation Dialog Registration
------------------------------------------------------------------
ZO_Dialogs_RegisterCustomDialog("InventoryCompanion_CONFIRM_IMPORT_DIALOG", {
    gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
    title = { text = "Confirm Item Tracker Import" },
    mainText = {
        text = function(dialog)
            local data = dialog.data
            return string.format(
                "Are you sure you want to overwrite '%s' with '%s'?\n\n|cFF5252This action cannot be undone.|r",
                data.destName, data.sourceName
            )
        end
    },
    buttons = {
        [1] = {
            text = "Import",
            callback = function(dialog)
                local data = dialog.data
                ExecuteCopy(data.sourceKey)
                
                zo_callLater(function()
                    SetGameCameraUIMode(true)
                end, 50)
            end
        },
        [2] = {
            text = SI_DIALOG_CANCEL,
            callback = function(dialog)
                zo_callLater(function()
                    SetGameCameraUIMode(true)
                end, 50)
            end
        }
    }    
})

------------------------------------------------------------------
-- Scene Integration & Endpoints
------------------------------------------------------------------

local itemTrackerScene = ZO_Scene:New("InventoryCompanion_TrackedItemsScene", SCENE_MANAGER)
itemTrackerScene:AddFragment(ZO_FadeSceneFragment:New(InventoryCompanion_TrackedItemsWindow))

--these don't seem to ever fire...
itemTrackerScene:RegisterCallback(SCENE_SHOWING, function()
    SetGameCameraUIMode(true)
    this.RefreshTrackedItemsEditor()
	this.UpdateEditorLayout()
end)

itemTrackerScene:RegisterCallback(SCENE_HIDDEN, function()
    SetGameCameraUIMode(false)
	this.UpdateEditorLayout()
end)

-- ...so I put these in (trackeitemswindow is actually this tab...
InventoryCompanion_TrackedItemsWindow:SetHandler("OnEffectivelyShown", function()
    SetGameCameraUIMode(true)
    if this.RefreshTrackedItemsEditor then this.RefreshTrackedItemsEditor() end
    if this.UpdateEditorLayout then this.UpdateEditorLayout() end
end)

InventoryCompanion_TrackedItemsWindow:SetHandler("OnEffectivelyHidden", function()
    SetGameCameraUIMode(false)
    if this.UpdateEditorLayout then this.UpdateEditorLayout() end
end)

------------------------------------------------------------------
-- Refresh Panel
------------------------------------------------------------------
local function HideAllRows(editorRows)
    for _, row in ipairs(editorRows) do
        row:SetHidden(true)
    end
end

local function CollectTrackedItems(trackedList, seenItemIds, sortedEntries)
    if not trackedList then return end
    for itemId, data in pairs(trackedList) do
        seenItemIds[itemId] = true
        table.insert(sortedEntries, {
            key = itemId,
            isRule = false,
            isUntracked = false,
            name = GetItemLinkName(data.link) or "",
            data = data,
        })
    end
end

local function CollectWildcardRules(trackedRules, sortedEntries)
    local activeRules = this.GetActiveTrackedRules() -- NEW FOR KEY CHANGE
    if not trackedRules then return end
    for ruleName, data in pairs(trackedRules) do
		if ruleName ~= "miscellaneous" then -- NEW FOR KEY CHANGE
            local ruleData = activeRules[ruleName] -- NEW FOR KEY CHANGE
            local displayName = (ruleData and ruleData.displayName) or ruleName -- NEW FOR KEY CHANGE
			table.insert(sortedEntries, {
				key = ruleName,
				isRule = true,
				isUntracked = false,
				name = "Group: " .. displayName, -- NEW FOR KEY CHANGE
				data = data,
			})
		end
    end
end

local function CollectUntrackedItems(trackedRules, seenItemIds, sortedEntries)
    if not this.character.filterUntracked then return end

    local bagList = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
    if IsESOPlusSubscriber() and this.character.filterCraftbag then
        table.insert(bagList, BAG_VIRTUAL)
    end
    
    local untrackedSeen = {}
    
    local untrackedItems = this.Scanning.GetBagContents(bagList, function(item)
        if seenItemIds[item.itemId] or untrackedSeen[item.itemId] then return false end
        
        for _, ruleData in pairs(trackedRules) do
            local patterns = ruleData.patterns or { ruleData.pattern }
            if this.ItemMatchesAnyRule and this.ItemMatchesAnyRule(item.link, patterns) then
                return false
            end
        end
        
        untrackedSeen[item.itemId] = true
        return true
    end)

    for _, item in ipairs(untrackedItems) do		
        table.insert(sortedEntries, {
            key = item.itemId,
            isRule = false,
            isUntracked = true,
            name = GetItemLinkName(item.link) or "No LINK!",
            data = {
                link = item.link,
                icon = item.icon,                
				display = {
                    show = false,
                    notify = false,
                    bank = false,
                    group = false,
                },
            },
        })
    end
end

local function ShouldIncludeEntry(entry, queryStr)
    local displayData = entry.data.display or {}

    if not entry.isUntracked then
        local showFlag = displayData.show ~= false
        local notifyFlag = displayData.notify == true

        local isInactive = (not showFlag and not notifyFlag)

        local allowShow = showFlag and (this.character.filterShow ~= false)
        local allowNotify = notifyFlag and (this.character.filterNotify ~= false)
        local allowInactive = isInactive and (this.character.filterMute ~= false)

        if not (allowShow or allowNotify or allowInactive) then
            return false
        end
    else
        if not this.character.filterUntracked then
            return false
        end
    end

    if queryStr ~= "" and not entry.name:lower():find(queryStr, 1, true) then
        return false
    end

    return true
end

local function ToggleState(entry, flagKey, refreshCallback)
    entry.data.display[flagKey] = not entry.data.display[flagKey]

    if entry.isRule then
        InventoryCompanion.SetRuleFlag(entry.key, flagKey, entry.data.display[flagKey])
    elseif entry.isUntracked then
        local trackedList = InventoryCompanion.GetActiveTrackedItems()
        trackedList[entry.key] = { 
            link = entry.data.link, 
            icon = entry.data.icon, 
            display = {
                show  = entry.data.display.show,
                notify = entry.data.display.notify,
                bank  = entry.data.display.bank,
                group = entry.data.display.group,
            }
        }
    else
        InventoryCompanion.GetActiveTrackedItems()[entry.key].display[flagKey] = entry.data.display[flagKey]
    end

    refreshCallback()
end

local function ConfigureRowStateStyles(row, entry)
    local displayData = entry.data.display or {}

    local function ApplyLabelStyle(lbl, isActive)
        lbl:SetFont("ZoFontGame")
        lbl:SetColor(1.0, 0.94, 0.76, isActive and 1.0 or 0.5)
    end

    ApplyLabelStyle(GetControl(row, "LblNotifyState"), displayData.notify == true)
    ApplyLabelStyle(GetControl(row, "LblShowState"), displayData.show ~= false)
    ApplyLabelStyle(GetControl(row, "LblBankState"), displayData.bank == true)
    ApplyLabelStyle(GetControl(row, "LblGroupState"), displayData.group == true)
end

local function ConfigureRowClickHandlers(row, entry, refreshCallback)
    GetControl(row, "LblNotifyState"):SetHandler("OnMouseDown", function() ToggleState(entry, "notify", refreshCallback) end)
    GetControl(row, "LblShowState"):SetHandler("OnMouseDown", function() ToggleState(entry, "show", refreshCallback) end)
    GetControl(row, "LblBankState"):SetHandler("OnMouseDown", function() ToggleState(entry, "bank", refreshCallback) end)
    GetControl(row, "LblGroupState"):SetHandler("OnMouseDown", function() ToggleState(entry, "group", refreshCallback) end)
end

local function ConfigureRowTextAndRemoval(row, entry, refreshCallback)
    local label     = GetControl(row, "ItemLabel")
    local btnRemove = GetControl(row, "BtnRemove")
    local key       = entry.key
    local isRule    = entry.isRule
    local data      = entry.data

    GetControl(row, "LblGroupState"):SetHidden(not isRule)

    if isRule then
        local activeRules = this.GetActiveTrackedRules() -- NEW FOR KEY CHANGE
        local ruleData = activeRules[key] -- NEW FOR KEY CHANGE
        local displayName = (ruleData and ruleData.displayName) or key -- NEW FOR KEY CHANGE
        label:SetText(string.format("|c50c878[Group]|r %s", displayName)) -- NEW FOR KEY CHANGE
        btnRemove:SetHidden(true)
    elseif entry.isUntracked then
        local iconTex = data.icon
        local iconFmt = (iconTex and iconTex ~= "") and string.format("|t20:20:%s|t", iconTex) or ""
        label:SetText(string.format("%s %s |c888888[Untracked]|r", iconFmt, data.link))
        btnRemove:SetHidden(true)
    else
        local targetTable = InventoryCompanion.GetActiveTrackedItems()
        btnRemove:SetHidden(false)
        btnRemove:SetHandler("OnClicked", function()
            targetTable[key] = nil
            refreshCallback()
        end)

        local count = InventoryCompanion.GetTrackedItemCount(key)
        local iconTex = data.icon
        if not iconTex or iconTex == "" then
            iconTex = GetItemLinkIcon(data.link)
        end
        local iconFmt = (iconTex and iconTex ~= "") and string.format("|t20:20:%s|t", iconTex) or ""
        label:SetText(string.format("%s %s |cffffcc(%d)|r", iconFmt, data.link, count))
    end
end

local function UpdateRowVisualsAndHandlers(row, entry, refreshCallback)
    ConfigureRowStateStyles(row, entry)
    ConfigureRowClickHandlers(row, entry, refreshCallback)
    ConfigureRowTextAndRemoval(row, entry, refreshCallback)
end

function this.RefreshTrackedItemsEditor()
    local scrollChild = GetControl(InventoryCompanion_TrackedItemsWindow, "ScrollContainerScrollChild")
    if not scrollChild then return end

    InitToolbar()
    HideAllRows(editorRows)

    local trackedList = this.GetActiveTrackedItems()
    local trackedRules = this.GetActiveTrackedRules()
    local sortedEntries = {}
    local seenItemIds = {}

    CollectTrackedItems(trackedList, seenItemIds, sortedEntries)
    CollectWildcardRules(trackedRules, sortedEntries)
    CollectUntrackedItems(trackedRules, seenItemIds, sortedEntries)

    table.sort(sortedEntries, function(a, b) return a.name:lower() < b.name:lower() end)
    
    local queryStr = searchQuery:lower():match("^%s*(.-)%s*$")
    local rowIndex = 1
    local rowHeight = 36

    for _, entry in ipairs(sortedEntries) do
        if ShouldIncludeEntry(entry, queryStr) then
            local row = editorRows[rowIndex]
            if not row then
                row = CreateControlFromVirtual("InventoryCompanion_TrackedItemRow_", scrollChild, "InventoryCompanion_TrackedItemRow_Template", rowIndex)
                table.init = table.init or {}
                table.insert(editorRows, row)
            end

            row:ClearAnchors()
            row:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, 0, (rowIndex - 1) * rowHeight)
            row:SetHidden(false)

            UpdateRowVisualsAndHandlers(row, entry, function()
                this.RefreshTrackedItemsEditor()
                if this.RefreshItemTrackerPanel then this.RefreshItemTrackerPanel() end
            end)

            rowIndex = rowIndex + 1
        end
    end
end

