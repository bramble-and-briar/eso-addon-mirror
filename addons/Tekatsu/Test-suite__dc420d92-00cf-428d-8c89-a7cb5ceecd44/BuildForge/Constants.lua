BF = {}
BF.name = "BuildForge"
BF.displayName = "BuildForge"
BF.version = "0.1.0"
BF.savedVars = nil
BF.initialized = false
BF.DEBUG_ENABLED = false

BF.defaults = {
    savedVarsVersion = 1,
    builds = {},
    marketplaceBuilds = {},
    settings = {
        exportEndpoint = "https://publishers-cuisine-gadgets-concerned.trycloudflare.com/ingest",
        applyDelayMs = 350,
    },
}

BF.ui = {
    isOpen = false,
    sceneInitialized = false,
    selectedBuildIndex = 1,
    buildScrollOffset = 0,
    maxVisibleBuilds = 10,
    sortedBuilds = {},
    lastCompareSummary = nil,
}

BF.runtime = {
    missingGear = {},
    matchedGear = {},
    failedGear = {},
    exportQueue = nil,
}

function BF.Debug(msg)
    if BF.DEBUG_ENABLED and d then d("|c88CCFF[BuildForge Debug]|r " .. tostring(msg)) end
end

function BF.Chat(msg)
    if d then d("|c88CCFF[BuildForge]|r " .. tostring(msg)) end
end

function BF.FormatTimestamp(timestamp)
    if not timestamp or timestamp == 0 then return "Never" end
    local dateTable = os.date("*t", timestamp)
    return string.format("%02d/%02d/%02d %02d:%02d", dateTable.month, dateTable.day, dateTable.year % 100, dateTable.hour, dateTable.min)
end

function BF.TableCount(t)
    local count = 0
    if not t then return 0 end
    for _ in pairs(t) do count = count + 1 end
    return count
end

function BF.MakeBuildId()
    local classId = GetUnitClassId and GetUnitClassId("player") or 0
    return string.format("build-%d-%d", classId, GetTimeStamp())
end

function BF.GetPlayerName()
    return GetUnitName and GetUnitName("player") or "Unknown Character"
end

function BF.GetDisplayAuthor()
    return GetDisplayName and GetDisplayName() or ""
end
