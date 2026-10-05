--[[
Better Character Overview
Version 1.10.0
PS5 / Update 50 native-list architecture test.

This version registers two dedicated lists through GAMEPAD_INVENTORY:AddList:
  BCOCategory
  BCOItems

It does not replace ESO's categoryList, itemList, or craftBagList.

Commands:
  /bco
  /bcorescan
  /bcoclear
]]

BetterCharacterOverview = {}
local BCO = BetterCharacterOverview

BCO.name = "BetterCharacterOverview"
BCO.version = "1.10.0"
BCO.savedVarVersion = 2

BCO.CATEGORY_DESCRIPTOR = "bcoCategoryList"
BCO.ITEM_DESCRIPTOR = "bcoItemList"
BCO.NATIVE_CATEGORY_DESCRIPTOR = "categoryList"

BCO.defaults = {
    characters = {},
    shared = {
        bank = { items = {}, updated = 0 },
        storage = {},
        houses = {},
        guildListings = {},
        currencies = {
            bank = {},
            updated = 0,
        },
    },
    settings = {
        categoryIndex = 1,
    },
}

BCO.categories = {
    { key = "all", name = "ALL ITEMS" },
    { key = "currencies", name = "CURRENCIES" },
    { key = "supplies", name = "SUPPLIES" },
    { key = "slottable", name = "SLOTTABLE ITEMS" },
    { key = "furnishings", name = "FURNISHINGS" },
    { key = "companion", name = "COMPANION ITEMS" },
    { key = "quest", name = "QUEST ITEMS" },
    { key = "weapons", name = "WEAPONS" },
    { key = "apparel", name = "APPAREL" },
    { key = "materials", name = "MATERIALS" },
    { key = "misc", name = "MISCELLANEOUS" },
}

BCO.categoryIcons = {
    -- All Items is a BCO-only category, so it keeps ESO's general inventory bag icon.
    all = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds",
    currencies = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_currencies.dds",

    -- These paths match ESO's native gamepad Inventory category list.
    supplies = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds",
    materials = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_materials.dds",
    slottable = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quickslot.dds",
    furnishings = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuIcon_furnishings.dds",
    companion = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_companionItems.dds",
    quest = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quest.dds",
    weapons = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_weapons.dds",
    apparel = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_apparel.dds",

    -- Miscellaneous is a BCO category rather than a native root category,
    -- but ESO provides this matching inventory icon.
    misc = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_miscellaneous.dds",
}

BCO.active = false
BCO.installed = false
BCO.installAttempts = 0
BCO.bankOpen = false
BCO.activeBankBag = nil
BCO.scanPending = false
BCO.houseScanToken = 0
BCO.houseScanScheduled = false
BCO.tradingHouseOpen = false
BCO.listingScanScheduled = false
BCO.indexToken = 0
BCO.indexReady = false
BCO.indexDirty = true
BCO.indexBuilding = false
BCO.aggregatedItems = {}
BCO.filteredItems = {}
BCO.selectedCategoryKey = "all"
BCO.selectedCategoryName = "ALL ITEMS"
-- ESO's private gamepad inventory action modes currently use 1 for the
-- category/read-only state. Keeping BCO in that state prevents deferred native
-- updates from rebuilding Use/Equip actions while a BCO list is active.
BCO.READ_ONLY_ACTION_MODE = 1
BCO.secureHookState = {}
BCO.searchHookMethodName = nil
BCO.thirdTabEntry = nil
BCO.sceneWatcherInstalled = false
BCO.sceneInstallGeneration = 0
BCO.sceneResumeGeneration = 0
BCO.resumeBCOAfterSceneShow = false
BCO.sceneResumeScheduled = false
BCO.lastInstallStatus = "Waiting for Inventory to open"
BCO.refreshingHeader = false
BCO.headerRefreshGeneration = 0
BCO.tooltipRefreshGeneration = 0
BCO.currencyTooltipGeneration = 0
BCO.renderedItemTooltipKey = nil
BCO.indexRebuildGeneration = 0
BCO.searchText = ""
BCO.searchRefreshGeneration = 0
BCO.locationViewExpanded = false
BCO.expandedLocationItemKey = nil
BCO.previewingFurnishingItemLink = nil
BCO.previewingFurnishingItemKey = nil
BCO.previewingFurnishingBagId = nil
BCO.previewingFurnishingSlotIndex = nil
BCO.furnishingPreviewConfirmed = false
BCO.lastFurnishingPreviewPath = "none"
BCO.lastFurnishingPreviewError = nil
BCO.lastSelectedItemData = nil
BCO.firstItemEntryData = nil
BCO.itemSelectionGeneration = 0
BCO.previewSelectionGeneration = 0
BCO.furnishingPreviewSettleMS = 90
BCO.collapsedLocationRows = 2
BCO.collapsedLocationBodyRows = 3

-- Square cycles the source used by the read-only account inventory list.
-- Character Items includes both backpack and equipped locations.
-- Storage includes housing storage chests/coffers, the Furnishing Vault,
-- and furnishings placed in owned houses.
-- Listed shows the player's own guild store sell listings per guild.
BCO.inventoryFilters = {
    {
        key = "all",
        keybindName = "All",
    },
    {
        key = "bank",
        keybindName = "Banked",
    },
    {
        key = "backpack",
        keybindName = "Characters",
    },
    {
        key = "storage",
        keybindName = "Storage",
    },
    {
        key = "listings",
        keybindName = "Listed",
    },
}
BCO.inventoryFilterIndex = 1

-- ZO_SharedGamepadEntry_OnSetup only ipairs() this, so every BCO row can
-- share one empty table instead of allocating its own per list refresh.
local EMPTY_STATUS_INDICATOR_ICONS = {}

local function Msg(text)
    if d then
        d(string.format(
            "|c66CCFF[Better Character Overview]|r %s",
            tostring(text)
        ))
    end
end

local function Lower(text)
    text = tostring(text or "")
    return zo_strlower and zo_strlower(text) or string.lower(text)
end


local function Trim(text)
    text = tostring(text or "")
    return text:match("^%s*(.-)%s*$") or ""
end

-- ESO item-name APIs can return localization grammar markers such as ^p and
-- ^n. Native inventory screens resolve those markers through the tooltip item
-- name formatter before putting the text into a list entry.
local function FormatItemName(name)
    name = Trim(name)

    if name == "" then
        return "Unknown Item"
    end

    if zo_strformat then
        if SI_TOOLTIP_ITEM_NAME then
            local ok, formattedName = pcall(
                zo_strformat,
                SI_TOOLTIP_ITEM_NAME,
                name
            )

            if ok
                and type(formattedName) == "string"
                and formattedName ~= ""
            then
                return formattedName
            end
        end

        -- This also resolves grammar markers on older API builds where the
        -- tooltip formatter constant is not exposed at addon load time.
        local ok, formattedName = pcall(
            zo_strformat,
            "<<1>>",
            name
        )

        if ok
            and type(formattedName) == "string"
            and formattedName ~= ""
        then
            return formattedName
        end
    end

    return name
end

local function ReadControlText(control)
    if not control or type(control.GetText) ~= "function" then
        return nil
    end

    local ok, value = pcall(control.GetText, control)

    if not ok or type(value) ~= "string" then
        return nil
    end

    return Trim(value)
end

local function ControlName(control)
    if not control or type(control.GetName) ~= "function" then
        return ""
    end

    local ok, value = pcall(control.GetName, control)

    if not ok then
        return ""
    end

    return Lower(value)
end

local function SearchPlaceholder()
    if GetString and SI_GAMEPAD_SEARCH then
        local ok, value = pcall(
            GetString,
            SI_GAMEPAD_SEARCH
        )

        if ok and value then
            return Lower(Trim(value))
        end
    end

    return "search"
end

local function FindTextControl(root)
    if not root then
        return nil
    end

    local bestControl = nil
    local bestScore = -1
    local visited = {}

    local function Visit(control, depth)
        if not control
            or visited[control]
            or depth > 6
        then
            return
        end

        visited[control] = true

        local text = ReadControlText(control)
        local name = ControlName(control)
        local score = 0

        if type(control.GetType) == "function"
            and CT_EDITBOX
        then
            local ok, controlType = pcall(
                control.GetType,
                control
            )

            if ok and controlType == CT_EDITBOX then
                score = score + 200
            end
        end

        if name:find("search", 1, true)
            or name:find("edit", 1, true)
            or name:find("input", 1, true)
        then
            score = score + 75
        end

        if text ~= nil then
            score = score + 10

            if score > bestScore then
                bestScore = score
                bestControl = control
            end
        end

        if type(control.GetNumChildren) == "function"
            and type(control.GetChild) == "function"
        then
            local ok, childCount = pcall(
                control.GetNumChildren,
                control
            )

            if ok and type(childCount) == "number" then
                for childIndex = 1, childCount do
                    local childOk, child = pcall(
                        control.GetChild,
                        control,
                        childIndex
                    )

                    if childOk then
                        Visit(child, depth + 1)
                    end
                end
            end
        end
    end

    Visit(root, 0)
    return bestControl
end

local function Now()
    return GetTimeStamp and GetTimeStamp() or 0
end

local function CharacterId()
    return GetCurrentCharacterId and tostring(GetCurrentCharacterId()) or nil
end

local function CharacterName()
    local name = GetUnitName and GetUnitName("player") or "Unknown Character"
    return zo_strformat and zo_strformat("<<1>>", name) or name
end


-- Account-wide currencies are intentionally excluded. Better Character
-- Overview only aggregates currencies that can differ by character, plus
-- their banked amounts.
local CHARACTER_CURRENCY_DEFINITIONS = {
    {
        constantName = "CURT_MONEY",
        fallbackName = "GOLD",
    },
    {
        constantName = "CURT_ALLIANCE_POINTS",
        fallbackName = "ALLIANCE POINTS",
    },
    {
        constantName = "CURT_TELVAR_STONES",
        fallbackName = "TEL VAR STONES",
    },
    {
        constantName = "CURT_WRIT_VOUCHERS",
        fallbackName = "WRIT VOUCHERS",
    },
}

local function GetCharacterCurrencyDefinitions()
    local definitions = {}

    for index = 1, #CHARACTER_CURRENCY_DEFINITIONS do
        local source = CHARACTER_CURRENCY_DEFINITIONS[index]
        local currencyType = _G[source.constantName]

        if currencyType ~= nil then
            definitions[#definitions + 1] = {
                currencyType = currencyType,
                fallbackName = source.fallbackName,
            }
        end
    end

    return definitions
end

local function ReadCurrencyAmount(
    currencyType,
    currencyLocation
)
    if type(GetCurrencyAmount) ~= "function"
        or currencyType == nil
        or currencyLocation == nil
    then
        return nil
    end

    local ok, amount = pcall(
        GetCurrencyAmount,
        currencyType,
        currencyLocation
    )

    if ok and type(amount) == "number" then
        return amount
    end

    return nil
end

local function ReadBankCurrencyAmount(currencyType)
    local amount = ReadCurrencyAmount(
        currencyType,
        CURRENCY_LOCATION_BANK
    )

    if amount ~= nil then
        return amount
    end

    if type(GetBankedCurrencyAmount) == "function" then
        local ok, bankedAmount = pcall(
            GetBankedCurrencyAmount,
            currencyType
        )

        if ok and type(bankedAmount) == "number" then
            return bankedAmount
        end
    end

    if CURT_MONEY
        and currencyType == CURT_MONEY
        and type(GetBankedMoney) == "function"
    then
        local ok, bankedMoney = pcall(GetBankedMoney)

        if ok and type(bankedMoney) == "number" then
            return bankedMoney
        end
    end

    if CURT_TELVAR_STONES
        and currencyType == CURT_TELVAR_STONES
        and type(GetBankedTelvarStones) == "function"
    then
        local ok, bankedTelvar = pcall(
            GetBankedTelvarStones
        )

        if ok and type(bankedTelvar) == "number" then
            return bankedTelvar
        end
    end

    return 0
end

local function ScanCharacterCurrencies()
    local currencies = {}
    local definitions =
        GetCharacterCurrencyDefinitions()

    for index = 1, #definitions do
        local currencyType =
            definitions[index].currencyType
        local amount = ReadCurrencyAmount(
            currencyType,
            CURRENCY_LOCATION_CHARACTER
        )

        currencies[tostring(currencyType)] =
            amount or 0
    end

    return currencies
end

local function ScanBankCurrencies()
    local currencies = {}
    local definitions =
        GetCharacterCurrencyDefinitions()

    for index = 1, #definitions do
        local currencyType =
            definitions[index].currencyType

        currencies[tostring(currencyType)] =
            ReadBankCurrencyAmount(currencyType)
    end

    return currencies
end

local function SetName(itemLink)
    if not GetItemLinkSetInfo then
        return ""
    end

    local hasSet, name = GetItemLinkSetInfo(itemLink, false)
    return hasSet and (name or "") or ""
end

local function IterateBag(bagId, callback)
    if ZO_IterateBagSlots then
        for slotIndex in ZO_IterateBagSlots(bagId) do
            callback(slotIndex)
        end
        return
    end

    local size = GetBagSize and GetBagSize(bagId) or 0
    for slotIndex = 0, size - 1 do
        callback(slotIndex)
    end
end

local function PackFilterTypes(...)
    local packed = {}
    local count = select("#", ...)

    for index = 1, count do
        local value = select(index, ...)

        if value ~= nil
            and value ~= 0
            and not ZO_IsElementInNumericallyIndexedTable(
                packed,
                value
            )
        then
            packed[#packed + 1] = value
        end
    end

    return packed
end

local function GetFilterData(itemLink, bagId, slotIndex)
    if itemLink
        and itemLink ~= ""
        and GetItemLinkFilterTypeInfo
    then
        local filterData = PackFilterTypes(
            GetItemLinkFilterTypeInfo(itemLink)
        )

        if #filterData > 0 then
            return filterData
        end
    end

    if bagId ~= nil
        and slotIndex ~= nil
        and GetItemFilterTypeInfo
    then
        return PackFilterTypes(
            GetItemFilterTypeInfo(bagId, slotIndex)
        )
    end

    return {}
end

local function GetLinkDisplayQuality(
    itemLink,
    savedQuality
)
    if itemLink and itemLink ~= "" then
        if GetItemLinkDisplayQuality then
            local quality =
                GetItemLinkDisplayQuality(itemLink)

            if quality ~= nil then
                return quality
            end
        end

        if GetItemLinkQuality then
            local quality =
                GetItemLinkQuality(itemLink)

            if quality ~= nil then
                return quality
            end
        end
    end

    return savedQuality
        or ITEM_DISPLAY_QUALITY_NORMAL
end

-- Snapshots are deliberately minimal: an item link plus a stack count.
-- Everything shown in All Inventories (name, icon, quality, type, filter
-- data, set name) is derived from the link when the index is built, so the
-- SavedVariables file and the resident Lua tables stay small. Console
-- add-ons share a ~100 MB Lua budget; the previous 11-field snapshot was
-- roughly 1 KB per item and was parsed back in at every loading screen.
local function ReadItem(bagId, slotIndex)
    local count = GetSlotStackSize(bagId, slotIndex) or 0
    if count <= 0 then
        return nil
    end

    local itemLink = GetItemLink(
        bagId,
        slotIndex,
        LINK_STYLE_DEFAULT
    ) or ""

    if itemLink == "" then
        return nil
    end

    return {
        itemLink = itemLink,
        count = count,
    }
end

-- Rewrites a snapshot list from an older BCO version down to the minimal
-- schema in place. Runs once per list at load so the next SavedVariables
-- write shrinks the file. Entries without an item link cannot be resolved
-- and are dropped.
local function SlimSnapshotList(items)
    if type(items) ~= "table" then
        return {}
    end

    local write = 1

    for read = 1, #items do
        local snapshot = items[read]
        local itemLink = type(snapshot) == "table"
            and snapshot.itemLink
            or nil

        if type(itemLink) == "string" and itemLink ~= "" then
            local count = tonumber(snapshot.count) or 1

            -- Only allocate a replacement when the entry still carries the
            -- old derived fields; already-slim entries are kept as-is.
            if snapshot.name ~= nil
                or snapshot.itemId ~= nil
                or snapshot.filterData ~= nil
                or snapshot.count ~= count
            then
                snapshot = {
                    itemLink = itemLink,
                    count = count,
                }
            end

            items[write] = snapshot
            write = write + 1
        end
    end

    for index = write, #items do
        items[index] = nil
    end

    return items
end

local function ScanBag(bagId)
    local items = {}

    IterateBag(bagId, function(slotIndex)
        local item = ReadItem(bagId, slotIndex)
        if item then
            items[#items + 1] = item
        end
    end)

    return items
end

local function Append(target, source)
    for index = 1, #(source or {}) do
        target[#target + 1] = source[index]
    end
end


local HOUSE_BANK_CONSTANT_NAMES = {
    "BAG_HOUSE_BANK_ONE",
    "BAG_HOUSE_BANK_TWO",
    "BAG_HOUSE_BANK_THREE",
    "BAG_HOUSE_BANK_FOUR",
    "BAG_HOUSE_BANK_FIVE",
    "BAG_HOUSE_BANK_SIX",
    "BAG_HOUSE_BANK_SEVEN",
    "BAG_HOUSE_BANK_EIGHT",
    "BAG_HOUSE_BANK_NINE",
    "BAG_HOUSE_BANK_TEN",
}

local HOUSE_BANK_ORDINALS = {}

for index = 1, #HOUSE_BANK_CONSTANT_NAMES do
    local bagId = _G[HOUSE_BANK_CONSTANT_NAMES[index]]

    if bagId ~= nil then
        HOUSE_BANK_ORDINALS[bagId] = index
    end
end

local function IsFurnitureVaultBag(bagId)
    if bagId == nil then
        return false
    end

    if BAG_FURNITURE_VAULT
        and bagId == BAG_FURNITURE_VAULT
    then
        return true
    end

    if type(IsFurnitureVault) == "function" then
        local ok, result = pcall(
            IsFurnitureVault,
            bagId
        )

        if ok then
            return result == true
        end
    end

    return false
end

local function IsHousingStorageBag(bagId)
    if bagId == nil then
        return false
    end

    if IsFurnitureVaultBag(bagId) then
        return true
    end

    if type(IsHouseBankBag) == "function" then
        local ok, result = pcall(
            IsHouseBankBag,
            bagId
        )

        if ok and result == true then
            return true
        end
    end

    return HOUSE_BANK_ORDINALS[bagId] ~= nil
end

local function TryGetStorageCollectibleId(
    getCollectibleId,
    bagId
)
    if type(getCollectibleId) ~= "function" then
        return 0
    end

    local ok, collectibleId = pcall(
        getCollectibleId,
        bagId
    )

    if ok
        and collectibleId
        and collectibleId ~= 0
    then
        return collectibleId
    end

    return 0
end

local function GetStorageCollectibleId(bagId)
    local collectibleId =
        TryGetStorageCollectibleId(
            GetCollectibleForBag,
            bagId
        )

    if collectibleId ~= 0 then
        return collectibleId
    end

    return TryGetStorageCollectibleId(
        GetCollectibleForHouseBankBag,
        bagId
    )
end

local function FormatStorageName(name)
    name = Trim(name)

    if name == "" then
        return ""
    end

    if zo_strformat then
        return zo_strformat("<<1>>", name)
    end

    return name
end

local function GetStorageBagName(bagId)
    local collectibleId =
        GetStorageCollectibleId(bagId)

    if collectibleId ~= 0 then
        if type(GetCollectibleNickname) == "function" then
            local ok, nickname = pcall(
                GetCollectibleNickname,
                collectibleId
            )

            nickname = ok
                and FormatStorageName(nickname)
                or ""

            if nickname ~= "" then
                return nickname, collectibleId
            end
        end

        if type(GetCollectibleName) == "function" then
            local ok, collectibleName = pcall(
                GetCollectibleName,
                collectibleId
            )

            collectibleName = ok
                and FormatStorageName(collectibleName)
                or ""

            if collectibleName ~= "" then
                return collectibleName, collectibleId
            end
        end
    end

    if IsFurnitureVaultBag(bagId) then
        return "Furnishing Vault", collectibleId
    end

    local ordinal = HOUSE_BANK_ORDINALS[bagId]

    if ordinal then
        return string.format(
            "Housing Storage %d",
            ordinal
        ), collectibleId
    end

    return "Housing Storage", collectibleId
end

function BCO:ScanBank()
    local items = ScanBag(BAG_BANK)

    if BAG_SUBSCRIBER_BANK then
        Append(items, ScanBag(BAG_SUBSCRIBER_BANK))
    end

    self.savedVars.shared.bank = {
        items = items,
        updated = Now(),
    }
end

function BCO:ScanStorageBag(bagId)
    if not IsHousingStorageBag(bagId) then
        return false
    end

    local name, collectibleId =
        GetStorageBagName(bagId)
    local key = tostring(bagId)

    self.savedVars.shared.storage =
        self.savedVars.shared.storage or {}

    self.savedVars.shared.storage[key] = {
        bagId = bagId,
        name = name,
        collectibleId = collectibleId,
        isFurnitureVault =
            IsFurnitureVaultBag(bagId),
        items = ScanBag(bagId),
        updated = Now(),
    }

    return true
end

function BCO:ScanOpenBankLocation()
    if not self.bankOpen then
        return false
    end

    local bagId = self.activeBankBag

    if bagId == nil
        and type(GetBankingBag) == "function"
    then
        local ok, currentBagId = pcall(GetBankingBag)

        if ok then
            bagId = currentBagId
            self.activeBankBag = currentBagId
        end
    end

    if bagId == BAG_BANK then
        self:ScanBank()
        return "bank"
    elseif IsHousingStorageBag(bagId) then
        if self:ScanStorageBag(bagId) then
            return "storage:" .. tostring(bagId)
        end
    end

    return nil
end

-- Snapshot data changed. While All Inventories is on screen the aggregate
-- is rebuilt shortly afterwards so the open list stays current; otherwise
-- the rebuild waits until the next time All Inventories is opened.
function BCO:ScheduleIndexRebuild(delayMs, ...)
    local keyCount = select("#", ...)

    if keyCount == 0 then
        self:MarkIndexDirty()
    else
        for index = 1, keyCount do
            local key = select(index, ...)

            if key then
                self:MarkSourceDirty(key)
            end
        end
    end

    if not self.active then
        return
    end

    self.indexRebuildGeneration =
        self.indexRebuildGeneration + 1

    local generation = self.indexRebuildGeneration

    zo_callLater(function()
        if generation ~= BCO.indexRebuildGeneration
            or not BCO.active
        then
            return
        end

        -- EnsureIndex either patches the resident aggregate in place
        -- (incremental) and returns true, or starts a chunked rebuild whose
        -- completion callback refreshes the list. Only the former needs the
        -- explicit refresh here.
        if BCO:EnsureIndex() then
            local KEEP_SELECTION = false
            BCO:RefreshActiveBCOList(KEEP_SELECTION)
        end
    end, delayMs or 0)
end

local function GetCurrentOwnedHouseId()
    if type(GetCurrentZoneHouseId) ~= "function" then
        return nil
    end

    local ok, houseId = pcall(GetCurrentZoneHouseId)

    if not ok or not houseId or houseId == 0 then
        return nil
    end

    -- Only catalog houses the account owns. Visited houses would create
    -- misleading locations for items the player cannot retrieve.
    if type(IsOwnerOfCurrentHouse) == "function" then
        local okOwner, isOwner = pcall(IsOwnerOfCurrentHouse)

        if not okOwner or isOwner ~= true then
            return nil
        end
    end

    return houseId
end

-- Uses the standard house name from the collectible, matching how the base
-- game labels houses (e.g. the housing preview UI). Player-set nicknames
-- are intentionally ignored so locations read consistently.
local function GetHouseDisplayName(houseId)
    local collectibleId = 0

    if type(GetCollectibleIdForHouse) == "function" then
        local ok, id = pcall(
            GetCollectibleIdForHouse,
            houseId
        )

        if ok and id then
            collectibleId = id
        end
    end

    if collectibleId ~= 0 then
        if type(GetCollectibleName) == "function" then
            local ok, collectibleName = pcall(
                GetCollectibleName,
                collectibleId
            )

            collectibleName = ok
                and FormatStorageName(collectibleName)
                or ""

            if collectibleName ~= "" then
                return collectibleName
            end
        end
    end

    return string.format("House %d", houseId)
end

-- Builds an item snapshot from a bare item link (no bag slot). Used for
-- placed house furnishings and guild store listings. count starts at 0 and
-- is accumulated by the caller.
local function ReadItemLinkSnapshot(itemLink)
    if not itemLink or itemLink == "" then
        return nil
    end

    return {
        itemLink = itemLink,
        count = 0,
    }
end

-- Walks every furnishing placed in the current owned house in small chunks
-- so large houses (700+ placed items) never stall a frame. Duplicate
-- furnishings collapse into one snapshot entry with a count, which keeps
-- SavedVariables small and the link-derived reads to one per unique item.
function BCO:ScanCurrentHouse()
    local houseId = GetCurrentOwnedHouseId()

    if not houseId
        or type(GetNextPlacedHousingFurnitureId)
            ~= "function"
    then
        return false
    end

    self.houseScanToken = self.houseScanToken + 1
    local token = self.houseScanToken

    local aggregate = {}
    local items = {}
    local furnitureId = nil

    local function ProcessChunk()
        if token ~= BCO.houseScanToken then
            return
        end

        -- Abandon the scan if the player left the house mid-walk; a fresh
        -- scan starts on the next activation inside an owned house.
        if GetCurrentOwnedHouseId() ~= houseId then
            return
        end

        local processed = 0
        local done = false

        while processed < 40 do
            local ok, nextId = pcall(
                GetNextPlacedHousingFurnitureId,
                furnitureId
            )

            if not ok or not nextId then
                done = true
                break
            end

            furnitureId = nextId

            local itemLink = ""

            if type(GetPlacedFurnitureLink) == "function" then
                local okLink, link = pcall(
                    GetPlacedFurnitureLink,
                    furnitureId,
                    LINK_STYLE_DEFAULT
                )

                if okLink then
                    itemLink = link or ""
                end
            end

            -- Collectible-based furnishings return no item link. They are
            -- not inventory items, so they stay out of the item catalog.
            if itemLink ~= "" then
                local snapshot = aggregate[itemLink]

                if not snapshot then
                    snapshot = ReadItemLinkSnapshot(itemLink)

                    if snapshot then
                        aggregate[itemLink] = snapshot
                        items[#items + 1] = snapshot
                    end
                end

                if snapshot then
                    snapshot.count = snapshot.count + 1
                end
            end

            processed = processed + 1
        end

        if not done then
            zo_callLater(ProcessChunk, 0)
            return
        end

        BCO.savedVars.shared.houses =
            BCO.savedVars.shared.houses or {}

        BCO.savedVars.shared.houses[tostring(houseId)] = {
            houseId = houseId,
            name = GetHouseDisplayName(houseId),
            items = items,
            updated = Now(),
        }

        BCO:ScheduleIndexRebuild(
            50,
            "house:" .. tostring(houseId)
        )
    end

    ProcessChunk()
    return true
end

function BCO:ScheduleHouseScan(delayMs)
    if self.houseScanScheduled then
        return
    end

    self.houseScanScheduled = true

    zo_callLater(function()
        BCO.houseScanScheduled = false
        BCO:ScanCurrentHouse()
    end, delayMs or 750)
end

local function GetActiveTradingHouseGuild()
    local guildId, guildName = nil, ""

    if type(GetCurrentTradingHouseGuildDetails)
        == "function"
    then
        local ok, id, name = pcall(
            GetCurrentTradingHouseGuildDetails
        )

        if ok and id and id ~= 0 then
            guildId = id
            guildName = name or ""
        end
    end

    if not guildId
        and type(GetSelectedTradingHouseGuildId)
            == "function"
    then
        local ok, id = pcall(
            GetSelectedTradingHouseGuildId
        )

        if ok and id and id ~= 0 then
            guildId = id
        end
    end

    if not guildId then
        return nil, ""
    end

    guildName = FormatStorageName(guildName)

    if guildName == ""
        and type(GetGuildName) == "function"
    then
        local ok, name = pcall(GetGuildName, guildId)

        if ok then
            guildName = FormatStorageName(name)
        end
    end

    if guildName == "" then
        guildName = string.format(
            "Guild %d",
            guildId
        )
    end

    return guildId, guildName
end

-- Snapshots the player's own sell listings for the guild currently selected
-- at the trading house. A player can hold at most 30 listings per guild, so
-- this scan runs synchronously. An empty result still overwrites the stored
-- snapshot, which clears out sold or canceled listings on the next visit.
function BCO:ScanTradingHouseListings()
    if not self.tradingHouseOpen
        or type(GetNumTradingHouseListings)
            ~= "function"
        or type(GetTradingHouseListingItemLink)
            ~= "function"
    then
        return false
    end

    local guildId, guildName =
        GetActiveTradingHouseGuild()

    if not guildId then
        return false
    end

    local aggregate = {}
    local items = {}
    local okCount, listingCount = pcall(
        GetNumTradingHouseListings
    )

    if not okCount then
        return false
    end

    for index = 1, listingCount or 0 do
        local okLink, itemLink = pcall(
            GetTradingHouseListingItemLink,
            index,
            LINK_STYLE_DEFAULT
        )

        if okLink and itemLink and itemLink ~= "" then
            local stackCount = 1

            if type(GetTradingHouseListingItemInfo)
                == "function"
            then
                local okInfo, _, _, _, listingStack =
                    pcall(
                        GetTradingHouseListingItemInfo,
                        index
                    )

                if okInfo
                    and listingStack
                    and listingStack > 0
                then
                    stackCount = listingStack
                end
            end

            local snapshot = aggregate[itemLink]

            if not snapshot then
                snapshot =
                    ReadItemLinkSnapshot(itemLink)

                if snapshot then
                    aggregate[itemLink] = snapshot
                    items[#items + 1] = snapshot
                end
            end

            if snapshot then
                snapshot.count =
                    snapshot.count + stackCount
            end
        end
    end

    self.savedVars.shared.guildListings =
        self.savedVars.shared.guildListings or {}

    local listings =
        self.savedVars.shared.guildListings

    listings[tostring(guildId)] = {
        guildId = guildId,
        name = guildName,
        items = items,
        updated = Now(),
    }

    -- Drop snapshots for guilds the account has since left; their listings
    -- were returned by mail and no longer exist.
    if type(IsPlayerInGuild) == "function" then
        for key, listing in pairs(listings) do
            local listedGuildId =
                type(listing) == "table"
                and listing.guildId
                or tonumber(key)

            if listedGuildId then
                local ok, inGuild = pcall(
                    IsPlayerInGuild,
                    listedGuildId
                )

                if ok and inGuild == false then
                    listings[key] = nil
                end
            end
        end
    end

    self:ScheduleIndexRebuild(
        50,
        "guild:" .. tostring(guildId)
    )
    return true
end

function BCO:ScheduleListingScan(delayMs)
    if self.listingScanScheduled then
        return
    end

    self.listingScanScheduled = true

    zo_callLater(function()
        BCO.listingScanScheduled = false
        BCO:ScanTradingHouseListings()
    end, delayMs or 250)
end

-- The trading house allows one pending request at a time and enforces a
-- cooldown, so the listings request politely waits its turn. The open flag
-- stops the retry chain once the player leaves the trader.
function BCO:RequestListingsWhenReady()
    if not self.tradingHouseOpen
        or type(RequestTradingHouseListings)
            ~= "function"
    then
        return
    end

    local cooldown = 0

    if type(GetTradingHouseCooldownRemaining)
        == "function"
    then
        local ok, remaining = pcall(
            GetTradingHouseCooldownRemaining
        )

        if ok then
            cooldown = remaining or 0
        end
    end

    if cooldown > 0 then
        zo_callLater(function()
            BCO:RequestListingsWhenReady()
        end, cooldown + 100)
        return
    end

    pcall(RequestTradingHouseListings)
end

function BCO:ScanSharedCurrencies()
    self.savedVars.shared =
        self.savedVars.shared or {}

    self.savedVars.shared.currencies = {
        bank = ScanBankCurrencies(),
        updated = Now(),
    }
end

function BCO:ScanCurrentCurrencies()
    local id = CharacterId()

    if not id then
        return false
    end

    local character =
        self.savedVars.characters[id]

    if type(character) ~= "table" then
        character = {
            id = id,
            name = CharacterName(),
            backpack = {},
            worn = {},
            updated = 0,
        }

        self.savedVars.characters[id] =
            character
    end

    character.id = id
    character.name = CharacterName()
    character.currencies =
        ScanCharacterCurrencies()
    character.currencyUpdated = Now()

    self:ScanSharedCurrencies()
    return true
end

function BCO:ScanCurrentCharacter(rebuildIndex)
    local id = CharacterId()
    if not id then
        return false
    end

    local updated = Now()

    self.savedVars.characters[id] = {
        id = id,
        name = CharacterName(),
        backpack = ScanBag(BAG_BACKPACK),
        worn = ScanBag(BAG_WORN),
        currencies = ScanCharacterCurrencies(),
        currencyUpdated = updated,
        updated = updated,
    }

    self:ScanSharedCurrencies()

    local bankSourceKey = nil

    if self.bankOpen then
        bankSourceKey = self:ScanOpenBankLocation()
    end

    if rebuildIndex ~= false then
        self:ScheduleIndexRebuild(
            50,
            "char:" .. id .. ":backpack",
            "char:" .. id .. ":worn",
            bankSourceKey
        )
    end

    return true
end

function BCO:ScheduleScan(delayMs)
    if self.scanPending then
        return
    end

    self.scanPending = true

    zo_callLater(function()
        BCO.scanPending = false
        BCO:ScanCurrentCharacter()
    end, delayMs or 350)
end

local MATERIAL_TYPES = {}
local QUICKslot_TYPES = {}
local FURNISHING_TYPES = {}
local QUEST_TYPES = {}

local function AddType(target, constantName)
    local value = _G[constantName]
    if value ~= nil then
        target[value] = true
    end
end

for _, name in ipairs({
    "ITEMTYPE_BLACKSMITHING_MATERIAL",
    "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL",
    "ITEMTYPE_CLOTHIER_MATERIAL",
    "ITEMTYPE_CLOTHIER_RAW_MATERIAL",
    "ITEMTYPE_WOODWORKING_MATERIAL",
    "ITEMTYPE_WOODWORKING_RAW_MATERIAL",
    "ITEMTYPE_JEWELRYCRAFTING_MATERIAL",
    "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL",
    "ITEMTYPE_STYLE_MATERIAL",
    "ITEMTYPE_ARMOR_TRAIT",
    "ITEMTYPE_WEAPON_TRAIT",
    "ITEMTYPE_JEWELRY_TRAIT",
    "ITEMTYPE_REAGENT",
    "ITEMTYPE_POTION_BASE",
    "ITEMTYPE_POISON_BASE",
    "ITEMTYPE_ENCHANTING_RUNE_ASPECT",
    "ITEMTYPE_ENCHANTING_RUNE_ESSENCE",
    "ITEMTYPE_ENCHANTING_RUNE_POTENCY",
    "ITEMTYPE_INGREDIENT",
    "ITEMTYPE_RAW_MATERIAL",
}) do
    AddType(MATERIAL_TYPES, name)
end

-- Fallback for old snapshots created before filterType was stored.
for _, name in ipairs({
    "ITEMTYPE_POTION",
    "ITEMTYPE_POISON",
    "ITEMTYPE_FOOD",
    "ITEMTYPE_DRINK",
    "ITEMTYPE_SIEGE",
    "ITEMTYPE_AVA_REPAIR",
    "ITEMTYPE_REPAIR",
    "ITEMTYPE_CROWN_REPAIR",
}) do
    AddType(QUICKslot_TYPES, name)
end

AddType(FURNISHING_TYPES, "ITEMTYPE_FURNISHING")
AddType(QUEST_TYPES, "ITEMTYPE_QUEST_ITEM")

local function IsWeapon(item)
    return _G.ITEMTYPE_WEAPON ~= nil
        and item.itemType == ITEMTYPE_WEAPON
end

local function IsApparel(item)
    return (
        _G.ITEMTYPE_ARMOR ~= nil
        and item.itemType == ITEMTYPE_ARMOR
    ) or (
        _G.ITEMTYPE_COSTUME ~= nil
        and item.itemType == ITEMTYPE_COSTUME
    ) or (
        _G.ITEMTYPE_DISGUISE ~= nil
        and item.itemType == ITEMTYPE_DISGUISE
    )
end

local function IsFilterType(item, filterTypeName)
    local expected = _G[filterTypeName]
    if expected == nil then
        return false
    end

    local filterData = item.filterData or {}

    for index = 1, #filterData do
        if filterData[index] == expected then
            return true
        end
    end

    return false
end

local function IsMaterial(item)
    return IsFilterType(
        item,
        "ITEMFILTERTYPE_CRAFTING"
    ) or MATERIAL_TYPES[item.itemType] == true
end

local function IsSlottable(item)
    return IsFilterType(
        item,
        "ITEMFILTERTYPE_QUICKSLOT"
    ) or QUICKslot_TYPES[item.itemType] == true
end

local function IsFurnishing(item)
    return IsFilterType(
        item,
        "ITEMFILTERTYPE_FURNISHING"
    ) or FURNISHING_TYPES[item.itemType] == true
end

local function IsQuest(item)
    return IsFilterType(
        item,
        "ITEMFILTERTYPE_QUEST"
    ) or QUEST_TYPES[item.itemType] == true
end

local function IsEquipment(item)
    return IsWeapon(item) or IsApparel(item)
end

local function IsCompanion(item)
    return IsFilterType(
        item,
        "ITEMFILTERTYPE_COMPANION"
    )
end

local function IsSupplies(item)
    return item.equipType == EQUIP_TYPE_INVALID
        and not IsSlottable(item)
        and not IsMaterial(item)
        and not IsFurnishing(item)
        and not IsCompanion(item)
        and not IsQuest(item)
end

local function IsSpecificCategory(item)
    return IsSupplies(item)
        or IsMaterial(item)
        or IsSlottable(item)
        or IsFurnishing(item)
        or IsCompanion(item)
        or IsQuest(item)
        or IsEquipment(item)
end

local function MatchesCategory(item, key)
    if key == "currencies" then
        return false
    elseif key == "all" then
        return true
    elseif key == "supplies" then
        return IsSupplies(item)
    elseif key == "slottable" then
        return IsSlottable(item)
    elseif key == "furnishings" then
        return IsFurnishing(item)
    elseif key == "companion" then
        return IsCompanion(item)
    elseif key == "quest" then
        return IsQuest(item)
    elseif key == "weapons" then
        return IsWeapon(item)
    elseif key == "apparel" then
        return IsApparel(item)
    elseif key == "materials" then
        return IsMaterial(item)
    elseif key == "misc" then
        return not IsSpecificCategory(item)
    end

    return false
end

function BCO:CollectSources()
    local sources = {}
    local usedNames = {}

    -- sourceKey is a stable identifier ("char:<id>:backpack", "bank", ...)
    -- that the incremental index update uses to find the display name a
    -- source was aggregated under (see BCO:ApplySourceUpdate).
    local function AddSource(
        items,
        preferredName,
        kind,
        updated,
        uniqueSuffix,
        sourceKey
    )
        preferredName = Trim(preferredName)

        if preferredName == "" then
            preferredName = "Unknown Location"
        end

        local name = preferredName
        local normalizedName = Lower(name)

        if usedNames[normalizedName] then
            local suffix = uniqueSuffix
                or tostring(#sources + 1)

            name = string.format(
                "%s (%s)",
                preferredName,
                suffix
            )
            normalizedName = Lower(name)

            local duplicateIndex = 2

            while usedNames[normalizedName] do
                name = string.format(
                    "%s (%s-%d)",
                    preferredName,
                    suffix,
                    duplicateIndex
                )
                normalizedName = Lower(name)
                duplicateIndex = duplicateIndex + 1
            end
        end

        usedNames[normalizedName] = true
        sources[#sources + 1] = {
            items = items or {},
            name = name,
            kind = kind,
            updated = updated or 0,
            key = sourceKey,
        }
    end

    for characterId, character in pairs(
        self.savedVars.characters
    ) do
        local characterName = character.name
            or "Unknown Character"

        AddSource(
            character.backpack,
            characterName,
            "backpack",
            character.updated,
            nil,
            "char:" .. tostring(characterId) .. ":backpack"
        )

        AddSource(
            character.worn,
            characterName .. " (Equipped)",
            "equipped",
            character.updated,
            nil,
            "char:" .. tostring(characterId) .. ":worn"
        )
    end

    local bank = self.savedVars.shared.bank or {}

    AddSource(
        bank.items,
        "Bank",
        "bank",
        bank.updated,
        nil,
        "bank"
    )

    local storageRows = {}

    for storageKey, storage in pairs(
        self.savedVars.shared.storage or {}
    ) do
        if type(storage) == "table" then
            local bagId = storage.bagId
                or tonumber(storageKey)
            local ordinal = bagId
                and HOUSE_BANK_ORDINALS[bagId]
            local fallbackName

            if storage.isFurnitureVault
                or IsFurnitureVaultBag(bagId)
            then
                fallbackName = "Furnishing Vault"
            elseif ordinal then
                fallbackName = string.format(
                    "Housing Storage %d",
                    ordinal
                )
            else
                fallbackName = "Housing Storage"
            end

            local name = storage.name or fallbackName

            storageRows[#storageRows + 1] = {
                items = storage.items or {},
                name = name,
                sortName = Lower(name),
                updated = storage.updated or 0,
                bagId = bagId,
                ordinal = ordinal,
                isFurnitureVault =
                    storage.isFurnitureVault == true
                    or IsFurnitureVaultBag(bagId),
            }
        end
    end

    table.sort(storageRows, function(left, right)
        if left.isFurnitureVault
            ~= right.isFurnitureVault
        then
            return not left.isFurnitureVault
        end

        if (left.ordinal or 999)
            ~= (right.ordinal or 999)
        then
            return (left.ordinal or 999)
                < (right.ordinal or 999)
        end

        if left.sortName ~= right.sortName then
            return left.sortName < right.sortName
        end

        return tostring(left.bagId or "")
            < tostring(right.bagId or "")
    end)

    for index = 1, #storageRows do
        local storage = storageRows[index]
        local suffix

        if storage.isFurnitureVault then
            suffix = "Vault"
        elseif storage.ordinal then
            suffix = string.format(
                "Storage %d",
                storage.ordinal
            )
        else
            suffix = string.format(
                "Storage %d",
                index
            )
        end

        AddSource(
            storage.items,
            storage.name,
            "storage",
            storage.updated,
            suffix,
            "storage:" .. tostring(storage.bagId or index)
        )
    end

    local houseRows = {}

    for houseKey, house in pairs(
        self.savedVars.shared.houses or {}
    ) do
        if type(house) == "table" then
            local houseId = house.houseId
                or tonumber(houseKey)
                or 0

            -- Recompute from the live API so snapshots saved under an old
            -- nickname show the standard house name without a revisit.
            local name = houseId ~= 0
                and GetHouseDisplayName(houseId)
                or house.name
                or "House"

            houseRows[#houseRows + 1] = {
                items = house.items or {},
                name = name,
                sortName = Lower(name),
                updated = house.updated or 0,
                houseId = houseId,
            }
        end
    end

    table.sort(houseRows, function(left, right)
        if left.sortName ~= right.sortName then
            return left.sortName < right.sortName
        end

        return left.houseId < right.houseId
    end)

    for index = 1, #houseRows do
        local house = houseRows[index]

        AddSource(
            house.items,
            house.name,
            "house",
            house.updated,
            string.format("House %d", house.houseId),
            "house:" .. tostring(house.houseId)
        )
    end

    local listingRows = {}

    for listingKey, listing in pairs(
        self.savedVars.shared.guildListings or {}
    ) do
        if type(listing) == "table" then
            local name = listing.name or "Guild"

            listingRows[#listingRows + 1] = {
                items = listing.items or {},
                name = name,
                sortName = Lower(name),
                updated = listing.updated or 0,
                guildId = listing.guildId
                    or tonumber(listingKey)
                    or 0,
            }
        end
    end

    table.sort(listingRows, function(left, right)
        if left.sortName ~= right.sortName then
            return left.sortName < right.sortName
        end

        return left.guildId < right.guildId
    end)

    for index = 1, #listingRows do
        local listing = listingRows[index]

        AddSource(
            listing.items,
            string.format(
                "%s (Listed)",
                listing.name
            ),
            "guildStore",
            listing.updated,
            string.format(
                "Guild %d",
                listing.guildId
            ),
            "guild:" .. tostring(listing.guildId)
        )
    end

    return sources
end

-- Derives the display/classification data for one unique item link. Called
-- once per unique link per index build; the result lives in the aggregate.
local function BuildAggregateItem(key, itemLink)
    local itemType, specializedItemType = 0, 0

    if GetItemLinkItemType then
        itemType, specializedItemType =
            GetItemLinkItemType(itemLink)
    end

    local formattedName = FormatItemName(
        GetItemLinkName
            and GetItemLinkName(itemLink)
            or "Unknown Item"
    )

    return {
        key = key,
        itemLink = itemLink,
        itemId = GetItemLinkItemId
            and GetItemLinkItemId(itemLink)
            or 0,
        name = formattedName,
        normalizedName = Lower(formattedName),
        icon = GetItemLinkIcon
            and GetItemLinkIcon(itemLink)
            or "",
        quality = GetLinkDisplayQuality(
            itemLink,
            ITEM_DISPLAY_QUALITY_NORMAL
        ),
        itemType = itemType or 0,
        specializedItemType = specializedItemType or 0,
        equipType = GetItemLinkEquipType
            and GetItemLinkEquipType(itemLink)
            or EQUIP_TYPE_INVALID,
        filterData = GetFilterData(itemLink, nil, nil),
        setName = SetName(itemLink),
        totalCount = 0,
        locations = {},
        locationKinds = {},
    }
end

-- Marks the aggregate stale. The rebuild itself only runs while All
-- Inventories is on screen (see ScheduleIndexRebuild / EnsureIndex); every
-- other inventory change just flips this flag, so looting, banking and
-- crafting no longer re-aggregate the whole account catalog in the
-- background.
function BCO:MarkIndexDirty()
    self.indexDirty = true
end

-- Records that one snapshot source (a character bag, the bank, a storage
-- chest, a house, a guild's listings) changed. While the aggregate is
-- resident, the next EnsureIndex applies just that source's delta instead
-- of re-walking the whole account (see ApplySourceUpdate). With no resident
-- aggregate this degrades to MarkIndexDirty.
function BCO:MarkSourceDirty(sourceKey)
    -- No resident aggregate: the next open rebuilds everything anyway.
    if not self.indexReady and not self.indexBuilding then
        self.indexDirty = true
        return
    end

    -- Resident, or being built from the source tables captured when the
    -- build started: either way the delta can be applied afterwards.
    self.dirtySourceKeys = self.dirtySourceKeys or {}
    self.dirtySourceKeys[sourceKey] = true
    self.indexDirty = true
end

-- Drops the resident aggregate so its memory returns to the shared console
-- Lua pool. Called when Inventory closes; the next visit to All Inventories
-- rebuilds it in chunks. A warmed aggregate is roughly 2 KB per unique item
-- (views, search text and section caches included), so a multi-thousand
-- item account holds 10+ MB that is useless while Inventory is closed and
-- that every other load screen then has to fit beside.
function BCO:ReleaseIndex()
    self.indexToken = self.indexToken + 1
    self.indexBuilding = false
    self.indexReady = false
    self.indexDirty = true
    self.dirtySourceKeys = nil
    self.aggregatedItems = {}
    self.filteredItems = {}
    self.sourceNamesByKey = nil
end

-- Kept for callers that only want to release stale data.
function BCO:ReleaseIndexIfDirty()
    if self.indexDirty then
        self:ReleaseIndex()
    end
end

-- Clears every derived per-item cache that depends on the item's location
-- set. Called after a source delta changed the item's locations.
local function InvalidateItemLocationCaches(item)
    item.bcoViews = nil
    item.bcoSearchText = nil
    item.bcoPreviewSlotMiss = nil
    -- The row keeps bcoPreviewBagId/SlotIndex from the last preview; those
    -- may no longer be valid once the item moved.
    local data = item.bcoEntryData
    if data then
        data.bcoPreviewBagId = nil
        data.bcoPreviewSlotIndex = nil
    end
end

-- Adds one source's snapshot list into the aggregate under the given
-- display name. Shared by the full build and the incremental update.
local function AggregateSourceItems(aggregate, source)
    local items = source.items
    local name = source.name
    local kind = source.kind or "backpack"

    for index = 1, #items do
        local snapshot = items[index]
        local itemLink = snapshot and snapshot.itemLink

        if type(itemLink) == "string" and itemLink ~= "" then
            local item = aggregate[itemLink]

            if not item then
                item = BuildAggregateItem(itemLink, itemLink)
                aggregate[itemLink] = item
            end

            local count = snapshot.count or 1
            item.totalCount = item.totalCount + count
            item.locations[name] =
                (item.locations[name] or 0) + count
            item.locationKinds[name] = kind
            InvalidateItemLocationCaches(item)
        end
    end
end

-- Removes every contribution made under one location name. Items are left
-- in place even when this empties them, so a re-add of the same source
-- keeps their derived data and row objects; SweepEmptyAggregateItems drops
-- whatever is still empty afterwards.
local function RemoveLocationFromAggregate(aggregate, name)
    for _, item in pairs(aggregate) do
        local count = item.locations[name]

        if count then
            item.totalCount = item.totalCount - count
            item.locations[name] = nil
            item.locationKinds[name] = nil
            InvalidateItemLocationCaches(item)
        end
    end
end

local function SweepEmptyAggregateItems(aggregate)
    for itemLink, item in pairs(aggregate) do
        if item.totalCount <= 0
            or next(item.locations) == nil
        then
            aggregate[itemLink] = nil
        end
    end
end

-- Applies the pending per-source deltas to the resident aggregate. Returns
-- true when the incremental path handled everything, false when a full
-- rebuild is still required (a source was renamed, added or removed, or no
-- source keys were recorded).
function BCO:ApplySourceUpdate()
    local dirtyKeys = self.dirtySourceKeys
    local previousNames = self.sourceNamesByKey

    if not dirtyKeys or not previousNames then
        return false
    end

    local sources = self:CollectSources()
    local sourcesByKey = {}
    local currentNames = {}

    for index = 1, #sources do
        local source = sources[index]

        if source.key then
            sourcesByKey[source.key] = source
            currentNames[source.key] = source.name
        end
    end

    -- A source appearing or disappearing (first scan of a new character,
    -- /bcoclear, a guild left) changes the duplicate-name suffixes, so the
    -- display names no longer line up; take the full rebuild in that case.
    for key, name in pairs(previousNames) do
        if currentNames[key] ~= name then
            return false
        end
    end

    for key in pairs(currentNames) do
        if previousNames[key] == nil then
            return false
        end
    end

    local aggregate = self.aggregatedItems

    for key in pairs(dirtyKeys) do
        local source = sourcesByKey[key]

        if source then
            RemoveLocationFromAggregate(aggregate, source.name)
        end
    end

    for key in pairs(dirtyKeys) do
        local source = sourcesByKey[key]

        if source then
            AggregateSourceItems(aggregate, source)
        end
    end

    SweepEmptyAggregateItems(aggregate)

    self.dirtySourceKeys = nil
    self.indexDirty = false
    self.filteredItems = {}
    return true
end

function BCO:StartIndexBuild(onComplete)
    self.indexToken = self.indexToken + 1
    local token = self.indexToken

    local sources = self:CollectSources()
    local sourceIndex = 1
    local itemIndex = 1
    local aggregate = {}
    local sourceNames = {}

    for index = 1, #sources do
        local source = sources[index]

        if source.key then
            sourceNames[source.key] = source.name
        end
    end

    -- Release the previous aggregate up front rather than holding two full
    -- copies while the new one builds. Snapshot changes that arrive while
    -- All Inventories is open are now applied incrementally, so a full
    -- rebuild only happens on the first open after Inventory was closed,
    -- when there is nothing on screen to keep serving.
    self.aggregatedItems = {}
    self.filteredItems = {}
    self.dirtySourceKeys = nil
    self.indexDirty = false
    self.indexReady = false
    self.indexBuilding = true

    local function ProcessChunk()
        if token ~= BCO.indexToken then
            return
        end

        local processed = 0
        -- Each entry costs a few table lookups; unique links additionally
        -- cost roughly eight item-link API calls. 200 per frame keeps a
        -- multi-thousand item catalog to a handful of frames without
        -- approaching the console per-frame budget.
        local maximum = 200

        while processed < maximum and sourceIndex <= #sources do
            local source = sources[sourceIndex]
            local snapshot = source.items[itemIndex]

            if snapshot then
                local itemLink = snapshot.itemLink

                if type(itemLink) == "string"
                    and itemLink ~= ""
                then
                    local item = aggregate[itemLink]

                    if not item then
                        item = BuildAggregateItem(
                            itemLink,
                            itemLink
                        )
                        aggregate[itemLink] = item
                    end

                    local count = snapshot.count or 1
                    item.totalCount = item.totalCount + count
                    item.locations[source.name] =
                        (item.locations[source.name] or 0)
                        + count
                    item.locationKinds[source.name] =
                        source.kind or "backpack"
                end

                itemIndex = itemIndex + 1
                processed = processed + 1
            else
                sourceIndex = sourceIndex + 1
                itemIndex = 1
            end
        end

        if sourceIndex <= #sources then
            zo_callLater(ProcessChunk, 0)
            return
        end

        BCO.aggregatedItems = aggregate
        BCO.filteredItems = {}
        BCO.sourceNamesByKey = sourceNames
        BCO.indexReady = true
        BCO.indexBuilding = false

        if onComplete then
            onComplete()
        end

        -- A snapshot changed while the chunks were running; fold it in now
        -- (incrementally, if the source keys were recorded) rather than
        -- waiting for the next inventory event.
        if BCO.indexDirty and BCO.active then
            BCO:ScheduleIndexRebuild(0)
        end
    end

    ProcessChunk()
end

-- Builds or refreshes the aggregate when All Inventories needs it. Returns
-- true when the current aggregate is already usable.
function BCO:EnsureIndex()
    if self.indexReady and not self.indexDirty then
        return true
    end

    -- A build is already walking the sources; let it finish.
    if self.indexBuilding then
        return self.indexReady
    end

    -- Resident aggregate with known per-source changes: patch it in place.
    if self.indexReady and self:ApplySourceUpdate() then
        return true
    end

    self:StartIndexBuild(function()
        if BCO.active then
            BCO:RefreshActiveBCOList(true)
        end
    end)

    return self.indexReady
end


function BCO:FindSearchTextControl()
    local inventory = GAMEPAD_INVENTORY

    if not inventory then
        return nil
    end

    local candidates = {
        inventory.searchEditBox,
        inventory.textSearchEditBox,
        inventory.textSearchHeaderEditBox,
    }

    local focus = inventory.textSearchHeaderFocus

    if type(focus) == "table" then
        candidates[#candidates + 1] =
            focus.editBox
        candidates[#candidates + 1] =
            focus.editBoxControl
        candidates[#candidates + 1] =
            focus.searchEditBox
        candidates[#candidates + 1] =
            focus.control
    end

    for index = 1, #candidates do
        local candidate = candidates[index]

        if candidate
            and type(candidate.GetText) == "function"
        then
            return candidate
        end
    end

    return FindTextControl(
        inventory.textSearchHeaderControl
    )
end

function BCO:ReadSearchText(callbackText)
    local text

    if type(callbackText) == "string" then
        text = Trim(callbackText)
    else
        text = ReadControlText(
            self:FindSearchTextControl()
        ) or ""
    end

    text = Lower(text)

    if text == SearchPlaceholder() then
        return ""
    end

    return text
end

local function ItemSearchText(item)
    -- rawget: filtered views read other fields through their aggregate item,
    -- but the search text depends on the view's own location set.
    local cached = rawget(item, "bcoSearchText")

    if cached then
        return cached
    end

    local parts = {
        item.name or "",
        item.setName or "",
    }

    for locationName in pairs(
        item.locations or {}
    ) do
        parts[#parts + 1] = locationName
    end

    item.bcoSearchText = Lower(
        table.concat(parts, " ")
    )

    return item.bcoSearchText
end

-- Splits a search string into lowercase tokens once per list refresh so the
-- per-item test is a handful of plain finds rather than a gmatch each time.
local function SearchTokens(searchText)
    searchText = Trim(searchText)

    if searchText == "" then
        return nil
    end

    local tokens = {}

    for token in searchText:gmatch("%S+") do
        tokens[#tokens + 1] = token
    end

    if #tokens == 0 then
        return nil
    end

    return tokens
end

local function ItemMatchesTokens(item, tokens)
    if not tokens then
        return true
    end

    local itemText = ItemSearchText(item)

    for index = 1, #tokens do
        if not itemText:find(tokens[index], 1, true) then
            return false
        end
    end

    return true
end

function BCO:GetInventoryFilter()
    return self.inventoryFilters[
        self.inventoryFilterIndex
    ] or self.inventoryFilters[1]
end

function BCO:GetInventoryFilterKey()
    local filter = self:GetInventoryFilter()
    return filter and filter.key or "all"
end

function BCO:GetInventoryFilterKeybindName()
    local filter = self:GetInventoryFilter()
    return filter and filter.keybindName or "All"
end

local function InferLocationKind(name)
    local lowered = Lower(name)

    if lowered == "bank" then
        return "bank"
    elseif lowered:sub(-11) == " (equipped)" then
        return "equipped"
    end

    return "backpack"
end

local function LocationMatchesInventoryFilter(
    locationKind,
    filterKey
)
    if filterKey == "all" then
        return true
    elseif filterKey == "bank" then
        return locationKind == "bank"
    elseif filterKey == "backpack" then
        return locationKind == "backpack"
            or locationKind == "equipped"
    elseif filterKey == "storage" then
        return locationKind == "storage"
            or locationKind == "house"
    elseif filterKey == "listings" then
        return locationKind == "guildStore"
    end

    return true
end

-- Returns the item as seen through the Square source filter. For "All" the
-- aggregate item is used directly. For other filters a small view table
-- carrying only the filtered location fields is created once per item and
-- cached on it; every other field reads through to the aggregate item via
-- __index. This replaces a full 16-field deep copy of every item on every
-- list refresh and every category search check.
local function BuildInventoryFilteredItem(
    item,
    filterKey
)
    if filterKey == "all" then
        return item
    end

    local views = item.bcoViews

    if views then
        local cached = views[filterKey]

        if cached ~= nil then
            return cached or nil
        end
    else
        views = {}
        item.bcoViews = views
    end

    local locations = {}
    local locationKinds = {}
    local totalCount = 0

    for name, count in pairs(item.locations or {}) do
        local locationKind = item.locationKinds
            and item.locationKinds[name]
            or InferLocationKind(name)

        if LocationMatchesInventoryFilter(
            locationKind,
            filterKey
        ) then
            locations[name] = count
            locationKinds[name] = locationKind
            totalCount = totalCount + (count or 0)
        end
    end

    if totalCount <= 0 then
        views[filterKey] = false
        return nil
    end

    local view = setmetatable({
        totalCount = totalCount,
        locations = locations,
        locationKinds = locationKinds,
    }, { __index = item })

    views[filterKey] = view
    return view
end

function BCO:HasStorageSnapshots()
    for _, storage in pairs(
        self.savedVars.shared.storage or {}
    ) do
        if type(storage) == "table"
            and (storage.updated or 0) > 0
        then
            return true
        end
    end

    for _, house in pairs(
        self.savedVars.shared.houses or {}
    ) do
        if type(house) == "table"
            and (house.updated or 0) > 0
        then
            return true
        end
    end

    return false
end

function BCO:HasListingSnapshots()
    for _, listing in pairs(
        self.savedVars.shared.guildListings or {}
    ) do
        if type(listing) == "table"
            and (listing.updated or 0) > 0
        then
            return true
        end
    end

    return false
end

-- One pass over the aggregate that reports which categories have at least
-- one item matching the current source filter and search text. Replaces
-- ten separate full scans (one per category) during a search.
function BCO:ComputeCategorySearchHits(searchText)
    local filterKey = self:GetInventoryFilterKey()
    local tokens = SearchTokens(searchText)
    local hits = {}
    local categories = self.categories
    local remaining = 0

    for index = 1, #categories do
        if categories[index].key ~= "currencies" then
            remaining = remaining + 1
        end
    end

    for _, item in pairs(self.aggregatedItems) do
        local filteredItem =
            BuildInventoryFilteredItem(item, filterKey)

        if filteredItem
            and ItemMatchesTokens(filteredItem, tokens)
        then
            for index = 1, #categories do
                local key = categories[index].key

                if not hits[key]
                    and key ~= "currencies"
                    and MatchesCategory(filteredItem, key)
                then
                    hits[key] = true
                    remaining = remaining - 1
                end
            end

            if remaining <= 0 then
                break
            end
        end
    end

    return hits
end

function BCO:RefreshSearchResults(
    callbackText
)
    if not self.active
        or not GAMEPAD_INVENTORY
    then
        return
    end

    local previousText = self.searchText or ""

    self.searchText =
        self:ReadSearchText(callbackText)

    -- ESO fires search-result updates for every inventory change even when
    -- the search box is empty. Nothing about the search changed, so leave
    -- the BCO list alone; snapshot changes reach it through the index.
    if self.searchText == previousText then
        return
    end

    local current =
        GAMEPAD_INVENTORY:GetCurrentList()

    if current == self.itemList then
        self:RefreshItemList(true)

        local selectedData =
            self.itemList:GetTargetData()

        self.lastSelectedItemData = selectedData

        self:ScheduleItemTooltip(
            selectedData
        )
    elseif current == self.categoryList then
        self:RefreshCategoryList(true)
    end
end

function BCO:ScheduleSearchRefresh(
    callbackText
)
    self.searchRefreshGeneration =
        self.searchRefreshGeneration + 1

    local generation =
        self.searchRefreshGeneration

    zo_callLater(function()
        if generation
                ~= BCO.searchRefreshGeneration
            or not BCO.active
        then
            return
        end

        BCO:RefreshSearchResults(
            callbackText
        )
    end, 0)
end

-- Collects the items for one category under the current source filter and
-- search text. The result is left unsorted; BuildSectionedItemRows sorts
-- rows by section and name in a single pass.
function BCO:FilterItems(categoryKey)
    local result = {}
    local tokens = SearchTokens(self.searchText or "")
    local filterKey =
        self:GetInventoryFilterKey()

    for _, item in pairs(self.aggregatedItems) do
        local filteredItem =
            BuildInventoryFilteredItem(
                item,
                filterKey
            )

        if filteredItem
            and MatchesCategory(
                filteredItem,
                categoryKey
            )
            and ItemMatchesTokens(
                filteredItem,
                tokens
            )
        then
            result[#result + 1] = filteredItem
        end
    end

    self.filteredItems = result
    return result
end

local function MenuEquality(left, right)
    return left == right
        or (
            left
            and right
            and left.bcoKey == right.bcoKey
        )
end

local function SetupCategoryList(list)
    list:AddDataTemplate(
        "ZO_GamepadItemEntryTemplate",
        ZO_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction,
        MenuEquality
    )

    list:AddDataTemplateWithHeader(
        "ZO_GamepadItemEntryTemplate",
        ZO_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction,
        MenuEquality,
        "ZO_GamepadMenuEntryHeaderTemplate"
    )

    if list.SetReselectBehavior
        and ZO_PARAMETRIC_SCROLL_LIST_RESELECT_BEHAVIOR
    then
        list:SetReselectBehavior(
            ZO_PARAMETRIC_SCROLL_LIST_RESELECT_BEHAVIOR
                .MATCH_OR_RESET_TO_DEFAULT
        )
    end
end

local function SetupItemList(list)
    list:AddDataTemplate(
        "ZO_GamepadItemSubEntryTemplate",
        ZO_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction,
        MenuEquality
    )

    list:AddDataTemplateWithHeader(
        "ZO_GamepadItemSubEntryTemplate",
        ZO_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction,
        MenuEquality,
        "ZO_GamepadMenuEntryHeaderTemplate"
    )
end

local function FormatSectionHeader(sectionName)
    if not sectionName or sectionName == "" then
        sectionName = "Items"
    end

    if zo_strformat and SI_INVENTORY_HEADER then
        return zo_strformat(
            SI_INVENTORY_HEADER,
            sectionName
        )
    end

    return sectionName
end

local function GetEnumString(enumName, enumValue)
    if type(GetString) ~= "function"
        or enumValue == nil
    then
        return nil
    end

    local ok, value = pcall(
        GetString,
        enumName,
        enumValue
    )

    if ok
        and type(value) == "string"
        and value ~= ""
    then
        return value
    end

    return nil
end

local function GetItemLinkWeaponTypeSafe(itemLink)
    if type(GetItemLinkWeaponType) ~= "function"
        or not itemLink
        or itemLink == ""
    then
        return nil
    end

    local ok, weaponType = pcall(
        GetItemLinkWeaponType,
        itemLink
    )

    if ok then
        return weaponType
    end

    return nil
end

-- Mirrors ESO's current gamepad weapon grouping. This deliberately groups
-- individual flame/frost/lightning staves under Destruction Staff and the
-- one-handed weapon types under One-Handed Melee.
local function GetWeaponSectionName(item)
    local weaponType =
        GetItemLinkWeaponTypeSafe(
            item.itemLink
        )

    if not weaponType
        or weaponType == WEAPONTYPE_NONE
    then
        return nil
    end

    local categoryType = nil

    if weaponType == WEAPONTYPE_AXE
        or weaponType == WEAPONTYPE_HAMMER
        or weaponType == WEAPONTYPE_SWORD
        or weaponType == WEAPONTYPE_DAGGER
    then
        categoryType =
            GAMEPAD_WEAPON_CATEGORY_ONE_HANDED_MELEE
    elseif weaponType == WEAPONTYPE_TWO_HANDED_SWORD
        or weaponType == WEAPONTYPE_TWO_HANDED_AXE
        or weaponType == WEAPONTYPE_TWO_HANDED_HAMMER
    then
        categoryType =
            GAMEPAD_WEAPON_CATEGORY_TWO_HANDED_MELEE
    elseif weaponType == WEAPONTYPE_FIRE_STAFF
        or weaponType == WEAPONTYPE_FROST_STAFF
        or weaponType == WEAPONTYPE_LIGHTNING_STAFF
    then
        categoryType =
            GAMEPAD_WEAPON_CATEGORY_DESTRUCTION_STAFF
    elseif weaponType == WEAPONTYPE_HEALING_STAFF then
        categoryType =
            GAMEPAD_WEAPON_CATEGORY_RESTORATION_STAFF
    elseif weaponType == WEAPONTYPE_BOW then
        categoryType =
            GAMEPAD_WEAPON_CATEGORY_TWO_HANDED_BOW
    else
        categoryType =
            GAMEPAD_WEAPON_CATEGORY_UNCATEGORIZED
    end

    if categoryType
        and categoryType
            ~= GAMEPAD_WEAPON_CATEGORY_UNCATEGORIZED
    then
        local categoryName = GetEnumString(
            "SI_GAMEPADWEAPONCATEGORY",
            categoryType
        )

        if categoryName then
            return FormatSectionHeader(
                categoryName
            )
        end
    end

    local weaponName = GetEnumString(
        "SI_WEAPONTYPE",
        weaponType
    )

    return weaponName
        and FormatSectionHeader(weaponName)
        or nil
end

local APPAREL_SECTION_ORDER = {}

local function RegisterApparelOrder(equipType, order)
    if equipType ~= nil then
        APPAREL_SECTION_ORDER[equipType] = order
    end
end

RegisterApparelOrder(EQUIP_TYPE_HEAD, 10)
RegisterApparelOrder(EQUIP_TYPE_SHOULDERS, 20)
RegisterApparelOrder(EQUIP_TYPE_CHEST, 30)
RegisterApparelOrder(EQUIP_TYPE_HAND, 40)
RegisterApparelOrder(EQUIP_TYPE_WAIST, 50)
RegisterApparelOrder(EQUIP_TYPE_LEGS, 60)
RegisterApparelOrder(EQUIP_TYPE_FEET, 70)
RegisterApparelOrder(EQUIP_TYPE_NECK, 80)
RegisterApparelOrder(EQUIP_TYPE_RING, 90)
RegisterApparelOrder(EQUIP_TYPE_COSTUME, 100)

-- ESO's normal Inventory presents worn equipment primarily through equipment
-- slots rather than one combined Apparel page. All Inventories therefore uses
-- those slot names as its own useful Apparel subsections.
local function GetApparelSectionName(item)
    local equipType = item.equipType

    if not equipType
        or equipType == EQUIP_TYPE_INVALID
    then
        return nil, nil
    end

    local sectionName = GetEnumString(
        "SI_EQUIPTYPE",
        equipType
    )

    if sectionName then
        return FormatSectionHeader(sectionName),
            APPAREL_SECTION_ORDER[equipType]
            or 999
    end

    return nil, nil
end

-- Reusable scratch table for ZO_InventoryUtils_Gamepad_GetBestItemCategoryDescription,
-- which only reads the fields below. Section names are cached per item
-- (see GetItemSectionInfo), so this runs once per unique item per index.
local nativeSectionItemData = {}

local function GetNativeUtilitySectionName(item)
    if type(
        ZO_InventoryUtils_Gamepad_GetBestItemCategoryDescription
    ) ~= "function"
    then
        return nil
    end

    local itemData = nativeSectionItemData
    itemData.itemLink = item.itemLink or ""
    itemData.name = item.name or ""
    itemData.rawName = item.name or ""
    itemData.iconFile = item.icon or ""
    itemData.stackCount = item.totalCount or 1
    itemData.itemType = item.itemType or 0
    itemData.specializedItemType =
        item.specializedItemType or 0
    itemData.equipType =
        item.equipType or EQUIP_TYPE_INVALID
    itemData.displayQuality =
        item.quality or ITEM_DISPLAY_QUALITY_NORMAL
    itemData.quality =
        item.quality or ITEM_DISPLAY_QUALITY_NORMAL

    local ok, sectionName = pcall(
        ZO_InventoryUtils_Gamepad_GetBestItemCategoryDescription,
        itemData
    )

    if ok
        and type(sectionName) == "string"
        and sectionName ~= ""
    then
        return FormatSectionHeader(
            sectionName
        )
    end

    return nil
end

local function GetFallbackSectionName(item)
    local specializedName = GetEnumString(
        "SI_SPECIALIZEDITEMTYPE",
        item.specializedItemType or 0
    )

    if specializedName then
        return FormatSectionHeader(
            specializedName
        )
    end

    local itemTypeName = GetEnumString(
        "SI_ITEMTYPE",
        item.itemType or 0
    )

    if itemTypeName then
        return FormatSectionHeader(
            itemTypeName
        )
    end

    return FormatSectionHeader("Items")
end

-- ESO's native inventory groups furnishings by furniture category (Lighting,
-- Seating, Structures, ...). BCO items come from snapshots without live bag
-- slots, so the category is resolved from the item link instead. The result
-- is cached on the aggregated item because section names are recomputed on
-- every list refresh.
local function GetFurnishingSectionName(item)
    if item.bcoFurnishingSection ~= nil then
        return item.bcoFurnishingSection or nil
    end

    item.bcoFurnishingSection = false

    if not IsFurnishing(item)
        or type(GetItemLinkFurnitureDataId)
            ~= "function"
        or type(GetFurnitureCategoryInfo)
            ~= "function"
    then
        return nil
    end

    local itemLink = item.itemLink

    if not itemLink or itemLink == "" then
        return nil
    end

    local ok, furnitureDataId = pcall(
        GetItemLinkFurnitureDataId,
        itemLink
    )

    if not ok
        or not furnitureDataId
        or furnitureDataId == 0
    then
        return nil
    end

    local categoryId = nil

    if type(GetFurnitureDataCategoryInfo)
        == "function"
    then
        local okCategory, id = pcall(
            GetFurnitureDataCategoryInfo,
            furnitureDataId
        )

        if okCategory then
            categoryId = id
        end
    elseif type(GetFurnitureDataInfo) == "function" then
        local okCategory, id = pcall(
            GetFurnitureDataInfo,
            furnitureDataId
        )

        if okCategory then
            categoryId = id
        end
    end

    if not categoryId or categoryId == 0 then
        return nil
    end

    local okName, categoryName = pcall(
        GetFurnitureCategoryInfo,
        categoryId
    )

    if okName
        and type(categoryName) == "string"
        and categoryName ~= ""
    then
        item.bcoFurnishingSection =
            FormatSectionHeader(categoryName)

        return item.bcoFurnishingSection
    end

    return nil
end

local function ComputeItemSectionInfo(item, categoryKey)
    local weaponSection =
        GetWeaponSectionName(item)

    if weaponSection then
        return weaponSection, 100
    end

    local furnishingSection =
        GetFurnishingSectionName(item)

    if furnishingSection then
        return furnishingSection, 300
    end

    if categoryKey == "apparel"
        or categoryKey == "companion"
        or item.itemType == ITEMTYPE_ARMOR
    then
        local apparelSection, apparelOrder =
            GetApparelSectionName(item)

        if apparelSection then
            return apparelSection,
                apparelOrder or 200
        end
    end

    local nativeSection =
        GetNativeUtilitySectionName(item)

    if nativeSection then
        return nativeSection, 300
    end

    return GetFallbackSectionName(item), 900
end

-- Section lookups cost several GetString/zo_strformat and item-link calls
-- per item. Cache them on the aggregate item (views read through to it via
-- rawget on the underlying table) keyed by whether the apparel-slot rule
-- applied, which is the only category-dependent branch above.
local function GetItemSectionInfo(item, categoryKey)
    local apparelRule = categoryKey == "apparel"
        or categoryKey == "companion"
    local cacheKey = apparelRule
        and "bcoSectionApparel"
        or "bcoSection"
    local cached = item[cacheKey]

    if cached then
        return cached.name, cached.order, cached.normalized
    end

    local name, order =
        ComputeItemSectionInfo(item, categoryKey)

    cached = {
        name = name,
        order = order or 999,
        normalized = Lower(name),
    }

    -- Store on the aggregate item rather than a filtered view so every
    -- source filter shares one cache entry.
    local target = item
    local meta = getmetatable(item)

    if meta and meta.__index and type(meta.__index) == "table" then
        target = meta.__index
    end

    target[cacheKey] = cached

    return cached.name, cached.order, cached.normalized
end

local function BuildSectionedItemRows(items, categoryKey)
    local rows = {}

    for index = 1, #items do
        local item = items[index]
        local sectionName, sectionOrder, normalizedSection =
            GetItemSectionInfo(
                item,
                categoryKey
            )

        rows[#rows + 1] = {
            item = item,
            sectionName = sectionName,
            sectionOrder = sectionOrder or 999,
            normalizedSection = normalizedSection,
        }
    end

    table.sort(rows, function(left, right)
        -- Apparel has a natural equipment-slot order. All other sections keep
        -- ESO's familiar alphabetic category ordering.
        if categoryKey == "apparel"
            or categoryKey == "companion"
        then
            if left.sectionOrder
                ~= right.sectionOrder
            then
                return left.sectionOrder
                    < right.sectionOrder
            end
        elseif left.normalizedSection
            ~= right.normalizedSection
        then
            return left.normalizedSection
                < right.normalizedSection
        end

        if left.normalizedSection
            == right.normalizedSection
        then
            if left.item.normalizedName
                == right.item.normalizedName
            then
                return tostring(left.item.key)
                    < tostring(right.item.key)
            end

            return left.item.normalizedName
                < right.item.normalizedName
        end

        return left.normalizedSection
            < right.normalizedSection
    end)

    return rows
end

local function ColorizeLocationRow(text)
    if ZO_SELECTED_TEXT
        and type(ZO_SELECTED_TEXT.Colorize) == "function"
    then
        return ZO_SELECTED_TEXT:Colorize(text)
    end

    return text
end

local function BuildSortedLocationRows(item)
    local rows = {}
    local currentName = Lower(CharacterName())
    local currentEquippedName = currentName .. " (equipped)"

    for name, count in pairs(item.locations or {}) do
        local lowered = Lower(name)

        rows[#rows + 1] = {
            name = name,
            sortName = lowered,
            count = count or 0,
            isBank = lowered == "bank",
            isCurrent = lowered == currentName
                or lowered == currentEquippedName,
        }
    end

    table.sort(rows, function(left, right)
        if left.isBank ~= right.isBank then
            return left.isBank
        end

        if left.isCurrent ~= right.isCurrent then
            return left.isCurrent
        end

        if left.count ~= right.count then
            return left.count > right.count
        end

        return left.sortName < right.sortName
    end)

    return rows
end

local function FormatLocationLine(row)
    return ColorizeLocationRow(
        string.format(
            "%s  x%d",
            row.name,
            row.count
        )
    )
end

local function LocationStatusText(item)
    local rows = BuildSortedLocationRows(item)

    if #rows == 0 then
        return ""
    end

    -- Keep a fixed three-row body under ITEM LOCATIONS. Two exact locations
    -- are shown, followed by a summary row when more locations exist. This
    -- keeps the tooltip anchored without reserving an unnecessary fourth
    -- row that would place the item details too high on the screen.
    local lines = { "ITEM LOCATIONS" }
    local visibleCount = math.min(
        #rows,
        BCO.collapsedLocationRows
    )

    for index = 1, visibleCount do
        lines[#lines + 1] =
            FormatLocationLine(rows[index])
    end

    if #rows > visibleCount then
        local hiddenCount = #rows - visibleCount
        local hiddenTotal = 0

        for index = visibleCount + 1, #rows do
            hiddenTotal = hiddenTotal
                + rows[index].count
        end

        local locationWord = hiddenCount == 1
            and "OTHER LOCATION"
            or "OTHER LOCATIONS"

        lines[#lines + 1] = ColorizeLocationRow(
            string.format(
                "%d %s  x%d",
                hiddenCount,
                locationWord,
                hiddenTotal
            )
        )
    end

    while #lines < 1 + BCO.collapsedLocationBodyRows do
        lines[#lines + 1] = " "
    end

    return table.concat(lines, "\n")
end

local function ExpandedLocationText(item)
    local rows = BuildSortedLocationRows(item)
    local lines = {}

    for index = 1, #rows do
        lines[#lines + 1] =
            FormatLocationLine(rows[index])
    end

    return table.concat(lines, "\n"), #rows
end

local function LocationCount(item)
    local count = 0

    for _ in pairs(item and item.locations or {}) do
        count = count + 1
    end

    return count
end

local function ForceTooltipControlVisible(tooltipType)
    local tooltips = GAMEPAD_TOOLTIPS
        and GAMEPAD_TOOLTIPS.tooltips

    local tooltipInfo = tooltips
        and tooltips[tooltipType]

    if not tooltipInfo then
        return
    end

    local control = tooltipInfo.control

    if control and control.SetHidden then
        control:SetHidden(false)
    end

    local container = control and control.container
    if container and container.SetHidden then
        container:SetHidden(false)
    end
end

local function SetLocationTooltipInputEnabled(enabled)
    if GAMEPAD_TOOLTIPS
        and type(GAMEPAD_TOOLTIPS.SetInputEnabled) == "function"
    then
        pcall(
            GAMEPAD_TOOLTIPS.SetInputEnabled,
            GAMEPAD_TOOLTIPS,
            GAMEPAD_LEFT_TOOLTIP,
            enabled
        )
    end
end

-- Returns the ZO_ScrollTooltip_Gamepad wrapper that owns the left tooltip's
-- right-stick scroll handler, or nil if the console UI has not built it yet.
-- For the standard gamepad left tooltip this is container.tip itself (the
-- scroll wrapper), whose inner ZO_Tooltip is container.tip.tooltip.
local function GetLeftTooltipScrollTip()
    local tooltipInfo =
        GAMEPAD_TOOLTIPS
        and GAMEPAD_TOOLTIPS.tooltips
        and GAMEPAD_TOOLTIPS.tooltips[
            GAMEPAD_LEFT_TOOLTIP
        ]

    local control = tooltipInfo and tooltipInfo.control
    local container = control and control.container

    return container and container.tip
end


local function FormatCurrencyAmount(amount)
    amount = tonumber(amount) or 0

    if type(ZO_CommaDelimitNumber) == "function" then
        local ok, formatted = pcall(
            ZO_CommaDelimitNumber,
            amount
        )

        if ok and formatted then
            return tostring(formatted)
        end
    end

    return tostring(amount)
end

local function CurrencyDisplayName(definition)
    local name

    if type(GetCurrencyName) == "function" then
        local ok, value = pcall(
            GetCurrencyName,
            definition.currencyType,
            false,
            true
        )

        if ok and type(value) == "string" then
            name = Trim(value)
        end
    end

    if not name or name == "" then
        name = definition.fallbackName
    end

    return name
end

local function CurrencyIconMarkup(currencyType)
    local icon

    if type(GetCurrencyGamepadIcon) == "function" then
        local ok, value = pcall(
            GetCurrencyGamepadIcon,
            currencyType
        )

        if ok and type(value) == "string" then
            icon = value
        end
    end

    if (not icon or icon == "")
        and type(GetCurrencyKeyboardIcon) == "function"
    then
        local ok, value = pcall(
            GetCurrencyKeyboardIcon,
            currencyType
        )

        if ok and type(value) == "string" then
            icon = value
        end
    end

    if not icon or icon == "" then
        return ""
    end

    if type(zo_iconFormat) == "function" then
        local ok, markup = pcall(
            zo_iconFormat,
            icon,
            30,
            30
        )

        if ok and markup then
            return " " .. tostring(markup)
        end
    end

    return string.format(
        " |t30:30:%s|t",
        icon
    )
end

local function CurrencyHeading(text)
    if ZO_SELECTED_TEXT
        and type(ZO_SELECTED_TEXT.Colorize) == "function"
    then
        return ZO_SELECTED_TEXT:Colorize(text)
    end

    return text
end

function BCO:GetCurrencyTooltipData()
    local characters = {}
    local missingSnapshot = false

    for _, character in pairs(
        self.savedVars.characters or {}
    ) do
        if type(character) == "table" then
            characters[#characters + 1] = {
                name = character.name
                    or "Unknown Character",
                currencies = character.currencies,
            }
        end
    end

    table.sort(characters, function(left, right)
        return Lower(left.name) < Lower(right.name)
    end)

    local bankCurrencies =
        self.savedVars.shared
        and self.savedVars.shared.currencies
        and self.savedVars.shared.currencies.bank
        or {}
    local definitions =
        GetCharacterCurrencyDefinitions()
    local totals = {}

    for definitionIndex = 1, #definitions do
        local key = tostring(
            definitions[definitionIndex].currencyType
        )
        totals[key] =
            tonumber(bankCurrencies[key]) or 0
    end

    for characterIndex = 1, #characters do
        local currencies =
            characters[characterIndex].currencies

        if type(currencies) == "table" then
            for definitionIndex = 1, #definitions do
                local key = tostring(
                    definitions[definitionIndex].currencyType
                )
                totals[key] = (totals[key] or 0)
                    + (tonumber(currencies[key]) or 0)
            end
        else
            missingSnapshot = true
        end
    end

    return {
        characters = characters,
        bankCurrencies = bankCurrencies,
        definitions = definitions,
        totals = totals,
        missingSnapshot = missingSnapshot,
    }
end

local function CurrencyDisplayNameUpper(definition)
    local name = CurrencyDisplayName(definition)

    if type(zo_strupper) == "function" then
        local ok, upperName = pcall(
            zo_strupper,
            name
        )

        if ok and type(upperName) == "string" then
            return upperName
        end
    end

    return string.upper(name)
end

local function CurrencyTooltipTitle()
    if type(GetString) == "function"
        and SI_INVENTORY_CURRENCIES
    then
        local ok, title = pcall(
            GetString,
            SI_INVENTORY_CURRENCIES
        )

        if ok and type(title) == "string"
            and title ~= ""
        then
            return title
        end
    end

    return "Currencies"
end

local function NativeCurrencyValue(
    definition,
    amount,
    isScanned
)
    if isScanned == false then
        return "NOT SCANNED"
            .. CurrencyIconMarkup(
                definition.currencyType
            )
    end

    amount = tonumber(amount) or 0

    local whiteAmountIconFormat =
        ZO_CURRENCY_FORMAT_WHITE_AMOUNT_ICON
        or ZO_CURRENCY_FORMAT_AMOUNT_ICON

    if type(ZO_Currency_FormatGamepad) == "function"
        and whiteAmountIconFormat
    then
        local options = {
            showCap = false,
        }
        local ok, value = pcall(
            ZO_Currency_FormatGamepad,
            definition.currencyType,
            amount,
            whiteAmountIconFormat,
            options
        )

        if ok and type(value) == "string"
            and value ~= ""
        then
            return value
        end
    end

    return FormatCurrencyAmount(amount)
        .. CurrencyIconMarkup(
            definition.currencyType
        )
end

local function IsCurrencyTooltipObject(candidate)
    return candidate
        and type(candidate.GetStyle) == "function"
        and type(candidate.AcquireSection) == "function"
        and type(candidate.AddSection) == "function"
end

local function GetCurrencyTooltipTip()
    local tooltipInfo =
        GAMEPAD_TOOLTIPS
        and GAMEPAD_TOOLTIPS.tooltips
        and GAMEPAD_TOOLTIPS.tooltips[
            GAMEPAD_LEFT_TOOLTIP
        ]

    if not tooltipInfo then
        return nil
    end

    local control = tooltipInfo.control
    local container = control and control.container
    local scrollTip = container and container.tip

    -- On console, container.tip is the scroll-tooltip wrapper.
    -- The actual ZO_Tooltip object that owns GetStyle(),
    -- AcquireSection(), and AddSection() is wrapper.tooltip.
    -- Some UI versions expose that object directly, so check
    -- every known location and return only a usable tooltip.
    local candidate = tooltipInfo.tooltip
    if IsCurrencyTooltipObject(candidate) then
        return candidate
    end

    candidate = control and control.tooltip
    if IsCurrencyTooltipObject(candidate) then
        return candidate
    end

    candidate = container and container.tooltip
    if IsCurrencyTooltipObject(candidate) then
        return candidate
    end

    candidate = scrollTip and scrollTip.tooltip
    if IsCurrencyTooltipObject(candidate) then
        return candidate
    end

    if IsCurrencyTooltipObject(scrollTip) then
        return scrollTip
    end

    return nil
end

local function AddNativeCurrencyLocationSection(
    tip,
    mainSection,
    heading,
    currencies,
    isScanned,
    definitions
)
    -- Use the same nested sections and styles as ESO's native
    -- gamepad currency overview. The dedicated currency pair
    -- style supplies the smaller fonts, off-white labels,
    -- white values, fixed row width, and right alignment.
    local locationSection = mainSection:AcquireSection(
        tip:GetStyle("currencyLocationSection")
    )

    locationSection:AddLine(
        heading,
        tip:GetStyle("currencyLocationTitle")
    )

    local currenciesSection = locationSection:AcquireSection(
        tip:GetStyle("currencyLocationCurrenciesSection")
    )

    for definitionIndex = 1, #definitions do
        local definition = definitions[definitionIndex]
        local key = tostring(
            definition.currencyType
        )
        local pair = currenciesSection:AcquireStatValuePair(
            tip:GetStyle("currencyStatValuePair")
        )

        pair:SetStat(
            CurrencyDisplayNameUpper(definition),
            tip:GetStyle("currencyStatValuePairStat")
        )
        pair:SetValue(
            NativeCurrencyValue(
                definition,
                currencies and currencies[key],
                isScanned
            ),
            tip:GetStyle("currencyStatValuePairValue")
        )
        currenciesSection:AddStatValuePair(pair)
    end

    locationSection:AddSection(currenciesSection)
    mainSection:AddSection(locationSection)
end

function BCO:LayoutNativeCurrencyTooltip()
    local data = self:GetCurrencyTooltipData()
    local definitions = data.definitions
    local tip = GetCurrencyTooltipTip()

    if #definitions == 0
        or not tip
        or type(tip.GetStyle) ~= "function"
        or type(tip.AcquireSection) ~= "function"
        or type(tip.AddSection) ~= "function"
    then
        return false
    end

    local ok = pcall(function()
        local mainSection = tip:AcquireSection(
            tip:GetStyle("currencyMainSection")
        )

        AddNativeCurrencyLocationSection(
            tip,
            mainSection,
            "TOTAL",
            data.totals,
            true,
            definitions
        )
        AddNativeCurrencyLocationSection(
            tip,
            mainSection,
            "BANKED",
            data.bankCurrencies,
            true,
            definitions
        )

        for characterIndex = 1, #data.characters do
            local character =
                data.characters[characterIndex]
            local isScanned =
                type(character.currencies) == "table"

            AddNativeCurrencyLocationSection(
                tip,
                mainSection,
                character.name,
                character.currencies,
                isScanned,
                definitions
            )
        end

        tip:AddSection(mainSection)
    end)

    return ok
end

function BCO:BuildCurrencyTooltipText()
    local lines = {}
    local data = self:GetCurrencyTooltipData()
    local definitions = data.definitions

    local function AppendSection(
        heading,
        currencies,
        isScanned
    )
        if #lines > 0 then
            lines[#lines + 1] = " "
        end

        lines[#lines + 1] =
            CurrencyHeading(heading)

        for definitionIndex = 1, #definitions do
            local definition =
                definitions[definitionIndex]
            local key = tostring(
                definition.currencyType
            )
            local value

            if isScanned == false then
                value = "NOT SCANNED"
            else
                value = FormatCurrencyAmount(
                    currencies and currencies[key]
                )
            end

            lines[#lines + 1] = string.format(
                "%s  %s%s",
                CurrencyDisplayNameUpper(definition),
                value,
                CurrencyIconMarkup(
                    definition.currencyType
                )
            )
        end
    end

    if #definitions == 0 then
        lines[#lines + 1] =
            "Character currency data is unavailable."
        return table.concat(lines, "\n")
    end

    AppendSection("TOTAL", data.totals, true)
    AppendSection(
        "BANKED",
        data.bankCurrencies,
        true
    )

    for characterIndex = 1, #data.characters do
        local character =
            data.characters[characterIndex]
        local isScanned =
            type(character.currencies) == "table"

        AppendSection(
            character.name,
            character.currencies,
            isScanned
        )
    end

    return table.concat(lines, "\n")
end

function BCO:RenderCurrencyTooltip()
    if not GAMEPAD_TOOLTIPS then
        return false
    end

    GAMEPAD_TOOLTIPS:ClearTooltip(
        GAMEPAD_LEFT_TOOLTIP
    )
    GAMEPAD_TOOLTIPS:ClearTooltip(
        GAMEPAD_RIGHT_TOOLTIP
    )

    local title = CurrencyTooltipTitle()

    if GAMEPAD_TOOLTIPS.SetStatusLabelText then
        pcall(
            GAMEPAD_TOOLTIPS.SetStatusLabelText,
            GAMEPAD_TOOLTIPS,
            GAMEPAD_LEFT_TOOLTIP,
            "",
            title
        )
    elseif GAMEPAD_TOOLTIPS.ClearStatusLabel then
        pcall(
            GAMEPAD_TOOLTIPS.ClearStatusLabel,
            GAMEPAD_TOOLTIPS,
            GAMEPAD_LEFT_TOOLTIP
        )
    end

    local rendered = self:LayoutNativeCurrencyTooltip()

    if not rendered then
        GAMEPAD_TOOLTIPS:ClearTooltip(
            GAMEPAD_LEFT_TOOLTIP
        )

        local text = self:BuildCurrencyTooltipText()

        if GAMEPAD_TOOLTIPS.LayoutTitleAndDescriptionTooltip then
            rendered = pcall(
                GAMEPAD_TOOLTIPS.LayoutTitleAndDescriptionTooltip,
                GAMEPAD_TOOLTIPS,
                GAMEPAD_LEFT_TOOLTIP,
                "CURRENCIES",
                text
            )
        elseif GAMEPAD_TOOLTIPS.LayoutTextBlockTooltip then
            rendered = pcall(
                GAMEPAD_TOOLTIPS.LayoutTextBlockTooltip,
                GAMEPAD_TOOLTIPS,
                GAMEPAD_LEFT_TOOLTIP,
                "CURRENCIES\n\n" .. text
            )
        end
    end

    -- Direct native section layout bypasses the manager's normal layout
    -- wrapper, so explicitly restore the standard gamepad tooltip backdrop.
    if type(GAMEPAD_TOOLTIPS.SetBgType) == "function" then
        pcall(
            GAMEPAD_TOOLTIPS.SetBgType,
            GAMEPAD_TOOLTIPS,
            GAMEPAD_LEFT_TOOLTIP,
            GAMEPAD_TOOLTIP_NORMAL_BG or 1
        )
    end

    if type(GAMEPAD_TOOLTIPS.SetAutoShowBg) == "function" then
        pcall(
            GAMEPAD_TOOLTIPS.SetAutoShowBg,
            GAMEPAD_TOOLTIPS,
            GAMEPAD_LEFT_TOOLTIP,
            true
        )
    end

    if type(GAMEPAD_TOOLTIPS.ShowBg) == "function" then
        pcall(
            GAMEPAD_TOOLTIPS.ShowBg,
            GAMEPAD_TOOLTIPS,
            GAMEPAD_LEFT_TOOLTIP
        )
    end

    ForceTooltipControlVisible(
        GAMEPAD_LEFT_TOOLTIP
    )
    SetLocationTooltipInputEnabled(true)

    if GAMEPAD_TOOLTIPS.ResetScrollTooltipToTop then
        GAMEPAD_TOOLTIPS:ResetScrollTooltipToTop(
            GAMEPAD_LEFT_TOOLTIP
        )
    end

    return rendered
end

function BCO:ScheduleCurrencyTooltip(selectedData)
    self.currencyTooltipGeneration =
        self.currencyTooltipGeneration + 1

    local generation =
        self.currencyTooltipGeneration
    local pendingData = selectedData
    local rendered = false
    local delays = { 0, 200 }

    for index = 1, #delays do
        zo_callLater(function()
            if rendered
                or generation ~= BCO.currencyTooltipGeneration
                or not BCO.active
                or not GAMEPAD_INVENTORY
                or GAMEPAD_INVENTORY:GetCurrentList()
                    ~= BCO.categoryList
            then
                return
            end

            local currentData =
                BCO.categoryList:GetTargetData()
                or pendingData

            if currentData
                and currentData.bcoKey == "currencies"
            then
                rendered = BCO:RenderCurrencyTooltip() == true
            end
        end, delays[index])
    end
end

function BCO:UpdateCategoryTooltip(selectedData)
    self.currencyTooltipGeneration =
        self.currencyTooltipGeneration + 1

    SetLocationTooltipInputEnabled(false)

    if GAMEPAD_TOOLTIPS then
        GAMEPAD_TOOLTIPS:ClearTooltip(
            GAMEPAD_LEFT_TOOLTIP
        )
        GAMEPAD_TOOLTIPS:ClearTooltip(
            GAMEPAD_RIGHT_TOOLTIP
        )
    end

    if selectedData
        and selectedData.bcoKey == "currencies"
    then
        self:ScheduleCurrencyTooltip(
            selectedData
        )
    end
end

local function GetItemPreviewObject()
    if not SYSTEMS
        or type(SYSTEMS.GetObject) ~= "function"
    then
        return nil
    end

    local ok, previewObject = pcall(
        SYSTEMS.GetObject,
        SYSTEMS,
        "itemPreview"
    )

    if ok then
        return previewObject
    end

    return nil
end

function BCO:SetFurnishingPreviewBuffer(enabled)
    local previewObject = GetItemPreviewObject()

    if not previewObject
        or type(previewObject.SetPreviewBufferMS)
            ~= "function"
    then
        return false
    end

    -- Keep the previous furnishing visible while rapid gamepad selection
    -- changes settle. A non-zero buffer is important on console because a
    -- zero millisecond buffer still commits every transient row on the next
    -- preview update and can expose the character while the model changes.
    local bufferMilliseconds = enabled
        and (self.furnishingPreviewSettleMS or 90)
        or nil

    return pcall(
        previewObject.SetPreviewBufferMS,
        previewObject,
        bufferMilliseconds
    )
end

local function CanPreviewItemLinkAsFurniture(itemLink)
    if not itemLink or itemLink == "" then
        return false
    end

    -- Update 50 can expose either the furniture-specific validator or only
    -- the generic item-link validator, depending on the UI path/platform.
    -- Accept either result so saved links from another character are not
    -- rejected before PreviewItemLink gets a chance to handle them.
    if type(CanItemLinkBePreviewedAsFurniture)
        == "function"
    then
        local ok, canPreview = pcall(
            CanItemLinkBePreviewedAsFurniture,
            itemLink
        )

        if ok and canPreview == true then
            return true
        end
    end

    if type(CanItemLinkBePreviewed) == "function" then
        local ok, canPreview = pcall(
            CanItemLinkBePreviewed,
            itemLink
        )

        if ok and canPreview == true then
            return true
        end
    end

    -- PreviewItemLink is itself the final authority on clients that do not
    -- publish either eligibility helper to insecure addon code.
    return type(PreviewItemLink) == "function"
end

local function ClearPendingPreviewCollection(previewObject)
    if not previewObject
        or type(previewObject.ClearPreviewCollection)
            ~= "function"
    then
        return false
    end

    return pcall(
        previewObject.ClearPreviewCollection,
        previewObject
    )
end

local function CommitPendingPreviewCollection()
    if type(ApplyChangesToPreviewCollectionShown)
        ~= "function"
    then
        return false
    end

    return pcall(ApplyChangesToPreviewCollectionShown)
end

local function TryFurnishingPreviewCall(path, callback, ...)
    BCO.lastFurnishingPreviewPath = path or "unknown"

    local ok, result = pcall(callback, ...)

    if ok then
        BCO.lastFurnishingPreviewError = nil
    else
        BCO.lastFurnishingPreviewError =
            tostring(result or "preview call failed")
    end

    return ok
end

local function FindItemLinkInBag(bagId, itemLink)
    if bagId == nil
        or not itemLink
        or itemLink == ""
        or type(GetItemLink) ~= "function"
    then
        return nil
    end

    local foundSlotIndex = nil

    local ok = pcall(
        IterateBag,
        bagId,
        function(slotIndex)
            if foundSlotIndex ~= nil then
                return
            end

            local liveLink = GetItemLink(
                bagId,
                slotIndex,
                LINK_STYLE_DEFAULT
            ) or ""

            if liveLink == itemLink then
                foundSlotIndex = slotIndex
            end
        end
    )

    if ok then
        return foundSlotIndex
    end

    return nil
end

function BCO:FindLiveFurnishingPreviewSlot(item)
    if not item
        or not item.itemLink
        or item.itemLink == ""
    then
        return nil, nil
    end

    -- Scanning every reachable bag costs on the order of 1,500 GetItemLink
    -- calls. Remember a miss on the aggregate item so snapshot-only
    -- furnishings (houses, listings, other characters) are scanned once
    -- per index build rather than on every selection change.
    if rawget(item, "bcoPreviewSlotMiss") then
        return nil, nil
    end

    local bags = {}
    local seenBags = {}

    local function AddBag(bagId)
        if bagId ~= nil and not seenBags[bagId] then
            seenBags[bagId] = true
            bags[#bags + 1] = bagId
        end
    end

    -- ESO's native furniture preview path needs a real inventory slot that
    -- the client currently exposes. Check every bag that can legitimately be
    -- available, then let CanInventoryItemBePreviewed reject unloaded bags.
    AddBag(BAG_BACKPACK)
    AddBag(BAG_WORN)
    AddBag(self.activeBankBag)
    AddBag(BAG_BANK)
    AddBag(BAG_SUBSCRIBER_BANK)
    AddBag(BAG_FURNITURE_VAULT)

    for bagId in pairs(HOUSE_BANK_ORDINALS) do
        AddBag(bagId)
    end

    for storageKey, storage in pairs(
        self.savedVars
            and self.savedVars.shared
            and self.savedVars.shared.storage
            or {}
    ) do
        if type(storage) == "table" then
            AddBag(storage.bagId or tonumber(storageKey))
        else
            AddBag(tonumber(storageKey))
        end
    end

    for index = 1, #bags do
        local bagId = bags[index]
        local slotIndex = FindItemLinkInBag(
            bagId,
            item.itemLink
        )

        if slotIndex ~= nil then
            if type(CanInventoryItemBePreviewed)
                == "function"
            then
                local ok, canPreview = pcall(
                    CanInventoryItemBePreviewed,
                    bagId,
                    slotIndex
                )

                if ok and canPreview then
                    return bagId, slotIndex
                end
            else
                return bagId, slotIndex
            end
        end
    end

    item.bcoPreviewSlotMiss = true
    return nil, nil
end

function BCO:GetSelectedItemData(fallbackData)
    local targetData = self.itemList
        and self.itemList:GetTargetData()

    if targetData and targetData.bcoItem then
        self.lastSelectedItemData = targetData
        return targetData
    end

    if fallbackData and fallbackData.bcoItem then
        self.lastSelectedItemData = fallbackData
        return fallbackData
    end

    local inventoryData = GAMEPAD_INVENTORY
        and GAMEPAD_INVENTORY.currentlySelectedData

    if inventoryData and inventoryData.bcoItem then
        self.lastSelectedItemData = inventoryData
        return inventoryData
    end

    if self.lastSelectedItemData
        and self.lastSelectedItemData.bcoItem
    then
        return self.lastSelectedItemData
    end

    if self.firstItemEntryData
        and self.firstItemEntryData.bcoItem
    then
        self.lastSelectedItemData =
            self.firstItemEntryData
        return self.firstItemEntryData
    end

    return nil
end

function BCO:ResolveFurnishingPreviewSlot(dataOrItem)
    local data = dataOrItem
        and dataOrItem.bcoItem
        and dataOrItem
        or nil
    local item = data and data.bcoItem or dataOrItem

    if not item then
        return nil, nil
    end

    if data
        and data.bcoPreviewBagId ~= nil
        and data.bcoPreviewSlotIndex ~= nil
    then
        if type(CanInventoryItemBePreviewed)
            ~= "function"
        then
            return data.bcoPreviewBagId,
                data.bcoPreviewSlotIndex
        end

        local ok, canPreview = pcall(
            CanInventoryItemBePreviewed,
            data.bcoPreviewBagId,
            data.bcoPreviewSlotIndex
        )

        if ok and canPreview then
            return data.bcoPreviewBagId,
                data.bcoPreviewSlotIndex
        end

        data.bcoPreviewBagId = nil
        data.bcoPreviewSlotIndex = nil
    end

    local bagId, slotIndex =
        self:FindLiveFurnishingPreviewSlot(item)

    if data and bagId ~= nil and slotIndex ~= nil then
        data.bcoPreviewBagId = bagId
        data.bcoPreviewSlotIndex = slotIndex
    end

    return bagId, slotIndex
end

function BCO:IsFurnishingPreviewActive()
    -- Once ESO has confirmed the initial preview, keep the mode active while
    -- the selected furnishing is being replaced. The native collection can
    -- report false for a frame during that replacement on console.
    if self.furnishingPreviewConfirmed then
        return true
    end

    if type(IsCurrentlyPreviewing) == "function" then
        local ok, active = pcall(IsCurrentlyPreviewing)

        if ok then
            return active == true
        end
    end

    return false
end

function BCO:CanPreviewFurnishing(dataOrItem)
    local item = dataOrItem
        and dataOrItem.bcoItem
        or dataOrItem

    if not item
        or not IsFurnishing(item)
        or not item.itemLink
        or item.itemLink == ""
    then
        return false
    end

    if type(IsCharacterPreviewingAvailable) == "function" then
        local ok, available = pcall(
            IsCharacterPreviewingAvailable
        )

        if ok and not available then
            return false
        end
    end

    -- This runs from the keybind strip's visible() callback on every
    -- selection change and keybind refresh, so it must stay cheap: decide
    -- from the item link alone and leave the live-slot lookup to the
    -- actual preview request. The item-link preview path is the primary
    -- one on Update 50 anyway; the slot path is only a fallback.
    if type(PreviewItemLink) == "function" then
        local cached = rawget(item, "bcoCanPreviewLink")

        if cached == nil then
            cached = CanPreviewItemLinkAsFurniture(item.itemLink)
            item.bcoCanPreviewLink = cached
        end

        if cached then
            return true
        end
    end

    -- Clients without item-link previewing need a live bag slot. Cached
    -- on the row data by ResolveFurnishingPreviewSlot, and misses are
    -- remembered on the item, so the bag walk happens at most once.
    local bagId, slotIndex =
        self:ResolveFurnishingPreviewSlot(dataOrItem)

    return bagId ~= nil and slotIndex ~= nil
end

function BCO:PreviewFurnishing(
    item,
    resolvedBagId,
    resolvedSlotIndex
)
    if not item
        or not IsFurnishing(item)
        or not item.itemLink
        or item.itemLink == ""
    then
        return false
    end

    if type(IsCharacterPreviewingAvailable) == "function" then
        local ok, available = pcall(
            IsCharacterPreviewingAvailable
        )

        if ok and not available then
            return false
        end
    end

    local bagId = resolvedBagId
    local slotIndex = resolvedSlotIndex

    if bagId == nil or slotIndex == nil then
        bagId, slotIndex =
            self:ResolveFurnishingPreviewSlot(item)
    end

    local previewObject = GetItemPreviewObject()
    if not previewObject then
        return false
    end

    local wasPreviewActive =
        self:IsFurnishingPreviewActive()

    -- Duplicate target callbacks are common in parametric gamepad lists.
    if self.previewingFurnishingItemLink
            == item.itemLink
        and self:IsFurnishingPreviewActive()
    then
        return true
    end

    local previewBufferEnabled =
        self:SetFurnishingPreviewBuffer(true)
    local requested = false
    local usedItemLink = false
    local canUseItemLink =
        type(PreviewItemLink) == "function"
        and CanPreviewItemLinkAsFurniture(item.itemLink)

    local function PreviewActiveItemLink(path)
        usedItemLink = true

        -- The item-link path is the only replacement path observed to keep
        -- the PS5 preview scene continuously rendered. Use it for every
        -- already-open preview, including furnishings that also have a live
        -- backpack, bank, housing-storage, or Furnishing Vault slot.
        if GAMEPAD_INVENTORY then
            GAMEPAD_INVENTORY.currentPreviewBagId = nil
            GAMEPAD_INVENTORY.currentPreviewSlotIndex = nil
        end

        ClearPendingPreviewCollection(previewObject)

        local accepted = TryFurnishingPreviewCall(
            path,
            PreviewItemLink,
            item.itemLink,
            0
        )

        if accepted then
            CommitPendingPreviewCollection()
        end

        return accepted
    end

    if wasPreviewActive and canUseItemLink then
        -- Do not use PreviewInventoryItem while scrolling. Even its direct
        -- pending-collection form briefly exposes the character model for
        -- live slots on PS5. Item-link replacement has already proven
        -- seamless for snapshot-only furnishings, and the same item link is
        -- valid for live items as well.
        requested = PreviewActiveItemLink(
            bagId ~= nil
                and "live-active-item-link"
                or "remote-active-item-link"
        )

        if not requested
            and bagId ~= nil
            and slotIndex ~= nil
            and type(PreviewInventoryItem) == "function"
        then
            -- Keep slot previewing only as a compatibility fallback so an
            -- unusual client API restriction cannot break live previews.
            usedItemLink = false
            ClearPendingPreviewCollection(previewObject)
            requested = TryFurnishingPreviewCall(
                "live-active-slot-fallback",
                PreviewInventoryItem,
                bagId,
                slotIndex
            )

            if requested then
                CommitPendingPreviewCollection()
            elseif type(previewObject.PreviewInventoryItem)
                == "function"
            then
                requested = TryFurnishingPreviewCall(
                    "live-active-shared-fallback",
                    previewObject.PreviewInventoryItem,
                    previewObject,
                    bagId,
                    slotIndex
                )
            end

            if GAMEPAD_INVENTORY then
                GAMEPAD_INVENTORY.currentPreviewBagId =
                    bagId
                GAMEPAD_INVENTORY.currentPreviewSlotIndex =
                    slotIndex
            end
        end
    elseif canUseItemLink then
        -- Open every furnishing preview through the same item-link preview
        -- type used by snapshot-only items. Previously live items opened as
        -- inventory-slot previews, so the first scroll had to change preview
        -- types before later item-link replacements could become seamless.
        usedItemLink = true

        if GAMEPAD_INVENTORY then
            GAMEPAD_INVENTORY.currentPreviewBagId = nil
            GAMEPAD_INVENTORY.currentPreviewSlotIndex = nil
        end

        if type(previewObject.PreviewItemLink)
            == "function"
        then
            requested = TryFurnishingPreviewCall(
                bagId ~= nil
                    and "live-initial-item-link-shared"
                    or "remote-initial-item-link-shared",
                previewObject.PreviewItemLink,
                previewObject,
                item.itemLink,
                0
            )
        end

        if not requested then
            ClearPendingPreviewCollection(previewObject)
            requested = TryFurnishingPreviewCall(
                bagId ~= nil
                    and "live-initial-item-link-direct"
                    or "remote-initial-item-link-direct",
                PreviewItemLink,
                item.itemLink,
                0
            )

            if requested then
                CommitPendingPreviewCollection()
            end
        end

        if not requested
            and bagId ~= nil
            and slotIndex ~= nil
        then
            -- Item-link previewing is expected on Update 50, but preserve a
            -- live-slot escape hatch for console builds that restrict either
            -- item-link entry point to secure code.
            usedItemLink = false

            if GAMEPAD_INVENTORY
                and type(GAMEPAD_INVENTORY.PreviewInventoryItem)
                    == "function"
            then
                requested = TryFurnishingPreviewCall(
                    "live-initial-native-fallback",
                    GAMEPAD_INVENTORY.PreviewInventoryItem,
                    GAMEPAD_INVENTORY,
                    bagId,
                    slotIndex
                )
            elseif type(previewObject.PreviewInventoryItem)
                == "function"
            then
                ClearPendingPreviewCollection(previewObject)
                requested = TryFurnishingPreviewCall(
                    "live-initial-shared-fallback",
                    previewObject.PreviewInventoryItem,
                    previewObject,
                    bagId,
                    slotIndex
                )
            end
        end
    elseif bagId ~= nil and slotIndex ~= nil then
        -- Legacy fallback for clients that expose slot previewing but no
        -- item-link preview API at all.
        if GAMEPAD_INVENTORY
            and type(GAMEPAD_INVENTORY.PreviewInventoryItem)
                == "function"
        then
            requested = TryFurnishingPreviewCall(
                "live-initial-native-legacy",
                GAMEPAD_INVENTORY.PreviewInventoryItem,
                GAMEPAD_INVENTORY,
                bagId,
                slotIndex
            )
        elseif type(previewObject.PreviewInventoryItem)
            == "function"
        then
            ClearPendingPreviewCollection(previewObject)
            requested = TryFurnishingPreviewCall(
                "live-initial-shared-legacy",
                previewObject.PreviewInventoryItem,
                previewObject,
                bagId,
                slotIndex
            )
        end
    end

    if requested then
        self.previewingFurnishingItemLink =
            item.itemLink
        self.previewingFurnishingItemKey = item.key
        self.previewingFurnishingBagId = bagId
        self.previewingFurnishingSlotIndex = slotIndex
        self.previewingFurnishingUsesItemLink =
            usedItemLink

        if wasPreviewActive then
            self.furnishingPreviewConfirmed = true
            self:RefreshItemKeybinds()
        elseif type(zo_callLater) == "function" then
            local requestedItemLink = item.itemLink

            zo_callLater(function()
                if BCO.previewingFurnishingItemLink
                    ~= requestedItemLink
                then
                    return
                end

                local nativeActive = false

                if type(IsCurrentlyPreviewing)
                    == "function"
                then
                    local ok, active = pcall(
                        IsCurrentlyPreviewing
                    )
                    nativeActive = ok and active == true
                else
                    nativeActive =
                        BCO.previewingFurnishingItemLink
                            ~= nil
                end

                if nativeActive then
                    BCO.furnishingPreviewConfirmed = true
                else
                    -- A low-level item-link preview can be accepted before the
                    -- gamepad preview scene is ready. Retry through any shared
                    -- object method that Update 50 exposes, then keep the mode
                    -- only if ESO confirms it.
                    local retried = false
                    local object = GetItemPreviewObject()

                    if usedItemLink
                        and object
                        and type(object.PreviewItemLink)
                            == "function"
                    then
                        retried = TryFurnishingPreviewCall(
                            "item-link-confirmation-retry",
                            object.PreviewItemLink,
                            object,
                            requestedItemLink,
                            0
                        )
                    end

                    if retried then
                        zo_callLater(function()
                            local retryActive = false

                            if type(IsCurrentlyPreviewing)
                                == "function"
                            then
                                local ok, active = pcall(
                                    IsCurrentlyPreviewing
                                )
                                retryActive = ok
                                    and active == true
                            end

                            if retryActive then
                                BCO.furnishingPreviewConfirmed = true
                            else
                                BCO.previewingFurnishingItemLink = nil
                                BCO.previewingFurnishingItemKey = nil
                                BCO.previewingFurnishingBagId = nil
                                BCO.previewingFurnishingSlotIndex = nil
                                BCO.previewingFurnishingUsesItemLink = nil
                                BCO.furnishingPreviewConfirmed = false
                                BCO:SetFurnishingPreviewBuffer(false)
                            end

                            BCO:RefreshItemKeybinds()
                        end, 100)
                        return
                    end

                    BCO.previewingFurnishingItemLink = nil
                    BCO.previewingFurnishingItemKey = nil
                    BCO.previewingFurnishingBagId = nil
                    BCO.previewingFurnishingSlotIndex = nil
                    BCO.previewingFurnishingUsesItemLink = nil
                    BCO.furnishingPreviewConfirmed = false
                    BCO:SetFurnishingPreviewBuffer(false)
                end

                BCO:RefreshItemKeybinds()
            end, 100)
        end
    end

    if not requested
        and not wasPreviewActive
        and previewBufferEnabled
    then
        self:SetFurnishingPreviewBuffer(false)
    end

    return requested
end

function BCO:EndFurnishingPreview()
    self.previewSelectionGeneration =
        self.previewSelectionGeneration + 1

    local hadActivePreview =
        self.previewingFurnishingItemLink ~= nil
        or self:IsFurnishingPreviewActive()

    -- Restore the shared preview object's default unbuffered behavior even
    -- after a failed or externally closed preview.
    self:SetFurnishingPreviewBuffer(false)

    if not hadActivePreview then
        return false
    end

    local endedNatively = false

    if GAMEPAD_INVENTORY
        and type(GAMEPAD_INVENTORY.EndPreview)
            == "function"
    then
        endedNatively = pcall(
            GAMEPAD_INVENTORY.EndPreview,
            GAMEPAD_INVENTORY
        )
    end

    if not endedNatively then
        local previewObject = GetItemPreviewObject()

        if previewObject
            and type(previewObject.ClearPreviewCollection)
                == "function"
        then
            pcall(
                previewObject.ClearPreviewCollection,
                previewObject
            )
        end

        if type(ApplyChangesToPreviewCollectionShown)
            == "function"
        then
            pcall(ApplyChangesToPreviewCollectionShown)
        end
    end

    self.previewingFurnishingItemLink = nil
    self.previewingFurnishingItemKey = nil
    self.previewingFurnishingBagId = nil
    self.previewingFurnishingSlotIndex = nil
    self.previewingFurnishingUsesItemLink = nil
    self.furnishingPreviewConfirmed = false
    self.lastFurnishingPreviewPath = "ended"

    return true
end

function BCO:UpdateActiveFurnishingPreview(selectedData)
    if not self:IsFurnishingPreviewActive() then
        return
    end

    local targetData = self.itemList
        and self.itemList:GetTargetData()
        or selectedData
    local settledData =
        self:GetSelectedItemData(targetData)
    local item = settledData
        and settledData.bcoItem

    if not item or not IsFurnishing(item) then
        return
    end

    local bagId, slotIndex =
        self:ResolveFurnishingPreviewSlot(settledData)

    self:PreviewFurnishing(
        item,
        bagId,
        slotIndex
    )
end

function BCO:ScheduleActiveFurnishingPreview(selectedData)
    if not self:IsFurnishingPreviewActive() then
        return
    end

    self.previewSelectionGeneration =
        self.previewSelectionGeneration + 1

    local generation =
        self.previewSelectionGeneration
    local settleMilliseconds =
        self.furnishingPreviewSettleMS or 90

    if type(zo_callLater) ~= "function" then
        self:UpdateActiveFurnishingPreview(selectedData)
        return
    end

    -- While a stick/d-pad is held, target callbacks arrive faster than a
    -- furnishing can be prepared. Keep the old model visible and request only
    -- the row where scrolling settles instead of flashing through every row.
    zo_callLater(function()
        if generation
                ~= BCO.previewSelectionGeneration
            or not BCO.active
            or not BCO:IsFurnishingPreviewActive()
        then
            return
        end

        BCO:UpdateActiveFurnishingPreview(
            selectedData
        )
    end, settleMilliseconds)
end

function BCO:HandleItemSelectionChanged(selectedData)
    if not self.active
        or not GAMEPAD_INVENTORY
        or GAMEPAD_INVENTORY:GetCurrentList()
            ~= self.itemList
    then
        return
    end

    local targetData = self.itemList
        and self.itemList:GetTargetData()
        or selectedData
    local settledData =
        self:GetSelectedItemData(targetData)

    if settledData and settledData.bcoItem then
        self.lastSelectedItemData = settledData
    end

    -- Keep BCO snapshot rows completely separate from ESO's native
    -- currentlySelectedData field. Native inventory events feed that field
    -- into the protected item-action controller even when the active list is
    -- a custom list.
    self.lastSelectedItemData = settledData

    self:ScheduleActiveFurnishingPreview(
        settledData
    )
    -- The keybind strip is already refreshed by the native
    -- SelectedDataChanged/TargetDataChanged closures that
    -- ZO_Gamepad_ParametricList_Screen attached when the list was created
    -- (they call self:RefreshKeybinds on the active descriptor, which is
    -- BCO's while a BCO list is current), so no extra pass is needed here.
    self:ScheduleItemTooltip(settledData)
end

function BCO:RefreshItemKeybinds()
    if not self.itemKeybinds then
        return
    end

    if KEYBIND_STRIP
        and type(KEYBIND_STRIP.UpdateKeybindButtonGroup)
            == "function"
    then
        pcall(
            KEYBIND_STRIP.UpdateKeybindButtonGroup,
            KEYBIND_STRIP,
            self.itemKeybinds
        )
    end
end

function BCO:ScheduleItemKeybindRefresh()
    self.itemKeybindRefreshGeneration =
        (self.itemKeybindRefreshGeneration or 0) + 1

    local generation =
        self.itemKeybindRefreshGeneration
    -- SetActiveKeybinds already evaluated the group once synchronously;
    -- only the late settling pass remains.
    local delays = { 200 }

    for index = 1, #delays do
        zo_callLater(function()
            if generation
                    ~= BCO.itemKeybindRefreshGeneration
                or not BCO.active
                or not GAMEPAD_INVENTORY
                or GAMEPAD_INVENTORY:GetCurrentList()
                    ~= BCO.itemList
            then
                return
            end

            -- The first row is selected while the custom list is becoming
            -- active. On PS5 its target data can arrive after the keybind
            -- group was initially evaluated, so refresh it over the same
            -- short settling window used by the tooltip.
            BCO:RefreshItemKeybinds()
        end, delays[index])
    end
end

function BCO:CollapseLocationView(refreshTooltip)
    local wasExpanded = self.locationViewExpanded

    self.locationViewExpanded = false
    self.expandedLocationItemKey = nil

    if wasExpanded then
        SetLocationTooltipInputEnabled(false)
        self:RefreshItemKeybinds()
    end

    if refreshTooltip
        and self.active
        and GAMEPAD_INVENTORY
        and GAMEPAD_INVENTORY:GetCurrentList()
            == self.itemList
    then
        self:ScheduleItemTooltip(
            self.itemList:GetTargetData()
        )
    end
end

function BCO:SetLocationViewExpanded(
    expanded,
    selectedData
)
    local item = selectedData
        and selectedData.bcoItem

    if not item then
        return
    end

    if expanded
        and LocationCount(item)
            <= self.collapsedLocationRows
    then
        return
    end

    self.locationViewExpanded = expanded == true
    self.expandedLocationItemKey =
        self.locationViewExpanded
        and item.key
        or nil

    SetLocationTooltipInputEnabled(
        self.locationViewExpanded
    )

    self.tooltipRefreshGeneration =
        self.tooltipRefreshGeneration + 1

    self:UpdateItemTooltip(selectedData)
    self:RefreshItemKeybinds()
end

function BCO:RenderExpandedLocationTooltip(item)
    local locationText, locationCount =
        ExpandedLocationText(item)

    if locationCount == 0 then
        return false
    end

    if GAMEPAD_TOOLTIPS.ClearStatusLabel then
        pcall(
            GAMEPAD_TOOLTIPS.ClearStatusLabel,
            GAMEPAD_TOOLTIPS,
            GAMEPAD_LEFT_TOOLTIP
        )
    end

    local rendered = false

    if GAMEPAD_TOOLTIPS.LayoutTitleAndDescriptionTooltip then
        rendered = pcall(
            GAMEPAD_TOOLTIPS.LayoutTitleAndDescriptionTooltip,
            GAMEPAD_TOOLTIPS,
            GAMEPAD_LEFT_TOOLTIP,
            "ITEM LOCATIONS",
            locationText
        )
    elseif GAMEPAD_TOOLTIPS.LayoutTextBlockTooltip then
        rendered = pcall(
            GAMEPAD_TOOLTIPS.LayoutTextBlockTooltip,
            GAMEPAD_TOOLTIPS,
            GAMEPAD_LEFT_TOOLTIP,
            "ITEM LOCATIONS\n\n" .. locationText
        )
    end

    if not rendered then
        local tooltipInfo =
            GAMEPAD_TOOLTIPS.tooltips
            and GAMEPAD_TOOLTIPS.tooltips[
                GAMEPAD_LEFT_TOOLTIP
            ]

        local tip = tooltipInfo
            and tooltipInfo.control
            and tooltipInfo.control.container
            and tooltipInfo.control.container.tip

        if tip
            and type(tip.LayoutTitleAndDescriptionTooltip)
                == "function"
        then
            rendered = pcall(
                tip.LayoutTitleAndDescriptionTooltip,
                tip,
                "ITEM LOCATIONS",
                locationText
            )
        elseif tip
            and tip.tooltip
            and type(
                tip.tooltip.LayoutTitleAndDescriptionTooltip
            ) == "function"
        then
            rendered = pcall(
                tip.tooltip.LayoutTitleAndDescriptionTooltip,
                tip.tooltip,
                "ITEM LOCATIONS",
                locationText
            )
        end
    end

    ForceTooltipControlVisible(
        GAMEPAD_LEFT_TOOLTIP
    )

    SetLocationTooltipInputEnabled(true)

    if GAMEPAD_TOOLTIPS.ResetScrollTooltipToTop then
        GAMEPAD_TOOLTIPS:ResetScrollTooltipToTop(
            GAMEPAD_LEFT_TOOLTIP
        )
    end

    return rendered
end

function BCO:UpdateItemTooltip(selectedData)
    if not GAMEPAD_TOOLTIPS then
        return false
    end

    GAMEPAD_TOOLTIPS:ClearTooltip(
        GAMEPAD_LEFT_TOOLTIP
    )
    GAMEPAD_TOOLTIPS:ClearTooltip(
        GAMEPAD_RIGHT_TOOLTIP
    )

    local item = selectedData and selectedData.bcoItem
    if not item
        or not item.itemLink
        or item.itemLink == ""
    then
        self.renderedItemTooltipKey = nil
        -- Keep the shared left-tooltip scroll input at ESO's enabled default
        -- even for an empty row. An empty tooltip has no scroll extents, so
        -- ESO leaves the right-stick handler dormant on its own; disabling the
        -- input here previously leaked out and blocked scrolling elsewhere.
        SetLocationTooltipInputEnabled(true)
        return false
    end

    -- Record which item the left tooltip is showing (used by the /bcoscroll
    -- diagnostic to confirm BCO, not native, rendered the visible tooltip).
    self.renderedItemTooltipKey = item.key

    if self.locationViewExpanded
        and self.expandedLocationItemKey ~= item.key
    then
        self:CollapseLocationView(false)
    end

    if self.locationViewExpanded then
        return self:RenderExpandedLocationTooltip(item)
    end

    if GAMEPAD_TOOLTIPS.ResetScrollTooltipToTop then
        GAMEPAD_TOOLTIPS:ResetScrollTooltipToTop(
            GAMEPAD_LEFT_TOOLTIP
        )
    end

    local rendered = false

    -- This is the item-link path used by gamepad loot and other screens
    -- where there is no live bag slot available.
    if GAMEPAD_TOOLTIPS.LayoutItemWithStackCount then
        rendered = pcall(
            GAMEPAD_TOOLTIPS.LayoutItemWithStackCount,
            GAMEPAD_TOOLTIPS,
            GAMEPAD_LEFT_TOOLTIP,
            item.itemLink,
            false,                 -- not equipped
            nil,                   -- no creator name
            true,                  -- full durability
            nil,                   -- no preview value
            item.totalCount or 1
        )
    end

    if not rendered
        and GAMEPAD_TOOLTIPS.LayoutItemLink
    then
        rendered = pcall(
            GAMEPAD_TOOLTIPS.LayoutItemLink,
            GAMEPAD_TOOLTIPS,
            GAMEPAD_LEFT_TOOLTIP,
            item.itemLink
        )
    end

    -- Console fallback: call the concrete tooltip control directly.
    if not rendered then
        local tooltipInfo =
            GAMEPAD_TOOLTIPS.tooltips
            and GAMEPAD_TOOLTIPS.tooltips[
                GAMEPAD_LEFT_TOOLTIP
            ]

        local tip = tooltipInfo
            and tooltipInfo.control
            and tooltipInfo.control.container
            and tooltipInfo.control.container.tip

        if tip and type(tip.LayoutItemLink) == "function" then
            rendered = pcall(
                tip.LayoutItemLink,
                tip,
                item.itemLink
            )
        elseif tip
            and tip.tooltip
            and type(tip.tooltip.LayoutItemLink) == "function"
        then
            rendered = pcall(
                tip.tooltip.LayoutItemLink,
                tip.tooltip,
                item.itemLink
            )
        end
    end

    ForceTooltipControlVisible(
        GAMEPAD_LEFT_TOOLTIP
    )

    -- Category mode and scene shutdown disable tooltip input. Item-link
    -- layout does not reliably enable it again on console, so explicitly
    -- restore the standard right-stick scroll handler for ordinary BCO item
    -- tooltips just as the Currencies and expanded Locations views do.
    SetLocationTooltipInputEnabled(true)

    local locationStatusText =
        LocationStatusText(item)

    if locationStatusText ~= ""
        and GAMEPAD_TOOLTIPS.SetStatusLabelText
    then
        GAMEPAD_TOOLTIPS:SetStatusLabelText(
            GAMEPAD_LEFT_TOOLTIP,
            locationStatusText,
            ""
        )
    end

    return rendered
end

-- One short settle timer per selection change. While the stick is held the
-- list reports a new target every frame; each call bumps the generation and
-- cancels the previous timer, so only the row the player stops on is laid
-- out (a full item tooltip layout is one of the more expensive UI
-- operations available). A single late confirmation pass covers the first
-- row's target data arriving late on PS5; it re-lays only if the target
-- row differs from what was drawn.
BCO.tooltipSettleMS = 60
BCO.tooltipConfirmMS = 200

function BCO:ScheduleItemTooltip(selectedData)
    self.tooltipRefreshGeneration =
        self.tooltipRefreshGeneration + 1

    local generation = self.tooltipRefreshGeneration
    local pendingData = selectedData
    local renderedData = nil

    local function IsStale()
        return generation ~= BCO.tooltipRefreshGeneration
            or not BCO.active
            or not GAMEPAD_INVENTORY
            or GAMEPAD_INVENTORY:GetCurrentList()
                ~= BCO.itemList
    end

    local function Render()
        local currentData =
            BCO.itemList:GetTargetData()
            or pendingData

        if currentData == renderedData then
            return
        end

        if BCO:UpdateItemTooltip(currentData) then
            renderedData = currentData
        end
    end

    zo_callLater(function()
        if IsStale() then
            return
        end

        Render()

        zo_callLater(function()
            if IsStale() then
                return
            end

            Render()
        end, BCO.tooltipConfirmMS)
    end, BCO.tooltipSettleMS)
end

function BCO:RefreshCategoryList(
    selectDefault,
    preferredCategoryKey
)
    local list = self.categoryList
    list:Clear()

    -- Kick off (or continue) the aggregate build; the loading row below
    -- stays until StartIndexBuild's completion callback refreshes this list.
    self:EnsureIndex()

    if not self.indexReady then
        local loading = ZO_GamepadEntryData:New(
            "Building account inventory...",
            nil
        )
        loading.bcoKey = "loading"
        loading.bcoLoading = true

        list:AddEntry(
            "ZO_GamepadItemEntryTemplate",
            loading
        )

        list:Commit()
        return
    end

    if self:GetInventoryFilterKey() == "storage"
        and not self:HasStorageSnapshots()
    then
        if list.SetNoItemText then
            list:SetNoItemText(
                "Open each housing storage container or visit an owned house once to add it to All Inventories."
            )
        end

        list:Commit()
        return
    end

    if self:GetInventoryFilterKey() == "listings"
        and not self:HasListingSnapshots()
    then
        if list.SetNoItemText then
            list:SetNoItemText(
                "Visit a guild trader or banker once to record your guild store listings."
            )
        end

        list:Commit()
        return
    end

    local visibleCategories = {}
    local searchHits = nil

    if self.searchText ~= "" then
        searchHits = self:ComputeCategorySearchHits(
            self.searchText
        )
    end

    for index = 1, #self.categories do
        local category = self.categories[index]

        if category.key == "currencies"
            or not searchHits
            or searchHits[category.key]
        then
            visibleCategories[
                #visibleCategories + 1
            ] = {
                category = category,
                originalIndex = index,
            }
        end
    end

    for visibleIndex = 1, #visibleCategories do
        local entry =
            visibleCategories[visibleIndex]
        local category = entry.category

        local data = ZO_GamepadEntryData:New(
            category.name,
            self.categoryIcons[category.key]
        )

        data.bcoKey = category.key
        data.bcoCurrencyEntry =
            category.key == "currencies"
        data.bcoCategoryIndex =
            entry.originalIndex
        data.bcoOfflineEntry = true
        data.overrideStatusIndicatorIcons =
            EMPTY_STATUS_INDICATOR_ICONS

        if data.SetIconTintOnSelection then
            data:SetIconTintOnSelection(true)
        end

        list:AddEntry(
            "ZO_GamepadItemEntryTemplate",
            data
        )
    end

    if list.SetNoItemText then
        if self.searchText ~= "" then
            list:SetNoItemText(
                "No saved items match this search."
            )
        else
            list:SetNoItemText(
                "No saved inventory data."
            )
        end
    end

    list:Commit()

    if selectDefault
        and list.SetSelectedIndexWithoutAnimation
        and #visibleCategories > 0
    then
        local selectedIndex = 1

        if preferredCategoryKey then
            for index = 1, #visibleCategories do
                if visibleCategories[index]
                    .category.key
                    == preferredCategoryKey
                then
                    selectedIndex = index
                    break
                end
            end
        end

        list:SetSelectedIndexWithoutAnimation(
            selectedIndex
        )
    end
end

function BCO:RefreshItemList(
    selectDefault,
    preferredItemKey
)
    self:CollapseLocationView(false)

    local list = self.itemList
    list:Clear()
    self.firstItemEntryData = nil

    local categoryData = self.categoryList:GetTargetData()

    self.selectedCategoryKey =
        categoryData
        and categoryData.bcoKey
        or self.selectedCategoryKey
        or "all"

    -- Save the selected title before the category list becomes inactive.
    -- On console, GetTargetData() is not guaranteed to remain available after
    -- switching to the dedicated item list.
    self.selectedCategoryName = "ALL INVENTORIES"

    for index = 1, #self.categories do
        local category = self.categories[index]

        if category.key == self.selectedCategoryKey then
            self.selectedCategoryName = category.name
            break
        end
    end

    if categoryData and categoryData.bcoCategoryIndex then
        self.savedVars.settings.categoryIndex =
            categoryData.bcoCategoryIndex
    end

    local items = self:FilterItems(
        self.selectedCategoryKey
    )

    local sectionedRows =
        BuildSectionedItemRows(
            items,
            self.selectedCategoryKey
        )
    local previousSectionName = nil

    for index = 1, #sectionedRows do
        local row = sectionedRows[index]
        local item = row.item

        -- Reuse the row object across refreshes. A ZO_GamepadEntryData is
        -- ~1.3 KB; rebuilding every row for a few thousand items on each
        -- inventory event was several MB of garbage per refresh. Rows are
        -- cached on the item (or its filtered view) and released with the
        -- aggregate when Inventory closes. Only the fields that can change
        -- between refreshes are rewritten below.
        local data = rawget(item, "bcoEntryData")

        if not data then
            data = ZO_GamepadEntryData:New(
                item.name,
                item.icon
            )

            data.displayQuality =
                item.quality
                or ITEM_DISPLAY_QUALITY_NORMAL

            if data.SetNameColors
                and data.GetColorsBasedOnQuality
            then
                data:SetNameColors(
                    data:GetColorsBasedOnQuality(
                        data.displayQuality
                    )
                )
            elseif data.SetNameColors
                and GetItemQualityColor
            then
                local qualityColor =
                    GetItemQualityColor(
                        data.displayQuality
                    )

                data:SetNameColors(
                    qualityColor,
                    qualityColor
                )
            end

            data.bcoKey = item.key
            data.bcoItem = item
            data.bcoOfflineEntry = true
            data.itemLink = item.itemLink
            data.overrideStatusIndicatorIcons =
                EMPTY_STATUS_INDICATOR_ICONS

            item.bcoEntryData = data
        end

        data.stackCount = item.totalCount
        data.bestItemCategoryName =
            row.sectionName

        if index == 1 then
            self.firstItemEntryData = data
        end

        if row.sectionName ~= previousSectionName then
            previousSectionName =
                row.sectionName

            data:SetHeader(
                row.sectionName
            )

            list:AddEntry(
                "ZO_GamepadItemSubEntryTemplateWithHeader",
                data
            )
        else
            data.header = nil

            list:AddEntry(
                "ZO_GamepadItemSubEntryTemplate",
                data
            )
        end
    end

    if list.SetNoItemText then
        if self.searchText ~= "" then
            list:SetNoItemText(
                "No items in this category match the search."
            )
        elseif self:GetInventoryFilterKey() == "storage"
            and not self:HasStorageSnapshots()
        then
            list:SetNoItemText(
                "Open each housing storage container or visit an owned house once to add it to All Inventories."
            )
        elseif self:GetInventoryFilterKey() == "storage" then
            list:SetNoItemText(
                "No saved storage items in this category."
            )
        elseif self:GetInventoryFilterKey() == "listings"
            and not self:HasListingSnapshots()
        then
            list:SetNoItemText(
                "Visit a guild trader or banker once to record your guild store listings."
            )
        elseif self:GetInventoryFilterKey() == "listings" then
            list:SetNoItemText(
                "No guild store listings in this category."
            )
        else
            list:SetNoItemText(
                "No saved items in this category."
            )
        end
    end

    list:Commit()

    if selectDefault
        and list.SetSelectedIndexWithoutAnimation
        and #items > 0
    then
        local selectedIndex = 1

        if preferredItemKey then
            for index = 1, #sectionedRows do
                if sectionedRows[index].item.key
                    == preferredItemKey
                then
                    selectedIndex = index
                    break
                end
            end
        end

        list:SetSelectedIndexWithoutAnimation(
            selectedIndex
        )
    end

    local targetData = list:GetTargetData()
        or self.firstItemEntryData

    if targetData and targetData.bcoItem then
        self.lastSelectedItemData = targetData
    end
end

function BCO:RefreshActiveBCOList(selectDefault)
    if not self.active or not GAMEPAD_INVENTORY then
        return
    end

    local current = GAMEPAD_INVENTORY:GetCurrentList()

    if current == self.categoryList then
        self:RefreshCategoryList(selectDefault)
    elseif current == self.itemList then
        self:RefreshItemList(selectDefault)
    end
end

function BCO:RefreshBCOHeader(blockCallback, onlyIfStale)
    if not GAMEPAD_INVENTORY or not GAMEPAD_INVENTORY.header then
        return
    end

    local current = GAMEPAD_INVENTORY:GetCurrentList()
    local data

    if current == self.categoryList then
        data = self.categoryHeaderData
    elseif current == self.itemList then
        data = self.itemHeaderData
    else
        return
    end

    GAMEPAD_INVENTORY.headerData = data

    -- The native RefreshHeader that triggered this was skipped by the
    -- header pre-hook (InstallHeaderTabInjection), so the controls still
    -- show BCO's last draw; only the headerData field needed restoring.
    if onlyIfStale and self.lastDrawnHeaderData == data then
        return
    end

    self.lastDrawnHeaderData = data

    ZO_GamepadGenericHeader_Refresh(
        GAMEPAD_INVENTORY.header,
        data,
        blockCallback
    )

    -- GenericHeader rebuilds its tab list during every refresh and normally
    -- retains the previously selected native tab index. When BCO is restored
    -- after the Inventory scene reopens, that stale index can point at Craft
    -- Bag while BCO's title is already visible. Re-select BCO's own tab with
    -- callbacks blocked so the title text and divider pip remain in sync.
    if current == self.categoryList then
        self:SyncBCOTabSelection(data)
    end
end

function BCO:ActivateCategoryList(selectDefault)
    self:EndFurnishingPreview()
    self:CollapseLocationView(false)

    local inventory = GAMEPAD_INVENTORY

    self.searchText = self:ReadSearchText()
    if not inventory or not inventory.scene:IsShowing() then
        return
    end

    self.active = true

    if inventory:IsHeaderActive() then
        inventory:RequestLeaveHeader()
    end

    inventory.previousListType =
        inventory.currentListType
    inventory.currentListType =
        self.CATEGORY_DESCRIPTOR

    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)

    inventory:SetCurrentList(self.categoryList)
    self:RefreshCategoryList(selectDefault)
    inventory:SetActiveKeybinds(
        self.categoryKeybinds
    )
    self:ApplyReadOnlyInventoryState(inventory)

    self:RefreshBCOHeader(true)
    inventory:ActivateHeader()

    self:UpdateCategoryTooltip(
        self.categoryList:GetTargetData()
    )
end

function BCO:ActivateItemList(selectDefault)
    self:CollapseLocationView(false)

    local categoryData = self.categoryList
        and self.categoryList:GetTargetData()

    if categoryData
        and categoryData.bcoKey == "currencies"
    then
        self:UpdateCategoryTooltip(categoryData)
        return
    end

    local inventory = GAMEPAD_INVENTORY
    if not inventory or not inventory.scene:IsShowing() then
        return
    end

    if inventory:IsHeaderActive() then
        inventory:RequestLeaveHeader()
    end

    inventory.previousListType =
        inventory.currentListType
    inventory.currentListType =
        self.ITEM_DESCRIPTOR

    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)

    self:RefreshItemList(selectDefault)
    inventory:SetCurrentList(self.itemList)

    -- ESO clears its selected inventory data inside SetActiveKeybinds, so the
    -- first row must be assigned after the keybind group has been installed.
    inventory:SetActiveKeybinds(
        self.itemKeybinds
    )
    self:ApplyReadOnlyInventoryState(inventory)

    local selectedData =
        self.itemList:GetTargetData()
        or self.firstItemEntryData

    self.lastSelectedItemData = selectedData

    self:RefreshBCOHeader(true)
    inventory:DeactivateHeader()

    self:HandleItemSelectionChanged(selectedData)
    self:ScheduleItemKeybindRefresh()
end

function BCO:LeaveBCOMode(clearTooltips)
    self:EndFurnishingPreview()
    self:CollapseLocationView(false)
    self.active = false
    self.searchRefreshGeneration =
        self.searchRefreshGeneration + 1
    self.tooltipRefreshGeneration =
        self.tooltipRefreshGeneration + 1
    self.currencyTooltipGeneration =
        self.currencyTooltipGeneration + 1

    self.renderedItemTooltipKey = nil

    -- Restore ESO's default (enabled) left-tooltip scroll input when handing
    -- control back to a native list. The tooltip scroll input is shared across
    -- every left tooltip, and native inventory never disables it -- it relies
    -- on the per-tooltip scroll extents to decide when the right stick scrolls.
    -- Leaving it disabled here silently broke right-stick scrolling on the
    -- native Inventory, Craft Bag, and Vengeance item tooltips after any visit
    -- to All Inventories.
    SetLocationTooltipInputEnabled(true)

    -- When ESO has already completed a native tab switch, its freshly drawn
    -- native tooltips must be preserved. Scene shutdown and direct BCO cleanup
    -- still use the default clearing behavior.
    if clearTooltips ~= false and GAMEPAD_TOOLTIPS then
        GAMEPAD_TOOLTIPS:ClearTooltip(
            GAMEPAD_LEFT_TOOLTIP
        )
        GAMEPAD_TOOLTIPS:ClearTooltip(
            GAMEPAD_RIGHT_TOOLTIP
        )
    end
end

function BCO:IsBCOListCurrent(inventory)
    inventory = inventory or GAMEPAD_INVENTORY

    if not self.active
        or not inventory
        or type(inventory.GetCurrentList) ~= "function"
    then
        return false
    end

    local current = inventory:GetCurrentList()

    return current == self.categoryList
        or current == self.itemList
end

function BCO:IsBCODescriptor(descriptor)
    return descriptor == self.CATEGORY_DESCRIPTOR
        or descriptor == self.ITEM_DESCRIPTOR
end

function BCO:PrepareForInventorySceneHide(inventory)
    inventory = inventory or GAMEPAD_INVENTORY

    -- Before Install() creates the BCO lists, self.categoryList and
    -- self.itemList are nil, so the wasBCO check below would compare
    -- GetCurrentList() (also nil on a freshly loaded UI whose inventory has
    -- not activated a list yet) against nil and wrongly conclude a BCO list
    -- was active. That armed resumeBCOAfterSceneShow on a scene hide that
    -- happened before the addon ever installed, making the first Inventory
    -- open after a reload land on All Inventories. Pre-install there is no
    -- BCO descriptor, list, or mode to clean up, so skip entirely.
    if not self.installed or not inventory then
        return false
    end

    local current

    if type(inventory.GetCurrentList) == "function" then
        local ok, value = pcall(
            inventory.GetCurrentList,
            inventory
        )

        if ok then
            current = value
        end
    end

    local currentDescriptor =
        inventory.currentListType
    local previousDescriptor =
        inventory.previousListType

    local wasBCO = self.active
        or current == self.categoryList
        or current == self.itemList
        or self:IsBCODescriptor(
            currentDescriptor
        )
        or (
            currentDescriptor == nil
            and self:IsBCODescriptor(
                previousDescriptor
            )
        )

    if not wasBCO then
        return false
    end

    -- Clear the stale All Inventories tab index before the scene hides so the
    -- next open cannot clamp it onto Craft Bag (see ResetNativeTabToInventory).
    self:ResetNativeTabToInventory()

    -- The player closed the Inventory while on All Inventories, so mirror
    -- ESO's native tab persistence (Craft Bag reopens on Craft Bag) by
    -- resuming BCO after the next scene show. This flag is only armed here,
    -- behind the wasBCO check, so closing on a native tab never resumes BCO.
    self.resumeBCOAfterSceneShow = true

    -- ESO remembers currentListType as previousListType while the scene hides
    -- and reuses that descriptor the next time Inventory opens. Its native
    -- SwitchActiveList only recognizes categoryList, itemList, and
    -- craftBagList, so persisting a BCO descriptor reopens an unactivated
    -- custom list with an empty All Inventories header. Normalize to the
    -- native category descriptor and let ScheduleBCOSceneResume re-enter
    -- All Inventories from that clean native state after the scene shows.
    if self:IsBCODescriptor(
        inventory.previousListType
    ) then
        inventory.previousListType =
            self.NATIVE_CATEGORY_DESCRIPTOR
    end

    -- This also covers callback ordering where BCO receives SCENE_HIDING
    -- before ESO has called SwitchActiveList(nil). Leaving currentListType nil
    -- lets ESO reopen through its normal category-list path.
    if self:IsBCODescriptor(
        inventory.currentListType
    ) then
        inventory.currentListType = nil
        inventory.previousListType =
            self.NATIVE_CATEGORY_DESCRIPTOR
    end

    if self.active then
        self:LeaveBCOMode()
    else
        self:EndFurnishingPreview()
        self:CollapseLocationView(false)
    end

    return true
end

-- Frees everything All Inventories keeps only for display: the aggregate
-- and the ZO_GamepadEntryData rows held by the two BCO parametric lists
-- (roughly 1.3 KB per row, and the item list can hold every unique item
-- on the account). Run when the Inventory scene has fully hidden.
function BCO:ReleaseSceneResources()
    self:ReleaseIndex()

    for _, list in ipairs({ self.categoryList, self.itemList }) do
        if list and type(list.Clear) == "function" then
            pcall(list.Clear, list)
        end
    end

    self.firstItemEntryData = nil
    self.lastSelectedItemData = nil
end

function BCO:ScheduleBCOSceneResume()
    if not self.installed
        or not self.resumeBCOAfterSceneShow
        or self.sceneResumeScheduled
    then
        return false
    end

    self.resumeBCOAfterSceneShow = false
    self.sceneResumeScheduled = true
    self.sceneResumeGeneration =
        self.sceneResumeGeneration + 1

    local generation =
        self.sceneResumeGeneration

    zo_callLater(function()
        if generation ~= BCO.sceneResumeGeneration then
            return
        end

        local inventory = GAMEPAD_INVENTORY
        local scene = inventory and inventory.scene

        if not scene or not scene:IsShowing() then
            BCO.sceneResumeScheduled = false
            BCO.resumeBCOAfterSceneShow = true
            return
        end

        BCO.sceneResumeScheduled = false

        -- ESO has now completed a normal, secure category-list activation.
        -- Re-enter BCO from that known native state rather than asking ESO to
        -- interpret the private BCO descriptor during OnStateChanged.
        BCO:ActivateCategoryList(true)
    end, 0)

    return true
end

function BCO:GetSafeNativeSelection(inventory)
    inventory = inventory or GAMEPAD_INVENTORY

    if not inventory then
        return nil
    end

    local categoryList = inventory.categoryList

    if categoryList
        and type(categoryList.GetTargetData) == "function"
    then
        local ok, data = pcall(
            categoryList.GetTargetData,
            categoryList
        )

        if ok and data and not data.bcoOfflineEntry then
            return data
        end
    end

    local currentData = inventory.currentlySelectedData

    if currentData and not currentData.bcoOfflineEntry then
        return currentData
    end

    -- ESO's currency-update callback expects currentlySelectedData to be a
    -- table while the Inventory scene is visible. This inert category-like
    -- placeholder is never exposed as a BCO row and produces no item actions.
    self.safeNativeSelection = self.safeNativeSelection or {
        isCurrencyEntry = false,
        bcoReadOnlyPlaceholder = true,
    }

    return self.safeNativeSelection
end

function BCO:ApplyReadOnlyInventoryState(inventory)
    inventory = inventory or GAMEPAD_INVENTORY

    if not inventory then
        return
    end

    -- Do not let a pending native action refresh run against a custom list.
    inventory.actionMode = self.READ_ONLY_ACTION_MODE
    inventory.updateItemActions = nil

    -- Keep ESO's field populated with genuine native category data rather
    -- than a BCO snapshot. Native currency/death/inventory events may pass
    -- this field back into SetSelectedInventoryData without checking the list
    -- descriptor first.
    inventory.currentlySelectedData =
        self:GetSafeNativeSelection(inventory)
end

-- Native ZO_GamepadInventory:OnUpdate redraws the category tooltip for
-- currentlySelectedData on every dirty tick. BCO keeps that field on an
-- inert placeholder, so the native pass simply clears the left tooltip and
-- this post-hook puts BCO's back. Successive native ticks for the same row
-- are coalesced through the tooltip generations.
function BCO:RestoreBCOTooltipsAfterNativeUpdate()
    if not self:IsBCOListCurrent() then
        return
    end

    local current = GAMEPAD_INVENTORY:GetCurrentList()

    if current == self.categoryList then
        self:UpdateCategoryTooltip(
            self.categoryList:GetTargetData()
        )
    elseif current == self.itemList then
        self:ScheduleItemTooltip(
            self.itemList:GetTargetData()
                or self.lastSelectedItemData
        )
    end
end

function BCO:RefreshCategoryKeybinds()
    if not self.categoryKeybinds then
        return
    end

    if KEYBIND_STRIP
        and type(KEYBIND_STRIP.UpdateKeybindButtonGroup)
            == "function"
    then
        pcall(
            KEYBIND_STRIP.UpdateKeybindButtonGroup,
            KEYBIND_STRIP,
            self.categoryKeybinds
        )
    end
end

function BCO:RefreshCurrentKeybinds()
    if not GAMEPAD_INVENTORY then
        return
    end

    local current =
        GAMEPAD_INVENTORY:GetCurrentList()

    if current == self.categoryList then
        self:RefreshCategoryKeybinds()
    elseif current == self.itemList then
        self:RefreshItemKeybinds()
    end
end

function BCO:CycleInventoryFilter()
    local filters = self.inventoryFilters

    if not filters or #filters == 0 then
        return
    end

    local inventory = GAMEPAD_INVENTORY
    local current = inventory
        and inventory:GetCurrentList()

    if current == self.categoryList then
        local currentData =
            self.categoryList:GetTargetData()

        if currentData
            and currentData.bcoKey == "currencies"
        then
            return
        end
    end

    self.inventoryFilterIndex =
        (self.inventoryFilterIndex % #filters) + 1

    self:CollapseLocationView(false)
    self.searchText = self:ReadSearchText()

    if current == self.categoryList then
        local selectedData =
            self.categoryList:GetTargetData()
        local preferredCategoryKey = selectedData
            and selectedData.bcoKey

        self:RefreshCategoryList(
            true,
            preferredCategoryKey
        )

        self:UpdateCategoryTooltip(
            self.categoryList:GetTargetData()
        )
    elseif current == self.itemList then
        local selectedData =
            self.itemList:GetTargetData()
        local preferredItemKey = selectedData
            and selectedData.bcoKey

        self:RefreshItemList(
            true,
            preferredItemKey
        )

        local refreshedData =
            self.itemList:GetTargetData()

        self.lastSelectedItemData = refreshedData

        self:ScheduleItemTooltip(
            refreshedData
        )
    end

    self:RefreshCurrentKeybinds()

    if SOUNDS and SOUNDS.DEFAULT_CLICK then
        PlaySound(SOUNDS.DEFAULT_CLICK)
    end
end

local function CreateInventoryFilterKeybind()
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = function()
            return BCO:GetInventoryFilterKeybindName()
        end,
        keybind = "UI_SHORTCUT_SECONDARY",
        visible = function()
            if not GAMEPAD_INVENTORY
                or GAMEPAD_INVENTORY:GetCurrentList()
                    ~= BCO.categoryList
            then
                return true
            end

            local data = BCO.categoryList
                and BCO.categoryList:GetTargetData()

            return not data
                or data.bcoKey ~= "currencies"
        end,
        callback = function()
            BCO:CycleInventoryFilter()
        end,
    }
end

function BCO:InitializeKeybinds()
    self.categoryKeybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,

        {
            name = GetString and
                GetString(SI_GAMEPAD_SELECT_OPTION) or
                "Select",
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                local data =
                    BCO.categoryList:GetTargetData()

                return data ~= nil
                    and not data.bcoLoading
                    and data.bcoKey ~= "currencies"
            end,
            enabled = function()
                local data =
                    BCO.categoryList:GetTargetData()

                return data ~= nil
                    and not data.bcoLoading
                    and data.bcoKey ~= "currencies"
            end,
            callback = function()
                local data =
                    BCO.categoryList:GetTargetData()

                if not data
                    or data.bcoLoading
                    or data.bcoKey == "currencies"
                then
                    return
                end

                BCO:ActivateItemList(true)
                PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
            end,
        },

        CreateInventoryFilterKeybind(),

        KEYBIND_STRIP:GetDefaultGamepadBackButtonDescriptor(),
    }

    self.itemKeybinds = {
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = GetString and
                GetString(SI_GAMEPAD_BACK_OPTION) or
                "Back",
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function()
                BCO:ActivateCategoryList(false)
                PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
            end,
        },

        CreateInventoryFilterKeybind(),

        {
            alignment = KEYBIND_STRIP_ALIGN_CENTER,
            name = function()
                if BCO:IsFurnishingPreviewActive() then
                    if GetString
                        and SI_PREVIEW_CLEAR_INVENTORY_PREVIEW
                    then
                        return GetString(
                            SI_PREVIEW_CLEAR_INVENTORY_PREVIEW
                        )
                    end

                    return "End Preview"
                end

                if GetString
                    and SI_CRAFTING_ENTER_PREVIEW_MODE
                then
                    return GetString(
                        SI_CRAFTING_ENTER_PREVIEW_MODE
                    )
                end

                return "Preview"
            end,
            keybind = "UI_SHORTCUT_QUATERNARY",
            order = 2500,
            disabledDuringSceneHiding = true,
            visible = function()
                if BCO:IsFurnishingPreviewActive() then
                    return true
                end

                local data =
                    BCO:GetSelectedItemData()

                return BCO:CanPreviewFurnishing(data)
            end,
            callback = function()
                if BCO:IsFurnishingPreviewActive() then
                    BCO:EndFurnishingPreview()
                else
                    local data =
                        BCO:GetSelectedItemData()
                    local item = data and data.bcoItem
                    local bagId, slotIndex =
                        BCO:ResolveFurnishingPreviewSlot(
                            data
                        )

                    BCO:PreviewFurnishing(
                        item,
                        bagId,
                        slotIndex
                    )
                end

                BCO:RefreshItemKeybinds()
            end,
        },

        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = function()
                return BCO.locationViewExpanded
                    and "Collapse Locations"
                    or "Show All Locations"
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
                if not BCO.itemList then
                    return false
                end

                local data =
                    BCO.itemList:GetTargetData()
                local item = data and data.bcoItem

                return item ~= nil
                    and LocationCount(item)
                        > BCO.collapsedLocationRows
            end,
            callback = function()
                local data =
                    BCO.itemList:GetTargetData()

                if not data or not data.bcoItem then
                    return
                end

                local expanding =
                    not BCO.locationViewExpanded

                BCO:SetLocationViewExpanded(
                    expanding,
                    data
                )

                if SOUNDS then
                    PlaySound(
                        expanding
                        and SOUNDS.GAMEPAD_MENU_FORWARD
                        or SOUNDS.GAMEPAD_MENU_BACK
                    )
                end
            end,
        },
    }
end

local function EnsureThirdTab(headerData)
    if not headerData
        or type(headerData.tabBarEntries) ~= "table"
        or not BCO.thirdTabEntry
    then
        return false
    end

    local entries = headerData.tabBarEntries

    for index = 1, #entries do
        if entries[index].bcoAllInventories then
            -- Keep one stable callback object even if ESO rebuilt the table.
            entries[index] = BCO.thirdTabEntry
            return true
        end
    end

    entries[#entries + 1] = BCO.thirdTabEntry
    return true
end

function BCO:EnsureNativeTabs()
    local inventory = GAMEPAD_INVENTORY
    if not inventory then
        return false
    end

    local categoryReady =
        EnsureThirdTab(inventory.categoryHeaderData)
    local craftReady =
        EnsureThirdTab(inventory.craftBagHeaderData)
    -- The Vengeance ruleset adds a dedicated Vengeance inventory whose header
    -- uses its own tab-bar table. Without appending BCO's tab here, the All
    -- Inventories tab appeared to be created and deleted as the player tabbed
    -- between the Vengeance inventory (3 tabs) and the regular Inventory or
    -- Craft Bag (4 tabs). Keeping it on every native header makes the tab count
    -- stable across all three native tabs.
    local vengeanceReady =
        EnsureThirdTab(inventory.vengeanceCategoryHeaderData)

    if self.categoryHeaderData then
        self.categoryHeaderData.tabBarEntries =
            inventory.categoryHeaderData
            and inventory.categoryHeaderData.tabBarEntries
            or self.categoryHeaderData.tabBarEntries
    end

    return categoryReady or craftReady or vengeanceReady
end

function BCO:GetBCOTabIndex(headerData)
    local entries = headerData
        and headerData.tabBarEntries

    if type(entries) ~= "table" then
        return nil
    end

    local visibleIndex = 0

    for index = 1, #entries do
        local entry = entries[index]
        local visible = entry and entry.visible

        if type(visible) == "function" then
            local ok, value = pcall(visible)

            -- ESO itself calls visible() without arguments while rebuilding
            -- the header. If an unrelated tab visibility callback fails here,
            -- preserve the table order rather than shifting BCO's index.
            if ok then
                visible = value
            else
                visible = true
            end
        end

        if visible ~= false then
            visibleIndex = visibleIndex + 1

            if entry and entry.bcoAllInventories then
                return visibleIndex
            end
        end
    end

    return nil
end

function BCO:SyncBCOTabSelection(headerData)
    local inventory = GAMEPAD_INVENTORY
    local header = inventory and inventory.header
    local tabBar = header and header.tabBar

    if not tabBar
        or type(tabBar.SetSelectedIndex) ~= "function"
    then
        return false
    end

    local tabIndex = self:GetBCOTabIndex(
        headerData or self.categoryHeaderData
    )

    if not tabIndex then
        return false
    end

    -- ZO_GamepadGenericHeader_SetActiveTabIndex forwards its blockCallback
    -- argument into the tab bar's forceAnimation parameter, so the tab bar
    -- lerps to the target index over several frames and selects every tab it
    -- crosses. Each intermediate selection fires TabBar_OnDataChanged, whose
    -- callback() calls SwitchActiveList -- crossing Craft Bag silently
    -- switched the freshly opened Inventory onto the Craft Bag list (and in
    -- Vengeance campaigns crossed two native tabs, breaking the UI). Calling
    -- the tab bar directly without forceAnimation makes the animation-
    -- disabled tab bar snap synchronously, so only the final BCO tab fires
    -- its callback, which no-ops while BCO is active or refreshing.
    local ALLOW_EVEN_IF_DISABLED = true
    local NO_FORCE_ANIMATION = nil
    local DEFAULT_JUMP_TYPE = nil
    local BLOCK_SELECTION_CHANGED_CALLBACK = true

    local ok = pcall(
        tabBar.SetSelectedIndex,
        tabBar,
        tabIndex,
        ALLOW_EVEN_IF_DISABLED,
        NO_FORCE_ANIMATION,
        DEFAULT_JUMP_TYPE,
        BLOCK_SELECTION_CHANGED_CALLBACK
    )

    return ok
end

-- Resolve the visible tab-bar index of the native Inventory (backpack) tab in
-- the header that is currently committed to the tab bar. Matching is done by
-- the tab's localized text so it stays correct regardless of the optional
-- Vengeance tab or BCO's appended All Inventories tab.
function BCO:GetNativeInventoryTabIndex()
    local inventory = GAMEPAD_INVENTORY
    local entries =
        inventory
        and inventory.categoryHeaderData
        and inventory.categoryHeaderData.tabBarEntries

    if type(entries) ~= "table"
        or type(GetString) ~= "function"
    then
        return nil
    end

    local wantText =
        GetString(SI_GAMEPAD_INVENTORY_CATEGORY_HEADER)
    local visibleIndex = 0

    for index = 1, #entries do
        local entry = entries[index]
        local visible = entry and entry.visible

        if type(visible) == "function" then
            local ok, value = pcall(visible)

            if ok then
                visible = value
            else
                visible = true
            end
        end

        if visible ~= false then
            visibleIndex = visibleIndex + 1

            if entry and not entry.bcoAllInventories then
                local text = entry.text

                if type(text) == "function" then
                    local ok, value = pcall(text, entry)
                    text = ok and value or nil
                end

                if text == wantText then
                    return visibleIndex
                end
            end
        end
    end

    return nil
end

-- Point ESO's header tab bar back at the native Inventory tab.
--
-- ESO's parametric tab bar remembers the previously selected index across
-- Inventory open/close and, on the next open, clamps that index down to the
-- number of native tabs (see ZO_ParametricScrollList:Commit). When Inventory
-- is closed while BCO's All Inventories tab (the last tab) is selected, that
-- remembered index is larger than the native tab count, so on reopen it clamps
-- onto the last native tab -- Craft Bag -- and fires its callback, silently
-- switching the freshly opened Inventory over to the Craft Bag list.
--
-- Resetting the remembered index to the Inventory tab while the scene hides
-- keeps the index within the native range, so reopening lands on Inventory.
-- BCO's scene-resume then re-selects All Inventories cleanly, without the
-- Craft Bag detour.
--
-- SetSelectedIndex cannot be used here: its blockSelectionChangedCallback
-- flag only suppresses the TargetDataChanged event, while the synchronous
-- UpdateAnchors call it makes still fires SelectedDataChanged. That invoked
-- the native Inventory tab's callback -- SwitchActiveList("categoryList") --
-- during scene hide, leaving currentListType set while hidden so the next
-- open's SwitchActiveList early-returned and never reactivated the scene.
-- Writing the remembered selection fields directly fires nothing; the next
-- open's header refresh recommits the tab bar from scratch anyway.
function BCO:ResetNativeTabToInventory()
    local inventory = GAMEPAD_INVENTORY
    local header = inventory and inventory.header
    local tabBar = header and header.tabBar

    if not tabBar
        or type(tabBar.dataList) ~= "table"
    then
        return false
    end

    local tabIndex = self:GetNativeInventoryTabIndex()

    if not tabIndex
        or tabBar.dataList[tabIndex] == nil
    then
        return false
    end

    tabBar.targetSelectedIndex = tabIndex
    tabBar.selectedIndex = tabIndex
    tabBar.selectedData = tabBar.dataList[tabIndex]
    -- Keep the OnUpdate lerp from seeing a stale offset and animating toward
    -- the new index (which would re-fire tab callbacks frame by frame).
    tabBar.lastContinousTargetOffset = tabIndex

    return true
end


function BCO:GetCurrentHeaderData()
    local inventory = GAMEPAD_INVENTORY
    if not inventory then
        return nil
    end

    local current = inventory:GetCurrentList()

    if current == self.categoryList then
        if self.categoryHeaderData then
            self.categoryHeaderData.tabBarEntries =
                inventory.categoryHeaderData
                and inventory.categoryHeaderData.tabBarEntries
                or self.categoryHeaderData.tabBarEntries
        end
        return self.categoryHeaderData
    elseif current == self.itemList then
        return self.itemHeaderData
    elseif current == inventory.craftBagList then
        return inventory.craftBagHeaderData
    elseif current == inventory.categoryList then
        return inventory.categoryHeaderData
    elseif current == inventory.itemList then
        return inventory.itemListHeaderData
    elseif current == inventory.vengeanceCategoryList then
        return inventory.vengeanceCategoryHeaderData
    elseif current == inventory.vengeanceItemList then
        return inventory.vengeanceItemListHeaderData
    end

    return inventory.headerData
        or inventory.categoryHeaderData
end

function BCO:RedrawCurrentHeader()
    if self.refreshingHeader
        or not self.installed
        or not GAMEPAD_INVENTORY
        or not GAMEPAD_INVENTORY.header
        or not ZO_GamepadGenericHeader_Refresh
    then
        return false
    end

    local scene = GAMEPAD_INVENTORY.scene
    if not scene or not scene:IsShowing() then
        return false
    end

    self:EnsureNativeTabs()

    local headerData = self:GetCurrentHeaderData()
    if not headerData then
        return false
    end

    GAMEPAD_INVENTORY.headerData = headerData

    self.refreshingHeader = true
    self.lastDrawnHeaderData = headerData

    local succeeded = pcall(
        ZO_GamepadGenericHeader_Refresh,
        GAMEPAD_INVENTORY.header,
        headerData,
        true
    )

    if succeeded
        and GAMEPAD_INVENTORY:GetCurrentList()
            == self.categoryList
    then
        self:SyncBCOTabSelection(headerData)
    end

    self.refreshingHeader = false
    return succeeded
end

-- True only when the header on screen is actually wrong for BCO: the live
-- tab bar lacks the All Inventories tab, or a BCO list is current but the
-- header was last drawn from native header data. With the tab injected
-- ahead of every native refresh (see InstallHeaderTabInjection) this is
-- normally false, which turns the redraw timers below into no-ops instead
-- of two full tab-bar rebuilds after every native RefreshHeader.
function BCO:NeedsHeaderRedraw()
    local inventory = GAMEPAD_INVENTORY

    if not self.installed
        or not inventory
        or not inventory.header
    then
        return false
    end

    local scene = inventory.scene

    if not scene or not scene:IsShowing() then
        return false
    end

    if self:IsBCOListCurrent(inventory) then
        local current = inventory:GetCurrentList()
        local wanted = current == self.categoryList
            and self.categoryHeaderData
            or self.itemHeaderData

        if inventory.headerData ~= wanted then
            return true
        end

        -- The item view has no tab bar entries to check.
        if current == self.itemList then
            return false
        end
    end

    local tabBar = inventory.header.tabBar
    local dataList = tabBar and tabBar.dataList

    if type(dataList) ~= "table" then
        return true
    end

    for index = 1, #dataList do
        local entry = dataList[index]

        if entry and entry.bcoAllInventories then
            return false
        end
    end

    return true
end

function BCO:ScheduleHeaderRedraw()
    self.headerRefreshGeneration =
        self.headerRefreshGeneration + 1

    local generation = self.headerRefreshGeneration
    -- Two passes: immediately, and once more after ESO's own deferred
    -- header work has settled. Each pass rebuilds the native tab bar, so
    -- each first checks whether the header is actually missing anything.
    local delays = { 0, 250 }

    for index = 1, #delays do
        zo_callLater(function()
            if generation ~= BCO.headerRefreshGeneration
                or not BCO:NeedsHeaderRedraw()
            then
                return
            end

            BCO:RedrawCurrentHeader()
        end, delays[index])
    end
end

-- Native RefreshHeader rebuilds categoryHeaderData.tabBarEntries from
-- GetTabBarEntries() (native tabs only) and hands it straight to
-- ZO_GamepadGenericHeader_Refresh. Appending BCO's tab afterwards meant
-- every native header refresh (each inventory slot update, each currency
-- change) was followed by two more full tab-bar rebuilds from BCO. This
-- pre-hook adds the tab to the header data before the native refresh draws
-- it, so the native pass already shows the right tabs. It touches only the
-- header data table; nothing on the protected item-action path runs here.
--
-- It also skips a native refresh that would draw native header data over a
-- BCO list (RefreshHeader falls through to itemListHeaderData for unknown
-- lists); the RefreshHeader post-hook draws BCO's header right after.
function BCO:InstallHeaderTabInjection()
    if self.headerInjectionInstalled
        or type(ZO_PreHook) ~= "function"
        or type(ZO_GamepadGenericHeader_Refresh) ~= "function"
    then
        return self.headerInjectionInstalled == true
    end

    ZO_PreHook(
        "ZO_GamepadGenericHeader_Refresh",
        function(control, data)
            local inventory = GAMEPAD_INVENTORY

            if not BCO.installed
                or not inventory
                or control ~= inventory.header
                or type(data) ~= "table"
            then
                return false
            end

            if BCO:IsBCOListCurrent(inventory)
                and data ~= BCO.categoryHeaderData
                and data ~= BCO.itemHeaderData
            then
                -- Skip the native draw; BCO's post-hook redraws immediately.
                return true
            end

            if type(data.tabBarEntries) == "table" then
                EnsureThirdTab(data)
            end

            -- A native draw is about to replace whatever BCO drew last.
            if data ~= BCO.categoryHeaderData
                and data ~= BCO.itemHeaderData
            then
                BCO.lastDrawnHeaderData = nil
            end

            return false
        end
    )

    self.headerInjectionInstalled = true
    return true
end


function BCO:SecureHookInventoryMethod(
    methodName,
    callback
)
    self.secureHookState =
        self.secureHookState or {}

    if self.secureHookState[methodName] then
        return true
    end

    local inventory = GAMEPAD_INVENTORY

    if not inventory
        or type(inventory[methodName]) ~= "function"
        or type(SecurePostHook) ~= "function"
    then
        return false
    end

    local ok = pcall(
        SecurePostHook,
        inventory,
        methodName,
        callback
    )

    if ok then
        self.secureHookState[methodName] = true
    end

    return ok
end

function BCO:InstallSecureInventoryHooks()
    local inventory = GAMEPAD_INVENTORY

    if not inventory then
        return false
    end

    -- RefreshHeader is called inside native list switches. A direct wrapper
    -- would make every downstream Use/Equip callback originate from addon
    -- code. SecurePostHook lets ESO finish the native method securely first.
    local headerHooked =
        self:SecureHookInventoryMethod(
            "RefreshHeader",
            function(inv, blockCallback)
                BCO:EnsureNativeTabs()

                if BCO:IsBCOListCurrent(inv) then
                    local ONLY_IF_STALE = true
                    BCO:RefreshBCOHeader(
                        blockCallback,
                        ONLY_IF_STALE
                    )
                else
                    BCO:ScheduleHeaderRedraw()
                end
            end
        )

    -- The original SwitchActiveList must remain untouched because it securely
    -- rebuilds the native item-action controller. BCO only cleans up after the
    -- completed switch.
    local switchHooked =
        self:SecureHookInventoryMethod(
            "SwitchActiveList",
            function(inv, listDescriptor)
                -- During SCENE_HIDING ESO calls SwitchActiveList(nil), copies
                -- currentListType into previousListType, and reuses it on the
                -- next SCENE_SHOWING. Replace BCO's private descriptor with a
                -- native one before that next activation.
                if listDescriptor == nil then
                    BCO:PrepareForInventorySceneHide(inv)
                    return
                end

                local current = inv:GetCurrentList()

                if current ~= BCO.categoryList
                    and current ~= BCO.itemList
                then
                    if BCO.active then
                        BCO:LeaveBCOMode(false)
                    end

                    if inv.currentlySelectedData
                        and inv.currentlySelectedData.bcoOfflineEntry
                    then
                        inv.currentlySelectedData =
                            BCO:GetSafeNativeSelection(inv)
                    end

                    BCO:EnsureNativeTabs()
                    BCO:ScheduleHeaderRedraw()
                end
            end
        )

    -- API builds have used both spellings. The native search refresh is safe
    -- to run first because native lists gate their rebuilds by list type; BCO
    -- then refreshes its own dedicated list from a secure post-hook.
    local searchMethodName

    if type(inventory.OnUpdatedSearchResults)
        == "function"
    then
        searchMethodName =
            "OnUpdatedSearchResults"
    elseif type(inventory.OnUpdateSearchResults)
        == "function"
    then
        searchMethodName =
            "OnUpdateSearchResults"
    end

    if searchMethodName then
        local searchHooked =
            self:SecureHookInventoryMethod(
                searchMethodName,
                function(_, ...)
                    if not BCO:IsBCOListCurrent() then
                        return
                    end

                    local firstArgument =
                        select(1, ...)

                    BCO:ScheduleSearchRefresh(
                        type(firstArgument) == "string"
                            and firstArgument
                            or nil
                    )
                end
            )

        if searchHooked then
            self.searchHookMethodName =
                searchMethodName
        end
    end

    -- Native update ticks can redraw the category tooltip while BCO uses its
    -- read-only action mode. Restore BCO's item-link/currency tooltip only
    -- after the native function has completed.
    if type(inventory.UpdateCategoryLeftTooltip)
        == "function"
    then
        self:SecureHookInventoryMethod(
            "UpdateCategoryLeftTooltip",
            function()
                BCO:RestoreBCOTooltipsAfterNativeUpdate()
            end
        )
    end

    if type(inventory.UpdateRightTooltip)
        == "function"
    then
        self:SecureHookInventoryMethod(
            "UpdateRightTooltip",
            function()
                if BCO:IsBCOListCurrent()
                    and GAMEPAD_TOOLTIPS
                then
                    GAMEPAD_TOOLTIPS:ClearTooltip(
                        GAMEPAD_RIGHT_TOOLTIP
                    )
                end
            end
        )
    end

    return headerHooked and switchHooked
end

-- Native ZO_GamepadInventory:MarkDirty arms a 10 ms OnUpdate tick after
-- every inventory event. In the read-only (category) action mode BCO keeps
-- while its lists are current, that tick does nothing but lay out the
-- native category target's equipped-slot tooltip and the right comparison
-- tooltip, which BCO's post-hooks then clear and replace with its own item
-- tooltip. Disarming the tick while a BCO list is current removes three
-- tooltip layouts per inventory event; leaving BCO goes through the native
-- SwitchActiveList, which refreshes everything itself.
function BCO:InstallDirtyTickSuppression()
    return self:SecureHookInventoryMethod(
        "MarkDirty",
        function(inv)
            if BCO:IsBCOListCurrent(inv) then
                inv.nextUpdateTimeSeconds = nil
            end
        end
    )
end

function BCO:GetInstallReadiness()
    local inventory = GAMEPAD_INVENTORY

    if not inventory then
        return false, "GAMEPAD_INVENTORY=nil"
    elseif not inventory.categoryList then
        return false, "categoryList=nil"
    elseif not inventory.itemList then
        return false, "itemList=nil"
    elseif not inventory.craftBagList then
        return false, "craftBagList=nil"
    elseif type(inventory.AddList) ~= "function" then
        return false, "AddList=" .. type(inventory.AddList)
    elseif type(SecurePostHook) ~= "function" then
        return false, "SecurePostHook=" .. type(SecurePostHook)
    elseif type(inventory.SwitchActiveList) ~= "function" then
        return false, "SwitchActiveList=" .. type(inventory.SwitchActiveList)
    elseif type(inventory.RefreshHeader) ~= "function" then
        return false, "RefreshHeader=" .. type(inventory.RefreshHeader)
    elseif not inventory.categoryHeaderData then
        return false, "categoryHeaderData=nil"
    elseif not inventory.craftBagHeaderData then
        return false, "craftBagHeaderData=nil"
    end

    return true, "ready"
end

function BCO:Install()
    if self.installed then
        return true
    end

    self.installAttempts = self.installAttempts + 1

    local ready, status = self:GetInstallReadiness()
    self.lastInstallStatus = status

    if not ready then
        return false
    end

    local inventory = GAMEPAD_INVENTORY

    if not self:InstallSecureInventoryHooks() then
        self.lastInstallStatus =
            "Secure inventory hook installation failed"
        return false
    end

    self.categoryList = inventory:AddList(
        "BCOCategory",
        SetupCategoryList
    )

    self.itemList = inventory:AddList(
        "BCOItems",
        SetupItemList
    )

    if self.categoryList.SetNoItemText then
        self.categoryList:SetNoItemText(
            "No saved inventory data."
        )
    end

    if self.itemList.SetNoItemText then
        self.itemList:SetNoItemText(
            "No saved items in this category."
        )
    end

    self.categoryList:SetOnSelectedDataChangedCallback(
        function(first, second)
            local selectedData = second or first

            -- Category rows are read-only BCO data and must not be stored in
            -- ESO's native selected-inventory field.
            BCO:RefreshCategoryKeybinds()
            BCO:UpdateCategoryTooltip(
                selectedData
            )
        end
    )

    self.itemList:SetOnSelectedDataChangedCallback(
        function(first, second)
            local selectedData = BCO.itemList
                and BCO.itemList:GetTargetData()
                or second
                or first

            BCO:CollapseLocationView(false)
            BCO:HandleItemSelectionChanged(
                selectedData
            )
        end
    )

    self:InitializeKeybinds()

    self.thirdTabEntry = {
        text = "All Inventories",
        bcoAllInventories = true,
        callback = function()
            if BCO.refreshingHeader
                or BCO.resumeBCOAfterSceneShow
                or BCO.sceneResumeScheduled
            then
                return
            end

            if not BCO.active then
                BCO:ActivateCategoryList(true)
            end
        end,
    }

    self:EnsureNativeTabs()

    self.categoryHeaderData = {
        tabBarEntries =
            inventory.categoryHeaderData.tabBarEntries,
        titleText = function()
            return "ALL INVENTORIES"
        end,
    }

    self:EnsureNativeTabs()

    self.itemHeaderData = {
        titleText = function()
            return BCO.selectedCategoryName
                or "ALL INVENTORIES"
        end,
    }

    -- Native inventory methods are deliberately not replaced. Their secure
    -- execution context owns all Use/Equip/Move action construction; BCO is
    -- synchronized exclusively through the secure post-hooks installed above.

    self:InstallHeaderTabInjection()
    self:InstallDirtyTickSuppression()

    self.installed = true

    if inventory.scene and inventory.scene:IsShowing() then
        self:EnsureNativeTabs()
        self:ScheduleHeaderRedraw()
    end

    -- The aggregate is built the first time All Inventories is opened
    -- (RefreshCategoryList -> EnsureIndex), not at install, so opening the
    -- native Inventory costs nothing extra.
    self:MarkIndexDirty()

    Msg("Loaded. Inventory now includes All Inventories.")
    return true
end

function BCO:TryInstallForOpenScene()
    if self.installed then
        self:EnsureNativeTabs()
        self:ScheduleHeaderRedraw()
        return true
    end

    local inventory = GAMEPAD_INVENTORY
    local scene = inventory and inventory.scene

    if not scene or not scene:IsShowing() then
        self.lastInstallStatus = "Inventory scene is not showing"
        return false
    end

    return self:Install()
end

function BCO:ScheduleSceneInstall()
    if self.installed then
        return
    end

    self.sceneInstallGeneration =
        self.sceneInstallGeneration + 1

    local generation = self.sceneInstallGeneration
    local delays = { 0, 250, 1000 }

    for index = 1, #delays do
        zo_callLater(function()
            if generation ~= BCO.sceneInstallGeneration
                or BCO.installed
            then
                return
            end

            BCO:TryInstallForOpenScene()
        end, delays[index])
    end
end

function BCO:InstallSceneWatcher()
    if self.sceneWatcherInstalled then
        return true
    end

    local scene =
        GAMEPAD_INVENTORY_ROOT_SCENE
        or (
            SCENE_MANAGER
            and SCENE_MANAGER:GetScene(
                "gamepad_inventory_root"
            )
        )

    if not scene then
        zo_callLater(function()
            BCO:InstallSceneWatcher()
        end, 500)
        return false
    end

    scene:RegisterCallback(
        "StateChange",
        function(_, newState)
            if newState == SCENE_SHOWING
                or newState == SCENE_SHOWN
            then
                BCO:ScheduleSceneInstall()

                if BCO.installed then
                    BCO:ScheduleHeaderRedraw()
                    BCO:ScheduleBCOSceneResume()
                end
            elseif newState == SCENE_HIDING then
                BCO:PrepareForInventorySceneHide()
            elseif newState == SCENE_HIDDEN then
                -- Run the normalization again for safety because scene
                -- callback order can differ between console UI builds.
                BCO:PrepareForInventorySceneHide()
                BCO.sceneInstallGeneration =
                    BCO.sceneInstallGeneration + 1
                -- Give the aggregate and the BCO list rows back to the
                -- shared Lua pool; the next All Inventories visit rebuilds
                -- them in chunks. Holding them while Inventory is closed
                -- bought nothing and left 10+ MB resident through every
                -- load screen on large accounts.
                BCO:ReleaseSceneResources()
            end
        end
    )

    self.sceneWatcherInstalled = true

    if scene:IsShowing() then
        self:ScheduleSceneInstall()
    end

    return true
end

function BCO:Open()
    self:InstallSceneWatcher()
    SCENE_MANAGER:Show("gamepad_inventory_root")
    self:ScheduleSceneInstall()

    local generation = self.sceneInstallGeneration

    local function TryOpenBCO()
        if generation ~= BCO.sceneInstallGeneration then
            return
        end

        if BCO.installed then
            BCO:ActivateCategoryList(true)
            return
        end

        local inventory = GAMEPAD_INVENTORY
        if inventory
            and inventory.scene
            and inventory.scene:IsShowing()
        then
            zo_callLater(TryOpenBCO, 100)
        end
    end

    zo_callLater(TryOpenBCO, 100)
end

local function RegisterCommands()
    SLASH_COMMANDS = SLASH_COMMANDS or {}

    SLASH_COMMANDS["/bco"] = function()
        BCO:Open()
    end

    SLASH_COMMANDS["/bcorescan"] = function()
        BCO:ScanCurrentCharacter()
        Msg("Current character rescanned.")
    end

    SLASH_COMMANDS["/bcoclear"] = function()
        BCO.savedVars.characters = {}
        BCO.savedVars.shared = {
            bank = { items = {}, updated = 0 },
            storage = {},
            houses = {},
            guildListings = {},
            currencies = {
                bank = {},
                updated = 0,
            },
        }
        BCO:ReleaseIndex()
        Msg("Saved inventory snapshots cleared.")
    end


    -- Reports the live scroll state of the left item tooltip. Run it while an
    -- item set piece with a long tooltip is highlighted in All Inventories to
    -- diagnose why the right stick will or will not scroll the description.
    SLASH_COMMANDS["/bcoscroll"] = function()
        local tip = GetLeftTooltipScrollTip()

        if not tip then
            Msg("Left tooltip scroll wrapper not built yet.")
            return
        end

        local verticalExtents = 0

        if tip.scroll
            and type(tip.scroll.GetScrollExtents) == "function"
        then
            local ok, _, extents = pcall(
                tip.scroll.GetScrollExtents,
                tip.scroll
            )

            if ok then
                verticalExtents = extents or 0
            end
        end

        local tipHeight =
            type(tip.GetHeight) == "function"
            and tip:GetHeight()
            or -1
        local childHeight =
            tip.scrollChild
            and type(tip.scrollChild.GetHeight) == "function"
            and tip.scrollChild:GetHeight()
            or -1

        Msg(string.format(
            "scroll: hidden=%s input=%s canScroll=%s active=%s vExtents=%.1f tipH=%.1f childH=%.1f renderedKey=%s",
            tostring(type(tip.IsHidden) == "function" and tip:IsHidden()),
            tostring(tip.inputEnabled),
            tostring(tip.canScroll),
            tostring(tip.directionalInputActivated),
            verticalExtents,
            tipHeight,
            childHeight,
            tostring(BCO.renderedItemTooltipKey)
        ))
    end


    SLASH_COMMANDS["/bcostatus"] = function()
        local ready, status = BCO:GetInstallReadiness()
        local inventory = GAMEPAD_INVENTORY
        local categoryTabs =
            inventory
            and inventory.categoryHeaderData
            and inventory.categoryHeaderData.tabBarEntries
            and #inventory.categoryHeaderData.tabBarEntries
            or 0
        local craftTabs =
            inventory
            and inventory.craftBagHeaderData
            and inventory.craftBagHeaderData.tabBarEntries
            and #inventory.craftBagHeaderData.tabBarEntries
            or 0
        local liveTabs =
            inventory
            and inventory.headerData
            and inventory.headerData.tabBarEntries
            and #inventory.headerData.tabBarEntries
            or 0

        Msg(string.format(
            "Installed=%s Ready=%s Status=%s Attempts=%d Hooks H/S=%s/%s Search=%s Tabs C/F/L=%d/%d/%d",
            tostring(BCO.installed),
            tostring(ready),
            tostring(status or BCO.lastInstallStatus),
            BCO.installAttempts or 0,
            tostring(
                BCO.secureHookState
                and BCO.secureHookState.RefreshHeader
                or false
            ),
            tostring(
                BCO.secureHookState
                and BCO.secureHookState.SwitchActiveList
                or false
            ),
            tostring(BCO.searchHookMethodName or "none"),
            categoryTabs,
            craftTabs,
            liveTabs
        ))
    end

    SLASH_COMMANDS["/bcopreviewstatus"] = function()
        local selectedData = BCO:GetSelectedItemData()
        local item = selectedData and selectedData.bcoItem
        local bagId, slotIndex = nil, nil
        local furnitureEligible = false
        local genericEligible = false
        local previewObject = GetItemPreviewObject()

        if item then
            bagId, slotIndex =
                BCO:ResolveFurnishingPreviewSlot(selectedData)

            if type(CanItemLinkBePreviewedAsFurniture)
                == "function"
            then
                local ok, value = pcall(
                    CanItemLinkBePreviewedAsFurniture,
                    item.itemLink
                )
                furnitureEligible = ok and value == true
            end

            if type(CanItemLinkBePreviewed) == "function" then
                local ok, value = pcall(
                    CanItemLinkBePreviewed,
                    item.itemLink
                )
                genericEligible = ok and value == true
            end
        end

        Msg(string.format(
            "Preview active=%s path=%s liveSlot=%s/%s linkAPI=%s sharedLink=%s furnitureCheck=%s genericCheck=%s error=%s",
            tostring(BCO:IsFurnishingPreviewActive()),
            tostring(BCO.lastFurnishingPreviewPath or "none"),
            tostring(bagId),
            tostring(slotIndex),
            tostring(type(PreviewItemLink) == "function"),
            tostring(
                previewObject
                and type(previewObject.PreviewItemLink)
                    == "function"
            ),
            tostring(furnitureEligible),
            tostring(genericEligible),
            tostring(BCO.lastFurnishingPreviewError or "none")
        ))
    end

    SLASH_COMMANDS["/bcosnapshots"] = function()
        local rows = {}
        local totalCharacters = 0

        for _, character in pairs(
            BCO.savedVars.characters or {}
        ) do
            totalCharacters = totalCharacters + 1
            rows[#rows + 1] = {
                name = character.name
                    or "Unknown Character",
                backpack = #(character.backpack or {}),
                worn = #(character.worn or {}),
                hasCurrencies =
                    type(character.currencies) == "table",
                updated = character.updated or 0,
            }
        end

        table.sort(rows, function(left, right)
            return Lower(left.name) < Lower(right.name)
        end)

        local storageRows = {}

        for storageKey, storage in pairs(
            BCO.savedVars.shared.storage or {}
        ) do
            storageRows[#storageRows + 1] = {
                name = storage.name
                    or "Housing Storage",
                items = #(storage.items or {}),
                updated = storage.updated or 0,
                key = storageKey,
            }
        end

        table.sort(storageRows, function(left, right)
            return Lower(left.name) < Lower(right.name)
        end)

        local houseRows = {}

        for houseKey, house in pairs(
            BCO.savedVars.shared.houses or {}
        ) do
            houseRows[#houseRows + 1] = {
                name = house.name or "House",
                items = #(house.items or {}),
                updated = house.updated or 0,
                key = houseKey,
            }
        end

        table.sort(houseRows, function(left, right)
            return Lower(left.name) < Lower(right.name)
        end)

        local listingRows = {}

        for listingKey, listing in pairs(
            BCO.savedVars.shared.guildListings or {}
        ) do
            listingRows[#listingRows + 1] = {
                name = listing.name or "Guild",
                items = #(listing.items or {}),
                updated = listing.updated or 0,
                key = listingKey,
            }
        end

        table.sort(listingRows, function(left, right)
            return Lower(left.name) < Lower(right.name)
        end)

        Msg(string.format(
            "Saved characters=%d Bank=%d Storage=%d Houses=%d Listings=%d CurrencyBank=%s",
            totalCharacters,
            #(
                BCO.savedVars.shared.bank.items
                or {}
            ),
            #storageRows,
            #houseRows,
            #listingRows,
            tostring(
                BCO.savedVars.shared.currencies
                    ~= nil
            )
        ))

        for index = 1, #rows do
            local row = rows[index]

            Msg(string.format(
                "%s backpack=%d worn=%d currencies=%s updated=%d",
                row.name,
                row.backpack,
                row.worn,
                tostring(row.hasCurrencies),
                row.updated
            ))
        end

        for index = 1, #storageRows do
            local row = storageRows[index]

            Msg(string.format(
                "%s items=%d updated=%d",
                row.name,
                row.items,
                row.updated
            ))
        end

        for index = 1, #houseRows do
            local row = houseRows[index]

            Msg(string.format(
                "%s furnishings=%d updated=%d",
                row.name,
                row.items,
                row.updated
            ))
        end

        for index = 1, #listingRows do
            local row = listingRows[index]

            Msg(string.format(
                "%s listings=%d updated=%d",
                row.name,
                row.items,
                row.updated
            ))
        end
    end

end

local function OnCurrencyUpdate()
    BCO:ScanCurrentCurrencies()

    if BCO.active
        and GAMEPAD_INVENTORY
        and GAMEPAD_INVENTORY:GetCurrentList()
            == BCO.categoryList
    then
        local selectedData =
            BCO.categoryList:GetTargetData()

        if selectedData
            and selectedData.bcoKey == "currencies"
        then
            BCO:ScheduleCurrencyTooltip(
                selectedData
            )
        end
    end
end

local function OnInventoryUpdate(_, bagId)
    local openBankBag = BCO.activeBankBag
    local isOpenBankUpdate = false

    if BCO.bankOpen then
        if openBankBag == BAG_BANK then
            isOpenBankUpdate = bagId == BAG_BANK
                or bagId == BAG_SUBSCRIBER_BANK
        elseif openBankBag ~= nil then
            isOpenBankUpdate = bagId == openBankBag
        end
    end

    if bagId == BAG_BACKPACK
        or bagId == BAG_WORN
        or isOpenBankUpdate
    then
        BCO:ScheduleScan()
    end
end

local function OnBankOpen(_, bankBag)
    BCO.bankOpen = true
    BCO.activeBankBag = bankBag

    if BCO.activeBankBag == nil
        and type(GetBankingBag) == "function"
    then
        local ok, currentBagId = pcall(GetBankingBag)

        if ok then
            BCO.activeBankBag = currentBagId
        end
    end

    local expectedBag = BCO.activeBankBag

    zo_callLater(function()
        if BCO.bankOpen
            and BCO.activeBankBag == expectedBag
        then
            BCO:ScanCurrentCharacter()
        end
    end, 350)
end

local function OnBankClose()
    BCO.bankOpen = false
    BCO.activeBankBag = nil
end

local function OnPlayerActivated()
    BCO:InstallSceneWatcher()

    -- One scan after the inventory has settled on slower console loads.
    -- EVENT_PLAYER_ACTIVATED also fires on every zone change, and the
    -- snapshot only needs two API calls per slot, so a single pass is
    -- enough; any later change is caught by the inventory update events.
    -- Goes through ScheduleScan so the EVENT_INVENTORY_FULL_UPDATE that
    -- accompanies every load screen does not add a second full bag walk.
    BCO:ScheduleScan(1000)

    -- No-op outside an owned house. Delayed so placed furniture has loaded
    -- and the character scans above have already run.
    BCO:ScheduleHouseScan(2500)
end

local function OnHouseFurnitureChanged()
    BCO:ScheduleHouseScan()
end

local function OnTradingHouseOpened()
    BCO.tradingHouseOpen = true

    -- Delayed so the native trading house UI finishes its own opening
    -- requests before this one queues up behind the shared cooldown.
    zo_callLater(function()
        BCO:RequestListingsWhenReady()
    end, 1000)
end

local function OnTradingHouseClosed()
    BCO.tradingHouseOpen = false
end

local function OnTradingHouseResponse(
    _,
    responseType,
    result
)
    if result ~= TRADING_HOUSE_RESULT_SUCCESS then
        return
    end

    if responseType
        == TRADING_HOUSE_RESULT_LISTINGS_PENDING
    then
        BCO:ScheduleListingScan()
    elseif responseType
            == TRADING_HOUSE_RESULT_POST_PENDING
        or responseType
            == TRADING_HOUSE_RESULT_CANCEL_SALE_PENDING
    then
        -- Posting or canceling a listing changes the set, so fetch the
        -- updated listings for the fresh snapshot.
        zo_callLater(function()
            BCO:RequestListingsWhenReady()
        end, 500)
    end
end

local function OnTradingHouseGuildChanged()
    zo_callLater(function()
        BCO:RequestListingsWhenReady()
    end, 500)
end

local function OnPlayerDeactivated()
    -- SavedVariables are written as the character unloads. Capture the
    -- current bags synchronously so the next character can see them.
    BCO.scanPending = false
    BCO:ScanCurrentCharacter(false)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= BCO.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(
        BCO.name,
        EVENT_ADD_ON_LOADED
    )

    BCO.savedVars = ZO_SavedVars:NewAccountWide(
        "BetterCharacterOverviewSavedVariables",
        BCO.savedVarVersion,
        nil,
        BCO.defaults
    )

    -- All Inventories intentionally excludes the account-wide Craft Bag.
    -- Remove any snapshot left by an older version so it is not retained in
    -- SavedVariables or accidentally reintroduced into the combined index.
    BCO.savedVars.shared = BCO.savedVars.shared or {}
    BCO.savedVars.shared.bank = BCO.savedVars.shared.bank or {
        items = {},
        updated = 0,
    }
    BCO.savedVars.shared.storage =
        BCO.savedVars.shared.storage or {}
    BCO.savedVars.shared.houses =
        BCO.savedVars.shared.houses or {}
    BCO.savedVars.shared.guildListings =
        BCO.savedVars.shared.guildListings or {}
    BCO.savedVars.shared.currencies =
        BCO.savedVars.shared.currencies or {
            bank = {},
            updated = 0,
        }
    BCO.savedVars.shared.currencies.bank =
        BCO.savedVars.shared.currencies.bank or {}
    BCO.savedVars.shared.craftBag = nil

    -- Shrink snapshots written by earlier versions down to the minimal
    -- {itemLink, count} schema (see ReadItem). This frees the derived
    -- fields immediately and makes the next SavedVariables write smaller.
    for _, character in pairs(BCO.savedVars.characters) do
        if type(character) == "table" then
            character.backpack =
                SlimSnapshotList(character.backpack)
            character.worn = SlimSnapshotList(character.worn)
        end
    end

    BCO.savedVars.shared.bank.items =
        SlimSnapshotList(BCO.savedVars.shared.bank.items)

    for _, group in ipairs({
        BCO.savedVars.shared.storage,
        BCO.savedVars.shared.houses,
        BCO.savedVars.shared.guildListings,
    }) do
        for _, source in pairs(group) do
            if type(source) == "table" then
                source.items = SlimSnapshotList(source.items)
            end
        end
    end

    RegisterCommands()

    EVENT_MANAGER:RegisterForEvent(
        BCO.name,
        EVENT_PLAYER_ACTIVATED,
        OnPlayerActivated
    )


    EVENT_MANAGER:RegisterForEvent(
        BCO.name,
        EVENT_PLAYER_DEACTIVATED,
        OnPlayerDeactivated
    )

    EVENT_MANAGER:RegisterForEvent(
        BCO.name,
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        OnInventoryUpdate
    )

    if EVENT_CURRENCY_UPDATE then
        EVENT_MANAGER:RegisterForEvent(
            BCO.name,
            EVENT_CURRENCY_UPDATE,
            OnCurrencyUpdate
        )
    end

    if EVENT_CURRENCY_CAPS_CHANGED then
        EVENT_MANAGER:RegisterForEvent(
            BCO.name,
            EVENT_CURRENCY_CAPS_CHANGED,
            OnCurrencyUpdate
        )
    end

    EVENT_MANAGER:RegisterForEvent(
        BCO.name,
        EVENT_INVENTORY_FULL_UPDATE,
        function()
            BCO:ScheduleScan()
        end
    )

    if EVENT_OPEN_BANK then
        EVENT_MANAGER:RegisterForEvent(
            BCO.name,
            EVENT_OPEN_BANK,
            OnBankOpen
        )
    end

    if EVENT_CLOSE_BANK then
        EVENT_MANAGER:RegisterForEvent(
            BCO.name,
            EVENT_CLOSE_BANK,
            OnBankClose
        )
    end

    if EVENT_HOUSING_FURNITURE_PLACED then
        EVENT_MANAGER:RegisterForEvent(
            BCO.name,
            EVENT_HOUSING_FURNITURE_PLACED,
            OnHouseFurnitureChanged
        )
    end

    if EVENT_HOUSING_FURNITURE_REMOVED then
        EVENT_MANAGER:RegisterForEvent(
            BCO.name,
            EVENT_HOUSING_FURNITURE_REMOVED,
            OnHouseFurnitureChanged
        )
    end

    if EVENT_OPEN_TRADING_HOUSE then
        EVENT_MANAGER:RegisterForEvent(
            BCO.name,
            EVENT_OPEN_TRADING_HOUSE,
            OnTradingHouseOpened
        )
    end

    if EVENT_CLOSE_TRADING_HOUSE then
        EVENT_MANAGER:RegisterForEvent(
            BCO.name,
            EVENT_CLOSE_TRADING_HOUSE,
            OnTradingHouseClosed
        )
    end

    if EVENT_TRADING_HOUSE_RESPONSE_RECEIVED then
        EVENT_MANAGER:RegisterForEvent(
            BCO.name,
            EVENT_TRADING_HOUSE_RESPONSE_RECEIVED,
            OnTradingHouseResponse
        )
    end

    if EVENT_TRADING_HOUSE_SELECTED_GUILD_CHANGED then
        EVENT_MANAGER:RegisterForEvent(
            BCO.name,
            EVENT_TRADING_HOUSE_SELECTED_GUILD_CHANGED,
            OnTradingHouseGuildChanged
        )
    end
end

EVENT_MANAGER:RegisterForEvent(
    BCO.name,
    EVENT_ADD_ON_LOADED,
    OnAddOnLoaded
)
