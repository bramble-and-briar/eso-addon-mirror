-- SatchelExchangeStoreActions.lua: The buy engine.
--
-- One visit = one purchase: the satchel is unique, so a run buys exactly one,
-- arms the cross-interaction auto-resume, and exits the vendor interaction so
-- the unboxer (UnboxActions) can open the satchel -- item use is gated behind
-- CanInteractWithItem=false for the whole vendor interaction (confirmed in
-- testing). Persistent session handlers then automate the next visit
-- end-to-end: the player presses Talk (the only step an addon cannot perform
-- -- GameCameraInteractStart is private), the chatter handler auto-selects
-- the store dialogue option, the store-open handler re-buys, and the receipt
-- handler exits the interaction again.
--
-- Nothing here is specific to one vendor or satchel: the target is whatever
-- store entry the player started the run on (re-found by item link), the
-- dialogue option is matched by CHATTER_START_SHOP type, and pre-buy checks
-- handle alternate currencies (Tel Var, writ vouchers, ...) generically.

local StoreUtils = SatchelExchange.StoreUtils
local BagUtils = SatchelExchange.BagUtils
local ChatterUtils = SatchelExchange.ChatterUtils

local SatchelExchangeStoreActions = {}

local EVENT_NAMESPACE = "SatchelExchangeEngine"
local PERSISTENT_NAMESPACE = "SatchelExchangeSession"
local RESUME_START_DELAY_MS = 400

local Log = SatchelExchange.Log

---@return SatchelExchangeRunState
local function GetRun()
    return SatchelExchange.state.run
end

---@return SatchelExchangeSessionState
local function GetSession()
    return SatchelExchange.state.session
end

---@return SatchelExchangeSavedVars
local function GetSettings()
    return SatchelExchange.state.savedVars
end

local function DisarmSession()
    local session = GetSession()
    session.resumeItemLink = nil
    session.resumeArmedAtMs = 0
end

---Disarm with a user-facing log line (no-op when already disarmed)
---@param reason string
local function DisarmSessionWithLog(reason)
    if not GetSession().resumeItemLink then
        return
    end
    Log("Auto-exchange disarmed: " .. reason)
    DisarmSession()
end

---Arm the cross-interaction auto-resume for the current run's item
local function ArmSession()
    local session = GetSession()
    session.resumeItemLink = GetRun().itemLink
    session.resumeArmedAtMs = GetGameTimeMilliseconds()
end

---@return boolean isArmedAndFresh
local function IsSessionFresh()
    local session = GetSession()
    if not session.resumeItemLink then
        return false
    end
    if GetGameTimeMilliseconds() - session.resumeArmedAtMs > GetSettings().resumeWindowMs then
        Log("Auto-resume window expired")
        DisarmSession()
        return false
    end
    return true
end

---Advance the phase and invalidate any pending timers/watchdogs from prior phases
---@param phase string
local function SetPhase(phase)
    local run = GetRun()
    run.phase = phase
    run.token = run.token + 1
end

local function RefreshKeybindStrip()
    if not SCENE_MANAGER:IsShowing(GAMEPAD_STORE_SCENE_NAME) then
        return
    end
    local component = StoreUtils.GetBuyComponent()
    if component and component.keybindStripDescriptor then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(component.keybindStripDescriptor)
    end
end

---@param reason string
local function Stop(reason)
    local run = GetRun()
    if not run.active then
        return
    end

    -- Pending timers hold a reference to this table; flag it dead before swapping it out.
    run.active = false

    local elapsedSeconds = (GetGameTimeMilliseconds() - run.startedAtMs) / 1000
    Log(string.format("Run over (%s) after %.1fs", reason, elapsedSeconds))

    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_BUY_RECEIPT)
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_STORE_FAILURE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_CLOSE_STORE)

    SatchelExchange.state.run = SatchelExchange.State.CreateRun()
    RefreshKeybindStrip()
end

---Leave the store AND the underlying NPC interaction, mirroring what the base
---game does when a scene forces the player out (ingamescenemanager.lua).
local function ExitVendorInteraction()
    CloseStore()
    local interactionType = GetInteractionType()
    if interactionType ~= INTERACTION_NONE then
        EndInteraction(interactionType)
    end
end

---End the run with the auto-resume armed, then exit the interaction so the
---unboxer can fire; the next Talk re-runs the whole flow.
---@param reason string
local function SettleAndExit(reason)
    ArmSession()
    -- Queue exactly one wait-for-the-satchel for the interaction-end events.
    -- Gating on this (instead of "armed") stops phantom waits: the loot window
    -- our own unboxer opens also emits an interaction-end when it closes.
    SatchelExchange.state.unbox.pendingItemLink = GetRun().itemLink
    Stop(reason)

    if GetSettings().autoCloseStore then
        Log("Exiting the vendor; unboxer takes over, then Talk again to repeat")
        ExitVendorInteraction()
    end
end

---Abort if the current phase is still waiting when the watchdog fires
local function ArmWatchdog()
    local run = GetRun()
    local token = run.token
    local phase = run.phase
    zo_callLater(function()
        if run.active and run.token == token then
            Stop("timed out during phase '" .. phase .. "'")
        end
    end, GetSettings().watchdogMs)
end

---Whether this failure code means "blocked because a satchel is already held"
---@param buyStoreFailure integer
---@return boolean
local function IsHeldSatchelFailure(buyStoreFailure)
    return buyStoreFailure == STORE_FAILURE_ITEM_BUY_UNIQUE
        or buyStoreFailure == STORE_FAILURE_CANT_BUY_MULTIPLES
end

---Send the single BuyStoreItem for this visit (receipt/failure events finish the run)
local function BeginBuy()
    local run = GetRun()
    if not run.active then
        return
    end

    if not StoreUtils.IsVendorInteractionActive() then
        Stop("vendor interaction ended")
        return
    end

    local entryIndex = StoreUtils.FindEntryIndexByItemLink(run.itemLink)
    if not entryIndex then
        Stop("item no longer offered by this vendor")
        return
    end
    run.entryIndex = entryIndex

    -- Last line of defense against buying anything that is not a satchel
    -- (e.g. a style page); Start/StartAtEntryIndex already gate on this, but
    -- this check sits directly in front of every BuyStoreItem we ever send.
    if not StoreUtils.IsContainerItemLink(run.itemLink) then
        Stop("target item is not a container; refusing to buy")
        return
    end

    local diagnostics = StoreUtils.GetEntryDiagnostics(entryIndex)
    local blockReason = StoreUtils.GetBuyBlockReason(diagnostics)
    if blockReason then
        Log("Pre-buy check failed: " .. StoreUtils.FormatEntryDiagnostics(diagnostics))
        local heldSatchelBlock = (IsHeldSatchelFailure(diagnostics.buyStoreFailure) or diagnostics.maxBuyable < 1)
            and BagUtils.FindItemInBackpack(run.itemId) ~= nil
        if heldSatchelBlock then
            -- Unboxer hasn't fired yet; stay armed and get out of its way.
            SettleAndExit(blockReason)
        else
            Stop(blockReason)
        end
        return
    end

    SetPhase("buying")
    ArmWatchdog()
    BuyStoreItem(entryIndex, 1)
end

local function OnBuyReceipt(_eventId, entryName)
    local run = GetRun()
    if not run.active or run.phase ~= "buying" then
        return
    end

    local session = GetSession()
    session.buysThisSession = session.buysThisSession + 1
    Log(string.format("Bought '%s' (#%d this session)",
        zo_strformat(SI_TOOLTIP_ITEM_NAME, entryName), session.buysThisSession))

    SettleAndExit("bought one satchel")
end

local function OnStoreFailure(_eventId, reason, errorStringId, reasonParam1)
    local run = GetRun()
    if not run.active then
        return
    end

    local errorText = ZO_StoreManager_GetRequiredToBuyErrorText(reason, errorStringId, reasonParam1)
    local description = string.format("store failure %d: %s", reason, errorText or "?")
    local heldSatchelBlock = IsHeldSatchelFailure(reason)
        and BagUtils.FindItemInBackpack(run.itemId) ~= nil
    if heldSatchelBlock then
        SettleAndExit(description)
    else
        Stop(description)
    end
end

local function OnCloseStore()
    -- Manual exit mid-run: plain stop; the armed session (if any) stays as-is.
    Stop("store closed")
end

---@return boolean isRunning
function SatchelExchangeStoreActions.IsRunning()
    return GetRun().active
end

---@return boolean isArmed
function SatchelExchangeStoreActions.IsArmed()
    return GetSession().resumeItemLink ~= nil
end

---Start a single-buy run for a specific store entry
---@param entryIndex integer
function SatchelExchangeStoreActions.StartAtEntryIndex(entryIndex)
    local run = GetRun()
    if run.active then
        return
    end

    local diagnostics = StoreUtils.GetEntryDiagnostics(entryIndex)
    if not diagnostics.itemLink or diagnostics.itemLink == "" then
        Log("Cannot start: store entry " .. entryIndex .. " has no item link")
        return
    end
    if not StoreUtils.IsContainerItemLink(diagnostics.itemLink) then
        Log("Cannot start: " .. diagnostics.name .. " is not a satchel/container")
        return
    end

    run.active = true
    run.startedAtMs = GetGameTimeMilliseconds()
    run.entryIndex = entryIndex
    run.itemLink = diagnostics.itemLink
    run.itemId = GetItemLinkItemId(diagnostics.itemLink)
    run.entryName = diagnostics.name

    Log("Buying " .. StoreUtils.FormatEntryDiagnostics(diagnostics))

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_BUY_RECEIPT, OnBuyReceipt)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_STORE_FAILURE, OnStoreFailure)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_CLOSE_STORE, OnCloseStore)

    RefreshKeybindStrip()
    BeginBuy()
end

---Start a run targeting the entry currently hovered in the gamepad buy list
function SatchelExchangeStoreActions.Start()
    if GetRun().active then
        return
    end

    local entryData = StoreUtils.GetSelectedBuyEntry()
    if not entryData or not entryData.slotIndex then
        Log("Cannot start: no store entry selected")
        return
    end
    if entryData.entryType ~= STORE_ENTRY_TYPE_ITEM then
        Log("Cannot start: selected entry is not an inventory item (entryType=" .. tostring(entryData.entryType) .. ")")
        return
    end

    SatchelExchangeStoreActions.StartAtEntryIndex(entryData.slotIndex)
end

---User-initiated stop: also disarms the cross-interaction auto-resume
---@param reason string|nil
function SatchelExchangeStoreActions.Stop(reason)
    DisarmSessionWithLog(reason or "stopped by user")
    Stop(reason or "stopped by user")
end

---Disarm the auto-resume without touching any active run (settings page hook)
function SatchelExchangeStoreActions.Disarm()
    DisarmSessionWithLog("disarmed from settings")
end

-- ---------------------------------------------------------------------------
-- Persistent session handlers (installed once at addon load)
-- ---------------------------------------------------------------------------

---Armed session + NPC dialogue on screen: pick the "Store (...)" option so the
---player only has to press Talk. Dialogue without a store option (a different
---NPC) is simply ignored -- the arm stays live until its window expires.
local function OnChatterBeginPersistent()
    if not GetSettings().enabled or not IsSessionFresh() then
        return
    end

    local optionIndex = ChatterUtils.FindShopOptionIndex()
    if not optionIndex then
        return
    end

    -- Select synchronously (the AutoInteract example does the same on console);
    -- deferring risks another dialogue addon ending the chatter first.
    Log("Auto-opening the store from dialogue")
    SelectChatterOption(optionIndex)
end

---Armed session + store opened (via the chatter hook or manually): re-buy.
local function OnOpenStorePersistent()
    if not GetSettings().enabled or not IsSessionFresh() then
        return
    end

    -- Let the store data and UI finish initializing before restarting.
    zo_callLater(function()
        local resumeLink = GetSession().resumeItemLink
        if not resumeLink or GetRun().active or not StoreUtils.IsVendorInteractionActive() then
            return
        end

        local entryIndex = StoreUtils.FindEntryIndexByItemLink(resumeLink)
        if not entryIndex then
            -- A different vendor; stay armed for the right one.
            Log("This vendor does not sell the target item; auto-resume still armed")
            return
        end

        Log("Auto-resuming buy (press the toggle keybind to stop)")
        SatchelExchangeStoreActions.StartAtEntryIndex(entryIndex)
    end, RESUME_START_DELAY_MS)
end

---Install the cross-interaction handlers; called once from Main
function SatchelExchangeStoreActions.InitializeSessionHandlers()
    EVENT_MANAGER:RegisterForEvent(PERSISTENT_NAMESPACE, EVENT_CHATTER_BEGIN, OnChatterBeginPersistent)
    EVENT_MANAGER:RegisterForEvent(PERSISTENT_NAMESPACE, EVENT_OPEN_STORE, OnOpenStorePersistent)
end

SatchelExchange.StoreActions = SatchelExchangeStoreActions
