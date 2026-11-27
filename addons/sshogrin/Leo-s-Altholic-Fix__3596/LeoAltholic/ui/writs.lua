local LeoAltholic = LeoAltholic
LeoAltholic.WritsList = ZO_SortFilterList:Subclass()
function LeoAltholic.WritsList:New(control)

    ZO_SortFilterList.InitializeSortFilterList(self, control)

    local sorterKeys =
    {
        ["queueIndex"] = { tiebreaker = "name" },
        ["name"] = {},
    }

    self.masterList = {}
    self.currentSortKey = "queueIndex"
    self.currentSortOrder = ZO_SORT_ORDER_UP
    ZO_ScrollList_AddDataType(self.list, 1, "LeoAltholicWritsListTemplate", 32, function(control, data) self:SetupEntry(control, data) end)

    self.sortFunction = function(listEntry1, listEntry2)
        return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, sorterKeys, self.currentSortOrder)
    end

    return self
end

function LeoAltholic.WritsList:SetupEntry(control, data)

    control.data = data

    control.name = GetControl(control, "Name")
    control.name:SetText(data.name)

    local child, texture
    for _, craft in pairs(LeoAltholic.allCrafts) do
        child = GetControl(control, "Craft"..craft.."Status")
        texture = GetControl(control, "Craft"..craft.."Icon")
        local icon = "esoui/art/tutorial/menubar_help_up.dds"
        local color = LeoAltholic.color.rgba.white
        local ago = ""
        local tooltip = ""
        for _, writ in pairs(data.writs) do
            if craft == writ.craft then
                local inProgress = true
                if writ.lastDone ~= nil and LeoAltholic.IsAfterReset(writ.lastDone) then
                    color = LeoAltholic.color.rgba.green
                    icon = "esoui/art/buttons/accept_up.dds"
                elseif writ.lastPreDeliver ~= nil and LeoAltholic.IsAfterReset(writ.lastPreDeliver) then
                    color = LeoAltholic.color.rgba.yellow
                    icon = "esoui/art/loot/loot_finesseItem.dds"
                elseif writ.lastUpdated ~= nil and LeoAltholic.IsAfterReset(writ.lastUpdated) then
                    color = LeoAltholic.color.rgba.orange
                    icon = "esoui/art/buttons/pointsplus_up.dds"
                elseif writ.lastStarted ~= nil and LeoAltholic.IsAfterReset(writ.lastStarted) then
                    color = LeoAltholic.color.rgba.white
                    icon = "esoui/art/buttons/pointsminus_up.dds"
                else
                    inProgress = false
                    color = LeoAltholic.color.rgba.red
                    icon = "esoui/art/buttons/decline_up.dds"
                end
                if writ.lastDone ~= nil then
                    local diff = GetTimeStamp() - writ.lastDone
                    if diff < 3600 then
                        ago = ZO_CachedStrFormat(GetString(SI_TIME_FORMAT_MINUTES), math.floor(diff / 60))
                    elseif diff < 86400 then
                        ago = ZO_CachedStrFormat(GetString(SI_TIME_FORMAT_HOURS), math.floor(diff / 3600))
                    else
                        ago = ZO_CachedStrFormat(GetString(SI_TIME_FORMAT_DAYS), math.floor(diff / 86400))
                    end
                    tooltip = ZO_CachedStrFormat(GetString(SI_TIME_DURATION_AGO), ago)
                else
                    ago = '?'
                    tooltip = ZO_CachedStrFormat(GetString(SI_STR_TIME_UNKNOWN))
                end
                tooltip = ZO_CachedStrFormat(GetString(SI_TRACKED_QUEST_STEP_DONE), tooltip)
                break
            end
        end

        texture:SetTexture(icon)
        texture:SetColor(unpack(color))

        child:SetText(ago)
        child:SetColor(unpack(color))
        if tooltip ~= "" then
            child:SetHandler("OnMouseEnter", function(control)
                InitializeTooltip(InformationTooltip, control, TOPLEFT, 50, 0, TOPLEFT)
                SetTooltipText(InformationTooltip, tooltip)
            end)
            child:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
            child:SetMouseEnabled(true)
        else
            child:SetMouseEnabled(true)
        end
    end

    ZO_SortFilterList.SetupRow(self, control, data)
end


function LeoAltholic.WritsList:ColorRow(control, data, mouseIsOver)

    local color = ZO_SECOND_CONTRAST_TEXT
    local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_QUALITY_MAGIC)

    local child = GetControl(control, "Name")
    if data.name == LeoAltholic.CharName then
        child:SetColor(r, g, b)
    else
        child:SetColor(color:UnpackRGBA())
    end
end

function LeoAltholic.WritsList:BuildMasterList()
    self.masterList = {}
    local list = LeoAltholic.ExportCharacters(true)
    for k, v in ipairs(list) do
        local data = {
            name = v.bio.name,
            writs = v.quests.writs or {}
        }
        data.queueIndex = k
        table.insert(self.masterList, data)
    end
end

function LeoAltholic.WritsList:SortScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    if self.currentSortKey == "queueIndex" then
        table.sort(scrollData, function(listEntry1, listEntry2)
            return (listEntry1.data.queueIndex or 999) < (listEntry2.data.queueIndex or 999)
        end)
    else
        table.sort(scrollData, self.sortFunction)
    end
end

function LeoAltholic.WritsList:FilterScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    ZO_ClearNumericallyIndexedTable(scrollData)
    for i = 1, #self.masterList do
        local data = self.masterList[i]
        table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, data))
    end
end
