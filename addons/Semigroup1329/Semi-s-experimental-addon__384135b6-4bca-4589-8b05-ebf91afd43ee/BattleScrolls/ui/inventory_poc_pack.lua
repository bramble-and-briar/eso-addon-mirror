---@diagnostic disable: undefined-field, inject-field -- Native gamepad controls and entry data expose additional runtime methods and fields
if not SemisPlaygroundCheckAccess() then return end

---The Pack tab of the "Your pack" screen: every pack slot under what it is
---waiting for, the most blocked first. A bar under the header shows how the
---pack divides, in the colors of the group headers below it.
---@class InventoryPocPackView
---@field bar Control
---@field header Control
---@field onChanged fun()
---@field analysis InventoryPocAnalysis|nil
---@field fiber Fiber|nil
---@field dirty boolean
---@field active boolean
local PackView = {}
PackView.__index = PackView
BattleScrolls.inventoryPocPack = PackView
local poc = BattleScrolls.inventoryPoc
local details = BattleScrolls.inventoryPocDetails
local EVENT_NAME = 'BattleScrollsInventoryPocPack'
local ROW_TEMPLATE = 'ZO_GamepadItemSubEntryTemplate'
local OVERVIEW_ICON = 'EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_inventory.dds'
local BAR_HEIGHT, BAR_PADDING, SEGMENT_GAP = 10, 14, 2

---@type table<InventoryPocFateClass, string>
local CLASS_COLORS = { stuck = 'E0553D', trade = 'D9B13B', leaves = '6FB551', unassigned = 'B08AD9', kept = '8C8C8C' }
---@type table<InventoryPocFateClass, string|number>
local CLASS_TITLES = {
    stuck = BATTLESCROLLS_IPOC_CLASS_STUCK, trade = BATTLESCROLLS_IPOC_CLASS_TRADE,
    leaves = BATTLESCROLLS_IPOC_CLASS_LEAVES, unassigned = BATTLESCROLLS_IPOC_REASON_UNASSIGNED,
    kept = BATTLESCROLLS_IPOC_FATE_KEEP,
}
---@type table<InventoryPocFate, string|number>
local FATE_TITLES = {
    listWait = BATTLESCROLLS_IPOC_FATE_LIST_WAIT, price = BATTLESCROLLS_IPOC_FATE_PRICE,
    info = BATTLESCROLLS_IPOC_FATE_INFO, list = BATTLESCROLLS_IPOC_FATE_LIST,
    listNext = BATTLESCROLLS_IPOC_FATE_LIST_NEXT, sell = BATTLESCROLLS_IPOC_FATE_SELL,
    deconstruct = BATTLESCROLLS_IPOC_FATE_DECONSTRUCT, bank = BATTLESCROLLS_IPOC_FATE_BANK,
    auto = BATTLESCROLLS_IPOC_FATE_AUTO, unassigned = BATTLESCROLLS_IPOC_REASON_UNASSIGNED,
    keep = BATTLESCROLLS_IPOC_FATE_KEEP,
}
---@type table<InventoryPocFate, string|number>
local FATE_WHY = {
    listNext = BATTLESCROLLS_IPOC_WHY_LIST_NEXT, sell = BATTLESCROLLS_IPOC_WHY_SELL,
    deconstruct = BATTLESCROLLS_IPOC_WHY_DECONSTRUCT, bank = BATTLESCROLLS_IPOC_WHY_BANK,
    auto = BATTLESCROLLS_IPOC_WHY_AUTO, unassigned = BATTLESCROLLS_IPOC_WHY_UNASSIGNED,
    keep = BATTLESCROLLS_IPOC_WHY_KEEP,
}

---@param bar Control
---@param class InventoryPocFateClass
---@return Control
local function segment(bar, class)
    return bar:GetNamedChild(class:sub(1, 1):upper() .. class:sub(2))
end

---@param class InventoryPocFateClass
---@param text string
---@return string
local function colored(class, text)
    return '|c' .. CLASS_COLORS[class] .. text .. '|r'
end

---@param value number
---@return string
local function gold(value)
    return ZO_CommaDelimitNumber(math.floor(value))
end

---@param headerContainer Control The screen's header container: the bar grows it, moving the list down
---@param header Control
---@param onChanged fun() A new analysis is ready to show
---@return InventoryPocPackView
function PackView.new(headerContainer, header, onChanged)
    local bar = CreateControlFromVirtual('$(parent)PackBar', headerContainer, 'BattleScrollsInventoryPocPackBar')
    bar:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 0)
    bar:SetAnchor(TOPRIGHT, header, BOTTOMRIGHT, 0, 0)
    for class, color in pairs(CLASS_COLORS) do
        local r, g, b = tonumber(color:sub(1, 2), 16), tonumber(color:sub(3, 4), 16), tonumber(color:sub(5, 6), 16)
        segment(bar, class):SetColor(r / 255, g / 255, b / 255, 1)
    end
    return setmetatable({ bar = bar, header = header, onChanged = onChanged, dirty = false, active = false }, PackView)
end

function PackView:scan()
    if self.fiber then self.fiber:Cancel() end
    self.dirty = false
    self.fiber = LibEffect.Async(function()
        self.analysis = BattleScrolls.inventoryPocAnalysis.scan():Await()
        self.onChanged()
    end):Ensure(function()
        self.fiber = nil
        BattleScrolls.gc:RequestGC(2)
    end):Run()
end

---The tab is on screen: follow the pack until it leaves.
function PackView:start()
    if self.active then return end
    self.active = true
    local function changed() self.dirty = true end
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, changed)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_INVENTORY_FULL_UPDATE, changed)
    self:scan()
end

function PackView:stop()
    if not self.active then return end
    self.active = false
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_INVENTORY_FULL_UPDATE)
    if self.fiber then self.fiber:Cancel() end
    -- The scan holds a table per pack slot.
    self.analysis, self.dirty = nil, false
    self:renderBar()
end

---The screen's periodic check: several slot events become one scan.
function PackView:update()
    if self.active and self.dirty and not self.fiber then self:scan() end
end

function PackView:renderBar()
    local bar, result = self.bar, self.analysis
    local visible = self.active and result ~= nil and result.size > 0
    bar:SetHidden(not visible)
    -- The header container sizes itself to its children, hidden or not.
    bar:SetHeight(visible and BAR_HEIGHT + BAR_PADDING or 0)
    if not visible then return end
    local width = bar:GetWidth()
    if width <= 0 then width = ZO_GAMEPAD_CONTENT_WIDTH end
    local offset = 0
    for _, class in ipairs(BattleScrolls.inventoryPocAnalysis.CLASSES) do
        local texture = segment(bar, class)
        local span = result.classes[class] / result.size * width
        texture:SetHidden(span < 1)
        if span >= 1 then
            texture:ClearAnchors()
            texture:SetAnchor(BOTTOMLEFT, bar, BOTTOMLEFT, offset, 0)
            texture:SetDimensions(math.max(1, span - SEGMENT_GAP), BAR_HEIGHT)
            offset = offset + span
        end
    end
end

---@param data table The screen's header data
function PackView:headerData(data)
    local result = self.analysis
    data.data1HeaderText, data.data1Text, data.data2HeaderText, data.data2Text = nil, nil, nil, nil
    if not self.active or not result then return end
    data.data1HeaderText = GetString(BATTLESCROLLS_IPOC_PACK_SLOTS)
    data.data1Text = string.format('%d / %d', result.used, result.size)
    data.data2HeaderText = GetString(BATTLESCROLLS_IPOC_PACK_LISTING_SLOTS)
    data.data2Text = result.listingFree and string.format('%d / %d', result.listingFree, result.listingCapacity)
        or GetString(BATTLESCROLLS_IPOC_PACK_UNKNOWN)
end

---@param row InventoryPocAnalysisRow
---@return string
local function reasonText(row)
    if row.buildDeposit then return GetString(BATTLESCROLLS_IPOC_REASON_RESERVED) end
    local reason = details.REASONS[row.decision.reason]
    return reason and GetString(reason) or row.decision.reason
end

---@param row InventoryPocAnalysisRow
---@return string
local function summary(row)
    if row.rank then return zo_strformat(GetString(BATTLESCROLLS_IPOC_PACK_QUEUE), row.rank, gold(row.value or 0)) end
    if row.fate == 'sell' then return zo_strformat(GetString(BATTLESCROLLS_IPOC_PACK_GOLD), gold(row.value or 0)) end
    return reasonText(row)
end

---@param list ZO_ParametricScrollList
---@param selected table|nil The entry selected before the refresh
---@return number|nil selectedIndex
function PackView:populate(list, selected)
    local result = self.analysis
    self:renderBar()
    if not result then return end
    local selectedRow = selected and selected.packRow
    local selectedIndex = selected and selected.packOverview and 1 or nil
    local overview = ZO_GamepadEntryData:New(GetString(BATTLESCROLLS_IPOC_PACK_OVERVIEW), OVERVIEW_ICON)
    overview.packOverview = true
    overview:AddSubLabel(string.format('%d / %d', result.used, result.size))
    list:AddEntry(ROW_TEMPLATE, overview)
    local index = 1
    for _, group in ipairs(result.groups) do
        local title = colored(group.class,
            zo_strformat(GetString(BATTLESCROLLS_IPOC_PACK_GROUP), GetString(FATE_TITLES[group.fate]), #group.rows))
        for position, row in ipairs(group.rows) do
            local item = row.item
            local data = ZO_GamepadEntryData:New(zo_strformat(SI_TOOLTIP_ITEM_NAME, item.name), GetItemLinkIcon(item.link))
            data:InitializeLootVisualData(nil, item.stack, item.quality, nil, false, item.stolen)
            data.packRow = row
            data:AddSubLabel(summary(row))
            if position == 1 then
                data:SetHeader(title)
                list:AddEntryWithHeader(ROW_TEMPLATE, data)
            else
                list:AddEntry(ROW_TEMPLATE, data)
            end
            index = index + 1
            if selectedRow and selectedRow.item.slot == item.slot and selectedRow.item.uniqueId == item.uniqueId then
                selectedIndex = index
            end
        end
    end
    return selectedIndex
end

---@param result InventoryPocAnalysis
local function showOverview(result)
    local lines = {}
    for _, class in ipairs(BattleScrolls.inventoryPocAnalysis.CLASSES) do
        if result.classes[class] > 0 then
            lines[#lines + 1] = colored(class,
                zo_strformat(GetString(BATTLESCROLLS_IPOC_PACK_COUNT), GetString(CLASS_TITLES[class]), result.classes[class]))
        end
    end
    details.add(lines, BATTLESCROLLS_IPOC_PACK_COUNT, GetString(BATTLESCROLLS_IPOC_CLASS_FREE), result.size - result.used)
    lines[#lines + 1] = ''
    details.add(lines, BATTLESCROLLS_IPOC_PACK_COUNT, GetString(BATTLESCROLLS_IPOC_PACK_LISTING_SLOTS),
        result.listingFree and string.format('%d / %d', result.listingFree, result.listingCapacity)
            or GetString(BATTLESCROLLS_IPOC_PACK_UNKNOWN))
    if result.waitingValue > 0 then details.add(lines, BATTLESCROLLS_IPOC_PACK_WAITING_VALUE, gold(result.waitingValue)) end
    if result.merchantValue > 0 then details.add(lines, BATTLESCROLLS_IPOC_PACK_MERCHANT_VALUE, gold(result.merchantValue)) end
    GAMEPAD_TOOLTIPS:LayoutTitleAndDescriptionTooltip(GAMEPAD_LEFT_TOOLTIP,
        GetString(BATTLESCROLLS_IPOC_PACK_OVERVIEW), table.concat(lines, '\n'))
end

---@param row InventoryPocAnalysisRow
---@param result InventoryPocAnalysis
---@return string
local function why(row, result)
    local fate, item = row.fate, row.item
    if row.buildDeposit then return GetString(BATTLESCROLLS_IPOC_WHY_BANK_BUILD) end
    if row.overflow then
        return zo_strformat(GetString(BATTLESCROLLS_IPOC_WHY_BANK_LISTING), row.rank, result.listingAllowance)
    end
    if fate == 'listWait' then
        return zo_strformat(GetString(BATTLESCROLLS_IPOC_WHY_LIST_WAIT), row.rank, result.listingFree)
    elseif fate == 'list' then
        return zo_strformat(GetString(BATTLESCROLLS_IPOC_WHY_LIST), row.rank)
    elseif fate == 'price' then
        return GetString(item.priceLoading and BATTLESCROLLS_IPOC_WHY_PRICE_LOADING or BATTLESCROLLS_IPOC_WHY_PRICE)
    elseif fate == 'info' then
        return GetString(row.decision.reason == 'companion' and BATTLESCROLLS_IPOC_WHY_COMPANION
            or BATTLESCROLLS_IPOC_WHY_KNOWLEDGE)
    end
    return GetString(FATE_WHY[fate])
end

---@param row InventoryPocAnalysisRow
---@param result InventoryPocAnalysis
local function showRow(row, result)
    local item = row.item
    local lines = { why(row, result) }
    details.add(lines, BATTLESCROLLS_IPOC_DETAIL_REASON, reasonText(row))
    if row.rank then
        details.add(lines, BATTLESCROLLS_IPOC_DETAIL_LISTING, row.quantity, gold(item.marketUnit or 0), gold(row.value or 0))
    elseif row.quantity ~= item.stack then
        details.add(lines, BATTLESCROLLS_IPOC_DETAIL_QUANTITY, row.quantity)
    end
    if item.marketUnit then
        lines[#lines + 1] = GetString(row.quoted and BATTLESCROLLS_IPOC_DETAIL_PRICE_QUOTE or BATTLESCROLLS_IPOC_DETAIL_PRICE_LIST)
    end
    if item.unsold then lines[#lines + 1] = GetString(BATTLESCROLLS_IPOC_DETAIL_UNSOLD)
    elseif row.discounted then lines[#lines + 1] = GetString(BATTLESCROLLS_IPOC_DETAIL_EXPIRED) end
    lines[#lines + 1] = ''
    details.identity(lines, item.link, item.itemId)
    details.add(lines, BATTLESCROLLS_IPOC_DETAIL_SLOT, item.slot, item.uniqueId)
    details.prices(lines, item.link, poc.logDetails(item))
    -- The rules' raw inputs, as the chat inspection printed them.
    lines[#lines + 1] = ''
    for _, fact in ipairs(poc.itemFacts(item)) do lines[#lines + 1] = fact end
    GAMEPAD_TOOLTIPS:LayoutItemWithStackCountSimple(GAMEPAD_RIGHT_TOOLTIP, item.link, item.stack)
    GAMEPAD_TOOLTIPS:LayoutTitleAndDescriptionTooltip(GAMEPAD_LEFT_TOOLTIP,
        colored(BattleScrolls.inventoryPocAnalysis.CLASS[row.fate], GetString(FATE_TITLES[row.fate])),
        table.concat(lines, '\n'))
end

---@param data table|nil The selected list entry
function PackView:showTooltip(data)
    local result = self.analysis
    if not data or not result then return end
    if data.packOverview then showOverview(result)
    elseif data.packRow then showRow(data.packRow, result) end
end
