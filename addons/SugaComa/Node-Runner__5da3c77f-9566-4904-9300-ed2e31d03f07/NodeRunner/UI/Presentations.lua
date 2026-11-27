NODE_RUNNER = NODE_RUNNER or {}
local Project = NODE_RUNNER

Project.Presentations = Project.Presentations or {}
local Presentations = Project.Presentations

local function FormatSeconds(totalSeconds)
    totalSeconds = math.max(0, tonumber(totalSeconds) or 0)
    local hours = math.floor(totalSeconds / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local seconds = totalSeconds % 60
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, seconds)
    end
    return string.format("%02d:%02d", minutes, seconds)
end

local function FormatCountdownMs(ms)
    ms = math.max(0, tonumber(ms) or 0)
    return FormatSeconds(math.ceil(ms / 1000))
end

local function FormatElapsedMs(ms)
    ms = math.max(0, tonumber(ms) or 0)
    return FormatSeconds(math.floor(ms / 1000))
end

local function IsDragonWallShowing()
    if not SCENE_MANAGER or not SCENE_MANAGER.GetCurrentScene then return false end
    local scene = SCENE_MANAGER:GetCurrentScene()
    if not scene or not scene.GetName then return false end
    return scene:GetName() == "dragonWallGamepad"
end

local module = {
    id = Project.Config.moduleId,
    name = "Node Runner",
    version = Project.Config.version,
    apiVersion = 1,
    presentationType = "game",
    description = "A timed gathering survival game: keep the Harvest Clock alive, reach the next node, and decide what is worth risking along the way.",
    defaultActive = true,
    entryIndex = 1,
}

function Presentations:GetRecordPresentation()
    local data = Project.Game:EnsureRecords()
    local last = data.lastRun
    local lines = {
        "Games Played: " .. tostring(data.gamesPlayed or 0),
        "Best Survival: " .. FormatElapsedMs(data.bestTimeMs or 0),
        "Nodes Gathered: " .. tostring(data.totalNodes or 0),
        "Missed Gather Penalties: " .. tostring(data.totalGatherPenalties or 0),
        "",
        "RUN RULES",
        string.format("Harvest begins at %d minutes.", math.floor(Project.Config.startingSeconds / 60)),
        string.format("Harvest can never exceed %d minutes.", math.floor(Project.Config.maxHarvestSeconds / 60)),
        string.format("Gather any resource node within %d seconds.", Project.Config.gatherWindowSeconds),
        string.format("If GATHER reaches zero, lose %d seconds and it restarts.", Project.Config.missedGatherPenaltySeconds),
        "Every gathered node resets GATHER to 45 seconds.",
        "SURVIVED always measures real elapsed time.",
        "Every gathered node rolls exactly one roulette effect.",
        "+TIME 20%  •  -TIME 18%  •  FREEZE 14%",
        "SLOW 14%  •  SPEED 14%  •  NOTHING 20%",
        "Timed rate effects replace each other; immediate time effects do not.",
    }

    if last then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "LAST RUN"
        lines[#lines + 1] = "Survived: " .. FormatElapsedMs(last.durationMs)
        lines[#lines + 1] = "Nodes: " .. tostring(last.nodes or 0)
        lines[#lines + 1] = "Missed Gathers: " .. tostring(last.gatherPenalties or 0)
        lines[#lines + 1] = "Zone: " .. tostring(last.zone or "Unknown Zone")
        lines[#lines + 1] = tostring(last.reason or "Run complete")
    else
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Complete your first run to begin the record."
    end

    return {
        title = "NODE RUNNER",
        subtitle = "SURVIVAL RECORD",
        lines = lines,
    }
end

function Presentations:GetControlPresentation()
    local state = Project.State
    local lines = {}
    local subtitle = "READY"

    if state.phase == "idle" then
        lines = {
            "Press X to begin.",
            "",
            string.format("A %d-second countdown gives you time to leave Dragon Wall.", Project.Config.countdownSeconds),
            string.format("HARVEST begins at %d minutes.", math.floor(Project.Config.startingSeconds / 60)),
            string.format("GATHER begins at %d seconds.", Project.Config.gatherWindowSeconds),
            "Gather any resource node to reset GATHER.",
            string.format("Miss a gather and HARVEST loses %d seconds.", Project.Config.missedGatherPenaltySeconds),
            "SURVIVED is your real run time and never changes speed.",
            "Every node rolls: time, freeze, slow, speed, loss or nothing.",
        }
    elseif state:IsCountdown() then
        local current = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds() or 0
        local remaining = math.max(0, (state.countdownEndsMs or current) - current)
        subtitle = "GET READY"
        lines = {
            "Countdown: " .. tostring(math.max(1, math.ceil(remaining / 1000))),
            "",
            "Close Dragon Wall and find a resource node.",
            "Square restarts. Triangle cancels.",
        }
    elseif state:IsRunning() then
        local current = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds()
            or (type(GetGameTimeMilliseconds) == "function" and GetGameTimeMilliseconds() or 0)
        subtitle = "HARVEST ACTIVE"
        lines = {
            "Harvest: " .. FormatCountdownMs(Project.Game:GetRemainingMs()),
            "Gather: " .. FormatCountdownMs(Project.Game:GetGatherRemainingMs(current)),
            "Survived: " .. FormatElapsedMs(Project.Game:GetElapsedMs(current)),
            "Nodes: " .. tostring(state.nodesGathered or 0),
            "Missed Gathers: " .. tostring(state.gatherPenalties or 0),
            "",
            tostring(state.lastEffectText or "The hunt is on."),
        }
        if state.lastItemName and state.lastItemName ~= "" then
            lines[#lines + 1] = tostring(state.lastItemName)
        end
    elseif state.phase == "finished" and state.lastResult then
        local result = state.lastResult
        subtitle = result.newBest and "NEW PERSONAL BEST" or "RUN COMPLETE"
        lines = {
            "Survival Time: " .. FormatElapsedMs(result.durationMs),
            "Nodes: " .. tostring(result.nodes or 0),
            "Missed Gathers: " .. tostring(result.gatherPenalties or 0),
            "Zone: " .. tostring(result.zone or "Unknown Zone"),
            "",
            tostring(result.reason or "Run complete"),
            "",
            "Press X for another run.",
        }
    end

    return {
        title = "NODE RUNNER",
        subtitle = subtitle,
        lines = lines,
    }
end

local function GetHistory()
    local data = Project.Game:EnsureRecords()
    return Project.Game:EnsureRunHistory(data)
end

function module:GetEntryCount()
    return 2 + #GetHistory()
end

function module:ChangeEntry(delta)
    self.entryIndex = ((self.entryIndex or 1) - 1 + delta) % self:GetEntryCount() + 1
    Project.State.entryIndex = self.entryIndex
    return true
end

function module:GetActions()
    local state = Project.State
    return {
        primary = {
            name = state.phase == "finished" and "New Run" or "Start Run",
            visible = function()
                return IsDragonWallShowing() and not Project.State:IsActive()
            end,
            enabled = function()
                return not Project.State:IsActive()
            end,
            callback = function()
                module.entryIndex = 2
                Project.State.entryIndex = 2
                return Project.Game:StartRun()
            end,
        },
        secondary = {
            name = "Restart Run",
            visible = function()
                return IsDragonWallShowing()
                    and (Project.State:IsActive() or Project.State.phase == "finished")
            end,
            callback = function()
                module.entryIndex = 2
                Project.State.entryIndex = 2
                return Project.Game:RestartRun()
            end,
        },
        tertiary = {
            name = "Cancel Run",
            visible = function()
                return IsDragonWallShowing() and Project.State:IsActive()
            end,
            callback = function()
                return Project.Game:CancelRun("Run cancelled.")
            end,
        },
    }
end

function module:GetPresentationData()
    if self.entryIndex == 1 then
        return Presentations:GetRecordPresentation()
    end
    if self.entryIndex == 2 then
        return Presentations:GetControlPresentation()
    end
    local history = GetHistory()
    local index = self.entryIndex - 2
    local run = history[index]
    if not run then
        self.entryIndex = 1
        return Presentations:GetRecordPresentation()
    end
    return {
        title = "NODE RUNNER",
        subtitle = "RUN HISTORY",
        entryIndex = index,
        entryCount = #history,
        lines = {
            "Survived: " .. FormatElapsedMs(run.durationMs),
            "Nodes: " .. tostring(run.nodes or 0),
            "Missed Gathers: " .. tostring(run.gatherPenalties or 0),
            "Zone: " .. tostring(run.zone or "Unknown Zone"),
            tostring(run.reason or "Run complete"),
        },
    }
end

function Presentations:Initialize()
    if not DragonWallReverb or type(DragonWallReverb.RegisterModule) ~= "function" then
        Project.Diagnostics:Warn("DragonWallReverb unavailable; Node Runner not registered")
        return
    end

    local ok, err = DragonWallReverb:RegisterModule(module)
    if not ok then
        Project.Diagnostics:Warn("Node Runner registration failed: " .. tostring(err))
        return
    end

    Project.Diagnostics:Log("Node Runner registered with Dragon Wall", true)
end

function Presentations:OnPlayerActivated()
    Project:NotifyChanged()
end

Project.Controller:RegisterModule("Presentations", Presentations)
