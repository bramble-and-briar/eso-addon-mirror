AutoBindSetItems = AutoBindSetItems or {}
AutoBindSetItems.defaultSettings = {
    enabled = true,
    message = true,
    sharegear = true,
    msgcolor = {r = 0, g = 1, b = 0},
    shareuncollected = false,
    debug = false,
}
AutoBindSetItems.queue = {}
AutoBindSetItems.recents = {}
AutoBindSetItems.gearqueue = {}
AutoBindSetItems.newGearQueue = false
AutoBindSetItems.testInCombat = false

local function checkInQueues(itemName)
  for _, queuedItem in ipairs(AutoBindSetItems.queue) do
    if queuedItem.name == itemName then
      return true
    end
  end
  for _, recentItem in ipairs(AutoBindSetItems.recents) do
    if recentItem.name == itemName then
      return true
    end
  end
  return false
end

--- Returns the localized string for the given key based on the current language setting
--- @param key string The key to localize
function AutoBindSetItems.L(key)
  return AutoBindSetItems.strings[key] or AutoBindSetItems.strings[key]
end

--- Places a message in the chat window in a safe manner
function AutoBindSetItems.SafeStartChatInput(text, channel, target)
    local isRestrictedCommunicationPermitted = true
    if target ~= nil and IsCommunicationRestricted() then
        isRestrictedCommunicationPermitted = CanCommunicateWith(target)
    end
    if IsChatSystemAvailableForCurrentPlatform() and isRestrictedCommunicationPermitted then
        ZO_GetChatSystem():StartTextEntry(text, channel, target, true)
        -- CallSecureProtected("ZO_GetChatSystem():StartTextEntry", text, channel, target, false)
    end
end

--- Convert rgb to #ffggbb
--- @param r number The red component (0-255)
--- @param g number The green component (0-255)
--- @param b number The blue component (0-255)
function AutoBindSetItems.RGBToHex(r, g, b)
  -- Clamp values to range 0–255
  r = math.max(0, math.min(255, r))
  g = math.max(0, math.min(255, g))
  b = math.max(0, math.min(255, b))
  
  return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

--- Combat Change Event Handler
--- This function is called when the player's combat state changes
--- If the player is in not combat, it will start the processing of the auto-bind queue
--- @param isFighting boolean Indicates whether the player is currently in combat
function AutoBindSetItems:combatStateChanged(isFighting) 
  if AutoBindSetItems.savedVars.debug then d("combatStateChanged - isFighting: " .. tostring(isFighting)) end
  if not IsUnitInCombat("player") then 
    EVENT_MANAGER:UnregisterForEvent(AutoBindSetItems.name .. "_CombatChanged", EVENT_PLAYER_COMBAT_STATE)
    AutoBindSetItems.processQueue()
  end
end

function AutoBindSetItems.doBind(bagId, slotIndex)
  if AutoBindSetItems.savedVars.debug then d("doBind - bagId: " .. tostring(bagId) .. " slotIndex: " .. tostring(slotIndex)) end
  table.insert(AutoBindSetItems.recents, {bagId = bagId, slotIndex = slotIndex, name = GetItemName(bagId, slotIndex)})
  BindItem(bagId, slotIndex)
  if AutoBindSetItems.savedVars.message then
    local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)  
    local chat = LibChatMessage("AutoBind", "AutoBind")
    LibChatMessage:SetTagPrefixMode(TAG_PREFIX_SHORT)
      local msgcolor = AutoBindSetItems.RGBToHex(AutoBindSetItems.savedVars.msgcolor.r, AutoBindSetItems.savedVars.msgcolor.g, AutoBindSetItems.savedVars.msgcolor.b)
      chat:SetTagColor(msgcolor):Print("|c" .. msgcolor .. AutoBindSetItems.L("SI_AUTOBIND_BINDING_MESSAGE") .. "|r " .. itemLink)
  end
end

function AutoBindSetItems.queueItem(bagId, slotIndex)
  if AutoBindSetItems.savedVars.debug then d("queueItem - bagId: " .. tostring(bagId) .. " slotIndex: " .. tostring(slotIndex)) end
  AutoBindSetItems.queue = AutoBindSetItems.queue or {}
  local currentItem = {}
  currentItem.bagId = bagId
  currentItem.slotIndex = slotIndex
  currentItem.name = GetItemName(bagId, slotIndex)
  -- Check if item with same name already exists in queue

  if checkInQueues(currentItem.name) then 
    if AutoBindSetItems.savedVars.debug then d("Item already queued: " .. currentItem.name) end
    return 
  end
  table.insert(AutoBindSetItems.queue, currentItem)
  -- AutoBindSetItems.test = AutoBindSetItems.test + 1
  -- d("Process queue - size = " .. #AutoBindSetItems.queue)
  -- d('AutoBindSetItems.test = ' .. AutoBindSetItems.test)
  EVENT_MANAGER:RegisterForEvent(AutoBindSetItems.name .. "_CombatChanged", EVENT_PLAYER_COMBAT_STATE, AutoBindSetItems.combatStateChanged)
end

function AutoBindSetItems.processQueue()
  if AutoBindSetItems.savedVars.debug then d("processQueue - size = " .. #AutoBindSetItems.queue) end
  if ZO_IsTableEmpty(AutoBindSetItems.queue) then return end
  local next = table.remove(AutoBindSetItems.queue) -- removed the last item added to the queue
  if not next then return end
  local name = next.name
  local bagId = next.bagId
  local slotIndex = next.slotIndex
  if name == GetItemName(bagId, slotIndex) then AutoBindSetItems.TryAutoBindItem(bagId, slotIndex) end
  if not ZO_IsTableEmpty(AutoBindSetItems.queue) then zo_callLater(AutoBindSetItems.processQueue, 1000) end
end

--- Tries to auto-bind an item in the player's inventory from the queue of items to bind
--- If the player is in combat, it will queue the item for later binding and registers the combat state change event
--- If the player is not in combat, it will bind the item immediately and unregister the combat state change event
--- If called without parameters, it will process the queue of items to bind and takes the last item from the queue and call this function to bind the item and schedule another call of this function without paramaters to progress the queue
--- Progressing through the queue asychronize ensures that the add-on will not go over the alloted time for add-ons 
--- @param bagId number The bag ID of the item to bind
--- @param slotIndex number The slot index of the item to bind
function AutoBindSetItems.TryAutoBindItem(bagId, slotIndex)
  if AutoBindSetItems.savedVars.debug then d("TryAutoBindItem - bagId: " .. tostring(bagId) .. " slotIndex: " .. tostring(slotIndex) .. " testInCombat: " .. tostring(AutoBindSetItems.testInCombat)) end
  if AutoBindSetItems.savedVars.debug and AutoBindSetItems.testInCombat then 
    if bagId and slotIndex and not IsUnitInCombat("player") and not AutoBindSetItems.testInCombat then
      AutoBindSetItems.doBind(bagId, slotIndex)
    elseif bagId and slotIndex and (IsUnitInCombat("player") or AutoBindSetItems.testInCombat) then
      AutoBindSetItems.queueItem(bagId, slotIndex)
      zo_callLater(function() 
          d("Set testInCombat = false") 
          AutoBindSetItems.testInCombat = false
        end
      , 5000)
      EVENT_MANAGER:RegisterForEvent(AutoBindSetItems.name .. "_CombatChanged", EVENT_PLAYER_COMBAT_STATE, AutoBindSetItems.combatStateChanged)
    end
  else
    if bagId and slotIndex and not IsUnitInCombat("player") then
      AutoBindSetItems.doBind(bagId, slotIndex)
    elseif bagId and slotIndex and IsUnitInCombat("player") then
      AutoBindSetItems.queueItem(bagId, slotIndex)
      EVENT_MANAGER:RegisterForEvent(AutoBindSetItems.name .. "_CombatChanged", EVENT_PLAYER_COMBAT_STATE, AutoBindSetItems.combatStateChanged)
    end
  end
end

--- Event handler for inventory slot updates
--- This function checks if the item is a set collection piece and if it is not unlocked, it will add it to the auto-bind queue
--- and calls the try autobind function to start binding items (if possible at this moment)
--- @param bagId number The bag ID of the item
--- @param slotIndex number The slot index of the item
--- @param reason number The reason for the inventory update (e.g., default, item moved, etc.)
--- @return nil
function AutoBindSetItems:OnInventorySlotUpdate(bagId, slotIndex, previousSlotData, isLastUpdateForMessage)
  if AutoBindSetItems.savedVars.debug then d("OnInventorySlotUpdate - bagId: " .. tostring(bagId) .. " slotIndex: " .. tostring(slotIndex)) end
  local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
  if not IsItemLinkSetCollectionPiece(itemLink) then return end
  if AutoBindSetItems.savedVars.debug then d("Is Set Collection Piece") end
  if IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(itemLink)) then return end
  if AutoBindSetItems.savedVars.debug then d("Is Not Unlocked") end
  local itemName = GetItemName(bagId, slotIndex)
  if checkInQueues(itemName) then 
    if AutoBindSetItems.savedVars.debug then d("Item already queued: " .. itemName) end
    return 
  end

  if not AutoBindSetItems.savedVars.enabled then return end
  if AutoBindSetItems.savedVars.debug then d("Determine if it is an uncollected set item: " .. itemLink) end
  local hasSet, setName, numBonuses, numNormalEquipped, maxEquipped, setId, numPerfectedEquipped = GetItemLinkSetInfo(itemLink, false)
  if not hasSet then end
  if AutoBindSetItems.savedVars.debug then d("Detected uncollected set item: " .. itemLink) end
  AutoBindSetItems.TryAutoBindItem(bagId, slotIndex)
end

--- Sends a message in the group chat with the items in the gear queue 
--- If the gear queue is empty, it will notify the user that there are no items to share
--- If the gear queue contains a newly created list of items to share, a message will be posted that this is the start of Start of the list of items to share
--- If the gear queue contains items, it will send them in a message, splitting them into multiple messages if necessary
function AutoBindSetItems.SendShareGearMessage() 
    local chat = LibChatMessage("AutoBind", "AutoBind")
    local msgcolor = AutoBindSetItems.RGBToHex(AutoBindSetItems.savedVars.msgcolor.r, AutoBindSetItems.savedVars.msgcolor.g, AutoBindSetItems.savedVars.msgcolor.b)
    if #AutoBindSetItems.gearqueue == 0 then 
      chat:SetTagColor(msgcolor):Print(AutoBindSetItems.L("SI_NOTHING_TO_SHARE"))
      return
    end
    if AutoBindSetItems.newGearQueue then
      chat:SetTagColor(msgcolor):Print(AutoBindSetItems.L("NEW_GEAR_QUEUE"))
      AutoBindSetItems.newGearQueue = false
    end 
    local msg = ""
    local i = 1
    local toolong = false
    repeat 
      local itemLink = table.remove(AutoBindSetItems.gearqueue, 1)
      if string.len(msg) + string.len(itemLink) > 345 then
        table.insert(AutoBindSetItems.gearqueue, itemLink)
        toolong = true
      else 
        msg = msg .. itemLink .. " "
      end
    until #AutoBindSetItems.gearqueue == 0 or toolong == true
    if msg and msg ~= "" then
      if #AutoBindSetItems.gearqueue > 0 then msg = msg .. "..." end
      ZO_GetChatSystem():Maximize()
      AutoBindSetItems.SafeStartChatInput(msg)
    end
end

--- Returns true if the inventory item is a gear item from a collectible set and is shareable with other group members
--- @param bagId number
--- @param slotIndex number
--- @return boolean
function AutoBindSetItems.IsGearTradable(bagId, slotIndex, dungeonOrTrialGearOnly)
    if AutoBindSetItems.savedVars.debug then d("IsGearTradable - bagId: " .. tostring(bagId) .. " slotIndex: " .. tostring(slotIndex) .. " dungeonOrTrialGearOnly: " .. tostring(dungeonOrTrialGearOnly)) end
    if not bagId or not slotIndex then return false end
    if IsItemBound(bagId, slotIndex) then return false end
    local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
    if not IsItemLinkSetCollectionPiece(itemLink) then return false end
    local tradeTime = GetItemBoPTimeRemainingSeconds(bagId, slotIndex)
    if AutoBindSetItems.savedVars.debug then d("IsGearTradable - itemLink: " .. itemLink .. " tradeTime: " .. tostring(tradeTime) .. " dungeonOrTrialGearOnly: " .. tostring(dungeonOrTrialGearOnly)) end
    if dungeonOrTrialGearOnly then
      return tradeTime and tradeTime > 0
    else
      if tradeTime and tradeTime > 0 then return false end
    end
    return true
end

--- Checks if the player is in a group dungeon or trial
--- @return boolean
function AutoBindSetItems.IsInGroupDungeonOrTrial()
    if not IsUnitInDungeon("player") then return false end
    local difficulty = GetCurrentZoneDungeonDifficulty()
    return difficulty == DUNGEON_DIFFICULTY_NORMAL or difficulty == DUNGEON_DIFFICULTY_VETERAN
end

--- Returns a list of tradable gear items from the player's inventory
--- @return table
--- @return string[] list of item links
function AutoBindSetItems.getGearToShareFromInventory()
  if AutoBindSetItems.savedVars.debug then d("getGearToShareFromInventory") end
  local shareGearQueue = {}
  local checkQueue = {}
  local isInDungeon = AutoBindSetItems.IsInGroupDungeonOrTrial()
  for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
    if HasItemInSlot(BAG_BACKPACK, slotIndex) then
      local itemLink = GetItemLink(BAG_BACKPACK, slotIndex, LINK_STYLE_BRACKETS)
      if AutoBindSetItems.IsGearTradable(BAG_BACKPACK, slotIndex, isInDungeon) and IsItemLinkSetCollectionPiece(itemLink) then
        if AutoBindSetItems.savedVars.shareuncollected == true or IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(itemLink))  then
          local itemId = GetItemLinkItemId(itemLink)
          if not checkQueue[itemId] then
              checkQueue[itemId] = true
              table.insert(shareGearQueue, itemLink)  
          end
        end
      end
    end
  end
  AutoBindSetItems.newGearQueue = true
  if AutoBindSetItems.savedVars.debug then d("getGearToShareFromInventory - found " .. #shareGearQueue .. " items to share.") end
  return shareGearQueue
end

--- Called when the share gear button is clicked 
--- If the share gear feature is enabled and there are items in the gear queue, it sends a message with the items to share
--- If the gear queue is empty, it will first populates it with items from the player's inventory that are tradable
function AutoBindSetItems.OnShareGearButtonClicked()
    if not AutoBindSetItems.savedVars.sharegear then return end
    if not AutoBindSetItems.gearqueue or #AutoBindSetItems.gearqueue == 0 then
        AutoBindSetItems.gearqueue = AutoBindSetItems.getGearToShareFromInventory()
    end
    AutoBindSetItems.SendShareGearMessage()
end

--- Defines the Share Gear button
AutoBindSetItems.shareButton = {
    name = AutoBindSetItems.L("SHARE_BUTTON"),
    keybind = "UI_SHORTCUT_QUATERNARY",
    callback = function(input, input2) AutoBindSetItems.OnShareGearButtonClicked() end,
    visible = function()
        return AutoBindSetItems.savedVars.sharegear and not IsUnitInCombat("player")
        --return AutoBindSetItems.savedVars.sharegear and GetGroupSize() > 0 and not IsUnitInCombat("player")
    end,
}

function AutoBindSetItems.toggleTestInCombat()
  AutoBindSetItems.testInCombat = not AutoBindSetItems.testInCombat
  local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.ACHIEVEMENT_AWARDED)
  params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_CRAFTING_RESULTS)
  params:SetText("AutoBind testInCombat = " .. tostring(AutoBindSetItems.testInCombat))
  CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
end

--- Register the /sharegear command
function AutoBindSetItems.RegisterSlashCommands()
  if AutoBindSetItems.savedVars.debug then d("RegisterSlashCommands") end
  SLASH_COMMANDS["/sharegear"] = function()
    AutoBindSetItems.OnShareGearButtonClicked()
  end
  SLASH_COMMANDS["/ab_toggleincombat"] = function()
    AutoBindSetItems.toggleTestInCombat()
  end
end

--- Apply bugfixes between versions
function AutoBindSetItems.BugFixes()
    if not AutoBindSetItems.savedVars.colorFix then
      if AutoBindSetItems.savedVars.msgcolor.r > 1 then AutoBindSetItems.savedVars.msgcolor.r = 1 end
      if AutoBindSetItems.savedVars.msgcolor.g > 1 then AutoBindSetItems.savedVars.msgcolor.g = 1 end
      if AutoBindSetItems.savedVars.msgcolor.b > 1 then AutoBindSetItems.savedVars.msgcolor.b = 1 end
	  AutoBindSetItems.savedVars.colorFix = true
	end
end

--- Called when the inventory scene state changes
--- If the Inventory screen keystrip does not yet contain the Share Gear button it will add it to the keystrip
---@param oldState any
---@param newState any
function AutoBindSetItems:OnInventorySceneStateChange(newState)
    --d("OnInventorySceneStateChange - newState: " .. tostring(newState))
    if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
      --d("SCENE_SHOWING")
        if GAMEPAD_INVENTORY then
            --d("GAMEPAD_INVENTORY")
            -- Prevent duplicate buttons
            local found = false
            for _, btn in ipairs(GAMEPAD_INVENTORY.categoryListKeybindStripDescriptor) do
                if btn == AutoBindSetItems.shareButton then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(GAMEPAD_INVENTORY.categoryListKeybindStripDescriptor, AutoBindSetItems.shareButton)
                -- Workaround to refresh the keystrip the first time the button is added, else it will only show up the second time the user goes into the Inventory menu
                SCENE_MANAGER:Hide("gamepad_inventory_root")
                SCENE_MANAGER:Show("gamepad_inventory_root")
            end
        end
    end
end

--- Called when the add-on is loaded
--- This function initializes the add-on, registers events, and sets up the settings menu. 
---@param event any
---@param addonName any
function AutoBindSetItems.OnAddOnLoaded(event, addonName)
  if addonName ~= AutoBindSetItems.name then return end
  EVENT_MANAGER:UnregisterForEvent(AutoBindSetItems.name .. "_Loaded", EVENT_ADD_ON_LOADED)
  
  AutoBindSetItems.savedVars = ZO_SavedVars:NewAccountWide("AutoBindSetItemsSaved", 1, nil, AutoBindSetItems.defaultSettings)
  
  AutoBindSetItems.BugFixes()
  AutoBindSetItems.CreateSettingsMenu()
  AutoBindSetItems.RegisterSlashCommands()

  EVENT_MANAGER:RegisterForEvent(AutoBindSetItems.name .. "_InventorySlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, AutoBindSetItems.OnInventorySlotUpdate)
  EVENT_MANAGER:AddFilterForEvent(AutoBindSetItems.name .. "_InventorySlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
  EVENT_MANAGER:AddFilterForEvent(AutoBindSetItems.name .. "_InventorySlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
  EVENT_MANAGER:AddFilterForEvent(AutoBindSetItems.name .. "_InventorySlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM, true)

  if SCENE_MANAGER then
      local scene = SCENE_MANAGER:GetScene("gamepad_inventory_root")
      if scene then
          scene:RegisterCallback("StateChange", AutoBindSetItems.OnInventorySceneStateChange)
      end
  end

end

EVENT_MANAGER:RegisterForEvent(AutoBindSetItems.name .. "_Loaded", EVENT_ADD_ON_LOADED, AutoBindSetItems.OnAddOnLoaded)
