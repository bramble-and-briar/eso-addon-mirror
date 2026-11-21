
LeoAltholicResearchList = ZO_SortFilterList:Subclass()
function LeoAltholicResearchList:New(control)

    ZO_SortFilterList.InitializeSortFilterList(self, control)

    local sorterKeys =
    {
        ["queueIndex"] = { tiebreaker = "name" },
        ["name"] = {}
    }

    self.masterList = {}
    self.currentSortKey = "queueIndex"
    self.currentSortOrder = ZO_SORT_ORDER_UP
    ZO_ScrollList_AddDataType(self.list, 1, "LeoAltholicResearchListTemplate", 32, function(control, data) self:SetupEntry(control, data) end)

    self.sortFunction = function(listEntry1, listEntry2)
        return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, sorterKeys, self.currentSortOrder)
    end

    return self
end

function LeoAltholicResearchList:SetupEntry(control, data)

    control.data = data

    control.name = GetControl(control, "Name")
	local isCurrentPlayer = (data.name == LeoAltholic.CharName)
	local now = GetTimeStamp()
    control.name:SetText(data.name)

    local color
    control.craft = {}
    for _,craft in pairs(LeoAltholic.craftResearch) do
        control.craft[craft] = GetControl(control, "Craft" .. craft)

        local researching = data.research.doing[craft] and #data.research.doing[craft] or 0
        local missing = LeoAltholic.GetNumMissingTraitsFor(craft, data.name)
        local output
        color = '|c'..LeoAltholic.color.hex.green

        local first
        local list = {}
        for _, research in pairs(data.research.doing[craft]) do
		
		if isCurrentPlayer then
		local _, remaining = GetSmithingResearchLineTraitTimes(craft, research.line, research.trait)
			research.doneAt = remaining + now
		else
		local remaining = GetDiffBetweenTimeStamps(research.doneAt, now)
		research.doneAt = remaining + now
		end

            if research.doneAt ~= nil and research.doneAt - GetTimeStamp() < 0 then
                researching = researching - 1
            elseif first == nil then
                first = research
            end

            local lineName, lineIcon = GetSmithingResearchLineInfo(craft, research.line)
            local traitType = GetSmithingResearchLineTraitInfo(craft, research.line, research.trait)
            local traitName = GetString('SI_ITEMTRAITTYPE', traitType)

            local d = {
                craft = craft,
                line = research.line,
                trait = research.trait,
                lineName = lineName,
                lineIcon = lineIcon,
                traitName = traitName,
                doneAt = research.doneAt,
                timer = ''
            }
            if research.doneAt ~= nil then
                d.timer = LeoAltholic.FormatTime(research.doneAt - GetTimeStamp(), false, true)
            end
            table.insert(list, d)
        end

        if researching == 0 and missing == 0 then
            output = color..ZO_CachedStrFormat(SI_ACHIEVEMENTS_TOOLTIP_COMPLETE).."|r"
            list = {}
        else
            if researching < data.research.done[craft].max and researching < missing then
                color = '|c'..LeoAltholic.color.hex.red
            end
            if researching > data.research.done[craft].max then researching = data.research.done[craft].max end

            output = color .. researching .. '/' .. data.research.done[craft].max .. '|r'
            color = '|c'..LeoAltholic.color.hex.white
            if first and first.doneAt ~= nil and first.doneAt - GetTimeStamp() <= 3600 then
                color = '|c'..LeoAltholic.color.hex.yellow
            end
            if first ~= nil then
                if first.doneAt ~= nil then
                    output = output .. " " .. color..LeoAltholic.FormatTime(first.doneAt - GetTimeStamp(), false, true) .. '|r'
                end
            end
        end
        control.craft[craft]:SetText(output)
        control.craft[craft].list = list
    end

    ZO_SortFilterList.SetupRow(self, control, data)
end

function LeoAltholicResearchList:ColorRow(control, data, mouseIsOver)

    local color = ZO_SECOND_CONTRAST_TEXT
    local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_QUALITY_MAGIC)

    local child = GetControl(control, "Name")
    if data.name == LeoAltholic.CharName then
        child:SetColor(r, g, b)
    else
        child:SetColor(color:UnpackRGBA())
    end
end

function LeoAltholicResearchList:BuildMasterList()
    self.masterList = {}
    local list = LeoAltholic.ExportCharacters(true)
    for k, v in ipairs(list) do
        local data = {
            name = v.bio.name,
            research = v.research
        }
        data.queueIndex = k
        table.insert(self.masterList, data)
    end
end

function LeoAltholicResearchList:SortScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    if self.currentSortKey == "queueIndex" then
        table.sort(scrollData, function(listEntry1, listEntry2)
            return (listEntry1.data.queueIndex or 999) < (listEntry2.data.queueIndex or 999)
        end)
    else
        table.sort(scrollData, self.sortFunction)
    end
end

function LeoAltholicResearchList:FilterScrollList()
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

function LeoAltholicUI.TooltipResearch(control, visible)

    if visible then
        if #control.list == 0 then return end
        if not parent then parent = control end

        InitializeTooltip(InformationTooltip, control, LEFT, -30, 0)

        addLineTitle(InformationTooltip, ZO_CachedStrFormat(SI_ABILITY_NAME, GetCraftingSkillName(control.list[1].craft)))

        for _, trait in pairs(control.list) do
            addLine(InformationTooltip, "|t30:30:"..trait.lineIcon.."|t "..trait.traitName.." "..trait.lineName.." |cff0000"..trait.timer)
        end

        InformationTooltip:SetHidden(false)
        InformationTooltipTopLevel:BringWindowToTop()
    else
        ClearTooltip(InformationTooltip)
        InformationTooltip:SetHidden(true)
    end
end

function LeoAltholicUI:updateResearch()
    LeoAltholicUI.researchList:RefreshData()
end
