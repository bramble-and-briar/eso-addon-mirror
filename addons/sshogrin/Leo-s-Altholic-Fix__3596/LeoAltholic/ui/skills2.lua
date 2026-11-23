
LeoAltholicSkills2List = ZO_SortFilterList:Subclass()
function LeoAltholicSkills2List:New(control)
    local list = ZO_Object.New(self)
    list:Initialize(control)
    return list
end

function LeoAltholicSkills2List:Initialize(control)
    ZO_SortFilterList.InitializeSortFilterList(self, control)

    local sorterKeys =
    {
        ["queueIndex"] = { tiebreaker = "name" },
        ["name"] = {},
    }

    self.masterList = {}
    self.currentSortKey = "queueIndex"
    self.currentSortOrder = ZO_SORT_ORDER_UP
    ZO_ScrollList_AddDataType(self.list, 1, "LeoAltholicSkills2ListTemplate", 32, function(rowControl, data) self:SetupEntry(rowControl, data) end)

    self.sortFunction = function(listEntry1, listEntry2)
        return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, sorterKeys, self.currentSortOrder)
    end
end

function LeoAltholicSkills2List:SetupEntry(control, data)

    control.data = data

    control.name = GetControl(control, "Name")
    control.name:SetText(data.name)

    control.world = {}
    for i = 1, 4 do
        control.world[i] = GetControl(control, "World"..i)
        control.world[i].max = LeoAltholic.GetMaxRank(SKILL_TYPE_WORLD, i)
        if data.skills.world[i] then
            control.world[i]:SetText(data.skills.world[i].rank)
            control.world[i].number = tonumber(data.skills.world[i].rank)
            control.world[i].tooltip = {
                name = data.skills.world[i].name,
                rank = data.skills.world[i].rank,
                max = control.world[i].max,
                id = data.skills.world[i].id,
                list = {}
            }
            for k, skill in ipairs(data.skills.world[i].list) do
                if data.skills.world[i].list[k].level == nil or data.skills.world[i].list[k].level > 0 then
                    table.insert(control.world[i].tooltip.list, ZO_CachedStrFormat(SI_ABILITY_NAME, data.skills.world[i].list[k].name))
                end
            end
        else
            control.world[i]:SetText("-")
            control.world[i].number = tonumber(0)
        end
    end
    control.guild = {}
    for i = 1, 6 do
        control.guild[i] = GetControl(control, "Guild"..i)
        control.guild[i].max = LeoAltholic.GetMaxRank(SKILL_TYPE_GUILD, i)
        if data.skills.guild[i] then
            control.guild[i]:SetText(data.skills.guild[i].rank)
            control.guild[i].number = tonumber(data.skills.guild[i].rank)
            control.guild[i].tooltip = {
                name = data.skills.guild[i].name,
                rank = data.skills.guild[i].rank,
                max = control.guild[i].max,
                id = data.skills.guild[i].id,
                list = {}
            }
            for k, skill in ipairs(data.skills.guild[i].list) do
                if data.skills.guild[i].list[k].level == nil or data.skills.guild[i].list[k].level > 0 then
                    table.insert(control.guild[i].tooltip.list, ZO_CachedStrFormat(SI_ABILITY_NAME, data.skills.guild[i].list[k].name))
                end
            end
        else
            control.guild[i]:SetText("-")
            control.guild[i].number = tonumber(0)
        end
    end

    control.ava = {}
    for i = 1, 3 do
        control.ava[i] = GetControl(control, "AvA"..i)
        control.ava[i].max = LeoAltholic.GetMaxRank(SKILL_TYPE_AVA, i)
        if data.skills.ava[i] then
            control.ava[i]:SetText(data.skills.ava[i].rank)
            control.ava[i].number = tonumber(data.skills.ava[i].rank)
            control.ava[i].tooltip = {
                name = data.skills.ava[i].name,
                rank = data.skills.ava[i].rank,
                max = control.ava[i].max,
                id = data.skills.ava[i].id,
                list = {}
            }
            for k, skill in ipairs(data.skills.ava[i].list) do
                if data.skills.ava[i].list[k].level == nil or data.skills.ava[i].list[k].level > 0 then
                    table.insert(control.ava[i].tooltip.list, ZO_CachedStrFormat(SI_ABILITY_NAME, data.skills.ava[i].list[k].name))
                end
            end
        else
            control.ava[i]:SetText("-")
            control.ava[i].number = tonumber(0)
        end
    end

    ZO_SortFilterList.SetupRow(self, control, data)
end

function LeoAltholicSkills2List:ColorRow(control, data, mouseIsOver)

    local color = ZO_SECOND_CONTRAST_TEXT
    local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_QUALITY_MAGIC)

    for i = 1, control:GetNumChildren() do
        local child = control:GetChild(i)
        if child then
            if child:GetType() == CT_LABEL and string.find(child:GetName(), 'Name$') then
                if data.name == LeoAltholic.CharName then
                    child:SetColor(r, g, b)
                else
                    child:SetColor(color:UnpackRGBA())
                end
            end
            if not child.nonRecolorable and child.number ~= nil then
                if child.number == child.max then
                    child:SetColor(0, 1, 0, 1)
                elseif child.number > child.max * 0.8 then
                    child:SetColor(1, 1, 0, 1)
                elseif child.number > child.max * 0.1 then
                    child:SetColor(color:UnpackRGBA())
                else
                    child:SetColor(1, 0, 0, 1)
                end
            end
        end
    end
end

function LeoAltholicSkills2List:BuildMasterList()
    self.masterList = {}
    local list = LeoAltholic.ExportCharacters(true)
    for k, v in ipairs(list) do
        local data = {
            name = v.bio.name,
            skills = v.skills
        }
        data.queueIndex = k
        table.insert(self.masterList, data)
    end
end

function LeoAltholicSkills2List:SortScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    if self.currentSortKey == "queueIndex" then
        table.sort(scrollData, function(listEntry1, listEntry2)
            return (listEntry1.data.queueIndex or 999) < (listEntry2.data.queueIndex or 999)
        end)
    else
        table.sort(scrollData, self.sortFunction)
    end
end

function LeoAltholicSkills2List:FilterScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    ZO_ClearNumericallyIndexedTable(scrollData)
    for i = 1, #self.masterList do
        local data = self.masterList[i]
        table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, data))
    end
end
