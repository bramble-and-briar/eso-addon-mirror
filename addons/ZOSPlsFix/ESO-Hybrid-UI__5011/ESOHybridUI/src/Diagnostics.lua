-- Optional LibDebugLogger integration and in-game diagnostics.
-- LibDebugLogger is deliberately optional: the addon remains usable without it.

local ADDON = ESOHybridUI
local SM = SCENE_MANAGER

local function SafeCall(object, method, ...)
    if object and type(object[method]) == "function" then
        return pcall(object[method], object, ...)
    end
    return false
end

local function FallbackMessage(level, ...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    local message = "[ESO Hybrid UI][" .. tostring(level) .. "] " .. table.concat(parts, " ")
    if type(d) == "function" then
        d(message)
    elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage(message)
    end
end

function ADDON:InitializeDiagnostics()
    local logger
    if type(LibDebugLogger) == "function" then
        local ok, result = pcall(LibDebugLogger, "ESOHybridUI")
        if ok then logger = result end
    elseif type(LibDebugLogger) == "table" and type(LibDebugLogger.Create) == "function" then
        local ok, result = pcall(LibDebugLogger.Create, "ESOHybridUI")
        if ok then logger = result end
    end

    self.runtime.logger = logger
    self.runtime.debugLoggingEnabled = self:GetSettings().debugLoggingEnabled == true

    if logger and self.runtime.debugLoggingEnabled then
        self:SetDebugLogging(true, true)
    end

    if not logger then
        self:LogWarn("LibDebugLogger is not loaded; diagnostic messages will use ESO's debug output when available.")
    end
end

local function WriteLog(self, method, level, ...)
    local logger = self.runtime.logger
    if logger and type(logger[method]) == "function" then
        local ok = pcall(logger[method], logger, ...)
        if ok then return end
    end
    FallbackMessage(level, ...)
end

function ADDON:LogDebug(...)
    if self.runtime.debugLoggingEnabled then
        WriteLog(self, "Debug", "DEBUG", ...)
    end
end

function ADDON:LogInfo(...)
    WriteLog(self, "Info", "INFO", ...)
end

function ADDON:LogWarn(...)
    WriteLog(self, "Warn", "WARN", ...)
end

function ADDON:LogError(...)
    WriteLog(self, "Error", "ERROR", ...)
end

function ADDON:SetDebugLogging(enabled, silent)
    enabled = enabled == true
    self.runtime.debugLoggingEnabled = enabled

    local settings = self:GetSettings()
    settings.debugLoggingEnabled = enabled

    local logger = self.runtime.logger
    if logger then
        if enabled then
            local debugLevel = LibDebugLogger and LibDebugLogger.LOG_LEVEL_DEBUG
            SafeCall(logger, "SetMinLevelOverride", debugLevel)
            SafeCall(logger, "SetLogTracesOverride", true)
        else
            SafeCall(logger, "SetMinLevelOverride", nil)
            SafeCall(logger, "SetLogTracesOverride", nil)
        end
    end

    if not silent then
        if enabled then
            self:LogInfo("Diagnostic logging enabled.")
            if not logger then
                FallbackMessage("WARN", "Install LibDebugLogger and DebugLogViewer to save and inspect logs.")
            end
        else
            self:LogInfo("Diagnostic logging disabled.")
        end
    end
end

function ADDON:DumpDiagnostics()
    local settings = self:GetSettings()
    local runtime = self.runtime
    local physicalGamepad = tostring(self:IsNativeGamepadMode())
    local effectiveGamepadUI = tostring(IsInGamepadPreferredMode())
    local inUIMode = tostring(SM:IsInUIMode())
    local worldMapShowing = tostring(WORLD_MAP_SCENE:IsShowing())
    local currentScene = tostring(SM:GetCurrentSceneName())

    local accountWide = self.savedVariablesAccountWide
        and self.savedVariablesAccountWide._esoHybridUseAccountWideSettings == true
        or false
    local uiMode = settings.useHybridUI and "hybrid"
        or (settings.useControllerUI and "gamepad" or "keyboard")

    self:LogInfo("========== DIAGNOSTIC SNAPSHOT BEGIN ==========")
    self:LogInfo("Addon version:", self.VERSION, "API:", tostring(GetAPIVersion()))
    self:LogInfo("UI mode:", uiMode,
        "Controller prompts:", tostring(settings.useHybridUI or settings.useGamepadButtons == true),
        "Account-wide profile:", tostring(accountWide))
    self:LogInfo("Physical gamepad preference:", physicalGamepad,
        "Effective gamepad UI:", effectiveGamepadUI,
        "Scene manager UI mode:", inUIMode)
    self:LogInfo("Current scene:", currentScene,
        "World map showing:", worldMapShowing,
        "Native-mode override depth:", tostring(runtime.forceNativeModeDepth or 0))
    self:LogInfo("Runtime:", "initialized=" .. tostring(runtime.initialized),
        "modeOverride=" .. tostring(runtime.modeOverrideInstalled),
        "lockpicking=" .. tostring(runtime.isLockpicking))
    self:LogInfo("Hooks installed:",
        "globalPrompts=" .. tostring(runtime.globalPromptHooksInstalled),
        "promptDescriptors=" .. tostring(runtime.promptHooksInstalled),
        "deathPrompt=" .. tostring(runtime.deathPromptHookInstalled),
        "actionButtons=" .. tostring(runtime.actionButtonHooksInstalled),
        "dialogs=" .. tostring(runtime.dialogHooksInstalled),
        "worldMap=" .. tostring(runtime.hybridWorldMapHookInstalled or runtime.hybridMapCategoryHookInstalled),
        "mapScene=" .. tostring(runtime.hybridWorldMapHookInstalled),
        "mapCategory=" .. tostring(runtime.hybridMapCategoryHookInstalled),
        "utilityWheel=" .. tostring(runtime.utilityWheelHooksInstalled))
    self:LogInfo("Utility wheel:",
        "bridgeActive=" .. tostring(runtime.utilityWheelLayerActive),
        "defaultBindingsCopied=" .. tostring(runtime.utilityWheelDefaultsCopied),
        "retryHook=" .. tostring(runtime.utilityWheelRetryHook))
    self:LogInfo("Diagnostics:",
        "enabled=" .. tostring(runtime.debugLoggingEnabled),
        "LibDebugLoggerGlobal=" .. tostring(type(LibDebugLogger)),
        "loggerInstance=" .. tostring(type(runtime.logger)),
        "LibAddonMenu2=" .. tostring(type(LibAddonMenu2)))
    self:LogInfo("========== DIAGNOSTIC SNAPSHOT END ============")
end

function ADDON:RegisterDiagnosticCommands()
    SLASH_COMMANDS["/esohybrid_debug"] = function(argument)
        local value = string.lower(tostring(argument or "")):match("^%s*(.-)%s*$")
        if value == "on" then
            ADDON:SetDebugLogging(true)
        elseif value == "off" then
            ADDON:SetDebugLogging(false)
        else
            ADDON:SetDebugLogging(not ADDON.runtime.debugLoggingEnabled)
        end
    end

    SLASH_COMMANDS["/esohybrid_dump"] = function()
        ADDON:DumpDiagnostics()
    end
end
