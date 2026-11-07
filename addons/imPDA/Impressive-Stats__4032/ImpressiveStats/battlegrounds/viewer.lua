local TLC = IMP_STATS_VIEWER_TLC
local ImperessiveStatsViewer = {}

function ImperessiveStatsViewer:Init()
	local body = TLC:GetNamedChild('Body')
	self.body = body

	self.scores = body:GetNamedChild('Scores')

	self:_initRounds()

	self:_initTable()

	IMP_STATS_MATCHES:SetHandler('OnEffectivelyShown', function()
		if self.match then
			TLC:SetHidden(false)
		end
	end)

	IMP_STATS_MATCHES:SetHandler('OnEffectivelyHidden', function()
		TLC:SetHidden(true)
	end)

	return self
end

function ImperessiveStatsViewer:_initRounds()
	local function SwitchRound(roundControl, button)
		if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
		self:LayoutRound(roundControl.number)
	end

	local rounds = self.body:GetNamedChild('Rounds')
	local previous = rounds:GetNamedChild('Label')
	for r = 1, 3 do
		local roundControl = CreateControlFromVirtual('$(parent)Round', rounds, 'IMP_STATS_VIEWER_RoundNumberTemplate', r)
		roundControl:SetAnchor(LEFT, previous, RIGHT)
		previous = roundControl

		roundControl:SetText(r)
		roundControl:SetHandler('OnMouseDown', SwitchRound)

		roundControl.selected = false
		roundControl.number = r
	end

	self.rounds = rounds
end

function ImperessiveStatsViewer:_initTable()
	local Texture = LibScrollList.Texture
	local Column = LibScrollList.Column
	local Table = LibScrollList.Table

	local function setTeamIcon(ctrl, teamId)
		ctrl:SetTexture(ZO_GetBattlegroundTeamIcon(teamId))
	end

	local iconStyle = {
		SetDimensions = {28, 28},
		SetDrawLayer = {DL_CONTROLS},
	}

	local TeamIcon = Texture(iconStyle, setTeamIcon)

	local TC = IMP_STATS_TABLESTYLES.Text.Cell
	local FC = IMP_STATS_TABLESTYLES.Formatted.Cell

	local ClassIcon = IMP_STATS_TABLESTYLES.ClassIcon
	local THU = IMP_STATS_TABLESTYLES.Text.HeaderUpper

	local TS = IMP_STATS_TABLESTYLES

	local SORTABLE = true
	local columns = {
		Column('Index', 	   20,  0, TC.Right,       '##', THU.Right,  SORTABLE),
		Column('Team',  	   50, 16, TeamIcon,	 'Team', THU.Center, SORTABLE),
		Column('Class', 	   28, 22, ClassIcon,		nil, THU.Center, SORTABLE),
		Column('DisplayName', 400,  8, TS.Names, 	 'Name', THU.Left,   SORTABLE),
		Column('MedalScore',   80,  0, TC.Center,	'Score', THU.Center, SORTABLE),
		Column('Kills',        50, 15, TC.Center,	    'K', THU.Center, SORTABLE),
		Column('Deaths',       50,  0, TC.Center,	    'D', THU.Center, SORTABLE),
		Column('Assists',      50,  0, TC.Center,	    'A', THU.Center, SORTABLE),
		Column('DamageDone',  100,  0, FC.Center,  'Damage', THU.Center, SORTABLE),
		Column('HealingDone', 100,  0, FC.Center, 'Healing', THU.Center, SORTABLE),
    }

	local WITH_HEADERS = true
    local myTable = Table(WITH_HEADERS)

	local function _showRMBMenu(rowCtrl, button)
		if button ~= MOUSE_BUTTON_INDEX_RIGHT then return end

		local data = rowCtrl.dataEntry.data

		ClearMenu()

		AddCustomMenuItem(GetString(SI_PLAYER_TO_PLAYER_WHISPER), function()
			local playerNames = data[4]
			KEYBOARD_CHAT_SYSTEM:StartTextEntry(nil, CHAT_CHANNEL_WHISPER, playerNames[1])
		end)

		ShowMenu()
	end

	local postCreateCallback = function(rowControl)
		local background = CreateControlFromVirtual('$(parent)Background', rowControl, 'IMP_TallListSelectedHighlight')

		rowControl:SetHandler('OnMouseDown', function(control, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then
                --  ZO_ScrollList_MouseClick(scrollList, rowControl)
            else
                _showRMBMenu(control, button)
            end
        end)
	end
	local postSetupCallback = function(rowControl, dataEntryData, scrollList)
		local team = dataEntryData[2]
		local color = GetBattlegroundTeamColor(team)
		rowControl:GetNamedChild('Background'):SetColor(color:UnpackRGBA())
		rowControl:GetNamedChild('Background'):SetHidden(false)

		-- TODO: find a way to insert new columns without changing indices in other different places
		local isLocal = dataEntryData[11]
		if isLocal then
			rowControl:GetNamedChild('DisplayName'):SetColor(239 / 255, 191 / 255, 4 / 255)  -- #EFBF04 Gold
		else
			rowControl:GetNamedChild('DisplayName'):SetColor(1, 1, 1)  -- #EFBF04 Gold
		end

		rowControl:GetNamedChild('Index'):SetText(rowControl.index)
	end
    myTable:AddDataType(1, columns, 32, postCreateCallback, postSetupCallback)

	myTable:SetMulticolumnSortingEnabled(true)
	myTable:SetDefaultSortingCriteria(
		2, ZO_SORT_ORDER_UP,
		5, ZO_SORT_ORDER_DOWN
	)

	local REPLACE = true
    local scrollControl = myTable:Create('Table', self.body, REPLACE)
    scrollControl:SetDimensions(1048+36-75-8, 0)

	self.table = myTable
end

function ImperessiveStatsViewer:Clear()
	self.match = nil
	self.roundNumber = nil
end

IMP_STATS_VIEWER = ImperessiveStatsViewer:Init()

function ImperessiveStatsViewer:LayoutRound(roundNumber)
	local match = self.match

	if not (match and match.rounds and match.rounds[roundNumber] and match.rounds[roundNumber].result ~= BATTLEGROUND_ROUND_RESULT_INVALID) then return end
	if roundNumber == self.roundNumber then return end
	self.roundNumber = roundNumber

	local round = match.rounds[roundNumber]

	local maxTeamId = 2  -- TODO: find better way to distinct 2-team and 3-team, e.x. with team type

	local data = {}
	for p, player in ipairs(round.players) do
		table.insert(data, {
			0,  -- can't put nil because it will try to sort by 1 column by default and fail
			player.battlegroundTeam,
			player.classId,
			{player.displayName, player.characterName},  -- zo_strformat('<<1>> (<<2>>)', player.displayName, player.characterName),
			player.medalScore,
			player.kills,
			player.deaths,
			player.assists,
			player.damageDone,
			player.healingDone,
			p == 1,
		})

		if player.battlegroundTeam > maxTeamId then
			maxTeamId = player.battlegroundTeam
		end
	end

	local scores = round.scores
	local winner = 0
	local maxScore = 0
	for s = 1, #scores do
		if scores[s] > maxScore then
			winner = s
			maxScore = scores[s]
		end
	end

	-- local localPlayerTeam = round.players[1].battlegroundTeam
	-- TODO: label WIN if winner == localPlayerTeam
	for t = 1, 3 do
		local team = self.scores:GetNamedChild('Team'..t)
		if t <= maxTeamId then
			local score = team:GetNamedChild('Score')
			score:SetText(scores[t])
			if t == winner then
				score:SetColor(239 / 255, 191 / 255, 4 / 255)  -- #EFBF04 Gold
			else
				score:SetColor(0.7, 0.7, 0.7)
			end

			team:SetHidden(false)
		else
			team:SetHidden(true)
		end
	end

	self.table:ResizeToFitNRows(1, #data)
	self.table:Update(1, data)

	self:_updateRoundsSelector()
end

function ImperessiveStatsViewer:_updateRoundsSelector()
	local match = self.match
	local rounds = self.rounds

	if #match.rounds > 1 then
		for r = 1, 3 do
			local roundData = match.rounds[r]
			local roundControl = rounds:GetNamedChild('Round' .. r)
			if roundData and roundData.result ~= BATTLEGROUND_ROUND_RESULT_INVALID then
				roundControl:SetHidden(false)
				if r == IMP_STATS_VIEWER.roundNumber then
					roundControl.selected = true
					roundControl:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED))
				else
					roundControl.selected = false
					roundControl:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
				end
			else
				roundControl:SetHidden(true)
			end
		end
		rounds:SetHidden(false)
	else
		rounds:SetHidden(true)
	end
end

function ImperessiveStatsViewer:LayoutMatch(match)
	self:Clear()
	self.match = match

	if match.entryTimestamp then
		local formattedTime = os.date('%d.%m.%Y %H:%M', match.entryTimestamp)
		local localPlayer = match.rounds[1].players[1]
		local formattedPlayer = zo_strformat('<<1>> (<<2>>)', localPlayer.displayName, localPlayer.characterName)
		TLC:GetNamedChild('HeaderLabel'):SetText(
			('%s, %s, %s'):format(formattedTime, GetZoneNameById(match.zoneId), formattedPlayer)
		)
	end

	self:LayoutRound(1)

	TLC:SetHidden(false)
end

function ImperessiveStatsViewer:OnDeselect()
	TLC:SetHidden(true)
	self:Clear()
end

-- TODO: add category for players stats with RMB