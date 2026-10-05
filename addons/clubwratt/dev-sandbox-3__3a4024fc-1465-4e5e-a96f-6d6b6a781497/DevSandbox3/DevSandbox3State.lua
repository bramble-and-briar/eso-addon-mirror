-- DevSandbox3State.lua: Pure data initialization
-- Creates the initial state structure (defaults).

local DevSandbox3State = {}

-- Bump when a default changes and existing SavedVars should be forced onto the new value.
-- 2 (0.8.0): logEmptySlots shipped ON in 0.7.0 and stuck in everyone's SavedVars after 0.7.1 flipped the default.
DevSandbox3State.MIGRATION = 2

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
            showEmptySlots = true,
            showExpectedSlots = false,
            logEmptySlots = false,
            alertOnEmptySlots = false,
            emptyByPinCount = true,
            emptySlotTtlMinutes = 180,
            showEmptySlotsOutOfRange = false,
            showWorldMarkers = true,
            showCompassMarkers = true,
            markMissingSlotsInWorld = true,
            markSpawnsInWorld = true,
            worldMarkerRangeM = 200,
            worldMarkerSizeM = 0.35,
            worldMarkerConstantSize = true,
            mapPinSize = 8,
        },
        activeAlert = nil,
        coverage = {},
        emptySlots = {},
        emptySlotsVersion = nil,
        lootedSlots = {},
        settingsMigration = DevSandbox3State.MIGRATION,
    }
end

---Apply one-time fixes to SavedVars that ZO_SavedVars defaults cannot express (defaults only fill missing keys).
---@param savedVars DevSandbox3SavedVars
---@return boolean migrated
function DevSandbox3State.Migrate(savedVars)
    local from = savedVars.settingsMigration or 1
    if from >= DevSandbox3State.MIGRATION then return false end
    if from < 2 then
        savedVars.settings.logEmptySlots = false
        savedVars.settings.alertOnEmptySlots = false
    end
    savedVars.settingsMigration = DevSandbox3State.MIGRATION
    return true
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
