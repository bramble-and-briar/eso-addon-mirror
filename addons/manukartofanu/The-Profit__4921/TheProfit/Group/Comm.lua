local TP = TheProfit

-- Group sharing over LibGroupBroadcast: finds group members who also run The Profit
-- and keeps a copy of their tracked items with the highest unit price they would pay.
-- Four protocols: Hello (presence), Table (the whole list), Delta (list changes) and
-- Deal (lots found during a store visit plus the public kiosk where they were found).
-- The module only depends on TP.SV, TP.GetMaxPurchasePrice and the TP.callbacks events.
local LGB = LibGroupBroadcast
if LGB then
    local manager = GetAddOnManager()
    for index = 1, manager:GetNumAddOns() do
        if manager:GetAddOnInfo(index) == "LibGroupBroadcast" and manager:GetAddOnVersion(index) < 95 then
            LGB = nil
            break
        end
    end
end

-- Ids 300-309 are reserved for The Profit on the ESOUI wiki page
-- "LibGroupBroadcast_IDs".
local PROTOCOL_ID_HELLO = 300
local PROTOCOL_ID_TABLE = 301
local PROTOCOL_ID_DELTA = 302
local PROTOCOL_ID_DEAL = 303

local PROTOCOL_VERSION = 1
local KIND_HELLO, KIND_REPLY, KIND_BYE = 0, 1, 2
local ITEMS_PER_TABLE_PART = 3
local MAX_TABLE_PARTS = 4
local ENTRIES_PER_DELTA = 2
local MAX_PLACE_BYTES = 96
local MAX_QUANTITY = 1023
local MAX_GUILD_ID = 2 ^ 24 - 1
local PEER_STALE_SECONDS = 150 * 60
local MAX_PRICE = 2 ^ 24 - 1
local MAX_ITEM_ID = 2 ^ 24 - 1
local HASH_MODULUS = 524287
local TAG_MODULUS = 251
local REVISION_RANGE = 256
local STALE_BEFORE_RESET = 2
local EDIT_FLUSH_DELAY_MS = 20 * 1000
local HELLO_FLUSH_DELAY_MS = 1500
local MARKET_FLUSH_DELAY_MS = 5 * 1000
local GROUP_EVENT_DELAY_MS = 500
local ACTIVATED_DELAY_MS = 3000
local PERIODIC_TABLE_MS = 60 * 60 * 1000
local UPDATE_NAME = TP.name .. "GroupSharing"

local strings = {
    en = {
        share = "Share tracked items with group",
        shareTooltip = "Tells group members who also run The Profit which items you track and the highest price you would pay for one piece, and receives the same from them. Off by default.",
        needsLibrary = "Requires LibGroupBroadcast build 95 or newer. Install or update it, then reload the UI.",
        handlerDescription = "Shares tracked items and their buy prices with group members to find deals for each other.",
        helloName = "The Profit: presence",
        helloDescription = "Tells group members that you run The Profit and are ready to exchange tracked items.",
        tableName = "The Profit: tracked list",
        tableDescription = "Sends the full list of your tracked items with their buy prices.",
        deltaName = "The Profit: list changes",
        deltaDescription = "Sends items you start or stop tracking, so the list of group members stays current.",
        dealName = "The Profit: deals",
        dealDescription = "Tells group members about a guild store lot that matches an item they track.",
        debugHeader = "Group sharing",
        debugState = "enabled: %s, LibGroupBroadcast: %s, ready: %s, grouped: %s, revision: %d",
        debugOwn = "Own list (%d items):",
        debugPeers = "Group members with The Profit (%d):",
        debugPeer = "%s: version %s, revision %s, %d items",
        debugItem = "  %s  hash %d  price %s",
        debugNone = "  none",
        yes = "yes",
        no = "no",
    },
    ru = {
        share = "Делиться отслеживаемыми предметами с группой",
        shareTooltip = "Сообщает участникам группы, у которых тоже есть The Profit, какие предметы вы отслеживаете и максимальную цену за штуку, и получает то же от них. По умолчанию выключено.",
        needsLibrary = "Нужна LibGroupBroadcast сборки 95 или новее. Установите или обновите её, затем перезагрузите интерфейс.",
        handlerDescription = "Обменивается с участниками группы отслеживаемыми предметами и ценами покупки, чтобы находить друг другу сделки.",
        helloName = "The Profit: присутствие",
        helloDescription = "Сообщает участникам группы, что у вас The Profit и вы готовы обмениваться отслеживаемыми предметами.",
        tableName = "The Profit: список предметов",
        tableDescription = "Отправляет полный список ваших отслеживаемых предметов с ценами покупки.",
        deltaName = "The Profit: изменения списка",
        deltaDescription = "Отправляет предметы, которые вы начали или перестали отслеживать, чтобы список у участников группы оставался актуальным.",
        dealName = "The Profit: сделки",
        dealDescription = "Сообщает участникам группы о лоте в гильдейском магазине, подходящем под отслеживаемый ими предмет.",
        debugHeader = "Обмен с группой",
        debugState = "включён: %s, LibGroupBroadcast: %s, готов: %s, в группе: %s, ревизия: %d",
        debugOwn = "Свой список (%d предметов):",
        debugPeers = "Участники группы с The Profit (%d):",
        debugPeer = "%s: версия %s, ревизия %s, предметов: %d",
        debugItem = "  %s  хэш %d  цена %s",
        debugNone = "  нет",
        yes = "да",
        no = "нет",
    },
}

local function L(key)
    local language = string.lower(GetCVar("language.2") or "en") == "ru" and "ru" or "en"
    return strings[language][key] or strings.en[key] or key
end

local state = {
    ready = false,
    revision = 0,
    announced = false,
    wasGrouped = false,
    peers = {},
    pendingFull = false,
    pendingDeltas = {},
    flushDue = nil,
    groupEventGeneration = 0,
    peersVersion = 0,
}
local helloProtocol, tableProtocol, deltaProtocol, dealProtocol

local function IsEnabled()
    local store = TP.SV and TP.SV.groupShare
    return store ~= nil and store.enabled == true
end

-- Bumped whenever a peer or its list changes, so consumers can rebuild their indexes.
local function Touch()
    state.peersVersion = state.peersVersion + 1
end

local function NormalizeName(name)
    return zo_strlower(UndecorateDisplayName(name or ""))
end

-- Hashes stay below the modulus, so every intermediate value is far inside the exact
-- integer range of a Lua number.
local function HashString(text, modulus)
    local hash = 0
    for index = 1, #text do
        hash = (hash * 31 + string.byte(text, index)) % modulus
    end
    return hash
end

local function GetSelfTag()
    return HashString(NormalizeName(GetDisplayName()), TAG_MODULUS)
end

-- An item is identified by its id plus a hash of the whole normalized link key, so
-- variants of one item id (enchants, potion effects) stay apart.
local function GetIdentity(itemKey)
    local itemId = tonumber(string.match(itemKey or "", "|H%d:item:(%d+):"))
    if not itemId or itemId > MAX_ITEM_ID then return nil end
    return itemId, HashString(itemKey, HASH_MODULUS)
end

local function IdentityKey(itemId, hash)
    return itemId .. ":" .. hash
end
TP.GetGroupItemIdentity = GetIdentity

local function NextRevision()
    state.revision = (state.revision + 1) % REVISION_RANGE
    return state.revision
end

local function IsNewer(revision, known)
    local difference = (revision - known) % REVISION_RANGE
    return difference > 0 and difference < REVISION_RANGE / 2
end

local function IsNewerOrEqual(revision, known)
    return (revision - known) % REVISION_RANGE < REVISION_RANGE / 2
end

local function IsGrouped()
    return IsUnitGrouped("player")
end

local function CanSend()
    return state.ready and IsEnabled() and IsGrouped()
end

local function Send(protocol, values, options)
    if not protocol or not protocol:IsEnabled() then return false end
    return protocol:Send(values, options)
end

local function SendHello(kind)
    return Send(helloProtocol, { version = PROTOCOL_VERSION, kind = kind })
end

-- The unit price at which the model would buy one piece. Items without a forecast
-- are left out because there is nothing to compare a listing with, and so are items
-- whose price does not fit the message: a clamped price would not be the model's price.
local function GetEntry(itemKey)
    local itemId, hash = GetIdentity(itemKey)
    if not itemId or not TP.GetMaxPurchasePrice then return nil end
    local price = TP.GetMaxPurchasePrice(itemKey)
    if not price then return nil end

    price = zo_round(price)
    if price < 1 or price > MAX_PRICE then return nil end
    return { itemId = itemId, hash = hash, price = price }
end

local function BuildOwnItems()
    local items = {}
    for _, itemKey in ipairs(TP.SV.trackedItemOrder or {}) do
        if TP.SV.trackedItems[itemKey] and #items < ITEMS_PER_TABLE_PART * MAX_TABLE_PARTS then
            local entry = GetEntry(itemKey)
            if entry then items[#items + 1] = entry end
        end
    end
    return items
end

-- The first part replaces any older table still waiting in the queue; later parts
-- must not, or they would delete the parts queued just before them.
local function SendTable()
    if not CanSend() then return end

    local parts = {}
    for index, entry in ipairs(BuildOwnItems()) do
        local partIndex = math.floor((index - 1) / ITEMS_PER_TABLE_PART) + 1
        parts[partIndex] = parts[partIndex] or {}
        parts[partIndex][#parts[partIndex] + 1] = entry
    end
    if #parts == 0 then parts[1] = {} end

    local revision = NextRevision()
    local tag = GetSelfTag()
    for index, part in ipairs(parts) do
        Send(tableProtocol, {
            revision = revision,
            senderTag = tag,
            part = index - 1,
            total = #parts,
            item = part,
        }, { replaceQueuedMessages = index == 1 })
    end
end

local function SendDeltas()
    local entries = {}
    for _, delta in pairs(state.pendingDeltas) do
        if delta.add then
            local entry = TP.SV.trackedItems[delta.key] and GetEntry(delta.key)
            if entry then
                entries[#entries + 1] = { add = true, itemId = entry.itemId, hash = entry.hash, price = entry.price }
            end
        elseif not TP.SV.trackedItems[delta.key] then
            entries[#entries + 1] = { add = false, itemId = delta.itemId, hash = delta.hash }
        end
    end
    state.pendingDeltas = {}

    local tag = GetSelfTag()
    for first = 1, #entries, ENTRIES_PER_DELTA do
        local chunk = {}
        for index = first, math.min(#entries, first + ENTRIES_PER_DELTA - 1) do
            chunk[#chunk + 1] = entries[index]
        end
        Send(deltaProtocol, { revision = NextRevision(), senderTag = tag, entry = chunk })
    end
end

local function Flush()
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME .. "Flush")
    state.flushDue = nil

    local sendFull = state.pendingFull
    state.pendingFull = false
    if not CanSend() then
        state.pendingDeltas = {}
        return
    end

    -- A full table already contains everything the queued changes would say.
    if sendFull then
        state.pendingDeltas = {}
        SendTable()
    elseif next(state.pendingDeltas) then
        SendDeltas()
    end
end

-- Keeps the earliest due time, so a quick reply to a Hello is not postponed by a
-- slower batch of edits and edits are collected for the whole window.
local function ScheduleFlush(delayMs)
    local due = GetGameTimeMilliseconds() + delayMs
    if state.flushDue and state.flushDue <= due then return end
    state.flushDue = due
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME .. "Flush")
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME .. "Flush", delayMs, Flush)
end

local function ScheduleFullTable(delayMs)
    state.pendingFull = true
    ScheduleFlush(delayMs)
end

local function ClearPeers()
    state.peers = {}
    Touch()
end

-- Display names of the other group members, normalized.
local function GetGroupNames()
    local names = {}
    local selfName = NormalizeName(GetDisplayName())
    for index = 1, GetGroupSize() do
        local name = NormalizeName(GetUnitDisplayName(GetGroupUnitTagByIndex(index)))
        if name ~= "" and name ~= selfName then names[name] = true end
    end
    return names
end

local function PrunePeers()
    local names = GetGroupNames()
    for name in pairs(state.peers) do
        if not names[name] then
            state.peers[name] = nil
            Touch()
        end
    end
end

local function Announce()
    state.announced = true
    SendHello(KIND_HELLO)
    ScheduleFullTable(HELLO_FLUSH_DELAY_MS)
end

local function OnGroupChanged()
    if not IsGrouped() then
        state.wasGrouped = false
        state.announced = false
        ClearPeers()
        state.pendingDeltas = {}
        return
    end
    state.wasGrouped = true
    PrunePeers()
    if CanSend() and not state.announced then Announce() end
end

local function OnGroupEvent()
    state.groupEventGeneration = state.groupEventGeneration + 1
    local generation = state.groupEventGeneration
    zo_callLater(function()
        if generation == state.groupEventGeneration then OnGroupChanged() end
    end, GROUP_EVENT_DELAY_MS)
end

-- Returns the record for the sender, or nil for ourselves, when sharing is off, or
-- when the sender tag does not match the unit (parts of different senders can get
-- mixed up by the library when messages are split across frames).
local function ResolvePeer(unitTag, senderTag)
    if not IsEnabled() then return nil end
    local displayName = GetUnitDisplayName(unitTag)
    local name = NormalizeName(displayName)
    if name == "" or name == NormalizeName(GetDisplayName()) then return nil end
    if senderTag ~= nil and HashString(name, TAG_MODULUS) ~= senderTag then return nil end

    local peer = state.peers[name]
    if not peer then
        peer = { name = displayName, items = {} }
        state.peers[name] = peer
        Touch()
    end
    return peer
end

-- Forgets everything known about a peer's list. Used when the peer starts a new
-- session: its revision counter starts over after a reload, so the old one is useless.
local function ResetSession(peer)
    peer.revision = nil
    peer.pending = nil
    peer.items = {}
    peer.rejected = 0
    Touch()
end

-- A message that looks older than the stored revision is normally a late duplicate.
-- If that keeps happening the peer has most likely restarted without us seeing its
-- Hello, so after a few of them the stored state is dropped and the message is taken.
local function ShouldRejectStale(peer, isStale)
    if not (peer.revision and isStale) then
        peer.rejected = 0
        return false
    end
    peer.rejected = (peer.rejected or 0) + 1
    if peer.rejected < STALE_BEFORE_RESET then return true end
    ResetSession(peer)
    return false
end

local function OnHelloReceived(unitTag, data)
    if not IsEnabled() then return end

    if data.kind == KIND_BYE then
        local name = NormalizeName(GetUnitDisplayName(unitTag))
        state.peers[name] = nil
        Touch()
        return
    end

    local peer = ResolvePeer(unitTag, nil)
    if not peer then return end
    peer.version = data.version
    peer.updated = GetTimeStamp()
    if data.kind == KIND_HELLO then ResetSession(peer) end

    -- A newcomer needs our list; a reply already carries the sender's own.
    if data.kind == KIND_HELLO and CanSend() then
        SendHello(KIND_REPLY)
        ScheduleFullTable(HELLO_FLUSH_DELAY_MS)
    end
end

local function OnTableReceived(unitTag, data)
    local peer = ResolvePeer(unitTag, data.senderTag)
    if not peer then return end

    local revision, total, part = data.revision, data.total, data.part
    if part >= total then return end
    if part == 0 then
        if ShouldRejectStale(peer, peer.revision and not IsNewerOrEqual(revision, peer.revision)) then return end
    elseif peer.revision and not IsNewerOrEqual(revision, peer.revision) then
        return
    end

    local pending = peer.pending
    if not pending or pending.revision ~= revision then
        if pending and not IsNewer(revision, pending.revision) then return end
        pending = { revision = revision, total = total, parts = {}, count = 0 }
        peer.pending = pending
    end
    if pending.parts[part] == nil then
        pending.parts[part] = data.item or {}
        pending.count = pending.count + 1
    end
    if pending.count < pending.total then return end

    local items = {}
    for index = 0, pending.total - 1 do
        for _, entry in ipairs(pending.parts[index] or {}) do
            items[IdentityKey(entry.itemId, entry.hash)] = { itemId = entry.itemId, hash = entry.hash, price = entry.price }
        end
    end
    peer.items = items
    peer.revision = revision
    peer.pending = nil
    peer.updated = GetTimeStamp()
    Touch()
end

local function OnDeltaReceived(unitTag, data)
    local peer = ResolvePeer(unitTag, data.senderTag)
    if not peer then return end
    if ShouldRejectStale(peer, peer.revision and not IsNewer(data.revision, peer.revision)) then return end

    for _, entry in ipairs(data.entry or {}) do
        local key = IdentityKey(entry.itemId, entry.hash)
        if entry.add and entry.price then
            peer.items[key] = { itemId = entry.itemId, hash = entry.hash, price = entry.price }
        else
            peer.items[key] = nil
        end
    end
    peer.revision = data.revision
    peer.updated = GetTimeStamp()
    Touch()
end

-- Keeps the byte-oriented LGB string field from cutting a multibyte UTF-8 character.
local function TruncateUtf8(value, maxBytes)
    value = tostring(value or "")
    if #value <= maxBytes then return value end

    local last = maxBytes
    while last > 0 do
        local nextByte = string.byte(value, last + 1)
        if not nextByte or nextByte < 128 or nextByte >= 192 then break end
        last = last - 1
    end
    return string.sub(value, 1, last)
end

-- A hit is { itemId, hash, unitPrice, quantity, guildId }. The place is captured by
-- the reporter while they are standing at the foreign guild's public kiosk.
local function SendDeal(hit, place)
    if not CanSend() or not hit then return false end

    local price = zo_round(hit.unitPrice)
    local quantity = zo_round(hit.quantity)
    if not hit.guildId or hit.guildId < 1 or hit.guildId > MAX_GUILD_ID
        or price < 1 or price > MAX_PRICE
        or quantity < 1 or quantity > MAX_QUANTITY then return false end

    return Send(dealProtocol, {
        senderTag = GetSelfTag(),
        place = TruncateUtf8(place, MAX_PLACE_BYTES),
        itemId = hit.itemId,
        hash = hit.hash,
        price = price,
        quantity = quantity,
        guildId = hit.guildId,
    })
end

local function SendDeals(hits, place)
    local sent = {}
    for _, hit in ipairs(hits) do
        if SendDeal(hit, place) then sent[#sent + 1] = hit end
    end
    return sent
end

local function OnDealReceived(unitTag, data)
    local peer = ResolvePeer(unitTag, data.senderTag)
    if not peer then return end
    if data.place == "" then data.place = nil end
    TP.callbacks:FireCallbacks("GroupDealReceived", peer.name, data)
end

-- Peers that can be told about a deal: still in the group, online, and recently
-- heard from (a live peer resends its list at least hourly).
local function GetActivePeers()
    local tags = {}
    for index = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(index)
        tags[NormalizeName(GetUnitDisplayName(unitTag))] = unitTag
    end

    local now = GetTimeStamp()
    local result = {}
    for name, peer in pairs(state.peers) do
        local unitTag = tags[name]
        if unitTag and IsUnitOnline(unitTag)
            and (peer.updated == nil or now - peer.updated <= PEER_STALE_SECONDS) then
            result[#result + 1] = peer
        end
    end
    return result
end

local function QueueDelta(itemKey, add)
    if not CanSend() then return end
    local itemId, hash = GetIdentity(itemKey)
    if not itemId then return end

    state.pendingDeltas[IdentityKey(itemId, hash)] = { add = add, key = itemKey, itemId = itemId, hash = hash }
    ScheduleFlush(EDIT_FLUSH_DELAY_MS)
end

local function SetSharingEnabled(enabled)
    enabled = enabled == true
    local was = IsEnabled()
    if enabled == was then return end

    if was and state.ready and IsGrouped() then SendHello(KIND_BYE) end
    TP.SV.groupShare = TP.SV.groupShare or {}
    TP.SV.groupShare.enabled = enabled

    state.announced = false
    state.pendingFull = false
    state.pendingDeltas = {}
    ClearPeers()
    if enabled then OnGroupChanged() end
    TP.callbacks:FireCallbacks("GroupSharingChanged", enabled)
end

local function DeclareProtocols()
    local handler = LGB:RegisterHandler(TP.name)
    handler:SetDisplayName("The Profit")
    handler:SetDescription(L("handlerDescription"))

    helloProtocol = handler:DeclareProtocol(PROTOCOL_ID_HELLO, "TheProfitHello")
    helloProtocol:SetDisplayName(L("helloName"))
    helloProtocol:SetDescription(L("helloDescription"))
    helloProtocol:AddField(LGB.CreateNumericField("version", { minValue = 0, maxValue = 15 }))
    helloProtocol:AddField(LGB.CreateNumericField("kind", { minValue = 0, maxValue = 3 }))
    helloProtocol:AddField(LGB.CreateReservedField("reserved", 1))
    helloProtocol:OnData(OnHelloReceived)
    local helloOk = helloProtocol:Finalize()

    tableProtocol = handler:DeclareProtocol(PROTOCOL_ID_TABLE, "TheProfitTable")
    tableProtocol:SetDisplayName(L("tableName"))
    tableProtocol:SetDescription(L("tableDescription"))
    tableProtocol:AddField(LGB.CreateNumericField("revision", { numBits = 8 }))
    tableProtocol:AddField(LGB.CreateNumericField("senderTag", { numBits = 8 }))
    tableProtocol:AddField(LGB.CreateNumericField("part", { minValue = 0, maxValue = MAX_TABLE_PARTS - 1 }))
    tableProtocol:AddField(LGB.CreateNumericField("total", { minValue = 1, maxValue = MAX_TABLE_PARTS }))
    tableProtocol:AddField(LGB.CreateArrayField(LGB.CreateTableField("item", {
        LGB.CreateNumericField("itemId", { numBits = 24 }),
        LGB.CreateNumericField("hash", { numBits = 19 }),
        LGB.CreateNumericField("price", { numBits = 24 }),
    }), { minLength = 0, maxLength = ITEMS_PER_TABLE_PART }))
    tableProtocol:OnData(OnTableReceived)
    local tableOk = tableProtocol:Finalize({ replaceQueuedMessages = false })

    deltaProtocol = handler:DeclareProtocol(PROTOCOL_ID_DELTA, "TheProfitDelta")
    deltaProtocol:SetDisplayName(L("deltaName"))
    deltaProtocol:SetDescription(L("deltaDescription"))
    deltaProtocol:AddField(LGB.CreateNumericField("revision", { numBits = 8 }))
    deltaProtocol:AddField(LGB.CreateNumericField("senderTag", { numBits = 8 }))
    deltaProtocol:AddField(LGB.CreateArrayField(LGB.CreateTableField("entry", {
        LGB.CreateFlagField("add"),
        LGB.CreateNumericField("itemId", { numBits = 24 }),
        LGB.CreateNumericField("hash", { numBits = 19 }),
        LGB.CreateOptionalField(LGB.CreateNumericField("price", { numBits = 24 })),
    }), { minLength = 1, maxLength = ENTRIES_PER_DELTA }))
    deltaProtocol:OnData(OnDeltaReceived)
    local deltaOk = deltaProtocol:Finalize({ replaceQueuedMessages = false })

    dealProtocol = handler:DeclareProtocol(PROTOCOL_ID_DEAL, "TheProfitDeal")
    dealProtocol:SetDisplayName(L("dealName"))
    dealProtocol:SetDescription(L("dealDescription"))
    dealProtocol:AddField(LGB.CreateNumericField("senderTag", { numBits = 8 }))
    dealProtocol:AddField(LGB.CreateStringField("place", { minLength = 0, maxLength = MAX_PLACE_BYTES }))
    dealProtocol:AddField(LGB.CreateNumericField("itemId", { numBits = 24 }))
    dealProtocol:AddField(LGB.CreateNumericField("hash", { numBits = 19 }))
    dealProtocol:AddField(LGB.CreateNumericField("price", { numBits = 24 }))
    dealProtocol:AddField(LGB.CreateNumericField("quantity", { numBits = 10 }))
    dealProtocol:AddField(LGB.CreateNumericField("guildId", { numBits = 24 }))
    dealProtocol:OnData(OnDealReceived)
    local dealOk = dealProtocol:Finalize({ replaceQueuedMessages = false })

    return helloOk and tableOk and deltaOk and dealOk
end

-- Narrow interface for the finder and the deals list.
TP.GroupComm = {
    IsEnabled = IsEnabled,
    CanSend = CanSend,
    SendDeals = SendDeals,
    GetActivePeers = GetActivePeers,
    GetPeersVersion = function() return state.peersVersion end,
    NormalizeName = NormalizeName,
    HashString = HashString,
    HASH_MODULUS = HASH_MODULUS,
}

function TP.SetupGroupSharing()
    if state.ready or not LGB then return end

    local succeeded, result = pcall(DeclareProtocols)
    if not succeeded or not result then
        d("|cE7C56AThe Profit:|r group sharing is unavailable: " .. tostring(succeeded and "protocol setup failed" or result))
        return
    end
    state.ready = true

    TP.callbacks:RegisterCallback("TrackedItemAdded", function(itemKey) QueueDelta(itemKey, true) end)
    TP.callbacks:RegisterCallback("TrackedItemRemoved", function(itemKey) QueueDelta(itemKey, false) end)
    TP.callbacks:RegisterCallback("MarketDataLoaded", function()
        if CanSend() then ScheduleFullTable(MARKET_FLUSH_DELAY_MS) end
    end)

    local eventName = TP.name .. "GroupSharing"
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_GROUP_MEMBER_JOINED, OnGroupEvent)
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_GROUP_MEMBER_LEFT, OnGroupEvent)
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(OnGroupChanged, ACTIVATED_DELAY_MS)
    end)
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME .. "Periodic", PERIODIC_TABLE_MS, function()
        if CanSend() then ScheduleFullTable(EDIT_FLUSH_DELAY_MS) end
    end)

    if TP.SetupGroupFinder then TP.SetupGroupFinder() end
    if TP.SetupGroupDeals then TP.SetupGroupDeals() end
end

-- Control inserted below the header of the group settings.
local function BuildShareControl()
    local control = {
        type = "checkbox",
        name = L("share"),
        tooltip = L("shareTooltip"),
        getFunc = IsEnabled,
        setFunc = SetSharingEnabled,
        default = false,
    }
    if not LGB then
        control.disabled = true
        control.warning = L("needsLibrary")
    end
    return control
end

local getBaseControls = TP.GetGroupOptionControls
function TP.GetGroupOptionControls()
    local controls = getBaseControls and getBaseControls() or {}
    table.insert(controls, 2, BuildShareControl())
    return controls
end

function TP.GetGroupPeers()
    return state.peers
end

local function YesNo(value)
    return L(value and "yes" or "no")
end

function TP.PrintGroupSharing()
    local prefix = "|cE7C56AThe Profit:|r "
    d(prefix .. L("debugHeader"))
    d(string.format(L("debugState"), YesNo(IsEnabled()), YesNo(LGB ~= nil), YesNo(state.ready),
        YesNo(IsGrouped()), state.revision))

    local own = BuildOwnItems()
    d(string.format(L("debugOwn"), #own))
    for _, entry in ipairs(own) do
        d(string.format(L("debugItem"), tostring(entry.itemId), entry.hash, ZO_CommaDelimitNumber(entry.price)))
    end
    if #own == 0 then d(L("debugNone")) end

    local count = 0
    for _ in pairs(state.peers) do count = count + 1 end
    d(string.format(L("debugPeers"), count))
    for _, peer in pairs(state.peers) do
        local itemCount = 0
        for _ in pairs(peer.items) do itemCount = itemCount + 1 end
        d(string.format(L("debugPeer"), peer.name, tostring(peer.version or "?"), tostring(peer.revision or "?"), itemCount))
        for _, entry in pairs(peer.items) do
            d(string.format(L("debugItem"), tostring(entry.itemId), entry.hash, ZO_CommaDelimitNumber(entry.price)))
        end
    end
    if count == 0 then d(L("debugNone")) end
end
