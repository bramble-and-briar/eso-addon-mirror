-- GuildNameTickerState.lua: Pure data initialization
-- Creates the initial state structure (defaults).

local GuildNameTickerState = {}

-- Number of ticker name fields shown in the settings panel.
GuildNameTickerState.TICKER_LINE_COUNT = 5

---@return GuildNameTickerRunState
function GuildNameTickerState.CreateRun()
    return {
        active = false,
        mode = "single",
        phase = "idle",
        token = 0,
        attemptId = 0,
        chunks = {},
        chunkIndex = 0,
        consecutiveFailures = 0,
        pendingName = nil,
        stalePendingName = nil,
        currentGuildId = nil,
        disbandingGuildId = nil,
        previousRepresentedGuildId = 0,
    }
end

---@return GuildNameTickerState
function GuildNameTickerState.Create()
    local lines = {}
    for i = 1, GuildNameTickerState.TICKER_LINE_COUNT do
        lines[i] = ""
    end
    return {
        savedVars = {
            quickName = "",
            prefix = "",
            suffix = "",
            lines = lines,
            intervalMs = 10000,
            lastCreatedGuildName = "",
            alliance = 0,
            description = "",
            motd = "",
            playtimeStartHour = 0,
            playtimeEndHour = 0,
        },
        run = GuildNameTickerState.CreateRun(),
    }
end

GuildNameTicker.State = GuildNameTickerState
