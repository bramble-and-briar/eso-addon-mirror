-- Housing editor (keyboard): Retrieve list sort headers, right-click to store,
-- "Retrieve To" docked in the list footer, bound furnishings to the Furnishing Vault,
-- and keeping the category position when a category empties.
-- Formerly the standalone addon HousingRetrieveSort.

local SHT = SchrodisHousingTools

local HEADER_HEIGHT = 26
local KEY_NAME = SHT.SORT_KEY_NAME
local KEY_DISTANCE = SHT.SORT_KEY_DISTANCE

-- Row layout (ZO_RetrievableFurnitureSlot): name label starts at 32 (status icon) + 89,
-- distance label ends 10 + 32 + 10 px before the row's right edge (direction arrow column).
local NAME_COLUMN_X = 121
local DISTANCE_COLUMN_RIGHT_INSET = 52

local sv

--------------------------------------------------------------------------------
-- Sorting
--------------------------------------------------------------------------------

local function TieBreak(a, b)
    local idA, idB = a.retrievableFurnitureId, b.retrievableFurnitureId
    if idA and idB then
        return CompareId64s(idA, idB) < 0
    end
    return false
end

local function CompareAscending(a, b, key)
    local nameA, nameB = a:GetFormattedName(), b:GetFormattedName()
    local distA, distB = a:GetDistanceFromPlayerCM() or 0, b:GetDistanceFromPlayerCM() or 0

    if key == KEY_NAME then
        if nameA ~= nameB then return nameA < nameB end
        if distA ~= distB then return distA < distB end
    else
        if distA ~= distB then return distA < distB end
        if nameA ~= nameB then return nameA < nameB end
    end
    -- Stable final order so equal entries don't jitter on the frequent distance re-sorts.
    return TieBreak(a, b)
end

local function InstallSortOverride(panel)
    panel.CompareFurnitureEntries = function(_, a, b)
        -- Path nodes keep the native ordering (by path index).
        if a:GetDataType() ~= ZO_RECALLABLE_HOUSING_DATA_TYPE or b:GetDataType() ~= ZO_RECALLABLE_HOUSING_DATA_TYPE then
            return a:CompareTo(b)
        end

        if sv.sortOrder == ZO_SORT_ORDER_UP then
            return CompareAscending(a, b, sv.sortKey)
        else
            return CompareAscending(b, a, sv.sortKey)
        end
    end
end

--------------------------------------------------------------------------------
-- Sort headers
--------------------------------------------------------------------------------

local function CreateSortHeaders(panel)
    local contents = panel.contents
    local list = contents:GetNamedChild("List")
    local categoryList = contents:GetNamedChild("CategoryList")

    -- Push the list down to make room for the header row.
    list:ClearAnchors()
    list:SetAnchor(TOPLEFT, categoryList, TOPRIGHT, 0, 5 + HEADER_HEIGHT)
    list:SetAnchor(BOTTOMRIGHT, contents, BOTTOMRIGHT, -12, 0)

    local baseName = contents:GetName() .. "SHT"
    local headers = WINDOW_MANAGER:CreateControl(baseName .. "Headers", contents, CT_CONTROL)
    headers:SetHeight(HEADER_HEIGHT)
    headers:SetAnchor(BOTTOMLEFT, list, TOPLEFT, 0, 0)
    headers:SetAnchor(BOTTOMRIGHT, list, TOPRIGHT, -ZO_SCROLL_BAR_WIDTH, 0)

    local nameHeader = CreateControlFromVirtual(baseName .. "HeaderName", headers, "ZO_SortHeader")
    nameHeader:SetDimensions(200, HEADER_HEIGHT)
    nameHeader:SetAnchor(LEFT, headers, LEFT, NAME_COLUMN_X, 0)
    ZO_SortHeader_Initialize(nameHeader, "Name", KEY_NAME, ZO_SORT_ORDER_UP, TEXT_ALIGN_LEFT, "ZoFontHeader")

    local distanceHeader = CreateControlFromVirtual(baseName .. "HeaderDistance", headers, "ZO_SortHeader")
    distanceHeader:SetDimensions(120, HEADER_HEIGHT)
    distanceHeader:SetAnchor(RIGHT, headers, RIGHT, -DISTANCE_COLUMN_RIGHT_INSET, 0)
    ZO_SortHeader_Initialize(distanceHeader, "Distance", KEY_DISTANCE, ZO_SORT_ORDER_UP, TEXT_ALIGN_RIGHT, "ZoFontHeader")

    local SHOW_ARROWS = true
    local group = ZO_SortHeaderGroup:New(headers, SHOW_ARROWS)
    group:AddHeadersFromContainer()
    group:SelectHeaderByKey(sv.sortKey, ZO_SortHeaderGroup.SUPPRESS_CALLBACKS, ZO_SortHeaderGroup.FORCE_RESELECT, sv.sortOrder)

    group:RegisterCallback(ZO_SortHeaderGroup.HEADER_CLICKED, function(key, order)
        sv.sortKey = key
        sv.sortOrder = order
        panel:UpdateContentsSort()
    end)
end

--------------------------------------------------------------------------------
-- Bound furnishings -> Furnishing Vault
--------------------------------------------------------------------------------

-- Returns BAG_FURNITURE_VAULT if this put-away should be redirected there, nil otherwise.
local function GetBoundRedirectBag(furnitureId)
    if not sv.boundToVault or not furnitureId then return nil end
    if HousingEditorGetRetrieveToBag() == BAG_FURNITURE_VAULT then return nil end

    local itemLink = GetPlacedFurnitureLink(furnitureId)
    if not itemLink or itemLink == "" or not IsItemLinkBound(itemLink) then
        return nil -- collectible furnishings (no item link) go back to collections anyway
    end

    local vaultInfo = HOUSING_FURNITURE_RETRIEVE_TO_KEYBOARD and HOUSING_FURNITURE_RETRIEVE_TO_KEYBOARD:GetBagInfo(BAG_FURNITURE_VAULT)
    if not (vaultInfo and vaultInfo:IsEnabled()) then
        return nil -- no ESO+ / vault not unlocked: fall back to the selected bag
    end
    return BAG_FURNITURE_VAULT
end

local function CallWithRetrieveToBag(furnitureId, func, ...)
    local redirectBag = GetBoundRedirectBag(furnitureId)
    if not redirectBag then
        return func(...)
    end
    local previousBag = HousingEditorGetRetrieveToBag()
    HousingEditorSetRetrieveToBag(redirectBag)
    local result = func(...)
    HousingEditorSetRetrieveToBag(previousBag)
    return result
end

local function InstallBoundToVault()
    -- Covers every put-away path: list keybind / right-click (by id) and the in-world
    -- editor keybind on a picked-up item (selected), keyboard and gamepad alike.
    local originalRemoveFurniture = HousingEditorRequestRemoveFurniture
    HousingEditorRequestRemoveFurniture = function(furnitureId, ...)
        return CallWithRetrieveToBag(furnitureId, originalRemoveFurniture, furnitureId, ...)
    end

    local originalRemoveSelected = HousingEditorRequestRemoveSelectedFurniture
    HousingEditorRequestRemoveSelectedFurniture = function(...)
        return CallWithRetrieveToBag(HousingEditorGetSelectedFurnitureId(), originalRemoveSelected, ...)
    end
end

--------------------------------------------------------------------------------
-- UI helpers
--------------------------------------------------------------------------------

local function ShowTextTooltip(control, text)
    InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -5)
    SetTooltipText(InformationTooltip, text)
end

local function HideTextTooltip()
    ClearTooltip(InformationTooltip)
end

-- Checkbox + clickable label; labelSide is LEFT or RIGHT of the box.
local function CreateLabeledCheckbox(name, parent, text, tooltip, labelSide, initialState, onToggle)
    local checkbox = CreateControlFromVirtual(name, parent, "ZO_CheckButton")
    local label = WINDOW_MANAGER:CreateControl(name .. "Text", parent, CT_LABEL)
    label:SetFont("ZoFontGame")
    label:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    label:SetText(text)
    label:SetMouseEnabled(true)
    if labelSide == LEFT then
        label:SetAnchor(RIGHT, checkbox, LEFT, -6, 0)
    else
        label:SetAnchor(LEFT, checkbox, RIGHT, 6, 0)
    end

    ZO_CheckButton_SetCheckState(checkbox, initialState)
    ZO_CheckButton_SetToggleFunction(checkbox, function(_, checked) onToggle(checked) end)
    label:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            ZO_CheckButton_OnClicked(checkbox)
        end
    end)

    local function OnEnter(control) ShowTextTooltip(control, tooltip) end
    for _, control in ipairs({ checkbox, label }) do
        control:SetHandler("OnMouseEnter", OnEnter)
        control:SetHandler("OnMouseExit", HideTextTooltip)
    end

    return checkbox, label
end

--------------------------------------------------------------------------------
-- Right-click -> store (put away to the Retrieve To bag)
--------------------------------------------------------------------------------

local function InstallRightClickStore(panel)
    -- Row setup reads panel.RetrievableFurnitureOnMouseClick each time a row is set up,
    -- so replacing it here applies to every row.
    local originalOnMouseClick = panel.RetrievableFurnitureOnMouseClick
    panel.RetrievableFurnitureOnMouseClick = function(control, buttonIndex, upInside)
        if buttonIndex == MOUSE_BUTTON_INDEX_RIGHT and sv.rightClickStore then
            if upInside and HOUSING_EDITOR_STATE:IsLocalPlayerHouseOwner() then
                local data = ZO_ScrollList_GetData(control)
                -- Path nodes are deliberately ignored (removing one is not "storing").
                if data and data:GetDataType() == ZO_RECALLABLE_HOUSING_DATA_TYPE then
                    ZO_HousingFurnitureBrowser_Base.PutAwayFurniture(data)
                end
            end
            return
        end
        return originalOnMouseClick(control, buttonIndex, upInside)
    end
end

--------------------------------------------------------------------------------
-- Layout: right-click toggle next to the filters, Retrieve To in the list footer
--------------------------------------------------------------------------------

local function DockRetrieveTo(panel)
    local retrieveTo = HOUSING_FURNITURE_RETRIEVE_TO_KEYBOARD
    local topLevel = ZO_HousingFurnitureRetrieveTo_TopLevel
    if not (retrieveTo and topLevel) then return end

    -- Grab the combo box while it is still a child of its original top level.
    retrieveTo:DeferredInitializeControls()
    local bagControl = retrieveTo.bagDropdownControl
    local bagComboBox = retrieveTo.bagComboBox

    -- Keep the original fragment (it drives the bag list refreshes) but make the
    -- floating top-left box empty and invisible.
    topLevel:GetNamedChild("BG"):SetHidden(true)
    topLevel:GetNamedChild("Title"):SetHidden(true)

    local contents = panel.contents
    local infoBar = contents:GetNamedChild("InfoBar")
    local freeSlotsLabel = infoBar:GetNamedChild("FreeSlots")
    local baseName = contents:GetName() .. "SHT"

    local caption = WINDOW_MANAGER:CreateControl(baseName .. "RetrieveToCaption", infoBar, CT_LABEL)
    caption:SetFont("ZoFontGameLargeBold")
    caption:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    caption:SetText(zo_strformat("<<1>>:", GetString(SI_HOUSING_EDITOR_RETRIEVE_TO)))
    caption:SetAnchor(LEFT, freeSlotsLabel, LEFT, 0, 0)

    bagControl:SetParent(infoBar)
    bagControl:ClearAnchors()
    bagControl:SetAnchor(LEFT, caption, RIGHT, 8, 0)
    -- Fixed width so the checkbox next to it does not jump when the bag changes.
    bagControl:SetDimensionConstraints(200, 0, 200, 0)

    -- The footer sits at the bottom of the screen: open the bag list upwards.
    local originalAddMenuItems = bagComboBox.AddMenuItems
    bagComboBox.AddMenuItems = function(comboBox, ...)
        originalAddMenuItems(comboBox, ...)
        local dropdownControl = comboBox.m_dropdownObject.control
        dropdownControl:ClearAnchors()
        dropdownControl:SetAnchor(BOTTOMLEFT, comboBox:GetContainer(), TOPLEFT)
    end

    -- Bag entry tooltips (e.g. "requires ESO+") were anchored to the old top level.
    retrieveTo.OnBagEntryMouseEnter = function(_, _, entryControl)
        local tooltipText = entryControl.m_data.bagInfo:GetTooltipText()
        if tooltipText then
            InitializeTooltip(InformationTooltip, entryControl, LEFT, 15, 0, RIGHT)
            SetTooltipText(InformationTooltip, tooltipText)
        else
            ClearTooltip(InformationTooltip)
        end
    end

    local boundCheckbox, boundLabel = CreateLabeledCheckbox(baseName .. "BoundToVault", infoBar,
        "Bound items to Vault",
        "Bound furnishings always go to the Furnishing Vault when put away; everything else goes to the selected bag.\n\nIgnored if the Furnishing Vault is unavailable (ESO+ and the vault collectible are required).",
        RIGHT, sv.boundToVault, function(checked) sv.boundToVault = checked end)
    boundCheckbox:SetAnchor(LEFT, bagControl, RIGHT, 16, 0)

    return { caption, bagControl, boundCheckbox, boundLabel }, freeSlotsLabel
end

local function CreateTopRowToggle(panel)
    local contents = panel.contents
    local dropdown = contents:GetNamedChild("FiltersDropdown")
    local checkbox, label = CreateLabeledCheckbox(contents:GetName() .. "SHTRightClickStore", contents,
        "Right-click to store",
        "Right-click a furnishing in the list to put it away into the \"Retrieve To\" bag shown below the list (bound furnishings to the Furnishing Vault if that option is on).",
        LEFT, sv.rightClickStore, function(checked) sv.rightClickStore = checked end)
    checkbox:SetAnchor(RIGHT, dropdown, LEFT, -12, 0)
    return { checkbox, label }
end

local function SetHidden(controls, hidden)
    for _, control in ipairs(controls) do
        control:SetHidden(hidden)
    end
end

local function InstallLayout(panel)
    local topRowControls = CreateTopRowToggle(panel)
    local footerControls, freeSlotsLabel = DockRetrieveTo(panel)

    -- RefreshFilters runs on every OnShowing of the panel.
    ZO_PostHook(panel, "RefreshFilters", function()
        local isOwner = HOUSING_EDITOR_STATE:IsLocalPlayerHouseOwner()
        SetHidden(topRowControls, not isOwner or HOUSING_EDITOR_STATE:IsHousePreview())

        if footerControls then
            -- Retrieve To only exists for the owner; otherwise keep the stock backpack line.
            SetHidden(footerControls, not isOwner)
            freeSlotsLabel:SetHidden(isOwner)
            if isOwner then
                -- Populate the combo box now instead of after the fragment fade-in.
                HOUSING_FURNITURE_RETRIEVE_TO_KEYBOARD:RefreshBags()
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- Emptied category -> select the next non-empty one (or the previous), not the first
--------------------------------------------------------------------------------

-- Leaf categories of the current (pre-rebuild) tree, in display order,
-- plus the index of the selected one.
local function SnapshotLeafCategories(list)
    local tree = list.categoryTree
    local selectedNode = tree:GetSelectedNode()
    local leaves, selectedIndex = {}, nil

    tree:ExecuteOnSubTree(nil, function(node)
        if node:IsLeaf() then
            local data = node:GetData()
            if data then
                local entry
                if data.parentData then
                    entry = { categoryId = data.parentData.categoryId, subCategoryId = data.categoryId }
                else
                    entry = { categoryId = data.categoryId }
                end
                leaves[#leaves + 1] = entry
                if node == selectedNode then
                    selectedIndex = #leaves
                end
            end
        end
    end)

    return leaves, selectedIndex
end

local function InstallKeepCategoryPosition(list)
    if not (list and list.categoryTree) then return end

    local originalBuildCategories = list.BuildCategories
    list.BuildCategories = function(self, ...)
        local leaves, selectedIndex = SnapshotLeafCategories(self)
        if not selectedIndex then
            return originalBuildCategories(self, ...)
        end

        -- BuildCategories looks up the previously selected category once via
        -- GetCategoryData; when that category no longer exists it would fall back
        -- to the first node. Answer that lookup with the nearest surviving neighbour.
        local hadOwnGetCategoryData = rawget(self, "GetCategoryData")
        local originalGetCategoryData = self.GetCategoryData
        self.GetCategoryData = function(innerSelf, categoryId, subCategoryId)
            local node = originalGetCategoryData(innerSelf, categoryId, subCategoryId)
            if node then
                return node
            end
            for i = selectedIndex + 1, #leaves do
                node = originalGetCategoryData(innerSelf, leaves[i].categoryId, leaves[i].subCategoryId)
                if node then return node end
            end
            for i = selectedIndex - 1, 1, -1 do
                node = originalGetCategoryData(innerSelf, leaves[i].categoryId, leaves[i].subCategoryId)
                if node then return node end
            end
            return nil
        end

        local results = { originalBuildCategories(self, ...) }

        if hadOwnGetCategoryData then
            self.GetCategoryData = hadOwnGetCategoryData
        else
            self.GetCategoryData = nil -- back to the class method
        end
        return unpack(results)
    end
end

--------------------------------------------------------------------------------

function SHT.InitializeHousingEditor(savedVars)
    sv = savedVars

    local browser = KEYBOARD_HOUSING_FURNITURE_BROWSER
    local panel = browser and browser.retrievalPanel
    if not panel then return end

    InstallSortOverride(panel)
    CreateSortHeaders(panel)
    InstallRightClickStore(panel)
    InstallBoundToVault()
    InstallLayout(panel)

    -- NOT the Products (Crown Store) panel: its rows call private market functions
    -- (GetMarketProductPricingByPresentation etc.), and running BuildCategories
    -- through addon code taints the call stack -> "private function from insecure code".
    InstallKeepCategoryPosition(browser.placeablePanel)
    InstallKeepCategoryPosition(browser.retrievalPanel)
end
