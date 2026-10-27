-- Tracking/ItemDatabase.lua
InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local itemCountsCache = {}

-- Items
function this.GetActiveTrackedItems()
    if this.character and this.character.useCharacterItemList then
        this.character.trackedItems = this.character.trackedItems or {}
        return this.character.trackedItems
    else
        this.accountWide.trackedItems = this.accountWide.trackedItems or {}
        return this.accountWide.trackedItems
    end
end

------------------------------------------------------------------
-- Rules
------------------------------------------------------------------
local function GetRawSavedRules()
    if this.character.useCharacterItemList then
        this.character.trackedRules = this.character.trackedRules or {}
        return this.character.trackedRules
    else
        this.accountWide.trackedRules = this.accountWide.trackedRules or {}
        return this.accountWide.trackedRules
    end
end

------------------------------------------------------------------
-- Get Active Tracked Rules 
------------------------------------------------------------------
function this.GetActiveTrackedRules(includeHidden)	 
	local resolvedRules = {}
    	
    -- 1. Load pre-defined rules as authoritative baseline defaults
    for ruleSlug, ruleData in pairs(this.preLoadedRulesets) do
        resolvedRules[ruleSlug] = {
            displayName = ruleData.displayName,
            patterns = ruleData.patterns,
            display = {
                show = ruleData.display.show,
                notify = ruleData.display.notify,
                bank = ruleData.display.bank,
                group = ruleData.display.group,
                isExpanded = ruleData.display.isExpanded,
                isHidden = ruleData.display.isHidden,
            },
            isPreloaded = true,
        }
    end
    	
    -- 2. Apply partial user saved overrides
    for key, savedData in pairs(GetRawSavedRules()) do
        if resolvedRules[key] then
            -- Pre-defined rule: only override properties explicitly modified by the user
            if savedData.displayName ~= nil then
                resolvedRules[key].displayName = savedData.displayName
            end
            if savedData.patterns ~= nil then
                resolvedRules[key].patterns = savedData.patterns
            end
            if savedData.display then
                for k, v in pairs(savedData.display) do
                    if v ~= nil then
                        resolvedRules[key].display[k] = v
                    end
                end
            end
        else
            -- Custom user-created group
            resolvedRules[key] = {
                displayName = savedData.displayName or key,
                patterns = savedData.patterns or {},
                display = savedData.display or { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false },
                isPreloaded = false,
            }
        end
    end
    
	-- 3. Filter out rules where isHidden == true (Excluding system fallback "miscellaneous")
    for ruleName, ruleData in pairs(resolvedRules) do
        if ruleName ~= "miscellaneous" and ruleData.display.isHidden == true and not includeHidden then
            resolvedRules[ruleName] = nil
        end
    end
    
    return resolvedRules
end


------------------------------------------------------------------
-- Set Rule Flag (Ephemeral Toggle Writer)
------------------------------------------------------------------
function this.SetRuleFlag(ruleName, flagKey, value)
    local savedRules = GetRawSavedRules()
    
    -- Ensure we only write the specific display flag, avoiding full pattern/name clones
    savedRules[ruleName] = savedRules[ruleName] or {}
    savedRules[ruleName].display = savedRules[ruleName].display or {}
    savedRules[ruleName].display[flagKey] = value
end

------------------------------------------------------------------
-- Profile Copying Logic
------------------------------------------------------------------
function this.CopyProfile(sourceKey)
    local sv = _G[this.SettingsName]
    if not sv or not sv.Default then return false end

    local sourceBlock = nil

    for _, accData in pairs(sv.Default) do
        if sourceKey == "$AccountWide" then
            if accData["$AccountWide"] then
                sourceBlock = accData["$AccountWide"]
                break
            end
        else
            if accData[sourceKey] then
                sourceBlock = accData[sourceKey]
                break
            end
        end
    end

    local destTable = this.GetActiveTrackedItems()
    local destRules = GetRawSavedRules()

    if sourceBlock and destTable and destRules then
        -- Copy Tracked Items
        ZO_ClearTable(destTable)
        if sourceBlock.trackedItems then
            for itemId, data in pairs(sourceBlock.trackedItems) do
                local srcDisplay = data.display or {}
                local mode = data.mode or 1
                destTable[itemId] = {
                    link = data.link,
                    icon = data.icon,
                    display = {
                        show = srcDisplay.show ~= false or (mode ~= 3),
                        notify = srcDisplay.notify == true or (mode == 2),
                        bank = srcDisplay.bank == true,
                        group = srcDisplay.group == true,
                    },
                }
            end
        end

        -- Copy Tracked Rule Overrides & Custom Rules
        ZO_ClearTable(destRules)
        if sourceBlock.trackedRules then
            for ruleKey, ruleData in pairs(sourceBlock.trackedRules) do -- NEW FOR KEY CHANGE
                local ruleDisplay = ruleData.display or {}
                destRules[ruleKey] = { -- NEW FOR KEY CHANGE
                    displayName = ruleData.displayName, -- NEW FOR KEY CHANGE
                    patterns = ruleData.patterns,
                    display = {
                        show = ruleDisplay.show ~= false,
                        notify = ruleDisplay.notify == true,
                        bank = ruleDisplay.bank == true,
                        group = ruleDisplay.group == true,
                        isExpanded = ruleDisplay.isExpanded,
                        isHidden = ruleDisplay.isHidden == true,
                    }
                }
            end
        end

        return true
    end

    return false
end

------------------------------------------------------------------
-- Pattern Compilation & Matching
------------------------------------------------------------------
local function CompilePatterns(patterns)
    local compiled = {}
    for _, pattern in ipairs(patterns or {}) do
        local cleaned = pattern:lower()
        if cleaned:find("*", 1, true) then
            local p = cleaned:gsub("([%^%$%(%)%%%.%[%+%-%?])", "%%%1")
            p = p:gsub("%*", ".*")
            table.insert(compiled, "^" .. p .. "$")
        else
            local p = cleaned:gsub("([%^%$%(%)%%%.%[%+%-%?])", "%%%1")
            table.insert(compiled, p)
        end
    end
    return compiled
end

function this.ItemMatchesRule(itemLink, pattern)
    local name = GetItemLinkName(itemLink)
    if not name then return false end
    local compiled = CompilePatterns({pattern})
    return name:lower():match(compiled[1]) ~= nil
end

function this.ItemMatchesAnyRule(itemLink, patterns)
    if not patterns then return false end
    for _, pattern in ipairs(patterns) do
        if this.ItemMatchesRule(itemLink, pattern) then
            return true
        end
    end
    return false
end

------------------------------------------------------------------
-- Update Display List
------------------------------------------------------------------

function this.GetTrackedItemCount(itemId)
    if not itemId then return 0 end

    local bagList = { BAG_BACKPACK }
    if IsESOPlusSubscriber() then
        table.insert(bagList, BAG_VIRTUAL)
    end

    local contents = this.Scanning.GetBagContents(bagList, function(item)
        return item.itemId == itemId
    end)

    local total = 0
    for _, item in ipairs(contents) do
        total = total + item.count
    end

    return total
end

function this.HandleTrackedItemInventoryUpdate(bagId, slotIndex, stackCountChange)
    if bagId ~= BAG_BACKPACK and bagId ~= BAG_VIRTUAL then return end

    local itemId = GetItemId(bagId, slotIndex)
    if not itemId or itemId <= 0 then return end

    local itemLink = GetItemLink(bagId, slotIndex)
    if not itemLink or itemLink == "" then return end

    local trackedList = this.GetActiveTrackedItems()
    local trackedRules = this.GetActiveTrackedRules()
    
    local targetData = trackedList[itemId]
    local isNotified = targetData and targetData.display.notify

    if not isNotified then
        for _, ruleData in pairs(trackedRules) do
            local patterns = ruleData.patterns or { ruleData.pattern }
            if (ruleData.display.notify) and this.ItemMatchesAnyRule(itemLink, patterns) then
                isNotified = true
                break
            end
        end
    end

    if isNotified then
        local currentCount = this.GetTrackedItemCount(itemId)
        local gained = (stackCountChange and stackCountChange > 0) and stackCountChange or 0

        if gained <= 0 then
            local previousCount = itemCountsCache[itemId] or currentCount
            gained = currentCount - previousCount
        end

        if gained > 0 then
		
			local formattedCount = this.Utils.FormatBigNumber(currentCount)
			local currentString = tostring(currentCount)

			local messageText = (formattedCount == currentString) and "You now have" or "You have about "

			local hud = string.format("Gained %d x %s. %s %s.", gained, itemLink, messageText, formattedCount)
			local chat = string.format("%d x %s (%s total)", gained, itemLink, currentString)

            this.Utils.UserWarning(chat, hud)
        end

        itemCountsCache[itemId] = currentCount
    end
end

------------------------------------------------------------------
-- Internal Helpers & Scan Engine
------------------------------------------------------------------
local function addToRuleIndex(ruleIndex, ruleName, itemId)
    ruleIndex[ruleName] = ruleIndex[ruleName] or {}
    local list = ruleIndex[ruleName]
    for _, id in ipairs(list) do
        if id == itemId then return end
    end
    table.insert(list, itemId)
end

local function findMatchingRulesCompiled(lowerName, compiledRules)
    local matchedRules = {}
    for ruleName, patterns in pairs(compiledRules) do
        for _, luaPattern in ipairs(patterns) do
            if lowerName:match(luaPattern) ~= nil then
                matchedRules[ruleName] = true
                break
            end
        end
    end
    return matchedRules
end

local function hasAnyMatch(matchedRules)
    for _ in pairs(matchedRules) do return true end
    return false
end

local function updateItemCounts(itemRecord, count, isBank)
    if not isBank then
        itemRecord.bagCount = itemRecord.bagCount + count
    end
    itemRecord.bankCount = itemRecord.bankCount + count
end

local function registerItemRules(itemRecord, ruleIndex, matchedRules, itemId)
    for ruleName in pairs(matchedRules) do
        itemRecord.matchedRules[ruleName] = true
        addToRuleIndex(ruleIndex, ruleName, itemId)
    end
end

local function evaluateAndRecordItem(masterItems, ruleIndex, trackedItems, compiledRules, itemData, isBank)
    local itemId = itemData.itemId
    local link = itemData.link
    local isTracked = trackedItems and trackedItems[itemId] ~= nil

    local itemName = GetItemLinkName(link)
    local lowerName = itemName and itemName:lower() or ""

    local matchedRules = findMatchingRulesCompiled(lowerName, compiledRules)

    if not isTracked and not hasAnyMatch(matchedRules) then return end

    if not masterItems[itemId] then
        masterItems[itemId] = {
            itemId = itemId,
            link = link,
            icon = itemData.icon or GetItemLinkIcon(link),
            bagCount = 0,
            bankCount = 0,
            matchedRules = {},
        }
    end

    local itemRecord = masterItems[itemId]
    updateItemCounts(itemRecord, itemData.count, isBank)
    registerItemRules(itemRecord, ruleIndex, matchedRules, itemId)
end

local function addRescuePassForTrackedItems(masterItems, trackedItems)
    if not trackedItems then return end
    
    for itemId, data in pairs(trackedItems) do
        if not masterItems[itemId] then
            masterItems[itemId] = {
                itemId = itemId,
                link = data.link,
                icon = data.icon or GetItemLinkIcon(data.link),
                bagCount = 0,
                bankCount = 0,
                matchedRules = {},
            }
        end
    end
end

function this.GetMasterItemList(trackedItems, activeRules, bagIdList)
    local masterItems = {}
    local ruleIndex = {}

    local compiledRules = {}
    for ruleName, ruleData in pairs(activeRules) do
        compiledRules[ruleName] = CompilePatterns(ruleData.patterns or { ruleData.pattern })
    end

    for _, bagId in ipairs(bagIdList) do
        local isBank = (bagId ~= BAG_BACKPACK)
        local contents = this.Scanning.GetBagContents({ bagId })
        for _, itemData in ipairs(contents) do
            evaluateAndRecordItem(masterItems, ruleIndex, trackedItems, compiledRules, itemData, isBank)
        end
    end

    addRescuePassForTrackedItems(masterItems, trackedItems)

    return {
        items = masterItems,
        ruleIndex = ruleIndex,
    }
end