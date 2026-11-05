local C = CrownCrateCodex

local function Refresh()
    C:Discover()
    if not C.didInitialImport then
        local report = C:ImportAvailable()
        C.didInitialImport = true
        C:RebuildCatalog()
        if report.imported > 0 then d(string.format(C.L("Crown Crate Codex: imported %d Tracker openings. Original history unchanged."), report.imported)) end
    end
    if C.AttachCrateScene then C:AttachCrateScene() end
    if C.window and not C.window:IsHidden() then C:RefreshUI() end
end

local function QueueSync()
    if C.syncQueued then return end
    C.syncQueued = true
    -- One deferred callback per event batch lets Tracker finish regardless of
    -- addon event-handler order. This is not a repeating update or poll loop.
    zo_callLater(function()
        C.syncQueued = false
        C:ReconcileTrackerResponses()
        C:ImportAvailable()
        if C.window and not C.window:IsHidden() then C:RefreshUI() end
    end, 0)
end

local function Loaded(_, addonName)
    if addonName ~= C.name then return end
    EVENT_MANAGER:UnregisterForEvent(C.name, EVENT_ADD_ON_LOADED)
    local world=GetWorldName()
    local store=ZO_SavedVars:NewAccountWide("CrownCrateCodexSavedVariables",1,nil,{},world)
    local shared=ZO_SavedVars:NewAccountWide("CrownCrateCodexSavedVariables",1,nil,{},"Codex Shared")
    C:InitializeServerStore(store,shared,world,CrownCrateCodexSavedVariables,GetDisplayName and GetDisplayName() or "")
    if C.InitializeLanguage then C:InitializeLanguage() end
    if C.SyncGamepad and EVENT_GAMEPAD_PREFERRED_MODE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(C.name,EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,function()
            C.gamepadEditing=false; C:SyncGamepad()
        end)
    end
    if C.SyncGamepad then
        for _,event in pairs({EVENT_KEYBINDING_SET,EVENT_KEYBINDING_CLEARED,EVENT_INPUT_TYPE_CHANGED,EVENT_KEYBIND_DISPLAY_MODE_CHANGED}) do
            EVENT_MANAGER:RegisterForEvent(C.name,event,function()
                if C:GamepadRoot() then C:SyncGamepad() end
            end)
        end
    end
    if C.InitializeSettings then C:InitializeSettings() end
    EVENT_MANAGER:RegisterForEvent(C.name, EVENT_PLAYER_ACTIVATED, Refresh)
    EVENT_MANAGER:RegisterForEvent(C.name, EVENT_CROWN_CRATE_INVENTORY_UPDATED, Refresh)
    EVENT_MANAGER:RegisterForEvent(C.name, EVENT_CROWN_CRATE_QUANTITY_UPDATE, Refresh)
    EVENT_MANAGER:RegisterForEvent(C.name, EVENT_CROWN_CRATES_SYSTEM_STATE_CHANGED, Refresh)
    EVENT_MANAGER:RegisterForEvent(C.name, EVENT_CROWN_CRATE_OPEN_RESPONSE, function(_, id, response)
        local recorded = C:Capture(id, response)
        C.trackerResponses = C.trackerResponses or {}
        C.trackerResponses[#C.trackerResponses + 1] = response == LOOT_CRATE_OPEN_RESPONSE_SUCCESS
        QueueSync()
        if response == LOOT_CRATE_OPEN_RESPONSE_SUCCESS and not recorded then
            d(C.L("Crown Crate Codex: could not read this opening. Use /ccc status for diagnostics."))
        end
        if C.window and not C.window:IsHidden() then C:RefreshUI() end
    end)
    SLASH_COMMANDS["/ccc"] = function(argument)
        argument = string.lower(argument or "")
        if argument == "keys" then
            C:OpenKeybindings()
        elseif argument == "settings" then
            C:OpenSettings()
        elseif argument == "scan" then
            Refresh()
            d(C.L("Crown Crate Codex: refreshed owned and on-sale crate types."))
        elseif argument == "import" then
            C:RunManualImport()
            Refresh()
        elseif argument == "status" then
            d(string.format(C.L("Crown Crate Codex %s | API %s | %d openings | %d failed requests | %d unreadable openings"),
                C.version, tostring(GetAPIVersion()), #C.db.history,
                C.db.diagnostics.failedOpens, C.db.diagnostics.unreadableOpens))
            local report = C.db.lastImport
            if report then d(string.format(C.L("Tracker sync: %d added, %d existing, %d unreadable | Imported statistics: %s | Imported tier rates: %s"),
                report.imported, report.existing, report.invalid, C.db.settings.includeImported and C.L("ON") or C.L("OFF"),
                C.db.settings.includeImportedTiers and C.L("ON") or C.L("OFF"))) end
        else
            C:Toggle()
        end
    end
    SLASH_COMMANDS["/crowncratecodex"] = SLASH_COMMANDS["/ccc"]
    ZO_CreateStringId("SI_BINDING_NAME_CROWN_CRATE_CODEX_TOGGLE", C.L("Open Crown Crate Codex"))
end

EVENT_MANAGER:RegisterForEvent(C.name, EVENT_ADD_ON_LOADED, Loaded)
