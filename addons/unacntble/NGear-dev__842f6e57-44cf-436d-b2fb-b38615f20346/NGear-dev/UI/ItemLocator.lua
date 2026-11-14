NGear = NGear or {}

local ItemLocator = NGear.ItemLocator
local C = {
    SEARCH_DIALOG = "NGear_ITEM_LOCATOR_SEARCH",
    SORT_ALPHABETICAL = 1,
    SORT_QUALITY = 2,
    DRAW_LEVEL = 300,
    PADDING = 28,
    SCREEN_TOP_MARGIN = 16,
    SCREEN_FOOTER_GAP = 8,
    HEADER_HEIGHT = 76,
    TAB_HEIGHT = 46,
    TAB_GAP = 4,
    MAX_TABS = 64,
    TAB_COLUMNS = 2,
    MIN_TAB_ROWS = 5,
    PANE_HEADER_HEIGHT = 42,
    PANE_HEADER_OFFSET = 8,
    PANE_GAP = 24,
    DETAIL_TOP_OFFSET = 104,
    DETAIL_BOTTOM_PADDING = 12,
    DETAIL_MEASURE_HEIGHT = 4096,
    DETAIL_LINE_HEIGHT = 28,
    DETAIL_HINT_HEIGHT = 44,
    FOOTER_HEIGHT = 52,
    ROW_HEIGHT = 48,
    ROW_GAP = 4,
    MAX_ROWS = 32,
    INPUT_DEADZONE = 0.34,
    INPUT_INITIAL_DELAY_MS = 330,
    INPUT_REPEAT_DELAY_MS = 95,
    CATEGORY_INITIAL_DELAY_MS = 250,
    CATEGORY_REPEAT_DELAY_MS = 65,
    CATEGORY_REPEAT_POLL_MS = 16,
    CATEGORY_REPEAT_UPDATE = "NGear_ItemLocator_CategoryRepeat",
    CONSUMABLE_ABILITY_ICON_UP = "EsoUI/Art/Inventory/inventory_tabIcon_consumables_up.dds",
    CONSUMABLE_ABILITY_ICON_DOWN = "EsoUI/Art/Inventory/inventory_tabIcon_consumables_down.dds",
}

local COLORS = {
    panel = { 0.035, 0.055, 0.085, 0.94 },
    panelAlt = { 0.055, 0.080, 0.120, 0.78 },
    selected = { 0.070, 0.310, 0.520, 0.96 },
    accent = { 0.300, 0.760, 1.000, 1 },
    text = { 0.940, 0.970, 1.000, 1 },
    muted = { 0.630, 0.720, 0.820, 1 },
    divider = { 0.250, 0.480, 0.680, 0.7 },
}

local FONT_SIZES = {
    ZoFontGamepad18 = 18,
    ZoFontGamepad22 = 22,
    ZoFontGamepad27 = 27,
    ZoFontGamepadBold22 = 22,
    ZoFontGamepadBold34 = 34,
}

local ui
local hudVisible = false
local keybindsActive = false
local searchDialogOpen = false
local dialogsRegistered = false
local searchText = ""
local searchNeedle = ""
local sortMode = C.SORT_ALPHABETICAL
local records = {}
local filtered = {}
local listEntries = {}
local recordEntryIndices = {}
local categories = {}
local selectedByCategory = {}
local detailLines = {}
local chatCounts = {}
local chatEntries = {}
local chatHouseCounts = {}
local chatHouseNames = {}
local chatHouseKeys = {}
local activeCategoryIndex = 1
local selectedIndex = 1
local visibleFirstIndex = 1
local EnsureTab
local LayoutUI
local HideBrowser
local fontStringCache = {}

local function IsBrowserVisible()
    return hudVisible and ui and ui.control and not ui.control:IsHidden()
end

local function Clear(values)
    for key in pairs(values) do values[key] = nil end
end

local function SetColor(control, color)
    control:SetColor(color[1], color[2], color[3], color[4] or 1)
end

local function SetBackdropColor(control, color)
    control:SetCenterColor(color[1], color[2], color[3], color[4] or 1)
    control:SetEdgeColor(COLORS.divider[1], COLORS.divider[2], COLORS.divider[3], COLORS.divider[4])
end

local function ResolveFont(font)
    local size = FONT_SIZES[font]
    if not size or not ItemLocator.GetFont then return font end
    local fontPath = ItemLocator.GetFont()
    local key = tostring(fontPath) .. "|" .. tostring(size)
    if not fontStringCache[key] then
        fontStringCache[key] = string.format("%s|%d|soft-shadow-thin", fontPath, size)
    end
    return fontStringCache[key]
end

local function SetLabelFont(label, font)
    label.ngearFont = font
    label:SetFont(ResolveFont(font))
end

local function CreateLabel(parent, font, color, alignment)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    SetLabelFont(label, font)
    label:SetHorizontalAlignment(alignment or TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    SetColor(label, color or COLORS.text)
    label:SetDrawLevel(C.DRAW_LEVEL + 4)
    return label
end

local function CreateBackdrop(parent, color)
    local backdrop = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
    SetBackdropColor(backdrop, color)
    backdrop:SetDrawLevel(C.DRAW_LEVEL + 1)
    return backdrop
end

local function GetFurnitureVaultName()
    if ItemLocator.GetFurnitureVaultName then return ItemLocator.GetFurnitureVaultName() end
    if GetString and SI_GAMEPAD_INVENTORY_STACK_COUNT_BAG_FURNITURE_VAULT then
        local name = GetString(SI_GAMEPAD_INVENTORY_STACK_COUNT_BAG_FURNITURE_VAULT)
        if name and name ~= "" then return name end
    end
    return NGear.L("item_locator.furniture_vault")
end

local function GetCraftBagName()
    if ItemLocator.GetCraftBagName then return ItemLocator.GetCraftBagName() end
    if GetString and SI_GAMEPAD_INVENTORY_CRAFT_BAG_HEADER then
        local name = GetString(SI_GAMEPAD_INVENTORY_CRAFT_BAG_HEADER)
        if name and name ~= "" then return name end
    end
    return NGear.L("item_locator.craft_bag")
end

local function GetSelectedRecord()
    return filtered[selectedIndex]
end

local function GetActiveCategory()
    return categories[activeCategoryIndex]
end

local function GetCategoryIconPaths(itemLink)
    local icons
    local itemType, specializedItemType = 0, 0
    if GetItemLinkItemType then itemType, specializedItemType = GetItemLinkItemType(itemLink) end
    -- ESO's specialized Skill Scroll filter icons reference textures that are absent on console.
    if ITEMTYPE_CONSUMABLE_ABILITY and itemType == ITEMTYPE_CONSUMABLE_ABILITY then
        return C.CONSUMABLE_ABILITY_ICON_UP, C.CONSUMABLE_ABILITY_ICON_DOWN
    end
    local filterUtils = ZO_ItemFilterUtils
    if type(filterUtils) == "table" then
        if ITEMTYPE_WEAPON and itemType == ITEMTYPE_WEAPON and filterUtils.GetWeaponTypeFilterIcons then
            local weaponType = GetItemLinkWeaponType and GetItemLinkWeaponType(itemLink) or 0
            icons = filterUtils.GetWeaponTypeFilterIcons(weaponType)
        elseif ITEMTYPE_ARMOR and itemType == ITEMTYPE_ARMOR and filterUtils.GetEquipTypeFilterIcons then
            local equipType = GetItemLinkEquipType and GetItemLinkEquipType(itemLink) or 0
            icons = filterUtils.GetEquipTypeFilterIcons(equipType)
        end
        if not icons and filterUtils.GetItemTypeFilterIcons then
            icons = filterUtils.GetItemTypeFilterIcons(itemType)
        end
        if not icons and filterUtils.GetSpecializedItemTypeFilterIcons then
            icons = filterUtils.GetSpecializedItemTypeFilterIcons(specializedItemType)
        end
    end

    if type(icons) == "table" then
        local up = icons.up or icons.over or icons.down
        local down = icons.down or icons.over or icons.up
        if up or down then return up or down, down or up end
    end
    local fallback = GetItemLinkIcon and GetItemLinkIcon(itemLink) or ""
    return fallback, fallback
end

local function PopulateActiveCategory(preferredId)
    Clear(filtered)
    Clear(listEntries)
    Clear(recordEntryIndices)

    local category = GetActiveCategory()
    if category then
        for index = 1, #category.records do
            local record = category.records[index]
            filtered[index] = record
            listEntries[index] = record
            recordEntryIndices[record.id] = index
        end
    end

    selectedIndex = 1
    if preferredId then
        for index = 1, #filtered do
            if filtered[index].id == preferredId then
                selectedIndex = index
                break
            end
        end
    end
    visibleFirstIndex = math.max(selectedIndex - 1, 1)
end

local function BuildFilteredRecords(preferredId, preferredCategory)
    Clear(categories)
    local category

    for index = 1, #records do
        local record = records[index]
        if searchNeedle == "" or string.find(record.needle, searchNeedle, 1, true) then
            if not category or category.label ~= record.category then
                local iconUp, iconDown = GetCategoryIconPaths(record.link)
                category = { label = record.category, records = {}, iconUp = iconUp, iconDown = iconDown }
                categories[#categories + 1] = category
            end
            category.records[#category.records + 1] = record
        end
    end

    activeCategoryIndex = 1
    local foundPreferredId = false
    if preferredId then
        for categoryIndex = 1, #categories do
            local candidate = categories[categoryIndex]
            for recordIndex = 1, #candidate.records do
                if candidate.records[recordIndex].id == preferredId then
                    activeCategoryIndex = categoryIndex
                    foundPreferredId = true
                    break
                end
            end
            if foundPreferredId then break end
        end
    end
    if not foundPreferredId and preferredCategory then
        for categoryIndex = 1, #categories do
            if categories[categoryIndex].label == preferredCategory then
                activeCategoryIndex = categoryIndex
                break
            end
        end
    end
    PopulateActiveCategory(preferredId or (GetActiveCategory() and selectedByCategory[GetActiveCategory().label]))
end

local function SortBrowserRecords()
    table.sort(records, function(left, right)
        local leftCategory = NGear.Util.Lower(left.category)
        local rightCategory = NGear.Util.Lower(right.category)
        if leftCategory ~= rightCategory then return leftCategory < rightCategory end
        if sortMode == C.SORT_QUALITY and left.quality ~= right.quality then
            return left.quality > right.quality
        end
        if left.needle ~= right.needle then return left.needle < right.needle end
        return left.id < right.id
    end)
end

local function RemoveHiddenCategories()
    local writeIndex = 1
    for readIndex = 1, #records do
        local record = records[readIndex]
        if ItemLocator.IsCategoryVisible(record.categoryKey) then
            records[writeIndex] = record
            writeIndex = writeIndex + 1
        end
    end
    for index = #records, writeIndex, -1 do records[index] = nil end
end

local function AddDetailLine(label, value)
    if value == nil or value == "" then return end
    detailLines[#detailLines + 1] = NGear.L("item_locator.detail_line", label, tostring(value))
end

local function FormatMarketPrice(value)
    value = math.max(math.floor((tonumber(value) or 0) + 0.5), 0)
    if ZO_CurrencyControl_FormatCurrencyAndAppendIcon and CURT_MONEY then
        return ZO_CurrencyControl_FormatCurrencyAndAppendIcon(value, false, CURT_MONEY, true)
    end
    local formatted = ZO_CommaDelimitNumber and ZO_CommaDelimitNumber(value) or tostring(value)
    return string.format("%s |t20:20:EsoUI/Art/currency/currency_gold.dds|t", formatted)
end

local function AddMarketPrices(itemLink)
    if type(ItemLocator.GetMarketPriceData) ~= "function" then return end
    local minimum, average, maximum = ItemLocator.GetMarketPriceData(itemLink)
    if not minimum then return end

    detailLines[#detailLines + 1] = ""
    detailLines[#detailLines + 1] = "|c72BEEB" .. NGear.L("item_locator.market_prices") .. "|r"
    AddDetailLine(NGear.L("item_locator.price_minimum"), FormatMarketPrice(minimum))
    AddDetailLine(NGear.L("item_locator.price_average"), FormatMarketPrice(average))
    AddDetailLine(NGear.L("item_locator.price_maximum"), FormatMarketPrice(maximum))
end

local function BuildLocationText(record)
    Clear(detailLines)
    local itemLink = record.link
    local itemType, specializedItemType = GetItemLinkItemType(itemLink)
    AddDetailLine(NGear.L("item_locator.type"), GetString("SI_ITEMTYPE", itemType))
    if specializedItemType and specializedItemType ~= 0 then
        AddDetailLine(NGear.L("item_locator.category"), GetString("SI_SPECIALIZEDITEMTYPE", specializedItemType))
    end
    local armorType = GetItemLinkArmorType and GetItemLinkArmorType(itemLink) or 0
    local armorColor
    if ARMORTYPE_HEAVY and armorType == ARMORTYPE_HEAVY then
        armorColor = "FF5555"
    elseif ARMORTYPE_MEDIUM and armorType == ARMORTYPE_MEDIUM then
        armorColor = "60D860"
    elseif ARMORTYPE_LIGHT and armorType == ARMORTYPE_LIGHT then
        armorColor = "4FA8FF"
    end
    if armorColor then
        AddDetailLine(
            NGear.L("item_locator.weight"),
            string.format("|c%s%s|r", armorColor, GetString("SI_ARMORTYPE", armorType))
        )
    end
    local traitType = GetItemLinkTraitType and GetItemLinkTraitType(itemLink) or 0
    if traitType and traitType ~= 0 then
        AddDetailLine(NGear.L("item_locator.trait"), GetString("SI_ITEMTRAITTYPE", traitType))
    end
    local level = GetItemLinkRequiredLevel and GetItemLinkRequiredLevel(itemLink) or 0
    local championPoints = GetItemLinkRequiredChampionPoints and GetItemLinkRequiredChampionPoints(itemLink) or 0
    if championPoints and championPoints > 0 then
        AddDetailLine(NGear.L("item_locator.level"), NGear.L("item_locator.champion_level", championPoints))
    elseif level and level > 0 then
        AddDetailLine(NGear.L("item_locator.level"), tostring(level))
    end
    local styleId = GetItemLinkItemStyle and GetItemLinkItemStyle(itemLink) or 0
    if styleId and styleId > 0 and GetItemStyleName then
        AddDetailLine(NGear.L("item_locator.style"), GetItemStyleName(styleId))
    end
    local flags = tonumber(record.flags) or 0
    local bindType = math.floor(flags / 4)
    local isBound = flags % 2 == 1
    if isBound and BIND_TYPE_ON_PICKUP_BACKPACK and bindType == BIND_TYPE_ON_PICKUP_BACKPACK then
        AddDetailLine(NGear.L("item_locator.binding"), GetString(SI_ITEM_FORMAT_STR_BACKPACK_BOUND))
    elseif isBound then
        AddDetailLine(NGear.L("item_locator.binding"), GetString(SI_ITEM_FORMAT_STR_BOUND))
    elseif BIND_TYPE_NONE and BIND_TYPE_UNSET and bindType ~= BIND_TYPE_NONE and bindType ~= BIND_TYPE_UNSET then
        AddDetailLine(NGear.L("item_locator.binding"), GetString("SI_BINDTYPE", bindType))
    end
    if math.floor(flags / 2) % 2 == 1 then
        AddDetailLine(NGear.L("item_locator.status"), NGear.L("item_locator.stolen"))
    end
    if GetItemLinkSetInfo then
        local hasSet, setName = GetItemLinkSetInfo(itemLink, false)
        if hasSet then AddDetailLine(NGear.L("common.item_set"), setName) end
    end
    if GetItemLinkEnchantInfo then
        local _, enchantHeader = GetItemLinkEnchantInfo(itemLink)
        AddDetailLine(NGear.L("item_locator.enchantment"), enchantHeader)
    end

    AddMarketPrices(itemLink)
    detailLines[#detailLines + 1] = ""
    detailLines[#detailLines + 1] = "|c72BEEB" .. NGear.L("item_locator.locations") .. "|r"
    local locations = record.locations
    for index = 1, #locations, 4 do
        local characterName, kind = locations[index], locations[index + 1]
        local count = locations[index + 2]
        if kind == "b" then
            detailLines[#detailLines + 1] = NGear.L("item_locator.location_inventory", characterName, count)
        elseif kind == "w" then
            detailLines[#detailLines + 1] = NGear.L("item_locator.location_equipped", characterName, count)
        elseif kind == "k" then
            detailLines[#detailLines + 1] = NGear.L("item_locator.location_bank", count)
        elseif kind == "m" then
            detailLines[#detailLines + 1] = NGear.L("item_locator.location_storage", GetCraftBagName(), count)
        elseif kind == "f" then
            detailLines[#detailLines + 1] = NGear.L("item_locator.location_storage", GetFurnitureVaultName(), count)
        elseif type(kind) == "string" and string.sub(kind, 1, 1) == "h" then
            detailLines[#detailLines + 1] = NGear.L("item_locator.location_storage", characterName, count)
        end
    end
    return table.concat(detailLines, "\n")
end

local function ApplyQualityColor(label, quality)
    if GetItemQualityColor then
        local color = GetItemQualityColor(quality)
        if color and color.UnpackRGB then
            local red, green, blue = color:UnpackRGB()
            label:SetColor(red, green, blue, 1)
            return
        end
    end
    SetColor(label, COLORS.text)
end

local function ReleaseItemIcon()
    if not ui or not ui.itemIcon then return end
    NGear.Util.ReleaseContentTexture(ui.itemIcon)
    ui.currentItemIconPath = nil
end

local function ResetDetailInput()
    if not ui then return end
    ui.detailSortHeld, ui.detailScrollUsed, ui.detailScrollReleasePending = false, false, false
    ui.inputDirection, ui.nextInputAt = 0, 0
end

local function ApplyDetailOffset()
    ui.detailScrollOffset = NGear.Util.Clamp(ui.detailScrollOffset or 0, 0, ui.detailScrollMaximum or 0)
    ui.detailScrollViewport:SetVerticalScroll(ui.detailScrollOffset)
end

local function ScrollDetails(direction)
    -- Even a gesture at the boundary consumes the held click; releasing it must not sort.
    ui.detailScrollUsed = true
    ui.detailScrollOffset = (ui.detailScrollOffset or 0) + direction * C.DETAIL_LINE_HEIGHT
    ApplyDetailOffset()
end

local function RenderDetails(record)
    local selectedId = record and record.id
    if ui.detailRecordId ~= selectedId then
        ui.detailScrollOffset = 0
        ui.detailRecordId = selectedId
    end
    if not record then
        ReleaseItemIcon()
        ui.detailContentHeight, ui.detailMinimumHeight, ui.detailScrollMaximum = 0, 0, 0
        ui.detailScrollViewport:SetHidden(true)
        ui.detailScrollHint:SetHidden(true)
        ui.detailEmpty:SetText(NGear.L("item_locator.no_selection"))
        ui.detailEmpty:SetHidden(false)
        ui.itemName:SetHidden(true)
        ui.itemMeta:SetHidden(true)
        ui.details:SetHidden(true)
        ui.details:SetText("")
        return
    end
    ui.detailEmpty:SetHidden(true)
    ui.detailScrollViewport:SetHidden(false)
    local icon = GetItemLinkIcon and GetItemLinkIcon(record.link) or ""
    if icon ~= "" then
        if ui.currentItemIconPath ~= icon then
            ui.currentItemIconPath = icon
            NGear.Util.LoadContentTexture(ui.itemIcon, icon)
        elseif not ui.itemIcon.IsTextureLoaded or ui.itemIcon:IsTextureLoaded() then
            ui.itemIcon:SetHidden(false)
            ui.itemIconFrame:SetHidden(false)
        end
    else
        ReleaseItemIcon()
    end
    ui.itemName:SetHidden(false)
    ui.itemName:SetText(record.name)
    ApplyQualityColor(ui.itemName, record.quality)
    ui.itemMeta:SetHidden(false)
    ui.itemMeta:SetText(NGear.L("item_locator.variant_total", record.total))
    ui.details:SetHidden(false)
    local detailText = BuildLocationText(record)
    ui.details:SetHeight(C.DETAIL_MEASURE_HEIGHT)
    ui.details:SetText(detailText)
    local measuredHeight = ui.details.GetTextHeight and math.ceil(ui.details:GetTextHeight()) or 0
    local lineCount = 1
    for _ in string.gmatch(detailText, "\n") do lineCount = lineCount + 1 end
    ui.detailMinimumHeight = lineCount * C.DETAIL_LINE_HEIGHT
    ui.detailContentHeight = math.max(measuredHeight, ui.detailMinimumHeight)
end

local function KeepSelectionVisible()
    local record = GetSelectedRecord()
    local entryIndex = record and recordEntryIndices[record.id] or 1
    local visibleRows = ui.visibleRows or C.MAX_ROWS
    if entryIndex < visibleFirstIndex then
        visibleFirstIndex = entryIndex
    elseif entryIndex >= visibleFirstIndex + visibleRows then
        visibleFirstIndex = entryIndex - visibleRows + 1
    end
    visibleFirstIndex = NGear.Util.Clamp(visibleFirstIndex, 1, math.max(#listEntries - visibleRows + 1, 1))
end

local function GetFirstVisibleCategoryIndex()
    local categoryCount = #categories
    local visibleLimit = ui.visibleTabs or C.MAX_TABS
    return NGear.Util.Clamp(
        activeCategoryIndex - math.floor(visibleLimit / 2),
        1,
        math.max(categoryCount - visibleLimit + 1, 1)
    )
end

local function RenderTabs()
    local categoryCount = #categories
    local visibleLimit = ui.visibleTabs or C.MAX_TABS
    local visibleCount = math.min(categoryCount, visibleLimit)
    local firstIndex = GetFirstVisibleCategoryIndex()
    for tabIndex = 1, visibleCount do EnsureTab(tabIndex) end
    local tabBarWidth = ui.tabBarWidth or 1
    local tabColumns = ui.visibleTabColumns or C.TAB_COLUMNS
    local tabWidth = math.floor((tabBarWidth - (C.TAB_GAP * (tabColumns - 1))) / tabColumns)
    local tabHeight = ui.tabHeight or C.TAB_HEIGHT

    for tabIndex = 1, #ui.tabs do
        local tab = ui.tabs[tabIndex]
        local categoryIndex = firstIndex + tabIndex - 1
        local category = tabIndex <= visibleCount and categories[categoryIndex] or nil
        tab.control:SetHidden(category == nil)
        if category then
            local selected = categoryIndex == activeCategoryIndex
            local iconPath = selected and category.iconDown or category.iconUp
            local rowsPerColumn = ui.visibleTabRows or math.ceil(visibleLimit / C.TAB_COLUMNS)
            local columnIndex = math.floor((tabIndex - 1) / rowsPerColumn)
            local rowIndex = (tabIndex - 1) % rowsPerColumn
            tab.control:ClearAnchors()
            tab.control:SetDimensions(tabWidth, tabHeight)
            tab.control:SetAnchor(
                TOPLEFT, ui.tabBar, TOPLEFT,
                columnIndex * (tabWidth + C.TAB_GAP), rowIndex * (tabHeight + C.TAB_GAP)
            )
            SetBackdropColor(tab.background, selected and COLORS.selected or COLORS.panelAlt)
            tab.underline:SetHidden(not selected)
            if tab.currentIconPath ~= iconPath then
                tab.currentIconPath = iconPath
                tab.icon:SetTexture(iconPath ~= "" and iconPath or nil)
            end
            local iconSize = math.min(32, tabHeight - 10)
            tab.icon:SetDimensions(iconSize, iconSize)
            tab.icon:SetHidden(not iconPath or iconPath == "")
            tab.label:SetDimensions(tabWidth - 62, tabHeight)
            SetLabelFont(tab.label, selected and "ZoFontGamepadBold22" or "ZoFontGamepad22")
            SetColor(tab.label, selected and COLORS.text or COLORS.muted)
            tab.label:SetText(NGear.Util.Upper(category.label))
        elseif tab.currentIconPath then
            tab.currentIconPath = nil
            tab.icon:SetTexture(nil)
        end
    end
end

local function RenderRows()
    KeepSelectionVisible()
    local selected = GetSelectedRecord()
    for rowIndex = 1, #ui.rows do
        local row = ui.rows[rowIndex]
        local entry = listEntries[visibleFirstIndex + rowIndex - 1]
        local visible = rowIndex <= ui.visibleRows and entry ~= nil
        row.control:SetHidden(not visible)
        if visible then
            local isSelected = entry == selected
            row.background:SetHidden(false)
            SetBackdropColor(row.background, isSelected and COLORS.selected or COLORS.panelAlt)
            row.accent:SetHidden(not isSelected)
            row.name:SetHidden(false)
            row.name:SetText(entry.name)
            ApplyQualityColor(row.name, entry.quality)
            row.count:SetHidden(false)
            row.count:SetText(tostring(entry.total))
        end
    end
    ui.upArrow:SetHidden(visibleFirstIndex <= 1)
    ui.downArrow:SetHidden(visibleFirstIndex + ui.visibleRows - 1 >= #listEntries)
end

local function RenderEmptyState()
    local hasRecords = #filtered > 0
    ui.empty:SetHidden(hasRecords)
    if hasRecords then return end
    if searchText ~= "" then
        ui.empty:SetText(NGear.L("item_locator.no_search_results", searchText))
    else
        ui.empty:SetText(NGear.L("item_locator.no_items"))
    end
end

local function GetBindingIcon(actionName, fallback)
    if ZO_Keybindings_GetHighestPriorityBindingStringFromAction and KEYBIND_TEXT_OPTIONS_FULL_NAME and KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP then
        local binding = ZO_Keybindings_GetHighestPriorityBindingStringFromAction(
            actionName, KEYBIND_TEXT_OPTIONS_FULL_NAME, KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP, true, false, 100
        )
        if binding and binding ~= "" then return binding end
    end
    return fallback
end

local function GetBindingTextureIcon(actionName, fallback)
    if ZO_Keybindings_GetHighestPriorityBindingStringFromAction then
        local _, key = ZO_Keybindings_GetHighestPriorityBindingStringFromAction(
            actionName, KEYBIND_TEXT_OPTIONS_FULL_NAME, KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP, true, false, 100
        )
        if key and key ~= KEY_INVALID and GetGamepadIconPathForKeyCode and zo_iconFormat then
            local texture = GetGamepadIconPathForKeyCode(key, false)
            if texture and texture ~= "" then return zo_iconFormat(texture, 28, 28) end
        end
    end
    return fallback
end

local function GetGamepadKeyCodeIcon(keyCode, fallback)
    if keyCode and GetGamepadIconPathForKeyCode and zo_iconFormat then
        local texture = GetGamepadIconPathForKeyCode(keyCode, false)
        if texture and texture ~= "" then return zo_iconFormat(texture, 28, 28) end
    end
    return fallback
end

local function GetInputHint()
    local back = GetBindingTextureIcon("UI_SHORTCUT_NEGATIVE", "B")
    if not ItemLocator.HasData() then
        return NGear.L("item_locator.input_hint_empty", back)
    end

    local search = GetBindingIcon("UI_SHORTCUT_LEFT_STICK", "L3")
    local logInChat = GetBindingTextureIcon("UI_SHORTCUT_TERTIARY", "△")
    local sortLabel = NGear.L(sortMode == C.SORT_QUALITY and "item_locator.sort_quality" or "item_locator.sort_alphabetical")
    local sortHint = NGear.L(
        "item_locator.sort_hint",
        GetBindingIcon("UI_SHORTCUT_RIGHT_STICK", "R3"),
        sortLabel
    )
    if #filtered == 0 then
        return NGear.L("item_locator.input_hint_actions", search, sortHint, back)
    end

    local browse = NGear.L("common.right_stick")
    if GetGamepadRightStickScrollIcon and zo_iconFormat then
        browse = zo_iconFormat(GetGamepadRightStickScrollIcon(), 32, 32)
    end
    if #categories > 1 then
        if ui and ui.visibleTabColumns == C.TAB_COLUMNS then
            return NGear.L(
                "item_locator.input_hint_category_columns",
                browse,
                GetGamepadKeyCodeIcon(KEY_GAMEPAD_RSTICK_LEFT, "R←"),
                GetGamepadKeyCodeIcon(KEY_GAMEPAD_RSTICK_RIGHT, "R→"),
                GetBindingIcon("UI_SHORTCUT_LEFT_SHOULDER", "L1"),
                GetBindingIcon("UI_SHORTCUT_RIGHT_SHOULDER", "R1"),
                search,
                sortHint,
                logInChat,
                back
            )
        end
        return NGear.L(
            "item_locator.input_hint_categories",
            browse,
            GetBindingIcon("UI_SHORTCUT_LEFT_SHOULDER", "L1"),
            GetBindingIcon("UI_SHORTCUT_RIGHT_SHOULDER", "R1"),
            search,
            sortHint,
            logInChat,
            back
        )
    end
    return NGear.L("item_locator.input_hint_items", browse, search, sortHint, logInChat, back)
end

local function RefreshHeader()
    local totalItems = 0
    for index = 1, #records do totalItems = totalItems + records[index].total end
    ui.title:SetText(searchText ~= "" and NGear.L("item_locator.title_search", searchText) or NGear.L("item_locator.title"))
    ui.summary:SetText(NGear.L("item_locator.summary", totalItems, #records))
    ui.leftHeader:SetText(NGear.L("item_locator.items"))
    ui.rightHeader:SetText(NGear.L("item_locator.details"))
    local hasUnavailableData = ItemLocator.HasUnavailableData()
    ui.status:SetHidden(not hasUnavailableData)
    ui.hint:SetWidth(hasUnavailableData and ui.footerHintReducedWidth or ui.footerHintWidth)
    if hasUnavailableData then
        ui.status:SetText(NGear.L("item_locator.data_unavailable"))
    else
        ui.status:SetText("")
    end
    SetLabelFont(ui.hint, "ZoFontGamepad22")
    ui.hint:SetText(GetInputHint())
    if ui.hint.GetTextWidth and ui.hint:GetTextWidth() > ui.hint:GetWidth() then
        SetLabelFont(ui.hint, "ZoFontGamepad18")
    end
end

local keybindGroup
local suspendedOptionsTertiaryKeybind
local StopCategoryRepeat

local function GetOptionsTertiaryKeybind()
    local descriptors = GAMEPAD_OPTIONS and GAMEPAD_OPTIONS.keybindStripDescriptor
    if type(descriptors) ~= "table" then return nil end
    for index = 1, #descriptors do
        if descriptors[index].keybind == "UI_SHORTCUT_TERTIARY" then return descriptors[index] end
    end
    return nil
end

local function SuspendOptionsTertiaryKeybind()
    if suspendedOptionsTertiaryKeybind or not KEYBIND_STRIP.HasKeybindButton
        or not KEYBIND_STRIP.RemoveKeybindButton then return end
    local descriptor = GetOptionsTertiaryKeybind()
    if descriptor and KEYBIND_STRIP:HasKeybindButton(descriptor) then
        KEYBIND_STRIP:RemoveKeybindButton(descriptor)
        suspendedOptionsTertiaryKeybind = descriptor
    end
end

local function ResumeOptionsTertiaryKeybind()
    local descriptor = suspendedOptionsTertiaryKeybind
    suspendedOptionsTertiaryKeybind = nil
    if not descriptor or not KEYBIND_STRIP.AddKeybindButton then return end
    if SCENE_MANAGER and SCENE_MANAGER.IsShowing
        and not SCENE_MANAGER:IsShowing("gamepad_options_panel") then return end
    if not KEYBIND_STRIP.HasKeybindButton or not KEYBIND_STRIP:HasKeybindButton(descriptor) then
        KEYBIND_STRIP:AddKeybindButton(descriptor)
    end
end

local function RefreshKeybinds()
    if not KEYBIND_STRIP or not keybindGroup then return end
    local shouldShow = IsBrowserVisible() and not searchDialogOpen
    if not shouldShow then
        if StopCategoryRepeat then StopCategoryRepeat() end
        ResetDetailInput()
    end
    if shouldShow and not keybindsActive then
        SuspendOptionsTertiaryKeybind()
        KEYBIND_STRIP:AddKeybindButtonGroup(keybindGroup)
        keybindsActive = true
    elseif shouldShow and keybindsActive and KEYBIND_STRIP.UpdateKeybindButtonGroup then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(keybindGroup)
    elseif not shouldShow and keybindsActive then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(keybindGroup)
        keybindsActive = false
        ResumeOptionsTertiaryKeybind()
    end
end

local RefreshDirectionalInput

local function RefreshBrowser(preferredId)
    if not IsBrowserVisible() then return end
    preferredId = preferredId or (GetSelectedRecord() and GetSelectedRecord().id)
    ItemLocator.BuildBrowserRecords(records)
    RemoveHiddenCategories()
    SortBrowserRecords()
    local preferredCategory = GetActiveCategory() and GetActiveCategory().label
    BuildFilteredRecords(preferredId, preferredCategory)
    RenderDetails(GetSelectedRecord())
    LayoutUI()
    RefreshHeader()
    RenderTabs()
    RenderRows()
    RenderEmptyState()
    RefreshDirectionalInput()
    RefreshKeybinds()
end

local function ReleaseBrowserData()
    ReleaseItemIcon()
    for index = 1, #(ui and ui.tabs or {}) do
        local tab = ui.tabs[index]
        tab.currentIconPath = nil
        tab.icon:SetTexture(nil)
    end
    records = {}
    filtered = {}
    listEntries = {}
    recordEntryIndices = {}
    categories = {}
    selectedByCategory = {}
    detailLines = {}
    chatCounts = {}
    chatEntries = {}
    chatHouseCounts = {}
    chatHouseNames = {}
    chatHouseKeys = {}
    activeCategoryIndex = 1
    selectedIndex = 1
    visibleFirstIndex = 1
    if ui then
        ui.detailRecordId, ui.detailScrollOffset, ui.detailScrollMaximum = nil, 0, 0
        ResetDetailInput()
    end
end

local function MoveSelection(delta)
    if #filtered == 0 then return end
    local nextIndex = NGear.Util.Clamp(selectedIndex + (delta > 0 and 1 or -1), 1, #filtered)
    if nextIndex == selectedIndex then return end
    selectedIndex = nextIndex
    RenderDetails(GetSelectedRecord())
    LayoutUI()
    RenderTabs()
    RenderRows()
    RenderEmptyState()
    if PlaySound and SOUNDS then PlaySound(delta > 0 and SOUNDS.GAMEPAD_MENU_DOWN or SOUNDS.GAMEPAD_MENU_UP) end
end

local function ChangeCategory(delta)
    if #categories < 2 then return end
    local nextIndex = ((activeCategoryIndex - 1 + delta) % #categories) + 1
    local selected = GetSelectedRecord()
    local current = GetActiveCategory()
    if selected and current then selectedByCategory[current.label] = selected.id end
    activeCategoryIndex = nextIndex
    local category = GetActiveCategory()
    PopulateActiveCategory(category and selectedByCategory[category.label])
    RenderDetails(GetSelectedRecord())
    LayoutUI()
    RefreshHeader()
    RenderTabs()
    RenderRows()
    RenderEmptyState()
    RefreshDirectionalInput()
    RefreshKeybinds()
    if PlaySound and SOUNDS then PlaySound(delta > 0 and SOUNDS.GAMEPAD_MENU_DOWN or SOUNDS.GAMEPAD_MENU_UP) end
end

local function JumpCategoryColumn(direction)
    if not ui or ui.visibleTabColumns ~= C.TAB_COLUMNS then return end
    local visibleCount = math.min(#categories, ui.visibleTabs or C.MAX_TABS)
    local rowsPerColumn = ui.visibleTabRows or math.ceil(visibleCount / C.TAB_COLUMNS)
    local firstIndex = GetFirstVisibleCategoryIndex()
    local visibleOffset = activeCategoryIndex - firstIndex
    if visibleOffset < 0 or visibleOffset >= visibleCount then return end

    local currentColumn = math.floor(visibleOffset / rowsPerColumn)
    local targetOffset
    if direction > 0 then
        if currentColumn ~= 0 then return end
        targetOffset = math.min(visibleOffset + rowsPerColumn, visibleCount - 1)
        if targetOffset < rowsPerColumn then return end
    else
        if currentColumn ~= 1 then return end
        targetOffset = visibleOffset - rowsPerColumn
    end

    local targetIndex = firstIndex + targetOffset
    if targetIndex ~= activeCategoryIndex then ChangeCategory(targetIndex - activeCategoryIndex) end
end

StopCategoryRepeat = function(direction)
    if direction and ui and ui.categoryInputDirection ~= direction then return end
    if EVENT_MANAGER then EVENT_MANAGER:UnregisterForUpdate(C.CATEGORY_REPEAT_UPDATE) end
    if ui then ui.categoryInputDirection, ui.nextCategoryInputAt = 0, 0 end
end

local function StartCategoryRepeat(direction)
    if not ui or not IsBrowserVisible() or searchDialogOpen or #categories < 2 then return end
    if ui.categoryInputDirection == direction then return end
    StopCategoryRepeat()
    ui.categoryInputDirection = direction
    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    ui.nextCategoryInputAt = now + C.CATEGORY_INITIAL_DELAY_MS
    ChangeCategory(direction)
    if not EVENT_MANAGER then return end
    EVENT_MANAGER:RegisterForUpdate(C.CATEGORY_REPEAT_UPDATE, C.CATEGORY_REPEAT_POLL_MS, function()
        if not ui or not IsBrowserVisible() or searchDialogOpen or #categories < 2 then
            StopCategoryRepeat()
            return
        end
        local repeatNow = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
        if repeatNow >= ui.nextCategoryInputAt then
            ui.nextCategoryInputAt = repeatNow + C.CATEGORY_REPEAT_DELAY_MS
            ChangeCategory(direction)
        end
    end)
end

RefreshDirectionalInput = function()
    if not ui or not DIRECTIONAL_INPUT then return end
    local listening = DIRECTIONAL_INPUT.IsListening and DIRECTIONAL_INPUT:IsListening(ui)
    local hasDirectionalNavigation = #filtered > 1 or ui.visibleTabColumns == C.TAB_COLUMNS
        or (ui.detailScrollMaximum or 0) > 0
    local shouldListen = IsBrowserVisible() and not searchDialogOpen and hasDirectionalNavigation
    if shouldListen and not listening then
        DIRECTIONAL_INPUT:Activate(ui, ui.control)
    elseif not shouldListen and listening then
        DIRECTIONAL_INPUT:Deactivate(ui)
    end
    if not shouldListen then
        ResetDetailInput()
        ui.inputDirection, ui.nextInputAt = 0, 0
        ui.columnInputDirection = 0
    end
end

local function ApplySearch(value)
    local preferredId = GetSelectedRecord() and GetSelectedRecord().id
    local preferredCategory = GetActiveCategory() and GetActiveCategory().label
    searchText = tostring(value or "")
    if zo_strtrim then searchText = zo_strtrim(searchText) end
    searchNeedle = NGear.Util.Lower(searchText)
    BuildFilteredRecords(preferredId, preferredCategory)
    RenderDetails(GetSelectedRecord())
    LayoutUI()
    RefreshHeader()
    RenderTabs()
    RenderRows()
    RenderEmptyState()
    RefreshDirectionalInput()
    RefreshKeybinds()
end

local function ToggleSortMode()
    local preferredId = GetSelectedRecord() and GetSelectedRecord().id
    local preferredCategory = GetActiveCategory() and GetActiveCategory().label
    sortMode = sortMode == C.SORT_ALPHABETICAL and C.SORT_QUALITY or C.SORT_ALPHABETICAL
    if ItemLocator.SetSortMode then ItemLocator.SetSortMode(sortMode) end
    SortBrowserRecords()
    BuildFilteredRecords(preferredId, preferredCategory)
    RenderDetails(GetSelectedRecord())
    LayoutUI()
    RefreshHeader()
    RenderTabs()
    RenderRows()
    RenderEmptyState()
    RefreshDirectionalInput()
    RefreshKeybinds()
end

local function LogSelectedItemInChat()
    local record = GetSelectedRecord()
    if not record then return end
    Clear(chatCounts)
    Clear(chatEntries)
    Clear(chatHouseCounts)
    Clear(chatHouseNames)
    Clear(chatHouseKeys)
    local bankCount = 0
    local craftBagCount = 0
    local furnitureVaultCount = 0
    for index = 1, #record.locations, 4 do
        local characterName = record.locations[index]
        local kind = record.locations[index + 1]
        local count = tonumber(record.locations[index + 2]) or 0
        if kind == "b" or kind == "w" then
            if not chatCounts[characterName] then chatEntries[#chatEntries + 1] = characterName end
            chatCounts[characterName] = (chatCounts[characterName] or 0) + count
        elseif kind == "k" then
            bankCount = bankCount + count
        elseif kind == "m" then
            craftBagCount = craftBagCount + count
        elseif kind == "f" then
            furnitureVaultCount = furnitureVaultCount + count
        elseif type(kind) == "string" and string.sub(kind, 1, 1) == "h" then
            if not chatHouseCounts[kind] then chatHouseKeys[#chatHouseKeys + 1] = kind end
            chatHouseCounts[kind] = (chatHouseCounts[kind] or 0) + count
            chatHouseNames[kind] = characterName
        end
    end
    table.sort(chatEntries, function(left, right)
        return NGear.Util.Lower(left) < NGear.Util.Lower(right)
    end)
    for index = 1, #chatEntries do
        local characterName = chatEntries[index]
        chatEntries[index] = NGear.L("item_locator.chat_character", characterName, chatCounts[characterName])
    end
    if bankCount > 0 then
        chatEntries[#chatEntries + 1] = NGear.L("item_locator.chat_bank", bankCount)
    end
    if craftBagCount > 0 then
        chatEntries[#chatEntries + 1] = NGear.L("item_locator.chat_storage", GetCraftBagName(), craftBagCount)
    end
    if furnitureVaultCount > 0 then
        chatEntries[#chatEntries + 1] = NGear.L("item_locator.chat_storage", GetFurnitureVaultName(), furnitureVaultCount)
    end
    table.sort(chatHouseKeys, function(left, right)
        return NGear.Util.Lower(chatHouseNames[left]) < NGear.Util.Lower(chatHouseNames[right])
    end)
    for index = 1, #chatHouseKeys do
        local key = chatHouseKeys[index]
        chatEntries[#chatEntries + 1] = NGear.L("item_locator.chat_storage", chatHouseNames[key], chatHouseCounts[key])
    end
    local locations
    if ZO_GenerateCommaSeparatedListWithoutAnd then
        locations = ZO_GenerateCommaSeparatedListWithoutAnd(chatEntries)
    else
        local separator = ", "
        if GetString and SI_LIST_COMMA_SEPARATOR then
            local nativeSeparator = GetString(SI_LIST_COMMA_SEPARATOR)
            if nativeSeparator and nativeSeparator ~= "" then separator = nativeSeparator end
        end
        locations = table.concat(chatEntries, separator)
    end
    local message = NGear.L("item_locator.chat_message", record.link, locations)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(message)
    elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage(message)
    end
end

local function ReleaseSearchDialog()
    if ZO_Dialogs_ReleaseDialogOnButtonPress then
        ZO_Dialogs_ReleaseDialogOnButtonPress(C.SEARCH_DIALOG)
    elseif ZO_Dialogs_ReleaseDialog then
        ZO_Dialogs_ReleaseDialog(C.SEARCH_DIALOG)
    end
end

local function SetupDialogEntry(control, data, selected, reselectingDuringRebuild, enabled, active)
    if ZO_SharedGamepadEntry_OnSetup then
        ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    end
end

local function RegisterDialogs()
    if dialogsRegistered or not ZO_Dialogs_RegisterCustomDialog or not GAMEPAD_DIALOGS then return end
    dialogsRegistered = true
    ZO_Dialogs_RegisterCustomDialog(C.SEARCH_DIALOG, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = function() return NGear.L("item_locator.search_title") end },
        setup = function(dialog)
            dialog.data = dialog.data or {}
            dialog.info.parametricList = {
                {
                    template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                    templateData = {
                        nameField = true,
                        textChangedCallback = function(editBox) dialog.data.searchText = editBox:GetText() end,
                        setup = function(control, data, selected)
                            if control.highlight then control.highlight:SetHidden(not selected) end
                            local editBox = control.editBoxControl
                            editBox.textChangedCallback = data.textChangedCallback
                            if editBox.SetMaxInputChars then editBox:SetMaxInputChars(50) end
                            if editBox.SetDefaultText then editBox:SetDefaultText(NGear.L("item_locator.search_placeholder")) end
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
                        text = NGear.L("item_locator.apply_search"),
                        setup = SetupDialogEntry,
                        callback = function(dialogRef)
                            ApplySearch(dialogRef.data and dialogRef.data.searchText or "")
                            ReleaseSearchDialog()
                        end,
                    },
                },
                {
                    template = "ZO_GamepadTextFieldSubmitItem",
                    templateData = {
                        text = NGear.L("item_locator.clear_search"),
                        setup = SetupDialogEntry,
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
            RefreshDirectionalInput()
            RefreshKeybinds()
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
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL, callback = ReleaseSearchDialog },
        },
    })
end

local function OpenSearchDialog()
    if not ZO_Dialogs_ShowGamepadDialog or not ItemLocator.HasData() then return end
    RegisterDialogs()
    if not dialogsRegistered then return end
    searchDialogOpen = true
    ResetDetailInput()
    RefreshDirectionalInput()
    RefreshKeybinds()
    ZO_Dialogs_ShowGamepadDialog(C.SEARCH_DIALOG, { searchText = searchText })
end

keybindGroup = {
    {
        name = function() return NGear.L("item_locator.log_in_chat") end,
        keybind = "UI_SHORTCUT_TERTIARY",
        ethereal = true,
        visible = function() return GetSelectedRecord() ~= nil end,
        callback = LogSelectedItemInChat,
    },
    {
        name = function() return NGear.L("common.search") end,
        keybind = "UI_SHORTCUT_LEFT_STICK",
        ethereal = true,
        visible = function() return ItemLocator.HasData() end,
        callback = OpenSearchDialog,
    },
    {
        name = function() return NGear.L("item_locator.sort") end,
        keybind = "UI_SHORTCUT_RIGHT_STICK",
        ethereal = true,
        visible = function() return ItemLocator.HasData() end,
        handlesKeyUp = true,
        callback = function(isKeyUp)
            if not ui or not IsBrowserVisible() or searchDialogOpen then return end
            if isKeyUp then
                local shouldSort = ui.detailSortHeld and not ui.detailScrollUsed
                local consumedGesture = ui.detailSortHeld and ui.detailScrollUsed
                ResetDetailInput()
                ui.detailScrollReleasePending = consumedGesture
                if shouldSort then ToggleSortMode() end
            elseif not ui.detailSortHeld then
                ui.detailSortHeld, ui.detailScrollUsed, ui.detailScrollReleasePending = true, false, false
                ui.inputDirection, ui.nextInputAt = 0, 0
            end
        end,
    },
    {
        keybind = "UI_SHORTCUT_LEFT_SHOULDER",
        ethereal = true,
        visible = function() return #categories > 1 end,
        handlesKeyUp = true,
        callback = function(isKeyUp)
            if isKeyUp then StopCategoryRepeat(-1) else StartCategoryRepeat(-1) end
        end,
    },
    {
        keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
        ethereal = true,
        visible = function() return #categories > 1 end,
        handlesKeyUp = true,
        callback = function(isKeyUp)
            if isKeyUp then StopCategoryRepeat(1) else StartCategoryRepeat(1) end
        end,
    },
}

local function CreateRow(parent, index)
    local row = { control = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL) }
    row.control:SetDimensions(1, C.ROW_HEIGHT)
    row.control:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, (index - 1) * (C.ROW_HEIGHT + C.ROW_GAP))
    row.background = CreateBackdrop(row.control, COLORS.panelAlt)
    row.background:SetAnchorFill(row.control)
    row.accent = WINDOW_MANAGER:CreateControl(nil, row.control, CT_TEXTURE)
    row.accent:SetDimensions(5, C.ROW_HEIGHT)
    row.accent:SetAnchor(TOPLEFT, row.control, TOPLEFT, 0, 0)
    SetColor(row.accent, COLORS.accent)
    row.name = CreateLabel(row.control, "ZoFontGamepad27", COLORS.text)
    row.name:SetAnchor(LEFT, row.control, LEFT, 14, 0)
    row.count = CreateLabel(row.control, "ZoFontGamepad22", COLORS.muted, TEXT_ALIGN_RIGHT)
    row.count:SetAnchor(RIGHT, row.control, RIGHT, -12, 0)
    row.control:SetHidden(true)
    return row
end

local function EnsureRow(index)
    if not ui.rows[index] then ui.rows[index] = CreateRow(ui.leftViewport, index) end
    return ui.rows[index]
end

local function CreateTab(parent)
    local tab = { control = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL) }
    tab.background = CreateBackdrop(tab.control, COLORS.panelAlt)
    tab.background:SetAnchorFill(tab.control)
    tab.icon = WINDOW_MANAGER:CreateControl(nil, tab.control, CT_TEXTURE)
    tab.icon:SetAnchor(LEFT, tab.control, LEFT, 10, 0)
    tab.icon:SetDrawLevel(C.DRAW_LEVEL + 5)
    if tab.icon.SetColor then tab.icon:SetColor(1, 1, 1, 1) end
    if tab.icon.SetDesaturation then tab.icon:SetDesaturation(0) end
    if tab.icon.SetTextureReleaseOption and RELEASE_TEXTURE_AT_ZERO_REFERENCES then
        tab.icon:SetTextureReleaseOption(RELEASE_TEXTURE_AT_ZERO_REFERENCES)
    end
    tab.label = CreateLabel(tab.control, "ZoFontGamepad22", COLORS.muted)
    tab.label:SetAnchor(LEFT, tab.control, LEFT, 50, 0)
    if tab.label.SetWrapMode and TEXT_WRAP_MODE_TRUNCATE then tab.label:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE) end
    if tab.label.SetMaxLineCount then tab.label:SetMaxLineCount(1) end
    tab.underline = WINDOW_MANAGER:CreateControl(nil, tab.control, CT_TEXTURE)
    tab.underline:SetDimensions(5, 1)
    tab.underline:SetAnchor(TOPLEFT, tab.control, TOPLEFT, 0, 0)
    tab.underline:SetAnchor(BOTTOMLEFT, tab.control, BOTTOMLEFT, 0, 0)
    SetColor(tab.underline, COLORS.accent)
    tab.control:SetHidden(true)
    return tab
end

EnsureTab = function(index)
    if not ui.tabs[index] then ui.tabs[index] = CreateTab(ui.tabBar) end
    return ui.tabs[index]
end

LayoutUI = function()
    local width = GuiRoot:GetWidth()
    local height = GuiRoot:GetHeight()
    local scale = (ItemLocator.GetScale and ItemLocator.GetScale() or 100) / 100
    local maximumWidth = math.max(math.min(1500, (width - 32) / scale), 320)
    local minimumWidth = math.min(900, maximumWidth)
    local contentWidth = NGear.Util.Clamp((width - 100) / scale, minimumWidth, maximumWidth)
    local gameFooterHeight = tonumber(ZO_KEYBIND_STRIP_GAMEPAD_VISUAL_HEIGHT) or 125
    local maximumContentHeight = (height - C.SCREEN_TOP_MARGIN - gameFooterHeight - C.SCREEN_FOOTER_GAP) / scale
    local innerWidth = contentWidth - (C.PADDING * 2)
    local contentTop = C.PADDING + C.HEADER_HEIGHT
    local fixedHeight = contentTop + C.FOOTER_HEIGHT + C.PADDING
    local maximumPaneHeight = math.max(maximumContentHeight - fixedHeight, C.TAB_HEIGHT)
    local maximumTabRows = NGear.Util.Clamp(
        math.floor((maximumPaneHeight + C.TAB_GAP) / (C.TAB_HEIGHT + C.TAB_GAP)),
        1,
        math.floor(C.MAX_TABS / C.TAB_COLUMNS)
    )
    local requiredTabRows = math.ceil(math.max(#categories, 1) / C.TAB_COLUMNS)
    local detailContentHeight = math.max(tonumber(ui.detailContentHeight) or 0, 0)
    if detailContentHeight > 0 then
        local detailPaneHeight = C.PANE_HEADER_HEIGHT - C.PANE_HEADER_OFFSET
            + C.DETAIL_TOP_OFFSET + detailContentHeight + C.DETAIL_BOTTOM_PADDING
        local detailTabRows = math.ceil((detailPaneHeight + C.TAB_GAP) / (C.TAB_HEIGHT + C.TAB_GAP))
        requiredTabRows = math.max(requiredTabRows, detailTabRows)
    end
    ui.visibleTabRows = NGear.Util.Clamp(
        requiredTabRows,
        math.min(C.MIN_TAB_ROWS, maximumTabRows),
        maximumTabRows
    )
    local paneHeight = (ui.visibleTabRows * C.TAB_HEIGHT) + ((ui.visibleTabRows - 1) * C.TAB_GAP)
    local contentHeight = fixedHeight + paneHeight
    local viewportHeight = paneHeight - C.PANE_HEADER_HEIGHT + C.PANE_HEADER_OFFSET
    local expandedTabBarWidth = NGear.Util.Clamp(math.floor(innerWidth * 0.34), 340, 500)
    local tabColumnWidth = math.floor(
        (expandedTabBarWidth - (C.TAB_GAP * (C.TAB_COLUMNS - 1))) / C.TAB_COLUMNS
    )
    ui.visibleTabColumns = #categories > ui.visibleTabRows and C.TAB_COLUMNS or 1
    local tabWidth = ui.visibleTabColumns == C.TAB_COLUMNS and expandedTabBarWidth or tabColumnWidth
    local paneWidth = innerWidth - tabWidth - (C.PANE_GAP * 2)
    local leftWidth = math.floor(paneWidth * 0.43)
    local rightWidth = paneWidth - leftWidth
    local leftX = C.PADDING + tabWidth + C.PANE_GAP
    local rightX = leftX + leftWidth + C.PANE_GAP
    ui.visibleRows = NGear.Util.Clamp(
        math.floor((viewportHeight + C.ROW_GAP) / (C.ROW_HEIGHT + C.ROW_GAP)), 1, C.MAX_ROWS
    )
    ui.rowHeight = math.floor((viewportHeight - (C.ROW_GAP * (ui.visibleRows - 1))) / ui.visibleRows)
    ui.visibleTabs = NGear.Util.Clamp(
        ui.visibleTabRows * ui.visibleTabColumns,
        ui.visibleTabColumns,
        C.MAX_TABS
    )
    ui.tabHeight = C.TAB_HEIGHT
    for index = ui.visibleTabs + 1, #ui.tabs do ui.tabs[index].control:SetHidden(true) end
    for index = 1, ui.visibleRows do EnsureRow(index) end
    for index = ui.visibleRows + 1, #ui.rows do ui.rows[index].control:SetHidden(true) end

    ui.control:ClearAnchors()
    if ui.control.SetScale then ui.control:SetScale(scale) end
    local horizontalPosition = ItemLocator.GetHorizontalPosition and ItemLocator.GetHorizontalPosition() or 50
    local verticalPosition = ItemLocator.GetVerticalPosition and ItemLocator.GetVerticalPosition() or 50
    local maximumX = math.max(width - (contentWidth * scale), 0)
    local maximumY = math.max(height - (contentHeight * scale), 0)
    ui.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, maximumX * (horizontalPosition / 100), maximumY * (verticalPosition / 100))
    ui.control:SetDimensions(contentWidth, contentHeight)
    ui.title:SetDimensions(math.floor(innerWidth * 0.60), C.HEADER_HEIGHT)
    ui.summary:SetDimensions(rightWidth, C.HEADER_HEIGHT)
    ui.tabBar:ClearAnchors()
    ui.tabBar:SetDimensions(tabWidth, paneHeight)
    ui.tabBar:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, C.PADDING, contentTop)
    ui.tabBarWidth = tabWidth
    ui.leftHeader:ClearAnchors()
    ui.leftHeader:SetDimensions(leftWidth, C.PANE_HEADER_HEIGHT)
    ui.leftHeader:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, leftX, contentTop - C.PANE_HEADER_OFFSET)
    ui.rightHeader:ClearAnchors()
    ui.rightHeader:SetDimensions(rightWidth, C.PANE_HEADER_HEIGHT)
    ui.rightHeader:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, rightX, contentTop - C.PANE_HEADER_OFFSET)
    ui.leftViewport:ClearAnchors()
    ui.leftViewport:SetDimensions(leftWidth, viewportHeight)
    ui.leftViewport:SetAnchor(TOPLEFT, ui.leftHeader, BOTTOMLEFT, 0, 0)
    ui.rightViewport:ClearAnchors()
    ui.rightViewport:SetDimensions(rightWidth, viewportHeight)
    ui.rightViewport:SetAnchor(TOPLEFT, ui.rightHeader, BOTTOMLEFT, 0, 0)
    ui.tabDivider:SetDimensions(1, paneHeight)
    ui.tabDivider:ClearAnchors()
    ui.tabDivider:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, C.PADDING + tabWidth + math.floor(C.PANE_GAP / 2), contentTop)
    ui.divider:SetDimensions(1, paneHeight)
    ui.divider:ClearAnchors()
    ui.divider:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, leftX + leftWidth + math.floor(C.PANE_GAP / 2), contentTop)
    ui.footer:SetDimensions(innerWidth, C.FOOTER_HEIGHT)
    ui.footerDivider:SetDimensions(innerWidth, 1)
    local statusWidth = math.floor(innerWidth * 0.28)
    ui.footerHintWidth = innerWidth
    ui.footerHintReducedWidth = innerWidth - statusWidth - C.PANE_GAP
    ui.status:SetDimensions(statusWidth, C.FOOTER_HEIGHT)
    ui.hint:SetDimensions(ui.footerHintWidth, C.FOOTER_HEIGHT)

    for index = 1, #ui.rows do
        local row = ui.rows[index]
        row.control:ClearAnchors()
        row.control:SetDimensions(leftWidth, ui.rowHeight)
        row.control:SetAnchor(TOPLEFT, ui.leftViewport, TOPLEFT, 0, (index - 1) * (ui.rowHeight + C.ROW_GAP))
        row.accent:SetDimensions(5, ui.rowHeight)
        row.name:SetDimensions(leftWidth - 90, ui.rowHeight)
        row.count:SetDimensions(66, ui.rowHeight)
    end
    ui.itemName:SetDimensions(rightWidth - 100, 58)
    ui.itemMeta:SetDimensions(rightWidth - 100, 40)
    -- Measure at the final width, then clip only the scrolling body, below the item heading.
    ui.details:SetDimensions(rightWidth, math.max(C.DETAIL_MEASURE_HEIGHT, ui.detailMinimumHeight or 0))
    local measuredHeight = ui.details.GetTextHeight and math.ceil(ui.details:GetTextHeight()) or 0
    ui.detailContentHeight = math.max(measuredHeight, ui.detailMinimumHeight or 0)
    local detailHeight = math.max(viewportHeight - C.DETAIL_TOP_OFFSET, 1)
    local hasOverflow = ui.detailContentHeight > detailHeight
    ui.detailScrollHint:SetDimensions(rightWidth, C.DETAIL_MEASURE_HEIGHT)
    ui.detailScrollHint:SetHidden(not hasOverflow or GetSelectedRecord() == nil)
    local hintHeight = C.DETAIL_HINT_HEIGHT
    if hasOverflow then
        ui.detailScrollHint:SetText(NGear.L("item_locator.details_scroll_hint", GetBindingIcon("UI_SHORTCUT_RIGHT_STICK", "R3")))
        if ui.detailScrollHint.GetTextHeight then
            hintHeight = math.max(hintHeight, math.ceil(ui.detailScrollHint:GetTextHeight()))
        end
        detailHeight = math.max(detailHeight - hintHeight, 1)
    end
    ui.detailScrollHint:SetHeight(hintHeight)
    ui.detailScrollViewport:SetDimensions(rightWidth, detailHeight)
    ui.details:SetHeight(math.max(ui.detailContentHeight, detailHeight))
    ui.detailScrollMaximum = math.max(ui.detailContentHeight - detailHeight, 0)
    ApplyDetailOffset()
    ui.empty:SetDimensions(leftWidth - 40, 150)
    ui.detailEmpty:SetDimensions(rightWidth - 40, 150)
end

local function ApplyFonts()
    if not ui then return end
    local labels = {
        ui.title, ui.summary, ui.leftHeader, ui.rightHeader, ui.empty, ui.detailEmpty,
        ui.itemName, ui.itemMeta, ui.details, ui.detailScrollHint, ui.status, ui.hint,
    }
    for index = 1, #labels do
        local label = labels[index]
        if label and label.ngearFont then label:SetFont(ResolveFont(label.ngearFont)) end
    end
    for _, row in ipairs(ui.rows or {}) do
        row.name:SetFont(ResolveFont(row.name.ngearFont))
        row.count:SetFont(ResolveFont(row.count.ngearFont))
    end
    for _, tab in ipairs(ui.tabs or {}) do
        tab.label:SetFont(ResolveFont(tab.label.ngearFont))
    end
end

local function ApplyBackgroundOpacity()
    if not ui or not ui.panelBackground then return end
    local opacity = (ItemLocator.GetBackgroundOpacity and ItemLocator.GetBackgroundOpacity() or 94) / 100
    ui.panelBackground:SetCenterColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], opacity)
    ui.panelBackground:SetEdgeColor(COLORS.divider[1], COLORS.divider[2], COLORS.divider[3], math.min(opacity + 0.12, 1))
end

local function EnsureHud()
    if ui or not WINDOW_MANAGER or not GuiRoot then return ui end
    ui = {
        rows = {},
        tabs = {},
        inputDirection = 0,
        nextInputAt = 0,
        columnInputDirection = 0,
        categoryInputDirection = 0,
        nextCategoryInputAt = 0,
    }
    ui.control = WINDOW_MANAGER:CreateTopLevelWindow("NGearItemLocator")
    ui.control:SetHidden(true)
    if ui.control.SetDrawTier and DT_HIGH then ui.control:SetDrawTier(DT_HIGH) end
    if ui.control.SetDrawLayer and DL_CONTROLS then ui.control:SetDrawLayer(DL_CONTROLS) end
    ui.control:SetDrawLevel(C.DRAW_LEVEL)
    ui.UpdateDirectionalInput = function()
        if not IsBrowserVisible() or searchDialogOpen or not DIRECTIONAL_INPUT or not ZO_DI_RIGHT_STICK then
            ui.inputDirection, ui.nextInputAt = 0, 0
            ui.columnInputDirection = 0
            return
        end

        local stickX, stickY = DIRECTIONAL_INPUT:GetXY(ZO_DI_RIGHT_STICK)
        stickX, stickY = stickX or 0, stickY or 0
        local absoluteX, absoluteY = math.abs(stickX), math.abs(stickY)
        if absoluteX <= C.INPUT_DEADZONE and absoluteY <= C.INPUT_DEADZONE then
            ui.detailScrollReleasePending = false
            ui.inputDirection, ui.nextInputAt = 0, 0
            ui.columnInputDirection = 0
            return
        end

        if ui.detailScrollReleasePending then return end

        if absoluteX > C.INPUT_DEADZONE and absoluteX > absoluteY then
            if ui.detailSortHeld then ui.detailScrollUsed = true end
            ui.inputDirection, ui.nextInputAt = 0, 0
            if ui.columnInputDirection == 0 then
                ui.columnInputDirection = stickX > 0 and 1 or -1
                JumpCategoryColumn(ui.columnInputDirection)
            end
            return
        end

        if ui.columnInputDirection ~= 0 or (not ui.detailSortHeld and #filtered <= 1)
            or absoluteY <= C.INPUT_DEADZONE or absoluteY <= absoluteX then return end
        if ui.detailSortHeld then ui.detailScrollUsed = true end
        local direction = stickY < 0 and 1 or -1
        local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
        if direction ~= ui.inputDirection then
            ui.inputDirection = direction
            ui.nextInputAt = now + C.INPUT_INITIAL_DELAY_MS
            if ui.detailSortHeld then ScrollDetails(direction) else MoveSelection(direction) end
        elseif now >= ui.nextInputAt then
            ui.nextInputAt = now + C.INPUT_REPEAT_DELAY_MS
            if ui.detailSortHeld then ScrollDetails(direction) else MoveSelection(direction) end
        end
    end
    ui.panel = WINDOW_MANAGER:CreateControl(nil, ui.control, CT_CONTROL)
    ui.panel:SetAnchorFill(ui.control)
    ui.panelBackground = CreateBackdrop(ui.panel, COLORS.panel)
    ui.panelBackground:SetAnchorFill(ui.panel)
    ui.title = CreateLabel(ui.panel, "ZoFontGamepadBold34", COLORS.text)
    ui.title:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, C.PADDING, C.PADDING)
    ui.summary = CreateLabel(ui.panel, "ZoFontGamepad22", COLORS.muted, TEXT_ALIGN_RIGHT)
    ui.summary:SetAnchor(TOPRIGHT, ui.panel, TOPRIGHT, -C.PADDING, C.PADDING)
    ui.tabBar = WINDOW_MANAGER:CreateControl(nil, ui.panel, CT_CONTROL)
    ui.tabBar:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, C.PADDING, C.PADDING + C.HEADER_HEIGHT)
    if ui.tabBar.SetClipsChildren then ui.tabBar:SetClipsChildren(true) end
    ui.leftHeader = CreateLabel(ui.panel, "ZoFontGamepadBold22", COLORS.accent)
    ui.leftHeader:SetAnchor(TOPLEFT, ui.tabBar, BOTTOMLEFT, 0, 0)
    ui.rightHeader = CreateLabel(ui.panel, "ZoFontGamepadBold22", COLORS.accent)
    ui.rightHeader:SetAnchor(TOPRIGHT, ui.tabBar, BOTTOMRIGHT, 0, 0)
    ui.leftViewport = WINDOW_MANAGER:CreateControl(nil, ui.panel, CT_CONTROL)
    ui.leftViewport:SetAnchor(TOPLEFT, ui.leftHeader, BOTTOMLEFT, 0, 0)
    ui.rightViewport = WINDOW_MANAGER:CreateControl(nil, ui.panel, CT_CONTROL)
    ui.rightViewport:SetAnchor(TOPLEFT, ui.rightHeader, BOTTOMLEFT, 0, 0)
    ui.tabDivider = WINDOW_MANAGER:CreateControl(nil, ui.panel, CT_TEXTURE)
    SetColor(ui.tabDivider, COLORS.divider)
    ui.divider = WINDOW_MANAGER:CreateControl(nil, ui.panel, CT_TEXTURE)
    SetColor(ui.divider, COLORS.divider)
    ui.upArrow = WINDOW_MANAGER:CreateControl(nil, ui.leftHeader, CT_TEXTURE)
    ui.upArrow:SetTexture("EsoUI/Art/Buttons/Gamepad/gp_upArrow.dds")
    ui.upArrow:SetDimensions(24, 24)
    ui.upArrow:SetAnchor(RIGHT, ui.leftHeader, RIGHT, -4, 0)
    SetColor(ui.upArrow, COLORS.accent)
    ui.downArrow = WINDOW_MANAGER:CreateControl(nil, ui.leftViewport, CT_TEXTURE)
    ui.downArrow:SetTexture("EsoUI/Art/Buttons/Gamepad/gp_downArrow.dds")
    ui.downArrow:SetDimensions(24, 24)
    ui.downArrow:SetAnchor(BOTTOMRIGHT, ui.leftViewport, BOTTOMRIGHT, -4, 0)
    SetColor(ui.downArrow, COLORS.accent)
    ui.empty = CreateLabel(ui.leftViewport, "ZoFontGamepad27", COLORS.muted, TEXT_ALIGN_CENTER)
    ui.empty:SetAnchor(CENTER, ui.leftViewport, CENTER, 0, 0)
    ui.detailEmpty = CreateLabel(ui.rightViewport, "ZoFontGamepad27", COLORS.muted, TEXT_ALIGN_CENTER)
    ui.detailEmpty:SetAnchor(CENTER, ui.rightViewport, CENTER, 0, 0)
    ui.itemIconFrame = CreateBackdrop(ui.rightViewport, COLORS.panelAlt)
    ui.itemIconFrame:SetDrawLevel(C.DRAW_LEVEL + 3)
    ui.itemIconFrame:SetDimensions(84, 84)
    ui.itemIconFrame:SetAnchor(TOPLEFT, ui.rightViewport, TOPLEFT, 0, 0)
    ui.itemIcon = WINDOW_MANAGER:CreateControl(nil, ui.rightViewport, CT_TEXTURE)
    ui.itemIcon:SetDimensions(80, 80)
    ui.itemIcon:SetAnchor(CENTER, ui.itemIconFrame, CENTER, 0, 0)
    ui.itemIcon:SetDrawLevel(C.DRAW_LEVEL + 5)
    if ui.itemIcon.SetAlpha then ui.itemIcon:SetAlpha(1) end
    if ui.itemIcon.SetColor then ui.itemIcon:SetColor(1, 1, 1, 1) end
    if ui.itemIcon.SetDesaturation then ui.itemIcon:SetDesaturation(0) end
    NGear.Util.ConfigureContentTexture(ui.itemIcon, nil, ui.itemIconFrame)
    ui.itemName = CreateLabel(ui.rightViewport, "ZoFontGamepadBold34", COLORS.text)
    ui.itemName:SetAnchor(TOPLEFT, ui.itemIconFrame, TOPRIGHT, 16, 0)
    ui.itemMeta = CreateLabel(ui.rightViewport, "ZoFontGamepad22", COLORS.muted)
    ui.itemMeta:SetAnchor(TOPLEFT, ui.itemName, BOTTOMLEFT, 0, 0)
    ui.detailScrollViewport = WINDOW_MANAGER:CreateControl(nil, ui.rightViewport, CT_SCROLL)
    ui.detailScrollViewport:SetAnchor(TOPLEFT, ui.rightViewport, TOPLEFT, 0, C.DETAIL_TOP_OFFSET)
    ui.details = CreateLabel(ui.detailScrollViewport, "ZoFontGamepad22", COLORS.text)
    ui.details:SetVerticalAlignment(TEXT_ALIGN_TOP)
    ui.details:SetAnchor(TOPLEFT, ui.detailScrollViewport, TOPLEFT, 0, 0)
    ui.detailScrollHint = CreateLabel(ui.rightViewport, "ZoFontGamepad18", COLORS.muted)
    ui.detailScrollHint:SetAnchor(BOTTOMLEFT, ui.rightViewport, BOTTOMLEFT, 0, 0)
    ui.detailScrollHint:SetHidden(true)
    ui.footerDivider = WINDOW_MANAGER:CreateControl(nil, ui.panel, CT_TEXTURE)
    ui.footerDivider:SetAnchor(BOTTOMLEFT, ui.panel, BOTTOMLEFT, C.PADDING, -(C.FOOTER_HEIGHT + 1))
    SetColor(ui.footerDivider, COLORS.divider)
    ui.footer = WINDOW_MANAGER:CreateControl(nil, ui.panel, CT_CONTROL)
    ui.footer:SetAnchor(BOTTOMLEFT, ui.panel, BOTTOMLEFT, C.PADDING, -2)
    ui.status = CreateLabel(ui.footer, "ZoFontGamepad18", COLORS.muted)
    ui.status:SetAnchor(LEFT, ui.footer, LEFT, 0, 0)
    ui.hint = CreateLabel(ui.footer, "ZoFontGamepad22", COLORS.muted, TEXT_ALIGN_RIGHT)
    ui.hint:SetAnchor(RIGHT, ui.footer, RIGHT, 0, 0)
    LayoutUI()
    ApplyFonts()
    ApplyBackgroundOpacity()
    RegisterDialogs()
    return ui
end

function ItemLocator.OpenBrowser()
    if not EnsureHud() then return end
    searchText, searchNeedle = "", ""
    local savedSortMode = ItemLocator.GetSortMode and ItemLocator.GetSortMode()
    sortMode = savedSortMode == C.SORT_QUALITY and C.SORT_QUALITY or C.SORT_ALPHABETICAL
    hudVisible = true
    ui.control:SetHidden(false)
    RefreshBrowser()
    RefreshDirectionalInput()
    RefreshKeybinds()
end

HideBrowser = function()
    hudVisible = false
    if searchDialogOpen then ReleaseSearchDialog() end
    if ui and ui.control then ui.control:SetHidden(true) end
    RefreshDirectionalInput()
    RefreshKeybinds()
    ReleaseBrowserData()
end

function ItemLocator.SetSettingsPanelVisible(value)
    if value == true then
        ItemLocator.OpenBrowser()
    else
        HideBrowser()
    end
end

function ItemLocator.RefreshDisplay()
    if not ui then return end
    fontStringCache = {}
    ApplyFonts()
    RenderDetails(GetSelectedRecord())
    LayoutUI()
    ApplyBackgroundOpacity()
    RefreshHeader()
    RefreshDirectionalInput()
end

ItemLocator.RefreshBrowser = function()
    if IsBrowserVisible() then RefreshBrowser() end
end
