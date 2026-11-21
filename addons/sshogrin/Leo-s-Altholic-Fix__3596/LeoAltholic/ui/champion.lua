
LeoAltholicChampionList = ZO_SortFilterList:Subclass()
function LeoAltholicChampionList:New(control)

    ZO_SortFilterList.InitializeSortFilterList(self, control)

    local sorterKeys =
    {
        ["queueIndex"] = { tiebreaker = "name" },
        ["name"] = {},
    }

    self.masterList = {}
    self.currentSortKey = "queueIndex"
    self.currentSortOrder = ZO_SORT_ORDER_UP
    ZO_ScrollList_AddDataType(self.list, 1, "LeoAltholicChampionListTemplate", 32, function(control, data) self:SetupEntry(control, data) end)

    self.sortFunction = function(listEntry1, listEntry2)
        return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, sorterKeys, self.currentSortOrder)
    end

    return self
end

function LeoAltholicChampionList:SetupEntry(control, data)
    control.data = data

    control.name = GetControl(control, "Name")
    control.name:SetText(data.name)

    local icons = {
        [LeoAltholic.CHAMPION_WARFARE] = "champion_points_magicka_icon",
        [LeoAltholic.CHAMPION_FITNESS] = "champion_points_health_icon",
        [LeoAltholic.CHAMPION_CRAFT] = "champion_points_stamina_icon"
    }

    control.disc = {};
    for disciplineIndex = 1, GetNumChampionDisciplines() do
        local disciplineId = GetChampionDisciplineId(disciplineIndex)
        control.disc[disciplineIndex] = GetControl(control, "Disc" .. disciplineIndex)
        local total = data.champion[disciplineIndex].spent + data.champion[disciplineIndex].unspent
        local color = '|c'..LeoAltholic.color.hex.green
        if data.champion[disciplineIndex].unspent > 0 then
            color = '|c'..LeoAltholic.color.hex.red
        end
        control.disc[disciplineIndex]:SetText("|t24:24:esoui/art/tutorial/" .. icons[disciplineId] .. ".dds|t "..color .. data.champion[disciplineIndex].spent .. '/' .. total .. '|r    ')
        control.disc[disciplineIndex].champion = data.champion
        control.disc[disciplineIndex].attribute = disciplineIndex
    end

    ZO_SortFilterList.SetupRow(self, control, data)
end

function LeoAltholicChampionList:BuildMasterList()
    self.masterList = {}
    local list = LeoAltholic.ExportCharacters(true)
    for k, v in ipairs(list) do
        local data = {
            name = v.bio.name,
            champion = v.champion
        }
        data.queueIndex = k
        table.insert(self.masterList, data)
    end
end

function LeoAltholicChampionList:SortScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    if self.currentSortKey == "queueIndex" then
        table.sort(scrollData, function(listEntry1, listEntry2)
            return (listEntry1.data.queueIndex or 999) < (listEntry2.data.queueIndex or 999)
        end)
    else
        table.sort(scrollData, self.sortFunction)
    end
end

function LeoAltholicChampionList:FilterScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    ZO_ClearNumericallyIndexedTable(scrollData)
    for i = 1, #self.masterList do
        local data = self.masterList[i]
        table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, data))
    end
end

local function addLine(tooltip, text, color)
    if not color then color = ZO_TOOLTIP_DEFAULT_COLOR end
    local r, g, b = color:UnpackRGB()
    tooltip:AddLine(text, "", r, g, b, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_LEFT, true)
end

local function addLineTitle(tooltip, text, color)
    if not color then color = ZO_SELECTED_TEXT end
    local r, g, b = color:UnpackRGB()
    tooltip:AddLine(text, "ZoFontHeader3", r, g, b, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
end

function LeoAltholicUI.TooltipChampionSkill(control, visible)

    local disciplineIndex = control.attribute
    local disciplineId = GetChampionDisciplineId(control.attribute)
    if visible then
        InitializeTooltip(InformationTooltip, control, LEFT, 5, 0)
        if control.champion[control.attribute] then
            addLineTitle(InformationTooltip, GetChampionDisciplineName(disciplineId).." "..control.champion[control.attribute].spent)
            for skill = 1, GetNumChampionDisciplineSkills(disciplineIndex) do
                local id = GetChampionSkillId(disciplineIndex, skill)
                local skillName = GetChampionSkillName(id)
                local points = 0
                if control.champion[control.attribute].skills[skill] then
                    points = control.champion[control.attribute].skills[skill]
                    if points > 0 then
                        addLine(InformationTooltip, "|c" ..LeoAltholic.color.hex.eso.. skillName .. "|r " .. points, ZO_SELECTED_TEXT)
                    end
                end
            end
        end
        InformationTooltip:SetHidden(false)
        InformationTooltipTopLevel:BringWindowToTop()
    else
        ClearTooltip(InformationTooltip)
        InformationTooltip:SetHidden(true)
    end
end
