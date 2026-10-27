InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local trackerRows = {}
local originalTrackerPos = nil

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

local function RenderEmptyState()
    local row = trackerRows[1]
    if not row then
        row = CreateControlFromVirtual("InventoryCompanion_ItemTrackerFloatRow_", InventoryCompanion_ItemTrackerFloatContainer, "InventoryCompanion_ItemTrackerRow_Multi_Template", 1)
        table.insert(trackerRows, row)
    end
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, InventoryCompanion_ItemTrackerFloatTitle, BOTTOMLEFT, 0, 4)
    
    local iconControl = GetControl(row, "Icon")
    iconControl:SetTexture("EsoUI/Art/Buttons/edit_up.dds")

    GetControl(row, "Name"):SetText("|c888888No tracked items in backpack|r")    
    GetControl(row, "Count"):SetText("")
    row:SetHidden(false)
end

local function GetOrCreateTrackerRow(rowIndex)
    local row = trackerRows[rowIndex]
    if not row then
        row = CreateControlFromVirtual("InventoryCompanion_ItemTrackerFloatRow_", InventoryCompanion_ItemTrackerFloatContainer, "InventoryCompanion_ItemTrackerRow_Multi_Template", rowIndex)
        trackerRows[rowIndex] = row
    end
    return row
end

local function ApplyRowAnchors(row, rowIndex)
    row:ClearAnchors()
    if rowIndex == 1 then
        row:SetAnchor(TOPLEFT, InventoryCompanion_ItemTrackerFloatTitle, BOTTOMLEFT, 0, 4)
    else
        row:SetAnchor(TOPLEFT, trackerRows[rowIndex - 1], BOTTOMLEFT, 0, (this.accountWide.wrapTrackedItemNames == true) and 4 or 2)
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

local function PopulateBaseRow(rowIndex, itemData)
    local row = GetOrCreateTrackerRow(rowIndex)
    ApplyRowAnchors(row, rowIndex)
    
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
                if ruleData then
                    local newState = not (ruleData.display.isExpanded == true)
                    this.SetRuleFlag(itemData.ruleName, "isExpanded", newState)
                    this.RefreshItemTrackerPanel()
                end
            end
        end)
        row:SetHandler("OnMouseUp", function(control, button)
            if button == MOUSE_BUTTON_INDEX_RIGHT then
                OnTrackerMouseUp(control, button)
            end
        end)
        row:SetMouseEnabled(true)

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
    iconControl:SetDrawLayer(DL_CONTROLS)
    iconControl:SetDrawLevel(2)
    iconControl:SetAlpha(1.0)
            
    nameControl:SetText(itemData.link)        

    local countText = this.Utils.FormatBigNumber(itemData.count)
    
    if itemData.showBank then
        if itemData.bankCount then        
            countText = this.Utils.FormatBigNumber(itemData.bankCount) .. " \\ " .. countText
        else
            countText = "err \\ " .. countText
        end
    end
    countCtrl:SetText(countText)

    row:SetHidden(false)
    return { row = row, nameControl = nameControl, countCtrl = countCtrl }
end

local function CalculateMaxCountWidth(computedRows)
    local maxWidth = 0
    for _, entry in ipairs(computedRows) do
        entry.countCtrl:SetWidth(0)
        local width = entry.countCtrl:GetTextWidth()
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

local function ApplyFinalRowLayout(computedRows, minAvailableWidth)
    for _, entry in ipairs(computedRows) do
        local nameControl = entry.nameControl
        local row = entry.row

        if this.accountWide.wrapTrackedItemNames == true then
            nameControl:SetDimensionConstraints(minAvailableWidth, 0, minAvailableWidth, 0)
            row:SetHeight(math.max(nameControl:GetTextHeight(), 22))
        else
            nameControl:SetDimensionConstraints(minAvailableWidth, 22, minAvailableWidth, 22)
            row:SetHeight(22)
        end
    end
end

local function RenderPopulatedRows(itemsToDisplay)
    HideAllTrackerRows()
    
    local computedRows = {}
    for rowIndex, itemData in ipairs(itemsToDisplay) do
        table.insert(computedRows, PopulateBaseRow(rowIndex, itemData))
    end
    
    local maxCountWidth = CalculateMaxCountWidth(computedRows)
    local minAvailableWidth = CalculateMinAvailableNameWidth(computedRows, maxCountWidth)
    
    ApplyFinalRowLayout(computedRows, minAvailableWidth)
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
            table.insert(itemsToDisplay, {
                link = displayName,
                icon = bestIcon,
                count = totalGroupCount,
                showBank = effectiveGroupBankActive,
                bankCount = effectiveGroupBankActive and totalGroupBankCount or 0,
                sortName = groupTitle,
                isGroup = true,
                isExpanded = ruleData.display.isExpanded == true,
                ruleName = ruleName,
            })

            -- Insert Group Members if Expanded
            if ruleData.display.isExpanded == true and itemIds then
                local groupMembers = {}
                for _, itemId in ipairs(itemIds) do
                    local itemData = snapshot.items[itemId]
                    if itemData then
                        local itemShowBank = showBank
                        if ruleName == "miscellaneous" and snapshot.itemShowBank and snapshot.itemShowBank[itemId] ~= nil then
                            itemShowBank = snapshot.itemShowBank[itemId]
                        end

                        local memberRelCount = itemShowBank and ((itemData.bagCount + itemData.bankCount) > 0) or (itemData.bagCount > 0)
                        if memberRelCount or showEmpty then
                            table.insert(groupMembers, {
                                link = itemData.link,
                                icon = itemData.icon,
                                count = itemData.bagCount,
                                showBank = itemShowBank,
                                bankCount = itemData.bankCount,
                                sortName = GetItemLinkName(itemData.link) or "",
                                isGroupMember = true,
                                parentGroup = ruleName,
                            })
                        end
                    end
                end

                table.sort(groupMembers, function(a, b) return a.sortName < b.sortName end)
                for _, member in ipairs(groupMembers) do
                    table.insert(itemsToDisplay, member)
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
    return BuildDisplayList(snapshot, activeRules, trackedItems, showEmpty)
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

function this.RefreshItemTrackerPanel()
    if this.accountWide.showTrackedItemsPanel == false then
        InventoryCompanion_ItemTrackerFloat:SetHidden(true)
        return
    end

    local oldLeft, oldTop = GetTrackerCoordinates()
    HideAllTrackerRows()

    local itemsToDisplay = GetTrackerDisplayList()

    if #itemsToDisplay == 0 then
        RenderEmptyState()
    else
        RenderPopulatedRows(itemsToDisplay)
    end
    
    ApplyBoundedPosition(oldLeft, oldTop)
end