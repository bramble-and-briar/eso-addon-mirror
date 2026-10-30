local this = InventoryCompanion

local function Equal(actual, expected, message)
    assert(actual == expected, string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
end

local function List(actual, expected, message)
    Equal(#actual, #expected, message .. " length")
    for index, value in ipairs(expected) do Equal(actual[index], value, message .. " #" .. index) end
end

local function FailsWith(run, fragment)
    local ok, err = pcall(run)
    assert(not ok, "Expected failure containing: " .. fragment)
    assert(tostring(err):find(fragment, 1, true), "Unexpected error: " .. tostring(err))
end

function this.GetRuleTests()
    local tests = {}
    local function Add(name, run)
        table.insert(tests, {
            name = name,
            run = function()
                local accountWide, character, baseline = this.accountWide, this.character, this.preLoadedRulesets
                local scanning, utils = this.Scanning, this.Utils
                local globalNames = {
                    this.SettingsName, "ZO_ClearTable", "GetItemLinkName", "GetItemId", "GetItemLink",
                    "IsESOPlusSubscriber", "BAG_BACKPACK", "BAG_BANK", "BAG_VIRTUAL", "GetGameTimeMilliseconds",
                }
                local globals = {}
                for _, key in ipairs(globalNames) do table.insert(globals, { key = key, value = _G[key] }) end
                this.accountWide = { trackedRules = {}, trackedItems = {} }
                this.character = { trackedRules = {}, trackedItems = {}, useCharacterItemList = false }
                this.preLoadedRulesets = {
                    default = {
                        displayName = "Default",
                        patterns = { "c", "a", "b" },
                        display = { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false },
                    },
                }
                this.InvalidateRuleCache()
                local ok, err = pcall(run)
                this.accountWide, this.character, this.preLoadedRulesets = accountWide, character, baseline
                this.Scanning, this.Utils = scanning, utils
                for _, entry in ipairs(globals) do _G[entry.key] = entry.value end
                this.InvalidateRuleCache()
                if not ok then error(err, 0) end
                return err
            end,
        })
    end

    Add("Delta patterns follow the sequential specification", function()
        local function State(edited, added, removed, effective)
            this.UpdateRulePatterns("default", edited)
            local saved = this.accountWide.trackedRules.default or {}
            List(saved.addedPatterns or {}, added, "Added")
            List(saved.removedPatterns or {}, removed, "Removed")
            Equal(saved.patterns, nil, "No full baseline copy")
            List(this.GetActiveTrackedRules().default.patterns, effective, "Effective list")
        end
        State({ "a", "b", "c" }, {}, {}, { "a", "b", "c" })
        Equal(this.accountWide.trackedRules.default, nil, "No redundant rule")
        State({ "a", "b", "c", "d" }, { "d" }, {}, { "a", "b", "c", "d" })
        State({ "a1", "b", "c", "d" }, { "a1", "d" }, { "a" }, { "a1", "b", "c", "d" })
        State({ "a", "b", "c", "d" }, { "d" }, {}, { "a", "b", "c", "d" })
        State({ "a", "b", "c", "d1" }, { "d1" }, {}, { "a", "b", "c", "d1" })
        State({ "a", "b", "d1" }, { "d1" }, { "c" }, { "a", "b", "d1" })
        State({ "a", "b", "c" }, {}, {}, { "a", "b", "c" })
        Equal(this.accountWide.trackedRules.default, nil, "Reverting removes the override")
    end)

    Add("Delta patterns are unique and support empty lists and custom groups", function()
        this.UpdateRulePatterns("default", { "a", "a", "c" })
        List(this.GetActiveTrackedRules().default.patterns, { "a", "c" }, "Duplicate edit")
        List(this.accountWide.trackedRules.default.removedPatterns, { "b" }, "Duplicate edit removes old value")
        this.UpdateRulePatterns("default", {})
        List(this.GetActiveTrackedRules().default.patterns, {}, "Remove all defaults")
        this.UpdateRulePatterns("custom", { "z", "z", "a" })
        List(this.accountWide.trackedRules.custom.addedPatterns, { "a", "z" }, "Custom additions")
        this.UpdateRulePatterns("custom", {})
        assert(this.accountWide.trackedRules.custom, "An empty custom group must remain")
        Equal(this.accountWide.trackedRules.custom.addedPatterns, nil, "Empty collection is absent")
    end)

    Add("Rule setters write only selected fields and prune restored defaults", function()
        this.UpdateRuleProperty("default", "displayName", "Renamed")
        local saved = this.accountWide.trackedRules.default
        Equal(saved.displayName, "Renamed", "Name")
        Equal(saved.display, nil, "Rename does not copy flags")
        Equal(saved.addedPatterns, nil, "Rename does not copy patterns")
        this.UpdateRuleFlag("default", "show", false)
        this.UpdateRulePatterns("default", { "a", "b", "c", "d" })
        Equal(saved.displayName, "Renamed", "Pattern editing preserves name")
        Equal(saved.display.show, false, "Pattern editing preserves flag")
        this.UpdateRulePatterns("default", { "a", "b", "c" })
        this.UpdateRuleFlag("default", "show", true)
        Equal(saved.display, nil, "Restored display table pruned")
        this.UpdateRuleProperty("default", "displayName", "Default")
        Equal(this.accountWide.trackedRules.default, nil, "Restored rule pruned")
        this.SetRuleFlag("default", "notify", true)
        Equal(this.accountWide.trackedRules.default.display.notify, true, "Compatible flag setter")
    end)

    Add("Legacy rules convert to sparse overrides without altering the baseline", function()
        this.accountWide.trackedRules = {
            default = {
                displayName = "Default", patterns = { "b", "c", "d", "d" },
                display = { show = true, notify = true, isHidden = false },
            },
            custom = { patterns = { "z", "z" }, display = { notify = true } },
        }
        local rules = this.GetActiveTrackedRules()
        local saved = this.accountWide.trackedRules.default
        List(saved.addedPatterns, { "d" }, "Legacy additions")
        List(saved.removedPatterns, { "a" }, "Legacy removals")
        Equal(saved.patterns, nil, "Legacy list removed")
        Equal(saved.displayName, nil, "Legacy default name removed")
        Equal(saved.display.show, nil, "Legacy default flag removed")
        Equal(saved.display.notify, true, "Edited flag retained")
        List(rules.default.patterns, { "b", "c", "d" }, "Legacy effective list")
        Equal(rules.custom.display.show, true, "Partial custom display inherits defaults")
        List(this.preLoadedRulesets.default.patterns, { "c", "a", "b" }, "Baseline unchanged")
        this.preLoadedRulesets.default.patterns = { "a", "b", "c", "e" }
        this.InvalidateRuleCache()
        List(this.GetActiveTrackedRules().default.patterns, { "b", "c", "d", "e" }, "New defaults remain visible")
    end)

    Add("Invalid rule mutations fail without writing saved state", function()
        assert(not pcall(this.UpdateRulePatterns, "default", { true }), "Invalid patterns should fail")
        assert(not pcall(this.UpdateRuleFlag, "default", "missing", true), "Unknown flags should fail")
        assert(not pcall(this.UpdateRuleFlag, "default", "show", "yes"), "Invalid flag values should fail")
        assert(not pcall(this.UpdateRuleProperty, "default", "patterns", {}), "Wrong mutation API should fail")
        Equal(next(this.accountWide.trackedRules), nil, "Failed edits leave no overrides")
    end)

    Add("Saved rule boundary rejects malformed data without discarding it", function()
        local cases = {
            { rules = false, field = "Account-wide.trackedRules" },
            { rules = { bad = false }, field = "[bad]" },
            { rules = { [12] = {} }, field = "invalid rule key" },
            { rules = { bad = { displayName = 12 } }, field = "[bad].displayName" },
            { rules = { bad = { display = false } }, field = "[bad].display" },
            { rules = { bad = { display = { show = "yes" } } }, field = ".display.show" },
            { rules = { bad = { display = { typo = true } } }, field = "unknown flag" },
            { rules = { bad = { addedPatterns = false } }, field = "[bad].addedPatterns" },
            { rules = { bad = { removedPatterns = { true } } }, field = "removedPatterns[1]" },
            { rules = { bad = { patterns = { [2] = "hole" } } }, field = "must not contain holes" },
            { rules = { bad = { addedPatterns = { named = "ignored" } } }, field = "positive integer indices" },
        }
        for _, case in ipairs(cases) do
            this.accountWide.trackedRules = case.rules
            this.accountWide.unrelated = "preserved"
            FailsWith(this.GetRuntimeRules, case.field)
            Equal(this.accountWide.trackedRules, case.rules, "Rejected saved table is not replaced")
            Equal(this.accountWide.unrelated, "preserved", "Unrelated settings retained")
        end
        local legacy = { patterns = { "legacy*" }, displayName = "Legacy" }
        this.accountWide.trackedRules = { valid = legacy, broken = { removedPatterns = false } }
        FailsWith(this.GetRuntimeRules, "broken")
        Equal(legacy.patterns[1], "legacy*", "Reject before migrating any rule")
        Equal(legacy.addedPatterns, nil, "No partial conversion")
        this.accountWide.trackedRules = { custom = { patterns = { "valid*" }, extra = { keep = true } } }
        local extra = this.accountWide.trackedRules.custom.extra
        this.GetRuntimeRules()
        Equal(this.accountWide.trackedRules.custom.extra, extra, "Unrelated rule fields retained through validation/migration")
        Equal(extra.keep, true, "Unrelated rule data not modified")
    end)

    Add("Initialization validates inactive saved profiles and optional absence", function()
        this.accountWide.trackedRules = nil
        this.character.trackedRules = { broken = { addedPatterns = false } }
        FailsWith(this.ValidateSavedRuleProfiles, "Character.trackedRules[broken].addedPatterns")
        Equal(this.character.trackedRules.broken.addedPatterns, false, "Invalid inactive data retained")
        this.character.trackedRules = nil
        this.ValidateSavedRuleProfiles()
        Equal(type(this.accountWide.trackedRules), "table", "Missing account rules initialize")
        Equal(type(this.character.trackedRules), "table", "Missing character rules initialize")
        this.character.useCharacterItemList = "yes"
        FailsWith(this.ValidateSavedRuleProfiles, "useCharacterItemList must be boolean")
    end)

    Add("Internal mutation contracts reject sparse lists and invalid list switches", function()
        for _, patterns in ipairs({
            { [2] = "hole" }, { [1] = "a", [3] = "c" },
            { named = "ignored" }, { [0] = "zero" }, { [1.5] = "fraction" },
        }) do
            FailsWith(function() this.UpdateRulePatterns("default", patterns) end, "Rule patterns")
            Equal(next(this.accountWide.trackedRules), nil, "Invalid internal list does not write")
        end
        FailsWith(function() this.SetUseCharacterItemList("yes") end, "must be boolean")
        Equal(this.character.useCharacterItemList, false, "Bad switch does not change mode")
        this.ValidateSavedRuleProfiles()
        this.accountWide.trackedRules = nil
        FailsWith(this.GetRuntimeRules, "Account-wide.trackedRules must be a table")
        Equal(this.accountWide.trackedRules, nil, "Internal loss of required rules is not silently repaired")
    end)

    Add("Broken maintained baselines fail before normalization or writes", function()
        local base = this.preLoadedRulesets.default
        this.accountWide.trackedRules = { default = { displayName = "Default", patterns = { "legacy" } } }
        local patterns = base.patterns
        base.patterns = nil
        FailsWith(this.GetRuntimeRules, "Built-in rule default.patterns")
        Equal(this.accountWide.trackedRules.default.patterns[1], "legacy", "Broken baseline does not migrate saved rules")
        base.patterns = patterns
        local display = base.display
        base.display = nil
        FailsWith(function() this.UpdateRuleFlag("default", "show", false) end, "Built-in rule default.display")
        Equal(this.accountWide.trackedRules.default.display, nil, "Broken baseline does not create flag overrides")
        base.display = display
        base.display.show = nil
        FailsWith(this.GetRuntimeRules, "display.show must be boolean")
        base.display.show = true
        base.displayName = nil
        FailsWith(function() this.UpdateRuleProperty("default", "displayName", "Changed") end, ".displayName must be a string")
    end)

    Add("Scans require compiled rules instead of silently compiling raw input", function()
        FailsWith(function()
            this.GetMasterItemList({}, { broken = { patterns = { "raw*" } } }, {})
        end, "Rule broken is missing compiledPatterns")
    end)

    Add("Runtime cache rebuilds lazily and keeps editor views isolated", function()
        local original = this.GetRuntimeRules()
        Equal(this.GetRuntimeRules(), original, "Unchanged rules reuse cache")
        this.UpdateRulePatterns("default", { "new*" })
        List(original.default.patterns, { "a", "b", "c" }, "Mutation does not eagerly rebuild")
        local updated = this.GetRuntimeRules()
        assert(updated ~= original, "Pattern mutation should replace the cache")
        Equal(this.GetRuntimeRules(), updated, "Rebuilt cache reused")
        List(updated.default.compiledPatterns, { "^new.*$" }, "Compiled wildcard")
        this.UpdateRuleProperty("default", "displayName", "Changed")
        local renamed = this.GetRuntimeRules()
        assert(renamed ~= updated, "Rename should invalidate")
        Equal(renamed.default.displayName, "Changed", "Cached name updates")
        this.UpdateRuleFlag("default", "notify", true)
        local flagged = this.GetRuntimeRules()
        assert(flagged ~= renamed, "Flag should invalidate")
        Equal(flagged.default.display.notify, true, "Cached flag updates")
        local view = this.GetActiveTrackedRules()
        view.default.patterns[1] = "editor-only"
        view.default.display.notify = false
        Equal(flagged.default.patterns[1], "new*", "Editor list cannot corrupt cache")
        Equal(flagged.default.display.notify, true, "Editor flags cannot corrupt cache")
        Equal(this.accountWide.trackedRules.default.compiledPatterns, nil, "No compiled saved data")
    end)

    Add("Hidden groups stay cached and list switching invalidates immediately", function()
        this.UpdateRuleFlag("default", "isHidden", true)
        assert(this.GetRuntimeRules().default, "Hidden rule must be cached")
        Equal(this.GetActiveTrackedRules().default, nil, "Hidden rule excluded from normal view")
        assert(this.GetActiveTrackedRules(true).default, "Editor includes hidden rules")
        this.UpdateRuleFlag("default", "isHidden", false)
        assert(this.GetActiveTrackedRules().default, "Unhide invalidates")
        this.UpdateRulePatterns("default", { "account" })
        local account = this.GetRuntimeRules()
        this.SetUseCharacterItemList(true)
        List(this.GetRuntimeRules().default.patterns, { "a", "b", "c" }, "Character inherits baseline")
        this.UpdateRulePatterns("default", { "character" })
        List(this.GetRuntimeRules().default.patterns, { "character" }, "Character override")
        this.SetUseCharacterItemList(false)
        local restored = this.GetRuntimeRules()
        assert(restored ~= account, "Switching rebuilds cache")
        List(restored.default.patterns, { "account" }, "Account override retained")
    end)

    Add("Failed runtime rebuilds do not publish partial caches", function()
        local original = this.GetRuntimeRules()
        this.preLoadedRulesets.default.patterns = { true }
        this.InvalidateRuleCache()
        assert(not pcall(this.GetRuntimeRules), "Invalid baseline should surface an error")
        List(original.default.patterns, { "a", "b", "c" }, "Published cache unchanged after failure")
        this.preLoadedRulesets.default.patterns = { "repaired" }
        List(this.GetRuntimeRules().default.patterns, { "repaired" }, "Failed rebuild remains invalid")
    end)

    Add("Profile copy preserves sparse deltas and never aliases its source", function()
        _G.ZO_ClearTable = function(values) for key in pairs(values) do values[key] = nil end end
        this.preLoadedRulesets.default.display.notify = true
        local source = {
            trackedItems = { [123] = { link = "item", mode = 3, display = { show = false } } },
            trackedRules = {
                default = { addedPatterns = { "d" }, removedPatterns = { "a" }, display = { show = false } },
                custom = { patterns = { "custom" } },
            },
        }
        _G[this.SettingsName] = { Default = { account = { source = source } } }
        local before = this.GetRuntimeRules()
        assert(this.CopyProfile("source"), "Profile copy should succeed")
        local copied = this.accountWide.trackedRules
        Equal(copied.default.display.notify, nil, "Missing source flag stays absent")
        Equal(this.GetRuntimeRules().default.display.notify, true, "Missing flag inherits baseline")
        assert(this.GetRuntimeRules() ~= before, "Profile copy invalidates")
        List(this.GetRuntimeRules().default.patterns, { "b", "c", "d" }, "Copied effective patterns")
        this.UpdateRulePatterns("default", { "b", "c", "d", "e" })
        List(source.trackedRules.default.addedPatterns, { "d" }, "Source additions isolated")
        this.UpdateRuleFlag("default", "show", true)
        Equal(source.trackedRules.default.display.show, false, "Source flags isolated")
        Equal(source.trackedRules.custom.patterns[1], "custom", "Source legacy data not migrated in place")
        local valid = this.GetRuntimeRules()
        assert(not this.CopyProfile("missing"), "Unknown profile should fail")
        Equal(this.GetRuntimeRules(), valid, "Failed copy does not invalidate")
        _G[this.SettingsName].Default.account.self = this.accountWide
        assert(this.CopyProfile("self"), "Self-copy should preserve data")
        Equal(this.accountWide.trackedItems[123].link, "item", "Self-copy retains items")
        List(this.GetRuntimeRules().default.patterns, { "b", "c", "d", "e" }, "Self-copy retains rules")
    end)

    Add("Malformed imported rules fail before clearing the destination", function()
        local source = {
            trackedItems = {},
            trackedRules = { broken = { addedPatterns = false } },
        }
        _G[this.SettingsName] = { Default = { account = { source = source } } }
        this.UpdateRuleProperty("default", "displayName", "Keep")
        this.accountWide.trackedItems[123] = { link = "keep" }
        local rules, items = this.accountWide.trackedRules, this.accountWide.trackedItems
        local cache = this.GetRuntimeRules()
        FailsWith(function() this.CopyProfile("source") end, "Imported profile source.trackedRules[broken].addedPatterns")
        Equal(this.accountWide.trackedRules, rules, "Destination rules table retained")
        Equal(rules.default.displayName, "Keep", "Destination overrides retained")
        Equal(this.accountWide.trackedItems, items, "Destination items table retained")
        Equal(items[123].link, "keep", "Destination items retained")
        Equal(this.GetRuntimeRules(), cache, "Rejected import does not invalidate")
        Equal(source.trackedRules.broken.addedPatterns, false, "Malformed source retained for repair")
        _G[this.SettingsName].Default.account.source = false
        FailsWith(function() this.CopyProfile("source") end, "Imported profile source must be a table")
        source.trackedRules.broken = {}
        source.trackedItems = false
        _G[this.SettingsName].Default.account.source = source
        FailsWith(function() this.CopyProfile("source") end, "Imported profile source.trackedItems must be a table")
        Equal(items[123].link, "keep", "Malformed item container cannot clear destination")
    end)

    Add("Scanning and notifications use current compiled rules", function()
        _G.BAG_BACKPACK, _G.BAG_BANK, _G.BAG_VIRTUAL = 1, 2, 3
        _G.GetItemLinkName = function(link) return link == "item" and "Target +1" or nil end
        _G.GetItemId = function() return 987654321 end
        _G.GetItemLink = function() return "item" end
        _G.IsESOPlusSubscriber = function() return false end
        local entries = { { itemId = 987654321, link = "item", icon = "icon", count = 2 } }
        this.Scanning = { GetBagContents = function() return entries end }
        local warnings = 0
        this.Utils = {
            FormatBigNumber = tostring,
            UserWarning = function() warnings = warnings + 1 end,
        }
        this.UpdateRulePatterns("default", { "Target +1" })
        this.UpdateRuleFlag("default", "notify", true)
        local cache = this.GetRuntimeRules()
        assert(this.ItemMatchesRuntimeRule("item", cache.default), "Literal punctuation matches")
        assert(not this.ItemMatchesRuntimeRule("missing", cache.default), "Missing item never matches")
        local snapshot = this.GetMasterItemList({}, this.GetActiveTrackedRules(), { BAG_BACKPACK })
        Equal(#snapshot.ruleIndex.default, 1, "Scan uses compiled rule")
        this.HandleTrackedItemInventoryUpdate(BAG_BACKPACK, 1, 1)
        Equal(warnings, 1, "Notification uses compiled rule")
        this.UpdateRulePatterns("default", { "Other*" })
        this.HandleTrackedItemInventoryUpdate(BAG_BACKPACK, 1, 1)
        Equal(warnings, 1, "Notification sees pattern change before any scan")
        this.UpdateRulePatterns("default", { "Target*" })
        this.UpdateRuleFlag("default", "isHidden", true)
        this.HandleTrackedItemInventoryUpdate(BAG_BACKPACK, 1, 1)
        Equal(warnings, 1, "Hidden groups do not notify")
        this.UpdateRuleFlag("default", "isHidden", false)
        this.HandleTrackedItemInventoryUpdate(BAG_BACKPACK, 1, 1)
        Equal(warnings, 2, "Unhiding takes effect immediately")
    end)

    Add("Empty patterns do not match every item", function()
        _G.GetItemLinkName = function(link) return link == "item" and "Target +1" or nil end
        this.UpdateRulePatterns("custom", { "" })
        local rule = this.GetRuntimeRules().custom
        assert(not this.ItemMatchesRuntimeRule("item", rule), "An empty saved pattern must not match items")
        assert(not this.ItemMatchesRule("item", ""), "An empty standalone pattern must not match items")
    end)

    Add("Group lifecycle mutations invalidate and clear only the active profile", function()
        local initial = this.GetRuntimeRules()
        this.CreateCustomRule("custom", "Custom")
        local created = this.GetRuntimeRules()
        assert(created ~= initial and created.custom, "Creation must invalidate")
        Equal(next(created.custom.patterns), nil, "Custom group starts empty")
        Equal(this.accountWide.trackedRules.custom.display, nil, "Custom defaults are not copied")
        this.UpdateRulePatterns("custom", { "custom*" })
        this.DeleteCustomRule("custom")
        Equal(this.GetRuntimeRules().custom, nil, "Deletion must invalidate")
        this.UpdateRuleProperty("default", "displayName", "Changed")
        this.UpdateRulePatterns("default", {})
        this.UpdateRuleFlag("default", "notify", true)
        this.UpdateRuleFlag("default", "isHidden", true)
        this.UpdateRuleFlag("default", "show", false)
        this.UpdateRuleFlag("default", "bank", true)
        this.UpdateRuleFlag("default", "group", false)
        this.UpdateRuleFlag("default", "isExpanded", false)
        local display = this.accountWide.trackedRules.default.display
        local beforeReset = this.GetRuntimeRules()
        assert(this.HasResettableRuleOverrides("default"), "Edited group has overrides")
        this.ResetRule("default")
        Equal(this.accountWide.trackedRules.default.display, display, "Reset retains the display override table")
        Equal(this.accountWide.trackedRules.default.displayName, nil, "Reset removes name override")
        Equal(this.accountWide.trackedRules.default.removedPatterns, nil, "Reset removes pattern overrides")
        assert(this.GetRuntimeRules() ~= beforeReset, "Reset invalidates cache")
        List(this.GetRuntimeRules().default.patterns, { "a", "b", "c" }, "Reset restores patterns")
        Equal(this.GetRuntimeRules().default.displayName, "Default", "Reset restores name")
        for key, value in pairs(display) do
            Equal(this.GetRuntimeRules().default.display[key], value, "Reset preserves " .. key)
        end
        Equal(this.GetActiveTrackedRules().default, nil, "Reset does not unhide a hidden group")
        assert(not this.HasResettableRuleOverrides("default"), "Display-only changes are not resettable")
        this.ResetRule("default")
        Equal(this.accountWide.trackedRules.default.display, display, "Repeated reset preserves display")
        this.UpdateRuleProperty("default", "displayName", "Changed again")
        this.SetUseCharacterItemList(true)
        this.UpdateRuleProperty("default", "displayName", "Character name")
        this.ResetRule("default")
        Equal(this.character.trackedRules.default, nil, "Name-only reset prunes the empty rule")
        this.SetUseCharacterItemList(false)
        Equal(this.GetRuntimeRules().default.displayName, "Changed again", "Other profile is not reset")
        this.SetUseCharacterItemList(true)
        this.CreateCustomRule("custom", "Character custom")
        this.SetUseCharacterItemList(false)
        Equal(this.GetRuntimeRules().custom, nil, "Character group does not leak to account")
        assert(not pcall(this.DeleteCustomRule, "default"), "Built-ins cannot be deleted")
        assert(not pcall(this.CreateCustomRule, "default", "Duplicate"), "Built-ins cannot be replaced")
        assert(not pcall(this.ResetRule, "custom"), "Custom groups cannot be reset as built-ins")
    end)

    Add("Untouched defaults allocate no saved rule data", function()
        local matcher = this.ItemMatchesRuntimeRule
        Equal(type(matcher), "function", "Runtime matcher exists before cache construction")
        local cache = this.GetRuntimeRules()
        Equal(this.ItemMatchesRuntimeRule, matcher, "Compiling patterns must not redefine the matcher")
        Equal(next(this.accountWide.trackedRules), nil, "Reading defaults must not persist rules")
        List(cache.default.patterns, { "a", "b", "c" }, "Defaults are sorted")
        this.UpdateRuleFlag("default", "show", true)
        this.UpdateRuleProperty("default", "displayName", "Default")
        this.UpdateRulePatterns("default", { "c", "a", "b", "a" })
        Equal(next(this.accountWide.trackedRules), nil, "Writing baseline values must not persist rules")
        this.UpdateRuleProperty("default", "displayName", "Renamed")
        this.preLoadedRulesets.default.display.notify = true
        this.preLoadedRulesets.default.patterns = { "new default" }
        this.InvalidateRuleCache()
        local updated = this.GetRuntimeRules().default
        Equal(updated.displayName, "Renamed", "Explicit name is preserved")
        Equal(updated.display.notify, true, "Unmodified flag follows updated baseline")
        List(updated.patterns, { "new default" }, "Unmodified patterns follow updated baseline")
    end)

    Add("Reconciled pattern deltas obey set invariants across repeated edits", function()
        local candidates = { "a", "b", "c", "d", "e", "f" }
        for iteration = 0, 63 do
            local edited, expected, added, removed = {}, {}, {}, {}
            for index, pattern in ipairs(candidates) do
                local included = math.floor(iteration / (2 ^ (index - 1))) % 2 == 1
                if included then
                    table.insert(edited, pattern)
                    table.insert(edited, pattern)
                    table.insert(expected, pattern)
                    if index > 3 then table.insert(added, pattern) end
                elseif index <= 3 then
                    table.insert(removed, pattern)
                end
            end
            this.UpdateRulePatterns("default", edited)
            local saved = this.accountWide.trackedRules.default or {}
            List(saved.addedPatterns or {}, added, "Exact addition delta " .. iteration)
            List(saved.removedPatterns or {}, removed, "Exact removal delta " .. iteration)
            List(this.GetRuntimeRules().default.patterns, expected, "Exact effective set " .. iteration)
            for key in pairs(saved) do
                assert(key == "addedPatterns" or key == "removedPatterns", "Unexpected saved field: " .. key)
            end
        end
    end)

    Add("Cached synthetic scans and inventory bursts stay within thresholds", function()
        _G.BAG_BACKPACK, _G.BAG_BANK, _G.BAG_VIRTUAL = 1, 2, 3
        _G.GetItemLinkName = function(link) return link end
        _G.GetItemId = function(_, slotIndex) return 990000 + slotIndex end
        _G.GetItemLink = function(_, slotIndex) return "Synthetic Item " .. slotIndex end
        _G.IsESOPlusSubscriber = function() return false end
        local entries = {}
        for index = 1, 100 do
            entries[index] = { itemId = 990000 + index, link = "Synthetic Item " .. index, icon = "icon", count = 1 }
        end
        this.Scanning = { GetBagContents = function() return entries end }
        local warnings = 0
        this.Utils = { FormatBigNumber = tostring, UserWarning = function() warnings = warnings + 1 end }
        this.preLoadedRulesets = {}
        for index = 1, 20 do
            this.preLoadedRulesets["synthetic_" .. index] = {
                displayName = "Synthetic " .. index,
                patterns = { "Synthetic Item *" },
                display = { show = true, notify = true, bank = false, group = true, isExpanded = true, isHidden = false },
            }
        end
        local cache = this.GetRuntimeRules()
        local started = GetGameTimeMilliseconds()
        for _ = 1, 20 do
            local snapshot = this.GetMasterItemList({}, this.GetActiveTrackedRules(), { BAG_BACKPACK })
            Equal(#snapshot.ruleIndex.synthetic_1, 100, "All items matched")
            Equal(#snapshot.ruleIndex.synthetic_20, 100, "All rules matched")
        end
        local scanMs = GetGameTimeMilliseconds() - started
        started = GetGameTimeMilliseconds()
        for index = 1, 100 do
            assert(this.ItemMatchesRuntimeRule("Synthetic Item " .. index, cache.synthetic_1), "Burst rule match")
        end
        local matchMs = GetGameTimeMilliseconds() - started
        started = GetGameTimeMilliseconds()
        for index = 1, 100 do this.HandleTrackedItemInventoryUpdate(BAG_BACKPACK, index, 1) end
        local updateMs = GetGameTimeMilliseconds() - started
        Equal(warnings, 100, "Every synthetic update notifies")
        Equal(this.GetRuntimeRules(), cache, "Bursts reuse the cache")
        Equal(next(this.accountWide.trackedRules), nil, "Bursts do not write saved rules")
        local timings = string.format("20 scans: %d/500 ms; 100 matches: %d/100 ms; 100 updates: %d/200 ms",
            scanMs, matchMs, updateMs)
        assert(scanMs <= 500 and matchMs <= 100 and updateMs <= 200, timings)
        return timings
    end)

    return tests
end
