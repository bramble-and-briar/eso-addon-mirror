-- FurnishingCatalogMain.lua: slash commands and load sequence.
local FC = FurnishingCatalog

local function Status()
    local d = FC.diagnostics
    local catalog = FC.state.savedVars.catalog
    FC.Chat(FC.Fmt("v%s debug=%s (%s)", FC.version, tostring(FC.IsDebug()), FC.LoggerStateLine()))
    FC.Chat(FC.Fmt("memory: %s", FC.MemText()))
    if FC.Shopping then
        local numItems = 0
        local lists = FC.Shopping.Store().lists
        for _, list in ipairs(lists) do
            numItems = numItems + #list.items
        end
        FC.Chat(FC.Fmt("shopping lists: %d, holding %d furnishing(s)", #lists, numItems))
    end
    FC.Chat(FC.Fmt("guild trader: %s", FC.Trader and FC.Trader.StateText() or "module missing"))
    FC.Chat(FC.Fmt("settings: %s", FC.Settings and FC.Settings.StateText() or "module missing"))
    if FC.Plans then
        local numPlans, plansSource = FC.Plans.Count()
        FC.Chat(FC.Fmt("plans: the %s names a plan for %d furnishing(s)", plansSource, numPlans))
    end
    FC.Chat(FC.Fmt("jump to search: %s", FC.Browse and FC.Browse.JumpToSearchState() or "module missing"))
    FC.Chat(FC.Fmt("built-in list: %s ids, version %s", tostring(FC.Seed and FC.Seed.count), tostring(FC.Seed and FC.Seed.version)))
    if type(catalog) == "table" then
        FC.Chat(FC.Fmt("catalog: %s furnishings from %s, built in %s ms over %s frames, stamp %s%s", tostring(catalog.total),
            catalog.source == "full" and "a full scan" or "the built-in list", tostring(catalog.scanMs), tostring(catalog.scanFrames), tostring(catalog.stamp),
            (FC.Scan and not FC.Scan.GetCatalog()) and " (out of date: rebuilt on the next open)" or ""))
    else
        FC.Chat("catalog: not built yet; /furn opens the catalog and builds it")
    end
    local saved = FC.Scan and FC.Scan.GetSavedProgress()
    if saved then
        local hasRoom, roomText = FC.Scan.FullScanRoom()
        FC.Chat(FC.Fmt("full scan paused at item id %s (%s found); /furn scan continues it%s", tostring(saved.nextId), tostring(saved.total), hasRoom and "" or (", but not in this session: " .. tostring(roomText))))
    end
    local progress = FC.Scan and FC.Scan.GetProgress()
    if progress then
        FC.Chat(FC.Fmt("%s running: %d%%, %d found", progress.kind == "full" and "full scan" or "seed pass", math.floor(progress.fraction * 100), progress.found))
    end
    local counters = {}
    for key, value in pairs(d.counters) do
        counters[#counters + 1] = key .. "=" .. tostring(value)
    end
    table.sort(counters)
    FC.Chat(FC.Fmt("counters: %s", #counters > 0 and table.concat(counters, " ") or "none"))
    local creationError = FC.Browse and FC.Browse.GetCreationError()
    if creationError then
        FC.Chat("screen error: " .. creationError)
    end
    FC.Chat(FC.Fmt("%d init error(s), %d runtime error(s)", #d.initErrors, #d.errors))
    for _, err in ipairs(d.initErrors) do
        FC.Chat("  init: " .. err)
    end
    for index = math.max(1, #d.errors - 4), #d.errors do
        FC.Chat("  error: " .. d.errors[index])
    end
end

local function Help()
    FC.Chat("/furn (open the catalog; also Furnishing Catalog in the main menu's Add-Ons list) | probe (preview test: opens the catalog, tries 7 links, about 12 s) | scan (walk every item id for furnishings and plans the built-in list lacks; uses memory the game holds on to, so it pauses itself before add-on memory runs short and takes several sessions) | reset (back to the built-in list) | status | debug | chat (debug lines to chat) | export | clear")
end

-- Registered at file scope so "/furn status" answers even if Initialize never runs.
local function HandleCommand(args)
    local command = string.lower(string.match(args or "", "^%s*(%S*)") or "")
    if command == "" or command == "open" then
        if not FC.Browse then
            FC.Chat("catalog screen module missing (file load failed); /furn status")
            return
        end
        FC.SafeCall("Open", FC.Browse.Open)
    elseif command == "probe" then
        if FC.Browse then
            FC.SafeCall("Probe", FC.Browse.Probe)
        end
    elseif command == "scan" then
        if FC.Browse then
            FC.SafeCall("FullScan", FC.Browse.FullScan)
        end
    elseif command == "reset" then
        if FC.Browse then
            FC.SafeCall("Reset", FC.Browse.Reset)
            FC.Chat("saved catalog dropped; the next open starts from the built-in list")
        end
    elseif command == "status" then
        FC.SafeCall("Status", Status)
    elseif command == "debug" then
        FC.state.savedVars.debug = not FC.state.savedVars.debug
        FC.Chat(FC.Fmt("debug mode %s (%s)", FC.state.savedVars.debug and "ON" or "OFF", FC.LoggerStateLine()))
    elseif command == "chat" then
        FC.state.savedVars.debugChat = not FC.state.savedVars.debugChat
        FC.Chat(FC.Fmt("debug lines to chat: %s", FC.state.savedVars.debugChat and "ON" or "OFF"))
    elseif command == "export" then
        FC.Export()
    elseif command == "clear" then
        local lib = rawget(_G, "LibConsoleLogger")
        if lib and lib.Clear then
            lib:Clear()
        end
        FC.Chat("log cleared")
    else
        Help()
    end
end

SLASH_COMMANDS["/furn"] = HandleCommand
SLASH_COMMANDS["/furnishings"] = HandleCommand
SLASH_COMMANDS["/furnishingcatalog"] = HandleCommand

local function Initialize()
    local d = FC.diagnostics
    if d.initialized then
        return
    end
    d.initialized = true

    local okSV, savedVars = pcall(ZO_SavedVars.NewAccountWide, ZO_SavedVars, FC.savedVarsName, FC.savedVarsVersion, nil, FC.state.savedVars)
    if okSV then
        FC.state.savedVars = savedVars
    else
        table.insert(d.initErrors, "savedVars: " .. tostring(savedVars))
    end
    for _, moduleName in ipairs({ "Seed", "ScanUtils", "Scan", "BrowseUtils", "ShoppingUtils", "PlanUtils", "Search", "Shopping", "Plans", "Trader", "Browse", "Settings" }) do
        if not FC[moduleName] then
            table.insert(d.initErrors, "module missing: " .. moduleName)
        end
    end

    -- Three readings split this add-on's load: its Lua files, then its saved variables and
    -- whatever else the client does before it reports the add-on loaded.
    FC.Log("loaded v%s (%d init errors); add-on pool at this add-on's first line %s MB, after its last line %s MB; now: %s", FC.version, #d.initErrors,
        d.poolAtFileStart and string.format("%.2f", d.poolAtFileStart) or "?", d.poolAtFileEnd and string.format("%.2f", d.poolAtFileEnd) or "?", FC.MemText())
    if FC.Trader then
        FC.SafeCall("TraderInitialize", FC.Trader.Initialize)
    end
    if FC.Settings then
        FC.SafeCall("SettingsInitialize", FC.Settings.Initialize)
        FC.Log("settings: %s", FC.Settings.StateText())
    end
    -- A marker left by the previous UI session: it was torn down while a pass was running.
    local marker = FC.Scan and FC.Scan.TakeInterruptedMarker()
    if marker then
        d.interrupted = marker
        FC.Log("previous session ended mid-%s at %s after %s frames, memory %s KB", tostring(marker.kind), tostring(marker.position), tostring(marker.frames),
            tostring(marker.memoryKb and math.floor(marker.memoryKb)))
        FC.Chat(FC.Fmt("the UI reloaded while the catalog was being %s (at %s). /furn export sends the details.", marker.kind == "full" and "scanned" or "prepared", tostring(marker.position)))
    end
    for _, err in ipairs(d.initErrors) do
        FC.Log("  initError: %s", err)
    end
    -- A broken install should be visible even without debug mode.
    if #d.initErrors > 0 then
        FC.Chat(FC.Fmt("v%s loaded with %d init error(s); /furn status for details", FC.version, #d.initErrors))
    end
end

EVENT_MANAGER:RegisterForEvent(FC.name .. "_Loaded", EVENT_ADD_ON_LOADED, function(_event, addonName)
    if addonName == FC.name then
        EVENT_MANAGER:UnregisterForEvent(FC.name .. "_Loaded", EVENT_ADD_ON_LOADED)
        Initialize()
    end
end)

-- Fallback in case EVENT_ADD_ON_LOADED never carries our manifest name on this platform.
EVENT_MANAGER:RegisterForEvent(FC.name .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
    EVENT_MANAGER:UnregisterForEvent(FC.name .. "_Activated", EVENT_PLAYER_ACTIVATED)
    if not FC.diagnostics.initialized then
        Initialize()
    end
    -- Every add-on has loaded by now: the pool figure here is the session's starting point.
    FC.Log("player activated: %s", FC.MemText())
end)

-- Debug mode: every Lua error from any addon or the base UI goes to the log (consoles show none
-- of them), so a broken screen comes with its stack trace in the export.
local luaErrors = 0
EVENT_MANAGER:RegisterForEvent(FC.name .. "_LuaError", EVENT_LUA_ERROR, function(_event, errorText, errorCode)
    if not FC.IsDebug() then
        return
    end
    luaErrors = luaErrors + 1
    FC.Count("luaErrors")
    if luaErrors <= 20 then
        local text = tostring(errorText)
        if #text > 900 then
            text = string.sub(text, 1, 900) .. " ..."
        end
        FC.Log("LUA ERROR #%d (code %s): %s", luaErrors, tostring(errorCode), text)
        FC.Log("  at that moment: %s", FC.MemText())
    end
end)

-- Last line of this add-on's last file.
FC.diagnostics.poolAtFileEnd = FC.PoolMb()
