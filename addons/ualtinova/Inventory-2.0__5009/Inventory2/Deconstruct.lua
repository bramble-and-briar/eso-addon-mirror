InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- AUTOMATE's second action: the DECONSTRUCT category broken down at a crafting station, the way
-- the first one (Trading.lua) sells the SELL category at a merchant. Off, Ask or Auto
-- (IG.ActionMode("decon"), Classify.lua). Ask puts up a window saying how many pieces it is
-- about to break down; Auto does it as the station opens and says what it did in chat.
--
-- The game's own path is used and nothing else: PrepareDeconstructMessage, then each piece with
-- AddItemToDeconstructMessage, then SendDeconstructMessage -- exactly what the station's own
-- Deconstruct All does (smithingextraction_shared.lua and universaldeconstructionpanel_shared.lua
-- ExtractAll). None of the three is protected. A batch holds at most what the station's own
-- slot would hold (MAX_ITEM_SLOTS_PER_DECONSTRUCTION, MAX_ITERATIONS_PER_DECONSTRUCTION), and the
-- next batch waits for the game to say the last one is done (EVENT_CRAFT_COMPLETED).
--
-- What it touches: backpack pieces standing in DECONSTRUCT (by the classifier, so rules and your
-- own moves alike) that this station can break down. Never a locked piece, a piece in an Armory
-- build, a stolen piece, a piece a crafting writ is waiting for, or a set piece not yet in your
-- set collection.

local NAME = "InventoryGroupingDecon"
local DIALOG = "INVENTORY_GROUPING_DECON_ALL"
local START_DELAY_MS = 400     -- after the station opens, so its own scene is up first
local NEXT_BATCH_MS = 300      -- after the game says a batch is done
local BUSY_RETRY_MS = 200      -- while the game is still busy with a craft
local BATCH_TIMEOUT_MS = 6000  -- a batch the game never answers ends the run
local MAX_ADD_RETRIES = 20     -- pieces the game turns away in one run before it gives up
local MAX_SLOTS = MAX_ITEM_SLOTS_PER_DECONSTRUCTION or 100
local MAX_ITERATIONS = MAX_ITERATIONS_PER_DECONSTRUCTION or 100

local STATION_TYPES = {}
for _, name in ipairs({ "CRAFTING_TYPE_BLACKSMITHING", "CRAFTING_TYPE_CLOTHIER", "CRAFTING_TYPE_WOODWORKING",
    "CRAFTING_TYPE_JEWELRYCRAFTING", "CRAFTING_TYPE_ENCHANTING" }) do
    if _G[name] then STATION_TYPES[_G[name]] = true end
end

-- The station being used: { craftingType = n } at one craft's station, { } at the universal
-- deconstruction assistant (every craft at once), nil when not at a station.
local station
local run -- { queue, broken, refused, waiting } while a run is going

local function Commas(amount)
    if ZO_CommaDelimitNumber then return ZO_CommaDelimitNumber(amount) end
    return tostring(amount)
end

local function Refused(bagId, slotIndex, itemLink)
    if IsItemPlayerLocked(bagId, slotIndex) then return true end
    if IsItemInArmory and IsItemInArmory(bagId, slotIndex) then return true end
    if IsItemStolen(bagId, slotIndex) then return true end
    if IG.IsDailyWritItem and IG.IsDailyWritItem({ bagId = bagId, slotIndex = slotIndex }) then return true end
    -- A set piece the collection does not have yet is worth more kept than broken down.
    if IsItemLinkSetCollectionPiece and IsItemLinkSetCollectionPiece(itemLink)
        and not IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(itemLink)) then
        return true
    end
    return false
end

local function StationTakes(bagId, slotIndex)
    if not station then return false end
    if station.craftingType then return CanItemBeDeconstructed(bagId, slotIndex, station.craftingType) end
    return CanItemBeDeconstructed(bagId, slotIndex)
end

-- The backpack's DECONSTRUCT pieces this station can take, with their links so each one can be
-- checked again just before it goes.
local function Pieces()
    local pieces = {}
    local cache = SHARED_INVENTORY and SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
    if not cache then return pieces end
    for _, slotData in pairs(cache) do
        if type(slotData) == "table" and slotData.bagId == BAG_BACKPACK and slotData.slotIndex then
            local bagId, slotIndex = slotData.bagId, slotData.slotIndex
            local path = IG.ClassifySlot(slotData, false, false)
            local itemLink = GetItemLink(bagId, slotIndex)
            if path and path[1] and path[1].id == "DECON" and itemLink ~= ""
                and not Refused(bagId, slotIndex, itemLink) and StationTakes(bagId, slotIndex) then
                local stack = GetSlotStackSize(bagId, slotIndex) or 1
                if stack < 1 then stack = 1 end
                pieces[#pieces + 1] = { bagId = bagId, slotIndex = slotIndex, link = itemLink, stack = stack }
            end
        end
    end
    return pieces
end

local function Finish()
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Timeout")
    if not run then return end
    local broken = run.broken
    run = nil
    if broken > 0 then
        d(string.format(IG.S("DECON_CHAT_DONE"), broken, broken == 1 and IG.S("DECON_ITEM_SINGULAR") or IG.S("DECON_ITEM_PLURAL")))
    end
end

local SendBatch

-- One batch: as many pieces as the station's slot would hold. A piece the game turns away is
-- dropped and the batch is started again without it, because the station's own Deconstruct All
-- never sends a message that had a piece refused.
SendBatch = function()
    if not run then return end
    if not station then return Finish() end
    if IsPerformingCraftProcess() then
        zo_callLater(SendBatch, BUSY_RETRY_MS)
        return
    end
    -- Pieces that moved, were used or changed since they were gathered are let go.
    for index = #run.queue, 1, -1 do
        local piece = run.queue[index]
        if GetItemLink(piece.bagId, piece.slotIndex) ~= piece.link then table.remove(run.queue, index) end
    end
    if #run.queue == 0 then return Finish() end

    local added, iterations
    while true do
        PrepareDeconstructMessage()
        added, iterations = 0, 0
        local turnedAway
        for index, piece in ipairs(run.queue) do
            if added >= MAX_SLOTS then break end
            if added > 0 and iterations + piece.stack > MAX_ITERATIONS then break end
            if AddItemToDeconstructMessage(piece.bagId, piece.slotIndex, piece.stack) then
                added, iterations = added + 1, iterations + piece.stack
            else
                turnedAway = index
                break
            end
        end
        if not turnedAway then break end
        table.remove(run.queue, turnedAway)
        run.refused = run.refused + 1
        if run.refused > MAX_ADD_RETRIES or #run.queue == 0 then return Finish() end
    end
    if added == 0 then return Finish() end

    for _ = 1, added do table.remove(run.queue, 1) end
    run.waiting = added
    SendDeconstructMessage()
    EVENT_MANAGER:RegisterForUpdate(NAME .. "Timeout", BATCH_TIMEOUT_MS, Finish)
end

local function OnCraftCompleted()
    if not (run and run.waiting) then return end
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Timeout")
    run.broken = run.broken + run.waiting
    run.waiting = nil
    if #run.queue > 0 then zo_callLater(SendBatch, NEXT_BATCH_MS) else Finish() end
end

local function Start(pieces)
    if run or not station or #pieces == 0 then return end
    run = { queue = pieces, broken = 0, refused = 0 }
    SendBatch()
end

ESO_Dialogs[DIALOG] = {
    title = { text = function() return IG.S("DECON_DIALOG_TITLE") end },
    mainText = { text = "" },
    buttons = {
        { text = SI_DIALOG_YES, callback = function()
            -- Gathered again at the press: the window was put up at one moment and answered at
            -- another.
            zo_callLater(function() Start(Pieces()) end, 0)
        end },
        { text = SI_DIALOG_NO },
    },
}

local function Ask(pieces)
    ESO_Dialogs[DIALOG].mainText.text = string.format(IG.S("DECON_DIALOG_BODY"),
        Commas(#pieces), #pieces == 1 and IG.S("DECON_PIECE_SINGULAR") or IG.S("DECON_PIECE_PLURAL"))
    ZO_Dialogs_ShowDialog(DIALOG)
end

local function OnStationOpened(_, craftingType, _, craftingMode)
    station = nil
    if CRAFTING_INTERACTION_MODE_UNIVERSAL_DECONSTRUCTION
        and craftingMode == CRAFTING_INTERACTION_MODE_UNIVERSAL_DECONSTRUCTION then
        station = {}
    elseif STATION_TYPES[craftingType] then
        station = { craftingType = craftingType }
    else
        return
    end
    local mode = IG.ActionMode and IG.ActionMode("decon") or "off"
    if mode == "off" then return end
    if IG.IsEnabled and not IG.IsEnabled() then return end
    zo_callLater(function()
        if not station or run then return end
        local pieces = Pieces()
        if #pieces == 0 then return end
        if mode == "ask" then Ask(pieces) else Start(pieces) end
    end, START_DELAY_MS)
end

local function OnStationClosed()
    station = nil
    ZO_Dialogs_ReleaseDialog(DIALOG)
    Finish()
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_CRAFTING_STATION_INTERACT, OnStationOpened)
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_END_CRAFTING_STATION_INTERACT, OnStationClosed)
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_CRAFT_COMPLETED, OnCraftCompleted)
