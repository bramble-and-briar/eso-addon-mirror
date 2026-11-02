-- Tamriel Collections - Archive Lorebooks v1.0.0
-- ESO's Lore Library owns the catalogue and character read state.
local TC = TamrielCollections
local ID = 'lorebooks'
local ICON = 'EsoUI/Art/ZoneStories/completionTypeIcon_lorebooks.dds'
local GOLD, GREEN, RED = '|cFFEBB3', '|c66CC66', '|cE57373'
local TEMPLATE = 'ZO_QuestJournal_Gamepad_MenuEntryTemplate'

local function Text(value) return zo_strformat(value or '') end
local function Key(value)
    return (zo_strlower(Text(value)):gsub('|c%x%x%x%x%x%x', ''):gsub('|r', '')
        :gsub('%^.*$', ''):gsub('[%p%c]+', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- These collections belong to the separate Motifs and Style Pages modules.
-- Match section names, not the word "style" inside ordinary lorebook titles.
local otherArchiveSections = {
    ['crafting motifs'] = true, ['crafting motif'] = true, ['motifs'] = true,
    ['style pages'] = true, ['style page'] = true, ['styles'] = true,
    ['crafting style pages'] = true, ['crafting styles'] = true,
    ['crafting style books'] = true, ['outfit styles'] = true, ['outfit style pages'] = true,
}

local function IsOtherArchiveSection(name)
    local key = Key(name)
    return otherArchiveSections[key] == true or key:match('^crafting motif %d') ~= nil
        or key:match('^style page ') ~= nil
end

local function AddCollection(result, category, collection)
    collection.nameKey = Key(collection.name)
    category.collections[#category.collections + 1] = collection
    result.collections[#result.collections + 1] = collection
    result.byKey[collection.key] = collection
    category.known, category.total = category.known + collection.known, category.total + collection.total
    result.known, result.total = result.known + collection.known, result.total + collection.total
end

local function AddCategory(result, category)
    category.nameKey = Key(category.name)
    if #category.collections > 0 then
        result.categories[#result.categories + 1] = category
        result.byKey[category.key] = category
    end
end

local function Catalogue()
    local result = { categories = {}, collections = {}, byKey = {}, known = 0, total = 0 }
    -- Retain every other native collection, including locked ones. Exclude
    -- motifs/styles before adding rows, search data or completion totals.
    if GetNumLoreCategories and GetLoreCategoryInfo and GetLoreCollectionInfo then
        for ci = 1, GetNumLoreCategories() do
            local name, count, categoryId = GetLoreCategoryInfo(ci)
            local category = { kind = 'category', name = Text(name), categoryIndex = ci,
                key = 'category:' .. tostring(categoryId or ci), collections = {}, known = 0, total = 0 }
            local otherArchiveCategory = IsOtherArchiveSection(name)
            for li = 1, (count or 0) do
                local title, description, known, total, hidden, icon, collectionId = GetLoreCollectionInfo(ci, li)
                -- "Crafting Books" is ordinary lore, even if ESO groups it
                -- alongside motifs. Keep it while removing the style families.
                local ordinaryCraftingLore = Key(title) == 'crafting books'
                if not IsOtherArchiveSection(title) and (not otherArchiveCategory or ordinaryCraftingLore) then
                    local collection = { kind = 'collection', name = Text(title), description = Text(description),
                        known = known or 0, total = total or 0, hidden = hidden, icon = icon, category = category,
                        categoryIndex = ci, collectionIndex = li,
                        key = category.key .. ':collection:' .. tostring(collectionId or li) }
                    AddCollection(result, category, collection)
                end
            end
            AddCategory(result, category)
        end
    end
    -- Correspondence is a separate native catalogue, not a lore category.
    -- This includes both quest contacts and hirelings without a name whitelist.
    if GetNumMailLists and GetMailListName and GetNumUnlockedMailsInMailList then
        local category = { kind = 'category', name = 'Correspondence', key = 'mail',
            collections = {}, known = 0, total = 0 }
        for mi = 1, GetNumMailLists() do
            local known, total = GetNumUnlockedMailsInMailList(mi)
            local collection = { kind = 'collection', name = Text(GetMailListName(mi)), description = '',
                known = known or 0, total = total or 0, category = category, mailListIndex = mi,
                icon = GetMailListGamepadIcon and GetMailListGamepadIcon(mi),
                key = 'mail:collection:' .. tostring(mi) }
            AddCollection(result, category, collection)
        end
        AddCategory(result, category)
    end
    local function ByName(a, b)
        local aName, bName = a.nameKey, b.nameKey
        if aName == bName then return a.key < b.key end
        return aName < bName
    end
    local function ByMissing(a, b)
        local aMissing = math.max(a.total - a.known, 0)
        local bMissing = math.max(b.total - b.known, 0)
        if (aMissing == 0) ~= (bMissing == 0) then return aMissing > 0 end
        if aMissing ~= bMissing then return aMissing < bMissing end
        return ByName(a, b)
    end
    table.sort(result.categories, ByName)
    table.sort(result.collections, ByMissing)
    for _, category in ipairs(result.categories) do table.sort(category.collections, ByMissing) end
    return result
end

local function Model(screen)
    if not screen._tclCatalogue then screen._tclCatalogue = Catalogue() end
    return screen._tclCatalogue
end

local VisibleBooks, Counts
local function IncludeCollection(screen, collection)
    local known, total = Counts(screen, collection)
    if screen._tclZone and total == 0 then return false end
    return screen._tclShowAll or known < total
end

local function ReadBook(collection, index)
    local book
    if collection.mailListIndex then
        local known = index <= collection.known
        local sender, subject, message, icon
        if known and GetMailInfoFromMailList then
            sender, subject, message, icon = GetMailInfoFromMailList(collection.mailListIndex, index)
        end
        local name = subject and subject ~= '' and Text(subject)
            or (known and 'Collected letter' or 'Uncollected letter')
        book = { kind = 'book', name = string.format('%s (%d)', name, index),
            sender = Text(sender), icon = icon, known = known, bookIndex = index,
            collection = collection, key = collection.key .. ':mail:' .. tostring(index) }
    elseif GetLoreBookInfo then
        local title, icon, known, bookId = GetLoreBookInfo(collection.categoryIndex, collection.collectionIndex, index)
        if title and title ~= '' then
            book = { kind = 'book', name = Text(title), icon = icon, known = known == true,
                bookId = bookId, bookIndex = index, collection = collection,
                key = collection.key .. ':book:' .. tostring(bookId or index) }
        end
    end
    if book then
        book.nameKey = Key(book.name)
        book.senderKey = book.sender and Key(book.sender)
    end
    return book
end

local function SortBooks(books)
    table.sort(books, function(a, b)
        if a.known ~= b.known then return not a.known end
        if a.nameKey ~= b.nameKey then return a.nameKey < b.nameKey end
        return a.bookIndex < b.bookIndex
    end)
end

local function Books(screen, collection)
    screen._tclBooks = screen._tclBooks or {}
    local books = screen._tclBooks[collection.key]
    if books then return books end
    books = {}
    for index = 1, collection.total do
        local book = ReadBook(collection, index)
        if book then books[#books + 1] = book end
    end
    SortBooks(books)
    screen._tclBooks[collection.key] = books
    return books
end

VisibleBooks = function(screen, collection)
    if not screen._tclZone then return Books(screen, collection) end
    screen._tclZoneBooks = screen._tclZoneBooks or {}
    local cached = screen._tclZoneBooks[collection.key]
    if cached then return cached.books end
    cached = { books = {}, known = 0, total = 0 }
    local sources = TC.lorebookSources
    for _, book in ipairs(Books(screen, collection)) do
        if sources and sources.InZone(book, screen._tclZone) then
            table.insert(cached.books, book)
            cached.total = cached.total + 1
            if book.known then cached.known = cached.known + 1 end
        end
    end
    screen._tclZoneBooks[collection.key] = cached
    return cached.books
end

Counts = function(screen, collection)
    if not screen._tclZone then return collection.known, collection.total end
    VisibleBooks(screen, collection)
    local cached = screen._tclZoneBooks[collection.key]
    return cached.known, cached.total
end

local function CollectionsForView(screen)
    if not screen._tclZone then return Model(screen).collections end
    local result = {}
    for _, collection in ipairs(Model(screen).collections) do
        if IncludeCollection(screen, collection) then table.insert(result, collection) end
    end
    table.sort(result, function(a, b)
        local ak, at = Counts(screen, a)
        local bk, bt = Counts(screen, b)
        local am, bm = at - ak, bt - bk
        if (am == 0) ~= (bm == 0) then return am > 0 end
        if am ~= bm then return am < bm end
        if a.nameKey ~= b.nameKey then return a.nameKey < b.nameKey end
        return a.key < b.key
    end)
    return result
end

local function Search(screen, query)
    local result = {}
    for _, collection in ipairs(CollectionsForView(screen)) do
        if IncludeCollection(screen, collection) then
            local categoryMatch = not IsOtherArchiveSection(collection.category.name)
                and collection.category.nameKey:find(query, 1, true)
            if collection.nameKey:find(query, 1, true) or categoryMatch then
                result[#result + 1] = collection
            end
            for _, book in ipairs(VisibleBooks(screen, collection)) do
                if book.nameKey:find(query, 1, true) or (book.senderKey and book.senderKey:find(query, 1, true)) then
                    result[#result + 1] = book
                end
            end
        end
    end
    return result
end

local function SearchPrompt(screen, text)
    if screen.motifSearchFocus and screen.motifSearchFocus.GetEditBox then
        screen.motifSearchFocus:GetEditBox():SetDefaultText(text)
    end
end

local function ResetLayout(screen)
    local parent = screen.rightContent or (screen.detailBottomLine and screen.detailBottomLine:GetParent())
    if screen.detailBottomLine and parent then
        screen.detailBottomLine:ClearAnchors()
        screen.detailBottomLine:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 0, -285)
        screen.detailBottomLine:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, -285)
    end
    screen.detailSource:SetFont('ZoFontGamepad22')
    screen.detailSource:SetHeight(88)
    screen.detailSource:SetMaxLineCount(5)
    screen.detailAchievement:SetFont('ZoFontGamepad20')
    screen.detailAchievement:SetHeight(58)
    screen.detailAchievement:SetMaxLineCount(3)
end

local function Card(screen)
    ResetLayout(screen)
    for _, name in ipairs({ 'detailControl', 'detailHeading', 'detailAcquisition', 'detailWhereTitle',
        'detailLocation', 'detailSource', 'detailAchievement' }) do screen[name]:SetHidden(false) end
    screen.detailIcon:SetHidden(true)
    if screen.rightText then screen.rightText:SetHidden(true) end
end

local function SelectedBook(screen)
    local data = screen.detailList:GetTargetData()
    return data and data.loreBook or nil
end

local function BookInfo(screen, book)
    local mail = book and book.collection.mailListIndex
    local status = book and (mail and (book.known and 'Collected' or 'Not collected')
        or (book.known and 'Read' or 'Not read'))
    screen.detailAcquisition:SetText(book and ((mail and 'Correspondence' or 'Lore Library') .. ' — '
        .. (book.known and GREEN or RED) .. status .. '|r') or 'Lore Library')
    screen.detailWhereTitle:SetText(book and 'Where to obtain:' or '')
    local source = book and TC.lorebookSources and TC.lorebookSources.Get(book, screen._tclZone)
    screen._tclSelectedSource = source
    screen.detailLocation:SetText(source and source.location or '')
    local description = source and source.description or ''
    if mail and not book.known then
        description = description .. ' Its title is revealed after collection.'
    end
    screen.detailSource:SetText(description)
end

local function CanRead(book)
    if not (book and book.known) then return false end
    if book.collection.mailListIndex then return type(ZO_LoreLibrary_ReadMailFromMailList) == 'function' end
    return type(ZO_LoreLibrary_ReadBook) == 'function'
end

local function Achievement(collection)
    if collection.mailListIndex then return '' end
    if not (GetLoreBookCollectionLinkedAchievement and GetAchievementInfo) then return '' end
    local id = GetLoreBookCollectionLinkedAchievement(collection.categoryIndex, collection.collectionIndex)
    if id and id > 0 then
        local name = GetAchievementInfo(id)
        if name and name ~= '' then return GOLD .. 'Achievement:|r ' .. Text(name) end
    end
    return ''
end

local function ShowNode(screen, data)
    if screen._tclLoading then return end
    local node = data and data.loreNode
    Card(screen)
    screen._tclRendering = true
    screen.detailList:Clear()
    screen.detailAchievement:SetText('')
    screen._tclSelectedSource = nil
    local model = Model(screen)
    screen.detailAcquisition:SetText('Lore Library')
    if not node then
        screen.detailHeading:SetText(GOLD .. 'Lorebooks|r')
        screen.detailWhereTitle:SetText('')
        screen.detailLocation:SetText('')
        local message = 'No Lore Library collections are available yet.'
        if screen._tclLevel == 'search' then
            message = 'No matches in this view. Press L3 to switch views.'
        elseif screen._tclZone then
            local name = TC.lorebookZoneNames[screen._tclZone] or screen._tclZone
            message = 'No books with a verified source in ' .. name .. ' match this view.'
            if not screen._tclShowAll then message = message .. ' Press L3 to include completed families.' end
        elseif #model.collections > 0 and not screen._tclShowAll then
            message = 'All included collections are complete. Press L3 to show all.'
        end
        screen.detailSource:SetText(message)
    else
        local collection = node.kind == 'book' and node.collection or node
        local known, total = Counts(screen, collection)
        screen.detailHeading:SetText(string.format('%s%s (%d/%d)|r', GOLD, collection.name, known, total))
        if collection.mailListIndex then screen.detailAcquisition:SetText('Correspondence') end
        for _, book in ipairs(VisibleBooks(screen, collection)) do
            local label = collection.mailListIndex and (book.known and 'Collected' or 'Not collected')
                or (book.known and 'Read' or 'Not read')
            local status = (book.known and GREEN or RED) .. label .. '|r'
            local entry = ZO_GamepadEntryData:New(book.name .. '  —  ' .. status)
            entry.loreBook, entry.isKnown = book, book.known
            screen.detailList:AddEntry(TEMPLATE, entry)
        end
        screen.detailAchievement:SetText(Achievement(collection))
        screen._tclCurrentCollection = collection.key
    end
    screen.detailList:Commit()
    if node then
        local wanted = node.kind == 'book' and node.key or screen._tclSelectedBookKey
        local index = 1
        local collection = node.kind == 'book' and node.collection or node
        local books = VisibleBooks(screen, collection)
        for i, book in ipairs(books) do if book.key == wanted then index = i; break end end
        if #books > 0 then screen.detailList:SetSelectedIndex(index) end
        BookInfo(screen, SelectedBook(screen))
        if #books == 0 then screen.detailSource:SetText(collection.description) end
    end
    screen._tclRendering = false
end

local function RenderMiddle(screen, index, selectedKey)
    local model, items = Model(screen)
    if screen._tclLevel == 'search' then
        items = Search(screen, screen._tclQuery or '')
    end
    -- Every retained native collection shares one middle list. Category IDs
    -- remain metadata for ownership/read APIs, not another navigation level.
    if not items then
        items = {}
        for _, collection in ipairs(CollectionsForView(screen)) do
            if IncludeCollection(screen, collection) then items[#items + 1] = collection end
        end
    end
    screen._tclItems = items
    screen._tclRendering = true
    screen.styleList:Clear()
    for i, node in ipairs(items) do
        local title = node.name
        if node.kind ~= 'book' then
            local known, total = Counts(screen, node)
            title = string.format('%s (%d/%d)', title, known, total)
        end
        local entry = ZO_GamepadEntryData:New(title)
        entry.loreNode = node
        screen.styleList:AddEntry(TEMPLATE, entry)
        if node.key == selectedKey then index = i end
    end
    screen.styleList:Commit()
    if #items > 0 then screen.styleList:SetSelectedIndex(math.max(1, math.min(index or 1, #items))) end
    screen._tclRendering = false
    if screen.activeModuleId == ID then ShowNode(screen, screen.styleList:GetTargetData()) end
    screen:RefreshKeybinds()
end

local function CancelViewWork(screen)
    screen._tclViewSerial = (screen._tclViewSerial or 0) + 1
    screen._tclLoading = nil
end

local function IsVisible(screen)
    if screen._tclHidden then return false end
    if SCENE_MANAGER and SCENE_MANAGER.IsShowing then
        return SCENE_MANAGER:IsShowing('tamrielCollectionsGamepad')
    end
    return true
end

local function WantsLorebooks(screen)
    if screen.activeModuleId == ID then return true end
    local selected = screen.mode == 'categories' and screen.categoryList and screen.categoryList:GetTargetData()
    return selected and selected.categoryKey == ID
end

local function FillMiddle(screen, index, selectedKey, onReady)
    CancelViewWork(screen)
    local model, zone = Model(screen), screen._tclZone
    screen._tclBooks = screen._tclBooks or {}
    -- Reuse completed collections when returning to a zone. Keep unfinished
    -- collections private to the current job so cancellation cannot expose them.
    screen._tclZoneViews = screen._tclZoneViews or {}
    local zoneBooks
    if zone then
        zoneBooks = screen._tclZoneViews[zone] or {}
        screen._tclZoneViews[zone] = zoneBooks
    end
    screen._tclZoneBooks = zoneBooks
    local prepare = false
    if zone or screen._tclLevel == 'search' then
        for _, collection in ipairs(model.collections) do
            if not screen._tclBooks[collection.key] or (zone and not screen._tclZoneBooks[collection.key]) then
                prepare = true
                break
            end
        end
    end
    if not prepare or not zo_callLater then
        RenderMiddle(screen, index, selectedKey)
        if onReady then onReady() end
        return
    end

    -- A zone/search can touch thousands of books. Never build it in the
    -- dialog callback or a learned-book event: share the work across frames.
    local serial = screen._tclViewSerial
    screen._tclLoading = true
    screen._tclRendering = true
    screen.styleList:Clear()
    screen.detailList:Clear()
    screen.styleList:Commit()
    screen.detailList:Commit()
    screen._tclRendering = false
    screen._tclSelectedSource = nil
    if screen.activeModuleId == ID then
        Card(screen)
        screen.detailHeading:SetText(GOLD .. 'Lorebooks|r')
        screen.detailAcquisition:SetText('Lore Library')
        screen.detailWhereTitle:SetText('')
        screen.detailLocation:SetText('')
        screen.detailSource:SetText('Preparing book list…')
        screen.detailAchievement:SetText('')
    end
    screen:RefreshKeybinds()
    local ci, bi, books, filtered = 1, 1
    local sources = TC.lorebookSources
    local function AddToZone(book)
        if sources and sources.InZone(book, zone) then
            filtered.books[#filtered.books + 1] = book
            filtered.total = filtered.total + 1
            if book.known then filtered.known = filtered.known + 1 end
        end
    end
    local function Step()
        if serial ~= screen._tclViewSerial then return end
        if screen._tclHidden or model ~= screen._tclCatalogue or zone ~= screen._tclZone
            or not WantsLorebooks(screen) then
            CancelViewWork(screen)
            return
        end
        local started = GetGameTimeMilliseconds and GetGameTimeMilliseconds()
        -- Use the available time instead of sleeping after just 32 entries.
        -- The hard cap also bounds work if a millisecond clock is unavailable.
        local maximum = started and 256 or 32
        for unit = 1, maximum do
            local collection = model.collections[ci]
            if not collection then
                screen._tclLoading = nil
                RenderMiddle(screen, index, selectedKey)
                if onReady then onReady() end
                return
            end
            local cached = screen._tclBooks[collection.key]
            if not cached then
                books = books or {}
                if zone then filtered = filtered or { books = {}, known = 0, total = 0 } end
                if bi <= collection.total then
                    local book = ReadBook(collection, bi)
                    if book then
                        books[#books + 1] = book
                        if zone then AddToZone(book) end
                    end
                    bi = bi + 1
                else
                    SortBooks(books)
                    screen._tclBooks[collection.key] = books
                    if zone then
                        SortBooks(filtered.books)
                        zoneBooks[collection.key] = filtered
                    end
                    books, bi = nil, 1
                    filtered, ci = nil, ci + 1
                end
            elseif zone and not zoneBooks[collection.key] then
                filtered = filtered or { books = {}, known = 0, total = 0 }
                local book = cached[bi]
                if book then
                    AddToZone(book)
                    bi = bi + 1
                else
                    zoneBooks[collection.key] = filtered
                    filtered, bi, ci = nil, 1, ci + 1
                end
            else
                bi, ci = 1, ci + 1
            end
            if started and GetGameTimeMilliseconds() - started >= 2 then break end
        end
        zo_callLater(Step, 0)
    end
    zo_callLater(Step, 0)
end

local function ApplyZone(screen, zone)
    if screen.activeModuleId ~= ID then return end
    local data = screen.styleList:GetTargetData()
    local selected = data and data.loreNode and data.loreNode.key
    screen._tclZone, screen._tclZoneBooks = zone, nil
    FillMiddle(screen, 1, selected)
    screen.mode = 'styles'
    screen:SetCurrentList(screen.styleList)
    screen:RefreshKeybinds()
end

local function OpenZoneChooser(screen)
    if screen.activeModuleId ~= ID or not TC.lorebookSources then return end
    if not (ZO_Dialogs_RegisterCustomDialog and ZO_Dialogs_ShowGamepadDialog and GAMEPAD_DIALOGS) then return end
    local dialogName = 'TCL_LOREBOOK_LOCATION'
    if not TC._tclZoneDialogRegistered then
        TC._tclZoneDialogRegistered = true
        ZO_Dialogs_RegisterCustomDialog(dialogName, {
            gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
            title = { text = 'Location' },
            parametricList = {},
            setup = function(dialog, data)
                local rows, selected = {}, 1
                for index, zone in ipairs(data.zones) do
                    local entry = ZO_GamepadEntryData:New(zone.name)
                    entry.zoneKey = zone.key
                    entry.setup = ZO_SharedGamepadEntry_OnSetup
                    rows[#rows + 1] = { template = 'ZO_GamepadMenuEntryTemplate', entryData = entry }
                    if zone.key == data.screen._tclZone then selected = index end
                end
                dialog.info.parametricList = rows
                dialog:setupFunc()
                dialog.entryList:SetSelectedIndex(selected)
            end,
            buttons = {
                { keybind = 'DIALOG_PRIMARY', text = 'Select', callback = function(dialog)
                    local selected = dialog.entryList:GetTargetData()
                    if selected then ApplyZone(dialog.data.screen, selected.zoneKey) end
                end },
                { keybind = 'DIALOG_NEGATIVE', text = 'Cancel' },
            },
        })
    end
    ZO_Dialogs_ShowGamepadDialog(dialogName, { screen = screen, zones = TC.lorebookSources.GetZones() })
end

local function ToggleFilter(screen)
    if screen.activeModuleId ~= ID or screen.mode ~= 'styles' then return end
    local data = screen.styleList:GetTargetData()
    local key = data and data.loreNode and data.loreNode.key
    screen._tclShowAll = not screen._tclShowAll
    FillMiddle(screen, screen.styleList:GetSelectedIndex(), key)
end

local function SaveBookmark(screen)
    local data = screen.styleList:GetTargetData()
    local book = SelectedBook(screen)
    screen._tclBookmark = { middleKey = data and data.loreNode and data.loreNode.key,
        middleIndex = screen.styleList:GetSelectedIndex(), bookKey = book and book.key,
        bookIndex = screen.detailList:GetSelectedIndex(), mode = screen.mode }
end

local function RestoreBookmark(screen)
    local bookmark = screen._tclBookmark
    screen._tclBookmark = nil
    screen.resumeMotifsAfterMap = false
    if bookmark then
        screen._tclSelectedBookKey = bookmark.bookKey
        FillMiddle(screen, bookmark.middleIndex, bookmark.middleKey, function()
            local data = screen.styleList:GetTargetData()
            local node = data and data.loreNode
            local collection = node and (node.kind == 'book' and node.collection or node)
            local books = collection and VisibleBooks(screen, collection) or {}
            local index = bookmark.bookIndex or 1
            for i, book in ipairs(books) do if book.key == bookmark.bookKey then index = i; break end end
            if #books > 0 then screen.detailList:SetSelectedIndex(math.max(1, math.min(index, #books))) end
            screen.mode = bookmark.mode or 'details'
            screen:SetCurrentList(screen.mode == 'styles' and screen.styleList or screen.detailList)
            BookInfo(screen, SelectedBook(screen))
            screen:RefreshKeybinds()
        end)
    else
        screen.mode = 'details'
        screen:SetCurrentList(screen.detailList)
        BookInfo(screen, SelectedBook(screen))
        screen:RefreshKeybinds()
    end
end

local function InstallReaderRoute(screen)
    local reader = LORE_READER
    if not (reader and type(reader.GetCustomSceneInfo) == 'function') then return end
    reader._tclArchiveScreen = screen
    if reader._tclRouteInstalled then return end
    reader._tclRouteInstalled = true
    local original = reader.GetCustomSceneInfo
    reader.GetCustomSceneInfo = function(self, sceneName)
        local owner = self._tclArchiveScreen
        if sceneName == 'tamrielCollectionsGamepad' and owner and owner.activeModuleId == ID
            and owner._tclResumeAfterRead then
            -- Use ESO's journal reader: it pushes its scene and its native
            -- Close button pops back to this exact Archive screen.
            return original(self, 'bookSetGamepad')
        end
        return original(self, sceneName)
    end
end

local function ClearSearch(screen)
    screen._tclChangingSearch = true
    if screen.motifSearchFocus and screen.motifSearchFocus.GetEditBox then screen.motifSearchFocus:GetEditBox():SetText('') end
    screen._tclChangingSearch = false
    screen._tclQuery = nil
end

local function OnSearch(screen, value)
    if screen._tclChangingSearch then return end
    local query = Key(value)
    if query == '' then
        if screen._tclLevel == 'search' then
            screen._tclLevel = screen._tclReturnLevel or 'collections'
            FillMiddle(screen, screen._tclReturnIndex, screen._tclReturnKey)
        end
        screen._tclQuery = nil
        return
    end
    if screen._tclLevel ~= 'search' then
        screen._tclReturnLevel, screen._tclReturnIndex = screen._tclLevel, screen.styleList:GetSelectedIndex()
        local data = screen.styleList:GetTargetData()
        screen._tclReturnKey = data and data.loreNode and data.loreNode.key
    end
    screen._tclLevel, screen._tclQuery = 'search', query
    FillMiddle(screen)
end

local function Select(screen)
    local data = screen.styleList:GetTargetData()
    local node = data and data.loreNode
    if not node then return end
    screen.mode = 'details'
    screen:SetCurrentList(screen.detailList)
    BookInfo(screen, SelectedBook(screen))
    screen:RefreshKeybinds()
end

local function Back(screen)
    local wasLoading = screen._tclLoading
    CancelViewWork(screen)
    screen._tclResumeAfterRead = nil
    screen._tclBookmark = nil
    if screen.mode == 'details' then
        screen.mode = 'styles'
        screen:SetCurrentList(screen.styleList)
        if wasLoading then FillMiddle(screen) end
    elseif screen._tclLevel == 'search' then
        ClearSearch(screen)
        screen._tclLevel = screen._tclReturnLevel or 'collections'
        FillMiddle(screen, screen._tclReturnIndex, screen._tclReturnKey)
    else screen:ShowCategories() end
    screen:RefreshKeybinds()
end

local function CancelMapReturnForTravel()
    local screen = TC.questScreen
    if not screen or screen.activeModuleId ~= ID or not (screen._tclResumeAfterMap
        or screen.returnToMotifsAfterMap or screen.resumeMotifsAfterMap) then return end
    screen._tclResumeAfterMap, screen._tclBookmark = nil, nil
    screen.returnToMotifsAfterMap, screen.resumeMotifsAfterMap = false, false
    if TC.lorebookSources then TC.lorebookSources.CancelMap() end
    -- A native map-close callback may already have queued its return. Clearing
    -- both flags cancels that callback; a confirmed journey owns navigation.
    if SCENE_MANAGER and SCENE_MANAGER.IsShowing and SCENE_MANAGER:IsShowing('tamrielCollectionsGamepad')
        and SCENE_MANAGER.ShowBaseScene then SCENE_MANAGER:ShowBaseScene() end
end

local function Install(screen)
    if screen._tclHooksInstalled then return end
    screen._tclHooksInstalled = true
    if not TC._tclTravelHookInstalled and ZO_PreHook and type(FastTravelToNode) == 'function' then
        TC._tclTravelHookInstalled = true
        ZO_PreHook('FastTravelToNode', function() CancelMapReturnForTravel() end)
    end
    if TC.lorebookSources and TC.lorebookSources.WarmMaps then
        TC.lorebookSources.WarmMaps(function()
            -- Map ancestry may add zone matches. Cancel the old job before
            -- replacing its caches, including while previewing the family.
            if screen._tclZone then CancelViewWork(screen) end
            screen._tclZoneBooks, screen._tclZoneViews = nil, nil
            if IsVisible(screen) and WantsLorebooks(screen) then
                if screen._tclZone then
                    local data = screen.styleList:GetTargetData()
                    FillMiddle(screen, screen.styleList:GetSelectedIndex(), data and data.loreNode and data.loreNode.key)
                elseif screen.activeModuleId == ID then
                    BookInfo(screen, SelectedBook(screen)); screen:RefreshKeybinds()
                end
            end
        end)
    end
    local originalShow, originalSearch = screen.ShowStyle, screen.OnMotifSearchTextChanged
    screen.ShowStyle = function(self, data)
        if self.activeModuleId == ID then
            if not self._tclRendering then ShowNode(self, data) end
        else return originalShow(self, data) end
    end
    screen.OnMotifSearchTextChanged = function(self, text)
        if self.activeModuleId == ID then return OnSearch(self, text) end
        if originalSearch then return originalSearch(self, text) end
    end
    local originalMotifs = screen.ShowMotifCategory
    screen.ShowMotifCategory = function(self, data)
        SearchPrompt(self, 'Search Motifs')
        return originalMotifs(self, data)
    end
    local originalShowing = screen.OnShowing
    screen.OnShowing = function(self, ...)
        self._tclHidden = nil
        if (self._tclResumeAfterRead or self._tclResumeAfterMap) and self.activeModuleId == ID then
            if self._tclResumeAfterMap and TC.lorebookSources then TC.lorebookSources.CancelMap() end
            self._tclResumeAfterRead = nil
            self._tclResumeAfterMap = nil
            ZO_Gamepad_ParametricList_Screen.OnShowing(self)
            RestoreBookmark(self)
        elseif originalShowing then return originalShowing(self, ...) end
    end
    local originalHiding = screen.OnHiding
    screen.OnHiding = function(self, ...)
        self._tclHidden = true
        CancelViewWork(self)
        if originalHiding then return originalHiding(self, ...) end
    end
    -- ESO registers these additively; retain the other modules' callbacks.
    screen.detailList:SetOnTargetDataChangedCallback(function(_, data)
        if screen.activeModuleId == ID and not screen._tclRendering then
            local book = data and data.loreBook
            screen._tclSelectedBookKey = book and book.key
            BookInfo(screen, book)
            screen:RefreshKeybinds()
        end
    end)
    for _, descriptor in ipairs(screen.keybindStripDescriptor or {}) do
        local visible, callback, name = descriptor.visible, descriptor.callback, descriptor.name
        if descriptor.keybind == 'UI_SHORTCUT_PRIMARY' then
            descriptor.name = function()
                if screen.activeModuleId == ID and screen.mode == 'details' then return 'Read' end
                return type(name) == 'function' and name() or name
            end
            descriptor.visible = function()
                if screen.activeModuleId == ID then
                    if screen.mode == 'styles' then return screen.styleList:GetTargetData() ~= nil end
                    local book = screen.mode == 'details' and SelectedBook(screen)
                    return CanRead(book)
                end
                return visible and visible() or false
            end
            descriptor.callback = function()
                if screen.activeModuleId ~= ID then if callback then return callback() end; return end
                if screen.mode == 'styles' then return Select(screen) end
                local book = SelectedBook(screen)
                if CanRead(book) then
                    local collection = book.collection
                    SaveBookmark(screen)
                    screen._tclResumeAfterRead = true
                    InstallReaderRoute(screen)
                    if collection.mailListIndex then
                        return ZO_LoreLibrary_ReadMailFromMailList(collection.mailListIndex, book.bookIndex)
                    end
                    return ZO_LoreLibrary_ReadBook(collection.categoryIndex, collection.collectionIndex, book.bookIndex)
                end
            end
        elseif descriptor.keybind == 'UI_SHORTCUT_SECONDARY' then
            descriptor.visible = function()
                if screen.activeModuleId == ID then
                    local sources = TC.lorebookSources
                    return SelectedBook(screen) ~= nil and (screen.mode == 'styles' or screen.mode == 'details') and sources
                        and sources.CanMap(screen._tclSelectedSource) or false
                end
                return visible and visible() or false
            end
            descriptor.callback = function()
                if screen.activeModuleId ~= ID then if callback then return callback() end; return end
                local sources = TC.lorebookSources
                if SelectedBook(screen) and sources and sources.CanMap(screen._tclSelectedSource) then
                    SaveBookmark(screen)
                    screen._tclResumeAfterMap = true
                    screen.returnToMotifsAfterMap = true
                    if not sources.ShowMap(screen._tclSelectedSource) then
                        screen._tclResumeAfterMap, screen.returnToMotifsAfterMap, screen._tclBookmark = nil, false, nil
                    end
                end
            end
        elseif descriptor.keybind == 'UI_SHORTCUT_NEGATIVE' then
            descriptor.callback = function()
                if screen.activeModuleId == ID then return Back(screen) end
                if callback then return callback() end
            end
        end
    end
    local group = screen.keybindStripDescriptor
    if group then
        local strip = KEYBIND_STRIP
        local registered = strip and strip.HasKeybindButtonGroup and strip:HasKeybindButtonGroup(group)
        -- UpdateKeybindButtonGroup does not register newly inserted buttons.
        -- Re-register an already-visible group once when installing this hook.
        if registered then strip:RemoveKeybindButtonGroup(group) end
        table.insert(group, {
            name = function()
                local action = screen._tclShowAll and 'Hide completed' or 'Show all'
                if screen.activeModuleId ~= ID then return action end
                local model = Model(screen)
                return string.format('%s  (%d/%d collected)', action, model.known, model.total)
            end,
            keybind = 'UI_SHORTCUT_LEFT_STICK',
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            visible = function() return screen.activeModuleId == ID and screen.mode == 'styles' end,
            callback = function() ToggleFilter(screen) end,
        })
        table.insert(group, {
            name = function()
                local zone = screen._tclZone
                return 'Location: ' .. (zone and TC.lorebookZoneNames and TC.lorebookZoneNames[zone] or 'All')
            end,
            keybind = 'UI_SHORTCUT_RIGHT_STICK',
            visible = function() return screen.activeModuleId == ID and (screen.mode == 'styles' or screen.mode == 'details') end,
            callback = function() OpenZoneChooser(screen) end,
        })
        if registered then strip:AddKeybindButtonGroup(group) end
    end
end

local function Preview(screen)
    Install(screen)
    ResetLayout(screen)
    -- Ownership events invalidate these caches. Merely focusing/reopening the
    -- family must not throw away a prepared multi-thousand-book zone index.
    screen._tclLevel, screen._tclSelectedBookKey = 'collections', nil
    screen:SetMotifContentVisible(true)
    FillMiddle(screen)
    screen.middle:SetHidden(false)
    screen.right:SetHidden(false)
    for _, name in ipairs({ 'detailControl', 'detailHeading', 'detailAcquisition', 'detailWhereTitle',
        'detailLocation', 'detailSource', 'detailAchievement' }) do screen[name]:SetHidden(true) end
    screen.detailIcon:SetTexture(ICON)
    screen.detailIcon:SetHidden(false)
    SearchPrompt(screen, 'Search Lorebooks')
end

TC:RegisterArchiveModule(ID, {
    displayName = 'Lorebooks', addonName = 'Tamriel Collections - Archive Lorebooks',
    assetRoot = 'TamrielCollectionsLorebooks', screenControl = 'TCLQuestJournalTL',
    version = 1000, supportsSearch = true, onCategoryFocus = Preview,
    open = function(screen)
        Install(screen)
        screen.activeModuleId, screen.mode = ID, 'styles'
        screen._tclLevel = screen._tclLevel or 'collections'
        screen:SetMotifContentVisible(true)
        ClearSearch(screen)
        if screen._tclLevel == 'search' then screen._tclLevel = 'collections' end
        screen:SetCurrentList(screen.styleList)
        screen.middle:SetHidden(false)
        screen.right:SetHidden(false)
        SearchPrompt(screen, 'Search Lorebooks')
        FillMiddle(screen)
    end,
    activateSearch = function(screen) screen:ActivateMotifSearch() end,
})

local function Invalidate()
    local screen = TC.questScreen
    if not screen then return end
    CancelViewWork(screen)
    screen._tclCatalogue, screen._tclBooks, screen._tclZoneBooks, screen._tclZoneViews = nil, nil, nil, nil
    -- Learning from a bookshelf can happen while this screen is closed.
    -- Mark it dirty only; the next open builds the current state on demand.
    if not IsVisible(screen) then return end
    if screen._tclRefreshQueued then return end
    screen._tclRefreshQueued = true
    local data = screen.styleList and screen.styleList:GetTargetData()
    local key = data and data.loreNode and data.loreNode.key
    local function Refresh()
        screen._tclRefreshQueued = nil
        if not IsVisible(screen) then return end
        if screen.activeModuleId == ID then
            FillMiddle(screen, screen.styleList:GetSelectedIndex(), key)
        elseif screen.mode == 'categories' then
            local selected = screen.categoryList:GetTargetData()
            if selected and selected.categoryKey == ID then Preview(screen) end
        end
    end
    if zo_callLater then zo_callLater(Refresh, 10) else Refresh() end
end

if EVENT_MANAGER then
    if EVENT_PREPARE_FOR_JUMP then
        EVENT_MANAGER:RegisterForEvent('TCLLorebookTravel', EVENT_PREPARE_FOR_JUMP, CancelMapReturnForTravel)
    end
    for _, name in ipairs({ 'EVENT_LORE_LIBRARY_INITIALIZED', 'EVENT_LORE_BOOK_LEARNED',
        'EVENT_LORE_BOOK_COLLECTION_LEARNED', 'EVENT_LORE_COLLECTION_COMPLETED',
        'EVENT_MAIL_LISTS_INITIALIZED', 'EVENT_MAIL_LISTS_UPDATED' }) do
        local event = _G[name]
        if event then EVENT_MANAGER:RegisterForEvent('TCLLoreLibrary', event, Invalidate) end
    end
end
