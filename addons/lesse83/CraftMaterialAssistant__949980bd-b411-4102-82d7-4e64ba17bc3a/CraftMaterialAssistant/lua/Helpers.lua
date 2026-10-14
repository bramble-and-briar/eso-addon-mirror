local CMA = CraftMaterialAssistant

-- output formatted chat messages with an add-on tag
function CMA:SendChatMessage(message)
    d("|cFFD700[CraftMaterialAssistant]|r " .. message)
end

-- send formatted message concatenating items in a table. limit item count per message.
function CMA:SendChatMessageLimitedItemCount(message, items)
    local chunks = {}
    local totalItemCount = #items

    -- create sized junks with items
    for i = 1, totalItemCount, self.maxChatMessageItems do
        local startIndex = i
        local endIndex = math.min(i + self.maxChatMessageItems - 1, totalItemCount)
        table.insert(chunks, table.concat(items, ", ", startIndex, endIndex))
    end
    -- iterate over the junks and print them
    for i = 1, #chunks do
        self:SendChatMessage(message .. chunks[i])
    end
end

-- Helper function to convert id64 to string safely
function CMA:GetUniqueIdString(bagId, slotIndex)
    local uniqueId = GetItemUniqueId(bagId, slotIndex)
    if uniqueId then
        return Id64ToString(uniqueId)
    end
    return nil
end

-- find an item by its uniqueId in a bag
function CMA:findItemByUniqueId(bagId, searchedUniqueId)
    local maxSlots = GetBagSize(bagId)
    for slotIndex = 0, maxSlots do
        if HasItemInSlot(bagId, slotIndex) then
            local uniqueId = self:GetUniqueIdString(bagId, slotIndex)
            if uniqueId == searchedUniqueId then
                return bagId, slotIndex
            end
        end
    end
    return nil, nil
end

-- string explode function splitting a string into substrings (delimited by the separator)
function CMA:StringExplode(text, separator)
  local result = {}
  for substring in string.gmatch(text, "([^"..separator.."]+)") do
    table.insert(result, substring)
  end
  return result
end

-- scan the bank and fill the cachedBankSlots
function CMA:ScanAndMapBankSlots(bag)
    -- iterate through the bag and get the items
    local slot = ZO_GetNextBagSlotIndex(bag)
    while slot do
        if HasItemInSlot(bag, slot) then
            local itemId = GetItemId(bag, slot)
            if self.cachedBankSlots[itemId] then
                -- another slot already features that itemId - attach as comma separated values
                self.cachedBankSlots[itemId][1] = self.cachedBankSlots[itemId][1] + 1
                self.cachedBankSlots[itemId][2] = self.cachedBankSlots[itemId][2] .. self.cachedBankSlotSeparator .. slot
            else
                -- item id not in the map so far - initialize it with the item
                self.cachedBankSlots[itemId] = {1, slot}
            end
        end
        -- go on with the next slot, if available
        slot = ZO_GetNextBagSlotIndex(bag, slot)
    end
end

-- check if there is a slot that item is already present and get the best fitting slotIndex if there are multiple
function CMA:GetBestFitMapSlot(bag, itemId, stackSizeToDeposit)
    -- check if there are items with that id in the bank
    if self.cachedBankSlots[itemId] then
        -- found at least one stack
        if(self.cachedBankSlots[itemId][1] == 1) then
            -- only one option, check if the stack size would fit
            local currentStackSize, maxStackSize = GetSlotStackSize(bag, self.cachedBankSlots[itemId][2])
            if (maxStackSize - currentStackSize - stackSizeToDeposit) > 0 then
                -- there is space, return the slotIndex
                return self.cachedBankSlots[itemId][2]
            else
                -- no space for it
                return nil
            end
        else
            -- multiple options - iterate them and look where it fits and the left space is smallest
            local possibleSlots = self:StringExplode(self.cachedBankSlots[itemId][2], self.cachedBankSlotSeparator)
            local smallestDifferenceValue = math.huge
            local smallestDifferenceIndex = -1
            -- iterate over slots
            for i = 1, #possibleSlots do
                local currentStackSize, maxStackSize = GetSlotStackSize(bag, possibleSlots[i])
                local computedNewStackSize = maxStackSize - currentStackSize - stackSizeToDeposit
                -- only remember slot if it fits and is the best fitting
                if (computedNewStackSize >= 0) and (computedNewStackSize < smallestDifferenceValue) then
                    smallestDifferenceValue = computedNewStackSize
                    smallestDifferenceIndex = possibleSlots[i]
                end
            end
            -- now check if there was something found to be merged with
            if smallestDifferenceIndex ~= -1 then
                -- one optimal was found, return the slotIndex
                return smallestDifferenceIndex
            else
                -- no fitting space amongst them
                return nil
            end
        end
    else
        -- no stack with that item so far -> return nil
        return nil
    end
end

-- Helpers for custom item rules --------------------------------------------------------------------------------

-- serialize a table as string
function CMA:serializeCustomItemRuleTable(t)
    local serialized = {}
    for k, v in pairs(t) do
        table.insert(serialized, tostring(k) .. ":" .. tostring(v[1]) .. "." .. tostring(v[2]) .. "." .. tostring(v[3]))
    end
    return table.concat(serialized, ";")
end

-- deserialize a string as table
function CMA:deserializeCustomItemRuleTable(serializedString)
    local t = {}
    -- Look for key:value blocks split by semicolons
    for pair in string.gmatch(serializedString, "[^;]+") do
        local key, val = string.match(pair, "([^:]+):([^:]+)")
        if key and val then
            local val1, val2, val3 = string.match(val, "([^.]+).([^.]+).([^.]+)")
            if val1 and val2 and val3 then
                t[key] = {val1, val2, val3}
            end
        end
    end
    return t
end

function CMA:updateItemRulesDropdown(selection)
    -- reset the names and values of the dropdown
    for k, v in pairs(self.customItemRuleTable) do
        table.insert(self.customItemRuleDropdownNames, v[1] .. " (" .. v[3] .. ")")
        table.insert(self.customItemRuleDropdownValues, v[2])
        self.customItemRuleSelection = selection
    end
end

-- add a custom rule to the persisted rules table
function CMA:CustomItemRuleAdd(customRuleName, customRuleItemId, customRuleAction)
    -- ensure that the data is present (=non empty)
    if
        customRuleName == nil or customRuleName == "" or string.find(customRuleName, ".", 1, true) or string.find(customRuleName, ":", 1, true) or string.find(customRuleName, ";", 1, true) or
        customRuleItemId == nil or customRuleItemId == "" or not tonumber(customRuleItemId) or
        customRuleAction == nil or customRuleAction == "" or string.find(customRuleAction, ".", 1, true) or string.find(customRuleAction, ":", 1, true) or string.find(customRuleAction, ";", 1, true)
    then
        -- fields are empty, return values as they are
        self:SendChatMessage("Failed to add custom rule: At least one field (Name, ItemId, Action) is empty or contains ';' or '.' or ':'.")
        return customRuleName, customRuleItemId, customRuleAction
    end
    if self.customItemRuleTable[customRuleItemId] then
        -- already present, update the values
        self.customItemRuleTable[customRuleItemId][1] = customRuleName
        self.customItemRuleTable[customRuleItemId][2] = customRuleItemId
        self.customItemRuleTable[customRuleItemId][3] = customRuleAction
    else
        -- not present, add them
        self.customItemRuleTable[customRuleItemId] = {customRuleName, customRuleItemId, customRuleAction}
    end
    -- rebuild the dropdown 
    self:updateItemRulesDropdown(customRuleItemId)
    -- serialize the table
    self.db.serializedCustomItemRules = self:serializeCustomItemRuleTable(self.customItemRuleTable)
    -- if it was successful clear the fields
    return "", "", ""
end

-- remove the rule having customRuleItemId from the persisted rules table
function CMA:CustomItemRuleRemove(customRuleItemId)
        -- ensure that the data is present (=non empty)
    if
        customRuleItemId == nil or customRuleItemId == ""
    then
        -- fields are empty, return values as they are
        self:SendChatMessage("Failed to remove custom rule: Nothing selected")
        return nil
    end
    -- iterate over the items (backwards due to index reshifting when removing) and remove item if if ItemId matches the element
    if self.customItemRuleTable[customRuleItemId] then
        self.customItemRuleTable[customRuleItemId] = nil
        -- rebuild the dropdown 
        self:updateItemRulesDropdown(customRuleItemId)
        -- serialize the table
        self.db.serializedCustomItemRules = self:serializeCustomItemRuleTable(self.customItemRuleTable)
    else
        self:SendChatMessage("Failed to remove custom rule: " .. tostring(customRuleItemId))
    end
end

function CMA:CustomItemRuleListItems(bag)
    self:SendChatMessage("-- ItemIds of items in bag (Name: ItemId) --")
    -- iterate through the bag and get the items
    local slot = ZO_GetNextBagSlotIndex(bag)
    while slot do
        if HasItemInSlot(bag, slot) then
            local itemLink = GetItemLink(bag, slot)
            local itemId = GetItemId(bag, slot)
            self:SendChatMessage(itemLink .. ": " .. itemId)
        end
        -- go on with the next slot, if available
        slot = ZO_GetNextBagSlotIndex(bag, slot)
    end
end

function CMA:CustomItemRuleReloadUI()
    ReloadUI()
end