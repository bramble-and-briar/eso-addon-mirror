BSCAllianceRanking = BSCAllianceRanking or {}
local BSCARI = BSCAllianceRanking

BSCARI.Name = "BSCs-AllianceRanking"
BSCARI.NameSpaced = "BSCs-Alliance Ranking/Point Info"
BSCARI.Author = "@BloodStainChild666"
BSCARI.Version = 1
BSCARI.SavedVar = "BSCAllianceRankingSaved"
BSCARI.NameMenu = "BSCs-AllianceRanking"
BSCARI.VersionDisplay = "2.3.35-u51"

BSCARI.CurrentCharID = -1

local HUD_BAR_SOLID_TEXTURE = "EsoUI/Art/Miscellaneous/white.dds"

-- Saved Vars
local defaultSavedVarsAccount = { 
	CHAR_LIST = {},
	SETTING = {},
	cooldownRotWTime = 0,
}


BSCARI.DefaultCharacterSettings =
{
    bAlert = false,
    bAlertBuff = false,
    bEnableUI = false,
    ARO_H = false,
    CRO_H = false,
    TRO_H = false,
    VRO_H = false,
    VCO_H = false,
    LOCK_UI = false,
    bAPInfoChat = false,
    PLAY_SOUND = false,
    bAlertLowPop = false,
    offsetX = 0,
    offsetY = 0,
    ARO_X = 0,
    ARO_Y = 0,
    CRO_X = 0,
    CRO_Y = 0,
    TRO_X = 0,
    TRO_Y = 0,
    VRO_X = 0,
    VRO_Y = 0,
    VCO_X = 0,
    VCO_Y = 0,
    HUD_BAR_EDGE_SIZE = 2,
    AP_HUD_BAR_COLOR = { r = 0.20, g = 0.85, b = 0.20, a = 1 },
    _HUD_BAR_COLOR_DEFAULT_MIGRATED = false,
    VETERANCY_HUD_BAR_COLOR = { r = 0, g = 0.85, b = 0.85, a = 1 },
    HUD_BAR_CENTER_COLOR = { r = 0, g = 0, b = 0, a = 0.40 },
    HUD_BAR_EDGE_COLOR = { r = 0, g = 0, b = 0, a = 1 },
}

local function CopyDefaultSetting(value)
    if type(value) == "table" then
        local copy = {}
        for k, v in pairs(value) do
            copy[k] = v
        end
        return copy
    end
    return value
end

local function IsSameColorSetting(color, r, g, b, a)
    if type(color) ~= "table" then return false end
    local tolerance = 0.001
    return math.abs((tonumber(color.r) or -1) - r) <= tolerance
        and math.abs((tonumber(color.g) or -1) - g) <= tolerance
        and math.abs((tonumber(color.b) or -1) - b) <= tolerance
        and math.abs((tonumber(color.a) or -1) - a) <= tolerance
end

function BSCARI:GetCurrentCharacterSettings()
    if not self.SVA then return nil end
    self.SVA.SETTING = self.SVA.SETTING or {}

    local settings = self.SVA.SETTING[self.CurrentCharID]
    if settings == nil then
        settings = {}
        self.SVA.SETTING[self.CurrentCharID] = settings
    end

    for key, value in pairs(self.DefaultCharacterSettings) do
        if settings[key] == nil then
            settings[key] = CopyDefaultSetting(value)
        end
    end

    if settings._HUD_BAR_COLOR_DEFAULT_MIGRATED ~= true then
        if IsSameColorSetting(settings.AP_HUD_BAR_COLOR, 0.92, 0.68, 0.16, 1) then
            settings.AP_HUD_BAR_COLOR = CopyDefaultSetting(self.DefaultCharacterSettings.AP_HUD_BAR_COLOR)
        end
        settings._HUD_BAR_COLOR_DEFAULT_MIGRATED = true
    end

    return settings
end

local ENABLED_STATE = 1
local DISABLED_STATE = 0.5

-------------------------------------------------------------------------------------------------------------------------------------------------
local CAMPAIGN_OVERVIEW_TYPE_BSCARI_AP_RANKING = 1001
local CAMPAIGN_OVERVIEW_TYPE_BSCARI_TIER_INFO = 1002

local BSCARI_CAMPAIGN_ICON =
{
    normal = "EsoUI/Art/icons/achievements_indexicon_alliancewar_up.dds",
    pressed = "EsoUI/Art/icons/achievements_indexicon_alliancewar_down.dds",
    mouseover = "EsoUI/Art/icons/achievements_indexicon_alliancewar_over.dds",
}

local function SafeRemoveCampaignFragment(fragment)
    if fragment and CAMPAIGN_OVERVIEW_SCENE then
        CAMPAIGN_OVERVIEW_SCENE:RemoveFragment(fragment)
    end
end

local function RemoveBSCARICampaignFragments()
    SafeRemoveCampaignFragment(BSCARI.ALLIANCE_POINTSVIEW_FRAGMENT)
    SafeRemoveCampaignFragment(BSCARI.ALLIANCE_TIERVIEW_FRAGMENT)
    SafeRemoveCampaignFragment(BSCARI.ALLIANCE_BGSTYLEVIEW_FRAGMENT)
end

ZO_CreateStringId("SI_BSCARI_MAIN_TAB", "BSCs-AllianceRanking")
ZO_CreateStringId("SI_BSCARI_SETTINGS_TAB", "Settings")
ZO_CreateStringId("SI_BSCARI_AP_RANKING_TAB", "AP Ranking")
ZO_CreateStringId("SI_BSCARI_TIER_INFO_TAB", "Char Tier Info")
ZO_CreateStringId("SI_BSCARI_VETERANCY_RANKING_TAB", "Veterancy Ranking")
ZO_CreateStringId("SI_BSCARI_PVP_STYLES_TAB", "PvP Styles")

local BSCARI_MAIN_SCENE_NAME = "bscarAllianceRanking"
local BSCARI_SUBTAB_SETTINGS = "settings"
local BSCARI_SUBTAB_TIER = "tier"
local BSCARI_SUBTAB_AP = "ap"
local BSCARI_SUBTAB_PVP_STYLES = "pvpstyles"
local BSCARI_SUBTAB_VETERANCY = "veterancy"

local function AddFragmentGroupSafe(scene, fragmentGroup)
    if scene and fragmentGroup then
        scene:AddFragmentGroup(fragmentGroup)
    end
end

local function AddFragmentSafe(scene, fragment)
    if scene and fragment then
        scene:AddFragment(fragment)
    end
end

local function TopTabIconData(sceneName, stringId)
    return
    {
        categoryName = stringId,
        descriptor = sceneName,
        normal = BSCARI_CAMPAIGN_ICON.normal,
        pressed = BSCARI_CAMPAIGN_ICON.pressed,
        highlight = BSCARI_CAMPAIGN_ICON.mouseover,
        visible = function() return true end,
    }
end

local function MenuBarIconExists(iconData, sceneName)
    if not iconData then return true end

    for _, data in ipairs(iconData) do
        if data.descriptor == sceneName then
            return true
        end
    end

    return false
end

function BSCARI:CreateAllianceWarTopTabScene(sceneName, fragment)
    local scene = SCENE_MANAGER:GetScene(sceneName)
    if not scene then
        scene = ZO_Scene:New(sceneName, SCENE_MANAGER)
    end

    AddFragmentGroupSafe(scene, FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    AddFragmentGroupSafe(scene, FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL)
    AddFragmentGroupSafe(scene, FRAGMENT_GROUP.PLAYER_PROGRESS_BAR_KEYBOARD_CURRENT)

    AddFragmentSafe(scene, RIGHT_BG_FRAGMENT)
    AddFragmentSafe(scene, TITLE_FRAGMENT)

    local sceneGroupInfo = MAIN_MENU_KEYBOARD and MAIN_MENU_KEYBOARD.sceneGroupInfo and MAIN_MENU_KEYBOARD.sceneGroupInfo["allianceWarSceneGroup"]
    if sceneGroupInfo and sceneGroupInfo.sceneGroupBarFragment then
        AddFragmentSafe(scene, sceneGroupInfo.sceneGroupBarFragment)
    end

    AddFragmentSafe(scene, fragment)

    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            self:UpdateRotW()
            self:RequestCampaignLeaderboardData("bscar-tab-show", false, true)
        end
    end)

    if SYSTEMS and SYSTEMS.RegisterKeyboardRootScene then
        SYSTEMS:RegisterKeyboardRootScene(sceneName, scene)
    end

    return scene
end

function BSCARI:RegisterAllianceWarTopTabs()
    if self._allianceWarTopTabsRegistered then
        return true
    end

    if not MAIN_MENU_KEYBOARD or not SCENE_MANAGER or not self.ALLIANCE_RANKINGVIEW_FRAGMENT then
        return false
    end

    local sceneGroupInfo = MAIN_MENU_KEYBOARD.sceneGroupInfo and MAIN_MENU_KEYBOARD.sceneGroupInfo["allianceWarSceneGroup"]
    local sceneGroup = SCENE_MANAGER:GetSceneGroup("allianceWarSceneGroup")
    local categoryInfo = MAIN_MENU_KEYBOARD.categoryInfo and MAIN_MENU_KEYBOARD.categoryInfo[MENU_CATEGORY_ALLIANCE_WAR]

    if not sceneGroupInfo or not sceneGroup or not categoryInfo then
        return false
    end

    self:CreateAllianceWarTopTabScene(BSCARI_MAIN_SCENE_NAME, self.ALLIANCE_RANKINGVIEW_FRAGMENT)

    local iconData = sceneGroupInfo.menuBarIconData
    if iconData and not MenuBarIconExists(iconData, BSCARI_MAIN_SCENE_NAME) then
        iconData[#iconData + 1] = TopTabIconData(BSCARI_MAIN_SCENE_NAME, SI_BSCARI_MAIN_TAB)
    end

    sceneGroup:AddScene(BSCARI_MAIN_SCENE_NAME)
    MAIN_MENU_KEYBOARD:AddRawScene(BSCARI_MAIN_SCENE_NAME, MENU_CATEGORY_ALLIANCE_WAR, categoryInfo, "allianceWarSceneGroup")
    if MAIN_MENU_KEYBOARD.UpdateSceneGroupButtons then
        MAIN_MENU_KEYBOARD:UpdateSceneGroupButtons("allianceWarSceneGroup")
    end

    self._allianceWarTopTabsRegistered = true
    return true
end

local BSCARI_SUBTAB_BUTTON_TEXT =
{
    [BSCARI_SUBTAB_SETTINGS] = "Settings",
    [BSCARI_SUBTAB_TIER] = "Char Tier Info",
    [BSCARI_SUBTAB_AP] = "AP Ranking",
    [BSCARI_SUBTAB_PVP_STYLES] = "PvP Styles",
    [BSCARI_SUBTAB_VETERANCY] = "Veterancy Ranking",
}

local function AnchorControlFill(control, parent)
    if not control or not parent then return end

    -- CampaignTierView/CampaignAPView/CampaignVeterancyView are TopLevelControls.
    -- ESO does not allow reparenting TopLevelControls away from GuiRoot, so only
    -- anchor them to our content area and manage visibility manually.
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    control:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0)
end

function BSCARI:HideAllianceRankingSubViews()
    local views =
    {
        CampaignTierView,
        CampaignAPView,
        CampaignPvPStylesView,
        CampaignVeterancyView,
        self.ALLIANCE_RANKINGVIEW_SETTINGS,
    }

    for _, control in ipairs(views) do
        if control then
            control:SetHidden(true)
        end
    end
end


local BSCARI_SETTINGS_ROWS =
{
    { type = "header", text = "General" },
    { key = "bAPInfoChat", text = "Print AP gain to Chat" },
    { key = "bAlert", text = "AP Tier Alert" },
    { key = "bAlertLowPop", text = "Alert LowPop/Score AP Bonus" },

    { type = "header", text = "Buff Display" },
    { key = "bEnableUI", text = "Show Buff UI in Cyrodiil" },
    { key = "bAlertBuff", text = "AP Buff Reminder" },
    { key = "PLAY_SOUND", text = "Play Sound on Buff End" },
    { key = "LOCK_UI", text = "Lock Buff/AP HUD UI" },

    { type = "header", text = "AP HUD Bars" },
    { key = "ARO_H", text = "Show Total AP Bar UI" },
    { key = "CRO_H", text = "Show Next Level AP Bar UI" },
    { key = "TRO_H", text = "Show Tier AP Bar UI" },
    { type = "color", key = "AP_HUD_BAR_COLOR", text = "AP HUD Bar Color" },

    { type = "header", text = "Veterancy HUD Bars" },
    { key = "VRO_H", text = "Show Total Veterancy Bar UI" },
    { key = "VCO_H", text = "Show Current Veterancy Level Bar UI" },
    { type = "color", key = "VETERANCY_HUD_BAR_COLOR", text = "Veterancy HUD Bar Color" },

    { type = "header", text = "HUD Bar Appearance" },
    { type = "stepper", key = "HUD_BAR_EDGE_SIZE", text = "HUD Bar Edge Size", min = 0, max = 8, step = 1 },
    { type = "color", key = "HUD_BAR_CENTER_COLOR", text = "HUD Bar Center Color" },
    { type = "color", key = "HUD_BAR_EDGE_COLOR", text = "HUD Bar Edge Color" },
}

local function SetSettingsCheckboxVisual(rowControl, value)
    if not rowControl then return end

    if rowControl.checkbox then
        ZO_CheckButton_SetCheckState(rowControl.checkbox, value == true)
    end

    if rowControl.nameLabel then
        local color = value and ZO_SELECTED_TEXT or ZO_DISABLED_TEXT
        rowControl.nameLabel:SetColor(color:UnpackRGBA())
    end
end

local function ClampNumber(value, minValue, maxValue, defaultValue)
    value = tonumber(value) or defaultValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function GetColorTableValue(settings, key, defaultColor)
    local color = settings and settings[key]
    if type(color) ~= "table" then
        color = CopyDefaultSetting(defaultColor)
        if settings then
            settings[key] = color
        end
    end

    color.r = tonumber(color.r) or defaultColor.r or 1
    color.g = tonumber(color.g) or defaultColor.g or 1
    color.b = tonumber(color.b) or defaultColor.b or 1
    color.a = tonumber(color.a) or defaultColor.a or 1
    return color
end

local function SetSettingsSliderVisual(rowControl, settings)
    if not rowControl or not rowControl.slider then return end

    local rowData = rowControl.rowData
    local value = settings and settings[rowData.key] or rowData.min
    value = ClampNumber(value, rowData.min, rowData.max, rowData.min)

    rowControl.slider:SetValue(value)
    if rowControl.valueLabel then
        rowControl.valueLabel:SetText(tostring(value) .. (rowData.suffix or ""))
    end
end

local function SetSettingsStepperVisual(rowControl, settings)
    if not rowControl or not rowControl.valueLabel then return end

    local rowData = rowControl.rowData
    local value = settings and settings[rowData.key] or rowData.min
    value = ClampNumber(value, rowData.min, rowData.max, rowData.min)
    rowControl.valueLabel:SetText(tostring(value) .. (rowData.suffix or ""))
end

local function SetSettingsColorVisual(rowControl, settings)
    if not rowControl or not rowControl.swatch then return end

    local defaultColor = BSCARI.DefaultCharacterSettings[rowControl.settingKey] or { r = 1, g = 1, b = 1, a = 1 }
    local color = GetColorTableValue(settings, rowControl.settingKey, defaultColor)
    rowControl.swatch:SetCenterColor(color.r, color.g, color.b, color.a or 1)
    rowControl.swatch:SetEdgeColor(1, 1, 1, 0.75)
end

local function GetCurrentCharacterDisplayName()
    local currentCharId = BSCARI.CurrentCharID
    for index = 1, GetNumCharacters() do
        local charName, _, _, _, _, alliance, charId = GetCharacterInfo(index)
        if charId == currentCharId then
            return GetAllianceColor(alliance):Colorize(zo_strformat("<<1>>", charName))
        end
    end

    return zo_strformat("<<1>>", GetUnitName("player"))
end

function BSCARI:IsAllianceRankingSettingsTabVisible()
    return self._allianceRankingViewVisible == true and self._selectedAllianceRankingSubTab == BSCARI_SUBTAB_SETTINGS
end

local CAMPAIGN_LEADERBOARD_QUERY_COOLDOWN_MS = 60000
local CAMPAIGN_LEADERBOARD_DATA_FRESH_MS = 180000
local CAMPAIGN_LEADERBOARD_IN_FLIGHT_BLOCK_MS = 15000
local CAMPAIGN_SELECTION_QUERY_COOLDOWN_MS = 120000

local function GetSafeGameTimeMilliseconds()
    return GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
end

local CAMPAIGN_SELECTION_NATIVE_QUERY_GUARD_MS = 15000
local CAMPAIGN_LEADERBOARD_NATIVE_QUERY_GUARD_MS = 15000
local CAMPAIGN_QUERY_IN_FLIGHT_MS = 15000

local OriginalQueryCampaignSelectionData = QueryCampaignSelectionData
local OriginalQueryCampaignLeaderboardData = QueryCampaignLeaderboardData

function BSCARI:DebugCampaignQuery(message)
    if self.SVA and self.SVA.SETTING and self.CurrentCharID and self.SVA.SETTING[self.CurrentCharID] and self.SVA.SETTING[self.CurrentCharID].bDebugCampaignQueries then
        d("|cE9C62A[BSCARI QueryGuard]|r " .. tostring(message))
    end
end

function BSCARI:MarkCampaignSelectionDataReady()
    self._campaignSelectionDataReady = true
    self._campaignSelectionQueryInFlight = false
    self._lastCampaignSelectionDataAt = GetSafeGameTimeMilliseconds()
end

function BSCARI:MarkCampaignSelectionQuerySent()
    local now = GetSafeGameTimeMilliseconds()
    self._campaignSelectionQueryInFlight = true
    self._lastCampaignSelectionQuerySentAt = now
end

function BSCARI:CanSendNativeCampaignQuery(kind, cooldownMs, inFlightMs)
    local now = GetSafeGameTimeMilliseconds()
    if now <= 0 then
        return true
    end

    local lastSentKey = kind == "selection" and "_lastCampaignSelectionQuerySentAt" or "_lastCampaignLeaderboardQuerySentAt"
    local inFlightKey = kind == "selection" and "_campaignSelectionQueryInFlight" or "_campaignLeaderboardQueryInFlight"

    local lastSent = self[lastSentKey] or 0
    if self[inFlightKey] and lastSent > 0 and (now - lastSent) < (inFlightMs or CAMPAIGN_QUERY_IN_FLIGHT_MS) then
        self:DebugCampaignQuery("blocked " .. kind .. " query: in flight")
        return false
    end

    if lastSent > 0 and (now - lastSent) < cooldownMs then
        self:DebugCampaignQuery("blocked " .. kind .. " query: cooldown")
        return false
    end

    return true
end

function BSCARI:ShouldAllowNativeCampaignSelectionQuery()
    return self:CanSendNativeCampaignQuery("selection", CAMPAIGN_SELECTION_NATIVE_QUERY_GUARD_MS, CAMPAIGN_QUERY_IN_FLIGHT_MS)
end

function BSCARI:ShouldAllowNativeCampaignLeaderboardQuery(alliance)
    if alliance ~= nil and alliance ~= ALLIANCE_NONE then
        return true
    end
    return self:CanSendNativeCampaignQuery("leaderboard", CAMPAIGN_LEADERBOARD_NATIVE_QUERY_GUARD_MS, CAMPAIGN_QUERY_IN_FLIGHT_MS)
end

if OriginalQueryCampaignSelectionData then
    function QueryCampaignSelectionData(...)
        if BSCARI and BSCARI.ShouldAllowNativeCampaignSelectionQuery and not BSCARI:ShouldAllowNativeCampaignSelectionQuery() then
            return false
        end
        if BSCARI and BSCARI.MarkCampaignSelectionQuerySent then
            BSCARI:MarkCampaignSelectionQuerySent()
            BSCARI:DebugCampaignQuery("sent selection query")
        end
        return OriginalQueryCampaignSelectionData(...)
    end
end

if OriginalQueryCampaignLeaderboardData then
    function QueryCampaignLeaderboardData(alliance, ...)
        if BSCARI and BSCARI.ShouldAllowNativeCampaignLeaderboardQuery and not BSCARI:ShouldAllowNativeCampaignLeaderboardQuery(alliance) then
            return false
        end
        if BSCARI and BSCARI.MarkCampaignLeaderboardQuerySent then
            BSCARI:MarkCampaignLeaderboardQuerySent()
            BSCARI:DebugCampaignQuery("sent leaderboard query")
        end
        return OriginalQueryCampaignLeaderboardData(alliance, ...)
    end
end

function BSCARI:MarkCampaignLeaderboardDataReady()
    self._campaignLeaderboardDataReady = true
    self._campaignLeaderboardQueryInFlight = false
    self._lastCampaignLeaderboardDataAt = GetSafeGameTimeMilliseconds()
    self._lastCampaignLeaderboardCampaignId = GetAssignedCampaignId and GetAssignedCampaignId() or 0
end

function BSCARI:HasFreshCampaignLeaderboardData(maxAgeMs)
    if not self._campaignLeaderboardDataReady then
        return false
    end

    local now = GetSafeGameTimeMilliseconds()
    local lastUpdate = self._lastCampaignLeaderboardDataAt or 0
    if now == 0 or lastUpdate == 0 then
        return true
    end

    return (now - lastUpdate) <= (maxAgeMs or CAMPAIGN_LEADERBOARD_DATA_FRESH_MS)
end

function BSCARI:MarkCampaignLeaderboardQuerySent()
    local now = GetSafeGameTimeMilliseconds()
    self._campaignLeaderboardQueryInFlight = true
    self._lastCampaignLeaderboardQuerySentAt = now
    if now > 0 then
        self._nextCampaignLeaderboardQueryAt = now + CAMPAIGN_LEADERBOARD_QUERY_COOLDOWN_MS
    end
end

-- Deprecated compatibility stub. Native query guarding is handled by the local wrappers above.
function BSCARI:ShouldBlockCampaignLeaderboardQuery(alliance)
    return not self:ShouldAllowNativeCampaignLeaderboardQuery(alliance)
end

function BSCARI:RequestCampaignSelectionData(reason, force)
    if not QueryCampaignSelectionData then
        return false
    end

    local now = GetSafeGameTimeMilliseconds()
    if not force then
        local nextAllowed = self._nextCampaignSelectionQueryAt or 0
        if now > 0 and now < nextAllowed then
            return false
        end
    end

    if now > 0 then
        self._nextCampaignSelectionQueryAt = now + CAMPAIGN_SELECTION_QUERY_COOLDOWN_MS
    end

    QueryCampaignSelectionData()
    return true
end

function BSCARI:RequestCampaignLeaderboardData(reason, force, useFreshCache)
    if not QueryCampaignLeaderboardData then
        return false
    end

    if useFreshCache and not force and self:HasFreshCampaignLeaderboardData() then
        return "cached"
    end

    local now = GetSafeGameTimeMilliseconds()
    if not force then
        local nextAllowed = self._nextCampaignLeaderboardQueryAt or 0
        if now > 0 and now < nextAllowed then
            return false
        end
    end

    self:MarkCampaignLeaderboardQuerySent()
    local result = QueryCampaignLeaderboardData(ALLIANCE_NONE)

    return result ~= false
end

local function BSCARI_IsInCyrodiil()
    return IsInCyrodiil and IsInCyrodiil() == true
end

local function IsSceneShowing(sceneName)
    if not SCENE_MANAGER then return false end
    local scene = SCENE_MANAGER:GetScene(sceneName)
    return scene ~= nil and scene:IsShowing()
end

function BSCARI:IsAllianceWarUiShowing()
    return IsSceneShowing("campaignOverview")
        or IsSceneShowing("campaignBrowser")
        or IsSceneShowing(BSCARI_MAIN_SCENE_NAME)
end

function BSCARI:RequestCyrodiilCampaignBonusData(reason)
    -- Never add extra campaign queries while the Alliance War UI is open.
    -- The native Overview/Campaigns scenes query their own data when they are shown.
    if self:IsAllianceWarUiShowing() then
        return false
    end

    -- The Buff UI is Cyrodiil-only, so background bonus refreshes are Cyrodiil-only too.
    if not BSCARI_IsInCyrodiil() then
        return false
    end

    return self:RequestCampaignLeaderboardData(reason or "cyrodiil-bonus", false, true)
end

function BSCARI:RequestInitialCampaignData()
    -- Disabled for safety: no automatic campaign selection/leaderboard query on login.
    -- The native Alliance War Overview/Campaigns scenes query their own data when shown.
    return false
end


function BSCARI:IsBuffInfoPreviewActive()
    return self._settingsPreviewActive == true and self:IsAllianceRankingSettingsTabVisible()
end

function BSCARI:ShouldShowBuffInfoUI()
    if self:IsBuffInfoPreviewActive() then
        return true
    end

    local settings = self:GetCurrentCharacterSettings()
    return settings ~= nil and settings.bEnableUI == true and BSCARI_IsInCyrodiil()
end

local function GetSceneByName(sceneName)
    if not SCENE_MANAGER then return nil end
    return SCENE_MANAGER:GetScene(sceneName)
end

local function RemoveBuffInfoFragmentFromScene(scene, fragment)
    if scene and fragment then
        scene:RemoveFragment(fragment)
    end
end

local function AddBuffInfoFragmentToScene(scene, fragment)
    if scene and fragment then
        scene:AddFragment(fragment)
    end
end

function BSCARI:EnsureBuffInfoFragment()
    if not BSCAllianceRankingBuffInfoUI then return nil end

    if not self.BuffInfoUIFragment then
        self.BuffInfoUIFragment = ZO_SimpleSceneFragment:New(BSCAllianceRankingBuffInfoUI)
    end

    return self.BuffInfoUIFragment
end

function BSCARI:RemoveBuffInfoUIFragments(hideControl)
    local fragment = self.BuffInfoUIFragment
    if fragment and self._buffInfoUIFragmentAdded then
        RemoveBuffInfoFragmentFromScene(GetSceneByName("hud"), fragment)
        RemoveBuffInfoFragmentFromScene(GetSceneByName("hudui"), fragment)
    end
    self._buffInfoUIFragmentAdded = false

    if hideControl ~= false and BSCAllianceRankingBuffInfoUI then
        BSCAllianceRankingBuffInfoUI:SetHidden(true)
    end
end

function BSCARI:AddBuffInfoUIFragments()
    local fragment = self:EnsureBuffInfoFragment()
    if not fragment or self._buffInfoUIFragmentAdded then return end

    AddBuffInfoFragmentToScene(GetSceneByName("hud"), fragment)
    AddBuffInfoFragmentToScene(GetSceneByName("hudui"), fragment)
    self._buffInfoUIFragmentAdded = true
end

function BSCARI:UpdateBuffInfoFragment()
    local settings = self:GetCurrentCharacterSettings()
    if not settings or not BSCAllianceRankingBuffInfoUI then return end

    if self:IsBuffInfoPreviewActive() then
        self:RemoveBuffInfoUIFragments(false)
        BSCAllianceRankingBuffInfoUI:SetMovable(not settings.LOCK_UI)
        BSCAllianceRankingBuffInfoUI:SetMouseEnabled(not settings.LOCK_UI)
        BSCAllianceRankingBuffInfoUI:SetHidden(false)
        return
    end

    BSCAllianceRankingBuffInfoUI:SetMovable(not settings.LOCK_UI)
    BSCAllianceRankingBuffInfoUI:SetMouseEnabled(not settings.LOCK_UI)

    if self:ShouldShowBuffInfoUI() then
        self:AddBuffInfoUIFragments()
    else
        self:RemoveBuffInfoUIFragments()
        if BSCAllianceRankingBuffInfoAlertUI then
            BSCAllianceRankingBuffInfoAlertUI:SetHidden(true)
        end
    end
end

function BSCARI:RefreshBuffInfoVisibility()
    self:UpdateBuffInfoFragment()
end

function BSCARI:ApplyAllianceRankingSetting(key, value)
    local settings = self:GetCurrentCharacterSettings()
    if not settings then return end

    settings[key] = value == true

    if key == "bAlert" and self.CboxControl then
        ZO_CheckButton_SetCheckState(self.CboxControl, settings[key])
    elseif key == "bEnableUI" then
        self:RefreshBuffInfoVisibility()
    elseif key == "ARO_H" or key == "CRO_H" or key == "TRO_H" or key == "VRO_H" or key == "VCO_H" then
        self:UpdateUISettingsBAR()
    elseif key == "LOCK_UI" then
        if BSCAllianceRankingBuffInfoUI then
            BSCAllianceRankingBuffInfoUI:SetMovable(not settings[key])
            BSCAllianceRankingBuffInfoUI:SetMouseEnabled(not settings[key])
        end
        self:UpdateUISettingsBAR()
        self:RefreshBuffInfoVisibility()
    end

    self:RefreshAllianceRankingSettings()
end

function BSCARI:CreateAllianceRankingSettingsCheckbox(parent, key, text, y)
    local controlName = "BSCARIAllianceRankingSettings" .. key
    local control = WINDOW_MANAGER:CreateControlFromVirtual(controlName, parent, "ZO_Options_Checkbox")
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, 10, y)
    control:SetDimensions(520, 28)

    control.data =
    {
        enabled = true,
        text = text,
    }

    control.checkbox = GetControl(control, "Checkbox")
    control.nameLabel = GetControl(control, "Name")

    if control.nameLabel then
        control.nameLabel:SetText(text)
        control.nameLabel:SetMouseEnabled(true)
        control.nameLabel:SetHandler("OnMouseUp", function()
            local current = control.checkbox and ZO_CheckButton_IsChecked(control.checkbox)
            local newValue = not current
            if control.checkbox then
                ZO_CheckButton_SetCheckState(control.checkbox, newValue)
            end
            self:ApplyAllianceRankingSetting(key, newValue)
        end)
    end

    if control.checkbox then
        control.checkbox:SetHandler("OnMouseUp", function()
            self:ApplyAllianceRankingSetting(key, ZO_CheckButton_IsChecked(control.checkbox))
        end)
    end

    control.settingKey = key
    return control
end

function BSCARI:CreateAllianceRankingSettingsHeader(parent, text, y)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, y)
    label:SetDimensions(520, 28)
    label:SetFont("ZoFontWinH3")
    label:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
    label:SetText(text)
    return label
end

function BSCARI:CreateAllianceRankingSettingsButton(parent, text, x, y, width, callback)
    local button = WINDOW_MANAGER:CreateControlFromVirtual(nil, parent, "ZO_DefaultButton")
    button:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    button:SetDimensions(width, 32)
    button:SetText(text)
    button:SetHandler("OnClicked", callback)
    return button
end

function BSCARI:CreateAllianceRankingSettingsSlider(parent, rowData, y)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, 10, y)
    label:SetDimensions(260, 28)
    label:SetFont("ZoFontWinH4")
    label:SetText(rowData.text)

    local slider = WINDOW_MANAGER:CreateControl(nil, parent, CT_SLIDER)
    slider:SetAnchor(TOPLEFT, parent, TOPLEFT, 275, y + 4)
    slider:SetDimensions(210, 20)
    slider:SetOrientation(ORIENTATION_HORIZONTAL)
    slider:SetMinMax(rowData.min, rowData.max)
    slider:SetValueStep(rowData.step or 1)

    local valueLabel = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    valueLabel:SetAnchor(LEFT, slider, RIGHT, 10, 0)
    valueLabel:SetDimensions(80, 24)
    valueLabel:SetFont("ZoFontWinH4")

    local control = { slider = slider, label = label, valueLabel = valueLabel, rowData = rowData, settingKey = rowData.key }
    slider:SetHandler("OnValueChanged", function(_, value)
        local settings = self:GetCurrentCharacterSettings()
        if not settings then return end

        local step = rowData.step or 1
        local roundedValue = zo_round(value / step) * step
        roundedValue = ClampNumber(roundedValue, rowData.min, rowData.max, rowData.min)
        settings[rowData.key] = roundedValue

        if valueLabel then
            valueLabel:SetText(tostring(roundedValue) .. (rowData.suffix or ""))
        end

        self:ApplyHudBarAppearance()
    end)

    return control
end

function BSCARI:CreateAllianceRankingSettingsColor(parent, rowData, y)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, 10, y)
    label:SetDimensions(260, 28)
    label:SetFont("ZoFontWinH4")
    label:SetText(rowData.text)

    local swatch = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
    swatch:SetAnchor(TOPLEFT, parent, TOPLEFT, 275, y + 2)
    swatch:SetDimensions(48, 24)
    swatch:SetCenterColor(1, 1, 1, 1)
    swatch:SetEdgeColor(1, 1, 1, 0.75)
    swatch:SetMouseEnabled(true)

    local button = WINDOW_MANAGER:CreateControlFromVirtual(nil, parent, "ZO_DefaultButton")
    button:SetAnchor(LEFT, swatch, RIGHT, 10, 0)
    button:SetDimensions(120, 28)
    button:SetText("Change")

    local control = { label = label, swatch = swatch, button = button, settingKey = rowData.key, rowData = rowData }
    local function OpenColorPicker()
        local settings = self:GetCurrentCharacterSettings()
        if not settings then return end

        local defaultColor = self.DefaultCharacterSettings[rowData.key] or { r = 1, g = 1, b = 1, a = 1 }
        local color = GetColorTableValue(settings, rowData.key, defaultColor)

        if COLOR_PICKER then
            COLOR_PICKER:Show(function(r, g, b, a)
                settings[rowData.key] = { r = r, g = g, b = b, a = a or 1 }
                self:RefreshAllianceRankingSettings()
                self:ApplyHudBarAppearance()
            end, color.r, color.g, color.b, color.a or 1)
        end
    end

    swatch:SetHandler("OnMouseUp", OpenColorPicker)
    button:SetHandler("OnClicked", OpenColorPicker)

    return control
end

function BSCARI:CreateAllianceRankingSettingsStepper(parent, rowData, y)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, 10, y)
    label:SetDimensions(260, 28)
    label:SetFont("ZoFontWinH4")
    label:SetText(rowData.text)

    local minusButton = WINDOW_MANAGER:CreateControlFromVirtual(nil, parent, "ZO_DefaultButton")
    minusButton:SetAnchor(TOPLEFT, parent, TOPLEFT, 275, y)
    minusButton:SetDimensions(46, 28)
    minusButton:SetText("-")

    local valueLabel = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    valueLabel:SetAnchor(LEFT, minusButton, RIGHT, 8, 0)
    valueLabel:SetDimensions(62, 28)
    valueLabel:SetFont("ZoFontWinH4")
    valueLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local plusButton = WINDOW_MANAGER:CreateControlFromVirtual(nil, parent, "ZO_DefaultButton")
    plusButton:SetAnchor(LEFT, valueLabel, RIGHT, 8, 0)
    plusButton:SetDimensions(46, 28)
    plusButton:SetText("+")

    local control = { stepper = true, label = label, minusButton = minusButton, plusButton = plusButton, valueLabel = valueLabel, rowData = rowData, settingKey = rowData.key }

    local function ChangeValue(delta)
        local settings = self:GetCurrentCharacterSettings()
        if not settings then return end

        local step = rowData.step or 1
        local currentValue = ClampNumber(settings[rowData.key], rowData.min, rowData.max, rowData.min)
        local newValue = ClampNumber(currentValue + (delta * step), rowData.min, rowData.max, rowData.min)
        settings[rowData.key] = newValue
        SetSettingsStepperVisual(control, settings)
        self:ApplyHudBarAppearance()
    end

    minusButton:SetHandler("OnClicked", function() ChangeValue(-1) end)
    plusButton:SetHandler("OnClicked", function() ChangeValue(1) end)

    return control
end

function BSCARI:ResetAllianceRankingHudPositions()
    local settings = self:GetCurrentCharacterSettings()
    if not settings then return end

    settings.offsetX = 0
    settings.offsetY = 0
    settings.ARO_X = 0
    settings.ARO_Y = 0
    settings.CRO_X = 0
    settings.CRO_Y = 0
    settings.TRO_X = 0
    settings.TRO_Y = 0
    settings.VRO_X = 0
    settings.VRO_Y = 0
    settings.VCO_X = 0
    settings.VCO_Y = 0

    if BSCAllianceRankingBuffInfoUI then
        BSCAllianceRankingBuffInfoUI:ClearAnchors()
        BSCAllianceRankingBuffInfoUI:SetAnchor(RIGHT, GuiRoot, RIGHT, 0, 100)
    end

    if self.BARframes then
        local defaultY = 590
        for index, frame in pairs(self.BARframes) do
            if frame then
                frame:ClearAnchors()
                frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 600, defaultY + ((index - 1) * 90))
            end
        end
    end
end

function BSCARI:RefreshAllianceRankingSettingsScroll()
    local content = self._settingsContent
    if not content then return end

    local contentHeight = self._settingsContentHeight or 0
    content:SetDimensions(760, contentHeight)

    if self._settingsScrollChild then
        self._settingsScrollChild:SetDimensions(760, contentHeight)
    end
end

function BSCARI:ScrollAllianceRankingSettings(delta)
    -- Scrolling is handled by the native ZO_ScrollContainerBase in the settings XML.
end

function BSCARI:InitializeAllianceRankingSettings()
    local parent = self.ALLIANCE_RANKINGVIEW_SETTINGS
    if not parent or self._settingsInitialized then return end

    parent:SetMouseEnabled(true)
    self._settingsRows = {}

    local title = parent:GetNamedChild("Title")
    if title then
        title:SetText("BSCs-AllianceRanking Settings")
    end

    local character = parent:GetNamedChild("Character")
    self._settingsCharacterLabel = character

    local panel = parent:GetNamedChild("Panel")
    self._settingsPanel = panel
    if panel then
        panel:SetCenterColor(0, 0, 0, 0)
        panel:SetEdgeColor(0, 0, 0, 0)
    end

    local parentName = parent:GetName()
    self._settingsScrollChild = GetControl(parentName .. "PanelScrollChild")
    local content = GetControl(parentName .. "PanelScrollChildContent")
    if not content then
        content = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
        content:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 68)
    end
    self._settingsContent = content

    local y = 0
    for _, row in ipairs(BSCARI_SETTINGS_ROWS) do
        if row.type == "header" then
            self:CreateAllianceRankingSettingsHeader(content, row.text, y)
            y = y + 34
        elseif row.type == "slider" then
            local slider = self:CreateAllianceRankingSettingsSlider(content, row, y)
            self._settingsRows[row.key] = slider
            y = y + 34
        elseif row.type == "stepper" then
            local stepper = self:CreateAllianceRankingSettingsStepper(content, row, y)
            self._settingsRows[row.key] = stepper
            y = y + 34
        elseif row.type == "color" then
            local color = self:CreateAllianceRankingSettingsColor(content, row, y)
            self._settingsRows[row.key] = color
            y = y + 34
        else
            local checkbox = self:CreateAllianceRankingSettingsCheckbox(content, row.key, row.text, y)
            self._settingsRows[row.key] = checkbox
            y = y + 30
        end
    end

    y = y + 8
    self._settingsContentHeight = y

    local previewButton = parent:GetNamedChild("PreviewBuffUI")
    if previewButton then
        previewButton:SetText("Preview Buff UI")
        previewButton:SetHandler("OnClicked", function()
            self._settingsPreviewActive = true
            if self.RefreshBuffInfoNow then
                self:RefreshBuffInfoNow()
            end
            self:RefreshBuffInfoVisibility()
        end)
    end

    local resetButton = parent:GetNamedChild("ResetHUDPositions")
    if resetButton then
        resetButton:SetText("Reset HUD Positions")
        resetButton:SetHandler("OnClicked", function()
            self:ResetAllianceRankingHudPositions()
            self:RefreshAllianceRankingSettings()
        end)
    end

    local donateButton = parent:GetNamedChild("Donate")
    if donateButton then
        donateButton:SetText("Donate")
        donateButton:SetHandler("OnClicked", function()
            local function PrefillMail()
                ZO_MailSendToField:SetText(self.Author)
                ZO_MailSendSubjectField:SetText(self.NameSpaced)
                ZO_MailSendBodyField:TakeFocus()
            end
            SCENE_MANAGER:Show("mailSend")
            zo_callLater(PrefillMail, 250)
        end)
    end

    self._settingsInitialized = true
    self:RefreshAllianceRankingSettings()
    self:RefreshAllianceRankingSettingsScroll()
end

function BSCARI:RefreshAllianceRankingSettings()
    if not self._settingsInitialized then return end

    local settings = self:GetCurrentCharacterSettings()
    if not settings then return end

    if self._settingsCharacterLabel then
        self._settingsCharacterLabel:SetText("Character: " .. GetCurrentCharacterDisplayName())
    end

    for key, control in pairs(self._settingsRows or {}) do
        if control.slider then
            SetSettingsSliderVisual(control, settings)
        elseif control.stepper then
            SetSettingsStepperVisual(control, settings)
        elseif control.swatch then
            SetSettingsColorVisual(control, settings)
        else
            SetSettingsCheckboxVisual(control, settings[key] == true)
        end
    end

    self:RefreshAllianceRankingSettingsScroll()
end

function BSCARI:InitializeAllianceRankingView(control)
    self.ALLIANCE_RANKINGVIEW_CONTROL = control
    self.ALLIANCE_RANKINGVIEW_CONTENT = control:GetNamedChild("Content")
    self.ALLIANCE_RANKINGVIEW_METERS = control:GetNamedChild("Meters")
    self.ALLIANCE_RANKINGVIEW_SETTINGS = control:GetNamedChild("Settings")
    self.ALLIANCE_RANKINGVIEW_FRAGMENT = ZO_FadeSceneFragment:New(control)
    self:SetupAllianceRankingMeters()
    self:InitializeAllianceRankingSettings()

    local navigation = control:GetNamedChild("Navigation")
    self._allianceRankingSubTabButtons =
    {
        [BSCARI_SUBTAB_SETTINGS] = navigation:GetNamedChild("Settings"),
        [BSCARI_SUBTAB_TIER] = navigation:GetNamedChild("CharTierInfo"),
        [BSCARI_SUBTAB_AP] = navigation:GetNamedChild("APRanking"),
        [BSCARI_SUBTAB_PVP_STYLES] = navigation:GetNamedChild("PvPStyles"),
        [BSCARI_SUBTAB_VETERANCY] = navigation:GetNamedChild("VeterancyRanking"),
    }

    for tabKey, button in pairs(self._allianceRankingSubTabButtons) do
        button:SetText(BSCARI_SUBTAB_BUTTON_TEXT[tabKey])
        button:SetHandler("OnClicked", function()
            self:SelectAllianceRankingSubTab(tabKey)
        end)
    end

    self.ALLIANCE_RANKINGVIEW_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_FRAGMENT_SHOWING then
            self._allianceRankingViewVisible = true
            self:AttachAllianceRankingSubViews()
            self:RequestCampaignLeaderboardData("bscar-view-show", false, true)
            self:RefreshAllianceRankingMeters()
            self:SelectAllianceRankingSubTab(self._selectedAllianceRankingSubTab or BSCARI_SUBTAB_TIER)
        elseif newState == SCENE_FRAGMENT_HIDING or newState == SCENE_FRAGMENT_HIDDEN then
            self._allianceRankingViewVisible = false
            self._settingsPreviewActive = false
            self:HideAllianceRankingSubViews()
            self:RefreshBuffInfoVisibility()
        end
    end)
end

function BSCARI:AttachAllianceRankingSubViews()
    local content = self.ALLIANCE_RANKINGVIEW_CONTENT
    if not content then return end

    local views =
    {
        CampaignTierView,
        CampaignAPView,
        CampaignPvPStylesView,
        CampaignVeterancyView,
    }

    for _, control in ipairs(views) do
        if control and not control._bscarAllianceRankingAttached then
            AnchorControlFill(control, content)
            control:SetHidden(true)
            control._bscarAllianceRankingAttached = true
        end
    end
end

function BSCARI:RefreshAllianceRankingSubTab(tabKey)
    if tabKey == BSCARI_SUBTAB_SETTINGS then
        self:RefreshAllianceRankingSettings()
    elseif tabKey == BSCARI_SUBTAB_TIER then
        if self.ALLIANCE_TIERVIEW and self.ALLIANCE_TIERVIEW.Refresh then
            self.ALLIANCE_TIERVIEW:Refresh()
        elseif self.UpdateCharData then
            self:UpdateCharData()
        end
    elseif tabKey == BSCARI_SUBTAB_AP then
        if self.ALLIANCE_POINTSVIEW and self.ALLIANCE_POINTSVIEW.Refresh then
            self.ALLIANCE_POINTSVIEW:Refresh()
        end
    elseif tabKey == BSCARI_SUBTAB_PVP_STYLES then
        if self.ALLIANCE_PVPSTYLEVIEW and self.ALLIANCE_PVPSTYLEVIEW.Refresh then
            self.ALLIANCE_PVPSTYLEVIEW:Refresh()
        end
    elseif tabKey == BSCARI_SUBTAB_VETERANCY then
        if self.ALLIANCE_VETERANCYVIEW and self.ALLIANCE_VETERANCYVIEW.Refresh then
            self.ALLIANCE_VETERANCYVIEW:Refresh()
        end
    end
end

function BSCARI:UpdateAllianceRankingSubTabButtons(selectedTab)
    if not self._allianceRankingSubTabButtons then return end

    for tabKey, button in pairs(self._allianceRankingSubTabButtons) do
        local text = BSCARI_SUBTAB_BUTTON_TEXT[tabKey]
        if tabKey == selectedTab then
            button:SetText("|cE9C62A> " .. text .. "|r")
        else
            button:SetText(text)
        end
    end
end

function BSCARI:SelectAllianceRankingSubTab(tabKey)
    if tabKey ~= BSCARI_SUBTAB_SETTINGS and tabKey ~= BSCARI_SUBTAB_TIER and tabKey ~= BSCARI_SUBTAB_AP and tabKey ~= BSCARI_SUBTAB_PVP_STYLES and tabKey ~= BSCARI_SUBTAB_VETERANCY then
        tabKey = BSCARI_SUBTAB_TIER
    end

    self:AttachAllianceRankingSubViews()

    local controls =
    {
        [BSCARI_SUBTAB_SETTINGS] = self.ALLIANCE_RANKINGVIEW_SETTINGS,
        [BSCARI_SUBTAB_TIER] = CampaignTierView,
        [BSCARI_SUBTAB_AP] = CampaignAPView,
        [BSCARI_SUBTAB_PVP_STYLES] = CampaignPvPStylesView,
        [BSCARI_SUBTAB_VETERANCY] = CampaignVeterancyView,
    }

    for key, control in pairs(controls) do
        if control then
            control:SetHidden(key ~= tabKey)
        end
    end

    self._selectedAllianceRankingSubTab = tabKey
    if tabKey ~= BSCARI_SUBTAB_SETTINGS then
        self._settingsPreviewActive = false
    end
    self:UpdateAllianceRankingSubTabButtons(tabKey)
    self:RefreshAllianceRankingSubTab(tabKey)
    self:RefreshAllianceRankingMeters()
    self:RefreshBuffInfoVisibility()
    self:UpdateRotW()
end

function BSCARI_AllianceRankingView_OnInitialized(control)
    BSCAllianceRanking:InitializeAllianceRankingView(control)
end

function BSCARI:ShowCampaignOverviewFragment(fragment)
    if CAMPAIGN_OVERVIEW and CAMPAIGN_OVERVIEW.RemoveAllCategoryFragments then
        CAMPAIGN_OVERVIEW:RemoveAllCategoryFragments()
    else
        RemoveBSCARICampaignFragments()
    end

    RemoveBSCARICampaignFragments()

    if CAMPAIGN_OVERVIEW and CAMPAIGN_OVERVIEW.ShowCampaignSelector then
        CAMPAIGN_OVERVIEW:ShowCampaignSelector()
    end

    if fragment and CAMPAIGN_OVERVIEW_SCENE then
        CAMPAIGN_OVERVIEW_SCENE:AddFragment(fragment)
    end

    self:UpdateRotW()
end

function BSCARI:RegisterCampaignOverviewCategories()
    if self._campaignOverviewCategoriesRegistered then
        return true
    end

    if not ZO_CAMPAIGN_OVERVIEW_TYPE_INFO or not CAMPAIGN_OVERVIEW or not CAMPAIGN_OVERVIEW_SCENE then
        return false
    end

    ZO_CAMPAIGN_OVERVIEW_TYPE_INFO[CAMPAIGN_OVERVIEW_TYPE_BSCARI_AP_RANKING] =
    {
        name = "AP Ranking",
        normalIcon = BSCARI_CAMPAIGN_ICON.normal,
        pressedIcon = BSCARI_CAMPAIGN_ICON.pressed,
        mouseoverIcon = BSCARI_CAMPAIGN_ICON.mouseover,
        priority = 14,
        categoryFragment = self.ALLIANCE_POINTSVIEW_FRAGMENT,
        categoryFragmentFunction = function()
            self:ShowCampaignOverviewFragment(self.ALLIANCE_POINTSVIEW_FRAGMENT)
        end,
    }

    ZO_CAMPAIGN_OVERVIEW_TYPE_INFO[CAMPAIGN_OVERVIEW_TYPE_BSCARI_TIER_INFO] =
    {
        name = "Char Tier Info",
        normalIcon = BSCARI_CAMPAIGN_ICON.normal,
        pressedIcon = BSCARI_CAMPAIGN_ICON.pressed,
        mouseoverIcon = BSCARI_CAMPAIGN_ICON.mouseover,
        priority = 15,
        categoryFragment = self.ALLIANCE_TIERVIEW_FRAGMENT,
        categoryFragmentFunction = function()
            self:ShowCampaignOverviewFragment(self.ALLIANCE_TIERVIEW_FRAGMENT)
        end,
    }

    if CAMPAIGN_OVERVIEW.RemoveAllCategoryFragments and not self._campaignOverviewRemoveHookInstalled then
        ZO_PostHook(CAMPAIGN_OVERVIEW, "RemoveAllCategoryFragments", RemoveBSCARICampaignFragments)
        self._campaignOverviewRemoveHookInstalled = true
    end

    self._campaignOverviewCategoriesRegistered = true

    if CAMPAIGN_OVERVIEW.RefreshCategories then
        CAMPAIGN_OVERVIEW:RefreshCategories()
    end

    return true
end

-- Legacy wrapper names kept for slash/debug compatibility.
function BSCARI:HookInitializeCategories() -- /script BSCAllianceRanking:HookInitializeCategories()
    return self:RegisterCampaignOverviewCategories()
end

function BSCARI:HookRefreshCategories() -- /script BSCAllianceRanking:HookRefreshCategories()
    if CAMPAIGN_OVERVIEW and CAMPAIGN_OVERVIEW.RefreshCategories then
        CAMPAIGN_OVERVIEW:RefreshCategories()
        return true
    end

    return false
end

function BSCARI:HookChangeCategory()
    RemoveBSCARICampaignFragments()
    self:UpdateRotW()
end

function BSCARI:PlayAnnounce(text)
	CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATEGORY_LARGE_TEXT, SOUNDS.LEVEL_UP, "Alliance Reward", zo_strformat("<<1>> ", text), "/esoui/art/icons/achievement_battlegrounds_001.dds", "EsoUI/Art/Achievements/achievements_iconBG.dds", nil, nil, 4000)
end
-------------------------------------------------------------------------------------------------
-- Tier/AP Controls 
-------------------------------------------------------------------------------------------------
local function CreateControls()
	local fontSize = 18
	local fontStyle = ZoFontGame:GetFontInfo()
	local fontWeight = "soft-shadow-thin"
	local font = string.format("%s|$(KB_%s)|%s", fontStyle, fontSize, fontWeight)
	
	local parentStatusbar = ZO_CampaignScoringTierProgressStatusBar
	BSCARI.TierInfoLabel = WINDOW_MANAGER:CreateControl(nil, parentStatusbar, CT_LABEL)
	BSCARI.TierInfoLabel:SetAnchor(CENTER, parentStatusbar, CENTER, 0, 20) 
	BSCARI.TierInfoLabel:SetFont(font)
	
	local parentRankingBar = ZO_CampaignAvARankXPBar	
	--
	BSCARI.APBarControl = WINDOW_MANAGER:CreateControlFromVirtual("TestAPBar", parentRankingBar, "ZO_ArrowStatusBarWithBG")
	BSCARI.APInfoBar = ZO_WrappingStatusBar:New(BSCARI.APBarControl)
	ZO_StatusBar_SetGradientColor(BSCARI.APBarControl, ZO_AVA_RANK_GRADIENT_COLORS)	
	BSCARI.APBarControl:SetAnchor(LEFT, parentRankingBar, RIGHT, 20, 0) 
	--
	BSCARI.APInfoLable = WINDOW_MANAGER:CreateControl(nil, BSCARI.APBarControl, CT_LABEL)
	BSCARI.APInfoLable:SetAnchor(CENTER, BSCARI.APBarControl, CENTER, 0, 20) 
	BSCARI.APInfoLable:SetFont(font)
	-- 
	BSCARI.CurrentAPInfoLable = WINDOW_MANAGER:CreateControl(nil, parentRankingBar, CT_LABEL)
	BSCARI.CurrentAPInfoLable:SetAnchor(CENTER, parentRankingBar, CENTER, 0, 20) 
	BSCARI.CurrentAPInfoLable:SetFont(font)
	
	-- Lable RotW
	BSCARI.RotWLable = WINDOW_MANAGER:CreateControl(nil, BSCARI.APBarControl, CT_LABEL)
	BSCARI.RotWLable:SetAnchor(LEFT, BSCARI.APBarControl, RIGHT, 10, 10) 
	BSCARI.RotWLable:SetFont(font)	
		
	-- Test Button
	BSCARI.ButtonAlert = WINDOW_MANAGER:CreateControlFromVirtual(nil, parentStatusbar, "ZO_DefaultButton")
    BSCARI.ButtonAlert:SetAnchor(LEFT, parentStatusbar, RIGHT, 0, 30)
    BSCARI.ButtonAlert:SetWidth(100)
    BSCARI.ButtonAlert:SetText("Test Alert")
    BSCARI.ButtonAlert:SetHandler("OnClicked", function() 		
		local currentTier, nextTierProgress, nextTierTotal = GetPlayerCampaignRewardTierInfo(GetAssignedCampaignId())
		local info = "["..currentTier.."/3] Points to next [" .. ZO_CommaDelimitDecimalNumber(nextTierProgress).."/"..ZO_CommaDelimitDecimalNumber(nextTierTotal).."]"
		if currentTier == 3 then
			info = "["..currentTier.."/3] Max Alliance Tier Level Reached!"
		end
		BSCARI:PlayAnnounce(info)		
	end)
	-- CheckBox
	BSCARI.CheckBoxAlert = WINDOW_MANAGER:CreateControlFromVirtual(nil, parentStatusbar, "ZO_Options_Checkbox")
	BSCARI.CheckBoxAlert.data = { }
	BSCARI.CheckBoxAlert.data.enabled = true
	BSCARI.CheckBoxAlert.data.text = "Tier Alert"
	BSCARI.CheckBoxAlert.data.tooltipText = "Show Alert every Tier you reach!"
	
    BSCARI.CheckBoxAlert:SetAnchor(LEFT, parentStatusbar, RIGHT, 15, 0)	
	BSCARI.CheckBoxAlert:SetWidth(300)
		
	local lblNameControl = GetControl(BSCARI.CheckBoxAlert, "Name")
	lblNameControl:SetText(BSCARI.CheckBoxAlert.data.text);
	if BSCARI.SVA.SETTING[BSCARI.CurrentCharID].bAlert then 
		lblNameControl:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
	else
		lblNameControl:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
	end	
	
	BSCARI.CboxControl = GetControl(BSCARI.CheckBoxAlert, "Checkbox")
	ZO_CheckButton_SetCheckState(BSCARI.CboxControl, BSCARI.SVA.SETTING[BSCARI.CurrentCharID].bAlert)				
    BSCARI.CboxControl:SetHandler("OnMouseUp", function(checkboxControl)	
		local NameControl = GetControl(BSCARI.CheckBoxAlert, "Name")	
		if ZO_CheckButton_IsChecked(checkboxControl) then
			BSCARI.SVA.SETTING[BSCARI.CurrentCharID].bAlert = true
			NameControl:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
		else
			BSCARI.SVA.SETTING[BSCARI.CurrentCharID].bAlert = false
			NameControl:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
		end
	end)
    BSCARI.CboxControl:SetHandler("OnMouseExit", function(checkboxControl)	
		ClearTooltip(InformationTooltip)		
		local NameControl = GetControl(BSCARI.CheckBoxAlert, "Name")
		if ZO_CheckButton_IsChecked(checkboxControl) then
			NameControl:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
		else
			NameControl:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
		end
	end)
	
	BSCARI.CheckBoxAlert:SetHandler("OnMouseUp", function(control) 
		local NameControl = GetControl(control, "Name")	
		local checkboxControl = GetControl(control, "Checkbox")
		ZO_CheckButton_OnClicked(checkboxControl)
		if ZO_CheckButton_IsChecked(checkboxControl) then
			BSCARI.SVA.SETTING[BSCARI.CurrentCharID].bAlert = true
			NameControl:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
		else
			BSCARI.SVA.SETTING[BSCARI.CurrentCharID].bAlert = false
			NameControl:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
		end		
	end)
    BSCARI.CheckBoxAlert:SetHandler("OnMouseExit", function(control) 
		ClearTooltip(InformationTooltip)		
		local NameControl = GetControl(control, "Name")		
		local checkboxControl = GetControl(control, "Checkbox")			
		if ZO_CheckButton_IsChecked(checkboxControl) then
			NameControl:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
		else
			NameControl:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
		end
	end)
	-- end checkox
end

local CURRENT_TIER = 0 -- 0 = unbekannt, 1–3 = Fortschritt
local AP_TIER_ALERT_SESSION_INITIALIZED = false

local function GetCampaignExpireTime(campaignId)
    if not campaignId or campaignId <= 0 or not GetSecondsUntilCampaignEnd then
        return 0
    end

    local secondsUntilEnd = GetSecondsUntilCampaignEnd(campaignId) or 0
    if secondsUntilEnd <= 0 then
        return 0
    end

    return os.time() + secondsUntilEnd
end

local function GetRewardTierAlertState(campaignId, currentTier)
    local settings = BSCARI:GetCurrentCharacterSettings()
    if not settings or not campaignId or campaignId <= 0 then
        return nil
    end

    settings.AP_TIER_ALERT_STATE = settings.AP_TIER_ALERT_STATE or {}

    local state = settings.AP_TIER_ALERT_STATE
    local now = os.time()
    local expireTime = GetCampaignExpireTime(campaignId)
    local savedTier = tonumber(state.lastTier) or 0
    local savedExpireTime = tonumber(state.expireTime) or 0

    local shouldReset = false
    if state.campaignId ~= campaignId then
        shouldReset = true
    elseif savedExpireTime > 0 and savedExpireTime <= now then
        shouldReset = true
    elseif currentTier < savedTier then
        -- Same campaign id can be reused by ESO after reset. A lower tier means the
        -- campaign reward progress was reset, so this becomes the new baseline.
        shouldReset = true
    end

    if shouldReset then
        state.campaignId = campaignId
        state.expireTime = expireTime
        state.lastTier = currentTier or 0
        state.lastUpdated = now
        return state, true
    end

    state.campaignId = campaignId
    state.expireTime = expireTime
    return state, false
end

local function CheckRewardTierAlert(campaignId, currentTier, nextTierProgress, nextTierTotal)
    local settings = BSCARI:GetCurrentCharacterSettings()
    if not settings or not settings.bAlert then
        return
    end

    if not campaignId or campaignId <= 0 or campaignId ~= GetCurrentCampaignId() then
        return
    end

    local state = GetRewardTierAlertState(campaignId, currentTier)
    if not state then
        return
    end

    -- First update after login is only the baseline. This prevents an alert when the
    -- character logs in while already sitting at reward tier 3.
    if not AP_TIER_ALERT_SESSION_INITIALIZED then
        state.lastTier = currentTier or 0
        state.lastUpdated = os.time()
        AP_TIER_ALERT_SESSION_INITIALIZED = true
        return
    end

    local previousTier = tonumber(state.lastTier) or 0
    if currentTier > previousTier then
        local info = "["..currentTier.."/3] Points to next [" .. ZO_CommaDelimitDecimalNumber(nextTierProgress or 0).."/"..ZO_CommaDelimitDecimalNumber(nextTierTotal or 0).."]"
        if currentTier == 3 then
            info = "["..currentTier.."/3] Max Alliance Tier Level Reached!"
        end
        BSCARI:PlayAnnounce(info)
    end

    state.lastTier = currentTier or 0
    state.lastUpdated = os.time()
end

local function UpdateRewardTier()
	local currentTier, nextTierProgress, nextTierTotal = GetPlayerCampaignRewardTierInfo(GetAssignedCampaignId())
	local info = " [" ..zo_strformat(SI_NUMBER_FORMAT, nextTierProgress).."/"..zo_strformat(SI_NUMBER_FORMAT, nextTierTotal).."]"	
	local color = "|cb30000"	
	if currentTier == 1 then
		color = "|cff9933" 
	elseif currentTier == 2 then
		color = "|cfcd25d" 
	elseif currentTier == 3 then
		color = "|c00b300" 
		info = " Max Tier Reached!"
	end
	--	
	CURRENT_TIER = currentTier
	BSCARI.TierInfoLabel:SetText(color.." [" .. currentTier .. "/3]"..info.." |r " )
	-- UI
	if currentTier == 3 then
		BSCARI.BARframes[3]:GetNamedChild("Bar"):SetMinMax(0, 100)
		BSCARI.BARframes[3]:GetNamedChild("Bar"):SetValue(100)
	else		
		BSCARI.BARframes[3]:GetNamedChild("Bar"):SetMinMax(0, nextTierTotal)
		BSCARI.BARframes[3]:GetNamedChild("Bar"):SetValue(nextTierProgress)
	end
	BSCARI.BARframes[3]:GetNamedChild("Info"):SetText(color.." [" .. currentTier .. "/3]"..info.." |r " )	
	
	if GetAssignedCampaignId() == GetCurrentCampaignId() then
		CheckRewardTierAlert(GetAssignedCampaignId(), currentTier, nextTierProgress, nextTierTotal)
	end	
	BSCARI:UpdateCharData()
end
local MAX_AVA_RANK = 50

local function GetMaxAvARankPoints()
    local points = GetNumPointsNeededForAvARank(MAX_AVA_RANK)
    if type(points) == "number" and points > 0 then
        return points
    end

    return 64680000
end

local function GetCurrentRankProgress()
    local rankPoints = GetUnitAvARankPoints("player")
    local _, _, rankStartsAt, nextRankAt = GetAvARankProgress(rankPoints)
    if rankPoints >= nextRankAt then
        local rank = GetUnitAvARank("player")
        local lastRankPoints = GetNumPointsNeededForAvARank(rank - 1)
        local maxRankPoints = GetNumPointsNeededForAvARank(rank)
        local fullRankPoints = maxRankPoints - lastRankPoints
        return fullRankPoints, fullRankPoints
    else
        return rankPoints - rankStartsAt, nextRankAt - rankStartsAt
    end
end
local function SafeFormatNumber(value)
    return zo_strformat(SI_NUMBER_FORMAT, type(value) == "number" and value or 0)
end

local function SetMeterValue(bar, currentValue, maxValue)
    if not bar then return end

    currentValue = type(currentValue) == "number" and currentValue or 0
    maxValue = type(maxValue) == "number" and maxValue or 0
    if maxValue <= 0 then
        maxValue = 1
    end

    bar:SetMinMax(0, maxValue)
    bar:SetValue(zo_min(currentValue, maxValue))
end

local MAX_DISPLAY_VETERANCY_RANK = 100
local MAX_VETERANCY_PROGRESS_RANK = MAX_DISPLAY_VETERANCY_RANK - 1

local function GetVeterancyTotalProgressInfo()
    if not IsVeterancySeasonActive or not IsVeterancySeasonActive() then
        return nil
    end

    local trackType = REWARD_TRACK_TYPE_AVA_VETERANCY
    if not trackType or not GetActiveReferenceTrackIdsForRewardTrackType then
        return nil
    end

    local trackId = GetActiveReferenceTrackIdsForRewardTrackType(trackType)
    if not trackId or trackId == 0 then
        return nil
    end

    local rewardTrackId = GetRewardTrackIdFromReferenceTrackId(trackType, trackId)
    local trackIndex = GetReferenceTrackIndex(trackType, trackId)
    if not rewardTrackId or rewardTrackId == 0 or not trackIndex then
        return nil
    end

    local _, currentRank, currentProgress = GetInfoForRewardTrack(trackType, trackIndex)
    currentRank = type(currentRank) == "number" and currentRank or 0
    currentProgress = type(currentProgress) == "number" and currentProgress or 0

    local numBaseRanks = GetNumBaseTiersForRewardTrack(rewardTrackId)
    numBaseRanks = type(numBaseRanks) == "number" and numBaseRanks or 0
    local maxRank = zo_min(numBaseRanks, MAX_DISPLAY_VETERANCY_RANK)
    if maxRank <= 0 then
        return nil
    end

    local displayRank = zo_min(currentRank, maxRank)
    if displayRank < 0 then displayRank = 0 end

    local maxProgressRank = zo_min(MAX_VETERANCY_PROGRESS_RANK, maxRank - 1)
    local maxProgress = 0
    local currentTotal = 0
    local currentRankTotal = 0

    -- Rank 100 is the cap. Do not include rank 100 itself as another required tier,
    -- otherwise a player already at 100/100 still appears to need one more rank.
    for rank = 1, maxProgressRank do
        local tierProgress = GetTotalProgressAtRewardTrackTier(rewardTrackId, rank)
        tierProgress = type(tierProgress) == "number" and tierProgress or 0
        maxProgress = maxProgress + tierProgress

        if rank < currentRank then
            currentTotal = currentTotal + tierProgress
        elseif rank == currentRank then
            currentRankTotal = tierProgress
            currentTotal = currentTotal + zo_min(currentProgress, tierProgress)
        end
    end

    if currentRank >= maxRank then
        currentTotal = maxProgress
        currentRankTotal = 1
        currentProgress = 1
        displayRank = maxRank
    elseif maxProgress <= 0 then
        maxProgress = 1
        currentRankTotal = 1
        currentProgress = 0
    end

    return currentTotal, maxProgress, displayRank, maxRank, currentProgress, currentRankTotal
end

function BSCARI:RefreshVeterancyHudBars()
    if not self.BARframes then return end

    local totalFrame = self.BARframes[4]
    local currentFrame = self.BARframes[5]
    if not totalFrame and not currentFrame then return end

    local currentTotal, maxTotal, currentRank, maxRank, currentRankProgress, currentRankTotal = GetVeterancyTotalProgressInfo()

    if currentTotal and maxTotal and maxTotal > 0 then
        if totalFrame then
            local totalPercent = currentTotal / maxTotal * 100
            totalFrame:GetNamedChild("Bar"):SetMinMax(0, maxTotal)
            totalFrame:GetNamedChild("Bar"):SetValue(currentTotal)
            totalFrame:GetNamedChild("Info"):SetText(string.format("%.2f%% Completed [%s / %s]", totalPercent, SafeFormatNumber(currentTotal), SafeFormatNumber(maxTotal)))
            totalFrame:GetNamedChild("lbl"):SetText(string.format("Veterancy Total [%d / %d]", currentRank or 0, maxRank or 0))
        end

        if currentFrame then
            currentRankProgress = type(currentRankProgress) == "number" and currentRankProgress or 0
            currentRankTotal = type(currentRankTotal) == "number" and currentRankTotal or 0
            if currentRankTotal <= 0 then currentRankTotal = 1 end
            local currentPercent = currentRankProgress / currentRankTotal * 100
            currentFrame:GetNamedChild("Bar"):SetMinMax(0, currentRankTotal)
            currentFrame:GetNamedChild("Bar"):SetValue(zo_min(currentRankProgress, currentRankTotal))
            currentFrame:GetNamedChild("Info"):SetText(string.format("%.2f%% Completed [%s / %s]", currentPercent, SafeFormatNumber(currentRankProgress), SafeFormatNumber(currentRankTotal)))
            currentFrame:GetNamedChild("lbl"):SetText(string.format("Veterancy to Next Rank [%d / %d]", currentRank or 0, maxRank or 0))
        end
    else
        for _, frame in ipairs({ totalFrame, currentFrame }) do
            if frame then
                frame:GetNamedChild("Bar"):SetMinMax(0, 1)
                frame:GetNamedChild("Bar"):SetValue(0)
                frame:GetNamedChild("Info"):SetText("No active season")
            end
        end
    end
end

local function ResizeMeterChildren(meterControl, width)
    if not meterControl or not width or width <= 0 then return end

    local label = meterControl:GetNamedChild("Label")
    local bar = meterControl:GetNamedChild("Bar")
    local info = meterControl:GetNamedChild("Info")

    if label then label:SetWidth(width) end
    if bar then bar:SetWidth(width) end
    if info then info:SetWidth(width) end
end

function BSCARI:LayoutAllianceRankingMeters()
    local meters = self.ALLIANCE_RANKINGVIEW_METERS
    local ap = self.ALLIANCE_RANKINGVIEW_AP_METER
    local veterancy = self.ALLIANCE_RANKINGVIEW_VETERANCY_METER
    if not meters or not ap or not veterancy then return end

    local totalWidth = meters:GetWidth()
    if not totalWidth or totalWidth <= 0 then
        totalWidth = 1080
    end

    local gap = 22
    local meterHeight = 58
    local meterWidth = zo_floor((totalWidth - gap) / 2)
    if meterWidth < 250 then
        meterWidth = 250
    end

    ap:ClearAnchors()
    ap:SetAnchor(TOPLEFT, meters, TOPLEFT, 0, 0)
    ap:SetDimensions(meterWidth, meterHeight)
    ResizeMeterChildren(ap, meterWidth)

    veterancy:ClearAnchors()
    veterancy:SetAnchor(TOPRIGHT, meters, TOPRIGHT, 0, 0)
    veterancy:SetDimensions(meterWidth, meterHeight)
    ResizeMeterChildren(veterancy, meterWidth)
end

function BSCARI:SetupAllianceRankingMeters()
    local meters = self.ALLIANCE_RANKINGVIEW_METERS
    if not meters then return end

    local ap = meters:GetNamedChild("AP")
    local veterancy = meters:GetNamedChild("Veterancy")
    self.ALLIANCE_RANKINGVIEW_AP_METER = ap
    self.ALLIANCE_RANKINGVIEW_VETERANCY_METER = veterancy

    if ap then
        self.ALLIANCE_RANKINGVIEW_AP_BAR = ap:GetNamedChild("Bar")
        self.ALLIANCE_RANKINGVIEW_AP_INFO = ap:GetNamedChild("Info")
        self.ALLIANCE_RANKINGVIEW_AP_LABEL = ap:GetNamedChild("Label")
        if self.ALLIANCE_RANKINGVIEW_AP_BAR then
            ZO_StatusBar_SetGradientColor(self.ALLIANCE_RANKINGVIEW_AP_BAR, ZO_AVA_RANK_GRADIENT_COLORS)
        end
    end

    if veterancy then
        self.ALLIANCE_RANKINGVIEW_VETERANCY_BAR = veterancy:GetNamedChild("Bar")
        self.ALLIANCE_RANKINGVIEW_VETERANCY_INFO = veterancy:GetNamedChild("Info")
        self.ALLIANCE_RANKINGVIEW_VETERANCY_LABEL = veterancy:GetNamedChild("Label")
        if self.ALLIANCE_RANKINGVIEW_VETERANCY_BAR then
            self.ALLIANCE_RANKINGVIEW_VETERANCY_BAR:SetColor(0, 0.85, 0.85, 1)
        end
    end

    self:LayoutAllianceRankingMeters()
end

function BSCARI:RefreshAllianceRankingMeters()
    self:LayoutAllianceRankingMeters()
    if self.ALLIANCE_RANKINGVIEW_AP_BAR then
        local rankPoints = GetUnitAvARankPoints("player")
        local maxPoints = GetMaxAvARankPoints()
        local percent = maxPoints > 0 and (rankPoints / maxPoints * 100) or 0
        SetMeterValue(self.ALLIANCE_RANKINGVIEW_AP_BAR, rankPoints, maxPoints)
        if self.ALLIANCE_RANKINGVIEW_AP_LABEL then
            self.ALLIANCE_RANKINGVIEW_AP_LABEL:SetText("Alliance Rank")
        end
        if self.ALLIANCE_RANKINGVIEW_AP_INFO then
            self.ALLIANCE_RANKINGVIEW_AP_INFO:SetText(string.format("%.2f%% [%s / %s]", percent, SafeFormatNumber(rankPoints), SafeFormatNumber(maxPoints)))
        end
    end

    if self.ALLIANCE_RANKINGVIEW_VETERANCY_BAR then
        local currentProgress, maxProgress, currentRank, maxRank = GetVeterancyTotalProgressInfo()
        if currentProgress and maxProgress and maxProgress > 0 then
            local percent = currentProgress / maxProgress * 100
            SetMeterValue(self.ALLIANCE_RANKINGVIEW_VETERANCY_BAR, currentProgress, maxProgress)
            if self.ALLIANCE_RANKINGVIEW_VETERANCY_LABEL then
                self.ALLIANCE_RANKINGVIEW_VETERANCY_LABEL:SetText(string.format("Veterancy Rank %d / %d", currentRank or 0, maxRank or 0))
            end
            if self.ALLIANCE_RANKINGVIEW_VETERANCY_INFO then
                self.ALLIANCE_RANKINGVIEW_VETERANCY_INFO:SetText(string.format("%.2f%% [%s / %s]", percent, SafeFormatNumber(currentProgress), SafeFormatNumber(maxProgress)))
            end
        else
            SetMeterValue(self.ALLIANCE_RANKINGVIEW_VETERANCY_BAR, 0, 1)
            if self.ALLIANCE_RANKINGVIEW_VETERANCY_LABEL then
                self.ALLIANCE_RANKINGVIEW_VETERANCY_LABEL:SetText("Veterancy")
            end
            if self.ALLIANCE_RANKINGVIEW_VETERANCY_INFO then
                self.ALLIANCE_RANKINGVIEW_VETERANCY_INFO:SetText("No active season")
            end
        end
    end
end

local function AvARankRefresh()
	local rankPoints = GetUnitAvARankPoints("player")
	local max_points = GetMaxAvARankPoints()
	local percent = rankPoints / max_points * 100
	BSCARI.APInfoLable:SetText(string.format("%.4f%% Completed ["..zo_strformat(SI_NUMBER_FORMAT, rankPoints).." / "..zo_strformat(SI_NUMBER_FORMAT, max_points).."]", percent))
	BSCARI.APInfoBar:SetValue(0, rankPoints, max_points, true, true)	
	local APcurrent, APmax = GetCurrentRankProgress()
	local APPercent = APcurrent / APmax * 100
	BSCARI.CurrentAPInfoLable:SetText(string.format("%.2f%% Completed ["..zo_strformat(SI_NUMBER_FORMAT, APcurrent).." / "..zo_strformat(SI_NUMBER_FORMAT, APmax).."]", APPercent))
	-- UI		
	BSCARI.BARframes[1]:GetNamedChild("Bar"):SetMinMax(0, max_points)
	BSCARI.BARframes[1]:GetNamedChild("Bar"):SetValue(rankPoints)		
	BSCARI.BARframes[1]:GetNamedChild("Info"):SetText(string.format("%.1f%% Completed ["..zo_strformat(SI_NUMBER_FORMAT, rankPoints).." / "..zo_strformat(SI_NUMBER_FORMAT, max_points).."]", percent))
	
	BSCARI.BARframes[2]:GetNamedChild("Bar"):SetMinMax(0, APmax)
	BSCARI.BARframes[2]:GetNamedChild("Bar"):SetValue(APcurrent)	
	BSCARI.BARframes[2]:GetNamedChild("Info"):SetText(string.format("%.2f%% Completed ["..zo_strformat(SI_NUMBER_FORMAT, APcurrent).." / "..zo_strformat(SI_NUMBER_FORMAT, APmax).."]", APPercent))	
	local currentAvARank = GetUnitAvARank("player")
	BSCARI.BARframes[2]:GetNamedChild("lbl"):SetText("|t23:23:"..GetAvARankIcon(currentAvARank).."|t|r AP to Next Rank ["..tostring(currentAvARank).."/"..tostring(MAX_AVA_RANK).."] |t23:23:"..GetAvARankIcon(currentAvARank).."|t")	
	BSCARI:RefreshAllianceRankingMeters()
	BSCARI:RefreshVeterancyHudBars()
end
local icon = '|t16:16:/esoui/art/currency/alliancepoints.dds|t'
local APGain = 0
local AP_DelayedPrint = 0
local APR_DelayedPrint = 0
local function RankPointUpdate(_, unitTag, rankPoints, difference) 
	AvARankRefresh()
	BSCARI:UpdateCharData()
	if not BSCARI.SVA.SETTING[BSCARI.CurrentCharID].bAPInfoChat then return end	
	if unitTag == "player" then
		if APGain > 1000 then		
			local APG = zo_strformat(SI_NUMBER_FORMAT, APGain)
			local APD = zo_strformat(SI_NUMBER_FORMAT, difference)		
			d(zo_strformat("<<3>> |c31c441AP gain: |cffff66 <<1>> |c31c441APR gain: |cffff66 <<2>>", APG, APD, icon))
		else
			AP_DelayedPrint = AP_DelayedPrint + APGain
			APR_DelayedPrint = APR_DelayedPrint + difference
		end
				
		if AP_DelayedPrint > 1000 then
			local APG = zo_strformat(SI_NUMBER_FORMAT, AP_DelayedPrint)
			local APD = zo_strformat(SI_NUMBER_FORMAT, APR_DelayedPrint)		
			d(zo_strformat("<<3>> |c31c441AP gain: |cffff66 <<1>> |c31c441APR gain: |cffff66 <<2>> |c31c441(collected)", APG, APD, icon))
			AP_DelayedPrint = 0
			APR_DelayedPrint = 0
		end	
	end
end
local accumulatedAP = 0
local AP_THRESHOLD = 5000 -- request every 5k ap gain data
local function AlliancePointUpdate(eventCode, alliancePoints, playSound, difference, reason)	
	if difference > 0 then		
		APGain = difference	
		-- Only re-query while the player is in the assigned campaign and has not reached tier 3.
		-- Do not fake CURRENT_TIER locally; the server result from EVENT_CAMPAIGN_LEADERBOARD_DATA_RECEIVED is authoritative.
		if CURRENT_TIER < 3 and GetAssignedCampaignId() == GetCurrentCampaignId() then
			accumulatedAP = accumulatedAP + difference

			if accumulatedAP >= AP_THRESHOLD or difference >= 100000 then
				accumulatedAP = 0
				BSCARI:RequestCampaignLeaderboardData("ap-threshold") -- throttled
			end
		end		
	end
end
local function OnCombatState(_, inCombat)
	if not inCombat then	
		if AP_DelayedPrint > 0 then
			local APG = zo_strformat(SI_NUMBER_FORMAT, AP_DelayedPrint)
			local APD = zo_strformat(SI_NUMBER_FORMAT, APR_DelayedPrint)		
			CHAT_ROUTER:AddSystemMessage(zo_strformat("<<3>> |c31c441AP gain: |cffff66 <<1>> |c31c441APR gain: |cffff66 <<2>> |c31c441(collected)", APG, APD, icon))
			AP_DelayedPrint = 0
			APR_DelayedPrint = 0	
		end
	end
end
-------------------------------------------------------------------------------------------------
-- Low PoP Info Stuff
-------------------------------------------------------------------------------------------------
BSCARI.CAMPAIGN_IDS = { }
local LOWPOP_SCORE_EVENT_THROTTLE_MS = 30000
local lastLowPopEventAt = 0
local lastScoreEventAt = 0

local function ShouldSkipCampaignBonusEvent(lastEventAt)
    if not BSCARI.SVA or not BSCARI.CurrentCharID or not BSCARI.SVA.SETTING[BSCARI.CurrentCharID] then return true end
    if not BSCARI.SVA.SETTING[BSCARI.CurrentCharID].bAlertLowPop then return true end
    if BSCARI_IsInCyrodiil and not BSCARI_IsInCyrodiil() then return true end
    if BSCARI.IsAllianceWarUiShowing and BSCARI:IsAllianceWarUiShowing() then return true end

    local now = GetSafeGameTimeMilliseconds()
    if now > 0 and lastEventAt and lastEventAt > 0 and (now - lastEventAt) < LOWPOP_SCORE_EVENT_THROTTLE_MS then
        return true
    end

    return false, now
end
--EVENT_CAMPAIGN_UNDERPOP_BONUS_CHANGE_NOTIFICATION (*integer* _campaignId_)
function BSCARI:BSCGetCampaignIdList()
	--d("BSCARI:BSCGetCampaignIdList()")
	BSCARI.CAMPAIGN_IDS = { }
	for selectionIndex, campaignData in pairs(CAMPAIGN_BROWSER_MANAGER.selectionCampaignList) do	
		local _campaignId_ = campaignData.id
		if not campaignData.isImperialCityCampaign then	
			BSCARI.CAMPAIGN_IDS[_campaignId_] = { }		
			for _alliance_ = 1, 3 do
				BSCARI.CAMPAIGN_IDS[_campaignId_][_alliance_] = false
			end
		end
	end --/script d(BSCAllianceRanking.CAMPAIGN_IDS)
end
local function OnUPoPBonusChangeNotify( _, campaignId)
    local skip, now = ShouldSkipCampaignBonusEvent(lastLowPopEventAt)
    if skip then return end
    lastLowPopEventAt = now or GetSafeGameTimeMilliseconds()
	BSCARI:CheckLowPoP()

	for _alliance_ = 1, 3 do
		if IsUnderpopBonusEnabled(campaignId, _alliance_) then		
			CHAT_ROUTER:AddSystemMessage(zo_strformat("START LOWPOP AP BOOST [<<2>>] FOR [<<1>>]", GetAllianceColor(_alliance_):Colorize(GetAllianceName(_alliance_)), GetCampaignName(campaignId)))
			PlaySound(SOUNDS.ENLIGHTENED_STATE_GAINED)
		else
			CHAT_ROUTER:AddSystemMessage(zo_strformat("END LOWPOP AP BOOST [<<2>>] FOR [<<1>>]", GetAllianceColor(_alliance_):Colorize(GetAllianceName(_alliance_)), GetCampaignName(campaignId)))
		end
	end
end
local function OnUScoreBonusChangeNotify()
    local skip, now = ShouldSkipCampaignBonusEvent(lastScoreEventAt)
    if skip then return end
    lastScoreEventAt = now or GetSafeGameTimeMilliseconds()
	BSCARI:CheckLowPoP()
	BSCARI:BSCGetCampaignIdList()
	for campaignId, info in pairs(BSCARI.CAMPAIGN_IDS) do	
		local keepScore, resourceValue, outpostValue, defensiveScrollValue, offensiveScrollValue = GetCampaignHoldingScoreValues(campaignId)
		local underdogLeaderAlliance = GetCampaignUnderdogLeaderAlliance(campaignId)
		for i = 1, NUM_ALLIANCES do
			local isUnderdog = underdogLeaderAlliance ~= 0 and underdogLeaderAlliance ~= i
			if isUnderdog then					
				d(zo_strformat("START LOWSCORE AP BOOST [<<2>>] FOR [<<1>>]", GetAllianceColor(i):Colorize(GetAllianceName(i)), GetCampaignName(campaignId)))
			end
		end
	end
end
local function TestLowPoPBonus()	
	BSCARI:BSCGetCampaignIdList()
	if GetAssignedCampaignId() > 0 then
		GetCampaignHoldingScoreValues(GetAssignedCampaignId())
		GetCampaignUnderdogLeaderAlliance(GetAssignedCampaignId())	
	end		
	BSCARI:RequestCampaignSelectionData("debug-lowpop", true)
	BSCARI:RequestCampaignLeaderboardData("debug-lowpop", true)
	for _campaignId_, info in pairs(BSCARI.CAMPAIGN_IDS) do	
		GetCampaignHoldingScoreValues(_campaignId_)
		GetCampaignUnderdogLeaderAlliance(_campaignId_)		
		local underdogLeaderAlliance = GetCampaignUnderdogLeaderAlliance(_campaignId_)
		-- Do not call CAMPAIGN_SCORING:UpdateRewardTier()/UpdateScores() here;
		-- those can trigger extra server requests in the native campaign UI.		
		for _alliance_ = 1, NUM_ALLIANCES do
			if IsUnderpopBonusEnabled(_campaignId_, _alliance_) then
				if BSCARI.CAMPAIGN_IDS[_campaignId_][_alliance_] == false then 
					BSCARI.CAMPAIGN_IDS[_campaignId_][_alliance_] = true
					if BSCARI.SVA.SETTING[BSCARI.CurrentCharID].bAlertLowPop then 
						CHAT_ROUTER:AddSystemMessage(zo_strformat("START LOWPOP AP BOOST [<<2>>] FOR [<<1>>]", GetAllianceColor(_alliance_):Colorize(GetAllianceName(_alliance_)), GetCampaignName(_campaignId_)))
						PlaySound(SOUNDS.ENLIGHTENED_STATE_GAINED)
					end
				end
			else
				if BSCARI.CAMPAIGN_IDS[_campaignId_][_alliance_] == true then 
					BSCARI.CAMPAIGN_IDS[_campaignId_][_alliance_] = false
				end
			end
			
			local isUnderdog = underdogLeaderAlliance ~= 0 and underdogLeaderAlliance ~= _alliance_
			if isUnderdog then	
				if BSCARI.SVA.SETTING[BSCARI.CurrentCharID].bAlertLowPop then 				
					d(zo_strformat("START LOWSCORE AP BOOST [<<2>>] FOR [<<1>>]", GetAllianceColor(_alliance_):Colorize(GetAllianceName(_alliance_)), GetCampaignName(_campaignId_)))
					PlaySound(SOUNDS.ENLIGHTENED_STATE_GAINED)
				end
			end
		end
	end
end
function BSCARI:UpdateRotW()
    local cooldownRotWEpoch = BSCARI.SVA.cooldownRotWTime
    local output = "|cE9C62ARotW: "
    if cooldownRotWEpoch == nil then -- If there is no data from previous
        output = output .. " |cffcc00-|r"
    else
        local cooldownRemainingSeconds = os.difftime(cooldownRotWEpoch, os.time())
        if cooldownRemainingSeconds <= 0 then -- If the coffer is out of cooldown
            output = output .. " |t23:23:/esoui/art/icons/crafting_runecrafter_potion_sp_001.dds|t"
        else -- If the coffer is on cooldown
            local timediff, secondsToUpdate = FormatTimeSeconds(cooldownRemainingSeconds, TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT, TIME_FORMAT_PRECISION_SECONDS, TIME_FORMAT_DIRECTION_DESCENDING)
            output = output .. "|cE9C62A" .. timediff
        end
    end
    BSCARI.RotWLable:SetText(output)
end
local function InvetorySingleSlotUpdate(_, bagId, slotId)
	--d(zo_strformat("Item ID[<<1>>]", GetItemId(bagId, slotId)))
	if GetItemId(bagId, slotId) == 134618 then -- 134618 RotW Geode id
        if BSCARI.SVA.cooldownRotWTime == nil or BSCARI.SVA.cooldownRotWTime <= os.time() then
			BSCARI.SVA.cooldownRotWTime = os.time() + 72000
			BSCARI:UpdateRotW()
        end
    end
end
-------------------------------------------------------------------------------------------------
-- /script d(CAMPAIGN_OVERVIEW.overviewType)
-------------------------------------------------------------------------------------------------
local function OnPlayerActivated()	
    EVENT_MANAGER:UnregisterForEvent(BSCARI.Name, EVENT_PLAYER_ACTIVATED)
	-- Add one native top tab to the Alliance War scene group so the pages are available without a home campaign.
	if not BSCARI:RegisterAllianceWarTopTabs() then
		zo_callLater(function() BSCARI:RegisterAllianceWarTopTabs() end, 1000)
	end
	AvARankRefresh()
	UpdateRewardTier()
	
	BSCARI:RefreshVeterancyHudBars()
	BSCARI:UpdateUISettingsBAR()
end
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- Create UI
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
local UIELEments = {
	[1] = { name = "TotalAP", info = "Total AP Need until 50", settingKey = "ARO_H", xKey = "ARO_X", yKey = "ARO_Y" },
	[2] = { name = "APRank", info = "AP to Next Rank", settingKey = "CRO_H", xKey = "CRO_X", yKey = "CRO_Y" },
	[3] = { name = "APTier", info = "AP Tier Info", settingKey = "TRO_H", xKey = "TRO_X", yKey = "TRO_Y", requireAssignedCampaign = true },
	[4] = { name = "TotalVeterancy", info = "Veterancy Total", settingKey = "VRO_H", xKey = "VRO_X", yKey = "VRO_Y", veterancy = true },
	[5] = { name = "VeterancyRank", info = "Veterancy to Next Rank", settingKey = "VCO_H", xKey = "VCO_X", yKey = "VCO_Y", veterancy = true },
}

function BSCARI:GetHudBarEdgeSize()
    local settings = self:GetCurrentCharacterSettings()
    return ClampNumber(settings and settings.HUD_BAR_EDGE_SIZE, 0, 8, 2)
end

function BSCARI:GetHudColor(key, fallback)
    local settings = self:GetCurrentCharacterSettings()
    local defaultColor = self.DefaultCharacterSettings[key] or fallback or { r = 1, g = 1, b = 1, a = 1 }
    local color = GetColorTableValue(settings, key, defaultColor)
    return color.r, color.g, color.b, color.a or 1
end

function BSCARI:GetHudBarColor(isVeterancy)
    local key = isVeterancy and "VETERANCY_HUD_BAR_COLOR" or "AP_HUD_BAR_COLOR"
    return self:GetHudColor(key, { r = 1, g = 1, b = 1, a = 1 })
end

function BSCARI:GetHudBackdropCenterColor()
    return self:GetHudColor("HUD_BAR_CENTER_COLOR", { r = 0, g = 0, b = 0, a = 0.40 })
end

function BSCARI:GetHudBackdropEdgeColor()
    return self:GetHudColor("HUD_BAR_EDGE_COLOR", { r = 0, g = 0, b = 0, a = 1 })
end

local function GetOrCreateHudBarSolidEdgeControls(frame)
    if frame._bscariHudBarEdges then
        return frame._bscariHudBarEdges
    end

    local WM = GetWindowManager()
    local prefix = frame:GetName() .. "HudSolidEdge"
    local edges =
    {
        top = WM:CreateControl(prefix .. "Top", frame, CT_BACKDROP),
        bottom = WM:CreateControl(prefix .. "Bottom", frame, CT_BACKDROP),
        left = WM:CreateControl(prefix .. "Left", frame, CT_BACKDROP),
        right = WM:CreateControl(prefix .. "Right", frame, CT_BACKDROP),
    }

    for _, edge in pairs(edges) do
        edge:SetMouseEnabled(false)
        edge:SetCenterColor(1, 1, 1, 1)
        edge:SetEdgeColor(0, 0, 0, 0)
        if edge.SetEdgeTexture then
            edge:SetEdgeTexture(nil, 1, 1, 0, 0)
        end
        if edge.SetDrawLayer then
            edge:SetDrawLayer(DL_CONTROLS)
        end
        if edge.SetDrawLevel then
            edge:SetDrawLevel(4)
        end
        edge:SetHidden(true)
    end

    frame._bscariHudBarEdges = edges
    return edges
end

local function ApplyHudBarSolidEdge(frame, backdrop, edgeSize, r, g, b, a)
    local edges = GetOrCreateHudBarSolidEdgeControls(frame)

    if edgeSize <= 0 then
        for _, edge in pairs(edges) do
            edge:SetHidden(true)
        end
        return
    end

    edgeSize = zo_round(edgeSize)

    edges.top:ClearAnchors()
    edges.top:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 0, 0)
    edges.top:SetAnchor(TOPRIGHT, backdrop, TOPRIGHT, 0, 0)
    edges.top:SetHeight(edgeSize)

    edges.bottom:ClearAnchors()
    edges.bottom:SetAnchor(BOTTOMLEFT, backdrop, BOTTOMLEFT, 0, 0)
    edges.bottom:SetAnchor(BOTTOMRIGHT, backdrop, BOTTOMRIGHT, 0, 0)
    edges.bottom:SetHeight(edgeSize)

    edges.left:ClearAnchors()
    edges.left:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 0, 0)
    edges.left:SetAnchor(BOTTOMLEFT, backdrop, BOTTOMLEFT, 0, 0)
    edges.left:SetWidth(edgeSize)

    edges.right:ClearAnchors()
    edges.right:SetAnchor(TOPRIGHT, backdrop, TOPRIGHT, 0, 0)
    edges.right:SetAnchor(BOTTOMRIGHT, backdrop, BOTTOMRIGHT, 0, 0)
    edges.right:SetWidth(edgeSize)

    for _, edge in pairs(edges) do
        edge:SetCenterColor(r, g, b, a)
        edge:SetEdgeColor(0, 0, 0, 0)
        edge:SetHidden(false)
    end
end

function BSCARI:ApplyHudBarAppearanceToFrame(index)
    if not self.BARframes then return end

    local frame = self.BARframes[index]
    local data = UIELEments[index]
    if not frame or not data then return end

    local backdrop = frame:GetNamedChild("Frame")
    if backdrop then
        local centerR, centerG, centerB, centerA = self:GetHudBackdropCenterColor()
        local edgeR, edgeG, edgeB, edgeA = self:GetHudBackdropEdgeColor()
        local edgeSize = self:GetHudBarEdgeSize()

        backdrop:SetCenterColor(centerR, centerG, centerB, centerA)
        -- The native Backdrop edge uses a sliced decorative texture. With larger edge sizes
        -- only parts of that texture are visibly tinted, so we keep the native edge transparent
        -- and draw a solid four-sided texture border ourselves.
        backdrop:SetEdgeColor(edgeR, edgeG, edgeB, 0)
        ApplyHudBarSolidEdge(frame, backdrop, edgeSize, edgeR, edgeG, edgeB, edgeA)
    end

    local bar = frame:GetNamedChild("Bar")
    if bar then
        local r, g, b, a = self:GetHudBarColor(data.veterancy == true)
        bar:SetColor(r, g, b, a)
    end
end

function BSCARI:ApplyHudBarAppearance()
    if not self.BARframes then return end

    for index in ipairs(UIELEments) do
        self:ApplyHudBarAppearanceToFrame(index)
    end
end
function BSCARI:UIBARSetHidden(hidden) -- /script BSCAllianceRanking:UIBARSetHidden(false)
	for IDX in ipairs(UIELEments) do	
		if BSCARI.BARframes and BSCARI.BARframes[IDX] then
			BSCARI.BARframes[IDX]:SetHidden(hidden)
		end
		if hidden and BSCARI.BARfragments and BSCARI.BARfragments[IDX] then
			SCENE_MANAGER:GetScene("hud"):RemoveFragment(BSCARI.BARfragments[IDX])
			SCENE_MANAGER:GetScene("hudui"):RemoveFragment(BSCARI.BARfragments[IDX])
		end
	end	
end

function BSCARI:UpdateUISettingsBAR() -- /script BSCAllianceRanking:UpdateUISettingsBAR()
	local settings = BSCARI:GetCurrentCharacterSettings()
	if not settings or not BSCARI.BARframes or not BSCARI.BARfragments then return end

	BSCARI:ApplyHudBarAppearance()

	if not IsInAvAZone() then 
		BSCARI:UIBARSetHidden(true)		
		return
	end

	local veterancyActive = IsVeterancySeasonActive and IsVeterancySeasonActive() == true
	for IDX, data in ipairs(UIELEments) do		
		local hidden = not settings[data.settingKey]
		if data.requireAssignedCampaign and GetAssignedCampaignId() ~= GetCurrentCampaignId() then
			hidden = true
		elseif data.veterancy and not veterancyActive then
			hidden = true
		end

		local fragment = BSCARI.BARfragments[IDX]
		if not hidden then
			SCENE_MANAGER:GetScene("hud"):AddFragment(fragment)
			SCENE_MANAGER:GetScene("hudui"):AddFragment(fragment)	
		else
			SCENE_MANAGER:GetScene("hud"):RemoveFragment(fragment)
			SCENE_MANAGER:GetScene("hudui"):RemoveFragment(fragment)
		end
		BSCARI.BARframes[IDX]:SetMovable(not settings.LOCK_UI)
	end
end
function BSCARI.OnMoveStopBAR(IDX, frame)
	local settings = BSCARI:GetCurrentCharacterSettings()
	local data = UIELEments[IDX]
	if not settings or not data then return end
	settings[data.xKey] = frame:GetLeft()
	settings[data.yKey] = frame:GetTop()
end
local function CreateBARUI()
	local WM = GetWindowManager()
	BSCARI.BARframes = { }	
	BSCARI.BARfragments = { }
	for IDX, data in ipairs(UIELEments) do
		local frame = WM:CreateControlFromVirtual("BSCARIUI" .. data.name, nil, "BSCARIUI")
		frame:SetHandler("OnMoveStop", function() BSCAllianceRanking.OnMoveStopBAR(IDX, frame) end)		
		frame:GetNamedChild("lbl"):SetText(data.info)		

		local bar = frame:GetNamedChild("Bar")
		if bar then
			local r, g, b, a = BSCARI:GetHudBarColor(data.veterancy == true)
			bar:SetColor(r, g, b, a)
		end
		
		BSCARI.BARfragments[IDX] = ZO_HUDFadeSceneFragment:New(frame)		
		BSCARI.BARframes[IDX] = frame
		BSCARI:ApplyHudBarAppearanceToFrame(IDX)
		
		local settings = BSCARI:GetCurrentCharacterSettings()
		local L = settings and settings[data.xKey] or 0
		local T = settings and settings[data.yKey] or 0
		
		frame:ClearAnchors()
		if L ~= 0 and T ~= 0 then
			frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, L, T)
		else
			frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 600, 500 + (IDX * 90))			
		end	
		frame:SetMovable(not BSCARI.SVA.SETTING[BSCARI.CurrentCharID].LOCK_UI)
		frame:SetHidden(true)
	end	
end
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- //////////////////////////////////////////////// --- Init -- //////////////////////////////////////////////////////
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
local function SlashCommand(text)
	local ftext = zo_strlower(text)
	if ftext == 'test' then	
		d("TestLowPoPBonus")
		TestLowPoPBonus()
	elseif ftext == 'event' then
	
		--/script d(ZO_CURRENCIES_DATA[CURT_EVENT_TICKETS])
		
	elseif ftext == 'score' then
		d("TestScore")	
		BSCARI:BSCGetCampaignIdList()
		for campaignId, info in pairs(BSCARI.CAMPAIGN_IDS) do	
			local keepScore, resourceValue, outpostValue, defensiveScrollValue, offensiveScrollValue = GetCampaignHoldingScoreValues(campaignId)
			local underdogLeaderAlliance = GetCampaignUnderdogLeaderAlliance(campaignId)
			for i = 1, NUM_ALLIANCES do
				local isUnderpop = IsUnderpopBonusEnabled(campaignId, i)
				local isUnderdog = underdogLeaderAlliance ~= 0 and underdogLeaderAlliance ~= i
				if isUnderpop then
					d(zo_strformat("START LOWPOP AP BOOST [<<2>>] FOR [<<1>>]", GetAllianceColor(i):Colorize(GetAllianceName(i)), GetCampaignName(campaignId)))
				end
				if isUnderdog then					
					d(zo_strformat("START LOWSCORE AP BOOST [<<2>>] FOR [<<1>>]", GetAllianceColor(i):Colorize(GetAllianceName(i)), GetCampaignName(campaignId)))
				end
			end
		end
	else
		d(text)
		-- Home Keeps
		--  3 -  8 DC
		--  9 - 14 EP
		-- 15 - 20 AD
		for i = 1, GetNumKeeps() do
			local keepId, bgContext = GetKeepKeysByIndex(i)
			if GetKeepType(keepId) == KEEPTYPE_KEEP then
				d(keepId.." - "..bgContext.." - "..GetKeepName(keepId))
			end
		end
	end
end

function BSCARI.init(event, addonName)	
	if addonName ~= BSCARI.Name then
		return 
	end
	EVENT_MANAGER:UnregisterForEvent(BSCARI.Name, 	EVENT_ADD_ON_LOADED)	
		
	BSCARI.CurrentCharID = GetCurrentCharacterId()	
	EVENT_MANAGER:RegisterForEvent(BSCARI.Name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)		
	BSCARI.SVA = ZO_SavedVars:NewAccountWide(BSCARI.SavedVar, BSCARI.Version, nil, defaultSavedVarsAccount)
	BSCARI:GetCurrentCharacterSettings()
	
	-- Lables & Total AP Bar
	CreateControls()		
	CreateBARUI()	
	EVENT_MANAGER:RegisterForEvent(BSCARI.Name, EVENT_CAMPAIGN_LEADERBOARD_DATA_RECEIVED, function()
		BSCARI:MarkCampaignLeaderboardDataReady()
		UpdateRewardTier()
		AvARankRefresh()
	end)	
	EVENT_MANAGER:RegisterForEvent(BSCARI.Name, EVENT_CAMPAIGN_LEADERBOARD_DATA_CHANGED, function()
		BSCARI:MarkCampaignLeaderboardDataReady()
		UpdateRewardTier()
		AvARankRefresh()
	end) --	
	EVENT_MANAGER:RegisterForEvent(BSCARI.Name .. "SelectionDataReady", EVENT_CAMPAIGN_SELECTION_DATA_CHANGED, function()
		BSCARI:MarkCampaignSelectionDataReady()
	end)
 
	EVENT_MANAGER:RegisterForEvent(BSCARI.Name, EVENT_RANK_POINT_UPDATE, RankPointUpdate)  
	EVENT_MANAGER:AddFilterForEvent(BSCARI.Name, EVENT_RANK_POINT_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
	
	EVENT_MANAGER:RegisterForEvent(BSCARI.Name, EVENT_ALLIANCE_POINT_UPDATE, AlliancePointUpdate)  	
	EVENT_MANAGER:RegisterForEvent(BSCARI.Name, EVENT_PLAYER_COMBAT_STATE, OnCombatState)	
	if EVENT_REWARD_TRACK_PROGRESS_GAINED then
		EVENT_MANAGER:RegisterForEvent(BSCARI.Name .. "VeterancyMeterProgress", EVENT_REWARD_TRACK_PROGRESS_GAINED, function()
			BSCARI:RefreshAllianceRankingMeters()
			BSCARI:RefreshVeterancyHudBars()
			BSCARI:UpdateUISettingsBAR()
		end)
	end
	if EVENT_REWARD_TRACK_UPDATE_RECEIVED then
		EVENT_MANAGER:RegisterForEvent(BSCARI.Name .. "VeterancyMeterUpdate", EVENT_REWARD_TRACK_UPDATE_RECEIVED, function()
			BSCARI:RefreshAllianceRankingMeters()
			BSCARI:RefreshVeterancyHudBars()
			BSCARI:UpdateUISettingsBAR()
		end)
	end
	if EVENT_COLLECTION_UPDATED then
		EVENT_MANAGER:RegisterForEvent(BSCARI.Name .. "PvPStylesCollectionUpdate", EVENT_COLLECTION_UPDATED, function()
			if BSCARI.ALLIANCE_PVPSTYLEVIEW and BSCARI.ALLIANCE_PVPSTYLEVIEW.Refresh then
				BSCARI.ALLIANCE_PVPSTYLEVIEW:Refresh()
			end
		end)
	end
	if EVENT_COLLECTIBLES_UNLOCK_STATE_CHANGED then
		EVENT_MANAGER:RegisterForEvent(BSCARI.Name .. "PvPStylesUnlockUpdate", EVENT_COLLECTIBLES_UNLOCK_STATE_CHANGED, function()
			if BSCARI.ALLIANCE_PVPSTYLEVIEW and BSCARI.ALLIANCE_PVPSTYLEVIEW.Refresh then
				zo_callLater(function() BSCARI.ALLIANCE_PVPSTYLEVIEW:Refresh() end, 250)
			end
		end)
	end
	EVENT_MANAGER:RegisterForEvent(BSCARI.Name, EVENT_CAMPAIGN_UNDERPOP_BONUS_CHANGE_NOTIFICATION, OnUPoPBonusChangeNotify)  
	EVENT_MANAGER:RegisterForEvent(BSCARI.Name, EVENT_CAMPAIGN_SCORE_DATA_CHANGED, OnUScoreBonusChangeNotify)	
	--
	EVENT_MANAGER:RegisterForEvent(BSCARI.Name.."ROTW", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, InvetorySingleSlotUpdate)
    EVENT_MANAGER:AddFilterForEvent(BSCARI.Name.."ROTW", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    EVENT_MANAGER:AddFilterForEvent(BSCARI.Name.."ROTW", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
    EVENT_MANAGER:AddFilterForEvent(BSCARI.Name.."ROTW", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM, true)
	
	BSCARI:InitAbuffInfo()
	BSCARI:UpdateCharData()	
		
	-- Native settings are now inside the BSCs-AllianceRanking Alliance War tab.
	-- Command
	SLASH_COMMANDS['/bscari'] = SlashCommand
end

EVENT_MANAGER:RegisterForEvent(BSCARI.Name, EVENT_ADD_ON_LOADED, BSCARI.init)
