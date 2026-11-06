local this = InventoryCompanion
local integration = {}
this.AutoCategoryIntegration = integration

local pluginName = "Inventory Companion"
local ruleTag = "Inventory Companion"
local predicateName = "ic_group"
local categoryNameMarkupSuffix = "|cFFFFFF|r"
local otherRuleKey = "__ic_other"
local otherRule = {
    displayName = "Other", patterns = { "*" },
    compiledPatterns = { "^.*$" }, compiledExcludedPatterns = {},
}

local contexts = {
    { key = "backpack", title = "Backpack", bagType = function() return AC_BAG_TYPE_BACKPACK end,
        inventoryType = function() return INVENTORY_BACKPACK end },
    { key = "bank", title = "Bank", bagType = function() return AC_BAG_TYPE_BANK end,
        inventoryType = function() return INVENTORY_BANK end },
    { key = "guild_bank", title = "Guild Bank", bagType = function() return AC_BAG_TYPE_GUILDBANK end,
        inventoryType = function() return INVENTORY_GUILD_BANK end },
    { key = "house_bank", title = "House Bank", bagType = function() return AC_BAG_TYPE_HOUSEBANK end,
        inventoryType = function() return INVENTORY_HOUSE_BANK end },
    { key = "crafting_station", title = "Crafting Station", bagType = function() return AC_BAG_TYPE_CRAFTSTATION end,
        inventoryType = function() return 880 end },
    { key = "craft_bag", title = "Craft Bag", bagType = function() return AC_BAG_TYPE_CRAFTBAG end,
        inventoryType = function() return INVENTORY_CRAFT_BAG end },
    { key = "furniture_vault", title = "Furniture Vault", bagType = function() return AC_BAG_TYPE_FURNVAULT end,
        inventoryType = function() return INVENTORY_FURNITURE_VAULT end },
}

local contextByKey = {}
for _, context in ipairs(contexts) do contextByKey[context.key] = context end

local status = { state = "uninitialized", message = "AutoCategory integration has not initialized." }
integration.unavailableAssignments = {}
local registeredPlugin
local hooksInstalled = false
local reconciling = false
local pendingGeneration = 0
local pendingFullReconcile = false
local nextErrorWindow = 0
local resetProfile
local InstallExternalHooks
local CopySavedValue
local function SetStatus(state, message)
    if status.state == state and status.message == message then return end
    status = { state = state, message = message }
    if state == "unsupported" then
        d("[InventoryCompanion] WARNING: " .. message
            .. " Open the IC AutoCategory panel for recovery, or IC Settings > AutoCategory Integration > More information.")
    end
    if this.RefreshAutoCategoryUI then this.RefreshAutoCategoryUI() end
end

-- Action timing diagnostics, active only in Debug Mode. Slow actions are reported to chat, never raised, so
-- diagnostics cannot block the editor or disable the integration.
local timing = {
    historySize = 12,
    history = {},
}
integration.Timing = timing
local activeAction
local nextFrameCheck = 0
local currentReconcileReason
local unpackValues = unpack or table.unpack

local function PackValues(...)
    return { n = select("#", ...), ... }
end

local function FormatTimingValue(value)
    if type(value) ~= "table" then return tostring(value) end
    local parts = {}
    for index, item in ipairs(value) do parts[index] = tostring(item) end
    return "[" .. #parts .. "] " .. table.concat(parts, ", ")
end

local function BuildTimingReport(record, stage, elapsedMs)
    local lines = {
        string.format("[InventoryCompanion] Slow AutoCategory %s: %s took %d ms %s (threshold %d ms).",
            record.source, record.operation, elapsedMs, stage, record.thresholdMs),
        "Synchronous total: " .. tostring(record.totalMs) .. " ms",
        "Since previous timed action finished: "
            .. (record.sincePreviousMs and (record.sincePreviousMs .. " ms") or "none this session"),
    }
    if record.failure then lines[#lines + 1] = "Integration failed during this action: " .. record.failure end
    lines[#lines + 1] = "Phases:"
    for _, phase in ipairs(record.phases) do
        lines[#lines + 1] = "  " .. string.rep("  ", phase.depth) .. phase.name .. ": "
            .. (phase.ms and (phase.ms .. " ms") or "did not finish")
    end
    lines[#lines + 1] = "State at start:"
    local keys = {}
    for key in pairs(record.snapshot) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        lines[#lines + 1] = "  " .. key .. ": " .. FormatTimingValue(record.snapshot[key])
    end
    lines[#lines + 1] = "Recent timed actions (oldest first):"
    for _, entry in ipairs(timing.history) do
        lines[#lines + 1] = string.format("  %s: %s, %d ms, +%s ms after previous", entry.source, entry.operation,
            entry.totalMs, tostring(entry.sincePreviousMs or "-"))
    end
    return table.concat(lines, "\n")
end

local function ReportSlowAction(record, stage, elapsedMs)
    local report = BuildTimingReport(record, stage, elapsedMs)
    timing.lastSlowReport = report
    d(report)
end

local function ScheduleNextFrameCheck(record)
    nextFrameCheck = nextFrameCheck + 1
    local updateName = "InventoryCompanion_AutoCategoryTiming" .. nextFrameCheck
    EVENT_MANAGER:RegisterForUpdate(updateName, 0, function()
        EVENT_MANAGER:UnregisterForUpdate(updateName)
        local elapsed = GetGameTimeMilliseconds() - record.started
        record.nextFrameMs = elapsed
        if elapsed > record.thresholdMs then ReportSlowAction(record, "before the next frame", elapsed) end
    end)
end

local function AppendTraceback(failure)
    return debug.traceback(tostring(failure), 2)
end

function integration.TimePhase(name, operation, ...)
    local record = activeAction
    if record == nil then return operation(...) end
    local phase = { name = name, depth = record.depth }
    record.phases[#record.phases + 1] = phase
    record.depth = record.depth + 1
    local started = GetGameTimeMilliseconds()
    local results = PackValues(operation(...))
    phase.ms = GetGameTimeMilliseconds() - started
    record.depth = phase.depth
    return unpackValues(results, 1, results.n)
end

-- Times a user action or deferred callback; nested calls are recorded as phases of the outer action.
function integration.TimeAction(source, operation, snapshot, action, ...)
    assert(type(source) == "string" and type(operation) == "string", "Timed action requires source and operation names")
    assert(type(snapshot) == "function" and type(action) == "function", "Timed action requires snapshot and action functions")
    if activeAction ~= nil then return integration.TimePhase(source .. " " .. operation, action, ...) end
    if this.accountWide.debugEnabled ~= true then return action(...) end
    local started = GetGameTimeMilliseconds()
    local record = {
        source = source, operation = operation, snapshot = snapshot(), phases = {}, depth = 0, started = started,
        sincePreviousMs = timing.lastFinished and started - timing.lastFinished or nil,
        thresholdMs = this.accountWide.autoCategoryTimingThresholdMs,
    }
    local faultedBefore = integration.IsFaulted()
    local arguments = PackValues(...)
    activeAction = record
    -- Lua 5.1 xpcall does not forward extra arguments.
    local results = PackValues(xpcall(function() return action(unpackValues(arguments, 1, arguments.n)) end,
        AppendTraceback))
    activeAction = nil
    if not faultedBefore and integration.IsFaulted() then record.failure = this.autoCategoryFailure end
    local finished = GetGameTimeMilliseconds()
    record.totalMs = finished - started
    timing.lastFinished = finished
    timing.lastAction = record
    table.insert(timing.history, {
        source = source, operation = operation, totalMs = record.totalMs, sincePreviousMs = record.sincePreviousMs,
    })
    if #timing.history > timing.historySize then table.remove(timing.history, 1) end
    if not results[1] then error(results[2], 0) end
    if record.totalMs > record.thresholdMs then
        ReportSlowAction(record, "synchronously", record.totalMs)
    else
        ScheduleNextFrameCheck(record)
    end
    return unpackValues(results, 2, results.n)
end

local function IntegrationSnapshot()
    return {
        integrationState = status.state,
        faulted = integration.IsFaulted(),
        reconciling = reconciling,
        autoCategoryInited = AutoCategory ~= nil and AutoCategory.Inited == true,
    }
end
integration.TimingSnapshot = IntegrationSnapshot

function integration.GetStatus()
    return status.state, status.message
end

function integration.IsFaulted()
    return this.autoCategoryFailure ~= nil
end

function integration.NeedsRecovery()
    return integration.IsFaulted() or status.state == "unsupported"
end

function integration.GetRecoveryMessage()
    assert(integration.NeedsRecovery(), "AutoCategory has no failure to display")
    local reason = this.autoCategoryFailure or status.message
    return "|cFF4444|t24:24:EsoUI/Art/Miscellaneous/large_yellow_warning.dds|t "
        .. "AutoCategory integration needs attention.|r\n"
        .. "Synchronization has stopped to protect your data. Your groups and saved order are preserved.\n\n"
        .. "Reason: " .. reason:gsub("|", "||")
end

function integration.GetProblemRowsMessage()
    assert(integration.NeedsRecovery(), "AutoCategory has no failure to display")
    local records = integration.unavailableAssignments
    if #records == 0 then
        return "No specific problematic assignment rows were identified. Use Show details for the failure report."
    end
    local lines = { "Problematic assignments (" .. #records .. "):" }
    for _, record in ipairs(records) do
        lines[#lines + 1] = contextByKey[record.context].title .. ": "
            .. record.line.name:gsub("|", "||") .. " [key=" .. record.ruleKey:gsub("|", "||") .. "]"
    end
    return table.concat(lines, "\n")
end

function integration.ShowRecoveryDetails()
    assert(integration.NeedsRecovery(), "AutoCategory has no failure details")
    if integration.IsFaulted() then return integration.ShowLastError() end
    local lines = { status.message, "", "Problematic assignments:" }
    for _, record in ipairs(integration.unavailableAssignments) do
        lines[#lines + 1] = contextByKey[record.context].title .. ": "
            .. record.line.name .. " [key=" .. record.ruleKey .. "]"
    end
    error(table.concat(lines, "\n"), 0)
end

local function ScheduleErrorWindow(message)
    nextErrorWindow = nextErrorWindow + 1
    local updateName = "InventoryCompanion_AutoCategoryError" .. nextErrorWindow
    EVENT_MANAGER:RegisterForUpdate(updateName, 0, function()
        EVENT_MANAGER:UnregisterForUpdate(updateName)
        error(message, 0)
    end)
end

function integration.ShowLastError()
    assert(integration.IsFaulted(), "AutoCategory has no stored integration error")
    local report = this.autoCategoryFailureTraceback or this.autoCategoryFailure
    if integration.failureDiagnostics then
        report = report .. "\n\n" .. integration.failureDiagnostics
    end
    error(report, 0)
end

function integration.Run(operation, ...)
    if integration.IsFaulted() then return false, this.autoCategoryFailure end
    local arguments = { n = select("#", ...), ... }
    local traceback
    -- Lua 5.1 xpcall does not forward extra arguments; the handler keeps the stack for Debug Mode reports.
    local ok, result = xpcall(function() return operation(unpackValues(arguments, 1, arguments.n)) end,
        function(failure)
            traceback = debug.traceback(tostring(failure), 2)
            return failure
        end)
    if not ok then
        integration.Fail(result, traceback)
        return false, result
    end
    return result
end

function integration.IsAvailable()
    return not integration.IsFaulted() and (status.state == "available" or status.state == "disabled")
end

function integration.IsEditorActive()
    return integration.IsAvailable() and this.GetAutoCategoryState().enabled
end

function integration.IsPanelAvailable()
    return type(AutoCategory) == "table"
end

function integration.IsAwaitingSetup()
    local profile = this.GetAutoCategoryProfile()
    return resetProfile == profile and this.accountWide.autoCategoryIntegrationEnabled ~= true
        and profile.autoCategorySetupComplete ~= true
end

function integration.GetContexts()
    local result = {}
    for _, context in ipairs(contexts) do
        result[#result + 1] = { key = context.key, title = context.title }
    end
    return result
end

function integration.GetHeadingDetails(name)
    assert(type(name) == "string" and name ~= "", "AutoCategory heading name must be non-empty")
    local definition = AutoCategory.GetRuleByName(name)
    if definition == nil then return nil end
    assert(type(definition) == "table" and type(definition.rule) == "string",
        "AutoCategory heading definition is malformed: " .. name)
    return { name = name, rule = definition.rule }
end

local function GetRuntimeRules()
    local rules = this.GetRuntimeRules()
    local profile = this.GetAutoCategoryProfile()
    assert(next(this.preLoadedRulesets) ~= nil, "IC baseline groups have not finished loading")
    assert(rules[otherRuleKey] == nil and profile.trackedRules[otherRuleKey] == nil,
        "IC group identity collides with the internal Other helper")
    for key in pairs(this.preLoadedRulesets) do
        assert(rules[key] ~= nil and rules[key].isPreloaded == true,
            "IC runtime is incomplete: missing baseline group " .. key)
    end
    for key in pairs(profile.trackedRules) do
        assert(rules[key] ~= nil, "IC runtime is incomplete: missing saved group " .. key)
    end
    for key, rule in pairs(rules) do
        assert(type(rule.displayName) == "string" and type(rule.autoCategoryEnabled) == "boolean"
            and type(rule.compiledPatterns) == "table" and type(rule.compiledExcludedPatterns) == "table"
            and type(rule.display) == "table" and type(rule.patterns) == "table"
            and (this.preLoadedRulesets[key] ~= nil or profile.trackedRules[key] ~= nil)
            and rule.isPreloaded == (this.preLoadedRulesets[key] ~= nil),
            "IC runtime group is incomplete: " .. key)
    end
    return rules
end

local function IsOrdinaryRule(ruleKey, rule)
    return ruleKey ~= "miscellaneous" and rule.isPreloaded ~= nil
end

local function GetOrderedRuleKeys(rules)
    local keys = {}
    for ruleKey, rule in pairs(rules) do
        if IsOrdinaryRule(ruleKey, rule) then table.insert(keys, ruleKey) end
    end
    table.sort(keys, function(left, right)
        local a, b = rules[left], rules[right]
        local nameA, nameB = a.displayName:lower(), b.displayName:lower()
        if nameA ~= nameB then return nameA < nameB end
        return left < right
    end)
    return keys
end

local function GetCategoryName(rule)
    return rule.displayName .. categoryNameMarkupSuffix
end

local function QuoteLuaString(value)
    assert(type(value) == "string" and value ~= "", "AutoCategory group key must be a non-empty string")
    return string.format("%q", value)
end

local function BuildDefinition(ruleKey, rule)
    return {
        name = GetCategoryName(rule),
        tag = ruleTag,
        rule = predicateName .. "(" .. QuoteLuaString(ruleKey) .. ")",
        description = "Inventory Companion group: " .. rule.displayName,
        icIntegrationOwned = true,
        icRuleKey = ruleKey,
    }
end

local function BuildDefinitions(rules)
    rules = rules or GetRuntimeRules()
    local definitions = {}
    for _, ruleKey in ipairs(GetOrderedRuleKeys(rules)) do
        definitions[#definitions + 1] = BuildDefinition(ruleKey, rules[ruleKey])
    end
    definitions[#definitions + 1] = BuildDefinition(otherRuleKey, otherRule)
    return definitions
end

local function ContainsName(entries, name)
    if entries == nil then return false end
    assert(type(entries) == "table", "AutoCategory rule collection must be a table")
    for _, entry in pairs(entries) do
        assert(type(entry) == "table", "AutoCategory rule collection contains a malformed entry")
        if entry.name == name then return true end
    end
    return false
end

local function CheckExternalShape(ac)
    assert(type(ac) == "table", "AutoCategory namespace must be a table")
    assert(type(ac.RegisterPlugin) == "function" and type(ac.AddRuleFunc) == "function",
        "AutoCategory plugin registration APIs are unavailable")
    assert(type(ac.Plugins) == "table" and type(ac.RulesW) == "table"
        and type(ac.RulesW.ruleList) == "table" and type(ac.RulesW.ruleNames) == "table"
        and type(ac.RulesW.AddRule) == "function",
        "AutoCategory rule/plugin registries are incompatible")
    assert(type(ac.acctSaved) == "table" and type(ac.charSaved) == "table",
        "AutoCategory account or character saved profiles are unavailable")
    assert(type(ac.GetRuleByName) == "function" and type(ac.predefinedRules) == "table"
        and type(ac.RefreshList) == "function",
        "AutoCategory rule lookup, definitions, or refresh APIs are unavailable")
    assert(type(ac.cacheInitBag) == "function" and type(ac.cacheInitialize) == "function"
        and type(ac.cacheRuleInitialize) == "function" and type(ac.RulesW.CompileAll) == "function"
        and type(ac.RuleList) == "table" and type(ac.RuleList.removeRuleByName) == "function"
        and type(ac.RulesW.compiled) == "table",
        "AutoCategory cache or rule lifecycle APIs are incompatible")
end

local function CheckActiveAssignments(ac, allowNotReady)
    if allowNotReady and ac.Inited ~= true then
        if type(ac.saved) ~= "table" or type(ac.saved.bags) ~= "table" then return false end
        for _, context in ipairs(contexts) do
            local bag = ac.saved.bags[context.bagType()]
            if bag == nil then return false end
            assert(type(bag) == "table", "AutoCategory active assignments are malformed for " .. context.title)
            if bag.rules == nil then return false end
            assert(type(bag.rules) == "table", "AutoCategory active assignments are malformed for " .. context.title)
        end
        return true
    end
    assert(type(ac.saved) == "table" and type(ac.saved.bags) == "table",
        "AutoCategory active profile assignments are unavailable")
    for _, context in ipairs(contexts) do
        local bagType = context.bagType()
        assert(type(bagType) == "number" and type(ac.saved.bags[bagType]) == "table"
            and type(ac.saved.bags[bagType].rules) == "table",
            "AutoCategory is missing active assignments for " .. context.title)
    end
    return true
end

local function CheckDefinitionCollision(ac, definitions)
    local desiredNames = {}
    for _, definition in ipairs(definitions) do
        assert(not desiredNames[definition.name],
            "IC AutoCategory category name collision: " .. definition.name)
        desiredNames[definition.name] = true
    end
    local sources = {
        ac.RulesW.ruleList,
        ac.predefinedRules,
        ac.default_rules and ac.default_rules.rules,
        ac.acctRules and ac.acctRules.rules,
    }
    for _, profile in ipairs({ ac.acctSaved, ac.charSaved, ac.saved }) do
        if profile.rules ~= nil then sources[#sources + 1] = profile.rules end
    end
    for pluginKey, plugin in pairs(ac.Plugins) do
        if pluginKey ~= pluginName and plugin.predef then sources[#sources + 1] = plugin.predef end
    end
    for _, definition in ipairs(definitions) do
        for _, source in ipairs(sources) do
            if ContainsName(source, definition.name) then
                local existing
                for _, entry in pairs(source) do
                    if entry.name == definition.name then existing = entry; break end
                end
                if not (existing and existing.icIntegrationOwned) then
                    return false, "AutoCategory name collision: " .. definition.name
                end
            end
        end
        for _, profile in ipairs({ ac.acctSaved, ac.charSaved, ac.saved }) do
            for _, context in ipairs(contexts) do
                local bag = profile.bags and profile.bags[context.bagType()]
                if bag ~= nil then
                    assert(type(bag.rules) == "table", "AutoCategory saved assignments are malformed")
                    for _, assignment in ipairs(bag.rules) do
                        assert(type(assignment) == "table", "AutoCategory assignment is malformed")
                        if assignment.name == definition.name and assignment.icOwned ~= true then
                            return false, "AutoCategory assignment collision: " .. definition.name
                        end
                    end
                end
            end
        end
    end
    return true
end

local function SameDefinition(existing, desired)
    if type(existing) ~= "table" then return false end
    for key, value in pairs(desired) do
        if existing[key] ~= value then return false end
    end
    return true
end

local function DefinitionsMatch(ac, plugin, definitions)
    if #plugin.predef ~= #definitions then return false end
    local pluginByName, predefinedByName = {}, {}
    for _, definition in ipairs(plugin.predef) do pluginByName[definition.name] = definition end
    local ownedCount = 0
    for _, definition in ipairs(ac.predefinedRules) do
        if definition.icIntegrationOwned then
            predefinedByName[definition.name] = definition
            ownedCount = ownedCount + 1
        end
    end
    if ownedCount ~= #definitions then return false end
    for _, definition in ipairs(definitions) do
        if not SameDefinition(pluginByName[definition.name], definition)
            or not SameDefinition(predefinedByName[definition.name], definition)
            or not SameDefinition(ac.GetRuleByName(definition.name), definition) then
            return false
        end
    end
    return true
end

local function SyncDefinitions(ac, definitions)
    local plugin = ac.Plugins[pluginName]
    assert(plugin and type(plugin.predef) == "table", "AutoCategory did not retain the integration plugin")
    if DefinitionsMatch(ac, plugin, definitions) then return end
    local desiredNames = {}
    for _, definition in ipairs(definitions) do desiredNames[definition.name] = true end

    for index = #plugin.predef, 1, -1 do
        local definition = plugin.predef[index]
        if definition.icIntegrationOwned and not desiredNames[definition.name] then
            ac.RuleList.removeRuleByName(ac.RulesW, definition.name)
            ac.RulesW.compiled[definition.name] = nil
            table.remove(plugin.predef, index)
            for predefIndex = #ac.predefinedRules, 1, -1 do
                if ac.predefinedRules[predefIndex].name == definition.name
                    and ac.predefinedRules[predefIndex].icIntegrationOwned then
                    table.remove(ac.predefinedRules, predefIndex)
                end
            end
        end
    end
    -- removeRuleByName shifts later rules without reindexing ruleNames, so name lookups are stale until rebuilt.
    ac.cacheRuleInitialize()
    for _, definition in ipairs(definitions) do
        local existing = ac.GetRuleByName(definition.name)
        if existing and existing.icIntegrationOwned then
            ac.RulesW.AddRule(ac.RulesW, definition, true)
        elseif existing == nil then
            ac.RulesW.AddRule(ac.RulesW, definition)
        else
            error("AutoCategory definition collision appeared after preflight: " .. definition.name)
        end
        local found
        for index, old in ipairs(plugin.predef) do
            if old.icRuleKey == definition.icRuleKey then
                plugin.predef[index] = definition
                found = true
                break
            end
        end
        if not found then plugin.predef[#plugin.predef + 1] = definition end
        found = false
        for index, old in ipairs(ac.predefinedRules) do
            if old.icRuleKey == definition.icRuleKey and old.icIntegrationOwned then
                ac.predefinedRules[index] = definition
                found = true
                break
            end
        end
        if not found then ac.predefinedRules[#ac.predefinedRules + 1] = definition end
    end
    ac.cacheRuleInitialize()
    ac.RulesW.CompileAll(ac.RulesW)
end

local function RefreshContexts(ac, changed, rebuildCache)
    for _, context in ipairs(contexts) do
        if changed[context.key] then
            if rebuildCache then
                integration.TimePhase("AutoCategory cacheInitBag " .. context.key, ac.cacheInitBag, context.bagType())
            end
            -- Hidden inventories are only marked dirty by ZOS and rebuild when next shown; forcing them re-sorts every bag.
            integration.TimePhase("AutoCategory RefreshList " .. context.key, ac.RefreshList,
                context.inventoryType(), false)
        end
    end
end

local function RemoveOwnedAssignments(refresh)
    local ac = AutoCategory
    CheckExternalShape(ac)
    if not CheckActiveAssignments(ac, true) then return end
    local templatesByContext = {}
    for _, context in ipairs(contexts) do
        local bag = ac.saved.bags[context.bagType()]
        local templates = bag.icAssignmentTemplates == nil and {} or CopySavedValue(bag.icAssignmentTemplates)
        assert(type(templates) == "table", "AutoCategory IC assignment templates must be a table")
        for _, assignment in ipairs(bag.rules) do
            if assignment.icOwned == true then
                assert(type(assignment.icRuleKey) == "string" and assignment.icRuleKey ~= "",
                    "Cannot preserve an IC assignment without its stable identity")
                templates[assignment.icRuleKey] = CopySavedValue(assignment)
            end
        end
        templatesByContext[context.key] = templates
    end
    local changed = {}
    for _, context in ipairs(contexts) do
        local bag = ac.saved.bags[context.bagType()]
        for index = #bag.rules, 1, -1 do
            if bag.rules[index].icOwned == true then
                table.remove(bag.rules, index)
                changed[context.key] = true
            end
            bag.icAssignmentTemplates = templatesByContext[context.key]
        end
    end
    if refresh then RefreshContexts(ac, changed, true) end
end

-- Debug Mode raises the failure from the next frame so the failing caller still gets its normal false result.
local function RaiseDebugFailure(message, traceback)
    -- Saved-variable migration can disable the integration before accountWide (and its Debug Mode flag) loads.
    if this.accountWide == nil or this.accountWide.debugEnabled ~= true then return end
    local report = "[InventoryCompanion] AutoCategory synchronization stopped after this failure (Debug Mode report):\n"
        .. (traceback or debug.traceback(message, 3))
    if integration.failureDiagnostics then
        report = report .. "\n\n" .. integration.failureDiagnostics
    end
    integration.lastFailureReport = report
    ScheduleErrorWindow(report)
end

function integration.Fail(failure, traceback)
    if integration.IsFaulted() then return end
    this.autoCategoryFailure = tostring(failure)
    this.autoCategoryFailureTraceback = traceback or debug.traceback(this.autoCategoryFailure, 2)
    RaiseDebugFailure(this.autoCategoryFailure, traceback)
    pendingGeneration = pendingGeneration + 1
    reconciling = false
    status = {
        state = "error",
        message = "AutoCategory synchronization stopped: " .. this.autoCategoryFailure
            .. " Open the IC AutoCategory panel for recovery, or IC Settings > Integrations > AutoCategory"
            .. " > Settings. Saved settings are preserved; other IC features remain available.",
    }
    d("[InventoryCompanion] WARNING: " .. status.message)
    if this.state ~= nil and this.state.isLoaded then
        local ok, refreshFailure = pcall(this.RefreshAutoCategoryUI)
        if not ok then
            d("[InventoryCompanion] WARNING: AutoCategory UI refresh also failed: " .. tostring(refreshFailure))
        end
    end
end

function integration.PreflightSavedDataCleanup()
    if AutoCategory == nil then return nil end
    CheckExternalShape(AutoCategory)
    local removals = { templates = {} }
    for _, profileName in ipairs({ "acctSaved", "charSaved" }) do
        local profile = AutoCategory[profileName]
        assert(type(profile.bags) == "table",
            "AutoCategory " .. profileName .. " bag assignments are unavailable; no cleanup was performed")
        for _, context in ipairs(contexts) do
            local bag = profile.bags[context.bagType()]
            assert(type(bag) == "table" and type(bag.rules) == "table",
                "AutoCategory " .. profileName .. " assignments are unavailable for " .. context.title
                    .. "; no cleanup was performed")
            removals.templates[#removals.templates + 1] = { bag = bag, value = bag.icAssignmentTemplates }
            for index, assignment in ipairs(bag.rules) do
                assert(type(assignment) == "table", "AutoCategory assignment is malformed; no cleanup was performed")
                if assignment.icOwned == true then
                    removals[#removals + 1] = {
                        profile = profile,
                        rules = bag.rules,
                        index = index,
                        assignment = assignment,
                        context = context,
                    }
                end
            end
        end
    end
    return removals
end

function integration.ApplySavedDataCleanup(removals)
    assert(type(removals) == "table", "AutoCategory cleanup preflight is required")
    local byRules, changedActive, count = {}, {}, 0
    for _, template in ipairs(removals.templates) do
        assert(template.bag.icAssignmentTemplates == template.value,
            "AutoCategory assignment templates changed after cleanup preflight; no cleanup was applied")
    end
    for _, removal in ipairs(removals) do
        local current = removal.rules[removal.index]
        assert(current == removal.assignment,
            "AutoCategory assignments changed after cleanup preflight; no cleanup was applied")
        byRules[removal.rules] = byRules[removal.rules] or {}
        byRules[removal.rules][#byRules[removal.rules] + 1] = removal
    end
    for rules, entries in pairs(byRules) do
        table.sort(entries, function(left, right) return left.index > right.index end)
        for _, removal in ipairs(entries) do
            assert(rules[removal.index] == removal.assignment,
                "AutoCategory assignments changed during cleanup")
            table.remove(rules, removal.index)
            count = count + 1
            if removal.profile.bags == AutoCategory.saved.bags then
                changedActive[removal.context.key] = true
            end
        end
    end
    for _, template in ipairs(removals.templates) do template.bag.icAssignmentTemplates = nil end
    if AutoCategory.Inited == true then RefreshContexts(AutoCategory, changedActive, true) end
    SetStatus("disabled", "AutoCategory integration data was cleared for the selected Inventory Companion account.")
    return count
end

local function ScheduleReconcile(reason, refreshOnly)
    if AutoCategory == nil or status.state == "absent" or not this.GetAutoCategoryState().enabled then return end
    pendingFullReconcile = pendingFullReconcile or not refreshOnly
    pendingGeneration = pendingGeneration + 1
    local generation = pendingGeneration
    zo_callLater(function()
        local previousReason = currentReconcileReason
        currentReconcileReason = reason
        integration.Run(function()
            if generation ~= pendingGeneration or not this.GetAutoCategoryState().enabled then return end
            if AutoCategory.Inited ~= true then return end
            local project = pendingFullReconcile
            pendingFullReconcile = false
            if not project then
                local changed = {}
                for _, context in ipairs(contexts) do changed[context.key] = true end
                RefreshContexts(AutoCategory, changed, false)
            else
                integration.ProjectAutoCategory()
            end
        end)
        currentReconcileReason = previousReason
    end, 100)
end

function integration.OnRuleMutation(kind, ruleKey)
    if AutoCategory == nil or status.state == "absent" then return end
    if not this.GetAutoCategoryState().enabled then return end
    if kind == "patterns" then
        local rule = GetRuntimeRules()[ruleKey]
        assert(rule ~= nil, "Pattern mutation references an unknown Inventory Companion group: "
            .. tostring(ruleKey))
    end
    if kind == "participation" then
        integration.ProjectAutoCategory()
        return
    end
    ScheduleReconcile(kind, kind == "patterns")
end

function integration.OnProfileChanged()
    if integration.IsFaulted() then return end
    pendingGeneration = pendingGeneration + 1
    if AutoCategory == nil or status.state == "absent" then return end
    if this.GetAutoCategoryState().configuredEnabled then
        if status.state == "unsupported" then
            integration.RetrySynchronization()
            return
        end
        ScheduleReconcile("profile", false)
    else
        integration.unavailableAssignments = {}
        RemoveOwnedAssignments(AutoCategory.Inited == true)
        SetStatus("disabled", "AutoCategory integration is disabled account-wide.")
    end
end

function integration.OnEnablementChanged(enabled)
    assert(type(enabled) == "boolean", "AutoCategory enablement must be boolean")
    if integration.IsFaulted() then return end
    pendingGeneration = pendingGeneration + 1
    if AutoCategory == nil or status.state == "absent" then
        SetStatus("absent", "AutoCategory is not loaded; saved integration choices are preserved.")
        return
    end
    if enabled then
        InstallExternalHooks()
        ScheduleReconcile("enabled", false)
    else
        integration.unavailableAssignments = {}
        RemoveOwnedAssignments(AutoCategory.Inited == true)
        SetStatus("disabled", "AutoCategory integration is disabled for this Inventory Companion profile.")
        d("[InventoryCompanion] IC exclusions will stop applying."
            .. " AutoCategory keeps the last matching order set by IC; previously excluded categories may match later than others.")
    end
end

InstallExternalHooks = function()
    if hooksInstalled then return end
    local ac = AutoCategory
    assert(type(ac) == "table" and type(ac.UpdateCurrentSavedVars) == "function"
        and type(ac.cacheInitBag) == "function" and type(ac.cacheInitialize) == "function",
        "AutoCategory lifecycle hook targets are unavailable")
    assert(type(ZO_PostHook) == "function", "ESO post-hook API is unavailable")
    ZO_PostHook(ac, "UpdateCurrentSavedVars", function() integration.Run(function()
        if not reconciling then integration.OnProfileChanged() end
    end) end)
    ZO_PostHook(ac, "cacheInitBag", function() integration.Run(function()
        if not reconciling and this.GetAutoCategoryState().enabled then ScheduleReconcile("external-heading-edit", false) end
    end) end)
    ZO_PostHook(ac, "cacheInitialize", function() integration.Run(function()
        if not reconciling and this.GetAutoCategoryState().enabled then ScheduleReconcile("external-heading-edit", false) end
    end) end)
    hooksInstalled = true
end

local function RegisterPlugin()
    local ac = AutoCategory
    if ac == nil then
        SetStatus("absent", "AutoCategory is not loaded; saved integration choices are preserved.")
        return false
    end
    local ok, failure = pcall(CheckExternalShape, ac)
    if not ok then
        integration.Fail(failure)
        return false
    end
    if ac.Inited == true then
        integration.Fail("AutoCategory initialized before Inventory Companion could register its plugin.")
        return false
    end
    local definitions = BuildDefinitions()
    local collisionFree, collision = CheckDefinitionCollision(ac, definitions)
    if not collisionFree then
        integration.Fail(collision)
        return false
    end
    if ac.Plugins[pluginName] ~= nil then
        integration.Fail("AutoCategory plugin name is already registered.")
        return false
    end
    ac.RegisterPlugin(pluginName, function() integration.Run(function()
        if integration.IsFaulted() then return end
        local function MatchesRule(ruleKey)
            if not this.GetAutoCategoryState().enabled then return false end
            assert(type(ac.checkingItemLink) == "string", "AutoCategory checkingItemLink must be a string")
            if ruleKey == otherRuleKey then return this.ItemMatchesRuntimeRule(ac.checkingItemLink, otherRule) end
            local rules = GetRuntimeRules()
            local rule = rules[ruleKey]
            assert(rule ~= nil, "Registered AutoCategory expression references unknown Inventory Companion group: "
                .. tostring(ruleKey))
            assert(type(ac.checkingItemLink) == "string", "AutoCategory checkingItemLink must be a string")
            return this.ItemMatchesRuntimeRule(ac.checkingItemLink, rule)
        end
        ac.AddRuleFunc(predicateName, function(ruleKey)
            return integration.Run(MatchesRule, ruleKey) == true
        end)
        if this.GetAutoCategoryState().enabled then
            -- AutoCategory sets Inited synchronously after plugin initializers, before this deferred call runs.
            ScheduleReconcile("autocategory-initialized", false)
        else
            RemoveOwnedAssignments(false)
        end
    end) end, definitions)
    registeredPlugin = ac.Plugins[pluginName]
    assert(registeredPlugin and registeredPlugin.predef == definitions,
        "AutoCategory did not retain Inventory Companion's plugin definitions")
    local enabled = this.GetAutoCategoryState().enabled
    SetStatus(enabled and "pending" or "disabled",
        enabled and "AutoCategory plugin is registered; integration will activate after AutoCategory initializes."
            or "AutoCategory integration is disabled for this Inventory Companion profile.")
    if enabled then InstallExternalHooks() end
    return true
end

function integration.Initialize()
    if AutoCategory == nil then
        SetStatus("absent", "AutoCategory is not loaded; saved integration choices are preserved.")
        return
    end
    RegisterPlugin()
end

local projectedOrders = setmetatable({}, { __mode = "k" })
local renameHookInstalled = false

local function CopySequence(sequence)
    local copy = {}
    for index, value in ipairs(sequence) do copy[index] = value end
    return copy
end

local function SameSequence(left, right)
    if #left ~= #right then return false end
    for index = 1, #left do
        if left[index] ~= right[index] then return false end
    end
    return true
end

local function GetManagedRuleKey(assignment, definitionsByName)
    if assignment.icOwned ~= true then return nil end
    if assignment.icRuleKey ~= nil then
        assert(type(assignment.icRuleKey) == "string" and assignment.icRuleKey ~= "",
            "AutoCategory managed assignment has an invalid IC rule identity")
        return assignment.icRuleKey
    end
    local definition = definitionsByName[assignment.name]
    assert(definition and definition.icRuleKey,
        "AutoCategory managed assignment cannot be mapped to an IC group: " .. tostring(assignment.name))
    return definition.icRuleKey
end

local function CountEntries(values)
    if type(values) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(values) do count = count + 1 end
    return count
end

CopySavedValue = function(value, activeTables)
    local valueType = type(value)
    assert(valueType == "table" or valueType == "boolean" or valueType == "number" or valueType == "string",
        "AutoCategory assignment contains an unsupported saved value")
    if valueType ~= "table" then return value end
    activeTables = activeTables or {}
    assert(not activeTables[value], "AutoCategory assignment contains a circular table")
    activeTables[value] = true
    local copy = {}
    for key, nestedValue in pairs(value) do
        assert(type(key) == "string" or type(key) == "number",
            "AutoCategory assignment contains an unsupported saved key")
        copy[key] = CopySavedValue(nestedValue, activeTables)
    end
    activeTables[value] = nil
    return copy
end

local function RestoreArchivedAssignments(ac)
    local archive = this.accountWide.debug.autoCategoryRemovedLines
    local restoredContexts = {}
    for _, record in ipairs(archive) do
        if record.restored ~= true then
            local context = contextByKey[record.context]
            assert(context ~= nil and context.bagType() == record.bagType,
                "AutoCategory recovery archive has an invalid context or bag type")
            local bag = ac.saved.bags[record.bagType]
            assert(type(bag) == "table" and type(bag.rules) == "table",
                "AutoCategory recovery target is unavailable for " .. context.title)
            local alreadyPresent = false
            for _, assignment in ipairs(bag.rules) do
                assert(type(assignment) == "table",
                    "AutoCategory assignment is malformed in " .. context.title)
                if assignment.icOwned == true and assignment.icRuleKey == record.line.icRuleKey then
                    alreadyPresent = true
                    break
                end
            end
            if not alreadyPresent then
                table.insert(bag.rules, math.min(record.index, #bag.rules + 1), CopySavedValue(record.line))
                restoredContexts[context.key] = true
            end
            record.restored = true
        end
    end
    if next(restoredContexts) ~= nil then
        local wasReconciling = reconciling
        reconciling = true
        local ok, failure = xpcall(function()
            RefreshContexts(ac, restoredContexts, true)
        end, function(errorValue)
            reconciling = wasReconciling
            return errorValue
        end)
        reconciling = wasReconciling
        if not ok then error(failure) end
    end
end

local function FindUnavailableAssignments(ac, definitions, rules)
    local definitionsByName, definitionsByKey = {}, {}
    for _, definition in ipairs(definitions) do
        definitionsByName[definition.name] = definition
        definitionsByKey[definition.icRuleKey] = true
    end
    local unavailable = {}
    for _, context in ipairs(contexts) do
        local bag = ac.saved.bags[context.bagType()]
        for index, assignment in ipairs(bag.rules) do
            assert(type(assignment) == "table",
                "AutoCategory assignment is malformed in " .. context.title)
            local ruleKey = GetManagedRuleKey(assignment, definitionsByName)
            local rule = ruleKey and rules[ruleKey]
            if ruleKey ~= nil and ruleKey ~= otherRuleKey and (definitionsByKey[ruleKey] ~= true
                or rule == nil) then
                unavailable[#unavailable + 1] = {
                    context = context.key,
                    bagType = context.bagType(),
                    index = index,
                    ruleKey = ruleKey,
                    line = CopySavedValue(assignment),
                }
            end
        end
    end
    return unavailable
end

local function FormatSavedValue(value)
    if type(value) == "string" then return string.format("%q", value) end
    if type(value) ~= "table" then return tostring(value) end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(left, right) return tostring(left) < tostring(right) end)
    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = FormatSavedValue(key) .. "=" .. FormatSavedValue(value[key])
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

function integration.GetOrphanedAssignmentReport(veryVerbose)
    assert(type(veryVerbose) == "boolean", "AutoCategory recovery report verbosity must be boolean")
    local archived = this.accountWide.debug.autoCategoryRemovedLines
    local restoredCount = 0
    for _, record in ipairs(archived) do
        if record.restored == true then restoredCount = restoredCount + 1 end
    end
    local unavailable = integration.unavailableAssignments
    local lines = {
        "AutoCategory archived assignment lines: " .. tostring(#archived)
            .. "; restored: " .. tostring(restoredCount),
        "Current active-profile mismatches ignored: " .. tostring(#unavailable),
    }
    if veryVerbose then
        for index, record in ipairs(archived) do
            lines[#lines + 1] = string.format("  archive #%d %s context=%s bag=%s index=%d restored=%s line=%s",
                index, record.dateTime, record.context, tostring(record.bagType), record.index,
                tostring(record.restored == true),
                FormatSavedValue(record.line))
        end
        for index, record in ipairs(unavailable) do
            lines[#lines + 1] = string.format("  ignored #%d context=%s bag=%s index=%d key=%s line=%s",
                index, record.context, tostring(record.bagType), record.index, record.ruleKey,
                FormatSavedValue(record.line))
        end
    end
    return lines
end

local function DescribeSavedAssignments(profile, ruleKey, assignmentName)
    if type(profile) ~= "table" or type(profile.bags) ~= "table" then return "unavailable" end
    local count, foundContexts = 0, {}
    for _, context in ipairs(contexts) do
        local bag = profile.bags[context.bagType()]
        if type(bag) == "table" and type(bag.rules) == "table" then
            for _, candidate in ipairs(bag.rules) do
                if type(candidate) == "table" and candidate.icOwned == true
                    and (candidate.icRuleKey == ruleKey
                        or candidate.icRuleKey == nil and candidate.name == assignmentName) then
                    count = count + 1
                    foundContexts[#foundContexts + 1] = context.key
                end
            end
        end
    end
    return tostring(count) .. (count > 0 and " in " .. table.concat(foundContexts, ",") or "")
end

local function CaptureMissingGroupDiagnostics(context, assignment, ruleKey, rules, definitions)
    if this.IsDevelopment ~= true then return end
    local ac = AutoCategory
    local runtime = this.GetRuntimeRuleDiagnostics(ruleKey)
    local accountAssignments = DescribeSavedAssignments(ac.acctSaved, ruleKey, assignment.name)
    local characterAssignments = DescribeSavedAssignments(ac.charSaved, ruleKey, assignment.name)
    local activeAssignments = DescribeSavedAssignments(ac.saved, ruleKey, assignment.name)
    local activeAutoCategoryProfile = "unidentified"
    if ac.saved == ac.acctSaved then
        activeAutoCategoryProfile = "account"
    elseif ac.saved == ac.charSaved then
        activeAutoCategoryProfile = "character"
    end
    local first = runtime.firstAccess
    local lines = {
        "Inventory Companion DEV AutoCategory diagnostic (read-only; no saved variables changed):",
        "Reconcile trigger: " .. tostring(currentReconcileReason or "direct projection"),
        "IC fully loaded: " .. tostring(this.state.isLoaded == true)
            .. "; selected list: " .. runtime.selectedProfile,
        "IC saved rule counts: account-wide=" .. tostring(runtime.accountSavedRuleCount)
            .. ", character-specific=" .. tostring(runtime.characterSavedRuleCount)
            .. "; target present: account-wide=" .. tostring(runtime.accountHasRule)
            .. ", character-specific=" .. tostring(runtime.characterHasRule),
        "IC built-in rules: " .. tostring(runtime.baselineRuleCount)
            .. "; target built-in=" .. tostring(runtime.baselineHasRule),
        "IC runtime cache: built=" .. tostring(runtime.cacheBuilt)
            .. ", invalid=" .. tostring(runtime.cacheInvalid)
            .. ", matches active saved rules=" .. tostring(runtime.cacheMatchesActiveRules)
            .. ", matches current baselines=" .. tostring(runtime.cacheMatchesBaselines)
            .. ", count=" .. tostring(runtime.runtimeRuleCount)
            .. ", target present=" .. tostring(runtime.runtimeHasRule),
        "BuildContextModel input: rules=" .. tostring(CountEntries(rules))
            .. ", definitions=" .. tostring(#definitions)
            .. ", target definition present=false",
        "AutoCategory initialized: " .. tostring(ac.Inited == true)
            .. "; active profile: " .. activeAutoCategoryProfile
            .. "; target assignments: active=" .. activeAssignments
            .. ", account=" .. accountAssignments .. ", character=" .. characterAssignments,
        "Failing assignment: context=" .. context.key .. ", name=" .. tostring(assignment.name)
            .. ", icRuleKey=" .. ruleKey .. ", runpriority=" .. tostring(assignment.runpriority)
            .. ", showpriority=" .. tostring(assignment.showpriority),
    }
    if first then
        lines[#lines + 1] = "First natural GetRuntimeRules call: caller=" .. tostring(first.caller)
            .. ", profile=" .. tostring(first.selectedProfile)
            .. ", cacheInvalid=" .. tostring(first.cacheInvalid)
            .. ", cacheBuilt=" .. tostring(first.cacheBuilt)
            .. ", baselines=" .. tostring(first.baselineRuleCount)
            .. ", savedRules=" .. tostring(first.savedRuleCount)
            .. ", cachePath=" .. tostring(first.cachePath)
            .. ", returnedRules=" .. tostring(first.returnedRuleCount)
    else
        lines[#lines + 1] = "First natural GetRuntimeRules call: not observed in DEV mode."
    end
    integration.failureDiagnostics = table.concat(lines, "\n")
end

local function SortAssignments(entries, mode)
    table.sort(entries, function(left, right)
        if mode == "display" then
            local leftKey = string.format("%04d%s", 1000 - left.assignment.showpriority, left.assignment.name)
            local rightKey = string.format("%04d%s", 1000 - right.assignment.showpriority, right.assignment.name)
            return leftKey < rightKey
        end
        local leftPriority, rightPriority = left.assignment.runpriority, right.assignment.runpriority
        if leftPriority ~= rightPriority then return leftPriority > rightPriority end
        return left.assignment.name < right.assignment.name
    end)
end

local function BuildContextModel(context, definitions, rules, repairAssignments)
    local ac = AutoCategory
    local bag = ac.saved.bags[context.bagType()]
    local definitionsByName, definitionsByKey = {}, {}
    for _, definition in ipairs(definitions) do
        definitionsByName[definition.name] = definition
        definitionsByKey[definition.icRuleKey] = definition
    end
    local entries, members, actualAssignments, nativeNames = {}, {}, {}, {}
    local templates = {}
    if bag.icAssignmentTemplates ~= nil then
        assert(type(bag.icAssignmentTemplates) == "table", "AutoCategory IC assignment templates must be a table")
        for key, template in pairs(bag.icAssignmentTemplates) do
            assert(type(key) == "string" and type(template) == "table"
                and template.icOwned == true and template.icRuleKey == key,
                "AutoCategory IC assignment template has an invalid ownership identity")
            assert(template.isHidden == nil or type(template.isHidden) == "boolean",
                "AutoCategory IC assignment template has an invalid hidden setting")
            templates[key] = CopySavedValue(template)
        end
    end
    local assignments = bag.rules
    local assignmentCount = 0
    for index in pairs(assignments) do
        assert(type(index) == "number" and index >= 1 and index % 1 == 0,
            "AutoCategory assignments must be a dense list in " .. context.title)
        assignmentCount = assignmentCount + 1
    end
    for index = 1, assignmentCount do
        assert(rawget(assignments, index) ~= nil, "AutoCategory assignments contain a hole in " .. context.title)
    end
    if repairAssignments then
        assignments = {}
        for _, assignment in ipairs(bag.rules) do
            if assignment.icOwned == true then
                local key = GetManagedRuleKey(assignment, definitionsByName)
                local template = CopySavedValue(assignment)
                template.icRuleKey = key
                templates[key] = template
            end
            if not repairAssignments[assignment] then assignments[#assignments + 1] = assignment end
        end
    end
    for _, assignment in ipairs(assignments) do
        assert(type(assignment) == "table" and type(assignment.name) == "string" and assignment.name ~= "",
            "AutoCategory assignment is malformed in " .. context.title)
        assert(assignment.isHidden == nil or type(assignment.isHidden) == "boolean",
            "AutoCategory hidden setting is invalid in " .. context.title .. ": " .. assignment.name)
        assert(type(assignment.runpriority) == "number" and assignment.runpriority == assignment.runpriority
            and math.abs(assignment.runpriority) < math.huge,
            "AutoCategory run priority is invalid in " .. context.title .. ": " .. assignment.name)
        assert(type(assignment.showpriority) == "number" and assignment.showpriority == assignment.showpriority
            and math.abs(assignment.showpriority) < math.huge,
            "AutoCategory display priority is invalid in " .. context.title .. ": " .. assignment.name)
        local ruleKey = GetManagedRuleKey(assignment, definitionsByName)
        local reference
        if ruleKey then
            reference = "ic:" .. ruleKey
            assert(actualAssignments[reference] == nil,
                "AutoCategory has duplicate managed assignments for " .. reference .. " in " .. context.title)
            actualAssignments[reference] = assignment
            local template = CopySavedValue(assignment)
            template.icRuleKey = ruleKey
            templates[ruleKey] = template
            local rule = rules[ruleKey]
            if rule and IsOrdinaryRule(ruleKey, rule) then
                members[reference] = { reference = reference, ruleKey = ruleKey, assignment = assignment }
            end
        else
            assert(nativeNames[assignment.name] == nil,
                "AutoCategory has duplicate native assignments named '" .. assignment.name .. "' in " .. context.title)
            nativeNames[assignment.name] = assignment
            reference = "ac:" .. assignment.name
            members[reference] = { reference = reference, name = assignment.name, assignment = assignment }
        end
        entries[#entries + 1] = {
            reference = reference,
            assignment = assignment,
        }
    end
    for ruleKey, rule in pairs(rules) do
        if IsOrdinaryRule(ruleKey, rule) then
            local reference = "ic:" .. ruleKey
            if members[reference] == nil then
                members[reference] = {
                    reference = reference,
                    ruleKey = ruleKey,
                    assignment = templates[ruleKey]
                        or { name = definitionsByKey[ruleKey].name, runpriority = 0, showpriority = 0 },
                }
            end
        end
    end
    for _, mode in ipairs({ "display", "matching" }) do
        local sorted = {}
        for _, entry in ipairs(entries) do
            if members[entry.reference] or mode == "display" and entry.reference == "ic:" .. otherRuleKey then
                sorted[#sorted + 1] = entry
            end
        end
        SortAssignments(sorted, mode)
        local sequence = {}
        for index, entry in ipairs(sorted) do sequence[index] = entry.reference end
        entries[mode] = sequence
    end
    return { entries = entries, members = members, definitions = definitionsByKey, templates = templates }
end

local function FilterToMembers(sequence, members)
    local result, seen = {}, {}
    for _, reference in ipairs(sequence) do
        if members[reference] and not seen[reference] then
            result[#result + 1] = reference
            seen[reference] = true
        end
    end
    return result, seen
end

local function MergeObservedReferences(saved, observed, members)
    local result, present = FilterToMembers(saved, members)
    for index, reference in ipairs(observed) do
        if members[reference] and not present[reference] then
            local insertion
            for nextIndex = index + 1, #observed do
                for resultIndex, existing in ipairs(result) do
                    if existing == observed[nextIndex] then insertion = resultIndex; break end
                end

                if insertion then break end
            end
            if insertion then
                table.insert(result, insertion, reference)
            else
                local previous
                for previousIndex = index - 1, 1, -1 do
                    for resultIndex, existing in ipairs(result) do
                        if existing == observed[previousIndex] then previous = resultIndex; break end
                    end
                    if previous then break end
                end
                table.insert(result, previous and previous + 1 or #result + 1, reference)
            end
            present[reference] = true
        end
    end
    local missing = {}
    for reference in pairs(members) do
        if not present[reference] then missing[#missing + 1] = reference end
    end
    table.sort(missing)
    for _, reference in ipairs(missing) do
        local insertion = #result + 1
        if reference ~= "ic:" .. otherRuleKey then
            for index, value in ipairs(result) do
                if value == "ic:" .. otherRuleKey then insertion = index; break end
            end
        end
        table.insert(result, insertion, reference)
    end
    return result
end

local function PreserveDormantNativeReferences(saved, active, members, previous)
    local result = CopySequence(active)
    local previouslyPresent = {}
    if previous then
        for _, reference in ipairs(previous) do previouslyPresent[reference] = true end
    end
    for index = #saved, 1, -1 do
        local reference = saved[index]
        if reference:sub(1, 3) == "ac:" and not members[reference] and not previouslyPresent[reference] then
            local insertion = #result + 1
            for nextIndex = index + 1, #saved do
                local found = false
                for position, existing in ipairs(result) do
                    if existing == saved[nextIndex] then insertion = position; found = true; break end
                end
                if found then break end
            end
            table.insert(result, insertion, reference)
        end
    end
    return result
end

local function SnapshotMatches(snapshot, observed, members)
    if snapshot == nil then return false end
    local observedSet = {}
    for _, reference in ipairs(observed) do observedSet[reference] = true end
    local expected = {}
    for _, reference in ipairs(snapshot) do
        if members[reference] and observedSet[reference] then expected[#expected + 1] = reference end
    end
    return SameSequence(expected, observed)
end

local function ValidateCompleteSequence(sequence, members, context, mode)
    assert(type(sequence) == "table", context .. " " .. mode .. " order must be a list")
    local seen = {}
    for index, reference in ipairs(sequence) do
        assert(type(reference) == "string" and members[reference],
            context .. " " .. mode .. " order has an unavailable reference at position " .. tostring(index))
        assert(not seen[reference], context .. " " .. mode .. " order repeats " .. reference)
        seen[reference] = true
    end
    local memberCount = 0
    for reference in pairs(members) do
        memberCount = memberCount + 1
        assert(seen[reference], context .. " " .. mode .. " order is missing " .. reference)
    end
    assert(#sequence == memberCount, context .. " " .. mode .. " order is not a complete permutation")
    assert(memberCount <= 999,
        context .. " has " .. tostring(memberCount) .. " assignments; AutoCategory supports at most 999 per order")
end

local assignmentStateFields = { "name", "icOwned", "icRuleKey", "runpriority", "showpriority" }

local function CaptureAssignmentState(ac)
    local snapshot = {}
    for _, context in ipairs(contexts) do
        local rules = ac.saved.bags[context.bagType()].rules
        local entries = {}
        for index, assignment in ipairs(rules) do
            local values = {}
            for _, field in ipairs(assignmentStateFields) do values[field] = assignment[field] end
            entries[index] = { assignment = assignment, values = values }
        end
        snapshot[context.key] = {
            rules = rules, entries = entries,
            templates = ac.saved.bags[context.bagType()].icAssignmentTemplates,
        }
    end
    return snapshot
end

local function RestoreAssignmentState(ac, snapshot)
    for _, context in ipairs(contexts) do
        local rules = ac.saved.bags[context.bagType()].rules
        local saved = snapshot[context.key]
        ac.saved.bags[context.bagType()].icAssignmentTemplates = saved.templates
        assert(rules == saved.rules, "AutoCategory replaced an assignment list during projection")
        for index = #rules, 1, -1 do rules[index] = nil end
        for index, entry in ipairs(saved.entries) do
            for _, field in ipairs(assignmentStateFields) do entry.assignment[field] = entry.values[field] end
            rules[index] = entry.assignment
        end
    end
end

local function GetCurrentOrderData()
    local profile = this.GetAutoCategoryProfile()
    local order = profile.autoCategoryOrder
    assert(type(order) == "table" and type(order.contexts) == "table",
        "Schema-5 AutoCategory context orders are unavailable")
    return profile, order
end

local function BuildStartingSequence(model, mode, rules, preset, hidden)
    local sequence, groups = {}, {}
    for _, reference in ipairs(model.entries[mode]) do
        if reference:sub(1, 3) == "ac:" then sequence[#sequence + 1] = reference end
    end
    for _, ruleKey in ipairs(GetOrderedRuleKeys(rules)) do
        if not hidden["ic:" .. ruleKey] then groups[#groups + 1] = "ic:" .. ruleKey end
    end
    local insertion = #sequence + 1
    if preset == "ic" then
        insertion = 1
        assert(SI_AC_DEFAULT_CATEGORY_NEW ~= nil, "AutoCategory's default New category string is unavailable")
        local newName = GetString(SI_AC_DEFAULT_CATEGORY_NEW)
        assert(type(newName) == "string" and newName ~= "",
            "AutoCategory's default New category name is unavailable")
        local newReference = "ac:" .. newName
        for index, reference in ipairs(sequence) do
            if reference == newReference and model.members[reference].assignment.isHidden ~= true then
                insertion = index + 1
                break
            end
        end
    end
    for index, reference in ipairs(groups) do table.insert(sequence, insertion + index - 1, reference) end
    return sequence
end

local function BuildPlans(orderOverride, setupRules, preset, repairAssignments)
    local ac = AutoCategory
    CheckExternalShape(ac)
    assert(ac.Inited == true, "AutoCategory must finish initialization before projection")
    CheckActiveAssignments(ac)
    assert(setupRules ~= nil or this.GetAutoCategoryState().enabled
        or repairAssignments ~= nil and this.GetAutoCategoryState().configuredEnabled,
        "Cannot project while AutoCategory integration is disabled")
    local rules = setupRules or GetRuntimeRules()
    if setupRules and not preset and not repairAssignments then
        local currentRules = GetRuntimeRules()
        repairAssignments = {}
        for _, context in ipairs(contexts) do
            for _, row in ipairs(ac.saved.bags[context.bagType()].rules) do
                if row.icOwned == true and currentRules[row.icRuleKey] and not rules[row.icRuleKey] then
                    repairAssignments[row] = true
                end
            end
        end
    end
    local definitions = BuildDefinitions(rules)
    integration.unavailableAssignments = FindUnavailableAssignments(ac, definitions, rules)
    local collisionFree, collision = CheckDefinitionCollision(ac, definitions)
    assert(collisionFree, collision)
    local profile, storedOrder = GetCurrentOrderData()
    local snapshotByContext = projectedOrders[ac.saved.bags]
    if snapshotByContext and snapshotByContext.profile ~= profile then snapshotByContext = nil end
    local plans, reconciled = {}, { contexts = {} }
    for _, context in ipairs(contexts) do
        local model = BuildContextModel(context, definitions, rules, repairAssignments)
        local savedContext = storedOrder.contexts[context.key]
        assert(type(savedContext) == "table", "Missing saved AutoCategory context: " .. context.key)
        local override = orderOverride and orderOverride[context.key]
        local priorSnapshot = snapshotByContext and snapshotByContext[context.key]
        local resolved = {
            hidden = CopySavedValue(override and override.hidden or savedContext.hidden),
            displayPositions = CopySavedValue(override and override.displayPositions or savedContext.displayPositions),
        }
        if preset and not repairAssignments then
            for key, rule in pairs(rules) do
                if IsOrdinaryRule(key, rule) then
                    resolved.hidden["ic:" .. key] = not rule.autoCategoryEnabled and true or nil
                end
            end
        end
        for _, mode in ipairs({ "display", "matching" }) do
            local members = {}
            for reference, entry in pairs(model.members) do members[reference] = entry end
            if mode == "display" then
                members["ic:" .. otherRuleKey] = {
                    ruleKey = otherRuleKey, assignment = model.templates[otherRuleKey] or {},
                }
            end
            local observed = model.entries[mode]
            local savedSequence = savedContext[mode]
            assert(type(savedSequence) == "table", "Missing saved AutoCategory " .. mode .. " order: " .. context.key)
            if mode == "display" then
                local savedOther = false
                for _, reference in ipairs(savedSequence) do
                    if reference == "ic:" .. otherRuleKey then savedOther = true; break end
                end
                if not savedOther then
                    observed = {}
                    for _, reference in ipairs(model.entries[mode]) do
                        if reference ~= "ic:" .. otherRuleKey then observed[#observed + 1] = reference end
                    end
                end
            end
            local sequence
            if preset then
                sequence = BuildStartingSequence(model, mode, rules, preset, resolved.hidden)
                sequence = MergeObservedReferences(sequence, {}, members)
            elseif override and override[mode] ~= nil then
                local seen = {}
                for _, reference in ipairs(override[mode]) do
                    assert(type(reference) == "string" and not seen[reference],
                        "AutoCategory order override contains an invalid or duplicate reference")
                    seen[reference] = true
                    local known = members[reference] ~= nil
                    for _, savedReference in ipairs(savedSequence) do
                        if reference == savedReference and reference:sub(1, 3) == "ac:" then known = true; break end
                    end
                    assert(known, "AutoCategory order override has an unavailable reference: " .. tostring(reference))
                end
                sequence = FilterToMembers(override[mode], members)
                for _, reference in ipairs(savedSequence) do
                    if resolved.hidden[reference] and members[reference] then
                        local present = false
                        for _, existing in ipairs(sequence) do
                            if reference == existing then present = true; break end
                        end
                        if not present then sequence[#sequence + 1] = reference end
                    end
                end
            elseif priorSnapshot and SnapshotMatches(priorSnapshot[mode], observed, model.members) then
                sequence = MergeObservedReferences(savedSequence, observed, members)
            else
                sequence = MergeObservedReferences(savedSequence, observed, members)
            end
            local included, hidden = {}, {}
            for _, reference in ipairs(sequence) do
                local destination = resolved.hidden[reference] and hidden or included
                destination[#destination + 1] = reference
            end
            for _, reference in ipairs(hidden) do included[#included + 1] = reference end
            ValidateCompleteSequence(included, members, context.title, mode)
            assert(#included <= (mode == "display" and 999 or 998),
                context.title .. " supports at most 998 assignments plus the IC Other helper")
            resolved[mode] = included
        end
        local planned = {}
        for _, mode in ipairs({ "display", "matching" }) do
            local field = mode == "display" and "showpriority" or "runpriority"
            for index, reference in ipairs(resolved[mode]) do
                local entry = model.members[reference]
                if reference == "ic:" .. otherRuleKey then
                    entry = { ruleKey = otherRuleKey, assignment = model.templates[otherRuleKey] or {} }
                end
                local target = planned[reference]
                if target == nil then
                    target = {
                        reference = reference, ruleKey = entry.ruleKey, name = entry.name,
                        assignment = entry.assignment, isManaged = reference:sub(1, 3) == "ic:",
                    }
                    if target.isManaged then target.name = model.definitions[entry.ruleKey].name end
                    planned[reference] = target
                end
                local hidden = resolved.hidden[reference] == true
                target[field] = 1001 - index - (mode == "matching" and hidden and 1 or 0)
            end
        end
        local includedCount = 0
        for _, reference in ipairs(resolved.matching) do
            if not resolved.hidden[reference] then includedCount = includedCount + 1 end
        end
        planned["ic:" .. otherRuleKey].runpriority = 1000 - includedCount
        plans[context.key] = {
            assignments = planned,
            orders = resolved,
            templates = model.templates,
            forceRefresh = forceRefreshContexts and forceRefreshContexts[context.key] == true,
        }
        reconciled.contexts[context.key] = {
            hidden = resolved.hidden, displayPositions = resolved.displayPositions,
        }
        for _, mode in ipairs({ "display", "matching" }) do
            reconciled.contexts[context.key][mode] = preset and resolved[mode]
                or PreserveDormantNativeReferences(savedContext[mode], resolved[mode], model.members,
                    priorSnapshot and priorSnapshot[mode])
        end
    end
    return plans, reconciled, profile
end

local function ProjectPlans(plans)
    local ac = AutoCategory
    local definitions = integration.TimePhase("BuildDefinitions", BuildDefinitions)
    integration.TimePhase("SyncDefinitions", SyncDefinitions, ac, definitions)
    local definitionsByName = {}
    for _, definition in ipairs(definitions) do definitionsByName[definition.name] = definition end
    local changed = {}
    for _, context in ipairs(contexts) do
        if plans[context.key].forceRefresh then changed[context.key] = true end
    end
    reconciling = true
    local ok, failure = xpcall(function()
        for _, context in ipairs(contexts) do
            local bag = ac.saved.bags[context.bagType()]
            local plan = plans[context.key]
            local managedByKey, wantedManaged = {}, {}
            for _, assignment in ipairs(bag.rules) do
                if assignment.icOwned == true then
                    local key = GetManagedRuleKey(assignment, definitionsByName)
                    managedByKey[key] = assignment
                end
            end
            for _, target in pairs(plan.assignments) do
                if target.isManaged then wantedManaged[target.ruleKey] = true end
            end
            for index = #bag.rules, 1, -1 do
                local assignment = bag.rules[index]
                if assignment.icOwned == true then
                    local key = GetManagedRuleKey(assignment, definitionsByName)
                    if not wantedManaged[key] then
                        table.remove(bag.rules, index)
                        changed[context.key] = true
                    end
                end
            end
            local nativeByName = {}
            for _, assignment in ipairs(bag.rules) do
                if assignment.icOwned ~= true then nativeByName[assignment.name] = assignment end
            end
            for _, target in pairs(plan.assignments) do
                local assignment
                if target.isManaged then
                    assignment = managedByKey[target.ruleKey]
                    if assignment == nil then
                        assignment = CopySavedValue(target.assignment)
                        assignment.name, assignment.icOwned, assignment.icRuleKey = target.name, true, target.ruleKey
                        bag.rules[#bag.rules + 1] = assignment
                        managedByKey[target.ruleKey] = assignment
                        changed[context.key] = true
                    end
                    if assignment.name ~= target.name then
                        assignment.name = target.name
                        changed[context.key] = true
                    end
                    if assignment.icRuleKey ~= target.ruleKey then
                        assignment.icRuleKey = target.ruleKey
                        changed[context.key] = true
                    end
                else
                    assignment = nativeByName[target.name]
                    assert(assignment ~= nil, "AutoCategory native assignment disappeared after preflight: " .. target.name)
                end
                if assignment.runpriority ~= target.runpriority then
                    assignment.runpriority = target.runpriority
                    changed[context.key] = true
                end
                if assignment.showpriority ~= target.showpriority then
                    assignment.showpriority = target.showpriority
                    changed[context.key] = true
                end
                bag.icAssignmentTemplates = plan.templates
            end
        end
        RefreshContexts(ac, changed, true)
    end, function(errorValue)
        reconciling = false
        return errorValue
    end)
    reconciling = false
    if not ok then error(failure) end
    local snapshots = { profile = this.GetAutoCategoryProfile() }
    for _, context in ipairs(contexts) do
        snapshots[context.key] = {
            display = CopySequence(plans[context.key].orders.display),
            matching = CopySequence(plans[context.key].orders.matching),
        }
    end
    projectedOrders[ac.saved.bags] = snapshots
    return changed
end

local function ReportProjectionFailure(failure)
    if status.state == "unsupported" then return false end
    integration.Fail(failure)
    return false
end

function integration.PreflightAutoCategory(orderOverride, candidateRules)
    if integration.IsFaulted() then return nil, this.autoCategoryFailure end
    local ok, plans, reconciled, profile, unavailableReason = pcall(
        integration.TimePhase, "BuildPlans", BuildPlans, orderOverride, candidateRules)
    if not ok then
        integration.Fail(plans)
        return nil, tostring(plans)
    end
    if plans == nil then return nil, unavailableReason end
    return { plans = plans, order = reconciled, profile = profile, bags = AutoCategory.saved.bags }
end

function integration.ProjectAutoCategory(preflight)
    if status.state == "unsupported" then return false, status.message end
    assert(not integration.NeedsRecovery(), "AutoCategory projection requires recovery before writing")
    local prepared = preflight
    if prepared == nil then
        local failure
        prepared, failure = integration.PreflightAutoCategory()
        if prepared == nil then return ReportProjectionFailure(failure) end
    end

    local ac = AutoCategory
    assert(prepared.profile == this.GetAutoCategoryProfile() and prepared.bags == ac.saved.bags,
        "Active profiles changed after AutoCategory preflight")
    local assignmentSnapshot = CaptureAssignmentState(ac)
    local ok, changed = xpcall(function()
        return integration.TimePhase("ProjectPlans", ProjectPlans, prepared.plans)
    end, function(failure)
        return debug.traceback(tostring(failure), 2)
    end)
    if not ok then
        local restored, restoreFailure = xpcall(function()
            RestoreAssignmentState(ac, assignmentSnapshot)
        end, function(failure)
            return debug.traceback(tostring(failure), 2)
        end)
        if not restored then
            error("AutoCategory projection failed and assignment rollback also failed: "
                .. tostring(changed) .. "\n" .. tostring(restoreFailure), 0)
        end
        error(changed, 0)
    end
    prepared.profile.autoCategoryOrder = prepared.order
    integration.unavailableAssignments = {}
    SetStatus("available", "AutoCategory display and matching orders are synchronized for the selected context.")
    return changed
end

function integration.SetEntryIncluded(reference, contextKey, included)
    assert(type(included) == "boolean" and type(reference) == "string", "Invalid AutoCategory inclusion change")
    assert(this.GetAutoCategoryState().enabled, "Cannot change inclusion while integration is disabled")
    assert(contextByKey[contextKey], "Inclusion requires an AutoCategory context")
    local profile = this.GetAutoCategoryProfile()
    local _, order = BuildPlans()
    local rules = GetRuntimeRules()
    local ruleKey = reference:sub(1, 3) == "ic:" and reference:sub(4) or nil
    if ruleKey then
        assert(IsOrdinaryRule(ruleKey, assert(rules[ruleKey], "Unknown IC inclusion group")),
            "Only ordinary IC groups can participate")
    else
        assert(reference:sub(1, 3) == "ac:" and contextByKey[contextKey], "Invalid native AC inclusion reference")
        local contextOrder = order.contexts[contextKey]
        local present = false
        for _, assignment in ipairs(AutoCategory.saved.bags[contextByKey[contextKey].bagType()].rules) do
            if assignment.icOwned ~= true and "ac:" .. assignment.name == reference then present = true; break end
        end
        assert(present, "Native AC inclusion references an unavailable category")
    end
    if (order.contexts[contextKey].hidden[reference] ~= true) == included then return true end
    local overrides = {}
    for _, context in ipairs(contexts) do
        if context.key == contextKey then
            local saved = order.contexts[context.key]
            local hidden, positions = CopySavedValue(saved.hidden), CopySavedValue(saved.displayPositions)
            local available = {}
            for _, row in ipairs(AutoCategory.saved.bags[context.bagType()].rules) do
                if row.icOwned ~= true then available["ac:" .. row.name] = true end
            end
            for key, rule in pairs(rules) do
                if IsOrdinaryRule(key, rule) then available["ic:" .. key] = true end
            end
            available["ic:" .. otherRuleKey] = true
            hidden[reference] = not included and true or nil
            local currentDisplay, displayIndex = nil, 0
            for _, value in ipairs(saved.display) do
                if available[value] and not saved.hidden[value] then
                    displayIndex = displayIndex + 1
                    if value == reference then currentDisplay = displayIndex; break end
                end
            end
            if not included and currentDisplay then positions[reference] = currentDisplay end
            local replacement = { hidden = hidden, displayPositions = positions }
            local restoredDisplay
            for _, mode in ipairs({ "display", "matching" }) do
                local sequence, excluded = {}, {}
                for _, value in ipairs(saved[mode]) do
                    if value ~= reference and available[value] then
                        local destination = hidden[value] and excluded or sequence
                        destination[#destination + 1] = value
                    end
                end
                if included then
                    local insertionReference = mode == "display" and positions[reference] or restoredDisplay
                    local insertion = insertionReference and math.min(insertionReference + 1, #sequence + 1) or #sequence + 1
                    table.insert(sequence, insertion, reference)
                    if mode == "display" then restoredDisplay = insertion end
                else
                    excluded[#excluded + 1] = reference
                end
                for _, value in ipairs(excluded) do sequence[#sequence + 1] = value end
                replacement[mode] = sequence
            end
            overrides[context.key] = replacement
        end
    end
    local plans, reconciled = BuildPlans(overrides)
    if integration.ProjectAutoCategory({
        plans = plans, order = reconciled, profile = profile, bags = AutoCategory.saved.bags,
    }) == false then return false end
    return true
end

function integration.IsEntryIncluded(reference, contextKey)
    assert(contextByKey[contextKey], "Unknown AutoCategory context")
    assert(reference:sub(1, 3) == "ic:" and reference ~= "ic:" .. otherRuleKey
        and IsOrdinaryRule(reference:sub(4), assert(GetRuntimeRules()[reference:sub(4)], "Unknown IC group")),
        "Area selection requires an ordinary IC group")
    local _, order = GetCurrentOrderData()
    return order.contexts[contextKey].hidden[reference] ~= true
end

function integration.GetAreaSummary(reference, fits)
    local enabled, disabled = {}, {}
    for _, context in ipairs(contexts) do
        local names = integration.IsEntryIncluded(reference, context.key) and enabled or disabled
        names[#names + 1] = context.title
    end
    if #enabled == 7 then return "All" end
    if #enabled == 0 then return "None" end
    if #enabled == 1 then return enabled[1] end
    if #disabled == 1 then return "Not: " .. disabled[1] end
    local text = table.concat(enabled, ", ")
    if fits(text) then return text end
    text = "Not: " .. table.concat(disabled, ", ")
    if fits(text) then return text end
    return ({ [2] = "Two Areas", [3] = "Three Areas", [4] = "Four Areas", [5] = "Five Areas" })[#enabled]
end

function integration.RetrySynchronization()
    assert(integration.NeedsRecovery(), "AutoCategory retry requires a failure state")
    pendingGeneration = pendingGeneration + 1
    this.autoCategoryFailure = nil
    this.autoCategoryFailureTraceback = nil
    integration.failureDiagnostics = nil
    integration.lastFailureReport = nil
    status = { state = "pending", message = "Retrying AutoCategory synchronization." }
    local recovered = integration.Run(function()
        this.ValidateAutoCategoryRecoveryData()
        CheckExternalShape(AutoCategory)
        assert(AutoCategory.Inited == true, "AutoCategory is not initialized; finish loading or /reloadui before retrying")
        assert(AutoCategory.Plugins[pluginName] ~= nil,
            "AutoCategory plugin registration did not finish; /reloadui is required")
        if this.GetAutoCategoryState().configuredEnabled then
            local prepared = integration.PreflightAutoCategory()
            if prepared == nil then return false end
            for _, plan in pairs(prepared.plans) do plan.forceRefresh = true end
            integration.ProjectAutoCategory(prepared)
            return not integration.NeedsRecovery() and status.state == "available"
        end
        SetStatus("disabled", "AutoCategory integration is disabled. Saved choices are preserved.")
        return true
    end)
    this.RefreshAutoCategoryUI()
    d("[InventoryCompanion] " .. (recovered == true
        and "AutoCategory recovery succeeded."
        or "AutoCategory still needs attention. Open the IC AutoCategory panel for details."))
    return recovered == true
end


function integration.CanRepairAssignments()
    return integration.NeedsRecovery() and #integration.unavailableAssignments > 0
end

local function PrepareAssignmentRepair()
    assert(integration.CanRepairAssignments(), "No specific assignment repair is available for this failure")
    this.ValidateAutoCategoryRecoveryData()
    local ac = AutoCategory
    CheckExternalShape(ac)
    CheckActiveAssignments(ac)
    local rules = GetRuntimeRules()
    assert(next(this.preLoadedRulesets) ~= nil, "Cannot repair assignments without loaded baseline groups")
    for ruleKey in pairs(this.preLoadedRulesets) do
        assert(rules[ruleKey] ~= nil, "Cannot repair assignments with an incomplete IC runtime: " .. ruleKey)
    end
    for ruleKey in pairs(this.GetAutoCategoryProfile().trackedRules) do
        assert(rules[ruleKey] ~= nil, "Cannot repair assignments with an incomplete IC runtime: " .. ruleKey)
    end
    local unavailable = FindUnavailableAssignments(ac, BuildDefinitions(rules), rules)
    assert(#unavailable > 0, "Assignments changed; retry synchronization before attempting repair")
    local skipped = {}
    for _, record in ipairs(unavailable) do
        skipped[ac.saved.bags[record.bagType].rules[record.index]] = true
    end
    local plans, order, profile = BuildPlans(nil, nil, nil, skipped)
    assert(plans ~= nil, "Assignment repair could not produce a valid synchronization plan")
    return { plans = plans, order = order, profile = profile, bags = ac.saved.bags }, unavailable
end

function integration.RepairAffectedAssignments(expectedProfile, expectedSaved, expectedRows)
    assert(integration.NeedsRecovery(), "Assignment repair requires a failure state")
    local ok, prepared, removed = pcall(PrepareAssignmentRepair)
    if not ok then
        d("[InventoryCompanion] Assignment repair was not applied: " .. tostring(prepared))
        return false
    end
    assert(prepared.profile == expectedProfile and AutoCategory.saved == expectedSaved,
        "Active profiles changed while the repair confirmation was open; no repair was applied")
    assert(#removed == #expectedRows, "Repair candidates changed; reopen the repair confirmation")
    for index, record in ipairs(removed) do
        local expected = expectedRows[index]
        assert(record.context == expected.context and record.index == expected.index
            and FormatSavedValue(record.line) == FormatSavedValue(expected.line),
            "Repair candidates changed; reopen the repair confirmation")
    end
    -- Session-only copies avoid changing the saved schema or feeding the legacy restore archive.
    integration.lastRepairBackup = { saved = expectedSaved, profile = expectedProfile, rows = removed }
    local assignmentSnapshot = CaptureAssignmentState(AutoCategory)
    local originalOrder = expectedProfile.autoCategoryOrder
    this.autoCategoryFailure = nil
    this.autoCategoryFailureTraceback = nil
    integration.failureDiagnostics = nil
    status = { state = "pending", message = "Repairing AutoCategory assignments." }
    for _, plan in pairs(prepared.plans) do plan.forceRefresh = true end
    integration.ProjectAutoCategory(prepared)
    local recovered = not integration.NeedsRecovery() and status.state == "available"
    if recovered then
        integration.unavailableAssignments = {}
    else
        RestoreAssignmentState(AutoCategory, assignmentSnapshot)
        expectedProfile.autoCategoryOrder = originalOrder
    end
    this.RefreshAutoCategoryUI()
    d("[InventoryCompanion] " .. (recovered
        and ("Removed " .. #removed .. " affected IC-owned assignment(s) from the active AC profile and synchronized."
            .. " Recovery copies are available for this session.")
        or "Assignment repair did not recover integration; assignment changes were rolled back. See recovery details."))
    return recovered
end

local repairDialogRegistered = false
function integration.ShowAssignmentRepair()
    local ok, prepared, removed = pcall(PrepareAssignmentRepair)
    if not ok then
        d("[InventoryCompanion] Assignment repair is unavailable: " .. tostring(prepared))
        return false
    end
    if not repairDialogRegistered then
        ZO_Dialogs_RegisterCustomDialog("InventoryCompanion_AUTOCATEGORY_REPAIR", {
            gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
            title = { text = "Repair AutoCategory Assignments" },
            mainText = { text = function(dialog) return dialog.data.summary end },
            buttons = {
                { text = SI_DIALOG_CONFIRM, callback = function(dialog)
                    local data = dialog.data
                    integration.RepairAffectedAssignments(data.profile, data.saved, data.rows)
                end },
                { text = SI_DIALOG_CANCEL },
            },
        })
        repairDialogRegistered = true
    end
    local summary = { "Remove " .. #removed
        .. " affected IC-owned assignment(s) from the active AutoCategory profile, then synchronize:", "" }
    local shown = #removed <= 5 and #removed or 3
    for index = 1, shown do
        local record = removed[index]
        summary[#summary + 1] = contextByKey[record.context].title .. ": " .. record.line.name:gsub("|", "||")
    end
    if #removed > shown then
        summary[#summary + 1] = "... and " .. (#removed - shown) .. " more."
        summary[#summary + 1] = "To see everything that will change, cancel and review the scrollable details in the recovery panel."
    end
    summary[#summary + 1] = "\nIC groups, saved IC order, native AC categories and inactive profiles are preserved."
        .. " Copies of removed rows are retained for this session only; back up saved variables before repair."
    ZO_Dialogs_ShowDialog("InventoryCompanion_AUTOCATEGORY_REPAIR", {
        profile = prepared.profile, saved = AutoCategory.saved, rows = removed, summary = table.concat(summary, "\n"),
    })
    return true
end

local function PrepareIntegrationReset()
    local ac = AutoCategory
    CheckExternalShape(ac)
    assert(ac.Inited == true and ac.Plugins[pluginName] ~= nil,
        "AutoCategory must finish loading the IC plugin before integration can be reset")
    CheckActiveAssignments(ac)
    local rows = {}
    for _, context in ipairs(contexts) do
        local assignments = ac.saved.bags[context.bagType()].rules
        local count = 0
        for index in pairs(assignments) do
            assert(type(index) == "number" and index >= 1 and index % 1 == 0,
                "A malformed AC assignment list prevents a safe integration-only reset")
            count = count + 1
        end
        for index = 1, count do
            local row = assignments[index]
            assert(type(row) == "table", "An unidentified malformed AC row prevents a safe integration-only reset")
            if row.icOwned == true then
                rows[#rows + 1] = {
                    context = context.key, index = index, line = CopySavedValue(row),
                }
            end
        end
    end
    return { profile = this.GetAutoCategoryProfile(), saved = ac.saved, rows = rows }
end

function integration.ResetIntegration(expected, preset)
    assert(preset == "ic" or preset == "ac", "Reset requires a chosen starting arrangement")
    local current = PrepareIntegrationReset()
    assert(current.profile == expected.profile and current.saved == expected.saved,
        "Active profiles changed while reset confirmation was open; no reset was applied")
    assert(FormatSavedValue(current.rows) == FormatSavedValue(expected.rows),
        "IC-owned AC assignments changed; reopen the reset confirmation")
    local ac, profile = AutoCategory, current.profile
    local fields = {
        "autoCategorySetupComplete", "autoCategoryOrder", "autoCategoryInitialized",
    }
    local prior = {}
    local priorEnabled = this.accountWide.autoCategoryIntegrationEnabled
    for _, field in ipairs(fields) do prior[field] = profile[field] end
    local snapshot = CaptureAssignmentState(ac)
    integration.lastResetBackup = { saved = current.saved, profile = profile, rows = current.rows, fields = prior }
    local previousResetProfile = resetProfile
    pendingGeneration = pendingGeneration + 1
    local ok, failure = xpcall(function()
        local order = { contexts = {} }
        assert(type(prior.autoCategoryOrder) == "table" and type(prior.autoCategoryOrder.contexts) == "table",
            "Reset cannot preserve inclusion: saved context data is malformed")
        for _, context in ipairs(contexts) do
            order.contexts[context.key] = { display = {}, matching = {}, hidden = {}, displayPositions = {} }
            local previous = prior.autoCategoryOrder.contexts[context.key]
            assert(type(previous) == "table" and type(previous.hidden) == "table",
                "Reset cannot preserve inclusion: saved exclusions are malformed in " .. context.title)
            for reference, hidden in pairs(previous.hidden) do
                assert(type(reference) == "string" and type(hidden) == "boolean",
                    "Reset cannot preserve malformed inclusion data in " .. context.title)
                if reference:sub(1, 3) == "ic:" then order.contexts[context.key].hidden[reference] = hidden end
            end
        end
        profile.autoCategoryInitialized = nil
        profile.autoCategoryOrder = order
        this.ValidateAutoCategoryRecoveryData()
        this.autoCategoryFailure = nil
        this.autoCategoryFailureTraceback = nil
        integration.failureDiagnostics = nil
        integration.lastFailureReport = nil
        integration.unavailableAssignments = {}
        status = { state = "pending", message = "Rebuilding AutoCategory integration." }
        local removals = {}
        for _, context in ipairs(contexts) do
            for _, row in ipairs(ac.saved.bags[context.bagType()].rules) do
                if row.icOwned == true then removals[row] = true end
            end
        end
        local plans, rebuilt = BuildPlans(nil, GetRuntimeRules(), preset, removals)
        ProjectPlans(plans)
        profile.autoCategoryOrder = rebuilt
        profile.autoCategorySetupComplete = true
        this.accountWide.autoCategoryIntegrationEnabled = true
        resetProfile = nil
        SetStatus("available", "AutoCategory integration was reset using the chosen starting arrangement.")
    end, AppendTraceback)
    reconciling = false
    if not ok then
        RestoreAssignmentState(ac, snapshot)
        for _, field in ipairs(fields) do profile[field] = prior[field] end
        this.accountWide.autoCategoryIntegrationEnabled = priorEnabled
        resetProfile = previousResetProfile
        this.autoCategoryFailure = nil
        integration.Fail("Integration reset failed; saved changes were rolled back: " .. tostring(failure))
        return false
    end
    d("[InventoryCompanion] Reset complete: the previous arrangement and native AC exclusions were replaced."
        .. " IC groups, item assignments, per-area IC inclusion, native AC categories and inactive profiles were preserved.")
    this.RefreshAutoCategoryUI()
    return true
end

local resetDialogRegistered = false
function integration.ShowIntegrationReset()
    local ok, prepared = pcall(PrepareIntegrationReset)
    if not ok then
        d("[InventoryCompanion] Integration reset is unavailable: " .. tostring(prepared))
        return false
    end
    if not resetDialogRegistered then
        ZO_Dialogs_RegisterCustomDialog("InventoryCompanion_AUTOCATEGORY_RESET", {
            gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
            title = { text = "Reset AutoCategory Integration" },
            mainText = { text = function(dialog) return dialog.data.summary end },
            buttons = {
                { text = SI_DIALOG_CONFIRM, callback = function(dialog) integration.ShowInitialSetup(dialog.data) end },
                { text = SI_DIALOG_CANCEL },
            },
        })
        resetDialogRegistered = true
    end
    local icScope = prepared.profile == this.accountWide and "account-wide" or "current character"
    local acScope = "active"
    if prepared.saved.bags == AutoCategory.acctSaved.bags then
        acScope = "account-wide"
    elseif prepared.saved.bags == AutoCategory.charSaved.bags then
        acScope = "current character"
    end
    prepared.summary = "Reset the " .. icScope .. " IC integration arrangement in the " .. acScope
        .. " AC profile (all seven inventory contexts)."
        .. "\n\nThe previous arrangement and native AC exclusions will be replaced."
        .. " Next, choose IC categories near the top or at the bottom. Cancelling leaves the existing configuration unchanged."
        .. "\n\nIC groups, per-area IC inclusion, matching rules, tracked items, native AC categories and inactive profiles"
        .. " are preserved. Removed rows and cleared settings are copied for this session only."
        .. "\n\nCustom integration ordering WILL BE LOST. Back up saved variables before continuing."
    ZO_Dialogs_ShowDialog("InventoryCompanion_AUTOCATEGORY_RESET", prepared)
    return true
end

local testAssignmentKey = "_ic_dev_recovery_test_missing_group"
local testAssignmentName = "IC DEV recovery test (missing group)"
local testScenarios = {}
for scenario = 1, 4 do
    local records = {}
    local count = ({ 3, 7, 30, 5 })[scenario]
    for index = 1, count do
        local group = scenario == 2 and 1 or index
        records[index] = {
            context = scenario == 2 and contexts[index] or contextByKey.backpack,
            key = testAssignmentKey .. "_scenario" .. scenario .. "_group" .. group,
            name = string.format("IC DEV recovery test %d - Group %02d", scenario, group),
        }
    end
    testScenarios[scenario] = records
end

local function IsTestAssignment(row)
    if row.icOwned ~= true then return false end
    if row.icRuleKey == testAssignmentKey and row.name == testAssignmentName then return true end
    for _, records in ipairs(testScenarios) do
        for _, record in ipairs(records) do
            if row.icRuleKey == record.key and row.name == record.name then return true end
        end
    end
    return false
end

local function RemoveTestRows()
    local removed = 0
    for _, context in ipairs(contexts) do
        local rows = AutoCategory.saved.bags[context.bagType()].rules
        for index = #rows, 1, -1 do
            if IsTestAssignment(rows[index]) then
                table.remove(rows, index)
                removed = removed + 1
            end
        end
    end
    return removed
end

local function GetTestAssignmentList()
    assert(this.IsDevelopment == true, "AutoCategory saved-data testing is DEV-only")
    CheckExternalShape(AutoCategory)
    assert(AutoCategory.Inited == true, "AutoCategory must finish loading before saved-data testing")
    CheckActiveAssignments(AutoCategory)
    return AutoCategory.saved.bags[contextByKey.backpack.bagType()].rules
end

function integration.InjectTestAssignment(scenario)
    GetTestAssignmentList()
    assert(scenario == nil or testScenarios[scenario] ~= nil, "Unknown AutoCategory injection scenario")
    local records = scenario and testScenarios[scenario] or {
        { context = contextByKey.backpack, key = testAssignmentKey, name = testAssignmentName },
    }
    local rules = GetRuntimeRules()
    for _, record in ipairs(records) do
        assert(rules[record.key] == nil, "The reserved test group key already exists in IC: " .. record.key)
        assert(AutoCategory.GetRuleByName(record.name) == nil,
            "The reserved test category name already exists: " .. record.name)
    end
    local removed = RemoveTestRows()
    if removed > 0 then
        d("[InventoryCompanion] Removed " .. removed .. " prior DEV scenario row(s) from the active AC profile.")
        if integration.NeedsRecovery() then integration.RetrySynchronization() end
    end
    assert(integration.IsEditorActive(), "Start with a working enabled integration before injecting test data")
    for _, record in ipairs(records) do
        local assignments = AutoCategory.saved.bags[record.context.bagType()].rules
        assignments[#assignments + 1] = {
            name = record.name, icOwned = true, icRuleKey = record.key,
            runpriority = "IC DEV invalid priority", showpriority = 1, isHidden = false,
        }
    end
    d("[InventoryCompanion] Inserted " .. #records .. " malformed-priority IC-owned assignment(s) for "
        .. (scenario and ("scenario " .. scenario) or "the original single-row test") .. " into the active AC profile."
        .. " Use Repair affected assignments in the IC AutoCategory panel, or /icactest remove in this same AC profile.")
    integration.ProjectAutoCategory()
end

function integration.RemoveTestAssignment()
    GetTestAssignmentList()
    local removed = RemoveTestRows()
    d("[InventoryCompanion] Removed " .. removed .. " DEV test assignment(s) from the active AC profile.")
    if integration.NeedsRecovery() then integration.RetrySynchronization() end
    return removed
end

function integration.VerifyTestAssignment()
    GetTestAssignmentList()
    local profile = this.GetAutoCategoryProfile()
    local acScope = "unidentified active profile"
    if AutoCategory.saved.bags == AutoCategory.acctSaved.bags then
        acScope = "account-wide"
    elseif AutoCategory.saved.bags == AutoCategory.charSaved.bags then
        acScope = "current character"
    end
    local counts = { test = 0, managed = 0, native = 0, unavailable = 0 }
    local lines = {
        "[InventoryCompanion] AutoCategory saved-data verification (read-only)",
        "IC profile: " .. (profile == this.accountWide and "account-wide" or "current character"),
        "AC profile: " .. acScope,
        "Integration status: " .. status.state,
        "Saved enablement: " .. tostring(this.accountWide.autoCategoryIntegrationEnabled == true),
        "Setup complete: " .. tostring(profile.autoCategorySetupComplete == true),
        "The reserved injected test row is checked separately from real IC-owned assignments.",
        "",
    }
    for _, context in ipairs(contexts) do
        local contextCounts = { test = 0, managed = 0, native = 0, unavailable = 0 }
        local details = {}
        for _, row in pairs(AutoCategory.saved.bags[context.bagType()].rules) do
            assert(type(row) == "table", "Cannot verify a malformed AC assignment list")
            if IsTestAssignment(row) then
                contextCounts.test = contextCounts.test + 1
            end
            if row.icOwned == true then
                contextCounts.managed = contextCounts.managed + 1
                local key = row.icRuleKey
                local reason
                if type(key) ~= "string" or key == "" then
                    reason = "missing or invalid IC group key"
                elseif key ~= otherRuleKey and this.preLoadedRulesets[key] == nil and profile.trackedRules[key] == nil then
                    reason = "group missing from selected IC profile"
                end
                if reason then
                    contextCounts.unavailable = contextCounts.unavailable + 1
                    details[#details + 1] = "  Unavailable: " .. tostring(row.name)
                        .. " [key=" .. tostring(key) .. "]: " .. reason
                end
            else
                contextCounts.native = contextCounts.native + 1
            end
        end
        lines[#lines + 1] = context.title .. ": test=" .. contextCounts.test
            .. ", IC-owned=" .. contextCounts.managed .. ", native=" .. contextCounts.native
            .. ", unavailable=" .. contextCounts.unavailable
        for _, detail in ipairs(details) do lines[#lines + 1] = detail end
        for key, value in pairs(contextCounts) do counts[key] = counts[key] + value end
    end
    local result
    if counts.test > 0 then result = "test item still present"
    elseif counts.managed > 0 then result = "item gone"
    else result = "everything gone - its lonely in here" end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Reserved test row result: " .. result
    lines[#lines + 1] = "Real assignment check: " .. counts.unavailable .. " unavailable IC-owned assignment(s)."
    lines[#lines + 1] = "'item gone' means only that the reserved test row is absent; it does not prove a real repair succeeded."
    lines[#lines + 1] = "Totals: test=" .. counts.test .. ", IC-owned=" .. counts.managed
        .. ", native=" .. counts.native .. ", unavailable=" .. counts.unavailable
    lines[#lines + 1] = "Read-only check of loaded AC saved tables across all seven supported contexts."
        .. " Native categories are not reset; inactive profiles and files on disk were not checked."
        .. " Run again after /reloadui to verify the persisted result."
    local report = table.concat(lines, "\n")
    integration.lastVerificationReport = report
    d("[InventoryCompanion] " .. result .. " (test=" .. counts.test .. ", IC-owned=" .. counts.managed
        .. ", native=" .. counts.native .. ", unavailable=" .. counts.unavailable .. ").")
    d("[InventoryCompanion] 'item gone' checks the reserved test row only. Full report opens in the error window.")
    return counts, report
end

function integration.ShowTestVerification()
    local _, report = integration.VerifyTestAssignment()
    -- This deliberate report is not an integration failure and must bypass Run.
    error(report, 0)
end

function integration.CompleteInitialSetup(preset, profile)
    assert(preset == "ic" or preset == "ac", "Unknown AutoCategory starting preset")
    assert(profile == this.GetAutoCategoryProfile(), "AutoCategory setup profile changed while the dialog was open")
    assert(profile.autoCategorySetupComplete ~= true, "AutoCategory initial setup is already complete")
    assert(integration.IsAvailable(), "AutoCategory integration is unavailable")
    local rules, participation = {}, {}
    for ruleKey, rule in pairs(GetRuntimeRules()) do
        local copy = {}
        for key, value in pairs(rule) do copy[key] = value end
        rules[ruleKey] = copy
        if IsOrdinaryRule(ruleKey, rule) then
            local display = this.ResolveItemDisplay(rule.display)
            copy.autoCategoryEnabled = rule.autoCategoryEnabled or display.show or display.notify
            if copy.autoCategoryEnabled then participation[#participation + 1] = ruleKey end
        end
    end
    -- Check every context before publishing participation, enablement, or orders.
    local plans, order = BuildPlans(nil, rules, preset)
    if plans == nil then return false end
    integration.ProjectAutoCategory({ plans = plans, order = order, profile = profile, bags = AutoCategory.saved.bags })
    if integration.IsFaulted() then return false end
    for _, ruleKey in ipairs(participation) do
        local saved = profile.trackedRules[ruleKey]
        if saved == nil then saved = {}; profile.trackedRules[ruleKey] = saved end
        saved.autoCategoryEnabled = true
    end
    this.InvalidateRuleCache()
    this.accountWide.autoCategoryIntegrationEnabled = true
    profile.autoCategorySetupComplete = true
    integration.OnEnablementChanged(true)
    this.RefreshAutoCategoryUI()
    return true
end

local setupDialogRegistered = false
function integration.ShowInitialSetup(resetExpected)
    assert(resetExpected ~= nil or integration.IsAvailable(), "AutoCategory integration is unavailable")
    if not setupDialogRegistered then
        local function Choose(dialog, preset)
            if dialog.data.profile ~= this.GetAutoCategoryProfile() then
                d("[InventoryCompanion] AutoCategory setup cancelled because the selected item-list profile changed.")
                this.RefreshAutoCategoryUI()
                return
            end
            if dialog.data.resetExpected then
                integration.ResetIntegration(dialog.data.resetExpected, preset)
            else
                integration.CompleteInitialSetup(preset, dialog.data.profile)
            end
        end
        ZO_Dialogs_RegisterCustomDialog("InventoryCompanion_AUTOCATEGORY_SETUP", {
            gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
            title = { text = "Set Up AutoCategory Integration" },
            mainText = { text = "Enable AutoCategory integration to manage category order in Inventory Companion "
                .. "and use your IC groups in your backpack, bank and other inventories.\n\n"
                .. "Where should IC groups appear among your existing AutoCategory categories? "
                .. "You can change this later in the group editor." },
            radioButtons = {
                { text = "Near the top (default)", data = "ic" },
                { text = "At the bottom", data = "ac" },
            },
            buttons = {
                { text = SI_DIALOG_CONFIRM, callback = function(dialog)
                    local selected = dialog.radioButtonGroup:GetClickedButton()
                    assert(selected ~= nil, "AutoCategory setup dialog has no selected arrangement")
                    Choose(dialog, selected.data)
                end },
                { text = SI_DIALOG_CANCEL, callback = function() this.RefreshAutoCategoryUI() end },
            },
            noChoiceCallback = function() this.RefreshAutoCategoryUI() end,
        })
        setupDialogRegistered = true
    end
    ZO_Dialogs_ShowDialog("InventoryCompanion_AUTOCATEGORY_SETUP", {
        profile = this.GetAutoCategoryProfile(), resetExpected = resetExpected,
    })
    return false
end

function integration.ResolveAutoCategoryOrder(contextKey, options)
    assert(contextByKey[contextKey], "Unknown AutoCategory context: " .. tostring(contextKey))
    local mode = options and options.mode or "display"
    assert(mode == "display" or mode == "matching", "Unknown AutoCategory ordering mode: " .. tostring(mode))
    local _, order = GetCurrentOrderData()
    local nativeNames = {}
    for _, assignment in ipairs(AutoCategory.saved.bags[contextByKey[contextKey].bagType()].rules) do
        if assignment.icOwned ~= true then nativeNames["ac:" .. assignment.name] = true end
    end
    local function ActiveSequence(modeName)
        local active = {}
        for _, reference in ipairs(order.contexts[contextKey][modeName]) do
            if reference:sub(1, 3) == "ic:" or nativeNames[reference] then active[#active + 1] = reference end
        end
        return active
    end
    local sequence = ActiveSequence(mode)
    local rules = GetRuntimeRules()
    -- The two mode lists only share membership after reconciliation, so the other list may lack a reference.
    local positions = { display = {}, matching = {} }
    for _, modeName in ipairs({ "display", "matching" }) do
        for index, reference in ipairs(ActiveSequence(modeName)) do
            positions[modeName][reference] = index
        end
    end
    local rows, excluded = {}, {}
    for index, reference in ipairs(sequence) do
        local hidden = order.contexts[contextKey].hidden[reference] == true
        local destination = hidden and excluded or rows
        if reference == "ic:" .. otherRuleKey then
            assert(mode == "display" and not hidden, "Other must be included in Display only")
            rows[#rows + 1] = {
                kind = "other", reference = reference, name = "Other", included = true, index = #rows + 1,
                displayPosition = positions.display[reference],
            }
        elseif reference:sub(1, 3) == "ic:" then
            local ruleKey = reference:sub(4)
            local rule = rules[ruleKey]
            assert(rule and IsOrdinaryRule(ruleKey, rule),
                "Saved AutoCategory order references an unknown IC group: " .. ruleKey)
            destination[#destination + 1] = {
                kind = "group", reference = reference, ruleKey = ruleKey,
                name = rule.displayName, participating = not hidden, included = not hidden, index = #rows + 1,
                displayPosition = positions.display[reference], matchingPosition = positions.matching[reference],
            }
        else
            destination[#destination + 1] = {
                kind = "heading", reference = reference, name = reference:sub(4),
                index = #rows + 1, hidden = hidden, included = not hidden,
                scopeLabel = contextByKey[contextKey].title,
                displayPosition = positions.display[reference], matchingPosition = positions.matching[reference],
            }
        end
    end
    local includedCount = #rows
    if #excluded > 0 then
        rows[#rows + 1] = { kind = "divider", reference = "__excluded", name = "Excluded", included = false }
        for _, entry in ipairs(excluded) do rows[#rows + 1] = entry end
    end
    for _, row in ipairs(rows) do row.orderCount = includedCount end
    return rows
end

function integration.GetIncludedSequence(contextKey, mode)
    local sequence = {}
    for _, row in ipairs(integration.ResolveAutoCategoryOrder(contextKey, { mode = mode })) do
        if row.included then sequence[#sequence + 1] = row.reference end
    end
    return sequence
end

local function ApplyOrderOverride(orderOverride)
    local prepared, failure = integration.PreflightAutoCategory(orderOverride)
    if prepared == nil then return ReportProjectionFailure(failure) end
    return integration.ProjectAutoCategory(prepared) ~= false
end

function integration.GetMovedSequence(sequence, selection, movement)
    assert(movement == "top" or movement == "bottom"
        or movement == -1 or movement == 1 or movement == -5 or movement == 5
        or movement == -10 or movement == 10, "Unknown AutoCategory movement")
    local present = {}
    for _, reference in ipairs(sequence) do present[reference] = true end
    for reference, selected in pairs(selection) do
        assert(selected == true and present[reference],
            "AutoCategory selection references a missing assignment: " .. tostring(reference))
    end
    local result
    if movement == "top" or movement == "bottom" then
        result = {}
        for _, selected in ipairs({ movement == "top", movement ~= "top" }) do
            for _, reference in ipairs(sequence) do
                if (selection[reference] == true) == selected then result[#result + 1] = reference end
            end
        end
    else
        result = CopySequence(sequence)
        local first, last, step = 2, #result, 1
        if movement > 0 then first, last, step = #result - 1, 1, -1 end
        for _ = 1, math.abs(movement) do
            for index = first, last, step do
                local neighbour = index - step
                if selection[result[index]] and not selection[result[neighbour]] then
                    result[index], result[neighbour] = result[neighbour], result[index]
                end
            end
        end
    end
    for index, reference in ipairs(result) do
        if reference ~= sequence[index] then return result, true end
    end
    return result, false
end

function integration.MoveEntries(selection, contextKey, mode, movement)
    assert(contextByKey[contextKey], "Unknown AutoCategory context: " .. tostring(contextKey))
    assert(mode == "display" or mode == "matching", "Unknown AutoCategory ordering mode: " .. tostring(mode))
    local sequence, changed = integration.GetMovedSequence(integration.GetIncludedSequence(contextKey, mode), selection, movement)
    if not changed then return false end
    return ApplyOrderOverride({ [contextKey] = { [mode] = sequence } })
end

function integration.MoveEntry(reference, contextKey, mode, direction)
    assert(direction == -1 or direction == 1, "AutoCategory move direction must be -1 or 1")
    return integration.MoveEntries({ [reference] = true }, contextKey, mode, direction)
end

function integration.UseOtherOrder(contextKey, activeMode)
    assert(contextByKey[contextKey], "Unknown AutoCategory context: " .. tostring(contextKey))
    assert(activeMode == "display" or activeMode == "matching", "Unknown AutoCategory ordering mode")
    local _, order = GetCurrentOrderData()
    local sourceMode = activeMode == "display" and "matching" or "display"
    local sequence, otherPosition = {}, nil
    for index, reference in ipairs(order.contexts[contextKey].display) do
        if reference == "ic:" .. otherRuleKey then otherPosition = index; break end
    end
    for _, reference in ipairs(order.contexts[contextKey][sourceMode]) do
        if reference ~= "ic:" .. otherRuleKey then sequence[#sequence + 1] = reference end
    end
    if activeMode == "display" then
        assert(otherPosition, "Other is missing from Display")
        table.insert(sequence, math.min(otherPosition, #sequence + 1), "ic:" .. otherRuleKey)
    end
    return ApplyOrderOverride({
        [contextKey] = { [activeMode] = sequence },
    })
end

local function MergeDestinationSlots(source, destination)
    local destinationSet, sourceSet, shared, result = {}, {}, {}, {}
    for _, reference in ipairs(destination) do destinationSet[reference] = true end
    for _, reference in ipairs(source) do
        sourceSet[reference] = true
        if destinationSet[reference] then shared[#shared + 1] = reference end
    end
    local sharedIndex = 1
    for index, reference in ipairs(destination) do
        if not sourceSet[reference] then
            result[index] = reference
        else
            result[index] = shared[sharedIndex]
            sharedIndex = sharedIndex + 1
        end
    end
    assert(sharedIndex == #shared + 1, "Cross-context copy lost a shared AutoCategory reference")
    return result
end

function integration.CopyBothOrders(sourceContext, destinationContext)
    assert(contextByKey[sourceContext] and contextByKey[destinationContext],
        "Unknown AutoCategory copy context")
    if sourceContext == destinationContext then return false end
    local _, order = GetCurrentOrderData()
    local source, destination = order.contexts[sourceContext], order.contexts[destinationContext]
    local override = { [destinationContext] = {} }
    for _, mode in ipairs({ "display", "matching" }) do
        override[destinationContext][mode] = MergeDestinationSlots(source[mode], destination[mode])
    end
    return ApplyOrderOverride(override)
end

local originalInstallExternalHooks = InstallExternalHooks
InstallExternalHooks = function()
    originalInstallExternalHooks()
    if renameHookInstalled then return end
    local ac = AutoCategory
    assert(type(ac.renameBagRule) == "function", "AutoCategory renameBagRule hook target is unavailable")
    ZO_PostHook(ac, "renameBagRule", function(oldName, newName) integration.Run(function()
        if integration.NeedsRecovery() or reconciling or ac.Inited ~= true then return end
        assert(type(oldName) == "string" and oldName ~= "" and type(newName) == "string" and newName ~= "",
            "AutoCategory rename hook supplied invalid names")
        if oldName == newName then return end
        local profile = this.GetAutoCategoryProfile()
        local oldReference, newReference = "ac:" .. oldName, "ac:" .. newName
        for _, context in ipairs(contexts) do
            local lists = profile.autoCategoryOrder.contexts[context.key]
            lists.hidden[newReference], lists.hidden[oldReference] = lists.hidden[oldReference], nil
            lists.displayPositions[newReference], lists.displayPositions[oldReference] =
                lists.displayPositions[oldReference], nil
            for _, mode in ipairs({ "display", "matching" }) do
                local seen = {}
                for index, reference in ipairs(lists[mode]) do
                    if reference == oldReference then lists[mode][index] = newReference end
                    assert(not seen[lists[mode][index]],
                        "AutoCategory rename creates duplicate order reference: " .. newReference)
                    seen[lists[mode][index]] = true
                end
            end
        end
        local snapshots = projectedOrders[ac.saved.bags]
        if snapshots then
            for _, context in ipairs(contexts) do
                for _, mode in ipairs({ "display", "matching" }) do
                    for index, reference in ipairs(snapshots[context.key][mode]) do
                        if reference == oldReference then snapshots[context.key][mode][index] = newReference end
                    end
                end
            end
        end
        ScheduleReconcile("native-category-renamed", false)
    end) end)
    renameHookInstalled = true
end

for _, name in ipairs({
    "Initialize", "OnRuleMutation", "OnProfileChanged", "OnEnablementChanged",
    "ProjectAutoCategory", "MoveEntry", "MoveEntries", "UseOtherOrder", "CopyBothOrders", "GetHeadingDetails",
    "CompleteInitialSetup",
    "SetEntryIncluded",
}) do
    local operation = integration[name]
    integration[name] = function(...) return integration.TimePhase(name, integration.Run, operation, ...) end
end

local showInitialSetup = integration.ShowInitialSetup
function integration.ShowInitialSetup(resetExpected)
    if resetExpected ~= nil then return showInitialSetup(resetExpected) end
    return integration.Run(showInitialSetup)
end
