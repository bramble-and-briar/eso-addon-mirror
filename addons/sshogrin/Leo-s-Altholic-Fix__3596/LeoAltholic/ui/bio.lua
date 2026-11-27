local LeoAltholic = LeoAltholic
LeoAltholic.BioList = ZO_SortFilterList:Subclass()
function LeoAltholic.BioList:New(control)

    ZO_SortFilterList.InitializeSortFilterList(self, control)

    local sorterKeys =
    {
        ["queueIndex"] = { tiebreaker = "name" },
        ["name"] = {},
        ["level"] = { tiebreaker = "name"},
        ["race"] = { tiebreaker = "level"},
        ["class"] = { tiebreaker = "race"},
        ["alliance"] = { tiebreaker = "class"},
        ["riding"] = { tiebreaker = "alliance"},
    }

    self.masterList = {}
    self.currentSortKey = "queueIndex"
    self.currentSortOrder = ZO_SORT_ORDER_UP
    ZO_ScrollList_AddDataType(self.list, 1, "LeoAltholicBioListTemplate", 32, function(control, data) self:SetupEntry(control, data) end)

    self.sortFunction = function(listEntry1, listEntry2)
        return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, sorterKeys, self.currentSortOrder)
    end

    return self
end

function LeoAltholic.BioList:SetupEntry(control, data)

    control.data = data

    control.name = GetControl(control, "Name")
    control.name:SetText(data.name)

    control.level = GetControl(control, "Level")
    if data.isChampion then
        control.level:SetText("|t24:24:esoui/art/champion/champion_icon.dds|t" .. data.championPoints)
    else
        control.level:SetText(data.level)
    end

    control.race = GetControl(control, "Race")
    local raceName = GetRaceName(data.gender, data.raceId) or GetString(SI_UNKNOWN_RACE)
    control.race:SetText(ZO_CachedStrFormat(SI_RACE_NAME, raceName))

    control.class = GetControl(control, "Class")
    control.class:SetText(ZO_CachedStrFormat(SI_CLASS_NAME, GetClassName(data.gender, data.classId)))

    control.alliance = GetControl(control, "Alliance")
    local color, icon, allianceName
    if data.alliance.id == ALLIANCE_ALDMERI_DOMINION then
        icon = 'esoui/art/guild/guildbanner_icon_aldmeri.dds'
        allianceName = ZO_CachedStrFormat(SI_ALLIANCE_NAME, GetAllianceName(ALLIANCE_ALDMERI_DOMINION))
    elseif data.alliance.id == ALLIANCE_EBONHEART_PACT then
        icon = 'esoui/art/guild/guildbanner_icon_ebonheart.dds'
        allianceName = ZO_CachedStrFormat(SI_ALLIANCE_NAME, GetAllianceName(ALLIANCE_EBONHEART_PACT))
    elseif data.alliance.id == ALLIANCE_DAGGERFALL_COVENANT then
        icon = 'esoui/Art/guild/guildbanner_icon_daggerfall.dds'
        allianceName = ZO_CachedStrFormat(SI_ALLIANCE_NAME, GetAllianceName(ALLIANCE_DAGGERFALL_COVENANT))
    end
    control.alliance:SetText("|t30:30:" .. icon .. "|t ".. allianceName)

    control.riding = GetControl(control, "Riding")
    local riding = '|t20:20:esoui/art/mounts/ridingskill_speed.dds|t' .. string.format("%02d%%", data.riding.speed) ..
            ' |t20:20:esoui/art/mounts/ridingskill_stamina.dds|t' .. string.format("%02d", data.riding.stamina) ..
            ' |t20:20:esoui/art/mounts/ridingskill_capacity.dds|t' .. string.format("%02d", data.riding.capacity)
    if (data.riding.speed < data.riding.speedMax or
            data.riding.stamina < data.riding.staminaMax or
            data.riding.capacity < data.riding.capacityMax) then
        riding = riding .. ' |t22:22:esoui/art/miscellaneous/timer_32.dds|t' .. LeoAltholic.FormatTime(data.riding.time - GetTimeStamp(), true, true)
    end
    control.riding:SetText(riding)
    control.riding.riding = data.riding

    ZO_SortFilterList.SetupRow(self, control, data)
end

function LeoAltholic.BioList:ColorRow(control, data, mouseIsOver)

    local color = ZO_SECOND_CONTRAST_TEXT
    local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_QUALITY_MAGIC)

    for i = 1, control:GetNumChildren() do
        local child = control:GetChild(i)
        if child then
            if data.name == LeoAltholic.CharName then
                child:SetColor(r, g, b)
            else
                child:SetColor(color:UnpackRGBA())
            end
        end
    end
end

function LeoAltholic.BioList:BuildMasterList()
    self.masterList = {}
    local list = LeoAltholic.ExportCharacters(true)
    for k, v in ipairs(list) do
        local data = {
            name = v.bio.name,
            level = v.bio.level,
            championPoints = v.bio.championPoints,
            isChampion = v.bio.isChampion,
            gender = v.bio.gender,
            race = v.bio.race,
            raceId = v.bio.raceId,
            class = v.bio.class,
            classId = v.bio.classId,
            alliance = v.bio.alliance,
            riding = v.attributes.riding
        }
        data.queueIndex = k
        table.insert(self.masterList, data)
    end
end

function LeoAltholic.BioList:SortScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    if self.currentSortKey == "queueIndex" then
        table.sort(scrollData, function(listEntry1, listEntry2)
            return (listEntry1.data.queueIndex or 999) < (listEntry2.data.queueIndex or 999)
        end)
    elseif self.currentSortKey == "alliance" then
        table.sort(scrollData, function(listEntry1, listEntry2)
            if self.currentSortOrder == ZO_SORT_ORDER_UP then
                return listEntry1.data.alliance.name < listEntry2.data.alliance.name
            else
                return listEntry1.data.alliance.name > listEntry2.data.alliance.name
            end
        end)
    elseif self.currentSortKey == "riding" then
        table.sort(scrollData, function(listEntry1, listEntry2)
            local sum1 = listEntry1.data.riding.speed + listEntry1.data.riding.stamina + listEntry1.data.riding.capacity
            local sum2 = listEntry2.data.riding.speed + listEntry2.data.riding.stamina + listEntry2.data.riding.capacity
            if self.currentSortOrder == ZO_SORT_ORDER_UP then
                return sum1 < sum2
            else
                return sum1 > sum2
            end
        end)
    else
        table.sort(scrollData, self.sortFunction)
    end
end

function LeoAltholic.UI:updateBio()
    local control = LeoAltholicWindowBioPanelListScrollListContents
    for i = 1, control:GetNumChildren() do
        local child = control:GetChild(i):GetChild(8)
		if child ~= nil then
        local riding = '|t20:20:esoui/art/mounts/ridingskill_speed.dds|t' .. string.format("%02d%%", child.riding.speed) ..
                ' |t20:20:esoui/art/mounts/ridingskill_stamina.dds|t' .. string.format("%02d", child.riding.stamina) ..
                ' |t20:20:esoui/art/mounts/ridingskill_capacity.dds|t' .. string.format("%02d", child.riding.capacity)

        if (child.riding.speed < child.riding.speedMax or
                child.riding.stamina < child.riding.staminaMax or
                child.riding.capacity < child.riding.capacityMax) then
            riding = riding .. ' |t22:22:esoui/art/miscellaneous/timer_32.dds|t' .. LeoAltholic.FormatTime(child.riding.time - GetTimeStamp(), true, true)
        end
        child:SetText(riding)
		end
    end
end

function LeoAltholic.BioList:FilterScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    ZO_ClearNumericallyIndexedTable(scrollData)
    for i = 1, #self.masterList do
        local data = self.masterList[i]
        table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, data))
    end
end
