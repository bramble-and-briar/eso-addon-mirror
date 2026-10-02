Librarian = ZO_SortFilterList:Subclass()
Librarian.name = "Librarian"
Librarian.defaults = {}
Librarian.menuSettings = {
    name = "LibrarianOptions",
    authors = "Orionik, |c4EFFF6Calia1120|r, Flamage",
    version = "3.18",
    optionSlashCommandText = "/librarianOptions"
}
Librarian.slashCommandText = "/librarian"

Librarian.constants = {
    LIBRARIAN_DATA = 1,
    LIBRARIAN_SEARCH = 1,

    ENTRY_SORT_KEYS =
    {
        ["title"] = { },
        ["unread"] = { tiebreaker = "timeStamp" },
        ["timeStamp"] = { tiebreaker = "title" },
        ["category"] = { tiebreaker = "title" },
        ["wordCount"] = { tiebreaker = "title" }
    }
}

ESO_Dialogs["LIBRARIAN_DELETE_BOOK"] =
{
    gamepadInfo =
    {
        dialogType = GAMEPAD_DIALOGS.BASIC,
    },
    title =
    {
        text = LIBRARIAN_DELETE_BOOK_PROMPT_TITLE,
    },
    mainText =
    {
        text = LIBRARIAN_DELETE_BOOK_PROMPT_MESSAGE,
    },
    buttons =
    {
        [1] =
        {
            text = SI_YES,
            callback =  function(dialog) LIBRARIAN:RemoveBook(dialog.data.bookId) end,
        },
        [2] =
        {
            text = SI_NO,
        }
    }
}

function Librarian:New()
    return ZO_SortFilterList.New(self, LibrarianFrame)
end

function Librarian:Initialize(...)
    ZO_SortFilterList.Initialize(self, ...)

    self.masterList = {}
    self.unreadPerCollections = {}
    self.newBookCount = 0
    self.sortHeaderGroup:SelectHeaderByKey("timeStamp")

    ZO_ScrollList_AddDataType(self.list, self.constants.LIBRARIAN_DATA, "LibrarianBookRow", 30, function(control, data) self:SetupBookRow(control, data) end)
    ZO_ScrollList_EnableHighlight(self.list, "ZO_ThinListHighlight")

    self.localSavedVars = ZO_SavedVars:New("Librarian_SavedVariables", 1, nil, self.defaults, nil)
    self.globalSavedVars = ZO_SavedVars:NewAccountWide("Librarian_SavedVariables", 1, nil, self.defaults, nil)

    if not self.globalSavedVars.settings then
        self.globalSavedVars.settings = {}
        self.globalSavedVars.saveVersion = 2
    end
    self.settings = self.globalSavedVars.settings

    if not self.globalSavedVars.books then self.globalSavedVars.books = {} end
    self.books = self.globalSavedVars.books

    if not self.globalSavedVars.deletedBooks then self.globalSavedVars.deletedBooks = {} end

    if not self.localSavedVars.characterBooks then
        self.localSavedVars.characterBooks = {}
        self.localSavedVars.saveVersion = 2
    end
    self.characterBooks = self.localSavedVars.characterBooks
    self.characterBooksCache = {}

    for _, bookIdToDelete in ipairs(self.globalSavedVars.deletedBooks) do
        self:RemoveCharacterBook(bookIdToDelete)
    end

    self.searchBox = GetControl(LibrarianFrame, "SearchBox")
    self.searchBox:SetHandler("OnTextChanged", function() self:OnSearchTextChanged() end)
    self.search = ZO_StringSearch:New()
    self.search:AddProcessor(self.constants.LIBRARIAN_SEARCH, function(stringSearch, data, searchTerm, cache) return self:ProcessBookEntry(stringSearch, data, searchTerm, cache) end)

    self.sortFunction = function(listEntry1, listEntry2) return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, self.constants.ENTRY_SORT_KEYS, self.currentSortOrder) end

    LibrarianDeprecation:UpdateSavedVariables(self)

    local librarianSettings = LibrarianSettings:New(self.settings, self.menuSettings)

    local function OnShowAllBooksClicked(checkButton, isChecked)
        self.settings.showAllBooks = isChecked
        self:RefreshData()
    end

    local function GetShowAllBooks()
        return self.settings.showAllBooks
    end

    local showAllBooks = LibrarianFrameShowAllBooks
    ZO_CheckButton_SetToggleFunction(showAllBooks, OnShowAllBooksClicked)
    ZO_CheckButton_SetCheckState(showAllBooks, GetShowAllBooks())

    local function OnSearchOnlyTitleClicked(checkButton, isChecked)
        if isChecked then
            LibrarianFrameSearchLabel:SetText(GetString(LIBRARIAN_TITLE_SEARCH))
        else
            LibrarianFrameSearchLabel:SetText(GetString(LIBRARIAN_FULLTEXT_SEARCH))
        end
        self.searchOnlyTitle = isChecked

        if self.searchBox:GetText() ~= "" then
            self:RefreshFilters()
        end
    end

    local searchOnlyTitleControl = LibrarianFrameSearchOnlyTitle
    ZO_CheckButton_SetToggleFunction(searchOnlyTitleControl, OnSearchOnlyTitleClicked)
    self.searchOnlyTitle = false

    self:RefreshData()
    self:InitializeKeybindStripDescriptors()
    self:InitializeScene()
    self:AddLoreReaderUnreadToggle()
    self:AddLoreLibraryIcons()

    self:ImportFromLoreLibrary()
end

function Librarian:ReadBook(data)
    self.lastShownBookId = data.bookId

    if data.categoryIndex and data.collectionIndex and data.bookIndex then
        local body, medium, showTitle = self:ReadLoreBook(data.categoryIndex, data.collectionIndex, data.bookIndex)
        if medium ~= 0 then
            LORE_READER:SetupBook(data.title, body, medium, showTitle)
        else
            d(GetString(LIBRARIAN_COULD_NOT_READ))
            PlaySound(SOUNDS.GENERAL_ALERT_ERROR)
            return
        end
    else
        LORE_READER:SetupBook(data.title, data.body, data.medium, data.showTitle)
    end

    SCENE_MANAGER:Push("loreReaderDefault")

    PlaySound(LORE_READER.OpenSound)
end

function Librarian:RefreshAllData()
    self:RefreshData()
    self:RefreshLoreLibraryData()
end

function Librarian.SlashCommand(args)
    LIBRARIAN:Toggle()
end

function Librarian.OnShowBook(eventCode, title, body, medium, showTitle, bookId)
    local book = { title = title, body = body, medium = medium, showTitle = showTitle, bookId = bookId }
    LIBRARIAN:AddBook(book, true)
    LIBRARIAN.lastShownBookId = bookId

    -- I don't know why, but if I don't update the keybinds here when opening a book,
    -- the keybind I add after doesn't work
    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
    KEYBIND_STRIP:AddKeybindButtonGroup(LIBRARIAN.loreReaderKeybinds)
end

function Librarian.OnAddonLoaded(event, addon)
    if addon == Librarian.name then
        EVENT_MANAGER:UnregisterForEvent(Librarian.name, EVENT_ADD_ON_LOADED)
        LIBRARIAN = Librarian:New()
        EVENT_MANAGER:RegisterForEvent(Librarian.name, EVENT_SHOW_BOOK, Librarian.OnShowBook)
    end
end

SLASH_COMMANDS[Librarian.slashCommandText] = Librarian.SlashCommand

EVENT_MANAGER:RegisterForEvent(Librarian.name, EVENT_ADD_ON_LOADED, Librarian.OnAddonLoaded)
