AutoExtract = AutoExtract or {}
AutoExtract.name = "AutoExtract"
local queue = {}
local queueProcessing = false
local currentlyExtractedItem = nil
local unknownSurveyReportIds = {
  219849, -- Blacksmith
  219850, -- Clothier
  219851, -- Woodworker
  219852, -- Enchanter
  219853, -- Alchemist
  219854, -- Jewelry Crafter
}

local unknownMasterWritItemIds = {
  217917, -- Blacksmith
  217918, -- Clothier
  217919, -- Woodworker
  217920, -- Enchanter
  217921, -- Alchemist
  217923, -- Jewelry Crafter
}

local unknownOtherIds = {
  224681, -- Unopened Treasure Map
}

local function initExtractAllTranslations() 
  local lang = GetCVar("Language.2")
  if lang == "en" then ZO_CreateStringId("SI_EXTRACT_ALL", "Extract All") return end
  if lang == "de" then ZO_CreateStringId("SI_EXTRACT_ALL", "Alles Extrahieren") return end
  if lang == "fr" then ZO_CreateStringId("SI_EXTRACT_ALL", "Extraire Tout") return end
  if lang == "ru" then ZO_CreateStringId("SI_EXTRACT_ALL", "Извлечь Все") return end
  if lang == "ja" then ZO_CreateStringId("SI_EXTRACT_ALL", "すべて抽出") return end
  if lang == "zh" then ZO_CreateStringId("SI_EXTRACT_ALL", "提取全部") return end
  if lang == "es" then ZO_CreateStringId("SI_EXTRACT_ALL", "Extraer Todo") return end
  if lang == "it" then ZO_CreateStringId("SI_EXTRACT_ALL", "Estrai Tutto") return end
  if lang == "pl" then ZO_CreateStringId("SI_EXTRACT_ALL", "Ekstrahuj Wszystko") return end
  ZO_CreateStringId("SI_EXTRACT_ALL", "Extract All")
end

local function getExtractingLabel() 
  local lang = GetCVar("Language.2")
  if lang == "en" then return "Extracting" end
  if lang == "de" then return "Extrahiere" end
  if lang == "fr" then return "Extraction" end
  if lang == "ru" then return "Извлечение" end
  if lang == "ja" then return "抽出中" end
  if lang == "zh" then return "提取中" end
  if lang == "es" then return "Extrayendo" end
  if lang == "it" then return "Estrazione in corso" end
  if lang == "pl" then return "Ekstrahowanie" end
  return "Extracting"
end

local function getStopExtractionLabel()
  local lang = GetCVar("Language.2")
  if lang == "en" then return "Inventory full, stopping extraction." end
  if lang == "de" then return "Inventar voll, stoppe Extraktion." end
  if lang == "fr" then return "Inventaire plein, arrêt de l'extraction." end
  if lang == "ru" then return "Инвентарь полон, остановка извлечения." end
  if lang == "ja" then return "インベントリがいっぱいです。抽出を停止します。" end
  if lang == "zh" then return "背包已满，停止提取。" end
  if lang == "es" then return "Inventario lleno, deteniendo la extracción." end
  if lang == "it" then return "Inventario pieno, arresto dell'estrazione." end
  if lang == "pl" then return "Inventar pełny, zatrzymywanie ekstrakcji." end
  return "Inventory full, stopping extraction."
end

--- Function to check if a value exists in a table
--- @param table The table to search
--- @param value The value to search for
--- @return boolean True if the value is found, false otherwise
local function contains(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

--- Sends a chat message to the default chat window.
--- @param msg The message to send.
--- @param color The color of the message (optional). If not specified the color in the account-wide saved variable will be used.
local function sendChatMessage(msg, color)
    if not color then
        color = "FFFF00" -- default to yellow
    end
    if not LibChatMessage then
        CHAT_ROUTER:AddSystemMessage("|c" .. color .. msg .. "|r ")
        return
    end
    local chat = LibChatMessage("AutoExtract", "AutoExtract")
    LibChatMessage:SetTagPrefixMode(TAG_PREFIX_SHORT)
    chat:SetTagColor(color):Print("|c" .. color .. msg .. "|r ")
end

local function findInInventory(item) 
  for i=0, GetBagSize(BAG_BACKPACK) do
		if GetItemId(BAG_BACKPACK, i) == item.itemid then
      local _, stack = GetItemInfo(BAG_BACKPACK, i)
      if stack == item.amount then return BAG_BACKPACK, i end
		end
	end
  return nil, nil
end

local function processQueue()
  if #queue == 0 then return end
  if IsBankOpen() or IsGuildBankOpen() or IsUnitSwimming("player") or IsUnitInCombat("player") or IsLooting() then
    --d("Delaying extraction")
    return
  end
  if not TRIBUTE.gameFlowState == TRIBUTE_GAME_FLOW_STATE_INACTIVE then
    --d("Delaying extraction - ToT")
    return
  end
  --d("Processing extraction queue. Queue size: " .. #queue)
  local item = queue[1]
  --d("Processing itemid: " .. item.itemid .. " amount: " .. item.amount)
  local bag, slot = findInInventory(item)
  if bag and slot then
    --d("Found item in inventory, extracting.")
    local itemLink = GetItemLink(bag, slot, LINK_STYLE_BRACKETS)
    sendChatMessage(getExtractingLabel() .. " ".. itemLink)
    currentlyExtractedItem = item
    if IsProtectedFunction("UseItem") then
		  CallSecureProtected("UseItem", bag, slot)
	  else
  		UseItem(bag, slot)
    end
  else
    --d("Item not found in inventory")
    currentlyExtractedItem = nil
  end
end

local function combatChanged(_, inCombat)
  if not IsUnitInCombat("player") then processQueue() end
end

local function extractAll(bag, slot) 
	local itemLink = GetItemLink(bag, slot)
  local itemid = GetItemLinkItemId(itemLink)
  local _, stack = GetItemInfo(bag, slot)
  table.insert(queue, {itemid = itemid, amount = stack})
  if not queueProcessing then processQueue() end
end

local function gamepadInventoryHook(inventoryInfo, slotActions)
	if not IsInGamepadPreferredMode() and not IsConsoleUI() then
		return
	end
	if not inventoryInfo or not inventoryInfo.dataSource then
		return
	end
  if IsBankOpen() or IsGuildBankOpen() then
    return
  end
	local bag = inventoryInfo.dataSource.bagId
	local slot = inventoryInfo.dataSource.slotIndex
	local itemLink = GetItemLink(bag, slot)

  local itemid = GetItemLinkItemId(itemLink)
  --d("gamepadInventoryHook for itemid: " .. itemid)
  if contains(unknownSurveyReportIds, itemid) then
    slotActions:AddSlotAction(SI_EXTRACT_ALL, function() extractAll(bag, slot) end , "keybind3")
    return
  elseif contains(unknownMasterWritItemIds, itemid) then
    slotActions:AddSlotAction(SI_EXTRACT_ALL, function() extractAll(bag, slot) end , "keybind3")
    return
  elseif contains(unknownOtherIds, itemid) then
    slotActions:AddSlotAction(SI_EXTRACT_ALL, function() extractAll(bag, slot) end , "keybind3")
    return
  end
end

local function inventoryUpdated(eventCode, bagId, slotId, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange) 
  if #queue == 0 then return end
  if not currentlyExtractedItem then return end
  if bagId ~= BAG_BACKPACK then return end
  if not slotId then return end
  if inventoryUpdateReason ~= INVENTORY_UPDATE_REASON_DEFAULT then return end
  local itemLink = GetItemLink(bagId, slotId)
  local itemid = GetItemLinkItemId(itemLink)
  local itemType, specializedType = GetItemType(bagId, slotId)
  --d("inventoryUpdated for itemid: " .. itemid .. " stackChange: " .. stackCountChange)
  if (itemid == currentlyExtractedItem.itemid and stackCountChange == -1) or (itemid == 0 and stackCountChange == -1 and currentlyExtractedItem.amount == 1) then
    --d("Finished extracting itemid: " .. itemid)
    currentlyExtractedItem = nil
    local item = queue[1]
    if item.amount > 1 then
      item.amount = item.amount - 1
    else
      --d("Removing item from queue: " .. itemid)
      table.remove(queue, 1)
      return
    end
    local freespace = GetNumBagFreeSlots(bagId)
    if freespace == 0 then 
      sendChatMessage(getStopExtractionLabel(), "FF0000")
      queue = {}
      return 
    end
    zo_callLater(processQueue, 1000) -- wait 1000ms before processing next item
  end
end

local function startListeningForEvents()
  EVENT_MANAGER:RegisterForEvent(AutoExtract.name .. "_CloseBank", EVENT_CLOSE_BANK, processQueue)
  EVENT_MANAGER:RegisterForEvent(AutoExtract.name .. "_CloseStore",  EVENT_CLOSE_STORE, processQueue)
  EVENT_MANAGER:RegisterForEvent(AutoExtract.name .. "_CloseGuildBank", EVENT_CLOSE_GUILD_BANK, processQueue)
  EVENT_MANAGER:RegisterForEvent(AutoExtract.name .. "_EndSwimming", EVENT_PLAYER_NOT_SWIMMING, processQueue)
  EVENT_MANAGER:RegisterForEvent(AutoExtract.name .. "_CombatEnd",  EVENT_PLAYER_COMBAT_STATE, combatChanged)
  EVENT_MANAGER:RegisterForEvent(AutoExtract.name .. "_EndLooting", EVENT_LOOT_CLOSED, processQueue)
  EVENT_MANAGER:RegisterForEvent(AutoExtract.name .. "_EndCraftingStation", EVENT_END_CRAFTING_STATION_INTERACT, processQueue)
  EVENT_MANAGER:RegisterForEvent(AutoExtract.name .. "_InventoryUpdated",  EVENT_INVENTORY_SINGLE_SLOT_UPDATE, inventoryUpdated)
  EVENT_MANAGER:AddFilterForEvent(AutoExtract.name .. "_InventoryUpdated", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
end

-- Addon initialization
function AutoExtract.OnAddOnLoaded(event, addonName)
  if addonName ~= AutoExtract.name then return end

  initExtractAllTranslations()
  SecurePostHook(_G, "ZO_InventorySlot_DiscoverSlotActionsFromActionList", gamepadInventoryHook)
  startListeningForEvents()

  EVENT_MANAGER:UnregisterForEvent(AutoExtract.name .. "_Loaded", EVENT_ADD_ON_LOADED)  
end

EVENT_MANAGER:RegisterForEvent(AutoExtract.name .. "_Loaded", EVENT_ADD_ON_LOADED, AutoExtract.OnAddOnLoaded)
