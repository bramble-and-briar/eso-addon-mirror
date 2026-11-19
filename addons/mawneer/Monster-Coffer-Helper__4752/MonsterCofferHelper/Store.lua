local MCH = MonsterCofferHelper

local Store = {}
MCH.Store = Store

-- What the last store scan found. Cleared when the store closes.
-- { vendorId, mysteryIndex, curatedIndexToSetIds = { [storeIndex] = { setId, ... } } }
Store.current = nil

--------------------------------------------------------------------------------
-- What a store entry contains
--------------------------------------------------------------------------------

-- The sets a coffer can hand out, read from its item link: the same data the
-- game's own tooltip lists as "Set A -- or -- Set B". A curated coffer covers
-- two sets, so its name cannot be matched to one set; matching names used to
-- miss most coffers and tie style pages to a set instead.
local function ContainerSetIds(itemLink)
    local setIds = {}
    if not itemLink or itemLink == "" then return setIds end

    for setIndex = 1, GetItemLinkNumContainerSetIds(itemLink) do
        local hasSet, _, _, _, _, setId = GetItemLinkContainerSetInfo(itemLink, setIndex)
        if hasSet and setId and setId > 0 then
            setIds[#setIds + 1] = setId
        end
    end
    return setIds
end

-- Style pages are key-priced containers too, but they grant a collectible
-- rather than gear, so they are neither coffer.
local function GrantsCollectible(itemLink)
    return itemLink ~= nil and itemLink ~= "" and GetItemLinkContainerCollectibleId(itemLink) > 0
end

local function HasSets(entry)
    return entry.setIds ~= nil and #entry.setIds > 0
end

--------------------------------------------------------------------------------
-- Working out which quartermaster this is
--------------------------------------------------------------------------------

-- Scoring the scanned sets against each quartermaster's known stock is more
-- dependable than reading the NPC's name: it survives localisation quirks and
-- still lands on the right vendor if the stock has been rotated.
local function IdentifyByStock(setIds)
    local setInfo = LibSets and LibSets.setInfo
    if not setInfo or #setIds == 0 then return nil end

    local scores = {}
    for _, setId in ipairs(setIds) do
        local data = setInfo[setId]
        local vendorId = data and data.undauntedChestId
        if vendorId then
            scores[vendorId] = (scores[vendorId] or 0) + 1
        end
    end

    local best, bestScore = nil, 0
    for vendorId, score in pairs(scores) do
        if score > bestScore then best, bestScore = vendorId, score end
    end
    return best
end

local function IdentifyByName()
    local npcName = zo_strlower(zo_strformat(SI_UNIT_NAME, GetUnitName("interact") or ""))
    if npcName == "" then return nil end

    for _, vendorId in ipairs(MCH.VENDOR_IDS) do
        local vendorName = MCH.Model.GetVendorName(vendorId)
        if vendorName then
            local lower = zo_strlower(vendorName)
            if lower ~= "" and (npcName == lower or string.find(npcName, lower, 1, true)) then
                return vendorId
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Scanning
--------------------------------------------------------------------------------

-- Every store entry that can be bought with Undaunted Keys, with the sets it
-- contains. Style pages are left out.
local function CollectKeyPricedEntries()
    local entries = {}

    for entryIndex = 1, GetNumStoreItems() do
        local _, name, stack, _, _, _, _, _, _, currencyType1, currencyQuantity1,
              currencyType2, currencyQuantity2 = GetStoreEntryInfo(entryIndex)

        -- Undaunted Keys can sit in either currency slot depending on the entry.
        local keyCost
        if currencyType1 == CURT_UNDAUNTED_KEYS then
            keyCost = currencyQuantity1
        elseif currencyType2 == CURT_UNDAUNTED_KEYS then
            keyCost = currencyQuantity2
        end

        local itemLink = GetStoreItemLink(entryIndex)
        if keyCost and keyCost > 0 and stack > 0 and not GrantsCollectible(itemLink) then
            entries[#entries + 1] = {
                index  = entryIndex,
                name   = zo_strformat(SI_TOOLTIP_ITEM_NAME, name or ""),
                cost   = keyCost,
                setIds = ContainerSetIds(itemLink),
            }
        end
    end

    return entries
end

-- Most frequent value in a list, ties broken towards the cheaper price.
local function ModalCost(costs)
    local counts = {}
    for _, cost in ipairs(costs) do
        counts[cost] = (counts[cost] or 0) + 1
    end

    local best, bestCount
    for cost, count in pairs(counts) do
        if not best or count > bestCount or (count == bestCount and cost < best) then
            best, bestCount = cost, count
        end
    end
    return best
end

-- A quartermaster stocks many curated coffers, all at the same price, against a
-- single cheaper mystery coffer. So the price that repeats across the shelf IS
-- the curated price, counted among the entries that contain sets when enough
-- of them do, so that a run of unrelated key-priced items cannot outvote them.
-- Exposed on Store so it can be tested outside the game: it takes plain entry
-- tables and calls no game API.
local MIN_MATCHES_TRUSTED = 3

function Store.DerivePrices(entries)
    if #entries == 0 then return nil, nil, nil end

    local allCosts, matchedCosts = {}, {}
    for _, entry in ipairs(entries) do
        allCosts[#allCosts + 1] = entry.cost
        if HasSets(entry) then matchedCosts[#matchedCosts + 1] = entry.cost end
    end

    -- Trust the set-holding entries only when enough of them look like a real shelf.
    local curatedCost = (#matchedCosts >= MIN_MATCHES_TRUSTED)
        and ModalCost(matchedCosts)
        or ModalCost(allCosts)

    -- The mystery coffer is the cheap outlier below the curated price. An entry
    -- that names no set is preferred, so that a cheap curated coffer is never
    -- taken for it; but the mystery coffer's link may list every set it can
    -- roll, so failing that the cheapest entry below the curated price wins.
    local mysteryEntry, mysteryHasSets
    for _, entry in ipairs(entries) do
        if entry.cost < curatedCost then
            local hasSets = HasSets(entry)
            local better = not mysteryEntry
                or (mysteryHasSets and not hasSets)
                or (mysteryHasSets == hasSets and entry.cost < mysteryEntry.cost)
            if better then
                mysteryEntry, mysteryHasSets = entry, hasSets
            end
        end
    end

    if mysteryEntry then
        return mysteryEntry.cost, curatedCost, mysteryEntry.index
    end
    return nil, curatedCost, nil
end

-- Returns a scan table, or nil when this store is not an Undaunted quartermaster.
function Store.Scan()
    local entries = CollectKeyPricedEntries()
    if #entries == 0 then return nil end

    local mysteryCost, curatedCost, mysteryIndex = Store.DerivePrices(entries)

    -- Only entries selling at the curated price count as coffers. That keeps any
    -- other set-holding thing the vendor happens to stock out of both the
    -- tooltip annotations and the learned stock list.
    local curatedIndexToSetIds = {}
    local setIds, seenSet = {}, {}

    for _, entry in ipairs(entries) do
        if HasSets(entry) and entry.cost == curatedCost and entry.index ~= mysteryIndex then
            curatedIndexToSetIds[entry.index] = entry.setIds
            for _, setId in ipairs(entry.setIds) do
                if not seenSet[setId] then
                    seenSet[setId] = true
                    setIds[#setIds + 1] = setId
                end
            end
        end
    end

    local vendorId = IdentifyByStock(setIds) or IdentifyByName()
    if not vendorId then return nil end

    table.sort(setIds)

    return {
        vendorId            = vendorId,
        setIds              = setIds,
        mysteryIndex        = mysteryIndex,
        mysteryCost         = mysteryCost,
        curatedCost         = curatedCost,
        curatedIndexToSetIds = curatedIndexToSetIds,
        entries             = entries,
    }
end

--------------------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------------------

-- `/coffer scan` while a vendor window is open. Dumps what the game reports so a
-- mismatch between the real shelf and what this addon made of it is visible.
function Store.Dump()
    local count = GetNumStoreItems()
    if count == 0 then
        d("|cDD6666No store is open.|r Talk to an Undaunted quartermaster first.")
        return
    end

    d(string.format("|c9FD3FF[Coffer] store scan: %d entries|r", count))

    for entryIndex = 1, count do
        local _, name, stack, price, _, _, _, _, _, currencyType1, currencyQuantity1,
              currencyType2, currencyQuantity2 = GetStoreEntryInfo(entryIndex)

        local cleanName = zo_strformat(SI_TOOLTIP_ITEM_NAME, name or "")
        local cost = "-"
        if currencyType1 == CURT_UNDAUNTED_KEYS then
            cost = currencyQuantity1 .. " keys"
        elseif currencyType2 == CURT_UNDAUNTED_KEYS then
            cost = currencyQuantity2 .. " keys(2)"
        elseif price and price > 0 then
            cost = price .. " gold"
        end

        local itemLink = GetStoreItemLink(entryIndex)
        local names = {}
        for _, setId in ipairs(ContainerSetIds(itemLink)) do
            names[#names + 1] = zo_strformat(SI_ITEM_SET_NAME_FORMATTER, GetItemSetName(setId))
        end

        local contents
        if #names > 0 then
            contents = "|c66DD66-> " .. table.concat(names, " / ") .. "|r"
        else
            -- The game's own wording for what the item is ("Style Page", "Skill
            -- Style", ...), as on the first line of its tooltip.
            local itemType, specializedItemType = GetItemLinkItemType(itemLink)
            local typeText = ZO_GetSpecializedItemTypeText(itemType, specializedItemType)
            if not typeText or typeText == "" then typeText = "no sets" end
            local ignored = GrantsCollectible(itemLink) and " (ignored)" or ""
            contents = "|c9A9A9A-> " .. typeText .. ignored .. "|r"
        end

        d(string.format("  %2d. %s  |cFFFFFF[%s]|r  stack %s  %s",
            entryIndex, cleanName, cost, tostring(stack), contents))
    end

    local scan = Store.Scan()
    if not scan then
        d("|cDD6666Not recognised as an Undaunted quartermaster.|r")
        return
    end

    local curatedCount = 0
    for _ in pairs(scan.curatedIndexToSetIds) do curatedCount = curatedCount + 1 end

    d(string.format("|c9FD3FFDerived:|r vendor %d (%s), mystery %s (entry %s), curated %s, %d coffer(s) covering %d set(s)",
        scan.vendorId, MCH.Model.GetVendorName(scan.vendorId),
        tostring(scan.mysteryCost), tostring(scan.mysteryIndex), tostring(scan.curatedCost),
        curatedCount, #scan.setIds))
end

-- Writes what the scan learned into SavedVariables so the slash command can use
-- real prices and real stock while the player is nowhere near the vendor.
local function Remember(scan)
    local record = MCH.learned[scan.vendorId] or {}
    record.seenAt = GetTimeStamp()

    -- A shelf where the mystery coffer is not the cheaper option means something
    -- was misread. Keep the previous figures rather than persisting nonsense --
    -- a bad price would otherwise stick around long after leaving the vendor.
    local pricesLookSane = scan.mysteryCost and scan.curatedCost
        and scan.mysteryCost < scan.curatedCost

    if pricesLookSane then
        record.mysteryCost = scan.mysteryCost
        record.curatedCost = scan.curatedCost
    end

    -- Only keep a stock list that actually looks like a quartermaster's shelf.
    -- It can only add sets to the pool (see Model.MergeVendorSets), but a stray
    -- set-holding item elsewhere should not add one.
    if #scan.setIds >= 3 then
        record.setIds = scan.setIds
    end

    MCH.learned[scan.vendorId] = record
    MCH.Model.Invalidate(scan.vendorId)
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local function OnOpenStore()
    local scan = Store.Scan()
    if not scan then return end

    Remember(scan)
    Store.current = scan

    local result = MCH.Advisor.ForVendor(scan.vendorId)
    if not result then return end

    if MCH.db.chatMessage then
        MCH.Format.PrintToChat(result)
    end
    if MCH.db.showPanel then
        MCH.UI.Show(result, scan.vendorId)
    end
end

local function OnCloseStore()
    Store.current = nil
    MCH.UI.HideIfAuto()
end

function Store.Initialize()
    EVENT_MANAGER:RegisterForEvent(MCH.name, EVENT_OPEN_STORE, OnOpenStore)
    EVENT_MANAGER:RegisterForEvent(MCH.name, EVENT_CLOSE_STORE, OnCloseStore)
end
