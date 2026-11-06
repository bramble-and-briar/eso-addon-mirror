local this = InventoryCompanion

local editorRows = {}
local searchQuery = ""
local editorRevision = 0
local optionsTarget
local optionsEventName = this.Name .. "_ItemRowOptions"

function this.CloseItemRowOptions()
    optionsTarget = nil
    InventoryCompanion_ItemRowOptions:SetHidden(true)
    EVENT_MANAGER:UnregisterForEvent(optionsEventName, EVENT_GLOBAL_MOUSE_DOWN)
end

InventoryCompanion_ItemRowOptions:SetHandler("OnKeyDown", function(_, key)
    if key == KEY_ESCAPE then this.CloseItemRowOptions() end
end)
InventoryCompanion_ItemRowOptions:SetHandler("OnEffectivelyHidden", function()
    optionsTarget = nil
    EVENT_MANAGER:UnregisterForEvent(optionsEventName, EVENT_GLOBAL_MOUSE_DOWN)
end)
ZO_PreHookHandler(GetControl(InventoryCompanion_TrackedItemsWindow, "ScrollContainer").scroll,
    "OnScrollOffsetChanged", function() this.CloseItemRowOptions() end)

------------------------------------------------------------------
-- DBCopy Helpers & Data Migration Logic
------------------------------------------------------------------
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

    ZO_CheckButton_SetCheckState(chkShow, this.GetSettingsProfile().filterShow ~= false)
    ZO_CheckButton_SetCheckState(chkNotify, this.GetSettingsProfile().filterNotify ~= false)
    ZO_CheckButton_SetCheckState(chkMute, this.GetSettingsProfile().filterMute ~= false)
    ZO_CheckButton_SetCheckState(chkUntracked, this.GetSettingsProfile().filterUntracked == true)

    local function ToggleFilter(chkControl, key)
        local newState = not (this.GetSettingsProfile()[key] ~= false)
        if key == "filterUntracked" then
            newState = not (this.GetSettingsProfile()[key] == true)
        end
        this.GetSettingsProfile()[key] = newState
        ZO_CheckButton_SetCheckState(chkControl, newState)
        this.RefreshTrackedItemsEditor()
    end

    ZO_CheckButton_SetToggleFunction(chkShow, function(control, checked)
        this.GetSettingsProfile().filterShow = checked
        this.RefreshTrackedItemsEditor()
    end)

    ZO_CheckButton_SetToggleFunction(chkNotify, function(control, checked)
        this.GetSettingsProfile().filterNotify = checked
        this.RefreshTrackedItemsEditor()
    end)

    ZO_CheckButton_SetToggleFunction(chkMute, function(control, checked)
        this.GetSettingsProfile().filterMute = checked
        this.RefreshTrackedItemsEditor()
    end)
   
    ZO_CheckButton_SetToggleFunction(chkUntracked, function(control, checked)
        this.GetSettingsProfile().filterUntracked = checked
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
    GetControl(InventoryCompanion_TrackedItemsWindow, "BtnAutoCategory"):SetHidden(not this.AutoCategoryIntegration.IsPanelAvailable())
end

local function InitToolbar()
    local topBar = GetControl(InventoryCompanion_TrackedItemsWindow, "TopActionBar")
    local filterBar = GetControl(InventoryCompanion_TrackedItemsWindow, "FilterBar")

	InitEditGroupsButton(topBar)
    InitFilterBar(filterBar)	
end

------------------------------------------------------------------
-- Custom Confirmation Dialog Registration
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
    this.RefreshTrackedItemsEditor()
    this.UpdateEditorLayout()
end)

InventoryCompanion_TrackedItemsWindow:SetHandler("OnEffectivelyHidden", function()
    this.EndEditorVisit(InventoryCompanion_TrackedItemsWindow)
    this.CloseItemRowOptions()
    editorRevision = editorRevision + 1
    SetGameCameraUIMode(false)
    this.UpdateEditorLayout()
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
    for ruleName, data in pairs(trackedRules) do
		if ruleName ~= "miscellaneous" then -- NEW FOR KEY CHANGE
            local ruleData = activeRules[ruleName] -- NEW FOR KEY CHANGE
            local displayName = ruleData.displayName
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
    if not this.GetSettingsProfile().filterUntracked then return end

    local bagList = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
    if IsESOPlusSubscriber() and this.GetSettingsProfile().filterCraftbag then
        table.insert(bagList, BAG_VIRTUAL)
    end
    
    local untrackedSeen = {}
    
    local untrackedItems = this.Scanning.GetBagContents(bagList, function(item)
        if seenItemIds[item.itemId] or untrackedSeen[item.itemId] then return false end
        
        for _, ruleData in pairs(trackedRules) do
            if this.ItemMatchesRuntimeRule(item.link, ruleData) then
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
    local displayData = this.ResolveItemDisplay(entry.data.display)

    if not entry.isUntracked then
        local showFlag = displayData.show ~= false
        local notifyFlag = displayData.notify == true

        local isInactive = (not showFlag and not notifyFlag)

        local allowShow = showFlag and (this.GetSettingsProfile().filterShow ~= false)
        local allowNotify = notifyFlag and (this.GetSettingsProfile().filterNotify ~= false)
        local allowInactive = isInactive and (this.GetSettingsProfile().filterMute ~= false)

        if not (allowShow or allowNotify or allowInactive) then
            return false
        end
    else
        if not this.GetSettingsProfile().filterUntracked then
            return false
        end
    end

    if queryStr ~= "" and not entry.name:lower():find(queryStr, 1, true) then
        return false
    end

    return true
end

local function ResolveEntryData(entry)
    local rules, revision = this.GetTrackerContext()
    assert(entry.editorRevision == editorRevision, "Tracked-items editor action targets an obsolete row")
    assert(entry.rules == rules and entry.contextRevision == revision,
        "Tracked-items editor action targets an obsolete profile")

    if entry.isRule then
        local rule = this.GetRuntimeRules()[entry.key]
        assert(rule and not rule.display.isHidden, "Tracked-items editor action targets a missing or hidden rule")
        return rule
    end

    local tracked = this.GetActiveTrackedItems()[entry.key]
    if entry.isUntracked then
        assert(tracked == nil, "Untracked editor entry is already tracked")
        return entry.data
    end
    assert(tracked, "Tracked-items editor action targets a removed item")
    return tracked
end

local function SetEntryFlag(entry, flagKey, value, refreshCallback)
    assert(flagKey == "showBackpack" or flagKey == "showBank" or flagKey == "notifyChat"
        or flagKey == "notifyHud" or flagKey == "group",
        "Unknown item editor flag: " .. tostring(flagKey))
    assert(type(value) == "boolean", "Item editor flag value must be boolean")
    assert(flagKey ~= "group" or entry.isRule, "Grouping is only editable on group rows")
    local data = ResolveEntryData(entry)

    if entry.isRule then
        this.UpdateRuleFlag(entry.key, flagKey, value)
    elseif entry.isUntracked then
        local display = data.display
        local tracked = {
            link = data.link,
            icon = data.icon,
            display = {
                show = display.show,
                notify = display.notify,
                bank = display.bank,
                group = display.group,
                showBackpack = display.showBackpack,
                showBank = display.showBank,
                notifyChat = display.notifyChat,
                notifyHud = display.notifyHud,
            },
        }
        tracked.display[flagKey] = value
        this.GetActiveTrackedItems()[entry.key] = tracked
    else
        data.display[flagKey] = value
    end

    refreshCallback()
    this.UpdateEventRegistry()
end

local function ConfigureRowStateStyles(row, entry)
    local display = this.ResolveItemDisplay(entry.data.display)

    local function ApplyStyle(name, active, detail)
        local button = GetControl(row, name)
        GetControl(button, "Detail"):SetColor(1.0, 0.94, 0.76, active and 1.0 or 0.5)
        GetControl(button, "Detail"):SetText(detail)
    end

    local locations = display.showBackpack and (display.showBank and "Both" or "Backpack")
        or (display.showBank and "Bank" or "None")
    if display.show and entry.isRule and display.group then locations = locations .. ", grouped" end
    local destinations = display.notifyChat and (display.notifyHud and "Both" or "Chat")
        or (display.notifyHud and "HUD" or "None")
    ApplyStyle("Show", display.show, locations)
    ApplyStyle("Notify", display.notify, destinations)
end

local OpenRowOptions
OpenRowOptions = function(row, entry, kind, refreshCallback)
    assert(kind == "Show" or kind == "Notify", "Unknown tracking option column: " .. tostring(kind))
    if optionsTarget and optionsTarget.entry == entry and optionsTarget.kind == kind then
        this.CloseItemRowOptions()
        return
    end
    this.CloseItemRowOptions()
    ResolveEntryData(entry)
    local panel = InventoryCompanion_ItemRowOptions
    local target = { entry = entry, kind = kind, row = row }
    optionsTarget = target
    local fields
    if kind == "Show" then
        fields = {}
        if entry.isRule then fields[#fields + 1] = { "group", "Display items together" } end
        fields[#fields + 1] = { "showBackpack", "Show backpack" }
        fields[#fields + 1] = { "showBank", "Show bank" }
    else
        fields = { { "notifyChat", "Notify Chat" }, { "notifyHud", "Notify HUD" } }
    end
    for index = 1, 3 do
        local option = GetControl(panel, "Option" .. index)
        local field = fields[index]
        option:SetHidden(field == nil)
        if field then
            local check, label = GetControl(option, "Check"), GetControl(option, "Label")
            label:SetText(field[2])
            label:SetColor(1.0, 0.94, 0.76, 1.0)
            local function IsChecked()
                return this.ResolveItemDisplay(ResolveEntryData(entry).display)[field[1]] == true
            end
            ZO_CheckButton_SetCheckState(check, IsChecked())
            local function Apply(checked)
                assert(optionsTarget == target, "Item row options action targets an obsolete popup")
                local function Refresh()
                    refreshCallback()
                    for _, currentRow in ipairs(editorRows) do
                        local current = currentRow.entry
                        if not currentRow:IsHidden() and current.key == entry.key
                            and current.isRule == entry.isRule then
                            OpenRowOptions(currentRow, current, kind, refreshCallback)
                            break
                        end
                    end
                end
                SetEntryFlag(entry, field[1], checked, Refresh)
            end
            ZO_CheckButton_SetToggleFunction(check, function(_, checked) Apply(checked) end)
            label:SetHandler("OnMouseDown", function(_, button)
                if button == MOUSE_BUTTON_INDEX_LEFT then
                    Apply(not IsChecked())
                end
            end)
        end
    end
    panel:SetDimensions(274, 16 + #fields * 30)
    panel:SetDrawTier(DT_HIGH)
    panel:ClearAnchors()
    local anchor = GetControl(row, kind)
    panel:SetAnchor(TOPRIGHT, anchor, BOTTOMRIGHT, 0, 2)
    if panel:GetTop() + panel:GetHeight() > GuiRoot:GetHeight() then
        panel:ClearAnchors()
        panel:SetAnchor(BOTTOMRIGHT, anchor, TOPRIGHT, 0, -2)
    end
    panel:SetHidden(false)
    EVENT_MANAGER:RegisterForEvent(optionsEventName, EVENT_GLOBAL_MOUSE_DOWN, function()
        local control = WINDOW_MANAGER:GetMouseOverControl()
        while control do
            if control == panel or control == anchor then return end
            control = control:GetParent()
        end
        this.CloseItemRowOptions()
    end)
end

local function ConfigureRowClickHandlers(row, entry, refreshCallback)
    row.entry = entry
    entry.editorRevision = editorRevision
    entry.rules, entry.contextRevision = this.GetTrackerContext()
    GetControl(row, "Show"):SetHandler("OnClicked", function() OpenRowOptions(row, entry, "Show", refreshCallback) end)
    GetControl(row, "Notify"):SetHandler("OnClicked", function() OpenRowOptions(row, entry, "Notify", refreshCallback) end)
end

local function ConfigureRowTextAndRemoval(row, entry, refreshCallback)
    local label     = GetControl(row, "ItemLabel")
    local btnRemove = GetControl(row, "BtnRemove")
    local key       = entry.key
    local isRule    = entry.isRule
    local data      = entry.data

    if isRule then
        local activeRules = this.GetActiveTrackedRules() -- NEW FOR KEY CHANGE
        local ruleData = activeRules[key] -- NEW FOR KEY CHANGE
        local displayName = ruleData.displayName
        label:SetText(string.format("|c50c878[Group]|r %s", displayName)) -- NEW FOR KEY CHANGE
        btnRemove:SetHidden(true)
    elseif entry.isUntracked then
        local iconTex = data.icon
        local iconFmt = (iconTex and iconTex ~= "") and string.format("|t20:20:%s|t", iconTex) or ""
        label:SetText(string.format("%s %s |c888888[Untracked]|r", iconFmt, data.link))
        btnRemove:SetHidden(true)
    else
        btnRemove:SetHidden(false)
        btnRemove:SetHandler("OnClicked", function()
            ResolveEntryData(entry)
            this.GetActiveTrackedItems()[key] = nil
            refreshCallback()
            this.UpdateEventRegistry()
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
    this.CloseItemRowOptions()
    editorRevision = editorRevision + 1
    local scrollChild = GetControl(InventoryCompanion_TrackedItemsWindow, "ScrollContainerScrollChild")
    assert(scrollChild, "Tracked-items editor is missing ScrollContainerScrollChild")

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
    local rowHeight = 34

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
                this.RefreshItemTrackerPanel()
            end)

            rowIndex = rowIndex + 1
        end
        this.RefreshEditorChrome(InventoryCompanion_TrackedItemsWindow, "items")
    end
end
