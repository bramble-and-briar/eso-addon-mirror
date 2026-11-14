NGear = NGear or {}
NGear.Features = NGear.Features or {}

local ItemLocator = {}
NGear.ItemLocator = ItemLocator
NGear.Features.ItemLocator = ItemLocator

local Codec = NGear.ItemLocatorCodec
local C = {
    VERSION = 2,
    NAMESPACE = "ItemLocator",
    EVENT_NAMESPACE = "NGear_ItemLocator",
    FLUSH_UPDATE = "NGear_ItemLocator_Flush",
    FULL_SCAN_UPDATE = "NGear_ItemLocator_FullScan",
    BANK_SCAN_UPDATE = "NGear_ItemLocator_BankScan",
    CHARACTER_SCAN_UPDATE = "NGear_ItemLocator_CharacterScan",
    STORAGE_SCAN_UPDATE = "NGear_ItemLocator_StorageScan",
    FLUSH_DELAY_MS = 250,
    RESCAN_DELAY_MS = 100,
    SCAN_BUDGET_MS = 2,
    SCAN_MAX_SLOTS_PER_FRAME = 8,
    -- PS5 can corrupt the add-on save with strings well below ESO's nominal limit.
    PAYLOAD_CHUNK_LENGTH = 240,
    DISPLAY_SCALE_MIN = 50,
    DISPLAY_SCALE_MAX = 150,
    DISPLAY_OPACITY_MIN = 0,
    DISPLAY_OPACITY_MAX = 100,
    SORT_ALPHABETICAL = 1,
    SORT_QUALITY = 2,
}

local DISPLAY_DEFAULTS = {
    x = 50,
    y = 50,
    f = NGear.Util.GetDefaultFont(),
    s = 100,
    o = 94,
    r = C.SORT_ALPHABETICAL,
}

local defaults = {
    v = C.VERSION,
    e = false,
    c = {},
    p = {},
    k = { t = 0, p = {} },
    m = { t = 0, p = {} },
    f = { t = 0, p = {} },
    h = {},
    x = {},
    u = DISPLAY_DEFAULTS,
}
NGear.Settings.RegisterAccountWideDefaults(C.NAMESPACE, defaults)

local savedVariables
local initialized = false
local eventsRegistered = false
local bankOpen = false
local furnitureVaultOpen = false
local houseBankBag
local bankCacheReady = false
local furnitureVaultCacheReady = false
local houseBankCacheReady = false
local characterCacheReady = false
local catalogLookupReady = false
local catalogCompactionNeeded = true
local unavailableData = false
-- The identity itself is the lookup key. This keeps lookups exact while avoiding
-- the former second unpack/API/identity pass required to verify every hash hit.
local catalogIdentityToId = {}
local dirty = { b = false, w = false, k = false, m = false, f = false, h = false }
local aggregates = { b = {}, w = {}, k = {}, m = {}, f = {}, h = {} }
local slotIds = {}
local slotCounts = {}
local codecBuffer = {}
local codecIds = {}
local codecFields = {}
local decodeScratch = {}
local remapScratch = {}
local identityParts = {}
local CompactCatalog
local CancelCharacterScan
local CancelStorageScan
local StartCharacterScan
local StartStorageScan
local characterScanJob
local storageScanJob

local TRACKED_BAGS = {}
local BANK_BAGS = {}

local function Clear(values)
    for key in pairs(values) do values[key] = nil end
end

local function IsTrue(value)
    return value == true and 1 or 0
end

local function Number(value)
    return tonumber(value) or 0
end

local function IsPayload(value)
    if type(value) ~= "table" then return false end
    local length = #value
    for key, chunk in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or key > length
            or type(chunk) ~= "string" or #chunk > C.PAYLOAD_CHUNK_LENGTH then
            return false
        end
    end
    return true
end

local function SafeNumber(api, ...)
    if type(api) ~= "function" then return 0 end
    return Number(api(...))
end

local function SafeBoolean(api, ...)
    if type(api) ~= "function" then return 0 end
    return IsTrue(api(...))
end

local function GetCharacterName(name)
    name = tostring(name or "")
    if zo_strformat and SI_UNIT_NAME then
        name = zo_strformat(SI_UNIT_NAME, name)
    end
    return name
end

local function GetCurrentCharacterKey()
    if GetCurrentCharacterId then
        local characterId = GetCurrentCharacterId()
        if characterId ~= nil and tostring(characterId) ~= "" then
            return tostring(characterId)
        end
    end
    return GetCharacterName(GetUnitName and GetUnitName("player") or "")
end

local function GetCurrentCharacterName()
    return GetCharacterName(GetUnitName and GetUnitName("player") or "")
end

local function GetBankName()
    if GetString and SI_GAMEPAD_INVENTORY_STACK_COUNT_BAG_BANK then
        local name = GetString(SI_GAMEPAD_INVENTORY_STACK_COUNT_BAG_BANK)
        if name and name ~= "" then return name end
    end
    return NGear.L("item_locator.bank")
end

local function GetCraftBagName()
    if GetString and SI_GAMEPAD_INVENTORY_CRAFT_BAG_HEADER then
        local name = GetString(SI_GAMEPAD_INVENTORY_CRAFT_BAG_HEADER)
        if name and name ~= "" then return name end
    end
    return NGear.L("item_locator.craft_bag")
end

local function GetFurnitureVaultName()
    if GetString and SI_GAMEPAD_INVENTORY_STACK_COUNT_BAG_FURNITURE_VAULT then
        local name = GetString(SI_GAMEPAD_INVENTORY_STACK_COUNT_BAG_FURNITURE_VAULT)
        if name and name ~= "" then return name end
    end
    return NGear.L("item_locator.furniture_vault")
end

local function GetHouseStorageName(bagId)
    local collectibleId = GetCollectibleForBag and Number(GetCollectibleForBag(bagId)) or 0
    local name = ""
    if collectibleId > 0 then
        name = GetCollectibleNickname and tostring(GetCollectibleNickname(collectibleId) or "") or ""
        if name == "" and GetCollectibleName then name = tostring(GetCollectibleName(collectibleId) or "") end
    end
    if name == "" and GetString then name = tostring(GetString("SI_BAG", bagId) or "") end
    return name ~= "" and name or NGear.L("item_locator.house_storage")
end

local function RequestPrioritySave()
    if not GetAddOnManager then return end
    local manager = GetAddOnManager()
    if manager and manager.RequestAddOnSavedVariablesPrioritySave then
        manager:RequestAddOnSavedVariablesPrioritySave(NGear.name or "NGear")
    end
end

local function GetDisplaySettings()
    if not savedVariables then return DISPLAY_DEFAULTS end
    if type(savedVariables.u) ~= "table" then savedVariables.u = {} end
    local settings = savedVariables.u
    settings.x = NGear.Util.Clamp(tonumber(settings.x) or DISPLAY_DEFAULTS.x, 0, 100)
    settings.y = NGear.Util.Clamp(tonumber(settings.y) or DISPLAY_DEFAULTS.y, 0, 100)
    settings.s = NGear.Util.Clamp(NGear.Util.Round(tonumber(settings.s) or DISPLAY_DEFAULTS.s), C.DISPLAY_SCALE_MIN, C.DISPLAY_SCALE_MAX)
    settings.o = NGear.Util.Clamp(NGear.Util.Round(tonumber(settings.o) or DISPLAY_DEFAULTS.o), C.DISPLAY_OPACITY_MIN, C.DISPLAY_OPACITY_MAX)
    settings.r = Number(settings.r) == C.SORT_QUALITY and C.SORT_QUALITY or C.SORT_ALPHABETICAL
    if not NGear.Util.IsFontChoice(settings.f) then settings.f = DISPLAY_DEFAULTS.f end
    return settings
end

local function RefreshDisplay()
    if type(ItemLocator.RefreshDisplay) == "function" then ItemLocator.RefreshDisplay() end
end

local function EnsureSchema()
    if savedVariables.v ~= C.VERSION then
        savedVariables.v = C.VERSION
        savedVariables.e = false
        savedVariables.c = {}
        savedVariables.p = {}
        savedVariables.k = { t = 0, p = {} }
        savedVariables.m = { t = 0, p = {} }
        savedVariables.f = { t = 0, p = {} }
        savedVariables.h = {}
        savedVariables.x = {}
        savedVariables.u = {}
        GetDisplaySettings()
        return
    end
    savedVariables.e = savedVariables.e == true
    if type(savedVariables.c) ~= "table" then savedVariables.c = {} end
    if type(savedVariables.p) ~= "table" then savedVariables.p = {} end
    for characterKey, record in pairs(savedVariables.p) do
        if type(record) ~= "table" then
            savedVariables.p[characterKey] = nil
        else
            record.n = tostring(record.n or "")
            record.t = Number(record.t)
            if not IsPayload(record.b) then record.b = {} end
            if not IsPayload(record.w) then record.w = {} end
        end
    end
    if type(savedVariables.k) ~= "table" then savedVariables.k = { t = 0, p = {} } end
    savedVariables.k.t = Number(savedVariables.k.t)
    if not IsPayload(savedVariables.k.p) then savedVariables.k.p = {} end
    if type(savedVariables.m) ~= "table" then savedVariables.m = { t = 0, p = {} } end
    savedVariables.m.t = Number(savedVariables.m.t)
    if not IsPayload(savedVariables.m.p) then savedVariables.m.p = {} end
    if type(savedVariables.f) ~= "table" then savedVariables.f = { t = 0, p = {} } end
    savedVariables.f.t = Number(savedVariables.f.t)
    if not IsPayload(savedVariables.f.p) then savedVariables.f.p = {} end
    if type(savedVariables.h) ~= "table" then savedVariables.h = {} end
    for bagId, record in pairs(savedVariables.h) do
        if type(record) ~= "table" then
            savedVariables.h[bagId] = nil
        else
            record.t = Number(record.t)
            if not IsPayload(record.p) then record.p = {} end
        end
    end
    if type(savedVariables.x) ~= "table" then savedVariables.x = {} end
    GetDisplaySettings()
end

local function BuildBagLists()
    Clear(TRACKED_BAGS)
    Clear(BANK_BAGS)
    if BAG_BACKPACK ~= nil then TRACKED_BAGS[BAG_BACKPACK] = "b" end
    if BAG_WORN ~= nil then TRACKED_BAGS[BAG_WORN] = "w" end
    if BAG_VIRTUAL ~= nil then TRACKED_BAGS[BAG_VIRTUAL] = "m" end
    if BAG_BANK ~= nil then
        TRACKED_BAGS[BAG_BANK] = "k"
        BANK_BAGS[#BANK_BAGS + 1] = BAG_BANK
    end
    if BAG_SUBSCRIBER_BANK ~= nil then
        TRACKED_BAGS[BAG_SUBSCRIBER_BANK] = "k"
        BANK_BAGS[#BANK_BAGS + 1] = BAG_SUBSCRIBER_BANK
    end
    if BAG_FURNITURE_VAULT ~= nil then TRACKED_BAGS[BAG_FURNITURE_VAULT] = "f" end
    if BAG_HOUSE_BANK_ONE ~= nil and BAG_HOUSE_BANK_TEN ~= nil then
        for bagId = BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TEN do TRACKED_BAGS[bagId] = "h" end
    end
end

local function AddIdentityPart(value)
    identityParts[#identityParts + 1] = tostring(value or 0)
end

local function BuildVariantIdentity(itemLink, flags)
    Clear(identityParts)
    local itemType, specializedItemType = 0, 0
    if GetItemLinkItemType then itemType, specializedItemType = GetItemLinkItemType(itemLink) end
    local hasSet, setId = false, 0
    if GetItemLinkSetInfo then
        local setResult, _, _, _, _, resultSetId = GetItemLinkSetInfo(itemLink, false)
        hasSet, setId = setResult == true, Number(resultSetId)
    end
    local recipeListIndex, recipeIndex = 0, 0
    if GetItemLinkGrantedRecipeIndices then
        recipeListIndex, recipeIndex = GetItemLinkGrantedRecipeIndices(itemLink)
    end

    AddIdentityPart(SafeNumber(GetItemLinkItemId, itemLink))
    AddIdentityPart(itemType)
    AddIdentityPart(specializedItemType)
    AddIdentityPart(SafeNumber(GetItemLinkDisplayQuality, itemLink))
    AddIdentityPart(SafeNumber(GetItemLinkRequiredLevel, itemLink))
    AddIdentityPart(SafeNumber(GetItemLinkRequiredChampionPoints, itemLink))
    AddIdentityPart(SafeNumber(GetItemLinkTraitType, itemLink))
    AddIdentityPart(SafeNumber(GetItemLinkDefaultEnchantId, itemLink))
    AddIdentityPart(SafeNumber(GetItemLinkAppliedEnchantId, itemLink))
    AddIdentityPart(SafeNumber(GetItemLinkFinalEnchantId, itemLink))
    AddIdentityPart(SafeNumber(GetItemLinkItemStyle, itemLink))
    AddIdentityPart(SafeNumber(GetItemLinkOutfitStyleId, itemLink))
    AddIdentityPart(SafeNumber(GetItemLinkEquipType, itemLink))
    AddIdentityPart(SafeNumber(GetItemLinkArmorType, itemLink))
    AddIdentityPart(SafeNumber(GetItemLinkWeaponType, itemLink))
    AddIdentityPart(hasSet and setId or 0)
    AddIdentityPart(SafeNumber(GetItemLinkCombinationId, itemLink))
    AddIdentityPart(SafeNumber(GetItemLinkFurnitureDataId, itemLink))
    AddIdentityPart(recipeListIndex)
    AddIdentityPart(recipeIndex)
    AddIdentityPart(SafeBoolean(IsItemLinkCrafted, itemLink))
    AddIdentityPart(SafeNumber(GetItemLinkBindType, itemLink))
    AddIdentityPart(SafeBoolean(IsItemLinkBound, itemLink))
    AddIdentityPart(SafeBoolean(IsItemLinkStolen, itemLink))
    AddIdentityPart(SafeNumber(GetItemLinkActorCategory, itemLink))
    AddIdentityPart(flags)
    AddIdentityPart(GetItemLinkName and GetItemLinkName(itemLink) or "")
    if ITEMTYPE_MASTER_WRIT and itemType == ITEMTYPE_MASTER_WRIT and GenerateMasterWritBaseText then
        AddIdentityPart(GenerateMasterWritBaseText(itemLink))
    end
    return table.concat(identityParts, "\31")
end

local function GetSlotFlags(bagId, slotIndex, itemLink)
    local bindType = SafeNumber(GetItemBindType, bagId, slotIndex)
    local isBound = SafeBoolean(IsItemBound, bagId, slotIndex)
    local isStolen = SafeBoolean(IsItemLinkStolen, itemLink)
    return (bindType * 4) + isBound + (isStolen * 2)
end

local function FindCatalogId(identity)
    return catalogIdentityToId[identity]
end

local function AddCatalogLookup(identity, catalogId)
    if catalogIdentityToId[identity] == nil then catalogIdentityToId[identity] = catalogId end
end

local function RebuildCatalogLookup()
    Clear(catalogIdentityToId)
    local catalog = savedVariables and savedVariables.c or nil
    if not catalog then return end

    for catalogId = 1, #catalog do
        local itemLink, flags = Codec.UnpackVariant(catalog[catalogId], codecFields)
        if itemLink then
            local identity = BuildVariantIdentity(itemLink, flags)
            AddCatalogLookup(identity, catalogId)
        end
    end
    catalogLookupReady = true
end

local function GetOrCreateCatalogId(bagId, slotIndex, itemLink)
    if not catalogLookupReady then RebuildCatalogLookup() end
    local flags = GetSlotFlags(bagId, slotIndex, itemLink)
    local identity = BuildVariantIdentity(itemLink, flags)
    local catalogId = FindCatalogId(identity)
    if catalogId then return catalogId end

    local packed = Codec.PackVariant(itemLink, flags, codecBuffer, codecFields)
    if not packed then return nil end
    local catalog = savedVariables.c
    catalogId = #catalog + 1
    catalog[catalogId] = packed
    catalogCompactionNeeded = true
    AddCatalogLookup(identity, catalogId)
    return catalogId
end

local function GetCharacterRecord()
    local characterKey = GetCurrentCharacterKey()
    local record = savedVariables.p[characterKey]
    if type(record) ~= "table" then
        record = { n = GetCurrentCharacterName(), t = 0, b = {}, w = {} }
        savedVariables.p[characterKey] = record
    end
    record.n = GetCurrentCharacterName()
    if not IsPayload(record.b) then record.b = {} end
    if not IsPayload(record.w) then record.w = {} end
    record.t = Number(record.t)
    return record
end

local function GetHouseBankRecord(bagId)
    local record = savedVariables.h[bagId]
    if type(record) ~= "table" then
        record = { t = 0, p = {} }
        savedVariables.h[bagId] = record
    end
    record.t = Number(record.t)
    if not IsPayload(record.p) then record.p = {} end
    return record
end

local function AdjustCount(location, catalogId, delta)
    if not catalogId or delta == 0 then return end
    local counts = aggregates[location]
    local nextCount = (counts[catalogId] or 0) + delta
    counts[catalogId] = nextCount > 0 and nextCount or nil
end

local function ClearBagCache(bagId)
    if slotIds[bagId] then Clear(slotIds[bagId]) end
    if slotCounts[bagId] then Clear(slotCounts[bagId]) end
end

local function ReadSlot(bagId, slotIndex)
    local itemLink = GetItemLink and GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT) or ""
    if itemLink == "" then return nil, 0 end
    local count = GetSlotStackSize and Number(GetSlotStackSize(bagId, slotIndex)) or 1
    if count <= 0 then return nil, 0 end
    return GetOrCreateCatalogId(bagId, slotIndex, itemLink), count
end

local function EncodeLocation(location)
    return Codec.EncodeCountChunks(
        aggregates[location], C.PAYLOAD_CHUNK_LENGTH, codecBuffer, codecIds
    )
end

local function SaveLocation(record, key, location)
    -- Identical rescans update timestamps without rewriting payloads or forcing
    -- another account-wide compaction on the next zone transition.
    local payload = EncodeLocation(location)
    local previous = record[key]
    local changed = type(previous) ~= "table" or #previous ~= #payload
    if not changed then
        for index = 1, #payload do
            if previous[index] ~= payload[index] then changed = true break end
        end
    end
    if changed then
        record[key] = payload
        catalogCompactionNeeded = true
    end
end

local function NotifyDataChanged()
    if type(ItemLocator.RefreshBrowser) == "function" then ItemLocator.RefreshBrowser() end
end

local function FlushDirty()
    if not savedVariables then return end
    if dirty.b or dirty.w then
        local record = GetCharacterRecord()
        if dirty.b then SaveLocation(record, "b", "b") end
        if dirty.w then SaveLocation(record, "w", "w") end
    end
    if dirty.k then SaveLocation(savedVariables.k, "p", "k") end
    if dirty.m then SaveLocation(savedVariables.m, "p", "m") end
    if dirty.f then SaveLocation(savedVariables.f, "p", "f") end
    if dirty.h and houseBankBag then SaveLocation(GetHouseBankRecord(houseBankBag), "p", "h") end
    dirty.b, dirty.w, dirty.k, dirty.m, dirty.f, dirty.h = false, false, false, false, false, false
    NotifyDataChanged()
end

local function CancelUpdate(name)
    if EVENT_MANAGER and EVENT_MANAGER.UnregisterForUpdate then
        EVENT_MANAGER:UnregisterForUpdate(name)
    end
end

local function OnFlushUpdate()
    CancelUpdate(C.FLUSH_UPDATE)
    FlushDirty()
end

local function ScheduleFlush()
    if not EVENT_MANAGER or not EVENT_MANAGER.RegisterForUpdate then
        FlushDirty()
        return
    end
    CancelUpdate(C.FLUSH_UPDATE)
    EVENT_MANAGER:RegisterForUpdate(C.FLUSH_UPDATE, C.FLUSH_DELAY_MS, OnFlushUpdate)
end

local function ValidatePayloads(liveIds)
    Clear(liveIds)
    for _, record in pairs(savedVariables.p) do
        if type(record) == "table" then
            for _, key in ipairs({ "b", "w" }) do
                local decoded = Codec.DecodeCounts(record[key] or {}, decodeScratch)
                if not decoded then unavailableData = true return false end
                for catalogId in pairs(decoded) do liveIds[catalogId] = true end
            end
        end
    end
    local decoded = Codec.DecodeCounts(savedVariables.k.p or {}, decodeScratch)
    if not decoded then unavailableData = true return false end
    for catalogId in pairs(decoded) do liveIds[catalogId] = true end
    decoded = Codec.DecodeCounts(savedVariables.m.p or {}, decodeScratch)
    if not decoded then unavailableData = true return false end
    for catalogId in pairs(decoded) do liveIds[catalogId] = true end
    decoded = Codec.DecodeCounts(savedVariables.f.p or {}, decodeScratch)
    if not decoded then unavailableData = true return false end
    for catalogId in pairs(decoded) do liveIds[catalogId] = true end
    for _, record in pairs(savedVariables.h) do
        decoded = Codec.DecodeCounts(record.p or {}, decodeScratch)
        if not decoded then unavailableData = true return false end
        for catalogId in pairs(decoded) do liveIds[catalogId] = true end
    end
    return true
end

local function RemapMap(values, remap)
    Clear(remapScratch)
    for oldId, count in pairs(values) do
        local newId = remap[oldId]
        if newId then remapScratch[newId] = (remapScratch[newId] or 0) + count end
    end
    Clear(values)
    for newId, count in pairs(remapScratch) do values[newId] = count end
end

local function RemapRuntime(remap)
    RemapMap(aggregates.b, remap)
    RemapMap(aggregates.w, remap)
    RemapMap(aggregates.k, remap)
    RemapMap(aggregates.m, remap)
    RemapMap(aggregates.f, remap)
    RemapMap(aggregates.h, remap)
    for _, ids in pairs(slotIds) do
        for slotIndex, oldId in pairs(ids) do ids[slotIndex] = remap[oldId] end
    end
end

CompactCatalog = function()
    if not catalogCompactionNeeded then return true end
    local liveIds = {}
    if not ValidatePayloads(liveIds) then return false end

    local identityRecords = {}
    local oldIdentity = {}
    for oldId in pairs(liveIds) do
        local packed = savedVariables.c[oldId]
        local itemLink, flags = Codec.UnpackVariant(packed, codecFields)
        if not itemLink then return false end
        local identity = BuildVariantIdentity(itemLink, flags)
        oldIdentity[oldId] = identity
        local existing = identityRecords[identity]
        if not existing or packed < existing then identityRecords[identity] = packed end
    end

    local identities = {}
    for identity in pairs(identityRecords) do identities[#identities + 1] = identity end
    table.sort(identities)
    local newCatalog, identityToNew, remap = {}, {}, {}
    for newId = 1, #identities do
        local identity = identities[newId]
        newCatalog[newId] = identityRecords[identity]
        identityToNew[identity] = newId
    end
    for oldId, identity in pairs(oldIdentity) do remap[oldId] = identityToNew[identity] end

    for _, record in pairs(savedVariables.p) do
        if type(record) == "table" then
            record.b = Codec.ChunkString(
                Codec.RemapCounts(record.b or {}, remap, decodeScratch, remapScratch) or "",
                C.PAYLOAD_CHUNK_LENGTH
            )
            record.w = Codec.ChunkString(
                Codec.RemapCounts(record.w or {}, remap, decodeScratch, remapScratch) or "",
                C.PAYLOAD_CHUNK_LENGTH
            )
        end
    end
    savedVariables.k.p = Codec.ChunkString(
        Codec.RemapCounts(savedVariables.k.p or {}, remap, decodeScratch, remapScratch) or "",
        C.PAYLOAD_CHUNK_LENGTH
    )
    savedVariables.m.p = Codec.ChunkString(
        Codec.RemapCounts(savedVariables.m.p or {}, remap, decodeScratch, remapScratch) or "",
        C.PAYLOAD_CHUNK_LENGTH
    )
    savedVariables.f.p = Codec.ChunkString(
        Codec.RemapCounts(savedVariables.f.p or {}, remap, decodeScratch, remapScratch) or "",
        C.PAYLOAD_CHUNK_LENGTH
    )
    for _, record in pairs(savedVariables.h) do
        record.p = Codec.ChunkString(
            Codec.RemapCounts(record.p or {}, remap, decodeScratch, remapScratch) or "",
            C.PAYLOAD_CHUNK_LENGTH
        )
    end
    savedVariables.c = newCatalog
    RemapRuntime(remap)
    catalogIdentityToId = identityToNew
    catalogLookupReady = true
    catalogCompactionNeeded = false
    return true
end

local function GetScanTimeMilliseconds()
    if GetGameTimeMilliseconds then return Number(GetGameTimeMilliseconds()) end
    if GetFrameTimeMilliseconds then return Number(GetFrameTimeMilliseconds()) end
    return 0
end

local function IsScanAccessible(job)
    if job.kind == "character" then
        return job.characterKey == GetCurrentCharacterKey()
    end
    if job.location == "k" then return bankOpen end
    if job.location == "f" then return furnitureVaultOpen end
    return houseBankBag == job.targetBag
end

local function ScanContainsBag(job, bagId)
    for index = 1, #job.bags do
        if job.bags[index] == bagId then return true end
    end
    return false
end

local function BeginNextScanBag(job)
    job.bagIndex = job.bagIndex + 1
    local bagId = job.bags[job.bagIndex]
    if bagId == nil then
        job.currentBag = nil
        return false
    end
    job.currentBag = bagId
    job.slotRefs[bagId] = {}
    job.slotCounts[bagId] = {}
    job.lastSparseSlot = nil
    job.nextSlot = 0
    if BAG_VIRTUAL ~= nil and bagId == BAG_VIRTUAL and type(GetNextVirtualBagSlotId) == "function" then
        job.sparseApi = GetNextVirtualBagSlotId
    elseif BAG_FURNITURE_VAULT ~= nil and bagId == BAG_FURNITURE_VAULT
        and type(GetNextFurnitureVaultSlotId) == "function" then
        job.sparseApi = GetNextFurnitureVaultSlotId
    else
        job.sparseApi = nil
    end
    job.bagSize = job.sparseApi and 0 or (GetBagSize and Number(GetBagSize(bagId)) or 0)
    return true
end

local function GetNextScanSlot(job)
    while job.currentBag or BeginNextScanBag(job) do
        local bagId = job.currentBag
        if job.sparseApi then
            local slotIndex = job.sparseApi(job.lastSparseSlot)
            if slotIndex ~= nil then
                job.lastSparseSlot = slotIndex
                return bagId, slotIndex
            end
        elseif job.nextSlot < job.bagSize then
            local slotIndex = job.nextSlot
            job.nextSlot = slotIndex + 1
            return bagId, slotIndex
        end
        job.currentBag = nil
    end
    return nil
end

local function ProcessScanSlot(job, bagId, slotIndex)
    local itemLink = GetItemLink and GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT) or ""
    if itemLink == "" then return end
    local count = GetSlotStackSize and Number(GetSlotStackSize(bagId, slotIndex)) or 1
    if count <= 0 then return end
    local flags = GetSlotFlags(bagId, slotIndex, itemLink)
    local identity = BuildVariantIdentity(itemLink, flags)
    local ref = job.identityToRef[identity]
    if not ref then
        ref = #job.identities + 1
        job.identities[ref] = identity
        job.identityToRef[identity] = ref
        job.catalogIds[ref] = FindCatalogId(identity)
        if not job.catalogIds[ref] then
            job.packed[ref] = Codec.PackVariant(itemLink, flags, codecBuffer, codecFields)
        end
        if not job.catalogIds[ref] and not job.packed[ref] then
            job.identities[ref] = nil
            job.identityToRef[identity] = nil
            return
        end
    end
    local location = job.bagLocations[bagId]
    local refCounts = job.refCounts[location]
    refCounts[ref] = (refCounts[ref] or 0) + count
    job.slotRefs[bagId][slotIndex] = ref
    job.slotCounts[bagId][slotIndex] = count
end

local function CommitScanRuntime(job)
    local refToCatalogId = {}
    for ref = 1, #job.identities do
        local catalogId = job.catalogIds[ref]
        if not catalogId then catalogId = FindCatalogId(job.identities[ref]) end
        if not catalogId then
            catalogId = #savedVariables.c + 1
            savedVariables.c[catalogId] = job.packed[ref]
            catalogCompactionNeeded = true
            AddCatalogLookup(job.identities[ref], catalogId)
        end
        refToCatalogId[ref] = catalogId
    end

    for index = 1, #job.locations do
        local location = job.locations[index]
        Clear(aggregates[location])
        for ref, count in pairs(job.refCounts[location]) do
            aggregates[location][refToCatalogId[ref]] = count
        end
    end
    for index = 1, #job.bags do
        local bagId = job.bags[index]
        local refs = job.slotRefs[bagId]
        for slotIndex, ref in pairs(refs) do refs[slotIndex] = refToCatalogId[ref] end
        ClearBagCache(bagId)
        slotIds[bagId] = refs
        slotCounts[bagId] = job.slotCounts[bagId]
    end
end

local function CommitCharacterScan(job)
    CommitScanRuntime(job)

    local timestamp = GetTimeStamp and Number(GetTimeStamp()) or 0
    local record = GetCharacterRecord()
    record.t = timestamp
    SaveLocation(record, "b", "b")
    SaveLocation(record, "w", "w")
    dirty.b, dirty.w = false, false
    if job.refCounts.m then
        savedVariables.m.t = timestamp
        SaveLocation(savedVariables.m, "p", "m")
        dirty.m = false
    end
    characterCacheReady = true
    RequestPrioritySave()
    NotifyDataChanged()
end

local function CommitStorageScan(job)
    CommitScanRuntime(job)

    local timestamp = GetTimeStamp and Number(GetTimeStamp()) or 0
    local location = job.location
    if location == "k" then
        savedVariables.k.t = timestamp
        SaveLocation(savedVariables.k, "p", "k")
        dirty.k = false
        bankCacheReady = bankOpen
    elseif location == "f" then
        savedVariables.f.t = timestamp
        SaveLocation(savedVariables.f, "p", "f")
        dirty.f = false
        furnitureVaultCacheReady = furnitureVaultOpen
    else
        local record = GetHouseBankRecord(job.targetBag)
        record.t = timestamp
        SaveLocation(record, "p", "h")
        dirty.h = false
        houseBankCacheReady = houseBankBag == job.targetBag
    end
    RequestPrioritySave()
    NotifyDataChanged()
end

local function CreateScanJob(kind, bags, bagLocations, targetBag)
    local job = {
        kind = kind,
        targetBag = targetBag,
        bags = bags,
        bagLocations = bagLocations,
        locations = {},
        bagIndex = 0,
        identities = {},
        identityToRef = {},
        catalogIds = {},
        packed = {},
        refCounts = {},
        slotRefs = {},
        slotCounts = {},
    }
    for index = 1, #bags do
        local location = bagLocations[bags[index]]
        if not job.refCounts[location] then
            job.locations[#job.locations + 1] = location
            job.refCounts[location] = {}
        end
    end
    return job
end

local function ProcessScanUpdate(job)
    local startedAt = GetScanTimeMilliseconds()
    local processed = 0
    while processed < C.SCAN_MAX_SLOTS_PER_FRAME do
        local bagId, slotIndex = GetNextScanSlot(job)
        if not bagId then return true end
        ProcessScanSlot(job, bagId, slotIndex)
        processed = processed + 1
        if GetScanTimeMilliseconds() - startedAt >= C.SCAN_BUDGET_MS then return false end
    end
    return false
end

CancelCharacterScan = function()
    CancelUpdate(C.CHARACTER_SCAN_UPDATE)
    characterScanJob = nil
end

CancelStorageScan = function()
    CancelUpdate(C.STORAGE_SCAN_UPDATE)
    storageScanJob = nil
end

local function OnCharacterScanUpdate()
    local job = characterScanJob
    if not job or not savedVariables or not savedVariables.e or not IsScanAccessible(job) then
        CancelCharacterScan()
        return
    end
    if not ProcessScanUpdate(job) then return end

    local needsRescan = job.needsRescan
    CancelCharacterScan()
    if needsRescan then StartCharacterScan() else CommitCharacterScan(job) end
end

local function OnStorageScanUpdate()
    local job = storageScanJob
    if not job or not savedVariables or not savedVariables.e or not IsScanAccessible(job) then
        CancelStorageScan()
        return
    end
    if not ProcessScanUpdate(job) then return end

    local location, targetBag, needsRescan = job.location, job.targetBag, job.needsRescan
    CancelStorageScan()
    if needsRescan and ((location == "k" and bankOpen) or (location == "f" and furnitureVaultOpen)
        or (location == "h" and houseBankBag == targetBag)) then
        StartStorageScan(location, targetBag)
    else
        CommitStorageScan(job)
    end
end

StartCharacterScan = function()
    CancelCharacterScan()
    characterCacheReady = false
    if not savedVariables or not savedVariables.e then return end
    if not catalogLookupReady then RebuildCatalogLookup() end

    local bags, bagLocations = {}, {}
    if BAG_BACKPACK ~= nil then
        bags[#bags + 1] = BAG_BACKPACK
        bagLocations[BAG_BACKPACK] = "b"
    end
    if BAG_WORN ~= nil then
        bags[#bags + 1] = BAG_WORN
        bagLocations[BAG_WORN] = "w"
    end
    if BAG_VIRTUAL ~= nil then
        bags[#bags + 1] = BAG_VIRTUAL
        bagLocations[BAG_VIRTUAL] = "m"
    end
    if #bags == 0 then return end

    characterScanJob = CreateScanJob("character", bags, bagLocations)
    characterScanJob.characterKey = GetCurrentCharacterKey()
    EVENT_MANAGER:RegisterForUpdate(C.CHARACTER_SCAN_UPDATE, 0, OnCharacterScanUpdate)
end

StartStorageScan = function(location, targetBag)
    CancelStorageScan()
    if not savedVariables or not savedVariables.e then return end
    if not catalogLookupReady then RebuildCatalogLookup() end
    local bags = {}
    if location == "k" then
        for index = 1, #BANK_BAGS do bags[index] = BANK_BAGS[index] end
    elseif targetBag ~= nil then
        bags[1] = targetBag
    end
    if #bags == 0 then return end
    local bagLocations = {}
    for index = 1, #bags do bagLocations[bags[index]] = location end
    storageScanJob = CreateScanJob("storage", bags, bagLocations, targetBag)
    storageScanJob.location = location
    EVENT_MANAGER:RegisterForUpdate(C.STORAGE_SCAN_UPDATE, 0, OnStorageScanUpdate)
end

local function ScanBank()
    if not savedVariables or not savedVariables.e or not bankOpen then return end
    StartStorageScan("k")
end

local function ScanFurnitureVault()
    if not savedVariables or not savedVariables.e or not furnitureVaultOpen
        or BAG_FURNITURE_VAULT == nil then return end
    StartStorageScan("f", BAG_FURNITURE_VAULT)
end

local function ScanHouseBank()
    if not savedVariables or not savedVariables.e or not houseBankBag then return end
    StartStorageScan("h", houseBankBag)
end

local function OnInventorySlotUpdate(_, bagId, slotIndex)
    if not savedVariables.e then return end
    local location = TRACKED_BAGS[bagId]
    if not location or (location == "k" and not bankOpen)
        or (location == "f" and not furnitureVaultOpen)
        or (location == "h" and bagId ~= houseBankBag) then return end
    if characterScanJob and ScanContainsBag(characterScanJob, bagId) then
        characterScanJob.needsRescan = true
        return
    end
    if storageScanJob and storageScanJob.location == location
        and ScanContainsBag(storageScanJob, bagId) then
        storageScanJob.needsRescan = true
        return
    end
    if (location == "k" and not bankCacheReady)
        or (location == "f" and not furnitureVaultCacheReady)
        or (location == "h" and not houseBankCacheReady)
        or ((location == "b" or location == "w" or location == "m") and not characterCacheReady) then return end

    local ids = slotIds[bagId] or {}
    local counts = slotCounts[bagId] or {}
    slotIds[bagId], slotCounts[bagId] = ids, counts
    local oldId, oldCount = ids[slotIndex], counts[slotIndex] or 0
    if oldId then AdjustCount(location, oldId, -oldCount) end

    local newId, newCount = ReadSlot(bagId, slotIndex)
    ids[slotIndex], counts[slotIndex] = newId, newId and newCount or nil
    if newId then AdjustCount(location, newId, newCount) end
    dirty[location] = true
    ScheduleFlush()
end

local function OnFullScanUpdate()
    CancelUpdate(C.FULL_SCAN_UPDATE)
    StartCharacterScan()
    if bankOpen then ScanBank() end
    if furnitureVaultOpen then ScanFurnitureVault() end
    if houseBankBag then ScanHouseBank() end
end

local function OnInventoryFullUpdate()
    if not savedVariables.e then return end
    CancelUpdate(C.FULL_SCAN_UPDATE)
    EVENT_MANAGER:RegisterForUpdate(C.FULL_SCAN_UPDATE, C.RESCAN_DELAY_MS, OnFullScanUpdate)
end

local function OnBankScanUpdate()
    CancelUpdate(C.BANK_SCAN_UPDATE)
    if bankOpen then
        ScanBank()
    elseif furnitureVaultOpen then
        ScanFurnitureVault()
    elseif houseBankBag then
        ScanHouseBank()
    end
end

local function IsFurnitureVaultBag(bagId)
    if bagId == nil then return false end
    if type(IsFurnitureVault) == "function" then return IsFurnitureVault(bagId) == true end
    return BAG_FURNITURE_VAULT ~= nil and bagId == BAG_FURNITURE_VAULT
end

local function IsHouseStorageBag(bagId)
    if bagId == nil or IsFurnitureVaultBag(bagId) then return false end
    if type(IsHouseBankBag) == "function" then return IsHouseBankBag(bagId) == true end
    return BAG_HOUSE_BANK_ONE ~= nil and BAG_HOUSE_BANK_TEN ~= nil
        and bagId >= BAG_HOUSE_BANK_ONE and bagId <= BAG_HOUSE_BANK_TEN
end

local function SetOpenBankBag(bankBag)
    bankOpen = bankBag ~= nil and (bankBag == BAG_BANK or bankBag == BAG_SUBSCRIBER_BANK)
    furnitureVaultOpen = IsFurnitureVaultBag(bankBag)
    houseBankBag = IsHouseStorageBag(bankBag) and bankBag or nil
    bankCacheReady, furnitureVaultCacheReady, houseBankCacheReady = false, false, false
end

local function RefreshOpenBankBag()
    if IsBankOpen and IsBankOpen() then
        SetOpenBankBag(GetBankingBag and GetBankingBag() or BAG_BANK)
    else
        bankOpen, furnitureVaultOpen = false, false
        houseBankBag = nil
        bankCacheReady, furnitureVaultCacheReady, houseBankCacheReady = false, false, false
    end
end

local function OnOpenBank(_, bankBag)
    if not savedVariables.e then return end
    CancelStorageScan()
    if dirty.k or dirty.f or dirty.h then FlushDirty() end
    SetOpenBankBag(bankBag)
    CancelUpdate(C.BANK_SCAN_UPDATE)
    if bankOpen or furnitureVaultOpen or houseBankBag then
        EVENT_MANAGER:RegisterForUpdate(C.BANK_SCAN_UPDATE, C.RESCAN_DELAY_MS, OnBankScanUpdate)
    end
end

local function OnCloseBank()
    if not savedVariables.e then return end
    CancelUpdate(C.BANK_SCAN_UPDATE)
    CancelStorageScan()
    if dirty.k or dirty.f or dirty.h then FlushDirty() end
    Clear(aggregates.k)
    Clear(aggregates.f)
    Clear(aggregates.h)
    for index = 1, #BANK_BAGS do ClearBagCache(BANK_BAGS[index]) end
    if BAG_FURNITURE_VAULT ~= nil then ClearBagCache(BAG_FURNITURE_VAULT) end
    if houseBankBag then ClearBagCache(houseBankBag) end
    bankOpen, furnitureVaultOpen = false, false
    houseBankBag = nil
    bankCacheReady, furnitureVaultCacheReady, houseBankCacheReady = false, false, false
end

local function OnPlayerDeactivated()
    -- Preserve the last complete snapshots until activation can finish a new
    -- baseline. Slot events during loading must not write partial aggregates.
    characterCacheReady = false
    CancelCharacterScan()
    CancelStorageScan()
    CancelUpdate(C.FLUSH_UPDATE)
    CancelUpdate(C.FULL_SCAN_UPDATE)
    CancelUpdate(C.BANK_SCAN_UPDATE)
    if dirty.b or dirty.w or dirty.k or dirty.m or dirty.f or dirty.h then FlushDirty() end
    OnCloseBank()
    CompactCatalog()
end

local function OnPlayerActivated()
    if not savedVariables or not savedVariables.e then return end
    RefreshOpenBankBag()
    StartCharacterScan()
    if bankOpen then ScanBank() end
    if furnitureVaultOpen then ScanFurnitureVault() end
    if houseBankBag then ScanHouseBank() end
end

local function RegisterEvents()
    if eventsRegistered or not EVENT_MANAGER then return end
    EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlotUpdate)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_INVENTORY_FULL_UPDATE, OnInventoryFullUpdate)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_OPEN_BANK, OnOpenBank)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_CLOSE_BANK, OnCloseBank)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated)
    EVENT_MANAGER:RegisterForEvent(C.EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    eventsRegistered = true
end

local function UnregisterEvents()
    if not eventsRegistered or not EVENT_MANAGER then return end
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_NAMESPACE, EVENT_INVENTORY_FULL_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_NAMESPACE, EVENT_OPEN_BANK)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_NAMESPACE, EVENT_CLOSE_BANK)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_NAMESPACE, EVENT_PLAYER_DEACTIVATED)
    EVENT_MANAGER:UnregisterForEvent(C.EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED)
    CancelUpdate(C.FLUSH_UPDATE)
    CancelUpdate(C.FULL_SCAN_UPDATE)
    CancelUpdate(C.BANK_SCAN_UPDATE)
    CancelCharacterScan()
    CancelStorageScan()
    eventsRegistered = false
end

local function ClearRuntime()
    characterCacheReady = false
    CancelCharacterScan()
    CancelStorageScan()
    Clear(aggregates.b)
    Clear(aggregates.w)
    Clear(aggregates.k)
    Clear(aggregates.m)
    Clear(aggregates.f)
    Clear(aggregates.h)
    for bagId in pairs(slotIds) do ClearBagCache(bagId) end
    Clear(slotIds)
    Clear(slotCounts)
    Clear(catalogIdentityToId)
    catalogLookupReady = false
    dirty.b, dirty.w, dirty.k, dirty.m, dirty.f, dirty.h = false, false, false, false, false, false
    bankOpen, furnitureVaultOpen = false, false
    houseBankBag = nil
    bankCacheReady, furnitureVaultCacheReady, houseBankCacheReady = false, false, false
end

local function DecodeLocation(encoded, callback)
    local counts = Codec.DecodeCounts(encoded or "", decodeScratch)
    if not counts then unavailableData = true return false end
    for catalogId, count in pairs(counts) do callback(catalogId, count) end
    return true
end

local function FormatItemName(itemLink)
    local name = GetItemLinkName and GetItemLinkName(itemLink) or ""
    if zo_strformat and SI_TOOLTIP_ITEM_NAME then name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name) end
    return name
end

local function BuildGamepadCategoryIdsByLabel()
    local result = {}
    if not GetString then return result end
    local maximum = tonumber(GAMEPAD_ITEM_CATEGORY_COMPANION_WAIST) or 55
    for categoryId = 0, maximum do
        local label = GetString("SI_GAMEPADITEMCATEGORY", categoryId)
        if type(label) == "string" and label ~= "" then result[label] = categoryId end
    end
    return result
end

local function GetItemCategory(itemLink, categoryIdsByLabel)
    local itemType = 0
    local specializedItemType = 0
    if GetItemLinkItemType then itemType, specializedItemType = GetItemLinkItemType(itemLink) end
    local itemData = {
        itemType = itemType,
        specializedItemType = specializedItemType,
        equipType = SafeNumber(GetItemLinkEquipType, itemLink),
        armorType = SafeNumber(GetItemLinkArmorType, itemLink),
        weaponType = SafeNumber(GetItemLinkWeaponType, itemLink),
        actorCategory = SafeNumber(GetItemLinkActorCategory, itemLink),
        itemLink = itemLink,
    }
    local category
    if ZO_InventoryUtils_Gamepad_GetBestItemCategoryDescription then
        category = ZO_InventoryUtils_Gamepad_GetBestItemCategoryDescription(itemData)
    elseif GetString then
        category = GetString("SI_ITEMTYPE", itemType)
    else
        category = NGear.L("common.other")
    end
    local categoryId = categoryIdsByLabel[category]
    return category, categoryId ~= nil and ("g" .. tostring(categoryId)) or ("i" .. tostring(itemType))
end

local function AddBrowserLocation(recordsById, categoryIdsByLabel, catalogId, count, characterName, kind, scannedAt)
    if count <= 0 then return end
    local record = recordsById[catalogId]
    if not record then
        local itemLink, flags = Codec.UnpackVariant(savedVariables.c[catalogId], codecFields)
        if not itemLink then unavailableData = true return end
        local name = FormatItemName(itemLink)
        local category, categoryKey = GetItemCategory(itemLink, categoryIdsByLabel)
        record = {
            id = catalogId,
            link = itemLink,
            flags = flags,
            name = name,
            needle = NGear.Util.Lower(name),
            category = category,
            categoryKey = categoryKey,
            quality = SafeNumber(GetItemLinkDisplayQuality, itemLink),
            total = 0,
            locations = {},
        }
        recordsById[catalogId] = record
    end
    record.total = record.total + count
    local locations = record.locations
    locations[#locations + 1] = characterName
    locations[#locations + 1] = kind
    locations[#locations + 1] = count
    locations[#locations + 1] = Number(scannedAt)
end

function ItemLocator.InitializeSavedVariables()
    savedVariables = NGear.Settings.GetAccountWideSection(C.NAMESPACE)
    EnsureSchema()
    catalogCompactionNeeded = true
end

function ItemLocator.Initialize()
    if initialized then return end
    initialized = true
    BuildBagLists()
    if savedVariables.e then
        RegisterEvents()
        RefreshOpenBankBag()
        StartCharacterScan()
        if bankOpen then ScanBank() end
        if furnitureVaultOpen then ScanFurnitureVault() end
        if houseBankBag then ScanHouseBank() end
    end
end

function ItemLocator.IsEnabled()
    return savedVariables and savedVariables.e == true
end

function ItemLocator.SetEnabled(value)
    if not savedVariables then return end
    value = value == true
    if savedVariables.e == value then return end
    savedVariables.e = value
    if value then
        BuildBagLists()
        RegisterEvents()
        RefreshOpenBankBag()
        StartCharacterScan()
        if bankOpen then ScanBank() end
        if furnitureVaultOpen then ScanFurnitureVault() end
        if houseBankBag then ScanHouseBank() end
    else
        CancelUpdate(C.FLUSH_UPDATE)
        if dirty.b or dirty.w or dirty.k or dirty.m or dirty.f or dirty.h then FlushDirty() end
        UnregisterEvents()
        CompactCatalog()
        ClearRuntime()
        NotifyDataChanged()
    end
    RequestPrioritySave()
end

function ItemLocator.ClearData()
    if not savedVariables then return end
    savedVariables.c = {}
    savedVariables.p = {}
    savedVariables.k = { t = 0, p = {} }
    savedVariables.m = { t = 0, p = {} }
    savedVariables.f = { t = 0, p = {} }
    savedVariables.h = {}
    catalogCompactionNeeded = false
    ClearRuntime()
    if savedVariables.e then
        BuildBagLists()
        RegisterEvents()
        RefreshOpenBankBag()
        StartCharacterScan()
        if bankOpen then ScanBank() end
        if furnitureVaultOpen then ScanFurnitureVault() end
        if houseBankBag then ScanHouseBank() end
    end
    RequestPrioritySave()
    NotifyDataChanged()
end

function ItemLocator.HasData()
    if not savedVariables then return false end
    if type(savedVariables.k) == "table" and #savedVariables.k.p > 0 then return true end
    if type(savedVariables.m) == "table" and #savedVariables.m.p > 0 then return true end
    if type(savedVariables.f) == "table" and #savedVariables.f.p > 0 then return true end
    for _, record in pairs(savedVariables.h) do
        if type(record) == "table" and #record.p > 0 then return true end
    end
    for _, record in pairs(savedVariables.p) do
        if type(record) == "table" and (#record.b > 0 or #record.w > 0) then return true end
    end
    return false
end

function ItemLocator.HasUnavailableData()
    return unavailableData
end

function ItemLocator.GetMarketPriceData(itemLink)
    local priceApi = rawget(_G, "TSCPriceDataAPI")
    if type(priceApi) ~= "table" or type(priceApi.GetItemData) ~= "function" then return nil end
    local succeeded, itemData = pcall(priceApi.GetItemData, priceApi, itemLink)
    if not succeeded or itemData == priceApi.LOADING or type(itemData) ~= "table" then return nil end
    local minimum = tonumber(itemData.commonMin or itemData.legacyMin)
    local average = tonumber(itemData.avgPrice or itemData.legacyAvg)
    local maximum = tonumber(itemData.commonMax or itemData.legacyMax)
    if not minimum or not average or not maximum then return nil end
    return minimum, average, maximum
end

function ItemLocator.IsCategoryVisible(categoryKey)
    return not savedVariables or savedVariables.x[categoryKey] ~= true
end

function ItemLocator.SetCategoryVisible(categoryKey, visible)
    if not savedVariables or type(categoryKey) ~= "string" or categoryKey == "" then return end
    if visible == false then
        savedVariables.x[categoryKey] = true
    else
        savedVariables.x[categoryKey] = nil
    end
    RequestPrioritySave()
    NotifyDataChanged()
end

function ItemLocator.ResetCategoryVisibility()
    if not savedVariables then return end
    savedVariables.x = {}
    RequestPrioritySave()
    NotifyDataChanged()
end

function ItemLocator.ResetDisplaySettings()
    local settings = GetDisplaySettings()
    for key, value in pairs(DISPLAY_DEFAULTS) do settings[key] = value end
    RefreshDisplay()
end

function ItemLocator.GetHorizontalPosition() return GetDisplaySettings().x end
function ItemLocator.SetHorizontalPosition(value) GetDisplaySettings().x = NGear.Util.Clamp(value, 0, 100); RefreshDisplay() end
function ItemLocator.GetVerticalPosition() return GetDisplaySettings().y end
function ItemLocator.SetVerticalPosition(value) GetDisplaySettings().y = NGear.Util.Clamp(value, 0, 100); RefreshDisplay() end
function ItemLocator.GetFontChoices() return NGear.Util.GetFontChoices() end
function ItemLocator.GetFontChoiceNames() return NGear.Util.GetFontChoiceNames() end
function ItemLocator.GetFont() return GetDisplaySettings().f end
function ItemLocator.SetFont(value) if not NGear.Util.IsFontChoice(value) then value = DISPLAY_DEFAULTS.f end; GetDisplaySettings().f = value; RefreshDisplay() end
function ItemLocator.GetScale() return GetDisplaySettings().s end
function ItemLocator.SetScale(value) GetDisplaySettings().s = NGear.Util.Clamp(NGear.Util.Round(value), C.DISPLAY_SCALE_MIN, C.DISPLAY_SCALE_MAX); RefreshDisplay() end
function ItemLocator.GetScaleMin() return C.DISPLAY_SCALE_MIN end
function ItemLocator.GetScaleMax() return C.DISPLAY_SCALE_MAX end
function ItemLocator.GetBackgroundOpacity() return GetDisplaySettings().o end
function ItemLocator.SetBackgroundOpacity(value) GetDisplaySettings().o = NGear.Util.Clamp(NGear.Util.Round(value), C.DISPLAY_OPACITY_MIN, C.DISPLAY_OPACITY_MAX); RefreshDisplay() end
function ItemLocator.GetBackgroundOpacityMin() return C.DISPLAY_OPACITY_MIN end
function ItemLocator.GetBackgroundOpacityMax() return C.DISPLAY_OPACITY_MAX end
function ItemLocator.GetSortMode() return GetDisplaySettings().r end
function ItemLocator.SetSortMode(value)
    GetDisplaySettings().r = Number(value) == C.SORT_QUALITY and C.SORT_QUALITY or C.SORT_ALPHABETICAL
    RequestPrioritySave()
end

function ItemLocator.GetHorizontalPositionLabel() return NGear.L("item_locator.horizontal_position_label") end
function ItemLocator.GetHorizontalPositionTooltip() return NGear.L("item_locator.horizontal_position_tooltip") end
function ItemLocator.GetVerticalPositionLabel() return NGear.L("item_locator.vertical_position_label") end
function ItemLocator.GetVerticalPositionTooltip() return NGear.L("item_locator.vertical_position_tooltip") end
function ItemLocator.GetFontLabel() return NGear.L("item_locator.font_label") end
function ItemLocator.GetFontTooltip() return NGear.L("item_locator.font_tooltip") end
function ItemLocator.GetScaleLabel() return NGear.L("item_locator.scale_label") end
function ItemLocator.GetScaleTooltip() return NGear.L("item_locator.scale_tooltip") end
function ItemLocator.GetBackgroundOpacityLabel() return NGear.L("item_locator.background_opacity_label") end
function ItemLocator.GetBackgroundOpacityTooltip() return NGear.L("item_locator.background_opacity_tooltip") end

local function FormatRosterDate(timestamp)
    if not GetDateElementsFromTimestamp then
        return GetDateStringFromTimestamp and GetDateStringFromTimestamp(timestamp) or tostring(timestamp)
    end
    local year, month, day = GetDateElementsFromTimestamp(timestamp)
    local monthName = tostring(month or "")
    local monthIndex = 0
    for abbreviation in string.gmatch(NGear.L("item_locator.date_month_abbreviations"), "[^|]+") do
        monthIndex = monthIndex + 1
        if monthIndex == month then
            monthName = abbreviation
            break
        end
    end
    return NGear.L("item_locator.roster_date", string.format("%02d", day or 0), monthName, tostring(year or ""))
end

local function AddTooltipRosterLine(lines, name, timestamp)
    timestamp = Number(timestamp)
    local status = timestamp > 0 and FormatRosterDate(timestamp) or NGear.L("item_locator.roster_not_indexed")
    lines[#lines + 1] = NGear.L("item_locator.roster_scanned", name, status)
end

local function AddHouseStorageEntry(storage, seen, bagId)
    bagId = Number(bagId)
    if bagId <= 0 or seen[bagId] then return end

    local record = savedVariables and savedVariables.h
        and (savedVariables.h[bagId] or savedVariables.h[tostring(bagId)])
    local collectibleId = GetCollectibleForBag and Number(GetCollectibleForBag(bagId)) or 0
    local active = type(record) == "table"
    if not active and collectibleId > 0 then
        active = type(IsCollectibleUnlocked) ~= "function" or IsCollectibleUnlocked(collectibleId) == true
    end
    if not active then return end

    seen[bagId] = true
    storage[#storage + 1] = {
        b = bagId,
        n = GetHouseStorageName(bagId),
        t = type(record) == "table" and record.t or 0,
    }
end

local function GetActiveCharacterRoster()
    local roster = {}
    if type(GetNumCharacters) ~= "function" or type(GetCharacterInfo) ~= "function" then return roster end

    for index = 1, Number(GetNumCharacters()) do
        local name, _, _, _, _, _, characterId = GetCharacterInfo(index)
        local key = tostring(characterId or "")
        if key ~= "" then
            local record = savedVariables and savedVariables.p and savedVariables.p[key]
            roster[#roster + 1] = {
                k = key,
                n = GetCharacterName(name),
                t = type(record) == "table" and Number(record.t) or 0,
            }
        end
    end
    table.sort(roster, function(left, right)
        local leftName, rightName = NGear.Util.Lower(left.n), NGear.Util.Lower(right.n)
        return leftName == rightName and left.k < right.k or leftName < rightName
    end)
    return roster
end

function ItemLocator.GetRosterTooltip()
    local accountLines, characterLines = {}, {}
    AddTooltipRosterLine(accountLines, GetBankName(), savedVariables and savedVariables.k and savedVariables.k.t)
    AddTooltipRosterLine(accountLines, GetCraftBagName(), savedVariables and savedVariables.m and savedVariables.m.t)

    local storage, seenStorage = {}, {}
    if type(BAG_HOUSE_BANK_ONE) == "number" and type(BAG_HOUSE_BANK_TEN) == "number" then
        for bagId = BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TEN do
            AddHouseStorageEntry(storage, seenStorage, bagId)
        end
    end
    if savedVariables and savedVariables.h then
        for bagId in pairs(savedVariables.h) do
            AddHouseStorageEntry(storage, seenStorage, bagId)
        end
    end
    table.sort(storage, function(left, right)
        local leftName, rightName = NGear.Util.Lower(left.n), NGear.Util.Lower(right.n)
        return leftName == rightName and left.b < right.b or leftName < rightName
    end)
    for index = 1, #storage do
        local entry = storage[index]
        AddTooltipRosterLine(accountLines, entry.n, entry.t)
    end
    AddTooltipRosterLine(accountLines, GetFurnitureVaultName(), savedVariables and savedVariables.f and savedVariables.f.t)

    local roster = GetActiveCharacterRoster()
    for index = 1, #roster do
        local entry = roster[index]
        AddTooltipRosterLine(characterLines, entry.n, entry.t)
    end

    local lines = { NGear.L("ui.navigation.item_locator_tooltip"), "" }
    for index = 1, #accountLines do lines[#lines + 1] = accountLines[index] end
    if #accountLines > 0 and #characterLines > 0 then lines[#lines + 1] = "" end
    for index = 1, #characterLines do lines[#lines + 1] = characterLines[index] end
    return table.concat(lines, "\n")
end

function ItemLocator.BuildBrowserRecords(output)
    output = output or {}
    Clear(output)
    if not savedVariables then return output end
    unavailableData = false
    local recordsById = {}
    local categoryIdsByLabel = BuildGamepadCategoryIdsByLabel()
    local characters = {}
    for key, record in pairs(savedVariables.p) do
        if type(record) == "table" then
            characters[#characters + 1] = { k = key, r = record, n = GetCharacterName(record.n) }
        end
    end
    table.sort(characters, function(left, right)
        return NGear.Util.Lower(left.n) < NGear.Util.Lower(right.n)
    end)
    for index = 1, #characters do
        local character = characters[index]
        DecodeLocation(character.r.b, function(catalogId, count)
            AddBrowserLocation(recordsById, categoryIdsByLabel, catalogId, count, character.n, "b", character.r.t)
        end)
        DecodeLocation(character.r.w, function(catalogId, count)
            AddBrowserLocation(recordsById, categoryIdsByLabel, catalogId, count, character.n, "w", character.r.t)
        end)
    end
    DecodeLocation(savedVariables.k.p, function(catalogId, count)
        AddBrowserLocation(recordsById, categoryIdsByLabel, catalogId, count, "", "k", savedVariables.k.t)
    end)
    DecodeLocation(savedVariables.m.p, function(catalogId, count)
        AddBrowserLocation(recordsById, categoryIdsByLabel, catalogId, count, "", "m", savedVariables.m.t)
    end)
    DecodeLocation(savedVariables.f.p, function(catalogId, count)
        AddBrowserLocation(recordsById, categoryIdsByLabel, catalogId, count, "", "f", savedVariables.f.t)
    end)
    local houseRecords = {}
    for bagId, record in pairs(savedVariables.h) do
        if type(record) == "table" then houseRecords[#houseRecords + 1] = { b = Number(bagId), r = record } end
    end
    table.sort(houseRecords, function(left, right) return left.b < right.b end)
    for index = 1, #houseRecords do
        local house = houseRecords[index]
        if house.b > 0 then
            local storageName = GetHouseStorageName(house.b)
            DecodeLocation(house.r.p, function(catalogId, count)
                AddBrowserLocation(recordsById, categoryIdsByLabel, catalogId, count, storageName, "h" .. tostring(house.b), house.r.t)
            end)
        end
    end
    for _, record in pairs(recordsById) do output[#output + 1] = record end
    table.sort(output, function(left, right)
        if left.category ~= right.category then return left.category < right.category end
        if left.name ~= right.name then return left.name < right.name end
        return left.id < right.id
    end)
    return output
end

function ItemLocator.BuildCategoryList(output)
    output = output or {}
    Clear(output)
    if not savedVariables then return output end
    unavailableData = false
    local categoryIdsByLabel = BuildGamepadCategoryIdsByLabel()
    local seenIds, seenCategories = {}, {}
    local function AddPayloadCategories(payload)
        local counts = Codec.DecodeCounts(payload or {}, decodeScratch)
        if not counts then unavailableData = true return end
        for catalogId in pairs(counts) do
            if not seenIds[catalogId] then
                seenIds[catalogId] = true
                local itemLink = Codec.UnpackVariant(savedVariables.c[catalogId], codecFields)
                if itemLink then
                    local label, key = GetItemCategory(itemLink, categoryIdsByLabel)
                    if not seenCategories[key] then
                        seenCategories[key] = true
                        output[#output + 1] = { key = key, label = label }
                    end
                else
                    unavailableData = true
                end
            end
        end
    end
    for _, record in pairs(savedVariables.p) do
        if type(record) == "table" then
            AddPayloadCategories(record.b)
            AddPayloadCategories(record.w)
        end
    end
    AddPayloadCategories(savedVariables.k.p)
    AddPayloadCategories(savedVariables.m.p)
    AddPayloadCategories(savedVariables.f.p)
    for bagId, record in pairs(savedVariables.h) do
        if Number(bagId) > 0 and type(record) == "table" then AddPayloadCategories(record.p) end
    end
    table.sort(output, function(left, right)
        return NGear.Util.Lower(left.label) < NGear.Util.Lower(right.label)
    end)
    return output
end

ItemLocator._CompactCatalog = CompactCatalog
ItemLocator._BuildVariantIdentity = BuildVariantIdentity
ItemLocator._FormatRosterDate = FormatRosterDate
ItemLocator.GetHouseStorageName = GetHouseStorageName
ItemLocator.GetFurnitureVaultName = GetFurnitureVaultName
ItemLocator.GetCraftBagName = GetCraftBagName
