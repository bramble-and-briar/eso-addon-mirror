-- LibConsoleLoggerState.lua: shared state + saved vars

LibConsoleLogger = LibConsoleLogger or {}
LibConsoleLogger.State = LibConsoleLogger.State or {}

local State = LibConsoleLogger.State

State.defaults = State.defaults or {
    enabled = false,
    chatEnabled = true,
    url = "",
    maxLines = 4000, -- buffer cap in lines; see LibConsoleLogger:SetMaxLines
}

State.runtimeEnabled = State.runtimeEnabled or false
State.savedVars = LibConsoleLogger.savedVars or State.savedVars or nil

-- Pending persisted settings (used before SavedVars are available)
LibConsoleLogger._pendingUrl = LibConsoleLogger._pendingUrl or nil
LibConsoleLogger._pendingEnabled = LibConsoleLogger._pendingEnabled or nil
LibConsoleLogger._pendingChatEnabled = LibConsoleLogger._pendingChatEnabled or nil
LibConsoleLogger._pendingMaxLines = LibConsoleLogger._pendingMaxLines or nil

LibConsoleLogger.savedVars = State.savedVars

---@return boolean
function LibConsoleLogger:_EnsureSavedVars()
    if State.savedVars ~= nil then
        LibConsoleLogger.savedVars = State.savedVars
        return true
    end
    if not ZO_SavedVars or not ZO_SavedVars.NewAccountWide then
        return false
    end

    State.savedVars = ZO_SavedVars:NewAccountWide(
        LibConsoleLogger.savedVarsName,
        LibConsoleLogger.savedVarsVersion,
        nil,
        State.defaults
    )
    LibConsoleLogger.savedVars = State.savedVars

    if LibConsoleLogger._pendingUrl ~= nil then
        State.savedVars.url = LibConsoleLogger._pendingUrl
        LibConsoleLogger._pendingUrl = nil
    end
    if LibConsoleLogger._pendingEnabled ~= nil then
        State.savedVars.enabled = LibConsoleLogger._pendingEnabled
        LibConsoleLogger._pendingEnabled = nil
    end
    if LibConsoleLogger._pendingChatEnabled ~= nil then
        State.savedVars.chatEnabled = LibConsoleLogger._pendingChatEnabled
        LibConsoleLogger._pendingChatEnabled = nil
    end
    if LibConsoleLogger._pendingMaxLines ~= nil then
        State.savedVars.maxLines = LibConsoleLogger._pendingMaxLines
        LibConsoleLogger._pendingMaxLines = nil
    end

    return true
end
