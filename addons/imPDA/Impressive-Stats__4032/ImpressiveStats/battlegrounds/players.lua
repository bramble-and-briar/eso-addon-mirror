local MATCHES   = 1
local KILLS     = 2
local DEATHS    = 3
local ASSISTS   = 4
local DAMAGE    = 5
local HEALING   = 6

local function BuildCache(forceRebuild)
    local cache
    if forceRebuild then
        cache = {players={},lastCached=0}
    else
        cache = ImpressiveStatsPlayersCache or {players={},lastCached=0}
    end
    ImpressiveStatsPlayersCache = cache

    local cachedPlayers = cache.players

    local matches = IMP_STATS_MATCHES_MANAGER.matches

    for mi = cache.lastCached + 1, #matches do
        local rounds = matches[mi]['rounds']
        for r = 1, #rounds do
            local players = rounds[r]['players']
            for p = 2, #players do
                local player = players[p]
                local displayName = player['displayName']
                local playerCache = cachedPlayers[displayName] or {{},0,0,0,0,0}
                cachedPlayers[displayName] = playerCache

                local seenInMatches = playerCache[MATCHES]
                if seenInMatches[#seenInMatches] ~= mi then  -- to prevent duplicates from 2+ round matches
                    seenInMatches[#seenInMatches+1] = mi
                end
                playerCache[KILLS]      = playerCache[KILLS]    + player['kills']
                playerCache[DEATHS]     = playerCache[DEATHS]   + player['deaths']
                playerCache[ASSISTS]    = playerCache[ASSISTS]  + player['assists']
                playerCache[DAMAGE]     = playerCache[DAMAGE]   + player['damageDone']
                playerCache[HEALING]    = playerCache[HEALING]  + player['healingDone']
            end
        end
        cache.lastCached = mi
    end
end

-- ----------------------------------------------------------------------------

local addon = {
    control = IMP_STATS_PlayersSummary,
    listControl = IMP_STATS_PlayersSummaryBodyScrollableList,
    performanceMeter = IMP_STATS_PlayersSummaryPerformanceMeter,
    filters = {
        displayName = nil,  -- always keep in lower case!
    },
}

local function hex2rgb(hex)  -- TODO: define colors, make them not HEX
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)

    return r / 255, g / 255, b / 255
end

local function ShowRMBMenu(control, button)
    if button ~= MOUSE_BUTTON_INDEX_RIGHT then return end

    local data = control.dataEntry.data

    ClearMenu()

    local categories = ImpressiveStatsPlayersSV.categories
    local players = ImpressiveStatsPlayersSV.playerCategories

    for categoryIndex, categoryData in ipairs(categories) do
        local text = ('|c%s|t13:13:/art/fx/texture/whitesquare.dds:inheritcolor|t|r %s'):format(categoryData.color, categoryData.name)
        AddCustomMenuItem(text, function()
            local playerDisplayName = data[2]
            players[playerDisplayName] = categoryIndex

            addon.dirty = true  -- TODO: kinda don't like it
            addon:Update()
        end)
    end

    AddCustomMenuItem('Clear category', function()
        local playerDisplayName = data[2]
        players[playerDisplayName] = nil

        addon.dirty = true  -- TODO: kinda don't like it
        addon:Update()
    end)

    AddCustomMenuItem(GetString(SI_PLAYER_TO_PLAYER_WHISPER), function()
        local playerDisplayName = data[2]

        KEYBOARD_CHAT_SYSTEM:StartTextEntry(nil, CHAT_CHANNEL_WHISPER, playerDisplayName)
    end)

    ShowMenu()
end

function addon:IsHidden()
    return self.control:IsHidden()
end

function addon:Update()
    if self:IsHidden() then
        self.dirty = true
        return
    end

    if not self.dirty then
        return
    end

    local updateStart = GetGameTimeSeconds()

    BuildCache()  -- TODO

    local data = {}
    for displayName, stats in pairs(ImpressiveStatsPlayersCache.players) do
        if self:PassesFilter(displayName, stats) then
            local numMatches = #stats[MATCHES]  -- can it actually be 0?

            local avgKA = (stats[KILLS] + stats[ASSISTS]) / numMatches
            local avgDmg = stats[DAMAGE] / numMatches
            local avgHeal = stats[HEALING] / numMatches

            local category = ImpressiveStatsPlayersSV.playerCategories[displayName]

            data[#data+1] = {category, displayName, numMatches, avgKA, avgDmg, avgHeal,}
        end
    end

    self.table:Update(1, data)

    local updateDuration = GetGameTimeSeconds() - updateStart
    -- TODO: global performance metering
    -- self.performanceMeter:SetText(('Update ~%d ms'):format(updateDuration * 1000))
end

function addon:PassesFilter(playerDisplayName, playerStats)
    local displayName = self.filters.displayName
    if displayName then
        if not playerDisplayName:lower():find(displayName) then
            return
        end
    end

    return true
end

function addon:HookBattlegroundPlayerRow()
    ZO_PostHook(ZO_Battleground_Scoreboard_Player_Row_Object, 'SetupOnAcquire', function(obj, panel, poolKey, data)
        local control = obj.control
        local nameLabel = obj.nameLabel

        local mark = obj.control:GetNamedChild('Mark')
        if not mark then
            mark = CreateControl('$(parent)Mark', control, CT_TEXTURE)
            mark:SetDimensions(20, 20)
            mark:SetAnchor(RIGHT, nameLabel, LEFT, -4)
            mark:SetDrawLayer(DL_TEXT)
        end

        local playerDisplayName = data.displayName
        local categoryIndex = ImpressiveStatsPlayersSV.playerCategories[playerDisplayName]

        if categoryIndex then
            local categoryData = ImpressiveStatsPlayersSV.categories[categoryIndex]
            mark:SetHidden(false)
            mark:SetColor(hex2rgb(categoryData.color))
        else
            mark:SetHidden(true)
        end
    end)
end

function addon:HookBattlegroundPlayerRowMenu()
    ZO_PreHook(BATTLEGROUND_SCOREBOARD_FRAGMENT, 'ShowKeyboardPlayerMenu', function(obj, anchorToControl)
        ClearMenu()

        local data = obj.selectedPlayerData
        if not data then return end

        if IsChatSystemAvailableForCurrentPlatform() then
            AddMenuItem(GetString(SI_SOCIAL_LIST_SEND_MESSAGE), function() StartChatInput("", CHAT_CHANNEL_WHISPER, data.displayName) end)
        end

        if not data.isLocalPlayer then
            if not IsFriend(data.displayName) then
                AddMenuItem(GetString(SI_SOCIAL_MENU_ADD_FRIEND), function() ZO_Dialogs_ShowDialog("REQUEST_FRIEND", {name = data.displayName}) end)
            end

            local function SendMailCallback()
                if not IsUnitDead("player") then
                    MAIL_SEND:ComposeMailTo(data.displayName)
                else
                    ZO_AlertEvent(EVENT_UI_ERROR, SI_CANNOT_DO_THAT_WHILE_DEAD)
                end
            end
            AddMenuItem(GetString(SI_SOCIAL_MENU_SEND_MAIL), SendMailCallback)

            AddMenuItem(GetString(SI_FRIEND_MENU_IGNORE), function() AddIgnore(data.displayName) end)
        end

        local playerDisplayName = data.displayName

        local categories = ImpressiveStatsPlayersSV.categories
        local players = ImpressiveStatsPlayersSV.playerCategories

        for categoryIndex, categoryData in ipairs(categories) do
            local text = ('|c%s|t13:13:/art/fx/texture/whitesquare.dds:inheritcolor|t|r %s'):format(categoryData.color, categoryData.name)
            AddCustomMenuItem(text, function()
                players[playerDisplayName] = categoryIndex

                GetControl(anchorToControl, 'Mark'):SetHidden(false)
                GetControl(anchorToControl, 'Mark'):SetColor(hex2rgb(categoryData.color))

                self.dirty = true
                self:Update()
            end)
        end

        AddCustomMenuItem('Clear category', function()
            players[playerDisplayName] = nil

            GetControl(anchorToControl, 'Mark'):SetHidden(true)

            self.dirty = true
            self:Update()
        end)

        ShowMenu(anchorToControl)

        return true
    end)
end

function addon:AddSelfToBattlegroundMatchesScene()
    local sceneName = 'IMP_STATS_MENU' .. SI_IMP_PVP_METER_BATTLEGROUNS_TAB_TITLE .. 'Scene'
    local scene = SCENE_MANAGER.scenes[sceneName]

    -- if not scene then return end

    -- local fragment = ZO_SimpleSceneFragment:New(self.control)
    -- scene:AddFragment(fragment)

    -- -- self.fragment = fragment

    -- fragment:RegisterCallback('StateChange', function(oldState, newState)
    --     if newState == ZO_STATE.SHOWING then
    --         self:Update()
    --     end
    -- end)

    self.control:SetHandler('OnEffectivelyShown', function()
        self:Update()
    end)

    scene:RegisterCallback('StateChange', function(oldState, newState)
        if newState == ZO_STATE.HIDING then
            self.control:SetHidden(true)
        end
    end)
end

function addon:HookMatchesUpdate()
    -- TODO: implement event-callback system instead of this monstrosity?
    ZO_PostHook(IMP_STATS_MATCHES_UI, 'Update', function()
        zo_callLater(function()
            self.dirty = true  -- assume the have to update, but it is not true TODO: update on actual data change?
            self:Update()
        end,
        2000)
    end)
end

function addon:InitializeSearch()
    local function OnSearchTextChanged(editBox)
        local newText = string.lower(editBox:GetText())

        if newText == self.filters.displayName then return end

        self.filters.displayName = newText
        self.dirty = true
        self:Update()
    end

    local searchBox = GetControl(self.control, 'HeaderPlayerSearchBox')
    searchBox:SetDefaultText('Enter player display name')
    searchBox:SetHandler('OnTextChanged',  OnSearchTextChanged)
end

function addon:Initialize()
    ImpressiveStatsPlayersSV = ImpressiveStatsPlayersSV or {
        playerCategories = {},
        categories = {
            {color='FF3333', name='Category 1'},
            {color='FF6633', name='Category 2'},
            {color='FFCC33', name='Category 3'},
            {color='CCFF33', name='Category 4'},
            {color='33FF66', name='Category 5'},
            {color='33CC33', name='Category 6'},
        }
    }

    local body = self.control:GetNamedChild('Body')
    self.body = body

    self:InitializeSearch()

    self:_initTable()

    SLASH_COMMANDS['/impstatsrebuildcache'] = function()
        BuildCache(true)
    end

    self:AddSelfToBattlegroundMatchesScene()

    self:HookBattlegroundPlayerRow()
    self:HookBattlegroundPlayerRowMenu()

    self:HookMatchesUpdate()

    if PP then
        self.control:ClearAnchors()

        self.control:SetAnchor(TOPRIGHT, IMP_STATS_MATCHES, TOPLEFT, -32, 0)
        self.control:SetAnchor(BOTTOMRIGHT, IMP_STATS_MATCHES, BOTTOMLEFT, -32, 0)

        self.control:GetNamedChild('BG'):SetHidden(true)
        PP:CreateBackground(self.control, --[[#1]] nil, nil, nil, -10, -10, --[[#2]] nil, nil, nil, 10, 10)
    end

    return self
end

function addon:_initTable()
    local categories = ImpressiveStatsPlayersSV.categories

	local Texture = LibScrollList.Texture
	local Column = LibScrollList.Column
	local Table = LibScrollList.Table

    local function ShowCategoryName(iconCtrl)
        local rowCtrl = iconCtrl:GetParent():GetParent()
        ZO_Tooltips_ShowTextTooltip(iconCtrl, LEFT, categories[rowCtrl.dataEntry.data[1]].name)
    end

	local function setCategoryIcon(ctrl, category)
        if not category then
            ctrl:SetColor(0.25, 0.25, 0.25)
            ctrl:SetHandler('OnMouseEnter', nil)
            ctrl:SetHandler('OnMouseExit', nil)
        else
            ctrl:SetColor(hex2rgb(categories[category].color))
            ctrl:SetHandler('OnMouseEnter', ShowCategoryName)
            ctrl:SetHandler('OnMouseExit', ZO_Tooltips_HideTextTooltip)
        end
	end

	local iconStyle = {
        SetTexture = {'/esoui/art/dye/gamepad/dye_circle.dds'},
		SetDimensions = {20, 20},
		SetDrawLayer = {DL_CONTROLS},
		SetDrawTier = {DT_MEDIUM},
        SetMouseEnabled = {true},
	}

    local CategoryIcon = Texture(iconStyle, setCategoryIcon)

    local TC = IMP_STATS_TABLESTYLES.Text.Cell
    local THU = IMP_STATS_TABLESTYLES.Text.HeaderUpper
    local FC = IMP_STATS_TABLESTYLES.Formatted.Cell
	local RC = IMP_STATS_TABLESTYLES.Rounded1F.Cell

	local SORTABLE = true
	local columns = {
		Column('Group', 	   28,  0, CategoryIcon, '!', THU.Center, SORTABLE),
		Column('DisplayName', 180,  8, TC.Left,   'Name', THU.Left,   SORTABLE),
		Column('NumMatches',   32, 16, TC.Center,    '#', THU.Center, SORTABLE),
		Column('KA',           60,  0, RC.Center,  'K+A', THU.Center, SORTABLE),
		Column('DamageDone',   60,  0, FC.Center,  'Dmg', THU.Center, SORTABLE),
		Column('HealingDone',  60,  0, FC.Center, 'Heal', THU.Center, SORTABLE),
    }

	local WITH_HEADERS = true
    local myTable = Table(WITH_HEADERS)

	local postCreateCallback = function(rowControl)
        rowControl:SetHandler('OnMouseDown', function(control, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then
                --  ZO_ScrollList_MouseClick(scrollList, rowControl)
            else
                ShowRMBMenu(control, button)
            end
        end)
		-- local background = CreateControlFromVirtual('$(parent)Background', rowControl, 'IMP_TallListSelectedHighlight')
	end

	local postSetupCallback = function(rowControl, dataEntryData, scrollList)
        if dataEntryData[DAMAGE] > 500000 then
            GetControl(rowControl, 'DamageDone'):SetColor(0.86, 0.3, 0)
        else
            GetControl(rowControl, 'DamageDone'):SetColor(1, 1, 1)
        end

        if dataEntryData[HEALING] > 500000 then
            GetControl(rowControl, 'HealingDone'):SetColor(0, 0.7, 0)
        else
            GetControl(rowControl, 'HealingDone'):SetColor(1, 1, 1)
        end
	end

    myTable:AddDataType(1, columns, 32, postCreateCallback, postSetupCallback)

    myTable:SetMulticolumnSortingEnabled(true)
	myTable:SetDefaultSortingCriteria(
		1, ZO_SORT_ORDER_DOWN,
		2, ZO_SORT_ORDER_UP
    )

	local REPLACE = true
    local scrollControl = myTable:Create('Table', self.body, REPLACE)
    scrollControl:SetDimensions(460, 650)

	self.table = myTable
end

-- TODO: SV handling, unify RMB, unify setting player category

-- TODO: remake XML with simple controls in headers and labels inside so 
-- sortind direction icon can be anchored to the cneter of label independently
-- from column actual width

-- ----------------------------------------------------------------------------

function IMP_STATS_InitializePlayersStats()
    addon:Initialize()
end
