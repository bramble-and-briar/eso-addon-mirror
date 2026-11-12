local ItemShare = {}
ItemShare.name = "ItemShare"
-- Kept in step with ## Version in ItemShare.txt. Written into the saved
-- variables so an uploaded file says which addon produced it, which is the only
-- reliable way to answer "am I actually running the new version?".
local ADDON_VERSION = "1.11.31"
-- Bumped whenever the saved layout changes shape. A file written by a different
-- number is not migrated: its tables are started over, so the file is rewritten in
-- the current layout on the next save.
local SAVED_VARS_VERSION = 5
local CURRENT_DISPLAY_NAME = GetDisplayName() or "@Unknown"

ItemShare.savedVars = nil

local SHARE_TEXTURE_PATH = "ItemShare/media/itemshare_share2.dds"
-- The standing-offer variant of the same glyph: the dome closes into a ring, so
-- "always shared" is readable at 16 px without needing a colour legend.
local ALWAYS_SHARE_TEXTURE_PATH = "ItemShare/media/itemshare_always.dds"
-- A reserve gets a badge of its own rather than a tint, and it keeps the glyph it
-- sits on: the amber tag says "some of this is mine", the parcel underneath still
-- says whether the offer is a plain share or a standing one.
local RESERVE_TEXTURE_PATH = "ItemShare/media/itemshare_reserve.dds"
local ALWAYS_RESERVE_TEXTURE_PATH = "ItemShare/media/itemshare_always_reserve.dds"
-- A reserve on an item that is not shared at all: the amber tag with no parcel under
-- it. Without a badge of its own a reserve on an unshared item was invisible, so the
-- only way to find out it needed clearing was to remember setting it.
local RESERVE_ONLY_TEXTURE_PATH = "ItemShare/media/itemshare_reserve_only.dds"
-- A share that has been on offer past the limit in the saved variables wears this
-- instead of the share glyph: same corner, same size, so nothing on the slot moves and
-- an item that has quietly become clutter reads as clutter at a glance.
local EXPIRED_TEXTURE_PATH = "ItemShare/media/itemshare_expired.dds"

local defaults = {
    sharedItems = {},
    alwaysShare = {},
    reserves = {},
    -- Reserves set in one place at a time, keyed by item link and location. The table
    -- above stays as the item-wide fallback an older file may have written.
    locationReserves = {},
    -- Which platform and which megaserver this file was written on. Both describe the
    -- account rather than an item, so they sit once at the top of the table: the
    -- website cannot tell a PC/EU offer from a PC/NA one without them, and nothing
    -- trades between those two worlds.
    platform = "",
    platformRaw = 0,
    world = "",
    worldName = "",
    -- A share refuses to be sold or deconstructed from the place it was made from,
    -- so an offer cannot be destroyed by accident while it is on the list.
    shareProtection = true,
    guildBankSharingEnabled = false,
    -- How long a share may stay on offer, in days, before its badge becomes the
    -- stopwatch. 0 is off. One number for the whole file rather than a flag on each
    -- share: what counts as "too long" is a decision about the list, and changing it
    -- needs no pass over the entries.
    expireDays = 0,
    -- Guilds are stored once, by ID, and pointed at rather than copied: every
    -- character's membership and every shared item used to carry its own list.
    guilds = {},
    characterGuilds = {},
    listWindowState = {
        left = nil,
        top = nil,
        isOpen = false,
    }
}

local PrintMessage
local RemoveItemFromShareByKey
-- Sharing and always sharing are one choice per item, so the code that turns one on
-- has to be able to clear the other from here onwards in the file.
local RemoveSharesForItemLink
local RemoveAlwaysShareForItemLink
local SaveAlwaysShareEntry
local SaveSharedEntry
local SaveSharedEntryFromSavedEntry
local BuildSharedItemKey
local IsSavedEntryEligibleForShare
local RefreshShareListWindow
local RefreshShareListWindowIfVisible
local IsItemLinkAlwaysShared
local CanModifyGuildBankShare
local SyncSharedItemsWithInventory
local RebuildSharedItemsWithInventory

-- Declared here because the badge and the list rows are built before the reserve
-- and standing-offer code they ask about runs for the first time.
local GetShareReserve
local ShareableCount
local GetAlwaysShareTable
local GetAlwaysShareKey
local BuildActualInventoryIndex
local TryRefreshInventoryVisuals
-- The reserve prompt and the one place a reserve is written to everything that
-- records it. Both are assigned further down, once the tables and the panel exist.
local OpenShareReserveDialog
local ApplyShareReserve

-- What an entry holds and what it offers. Only the held count is stored: what is on
-- offer is the held count minus the reserve, and the reserve lives in its own table,
-- so neither number needs a copy on the entry that can drift from them.
GetEntryHeldCount = function(entry)
    return math.max(0, math.floor(tonumber(entry and entry.heldCount or 0) or 0))
end

GetEntryOfferedCount = function(entry)
    local link = entry and tostring(entry.itemLink or "") or ""
    return ShareableCount(link, GetEntryHeldCount(entry), entry and entry.locationKey or "")
end

local SECONDS_PER_DAY = 86400

local function GetExpireDays()
    local days = tonumber(ItemShare.savedVars and ItemShare.savedVars.expireDays) or 0
    if days <= 0 then
        return 0
    end
    return math.floor(days)
end

-- Days this share has been on offer, or nil when there is no timestamp to go by. An
-- unknown age is never treated as old: a file that predates the timestamps would
-- otherwise have every share show the stopwatch on its first load.
local function GetShareAgeInDays(entry)
    local firstDumpedAt = tonumber(entry and entry.firstDumpedAt) or 0
    local now = tonumber(GetTimeStamp()) or 0
    if firstDumpedAt <= 0 or now <= 0 or now < firstDumpedAt then
        return nil
    end
    return (now - firstDumpedAt) / SECONDS_PER_DAY
end

local function IsShareEntryExpired(entry)
    local days = GetExpireDays()
    if days <= 0 then
        return false
    end
    local age = GetShareAgeInDays(entry)
    return age ~= nil and age >= days
end

-- What the command reports back: how many shares are past the limit, out of how many.
local function CountSharesAboveExpireLimit()
    local sharedItems = (ItemShare.savedVars and ItemShare.savedVars.sharedItems) or {}
    local expired, total = 0, 0
    for _, entry in pairs(sharedItems) do
        if type(entry) == "table" and not entry.reserveOnly then
            total = total + 1
            if IsShareEntryExpired(entry) then
                expired = expired + 1
            end
        end
    end
    return expired, total
end

-- Which of the four badges belongs on an item: standing offer or plain share, with
-- an amber tag on either when a reserve is set on it.
local function GetShareBadgeTexture(itemLink, isAlways, locationKey)
    local reserve = (GetShareReserve and GetShareReserve(itemLink, locationKey)) or 0
    if reserve > 0 then
        return isAlways and ALWAYS_RESERVE_TEXTURE_PATH or RESERVE_TEXTURE_PATH
    end
    return isAlways and ALWAYS_SHARE_TEXTURE_PATH or SHARE_TEXTURE_PATH
end

-- One wording for "keeping some back", so the bag badge, the list window and the
-- chat messages cannot drift apart.
local function DescribeReserveLine(itemLink, entry)
    local reserve = (GetShareReserve and GetShareReserve(itemLink, entry and entry.locationKey)) or 0
    if reserve <= 0 then
        return nil
    end

    local held = GetEntryHeldCount(entry)
    if held <= 0 then
        return string.format("|cD8A24FKeeping %d back|r.", reserve)
    end

    return string.format(
        "|cD8A24FKeeping %d back|r - offering %d of %d held.",
        reserve,
        math.max(0, held - reserve),
        held
    )
end

ItemShare.ui = {
    listWindow = nil,
    listScroll = nil,
    listContent = nil,
    reloadButton = nil,
    rowControls = {}
}

local function SaveListWindowState()
    if not ItemShare.savedVars or not ItemShare.savedVars.listWindowState then
        return
    end

    local window = ItemShare.ui and ItemShare.ui.listWindow
    if not window then
        return
    end

    local left = window.GetLeft and window:GetLeft() or nil
    local top = window.GetTop and window:GetTop() or nil

    ItemShare.savedVars.listWindowState.left = left
    ItemShare.savedVars.listWindowState.top = top
    ItemShare.savedVars.listWindowState.isOpen = not window:IsHidden()
end

local function ApplySavedListWindowPosition(window)
    if not ItemShare.savedVars or not ItemShare.savedVars.listWindowState then
        return
    end

    local state = ItemShare.savedVars.listWindowState
    if state.left == nil or state.top == nil then
        return
    end

    window:ClearAnchors()
    window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, state.left, state.top)
end

-- The window lists what is actually on offer. A standing offer counts as on offer
-- as soon as a copy is in a bag we can read, even when no copy was ever marked by
-- hand, so the always-share table is folded in here. Both sources are counted the
-- same way - what is held above the reserve - and an item with nothing above its
-- reserve is not listed at all, because offering zero is not an offer.
local function GetShareListEntries()
    local entries = {}
    local linksListed = {}
    -- Which item-and-place pairs already have a row, so a reserve set on a place that
    -- is shared anyway does not add a second row beside its own.
    local placesListed = {}

    -- Asked at most once per refresh, and only when a number has to come from the
    -- bags, so an ordinary refresh stays as cheap as it was.
    local inventoryIndex = nil
    local function GetListInventoryIndex()
        if inventoryIndex == nil then
            inventoryIndex = (BuildActualInventoryIndex and BuildActualInventoryIndex()) or false
        end
        return inventoryIndex or nil
    end

    -- The place a share was filed from, used to keep the rows apart. Older entries
    -- stored only the label, so the label stands in for the key when there is none.
    local function GetEntryLocationKey(entry)
        local locationKey = tostring(entry and entry.locationKey or "")
        if locationKey == "" then
            locationKey = tostring(entry and entry.sharedFrom or "")
        end
        return locationKey
    end

    -- One row per item per place, not one row per stack. Stacks of the same thing in
    -- one bag are one offer - two stacks of soul gems in the bank are 400 to hand
    -- over - but a share in the bags and a share in the bank stay two rows, because
    -- that is how they are taken back: one row, one place, one removal. Adding them
    -- up across places made the count something you could point at in neither bag.
    local sharesByPlace = {}
    local shareOrder = {}

    for itemKey, entry in pairs(ItemShare.savedVars.sharedItems or {}) do
        local link = tostring(entry.itemLink or "")
        local locationKey = GetEntryLocationKey(entry)
        local groupKey = link ~= "" and (link .. "||" .. locationKey) or tostring(itemKey)

        local group = sharesByPlace[groupKey]
        if not group then
            group = {
                itemKey = tostring(itemKey),
                entry = entry,
                itemLink = link,
                locationKey = locationKey,
                stacksHeld = 0,
                stackCount = 0,
            }
            sharesByPlace[groupKey] = group
            shareOrder[#shareOrder + 1] = groupKey
        end

        group.stacksHeld = group.stacksHeld + GetEntryHeldCount(entry)
        group.stackCount = group.stackCount + 1
    end

    table.sort(shareOrder)

    for _, groupKey in ipairs(shareOrder) do
        local group = sharesByPlace[groupKey]
        local entry = group.entry
        local link = group.itemLink
        -- The reserve is this place's: the bank's soul gems can keep 50 back while the
        -- ones in your bags keep none, and each row subtracts only its own.
        local reserve = link ~= "" and GetShareReserve(link, group.locationKey) or 0

        -- The count comes from the shares themselves, not from measuring the bags
        -- again. Each entry was written with the whole bag's worth of that item, and
        -- sync, rebuild and the login pass keep those counts in step, so opening
        -- this window is a read of saved data. That is also why the bank's row is
        -- here while the bank is shut: it was counted when it was shared.
        local held = group.stacksHeld
        local count = ShareableCount(link, held, group.locationKey)

        -- A share that is entirely inside its reserve is still a share: it stays in
        -- the window with nothing on offer, so the reserve can be seen and changed
        -- instead of the item quietly vanishing until more are picked up.
        if count > 0 or reserve > 0 then
            local copy = {}
            for k, v in pairs(entry) do
                copy[k] = v
            end

            copy.itemKey = group.itemKey
            copy.itemLink = link
            copy.locationKey = group.locationKey
            copy.count = count
            copy.reserve = reserve
            copy.heldCount = held
            copy.stackCount = group.stackCount

            -- The one place this row counts, and the only place it can be taken back
            -- from. Naming a single place is what makes the row removable.
            local label = tostring(copy.sharedFrom or "")
            if label == "" then
                label = group.locationKey
            end
            copy.sharedFrom = label

            entries[#entries + 1] = copy

            if link ~= "" then
                linksListed[link] = true
                placesListed[link .. "||" .. group.locationKey] = true
            end
        end
    end

    local alwaysShare = ItemShare.savedVars.alwaysShare
    if type(alwaysShare) == "table" then
        local waiting = {}
        for _, alwaysEntry in pairs(alwaysShare) do
            if type(alwaysEntry) == "table" then
                local entryLink = tostring(alwaysEntry.itemLink or "")
                local entryPlace = tostring(alwaysEntry.locationKey or "")
                -- A share in one bag says nothing about an offer in another, so the
                -- offer is only folded away by a share in its own place.
                if entryLink ~= ""
                    and not placesListed[BuildSharedItemKey(entryLink, entryPlace)] then
                    waiting[#waiting + 1] = alwaysEntry
                end
            end
        end

        local alwaysIndex = #waiting > 0 and GetListInventoryIndex() or nil
        for _, alwaysEntry in ipairs(waiting) do
            local link = tostring(alwaysEntry.itemLink or "")
            if link ~= "" then
                -- The place it was marked in, not wherever a copy happens to be now.
                -- A standing offer's number is what that one place holds: hand the
                -- last one over and the row reads 0 offered, pick one up again and it
                -- reads 1, without the row moving to another bag in between.
                local locationKey = tostring(alwaysEntry.locationKey or "")
                local sharedFrom = tostring(alwaysEntry.sharedFrom or "")
                local held = GetEntryHeldCount(alwaysEntry)
                local itemData = nil

                if alwaysIndex and locationKey ~= "" then
                    local place = alwaysIndex.countsByEntryKey
                        and alwaysIndex.countsByEntryKey[BuildSharedItemKey(link, locationKey)]
                    if type(place) == "table" then
                        held = math.max(0, tonumber(place.count or 0) or 0)
                        sharedFrom = tostring(place.sharedFrom or sharedFrom)
                        itemData = place.itemData
                    end
                end

                entries[#entries + 1] = {
                    itemKey = BuildSharedItemKey(link, locationKey),
                    itemLink = link,
                    itemName = tostring((itemData and itemData.itemName) or alwaysEntry.itemName or link),
                    itemType = (itemData and itemData.itemType) or alwaysEntry.itemType,
                    itemTypeName = (itemData and itemData.itemTypeName) or alwaysEntry.itemTypeName,
                    quality = (itemData and itemData.quality) or alwaysEntry.quality,
                    trait = (itemData and itemData.trait) or alwaysEntry.trait,
                    heldCount = held,
                    reserve = GetShareReserve(link, locationKey),
                    count = ShareableCount(link, held, locationKey),
                    sharedFrom = sharedFrom ~= "" and sharedFrom or "Not in a bag",
                    locationKey = locationKey,
                    bagId = (itemData and itemData.bagId) or alwaysEntry.bagId,
                    slotIndex = (itemData and itemData.slotIndex) or alwaysEntry.slotIndex,
                    alwaysOnly = true,
                }

                placesListed[link .. "||" .. locationKey] = true
                linksListed[link] = true
            end
        end
    end

    -- A reserve belongs to the item in one place, so it can be set on an item that is
    -- not shared at all - the amber tag with no parcel under it in that bag - and an
    -- item shared in one bag can carry a reserve in another. Every place keeps its
    -- own row; an item-wide reserve keeps the single row it always had.
    local reserveRows = {}

    local function AddReserveRow(link, locationKey, amount)
        local linkText = tostring(link or "")
        local placeKey = tostring(locationKey or "")
        if linkText == "" or amount <= 0 then
            return
        end
        if placesListed[linkText .. "||" .. placeKey] then
            return
        end

        placesListed[linkText .. "||" .. placeKey] = true
        reserveRows[#reserveRows + 1] = { link = linkText, locationKey = placeKey }
    end

    local locationReserves = ItemShare.savedVars.locationReserves
    if type(locationReserves) == "table" then
        for placeKey, amount in pairs(locationReserves) do
            local link, locationKey = string.match(tostring(placeKey or ""), "^(.*)||([^|]*)$")
            local keep = math.max(0, math.floor(tonumber(amount or 0) or 0))
            if link then
                AddReserveRow(link, locationKey, keep)
            end
        end
    end

    local reserves = ItemShare.savedVars.reserves
    if type(reserves) == "table" then
        for link, amount in pairs(reserves) do
            local linkText = tostring(link or "")
            local keep = math.max(0, math.floor(tonumber(amount or 0) or 0))
            if keep > 0 and linkText ~= "" and not linksListed[linkText] then
                AddReserveRow(linkText, "", keep)
            end
        end
    end

    if #reserveRows > 0 then
        table.sort(reserveRows, function(left, right)
            if left.link ~= right.link then
                return left.link < right.link
            end
            return tostring(left.locationKey) < tostring(right.locationKey)
        end)

        local reserveIndex = GetListInventoryIndex()
        for _, reserveRow in ipairs(reserveRows) do
            local link = reserveRow.link
            local locationKey = reserveRow.locationKey
            local location = nil
            local itemData = nil
            local held = 0

            if reserveIndex then
                if locationKey ~= "" then
                    local placeEntry = reserveIndex.countsByEntryKey
                        and reserveIndex.countsByEntryKey[BuildSharedItemKey(link, locationKey)]
                    if placeEntry then
                        held = math.max(0, tonumber(placeEntry.count or 0) or 0)
                        itemData = placeEntry.itemData
                        location = {
                            sharedFrom = placeEntry.sharedFrom,
                            locationKey = locationKey,
                            bagId = placeEntry.bagId,
                            slotIndex = placeEntry.slotIndex,
                        }
                    else
                        location = { locationKey = locationKey }
                    end
                else
                    location = reserveIndex.locationsByLink and reserveIndex.locationsByLink[link] or nil
                    itemData = location and location.itemData or nil
                    local placeEntry = location and reserveIndex.countsByEntryKey
                        and reserveIndex.countsByEntryKey[BuildSharedItemKey(link, tostring(location.locationKey or ""))]
                    held = math.max(0, tonumber(placeEntry and placeEntry.count or 0) or 0)
                end
            end

            entries[#entries + 1] = {
                itemKey = BuildSharedItemKey(link, locationKey),
                itemLink = link,
                itemName = tostring(itemData and itemData.itemName or link),
                itemType = itemData and itemData.itemType,
                itemTypeName = itemData and itemData.itemTypeName,
                quality = itemData and itemData.quality,
                trait = itemData and itemData.trait,
                itemId = itemData and itemData.itemId,
                icon = itemData and itemData.icon,
                esoDetails = itemData and itemData.esoDetails,
                heldCount = held,
                reserve = GetShareReserve(link, locationKey),
                -- Nothing is on offer from a reserved item that is not shared, so the
                -- count column says zero while the row still shows what is kept back.
                count = 0,
                sharedFrom = location and tostring(location.sharedFrom or "Not in a bag") or "Not in a bag",
                locationKey = location and tostring(location.locationKey or locationKey) or locationKey,
                bagId = location and location.bagId or nil,
                slotIndex = location and location.slotIndex or nil,
                reserveOnly = true,
            }
        end
    end

    table.sort(entries, function(a, b)
        local aName = tostring(a.itemName or a.itemLink or "")
        local bName = tostring(b.itemName or b.itemLink or "")
        local aSortName = zo_strlower(aName)
        local bSortName = zo_strlower(bName)
        if aSortName ~= bSortName then
            return aSortName < bSortName
        end
        if aName ~= bName then
            return aName < bName
        end

        local aLocation = tostring(a.sharedFrom or "")
        local bLocation = tostring(b.sharedFrom or "")
        if aLocation ~= bLocation then
            return aLocation < bLocation
        end

        return tostring(a.itemLink or "") < tostring(b.itemLink or "")
    end)

    return entries
end


local function CreateShareListWindow()
    if ItemShare.ui.listWindow then
        return ItemShare.ui.listWindow
    end

    local wm = WINDOW_MANAGER
    local window = wm:CreateTopLevelWindow("ItemShareShareListWindow")
    -- Registered before anything below can throw. A half-built window is still better
    -- than a second CreateTopLevelWindow on the next call, which errors with "already
    -- exists" and leaves the list unreachable until a reload.
    ItemShare.ui.listWindow = window
    window:SetDimensions(720, 520)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetClampedToScreen(true)
    window:SetHidden(true)
    window:SetHandler("OnMoveStop", function()
        SaveListWindowState()
    end)
    window:SetHandler("OnHide", function()
        SaveListWindowState()
    end)
    window:SetHandler("OnShow", function()
        SaveListWindowState()
    end)

    ApplySavedListWindowPosition(window)

    local backdrop = wm:CreateControl(nil, window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    backdrop:SetCenterColor(0.05, 0.05, 0.05, 0.95)
    backdrop:SetEdgeColor(0.7, 0.7, 0.7, 1)
    backdrop:SetEdgeTexture(nil, 1, 1, 2, 0)

    local title = wm:CreateControl(nil, window, CT_LABEL)
    title:SetFont("ZoFontWinH1")
    title:SetColor(1, 1, 1, 1)
    title:SetText("Shared Items")
    title:SetAnchor(TOPLEFT, window, TOPLEFT, 18, 14)

    local closeButton = wm:CreateControl(nil, window, CT_BUTTON)
    closeButton:SetDimensions(32, 32)
    closeButton:SetAnchor(TOPRIGHT, window, TOPRIGHT, -8, 8)
    closeButton:SetNormalTexture("/esoui/art/buttons/decline_up.dds")
    closeButton:SetPressedTexture("/esoui/art/buttons/decline_down.dds")
    closeButton:SetMouseOverTexture("/esoui/art/buttons/decline_over.dds")
    closeButton:SetHandler("OnClicked", function()
        window:SetHidden(true)
        SaveListWindowState()
    end)

    local shareHeader = wm:CreateControl(nil, window, CT_LABEL)
    shareHeader:SetFont("ZoFontGameSmall")
    shareHeader:SetColor(1, 1, 1, 1)
    shareHeader:SetText("")
    shareHeader:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 54)
    shareHeader:SetDimensions(20, 20)

    local itemHeader = wm:CreateControl(nil, window, CT_LABEL)
    itemHeader:SetFont("ZoFontGameSmall")
    itemHeader:SetColor(1, 1, 1, 1)
    itemHeader:SetText("Item")
    itemHeader:SetAnchor(TOPLEFT, window, TOPLEFT, 44, 54)

    local countHeader = wm:CreateControl(nil, window, CT_LABEL)
    countHeader:SetFont("ZoFontGameSmall")
    countHeader:SetColor(1, 1, 1, 1)
    countHeader:SetText("Count")
    countHeader:SetAnchor(TOPLEFT, window, TOPLEFT, 390, 54)
    countHeader:SetWidth(50)
    countHeader:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    local locationHeader = wm:CreateControl(nil, window, CT_LABEL)
    locationHeader:SetFont("ZoFontGameSmall")
    locationHeader:SetColor(1, 1, 1, 1)
    locationHeader:SetText("Location")
    locationHeader:SetAnchor(TOPLEFT, window, TOPLEFT, 460, 54)

    local instructionLabel = wm:CreateControl(nil, window, CT_LABEL)
    instructionLabel:SetFont("ZoFontGameSmall")
    instructionLabel:SetColor(0.85, 0.85, 0.85, 1)
    instructionLabel:SetText("Right Click a row to cycle: Share, Always Share, Stop Sharing")
    instructionLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    instructionLabel:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 16, -48)
    instructionLabel:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -16, -48)
    instructionLabel:SetHeight(20)

    local reloadButton = wm:CreateControl(nil, window, CT_BUTTON)
    reloadButton:SetDimensions(200, 36)
    reloadButton:SetAnchor(BOTTOM, window, BOTTOM, 0, -12)
    reloadButton:SetFont("ZoFontGame")
    reloadButton:SetText("Reload UI")
    -- No button art: the textured frame was loud enough to pull the eye off the list
    -- itself, and a plain label reads as the quiet action it is.
    reloadButton:SetClickSound(SOUNDS.DIALOG_ACCEPT)
    reloadButton:SetHandler("OnClicked", function()
        SyncSharedItemsWithInventory()
        ReloadUI()
    end)

    -- Named explicitly and reused if it is already there. An unnamed control created
    -- from a virtual template takes the template's own name, so the moment anything
    -- else in the client has a control called "Scroll", creating this one fails with
    -- "Unable to create control [Scroll]. This control already exists" - which is the
    -- intermittent error this replaces. Reusing also covers a previous attempt that
    -- built the scroll and then threw before the window was finished.
    local scrollName = "ItemShareShareListScroll"
    local scroll = _G[scrollName]

    if scroll then
        scroll:SetParent(window)
    else
        scroll = wm:CreateControlFromVirtual(scrollName, window, "ZO_ScrollContainer")
    end

    scroll:SetAnchor(TOPLEFT, window, TOPLEFT, 16, 74)
    scroll:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -16, -72)
    scroll:SetMouseEnabled(true)

    local content = scroll:GetNamedChild("ScrollChild")
    content:ClearAnchors()
    content:SetAnchor(TOPLEFT, scroll, TOPLEFT, 0, 0)
    content:SetDimensions(1, 1)

    window:SetHandler("OnKeyUp", function(_, key, ctrl, alt, command)
        if ctrl or alt or command then
            return
        end

        if key == KEY_R or key == string.byte("R") or key == string.byte("r") then
            ReloadUI()
        end
    end)

    ItemShare.ui.listWindow = window
    ItemShare.ui.listScroll = scroll
    ItemShare.ui.listContent = content
    ItemShare.ui.reloadButton = reloadButton
    return window
end

local function GetOrCreateShareListRow(index)
    local existing = ItemShare.ui.rowControls[index]
    if existing then
        return existing
    end

    local wm = WINDOW_MANAGER
    local row = wm:CreateControl("ItemShareShareListRow" .. tostring(index), ItemShare.ui.listContent, CT_CONTROL)
    row:SetAnchor(TOPLEFT, ItemShare.ui.listContent, TOPLEFT, 0, (index - 1) * 24)
    row:SetDimensions(660, 22)
    row:SetMouseEnabled(true)

    local rowBackdrop = wm:CreateControl(nil, row, CT_BACKDROP)
    rowBackdrop:SetAnchorFill(row)
    rowBackdrop:SetCenterColor(0, 0, 0, 0)
    rowBackdrop:SetEdgeColor(0, 0, 0, 0)
    rowBackdrop:SetMouseEnabled(false)

    local statusIcon = wm:CreateControl(nil, row, CT_TEXTURE)
    statusIcon:SetAnchor(LEFT, row, LEFT, 2, 0)
    statusIcon:SetDimensions(18, 18)
    statusIcon:SetDrawLayer(DL_OVERLAY)
    statusIcon:SetDrawTier(DT_HIGH)
    statusIcon:SetTexture(SHARE_TEXTURE_PATH)
    statusIcon:SetMouseEnabled(true)

    local itemLabel = wm:CreateControl(nil, row, CT_LABEL)
    itemLabel:SetAnchor(TOPLEFT, row, TOPLEFT, 28, 0)
    itemLabel:SetDimensions(334, 22)
    itemLabel:SetFont("ZoFontGameSmall")
    itemLabel:SetColor(1, 1, 1, 1)
    itemLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    if itemLabel.SetMaxLineCount then
        itemLabel:SetMaxLineCount(1)
    end
    itemLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    itemLabel:SetMouseEnabled(true)

    local countLabel = wm:CreateControl(nil, row, CT_LABEL)
    countLabel:SetAnchor(TOPLEFT, row, TOPLEFT, 370, 0)
    countLabel:SetDimensions(50, 22)
    countLabel:SetFont("ZoFontGameSmall")
    countLabel:SetColor(1, 1, 1, 1)
    countLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    if countLabel.SetMaxLineCount then
        countLabel:SetMaxLineCount(1)
    end
    countLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    countLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    local locationLabel = wm:CreateControl(nil, row, CT_LABEL)
    locationLabel:SetAnchor(TOPLEFT, row, TOPLEFT, 440, 0)
    locationLabel:SetAnchor(TOPRIGHT, row, TOPRIGHT, 0, 0)
    locationLabel:SetFont("ZoFontGameSmall")
    locationLabel:SetColor(1, 1, 1, 1)
    locationLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    if locationLabel.SetMaxLineCount then
        locationLabel:SetMaxLineCount(1)
    end
    locationLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local function IsGuildBankEntryDisabled()
        local isGuildBankEntry = row.entryData and tostring(row.entryData.locationKey or ""):find("guildbank", 1, true) == 1
        if not isGuildBankEntry then
            return false
        end

        local guildIdForEntry = nil
        if row.entryData then
            guildIdForEntry = tonumber(string.match(tostring(row.entryData.locationKey or ""), "^guildbank:(%d+)$"))
        end

        return not CanModifyGuildBankShare(BAG_GUILDBANK, row.entryData and row.entryData.slotIndex, guildIdForEntry)
    end

    local function RefreshRowAppearance()
        local isDisabled = IsGuildBankEntryDisabled()
        local isActive = row.isMouseOver and true or false

        if isActive then
            rowBackdrop:SetCenterColor(0.85, 0.72, 0.35, 0.14)
        elseif (tonumber(row.rowIndex or 0) % 2) == 0 then
            rowBackdrop:SetCenterColor(1, 1, 1, 0.05)
        else
            rowBackdrop:SetCenterColor(0, 0, 0, 0)
        end

        if isDisabled then
            itemLabel:SetColor(0.55, 0.55, 0.55, 1)
            countLabel:SetColor(0.55, 0.55, 0.55, 1)
            locationLabel:SetColor(0.55, 0.55, 0.55, 1)
            statusIcon:SetAlpha(0.35)
        else
            itemLabel:SetColor(1, 1, 1, 1)
            countLabel:SetColor(1, 1, 1, 1)
            locationLabel:SetColor(1, 1, 1, 1)
            statusIcon:SetAlpha(1)
        end
    end

    local function updateRowSharedVisuals()
        local isShared = row.entryKey and ItemShare.savedVars and ItemShare.savedVars.sharedItems and ItemShare.savedVars.sharedItems[row.entryKey] ~= nil
        local link = row.itemLink or (row.entryData and row.entryData.itemLink) or ""
        local isAlways = link ~= "" and IsItemLinkAlwaysShared(link, (row.entryData and row.entryData.locationKey) or row.locationKey)

        -- A standing offer has no share entry to find, so "shared" has to include it,
        -- and the badge has to come from the same function the rest of the addon uses:
        -- picking a texture here by hand lost the amber reserve tag after a toggle.
        -- A reserve can outlive the share it was set beside, and then the badge is
        -- the amber tag on its own rather than a parcel nobody can ask for. The same
        -- rule the bags use, so removing a share here does not leave a stale badge.
        local reserve = link ~= ""
                and ((GetShareReserve and GetShareReserve(link, row.entryData and row.entryData.locationKey)) or 0)
            or 0
        row.isReserveOnly = (not (isShared or isAlways)) and reserve > 0
        row.isShared = (isShared or isAlways) and true or false
        local isExpired = row.entryData ~= nil and IsShareEntryExpired(row.entryData)
        statusIcon:SetTexture(
            (row.isReserveOnly and RESERVE_ONLY_TEXTURE_PATH)
                or (isExpired and EXPIRED_TEXTURE_PATH)
                or GetShareBadgeTexture(link, isAlways, row.entryData and row.entryData.locationKey)
        )
        statusIcon:SetHidden(not (isShared or isAlways or row.isReserveOnly))
        RefreshRowAppearance()
    end

    local function handleRowMouseEnter()
        if ItemShare.ui and ItemShare.ui.hoveredRow and ItemShare.ui.hoveredRow ~= row then
            ItemShare.ui.hoveredRow.isMouseOver = false
            if ItemShare.ui.hoveredRow.RefreshAppearance then
                ItemShare.ui.hoveredRow:RefreshAppearance()
            end
        end

        row.isMouseOver = true
        if ItemShare.ui then
            ItemShare.ui.hoveredRow = row
        end
        RefreshRowAppearance()
    end

    local function toggleRowSharedState()
        local isGuildBankEntry = row.entryData and tostring(row.entryData.locationKey or ""):find("guildbank", 1, true) == 1
        local guildIdForEntry = nil
        if isGuildBankEntry and row.entryData then
            guildIdForEntry = tonumber(string.match(tostring(row.entryData.locationKey or ""), "^guildbank:(%d+)$"))
        end
        local canModifyGuildBankEntry = not isGuildBankEntry or CanModifyGuildBankShare(BAG_GUILDBANK, row.entryData and row.entryData.slotIndex, guildIdForEntry)

        if not canModifyGuildBankEntry then
            return
        end

        -- Right-click walks the three states and comes back round:
        -- not sharing -> sharing -> always sharing -> not sharing. Every step
        -- rewrites the tables and then redraws, so the row, the bag badge and the
        -- next click all agree on where the cycle is.
        local link = tostring(row.itemLink or (row.entryData and row.entryData.itemLink) or "")
        if link == "" then
            return
        end

        if row.isAlwaysOnly then
            -- Always sharing -> not sharing.
            local removed = RemoveAlwaysShareForItemLink(link, (row.entryData and row.entryData.locationKey) or row.locationKey)
            if not removed then
                return
            end

            TryRefreshInventoryVisuals()
            RefreshShareListWindowIfVisible()
            PrintMessage(string.format(
                "Stopped always sharing %s. It is not offered at all now.",
                tostring(removed.itemName or link)
            ))
            return
        end

        if row.isShared then
            -- Sharing -> always sharing. The share goes in the same step, because an
            -- item is offered one way at a time.
            local currentEntry = row.entryKey and ItemShare.savedVars.sharedItems[row.entryKey] or row.entryData
            local alwaysEntry = SaveAlwaysShareEntry(currentEntry, GetEntryHeldCount(currentEntry))

            if not alwaysEntry then
                PrintMessage(string.format(
                    "Could not always share %s. It is still shared from %s.",
                    tostring(currentEntry and currentEntry.itemName or link),
                    tostring(currentEntry and currentEntry.sharedFrom or "-")
                ))
                return
            end

            RemoveSharesForItemLink(link)
            TryRefreshInventoryVisuals()
            RefreshShareListWindowIfVisible()
            PrintMessage(string.format(
                "Always sharing %s now. It stays offered even when you do not have one.",
                tostring(alwaysEntry.itemName or link)
            ))
            return
        end

        -- Not sharing -> sharing. The checks below are the same ones the bag menu
        -- makes, so a bound item cannot slip in through this window.
        if not row.entryData then
            return
        end

        -- A reserved item that is not in a readable bag has nothing to file: the row
        -- knows only its link and its reserve, so there is no share to make of it
        -- until a copy turns up.
        if row.isReserveOnly
            and (tonumber(row.entryData.bagId) == nil or tonumber(row.entryData.slotIndex) == nil) then
            PrintMessage(string.format(
                "Cannot share %s yet: no copy of it is in a bag right now.",
                tostring(row.entryData.itemName or link or "that item")
            ))
            return
        end

        local isEligible, reason = IsSavedEntryEligibleForShare(row.entryData)
        if not isEligible then
            PrintMessage(string.format("Cannot add that item to share: %s", tostring(reason)))
            return
        end

        local savedEntry = SaveSharedEntryFromSavedEntry(row.entryData, false)
        if not savedEntry then
            PrintMessage("Could not re-add item from shared list window.")
            return
        end

        RemoveAlwaysShareForItemLink(savedEntry.itemLink, savedEntry.locationKey)
        TryRefreshInventoryVisuals()
        RefreshShareListWindowIfVisible()
        PrintMessage(string.format(
            "Sharing %s from %s (%d offered). Right-click again to always share it.",
            tostring(savedEntry.itemName or link),
            tostring(savedEntry.sharedFrom or "-"),
            GetEntryOfferedCount(savedEntry)
        ))

    end

    local function handleRowRightClick(button)
        local rightButton = MOUSE_BUTTON_INDEX_RIGHT or 2
        if button ~= rightButton then
            return false
        end

        toggleRowSharedState()
        return true
    end


    statusIcon:SetHandler("OnMouseEnter", function(self)
        handleRowMouseEnter()
        InitializeTooltip(InformationTooltip, self, BOTTOMLEFT, 0, -4)

        local link = row.itemLink or (row.entryData and row.entryData.itemLink)
        local lines = {}

        if row.isReserveOnly then
            lines[#lines + 1] = "|cD8A24FShare reserve|r"
            lines[#lines + 1] = "Nothing is shared from this item, but some is kept back."
            lines[#lines + 1] = "Right-click the row to add it to the shared list."
        elseif link and IsItemLinkAlwaysShared(link, (row.entryData and row.entryData.locationKey) or row.locationKey) then
            lines[#lines + 1] = "|cFFD266Always shared|r"
            lines[#lines + 1] = "You offer this whenever you have one."
        else
            lines[#lines + 1] = "|c00FF00Shared Item|r"
            lines[#lines + 1] = "This item is available to others."
        end

        local reserveLine = DescribeReserveLine(link, row.entryData)
        if reserveLine then
            lines[#lines + 1] = reserveLine
        end

        SetTooltipText(InformationTooltip, table.concat(lines, "\n"))
    end)

    statusIcon:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    itemLabel:SetHandler("OnMouseEnter", function(self)
        handleRowMouseEnter()
    end)

    itemLabel:SetHandler("OnMouseExit", function()
    end)

    itemLabel:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside then
            return
        end

        local didToggle = handleRowRightClick(button)
        if didToggle then
            return
        end

        local leftButton = MOUSE_BUTTON_INDEX_LEFT or 1
        if button == leftButton and row.itemLink and row.itemLink ~= "" then
            ZO_LinkHandler_OnLinkClicked(row.itemLink, button, self)
        end
    end)

    statusIcon:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside then
            return
        end

        handleRowRightClick(button)
    end)

    row:SetHandler("OnMouseEnter", function()
        handleRowMouseEnter()
    end)

    row:SetHandler("OnMouseExit", function()
        row.isMouseOver = false
        if ItemShare.ui and ItemShare.ui.hoveredRow == row then
            ItemShare.ui.hoveredRow = nil
        end
        RefreshRowAppearance()
    end)

    row:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside then
            return
        end

        handleRowRightClick(button)
    end)

    row.itemLabel = itemLabel
    row.countLabel = countLabel
    row.locationLabel = locationLabel
    row.statusIcon = statusIcon
    row.rowBackdrop = rowBackdrop
    row.UpdateSharedVisuals = updateRowSharedVisuals
    row.RefreshAppearance = RefreshRowAppearance
    ItemShare.ui.rowControls[index] = row
    return row
end

RefreshShareListWindow = function()
    local window = CreateShareListWindow()

    -- A window that exists but never finished being built has no scroll to put rows
    -- in; returning here keeps one bad load from turning into an error every refresh.
    if not ItemShare.ui.listContent then
        return
    end

    local entries = GetShareListEntries()
    local rowHeight = 24
    local contentWidth = math.max((ItemShare.ui.listScroll and ItemShare.ui.listScroll:GetWidth()) or 660, 660)

    for index, entry in ipairs(entries) do
        local row = GetOrCreateShareListRow(index)
        row:SetAnchor(TOPLEFT, ItemShare.ui.listContent, TOPLEFT, 0, (index - 1) * rowHeight)
        row:SetDimensions(contentWidth - 8, rowHeight)
        row:SetHidden(false)
        row.rowIndex = index
        row.itemLink = tostring(entry.itemLink or "")
        row.entryKey = tostring(entry.itemKey or BuildSharedItemKey(entry.itemLink, entry.locationKey))
        row.entryData = entry
        local displayText = row.itemLink ~= "" and row.itemLink or tostring(entry.itemName or "")
        local traitText = tostring(entry.trait or "")
        if traitText ~= "" then
            displayText = string.format("%s (%s)", displayText, traitText)
        end
        row.itemLabel:SetText(displayText)
        -- A reserved row that is not shared offers nothing, so its count is zero
        -- whatever the bags hold; what is held is shown beside the reserve instead.
        row.countLabel:SetText(tostring((entry.reserveOnly and 0) or GetEntryOfferedCount(entry)))

        -- The reserve is part of what the row has to say: "12" alone does not
        -- explain why a stack of 20 offers 8.
        local locationText = tostring(entry.sharedFrom or "-")
        local reserve = GetShareReserve(entry.itemLink, entry.locationKey)
        if reserve > 0 then
            local held = GetEntryHeldCount(entry)
            locationText = held > 0
                and string.format("%s - keep %d of %d", locationText, reserve, held)
                or string.format("%s - keep %d", locationText, reserve)
        end
        row.locationLabel:SetText(locationText)
        -- A row that only carries a reserve is not a share yet: right-clicking it
        -- adds one, so it has to look unshared or the toggle reads as a no-op.
        row.isShared = not (entry.reserveOnly and true or false)
        row.isAlwaysOnly = entry.alwaysOnly and true or false
        row.isReserveOnly = entry.reserveOnly and true or false
        -- Rows are recycled, so the badge is set from the entry on every refresh.
        -- Leaving it to creation time meant a removed standing offer kept its gold
        -- icon in this window until the row happened to be reused for something else.
        row.statusIcon:SetTexture(
            (entry.reserveOnly and RESERVE_ONLY_TEXTURE_PATH)
                or (IsShareEntryExpired(entry) and EXPIRED_TEXTURE_PATH)
                or GetShareBadgeTexture(entry.itemLink, IsItemLinkAlwaysShared(entry.itemLink, entry.locationKey), entry.locationKey)
        )
        row.statusIcon:SetHidden(false)
        if row.RefreshAppearance then
            row:RefreshAppearance()
        end
    end

    for index = #entries + 1, #ItemShare.ui.rowControls do
        local row = ItemShare.ui.rowControls[index]
        if row then
            row:SetHidden(true)
        end
    end

    local contentHeight = math.max(#entries * rowHeight, 1)
    ItemShare.ui.listContent:SetDimensions(contentWidth, contentHeight)
    window:SetHidden(false)
    SaveListWindowState()
end

RefreshShareListWindowIfVisible = function()
    local window = ItemShare.ui and ItemShare.ui.listWindow
    if window and not window:IsHidden() then
        RefreshShareListWindow()
    end
end

-- Every message this addon prints goes through here. It is a system message, so a
-- command's answer reaches chat whether or not anything else is on, and a slash command
-- that reports nothing is a bug rather than a setting.
PrintMessage = function(message)
    CHAT_ROUTER:AddSystemMessage("|cD8A24F[ItemShare]|r " .. tostring(message))
end

local function ConfirmReloadUI()
    local dialogName = "ITEM_SHARE_CONFIRM_RELOAD_UI"

    if not ItemShare.reloadDialogRegistered then
        ZO_Dialogs_RegisterCustomDialog(dialogName, {
            title = {
                text = "Reload UI",
            },
            mainText = {
                text = "Would you like to reload the UI?",
            },
            buttons = {
                [1] = {
                    text = SI_DIALOG_ACCEPT,
                    callback = function()
                        PrintMessage("Reloading UI.")
                        ReloadUI()
                    end,
                },
                [2] = {
                    text = SI_DIALOG_CANCEL,
                },
            },
        })
        ItemShare.reloadDialogRegistered = true
    end

    ZO_Dialogs_ShowDialog(dialogName)
end

local function GetNormalizedText(value)
    if not value or value == "" then
        return nil
    end
    return zo_strformat("<<t:1>>", value)
end

local function GetNormalizedItemName(bagId, slotIndex)
    return GetNormalizedText(GetItemName(bagId, slotIndex))
end

local function GetNormalizedItemLink(bagId, slotIndex)
    local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    if not itemLink or itemLink == "" then
        return nil
    end
    return itemLink
end

local function GetCurrentCharacterName()
    return GetNormalizedText(GetUnitName("player")) or "Unknown"
end

-- The platform arrives as one of the UI_PLATFORM_* numbers. The constants are read
-- rather than hardcoded, so a client that renumbers them still records the right name;
-- a number with no name of its own is recorded as "unknown" instead of guessed at.
local function GetPlatformToken(rawPlatform)
    local raw = tonumber(rawPlatform) or 0
    if raw > 0 then
        if UI_PLATFORM_PC and raw == UI_PLATFORM_PC then
            return "pc"
        elseif UI_PLATFORM_MAC and raw == UI_PLATFORM_MAC then
            return "mac"
        elseif UI_PLATFORM_PS4 and raw == UI_PLATFORM_PS4 then
            return "ps4"
        elseif UI_PLATFORM_XBOX and raw == UI_PLATFORM_XBOX then
            return "xbox"
        elseif UI_PLATFORM_STADIA and raw == UI_PLATFORM_STADIA then
            return "stadia"
        end
    end

    return "unknown"
end

-- GetWorldName is translated into the client's language and can read "PTS", so the raw
-- string is kept for display and a token is matched out of it for everything that has
-- to compare one file with another. The region has to stand on its own as a word: the
-- French "Mégaserveur" contains the letters "eu" and is not Europe.
local function GetWorldToken(worldName)
    local text = zo_strlower(tostring(worldName or ""))
    if text == "" then
        return ""
    end

    if string.find(text, "pts", 1, true) or string.find(text, "public test", 1, true) then
        return "pts"
    end

    if string.find(text, "%f[%a]na%f[%A]") then
        return "na"
    end

    if string.find(text, "%f[%a]eu%f[%A]") then
        return "eu"
    end

    return ""
end

-- Recorded once for the account and rewritten on every load, which is what keeps it
-- honest: if the same account plays the other megaserver, the next login says so and
-- the file stops claiming the old one. Identical values change nothing in the saved
-- file beyond the timestamp.
CaptureServerEnvironment = function()
    if not ItemShare.savedVars then
        return "", ""
    end

    local rawPlatform = 0
    if type(GetUIPlatform) == "function" then
        local ok, value = pcall(GetUIPlatform)
        if ok then
            rawPlatform = tonumber(value) or 0
        end
    end

    local worldName = ""
    if type(GetWorldName) == "function" then
        local ok, value = pcall(GetWorldName)
        if ok and value ~= nil then
            worldName = tostring(value)
        end
    end

    local saved = ItemShare.savedVars
    saved.platform = GetPlatformToken(rawPlatform)
    saved.platformRaw = rawPlatform
    saved.world = GetWorldToken(worldName)
    saved.worldName = worldName

    return saved.platform, saved.world
end

local function PrintServerEnvironment()
    local platform, world = CaptureServerEnvironment()
    local saved = ItemShare.savedVars or {}

    PrintMessage(string.format(
        "This file is recorded for %s on %s.",
        string.upper(tostring(platform ~= "" and platform or "unknown")),
        string.upper(tostring(world ~= "" and world or "unknown"))
    ))

    local worldName = tostring(saved.worldName or "")
    if worldName ~= "" then
        PrintMessage(string.format(
            "The game reports the megaserver as \"%s\" and the platform as %d.",
            worldName,
            tonumber(saved.platformRaw or 0) or 0
        ))
    end

    PrintMessage("Every share in this file is offered on that platform and megaserver only.")
end

local function GetCharacterGuilds()
    local guilds = {}

    if type(GetNumGuilds) ~= "function" or type(GetGuildId) ~= "function" then
        return guilds
    end

    local numGuilds = tonumber(GetNumGuilds()) or 0
    for guildIndex = 1, numGuilds do
        local guildId = tonumber(GetGuildId(guildIndex)) or 0
        if guildId > 0 then
            local guildName = ""
            if type(GetGuildName) == "function" then
                guildName = GetNormalizedText(GetGuildName(guildId)) or ""
            end

            guilds[#guilds + 1] = {
                guildId = guildId,
                guildName = guildName,
            }
        end
    end

    return guilds
end

-- Guilds are facts about the account, not about an item, so they are stored once
-- and everything else points at them. Before 1.10 the same names were written onto
-- every share, a second time as {guildId, guildName} pairs beside the ids in each
-- character snapshot, and a third time as an account-wide id->name map. IDs are the
-- key because guild names are not unique and can be renamed; the ID is the stable one.
GetSavedGuildRegistry = function()
    if not ItemShare.savedVars then
        return {}
    end

    if type(ItemShare.savedVars.guilds) ~= "table" then
        ItemShare.savedVars.guilds = {}
    end
    return ItemShare.savedVars.guilds
end

GetCharacterGuildSnapshots = function()
    if not ItemShare.savedVars then
        return {}
    end

    if type(ItemShare.savedVars.characterGuilds) ~= "table" then
        ItemShare.savedVars.characterGuilds = {}
    end
    return ItemShare.savedVars.characterGuilds
end

GetGuildNameById = function(guildId)
    local id = tonumber(guildId) or 0
    if id <= 0 then
        return ""
    end

    local guildName = GetSavedGuildRegistry()[tostring(id)]
    return type(guildName) == "string" and guildName or ""
end

-- Only a name the registry did not already hold counts as work, so a refresh on
-- every login writes nothing once the guild list has settled.
RecordGuildInRegistry = function(guildId, guildName)
    local id = tonumber(guildId) or 0
    local name = tostring(guildName or "")
    if id <= 0 or name == "" then
        return false
    end

    local registry = GetSavedGuildRegistry()
    local key = tostring(id)
    if registry[key] == name then
        return false
    end

    registry[key] = name
    return true
end

-- The game gives an account five guild slots, and every one of them is written,
-- including the empty ones: a file that listed only the guilds you are in could not be
-- told apart from one written before you left, while five slots with zeros in them show
-- exactly which have gone.
local MAX_GUILD_SLOTS = 5

-- Membership is per character because guilds are. A snapshot is now only the ids
-- and the time they were read; the names stay in the registry above.
local function RefreshGuildSnapshot()
    if not ItemShare.savedVars then
        return {}
    end

    local guilds = GetCharacterGuilds()
    local guildIds = {}

    for _, guild in ipairs(guilds) do
        guildIds[#guildIds + 1] = guild.guildId
        RecordGuildInRegistry(guild.guildId, guild.guildName)
    end

    for slot = #guildIds + 1, MAX_GUILD_SLOTS do
        guildIds[slot] = 0
    end

    local now = GetTimeStamp()
    GetCharacterGuildSnapshots()[GetCurrentCharacterName()] = {
        guildIds = guildIds,
        updatedAt = now,
    }

    return guilds
end

local function GuildIdFromLocationKey(locationKey)
    return tonumber(string.match(tostring(locationKey or ""), "^guildbank:(%d+)$"))
end

-- Keys look like "itemLink||locationKey", and an item link contains single pipes of
-- its own, so the split is taken at the last double pipe.
local function LocationKeyOfSavedKey(savedKey)
    return tostring(savedKey or ""):match("^.*||(.*)$") or ""
end

-- Leaving a guild leaves its bank behind: a share or reserve filed against that guild's
-- id can never be reached again, because the bank cannot be opened, and the sync that
-- drops items no longer held deliberately keeps anything it could not look at. So they
-- are removed here, where the guild list is known. A guild id that no character on the
-- account is in any more takes its name with it.
PruneDepartedGuilds = function(quiet)
    local removedShares, removedReserves, removedNames = 0, 0, 0
    if not ItemShare.savedVars then
        return removedShares, removedReserves, removedNames
    end

    local guilds = GetCharacterGuilds()

    -- Nothing is removed until the guild list has actually loaded. An empty list this
    -- early in a login means "not read yet", and reading that as "in no guilds" would
    -- delete every guild bank share the player has.
    if #guilds == 0 then
        return removedShares, removedReserves, removedNames
    end

    local currentIds = {}
    for _, guild in ipairs(guilds) do
        currentIds[tostring(guild.guildId)] = true
    end

    local function IsDeparted(locationKey)
        local guildId = GuildIdFromLocationKey(locationKey)
        if not guildId then
            return false
        end
        return currentIds[tostring(guildId)] ~= true
    end

    local sharedItems = ItemShare.savedVars.sharedItems or {}
    local departedShareKeys = {}
    for itemKey, entry in pairs(sharedItems) do
        if type(entry) == "table" and IsDeparted(entry.locationKey) then
            departedShareKeys[#departedShareKeys + 1] = itemKey
        end
    end
    for _, itemKey in ipairs(departedShareKeys) do
        sharedItems[itemKey] = nil
        removedShares = removedShares + 1
    end

    local locationReserves = ItemShare.savedVars.locationReserves or {}
    local departedReserveKeys = {}
    for savedKey in pairs(locationReserves) do
        if IsDeparted(LocationKeyOfSavedKey(savedKey)) then
            departedReserveKeys[#departedReserveKeys + 1] = savedKey
        end
    end
    for _, savedKey in ipairs(departedReserveKeys) do
        locationReserves[savedKey] = nil
        removedReserves = removedReserves + 1
    end

    -- The registry is account-wide, so a name goes only when no character's snapshot
    -- still points at that guild.
    local stillKnown = {}
    for _, snapshot in pairs(GetCharacterGuildSnapshots()) do
        local ids = type(snapshot) == "table" and snapshot.guildIds or nil
        if type(ids) == "table" then
            for _, guildId in ipairs(ids) do
                local id = tonumber(guildId) or 0
                if id > 0 then
                    stillKnown[tostring(id)] = true
                end
            end
        end
    end

    local registry = GetSavedGuildRegistry()
    local departedNameKeys = {}
    for guildId in pairs(registry) do
        if not stillKnown[tostring(guildId)] then
            departedNameKeys[#departedNameKeys + 1] = guildId
        end
    end
    for _, guildId in ipairs(departedNameKeys) do
        registry[guildId] = nil
        removedNames = removedNames + 1
    end

    if (removedShares > 0 or removedReserves > 0) and not quiet then
        PrintMessage(string.format(
            "Removed %d share%s and %d reserve%s filed against guilds you are no longer in.",
            removedShares,
            removedShares == 1 and "" or "s",
            removedReserves,
            removedReserves == 1 and "" or "s"
        ))
    end

    return removedShares, removedReserves, removedNames
end



local function GetSelectedGuildBankLocationInfo()
    local guildId = 0
    if GetSelectedGuildBankId then
        guildId = tonumber(GetSelectedGuildBankId()) or 0
    end

    local guildName = ""
    if guildId > 0 and GetGuildName then
        guildName = GetNormalizedText(GetGuildName(guildId)) or ""
    end

    if guildId > 0 and guildName ~= "" then
        return string.format("guildbank:%d", guildId), string.format("Guild Bank (%s)", guildName)
    elseif guildId > 0 then
        return string.format("guildbank:%d", guildId), "Guild Bank"
    end

    return "guildbank", "Guild Bank"
end

CanModifyGuildBankShare = function(bagId, slotIndex, guildId)
    if not (BAG_GUILDBANK and bagId == BAG_GUILDBANK) then
        return true
    end

    if not (ItemShare.savedVars and ItemShare.savedVars.guildBankSharingEnabled) then
        return false
    end

    if type(CanUseBank) == "function" and GUILD_PERMISSION_BANK_WITHDRAW ~= nil then
        return CanUseBank(GUILD_PERMISSION_BANK_WITHDRAW)
    end

    local selectedGuildId = tonumber(guildId)
    if (not selectedGuildId or selectedGuildId <= 0) and type(GetSelectedGuildBankId) == "function" then
        selectedGuildId = tonumber(GetSelectedGuildBankId()) or 0
    end

    if selectedGuildId > 0
        and type(DoesPlayerHaveGuildPermission) == "function"
        and GUILD_PERMISSION_BANK_WITHDRAW ~= nil then
        return DoesPlayerHaveGuildPermission(selectedGuildId, GUILD_PERMISSION_BANK_WITHDRAW) == true
    end

    return false
end

-- The ten home storage chests are separate bags, so they are worth naming one
-- by one: indices are kept explicit because a missing constant would otherwise
-- shift every later chest by one.
local HOUSE_STORAGE_BAGS = {
    [1] = BAG_HOUSE_BANK_ONE,
    [2] = BAG_HOUSE_BANK_TWO,
    [3] = BAG_HOUSE_BANK_THREE,
    [4] = BAG_HOUSE_BANK_FOUR,
    [5] = BAG_HOUSE_BANK_FIVE,
    [6] = BAG_HOUSE_BANK_SIX,
    [7] = BAG_HOUSE_BANK_SEVEN,
    [8] = BAG_HOUSE_BANK_EIGHT,
    [9] = BAG_HOUSE_BANK_NINE,
    [10] = BAG_HOUSE_BANK_TEN,
}

local function GetHouseStorageChestIndex(bagId)
    for index = 1, 10 do
        local candidate = HOUSE_STORAGE_BAGS[index]
        if candidate and bagId == candidate then
            return index
        end
    end
    return 0
end

-- Best effort, and deliberately pcall'd: the zone name is the house name while
-- the player is inside a home, which is the difference between "the furnishing
-- vault" and "the furnishing vault in Mournoth Keep".
local function GetCurrentZoneDisplayName()
    if not GetUnitZone then
        return ""
    end
    local ok, zoneName = pcall(GetUnitZone, "player")
    if not ok or type(zoneName) ~= "string" then
        return ""
    end
    return GetNormalizedText(zoneName) or ""
end

-- One bucket per house. Furniture offered from a house is not a stack in a bag, so
-- the house is part of the key: two houses never collapse into one row, and no bag
-- can ever confirm or deny the share.
IsPlacedLocationKey = function(locationKey)
    local text = tostring(locationKey or "")
    return string.sub(text, 1, 7) == "placed:"
end

-- Where a /ishare scan files its pieces. The zone name is the house name while the
-- character is inside a home, which is what makes "Placed (Mournoth Keep)" possible;
-- with no house there is nothing to scan and nothing is filed.
local function GetPlacedLocationInfo(houseName)
    local name = tostring(houseName or "")
    if name ~= "" then
        return "placed:" .. zo_strlower(name), string.format("Placed (%s)", name)
    end
    return "placed", "Placed"
end

-- The ten home storage chests can each be renamed in game, and the name is the only
-- thing that makes one findable: "House Storage 8" says nothing about what is inside it.
-- Each chest is a collectible, so the game can name its bag - the nickname the player
-- gave it first, then the collectible's own name, then the slot number.
local function GetHouseStorageDisplayName(bagId, chestIndex)
    local fallback = string.format("House Storage %d", chestIndex)

    if not (GetCollectibleForBag and GetCollectibleNickname and GetCollectibleName) then
        return fallback
    end

    local idOk, collectibleId = pcall(GetCollectibleForBag, bagId)
    if not idOk or type(collectibleId) ~= "number" or collectibleId <= 0 then
        return fallback
    end

    local nicknameOk, nickname = pcall(GetCollectibleNickname, collectibleId)
    if nicknameOk and type(nickname) == "string" then
        nickname = string.gsub(nickname, "^%s*(.-)%s*$", "%1")
        if nickname ~= "" then
            return nickname
        end
    end

    local nameOk, collectibleName = pcall(GetCollectibleName, collectibleId)
    if nameOk and type(collectibleName) == "string" and collectibleName ~= "" then
        local normalizedName = GetNormalizedText(collectibleName)
        if normalizedName and normalizedName ~= "" then
            return normalizedName
        end
    end

    return fallback
end

local function GetBagLocationInfo(bagId)
    if bagId == BAG_BACKPACK then
        local characterName = GetCurrentCharacterName()
        local locationLabel = string.format("Inventory (%s)", characterName)
        local locationKey = string.format("inventory:%s", zo_strlower(characterName))
        return locationKey, locationLabel
    elseif bagId == BAG_BANK or (BAG_SUBSCRIBER_BANK and bagId == BAG_SUBSCRIBER_BANK) then
        return "bank", "Bank"
    elseif BAG_GUILDBANK and bagId == BAG_GUILDBANK then
        return GetSelectedGuildBankLocationInfo()
    elseif BAG_VIRTUAL and bagId == BAG_VIRTUAL then
        return "craftbag", "Craft Bag"
    end

    local chestIndex = GetHouseStorageChestIndex(bagId)
    if chestIndex > 0 then
        return string.format("housestorage:%d", chestIndex), GetHouseStorageDisplayName(bagId, chestIndex)
    end

    if BAG_FURNITURE_VAULT and bagId == BAG_FURNITURE_VAULT then
        local zoneName = GetCurrentZoneDisplayName()
        if zoneName ~= "" then
            return "furnishingvault", string.format("Furnishing Vault (%s)", zoneName)
        end
        return "furnishingvault", "Furnishing Vault"
    end

    return string.format("bag:%s", tostring(bagId)), string.format("Bag %s", tostring(bagId))
end

BuildSharedItemKey = function(itemLink, locationKey)
    return string.format("%s||%s", tostring(itemLink or ""), tostring(locationKey or ""))
end

local function BuildLocationKeyFromSharedFrom(sharedFrom)
    local value = zo_strlower(tostring(sharedFrom or ""))
    if value == "" then
        return ""
    end
    if value == "bank" then
        return "bank"
    elseif value == "craft bag" then
        return "craftbag"
    elseif string.find(value, "house storage", 1, true) == 1 then
        local chestNumber = string.match(value, "^house storage (%d+)")
        if chestNumber then
            return "housestorage:" .. chestNumber
        end
        return "housestorage"
    elseif string.find(value, "furnishing vault", 1, true) == 1 then
        return "furnishingvault"
elseif string.find(value, "placed %(", 1, true) == 1 then
        -- The label carries the house, so the key has to carry it too, or two houses
        -- would collapse back into one row the next time the file is read.
        local houseName = string.match(tostring(sharedFrom or ""), "^Placed %((.*)%)$")
        if houseName and houseName ~= "" then
            return "placed:" .. zo_strlower(houseName)
        end
        return "placed"
    elseif string.find(value, "inventory %(", 1, true) == 1 then
        local characterName = string.match(tostring(sharedFrom or ""), "^Inventory %((.*)%)$")
        if characterName and characterName ~= "" then
            return string.format("inventory:%s", zo_strlower(characterName))
        end
        return "inventory"
    elseif string.find(value, "guild bank %(", 1, true) == 1 then
        return value
    elseif value == "guild bank" then
        return "guildbank"
    end
    return value
end

local function JoinSortedLocations(locationSet)
    local locations = {}
    for locationName, hasLocation in pairs(locationSet or {}) do
        if hasLocation then
            table.insert(locations, locationName)
        end
    end

    table.sort(locations)
    return table.concat(locations, ", ")
end

local function GetLocalizedStringByPrefix(prefix, value, fallback)
    local globalName = prefix .. tostring(value)
    local stringId = _G[globalName]
    if stringId then
        local text = GetString(stringId)
        if text and text ~= "" then
            return zo_strformat("<<t:1>>", text)
        end
    end
    return fallback or tostring(value)
end

local function GetItemTypeInfo(bagId, slotIndex)
    local itemType = GetItemType(bagId, slotIndex) or 0
    local itemTypeName = GetLocalizedStringByPrefix("SI_ITEMTYPE", itemType, tostring(itemType))
    return itemType, itemTypeName
end

local function GetItemQualityInfo(bagId, slotIndex)
    local quality = GetItemQuality(bagId, slotIndex) or 0
    local qualityName = GetLocalizedStringByPrefix("SI_ITEMQUALITY", quality, tostring(quality))
    return quality, qualityName
end

local function GetItemTraitInfo(bagId, slotIndex)
    local traitType = GetItemTrait(bagId, slotIndex)
    if not traitType or traitType == ITEM_TRAIT_TYPE_NONE or traitType == 0 then
        return "", ITEM_TRAIT_TYPE_NONE
    end

    local traitName = GetLocalizedStringByPrefix("SI_ITEMTRAITTYPE", traitType, tostring(traitType))
    return traitName, traitType
end

local function GetItemEquipTypeInfo(bagId, slotIndex)
    local equipType = GetItemEquipType and GetItemEquipType(bagId, slotIndex) or nil
    equipType = tonumber(equipType) or 0
    if equipType == 0 or (EQUIP_TYPE_INVALID and equipType == EQUIP_TYPE_INVALID) then
        return "", equipType
    end

    local equipTypeName = GetLocalizedStringByPrefix("SI_EQUIPTYPE", equipType, tostring(equipType))
    return equipTypeName, equipType
end

local function GetItemArmorWeightInfo(bagId, slotIndex)
    local armorType = GetItemArmorType and GetItemArmorType(bagId, slotIndex) or nil
    armorType = tonumber(armorType) or 0
    if armorType == 0 or (ARMORTYPE_NONE and armorType == ARMORTYPE_NONE) then
        return "", armorType
    end

    local armorTypeName = GetLocalizedStringByPrefix("SI_ARMORTYPE", armorType, tostring(armorType))
    return armorTypeName, armorType
end

local function GetItemWeaponTypeInfo(bagId, slotIndex)
    local weaponType = GetItemWeaponType and GetItemWeaponType(bagId, slotIndex) or nil
    weaponType = tonumber(weaponType) or 0

    if weaponType == 0 or (WEAPONTYPE_NONE and weaponType == WEAPONTYPE_NONE) then
        return "", weaponType, ""
    end

    local weaponTypeName = GetLocalizedStringByPrefix("SI_WEAPONTYPE", weaponType, tostring(weaponType))

    local handedness = ""

    if weaponType == WEAPONTYPE_AXE
        or weaponType == WEAPONTYPE_DAGGER
        or weaponType == WEAPONTYPE_MACE
        or weaponType == WEAPONTYPE_SWORD then
        handedness = "1H"

    elseif weaponType == WEAPONTYPE_TWO_HANDED_AXE
        or weaponType == WEAPONTYPE_TWO_HANDED_HAMMER
        or weaponType == WEAPONTYPE_TWO_HANDED_SWORD
        or weaponType == WEAPONTYPE_BOW
        or weaponType == WEAPONTYPE_FIRE_STAFF
        or weaponType == WEAPONTYPE_FROST_STAFF
        or weaponType == WEAPONTYPE_LIGHTNING_STAFF
        or weaponType == WEAPONTYPE_HEALING_STAFF then
        handedness = "2H"
    end

    return weaponTypeName, weaponType, handedness
end


local function GetApparelInfo(bagId, slotIndex)
    local apparelSlot, equipType = GetItemEquipTypeInfo(bagId, slotIndex)
    local apparelWeight, armorType = GetItemArmorWeightInfo(bagId, slotIndex)

    if apparelWeight == "" then
        return "", 0, "", 0
    end

    return apparelSlot, equipType, apparelWeight, armorType
end

local function GetItemShareCount(bagId, slotIndex)
    local stackCount = GetSlotStackSize(bagId, slotIndex)
    if stackCount and stackCount > 0 then
        return stackCount
    end
    return 1
end

local function GetItemFurnitureDataIdSafe(bagId, slotIndex)
    if not GetItemFurnitureDataId then
        return 0
    end
    return tonumber(GetItemFurnitureDataId(bagId, slotIndex)) or 0
end

-- The icon path is the only thing that lets the site cache an image, so more than
-- one getter is asked. GetItemIcon is not exposed on every client and does not
-- answer for every slot; GetItemInfo returns the icon as its *third* value, not its
-- second, so reading the second value returned the item link and quietly left the
-- icon blank. Link-based getters are asked last: they need no live bag slot, which
-- is exactly what a set item filed from a bank or a house chest can lack when the
-- slot getters come back empty.
local ITEM_ICON_LINK_GETTERS = {
    "GetItemLinkIconTextureName",
    "GetItemLinkIcon",
    "GetItemLinkTextureName",
}

-- Accepts only what can be a texture path: some getters answer with a bare icon
-- name, which the site cannot turn into an image. A path missing its leading slash
-- is repaired rather than thrown away.
local function NormalizeIconTexturePath(value)
    local text = type(value) == "string" and string.match(value, "^%s*(.-)%s*$") or ""

    if text == "" or string.find(text, "/", 1, true) == nil then
        return ""
    end
    if string.sub(text, 1, 1) ~= "/" then
        text = "/" .. text
    end

    return text
end

local function GetItemIconFromLinkSafe(itemLink)
    local link = tostring(itemLink or "")

    if link == "" then
        return ""
    end

    for _, getterName in ipairs(ITEM_ICON_LINK_GETTERS) do
        local getter = _G[getterName]
        if type(getter) == "function" then
            local ok, icon = pcall(getter, link)
            local path = ok and NormalizeIconTexturePath(icon) or ""
            if path ~= "" then
                return path
            end
        end
    end

    return ""
end

local function GetItemIconPathSafe(bagId, slotIndex, itemLink)
    if type(GetItemIcon) == "function" then
        local ok, icon = pcall(GetItemIcon, bagId, slotIndex)
        local path = ok and NormalizeIconTexturePath(icon) or ""
        if path ~= "" then
            return path
        end
    end

    if type(GetItemInfo) == "function" then
        local ok, _, _, icon = pcall(GetItemInfo, bagId, slotIndex)
        local path = ok and NormalizeIconTexturePath(icon) or ""
        if path ~= "" then
            return path
        end
    end

    return GetItemIconFromLinkSafe(itemLink)
end

-- The item id lives inside the link: |H0:item:43532:370:50:...|h|h
local function GetItemIdFromLink(itemLink)
    local id = string.match(tostring(itemLink or ""), "item:(%d+)")
    return tonumber(id) or 0
end

-- ESO exposes item detail through global getters whose signatures move between
-- API versions, and calling one with the wrong arguments raises a Lua error.
-- Every probe below is pcall'd and type-checked, so a getter the client does not
-- have, or one whose shape changed, costs that field and nothing else: adding an
-- item to the share list must never fail because of a capture attempt.
local ITEM_LINK_GETTERS = {
    "GetItemLinkDisplayQuality",
    "GetItemLinkItemType",
    "GetItemLinkEquipType",
    "GetItemLinkArmorType",
    "GetItemLinkWeaponType",
    "GetItemLinkTraitType",
    "GetItemLinkItemId",
    "GetItemLinkItemLevel",
    "GetItemLinkRequiredLevel",
    "GetItemLinkRequiredChampionPoints",
    "GetItemLinkFlavorText",
    "GetItemLinkEnchantInfo",
    "GetItemLinkItemStyle",
    "GetItemLinkMaxStackSize",
    "GetItemLinkStolen",
}

local ITEM_SLOT_GETTERS = {
    "GetItemRequiredLevel",
    "GetItemRequiredChampionPoints",
    "GetItemArmorRating",
    "GetItemWeaponDamage",
    "GetItemMaxStack",
    "GetItemStolen",
}

local function PackItemScalars(...)
    local packed = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        local valueType = type(value)
        if valueType == "number" or valueType == "boolean" or (valueType == "string" and value ~= "") then
            packed[#packed + 1] = value
        end
    end
    return packed
end

-- Runs one getter if the running client has it and keeps whatever scalar values
-- it returned. The packed results are stored verbatim with the item as well, so
-- detail this version of the addon does not display yet survives an upload and
-- can be used by the website later without a new game capture.
local function ProbeItemApi(raw, name, ...)
    local getter = _G[name]
    if type(getter) ~= "function" then
        return nil
    end

    local results = { pcall(getter, ...) }
    if results[1] ~= true then
        return nil
    end

    local packed = PackItemScalars(unpack(results, 2, #results))
    if #packed > 0 then
        raw[name] = packed
        return packed
    end
    return nil
end

local function FirstItemString(values)
    for _, value in ipairs(values or {}) do
        if type(value) == "string" and value ~= "" then
            return value
        end
    end
    return ""
end

local function FirstItemNumber(values)
    for _, value in ipairs(values or {}) do
        if type(value) == "number" and value > 0 then
            return value
        end
    end
    return 0
end

local function CaptureItemDetails(itemLink, bagId, slotIndex)
    local raw = {}
    local details = { esoDetails = raw }

    if itemLink and itemLink ~= "" then
        for _, getterName in ipairs(ITEM_LINK_GETTERS) do
            ProbeItemApi(raw, getterName, itemLink)
        end

        -- The set name is picked out by type rather than by position: its result
        -- is mostly numbers, and the order has changed between API versions, so
        -- reading position one as the name could store a bonus count instead.
        local setInfo = ProbeItemApi(raw, "GetItemLinkSetInfo", itemLink, false)
        details.setName = FirstItemString(setInfo)
        details.enchantName = FirstItemString(raw.GetItemLinkEnchantInfo)
        details.styleName = FirstItemString(raw.GetItemLinkItemStyle)
        details.flavorText = FirstItemString(raw.GetItemLinkFlavorText)
        -- Kept once, on the entry: the raw dump would otherwise store the same
        -- paragraph again for every item that has one.
        raw.GetItemLinkFlavorText = nil
    end

    if bagId ~= nil and slotIndex ~= nil then
        for _, getterName in ipairs(ITEM_SLOT_GETTERS) do
            ProbeItemApi(raw, getterName, bagId, slotIndex)
        end
    end

    details.requiredLevel = FirstItemNumber(raw.GetItemLinkRequiredLevel)
    if details.requiredLevel == 0 then
        details.requiredLevel = FirstItemNumber(raw.GetItemRequiredLevel)
    end

    details.requiredCp = FirstItemNumber(raw.GetItemLinkRequiredChampionPoints)
    if details.requiredCp == 0 then
        details.requiredCp = FirstItemNumber(raw.GetItemRequiredChampionPoints)
    end

    return details
end

local function GetItemDataFromBagSlot(bagId, slotIndex)
    local itemName = GetNormalizedItemName(bagId, slotIndex)
    local itemLink = GetNormalizedItemLink(bagId, slotIndex)
    if not itemName or not itemLink then
        return nil
    end

    local itemType, itemTypeName = GetItemTypeInfo(bagId, slotIndex)
    local quality, qualityName = GetItemQualityInfo(bagId, slotIndex)
    local traitName, traitType = GetItemTraitInfo(bagId, slotIndex)
    local apparelSlot, equipType, apparelWeight, armorType = GetApparelInfo(bagId, slotIndex)
    local weaponTypeName, weaponType, weaponHandedness = GetItemWeaponTypeInfo(bagId, slotIndex)
    local furnitureDataId = GetItemFurnitureDataIdSafe(bagId, slotIndex)
    local locationKey, sharedFrom = GetBagLocationInfo(bagId)
    local details = CaptureItemDetails(itemLink, bagId, slotIndex)

    return {
        itemKey = BuildSharedItemKey(itemLink, locationKey),
        itemName = itemName,
        itemLink = itemLink,
        itemId = GetItemIdFromLink(itemLink),
        icon = GetItemIconPathSafe(bagId, slotIndex, itemLink),
        itemType = itemType,
        itemTypeName = itemTypeName,
        quality = quality,
        qualityName = qualityName,
        trait = traitName,
        traitType = traitType,
        apparelSlot = apparelSlot,
        equipType = equipType,
        apparelWeight = apparelWeight,
        armorType = armorType,
        weaponType = weaponTypeName,
        weaponHandedness = weaponHandedness,
        weaponTypeId = weaponType,
        furnitureDataId = furnitureDataId,
        setName = details.setName or "",
        enchantName = details.enchantName or "",
        styleName = details.styleName or "",
        requiredLevel = details.requiredLevel or 0,
        requiredCp = details.requiredCp or 0,
        flavorText = details.flavorText or "",
        esoDetails = details.esoDetails or {},
        bagId = bagId,
        slotIndex = slotIndex,
        locationKey = locationKey,
        sharedFrom = sharedFrom,
    }
end

-- The client's own link check, captured before the helper below takes the name: it is
-- the only bound test the housing API leaves for a placed piece, which has no bag slot.
local EsoIsItemLinkBound = IsItemLinkBound

-- The item link carries the item's own bound state, which still answers when the
-- slot cannot: a guild bank tab that is not open, a house bank the client has not
-- loaded, a saved row whose bag was reorganised. It is a second opinion behind
-- IsItemBound, never a replacement for it.
--
-- GetItemLinkBoundStatus is not in the client's API - asking for it and giving up
-- answered "not bound" for every link the game ever produced, which is how bound
-- furnishings reached the share list. The client's IsItemLinkBound is the real test.
local function IsItemLinkBound(itemLink)
    local link = tostring(itemLink or "")
    if link == "" then
        return false
    end

    if type(GetItemLinkBoundStatus) == "function" then
        local ok, status = pcall(GetItemLinkBoundStatus, link)
        if ok and status ~= nil then
            -- The named constant is preferred so a client that renumbers the enum is
            -- still read correctly; every version defines BOUND_STATUS_UNBOUND as 0.
            if BOUND_STATUS_UNBOUND ~= nil then
                return status ~= BOUND_STATUS_UNBOUND
            end
            return tonumber(status) ~= 0
        end
    end

    if type(EsoIsItemLinkBound) == "function" then
        local ok, bound = pcall(EsoIsItemLinkBound, link)
        if ok then
            return bound == true
        end
    end

    return false
end

local function IsItemEligibleForShare(bagId, slotIndex)
    if bagId == nil or slotIndex == nil then
        return false, "Invalid inventory slot."
    end
    if IsItemBound(bagId, slotIndex) then
        return false, "Item is already bound."
    end
    if IsItemLinkBound(GetNormalizedItemLink(bagId, slotIndex)) then
        return false, "Item is already bound."
    end
    if IsItemBoPAndTradeable(bagId, slotIndex) then
        return false, "Item is restricted to temporary group sharing."
    end
    return true, nil
end

-- A row in the share list keeps the bag and slot it was filed from, but that slot
-- may hold something else by now. The slot check only counts when it still holds
-- this item; otherwise the link's own bound state is the honest answer.
IsSavedEntryEligibleForShare = function(entry)
    if not entry then
        return false, "No item data."
    end

    local itemLink = tostring(entry.itemLink or "")
    if itemLink == "" then
        return false, "No item link."
    end

    local bagId = tonumber(entry.bagId)
    local slotIndex = tonumber(entry.slotIndex)

    if bagId and slotIndex and GetNormalizedItemLink(bagId, slotIndex) == itemLink then
        return IsItemEligibleForShare(bagId, slotIndex)
    end

    if IsItemLinkBound(itemLink) then
        return false, "Item is already bound."
    end

    return true, nil
end

-- "Share reserve": keep this many for yourself and offer only what you have above
-- it. Kept per item and per place, so the bank's stack can keep 50 back while the
-- same item in your bags keeps none; the item-wide table is the fallback an older
-- file wrote, and it answers for any place that has no number of its own.
local function GetShareReserveTable()
    if not ItemShare.savedVars then
        return {}
    end
    if type(ItemShare.savedVars.reserves) ~= "table" then
        ItemShare.savedVars.reserves = {}
    end
    return ItemShare.savedVars.reserves
end

local function GetLocationReserveTable()
    if not ItemShare.savedVars then
        return {}
    end
    if type(ItemShare.savedVars.locationReserves) ~= "table" then
        ItemShare.savedVars.locationReserves = {}
    end
    return ItemShare.savedVars.locationReserves
end

GetShareReserve = function(itemLink, locationKey)
    local link = tostring(itemLink or "")
    if link == "" then
        return 0
    end

    -- A zero stored against a place is a real answer - "none here" - and it overrides
    -- the item-wide number instead of falling back to it. Without that, clearing the
    -- reserve in one bag would look as if it had failed.
    local placeKey = tostring(locationKey or "")
    if placeKey ~= "" then
        local byPlace = tonumber(GetLocationReserveTable()[BuildSharedItemKey(link, placeKey)])
        if byPlace ~= nil then
            return math.max(0, math.floor(byPlace))
        end
    end

    local reserve = tonumber(GetShareReserveTable()[link]) or 0
    return math.max(0, math.floor(reserve))
end

local function SetShareReserve(itemLink, reserve, locationKey)
    local link = tostring(itemLink or "")
    if link == "" then
        return
    end

    local amount = math.max(0, math.floor(tonumber(reserve) or 0))
    local placeKey = tostring(locationKey or "")

    if placeKey ~= "" then
        -- Stored even at zero: the place has been answered on purpose, which is what
        -- lets clearing it in one bag leave the other bags' reserves alone.
        GetLocationReserveTable()[BuildSharedItemKey(link, placeKey)] = amount
        return
    end

    local reserves = GetShareReserveTable()
    if amount <= 0 then
        reserves[link] = nil
    else
        reserves[link] = amount
    end
end

-- What is offered is what is held above the reserve. Twenty held with twelve kept
-- shares eight; eight held with twelve kept shares nothing, and the share entry
-- stays at zero so the marking comes back by itself when more are acquired.
ShareableCount = function(itemLink, heldCount, locationKey)
    local held = math.max(0, math.floor(tonumber(heldCount) or 0))
    return math.max(0, held - GetShareReserve(itemLink, locationKey))
end

local function IsItemLinkSharedInLocation(itemLink, locationKey)
    if not itemLink or not locationKey or not ItemShare.savedVars or not ItemShare.savedVars.sharedItems then
        return false
    end

    local entryKey = BuildSharedItemKey(itemLink, locationKey)
    return ItemShare.savedVars.sharedItems[entryKey] ~= nil
end

-- A share reserves the copy it was made from, and only that copy: something shared
-- from your bags is still yours to sell if it happens to be sitting in the bank, and
-- a copy in a place nothing was shared from is not protected at all.
--
-- A standing offer is held just as tightly, because it is marked in one place and counts
-- that place: the copy the offer is counted from is the copy it promises. Marking an
-- offer also clears any share of the same item - the two states are one way at a time -
-- so this used to be the one way to be on the list and be unprotected.
--
-- The second return says which of the two is holding the copy, because the message has
-- to send you to the row that will actually release it.
local function GetSharedEntryProtectingSlot(bagId, slotIndex)
    if bagId == nil or slotIndex == nil or not ItemShare.savedVars then
        return nil, nil
    end
    if ItemShare.savedVars.shareProtection == false then
        return nil, nil
    end

    local itemLink = GetNormalizedItemLink(bagId, slotIndex)
    if not itemLink or itemLink == "" then
        return nil, nil
    end

    local locationKey = select(1, GetBagLocationInfo(bagId))
    if not locationKey then
        return nil, nil
    end

    local entry = ItemShare.savedVars.sharedItems and
        ItemShare.savedVars.sharedItems[BuildSharedItemKey(itemLink, locationKey)]
    if entry ~= nil then
        return entry, "share"
    end

    local alwaysShare = ItemShare.savedVars.alwaysShare
    if type(alwaysShare) == "table" and type(GetAlwaysShareKey) == "function" then
        local alwaysEntry = alwaysShare[GetAlwaysShareKey(itemLink, locationKey)]
        if alwaysEntry ~= nil then
            return alwaysEntry, "always"
        end
    end

    return nil, nil
end

-- One line per second at most: a blocked action can be tried repeatedly, and the
-- reason only has to be said once for it to be read.
local lastShareProtectionNotice = 0

local function NotifyShareProtected(entry, source)
    local now = GetTimeStamp()
    if now == lastShareProtectionNotice then
        return
    end
    lastShareProtectionNotice = now

    -- A standing offer is released by stopping the offer, a share by removing the share, so
    -- the message has to name the right one - and nothing else: the item's own menu is where
    -- you would already be, and directions to the window read as noise mid-action.
    local heldAs = "shared"
    local release = "Remove the share to use it."
    if source == "always" then
        heldAs = "always shared"
        release = "Stop always sharing it to use it."
    end

    PrintMessage(string.format(
        "%s is %s from %s, so ItemShare is holding it: mailing, trading or storing it is all it will allow. %s",
        tostring(entry and entry.itemName or "That item"),
        heldAs,
        tostring(entry and entry.sharedFrom or "that place"),
        release
    ))
end

-- Mailing is one of the two things that has to keep working, and the attachment picker is a
-- bag list like any other, so its clicks are let through while it is on screen.
local function IsMailSendShowing()
    if type(SCENE_MANAGER) ~= "table" or type(MAIL_SEND) ~= "string" then
        return false
    end
    if type(SCENE_MANAGER.IsShowing) ~= "function" then
        return false
    end

    local ok, showing = pcall(SCENE_MANAGER.IsShowing, SCENE_MANAGER, MAIL_SEND)
    return ok and showing == true
end

-- The guild store's sell tab is the one place a drag can file something: drop a row on the
-- pending listing and the client takes it, with no menu involved. Posting is not something a
-- share allows, so while that tab is up a locked copy cannot be picked up at all - there is
-- nothing else to drop it on in that window - and a drag anywhere else stays available for
-- mail and trade.
local function IsGuildStoreSellMode()
    if type(TRADING_HOUSE) ~= "table" or type(TRADING_HOUSE.IsInSellMode) ~= "function" then
        return false
    end

    local ok, inSellMode = pcall(TRADING_HOUSE.IsInSellMode, TRADING_HOUSE)
    return ok and inSellMode == true
end

local function ShouldRefuseSharedDrag(inventorySlot)
    if not IsGuildStoreSellMode() then
        return nil, nil
    end

    return GetSharedEntryProtectingSlot(GetBagAndSlotFromInventorySlot(inventorySlot))
end

-- The client reads a bag and slot out of a control with ZO_Inventory_GetBagAndIndex: it
-- returns the bagId and slotIndex the inventory bound onto the control. The ...Slot... form
-- these guards used to ask for is not in the client at all, so every lookup answered nil,
-- both guards decided there was nothing in front of them to protect, and a shared copy went
-- to the merchant anyway.
--
-- A control can also arrive before it has been resolved into its components, which is how
-- ZO_InventorySlot_DoPrimaryAction starts, so that shape is read as well.
local function GetBagAndSlotFromInventorySlot(inventorySlot)
    local slotType = type(inventorySlot)
    if slotType ~= "table" and slotType ~= "userdata" then
        return nil, nil
    end

    if type(ZO_Inventory_GetBagAndIndex) == "function" then
        local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
        if bagId ~= nil and slotIndex ~= nil then
            return bagId, slotIndex
        end
    end

    local data = inventorySlot.dataEntry and inventorySlot.dataEntry.data
    if type(data) == "table" and data.bagId ~= nil and data.slotIndex ~= nil then
        return data.bagId, data.slotIndex
    end

    if inventorySlot.bagId ~= nil and inventorySlot.slotIndex ~= nil then
        return inventorySlot.bagId, inventorySlot.slotIndex
    end

    if type(ZO_InventorySlot_GetInventorySlotComponents) == "function" then
        local components = ZO_InventorySlot_GetInventorySlotComponents(inventorySlot)
        if components ~= nil and components ~= inventorySlot
            and type(components) == "table"
            and components.bagId ~= nil and components.slotIndex ~= nil then
            return components.bagId, components.slotIndex
        end
    end

    return nil, nil
end

local function GetBagAndSlotFromSlotActions(slotActions)
    if type(slotActions) ~= "table" then
        return nil, nil
    end

    local slot = slotActions.m_inventorySlot or slotActions.inventorySlot
    if slot ~= nil then
        local bagId, slotIndex = GetBagAndSlotFromInventorySlot(slot)
        if bagId ~= nil and slotIndex ~= nil then
            return bagId, slotIndex
        end
    end

    local data = slotActions.dataEntry and slotActions.dataEntry.data or slotActions.slotData
    if type(data) == "table" then
        return data.bagId, data.slotIndex
    end

    return nil, nil
end

-- What a share still allows. Everything the client can offer for a bag slot that is not on
-- this list is refused, so an action nobody has thought of fails closed instead of handing
-- the copy over. Mailing and trading are the two that have to keep working.
local shareProtectedAllowedActions = {}

local function AllowShareProtectedAction(actionId)
    if actionId ~= nil then
        shareProtectedAllowedActions[actionId] = true
    end
end

AllowShareProtectedAction(SI_ITEM_ACTION_MAIL_ATTACH)
AllowShareProtectedAction(SI_ITEM_ACTION_MAIL_DETACH)
AllowShareProtectedAction(SI_ITEM_ACTION_TRADE_ADD)
AllowShareProtectedAction(SI_ITEM_ACTION_TRADE_REMOVE)
-- Looking at it changes nothing: linking, previewing, the map and quest entries, the junk
-- and lock marks, and reporting it.
AllowShareProtectedAction(SI_ITEM_ACTION_LINK_TO_CHAT)
AllowShareProtectedAction(SI_ITEM_ACTION_PREVIEW)
AllowShareProtectedAction(SI_ITEM_ACTION_PREVIEW_DYE_STAMP)
AllowShareProtectedAction(SI_ITEM_ACTION_SHOW_MAP)
AllowShareProtectedAction(SI_ITEM_ACTION_SHOW_QUEST)
AllowShareProtectedAction(SI_ITEM_ACTION_MARK_AS_JUNK)
AllowShareProtectedAction(SI_ITEM_ACTION_UNMARK_AS_JUNK)
AllowShareProtectedAction(SI_ITEM_ACTION_MARK_AS_LOCKED)
AllowShareProtectedAction(SI_ITEM_ACTION_UNMARK_AS_LOCKED)
AllowShareProtectedAction(SI_ITEM_ACTION_REPORT_ITEM)
-- Splitting keeps the share: both halves carry the same item link, so both stay protected.
AllowShareProtectedAction(SI_ITEM_ACTION_SPLIT_STACK)
-- Storage keeps the copy: putting a shared piece in the bank, a house chest or the
-- furnishing vault and taking it back out again is where it lives between sessions, and
-- refusing those made the vaults unusable for exactly the items the list is about. Both
-- directions, because it is the same item on whichever side of the vault it sits.
AllowShareProtectedAction(SI_ITEM_ACTION_BANK_DEPOSIT)
AllowShareProtectedAction(SI_ITEM_ACTION_BANK_WITHDRAW)
-- Placing a shared furnishing is storage with a view: it leaves the bag, stays yours, and
-- has to be pickable again.
AllowShareProtectedAction(SI_ITEM_ACTION_PLACE_FURNITURE)

local shareProtectionInstalled = false

-- A shared copy can be asked to do something in two places only: the action list a slot
-- builds before it shows its menu, and the primary action a click or a double click runs.
-- Refusing both is what stops the copy being sold, destroyed, deconstructed, refined,
-- researched, enchanted, used, equipped, laundered, or turned over to a craft bag.
local function InstallShareProtection()
    if shareProtectionInstalled or not ZO_PreHook then
        return
    end
    shareProtectionInstalled = true

    if ZO_InventorySlotActions then
        ZO_PreHook(ZO_InventorySlotActions, "AddSlotAction", function(slotActions, actionStringId, ...)
            if shareProtectedAllowedActions[actionStringId] then
                return false
            end

            local bagId, slotIndex = GetBagAndSlotFromSlotActions(slotActions)
            local entry, source = GetSharedEntryProtectingSlot(bagId, slotIndex)
            if not entry then
                return false
            end

            NotifyShareProtected(entry, source)
            return true
        end)
    end

    if ZO_InventorySlot_DoPrimaryAction then
        ZO_PreHook("ZO_InventorySlot_DoPrimaryAction", function(inventorySlot)
            if IsMailSendShowing() then
                return false
            end

            local entry, source = GetSharedEntryProtectingSlot(GetBagAndSlotFromInventorySlot(inventorySlot))
            if not entry then
                return false
            end

            NotifyShareProtected(entry, source)
            return true
        end)
    end

    -- Dragging is the third way to ask a slot to do something, and the one that never touches
    -- the slot menu: the client starts a pickup on the row's OnDragStart and whatever control
    -- is under the cursor takes it from there. That is how a shared piece reached the guild
    -- store's listing slot while every click and menu entry on it was being refused.
    if ZO_InventorySlot_OnDragStart then
        ZO_PreHook("ZO_InventorySlot_OnDragStart", function(inventorySlot)
            local entry, source = ShouldRefuseSharedDrag(inventorySlot)
            if not entry then
                return false
            end

            NotifyShareProtected(entry, source)
            return true
        end)
    end
end

local function FindSharedEntryKeyForBagSlot(bagId, slotIndex)
    local itemLink = GetNormalizedItemLink(bagId, slotIndex)
    if not itemLink then
        return nil
    end

    local locationKey = select(1, GetBagLocationInfo(bagId))
    local entryKey = BuildSharedItemKey(itemLink, locationKey)
    if ItemShare.savedVars and ItemShare.savedVars.sharedItems then
        return ItemShare.savedVars.sharedItems[entryKey] and entryKey or nil
    end
    return nil
end

-- An item can be in the share list and in the always-share list at the same time.
-- The offer is keyed by item link and place, so the same stack in another bag is a
-- different thing and stays unmarked.
IsItemLinkAlwaysShared = function(itemLink, locationKey)
    local alwaysShare = ItemShare.savedVars and ItemShare.savedVars.alwaysShare
    if type(alwaysShare) ~= "table" then
        return false
    end
    local link = tostring(itemLink or "")
    if link == "" then
        return false
    end
    return alwaysShare[GetAlwaysShareKey(link, locationKey)] ~= nil
end

-- Crafting panels own their inventories and are built when a station or the
-- ragpicker first opens, so they are kept here and repainted with the bags: a share
-- toggled while the deconstruction pane is open has to update in that pane too.
local itemShareExtraListViews = {}

TryRefreshInventoryVisuals = function()
    if PLAYER_INVENTORY and PLAYER_INVENTORY.inventories then
        for _, inventory in pairs(PLAYER_INVENTORY.inventories) do
            local listView = inventory and inventory.listView
            if listView and ZO_ScrollList_RefreshVisible then
                ZO_ScrollList_RefreshVisible(listView)
            end
        end
    end

    for listView in pairs(itemShareExtraListViews) do
        if ZO_ScrollList_RefreshVisible then
            ZO_ScrollList_RefreshVisible(listView)
        end
    end
end

local function GetBagAndSlotFromSlotData(control, slotData)
    local bagId, slotIndex = nil, nil

    if type(slotData) == "table" then
        bagId = slotData.bagId
            or (slotData.slotData and slotData.slotData.bagId)
            or (slotData.dataEntry and slotData.dataEntry.data and slotData.dataEntry.data.bagId)
            or (slotData.rawSlotData and slotData.rawSlotData.bagId)

        slotIndex = slotData.slotIndex
            or (slotData.slotData and slotData.slotData.slotIndex)
            or (slotData.dataEntry and slotData.dataEntry.data and slotData.dataEntry.data.slotIndex)
            or (slotData.rawSlotData and slotData.rawSlotData.slotIndex)
    end

    if (bagId == nil or slotIndex == nil) and control ~= nil then
        local controlBagId, controlSlotIndex = GetBagAndSlotFromInventorySlot(control)
        bagId = bagId or controlBagId
        slotIndex = slotIndex or controlSlotIndex
    end

    return bagId, slotIndex
end

-- The item icon is not always `GetNamedChild("Icon")`. A bag slot exposes it, but a
-- list row can keep the art one level deeper, and when that lookup missed the badge
-- fell back to the slot's own corner - which is the "off to the left" spot this is
-- supposed to avoid. So look where the game actually puts it.
local function FindItemIconControl(control)
    if not control or not control.GetNamedChild then
        return nil
    end

    local direct = control:GetNamedChild("Icon")
    if direct then
        return direct
    end

    -- Some templates wrap the art in a named container, and the icon lives inside it.
    local wrappers = { "Button", "IconHolder", "IconContainer", "IconFrame" }
    for _, name in ipairs(wrappers) do
        local wrapper = control:GetNamedChild(name)
        if wrapper and wrapper.GetNamedChild then
            local nested = wrapper:GetNamedChild("Icon")
            if nested then
                return nested
            end
        end
    end

    return nil
end

-- The badge sits on the item icon's own top-left corner rather than in the gap
-- beside it. That gap is where the slot's level, stack count and lock live, and it
-- is also where a second addon may already be drawing; the corner of the icon reads
-- as part of the item instead of as a loose symbol next to it.
--
-- The size follows what it is sitting on: a fixed 14 px read as a speck next to a
-- 36 px slot icon, so it is a little over half the icon now.
local function AnchorShareMarker(marker, control)
    local icon = FindItemIconControl(control)

    marker:ClearAnchors()

    if icon then
        local width = (icon.GetWidth and icon:GetWidth()) or 0
        local height = (icon.GetHeight and icon:GetHeight()) or 0
        local size = 20

        if width > 0 and height > 0 then
            size = math.max(18, math.min(26, math.floor(math.min(width, height) * 0.55)))
        end

        marker:SetDimensions(size, size)
        marker:SetAnchor(TOPLEFT, icon, TOPLEFT, -2, -2)
        marker:SetDrawLayer(icon:GetDrawLayer())
        marker:SetDrawTier(icon:GetDrawTier() + 1)
        return
    end

    -- No icon to sit on: use the control's own corner, sized to it, rather than a
    -- fixed offset that lands in the empty margin of a wide list row.
    local height = (control.GetHeight and control:GetHeight()) or 0
    local size = height > 0 and math.max(16, math.min(26, math.floor(height * 0.5))) or 20

    marker:SetDimensions(size, size)
    marker:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
end

local function EnsureShareMarker(control)
    if not control then
        return nil
    end

    if control.ItemShareMarker and control.ItemShareMarker.SetTexture then
        -- Rows are recycled and the icon a row borrows can change, so the anchor is
        -- re-applied rather than only set once at creation.
        AnchorShareMarker(control.ItemShareMarker, control)
        return control.ItemShareMarker
    end

    local marker = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    marker:SetTexture(SHARE_TEXTURE_PATH)
    marker:SetHidden(true)
    marker:SetMouseEnabled(true)

    -- The wording follows the texture: the same badge serves both states, so the
    -- tooltip is decided when the marker is shown, not when it is built.
    marker:SetHandler("OnMouseEnter", function(self)
        -- Anchored below the badge, not at its top-left. A tooltip that opens under
        -- the pointer takes the pointer off the badge, which closes the tooltip and
        -- puts the pointer back on it: hovering the left edge flashed nonstop.
        InitializeTooltip(InformationTooltip, self, BOTTOMLEFT, 0, -4)

        local lines = {}
        if self.ItemShareExpired then
            lines[#lines + 1] = string.format("|cFF8A70Shared for %d days|r", tonumber(self.ItemShareAgeDays) or 0)
            lines[#lines + 1] = string.format(
                "Past the /itemshare expire limit of %d days.",
                GetExpireDays()
            )
            lines[#lines + 1] = "It may be time to sell it."
        end
        if self.ItemShareAlways then
            lines[#lines + 1] = "|cFFD266Always shared|r"
            lines[#lines + 1] = "You offer this whenever you have one."
        else
            lines[#lines + 1] = "|c00FF00Shared Item|r"
            lines[#lines + 1] = "This item is available to others."
        end

        local reserve = tonumber(self.ItemShareReserve) or 0
        if reserve > 0 then
            local held = tonumber(self.ItemShareHeld) or 0
            if held > 0 then
                lines[#lines + 1] = string.format(
                    "|cD8A24FKeeping %d back|r - offering %d of %d held.",
                    reserve,
                    tonumber(self.ItemShareOffered) or 0,
                    held
                )
            else
                lines[#lines + 1] = string.format("|cD8A24FKeeping %d back|r.", reserve)
            end
        end

        SetTooltipText(InformationTooltip, table.concat(lines, "\n"))
    end)

    marker:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    AnchorShareMarker(marker, control)

    control.ItemShareMarker = marker
    return marker
end

-- Anchored to the icon's bottom-left corner, opposite the share glyph. The size
-- follows the icon for the same reason the share badge does: a fixed 14 px read as a
-- speck next to a 36 px slot icon.
local function AnchorReserveMarker(marker, control)
    local icon = FindItemIconControl(control)

    marker:ClearAnchors()

    local width = icon and icon.GetWidth and icon:GetWidth() or 0
    local height = icon and icon.GetHeight and icon:GetHeight() or 0
    local size = 20

    if width > 0 and height > 0 then
        size = math.max(18, math.min(26, math.floor(math.min(width, height) * 0.55)))
    else
        local controlHeight = (control.GetHeight and control:GetHeight()) or 0
        size = controlHeight > 0 and math.max(16, math.min(26, math.floor(controlHeight * 0.5))) or 20
    end

    marker:SetDimensions(size, size)

    if icon then
        marker:SetAnchor(BOTTOMLEFT, icon, BOTTOMLEFT, -2, 2)
        marker:SetDrawLayer(icon:GetDrawLayer())
        marker:SetDrawTier(icon:GetDrawTier() + 1)
    else
        marker:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, 0, 0)
    end
end

local function EnsureReserveMarker(control)
    if not control then
        return nil
    end

    if control.ItemShareReserveMarker then
        return control.ItemShareReserveMarker
    end

    local marker = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    -- The amber tag on its own: the parcel, when there is one, is the badge in the
    -- opposite corner, so this one says only "part of this stack is mine".
    marker:SetTexture(RESERVE_ONLY_TEXTURE_PATH)
    marker:SetHidden(true)
    marker:SetMouseEnabled(true)

    marker:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, BOTTOMLEFT, 0, -4)

        local lines = { "|cD8A24FShare reserve|r" }
        local reserve = tonumber(self.ItemShareReserve) or 0
        local held = tonumber(self.ItemShareHeld) or 0

        if reserve > 0 and held > 0 then
            lines[#lines + 1] = string.format(
                "|cD8A24FKeeping %d back|r - offering %d of %d held.",
                reserve,
                tonumber(self.ItemShareOffered) or 0,
                held
            )
        elseif reserve > 0 then
            lines[#lines + 1] = string.format("|cD8A24FKeeping %d back|r.", reserve)
        end

        if self.ItemShareUnshared then
            lines[#lines + 1] = "Nothing is shared from this item, but some is kept back."
            lines[#lines + 1] = "Right-click it - Share Reserve - to change or clear it."
        end

        SetTooltipText(InformationTooltip, table.concat(lines, "\n"))
    end)

    marker:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    AnchorReserveMarker(marker, control)
    control.ItemShareReserveMarker = marker
    return marker
end

local function UpdateSharedRowMarker(control, slotData)
    if not control then
        return
    end

    local marker = EnsureShareMarker(control)
    if not marker then
        return
    end

    local bagId, slotIndex = GetBagAndSlotFromSlotData(control, slotData)
    if bagId == nil or slotIndex == nil then
        marker:SetHidden(true)
        return
    end

    local itemLink = GetNormalizedItemLink(bagId, slotIndex)
    local locationKey = select(1, GetBagLocationInfo(bagId))
    local isSharedInList = itemLink and locationKey and IsItemLinkSharedInLocation(itemLink, locationKey)
    local sharedEntry = isSharedInList
            and ItemShare.savedVars
            and ItemShare.savedVars.sharedItems
            and ItemShare.savedVars.sharedItems[BuildSharedItemKey(itemLink, locationKey)]
        or nil
    -- The entry existing is what "shared" means. This used to be decided by reading
    -- the count the entry carried, and when that count stopped being stored every
    -- share lost its badge: the marking was there, the list showed it, and the bag
    -- said nothing. How much is on offer belongs in the tooltip, not in whether the
    -- badge is drawn at all.
    local isShared = sharedEntry ~= nil
    -- A standing offer deserves its badge even when no copy is in a bag right now:
    -- that is what the offer means. It used to show nothing at all in that state,
    -- which made the gold icon look as if it did not exist.
    local isAlways = itemLink and IsItemLinkAlwaysShared(itemLink, locationKey)
    local reserve = (itemLink and GetShareReserve(itemLink, locationKey)) or 0

    local isExpired = isShared and IsShareEntryExpired(sharedEntry)
    marker.ItemShareExpired = isExpired and true or false
    marker.ItemShareAgeDays = isExpired and math.floor(GetShareAgeInDays(sharedEntry) or 0) or 0

    if isShared or isAlways then
        -- The plain glyph, saying only what the item offers. A reserve is a separate
        -- fact and gets its own corner below, so a share that keeps some back shows
        -- both instead of one badge having to mean two things. A share past the expire
        -- limit is the one case where the age is the thing to say, so the stopwatch
        -- takes the glyph's place rather than being added to it.
        marker:SetTexture(
            isExpired and EXPIRED_TEXTURE_PATH
                or (isAlways and ALWAYS_SHARE_TEXTURE_PATH or SHARE_TEXTURE_PATH)
        )
        marker.ItemShareAlways = isAlways and true or false
        marker.ItemShareReserve = reserve
        marker.ItemShareHeld = GetEntryHeldCount(sharedEntry)
        marker.ItemShareOffered = GetEntryOfferedCount(sharedEntry)
    end

    marker:SetHidden(not (isShared or isAlways))

    -- The reserve tag, bottom-left: a reserved share shows the parcel above and the
    -- amber tag below, and a reserve on an item that is not shared at all shows only
    -- the tag. One place for it means the reserve is never the badge that got hidden.
    local reserveMarker = EnsureReserveMarker(control)
    if reserveMarker then
        reserveMarker.ItemShareReserve = reserve
        reserveMarker.ItemShareUnshared = not (isShared or isAlways)
        reserveMarker.ItemShareHeld = GetEntryHeldCount(sharedEntry)
        reserveMarker.ItemShareOffered = GetEntryOfferedCount(sharedEntry)
        reserveMarker:SetHidden(reserve <= 0)
    end
end

-- Every item control in the game is bound to its bag item through ZO_Inventory_BindSlot, which
-- the client's own comment describes as the call that "should be called for all item slots
-- (trade, mail, store, backpack, bank, crafting, etc...)". Marking the control when it is bound
-- stops the badge depending on a list, or on that list's row-setup callback still being the one
-- the addon wrapped: a shared item used to go unmarked at the ragpicker, whose rows are painted
-- through a repaint path the wrapped callback did not reach.
local function HookInventorySlotBinding()
    if type(ZO_PostHook) ~= "function" or type(ZO_Inventory_BindSlot) ~= "function" then
        return
    end

    -- After the bind, not before: the bag and slot are only on the control once it has run.
    ZO_PostHook("ZO_Inventory_BindSlot", function(slotControl)
        if slotControl == nil then
            return
        end

        local bagId, slotIndex = GetBagAndSlotFromInventorySlot(slotControl)
        if bagId ~= nil and slotIndex ~= nil then
            UpdateSharedRowMarker(slotControl, nil)
        end
    end)
end

-- Every item row in the game is drawn by a scroll list data type, whether it belongs
-- to the bags or to a crafting panel. Hooking only PLAYER_INVENTORY left the
-- deconstruction, refinement and ragpicker lists unmarked: those are separate
-- inventories that the crafting UI builds when its panel first opens.
local function HookListViewDataTypes(listView)
    local dataTypes = listView and listView.dataTypes
    if not dataTypes then
        return false
    end

    local hooked = false
    for _, dataType in pairs(dataTypes) do
        if dataType and not dataType.ItemShareWrapped then
            local wrapped = false

            if type(dataType.callbackFunction) == "function" then
                local originalCallbackFunction = dataType.callbackFunction
                dataType.callbackFunction = function(control, slotData, ...)
                    originalCallbackFunction(control, slotData, ...)
                    UpdateSharedRowMarker(control, slotData)
                end
                wrapped = true
            elseif type(dataType.callback) == "function" then
                local originalCallback = dataType.callback
                dataType.callback = function(control, slotData, ...)
                    originalCallback(control, slotData, ...)
                    UpdateSharedRowMarker(control, slotData)
                end
                wrapped = true
            elseif type(dataType.setupCallback) == "function" then
                local originalSetupCallback = dataType.setupCallback
                dataType.setupCallback = function(control, slotData, ...)
                    originalSetupCallback(control, slotData, ...)
                    UpdateSharedRowMarker(control, slotData)
                end
                wrapped = true
            end

            if wrapped then
                dataType.ItemShareWrapped = true
                hooked = true
            end
        end
    end

    if hooked then
        itemShareExtraListViews[listView] = true
        if ZO_ScrollList_RefreshVisible then
            ZO_ScrollList_RefreshVisible(listView)
        end
    end

    return hooked
end

local function HookInventoryRowCallbacks()
    if PLAYER_INVENTORY and PLAYER_INVENTORY.inventories then
        for _, inventory in pairs(PLAYER_INVENTORY.inventories) do
            HookListViewDataTypes(inventory and inventory.listView)
        end
    end

    TryRefreshInventoryVisuals()
end

-- Where the crafting UI keeps the lists that show your items. Each lookup is pcall'd
-- and may answer nothing yet: a panel is created the first time its scene opens, so
-- anything missing here is hooked by a later pass rather than treated as an error.
local CRAFTING_INVENTORY_LOOKUPS = {
    function() return SMITHING and SMITHING.deconstructPanel and SMITHING.deconstructPanel.inventory end,
    function() return SMITHING and SMITHING.refinePanel and SMITHING.refinePanel.inventory end,
    function() return SMITHING and SMITHING.creationPanel and SMITHING.creationPanel.inventory end,
    function() return ENCHANTING and ENCHANTING.deconstructPanel and ENCHANTING.deconstructPanel.inventory end,
    function() return ENCHANTING and ENCHANTING.refinePanel and ENCHANTING.refinePanel.inventory end,
    function() return ENCHANTING and ENCHANTING.creationPanel and ENCHANTING.creationPanel.inventory end,
    function() return ALCHEMY and ALCHEMY.refinePanel and ALCHEMY.refinePanel.inventory end,
    function() return PROVISIONER and PROVISIONER.refinePanel and PROVISIONER.refinePanel.inventory end,
    function() return ZO_DeconstructPane and ZO_DeconstructPane.inventory end,
}

local function HookCraftingInventoryRows()
    for _, lookup in ipairs(CRAFTING_INVENTORY_LOOKUPS) do
        local ok, inventory = pcall(lookup)
        if ok and type(inventory) == "table" and inventory.listView then
            HookListViewDataTypes(inventory.listView)
        end
    end
end

-- What one bag holds of an item, as one number. Sharing any stack of soul gems in
-- the bank means sharing every stack of them there: one entry, and a count that is
-- the whole bag's worth. Without this each click replaced the last one's count, so
-- two bank stacks of 200 came out as 200 while the badge sat on both of them.
local function GetLocationShareCount(bagId, itemLink)
    local link = tostring(itemLink or "")
    if bagId == nil or link == "" then
        return 0
    end

    local bagSize = GetBagSize(bagId) or 0
    local total = 0

    for slotIndex = 0, bagSize - 1 do
        if GetNormalizedItemLink(bagId, slotIndex) == link then
            total = total + GetItemShareCount(bagId, slotIndex)
        end
    end

    return total
end

local function AddItemToShareFromBagSlot(bagId, slotIndex)
    local isEligible, reason = IsItemEligibleForShare(bagId, slotIndex)
    if not isEligible then
        PrintMessage(string.format("Cannot add item to share: %s", tostring(reason)))
        return
    end

    local itemData = GetItemDataFromBagSlot(bagId, slotIndex)
    if not itemData then
        PrintMessage("Could not determine item data.")
        return
    end

    -- The whole bag, not the clicked stack: a second stack of the same item adds to
    -- this share instead of overwriting what the first one recorded.
    local stackCount = GetLocationShareCount(bagId, itemData.itemLink)
    if stackCount <= 0 then
        stackCount = GetItemShareCount(bagId, slotIndex)
    end
    local existing = ItemShare.savedVars.sharedItems[itemData.itemKey]
    local savedEntry = SaveSharedEntry(itemData, stackCount, existing and existing.firstDumpedAt or GetTimeStamp(), true)

    if not savedEntry then
        PrintMessage(string.format("Could not add %s to the shared list.", tostring(itemData.itemName or "that item")))
        return
    end

    -- The other direction: sharing it from a bag now replaces a standing offer. Done
    -- after the save, because a save that is refused (a bound item) must not take the
    -- offer away with it.
    local removedAlways = RemoveAlwaysShareForItemLink(savedEntry.itemLink, savedEntry.locationKey) ~= nil
    if removedAlways then
        TryRefreshInventoryVisuals()
        RefreshShareListWindowIfVisible()
    end

    local reserve = tonumber(GetShareReserve(savedEntry.itemLink, savedEntry.locationKey)) or 0

    if reserve > 0 then
        PrintMessage(string.format(
            "%s %s: keeping %d back, so %d of %d held are shared.",
            existing and "Updated" or "Added",
            itemData.itemName,
            reserve,
            GetEntryOfferedCount(savedEntry),
            stackCount
        ))
    else
        PrintMessage(string.format(
            "%s shared item %s from %s (stack size: %d)",
            existing and "Updated" or "Added",
            itemData.itemName,
            itemData.sharedFrom,
            stackCount
        ))
    end

    if removedAlways then
        PrintMessage(string.format(
            "Stopped always sharing %s: an item is offered one way at a time.",
            itemData.itemName
        ))
    end
end

RemoveItemFromShareByKey = function(itemKey, entry, refreshListWindow)
    if not itemKey or itemKey == "" then
        return
    end

    local itemName = entry and entry.itemName or itemKey
    ItemShare.savedVars.sharedItems[itemKey] = nil
    PrintMessage(string.format("Removed %s from shared list.", tostring(itemName)))
    TryRefreshInventoryVisuals()
    if refreshListWindow ~= false then
        RefreshShareListWindowIfVisible()
    end
end


SaveSharedEntry = function(itemData, count, firstDumpedAt, refreshListWindow)
    if not itemData or not itemData.itemKey then
        return nil
    end

    -- Every path that files an item ends here, so the rule lives here as well: a
    -- bound item is not offerable, whichever way it was reached.
    if IsItemLinkBound(itemData.itemLink) then
        return nil
    end

    local now = GetTimeStamp()
    local existing = ItemShare.savedVars.sharedItems[itemData.itemKey]
    local entry = existing or {}

    entry.characterName = GetCurrentCharacterName()
    entry.itemName = itemData.itemName
    entry.itemLink = itemData.itemLink
    entry.itemId = tonumber(itemData.itemId or 0) or 0
    -- A getter that answers nothing must not erase an icon captured earlier: the
    -- path is what the site caches the image from, and it does not change.
    entry.icon = (tostring(itemData.icon or "") ~= "" and tostring(itemData.icon)) or entry.icon or ""
    entry.itemType = itemData.itemType
    entry.itemTypeName = itemData.itemTypeName
    entry.quality = itemData.quality
    entry.qualityName = itemData.qualityName
    entry.trait = itemData.trait
    entry.traitType = itemData.traitType
    entry.apparelSlot = itemData.apparelSlot
    entry.equipType = itemData.equipType
    entry.apparelWeight = itemData.apparelWeight
    entry.armorType = itemData.armorType
    entry.weaponType = itemData.weaponType
    entry.weaponHandedness = itemData.weaponHandedness
    entry.weaponTypeId = itemData.weaponTypeId
    entry.furnitureDataId = itemData.furnitureDataId
    entry.setName = itemData.setName or ""
    entry.enchantName = itemData.enchantName or ""
    entry.styleName = itemData.styleName or ""
    entry.requiredLevel = tonumber(itemData.requiredLevel or 0) or 0
    entry.requiredCp = tonumber(itemData.requiredCp or 0) or 0
    entry.flavorText = itemData.flavorText or ""
    entry.esoDetails = itemData.esoDetails or {}
    entry.bagId = itemData.bagId
    entry.slotIndex = itemData.slotIndex
    entry.locationKey = itemData.locationKey
    entry.sharedFrom = itemData.sharedFrom
    -- What the bag reported is kept beside what is actually offered, so the number
    -- on the site and the number kept back can never drift apart.
    local heldCount = math.max(0, math.floor(tonumber(count) or 0))
    entry.heldCount = heldCount
    entry.firstDumpedAt = tonumber(firstDumpedAt or entry.firstDumpedAt or now) or now
    entry.lastDumpedAt = now

    ItemShare.savedVars.sharedItems[itemData.itemKey] = entry
    TryRefreshInventoryVisuals()
    if refreshListWindow ~= false then
        RefreshShareListWindowIfVisible()
    end
    return entry
end

SaveSharedEntryFromSavedEntry = function(entry, refreshListWindow)
    if not entry or not entry.itemLink then
        return nil
    end

    local locationKey = tostring(entry.locationKey or "")
    if locationKey == "" then
        locationKey = BuildLocationKeyFromSharedFrom(entry.sharedFrom)
    end

    local itemData = {
        itemKey = BuildSharedItemKey(entry.itemLink, locationKey),
        itemName = entry.itemName,
        itemLink = entry.itemLink,
        itemId = entry.itemId,
        icon = entry.icon,
        itemType = entry.itemType,
        itemTypeName = entry.itemTypeName,
        quality = entry.quality,
        qualityName = entry.qualityName,
        trait = entry.trait,
        traitType = entry.traitType,
        apparelSlot = entry.apparelSlot,
        equipType = entry.equipType,
        apparelWeight = entry.apparelWeight,
        armorType = entry.armorType,
        weaponType = entry.weaponType,
        weaponHandedness = entry.weaponHandedness,
        weaponTypeId = entry.weaponTypeId,
        furnitureDataId = entry.furnitureDataId,
        setName = entry.setName,
        enchantName = entry.enchantName,
        styleName = entry.styleName,
        requiredLevel = entry.requiredLevel,
        requiredCp = entry.requiredCp,
        flavorText = entry.flavorText,
        esoDetails = entry.esoDetails,
        bagId = entry.bagId,
        slotIndex = entry.slotIndex,
        locationKey = locationKey,
        sharedFrom = entry.sharedFrom,
    }

    return SaveSharedEntry(itemData, GetEntryHeldCount(entry), entry.firstDumpedAt or GetTimeStamp(), refreshListWindow)
end

-- "Placed" shares: furniture standing in a house rather than held in a bag.
--
-- Only the house the character is standing in can be read, and a piece on display
-- says nothing about where it came from, so this is not something the addon can
-- infer safely. The player says it instead: /ishare scan in the storage house files
-- every non-bound furnishing standing there as Placed (<house>), one row per
-- furnishing with the number of copies, and running it again is the record of what
-- that house still holds.
--
-- Placed furniture is enumerated by id, never by index: there is no
-- GetPlacedFurnitureCount/GetPlacedFurnitureIdInfo pair in the housing API, so the old
-- code fell through to the iterator and then read the details out of the wrong positions.
-- Each id is asked for its own details, and the link comes from the housing API instead of
-- being rebuilt from a data id that was never read.
local function GetPlacedFurniturePieces()
    if not GetNextPlacedHousingFurnitureId then
        return nil
    end

    local pieces = {}
    local furnitureId = GetNextPlacedHousingFurnitureId(nil)
    -- A guard rather than a trust: an iterator that stopped advancing would hang the
    -- client, and 5000 placed pieces is far past any house limit.
    local guard = 0

    while furnitureId and guard < 5000 do
        guard = guard + 1

        local piece = { furnitureId = furnitureId, name = "", icon = "", furnitureDataId = 0 }

        if GetPlacedHousingFurnitureInfo then
            -- name, icon, furniture data id - in that order.
            local infoOk, name, icon, furnitureDataId = pcall(GetPlacedHousingFurnitureInfo, furnitureId)
            if infoOk then
                piece.name = type(name) == "string" and name or ""
                piece.icon = type(icon) == "string" and icon or ""
                piece.furnitureDataId = tonumber(furnitureDataId) or 0
            end
        end

        if GetPlacedFurnitureLink then
            -- Two returns: the item link, and the collectible link of a collectible
            -- furnishing, which is not an item and therefore has no item link at all.
            -- Reading only the first made every collectible look like a failed call.
            local linkOk, itemLink, collectibleLink = pcall(GetPlacedFurnitureLink, furnitureId, LINK_STYLE_DEFAULT)
            if linkOk then
                piece.link = type(itemLink) == "string" and itemLink or ""
                piece.collectibleLink = type(collectibleLink) == "string" and collectibleLink or ""
            end
        end

        if GetPlacedHousingFurnitureQuality then
            local qualityOk, quality = pcall(GetPlacedHousingFurnitureQuality, furnitureId)
            if qualityOk then
                piece.quality = quality
            end
        end

        pieces[#pieces + 1] = piece
        furnitureId = GetNextPlacedHousingFurnitureId(furnitureId)
    end

    return pieces
end

-- A placed piece is described by its furniture data id, not by a bag slot, so the
-- item link has to be made from that id. Each step is a getter the client may or may
-- not have: a piece nothing can name is counted and reported rather than guessed at.
local function GetLinkForFurnitureDataId(furnitureDataId, info, inventoryIndex)
    local dataId = tonumber(furnitureDataId) or 0
    if dataId <= 0 then
        return ""
    end

    if GetItemLinkFromFurnitureDataId then
        local ok, link = pcall(GetItemLinkFromFurnitureDataId, dataId)
        if ok and type(link) == "string" and link ~= "" then
            return link
        end
    end

    for _, value in ipairs(info or {}) do
        if type(value) == "string" and string.find(value, "|H1:item:", 1, true) then
            return value
        end
    end

    -- Last resort: the same furnishing sitting in a readable bag carries the link,
    -- and matching on the data id is what the addon already trusts.
    local index = inventoryIndex or BuildActualInventoryIndex()
    for _, place in pairs(index.locationsByLink or {}) do
        local itemData = place and place.itemData
        if itemData and tonumber(itemData.furnitureDataId) == dataId and tostring(itemData.itemLink or "") ~= "" then
            return itemData.itemLink
        end
    end

    return ""
end

local function BuildPlacedItemData(link, furnitureDataId, sharedFrom, locationKey)
    local nameOk, itemName = pcall(GetItemLinkName, link)
    local iconOk, icon = pcall(GetItemLinkInfo, link)
    local itemIdOk, itemId = pcall(GetItemLinkItemId, link)
    local qualityOk, quality = pcall(GetItemLinkQuality, link)

    return {
        itemKey = BuildSharedItemKey(link, locationKey),
        itemName = (nameOk and type(itemName) == "string" and itemName ~= "" and itemName) or link,
        itemLink = link,
        itemId = (itemIdOk and tonumber(itemId)) or 0,
        icon = (iconOk and type(icon) == "string" and icon) or "",
        itemType = ITEMTYPE_FURNISHING,
        itemTypeName = "Furnishing",
        quality = qualityOk and quality or nil,
        furnitureDataId = tonumber(furnitureDataId) or 0,
        locationKey = locationKey,
        sharedFrom = sharedFrom,
    }
end

-- Reads the house once and treats that reading as the truth for it: a piece on
-- display is shared with the number of copies standing there, a share filed under
-- this house that is no longer in it is taken back, and every other house is left
-- alone because nothing here can see it.
-- The house owner and the player are both display names, but one may carry the @ the
-- other lacks and the case is not guaranteed, so both are flattened before comparing.
local function NormalizeHouseOwnerName(name)
    local text = string.gsub(tostring(name or ""), "^@", "")
    return zo_strlower(text)
end

-- Where the scan is standing, and whether that is a house this character owns. Reading
-- placed furniture works in any home, but filing it is only honest for your own: a
-- piece in someone else's house is not yours to offer.
local function GetCurrentHouseScanInfo()
    if not GetCurrentZoneHouseId then
        return nil, "This client cannot tell whether you are in a house, so there is nothing to scan or clear."
    end

    local idOk, idValue = pcall(GetCurrentZoneHouseId)
    local houseId = idOk and (tonumber(idValue) or 0) or 0
    if houseId <= 0 then
        return nil, "You are not inside a house, so there is nothing to scan or clear. Stand in the house first."
    end

    local houseName = GetCurrentZoneDisplayName()

    local ownerName = ""
    if GetCurrentHouseOwner then
        local ownerOk, ownerValue = pcall(GetCurrentHouseOwner)
        if ownerOk and type(ownerValue) == "string" then
            ownerName = GetNormalizedText(ownerValue) or ""
        end
    end

    -- Best effort: a client that does not name the owner cannot prove ownership, so the
    -- scan goes ahead rather than refusing a house the player is standing in.
    if ownerName ~= "" then
        local ownerKey = NormalizeHouseOwnerName(ownerName)
        local ownsHouse = false

        if GetDisplayName then
            local nameOk, nameValue = pcall(GetDisplayName)
            if nameOk and type(nameValue) == "string" and NormalizeHouseOwnerName(nameValue) == ownerKey then
                ownsHouse = true
            end
        end
        if not ownsHouse and NormalizeHouseOwnerName(GetCurrentCharacterName()) == ownerKey then
            ownsHouse = true
        end

        if not ownsHouse then
            return nil, string.format(
                "This house belongs to %s. Furniture is only scanned or cleared for a house you own, so nothing was done.",
                ownerName
            )
        end
    end

    return {
        houseId = houseId,
        houseName = houseName,
        ownerName = ownerName,
    }
end

-- Reads the house once and treats that reading as the truth for it: a piece on
-- display is shared with the number of copies standing there, a share filed under
-- this house that is no longer in it is taken back, and every other house is left
-- alone because nothing here can see it.
local function ScanPlacedFurnishings()
    -- Said before anything is read: finding the house and listing its furniture both
    -- take a moment, and a silent pause reads as a hung client.
    PrintMessage("Scanning, one moment...")

    local house, problem = GetCurrentHouseScanInfo()
    if not house then
        PrintMessage(problem)
        return
    end

    local pieces = GetPlacedFurniturePieces()
    if not pieces then
        PrintMessage("This client cannot list placed furniture, so nothing was scanned.")
        return
    end

    local houseLabel = house.houseName ~= "" and house.houseName or "this house"
    local placedKey, placedLabel = GetPlacedLocationInfo(house.houseName)

    local copiesByLink = {}
    local dataIdByLink = {}
    local boundCount, collectibleCount, unreadableCount, unboundCount = 0, 0, 0, 0
    -- Built once, and only if a piece needs it: rebuilding the bag index for every
    -- unlinked piece is most of what made a full house feel like a pause.
    local bagIndex = nil

    for _, piece in ipairs(pieces) do
        local furnitureDataId = tonumber(piece.furnitureDataId) or 0
        local collectibleLink = tostring(piece.collectibleLink or "")

        local link = tostring(piece.link or "")
        if link == "" then
            -- Older clients may have no GetPlacedFurnitureLink; the data id is the only
            -- other route to a link, and it stays 0 when even the info call failed.
            if not bagIndex then
                bagIndex = BuildActualInventoryIndex()
            end
            link = GetLinkForFurnitureDataId(furnitureDataId, { piece.name, piece.icon }, bagIndex)
        end

        if link == "" then
            if collectibleLink ~= "" then
                -- A collectible furnishing is not an item: it has no link to offer and
                -- cannot be given away, so it is counted apart from a failure.
                collectibleCount = collectibleCount + 1
            else
                unreadableCount = unreadableCount + 1
            end
        else
            local boundOk, isBound = pcall(IsItemLinkBound, link)

            if not boundOk then
                -- A bound state nothing could answer is not a licence to offer it.
                unreadableCount = unreadableCount + 1
            elseif isBound == true then
                -- Bound is bound: a piece that can never leave the account is not an
                -- offer, whichever house it stands in.
                boundCount = boundCount + 1
            else
                copiesByLink[link] = (copiesByLink[link] or 0) + 1
                dataIdByLink[link] = dataIdByLink[link] or furnitureDataId
                unboundCount = unboundCount + 1
            end
        end
    end

    local sharedItems = ItemShare.savedVars.sharedItems
    local removedCount = 0

    for itemKey, entry in pairs(sharedItems) do
        local entryKey = tostring(entry and entry.locationKey or "")
        if entryKey == placedKey and copiesByLink[tostring(entry and entry.itemLink or "")] == nil then
            sharedItems[itemKey] = nil
            removedCount = removedCount + 1
        end
    end

    for link, copies in pairs(copiesByLink) do
        local existing = sharedItems[BuildSharedItemKey(link, placedKey)]
        local itemData = BuildPlacedItemData(link, dataIdByLink[link], placedLabel, placedKey)
        SaveSharedEntry(itemData, copies, existing and existing.firstDumpedAt or GetTimeStamp(), false)
    end

    RefreshShareListWindowIfVisible()

    local skippedParts = {}
    if boundCount > 0 then
        skippedParts[#skippedParts + 1] = string.format("%d bound", boundCount)
    end
    if collectibleCount > 0 then
        skippedParts[#skippedParts + 1] = string.format("%d collectible", collectibleCount)
    end
    if unreadableCount > 0 then
        skippedParts[#skippedParts + 1] = string.format("%d unreadable", unreadableCount)
    end
    local skippedText = ""
    if #skippedParts > 0 then
        skippedText = string.format(" (%s skipped)", table.concat(skippedParts, ", "))
    end

    PrintMessage(string.format(
        "Scan complete: %d unbound item%s found in %s%s.",
        unboundCount,
        unboundCount == 1 and "" or "s",
        houseLabel,
        skippedText
    ))

    if removedCount > 0 then
        PrintMessage(string.format(
            "%d share%s filed under %s %s no longer in the house and %s removed.",
            removedCount,
            removedCount == 1 and "" or "s",
            placedLabel,
            removedCount == 1 and "was" or "were",
            removedCount == 1 and "was" or "were"
        ))
    end

    if unboundCount > 0 or removedCount > 0 then
        PrintMessage("Use /ishare save or /reloadui to write the change to the file.")
    end
end

-- /ishare scan clear: the way out of a house that was scanned by mistake, or one that
-- has stopped being the storage house. Only the house the player is standing in is
-- touched, and only rows keyed to it - the house name is the whole key, so a row filed
-- under another house or under a bag cannot be caught by this.
local function ClearPlacedFurnishingsForCurrentHouse()
    local house, problem = GetCurrentHouseScanInfo()
    if not house then
        PrintMessage(problem)
        return
    end

    local placedKey, placedLabel = GetPlacedLocationInfo(house.houseName)
    local sharedItems = ItemShare.savedVars.sharedItems
    local cleared = 0

    for itemKey, entry in pairs(sharedItems) do
        if tostring(entry and entry.locationKey or "") == placedKey then
            sharedItems[itemKey] = nil
            cleared = cleared + 1
        end
    end

    TryRefreshInventoryVisuals()
    RefreshShareListWindowIfVisible()

    if cleared == 0 then
        PrintMessage(string.format("No shares were filed under %s, so there was nothing to clear.", placedLabel))
        return
    end

    PrintMessage(string.format(
        "Cleared %d share%s filed under %s. Run /ishare save or /reloadui to write the change to the file.",
        cleared,
        cleared == 1 and "" or "s",
        placedLabel
    ))
end


-- Files written before this release recorded placed furniture under a key of their
-- own, with no way to tell a piece that had been picked up from one that was never
-- placed. That idea is gone, so those rows go with it, once, with a message saying
-- how to file them again the new way.
local function PruneLegacyPlacedFurnitureShares()
    local sharedItems = ItemShare.savedVars and ItemShare.savedVars.sharedItems
    if type(sharedItems) ~= "table" then
        return 0
    end

    local removed = 0
    for itemKey, entry in pairs(sharedItems) do
        local locationKey = tostring(entry and entry.locationKey or "")
        if locationKey == "" then
            locationKey = BuildLocationKeyFromSharedFrom(entry and entry.sharedFrom)
        end
        local legacyPrefix = string.sub(locationKey, 1, 16)
        if legacyPrefix == "placedfurniture" or legacyPrefix == "placed furniture" then
            sharedItems[itemKey] = nil
            removed = removed + 1
        end
    end

    return removed
end

-- "Always share" is a standing offer rather than an inventory entry: it says "if
-- I ever have this again, offer it". It lives in its own table so the rebuild
-- pass, which prunes anything missing from a readable bag, can never delete it.
GetAlwaysShareTable = function()
    if not ItemShare.savedVars then
        return {}
    end
    if type(ItemShare.savedVars.alwaysShare) ~= "table" then
        ItemShare.savedVars.alwaysShare = {}
    end
    return ItemShare.savedVars.alwaysShare
end

-- Keyed by item link and place: a standing offer belongs to the place it was marked
-- in, so marking lockpicks in your bags does not also mark the stack in the bank. The
-- link stays in the key so the offer still names the item once that place holds none.
GetAlwaysShareKey = function(itemLink, locationKey)
    return BuildSharedItemKey(itemLink, locationKey)
end

-- A file written before offers were tied to a place keeps them under the item link
-- alone. Those are moved onto a place key at load, using the place the offer recorded
-- if it has one; one that recorded none is picked up by the next sync, which adopts the
-- bag the item is in and re-keys it then.
local function ReindexAlwaysShareTable()
    local alwaysShare = GetAlwaysShareTable()
    local moves = {}

    for key, entry in pairs(alwaysShare) do
        if type(entry) == "table" then
            local link = tostring(entry.itemLink or "")
            if link ~= "" then
                local wanted = GetAlwaysShareKey(link, entry.locationKey)
                if key ~= wanted then
                    moves[#moves + 1] = { from = key, to = wanted, entry = entry }
                end
            end
        end
    end

    local moved = 0
    for _, move in ipairs(moves) do
        if alwaysShare[move.from] == move.entry then
            alwaysShare[move.from] = nil
        end
        if alwaysShare[move.to] == nil then
            alwaysShare[move.to] = move.entry
            moved = moved + 1
        end
    end

    return moved
end

SaveAlwaysShareEntry = function(itemData, heldCount)
    if not itemData or not itemData.itemLink or itemData.itemLink == "" then
        return nil
    end

    if IsItemLinkBound(itemData.itemLink) then
        return nil
    end

    local alwaysShare = GetAlwaysShareTable()
    local key = GetAlwaysShareKey(itemData.itemLink, itemData.locationKey)
    local now = GetTimeStamp()
    local entry = alwaysShare[key] or {}

    entry.characterName = GetCurrentCharacterName()
    entry.itemName = itemData.itemName
    entry.itemLink = itemData.itemLink
    entry.itemId = tonumber(itemData.itemId or 0) or 0
    -- A getter that answers nothing must not erase an icon captured earlier: the
    -- path is what the site caches the image from, and it does not change.
    entry.icon = (tostring(itemData.icon or "") ~= "" and tostring(itemData.icon)) or entry.icon or ""
    entry.itemType = itemData.itemType
    entry.itemTypeName = itemData.itemTypeName
    entry.quality = itemData.quality
    entry.qualityName = itemData.qualityName
    entry.trait = itemData.trait
    entry.traitType = itemData.traitType
    entry.apparelSlot = itemData.apparelSlot
    entry.equipType = itemData.equipType
    entry.apparelWeight = itemData.apparelWeight
    entry.armorType = itemData.armorType
    entry.weaponType = itemData.weaponType
    entry.weaponHandedness = itemData.weaponHandedness
    entry.weaponTypeId = itemData.weaponTypeId
    entry.furnitureDataId = itemData.furnitureDataId
    entry.setName = itemData.setName or ""
    entry.enchantName = itemData.enchantName or ""
    entry.styleName = itemData.styleName or ""
    entry.requiredLevel = tonumber(itemData.requiredLevel or 0) or 0
    entry.requiredCp = tonumber(itemData.requiredCp or 0) or 0
    entry.flavorText = itemData.flavorText or ""
    entry.esoDetails = itemData.esoDetails or {}
    -- Where it was marked, and how many were there. A standing offer's number is the count
    -- in that one place, so the offer has to remember the place as well as the number: the
    -- site can only show what is held when it is told, and a reserve belongs to a place.
    -- A caller that knows neither leaves what was recorded alone rather than wiping it.
    entry.locationKey = tostring(itemData.locationKey or entry.locationKey or "")
    entry.sharedFrom = tostring(itemData.sharedFrom or entry.sharedFrom or "")

    local knownHeld = tonumber(heldCount)

    if knownHeld == nil then
        knownHeld = tonumber(itemData.heldCount)
    end

    if knownHeld ~= nil then
        entry.heldCount = math.max(0, math.floor(knownHeld))
    end

    entry.firstAddedAt = entry.firstAddedAt or now
    entry.lastUpdatedAt = now
    alwaysShare[key] = entry
    return entry
end

-- An item is offered one way at a time: shared from a bag right now, or always
-- offered from then on. These two are what "one way" means in the saved tables, and
-- both refresh what is on screen afterwards so an open list cannot keep showing the
-- state it was opened with.
RemoveSharesForItemLink = function(itemLink)
    local link = tostring(itemLink or "")
    if link == "" then
        return 0
    end

    local keys = {}
    for itemKey, entry in pairs(ItemShare.savedVars.sharedItems or {}) do
        if type(entry) == "table" and tostring(entry.itemLink or "") == link then
            keys[#keys + 1] = itemKey
        end
    end

    for _, itemKey in ipairs(keys) do
        ItemShare.savedVars.sharedItems[itemKey] = nil
    end

    return #keys
end

RemoveAlwaysShareForItemLink = function(itemLink, locationKey)
    local link = tostring(itemLink or "")
    if link == "" then
        return nil
    end

    local alwaysShare = GetAlwaysShareTable()

    -- With a place, only that place stops being offered. Without one, every place the
    -- item was marked in stops, which is what taking the item off the list means.
    if locationKey ~= nil then
        local key = GetAlwaysShareKey(link, locationKey)
        local existing = alwaysShare[key]
        if existing ~= nil then
            alwaysShare[key] = nil
        end
        return existing
    end

    local removed = nil
    for key, entry in pairs(alwaysShare) do
        if type(entry) == "table" and tostring(entry.itemLink or "") == link then
            alwaysShare[key] = nil
            removed = removed or entry
        end
    end

    return removed
end

local function AddAlwaysShareFromBagSlot(bagId, slotIndex)
    local isEligible, reason = IsItemEligibleForShare(bagId, slotIndex)
    if not isEligible then
        PrintMessage(string.format("Cannot always share that item: %s", tostring(reason)))
        return
    end

    local itemData = GetItemDataFromBagSlot(bagId, slotIndex)
    if not itemData then
        PrintMessage("Could not determine item data.")
        return
    end

    local existing = GetAlwaysShareTable()[GetAlwaysShareKey(itemData.itemLink, itemData.locationKey)]
    -- The offer starts at what this place holds of it right now, so marking the last
    -- copy is an offer of one and handing it over later leaves the row at 0.
    local markedCount = GetLocationShareCount(bagId, itemData.itemLink)
    if markedCount <= 0 then
        markedCount = GetItemShareCount(bagId, slotIndex)
    end
    SaveAlwaysShareEntry(itemData, markedCount)

    -- The standing offer replaces any share of the same item, in whichever bag it was
    -- filed from. Doing it before the refresh means the window redraws once, already
    -- showing the item as offered rather than shared.
    local removedShares = RemoveSharesForItemLink(itemData.itemLink)

    TryRefreshInventoryVisuals()
    RefreshShareListWindowIfVisible()
    PrintMessage(string.format(
        "%s always shared item %s. It stays offered even when you do not have one.",
        existing and "Updated" or "Added",
        itemData.itemName
    ))
    if removedShares > 0 then
        PrintMessage(string.format(
            "Removed %s from the shared list: an item is offered one way at a time.",
            itemData.itemName
        ))
    end
end

local function PrintAlwaysShareItems()
    local alwaysShare = GetAlwaysShareTable()
    local entries = {}

    for _, entry in pairs(alwaysShare) do
        if type(entry) == "table" then
            entries[#entries + 1] = entry
        end
    end

    if #entries == 0 then
        PrintMessage("Nothing is always shared yet. Right-click an item and choose \"Always Share This Item\".")
        return
    end

    table.sort(entries, function(left, right)
        local leftName = zo_strlower(tostring(left.itemName or ""))
        local rightName = zo_strlower(tostring(right.itemName or ""))
        if leftName ~= rightName then
            return leftName < rightName
        end
        return zo_strlower(tostring(left.sharedFrom or left.locationKey or ""))
            < zo_strlower(tostring(right.sharedFrom or right.locationKey or ""))
    end)

    PrintMessage(string.format("Always shared (%d):", #entries))
    for index, entry in ipairs(entries) do
        local place = tostring(entry.sharedFrom or entry.locationKey or "")
        PrintMessage(string.format(
            "  %d. %s%s",
            index,
            tostring(entry.itemName or entry.itemLink or "Unknown item"),
            place ~= "" and string.format(" - %s", place) or ""
        ))
    end
    PrintMessage("Remove one with /itemshare noalways <part of the name>.")
end

local function RemoveAlwaysShareByName(searchText)
    local needle = zo_strlower(zo_strtrim(tostring(searchText or "")))
    if needle == "" then
        PrintMessage("Usage: /itemshare noalways <part of the item name>")
        return
    end

    local alwaysShare = GetAlwaysShareTable()
    local matches = {}

    for key, entry in pairs(alwaysShare) do
        if type(entry) == "table" then
            local name = zo_strlower(tostring(entry.itemName or ""))
            if name ~= "" and string.find(name, needle, 1, true) then
                matches[#matches + 1] = { key = key, entry = entry }
            end
        end
    end

    if #matches == 0 then
        PrintMessage(string.format("No always-shared item matches \"%s\".", tostring(searchText)))
        return
    end

    -- One item can now stand in several places, so a name matches each place it was
    -- marked in. Every one of them stops being offered, and the message says where.
    local places = {}

    for _, match in ipairs(matches) do
        alwaysShare[match.key] = nil
        local place = tostring(match.entry.sharedFrom or "")
        if place == "" then
            place = tostring(match.entry.locationKey or "")
        end
        if place == "" then
            place = "unknown place"
        end
        places[#places + 1] = place
    end

    table.sort(places)
    TryRefreshInventoryVisuals()
    RefreshShareListWindowIfVisible()

    if #matches == 1 then
        PrintMessage(string.format(
            "Stopped always sharing %s - %s.",
            tostring(matches[1].entry.itemName or matches[1].key),
            places[1]
        ))
        return
    end

    PrintMessage(string.format(
        "Stopped always sharing %s in %d places: %s.",
        tostring(matches[1].entry.itemName or "that item"),
        #matches,
        table.concat(places, ", ")
    ))
end

local function RemoveItemFromShareFromBagSlot(bagId, slotIndex)
    local itemData = GetItemDataFromBagSlot(bagId, slotIndex)
    if not itemData or not itemData.itemLink or not itemData.itemName then
        PrintMessage("Could not determine item data.")
        return
    end

    local existing = ItemShare.savedVars.sharedItems[itemData.itemKey]
    if existing then
        RemoveItemFromShareByKey(itemData.itemKey, existing, true)
    else
        PrintMessage(string.format("Item was not found in shared list: %s", itemData.itemName))
    end
end

local function AddInventoryContextMenu(slot)
    if not slot or slot.bagId == nil or slot.slotIndex == nil then
        return
    end

    local bagId = slot.bagId
    local slotIndex = slot.slotIndex

    if not CanModifyGuildBankShare(bagId, slotIndex, GetSelectedGuildBankId and GetSelectedGuildBankId() or nil) then
        return
    end
    local itemLink = GetNormalizedItemLink(bagId, slotIndex)
    local itemName = GetNormalizedItemName(bagId, slotIndex)
    if not itemLink or not itemName then
        return
    end

    local sharedEntryKey = FindSharedEntryKeyForBagSlot(bagId, slotIndex)
    local isEligible = IsItemEligibleForShare(bagId, slotIndex)

    if sharedEntryKey then
        AddCustomMenuItem("Remove from Shared List", function()
            RemoveItemFromShareFromBagSlot(bagId, slotIndex)
        end, MENU_ADD_OPTION_LABEL)
    elseif isEligible then
        AddCustomMenuItem("Add to Share", function()
            AddItemToShareFromBagSlot(bagId, slotIndex)
        end, MENU_ADD_OPTION_LABEL)
    end

    -- The standing offer is independent of this copy: an item can be shared right
    -- now and marked to always share at the same time, so it gets its own entry
    -- rather than replacing the one above.
    local bagLocationKey = select(1, GetBagLocationInfo(bagId))
    local alwaysKey = GetAlwaysShareKey(itemLink, bagLocationKey)
    if GetAlwaysShareTable()[alwaysKey] then
        AddCustomMenuItem("Stop Always Sharing", function()
            local entry = GetAlwaysShareTable()[alwaysKey]
            GetAlwaysShareTable()[alwaysKey] = nil
            -- The badge and the share list are drawn from this table. Without a
            -- redraw the gold icon stayed on the item and the list kept showing it
            -- until the UI was reloaded, so the removal looked like it had failed.
            TryRefreshInventoryVisuals()
            RefreshShareListWindowIfVisible()
            PrintMessage(string.format(
                "Stopped always sharing %s.",
                tostring(entry and entry.itemName or itemName)
            ))
        end, MENU_ADD_OPTION_LABEL)
    elseif isEligible then
        AddCustomMenuItem("Always Share This Item", function()
            AddAlwaysShareFromBagSlot(bagId, slotIndex)
        end, MENU_ADD_OPTION_LABEL)
    end

    -- The reserve belongs to this place: the same item can keep 50 back in the bank
    -- and nothing back in your bags, so the menu speaks for the bag it was opened on.
    -- A bound item cannot be shared, so a reserve on it would never count and the menu
    -- offers no way to set one. An existing reserve can still be cleared, because a
    -- reserve outlives the share it was set beside and would otherwise be stuck.
    local reserveLocationKey = select(1, GetBagLocationInfo(bagId))
    local reserve = GetShareReserve(itemLink, reserveLocationKey)
    if reserve > 0 then
        if isEligible then
            AddCustomMenuItem(string.format("Share Reserve: Keep %d Back...", reserve), function()
                if OpenShareReserveDialog then
                    OpenShareReserveDialog(bagId, slotIndex)
                end
            end, MENU_ADD_OPTION_LABEL)
        end
        AddCustomMenuItem("Clear Share Reserve", function()
            if ApplyShareReserve then
                ApplyShareReserve(itemLink, 0, reserveLocationKey)
                PrintMessage(string.format("Share reserve cleared for %s.", tostring(itemName)))
            end
        end, MENU_ADD_OPTION_LABEL)
    elseif isEligible then
        AddCustomMenuItem("Share Reserve", function()
            if OpenShareReserveDialog then
                OpenShareReserveDialog(bagId, slotIndex)
            end
        end, MENU_ADD_OPTION_LABEL)
    end
end

-- ---------------------------------------------------------------- keybinds --
-- Both menu entries are also keybinds, listed in the game's own keybind list: ESC, Controls,
-- Keybinds, category ItemShare. A keybind has no row to click, so each one acts on the item
-- last hovered - hovering is the only way the addon is told which item you mean.
ZO_CreateStringId("SI_BINDING_NAME_ITEMSHARE_TOGGLE_SHARE", "Toggle share on the hovered item")
ZO_CreateStringId("SI_BINDING_NAME_ITEMSHARE_TOGGLE_ALWAYS_SHARE", "Toggle always share on the hovered item")

local hoveredShareBagId, hoveredShareSlotIndex = nil, nil

local function RememberHoveredShareSlot(bagId, slotIndex)
    if type(bagId) == "number" and type(slotIndex) == "number" then
        hoveredShareBagId, hoveredShareSlotIndex = bagId, slotIndex
    end
end

-- Every item tooltip in the game goes through ItemTooltip:SetBagItem - a bag row, the bank,
-- house storage, the furnishing vault, the deconstruction panel - so hooking that is what
-- keeps the remembered slot honest instead of guessing from what has focus.
local function InstallHoveredShareSlotTracking()
    if type(ZO_PreHook) ~= "function" then
        return
    end
    if ItemTooltip == nil or type(ItemTooltip.SetBagItem) ~= "function" then
        return
    end

    ZO_PreHook(ItemTooltip, "SetBagItem", function(_, bagId, slotIndex)
        RememberHoveredShareSlot(bagId, slotIndex)
        return false
    end)
end

-- The remembered slot can go stale - the item was sold, moved, or the bag was closed - and
-- sharing whatever has since taken its place would be worse than doing nothing.
local function GetHoveredShareSlot()
    if hoveredShareBagId == nil or hoveredShareSlotIndex == nil then
        PrintMessage("Hover the item first, then press the key again.")
        return nil, nil
    end

    local itemLink = GetNormalizedItemLink(hoveredShareBagId, hoveredShareSlotIndex)
    if not itemLink or itemLink == "" then
        PrintMessage("Nothing is in that slot any more - hover the item and press again.")
        return nil, nil
    end

    return hoveredShareBagId, hoveredShareSlotIndex
end

-- Pressing the key on an item that is not shared shares it; pressing it again takes the share
-- back off. Sharing a copy replaces a standing offer of the same item, which is what the menu
-- does as well, so the two keybinds cannot leave an item in both states.
function ItemShare_ToggleShare()
    local bagId, slotIndex = GetHoveredShareSlot()
    if not bagId then
        return
    end

    if FindSharedEntryKeyForBagSlot(bagId, slotIndex) then
        RemoveItemFromShareFromBagSlot(bagId, slotIndex)
    else
        AddItemToShareFromBagSlot(bagId, slotIndex)
    end
end

-- The same for the standing offer: on, off, on, off. Marking one clears any share of the item,
-- and stopping one leaves the copy alone, so this goes through the same entries the menu uses.
function ItemShare_ToggleAlwaysShare()
    local bagId, slotIndex = GetHoveredShareSlot()
    if not bagId then
        return
    end

    local itemLink = GetNormalizedItemLink(bagId, slotIndex)
    local locationKey = select(1, GetBagLocationInfo(bagId))
    local alwaysShare = GetAlwaysShareTable()
    local key = (itemLink and locationKey) and GetAlwaysShareKey(itemLink, locationKey) or nil
    local existing = key and alwaysShare[key] or nil

    if existing then
        alwaysShare[key] = nil
        TryRefreshInventoryVisuals()
        RefreshShareListWindowIfVisible()
        PrintMessage(string.format(
            "Stopped always sharing %s.",
            tostring(existing.itemName or itemLink)
        ))
        return
    end

    AddAlwaysShareFromBagSlot(bagId, slotIndex)
end

local function RegisterContextMenus()
    if not LibCustomMenu then
        PrintMessage("LibCustomMenu not found.")
        return
    end

    LibCustomMenu:RegisterContextMenu(function(inventorySlot)
        AddInventoryContextMenu(inventorySlot)
    end, LibCustomMenu.CATEGORY_LATE)
end

local function ResetSharedItems()
    ItemShare.savedVars.sharedItems = {}
    PrintMessage("Saved variables reset. No shared items remain.")
    TryRefreshInventoryVisuals()
    RefreshShareListWindowIfVisible()
end

local function PrintSharedItems()
    RefreshShareListWindow()
end

local function GetTrackedBagIds()
    local bagIds = { BAG_BACKPACK, BAG_BANK }

    if BAG_SUBSCRIBER_BANK then
        table.insert(bagIds, BAG_SUBSCRIBER_BANK)
    end
    if BAG_VIRTUAL then
        table.insert(bagIds, BAG_VIRTUAL)
    end

    local houseBanks = {
        BAG_HOUSE_BANK_ONE,
        BAG_HOUSE_BANK_TWO,
        BAG_HOUSE_BANK_THREE,
        BAG_HOUSE_BANK_FOUR,
        BAG_HOUSE_BANK_FIVE,
        BAG_HOUSE_BANK_SIX,
        BAG_HOUSE_BANK_SEVEN,
        BAG_HOUSE_BANK_EIGHT,
        BAG_HOUSE_BANK_NINE,
        BAG_HOUSE_BANK_TEN,
    }

    for _, bagId in ipairs(houseBanks) do
        if bagId then
            table.insert(bagIds, bagId)
        end
    end

    if BAG_FURNITURE_VAULT then
        table.insert(bagIds, BAG_FURNITURE_VAULT)
    end
    if BAG_GUILDBANK then
        table.insert(bagIds, BAG_GUILDBANK)
    end

    return bagIds
end

-- The bags this addon counts are a fixed list, so a change anywhere else is none of
-- its business. Asked once per slot update, so it stays a plain walk of that list.
local function IsTrackedBagId(bagId)
    for _, trackedBagId in ipairs(GetTrackedBagIds()) do
        if trackedBagId == bagId then
            return true
        end
    end

    return false
end

BuildActualInventoryIndex = function()
    local countsByEntryKey = {}
    local countsByLink = {}
    local locationsByLink = {}
    local observableLocationKeys = {}

    for _, bagId in ipairs(GetTrackedBagIds()) do
        local locationKey, locationLabel = GetBagLocationInfo(bagId)
        local bagSize = GetBagSize(bagId) or 0
        if bagSize > 0 then
            -- A bag we can actually read is a bag we are allowed to judge. An
            -- unopened bank or guild bank reports size 0, and shares filed there
            -- must survive a reconcile that could not see them.
            observableLocationKeys[locationKey] = true
        end
        for slotIndex = 0, bagSize - 1 do
            local slotItemName = GetItemName(bagId, slotIndex)
            if slotItemName and slotItemName ~= "" then
                local isEligible = IsItemEligibleForShare(bagId, slotIndex)
                if isEligible then
                    local itemData = GetItemDataFromBagSlot(bagId, slotIndex)
                    if itemData and itemData.itemLink then
                        local stackCount = GetItemShareCount(bagId, slotIndex)
                        local entryKey = BuildSharedItemKey(itemData.itemLink, locationKey)

                        countsByEntryKey[entryKey] = {
                            count = (countsByEntryKey[entryKey] and countsByEntryKey[entryKey].count or 0) + stackCount,
                            sharedFrom = locationLabel,
                            locationKey = locationKey,
                            trait = tostring(itemData.trait or ""),
                            furnitureDataId = tonumber(itemData.furnitureDataId) or 0,
                            bagId = bagId,
                            slotIndex = slotIndex,
                            itemData = itemData,
                        }
                        countsByLink[itemData.itemLink] = (countsByLink[itemData.itemLink] or 0) + stackCount
                        if not locationsByLink[itemData.itemLink] then
                            locationsByLink[itemData.itemLink] = {
                                sharedFrom = locationLabel,
                                locationKey = locationKey,
                                bagId = bagId,
                                slotIndex = slotIndex,
                                itemData = itemData,
                            }
                        end

                    end
                end
            end
        end
    end

    return {
        observableLocationKeys = observableLocationKeys,
        countsByEntryKey = countsByEntryKey,
        countsByLink = countsByLink,
        locationsByLink = locationsByLink,
    }
end

-- The one place a readable index holds this link, if there is exactly one. A share whose
-- own place has run out is asking this question, and the answer has to be single: three
-- swords split across two bags and the bank is not an item that moved, and guessing would
-- put a lock on a copy nobody shared.
local function FindSolePlaceHoldingLink(inventoryIndex, itemLink, excludeLocationKey)
    local link = tostring(itemLink or "")
    if link == "" or not inventoryIndex then
        return nil
    end

    local found = nil
    for entryKey, place in pairs(inventoryIndex.countsByEntryKey or {}) do
        if type(place) == "table" then
            local placeLink, placeLocationKey = string.match(tostring(entryKey), "^(.*)||([^|]*)$")
            placeLink = tostring(placeLink or "")
            placeLocationKey = tostring(placeLocationKey or "")

            if placeLink == link
                and placeLocationKey ~= ""
                and placeLocationKey ~= tostring(excludeLocationKey or "")
                and (tonumber(place.count or 0) or 0) > 0 then
                if found ~= nil then
                    return nil
                end

                found = {
                    locationKey = placeLocationKey,
                    sharedFrom = tostring(place.sharedFrom or ""),
                    count = math.max(0, tonumber(place.count or 0) or 0),
                }
            end
        end
    end

    return found
end

-- A share is filed against the place it was made from, so it has to be re-filed when the
-- copy moves: something shared from your bags and then banked used to drop off the list at
-- the next pass, because the place it named held nothing and the addon could not tell that
-- apart from sold. It can tell, as long as the item is plainly in one other place - and when
-- it is not, the row is left exactly where it was rather than moved on a guess.
local function FindAlternateSharedEntryMatch(entry, inventoryIndex)
    if not entry or not inventoryIndex then
        return nil
    end

    local entryItemLink = tostring(entry.itemLink or "")
    if entryItemLink == "" then
        return nil
    end

    local entryTrait = tostring(entry.trait or "")
    local entryLocationKey = tostring(entry.locationKey or BuildLocationKeyFromSharedFrom(entry.sharedFrom) or "")

    local found = nil

    for entryKey, actualEntry in pairs(inventoryIndex.countsByEntryKey or {}) do
        if entryKey ~= "" and entryKey ~= BuildSharedItemKey(entry.itemLink, entry.locationKey) and type(actualEntry) == "table" then
            local actualItemLink, actualLocationKey = string.match(entryKey, "^(.*)||([^|]*)$")
            actualItemLink = tostring(actualItemLink or "")
            actualLocationKey = tostring(actualLocationKey or "")

            if actualItemLink == entryItemLink and actualLocationKey ~= "" and actualLocationKey ~= entryLocationKey then
                local actualTrait = tostring(actualEntry.trait or "")
                local traitMatches = (entryTrait == "" and actualTrait == "") or (entryTrait ~= "" and actualTrait == entryTrait)

                if traitMatches then
                    if found ~= nil and found.locationKey ~= actualLocationKey then
                        -- Two places hold it, so this is not a move and nothing follows.
                        return nil
                    end

                    found = {
                        itemKey = entryKey,
                        locationKey = actualLocationKey,
                        sharedFrom = tostring(actualEntry.sharedFrom or entry.sharedFrom or "-"),
                        count = tonumber(actualEntry.count or 0) or 0,
                        bagId = actualEntry.bagId,
                        slotIndex = actualEntry.slotIndex,
                        itemData = actualEntry.itemData,
                    }
                end
            end
        end
    end

    return found
end

local function ShowSyncSummary(actionName, updatedCount, removedCount, unchangedCount, quiet)
    local summary = string.format(
        "%s complete. Updated: %d, Removed: %d, Unchanged: %d",
        tostring(actionName or "Sync"),
        updatedCount,
        removedCount,
        unchangedCount
    )

    -- Left silent on purpose: a sync or rebuild is usually an automatic pass the player
    -- never asked for, so the counts line read as spam. Kept here, commented out, so it
    -- can be switched back on without being rewritten.
    -- PrintMessage(summary)
    if not quiet then
        PrintMessage("Use /ishare save or /reloadui to persist changes.")
    end
end

-- A standing offer is a promise about one place: the number beside it is what that
-- place holds of the item, and sync, rebuild and the login pass all come through here
-- to keep it true. A place that cannot be read this session keeps the number it had,
-- because a shut bank proves nothing about what is inside it - the same rule shares use.
RefreshAlwaysShareHeldCounts = function(inventoryIndex)
    local alwaysShare = ItemShare.savedVars and ItemShare.savedVars.alwaysShare
    if type(alwaysShare) ~= "table" or not inventoryIndex then
        return 0
    end

    local changed = 0
    local rekeys = {}
    for key, entry in pairs(alwaysShare) do
        if type(entry) == "table" then
            local link = tostring(entry.itemLink or "")
            local locationKey = tostring(entry.locationKey or "")

            if link ~= "" then
                local held = nil

                if locationKey ~= "" then
                    local place = inventoryIndex.countsByEntryKey
                        and inventoryIndex.countsByEntryKey[BuildSharedItemKey(link, locationKey)]
                    if type(place) == "table" then
                        held = math.max(0, tonumber(place.count or 0) or 0)
                        entry.sharedFrom = tostring(place.sharedFrom or entry.sharedFrom or "")
                    elseif inventoryIndex.observableLocationKeys
                        and inventoryIndex.observableLocationKeys[locationKey] == true then
                        -- That place is readable and holds none of it, so the copy has
                        -- moved or gone. If exactly one other place holds the item, the
                        -- offer goes with it: an offer is about the item, and dropping to
                        -- zero in a place you emptied read as the offer having stopped.
                        local movedTo = FindSolePlaceHoldingLink(inventoryIndex, link, locationKey)
                        if movedTo then
                            entry.locationKey = tostring(movedTo.locationKey or "")
                            entry.sharedFrom = tostring(movedTo.sharedFrom or "")
                            held = movedTo.count
                        else
                            held = 0
                        end
                    end
                else
                    -- An offer saved before the place was recorded adopts the place the
                    -- item is in now, once, so it has somewhere to count from.
                    for entryKey, place in pairs(inventoryIndex.countsByEntryKey or {}) do
                        local placeLink, placeLocationKey = string.match(tostring(entryKey), "^(.*)||([^|]*)$")
                        if tostring(placeLink or "") == link and type(place) == "table" then
                            entry.locationKey = tostring(placeLocationKey or "")
                            entry.sharedFrom = tostring(place.sharedFrom or "")
                            held = math.max(0, tonumber(place.count or 0) or 0)
                            break
                        end
                    end
                end

                if held ~= nil and held ~= GetEntryHeldCount(entry) then
                    entry.heldCount = held
                    entry.lastUpdatedAt = GetTimeStamp()
                    changed = changed + 1
                end

                -- Adopting a place changes the key the offer is filed under, so the move
                -- is queued here and made once the table is no longer being walked.
                local wanted = GetAlwaysShareKey(link, entry.locationKey)
                if key ~= wanted then
                    rekeys[#rekeys + 1] = { from = key, to = wanted, entry = entry }
                end
            end
        end
    end

    for _, move in ipairs(rekeys) do
        if alwaysShare[move.from] == move.entry then
            alwaysShare[move.from] = nil
        end
        if alwaysShare[move.to] == nil then
            alwaysShare[move.to] = move.entry
            changed = changed + 1
        end
    end

    return changed
end

SyncSharedItemsWithInventory = function(quiet)
    local sharedItems = ItemShare.savedVars.sharedItems
    local inventoryIndex = BuildActualInventoryIndex()
    local removedCount, updatedCount, unchangedCount = 0, 0, 0

    local snapshot = {}
    for itemKey, entry in pairs(sharedItems) do
        snapshot[itemKey] = entry
    end

    for itemKey, entry in pairs(snapshot) do
        local itemName = tostring(entry.itemName or "Unknown Item")
        local actualByEntry = inventoryIndex.countsByEntryKey[itemKey]
        local actualCount = actualByEntry and (tonumber(actualByEntry.count or 0) or 0) or 0
        local currentLocation = actualByEntry and tostring(actualByEntry.sharedFrom or entry.sharedFrom or "-") or tostring(entry.sharedFrom or "-")
        local currentLocationKey = actualByEntry and tostring(actualByEntry.locationKey or entry.locationKey or "") or tostring(entry.locationKey or "")
        local currentItemKey = itemKey

        -- A piece filed by /ishare scan stands in a house rather than in a bag, so
        -- the bags must not claim it back: the scan of that house is its only record.
        if actualCount == 0 and not IsPlacedLocationKey(entry.locationKey) then
            local alternateMatch = FindAlternateSharedEntryMatch(entry, inventoryIndex)
            if alternateMatch then
                actualCount = tonumber(alternateMatch.count or 0) or 0
                currentLocation = tostring(alternateMatch.sharedFrom or currentLocation or "-")
                currentLocationKey = tostring(alternateMatch.locationKey or currentLocationKey or "")
                currentItemKey = tostring(alternateMatch.itemKey or currentItemKey or itemKey)
            end
        end

        local entryLocationKey = tostring(entry.locationKey or BuildLocationKeyFromSharedFrom(entry.sharedFrom) or "")
        local canVerify = inventoryIndex.observableLocationKeys[entryLocationKey] == true

        if actualCount <= 0 then
            if not canVerify then
                -- That bag could not be read this session, so "not found" proves
                -- nothing about the item. Keep the share rather than delete blind.
                unchangedCount = unchangedCount + 1
            else
                sharedItems[itemKey] = nil
                removedCount = removedCount + 1
                if not quiet then
                    PrintMessage(string.format("Removed missing shared item: %s [%s]", itemName, tostring(entry.sharedFrom or "-")))
                end
            end
        else
            local previousCount = GetEntryOfferedCount(entry)
            local previousLocation = tostring(entry.sharedFrom or "")
            local previousItemKey = itemKey
            local previousLocationKey = tostring(entry.locationKey or "")
            local targetItemKey = tostring(currentItemKey or itemKey)

            entry.heldCount = actualCount
            entry.sharedFrom = currentLocation
            entry.locationKey = currentLocationKey
            entry.lastDumpedAt = GetTimeStamp()

            if targetItemKey ~= itemKey then
                sharedItems[itemKey] = nil
                sharedItems[targetItemKey] = entry
            else
                sharedItems[itemKey] = entry
            end

            if previousCount ~= GetEntryOfferedCount(entry)
                or previousLocation ~= currentLocation
                or previousItemKey ~= targetItemKey
                or previousLocationKey ~= currentLocationKey then
                updatedCount = updatedCount + 1
                if not quiet then
                    PrintMessage(string.format("Updated shared item: %s (%d) - %s", itemName, GetEntryOfferedCount(entry), currentLocation))
                end
            else
                unchangedCount = unchangedCount + 1
            end
        end
    end

    RefreshAlwaysShareHeldCounts(inventoryIndex)
    ShowSyncSummary("Sync", updatedCount, removedCount, unchangedCount, quiet)
    RefreshShareListWindowIfVisible()
end

RebuildSharedItemsWithInventory = function(quiet)
    local sharedItems = ItemShare.savedVars.sharedItems
    local inventoryIndex = BuildActualInventoryIndex()
    -- Dropped here as well as at login: whatever wrote the file, a row from the
    -- removed placed-furniture idea must not be carried forward into the next save.
    local removedCount, updatedCount, unchangedCount = PruneLegacyPlacedFurnitureShares(), 0, 0

    local snapshot = {}
    for itemKey, entry in pairs(sharedItems) do
        snapshot[itemKey] = entry
    end

    for itemKey, entry in pairs(snapshot) do
        local itemName = tostring(entry.itemName or "Unknown Item")
        local actualByEntry = inventoryIndex.countsByEntryKey[itemKey]
        local actualCount = actualByEntry and (tonumber(actualByEntry.count or 0) or 0) or 0
        local currentLocation = actualByEntry and tostring(actualByEntry.sharedFrom or entry.sharedFrom or "-") or tostring(entry.sharedFrom or "-")
        local currentLocationKey = actualByEntry and tostring(actualByEntry.locationKey or entry.locationKey or "") or tostring(entry.locationKey or "")
        local currentItemKey = itemKey
        local currentItemData = actualByEntry and actualByEntry.itemData or nil

        -- A piece filed by /ishare scan stands in a house rather than in a bag, so
        -- the bags must not claim it back: the scan of that house is its only record.
        if actualCount == 0 and not IsPlacedLocationKey(entry.locationKey) then
            local alternateMatch = FindAlternateSharedEntryMatch(entry, inventoryIndex)
            if alternateMatch then
                actualCount = tonumber(alternateMatch.count or 0) or 0
                currentLocation = tostring(alternateMatch.sharedFrom or currentLocation or "-")
                currentLocationKey = tostring(alternateMatch.locationKey or currentLocationKey or "")
                currentItemKey = tostring(alternateMatch.itemKey or currentItemKey or itemKey)
                currentItemData = alternateMatch.itemData or currentItemData
            end
        end

        local entryLocationKey = tostring(entry.locationKey or BuildLocationKeyFromSharedFrom(entry.sharedFrom) or "")
        local canVerify = inventoryIndex.observableLocationKeys[entryLocationKey] == true

        if actualCount <= 0 then
            if not canVerify then
                -- Unreadable bag: keep the share until a session can see it.
                unchangedCount = unchangedCount + 1
            else
                sharedItems[itemKey] = nil
                removedCount = removedCount + 1
                if not quiet then
                    PrintMessage(string.format("Removed missing shared item during rebuild: %s [%s]", itemName, tostring(entry.sharedFrom or "-")))
                end
            end
        else
            local previousCount = GetEntryOfferedCount(entry)
            local previousLocation = tostring(entry.sharedFrom or "")
            local previousItemKey = itemKey
            local previousLocationKey = tostring(entry.locationKey or "")
            local previousApparelSlot = tostring(entry.apparelSlot or "")
            local previousApparelWeight = tostring(entry.apparelWeight or "")
            local previousWeaponType = tostring(entry.weaponType or "")
            local targetItemKey = tostring(currentItemKey or itemKey)

            local rebuiltEntry = nil
            if currentItemData then
                rebuiltEntry = SaveSharedEntry(currentItemData, actualCount, entry.firstDumpedAt or GetTimeStamp(), false)
            end

            if rebuiltEntry then
                rebuiltEntry.sharedFrom = currentLocation
                rebuiltEntry.locationKey = currentLocationKey
                rebuiltEntry.lastDumpedAt = GetTimeStamp()
                sharedItems[targetItemKey] = rebuiltEntry
                if targetItemKey ~= itemKey then
                    sharedItems[itemKey] = nil
                end
                entry = rebuiltEntry
            else
                entry.heldCount = actualCount
                entry.sharedFrom = currentLocation
                entry.locationKey = currentLocationKey
                entry.lastDumpedAt = GetTimeStamp()
                if targetItemKey ~= itemKey then
                    sharedItems[itemKey] = nil
                    sharedItems[targetItemKey] = entry
                else
                    sharedItems[itemKey] = entry
                end
            end

            if previousCount ~= GetEntryOfferedCount(entry)
                or previousLocation ~= tostring(entry.sharedFrom or "")
                or previousItemKey ~= targetItemKey
                or previousLocationKey ~= tostring(entry.locationKey or "")
                or previousApparelSlot ~= tostring(entry.apparelSlot or "")
                or previousApparelWeight ~= tostring(entry.apparelWeight or "")
                or previousWeaponType ~= tostring(entry.weaponType or "") then
                updatedCount = updatedCount + 1
                if not quiet then
                    PrintMessage(string.format("Rebuilt shared item: %s (%d) - %s", itemName, GetEntryOfferedCount(entry), tostring(entry.sharedFrom or "-")))
                end
            else
                unchangedCount = unchangedCount + 1
            end
        end
    end

    RefreshAlwaysShareHeldCounts(inventoryIndex)
    ShowSyncSummary("Rebuild", updatedCount, removedCount, unchangedCount, quiet)
    RefreshShareListWindowIfVisible()
end

-- The saved file is meant to be a snapshot of what the account owns right now, so
-- the addon refreshes it without being asked: once when a character loads, and
-- again when a bank opens or closes. Every entry it can see is rewritten from live
-- data (item id, icon, guild ids, set, enchant, style, level, CP, flavour text),
-- and entries whose location was readable but no longer holds the item are
-- dropped. Locations that could not be read are left alone.
-- Nothing to refresh means nothing to scan: a player with no shares and no standing
-- offers should not pay for a rebuild every time they pick something up.
local function HasEntriesToRefresh()
    local savedVars = ItemShare.savedVars
    if not savedVars then
        return false
    end

    return next(savedVars.alwaysShare or {}) ~= nil or next(savedVars.sharedItems or {}) ~= nil
end

-- A slot change is worth a pass only when it happened in a bag this addon counts and
-- there is a table that could have gone stale.
local function ShouldReconcileForInventoryChange(bagId)
    return IsTrackedBagId(bagId) and HasEntriesToRefresh()
end

local autoReconcilePending = false

local function ScheduleAutoReconcile(reason)
    if autoReconcilePending or not ItemShare.savedVars or not zo_callLater then
        return
    end

    autoReconcilePending = true
    zo_callLater(function()
        autoReconcilePending = false
        if not ItemShare.savedVars then
            return
        end

        RefreshGuildSnapshot()
        RebuildSharedItemsWithInventory(true)
        -- This pass runs on login, on every bank visit and after most bag changes, so the
        -- line was noise. Kept, commented out, for whenever it is wanted again.
        -- PrintMessage(string.format("Shared items refreshed after %s.", tostring(reason or "login")))
    end, 4000)
end

local function SharedEntriesMatching(searchText)
    local needle = string.lower(zo_strtrim(tostring(searchText or "")))
    local matches = {}

    if needle == "" then
        return matches
    end

    for _, entry in pairs(ItemShare.savedVars.sharedItems or {}) do
        if string.find(string.lower(tostring(entry.itemName or "")), needle, 1, true) then
            matches[#matches + 1] = entry
        end
    end

    return matches
end

local function SetShareReserveByName(searchText, amount)
    local matches = SharedEntriesMatching(searchText)

    if #matches == 0 then
        PrintMessage(string.format("No shared item matches \"%s\".", tostring(searchText)))
        return
    end
    if #matches > 1 then
        -- The same item in two bags is two matches, and more of the name cannot choose
        -- between them now that a reserve is answered per place: the place has to come
        -- from the bag the reserve is meant for.
        local firstLink = tostring(matches[1] and matches[1].itemLink or "")
        local sameItem = firstLink ~= ""
        local places = {}

        for _, match in ipairs(matches) do
            if tostring(match and match.itemLink or "") ~= firstLink then
                sameItem = false
            end
            local label = tostring(match and match.sharedFrom or "")
            if label ~= "" then
                places[label] = true
            end
        end

        if sameItem then
            PrintMessage(string.format(
                "%s is shared from more than one place (%s); set its reserve from the item's right-click menu in the bag you mean.",
                tostring(matches[1].itemName or "that item"),
                JoinSortedLocations(places)
            ))
            return
        end

        PrintMessage(string.format(
            "%d shared items match \"%s\"; use more of the name.",
            #matches,
            tostring(searchText)
        ))
        return
    end

    local entry = matches[1]
    local locationKey = tostring(entry.locationKey or "")
    SetShareReserve(entry.itemLink, amount, locationKey)

    -- The count comes from what the file already recorded, so it is right even when
    -- the bag holding the item is not readable this session. The next rebuild
    -- corrects it from live inventory data.
    local held = GetEntryHeldCount(entry)
    local reserve = GetShareReserve(entry.itemLink, locationKey)
    local offered = ShareableCount(entry.itemLink, held, locationKey)
    entry.heldCount = held

    TryRefreshInventoryVisuals()
    RefreshShareListWindowIfVisible()

    if reserve > 0 then
        PrintMessage(string.format(
            "%s: keeping %d back, sharing %d of %d held.",
            tostring(entry.itemName or "that item"),
            reserve,
            offered,
            held
        ))
    else
        PrintMessage(string.format(
            "%s: sharing everything held (%d).",
            tostring(entry.itemName or "that item"),
            offered
        ))
    end
end

-- Sets the reserve for one item and keeps every place that records it in step: the
-- share entry and the count it implies, the standing offer, the bag badges and the
-- share list. Everything that changes a reserve comes through here, so a number typed
-- into the box and a number typed after the slash command cannot disagree.
ApplyShareReserve = function(itemLink, amount, locationKey)
    local link = tostring(itemLink or "")
    if link == "" then
        return nil
    end

    local keep = math.max(0, math.floor(tonumber(amount) or 0))
    local placeKey = tostring(locationKey or "")
    SetShareReserve(link, keep, placeKey)

    local updated = nil
    for _, entry in pairs(ItemShare.savedVars.sharedItems or {}) do
        if tostring(entry.itemLink or "") == link
            and (placeKey == "" or tostring(entry.locationKey or "") == placeKey) then
            entry.heldCount = GetEntryHeldCount(entry)
            updated = entry
        end
    end

    local alwaysShare = ItemShare.savedVars.alwaysShare
    if type(alwaysShare) == "table" then
        for _, entry in pairs(alwaysShare) do
            if type(entry) == "table" and tostring(entry.itemLink or "") == link
                and (placeKey == "" or tostring(entry.locationKey or "") == placeKey) then
                updated = updated or entry
            end
        end
    end

    TryRefreshInventoryVisuals()
    RefreshShareListWindowIfVisible()
    return updated
end

-- The reserve prompt. A reserve is a number the player has in mind rather than one of
-- a few fixed choices, so this is a number box with the item already chosen and a
-- clear button that appears only when there is something to clear. Anything that is
-- not a whole number of at least one is refused: zero is "no reserve" and has its own
-- button.
local reserveDialog = nil

local function CloseReserveDialog()
    if reserveDialog and reserveDialog.window then
        reserveDialog.window:SetHidden(true)
    end
end

local function BuildReserveDialog()
    if reserveDialog then
        return reserveDialog.broken and nil or reserveDialog
    end

    local wm = WINDOW_MANAGER
    local window = wm:CreateTopLevelWindow("ItemShareReserveWindow")
    -- Remembered before anything below can throw, so a half-built window is never
    -- created a second time under the same name.
    reserveDialog = { window = window }
    window:SetDimensions(380, 236)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetMouseEnabled(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetHidden(true)

    local backdrop = wm:CreateControl(nil, window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    backdrop:SetCenterColor(0.05, 0.05, 0.05, 0.97)
    backdrop:SetEdgeColor(0.7, 0.7, 0.7, 1)
    backdrop:SetEdgeTexture(nil, 1, 1, 2, 0)

    local title = wm:CreateControl(nil, window, CT_LABEL)
    title:SetFont("ZoFontWinH2")
    title:SetColor(1, 1, 1, 1)
    title:SetText("Share Reserve")
    title:SetAnchor(TOPLEFT, window, TOPLEFT, 16, 12)

    local closeButton = wm:CreateControl(nil, window, CT_BUTTON)
    closeButton:SetDimensions(28, 28)
    closeButton:SetAnchor(TOPRIGHT, window, TOPRIGHT, -6, 6)
    closeButton:SetNormalTexture("/esoui/art/buttons/decline_up.dds")
    closeButton:SetPressedTexture("/esoui/art/buttons/decline_down.dds")
    closeButton:SetMouseOverTexture("/esoui/art/buttons/decline_over.dds")
    closeButton:SetHandler("OnClicked", CloseReserveDialog)

    local itemLabel = wm:CreateControl(nil, window, CT_LABEL)
    itemLabel:SetFont("ZoFontGame")
    itemLabel:SetColor(1, 1, 1, 1)
    itemLabel:SetAnchor(TOPLEFT, window, TOPLEFT, 16, 42)
    itemLabel:SetAnchor(TOPRIGHT, window, TOPRIGHT, -16, 42)
    itemLabel:SetHeight(20)
    itemLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    if itemLabel.SetMaxLineCount then
        itemLabel:SetMaxLineCount(1)
    end

    local prompt = wm:CreateControl(nil, window, CT_LABEL)
    prompt:SetFont("ZoFontGameSmall")
    prompt:SetColor(0.85, 0.85, 0.85, 1)
    prompt:SetText("Keep how many back? They are not offered while you hold this many or fewer.")
    prompt:SetAnchor(TOPLEFT, window, TOPLEFT, 16, 64)
    prompt:SetAnchor(TOPRIGHT, window, TOPRIGHT, -16, 64)
    prompt:SetHeight(34)
    prompt:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    local editBox = nil
    if wm.CreateControlFromVirtual then
        local built, control = pcall(function()
            return wm:CreateControlFromVirtual("ItemShareReserveEdit", window, "ZO_DefaultEditForBackdrop")
        end)
        if built then
            editBox = control
        end
    end

    if not editBox then
        -- No number box means nothing to type an answer into: leave the slash command
        -- as the way in rather than opening a window that cannot work.
        reserveDialog = { window = window, broken = true }
        window:SetHidden(true)
        return nil
    end

    -- A frame drawn here rather than by the template: the template gives an edit box
    -- the client's own background only when it is set up as a backdrop control, so on
    -- its own it looked like a gap in the dialog.
    local editFrame = wm:CreateControl(nil, window, CT_BACKDROP)
    editFrame:SetDimensions(96, 30)
    editFrame:SetAnchor(TOP, window, TOP, 0, 104)
    editFrame:SetCenterColor(0, 0, 0, 0.7)
    editFrame:SetEdgeColor(0.7, 0.7, 0.7, 1)
    editFrame:SetEdgeTexture(nil, 1, 1, 1, 0)

    editBox:SetDimensions(80, 24)
    editBox:SetAnchor(TOP, editFrame, TOP, 0, 3)
    editBox:SetColor(1, 1, 1, 1)
    if editBox.SetMaxChars then
        editBox:SetMaxChars(6)
    end

    local status = wm:CreateControl(nil, window, CT_LABEL)
    status:SetFont("ZoFontGameSmall")
    status:SetColor(0.85, 0.85, 0.85, 1)
    status:SetAnchor(TOPLEFT, window, TOPLEFT, 16, 144)
    status:SetAnchor(TOPRIGHT, window, TOPRIGHT, -16, 144)
    status:SetHeight(20)
    status:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- Two buttons on one row inside the frame. The close button and Escape are the way
    -- out, so a third Cancel beside them only crowded the row; offsets are negative
    -- because a positive BOTTOM offset moves a control down, out of the window.
    local keepButton = wm:CreateControl(nil, window, CT_BUTTON)
    keepButton:SetDimensions(140, 32)
    keepButton:SetAnchor(BOTTOM, window, BOTTOM, -78, -16)
    keepButton:SetFont("ZoFontGame")
    keepButton:SetText("Keep This Many")
    keepButton:SetClickSound(SOUNDS.DIALOG_ACCEPT)

    local clearButton = wm:CreateControl(nil, window, CT_BUTTON)
    clearButton:SetDimensions(120, 32)
    clearButton:SetAnchor(BOTTOM, window, BOTTOM, 78, -16)
    clearButton:SetFont("ZoFontGame")
    clearButton:SetText("Clear Reserve")
    clearButton:SetClickSound(SOUNDS.DIALOG_DECLINE)

    keepButton:SetHandler("OnClicked", function()
        local pending = reserveDialog and reserveDialog.pending
        if not pending then
            return
        end

        local typed = zo_strtrim(tostring(editBox:GetText() or ""))
        local amount = tonumber(typed)

        if not amount or amount < 1 or amount ~= math.floor(amount) then
            status:SetColor(1, 0.45, 0.45, 1)
            status:SetText("Enter a whole number of 1 or more.")
            editBox:TakeFocus()
            return
        end

        local entry = ApplyShareReserve(pending.itemLink, amount, pending.locationKey)
        local held = GetEntryHeldCount(entry)
        local offered = GetEntryOfferedCount(entry)

        if held > 0 then
            PrintMessage(string.format(
                "%s: keeping %d back, so %d of %d held are shared.",
                tostring(pending.itemName),
                amount,
                offered,
                held
            ))
        else
            PrintMessage(string.format(
                "%s: keeping %d back. Nothing is offered until you hold more.",
                tostring(pending.itemName),
                amount
            ))
        end

        window:SetHidden(true)
    end)

    clearButton:SetHandler("OnClicked", function()
        local pending = reserveDialog and reserveDialog.pending
        if not pending then
            return
        end

        local entry = ApplyShareReserve(pending.itemLink, 0, pending.locationKey)
        local held = GetEntryHeldCount(entry)
        PrintMessage(string.format(
            "%s: reserve cleared, so everything held is shared (%d).",
            tostring(pending.itemName),
            held
        ))
        window:SetHidden(true)
    end)

    window:SetHandler("OnKeyUp", function(_, key)
        if KEY_ESCAPE and key == KEY_ESCAPE then
            CloseReserveDialog()
        end
    end)

    reserveDialog.itemLabel = itemLabel
    reserveDialog.editBox = editBox
    reserveDialog.status = status
    reserveDialog.clearButton = clearButton
    return reserveDialog
end

OpenShareReserveDialog = function(bagId, slotIndex)
    local itemLink = GetNormalizedItemLink(bagId, slotIndex)
    local itemName = GetNormalizedItemName(bagId, slotIndex) or itemLink

    if not itemLink then
        return
    end

    local dialog = BuildReserveDialog()

    if not dialog then
        PrintMessage(string.format(
            "The reserve box is unavailable in this client. Use /itemshare reserve <amount> %s.",
            tostring(itemName)
        ))
        return
    end

    local locationKey = select(1, GetBagLocationInfo(bagId))
    local reserve = GetShareReserve(itemLink, locationKey)
    dialog.pending = { itemLink = itemLink, itemName = itemName, locationKey = locationKey }
    dialog.itemLabel:SetText(tostring(itemName))
    dialog.editBox:SetText(reserve > 0 and tostring(reserve) or "")
    dialog.clearButton:SetHidden(reserve <= 0)
    dialog.status:SetColor(0.85, 0.85, 0.85, 1)
    dialog.status:SetText(
        reserve > 0 and string.format("Keeping %d back here.", reserve) or "Nothing is kept back here yet."
    )
    dialog.window:SetHidden(false)
    dialog.editBox:TakeFocus()
end

local function PrintShareReserves()
    local rows = {}
    local listed = {}

    local function AddEntryRow(entry)
        if type(entry) ~= "table" then
            return
        end

        local link = tostring(entry.itemLink or "")
        local locationKey = tostring(entry.locationKey or "")
        local placeKey = BuildSharedItemKey(link, locationKey)
        if link ~= "" and not listed[placeKey] and GetShareReserve(link, locationKey) > 0 then
            listed[placeKey] = true
            listed[link] = true
            rows[#rows + 1] = {
                entry = entry,
                link = link,
                locationKey = locationKey,
                place = tostring(entry.sharedFrom or ""),
            }
        end
    end

    for _, entry in pairs(ItemShare.savedVars.sharedItems or {}) do
        AddEntryRow(entry)
    end
    for _, entry in pairs(GetAlwaysShareTable()) do
        AddEntryRow(entry)
    end

    -- The reserve tables are the authority, because a reserve can be set on an item
    -- that is not shared at all, and now on one place of it. Reading only the shares
    -- left those out of this list as well as out of the window.
    local index = (BuildActualInventoryIndex and BuildActualInventoryIndex()) or nil

    local function NameFromIndex(link, locationKey)
        local place = locationKey ~= "" and index and index.countsByEntryKey
            and index.countsByEntryKey[BuildSharedItemKey(link, locationKey)]
        local itemData = place and place.itemData
        if not itemData and index and index.locationsByLink then
            local location = index.locationsByLink[link]
            itemData = location and location.itemData
        end
        return tostring(itemData and itemData.itemName or ""), tostring(place and place.sharedFrom or "")
    end

    local locationReserves = ItemShare.savedVars.locationReserves
    if type(locationReserves) == "table" then
        for placeKey, amount in pairs(locationReserves) do
            local link, locationKey = string.match(tostring(placeKey or ""), "^(.*)||([^|]*)$")
            local keep = math.max(0, math.floor(tonumber(amount or 0) or 0))
            link = tostring(link or "")
            locationKey = tostring(locationKey or "")
            if link ~= "" and keep > 0 and not listed[link .. "||" .. locationKey] then
                listed[link .. "||" .. locationKey] = true
                local name, place = NameFromIndex(link, locationKey)
                rows[#rows + 1] = {
                    link = link,
                    locationKey = locationKey,
                    reserveOnly = true,
                    name = name,
                    place = place,
                }
            end
        end
    end

    for link, amount in pairs(GetShareReserveTable()) do
        local linkText = tostring(link or "")
        local keep = math.max(0, math.floor(tonumber(amount or 0) or 0))
        if keep > 0 and linkText ~= "" and not listed[linkText] then
            listed[linkText] = true
            local name = NameFromIndex(linkText, "")
            rows[#rows + 1] = {
                link = linkText,
                locationKey = "",
                reserveOnly = true,
                name = name,
                place = "",
            }
        end
    end

    if #rows == 0 then
        PrintMessage("No item has a share reserve. Set one with /itemshare reserve <amount> <part of the name>.")
        return
    end

    local function NameOf(row)
        if row.entry then
            return tostring(row.entry.itemName or "Unknown Item")
        end
        if row.name ~= "" then
            return row.name
        end
        return string.format("item %s", tostring(string.match(row.link, "item:(%d+)") or row.link))
    end

    local function PlaceOf(row)
        local place = tostring(row.place or "")
        if place ~= "" then
            return place
        end
        local locationKey = tostring(row.locationKey or "")
        if locationKey ~= "" then
            return locationKey
        end
        return "any place"
    end

    table.sort(rows, function(a, b)
        local aName = string.lower(NameOf(a))
        local bName = string.lower(NameOf(b))
        if aName ~= bName then
            return aName < bName
        end
        return PlaceOf(a) < PlaceOf(b)
    end)

    PrintMessage(string.format("Share reserves (%d):", #rows))
    for _, row in ipairs(rows) do
        if row.entry then
            PrintMessage(string.format(
                "  %s [%s]: keep %d, sharing %d of %d held",
                NameOf(row),
                PlaceOf(row),
                GetShareReserve(row.link, row.locationKey),
                ShareableCount(row.link, GetEntryHeldCount(row.entry), row.locationKey),
                GetEntryHeldCount(row.entry)
            ))
        else
            PrintMessage(string.format(
                "  %s [%s]: keep %d, not shared",
                NameOf(row),
                PlaceOf(row),
                GetShareReserve(row.link, row.locationKey)
            ))
        end
    end
    PrintMessage("Clear one with /itemshare noreserve <part of the name>, or from the item's right-click menu.")
end

-- /itemshare expire <days> is a statement about the list, not about one item, so it
-- is kept in the saved variables and read when a badge is painted. That is what makes
-- it apply by itself after a reload, and on the next inventory, bank or storage view.
local function SetShareExpireDays(rawArg)
    local value = zo_strtrim(tostring(rawArg or ""):match("^%s*[Ee]xpire%s*(.*)$") or "")
    local days = tonumber(value)
    local current = GetExpireDays()
    local expired, total = CountSharesAboveExpireLimit()

    if value == "" then
        if current > 0 then
            PrintMessage(string.format(
                "Shares older than %d days show the stopwatch: %d of %d are past it.",
                current,
                expired,
                total
            ))
        else
            PrintMessage("No expire limit is set, so no share shows the stopwatch.")
        end
        PrintMessage("Use /itemshare expire <days> to mark shares older than that many days, or /itemshare expire 0 to stop marking them.")
        return
    end

    if not days or days < 0 or days ~= math.floor(days) then
        PrintMessage("Usage: /itemshare expire <days>   (0 turns the stopwatch off)")
        return
    end

    ItemShare.savedVars.expireDays = days
    TryRefreshInventoryVisuals()
    RefreshShareListWindowIfVisible()

    if days <= 0 then
        PrintMessage("Expire limit cleared: no share shows the stopwatch.")
    else
        PrintMessage(string.format(
            "Shares older than %d days now show the stopwatch: %d of %d are past it.",
            days,
            expired,
            total
        ))
    end
end

-- One list, printed from one place. The bare command and the unknown-command fallback
-- each carried their own copy of it, which is how a command that works - guildbank - ends
-- up missing from the help, and how a line that made no sense survived in both copies.
local function PrintCommandHelp()
    PrintMessage("Commands:")
    PrintMessage("/itemshare list      - Open the shared items window")
    PrintMessage("/itemshare reset     - Clear all shared entries")
    PrintMessage("/itemshare sync      - Recount and drop shares you no longer own, in bags that are readable now")
    PrintMessage("/itemshare rebuild   - Rewrite every shared item from your current bags (also runs on login and when a bank opens)")
    PrintMessage("/itemshare save      - Reload the UI")
    PrintMessage("/itemshare guilds    - Show the guilds this character's shares are matched against")
    PrintMessage("/itemshare always    - List the items you always offer, in or out of your bags")
    PrintMessage("/itemshare noalways  - Stop always sharing one: /itemshare noalways <part of the name>")
    PrintMessage("/itemshare reserve N <name> - Share only what you hold above N of that item")
    PrintMessage("/itemshare noreserve <name> - Share everything you hold of that item again")
    PrintMessage("/itemshare reserves  - List the items you keep a reserve on")
    PrintMessage("/itemshare expire N  - Show a stopwatch on shares older than N days (0 turns it off)")
    PrintMessage("/itemshare server    - Show the platform and megaserver this file is recorded for")
    PrintMessage("/itemshare guildbank - Turn sharing from the guild bank on or off")
    PrintMessage("/itemshare scan      - Share every unbound furnishing placed in the house you own and are standing in")
    PrintMessage("/itemshare scan clear - Clear every share filed as Placed (<house>) for the house you are standing in")
    PrintMessage("/itemshare protect   - Turn the lock on a shared copy on or off: mailing and trading still work")
    PrintMessage("Right-click an item - Add to Share, Always Share This Item, Share Reserve")
end

local function OnSlashCommand(arg)
    if not ItemShare.savedVars then
        PrintMessage("The addon has not finished loading, so there is nothing to run yet. If this never changes, check the addon folder is named ItemShare.")
        return
    end

    local rawArg = zo_strtrim(arg or "")
    local lowerArg = zo_strlower(rawArg)

    if lowerArg == "" then
        PrintCommandHelp()
    elseif lowerArg == "list" then
        local window = ItemShare.ui and ItemShare.ui.listWindow
        if window and not window:IsHidden() then
            window:SetHidden(true)
            SaveListWindowState()
        else
            PrintSharedItems()
        end
    elseif lowerArg == "clear" or lowerArg == "reset" then
        ResetSharedItems()
    elseif lowerArg == "sync" or lowerArg == "cleanup" or lowerArg == "reconcile" then
        SyncSharedItemsWithInventory()
    elseif string.match(lowerArg, "^scan%s+clear$") or string.match(lowerArg, "^scan%s+reset$") then
        ClearPlacedFurnishingsForCurrentHouse()
    elseif lowerArg == "scan" then
        ScanPlacedFurnishings()
    elseif lowerArg == "rebuild" then
        RebuildSharedItemsWithInventory()
    elseif lowerArg == "save" then
        RebuildSharedItemsWithInventory()
        ConfirmReloadUI()
    elseif lowerArg == "guilds" then
        local guilds = RefreshGuildSnapshot()
        if #guilds == 0 then
            PrintMessage("No guilds detected for this character yet. Try again once the guild list has loaded.")
        else
            PruneDepartedGuilds()
            RefreshShareListWindowIfVisible()

            local snapshots = GetCharacterGuildSnapshots()
            local snapshot = snapshots[GetCurrentCharacterName()]
            local slots = type(snapshot) == "table" and snapshot.guildIds or nil

            PrintMessage(string.format("Guild slots for %s:", GetCurrentCharacterName()))
            for slot = 1, MAX_GUILD_SLOTS do
                local guildId = type(slots) == "table" and (tonumber(slots[slot]) or 0) or 0
                if guildId > 0 then
                    local guildName = GetGuildNameById(guildId)
                    PrintMessage(string.format(
                        "  %d: %s (id: %d)",
                        slot,
                        guildName ~= "" and guildName or "Unknown guild",
                        guildId
                    ))
                else
                    PrintMessage(string.format("  %d: no guild", slot))
                end
            end
        end
    elseif lowerArg == "always" then
        PrintAlwaysShareItems()
    elseif string.match(lowerArg, "^noalways%s+") then
        RemoveAlwaysShareByName(zo_strtrim(rawArg:sub(9)))
    elseif lowerArg == "reserves" then
        PrintShareReserves()
    elseif string.match(lowerArg, "^noreserve%s+") then
        SetShareReserveByName(zo_strtrim(rawArg:sub(11)), 0)
    elseif string.match(lowerArg, "^reserve%s+") then
        local amount, needle = rawArg:match("^%s*[Rr]eserve%s+(%d+)%s+(.+)$")
        if not amount then
            PrintMessage("Usage: /itemshare reserve <amount to keep> <part of the item name>")
        else
            SetShareReserveByName(zo_strtrim(needle), tonumber(amount) or 0)
        end
    elseif lowerArg == "protect" then
        local wasEnabled = ItemShare.savedVars.shareProtection ~= false
        ItemShare.savedVars.shareProtection = not wasEnabled
        PrintMessage(string.format(
            "Share protection %s. %s",
            wasEnabled and "off" or "on",
            wasEnabled and "Shared copies are unlocked: they can be sold, deconstructed or used again." or "A copy shared from a place is locked: it can be mailed or traded, nothing else."
        ))
    elseif lowerArg == "expire" or string.match(lowerArg, "^expire%s") then
        SetShareExpireDays(rawArg)
    elseif lowerArg == "server" then
        PrintServerEnvironment()
    elseif lowerArg == "guildbank" then
        local current = ItemShare.savedVars.guildBankSharingEnabled == true
        ItemShare.savedVars.guildBankSharingEnabled = not current

        PrintMessage(string.format(
            "Guild bank sharing %s.",
            ItemShare.savedVars.guildBankSharingEnabled and "enabled" or "disabled"
        ))
        RefreshShareListWindowIfVisible()
    else
        PrintCommandHelp()
    end
end

-- ESO hands this event the addon's folder name, not the Title in the manifest. A copy
-- unzipped from GitHub arrives as "ItemShare-main", so an exact comparison loaded this
-- file, showed its version, and then returned before registering a single command,
-- event or message - which looks exactly like an addon that is running but mute.
local function IsItemShareAddonName(name)
    local lower = zo_strlower(tostring(name or ""))
    return lower == "itemshare" or string.sub(lower, 1, #"itemshare") == "itemshare"
end

local function OnAddonLoaded(event, addonName)
    if not IsItemShareAddonName(addonName) then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ItemShare.name, EVENT_ADD_ON_LOADED)

    -- Said first, before any setup that could go wrong, so a silent failure cannot be
    -- mistaken for a command that did not run.
    PrintMessage(string.format(
        "Loaded (version %s) from the folder '%s'. Shared items refresh from your bags on login and when you open the bank.",
        ADDON_VERSION,
        tostring(addonName)
    ))
    if tostring(addonName) ~= ItemShare.name then
        PrintMessage(string.format(
            "That folder name is not '%s'. Renaming it to '%s' is what the update instructions expect.",
            ItemShare.name,
            ItemShare.name
        ))
    end

    ItemShare.savedVars = ZO_SavedVars:NewAccountWide(
        "ItemShareSavedVars",
        SAVED_VARS_VERSION,
        GetWorldName(),
        defaults
    )

    -- A file written by another layout is not carried forward: this release starts its
    -- tables over rather than reading around an old shape. Shares come back from the
    -- bags on the rebuild that runs at login; standing offers and reserves are set by
    -- hand rather than read from a bag, so they start empty.
    if tonumber(ItemShare.savedVars.schema) ~= SAVED_VARS_VERSION then
        ItemShare.savedVars.sharedItems = {}
        ItemShare.savedVars.alwaysShare = {}
        ItemShare.savedVars.reserves = {}
        ItemShare.savedVars.locationReserves = {}
        ItemShare.savedVars.guilds = {}
        ItemShare.savedVars.characterGuilds = {}
        ItemShare.savedVars.schema = SAVED_VARS_VERSION
    end

    GetAlwaysShareTable()
    ReindexAlwaysShareTable()

    local legacyPlacedShares = PruneLegacyPlacedFurnitureShares()
    if legacyPlacedShares > 0 then
        PrintMessage(string.format(
            "Removed %d share%s that were filed as placed furniture. Run /ishare scan in your storage house to file them again.",
            legacyPlacedShares,
            legacyPlacedShares == 1 and "" or "s"
        ))
    end

    ItemShare.savedVars.addonVersion = ADDON_VERSION
    -- The platform and megaserver are read once per load, before anything is offered:
    -- every entry in the file belongs to them, and the site matches on them.
    CaptureServerEnvironment()

    RefreshGuildSnapshot()
    -- Guilds are often not loaded this early, so this is a head start only; the
    -- delayed refresh repeats it once they are.
    if zo_callLater then
        zo_callLater(function()
            RefreshGuildSnapshot()
            -- Only safe once the list has loaded, which PruneDepartedGuilds checks for
            -- itself: it removes nothing while the guild list is still empty.
            PruneDepartedGuilds()
        end, 3000)
    end

        EVENT_MANAGER:RegisterForEvent(ItemShare.name, EVENT_GUILD_SELF_LEFT_GUILD, function()
            -- The guild list is not always updated in the same frame as the event, so the
            -- snapshot is taken again shortly afterwards rather than immediately.
            if zo_callLater then
                zo_callLater(function()
                    RefreshGuildSnapshot()
                    PruneDepartedGuilds()
                end, 2000)
            end
        end)

        EVENT_MANAGER:RegisterForEvent(ItemShare.name, EVENT_PLAYER_ACTIVATED, function()
            ScheduleAutoReconcile("login")
        end)
        EVENT_MANAGER:RegisterForEvent(ItemShare.name, EVENT_OPEN_BANK, function()
            ScheduleAutoReconcile("the bank opening")
        end)
        EVENT_MANAGER:RegisterForEvent(ItemShare.name, EVENT_CLOSE_BANK, function()
            ScheduleAutoReconcile("the bank closing")
        end)

    -- A count goes stale the moment something leaves a bag, and selling, deconstructing,
    -- trading, mailing or destroying never opens the bank, so nothing used to notice and
    -- the number kept whatever the last sync or reload left behind. A slot update covers
    -- every one of those, and ScheduleAutoReconcile collapses a burst into one pass, so a
    -- loot run or a stack split costs a single rebuild rather than one per item.
        EVENT_MANAGER:RegisterForEvent(ItemShare.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bagId)
            if not ShouldReconcileForInventoryChange(bagId) then
                return
            end

            ScheduleAutoReconcile("a change in your bags")
        end)

    -- A completed trade can move a whole stack without a slot update for the copy that
    -- left, so the window closing is the second chance to notice it.
        EVENT_MANAGER:RegisterForEvent(ItemShare.name, EVENT_CLOSE_TRADE_WINDOW, function()
            if not HasEntriesToRefresh() then
                return
            end

            ScheduleAutoReconcile("a trade")
        end)

    RegisterContextMenus()
    InstallShareProtection()
    InstallHoveredShareSlotTracking()
    HookInventoryRowCallbacks()
    HookCraftingInventoryRows()
    HookInventorySlotBinding()
    if zo_callLater then
        zo_callLater(HookInventoryRowCallbacks, 500)
        zo_callLater(HookCraftingInventoryRows, 1000)
    end

    -- A crafting panel is built as its scene opens, so the pass is repeated once the
    -- scene has had a frame to create the inventory it holds.
    if SCENE_MANAGER and SCENE_MANAGER.RegisterCallback then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
            if zo_callLater then
                zo_callLater(HookCraftingInventoryRows, 100)
            else
                HookCraftingInventoryRows()
            end
        end)
    end

    if ItemShare.savedVars.listWindowState and ItemShare.savedVars.listWindowState.isOpen then
        PrintSharedItems()
    else
        CreateShareListWindow()
    end

end

-- An error anywhere in the setup above used to abort the handler with nothing to show for
-- it: no command, no event, no line in chat, and the addon still listed at its current
-- version. The handler is called through pcall so the message lands in chat instead.
local function OnAddonLoadedGuarded(event, addonName)
    local ok, err = pcall(OnAddonLoaded, event, addonName)
    if not ok then
        PrintMessage(string.format(
            "Setup stopped with an error, so most of the addon is not running: %s",
            tostring(err)
        ))
    end
end

EVENT_MANAGER:RegisterForEvent(ItemShare.name, EVENT_ADD_ON_LOADED, OnAddonLoadedGuarded)

-- Registered here rather than inside the load handler: the file only runs if the addon
-- is enabled, so the command exists as soon as the addon does, and a setup error later
-- in the handler can no longer leave the player with a slash command that does nothing.
SLASH_COMMANDS["/itemshare"] = OnSlashCommand
SLASH_COMMANDS["/ishare"] = OnSlashCommand
