NODE_RUNNER = NODE_RUNNER or {}
local Project = NODE_RUNNER

Project.Config = {
    addonName = "NodeRunner",
    displayName = "Node Runner",
    version = "0.2.1",
    savedVariablesName = "NodeRunner_SV",
    savedVariablesVersion = 1,
    moduleId = "node_runner",

    countdownSeconds = 5,

    -- Standalone Node Runner timing model.
    startingSeconds = 180,
    maxHarvestSeconds = 1200,
    gatherWindowSeconds = 45,
    missedGatherPenaltySeconds = 30,
    dangerHarvestSeconds = 60,

    roulette = {
        addTimeWeight = 20,
        removeTimeWeight = 18,
        freezeWeight = 14,
        slowWeight = 14,
        speedWeight = 14,
        nothingWeight = 20,

        addTimeSeconds = { 30, 45 },
        removeTimeSeconds = { 10, 20, 30 },
        freezeSeconds = { 10, 15, 20 },
        slowSeconds = { 15, 20, 30 },
        speedSeconds = { 10, 15, 20 },
        slowRate = 0.5,
        speedRate = 2.0,
    },

    updateIntervalMs = 250,
    nodeDedupWindowMs = 900,
    harvestInteractionGraceMs = 2500,
    lootCorrelationWindowMs = 1800,
    duplicateInventoryWindowMs = 500,
}

Project.Defaults = {
    loaded = 0,
    settings = {
        diagnostics = false,
    },
    projectData = {
        gamesPlayed = 0,
        bestTimeMs = 0,
        totalNodes = 0,
        totalGatherPenalties = 0,
        lastRun = nil,
    },
}

function Project:NotifyChanged()
    if DragonWallReverb and type(DragonWallReverb.NotifyDataChanged) == "function" then
        DragonWallReverb:NotifyDataChanged(self.Config.moduleId)
    end
end
