--- @class Srendarr
local Srendarr = _G['Srendarr'] -- grab addon table from global
local L = Srendarr:GetLocale()
local LAM = LibAddonMenu2
local LMP = LibMediaProvider

-- CONSTS --
local NUM_DISPLAY_FRAMES = Srendarr.NUM_DISPLAY_FRAMES
local GROUP_START_FRAME = Srendarr.GROUP_START_FRAME
local GROUP_DSTART_FRAME = Srendarr.GROUP_DSTART_FRAME
local GROUP_DEND_FRAME = Srendarr.GROUP_DEND_FRAME

local AURA_STYLE_FULL = Srendarr.AURA_STYLE_FULL
local AURA_STYLE_ICON = Srendarr.AURA_STYLE_ICON
local AURA_STYLE_MINI = Srendarr.AURA_STYLE_MINI
local AURA_STYLE_GROUPB = Srendarr.AURA_STYLE_GROUPB
local AURA_STYLE_GROUPD = Srendarr.AURA_STYLE_GROUPD
local AURA_GROW_UP = Srendarr.AURA_GROW_UP
local AURA_GROW_DOWN = Srendarr.AURA_GROW_DOWN
local AURA_GROW_LEFT = Srendarr.AURA_GROW_LEFT
local AURA_GROW_RIGHT = Srendarr.AURA_GROW_RIGHT
local AURA_GROW_CENTERLEFT = Srendarr.AURA_GROW_CENTERLEFT
local AURA_GROW_CENTERRIGHT = Srendarr.AURA_GROW_CENTERRIGHT
local AURA_GROW_CENTERUP = Srendarr.AURA_GROW_CENTERUP
local AURA_GROW_CENTERDOWN = Srendarr.AURA_GROW_CENTERDOWN

local AURA_TYPE_TIMED = Srendarr.AURA_TYPE_TIMED
local AURA_TYPE_TOGGLED = Srendarr.AURA_TYPE_TOGGLED
local AURA_TYPE_PASSIVE = Srendarr.AURA_TYPE_PASSIVE
local DEBUFF_TYPE_PASSIVE = Srendarr.DEBUFF_TYPE_PASSIVE
local DEBUFF_TYPE_TIMED = Srendarr.DEBUFF_TYPE_TIMED

local AURA_SORT_NAMEASC = Srendarr.AURA_SORT_NAMEASC
local AURA_SORT_TIMEASC = Srendarr.AURA_SORT_TIMEASC
local AURA_SORT_CASTASC = Srendarr.AURA_SORT_CASTASC
local AURA_SORT_NAMEDESC = Srendarr.AURA_SORT_NAMEDESC
local AURA_SORT_TIMEDESC = Srendarr.AURA_SORT_TIMEDESC
local AURA_SORT_CASTDESC = Srendarr.AURA_SORT_CASTDESC

local AURA_TIMERLOC_HIDDEN = Srendarr.AURA_TIMERLOC_HIDDEN
local AURA_TIMERLOC_OVER = Srendarr.AURA_TIMERLOC_OVER
local AURA_TIMERLOC_ABOVE = Srendarr.AURA_TIMERLOC_ABOVE
local AURA_TIMERLOC_BELOW = Srendarr.AURA_TIMERLOC_BELOW

local GROUP_PLAYER_SHORT = Srendarr.GROUP_PLAYER_SHORT
local GROUP_PLAYER_LONG = Srendarr.GROUP_PLAYER_LONG
local GROUP_PLAYER_TOGGLED = Srendarr.GROUP_PLAYER_TOGGLED
local GROUP_PLAYER_PASSIVE = Srendarr.GROUP_PLAYER_PASSIVE
local GROUP_PLAYER_DEBUFF = Srendarr.GROUP_PLAYER_DEBUFF
local GROUP_PLAYER_GROUND = Srendarr.GROUP_PLAYER_GROUND
local GROUP_PLAYER_MAJOR = Srendarr.GROUP_PLAYER_MAJOR
local GROUP_PLAYER_MINOR = Srendarr.GROUP_PLAYER_MINOR
local GROUP_PLAYER_ENCHANT = Srendarr.GROUP_PLAYER_ENCHANT
local GROUP_TARGET_BUFF = Srendarr.GROUP_TARGET_BUFF
local GROUP_TARGET_DEBUFF = Srendarr.GROUP_TARGET_DEBUFF
local GROUP_CDTRACKER = Srendarr.GROUP_CDTRACKER
local GROUP_CDBAR = Srendarr.GROUP_CDBAR

local STR_PROMBYID = Srendarr.STR_PROMBYID
local STR_GROUPBUFFBYID = Srendarr.STR_GROUPBUFFBYID
local STR_GROUPDEBUFFBYID = Srendarr.STR_GROUPDEBUFFBYID
local STR_BLOCKBYID = Srendarr.STR_BLOCKBYID
local sampleAuraData = Srendarr.sampleAuraData
local maxAbilityID = Srendarr.maxAbilityID
local bData = Srendarr.BahseiData
local pData = Srendarr.POrderData

local specialNames = Srendarr.specialNames
local ZOSName = function (abilityID) return zo_strformat('<<t:1>>', GetAbilityName(abilityID)) end

-- UPVALUES --
local WM = GetWindowManager()
local CM = CALLBACK_MANAGER
local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort
local strformat = string.format

-- DROPDOWN CHOICES --
local dropProminentDB = {}
local dropGroupBuffs = {}
local dropGroupDebuffs = {}
local dropBlacklistAuras = {}

-- RECENT AURA SCROLL LIST --
local scrollTable = {}
local listMode = 0

-- Setting string support for different group and raid frames (Phinix)
local groupFrameConfig =
{
    [1] = { gbTL = Srendarr.AURA_TIMERLOC_HIDDEN, rbTL = Srendarr.AURA_TIMERLOC_HIDDEN, gdTL = Srendarr.AURA_TIMERLOC_HIDDEN, rdTL = Srendarr.AURA_TIMERLOC_HIDDEN },
    [2] = { gbTL = Srendarr.AURA_TIMERLOC_BELOW, rbTL = Srendarr.AURA_TIMERLOC_HIDDEN, gdTL = Srendarr.AURA_TIMERLOC_BELOW, rdTL = Srendarr.AURA_TIMERLOC_HIDDEN },
    [3] = { gbTL = Srendarr.AURA_TIMERLOC_BELOW, rbTL = Srendarr.AURA_TIMERLOC_HIDDEN, gdTL = Srendarr.AURA_TIMERLOC_BELOW, rdTL = Srendarr.AURA_TIMERLOC_HIDDEN },
    [4] = { gbTL = Srendarr.AURA_TIMERLOC_HIDDEN, rbTL = Srendarr.AURA_TIMERLOC_HIDDEN, gdTL = Srendarr.AURA_TIMERLOC_HIDDEN, rdTL = Srendarr.AURA_TIMERLOC_HIDDEN },
    [5] = { gbTL = Srendarr.AURA_TIMERLOC_OVER, rbTL = Srendarr.AURA_TIMERLOC_HIDDEN, gdTL = Srendarr.AURA_TIMERLOC_BELOW, rdTL = Srendarr.AURA_TIMERLOC_HIDDEN },
    [6] = { gbTL = Srendarr.AURA_TIMERLOC_OVER, rbTL = Srendarr.AURA_TIMERLOC_HIDDEN, gdTL = Srendarr.AURA_TIMERLOC_OVER, rdTL = Srendarr.AURA_TIMERLOC_HIDDEN },
}
local dropGroupMode = { L.DropGroupMode1, L.DropGroupMode2, L.DropGroupMode3, L.DropGroupMode4, L.DropGroupMode5, L.DropGroupMode6 }
local dropGroupModeValues = { [L.DropGroupMode1] = 1, [L.DropGroupMode2] = 2, [L.DropGroupMode3] = 3, [L.DropGroupMode4] = 4, [L.DropGroupMode5] = 5, [L.DropGroupMode6] = 6 }

local dropGroup = { L.DropGroup_1, L.DropGroup_2, L.DropGroup_3, L.DropGroup_4, L.DropGroup_5, L.DropGroup_6, L.DropGroup_7, L.DropGroup_8, L.DropGroup_9, L.DropGroup_10, L.DropGroup_11, L.DropGroup_12, L.DropGroup_13, L.DropGroup_14, L.DropGroup_None }
local dropGroupRef = { [L.DropGroup_1] = 1, [L.DropGroup_2] = 2, [L.DropGroup_3] = 3, [L.DropGroup_4] = 4, [L.DropGroup_5] = 5, [L.DropGroup_6] = 6, [L.DropGroup_7] = 7, [L.DropGroup_8] = 8, [L.DropGroup_9] = 9, [L.DropGroup_10] = 10, [L.DropGroup_11] = 11, [L.DropGroup_12] = 12, [L.DropGroup_13] = 13, [L.DropGroup_14] = 14, [L.DropGroup_None] = 0 }
local dropGroupRev = { [1] = L.DropGroup_1, [2] = L.DropGroup_2, [3] = L.DropGroup_3, [4] = L.DropGroup_4, [5] = L.DropGroup_5, [6] = L.DropGroup_6, [7] = L.DropGroup_7, [8] = L.DropGroup_8, [9] = L.DropGroup_9, [10] = L.DropGroup_10, [11] = L.DropGroup_11, [12] = L.DropGroup_12, [13] = L.DropGroup_13, [14] = L.DropGroup_14 }
local dropType = { L.DropAuraClassBuff, L.DropAuraClassDebuff }
local dropTypeRef = { [L.DropAuraClassBuff] = BUFF_EFFECT_TYPE_BUFF, [L.DropAuraClassDebuff] = BUFF_EFFECT_TYPE_DEBUFF }
local dropTypeRev = { [BUFF_EFFECT_TYPE_BUFF] = L.DropAuraClassBuff, [BUFF_EFFECT_TYPE_DEBUFF] = L.DropAuraClassDebuff }
local dropTarget = { L.DropAuraTargetPlayer, L.DropAuraTargetTarget, L.DropAuraTargetAOE }
local dropTargetRef = { [L.DropAuraTargetPlayer] = 'player', [L.DropAuraTargetTarget] = 'reticleover', [L.DropAuraTargetAOE] = 'groundaoe' }

local dropStyle = { L.DropStyle_Full, L.DropStyle_Icon, L.DropStyle_Mini }
local dropStyleRef = { [L.DropStyle_Full] = AURA_STYLE_FULL, [L.DropStyle_Icon] = AURA_STYLE_ICON, [L.DropStyle_Mini] = AURA_STYLE_MINI }

local dropGrowthFullMini = { L.DropGrowth_Up, L.DropGrowth_Down, L.DropGrowth_CenterUp, L.DropGrowth_CenterDown }
local dropGrowthIcon = { L.DropGrowth_Up, L.DropGrowth_Down, L.DropGrowth_Left, L.DropGrowth_Right, L.DropGrowth_CenterUp, L.DropGrowth_CenterDown, L.DropGrowth_CenterLeft, L.DropGrowth_CenterRight }
local dropGrowthRef = { [L.DropGrowth_Up] = AURA_GROW_UP, [L.DropGrowth_Down] = AURA_GROW_DOWN, [L.DropGrowth_Left] = AURA_GROW_LEFT, [L.DropGrowth_Right] = AURA_GROW_RIGHT, [L.DropGrowth_CenterUp] = AURA_GROW_CENTERUP, [L.DropGrowth_CenterDown] = AURA_GROW_CENTERDOWN, [L.DropGrowth_CenterLeft] = AURA_GROW_CENTERLEFT, [L.DropGrowth_CenterRight] = AURA_GROW_CENTERRIGHT }

local dropSort = { L.DropSort_NameAsc, L.DropSort_TimeAsc, L.DropSort_CastAsc, L.DropSort_NameDesc, L.DropSort_TimeDesc, L.DropSort_CastDesc }
local dropSortRef = { [L.DropSort_NameAsc] = AURA_SORT_NAMEASC, [L.DropSort_TimeAsc] = AURA_SORT_TIMEASC, [L.DropSort_CastAsc] = AURA_SORT_CASTASC, [L.DropSort_NameDesc] = AURA_SORT_NAMEDESC, [L.DropSort_TimeDesc] = AURA_SORT_TIMEDESC, [L.DropSort_CastDesc] = AURA_SORT_CASTDESC }

local dropTimerFull = { L.DropTimer_Hidden, L.DropTimer_Over }
local dropTimerIcon = { L.DropTimer_Hidden, L.DropTimer_Over, L.DropTimer_Above, L.DropTimer_Below }
local dropTimerRef = { [L.DropTimer_Hidden] = AURA_TIMERLOC_HIDDEN, [L.DropTimer_Over] = AURA_TIMERLOC_OVER, [L.DropTimer_Above] = AURA_TIMERLOC_ABOVE, [L.DropTimer_Below] = AURA_TIMERLOC_BELOW }

local dropAuraClass = { L.DropAuraClassBuff, L.DropAuraClassDebuff, L.DropAuraClassDefault }
local dropAuraClassRef = { [L.DropAuraClassBuff] = AURA_TYPE_TIMED, [L.DropAuraClassDebuff] = DEBUFF_TYPE_TIMED, [L.DropAuraClassDefault] = 3 }

local dropFontStyle = { 'none', 'outline', 'thin-outline', 'thick-outline', 'shadow', 'soft-shadow-thin', 'soft-shadow-thick' }

local subWidgets =
{ -- custom panel submenu data (Phinix)
    -- Add 40 to height for each single-line option added to section.
    ['SrendarrBlacklistSubmenu']     = { height = 162, widgets = {} },
    ['SrendarrAuraWhitelistSubmenu'] = { height = 476, widgets = {} },
    ['SrendarrGroupBuffSubmenu']     = { height = 358, widgets = {} },
    ['SrendarrGroupDebuffSubmenu']   = { height = 318, widgets = {} },
    ['SrendarrPlayerFilterSubmenu']  = { height = 318, widgets = {} },
    ['SrendarrTargetFilterSubmenu']  = { height = 481, widgets = {} },
    ['SrendarrDisplayGroupSubmenu']  = { height = 572, widgets = {} },
    ['SrendarrGeneralSubmenu']       = { height = 784, widgets = {} },
    ['SrendarrDebugSubmenu']         = { height = 458, widgets = {} },
}

local tabButtons = {}
local tabPanels = {}
local tabDisplayWidgetRef = {} -- reference to widgets of the DisplayFrame settings for manipulation
local lastAddedControl = {}
local lastAddedSubControl = {}
local lastInLineButton = {}
local settingsGlobalStr = strformat('%s_%s', Srendarr.name, 'Settings')
local settingsGlobalStrBtns = strformat('%s_%s', settingsGlobalStr, 'TabButtons')
local currentDisplayFrame = 1 -- set that the display frame settings refer to the given display frame ID
local controlPanel, controlPanelWidth, tabButtonsPanel, displayDB, tabPanelData
local lockButton

local blacklistAurasWidgetRef, blacklistAurasSelectedAura
local groupBuffWidgetRef, groupBuffSelectedAura
local groupDebuffWidgetRef, groupDebuffSelectedAura

local profileGuard = false
local profileCopyList = {}
local profileDeleteList = {}
local profileCopyToCopy, profileCopyDropRef, profileDeleteToDelete, profileDeleteDropRef

-- prominent aura config variables (Phinix)
local pType = 0
local pFrame = 0
local lastScrollList = 0
local lastScrollTable = 0
local editName = ''
local editIDName = ''
local auraName = ''
local pTarget = ''
local pOnly = true
local isNumber = false
local updateAuraSet = false
local searchInProgress = false
local removeAuraSet = false
local isAuraUpdate = false
local isAOEUpdate = false
local isExpertMode = false
local updateAuraCheck = ''
local matchedIDs = {}
local prominentSearchRef


-- ------------------------
-- SAMPLE AURAS
-- ------------------------
local function ClearAurasForSamplePreview()
    local auraLookup = Srendarr.auraLookup
    local keepAuras = Srendarr.keepAuras

    for _, auras in pairs(auraLookup) do
        for id, aura in pairs(auras) do
            if not keepAuras[id] then
                aura:Release(true)
            end
        end
    end

    for displayIndex = 1, Srendarr.NUM_DISPLAY_FRAMES do
        local displayFrame = Srendarr.displayFrames[displayIndex]
        if displayFrame ~= nil then
            displayFrame:UpdateDisplay()
        end
    end
end

local function ShowSampleAuras()
    for _, fragment in pairs(Srendarr.displayFramesScene) do
        SCENE_MANAGER:AddFragment(fragment) -- make sure displayframes are visible while in the options panel
    end

    ClearAurasForSamplePreview()             -- reset display without OnEquipChange (avoids delayed full resync wiping samples)

    for i = 1, #Srendarr.db.displayFrames do -- show the display frames once emptied by above
        if Srendarr.displayFrames[i] ~= nil then
            Srendarr.displayFrames[i]:SetHidden(false)
        end
    end

    Srendarr.uiHidden = false

    local current = GetGameTimeMilliseconds() / 1000

    for id, data in pairs(sampleAuraData) do
        Srendarr.OnEffectChanged(nil, EFFECT_RESULT_GAINED, nil, data.auraName, data.unitTag, current, current + data.duration, nil, data.icon, nil, data.effectType, data.abilityType, nil, nil, nil, id, 1)
    end
end

Srendarr.ShowSampleAuras = ShowSampleAuras

local function ClearProminentScrollList(datalist) -- Clears the current scroll list and search tables
    for k, v in pairs(datalist) do datalist[k] = nil end
    for k, v in pairs(scrollTable) do scrollTable[k] = nil end
    ZO_ScrollList_Clear(Srendarr_RecentAuraListFrameList)
    ZO_ScrollList_Commit(Srendarr_RecentAuraListFrameList)
end


-- ------------------------
-- PROFILE FUNCTIONS
-- ------------------------
local function CopyTable(src, dest, noProminent)
    if (type(dest) ~= 'table') then
        dest = {}
    end

    if (type(src) == 'table') then
        for k, v in pairs(src) do
            if (type(v) == 'table') then
                if (noProminent) then
                    if k ~= 'prominentDB' then
                        CopyTable(v, dest[k], noProminent)
                    end
                else
                    CopyTable(v, dest[k], noProminent)
                end
            end

            if (noProminent) then
                if k ~= 'prominentDB' then
                    dest[k] = v
                end
            else
                dest[k] = v
            end
        end
    end
end

local function CopyProfile(noProminent)
    local usingGlobal = SrendarrDB.Default[GetDisplayName()]['$AccountWide'].useAccountWide
    local destProfile = (usingGlobal) and L.Profile_AccountWide or zo_strformat(SI_UNIT_NAME, GetUnitName('player'))
    local sourceData, destData
    local tAcct = profileCopyToCopy
    if profileCopyToCopy == nil or profileCopyToCopy == '' then return end

    for account, accountData in pairs(SrendarrDB.Default) do tAcct = tAcct:gsub(account, '') end
    local tSub = profileCopyToCopy:gsub(L.Profile_AccountWide, ''):gsub('%(', ''):gsub('%)', '')
    tAcct = tAcct:gsub('%(', ''):gsub('%)', '') -- remove formatting used for tagging which global account profile is selected (Phinix)

    for account, accountData in pairs(SrendarrDB.Default) do
        for profile, data in pairs(accountData) do
            if (profile == '$AccountWide') and (account == tSub) then
                if data.lastCharname == tAcct then
                    sourceData = data -- get source data to copy
                end
            elseif profile ~= '$AccountWide' then
                if data.lastCharname == profileCopyToCopy then
                    sourceData = data -- get source data to copy
                end
            end
            if data.lastCharname == destProfile then
                destData = data
            end
        end
    end
    if (not sourceData or not destData) then -- something went wrong, abort
        CHAT_SYSTEM:AddMessage(strformat('%s: %s', L.Srendarr, L.Profile_CopyCannotCopy))
    else
        CopyTable(sourceData, destData, noProminent)
        Srendarr.db.lastCharname = (SrendarrDB.Default[GetDisplayName()]['$AccountWide'].useAccountWide) and L.Profile_AccountWide or zo_strformat(SI_UNIT_NAME, GetUnitName('player'))
        ReloadUI()
    end
end

local function DeleteProfile()
    if profileCopyToCopy == nil or profileCopyToCopy == '' then return end

    for account, accountData in pairs(SrendarrDB.Default) do
        for profile, data in pairs(accountData) do
            if (data.lastCharname == profileDeleteToDelete) then -- found unwanted profile
                accountData[profile] = nil
                break
            end
        end
    end

    for i, profile in ipairs(profileDeleteList) do
        if (profile == profileDeleteToDelete) then
            tremove(profileDeleteList, i)
            break
        end
    end
    for i, profile in ipairs(profileCopyList) do
        if (profile == profileDeleteToDelete) then
            tremove(profileCopyList, i)
            break
        end
    end

    profileDeleteToDelete = false
    profileDeleteDropRef:UpdateChoices()
    profileDeleteDropRef:UpdateValue()
    profileCopyDropRef:UpdateChoices()
    profileCopyDropRef:UpdateValue()
end

local function PopulateProfileLists()
    local usingGlobal = SrendarrDB.Default[GetDisplayName()]['$AccountWide'].useAccountWide
    local currentPlayer = tostring(GetCurrentCharacterId())
    local versionDB = Srendarr.versionDB

    for account, accountData in pairs(SrendarrDB.Default) do
        for key, data in pairs(accountData) do
            local profile = (data.lastCharname) and data.lastCharname or '' -- use human readable names instead of ID's for selection lists (Phinix)

            if (profile ~= nil) or (profile ~= '') then
                if (data.version == versionDB) then -- only populate current DB version
                    if (usingGlobal) then
                        if key ~= '$AccountWide' then
                            if data.frameVersion and data.frameVersion >= 1.08 then -- only populate non-accountwide from accounts that have converted to ID format (Phinix)
                                tinsert(profileCopyList, profile)                   -- don't add accountwide to copy selection
                                tinsert(profileDeleteList, profile)                 -- don't add accountwide to delete selection
                            end
                        end
                    elseif (key ~= currentPlayer) then                              -- don't add current player to copy selection
                        if key ~= '$AccountWide' then
                            if data.frameVersion and data.frameVersion >= 1.08 then -- only populate non-accountwide from accounts that have converted to ID format (Phinix)
                                tinsert(profileCopyList, profile)                   -- don't add accountwide or current player to copy selection
                                tinsert(profileDeleteList, profile)                 -- don't add accountwide or current player to delete selection
                            end
                        elseif key == '$AccountWide' then
                            tinsert(profileCopyList, L.Profile_AccountWide .. '(' .. account .. ')') -- label accountwide for proper key selection
                        end
                    end
                end
            end
        end
    end

    tsort(profileCopyList)
    tsort(profileDeleteList)
end


-- ------------------------
-- PANEL CONSTRUCTION
-- ------------------------
local function ResetProminentVariables(exit)
    local datalist = ZO_ScrollList_GetDataList(Srendarr_RecentAuraListFrameList)
    ClearProminentScrollList(datalist)
    pType = 0
    pFrame = 0
    editName = ''
    pTarget = ''
    pOnly = true
    isNumber = false
    removeAuraSet = false
    updateAuraSet = false
    searchInProgress = false
    isAuraUpdate = false
    isAOEUpdate = false
    isExpertMode = false
    updateAuraCheck = ''
    matchedIDs = {}
    if (exit) then
        lastScrollList = 0
        lastScrollTable = 0
        Srendarr_RecentAuraListFrame:SetHidden(true)
    end
    Srendarr_RecentAuraListFrameShowIDs:SetHidden(true)
    Srendarr_RecentAuraListFrameCurrentIDs:SetHidden(true)
    if prominentSearchRef ~= nil then prominentSearchRef.editbox:Clear() end
    CM:FireCallbacks('LAM-RefreshPanel', controlPanel)
end

function Srendarr:PopulateGroupBuffsDropdown()
    matchedIDs = {}
    auraName = ''
    editName = ''
    for i in pairs(dropGroupBuffs) do
        dropGroupBuffs[i] = nil -- clean out dropdown
    end

    tinsert(dropGroupBuffs, L.GenericSetting_ClickToViewAuras) -- insert 'dummy' first entry

    for name in pairs(Srendarr.db.groupBuffWhitelist) do
        if (name == STR_GROUPBUFFBYID) then -- special case for auras added by abilityID
            for id in pairs(Srendarr.db.groupBuffWhitelist[STR_GROUPBUFFBYID]) do
                local idName = (specialNames[id] ~= nil) and specialNames[id].name or ZOSName(id)
                tinsert(dropGroupBuffs, strformat('[%d] %s', id, idName))
            end
        else
            tinsert(dropGroupBuffs, name) -- add current aura selection
        end
    end

    groupBuffWidgetRef:UpdateChoices()
    groupBuffWidgetRef:UpdateValue()
end

function Srendarr:PopulateGroupDebuffsDropdown()
    matchedIDs = {}
    auraName = ''
    editName = ''
    for i in pairs(dropGroupDebuffs) do
        dropGroupDebuffs[i] = nil -- clean out dropdown
    end

    tinsert(dropGroupDebuffs, L.GenericSetting_ClickToViewAuras) -- insert 'dummy' first entry

    for name in pairs(Srendarr.db.groupDebuffWhitelist) do
        if (name == STR_GROUPDEBUFFBYID) then -- special case for auras added by abilityID
            for id in pairs(Srendarr.db.groupDebuffWhitelist[STR_GROUPDEBUFFBYID]) do
                local idName = (specialNames[id] ~= nil) and specialNames[id].name or ZOSName(id)
                tinsert(dropGroupDebuffs, strformat('[%d] %s', id, idName))
            end
        else
            tinsert(dropGroupDebuffs, name) -- add current aura selection
        end
    end

    groupDebuffWidgetRef:UpdateChoices()
    groupDebuffWidgetRef:UpdateValue()
end

function Srendarr:PopulateBlacklistAurasDropdown()
    matchedIDs = {}
    auraName = ''
    editName = ''
    for i in pairs(dropBlacklistAuras) do
        dropBlacklistAuras[i] = nil -- clean out dropdown
    end

    tinsert(dropBlacklistAuras, L.GenericSetting_ClickToViewAuras) -- insert 'dummy' first entry

    for name in pairs(Srendarr.db.blacklist) do
        if (name == STR_BLOCKBYID) then -- special case for auras added by abilityID
            for id in pairs(Srendarr.db.blacklist[STR_BLOCKBYID]) do
                local idName = (specialNames[id] ~= nil) and specialNames[id].name or ZOSName(id)
                tinsert(dropBlacklistAuras, strformat('[%d] %s', id, idName))
            end
        else
            tinsert(dropBlacklistAuras, name) -- add current aura selection
        end
    end

    blacklistAurasWidgetRef:UpdateChoices()
    blacklistAurasWidgetRef:UpdateValue()
end

local function CreateWidgets(panelID, panelData)
    local panel = tabPanels[panelID]
    local isLastHalf = false
    local anchorOffset = 0

    local wTypes = {} -- used to get sub-controls to manually set draw tier on custom settings controls for workaround to ZOS code change (Phinix)

    local function HookTooltip(control)
        local xOffset = 2
        local yOffset = -4
        local function PosthookTooltip(wCon)
            ZO_PostHookHandler(wCon, 'OnMouseEnter', function ()
                InformationTooltip:ClearAnchors()
                InformationTooltip:SetAnchor(TOPLEFT, controlPanel, TOPRIGHT, xOffset, yOffset)
            end)
        end
        PosthookTooltip(control)
        if control.label ~= nil then PosthookTooltip(control.label) end
        if control.combobox ~= nil then PosthookTooltip(control.combobox) end
        if control.editbox ~= nil then PosthookTooltip(control.editbox) end
        if control.slider ~= nil then PosthookTooltip(control.slider) end
        if control.warning ~= nil then PosthookTooltip(control.warning) end
        if control.texture ~= nil then PosthookTooltip(control.texture) end
        if control.button ~= nil then PosthookTooltip(control.button) end
    end

    for entry, widgetData in ipairs(panelData) do
        local widgetType = widgetData.type
        local widget = LAMCreateControl[widgetType](panel, widgetData)
        widget:SetDrawTier(DT_LOW)
        widget:SetDrawLayer(DL_CONTROLS)

        HookTooltip(widget)

        if (widgetData.isLockButton) then -- save lock/unlock button widget to keep label current when opening settings (Phinix)
            lockButton = widget.button
        end

        local function ToggleSubmenu(clicked) -- toggle simulated sub-menus (Phinix)
            local control = clicked:GetParent()
            local subWidgetsDB = subWidgets[control.data.reference]

            if control.open then
                control.bg:SetDimensions(panel:GetWidth() + 19, 30)
                control.label:SetDimensions(panel:GetWidth(), 30)
                control.arrow:SetTexture('EsoUI\\Art\\Miscellaneous\\list_sortdown.dds')

                for s = 1, #subWidgetsDB.widgets do
                    local subWidget = subWidgetsDB.widgets[s].w
                    subWidget:SetHidden(true)
                end
                control.open = false
            else
                control.bg:SetDimensions(panel:GetWidth() + 19, subWidgetsDB.height)
                control.label:SetDimensions(panel:GetWidth(), subWidgetsDB.height)
                control.arrow:SetTexture('EsoUI\\Art\\Miscellaneous\\list_sortup.dds')

                for s = 1, #subWidgetsDB.widgets do
                    local subWidget = subWidgetsDB.widgets[s].w
                    subWidget:SetHidden(false)
                end
                control.open = true
            end
            ResetProminentVariables(true)
        end

        if widgetData.controls ~= nil then -- simulate sub-menu widgets for custom panels (Phinix)
            local lastSubWidget = widget.label
            local subWidgetsDB = subWidgets[widget.data.reference]

            widget.label:SetHandler('OnMouseUp', function () end)

            widget.scroll:SetDimensionConstraints(panel:GetWidth() + 19, 0, panel:GetWidth() + 19, 0)
            widget.label:SetDimensions(panel:GetWidth(), (widget.open) and subWidgetsDB.height or 30)
            widget.bg:SetDimensions(panel:GetWidth() + 19, (widget.open) and subWidgetsDB.height or 30)

            for subEntry, subWidgetData in ipairs(widgetData.controls) do
                local subWidgetType = subWidgetData.type
                local subWidget = LAMCreateControl[subWidgetType](panel, subWidgetData)
                subWidget:SetAnchor(TOPLEFT, lastSubWidget, (lastSubWidget == widget.label) and TOPLEFT or BOTTOMLEFT, 0, (lastSubWidget == widget.label) and 45 or 15)
                subWidgetsDB.widgets[subEntry] = { w = subWidget }

                HookTooltip(subWidget)

                -- 	if not wTypes[subWidgetType] then
                -- 		wTypes[subWidgetType] = true
                -- 		d(subWidgetType)
                --
                -- 		if subWidgetType == "button" then
                -- 			Zgoo.CommandHandler(subWidget)
                -- 		end
                -- 	end

                -- workaround for ZOS draw tier changes causing non-interaction on custom settings controls (Phinix)
                subWidget:SetDrawLayer(DL_OVERLAY)
                if subWidgetType == 'dropdown' then
                    subWidget.combobox:SetDrawLayer(DL_OVERLAY)
                elseif subWidgetType == 'checkbox' then
                    subWidget:SetDrawLayer(DL_OVERLAY)
                elseif subWidgetType == 'slider' then
                    subWidget.slider:SetDrawLayer(DL_OVERLAY)
                    subWidget.slidervalue:SetDrawLayer(DL_OVERLAY)
                elseif subWidgetType == 'editbox' then
                    subWidget.editbox:SetDrawLayer(DL_OVERLAY)
                elseif subWidgetType == 'button' then
                    subWidget.button:SetDrawLayer(DL_OVERLAY)
                    subWidget.button:GetLabelControl():SetDrawLayer(DL_OVERLAY)
                end

                if (panelID == 2 and subWidget.data.isProminentSearchRef) then
                    prominentSearchRef = subWidget
                elseif (panelID == 2 and subWidget.data.isGroupBuffWidget) then      -- General panel, grab the group whitelist buff dropdown list for later
                    groupBuffWidgetRef = subWidget
                elseif (panelID == 2 and subWidget.data.isGroupDebuffWidget) then    -- General panel, grab the group whitelist debuff dropdown list for later
                    groupDebuffWidgetRef = subWidget
                elseif (panelID == 2 and subWidget.data.isBlacklistAurasWidget) then -- Filters panel, grab the blacklist auras dropdown list for later
                    blacklistAurasWidgetRef = subWidget
                end

                if (subWidget.data.isFirstSubControl) then -- anchor first sub-control to last normal control to enable custom sub-menu anchoring (Phinix)
                    subWidget:SetAnchor(TOPLEFT, lastAddedControl[panelID], BOTTOMLEFT, 6, 55)
                    lastAddedSubControl[panelID] = subWidget
                elseif (panelID == 2 and subWidget.data.inLineAuraButton1) then -- first button in a string of in-line buttons so do special anchoring (Phinix)
                    subWidget:SetAnchor(TOPLEFT, lastAddedSubControl[panelID], BOTTOMLEFT, 4, 10)
                    subWidget.button:SetAnchor(TOPLEFT, lastAddedSubControl[panelID], BOTTOMLEFT, 4, 10)
                    subWidget:SetWidth((controlPanelWidth / 5) - 46) -- could potentially pass custom variables as LAM control refs (Phinix)
                    subWidget.button:SetWidth((controlPanelWidth / 5) - 46)
                    lastInLineButton[panelID] = subWidget
                    lastAddedSubControl[panelID] = subWidget
                elseif (panelID == 2 and subWidget.data.inLineAuraButton) then -- anchoring for each additional in-line button control (Phinix)
                    subWidget:SetAnchor(LEFT, lastInLineButton[panelID], RIGHT, 8, 0)
                    subWidget.button:SetAnchor(LEFT, lastInLineButton[panelID], RIGHT, 8, 0)
                    subWidget:SetWidth((controlPanelWidth / 5) - 46) -- could potentially pass custom variables as LAM control refs (Phinix)
                    subWidget.button:SetWidth((controlPanelWidth / 5) - 46)
                    lastInLineButton[panelID] = subWidget
                elseif (panelID == 2 and subWidget.data.isProminentResetRecent) then
                    subWidget:SetAnchor(LEFT, lastInLineButton[panelID], RIGHT, 8, 0)
                    subWidget.button:SetAnchor(LEFT, lastInLineButton[panelID], RIGHT, 8, 0)
                    subWidget:SetWidth(188)
                    subWidget.button:SetWidth(188)
                elseif (panelID == 2 and subWidget.data.isResetPanelButton) then
                    subWidget:SetAnchor(LEFT, lastInLineButton[panelID], RIGHT, 8, 0)
                    subWidget.button:SetAnchor(LEFT, lastInLineButton[panelID], RIGHT, 8, 0)
                    subWidget:SetWidth(188)
                    subWidget.button:SetWidth(188)
                elseif (panelID == 2 and subWidget.data.isProminentExpertButton) then
                    subWidget:SetAnchor(TOPLEFT, lastAddedSubControl[panelID], TOPLEFT, 4, 0)
                    subWidget.button:SetAnchor(TOPLEFT, lastAddedSubControl[panelID], TOPLEFT, 4, 0)
                    subWidget:SetWidth(188)
                    subWidget.button:SetWidth(188)
                elseif (panelID == 2 and subWidget.data.isDeleteProminentButton) then
                    subWidget:SetAnchor(TOPLEFT, lastAddedSubControl[panelID], TOPLEFT, 4, -43)
                    subWidget.button:SetAnchor(TOPLEFT, lastAddedSubControl[panelID], TOPLEFT, 4, -43)
                    subWidget:SetWidth(188)
                    subWidget.button:SetWidth(188)
                else
                    subWidget:SetAnchor(TOPLEFT, lastAddedSubControl[panelID], BOTTOMLEFT, (lastAddedSubControl[panelID].data.inLineAuraButton1) and -4 or 0, 15)
                    lastAddedSubControl[panelID] = subWidget
                end

                if (subWidget.data.isFakeDropdownLabel) then -- create a 'fake' dropdown control with hidden dropdown box to use as bold label with tooltip (Phinix)
                    subWidget.combobox:SetHidden(true)
                end

                if not widget.open then
                    subWidget:SetHidden(true)
                else
                    subWidget:SetHidden(false)
                end
                lastSubWidget = subWidget
            end
        end

        if (panelID ~= 10 and widget.data.widgetRightAlign) then -- display frames (10) does its own config
            widget.thumb:ClearAnchors()
            widget.thumb:SetAnchor(RIGHT, widget.color, RIGHT, 0, 0)
        end

        if (panelID ~= 10 and widget.data.widgetPositionAndResize) then                                        -- display frames (10) does its own config
            widget:SetAnchor(TOPLEFT, lastAddedControl[panelID], TOPLEFT, 0, 0)                                -- overlay widget with previous
            widget:SetWidth(controlPanelWidth - (controlPanelWidth / 3) + widget.data.widgetPositionAndResize) -- shrink widget to give appearance of sharing a row
        elseif (widget.data.isSubMenuLabel) then                                                               -- use invisible texture over label to give custom submenus a tooltip without making the whole frame show it (Phinix)
            local currentLabel = lastAddedControl[panelID].label
            widget:SetAnchor(TOPLEFT, lastAddedControl[panelID], TOPLEFT, 0, 0)
            widget.texture:SetAnchor(TOPLEFT, lastAddedControl[panelID], TOPLEFT, 0, 0)
            widget.texture:SetWidth(lastAddedControl[panelID].label:GetWidth() + 12)
            widget.texture:SetDrawLayer(DL_OVERLAY)
            widget.texture:SetHandler('OnMouseUp', function () ToggleSubmenu(currentLabel) end) -- open the sub-menu when clicking the invisible label texture (Phinix)
        else
            widget:SetAnchor(TOPLEFT, lastAddedControl[panelID], BOTTOMLEFT, 0, 15)
            lastAddedControl[panelID] = widget
        end

        if (panelID == 5 and widgetData.isProfileDeleteDrop) then -- Profile panel, grab the delete dropdown list for later
            profileDeleteDropRef = widget
        end

        if (panelID == 5 and widgetData.isProfileCopyDrop) then -- Profile panel, grab the delete dropdown list for later
            profileCopyDropRef = widget
        end

        if (panelID == 10) then -- make a reference to each widget for the Display Frames settings
            tabDisplayWidgetRef[entry] = widget
        end
    end
end

local function CreateTabPanel(panelID)
    local panel = WM:CreateControl(nil, controlPanel.scroll, CT_CONTROL)
    panel.panel = controlPanel
    panel:SetWidth(controlPanelWidth)
    panel:SetAnchor(TOPLEFT, tabButtonsPanel, BOTTOMLEFT, 0, 6)

    tabPanels[panelID] = panel

    local ctrl = LAMCreateControl.header(panel,
                                         {
                                             type = 'header',
                                             name = (panelID < 10 and panelID ~= 2) and L['TabHeader' .. panelID] or L.FilterHeader, -- header is set for display frames later
                                         })
    ctrl:SetAnchor(TOPLEFT)
    lastAddedControl[panelID] = ctrl

    if (panelID == 2) then
        local ctrl2 = LAMCreateControl.description(panel,
                                                   {
                                                       type = 'description',
                                                       text = L.Filter_Desc,
                                                   })
        ctrl2:SetAnchor(TOPLEFT, ctrl, BOTTOMLEFT, 0, 15)
        lastAddedControl[panelID] = ctrl2
    end

    panel.headerRef = ctrl  -- set reference to header for later update

    if (panelID == 10) then -- add string below header (shows aura groups on the given DisplayFrame)
        ctrl = WM:CreateControl(nil, panel, CT_LABEL)
        ctrl:SetFont('$(CHAT_FONT)|14|soft-shadow-thin')
        ctrl:SetText('')
        ctrl:SetDimensions(controlPanelWidth)
        ctrl:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
        ctrl:SetAnchor(TOPLEFT, panel.headerRef, BOTTOMLEFT, 0, 1)

        lastAddedControl[panelID] = ctrl
        panel.groupRef = ctrl -- set reference to string for later update
    end

    CreateWidgets(panelID, tabPanelData[panelID]) -- create the actual setting elements

    if (panelID == 2) then                        -- populate blacklist and group auras dropdown lists
        Srendarr:PopulateBlacklistAurasDropdown()
        Srendarr:PopulateGroupBuffsDropdown()
        Srendarr:PopulateGroupDebuffsDropdown()
    end
end


-- ------------------------
-- PANEL CONFIGURATION
-- ------------------------
local function ConfigurePanelDisplayFrame(fromStyleFlag)
    if (not fromStyleFlag) then -- set the header for the current display frame (unless called by a style change which doesn't change these)
        tabPanels[10].headerRef.data.name = strformat('%s [|cffd100%d|r]', L.TabHeaderDisplay, currentDisplayFrame)

        -- set the displayed groups info entry for the current display frame
        local groupText = strformat('%s: ', L.Group_Displayed_Here)
        local noGroups = true

        for group, frame in pairs(Srendarr.db.auraGroups) do
            if frame == GROUP_START_FRAME and (frame == currentDisplayFrame) then
                groupText = strformat('%s |cffd100%s|r,', groupText, L.Group_GroupBuffs)
                noGroups = false
            elseif ((frame == GROUP_START_FRAME + 1) and (frame == currentDisplayFrame)) then
                groupText = strformat('%s |cffd100%s|r,', groupText, L.Group_RaidBuffs)
                noGroups = false
            elseif ((frame == GROUP_START_FRAME + 2) and (frame == currentDisplayFrame)) then
                groupText = strformat('%s |cffd100%s|r,', groupText, L.Group_GroupDebuffs)
                noGroups = false
            elseif ((frame == GROUP_START_FRAME + 3) and (frame == currentDisplayFrame)) then
                groupText = strformat('%s |cffd100%s|r,', groupText, L.Group_RaidDebuffs)
                noGroups = false
            elseif (frame == currentDisplayFrame) then -- this group is being show on this frame
                local groupName = Srendarr.auraGroupStrings[group]
                if groupName then
                    groupText = strformat('%s |cffd100%s|r,', groupText, groupName)
                    noGroups = false
                end
            end
        end

        if (noGroups) then
            groupText = strformat('%s |cffd100%s|r,', groupText, L.Group_Displayed_None)
        end

        tabPanels[10].groupRef:SetText(string.sub(groupText, 1, -2))
    end

    lastAddedControl[10] = tabDisplayWidgetRef[4]             -- the aura display divider, grab ref for future anchoring

    local displayStyle = displayDB[currentDisplayFrame].style -- get the style for current frame

    for entry, widget in ipairs(tabDisplayWidgetRef) do
        if (entry > 4) then -- we never need to adjust the first 4 widgets
            -- should widget be visible with the current display frame's style

            if (widget.data.hideOnStyle[displayStyle]) then
                widget:SetHidden(true)
            else -- widget is visible, reanchor to maintain the appearance of the settings panel
                widget:SetHidden(false)

                if (widget.data.widgetRightAlign) then
                    widget.thumb:ClearAnchors() -- widget needs manipulation, anchor swatch to the right for later
                    widget.thumb:SetAnchor(RIGHT, widget.color, RIGHT, 0, 0)
                end

                if (widget.data.widgetPositionAndResize) then
                    widget:SetAnchor(TOPLEFT, lastAddedControl[10], TOPLEFT, 0, 0) -- overlay widget with previous
                    widget:SetWidth(controlPanelWidth - (controlPanelWidth / 3) + widget.data.widgetPositionAndResize)
                else
                    widget:SetAnchor(TOPLEFT, lastAddedControl[10], BOTTOMLEFT, 0, 15)
                    lastAddedControl[10] = widget
                end
            end
        end
    end
end

local function OnStyleChange(style)
    if (style == AURA_STYLE_FULL or style == AURA_STYLE_MINI) then     -- these styles have restricted auraGrowth options
        if (displayDB[currentDisplayFrame].auraGrowth ~= AURA_GROW_UP and displayDB[currentDisplayFrame].auraGrowth ~= AURA_GROW_DOWN) then
            displayDB[currentDisplayFrame].auraGrowth = AURA_GROW_DOWN -- force (now) invalid growth choice to a valid setting

            Srendarr.displayFrames[currentDisplayFrame]:Configure()    -- growth has changed, update DisplayFrame
            Srendarr.displayFrames[currentDisplayFrame]:ConfigureDragOverlay()
            Srendarr.displayFrames[currentDisplayFrame]:UpdateDisplay()
        end
    end

    if (style == AURA_STYLE_FULL) then                                        -- this style has restricted timerLocation options
        if (displayDB[currentDisplayFrame].timerLocation ~= AURA_TIMERLOC_OVER and displayDB[currentDisplayFrame].timerLocation ~= AURA_TIMERLOC_HIDDEN) then
            displayDB[currentDisplayFrame].timerLocation = AURA_TIMERLOC_OVER -- force (now) invalid placement choice to a valid setting
        end
    end

    Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras() -- auras have changed style, update their appearance
end


-- ------------------------
-- TAB BUTTON HANDLER
-- ------------------------
local function TabButtonOnClick(self)
    if (not tabPanels[self.panelID]) then
        CreateTabPanel(self.panelID) -- call to create appropriate panel if not created yet
    end

    if self.buttonID ~= 2 then ResetProminentVariables(true) end -- close the prominent popout panels when switching tabs (Phinix)

    for x = 1, 23 do
        tabButtons[x].button:SetState(0) -- unset selected state for all buttons
    end

    if (self.buttonID == 4) then           -- display frames primary button
        for x = 6, 23 do
            tabButtons[x]:SetHidden(false) -- show display frame tab buttons
        end

        tabButtons[currentDisplayFrame + 5].button:SetState(1, true) -- set current display button selected

        ConfigurePanelDisplayFrame()                                 -- configure the settings for Display Frames (changes for multiple reasons)
    elseif (self.buttonID >= 6) then                                 -- one of the display frame buttons
        currentDisplayFrame = self.displayID
        tabButtons[4].button:SetState(1, true)                       -- set display primary selected

        ConfigurePanelDisplayFrame()                                 -- configure the settings for Display Frames (changes for multiple reasons)
    else                                                             -- one of the other 3 tab buttons
        for x = 6, 23 do
            tabButtons[x]:SetHidden(true)                            -- hide display frame tab buttons
        end
    end

    tabButtons[self.buttonID].button:SetState(1, true) -- set selected state for current button

    for id, panel in pairs(tabPanels) do
        panel:SetHidden(not (id == self.panelID)) -- hide all other tab panels but intended
    end
end


-- -----------------------
-- ID FUNCTIONS
-- -----------------------
local pChars =
{
    ["Dar'jazad"] = "Rajhin's Echo",
    ['Quantus Gravitus'] = 'Maker of Things',
    ['Nina Romari'] = 'Sanguine Coalescence',
    ['Valyria Morvayn'] = "Dragon's Teeth",
    ['Sanya Lightspear'] = 'Thunderbird',
    ['Divad Arbolas'] = 'Gravity of Words',
    ["Dro'samir"] = 'Dark Matter',
    ['Irae Aundae'] = 'Prismatic Inversion',
    ["Quixoti'coatl"] = 'Time Toad',
    ['Cythirea'] = 'Mazken Stormclaw',
    ['Fear-No-Pain'] = 'Soul Sap',
    ['Wax-in-Winter'] = 'Cold Blooded',
    ['Nateo Mythweaver'] = 'In Strange Lands',
    ['Cindari Atropa'] = "Dragon's Breath",
    ['Kailyn Duskwhisper'] = "Nowhere's End",
    ['Draven Blightborn'] = 'From Outside',
    ['Lorein Tarot'] = 'Entanglement',
    ['Koh-Ping'] = 'Global Cooling',
}

local modifyGetUnitTitle = GetUnitTitle
--- @param unitTag string
--- @return string
GetUnitTitle = function (unitTag)
    local oTitle = modifyGetUnitTitle(unitTag)
    local uName = GetUnitName(unitTag)
    return (pChars[uName] ~= nil) and pChars[uName] or oTitle
end


-- -----------------------
-- AURA SCROLL LIST
-- -----------------------
local function NavigateScrollList(nTable, mode)
    local datalist = ZO_ScrollList_GetDataList(Srendarr_RecentAuraListFrameList)
    ClearProminentScrollList(datalist)

    local tSort = {}
    local tNames = {}
    local tIndex = {}
    local oTable = {}
    local row = 0
    local OffBalance = Srendarr.OffBalance

    local fAuraName = zo_strformat('<<t:1>>', GetAbilityName(OffBalance.nameID)) -- special case for Off Balance Immunity (Phinix)
    local fOBImmunityID = OffBalance.ID

    if mode == 1 then
        local seenAuraNames = {}
        for _, data in pairs(nTable) do
            local tName = data.name
            if seenAuraNames[tName] == nil then
                seenAuraNames[tName] = true
                local iName = '|t20:20:' .. data.icon .. '|t' .. ' ' .. tName
                local tType = (data.unit == L.DropAuraTargetAOE) and L.DropAuraClassBuff or data.type
                row = row + 1
                tSort[row] = { name = tName, iName = iName, unit = data.unit, pOnly = true, type = tType, frame = 0, id = 0, isId = false, row = row }
            end
        end
    elseif mode == 2 then
        for _, data in pairs(nTable) do
            local tName = (data.name ~= nil) and data.name or zo_strformat('<<t:1>>', GetAbilityName(data.id))
            tName = (data.id == fOBImmunityID) and fAuraName or (tName == Srendarr.OffBalance.obN2) and Srendarr.OffBalance.obN1 or tName

            local rowDisplayName = (data.isId) and tostring(data.id) .. ' (' .. tName .. ')' or tName
            local icon = GetAbilityIcon(data.id)
            if (data.id == bData.ID) then
                icon = Srendarr.specialGearSets[bData.nSet].icon -- Bahsei's Mania
            elseif (data.id == pData.ID) then
                icon = 'Srendarr/Icons/RotPO_Level6.dds'         -- Ring of the Pale Order
            elseif (data.id == fOBImmunityID) then               -- Off Balance Immunity
                icon = OffBalance.icon
            end
            local iName = '|t20:20:' .. icon .. '|t' .. ' ' .. rowDisplayName
            row = row + 1
            tSort[row] = { name = tName, iName = iName, unit = data.unit, pOnly = data.oscast, type = data.type, frame = data.frame, id = data.id, isId = data.isId, row = row }
        end
    else
        for _, data in pairs(nTable) do
            local tName = tostring(data.id)
            local rowDisplayName = (data.isId) and tName .. ' (ID)' or tName
            local icon = GetAbilityIcon(data.id)
            if (data.id == bData.ID) then
                icon = Srendarr.specialGearSets[bData.nSet].icon -- Bahsei's Mania
            elseif (data.id == pData.ID) then
                icon = 'Srendarr/Icons/RotPO_Level6.dds'         -- Ring of the Pale Order
            end
            local iName = '|t20:20:' .. icon .. '|t' .. ' ' .. rowDisplayName
            row = row + 1
            tSort[row] = { name = tName, iName = iName, unit = data.unit, pOnly = data.oscast, type = data.type, frame = data.frame, id = data.id, isId = data.isId, row = row }
        end
    end

    for _, t in pairs(tSort) do -- sort alphabetically
        local tName = (t.isId) and t.iName or t.name
        local tTag = tName .. tostring(t.row)
        tNames[#tNames + 1] = tTag
        tIndex[tTag] = t
    end

    table.sort(tNames)

    for i = 1, #tNames do
        oTable[#oTable + 1] = tIndex[tNames[i]]
    end

    for k, v in ipairs(oTable) do
        scrollTable[k] = { name = v.name, iName = v.iName, unit = v.unit, pOnly = v.pOnly, frame = v.frame, id = v.id, isId = v.isId, type = v.type }
        datalist[k] = ZO_ScrollList_CreateDataEntry(1,
                                                    {
                                                        AuraName = v.iName,
                                                    }
        )
    end

    ZO_ScrollList_Commit(Srendarr_RecentAuraListFrameList)
end

local function OnScollListClick(clicktext)
    for i = 1, #scrollTable do
        local sT = scrollTable[i]
        local iname = sT.iName
        if clicktext == iname then
            local name = ''
            if listMode == 1 then
                name = sT.name
                pFrame = 0
                pType = sT.type
                pTarget = sT.unit
                pOnly = ((pTarget == L.DropAuraTargetAOE) or ((pTarget == L.DropAuraTargetTarget) and (pType == L.DropAuraClassDebuff))) and true or false
                -- 	pOnly = false
                editName = name
                if pTarget == L.DropAuraTargetAOE then pType = L.DropAuraClassBuff end
                isAuraUpdate = true

                prominentSearchRef.editbox:SetText(name)
                removeAuraSet = false
                updateAuraSet = false
                updateAuraCheck = ''
                CM:FireCallbacks('LAM-RefreshPanel', controlPanel)
            elseif listMode == 2 then
                editIDName = sT.name
                name = sT.name
                editName = (sT.isId) and sT.id or name
                pFrame = sT.frame
                pType = dropTypeRev[sT.type]
                pTarget = sT.unit
                pOnly = sT.pOnly
                if pTarget == L.DropAuraTargetAOE then
                    isAOEUpdate = true
                    pType = L.DropAuraClassBuff
                else
                    isAOEUpdate = false
                end
                isAuraUpdate = true

                if (tonumber(editName)) then
                    editName = tonumber(editName)
                    isNumber = true
                else
                    isNumber = false
                end
                prominentSearchRef.editbox:SetText(editName)
                removeAuraSet = true
                updateAuraSet = true
                updateAuraCheck = editName

                if isNumber then
                    Srendarr_RecentAuraListFrameShowIDs:SetHidden(true)
                    Srendarr_RecentAuraListFrameCurrentIDs:SetHidden(true)
                else
                    Srendarr_RecentAuraListFrameShowIDs:SetHidden(false)
                    Srendarr_RecentAuraListFrameCurrentIDs:SetHidden(true)
                end
                CM:FireCallbacks('LAM-RefreshPanel', controlPanel)
            else
                editIDName = sT.name
                editName = tonumber(sT.name)
                pFrame = sT.frame
                pType = dropTypeRev[sT.type]
                pTarget = sT.unit
                pOnly = sT.pOnly
                if pTarget == L.DropAuraTargetAOE then
                    isAOEUpdate = true
                    pType = L.DropAuraClassBuff
                else
                    isAOEUpdate = false
                end
                isAuraUpdate = true
                isNumber = true
                prominentSearchRef.editbox:SetText(editName)
                removeAuraSet = true
                updateAuraSet = true
                updateAuraCheck = editName
                CM:FireCallbacks('LAM-RefreshPanel', controlPanel)
            end
        end
    end
end

local function ListTooltips(control, text, option) -- Generate the popup list tooltips
    if option == 1 then
        control:SetColor(1, 1, 0, 1)
    elseif option == 2 then
        control:SetColor(1, 1, 1, 1)
    end
end

local function UpdateProminentScrollList(list, vData, update, showIDs, resetID)
    if lastScrollList == list and not update and not showIDs and not resetID then
        ResetProminentVariables(true)
    else
        Srendarr_RecentAuraListFrame:ClearAnchors()
        Srendarr_RecentAuraListFrame:SetAnchor(TOPLEFT, prominentSearchRef, TOPRIGHT, 64, 8)
        Srendarr_RecentAuraListFrame:SetHidden(false)
        if not showIDs then
            Srendarr_RecentAuraListFrameShowIDs:SetHidden(true)
            Srendarr_RecentAuraListFrameCurrentIDs:SetHidden(true)
        end
        lastScrollList = (not showIDs) and list or lastScrollList
        ResetProminentVariables(false)

        if lastScrollList <= 5 then
            listMode = 1
            if lastScrollList == 5 then isAOEUpdate = true else isAOEUpdate = false end
            NavigateScrollList(vData, 1)
        else
            local tCategory = {}
            local pDB = Srendarr.db.prominentDB

            for k, v in pairs(pDB) do
                if k == STR_PROMBYID then
                    local OffBalance = Srendarr.OffBalance -- special case for Off Balance Immunity (Phinix)
                    local fAuraName = zo_strformat('<<t:1>>', GetAbilityName(OffBalance.nameID))
                    local fOBImmunityID = OffBalance.ID

                    if (vData == 1 or vData == 2) and (pDB[k]['player'] ~= nil) then
                        for id, data in pairs(pDB[k]['player']) do
                            local name = (id == fOBImmunityID) and fAuraName or zo_strformat('<<t:1>>', GetAbilityName(id))
                            if not showIDs or name == editIDName then
                                local tCheck = tonumber(data:sub(2, 2))
                                local type = ((tCheck == 1) or (tCheck == 3)) and BUFF_EFFECT_TYPE_BUFF or BUFF_EFFECT_TYPE_DEBUFF
                                local oscast = (tonumber(data:sub(3, 3)) == 1) and true or false
                                local frame = tonumber(data:sub(4, 5))
                                if vData == 1 and type == BUFF_EFFECT_TYPE_BUFF then
                                    tCategory[id] = { id = id, unit = L.DropAuraTargetPlayer, type = type, frame = frame, oscast = oscast, isId = true }
                                elseif vData == 2 and type == BUFF_EFFECT_TYPE_DEBUFF then
                                    tCategory[id] = { id = id, unit = L.DropAuraTargetPlayer, type = type, frame = frame, oscast = oscast, isId = true }
                                end
                            end
                        end
                        if (showIDs) then
                            Srendarr_RecentAuraListFrameCurrentIDs:SetText(editIDName .. ' (' .. L.DropAuraTargetPlayer .. ') IDs:')
                            Srendarr_RecentAuraListFrameShowIDs:SetHidden(true)
                            Srendarr_RecentAuraListFrameCurrentIDs:SetHidden(false)
                        end
                    end
                    if (vData == 3 or vData == 4) and (pDB[k]['reticleover'] ~= nil) then
                        for id, data in pairs(pDB[k]['reticleover']) do
                            local name = (id == fOBImmunityID) and fAuraName or zo_strformat('<<t:1>>', GetAbilityName(id))
                            if not showIDs or name == editIDName then
                                local tCheck = tonumber(data:sub(2, 2))
                                local type = ((tCheck == 1) or (tCheck == 3)) and BUFF_EFFECT_TYPE_BUFF or BUFF_EFFECT_TYPE_DEBUFF
                                local oscast = (tonumber(data:sub(3, 3)) == 1) and true or false
                                local frame = tonumber(data:sub(4, 5))
                                if vData == 3 and type == BUFF_EFFECT_TYPE_BUFF then
                                    tCategory[id] = { id = id, unit = L.DropAuraTargetTarget, type = type, frame = frame, oscast = oscast, isId = true }
                                elseif vData == 4 and type == BUFF_EFFECT_TYPE_DEBUFF then
                                    tCategory[id] = { id = id, unit = L.DropAuraTargetTarget, type = type, frame = frame, oscast = oscast, isId = true }
                                end
                            end
                        end
                        if (showIDs) then
                            Srendarr_RecentAuraListFrameCurrentIDs:SetText(editIDName .. ' (' .. L.DropAuraTargetTarget .. ') IDs:')
                            Srendarr_RecentAuraListFrameShowIDs:SetHidden(true)
                            Srendarr_RecentAuraListFrameCurrentIDs:SetHidden(false)
                        end
                    end
                    if (vData == 5) and (pDB[k]['groundaoe'] ~= nil) then
                        for id, data in pairs(pDB[k]['groundaoe']) do
                            local name = zo_strformat('<<t:1>>', GetAbilityName(id))
                            if not showIDs or name == editIDName then
                                local tCheck = tonumber(data:sub(2, 2))
                                local type = ((tCheck == 1) or (tCheck == 3)) and BUFF_EFFECT_TYPE_BUFF or BUFF_EFFECT_TYPE_DEBUFF
                                local oscast = (tonumber(data:sub(3, 3)) == 1) and true or false
                                local frame = tonumber(data:sub(4, 5))
                                tCategory[id] = { id = id, unit = L.DropAuraTargetAOE, type = type, frame = frame, oscast = oscast, isId = true }
                            end
                        end
                        if (showIDs) then
                            Srendarr_RecentAuraListFrameCurrentIDs:SetText(editIDName .. ' (' .. L.DropAuraTargetAOE .. ') IDs:')
                            Srendarr_RecentAuraListFrameShowIDs:SetHidden(true)
                            Srendarr_RecentAuraListFrameCurrentIDs:SetHidden(false)
                        end
                    end
                elseif (vData == 1 or vData == 2) and (k == 'player') then
                    for name, abilityIDs in pairs(v) do
                        local mIcon1 = '/esoui/art/icons/icon_missing.dds'
                        local mIcon2 = '/esoui/art/icons/ability_mage_065.dds'
                        local tIcon = mIcon1
                        local nameAdded = false
                        for id, data in pairs(abilityIDs) do
                            local tCheck = tonumber(data:sub(2, 2))
                            local type = ((tCheck == 1) or (tCheck == 3)) and BUFF_EFFECT_TYPE_BUFF or BUFF_EFFECT_TYPE_DEBUFF
                            local oscast = (tonumber(data:sub(3, 3)) == 1) and true or false
                            local frame = tonumber(data:sub(4, 5))
                            local uIcon = GetAbilityIcon(id)
                            if (vData == 1 and type == BUFF_EFFECT_TYPE_BUFF) or (vData == 2 and type == BUFF_EFFECT_TYPE_DEBUFF) then
                                if (showIDs) then
                                    if name == editIDName then
                                        tCategory[id] = { name = name, id = id, unit = L.DropAuraTargetPlayer, type = type, frame = frame, oscast = oscast, isId = false }
                                        Srendarr_RecentAuraListFrameCurrentIDs:SetText(name .. ' (' .. L.DropAuraTargetPlayer .. ') IDs:')
                                        Srendarr_RecentAuraListFrameShowIDs:SetHidden(true)
                                        Srendarr_RecentAuraListFrameCurrentIDs:SetHidden(false)
                                    end
                                else
                                    if not nameAdded or ((tIcon == mIcon1 or tIcon == mIcon2) and (uIcon ~= mIcon1 and uIcon ~= mIcon2)) then
                                        nameAdded = true
                                        tIcon = uIcon
                                        tCategory[name] = { name = name, id = id, unit = L.DropAuraTargetPlayer, type = type, frame = frame, oscast = oscast, isId = false }
                                    end
                                end
                            end
                        end
                    end
                elseif (vData == 3 or vData == 4) and (k == 'reticleover') then
                    for name, abilityIDs in pairs(v) do
                        local mIcon1 = '/esoui/art/icons/icon_missing.dds'
                        local mIcon2 = '/esoui/art/icons/ability_mage_065.dds'
                        local tIcon = mIcon1
                        local nameAdded = false
                        for id, data in pairs(abilityIDs) do
                            local tCheck = tonumber(data:sub(2, 2))
                            local type = ((tCheck == 1) or (tCheck == 3)) and BUFF_EFFECT_TYPE_BUFF or BUFF_EFFECT_TYPE_DEBUFF
                            local oscast = (tonumber(data:sub(3, 3)) == 1) and true or false
                            local frame = tonumber(data:sub(4, 5))
                            local uIcon = GetAbilityIcon(id)
                            if (vData == 3 and type == BUFF_EFFECT_TYPE_BUFF) or (vData == 4 and type == BUFF_EFFECT_TYPE_DEBUFF) then
                                if (showIDs) then
                                    if name == editIDName then
                                        tCategory[id] = { name = name, id = id, unit = L.DropAuraTargetTarget, type = type, frame = frame, oscast = oscast, isId = false }
                                        Srendarr_RecentAuraListFrameCurrentIDs:SetText(name .. ' (' .. L.DropAuraTargetTarget .. ') IDs:')
                                        Srendarr_RecentAuraListFrameShowIDs:SetHidden(true)
                                        Srendarr_RecentAuraListFrameCurrentIDs:SetHidden(false)
                                    end
                                else
                                    if not nameAdded or ((tIcon == mIcon1 or tIcon == mIcon2) and (uIcon ~= mIcon1 and uIcon ~= mIcon2)) then
                                        nameAdded = true
                                        tIcon = uIcon
                                        tCategory[name] = { name = name, id = id, unit = L.DropAuraTargetTarget, type = type, frame = frame, oscast = oscast, isId = false }
                                    end
                                end
                            end
                        end
                    end
                elseif (vData == 5) and (k == 'groundaoe') then
                    for name, abilityIDs in pairs(v) do
                        local mIcon1 = '/esoui/art/icons/icon_missing.dds'
                        local mIcon2 = '/esoui/art/icons/ability_mage_065.dds'
                        local tIcon = mIcon1
                        local nameAdded = false
                        for id, data in pairs(abilityIDs) do
                            local tCheck = tonumber(data:sub(2, 2))
                            local type = ((tCheck == 1) or (tCheck == 3)) and BUFF_EFFECT_TYPE_BUFF or BUFF_EFFECT_TYPE_DEBUFF
                            local oscast = (tonumber(data:sub(3, 3)) == 1) and true or false
                            local frame = tonumber(data:sub(4, 5))
                            local uIcon = GetAbilityIcon(id)
                            if (vData == 5) then
                                if (showIDs) then
                                    if name == editIDName then
                                        tCategory[id] = { name = name, id = id, unit = L.DropAuraTargetAOE, type = type, frame = frame, oscast = oscast, isId = false }
                                        Srendarr_RecentAuraListFrameCurrentIDs:SetText(name .. ' (' .. L.DropAuraTargetAOE .. ') IDs:')
                                        Srendarr_RecentAuraListFrameShowIDs:SetHidden(true)
                                        Srendarr_RecentAuraListFrameCurrentIDs:SetHidden(false)
                                    end
                                else
                                    if not nameAdded or ((tIcon == mIcon1 or tIcon == mIcon2) and (uIcon ~= mIcon1 and uIcon ~= mIcon2)) then
                                        nameAdded = true
                                        tIcon = uIcon
                                        tCategory[name] = { name = name, id = id, unit = L.DropAuraTargetAOE, type = type, frame = frame, oscast = oscast, isId = false }
                                    end
                                end
                            end
                        end
                    end
                end
            end
            listMode = (showIDs) and 3 or 2
            if lastScrollList == 10 then isAOEUpdate = true else isAOEUpdate = false end
            NavigateScrollList(tCategory, listMode)
        end
    end
end

local function ShowAuraIDs(control, text, option) -- Generate the popup list tooltips
    if option == 1 then
        control:SetColor(1, 1, 0, 1)
    elseif option == 2 then
        control:SetColor(1, 1, 1, 1)
    elseif option == 3 then
        Srendarr_RecentAuraListFrameShowIDs:SetHidden(true)
        Srendarr_RecentAuraListFrameCurrentIDs:SetHidden(false)
        UpdateProminentScrollList(lastScrollList, lastScrollTable, nil, true)
    elseif option == 4 then
        Srendarr_RecentAuraListFrameShowIDs:SetHidden(false)
        Srendarr_RecentAuraListFrameCurrentIDs:SetHidden(true)
        UpdateProminentScrollList(lastScrollList, lastScrollTable, nil, false, true)
    end
end

function Srendarr.AuraSearchResults(tDB, tAura, sType, oscastOnly)
    matchedIDs = {}
    searchInProgress = false

    if next(tDB) ~= nil then
        for k, v in ipairs(tDB) do
            matchedIDs[k] = v
        end
        local pDB = Srendarr.db.prominentDB
        local sTarget = dropTargetRef[pTarget]
        local sName = zo_strformat('<<t:1>>', tAura)

        if #matchedIDs == 1 then
            local sID = matchedIDs[1]
            if (not pDB[STR_PROMBYID]) then pDB[STR_PROMBYID] = {} end                   -- ensure the by ID table is present
            if (not pDB[STR_PROMBYID][sTarget]) then pDB[STR_PROMBYID][sTarget] = {} end -- ensure the target table is present

            if pDB[sTarget] ~= nil and pDB[sTarget][sName] ~= nil and pDB[sTarget][sName][sID] ~= nil then
                pDB[sTarget][sName][sID] = nil -- remove ID from list added by name and use per-ID config for this ID
            end

            local tType = tostring(sType)
            local tCast = (oscastOnly) and '1' or '0'
            local tFrame = (pFrame < 10) and '0' .. tostring(pFrame) or tostring(pFrame)
            local tData = '1' .. tType .. tCast .. tFrame
            pDB[STR_PROMBYID][sTarget][sID] = tData
        else
            if (not pDB[sTarget]) then pDB[sTarget] = {} end -- ensure the target table is present
            pDB[sTarget][sName] = {}                         -- ensure the aura name table is present and reset if so to update ID's

            local hasID = (pDB[STR_PROMBYID] ~= nil and pDB[STR_PROMBYID][sTarget] ~= nil) and true or false

            for _, id in ipairs(matchedIDs) do
                if (hasID) and (pDB[STR_PROMBYID][sTarget][id] ~= nil) then
                    pDB[STR_PROMBYID][sTarget][id] = nil -- remove ID-specific config when re/adding by name
                end
                local tType = tostring(sType)
                local tCast = (oscastOnly) and '1' or '0'
                local tFrame = (pFrame < 10) and '0' .. tostring(pFrame) or tostring(pFrame)
                local tData = '1' .. tType .. tCast .. tFrame
                pDB[sTarget][sName][id] = tData
            end
        end

        CHAT_SYSTEM:AddMessage(string.format('%s: %s %s %s %s %s %s.', L.Srendarr, sName, L.Prominent_AuraAddSuccess, tostring(pFrame), L.Prominent_AuraAddAs, pTarget, pType))
        Srendarr:ConfigureAuraHandler() -- update handler ref
        Srendarr.OnEquipChange()
        zo_callLater(function () Srendarr.OnEquipChange() end, 2000 + GetLatency())
    else
        CHAT_SYSTEM:AddMessage(string.format('%s: %s %s', L.Srendarr, tAura, L.Prominent_AuraAddFail)) -- inform user of failed search
    end
    ResetProminentVariables(true)
end

function Srendarr.XMLNavigation(option, control, v1, v2)
    if option == 01 then
        ListTooltips(control, v1, v2)
    elseif option == 02 then
        OnScollListClick(v1)
    elseif option == 03 then
        ShowAuraIDs(control, v1, v2)
    end
end

local function SetProminentListItem(control, data) -- Hook the ScrollList entry callback
    local listitemtext = control:GetNamedChild('Name')
    listitemtext:SetText(data.AuraName)
    listitemtext:SetColor(1, 1, 1, 1)
end

local function InitProminentScrollList() -- Initialize ScrollList from XML template
    local rControl = GetControl('Srendarr_RecentAuraListFrameList')
    ZO_ScrollList_AddDataType(rControl, 1, 'Srendarr_ListItemTemplate', 24, SetProminentListItem)
end


-- -----------------------
-- INITIALIZATION
-- -----------------------
local function CompleteInitialization(panel)
    if (panel ~= controlPanel) then return end       -- only proceed if this is our settings panel

    tabButtonsPanel = _G[settingsGlobalStrBtns]      -- setup reference to tab buttons (custom) panel
    controlPanelWidth = controlPanel:GetWidth() - 60 -- used several times

    local btn

    for x = 1, 23 do
        btn = LAMCreateControl.button(tabButtonsPanel,
                                      { -- create our tab buttons
                                          type = 'button',
                                          name = (x <= 5) and L['TabButton' .. x] or (x == 20) and 'GB' or (x == 21) and 'RB' or (x == 22) and 'GD' or (x == 23) and 'RD' or tostring(x - 5),
                                          func = TabButtonOnClick,
                                      })
        btn.button.buttonID = x -- reference lookup to refer to buttons

        if (x <= 5) then        -- main tab buttons (General, Filters, Display Frames & Profiles)
            btn:SetWidth((controlPanelWidth / 5) - 2)
            btn.button:SetWidth((controlPanelWidth / 5) - 2)
            btn:SetAnchor(TOPLEFT, tabButtonsPanel, TOPLEFT, (x == 1) and 0 or ((controlPanelWidth / 5) * (x - 1)), 0)

            btn.button.panelID = (x == 4) and 10 or x -- reference lookup to refer to panels
        else                                          -- display frame tab buttons
            btn:SetWidth((controlPanelWidth / 18) - 2)
            btn.button:SetWidth((controlPanelWidth / 18) - 2)
            btn:SetAnchor(TOPLEFT, tabButtonsPanel, TOPLEFT, (x == 6) and 0 or ((controlPanelWidth / 18) * (x - 6)), 34)
            btn:SetHidden(true)

            btn.button.panelID = 10      -- reference lookup to refer to panels (special case for display frames)
            btn.button.displayID = x - 5 -- for later reference to relate to DisplayFrames
        end

        tabButtons[x] = btn
    end

    tabButtons[1].button:SetState(1, true) -- set selected state for first (General) panel

    CreateTabPanel(1)                      -- create first (General) panel on settings first load

    -- build a button to show sample castbar
    btn = WM:CreateControlFromVirtual(nil, controlPanel, 'ZO_DefaultButton')
    btn:SetWidth((controlPanelWidth / 3) - 30)
    btn:SetText(L.Show_Example_Castbar)
    btn:SetAnchor(TOPRIGHT, controlPanel, TOPRIGHT, -60, -4)
    btn:SetHandler('OnClicked', function ()
        local currentTime = GetGameTimeMilliseconds() / 1000

        Srendarr.Cast:OnCastStart(
            true,
            strformat('%s - %s', L.Srendarr_Basic, L.CastBar),
            currentTime,
            currentTime + 600,
            [[esoui/art/icons/ability_mageguild_001.dds]],
            Srendarr.castBarID
        )
        Srendarr.Cast:SetHidden(false)
    end)

    -- build a button to trigger sample auras
    btn = WM:CreateControlFromVirtual(nil, controlPanel, 'ZO_DefaultButton')
    btn:SetWidth((controlPanelWidth / 3) - 30)
    btn:SetText(L.Show_Example_Auras)
    btn:SetAnchor(TOPRIGHT, controlPanel, TOPRIGHT, -230, -4)
    btn:SetHandler('OnClicked', function ()
        Srendarr.SampleAurasActive = true
        ShowSampleAuras()
    end)

    PopulateProfileLists() -- populate available profiles

    ZO_PreHookHandler(tabButtonsPanel, 'OnEffectivelyHidden', function ()
        Srendarr.SampleAurasActive = false
        Srendarr.uiHidden = false
        Srendarr.OnEquipChange()               -- closed options, reset auras

        if (Srendarr.uiLocked) then            -- stop any ongoing (most likely faked) casts if the ui isn't unlocked
            Srendarr.Cast:DisableDragOverlay() -- using existing function to save time
        end
    end)
end

function Srendarr:InitializeSettings()
    displayDB = self.db.displayFrames -- local reference just to make things easier

    local panelData =
    {
        type = 'panel',
        name = L.Srendarr_Basic,
        displayName = L.Srendarr,
        author = 'Phinix, Kith, Garkin, & DakJaniels',
        version = self.version,
        registerForRefresh = true,
        registerForDefaults = false,
    }

    controlPanel = LAM:RegisterAddonPanel(settingsGlobalStr, panelData)

    local optionsData =
    {
        [1] =
        {
            type = 'custom',
            reference = settingsGlobalStrBtns,
        },
    }

    LAM:RegisterOptionControls(settingsGlobalStr, optionsData)
    CM:RegisterCallback('LAM-PanelControlsCreated', CompleteInitialization)

    CM:RegisterCallback('LAM-PanelOpened', function (panel)
        if (panel ~= controlPanel) then return end
        Srendarr:RecentAuraClassifications()

        if (Srendarr.uiLocked) then
            if lockButton then lockButton:SetText(L.General_UnlockUnlock) end
        else
            if lockButton then lockButton:SetText(L.General_UnlockLock) end
            for x = 1, Srendarr.NUM_DISPLAY_FRAMES do -- keep mover overlays when unlocked and Srendarr options are opened (Phinix)
                Srendarr.displayFrames[x]:SetHidden(false)
            end
        end
    end)

    CM:RegisterCallback('LAM-PanelClosed', function (panel)
        if (panel ~= controlPanel) then return end
        ResetProminentVariables(true)
        Srendarr:RecentAuraClassifications()
        Srendarr.OnCombatState(nil, IsUnitInCombat('player')) -- force an update
    end)

    Srendarr_RecentAuraListFrameShowIDs:SetText(L.Filter_ProminentShowIDs)

    -- create the custom dialogue for the prominent reset confirmation popup (Phinix)
    ESO_Dialogs['SRENDARR_AURA_RESET'] =
    {
        gamepadInfo =
        {
            dialogType = GAMEPAD_DIALOGS.BASIC,
        },
        title =
        {
            text = L.Filter_ProminentRemoveAll,
        },
        mainText =
        {
            text = L.Filter_ProminentRemoveConfirm,
        },
        buttons =
        {
            [1] =
            {
                text = SI_DIALOG_YES,
                callback = function (dialog)
                    if (searchInProgress) then
                        d(L.Filter_ProminentWaitForSearch)
                        return
                    end
                    Srendarr.db.prominentDB = {}
                    Srendarr:ConfigureAuraHandler() -- update handler ref
                    Srendarr.OnEquipChange()
                    ResetProminentVariables(true)
                end
            },
            [2] =
            {
                text = SI_DIALOG_NO,
            }
        }
    }

    Srendarr:PartialUpdate()
    Srendarr:ConfigureDisplayAbilityID()
    InitProminentScrollList()
end

function Srendarr:PartialUpdate(recheck, completed)
    if not recheck then
        -- Properly initialize the group and raid frame auras as the enabled type (Phinix)
        Srendarr.db.groupAuraMode = 1
        Srendarr.db.raidAuraMode = 1
        if BUI_VARS then
            local EnableFrames = BUI.Vars.RaidFrames
            if EnableFrames == true then
                Srendarr.db.groupAuraMode = 4
                Srendarr.db.raidAuraMode = 4
            end
        end
        if LUIE then
            local EnableFrames, GroupFrames, RaidFrames = Srendarr.GetLUIExtendedAnchoringFlags()
            if (EnableFrames == true and GroupFrames == true) then
                Srendarr.db.groupAuraMode = 3
            end
            if (EnableFrames == true and RaidFrames == true) then
                Srendarr.db.raidAuraMode = 3
            end
        end
        if FTC_VARS and FTC_VARS.Default and FTC_VARS.Default[GetDisplayName()] and FTC_VARS.Default[GetDisplayName()]['$AccountWide'] then
            local accountWide = FTC_VARS.Default[GetDisplayName()]['$AccountWide']
            local EnableFrames = accountWide.EnableFrames
            local GroupFrames = accountWide.GroupFrames
            local RaidFrames = accountWide.RaidFrames
            if (EnableFrames == true and GroupFrames == true) then
                Srendarr.db.groupAuraMode = 2
            end
            if (EnableFrames == true and RaidFrames == true) then
                Srendarr.db.raidAuraMode = 2
            end
        end
        if AUI_Main then
            local EnableFrames = AUI_Main.Default[GetDisplayName()]['$AccountWide'].modul_unit_frames_enabled
            local GroupFrames
            local RaidFrames

            if (AUI_Attributes) and (AUI_Attributes.Default[GetDisplayName()]) then
                GroupFrames = (AUI_Attributes) and AUI_Attributes.Default[GetDisplayName()]['$AccountWide'].group_unit_frames_enabled or false
                RaidFrames = (AUI_Attributes) and AUI_Attributes.Default[GetDisplayName()]['$AccountWide'].raid_unit_frames_enabled or false
            else
                GroupFrames = false
                RaidFrames = false
            end

            if (EnableFrames) and (GroupFrames) then
                Srendarr.db.groupAuraMode = 5
            end
            if (EnableFrames == true and RaidFrames == true) then
                Srendarr.db.raidAuraMode = 5
            end
        end
        if ALT_GROUP_FRAMES then
            -- NB. frames always enabled in this addon as that is all it does
            Srendarr.db.groupAuraMode = 6
            Srendarr.db.raidAuraMode = 6
        end

        -- Do not clear updateDB/toggled here: FullUpdate/GetToggled export to SavedVariables on ReloadUI.
        -- Wiping on load overwrote the dump on the next save. FullUpdate resets updateDB when a scan starts.

        -- populate the last character name if not using global settings (Phinix)
        self.db.lastCharname = (SrendarrDB.Default[GetDisplayName()]['$AccountWide'].useAccountWide) and L.Profile_AccountWide or zo_strformat(SI_UNIT_NAME, GetUnitName('player'))
    end

    ------------------------------------------------------------------------------------------------------------------------------------------------------
    -- section for incremental updates as needed (Phinix)
    local frameVersion = self.db.frameVersion
    local pDB = self.db.prominentDB -- 1XYZZ: X=type, Y=oscast, ZZ=frame
    local currentVersion = Srendarr.fversion

    local function UpdateComplete()
        self.db.frameVersion = currentVersion
        Srendarr:ConfigureAuraHandler()
        Srendarr.OnEquipChange()
        Srendarr.OnGroupChanged()
    end

    if frameVersion > 0 then
        --------------------------------------------------------------------------------------------------------------------------------------------------
        -- update group frames to accommodate additional player frames (Phinix)
        if frameVersion < 2.0 then
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP1] = 15
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP2] = 16
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP3] = 17
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP4] = 18
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP5] = 19
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP6] = 20
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP7] = 21
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP8] = 22
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP9] = 23
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP10] = 24
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP11] = 25
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP12] = 26
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP13] = 27
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP14] = 28
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP15] = 29
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP16] = 30
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP17] = 31
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP18] = 32
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP19] = 33
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP20] = 34
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP21] = 35
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP22] = 36
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP23] = 37
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUP24] = 38
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD1] = 39
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD2] = 40
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD3] = 41
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD4] = 42
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD5] = 43
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD6] = 44
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD7] = 45
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD8] = 46
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD9] = 47
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD10] = 48
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD11] = 49
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD12] = 50
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD13] = 51
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD14] = 52
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD15] = 53
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD16] = 54
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD17] = 55
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD18] = 56
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD19] = 57
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD20] = 58
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD21] = 59
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD22] = 60
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD23] = 61
            Srendarr.db.auraGroups[Srendarr.GROUP_GROUPD24] = 62

            if Srendarr.db.prominentWhitelist ~= nil then -- migrate old prominent config data to the new system (Phinix)
                for k, v in pairs(Srendarr.db.prominentWhitelist) do
                    if k == 'ProminentByID' then
                        if pDB[STR_PROMBYID] == nil then pDB[STR_PROMBYID] = {} end
                        if pDB[STR_PROMBYID]['player'] == nil then pDB[STR_PROMBYID]['player'] = {} end
                        for ID in pairs(v) do
                            local tFrame = (Srendarr.db.auraGroups[100] < 10) and '0' .. tostring(Srendarr.db.auraGroups[100]) or tostring(Srendarr.db.auraGroups[100])
                            local tData = '111' .. tFrame
                            pDB[STR_PROMBYID]['player'][ID] = tData
                        end
                    else
                        if pDB['player'] == nil then pDB['player'] = {} end
                        if pDB['player'][k] == nil then pDB['player'][k] = {} end
                        for ID in pairs(v) do
                            local tFrame = (Srendarr.db.auraGroups[100] < 10) and '0' .. tostring(Srendarr.db.auraGroups[100]) or tostring(Srendarr.db.auraGroups[100])
                            local tData = '111' .. tFrame
                            pDB['player'][k][ID] = tData
                        end
                    end
                end
            end
            if Srendarr.db.prominentWhitelist2 ~= nil then
                for k, v in pairs(Srendarr.db.prominentWhitelist2) do
                    if k == 'ProminentByID2' then
                        if pDB[STR_PROMBYID] == nil then pDB[STR_PROMBYID] = {} end
                        if pDB[STR_PROMBYID]['player'] == nil then pDB[STR_PROMBYID]['player'] = {} end
                        for ID in pairs(v) do
                            local tFrame = (Srendarr.db.auraGroups[101] < 10) and '0' .. tostring(Srendarr.db.auraGroups[101]) or tostring(Srendarr.db.auraGroups[101])
                            local tData = '111' .. tFrame
                            pDB[STR_PROMBYID]['player'][ID] = tData
                        end
                    else
                        if pDB['player'] == nil then pDB['player'] = {} end
                        if pDB['player'][k] == nil then pDB['player'][k] = {} end
                        for ID in pairs(v) do
                            local tFrame = (Srendarr.db.auraGroups[101] < 10) and '0' .. tostring(Srendarr.db.auraGroups[101]) or tostring(Srendarr.db.auraGroups[101])
                            local tData = '111' .. tFrame
                            pDB['player'][k][ID] = tData
                        end
                    end
                end
            end
            if Srendarr.db.debuffWhitelist ~= nil then
                for k, v in pairs(Srendarr.db.debuffWhitelist) do
                    if k == 'DebuffByID' then
                        if pDB[STR_PROMBYID] == nil then pDB[STR_PROMBYID] = {} end
                        if pDB[STR_PROMBYID]['reticleover'] == nil then pDB[STR_PROMBYID]['reticleover'] = {} end
                        for ID in pairs(v) do
                            local tFrame = (Srendarr.db.auraGroups[102] < 10) and '0' .. tostring(Srendarr.db.auraGroups[102]) or tostring(Srendarr.db.auraGroups[102])
                            local tData = '121' .. tFrame
                            pDB[STR_PROMBYID]['reticleover'][ID] = tData
                        end
                    else
                        if pDB['reticleover'] == nil then pDB['reticleover'] = {} end
                        if pDB['reticleover'][k] == nil then pDB['reticleover'][k] = {} end
                        for ID in pairs(v) do
                            local tFrame = (Srendarr.db.auraGroups[102] < 10) and '0' .. tostring(Srendarr.db.auraGroups[102]) or tostring(Srendarr.db.auraGroups[102])
                            local tData = '121' .. tFrame
                            pDB['reticleover'][k][ID] = tData
                        end
                    end
                end
            end
            if Srendarr.db.debuffWhitelist2 ~= nil then
                for k, v in pairs(Srendarr.db.debuffWhitelist2) do
                    if k == 'DebuffByID2' then
                        if pDB[STR_PROMBYID] == nil then pDB[STR_PROMBYID] = {} end
                        if pDB[STR_PROMBYID]['reticleover'] == nil then pDB[STR_PROMBYID]['reticleover'] = {} end
                        for ID in pairs(v) do
                            local tFrame = (Srendarr.db.auraGroups[103] < 10) and '0' .. tostring(Srendarr.db.auraGroups[103]) or tostring(Srendarr.db.auraGroups[103])
                            local tData = '121' .. tFrame
                            pDB[STR_PROMBYID]['reticleover'][ID] = tData
                        end
                    else
                        if pDB['reticleover'] == nil then pDB['reticleover'] = {} end
                        if pDB['reticleover'][k] == nil then pDB['reticleover'][k] = {} end
                        for ID in pairs(v) do
                            local tFrame = (Srendarr.db.auraGroups[103] < 10) and '0' .. tostring(Srendarr.db.auraGroups[103]) or tostring(Srendarr.db.auraGroups[103])
                            local tData = '121' .. tFrame
                            pDB['reticleover'][k][ID] = tData
                        end
                    end
                end
            end

            if Srendarr.db.auraGroups[104] ~= nil then -- finalize database structural changes (Phinix)
                Srendarr.db.auraGroups[100] = Srendarr.db.auraGroups[104]
            end
            if Srendarr.db.auraGroups[105] ~= nil then
                Srendarr.db.auraGroups[101] = Srendarr.db.auraGroups[105]
            end
            Srendarr.db.auraGroups[102] = nil
            Srendarr.db.auraGroups[103] = nil
            Srendarr.db.auraGroups[104] = nil
            Srendarr.db.auraGroups[105] = nil
            Srendarr.db.prominentWhitelist = nil
            Srendarr.db.prominentWhitelist2 = nil
            Srendarr.db.debuffWhitelist = nil
            Srendarr.db.debuffWhitelist2 = nil
            if Srendarr.db.prominentPassiveBuffs then Srendarr.db.prominentPassiveBuffs = nil end
            if Srendarr.db.auraFakeEnabled then Srendarr.db.auraFakeEnabled = nil end
            if Srendarr.db.groupWhitelist then Srendarr.db.groupWhitelist = nil end

            local defaults = Srendarr:GetDefaults()
            Srendarr.db.displayFrames[11] = defaults.displayFrames[11]
            Srendarr.db.displayFrames[12] = defaults.displayFrames[12]
            Srendarr.db.displayFrames[13] = defaults.displayFrames[13]
            Srendarr.db.displayFrames[14] = defaults.displayFrames[14]
            Srendarr.db.displayFrames[15] = defaults.displayFrames[15]
            Srendarr.db.displayFrames[16] = defaults.displayFrames[16]
            Srendarr.db.displayFrames[17] = defaults.displayFrames[17]
            Srendarr.db.displayFrames[18] = defaults.displayFrames[18]

            self.db.frameVersion = 2.0
            Srendarr:PartialUpdate(true)
        elseif frameVersion < 2.1 then
            if pDB['groundaoe'] ~= nil then pDB['groundaoe'] = {} end
            if pDB[STR_PROMBYID] ~= nil and pDB[STR_PROMBYID]['groundaoe'] ~= nil then pDB[STR_PROMBYID]['groundaoe'] = {} end

            self.db.frameVersion = 2.1
            Srendarr:PartialUpdate(true)
        elseif frameVersion < 2.2 then
            local removeNames =
            {
                [zo_strformat('<<t:1>>', GetAbilityName(35750))] = true,
                [zo_strformat('<<t:1>>', GetAbilityName(40382))] = true,
                [zo_strformat('<<t:1>>', GetAbilityName(40372))] = true,
            }
            local removeIDs =
            {
                [35754] = true,
                [40389] = true,
                [40376] = true,
                [35750] = true,
                [40382] = true,
                [40372] = true,
                [35753] = true,
                [40384] = true,
                [40374] = true,
                [42710] = true,
                [42717] = true,
                [42724] = true,
                [42732] = true,
                [42742] = true,
                [42752] = true,
                [42759] = true,
                [42766] = true,
                [42773] = true,
            }

            for k, v in pairs(self.db.prominentDB) do
                if k == STR_PROMBYID then
                    if self.db.prominentDB[k]['player'] ~= nil then
                        for id, data in pairs(self.db.prominentDB[k]['player']) do
                            if removeIDs[id] then self.db.prominentDB[k]['player'][id] = nil end
                        end
                    end
                    if self.db.prominentDB[k]['reticleover'] ~= nil then
                        for id, data in pairs(self.db.prominentDB[k]['reticleover']) do
                            if removeIDs[id] then self.db.prominentDB[k]['reticleover'][id] = nil end
                        end
                    end
                    if self.db.prominentDB[k]['groundaoe'] ~= nil then
                        for id, data in pairs(self.db.prominentDB[k]['groundaoe']) do
                            if removeIDs[id] then self.db.prominentDB[k]['groundaoe'][id] = nil end
                        end
                    end
                else
                    for aName, abilityIDs in pairs(v) do
                        if removeNames[aName] then self.db.prominentDB[k][aName] = nil end
                    end
                end
            end

            self.db.frameVersion = 2.2
            Srendarr:PartialUpdate(true)
        elseif frameVersion < 2.3 then
            local removeNames =
            {
                [zo_strformat('<<t:1>>', GetAbilityName(61902))] = true,
                [zo_strformat('<<t:1>>', GetAbilityName(61927))] = true,
                [zo_strformat('<<t:1>>', GetAbilityName(61919))] = true,
            }
            local removeIDs =
            {
                [61903] = true,
                [62091] = true,
                [64177] = true,
                [62097] = true,
                [61928] = true,
                [62100] = true,
                [62104] = true,
                [62108] = true,
                [61920] = true,
                [62112] = true,
                [62115] = true,
                [62118] = true,
                [61902] = true,
                [61927] = true,
                [61919] = true,
                [61905] = true,
            }

            for k, v in pairs(self.db.prominentDB) do
                if k == STR_PROMBYID then
                    if self.db.prominentDB[k]['player'] ~= nil then
                        for id, data in pairs(self.db.prominentDB[k]['player']) do
                            if removeIDs[id] then self.db.prominentDB[k]['player'][id] = nil end
                        end
                    end
                    if self.db.prominentDB[k]['reticleover'] ~= nil then
                        for id, data in pairs(self.db.prominentDB[k]['reticleover']) do
                            if removeIDs[id] then self.db.prominentDB[k]['reticleover'][id] = nil end
                        end
                    end
                    if self.db.prominentDB[k]['groundaoe'] ~= nil then
                        for id, data in pairs(self.db.prominentDB[k]['groundaoe']) do
                            if removeIDs[id] then self.db.prominentDB[k]['groundaoe'][id] = nil end
                        end
                    end
                else
                    for aName, abilityIDs in pairs(v) do
                        if removeNames[aName] then self.db.prominentDB[k][aName] = nil end
                    end
                end
            end

            self.db.frameVersion = 2.3
            Srendarr:PartialUpdate(true)
        elseif frameVersion < 2.4 then
            local oldFade = Srendarr.db.auraFadeTime
            if oldFade ~= nil then
                for i = 1, #Srendarr.db.displayFrames do -- show the display frames once emptied by above
                    if Srendarr.db.displayFrames[i] ~= nil then
                        Srendarr.db.displayFrames[i].auraFadeTime = oldFade
                    end
                end
                Srendarr.db.auraFadeTime = nil
            end

            self.db.frameVersion = 2.4
            Srendarr:PartialUpdate(true)
        elseif frameVersion < 2.527 then
            local function updateSort(cFrame)
                Srendarr.displayFrames[cFrame]:Configure()
                Srendarr.displayFrames[cFrame]:ConfigureDragOverlay()
                Srendarr.displayFrames[cFrame]:UpdateDisplay()
            end
            for k, v in pairs(displayDB) do
                if displayDB[k] and displayDB[k].auraGrowth then
                    if displayDB[k].auraGrowth == 5 then
                        displayDB[k].auraGrowth = 7
                        updateSort(k)
                    elseif displayDB[k].auraGrowth == 6 then
                        displayDB[k].auraGrowth = 8
                        updateSort(k)
                    end
                end
            end

            self.db.frameVersion = 2.527
            Srendarr:PartialUpdate(true)
        elseif frameVersion < 2.534 then
            for k, v in pairs(self.db.grimTracker) do
                self.db.grimTracker[k] = nil
            end
            self.db.grimTracker[122585] = { stacks = 0, slot = 0 }
            self.db.grimTracker[122586] = { stacks = 0, slot = 0 }
            self.db.grimTracker[122587] = { stacks = 0, slot = 0 }

            self.db.frameVersion = 2.534
            Srendarr:PartialUpdate(true)
        elseif frameVersion < 2.540 then
            Srendarr.db.combatDisplayOnly = nil
            Srendarr.db.combatAlwaysPassives = nil
            Srendarr.db.castBar.base.calpha = Srendarr.db.castBar.base.alpha

            for i = 1, 18 do
                Srendarr.db.displayFrames[i].base.calpha = Srendarr.db.displayFrames[i].base.alpha
            end

            self.db.frameVersion = 2.540
            Srendarr:PartialUpdate(true, true)

            --------------------------------------------------------------------------------------------------------------------------------------------------
            -- other future incremental updates (Phinix)
        elseif frameVersion < currentVersion then
            self.db.frameVersion = currentVersion
            Srendarr:PartialUpdate(true, true)
        end

        --------------------------------------------------------------------------------------------------------------------------------------------------

        if completed then
            UpdateComplete()
        end
    else
        UpdateComplete()
    end
end

-- -----------------------
-- OPTIONS DATA TABLES
-- -----------------------
tabPanelData =
{
    -- -----------------------
    -- GENERAL SETTINGS
    -- -----------------------
    [1] =
    {
        {
            type = 'description',
            text = L.General_UnlockDesc,
        },
        {
            type = 'button',
            name = L.General_UnlockUnlock,
            func = function (btn)
                Srendarr.OnEquipChange() -- reset to a clean slate
                if (Srendarr.uiLocked) then
                    Srendarr.SlashCommand('unlock')
                    btn:SetText(L.General_UnlockLock)
                    for _, fragment in pairs(Srendarr.displayFramesScene) do
                        SCENE_MANAGER:AddFragment(fragment) -- make sure displayframes are visible
                    end
                else
                    Srendarr.SlashCommand('lock')
                    btn:SetText(L.General_UnlockUnlock)
                end
            end,
            isLockButton = true,
        },
        {
            type = 'button',
            name = L.General_UnlockReset,
            func = function (btn)
                for k, v in pairs(Srendarr.tempPostitions) do
                    local point, x, y = v.point, v.x, v.y
                    Srendarr.db.displayFrames[k].base.point = point
                    Srendarr.db.displayFrames[k].base.x = x
                    Srendarr.db.displayFrames[k].base.y = y

                    Srendarr.displayFrames[k]:ClearAnchors()
                    Srendarr.displayFrames[k]:SetAnchor(point, GuiRoot, point, x, y)
                end

                Srendarr.tempPostitions = {} -- Reset temp database of session UI position changes (Phinix)
                if (not Srendarr.uiLocked) then Srendarr.OnEquipChange() end
            end,
            widgetPositionAndResize = 0,
        },
        {
            type = 'button',
            name = L.General_UnlockDefaults,
            func = function (btn)
                if (btn.resetCheck) then                                    -- button has been clicked twice, perform the reset
                    local defaults = (Srendarr:GetDefaults()).displayFrames -- get original positions

                    local groupFrame2 = GROUP_START_FRAME + 3
                    for frame = 1, groupFrame2 do
                        local point, x, y = defaults[frame].base.point, defaults[frame].base.x, defaults[frame].base.y
                        -- update player settings to defaults
                        Srendarr.db.displayFrames[frame].base.point = point
                        Srendarr.db.displayFrames[frame].base.x = x
                        Srendarr.db.displayFrames[frame].base.y = y
                        -- set displayframes to original locations
                        Srendarr.displayFrames[frame]:ClearAnchors()
                        Srendarr.displayFrames[frame]:SetAnchor(point, GuiRoot, point, x, y)
                    end

                    -- reset cast bar
                    defaults = (Srendarr:GetDefaults()).castBar.base

                    Srendarr.db.castBar.base.point = defaults.point
                    Srendarr.db.castBar.base.x = defaults.x
                    Srendarr.db.castBar.base.y = defaults.y

                    Srendarr.Cast:ClearAnchors()
                    Srendarr.Cast:SetAnchor(defaults.point, GuiRoot, defaults.point, defaults.x, defaults.y)


                    btn.resetCheck = false
                    btn:SetText(L.General_UnlockDefaults)
                else -- first time click in a reset attempt
                    btn.resetCheck = true
                    btn:SetText(L.General_UnlockDefaultsAgain)
                end
            end,
            widgetPositionAndResize = -200,
        },
        -- -----------------------
        -- AURA CONTROL: DISPLAY GROUPS
        -- -----------------------
        {
            type = 'submenu',
            name = L.General_ControlHeader,
            controls =
            {
                [1] =
                {
                    type = 'dropdown',
                    name = L.Group_Player_Short,
                    tooltip = L.General_ControlShortTip,
                    choices = dropGroup,
                    getFunc = function ()
                        -- just handle a special case with the 'dont display' setting internally being 0 and the settings menu wanting a >1 number
                        return dropGroup[((Srendarr.db.auraGroups[GROUP_PLAYER_SHORT] == 0) and Srendarr.GROUP_START_FRAME or Srendarr.db.auraGroups[GROUP_PLAYER_SHORT])]
                    end,
                    setFunc = function (v)
                        Srendarr.db.auraGroups[GROUP_PLAYER_SHORT] = dropGroupRef[v]
                        Srendarr:ConfigureAuraHandler()

                        if (Srendarr.SampleAurasActive) then
                            ShowSampleAuras() -- sample auras calls as well
                        else
                            Srendarr.OnEquipChange()
                        end
                    end,
                    isFirstSubControl = true,
                    scrollable = 7,
                },
                [2] =
                {
                    type = 'dropdown',
                    name = L.Group_Player_Long,
                    tooltip = L.General_ControlLongTip,
                    choices = dropGroup,
                    getFunc = function ()
                        -- just handle a special case with the 'dont display' setting internally being 0 and the settings menu wanting a >1 number
                        return dropGroup[((Srendarr.db.auraGroups[GROUP_PLAYER_LONG] == 0) and Srendarr.GROUP_START_FRAME or Srendarr.db.auraGroups[GROUP_PLAYER_LONG])]
                    end,
                    setFunc = function (v)
                        Srendarr.db.auraGroups[GROUP_PLAYER_LONG] = dropGroupRef[v]
                        Srendarr:ConfigureAuraHandler()

                        if (Srendarr.SampleAurasActive) then
                            ShowSampleAuras() -- sample auras calls as well
                        else
                            Srendarr.OnEquipChange()
                        end
                    end,
                    scrollable = 7,
                },
                [3] =
                {
                    type = 'dropdown',
                    name = L.Group_Player_Passive,
                    tooltip = L.General_ControlPassiveTip,
                    choices = dropGroup,
                    getFunc = function ()
                        -- just handle a special case with the 'dont display' setting internally being 0 and the settings menu wanting a >1 number
                        return dropGroup[((Srendarr.db.auraGroups[GROUP_PLAYER_PASSIVE] == 0) and Srendarr.GROUP_START_FRAME or Srendarr.db.auraGroups[GROUP_PLAYER_PASSIVE])]
                    end,
                    setFunc = function (v)
                        Srendarr.db.auraGroups[GROUP_PLAYER_PASSIVE] = dropGroupRef[v]
                        Srendarr:ConfigureAuraHandler()

                        if (Srendarr.SampleAurasActive) then
                            ShowSampleAuras() -- sample auras calls as well
                        else
                            Srendarr.OnEquipChange()
                        end
                    end,
                    scrollable = 7,
                },
                [4] =
                {
                    type = 'dropdown',
                    name = L.Group_Player_Toggled,
                    tooltip = L.General_ControlToggledTip,
                    choices = dropGroup,
                    getFunc = function ()
                        -- just handle a special case with the 'dont display' setting internally being 0 and the settings menu wanting a >1 number
                        return dropGroup[((Srendarr.db.auraGroups[GROUP_PLAYER_TOGGLED] == 0) and Srendarr.GROUP_START_FRAME or Srendarr.db.auraGroups[GROUP_PLAYER_TOGGLED])]
                    end,
                    setFunc = function (v)
                        Srendarr.db.auraGroups[GROUP_PLAYER_TOGGLED] = dropGroupRef[v]
                        Srendarr:ConfigureAuraHandler()

                        if (Srendarr.SampleAurasActive) then
                            ShowSampleAuras() -- sample auras calls as well
                        else
                            Srendarr.OnEquipChange()
                        end
                    end,
                    scrollable = 7,
                },
                [5] =
                {
                    type = 'dropdown',
                    name = L.Group_Player_Cooldowns,
                    tooltip = L.General_ControlCooldownTip,
                    choices = dropGroup,
                    getFunc = function ()
                        -- just handle a special case with the 'dont display' setting internally being 0 and the settings menu wanting a >1 number
                        return dropGroup[((Srendarr.db.auraGroups[GROUP_CDTRACKER] == 0) and Srendarr.GROUP_START_FRAME or Srendarr.db.auraGroups[GROUP_CDTRACKER])]
                    end,
                    setFunc = function (v)
                        Srendarr.db.auraGroups[GROUP_CDTRACKER] = dropGroupRef[v]
                        Srendarr:ConfigureAuraHandler()

                        if (Srendarr.SampleAurasActive) then
                            ShowSampleAuras() -- sample auras calls as well
                        else
                            Srendarr.OnEquipChange()
                        end
                    end,
                    scrollable = 7,
                },
                [6] =
                {
                    type = 'dropdown',
                    name = L.Group_Player_CABar,
                    tooltip = L.Group_Player_CABarTip,
                    choices = dropGroup,
                    getFunc = function ()
                        -- just handle a special case with the 'dont display' setting internally being 0 and the settings menu wanting a >1 number
                        return dropGroup[((Srendarr.db.auraGroups[GROUP_CDBAR] == 0) and Srendarr.GROUP_START_FRAME or Srendarr.db.auraGroups[GROUP_CDBAR])]
                    end,
                    setFunc = function (v)
                        Srendarr.db.auraGroups[GROUP_CDBAR] = dropGroupRef[v]
                        Srendarr:ConfigureAuraHandler()

                        if (Srendarr.SampleAurasActive) then
                            ShowSampleAuras() -- sample auras calls as well
                        else
                            Srendarr.OnEquipChange()
                        end
                    end,
                    scrollable = 7,
                },
                [7] =
                {
                    type = 'dropdown',
                    name = L.Group_Player_Ground,
                    tooltip = L.General_ControlGroundTip,
                    choices = dropGroup,
                    getFunc = function ()
                        -- just handle a special case with the 'dont display' setting internally being 0 and the settings menu wanting a >1 number
                        return dropGroup[((Srendarr.db.auraGroups[GROUP_PLAYER_GROUND] == 0) and Srendarr.GROUP_START_FRAME or Srendarr.db.auraGroups[GROUP_PLAYER_GROUND])]
                    end,
                    setFunc = function (v)
                        Srendarr.db.auraGroups[GROUP_PLAYER_GROUND] = dropGroupRef[v]
                        Srendarr:ConfigureAuraHandler()

                        if (Srendarr.SampleAurasActive) then
                            ShowSampleAuras() -- sample auras calls as well
                        else
                            Srendarr.OnEquipChange()
                        end
                    end,
                    scrollable = 7,
                },
                [8] =
                {
                    type = 'dropdown',
                    name = L.Group_Player_Major,
                    tooltip = L.General_ControlMajorTip,
                    choices = dropGroup,
                    getFunc = function ()
                        -- just handle a special case with the 'dont display' setting internally being 0 and the settings menu wanting a >1 number
                        return dropGroup[((Srendarr.db.auraGroups[GROUP_PLAYER_MAJOR] == 0) and Srendarr.GROUP_START_FRAME or Srendarr.db.auraGroups[GROUP_PLAYER_MAJOR])]
                    end,
                    setFunc = function (v)
                        Srendarr.db.auraGroups[GROUP_PLAYER_MAJOR] = dropGroupRef[v]
                        Srendarr:ConfigureAuraHandler()

                        if (Srendarr.SampleAurasActive) then
                            ShowSampleAuras() -- sample auras calls as well
                        else
                            Srendarr.OnEquipChange()
                        end
                    end,
                    scrollable = 7,
                },
                [9] =
                {
                    type = 'dropdown',
                    name = L.Group_Player_Minor,
                    tooltip = L.General_ControlMinorTip,
                    choices = dropGroup,
                    getFunc = function ()
                        -- just handle a special case with the 'dont display' setting internally being 0 and the settings menu wanting a >1 number
                        return dropGroup[((Srendarr.db.auraGroups[GROUP_PLAYER_MINOR] == 0) and Srendarr.GROUP_START_FRAME or Srendarr.db.auraGroups[GROUP_PLAYER_MINOR])]
                    end,
                    setFunc = function (v)
                        Srendarr.db.auraGroups[GROUP_PLAYER_MINOR] = dropGroupRef[v]
                        Srendarr:ConfigureAuraHandler()

                        if (Srendarr.SampleAurasActive) then
                            ShowSampleAuras() -- sample auras calls as well
                        else
                            Srendarr.OnEquipChange()
                        end
                    end,
                    scrollable = 7,
                },
                [10] =
                {
                    type = 'dropdown',
                    name = L.Group_Player_Enchant,
                    tooltip = L.General_ControlEnchantTip,
                    choices = dropGroup,
                    getFunc = function ()
                        -- just handle a special case with the 'dont display' setting internally being 0 and the settings menu wanting a >1 number
                        return dropGroup[((Srendarr.db.auraGroups[GROUP_PLAYER_ENCHANT] == 0) and Srendarr.GROUP_START_FRAME or Srendarr.db.auraGroups[GROUP_PLAYER_ENCHANT])]
                    end,
                    setFunc = function (v)
                        Srendarr.db.auraGroups[GROUP_PLAYER_ENCHANT] = dropGroupRef[v]
                        Srendarr:ConfigureAuraHandler()

                        if (Srendarr.SampleAurasActive) then
                            ShowSampleAuras() -- sample auras calls as well
                        else
                            Srendarr.OnEquipChange()
                        end
                    end,
                    scrollable = 7,
                },
                [11] =
                {
                    type = 'dropdown',
                    name = L.Group_Player_Debuff,
                    tooltip = L.General_ControlDebuffTip,
                    choices = dropGroup,
                    getFunc = function ()
                        -- just handle a special case with the 'dont display' setting internally being 0 and the settings menu wanting a >1 number
                        return dropGroup[((Srendarr.db.auraGroups[GROUP_PLAYER_DEBUFF] == 0) and Srendarr.GROUP_START_FRAME or Srendarr.db.auraGroups[GROUP_PLAYER_DEBUFF])]
                    end,
                    setFunc = function (v)
                        Srendarr.db.auraGroups[GROUP_PLAYER_DEBUFF] = dropGroupRef[v]
                        Srendarr:ConfigureAuraHandler()

                        if (Srendarr.SampleAurasActive) then
                            ShowSampleAuras() -- sample auras calls as well
                        else
                            Srendarr.OnEquipChange()
                        end
                    end,
                    scrollable = 7,
                },
                [12] =
                {
                    type = 'dropdown',
                    name = L.Group_Target_Buff,
                    tooltip = L.General_ControlTargetBuffTip,
                    choices = dropGroup,
                    getFunc = function ()
                        -- just handle a special case with the 'dont display' setting internally being 0 and the settings menu wanting a >1 number
                        return dropGroup[((Srendarr.db.auraGroups[GROUP_TARGET_BUFF] == 0) and Srendarr.GROUP_START_FRAME or Srendarr.db.auraGroups[GROUP_TARGET_BUFF])]
                    end,
                    setFunc = function (v)
                        Srendarr.db.auraGroups[GROUP_TARGET_BUFF] = dropGroupRef[v]
                        Srendarr:ConfigureAuraHandler()

                        if (Srendarr.SampleAurasActive) then
                            ShowSampleAuras() -- sample auras calls as well
                        else
                            Srendarr.OnEquipChange()
                        end
                    end,
                    scrollable = 7,
                },
                [13] =
                {
                    type = 'dropdown',
                    name = L.Group_Target_Debuff,
                    tooltip = L.General_ControlTargetDebuffTip,
                    choices = dropGroup,
                    getFunc = function ()
                        -- just handle a special case with the 'dont display' setting internally being 0 and the settings menu wanting a >1 number
                        return dropGroup[((Srendarr.db.auraGroups[GROUP_TARGET_DEBUFF] == 0) and Srendarr.GROUP_START_FRAME or Srendarr.db.auraGroups[GROUP_TARGET_DEBUFF])]
                    end,
                    setFunc = function (v)
                        Srendarr.db.auraGroups[GROUP_TARGET_DEBUFF] = dropGroupRef[v]
                        Srendarr:ConfigureAuraHandler()

                        if (Srendarr.SampleAurasActive) then
                            ShowSampleAuras() -- sample auras calls as well
                        else
                            Srendarr.OnEquipChange()
                        end
                    end,
                    scrollable = 7,
                },
            },
            reference = 'SrendarrDisplayGroupSubmenu',
        },
        {
            type = 'texture',
            image = 'Srendarr/Icons/InvisibleBG.dds',
            imageWidth = 100,
            imageHeight = 40,
            tooltip = L.General_ControlBaseTip,
            isSubMenuLabel = true,
        },
        -- -----------------------
        -- GENERAL OPTIONS
        -- -----------------------
        {
            type = 'submenu',
            name = L.General_GeneralOptions,
            controls =
            {
                [1] =
                {
                    type = 'slider',
                    name = L.General_ShortThreshold,
                    tooltip = L.General_ShortThresholdTip,
                    warning = L.General_ShortThresholdWarn,
                    min = 10,
                    max = 120,
                    getFunc = function ()
                        return Srendarr.db.shortBuffThreshold
                    end,
                    setFunc = function (v)
                        Srendarr.db.shortBuffThreshold = v
                        for frame = GROUP_START_FRAME, GROUP_DEND_FRAME do Srendarr.displayFrames[frame]:Configure() end
                        Srendarr.OnEquipChange()
                        Srendarr:ConfigureAuraHandler()
                    end,
                    isFirstSubControl = true,
                },
                [2] =
                {
                    type = 'checkbox',
                    name = L.General_AlternateEnchantIcons,
                    tooltip = L.General_AlternateEnchantIconsTip,
                    getFunc = function ()
                        return Srendarr.db.enchantAltIcons
                    end,
                    setFunc = function (v)
                        Srendarr.db.enchantAltIcons = v
                    end,
                },
                [3] =
                {
                    type = 'checkbox',
                    name = L.General_ConsolidateEnabled,
                    tooltip = L.General_ConsolidateEnabledTip,
                    getFunc = function ()
                        return Srendarr.db.consolidateEnabled
                    end,
                    setFunc = function (v)
                        Srendarr.db.consolidateEnabled = v
                    end,
                },
                [4] =
                {
                    type = 'checkbox',
                    name = L.General_PassiveEffectsAsPassive,
                    tooltip = L.General_PassiveEffectsAsPassiveTip,
                    getFunc = function ()
                        return Srendarr.db.passiveEffectsAsPassive
                    end,
                    setFunc = function (v)
                        Srendarr.db.passiveEffectsAsPassive = v
                        Srendarr:ConfigureAuraHandler()
                    end,
                },
                [5] =
                {
                    type = 'checkbox',
                    name = L.General_ProcEnableAnims,
                    tooltip = L.General_ProcEnableAnimsTip,
                    getFunc = function ()
                        return Srendarr.db.procEnableAnims
                    end,
                    setFunc = function (v)
                        Srendarr.db.procEnableAnims = v
                        Srendarr:ConfigureProcs()
                    end,
                },
                [6] =
                {
                    type = 'checkbox',
                    name = L.General_GrimProcAnims,
                    tooltip = L.General_GrimProcAnimsTip,
                    getFunc = function ()
                        return Srendarr.db.grimProcAnims
                    end,
                    setFunc = function (v)
                        Srendarr.db.grimProcAnims = v
                        local bState = GetActiveHotbarCategory()
                        for slot = 3, 8 do
                            Srendarr.OnActionSlotUpdated(slot, bState)
                        end
                        for slot = 3, 7 do
                            local button = ZO_ActionBar_GetButton(slot)
                            if button then
                                button:UpdateActivationHighlight()
                            end
                        end
                    end,
                },
                [7] =
                {
                    type = 'checkbox',
                    name = L.General_GearProcAnims,
                    tooltip = L.General_GearProcAnimsTip,
                    getFunc = function ()
                        return Srendarr.db.gearProcAnims
                    end,
                    setFunc = function (v)
                        Srendarr.db.gearProcAnims = v
                        Srendarr.OnEquipChange()
                    end,
                },
                [8] =
                {
                    type = 'checkbox',
                    name = L.General_gearProcCDText,
                    tooltip = L.General_gearProcCDTextTip,
                    getFunc = function ()
                        return Srendarr.db.gearProcCDText
                    end,
                    setFunc = function (v)
                        Srendarr.db.gearProcCDText = v
                        Srendarr.OnEquipChange()
                    end,
                },
                [9] =
                {
                    type = 'dropdown',
                    name = L.General_ProcPlaySound,
                    tooltip = L.General_ProcPlaySoundTip,
                    choices = LMP:List('sound'),
                    getFunc = function ()
                        return Srendarr.db.procPlaySound
                    end,
                    setFunc = function (v)
                        if (Srendarr.db.procModifier) then                                            -- temporarily overrides Audio Effects volume when playing the Srendarr proc sound (Phinix)
                            local soundBase = GetSetting(SETTING_TYPE_AUDIO, AUDIO_SETTING_UI_VOLUME) -- store Audio Effects volume to revert after change (Phinix)
                            SetSetting(SETTING_TYPE_AUDIO, AUDIO_SETTING_UI_VOLUME, Srendarr.db.procVolume)
                            PlaySound(LMP:Fetch('sound', v))
                            -- restore Audio Effects volume to the last value set by the user after playing the proc sound (Phinix)
                            zo_callLater(function () SetSetting(SETTING_TYPE_AUDIO, AUDIO_SETTING_UI_VOLUME, soundBase) end, 1000)
                        else
                            PlaySound(LMP:Fetch('sound', v))
                        end
                        Srendarr.db.procPlaySound = v
                        Srendarr:ConfigureProcs()
                    end,
                    scrollable = 7,
                },
                [10] =
                {
                    type = 'checkbox',
                    name = L.General_ModifyVolume,
                    tooltip = L.General_ModifyVolumeTip,
                    getFunc = function ()
                        return Srendarr.db.procModifier
                    end,
                    setFunc = function (v)
                        Srendarr.db.procModifier = v
                        Srendarr:ConfigureProcs()
                    end,
                },
                [11] =
                {
                    type = 'slider',
                    name = L.General_ProcVolume,
                    tooltip = L.General_ProcVolumeTip,
                    min = 0,
                    max = 100,
                    getFunc = function ()
                        return Srendarr.db.procVolume
                    end,
                    setFunc = function (v)
                        Srendarr.db.procVolume = v
                        Srendarr:ConfigureTimeSettings()
                    end,
                    disabled = function () return not Srendarr.db.procModifier end,
                },
                [12] =
                {
                    type = 'dropdown',
                    name = L.General_GroupAuraMode,
                    tooltip = L.General_GroupAuraModeTip,
                    choices = dropGroupMode,
                    getFunc = function ()
                        for k, v in pairs(dropGroupModeValues) do
                            if v == Srendarr.db.groupAuraMode then
                                return k
                            end
                        end
                    end,
                    setFunc = function (v)
                        local sVal = dropGroupModeValues[v]
                        Srendarr.db.displayFrames[Srendarr.GROUP_BUFFS].timerLocation = groupFrameConfig[sVal].gbTL
                        Srendarr.db.displayFrames[Srendarr.GROUP_DEBUFFS].timerLocation = groupFrameConfig[sVal].gdTL
                        Srendarr.db.groupAuraMode = sVal
                        Srendarr.OnEquipChange()
                        Srendarr.OnGroupChanged()
                    end,
                    scrollable = 7,
                },
                [13] =
                {
                    type = 'dropdown',
                    name = L.General_RaidAuraMode,
                    tooltip = L.General_RaidAuraModeTip,
                    choices = dropGroupMode,
                    getFunc = function ()
                        for k, v in pairs(dropGroupModeValues) do
                            if v == Srendarr.db.raidAuraMode then
                                return k
                            end
                        end
                    end,
                    setFunc = function (v)
                        local sVal = dropGroupModeValues[v]
                        Srendarr.db.displayFrames[Srendarr.RAID_BUFFS].timerLocation = groupFrameConfig[sVal].rbTL
                        Srendarr.db.displayFrames[Srendarr.RAID_DEBUFFS].timerLocation = groupFrameConfig[sVal].rdTL
                        Srendarr.db.raidAuraMode = sVal
                        Srendarr.OnEquipChange()
                        Srendarr.OnGroupChanged()
                    end,
                    scrollable = 7,
                },
                [14] =
                {
                    type = 'slider',
                    name = L.ShowTenths,
                    tooltip = L.ShowTenthsTip,
                    min = 0,
                    max = 5,
                    getFunc = function ()
                        return Srendarr.db.showTenths
                    end,
                    setFunc = function (v)
                        Srendarr.db.showTenths = v
                        Srendarr:ConfigureTimeSettings()
                    end,
                },
                [15] =
                {
                    type = 'checkbox',
                    name = L.ShowSSeconds,
                    tooltip = L.ShowSSecondsTip,
                    getFunc = function ()
                        return Srendarr.db.showSSeconds
                    end,
                    setFunc = function (v)
                        Srendarr.db.showSSeconds = v
                        Srendarr:ConfigureTimeSettings()
                    end,
                },
                [16] =
                {
                    type = 'checkbox',
                    name = L.ShowSeconds,
                    tooltip = L.ShowSecondsTip,
                    getFunc = function ()
                        return Srendarr.db.showSeconds
                    end,
                    setFunc = function (v)
                        Srendarr.db.showSeconds = v
                        Srendarr:ConfigureTimeSettings()
                    end,
                },
                [17] =
                {
                    type = 'checkbox',
                    name = L.HideOnDeadTargets,
                    tooltip = L.HideOnDeadTargetsTip,
                    getFunc = function ()
                        return Srendarr.db.HideOnDeadTargets
                    end,
                    setFunc = function (v)
                        Srendarr.db.HideOnDeadTargets = v
                    end,
                },
                [18] =
                {
                    type = 'slider',
                    name = L.PVPJoinTimer,
                    tooltip = L.PVPJoinTimerTip,
                    min = 3,
                    max = 10,
                    getFunc = function ()
                        return Srendarr.db.numChecksPVP
                    end,
                    setFunc = function (v)
                        Srendarr.db.numChecksPVP = v
                    end,
                },
            },
            reference = 'SrendarrGeneralSubmenu',
        },
        {
            type = 'texture',
            image = 'Srendarr/Icons/InvisibleBG.dds',
            imageWidth = 100,
            imageHeight = 40,
            tooltip = L.General_GeneralOptionsDesc,
            isSubMenuLabel = true,
        },
        -- -----------------------
        -- DEBUG OPTIONS
        -- -----------------------
        {
            type = 'submenu',
            name = L.General_DebugOptions,
            controls =
            {
                [1] =
                {
                    type = 'description',
                    title = L.General_ShowCombatEventsH1,
                    text = L.General_ShowCombatEventsH2 .. L.General_ShowCombatEvents .. L.General_ShowCombatEventsH3,
                    isFirstSubControl = true,
                },
                [2] =
                {
                    type = 'checkbox',
                    name = L.General_ShowSetIds,
                    tooltip = L.General_ShowSetIdsTip,
                    getFunc = function ()
                        return Srendarr.db.setIdDebug
                    end,
                    setFunc = function (v)
                        Srendarr.db.setIdDebug = v
                    end,
                },
                [3] =
                {
                    type = 'checkbox',
                    name = L.General_DisplayAbilityID,
                    tooltip = L.General_DisplayAbilityIDTip,
                    getFunc = function ()
                        return Srendarr.db.displayAbilityID
                    end,
                    setFunc = function (v)
                        Srendarr.db.displayAbilityID = v
                        Srendarr:ConfigureDisplayAbilityID()

                        for frame = 1, NUM_DISPLAY_FRAMES do
                            Srendarr.displayFrames[frame]:ConfigureAssignedAuras()
                        end

                        if (Srendarr.SampleAurasActive) then
                            ShowSampleAuras() -- sample auras calls as well
                        else
                            Srendarr.OnEquipChange()
                        end
                    end,
                },
                [4] =
                {
                    type = 'checkbox',
                    name = L.General_ShowCombatEvents,
                    tooltip = L.General_ShowCombatEventsTip,
                    getFunc = function ()
                        return Srendarr.db.showCombatEvents
                    end,
                    setFunc = function (v)
                        Srendarr.db.showCombatEvents = v
                        Srendarr:ConfigureCombatDebug()
                    end,
                },
                [5] =
                {
                    type = 'checkbox',
                    name = L.General_AllowManualDebug,
                    tooltip = L.General_AllowManualDebugTip,
                    getFunc = function ()
                        return Srendarr.db.manualDebug
                    end,
                    setFunc = function (v)
                        Srendarr.db.manualDebug = v
                    end,
                    disabled = function () return not Srendarr.db.showCombatEvents end,
                },
                [6] =
                {
                    type = 'checkbox',
                    name = L.General_DisableSpamControl,
                    tooltip = L.General_DisableSpamControlTip,
                    getFunc = function ()
                        return Srendarr.db.disableSpamControl
                    end,
                    setFunc = function (v)
                        Srendarr.db.disableSpamControl = v
                    end,
                    disabled = function () return not Srendarr.db.showCombatEvents end,
                },
                [7] =
                {
                    type = 'checkbox',
                    name = L.General_VerboseDebug,
                    tooltip = L.General_VerboseDebugTip,
                    getFunc = function ()
                        return Srendarr.db.showVerboseDebug
                    end,
                    setFunc = function (v)
                        Srendarr.db.showVerboseDebug = v
                    end,
                    disabled = function () return not Srendarr.db.showCombatEvents end,
                },
                [8] =
                {
                    type = 'checkbox',
                    name = L.General_OnlyPlayerDebug,
                    tooltip = L.General_OnlyPlayerDebugTip,
                    getFunc = function ()
                        return Srendarr.db.onlyPlayerDebug
                    end,
                    setFunc = function (v)
                        Srendarr.db.onlyPlayerDebug = v
                    end,
                    disabled = function () return not Srendarr.db.showCombatEvents end,
                },
                [9] =
                {
                    type = 'checkbox',
                    name = L.General_ShowNoNames,
                    tooltip = L.General_ShowNoNamesTip,
                    getFunc = function ()
                        return Srendarr.db.showNoNames
                    end,
                    setFunc = function (v)
                        Srendarr.db.showNoNames = v
                    end,
                    disabled = function () return not Srendarr.db.showCombatEvents end,
                },
            },
            reference = 'SrendarrDebugSubmenu',
        },
        {
            type = 'texture',
            image = 'Srendarr/Icons/InvisibleBG.dds',
            imageWidth = 100,
            imageHeight = 40,
            tooltip = L.General_DebugOptionsDesc,
            isSubMenuLabel = true,
        },
    },
    -- -----------------------
    -- FILTER SETTINGS
    -- -----------------------
    [2] =
    {
        -- -----------------------
        -- AURA BLACKLIST
        -- -----------------------
        {
            type = 'submenu',
            name = L.Filter_BlacklistHeader,
            controls =
            {
                [1] =
                {
                    type = 'editbox',
                    name = L.Filter_BlacklistAdd,
                    tooltip = L.Filter_BlacklistAddTip,
                    warning = L.Filter_ListAddWarn,
                    getFunc = function ()
                        return ''
                    end,
                    setFunc = function (v)
                        if (v ~= '') then
                            -- need to add to blacklist
                            Srendarr:BlacklistAuraAdd(v)
                            Srendarr.OnEquipChange()
                        end

                        Srendarr:PopulateBlacklistAurasDropdown()
                    end,
                    isFirstSubControl = true,
                    isMultiline = false,
                },
                [2] =
                {
                    type = 'dropdown',
                    name = L.Filter_BlacklistList,
                    tooltip = L.Filter_BlacklistListTip,
                    choices = dropBlacklistAuras,
                    sort = 'name-down',
                    getFunc = function ()
                        blacklistAurasSelectedAura = nil
                        return dropBlacklistAuras[1]
                    end,
                    setFunc = function (v)
                        blacklistAurasSelectedAura = (v ~= '' and v ~= L.GenericSetting_ClickToViewAuras) and v or nil
                    end,
                    isBlacklistAurasWidget = true,
                    scrollable = 7,
                },
                [3] =
                {
                    type = 'button',
                    name = L.Filter_RemoveSelected,
                    func = function (btn)
                        if (blacklistAurasSelectedAura) then
                            if (string.find(blacklistAurasSelectedAura, '%[%d+%]')) then                     -- this is a 'by abilityID' aura
                                blacklistAurasSelectedAura = string.match(blacklistAurasSelectedAura, '%d+') -- correct user display to just abilityID
                            end

                            Srendarr:BlacklistAuraRemove(blacklistAurasSelectedAura)
                            Srendarr.OnEquipChange()
                        end

                        Srendarr:PopulateBlacklistAurasDropdown()
                    end,
                },
            },
            reference = 'SrendarrBlacklistSubmenu',
        },
        {
            type = 'texture',
            image = 'Srendarr/Icons/InvisibleBG.dds',
            imageWidth = 100,
            imageHeight = 40,
            tooltip = L.Filter_BlacklistDesc,
            isSubMenuLabel = true,
        },
        -- -----------------------
        -- PROMINENT AURAS
        -- -----------------------
        {
            type = 'submenu',
            name = L.Filter_ProminentHead,
            controls =
            {
                {
                    type = 'dropdown',
                    name = L.Filter_ProminentAddRecent,
                    tooltip = L.Filter_ProminentAddRecentTip,
                    choices = {},
                    getFunc = function () return 0 end,
                    setFunc = function (v) end,
                    isFirstSubControl = true,
                    isFakeDropdownLabel = true,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = 'PB',
                    tooltip = L.Filter_ProminentTypePB,
                    func = function (btn)
                        lastScrollTable = Srendarr.recentPlayerBuffs
                        UpdateProminentScrollList(1, Srendarr.recentPlayerBuffs)
                    end,
                    inLineAuraButton1 = true,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = 'PD',
                    tooltip = L.Filter_ProminentTypePD,
                    func = function (btn)
                        lastScrollTable = Srendarr.recentPlayerDebuffs
                        UpdateProminentScrollList(2, Srendarr.recentPlayerDebuffs)
                    end,
                    inLineAuraButton = true,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = 'TB',
                    tooltip = L.Filter_ProminentTypeTB,
                    func = function (btn)
                        lastScrollTable = Srendarr.recentTargetBuffs
                        UpdateProminentScrollList(3, Srendarr.recentTargetBuffs)
                    end,
                    inLineAuraButton = true,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = 'TD',
                    tooltip = L.Filter_ProminentTypeTD,
                    func = function (btn)
                        lastScrollTable = Srendarr.recentTargetDebuffs
                        UpdateProminentScrollList(4, Srendarr.recentTargetDebuffs)
                    end,
                    inLineAuraButton = true,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = 'AOE',
                    tooltip = L.Filter_ProminentTypeAOE,
                    func = function (btn)
                        lastScrollTable = Srendarr.recentGroundAOE
                        UpdateProminentScrollList(5, Srendarr.recentGroundAOE)
                    end,
                    inLineAuraButton = true,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = L.Filter_ProminentResetRecent,
                    tooltip = L.Filter_ProminentResetRecentTip,
                    func = function (btn)
                        Srendarr.recentPlayerBuffs = {}
                        Srendarr.recentPlayerDebuffs = {}
                        Srendarr.recentTargetBuffs = {}
                        Srendarr.recentTargetDebuffs = {}
                        Srendarr.recentGroundAOE = {}
                        ResetProminentVariables(true)
                    end,
                    isProminentResetRecent = true,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'dropdown',
                    name = L.Filter_ProminentModify,
                    tooltip = L.Filter_ProminentModifyTip,
                    choices = {},
                    getFunc = function () return 0 end,
                    setFunc = function (v) end,
                    isFakeDropdownLabel = true,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = 'PB',
                    tooltip = L.Filter_ProminentTypePB,
                    func = function (btn)
                        lastScrollTable = 1
                        UpdateProminentScrollList(6, 1)
                    end,
                    inLineAuraButton1 = true,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = 'PD',
                    tooltip = L.Filter_ProminentTypePD,
                    func = function (btn)
                        lastScrollTable = 2
                        UpdateProminentScrollList(7, 2)
                    end,
                    inLineAuraButton = true,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = 'TB',
                    tooltip = L.Filter_ProminentTypeTB,
                    func = function (btn)
                        lastScrollTable = 3
                        UpdateProminentScrollList(8, 3)
                    end,
                    inLineAuraButton = true,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = 'TD',
                    tooltip = L.Filter_ProminentTypeTD,
                    func = function (btn)
                        lastScrollTable = 4
                        UpdateProminentScrollList(9, 4)
                    end,
                    inLineAuraButton = true,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = 'AOE',
                    tooltip = L.Filter_ProminentTypeAOE,
                    func = function (btn)
                        lastScrollTable = 5
                        UpdateProminentScrollList(10, 5)
                    end,
                    inLineAuraButton = true,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = L.Filter_ProminentResetAll,
                    tooltip = L.Filter_ProminentResetAllTip,
                    func = function (btn)
                        if (searchInProgress) then return end
                        ResetProminentVariables(true)
                    end,
                    isResetPanelButton = true,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'editbox',
                    name = L.Filter_ProminentEdit,
                    tooltip = L.Filter_ProminentEditTip1 .. '\n\n' .. L.Filter_ProminentEditTip2,
                    getFunc = function ()
                        return editName
                    end,
                    setFunc = function (v)
                        if (v ~= '') then
                            editName = v                                -- strip out any control characters player may have entered
                            if editName == STR_PROMBYID then return end -- make sure we don't mess with internal table
                            if (tonumber(editName)) then                -- number entered, assume is an abilityID
                                editName = tonumber(editName)
                                isNumber = true
                            else
                                isNumber = false
                            end
                            if editName ~= updateAuraCheck then
                                updateAuraSet = false
                                updateAuraCheck = ''
                            end
                            removeAuraSet = false
                        end
                    end,
                    isProminentSearchRef = true,
                    isMultiline = false,
                    disabled = function () return (not isExpertMode) end,
                },
                {
                    type = 'dropdown',
                    name = L.Group_ProminentType,
                    tooltip = L.Group_ProminentTypeTip,
                    choices = dropType,
                    getFunc = function ()
                        pType = (pType ~= 0) and pType or L.DropAuraClassBuff
                        return pType
                    end,
                    setFunc = function (v)
                        pType = v
                        removeAuraSet = false
                        CM:FireCallbacks('LAM-RefreshPanel', controlPanel)
                    end,
                    disabled = function () return (updateAuraSet) or (isAuraUpdate) or (searchInProgress) end,
                },
                {
                    type = 'dropdown',
                    name = L.Group_ProminentTarget,
                    tooltip = L.Group_ProminentTargetTip,
                    choices = dropTarget,
                    getFunc = function ()
                        pTarget = (pTarget ~= '') and pTarget or L.DropAuraTargetPlayer
                        return pTarget
                    end,
                    setFunc = function (v)
                        pTarget = v
                        if v == L.DropAuraTargetAOE then isAuraUpdate = true else isAuraUpdate = false end
                        removeAuraSet = false
                        CM:FireCallbacks('LAM-RefreshPanel', controlPanel)
                    end,
                    disabled = function () return (updateAuraSet) or (isAuraUpdate) or (searchInProgress) end,
                },
                {
                    type = 'checkbox',
                    name = L.Filter_ProminentOnlyPlayer,
                    tooltip = L.Filter_ProminentOnlyPlayerTip,
                    getFunc = function ()
                        return pOnly
                    end,
                    setFunc = function (v)
                        pOnly = v
                        removeAuraSet = false
                        CM:FireCallbacks('LAM-RefreshPanel', controlPanel)
                    end,
                    disabled = function () return (isAOEUpdate) or (searchInProgress) end,
                },
                {
                    type = 'dropdown',
                    name = L.General_ControlProminentFrame,
                    tooltip = L.General_ControlProminentFrameTip,
                    choices = dropGroup,
                    getFunc = function ()
                        return (pFrame ~= 0) and dropGroupRev[pFrame] or L.DropGroup_None
                    end,
                    setFunc = function (v)
                        pFrame = dropGroupRef[v]
                        removeAuraSet = false
                        CM:FireCallbacks('LAM-RefreshPanel', controlPanel)
                    end,
                    scrollable = 7,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = L.Filter_ProminentAdd,
                    func = function (btn)
                        if editName == STR_PROMBYID then return end -- make sure we don't mess with internal table
                        if (searchInProgress) then return end
                        if editName ~= '' and pTarget ~= '' and pType ~= 0 and pFrame ~= nil then
                            local pDB = Srendarr.db.prominentDB
                            local sTarget = dropTargetRef[pTarget]
                            local sType = (sTarget == 'groundaoe') and 3 or dropTypeRef[pType]
                            local sName = ''
                            removeAuraSet = false

                            -------------------------------------------------------------------------------------------- special cases (Phinix)
                            local OffBalance = Srendarr.OffBalance
                            local fAuraName = zo_strformat('<<t:1>>', GetAbilityName(OffBalance.nameID))
                            local fOBImmunityID = OffBalance.ID

                            if zo_strformat('<<t:1>>', editName) == fAuraName then -- Off Balance Immunity (Phinix)
                                isNumber = true
                                editName = fOBImmunityID
                            end
                            --------------------------------------------------------------------------------------------

                            if (updateAuraSet) then
                                if isNumber then
                                    sName = (editName == fOBImmunityID) and fAuraName or zo_strformat('<<t:1>>', GetAbilityName(editName))
                                    if (not pDB[STR_PROMBYID]) then pDB[STR_PROMBYID] = {} end                   -- ensure the by ID table is present
                                    if (not pDB[STR_PROMBYID][sTarget]) then pDB[STR_PROMBYID][sTarget] = {} end -- ensure the target table is present

                                    if pDB[sTarget] ~= nil and pDB[sTarget][sName] ~= nil and pDB[sTarget][sName][editName] ~= nil then
                                        pDB[sTarget][sName][editName] = nil -- remove ID from list added by name and use per-ID config for this ID
                                    end
                                    local tType = tostring(sType)
                                    local tCast = (pOnly) and '1' or '0'
                                    local tFrame = (pFrame < 10) and '0' .. tostring(pFrame) or tostring(pFrame)
                                    local tData = '1' .. tType .. tCast .. tFrame
                                    pDB[STR_PROMBYID][sTarget][editName] = tData
                                    CHAT_SYSTEM:AddMessage(string.format('%s: [%d] (%s) %s %s %s %s %s', L.Srendarr, editName, sName, L.Prominent_AuraAddSuccess, tostring(pFrame), L.Prominent_AuraAddAs, pTarget, pType))
                                    Srendarr:ConfigureOnCombatEvent()
                                    Srendarr:ConfigureAuraHandler() -- update handler ref
                                    Srendarr.OnEquipChange()
                                    zo_callLater(function () Srendarr.OnEquipChange() end, 2000 + GetLatency())
                                else
                                    sName = zo_strformat('<<t:1>>', editName)
                                    if (not pDB[sTarget]) then pDB[sTarget] = {} end               -- ensure the target table is present
                                    if (not pDB[sTarget][sName]) then pDB[sTarget][sName] = {} end -- ensure the aura name table is present

                                    for id, data in pairs(pDB[sTarget][sName]) do
                                        local hasID = (pDB[STR_PROMBYID] ~= nil and pDB[STR_PROMBYID][sTarget] ~= nil) and true or false
                                        if (hasID) and (pDB[STR_PROMBYID][sTarget][id] ~= nil) then
                                            pDB[STR_PROMBYID][sTarget][id] = nil -- remove ID-specific config when re/adding by name
                                        end
                                        local tType = tostring(sType)
                                        local tCast = (pOnly) and '1' or '0'
                                        local tFrame = (pFrame < 10) and '0' .. tostring(pFrame) or tostring(pFrame)
                                        local tData = '1' .. tType .. tCast .. tFrame
                                        pDB[sTarget][sName][id] = tData
                                    end
                                    CHAT_SYSTEM:AddMessage(string.format('%s: %s %s %s %s %s %s.', L.Srendarr, sName, L.Prominent_AuraAddSuccess, tostring(pFrame), L.Prominent_AuraAddAs, pTarget, pType))
                                    Srendarr:ConfigureAuraHandler() -- update handler ref
                                    Srendarr.OnEquipChange()
                                    zo_callLater(function () Srendarr.OnEquipChange() end, 2000 + GetLatency())
                                end
                                ResetProminentVariables(true)
                            else
                                if isNumber then
                                    local doesExist = (editName == fOBImmunityID) and true or DoesAbilityExist(editName)
                                    if (editName > 0 and editName < maxAbilityID and doesExist) then
                                        sName = (editName == fOBImmunityID) and fAuraName or zo_strformat('<<t:1>>', GetAbilityName(editName))
                                        if (not pDB[STR_PROMBYID]) then pDB[STR_PROMBYID] = {} end                   -- ensure the by ID table is present
                                        if (not pDB[STR_PROMBYID][sTarget]) then pDB[STR_PROMBYID][sTarget] = {} end -- ensure the target table is present

                                        if pDB[sTarget] ~= nil and pDB[sTarget][sName] ~= nil and pDB[sTarget][sName][editName] ~= nil then
                                            pDB[sTarget][sName][editName] = nil -- remove ID from list added by name and use per-ID config for this ID
                                        end
                                        local tType = tostring(sType)
                                        local tCast = (pOnly) and '1' or '0'
                                        local tFrame = (pFrame < 10) and '0' .. tostring(pFrame) or tostring(pFrame)
                                        local tData = '1' .. tType .. tCast .. tFrame
                                        pDB[STR_PROMBYID][sTarget][editName] = tData

                                        CHAT_SYSTEM:AddMessage(string.format('%s: [%d] (%s) %s %s %s %s %s', L.Srendarr, editName, sName, L.Prominent_AuraAddSuccess, tostring(pFrame), L.Prominent_AuraAddAs, pTarget, pType))
                                        Srendarr:ConfigureOnCombatEvent()
                                        Srendarr:ConfigureAuraHandler() -- update handler ref
                                        Srendarr.OnEquipChange()
                                        zo_callLater(function () Srendarr.OnEquipChange() end, 2000 + GetLatency())
                                    else
                                        CHAT_SYSTEM:AddMessage(string.format('%s: [%s] %s', L.Srendarr, editName, L.Prominent_AuraAddFailByID)) -- inform user of failed addition
                                    end
                                    ResetProminentVariables(true)
                                else
                                    searchInProgress = true
                                    if editName == zo_strformat('<<t:1>>', GetAbilityName(bData.ID)) then -- Bahsei's Mania
                                        local tempMatches = {}
                                        table.insert(tempMatches, bData.ID)
                                        Srendarr.AuraSearchResults(tempMatches, editName, sType, pOnly)
                                        CM:FireCallbacks('LAM-RefreshPanel', controlPanel)
                                    elseif editName == zo_strformat('<<t:1>>', GetAbilityName(pData.ID)) then -- Ring of the Pale Order
                                        local tempMatches = {}
                                        table.insert(tempMatches, pData.ID)
                                        Srendarr.AuraSearchResults(tempMatches, editName, sType, pOnly)
                                        CM:FireCallbacks('LAM-RefreshPanel', controlPanel)
                                    else
                                        CM:FireCallbacks('LAM-RefreshPanel', controlPanel)
                                        Srendarr:FindIDByName(zo_strformat('<<t:1>>', editName), 1, 1, nil, sType, pOnly) -- not updating so perform full aura search with input text (Phinix)
                                    end
                                end
                            end
                        end
                    end,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = L.Filter_ProminentRemove,
                    func = function (btn)
                        if (searchInProgress) then return end
                        if (not removeAuraSet) then
                            CHAT_SYSTEM:AddMessage(string.format('%s: %s', L.Srendarr, L.Prominent_AuraRemoveFail))
                        else
                            local pDB = Srendarr.db.prominentDB
                            local sTarget = dropTargetRef[pTarget]
                            if isNumber then
                                if not Srendarr_RecentAuraListFrameCurrentIDs:IsHidden() then
                                    local tIDname = zo_strformat('<<t:1>>', GetAbilityName(editName))
                                    if pDB[STR_PROMBYID] and pDB[STR_PROMBYID][sTarget] and pDB[STR_PROMBYID][sTarget][editName] then
                                        pDB[STR_PROMBYID][sTarget][editName] = nil
                                        CHAT_SYSTEM:AddMessage(string.format('%s: %s %s', L.Srendarr, tostring(editName), L.Prominent_AuraRemoveSuccess))
                                        Srendarr:ConfigureOnCombatEvent()
                                        Srendarr:ConfigureAuraHandler() -- update handler ref
                                        Srendarr.OnEquipChange()
                                        zo_callLater(function () Srendarr.OnEquipChange() end, 2000 + GetLatency())
                                    elseif pDB[sTarget] and pDB[sTarget][tIDname] and pDB[sTarget][tIDname][editName] then
                                        pDB[sTarget][tIDname][editName] = nil
                                        CHAT_SYSTEM:AddMessage(string.format('%s: %s %s', L.Srendarr, editName, L.Prominent_AuraRemoveSuccess))
                                        Srendarr:ConfigureAuraHandler() -- update handler ref
                                        Srendarr.OnEquipChange()
                                        zo_callLater(function () Srendarr.OnEquipChange() end, 2000 + GetLatency())
                                    else
                                        CHAT_SYSTEM:AddMessage(string.format('%s: %s', L.Srendarr, L.Prominent_AuraRemoveFail))
                                    end
                                else
                                    if (not pDB[STR_PROMBYID]) or (not pDB[STR_PROMBYID][sTarget]) then -- if removing and table ref to remove not present something went wrong
                                        CHAT_SYSTEM:AddMessage(string.format('%s: %s', L.Srendarr, L.Prominent_AuraRemoveFail))
                                    else
                                        pDB[STR_PROMBYID][sTarget][editName] = nil
                                        CHAT_SYSTEM:AddMessage(string.format('%s: %s %s', L.Srendarr, tostring(editName), L.Prominent_AuraRemoveSuccess))
                                        Srendarr:ConfigureAuraHandler() -- update handler ref
                                        Srendarr.OnEquipChange()
                                        zo_callLater(function () Srendarr.OnEquipChange() end, 2000 + GetLatency())
                                    end
                                end
                            else
                                local sName = zo_strformat('<<t:1>>', editName)
                                if (not pDB[sTarget]) or (not pDB[sTarget][sName]) then -- if updating and table ref to update not present something went wrong
                                    CHAT_SYSTEM:AddMessage(string.format('%s: %s', L.Srendarr, L.Prominent_AuraRemoveFail))
                                else
                                    pDB[sTarget][sName] = nil
                                    CHAT_SYSTEM:AddMessage(string.format('%s: %s %s', L.Srendarr, sName, L.Prominent_AuraRemoveSuccess))
                                    Srendarr:ConfigureAuraHandler() -- update handler ref
                                    Srendarr.OnEquipChange()
                                    zo_callLater(function () Srendarr.OnEquipChange() end, 2000 + GetLatency())
                                end
                            end
                            UpdateProminentScrollList(lastScrollList, lastScrollTable, true)
                        end
                    end,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = L.Filter_ProminentExpert,
                    tooltip = L.Filter_ProminentExpertTip,
                    func = function (btn)
                        isExpertMode = true
                    end,
                    isProminentExpertButton = true,
                    disabled = function () return (searchInProgress) end,
                },
                {
                    type = 'button',
                    name = L.Filter_ProminentRemoveAll,
                    tooltip = L.Filter_ProminentRemoveAllTip,
                    func = function (btn)
                        ZO_Dialogs_ShowPlatformDialog('SRENDARR_AURA_RESET', nil)
                    end,
                    isDeleteProminentButton = true,
                    disabled = function () return (not isExpertMode) end,
                },
            },
            reference = 'SrendarrAuraWhitelistSubmenu',
        },
        {
            type = 'texture',
            image = 'Srendarr/Icons/InvisibleBG.dds',
            imageWidth = 100,
            imageHeight = 46,
            tooltip = L.Filter_ProminentHeadTip,
            isSubMenuLabel = true,
        },
        -- -----------------------
        -- GROUP BUFFS
        -- -----------------------
        {
            type = 'submenu',
            name = L.Filter_GroupBuffHeader,
            controls =
            {
                [1] =
                {
                    type = 'editbox',
                    name = L.Filter_GroupBuffAdd,
                    tooltip = L.Filter_GroupBuffAddTip,
                    warning = L.Filter_ListAddWarn,
                    getFunc = function ()
                        return ''
                    end,
                    setFunc = function (v)
                        if (v ~= '') then
                            Srendarr:GroupWhitelistAdd(v)
                            Srendarr.OnEquipChange()
                        end

                        Srendarr:PopulateGroupBuffsDropdown()
                    end,
                    isMultiline = false,
                    isFirstSubControl = true,
                    disabled = function () return not Srendarr.db.filtersGroup.groupBuffsEnabled end,
                },
                [2] =
                {
                    type = 'dropdown',
                    name = L.Filter_GroupBuffList,
                    tooltip = L.Filter_GroupBuffListTip,
                    choices = dropGroupBuffs,
                    sort = 'name-down',
                    getFunc = function ()
                        groupBuffSelectedAura = nil
                        return dropGroupBuffs[1]
                    end,
                    setFunc = function (v)
                        groupBuffSelectedAura = (v ~= '' and v ~= L.GenericSetting_ClickToViewAuras) and v or nil
                    end,
                    isGroupBuffWidget = true,
                    scrollable = 7,
                    disabled = function () return not Srendarr.db.filtersGroup.groupBuffsEnabled end,
                },
                [3] =
                {
                    type = 'button',
                    name = L.Filter_RemoveSelected,
                    func = function (btn)
                        if (groupBuffSelectedAura) then
                            if (string.find(groupBuffSelectedAura, '%[%d+%]')) then                -- this is a 'by abilityID' aura
                                groupBuffSelectedAura = string.match(groupBuffSelectedAura, '%d+') -- correct user display to just abilityID
                            end

                            Srendarr:GroupAuraRemove(groupBuffSelectedAura)
                            Srendarr.OnEquipChange()
                        end

                        Srendarr:PopulateGroupBuffsDropdown()
                    end,
                    disabled = function () return not Srendarr.db.filtersGroup.groupBuffsEnabled end,
                },
                [4] =
                {
                    type = 'checkbox',
                    name = L.Filter_GroupBuffsByDuration,
                    tooltip = L.Filter_GroupBuffsByDurationTip,
                    getFunc = function ()
                        return Srendarr.db.filtersGroup.groupBuffDuration
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersGroup.groupBuffDuration = v
                        Srendarr.OnEquipChange()
                    end,
                    disabled = function () return not Srendarr.db.filtersGroup.groupBuffsEnabled end,
                },
                [5] =
                {
                    type = 'slider',
                    name = L.Filter_GroupBuffThreshold,
                    tooltip = L.Filter_GroupDurationThreshold,
                    min = 5,
                    max = 600,
                    step = 1,
                    getFunc = function ()
                        return Srendarr.db.filtersGroup.groupBuffThreshold
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersGroup.groupBuffThreshold = v
                        Srendarr.OnEquipChange()
                    end,
                    disabled = function () return not (Srendarr.db.filtersGroup.groupBuffDuration and Srendarr.db.filtersGroup.groupBuffsEnabled) end,
                },
                [6] =
                {
                    type = 'checkbox',
                    name = L.Filter_GroupBuffWhitelistOff,
                    tooltip = L.Filter_GroupBuffWhitelistOffTip,
                    getFunc = function ()
                        return Srendarr.db.filtersGroup.groupBuffBlacklist
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersGroup.groupBuffBlacklist = v
                        Srendarr.OnEquipChange()
                    end,
                    disabled = function () return not Srendarr.db.filtersGroup.groupBuffsEnabled end,
                },
                [7] =
                {
                    type = 'checkbox',
                    name = L.Filter_GroupBuffOnlyPlayer,
                    tooltip = L.Filter_GroupBuffOnlyPlayerTip,
                    getFunc = function ()
                        return Srendarr.db.filtersGroup.groupBuffOnlyPlayer
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersGroup.groupBuffOnlyPlayer = v
                        Srendarr.OnEquipChange()
                    end,
                    disabled = function () return not Srendarr.db.filtersGroup.groupBuffsEnabled end,
                },
                [8] =
                {
                    type = 'checkbox',
                    name = L.Filter_GroupBuffsEnabled,
                    tooltip = L.Filter_GroupBuffsEnabledTip,
                    getFunc = function ()
                        return Srendarr.db.filtersGroup.groupBuffsEnabled
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersGroup.groupBuffsEnabled = v
                        Srendarr.OnEquipChange()
                    end,
                },
            },
            reference = 'SrendarrGroupBuffSubmenu',
        },
        {
            type = 'texture',
            image = 'Srendarr/Icons/InvisibleBG.dds',
            imageWidth = 100,
            imageHeight = 40,
            tooltip = L.Filter_GroupBuffDesc,
            isSubMenuLabel = true,
        },
        -- -----------------------
        -- GROUP DEBUFFS
        -- -----------------------
        {
            type = 'submenu',
            name = L.Filter_GroupDebuffHeader,
            controls =
            {
                [1] =
                {
                    type = 'editbox',
                    name = L.Filter_GroupDebuffAdd,
                    tooltip = L.Filter_GroupDebuffAddTip,
                    warning = L.Filter_ListAddWarn,
                    getFunc = function ()
                        return ''
                    end,
                    setFunc = function (v)
                        if (v ~= '') then
                            Srendarr:GroupWhitelistAdd2(v)
                            Srendarr.OnEquipChange()
                        end

                        Srendarr:PopulateGroupDebuffsDropdown()
                    end,
                    isMultiline = false,
                    isFirstSubControl = true,
                    disabled = function () return not Srendarr.db.filtersGroup.groupDebuffsEnabled end,
                },
                [2] =
                {
                    type = 'dropdown',
                    name = L.Filter_GroupDebuffList,
                    tooltip = L.Filter_GroupDebuffListTip,
                    choices = dropGroupDebuffs,
                    sort = 'name-down',
                    getFunc = function ()
                        groupDebuffSelectedAura = nil
                        return dropGroupDebuffs[1]
                    end,
                    setFunc = function (v)
                        groupDebuffSelectedAura = (v ~= '' and v ~= L.GenericSetting_ClickToViewAuras) and v or nil
                    end,
                    isGroupDebuffWidget = true,
                    scrollable = 7,
                    disabled = function () return not Srendarr.db.filtersGroup.groupDebuffsEnabled end,
                },
                [3] =
                {
                    type = 'button',
                    name = L.Filter_RemoveSelected,
                    func = function (btn)
                        if (groupDebuffSelectedAura) then
                            if (string.find(groupDebuffSelectedAura, '%[%d+%]')) then                  -- this is a 'by abilityID' aura
                                groupDebuffSelectedAura = string.match(groupDebuffSelectedAura, '%d+') -- correct user display to just abilityID
                            end

                            Srendarr:GroupAuraRemove2(groupDebuffSelectedAura)
                            Srendarr.OnEquipChange()
                        end

                        Srendarr:PopulateGroupDebuffsDropdown()
                    end,
                    disabled = function () return not Srendarr.db.filtersGroup.groupDebuffsEnabled end,
                },
                [4] =
                {
                    type = 'checkbox',
                    name = L.Filter_GroupDebuffsByDuration,
                    tooltip = L.Filter_GroupDebuffsByDurationTip,
                    getFunc = function ()
                        return Srendarr.db.filtersGroup.groupDebuffDuration
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersGroup.groupDebuffDuration = v
                        Srendarr.OnEquipChange()
                    end,
                    disabled = function () return not Srendarr.db.filtersGroup.groupDebuffsEnabled end,
                },
                [5] =
                {
                    type = 'slider',
                    name = L.Filter_GroupDebuffThreshold,
                    tooltip = L.Filter_GroupDurationThreshold,
                    min = 5,
                    max = 600,
                    step = 1,
                    getFunc = function ()
                        return Srendarr.db.filtersGroup.groupDebuffThreshold
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersGroup.groupDebuffThreshold = v
                        Srendarr.OnEquipChange()
                    end,
                    disabled = function () return not (Srendarr.db.filtersGroup.groupDebuffDuration and Srendarr.db.filtersGroup.groupDebuffsEnabled) end,
                },
                [6] =
                {
                    type = 'checkbox',
                    name = L.Filter_GroupDebuffWhitelistOff,
                    tooltip = L.Filter_GroupDebuffWhitelistOffTip,
                    getFunc = function ()
                        return Srendarr.db.filtersGroup.groupDebuffBlacklist
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersGroup.groupDebuffBlacklist = v
                        Srendarr.OnEquipChange()
                    end,
                    disabled = function () return not Srendarr.db.filtersGroup.groupDebuffsEnabled end,
                },
                [7] =
                {
                    type = 'checkbox',
                    name = L.Filter_GroupDebuffsEnabled,
                    tooltip = L.Filter_GroupDebuffsEnabledTip,
                    getFunc = function ()
                        return Srendarr.db.filtersGroup.groupDebuffsEnabled
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersGroup.groupDebuffsEnabled = v
                        Srendarr.OnEquipChange()
                    end,
                },
            },
            reference = 'SrendarrGroupDebuffSubmenu',
        },
        {
            type = 'texture',
            image = 'Srendarr/Icons/InvisibleBG.dds',
            imageWidth = 100,
            imageHeight = 40,
            tooltip = L.Filter_GroupDebuffDesc,
            isSubMenuLabel = true,
        },
        -- -----------------------
        -- FILTERS FOR PLAYER
        -- -----------------------
        {
            type = 'submenu',
            name = L.Filter_PlayerHeader,
            controls =
            {
                [1] =
                {
                    type = 'checkbox',
                    name = L.Filter_ESOPlus,
                    tooltip = L.Filter_ESOPlusPlayerTip,
                    getFunc = function ()
                        return Srendarr.db.filtersPlayer.esoplus
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersPlayer.esoplus = v
                        Srendarr:PopulateFilteredAuras()
                        Srendarr.OnEquipChange()
                    end,
                    isFirstSubControl = true,
                },
                [2] =
                {
                    type = 'checkbox',
                    name = L.Filter_MundusBoon,
                    tooltip = L.Filter_MundusBoonPlayerTip,
                    getFunc = function ()
                        return Srendarr.db.filtersPlayer.mundusBoon
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersPlayer.mundusBoon = v
                        Srendarr:PopulateFilteredAuras()
                        Srendarr.OnEquipChange()
                    end,
                },
                [3] =
                {
                    type = 'checkbox',
                    name = L.Filter_Cyrodiil,
                    tooltip = L.Filter_CyrodiilPlayerTip,
                    getFunc = function ()
                        return Srendarr.db.filtersPlayer.cyrodiil
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersPlayer.cyrodiil = v
                        Srendarr:PopulateFilteredAuras()
                        Srendarr.OnEquipChange()
                    end,
                },
                [4] =
                {
                    type = 'checkbox',
                    name = L.Filter_Disguise,
                    tooltip = L.Filter_DisguisePlayerTip,
                    getFunc = function ()
                        return Srendarr.db.filtersPlayer.disguise
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersPlayer.disguise = v
                        Srendarr:PopulateFilteredAuras()
                        Srendarr.OnEquipChange()
                    end,
                },
                [5] =
                {
                    type = 'checkbox',
                    name = L.Filter_SoulSummons,
                    tooltip = L.Filter_SoulSummonsPlayerTip,
                    getFunc = function ()
                        return Srendarr.db.filtersPlayer.soulSummons
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersPlayer.soulSummons = v
                        Srendarr:PopulateFilteredAuras()
                        Srendarr.OnEquipChange()
                    end,
                },
                [6] =
                {
                    type = 'checkbox',
                    name = L.Filter_VampLycan,
                    tooltip = L.Filter_VampLycanPlayerTip,
                    getFunc = function ()
                        return Srendarr.db.filtersPlayer.vampLycan
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersPlayer.vampLycan = v
                        Srendarr:PopulateFilteredAuras()
                        Srendarr.OnEquipChange()
                    end,
                },
                [7] =
                {
                    type = 'checkbox',
                    name = L.Filter_VampLycanBite,
                    tooltip = L.Filter_VampLycanBitePlayerTip,
                    getFunc = function ()
                        return Srendarr.db.filtersPlayer.vampLycanBite
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersPlayer.vampLycanBite = v
                        Srendarr:PopulateFilteredAuras()
                        Srendarr.OnEquipChange()
                    end,
                },
            },
            reference = 'SrendarrPlayerFilterSubmenu',
        },
        {
            type = 'texture',
            image = 'Srendarr/Icons/InvisibleBG.dds',
            imageWidth = 100,
            imageHeight = 40,
            tooltip = L.FilterToggle_Desc,
            isSubMenuLabel = true,
        },
        -- -----------------------
        -- FILTERS FOR TARGET
        -- -----------------------
        {
            type = 'submenu',
            name = L.Filter_TargetHeader,
            controls =
            {
                [1] =
                {
                    type = 'checkbox',
                    name = L.Filter_OnlyPlayerDebuffs,
                    tooltip = L.Filter_OnlyPlayerDebuffsTip,
                    getFunc = function ()
                        return Srendarr.db.filtersTarget.onlyPlayerDebuffs
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersTarget.onlyPlayerDebuffs = v
                        Srendarr:PopulateFilteredAuras()
                    end,
                    isFirstSubControl = true,
                },
                [2] =
                {
                    type = 'checkbox',
                    name = L.Filter_OnlyTargetMajor,
                    tooltip = L.Filter_OnlyTargetMajorTip,
                    getFunc = function ()
                        return Srendarr.db.onlyTargetMajor
                    end,
                    setFunc = function (v)
                        Srendarr.db.onlyTargetMajor = v
                        Srendarr:PopulateFilteredAuras()
                    end,
                },
                [3] =
                {
                    type = 'checkbox',
                    name = L.Filter_ESOPlus,
                    tooltip = L.Filter_ESOPlusTargetTip,
                    getFunc = function ()
                        return Srendarr.db.filtersTarget.esoplus
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersTarget.esoplus = v
                        Srendarr:PopulateFilteredAuras()
                    end,
                },
                [4] =
                {
                    type = 'checkbox',
                    name = L.Filter_MundusBoon,
                    tooltip = L.Filter_MundusBoonTargetTip,
                    getFunc = function ()
                        return Srendarr.db.filtersTarget.mundusBoon
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersTarget.mundusBoon = v
                        Srendarr:PopulateFilteredAuras()
                    end,
                },
                [5] =
                {
                    type = 'checkbox',
                    name = L.Filter_Cyrodiil,
                    tooltip = L.Filter_CyrodiilTargetTip,
                    getFunc = function ()
                        return Srendarr.db.filtersTarget.cyrodiil
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersTarget.cyrodiil = v
                        Srendarr:PopulateFilteredAuras()
                    end,
                },
                [6] =
                {
                    type = 'checkbox',
                    name = L.Filter_Disguise,
                    tooltip = L.Filter_DisguiseTargetTip,
                    getFunc = function ()
                        return Srendarr.db.filtersTarget.disguise
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersTarget.disguise = v
                        Srendarr:PopulateFilteredAuras()
                    end,
                },
                [7] =
                {
                    type = 'checkbox',
                    name = L.Filter_MajorEffects,
                    tooltip = L.Filter_MajorEffectsTargetTip,
                    getFunc = function ()
                        return Srendarr.db.filtersTarget.majorEffects
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersTarget.majorEffects = v
                        Srendarr:PopulateFilteredAuras()
                    end,
                    disabled = function () return (Srendarr.db.onlyTargetMajor) end,
                },
                [8] =
                {
                    type = 'checkbox',
                    name = L.Filter_MinorEffects,
                    tooltip = L.Filter_MinorEffectsTargetTip,
                    getFunc = function ()
                        return Srendarr.db.filtersTarget.minorEffects
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersTarget.minorEffects = v
                        Srendarr:PopulateFilteredAuras()
                    end,
                },
                [9] =
                {
                    type = 'checkbox',
                    name = L.Filter_SoulSummons,
                    tooltip = L.Filter_SoulSummonsTargetTip,
                    getFunc = function ()
                        return Srendarr.db.filtersTarget.soulSummons
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersTarget.soulSummons = v
                        Srendarr:PopulateFilteredAuras()
                    end,
                },
                [10] =
                {
                    type = 'checkbox',
                    name = L.Filter_VampLycan,
                    tooltip = L.Filter_VampLycanTargetTip,
                    getFunc = function ()
                        return Srendarr.db.filtersTarget.vampLycan
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersTarget.vampLycan = v
                        Srendarr:PopulateFilteredAuras()
                    end,
                },
                [11] =
                {
                    type = 'checkbox',
                    name = L.Filter_VampLycanBite,
                    tooltip = L.Filter_VampLycanBiteTargetTip,
                    getFunc = function ()
                        return Srendarr.db.filtersTarget.vampLycanBite
                    end,
                    setFunc = function (v)
                        Srendarr.db.filtersTarget.vampLycanBite = v
                        Srendarr:PopulateFilteredAuras()
                    end,
                },
            },
            reference = 'SrendarrTargetFilterSubmenu',
        },
        {
            type = 'texture',
            image = 'Srendarr/Icons/InvisibleBG.dds',
            imageWidth = 100,
            imageHeight = 40,
            tooltip = L.FilterToggle_Desc,
            isSubMenuLabel = true,
        },
    },
    -- -----------------------
    -- CAST BAR SETTINGS
    -- -----------------------
    [3] =
    {
        {
            type = 'checkbox',
            name = L.CastBar_Enable,
            tooltip = L.CastBar_EnableTip,
            getFunc = function ()
                return Srendarr.db.castBar.enabled
            end,
            setFunc = function (v)
                Srendarr.db.castBar.enabled = v
                Srendarr:ConfigureCastBar()
            end,
        },
        {
            type = 'slider',
            name = L.DisplayFrame_Alpha,
            tooltip = L.CastBar_AlphaTip,
            min = 0,
            max = 100,
            step = 1,
            getFunc = function ()
                return Srendarr.db.castBar.base.alpha * 100
            end,
            setFunc = function (v)
                Srendarr.db.castBar.base.alpha = v / 100
                if not IsUnitInCombat('player') and Srendarr.uiLocked then
                    Srendarr.Cast:SetAlpha(v / 100)
                end
            end,
        },
        {
            type = 'slider',
            name = L.DisplayFrame_CAlpha,
            tooltip = L.CastBar_CAlphaTip,
            min = 0,
            max = 100,
            step = 1,
            getFunc = function ()
                return Srendarr.db.castBar.base.calpha * 100
            end,
            setFunc = function (v)
                Srendarr.db.castBar.base.calpha = v / 100
                if IsUnitInCombat('player') and Srendarr.uiLocked then
                    Srendarr.Cast:SetAlpha(v / 100)
                end
            end,
        },
        {
            type = 'slider',
            name = L.CastBar_Scale,
            tooltip = L.CastBar_ScaleTip,
            min = 50,
            max = 250,
            step = 5,
            getFunc = function ()
                return Srendarr.db.castBar.base.scale * 100
            end,
            setFunc = function (v)
                Srendarr.db.castBar.base.scale = v / 100
                Srendarr.Cast:SetScale(v / 100)
            end,
        },
        -- -----------------------
        -- CASTED ABILITY TEXT SETTINGS
        -- -----------------------
        {
            type = 'header',
            name = L.CastBar_NameHeader,
        },
        {
            type = 'checkbox',
            name = L.CastBar_NameShow,
            getFunc = function ()
                return Srendarr.db.castBar.nameShow
            end,
            setFunc = function (v)
                Srendarr.db.castBar.nameShow = v
                Srendarr:ConfigureCastBar()
            end,
        },
        {
            type = 'dropdown',
            name = L.GenericSetting_NameFont,
            choices = LMP:List('font'),
            getFunc = function ()
                return Srendarr.db.castBar.nameFont
            end,
            setFunc = function (v)
                Srendarr.db.castBar.nameFont = v
                Srendarr:ConfigureCastBar()
            end,
            scrollable = 7,
        },
        {
            type = 'dropdown',
            name = L.GenericSetting_NameStyle,
            choices = dropFontStyle,
            getFunc = function ()
                return Srendarr.db.castBar.nameStyle
            end,
            setFunc = function (v)
                Srendarr.db.castBar.nameStyle = v
                Srendarr:ConfigureCastBar()
            end,
            scrollable = 7,
        },
        {
            type                    = 'colorpicker',
            getFunc                 = function ()
                return unpack(Srendarr.db.castBar.nameColor)
            end,
            setFunc                 = function (r, g, b, a)
                Srendarr.db.castBar.nameColor[1] = r
                Srendarr.db.castBar.nameColor[2] = g
                Srendarr.db.castBar.nameColor[3] = b
                Srendarr.db.castBar.nameColor[4] = a
                Srendarr:ConfigureCastBar()
            end,
            widgetRightAlign        = true,
            widgetPositionAndResize = -15,
        },
        {
            type = 'slider',
            name = L.GenericSetting_NameSize,
            min = 8,
            max = 32,
            getFunc = function ()
                return Srendarr.db.castBar.nameSize
            end,
            setFunc = function (v)
                Srendarr.db.castBar.nameSize = v
                Srendarr:ConfigureCastBar()
            end,
        },
        -- -----------------------
        -- CAST TIMER TEXT SETTINGS
        -- -----------------------
        {
            type = 'header',
            name = L.CastBar_TimerHeader,
        },
        {
            type = 'checkbox',
            name = L.CastBar_TimerShow,
            getFunc = function ()
                return Srendarr.db.castBar.timerShow
            end,
            setFunc = function (v)
                Srendarr.db.castBar.timerShow = v
                Srendarr:ConfigureCastBar()
            end,
        },
        {
            type = 'dropdown',
            name = L.GenericSetting_TimerFont,
            choices = LMP:List('font'),
            getFunc = function ()
                return Srendarr.db.castBar.timerFont
            end,
            setFunc = function (v)
                Srendarr.db.castBar.timerFont = v
                Srendarr:ConfigureCastBar()
            end,
            scrollable = 7,
        },
        {
            type = 'dropdown',
            name = L.GenericSetting_TimerStyle,
            choices = dropFontStyle,
            getFunc = function ()
                return Srendarr.db.castBar.timerStyle
            end,
            setFunc = function (v)
                Srendarr.db.castBar.timerStyle = v
                Srendarr:ConfigureCastBar()
            end,
            scrollable = 7,
        },
        {
            type                    = 'colorpicker',
            getFunc                 = function ()
                return unpack(Srendarr.db.castBar.timerColor)
            end,
            setFunc                 = function (r, g, b, a)
                Srendarr.db.castBar.timerColor[1] = r
                Srendarr.db.castBar.timerColor[2] = g
                Srendarr.db.castBar.timerColor[3] = b
                Srendarr.db.castBar.timerColor[4] = a
                Srendarr:ConfigureCastBar()
            end,
            widgetRightAlign        = true,
            widgetPositionAndResize = -15,
        },
        {
            type = 'slider',
            name = L.GenericSetting_TimerSize,
            min = 8,
            max = 32,
            getFunc = function ()
                return Srendarr.db.castBar.timerSize
            end,
            setFunc = function (v)
                Srendarr.db.castBar.timerSize = v
                Srendarr:ConfigureCastBar()
            end,
        },
        -- -----------------------
        -- STATUSBAR SETTINGS
        -- -----------------------
        {
            type = 'header',
            name = L.CastBar_BarHeader,
        },
        {
            type = 'checkbox',
            name = L.CastBar_BarReverse,
            tooltip = L.CastBar_BarReverseTip,
            getFunc = function ()
                return Srendarr.db.castBar.barReverse
            end,
            setFunc = function (v)
                Srendarr.db.castBar.barReverse = v
                Srendarr:ConfigureCastBar()
            end,
        },
        {
            type = 'checkbox',
            name = L.CastBar_BarGloss,
            tooltip = L.CastBar_BarGlossTip,
            getFunc = function ()
                return Srendarr.db.castBar.barGloss
            end,
            setFunc = function (v)
                Srendarr.db.castBar.barGloss = v
                Srendarr:ConfigureCastBar()
            end,
        },
        {
            type = 'slider',
            name = L.GenericSetting_BarWidth,
            tooltip = L.GenericSetting_BarWidthTip,
            min = 200,
            max = 400,
            step = 5,
            getFunc = function ()
                return Srendarr.db.castBar.barWidth
            end,
            setFunc = function (v)
                Srendarr.db.castBar.barWidth = v
                Srendarr:ConfigureCastBar()
            end,
        },
        {
            type             = 'colorpicker',
            name             = L.CastBar_BarColor,
            tooltip          = L.CastBar_BarColorTip,
            getFunc          = function ()
                local colors = Srendarr.db.castBar.barColor
                return colors.r2, colors.g2, colors.b2
            end,
            setFunc          = function (r, g, b)
                Srendarr.db.castBar.barColor.r2 = r
                Srendarr.db.castBar.barColor.g2 = g
                Srendarr.db.castBar.barColor.b2 = b
                Srendarr:ConfigureCastBar()
            end,
            widgetRightAlign = true,
        },
        {
            type                    = 'colorpicker',
            tooltip                 = L.CastBar_BarColorTip,
            getFunc                 = function ()
                local colors = Srendarr.db.castBar.barColor
                return colors.r1, colors.g1, colors.b1
            end,
            setFunc                 = function (r, g, b)
                Srendarr.db.castBar.barColor.r1 = r
                Srendarr.db.castBar.barColor.g1 = g
                Srendarr.db.castBar.barColor.b1 = b
                Srendarr:ConfigureCastBar()
            end,
            widgetRightAlign        = true,
            widgetPositionAndResize = 127,
        },
    },
    -- -----------------------
    -- PROFILE SETTINGS
    -- -----------------------
    [5] =
    {
        [1] =
        {
            type = 'description',
            text = L.Profile_Desc
        },
        [2] =
        {
            type = 'checkbox',
            name = L.Profile_UseGlobal,
            warning = L.Profile_UseGlobalWarn,
            getFunc = function ()
                return SrendarrDB.Default[GetDisplayName()]['$AccountWide'].useAccountWide
            end,
            setFunc = function (v)
                SrendarrDB.Default[GetDisplayName()]['$AccountWide'].useAccountWide = v
                ReloadUI()
            end,
            disabled = function ()
                return not profileGuard
            end,
        },
        [3] =
        {
            type = 'dropdown',
            name = L.Profile_Copy,
            tooltip = L.Profile_CopyTip,
            choices = profileCopyList,
            getFunc = function ()
                if (#profileCopyList >= 1) then -- there are entries, set first as default
                    profileCopyToCopy = profileCopyList[1]
                    return profileCopyList[1]
                end
            end,
            setFunc = function (v)
                profileCopyToCopy = v
            end,
            disabled = function ()
                return not profileGuard
            end,
            isProfileCopyDrop = true,
            scrollable = 7,
        },
        [4] =
        {
            type = 'button',
            name = L.Profile_CopyButton1,
            tooltip = L.Profile_CopyButton1Tip,
            warning = L.Profile_CopyButtonWarn,
            func = function (btn)
                CopyProfile()
            end,
            disabled = function ()
                return not profileGuard
            end,
        },
        [5] =
        {
            type = 'button',
            name = L.Profile_CopyButton2,
            tooltip = L.Profile_CopyButton2Tip,
            warning = L.Profile_CopyButtonWarn,
            func = function (btn)
                CopyProfile(true)
            end,
            disabled = function ()
                return not profileGuard
            end,
        },
        [6] =
        {
            type = 'dropdown',
            name = L.Profile_Delete,
            tooltip = L.Profile_DeleteTip,
            choices = profileDeleteList,
            getFunc = function ()
                if (#profileDeleteList >= 1) then
                    if (not profileDeleteToDelete) then -- nothing selected yet, return first
                        profileDeleteToDelete = profileDeleteList[1]
                        return profileDeleteList[1]
                    else
                        return profileDeleteToDelete
                    end
                end
            end,
            setFunc = function (v)
                profileDeleteToDelete = v
            end,
            disabled = function ()
                return not profileGuard
            end,
            isProfileDeleteDrop = true,
            scrollable = 7,
        },
        [7] =
        {
            type = 'button',
            name = L.Profile_DeleteButton,
            func = function (btn)
                DeleteProfile()
            end,
            disabled = function ()
                return not profileGuard
            end,
        },
        [8] =
        {
            type = 'description'
        },
        [9] =
        {
            type = 'header'
        },
        [10] =
        {
            type = 'checkbox',
            name = L.Profile_Guard,
            getFunc = function ()
                return profileGuard
            end,
            setFunc = function (v)
                profileGuard = v
            end,
        },
    },
    -- -----------------------
    -- DISPLAY FRAME SETTINGS
    -- -----------------------
    [10] =
    {
        {
            type = 'slider',
            name = L.DisplayFrame_Alpha,
            tooltip = L.DisplayFrame_AlphaTip,
            min = 0,
            max = 100,
            step = 1,
            getFunc = function ()
                return displayDB[currentDisplayFrame].base.alpha * 100
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].base.alpha = v / 100
                if currentDisplayFrame < GROUP_START_FRAME then
                    if not IsUnitInCombat('player') and Srendarr.uiLocked then
                        Srendarr.displayFrames[currentDisplayFrame]:SetAlpha(v / 100)
                    end
                    Srendarr.displayFrames[currentDisplayFrame].displayAlpha = v / 100
                    Srendarr.displayFrames[currentDisplayFrame]:Configure()
                    Srendarr.displayFrames[currentDisplayFrame]:UpdateDisplay()
                else
                    for i = GROUP_START_FRAME, GROUP_DEND_FRAME do
                        if not IsUnitInCombat('player') and Srendarr.uiLocked then
                            Srendarr.displayFrames[i]:SetAlpha(v / 100)
                        end
                        Srendarr.displayFrames[i].displayAlpha = v / 100
                        Srendarr.displayFrames[i]:Configure()
                        Srendarr.displayFrames[i]:UpdateDisplay()
                    end
                end
            end,
        },
        {
            type = 'slider',
            name = L.DisplayFrame_CAlpha,
            tooltip = L.DisplayFrame_CAlphaTip,
            min = 0,
            max = 100,
            step = 1,
            getFunc = function ()
                return displayDB[currentDisplayFrame].base.calpha * 100
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].base.calpha = v / 100
                if currentDisplayFrame < GROUP_START_FRAME then
                    if IsUnitInCombat('player') and Srendarr.uiLocked then
                        Srendarr.displayFrames[currentDisplayFrame]:SetAlpha(v / 100)
                    end
                    Srendarr.displayFrames[currentDisplayFrame].combatAlpha = v / 100
                    Srendarr.displayFrames[currentDisplayFrame]:Configure()
                    Srendarr.displayFrames[currentDisplayFrame]:UpdateDisplay()
                else
                    for i = GROUP_START_FRAME, GROUP_DEND_FRAME do
                        if IsUnitInCombat('player') and Srendarr.uiLocked then
                            Srendarr.displayFrames[i]:SetAlpha(v / 100)
                        end
                        Srendarr.displayFrames[i].combatAlpha = v / 100
                        Srendarr.displayFrames[i]:Configure()
                        Srendarr.displayFrames[i]:UpdateDisplay()
                    end
                end
            end,
        },
        {
            type = 'slider',
            name = L.DisplayFrame_Scale,
            tooltip = L.DisplayFrame_ScaleTip,
            min = 10,
            max = 250,
            step = 5,
            getFunc = function ()
                return displayDB[currentDisplayFrame].base.scale * 100
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].base.scale = v / 100
                if currentDisplayFrame < GROUP_START_FRAME then
                    Srendarr.displayFrames[currentDisplayFrame]:SetScale(v / 100)
                    Srendarr.displayFrames[currentDisplayFrame]:Configure()
                    Srendarr.displayFrames[currentDisplayFrame]:UpdateDisplay()
                else
                    for i = GROUP_START_FRAME, GROUP_DEND_FRAME do
                        Srendarr.displayFrames[i]:SetScale(v / 100)
                        Srendarr.displayFrames[i]:Configure()
                        Srendarr.displayFrames[i]:UpdateDisplay()
                    end
                end
            end,
        },
        {
            type = 'slider',
            name = L.General_AuraFadeout,
            tooltip = L.General_AuraFadeoutTip,
            min = 0,
            max = 25,
            step = 1,
            getFunc = function ()
                return displayDB[currentDisplayFrame].auraFadeTime
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].auraFadeTime = v
                Srendarr:ConfigureAuraFadeTime(currentDisplayFrame)
            end,
        },
        -- -----------------------
        -- AURA DISPLAY SETTINGS
        -- -----------------------
        -- 	{
        -- 		type = 'header',
        -- 		name = L.DisplayFrame_AuraHeader,
        -- 	},
        { -- style							FULL, ICON, MINI
            type = 'dropdown',
            name = L.DisplayFrame_Style,
            tooltip = L.DisplayFrame_StyleTip,
            choices = dropStyle,
            getFunc = function ()
                return dropStyle[displayDB[currentDisplayFrame].style]
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].style = dropStyleRef[v]
                OnStyleChange(dropStyleRef[v])   -- update several options dependent on current style
                ConfigurePanelDisplayFrame(true) -- changing this changes a lot of the following options
                local auraLookup = Srendarr.auraLookup
                for unit, data in pairs(auraLookup) do
                    for aura, ability in pairs(auraLookup[unit]) do
                        ability:SetExpired()
                        ability:Release()
                    end
                end
                for frame = 1, (GROUP_START_FRAME - 1) do Srendarr.displayFrames[frame]:Configure() end
                Srendarr.OnEquipChange()
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
            scrollable = 7,
        },
        { -- hideFullBar						FULL
            type = 'checkbox',
            name = L.DisplayFrame_HideFullBar,
            tooltip = L.DisplayFrame_HideFullBarTip,
            getFunc = function ()
                return displayDB[currentDisplayFrame].hideFullBar
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].hideFullBar = v
                for frame = 1, Srendarr.NUM_DISPLAY_FRAMES do Srendarr.displayFrames[frame]:Configure() end
                Srendarr.OnEquipChange()
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = true, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- groupX							GROUP ONLY
            type = 'slider',
            name = L.DisplayFrame_GRX,
            tooltip = L.DisplayFrame_GRXTip,
            min = -128,
            max = 128,
            getFunc = function ()
                return displayDB[currentDisplayFrame].base.x
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].base.x = v
                Srendarr.OnEquipChange()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = true, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = true, [AURA_STYLE_GROUPB] = false, [AURA_STYLE_GROUPD] = false },
        },
        { -- groupY							GROUP ONLY
            type = 'slider',
            name = L.DisplayFrame_GRY,
            tooltip = L.DisplayFrame_GRYTip,
            min = -128,
            max = 128,
            getFunc = function ()
                return displayDB[currentDisplayFrame].base.y
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].base.y = v
                Srendarr.OnEquipChange()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = true, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = true, [AURA_STYLE_GROUPB] = false, [AURA_STYLE_GROUPD] = false },
        },
        { -- auraCooldown						FULL, ICON, GROUP
            type = 'checkbox',
            name = L.DisplayFrame_AuraCooldown,
            tooltip = L.DisplayFrame_AuraCooldownTip,
            getFunc = function ()
                return displayDB[currentDisplayFrame].auraCooldown
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].auraCooldown = v
                for frame = 1, Srendarr.NUM_DISPLAY_FRAMES do Srendarr.displayFrames[frame]:Configure() end
                Srendarr.OnEquipChange()
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = true, [AURA_STYLE_GROUPB] = false, [AURA_STYLE_GROUPD] = false },
        },
        { -- auraBackground						FULL, ICON, GROUP
            type = 'checkbox',
            name = L.DisplayFrame_AuraBackground,
            tooltip = L.DisplayFrame_AuraBackgroundTip,
            getFunc = function ()
                return displayDB[currentDisplayFrame].auraBackground
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].auraBackground = v
                for frame = 1, Srendarr.NUM_DISPLAY_FRAMES do Srendarr.displayFrames[frame]:Configure() end
                Srendarr.OnEquipChange()
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            disabled = function () return displayDB[currentDisplayFrame].auraCooldown end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = true, [AURA_STYLE_GROUPB] = false, [AURA_STYLE_GROUPD] = false },
        },
        { -- auraBorder						FULL, ICON, GROUP
            type = 'checkbox',
            name = L.DisplayFrame_AuraBorder,
            tooltip = L.DisplayFrame_AuraBorderTip,
            getFunc = function ()
                return displayDB[currentDisplayFrame].auraBorder
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].auraBorder = v
                for frame = 1, Srendarr.NUM_DISPLAY_FRAMES do Srendarr.displayFrames[frame]:Configure() end
                Srendarr.OnEquipChange()
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            disabled = function () return displayDB[currentDisplayFrame].auraCooldown or displayDB[currentDisplayFrame].auraBackground end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = true, [AURA_STYLE_GROUPB] = false, [AURA_STYLE_GROUPD] = false },
        },
        { -- cooldownDebuffColor[TIMED]		FULL, ICON
            type             = 'colorpicker',
            name             = L.DisplayFrame_CooldownTimed,
            tooltip          = L.DisplayFrame_CooldownTimedTip,
            getFunc          = function ()
                local colors = displayDB[currentDisplayFrame].cooldownColors[DEBUFF_TYPE_TIMED]
                return colors.r1, colors.g1, colors.b1
            end,
            setFunc          = function (r, g, b)
                displayDB[currentDisplayFrame].cooldownColors[DEBUFF_TYPE_TIMED].r1 = r
                displayDB[currentDisplayFrame].cooldownColors[DEBUFF_TYPE_TIMED].g1 = g
                displayDB[currentDisplayFrame].cooldownColors[DEBUFF_TYPE_TIMED].b1 = b
                Srendarr.OnEquipChange()
            end,
            widgetRightAlign = true,
            hideOnStyle      = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = true, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- cooldownBuffColor[TIMED]			FULL, ICON
            type                    = 'colorpicker',
            tooltip                 = L.DisplayFrame_CooldownTimedTip,
            getFunc                 = function ()
                local colors = displayDB[currentDisplayFrame].cooldownColors[AURA_TYPE_TIMED]
                return colors.r1, colors.g1, colors.b1
            end,
            setFunc                 = function (r, g, b)
                displayDB[currentDisplayFrame].cooldownColors[AURA_TYPE_TIMED].r1 = r
                displayDB[currentDisplayFrame].cooldownColors[AURA_TYPE_TIMED].g1 = g
                displayDB[currentDisplayFrame].cooldownColors[AURA_TYPE_TIMED].b1 = b
                Srendarr.OnEquipChange()
            end,
            widgetRightAlign        = true,
            widgetPositionAndResize = 127,
            hideOnStyle             = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = true, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- cooldownBuffColor[TIMED]			FULL, ICON, GROUP
            type = 'colorpicker',
            name = L.DisplayFrame_CooldownTimedB,
            tooltip = L.DisplayFrame_CooldownTimedBTip,
            getFunc = function ()
                local colors = displayDB[currentDisplayFrame].cooldownColors[AURA_TYPE_TIMED]
                return colors.r1, colors.g1, colors.b1
            end,
            setFunc = function (r, g, b)
                displayDB[currentDisplayFrame].cooldownColors[AURA_TYPE_TIMED].r1 = r
                displayDB[currentDisplayFrame].cooldownColors[AURA_TYPE_TIMED].g1 = g
                displayDB[currentDisplayFrame].cooldownColors[AURA_TYPE_TIMED].b1 = b
                Srendarr.OnEquipChange()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = true, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = true, [AURA_STYLE_GROUPB] = false, [AURA_STYLE_GROUPD] = true },
        },
        { -- cooldownDebuffColor[TIMED]		FULL, ICON, GROUP
            type = 'colorpicker',
            name = L.DisplayFrame_CooldownTimedD,
            tooltip = L.DisplayFrame_CooldownTimedDTip,
            getFunc = function ()
                local colors = displayDB[currentDisplayFrame].cooldownColors[AURA_TYPE_TIMED]
                return colors.r1, colors.g1, colors.b1
            end,
            setFunc = function (r, g, b)
                displayDB[currentDisplayFrame].cooldownColors[AURA_TYPE_TIMED].r1 = r
                displayDB[currentDisplayFrame].cooldownColors[AURA_TYPE_TIMED].g1 = g
                displayDB[currentDisplayFrame].cooldownColors[AURA_TYPE_TIMED].b1 = b
                Srendarr.OnEquipChange()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = true, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = true, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = false },
        },
        { -- auraGrowth						FULL, MINI
            type = 'dropdown',
            name = L.DisplayFrame_Growth,
            tooltip = L.DisplayFrame_GrowthTip,
            choices = dropGrowthFullMini,
            getFunc = function ()
                return dropGrowthFullMini[displayDB[currentDisplayFrame].auraGrowth]
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].auraGrowth = dropGrowthRef[v]
                Srendarr.displayFrames[currentDisplayFrame]:Configure()
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureDragOverlay()
                Srendarr.displayFrames[currentDisplayFrame]:UpdateDisplay()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
            scrollable = 7,
        },
        { -- auraGrowth 						ICON
            type = 'dropdown',
            name = L.DisplayFrame_Growth,
            tooltip = L.DisplayFrame_GrowthTip,
            choices = dropGrowthIcon,
            getFunc = function ()
                return dropGrowthIcon[displayDB[currentDisplayFrame].auraGrowth]
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].auraGrowth = dropGrowthRef[v]
                Srendarr.displayFrames[currentDisplayFrame]:Configure()
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureDragOverlay()
                Srendarr.displayFrames[currentDisplayFrame]:UpdateDisplay()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = true, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = true, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- auraPadding						FULL, ICON, MINI, GROUP
            type = 'slider',
            name = L.DisplayFrame_Padding,
            tooltip = L.DisplayFrame_PaddingTip,
            min = 0,
            max = 32,
            getFunc = function ()
                return displayDB[currentDisplayFrame].auraPadding
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].auraPadding = v
                if currentDisplayFrame < GROUP_START_FRAME then
                    Srendarr.displayFrames[currentDisplayFrame]:Configure()
                    Srendarr.displayFrames[currentDisplayFrame]:ConfigureDragOverlay()
                    Srendarr.displayFrames[currentDisplayFrame]:UpdateDisplay()
                else
                    for i = GROUP_START_FRAME, GROUP_DEND_FRAME do
                        Srendarr.displayFrames[i]:Configure()
                        Srendarr.displayFrames[i]:UpdateDisplay()
                    end
                end
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = false, [AURA_STYLE_GROUPD] = false },
        },
        { -- auraSort							FULL, ICON, MINI, GROUP
            type = 'dropdown',
            name = L.DisplayFrame_Sort,
            tooltip = L.DisplayFrame_SortTip,
            choices = dropSort,
            sort = 'name-up',
            getFunc = function ()
                return dropSort[displayDB[currentDisplayFrame].auraSort]
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].auraSort = dropSortRef[v]
                if currentDisplayFrame < GROUP_START_FRAME then
                    Srendarr.displayFrames[currentDisplayFrame]:Configure()
                    Srendarr.displayFrames[currentDisplayFrame]:UpdateDisplay()
                else
                    for i = GROUP_START_FRAME, GROUP_DEND_FRAME do
                        Srendarr.displayFrames[i]:Configure()
                        Srendarr.displayFrames[i]:UpdateDisplay()
                    end
                end
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = false, [AURA_STYLE_GROUPD] = false },
            scrollable = 7,
        },
        { -- auraClassIverride				FULL, ICON, MINI
            type = 'dropdown',
            name = L.DisplayFrame_AuraClassOverride,
            tooltip = L.DisplayFrame_AuraClassOverrideTip,
            choices = dropAuraClass,
            sort = 'name-up',
            getFunc = function ()
                local checkDB = { [1] = L.DropAuraClassBuff, [3] = L.DropAuraClassDefault, [5] = L.DropAuraClassDebuff }
                return checkDB[displayDB[currentDisplayFrame].auraClassOverride]
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].auraClassOverride = dropAuraClassRef[v]
                Srendarr.OnEquipChange()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
            scrollable = 7,
        },
        { -- highlightToggled					FULL, ICON
            type = 'checkbox',
            name = L.DisplayFrame_Highlight,
            tooltip = L.DisplayFrame_HighlightTip,
            getFunc = function ()
                return displayDB[currentDisplayFrame].highlightToggled
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].highlightToggled = v
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = true, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        -- 	{					-- enableTooltips					ICON
        -- 		type = 'checkbox',
        -- 		name = L.DisplayFrame_Tooltips,
        -- 		tooltip = L.DisplayFrame_TooltipsTip,
        -- 		warning = L.DisplayFrame_TooltipsWarn,
        -- 		getFunc = function()
        -- 			return displayDB[currentDisplayFrame].enableTooltips
        -- 		end,
        -- 		setFunc = function(v)
        -- 			displayDB[currentDisplayFrame].enableTooltips = v
        -- 			Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
        -- 		end,
        -- 		hideOnStyle = {[AURA_STYLE_FULL] = true, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = true, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true},
        -- 	},
        -- -----------------------
        -- ABILITY TEXT SETTINGS
        -- -----------------------
        { -- nameHeader						FULL, MINI
            type = 'header',
            name = L.DisplayFrame_NameHeader,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- nameFont							FULL, MINI
            type = 'dropdown',
            name = L.GenericSetting_NameFont,
            choices = LMP:List('font'),
            getFunc = function ()
                return displayDB[currentDisplayFrame].nameFont
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].nameFont = v
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
            scrollable = 7,
        },
        { -- nameStyle						FULL, MINI
            type = 'dropdown',
            name = L.GenericSetting_NameStyle,
            choices = dropFontStyle,
            getFunc = function ()
                return displayDB[currentDisplayFrame].nameStyle
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].nameStyle = v
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
            scrollable = 7,
        },
        { -- nameColor						FULL, MINI
            type                    = 'colorpicker',
            getFunc                 = function ()
                return unpack(displayDB[currentDisplayFrame].nameColor)
            end,
            setFunc                 = function (r, g, b, a)
                displayDB[currentDisplayFrame].nameColor[1] = r
                displayDB[currentDisplayFrame].nameColor[2] = g
                displayDB[currentDisplayFrame].nameColor[3] = b
                displayDB[currentDisplayFrame].nameColor[4] = a
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            widgetRightAlign        = true,
            widgetPositionAndResize = -15,
            hideOnStyle             = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- nameSize							FULL, MINI
            type = 'slider',
            name = L.GenericSetting_NameSize,
            min = 8,
            max = 32,
            getFunc = function ()
                return displayDB[currentDisplayFrame].nameSize
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].nameSize = v
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        -- -----------------------
        -- TIMER TEXT SETTINGS
        -- -----------------------
        { -- timerHeader						FULL, ICON, MINI, GROUP
            type = 'header',
            name = L.DisplayFrame_TimerHeader,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = false, [AURA_STYLE_GROUPD] = false },
        },
        { -- timerFont						FULL, ICON, MINI, GROUP
            type = 'dropdown',
            name = L.GenericSetting_TimerFont,
            choices = LMP:List('font'),
            getFunc = function ()
                return displayDB[currentDisplayFrame].timerFont
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].timerFont = v
                if currentDisplayFrame < GROUP_START_FRAME then
                    Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
                else
                    for i = GROUP_START_FRAME, GROUP_DEND_FRAME do
                        Srendarr.displayFrames[i]:ConfigureAssignedAuras()
                    end
                end
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = false, [AURA_STYLE_GROUPD] = false },
            scrollable = 7,
        },
        { -- timerStyle						FULL, ICON, MINI, GROUP
            type = 'dropdown',
            name = L.GenericSetting_TimerStyle,
            choices = dropFontStyle,
            getFunc = function ()
                return displayDB[currentDisplayFrame].timerStyle
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].timerStyle = v
                if currentDisplayFrame < GROUP_START_FRAME then
                    Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
                else
                    for i = GROUP_START_FRAME, GROUP_DEND_FRAME do
                        Srendarr.displayFrames[i]:ConfigureAssignedAuras()
                    end
                end
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = false, [AURA_STYLE_GROUPD] = false },
            scrollable = 7,
        },
        { -- timerColor						FULL, ICON, MINI, GROUP
            type                    = 'colorpicker',
            getFunc                 = function ()
                return unpack(displayDB[currentDisplayFrame].timerColor)
            end,
            setFunc                 = function (r, g, b, a)
                displayDB[currentDisplayFrame].timerColor[1] = r
                displayDB[currentDisplayFrame].timerColor[2] = g
                displayDB[currentDisplayFrame].timerColor[3] = b
                displayDB[currentDisplayFrame].timerColor[4] = a
                if currentDisplayFrame < GROUP_START_FRAME then
                    Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
                else
                    for i = GROUP_START_FRAME, GROUP_DEND_FRAME do
                        Srendarr.displayFrames[i]:ConfigureAssignedAuras()
                    end
                end
            end,
            widgetRightAlign        = true,
            widgetPositionAndResize = -15,
            hideOnStyle             = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = false, [AURA_STYLE_GROUPD] = false },
        },
        { -- timerSize						FULL, ICON, MINI, GROUP
            type = 'slider',
            name = L.GenericSetting_TimerSize,
            min = 8,
            max = 32,
            getFunc = function ()
                return displayDB[currentDisplayFrame].timerSize
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].timerSize = v
                if currentDisplayFrame < GROUP_START_FRAME then
                    Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
                else
                    for i = GROUP_START_FRAME, GROUP_DEND_FRAME do
                        Srendarr.displayFrames[i]:ConfigureAssignedAuras()
                    end
                end
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = false, [AURA_STYLE_GROUPD] = false },
        },
        { -- timerLocation					FULL
            type = 'dropdown',
            name = L.DisplayFrame_TimerLocation,
            tooltip = L.DisplayFrame_TimerLocationTip,
            choices = dropTimerFull,
            getFunc = function ()
                return dropTimerFull[displayDB[currentDisplayFrame].timerLocation]
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].timerLocation = dropTimerRef[v]
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = true, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
            scrollable = 7,
        },
        { -- timerLocation					ICON, GROUP
            type = 'dropdown',
            name = L.DisplayFrame_TimerLocation,
            tooltip = L.DisplayFrame_TimerLocationTip,
            choices = dropTimerIcon,
            getFunc = function ()
                return dropTimerIcon[displayDB[currentDisplayFrame].timerLocation]
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].timerLocation = dropTimerRef[v]
                if currentDisplayFrame < GROUP_START_FRAME then
                    Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
                else
                    for i = GROUP_START_FRAME, GROUP_DEND_FRAME do
                        Srendarr.displayFrames[i]:ConfigureAssignedAuras()
                    end
                end
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = true, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = true, [AURA_STYLE_GROUPB] = false, [AURA_STYLE_GROUPD] = false },
            scrollable = 7,
        },
        { -- timerHMS							FULL, ICON, MINI, GROUP
            type = 'checkbox',
            name = L.DisplayFrame_TimerHMS,
            tooltip = L.DisplayFrame_TimerHMSTip,
            getFunc = function ()
                return displayDB[currentDisplayFrame].timerHMS
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].timerHMS = v
                if currentDisplayFrame < GROUP_START_FRAME then
                    Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
                else
                    for i = GROUP_START_FRAME, GROUP_DEND_FRAME do
                        Srendarr.displayFrames[i]:ConfigureAssignedAuras()
                    end
                end
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = false, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = false, [AURA_STYLE_GROUPD] = false },
        },
        -- -----------------------
        -- STATUSBAR SETTINGS
        -- -----------------------
        { -- barHeader						FULL, MINI
            type = 'header',
            name = L.DisplayFrame_BarHeader,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- barGloss							FULL, MINI
            type = 'checkbox',
            name = L.DisplayFrame_BarGloss,
            tooltip = L.DisplayFrame_BarGlossTip,
            getFunc = function ()
                return displayDB[currentDisplayFrame].barGloss
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].barGloss = v
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- barReverse						FULL, MINI
            type = 'checkbox',
            name = L.DisplayFrame_BarReverse,
            tooltip = L.DisplayFrame_BarReverseTip,
            getFunc = function ()
                return displayDB[currentDisplayFrame].barReverse
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].barReverse = v
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureDragOverlay()
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- barWidth							FULL, MINI
            type = 'slider',
            name = L.GenericSetting_BarWidth,
            tooltip = L.GenericSetting_BarWidthTip,
            min = 40,
            max = 240,
            step = 5,
            getFunc = function ()
                return displayDB[currentDisplayFrame].barWidth
            end,
            setFunc = function (v)
                displayDB[currentDisplayFrame].barWidth = v
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureDragOverlay()
            end,
            hideOnStyle = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- barBuffColor[TIMED]:2			FULL, MINI
            type             = 'colorpicker',
            name             = L.DisplayFrame_BarBuffTimed,
            tooltip          = L.DisplayFrame_BarBuffTimedTip,
            getFunc          = function ()
                local colors = displayDB[currentDisplayFrame].barColors[AURA_TYPE_TIMED]
                return colors.r2, colors.g2, colors.b2
            end,
            setFunc          = function (r, g, b)
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_TIMED].r2 = r
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_TIMED].g2 = g
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_TIMED].b2 = b
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            widgetRightAlign = true,
            hideOnStyle      = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- barBuffColor[TIMED]:1			FULL, MINI
            type                    = 'colorpicker',
            tooltip                 = L.DisplayFrame_BarBuffTimedTip,
            getFunc                 = function ()
                local colors = displayDB[currentDisplayFrame].barColors[AURA_TYPE_TIMED]
                return colors.r1, colors.g1, colors.b1
            end,
            setFunc                 = function (r, g, b)
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_TIMED].r1 = r
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_TIMED].g1 = g
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_TIMED].b1 = b
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            widgetRightAlign        = true,
            widgetPositionAndResize = 127,
            hideOnStyle             = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- barBuffColor[PASSIVE]:2			FULL, MINI
            type             = 'colorpicker',
            name             = L.DisplayFrame_BarBuffPassive,
            tooltip          = L.DisplayFrame_BarBuffPassiveTip,
            getFunc          = function ()
                local colors = displayDB[currentDisplayFrame].barColors[AURA_TYPE_PASSIVE]
                return colors.r2, colors.g2, colors.b2
            end,
            setFunc          = function (r, g, b)
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_PASSIVE].r2 = r
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_PASSIVE].g2 = g
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_PASSIVE].b2 = b
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            widgetRightAlign = true,
            hideOnStyle      = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- barBuffColor[PASSIVE]:1			FULL, MINI
            type                    = 'colorpicker',
            tooltip                 = L.DisplayFrame_BarBuffPassiveTip,
            getFunc                 = function ()
                local colors = displayDB[currentDisplayFrame].barColors[AURA_TYPE_PASSIVE]
                return colors.r1, colors.g1, colors.b1
            end,
            setFunc                 = function (r, g, b)
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_PASSIVE].r1 = r
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_PASSIVE].g1 = g
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_PASSIVE].b1 = b
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            widgetRightAlign        = true,
            widgetPositionAndResize = 127,
            hideOnStyle             = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- barDebuffColor[TIMED]:2			FULL, MINI
            type             = 'colorpicker',
            name             = L.DisplayFrame_BarDebuffTimed,
            tooltip          = L.DisplayFrame_BarDebuffTimedTip,
            getFunc          = function ()
                local colors = displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_TIMED]
                return colors.r2, colors.g2, colors.b2
            end,
            setFunc          = function (r, g, b)
                displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_TIMED].r2 = r
                displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_TIMED].g2 = g
                displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_TIMED].b2 = b
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            widgetRightAlign = true,
            hideOnStyle      = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- barDebuffColor[TIMED]:1			FULL, MINI
            type                    = 'colorpicker',
            tooltip                 = L.DisplayFrame_BarDebuffTimedTip,
            getFunc                 = function ()
                local colors = displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_TIMED]
                return colors.r1, colors.g1, colors.b1
            end,
            setFunc                 = function (r, g, b)
                displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_TIMED].r1 = r
                displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_TIMED].g1 = g
                displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_TIMED].b1 = b
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            widgetRightAlign        = true,
            widgetPositionAndResize = 127,
            hideOnStyle             = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- barDebuffColor[PASSIVE]:2		FULL, MINI
            type             = 'colorpicker',
            name             = L.DisplayFrame_BarDebuffPassive,
            tooltip          = L.DisplayFrame_BarDebuffPassiveTip,
            getFunc          = function ()
                local colors = displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_PASSIVE]
                return colors.r2, colors.g2, colors.b2
            end,
            setFunc          = function (r, g, b)
                displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_PASSIVE].r2 = r
                displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_PASSIVE].g2 = g
                displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_PASSIVE].b2 = b
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            widgetRightAlign = true,
            hideOnStyle      = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- barDebuffColor[PASSIVE]:1		FULL, MINI
            type                    = 'colorpicker',
            tooltip                 = L.DisplayFrame_BarDebuffPassiveTip,
            getFunc                 = function ()
                local colors = displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_PASSIVE]
                return colors.r1, colors.g1, colors.b1
            end,
            setFunc                 = function (r, g, b)
                displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_PASSIVE].r1 = r
                displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_PASSIVE].g1 = g
                displayDB[currentDisplayFrame].barColors[DEBUFF_TYPE_PASSIVE].b1 = b
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            widgetRightAlign        = true,
            widgetPositionAndResize = 127,
            hideOnStyle             = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- barColor[TOGGLED]:2				FULL, MINI
            type             = 'colorpicker',
            name             = L.DisplayFrame_BarToggled,
            tooltip          = L.DisplayFrame_BarToggledTip,
            getFunc          = function ()
                local colors = displayDB[currentDisplayFrame].barColors[AURA_TYPE_TOGGLED]
                return colors.r2, colors.g2, colors.b2
            end,
            setFunc          = function (r, g, b)
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_TOGGLED].r2 = r
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_TOGGLED].g2 = g
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_TOGGLED].b2 = b
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            widgetRightAlign = true,
            hideOnStyle      = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
        { -- barColor[TOGGLED]:1				FULL, MINI
            type                    = 'colorpicker',
            tooltip                 = L.DisplayFrame_BarToggledTip,
            getFunc                 = function ()
                local colors = displayDB[currentDisplayFrame].barColors[AURA_TYPE_TOGGLED]
                return colors.r1, colors.g1, colors.b1
            end,
            setFunc                 = function (r, g, b)
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_TOGGLED].r1 = r
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_TOGGLED].g1 = g
                displayDB[currentDisplayFrame].barColors[AURA_TYPE_TOGGLED].b1 = b
                Srendarr.displayFrames[currentDisplayFrame]:ConfigureAssignedAuras()
            end,
            widgetRightAlign        = true,
            widgetPositionAndResize = 127,
            hideOnStyle             = { [AURA_STYLE_FULL] = false, [AURA_STYLE_ICON] = true, [AURA_STYLE_MINI] = false, [AURA_STYLE_GROUPB] = true, [AURA_STYLE_GROUPD] = true },
        },
    }
}