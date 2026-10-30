-- Tracking/ItemDatabase.lua
local this = InventoryCompanion

local itemCountsCache = {}
local cacheInvalid = true
local runtimeRules, cachedSavedRules, cachedBaseline
local CompilePatterns
local customDisplayDefaults = {
    show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false,
}
local validatedSavedRules = setmetatable({}, { __mode = "k" })

local function CheckPatternList(patterns, context)
    assert(type(patterns) == "table", context .. " must be a dense array of strings")
    local count = 0
    for key, pattern in pairs(patterns) do
        assert(type(key) == "number" and key >= 1 and key % 1 == 0,
            context .. " must contain only positive integer indices")
        assert(type(pattern) == "string", context .. "[" .. tostring(key) .. "] must be a string")
        count = count + 1
    end
    for index = 1, count do
        assert(rawget(patterns, index) ~= nil, context .. " must not contain holes")
    end
end

local function ValidateSavedRules(rules, context)
    assert(type(rules) == "table", context .. " must be a table; saved data was not changed")
    for ruleName, saved in pairs(rules) do
        assert(type(ruleName) == "string" and ruleName ~= "", context .. " has an invalid rule key")
        local path = context .. "[" .. ruleName .. "]"
        assert(type(saved) == "table", path .. " must be a table")
        assert(saved.displayName == nil or type(saved.displayName) == "string",
            path .. ".displayName must be a string")
        for _, field in ipairs({ "patterns", "addedPatterns", "removedPatterns" }) do
            if saved[field] ~= nil then CheckPatternList(saved[field], path .. "." .. field) end
        end
        if saved.display ~= nil then
            assert(type(saved.display) == "table", path .. ".display must be a table")
            for key, value in pairs(saved.display) do
                assert(customDisplayDefaults[key] ~= nil, path .. ".display has an unknown flag: " .. tostring(key))
                assert(type(value) == "boolean", path .. ".display." .. key .. " must be boolean")
            end
        end
    end
end

local function LoadSavedRules(profile, context, initializeMissing)
    assert(type(profile) == "table", "Required profile is missing: " .. context)
    local rules = profile.trackedRules
    if rules == nil and initializeMissing then
        rules = {}
        profile.trackedRules = rules
    end
    if not validatedSavedRules[rules] then
        ValidateSavedRules(rules, context .. ".trackedRules")
        validatedSavedRules[rules] = true
    end
    return rules
end

function this.ValidateSavedRuleProfiles()
    assert(type(this.character.useCharacterItemList) == "boolean",
        "Character.useCharacterItemList must be boolean")
    LoadSavedRules(this.accountWide, "Account-wide", true)
    LoadSavedRules(this.character, "Character", true)
end

local function GetBaseline(ruleName)
    assert(type(ruleName) == "string" and ruleName ~= "", "Rule name must be a non-empty string")
    local base = this.preLoadedRulesets[ruleName]
    if base ~= nil then
        local context = "Built-in rule " .. ruleName
        assert(type(base) == "table", context .. " must be a table")
        assert(type(base.displayName) == "string", context .. ".displayName must be a string")
        CheckPatternList(base.patterns, context .. ".patterns")
        assert(type(base.display) == "table", context .. ".display must be a table")
        for flag in pairs(customDisplayDefaults) do
            assert(type(base.display[flag]) == "boolean", context .. ".display." .. flag .. " must be boolean")
        end
    end
    return base
end

local function GetDisplayDefaults(base)
    if base ~= nil then return base.display end
    return customDisplayDefaults
end

local function GetDefaultName(ruleName, base)
    if base ~= nil then return base.displayName end
    return ruleName
end

function this.InvalidateRuleCache()
    cacheInvalid = true
end

-- Items
function this.GetActiveTrackedItems()
    if this.character.useCharacterItemList then
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
    assert(type(this.character.useCharacterItemList) == "boolean", "Character list preference must be boolean")
    if this.character.useCharacterItemList then
        return LoadSavedRules(this.character, "Character")
    else
        return LoadSavedRules(this.accountWide, "Account-wide")
    end
end

local function PatternSet(patterns)
    CheckPatternList(patterns, "Rule patterns")
    local values = {}
    for _, pattern in ipairs(patterns) do
        values[pattern] = true
    end
    return values
end

local function SortedPatterns(values)
    local patterns = {}
    for pattern in pairs(values) do
        table.insert(patterns, pattern)
    end
    table.sort(patterns)
    return patterns
end

local function GetPatternList(base, saved)
    local values = {}
    if base ~= nil then values = PatternSet(base.patterns) end
    if saved.removedPatterns ~= nil then
        for _, pattern in ipairs(saved.removedPatterns) do values[pattern] = nil end
    end
    if saved.addedPatterns ~= nil then
        for _, pattern in ipairs(saved.addedPatterns) do values[pattern] = true end
    end
    return SortedPatterns(values)
end

local function ReconcilePatterns(base, saved, patterns)
    local defaults = {}
    if base ~= nil then defaults = PatternSet(base.patterns) end
    local edited = PatternSet(patterns)
    local added, removed = {}, {}
    for pattern in pairs(edited) do
        if not defaults[pattern] then added[pattern] = true end
    end
    for pattern in pairs(defaults) do
        if not edited[pattern] then removed[pattern] = true end
    end
    saved.addedPatterns = next(added) and SortedPatterns(added) or nil
    saved.removedPatterns = next(removed) and SortedPatterns(removed) or nil
    saved.patterns = nil
end

local function PruneRule(savedRules, ruleName)
    local saved = savedRules[ruleName]
    if saved.display ~= nil and not next(saved.display) then saved.display = nil end
    if this.preLoadedRulesets[ruleName] and not next(saved) then
        savedRules[ruleName] = nil
    end
end

local function NormalizeRule(savedRules, ruleName)
    local saved = savedRules[ruleName]
    local base = GetBaseline(ruleName)
    if saved.patterns ~= nil then
        ReconcilePatterns(base, saved, saved.patterns)
    end
    local defaultName = GetDefaultName(ruleName, base)
    if saved.displayName == defaultName then saved.displayName = nil end
    local defaults = GetDisplayDefaults(base)
    if saved.display ~= nil then
        for key, value in pairs(saved.display) do
            if value == defaults[key] then saved.display[key] = nil end
        end
    end
    PruneRule(savedRules, ruleName)
end

local function CopyValues(values)
    local copy = {}
    for key, value in pairs(values) do copy[key] = value end
    return copy
end

local function CopyOptionalValues(values)
    if values == nil then return nil end
    return CopyValues(values)
end

function this.PrepareSavedVariables()
    local saved = _G[this.SettingsName]
    if saved == nil then return end
    assert(type(saved) == "table", this.SettingsName .. " must be a table; initialization stopped")
    if saved.Default == nil then return end
    assert(type(saved.Default) == "table", this.SettingsName .. ".Default must be a table; initialization stopped")

    local profiles = {}
    for accountName, account in pairs(saved.Default) do
        local accountPath = this.SettingsName .. ".Default[" .. tostring(accountName) .. "]"
        assert(type(account) == "table", accountPath .. " must be a table; initialization stopped")
        for profileName, profile in pairs(account) do
            local context = accountPath .. "[" .. tostring(profileName) .. "]"
            assert(type(profile) == "table", context .. " must be a table; initialization stopped")
            local version = profile.version
            assert(type(version) == "number" and version >= 1 and version < math.huge and version % 1 == 0,
                context .. ".version must be a positive integer; saved data was not changed")
            assert(version <= this.SettingsVersion,
                string.format("[InventoryCompanion] %s uses saved-variable version %s, but this addon supports version %s. "
                    .. "Initialization stopped without changing saved data. Install a compatible newer addon or restore a compatible backup.",
                    context, tostring(version), tostring(this.SettingsVersion)))
            assert(version == this.SettingsVersion or (version == 1 and this.SettingsVersion == 2),
                context .. " has no supported migration from version " .. tostring(version)
                    .. " to version " .. tostring(this.SettingsVersion))
            table.insert(profiles, { data = profile, context = context })
        end
    end

    for ruleName in pairs(this.preLoadedRulesets) do GetBaseline(ruleName) end
    local migrations = {}
    for _, entry in ipairs(profiles) do
        local profile, context = entry.data, entry.context
        if profile.trackedRules ~= nil then
            ValidateSavedRules(profile.trackedRules, context .. ".trackedRules")
        end
        assert(profile.useCharacterItemList == nil or type(profile.useCharacterItemList) == "boolean",
            context .. ".useCharacterItemList must be boolean")
        if profile.version == 1 then
            local rules = {}
            if profile.trackedRules ~= nil then
                for ruleName, rule in pairs(profile.trackedRules) do
                    local copy = CopyValues(rule)
                    copy.display = CopyOptionalValues(rule.display)
                    rules[ruleName] = copy
                    NormalizeRule(rules, ruleName)
                end
            end
            table.insert(migrations, { profile = profile, rules = rules })
        end
    end

    -- Publish only after every profile has passed validation and conversion.
    for _, migration in ipairs(migrations) do
        migration.profile.trackedRules = migration.rules
        migration.profile.version = this.SettingsVersion
    end
    this.InvalidateRuleCache()
end

function this.GetRuntimeRules()
    local savedRules = GetRawSavedRules()
    if not cacheInvalid and cachedSavedRules == savedRules and cachedBaseline == this.preLoadedRulesets then
        return runtimeRules
    end
    cacheInvalid = true
    for ruleName in pairs(this.preLoadedRulesets) do GetBaseline(ruleName) end
    for ruleName in pairs(savedRules) do NormalizeRule(savedRules, ruleName) end
    local resolvedRules = {}
    local function Resolve(ruleName, base)
        local saved = savedRules[ruleName]
        if saved == nil then saved = {} end
        local display = {}
        for key, value in pairs(GetDisplayDefaults(base)) do
            display[key] = value
        end
        if saved.display ~= nil then
            for key, value in pairs(saved.display) do display[key] = value end
        end
        local patterns = GetPatternList(base, saved)
        local displayName = saved.displayName
        if displayName == nil then displayName = GetDefaultName(ruleName, base) end
        resolvedRules[ruleName] = {
            displayName = displayName,
            patterns = patterns,
            compiledPatterns = CompilePatterns(patterns),
            display = display,
            isPreloaded = base ~= nil,
        }
    end
    for ruleName, base in pairs(this.preLoadedRulesets) do Resolve(ruleName, base) end
    for ruleName in pairs(savedRules) do
        if not this.preLoadedRulesets[ruleName] then Resolve(ruleName) end
    end
    runtimeRules = resolvedRules
    cachedSavedRules, cachedBaseline = savedRules, this.preLoadedRulesets
    cacheInvalid = false
    return runtimeRules
end

function this.GetActiveTrackedRules(includeHidden)
    local rules = {}
    for ruleName, rule in pairs(this.GetRuntimeRules()) do
        if includeHidden or ruleName == "miscellaneous" or not rule.display.isHidden then
            -- Editors and HUD layout may change their view without changing cached rules.
            rules[ruleName] = {
                displayName = rule.displayName,
                patterns = CopyValues(rule.patterns),
                compiledPatterns = rule.compiledPatterns,
                display = CopyValues(rule.display),
                isPreloaded = rule.isPreloaded,
            }
        end
    end
    return rules
end

local trackerContextRevision = 0

function this.GetTrackerContext()
    return GetRawSavedRules(), trackerContextRevision
end

function this.SetUseCharacterItemList(value)
    assert(type(value) == "boolean", "Character list preference must be boolean")
    this.character.useCharacterItemList = value
    trackerContextRevision = trackerContextRevision + 1
    this.InvalidateRuleCache()
end

function this.UpdateRuleFlag(ruleName, flagKey, value)
    assert(customDisplayDefaults[flagKey] ~= nil, "Unknown rule display flag: " .. tostring(flagKey))
    assert(value == nil or type(value) == "boolean", "Rule display flags must be boolean or nil")
    local base = GetBaseline(ruleName)
    local savedRules = GetRawSavedRules()
    if savedRules[ruleName] == nil then savedRules[ruleName] = {} end
    local saved = savedRules[ruleName]
    local defaults = GetDisplayDefaults(base)
    if saved.display == nil then saved.display = {} end
    if value == defaults[flagKey] then value = nil end
    saved.display[flagKey] = value
    PruneRule(savedRules, ruleName)
    this.InvalidateRuleCache()
end

this.SetRuleFlag = this.UpdateRuleFlag

function this.UpdateRuleProperty(ruleName, propertyKey, value)
    assert(propertyKey == "displayName", "Use UpdateRulePatterns for pattern edits")
    assert(value == nil or type(value) == "string", "Rule display name must be a string or nil")
    local base = GetBaseline(ruleName)
    local savedRules = GetRawSavedRules()
    if savedRules[ruleName] == nil then savedRules[ruleName] = {} end
    if value == GetDefaultName(ruleName, base) then value = nil end
    savedRules[ruleName][propertyKey] = value
    PruneRule(savedRules, ruleName)
    this.InvalidateRuleCache()
end

function this.UpdateRulePatterns(ruleName, uiPatterns)
    assert(type(uiPatterns) == "table", "Rule patterns must be a list")
    -- Validate before creating an override, so failed edits leave saved state unchanged.
    PatternSet(uiPatterns)
    local base = GetBaseline(ruleName)
    local savedRules = GetRawSavedRules()
    if savedRules[ruleName] == nil then savedRules[ruleName] = {} end
    ReconcilePatterns(base, savedRules[ruleName], uiPatterns)
    PruneRule(savedRules, ruleName)
    this.InvalidateRuleCache()
end

function this.HasResettableRuleOverrides(ruleName)
    local saved = GetRawSavedRules()[ruleName]
    return saved ~= nil and (saved.displayName ~= nil or saved.patterns ~= nil
        or saved.addedPatterns ~= nil or saved.removedPatterns ~= nil)
end

function this.CreateCustomRule(ruleName, displayName)
    local savedRules = GetRawSavedRules()
    assert(not this.preLoadedRulesets[ruleName] and not savedRules[ruleName], "Rule already exists: " .. ruleName)
    this.UpdateRuleProperty(ruleName, "displayName", displayName)
end

function this.DeleteCustomRule(ruleName)
    assert(not this.preLoadedRulesets[ruleName], "Built-in rules cannot be deleted")
    GetRawSavedRules()[ruleName] = nil
    this.InvalidateRuleCache()
end

function this.ResetRule(ruleName)
    assert(this.preLoadedRulesets[ruleName], "Only built-in rules can be reset")
    local savedRules = GetRawSavedRules()
    local saved = savedRules[ruleName]
    if saved then
        saved.displayName = nil
        saved.patterns = nil
        saved.addedPatterns = nil
        saved.removedPatterns = nil
        PruneRule(savedRules, ruleName)
    end
    this.InvalidateRuleCache()
    trackerContextRevision = trackerContextRevision + 1
end

------------------------------------------------------------------
-- Profile Copying Logic
------------------------------------------------------------------
function this.CopyProfile(sourceKey)
    assert(type(sourceKey) == "string" and sourceKey ~= "", "Profile source key must be a non-empty string")
    local sv = _G[this.SettingsName]
    if sv == nil then return false end
    assert(type(sv) == "table", "Saved profile namespace must be a table")
    if sv.Default == nil then return false end
    assert(type(sv.Default) == "table", "Saved profile namespace.Default must be a table")

    local sourceBlock = nil

    for _, accData in pairs(sv.Default) do
        assert(type(accData) == "table", "Saved account profile block must be a table")
        if sourceKey == "$AccountWide" then
            if accData["$AccountWide"] ~= nil then
                sourceBlock = accData["$AccountWide"]
                break
            end
        else
            if accData[sourceKey] ~= nil then
                sourceBlock = accData[sourceKey]
                break
            end
        end
    end

    if sourceBlock == nil then return false end
    local context = "Imported profile " .. sourceKey
    assert(type(sourceBlock) == "table", context .. " must be a table")
    if sourceBlock.trackedRules ~= nil then
        ValidateSavedRules(sourceBlock.trackedRules, context .. ".trackedRules")
    end
    if sourceBlock.trackedItems ~= nil then
        assert(type(sourceBlock.trackedItems) == "table", context .. ".trackedItems must be a table")
        for itemId, data in pairs(sourceBlock.trackedItems) do
            local path = context .. ".trackedItems[" .. tostring(itemId) .. "]"
            assert(type(data) == "table", path .. " must be a table")
            if data.display ~= nil then
                assert(type(data.display) == "table", path .. ".display must be a table")
            end
        end
    end
    local destTable = this.GetActiveTrackedItems()
    local destRules = GetRawSavedRules()

    local copiedItems, copiedRules = {}, {}
    if sourceBlock.trackedItems ~= nil then
        for itemId, data in pairs(sourceBlock.trackedItems) do
            local srcDisplay = data.display or {}
            local mode = data.mode or 1
            copiedItems[itemId] = {
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

    if sourceBlock.trackedRules ~= nil then
        for ruleKey, ruleData in pairs(sourceBlock.trackedRules) do
            copiedRules[ruleKey] = {
                displayName = ruleData.displayName,
                patterns = CopyOptionalValues(ruleData.patterns),
                addedPatterns = CopyOptionalValues(ruleData.addedPatterns),
                removedPatterns = CopyOptionalValues(ruleData.removedPatterns),
                display = CopyOptionalValues(ruleData.display),
            }
            NormalizeRule(copiedRules, ruleKey)
        end
    end

    ZO_ClearTable(destTable)
    for key, value in pairs(copiedItems) do destTable[key] = value end
    ZO_ClearTable(destRules)
    for key, value in pairs(copiedRules) do destRules[key] = value end
    this.InvalidateRuleCache()
    trackerContextRevision = trackerContextRevision + 1
    return true
end

------------------------------------------------------------------
-- Pattern Compilation & Matching
------------------------------------------------------------------
CompilePatterns = function(patterns)
    local compiled = {}
    for _, pattern in ipairs(patterns) do
        if pattern ~= "" then
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
    end
    return compiled
end

function this.ItemMatchesRuntimeRule(itemLink, rule)
    local name = GetItemLinkName(itemLink)
    if not name then return false end
    local lowerName = name:lower()
    for _, pattern in ipairs(rule.compiledPatterns) do
        if lowerName:match(pattern) ~= nil then return true end
    end
    return false
end

function this.ItemMatchesRule(itemLink, pattern)
    local name = GetItemLinkName(itemLink)
    if not name then return false end
    local compiled = CompilePatterns({pattern})
    if not compiled[1] then return false end
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
    local trackedRules = this.GetRuntimeRules()
    
    local targetData = trackedList[itemId]
    local isNotified = targetData and targetData.display.notify

    if not isNotified then
        for ruleName, ruleData in pairs(trackedRules) do
            if (ruleName == "miscellaneous" or not ruleData.display.isHidden)
                and ruleData.display.notify and this.ItemMatchesRuntimeRule(itemLink, ruleData) then
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
        assert(type(ruleData.compiledPatterns) == "table", "Rule " .. ruleName .. " is missing compiledPatterns")
        compiledRules[ruleName] = ruleData.compiledPatterns
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