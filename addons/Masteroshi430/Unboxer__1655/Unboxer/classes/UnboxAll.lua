--[[ 
     Handles base logic and events for unboxing all containers in inventory as configured.
]]--

local addon = Unboxer
local class = addon.classes
local debug = false
local defaultStates = {}

class.UnboxAll = ZO_CallbackObject:Subclass()

function class.UnboxAll:New(...)
    local instance = ZO_CallbackObject.New(self)
    instance:Initialize(...)
    return instance
end
function class.UnboxAll:Initialize(name)
    self.name = name or addon.name .. "_UnboxAll"
    self.states = {}
    self.eventHandlers = {}
    self.callbackHandlers = {}
    self.containerSlotIndexes = {}
    self.uniqueItemSlotIndexes = {
        [BAG_WORN]     = {},
        [BAG_BACKPACK] = {},
    }
    self.notified = {}
    for name, config in pairs(defaultStates) do
        if config.events then
            self:RegisterPauseEvents(name, config.events.pause, config.events.unpause, config.active, config.interactionTypes, config.combatEventFilters)
        end
        if config.callbacks then
            self:RegisterPauseCallbacks(name, config.callbacks.pause, config.callbacks.unpause, config.active)
        end
    end
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, self:CreateSlotUpdateCallback())
    EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
    EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM, true)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, self:CreatePlayerActivatedHandler())
    -- Register the "reset the in-flight opener on pause" handler exactly once, here,
    -- rather than once per item in Start(). self is this same long-lived UnboxAll
    -- instance for the whole session, and RegisterCallback appends rather than
    -- replacing by name, so registering a new closure every time an item is opened
    -- leaked one closure (plus everything it captured) per unboxed item, forever,
    -- for the life of the UI session. See Start() for the paired self.currentOpener.
    self:RegisterCallback("Paused", function()
        if self.currentOpener then
            self.currentOpener:Reset()
        end
    end)
    self:Reset()
    self:ListenForPause()
end

function class.UnboxAll:CreateFailedCallback()
    return function(slotIndex, itemLink, reason)
        addon.Debug("Failed "..tostring(itemLink).." ("..tostring(slotIndex)..") "..tostring(reason), debug)
        self:FireCallbacks("Failed", slotIndex, itemLink, reason)
        -- Inventory full: retrying (or moving on to the next box) can't succeed, so stop the whole queue.
        if reason == "Inventory full" or reason == "Not enough space" then
            if reason == "Inventory full" then
                PlaySound(SOUNDS.NEGATIVE_CLICK)
                addon.Print("Inventory full, unboxing stopped.")
            end
            self:Reset()
            self:FireCallbacks("Stopped")
            return
        end
        EVENT_MANAGER:RegisterForUpdate(self.name .. "_Start", 40, function() self:Start() end)
    end
end

function class.UnboxAll:CreateInteractionTypesCheck(interactionTypes)
    return function()
        local interactionType = GetInteractionType()
        if ZO_IsElementInNumericallyIndexedTable(interactionTypes, interactionType) then
            return true
        end
    end
end

function class.UnboxAll:CreateInteractSceneHiddenCallback(scene, name)
    return function(oldState, newState)
        if newState ~= SCENE_HIDDEN then
            return
        end
        self:OnUnpausedEvent(name)
    end
end

function class.UnboxAll:CreateMountFailureHandler()
    -- If a mount failure occurs while unboxing, delay for the configured time
    return function() self:DelayStart(math.max(self:GetDelayMilliseconds(), 2000)) end
end

function class.UnboxAll:CreateOpenedCallback()
    return function(itemLink, lootReceived, rule)
        self:FireCallbacks("Opened", itemLink, lootReceived, rule)
        local milliseconds = 40
        if #self.queue > 0 then
            local slotIndex = self.queue[1].slotIndex
            local remaining, duration = GetItemCooldownInfo(BAG_BACKPACK, slotIndex)
            if remaining > 0 and duration > 0 then
                milliseconds = milliseconds + remaining
            end
        end
        self:DelayStart(milliseconds)
    end
end

function class.UnboxAll:CreatePlayerActivatedHandler()
    return function()
        EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_PLAYER_ACTIVATED)
        SHARED_INVENTORY:RegisterCallback("SlotAdded", self:CreateSharedSlotUpdatedCallback())
        SHARED_INVENTORY:RegisterCallback("SlotUpdated", self:CreateSharedSlotUpdatedCallback(true))
        SHARED_INVENTORY:RegisterCallback("SlotRemoved", self:CreateSharedSlotRemovedCallback())
        local originalDebug = debug
        debug = false
        SHARED_INVENTORY:PerformFullUpdateOnBagCache(BAG_WORN)
        SHARED_INVENTORY:PerformFullUpdateOnBagCache(BAG_BACKPACK)
        debug = originalDebug
    end
end

function class.UnboxAll:CreateSharedSlotRemovedCallback()
    return function(bagId, slotIndex, existingSlotData)
        if not self.uniqueItemSlotIndexes[bagId] then
            return
        end
        addon.QueueKeybindRefresh()
        self.containerSlotIndexes[slotIndex] = nil
        if addon.IsDebugEnabled(debug) then
            addon.Debug("SharedSlotRemoved "..tostring(bagId).." "..tostring(slotIndex).." "..tostring(existingSlotData.itemLink), debug)
        end
        local uniqueItemIdRemoved = self.uniqueItemSlotIndexes[bagId][slotIndex]
        self.uniqueItemSlotIndexes[bagId][slotIndex] = nil
        if bagId ~= BAG_BACKPACK then
            return
        end
        addon.slotUniqueContentItemIds[slotIndex] = nil
        -- only display "no longer ignoring" alert when all unique items in the container have been removed
        if not uniqueItemIdRemoved then
            return
        end
        
        for containerWithUniqueItemsSlotIndex, uniqueItems in pairs(addon.slotUniqueContentItemIds) do
            if uniqueItems[uniqueItemIdRemoved] then
                local allRemoved = true
                for uniqueItemId, _ in pairs(uniqueItems) do
                    for _, itemId in pairs(self.uniqueItemSlotIndexes[bagId]) do
                        if itemId == uniqueItemId then
                            allRemoved = false
                            break
                        end
                    end
                    if not allRemoved then
                        break
                    end
                end
                if allRemoved then
                    local containerItemLink = GetItemLink(BAG_BACKPACK, containerWithUniqueItemsSlotIndex)
                    addon.PrintOnce(zo_strformat(GetString(SI_UNBOXER_NOT_IGNORING), containerItemLink, existingSlotData.itemLink))
                    if self.notified[containerWithUniqueItemsSlotIndex] then
                        self.notified[containerWithUniqueItemsSlotIndex][slotIndex] = nil
                    end
                end
            end
        end
    end
end

function class.UnboxAll:CreateSharedSlotUpdatedCallback(wasSameItemInSlotBefore)
    return function(bagId, slotIndex, slotData)
        if not self.uniqueItemSlotIndexes[bagId] then
            return
        end
        addon.QueueKeybindRefresh()
        if addon.containerItemTypes[slotData.itemType] then
            self.containerSlotIndexes[slotIndex] = true
        else
            self.containerSlotIndexes[slotIndex] = nil
            if bagId == BAG_BACKPACK then
                addon.slotUniqueContentItemIds[slotIndex] = nil
            end
        end
        slotData.itemLink = GetItemLink(bagId, slotIndex)
        slotData.itemId   = GetItemLinkItemId(slotData.itemLink)
        slotData.isUnique = IsItemLinkUnique(slotData.itemLink)
        slotData.bindType = nil
        slotData.flavorText = nil
        slotData.collectibleId = nil
        slotData.collectibleCategoryType = nil
        self.uniqueItemSlotIndexes[bagId][slotIndex] = slotData.isUnique and slotData.itemId or nil
        local uniqueItemId = self.uniqueItemSlotIndexes[bagId][slotIndex]
        if bagId == BAG_BACKPACK and uniqueItemId and not wasSameItemInSlotBefore then
            for containerWithUniqueItemsSlotIndex, uniqueItems in pairs(addon.slotUniqueContentItemIds) do
                local containerItemLink = GetItemLink(BAG_BACKPACK, containerWithUniqueItemsSlotIndex)
                if uniqueItems[uniqueItemId] and containerItemLink ~= "" then
                    if not self.notified[containerWithUniqueItemsSlotIndex] then
                        self.notified[containerWithUniqueItemsSlotIndex] = {}
                    end
                    if not self.notified[containerWithUniqueItemsSlotIndex][slotIndex] then
                        addon.PrintOnce(zo_strformat(GetString(SI_UNBOXER_IGNORING), containerItemLink, slotData.itemLink))
                        self.notified[containerWithUniqueItemsSlotIndex][slotIndex] = 1
                    end
                end
            end
        end
        if addon.IsDebugEnabled(debug) then
            addon.Debug("SharedSlotUpdate "..tostring(bagId).." "..tostring(slotIndex).." "..tostring(slotData.itemLink), debug)
        end
    end
end

function class.UnboxAll:CreateSlotUpdateCallback()
    return function(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange)
        local itemType = GetItemType(bagId, slotIndex)
        if not addon.containerItemTypes[itemType] then
            return
        end
        if self:GetAutoQueue()
           and addon:IsItemUnboxable(bagId, slotIndex, not self.autoQueueManual)
           and addon:HasInventorySpaceToUnbox(bagId, slotIndex)
        then
            self:Queue({ slotIndex = slotIndex, itemLink = GetItemLink(bagId, slotIndex) })
            if self.state == "stopped" and #self.queue < 2 then
                -- Was self.slotIndex, which doesn't exist on UnboxAll (that field only
                -- exists on BoxOpener instances) and was always nil, so this cooldown
                -- check was silently a no-op. Use the slot that was just queued instead.
                local remaining, duration = GetItemCooldownInfo(BAG_BACKPACK, slotIndex)
                if remaining > 0 and duration > 0 then
                    self:DelayStart(40 + remaining)
                else
                    self:DelayStart(40)
                end
            end
        end
    end
end

function class.UnboxAll:CreateUniqueLootFoundCallback()
    return function(boxOpener, lootInfo)
        local containerSlotIndex = boxOpener.slotIndex
        local lootItemId = GetItemLinkItemId(lootInfo.itemLink)
        
        if not addon.slotUniqueContentItemIds[containerSlotIndex] then
            addon.slotUniqueContentItemIds[containerSlotIndex] = {}
        end
        addon.slotUniqueContentItemIds[containerSlotIndex][lootItemId] = 1
        
        for bagId, itemIds in pairs(self.uniqueItemSlotIndexes) do
            for uniqueItemSlotIndex, itemId in pairs(itemIds) do
                if lootItemId == itemId and boxOpener.itemLink ~= "" then
                    if not self.notified[containerSlotIndex] then
                        self.notified[containerSlotIndex] = {}
                    end
                    if not self.notified[containerSlotIndex][uniqueItemSlotIndex] then
                        addon.PrintOnce(zo_strformat(GetString(SI_UNBOXER_IGNORING), boxOpener.itemLink, lootInfo.itemLink))
                        self.notified[containerSlotIndex][uniqueItemSlotIndex] = 1
                    end
                    boxOpener:Reset()
                    break
                end
            end
        end
    end
end

function class.UnboxAll:DelayStart(milliseconds)
    self.state = "delayed_start"
    if not milliseconds then
        milliseconds = self:GetDelayMilliseconds()
    end
    addon.Debug("Delay starting unbox for "..tostring(milliseconds).." ms", debug)
    self:FireCallbacks("DelayStart")
    EVENT_MANAGER:RegisterForUpdate(self.name .. "_Start", milliseconds, function() self:Start() end)
end
function class.UnboxAll:DequeueByItemIds(itemIds)
    for index=#self.queue,1,-1 do
        local item = self.queue[index]
        local itemId = GetItemLinkItemId(item.itemLink)
        if itemIds[itemId] then
            table.remove(self.queue, index)
        end
    end
end
function class.UnboxAll:GetAutoQueue(value)
    return addon.settings.autoloot or self.autoQueueManual
end
function class.UnboxAll:GetDelayMilliseconds()
    local delay = math.max(40, addon.settings.autolootDelay * 1000)
    return delay
end
function class.UnboxAll:HasUnboxableSlots()
    
    for state, config in pairs(self.states) do
        if config.active() then
            return false
        end
    end
    
    if #self.queue > 0 then return true end
    
    local bagId = BAG_BACKPACK
    for slotIndex, _ in pairs(self.containerSlotIndexes) do
        if addon:IsItemUnboxable(bagId, slotIndex) 
           and addon:HasInventorySpaceToUnbox(bagId, slotIndex)
           and CanInteractWithItem(bagId, slotIndex) 
           and select(4,GetItemInfo(bagId, slotIndex)) -- meets usage requirement
        then
            return true
        end
    end

    return false
end
function class.UnboxAll:ListenForPause()
    if self.listeningForPause then
        return
    end
    self.listeningForPause = true
    for name, handlers in pairs(self.eventHandlers) do
        local pause = handlers.pause
        if pause then
            local events = type(pause.events) == "table" and pause.events or { pause.events }
            for _, event in ipairs(events) do
                local scope = self.name .. "_" .. name .. "_pause"
                EVENT_MANAGER:RegisterForEvent(scope, event, pause.handler)
                addon.Debug("Listening for event " .. tostring(event) .. " " .. scope, debug)
                if pause.combatEventFilters then
                    if event == EVENT_COMBAT_EVENT then
                        for filterType, filterParameter in pairs(pause.combatEventFilters) do
                            addon.Debug("Adding combat event filter " .. tostring(filterType) .. " " .. tostring(filterParameter) 
                                        .. " for event " .. scope, debug)
                            EVENT_MANAGER:AddFilterForEvent(scope,  event, filterType, filterParameter)
                        end
                    else
                        addon.Debug("Event " .. scope .. " does not match "
                                     ..tostring(EVENT_COMBAT_EVENT).. ". it is "..tostring(event), debug)
                    end
                end
            end
        end
    end
    for name, callbackHandler in pairs(self.callbackHandlers) do
        if callbackHandler.pause then
            for _, pause in ipairs(callbackHandler.pause) do
                local scope = pause.name .. "_pause"
                pause.target:RegisterCallback(scope,  pause.callback)
            end
        end
    end
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MOUNT_FAILURE, self:CreateMountFailureHandler())
end

function class.UnboxAll:IsActive()
    return #self.queue > 0 or self.state == "active" or self.state == "delayed_start"
end

function class.UnboxAll:OnPausedEvent(name, combatEventFilters)
    local unpause, events
    local handlers = self.eventHandlers[self.state]
    if self.state == name then
        return
    elseif handlers then
        unpause = handlers.unpause
        events = type(unpause.events) == "table" and unpause.events or { unpause.events }
        addon.Debug("Unregistering unpause event(s) for " .. self.state, debug)
        for _, event in ipairs(events) do
            local scope = self.name .. "_" .. self.state .. "_unpause"
            EVENT_MANAGER:UnregisterForEvent(scope, event)
        end
    end
    handlers = self.eventHandlers[name]
    if not handlers then
        return
    end
    unpause = handlers.unpause
    if unpause then
        events = type(unpause.events) == "table" and unpause.events or { unpause.events }
        for _, event in ipairs(events) do
            local scope = self.name .. "_" .. name .. "_unpause"
            EVENT_MANAGER:RegisterForEvent(scope,  event, unpause.handler)
            if event == EVENT_COMBAT_EVENT and unpause.combatEventFilters then
                for filterType, filterParameter in pairs(unpause.combatEventFilters) do
                    EVENT_MANAGER:AddFilterForEvent(scope,  event, filterType, filterParameter)
                end
            end
        end
    
    -- Fix for retrait station having no close event
    elseif SCENE_MANAGER.currentScene and getmetatable(SCENE_MANAGER.currentScene) == ZO_InteractScene then
        self.sceneStateChange = {
            scene = SCENE_MANAGER.currentScene,
            callback = self:CreateInteractSceneHiddenCallback(SCENE_MANAGER.currentScene, name)
        }
        self.sceneStateChange.scene:RegisterCallback("StateChange", self.sceneStateChange.callback)
    end
    self.state = name
    addon.Debug("Paused ("..tostring(name)..")", debug)
    self:FireCallbacks("Paused", name)
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "_Start")
end

function class.UnboxAll:OnUnpausedEvent(name)
    if not self.eventHandlers[name] then
        return
    end
    local unpause = self.eventHandlers[name].unpause
    if unpause then
        local scope = self.name .. "_" .. name .. "_unpause"
        local events = type(unpause.events) == "table" and unpause.events or { unpause.events }
        for _, event in ipairs(events) do
            EVENT_MANAGER:UnregisterForEvent(scope, event)
        end
    end
    -- Fix for retrait station having no close event
    if self.sceneStateChange then
        self.sceneStateChange.scene:UnregisterCallback("StateChange", self.sceneStateChange.callback)
        self.sceneStateChange = nil
    end
    if self.state ~= name then
        addon.Debug("Not unpausing ("..tostring(name)..") because current state is " .. self.state, debug)
        return
    end
    self.state = "stopped"
    addon.Debug("Unpaused ("..tostring(name)..")", debug)
    self:FireCallbacks("Unpaused", name)
    if #self.queue > 0 then
        self:DelayStart()
    end
end

function class.UnboxAll:OnPausedCallback(name)
    if not self.callbackHandlers[name] or self.state == name then
        return
    end
    local handlers = self.callbackHandlers[name].unpause
    if handlers then
        for _, unpause in ipairs(handlers) do
            local scope = unpause.name .. "_unpause"
            unpause.target:RegisterCallback(scope,  unpause.callback)
        end
    end
    self.state = name
    addon.Debug("Paused ("..tostring(name)..")", debug)
    self:FireCallbacks("Paused", name)
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "_Start")
end

function class.UnboxAll:OnUnpausedCallback(name)
    if not self.callbackHandlers[name] then
        return
    end
    local handlers = self.callbackHandlers[name].unpause
    if handlers then
        for _, unpause in ipairs(handlers) do
            local scope = unpause.name .. "_unpause"
            unpause.target:UnregisterCallback(unpause,  unpause.callback)
        end
    end
    if self.state ~= name then
        addon.Debug("Not unpausing ("..tostring(name)..") because current state is " .. self.state, debug)
        return
    end
    self.state = "stopped"
    addon.Debug("Unpaused ("..tostring(name)..")", debug)
    self:FireCallbacks("Unpaused", name)
    if #self.queue > 0 then
        self:DelayStart()
    end
end

function class.UnboxAll:Queue(item)
    table.insert(self.queue, item)
    addon.Debug("Queued item "..tostring(item.itemLink).." ("..tostring(item.slotIndex)..")", debug)
end

function class.UnboxAll:QueueAllInBackpack()
    local bagId = BAG_BACKPACK
    for slotIndex, _ in pairs(self.containerSlotIndexes) do
        if addon:IsItemUnboxable(bagId, slotIndex) 
           and addon:HasInventorySpaceToUnbox(bagId, slotIndex)
           and CanInteractWithItem(bagId, slotIndex) 
           and select(4,GetItemInfo(bagId, slotIndex)) -- meets usage requirement
        then
            self:Queue({slotIndex = slotIndex, itemLink = GetItemLink(bagId, slotIndex)})
        end
    end
end

function class.UnboxAll:RefreshState()
    for name, state in pairs(self.states) do
        if state.active() then
            if state.events then
                self:OnPausedEvent(name)
            end
            return
        end
    end
end

function class.UnboxAll:Reset()
    self.state = "stopped"
    self.queue = {}
    self.autoQueueManual = nil
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "_Start")
    for name, handlers in pairs(self.eventHandlers) do
        local unpause = handlers.unpause
        if unpause then
            local events = type(unpause.events) == "table" and unpause.events or { unpause.events }
            for _, event in ipairs(events) do
                local scope = self.name .. "_" .. name .. "_unpause"
                EVENT_MANAGER:UnregisterForEvent(scope, event)
            end
        end
    end
    for _, handlers in pairs(self.callbackHandlers) do
        if handlers.unpause then
            for _, unpause in ipairs(handlers.unpause) do
                local scope = unpause.name .. "_unpause"
                unpause.target:UnregisterCallback(scope, unpause.callback)
            end
        end
    end
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_MOUNT_FAILURE)
end

function class.UnboxAll:RegisterPauseEvents(name, pauseEvents, unpauseEvents, activeFunc, interactionTypes, combatEventFilters)
    if not activeFunc and interactionTypes then
        activeFunc = self:CreateInteractionTypesCheck(interactionTypes)
    end
    self.states[name] = {
        events = { pause = pauseEvents, unpause = unpauseEvents },
        active = activeFunc,
        combatEventFilters = combatEventFilters,
    }
    local handlers = { }
    if pauseEvents then
        handlers.pause   = {
            events  = pauseEvents,
            handler = function(...)
                          if not activeFunc() then return end
                          self:OnPausedEvent(name)
                      end,
            combatEventFilters = combatEventFilters and combatEventFilters.pause or nil,
        }
    end
    if unpauseEvents then
        handlers.unpause = {
            events  = unpauseEvents,
            handler = function(...)
                          if activeFunc() then return end
                          self:OnUnpausedEvent(name, combatEventFilters and combatEventFilters.unpause)
                      end,
            combatEventFilters = combatEventFilters and combatEventFilters.unpause or nil,
        }
    end
    self.eventHandlers[name] = handlers
end

function class.UnboxAll:RegisterPauseCallbacks(name, pauseCallbacks, unpauseCallbacks, activeFunc)
    self.states[name] = {
        callbacks = {
            pause = pauseCallbacks,
            unpauseCallbacks = unpauseCallbacks,
        },
        active = activeFunc,
    }
    self.callbackHandlers[name] = {
        pause   = {},
        unpause = {},
    }
    if pauseCallbacks then
        for _, callback in ipairs(pauseCallbacks) do
            table.insert(self.callbackHandlers[name].pause,
                {
                    target    = callback.target,
                    name      = callback.name,
                    callback  = function(...)
                                    if not activeFunc() then return end
                                    self:OnUnpausedCallback(name)
                                end
                }
            )
        end
    end
    if unpauseCallbacks then
        for _, callback in ipairs(unpauseCallbacks) do
            table.insert(self.callbackHandlers[name].unpause,
                {
                    target    = callback.target,
                    name      = callback.name,
                    callback  = function(...)
                                    if activeFunc() then return end
                                    self:OnUnpausedCallback(name)
                                end
                }
            )
        end
    end
end

function class.UnboxAll:SetAutoQueueManual(value)
    self.autoQueueManual = value
end

function class.UnboxAll:Start()
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "_Start")
    addon.Debug("Start", debug)
    
    self:FireCallbacks("Start")
    
    if #self.queue == 0 then
        self:Reset()
        addon.Debug("Stopped. Queue is empty.", debug)
        self:FireCallbacks("Stopped")
        return
    end
    
    self:RefreshState()
    
    if self.state ~= "stopped" and self.state ~= "delayed_start" then
        return
    end
    
    self.state = "active"
    
    local item = table.remove(self.queue, 1)
    
    addon.Debug("BeforeOpen " .. tostring(item.itemLink) .. " (" .. tostring(item.slotIndex) .. ")", debug)
    self:FireCallbacks("BeforeOpen", item)
    
    local opener = class.BoxOpener:New(item.slotIndex)
    local failedCallback = self:CreateFailedCallback()
    opener:RegisterCallback("Failed", failedCallback)
    opener:RegisterCallback("Opened", self:CreateOpenedCallback())
    opener:RegisterCallback("UniqueLootFound", self:CreateUniqueLootFoundCallback())
    self.currentOpener = opener
    if opener:Open() then
        return
    end
    
    local reason
    if opener.rule then
        reason = "Container type " .. opener.rule.name .. " was not configured for unboxing in settings."
    else
        reason = "Unknown container type"
    end
    failedCallback(item.slotIndex, item.itemLink, reason)
end

function class.UnboxAll:StopListeningForPause()
    if not self.listeningForPause then
        return
    end
    self.listeningForPause = nil
    for name, handlers in pairs(self.eventHandlers) do
        local pause = handlers.pause
        if pause then
            local events = type(pause.events) == "table" and pause.events or { pause.events }
            for _, event in ipairs(events) do
                local scope = self.name .. "_" .. name .. "_pause"
                EVENT_MANAGER:UnregisterForEvent(scope, event)
                addon.Debug("Stop listening for event " .. tostring(event) .. " " .. scope, debug)
            end
        end
    end
    for name, callbackHandler in pairs(self.callbackHandlers) do
        if callbackHandler.pause then
            for _, pause in ipairs(callbackHandler.pause) do
                local scope = pause.name .. "_pause"
                pause.target:UnregisterCallback(scope,  pause.callback)
            end
        end
    end
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_MOUNT_FAILURE)
end
    
--[[ TODO: figure out a way to deal with loot scene changes.  Pause and resume, but without delay?
if LOOT_SCENE.state ~= SCENE_HIDDEN or LOOT_SCENE_GAMEPAD.state ~= SCENE_HIDDEN then
    self.Debug("Loot scene is showing.", debug)
    if self.unboxingAll then
        AbortAction()
        PlaySound(SOUNDS.NEGATIVE_CLICK)
    else
        self.Debug("Waiting for it to close to open slotIndex "..tostring(slotIndex))
        table.insert(self.itemSlotStack, slotIndex)
    end
    return
end ]]--

defaultStates = {
  inCombat = {
      events = { pause = EVENT_PLAYER_COMBAT_STATE, unpause = EVENT_PLAYER_COMBAT_STATE },
      active = function() return IsUnitInCombat("player") end,
  },
  swimming = {
      events = { pause = EVENT_PLAYER_SWIMMING, unpause = EVENT_PLAYER_NOT_SWIMMING },
      active = function() return IsUnitSwimming("player") end,
  },
  dead = {
      events = { pause = EVENT_PLAYER_DEAD, unpause = { EVENT_PLAYER_ALIVE, EVENT_PLAYER_REINCARNATED } },
      active = function() return IsUnitDeadOrReincarnating("player") end,
  },
  mail = {
      events = { pause = EVENT_MAIL_OPEN_MAILBOX, unpause = EVENT_MAIL_CLOSE_MAILBOX },
      interactionTypes = { INTERACTION_MAIL },
  },
  crafting = {
      events = { pause = EVENT_CRAFTING_STATION_INTERACT, unpause = EVENT_END_CRAFTING_STATION_INTERACT },
      interactionTypes = { INTERACTION_CRAFT },
  },
  retrait = {
      events = { pause = EVENT_RETRAIT_STATION_INTERACT_START  },
      interactionTypes = { INTERACTION_RETRAIT },
  },
  dyeing = {
      events = { pause = EVENT_DYEING_STATION_INTERACT_START, unpause = EVENT_DYEING_STATION_INTERACT_END },
      interactionTypes = { INTERACTION_DYE_STATION },
  },
  reading = {
      events = { pause = EVENT_SHOW_BOOK, unpause = EVENT_HIDE_BOOK },
      interactionTypes = { INTERACTION_BOOK },
  },
  bank = {
      events = { pause = EVENT_OPEN_BANK, unpause = EVENT_CLOSE_BANK },
      interactionTypes = { INTERACTION_BANK },
  },
  guildBank = {
      events = { pause = EVENT_OPEN_GUILD_BANK, unpause = EVENT_CLOSE_GUILD_BANK },
      interactionTypes = { INTERACTION_GUILDBANK },
  },
  tradingHouse = {
      events = { pause = EVENT_OPEN_TRADING_HOUSE, unpause = EVENT_CLOSE_TRADING_HOUSE },
      interactionTypes = { INTERACTION_TRADINGHOUSE },
  },
  conversation = {
      events = { pause = EVENT_CHATTER_BEGIN, unpause = EVENT_CHATTER_END },
      interactionTypes = { INTERACTION_CONVERSATION, INTERACTION_GUILDKIOSK_BID, INTERACTION_BUY_BAG_SPACE, INTERACTION_HIDEYHOLE },
  },
  vendor = {
      events = { pause = EVENT_OPEN_STORE, unpause = EVENT_CLOSE_STORE },
      interactionTypes = { INTERACTION_VENDOR },
  },
  wayshrine = {
      events = { pause = EVENT_START_FAST_TRAVEL_INTERACTION, unpause = EVENT_END_FAST_TRAVEL_INTERACTION },
      interactionTypes = { INTERACTION_FAST_TRAVEL },
  },
  fastTravelKeep = {
      events = { pause = EVENT_START_FAST_TRAVEL_KEEP_INTERACTION , unpause = EVENT_END_FAST_TRAVEL_KEEP_INTERACTION },
      interactionTypes = { INTERACTION_FAST_TRAVEL_KEEP },
  },
  lockpick = {
      events = { pause =  EVENT_BEGIN_LOCKPICK, unpause = { EVENT_LOCKPICK_FAILED, EVENT_LOCKPICK_SUCCESS } },
      interactionTypes = { INTERACTION_LOCKPICK },
  },
  stable = {
      events = { pause =  EVENT_STABLE_INTERACT_START, unpause = EVENT_STABLE_INTERACT_END },
      interactionTypes = { INTERACTION_STABLE },
  },
  siege = {
      events = { pause =  EVENT_BEGIN_SIEGE_CONTROL, unpause = EVENT_END_SIEGE_CONTROL },
      interactionTypes = { INTERACTION_SIEGE },
  },
  housing = {
      events = { pause = EVENT_HOUSING_EDITOR_MODE_CHANGED, unpause = EVENT_HOUSING_EDITOR_MODE_CHANGED },
      active = function() return GetHousingEditorMode() ~= HOUSING_EDITOR_MODE_DISABLED end,
  },
  hideyHole = {
      events = { pause =  EVENT_CLIENT_INTERACT_RESULT, unpause = EVENT_CHATTER_END },
      active = function() return GetGameCameraInteractableActionInfo() == GetString(SI_GAMECAMERAACTIONTYPE24) end,
      --[[events = { pause =  EVENT_COMBAT_EVENT, unpause = EVENT_CHATTER_END },
      interactionTypes = { INTERACTION_HIDEYHOLE },
      combatEventFilters = {
          pause = {
              [REGISTER_FILTER_COMBAT_RESULT] = ACTION_RESULT_IN_HIDEYHOLE,
          }
      },]]
  },
  
  --[[ Still to add/test
  
       * pause and cancel keybinds
       * Fence
       * Repair
       * Harvest
       * Animations before chatter (e.g. respec shrine)
       * Siege repair
       * Structure repair
       * Quick slot
  ]]--
  
  --[[ Other scenes/actions that do not interrupt or get interrupted by opening containers:
  
       * Champion Point assignment
       * Quest journal
       * Crown store
       * Map
       * Port to friend/guildie
       * Port to wayshrine from map
       * Guild management
       * Group finder
       * Friends list
       * Attribute respec scroll
       * Skill respec scroll
       * Cutscene / kill cam / blade of woe
       * 
  ]]--
  --[[interacting = {
      callbacks = {
          pause = {
              { target = INTERACT_WINDOW, name = "Shown" },
          },
          unpause = {
              { target = INTERACT_WINDOW, name = "Hidden" },
              { target = HUD_SCENE, name = "Shown" },
          }
      },
      active = function() return INTERACT_WINDOW:IsInteracting() end,
  }]]--
}