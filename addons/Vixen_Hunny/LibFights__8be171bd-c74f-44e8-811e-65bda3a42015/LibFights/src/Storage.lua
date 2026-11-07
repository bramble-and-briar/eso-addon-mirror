--[[
    LibFights - Storage
    Settings defaults, SavedVariables (account wide), saving / loading / trimming fights.

    Console note: SavedVariables on console have a much smaller size budget than on PC,
    so console defaults keep fewer saved fights and never save raw events.
]]

local LF = LibFights
local Util = LF.Util
local Storage = {}
LF.Storage = Storage

local SV_NAME = "LibFightsSV"
local SV_VERSION = 1

Storage.DEFAULT_SETTINGS = {
    -- logging
    rawEvents = true,               -- keep a raw event log per fight (ring buffer)
    rawEventCap = 20000,
    groupMode = false,              -- also record group members' damage/healing (heavier)
    trackTargetEffects = true,      -- debuffs on bosses / your target
    trackPower = true,
    trackCasts = true,
    statSampleMs = 1000,
    combatEndGraceMs = 3000,
    fightTimeoutMs = 120000,
    minFightSeconds = 2,
    maxFightsInMemory = 25,
    deathRecapSize = 20,
    procMergeMs = 600,              -- hits of the same proc closer than this = one activation
    blockMitigation = 0.5,          -- used to estimate damage prevented by blocking
    buildDetail = "basic",          -- "basic" | "full"
    -- saving
    saveFights = false,
    maxSavedFights = 10,
    saveRawEvents = false,
    -- sets
    logAllSets = true,
    loggedSets = {},
    -- models
    modelsEnabled = true,
    persistModels = false,
    referenceResistance = 18200,
    referenceTargetPatterns = "dummy",
    ttkHalfLifeSec = 30,
    -- ui
    showHUD = false,
    hudLocked = false,
    hudX = nil,
    hudY = nil,
    hudUpdateMs = 500,              -- HUD refresh interval while a fight is running
    printFightSummary = false,
    debug = false,
}

local CONSOLE_OVERRIDES = {
    rawEventCap = 5000,
    maxFightsInMemory = 10,
    maxSavedFights = 3,
    saveRawEvents = false,
}

local function Defaults()
    local s = Util.ShallowCopy(Storage.DEFAULT_SETTINGS)
    s.loggedSets = {}
    if LF.isConsole then
        for k, v in pairs(CONSOLE_OVERRIDES) do s[k] = v end
    end
    return s
end

local fallbackSettings = nil

-- Always returns a usable settings table (defaults before SavedVariables are loaded)
function LF.GetSettings()
    if LF.settings then return LF.settings end
    fallbackSettings = fallbackSettings or Defaults()
    return fallbackSettings
end

function Storage.Init()
    local defaults = {
        settings = Defaults(),
        fights = {},
        nextFightId = 1,
        setAbilityRegistry = {},
        models = nil,
    }
    LF.sv = ZO_SavedVars:NewAccountWide(SV_NAME, SV_VERSION, nil, defaults)
    LF.settings = LF.sv.settings
    -- fill keys added in newer versions
    for k, v in pairs(Defaults()) do
        if LF.settings[k] == nil then LF.settings[k] = v end
    end
    Storage._restored = nil
end

function Storage.ResetSettings()
    if not LF.sv then return end
    LF.sv.settings = Defaults()
    LF.settings = LF.sv.settings
end

-- ---------------------------------------------------------------------------
-- Fights
-- ---------------------------------------------------------------------------
function Storage.SaveFight(fight)
    if not LF.sv then return false end
    local s = LF.GetSettings()
    local data = fight:ToData(s.saveRawEvents)
    local list = LF.sv.fights
    list[#list + 1] = data
    local cap = s.maxSavedFights or 10
    while #list > cap do table.remove(list, 1) end
    Storage._restored = nil
    return true
end

-- Saved fights restored as Fight objects (cached until the list changes)
function Storage.GetSavedFights()
    if not LF.sv then return {} end
    if Storage._restored and Storage._restoredCount == #LF.sv.fights then return Storage._restored end
    local out = {}
    for i, data in ipairs(LF.sv.fights) do
        out[i] = LF.Fight.FromData(data)
    end
    Storage._restored = out
    Storage._restoredCount = #out
    return out
end

function Storage.GetSavedFight(id)
    for _, f in ipairs(Storage.GetSavedFights()) do
        if f.id == id then return f end
    end
    return nil
end

function Storage.DeleteSavedFight(id)
    if not LF.sv then return false end
    for i = #LF.sv.fights, 1, -1 do
        if LF.sv.fights[i].id == id then
            table.remove(LF.sv.fights, i)
            Storage._restored = nil
            return true
        end
    end
    return false
end

function Storage.ClearSavedFights()
    if not LF.sv then return end
    LF.sv.fights = {}
    Storage._restored = nil
end

function Storage.GetSavedFightCount()
    return LF.sv and #LF.sv.fights or 0
end

LF.GetSavedFights = Storage.GetSavedFights
LF.DeleteSavedFight = Storage.DeleteSavedFight
LF.ClearSavedFights = Storage.ClearSavedFights
