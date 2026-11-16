local GroupBuilds = GroupBuilds
local ZO_SortFilterList = ZO_SortFilterList
local GetControl = GetControl
local GetClassIcon = GetClassIcon
local GetClassInfo = GetClassInfo
local GetNumClasses = GetNumClasses
local GetDateStringFromTimestamp = GetDateStringFromTimestamp
local GetTimeStamp = GetTimeStamp
local WINDOW_MANAGER = WINDOW_MANAGER

GroupBuilds.BrowserClass = ZO_SortFilterList:Subclass()

local ROLE_FILTER_ORDER = {
    LFG_ROLE_TANK,
    LFG_ROLE_HEAL,
    LFG_ROLE_DPS,
}

local function GetWhen(timestamp)
    local now = GetTimeStamp()
    if GetDateStringFromTimestamp(timestamp) == GetDateStringFromTimestamp(now) then
        return ZO_FormatDurationAgo(now - timestamp)
    end
    return GetDateStringFromTimestamp(timestamp)
end

function GroupBuilds.BrowserClass:InitializeInterface()
    self.scrollData = ZO_ScrollList_GetDataList(self.list)

    ZO_ScrollList_AddDataType(self.list, 1, 'GroupBuildsBrowserRow', 40, function(control, data)
        self:SetupRow(control, data)
    end)
    ZO_ScrollList_EnableHighlight(self.list, 'ZO_ThinListHighlight')

    self.sortKeys = {
        name = { tiebreaker = 'timestamp', tieBreakerSortOrder = ZO_SORT_ORDER_DOWN },
        timestamp = {},
    }
    self.sortFunction = function(a, b)
        return ZO_TableOrderingFunction(a.data, b.data, self.currentSortKey, self.sortKeys, self.currentSortOrder)
    end

    self:CreateFilterButtons()

    self.search = ZO_StringSearch:New()
    self.search:AddProcessor(1, function(_, data, searchTerm, _)
        return zo_plainstrfind(data.searchText, searchTerm)
    end)

    self.sortHeaderGroup:SelectHeaderByKey('timestamp')
end

function GroupBuilds.BrowserClass:CreateFilterButtons()
    local parent = GroupBuildsBrowserFilters
    local x = 0

    self.roleFilter = {}
    for _, role in ipairs(ROLE_FILTER_ORDER) do
        self.roleFilter[role] = true
        self:MakeFilterButton(parent, x, GroupBuilds:RoleIcon(role), function(button)
            self.roleFilter[role] = not self.roleFilter[role]
            button:SetAlpha(self.roleFilter[role] and 1 or 0.3)
            self:RefreshFilters()
        end)
        x = x + 34
    end

    x = x + 16

    self.classFilter = {}
    for classIndex = 1, GetNumClasses() do
        local classId = GetClassInfo(classIndex)
        self.classFilter[classId] = true
        self:MakeFilterButton(parent, x, GetClassIcon(classId), function(button)
            self.classFilter[classId] = not self.classFilter[classId]
            button:SetAlpha(self.classFilter[classId] and 1 or 0.3)
            self:RefreshFilters()
        end)
        x = x + 34
    end
end

function GroupBuilds.BrowserClass:MakeFilterButton(parent, x, icon, onClicked)
    local button = WINDOW_MANAGER:CreateControl(nil, parent, CT_BUTTON)
    button:SetDimensions(32, 32)
    button:SetAnchor(LEFT, parent, LEFT, x, 0)
    button:SetNormalTexture(icon)
    button:SetHandler('OnClicked', onClicked)
    return button
end

function GroupBuilds.BrowserClass:BuildMasterList()
    self.masterList = {}

    for id, entry in pairs(GroupBuilds.sv.saved) do
        local note = entry.note or ''
        local name = entry.name or ''
        local className = GroupBuilds:ClassName(entry.class)
        local roleName = GroupBuilds:RoleName(entry.role)
        local timestamp = entry.timestamp or 0

        table.insert(self.masterList, {
            id = id,
            note = note,
            name = name,
            class = entry.class,
            role = entry.role,
            className = className,
            roleName = roleName,
            timestamp = timestamp,
            when = GetWhen(timestamp),
            payload = entry.payload,
            searchText = (name .. ' ' .. note .. ' ' .. className .. ' ' .. roleName):lower(),
        })
    end
end

function GroupBuilds.BrowserClass:FilterScrollList()
    ZO_ClearNumericallyIndexedTable(self.scrollData)

    local search = GroupBuildsBrowser:GetNamedChild('Filters'):GetNamedChild('Search'):GetNamedChild('Box'):GetText():lower()

    for _, row in ipairs(self.masterList) do
        local show = self.roleFilter[row.role] ~= false and self.classFilter[row.class] ~= false

        if show and #search > 0 then
            show = self.search:IsMatch(search, { type = 1, searchText = row.searchText })
        end

        if show then
            table.insert(self.scrollData, ZO_ScrollList_CreateDataEntry(1, row))
        end
    end
end

function GroupBuilds.BrowserClass:SortScrollList()
    table.sort(self.scrollData, self.sortFunction)
end

function GroupBuilds.BrowserClass:SetupRow(control, data)
    control.data = data

    GetControl(control, 'Role'):SetTexture(GroupBuilds:RoleIcon(data.role))

    local classControl = GetControl(control, 'Class')
    if data.class then
        classControl:SetHidden(false)
        classControl:SetTexture(GetClassIcon(data.class))
    else
        classControl:SetHidden(true)
    end
    GetControl(control, 'Name'):SetText(data.name ~= '' and data.name or '—')
    GetControl(control, 'Date'):SetText(data.when)

    local noteControl = GetControl(control, 'Note')
    local note = data.note or ''
    noteControl.noteText = note
    noteControl:SetHidden(note == '')

    ZO_SortFilterList.SetupRow(self, control, data)
end
