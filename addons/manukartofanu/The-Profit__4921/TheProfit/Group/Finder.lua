local TP = TheProfit

-- Looks through each page of guild store results AwesomeGuildStore receives for the
-- player's own searches and notes lots that another group member wants (an item they
-- track, at or below their buy price). The notes are sent when the store is closed.
-- It never makes a search request of its own. Only the page that has just arrived is
-- read: AwesomeGuildStore keeps the results of earlier searches for the whole session,
-- and those lots may be gone by now.
local REQUIRED_AGS_API_VERSION = 4
local MAX_CANDIDATES = 300
local WANTS_MAX_AGE_MS = 60 * 1000
local RESEND_SECONDS = 30 * 60
local EVENT_NAME = TP.name .. "GroupFinder"

local state = {
    wants = nil,
    wantsVersion = -1,
    wantsBuiltAt = 0,
    database = nil,
    candidates = {},
    seen = {},
    sent = {},
    place = nil,
    failed = false,
}

local function Reset()
    state.wants = nil
    state.candidates = {}
    state.seen = {}
    state.place = nil
end

-- GetGuildOwnedKioskInfo only knows the player's own guilds. At a public kiosk the
-- reliable source is the unit currently being interacted with; this is the same
-- route used by TTC and AwesomeGuildStore. GetPlayerLocationName does not depend on
-- which map the player last opened.
local function CaptureTraderPlace()
    if not IsUnitGuildKiosk or not IsUnitGuildKiosk("interact") then return nil end

    local trader = ""
    if GetRawUnitName then
        trader = zo_strformat(SI_UNIT_NAME, GetRawUnitName("interact") or "")
    elseif GetUnitName then
        trader = zo_strformat("<<1>>", GetUnitName("interact") or "")
    end
    local location = GetPlayerLocationName and zo_strformat("<<1>>", GetPlayerLocationName() or "") or ""
    if location == "" and GetUnitZone then
        location = zo_strformat("<<1>>", GetUnitZone("player") or "")
    end

    if trader ~= "" and location ~= "" then return string.format("%s, %s", trader, location) end
    if trader ~= "" then return trader end
    if location ~= "" then return location end
    return nil
end

-- itemId -> list of { hash, price }: the highest price any active peer would pay.
-- A peer going offline or falling silent changes no version number, so the index is
-- also rebuilt when it is a minute old.
local function GetWants()
    local comm = TP.GroupComm
    local version = comm.GetPeersVersion()
    local now = GetGameTimeMilliseconds()
    if state.wants and state.wantsVersion == version and now - state.wantsBuiltAt < WANTS_MAX_AGE_MS then
        return state.wants
    end

    local byIdentity = {}
    for _, peer in ipairs(comm.GetActivePeers()) do
        for key, entry in pairs(peer.items) do
            local existing = byIdentity[key]
            if not existing or entry.price > existing.price then byIdentity[key] = entry end
        end
    end

    local wants = {}
    for _, entry in pairs(byIdentity) do
        local list = wants[entry.itemId]
        if not list then
            list = {}
            wants[entry.itemId] = list
        end
        list[#list + 1] = { hash = entry.hash, price = entry.price }
    end

    state.wants = wants
    state.wantsVersion = version
    state.wantsBuiltAt = now
    return wants
end

local function EvaluateLot(item, guildId, wants, selfName)
    local comm = TP.GroupComm
    local itemLink = item.itemLink
    if type(itemLink) ~= "string" or itemLink == "" or item.purchased or item.soldout then return end

    local itemId = tonumber(string.match(itemLink, "|H%d:item:(%d+):"))
    local list = itemId and wants[itemId]
    if not list then return end

    local quantity = tonumber(item.stackCount) or 0
    local price = tonumber(item.purchasePrice) or 0
    if quantity < 1 or price <= 0 then return end
    if comm.NormalizeName(item.sellerName) == selfName then return end

    local unitPrice = price / quantity
    local hash = comm.HashString(TP.GetItemKey(itemLink), comm.HASH_MODULUS)
    for _, want in ipairs(list) do
        if want.hash == hash and unitPrice <= want.price then
            -- Every matching lot is kept: the cheapest one may be bought by the
            -- player before the store closes, and the next one must still be reported.
            local seen = state.seen[guildId]
            if not seen then
                seen = {}
                state.seen[guildId] = seen
            end
            if seen[item.itemUniqueId] or #state.candidates >= MAX_CANDIDATES then return end
            seen[item.itemUniqueId] = true

            state.candidates[#state.candidates + 1] = {
                itemId = itemId,
                hash = hash,
                guildId = guildId,
                unitPrice = unitPrice,
                quantity = quantity,
                totalPrice = price,
                uniqueId = item.itemUniqueId,
                ratio = unitPrice / want.price,
            }
            return
        end
    end
end

-- numItems is the size of the page that has just been received.
local function ScanPage(guildId, numItems)
    local comm = TP.GroupComm
    local database = state.database
    if not database or not guildId or not numItems or not comm.CanSend() then return end

    local wants = GetWants()
    if not next(wants) then return end
    state.place = state.place or CaptureTraderPlace()

    local data = database:GetOrCreateDataForGuild(guildId)
    local selfName = comm.NormalizeName(GetDisplayName())
    for slotIndex = 1, numItems do
        local uniqueId = database:GetItemUniqueIdForSlotIndex(slotIndex)
        local item = uniqueId and data[uniqueId]
        if item then EvaluateLot(item, guildId, wants, selfName) end
    end
end

local function OnItemDatabaseUpdate(database)
    state.database = database
end

-- A failure inside these callbacks must never reach AwesomeGuildStore's own callbacks.
local function OnSearchResultsReceived(_, numItems, _, _, guildId)
    if state.failed then return end
    local succeeded, message = pcall(ScanPage, guildId, numItems)
    if not succeeded then
        state.failed = true
        d("|cE7C56AThe Profit:|r group deal search stopped: " .. tostring(message))
    end
end

local function OnStoreClosed()
    local now = GetTimeStamp()
    local place = state.place
    for key, sentAt in pairs(state.sent) do
        if now - sentAt > RESEND_SECONDS then state.sent[key] = nil end
    end

    -- Lots the player bought or that were reported recently drop out first; only then
    -- is the cheapest remaining lot picked for each guild and item.
    local best = {}
    for _, hit in ipairs(state.candidates) do
        local sentKey = string.format("%d:%d:%d:%d:%d", hit.guildId, hit.itemId, hit.hash,
            zo_round(hit.unitPrice), hit.quantity)
        if not state.sent[sentKey] and not TP.IsLotPurchased(hit.guildId, hit.uniqueId, hit.totalPrice) then
            hit.sentKey = sentKey
            local key = hit.guildId .. ":" .. hit.itemId .. ":" .. hit.hash
            local current = best[key]
            if not current or hit.unitPrice < current.unitPrice then best[key] = hit end
        end
    end
    Reset()

    local hits = {}
    for _, hit in pairs(best) do hits[#hits + 1] = hit end
    -- Queue the deepest discount last so it remains on the HUD and at the top of the list.
    table.sort(hits, function(left, right) return left.ratio > right.ratio end)

    for _, hit in ipairs(TP.GroupComm.SendDeals(hits, place)) do state.sent[hit.sentKey] = now end
end

function TP.SetupGroupFinder()
    local AGS = AwesomeGuildStore
    if not AGS or type(AGS.RegisterCallback) ~= "function" or type(AGS.GetAPIVersion) ~= "function" then return end
    if AGS.GetAPIVersion() ~= REQUIRED_AGS_API_VERSION then return end
    if not AGS.callback or not AGS.callback.ITEM_DATABASE_UPDATE or not AGS.callback.SEARCH_RESULTS_RECEIVED then return end

    -- The database is updated just before the results callback fires, so the first one
    -- hands over the object and the second one reads the new page from it.
    AGS:RegisterCallback(AGS.callback.ITEM_DATABASE_UPDATE, OnItemDatabaseUpdate)
    AGS:RegisterCallback(AGS.callback.SEARCH_RESULTS_RECEIVED, OnSearchResultsReceived)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME .. "Open", EVENT_OPEN_TRADING_HOUSE, Reset)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME .. "Close", EVENT_CLOSE_TRADING_HOUSE, OnStoreClosed)
end
