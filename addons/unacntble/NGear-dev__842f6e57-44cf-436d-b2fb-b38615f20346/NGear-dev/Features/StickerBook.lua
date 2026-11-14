NGear = NGear or {}
NGear.Features = NGear.Features or {}

local StickerBook = {}
local USE_LETTER_GROUPS = NGear.Util.UsesCollectionLetterGroups()

local C = {
    NAMESPACE = "StickerBook",
    SEARCH_DIALOG_NAME = "NGear_STICKER_BOOK_SEARCH",
    SET_BUILD_UPDATE = "NGear_StickerBook_SetBuild",
    ANTIQUITY_BUILD_UPDATE = "NGear_StickerBook_AntiquityBuild",
    DATA_BUILD_BUDGET_MS = 2,
    DATA_BUILD_MAX_RECORDS_PER_FRAME = 12,
    DRAW_LEVEL = 240,
    SCALE_MIN = 50,
    SCALE_MAX = 150,
    BACKGROUND_OPACITY_MIN = 0,
    BACKGROUND_OPACITY_MAX = 100,
    SCREEN_MARGIN = 24,
    PADDING = 16,
    HEADER_HEIGHT = 66,
    FOOTER_HEIGHT = 44,
    FOOTER_META_WIDTH_RATIO = 0.44,
    PANE_HEADER_HEIGHT = 34,
    PANE_GAP = 18,
    ROW_GAP = 4,
    TILE_GAP = 8,
    PIECE_LABEL_GAP = 12,
    MAX_DETAIL_TILES = 64,
    MAX_CACHED_PIECE_METADATA = 64,
    INPUT_DEADZONE = 0.34,
    INPUT_INITIAL_DELAY_MS = 330,
    INPUT_REPEAT_DELAY_MS = 95,
    WATERMARK_ALPHA = 0.05,
    WATERMARK_FONT_OFFSET = 4,
    MIN_WIDTH = 820,
    MAX_WIDTH = 1280,
    MAX_CARD_WIDTH = 1600,
    MIN_HEIGHT = 500,
    MAX_HEIGHT = 760,
}

local COLORS = {
    background = { 0.018, 0.028, 0.045 },
    panel = { 0.035, 0.055, 0.085 },
    panelAlt = { 0.055, 0.08, 0.12 },
    selected = { 0.07, 0.31, 0.52 },
    selectedEdge = { 0.35, 0.78, 1 },
    accent = { 0.30, 0.76, 1 },
    accentSoft = { 0.12, 0.45, 0.68 },
    mythic = { 0.90, 0.78, 0.35 },
    cardGold = { 0.93, 0.76, 0.16 },
    cardMuted = { 0.70, 0.69, 0.59 },
    cardText = { 0.82, 0.82, 0.78 },
    complete = { 0.36, 0.92, 0.62 },
    missing = { 0.95, 0.28, 0.30 },
    text = { 0.94, 0.97, 1 },
    textMuted = { 0.63, 0.72, 0.82 },
    divider = { 0.25, 0.48, 0.68 },
}

local TEXTURES = {
    progress = "EsoUI/Art/Miscellaneous/progressbar_genericFill.dds",
    upArrow = "EsoUI/Art/Buttons/Gamepad/gp_upArrow.dds",
    downArrow = "EsoUI/Art/Buttons/Gamepad/gp_downArrow.dds",
}

local FILTERS = {
    { label = NGear.L("features.sticker_book.all_sets_6ece2fa"), summaryLabel = NGear.L("features.sticker_book.summary_sets") },
    { label = NGear.L("features.sticker_book.completed_sets_5094bc4"), summaryLabel = NGear.L("features.sticker_book.summary_completed_sets") },
    { label = NGear.L("features.sticker_book.incomplete_sets_a81fe8d"), summaryLabel = NGear.L("features.sticker_book.summary_incomplete_sets") },
    { label = NGear.L("features.sticker_book.mythics_965733d"), summaryLabel = NGear.L("features.sticker_book.summary_mythics") },
    { label = NGear.L("features.sticker_book.monster_sets_6bed3c4"), summaryLabel = NGear.L("features.sticker_book.summary_monster_sets") },
    { label = NGear.L("features.sticker_book.class_sets_d8f88fa"), summaryLabel = NGear.L("features.sticker_book.summary_class_sets") },
}
NGear.Lexicon.RegisterTableField(FILTERS, "label", {
    "features.sticker_book.all_sets_6ece2fa", "features.sticker_book.completed_sets_5094bc4",
    "features.sticker_book.incomplete_sets_a81fe8d", "features.sticker_book.mythics_965733d",
    "features.sticker_book.monster_sets_6bed3c4", "features.sticker_book.class_sets_d8f88fa",
})
NGear.Lexicon.RegisterTableField(FILTERS, "summaryLabel", {
    "features.sticker_book.summary_sets", "features.sticker_book.summary_completed_sets",
    "features.sticker_book.summary_incomplete_sets", "features.sticker_book.summary_mythics",
    "features.sticker_book.summary_monster_sets", "features.sticker_book.summary_class_sets",
})
local DEFAULT_FONT_SIZE = 26
local DEFAULT_SCALE = 100
local defaults = {
    collections = {
        stickerBook = {
            setCard = true,
            showWatermark = false,
            horizontalPosition = 50,
            verticalPosition = 50,
            font = NGear.Util.GetDefaultFont(),
            scale = DEFAULT_SCALE,
            backgroundOpacity = 90,
            selectedSetId = 0,
        },
    },
}
NGear.Settings.RegisterAccountWideDefaults(C.NAMESPACE, defaults)

local savedVariables
local initialized = false
local settingsPanelVisible = false
local hud
local setRecords = {}
local setIndexById = {}
local letterGroups = {}
local letterGroupPool = {}
local listEntries = {}
local setListEntryIndices = {}
local filteredSetIndices = {}
local filteredSummaryText = ""
local filterIndex = 1
local selectedIndex = 1
local visibleFirstIndex = 1
local dataReady = false
local setBuildRunning = false
local setBuildNextId
local fontStringCache = {}
local layoutCache = {}
local inputHintTextCache = {}
local searchText = ""
local searchNeedle = ""
local searchDialogOpen = false
local searchDialogRegistered = false
local antiquitySetIdByItemSetId = {}
local seenAntiquitySetIdsScratch = {}
local antiquitySetIndexBuilt = false
local antiquityBuildRunning = false
local antiquityBuildNextId
local antiquityBuildMappedCount = 0
local inventoryCategoryScratch = {
    actorCategory = GAMEPLAY_ACTOR_CATEGORY_PLAYER,
}
-- Collection slots are shared by every set. Cache one lightweight descriptor per
-- slot so browsing never loads a new item icon or retains a new item link per set.
local pieceMetadataBySlotKey = {}
local pieceMetadataCacheSize = 0
local pieceMetadataScratch = {}
local pieceSlotScratch = {}
local firstArmorTypeByEquipTypeScratch = {}
local multipleArmorWeightsScratch = {}
local setBonusTextScratch = {}
local hudKeybindGroup
local hudKeybindsActive = false
local Refresh
local ApplyPosition
local RefreshInputActivation
local RefreshHudKeybinds
local RebuildFilteredList
local StartSetRecordsBuild
local CancelSetRecordsBuild
local StartAntiquitySetIndexBuild
local CancelAntiquitySetIndexBuild

local Clamp = NGear.Util.Clamp
local Round = NGear.Util.Round

local function GetSettings()
    local collections = NGear.Settings.GetSection(savedVariables, defaults, "collections")
    if type(collections.stickerBook) ~= "table" then
        collections.stickerBook = {}
    end

    local settings = collections.stickerBook
    for key, value in pairs(defaults.collections.stickerBook) do
        if settings[key] == nil then
            settings[key] = value
        end
    end

    settings.setCard = settings.setCard == true
    settings.showWatermark = settings.showWatermark == true
    settings.horizontalPosition = Clamp(tonumber(settings.horizontalPosition) or defaults.collections.stickerBook.horizontalPosition, 0, 100)
    settings.verticalPosition = Clamp(tonumber(settings.verticalPosition) or defaults.collections.stickerBook.verticalPosition, 0, 100)
    settings.scale = Clamp(Round(tonumber(settings.scale) or DEFAULT_SCALE), C.SCALE_MIN, C.SCALE_MAX)
    settings.backgroundOpacity = Clamp(Round(tonumber(settings.backgroundOpacity) or defaults.collections.stickerBook.backgroundOpacity), C.BACKGROUND_OPACITY_MIN, C.BACKGROUND_OPACITY_MAX)
    settings.selectedSetId = tonumber(settings.selectedSetId) or 0
    if not NGear.Util.IsFontChoice(settings.font) then
        settings.font = NGear.Util.GetDefaultFont()
    end
    return settings
end

local function GetFont(offset)
    local settings = GetSettings()
    local size = Clamp(DEFAULT_FONT_SIZE + (offset or 0), 9, 36)
    local key = tostring(settings.font) .. "|" .. tostring(size)
    if not fontStringCache[key] then
        fontStringCache[key] = string.format("%s|%d|soft-shadow-thin", settings.font, size)
    end
    return fontStringCache[key]
end

local function SetColor(control, color, alpha)
    control:SetColor(color[1], color[2], color[3], alpha or 1)
end

local function SetMythicColor(control)
    if GetItemQualityColor and ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE then
        control:SetColor(GetItemQualityColor(ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE):UnpackRGBA())
    else
        SetColor(control, COLORS.mythic)
    end
end

local function SetCardTitleColor(control, isMythic)
    if isMythic then
        SetMythicColor(control)
    elseif GetItemQualityColor and ITEM_DISPLAY_QUALITY_LEGENDARY then
        control:SetColor(GetItemQualityColor(ITEM_DISPLAY_QUALITY_LEGENDARY):UnpackRGBA())
    else
        SetColor(control, COLORS.cardGold)
    end
end

local function MoveAbove(control, level)
    if control.SetDrawTier and DT_HIGH then
        control:SetDrawTier(DT_HIGH)
    end
    if control.SetDrawLayer and DL_CONTROLS then
        control:SetDrawLayer(DL_CONTROLS)
    end
    if control.SetDrawLevel then
        control:SetDrawLevel(level or C.DRAW_LEVEL)
    end
end

local function CreateLabel(parent, fontOffset, color, alignment)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(GetFont(fontOffset))
    SetColor(label, color or COLORS.text)
    label:SetHorizontalAlignment(alignment or TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    if label.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    MoveAbove(label, C.DRAW_LEVEL + 5)
    return label
end

local function CreateBackdrop(parent, color, edgeColor)
    local backdrop = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
    backdrop:SetCenterColor(color[1], color[2], color[3], color[4] or 1)
    local edge = edgeColor or color
    backdrop:SetEdgeColor(edge[1], edge[2], edge[3], edge[4] or 1)
    MoveAbove(backdrop, C.DRAW_LEVEL + 1)
    return backdrop
end

local function FormatSetName(rawName)
    if zo_strformat and SI_ITEM_SET_NAME_FORMATTER then
        return zo_strformat(SI_ITEM_SET_NAME_FORMATTER, rawName)
    end
    return rawName or NGear.L("features.sticker_book.unknown_set")
end

local function FormatAntiquityName(rawName)
    if zo_strformat and SI_ANTIQUITY_NAME_FORMATTER then
        return zo_strformat(SI_ANTIQUITY_NAME_FORMATTER, rawName)
    end
    return rawName or NGear.L("features.sticker_book.unknown_lead")
end

local function Uppercase(text)
    text = tostring(text or "")
    return NGear.Util.Upper(text)
end

local function GetPieceSlotKey(slot)
    if zo_getSafeId64Key then
        return zo_getSafeId64Key(slot)
    end
    if Id64ToString then
        return Id64ToString(slot)
    end
    return tostring(slot)
end

local function GetStaticPieceIcon(itemLink, itemType, equipType, weaponType)
    local icons
    if ZO_ItemFilterUtils then
        if itemType == ITEMTYPE_WEAPON and weaponType and ZO_ItemFilterUtils.GetWeaponTypeFilterIcons then
            icons = ZO_ItemFilterUtils.GetWeaponTypeFilterIcons(weaponType)
        end
        if not icons and equipType and ZO_ItemFilterUtils.GetEquipTypeFilterIcons then
            icons = ZO_ItemFilterUtils.GetEquipTypeFilterIcons(equipType)
        end
    end
    if icons then
        return icons.up or icons.down or icons.over
    end
    return GetItemLinkIcon and GetItemLinkIcon(itemLink) or nil
end

local function CreatePieceMetadata(pieceId)
    local itemLink = GetItemSetCollectionPieceItemLink(pieceId, LINK_STYLE_DEFAULT, ITEM_TRAIT_TYPE_NONE, nil)
    if not itemLink or itemLink == "" then
        return nil
    end

    local itemType = GetItemLinkItemType and GetItemLinkItemType(itemLink) or nil
    local equipType = GetItemLinkEquipType and GetItemLinkEquipType(itemLink) or nil
    local armorType = GetItemLinkArmorType and GetItemLinkArmorType(itemLink) or nil
    local weaponType = GetItemLinkWeaponType and GetItemLinkWeaponType(itemLink) or nil
    local inventoryCategoryName
    if ZO_InventoryUtils_Gamepad_GetBestItemCategoryDescription and GetItemLinkItemType and GetItemLinkEquipType then
        inventoryCategoryScratch.itemLink = itemLink
        inventoryCategoryScratch.itemType = itemType
        inventoryCategoryScratch.equipType = equipType
        inventoryCategoryName = ZO_InventoryUtils_Gamepad_GetBestItemCategoryDescription(inventoryCategoryScratch)
        inventoryCategoryScratch.itemLink = nil
        inventoryCategoryScratch.itemType = nil
        inventoryCategoryScratch.equipType = nil
    end

    local name
    if itemType == ITEMTYPE_WEAPON and weaponType and GetString then
        local needsHandClass = weaponType == WEAPONTYPE_AXE
            or weaponType == WEAPONTYPE_HAMMER
            or weaponType == WEAPONTYPE_SWORD
            or weaponType == WEAPONTYPE_TWO_HANDED_AXE
            or weaponType == WEAPONTYPE_TWO_HANDED_HAMMER
            or weaponType == WEAPONTYPE_TWO_HANDED_SWORD
        if needsHandClass and equipType then
            local baseName = inventoryCategoryName or GetString("SI_WEAPONTYPE", weaponType)
            name = string.format("%s (%s)", baseName, GetString("SI_EQUIPTYPE", equipType))
        else
            name = GetString("SI_WEAPONTYPE", weaponType)
        end
    end

    if not name then
        name = inventoryCategoryName or (equipType and GetString and GetString("SI_EQUIPTYPE", equipType)) or NGear.L("features.sticker_book.unknown_piece")
    end

    local weightedName
    if itemType == ITEMTYPE_ARMOR and armorType and armorType ~= ARMORTYPE_NONE and GetString then
        weightedName = string.format("%s (%s)", name, GetString("SI_ARMORTYPE", armorType))
    end

    return {
        itemType = itemType,
        equipType = equipType,
        armorType = armorType,
        name = name,
        weightedName = weightedName,
        icon = GetStaticPieceIcon(itemLink, itemType, equipType, weaponType),
    }
end

local function GetPieceMetadata(pieceId, slot)
    if not pieceId or pieceId == 0 or not slot or not GetItemSetCollectionPieceItemLink then
        return nil
    end
    local slotKey = GetPieceSlotKey(slot)
    local metadata = pieceMetadataBySlotKey[slotKey]
    if not metadata then
        metadata = CreatePieceMetadata(pieceId)
        if metadata and pieceMetadataCacheSize < C.MAX_CACHED_PIECE_METADATA then
            pieceMetadataBySlotKey[slotKey] = metadata
            pieceMetadataCacheSize = pieceMetadataCacheSize + 1
        end
    end
    return metadata
end

local function GetPieceTypeName(metadata, multipleArmorWeights)
    if metadata.weightedName and multipleArmorWeights[metadata.equipType] then
        return metadata.weightedName
    end
    return metadata.name
end

local function GetCategoryName(setId)
    if not GetItemSetCollectionCategoryId or not GetItemSetCollectionCategoryName then
        return NGear.L("features.sticker_book.set_collection")
    end
    local categoryId = GetItemSetCollectionCategoryId(setId)
    if not categoryId or categoryId == 0 then
        return NGear.L("features.sticker_book.set_collection")
    end
    local name = GetItemSetCollectionCategoryName(categoryId)
    if name and name ~= "" then
        return name
    end
    return NGear.L("features.sticker_book.set_collection")
end

local function ShouldShow()
    return settingsPanelVisible
end

local function CompareSetRecords(left, right)
    local leftName = NGear.Util.Lower(left.baseName or left.name)
    local rightName = NGear.Util.Lower(right.baseName or right.name)
    if leftName ~= rightName then
        return leftName < rightName
    end

    if left.baseSetId ~= right.baseSetId then
        return left.baseSetId < right.baseSetId
    end
    if left.isPerfected ~= right.isPerfected then
        return not left.isPerfected
    end
    return left.id < right.id
end

local function IsMonsterSet(itemSetId)
    return GetItemSetType and ITEM_SET_TYPE_MONSTER and GetItemSetType(itemSetId) == ITEM_SET_TYPE_MONSTER or false
end

local function IsClassSet(itemSetId)
    if not GetItemSetClassRestrictions then return false end
    local hasClassRestrictions = GetItemSetClassRestrictions(itemSetId)
    return hasClassRestrictions == true
end

local function ClearTable(values)
    for key in pairs(values) do
        values[key] = nil
    end
end

local function AttachAntiquitySetIds()
    for _, record in ipairs(setRecords) do
        record.antiquitySetId = antiquitySetIdByItemSetId[record.id]
        record.isMythic = record.antiquitySetId ~= nil
    end
end

local function GetDataBuildTimeMilliseconds()
    if GetGameTimeMilliseconds then return tonumber(GetGameTimeMilliseconds()) or 0 end
    if GetFrameTimeMilliseconds then return tonumber(GetFrameTimeMilliseconds()) or 0 end
    return 0
end

local function CancelDataBuildUpdate(name)
    if EVENT_MANAGER and EVENT_MANAGER.UnregisterForUpdate then
        EVENT_MANAGER:UnregisterForUpdate(name)
    end
end

CancelAntiquitySetIndexBuild = function()
    CancelDataBuildUpdate(C.ANTIQUITY_BUILD_UPDATE)
    antiquityBuildRunning = false
    antiquityBuildNextId = nil
end

local function FinishAntiquitySetIndexBuild()
    CancelAntiquitySetIndexBuild()
    ClearTable(seenAntiquitySetIdsScratch)
    antiquitySetIndexBuilt = true
    AttachAntiquitySetIds()
    local selectedRecord = setRecords[selectedIndex]
    RebuildFilteredList(selectedRecord and selectedRecord.id)
    if dataReady and ShouldShow() and Refresh then Refresh() end
end

local function ProcessAntiquityRecord(antiquityId)
    local antiquitySetId = GetAntiquitySetId(antiquityId)
    if not antiquitySetId or antiquitySetId == 0 or seenAntiquitySetIdsScratch[antiquitySetId] then return end
    seenAntiquitySetIdsScratch[antiquitySetId] = true
    local rewardId = GetAntiquitySetRewardId(antiquitySetId)
    local isItemReward = rewardId and rewardId ~= 0
        and (not GetRewardType or not REWARD_ENTRY_TYPE_ITEM or GetRewardType(rewardId) == REWARD_ENTRY_TYPE_ITEM)
    if not isItemReward then return end
    local itemLink = GetItemRewardItemLink(rewardId, 1)
    if not itemLink or itemLink == "" then return end
    local itemSetId = select(6, GetItemLinkSetInfo(itemLink, false))
    if itemSetId and itemSetId ~= 0 then
        if not antiquitySetIdByItemSetId[itemSetId] then
            antiquityBuildMappedCount = antiquityBuildMappedCount + 1
        end
        antiquitySetIdByItemSetId[itemSetId] = antiquitySetId
    end
end

local function OnAntiquitySetIndexBuildUpdate()
    if not antiquityBuildRunning or not ShouldShow() then
        CancelAntiquitySetIndexBuild()
        return
    end
    local startedAt = GetDataBuildTimeMilliseconds()
    local processed = 0
    while antiquityBuildNextId and processed < C.DATA_BUILD_MAX_RECORDS_PER_FRAME do
        local antiquityId = antiquityBuildNextId
        ProcessAntiquityRecord(antiquityId)
        antiquityBuildNextId = GetNextAntiquityId(antiquityId)
        processed = processed + 1
        if GetDataBuildTimeMilliseconds() - startedAt >= C.DATA_BUILD_BUDGET_MS then return end
    end
    if not antiquityBuildNextId then FinishAntiquitySetIndexBuild() end
end

StartAntiquitySetIndexBuild = function()
    if antiquitySetIndexBuilt or antiquityBuildRunning then return end
    ClearTable(antiquitySetIdByItemSetId)
    ClearTable(seenAntiquitySetIdsScratch)
    antiquityBuildMappedCount = 0
    if not GetNextAntiquityId or not GetAntiquitySetId or not GetAntiquitySetRewardId
        or not GetItemRewardItemLink or not GetItemLinkSetInfo then
        FinishAntiquitySetIndexBuild()
        return
    end
    antiquityBuildNextId = GetNextAntiquityId(nil)
    if not antiquityBuildNextId then
        FinishAntiquitySetIndexBuild()
        return
    end
    antiquityBuildRunning = true
    if EVENT_MANAGER and EVENT_MANAGER.RegisterForUpdate then
        EVENT_MANAGER:RegisterForUpdate(C.ANTIQUITY_BUILD_UPDATE, 0, OnAntiquitySetIndexBuildUpdate)
    else
        while antiquityBuildRunning do OnAntiquitySetIndexBuildUpdate() end
    end
end

local function RecordMatchesFilter(record)
    if filterIndex == 2 and record.unlocked < record.total then return false end
    if filterIndex == 3 and record.unlocked >= record.total then return false end
    if filterIndex == 4 and not record.isMythic then return false end
    if filterIndex == 5 and not record.isMonster then return false end
    if filterIndex == 6 and not record.isClass then return false end
    if searchNeedle ~= "" then
        local setName = NGear.Util.Lower(record.name or "")
        if not string.find(setName, searchNeedle, 1, true) then return false end
    end
    return true
end

RebuildFilteredList = function(preferredSetId)
    ClearTable(letterGroups)
    ClearTable(listEntries)
    ClearTable(setListEntryIndices)
    ClearTable(filteredSetIndices)

    local previousLetter
    local unlockedTotal = 0
    local pieceTotal = 0
    for index, record in ipairs(setRecords) do
        if RecordMatchesFilter(record) then
            filteredSetIndices[#filteredSetIndices + 1] = index
            unlockedTotal = unlockedTotal + record.unlocked
            pieceTotal = pieceTotal + record.total
            local groupKey, groupLabel = NGear.Util.GetCollectionLetterGroup(record.baseName)
            if USE_LETTER_GROUPS and groupKey ~= previousLetter then
                local groupIndex = #letterGroups + 1
                local group = letterGroupPool[groupIndex]
                if not group then
                    group = {}
                    letterGroupPool[groupIndex] = group
                end
                group.letter = groupLabel
                group.startIndex = index
                letterGroups[groupIndex] = group
                previousLetter = groupKey
                listEntries[#listEntries + 1] = -groupIndex
                group.entryIndex = #listEntries
            end
            record.groupIndex = USE_LETTER_GROUPS and #letterGroups or nil
            listEntries[#listEntries + 1] = index
            setListEntryIndices[index] = #listEntries
        end
    end
    filteredSummaryText = NGear.L(
        "features.sticker_book.summary",
        #filteredSetIndices,
        FILTERS[filterIndex].summaryLabel,
        unlockedTotal,
        pieceTotal
    )

    local settings = GetSettings()
    local preferredIndex = setIndexById[preferredSetId or settings.selectedSetId]
    if preferredIndex and setListEntryIndices[preferredIndex] then
        selectedIndex = preferredIndex
    else
        selectedIndex = filteredSetIndices[1] or 0
    end
    local selectedRecord = setRecords[selectedIndex]
    if selectedRecord then
        settings.selectedSetId = selectedRecord.id
    elseif #setRecords == 0 then
        settings.selectedSetId = 0
    end
    visibleFirstIndex = math.max((setListEntryIndices[selectedIndex] or 1) - 2, 1)
end

local function ResetSetRecordBuildData()
    ClearTable(setRecords)
    ClearTable(setIndexById)
    ClearTable(letterGroups)
    ClearTable(listEntries)
    ClearTable(setListEntryIndices)
    ClearTable(filteredSetIndices)
    filteredSummaryText = NGear.L("features.sticker_book.summary", 0, NGear.L("features.sticker_book.sets_cba9e41"), 0, 0)
    dataReady = false
end

local function AddSetRecord(itemSetId)
    local total = GetNumItemSetCollectionPieces(itemSetId) or 0
    if total <= 0 then return end
    local unlocked = GetNumItemSetCollectionSlotsUnlocked and (GetNumItemSetCollectionSlotsUnlocked(itemSetId) or 0) or 0
    local unperfectedSetId = GetItemSetUnperfectedSetId and (GetItemSetUnperfectedSetId(itemSetId) or 0) or 0
    local isPerfected = unperfectedSetId > 0
    local baseSetId = isPerfected and unperfectedSetId or itemSetId
    local ownName = GetItemSetName(itemSetId)
    local baseName = isPerfected and GetItemSetName(baseSetId) or ownName
    if not baseName or baseName == "" then baseName = ownName end
    baseName = FormatSetName(baseName)
    setRecords[#setRecords + 1] = {
        id = itemSetId,
        name = isPerfected and NGear.L("features.sticker_book.perfected_name", baseName) or baseName,
        baseName = baseName,
        baseSetId = baseSetId,
        isPerfected = isPerfected,
        isMythic = false,
        isMonster = IsMonsterSet(itemSetId),
        isClass = IsClassSet(itemSetId),
        total = total,
        unlocked = unlocked,
        progressText = string.format("%d/%d", unlocked, total),
    }
end

CancelSetRecordsBuild = function()
    CancelDataBuildUpdate(C.SET_BUILD_UPDATE)
    setBuildRunning = false
    setBuildNextId = nil
end

local function FinishSetRecordsBuild()
    CancelSetRecordsBuild()
    table.sort(setRecords, CompareSetRecords)
    for index, record in ipairs(setRecords) do setIndexById[record.id] = index end
    RebuildFilteredList()
    dataReady = true
    if ShouldShow() and Refresh then Refresh() end
    if ShouldShow() then StartAntiquitySetIndexBuild() end
end

local function OnSetRecordsBuildUpdate()
    if not setBuildRunning or not ShouldShow() then
        CancelSetRecordsBuild()
        return
    end
    local startedAt = GetDataBuildTimeMilliseconds()
    local processed = 0
    while setBuildNextId and processed < C.DATA_BUILD_MAX_RECORDS_PER_FRAME do
        local itemSetId = setBuildNextId
        AddSetRecord(itemSetId)
        setBuildNextId = GetNextItemSetCollectionId(itemSetId)
        processed = processed + 1
        if GetDataBuildTimeMilliseconds() - startedAt >= C.DATA_BUILD_BUDGET_MS then return end
    end
    if not setBuildNextId then FinishSetRecordsBuild() end
end

StartSetRecordsBuild = function()
    CancelSetRecordsBuild()
    ResetSetRecordBuildData()
    if not GetNextItemSetCollectionId or not GetItemSetName or not GetNumItemSetCollectionPieces then
        FinishSetRecordsBuild()
        return
    end
    setBuildNextId = GetNextItemSetCollectionId(nil)
    if not setBuildNextId then
        FinishSetRecordsBuild()
        return
    end
    setBuildRunning = true
    if EVENT_MANAGER and EVENT_MANAGER.RegisterForUpdate then
        EVENT_MANAGER:RegisterForUpdate(C.SET_BUILD_UPDATE, 0, OnSetRecordsBuildUpdate)
    else
        while setBuildRunning do OnSetRecordsBuildUpdate() end
    end
end

local function GetScreenDimensions()
    local width, height
    if GuiRoot and GuiRoot.GetDimensions then
        width, height = GuiRoot:GetDimensions()
    end
    if (not width or width <= 0) and GetScreenWidth then
        width = GetScreenWidth()
    end
    if (not height or height <= 0) and GetScreenHeight then
        height = GetScreenHeight()
    end
    return width or 1920, height or 1080
end

local function GetFooterTimestamp()
    if GetTimeStamp and os and os.date then
        local time = os.date("*t", GetTimeStamp())
        if time then
            return string.format("%04d-%02d-%02d %02d:%02d", time.year or 0, time.month or 0, time.day or 0, time.hour or 0, time.min or 0)
        end
    end
    if os and os.date then
        local time = os.date("*t")
        if time then
            return string.format("%04d-%02d-%02d %02d:%02d", time.year or 0, time.month or 0, time.day or 0, time.hour or 0, time.min or 0)
        end
    end
    if GetDate and GetTimeString then
        local year, month, day = GetDate()
        local hour, minute = string.match(GetTimeString() or "", "^(%d%d?):(%d%d)")
        return string.format("%04d-%02d-%02d %02d:%02d", tonumber(year) or 0, tonumber(month) or 0, tonumber(day) or 0, tonumber(hour) or 0, tonumber(minute) or 0)
    end
    return "0000-00-00 00:00"
end

local function GetPlayerServerText()
    local playerId = GetDisplayName and GetDisplayName() or ""
    if playerId == "" and GetUnitDisplayName then
        playerId = GetUnitDisplayName("player") or ""
    end
    local platformServer = string.format("%s %s", NGear.Util.GetConsolePlatform(), NGear.Util.GetMegaserverName())
    if playerId == "" then
        return string.format("%s · %s", platformServer, GetFooterTimestamp())
    end
    if string.sub(playerId, 1, 1) ~= "@" then
        playerId = "@" .. playerId
    end
    return string.format("%s · %s · %s", playerId, platformServer, GetFooterTimestamp())
end

local function BuildWatermarkTextBlock(text, targetWidth, targetHeight)
    local fontSize = Clamp(DEFAULT_FONT_SIZE + C.WATERMARK_FONT_OFFSET, 9, 36)
    local segmentWidth = math.max(math.ceil(string.len(text) * fontSize * 0.62), 1)
    local lineHeight = fontSize + 6
    local rows = math.max(math.ceil(targetHeight / lineHeight) + 2, 1)
    local repeatsPerRow = math.max(math.ceil(targetWidth / segmentWidth) + 2, 1)
    local parts = {}
    for index = 1, rows * repeatsPerRow do
        parts[index] = text
    end
    return table.concat(parts, " ")
end

local function GetLayout()
    local screenWidth, screenHeight = GetScreenDimensions()
    local settings = GetSettings()
    local setCard = settings.setCard
    local scale = settings.scale / 100
    local widthLimit = setCard and C.MAX_CARD_WIDTH or C.MAX_WIDTH
    local widthRatio = setCard and 0.78 or 0.58
    local maximumWidth = math.max(math.min(widthLimit, (screenWidth - (C.SCREEN_MARGIN * 2)) / scale), 320)
    local maximumHeight = math.max(math.min(C.MAX_HEIGHT, (screenHeight - (C.SCREEN_MARGIN * 2)) / scale), 300)
    local minimumWidth = math.min(C.MIN_WIDTH, maximumWidth)
    local minimumHeight = math.min(C.MIN_HEIGHT, maximumHeight)
    local width = Clamp(Round(screenWidth * widthRatio), minimumWidth, maximumWidth)
    local height = Clamp(Round(screenHeight * 0.64), minimumHeight, maximumHeight)
    local innerWidth = width - (C.PADDING * 2)
    local leftWidth = Round(innerWidth * (setCard and 0.32 or 0.40))
    local cardWidth = setCard and Round(innerWidth * 0.25) or 0
    local paneGapWidth = C.PANE_GAP * (setCard and 2 or 1)
    local rightWidth = innerWidth - leftWidth - cardWidth - paneGapWidth
    local rightAreaWidth = innerWidth - leftWidth - C.PANE_GAP
    local contentTop = C.PADDING + C.HEADER_HEIGHT
    local contentHeight = height - contentTop - C.FOOTER_HEIGHT - C.PADDING
    local viewportHeight = contentHeight - C.PANE_HEADER_HEIGHT
    local rowHeight = math.max(DEFAULT_FONT_SIZE + 24, 44)
    local visibleRows = math.max(math.floor((viewportHeight + C.ROW_GAP) / (rowHeight + C.ROW_GAP)), 1)
    layoutCache.screenWidth = screenWidth
    layoutCache.screenHeight = screenHeight
    layoutCache.width = width
    layoutCache.height = height
    layoutCache.innerWidth = innerWidth
    layoutCache.leftWidth = leftWidth
    layoutCache.rightWidth = rightWidth
    layoutCache.rightAreaWidth = rightAreaWidth
    layoutCache.cardWidth = cardWidth
    layoutCache.setCard = setCard
    layoutCache.scale = scale
    layoutCache.contentTop = contentTop
    layoutCache.contentHeight = contentHeight
    layoutCache.viewportHeight = viewportHeight
    layoutCache.rowHeight = rowHeight
    layoutCache.visibleRows = visibleRows
    return layoutCache
end

local function EnsureListRow(index)
    hud.listRows = hud.listRows or {}
    if hud.listRows[index] then
        return hud.listRows[index]
    end
    local row = {}
    row.control = WINDOW_MANAGER:CreateControl(nil, hud.leftViewport, CT_CONTROL)
    row.background = CreateBackdrop(row.control, { COLORS.panelAlt[1], COLORS.panelAlt[2], COLORS.panelAlt[3], 0.65 })
    row.background:SetAnchorFill(row.control)
    row.accent = WINDOW_MANAGER:CreateControl(nil, row.control, CT_TEXTURE)
    SetColor(row.accent, COLORS.selectedEdge)
    MoveAbove(row.accent, C.DRAW_LEVEL + 3)
    row.groupTitle = CreateLabel(row.control, 2, COLORS.accent)
    row.name = CreateLabel(row.control, -2, COLORS.text)
    row.progressText = CreateLabel(row.control, -4, COLORS.textMuted, TEXT_ALIGN_RIGHT)
    row.progressBackground = WINDOW_MANAGER:CreateControl(nil, row.control, CT_TEXTURE)
    SetColor(row.progressBackground, COLORS.panel, 0.95)
    MoveAbove(row.progressBackground, C.DRAW_LEVEL + 3)
    row.progress = WINDOW_MANAGER:CreateControl(nil, row.control, CT_STATUSBAR)
    row.progress:SetTexture(TEXTURES.progress)
    row.progress:SetMinMax(0, 1)
    SetColor(row.progress, COLORS.accentSoft)
    MoveAbove(row.progress, C.DRAW_LEVEL + 4)
    hud.listRows[index] = row
    return row
end

local function EnsurePieceTile(index)
    hud.pieceTiles = hud.pieceTiles or {}
    if hud.pieceTiles[index] then
        return hud.pieceTiles[index]
    end
    local tile = {}
    tile.control = WINDOW_MANAGER:CreateControl(nil, hud.rightViewport, CT_CONTROL)
    tile.background = CreateBackdrop(tile.control, { COLORS.panelAlt[1], COLORS.panelAlt[2], COLORS.panelAlt[3], 0.78 }, { COLORS.divider[1], COLORS.divider[2], COLORS.divider[3], 0.45 })
    tile.background:SetAnchorFill(tile.control)
    tile.iconFrame = CreateBackdrop(tile.control, { 0.015, 0.025, 0.04, 0.95 }, { COLORS.accentSoft[1], COLORS.accentSoft[2], COLORS.accentSoft[3], 0.8 })
    tile.icon = WINDOW_MANAGER:CreateControl(nil, tile.control, CT_TEXTURE)
    MoveAbove(tile.icon, C.DRAW_LEVEL + 5)
    tile.iconLoading = CreateLabel(tile.control, -10, COLORS.textMuted, TEXT_ALIGN_CENTER)
    NGear.Util.ConfigureContentTexture(tile.icon, tile.iconLoading)
    tile.name = CreateLabel(tile.control, -4, COLORS.text)
    tile.marker = WINDOW_MANAGER:CreateControl(nil, tile.control, CT_TEXTURE)
    SetColor(tile.marker, COLORS.complete)
    MoveAbove(tile.marker, C.DRAW_LEVEL + 6)
    hud.pieceTiles[index] = tile
    return tile
end

local function EnsureHud()
    if hud or not WINDOW_MANAGER or not GuiRoot then
        return hud
    end

    hud = {
        inputDirection = 0,
        nextInputAt = 0,
    }
    hud.control = WINDOW_MANAGER:CreateTopLevelWindow("NGearStickerBook")
    hud.control:SetHidden(true)
    MoveAbove(hud.control, C.DRAW_LEVEL)
    hud.UpdateDirectionalInput = function(_, elapsedSeconds)
        StickerBook.UpdateDirectionalInput(elapsedSeconds or 0)
    end

    local backgroundOpacity = GetSettings().backgroundOpacity / 100
    hud.background = CreateBackdrop(hud.control, { COLORS.background[1], COLORS.background[2], COLORS.background[3], backgroundOpacity }, { COLORS.divider[1], COLORS.divider[2], COLORS.divider[3], math.min(backgroundOpacity + 0.12, 1) })
    hud.background:SetAnchorFill(hud.control)

    hud.watermarkClip = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_CONTROL)
    if hud.watermarkClip.SetClipsChildren then hud.watermarkClip:SetClipsChildren(true) end
    MoveAbove(hud.watermarkClip, C.DRAW_LEVEL + 2)
    hud.watermark = WINDOW_MANAGER:CreateControl(nil, hud.watermarkClip, CT_LABEL)
    hud.watermark:SetFont(GetFont(C.WATERMARK_FONT_OFFSET))
    hud.watermark:SetColor(1, 1, 1, C.WATERMARK_ALPHA)
    hud.watermark:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    hud.watermark:SetVerticalAlignment(TEXT_ALIGN_TOP)
    MoveAbove(hud.watermark, C.DRAW_LEVEL + 2)

    hud.title = CreateLabel(hud.control, 5, COLORS.text)
    hud.summary = CreateLabel(hud.control, -3, COLORS.textMuted, TEXT_ALIGN_RIGHT)
    hud.headerDivider = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_TEXTURE)
    SetColor(hud.headerDivider, COLORS.divider, 0.72)
    MoveAbove(hud.headerDivider, C.DRAW_LEVEL + 3)

    hud.leftHeader = CreateLabel(hud.control, -3, COLORS.accent)
    hud.verticalDivider = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_TEXTURE)
    SetColor(hud.verticalDivider, COLORS.divider, 0.55)
    MoveAbove(hud.verticalDivider, C.DRAW_LEVEL + 3)

    hud.leftViewport = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_CONTROL)
    if hud.leftViewport.SetClipsChildren then hud.leftViewport:SetClipsChildren(true) end
    MoveAbove(hud.leftViewport, C.DRAW_LEVEL + 2)
    hud.rightViewport = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_CONTROL)
    if hud.rightViewport.SetClipsChildren then hud.rightViewport:SetClipsChildren(true) end
    MoveAbove(hud.rightViewport, C.DRAW_LEVEL + 2)

    hud.upArrow = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_TEXTURE)
    hud.upArrow:SetTexture(TEXTURES.upArrow)
    SetColor(hud.upArrow, COLORS.accent)
    MoveAbove(hud.upArrow, C.DRAW_LEVEL + 6)
    hud.downArrow = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_TEXTURE)
    hud.downArrow:SetTexture(TEXTURES.downArrow)
    SetColor(hud.downArrow, COLORS.accent)
    MoveAbove(hud.downArrow, C.DRAW_LEVEL + 6)

    hud.empty = CreateLabel(hud.rightViewport, -1, COLORS.textMuted, TEXT_ALIGN_CENTER)
    hud.empty:SetText(NGear.L("features.sticker_book.no_pieces_are_available_for_this_set_e297c61"))
    hud.footerDivider = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_TEXTURE)
    SetColor(hud.footerDivider, COLORS.divider, 0.65)
    MoveAbove(hud.footerDivider, C.DRAW_LEVEL + 3)
    hud.hint = CreateLabel(hud.control, -4, COLORS.textMuted, TEXT_ALIGN_RIGHT)
    hud.footerMeta = CreateLabel(hud.control, -8, COLORS.cardMuted, TEXT_ALIGN_LEFT)
    hud.loadingMessage = CreateLabel(hud.control, 1, COLORS.text, TEXT_ALIGN_CENTER)
    hud.loadingMessage:SetAnchorFill(hud.control)
    hud.loadingMessage:SetText(NGear.L("features.sticker_book.loading"))
    MoveAbove(hud.loadingMessage, C.DRAW_LEVEL + 10)
    return hud
end

local function SetHudContentHidden(hidden)
    hud.watermarkClip:SetHidden(hidden)
    hud.title:SetHidden(hidden)
    hud.summary:SetHidden(hidden)
    hud.headerDivider:SetHidden(hidden)
    hud.leftHeader:SetHidden(hidden)
    hud.verticalDivider:SetHidden(hidden)
    hud.leftViewport:SetHidden(hidden)
    hud.rightViewport:SetHidden(hidden)
    hud.upArrow:SetHidden(hidden)
    hud.downArrow:SetHidden(hidden)
    hud.footerDivider:SetHidden(hidden)
    hud.hint:SetHidden(hidden)
    hud.footerMeta:SetHidden(hidden)
    if hud.cardViewport then hud.cardViewport:SetHidden(hidden) end
end

local function EnsureSetCard()
    if not hud or hud.cardViewport then return end

    hud.cardViewport = WINDOW_MANAGER:CreateControl(nil, hud.control, CT_CONTROL)
    if hud.cardViewport.SetClipsChildren then hud.cardViewport:SetClipsChildren(true) end
    MoveAbove(hud.cardViewport, C.DRAW_LEVEL + 2)
    hud.cardBackground = CreateBackdrop(hud.cardViewport, { 0.008, 0.009, 0.008, 0.93 }, { COLORS.cardGold[1], COLORS.cardGold[2], COLORS.cardGold[3], 0.34 })
    hud.cardBackground:SetAnchorFill(hud.cardViewport)
    hud.cardTitle = CreateLabel(hud.cardViewport, 1, COLORS.cardGold)
    hud.cardTitle:SetVerticalAlignment(TEXT_ALIGN_TOP)
    if hud.cardTitle.SetMaxLineCount then hud.cardTitle:SetMaxLineCount(2) end
    hud.cardMeta = CreateLabel(hud.cardViewport, -7, COLORS.cardMuted)
    hud.cardRule = WINDOW_MANAGER:CreateControl(nil, hud.cardViewport, CT_TEXTURE)
    SetColor(hud.cardRule, COLORS.cardGold, 0.42)
    MoveAbove(hud.cardRule, C.DRAW_LEVEL + 4)
    hud.cardBonusesHeader = CreateLabel(hud.cardViewport, -4, COLORS.cardMuted)
    hud.cardBonuses = CreateLabel(hud.cardViewport, -4, COLORS.cardText)
    hud.cardBonuses:SetVerticalAlignment(TEXT_ALIGN_TOP)
end

local function ApplyBackground()
    if not hud then return end
    local opacity = GetSettings().backgroundOpacity / 100
    hud.background:SetCenterColor(COLORS.background[1], COLORS.background[2], COLORS.background[3], opacity)
    hud.background:SetEdgeColor(COLORS.divider[1], COLORS.divider[2], COLORS.divider[3], math.min(opacity + 0.12, 1))
end

local function ApplyFonts()
    if not hud then return end
    hud.title:SetFont(GetFont(5))
    hud.summary:SetFont(GetFont(-3))
    hud.leftHeader:SetFont(GetFont(-3))
    hud.empty:SetFont(GetFont(-1))
    hud.hint:SetFont(GetFont(-4))
    hud.footerMeta:SetFont(GetFont(-8))
    hud.loadingMessage:SetFont(GetFont(1))
    hud.watermark:SetFont(GetFont(C.WATERMARK_FONT_OFFSET))
    if hud.cardViewport then
        hud.cardTitle:SetFont(GetFont(1))
        hud.cardMeta:SetFont(GetFont(-7))
        hud.cardBonusesHeader:SetFont(GetFont(-4))
        hud.cardBonuses:SetFont(GetFont(-4))
    end
    for _, row in ipairs(hud.listRows or {}) do
        row.groupTitle:SetFont(GetFont(2))
        row.name:SetFont(GetFont(-2))
        row.progressText:SetFont(GetFont(-4))
    end
    for _, tile in ipairs(hud.pieceTiles or {}) do
        tile.iconLoading:SetFont(GetFont(-10))
        tile.name:SetFont(GetFont(-4))
    end
end

local function LayoutHud(layout)
    local control = EnsureHud()
    if not control then return end
    if layout.setCard then EnsureSetCard() end
    hud.control:SetDimensions(layout.width, layout.height)
    if hud.control.SetScale then hud.control:SetScale(layout.scale) end

    hud.title:ClearAnchors()
    hud.title:SetDimensions(layout.leftWidth, C.HEADER_HEIGHT - 8)
    hud.title:SetAnchor(TOPLEFT, hud.control, TOPLEFT, C.PADDING, C.PADDING - 2)
    hud.summary:ClearAnchors()
    hud.summary:SetDimensions(layout.rightAreaWidth, C.HEADER_HEIGHT - 8)
    hud.summary:SetAnchor(TOPRIGHT, hud.control, TOPRIGHT, -C.PADDING, C.PADDING - 2)
    hud.headerDivider:ClearAnchors()
    hud.headerDivider:SetDimensions(layout.innerWidth, 1)
    hud.headerDivider:SetAnchor(TOPLEFT, hud.control, TOPLEFT, C.PADDING, C.PADDING + C.HEADER_HEIGHT - 7)

    hud.leftHeader:ClearAnchors()
    hud.leftHeader:SetDimensions(layout.leftWidth, C.PANE_HEADER_HEIGHT)
    hud.leftHeader:SetAnchor(TOPLEFT, hud.control, TOPLEFT, C.PADDING, layout.contentTop)

    hud.leftViewport:ClearAnchors()
    hud.leftViewport:SetDimensions(layout.leftWidth, layout.viewportHeight)
    hud.leftViewport:SetAnchor(TOPLEFT, hud.control, TOPLEFT, C.PADDING, layout.contentTop + C.PANE_HEADER_HEIGHT)
    hud.rightViewport:ClearAnchors()
    hud.rightViewport:SetDimensions(layout.rightWidth, layout.viewportHeight)
    hud.rightViewport:SetAnchor(TOPLEFT, hud.control, TOPLEFT, C.PADDING + layout.leftWidth + C.PANE_GAP, layout.contentTop + C.PANE_HEADER_HEIGHT)
    hud.verticalDivider:ClearAnchors()
    hud.verticalDivider:SetDimensions(1, layout.contentHeight)
    hud.verticalDivider:SetAnchor(TOPLEFT, hud.control, TOPLEFT, C.PADDING + layout.leftWidth + math.floor(C.PANE_GAP / 2), layout.contentTop)

    hud.watermarkClip:ClearAnchors()
    hud.watermarkClip:SetDimensions(layout.width, layout.height)
    hud.watermarkClip:SetAnchor(TOPLEFT, hud.control, TOPLEFT, 0, 0)
    hud.watermark:ClearAnchors()
    hud.watermark:SetDimensions(layout.width, layout.height)
    hud.watermark:SetAnchor(TOPLEFT, hud.watermarkClip, TOPLEFT, 0, 0)

    if hud.cardViewport then
        hud.cardViewport:SetHidden(not layout.setCard)
        if layout.setCard then
            local cardX = C.PADDING + layout.leftWidth + C.PANE_GAP + layout.rightWidth + C.PANE_GAP
            hud.cardViewport:ClearAnchors()
            hud.cardViewport:SetDimensions(layout.cardWidth, layout.viewportHeight)
            hud.cardViewport:SetAnchor(TOPLEFT, hud.control, TOPLEFT, cardX, layout.contentTop + C.PANE_HEADER_HEIGHT)
            hud.cardTitle:ClearAnchors()
            hud.cardTitle:SetDimensions(layout.cardWidth - 32, 66)
            hud.cardTitle:SetAnchor(TOPLEFT, hud.cardViewport, TOPLEFT, 16, 13)
        end
    end

    hud.upArrow:ClearAnchors()
    hud.upArrow:SetDimensions(24, 24)
    hud.upArrow:SetAnchor(RIGHT, hud.leftHeader, RIGHT, -3, 0)
    hud.downArrow:ClearAnchors()
    hud.downArrow:SetDimensions(24, 24)
    hud.downArrow:SetAnchor(BOTTOMRIGHT, hud.leftViewport, BOTTOMRIGHT, -3, -1)

    hud.footerDivider:ClearAnchors()
    hud.footerDivider:SetDimensions(layout.innerWidth, 1)
    hud.footerDivider:SetAnchor(BOTTOMLEFT, hud.control, BOTTOMLEFT, C.PADDING, -(C.FOOTER_HEIGHT + 1))
    local footerMetaWidth = Round(layout.innerWidth * C.FOOTER_META_WIDTH_RATIO)
    hud.hint:ClearAnchors()
    hud.hint:SetDimensions(layout.innerWidth - footerMetaWidth - C.PANE_GAP, C.FOOTER_HEIGHT)
    hud.hint:SetAnchor(BOTTOMRIGHT, hud.control, BOTTOMRIGHT, -C.PADDING, 0)
    hud.footerMeta:ClearAnchors()
    hud.footerMeta:SetDimensions(footerMetaWidth, C.FOOTER_HEIGHT)
    hud.footerMeta:SetAnchor(BOTTOMLEFT, hud.control, BOTTOMLEFT, C.PADDING, 0)
end

local function RenderWatermark(layout)
    local settings = GetSettings()
    if settings.showWatermark ~= true then
        hud.watermarkClip:SetHidden(true)
        hud.watermark:SetHidden(true)
        return
    end
    hud.watermark:SetFont(GetFont(C.WATERMARK_FONT_OFFSET))
    hud.watermark:SetColor(1, 1, 1, C.WATERMARK_ALPHA)
    local watermarkText = GetPlayerServerText()
    local watermarkKey = string.format("%s|%s|%d|%d", watermarkText, tostring(settings.font), layout.width, layout.height)
    if hud.watermarkTextKey ~= watermarkKey then
        hud.watermark:SetText(BuildWatermarkTextBlock(watermarkText, layout.width, layout.height))
        hud.watermarkTextKey = watermarkKey
    end
    hud.watermarkClip:SetHidden(false)
    hud.watermark:SetHidden(false)
end

local function KeepSelectionVisible(layout)
    local previousFirstIndex = visibleFirstIndex
    local selectedEntryIndex = setListEntryIndices[selectedIndex] or 1
    if selectedEntryIndex < visibleFirstIndex then
        visibleFirstIndex = selectedEntryIndex
        if listEntries[visibleFirstIndex - 1] and listEntries[visibleFirstIndex - 1] < 0 then
            visibleFirstIndex = visibleFirstIndex - 1
        end
    elseif selectedEntryIndex >= visibleFirstIndex + layout.visibleRows then
        visibleFirstIndex = selectedEntryIndex - layout.visibleRows + 1
    end
    local maxFirst = math.max(#listEntries - layout.visibleRows + 1, 1)
    visibleFirstIndex = Clamp(visibleFirstIndex, 1, maxFirst)
    return visibleFirstIndex ~= previousFirstIndex
end

local function SetSetRowSelected(row, selected)
    if selected then
        row.background:SetCenterColor(COLORS.selected[1], COLORS.selected[2], COLORS.selected[3], 0.92)
        row.background:SetEdgeColor(COLORS.selectedEdge[1], COLORS.selectedEdge[2], COLORS.selectedEdge[3], 0.9)
    else
        row.background:SetCenterColor(COLORS.panelAlt[1], COLORS.panelAlt[2], COLORS.panelAlt[3], 0.62)
        row.background:SetEdgeColor(COLORS.divider[1], COLORS.divider[2], COLORS.divider[3], 0.18)
    end
    row.accent:SetHidden(not selected)
end

local function RenderSetList(layout)
    KeepSelectionVisible(layout)
    hud.selectedSetRow = nil
    for poolIndex = 1, math.max(layout.visibleRows, #(hud.listRows or {})) do
        local row = EnsureListRow(poolIndex)
        local entryIndex = visibleFirstIndex + poolIndex - 1
        local entryValue = listEntries[entryIndex]
        local isVisible = poolIndex <= layout.visibleRows and entryValue ~= nil
        row.entryValue = isVisible and entryValue or nil
        row.control:SetHidden(not isVisible)
        if isVisible then
            local y = (poolIndex - 1) * (layout.rowHeight + C.ROW_GAP)
            row.control:ClearAnchors()
            row.control:SetDimensions(layout.leftWidth - 2, layout.rowHeight)
            row.control:SetAnchor(TOPLEFT, hud.leftViewport, TOPLEFT, 0, y)
            if entryValue < 0 then
                local group = letterGroups[-entryValue]
                row.background:SetHidden(true)
                row.accent:SetHidden(true)
                row.name:SetHidden(true)
                row.progressText:SetHidden(true)
                row.progressBackground:SetHidden(true)
                row.progress:SetHidden(true)
                row.groupTitle:SetHidden(false)
                row.groupTitle:ClearAnchors()
                row.groupTitle:SetDimensions(40, layout.rowHeight)
                row.groupTitle:SetAnchor(LEFT, row.control, LEFT, 12, 0)
                row.groupTitle:SetText(group.letter)
            else
                local record = setRecords[entryValue]
                local selected = entryValue == selectedIndex
                if selected then hud.selectedSetRow = row end
                row.groupTitle:SetHidden(true)
                row.background:SetHidden(false)
                row.name:SetHidden(false)
                row.progressText:SetHidden(false)
                row.progressBackground:SetHidden(false)
                row.progress:SetHidden(false)
                SetSetRowSelected(row, selected)
                row.accent:ClearAnchors()
                row.accent:SetDimensions(4, layout.rowHeight - 8)
                row.accent:SetAnchor(LEFT, row.control, LEFT, 3, 0)
                row.name:ClearAnchors()
                row.name:SetDimensions(layout.leftWidth - 92, layout.rowHeight - 13)
                row.name:SetAnchor(TOPLEFT, row.control, TOPLEFT, 12, 1)
                row.name:SetText(record.name)
                if record.isMythic then
                    SetMythicColor(row.name)
                else
                    SetColor(row.name, COLORS.text)
                end
                row.progressText:ClearAnchors()
                row.progressText:SetDimensions(68, layout.rowHeight - 13)
                row.progressText:SetAnchor(TOPRIGHT, row.control, TOPRIGHT, -10, 1)
                row.progressText:SetText(record.progressText)
                row.progressBackground:ClearAnchors()
                row.progressBackground:SetDimensions(layout.leftWidth - 24, 3)
                row.progressBackground:SetAnchor(BOTTOMLEFT, row.control, BOTTOMLEFT, 12, -7)
                row.progress:ClearAnchors()
                row.progress:SetDimensions(layout.leftWidth - 24, 3)
                row.progress:SetAnchor(BOTTOMLEFT, row.control, BOTTOMLEFT, 12, -7)
                row.progress:SetMinMax(0, math.max(record.total, 1))
                row.progress:SetValue(record.unlocked)
                SetColor(row.progress, record.unlocked >= record.total and COLORS.complete or COLORS.accentSoft)
            end
        end
    end
    hud.upArrow:SetHidden(visibleFirstIndex <= 1)
    hud.downArrow:SetHidden(visibleFirstIndex + layout.visibleRows - 1 >= #listEntries)
end

local function RenderSetListSelection(layout)
    if KeepSelectionVisible(layout) then
        RenderSetList(layout)
        return
    end
    local selectedRow
    for _, row in ipairs(hud.listRows or {}) do
        if row.entryValue == selectedIndex then
            selectedRow = row
            break
        end
    end
    if hud.selectedSetRow and hud.selectedSetRow ~= selectedRow then SetSetRowSelected(hud.selectedSetRow, false) end
    if selectedRow and hud.selectedSetRow ~= selectedRow then SetSetRowSelected(selectedRow, true) end
    hud.selectedSetRow = selectedRow
end

local function LayoutPieceTile(displayIndex, columns, tileWidth, tileHeight, iconSize)
    local tile = EnsurePieceTile(displayIndex)
    local column = (displayIndex - 1) % columns
    local row = math.floor((displayIndex - 1) / columns)
    tile.control:SetHidden(false)
    tile.control:ClearAnchors()
    tile.control:SetDimensions(tileWidth, tileHeight)
    tile.control:SetAnchor(TOPLEFT, hud.rightViewport, TOPLEFT, column * (tileWidth + C.TILE_GAP), row * (tileHeight + C.TILE_GAP))
    tile.iconFrame:ClearAnchors()
    tile.iconFrame:SetDimensions(iconSize + 4, iconSize + 4)
    tile.iconFrame:SetAnchor(LEFT, tile.control, LEFT, 6, 0)
    tile.icon:ClearAnchors()
    tile.icon:SetDimensions(iconSize, iconSize)
    tile.icon:SetAnchor(CENTER, tile.iconFrame, CENTER, 0, 0)
    tile.iconLoading:ClearAnchors()
    tile.iconLoading:SetDimensions(iconSize, iconSize)
    tile.iconLoading:SetAnchor(CENTER, tile.iconFrame, CENTER, 0, 0)
    tile.marker:ClearAnchors()
    tile.marker:SetDimensions(5, 5)
    tile.marker:SetAnchor(TOPRIGHT, tile.iconFrame, TOPRIGHT, -2, 2)
    tile.name:ClearAnchors()
    tile.name:SetDimensions(tileWidth - iconSize - C.PIECE_LABEL_GAP - 13, tileHeight - 4)
    tile.name:SetAnchor(LEFT, tile.iconFrame, RIGHT, C.PIECE_LABEL_GAP, 0)
    return tile
end

local function SetPieceTileIcon(tile, icon, desaturated)
    if icon and icon ~= "" then
        if tile.icon.SetDesaturation then
            tile.icon:SetDesaturation(desaturated and 1 or 0)
        end
        if tile.icon.ngearRequestedTexturePath ~= icon then
            NGear.Util.LoadContentTexture(tile.icon, icon)
        end
    else
        NGear.Util.ReleaseContentTexture(tile.icon)
    end
end

local function FinalizePieceTiles(layout, displayCount, emptyText)
    for index = displayCount + 1, #(hud.pieceTiles or {}) do
        local tile = hud.pieceTiles[index]
        NGear.Util.ReleaseContentTexture(tile.icon)
        tile.control:SetHidden(true)
    end
    hud.empty:SetHidden(displayCount > 0)
    if displayCount == 0 then
        hud.empty:SetText(emptyText)
        hud.empty:ClearAnchors()
        hud.empty:SetDimensions(layout.rightWidth - 30, 80)
        hud.empty:SetAnchor(CENTER, hud.rightViewport, CENTER, 0, 0)
    end
end

local function RenderPieces(layout, record, emptyText)
    local canReadPieces = record and GetItemSetCollectionPieceInfo and GetItemSetCollectionPieceItemLink and IsItemSetCollectionSlotUnlocked
    for equipType in pairs(firstArmorTypeByEquipTypeScratch) do
        firstArmorTypeByEquipTypeScratch[equipType] = nil
    end
    for equipType in pairs(multipleArmorWeightsScratch) do
        multipleArmorWeightsScratch[equipType] = nil
    end

    local pieceCount = 0
    if canReadPieces then
        for sourceIndex = 1, record.total do
            local pieceId, slot = GetItemSetCollectionPieceInfo(record.id, sourceIndex)
            if pieceId and pieceId ~= 0 then
                local metadata = GetPieceMetadata(pieceId, slot)
                if metadata and pieceCount < C.MAX_DETAIL_TILES then
                    pieceCount = pieceCount + 1
                    pieceMetadataScratch[pieceCount] = metadata
                    pieceSlotScratch[pieceCount] = slot

                    if metadata.itemType == ITEMTYPE_ARMOR then
                        local armorType = metadata.armorType
                        if armorType and armorType ~= ARMORTYPE_NONE then
                            local equipType = metadata.equipType
                            if equipType then
                                local firstArmorType = firstArmorTypeByEquipTypeScratch[equipType]
                                if firstArmorType and firstArmorType ~= armorType then
                                    multipleArmorWeightsScratch[equipType] = true
                                elseif not firstArmorType then
                                    firstArmorTypeByEquipTypeScratch[equipType] = armorType
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    for index = pieceCount + 1, #pieceMetadataScratch do
        pieceMetadataScratch[index] = nil
        pieceSlotScratch[index] = nil
    end

    local columns = layout.rightWidth >= 450 and 3 or 2
    local rows = math.max(math.ceil(pieceCount / columns), 1)
    local tileWidth = math.floor((layout.rightWidth - ((columns - 1) * C.TILE_GAP)) / columns)
    local tileHeight = Clamp(math.floor((layout.viewportHeight - ((rows - 1) * C.TILE_GAP)) / rows), 32, 58)
    local iconSize = Clamp(tileHeight - 12, 20, 40)
    for displayIndex = 1, pieceCount do
        local metadata = pieceMetadataScratch[displayIndex]
        local slot = pieceSlotScratch[displayIndex]
        local unlocked = slot and IsItemSetCollectionSlotUnlocked(record.id, slot)
        local tile = LayoutPieceTile(displayIndex, columns, tileWidth, tileHeight, iconSize)
        SetPieceTileIcon(tile, metadata.icon, false)
        SetColor(tile.marker, unlocked and COLORS.complete or COLORS.missing)
        tile.name:SetFont(GetFont(-4))
        SetColor(tile.name, COLORS.text)
        tile.name:SetText(GetPieceTypeName(metadata, multipleArmorWeightsScratch))
    end
    FinalizePieceTiles(layout, pieceCount, emptyText or NGear.L("features.sticker_book.no_pieces_are_available_for_this_set_e297c61"))
end

local function RenderMythicLeads(layout, record)
    local canReadLeads = record and record.antiquitySetId and GetNumAntiquitySetAntiquities and GetAntiquitySetAntiquityId and GetAntiquityName and DoesAntiquityHaveLead and GetNumAntiquitiesRecovered
    local leadCount = canReadLeads and math.min(GetNumAntiquitySetAntiquities(record.antiquitySetId) or 0, C.MAX_DETAIL_TILES) or 0
    local columns = layout.rightWidth >= 450 and 3 or 2
    local rows = math.max(math.ceil(leadCount / columns), 1)
    local tileWidth = math.floor((layout.rightWidth - ((columns - 1) * C.TILE_GAP)) / columns)
    local tileHeight = Clamp(math.floor((layout.viewportHeight - ((rows - 1) * C.TILE_GAP)) / rows), 50, 76)
    local iconSize = Clamp(tileHeight - 18, 26, 48)
    local displayCount = 0
    for leadIndex = 1, leadCount do
        local antiquityId = GetAntiquitySetAntiquityId(record.antiquitySetId, leadIndex)
        if antiquityId and antiquityId ~= 0 then
            displayCount = displayCount + 1
            local hasLead = DoesAntiquityHaveLead(antiquityId) == true
            local recovered = (GetNumAntiquitiesRecovered(antiquityId) or 0) > 0
            local discovered = hasLead or recovered

            local tile = LayoutPieceTile(displayCount, columns, tileWidth, tileHeight, iconSize)
            local icon = GetAntiquityLeadIcon and GetAntiquityLeadIcon() or nil
            SetPieceTileIcon(tile, icon, not recovered)
            if recovered then
                SetColor(tile.marker, COLORS.complete)
            elseif hasLead then
                SetMythicColor(tile.marker)
            else
                SetColor(tile.marker, COLORS.missing)
            end
            tile.name:SetFont(GetFont(-6))
            SetColor(tile.name, discovered and COLORS.text or COLORS.textMuted)
            tile.name:SetText(FormatAntiquityName(GetAntiquityName(antiquityId)))
        end
    end
    FinalizePieceTiles(layout, displayCount, NGear.L("features.sticker_book.no_mythic_lead_data"))
end

local function GetBindingIcon(actionName, fallback)
    if ZO_Keybindings_GetHighestPriorityBindingStringFromAction and KEYBIND_TEXT_OPTIONS_FULL_NAME and KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP then
        return ZO_Keybindings_GetHighestPriorityBindingStringFromAction(actionName, KEYBIND_TEXT_OPTIONS_FULL_NAME, KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP, true, false, 100) or fallback
    end
    return fallback
end

local function GetInputHint()
    if inputHintTextCache[filterIndex] then return inputHintTextCache[filterIndex] end
    local stickIcon = NGear.L("common.right_stick")
    if GetGamepadRightStickScrollIcon and zo_iconFormat then
        stickIcon = zo_iconFormat(GetGamepadRightStickScrollIcon(), 30, 30)
    end
    local leftShoulder = GetBindingIcon("UI_SHORTCUT_LEFT_SHOULDER", "L1")
    local rightShoulder = GetBindingIcon("UI_SHORTCUT_RIGHT_SHOULDER", "R1")
    local leftStickClick = GetBindingIcon("UI_SHORTCUT_LEFT_STICK", "L3")
    local rightStickClick = GetBindingIcon("UI_SHORTCUT_RIGHT_STICK", "R3")
    if USE_LETTER_GROUPS then
        inputHintTextCache[filterIndex] = NGear.L("features.sticker_book.input_hint", leftShoulder, rightShoulder, leftStickClick, rightStickClick, FILTERS[filterIndex].label, stickIcon)
    else
        inputHintTextCache[filterIndex] = NGear.L("features.sticker_book.input_hint_flat", leftStickClick, rightStickClick, FILTERS[filterIndex].label, stickIcon)
    end
    return inputHintTextCache[filterIndex]
end

local function RenderSetCard(layout, record)
    if not GetSettings().setCard or not hud.cardViewport then return end

    local categoryName = record and GetCategoryName(record.id) or NGear.L("common.item_set")
    hud.cardTitle:SetText(Uppercase(record and record.name or NGear.L("features.sticker_book.no_set_selected")))
    SetCardTitleColor(hud.cardTitle, record and record.isMythic)
    SetColor(hud.cardMeta, COLORS.cardMuted)
    SetColor(hud.cardBonusesHeader, COLORS.cardMuted)
    SetColor(hud.cardBonuses, COLORS.cardText)

    for index = #setBonusTextScratch, 1, -1 do
        setBonusTextScratch[index] = nil
    end

    local numBonuses = 0
    if record and GetItemSetInfo and GetItemSetBonusInfo then
        local hasSet, _, availableBonuses = GetItemSetInfo(record.id)
        if hasSet then
            numBonuses = availableBonuses or 0
            for bonusIndex = 1, numBonuses do
                local _, description = GetItemSetBonusInfo(record.id, bonusIndex)
                if description and description ~= "" then
                    setBonusTextScratch[#setBonusTextScratch + 1] = description
                end
            end
        end
    end

    if record then
        local setType
        if record.isMythic then
            setType = NGear.L("features.sticker_book.type_mythic")
        elseif record.isMonster then
            setType = NGear.L("features.sticker_book.type_monster")
        elseif record.isClass then
            setType = NGear.L("features.sticker_book.type_class")
        elseif record.isPerfected then
            setType = NGear.L("features.sticker_book.type_perfected")
        else
            setType = NGear.L("features.sticker_book.type_item")
        end
        if record.isMythic then
            hud.cardMeta:SetText(setType)
        else
            hud.cardMeta:SetText(string.format("%s  •  %s", setType, Uppercase(categoryName)))
        end
    else
        hud.cardMeta:SetText("")
    end
    hud.cardBonusesHeader:SetText(numBonuses == 1 and NGear.L("features.sticker_book.set_bonus") or NGear.L("features.sticker_book.set_bonuses"))
    hud.cardBonuses:SetFont(GetFont(numBonuses > 7 and -8 or (numBonuses > 5 and -6 or -4)))
    hud.cardBonuses:SetText(#setBonusTextScratch > 0 and table.concat(setBonusTextScratch, "\n") or NGear.L("features.sticker_book.no_bonus_details"))

    local titleHeight = hud.cardTitle.GetTextHeight and math.ceil(hud.cardTitle:GetTextHeight()) or (DEFAULT_FONT_SIZE + 7)
    titleHeight = Clamp(titleHeight, DEFAULT_FONT_SIZE + 4, 66)
    local metaY = 13 + titleHeight + 1
    local ruleY = metaY + 31
    local bonusesHeaderY = ruleY + 12
    local bonusesY = bonusesHeaderY + 33
    local cardContentWidth = layout.cardWidth - 32
    hud.cardTitle:SetDimensions(cardContentWidth, titleHeight)
    hud.cardMeta:ClearAnchors()
    hud.cardMeta:SetDimensions(cardContentWidth, 25)
    hud.cardMeta:SetAnchor(TOPLEFT, hud.cardViewport, TOPLEFT, 16, metaY)
    hud.cardRule:ClearAnchors()
    hud.cardRule:SetDimensions(cardContentWidth, 1)
    hud.cardRule:SetAnchor(TOPLEFT, hud.cardViewport, TOPLEFT, 16, ruleY)
    hud.cardBonusesHeader:ClearAnchors()
    hud.cardBonusesHeader:SetDimensions(cardContentWidth, 28)
    hud.cardBonusesHeader:SetAnchor(TOPLEFT, hud.cardViewport, TOPLEFT, 16, bonusesHeaderY)
    hud.cardBonuses:ClearAnchors()
    hud.cardBonuses:SetDimensions(cardContentWidth, math.max(layout.viewportHeight - bonusesY - 8, 40))
    hud.cardBonuses:SetAnchor(TOPLEFT, hud.cardViewport, TOPLEFT, 16, bonusesY)
end

local function RenderSelectedSetDetails(layout, record)
    if record and record.isMythic and record.antiquitySetId then
        RenderMythicLeads(layout, record)
    elseif record then
        RenderPieces(layout, record)
    else
        RenderPieces(layout, nil, NGear.L("features.sticker_book.no_sets_match_filter"))
    end
    RenderSetCard(layout, record)
end

local function RenderHud()
    local control = EnsureHud()
    if not control then return end
    local layout = GetLayout()
    if dataReady then SetHudContentHidden(false) end
    LayoutHud(layout)
    ApplyPosition(layout)

    hud.loadingMessage:SetHidden(dataReady)
    hud.control:SetHidden(false)
    if not dataReady then
        SetHudContentHidden(true)
        RefreshInputActivation()
        RefreshHudKeybinds()
        return
    end

    hud.title:SetText(searchText ~= "" and NGear.L("features.sticker_book.search_title", searchText) or NGear.L("features.sticker_book.title"))
    hud.summary:SetText(filteredSummaryText)
    hud.hint:SetText(GetInputHint())
    hud.footerMeta:SetText(string.format("%s · NGear v%s", GetPlayerServerText(), tostring(NGear.version or 0)))
    RenderWatermark(layout)

    local record = setRecords[selectedIndex]
    if record then
        GetSettings().selectedSetId = record.id
        hud.leftHeader:SetText(NGear.L("features.sticker_book.sets_cba9e41"))
        RenderSetList(layout)
        RenderSelectedSetDetails(layout, record)
    else
        hud.leftHeader:SetText(NGear.L("features.sticker_book.sets_cba9e41"))
        RenderSetList(layout)
        if searchText ~= "" then
            RenderPieces(layout, nil, NGear.L("features.sticker_book.no_search_results", searchText))
        else
            RenderPieces(layout, nil, NGear.L("features.sticker_book.no_sets_match_filter"))
        end
        RenderSetCard(layout, nil)
    end
    RefreshInputActivation()
    RefreshHudKeybinds()
end

local function RenderSelection()
    if not hud or not hud.layout then
        RenderHud()
        return
    end
    RenderSetListSelection(hud.layout)
    RenderSelectedSetDetails(hud.layout, setRecords[selectedIndex])
end

local function HideHud()
    if not hud then return end
    for _, tile in ipairs(hud.pieceTiles or {}) do
        NGear.Util.ReleaseContentTexture(tile.icon)
    end
    hud.control:SetHidden(true)
    hud.inputDirection = 0
    hud.nextInputAt = 0
    if DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.IsListening and DIRECTIONAL_INPUT:IsListening(hud) then
        DIRECTIONAL_INPUT:Deactivate(hud)
    end
    RefreshHudKeybinds()
end

ApplyPosition = function(layout)
    if not hud or not hud.control then return end
    layout = layout or GetLayout()
    local settings = GetSettings()
    local maxX = math.max(layout.screenWidth - (layout.width * layout.scale), 0)
    local maxY = math.max(layout.screenHeight - (layout.height * layout.scale), 0)
    hud.control:ClearAnchors()
    hud.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, maxX * (settings.horizontalPosition / 100), maxY * (settings.verticalPosition / 100))
end

RefreshInputActivation = function()
    if not hud or not DIRECTIONAL_INPUT then return end
    local listening = DIRECTIONAL_INPUT.IsListening and DIRECTIONAL_INPUT:IsListening(hud)
    local shouldListen = not hud.control:IsHidden() and not searchDialogOpen and #filteredSetIndices > 1
    if shouldListen and not listening then
        DIRECTIONAL_INPUT:Activate(hud, hud.control)
    elseif not shouldListen and listening then
        DIRECTIONAL_INPUT:Deactivate(hud)
    end
end

local function MoveSelection(delta)
    if #filteredSetIndices == 0 then return end
    local step = delta > 0 and 1 or -1
    local currentEntryIndex = setListEntryIndices[selectedIndex] or (step > 0 and 0 or (#listEntries + 1))
    local nextEntryIndex = currentEntryIndex + step
    while listEntries[nextEntryIndex] and listEntries[nextEntryIndex] < 0 do
        nextEntryIndex = nextEntryIndex + step
    end
    local nextIndex = listEntries[nextEntryIndex]
    if nextIndex and nextIndex > 0 and nextIndex ~= selectedIndex then
        selectedIndex = nextIndex
        GetSettings().selectedSetId = setRecords[selectedIndex].id
        RenderSelection()
        if PlaySound and SOUNDS and SOUNDS.GAMEPAD_MENU_DOWN then
            PlaySound(delta > 0 and SOUNDS.GAMEPAD_MENU_DOWN or SOUNDS.GAMEPAD_MENU_UP)
        end
    end
end

local function JumpGroup(delta)
    local record = setRecords[selectedIndex]
    if not record or #letterGroups < 2 then return end
    local nextGroupIndex = Clamp((record.groupIndex or 1) + delta, 1, #letterGroups)
    if nextGroupIndex == record.groupIndex then return end
    selectedIndex = letterGroups[nextGroupIndex].startIndex
    visibleFirstIndex = letterGroups[nextGroupIndex].entryIndex
    GetSettings().selectedSetId = setRecords[selectedIndex].id
    RenderHud()
    if PlaySound and SOUNDS and SOUNDS.GAMEPAD_MENU_DOWN then
        PlaySound(delta > 0 and SOUNDS.GAMEPAD_MENU_DOWN or SOUNDS.GAMEPAD_MENU_UP)
    end
end

local function CycleFilter()
    local record = setRecords[selectedIndex]
    local preferredSetId = record and record.id or GetSettings().selectedSetId
    filterIndex = (filterIndex % #FILTERS) + 1
    RebuildFilteredList(preferredSetId)
    RenderHud()
    if PlaySound and SOUNDS and SOUNDS.GAMEPAD_MENU_DOWN then
        PlaySound(SOUNDS.GAMEPAD_MENU_DOWN)
    end
end

local function TrimSearchText(value)
    local text = tostring(value or "")
    if zo_strtrim then return zo_strtrim(text) end
    return string.match(text, "^%s*(.-)%s*$") or ""
end

local function ApplySearch(value)
    local record = setRecords[selectedIndex]
    local preferredSetId = record and record.id or GetSettings().selectedSetId
    searchText = TrimSearchText(value)
    searchNeedle = NGear.Util.Lower(searchText)
    RebuildFilteredList(preferredSetId)
    Refresh()
end

local function ReleaseSearchDialog()
    if ZO_Dialogs_ReleaseDialogOnButtonPress then
        ZO_Dialogs_ReleaseDialogOnButtonPress(C.SEARCH_DIALOG_NAME)
    elseif ZO_Dialogs_ReleaseDialog then
        ZO_Dialogs_ReleaseDialog(C.SEARCH_DIALOG_NAME)
    end
end

local function SetupSearchAction(control, data, selected, reselectingDuringRebuild, enabled, active)
    if ZO_SharedGamepadEntry_OnSetup then
        ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    end
end

local function RegisterSearchDialog()
    if searchDialogRegistered or not ZO_Dialogs_RegisterCustomDialog or not GAMEPAD_DIALOGS then return end
    searchDialogRegistered = true
    ZO_Dialogs_RegisterCustomDialog(C.SEARCH_DIALOG_NAME, {
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        title = {
            text = function() return NGear.L("features.sticker_book.search_dialog_title", NGear.L("features.sticker_book.sets_cba9e41")) end,
        },
        setup = function(dialog)
            dialog.data = dialog.data or {}
            dialog.info.parametricList = {
                {
                    template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                    templateData = {
                        nameField = true,
                        textChangedCallback = function(editBox)
                            dialog.data.searchText = editBox:GetText()
                        end,
                        setup = function(control, data, selected)
                            if control.highlight then control.highlight:SetHidden(not selected) end
                            local editBox = control.editBoxControl
                            editBox.textChangedCallback = data.textChangedCallback
                            if editBox.SetMaxInputChars then editBox:SetMaxInputChars(50) end
                            if editBox.SetDefaultText then editBox:SetDefaultText(NGear.L("features.sticker_book.search_dialog_placeholder", NGear.Util.Lower(NGear.L("features.sticker_book.sets_cba9e41")))) end
                            editBox:SetText(dialog.data.searchText or "")
                            data.control = control
                        end,
                        callback = function(dialogRef)
                            local targetData = dialogRef.entryList:GetTargetData()
                            local editBox = targetData and targetData.control and targetData.control.editBoxControl
                            if editBox and editBox.TakeFocus then editBox:TakeFocus() end
                        end,
                        narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
                    },
                },
                {
                    template = "ZO_GamepadTextFieldSubmitItem",
                    templateData = {
                        text = NGear.L("features.sticker_book.apply_search_96b8b79"),
                        setup = SetupSearchAction,
                        callback = function(dialogRef)
                            ApplySearch(dialogRef.data and dialogRef.data.searchText or "")
                            ReleaseSearchDialog()
                        end,
                    },
                },
                {
                    template = "ZO_GamepadTextFieldSubmitItem",
                    templateData = {
                        text = NGear.L("features.sticker_book.clear_search_87e328d"),
                        setup = SetupSearchAction,
                        callback = function()
                            ApplySearch("")
                            ReleaseSearchDialog()
                        end,
                    },
                },
            }
            dialog:setupFunc()
        end,
        blockDialogReleaseOnPress = true,
        finishedCallback = function()
            searchDialogOpen = false
            RefreshInputActivation()
            RefreshHudKeybinds()
        end,
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = function(dialog)
                    local targetData = dialog.entryList:GetTargetData()
                    if targetData and targetData.callback then targetData.callback(dialog) end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = ReleaseSearchDialog,
            },
        },
    })
end

local function OpenSearchDialog()
    if not ZO_Dialogs_ShowGamepadDialog then return end
    RegisterSearchDialog()
    if not searchDialogRegistered then return end
    searchDialogOpen = true
    RefreshInputActivation()
    RefreshHudKeybinds()
    ZO_Dialogs_ShowGamepadDialog(C.SEARCH_DIALOG_NAME, { searchText = searchText })
end

hudKeybindGroup = {
    {
        keybind = "UI_SHORTCUT_LEFT_SHOULDER",
        ethereal = true,
        visible = function() return USE_LETTER_GROUPS end,
        callback = function()
            JumpGroup(-1)
        end,
    },
    {
        keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
        ethereal = true,
        visible = function() return USE_LETTER_GROUPS end,
        callback = function()
            JumpGroup(1)
        end,
    },
    {
        keybind = "UI_SHORTCUT_RIGHT_STICK",
        ethereal = true,
        callback = CycleFilter,
    },
    {
        name = function() return NGear.L("common.search") end,
        keybind = "UI_SHORTCUT_LEFT_STICK",
        ethereal = true,
        callback = OpenSearchDialog,
    },
}

RefreshHudKeybinds = function()
    if not KEYBIND_STRIP or not hudKeybindGroup then return end
    local shouldBeActive = dataReady and hud and hud.control and not hud.control:IsHidden() and not searchDialogOpen
    if shouldBeActive and not hudKeybindsActive then
        KEYBIND_STRIP:AddKeybindButtonGroup(hudKeybindGroup)
        hudKeybindsActive = true
    elseif not shouldBeActive and hudKeybindsActive then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(hudKeybindGroup)
        hudKeybindsActive = false
    end
end

function StickerBook.UpdateDirectionalInput()
    if not hud or hud.control:IsHidden() or searchDialogOpen or not DIRECTIONAL_INPUT or not ZO_DI_RIGHT_STICK then
        return
    end
    local stickY = DIRECTIONAL_INPUT:GetY(ZO_DI_RIGHT_STICK) or 0
    if math.abs(stickY) <= C.INPUT_DEADZONE then
        hud.inputDirection = 0
        hud.nextInputAt = 0
        return
    end

    local direction = stickY < 0 and 1 or -1
    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    if direction ~= hud.inputDirection then
        hud.inputDirection = direction
        hud.nextInputAt = now + C.INPUT_INITIAL_DELAY_MS
        MoveSelection(direction)
    elseif now >= (hud.nextInputAt or 0) then
        hud.nextInputAt = now + C.INPUT_REPEAT_DELAY_MS
        MoveSelection(direction)
    end
    if DIRECTIONAL_INPUT.Consume then
        DIRECTIONAL_INPUT:Consume(ZO_DI_RIGHT_STICK)
    end
end

Refresh = function()
    if not ShouldShow() then
        HideHud()
        return
    end
    RenderHud()
end

local function ClearSetData()
    CancelSetRecordsBuild()
    CancelAntiquitySetIndexBuild()
    dataReady = false
    ClearTable(setRecords)
    ClearTable(setIndexById)
    ClearTable(letterGroups)
    ClearTable(letterGroupPool)
    ClearTable(listEntries)
    ClearTable(setListEntryIndices)
    ClearTable(filteredSetIndices)
    filteredSummaryText = ""
    ClearTable(antiquitySetIdByItemSetId)
    ClearTable(seenAntiquitySetIdsScratch)
    antiquitySetIndexBuilt = false
    antiquityBuildMappedCount = 0
    ClearTable(pieceMetadataBySlotKey)
    pieceMetadataCacheSize = 0
    ClearTable(pieceMetadataScratch)
    ClearTable(pieceSlotScratch)
    ClearTable(firstArmorTypeByEquipTypeScratch)
    ClearTable(multipleArmorWeightsScratch)
    ClearTable(setBonusTextScratch)
    selectedIndex = 1
    visibleFirstIndex = 1
    if hud then
        hud.selectedSetRow = nil
        for _, row in ipairs(hud.listRows or {}) do
            row.entryValue = nil
        end
    end
end

function StickerBook.InitializeSavedVariables()
    savedVariables = NGear.Settings.GetAccountWideSection(C.NAMESPACE)
    savedVariables.progress = nil
    if type(savedVariables.collections) == "table" then
        for key in pairs(savedVariables.collections) do
            if key ~= "stickerBook" then savedVariables.collections[key] = nil end
        end
    end
    GetSettings()
end

function StickerBook.Initialize()
    if initialized then return end
    initialized = true
end

function StickerBook.SetSettingsPanelVisible(value)
    local showing = value == true
    if showing == settingsPanelVisible then return end
    settingsPanelVisible = showing
    if showing then
        StartSetRecordsBuild()
        Refresh()
        return
    end
    if searchDialogOpen then ReleaseSearchDialog() end
    HideHud()
    ClearSetData()
end

function StickerBook.GetSetCard() return GetSettings().setCard end
function StickerBook.SetSetCard(value) GetSettings().setCard = value == true; Refresh() end
function StickerBook.GetShowWatermark() return GetSettings().showWatermark end
function StickerBook.GetShowWatermarkDefault() return defaults.collections.stickerBook.showWatermark end
function StickerBook.SetShowWatermark(value) GetSettings().showWatermark = value == true; Refresh() end
function StickerBook.GetHorizontalPosition() return GetSettings().horizontalPosition end
function StickerBook.SetHorizontalPosition(value) GetSettings().horizontalPosition = Clamp(value, 0, 100); ApplyPosition() end
function StickerBook.GetVerticalPosition() return GetSettings().verticalPosition end
function StickerBook.SetVerticalPosition(value) GetSettings().verticalPosition = Clamp(value, 0, 100); ApplyPosition() end
function StickerBook.GetFontChoices() return NGear.Util.GetFontChoices() end
function StickerBook.GetFontChoiceNames() return NGear.Util.GetFontChoiceNames() end
function StickerBook.GetFont() return GetSettings().font end
function StickerBook.SetFont(value) if not NGear.Util.IsFontChoice(value) then value = NGear.Util.GetDefaultFont() end; GetSettings().font = value; fontStringCache = {}; ApplyFonts(); Refresh() end
function StickerBook.GetScale() return GetSettings().scale end
function StickerBook.SetScale(value) GetSettings().scale = Clamp(Round(value), C.SCALE_MIN, C.SCALE_MAX); Refresh() end
function StickerBook.GetScaleMin() return C.SCALE_MIN end
function StickerBook.GetScaleMax() return C.SCALE_MAX end
function StickerBook.GetBackgroundOpacity() return GetSettings().backgroundOpacity end
function StickerBook.SetBackgroundOpacity(value) GetSettings().backgroundOpacity = Clamp(Round(value), C.BACKGROUND_OPACITY_MIN, C.BACKGROUND_OPACITY_MAX); ApplyBackground() end
function StickerBook.GetBackgroundOpacityMin() return C.BACKGROUND_OPACITY_MIN end
function StickerBook.GetBackgroundOpacityMax() return C.BACKGROUND_OPACITY_MAX end

function StickerBook.GetSetCardLabel() return NGear.L("features.sticker_book.set_card_label") end
function StickerBook.GetSetCardTooltip() return NGear.L("features.sticker_book.set_card_tooltip") end
function StickerBook.GetShowWatermarkLabel() return NGear.L("features.sticker_book.show_watermark_label") end
function StickerBook.GetShowWatermarkTooltip() return NGear.L("features.sticker_book.show_watermark_tooltip") end
function StickerBook.GetHorizontalPositionLabel() return NGear.L("features.sticker_book.horizontal_position_label") end
function StickerBook.GetHorizontalPositionTooltip() return NGear.L("features.sticker_book.horizontal_position_tooltip") end
function StickerBook.GetVerticalPositionLabel() return NGear.L("features.sticker_book.vertical_position_label") end
function StickerBook.GetVerticalPositionTooltip() return NGear.L("features.sticker_book.vertical_position_tooltip") end
function StickerBook.GetFontLabel() return NGear.L("features.sticker_book.font_label") end
function StickerBook.GetFontTooltip() return NGear.L("features.sticker_book.font_tooltip") end
function StickerBook.GetScaleLabel() return NGear.L("features.sticker_book.scale_label") end
function StickerBook.GetScaleTooltip() return NGear.L("features.sticker_book.scale_tooltip") end
function StickerBook.GetBackgroundOpacityLabel() return NGear.L("features.sticker_book.background_opacity_label") end
function StickerBook.GetBackgroundOpacityTooltip() return NGear.L("features.sticker_book.background_opacity_tooltip") end

NGear.Features.StickerBook = StickerBook
