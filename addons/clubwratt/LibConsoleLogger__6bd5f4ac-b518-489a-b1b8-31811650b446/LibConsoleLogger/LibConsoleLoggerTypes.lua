-- LibConsoleLoggerTypes.lua: core types and globals

---@class LibConsoleLogger
---@field name string
---@field version string
---@field savedVarsName string
---@field savedVarsVersion number
---@field savedVars table|nil
---@field WebExport table|nil
---@field Settings table|nil
---@field State table|nil
---@field Utils table|nil
---@field Log fun(self: LibConsoleLogger, ...: any)
---@field L fun(self: LibConsoleLogger, ...: any)
---@field Buffer fun(self: LibConsoleLogger, ...: any): (boolean, string|nil)
---@field DD fun(self: LibConsoleLogger, ...: any): (boolean, string|nil)
---@field DebugDeferred fun(self: LibConsoleLogger, ...: any): (boolean, string|nil)
---@field ExportNow fun(self: LibConsoleLogger, ...: any): (boolean, string|nil)
---@field D fun(self: LibConsoleLogger, ...: any): (boolean, string|nil)
---@field Debug fun(self: LibConsoleLogger, ...: any): (boolean, string|nil)
---@field Export fun(self: LibConsoleLogger): (boolean, string|nil)
---@field E fun(self: LibConsoleLogger): (boolean, string|nil)
---@field Clear fun(self: LibConsoleLogger): (boolean, number)
---@field C fun(self: LibConsoleLogger): (boolean, number)
---@field IsEnabled fun(self: LibConsoleLogger): boolean
---@field SetEnabled fun(self: LibConsoleLogger, enabled: boolean)
---@field Enable fun(self: LibConsoleLogger)
---@field Disable fun(self: LibConsoleLogger)
---@field IsChatEnabled fun(self: LibConsoleLogger): boolean
---@field SetChatEnabled fun(self: LibConsoleLogger, enabled: boolean)
---@field For fun(self: LibConsoleLogger, source: string): LibConsoleLoggerScoped
---@field LogDialog table|nil

LibConsoleLogger = LibConsoleLogger or {}
LibConsoleLogger.name = "LibConsoleLogger"
-- Keep in sync with ## Version in LibConsoleLogger.addon
LibConsoleLogger.version = "0.3.0"

LibConsoleLogger.savedVarsName = "LibConsoleLoggerSavedVars"
LibConsoleLogger.savedVarsVersion = 1

---@type table|nil
LibConsoleLogger.savedVars = LibConsoleLogger.savedVars or nil
