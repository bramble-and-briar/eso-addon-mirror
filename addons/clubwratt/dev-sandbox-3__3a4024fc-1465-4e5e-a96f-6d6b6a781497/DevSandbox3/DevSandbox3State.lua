-- DevSandbox3State.lua: Pure data initialization
-- Creates the initial state structure (defaults).

local DevSandbox3State = {}

---@return DevSandbox3SavedVars
function DevSandbox3State.CreateSavedVarsDefaults()
    return {
        nodes = {},
        filters = {},
        debug = false,
        extraPatterns = {},
        ignoredNames = {},
        recordUnknown = false,
        settings = {
            alertEnabled = true,
            alertFontSize = 48,
            alertAutoDismissSeconds = 0,
            alertSound = true,
            alertOnCandidates = false,
            showPlayerRadius = false,
            playerRadiusMeters = 200,
            trackCoverage = false,
            showCoverage = false,
            probeAllTypes = false,
        },
        activeAlert = nil,
        coverage = {},
    }
end

---@return DevSandbox3State
function DevSandbox3State.Create()
    return {
        savedVars = DevSandbox3State.CreateSavedVarsDefaults(),
        pinTypeId = nil,
        lastReticleName = nil,
        lastRecordTime = 0,
    }
end

DevSandbox3.State = DevSandbox3State
