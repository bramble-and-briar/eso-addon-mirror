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
    version = 1100, supportsSearch = true, onCategoryFocus = Preview,
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

-- Shared layout: included in every standalone Archive module; initialized once.
do
local TC = TamrielCollections
if not TC.archiveLayout or TC.archiveLayout.version < 1101 then
-- Shared Archives layout derived from the approved Motifs v1.1.1: a separate scene-owned background plane keeps the
-- native masked menus, search controls, emblem and panel rails unobscured.
-- Geometry is measured
-- against GuiRoot because ESO narrows the native scene owner to quadrant 1.
local Pilot = { version = 1101, modules = {} }
TC.archiveLayout = Pilot
local function Current(screen)
    local id
    if screen.mode == 'categories' then
        local data = screen.categoryList and screen.categoryList:GetTargetData()
        id = data and data.categoryKey
    elseif screen.mode == 'styles' or screen.mode == 'details' or screen.mode == 'starter' then
        id = screen.activeModuleId
    end
    return id and Pilot.modules[id]
end
local function IsArchive(screen) return Current(screen) ~= nil end
local function Capture(control)
    local saved = { anchors = {}, width = control:GetWidth(), height = control:GetHeight(), hidden = control:IsHidden(), parent = control:GetParent() }
    for index = 0, control:GetNumAnchors() - 1 do
        local valid, point, relative, relativePoint, x, y, constrains = control:GetAnchor(index)
        if valid then saved.anchors[#saved.anchors + 1] = { point, relative, relativePoint, x, y, constrains } end
    end
    if control.GetAutoRectClipChildren then saved.clip = control:GetAutoRectClipChildren() end
    if control.GetDrawLayer then saved.layer = control:GetDrawLayer() end
    if control.GetDrawLevel then saved.level = control:GetDrawLevel() end
    if control.GetFont then saved.font = control:GetFont() end
    return saved
end
local function RestoreControl(control, saved)
    if saved.parent and control:GetParent() ~= saved.parent then control:SetParent(saved.parent) end
    control:ClearAnchors()
    control:SetDimensions(saved.width, saved.height)
    for _, anchor in ipairs(saved.anchors) do
        control:SetAnchor(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5], anchor[6])
    end
    control:SetHidden(saved.hidden)
    if saved.clip ~= nil and control.SetAutoRectClipChildren then control:SetAutoRectClipChildren(saved.clip) end
    if saved.layer ~= nil then control:SetDrawLayer(saved.layer) end
    if saved.level ~= nil then control:SetDrawLevel(saved.level) end
    if saved.font then control:SetFont(saved.font) end
end
local moved = { 'collectionsHeaderLine', 'collectionsLogoBottomLine', 'collectionsMenuBottomLine',
    'collectionsHeaderLogo', 'detailTopLine', 'detailBottomLine', 'motifSearchLine', 'motifSearchBackdrop',
    'motifSearchControl', 'styleListContainer', 'detailControl', 'detailHeading', 'detailAcquisition',
    'detailWhereTitle', 'detailLocation', 'detailSource', 'detailAchievement', 'detailIcon',
    'moduleUnavailableTitle', 'moduleUnavailableBody' }
local hiddenLines = { 'collectionsHeaderLine', 'collectionsLogoBottomLine', 'collectionsMenuBottomLine',
    'detailTopLine', 'detailBottomLine', 'motifSearchLine', 'motifSearchBackdrop' }
local function Bounds(screen)
    local owner, root = screen.control, GuiRoot or screen.control
    if not owner or not root or not root.GetLeft or not screen.middle or not screen.right then return end
    local left, top, width, height = root:GetLeft(), root:GetTop(), root:GetWidth(), root:GetHeight()
    if not (left and top and width and height and width > 600 and height > 400) then return end
    local middle, right = screen.middle:GetLeft() - left, screen.right:GetLeft() - left
    if not (middle > 100 and right > middle + 100 and right < width - 100) then return end
    local alley = ZO_GAMEPAD_ALLEY_WIDTH or 10
    local panelLeft = math.max(0, middle - screen.right:GetWidth() - alley)
    local panelRight = math.min(width, screen.right.GetRight and screen.right:GetRight() - left or width)
    local middleEnd = math.min(right - alley, screen.middle.GetRight and screen.middle:GetRight() - left or right - alley)
    local texture = ZO_KeybindStripGamepadBackgroundTexture
    local keybindHeight = texture and texture.GetHeight and texture:GetHeight() or ZO_GAMEPAD_KEYBIND_STRIP_BACKGROUND_HEIGHT or 128
    local footer = texture and texture.GetTop and texture:GetTop() - top or height - keybindHeight
    if not footer or footer <= height / 2 or footer > height then footer = height - keybindHeight end
    footer = footer - 16
    -- All columns share a title baseline and two narrow gold rules. Keep the
    -- left menu and chapter-list divider aligned, leaving the middle list open.
    local titleTop = math.max(24, ZO_GAMEPAD_SAFE_ZONE_INSET_Y or 54) + 8
    local first, second = titleTop + 56, titleTop + 216
    local listTop, lower = second + 18, footer - 234
    if lower - listTop < 314 then return end
    return { root = root, owner = owner, width = width, height = height,
        left = panelLeft, leftEnd = middle - alley, middle = middle, middleEnd = middleEnd,
        right = right, edge = panelRight, titleTop = titleTop, first = first,
        second = second, listTop = listTop, lower = lower, footer = footer }
end
local function Place(control, b, left, right, top, height)
    if not control then return end
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, b.root, TOPLEFT, left, top)
    control:SetAnchor(TOPRIGHT, b.root, TOPLEFT, right, top)
    control:SetHeight(height)
end
local function Foreground(control)
    if not control then return end
    control:SetDrawLayer(DL_CONTROLS)
    control:SetDrawLevel(90)
end
local function NewControl(state, name, kind, level)
    local isBackground = name == 'Backdrop' or name == 'FooterFill' or name == 'HeaderShade'
    local parent = isBackground and state.backgroundRoot or state.bounds.owner
    local control = WINDOW_MANAGER:CreateControl('TCArchiveLayout' .. name, parent, kind)
    if DT_LOW then control:SetDrawTier(DT_LOW) end
    control:SetDrawLayer(isBackground and DL_BACKGROUND or DL_CONTROLS)
    control:SetDrawLevel(isBackground and 0 or level)
    control:SetHidden(true)
    return control
end
local function MakeControls(state, screen)
    if state.controls then return end
    local c = {}; state.controls = c
    -- Scroll masks and top-level windows compose their descendants as a group.
    -- Raising a label cannot place it above an opaque sibling in another
    -- composed layer. Keep the paint in a distinct, lower background window.
    local background = WINDOW_MANAGER:CreateTopLevelWindow('TCArchiveBackgroundWindow')
    background:SetHidden(true)
    background:SetMouseEnabled(false)
    background:SetDrawTier(DT_LOW)
    background:SetDrawLayer(DL_BACKGROUND)
    background:SetDrawLevel(0)
    state.backgroundRoot = background
    state.backgroundFragment = ZO_SimpleSceneFragment:New(background)
    state.backgroundFragment:SetConditional(function() return state.active == true and IsArchive(screen) end)
    screen.scene:AddFragment(state.backgroundFragment)
    -- A near-solid tint retains a faint glimpse of the world beneath the
    -- native gamepad panels, while keeping collection text readable.
    c.Backdrop = NewControl(state, 'Backdrop', CT_TEXTURE, 10)
    c.Backdrop:SetColor(32 / 255, 37 / 255, 38 / 255, 0.72)
    c.FooterFill = NewControl(state, 'FooterFill', CT_TEXTURE, 11)
    c.FooterFill:SetColor(36 / 255, 40 / 255, 40 / 255, 1)
    c.FooterRule = NewControl(state, 'FooterRule', CT_TEXTURE, 20)
    c.FooterRule:SetColor(145 / 255, 137 / 255, 112 / 255, 1)
    c.HeaderShade = NewControl(state, 'HeaderShade', CT_TEXTURE, 15)
    c.HeaderShade:SetColor(0.015, 0.02, 0.02, 0.24)
    for _, name in ipairs({ 'TitleRule', 'HeaderRule', 'MenuRule', 'SourceRule' }) do
        local line = NewControl(state, name, CT_TEXTURE, 20)
        -- The native divider fades toward its ends. A solid two-unit rule
        -- spans the exact panel bounds without fading or stretching an image.
        line:SetColor(224 / 255, 191 / 255, 124 / 255, 1)
        c[name] = line
    end
    for _, name in ipairs({ 'ArchivesTitle', 'ModuleTitle', 'DetailsTitle', 'StarterHint' }) do
        local label = NewControl(state, name, CT_LABEL, 90)
        label:SetFont(name == 'StarterHint' and 'ZoFontGamepad25' or 'ZoFontGamepadBold34')
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        if name == 'StarterHint' then label:SetColor(0.72, 0.72, 0.68, 1)
        else label:SetColor(244 / 255, 225 / 255, 182 / 255, 1) end
        c[name] = label
    end
    c.ModuleEmblem = NewControl(state, 'ModuleEmblem', CT_TEXTURE, 90)
    c.ModuleEmblem:SetColor(244 / 255, 225 / 255, 182 / 255, 0.45)
    c.ContextHint = NewControl(state, 'ContextHint', CT_LABEL, 90)
    c.ContextHint:SetFont('ZoFontGamepad25')
    c.ContextHint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c.ContextHint:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    c.ContextHint:SetColor(0.72, 0.72, 0.68, 1)
    c.ContextHint:SetText('Collection overview')
    c.ArchivesTitle:SetText('TAMRIEL ARCHIVES')
    c.ModuleTitle:SetText('MOTIFS')
    c.DetailsTitle:SetText('DETAILS')
    c.StarterHint:SetText('Choose a motif to view its chapters,\ncollection progress and sources.')
end
local function HideNative(screen)
    for _, name in ipairs(hiddenLines) do if screen[name] then screen[name]:SetHidden(true) end end
end
function Pilot.Restore(screen)
    local state = screen._tcArchiveLayout
    if not state then return end
    state.generation = (state.generation or 0) + 1
    state.pending, state.attempts = nil, 0
    local wasActive = state.active
    state.active = false
    if state.backgroundFragment then state.backgroundFragment:Refresh() end
    if not wasActive then return end
    for list, offset in pairs(state.listOffsets or {}) do
        list:SetFixedCenterOffset(offset)
    end
    state.listOffsets = nil
    for control, saved in pairs(state.saved) do RestoreControl(control, saved) end
    for _, control in pairs(state.controls or {}) do control:SetHidden(true) end
    if state.ownerLayer ~= nil then screen.control:SetDrawLayer(state.ownerLayer) end
    if ZO_GamepadGenericHeader_Refresh and screen.header then
        ZO_GamepadGenericHeader_Refresh(screen.header, screen.headerData or { titleText = 'TAMRIEL ARCHIVES' })
    end
    state.saved = nil
end
function Pilot.Apply(screen)
    local config = Current(screen)
    if not config or screen._tcArchiveLayoutHidden then return false end
    -- Motifs v1.1.1 owns its approved layout independently. Restore it before
    -- capturing native controls for another module, regardless of load order.
    local motifsState = screen._tcmLayoutPilot
    if motifsState and not motifsState.active and motifsState.saved then
        -- Its list-offset restoration fires keybind callbacks before it has
        -- restored the original parents. The enclosing category change will
        -- apply this layout once that restoration has fully completed.
        return false
    end
    if TC.motifLayoutPreview then TC.motifLayoutPreview.Restore(screen) end
    if screen._tcArchiveLayout and screen._tcArchiveLayout.active
        and screen._tcArchiveLayout.moduleId ~= config.id then Pilot.Restore(screen) end
    local state = screen._tcArchiveLayout
    if not state then state = {}; screen._tcArchiveLayout = state end
    local b = state.active and state.bounds or Bounds(screen)
    if not b then
        if zo_callLater and not state.pending and (state.attempts or 0) < 3 then
            state.pending, state.attempts = true, (state.attempts or 0) + 1
            local generation = state.generation or 0
            zo_callLater(function()
                if (state.generation or 0) ~= generation then return end
                state.pending = nil
                if IsArchive(screen) then Pilot.Apply(screen) end
            end, 33)
        end
        return false
    end
    if not state.active then
        state.bounds, state.saved, state.attempts = b, {}, 0
        state.ownerLayer = screen.control:GetDrawLayer()
        for _, name in ipairs(moved) do
            local control = screen[name]
            if control and control.GetNumAnchors then state.saved[control] = Capture(control) end
        end
        for _, row in ipairs(screen.fixedCategoryRows or {}) do state.saved[row] = Capture(row) end
        MakeControls(state, screen)
        state.active, state.moduleId = true, config.id
    end
    -- Explicitly separate the scene's content plane from its background plane.
    screen.control:SetDrawLayer(DL_CONTROLS)
    local c, starter = state.controls, screen.mode == 'categories' or screen.mode == 'starter'
    c.ModuleTitle:SetText(string.upper(config.name))
    c.StarterHint:SetText(config.hint)
    if not starter then screen:SetMotifContentVisible(true) end
    Place(state.backgroundRoot, b, 0, b.width, 0, b.height)
    Place(c.Backdrop, b, 0, b.width, 0, b.height)
    local keybindTop = b.footer + 16
    Place(c.FooterFill, b, 0, b.width, keybindTop, b.height - keybindTop)
    Place(c.FooterRule, b, 0, b.width, keybindTop, 2)
    Place(c.HeaderShade, b, b.left, b.edge, b.titleTop - 20, b.second - b.titleTop + 20)
    Place(c.TitleRule, b, b.left, b.edge, b.first, 2)
    Place(c.HeaderRule, b, b.left, b.edge, b.second, 2)
    Place(c.MenuRule, b, b.left, b.leftEnd, b.lower, 2)
    Place(c.SourceRule, b, b.right, b.edge, b.lower, 2)
    Place(c.ArchivesTitle, b, b.left + 12, b.leftEnd - 12, b.titleTop, 48)
    Place(c.ModuleTitle, b, b.middle + 12, b.middleEnd - 12, b.titleTop, 48)
    Place(c.DetailsTitle, b, b.right + 12, b.edge - 12, b.titleTop, 48)
    local category = TC.GetArchiveCategory and TC:GetArchiveCategory(config.id)
    local emblem = category and screen:GetCategoryIcon(category)
    if emblem then c.ModuleEmblem:SetTexture(emblem) end
    local emblemSize = math.min(128, b.footer - b.lower - 40)
    Place(c.ModuleEmblem, b, (b.left + b.leftEnd - emblemSize) / 2,
        (b.left + b.leftEnd + emblemSize) / 2, (b.lower + b.footer - emblemSize) / 2, emblemSize)
    Place(c.StarterHint, b, b.right + 28, b.edge - 28, (b.listTop + b.lower) / 2 - 48, 96)
    for _, control in pairs(c) do control:SetHidden(false) end
    c.StarterHint:SetHidden(not starter)
    c.ModuleEmblem:SetHidden(not emblem)
    c.ContextHint:SetHidden(config.search)
    if ZO_GamepadGenericHeader_Refresh and screen.header then
        ZO_GamepadGenericHeader_Refresh(screen.header, { titleText = '' })
    end
    local center = (b.first + b.second) / 2
    Place(c.ContextHint, b, b.middle + 32, b.middleEnd - 32, center - 24, 48)
    if screen.collectionsHeaderLogo then
        -- The native header is a separately animated fragment. Its hidden
        -- state and scroll mask must not hide the fixed Archives artwork.
        screen.collectionsHeaderLogo:SetParent(b.owner)
        screen.collectionsHeaderLogo:SetHidden(false)
        screen.collectionsHeaderLogo:ClearAnchors()
        screen.collectionsHeaderLogo:SetDimensions(100, 100)
        screen.collectionsHeaderLogo:SetAnchor(CENTER, b.root, TOPLEFT, (b.left + b.leftEnd) / 2, center)
        Foreground(screen.collectionsHeaderLogo)
    end
    if screen.detailIcon then
        screen.detailIcon:ClearAnchors()
        screen.detailIcon:SetDimensions(100, 100)
        screen.detailIcon:SetAnchor(CENTER, b.root, TOPLEFT, (b.right + b.edge) / 2, center)
        Foreground(screen.detailIcon)
    end
    if screen.motifSearchControl then
        screen.motifSearchControl:ClearAnchors()
        screen.motifSearchControl:SetAnchor(CENTER, b.root, TOPLEFT, (b.middle + b.middleEnd) / 2, center)
        -- The same native search affordance is visible on the starter. Its
        -- existing Search shortcut opens the selected module and then focuses the edit box.
        screen.motifSearchControl:SetHidden(not config.search)
        Foreground(screen.motifSearchControl)
    end
    Place(screen.styleListContainer, b, b.middle + 8, b.middleEnd - 8, b.listTop, b.footer - b.listTop)
    Place(screen.detailControl, b, b.right + 8, b.edge - 8, b.listTop, b.lower - b.listTop - 12)
    for _, name in ipairs({ 'styleListContainer', 'detailControl' }) do
        if screen[name] and screen[name].SetAutoRectClipChildren then screen[name]:SetAutoRectClipChildren(true) end
    end
    -- Native vertical lists anchor the selected row at their center. Bring
    -- that anchor to the top of the viewport without moving the panel itself.
    state.listOffsets = state.listOffsets or {}
    for _, list in ipairs({ screen.styleList, screen.detailList }) do
        if list.SetFixedCenterOffset and list.GetControl then
            if state.listOffsets[list] == nil then
                state.listOffsets[list] = list.fixedCenterOffset or 0
            end
            list:SetFixedCenterOffset(8 - list:GetControl():GetHeight() / 2)
        end
    end
    Place(screen.detailHeading, b, b.right + 24, b.edge - 24, b.first + 20, 76)
    if screen.detailHeading then screen.detailHeading:SetFont('ZoFontGamepadBold27') end
    Place(screen.detailAcquisition, b, b.right + 24, b.edge - 24, b.first + 110, 30)
    Foreground(screen.detailHeading)
    Foreground(screen.detailAcquisition)
    Place(screen.detailWhereTitle, b, b.right + 24, b.edge - 24, b.lower + 10, 28)
    Place(screen.detailLocation, b, b.right + 24, b.edge - 24, b.lower + 42, 30)
    Place(screen.detailSource, b, b.right + 24, b.edge - 24, b.lower + 76, 88)
    Place(screen.detailAchievement, b, b.right + 24, b.edge - 24, b.lower + 170, 58)
    -- Retain foreground placement without changing native data, row templates,
    -- scrolling, search controls or controller bindings.
    for _, name in ipairs({ 'styleListContainer', 'detailControl', 'detailWhereTitle',
        'detailLocation', 'detailSource', 'detailAchievement',
        'moduleUnavailableTitle', 'moduleUnavailableBody' }) do Foreground(screen[name]) end
    local rows = screen.fixedCategoryRows or {}
    local spacing = #rows > 1 and math.min(80, (b.lower - b.listTop - 90) / (#rows - 1)) or 0
    for index, row in ipairs(rows) do
        -- Keep only the visuals outside the animated header. The invisible
        -- native category list retains all controller input and selection.
        row:SetParent(b.owner)
        row:SetHidden(false)
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, b.root, TOPLEFT, b.left + 44, b.listTop + 14 + (index - 1) * spacing)
        Foreground(row)
    end
    if starter then
        -- A single module heading above the search field identifies this page;
        -- preserve the native press-X prompt without repeating the heading.
        if screen.moduleUnavailableTitle then screen.moduleUnavailableTitle:SetHidden(true) end
        Place(screen.moduleUnavailableBody, b, b.middle + 32, b.middleEnd - 32,
            (b.listTop + b.lower) / 2 - 76, 152)
    end
    HideNative(screen)
    state.backgroundFragment:Refresh()
    return true
end

-- List refreshes can call selection/keybind callbacks synchronously. Keep a
-- single layout pass active and restore the guard even if native code errors.
local rawApply, rawRestore = Pilot.Apply, Pilot.Restore
function Pilot.Apply(screen)
    if screen._tcArchiveLayoutBusy or screen._tcArchiveLayoutPaused then return false end
    screen._tcArchiveLayoutBusy = true
    local ok, result = pcall(rawApply, screen)
    screen._tcArchiveLayoutBusy = nil
    if not ok then error(result) end
    return result
end
function Pilot.Restore(screen)
    local busy = screen._tcArchiveLayoutBusy
    screen._tcArchiveLayoutBusy = true
    local ok, result = pcall(rawRestore, screen)
    screen._tcArchiveLayoutBusy = busy
    if not ok then error(result) end
    return result
end
local function Sync(screen)
    if screen._tcArchiveLayoutBusy or screen._tcArchiveLayoutPaused or screen._tcArchiveLayoutHidden then return end
    if Current(screen) then Pilot.Apply(screen) else Pilot.Restore(screen) end
end
function Pilot.WatchLifecycle(screen)
    -- Modules install their reader/loading hooks on first open. Keep this
    -- observer outside the latest hooks: a reader's resume branch can return
    -- without calling an earlier OnShowing implementation.
    if screen.OnShowing ~= screen._tcArchiveLayoutOnShowing then
        local showing = screen.OnShowing
        local wrapper = function(self, ...)
            self._tcArchiveLayoutHidden = nil
            local result
            if showing then result = showing(self, ...) end
            Sync(self)
            return result
        end
        screen.OnShowing, screen._tcArchiveLayoutOnShowing = wrapper, wrapper
    end
    if screen.OnHiding ~= screen._tcArchiveLayoutOnHiding then
        local hiding = screen.OnHiding
        local wrapper = function(self, ...)
            self._tcArchiveLayoutHidden = true
            Pilot.Restore(self)
            if hiding then return hiding(self, ...) end
        end
        screen.OnHiding, screen._tcArchiveLayoutOnHiding = wrapper, wrapper
    end
end
function Pilot.BeforeShowing(screen)
    screen._tcArchiveLayoutHidden = nil
    Pilot.Install(screen)
    -- A standalone module must open on an installed category, rather than
    -- the disabled Motifs row inherited from the native shared menu.
    local selected = screen.categoryList and screen.categoryList:GetTargetData()
    if selected and TC:IsArchiveModuleInstalled(selected.categoryKey) then return end
    for index, category in ipairs(TC.archiveCategories or {}) do
        if TC:IsArchiveModuleInstalled(category.key) then
            screen.categoryList:SetSelectedIndex(index)
            break
        end
    end
end
function Pilot.Install(screen)
    if screen._tcArchiveLayoutInstalled then Pilot.WatchLifecycle(screen); return end
    screen._tcArchiveLayoutInstalled = true
    local category = screen.ShowCategory
    screen.ShowCategory = function(self, data)
        local state = self._tcArchiveLayout
        if state and state.active and (not data or data.categoryKey ~= state.moduleId) then Pilot.Restore(self) end
        local result = category(self, data)
        Sync(self)
        return result
    end
    local show = screen.ShowStyle
    screen.ShowStyle = function(self, data)
        if not Current(self) then Pilot.Restore(self) end
        local result = show(self, data)
        Sync(self)
        return result
    end
    local refresh = screen.RefreshKeybinds
    screen.RefreshKeybinds = function(self, ...)
        local result = refresh(self, ...)
        Sync(self)
        return result
    end
    Pilot.WatchLifecycle(screen)
end
function Pilot.Prompt(screen, data, config)
    screen:ShowUnavailableCategory(data, TC:GetArchiveCategory(config.id))
    if screen.moduleUnavailableTitle then screen.moduleUnavailableTitle:SetHidden(true) end
    if screen.moduleUnavailableBody then screen.moduleUnavailableBody:SetText(config.intro) end
    if screen.motifSearchFocus and screen.motifSearchFocus.GetEditBox then
        screen.motifSearchFocus:GetEditBox():SetDefaultText('Search ' .. config.name)
    end
    Pilot.Apply(screen)
end
function Pilot.Register(id, config)
    config.id = id
    local module = TC:GetArchiveModule(id)
    if not module then return end
    config.search = module.supportsSearch == true
    Pilot.modules[id] = config
    if module._tcArchiveLayoutWrapped then return end
    module._tcArchiveLayoutWrapped = true
    local focus, open = module.onCategoryFocus, module.open
    module.onCategoryFocus = function(screen, data)
        Pilot.Install(screen)
        Pilot.Prompt(screen, data, config)
    end
    module.open = function(screen)
        Pilot.Install(screen)
        -- Style Pages previously populated on focus. Defer that exact native
        -- catalogue routine to X; the other modules prepare themselves on open.
        local paused = screen._tcArchiveLayoutPaused
        screen._tcArchiveLayoutPaused = true
        local ok, result = pcall(function()
            if config.prepareOnOpen and focus then focus(screen) end
            if open then return open(screen) end
        end)
        screen._tcArchiveLayoutPaused = paused
        if not ok then error(result) end
        Pilot.WatchLifecycle(screen)
        Pilot.Apply(screen)
        return result
    end
end

end
TC.archiveLayout.Register("lorebooks", { name = "Lorebooks", intro = "Explore the Lore Library and track your reading.\nBrowse collections, books and their locations.\n\nPress X to browse Lorebooks.", hint = "Choose a collection to view its books,\nreading progress and locations." })
end
