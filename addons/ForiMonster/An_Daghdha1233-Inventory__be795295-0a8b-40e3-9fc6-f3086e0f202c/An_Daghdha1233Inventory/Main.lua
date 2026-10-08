-- An_Daghdha1233 Inventory: controller scene and player-driven actions.
An_Daghdha1233Inventory = An_Daghdha1233Inventory or {}
local Addon = An_Daghdha1233Inventory

Addon.NAME = "An_Daghdha1233Inventory"
Addon.DISPLAY_NAME = "An_Daghdha1233 Inventory"
Addon.SCENE_NAME = "An_Daghdha1233InventoryScene"

local SAVE_VERSION = 1
local SAVE_DEFAULTS = { category = "all", gearFilter = "all" }
local CATEGORIES = { "all", "gear", "materials", "supplies", "slottable", "quest" }
local GEAR_FILTERS = { "all", "heavy", "medium", "light", "weapons", "jewelry", "other" }
-- ESO's eight quickslot action slots run counterclockwise from the lower
-- right. Keep D-pad movement spatial so the picker matches the native wheel.
local QUICK_SLOT_NEIGHBORS = {
    left = { [1] = 8, [2] = 6, [3] = 4, [4] = 5, [8] = 7 },
    right = { [4] = 3, [5] = 4, [6] = 2, [7] = 8, [8] = 1 },
    up = { [1] = 2, [2] = 3, [6] = 5, [7] = 6, [8] = 4 },
    down = { [2] = 1, [3] = 2, [4] = 8, [5] = 6, [6] = 7 },
}
local BAG_EVENT = "An_Daghdha1233Inventory_BagUpdate"
local FULL_EVENT = "An_Daghdha1233Inventory_FullUpdate"
local WEAPON_EVENT = "An_Daghdha1233Inventory_WeaponUpdate"
local LOAD_EVENT = "An_Daghdha1233Inventory_Load"
local UPDATE_DELAY_MS = 45
local EQUIP_PENDING_TIMEOUT_MS = 1500
local USE_PENDING_TIMEOUT_MS = 1500

local function GetDetailStickMagnitude(direction)
    if direction == MOVEMENT_CONTROLLER_DIRECTION_VERTICAL then
        return DIRECTIONAL_INPUT:GetY(ZO_DI_RIGHT_STICK_NO_KEYBOARD, ZO_DI_RIGHT_STICK)
    end
    return 0
end

local function SameId(left, right)
    if left == nil or right == nil then
        return false
    end
    return AreId64sEqual(left, right)
end

local function SameItem(left, right)
    if not left or not right then return false end
    if left.isQuest or right.isQuest then
        return left.isQuest and right.isQuest and left.questIndex == right.questIndex
            and left.questItemId == right.questItemId
    end
    return left.bagId == right.bagId and SameId(left.uniqueId, right.uniqueId)
end

local function FindDestination(destinations, equipSlot)
    for index, destination in ipairs(destinations) do
        if destination.equipSlot == equipSlot then
            return index
        end
    end
    return nil
end

function Addon:GetFocusedItem()
    if self.pane ~= "bag" then
        return nil
    end
    return self.items[self.selectedIndex]
end

function Addon:GetDestination()
    return self.destinations[self.destinationIndex]
end

function Addon:RefreshSelection(preserveDestination)
    local item = self:GetFocusedItem()
    local previousSlot = preserveDestination and self:GetDestination() and self:GetDestination().equipSlot or nil
    self.destinations = item and self.Data.GetDestinations(item) or {}
    self.destinationIndex = FindDestination(self.destinations, previousSlot) or 1
    local destination = self:GetDestination()
    local comparison = item and destination and self.Data.DescribeComparison(item, destination) or nil
    self.view:Render(self.items, self.equipped, self.selectedIndex, self.pane,
        self.equippedIndex, destination, comparison, self.savedVars.category,
        self.inventoryRevision or 0, self.categoryCounts, self.savedVars.gearFilter)
    if self.tooltipVisible then
        self:RefreshNativeTooltip()
    end
    if self.keybindsActive then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds)
    end
end

function Addon:RefreshInventory()
    self.inventoryRevision = (self.inventoryRevision or 0) + 1
    local oldItem = self.items and self.items[self.selectedIndex]
    local oldDestination = self:GetDestination()
    local oldSlot = oldDestination and oldDestination.equipSlot

    local allItems = self.Data.CollectBag()
    self.categoryCounts = { all = #allItems, gear = 0, materials = 0,
        supplies = 0, slottable = 0, quest = 0 }
    self.items = {}
    for _, item in ipairs(allItems) do
        local category = self.Data.GetCategory(item)
        self.categoryCounts[category] = self.categoryCounts[category] + 1
        if self.Data.IsSlottable(item) then
            self.categoryCounts.slottable = self.categoryCounts.slottable + 1
        end
        local show = self.savedVars.category == "all" or self.savedVars.category == category
            or (self.savedVars.category == "slottable" and self.Data.IsSlottable(item))
        if show and self.savedVars.category == "gear" and self.savedVars.gearFilter ~= "all" then
            show = self.Data.GetGearGroup(item) == self.savedVars.gearFilter
        end
        if show then
            self.items[#self.items + 1] = item
        end
    end
    local questItems = self.Data.CollectQuest()
    self.categoryCounts.quest = #questItems
    if self.savedVars.category == "quest" then
        self.items = questItems
    end
    self.equipped = self.Data.GetEquipped()
    if self.pendingEquip then
        for _, item in ipairs(self.equipped) do
            if item.equipSlot == self.pendingEquip.equipSlot
                and SameId(item.uniqueId, self.pendingEquip.uniqueId) then
                self.pendingEquip = nil
                break
            end
        end
    end
    if self.pendingUse then
        local fresh = self.Data.ValidateItem(self.pendingUse)
        if not fresh or (fresh.stackCount or 1) < (self.pendingUse.stackCount or 1) then
            self.pendingUse = nil
        end
    end

    local selectedIndex
    if oldItem then
        for index, item in ipairs(self.items) do
            if SameItem(item, oldItem) then
                selectedIndex = index
                break
            end
        end
    end
    self.selectedIndex = selectedIndex or math.min(self.selectedIndex or 1, #self.items)
    if self.selectedIndex < 1 then
        self.selectedIndex = 1
    end
    self.equippedIndex = math.min(self.equippedIndex or 1, self.view:GetEquipmentSlotCount())
    self.destinations = self:GetFocusedItem() and self.Data.GetDestinations(self:GetFocusedItem()) or {}
    self.destinationIndex = FindDestination(self.destinations, oldSlot) or 1
    self:RefreshSelection(true)
end

function Addon:QueueRefresh()
    local epoch = self.sceneEpoch
    if self.refreshQueuedEpoch == epoch then
        return
    end
    self.refreshQueuedEpoch = epoch
    zo_callLater(function()
        -- A timer from a previous scene must not clear a newer scene's queue.
        if self.refreshQueuedEpoch ~= epoch then
            return
        end
        self.refreshQueuedEpoch = nil
        if self.sceneEpoch == epoch and self.scene:IsShowing() then
            self:RefreshInventory()
        end
    end, UPDATE_DELAY_MS)
end

function Addon:RefreshNativeTooltip()
    if not GAMEPAD_TOOLTIPS then
        return
    end
    GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
    local item = self:GetFocusedItem()
    self.view:SetNativeTooltipVisible(self.tooltipVisible and item ~= nil)
    if self.tooltipVisible and item then
        if item.isQuest then
            GAMEPAD_TOOLTIPS:LayoutQuestItem(GAMEPAD_RIGHT_TOOLTIP, item.questItemId)
            return
        end
        local fresh = self.Data.ValidateItem(item)
        if not fresh and item.uniqueId == nil and HasItemInSlot(item.bagId, item.slotIndex)
            and GetItemLink(item.bagId, item.slotIndex) == item.itemLink then
            fresh = item
        end
        if fresh then
            GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_RIGHT_TOOLTIP, fresh.bagId, fresh.slotIndex)
        end
    end
end

function Addon:Move(moveX, moveY)
    if self.quickslotMode then
        local direction = moveX == MOVEMENT_CONTROLLER_MOVE_PREVIOUS and "left"
            or moveX == MOVEMENT_CONTROLLER_MOVE_NEXT and "right"
            or moveY == MOVEMENT_CONTROLLER_MOVE_PREVIOUS and "up"
            or moveY == MOVEMENT_CONTROLLER_MOVE_NEXT and "down" or nil
        local nextIndex = direction and QUICK_SLOT_NEIGHBORS[direction][self.quickslotIndex]
        if nextIndex then
            self.quickslotIndex = nextIndex
            self.view:ShowQuickslotPicker(true, self.quickslotIndex, self.quickslotItem)
            if self.keybindsActive then KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds) end
            PlaySound(SOUNDS.GAMEPAD_MENU_RIGHT)
        end
        return
    end
    if self.pane == "gearFilters" then
        if moveX == MOVEMENT_CONTROLLER_MOVE_PREVIOUS then
            self:CycleGearFilter(-1)
            return
        elseif moveX == MOVEMENT_CONTROLLER_MOVE_NEXT then
            self:CycleGearFilter(1)
            return
        elseif moveY == MOVEMENT_CONTROLLER_MOVE_PREVIOUS then
            self.pane = "equipment"
        elseif moveY == MOVEMENT_CONTROLLER_MOVE_NEXT and #self.items > 0 then
            self.pane = "bag"
        end
    elseif self.pane == "bag" then
        local count = #self.items
        if count == 0 then
            if self.savedVars.category == "gear" and moveY == MOVEMENT_CONTROLLER_MOVE_PREVIOUS then
                self.pane = "gearFilters"
                self:RefreshSelection(false)
            end
            return
        end
        local columns = self.view:GetColumns()
        local nextIndex = self.selectedIndex
        if moveX == MOVEMENT_CONTROLLER_MOVE_PREVIOUS then
            if ((nextIndex - 1) % columns) > 0 then
                nextIndex = nextIndex - 1
            end
        elseif moveX == MOVEMENT_CONTROLLER_MOVE_NEXT
            and ((nextIndex - 1) % columns) < columns - 1 and nextIndex < count then
            nextIndex = nextIndex + 1
        end
        if moveY == MOVEMENT_CONTROLLER_MOVE_PREVIOUS then
            if nextIndex <= columns then
                if self.savedVars.category == "gear" then
                    self.pane = "gearFilters"
                else
                    self.pane = "equipment"
                    self.equippedIndex = self.view:GetEquipmentEntryForBagColumn(
                        ((nextIndex - 1) % columns) + 1)
                end
            else
                nextIndex = math.max(1, nextIndex - columns)
            end
        elseif moveY == MOVEMENT_CONTROLLER_MOVE_NEXT then
            nextIndex = math.min(count, nextIndex + columns)
        end
        if self.pane == "bag" then
            self.selectedIndex = nextIndex
        end
    else
        local directionX = moveX == MOVEMENT_CONTROLLER_MOVE_PREVIOUS and -1
            or moveX == MOVEMENT_CONTROLLER_MOVE_NEXT and 1 or 0
        local directionY = moveY == MOVEMENT_CONTROLLER_MOVE_PREVIOUS and -1
            or moveY == MOVEMENT_CONTROLLER_MOVE_NEXT and 1 or 0
        local neighbor = self.view:GetEquipmentNeighbor(self.equippedIndex, directionX, directionY)
        if neighbor then
            self.equippedIndex = neighbor
        elseif directionY > 0 then
            if self.savedVars.category == "gear" then
                self.pane = "gearFilters"
            elseif #self.items > 0 then
                self.pane = "bag"
                self.selectedIndex = self.view:GetBagEntryForEquipment(self.equippedIndex, #self.items)
            end
        end
    end
    self:RefreshSelection(false)
    PlaySound(SOUNDS.GAMEPAD_MENU_DOWN)
end

function Addon:UpdateDirectionalInput()
    -- UI shortcut actions navigate the grid. Consume left-stick input so it
    -- cannot reach the world while this custom scene is active.
    DIRECTIONAL_INPUT:GetX(ZO_DI_LEFT_STICK_NO_KEYBOARD, ZO_DI_LEFT_STICK)
    DIRECTIONAL_INPUT:GetY(ZO_DI_LEFT_STICK_NO_KEYBOARD, ZO_DI_LEFT_STICK)
    local detailMove = self.detailMovementController:CheckMovement()
    if detailMove ~= MOVEMENT_CONTROLLER_NO_CHANGE then
        self.view:ScrollDetails(detailMove)
    end
end

function Addon:CycleDestination(direction)
    if self.pane ~= "bag" or #self.destinations < 2 then
        return
    end
    self.destinationIndex = ((self.destinationIndex - 1 + direction) % #self.destinations) + 1
    self:RefreshSelection(true)
    PlaySound(SOUNDS.GAMEPAD_MENU_RIGHT)
end

function Addon:CycleCategory(direction)
    local index = 1
    for candidateIndex, category in ipairs(CATEGORIES) do
        if category == self.savedVars.category then
            index = candidateIndex
            break
        end
    end
    self.savedVars.category = CATEGORIES[((index - 1 + direction) % #CATEGORIES) + 1]
    self.selectedIndex = 1
    self.pane = "bag"
    self:RefreshInventory()
    PlaySound(SOUNDS.GAMEPAD_MENU_RIGHT)
end

function Addon:CycleGearFilter(direction)
    if self.savedVars.category ~= "gear" then return end
    local index = 1
    for candidateIndex, filter in ipairs(GEAR_FILTERS) do
        if filter == self.savedVars.gearFilter then index = candidateIndex break end
    end
    self.savedVars.gearFilter = GEAR_FILTERS[((index - 1 + direction) % #GEAR_FILTERS) + 1]
    self.selectedIndex = 1
    self.pane = "gearFilters"
    self:RefreshInventory()
    PlaySound(SOUNDS.GAMEPAD_MENU_RIGHT)
end

function Addon:OpenNativeInventory()
    self.tooltipVisible = false
    self:RefreshNativeTooltip()
    if not self.Integration.OpenNativeInventory() then
        self.view:SetStatus("Native inventory is unavailable here.")
    elseif type(ZO_Alert) == "function" and UI_ALERT_CATEGORY_ALERT ~= nil then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil,
            "Press Inventory again for ESO's standard view. Map Options > Inventory returns here.")
    end
end

function Addon:DoEquip(itemRef, equipSlot)
    local fresh = self.Data.ValidateItem(itemRef)
    if not fresh or fresh.bagId ~= BAG_BACKPACK then
        self.view:SetStatus("The selected item changed. Choose it again.")
        self:QueueRefresh()
        return
    end
    local currentItem = self:GetFocusedItem()
    if not currentItem or not SameId(currentItem.uniqueId, fresh.uniqueId) then
        self.view:SetStatus("Selection changed. Choose the item again.")
        return
    end
    local destinations = self.Data.GetDestinations(fresh)
    local currentDestinationIndex = FindDestination(destinations, equipSlot)
    if not currentDestinationIndex or not destinations[currentDestinationIndex].canEquip then
        self.view:SetStatus("That equipment slot is no longer valid.")
        self:QueueRefresh()
        return
    end
    if type(RequestEquipItem) ~= "function" then
        self.view:SetStatus("Use the native inventory to equip this item.")
        return
    end
    if self.pendingEquip or self.pendingUse then
        return
    end
    self.nextEquipToken = (self.nextEquipToken or 0) + 1
    local token = self.nextEquipToken
    self.pendingEquip = { uniqueId = fresh.uniqueId, equipSlot = equipSlot, token = token }
    RequestEquipItem(fresh.bagId, fresh.slotIndex, BAG_WORN, equipSlot)
    if self.keybindsActive then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds)
    end
    zo_callLater(function()
        if self.pendingEquip and self.pendingEquip.token == token then
            self.pendingEquip = nil
            if self.keybindsActive then
                KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds)
            end
        end
    end, EQUIP_PENDING_TIMEOUT_MS)
    self:QueueRefresh()
end

function Addon:EquipFocused()
    local item = self:GetFocusedItem()
    local destination = self:GetDestination()
    if not item or not destination or not destination.canEquip then
        return
    end
    local fresh = self.Data.ValidateItem(item)
    if not fresh then
        self.view:SetStatus("The selected item changed. Choose it again.")
        self:QueueRefresh()
        return
    end
    local equipSlot = destination.equipSlot
    local function ConfirmedEquip()
        self:DoEquip(fresh, equipSlot)
    end
    if ZO_InventorySlot_WillItemBecomeBoundOnEquip(fresh.bagId, fresh.slotIndex) then
        local color = GetItemQualityColor(GetItemDisplayQuality(fresh.bagId, fresh.slotIndex))
        local displayName = color:Colorize(zo_strformat(SI_TOOLTIP_ITEM_NAME,
            GetItemName(fresh.bagId, fresh.slotIndex)))
        ZO_Dialogs_ShowPlatformDialog("CONFIRM_EQUIP_ITEM",
            { onAcceptCallback = ConfirmedEquip },
            { mainTextParams = { displayName } })
    else
        ConfirmedEquip()
    end
end

function Addon:OpenQuickslotPicker()
    local item = self:GetFocusedItem()
    local fresh = item and self.Data.ValidateItem(item)
    if not fresh or not self.Data.IsSlottable(fresh) then
        self.view:SetStatus("That item changed or cannot be assigned. Choose it again.")
        self:QueueRefresh()
        return
    end
    self.tooltipVisible = false
    self:RefreshNativeTooltip()
    if type(CallSecureProtected) ~= "function" or HOTBAR_CATEGORY_QUICKSLOT_WHEEL == nil then
        self.view:SetStatus("Quickslot assignment is unavailable here.")
        return
    end
    self.quickslotMode = true
    self.quickslotItem = fresh
    self.quickslotIndex = 4
    self.view:ShowQuickslotPicker(true, self.quickslotIndex, fresh)
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds)
end

function Addon:CloseQuickslotPicker()
    self.quickslotMode = false
    self.quickslotItem = nil
    self.view:ShowQuickslotPicker(false)
    if self.keybindsActive then KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds) end
end

function Addon:AssignSelectedQuickslot()
    if not self.quickslotMode then return end
    local fresh = self.Data.ValidateItem(self.quickslotItem)
    if not fresh or not self.Data.IsSlottable(fresh) then
        self:CloseQuickslotPicker()
        self.view:SetStatus("That item changed before assignment. Choose it again.")
        self:QueueRefresh()
        return
    end
    local assigned = CallSecureProtected("SelectSlotItem", fresh.bagId,
        fresh.slotIndex, self.quickslotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    if assigned then
        local slot = self.quickslotIndex
        self:CloseQuickslotPicker()
        self.view:SetStatus("Assigned " .. fresh.name .. " to quickslot " .. slot .. ".")
    else
        self.view:SetStatus("ESO blocked this assignment. No quickslot was changed.")
    end
end

function Addon:OpenMap()
    self.tooltipVisible = false
    self:RefreshNativeTooltip()
    if not self.Integration.OpenMap() then
        self.view:SetStatus("Map is unavailable here.")
    end
end

function Addon:UseFocused()
    if self.pendingEquip or self.pendingUse then
        return
    end
    local item = self:GetFocusedItem()
    local action = item and self.Data.GetUseAction(item)
    if not action then
        self.view:SetStatus("That item cannot be used right now.")
        self:QueueRefresh()
        return
    end
    if type(CallSecureProtected) ~= "function" then
        self.view:SetStatus("Use the native inventory for this item.")
        return
    end
    if type(SCENE_MANAGER.ShowBaseScene) ~= "function" then
        self.view:SetStatus("Use the native inventory for this item.")
        return
    end

    self.nextUseToken = (self.nextUseToken or 0) + 1
    local token = self.nextUseToken
    self.pendingUse = {
        bagId = item.bagId, slotIndex = item.slotIndex,
        uniqueId = item.uniqueId, stackCount = item.stackCount, token = token,
        protectedFunction = action.protectedFunction, awaitingScene = true,
    }
    -- A container's loot scene cannot replace this custom inventory scene while
    -- it is still showing. Let the scene finish hiding, then use the item.
    SCENE_MANAGER:ShowBaseScene()
end

function Addon:CompletePendingUse()
    local pending = self.pendingUse
    if not pending or not pending.awaitingScene then return end
    pending.awaitingScene = false
    local fresh = self.Data.ValidateItem(pending)
    local action = fresh and self.Data.GetUseAction(fresh)
    if not action or action.protectedFunction ~= pending.protectedFunction then
        self.pendingUse = nil
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK,
            "That item changed or cannot be used now. Try the native inventory.")
        return
    end

    -- Match ESO's native inventory use path before invoking the protected API.
    ClearCursor()
    local success = CallSecureProtected(action.protectedFunction, fresh.bagId, fresh.slotIndex)
    if not success then
        self.pendingUse = nil
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK,
            "That item cannot be used here. Try the native inventory.")
        return
    end
    local token = pending.token
    zo_callLater(function()
        if self.pendingUse and self.pendingUse.token == token then
            self.pendingUse = nil
            if self.keybindsActive then
                KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds)
            end
        end
    end, USE_PENDING_TIMEOUT_MS)
end

function Addon:ActivateFocused()
    local destination = self:GetDestination()
    if destination and destination.canEquip then
        self:EquipFocused()
    else
        self:UseFocused()
    end
end

function Addon:InitializeKeybinds()
    self.keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        -- These UI shortcut actions receive D-pad presses without polling the
        -- private IsKeyDown API. Ethereal descriptors handle input without
        -- adding four extra buttons to the visible footer.
        {
            name = "Navigate up",
            keybind = "UI_SHORTCUT_INPUT_UP",
            ethereal = true,
            callback = function()
                self:Move(MOVEMENT_CONTROLLER_NO_CHANGE, MOVEMENT_CONTROLLER_MOVE_PREVIOUS)
            end,
        },
        {
            name = "Navigate right",
            keybind = "UI_SHORTCUT_INPUT_RIGHT",
            ethereal = true,
            callback = function()
                self:Move(MOVEMENT_CONTROLLER_MOVE_NEXT, MOVEMENT_CONTROLLER_NO_CHANGE)
            end,
        },
        {
            name = "Navigate down",
            keybind = "UI_SHORTCUT_INPUT_DOWN",
            ethereal = true,
            callback = function()
                self:Move(MOVEMENT_CONTROLLER_NO_CHANGE, MOVEMENT_CONTROLLER_MOVE_NEXT)
            end,
        },
        {
            name = "Navigate left",
            keybind = "UI_SHORTCUT_INPUT_LEFT",
            ethereal = true,
            callback = function()
                self:Move(MOVEMENT_CONTROLLER_MOVE_PREVIOUS, MOVEMENT_CONTROLLER_NO_CHANGE)
            end,
        },
        {
            name = function()
                if self.quickslotMode then return "Assign to slot " .. self.quickslotIndex end
                local destination = self:GetDestination()
                if destination and destination.canEquip then
                    return "Equip: " .. destination.label
                end
                local item = self:GetFocusedItem()
                local action = item and self.Data.GetUseAction(item)
                return action and action.label or "Use"
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                if self.quickslotMode then return true end
                local destination = self:GetDestination()
                if self.pendingEquip or self.pendingUse then return false end
                if destination and destination.canEquip then return true end
                local item = self:GetFocusedItem()
                return item ~= nil and self.Data.GetUseAction(item) ~= nil
            end,
            callback = function()
                if self.quickslotMode then self:AssignSelectedQuickslot()
                else self:ActivateFocused() end
            end,
        },
        {
            name = "Prev tab",
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            visible = function() return not self.quickslotMode end,
            callback = function() self:CycleCategory(-1) end,
        },
        {
            name = "Next tab",
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            visible = function() return not self.quickslotMode end,
            callback = function() self:CycleCategory(1) end,
        },
        {
            name = "ESO mode",
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function() return not self.quickslotMode end,
            callback = function() self:OpenNativeInventory() end,
        },
        {
            name = "Prev slot",
            keybind = "UI_SHORTCUT_LEFT_TRIGGER",
            visible = function() return not self.quickslotMode and self.pane == "bag" and #self.destinations > 1 end,
            callback = function() self:CycleDestination(-1) end,
        },
        {
            name = "Next slot",
            keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
            visible = function() return not self.quickslotMode and self.pane == "bag" and #self.destinations > 1 end,
            callback = function() self:CycleDestination(1) end,
        },
        {
            name = function() return self.tooltipVisible and "Hide tooltip" or "Tooltip" end,
            keybind = "UI_SHORTCUT_QUATERNARY",
            visible = function() return not self.quickslotMode and self:GetFocusedItem() ~= nil end,
            callback = function()
                self.tooltipVisible = not self.tooltipVisible
                self:RefreshNativeTooltip()
                KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds)
            end,
        },
        {
            name = function()
                return self.savedVars.category == "slottable" and "Assign" or "Map"
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function() return not self.quickslotMode end,
            callback = function()
                if self.savedVars.category == "slottable" then
                    self:OpenQuickslotPicker()
                else
                    self:OpenMap()
                end
            end,
        },
    }
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybinds,
        GAME_NAVIGATION_TYPE_BUTTON,
        function()
            if self.quickslotMode then self:CloseQuickslotPicker()
            else SCENE_MANAGER:HideCurrentScene() end
        end)
end

function Addon:RegisterSceneEvents()
    EVENT_MANAGER:RegisterForEvent(BAG_EVENT, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        function(_, bagId)
            if bagId == BAG_BACKPACK or bagId == BAG_WORN then self:QueueRefresh() end
        end)
    EVENT_MANAGER:RegisterForEvent(FULL_EVENT, EVENT_INVENTORY_FULL_UPDATE,
        function() self:QueueRefresh() end)
    EVENT_MANAGER:RegisterForEvent(WEAPON_EVENT, EVENT_ACTIVE_WEAPON_PAIR_CHANGED,
        function() self:QueueRefresh() end)
    if SHARED_INVENTORY and SHARED_INVENTORY.RegisterCallback then
        SHARED_INVENTORY:RegisterCallback("FullQuestUpdate", self.questRefreshCallback)
        SHARED_INVENTORY:RegisterCallback("SingleQuestUpdate", self.questRefreshCallback)
    end
end

function Addon:UnregisterSceneEvents()
    EVENT_MANAGER:UnregisterForEvent(BAG_EVENT, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(FULL_EVENT, EVENT_INVENTORY_FULL_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(WEAPON_EVENT, EVENT_ACTIVE_WEAPON_PAIR_CHANGED)
    if SHARED_INVENTORY and SHARED_INVENTORY.UnregisterCallback then
        SHARED_INVENTORY:UnregisterCallback("FullQuestUpdate", self.questRefreshCallback)
        SHARED_INVENTORY:UnregisterCallback("SingleQuestUpdate", self.questRefreshCallback)
    end
end

function Addon:OnSceneStateChanged(_, newState)
    if newState == SCENE_SHOWING then
        -- Map Options can reopen our scene after ESO mode. Restore the normal
        -- menu route only once the player explicitly returns to this view.
        self.Integration.Enable()
        self.sceneEpoch = self.sceneEpoch + 1
        self.pane = "bag"
        self.tooltipVisible = false
        self.quickslotMode = false
        self.quickslotItem = nil
        self.view:ShowQuickslotPicker(false)
        self:RegisterSceneEvents()
        self:RefreshInventory()
        KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds)
        self.keybindsActive = true
        DIRECTIONAL_INPUT:Activate(self, self.view.root)
    elseif newState == SCENE_HIDING then
        self.sceneEpoch = self.sceneEpoch + 1
        self:UnregisterSceneEvents()
        self.quickslotMode = false
        self.quickslotItem = nil
        self.view:ShowQuickslotPicker(false)
        DIRECTIONAL_INPUT:Deactivate(self)
        if self.keybindsActive then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybinds)
            self.keybindsActive = false
        end
        self.tooltipVisible = false
        self:RefreshNativeTooltip()
    elseif newState == SCENE_HIDDEN then
        self:CompletePendingUse()
    end
end

function Addon:Initialize()
    self.savedVars = ZO_SavedVars:NewAccountWide("An_Daghdha1233InventorySavedVariables",
        SAVE_VERSION, nil, SAVE_DEFAULTS)
    if self.savedVars.filter == "gear" and self.savedVars.category == "all" then
        self.savedVars.category = "gear"
    elseif self.savedVars.category == nil then
        self.savedVars.category = self.savedVars.filter == "gear" and "gear" or "all"
    end
    self.savedVars.filter = nil
    local knownCategory = false
    for _, category in ipairs(CATEGORIES) do
        if self.savedVars.category == category then knownCategory = true break end
    end
    if not knownCategory then self.savedVars.category = "all" end
    local knownGearFilter = false
    for _, filter in ipairs(GEAR_FILTERS) do
        if self.savedVars.gearFilter == filter then knownGearFilter = true break end
    end
    if not knownGearFilter then self.savedVars.gearFilter = "all" end

    self.items = {}
    self.equipped = {}
    self.destinations = {}
    self.selectedIndex = 1
    self.equippedIndex = 1
    self.destinationIndex = 1
    self.pane = "bag"
    self.sceneEpoch = 0
    self.pendingUse = nil
    self.questRefreshCallback = function() self:QueueRefresh() end
    self.view = self.View.Create()
    self.scene = ZO_Scene:New(self.SCENE_NAME, SCENE_MANAGER)
    self.scene:AddFragment(ZO_FadeSceneFragment:New(self.view.root))
    self.scene:AddFragment(GAMEPAD_UI_MODE_FRAGMENT)
    self.scene:AddFragment(STOP_MOVEMENT_FRAGMENT)
    self.scene:AddFragment(UI_SHORTCUTS_ACTION_LAYER_FRAGMENT)
    self.scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_KEYBIND_STRIP_GROUP)
    self.scene:RegisterCallback("StateChange", function(...) self:OnSceneStateChanged(...) end)

    self.detailMovementController = ZO_MovementController:New(
        MOVEMENT_CONTROLLER_DIRECTION_VERTICAL, nil, GetDetailStickMagnitude)
    self:InitializeKeybinds()

    if not self.Integration.Enable() then
        self.view:SetStatus("The Inventory menu has changed. Native inventory remains available.")
    end
    self.Integration.EnableMapInfoTab()
    -- Map information may be constructed after add-on loading. Its Showing
    -- callback runs before the native tab header refreshes.
    if CALLBACK_MANAGER and CALLBACK_MANAGER.RegisterCallback then
        CALLBACK_MANAGER:RegisterCallback("WorldMapInfo_Gamepad_Showing", function()
            self.Integration.EnableMapInfoTab()
        end)
    end
end

EVENT_MANAGER:RegisterForEvent(LOAD_EVENT, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= Addon.NAME then return end
    EVENT_MANAGER:UnregisterForEvent(LOAD_EVENT, EVENT_ADD_ON_LOADED)
    Addon:Initialize()
end)
