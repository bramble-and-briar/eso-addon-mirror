
function Librarian:AddLoreReaderUnreadToggle()
    local function IsSameBook(book, title)
        if book.title then
            return book.title == title
        end
        local categoryIndex, collectionIndex, bookIndex = self:GetLoreBookIndicesFromBookId(book.bookId)
        local bookTitle = self:GetBookInfo(categoryIndex, collectionIndex, bookIndex)
        return bookTitle == title
    end

    self.loreReaderKeybinds =
    {
        {
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            name = function()
                local book = self:FindBook(self.lastShownBookId)
                if not book or not IsSameBook(book, LORE_READER.titleText) then
                    self.loreReaderUnreadIndicator:SetHidden(true)
                    return ""
                else
                    if book.unread then
                        if self.settings.showUnreadIndicatorInReader then
                            self.loreReaderUnreadIndicator:SetHidden(false)
                        else
                            self.loreReaderUnreadIndicator:SetHidden(true)
                        end
                        return GetString(LIBRARIAN_MARK_READ)
                    else
                        self.loreReaderUnreadIndicator:SetHidden(true)
                        return GetString(LIBRARIAN_MARK_UNREAD)
                    end
                end
            end,
            visible = function()
                local book = self:FindBook(self.lastShownBookId)
                return book and IsSameBook(book, LORE_READER.titleText)
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function()
                local book = self:FindBook(self.lastShownBookId)
                if book and IsSameBook(book, LORE_READER.titleText) then
                    self:ToggleReadBook(book)
                    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.loreReaderKeybinds)
                end
            end
        }
    }

    local function OnSceneStateChange(oldState, newState)
        -- Let's not add the keybind at all if this book is not registered in librarian
        -- This way, other addon (like Librarium) can override the same keybind for something else
        local book = self:FindBook(self.lastShownBookId)
        if not book or not IsSameBook(book, LORE_READER.titleText) then
            self.loreReaderUnreadIndicator:SetHidden(true)
            return
        end

        if newState == SCENE_SHOWING then
            KEYBIND_STRIP:AddKeybindButtonGroup(self.loreReaderKeybinds)
        elseif newState == SCENE_HIDDEN then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.loreReaderKeybinds)
        end
    end

    -- This list of scene should be the same as the list in esoui/ingame/lorereader/lorereader.lua in its Initialize function
    LORE_READER_DEFAULT_SCENE:RegisterCallback("StateChange", OnSceneStateChange)
    LORE_READER_CUSTOM_SCENE_KEYBOARD:RegisterCallback("StateChange", OnSceneStateChange)
    GAMEPAD_LORE_READER_DEFAULT_SCENE:RegisterCallback("StateChange", OnSceneStateChange)
    LORE_READER_CUSTOM_SCENE_GAMEPAD:RegisterCallback("StateChange", OnSceneStateChange)

    self.loreReaderUnreadIndicator = WINDOW_MANAGER:CreateControl("LibrarianLoreReaderUnreadIndicator", ZO_LoreReaderBookContainer, CT_TEXTURE)
    self.loreReaderUnreadIndicator:SetAnchor(TOPLEFT, ZO_LoreReaderBookContainerFirstPage, TOPLEFT, -32, 3)
    self.loreReaderUnreadIndicator:SetAlpha(self.settings.unreadIndicatorTransparency)
    self.loreReaderUnreadIndicator:SetDimensions(32, 32)
    self.loreReaderUnreadIndicator:SetHidden(true)
    self.loreReaderUnreadIndicator:SetTexture("esoui/art/miscellaneous/new_icon.dds")
end

function Librarian:AddLoreLibraryIcons()
    if not self.settings.showUnreadIndicatorInLoreLibrary then
        return
    end

    -- ADD UNREAD ICON ON EACH UNREAD ENTRY
    local BOOK_DATA_TYPE = 1
    local scrollList = LORE_LIBRARY.list:GetListControl()
    local initalDataType = scrollList.dataTypes[BOOK_DATA_TYPE]
    scrollList.dataTypes[BOOK_DATA_TYPE] = nil

    local function SetUpBookEntry(control, data)
        initalDataType.setupCallback(control, data)

        local _, _, known, bookId = GetLoreBookInfo(data.categoryIndex, data.collectionIndex, data.bookIndex)
        control.bookId = bookId
        local shouldUnreadIconBeHidden = true
        if known then
            local book = self:FindBook(bookId)
            if not book or book.unread then
                shouldUnreadIconBeHidden = false
            end
        end
        control:GetNamedChild("UnreadIcon"):SetHidden(shouldUnreadIconBeHidden)
    end

    ZO_ScrollList_AddDataType(scrollList, BOOK_DATA_TYPE, "Librarian_LoreLibrary_BookEntry", initalDataType.height, SetUpBookEntry)

    -- WHEN READING BOOK FROM LORE LIBRARY, UPDATE LASTSHOWNBOOKID
    local initial_ZO_LoreLibrary_ReadBook = ZO_LoreLibrary_ReadBook
    ZO_LoreLibrary_ReadBook = function(categoryIndex, collectionIndex, bookIndex)
        self.lastShownBookId = select(4, GetLoreBookInfo(categoryIndex, collectionIndex, bookIndex))
        initial_ZO_LoreLibrary_ReadBook(categoryIndex, collectionIndex, bookIndex)
    end

    -- ORDER BOOK LIST TO MAKE UNREAD BOOK FIRST
    -- piece of code adapted from lorelibrary_keyboard.lua
    local function BookEntryComparator(leftScrollData, rightScrollData)
        local leftData = leftScrollData.data
        local rightData = rightScrollData.data
        local leftTitle, _, leftKnown, leftBookId = GetLoreBookInfo(leftData.categoryIndex, leftData.collectionIndex, leftData.bookIndex)
        local rightTitle, _, rightKnown, rightBookId = GetLoreBookInfo(rightData.categoryIndex, rightData.collectionIndex, rightData.bookIndex)

        if leftKnown == rightKnown then
            if leftKnown then
                local leftBook = self:FindBook(leftBookId)
                local rightBook = self:FindBook(rightBookId)
                local wasLeftBookUnread = leftBook == nil or leftBook.unread
                local wasRightBookUnread = rightBook == nil or rightBook.unread

                if wasLeftBookUnread == wasRightBookUnread then
                    return leftTitle < rightTitle
                end

                return wasLeftBookUnread -- we want unread first
            end

            return leftTitle < rightTitle
        end

        return leftKnown
    end
    LORE_LIBRARY.list.SortScrollList = function(loreLibrarySelf)
        local scrollData = ZO_ScrollList_GetDataList(loreLibrarySelf.list)

        local categoryData = loreLibrarySelf.owner.navigationTree:GetSelectedData()
        if categoryData.mailListIndex == nil then
            table.sort(scrollData, BookEntryComparator)
        end
    end

    -- ADD KEYBIND TO MARK BOOK AS READ FROM LORE LIBRARY
    local loreLibraryKeybinds = LORE_LIBRARY.keybindStripDescriptor

    -- Make current secondary tertiary
    for i, keybindDescriptor in ipairs(loreLibraryKeybinds) do
        if keybindDescriptor.keybind == "UI_SHORTCUT_SECONDARY" then
            keybindDescriptor.keybind = "UI_SHORTCUT_TERTIARY"
        end
    end

    local toggleKeybind =
    {
        alignment = KEYBIND_STRIP_ALIGN_RIGHT,
        name = function()
            local selectedRow = LORE_LIBRARY.list:GetMouseOverRow()
            if selectedRow and selectedRow.known then
                local book = self:FindBook(selectedRow.bookId)
                if not book or book.unread then
                    return GetString(LIBRARIAN_MARK_READ)
                else
                    return GetString(LIBRARIAN_MARK_UNREAD)
                end
            end
        end,
        keybind = "UI_SHORTCUT_SECONDARY",
        visible = function()
            local selectedRow = LORE_LIBRARY.list:GetMouseOverRow()
            return selectedRow and selectedRow.known and selectedRow.mailListIndex == nil
        end,
        callback = function()
            local selectedRow = LORE_LIBRARY.list:GetMouseOverRow()
            if selectedRow then
                local book = self:FindBook(selectedRow.bookId)
                if not book then
                    book = { bookId = selectedRow.bookId, title = selectedRow.text:GetText() }
                    self:AddBook(book, true)
                end

                if book then
                    self:ToggleReadBook(book)
                    KEYBIND_STRIP:UpdateKeybindButtonGroup(loreLibraryKeybinds)
                end
            end
        end
    }
    table.insert(loreLibraryKeybinds, toggleKeybind)

    -- ADD UNREAD ICON ON COLLECTION IF IT CONTAINS AN UNREAD BOOK OR ADD COMPLETED MARK IF ALL ARE KNOWN AND READ
    local navigationEntryTemplateInfo = LORE_LIBRARY.navigationTree.templateInfo["ZO_LoreLibraryNavigationEntry"]
    local previousSetupFunction = navigationEntryTemplateInfo.setupFunction

    local function TreeEntrySetup(node, control, data, open)
        previousSetupFunction(node, control, data, open)

        local shouldHideIcon = true
        local statusIcon = control:GetNamedChild("StatusIcon")
        if data.mailListIndex == nil and data.numKnownBooks > 0 and data.categoryIndex ~= nil and data.collectionIndex ~= nil then
            if self.unreadPerCollections[data.categoryIndex] and
                self.unreadPerCollections[data.categoryIndex][data.collectionIndex] and
                self.unreadPerCollections[data.categoryIndex][data.collectionIndex] > 0 then
                shouldHideIcon = false
                statusIcon:SetTexture("esoui/art/miscellaneous/new_icon.dds")
            elseif data.numKnownBooks == data.totalBooks then
                shouldHideIcon = false
                statusIcon:SetTexture("esoui/art/miscellaneous/check.dds")
            end
        end

        statusIcon:SetHidden(shouldHideIcon)

        -- Fix about some collection being grayed out
        -- This happens because the empty hirelingtype/data.mailListIndex can get disabled if empty. And because control can be reused elsewhere when the list is rebuilt, then some random collection can appear disabled
        if data.mailListIndex == nil then
            control:SetEnabled(true)
        end
    end

    navigationEntryTemplateInfo.setupFunction = TreeEntrySetup
    navigationEntryTemplateInfo.template = "Librarian_LoreLibraryNavigationEntry"
    navigationEntryTemplateInfo.objectPool.templateName = "Librarian_LoreLibraryNavigationEntry"

    -- Fix of ESO because a label header is equal to all of its entries with the current code (API 101033, still present at API 101050)
    LORE_LIBRARY.navigationTree.templateInfo["ZO_LabelHeader"].equalityFunction = navigationEntryTemplateInfo.equalityFunction
end

function Librarian:RefreshLoreLibraryData()
    if self.settings.showUnreadIndicatorInLoreLibrary then
        local selectedCategoryIndex = LORE_LIBRARY:GetSelectedCategoryIndex()
        local selectedCollectionIndex = LORE_LIBRARY:GetSelectedCollectionIndex()
        local selectedCollectionId = select(7, GetLoreCollectionInfo(selectedCategoryIndex, selectedCollectionIndex))
        LORE_LIBRARY:SetCollectionIdToSelect(selectedCollectionId)
        LORE_LIBRARY:BuildCategoryList()
    end
end
