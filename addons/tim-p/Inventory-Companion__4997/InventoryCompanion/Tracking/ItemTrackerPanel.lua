InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local trackerRows = {}
local originalTrackerPos = nil
local previousLayout = nil
local ROW_HEIGHT = 22
local ROW_WIDTH = 320
local MAX_GROUP_ITEM_ROWS = 200
local MIN_COUNT_WIDTH = 36
local COUNT_WIDTH_PER_CHARACTER = 8

local function GetRowsContainer()
    return InventoryCompanion_ItemTrackerFloatContainerRows
end

local function GetRowsChild()
    return GetControl(GetRowsContainer(), "ScrollChild")
end

local function OnTrackerMoveStop(control)
    this.accountWide.trackerOffsetX = control:GetLeft()
    this.accountWide.trackerOffsetY = control:GetTop()
end

local function OnTrackerMouseUp(control, button)
    if button == MOUSE_BUTTON_INDEX_RIGHT then
        ClearMenu()

        -- 1. Toggle: Show/Hide Empty Tracked Items
        local showEmpty = (this.accountWide.showEmptyTrackedItems ~= false)
        AddCustomMenuItem(
            (showEmpty and "Hide Empty Tracked Items" or "Show Empty Tracked Items"),
            function()
                this.accountWide.showEmptyTrackedItems = not showEmpty
                this.RefreshItemTrackerPanel()
            end,
            MENU_ADD_OPTION_LABEL
        )

        -- 2. Toggle: Multiline / Single Line View
        local isWrapped = (this.accountWide.wrapTrackedItemNames == true)
        AddCustomMenuItem(
            (isWrapped and "Single Line View" or "Multiline View"),
            function()
                this.accountWide.wrapTrackedItemNames = not isWrapped
                this.RefreshItemTrackerPanel()
            end,
            MENU_ADD_OPTION_LABEL
        )

        -- 3. Open Full Settings Editor
        AddCustomMenuItem(
            "Open Tracked Items Editor...",
            function()
                this.ToggleTrackedItemsEditor()
            end,
            MENU_ADD_OPTION_LABEL
        )

        ShowMenu()
    end
end

function this.InitItemTrackerPanel()
    InventoryCompanion_ItemTrackerFloat:ClearAnchors()
    InventoryCompanion_ItemTrackerFloat:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, this.accountWide.trackerOffsetX, this.accountWide.trackerOffsetY)
    InventoryCompanion_ItemTrackerFloat:SetHandler("OnMoveStop", OnTrackerMoveStop)
    InventoryCompanion_ItemTrackerFloat:SetHandler("OnMouseUp", OnTrackerMouseUp)

    if InventoryCompanion_ItemTrackerFloatContainer then
        InventoryCompanion_ItemTrackerFloatContainer:SetHandler("OnMouseDown", function(control, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then
                InventoryCompanion_ItemTrackerFloat:StartMoving()
            end
        end)
        InventoryCompanion_ItemTrackerFloatContainer:SetHandler("OnMouseUp", OnTrackerMouseUp)
    end

    -- Edit Icon
    InventoryCompanion_ItemTrackerFloatEditIcon:SetAlpha(0.6)
    InventoryCompanion_ItemTrackerFloatEditIcon:SetHandler("OnMouseEnter", function(control) control:SetAlpha(1.0) end)
    InventoryCompanion_ItemTrackerFloatEditIcon:SetHandler("OnMouseExit", function(control) control:SetAlpha(0.6) end)
    InventoryCompanion_ItemTrackerFloatEditIcon:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            this.ToggleTrackedItemsEditor()
        end
    end)

    local settingsIcon = InventoryCompanion_ItemTrackerFloatSettingsIcon
    settingsIcon:SetAlpha(0.6)
    settingsIcon:SetHandler("OnMouseEnter", function(control) control:SetAlpha(1.0) end)
    settingsIcon:SetHandler("OnMouseExit", function(control) control:SetAlpha(0.6) end)
    settingsIcon:SetHandler("OnClicked", function()
        this.OpenSettingsPanel()
    end)

    this.RefreshItemTrackerPanel()
end

------------------------------------------------------------------
-- RenderPopulatedRows
------------------------------------------------------------------
local function HideAllTrackerRows()
    for _, row in ipairs(trackerRows) do
        row:SetHidden(true)
    end
end

local function GetOrCreateTrackerRow(rowIndex)
    local row = trackerRows[rowIndex]
    if not row then
        row = CreateControlFromVirtual("InventoryCompanion_ItemTrackerFloatRow_", GetRowsChild(), "InventoryCompanion_ItemTrackerRow_Multi_Template", rowIndex)
        trackerRows[rowIndex] = row
    end
    return row
end

local function ApplyRowAnchors(row, rowIndex, wrapped)
    row:ClearAnchors()
    if rowIndex == 1 then
        row:SetAnchor(TOPLEFT, GetRowsChild(), TOPLEFT, 0, 0)
    else
        row:SetAnchor(TOPLEFT, trackerRows[rowIndex - 1], BOTTOMLEFT, 0, wrapped and 4 or 2)
    end
end

local function GetAvailableNameWidth(row, nameControl)
    local rowWidth = row:GetWidth()
    local nameLeft = nameControl:GetLeft() - row:GetLeft()
    
    local rightControlsWidth = 0

    for i = 1, row:GetNumChildren() do
        local child = row:GetChild(i)
        if child and not child:IsHidden() and child ~= nameControl then
            local childLeft = child:GetLeft() - row:GetLeft()
            if childLeft > nameLeft then
                rightControlsWidth = rightControlsWidth + child:GetWidth()
            end
        end
    end

    local availableWidth = (rowWidth - nameLeft) - rightControlsWidth - 8
    return math.max(50, availableWidth)
end

local function GetCountText(item)
    if item.isEmpty then return "" end
    local text = this.Utils.FormatBigNumber(item.count)
    if item.showBank then
        text = (item.bankCount and this.Utils.FormatBigNumber(item.bankCount) or "err") .. " \\ " .. text
    end
    return text
end

local function PopulateBaseRow(rowIndex, itemData, wrapped)
    local row = GetOrCreateTrackerRow(rowIndex)
    ApplyRowAnchors(row, rowIndex, wrapped)
    row:SetWidth(ROW_WIDTH)
    
    local nameControl = GetControl(row, "Name")
    local iconControl = GetControl(row, "Icon")
    local expandIcon  = GetControl(row, "ExpandIcon")
    local countCtrl   = GetControl(row, "Count")
    
    if itemData.isGroup then
        local iconPath = itemData.isExpanded and "EsoUI/Art/Buttons/minus_up.dds" or "EsoUI/Art/Buttons/plus_up.dds"
        expandIcon:SetTexture(iconPath)
        expandIcon:SetDrawLayer(DL_CONTROLS)
        expandIcon:SetDrawLevel(3)
        expandIcon:SetAlpha(1.0)
        expandIcon:SetHidden(false)

        iconControl:ClearAnchors()
        iconControl:SetAnchor(TOPLEFT, row, TOPLEFT, 22, 2)
        
        nameControl:ClearAnchors()
        nameControl:SetAnchor(TOPLEFT, row, TOPLEFT, 44, 0)

        row:SetHandler("OnMouseDown", function(control, button)
            if button == MOUSE_BUTTON_INDEX_LEFT and itemData.ruleName then
                local activeRules = this.GetActiveTrackedRules()
                local ruleData = activeRules[itemData.ruleName]
                local newState = not (ruleData.display.isExpanded == true)
                this.SetRuleFlag(itemData.ruleName, "isExpanded", newState)
                this.RefreshItemTrackerPanel(newState and "expand" or "collapse", itemData.ruleName)
            end
        end)
        row:SetHandler("OnMouseUp", function(control, button)
            if button == MOUSE_BUTTON_INDEX_RIGHT then
                OnTrackerMouseUp(control, button)
            end
        end)
        row:SetMouseEnabled(true)
        row:SetHandler("OnMouseWheel", function(_, delta)
            ZO_Scroll_OnMouseWheel(GetRowsContainer(), delta)
        end)

    elseif itemData.isGroupMember then
        expandIcon:SetHidden(true)

        iconControl:ClearAnchors()
        iconControl:SetAnchor(TOPLEFT, row, TOPLEFT, 18, 2)
        
        nameControl:ClearAnchors()
        nameControl:SetAnchor(TOPLEFT, row, TOPLEFT, 40, 0)

        row:SetHandler("OnMouseDown", nil)
        row:SetMouseEnabled(false)

    else
        expandIcon:SetHidden(true)

        iconControl:ClearAnchors()
        iconControl:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 2)
        
        nameControl:ClearAnchors()
        nameControl:SetAnchor(TOPLEFT, row, TOPLEFT, 22, 0)

        row:SetHandler("OnMouseDown", nil)
        row:SetMouseEnabled(false)
    end

    iconControl:SetTexture(itemData.icon or "")
    iconControl:SetHidden(itemData.overflowCount ~= nil)
    iconControl:SetDrawLayer(DL_CONTROLS)
    iconControl:SetDrawLevel(2)
    iconControl:SetAlpha(1.0)
    if itemData.isOverflowGroup then
        iconControl:SetColor(1, 0.75, 0, 1)
    else
        iconControl:SetColor(1, 1, 1, 1)
    end
            
    nameControl:SetText(itemData.link)        
    if itemData.isOverflowGroup then
        nameControl:SetColor(1, 0.25, 0.25, 1)
    elseif itemData.isEmpty then
        nameControl:SetColor(1, 1, 1, 1)
    else
        local quality = itemData.quality or GetItemLinkQuality(itemData.link) or 0
        local colorDef = GetItemQualityColor(math.max(0, quality))
        if colorDef then
            nameControl:SetColor(colorDef:UnpackRGBA())
        end
    end

    local countText = GetCountText(itemData)
    countCtrl:SetText(countText)

    row:SetHidden(false)
    return { row = row, nameControl = nameControl, countCtrl = countCtrl, countText = countText }
end

local function CalculateMaxCountWidth(computedRows)
    local maxWidth = 0
    for _, entry in ipairs(computedRows) do
        entry.countCtrl:SetWidth(0)
        local width = entry.countCtrl:GetTextWidth()
        if entry.countText ~= "" then
            width = math.max(width, MIN_COUNT_WIDTH, #entry.countText * COUNT_WIDTH_PER_CHARACTER)
        end
        if width > maxWidth then
            maxWidth = width
        end
    end
    return maxWidth
end

local function CalculateMinAvailableNameWidth(computedRows, maxCountWidth)
    local minWidth = 99999
    for _, entry in ipairs(computedRows) do
        entry.countCtrl:SetWidth(maxCountWidth)
        local availWidth = math.max(50, GetAvailableNameWidth(entry.row, entry.nameControl))
        if availWidth < minWidth then
            minWidth = availWidth
        end
    end
    return minWidth
end

local function ApplyFinalRowLayout(computedRows, minAvailableWidth, items, wrapped)
    local height = 0
    for index, entry in ipairs(computedRows) do
        local nameControl = entry.nameControl
        local row = entry.row

        nameControl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        if wrapped and not items[index].isGroup then
            nameControl:SetDimensionConstraints(minAvailableWidth, 0, minAvailableWidth, 0)
            items[index].rowUnits = math.max(1, nameControl:GetNumLines())
        else
            nameControl:SetDimensionConstraints(minAvailableWidth, ROW_HEIGHT, minAvailableWidth, ROW_HEIGHT)
            items[index].rowUnits = 1
        end
        row:SetHeight(items[index].rowUnits * ROW_HEIGHT)
        height = height + row:GetHeight() + (index > 1 and (wrapped and 4 or 2) or 0)
    end
    return height
end

local function MeasureWrappedRows(items)
    local row = GetOrCreateTrackerRow(1)
    local name, count = GetControl(row, "Name"), GetControl(row, "Count")
    local maxCountWidth, maxIndent = 0, 22
    count:SetWidth(0)
    for _, item in ipairs(items) do
        count:SetText(GetCountText(item))
        maxCountWidth = math.max(maxCountWidth, count:GetTextWidth())
        maxIndent = math.max(maxIndent, item.isGroup and 44 or (item.isGroupMember and 40 or 22))
    end
    local width = math.max(50, ROW_WIDTH - maxIndent - maxCountWidth - 12)
    name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    name:SetDimensionConstraints(width, 0, width, 0)
    for _, item in ipairs(items) do
        if item.isGroup then
            item.rowUnits = 1
        else
            name:SetText(item.link)
            item.rowUnits = math.max(1, name:GetNumLines())
        end
    end
end

local function RenderPopulatedRows(itemsToDisplay, wrapped)
    HideAllTrackerRows()
    local computedRows = {}
    for rowIndex, itemData in ipairs(itemsToDisplay) do
        table.insert(computedRows, PopulateBaseRow(rowIndex, itemData, wrapped))
    end
    
    local maxCountWidth = CalculateMaxCountWidth(computedRows)
    local minAvailableWidth = CalculateMinAvailableNameWidth(computedRows, maxCountWidth)
    
    return ApplyFinalRowLayout(computedRows, minAvailableWidth, itemsToDisplay, wrapped)
end

------------------------------------------------------------------
-- BuildDisplayList
------------------------------------------------------------------
local function CollectSortedGroupNames(activeRules, snapshot)
    local sortedGroupNames = {}
    for ruleName, ruleData in pairs(activeRules) do
        if ruleData.display and ruleData.display.group and ruleData.display.show then
            local itemIds = snapshot.ruleIndex[ruleName]
            if itemIds and #itemIds > 0 then
                if ruleName ~= "miscellaneous" then table.insert(sortedGroupNames, ruleName) end
            end
        end
    end
    table.sort(sortedGroupNames)
    
    local miscItems = snapshot.ruleIndex["miscellaneous"]
    if miscItems and #miscItems > 0 then
        table.insert(sortedGroupNames, "miscellaneous")
    end
    
    return sortedGroupNames
end

local function ProcessGroupsAndMembers(sortedGroupNames, activeRules, snapshot, showEmpty, itemsToDisplay)
    for _, ruleName in ipairs(sortedGroupNames) do
        local ruleData = activeRules[ruleName]
        local itemIds = snapshot.ruleIndex[ruleName]
        
        local totalGroupCount = 0
        local totalGroupBankCount = 0
        local highestQuality = -1
        local bestIcon = nil
        local bestLink = ""
        local showBank = ruleData.display.bank == true

        if itemIds then
            for _, itemId in ipairs(itemIds) do
                local itemData = snapshot.items[itemId]
                local itemShowBank = showBank
                if ruleName == "miscellaneous" and snapshot.itemShowBank and snapshot.itemShowBank[itemId] ~= nil then
                    itemShowBank = snapshot.itemShowBank[itemId]
                end

                local hasRelevantStock = itemShowBank and ((itemData.bagCount + itemData.bankCount) > 0) or (itemData.bagCount > 0)
                
                if itemData and hasRelevantStock then
                    totalGroupCount = totalGroupCount + itemData.bagCount
                    if itemShowBank then
                        totalGroupBankCount = totalGroupBankCount + itemData.bankCount
                    end

                    if not bestIcon and itemData.icon and itemData.icon ~= "" then
                        bestIcon = itemData.icon
                    end

                    local quality = GetItemLinkQuality(itemData.link) or 0
                    if quality > highestQuality then
                        highestQuality = quality
                        bestIcon = itemData.icon
                        bestLink = itemData.link
                    elseif quality == highestQuality and itemData.link < bestLink then
                        bestLink = itemData.link
                        bestIcon = itemData.icon
                    end
                end
            end
        end

        if ruleName == "miscellaneous" then
            bestIcon = "EsoUI/Art/Tooltips/icon_bag.dds"
        else
            bestIcon = bestIcon or "/esoui/art/quickslots/quickslot_emptyslot.dds"
        end
		
        local effectiveGroupBankActive = showBank
        if ruleName == "miscellaneous" and itemIds then
            for _, itemId in ipairs(itemIds) do
                if snapshot.itemShowBank and snapshot.itemShowBank[itemId] then
                    effectiveGroupBankActive = true
                    break
                end
            end
        end
        local relevantCount = effectiveGroupBankActive and (totalGroupCount + totalGroupBankCount) or totalGroupCount

        if relevantCount > 0 or showEmpty then
            local colorDef = GetItemQualityColor(math.max(0, highestQuality))
            local groupTitle = ruleData and ruleData.displayName or ruleName
            local displayName = colorDef and colorDef:Colorize(groupTitle) or groupTitle

            -- Insert Group Header
            local groupHeader = {
                link = displayName,
                icon = bestIcon,
                count = totalGroupCount,
                showBank = effectiveGroupBankActive,
                bankCount = effectiveGroupBankActive and totalGroupBankCount or 0,
                sortName = groupTitle,
                isGroup = true,
                isExpanded = ruleData.display.isExpanded == true,
                ruleName = ruleName,
                quality = math.max(0, highestQuality),
            }
            table.insert(itemsToDisplay, groupHeader)

            if itemIds then
                local groupMembers = {}
                local memberCount = 0
                for _, itemId in ipairs(itemIds) do
                    local itemData = snapshot.items[itemId]
                    if itemData then
                        local itemShowBank = showBank
                        if ruleName == "miscellaneous" and snapshot.itemShowBank and snapshot.itemShowBank[itemId] ~= nil then
                            itemShowBank = snapshot.itemShowBank[itemId]
                        end

                        local memberRelCount = itemShowBank and ((itemData.bagCount + itemData.bankCount) > 0) or (itemData.bagCount > 0)
                        if memberRelCount or showEmpty then
                            memberCount = memberCount + 1
                            if memberCount <= MAX_GROUP_ITEM_ROWS then
                                table.insert(groupMembers, {
                                    link = itemData.link,
                                    icon = itemData.icon,
                                    count = itemData.bagCount,
                                    showBank = itemShowBank,
                                    bankCount = itemData.bankCount,
                                    sortName = GetItemLinkName(itemData.link) or "",
                                    isGroupMember = true,
                                    parentGroup = ruleName,
                                    itemId = itemId,
                                })
                            end
                        end
                    end
                end

                if memberCount > MAX_GROUP_ITEM_ROWS then
                    groupHeader.isOverflowGroup = true
                    groupHeader.link = groupTitle
                    groupHeader.icon = "/esoui/art/buttons/info_up.dds"
                    table.insert(itemsToDisplay, {
                        link = string.format("Your patterns matched %d items - too many to display here.",
                            memberCount),
                        isEmpty = true,
                        isGroupMember = true,
                        parentGroup = ruleName,
                        itemId = "overflow",
                        overflowCount = memberCount,
                    })
                else
                    table.sort(groupMembers, function(a, b)
                        if a.sortName == b.sortName then return a.itemId < b.itemId end
                        return a.sortName < b.sortName
                    end)
                    for _, member in ipairs(groupMembers) do
                        table.insert(itemsToDisplay, member)
                    end
                end
            end
        end
    end
end

local function CollectAllVisibleItems(snapshot, activeRules, trackedItems, showEmpty, seenVisibleIds)
    local allVisibleItems = {}

    for ruleName, ruleData in pairs(activeRules) do
        if ruleData.display and ruleData.display.show then
            local itemIds = snapshot.ruleIndex[ruleName]
            if itemIds then
                for _, itemId in ipairs(itemIds) do
                    local itemData = snapshot.items[itemId]
                    if itemData and not seenVisibleIds[itemId] then
                        local showBank = ruleData.display.bank == true
                        if ruleName == "miscellaneous" and snapshot.itemShowBank and snapshot.itemShowBank[itemId] ~= nil then
                            showBank = snapshot.itemShowBank[itemId]
                        end
                        local relevantCount = showBank and (itemData.bagCount + itemData.bankCount) or itemData.bagCount
                        if relevantCount > 0 or showEmpty then
                            seenVisibleIds[itemId] = true
                            table.insert(allVisibleItems, {
                                link = itemData.link,
                                icon = itemData.icon,
                                count = itemData.bagCount,
                                showBank = showBank,
                                bankCount = itemData.bankCount,
                                sortName = GetItemLinkName(itemData.link) or "",
                            })
                        end
                    end
                end
            end
        end
    end

    if trackedItems then
        for itemId, data in pairs(trackedItems) do
            local itemData = snapshot.items[itemId]
            if itemData and data.display and data.display.show and not seenVisibleIds[itemId] then
                local bagCount = itemData.bagCount or 0
                local bankCount = itemData.bankCount or 0
                local showBank = data.display.bank == true
                local relevantCount = showBank and (bagCount + bankCount) or bagCount

                if relevantCount > 0 or showEmpty then
                    seenVisibleIds[itemId] = true
                    table.insert(allVisibleItems, {
                        link = itemData.link,
                        icon = itemData.icon,
                        count = bagCount,
                        showBank = showBank,
                        bankCount = bankCount,
                        sortName = GetItemLinkName(itemData.link) or "",
                    })
                end
            end
        end
    end

    return allVisibleItems
end

local function FoldSingleMemberAndUngroupedIntoMisc(snapshot, activeRules, trackedItems, processedItemIds)
    snapshot.ruleIndex["miscellaneous"] = {}
    snapshot.itemShowBank = {}

    for ruleName, ruleData in pairs(activeRules) do
        if ruleName ~= "miscellaneous" and ruleData.display and not ruleData.display.group and ruleData.display.show then
            local itemIds = snapshot.ruleIndex[ruleName]
            if itemIds then
                for _, itemId in ipairs(itemIds) do
                    local itemData = snapshot.items[itemId]
                    if itemData and not processedItemIds[itemId] then
                        processedItemIds[itemId] = true
                        table.insert(snapshot.ruleIndex["miscellaneous"], itemId)
                        snapshot.itemShowBank[itemId] = ruleData.display.bank == true
                    end
                end
            end
        end
    end

    if trackedItems then
        for itemId, data in pairs(trackedItems) do
            local itemData = snapshot.items[itemId]
            if not processedItemIds[itemId] and data.display and data.display.show then
                processedItemIds[itemId] = true
                table.insert(snapshot.ruleIndex["miscellaneous"], itemId)
                snapshot.itemShowBank[itemId] = data.display.bank == true
            end
        end
    end

    for ruleName, ruleData in pairs(activeRules) do
        if ruleName ~= "miscellaneous" and ruleData.display and ruleData.display.group and ruleData.display.show then
            local itemIds = snapshot.ruleIndex[ruleName]
            if itemIds and #itemIds == 1 then
                for _, itemId in ipairs(itemIds) do
                    local itemData = snapshot.items[itemId]
                    if itemData and not processedItemIds[itemId] then
                        processedItemIds[itemId] = true
                        table.insert(snapshot.ruleIndex["miscellaneous"], itemId)
                        snapshot.itemShowBank[itemId] = ruleData.display.bank == true
                    end
                end
                snapshot.ruleIndex[ruleName] = nil
            end
        end
    end

    if activeRules["miscellaneous"] then
        activeRules["miscellaneous"].display.group = true
        activeRules["miscellaneous"].display.show = true
    end
end

local function BuildDisplayList(snapshot, activeRules, trackedItems, showEmpty)
    local seenVisibleIds = {}
    local allVisibleItems = CollectAllVisibleItems(snapshot, activeRules, trackedItems, showEmpty, seenVisibleIds)

    local threshold = (this.accountWide and this.accountWide.trackerGroupThreshold) or 8
    if #allVisibleItems < threshold then
        table.sort(allVisibleItems, function(a, b) return a.sortName < b.sortName end)
        return allVisibleItems
    end

    local itemsToDisplay = {}
    local processedItemIds = {}
    FoldSingleMemberAndUngroupedIntoMisc(snapshot, activeRules, trackedItems, processedItemIds)

    local sortedGroupNames = CollectSortedGroupNames(activeRules, snapshot)
    ProcessGroupsAndMembers(sortedGroupNames, activeRules, snapshot, showEmpty, itemsToDisplay)

    return itemsToDisplay
end

local function RuleSignature(rule)
    local parts = { tostring(rule.display.show), tostring(rule.display.bank),
        tostring(rule.display.group), tostring(rule.display.isHidden) }
    for _, pattern in ipairs(rule.patterns) do
        parts[#parts + 1] = #pattern .. ":" .. pattern
    end
    return table.concat(parts, ";")
end

local function BuildLayoutModel(items, rules)
    local model = { items = items, groups = {}, order = {}, baseRows = 0 }
    for _, item in ipairs(items) do
        if item.isGroup then
            local group = {
                expanded = item.isExpanded, members = {}, memberCount = 0,
                ruleSignature = RuleSignature(rules[item.ruleName]), signatureParts = {},
            }
            model.groups[item.ruleName] = group
            model.order[#model.order + 1] = item.ruleName
        elseif item.isGroupMember then
            local group = model.groups[item.parentGroup]
            group.members[item.itemId] = true
            group.memberCount = group.memberCount + 1
            group.signatureParts[#group.signatureParts + 1] = tostring(item.itemId) .. ":" .. tostring(item.showBank)
                .. ":" .. tostring(item.overflowCount)
        end
        if not item.isGroupMember then
            model.baseRows = model.baseRows + 1
        end
    end
    for _, name in ipairs(model.order) do
        local group = model.groups[name]
        group.signature = group.ruleSignature .. ";" .. table.concat(group.signatureParts, ";")
        group.signatureParts = nil
    end
    return model
end

local function SelectRows(model, expanded)
    local rows = {}
    for _, item in ipairs(model.items) do
        if not item.isGroupMember or expanded[item.parentGroup] then
            rows[#rows + 1] = item
        end
    end
    return rows
end

local function CountRows(model, expanded)
    local count = model.baseRows
    for _, name in ipairs(model.order) do
        if expanded[name] then
            local group = model.groups[name]
            count = count + group.memberCount
        end
    end
    return count
end

local function LayoutChanged(model, previous)
    if not previous or #model.order ~= #previous.order then return true end
    for _, name in ipairs(model.order) do
        local group, old = model.groups[name], previous.groups[name]
        if not old or group.signature ~= old.signature or group.memberCount ~= old.memberCount then return true end
        for id in pairs(group.members) do
            if not old.members[id] then return true end
        end
    end
    return false
end

local function ChooseLayout(model, previous, reason, target, budget)
    local expanded, allExpanded = {}, {}
    for _, name in ipairs(model.order) do
        expanded[name] = model.groups[name].expanded
        allExpanded[name] = true
    end

    local function Fits(selection)
        return CountRows(model, selection) <= budget
    end

    local changed = LayoutChanged(model, previous)
    local function Reintroduced(name)
        local group, old = model.groups[name], previous.groups[name]
        if not old or old.signature ~= group.signature then
            -- Membership changes during inventory bursts are growth, not configuration changes.
            if old and reason == "inventory" and old.ruleSignature == group.ruleSignature then return false end
            return true
        end
        return false
    end
    if reason ~= "expand" and reason ~= "collapse"
        and (changed or reason == "settings")
        and Fits(allExpanded) then
        expanded = allExpanded
    elseif reason ~= "expand" and reason ~= "collapse" and previous then
        -- Reintroduced/edited categories may use spare space, but may not displace others.
        for _, name in ipairs(model.order) do
            if Reintroduced(name) then
                expanded[name] = false
            end
        end
        local used = CountRows(model, expanded)
        for _, name in ipairs(model.order) do
            if Reintroduced(name) then
                local additional = model.groups[name].memberCount
                if used + additional <= budget then
                    expanded[name] = true
                    used = used + additional
                end
            end
        end
    end

    local collapsed = false
    if not Fits(expanded) and (changed or not previous or reason == "expand"
        or reason == "settings" or previous.budget ~= budget) then
        local retain = nil
        if reason == "expand" then
            retain = target
        elseif reason == "inventory" and previous then
            local candidates = 0
            for _, name in ipairs(model.order) do
                local group, old = model.groups[name], previous.groups[name]
                if old and old.expanded and expanded[name] and group.ruleSignature == old.ruleSignature
                    and group.memberCount > old.memberCount then
                    candidates = candidates + 1
                    retain = name
                end
            end
            if candidates ~= 1 then retain = nil end
        end
        for _, name in ipairs(model.order) do
            expanded[name] = name == retain
        end
        collapsed = true
    end
    return expanded, collapsed
end

local function ApplyViewport(contentHeight, budget, wrapped, previousOffset, target)
    local container = InventoryCompanion_ItemTrackerFloatContainer
    local headerHeight = InventoryCompanion_ItemTrackerFloatTitle:GetHeight() + 4
    local gap = wrapped and 4 or 2
    local maxHeight = math.max(1, math.min(budget * (ROW_HEIGHT + gap) - gap,
        GuiRoot:GetHeight() - headerHeight - 8))
    local viewportHeight = math.min(contentHeight, maxHeight)
    local scrollable = contentHeight > viewportHeight
    local contentWidth = ROW_WIDTH - (scrollable and ZO_SCROLL_BAR_WIDTH or 0)
    local rows = GetRowsContainer()
    rows:SetWidth(ROW_WIDTH)
    rows:SetHeight(viewportHeight)
    rows.scroll:ClearAnchors()
    rows.scroll:SetAnchor(TOPLEFT, rows, TOPLEFT, 0, 0)
    rows.scroll:SetAnchor(BOTTOMRIGHT, rows, BOTTOMRIGHT,
        scrollable and -ZO_SCROLL_BAR_WIDTH or 0, 0)
    GetRowsChild():SetDimensions(contentWidth, contentHeight)
    if scrollable then
        for _, row in ipairs(trackerRows) do
            if not row:IsHidden() then
                row:SetWidth(contentWidth)
                local name = GetControl(row, "Name")
                local nameWidth = name:GetWidth() - ZO_SCROLL_BAR_WIDTH
                name:SetDimensionConstraints(nameWidth, ROW_HEIGHT, nameWidth, ROW_HEIGHT)
            end
        end
    end
    container:SetWidth(ROW_WIDTH)
    container:SetHeight(headerHeight + viewportHeight)
    InventoryCompanion_ItemTrackerFloat:SetWidth(ROW_WIDTH + 20)
    InventoryCompanion_ItemTrackerFloat:SetHeight(headerHeight + viewportHeight + 8)
    ZO_Scroll_UpdateScrollBar(rows)
    local offset = math.max(0, math.min(previousOffset, contentHeight - viewportHeight))
    if target then
        local top = target:GetTop() - GetRowsChild():GetTop()
        if top < offset then offset = top end
        if top + ROW_HEIGHT > offset + viewportHeight then offset = top + ROW_HEIGHT - viewportHeight end
    end
    if scrollable then
        ZO_Scroll_ScrollAbsoluteInstantly(rows, offset)
    else
        ZO_Scroll_ResetToTop(rows)
    end
end

------------------------------------------------------------------
-- Editor Collision & Repositioning Handling
------------------------------------------------------------------

function this.AdjustTrackerPositionForEditor(editorWindow, alwaysMove, xOffset, yOffset)
	xOffset = xOffset or 0
    yOffset = yOffset or 0
    if not InventoryCompanion_ItemTrackerFloat or InventoryCompanion_ItemTrackerFloat:IsHidden() then
        return
    end

    if not editorWindow or editorWindow:IsHidden() then
        return
    end

    -- Save original position once when entering edit mode if not already saved
    if not originalTrackerPos then
        originalTrackerPos = {
            left = InventoryCompanion_ItemTrackerFloat:GetLeft(),
            top = InventoryCompanion_ItemTrackerFloat:GetTop(),
        }
    end

    local tracker = InventoryCompanion_ItemTrackerFloat
    local tLeft, tTop, tWidth, tHeight = tracker:GetLeft(), tracker:GetTop(), tracker:GetWidth(), tracker:GetHeight()
    local eLeft, eTop, eWidth, eHeight = editorWindow:GetLeft(), editorWindow:GetTop(), editorWindow:GetWidth(), editorWindow:GetHeight()

    -- Check for collision/overlap
    local overlaps = not (tLeft + tWidth < eLeft or tLeft > eLeft + eWidth or tTop + tHeight < eTop or tTop > eTop + eHeight)

    if overlaps or alwaysMove then
        local screenWidth, screenHeight = GuiRoot:GetWidth(), GuiRoot:GetHeight()
        local newTop = eTop

        -- Calculate potential left positions for both sides
        local rightSideLeft = eLeft + eWidth
        local leftSideLeft = eLeft - tWidth

        -- Evaluate screen boundary constraints for both sides
        local rightValid = (rightSideLeft + tWidth <= screenWidth) and (rightSideLeft >= 0)
        local leftValid = (leftSideLeft >= 0) and (leftSideLeft + tWidth <= screenWidth)

        local newLeft = rightSideLeft -- Default fallback

        if rightValid and leftValid then
            -- Both sides fit on screen: choose the one with the shortest distance to move
            local distRight = math.abs(rightSideLeft - tLeft)
            local distLeft = math.abs(leftSideLeft - tLeft)
            if distLeft < distRight then
                newLeft = leftSideLeft
            else
                newLeft = rightSideLeft
            end
        elseif leftValid then
            -- Only the left side fits cleanly
            newLeft = leftSideLeft
        elseif rightValid then
            -- Only the right side fits cleanly
            newLeft = rightSideLeft
        else
            -- Fallback: clamp whichever side is closer if the screen is too narrow overall
            if math.abs(leftSideLeft - tLeft) < math.abs(rightSideLeft - tLeft) then
                newLeft = math.max(0, math.min(leftSideLeft, screenWidth - tWidth))
            else
                newLeft = math.max(0, math.min(rightSideLeft, screenWidth - tWidth))
            end
        end

        -- If too tall / exceeds bottom screen bounds, move it up
        if newTop + tHeight > screenHeight then
            newTop = math.max(0, screenHeight - tHeight)
        end

        tracker:ClearAnchors()
        tracker:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, newLeft + xOffset, newTop + yOffset)
    end
end

local activeInteractionWindows = {
    { scene = "inventory",      control = ZO_PlayerInventory },
    { scene = "bank",           control = ZO_PlayerBank },
    { scene = "houseBank",      control = ZO_HouseBank },
    { scene = "guildBank",      control = ZO_GuildBank },
    { scene = "store",          control = ZO_PlayerInventory }, -- Store/Merchant uses inventory frame for positioning bounds
    { scene = "store_keyboard", control = ZO_PlayerInventory },
    { scene = "fence_keyboard", control = ZO_PlayerInventory },
}

local function GetActiveInteractionWindow()
    for _, entry in ipairs(activeInteractionWindows) do
        if SCENE_MANAGER:IsShowing(entry.scene) then
            if entry.control and not entry.control:IsHidden() then
                return entry.control
            end
        end
    end
    return nil
end

function this.AdjustTrackerPositionForInteraction()
    if not InventoryCompanion_ItemTrackerFloat or InventoryCompanion_ItemTrackerFloat:IsHidden() then
        return
    end

    local interactionWindow = GetActiveInteractionWindow()
    if interactionWindow then
        this.AdjustTrackerPositionForEditor(interactionWindow, true,-38,0)
    end
end

function this.RestoreTrackerPosition()
    if originalTrackerPos and InventoryCompanion_ItemTrackerFloat then
        InventoryCompanion_ItemTrackerFloat:ClearAnchors()
        InventoryCompanion_ItemTrackerFloat:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, originalTrackerPos.left, originalTrackerPos.top)
        originalTrackerPos = nil
    end
end


------------------------------------------------------------------
-- Refresh Panel
------------------------------------------------------------------
local function GetTrackerCoordinates()
    local oldLeft = InventoryCompanion_ItemTrackerFloat:GetLeft()
    local oldTop = InventoryCompanion_ItemTrackerFloat:GetTop()
    if not oldLeft or oldLeft <= 0 then oldLeft = this.accountWide.trackerOffsetX or 50 end
    if not oldTop or oldTop <= 0 then oldTop = this.accountWide.trackerOffsetY or 50 end
    return oldLeft, oldTop
end

local function GetTrackerDisplayList()
    local trackedItems = this.GetActiveTrackedItems()
    local activeRules = this.GetActiveTrackedRules()
    local showEmpty = this.accountWide.showEmptyTrackedItems ~= false

    local bagIdList = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
    if IsESOPlusSubscriber() then
        table.insert(bagIdList, BAG_VIRTUAL)
    end

    local snapshot = this.GetMasterItemList(trackedItems, activeRules, bagIdList)
    return BuildDisplayList(snapshot, activeRules, trackedItems, showEmpty), activeRules
end

local function ApplyBoundedPosition(oldLeft, oldTop)
    InventoryCompanion_ItemTrackerFloat:ClearAnchors()
    InventoryCompanion_ItemTrackerFloat:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, oldLeft, oldTop)
    InventoryCompanion_ItemTrackerFloat:SetHidden(false)

    local newHeight = InventoryCompanion_ItemTrackerFloat:GetHeight()
    local bottomLimit = GuiRoot:GetHeight()
    local finalTop = oldTop

    if (oldTop + newHeight) > bottomLimit then
        finalTop = math.max(0, bottomLimit - newHeight)
    end

    InventoryCompanion_ItemTrackerFloat:ClearAnchors()
    InventoryCompanion_ItemTrackerFloat:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, oldLeft, finalTop)
end

function this.SetItemTrackerPanelVisible(visible)
    assert(type(visible) == "boolean", "Tracker visibility must be a boolean")
    this.accountWide.showTrackedItemsPanel = visible
    this.UpdateEventRegistry()
    this.RefreshItemTrackerPanel()
end

function this.ToggleItemTrackerPanel()
    this.SetItemTrackerPanelVisible(this.accountWide.showTrackedItemsPanel == false)
end

function this.RefreshItemTrackerPanel(reason, targetGroup)
    local titleSize = this.accountWide.trackerTitleSize
    InventoryCompanion_ItemTrackerFloatTitle:SetFont(string.format("%s|%d|soft-shadow-thin",
        ZoFontGame:GetFontInfo(), titleSize))
    InventoryCompanion_ItemTrackerFloatEditIcon:SetDimensions(titleSize, titleSize)
    InventoryCompanion_ItemTrackerFloatSettingsIcon:SetDimensions(titleSize, titleSize)
    if this.accountWide.showTrackedItemsPanel == false then
        InventoryCompanion_ItemTrackerFloat:SetHidden(true)
        return
    end

    local oldLeft, oldTop = GetTrackerCoordinates()
    HideAllTrackerRows()

    local context, revision = this.GetTrackerContext()
    local contextChanged = not previousLayout or previousLayout.context ~= context
        or previousLayout.revision ~= revision
    if contextChanged then previousLayout = nil end
    local _, scrollOffset = GetRowsContainer().scroll:GetScrollOffsets()
    if contextChanged then scrollOffset = 0 end
    local items, rules = GetTrackerDisplayList()
    if #items == 0 then
        items = { { link = "|c888888No tracked items in backpack|r", count = 0,
            icon = "EsoUI/Art/Buttons/edit_up.dds", isEmpty = true } }
    end
    local budget = math.min(this.accountWide.trackerMaxRows,
        math.max(1, math.floor((GuiRoot:GetHeight() - InventoryCompanion_ItemTrackerFloatTitle:GetHeight() - 12) / 24)))
    local model = BuildLayoutModel(items, rules)
    -- Single-line row totals are a lower bound: an overflowing selection cannot fit wrapped.
    local expanded, collapsed = ChooseLayout(model, previousLayout, reason, targetGroup, budget)
    local selected = SelectRows(model, expanded)
    local wrapped = false
    if this.accountWide.wrapTrackedItemNames == true and not collapsed and #selected <= budget then
        MeasureWrappedRows(selected)
        local units = 0
        for _, item in ipairs(selected) do units = units + item.rowUnits end
        wrapped = units <= budget
    end
    for _, name in ipairs(model.order) do
        local group = model.groups[name]
        if expanded[name] ~= group.expanded then
            this.SetRuleFlag(name, "isExpanded", expanded[name])
        end
        group.expanded = expanded[name]
    end
    local contentHeight = RenderPopulatedRows(selected, wrapped)
    local target = nil
    for index, item in ipairs(selected) do
        if item.isGroup then
            GetControl(trackerRows[index], "ExpandIcon"):SetTexture(expanded[item.ruleName]
                and "EsoUI/Art/Buttons/minus_up.dds" or "EsoUI/Art/Buttons/plus_up.dds")
            if reason == "expand" and item.ruleName == targetGroup then target = trackerRows[index] end
        end
    end
    ApplyViewport(contentHeight, budget, wrapped, scrollOffset, target)
    model.context, model.revision, model.budget = context, revision, budget
    previousLayout = model
    ApplyBoundedPosition(oldLeft, oldTop)
end