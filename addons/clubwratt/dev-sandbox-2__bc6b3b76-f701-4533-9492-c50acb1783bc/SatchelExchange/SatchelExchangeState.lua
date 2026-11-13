-- SatchelExchangeState.lua: Pure data initialization
-- Creates the initial state structure (defaults).

local SatchelExchangeState = {}

---@return SatchelExchangeRunState
function SatchelExchangeState.CreateRun()
    return {
        active = false,
        phase = "idle",
        token = 0,
        entryIndex = nil,
        itemLink = nil,
        itemId = nil,
        entryName = nil,
        startedAtMs = 0,
    }
end

---@return SatchelExchangeState
function SatchelExchangeState.Create()
    return {
        savedVars = {
            enabled = true,
            watchdogMs = 4000,
            autoCloseStore = true,
            resumeWindowMs = 60000,
            autoUnbox = true,
            unboxTimeoutMs = 5000,
            -- Opt-in: opening every container a player receives is theirs to turn on.
            autoOpenMode = "off",
            openGeodes = false,
        },
        run = SatchelExchangeState.CreateRun(),
        session = {
            resumeItemLink = nil,
            resumeArmedAtMs = 0,
            buysThisSession = 0,
        },
        unbox = {
            active = false,
            pendingItemLink = nil,
            expectItemId = nil,
            expectDeadlineMs = 0,
            queue = {},
            queuedSource = {},
            skipped = {},
            inFlight = nil,
            resendSends = 0,
            resendUniqueId = nil,
            startedAtMs = 0,
            openedCount = 0,
            attemptIntervalMs = 0,
            nextAttemptAtMs = 0,
            attemptCount = 0,
            itemBlockSinceMs = 0,
            lastBlockKey = nil,
            lootWatchUntilMs = 0,
        },
    }
end

SatchelExchange.State = SatchelExchangeState
