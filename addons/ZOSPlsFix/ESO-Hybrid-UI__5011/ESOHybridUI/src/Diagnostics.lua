-- Logging, chat output, the mode-query tracer and the /esohybrid_dump snapshot.
-- ESOUI rule: no load-time chat spam. Anything that goes to chat is either an
-- error, explicitly requested by the user (slash command / button), or opt-in.

local ADDON = ESOHybridUI
local rt = ADDON.runtime

local function Join(...)
    local count = select("#", ...)
    if count == 1 then
        return tostring((...))
    end
    local parts = {}
    for index = 1, count do
        parts[index] = tostring((select(index, ...)))
    end
    return table.concat(parts, " ")
end

local function ToChat(text)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(text)
    elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage(text)
    elseif type(d) == "function" then
        d(text)
    end
end

-- Output the user asked for (slash commands, buttons). Always visible.
function ADDON:Say(...)
    ToChat("[ESO Hybrid UI] " .. Join(...))
end

local function CreateLogger()
    -- LibDebugLogger documents both LibDebugLogger("Tag") and LibDebugLogger.Create("Tag").
    if type(LibDebugLogger) ~= "table" and type(LibDebugLogger) ~= "function" then
        return nil
    end
    local ok, logger = pcall(LibDebugLogger, "ESOHybridUI")
    if ok and type(logger) == "table" then
        return logger
    end
    if type(LibDebugLogger) == "table" and type(LibDebugLogger.Create) == "function" then
        ok, logger = pcall(LibDebugLogger.Create, "ESOHybridUI")
        if ok and type(logger) == "table" then
            return logger
        end
    end
    return nil
end

function ADDON:InitializeDiagnostics()
    rt.logger = CreateLogger()
    rt.debugLoggingEnabled = self:GetSettings().debugLoggingEnabled == true
    if rt.logger and rt.debugLoggingEnabled then
        self:SetDebugLogging(true, true)
    end
end

local LEVEL_NAMES = { Debug = "DEBUG", Info = "INFO", Warn = "WARN", Error = "ERROR" }

local function Write(self, method, ...)
    local text = Join(...)
    local logger = rt.logger
    if logger and type(logger[method]) == "function" then
        -- Pass the text as an argument, never as the format string.
        if pcall(logger[method], logger, "%s", text) then
            return
        end
    end
    -- No LibDebugLogger: stay quiet unless it is an error or debug logging is on.
    if method == "Error" or rt.debugLoggingEnabled then
        ToChat("[ESO Hybrid UI][" .. LEVEL_NAMES[method] .. "] " .. text)
    end
end

function ADDON:LogDebug(...)
    if rt.debugLoggingEnabled then Write(self, "Debug", ...) end
end
function ADDON:LogInfo(...) Write(self, "Info", ...) end
function ADDON:LogWarn(...) Write(self, "Warn", ...) end
function ADDON:LogError(...) Write(self, "Error", ...) end

function ADDON:SetDebugLogging(enabled, silent)
    enabled = enabled == true
    rt.debugLoggingEnabled = enabled
    self:GetSettings().debugLoggingEnabled = enabled

    local logger = rt.logger
    if logger then
        local loggerLevel = type(LibDebugLogger) == "table" and LibDebugLogger.LOG_LEVEL_DEBUG or nil
        local level = enabled and loggerLevel or nil
        if type(logger.SetMinLevelOverride) == "function" then
            pcall(logger.SetMinLevelOverride, logger, level)
        end
        if type(logger.SetLogTracesOverride) == "function" then
            pcall(logger.SetLogTracesOverride, logger, enabled or nil)
        end
    end

    if not silent then
        self:Say(GetString(enabled and SI_ESOHYBRIDUI_DEBUG_ON or SI_ESOHYBRIDUI_DEBUG_OFF))
        if enabled and not logger then
            self:Say(GetString(SI_ESOHYBRIDUI_DEBUG_NEED_LIB))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Tracer: counts who asks IsInGamepadPreferredMode() and what we answered, so the
-- first in-game test produces data about which ESO code paths matter.
-- ---------------------------------------------------------------------------

local MAX_TRACE_KEYS = 400

local function NewTrace()
    return { counts = {}, keys = 0, total = 0, overflow = 0, scenes = {}, systemRoutes = {} }
end

function ADDON:TraceModeQuery(answer)
    local trace = rt.trace
    if not trace or not (debug and debug.traceback) then
        return
    end
    trace.total = trace.total + 1

    -- Level 3 skips traceback, this function and the override itself.
    local text = debug.traceback("", 3) or ""
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        if not line:find("^%s*stack traceback") then
            lines[#lines + 1] = (line:gsub("^%s+", ""))
            if #lines == 2 then break end
        end
    end
    local key = tostring(answer) .. " <- " .. (lines[1] or "?") .. " | " .. (lines[2] or "")

    local counts = trace.counts
    if counts[key] then
        counts[key] = counts[key] + 1
    elseif trace.keys < MAX_TRACE_KEYS then
        counts[key] = 1
        trace.keys = trace.keys + 1
    else
        trace.overflow = trace.overflow + 1
    end
end

-- Records every scene that was shown and the answer ESO got at that moment, so
-- unknown scene names (housing, photo mode, ...) can be read from /esohybrid_trace report.
function ADDON:TraceScene(name, answer)
    local trace = rt.trace
    if not trace or not name then
        return
    end
    local entry = trace.scenes[name]
    if not entry then
        entry = { count = 0 }
        trace.scenes[name] = entry
    end
    entry.count = entry.count + 1
    entry.answer = answer
end

function ADDON:TraceSystemRoute(method, systemName)
    local trace = rt.trace
    if not trace then
        return
    end
    local key = tostring(method) .. " / " .. tostring(systemName)
    trace.systemRoutes[key] = (trace.systemRoutes[key] or 0) + 1
end

function ADDON:SetTracing(enabled)
    rt.traceEnabled = enabled == true
    if rt.traceEnabled and not rt.trace then
        rt.trace = NewTrace()
    end
end

function ADDON:ReportTrace()
    local trace = rt.trace
    if not trace then
        self:Say("Tracer has no data. Use /esohybrid_trace on, open and close a few menus, then /esohybrid_trace report.")
        return
    end
    local rows = {}
    for key, count in pairs(trace.counts) do
        rows[#rows + 1] = { key = key, count = count }
    end
    table.sort(rows, function(a, b) return a.count > b.count end)

    self:Say(string.format("Tracer: %d queries, %d distinct callers%s.", trace.total, trace.keys,
        trace.overflow > 0 and (", " .. trace.overflow .. " not recorded") or ""))
    for index = 1, math.min(15, #rows) do
        self:Say(string.format("%d x %s", rows[index].count, rows[index].key))
    end

    local sceneNames = {}
    for name in pairs(trace.scenes or {}) do
        sceneNames[#sceneNames + 1] = name
    end
    table.sort(sceneNames)
    for _, name in ipairs(sceneNames) do
        local entry = trace.scenes[name]
        self:Say(string.format("scene %s: shown %d x, gamepad answer when shown = %s",
            name, entry.count, tostring(entry.answer)))
    end

    local routeRows = {}
    for key, count in pairs(trace.systemRoutes or {}) do
        routeRows[#routeRows + 1] = { key = key, count = count }
    end
    table.sort(routeRows, function(a, b) return a.count > b.count end)
    local printedRoutes = {}
    for index = 1, math.min(20, #routeRows) do
        local row = routeRows[index]
        self:Say(string.format("system route %d x %s", row.count, row.key))
        printedRoutes[row.key] = true
    end
    for _, row in ipairs(routeRows) do
        if not printedRoutes[row.key] and row.key:lower():find("bank", 1, true) then
            self:Say(string.format("bank-related system route %d x %s", row.count, row.key))
        end
    end
end

-- ---------------------------------------------------------------------------

function ADDON:DumpDiagnostics()
    local sm = SCENE_MANAGER
    local settings = self:GetSettings()
    local accountWide = self.savedVariablesAccountWide
        and self.savedVariablesAccountWide._esoHybridUseAccountWideSettings == true or false

    local mapShowing = (WORLD_MAP_SCENE and WORLD_MAP_SCENE:IsShowing())
        or (_G.GAMEPAD_WORLD_MAP_SCENE and _G.GAMEPAD_WORLD_MAP_SCENE:IsShowing()) or false

    local wheelInteracting = INTERACTIVE_WHEEL_MANAGER and INTERACTIVE_WHEEL_MANAGER.IsInteracting
        and INTERACTIVE_WHEEL_MANAGER:IsInteracting() or false

    local lines = {
        "===== DIAGNOSTIC SNAPSHOT =====",
        "Version " .. ADDON.VERSION .. " | API " .. tostring(GetAPIVersion()),
        "Mode: " .. tostring(settings.mode) .. " | menu policy: " .. tostring(settings.menuPolicy)
            .. " | account-wide profile: " .. tostring(accountWide),
        "Native gamepad preference: " .. tostring(self:IsNativeGamepadMode())
            .. " | effective gamepad UI now: " .. tostring(IsInGamepadPreferredMode()),
        "Scene: " .. tostring(sm and sm:GetCurrentSceneName())
            .. " | UI mode: " .. tostring(sm and sm:IsInUIMode())
            .. " | base scene: " .. tostring(sm and sm:IsShowingBaseScene())
            .. " | HUD scene: " .. tostring(sm and sm.GetHUDSceneName and sm:GetHUDSceneName())
            .. " | map showing: " .. tostring(mapShowing),
        "Depth native/keyboard: " .. rt.forceNativeModeDepth .. "/" .. rt.forceKeyboardWheelDepth
            .. " | lockpicking: " .. tostring(rt.isLockpicking),
        "Features: quickslotWheel=" .. tostring(settings.hybridQuickslotWheel)
            .. " actionBarGlyphs=" .. tostring(settings.hybridActionBarGlyphs),
        "Platform: dirty=" .. tostring(rt.platformDirty) .. " refreshing=" .. tostring(rt.isRefreshing)
            .. " wheelInteracting=" .. tostring(wheelInteracting),
        "HUD editor: " .. tostring(HUD_EDITOR_SCENE_KEYBOARD and HUD_EDITOR_SCENE_KEYBOARD:IsShowing() or false)
            .. " | editor layout: " .. tostring(HUD_EDITOR_SCENE_KEYBOARD and HUD_EDITOR_SCENE_KEYBOARD:IsShowing() and "keyboard" or "normal policy"),
        "Keyboard HUD active: " .. tostring(rt.hybrid and sm and sm:IsShowingBaseScene()
            and not IsInGamepadPreferredMode()),
        "Quickslot controller bridge active: " .. tostring(rt.utilityWheelLayerActive)
            .. " | bindings: inherited from ESO gamepad actions",
        "Override installed: " .. tostring(rt.modeOverrideInstalled)
            .. " | still ours: " .. tostring(_G.IsInGamepadPreferredMode == rt.overrideFunction),
    }

    local installed = {}
    for name, ok in pairs(rt.installed) do
        installed[#installed + 1] = name .. "=" .. tostring(ok)
    end
    table.sort(installed)
    lines[#lines + 1] = "Hooks: " .. (#installed > 0 and table.concat(installed, " ") or "none")
    lines[#lines + 1] = "Libraries: LibAddonMenu2=" .. type(LibAddonMenu2)
        .. " LibGamepadOptions=" .. type(LibGamepadOptions)
        .. " LibDebugLogger=" .. type(LibDebugLogger)
    lines[#lines + 1] = "===== END ====="

    for _, line in ipairs(lines) do
        self:Say(line)
        self:LogInfo(line)
    end
end

function ADDON:RegisterDiagnosticCommands()
    SLASH_COMMANDS["/esohybrid_debug"] = function(argument)
        local value = string.lower(tostring(argument or "")):match("^%s*(.-)%s*$")
        if value == "on" then
            ADDON:SetDebugLogging(true)
        elseif value == "off" then
            ADDON:SetDebugLogging(false)
        else
            ADDON:SetDebugLogging(not rt.debugLoggingEnabled)
        end
    end

    SLASH_COMMANDS["/esohybrid_dump"] = function()
        ADDON:DumpDiagnostics()
    end

    SLASH_COMMANDS["/esohybrid_trace"] = function(argument)
        local value = string.lower(tostring(argument or "")):match("^%s*(.-)%s*$")
        if value == "on" then
            ADDON:SetTracing(true)
            ADDON:Say("Tracer on. Open and close the bank, use a few bank actions, then /esohybrid_trace report.")
        elseif value == "off" then
            ADDON:SetTracing(false)
            ADDON:Say("Tracer off (data kept until /esohybrid_trace reset).")
        elseif value == "reset" then
            rt.trace = rt.traceEnabled and NewTrace() or nil
            ADDON:Say("Tracer data cleared.")
        else
            ADDON:ReportTrace()
        end
    end
end
