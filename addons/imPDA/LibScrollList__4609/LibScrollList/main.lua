local class = IMP_LibScrollList__class

local deep_table_copy = ZO_DeepTableCopy

-- ----------------------------------------------------------------------------

local addon = {}

-- ----------------------------------------------------------------------------

local function __applyStyle(ctrl, style)
    for method, args in pairs(style) do
        if type(method) == 'function' then  -- [function(ctrl) ... end] = {...}
            method(ctrl, unpack(args))
        elseif type(method) == 'number' then  -- {'SetHandler', 'OnMouseOver', function(ctrl) ... end}
            ctrl[args[1]](ctrl, select(2, unpack(args)))
        else
            ctrl[method](ctrl, unpack(args))  -- SetHandler = {'OnMouseOver', function(ctrl) ... end}
        end
    end
end

local labelPrimitiveSetFunction = function(ctrl, value) ctrl:SetText(value) end
local texturePrimitiveSetFunction = function(ctrl, value) ctrl:SetTexture(value) end
local buttonPrimitiveSetStateFunction = function(ctrl, nexState, locked) ctrl:SetState(nexState, locked) end

-- TODO: for console separate style?
local DEFAULT_LABEL_STYLE = {
    SetFont = {'ZoFontWinH4'},
    SetHorizontalAlignment = {TEXT_ALIGN_RIGHT},
    SetColor = {1, 1, 1, 1},
}

local DEFAULT_TEXTURE_STYLE = {
    SetDimensions = {32, 32},
}

local Label = class()

function Label:__init(style, setFn)
    self.style = style or DEFAULT_LABEL_STYLE
    self.setFn = setFn or labelPrimitiveSetFunction
end

function Label:Create(name, parent, width)
    local label = CreateControl(('$(parent)%s'):format(name), parent, CT_LABEL)
    label:SetWidth(width)

    __applyStyle(label, self.style)

    return label
end

function Label:Set(ctrl, value)
    self.setFn(ctrl, value)
end

function Label:Copy()
    local style = deep_table_copy(self.style)
    return Label(style, self.setFn)
end


local Texture = class()

function Texture:__init(style, setFn)
    self.style = style or DEFAULT_TEXTURE_STYLE
    self.setFn = setFn or texturePrimitiveSetFunction
end

function Texture:Create(name, parent, width)
    local container = CreateControl(('$(parent)%s'):format(name), parent, CT_CONTROL)
    container:SetWidth(width)

    local icon = CreateControl('$(parent)Icon', container, CT_TEXTURE)
    icon:SetAnchor(CENTER)

    __applyStyle(icon, self.style)

    return container
end

function Texture:Set(ctrl, value)
    self.setFn(ctrl:GetNamedChild('Icon'), value)
end

function Texture:Copy()
    local style = deep_table_copy(self.style)
    return Texture(style, self.setFn)
end


local Button = class()

function Button:__init(style, setFn, callback)
    self.style = style or {}
    self.setFn = setFn or buttonPrimitiveSetStateFunction
    self.cb = callback
end

function Button:Create(name, parent, width)
    local container = CreateControl(('$(parent)%s'):format(name), parent, CT_CONTROL)
    container:SetWidth(width)

    local button = CreateControl('$(parent)Button', container, CT_BUTTON)
    button:SetAnchor(CENTER)

    if self.cb then
        -- button:SetMouseEnabled(true)
        button:SetHandler('OnClicked', self.cb)
    end

    __applyStyle(button, self.style)

    return container
end

function Button:Set(ctrl, newState, locked)
    self.setFn(ctrl:GetNamedChild('Button'), newState, locked)
end

-- ----------------------------------------------------------------------------

local Column = class()

function Column:__init(name, width, offsetX, cell, headerText, header, sortable)
    -- TODO: check if type is in mapping
    self.width = width
    self.offsetX = offsetX
    self.name = name
    self.cell = cell
    self.sortable = sortable

    self.header = header
    self.headerText = headerText == nil and '' or headerText
    -- TODO: header text is not 100% correct name because in case of button - ButtonState can be used, etc.

    if not header then
        local copiedCell = cell:Copy()

        if copiedCell.__index == Label then
            copiedCell.style.SetModifyTextType = {MODIFY_TEXT_TYPE_UPPERCASE}
            copiedCell.style.SetColor = {ZO_NORMAL_TEXT:UnpackRGBA()}
        end

        self.header = copiedCell
    end
end

function Column:CreateCell(parent)
    return self.cell:Create(self.name, parent, self.width)
end

function Column:CreateHeader(parent)
    local header = self.header:Create(self.name, parent, self.width)
    self:SetHeader(header, self.headerText)
    return header
end

function Column:Set(ctrl, value)
    return self.cell:Set(ctrl, value)
end

function Column:SetHeader(ctrl, value)
    if self.header then
       return self.header:Set(ctrl, value)
    else
        return self:Set(ctrl, value)
    end
end


local SCROLL_LIST_UNIFORM = 1
local SCROLL_LIST_NON_UNIFORM = 2
local SCROLL_LIST_OPERATIONS = 3
local NO_HEIGHT_SET = -1
local function UpdateModeFromHeight(self, height)
    if self.mode == SCROLL_LIST_UNIFORM then
        if self.uniformControlHeight == NO_HEIGHT_SET then
            self.uniformControlHeight = height
        elseif height ~= self.uniformControlHeight then
            self.uniformControlHeight = nil
            self.mode = SCROLL_LIST_NON_UNIFORM
            ZO_ScrollList_Commit(self)
        end
    end
end

local Table = class()

function Table:__init(withHeaders)
    self.__dataTypes = {}
    -- self.__headerDataType = nil
    -- self.__headerSpec = nil

    self.withHeaders = withHeaders

    self.isCreated = false

    self.headerControls = {}

    self.sortCriteria = {}
    self.defaultSortingCriteria = {{columnIndex = 1, order = ZO_SORT_ORDER_UP}}  -- TODO: allow custom default sort ccriteria
end

function Table:SetDefaultSortingCriteria(...)
    local args = {...}
    assert(#args % 2 == 0, 'Even number of arguments must be provided!')

    local defaults = self.defaultSortingCriteria

    ZO_ClearNumericallyIndexedTable(defaults)
    for i = 1, #args, 2 do
        defaults[#defaults+1] = {columnIndex = args[i], order = args[i+1]}
    end
end

function Table:SetHeadersHidden(hidden)
    -- it always created, even if no headers set, so we are safe here
    self.headerContainer:SetHidden(hidden)

    -- reanchoring is kinda meh, so just shift instead of header should work fine
    local offsetY = hidden and -self.headerContainer:GetHeight() or 0
    self.scroll:SetAnchorOffsets(0, offsetY)

    ZO_ScrollList_Commit(self.scroll)
end

function Table:SetMulticolumnSortingEnabled(enabled)
    self.multicolumnSort = enabled
end

function Table:ClearSorting()
    for c, criteria in pairs(self.sortCriteria) do
        local columnIndex = criteria.columnIndex
        self.sortCriteria[c] = nil
        self:__updateSortingIndicator(self.headerControls[columnIndex])
    end

    self:__doSorting()

    ZO_ScrollList_Commit(self.scroll)
end

function Table:AddDataType(dataTypeId, columns, height, postCreateCallback, postSetupCallback)
    assert(not self.__dataTypes[dataTypeId], 'Data type already added')

    self.__dataTypes[dataTypeId] = {
        columns = columns,
        height = height,
        postCreate = postCreateCallback,
        postSetup = postSetupCallback,
    }
end

-- function Table:AddHeader(dataTypeId, headerSpec, headerHeight)
--     assert(self.__dataTypes[dataTypeId], 'Data type not added yet')

--     self.__headerDataType = dataTypeId
--     self.__headerSpec = headerSpec
--     self.__headerHeight = headerHeight
-- end

function Table:Create(name, parent, replace)
    assert(not self.isCreated, 'Table already created')

    local container
    if replace then
        container = parent:GetNamedChild(name)
        assert(container, 'Control not found!')
    else
        container = CreateControl(('$(parent)%s'):format(name), parent, CT_CONTROL)
    end

    -- if no header set, it will be empty container, kinda meh
    -- but it simplifies things a bit, no infinite checks all around
    local header = CreateControl('$(parent)Header', container, CT_CONTROL)
    header:SetAnchor(TOPLEFT, container, TOPLEFT)
    header:SetAnchor(TOPRIGHT, container, TOPRIGHT)
    self.headerContainer = header

    local scroll = CreateControlFromVirtual('$(parent)ScrollList', container, 'ZO_ScrollList')
    scroll:SetAnchor(TOPLEFT, header, BOTTOMLEFT)
    scroll:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT)
    self.scroll = scroll

    -- TODO: iterates contiguous numeric ids starting at 1
    -- string or sparse ids are skipped silently
    for id = 1, #self.__dataTypes do
        self:__addDataType(id)
    end

    self.container = container

    if self.withHeaders then
        self:__buildHeaders()
    end

    self.isCreated = true
    return container
end

function Table:Update(dataTypeId, data)
    assert(self.isCreated, 'Call Create() before Update()')
    assert(self.__dataTypes[dataTypeId], 'Unknown data type: ' .. dataTypeId)

    local dataList = ZO_ScrollList_GetDataList(self.scroll)
    ZO_ScrollList_Clear(self.scroll)

    for i = 1, #data do
        dataList[i] = ZO_ScrollList_CreateDataEntry(dataTypeId, data[i])
    end

    self:__doSorting()

    ZO_ScrollList_Commit(self.scroll)
end

function Table:Clear()
    ZO_ScrollList_Clear(self.scroll)
end

function Table:GetDataList()
    return ZO_ScrollList_GetDataList(self.scroll)
end

function Table:Commit()
    self:__doSorting()
    ZO_ScrollList_Commit(self.scroll)
end

function Table:__addDataType(dataTypeId)
    local scroll = self.scroll

    local dataTypeSpec = self.__dataTypes[dataTypeId]
    local columns, height = dataTypeSpec.columns, dataTypeSpec.height

    local postCreate = self.__dataTypes[dataTypeId].postCreate
    local factory = function(objectPool)
        local newRow = CreateControlFromVirtual(
            ('$(parent)Row%s_'):format(dataTypeId),scroll.contents, 'ZO_SelectableLabel',
            objectPool:GetNextControlId()
        )
        newRow:SetHeight(height)

        local previousCell
        for _, column in ipairs(columns) do
            local newCell = column:CreateCell(newRow)
            -- local _, _, _, _, offsetX = newCell:GetAnchor()
            newCell:ClearAnchors()
            if previousCell then
                newCell:SetAnchor(LEFT, previousCell, RIGHT, column.offsetX, 0)
            else
                newCell:SetAnchor(LEFT, nil, nil, column.offsetX, 0)
            end
            previousCell = newCell
        end

        if postCreate then
            postCreate(newRow)
        end

        return newRow
    end

    local postSetup = self.__dataTypes[dataTypeId].postSetup
    local setupCallback = function(rowControl, dataEntryData, scrollList)
        for i, column in ipairs(columns) do
            local e = rowControl:GetNamedChild(column.name)
            if e then
                column:Set(e, dataEntryData[i])
            end
        end

        if postSetup then
            postSetup(rowControl, dataEntryData, scrollList)
        end
    end

    local pool = ZO_ObjectPool:New(factory, ZO_ObjectPool_DefaultResetControl)

    scroll.dataTypes[dataTypeId] = {
        height = height,
        setupCallback = setupCallback,
        hideCallback = nil,
        pool = pool,
        selectSound = nil,
        selectable = true,
    }

    UpdateModeFromHeight(scroll, height)
end

local function HeaderLabel_ColorText(label, over, columnObject)
    local normalColor = columnObject.header.style.SetColor  -- or ZO_NORMAL_TEXT
    local highlightColor = label.defaultHighlightColor or ZO_HIGHLIGHT_TEXT

    if over then
        label:SetColor(highlightColor:UnpackRGBA())  -- TODO: custom height color
    else
        if normalColor then
            label:SetColor(unpack(normalColor))
        end
    end

    -- else
    --     local disabledColor = label.defaultDisabledColor or ZO_DISABLED_TEXT
    --     label:SetColor(disabledColor:UnpackRGBA())
    -- end
end

local SORT_INDICATOR_HEIGHT = 12
local SORT_INDICATOR_WIDTH = 16
function Table:__buildHeaders()
    local headerContainer = self.headerContainer

    -- TODO: limitation for now, only dataType = 1 can have header
    -- TODO: future feature - change headers
    local dataTypeId = 1

    local dataTypeSpec = self.__dataTypes[dataTypeId]
    local columns = dataTypeSpec.columns
    -- local headerSpec = self.__headerSpec

    local headerHeight = self.__headerHeight or dataTypeSpec.height

    ZO_ClearTable(self.headerControls)  -- TODO: zo clear numerically indexed table?

    local previousHeader
    for i, column in ipairs(columns) do
        -- local columnSpec = headerSpec[i]
        -- local headerText = columnSpec[1]
        -- local overrides = columnSpec[2] or {}

        local headerColumnCtrl = column:CreateHeader(headerContainer)
        headerColumnCtrl:SetDimensionConstraints(0, headerHeight, 0, 0)

        -- TODO: header text is bad naming, it can be texture as well
        -- headerColumnCtrl[column.__setFn](headerColumnCtrl, headerText)
        -- column:SetHeader(headerColumnCtrl, headerText)

        -- for methodName, args in pairs(overrides) do
        --     headerColumnCtrl[methodName](headerColumnCtrl, unpack(args))
        -- end

        local sortable = column.sortable

        headerColumnCtrl.dataTypeId = dataTypeId
        headerColumnCtrl.columnIndex = i
        headerColumnCtrl.table = self

        if sortable then
            headerColumnCtrl:SetMouseEnabled(true)
            headerColumnCtrl:SetHandler('OnMouseDown', self.__onHeaderClick)

            if not headerColumnCtrl:GetHandler('OnMouseEnter') then
                if headerColumnCtrl.SetText then
                    headerColumnCtrl:SetHandler('OnMouseEnter', function() HeaderLabel_ColorText(headerColumnCtrl, true, column) end)
                    headerColumnCtrl:SetHandler('OnMouseExit', function() HeaderLabel_ColorText(headerColumnCtrl, false, column) end)
                end
            end

            local sortingIndicator = CreateControl('$(parent)SortingIndicator', headerColumnCtrl, CT_CONTROL)  -- TODO: virtual control
            sortingIndicator:SetResizeToFitDescendents(true)
            sortingIndicator:SetDimensionConstraints(0, 0, 0, SORT_INDICATOR_HEIGHT)

            local sortingLabel = CreateControl('$(parent)Label', sortingIndicator, CT_LABEL)
            sortingLabel:SetAnchor(LEFT)
            sortingLabel:SetFont('ZoFontWinH5')
            sortingLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

            local sortingIcon = CreateControl('$(parent)Icon', sortingIndicator, CT_TEXTURE)
            sortingIcon:SetDimensions(SORT_INDICATOR_WIDTH, SORT_INDICATOR_HEIGHT)
            sortingIcon:SetAnchor(LEFT, sortingLabel, RIGHT)

            -- TODO: is acces by attribute like heacderControl.sortingIndicator is fater than GetNamedChild?
            self:__updateSortingIndicator(headerColumnCtrl)
        end

        -- local _, _, _, _, offsetX = headerColumnCtrl:GetAnchor()
        headerColumnCtrl:ClearAnchors()

        if previousHeader then
            headerColumnCtrl:SetAnchor(LEFT, previousHeader, RIGHT, column.offsetX, 0)
        else
            headerColumnCtrl:SetAnchor(LEFT, nil, nil, column.offsetX, 0)
        end

        previousHeader = headerColumnCtrl

        self.headerControls[i] = headerColumnCtrl
    end

    if true then  -- if there are sortable coulmns
        headerHeight = headerHeight + SORT_INDICATOR_HEIGHT * 2
    end
    headerContainer:SetDimensionConstraints(0, headerHeight, 0, 0)
    -- headerContainer:SetDimensions(nil, headerHeight)
end

local function MultiSortCompare(left, right, criteria)
    for c = 1, #criteria do
    -- for _, crit in ipairs(criteria) do
        local crit = criteria[c]
        local col = crit.columnIndex
        local l = left[col]
        local r = right[col]

        local lIsNil = (l == nil)
        local rIsNil = (r == nil)

        -- nil handling: non‑nil always comes first (independent of direction)
        if lIsNil ~= rIsNil then
            return not lIsNil   -- true if l is non‑nil and r is nil
        end

        if not lIsNil then
            if l < r then
                return crit.order == ZO_SORT_ORDER_UP
            elseif l > r then
                return crit.order == ZO_SORT_ORDER_DOWN
            end
        end
    end

    return false
end

local function _getNextSortingOrder(currentSortingOrder)
    if currentSortingOrder == ZO_SORT_ORDER_UP then
        return ZO_SORT_ORDER_DOWN
    elseif currentSortingOrder == ZO_SORT_ORDER_DOWN then
        return
    elseif currentSortingOrder == nil then
        return ZO_SORT_ORDER_UP
    end
end

function Table.__onHeaderClick(headerCtrl)
    local self = headerCtrl.table
    local columnIndex = headerCtrl.columnIndex

    local existingIndex = nil
    for i, criterium in ipairs(self.sortCriteria) do
        if criterium.columnIndex == columnIndex then
            existingIndex = i
            break
        end
    end

    if existingIndex then
        local criterium = self.sortCriteria[existingIndex]
        local nextOrder = _getNextSortingOrder(criterium.order)
        if nextOrder ~= nil then
            criterium.order = nextOrder
        else
            table.remove(self.sortCriteria, existingIndex)

            for i, criterium_ in ipairs(self.sortCriteria) do
                local columnIndex_ = criterium_.columnIndex
                local headerControl = self.headerControls[columnIndex_]
                headerControl:GetNamedChild('SortingIndicatorLabel'):SetText(i)
            end

        end
    else
        if #self.sortCriteria > 0 and not self.multicolumnSort then
            local headerToRemoveIndicatorFrom = self.headerControls[self.sortCriteria[1].columnIndex]
            ZO_ClearNumericallyIndexedTable(self.sortCriteria)  -- TODO: waisiting table
            self:__updateSortingIndicator(headerToRemoveIndicatorFrom)
        end
        table.insert(self.sortCriteria, {columnIndex = columnIndex, order = ZO_SORT_ORDER_UP})
    end

    self:__doSorting()

    ZO_ScrollList_Commit(self.scroll)

    self:__updateSortingIndicator(headerCtrl)
end

function Table:DefaultSortCompare(left, right)
    local criteria = (#self.sortCriteria > 0) and self.sortCriteria or self.defaultSortingCriteria
    if not criteria then
        return false
    end
    return MultiSortCompare(left.data, right.data, criteria)
end

function Table:SetSortComparator(fn)
    self.sortComparator = fn
end

function Table:__doSorting()
    local scrollData = ZO_ScrollList_GetDataList(self.scroll)

    if self.sortComparator then
        table.sort(scrollData, self.sortComparator)
    else
        local criteria = (#self.sortCriteria > 0) and self.sortCriteria or self.defaultSortingCriteria
        if criteria then
            table.sort(scrollData, function(left, right)
                return MultiSortCompare(left.data, right.data, criteria)
            end)
        end
    end
end

local ANCHORS_TABLE = {
    [TEXT_ALIGN_LEFT] = {
        [ZO_SORT_ORDER_UP]   = TOPLEFT,
        [ZO_SORT_ORDER_DOWN] = BOTTOMLEFT,
    },
    [TEXT_ALIGN_CENTER] = {
        [ZO_SORT_ORDER_UP]   = TOP,
        [ZO_SORT_ORDER_DOWN] = BOTTOM,
    },
    [TEXT_ALIGN_RIGHT] = {
        [ZO_SORT_ORDER_UP]   = TOPRIGHT,
        [ZO_SORT_ORDER_DOWN] = BOTTOMRIGHT,
    },
}

function Table:__updateSortingIndicator(c)
    local sortingIndicator = c:GetNamedChild('SortingIndicator')
    local columnIndex = c.columnIndex

    local existingIndex = nil
    for i, criterium in ipairs(self.sortCriteria) do
        if criterium.columnIndex == columnIndex then
            existingIndex = i
            break
        end
    end

    if not existingIndex then
        sortingIndicator:SetHidden(true)
        return
    end

    local sortingOrder = self.sortCriteria[existingIndex].order

    local offsetX, point, relativePoint, texture

    local hAlignment
    if c.SetText then  -- TODO: add method GetAlignment? AddIndicator(top/bottom)?
        hAlignment = c:GetHorizontalAlignment()
        if hAlignment == TEXT_ALIGN_CENTER then
            offsetX = 0
        elseif hAlignment == TEXT_ALIGN_LEFT then
            offsetX = c:GetTextWidth() / 2
        elseif hAlignment == TEXT_ALIGN_RIGHT then
            offsetX = -c:GetTextWidth() / 2
        end
    else
        hAlignment = TEXT_ALIGN_CENTER
        offsetX = 0
    end

    if sortingOrder == ZO_SORT_ORDER_UP then
        point = BOTTOM
        texture = '/esoui/art/miscellaneous/list_sortup.dds'
    else  -- nil handled above
        point = TOP
        texture = '/esoui/art/miscellaneous/list_sortdown.dds'
    end
    relativePoint = ANCHORS_TABLE[hAlignment][sortingOrder]

    sortingIndicator:ClearAnchors()
    sortingIndicator:SetAnchor(point, c, relativePoint, offsetX, 0)

    sortingIndicator:GetNamedChild('Icon'):SetTexture(texture)
    sortingIndicator:GetNamedChild('Label'):SetText(self.multicolumnSort and existingIndex or '')
    sortingIndicator:SetHidden(false)
end

function Table:ResizeToFitNRows(dataTypeId, num)
    self.container:SetHeight(num * self.__dataTypes[dataTypeId].height + self.headerContainer:GetHeight())
end


local function _deep_merge(base, overrides)
    if type(base) ~= 'table' or type(overrides) ~= 'table' then
        return overrides
    end

    local result = {}

    for k, v in pairs(base) do
        result[k] = v
    end

    for k, v in pairs(overrides) do
        if type(v) == 'table' and type(result[k]) == 'table' then
            result[k] = _deep_merge(result[k], v)
        else
            result[k] = v
        end
    end

    return result
end

addon.combine = _deep_merge


addon.Table = Table
addon.ScrollList = Table
addon.Label = Label
addon.Texture = Texture
addon.Button = Button
addon.Column = Column


local alignLeft = {SetHorizontalAlignment = {TEXT_ALIGN_LEFT}}
local alignCenter = {SetHorizontalAlignment = {TEXT_ALIGN_CENTER}}
local alignRight = {SetHorizontalAlignment = {TEXT_ALIGN_RIGHT}}

addon.Defaults = {
    LabelLeft   = Label(_deep_merge(DEFAULT_LABEL_STYLE, alignLeft)),
    LabelRight  = Label(_deep_merge(DEFAULT_LABEL_STYLE, alignRight)),
    LabelCenter = Label(_deep_merge(DEFAULT_LABEL_STYLE, alignCenter)),
}

LibScrollList = addon

-- TODO: parity gaps vs. ZO_ScrollList:
--   per-type hideCallback / resetControlCallback / equalityFunction
--   categories (categoryId on data entries)
--   operations (ZO_SCROLL_LIST_OPERATION_ADVANCE_CURSOR / LINE_BREAK via AddOperation)
--   selection and highlight (EnableSelection / EnableHighlight)
--   selection-aware Clear (currently raw ZO clear only)

IMP_LibScrollList__class = nil
