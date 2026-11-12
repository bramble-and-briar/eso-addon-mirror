-- ZoneSets.lua (Полная финальная версия: Сетка, Тосты, Сессии, Группа, Конвейер, Авто-Трейд и Автопривязка)
local ADDON_NAME = "ZoneSets"
ZoneSets = ZoneSets or {}
local ZS = ZoneSets
ZS.Cache = {}
ZS.CurrentTab = "zone"
ZS.ChatQueue = nil
ZS.PlayerRequests = {}
ZS.ToastQueue = {}
ZS.IsToastActive = false
ZS.GroupToastQueue = {}
ZS.IsGroupToastActive = false

-- ================= ЛОКАЛИЗАЦИЯ (СЛОВАРЬ) =================
local L = {
    title = GetString(ZONESETS_TITLE),
    unknownZone = GetString(ZONESETS_UNKNOWN_ZONE),
    noSetsFound = GetString(ZONESETS_NO_SETS_FOUND),
    tabZone = GetString(ZONESETS_TAB_ZONE),
    tabHistory = GetString(ZONESETS_TAB_HISTORY),
    historyTitle = GetString(ZONESETS_HISTORY_TITLE),
    currentSession = GetString(ZONESETS_CURRENT_SESSION),
    previousSession = GetString(ZONESETS_PREVIOUS_SESSION),
    noCurrentItems = GetString(ZONESETS_NO_CURRENT_ITEMS),
    noPreviousItems = GetString(ZONESETS_NO_PREVIOUS_ITEMS),
    groupLootHeader = GetString(ZONESETS_GROUP_LOOT_HEADER),
    noGroupLoot = GetString(ZONESETS_NO_GROUP_LOOT),
    askAllBtn = GetString(ZONESETS_ASK_ALL_BTN),
    askSingleBtn = GetString(ZONESETS_ASK_SINGLE_BTN),
    itemsNeededCount = GetString(ZONESETS_ITEMS_NEEDED_COUNT),
    justNow = GetString(ZONESETS_JUST_NOW),
    minutesAgo = GetString(ZONESETS_MINUTES_AGO),
    hoursAgo = GetString(ZONESETS_HOURS_AGO),
    testTitle = GetString(ZONESETS_TEST_TITLE),
    dragMe = GetString(ZONESETS_DRAG_ME),
    addedToColl = GetString(ZONESETS_ADDED_TO_COLL),
    chatBtnTooltip = GetString(ZONESETS_CHAT_BTN_TOOLTIP),
    setCompletedMsg = GetString(ZONESETS_SET_COMPLETED_MSG),
    toastProgressFormat = GetString(ZONESETS_TOAST_PROGRESS_FORMAT),
    testShown = GetString(ZONESETS_TEST_SHOWN),
    testSaved = GetString(ZONESETS_TEST_SAVED),
    toastDisabled = GetString(ZONESETS_TOAST_DISABLED),
    toastEnabled = GetString(ZONESETS_TOAST_ENABLED),
    toastDurationSet = GetString(ZONESETS_TOAST_DURATION_SET),
    toastStatus = GetString(ZONESETS_TOAST_STATUS),
    shareExtraBtn = GetString(ZONESETS_SHARE_EXTRA_BTN),
    noTradableDupes = GetString(ZONESETS_NO_TRADABLE_DUPES),
    shareBtnTooltip = GetString(ZONESETS_SHARE_BTN_TOOLTIP),
    tradeHelperTitle = GetString(ZONESETS_TRADE_HELPER_TITLE),
    tradePutRequested = GetString(ZONESETS_TRADE_PUT_REQUESTED),
    tradeDumpExtra = GetString(ZONESETS_TRADE_DUMP_EXTRA),
    tradeNoItems = GetString(ZONESETS_TRADE_NO_ITEMS),
    tradeFilledMsg = GetString(ZONESETS_TRADE_FILLED_MSG),
    autoBindOn = GetString(ZONESETS_AUTO_BIND_ON),
    autoBindOff = GetString(ZONESETS_AUTO_BIND_OFF),
    groupRequestsHeader = GetString(ZONESETS_GROUP_REQUESTS_HEADER),
    noGroupRequests = GetString(ZONESETS_NO_GROUP_REQUESTS),
    inBagTooltip = GetString(ZONESETS_IN_BAG_TOOLTIP),
    groupToastOn = GetString(ZONESETS_GROUP_TOAST_ON),
    groupToastOff = GetString(ZONESETS_GROUP_TOAST_OFF),
    neededInColl = GetString(ZONESETS_NEEDED_IN_COLL),
    groupLootedCount = GetString(ZONESETS_GROUP_LOOTED_COUNT),
    soloTag = GetString(ZONESETS_SOLO_TAG),
}

-- ================= СПИСОК СОЛО-ПОДЗЕМЕЛИЙ (НАСТРОЙКИ) =================
local SOLO_DUNGEONS = {
    [1592] = { extraSets = { "тарсир", "tarcyr" } },     -- Путь Жертвоприношений
    [1593] = { extraSets = { "миленн", "mylenne" } },    -- Крепость Лунного Охотника
}

-- Алиасы зон: перенаправление зон без собственного раздела стикербука в родительский регион
ZS.ZoneAliases = {
    [36] = 181, -- Джерольский перевал (36) -> Сиродил (181)
}

local createdRows = {}

-- Определение текущей локации
function ZS:GetCurrentZoneInfo()
    local zoneId = GetUnitWorldPosition("player") or 0
    local rawZoneName = (zoneId > 0 and GetZoneNameById(zoneId)) or GetUnitZone("player") or L.unknownZone
    local cleanZoneName = zo_strformat("<<1>>", rawZoneName)
    return zoneId, cleanZoneName
end

-- Очистка названий от римских цифр (I, II)
local function CleanZoneString(str)
    if not str then return "" end
    local clean = zo_strformat("<<1>>", str)
    clean = string.lower(clean)
    clean = string.gsub(clean, "%s+[ivx]+$", "")
    clean = string.gsub(clean, "%s+%d+$", "")
    clean = string.match(clean, "^%s*(.-)%s*$") or clean
    return clean
end


-- Очистка названия для строки поиска стикербука (убираем цвета, [Класс] и (Второй язык RuESO))
local function CleanSetNameForSearch(str)
    if not str then return "" end
    local clean = zo_strformat("<<1>>", str)
    clean = string.gsub(clean, "|c%x%x%x%x%x%x", "") -- убираем теги цвета
    clean = string.gsub(clean, "|r", "")             -- убираем закрытие цвета
    clean = string.gsub(clean, "%s*%b[]", "")        -- убираем скобки классов [..]
    clean = string.gsub(clean, "%s*%b()", "")        -- убираем второй язык RuESO (..)
    clean = string.match(clean, "^%s*(.-)%s*$") or clean
    return clean
end

-- Переход в стикербук через авто-поиск по названию
function ZS:ShowItemSetInJournal(itemSetDataOrName)
    if not itemSetDataOrName then return end

    local rawName = ""
    if type(itemSetDataOrName) == "string" then
        rawName = itemSetDataOrName
    elseif type(itemSetDataOrName) == "table" and itemSetDataOrName.GetFormattedName then
        rawName = itemSetDataOrName:GetFormattedName()
    end

    local setName = CleanSetNameForSearch(rawName)
    if setName == "" then return end

    if MAIN_MENU_KEYBOARD and MAIN_MENU_KEYBOARD.ShowSceneGroup then
        MAIN_MENU_KEYBOARD:ShowSceneGroup("collectionsSceneGroup", "itemSetsBook")
    else
        SCENE_MANAGER:Show("itemSetsBook")
    end

    zo_callLater(function()
        local book = ITEM_SET_COLLECTIONS_BOOK_KEYBOARD
        if not book then return end

        local searchEdit = (book.searchBox and book.searchBox.editBox) 
            or book.searchEditBox 
            or (book.control and book.control:GetNamedChild("SearchBox"))
            or _G["ZO_ItemSetsBook_Keyboard_TopLevelSearchBox"]
            or _G["ZO_ItemSetsBook_Keyboard_TopLevelSearchBoxEdit"]

        if searchEdit and searchEdit.SetText then
            searchEdit:SetText(setName)
        elseif book.SetSearchString then
            book:SetSearchString(setName)
        end
    end, 100)
end

-- Формирование умного интернационального запроса сета в чат группы
function ZS:RequestSetInChat(setInfo)
    if not setInfo or not setInfo.itemSetData then return end

    local missingWeaponsJewelry = {}
    local missingArmor = {}

    if setInfo.itemSetData.PieceIterator then
        for _, pieceData in setInfo.itemSetData:PieceIterator() do
            if pieceData and type(pieceData) == "table" then
                local isUnlocked = pieceData:IsUnlocked()
                if not isUnlocked then
                    local itemLink = pieceData:GetItemLink() or (GetItemSetCollectionPieceItemLink and GetItemSetCollectionPieceItemLink(pieceData:GetId(), LINK_STYLE_BRACKETS))
                    if itemLink and itemLink ~= "" then
                        local equipType = GetItemLinkEquipType(itemLink)
                        local isWepOrJewel = (equipType == EQUIP_TYPE_RING or equipType == EQUIP_TYPE_NECK 
                            or equipType == EQUIP_TYPE_MAIN_HAND or equipType == EQUIP_TYPE_ONE_HAND 
                            or equipType == EQUIP_TYPE_TWO_HAND or equipType == EQUIP_TYPE_OFF_HAND)

                        if isWepOrJewel then
                            table.insert(missingWeaponsJewelry, itemLink)
                        else
                            table.insert(missingArmor, itemLink)
                        end
                    end
                end
            end
        end
    end

    local totalMissingWepJewel = #missingWeaponsJewelry
    local totalMissingArmor = #missingArmor

    if totalMissingWepJewel == 0 and totalMissingArmor == 0 then
        d("|c39DB92[ZoneSets]|r |c00FF00" .. tostring(setInfo.name) .. "|r: " .. (L.setCompletedMsg or "Сет уже собран на 100%!"))
        PlaySound(SOUNDS.GENERAL_ALERT_ERROR)
        return
    end

    local message = ""

    if totalMissingWepJewel >= 5 then
        local sampleLink = missingWeaponsJewelry[1] or ""
        if sampleLink ~= "" then
            message = string.format("LF any weapons / jewelry of %s set, please! :)", sampleLink)
        else
            message = string.format("LF any weapons / jewelry of %s set, please! :)", setInfo.name)
        end
    elseif totalMissingWepJewel > 0 then
        local linksStr = table.concat(missingWeaponsJewelry, " ")
        message = string.format("LF: %s if you don't need, please! :)", linksStr)
    elseif totalMissingArmor > 0 and totalMissingArmor <= 4 then
        local linksStr = table.concat(missingArmor, " ")
        message = string.format("LF: %s if you don't need, please! :)", linksStr)
    elseif totalMissingArmor >= 5 then
        local sampleArmorLink = missingArmor[1] or ""
        if sampleArmorLink ~= "" then
            message = string.format("LF any body pieces of %s set, please! :)", sampleArmorLink)
        else
            message = string.format("LF any body pieces of %s set, please! :)", setInfo.name)
        end
    end

    if message ~= "" then
        if CHAT_SYSTEM and CHAT_SYSTEM.textEntry then
            CHAT_SYSTEM.textEntry:Open()
            if CHAT_SYSTEM.textEntry.editControl then
                CHAT_SYSTEM.textEntry.editControl:SetText(message)
                CHAT_SYSTEM.textEntry.editControl:SetCursorPosition(string.len(message))
            end
        end
    end
end

-- ================= УМНЫЙ КОНВЕЙЕР ШЕПОТОВ И РАЗДАЧИ ЛУТА =================

-- Поиск всех передаваемых дубликатов сетов в рюкзаке с группировкой (×2, ×3)
function ZS:GetTradableDuplicatesInBag()
    local itemsMap = {}
    local itemsOrder = {}
    local bagSize = GetBagSize(BAG_BACKPACK)

    for slotIndex = 0, bagSize - 1 do
        local itemLink = GetItemLink(BAG_BACKPACK, slotIndex)
        if itemLink and itemLink ~= "" then
            local isTradable = (not IsItemBound(BAG_BACKPACK, slotIndex)) or (IsItemBoPAndTradeable and IsItemBoPAndTradeable(BAG_BACKPACK, slotIndex))
            if isTradable then
                local hasSet = GetItemLinkSetInfo(itemLink)
                local pieceId = GetItemLinkItemId(itemLink)

                if hasSet and pieceId and pieceId > 0 and IsItemSetCollectionPieceUnlocked(pieceId) then
                    if not itemsMap[pieceId] then
                        itemsMap[pieceId] = { link = itemLink, count = 1 }
                        table.insert(itemsOrder, pieceId)
                    else
                        itemsMap[pieceId].count = itemsMap[pieceId].count + 1
                    end
                end
            end
        end
    end

    local formattedList = {}
    for _, pieceId in ipairs(itemsOrder) do
        local itemData = itemsMap[pieceId]
        if itemData.count > 1 then
            table.insert(formattedList, string.format("%s×%d", itemData.link, itemData.count))
        else
            table.insert(formattedList, itemData.link)
        end
    end

    return formattedList
end

-- Жадный упаковщик сообщений (стиль LootLog: сразу ссылки без префиксов)
function ZS.BuildChatMessages(mode, targetPlayer, linksList)
    local messages = {}
    if not linksList or #linksList == 0 then return messages end

    local firstPrefix, nextPrefix, finalSuffix
    if mode == "whisper" then
        firstPrefix = "Hi! If you don't need "
        nextPrefix = "... "
        finalSuffix = ", please share! :)"
    else
        -- Раздача лута в группу: 0 лишних слов, сразу чистые ссылки
        firstPrefix = ""
        nextPrefix = "... "
        finalSuffix = ""
    end

    local MAX_LEN = 345 -- Лимит игры 350
    local currentMsg = firstPrefix

    for _, link in ipairs(linksList) do
        local testMsg = currentMsg .. ((currentMsg == "" or currentMsg == nextPrefix) and "" or " ") .. link

        if string.len(testMsg) <= MAX_LEN then
            currentMsg = testMsg
        else
            table.insert(messages, currentMsg)
            currentMsg = nextPrefix .. link
        end
    end

    if currentMsg ~= "" and currentMsg ~= nextPrefix then
        if finalSuffix ~= "" and string.len(currentMsg .. finalSuffix) <= MAX_LEN then
            currentMsg = currentMsg .. finalSuffix
        end
        table.insert(messages, currentMsg)
    end

    return messages
end

function ZS:LoadNextChatChunk()
    if not self.ChatQueue or not self.ChatQueue.messages then return end
    local message = self.ChatQueue.messages[self.ChatQueue.currentIdx]
    if not message then
        self.ChatQueue = nil
        return
    end

    local mode = self.ChatQueue.mode or "whisper"
    local target = self.ChatQueue.target

    if mode == "whisper" and target and target ~= "" then
        if CHAT_SYSTEM and CHAT_SYSTEM.StartTextEntry then
            CHAT_SYSTEM:StartTextEntry(message, CHAT_CHANNEL_WHISPER, target)
        elseif CHAT_SYSTEM and CHAT_SYSTEM.textEntry then
            CHAT_SYSTEM.textEntry:Open()
            if CHAT_SYSTEM.textEntry.editControl then
                CHAT_SYSTEM.textEntry.editControl:SetText(message)
                CHAT_SYSTEM.textEntry.editControl:SetCursorPosition(string.len(message))
            end
        end
    else
        if CHAT_SYSTEM and CHAT_SYSTEM.textEntry then
            CHAT_SYSTEM.textEntry:Open()
            if CHAT_SYSTEM.textEntry.editControl then
                CHAT_SYSTEM.textEntry.editControl:SetText(message)
                CHAT_SYSTEM.textEntry.editControl:SetCursorPosition(string.len(message))
            end
        end
    end
end

function ZS:QueueChatMessages(targetPlayer, itemsList)
    if not targetPlayer or not itemsList or #itemsList == 0 then return end

    local links = {}
    for _, item in ipairs(itemsList) do
        if item.itemLink and item.itemLink ~= "" then
            table.insert(links, item.itemLink)
        end
    end

    if #links == 0 then return end

    local messages = ZS.BuildChatMessages("whisper", targetPlayer, links)

    self.ChatQueue = {
        mode = "whisper",
        target = targetPlayer,
        messages = messages,
        currentIdx = 1,
    }

    self:LoadNextChatChunk()
end

-- Запуск раздачи всех лишних вещей в чат (кнопка внизу окна)
function ZS:ShareExtraLootInChat()
    local dupes = self:GetTradableDuplicatesInBag()
    if #dupes == 0 then
        d(L.noTradableDupes)
        PlaySound(SOUNDS.GENERAL_ALERT_ERROR)
        return
    end

    local messages = ZS.BuildChatMessages("offer", nil, dupes)

    self.ChatQueue = {
        mode = "offer",
        messages = messages,
        currentIdx = 1,
    }

    self:LoadNextChatChunk()
end


-- Автоматический поиск сетов для зоны (универсальный: Зоны, Данжи, Архив, БГ и Канализация)
function ZS:GetZoneSets(zoneId, zoneName)
    local results = {}
    if not ITEM_SET_COLLECTIONS_DATA_MANAGER then return results end

    -- Если у зоны есть родительский алиас (ID 36 -> ID 181), переключаем имя на родителя
    local searchName = zoneName
    local targetZoneId = (ZS.ZoneAliases and ZS.ZoneAliases[zoneId]) or zoneId
    if targetZoneId ~= zoneId then
        local parentName = GetZoneNameById(targetZoneId)
        if parentName and parentName ~= "" then
            searchName = zo_strformat("<<1>>", parentName)
        end
    end

    local cleanPlayerZone = CleanZoneString(searchName)
    if cleanPlayerZone == "" then return results end

    local myClassName = zo_strformat("<<1>>", GetUnitClass("player"))
    local cleanMyClass = CleanZoneString(myClassName)

    local soloConfig = SOLO_DUNGEONS[zoneId]

    -- 1. Детектор Полей сражений (БГ)
    local isBG = IsActiveWorldBattleground and IsActiveWorldBattleground()

    -- 2. Детектор Имперского города и Канализации
    local isImperialOrSewers = string.find(cleanPlayerZone, "имперск", 1, true)
        or string.find(cleanPlayerZone, "imperial", 1, true)
        or string.find(cleanPlayerZone, "канализац", 1, true)
        or string.find(cleanPlayerZone, "sewer", 1, true)
        or string.find(cleanPlayerZone, "égout", 1, true)
        or string.find(cleanPlayerZone, "kanalisation", 1, true)

    local isArchiveMode = false

    for itemSetId in ITEM_SET_COLLECTIONS_DATA_MANAGER:ItemSetCollectionIterator() do
        local itemSetData = ITEM_SET_COLLECTIONS_DATA_MANAGER:GetItemSetCollectionData(itemSetId)
        
        if itemSetData and itemSetData.GetCategoryData then
            local categoryData = itemSetData:GetCategoryData()
            if categoryData and categoryData.GetFormattedName then
                local subCatName = categoryData:GetFormattedName()
                local cleanSubCat = CleanZoneString(subCatName)
                
                local parentCatData = categoryData.GetParentCategoryData and categoryData:GetParentCategoryData()
                local parentCatName = parentCatData and parentCatData.GetFormattedName and parentCatData:GetFormattedName() or ""
                local cleanParentCat = CleanZoneString(parentCatName)

                local isMatch = false
                local isClassSet = false
                local isSoloSet = false

                -- СЛУЧАЙ 1: Мы на Полях сражений (БГ)
                if isBG then
                    local isBGCategory = (cleanSubCat == "поля сражений") 
                        or (cleanSubCat == "battlegrounds") 
                        or (cleanSubCat == "champs de bataille") 
                        or (cleanSubCat == "schlachtfelder")
                        or (string.find(cleanParentCat, "pvp", 1, true) and (string.find(cleanSubCat, "battle", 1, true) or string.find(cleanSubCat, "поля", 1, true)))
                    if isBGCategory then
                        isMatch = true
                    end

                -- СЛУЧАЙ 2: Мы в Имперском городе / Канализации
                elseif isImperialOrSewers then
                    local isImpCat = string.find(cleanSubCat, "имперск", 1, true)
                        or string.find(cleanSubCat, "imperial", 1, true)
                        or string.find(cleanSubCat, "cité impériale", 1, true)
                        or string.find(cleanSubCat, "kaiserstadt", 1, true)
                    local isImpDungeon = string.find(cleanSubCat, "тюрьм", 1, true) 
                        or string.find(cleanSubCat, "prison", 1, true) 
                        or string.find(cleanSubCat, "башн", 1, true) 
                        or string.find(cleanSubCat, "tower", 1, true)
                    if isImpCat and not isImpDungeon then
                        isMatch = true
                    end

                -- СЛУЧАЙ 3: Обычные зоны, данжи, триалы (по подкатегории)
                elseif cleanPlayerZone == cleanSubCat or (cleanSubCat ~= "" and (string.find(cleanPlayerZone, cleanSubCat, 1, true) or string.find(cleanSubCat, cleanPlayerZone, 1, true))) then
                    isMatch = true

                -- СЛУЧАЙ 4: Бесконечный Архив (по родительской категории)
                elseif cleanParentCat ~= "" and (cleanPlayerZone == cleanParentCat or string.find(cleanPlayerZone, cleanParentCat, 1, true) or string.find(cleanParentCat, cleanPlayerZone, 1, true)) then
                    isMatch = true
                    isClassSet = true
                    isArchiveMode = true
                end

                -- СЛУЧАЙ 5: Специфический монстр-сет соло-данжа из «Одиночных подземелий»
                if soloConfig and not isMatch then
                    local rawSetNameLower = string.lower(zo_strformat("<<1>>", itemSetData:GetFormattedName()))
                    for _, pattern in ipairs(soloConfig.extraSets) do
                        if string.find(rawSetNameLower, pattern, 1, true) then
                            isMatch = true
                            isSoloSet = true
                            break
                        end
                    end
                end

                if isMatch then
                    local rawName = zo_strformat("<<1>>", itemSetData:GetFormattedName())
                    local displayName = rawName
                    local isMyClassSet = false

                    -- В Архиве добавляем тег класса
                    if isClassSet and subCatName ~= "" then
                        displayName = string.format("%s |c00FFFF[%s]|r", rawName, subCatName)
                        if cleanSubCat == cleanMyClass or (cleanMyClass ~= "" and (string.find(cleanMyClass, cleanSubCat, 1, true) or string.find(cleanSubCat, cleanMyClass, 1, true))) then
                            isMyClassSet = true
                        end
                    -- В Соло-данжах добавляем тег [Соло]
                    elseif isSoloSet then
                        displayName = string.format("%s |c00FFFF[%s]|r", rawName, L.soloTag or "Solo")
                    end

                    table.insert(results, {
                        id = itemSetData:GetId(),
                        name = displayName,
                        rawName = rawName,
                        className = subCatName,
                        numPieces = itemSetData:GetNumPieces(),
                        numUnlocked = itemSetData:GetNumUnlockedPieces(),
                        itemSetData = itemSetData,
                        isMyClass = isMyClassSet,
                        isSolo = isSoloSet,
                    })
                end
            end
        end
    end

    -- Сортировка: в соло-данжах поднимаем соло-сет на 1-е место, в Архиве — свой класс
    if (soloConfig or isArchiveMode) and #results > 1 then
        table.sort(results, function(a, b)
            if soloConfig then
                if a.isSolo ~= b.isSolo then
                    return a.isSolo == true
                end
            elseif isArchiveMode then
                if a.isMyClass ~= b.isMyClass then
                    return a.isMyClass == true
                end
                if a.className ~= b.className then
                    return a.className < b.className
                end
            end
            return a.rawName < b.rawName
        end)
    end

    return results
end

-- Получение списка кусочков сета
local function GetSetPiecesList(itemSetData)
    local pieces = {}
    if not itemSetData or not itemSetData.PieceIterator then return pieces end
    
    for _, pieceData in itemSetData:PieceIterator() do
        if pieceData and type(pieceData) == "table" then
            table.insert(pieces, {
                id = pieceData:GetId(),
                name = zo_strformat("<<1>>", pieceData:GetFormattedName()),
                icon = pieceData:GetIcon(),
                isUnlocked = pieceData:IsUnlocked(),
                itemLink = pieceData:GetItemLink()
            })
        end
    end
    return pieces
end

-- ================= ИНТЕРФЕЙС (ГЛАВНОЕ ОКНО) =================
local DEFAULT_WIDTH, DEFAULT_HEIGHT = 500, 520

local ZSWindow = WINDOW_MANAGER:CreateTopLevelWindow("ZoneSets_Window")
ZSWindow:SetDimensions(DEFAULT_WIDTH, DEFAULT_HEIGHT)
ZSWindow:SetDimensionConstraints(350, 250, 900, 900)
ZSWindow:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
ZSWindow:SetMovable(true)
ZSWindow:SetClampedToScreen(true)
ZSWindow:SetHidden(true)
ZSWindow:SetMouseEnabled(true)
ZSWindow:SetResizeHandleSize(10)

ZSWindow:SetHandler("OnShow", function() SCENE_MANAGER:SetInUIMode(true) end)
ZSWindow:SetHandler("OnHide", function() SCENE_MANAGER:SetInUIMode(false) end)

local bg = WINDOW_MANAGER:CreateControl(nil, ZSWindow, CT_BACKDROP)
bg:SetAnchorFill()
bg:SetCenterColor(0, 0, 0, 0.75)
bg:SetEdgeColor(0.7, 0.7, 0.7, 1)

local title = WINDOW_MANAGER:CreateControl(nil, ZSWindow, CT_LABEL)
title:SetFont("ZoFontWinH1")
title:SetAnchor(TOP, ZSWindow, TOP, 0, 10)
title:SetText(L.title)

local zoneLabel = WINDOW_MANAGER:CreateControl(nil, ZSWindow, CT_LABEL)
zoneLabel:SetFont("ZoFontGameLargeBold")
zoneLabel:SetAnchor(TOP, title, BOTTOM, 0, 2)
zoneLabel:SetColor(1, 1, 0, 1)
ZS.ZoneLabel = zoneLabel

local closeBtn = WINDOW_MANAGER:CreateControl(nil, ZSWindow, CT_BUTTON)
closeBtn:SetDimensions(40, 40)
closeBtn:SetAnchor(TOPRIGHT, ZSWindow, TOPRIGHT, 5, 5)
closeBtn:SetNormalTexture("EsoUI/Art/Buttons/closebutton_up.dds")
closeBtn:SetPressedTexture("EsoUI/Art/Buttons/closebutton_down.dds")
closeBtn:SetHandler("OnClicked", function() ZSWindow:SetHidden(true) end)

local tabContainer = WINDOW_MANAGER:CreateControl("ZoneSets_TabContainer", ZSWindow, CT_CONTROL)
tabContainer:SetDimensions(480, 30)
tabContainer:SetAnchor(TOP, zoneLabel, BOTTOM, 0, 6)

local tabZone = WINDOW_MANAGER:CreateControlFromVirtual("ZoneSets_TabZone", tabContainer, "ZO_DefaultTextButton")
tabZone:SetText(L.tabZone)
tabZone:SetDimensions(85, 25)
tabZone:SetAnchor(LEFT, tabContainer, LEFT, 0, 0)

local tabHistory = WINDOW_MANAGER:CreateControlFromVirtual("ZoneSets_TabHistory", tabContainer, "ZO_DefaultTextButton")
tabHistory:SetText(L.tabHistory)
tabHistory:SetDimensions(85, 25)
tabHistory:SetAnchor(LEFT, tabZone, RIGHT, 4, 0)

local btnAutoBind = WINDOW_MANAGER:CreateControlFromVirtual("ZoneSets_BtnAutoBind", tabContainer, "ZO_DefaultTextButton")
btnAutoBind:SetDimensions(165, 25)
btnAutoBind:SetAnchor(RIGHT, tabContainer, RIGHT, 0, 0)
ZS.BtnAutoBind = btnAutoBind

local btnGroupToast = WINDOW_MANAGER:CreateControlFromVirtual("ZoneSets_BtnGroupToast", tabContainer, "ZO_DefaultTextButton")
btnGroupToast:SetDimensions(125, 25)
btnGroupToast:SetAnchor(RIGHT, btnAutoBind, LEFT, -4, 0)
ZS.BtnGroupToast = btnGroupToast

function ZS:UpdateAutoBindVisuals()
    if not self.BtnAutoBind or not self.SavedVars then return end
    if self.SavedVars.autoBind then
        self.BtnAutoBind:SetText(string.format("|c00FF00[%s]|r", L.autoBindOn or "Auto-Bind: ON"))
    else
        self.BtnAutoBind:SetText(string.format("|c777777[%s]|r", L.autoBindOff or "Auto-Bind: OFF"))
    end
end

function ZS:UpdateGroupToastVisuals()
    if not self.BtnGroupToast or not self.SavedVars then return end
    if self.SavedVars.groupToast then
        self.BtnGroupToast:SetText(string.format("|c00FFFF[%s]|r", L.groupToastOn or "Группа: ВКЛ"))
    else
        self.BtnGroupToast:SetText(string.format("|c777777[%s]|r", L.groupToastOff or "Группа: ВЫКЛ"))
    end
end

btnAutoBind:SetHandler("OnClicked", function()
    if ZS.SavedVars then
        ZS.SavedVars.autoBind = not ZS.SavedVars.autoBind
        ZS:UpdateAutoBindVisuals()
        PlaySound(SOUNDS.DEFAULT_CLICK)
    end
end)

btnGroupToast:SetHandler("OnClicked", function()
    if ZS.SavedVars then
        ZS.SavedVars.groupToast = not ZS.SavedVars.groupToast
        ZS:UpdateGroupToastVisuals()
        PlaySound(SOUNDS.DEFAULT_CLICK)
    end
end)

function ZS:UpdateTabVisuals()
    if self.CurrentTab == "history" then
        tabZone:SetNormalFontColor(0.6, 0.6, 0.6, 1)
        tabHistory:SetNormalFontColor(0.9, 0.7, 0.2, 1)
    else
        tabZone:SetNormalFontColor(0.9, 0.7, 0.2, 1)
        tabHistory:SetNormalFontColor(0.6, 0.6, 0.6, 1)
    end
end

tabZone:SetHandler("OnClicked", function()
    ZS.CurrentTab = "zone"
    ZS:UpdateTabVisuals()
    ZS:ShowWindow()
end)

tabHistory:SetHandler("OnClicked", function()
    ZS.CurrentTab = "history"
    ZS:UpdateTabVisuals()
    ZS:ShowWindow()
end)

-- ================= ВСПЛЫВАЮЩИЕ ОКНА (TOAST HUD) =================

-- 1. ЗОЛОТОЙ ТОСТ (Твой лут / Привязка)
local ZSToast = WINDOW_MANAGER:CreateTopLevelWindow("ZoneSets_Toast")
ZSToast:SetDimensions(430, 60)
ZSToast:SetAnchor(TOP, GuiRoot, TOP, 0, 150)
ZSToast:SetHidden(true)
ZSToast:SetClampedToScreen(true)
ZSToast:SetMovable(true)
ZSToast:SetMouseEnabled(true)

local toastBg = WINDOW_MANAGER:CreateControl(nil, ZSToast, CT_BACKDROP)
toastBg:SetAnchorFill()
toastBg:SetCenterColor(0, 0, 0, 0.85)
toastBg:SetEdgeColor(0.9, 0.7, 0.2, 1)
toastBg:SetEdgeTexture(nil, 1, 1, 1, 0)

local toastIcon = WINDOW_MANAGER:CreateControl(nil, ZSToast, CT_TEXTURE)
toastIcon:SetDimensions(44, 44)
toastIcon:SetAnchor(LEFT, ZSToast, LEFT, 8, 0)
toastIcon:SetTexture("/esoui/art/icons/icon_missing.dds")

local toastTitle = WINDOW_MANAGER:CreateControl(nil, ZSToast, CT_LABEL)
toastTitle:SetFont("ZoFontWinH4")
toastTitle:SetAnchor(TOPLEFT, toastIcon, TOPRIGHT, 10, 2)
toastTitle:SetAnchor(TOPRIGHT, ZSToast, TOPRIGHT, -10, 2)
toastTitle:SetColor(1, 1, 1, 1)
toastTitle:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

local toastProgress = WINDOW_MANAGER:CreateControl(nil, ZSToast, CT_LABEL)
toastProgress:SetFont("ZoFontGameSmall")
toastProgress:SetAnchor(BOTTOMLEFT, toastIcon, BOTTOMRIGHT, 10, -2)
toastProgress:SetAnchor(BOTTOMRIGHT, ZSToast, BOTTOMRIGHT, -10, -2)
toastProgress:SetColor(0.9, 0.7, 0.2, 1)
toastProgress:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

ZSToast:SetHandler("OnMoveStop", function()
    if ZS.SavedVars then
        ZS.SavedVars.toastLeft, ZS.SavedVars.toastTop = ZSToast:GetLeft(), ZSToast:GetTop()
    end
end)

-- 2. СИНИЙ ТОСТ (Лут группы)
local ZSGroupToast = WINDOW_MANAGER:CreateTopLevelWindow("ZoneSets_GroupToast")
ZSGroupToast:SetDimensions(430, 60)
ZSGroupToast:SetAnchor(TOP, GuiRoot, TOP, 0, 220) -- по умолчанию чуть ниже золотого
ZSGroupToast:SetHidden(true)
ZSGroupToast:SetClampedToScreen(true)
ZSGroupToast:SetMovable(true)
ZSGroupToast:SetMouseEnabled(true)

local gToastBg = WINDOW_MANAGER:CreateControl(nil, ZSGroupToast, CT_BACKDROP)
gToastBg:SetAnchorFill()
gToastBg:SetCenterColor(0, 0, 0, 0.85)
gToastBg:SetEdgeColor(0.2, 0.7, 1.0, 1)
gToastBg:SetEdgeTexture(nil, 1, 1, 1, 0)

local gToastIcon = WINDOW_MANAGER:CreateControl(nil, ZSGroupToast, CT_TEXTURE)
gToastIcon:SetDimensions(44, 44)
gToastIcon:SetAnchor(LEFT, ZSGroupToast, LEFT, 8, 0)
gToastIcon:SetTexture("/esoui/art/icons/icon_missing.dds")

local gToastTitle = WINDOW_MANAGER:CreateControl(nil, ZSGroupToast, CT_LABEL)
gToastTitle:SetFont("ZoFontWinH4")
gToastTitle:SetAnchor(TOPLEFT, gToastIcon, TOPRIGHT, 10, 2)
gToastTitle:SetAnchor(TOPRIGHT, ZSGroupToast, TOPRIGHT, -10, 2)
gToastTitle:SetColor(1, 1, 1, 1)
gToastTitle:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

local gToastProgress = WINDOW_MANAGER:CreateControl(nil, ZSGroupToast, CT_LABEL)
gToastProgress:SetFont("ZoFontGameSmall")
gToastProgress:SetAnchor(BOTTOMLEFT, gToastIcon, BOTTOMRIGHT, 10, -2)
gToastProgress:SetAnchor(BOTTOMRIGHT, ZSGroupToast, BOTTOMRIGHT, -10, -2)
gToastProgress:SetColor(0.3, 0.9, 1.0, 1)
gToastProgress:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

ZSGroupToast:SetHandler("OnMoveStop", function()
    if ZS.SavedVars then
        ZS.SavedVars.groupToastLeft, ZS.SavedVars.groupToastTop = ZSGroupToast:GetLeft(), ZSGroupToast:GetTop()
    end
end)

-- Контейнер скролла
local scroll = WINDOW_MANAGER:CreateControlFromVirtual("ZoneSets_Scroll", ZSWindow, "ZO_ScrollContainer")
scroll:SetAnchor(TOPLEFT, ZSWindow, TOPLEFT, 14, 115)
scroll:SetDimensions(DEFAULT_WIDTH - 28, DEFAULT_HEIGHT - 170)

local scrollChild = scroll:GetNamedChild("ScrollChild")
scrollChild:SetAnchor(TOPLEFT, scrollChild:GetParent(), TOPLEFT, 0, 0)
scrollChild:SetWidth(scroll:GetWidth() - 10)

local function ClearScrollChild()
    if not scrollChild then return end
    for i = #createdRows, 1, -1 do
        local r = createdRows[i]
        if r then
            r:SetHidden(true)
            r:ClearAnchors()
            r:SetParent(nil)
        end
        createdRows[i] = nil
    end
    scrollChild:SetHeight(0)
end

-- Кнопка раздачи лишнего лута внизу главного окна
local shareBtn = WINDOW_MANAGER:CreateControlFromVirtual("ZoneSets_ShareLootBtn", ZSWindow, "ZO_DefaultTextButton")
shareBtn:SetDimensions(DEFAULT_WIDTH - 28, 28)
shareBtn:SetAnchor(BOTTOM, ZSWindow, BOTTOM, 0, -8)
shareBtn:SetFont("ZoFontGameBold")
shareBtn:SetText(string.format("|cFFD700[%s]|r", L.shareExtraBtn))
ZS.ShareBtn = shareBtn

shareBtn:SetHandler("OnMouseEnter", function()
    shareBtn:SetText(string.format("|cFFFFFF[%s]|r", L.shareExtraBtn))
end)
shareBtn:SetHandler("OnMouseExit", function()
    shareBtn:SetText(string.format("|cFFD700[%s]|r", L.shareExtraBtn))
end)
shareBtn:SetHandler("OnClicked", function()
    if ZS.ShareExtraLootInChat then
        ZS:ShareExtraLootInChat()
    end
end)

function ZS:RecalculateAll()
    if not self.rows or not scrollChild or not scroll or not self.header then return end

    for _, r in ipairs(self.rows) do
        if r.piecesContainer then
            if r.piecesContainer:IsHidden() then
                r:SetHeight(56)
            else
                local gridH = r.piecesContainer:GetHeight() or 130
                r:SetHeight(56 + gridH + 10)
            end
        end
    end

    local prev = self.header
    for _, r in ipairs(self.rows) do
        r:ClearAnchors()
        r:SetAnchor(TOPLEFT, prev, BOTTOMLEFT, 0, 15)
        prev = r
    end

    local top = scrollChild:GetTop()
    local lastBottom = prev and prev:GetBottom() or top
    local newHeight = lastBottom - top + 30
    scrollChild:SetHeight(math.max(newHeight, scroll:GetHeight() + 1))

    if type(ZO_Scroll_UpdateScrollBar) == "function" then
        ZO_Scroll_UpdateScrollBar(scroll)
    end
end

-- Адаптивная ширина всех элементов при растягивании/сжатии окна
function ZS:UpdateRowWidths(newWidth)
    if not self.rows then return end
    local scrollbarReserve = 25
    local targetWidth = newWidth - 28 - scrollbarReserve

    for _, r in ipairs(self.rows) do
        -- Обновляем ширину самой строки (чтобы [LF] двигалась вместе с краем)
        r:SetWidth(targetWidth)

        if r.headerArea then
            r.headerArea:SetWidth(targetWidth)
        end
        if r.nameLabel then
            r.nameLabel:SetWidth(math.max(targetWidth - 75, 80))
        end
        if r.barFrame then
            r.barFrame:SetWidth(math.max(targetWidth - 20, 100))
        end
        if r.piecesContainer then
            r.piecesContainer:SetWidth(targetWidth)
        end
    end
    zo_callLater(function() ZS:RecalculateAll() end, 50)
end

-- ================== ЛОГИКА СЕССИЙ И ИСТОРИИ ==================

function ZS:FormatTimeElapsed(timestamp)
    local now = GetTimeStamp()
    local elapsed = now - (timestamp or now)
    if elapsed < 0 then elapsed = 0 end

    if elapsed < 60 then
        return L.justNow
    elseif elapsed < 3600 then
        return string.format(L.minutesAgo, math.floor(elapsed / 60))
    else
        return string.format(L.hoursAgo, math.floor(elapsed / 3600))
    end
end

-- Добавление полученного сетового предмета в историю текущего захода
function ZS:AddLootToHistory(itemLink, pieceId)
    if not self.SavedVars or not itemLink then return end
    self.SavedVars.ZoneHistory = self.SavedVars.ZoneHistory or {}

    local zoneId, zoneName = self:GetCurrentZoneInfo()
    if zoneId <= 0 then return end

    self.SavedVars.ZoneHistory[zoneId] = self.SavedVars.ZoneHistory[zoneId] or {}
    local zoneHistory = self.SavedVars.ZoneHistory[zoneId]

    local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink)
    local done, total = 0, 0
    if setId and setId > 0 and ITEM_SET_COLLECTIONS_DATA_MANAGER then
        local itemSetData = ITEM_SET_COLLECTIONS_DATA_MANAGER:GetItemSetCollectionData(setId)
        if itemSetData then
            done = itemSetData:GetNumUnlockedPieces()
            total = itemSetData:GetNumPieces()
        end
    end

    local icon = GetItemLinkIcon(itemLink) or "/esoui/art/icons/icon_missing.dds"
    local pName = zo_strformat("<<1>>", GetItemLinkName(itemLink))

    table.insert(zoneHistory, 1, {
        pieceId = pieceId,
        name = pName,
        setName = zo_strformat("<<1>>", setName or ""),
        done = done,
        total = total,
        icon = icon,
        itemLink = itemLink,
        timestamp = GetTimeStamp(),
    })

    -- Очищаем этот предмет из списка нужного лута группы, если он там был
    if pieceId and pieceId > 0 and self.SavedVars.ZoneGroupLoot and self.SavedVars.ZoneGroupLoot[zoneId] then
        local gList = self.SavedVars.ZoneGroupLoot[zoneId]
        for i = #gList, 1, -1 do
            if gList[i].pieceId == pieceId then
                table.remove(gList, i)
            end
        end
    end
end

-- Проверка перехода зон и очистка лута прошлого данжа
function ZS:CheckZoneTransition()
    if not self.SavedVars then return end
    self.SavedVars.ZoneHistory = self.SavedVars.ZoneHistory or {}

    local zoneId = GetUnitWorldPosition("player") or 0
    if zoneId <= 0 then return end

    local now = GetTimeStamp()

    if self.LastZoneId and self.LastZoneId ~= zoneId then
        local oldId = self.LastZoneId
        -- Вышли из локации — сразу стираем временный лут и запросы
        if self.SavedVars.ZoneHistory[oldId] then
            self.SavedVars.ZoneHistory[oldId] = nil
        end
        if self.SavedVars.ZoneGroupLoot and self.SavedVars.ZoneGroupLoot[oldId] then
            self.SavedVars.ZoneGroupLoot[oldId] = nil
        end
    end

    self.LastZoneId = zoneId
    self.LastZoneTime = now
    ZS.PlayerRequests = {} -- Сбрасываем память просьб при выходе из подземелья/смене зоны
end

-- ================== ПОКАЗ ОКНА ==================
function ZS:ShowWindow()
    local zoneId, zoneName = self:GetCurrentZoneInfo()

    if self.CurrentTab == "history" then
        self.ZoneLabel:SetText(string.format("|cFFFF00%s:|r %s", L.historyTitle, zoneName))
    else
        local soloTag = (SOLO_DUNGEONS and SOLO_DUNGEONS[zoneId]) and string.format(" |c00FFFF[%s]|r", L.soloTag or "Solo") or ""
        self.ZoneLabel:SetText(string.format("%s%s |cAAAAAA(ID: %d)|r", zoneName, soloTag, zoneId))
    end

    ClearScrollChild()

    local leftPadding = 6
    local blockWidth = scrollChild:GetWidth()
    local rows = {}

    local header = WINDOW_MANAGER:CreateControl(nil, scrollChild, CT_CONTROL)
    header:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, leftPadding, 5)
    header:SetHidden(true)

    -- === ВКЛАДКА ИСТОРИИ ===
    if self.CurrentTab == "history" then
        self.SavedVars.ZoneHistory = self.SavedVars.ZoneHistory or {}
        self.SavedVars.ZoneGroupLoot = self.SavedVars.ZoneGroupLoot or {}

        local historyData = self.SavedVars.ZoneHistory[zoneId] or {}
        local rawGroupLoot = self.SavedVars.ZoneGroupLoot[zoneId] or {}

        -- 1. СЕКЦИЯ: ЛУТ ГРУППЫ (НУЖНО МНЕ)
        local activeGroupLoot = {}
        for _, entry in ipairs(rawGroupLoot) do
            if entry.pieceId and not IsItemSetCollectionPieceUnlocked(entry.pieceId) then
                table.insert(activeGroupLoot, entry)
            end
        end

        local playersMap = {}
        local playersOrder = {}
        for _, item in ipairs(activeGroupLoot) do
            local pName = item.player or "Unknown"
            if not playersMap[pName] then
                playersMap[pName] = {}
                table.insert(playersOrder, pName)
            end
            table.insert(playersMap[pName], item)
        end

        local gSecHeader = WINDOW_MANAGER:CreateControl(nil, scrollChild, CT_CONTROL)
        gSecHeader:SetWidth(blockWidth - 10)
        gSecHeader:SetHeight(28)

        local gSecLabel = WINDOW_MANAGER:CreateControl(nil, gSecHeader, CT_LABEL)
        gSecLabel:SetFont("ZoFontWinH3")
        gSecLabel:SetAnchor(TOPLEFT, gSecHeader, TOPLEFT, 4, 0)
        gSecLabel:SetText(L.groupLootHeader)

        table.insert(rows, gSecHeader)
        table.insert(createdRows, gSecHeader)

        if #playersOrder == 0 then
            local emptyRow = WINDOW_MANAGER:CreateControl(nil, scrollChild, CT_CONTROL)
            emptyRow:SetWidth(blockWidth - 10)
            emptyRow:SetHeight(24)

            local emptyLbl = WINDOW_MANAGER:CreateControl(nil, emptyRow, CT_LABEL)
            emptyLbl:SetFont("ZoFontGame")
            emptyLbl:SetAnchor(TOPLEFT, emptyRow, TOPLEFT, 12, 0)
            emptyLbl:SetColor(0.6, 0.6, 0.6, 1)
            emptyLbl:SetText(L.noGroupLoot)

            table.insert(rows, emptyRow)
            table.insert(createdRows, emptyRow)
        else
            for _, pName in ipairs(playersOrder) do
                local pItems = playersMap[pName]

                local pCardHeader = WINDOW_MANAGER:CreateControl(nil, scrollChild, CT_CONTROL)
                pCardHeader:SetWidth(blockWidth - 10)
                pCardHeader:SetHeight(30)

                local pBg = WINDOW_MANAGER:CreateControl(nil, pCardHeader, CT_BACKDROP)
                pBg:SetAnchorFill()
                pBg:SetCenterColor(0.1, 0.2, 0.3, 0.4)
                pBg:SetEdgeColor(0.3, 0.5, 0.7, 0.6)
                pBg:SetEdgeTexture(nil, 1, 1, 1, 0)

                local pLabel = WINDOW_MANAGER:CreateControl(nil, pCardHeader, CT_LABEL)
                pLabel:SetFont("ZoFontWinH4")
                pLabel:SetAnchor(LEFT, pCardHeader, LEFT, 8, 0)
                pLabel:SetText(string.format("|c00FFFF%s|r  |cAAAAAA(%s)|r", pName, string.format(L.itemsNeededCount, #pItems)))

                -- Кнопка [Попросить всё]
                local askAllBtn = WINDOW_MANAGER:CreateControl(nil, pCardHeader, CT_BUTTON)
                askAllBtn:SetDimensions(110, 22)
                askAllBtn:SetAnchor(RIGHT, pCardHeader, RIGHT, -6, 0)
                askAllBtn:SetFont("ZoFontGameBold")
                askAllBtn:SetText(string.format("|cFFD700[%s]|r", L.askAllBtn))

                askAllBtn:SetHandler("OnMouseEnter", function() askAllBtn:SetText(string.format("|cFFFFFF[%s]|r", L.askAllBtn)) end)
                askAllBtn:SetHandler("OnMouseExit", function() askAllBtn:SetText(string.format("|cFFD700[%s]|r", L.askAllBtn)) end)
                askAllBtn:SetHandler("OnClicked", function()
                    ZS:QueueChatMessages(pName, pItems)
                end)

                table.insert(rows, pCardHeader)
                table.insert(createdRows, pCardHeader)

                for _, item in ipairs(pItems) do
                    local gRow = WINDOW_MANAGER:CreateControl(nil, scrollChild, CT_BUTTON)
                    gRow:SetWidth(blockWidth - 20)
                    gRow:SetHeight(44)

                    local gRowBg = WINDOW_MANAGER:CreateControl(nil, gRow, CT_BACKDROP)
                    gRowBg:SetAnchorFill()
                    gRowBg:SetCenterColor(0, 0, 0, 0.5)
                    gRowBg:SetEdgeColor(0.5, 0.1, 0.1, 0.5)
                    gRowBg:SetEdgeTexture(nil, 1, 1, 1, 0)
                    gRowBg:SetMouseEnabled(false)

                    local gIcon = WINDOW_MANAGER:CreateControl(nil, gRow, CT_TEXTURE)
                    gIcon:SetDimensions(34, 34)
                    gIcon:SetAnchor(LEFT, gRow, LEFT, 6, 0)
                    gIcon:SetTexture(item.icon)
                    gIcon:SetMouseEnabled(false)

                    local gName = WINDOW_MANAGER:CreateControl(nil, gRow, CT_LABEL)
                    gName:SetFont("ZoFontWinH4")
                    gName:SetAnchor(TOPLEFT, gIcon, TOPRIGHT, 8, 2)
                    gName:SetText(item.name)
                    gName:SetColor(1, 1, 1, 1)
                    gName:SetMouseEnabled(false)

                    local timeStr = ZS:FormatTimeElapsed(item.timestamp)
                    local gSub = WINDOW_MANAGER:CreateControl(nil, gRow, CT_LABEL)
                    gSub:SetFont("ZoFontGameSmall")
                    gSub:SetAnchor(BOTTOMLEFT, gIcon, BOTTOMRIGHT, 8, -2)
                    gSub:SetText(string.format("|cFFD700%s|r  |cAAAAAA(%s)|r", item.setName, timeStr))
                    gSub:SetMouseEnabled(false)

                    -- Кнопка [Спросить]
                    local askSingleBtn = WINDOW_MANAGER:CreateControl(nil, gRow, CT_BUTTON)
                    askSingleBtn:SetDimensions(80, 20)
                    askSingleBtn:SetAnchor(RIGHT, gRow, RIGHT, -6, 0)
                    askSingleBtn:SetFont("ZoFontGame")
                    askSingleBtn:SetText(string.format("|c39DB92[%s]|r", L.askSingleBtn))

                    askSingleBtn:SetHandler("OnMouseEnter", function() askSingleBtn:SetText(string.format("|cFFFFFF[%s]|r", L.askSingleBtn)) end)
                    askSingleBtn:SetHandler("OnMouseExit", function() askSingleBtn:SetText(string.format("|c39DB92[%s]|r", L.askSingleBtn)) end)
                    askSingleBtn:SetHandler("OnClicked", function()
                        ZS:QueueChatMessages(pName, { item })
                    end)

                    gRow:SetHandler("OnMouseEnter", function()
                        gRowBg:SetCenterColor(0.2, 0.4, 0.8, 0.3)
                        local rCenterX = gRow:GetCenter()
                        local sCenterX = GuiRoot:GetWidth() / 2
                        if rCenterX and sCenterX and rCenterX < sCenterX then
                            InitializeTooltip(ItemTooltip, gRow, LEFT, 10, 0, RIGHT)
                        else
                            InitializeTooltip(ItemTooltip, gRow, RIGHT, -10, 0, LEFT)
                        end
                        if item.itemLink and item.itemLink ~= "" then
                            ItemTooltip:SetLink(item.itemLink)
                        end
                    end)

                    gRow:SetHandler("OnMouseExit", function()
                        gRowBg:SetCenterColor(0, 0, 0, 0.5)
                        ClearTooltip(ItemTooltip)
                    end)

                    gRow:SetHandler("OnMouseUp", function(_, button, upInside)
                        if not upInside then return end
                        if button == MOUSE_BUTTON_INDEX_LEFT then
                            if item.itemLink and item.itemLink ~= "" then
                                ZO_LinkHandler_InsertLink(item.itemLink)
                            end
                        elseif button == MOUSE_BUTTON_INDEX_RIGHT then
                            ZS:ShowItemSetInJournal(item.setName)
                        end
                    end)

                    table.insert(rows, gRow)
                    table.insert(createdRows, gRow)
                end
            end
        end

    -- === ВКЛАДКА ЗОНЫ ===
    else
        local sets = self:GetZoneSets(zoneId, zoneName)

        if #sets == 0 then
            local emptyLabel = WINDOW_MANAGER:CreateControl(nil, scrollChild, CT_LABEL)
            emptyLabel:SetFont("ZoFontGameMedium")
            emptyLabel:SetAnchor(TOP, scrollChild, TOP, 0, 40)
            emptyLabel:SetColor(0.7, 0.7, 0.7, 1)
            emptyLabel:SetText(L.noSetsFound)
            table.insert(createdRows, emptyLabel)
        else
            for _, setInfo in ipairs(sets) do
                local done, total = setInfo.numUnlocked, setInfo.numPieces
                local isComplete = (done >= total and total > 0)
                local percent = total > 0 and math.floor((done / total) * 100) or 0
                local statusColor = isComplete and "00FF00" or "FFFFFF"

                local row = WINDOW_MANAGER:CreateControl(nil, scrollChild, CT_CONTROL)
                row:SetWidth(blockWidth - 10)
                row:SetHeight(56)

                local headerArea = WINDOW_MANAGER:CreateControl(nil, row, CT_CONTROL)
                headerArea:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
                headerArea:SetDimensions(blockWidth - 10, 54)
                headerArea:SetMouseEnabled(true)
                row.headerArea = headerArea

                local headerBg = WINDOW_MANAGER:CreateControl(nil, headerArea, CT_BACKDROP)
                headerBg:SetAnchorFill()
                headerBg:SetCenterColor(0, 0, 0, 0)
                headerBg:SetEdgeColor(0, 0, 0, 0)

                headerArea:SetHandler("OnMouseEnter", function() headerBg:SetCenterColor(0.2, 0.4, 0.8, 0.2) end)
                headerArea:SetHandler("OnMouseExit", function() headerBg:SetCenterColor(0, 0, 0, 0) end)
                headerArea:SetHandler("OnMouseUp", function(_, button, upInside)
                    if button == MOUSE_BUTTON_INDEX_LEFT and upInside then
                        ZS:ShowItemSetInJournal(setInfo.itemSetData)
                    end
                end)

                -- Кнопка [+] / [-]
                local toggleBtn = WINDOW_MANAGER:CreateControl(nil, row, CT_BUTTON)
                toggleBtn:SetDimensions(22, 22)
                toggleBtn:SetAnchor(TOPLEFT, row, TOPLEFT, 2, 0)
                toggleBtn:SetNormalTexture("/esoui/art/buttons/plus_up.dds")
                toggleBtn:SetPressedTexture("/esoui/art/buttons/plus_down.dds")
                toggleBtn:SetMouseOverTexture("/esoui/art/buttons/plus_over.dds")

                local nameLabel = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
                nameLabel:SetFont("ZoFontWinH4")
                nameLabel:SetAnchor(TOPLEFT, toggleBtn, TOPRIGHT, 6, -2)
                nameLabel:SetText(string.format("|c%s%s|r  |cAAAAAA(%d%%)|r", statusColor, setInfo.name, percent))
                row.nameLabel = nameLabel

                -- Кнопка [LF]
                local chatBtn = WINDOW_MANAGER:CreateControl(nil, row, CT_BUTTON)
                chatBtn:SetDimensions(38, 22)
                chatBtn:SetAnchor(TOPRIGHT, row, TOPRIGHT, -12, 0)
                chatBtn:SetFont("ZoFontGameBold")
                chatBtn:SetText("|cFFD700[LF]|r")

                chatBtn:SetHandler("OnMouseEnter", function()
                    chatBtn:SetText("|cFFFFFF[LF]|r")
                    InitializeTooltip(InformationTooltip, chatBtn, TOP, 0, -5)
                    SetTooltipText(InformationTooltip, L.chatBtnTooltip)
                end)
                chatBtn:SetHandler("OnMouseExit", function()
                    chatBtn:SetText("|cFFD700[LF]|r")
                    ClearTooltip(InformationTooltip)
                end)
                chatBtn:SetHandler("OnClicked", function()
                    ZS:RequestSetInChat(setInfo)
                end)

                -- Рамка прогресс-бара
                local barFrame = WINDOW_MANAGER:CreateControl(nil, row, CT_BACKDROP)
                barFrame:SetDimensions(blockWidth - 30, 22)
                barFrame:SetAnchor(TOPLEFT, nameLabel, BOTTOMLEFT, -28, 4)
                barFrame:SetCenterColor(0, 0, 0, 0.6)
                barFrame:SetEdgeColor(0.9, 0.7, 0.2, 1)
                barFrame:SetEdgeTexture(nil, 1, 1, 1, 0)
                row.barFrame = barFrame

                local bar = WINDOW_MANAGER:CreateControl(nil, barFrame, CT_STATUSBAR)
                bar:SetAnchor(TOPLEFT, barFrame, TOPLEFT, 2, 2)
                bar:SetAnchor(BOTTOMRIGHT, barFrame, BOTTOMRIGHT, -2, -2)
                bar:SetMinMax(0, total > 0 and total or 1)
                bar:SetValue(done)
                bar:SetColor(isComplete and 0 or 0.7, isComplete and 0.7 or 0.2, 0.2, 1)

                local progLabel = WINDOW_MANAGER:CreateControl(nil, bar, CT_LABEL)
                progLabel:SetFont("ZoFontGameSmall")
                progLabel:SetAnchor(CENTER, bar, CENTER, 0, 0)
                progLabel:SetColor(1, 1, 1, 1)
                progLabel:SetText(string.format("%d / %d", done, total))

                local piecesContainer = WINDOW_MANAGER:CreateControl(nil, row, CT_CONTROL)
                piecesContainer:SetAnchor(TOPLEFT, barFrame, BOTTOMLEFT, 0, 8)
                piecesContainer:SetWidth(blockWidth - 30)
                piecesContainer:SetHidden(true)
                row.piecesContainer = piecesContainer

                -- Ленивая загрузка: создаем иконки строго при клике на [+]
                local isBuilt = false

                local function BuildPieces()
                    if isBuilt then return end
                    isBuilt = true

                    local piecesList = GetSetPiecesList(setInfo.itemSetData)
                    local curWidth = piecesContainer:GetWidth()
                    if not curWidth or curWidth <= 0 then curWidth = blockWidth - 30 end

                    local tileSize = 40
                    local spacing = 6
                    local cols = math.max(math.floor(curWidth / (tileSize + spacing)), 1)

                    for i, piece in ipairs(piecesList) do
                        local colIdx = (i - 1) % cols
                        local rowIdx = math.floor((i - 1) / cols)
                        local posX = colIdx * (tileSize + spacing)
                        local posY = rowIdx * (tileSize + spacing)

                        local tile = WINDOW_MANAGER:CreateControl(nil, piecesContainer, CT_BUTTON)
                        tile:SetDimensions(tileSize, tileSize)
                        tile:SetAnchor(TOPLEFT, piecesContainer, TOPLEFT, posX, posY)
                        tile:SetMouseEnabled(true)

                        local tileBg = WINDOW_MANAGER:CreateControl(nil, tile, CT_BACKDROP)
                        tileBg:SetAnchorFill()
                        tileBg:SetCenterColor(0, 0, 0, 0.8)
                        tileBg:SetEdgeTexture(nil, 1, 1, 1, 0)
                        tileBg:SetMouseEnabled(false)

                        if piece.isUnlocked then
                            tileBg:SetEdgeColor(0.8, 0.65, 0.2, 0.9)
                        else
                            tileBg:SetEdgeColor(0.5, 0.1, 0.1, 0.6)
                        end

                        local icon = WINDOW_MANAGER:CreateControl(nil, tile, CT_TEXTURE)
                        icon:SetDimensions(tileSize - 6, tileSize - 6)
                        icon:SetAnchor(CENTER, tile, CENTER, 0, 0)
                        icon:SetTexture(piece.icon)
                        icon:SetMouseEnabled(false)

                        if piece.isUnlocked then
                            icon:SetColor(1, 1, 1, 1)
                        else
                            icon:SetColor(0.25, 0.25, 0.25, 0.65)
                        end

                        tile:SetHandler("OnMouseEnter", function()
                            tileBg:SetCenterColor(0.2, 0.4, 0.8, 0.4)
                            local tileCenterX = tile:GetCenter()
                            local screenCenterX = GuiRoot:GetWidth() / 2
                            if tileCenterX and screenCenterX and tileCenterX < screenCenterX then
                                InitializeTooltip(ItemTooltip, tile, LEFT, 10, 0, RIGHT)
                            else
                                InitializeTooltip(ItemTooltip, tile, RIGHT, -10, 0, LEFT)
                            end
                            if piece.itemLink and piece.itemLink ~= "" then
                                ItemTooltip:SetLink(piece.itemLink)
                            end
                        end)

                        tile:SetHandler("OnMouseExit", function()
                            tileBg:SetCenterColor(0, 0, 0, 0.8)
                            ClearTooltip(ItemTooltip)
                        end)

                        tile:SetHandler("OnClicked", function()
                            if piece.itemLink and piece.itemLink ~= "" then
                                ZO_LinkHandler_InsertLink(piece.itemLink)
                            end
                        end)
                    end

                    local totalRows = math.ceil(#piecesList / cols)
                    local gridHeight = totalRows * (tileSize + spacing)
                    piecesContainer:SetHeight(gridHeight)
                end

                toggleBtn:SetHandler("OnClicked", function()
                    local wasHidden = piecesContainer:IsHidden()
                    if wasHidden then
                        BuildPieces()
                        piecesContainer:SetHidden(false)
                        toggleBtn:SetNormalTexture("/esoui/art/buttons/minus_up.dds")
                        toggleBtn:SetPressedTexture("/esoui/art/buttons/minus_down.dds")
                        toggleBtn:SetMouseOverTexture("/esoui/art/buttons/minus_over.dds")
                    else
                        piecesContainer:SetHidden(true)
                        toggleBtn:SetNormalTexture("/esoui/art/buttons/plus_up.dds")
                        toggleBtn:SetPressedTexture("/esoui/art/buttons/plus_down.dds")
                        toggleBtn:SetMouseOverTexture("/esoui/art/buttons/plus_over.dds")
                    end
                    zo_callLater(function() ZS:RecalculateAll() end, 50)
                end)

                table.insert(rows, row)
                table.insert(createdRows, row)
            end
        end
    end

    ZS.rows = rows
    ZS.header = header
    ZS:RecalculateAll()
    
    ZSWindow:SetHidden(false)
end

function ZoneSets_ToggleWindow()
    if ZSWindow:IsHidden() then
        ZS:ShowWindow()
    else
        ZSWindow:SetHidden(true)
    end
end

-- ================= ПОКАЗ ТОСТОВ И ОБНОВЛЕНИЕ =================

-- --- 1. ЛОГИКА ЗОЛОТОГО ТОСТА (СВОЙ ЛУТ) ---
function ZS:ShowTestToast()
    EVENT_MANAGER:UnregisterForUpdate("ZS_Toast_Hide_Timer")
    toastIcon:SetTexture("/esoui/art/icons/icon_missing.dds")
    toastTitle:SetText(L.testTitle)
    toastProgress:SetText(L.dragMe)
    ZSToast:SetHidden(false)
end

function ZS:ProcessToastQueue()
    if self.IsToastActive then return end
    if not self.ToastQueue or #self.ToastQueue == 0 then
        ZSToast:SetHidden(true)
        return
    end

    self.IsToastActive = true
    local item = table.remove(self.ToastQueue, 1)

    toastIcon:SetTexture(item.icon or "/esoui/art/icons/icon_missing.dds")
    toastTitle:SetText(item.name or "")
    
    if item.total and item.total > 0 then
        toastProgress:SetText(string.format(L.toastProgressFormat or "%s (%d/%d)", item.setName, item.done, item.total))
    else
        toastProgress:SetText(L.addedToColl or "Добавлено в коллекцию")
    end

    ZSToast:SetHidden(false)

    local duration = (#self.ToastQueue > 0) and 2200 or (self.SavedVars.toastDuration or 4000)

    local timerName = "ZS_Toast_Hide_Timer"
    EVENT_MANAGER:UnregisterForUpdate(timerName)
    EVENT_MANAGER:RegisterForUpdate(timerName, duration, function()
        EVENT_MANAGER:UnregisterForUpdate(timerName)
        ZS.IsToastActive = false
        ZS:ProcessToastQueue()
    end)
end

function ZS:ShowToastNotificationForItem(itemLink, setId)
    if not self.SavedVars or self.SavedVars.showToast == false or not itemLink then return end

    local hasSet, setName = GetItemLinkSetInfo(itemLink)
    local icon = GetItemLinkIcon(itemLink) or "/esoui/art/icons/icon_missing.dds"
    local pieceName = zo_strformat("<<1>>", GetItemLinkName(itemLink))

    local done, total = 0, 0
    if setId and setId > 0 and ITEM_SET_COLLECTIONS_DATA_MANAGER then
        local itemSetData = ITEM_SET_COLLECTIONS_DATA_MANAGER:GetItemSetCollectionData(setId)
        if itemSetData then
            done = itemSetData:GetNumUnlockedPieces()
            total = itemSetData:GetNumPieces()
            done = math.min(done + 1, total)
        end
    end

    table.insert(self.ToastQueue, {
        icon = icon,
        name = pieceName,
        setName = zo_strformat("<<1>>", setName or "Новый сет"),
        done = done,
        total = total,
    })

    self:ProcessToastQueue()
end

-- --- 2. ЛОГИКА СИНЕГО ТОСТА (ЛУТ ГРУППЫ) ---
function ZS:ShowTestGroupToast()
    EVENT_MANAGER:UnregisterForUpdate("ZS_GroupToast_Hide_Timer")
    gToastIcon:SetTexture("/esoui/art/icons/icon_missing.dds")
    gToastTitle:SetText(L.testTitle)
    gToastProgress:SetText(L.dragMe)
    ZSGroupToast:SetHidden(false)
end

function ZS:ProcessGroupToastQueue()
    if self.IsGroupToastActive then return end
    if not self.GroupToastQueue or #self.GroupToastQueue == 0 then
        ZSGroupToast:SetHidden(true)
        return
    end

    self.IsGroupToastActive = true
    local item = table.remove(self.GroupToastQueue, 1)

    gToastIcon:SetTexture(item.icon or "/esoui/art/icons/icon_missing.dds")
    gToastTitle:SetText(item.name or "")
    gToastProgress:SetText(item.subtitle or (L.neededInColl or "Нужно в коллекцию"))

    ZSGroupToast:SetHidden(false)

    local queueLen = #self.GroupToastQueue
    local duration
    if queueLen > 3 then
        duration = 1000 -- 1 сек при завале
    elseif queueLen > 0 then
        duration = 1500 -- 1.5 сек при небольшой очереди
    else
        duration = 2200 -- одиночный тост группы
    end

    local timerName = "ZS_GroupToast_Hide_Timer"
    EVENT_MANAGER:UnregisterForUpdate(timerName)
    EVENT_MANAGER:RegisterForUpdate(timerName, duration, function()
        EVENT_MANAGER:UnregisterForUpdate(timerName)
        ZS.IsGroupToastActive = false
        ZS:ProcessGroupToastQueue()
    end)
end

ZS.PendingGroupToasts = {}

function ZS:FlushGroupToastBuffer()
    if not self.PendingGroupToasts or #self.PendingGroupToasts == 0 then return end

    local totalPending = #self.PendingGroupToasts

    -- 1. Единичные предметы (до 4 шт.)
    if totalPending <= 4 then
        for _, item in ipairs(self.PendingGroupToasts) do
            table.insert(self.GroupToastQueue, {
                icon = item.icon,
                name = string.format("|c00FFFF%s|r: %s", item.player, item.name),
                subtitle = string.format("|cFFD700%s|r  |c00FFFF• %s|r", item.setName, L.neededInColl or "Нужно в коллекцию"),
            })
        end

    -- 2. Масс-лут триала (5+ шт.) — группируем по игрокам
    else
        local playersMap = {}
        local playersOrder = {}

        for _, item in ipairs(self.PendingGroupToasts) do
            if not playersMap[item.player] then
                playersMap[item.player] = { count = 0, lastIcon = item.icon }
                table.insert(playersOrder, item.player)
            end
            playersMap[item.player].count = playersMap[item.player].count + 1
        end

        for _, pName in ipairs(playersOrder) do
            local pData = playersMap[pName]
            local countText = string.format(L.groupLootedCount or "Выбил нужных вещей: %d шт.", pData.count)
            table.insert(self.GroupToastQueue, {
                icon = pData.lastIcon,
                name = string.format("|c00FFFF%s|r", pName),
                subtitle = string.format("|c00FFFF%s|r", countText),
            })
        end
    end

    self.PendingGroupToasts = {}
    self:ProcessGroupToastQueue()
end

function ZS:QueueGroupLootToast(player, itemName, setName, icon)
    if not self.SavedVars or not self.SavedVars.groupToast or self.SavedVars.showToast == false then
        return
    end

    table.insert(self.PendingGroupToasts, {
        player = player,
        name = itemName,
        setName = setName,
        icon = icon,
    })

    EVENT_MANAGER:UnregisterForUpdate("ZS_Group_Loot_Buffer")
    EVENT_MANAGER:RegisterForUpdate("ZS_Group_Loot_Buffer", 350, function()
        EVENT_MANAGER:UnregisterForUpdate("ZS_Group_Loot_Buffer")
        ZS:FlushGroupToastBuffer()
    end)
end

-- Просто обновляем окно аддона, если оно открыто в момент привязки
local function OnItemSetCollectionUpdated(eventCode, itemSetId)
    if not ZSWindow:IsHidden() then
        ZS:ShowWindow()
    end
end


-- ================= СЛЕЖКА ЗА ЛУТОМ ГРУППЫ И АВТОПРИВЯЗКА =================

-- Ловец сетовых предметов в нашем рюкзаке (только Стикербук, без крафта)
local function OnInventorySingleSlotUpdate(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange)
    if bagId ~= BAG_BACKPACK or not isNewItem then return end

    local itemLink = GetItemLink(bagId, slotIndex)
    if not itemLink or itemLink == "" then return end

    -- 1. ЖЕЛЕЗНЫЙ ЩИТ: проверяем, входит ли вещь в Стикербук (отсекает весь крафт!)
    if not IsItemLinkSetCollectionPiece(itemLink) then return end

    local pieceId = GetItemLinkItemId(itemLink)
    if not pieceId or pieceId <= 0 then return end

    local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink)
    if not hasSet or not setId or setId <= 0 then return end

    -- 2. Проверяем статус в Стикербуке
    local isUnlocked = IsItemSetCollectionPieceUnlocked(pieceId)
    if not isUnlocked then
        local didBind = false

        -- Если включена автопривязка и вещь не привязана
        if ZS.SavedVars and ZS.SavedVars.autoBind and not IsItemBound(bagId, slotIndex) then
            BindItem(bagId, slotIndex)
            didBind = true
        elseif IsItemBound(bagId, slotIndex) then
            didBind = true
        end

        -- Показываем тост ТОЛЬКО если вещь реально привязана в коллекцию!
        if didBind then
            ZS:ShowToastNotificationForItem(itemLink, setId)
        end
    end

    -- Отправляем в «Текущий заход»
    ZS:AddLootToHistory(itemLink, pieceId)

    if not ZSWindow:IsHidden() and ZS.CurrentTab == "history" then
        ZS:ShowWindow()
    end
end

-- Ловец лута сопартийцев
local function OnLootReceived(eventCode, receivedBy, itemName, quantity, itemSound, lootType, questItem, lootData, isSystemLoot)
    if not itemName or itemName == "" then return end

    local myCharName = zo_strformat("<<1>>", GetUnitName("player"))
    local myDisplayName = GetDisplayName()
    local receiver = zo_strformat("<<1>>", receivedBy)

    -- Игнорируем себя и пустые имена
    if receiver == myCharName or receiver == myDisplayName or receiver == "" then
        return
    end

    local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemName)
    if not hasSet or not setName or setName == "" then return end

    local pieceId = GetItemLinkItemId(itemName)
    if not pieceId or pieceId <= 0 then return end
    
    -- === АВТО-ОЧИСТКА ПРОСЬБ: если сопартиец сам выбил то, что просил ===
    if ZS.PlayerRequests and ZS.PlayerRequests[receiver] then
        local pReq = ZS.PlayerRequests[receiver]
        if pReq.pieces and pReq.pieces[pieceId] then
            pReq.pieces[pieceId] = nil
        end
        if not pReq.pieces or next(pReq.pieces) == nil then
            ZS.PlayerRequests[receiver] = nil
        end
    end

    -- Если у нас уже есть эта вещь — игнорируем
    local isUnlocked = IsItemSetCollectionPieceUnlocked(pieceId)
    if isUnlocked then return end

    local zoneId, zoneName = ZS:GetCurrentZoneInfo()
    if zoneId <= 0 then return end

    ZS.SavedVars.ZoneGroupLoot = ZS.SavedVars.ZoneGroupLoot or {}
    ZS.SavedVars.ZoneGroupLoot[zoneId] = ZS.SavedVars.ZoneGroupLoot[zoneId] or {}
    local gList = ZS.SavedVars.ZoneGroupLoot[zoneId]

    for _, entry in ipairs(gList) do
        if entry.player == receiver and entry.pieceId == pieceId then
            return
        end
    end

    local icon = GetItemLinkIcon(itemName) or "/esoui/art/icons/icon_missing.dds"
    local pName = zo_strformat("<<1>>", GetItemLinkName(itemName))

    table.insert(gList, 1, {
        player = receiver,
        pieceId = pieceId,
        name = pName,
        setName = zo_strformat("<<1>>", setName),
        icon = icon,
        itemLink = itemName,
        timestamp = GetTimeStamp(),
    })

    -- Отправляем в синий тост уведомлений
    ZS:QueueGroupLootToast(receiver, pName, zo_strformat("<<1>>", setName), icon)

    if not ZSWindow:IsHidden() and ZS.CurrentTab == "history" then
        ZS:ShowWindow()
    end
end

-- ================= ОТСЛЕЖИВАНИЕ ЧАТА ДЛЯ ТРЕЙДА И КОНВЕЙЕРА =================

local function OnChatMessage(eventCode, channelType, fromName, text, isCustomerService, fromDisplayName)
    -- 1. Конвейер наших собственных сообщений
    local isMyMessage = (fromDisplayName == GetDisplayName())
        or (fromName and fromName ~= "" and zo_strformat("<<1>>", fromName) == zo_strformat("<<1>>", GetUnitName("player")))
        or (channelType == CHAT_CHANNEL_WHISPER_SENT)

    if isMyMessage then
        if ZS.ChatQueue and ZS.ChatQueue.messages then
            if ZS.ChatQueue.currentIdx < #ZS.ChatQueue.messages then
                ZS.ChatQueue.currentIdx = ZS.ChatQueue.currentIdx + 1
                zo_callLater(function()
                    ZS:LoadNextChatChunk()
                end, 150)
            else
                ZS.ChatQueue = nil
            end
        end
        return
    end

    -- 2. Слушаем ТОЛЬКО группу и личный шепот
    if channelType ~= CHAT_CHANNEL_PARTY and channelType ~= CHAT_CHANNEL_WHISPER then
        return
    end

    if not text or text == "" then return end

    local sender = zo_strformat("<<1>>", fromDisplayName or fromName or "")
    if sender == "" or sender == GetDisplayName() then return end

    local now = GetTimeStamp()

    -- Ловим прямые ссылки на сетовые предметы (|H...|h)
    for itemLink in string.gmatch(text, "|H.-|h.-|h") do
        local hasSet = GetItemLinkSetInfo(itemLink)
        local pieceId = GetItemLinkItemId(itemLink)

        if hasSet and pieceId and pieceId > 0 then
            ZS.PlayerRequests = ZS.PlayerRequests or {}
            ZS.PlayerRequests[sender] = ZS.PlayerRequests[sender] or { pieces = {}, timestamp = now }
            ZS.PlayerRequests[sender].pieces = ZS.PlayerRequests[sender].pieces or {}
            ZS.PlayerRequests[sender].pieces[pieceId] = now
            ZS.PlayerRequests[sender].timestamp = now
        end
    end
end

-- ================= ПОМОЩНИК ОБМЕНА (TRADE HELPER) =================

local tradeHelper = nil
local btnPutRequested = nil
local btnDumpExtra = nil

-- Запоминаем текущего партнера по трейду
ZS.CurrentTradePartner = ""

local function GetTradePartnerName()
    if ZS.CurrentTradePartner and ZS.CurrentTradePartner ~= "" then
        return ZS.CurrentTradePartner
    end
    if TRADE_WINDOW and TRADE_WINDOW.targetName and TRADE_WINDOW.targetName.GetText then
        return zo_strformat("<<1>>", TRADE_WINDOW.targetName:GetText())
    end
    return ""
end

-- Поиск запрошенных вещей в сумке с памятью на 2 часа (7200 сек)
local function FindRequestedItemsInBag(partnerName)
    local results = {}
    if not ZS.PlayerRequests then return results end

    local now = GetTimeStamp()
    local maxAge = 7200 -- 2 часа (время жизни таймера передачи лута в ESO)
    local cleanPartner = zo_strformat("<<1>>", partnerName or "")

    -- Ищем запросы конкретно для нашего партнера по трейду
    local targetPieces = (cleanPartner ~= "" and ZS.PlayerRequests[cleanPartner]) and ZS.PlayerRequests[cleanPartner].pieces or nil

    local bagSize = GetBagSize(BAG_BACKPACK)

    for slotIndex = 0, bagSize - 1 do
        local itemLink = GetItemLink(BAG_BACKPACK, slotIndex)
        if itemLink and itemLink ~= "" then
            local isTradable = (not IsItemBound(BAG_BACKPACK, slotIndex)) or (IsItemBoPAndTradeable and IsItemBoPAndTradeable(BAG_BACKPACK, slotIndex))
            if isTradable then
                local hasSet = GetItemLinkSetInfo(itemLink)
                local pieceId = GetItemLinkItemId(itemLink)

                if hasSet and pieceId and pieceId > 0 then
                    local isRequested = false

                    -- 1. Сначала проверяем точный запрос от нашего партнера по трейду
                    if targetPieces and targetPieces[pieceId] and (now - targetPieces[pieceId]) <= maxAge then
                        isRequested = true
                    else
                        -- 2. Запасной вариант: проверяем общие запросы группы
                        for _, reqData in pairs(ZS.PlayerRequests) do
                            if reqData.pieces and reqData.pieces[pieceId] and (now - reqData.pieces[pieceId]) <= maxAge then
                                isRequested = true
                                break
                            end
                        end
                    end

                    if isRequested then
                        table.insert(results, slotIndex)
                        if #results == 5 then break end
                    end
                end
            end
        end
    end

    return results
end

-- Поиск любого лишнего сетового лута с таймером в сумке
local function FindExtraDungeonLootInBag()
    local results = {}
    local bagSize = GetBagSize(BAG_BACKPACK)

    for slotIndex = 0, bagSize - 1 do
        local itemLink = GetItemLink(BAG_BACKPACK, slotIndex)
        if itemLink and itemLink ~= "" then
            -- Проверяем: либо вещь вообще не привязана, либо на ней висит таймер группы/Архива
            local isTradable = (not IsItemBound(BAG_BACKPACK, slotIndex)) or (IsItemBoPAndTradeable and IsItemBoPAndTradeable(BAG_BACKPACK, slotIndex))
            if isTradable then
                local hasSet = GetItemLinkSetInfo(itemLink)
                local pieceId = GetItemLinkItemId(itemLink)

                if hasSet and pieceId and pieceId > 0 and IsItemSetCollectionPieceUnlocked(pieceId) then
                    table.insert(results, slotIndex)
                    if #results == 5 then break end
                end
            end
        end
    end

    return results
end

local function ExecuteTradeFill(slotsList)
    if not slotsList or #slotsList == 0 then return end
    local added = 0
    for _, slotIndex in ipairs(slotsList) do
        if TRADE_WINDOW and TRADE_WINDOW.AddItemToTrade then
            TRADE_WINDOW:AddItemToTrade(BAG_BACKPACK, slotIndex)
            added = added + 1
        elseif TradeAddItem then
            TradeAddItem(BAG_BACKPACK, slotIndex)
            added = added + 1
        end
    end
    d(string.format(L.tradeFilledMsg, added))
end

local function CreateTradeHelper()
    if tradeHelper then return end

    -- Создаем независимое окно верхнего уровня (поверх всех сцен и PerfectPixel)
    tradeHelper = WINDOW_MANAGER:CreateTopLevelWindow("ZoneSets_TradeHelper")
    tradeHelper:SetDimensions(420, 68)
    tradeHelper:SetClampedToScreen(true)
    tradeHelper:SetMovable(true)
    tradeHelper:SetMouseEnabled(true)
    tradeHelper:SetHidden(true)

    if ZS.SavedVars and ZS.SavedVars.tradeHelperLeft and ZS.SavedVars.tradeHelperTop then
        tradeHelper:ClearAnchors()
        tradeHelper:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, ZS.SavedVars.tradeHelperLeft, ZS.SavedVars.tradeHelperTop)
    else
        -- По умолчанию ставим слева от центра, над блоком предложения
        tradeHelper:ClearAnchors()
        tradeHelper:SetAnchor(CENTER, GuiRoot, CENTER, -250, 180)
    end

    tradeHelper:SetHandler("OnMoveStop", function()
        if ZS.SavedVars then
            ZS.SavedVars.tradeHelperLeft, ZS.SavedVars.tradeHelperTop = tradeHelper:GetLeft(), tradeHelper:GetTop()
        end
    end)

    local tradeHelperBg = WINDOW_MANAGER:CreateControl(nil, tradeHelper, CT_BACKDROP)
    tradeHelperBg:SetAnchorFill()
    tradeHelperBg:SetCenterColor(0, 0, 0, 0.85)
    tradeHelperBg:SetEdgeColor(0.9, 0.7, 0.2, 1)
    tradeHelperBg:SetEdgeTexture(nil, 1, 1, 1, 0)
    tradeHelperBg:SetMouseEnabled(false)

    local tradeHelperTitle = WINDOW_MANAGER:CreateControl(nil, tradeHelper, CT_LABEL)
    tradeHelperTitle:SetFont("ZoFontWinH4")
    tradeHelperTitle:SetAnchor(TOPLEFT, tradeHelper, TOPLEFT, 10, 6)
    tradeHelperTitle:SetText(L.tradeHelperTitle)
    tradeHelperTitle:SetMouseEnabled(false)

    btnPutRequested = WINDOW_MANAGER:CreateControl(nil, tradeHelper, CT_BUTTON)
    btnPutRequested:SetDimensions(195, 24)
    btnPutRequested:SetAnchor(BOTTOMLEFT, tradeHelper, BOTTOMLEFT, 10, -8)
    btnPutRequested:SetFont("ZoFontGameBold")

    btnDumpExtra = WINDOW_MANAGER:CreateControl(nil, tradeHelper, CT_BUTTON)
    btnDumpExtra:SetDimensions(195, 24)
    btnDumpExtra:SetAnchor(BOTTOMRIGHT, tradeHelper, BOTTOMRIGHT, -10, -8)
    btnDumpExtra:SetFont("ZoFontGameBold")
end

local function OnTradeWindowOpen()
    CreateTradeHelper()
    if not tradeHelper then return end

    local partner = GetTradePartnerName()
    local requestedSlots = FindRequestedItemsInBag(partner)
    local extraSlots = FindExtraDungeonLootInBag()

    if #requestedSlots > 0 then
        btnPutRequested:SetText(string.format("|c00FF00[%s]|r", string.format(L.tradePutRequested, #requestedSlots)))
        btnPutRequested:SetEnabled(true)
        btnPutRequested:SetHandler("OnClicked", function()
            ExecuteTradeFill(requestedSlots)
            btnPutRequested:SetEnabled(false)
        end)
    else
        btnPutRequested:SetText("|c777777[" .. string.format(L.tradePutRequested, 0) .. "]|r")
        btnPutRequested:SetEnabled(false)
    end

    if #extraSlots > 0 then
        btnDumpExtra:SetText(string.format("|cFFD700[%s]|r", string.format(L.tradeDumpExtra, #extraSlots)))
        btnDumpExtra:SetEnabled(true)
        btnDumpExtra:SetHandler("OnClicked", function()
            ExecuteTradeFill(extraSlots)
            btnDumpExtra:SetEnabled(false)
        end)
    else
        btnDumpExtra:SetText("|c777777[" .. string.format(L.tradeDumpExtra, 0) .. "]|r")
        btnDumpExtra:SetEnabled(false)
    end

    tradeHelper:SetHidden(false)
end

local function OnTradeWindowClose()
    if tradeHelper then
        tradeHelper:SetHidden(true)
    end
end

local function OnTradeSucceeded()
    local partner = GetTradePartnerName()
    if partner and ZS.PlayerRequests and ZS.PlayerRequests[partner] then
        ZS.PlayerRequests[partner] = nil -- Обмен прошел, закрываем запрос для этого игрока
    end
    if tradeHelper then
        tradeHelper:SetHidden(true)
    end
end

-- ================= СОХРАНЕНИЕ ПОЗИЦИИ И НАСТРОЕК =================
local function InitializeSavedVars()
    ZS.SavedVars = ZO_SavedVars:NewAccountWide("ZoneSets_AccountSavedVariables", 1, nil, {
        left = nil,
        top = nil,
        width = DEFAULT_WIDTH,
        height = DEFAULT_HEIGHT,
        toastLeft = nil,
        toastTop = nil,
        toastDuration = 4000,
        showToast = true,
        autoBind = false,
        groupToast = false,
        ZoneHistory = {},
        ZoneGroupLoot = {},
    }, GetWorldName())

    if ZS.SavedVars.left and ZS.SavedVars.top then
        ZSWindow:ClearAnchors()
        ZSWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, ZS.SavedVars.left, ZS.SavedVars.top)
    else
        ZSWindow:ClearAnchors()
        ZSWindow:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end

    if ZSToast then
        if ZS.SavedVars.toastLeft and ZS.SavedVars.toastTop then
            ZSToast:ClearAnchors()
            ZSToast:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, ZS.SavedVars.toastLeft, ZS.SavedVars.toastTop)
        else
            ZSToast:ClearAnchors()
            ZSToast:SetAnchor(TOP, GuiRoot, TOP, 0, 150)
        end
    end
    
    if ZSGroupToast then
        if ZS.SavedVars.groupToastLeft and ZS.SavedVars.groupToastTop then
            ZSGroupToast:ClearAnchors()
            ZSGroupToast:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, ZS.SavedVars.groupToastLeft, ZS.SavedVars.groupToastTop)
        else
            ZSGroupToast:ClearAnchors()
            ZSGroupToast:SetAnchor(TOP, GuiRoot, TOP, 0, 220)
        end
    end

    if ZSWindow and ZS.SavedVars then
        ZSWindow:SetDimensions(ZS.SavedVars.width, ZS.SavedVars.height)
        local w, h = ZSWindow:GetDimensions()
        if scroll then
            scroll:SetDimensions(w - 28, h - 170)
            if scrollChild then
                scrollChild:SetWidth(scroll:GetWidth() - 10)
            end
        end
        if ZS.ShareBtn and ZS.ShareBtn.SetWidth then
            ZS.ShareBtn:SetWidth(w - 28)
        end
    end
end

ZSWindow:SetHandler("OnMoveStop", function()
    if ZS.SavedVars then
        ZS.SavedVars.left, ZS.SavedVars.top = ZSWindow:GetLeft(), ZSWindow:GetTop()
    end
end)

ZSWindow:SetHandler("OnResizeStop", function()
    local w, h = ZSWindow:GetDimensions()
    if ZS.SavedVars then
        ZS.SavedVars.width, ZS.SavedVars.height = w, h
    end
    if scroll then
        scroll:SetDimensions(w - 28, h - 170)
        if scrollChild then
            scrollChild:SetWidth(scroll:GetWidth() - 10)
        end
    end
    if ZS.ShareBtn and ZS.ShareBtn.SetWidth then
        ZS.ShareBtn:SetWidth(w - 28)
    end

    zo_callLater(function()
        if ZS.UpdateRowWidths then
            ZS:UpdateRowWidths(w)
        end
    end, 50)
end)

-- Регистрация команд
local function RegisterSlashCommands()
    local function SlashCommandParser(extra)
        local args = {}
        for word in string.gmatch(extra, "%S+") do
            table.insert(args, string.lower(word))
        end

        local cmd = args[1] or ""

        -- 1. Настройка и перетаскивание ЗОЛОТОГО тоста (своего)
        if cmd == "test" or cmd == "testgold" then
            if ZSToast:IsHidden() then
                ZS:ShowTestToast()
                d("|cFFD700[ZoneSets]|r Золотой тост открыт для настройки. Перетащите мышкой!")
            else
                ZSToast:SetHidden(true)
                d("|cFFD700[ZoneSets]|r Позиция золотого тоста сохранена.")
            end

        -- 2. Настройка и перетаскивание СИНЕГО тоста (группы)
        elseif cmd == "testblue" or cmd == "testgroup" then
            if ZSGroupToast:IsHidden() then
                ZS:ShowTestGroupToast()
                d("|c00FFFF[ZoneSets]|r Синий тост открыт для настройки. Перетащите мышкой!")
            else
                ZSGroupToast:SetHidden(true)
                d("|c00FFFF[ZoneSets]|r Позиция синего тоста сохранена.")
            end

        -- 3. Тест триального масс-лута на синем окне (залп из 8 предметов)
        elseif cmd == "testraid" or cmd == "testtrial" then
            ZS.SavedVars.groupToast = true
            ZS:UpdateGroupToastVisuals()
            ZS:QueueGroupLootToast("Vasya_Pupkin", "Посох огня", "Скорбь", "/esoui/art/icons/gear_breton_staff_fire_a.dds")
            ZS:QueueGroupLootToast("Vasya_Pupkin", "Шлем", "Скорбь", "/esoui/art/icons/gear_nord_heavy_head_a.dds")
            ZS:QueueGroupLootToast("Elena_Healer", "Кольцо", "Олорима", "/esoui/art/icons/gear_jewelry_ring_1.dds")
            ZS:QueueGroupLootToast("Elena_Healer", "Ожерелье", "Олорима", "/esoui/art/icons/gear_jewelry_necklace_1.dds")
            ZS:QueueGroupLootToast("Elena_Healer", "Сапоги", "Олорима", "/esoui/art/icons/gear_altmer_light_feet_a.dds")
            ZS:QueueGroupLootToast("Tank_Ivan", "Щит", "Йолнакрина", "/esoui/art/icons/gear_nord_shield_a.dds")
            ZS:QueueGroupLootToast("Tank_Ivan", "Меч", "Йолнакрина", "/esoui/art/icons/gear_nord_1hsword_a.dds")
            ZS:QueueGroupLootToast("Super_DD", "Кинжал", "Суль-Зан", "/esoui/art/icons/gear_argonian_dagger_a.dds")
            d("|c00FFFF[ZoneSets Test]|r Залп из 8 предметов запущен в синее окно!")

        -- Быстрое переключение групповых тостов
        elseif cmd == "grouptoast" then
            local arg = args[2] or ""
            if arg == "off" or arg == "0" then
                ZS.SavedVars.groupToast = false
                ZS:UpdateGroupToastVisuals()
                d("|c777777[ZoneSets]|r Групповые тосты: |cFF0000ВЫКЛЮЧЕНЫ|r")
            elseif arg == "on" or arg == "1" then
                ZS.SavedVars.groupToast = true
                ZS:UpdateGroupToastVisuals()
                d("|c00FFFF[ZoneSets]|r Групповые тосты: |c00FF00ВКЛЮЧЕНЫ|r")
            else
                local status = ZS.SavedVars.groupToast and "|c00FF00ВКЛЮЧЕНЫ|r" or "|cFF0000ВЫКЛЮЧЕНЫ|r"
                d(string.format("|c00FFFF[ZoneSets]|r Статус групповых тостов: %s (используйте: /zs grouptoast on/off)", status))
            end


        elseif cmd == "toast" then
            local arg = args[2] or ""
            if arg == "off" or arg == "disable" then
                ZS.SavedVars.showToast = false
                d(L.toastDisabled)
            elseif arg == "on" or arg == "enable" then
                ZS.SavedVars.showToast = true
                d(L.toastEnabled)
            else
                local secs = tonumber(arg)
                if secs and secs > 0 then
                    ZS.SavedVars.showToast = true
                    ZS.SavedVars.toastDuration = secs * 1000
                    d(string.format(L.toastDurationSet, secs))
                else
                    local status = (ZS.SavedVars.showToast ~= false) and "|c00FF00ВКЛЮЧЕНЫ|r" or "|cFF0000ОТКЛЮЧЕНЫ|r"
                    local curSecs = (ZS.SavedVars.toastDuration or 4000) / 1000
                    d(string.format(L.toastStatus, status, curSecs))
                end
            end

        -- Тестовая имитация раздачи НАСТОЯЩИХ сетов текущей зоны
        elseif cmd == "testshare" or cmd == "sharetest" then
            local zoneId, zoneName = ZS:GetCurrentZoneInfo()
            local zoneSets = ZS:GetZoneSets(zoneId, zoneName)

            if not zoneSets or #zoneSets == 0 then
                d("|cFF5555[ZoneSets Test]|r В этой зоне не найдено сетов. Зайдите в данж или зону с сетами!")
                return
            end

            local realLinks = {}
            local countSimulator = { 2, 1, 3, 1, 2, 1, 1, 2, 1, 2, 1, 1 }
            local itemIndex = 1

            for _, setInfo in ipairs(zoneSets) do
                if setInfo.itemSetData and setInfo.itemSetData.PieceIterator then
                    local pieceCount = 0
                    for _, pieceData in setInfo.itemSetData:PieceIterator() do
                        if pieceData and pieceCount < 3 then
                            local pieceId = pieceData:GetId()
                            local realLink = GetItemSetCollectionPieceItemLink(pieceId, LINK_STYLE_BRACKETS)

                            if realLink and realLink ~= "" then
                                local simulatedCount = countSimulator[itemIndex] or 1
                                if simulatedCount > 1 then
                                    table.insert(realLinks, string.format("%s×%d", realLink, simulatedCount))
                                else
                                    table.insert(realLinks, realLink)
                                end

                                pieceCount = pieceCount + 1
                                itemIndex = itemIndex + 1
                            end
                        end
                    end
                end
            end

            local messages = ZS.BuildChatMessages("offer", nil, realLinks)
            ZS.ChatQueue = {
                mode = "offer",
                messages = messages,
                currentIdx = 1,
            }
            ZS:LoadNextChatChunk()
            d(string.format("|c00FF00[ZoneSets Test]|r Сгенерировано %d сетовых предметов (всего %d сообщений в чате). Нажмите Enter!", #realLinks, #messages))
        -- Тестовая имитация запроса вещи по ссылке
        elseif cmd == "fake" or cmd == "req" or cmd == "testreq" then
            local rawQuery = string.match(extra, "^%S+%s+(.*)$") or ""
            local itemLink = string.match(rawQuery, "|H.-|h.-|h")
            if not itemLink then
                d("|c39DB92[ZoneSets Test]|r Использование: /zs testreq <ссылка на предмет>")
                d("Пример: /zs testreq [Посох огня Материнской скорби]")
                return
            end

            local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink)
            local pieceId = GetItemLinkItemId(itemLink)
            if not hasSet or not pieceId or pieceId <= 0 then
                d("|cFF5555[ZoneSets Test]|r Указанный предмет не является сетовым!")
                return
            end

            local now = GetTimeStamp()
            ZS.PlayerRequests = ZS.PlayerRequests or {}
            ZS.PlayerRequests["TestPlayer"] = {
                pieces = { [pieceId] = now },
                timestamp = now,
            }

            d(string.format("|c00FF00[ZoneSets Test]|r Запрос записан для TestPlayer: %s (ID: %d)", itemLink, pieceId))
            d("|c00FF00[ZoneSets Test]|r Откройте окно трейда или вкладку Истории для проверки!")

        else
            ZoneSets_ToggleWindow()
        end
    end

    SLASH_COMMANDS["/zs"] = SlashCommandParser
    SLASH_COMMANDS["/zonesets"] = SlashCommandParser
end

local function OnPlayerActivated(event)
    ZS:CheckZoneTransition()
end

local function OnAddOnLoaded(event, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    InitializeSavedVars()
    RegisterSlashCommands()
    
    ZS.CurrentTab = "zone"
    ZS:UpdateTabVisuals()
    ZS:UpdateAutoBindVisuals()
    ZS:UpdateGroupToastVisuals()
    
    
    
    -- Подключаем сцену торговли
    local tradeScene = SCENE_MANAGER:GetScene("trade")
    if tradeScene then
        tradeScene:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_SHOWN then
                OnTradeWindowOpen()
            elseif newState == SCENE_HIDDEN then
                OnTradeWindowClose()
            end
        end)
    end
    
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySingleSlotUpdate)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK, REGISTER_FILTER_IS_NEW_ITEM, true)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ITEM_SET_COLLECTION_UPDATED, OnItemSetCollectionUpdated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_LOOT_RECEIVED, OnLootReceived)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CHAT_MESSAGE_CHANNEL, OnChatMessage)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_TRADE_SUCCEEDED, OnTradeSucceeded)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_TRADE_INVITE_WAITING, function(event, invitee) ZS.CurrentTradePartner = zo_strformat("<<1>>", invitee) end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_TRADE_INVITE_CONSIDERING, function(event, inviter) ZS.CurrentTradePartner = zo_strformat("<<1>>", inviter) end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)