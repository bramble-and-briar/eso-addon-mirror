-- FurnishingCatalogBrowseActions.lua: the catalog screen.
--
-- A stock gamepad list screen (ZO_Gamepad_ParametricList_Screen) in the housing editor's furniture
-- browser layout (GAMEPAD_HOUSING_FURNITURE_BROWSER_SCENE in gamepadingamescenes.lua): lists in
-- quadrant 1, the 3D preview centred in quadrants 2-3, the item tooltip on the right.
--   subcategory list (under category headers) -> item list of that subcategory, cut into sections
--   (A-Z / style / quality)
-- Only one subcategory's rows exist at a time. The preview follows the selected item through
-- ITEM_PREVIEW_GAMEPAD and the public PreviewItemLink. Everything here is created on the first
-- /furn, so a player who never opens the catalog pays nothing.
local FC = FurnishingCatalog
local ScanUtils = FC.ScanUtils
local Scan = FC.Scan
local BrowseUtils = FC.BrowseUtils
local Search = FC.Search
local ShoppingUtils = FC.ShoppingUtils
local Shopping = FC.Shopping
local PlanUtils = FC.PlanUtils
local Plans = FC.Plans

local Browse = {}

Browse.SCENE_NAME = "FurnishingCatalogGamepad"
Browse.PREVIEW_TYPE = "FurnishingCatalog_ItemLink" -- string key: cannot collide with ZO_ITEM_PREVIEW_* numbers
Browse.CONTROL_NAME = "FurnishingCatalog_GamepadTopLevel"

local SUBCATEGORY_TEMPLATE = "ZO_GamepadMenuEntryTemplate"
local SUBCATEGORY_TEMPLATE_WITH_HEADER = SUBCATEGORY_TEMPLATE .. "WithHeader"
local ITEM_TEMPLATE = "ZO_GamepadItemSubEntryTemplate"
local ITEM_TEMPLATE_WITH_HEADER = ITEM_TEMPLATE .. "WithHeader"
local PREVIEW_LOG_LIMIT = 8
local PREVIEW_SAMPLE_DELAYS_MS = { 300, 1200 }   -- when a logged preview is asked whether it is showing

-- /furn probe: links tried one after another on the open screen, to learn from one export which
-- link forms this client renders here. The first two are verbatim links that rendered on console
-- before (Preview Anywhere logs: a chat link in its own preview scene, a recipe result in a store).
local PROBE_STEP_MS = 1600
local PROBE_SAMPLE_DELAYS_MS = { 250, 800, 1400 }
local PROBE_KNOWN_CHAT_LINK = "|H1:item:125550:5:1:0:0:0:0:0:0:0:0:0:0:0:65:0:0:1:0:0:0|h|h"
local PROBE_KNOWN_STORE_LINK = "|H0:item:120648:2:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
local PROBE_BED_ID = 139214      -- 'Alinor Bed, Canopy Full': the 0.2.0 preview that did not report as showing
local PROBE_FLOWERS_ID = 125550  -- 'Flowers, Lava Blooms': the furnishing of the known chat link
local PROBE_QUALITY_IDS = { 125550, 120648, 120652, 145417, 139122, 139214 }

local PREPARING_TEXT = "Preparing the catalog."
local SCANNING_TEXT = "Scanning the game for every furnishing. Leaving this screen pauses the scan; /furn scan continues it."
local EMPTY_TEXT = "No furnishings found."
local EMPTY_SHOPPING_LIST_TEXT = "Nothing on this list yet. Add to List puts the furnishing you are looking at on it."

---@type table|nil the screen object, once created
local screen = nil
local creationError = nil
local fullScanRequested = false -- /furn scan asked for a full scan on the next show
local probeRequested = false    -- /furn probe asked for the preview test on the next show
local jumpToSearchState = "not asked yet (the catalog has not been opened)"
local jumpToSearchRegistered = false

---Open a web page in the system browser (on console: the built-in one), the way
---LibConsoleLogger's export does: through the secure call where the function is protected.
---@param url string
---@return boolean asked the client took the request
local function OpenUrl(url)
    local request = rawget(_G, "RequestOpenUnsafeURL")
    if type(request) ~= "function" then
        return false
    end
    local isProtected = rawget(_G, "IsProtectedFunction")
    local callSecure = rawget(_G, "CallSecureProtected")
    if isProtected and callSecure then
        local okProtected, protected = pcall(isProtected, "RequestOpenUnsafeURL")
        if okProtected and protected == true then
            local okSecure, secureResult = pcall(callSecure, "RequestOpenUnsafeURL", url)
            if okSecure and secureResult == true then
                return true
            end
        end
    end
    return (pcall(request, url))
end

-- ---------------------------------------------------------------- preview

---Preview type that renders an item link through the public PreviewItemLink.
local LinkPreviewType = ZO_ItemPreviewType:Subclass()

function LinkPreviewType:SetStaticParameters(itemLink)
    self.itemLink = itemLink
end

function LinkPreviewType:ResetStaticParameters()
    self.itemLink = nil
end

function LinkPreviewType:HasStaticParameters(itemLink)
    return self.itemLink == itemLink
end

function LinkPreviewType:Apply(variationIndex)
    FC.Count("previewApply")
    local ok, err = pcall(PreviewItemLink, self.itemLink, variationIndex)
    if not ok then
        FC.Log("ERROR PreviewItemLink(%s): %s", tostring(self.itemLink), tostring(err))
    end
end

function LinkPreviewType:GetNumVariations()
    local ok, numVariations = pcall(GetNumItemLinkPreviewVariations, self.itemLink)
    return ok and numVariations or 0
end

function LinkPreviewType:GetVariationName(variationIndex)
    local ok, name = pcall(GetItemLinkPreviewVariationDisplayName, self.itemLink, variationIndex)
    if ok and name and name ~= "" then
        return name
    end
    return tostring(variationIndex)
end

local previewLogs = 0
local lastLoggedPreviewId = nil

---What the preview system reports right now, for a diagnostic line.
---@return string
local function PreviewStateLine()
    local preview = ITEM_PREVIEW_GAMEPAD
    local okShowing, fragmentShowing = pcall(function() return preview.fragment:IsShowing() end)
    return FC.Fmt("available=%s modeEnabled=%s previewing=%s waiting=%s fragmentShowing=%s applies=%s", FC.CallText("IsCharacterPreviewingAvailable"),
        FC.CallText("GetPreviewModeEnabled"), FC.CallText("IsCurrentlyPreviewing"), tostring(preview.waitingForPreviewBegin), okShowing and tostring(fragmentShowing) or "?",
        tostring(FC.diagnostics.counters.previewApply or 0))
end

---Where the player is and what the character is doing: the things a preview may depend on.
---@return string
local function ContextLine()
    return FC.Fmt("zone=%s '%s' avaWorld=%s house=%s interaction=%s combat=%s dead=%s mounted=%s", FC.CallText("GetUnitWorldPosition", "player"), FC.CallText("GetUnitZone", "player"),
        FC.CallText("IsPlayerInAvAWorld"), FC.CallText("GetCurrentZoneHouseId"), FC.CallText("GetInteractionType"), FC.CallText("IsUnitInCombat", "player"),
        FC.CallText("IsUnitDead", "player"), FC.CallText("IsMounted"))
end

local NOTE_NO_PREVIEW = "Not available"
local NOTE_PREVIEW_BLOCKED = "Unavailable right now"

---Show the item in 3D, or clear the preview for an item the game cannot preview.
---@param item FurnishingCatalogItem
---@return string|nil note why nothing is shown, for the header
local function PreviewItem(item)
    -- The scene's preview options fragment buffers model loads (300 ms), so a fast scroll loads
    -- one model at the end instead of one per row.
    local preview = ITEM_PREVIEW_GAMEPAD
    local available = IsCharacterPreviewingAvailable()
    if item.canPreview and available then
        preview:SharedPreviewSetup(Browse.PREVIEW_TYPE, item.link)
    else
        preview:EndCurrentPreview()
    end
    if previewLogs < PREVIEW_LOG_LIMIT and item.id ~= lastLoggedPreviewId and FC.IsDebug() then
        previewLogs = previewLogs + 1
        lastLoggedPreviewId = item.id
        local id = item.id
        FC.Log("preview #%d: %d '%s' canPreview=%s %s | %s", previewLogs, id, item.name, tostring(item.canPreview), item.link, PreviewStateLine())
        for _, delayMs in ipairs(PREVIEW_SAMPLE_DELAYS_MS) do
            zo_callLater(function()
                FC.Log("  +%dms %d: %s", delayMs, id, PreviewStateLine())
            end, delayMs)
        end
    end
    if not item.canPreview then
        return NOTE_NO_PREVIEW
    elseif not available then
        return NOTE_PREVIEW_BLOCKED
    end
    return nil
end

local function EndPreview()
    ITEM_PREVIEW_GAMEPAD:EndCurrentPreview()
end

-- ---------------------------------------------------------------- reading the game

---The categories that hold furnishings, each with its subcategories, both in alphabetical order
---(the ones the game gave no name last).
---@param tree table<integer, table<integer, integer[]>>
---@return FurnishingCatalogCategory[]
local function ReadCategories(tree)
    local categories = {}
    local seenCategories = {}

    local function AddCategory(categoryId, categoryIndex)
        if seenCategories[categoryId] then
            return
        end
        local subTree = tree[categoryId]
        seenCategories[categoryId] = true
        if not subTree then
            return
        end
        local name = categoryId ~= 0 and GetFurnitureCategoryInfo(categoryId) or nil
        local icon = categoryId ~= 0 and GetFurnitureCategoryGamepadIcon(categoryId) or nil
        ---@type FurnishingCatalogCategory
        local category = {
            id = categoryId,
            name = (name and name ~= "") and name or "Uncategorized",
            unnamed = not (name and name ~= ""),
            icon = (icon and icon ~= "") and icon or nil,
            count = 0,
            subcategories = {},
        }
        local seenSubcategories = {}
        local function AddSubcategory(subcategoryId)
            -- The console's enumeration names every subcategory twice (0.2.0 log: 223 rows for
            -- 112 subcategories); the first mention keeps its place.
            if seenSubcategories[subcategoryId] then
                return
            end
            seenSubcategories[subcategoryId] = true
            local ids = subTree[subcategoryId]
            if ids and #ids > 0 then
                local subName = subcategoryId ~= 0 and GetFurnitureCategoryInfo(subcategoryId) or nil
                table.insert(category.subcategories, { id = subcategoryId, name = (subName and subName ~= "") and subName or "Other", unnamed = not (subName and subName ~= ""), count = #ids, ids = ids })
                category.count = category.count + #ids
            end
        end
        if categoryIndex then
            for subcategoryIndex = 1, GetNumFurnitureSubcategories(categoryIndex) do
                AddSubcategory(GetFurnitureSubcategoryId(categoryIndex, subcategoryIndex))
            end
        end
        -- Subcategory ids the category tree did not list (0 included).
        for subcategoryId in pairs(subTree) do
            AddSubcategory(subcategoryId)
        end
        if category.count > 0 then
            categories[#categories + 1] = category
        end
    end

    for categoryIndex = 1, GetNumFurnitureCategories() do
        AddCategory(GetFurnitureCategoryId(categoryIndex), categoryIndex)
    end
    -- Category ids the game's tree did not list (0 included).
    for categoryId in pairs(tree) do
        AddCategory(categoryId, nil)
    end
    return BrowseUtils.SortCategories(categories)
end

---The game's category tree exactly as its enumeration hands it out, one log line per category.
local function LogGameTree()
    for categoryIndex = 1, GetNumFurnitureCategories() do
        local categoryId = GetFurnitureCategoryId(categoryIndex)
        local ids = {}
        for subcategoryIndex = 1, GetNumFurnitureSubcategories(categoryIndex) do
            ids[#ids + 1] = tostring(GetFurnitureSubcategoryId(categoryIndex, subcategoryIndex))
        end
        FC.Log("  game tree %d: category %s '%s' lists %d subcategories: %s", categoryIndex, tostring(categoryId), tostring((GetFurnitureCategoryInfo(categoryId))), #ids, table.concat(ids, ","))
    end
end

---Everything the item list shows for one subcategory, read from the game now.
---@param subcategory FurnishingCatalogSubcategory
---@return FurnishingCatalogItem[]
local function ReadItems(subcategory)
    local items = {}
    for _, itemId in ipairs(subcategory.ids) do
        local bareLink = ScanUtils.BareLink(itemId)
        local quality = GetItemLinkDisplayQuality(bareLink) or 0
        local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(bareLink))
        local theme = 0
        local furnitureDataId = GetItemLinkFurnitureDataId(bareLink)
        if furnitureDataId and furnitureDataId ~= 0 then
            local _, _, furnitureTheme = GetFurnitureDataInfo(furnitureDataId)
            theme = furnitureTheme or 0
        end
        items[#items + 1] = {
            id = itemId,
            link = ScanUtils.Link(itemId, quality),
            name = name,
            sortName = zo_strlower(name),
            icon = GetItemLinkIcon(bareLink),
            quality = quality,
            theme = theme,
            canPreview = CanItemLinkBePreviewed(bareLink) == true,
        }
    end
    return items
end

---Section title of an item for the style and quality group modes.
---@param item FurnishingCatalogItem
---@param mode string
---@return string|nil
local function GroupNameOf(item, mode)
    if mode == "style" then
        return GetString("SI_FURNITURETHEMETYPE", item.theme)
    elseif mode == "quality" then
        return GetString("SI_ITEMDISPLAYQUALITY", item.quality)
    elseif mode == "plan" then
        return PlanUtils.SectionName(item.planState)
    end
    return nil
end

local function FormatNumber(n)
    if ZO_CommaDelimitNumber then
        return ZO_CommaDelimitNumber(n)
    end
    return tostring(n)
end

-- ---------------------------------------------------------------- the screen

local Screen = ZO_Gamepad_ParametricList_Screen:Subclass()

function Screen:Initialize(control, scene)
    local ACTIVATE_ON_SHOW = true
    ZO_Gamepad_ParametricList_Screen.Initialize(self, control, ZO_GAMEPAD_HEADER_TABBAR_DONT_CREATE, ACTIVATE_ON_SHOW, scene)

    -- The main list uses the base class's templates (ZO_GamepadMenuEntryTemplate, with and without header).
    self.subcategoryList = self:GetMainList()
    self.itemList = self:AddList("Items", function(list)
        list:AddDataTemplate(ITEM_TEMPLATE, ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
        list:AddDataTemplateWithHeader(ITEM_TEMPLATE, ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadMenuEntryHeaderTemplate")
    end)
    -- The shopping lists by name; opening one shows its furnishings in the item list.
    self.listsList = self:AddList("ShoppingLists", function(list)
        list:AddDataTemplate(SUBCATEGORY_TEMPLATE, ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
    end)
    -- Left / right trigger jump to the previous / next section header.
    self:SetListsUseTriggerKeybinds(true)
    -- The stock search box in the header: moving up from the first row enters it.
    self:AddSearch(self.textSearchKeybindStripDescriptor, FC.Guard("OnSearchTextChanged", function()
        self:OnSearchTextChanged()
    end))

    self.headerData = { titleText = FC.displayName }
    self.catalog = nil          -- FurnishingCatalogCache once loaded or built
    self.categories = {}        -- FurnishingCatalogCategory[]
    self.viewing = nil          -- { category, subcategory, shoppingList? } whose items are listed, nil on the other lists
    self.inLists = false        -- the shopping lists are the current list (or where the item list came from)
    self.showPlan = FC.state.savedVars.showPlan ~= false -- the tooltip shows the furnishing's plan, where it has one
    self.planText = nil         -- what the header says about the plan of the furnishing the list is on
    self.items = nil            -- FurnishingCatalogItem[] of that subcategory
    self.scanning = nil         -- "seed" or "full" while a pass runs on this screen
    self.scanProgressText = ""
    self.previewNote = nil      -- why the selected item shows no preview (header line), or nil
    self.savedIndexes = {}      -- BrowseUtils.PositionKey -> list index
    self.filter = nil           -- the search in effect: { text, tree (matches only), total }
    self.filteredCategories = nil -- FurnishingCatalogCategory[] of that tree
    self.searching = nil        -- the search text while its pass runs
    self.searchProgressText = ""
    self.probe = nil            -- the preview test while it runs: { steps, index }
    self.probeSummary = nil     -- its result, shown in the header until the screen closes
    self.gameTreeLogged = false
end

function Screen:InitializeKeybindStripDescriptors()
    local function Visible(fn)
        return function()
            local ok, result = pcall(fn)
            if not ok then
                FC.Count("keybindVisibleErrors")
                return false
            end
            return result == true
        end
    end

    self.keybindStripDescriptor =
    {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            -- Item list: put the furnishing on a shopping list. The other lists: open the row.
            name = function()
                return self.viewing and "Add to List" or GetString(SI_GAMEPAD_SELECT_OPTION)
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            order = -500,
            sound = SOUNDS.GAMEPAD_MENU_FORWARD,
            visible = Visible(function()
                if self.viewing then
                    return self:TargetItem() ~= nil
                elseif self.inLists then
                    return self.listsList:GetTargetData() ~= nil
                end
                return self.probe == nil and self.searching == nil and self.subcategoryList:GetTargetData() ~= nil
            end),
            callback = FC.Guard("Primary", function() self:OnPrimary() end),
        },
        {
            -- Item list: how it is cut into sections. Shopping lists: rename the list.
            name = function()
                if self.viewing then
                    return FC.Fmt("Sections: %s", BrowseUtils.GroupModeLabel(self:CurrentGroupMode()))
                end
                return "Rename"
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = Visible(function()
                if self.viewing then
                    return true
                end
                return self.inLists and self:TargetShoppingList() ~= nil
            end),
            callback = FC.Guard("Secondary", function()
                if self.viewing then
                    self:CycleGroupMode()
                else
                    self:RenameTargetList()
                end
            end),
        },
        {
            -- Subcategories: go to the shopping lists. Shopping lists: delete the list.
            -- A shopping list's items: take the furnishing off it.
            name = function()
                if self.viewing then
                    return "Remove from List"
                elseif self.inLists then
                    return "Delete"
                end
                return "Shopping Lists"
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = Visible(function()
                if self.viewing then
                    return self.viewing.shoppingList ~= nil and self:TargetItem() ~= nil
                elseif self.inLists then
                    local shoppingList = self:TargetShoppingList()
                    return shoppingList ~= nil and shoppingList.id ~= ShoppingUtils.DEFAULT_ID
                end
                return self.catalog ~= nil and self.scanning == nil and self.probe == nil and self.searching == nil
            end),
            callback = FC.Guard("Tertiary", function()
                if self.viewing then
                    self:RemoveTargetFromList()
                elseif self.inLists then
                    self:DeleteTargetList()
                else
                    self:ShowLists(nil)
                end
            end),
        },
        {
            -- Item list: which tooltip is up, the furnishing's or its plan's.
            name = function()
                return self.showPlan and "Tooltip: Plan" or "Tooltip: Item"
            end,
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            visible = Visible(function()
                return self.viewing ~= nil
            end),
            callback = FC.Guard("ToggleShowPlan", function() self:ToggleShowPlan() end),
        },
        {
            -- Item list: the furnishing's page on the web (where it comes from, recent sales).
            name = "Look Up Online",
            keybind = "UI_SHORTCUT_LEFT_STICK",
            visible = Visible(function()
                return self:TargetItem() ~= nil
            end),
            callback = FC.Guard("LookUpOnline", function() self:LookUpOnline() end),
        },
        {
            -- D-pad Left / Right step through a previewed item's states (lit / unlit ...). The
            -- preview's own action layer (PreviewStateNavigation in bindings.xml) gets the press
            -- first and only passes it down when the item has no states. This button does
            -- nothing; it marks D-pad Left as taken, so no other addon hangs a button on it here
            -- (Preview Anywhere's hover Preview checks the strip before adding one).
            name = "Preview state",
            keybind = "UI_SHORTCUT_INPUT_LEFT",
            ethereal = true,
            callback = function() end,
        },
    }
    ZO_Gamepad_AddBackNavigationKeybindDescriptorsWithSound(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, FC.Guard("Back", function() self:Back() end))

    -- Shown instead of the list's buttons while the search box in the header is selected
    -- (the layout of ZO_Gamepad_ParametricList_Search_Screen, plus Clear).
    self.textSearchKeybindStripDescriptor =
    {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = GetString(SI_GAMEPAD_SELECT_OPTION),
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = FC.Guard("FocusSearch", function() self:SetTextSearchFocused(true) end),
        },
        {
            name = "Clear",
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = Visible(function()
                return self.textSearchHeaderFocus ~= nil and self.textSearchHeaderFocus:GetText() ~= ""
            end),
            callback = FC.Guard("ClearSearch", function() self:ClearSearchText() end),
        },
    }
    ZO_Gamepad_AddBackNavigationKeybindDescriptorsWithSound(self.textSearchKeybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, FC.Guard("BackFromSearch", function()
        SCENE_MANAGER:HideCurrentScene()
    end))
end

---The saved group mode, or the default when the saved one is not on offer.
---@return string
function Screen:CurrentGroupMode()
    return BrowseUtils.ValidGroupMode(FC.state.savedVars.groupMode)
end

-- Called by the base class while the scene is SHOWING, when the screen is marked dirty.
function Screen:PerformUpdate()
    self.dirty = false
    FC.SafeCall("BuildSubcategoryList", self.BuildSubcategoryList, self)
end

function Screen:OnShowing()
    ZO_Gamepad_ParametricList_Screen.OnShowing(self)
    FC.SafeCall("OnShowing", function()
        -- The base class has just made the subcategory list current.
        self.inLists = false
        self.viewing = nil
        self.items = nil
        self.previewNote = nil
        local wantFullScan = fullScanRequested
        fullScanRequested = false
        if wantFullScan then
            self:BeginFullScan()
        elseif not self.catalog then
            self:LoadOrBuild()
        end
        self:SetTextSearchEntryHidden(false)
        -- A search cut short by closing the screen runs again.
        self:OnSearchTextChanged()
        self:RefreshHeader()
        FC.Log("catalog showing: catalog=%s scanning=%s | %s | %s", tostring(self.catalog ~= nil), tostring(self.scanning), PreviewStateLine(), FC.MemText())
        FC.Log("  context: %s", ContextLine())
        if probeRequested then
            probeRequested = false
            -- Once the scene has settled and the preview system has had time to switch on.
            zo_callLater(FC.Guard("StartProbe", function() self:StartProbe() end), PROBE_STEP_MS)
        end
    end)
end

function Screen:OnHiding()
    FC.SafeCall("OnHiding", function()
        self:SaveItemPosition()
        self.viewing = nil
        self.inLists = false
        self.items = nil
        -- Passes run only while this screen is open.
        if self.scanning then
            Scan.Pause()
            self.scanning = nil
            self.dirty = true
        end
        if self.searching then
            Search.Cancel()
            self.searching = nil
        end
        if self.probe then
            FC.Log("probe stopped at step %d of %d: the screen closed", self.probe.index, #self.probe.steps)
            self.probe = nil
        end
        self.probeSummary = nil
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
        FC.Log("catalog hiding: %s", FC.MemText())
    end)
end

function Screen:OnTargetChanged(list, targetData, oldTargetData)
    if list == self.itemList and self.viewing then
        FC.SafeCall("RefreshTarget", self.RefreshTarget, self)
    elseif list == self.listsList and self.inLists then
        -- Rename and Delete depend on the row: not on New List, no Delete on the default list.
        FC.SafeCall("RefreshKeybinds", self.RefreshKeybinds, self)
    end
end

---Use the saved catalog, or file the built-in list by category and fill the screen in when done.
function Screen:LoadOrBuild()
    local catalog = Scan.GetCatalog()
    if catalog then
        FC.Log("catalog from saved variables: %d furnishings (%s), stamp %s", catalog.total, tostring(catalog.source), tostring(catalog.stamp))
        self:SetCatalog(catalog)
        return
    end
    self.scanning = "seed"
    self.scanProgressText = ""
    self:BuildSubcategoryList()
    Scan.StartSeed(
        FC.Guard("OnScanProgress", function(progress) self:OnScanProgress(progress) end),
        FC.Guard("OnScanDone", function(builtCatalog) self:SetCatalog(builtCatalog) end))
end

---Say something the player has to see: in chat, and in the alert corner over this screen.
---@param text string
local function Announce(text)
    FC.Chat(text)
    local alert = rawget(_G, "ZO_Alert")
    if alert then
        pcall(alert, UI_ALERT_CATEGORY_ALERT, nil, "<<1>>", text)
    end
end

---Run (or continue) the full scan on this screen, when the add-on pool has room for it.
function Screen:BeginFullScan()
    local hasRoom, text = Scan.FullScanRoom()
    if not hasRoom then
        Announce("Scan not started: " .. tostring(text))
        if not self.catalog and not self.scanning then
            self:LoadOrBuild()
        end
        return
    end
    if self.viewing or self.inLists then
        self:ShowSubcategories()
    end
    self.scanning = "full"
    self.scanProgressText = ""
    self:BuildSubcategoryList()
    Scan.StartFull(
        FC.Guard("OnScanProgress", function(progress) self:OnScanProgress(progress) end),
        FC.Guard("OnScanDone", function(scannedCatalog) self:SetCatalog(scannedCatalog) end),
        FC.Guard("OnScanPaused", function(pausedText) self:OnScanPaused(pausedText) end))
    self:RefreshHeader()
    self:RefreshKeybinds()
end

---The full scan paused itself to keep the add-on pool's reserve: back to the catalog there is.
---@param text string what to tell the player
function Screen:OnScanPaused(text)
    self.scanning = nil
    self.scanProgressText = ""
    Announce(text)
    if not self.catalog then
        self:LoadOrBuild()
    elseif SCENE_MANAGER:IsShowing(Browse.SCENE_NAME) then
        self:BuildSubcategoryList()
        self:OnSearchTextChanged()
    else
        self.dirty = true
    end
    self:RefreshHeader()
    self:RefreshKeybinds()
end

function Screen:OnScanProgress(progress)
    if not progress then
        return
    end
    self.scanProgressText = FC.Fmt("%d%%  (%s found)", math.floor(progress.fraction * 100), FormatNumber(progress.found))
    if self.scanning and self.viewing == nil then
        self:RefreshHeader()
    end
end

---@param catalog FurnishingCatalogCache
function Screen:SetCatalog(catalog)
    self.catalog = catalog
    self.categories = ReadCategories(catalog.tree)
    self.scanning = nil
    self.savedIndexes = {}
    -- A search belongs to the catalog it ran on: run it again on this one.
    self.filter = nil
    self.filteredCategories = nil
    if FC.IsDebug() and not self.gameTreeLogged then
        self.gameTreeLogged = true
        FC.SafeCall("LogGameTree", LogGameTree)
    end
    for _, category in ipairs(self.categories) do
        local largest = 0
        for _, subcategory in ipairs(category.subcategories) do
            if subcategory.count > largest then
                largest = subcategory.count
            end
        end
        FC.Log("  category %d '%s': %d in %d subcategories (largest %d)", category.id, category.name, category.count, #category.subcategories, largest)
    end
    if SCENE_MANAGER:IsShowing(Browse.SCENE_NAME) then
        self:BuildSubcategoryList()
        self:OnSearchTextChanged()
        self:RefreshHeader()
        self:RefreshKeybinds()
    else
        self.dirty = true
    end
end

---The text in the search box changed (or may have: also called when the screen shows).
---Start the search for it, or show the whole catalog again when it is empty.
function Screen:OnSearchTextChanged()
    if not (self.textSearchHeaderFocus and self.catalog) or self.scanning then
        return
    end
    local text = self.textSearchHeaderFocus:GetText() or ""
    local words = BrowseUtils.SearchWords(zo_strlower(text))
    local wanted = words and table.concat(words, " ") or nil
    local current = self.searching or (self.filter and self.filter.text) or nil
    if wanted == current then
        return
    end
    Search.Cancel()
    self.searching = nil
    self.savedIndexes = {}
    if not wanted then
        self.filter = nil
        self.filteredCategories = nil
        FC.Log("search cleared")
        self:BuildSubcategoryList()
        self:RefreshHeader()
        self:RefreshKeybinds()
        return
    end
    self.searching = wanted
    self.searchProgressText = ""
    Search.Start(self.catalog.tree, wanted, words,
        FC.Guard("OnSearchProgress", function(fraction)
            self.searchProgressText = FC.Fmt("%d%%", math.floor(fraction * 100))
            if self.viewing == nil and not self.probe then
                self:RefreshHeader()
            end
        end),
        FC.Guard("OnSearchDone", function(result)
            self.searching = nil
            self.filter = result
            self.filteredCategories = ReadCategories(result.tree)
            if SCENE_MANAGER:IsShowing(Browse.SCENE_NAME) then
                self:BuildSubcategoryList()
                self:RefreshHeader()
                self:RefreshKeybinds()
            else
                self.dirty = true
            end
        end))
    self:RefreshHeader()
    self:RefreshKeybinds()
end

---The main list: every subcategory that holds furnishings (or search matches), under its category's header.
function Screen:BuildSubcategoryList()
    local list = self.subcategoryList
    list:Clear()
    if not self.scanning then
        for _, category in ipairs(self.filter and self.filteredCategories or self.categories) do
            for index, subcategory in ipairs(category.subcategories) do
                local entry = ZO_GamepadEntryData:New(BrowseUtils.CountLabel(subcategory.name, subcategory.count), category.icon)
                entry.category = category
                entry.subcategory = subcategory
                entry:SetIconTintOnSelection(true)
                if index == 1 then
                    entry:SetHeader(BrowseUtils.CountLabel(category.name, category.count))
                    list:AddEntry(SUBCATEGORY_TEMPLATE_WITH_HEADER, entry)
                else
                    list:AddEntry(SUBCATEGORY_TEMPLATE, entry)
                end
            end
        end
    end
    local emptyText = EMPTY_TEXT
    if self.scanning then
        emptyText = self.scanning == "full" and SCANNING_TEXT or PREPARING_TEXT
    elseif self.filter then
        emptyText = FC.Fmt("No furnishing name holds \"%s\".", self.filter.text)
    end
    list:SetNoItemText(emptyText)
    list:Commit()
end

---Fill the item list from self.items in the saved group mode.
---@param keepItemId integer|nil item to stay on (a regroup); otherwise the remembered position
function Screen:BuildItemList(keepItemId)
    local viewing = self.viewing
    local mode = self:CurrentGroupMode()
    -- Read once per item, and only when a mode shows it.
    if mode == "plan" then
        for _, item in ipairs(self.items) do
            Plans.Fill(item)
        end
    end
    local items, numGroups = BrowseUtils.SortAndGroup(self.items, mode, GroupNameOf)

    local list = self.itemList
    list:Clear()
    for _, item in ipairs(items) do
        local entry = ZO_GamepadEntryData:New(item.name, item.icon)
        entry.item = item
        entry:SetFontScaleOnSelection(false)
        entry:SetNameColors(entry:GetColorsBasedOnQuality(item.quality))
        if not item.canPreview then
            entry.iconDesaturation = 1
        end
        if item.startsGroup then
            entry:SetHeader(item.groupName)
            list:AddEntry(ITEM_TEMPLATE_WITH_HEADER, entry)
        else
            list:AddEntry(ITEM_TEMPLATE, entry)
        end
    end
    list:SetNoItemText(viewing.shoppingList and EMPTY_SHOPPING_LIST_TEXT or EMPTY_TEXT)

    local index = BrowseUtils.IndexOfId(items, keepItemId) or self.savedIndexes[BrowseUtils.PositionKey(viewing.category.id, viewing.subcategory.id, mode)] or 1
    if index > #items then
        index = 1
    end
    if #items > 0 then
        local ALLOW_EVEN_IF_DISABLED = true
        list:SetSelectedIndexWithoutAnimation(index, ALLOW_EVEN_IF_DISABLED)
    end
    list:Commit()
    FC.Log("item list: %s/%s '%s' mode=%s items=%d sections=%d index=%d", tostring(viewing.category.id), tostring(viewing.subcategory.id), viewing.subcategory.name, mode, #items, numGroups, index)
end

function Screen:ViewSubcategory()
    if self.viewing or self.scanning or self.probe or self.searching or not self.catalog then
        return
    end
    local targetData = self.subcategoryList:GetTargetData()
    if not (targetData and targetData.subcategory) then
        return
    end
    local startedMs = GetGameTimeMilliseconds()
    self.viewing = { category = targetData.category, subcategory = targetData.subcategory }
    self.items = ReadItems(targetData.subcategory)
    self:BuildItemList(nil)
    -- The search box belongs to the subcategory list.
    self:SetTextSearchEntryHidden(true)
    self:SetCurrentList(self.itemList)
    self:RefreshHeader()
    self:RefreshTarget()
    FC.Log("subcategory %d opened in %d ms; %s", targetData.subcategory.id, GetGameTimeMilliseconds() - startedMs, FC.MemText())
end

---The furnishing the item list is on, while the item list is showing.
---@return FurnishingCatalogItem|nil
function Screen:TargetItem()
    if not self.viewing then
        return nil
    end
    local targetData = self.itemList:GetTargetData()
    return targetData and targetData.item or nil
end

---The shopping list the list of lists is on (nil on the New List row).
---@return FurnishingCatalogShoppingList|nil
function Screen:TargetShoppingList()
    local targetData = self.listsList:GetTargetData()
    return targetData and targetData.shoppingList or nil
end

function Screen:OnPrimary()
    if self.viewing then
        local item = self:TargetItem()
        if item then
            Shopping.ShowAddDialog(item, FC.Guard("OnItemListed", function() self:RefreshKeybinds() end))
        end
    elseif self.inLists then
        local targetData = self.listsList:GetTargetData()
        if targetData and targetData.newShoppingList then
            Shopping.ShowNameDialog({ onDone = FC.Guard("OnListCreated", function(shoppingList) self:RefreshLists(shoppingList.id) end) })
        elseif targetData and targetData.shoppingList then
            self:ViewShoppingList(targetData.shoppingList)
        end
    else
        self:ViewSubcategory()
    end
end

---Fill the list of shopping lists: one row per list, then a row that makes a new one.
---@param keepListId integer|nil the list to stay on
function Screen:BuildListsList(keepListId)
    local list = self.listsList
    list:Clear()
    local selectIndex = 1
    for index, shoppingList in ipairs(Shopping.Store().lists) do
        local entry = ZO_GamepadEntryData:New(BrowseUtils.CountLabel(shoppingList.name, #shoppingList.items))
        entry.shoppingList = shoppingList
        list:AddEntry(SUBCATEGORY_TEMPLATE, entry)
        if shoppingList.id == keepListId then
            selectIndex = index
        end
    end
    local newEntry = ZO_GamepadEntryData:New("New List")
    newEntry.newShoppingList = true
    list:AddEntry(SUBCATEGORY_TEMPLATE, newEntry)
    local ALLOW_EVEN_IF_DISABLED = true
    list:SetSelectedIndexWithoutAnimation(selectIndex, ALLOW_EVEN_IF_DISABLED)
    list:Commit()
end

---Rebuild the list of shopping lists after one was created, renamed or deleted.
---@param keepListId integer|nil
function Screen:RefreshLists(keepListId)
    if not self.inLists or self.viewing then
        return
    end
    self:BuildListsList(keepListId)
    self:RefreshHeader()
    self:RefreshKeybinds()
end

---Go to the list of shopping lists (from the subcategories, or back from a list's items).
---@param keepListId integer|nil the list to land on
function Screen:ShowLists(keepListId)
    self:LeaveItems()
    self.inLists = true
    self:BuildListsList(keepListId)
    -- The search box belongs to the subcategory list.
    self:SetTextSearchEntryHidden(true)
    self:SetCurrentList(self.listsList)
    self:RefreshHeader()
end

---Show a shopping list's furnishings in the item list.
---@param shoppingList FurnishingCatalogShoppingList
function Screen:ViewShoppingList(shoppingList)
    if self.viewing then
        return
    end
    -- The item list reads a subcategory; a shopping list stands in as one.
    self.viewing = {
        category = { id = "lists", name = "Shopping List" },
        subcategory = { id = "list" .. tostring(shoppingList.id), name = shoppingList.name, count = #shoppingList.items, ids = shoppingList.items },
        shoppingList = shoppingList,
    }
    self.items = ReadItems(self.viewing.subcategory)
    self:BuildItemList(nil)
    self:SetCurrentList(self.itemList)
    self:RefreshHeader()
    self:RefreshTarget()
    FC.Log("shopping list %d '%s' opened: %d furnishings; %s", shoppingList.id, shoppingList.name, #shoppingList.items, FC.MemText())
end

function Screen:RenameTargetList()
    local shoppingList = self:TargetShoppingList()
    if shoppingList then
        Shopping.ShowNameDialog({ list = shoppingList, onDone = FC.Guard("OnListRenamed", function(renamed) self:RefreshLists(renamed.id) end) })
    end
end

function Screen:DeleteTargetList()
    local shoppingList = self:TargetShoppingList()
    if shoppingList then
        Shopping.ShowDeleteDialog(shoppingList, FC.Guard("OnListDeleted", function() self:RefreshLists(nil) end))
    end
end

---Take the furnishing the item list is on off the shopping list being shown.
function Screen:RemoveTargetFromList()
    local viewing = self.viewing
    local item = self:TargetItem()
    if not (viewing and viewing.shoppingList and item) then
        return
    end
    ShoppingUtils.Remove(viewing.shoppingList, item.id)
    viewing.subcategory.count = #viewing.shoppingList.items
    -- self.items is in the order shown: stay on the row that moves up into the gap.
    local index = BrowseUtils.IndexOfId(self.items, item.id)
    if index then
        table.remove(self.items, index)
    end
    local nextItem = index and (self.items[index] or self.items[index - 1]) or nil
    Shopping.Notify(FC.Fmt("%s removed from %s", item.name, viewing.shoppingList.name))
    FC.Log("shopping: removed %d '%s' from list %d '%s' (%d left)", item.id, item.name, viewing.shoppingList.id, viewing.shoppingList.name, #viewing.shoppingList.items)
    self:BuildItemList(nextItem and nextItem.id or nil)
    self:RefreshHeader()
    self:RefreshTarget()
    self:RefreshKeybinds()
end

---Switch the tooltip between the furnishing and its plan. The choice is saved; a furnishing
---without a plan shows its own tooltip either way.
function Screen:ToggleShowPlan()
    self.showPlan = not self.showPlan
    FC.state.savedVars.showPlan = self.showPlan
    FC.Log("tooltip: %s", self.showPlan and "plan" or "furnishing")
    self:RefreshTarget()
    self:RefreshKeybinds()
end

---Open the furnishing's ESO-Hub page in the web browser.
function Screen:LookUpOnline()
    local item = self:TargetItem()
    if not item then
        return
    end
    local url = BrowseUtils.WebUrl(item.name)
    local asked = url ~= nil and OpenUrl(url)
    FC.Log("look up online: %d '%s' -> %s (%s)", item.id, item.name, tostring(url), asked and "asked the browser" or "could not ask")
    if not asked then
        Shopping.Notify("The web browser could not be opened.")
    end
end

function Screen:CycleGroupMode()
    if not self.viewing then
        return
    end
    local targetData = self.itemList:GetTargetData()
    local keepItemId = targetData and targetData.item and targetData.item.id or nil
    FC.state.savedVars.groupMode = BrowseUtils.NextGroupMode(self:CurrentGroupMode())
    self:BuildItemList(keepItemId)
    self:RefreshKeybinds()
    self:RefreshTarget()
end

function Screen:Back()
    if self.viewing then
        if self.viewing.shoppingList then
            self:ShowLists(self.viewing.shoppingList.id)
        else
            self:ShowSubcategories()
        end
    elseif self.inLists then
        self:ShowSubcategories()
    else
        SCENE_MANAGER:HideCurrentScene()
    end
end

---Leave the item list behind (a no-op when it is not showing): position, preview, tooltip.
function Screen:LeaveItems()
    self:SaveItemPosition()
    self.viewing = nil
    self.items = nil
    self.previewNote = nil
    self.planText = nil
    EndPreview()
    GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
end

function Screen:ShowSubcategories()
    self:LeaveItems()
    self.inLists = false
    self:SetTextSearchEntryHidden(false)
    self:SetCurrentList(self.subcategoryList)
    self:RefreshHeader()
end

---Remember where the player is in the current subcategory for the current group mode.
function Screen:SaveItemPosition()
    local viewing = self.viewing
    if not viewing then
        return
    end
    local mode = self:CurrentGroupMode()
    self.savedIndexes[BrowseUtils.PositionKey(viewing.category.id, viewing.subcategory.id, mode)] = self.itemList:GetSelectedIndex()
end

---Tooltip and 3D preview for the item the list is on.
function Screen:RefreshTarget()
    if not self.viewing then
        return
    end
    local targetData = self.itemList:GetTargetData()
    local item = targetData and targetData.item
    local note, planText = nil, nil
    if item then
        planText = PlanUtils.StateText(Plans.Fill(item))
        -- The preview is the furnishing either way; the tooltip can be its plan's.
        GAMEPAD_TOOLTIPS:LayoutItem(GAMEPAD_RIGHT_TOOLTIP, self.showPlan and item.planLink or item.link)
        note = PreviewItem(item)
    else
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
        EndPreview()
    end
    if note ~= self.previewNote or planText ~= self.planText then
        self.previewNote = note
        self.planText = planText
        self:RefreshHeader()
    end
end

function Screen:RefreshHeader()
    local headerData = self.headerData
    headerData.data2HeaderText = nil
    headerData.data2Text = nil
    headerData.data3HeaderText = nil
    headerData.data3Text = nil
    if self.viewing then
        headerData.titleText = self.viewing.subcategory.name
        headerData.data1HeaderText = self.viewing.category.name
        headerData.data1Text = FormatNumber(self.viewing.subcategory.count)
        -- About the furnishing the list is on: its plan, why it shows no preview.
        local slot = 2
        local function Field(title, text)
            if text then
                headerData["data" .. slot .. "HeaderText"] = title
                headerData["data" .. slot .. "Text"] = text
                slot = slot + 1
            end
        end
        Field("Plan", self.planText)
        Field("Preview", self.previewNote)
    elseif self.probe then
        local step = self.probe.steps[self.probe.index]
        headerData.titleText = "Preview test"
        headerData.data1HeaderText = "Step"
        headerData.data1Text = FC.Fmt("%d of %d", self.probe.index, #self.probe.steps)
        headerData.data2HeaderText = "Trying"
        headerData.data2Text = step and step.label or ""
    elseif self.inLists then
        headerData.titleText = "Shopping Lists"
        headerData.data1HeaderText = "Lists"
        headerData.data1Text = FormatNumber(#Shopping.Store().lists)
    elseif self.scanning then
        headerData.titleText = FC.displayName
        headerData.data1HeaderText = self.scanning == "full" and "Scanning" or "Preparing"
        headerData.data1Text = self.scanProgressText ~= "" and self.scanProgressText or "0%"
    elseif self.searching then
        headerData.titleText = FC.displayName
        headerData.data1HeaderText = "Searching"
        headerData.data1Text = self.searchProgressText ~= "" and self.searchProgressText or "0%"
    else
        headerData.titleText = FC.displayName
        if self.filter then
            headerData.data1HeaderText = "Matches"
            headerData.data1Text = FC.Fmt("%s of %s", FormatNumber(self.filter.total), FormatNumber(self.catalog and self.catalog.total or 0))
        else
            headerData.data1HeaderText = "Furnishings"
            headerData.data1Text = FormatNumber(self.catalog and self.catalog.total or 0)
        end
        if self.probeSummary then
            headerData.data2HeaderText = "Preview test"
            headerData.data2Text = self.probeSummary
        end
    end
    ZO_GamepadGenericHeader_Refresh(self.header, headerData)
end

-- ---------------------------------------------------------------- preview test (/furn probe)

---@return { label: string, link: string }[]
local function ProbeSteps()
    local function Quality(itemId)
        return GetItemLinkDisplayQuality(ScanUtils.BareLink(itemId)) or 0
    end
    local bed, flowers = PROBE_BED_ID, PROBE_FLOWERS_ID
    return {
        { label = "flowers, chat link", link = PROBE_KNOWN_CHAT_LINK },
        { label = "boulder, store link", link = PROBE_KNOWN_STORE_LINK },
        { label = "bed, as the list builds it", link = ScanUtils.Link(bed, Quality(bed)) },
        { label = "bed, plain link", link = ScanUtils.BareLink(bed) },
        { label = "bed, quality + 1", link = ScanUtils.Link(bed, Quality(bed) + 1) },
        { label = "flowers, as the list builds it", link = ScanUtils.Link(flowers, Quality(flowers)) },
        { label = "flowers, plain link", link = ScanUtils.BareLink(flowers) },
    }
end

---What quality the game reports for a furnishing under each link subtype 0-6.
local function LogQualityBySubtype()
    for _, itemId in ipairs(PROBE_QUALITY_IDS) do
        local display, functional = {}, {}
        for subtype = 0, 6 do
            local link = subtype == 0 and ScanUtils.BareLink(itemId) or ScanUtils.Link(itemId, subtype)
            display[#display + 1] = FC.CallText("GetItemLinkDisplayQuality", link)
            functional[#functional + 1] = FC.CallText("GetItemLinkFunctionalQuality", link)
        end
        FC.Log("  quality of %d '%s' by link subtype 0-6: display %s | functional %s", itemId, tostring(GetItemLinkName(ScanUtils.BareLink(itemId))), table.concat(display, ","),
            table.concat(functional, ","))
    end
end

---The add-ons that are switched on: they share the memory pool.
local function LogEnabledAddOns()
    local manager = GetAddOnManager()
    local names = {}
    local total = manager:GetNumAddOns()
    for index = 1, total do
        local name, _, _, _, enabled = manager:GetAddOnInfo(index)
        if enabled then
            names[#names + 1] = tostring(name)
        end
    end
    FC.Log("  add-ons switched on: %d of %d", #names, total)
    for first = 1, #names, 12 do
        FC.Log("    %s", table.concat(names, ", ", first, math.min(first + 11, #names)))
    end
end

function Screen:StartProbe()
    if self.probe or not SCENE_MANAGER:IsShowing(Browse.SCENE_NAME) then
        return
    end
    if self.viewing or self.inLists then
        self:ShowSubcategories()
    end
    self.probe = { steps = ProbeSteps(), index = 0 }
    self.probeSummary = nil
    FC.Log("probe started: %s | %s", PreviewStateLine(), FC.MemText())
    FC.Log("  context: %s", ContextLine())
    FC.SafeCall("LogQualityBySubtype", LogQualityBySubtype)
    FC.SafeCall("LogEnabledAddOns", LogEnabledAddOns)
    self:RefreshKeybinds()
    self:ProbeNext()
end

---Show the next link of the test and ask a few times whether the game says it is showing.
function Screen:ProbeNext()
    local probe = self.probe
    if not probe then
        return
    end
    probe.index = probe.index + 1
    local index = probe.index
    local step = probe.steps[index]
    if not step then
        self:FinishProbe()
        return
    end
    local link = step.link
    EndPreview()
    FC.Log("probe %d/%d '%s' %s: name='%s' type=%s canPreview=%s quality=%s variations=%s", index, #probe.steps, step.label, link, tostring(GetItemLinkName(link)),
        tostring(GetItemLinkItemType(link)), tostring(CanItemLinkBePreviewed(link)), tostring(GetItemLinkDisplayQuality(link)), FC.CallText("GetNumItemLinkPreviewVariations", link))
    self:RefreshHeader()
    ITEM_PREVIEW_GAMEPAD:SharedPreviewSetup(Browse.PREVIEW_TYPE, link)
    for _, delayMs in ipairs(PROBE_SAMPLE_DELAYS_MS) do
        zo_callLater(FC.Guard("ProbeSample", function()
            if self.probe ~= probe or probe.index ~= index then
                return
            end
            if IsCurrentlyPreviewing() then
                step.showing = true
            end
            FC.Log("  probe %d +%dms: %s", index, delayMs, PreviewStateLine())
        end), delayMs)
    end
    zo_callLater(FC.Guard("ProbeNext", function()
        if self.probe == probe and probe.index == index then
            self:ProbeNext()
        end
    end), PROBE_STEP_MS)
end

function Screen:FinishProbe()
    local probe = self.probe
    self.probe = nil
    EndPreview()
    local results = {}
    local numShowing = 0
    for index, step in ipairs(probe.steps) do
        results[#results + 1] = FC.Fmt("%d=%s", index, step.showing and "yes" or "no")
        if step.showing then
            numShowing = numShowing + 1
        end
    end
    FC.Log("probe result (the game reported a preview showing): %s", table.concat(results, " "))
    FC.Log("  after the probe: %s", FC.MemText())
    self.probeSummary = FC.Fmt("done: %d of %d reported showing", numShowing, #probe.steps)
    FC.Chat(FC.Fmt("preview test %s. /furn export sends the details.", self.probeSummary))
    self:RefreshHeader()
    self:RefreshKeybinds()
end

-- ---------------------------------------------------------------- scene

---Keep the catalog open when a preview dismounts the player.
---The scene manager leaves UI mode, closing whatever screen is open, on every mount state change
---(ZO_IngameSceneManager:OnMountStateChanged in ingamescenemanager.lua), except on the scenes of
---a list local to that file: the stock screens that preview (inventory, collections, store,
---guild store ...), because a preview dismounts the player. An add-on scene cannot be put on
---that list, so the manager's question is answered for this one scene and passed on otherwise.
local function KeepOpenOnMountChange()
    local manager = SCENE_MANAGER
    local original = manager.DoesCurrentSceneOverrideMountStateChange
    if type(original) ~= "function" then
        FC.Log("scene manager has no DoesCurrentSceneOverrideMountStateChange: a preview while mounted will close the catalog")
        return
    end
    manager.DoesCurrentSceneOverrideMountStateChange = function(self, ...)
        if self:IsShowing(Browse.SCENE_NAME) then
            FC.Count("mountChangeKept")
            return true
        end
        return original(self, ...)
    end
    EVENT_MANAGER:RegisterForEvent(FC.name .. "_Mount", EVENT_MOUNTED_STATE_CHANGED, function(_event, mounted)
        if SCENE_MANAGER:IsShowing(Browse.SCENE_NAME) then
            FC.Log("mount state changed while the catalog is showing: mounted=%s | %s", tostring(mounted), PreviewStateLine())
        end
    end)
end

---Let Jump to Search (optional; 0.3.0 takes other add-ons' screens) send D-pad Right to the
---search box above the subcategory list. Asked as the catalog opens, until it holds.
local function RegisterWithJumpToSearch()
    if jumpToSearchRegistered then
        return
    end
    local before = jumpToSearchState
    local jumpToSearch = rawget(_G, "JumpToSearch")
    if type(jumpToSearch) ~= "table" then
        jumpToSearchState = "not installed"
    elseif type(jumpToSearch.RegisterScreen) ~= "function" then
        jumpToSearchState = "installed, but older than 0.3.0: it cannot take this screen"
    else
        local ok, registered = pcall(jumpToSearch.RegisterScreen, "furnishingcatalog", Browse.SCENE_NAME, function() return screen end)
        if ok and registered == true then
            jumpToSearchRegistered = true
            jumpToSearchState = "registered: D-pad Right goes to the search box"
        else
            jumpToSearchState = "refused (" .. tostring(registered) .. ")"
        end
    end
    if jumpToSearchState ~= before then
        FC.Log("jump to search: %s", jumpToSearchState)
    end
end

local function CreateScreen()
    FC.Log("creating the catalog screen; %s", FC.MemText())
    local control = rawget(_G, Browse.CONTROL_NAME)
    local controlSource = "xml"
    if not control then
        -- The XML did not load: build the same control from the stock template.
        control = CreateControlFromVirtual(Browse.CONTROL_NAME, GuiRoot, "ZO_Gamepad_ParametricList_Screen")
        controlSource = "lua"
    end

    ITEM_PREVIEW_GAMEPAD.previewTypeObjects[Browse.PREVIEW_TYPE] = LinkPreviewType:New()

    local scene = ZO_Scene:New(Browse.SCENE_NAME, SCENE_MANAGER)
    local createdScreen = Screen:New(control, scene)

    -- Same fragments, same order, as the housing editor's furniture browser scene. The preview
    -- options fragment has to come before the ITEM_PREVIEW_GAMEPAD fragment.
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_CENTERED_NO_BLUR)
    scene:AddFragment(ZO_SimpleSceneFragment:New(control))
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_2_3_FURNITURE_ITEM_PREVIEW_OPTIONS_FRAGMENT)
    scene:AddFragment(ITEM_PREVIEW_GAMEPAD:GetFragment())

    KeepOpenOnMountChange()
    FC.SafeCall("RegisterDialogs", Shopping.RegisterDialogs)

    screen = createdScreen
    FC.Log("catalog screen created (control from %s); %s", controlSource, FC.MemText())
end

---@return boolean created the screen exists
local function EnsureScreen()
    if screen then
        return true
    end
    if creationError then
        return false
    end
    if not (rawget(_G, "ITEM_PREVIEW_GAMEPAD") and rawget(_G, "ZO_Gamepad_ParametricList_Screen")) then
        creationError = "gamepad UI not available"
        return false
    end
    local ok, err = pcall(CreateScreen)
    if not ok then
        creationError = tostring(err)
        table.insert(FC.diagnostics.errors, "CreateScreen: " .. creationError)
        FC.Log("ERROR CreateScreen: %s", creationError)
        return false
    end
    return true
end

---Open the catalog screen.
---@param fromMenu boolean|nil opened from a menu entry: Back returns to that menu
---@return boolean opened
function Browse.Open(fromMenu)
    if not IsInGamepadPreferredMode() then
        FC.Chat("the catalog is a gamepad screen; switch to gamepad mode to open it")
        return false
    end
    if not EnsureScreen() then
        FC.Chat(FC.Fmt("could not create the catalog screen: %s", tostring(creationError)))
        return false
    end
    if SCENE_MANAGER:IsShowing(Browse.SCENE_NAME) then
        return true
    end
    FC.SafeCall("RegisterWithJumpToSearch", RegisterWithJumpToSearch)
    FC.Log("opening from scene %s", tostring(SCENE_MANAGER:GetCurrentScene() and SCENE_MANAGER:GetCurrentScene():GetName()))
    if fromMenu then
        SCENE_MANAGER:Push(Browse.SCENE_NAME)
    else
        SCENE_MANAGER:Show(Browse.SCENE_NAME)
    end
    return true
end

---Run (or continue) the full scan: on the open screen at once, otherwise as the screen opens.
function Browse.FullScan()
    if screen and SCENE_MANAGER:IsShowing(Browse.SCENE_NAME) then
        screen:BeginFullScan()
        return
    end
    fullScanRequested = true
    if not Browse.Open() then
        fullScanRequested = false
    end
end

---Run the preview test: on the open screen at once, otherwise as the screen opens.
function Browse.Probe()
    if screen and SCENE_MANAGER:IsShowing(Browse.SCENE_NAME) then
        screen:StartProbe()
        return
    end
    probeRequested = true
    if not Browse.Open() then
        probeRequested = false
    end
end

---Forget the saved catalog and any paused full scan: back to the built-in list.
function Browse.Reset()
    Scan.Pause()
    Scan.Reset()
    if screen then
        screen.catalog = nil
        screen.categories = {}
        screen.scanning = nil
        if SCENE_MANAGER:IsShowing(Browse.SCENE_NAME) then
            if screen.viewing or screen.inLists then
                screen:ShowSubcategories()
            end
            screen:LoadOrBuild()
            screen:RefreshHeader()
            screen:RefreshKeybinds()
        else
            screen.dirty = true
        end
    end
end

---@return string|nil
---@return string state whether Jump to Search took the catalog screen
function Browse.JumpToSearchState()
    return jumpToSearchState
end

function Browse.GetCreationError()
    return creationError
end

---@return table|nil
function Browse.GetScreen()
    return screen
end

FC.Browse = Browse
