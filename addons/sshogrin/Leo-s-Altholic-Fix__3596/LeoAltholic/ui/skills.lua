
LeoAltholicSkillsList = ZO_SortFilterList:Subclass()
function LeoAltholicSkillsList:New(control)

    ZO_SortFilterList.InitializeSortFilterList(self, control)

    local sorterKeys =
    {
        ["queueIndex"] = { tiebreaker = "name" },
        ["name"] = {},
    }

    self.masterList = {}
    self.currentSortKey = "queueIndex"
    self.currentSortOrder = ZO_SORT_ORDER_UP
    ZO_ScrollList_AddDataType(self.list, 1, "LeoAltholicSkillsListTemplate", 32, function(control, data) self:SetupEntry(control, data) end)

    self.sortFunction = function(listEntry1, listEntry2)
        return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, sorterKeys, self.currentSortOrder)
    end

    return self
end

function LeoAltholicSkillsList:SetupEntry(control, data)

    control.data = data

    control.name = GetControl(control, "Name")
    control.name:SetText(data.name)

    control.craft = {}
    for i = 1, 7 do
        control.craft[i] = GetControl(control, "Craft"..i)
        control.craft[i].max = tonumber(50)
        if data.skills.craft[i] then
            control.craft[i]:SetText(data.skills.craft[i].rank)
            control.craft[i].number = tonumber(data.skills.craft[i].rank)
            control.craft[i].tooltip = {
                name = data.skills.craft[i].name,
                rank = data.skills.craft[i].rank,
                max = control.craft[i].max,
                id = data.skills.craft[i].id,
                list = {}
            }
            for k, skill in ipairs(data.skills.craft[i].list) do
                if data.skills.craft[i].list[k].level == nil or data.skills.craft[i].list[k].level > 0 then
                    table.insert(control.craft[i].tooltip.list, data.skills.craft[i].list[k].name)
                end
            end
        else
            control.craft[i]:SetText("-")
            control.craft[i].number = tonumber(0)
        end
    end

    control.armor = {}
    for i = 1, 3 do
        control.armor[i] = GetControl(control, "Armor"..i)
        control.armor[i].max = tonumber(50)
        if data.skills.armor[i] then
            control.armor[i]:SetText(data.skills.armor[i].rank)
            control.armor[i].number = tonumber(data.skills.armor[i].rank)
            control.armor[i].tooltip = {
                name = data.skills.armor[i].name,
                rank = data.skills.armor[i].rank,
                max = control.armor[i].max,
                id = data.skills.armor[i].id,
                list = {}
            }
            for k, skill in ipairs(data.skills.armor[i].list) do
                if data.skills.armor[i].list[k].level == nil or data.skills.armor[i].list[k].level > 0 then
                    table.insert(control.armor[i].tooltip.list, data.skills.armor[i].list[k].name)
                end
            end
        else
            control.armor[i]:SetText("-")
            control.armor[i].number = tonumber(0)
        end
    end

    control.weapon = {}
    for i = 1, 6 do
        control.weapon[i] = GetControl(control, "Weapon"..i)
        control.weapon[i].max = tonumber(50)
        if data.skills.weapon[i] then
            control.weapon[i]:SetText(data.skills.weapon[i].rank)
            control.weapon[i].number = tonumber(data.skills.weapon[i].rank)
            control.weapon[i].tooltip = {
                name = data.skills.weapon[i].name,
                rank = data.skills.weapon[i].rank,
                max = control.weapon[i].max,
                id = data.skills.weapon[i].id,
                list = {}
            }
            for k, skill in ipairs(data.skills.weapon[i].list) do
                if data.skills.weapon[i].list[k].level == nil or data.skills.weapon[i].list[k].level > 0 then
                    table.insert(control.weapon[i].tooltip.list, data.skills.weapon[i].list[k].name)
                end
            end
        else
            control.weapon[i]:SetText("-")
            control.weapon[i].number = tonumber(0)
        end
    end

    control.class = {}
    for i = 1, 3 do
        control.class[i] = GetControl(control, "Class"..i)
        control.class[i].max = tonumber(50)
        if data.skills.class[i] then
            control.class[i]:SetText(data.skills.class[i].rank)
            control.class[i].number = tonumber(data.skills.class[i].rank)
            control.class[i].tooltip = {
                name = data.skills.class[i].name,
                rank = data.skills.class[i].rank,
                max = control.class[i].max,
                id = data.skills.class[i].id,
                list = {}
            }
            for k, skill in ipairs(data.skills.class[i].list) do
                if data.skills.class[i].list[k].level == nil or data.skills.class[i].list[k].level > 0 then
                    table.insert(control.class[i].tooltip.list, data.skills.class[i].list[k].name)
                end
            end
        else
            control.class[i]:SetText("-")
            control.class[i].number = tonumber(0)
        end
    end

    control.racial = GetControl(control, "Racial")
    control.racial.max = tonumber(50)
    if data.skills.racial[1] then
        control.racial:SetText(data.skills.racial[1].rank)
        control.racial.number = tonumber(data.skills.racial[1].rank)
        control.racial.tooltip = {
            name = data.skills.racial[1].name,
            rank = data.skills.racial[1].rank,
            max = control.racial.max,
            list = {}
        }
        if data.skills.racial[1].list then
            for k, skill in ipairs(data.skills.racial[1].list) do
                if data.skills.racial[1].list[k].level == nil or data.skills.racial[1].list[k].level > 0 then
                    table.insert(control.racial.tooltip.list, data.skills.racial[1].list[k].name)
                end
            end
        end
    else
        control.racial:SetText("-")
        control.racial.number = tonumber(0)
    end


    ZO_SortFilterList.SetupRow(self, control, data)
end

function LeoAltholicSkillsList:ColorRow(control, data, mouseIsOver)

    local color = ZO_SECOND_CONTRAST_TEXT
    local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_QUALITY_MAGIC)

    for i = 1, control:GetNumChildren() do
        local child = control:GetChild(i)
        if child then
            if child:GetType() == CT_LABEL and child:GetName() and string.find(child:GetName(), 'Name$') then
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

function LeoAltholicSkillsList:BuildMasterList()
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

function LeoAltholicSkillsList:SortScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    if self.currentSortKey == "queueIndex" then
        table.sort(scrollData, function(listEntry1, listEntry2)
            return (listEntry1.data.queueIndex or 999) < (listEntry2.data.queueIndex or 999)
        end)
    else
        table.sort(scrollData, self.sortFunction)
    end
end

function LeoAltholicSkillsList:FilterScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    ZO_ClearNumericallyIndexedTable(scrollData)
    for i = 1, #self.masterList do
        local data = self.masterList[i]
        table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, data))
    end
end

local function addLine(tooltip, text, color)
    if not color then color = ZO_SELECTED_TEXT end
    local r, g, b = color:UnpackRGB()
    tooltip:AddLine(text, "", r, g, b, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_LEFT, true)
end

local function addLineTitle(tooltip, text, color)
    if not color then color = ZO_TOOLTIP_DEFAULT_COLOR end
    local r, g, b = color:UnpackRGB()
    tooltip:AddLine(text, "ZoFontHeader3", r, g, b, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
end

function LeoAltholicUI.TooltipSkill(control, visible)

    if visible and control.tooltip and control.tooltip.name then
        if not parent then parent = control end

        InitializeTooltip(InformationTooltip, control, LEFT, 5, 0)

        local title = ZO_CachedStrFormat(SI_ABILITY_NAME, control.tooltip.name)
        if control.tooltip.rank then
            title = title  .." - ".. control.tooltip.rank
        end
        if control.tooltip.max then
            title = title  .." / ".. control.tooltip.max
        end
        addLineTitle(InformationTooltip, title)

        for _, skill in pairs(control.tooltip.list) do
            addLine(InformationTooltip, ZO_CachedStrFormat(SI_ABILITY_NAME, skill))
        end
        InformationTooltip:SetHidden(false)
        InformationTooltipTopLevel:BringWindowToTop()
    else
        ClearTooltip(InformationTooltip)
        InformationTooltip:SetHidden(true)
    end
end
