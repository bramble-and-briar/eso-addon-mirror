local addon = BureauOfMaterialWorth
addon.WithdrawDialog = addon.WithdrawDialog or {}

local WithdrawDialog = addon.WithdrawDialog
local private = addon.private

-- Hot-path / inventory globals cached to upvalues, same rationale as the other
-- modules: the withdrawal stepper touches these every tick across a multi-stack
-- run, and the capacity scan walks the whole backpack.
local GetString              = GetString
local stringformat           = string.format
local mathmin                = math.min
local mathmax                = math.max
local mathfloor              = math.floor
local tonumber               = tonumber
local CallSecureProtected    = CallSecureProtected
local GetSlotStackSize       = GetSlotStackSize
local GetItemId              = GetItemId
local GetNumBagFreeSlots     = GetNumBagFreeSlots
local FindFirstEmptySlotInBag = FindFirstEmptySlotInBag
local ZO_GetNextBagSlotIndex = ZO_GetNextBagSlotIndex

local BAG = BAG_VIRTUAL
local BAG_BACKPACK = BAG_BACKPACK

-- A classic stack is 200 items. Used only for the preset captions ("1 stack" =
-- 200) and the queue's conservative slots-needed estimate; the move engine does
-- NOT chunk by this -- one RequestMoveItem moves the full quantity and the game
-- spreads any overflow across slots itself. Declared once in the core as
-- private.STACK_SIZE (Valuation binds the same value), so the stack size cannot
-- drift between the queue estimate here and the stack count in the panel.
local STACK_SIZE = private.STACK_SIZE

-- Quantity presets offered as buttons. Raw item counts, ascending; the captions
-- for the >= one-stack entries are derived ("1 stack", "10 stacks", ...) so the
-- list is the single source of truth -- add a preset by adding a number.
local PRESETS = { 1, 10, 100, 200, 400, 2000, 4000 }

-- Default withdraw quantity proposed when a material is first opened or queued,
-- keyed by item quality (the same colour the game tints the name with). The idea:
-- cheap bulk mats default to a big grab, valuable mats to a small one, so a
-- careless click cannot dump a whole stack of something precious. The user can
-- always raise it (up to the available max) or type an exact value.
--
-- Keyed by ITEM_FUNCTIONAL_QUALITY_* (what Valuation passes as `quality`, from
-- GetItemLinkFunctionalQuality). Every ordinary tier proposes one full stack;
-- legendary (gold) mats -- kuta, rosin, chromium plating and friends -- propose a
-- single item, because they are the ones worth thousands each.
--
-- DEFAULT_QUANTITY_FALLBACK is deliberately the cautious end of that range, not
-- a stack: it covers a nil quality and any tier a future client adds, and
-- proposing too little is a harmless extra click while proposing too much can
-- dump a fortune into the backpack. Resolved through DefaultQuantityForQuality
-- so an unknown/nil quality is always safe.
local DEFAULT_QUANTITY_FALLBACK = 1
local DEFAULT_QUANTITY_BY_QUALITY = {
    [ITEM_FUNCTIONAL_QUALITY_TRASH]     = STACK_SIZE, -- grey
    [ITEM_FUNCTIONAL_QUALITY_NORMAL]    = STACK_SIZE, -- white
    [ITEM_FUNCTIONAL_QUALITY_MAGIC]     = STACK_SIZE, -- green
    [ITEM_FUNCTIONAL_QUALITY_ARCANE]    = STACK_SIZE, -- blue
    [ITEM_FUNCTIONAL_QUALITY_ARTIFACT]  = STACK_SIZE, -- purple
    [ITEM_FUNCTIONAL_QUALITY_LEGENDARY] = 1,          -- gold: precious, grab one
}

local function DefaultQuantityForQuality(quality)
    if quality == nil then
        return DEFAULT_QUANTITY_FALLBACK
    end
    return DEFAULT_QUANTITY_BY_QUALITY[quality] or DEFAULT_QUANTITY_FALLBACK
end

-- Palette (shared house style; see private.COLOR_* in BureauOfMaterialWorth.lua)
local COLOR_ACCENT = private.COLOR_ACCENT
local COLOR_MUTED  = private.COLOR_MUTED
local COLOR_WARN   = private.COLOR_WARN

-- Shared visual language (UI.lua). This window's chrome, type scale, spacing,
-- dividers and progress meters all come from there, so the withdraw window is
-- the same surface as the summary panel and the material table rather than a
-- third near-black with its own fonts.
local UI = private.UI
local FONT = UI.FONT
local METRIC = UI.METRIC

local Colorize = private.Colorize
local FormatGold = private.FormatGold

local LogDebug = private.LogDebug
local ChatInfo = private.ChatInfo

local function IsDetailedNotificationsEnabled()
    return private.GetNotificationMode and private.GetNotificationMode() == "detailed"
end

local function AnnounceWithdrawResult(moved, total, goldValue)
    if not IsDetailedNotificationsEnabled() then
        return
    end

    local message = moved < total and SI_BMW_MSG_WITHDRAW_PARTIAL or SI_BMW_MSG_WITHDRAW_RESULT
    ChatInfo(message, ZO_LocalizeDecimalNumber(moved), ZO_LocalizeDecimalNumber(total), goldValue)
end

-- Layout
-- ---------------------------------------------------------------------------
local POPUP_WIDTH   = 520
-- A free-floating window, so it takes the wider step of the shared spacing scale
-- (the narrow summary panel takes METRIC.PADDING), and its inter-block air and
-- button gutters come from the same scale -- the three windows breathe alike.
local PADDING       = METRIC.PADDING_WIDE
local TITLE_HEIGHT  = 30
local ICON_SIZE     = 32       -- the material icon beside the title
local CLOSE_SIZE    = 30       -- ZO_CloseButton's own footprint, reserved for it
local LINE          = 24       -- vertical rhythm for info lines
local SECTION_GAP   = METRIC.GAP_WIDE   -- space between blocks
local CONTROL_GAP   = METRIC.GAP        -- space between adjacent controls
local BUTTON_HEIGHT = 30
local PROGRESS_HEIGHT = 16
local QUEUE_ROW_HEIGHT = 30
local QUEUE_MAX_ROWS   = 6

-- The queue row template's text columns, by name suffix (see DetailWindow.xml).
-- The markup declares geometry only; this is what the row setup hands to
-- UI.ApplyRowFonts so the queue reads at the same size as the material table.
local QUEUE_ROW_COLUMNS = { "Name", "Value" }

-- Caption for a preset button: a plain number under one stack, otherwise an
-- "N stack(s)" label so 200 reads as "1 stack" and 4000 as "20 stacks".
local function PresetCaption(count)
    if count < STACK_SIZE then
        return ZO_LocalizeDecimalNumber(count)
    end
    local stacks = mathfloor(count / STACK_SIZE)
    local lastTwo = stacks % 100
    local lastDigit = stacks % 10
    local key
    if lastDigit == 1 and lastTwo ~= 11 then
        key = SI_BMW_WITHDRAW_PRESET_STACK
    elseif lastDigit >= 2 and lastDigit <= 4 and (lastTwo < 12 or lastTwo > 14) then
        key = SI_BMW_WITHDRAW_PRESET_STACKS_FEW
    else
        key = SI_BMW_WITHDRAW_PRESET_STACKS
    end
    return stringformat(GetString(key), stacks)
end

-- A free backpack slot not already reserved by this run, or nil when none is
-- left. Because a multi-item queue issues all its moves in one synchronous click
-- (before any of them have actually filled their slot), FindFirstEmptySlotInBag
-- would hand back the SAME first empty slot to every move and they would all
-- collide -- only the first lands. So each job claims a distinct slot here and
-- records it in `reserved`, mirroring CraftBagExtended's EmptySlotTracker. The
-- game still distributes a single move's overflow (>200) across further slots on
-- its own; we only need to hand each job its own starting slot.
local function FindFreeBackpackSlot(reserved)
    local slotIndex = FindFirstEmptySlotInBag(BAG_BACKPACK)
    while slotIndex do
        if not reserved[slotIndex] then
            return slotIndex
        end
        slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK, slotIndex)
        -- Skip ahead to the next genuinely empty slot. GetSlotStackSize returns
        -- nil (not 0) for an empty slot on some paths, so coerce before the
        -- comparison -- a bare `~= 0` treats nil as occupied and would walk
        -- straight past every free slot, making the run report "no room".
        while slotIndex and (GetSlotStackSize(BAG_BACKPACK, slotIndex) or 0) ~= 0 do
            slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK, slotIndex)
        end
    end
    return nil
end

-- The withdrawal engine can use one compatible partial stack before it starts
-- filling empty slots. Keep this selection aligned with
-- Valuation.GetBackpackCapacityFor, which exposes the same capacity in the UI.
local function FindPartialBackpackSlot(itemId, reserved)
    local slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK)
    while slotIndex do
        local stackSize = GetSlotStackSize(BAG_BACKPACK, slotIndex)
        if not reserved[slotIndex]
            and GetItemId(BAG_BACKPACK, slotIndex) == itemId
            and stackSize and stackSize > 0 and stackSize < STACK_SIZE then
            return slotIndex
        end
        slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK, slotIndex)
    end
    return nil
end

-- Shared withdrawal engine
-- ---------------------------------------------------------------------------
-- Both the single-material popup and the multi-material queue withdraw through
-- ONE engine. A run is a list of jobs:
--   jobs[i] = { itemId, slotIndex, qty }
-- The single popup builds a one-job list; the queue builds an N-job list.
--
-- IMPORTANT - why this is NOT a timer loop:
-- RequestMoveItem is a PROTECTED function. It must be called via
-- CallSecureProtected AND from a hardware-event callstack (a button click) -- it
-- does NOT work from a RegisterForUpdate timer or an event handler (their
-- callstacks are untrusted). So every move is issued synchronously, inside the
-- click handler that calls StartRun. One call per job moves that job's full
-- quantity; the engine spreads any overflow beyond 200 across backpack slots
-- itself, so there is no per-stack loop.
--
-- The arrival of the moved items is asynchronous, so the (honest) progress bar
-- is advanced by listening to EVENT_INVENTORY_SINGLE_SLOT_UPDATE on the backpack
-- (stack-count increases) until the requested total has landed, then the run
-- finishes. The listener is the only thing that outlives the click, and it is
-- self-cleaning: FinishRun unregisters it, as do Cancel / OnCraftBagHidden.
local MOVE_EVENT_NAME = addon.name .. "_WithdrawMoveWatch"
-- Safety timeout: if the expected items never fully arrive (e.g. a move was
-- partially rejected), end the run anyway so the UI never stays "in progress"
-- forever. Re-armed on every arrival; fires when arrivals go quiet.
-- Deliberately generous: this is a stall backstop, not a deadline. The old 2s
-- budget could expire before the server acknowledged the very first move on a
-- laggy connection or a large multi-job queue, which ended the run at 0 moved
-- and reported nothing withdrawn while the items were still on their way.
local WATCH_TIMEOUT_MS = 8000
local WATCH_TIMER_NAME = addon.name .. "_WithdrawWatchTimeout"

local isWithdrawing = false
local engineMoved = 0           -- items confirmed arrived in the backpack
local engineTotal = 0           -- items the run set out to move
local engineRequested = 0       -- items requested before jobs were validated
local engineWatchItemIds = nil  -- [itemId] = true for items this run is moving
local engineOnProgress = nil    -- callback(moved, total)
local engineOnFinish = nil      -- callback(moved, issued, requested) when the run ends

-- Call the protected RequestMoveItem safely. Guarded so a client where it is NOT
-- protected still works. Never bind RequestMoveItem to an upvalue -- merely
-- referencing the global at load throws "access a private function".
local function SecureRequestMoveItem(srcBag, srcSlot, destBag, destSlot, quantity)
    if IsProtectedFunction("RequestMoveItem") then
        CallSecureProtected("RequestMoveItem", srcBag, srcSlot, destBag, destSlot, quantity)
    else
        RequestMoveItem(srcBag, srcSlot, destBag, destSlot, quantity)
    end
end

local function StopWatching()
    EVENT_MANAGER:UnregisterForUpdate(WATCH_TIMER_NAME)
    EVENT_MANAGER:UnregisterForEvent(MOVE_EVENT_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
end

local function FinishRun()
    -- Idempotent: the quiet-timeout and the final arrival can both land in the
    -- same frame, and OnCraftBagHidden/Cancel may also call in. Without this
    -- guard the finish callback could fire twice and post two chat reports.
    if not isWithdrawing then
        StopWatching()
        return
    end

    StopWatching()
    isWithdrawing = false
    engineWatchItemIds = nil
    local moved, total, requested = mathmin(engineMoved, engineTotal), engineTotal, engineRequested
    local onFinish = engineOnFinish
    engineOnProgress = nil
    engineOnFinish = nil
    if onFinish then
        onFinish(moved, total, requested)
    end
end

-- Backpack slot-update handler: count stack-count increases for the items this
-- run is moving, advance the progress bar, and finish once the total has landed.
local function OnBackpackSlotUpdate(eventCode, bagId, slotIndex, isNewItem, soundCat, updateReason, stackCountChange)
    if bagId ~= BAG_BACKPACK or not stackCountChange or stackCountChange <= 0 then
        return
    end
    if not engineWatchItemIds then
        return
    end
    -- Only ordinary inventory movement counts. Without this, a reason-tagged
    -- update (durability/charge changes and similar) could be read as an arrival.
    if updateReason ~= nil and INVENTORY_UPDATE_REASON_DEFAULT ~= nil
        and updateReason ~= INVENTORY_UPDATE_REASON_DEFAULT then
        return
    end

    local itemId = GetItemId(BAG_BACKPACK, slotIndex)
    local outstanding = engineWatchItemIds[itemId]
    if not outstanding or outstanding <= 0 then
        return
    end

    -- Credit at most what this run still expects for that itemId. The handler
    -- cannot distinguish our withdrawal from any other gain of the same material
    -- (loot, a craft, a mail attachment, a purchase) that lands mid-run, so
    -- bounding the credit per item keeps a coincidental arrival from completing
    -- the run early and reporting a quantity that was never withdrawn.
    local credit = mathmin(stackCountChange, outstanding)
    engineWatchItemIds[itemId] = outstanding - credit
    engineMoved = mathmin(engineMoved + credit, engineTotal)
    if engineOnProgress then
        engineOnProgress(engineMoved, engineTotal)
    end

    if engineMoved >= engineTotal then
        FinishRun()
        return
    end

    -- Re-arm the quiet-timeout so a stalled move still ends the run.
    EVENT_MANAGER:UnregisterForUpdate(WATCH_TIMER_NAME)
    EVENT_MANAGER:RegisterForUpdate(WATCH_TIMER_NAME, WATCH_TIMEOUT_MS, FinishRun)
end

-- Issue a single job's protected move, claiming its backpack slots in `reserved`.
-- Returns the quantity actually issued (0 if the job was skipped). Skips when:
--   * the source slot no longer holds job.itemId (identity guard -- a deposit may
--     have reused the craft-bag slot for a different material since the job was
--     queued/clicked; withdrawing the wrong material would be worse than skipping);
--   * the source stack is empty; or
--   * there are not enough free backpack slots for the move's full overflow
--     footprint after using a compatible partial stack, which would risk a slot
--     collision with a later job -- see the reservation note below.
-- MUST run in the trusted click callstack (SecureRequestMoveItem is protected).
local function IssueJob(job, reserved, watchItemIds)
    if GetItemId(BAG, job.slotIndex) ~= job.itemId then
        return 0
    end

    local srcStack = GetSlotStackSize(BAG, job.slotIndex) or 0
    local moveQty = mathmin(job.qty, srcStack)
    if moveQty <= 0 then
        return 0
    end

    -- Prefer a matching partial stack. That makes the actual move agree with the
    -- popup's max-withdrawable figure, which includes this one stack's remaining
    -- room. Any overflow still needs distinct empty slots reserved up front.
    local destSlot = FindPartialBackpackSlot(job.itemId, reserved)
    local partialRoom = 0
    -- Remember the partial slot separately from destSlot: destSlot is reassigned
    -- to a claimed empty slot when no partial exists, so it cannot be used to
    -- decide what the rollback below has to release.
    local partialSlot = destSlot
    if destSlot then
        partialRoom = STACK_SIZE - (GetSlotStackSize(BAG_BACKPACK, destSlot) or STACK_SIZE)
        reserved[destSlot] = true
    end

    local overflowQty = mathmax(0, moveQty - partialRoom)
    local slotsNeeded = mathfloor((overflowQty + STACK_SIZE - 1) / STACK_SIZE)
    local claimed = {}
    for _ = 1, slotsNeeded do
        local slot = FindFreeBackpackSlot(reserved)
        if not slot then
            break
        end
        reserved[slot] = true
        claimed[#claimed + 1] = slot
        destSlot = destSlot or slot
    end

    -- Only issue if we secured the full footprint; a partial reservation risks the
    -- collision we are guarding against. Release the partial claim so a smaller
    -- later job can still use those slots, and skip this one (items stay in the bag).
    if not destSlot or #claimed < slotsNeeded then
        -- Release the partial stack whenever one was claimed. The old test keyed
        -- off `partialRoom > 0` and released `reserved[destSlot]`, so a claimed
        -- partial slot with zero room stayed reserved for the rest of the run and
        -- silently starved every later job of that slot.
        if partialSlot then
            reserved[partialSlot] = nil
        end
        for c = 1, #claimed do
            reserved[claimed[c]] = nil
        end
        return 0
    end

    -- Accumulate the outstanding quantity per material (several jobs can share an
    -- itemId across craft-bag slots) so the arrival handler can credit precisely
    -- what this run asked for and ignore anything beyond it.
    watchItemIds[job.itemId] = (watchItemIds[job.itemId] or 0) + moveQty
    SecureRequestMoveItem(BAG, job.slotIndex, BAG_BACKPACK, destSlot, moveQty)
    return moveQty
end

-- Begin a run. jobs is a list of { itemId, slotIndex, qty }; totalQty is the sum
-- (for the progress bar). MUST be called synchronously from a click handler so
-- the protected RequestMoveItem calls run in a trusted callstack.
-- onProgress(moved,total) drives the UI. onFinish receives the actual moved
-- count, issued count, and original requested count for an honest final report.
local function StartRun(jobs, totalQty, onProgress, onFinish)
    if isWithdrawing or totalQty <= 0 then
        return false
    end

    engineMoved = 0
    engineTotal = totalQty
    engineRequested = totalQty
    engineOnProgress = onProgress
    engineOnFinish = onFinish
    engineWatchItemIds = {}
    isWithdrawing = true

    if onProgress then
        onProgress(0, totalQty)
    end

    -- Watch backpack arrivals BEFORE issuing the moves, so we never miss an early
    -- slot event. Filtered to the backpack so craft-bag churn is ignored.
    EVENT_MANAGER:RegisterForEvent(MOVE_EVENT_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnBackpackSlotUpdate)
    EVENT_MANAGER:AddFilterForEvent(MOVE_EVENT_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    EVENT_MANAGER:RegisterForUpdate(WATCH_TIMER_NAME, WATCH_TIMEOUT_MS, FinishRun)

    -- Issue one protected move per job, synchronously, in this (trusted) click
    -- callstack. `reserved` tracks the backpack slots already claimed this run so
    -- the moves never target the same slot and collide (the slots have not actually
    -- filled yet at this point in the frame).
    local reserved = {}
    local issued = 0
    for i = 1, #jobs do
        issued = issued + IssueJob(jobs[i], reserved, engineWatchItemIds)
    end

    -- Nothing actually went out (no free slot / empty source): end immediately so
    -- the UI does not hang waiting for arrivals that will never come.
    if issued <= 0 then
        FinishRun()
        return false
    end

    -- Progress must track what was actually issued, not the requested total: if a
    -- job was skipped (no free slot) or its source stack shrank, engineMoved can
    -- never reach the requested totalQty, so the run would only ever end via the
    -- quiet-timeout with the bar stuck short of 100%. Re-baseline to `issued` so
    -- the bar reaches full and the run ends promptly on the last real arrival.
    engineTotal = issued
    if engineOnProgress then
        engineOnProgress(mathmin(engineMoved, engineTotal), engineTotal)
    end

    return true
end

-- ===========================================================================
-- Part A: single-material withdraw popup
-- ===========================================================================
local popup           -- top-level window
local popupTitle, popupIcon
local popupFreeLabel, popupMaxLabel, popupValueLabel
local popupQtyLabel, popupEditBg, popupEdit
local popupPresetButtons = {}
local popupQuantityButtons = {}
local popupMaxPresetButton
local popupConfirm, popupAddToQueue, popupCancel
local popupProgressBar, popupProgressLabel
local popupBatchSummaryLabel
local popupBaseHeight
local popupBatchBaseHeight
local queueSection
local queueList
local queueEmptyLabel
local queueSummaryLabel, queueStatusLabel
local queueWithdrawAll, queueClear
local queueProgressBar
local QUEUE_ROW_TYPE = 1

-- Current material under the popup. These fields persist because both the
-- single-item editor and the batch-mode header can be refreshed while open.
local curItemId, curSlotIndex, curUnitPrice, curPriced
local curName, curIcon, curQuality
local curMaterialData
local curRequested = 0
local curMax = 0
local suppressEditEvent = false  -- guards the editbox sanitizer against its own SetText

-- Queue data is independent from the currently selected popup material: adding a
-- new material changes the editor at the top but preserves quantities already in
-- the batch below.
local queue = {}
local queueByItemId = {}
local UpdateQueueSectionVisibility
local UpdatePopupMode

local function IsBatchMode()
    return #queue >= 2
end

local function GetQueueItemCount()
    local total = 0
    for i = 1, #queue do
        total = total + (queue[i].qty or 0)
    end
    return total
end

local function RenderSelectedHeader()
    if not curName then
        return
    end

    popupIcon:SetTexture(curIcon)
    popupTitle:SetText(Colorize(COLOR_ACCENT, stringformat(GetString(SI_BMW_WITHDRAW_TITLE),
        addon.Valuation.ColorizeMaterialName(curName, curQuality))))
end

UpdatePopupMode = function()
    local batchMode = IsBatchMode()

    popupIcon:SetHidden(batchMode)
    popupBatchSummaryLabel:SetHidden(not batchMode)
    popupFreeLabel:SetHidden(batchMode)
    popupMaxLabel:SetHidden(batchMode)
    popupValueLabel:SetHidden(batchMode)
    popupQtyLabel:SetHidden(batchMode)
    popupEditBg:SetHidden(batchMode)
    popupConfirm:SetHidden(batchMode)
    popupAddToQueue:SetHidden(batchMode)
    popupCancel:SetHidden(batchMode)

    for i = 1, #popupPresetButtons do
        popupPresetButtons[i]:SetHidden(batchMode)
    end
    if popupMaxPresetButton then
        popupMaxPresetButton:SetHidden(batchMode)
    end

    if batchMode then
        popupTitle:SetText(Colorize(COLOR_ACCENT, GetString(SI_BMW_WITHDRAW_BATCH_TITLE)))
        popupBatchSummaryLabel:SetText(Colorize(COLOR_MUTED,
            stringformat(GetString(SI_BMW_WITHDRAW_BATCH_SUMMARY), #queue,
                ZO_LocalizeDecimalNumber(GetQueueItemCount()))))
        UI.ShowMeter(popupProgressBar, false)
        popupProgressLabel:SetHidden(true)
    else
        RenderSelectedHeader()
    end
end

local function ComputeMax()
    local srcStack = GetSlotStackSize(BAG, curSlotIndex) or 0
    local backpackCap = addon.Valuation and addon.Valuation.GetBackpackCapacityFor(curItemId) or 0
    curMax = mathmax(0, mathmin(srcStack, backpackCap))
    return curMax
end

local function RenderPopup()
    popupFreeLabel:SetText(Colorize(COLOR_MUTED,
        stringformat(GetString(SI_BMW_WITHDRAW_FREE_COMPACT), GetNumBagFreeSlots(BAG_BACKPACK))))

    if curMax <= 0 then
        popupMaxLabel:SetText(Colorize(COLOR_WARN, GetString(SI_BMW_WITHDRAW_BACKPACK_FULL)))
    else
        popupMaxLabel:SetText(Colorize(COLOR_MUTED,
            stringformat(GetString(SI_BMW_WITHDRAW_MAX_COMPACT), ZO_LocalizeDecimalNumber(curMax))))
    end

    -- Total value of the working quantity, or a muted dash when unpriced.
    local valueText
    if curPriced and curUnitPrice and curUnitPrice > 0 then
        valueText = FormatGold(curUnitPrice * curRequested)
    else
        valueText = Colorize(COLOR_MUTED, GetString(SI_BMW_DETAIL_GROWTH_NEW))
    end
    popupValueLabel:SetText(Colorize(COLOR_MUTED,
        stringformat(GetString(SI_BMW_WITHDRAW_TOTAL_VALUE), valueText)))

    -- Confirm is only usable when there is something to move.
    local canWithdraw = not isWithdrawing and curRequested > 0 and curRequested <= curMax
    popupConfirm:SetEnabled(canWithdraw)
    popupAddToQueue:SetEnabled(not isWithdrawing and curMaterialData ~= nil)
    UI.PaintButton(popupConfirm)
    UI.PaintButton(popupAddToQueue)
    for index = 1, #popupPresetButtons do
        local button = popupPresetButtons[index]
        UI.SelectButton(button, curRequested > 0 and curRequested == button.bmwQuantity)
    end
    UI.SelectButton(popupMaxPresetButton, curMax > 0 and curRequested == curMax)
    popupQuantityButtons[1]:SetEnabled(not isWithdrawing and curRequested > 0)
    popupQuantityButtons[2]:SetEnabled(not isWithdrawing and curRequested < curMax)
end

local function SetRequested(qty)
    qty = tonumber(qty) or 0
    qty = mathmax(0, mathmin(qty, curMax))
    curRequested = qty

    -- A queued material can still be edited through the single-material view.
    -- Keep its queued quantity in sync so switching to batch mode preserves the
    -- value the player just selected.
    local queuedEntry = curItemId and queueByItemId[curItemId]
    if queuedEntry then
        queuedEntry.qty = qty
    end

    -- Reflect the clamped value back into the editbox without re-triggering the
    -- sanitizer (SetText fires OnTextChanged).
    suppressEditEvent = true
    popupEdit:SetText(qty > 0 and tostring(qty) or "")
    suppressEditEvent = false

    RenderPopup()
end

-- Point the compact editor at a material record. Queue entries deliberately use
-- the same fields as detail rows, so this keeps the title, price, available
-- capacity, and requested quantity in one consistent selection state.
local function SelectMaterial(materialData, requestedQty)
    curItemId = materialData.itemId
    curSlotIndex = materialData.slotIndex
    curUnitPrice = materialData.unitPrice
    curPriced = materialData.priced
    curMaterialData = materialData
    curName = materialData.name
    curIcon = materialData.icon
    curQuality = materialData.quality

    ComputeMax()
    SetRequested(requestedQty or DefaultQuantityForQuality(curQuality))
end

local function SetQuantityControlsEnabled(enabled)
    for i = 1, #popupPresetButtons do
        popupPresetButtons[i]:SetEnabled(enabled)
    end
    if popupMaxPresetButton then
        popupMaxPresetButton:SetEnabled(enabled)
    end
    popupEdit:SetEditEnabled(enabled)
    for index = 1, #popupQuantityButtons do
        popupQuantityButtons[index]:SetEnabled(enabled)
    end
end

local function OnPopupFinish(moved, total, requested)
    -- Protected moves cannot be revoked after the click. Keep the final observed
    -- result visible instead of implying that a Hide action cancelled the run.
    UI.ShowMeter(popupProgressBar, false)
    popupProgressLabel:SetText(Colorize(COLOR_MUTED,
        stringformat(GetString(SI_BMW_WITHDRAW_RESULT_LABEL), moved or 0, total or 0)))
    popupProgressLabel:SetHidden(false)
    SetQuantityControlsEnabled(true)
    popupCancel:SetEnabled(true)
    popupCancel:SetText(GetString(SI_BMW_WITHDRAW_CANCEL))

    ComputeMax()
    SetRequested(mathmin(curRequested, curMax))

    -- Value what actually arrived, never more than was asked for: `moved` is
    -- derived from inventory events, so clamping keeps a coincidental arrival of
    -- the same material from inflating the reported gold.
    local movedQty = mathmin(moved or 0, total or 0)
    local goldValue = (curPriced and curUnitPrice)
        and FormatGold(curUnitPrice * movedQty)
        or GetString(SI_BMW_MSG_VALUE_UNKNOWN)
    AnnounceWithdrawResult(movedQty, requested or total or 0, goldValue)
end

local function OnPopupProgress(moved, total)
    popupProgressBar:SetValue(total > 0 and moved / total or 0)
    popupProgressLabel:SetText(Colorize(COLOR_MUTED,
        stringformat(GetString(SI_BMW_WITHDRAW_PROGRESS), moved, total)))
end

function WithdrawDialog.Confirm()
    if isWithdrawing then
        return
    end
    ComputeMax()
    local qty = mathmin(curRequested, curMax)
    if qty <= 0 then
        RenderPopup()
        return
    end

    -- Lock the inputs for the duration of the run.
    SetQuantityControlsEnabled(false)
    popupConfirm:SetEnabled(false)
    popupAddToQueue:SetEnabled(false)
    UI.ShowMeter(popupProgressBar, true)
    popupProgressBar:SetValue(0)
    popupProgressLabel:SetHidden(false)
    popupCancel:SetText(GetString(SI_BMW_WITHDRAW_HIDE))

    StartRun({ { itemId = curItemId, slotIndex = curSlotIndex, qty = qty } }, qty,
        OnPopupProgress, OnPopupFinish)
end

local function HidePopup()
    if popup then
        if SCENE_MANAGER and SCENE_MANAGER.HideTopLevel then
            SCENE_MANAGER:HideTopLevel(popup)
        end
        popup:SetHidden(true)
    end
end

function WithdrawDialog.CancelPopup()
    -- The requests were issued synchronously from the click handler and cannot
    -- be cancelled. Hiding leaves the watcher active so the final result remains
    -- accurate and the engine cleans itself up on completion.
    HidePopup()
end

function WithdrawDialog.IsShown()
    return popup and not popup:IsHidden()
end

-- Height of the header wash: the identity block this window opens with (the
-- material icon and the title beside it) plus its top padding, closed by a little
-- air beneath so the accent underline does not crowd the text. The icon is the
-- taller of the two, so it -- not the title row -- sets the floor. Derived rather
-- than a constant, so a change to either carries the band with it.
local function HeaderBandHeight()
    return PADDING + mathmax(TITLE_HEIGHT, ICON_SIZE) + METRIC.BAND_PAD
end

-- Build the singleton popup once. Frame is code-built like the other windows.
local function InitializePopup()
    popup = WINDOW_MANAGER:CreateTopLevelWindow(addon.name .. "_WithdrawPopup")
    popup:SetClampedToScreen(true)
    popup:SetDimensions(POPUP_WIDTH, 260)
    popup:SetHidden(true)
    popup:SetMouseEnabled(true)
    popup:SetMovable(true)
    popup:SetDrawLayer(DL_OVERLAY)
    popup:SetDrawTier(DT_HIGH)
    if SCENE_MANAGER and SCENE_MANAGER.RegisterTopLevel then
        SCENE_MANAGER:RegisterTopLevel(popup, false)
    end
    -- The unified withdraw window is independent from the material list. Center
    -- it on first use, then preserve its dragged position across opens/reloads.
    local savedVars = private.savedVars or {}
    if savedVars.withdrawWindowLeft and savedVars.withdrawWindowTop then
        popup:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
            savedVars.withdrawWindowLeft, savedVars.withdrawWindowTop)
    else
        popup:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    popup:SetHandler("OnMoveStop", function(self)
        local vars = private.savedVars
        if vars then
            vars.withdrawWindowLeft = mathfloor(self:GetLeft())
            vars.withdrawWindowTop = mathfloor(self:GetTop())
        end
    end)

    local backdrop = WINDOW_MANAGER:CreateControl(addon.name .. "_WithdrawBackdrop", popup, CT_BACKDROP)
    backdrop:SetAnchorFill(popup)
    -- One call for the whole shell: ground, border, insets and opacity from the
    -- shared chrome. The one override is the more solid alpha, because this is the
    -- window that takes a typed quantity and the digits must not compete with
    -- whatever is behind it.
    UI.ApplyPanelChrome(backdrop, { alpha = UI.CHROME.BG_ALPHA_SOLID })

    -- The shared letterhead the other two windows open with: a faint accent wash
    -- the full width of the window, closed by an accent underline. Created before
    -- the icon and title so it sits behind them, and spanning the full width (not
    -- the inner width) so it reads as a band rather than a floating rectangle.
    local headerBand = UI.CreateHeaderBand(addon.name .. "_WithdrawHeaderBand", popup,
        POPUP_WIDTH, HeaderBandHeight())
    headerBand:SetAnchor(TOPLEFT, popup, TOPLEFT, 0, 0)

    popupIcon = WINDOW_MANAGER:CreateControl(addon.name .. "_WithdrawIcon", popup, CT_TEXTURE)
    popupIcon:SetDimensions(ICON_SIZE, ICON_SIZE)
    popupIcon:SetAnchor(TOPLEFT, popup, TOPLEFT, PADDING, PADDING)

    popupTitle = WINDOW_MANAGER:CreateControl(addon.name .. "_WithdrawTitle", popup, CT_LABEL)
    -- The section-heading step, not the title step: the title shares its row with
    -- the material icon and the close button, and the larger face would crowd them.
    popupTitle:SetFont(FONT.heading)
    popupTitle:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    popupTitle:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    popupTitle:SetMaxLineCount(1)
    popupTitle:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    popupTitle:SetAnchor(LEFT, popupIcon, RIGHT, CONTROL_GAP, 0)
    -- Leave room on the right for the close button (icon + title + close).
    popupTitle:SetWidth(POPUP_WIDTH - PADDING * 2 - ICON_SIZE - CONTROL_GAP - CLOSE_SIZE)

    local closeButton = WINDOW_MANAGER:CreateControlFromVirtual(
        addon.name .. "_WithdrawClose", popup, "ZO_CloseButton")
    closeButton:SetAnchor(TOPRIGHT, popup, TOPRIGHT, -PADDING, PADDING)
    closeButton:SetHandler("OnClicked", function() WithdrawDialog.CancelPopup() end)

    local innerWidth = POPUP_WIDTH - PADDING * 2

    popupBatchSummaryLabel = WINDOW_MANAGER:CreateControl(
        addon.name .. "_WithdrawBatchSummary", popup, CT_LABEL)
    popupBatchSummaryLabel:SetFont(FONT.body)
    popupBatchSummaryLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    popupBatchSummaryLabel:SetDimensions(innerWidth, LINE)
    -- In batch mode this line replaces the whole single-material block, so it sits
    -- directly beneath the header band -- not under the raw title row, which the
    -- band now extends past.
    popupBatchSummaryLabel:SetAnchor(TOPLEFT, popup, TOPLEFT, PADDING, HeaderBandHeight())
    popupBatchSummaryLabel:SetHidden(true)

    local y = HeaderBandHeight() + SECTION_GAP

    popupFreeLabel = WINDOW_MANAGER:CreateControl(addon.name .. "_WithdrawFree", popup, CT_LABEL)
    popupFreeLabel:SetFont(FONT.small)
    popupFreeLabel:SetDimensions(innerWidth * 0.48, LINE)
    popupFreeLabel:SetAnchor(TOPLEFT, popup, TOPLEFT, PADDING, y)

    popupMaxLabel = WINDOW_MANAGER:CreateControl(addon.name .. "_WithdrawMax", popup, CT_LABEL)
    popupMaxLabel:SetFont(FONT.small)
    popupMaxLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    popupMaxLabel:SetMaxLineCount(1)
    popupMaxLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    popupMaxLabel:SetDimensions(innerWidth * 0.50, LINE)
    popupMaxLabel:SetAnchor(TOPRIGHT, popup, TOPRIGHT, -PADDING, y)
    y = y + LINE

    popupValueLabel = WINDOW_MANAGER:CreateControl(addon.name .. "_WithdrawValue", popup, CT_LABEL)
    popupValueLabel:SetFont(FONT.heading)
    popupValueLabel:SetDimensions(innerWidth, LINE)
    popupValueLabel:SetAnchor(TOPLEFT, popup, TOPLEFT, PADDING, y)
    y = y + LINE + SECTION_GAP
    local quantityY = y
    local QUANTITY_HEIGHT = 40
    y = y + QUANTITY_HEIGHT + SECTION_GAP

    -- Preset buttons, wrapped across rows so they fit the popup width. The button
    -- width is derived from how many fit per row so they span the full width
    -- evenly with no overflow.
    local btnGap = CONTROL_GAP
    local presetsPerRow = 4
    local btnWidth = mathfloor((innerWidth - btnGap * (presetsPerRow - 1)) / presetsPerRow)
    for i = 1, #PRESETS do
        local count = PRESETS[i]
        local button = WINDOW_MANAGER:CreateControlFromVirtual(
            addon.name .. "_WithdrawPreset" .. i, popup, "ZO_DefaultButton")
        button:SetDimensions(btnWidth, BUTTON_HEIGHT)
        button:SetText(PresetCaption(count))
        local col = (i - 1) % presetsPerRow
        local rowN = mathfloor((i - 1) / presetsPerRow)
        button:SetAnchor(TOPLEFT, popup, TOPLEFT,
            PADDING + col * (btnWidth + btnGap), y + rowN * (BUTTON_HEIGHT + btnGap))
        button:SetHandler("OnClicked", function() SetRequested(count) end)
        button.bmwQuantity = count
        UI.ApplyButton(button, "tab")
        popupPresetButtons[i] = button
    end
    popupMaxPresetButton = WINDOW_MANAGER:CreateControlFromVirtual(
        addon.name .. "_WithdrawPresetMax", popup, "ZO_DefaultButton")
    popupMaxPresetButton:SetDimensions(btnWidth, BUTTON_HEIGHT)
    popupMaxPresetButton:SetText(GetString(SI_BMW_WITHDRAW_PRESET_MAX))
    local maxIndex = #PRESETS + 1
    local maxCol = (maxIndex - 1) % presetsPerRow
    local maxRow = mathfloor((maxIndex - 1) / presetsPerRow)
    popupMaxPresetButton:SetAnchor(TOPLEFT, popup, TOPLEFT,
        PADDING + maxCol * (btnWidth + btnGap), y + maxRow * (BUTTON_HEIGHT + btnGap))
    popupMaxPresetButton:SetHandler("OnClicked", function()
        ComputeMax()
        SetRequested(curMax)
    end)
    UI.ApplyButton(popupMaxPresetButton, "tab")
    local presetRows = mathfloor((#PRESETS) / presetsPerRow) + 1
    y = y + presetRows * (BUTTON_HEIGHT + btnGap) + SECTION_GAP

    -- Quantity row: label on the left, editbox to its right.
    popupQtyLabel = WINDOW_MANAGER:CreateControl(addon.name .. "_WithdrawQtyLabel", popup, CT_LABEL)
    popupQtyLabel:SetFont(FONT.body)
    popupQtyLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    popupQtyLabel:SetDimensions(120, QUANTITY_HEIGHT)
    popupQtyLabel:SetAnchor(TOPLEFT, popup, TOPLEFT, PADDING, quantityY)
    popupQtyLabel:SetText(Colorize(COLOR_MUTED, GetString(SI_BMW_WITHDRAW_QTY_LABEL)))

    popupEditBg = WINDOW_MANAGER:CreateControlFromVirtual(
        addon.name .. "_WithdrawEditBg", popup, "ZO_DefaultBackdrop")
    popupEditBg:SetDimensions(innerWidth - 120 - CONTROL_GAP, QUANTITY_HEIGHT)
    -- ZO_DefaultBackdrop ships with its own anchors; clear them before ours so
    -- this does not become a rejected third anchor.
    popupEditBg:ClearAnchors()
    popupEditBg:SetAnchor(LEFT, popupQtyLabel, RIGHT, CONTROL_GAP, 0)
    UI.ApplyField(popupEditBg)
    -- Clicking anywhere on the backdrop (incl. its padding) focuses the editbox,
    -- so the whole field is the hit target, not just the glyphs. Without this the
    -- box reads as "locked" because a custom (non-dialog) editbox does not grab
    -- focus on click on its own. Mirrors the detail window's search field.
    popupEditBg:SetMouseEnabled(true)
    popupEditBg:SetHandler("OnMouseUp", function()
        if popupEdit then
            popupEdit:TakeFocus()
        end
    end)

    popupEdit = WINDOW_MANAGER:CreateControl(addon.name .. "_WithdrawEdit", popupEditBg, CT_EDITBOX)
    popupEdit:SetAnchor(TOPLEFT, popupEditBg, TOPLEFT, 40, 2)
    popupEdit:SetAnchor(BOTTOMRIGHT, popupEditBg, BOTTOMRIGHT, -40, -2)
    popupEdit:SetFont(FONT.heading)
    popupEdit:SetMaxInputChars(7)
    popupEdit:SetMouseEnabled(true)
    popupEdit:SetTextType(TEXT_TYPE_NUMERIC)
    -- Take focus on click so typing an exact amount (e.g. 17) works; some custom
    -- editboxes do not auto-focus reliably.
    popupEdit:SetHandler("OnMouseUp", function(self)
        self:TakeFocus()
    end)
    popupEdit:SetHandler("OnTextChanged", function()
        if suppressEditEvent then
            return
        end
        SetRequested(popupEdit:GetText())
    end)
    -- Enter commits the withdrawal, so typing an exact amount and pressing Enter
    -- works without reaching for the Confirm button.
    popupEdit:SetHandler("OnEnter", function(self)
        self:LoseFocus()
        WithdrawDialog.Confirm()
    end)
    popupEdit:SetHandler("OnEscape", function(self)
        self:LoseFocus()
        WithdrawDialog.CancelPopup()
    end)
    for index = 1, 2 do
        local increase = index == 2
        local button = WINDOW_MANAGER:CreateControl(
            addon.name .. "_WithdrawStep" .. index, popupEditBg, CT_BUTTON)
        button:SetDimensions(30, 30)
        button:SetAnchor(increase and RIGHT or LEFT, popupEditBg,
            increase and RIGHT or LEFT, increase and -4 or 4, 0)
        local texture = increase and "plus" or "minus"
        button:SetNormalTexture("EsoUI/Art/Buttons/" .. texture .. "_up.dds")
        button:SetMouseOverTexture("EsoUI/Art/Buttons/" .. texture .. "_over.dds")
        button:SetPressedTexture("EsoUI/Art/Buttons/" .. texture .. "_down.dds")
        button:SetHandler("OnClicked", function()
            if not isWithdrawing then
                SetRequested(curRequested + (increase and 1 or -1))
            end
        end)
        button:SetHandler("OnMouseEnter", function(self)
            InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -2, TOP)
            UI.TipLine(InformationTooltip, GetString(increase
                and SI_BMW_WITHDRAW_INCREASE or SI_BMW_WITHDRAW_DECREASE))
        end)
        button:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
        popupQuantityButtons[index] = button
    end

    -- Progress block: bar + centered label. Reserves its own vertical space ABOVE
    -- the action buttons so the two never overlap while a run is in progress.
    popupProgressBar = WINDOW_MANAGER:CreateControl(addon.name .. "_WithdrawProgress", popup, CT_STATUSBAR)
    popupProgressBar:SetDimensions(innerWidth, PROGRESS_HEIGHT)
    popupProgressBar:SetAnchor(TOPLEFT, popup, TOPLEFT, PADDING, y)
    popupProgressBar:SetMinMax(0, 1)
    popupProgressBar:SetValue(0)
    UI.ShowMeter(popupProgressBar, false)
    -- The shared meter: an accent bar over a faint track, so a run that has barely
    -- started still shows how much is left rather than a gap in the layout. The
    -- accent tint comes from the palette instead of a hand-written triple that had
    -- drifted a shade off it.
    UI.ApplyMeter(popupProgressBar, addon.name .. "_WithdrawProgressTrack")

    popupProgressLabel = WINDOW_MANAGER:CreateControl(addon.name .. "_WithdrawProgressText", popup, CT_LABEL)
    popupProgressLabel:SetFont(FONT.small)
    popupProgressLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    popupProgressLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    popupProgressLabel:SetDimensions(innerWidth, PROGRESS_HEIGHT)
    popupProgressLabel:SetAnchor(TOPLEFT, popup, TOPLEFT, PADDING, y)
    popupProgressLabel:SetHidden(true)
    y = y + PROGRESS_HEIGHT + SECTION_GAP

    -- The selected material can be withdrawn immediately or added to the batch.
    -- The batch itself is shown as an expandable lower section of this same window.
    popupConfirm = WINDOW_MANAGER:CreateControlFromVirtual(
        addon.name .. "_WithdrawConfirm", popup, "ZO_DefaultButton")
    local actionGap = 8
    local actionWidth = mathfloor((innerWidth - actionGap * 2) / 3)
    popupConfirm:SetDimensions(actionWidth, BUTTON_HEIGHT)
    popupConfirm:SetAnchor(TOPLEFT, popup, TOPLEFT, PADDING, y)
    popupConfirm:SetText(GetString(SI_BMW_WITHDRAW_CONFIRM))
    popupConfirm:SetHandler("OnClicked", function() WithdrawDialog.Confirm() end)
    UI.ApplyButton(popupConfirm, "primary")

    popupAddToQueue = WINDOW_MANAGER:CreateControlFromVirtual(
        addon.name .. "_WithdrawAddToQueue", popup, "ZO_DefaultButton")
    popupAddToQueue:SetDimensions(actionWidth, BUTTON_HEIGHT)
    popupAddToQueue:SetAnchor(TOPLEFT, popupConfirm, TOPRIGHT, actionGap, 0)
    popupAddToQueue:SetText(GetString(SI_BMW_WITHDRAW_ADD_TO_QUEUE))
    popupAddToQueue:SetHandler("OnClicked", function()
        if curMaterialData then
            WithdrawDialog.AddToQueue(curMaterialData)
        end
    end)
    UI.ApplyButton(popupAddToQueue)

    popupCancel = WINDOW_MANAGER:CreateControlFromVirtual(
        addon.name .. "_WithdrawCancelBtn", popup, "ZO_DefaultButton")
    popupCancel:SetDimensions(actionWidth, BUTTON_HEIGHT)
    popupCancel:SetAnchor(TOPRIGHT, popup, TOPRIGHT, -PADDING, y)
    popupCancel:SetText(GetString(SI_BMW_WITHDRAW_CANCEL))
    popupCancel:SetHandler("OnClicked", function() WithdrawDialog.CancelPopup() end)
    UI.ApplyButton(popupCancel)

    popupBaseHeight = y + BUTTON_HEIGHT + PADDING
    -- Batch mode shows only the header band and the one summary line beneath it, so
    -- the queue starts right below that pair. Derived from the band, so it follows
    -- the band's height instead of re-adding the title row by hand.
    popupBatchBaseHeight = HeaderBandHeight() + LINE + SECTION_GAP
    popup:SetHeight(popupBaseHeight)
end

-- Open the popup for a material row (the record from GetCategoryMaterials, now
-- carrying slotIndex). Anchors over the detail window so windows don't scatter.
function WithdrawDialog.Open(materialData)
    if not popup or not materialData then
        return
    end
    if isWithdrawing then
        return  -- don't swap material mid-run
    end

    UI.ShowMeter(popupProgressBar, false)
    popupProgressLabel:SetHidden(true)
    popupCancel:SetText(GetString(SI_BMW_WITHDRAW_CANCEL))

    SelectMaterial(materialData, DefaultQuantityForQuality(materialData.quality))

    UpdateQueueSectionVisibility()

    if SCENE_MANAGER and SCENE_MANAGER.ShowTopLevel then
        SCENE_MANAGER:ShowTopLevel(popup)
    else
        popup:SetHidden(false)
    end
    popup:BringWindowToTop()
end

-- ===========================================================================
-- Part B: multi-material withdraw queue, embedded below the single-material
-- editor in the same popup.
-- ===========================================================================
-- Total empty backpack slots a quantity needs after the destination partial stack
-- is topped up. This mirrors the withdrawal engine, so the "needs N / free M"
-- readout and the enabled state of the action button match what can be moved.
local function SlotsForQuantity(qty, partialRoom)
    if not qty or qty <= 0 then
        return 0
    end
    return mathfloor((mathmax(0, qty - (partialRoom or 0)) + STACK_SIZE - 1) / STACK_SIZE)
end

local function GetPartialBackpackRoom(itemId)
    local slotIndex = FindPartialBackpackSlot(itemId, {})
    if not slotIndex then
        return 0
    end
    return STACK_SIZE - (GetSlotStackSize(BAG_BACKPACK, slotIndex) or STACK_SIZE)
end

-- The header and action state share one capacity calculation, matching the
-- protected movement engine's slot reservation rules. A queue should answer
-- both "what will move?" and "can it move?" without making the player compare
-- separate footer figures.
local function RenderQueueSummary()
    local neededSlots, totalValue = 0, 0
    for i = 1, #queue do
        local e = queue[i]
        neededSlots = neededSlots + SlotsForQuantity(e.qty, GetPartialBackpackRoom(e.itemId))
        if e.priced and e.unitPrice then
            totalValue = totalValue + e.unitPrice * e.qty
        end
    end

    local free = GetNumBagFreeSlots(BAG_BACKPACK)
    local canWithdraw = #queue > 0 and neededSlots <= free
    queueSummaryLabel:SetText(Colorize(COLOR_MUTED, stringformat(
        GetString(SI_BMW_QUEUE_SUMMARY), #queue, neededSlots, FormatGold(totalValue))))
    queueStatusLabel:SetText(Colorize(canWithdraw and COLOR_ACCENT or COLOR_WARN,
        GetString(canWithdraw and SI_BMW_QUEUE_STATUS_READY or SI_BMW_QUEUE_STATUS_NO_SPACE)))

    queueWithdrawAll:SetEnabled(not isWithdrawing and canWithdraw)
    queueClear:SetEnabled(not isWithdrawing and #queue > 0)
    UI.PaintButton(queueWithdrawAll)
    UI.PaintButton(queueClear)
end

local function PopulateQueueList()
    local dataList = ZO_ScrollList_GetDataList(queueList)
    ZO_ScrollList_Clear(queueList)
    for i = 1, #queue do
        -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        -- Scroll-list data is mutated with UI bookkeeping and a self-referential
        -- dataEntry.data path. Keep `queue` runtime-only and populate it with
        -- detached scalar copies in AddToQueue; never place SavedVariables-owned
        -- records here or persist queue entries after they have entered the list.
        --
        -- Bureau archive rule 47-C: withdrawal forms are disposable. Refile a
        -- stamped queue row and the serializer buries the disk under paperwork.
        -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(QUEUE_ROW_TYPE, queue[i])
    end
    ZO_ScrollList_Commit(queueList)
    queueEmptyLabel:SetHidden(#queue > 0)
end

local function RefreshQueue()
    PopulateQueueList()
    RenderQueueSummary()
end

UpdateQueueSectionVisibility = function()
    if not queueSection then
        return
    end

    -- A lone queued material is the same operation as the compact editor above.
    -- Show the batch list only when there are two distinct materials to review.
    local show = IsBatchMode()
    local queueTop = popupBaseHeight + SECTION_GAP
    if show then
        queueTop = popupBatchBaseHeight
    end

    UpdatePopupMode()
    queueSection:SetHidden(not show)
    queueSection:ClearAnchors()
    queueSection:SetAnchor(TOPLEFT, popup, TOPLEFT, PADDING, queueTop)
    popup:SetHeight(show and queueTop + queueSection:GetHeight() + PADDING or popupBaseHeight)
end

function WithdrawDialog.AddToQueue(materialData)
    if not materialData or not materialData.itemId then
        return
    end

    local entry = queueByItemId[materialData.itemId]
    if entry then
        -- Already queued: just refresh its source slot, keep the user's quantity.
        entry.slotIndex = materialData.slotIndex
    else
        local srcStack = GetSlotStackSize(BAG, materialData.slotIndex) or 0
        entry = {
            itemId = materialData.itemId,
            slotIndex = materialData.slotIndex,
            name = materialData.name,
            icon = materialData.icon,
            quality = materialData.quality,
            unitPrice = materialData.unitPrice,
            priced = materialData.priced,
            -- Default by quality (cheap bulk mats grab more, valuable mats less),
            -- clamped to what's actually held; the user raises it in the qty box.
            qty = mathmin(DefaultQuantityForQuality(materialData.quality), srcStack),
        }
        queue[#queue + 1] = entry
        queueByItemId[materialData.itemId] = entry
    end

    -- With one entry there is no separate batch UI: the normal editor is the
    -- only view and must show the queue's actual requested quantity.
    if #queue == 1 then
        SelectMaterial(entry, entry.qty)
    end

    -- Keep the unified popup visible. Its queue section expands only after a
    -- second material is present, avoiding a duplicate one-item representation.
    if popup:IsHidden() then
        WithdrawDialog.Open(materialData)
    else
        UpdateQueueSectionVisibility()
    end
    RefreshQueue()
end

function WithdrawDialog.RemoveFromQueue(itemId)
    if not queueByItemId[itemId] then
        return
    end
    local wasBatchMode = IsBatchMode()
    queueByItemId[itemId] = nil
    for i = 1, #queue do
        if queue[i].itemId == itemId then
            table.remove(queue, i)
            break
        end
    end

    -- When removing a row collapses a 2+ item batch back to one queue entry,
    -- that entry becomes the only meaningful single-material context. Replace
    -- any older material that originally opened the popup before showing the
    -- compact editor again.
    if wasBatchMode and #queue == 1 then
        SelectMaterial(queue[1], queue[1].qty)
    end
    RefreshQueue()
    UpdateQueueSectionVisibility()
end

function WithdrawDialog.ClearQueue()
    if isWithdrawing then
        return
    end
    queue = {}
    queueByItemId = {}
    RefreshQueue()
    UpdateQueueSectionVisibility()
end

local function OnQueueProgress(moved, total)
    queueProgressBar:SetValue(total > 0 and moved / total or 0)
    queueProgressBar.bmwLabel:SetText(Colorize(COLOR_MUTED,
        stringformat(GetString(SI_BMW_WITHDRAW_PROGRESS), moved, total)))
end

local function NormalizeQueue()
    for i = #queue, 1, -1 do
        local entry = queue[i]
        local currentItemId = GetItemId(BAG, entry.slotIndex)
        local remainingStack = GetSlotStackSize(BAG, entry.slotIndex) or 0
        if currentItemId ~= entry.itemId or remainingStack <= 0 then
            queueByItemId[entry.itemId] = nil
            table.remove(queue, i)
        else
            entry.qty = mathmin(entry.qty, remainingStack)
            local valuation = addon.Valuation
            if valuation and valuation.GetMaterialPrice then
                local unitPrice, priced = valuation.GetMaterialPrice(entry.itemId, entry.slotIndex)
                entry.unitPrice = unitPrice
                entry.priced = priced
            end
        end
    end
end

local queueRunGoldValue = nil

local function OnQueueFinish(moved, total, requested)
    UI.ShowMeter(queueProgressBar, false)
    queueProgressBar.bmwLabel:SetText(Colorize(COLOR_MUTED,
        stringformat(GetString(SI_BMW_WITHDRAW_RESULT_LABEL), moved or 0, total or 0)))
    SetQuantityControlsEnabled(true)
    -- Drop exhausted entries and ones whose virtual slot was reused by a
    -- different material; keep valid partials with their quantity clamped.
    NormalizeQueue()
    RefreshQueue()
    UpdateQueueSectionVisibility()
    ComputeMax()
    RenderPopup()
    local goldValue = queueRunGoldValue and requested == total and moved == total
        and FormatGold(queueRunGoldValue) or GetString(SI_BMW_MSG_VALUE_UNKNOWN)
    AnnounceWithdrawResult(moved or 0, requested or total or 0, goldValue)
    queueRunGoldValue = nil
end

function WithdrawDialog.WithdrawAll()
    if isWithdrawing or #queue == 0 then
        return
    end

    local jobs, total, neededSlots = {}, 0, 0
    local totalGold, allPriced = 0, true
    for i = 1, #queue do
        local e = queue[i]
        local srcStack = GetSlotStackSize(BAG, e.slotIndex) or 0
        if GetItemId(BAG, e.slotIndex) == e.itemId and srcStack > 0 then
            local qty = mathmin(e.qty, srcStack)
            jobs[#jobs + 1] = { itemId = e.itemId, slotIndex = e.slotIndex, qty = qty }
            total = total + qty
            neededSlots = neededSlots + SlotsForQuantity(qty, GetPartialBackpackRoom(e.itemId))
            if e.priced and e.unitPrice then
                totalGold = totalGold + e.unitPrice * qty
            else
                allPriced = false
            end
        end
    end
    if total <= 0 or neededSlots > GetNumBagFreeSlots(BAG_BACKPACK) then
        RefreshQueue()
        return
    end

    UI.ShowMeter(queueProgressBar, true)
    queueProgressBar:SetValue(0)
    queueProgressBar.bmwLabel:SetText("")
    queueWithdrawAll:SetEnabled(false)
    queueClear:SetEnabled(false)
    popupConfirm:SetEnabled(false)
    popupAddToQueue:SetEnabled(false)
    SetQuantityControlsEnabled(false)
    queueRunGoldValue = allPriced and totalGold or nil
    StartRun(jobs, total, OnQueueProgress, OnQueueFinish)
end

-- One queue row: icon, name, editable qty, value, remove button. Handlers are
-- bound once per recycled control (sentinel) and always read the row's CURRENT
-- data, since ZO_ScrollList reuses a small pool of rows across many entries.
local function SetupQueueRow(rowControl, data)
    rowControl.bmwQueueData = data

    -- The template declares the columns' geometry; their face comes from the shared
    -- type scale. No-ops after the first time this control is used.
    UI.ApplyRowFonts(rowControl, QUEUE_ROW_COLUMNS)
    rowControl:SetHeight(QUEUE_ROW_HEIGHT)
    UI.PaintRowFill(rowControl:GetNamedChild("Hover"), "zebra")
    rowControl:GetNamedChild("Hover"):SetHidden(false)
    UI.ApplyField(rowControl:GetNamedChild("QtyBg"))

    rowControl:GetNamedChild("Icon"):SetTexture(data.icon)

    local nameLabel = rowControl:GetNamedChild("Name")
    nameLabel:SetMaxLineCount(1)
    nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    nameLabel:SetText(addon.Valuation.ColorizeMaterialName(data.name, data.quality))

    local valueLabel = rowControl:GetNamedChild("Value")
    if data.priced and data.unitPrice then
        valueLabel:SetText(FormatGold(data.unitPrice * data.qty))
    else
        valueLabel:SetText(Colorize(COLOR_MUTED, GetString(SI_BMW_DETAIL_GROWTH_NEW)))
    end

    -- The qty editbox is nested inside the QtyBg backdrop (see DetailWindow.xml),
    -- so its name suffix is "QtyBgEdit", not "Qty".
    local edit = rowControl:GetNamedChild("QtyBgEdit")
    edit:SetFont(FONT.body)
    rowControl.bmwSuppressEdit = true
    edit:SetText(tostring(data.qty or 0))
    rowControl.bmwSuppressEdit = false

    if not rowControl.bmwBound then
        rowControl.bmwBound = true
        rowControl:SetHandler("OnMouseEnter", function(self)
            UI.PaintRowFill(self:GetNamedChild("Hover"))
        end)
        rowControl:SetHandler("OnMouseExit", function(self)
            UI.PaintRowFill(self:GetNamedChild("Hover"), "zebra")
        end)

        edit:SetHandler("OnTextChanged", function(self)
            if rowControl.bmwSuppressEdit then
                return
            end
            local d = rowControl.bmwQueueData
            if not d then
                return
            end
            local srcStack = GetSlotStackSize(BAG, d.slotIndex) or 0
            local qty = mathmax(0, mathmin(tonumber(self:GetText()) or 0, srcStack))
            d.qty = qty

            -- Reflect the clamped value back into the box so what is shown always
            -- matches what will be withdrawn (and what the slots-needed figure is
            -- based on). Without this, typing more than the craft bag holds leaves
            -- a misleading larger number in the field while the slot count tracks
            -- the real, clamped quantity. Guarded so this SetText does not recurse.
            if tostring(qty) ~= (self:GetText() or "") then
                rowControl.bmwSuppressEdit = true
                self:SetText(tostring(qty))
                rowControl.bmwSuppressEdit = false
            end

            -- Update just this row's value + the summary; avoid a full rebuild so
            -- the editbox keeps focus while typing.
            if d.priced and d.unitPrice then
                valueLabel:SetText(FormatGold(d.unitPrice * qty))
            end
            RenderQueueSummary()
        end)

        local removeButton = rowControl:GetNamedChild("Remove")
        removeButton:SetHandler("OnClicked", function()
            local d = rowControl.bmwQueueData
            if d then
                WithdrawDialog.RemoveFromQueue(d.itemId)
            end
        end)
    end
end

local function InitializeQueueSection()
    local innerWidth = POPUP_WIDTH - PADDING * 2

    queueSection = WINDOW_MANAGER:CreateControl(addon.name .. "_QueueSection", popup, CT_CONTROL)
    queueSection:SetWidth(innerWidth)
    queueSection:SetAnchor(TOPLEFT, popup, TOPLEFT, PADDING, popupBaseHeight + SECTION_GAP)
    queueSection:SetHidden(true)

    -- Structural weight: this rule is what separates the batch from the window's
    -- single-material half, the same job the rule under the material table's column
    -- headers does.
    local divider = UI.CreateRule(addon.name .. "_QueueDivider", queueSection, innerWidth, "strong")
    divider:SetAnchor(TOPLEFT, queueSection, TOPLEFT, 0, 0)

    local title = WINDOW_MANAGER:CreateControl(addon.name .. "_QueueTitle", queueSection, CT_LABEL)
    title:SetFont(FONT.heading)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    title:SetDimensions(innerWidth, TITLE_HEIGHT)
    title:SetAnchor(TOPLEFT, queueSection, TOPLEFT, 0, SECTION_GAP)
    title:SetText(Colorize(COLOR_ACCENT, GetString(SI_BMW_QUEUE_TITLE)))

    queueSummaryLabel = WINDOW_MANAGER:CreateControl(addon.name .. "_QueueSummary", queueSection, CT_LABEL)
    queueSummaryLabel:SetFont(FONT.body)
    queueSummaryLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    queueSummaryLabel:SetDimensions(innerWidth, LINE)
    queueSummaryLabel:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 0)

    queueStatusLabel = WINDOW_MANAGER:CreateControl(addon.name .. "_QueueStatus", queueSection, CT_LABEL)
    queueStatusLabel:SetFont(FONT.small)
    queueStatusLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    queueStatusLabel:SetDimensions(innerWidth, LINE)
    queueStatusLabel:SetAnchor(TOPLEFT, queueSummaryLabel, BOTTOMLEFT, 0, 0)

    local listY = SECTION_GAP + TITLE_HEIGHT + LINE * 2 + SECTION_GAP
    queueList = WINDOW_MANAGER:CreateControlFromVirtual(
        addon.name .. "_QueueListControl", queueSection, "BureauOfMaterialWorth_WithdrawQueueList")
    queueList:SetDimensions(innerWidth, QUEUE_ROW_HEIGHT * QUEUE_MAX_ROWS)
    queueList:SetAnchor(TOPLEFT, queueSection, TOPLEFT, 0, listY)
    ZO_ScrollList_Initialize(queueList)
    ZO_ScrollList_AddDataType(queueList, QUEUE_ROW_TYPE,
        "BureauOfMaterialWorth_WithdrawQueueRow", QUEUE_ROW_HEIGHT, SetupQueueRow)

    queueEmptyLabel = WINDOW_MANAGER:CreateControl(addon.name .. "_QueueEmpty", queueSection, CT_LABEL)
    queueEmptyLabel:SetFont(FONT.body)
    queueEmptyLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    queueEmptyLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    queueEmptyLabel:SetDimensions(innerWidth, QUEUE_ROW_HEIGHT * 2)
    queueEmptyLabel:SetAnchor(TOP, queueList, TOP, 0, QUEUE_ROW_HEIGHT)
    queueEmptyLabel:SetText(Colorize(COLOR_MUTED, GetString(SI_BMW_QUEUE_EMPTY)))

    local footerY = listY + QUEUE_ROW_HEIGHT * QUEUE_MAX_ROWS + SECTION_GAP

    -- Inside the batch block, so the soft weight: it closes the list off from its
    -- own footer rather than separating two parts of the window, exactly as the rule
    -- above the material table's total does.
    local footerDivider = UI.CreateRule(addon.name .. "_QueueFooterDivider", queueSection,
        innerWidth, "soft")
    footerDivider:SetAnchor(TOPLEFT, queueSection, TOPLEFT, 0, footerY)
    footerY = footerY + SECTION_GAP

    queueProgressBar = WINDOW_MANAGER:CreateControl(addon.name .. "_QueueProgress", queueSection, CT_STATUSBAR)
    queueProgressBar:SetDimensions(innerWidth, PROGRESS_HEIGHT)
    queueProgressBar:SetAnchor(TOPLEFT, queueSection, TOPLEFT, 0, footerY)
    queueProgressBar:SetMinMax(0, 1)
    queueProgressBar:SetValue(0)
    UI.ShowMeter(queueProgressBar, false)
    -- Same meter as the single-material run above, so a batch run and a single
    -- withdrawal report progress in one visual language.
    UI.ApplyMeter(queueProgressBar, addon.name .. "_QueueProgressTrack")
    queueProgressBar.bmwLabel = WINDOW_MANAGER:CreateControl(
        addon.name .. "_QueueProgressText", queueSection, CT_LABEL)
    queueProgressBar.bmwLabel:SetFont(FONT.small)
    queueProgressBar.bmwLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    queueProgressBar.bmwLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    queueProgressBar.bmwLabel:SetAnchorFill(queueProgressBar)
    footerY = footerY + PROGRESS_HEIGHT + SECTION_GAP

    queueWithdrawAll = WINDOW_MANAGER:CreateControlFromVirtual(
        addon.name .. "_QueueWithdrawAll", queueSection, "ZO_DefaultButton")
    queueWithdrawAll:SetDimensions(180, BUTTON_HEIGHT)
    queueWithdrawAll:SetAnchor(TOPLEFT, queueSection, TOPLEFT, 0, footerY)
    queueWithdrawAll:SetText(GetString(SI_BMW_QUEUE_WITHDRAW_ALL))
    queueWithdrawAll:SetHandler("OnClicked", function() WithdrawDialog.WithdrawAll() end)
    UI.ApplyButton(queueWithdrawAll, "primary")

    queueClear = WINDOW_MANAGER:CreateControlFromVirtual(
        addon.name .. "_QueueClear", queueSection, "ZO_DefaultButton")
    queueClear:SetDimensions(140, BUTTON_HEIGHT)
    queueClear:SetAnchor(TOPRIGHT, queueSection, TOPRIGHT, 0, footerY)
    queueClear:SetText(GetString(SI_BMW_QUEUE_CLEAR))
    queueClear:SetHandler("OnClicked", function() WithdrawDialog.ClearQueue() end)
    UI.ApplyButton(queueClear)

    queueSection:SetHeight(footerY + BUTTON_HEIGHT)

    RefreshQueue()
end

-- ===========================================================================
-- Public lifecycle
-- ===========================================================================
function WithdrawDialog.Initialize()
    if popup then
        return
    end
    QUEUE_ROW_HEIGHT = UI.RowHeight("queue")
    InitializePopup()
    InitializeQueueSection()
end

-- Refresh the open queue list against current stock; called from the detail
-- refresh path so the queue's values track withdrawals/deposits while open.
function WithdrawDialog.Refresh()
    if popup and not popup:IsHidden() and #queue > 0 and not isWithdrawing then
        NormalizeQueue()
        RefreshQueue()
        UpdateQueueSectionVisibility()
    end
end

-- Hard teardown when the craft bag closes: stop any run and hide the unified
-- withdrawal window so nothing lingers and no stepper survives with the bag shut.
function WithdrawDialog.OnCraftBagHidden()
    if isWithdrawing then
        FinishRun()
    end
    HidePopup()
end
