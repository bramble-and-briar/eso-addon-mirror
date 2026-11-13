-- SatchelExchangeUnboxActions.lua: The unboxer.
--
-- One queue of backpack slots, one frame-rate loop that opens them one after
-- another. Three things put a slot in the queue:
--
--   auto    a container just arrived in the backpack (loot, mail, a reward,
--           a purchase), filtered by the "open on arrival" setting
--   manual  UnboxAll: every container in the backpack (the LibRadialMenu
--           entry and the settings button)
--   vendor  the satchel a settled Satchel Exchange run bought; StoreActions
--           leaves its link in unbox.pendingItemLink and the next
--           interaction-end event starts waiting for it
--
-- Hard-won timing rules shape the loop:
--
-- 1. A vendor's close events fire BEFORE the purchased satchel reaches the
--    backpack (the buy receipt precedes the inventory update from the
--    server), so the vendor path waits for the satchel to appear.
-- 2. At most ONE UseItem may be in flight. The server resolves the slot index
--    when the request arrives, and a container's contents can land in the
--    slot it just vacated -- a second in-flight UseItem on that slot would
--    use (and potentially bind) whatever random item is there now. So every
--    send is followed by a wait for its result (the slot holds a different
--    item instance, or one fewer of a stack), and the next target is checked
--    to be an openable container at the moment of its own send.
--    A use request can however be silently dropped (no error, no effect), so
--    a retry IS allowed once we are certain the request did nothing: the
--    exact same container -- matched by unique id and stack size -- must
--    still be sitting in the bag well past any realistic server round trip,
--    with the HUD still up. Three sends without effect and the container is
--    left alone; so is one whose use brought up some other window.
-- 3. The game silently drops UseItem while any scene other than the plain HUD
--    is up -- including the store scene still FADING OUT after the
--    interaction ends. GetInteractionType() goes back to INTERACTION_NONE
--    well before the scene finishes, so interaction state alone is a false
--    green light. Readiness therefore also requires SCENE_MANAGER to be on
--    hud/hudui.
--
-- The send fires the instant every readiness gate passes. A send held back
-- only by the item cooldown is retried the moment the cooldown ends; any
-- other BLOCKED attempt backs the retry delay off by 16ms (0, 16, 32, ...) up
-- to a 200ms ceiling -- so the happy path fires at ~0ms while a long wait (a
-- menu, a fight) costs five cheap polls a second. The HUD coming back and
-- combat ending reset the backoff, so the wait ends on the next frame. A
-- blocked queue never gives up: it opens once the player is back on the HUD.
--
-- Opening a container without the game's autoloot setting shows a loot window
-- instead of delivering the contents, so a persistent EVENT_LOOT_UPDATED
-- handler performs Take All (LootAll) for any loot window that appears within
-- a short window after our UseItem. The window is time-based rather than tied
-- to the use because the container can vanish from the bag before the loot
-- window opens. A loot window that Take All cannot empty (bag full, a unique
-- item already held, a currency at its cap) is closed and its container left
-- alone.
--
-- Every stage logs a "+Nms" timestamp (ms since the run started) for field
-- diagnosis (visible when LibConsoleLogger is installed; logging is optional
-- and silently off without it).

local BagUtils = SatchelExchange.BagUtils

local SatchelExchangeUnboxActions = {}

local PERSISTENT_NAMESPACE = "SatchelExchangeUnbox"
local LOOP_UPDATE_NAME = "SatchelExchangeUnboxLoop"
-- Loop cadence and backoff step; one frame at 60fps
local LOOP_INTERVAL_MS = 16
local BACKOFF_STEP_MS = 16
local MAX_ATTEMPT_INTERVAL_MS = 200
-- How long after our UseItem a loot window is assumed to be the container's
local LOOT_WATCH_WINDOW_MS = 5000
-- A use request with no visible effect after this long (plus the current
-- latency) is considered dropped
local USE_RETRY_TIMEOUT_MS = 1000
local MAX_SENDS_PER_CONTAINER = 3
-- A loot window still open this long after Take All holds something that
-- cannot be taken
local LOOT_STUCK_MS = 2000
-- A container that itself refuses use (while the player could use items) is
-- dropped from the queue after this long
local ITEM_BLOCK_GIVE_UP_MS = 30000
-- Block key of a UseItem call the game refused outright
local BLOCK_KEY_REJECTED = -1

local SOURCE_AUTO = "auto"
local SOURCE_MANUAL = "manual"
local SOURCE_VENDOR = "vendor"
local SOURCE_RANK = { [SOURCE_AUTO] = 1, [SOURCE_MANUAL] = 2, [SOURCE_VENDOR] = 3 }

local Log = SatchelExchange.Log

-- One readiness snapshot reused by every attempt, so a long blocked wait
-- allocates nothing.
---@type SatchelExchangeUseReadiness
local readiness = {}

---@return SatchelExchangeUnboxState
local function GetUnbox()
    return SatchelExchange.state.unbox
end

---@return SatchelExchangeSavedVars
local function GetSettings()
    return SatchelExchange.state.savedVars
end

---@param now integer
---@return integer
local function Elapsed(now)
    return now - GetUnbox().startedAtMs
end

---Make the next loop tick attempt a send (the wait that held it back is over)
local function ResetBackoff()
    local unbox = GetUnbox()
    unbox.attemptIntervalMs = 0
    unbox.nextAttemptAtMs = 0
end

---@param message string
local function Alert(message)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, message)
end

-- ---------------------------------------------------------------------------
-- Which containers
-- ---------------------------------------------------------------------------

---Lazy Writ Crafter opens writ reward boxes itself while its own "open
---containers" setting is on. Two addons reacting to the same arrival would
---put two UseItem requests in flight on one slot (rule 2), so those boxes are
---left to it. Turning that setting off in Lazy Writ Crafter hands them here.
---@param slotIndex integer
---@return boolean
local function IsLeftToWritCrafter(slotIndex)
    local writCrafter = _G["WritCreater"]
    if type(writCrafter) ~= "table" or type(writCrafter.boxNames) ~= "table"
        or type(writCrafter.GetSettings) ~= "function" then
        return false
    end
    local ok, writSettings = pcall(writCrafter.GetSettings, writCrafter)
    if not ok or type(writSettings) ~= "table" or not writSettings.lootContainerOnReceipt then
        return false
    end
    return writCrafter.boxNames[GetItemLinkName(GetItemLink(BAG_BACKPACK, slotIndex))] ~= nil
end

---Whether the slot holds a container this source may open, judged on what the
---slot holds right now (it is asked again at the moment of every send).
---@param slotIndex integer
---@param source string "auto" | "manual" | "vendor"
---@return boolean
local function IsEligible(slotIndex, source)
    local kind = BagUtils.GetContainerKind(slotIndex)
    if not kind then
        return false
    end

    -- The list is empty nearly always; skip the id lookup (a string per call) then.
    local skipped = GetUnbox().skipped
    if next(skipped) then
        local uniqueId = BagUtils.GetSlotSignature(slotIndex)
        if uniqueId ~= "" and skipped[uniqueId] then
            return false
        end
    end

    -- The satchel the player started a run on is opened whatever the filters say.
    if source == SOURCE_VENDOR then
        return true
    end

    local settings = GetSettings()
    if IsItemPlayerLocked(BAG_BACKPACK, slotIndex) then
        return false
    end
    if kind == "geode" and not settings.openGeodes then
        return false
    end
    if source == SOURCE_MANUAL then
        return true
    end

    -- Opening on arrival is opt-in: anything but the two "on" modes is off.
    local mode = settings.autoOpenMode
    if mode ~= "all" and mode ~= "bound" then
        return false
    end
    if mode == "bound" and not IsItemBound(BAG_BACKPACK, slotIndex) then
        return false
    end
    return not IsLeftToWritCrafter(slotIndex)
end

-- ---------------------------------------------------------------------------
-- The queue
-- ---------------------------------------------------------------------------

---@param slotIndex integer
local function RemoveFromQueue(slotIndex)
    local unbox = GetUnbox()
    local queue = unbox.queue
    for index = 1, #queue do
        if queue[index] == slotIndex then
            table.remove(queue, index)
            break
        end
    end
    unbox.queuedSource[slotIndex] = nil
end

---Queue a slot once; a stronger source for a slot already queued replaces the
---weaker one.
---@param slotIndex integer
---@param source string
---@param atFront boolean Open it before everything already queued
local function Enqueue(slotIndex, source, atFront)
    local unbox = GetUnbox()
    local existing = unbox.queuedSource[slotIndex]
    if existing then
        if SOURCE_RANK[existing] > SOURCE_RANK[source] then
            source = existing
        end
        if not atFront then
            unbox.queuedSource[slotIndex] = source
            return
        end
        RemoveFromQueue(slotIndex)
    end

    unbox.queuedSource[slotIndex] = source
    if atFront then
        table.insert(unbox.queue, 1, slotIndex)
    else
        unbox.queue[#unbox.queue + 1] = slotIndex
    end
end

---First queued slot that still holds a container its source may open; slots
---that no longer do are dropped on the way.
---@return integer|nil slotIndex
local function NextTarget()
    local unbox = GetUnbox()
    local queue = unbox.queue
    while queue[1] do
        local slotIndex = queue[1]
        if IsEligible(slotIndex, unbox.queuedSource[slotIndex]) then
            return slotIndex
        end
        table.remove(queue, 1)
        unbox.queuedSource[slotIndex] = nil
    end
    return nil
end

local function ClearQueue()
    local unbox = GetUnbox()
    ZO_ClearNumericallyIndexedTable(unbox.queue)
    ZO_ClearTable(unbox.queuedSource)
end

---Leave one container alone until the next manual run. Without a unique id
---the skip list cannot hold it, so its slot leaves the queue instead.
---@param inFlight SatchelExchangeUnboxInFlight
---@param reason string
---@param now integer
local function Skip(inFlight, reason, now)
    if inFlight.uniqueId ~= "" then
        GetUnbox().skipped[inFlight.uniqueId] = reason
    else
        RemoveFromQueue(inFlight.slotIndex)
    end
    Log(string.format("Unbox +%dms: leaving the container in slot %d alone: %s",
        Elapsed(now), inFlight.slotIndex, reason))
end

-- ---------------------------------------------------------------------------
-- The loop
-- ---------------------------------------------------------------------------

local function StopLoop()
    EVENT_MANAGER:UnregisterForUpdate(LOOP_UPDATE_NAME)
end

---@param now integer
local function FinishRun(now)
    local unbox = GetUnbox()
    StopLoop()
    unbox.active = false
    Log(string.format("Unbox +%dms: done, %d opened (%d blocked attempts)",
        Elapsed(now), unbox.openedCount, unbox.attemptCount))
    -- lootWatchUntilMs deliberately survives: the loot window can open after
    -- the container disappears from the bag (which ends the run).
end

---@param slotIndex integer
---@return boolean sent
local function TryUseItem(slotIndex)
    if IsProtectedFunction("UseItem") then
        return CallSecureProtected("UseItem", BAG_BACKPACK, slotIndex)
    end
    UseItem(BAG_BACKPACK, slotIndex)
    return true
end

---Use the container at slotIndex if every gate passes. One send in flight
---only (see rule 2 in the header). A blocked attempt returns a key that
---changes only when the set of blocking gates does, so the loop can log gate
---transitions without spamming; the shared `readiness` holds the detail.
---@param slotIndex integer
---@param now integer
---@return boolean sent
---@return integer|nil blockKey
local function AttemptUse(slotIndex, now)
    local unbox = GetUnbox()

    BagUtils.GetUseReadiness(slotIndex, readiness)
    if not BagUtils.IsReadyToUse(readiness) then
        return false, BagUtils.GetBlockKey(readiness)
    end

    local uniqueId, stack = BagUtils.GetSlotSignature(slotIndex)
    local itemId = GetItemId(BAG_BACKPACK, slotIndex)

    if not TryUseItem(slotIndex) then
        return false, BLOCK_KEY_REJECTED
    end

    local sends = 1
    if uniqueId ~= "" and unbox.resendUniqueId == uniqueId then
        sends = unbox.resendSends + 1
    end
    unbox.resendUniqueId = nil
    unbox.resendSends = 0

    unbox.inFlight = {
        slotIndex = slotIndex,
        itemId = itemId,
        uniqueId = uniqueId,
        stack = stack,
        sentAtMs = now,
        sends = sends,
        lootAllAtMs = nil,
    }
    unbox.lootWatchUntilMs = now + LOOT_WATCH_WINDOW_MS
    unbox.itemBlockSinceMs = 0
    unbox.lastBlockKey = nil
    return true, nil
end

---Settle the use in flight: opened, dropped, or stuck on its loot window.
---@param now integer
---@return boolean settled Nothing is in flight any more; the loop may send again
local function SettleInFlight(now)
    local unbox = GetUnbox()
    local inFlight = unbox.inFlight
    local slotIndex = inFlight.slotIndex

    local uniqueId, stack = BagUtils.GetSlotSignature(slotIndex)
    local opened = uniqueId ~= inFlight.uniqueId
        or stack < inFlight.stack
        or GetItemId(BAG_BACKPACK, slotIndex) ~= inFlight.itemId

    if IsLooting() then
        -- Take All is still landing -- or left something it cannot take.
        if not inFlight.lootAllAtMs or now - inFlight.lootAllAtMs < LOOT_STUCK_MS then
            return false
        end
        EndLooting()
        unbox.inFlight = nil
        if not opened then
            Skip(inFlight, "its contents could not all be taken", now)
        end
        if not FindFirstEmptySlotInBag(BAG_BACKPACK) then
            Log(string.format("Unbox +%dms: backpack full; stopping", Elapsed(now)))
            ClearQueue()
        end
        ResetBackoff()
        return true
    end

    if opened then
        unbox.inFlight = nil
        unbox.openedCount = unbox.openedCount + 1
        Log(string.format("Unbox +%dms: opened slot %d (%dms after the send)",
            Elapsed(now), slotIndex, now - inFlight.sentAtMs))
        ResetBackoff()
        return true
    end

    -- Rule 2's reliability half: the EXACT same container is still there with
    -- no loot window, long past a server round trip -- the request did nothing.
    if now - inFlight.sentAtMs < USE_RETRY_TIMEOUT_MS + GetLatency() then
        return false
    end

    unbox.inFlight = nil
    if not BagUtils.IsHudSceneShowing() then
        -- Not a loot window, yet the HUD is gone: the use may have opened a
        -- window of its own (a reward choice). Sending again would only
        -- reopen it, so this one waits for the player.
        Skip(inFlight, "another window came up after the UseItem", now)
    elseif inFlight.sends >= MAX_SENDS_PER_CONTAINER then
        Skip(inFlight, string.format("no response to %d UseItem requests", inFlight.sends), now)
    else
        Log(string.format("Unbox +%dms: no response %dms after UseItem; assuming it was dropped, retrying",
            Elapsed(now), now - inFlight.sentAtMs))
        unbox.resendUniqueId = inFlight.uniqueId
        unbox.resendSends = inFlight.sends
    end
    ResetBackoff()
    return true
end

---Vendor path: the bought satchel goes to the front of the queue once it
---lands in the backpack ("never seen" just means it has not arrived yet).
---@param now integer
local function ResolveExpectedSatchel(now)
    local unbox = GetUnbox()
    local itemId = unbox.expectItemId
    if not itemId then
        return
    end

    local slotIndex = BagUtils.FindItemInBackpack(itemId)
    if slotIndex then
        unbox.expectItemId = nil
        -- Pressing Talk again is the player retrying it; forget an earlier give-up.
        local uniqueId = BagUtils.GetSlotSignature(slotIndex)
        unbox.skipped[uniqueId] = nil
        Log(string.format("Unbox +%dms: satchel in bag (slot %d)", Elapsed(now), slotIndex))
        Enqueue(slotIndex, SOURCE_VENDOR, true)
    elseif now >= unbox.expectDeadlineMs then
        unbox.expectItemId = nil
        Log(string.format("Unbox +%dms: gave up: the satchel never arrived in the backpack", Elapsed(now)))
    end
end

---The head of the queue itself refuses use while the player could use items:
---let the rest of the queue go first, and drop it if it never comes round.
---@param slotIndex integer
---@param now integer
local function StepAsideBlockedItem(slotIndex, now)
    local unbox = GetUnbox()
    if unbox.itemBlockSinceMs == 0 then
        unbox.itemBlockSinceMs = now
    end
    if now - unbox.itemBlockSinceMs >= ITEM_BLOCK_GIVE_UP_MS then
        Log(string.format("Unbox +%dms: slot %d cannot be used; dropping it from the queue", Elapsed(now), slotIndex))
        RemoveFromQueue(slotIndex)
        return
    end
    local queue = unbox.queue
    if #queue > 1 and queue[1] == slotIndex then
        table.remove(queue, 1)
        queue[#queue + 1] = slotIndex
    end
end

---A send attempt was blocked: schedule the next one and log a changed reason.
---@param slotIndex integer
---@param blockKey integer
---@param now integer
local function OnAttemptBlocked(slotIndex, blockKey, now)
    local unbox = GetUnbox()
    unbox.attemptCount = unbox.attemptCount + 1

    local rejected = blockKey == BLOCK_KEY_REJECTED
    if not rejected and BagUtils.IsBlockedByCooldownOnly(readiness) then
        -- The one gate with a known end: go the moment it lifts.
        unbox.nextAttemptAtMs = now + readiness.cooldownRemainMs
    else
        unbox.attemptIntervalMs = math.min(unbox.attemptIntervalMs + BACKOFF_STEP_MS, MAX_ATTEMPT_INTERVAL_MS)
        unbox.nextAttemptAtMs = now + unbox.attemptIntervalMs
    end

    if not rejected and BagUtils.IsBlockedByItem(readiness) then
        StepAsideBlockedItem(slotIndex, now)
    else
        unbox.itemBlockSinceMs = 0
    end

    if blockKey ~= unbox.lastBlockKey then
        unbox.lastBlockKey = blockKey
        Log(string.format("Unbox +%dms: blocked (slot %d, attempt %d, next try in %dms): %s",
            Elapsed(now), slotIndex, unbox.attemptCount, unbox.nextAttemptAtMs - now,
            rejected and "UseItem was rejected (in combat?)" or BagUtils.FormatUseReadiness(readiness)))
    end
end

---The single per-frame driver: settles the use in flight, waits for a bought
---satchel, picks the next container, and sends with backoff.
local function Loop()
    local unbox = GetUnbox()
    if not unbox.active then
        StopLoop()
        return
    end

    local now = GetGameTimeMilliseconds()

    if unbox.inFlight and not SettleInFlight(now) then
        return
    end

    ResolveExpectedSatchel(now)

    if now < unbox.nextAttemptAtMs then
        return
    end

    local slotIndex = NextTarget()
    if not slotIndex then
        if not unbox.expectItemId then
            FinishRun(now)
        end
        return
    end

    local sent, blockKey = AttemptUse(slotIndex, now)
    if sent then
        Log(string.format("Unbox +%dms: UseItem sent (slot %d, %d blocked attempts)",
            Elapsed(now), slotIndex, unbox.attemptCount))
        return
    end
    OnAttemptBlocked(slotIndex, blockKey, now)
end

---Start a run if none is going; a run lasts until the queue is empty.
local function StartLoop()
    local unbox = GetUnbox()
    if unbox.active then
        return
    end

    unbox.active = true
    unbox.startedAtMs = GetGameTimeMilliseconds()
    unbox.openedCount = 0
    unbox.attemptCount = 0
    unbox.itemBlockSinceMs = 0
    unbox.lastBlockKey = nil
    ResetBackoff()

    Log("Unbox +0ms: run started")
    EVENT_MANAGER:RegisterForUpdate(LOOP_UPDATE_NAME, LOOP_INTERVAL_MS, Loop)
end

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

---auto: a new item reached the backpack.
local function OnSlotUpdated(_eventId, bagId, slotIndex, isNewItem)
    if bagId ~= BAG_BACKPACK or not isNewItem then
        return
    end
    local settings = GetSettings()
    if not settings.enabled or settings.autoOpenMode == "off" then
        return
    end
    if not IsEligible(slotIndex, SOURCE_AUTO) then
        return
    end
    Enqueue(slotIndex, SOURCE_AUTO, false)
    StartLoop()
end

---vendor: start waiting for the satchel StoreActions queued
---(unbox.pendingItemLink), if any. The pending link -- set only when a
---settled run left a satchel to open -- is what tells a vendor exit from every
---other interaction-end event (closing a loot window emits one too).
local function OnInteractionEnded()
    local unbox = GetUnbox()
    local settings = GetSettings()
    local now = GetGameTimeMilliseconds()

    -- Whatever was waiting on this interaction can go on the next frame.
    ResetBackoff()

    -- EVENT_CHATTER_END and EVENT_CLOSE_STORE both fire on a vendor exit; the
    -- first starts the wait, later ones just refresh its deadline.
    if unbox.expectItemId then
        unbox.expectDeadlineMs = now + settings.unboxTimeoutMs
    end

    local pendingItemLink = unbox.pendingItemLink
    if not pendingItemLink or not settings.enabled or not settings.autoUnbox then
        return
    end
    unbox.pendingItemLink = nil

    -- Deliberately no "is the satchel in the bag" gate: on the buying visit
    -- the close events fire before the satchel lands (rule 1 in the header),
    -- so the loop waits for it to appear instead.
    unbox.expectItemId = GetItemLinkItemId(pendingItemLink)
    unbox.expectDeadlineMs = now + settings.unboxTimeoutMs
    StartLoop()
    Log(string.format("Unbox +%dms: waiting for the bought satchel (item %d, give up after %dms)",
        Elapsed(now), unbox.expectItemId, settings.unboxTimeoutMs))
end

---manual: open every container in the backpack. Clears the list of containers
---given up on, closes whatever menu is up, and reports the count on screen.
---@return integer count Containers queued (a stack counts each one in it)
function SatchelExchangeUnboxActions.UnboxAll()
    if not GetSettings().enabled then
        Alert("Satchel Exchange is turned off in its settings")
        return 0
    end

    local unbox = GetUnbox()
    ZO_ClearTable(unbox.skipped)

    local count = 0
    for slotIndex in ZO_IterateBagSlots(BAG_BACKPACK) do
        if IsEligible(slotIndex, SOURCE_MANUAL) then
            Enqueue(slotIndex, SOURCE_MANUAL, false)
            local _, stack = BagUtils.GetSlotSignature(slotIndex)
            count = count + stack
        end
    end

    if count == 0 then
        Alert("No containers to open")
        return 0
    end

    Alert(string.format("Opening %d container%s", count, count == 1 and "" or "s"))
    Log(string.format("Unbox: manual run, %d to open", count))
    SCENE_MANAGER:ShowBaseScene()
    StartLoop()
    ResetBackoff()
    return count
end

---Take All for the loot window our UseItem just opened. Time-window keyed
---(see header): loot windows inside the watch window are treated as ours.
---One LootAll per window: the event re-fires for every item the LootAll
---removes, so the watch is cleared after the first call.
local function OnLootUpdated()
    local unbox = GetUnbox()
    local now = GetGameTimeMilliseconds()
    if now > unbox.lootWatchUntilMs then
        return
    end
    unbox.lootWatchUntilMs = 0

    local inFlight = unbox.inFlight
    if inFlight then
        inFlight.lootAllAtMs = now
    end
    local lootTargetName = GetLootTargetInfo()
    Log(string.format("Unbox: loot window '%s'; taking all", tostring(lootTargetName)))
    LootAll(false)
end

---The HUD is (coming) back: whatever was waiting on a menu can go next frame.
local function OnHudStateChange(_oldState, newState)
    if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
        ResetBackoff()
    end
end

local function OnCombatState(_eventId, inCombat)
    if not inCombat then
        ResetBackoff()
    end
end

---Install the triggers; called once from Main
function SatchelExchangeUnboxActions.InitializePersistentHandlers()
    -- Both fire when leaving a vendor.
    EVENT_MANAGER:RegisterForEvent(PERSISTENT_NAMESPACE, EVENT_CHATTER_END, OnInteractionEnded)
    EVENT_MANAGER:RegisterForEvent(PERSISTENT_NAMESPACE, EVENT_CLOSE_STORE, OnInteractionEnded)
    EVENT_MANAGER:RegisterForEvent(PERSISTENT_NAMESPACE, EVENT_LOOT_UPDATED, OnLootUpdated)
    EVENT_MANAGER:RegisterForEvent(PERSISTENT_NAMESPACE, EVENT_PLAYER_COMBAT_STATE, OnCombatState)

    -- New items in the backpack only; the handler never runs for the rest.
    EVENT_MANAGER:RegisterForEvent(PERSISTENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdated)
    EVENT_MANAGER:AddFilterForEvent(PERSISTENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    EVENT_MANAGER:AddFilterForEvent(PERSISTENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
    EVENT_MANAGER:AddFilterForEvent(PERSISTENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_IS_NEW_ITEM, true)

    HUD_SCENE:RegisterCallback("StateChange", OnHudStateChange)
    HUD_UI_SCENE:RegisterCallback("StateChange", OnHudStateChange)
end

SatchelExchange.UnboxActions = SatchelExchangeUnboxActions
