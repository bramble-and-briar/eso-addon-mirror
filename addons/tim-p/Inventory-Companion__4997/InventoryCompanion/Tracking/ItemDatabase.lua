-- Tracking/ItemDatabase.lua
local this = InventoryCompanion

local itemCountsCache = {}
local cacheInvalid = true
local runtimeRules, cachedSavedRules, cachedBaseline
local runtimeRuleDiagnostics = {}
local CompilePatterns

local function CountEntries(values)
    if type(values) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(values) do count = count + 1 end
    return count
end
local function SplitStoredPatterns(patterns)
    local includes, excludes = {}, {}
    local suffix = this.constants.RULE_PATTERN_EXCLUSION_SUFFIX
    for _, pattern in ipairs(patterns) do
        if pattern:sub(-#suffix) == suffix then
            table.insert(excludes, pattern:sub(1, #pattern - #suffix))
        else
            table.insert(includes, pattern)
        end
    end
    return includes, excludes
end

local customDisplayDefaults = {
    show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false,
}
local extendedDisplayFlags = { showBackpack = true, showBank = true, notifyChat = true, notifyHud = true }
local autoCategoryContexts = {
    backpack = true,
    bank = true,
    guild_bank = true,
    house_bank = true,
    crafting_station = true,
    craft_bag = true,
    furniture_vault = true,
}
local autoCategoryRuleFields = {
    autoCategoryEnabled = true,
}
local autoCategoryOrderFields = { contexts = true }
local autoCategoryOrderModes = { display = true, matching = true, hidden = true, displayPositions = true }
local autoCategoryReferenceNamespaces = { ic = true, ac = true }
local invalidAutoCategoryProfiles = setmetatable({}, { __mode = "k" })
-- profile -> trackedRules table it was validated with; the AutoCategory matcher reads rules per item, so
-- boundary validation must not rerun on every read.
local validatedAutoCategoryProfiles = setmetatable({}, { __mode = "k" })

function this.ResolveItemDisplay(display)
    local resolved = {}
    for key, value in pairs(display) do resolved[key] = value end
    if resolved.showBackpack == nil then resolved.showBackpack = display.show ~= false end
    if resolved.showBank == nil then resolved.showBank = display.show ~= false and display.bank == true end
    if resolved.notifyChat == nil then resolved.notifyChat = display.notify == true end
    if resolved.notifyHud == nil then resolved.notifyHud = display.notify == true end
    resolved.show = resolved.showBackpack or resolved.showBank
    resolved.notify = resolved.notifyChat or resolved.notifyHud
    return resolved
end

local function CheckDisplay(display, context, rule)
    assert(type(display) == "table", context .. " must be a table")
    for key, value in pairs(display) do
        if rule then
            assert(customDisplayDefaults[key] ~= nil or extendedDisplayFlags[key],
                context .. " has an unknown flag: " .. tostring(key))
        end
        if customDisplayDefaults[key] ~= nil or extendedDisplayFlags[key] then
            assert(type(value) == "boolean", context .. "." .. key .. " must be boolean")
        end
    end
end

local function CheckTrackedItems(items, context)
    assert(type(items) == "table", context .. " must be a table")
    for key, item in pairs(items) do
        local path = context .. "[" .. tostring(key) .. "]"
        assert(type(item) == "table", path .. " must be a table")
        if item.display ~= nil then CheckDisplay(item.display, path .. ".display", false) end
        assert(item.mode == nil or item.mode == 1 or item.mode == 2 or item.mode == 3,
            path .. ".mode must be 1, 2, or 3")
    end
end

local function GetExtendedDefault(defaults, display, flag)
    local legacy = {}
    for key, value in pairs(defaults) do legacy[key] = value end
    if display ~= nil then
        for key, value in pairs(display) do
            if not extendedDisplayFlags[key] then legacy[key] = value end
        end
    end
    return this.ResolveItemDisplay(legacy)[flag]
end
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

local function CheckAutoCategoryPlacement(placement, context, allowPartial)
    assert(type(placement) == "table", context .. " must be a table")
    for key, value in pairs(placement) do
        assert(key == "anchor" or key == "rank", context .. " has an unknown field: " .. tostring(key))
        if key == "anchor" then
            assert(type(value) == "string" and value ~= "", context .. ".anchor must be a non-empty string")
        else
            assert(type(value) == "number" and value == math.floor(value) and value > 0 and value <= 0xFFFFFF,
                context .. ".rank must be an integer from 1 to 16777215")
        end
    end
    if allowPartial then
        assert(next(placement) ~= nil, context .. " must override an anchor or rank")
    else
        assert(type(placement.anchor) == "string" and placement.anchor ~= "",
            context .. ".anchor must be a non-empty string")
        assert(type(placement.rank) == "number" and placement.rank == math.floor(placement.rank)
            and placement.rank > 0 and placement.rank <= 0xFFFFFF,
            context .. ".rank must be an integer from 1 to 16777215")
    end
end

local function CheckAutoCategoryOrder(order, context, trackedRules)
    assert(type(order) == "table", context .. " must be a table")
    for key in pairs(order) do
        assert(autoCategoryOrderFields[key], context .. " has an unknown field: " .. tostring(key))
    end
    assert(type(order.contexts) == "table", context .. ".contexts must be a table")
    for contextKey, contextOrder in pairs(order.contexts) do
        local path = context .. ".contexts[" .. tostring(contextKey) .. "]"
        assert(autoCategoryContexts[contextKey], path .. " has an unknown context")
        assert(type(contextOrder) == "table", path .. " must be a table")
        for key in pairs(contextOrder) do
            assert(autoCategoryOrderModes[key], path .. " has an unknown order: " .. tostring(key))
        end
        for _, field in ipairs({ "hidden", "displayPositions" }) do
            local values = contextOrder[field]
            assert(values == nil or type(values) == "table", path .. "." .. field .. " must be a table")
            for reference, value in pairs(values or {}) do
                assert(type(reference) == "string" and reference:match("^..:.+$"),
                    path .. "." .. field .. " has an invalid reference")
                local namespace, identity = reference:match("^([^:]+):(.*)$")
                assert(autoCategoryReferenceNamespaces[namespace], path .. "." .. field .. " has an unsupported reference")
                if field == "hidden" then
                    assert(type(value) == "boolean" and not (namespace == "ic" and identity == "__ic_other"),
                        path .. ".hidden must map ordinary references to booleans")
                    assert(namespace ~= "ic" or identity ~= "miscellaneous"
                        and (this.preLoadedRulesets[identity] ~= nil or trackedRules ~= nil and trackedRules[identity] ~= nil),
                        path .. ".hidden references an unknown IC group: " .. identity)
                else
                    assert(type(value) == "number" and value >= 1 and value < math.huge and value % 1 == 0,
                        path .. ".displayPositions must contain positive integer positions")
                    assert(namespace ~= "ic" or identity ~= "miscellaneous"
                        and (this.preLoadedRulesets[identity] ~= nil or trackedRules ~= nil and trackedRules[identity] ~= nil),
                        path .. ".displayPositions references an unknown IC group: " .. identity)
                end
            end
        end
        for _, mode in ipairs({ "display", "matching" }) do
            local references = contextOrder[mode]
            assert(type(references) == "table", path .. "." .. mode .. " must be a dense list")
            local count, seen = 0, {}
            for index, reference in pairs(references) do
                assert(type(index) == "number" and index >= 1 and index % 1 == 0,
                    path .. "." .. mode .. " must contain only positive integer indices")
                assert(type(reference) == "string", path .. "." .. mode .. "[" .. tostring(index) .. "] must be a string")
                local namespace, identity = reference:match("^([^:]+):(.*)$")
                assert(namespace and autoCategoryReferenceNamespaces[namespace] and identity ~= "",
                    path .. "." .. mode .. "[" .. tostring(index) .. "] has an unsupported reference")
                if namespace == "ic" then
                    assert(identity == "__ic_other" and mode == "display"
                        or identity ~= "miscellaneous" and identity ~= "__ic_other"
                        and (this.preLoadedRulesets[identity] ~= nil
                            or trackedRules ~= nil and trackedRules[identity] ~= nil),
                        path .. "." .. mode .. "[" .. tostring(index) .. "] references an unknown IC group: " .. identity)
                end
                assert(not seen[reference], path .. "." .. mode .. " contains a duplicate reference: " .. reference)
                seen[reference] = true
                count = count + 1
            end
            for index = 1, count do
                assert(rawget(references, index) ~= nil, path .. "." .. mode .. " must not contain holes")
            end
        end
    end
end

local function MigrateContextInclusion(profile, order)
    local keys = {}
    for key in pairs(this.preLoadedRulesets) do
        if key ~= "miscellaneous" then keys[key] = true end
    end
    for key in pairs(profile.trackedRules or {}) do
        if key ~= "miscellaneous" then keys[key] = true end
    end
    local sorted = {}
    for key in pairs(keys) do sorted[#sorted + 1] = key end
    table.sort(sorted)
    for _, contextOrder in pairs(order.contexts) do
        for _, key in ipairs(sorted) do
            local saved = profile.trackedRules and profile.trackedRules[key]
            local reference = "ic:" .. key
            contextOrder.hidden[reference] = not (saved and saved.autoCategoryEnabled == true) and true or nil
        end
        for _, mode in ipairs({ "display", "matching" }) do
            local included, excluded, seen = {}, {}, {}
            for _, reference in ipairs(contextOrder[mode]) do
                local list = contextOrder.hidden[reference] and excluded or included
                list[#list + 1], seen[reference] = reference, true
            end
            for _, key in ipairs(sorted) do
                local reference = "ic:" .. key
                if not seen[reference] then
                    local list = contextOrder.hidden[reference] and excluded or included
                    list[#list + 1] = reference
                end
            end
            if mode == "display" then included[#included + 1] = "ic:__ic_other" end
            for _, reference in ipairs(excluded) do included[#included + 1] = reference end
            contextOrder[mode] = included
        end
    end
    return order
end

local function HasLegacyAutoCategoryOrdering(profile)
    if profile.autoCategoryInitialized ~= nil or profile.autoCategoryOrder ~= nil then return true end
    for _, rule in pairs(profile.trackedRules or {}) do
        if rule.autoCategoryAnchor ~= nil or rule.autoCategoryRank ~= nil
            or rule.autoCategoryOverrides ~= nil or rule.autoCategoryEnabled == true then
            return true
        end
    end
    return false
end

local function NewAutoCategoryOrder()
    local order = { contexts = {} }
    for contextKey in pairs(autoCategoryContexts) do
        order.contexts[contextKey] = { display = {}, matching = {}, hidden = {}, displayPositions = {} }
    end
    return order
end

local function NormalizeAutoCategoryOrder(order)
    if order == nil then return NewAutoCategoryOrder() end
    assert(type(order) == "table" and type(order.contexts) == "table",
        "AutoCategory order must contain a contexts table")
    local function CopyList(values)
        if values == nil then return {} end
        assert(type(values) == "table", "AutoCategory order sequence must be a table")
        local copy = {}
        for key, value in pairs(values) do copy[key] = value end
        return copy
    end
    local normalized = { contexts = {} }
    for contextKey, contextOrder in pairs(order.contexts) do
        assert(autoCategoryContexts[contextKey], "AutoCategory order has an unknown context: " .. tostring(contextKey))
        assert(type(contextOrder) == "table", "AutoCategory context order must be a table")
        normalized.contexts[contextKey] = {
            display = CopyList(contextOrder.display),
            matching = CopyList(contextOrder.matching),
            hidden = CopyList(contextOrder.hidden),
            displayPositions = CopyList(contextOrder.displayPositions),
        }
    end
    for contextKey in pairs(autoCategoryContexts) do
        if normalized.contexts[contextKey] == nil then
            normalized.contexts[contextKey] = { display = {}, matching = {}, hidden = {}, displayPositions = {} }
        end
    end
    return normalized
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
            CheckDisplay(saved.display, path .. ".display", true)
        end
    end
end

local function ValidateAutoCategoryProfile(profile, context)
    assert(profile.itemListInitialized == nil or type(profile.itemListInitialized) == "boolean",
        context .. ".itemListInitialized must be boolean")
    if profile.version == 4 then
        assert(not HasLegacyAutoCategoryOrdering(profile),
            context .. " contains schema-4 AutoCategory ordering data that schema 5 cannot migrate safely. "
                .. "Restore a compatible saved-variable backup and rebuild AutoCategory integration.")
    end
    for ruleName, saved in pairs(profile.trackedRules or {}) do
        local path = context .. ".trackedRules[" .. ruleName .. "]"
        assert(saved.autoCategoryEnabled == nil or type(saved.autoCategoryEnabled) == "boolean",
            path .. ".autoCategoryEnabled must be boolean")
        assert(saved.autoCategoryAnchor == nil and saved.autoCategoryRank == nil
            and saved.autoCategoryOverrides == nil,
            path .. " contains obsolete rank-based AutoCategory ordering data")
        for field in pairs(autoCategoryRuleFields) do
            assert(saved[field] == nil or ruleName ~= "miscellaneous",
                path .. " cannot participate in AutoCategory integration")
        end
    end
    assert(profile.autoCategoryIntegrationEnabled == nil or type(profile.autoCategoryIntegrationEnabled) == "boolean",
        context .. ".autoCategoryIntegrationEnabled must be boolean")
    assert(profile.autoCategorySetupComplete == nil or type(profile.autoCategorySetupComplete) == "boolean",
        context .. ".autoCategorySetupComplete must be boolean")
    assert(profile.autoCategoryInitialized == nil,
        context .. ".autoCategoryInitialized is obsolete in schema 5")
    if profile.autoCategoryOrder ~= nil then
        CheckAutoCategoryOrder(profile.autoCategoryOrder, context .. ".autoCategoryOrder", profile.trackedRules)
    end
end

local function ValidateAutoCategoryBoundary(profile, context)
    if invalidAutoCategoryProfiles[profile] then return false end
    local ok, failure = pcall(ValidateAutoCategoryProfile, profile, context)
    if not ok then
        invalidAutoCategoryProfiles[profile] = true
        this.AutoCategoryIntegration.Fail(failure)
    end
    return ok
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
    if rules == nil or validatedAutoCategoryProfiles[profile] ~= rules then
        if ValidateAutoCategoryBoundary(profile, context) and rules ~= nil then
            validatedAutoCategoryProfiles[profile] = rules
        end
    end
    return rules
end

function this.ValidateSavedRuleProfiles()
    assert(type(this.character.useCharacterItemList) == "boolean",
        "Character.useCharacterItemList must be boolean")
    validatedAutoCategoryProfiles[this.accountWide] = nil
    validatedAutoCategoryProfiles[this.character] = nil
    for _, profile in ipairs({ this.accountWide, this.character }) do
        if profile == this.accountWide or profile.itemListInitialized ~= false
            or this.character.useCharacterItemList then
        LoadSavedRules(profile, profile == this.accountWide and "Account-wide" or "Character", true)
        if not invalidAutoCategoryProfiles[profile] then
            profile.autoCategoryOrder = NormalizeAutoCategoryOrder(profile.autoCategoryOrder)
            CheckAutoCategoryOrder(profile.autoCategoryOrder, "Profile.autoCategoryOrder", profile.trackedRules)
        end
        if profile.trackedItems == nil then profile.trackedItems = {} end
        CheckTrackedItems(profile.trackedItems, "Profile.trackedItems")
        for _, item in pairs(profile.trackedItems) do
            if item.display == nil then item.display = {} end
        end
        this.PrepareProfilePreferences(profile)
        if profile.itemListInitialized == nil and (next(profile.trackedRules) ~= nil
            or next(profile.trackedItems) ~= nil or profile.autoCategorySetupComplete ~= nil
            or profile.autoCategoryIntegrationEnabled ~= nil) then
            profile.itemListInitialized = true
        end
        end
    end
    this.GetAutoCategoryProfile().itemListInitialized = true
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
        CheckDisplay(base.display, context .. ".display", true)
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
    if candidateSavedRules == nil then cacheInvalid = true end
end

-- Items
function this.GetActiveTrackedItems()
    return this.GetSettingsProfile().trackedItems
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
        for key in pairs(extendedDisplayFlags) do
            if saved.display[key] == GetExtendedDefault(defaults, saved.display, key) then
                saved.display[key] = nil
            end
        end
        for key, value in pairs(saved.display) do
            if value == defaults[key] then saved.display[key] = nil end
        end
    end
    PruneRule(savedRules, ruleName)
end

local trackerContextRevision = 0

local function CopyValues(values)
    local copy = {}
    for key, value in pairs(values) do copy[key] = value end
    return copy
end

local function CopySavedValue(value, activeTables)
    local valueType = type(value)
    assert(valueType == "table" or valueType == "nil" or valueType == "boolean"
        or valueType == "number" or valueType == "string",
        "Saved list contains an unsupported value")
    if valueType ~= "table" then return value end
    activeTables = activeTables or {}
    assert(not activeTables[value], "Saved list contains a circular table")
    activeTables[value] = true
    local copy = {}
    for key, nestedValue in pairs(value) do
        assert(type(key) == "string" or type(key) == "number", "Saved list contains an unsupported key")
        copy[key] = CopySavedValue(nestedValue, activeTables)
    end
    activeTables[value] = nil
    return copy
end

this.CopySavedValue = CopySavedValue

local preferenceFields = {
    "showTrackedItemsPanel", "showEmptyTrackedItems", "trackerOffsetX", "trackerOffsetY",
    "wrapTrackedItemNames", "trackerGroupThreshold", "trackerMaxRows", "trackerTitleSize",
    "showEmptyCurrencies", "currencyOffsetX", "currencyOffsetY", "currencyPreferences",
    "capacityPreferences", "progressBarPreferences", "progressBarAlertColors",
    "filterShow", "filterNotify", "filterCraftbag", "filterMute", "filterUntracked",
}
local preferenceDefaults = {
    showTrackedItemsPanel = true, showEmptyTrackedItems = true, trackerOffsetX = 50, trackerOffsetY = 50,
    wrapTrackedItemNames = false, trackerGroupThreshold = 8, trackerMaxRows = 20, trackerTitleSize = 20,
    showEmptyCurrencies = true, currencyOffsetX = 50, currencyOffsetY = 150,
    currencyPreferences = {}, capacityPreferences = {}, progressBarPreferences = {}, progressBarAlertColors = {},
    filterShow = true, filterNotify = true, filterCraftbag = false, filterMute = true, filterUntracked = false,
}

function this.GetSettingsProfile()
    if this.character.useCharacterItemList then return this.character end
    return this.accountWide
end

local function ValidateResourcePreference(preference, context)
    assert(type(preference) == "table", context .. " must be a table")
    for _, key in ipairs({ "showCompact", "hidden", "showBar" }) do
        assert(preference[key] == nil or type(preference[key]) == "boolean",
            context .. "." .. key .. " must be boolean")
    end
    for _, key in ipairs({ "order", "offsetX", "offsetY", "warningThreshold", "dangerThreshold" }) do
        local value = preference[key]
        if value ~= nil then
            assert(type(value) == "number" and value == value and math.abs(value) < math.huge,
                context .. "." .. key .. " must be finite")
            if key == "order" then
                assert(value > 0 and value % 1 == 0, context .. ".order must be a positive integer")
            elseif key == "warningThreshold" or key == "dangerThreshold" then
                assert(value >= 0 and value <= 1, context .. "." .. key .. " must be between zero and one")
            else
                assert(value >= 0, context .. "." .. key .. " must be nonnegative")
            end
        end
    end
end

local function ValidatePreferenceColor(color, context)
    assert(type(color) == "table", context .. " must be a color table")
    for _, channel in ipairs({ "r", "g", "b", "a" }) do
        local value = color[channel]
        assert(type(value) == "number" and value >= 0 and value <= 1,
            context .. "." .. channel .. " must be between zero and one")
    end
end

local function PrepareProfilePreferences(profile, source)
    for _, key in ipairs(preferenceFields) do
        local default = preferenceDefaults[key]
        local value = profile[key]
        if value == nil then
            value = source and source[key]
            if value == nil then value = default end
            profile[key] = CopySavedValue(value)
        end
        assert(type(profile[key]) == type(default), "Saved profile." .. key .. " has an invalid type")
        if type(default) == "number" then
            assert(profile[key] == profile[key] and math.abs(profile[key]) < math.huge,
                "Saved profile." .. key .. " must be finite")
        elseif type(default) == "table" then
            CopySavedValue(profile[key])
        end
    end
    for key, range in pairs({
        trackerGroupThreshold = { 1, 30 }, trackerMaxRows = { 5, 50 }, trackerTitleSize = { 16, 28 },
    }) do
        local value = profile[key]
        assert(value >= range[1] and value <= range[2] and value % 1 == 0,
            "Saved profile." .. key .. " is outside its supported integer range")
    end
    for key, preference in pairs(profile.currencyPreferences) do
        local context = "Saved profile.currencyPreferences[" .. tostring(key) .. "]"
        ValidateResourcePreference(preference, context)
        if preference.locations ~= nil then
            assert(type(preference.locations) == "table", context .. ".locations must be a table")
            for location, value in pairs(preference.locations) do
                ValidateResourcePreference(value, context .. ".locations[" .. tostring(location) .. "]")
            end
        end
    end
    for _, field in ipairs({ "capacityPreferences", "progressBarPreferences" }) do
        for key, preference in pairs(profile[field]) do
            local context = "Saved profile." .. field .. "[" .. tostring(key) .. "]"
            ValidateResourcePreference(preference, context)
            if field == "progressBarPreferences" and preference.normalColor ~= nil then
                ValidatePreferenceColor(preference.normalColor, context .. ".normalColor")
            end
        end
    end
    for _, key in ipairs({ "warning", "danger" }) do
        if profile.progressBarAlertColors[key] ~= nil then
            ValidatePreferenceColor(profile.progressBarAlertColors[key], "Saved profile.progressBarAlertColors." .. key)
        end
    end
end
this.PrepareProfilePreferences = PrepareProfilePreferences

function this.RefreshProfileSettings()
    this.ValidateTrackerSettings()
    this.InitializeProgressBarResources()
    this.RefreshResourceProgressBars()
    InventoryCompanion_CurrencyFloat:ClearAnchors()
    InventoryCompanion_CurrencyFloat:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        this.GetSettingsProfile().currencyOffsetX, this.GetSettingsProfile().currencyOffsetY)
    this.RefreshCurrencyPanel()
    this.RestoreTrackerPosition()
    InventoryCompanion_ItemTrackerFloat:ClearAnchors()
    InventoryCompanion_ItemTrackerFloat:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        this.GetSettingsProfile().trackerOffsetX, this.GetSettingsProfile().trackerOffsetY)
    this.RefreshItemTrackerPanel()
    this.UpdateEventRegistry()
    this.RefreshAutoCategoryUI()
end

local function ValidateAutoCategoryDebug(debugData, context)
    assert(type(debugData) == "table", context .. " must be a table")
    for key in pairs(debugData) do
        assert(key == "autoCategoryRemovedLines", context .. " has an unknown field: " .. tostring(key))
    end
    local lines = debugData.autoCategoryRemovedLines
    if lines == nil then return end
    assert(type(lines) == "table", context .. ".autoCategoryRemovedLines must be an array")
    local count = 0
    for index, record in pairs(lines) do
        assert(type(index) == "number" and index >= 1 and index % 1 == 0,
            context .. ".autoCategoryRemovedLines must contain only positive integer indices")
        count = count + 1
        local recordContext = context .. ".autoCategoryRemovedLines[" .. tostring(index) .. "]"
        assert(type(record) == "table", recordContext .. " must be a table")
        for key in pairs(record) do
            assert(key == "timestamp" or key == "dateTime" or key == "context" or key == "bagType"
                or key == "index" or key == "line" or key == "restored",
                recordContext .. " has an unknown field: " .. tostring(key))
        end
        assert(record.restored == nil or type(record.restored) == "boolean",
            recordContext .. ".restored must be boolean when present")
        assert(type(record.timestamp) == "number" and record.timestamp > 0
            and record.timestamp < math.huge and record.timestamp % 1 == 0,
            recordContext .. ".timestamp must be a positive integer")
        assert(type(record.dateTime) == "string" and record.dateTime ~= "",
            recordContext .. ".dateTime must be a non-empty string")
        assert(type(record.context) == "string" and record.context ~= "",
            recordContext .. ".context must be a non-empty string")
        assert(type(record.bagType) == "number" and record.bagType > 0
            and record.bagType < math.huge and record.bagType % 1 == 0,
            recordContext .. ".bagType must be a positive integer")
        assert(type(record.index) == "number" and record.index > 0
            and record.index < math.huge and record.index % 1 == 0,
            recordContext .. ".index must be a positive integer")
        assert(type(record.line) == "table" and record.line.icOwned == true
            and type(record.line.icRuleKey) == "string" and record.line.icRuleKey ~= ""
            and type(record.line.name) == "string" and record.line.name ~= "",
            recordContext .. ".line must be an IC-owned assignment")
        CopySavedValue(record.line)
    end
    for index = 1, count do
        assert(rawget(lines, index) ~= nil, context .. ".autoCategoryRemovedLines must not contain holes")
    end
end

local function CopyOptionalValues(values)
    if values == nil then return nil end
    return CopyValues(values)
end

local function ValidateAccountWideListBackup(backup, context)
    assert(type(backup) == "table", context .. " must be a table")
    for key in pairs(backup) do
        assert(key == "formatVersion" or key == "trackedRules" or key == "trackedItems"
            or key == "autoCategoryIntegrationEnabled" or key == "autoCategorySetupComplete"
            or key == "autoCategoryOrder", context .. " has an unknown field: " .. tostring(key))
    end
    assert(backup.formatVersion == 1, context .. " has an unsupported format version")
    ValidateSavedRules(backup.trackedRules, context .. ".trackedRules")
    CheckTrackedItems(backup.trackedItems, context .. ".trackedItems")
    assert(type(backup.autoCategoryOrder) == "table", context .. ".autoCategoryOrder must be a table")
    ValidateAutoCategoryProfile({
        version = this.SettingsVersion,
        trackedRules = backup.trackedRules,
        autoCategoryIntegrationEnabled = backup.autoCategoryIntegrationEnabled,
        autoCategorySetupComplete = backup.autoCategorySetupComplete,
        autoCategoryOrder = backup.autoCategoryOrder,
    }, context)
end

local function BuildAccountWideListBackup(profile)
    local backup = {
        formatVersion = 1,
        trackedRules = CopySavedValue(profile.trackedRules),
        trackedItems = CopySavedValue(profile.trackedItems),
        autoCategoryIntegrationEnabled = profile.autoCategoryIntegrationEnabled,
        autoCategorySetupComplete = profile.autoCategorySetupComplete,
        autoCategoryOrder = CopySavedValue(profile.autoCategoryOrder),
    }
    ValidateAccountWideListBackup(backup, "Account-wide list backup")
    return backup
end

function this.SaveAccountWideListBackup()
    assert(type(this.accountWide) == "table", "Account-wide saved profile is unavailable")
    local backup = BuildAccountWideListBackup(this.accountWide)
    this.accountWide.accountWideListBackup = backup
end

function this.RestoreAccountWideListBackup()
    assert(type(this.accountWide) == "table", "Account-wide saved profile is unavailable")
    local backup = this.accountWide.accountWideListBackup
    ValidateAccountWideListBackup(backup, "Account-wide list backup")
    local restored = BuildAccountWideListBackup(backup)
    this.accountWide.trackedRules = restored.trackedRules
    this.accountWide.trackedItems = restored.trackedItems
    this.accountWide.autoCategoryIntegrationEnabled = restored.autoCategoryIntegrationEnabled
    this.accountWide.autoCategorySetupComplete = restored.autoCategorySetupComplete
    this.accountWide.autoCategoryOrder = restored.autoCategoryOrder
    this.accountWide.itemListInitialized = true
    this.InvalidateRuleCache()
    trackerContextRevision = trackerContextRevision + 1
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
            if profileName == "$AccountWide" then
                assert(profile.guildBankPartialWithdrawEnabled == nil
                    or type(profile.guildBankPartialWithdrawEnabled) == "boolean",
                    context .. ".guildBankPartialWithdrawEnabled must be boolean")
            end
            local version = profile.version
            assert(type(version) == "number" and version >= 1 and version < math.huge and version % 1 == 0,
                context .. ".version must be a positive integer; saved data was not changed")
            assert(version <= this.SettingsVersion,
                string.format("[InventoryCompanion] %s uses saved-variable version %s, but this addon supports version %s. "
                    .. "Initialization stopped without changing saved data. Install a compatible newer addon or restore a compatible backup.",
                    context, tostring(version), tostring(this.SettingsVersion)))
            assert(this.SettingsVersion <= 10 and (version == this.SettingsVersion
                    or (this.SettingsVersion == 10 and version <= 9)
                    or (version == 1 and (this.SettingsVersion == 2 or this.SettingsVersion == 3 or this.SettingsVersion == 4
                        or this.SettingsVersion == 5 or this.SettingsVersion == 6 or this.SettingsVersion == 7))
                    or (version == 2 and (this.SettingsVersion == 3 or this.SettingsVersion == 4
                        or this.SettingsVersion == 5 or this.SettingsVersion == 6 or this.SettingsVersion == 7))
                    or (version == 3 and (this.SettingsVersion == 4 or this.SettingsVersion == 5
                        or this.SettingsVersion == 6 or this.SettingsVersion == 7))
                    or (version == 4 and (this.SettingsVersion == 5 or this.SettingsVersion == 6
                        or this.SettingsVersion == 7))
                    or (version == 5 and (this.SettingsVersion == 6 or this.SettingsVersion == 7))
                    or (version == 6 and this.SettingsVersion == 7)
                    or (version <= 7 and this.SettingsVersion == 8)
                    or (version <= 8 and this.SettingsVersion == 9)),
                context .. " has no supported migration from version " .. tostring(version)
                    .. " to version " .. tostring(this.SettingsVersion))
            local initialized = profile.itemListInitialized
            if initialized == nil then
                initialized = profile.trackedRules ~= nil and next(profile.trackedRules) ~= nil
                    or profile.trackedItems ~= nil and next(profile.trackedItems) ~= nil
                    or profile.autoCategorySetupComplete ~= nil or profile.autoCategoryIntegrationEnabled ~= nil
                    or profileName ~= "$AccountWide" and profile.useCharacterItemList == true
                if profileName == "$AccountWide" then
                    for key, character in pairs(account) do
                        if key ~= "$AccountWide" and type(character) == "table"
                            and character.useCharacterItemList ~= true then initialized = true end
                    end
                end
            end
            table.insert(profiles, { data = profile, context = context, initialized = initialized,
                account = account, name = profileName })
        end
    end

    for ruleName in pairs(this.preLoadedRulesets) do GetBaseline(ruleName) end
    local migrations = {}
    for _, entry in ipairs(profiles) do
        local profile, context = entry.data, entry.context
        if profile.trackedRules ~= nil then
            ValidateSavedRules(profile.trackedRules, context .. ".trackedRules")
        end
        ValidateAutoCategoryBoundary(profile, context)
        if profile.debug ~= nil then ValidateAutoCategoryDebug(profile.debug, context .. ".debug") end
        if profile.trackedItems ~= nil then
            CheckTrackedItems(profile.trackedItems, context .. ".trackedItems")
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
            table.insert(migrations, { profile = profile, rules = rules, initialized = entry.initialized })
        else
            table.insert(migrations, { profile = profile, initialized = entry.initialized })
        end
        local migration = migrations[#migrations]
        if not invalidAutoCategoryProfiles[profile] then
            migration.order = NormalizeAutoCategoryOrder(profile.autoCategoryOrder)
            if profile.version == 5 and profile.autoCategorySetupComplete == nil then
                for _, rule in pairs(profile.trackedRules or {}) do
                    if rule.autoCategoryEnabled ~= nil then migration.setupComplete = true end
                end
                for _, orders in pairs(migration.order.contexts) do
                    for _, mode in ipairs({ "display", "matching" }) do
                        for _, reference in ipairs(orders[mode]) do
                            if reference:sub(1, 3) == "ic:" then migration.setupComplete = true end
                        end
                    end
                end
            end
            if profile.version < 9 and this.SettingsVersion >= 9 then
                migration.order = MigrateContextInclusion(profile, migration.order)
            end
        end
        if profile.accountWideListBackup ~= nil then
            ValidateAccountWideListBackup(profile.accountWideListBackup, context .. ".accountWideListBackup")
            if profile.version < 9 and this.SettingsVersion >= 9 then
                migration.backup = CopySavedValue(profile.accountWideListBackup)
                migration.backup.autoCategoryOrder = MigrateContextInclusion(migration.backup,
                    NormalizeAutoCategoryOrder(migration.backup.autoCategoryOrder))
            end
        end
    end

    if this.SettingsVersion >= 10 then
        local candidates = {}
        for index, entry in ipairs(profiles) do
            local migration, candidate = migrations[index], CopyValues(entry.data)
            if migration.rules then candidate.trackedRules = migration.rules end
            if migration.order then candidate.autoCategoryOrder = migration.order end
            if migration.setupComplete then candidate.autoCategorySetupComplete = true end
            candidates[entry.data] = candidate
            migration.candidate = candidate
            if entry.name == "$AccountWide" then
                PrepareProfilePreferences(candidate)
                if candidate.trackedItems == nil then candidate.trackedItems = {} end
                if candidate.trackedRules == nil then candidate.trackedRules = {} end
                candidate.itemListInitialized = true
            end
        end
        for index, entry in ipairs(profiles) do
            local migration, candidate = migrations[index], migrations[index].candidate
            if entry.name ~= "$AccountWide" then
                local reset = entry.data.version < 10 and candidate.useCharacterItemList ~= true
                local initialized = not reset and
                    (candidate.useCharacterItemList == true or candidate.itemListInitialized == true)
                if initialized then
                    local account = entry.account["$AccountWide"]
                    PrepareProfilePreferences(candidate, entry.data.version < 10 and account and candidates[account] or nil)
                    if candidate.trackedItems == nil then candidate.trackedItems = {} end
                    if candidate.trackedRules == nil then candidate.trackedRules = {} end
                else
                    for _, key in ipairs(preferenceFields) do candidate[key] = nil end
                    candidate.trackedItems, candidate.trackedRules = nil, nil
                    candidate.autoCategoryOrder, candidate.autoCategorySetupComplete = nil, nil
                end
                candidate.itemListInitialized = initialized
                candidate.useCharacterItemList = candidate.useCharacterItemList == true
                candidate.autoCategoryIntegrationEnabled = nil
            end
            migration.initialized = candidate.itemListInitialized
        end
    end

    -- Publish only after every profile has passed validation and conversion.
    for _, migration in ipairs(migrations) do
        if migration.rules ~= nil then migration.profile.trackedRules = migration.rules end
        if not invalidAutoCategoryProfiles[migration.profile] then
            migration.profile.autoCategoryOrder = migration.order
            if migration.setupComplete then migration.profile.autoCategorySetupComplete = true end
        end
        if migration.backup then migration.profile.accountWideListBackup = migration.backup end
        if migration.candidate then
            for _, key in ipairs(preferenceFields) do migration.profile[key] = migration.candidate[key] end
            for _, key in ipairs({ "trackedItems", "trackedRules", "autoCategoryOrder",
                "autoCategorySetupComplete", "autoCategoryIntegrationEnabled", "useCharacterItemList" }) do
                migration.profile[key] = migration.candidate[key]
            end
        end
        migration.profile.version = this.SettingsVersion
        migration.profile.itemListInitialized = migration.initialized
    end
    this.InvalidateRuleCache()
end

function this.GetRuntimeRules(candidateSavedRules)
    local savedRules = candidateSavedRules or GetRawSavedRules()
    if candidateSavedRules then ValidateSavedRules(savedRules, "Candidate rules") end
    local firstAccess
    if candidateSavedRules == nil and this.IsDevelopment == true and runtimeRuleDiagnostics.firstAccess == nil then
        local caller = "unavailable"
        if type(debug) == "table" and type(debug.getinfo) == "function" then
            local callerInfo = debug.getinfo(2, "Sl")
            if callerInfo then
                caller = tostring(callerInfo.short_src) .. ":" .. tostring(callerInfo.currentline)
            end
        end
        firstAccess = {
            caller = caller,
            selectedProfile = this.character.useCharacterItemList and "character-specific" or "account-wide",
            cacheInvalid = cacheInvalid,
            cacheBuilt = runtimeRules ~= nil,
            cacheMatchesSavedRules = cachedSavedRules == savedRules,
            cacheMatchesBaselines = cachedBaseline == this.preLoadedRulesets,
            baselineRuleCount = CountEntries(this.preLoadedRulesets),
            savedRuleCount = CountEntries(savedRules),
            cachedRuleCount = CountEntries(runtimeRules),
        }
        runtimeRuleDiagnostics.firstAccess = firstAccess
    end
    if candidateSavedRules == nil and not cacheInvalid and cachedSavedRules == savedRules and cachedBaseline == this.preLoadedRulesets then
        if firstAccess then
            firstAccess.cachePath = "reused"
            firstAccess.returnedRuleCount = CountEntries(runtimeRules)
        end
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
        local includePatterns, excludePatterns = SplitStoredPatterns(patterns)
        local displayName = saved.displayName
        if displayName == nil then displayName = GetDefaultName(ruleName, base) end
        resolvedRules[ruleName] = {
            displayName = displayName,
            patterns = patterns,
            compiledPatterns = CompilePatterns(includePatterns),
            compiledExcludedPatterns = CompilePatterns(excludePatterns),
            display = this.ResolveItemDisplay(display),
            isPreloaded = base ~= nil,
            autoCategoryEnabled = saved.autoCategoryEnabled == true,
        }
    end
    for ruleName, base in pairs(this.preLoadedRulesets) do Resolve(ruleName, base) end
    for ruleName in pairs(savedRules) do
        if not this.preLoadedRulesets[ruleName] then Resolve(ruleName) end
    end
    if candidateSavedRules then return resolvedRules end
    runtimeRules = resolvedRules
    cachedSavedRules, cachedBaseline = savedRules, this.preLoadedRulesets
    cacheInvalid = false
    if firstAccess then
        firstAccess.cachePath = "built"
        firstAccess.returnedRuleCount = CountEntries(runtimeRules)
    end
    return runtimeRules
end

function this.GetRuntimeRuleDiagnostics(ruleKey)
    assert(type(ruleKey) == "string" and ruleKey ~= "", "Runtime rule diagnostic requires a rule key")
    assert(type(this.accountWide) == "table" and type(this.character) == "table",
        "Saved profiles are required for runtime rule diagnostics")
    assert(type(this.character.useCharacterItemList) == "boolean",
        "Character list preference must be validated before runtime rule diagnostics")
    local accountRules = this.accountWide.trackedRules
    local characterRules = this.character.trackedRules
    local activeRules = this.character.useCharacterItemList and characterRules or accountRules
    local firstAccess = runtimeRuleDiagnostics.firstAccess
    return {
        selectedProfile = this.character.useCharacterItemList and "character-specific" or "account-wide",
        accountSavedRuleCount = CountEntries(accountRules),
        characterSavedRuleCount = CountEntries(characterRules),
        activeSavedRuleCount = CountEntries(activeRules),
        accountHasRule = type(accountRules) == "table" and rawget(accountRules, ruleKey) ~= nil,
        characterHasRule = type(characterRules) == "table" and rawget(characterRules, ruleKey) ~= nil,
        activeHasRule = type(activeRules) == "table" and rawget(activeRules, ruleKey) ~= nil,
        baselineRuleCount = CountEntries(this.preLoadedRulesets),
        baselineHasRule = type(this.preLoadedRulesets) == "table"
            and rawget(this.preLoadedRulesets, ruleKey) ~= nil,
        cacheBuilt = runtimeRules ~= nil,
        cacheInvalid = cacheInvalid,
        cacheMatchesActiveRules = cachedSavedRules == activeRules,
        cacheMatchesBaselines = cachedBaseline == this.preLoadedRulesets,
        runtimeRuleCount = CountEntries(runtimeRules),
        runtimeHasRule = type(runtimeRules) == "table" and rawget(runtimeRules, ruleKey) ~= nil,
        firstAccess = firstAccess and {
            caller = firstAccess.caller,
            selectedProfile = firstAccess.selectedProfile,
            cacheInvalid = firstAccess.cacheInvalid,
            cacheBuilt = firstAccess.cacheBuilt,
            cacheMatchesSavedRules = firstAccess.cacheMatchesSavedRules,
            cacheMatchesBaselines = firstAccess.cacheMatchesBaselines,
            baselineRuleCount = firstAccess.baselineRuleCount,
            savedRuleCount = firstAccess.savedRuleCount,
            cachedRuleCount = firstAccess.cachedRuleCount,
            cachePath = firstAccess.cachePath,
            returnedRuleCount = firstAccess.returnedRuleCount,
        } or nil,
    }
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
                compiledExcludedPatterns = rule.compiledExcludedPatterns,
                display = CopyValues(rule.display),
                isPreloaded = rule.isPreloaded,
                autoCategoryEnabled = rule.autoCategoryEnabled,
            }
        end
    end
    return rules
end

function this.GetTrackerContext()
    return GetRawSavedRules(), trackerContextRevision
end

function this.GetAutoCategoryProfile()
    if this.character.useCharacterItemList then return this.character end
    return this.accountWide
end

function this.GetAutoCategoryState()
    local profile = this.GetAutoCategoryProfile()
    local configuredEnabled = this.accountWide.autoCategoryIntegrationEnabled == true
    local failed = this.AutoCategoryIntegration.NeedsRecovery()
    return {
        enabled = configuredEnabled and not failed,
        configuredEnabled = configuredEnabled,
        failed = failed,
        order = profile.autoCategoryOrder,
    }
end

function this.ValidateAutoCategoryRecoveryData()
    assert(type(this.character.useCharacterItemList) == "boolean",
        "Character.useCharacterItemList must be boolean")
    for _, entry in ipairs({ { this.accountWide, "Account-wide" }, { this.character, "Character" } }) do
        if entry[1] == this.accountWide or entry[1].itemListInitialized ~= false then
        ValidateSavedRules(entry[1].trackedRules, entry[2] .. ".trackedRules")
        ValidateAutoCategoryProfile(entry[1], entry[2])
        end
    end
    for _, profile in ipairs({ this.accountWide, this.character }) do
        invalidAutoCategoryProfiles[profile] = nil
        validatedAutoCategoryProfiles[profile] = profile.trackedRules
    end
    this.InvalidateRuleCache()
end

function this.SetAutoCategoryParticipation(ruleKey, enabled)
    assert(type(enabled) == "boolean", "AutoCategory participation must be boolean")
    assert(not this.AutoCategoryIntegration.NeedsRecovery(),
        "AutoCategory participation cannot change while integration needs recovery")
    local runtimeRule = this.GetRuntimeRules()[ruleKey]
    assert(runtimeRule ~= nil and ruleKey ~= "miscellaneous",
        "AutoCategory participation requires an ordinary group: " .. tostring(ruleKey))
    if this.AutoCategoryIntegration.IsEditorActive() then
        for contextKey in pairs(autoCategoryContexts) do
            if not this.AutoCategoryIntegration.SetEntryIncluded("ic:" .. ruleKey, contextKey, enabled) then return false end
        end
        return true
    end
    local savedRules = GetRawSavedRules()
    local saved = savedRules[ruleKey] or {}
    savedRules[ruleKey] = saved
    saved.autoCategoryEnabled = enabled and true or nil
    for _, orders in pairs(this.GetAutoCategoryProfile().autoCategoryOrder.contexts) do
        orders.hidden["ic:" .. ruleKey] = not enabled and true or nil
    end
    ValidateSavedRules(savedRules, "AutoCategory participation")
    PruneRule(savedRules, ruleKey)
    this.InvalidateRuleCache()
    this.AutoCategoryIntegration.OnRuleMutation("participation", ruleKey)
end

function this.SetAutoCategoryContextOrder(contextKey, mode, sequence)
    assert(autoCategoryContexts[contextKey], "Unknown AutoCategory context: " .. tostring(contextKey))
    assert(mode == "display" or mode == "matching", "Unknown AutoCategory ordering mode: " .. tostring(mode))
    assert(type(sequence) == "table", "AutoCategory ordering sequence must be a list")
    local prepared, failure = this.AutoCategoryIntegration.PreflightAutoCategory({
        [contextKey] = { [mode] = sequence },
    })
    if prepared == nil then
        this.AutoCategoryIntegration.Fail(failure)
        return false
    end
    return this.AutoCategoryIntegration.ProjectAutoCategory(prepared) ~= false
end

function this.SetAutoCategoryIntegrationEnabled(enabled)
    assert(type(enabled) == "boolean", "AutoCategory enablement must be boolean")
    local profile = this.GetAutoCategoryProfile()
    if enabled and profile.autoCategorySetupComplete ~= true then
        return this.AutoCategoryIntegration.ShowInitialSetup()
    end
    this.accountWide.autoCategoryIntegrationEnabled = enabled and true or nil
    this.AutoCategoryIntegration.OnEnablementChanged(enabled)
    return true
end

local function NormalizeAccountName(name)
    assert(type(name) == "string" and name ~= "", "ESO account name must be a non-empty string")
    return name:lower():gsub("^@", "")
end

function this.CleanAutoCategorySavedData(accountName)
    assert(type(accountName) == "string" and NormalizeAccountName(accountName) == "tim-p",
        "AutoCategory saved-data cleanup is restricted to the @Tim-P account")
    local saved = _G[this.SettingsName]
    assert(type(saved) == "table" and type(saved.Default) == "table",
        "Inventory Companion saved profiles are unavailable; no cleanup was performed")

    local account
    for savedAccountName, savedAccount in pairs(saved.Default) do
        assert(type(savedAccount) == "table", "Saved account profiles are malformed; no cleanup was performed")
        if NormalizeAccountName(savedAccountName) == "tim-p" then
            assert(account == nil, "Duplicate @Tim-P saved-variable account buckets; no cleanup was performed")
            account = savedAccount
        end
    end
    assert(account ~= nil, "No @Tim-P Inventory Companion saved profiles were found; no cleanup was performed")

    local profilePlans = {}
    for profileName, profile in pairs(account) do
        assert(type(profile) == "table",
            "Saved profile " .. tostring(profileName) .. " is malformed; no cleanup was performed")
        local version = profile.version
        assert(type(version) == "number" and version >= 1 and version % 1 == 0
                and version <= this.SettingsVersion,
            "Saved profile " .. tostring(profileName) .. " has an unsupported version; no cleanup was performed")
        local rules = profile.trackedRules
        assert(rules == nil or type(rules) == "table",
            "Saved rules in profile " .. tostring(profileName) .. " are malformed; no cleanup was performed")
        if rules ~= nil then
            for ruleKey, rule in pairs(rules) do
                assert(type(ruleKey) == "string" and type(rule) == "table",
                    "Saved rule in profile " .. tostring(profileName) .. " is malformed; no cleanup was performed")
            end
        end
        profilePlans[#profilePlans + 1] = profile
    end

    local assignmentRemovals = this.AutoCategoryIntegration.PreflightSavedDataCleanup()
    for _, profile in ipairs(profilePlans) do
        invalidAutoCategoryProfiles[profile] = nil
        profile.autoCategoryIntegrationEnabled = nil
        profile.autoCategorySetupComplete = nil
        profile.autoCategoryOrder = nil
        profile.autoCategoryInitialized = nil
        for _, rule in pairs(profile.trackedRules or {}) do
            rule.autoCategoryEnabled = nil
            rule.autoCategoryAnchor = nil
            rule.autoCategoryRank = nil
            rule.autoCategoryOverrides = nil
        end
    end
    local removedAssignments = 0
    if assignmentRemovals ~= nil then
        removedAssignments = this.AutoCategoryIntegration.ApplySavedDataCleanup(assignmentRemovals)
    end

    if this.accountWide ~= nil and this.character ~= nil then
        this.InvalidateRuleCache()
        this.ValidateSavedRuleProfiles()
        this.AutoCategoryIntegration.OnEnablementChanged(false)
        this.RefreshTrackedItemsEditor()
        this.RefreshGroupsEditor()
        this.RefreshAutoCategoryEditor()
        this.RefreshItemTrackerPanel()
    end
    return #profilePlans, removedAssignments
end

local function CopyItemListProfile(source, destination)
    if source.trackedRules ~= nil then ValidateSavedRules(source.trackedRules, "Source profile.trackedRules") end
    if source.trackedItems ~= nil then CheckTrackedItems(source.trackedItems, "Source profile.trackedItems") end
    ValidateAutoCategoryProfile(source, "Source profile")
    local rules = source.trackedRules == nil and {} or CopySavedValue(source.trackedRules)
    local items = source.trackedItems == nil and {} or CopySavedValue(source.trackedItems)
    for _, item in pairs(items) do
        if item.display == nil then item.display = {} end
        if item.mode ~= nil then
            item.display.show = item.display.show ~= false or item.mode ~= 3
            item.display.notify = item.display.notify == true or item.mode == 2
            item.mode = nil
        end
    end
    for ruleKey in pairs(rules) do NormalizeRule(rules, ruleKey) end
    local order = NormalizeAutoCategoryOrder(source.autoCategoryOrder)
    CheckAutoCategoryOrder(order, "Copied profile.autoCategoryOrder", rules)
    local preferences = CopyValues(source)
    PrepareProfilePreferences(preferences)
    destination.trackedRules = rules
    destination.trackedItems = items
    destination.autoCategorySetupComplete = source.autoCategorySetupComplete
    destination.autoCategoryOrder = order
    for _, key in ipairs(preferenceFields) do destination[key] = CopySavedValue(preferences[key]) end
    destination.itemListInitialized = true
end

function this.SetUseCharacterItemList(value)
    assert(type(value) == "boolean", "Character list preference must be boolean")
    local source = this.GetAutoCategoryProfile()
    local destination = value and this.character or this.accountWide
    if value and destination ~= source and destination.itemListInitialized ~= true then
        CopyItemListProfile(this.accountWide, destination)
    end
    this.character.useCharacterItemList = value
    trackerContextRevision = trackerContextRevision + 1
    this.InvalidateRuleCache()
    this.AutoCategoryIntegration.OnProfileChanged()
end

function this.UpdateRuleFlag(ruleName, flagKey, value)
    assert(customDisplayDefaults[flagKey] ~= nil or extendedDisplayFlags[flagKey],
        "Unknown rule display flag: " .. tostring(flagKey))
    assert(value == nil or type(value) == "boolean", "Rule display flags must be boolean or nil")
    local base = GetBaseline(ruleName)
    local savedRules = GetRawSavedRules()
    if savedRules[ruleName] == nil then savedRules[ruleName] = {} end
    local saved = savedRules[ruleName]
    local defaults = GetDisplayDefaults(base)
    if saved.display == nil then saved.display = {} end
    local default = defaults[flagKey]
    if extendedDisplayFlags[flagKey] then default = GetExtendedDefault(defaults, saved.display, flagKey) end
    if value == default then value = nil end
    saved.display[flagKey] = value
    PruneRule(savedRules, ruleName)
    this.InvalidateRuleCache()
    this.AutoCategoryIntegration.OnRuleMutation("rename", ruleName)
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
    this.AutoCategoryIntegration.OnRuleMutation("rename", ruleName)
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
    this.AutoCategoryIntegration.OnRuleMutation("patterns", ruleName)
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
    for _, orders in pairs(this.GetAutoCategoryProfile().autoCategoryOrder.contexts) do
        for _, mode in ipairs({ "display", "matching" }) do
            for index = #orders[mode], 1, -1 do
                if orders[mode][index] == "ic:" .. ruleName then table.remove(orders[mode], index) end
            end
        end
        orders.displayPositions["ic:" .. ruleName] = nil
        orders.hidden["ic:" .. ruleName] = nil
    end
    this.InvalidateRuleCache()
    this.AutoCategoryIntegration.OnRuleMutation("delete", ruleName)
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
    this.AutoCategoryIntegration.OnRuleMutation("reset", ruleName)
end

------------------------------------------------------------------
-- Profile Copying Logic
------------------------------------------------------------------
function this.GetSavedAccountProfiles()
    local saved = _G[this.SettingsName]
    assert(type(saved) == "table" and type(saved.Default) == "table", "Saved profile namespace is unavailable")
    local account = saved.Default[GetDisplayName()]
    assert(type(account) == "table", "Current account's saved profiles are unavailable")
    return account
end

function this.CopyProfile(sourceKey)
    assert(type(sourceKey) == "string" and sourceKey ~= "", "Profile source key must be a non-empty string")
    local sourceBlock = this.GetSavedAccountProfiles()[sourceKey]

    if sourceBlock == nil then return false end
    local context = "Imported profile " .. sourceKey
    assert(type(sourceBlock) == "table", context .. " must be a table")
    local destination = this.GetSettingsProfile()
    assert(sourceBlock ~= destination and sourceBlock.trackedRules ~= destination.trackedRules,
        "Cannot copy a profile onto itself")
    assert(sourceBlock.itemListInitialized ~= false, "Cannot copy an uninitialized character profile")
    if sourceBlock.trackedRules ~= nil then
        ValidateSavedRules(sourceBlock.trackedRules, context .. ".trackedRules")
    end
    if not ValidateAutoCategoryBoundary(sourceBlock, context) then return false end
    if sourceBlock.trackedItems ~= nil then
        CheckTrackedItems(sourceBlock.trackedItems, context .. ".trackedItems")
    end
    CopyItemListProfile(sourceBlock, destination)
    this.InvalidateRuleCache()
    trackerContextRevision = trackerContextRevision + 1
    this.AutoCategoryIntegration.OnProfileChanged()
    return true
end

function this.SavedValuesEqual(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do
        if not this.SavedValuesEqual(value, right[key]) then return false end
    end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

function this.CaptureEditorState(panel, contextKey, mode)
    local profile = this.GetSettingsProfile()
    if panel == "autocategory" then
        local contextOrder = profile.autoCategoryOrder.contexts[contextKey]
        return { order = CopySavedValue(contextOrder[mode]), hidden = CopySavedValue(contextOrder.hidden),
            displayPositions = CopySavedValue(contextOrder.displayPositions) }
    end
    assert(panel == "items" or panel == "groups", "Unknown editor snapshot scope")
    local snapshot = {
        trackedRules = CopySavedValue(profile.trackedRules),
        autoCategoryOrder = CopySavedValue(profile.autoCategoryOrder),
        autoCategorySetupComplete = profile.autoCategorySetupComplete,
    }
    if panel == "items" then
        snapshot.trackedItems = CopySavedValue(profile.trackedItems)
        for _, key in ipairs({ "filterShow", "filterNotify", "filterMute", "filterUntracked", "filterCraftbag" }) do
            snapshot[key] = profile[key]
        end
    end
    return snapshot
end

function this.RestoreEditorState(panel, snapshot, contextKey, mode)
    local profile = this.GetSettingsProfile()
    local candidate = CopyValues(profile)
    local overrides
    if panel == "autocategory" then
        candidate.autoCategoryOrder = CopySavedValue(profile.autoCategoryOrder)
        local restored = candidate.autoCategoryOrder.contexts[contextKey]
        restored[mode] = CopySavedValue(snapshot.order)
        restored.hidden = CopySavedValue(snapshot.hidden)
        restored.displayPositions = CopySavedValue(snapshot.displayPositions)
        overrides = { [contextKey] = restored }
    else
        for key, value in pairs(snapshot) do candidate[key] = CopySavedValue(value) end
        candidate.autoCategorySetupComplete = snapshot.autoCategorySetupComplete
        overrides = candidate.autoCategoryOrder.contexts
    end
    ValidateSavedRules(candidate.trackedRules, "Undo candidate.trackedRules")
    CheckTrackedItems(candidate.trackedItems, "Undo candidate.trackedItems")
    CheckAutoCategoryOrder(candidate.autoCategoryOrder, "Undo candidate.autoCategoryOrder", candidate.trackedRules)
    if this.AutoCategoryIntegration.IsEditorActive() then
        local rules = this.GetRuntimeRules(candidate.trackedRules)
        for key, order in pairs(overrides) do
            local available = {}
            for _, row in ipairs(this.AutoCategoryIntegration.ResolveAutoCategoryOrder(key, { mode = "display" })) do
                available[row.reference] = true
            end
            for _, orderMode in ipairs({ "display", "matching" }) do
                for _, reference in ipairs(order[orderMode]) do
                    if reference:sub(1, 3) == "ac:" and not available[reference] then
                        this.Utils.UserError("A category in the opening state no longer exists. Close and reopen the editor.",
                            "Undo changes unavailable")
                        return false
                    end
                end
            end
        end
        local prepared = this.AutoCategoryIntegration.PreflightAutoCategory(overrides, rules)
        if not prepared then return false end
        this.AutoCategoryIntegration.ProjectAutoCategory(prepared)
        candidate.autoCategoryOrder = prepared.order
    end
    if panel ~= "autocategory" then
        profile.trackedRules = candidate.trackedRules
        profile.autoCategorySetupComplete = candidate.autoCategorySetupComplete
        if panel == "items" then
            profile.trackedItems = candidate.trackedItems
            for _, key in ipairs({ "filterShow", "filterNotify", "filterMute", "filterUntracked", "filterCraftbag" }) do
                profile[key] = candidate[key]
            end
        end
    end
    profile.autoCategoryOrder = candidate.autoCategoryOrder
    this.InvalidateRuleCache()
    trackerContextRevision = trackerContextRevision + 1
    this.UpdateEventRegistry()
    this.RefreshItemTrackerPanel()
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

local function ItemNameMatchesCompiledRule(lowerName, compiledIncludes, compiledExcludes)
    local included = false
    for _, pattern in ipairs(compiledIncludes) do
        if lowerName:match(pattern) ~= nil then
            included = true
            break
        end
    end
    if not included then return false end

    for _, pattern in ipairs(compiledExcludes) do
        if lowerName:match(pattern) ~= nil then return false end
    end
    return true
end

function this.ItemMatchesRuntimeRule(itemLink, rule)
    local name = GetItemLinkName(itemLink)
    if not name then return false end
    return ItemNameMatchesCompiledRule(name:lower(), rule.compiledPatterns, rule.compiledExcludedPatterns)
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
    local notifyChat, notifyHud = false, false
    if targetData then
        local display = this.ResolveItemDisplay(targetData.display)
        notifyChat, notifyHud = display.notifyChat, display.notifyHud
    end
    for ruleName, ruleData in pairs(trackedRules) do
        local display = ruleData.display
        if (ruleName == "miscellaneous" or not display.isHidden)
            and display.notify and this.ItemMatchesRuntimeRule(itemLink, ruleData) then
            notifyChat = notifyChat or display.notifyChat
            notifyHud = notifyHud or display.notifyHud
        end
    end

    if notifyChat or notifyHud then
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

            this.Utils.UserWarning(notifyChat and chat or nil, notifyHud and hud or nil, true)
        end

        itemCountsCache[itemId] = currentCount
    end
end

function this.HasTrackedItemNotifications()
    for _, item in pairs(this.GetActiveTrackedItems()) do
        if this.ResolveItemDisplay(item.display).notify then return true end
    end
    for key, rule in pairs(this.GetRuntimeRules()) do
        if (key == "miscellaneous" or not rule.display.isHidden) and rule.display.notify then return true end
    end
    return false
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
    for ruleName, rule in pairs(compiledRules) do
        if ItemNameMatchesCompiledRule(lowerName, rule.compiledPatterns, rule.compiledExcludedPatterns) then
            matchedRules[ruleName] = true
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
        assert(type(ruleData.compiledExcludedPatterns) == "table",
            "Rule " .. ruleName .. " is missing compiledExcludedPatterns")
        compiledRules[ruleName] = {
            compiledPatterns = ruleData.compiledPatterns,
            compiledExcludedPatterns = ruleData.compiledExcludedPatterns,
        }
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
