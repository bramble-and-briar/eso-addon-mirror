local IMP_STATS_SHARED = IMP_STATS_SHARED

local Log = IMP_STATS_Logger('IMP_STATS_TRIBUTE_LEADERBOARD')

local addon = {}

local EVENT_NAMESPACE = 'IMP_TributeLeaderboard_EventNamespace'

function addon:CreateScrollListDataType()
    local function LayoutRow(rowControl, data, scrollList)
        GetControl(rowControl, 'Index'):SetText(data.index)
        GetControl(rowControl, 'Name'):SetText(data.name)
        GetControl(rowControl, 'MMR'):SetText(data.mmr)

        local games, winrate, FPWinrate, SPWinrate = IMP_STATS_TRIBUTE_STATS_MANAGER:GetStatsVS(data.name)
        if games then
            GetControl(rowControl, 'Stats'):SetText(('%.1f %%'):format(IMP_STATS_SHARED.PossibleNan(winrate) * 100))
        else
            GetControl(rowControl, 'Stats'):SetText('-')
        end

        -- GetControl(rowControl, 'Highlight'):SetHidden(data.name ~= '@Valoria_Winterdream')

        local note = IMP_STATS_NOTES_MANAGER:GetNote(data.name)
        GetControl(rowControl, 'NoteIcon'):SetHidden(note == nil)

        local tooltip = ''

        if games then
            tooltip = tooltip .. (' %d (%.1f - %.1f / %.1f)'):format(
                games,
                IMP_STATS_SHARED.PossibleNan(winrate) * 100,
                IMP_STATS_SHARED.PossibleNan(FPWinrate) * 100,
                IMP_STATS_SHARED.PossibleNan(SPWinrate) * 100
            )
        else
            tooltip = 'No games on record'
        end

        if note then
            tooltip = tooltip .. '\n\nNote:\n'
            tooltip = tooltip .. note
        end

        -- TODO IMPORTANT: I dont like idea to add custom hadler to every row
        -- it would be better to make some unified callback ?possible
        rowControl:SetHandler('OnMouseDown', function(control, button)
            if button == MOUSE_BUTTON_INDEX_RIGHT then
                ClearMenu()

                AddCustomMenuItem('Edit note', function()
                    IMP_STATS_NOTES_MANAGER:ShowEditNoteDialog(control.dataEntry.data.name)
                end)

                ShowMenu()
            end
        end)

        rowControl:SetHandler('OnMouseEnter', function() ZO_Tooltips_ShowTextTooltip(rowControl, RIGHT, tooltip) end)
        rowControl:SetHandler('OnMouseExit', function() ZO_Tooltips_HideTextTooltip() end)
    end

	local control = self.listControl
	local typeId = 1
	local templateName = 'IMP_STATS_Tribute_Leaderboard_Row'
	local height = 32
	local setupFunction = LayoutRow
	local hideCallback = nil
	local dataTypeSelectSound = nil
	local resetControlCallback = nil

	ZO_ScrollList_AddDataType(control, typeId, templateName, height, setupFunction, hideCallback, dataTypeSelectSound, resetControlCallback)

    -- local selectTemplate = 'ZO_ThinListHighlight'
	-- local selectCallback = nil
	-- ZO_ScrollList_EnableSelection(control, selectTemplate, selectCallback)
end

function addon:UpdateScrollListControl(force)
    if QueryTributeLeaderboardData(TRIBUTE_LEADERBOARD_TYPE_RANKED) ~= LEADERBOARD_DATA_READY then return end
    if not self.dirty and not force then return end

    Log('Updating leaderboard list...')

    local attentionIndex = 0

    local scrollList = self.listControl
	local dataList = ZO_ScrollList_GetDataList(scrollList)

    local function CreateAndAddDataEntry(index)
        local rank, displayName, characterName, score = GetTributeLeaderboardEntryInfo(TRIBUTE_LEADERBOARD_TYPE_RANKED, index)

        -- Log('Adding %s %d', displayName, score)
        -- if displayName == '@Valoria_Winterdream' then
        --     attentionIndex = rank
        -- end

        local value = {index = rank, name = displayName, mmr = score}
        local entry = ZO_ScrollList_CreateDataEntry(1, value)

		table.insert(dataList, entry)
    end

    ZO_ScrollList_Clear(scrollList)

    for i = 1, GetNumTributeLeaderboardEntries(TRIBUTE_LEADERBOARD_TYPE_RANKED) do
        CreateAndAddDataEntry(i)
    end

    table.sort(dataList, function(a,b) return a.data.index < b.data.index end)

    ZO_ScrollList_Commit(scrollList)
    self.dirty = false

    local rank, _ = GetTributeLeaderboardLocalPlayerInfo(TRIBUTE_LEADERBOARD_TYPE_RANKED)
    -- rank = attentionIndex
    if rank and rank > 0 then
        -- ZO_ScrollList_ScrollDataToCenter
        ZO_ScrollList_ScrollDataToCenter(scrollList, rank, nil, false)
    end
end

function addon:Initialize(rootControl)
    self.listControl = rootControl:GetNamedChild('Listing'):GetNamedChild('ScrollableList')
    self:CreateScrollListDataType()

    self.dirty = true

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_TRIBUTE_LEADERBOARD_DATA_RECEIVED, function()
        Log('Leaderboard data received')
        self.dirty = true
        self:UpdateScrollListControl()
    end)

    Log('Initialized')
end

-- function IMP_STATS_TributeLeaderboard_OnInitialize(control)
--     addon:Initialize(control)
-- end

function IMP_STATS_TributeLeaderboard_OnShow(control)
    addon:UpdateScrollListControl()
end

function IMP_STATS_TributeLeaderboard_Initialize(initialize)
    addon:Initialize(IMP_STATS_TRIBUTE_LEADERBOARD)

    local fragment = ZO_SimpleSceneFragment:New(IMP_STATS_TRIBUTE_LEADERBOARD)
    IMP_STATS_LEFT_PANEL_BACKGROUND = ZO_SimpleSceneFragment:New(IMP_STATS_LeftPanelBackground)

    local sceneName = 'IMP_STATS_MENU' .. SI_IMP_PVP_METER_TOT_TAB_TITLE .. 'Scene'
    local scene = SCENE_MANAGER:GetScene(sceneName)

    scene:AddFragment(fragment)
    scene:AddFragment(IMP_STATS_LEFT_PANEL_BACKGROUND)

    IMP_STATS_NOTES_MANAGER:RegisterCallback(EVENT_NAMESPACE, IMP_STATS_NOTES_MANAGER.events.EVENT_NOTE_EDITED, function()
        addon:UpdateScrollListControl(true)
    end)

    ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback('OnActivityFinderStatusUpdate', function(status)
        local queued = status == ACTIVITY_FINDER_STATUS_QUEUED
        GetControl(IMP_STATS_TRIBUTE_LEADERBOARD, 'Queue'):SetEnabled(not queued)
        GetControl(IMP_STATS_TRIBUTE_LEADERBOARD, 'LeaveQueue'):SetEnabled(queued)
    end)
end

function IMP_STATS_QueueTributeRanked()
    if IsCurrentlySearchingForGroup() then
        return
    end

    ClearActivityFinderSearch()

    ZO_ACTIVITY_FINDER_ROOT_MANAGER.locationSetsLookupData[9][80]:AddActivitySearchEntry()

    local result = StartActivityFinderSearch()
    if result ~= ACTIVITY_QUEUE_RESULT_SUCCESS then
        ZO_AlertEvent(EVENT_ACTIVITY_QUEUE_RESULT, result)
    end
end