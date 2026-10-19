-----------------------------------------------------------
-- Main
-- Entry point and initialization orchestration for Battle Scrolls
--
-- Handles EVENT_ADD_ON_LOADED and initializes all modules
-- in the correct order based on their dependencies.
--
-- Initialization order:
--   1. Infrastructure (binaryStorage, storage) - SavedVariables
--   2. Combat tracking (state, scribe, ticker) - Event subscriptions
--   3. Network (dpsShare, dpsSender) - Group communication
--   4. UI (dpsMeter, onboarding) - Display components
-----------------------------------------------------------

if not SemisPlaygroundCheckAccess() then
    return
end

BattleScrolls = BattleScrolls or {}
BattleScrolls.addonName = "ESOSemisDebugPlayground"

-- Both load and activation dispatches share the engine's execution budget
-- with other addons. Start the settling delay after those events are delivered.
local START_DELAY_MS = 2000

local function initialize()
    BattleScrolls.storage:Initialize()
    LibEffect.Yield():Await()

    -- Reset stall threshold to default if it's set too high (can cause issues)
    local currentThreshold = BattleScrolls.storage:GetAsyncStallThreshold()
    if currentThreshold > 30 then
        BattleScrolls.storage:SetAsyncStallThreshold(15) -- 15 is LibAsync default
    end

    BattleScrolls.state:Initialize()
    LibEffect.Yield():Await()
    BattleScrolls.healthRecovery:Initialize()
    BattleScrolls.shields:Initialize()
    BattleScrolls.trauma:Initialize()
    BattleScrolls.deathRecap:Initialize()
    BattleScrolls.ultimate:Initialize()
    BattleScrolls.crux:Initialize()
    BattleScrolls.resurrections:Initialize()
    BattleScrolls.effectsEvents:Initialize()
    BattleScrolls.effectsReconciler:Initialize()
    LibEffect.Yield():Await()
    BattleScrolls.scribe:Initialize()
    BattleScrolls.combatTicker:Initialize()
    BattleScrolls.setupCapture:Initialize()
    LibEffect.Yield():Await()
    BattleScrolls.prefsShare:Initialize()
    LibEffect.Yield():Await()
    BattleScrolls.dpsShare:Initialize()
    LibEffect.Yield():Await()
    BattleScrolls.encounterShare:Initialize()
    LibEffect.Yield():Await()
    BattleScrolls.setupShare:Initialize()
    LibEffect.Yield():Await()
    BattleScrolls.migration:Initialize()
    BattleScrolls.dpsSender:Initialize()
    LibEffect.Yield():Await()
    BattleScrolls.dpsMeter:Initialize()
    LibEffect.Yield():Await()
    BattleScrolls.onboarding:Initialize()
    BattleScrolls.characterStats:Initialize()
    -- Suppressing "Attempt to read past end of buffer" from LGB
    -- due to https://github.com/sirinsidiator/ESO-LibGroupBroadcast/issues/6
    -- Native ErrorFrame:Initialize creates this table; UI inheritance does
    -- not consistently expose it to LuaLS.
    ---@class BattleScrollsNativeErrorFrame
    ---@field suppressedErrors table<number, boolean>
    local errorFrame = ZO_ERROR_FRAME
    errorFrame.suppressedErrors[0xC078BBA0] = true
end

-- Create the handle during manifest loading: UI consumers can await it even
-- if their first scheduler update precedes the addon-loaded event dispatch.
BattleScrolls.startupFiber = LibEffect.Async(function()
    BattleScrolls.startup.addonLoaded:Await()
    BattleScrolls.startup.playerActivated:Await()
    LibEffect.Sleep(START_DELAY_MS):Await()
    initialize()
end):Run()
