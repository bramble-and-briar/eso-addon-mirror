FyrMM = {}
FyrMM.Panel = {}
FyrMM.Options = {}
FyrMM.ActionMap = {}
FyrMM.noMap = false
FyrMM.Visible = true
FyrMM.AutoHidden = false
FyrMM.Initialized = false
FyrMM.pScale = 75
FyrMM.pScalePercent = 0.75
FyrMM.questPinCount = 0
FyrMM.currentLocationsCount = 0
FyrMM.currentPOICount = 0
FyrMM.currentForwardCamps = 0
FyrMM.currentWayshrineCount = 0
FyrMM.AfterCombatUnhidePending = false
FyrMM.AfterCombatUnhideTimeStamp = 0
FyrMM.LastQuestPinRequest = 0
FyrMM.MovementSpeed = 0
FyrMM.MovementSpeedPrevious = 0
FyrMM.MovementSpeedMax = 0
FyrMM.UseOriginalFunctions = true
FyrMM.MeasureMaps = true
FyrMM.DistanceMeasurementStarted = false
FyrMM.InitialPreloadTimeStamp = nil
FyrMM.currentMap = {}
FyrMM.currentMap.MapId = 0
FyrMM.currentMap.PlayerNX = 0
FyrMM.currentMap.PlayerNY = 0
FyrMM.currentMap.mapBuilt = false
FyrMM.currentMap.PlayerMounted = false
FyrMM.currentMap.PlayerSwimming = false
FyrMM.currentMap.movedTimeStamp = 0
FyrMM.currentMap.ZoneIndex = 0
FyrMM.currentMap.MapContentType = GetMapContentType()
FyrMM.CheckingZone = false
FyrMM.CustomPinList = {}
FyrMM.CustomPinCheckList = {}
FyrMM.LoadingCustomPins = {}
FyrMM.UpdatingCustomPins = {}
FyrMM.CustomPinsEnabled = true
FyrMM.IsGroup = false
FyrMM.IsWaypoint = false
FyrMM.Waypoint = nil
FyrMM.IsRally = false
FyrMM.Rally = nil
FyrMM.IsPing = false
FyrMM.Ping = nil
FyrMM.OverMiniMap = false
FyrMM.OverMenu = false
FyrMM.MenuFadingIn = false
FyrMM.MenuFadingOut = false
FyrMM.DisableSubzones = false
FyrMM.Halted = false
FyrMM.HaltTimeOffset = 0
FyrMM.LastReload = 0
FyrMM.DebugMode = false
FyrMM.MapAPI0Present = false
FyrMM.FadingEdges = false
FyrMM.KeepRefreshNeeded = true
FyrMM.GroupRefreshNeeded = true
FyrMM.CustomPinCount = 0
FyrMM.AvailableQuestGivers = {}
FYRMM_ZOOM_MAX = 50
FYRMM_ZOOM_MIN = 1
FYRMM_DEFAULT_ZOOM_LEVEL = 10
FYRMM_ZOOM_INCREMENT_AMOUNT = nil
FYRMM_QUEST_PIN_REQUEST_TIMEOUT = 10000        -- Time in miliseconds to wait for quest pin data
FYRMM_QUEST_PIN_REQUEST_MINIMUM_DELAY = 1000   -- Time in miliseconds to be passed before requesting quest pins again
MM_GetNumMapLocations = GetNumMapLocations     -- Location pin count
MM_IsMapLocationVisible = IsMapLocationVisible -- is Location visible
MM_GetMapLocationIcon = GetMapLocationIcon     -- Location pin texture
MM_GetNumPOIs = GetNumPOIs                     -- POI pin count
MM_GetPOIMapInfo = GetPOIMapInfo               -- POI pin info
FyrMM.QuestPins = {}
FyrMM.RequestedQuestPins = {}
FyrMM.currentDigSiteCount = 0
FyrMM.TimeFormat = 0
FyrMM.pinZoomScale = 1

local QuestPins = FyrMM.QuestPins
local RequestedQuestPins = FyrMM.RequestedQuestPins

local FreeQuestPinIndex = {}
local CurrentTasks = {}
local NeedQuestPinUpdate = true
local NeedCheckRemoveInvalidQuestPins = true
local QuestPinsUpdating = false
local QuestTasksPending = false
local CustomPinsCopying = false
local PinRef = nil
local PRCustomPins = nil
local LastQuestPinIndex = 0
local CurrentMap = FyrMM.currentMap
local CurrentMapId = 0
local CurrentTasks = CurrentTasks
local CleanPOIs = 0
local CustomPinIndex = {}
local CustomPinKeyIndex = {}
local FreeCustomPinIndex = {}
local LastCustomPinIndex = 0
local CustomPinMapId = 0
local PinsList = {}
local Wayshrines = {}
local WayshrineDistancesTimeStamp = 0
local KeepDistancesTimeStamp = 0
local SkyshardDistancesTimeStamp = 0
local QuestGiverDistancesTimeStamp = 0
local KeepIndex = {}
local PositionLog3D = {}
local PositionLogCounter = 0
local Treasures = {}
local DragonNextLocation = {}
local Digsites = {}
local AQGList = {}
local AQGListFull = {}
local MenuAnimation
local ZOpinData = ZO_MapPin.PIN_DATA
local pi = ZO_PI
local halfPi = ZO_HALF_PI
local doublePi = ZO_TWO_PI
local floor = zo_floor 
local abs = zo_abs
local GetGameTimeMilliseconds = GetGameTimeMilliseconds
local GetFrameTimeMilliseconds = GetFrameTimeMilliseconds
local GetMapPlayerPosition = GetMapPlayerPosition
local GetPlayerCameraHeading = GetPlayerCameraHeading
local IsUnitInCombat = IsUnitInCombat
local zo_cos = zo_cos
local zo_sin = zo_sin
local zo_sqrt = zo_sqrt
local detectedNewCustomPin = false
local CustomPinCrossReference = {}
local IsCompanionAround = false
local ZoomAnimating = false
local ASSISTED_PIN_TYPES = ZO_MapPin.ASSISTED_PIN_TYPES
local QUEST_PIN_TYPES = ZO_MapPin.QUEST_PIN_TYPES

local questPinTextures = {
    [MAP_PIN_TYPE_ASSISTED_QUEST_CONDITION] = "EsoUI/Art/Compass/quest_icon_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/quest_icon_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_ENDING] = "EsoUI/Art/Compass/quest_icon_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_REPEATABLE_CONDITION] = "EsoUI/Art/Compass/repeatableQuest_icon_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_REPEATABLE_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/repeatableQuest_icon_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_REPEATABLE_ENDING] = "EsoUI/Art/Compass/repeatableQuest_icon_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_ZONE_STORY_CONDITION] = "EsoUI/Art/Compass/zoneStoryQuest_icon_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_ZONE_STORY_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/zoneStoryQuest_icon_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_ZONE_STORY_ENDING] = "EsoUI/Art/Compass/zoneStoryQuest_icon_assisted.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_CONDITION] = "EsoUI/Art/Compass/quest_icon.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/quest_icon.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_ENDING] = "EsoUI/Art/Compass/quest_icon.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_REPEATABLE_CONDITION] = "EsoUI/Art/Compass/repeatableQuest_icon.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_REPEATABLE_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/repeatableQuest_icon.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_REPEATABLE_ENDING] = "EsoUI/Art/Compass/repeatableQuest_icon.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_ZONE_STORY_CONDITION] = "EsoUI/Art/Compass/zoneStoryQuest_icon.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_ZONE_STORY_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/zoneStoryQuest_icon.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_ZONE_STORY_ENDING] = "EsoUI/Art/Compass/zoneStoryQuest_icon.dds",
    [MAP_PIN_TYPE_QUEST_CONDITION] = "EsoUI/Art/Compass/quest_icon.dds",
    [MAP_PIN_TYPE_QUEST_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/quest_icon.dds",
    [MAP_PIN_TYPE_QUEST_ENDING] = "EsoUI/Art/Compass/quest_icon.dds",
    [MAP_PIN_TYPE_QUEST_REPEATABLE_CONDITION] = "EsoUI/Art/Compass/repeatableQuest_icon.dds",
    [MAP_PIN_TYPE_QUEST_REPEATABLE_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/repeatableQuest_icon.dds",
    [MAP_PIN_TYPE_QUEST_REPEATABLE_ENDING] = "EsoUI/Art/Compass/repeatableQuest_icon.dds",
    [MAP_PIN_TYPE_QUEST_ZONE_STORY_CONDITION] = "EsoUI/Art/Compass/zoneStoryQuest_icon.dds",
    [MAP_PIN_TYPE_QUEST_ZONE_STORY_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/zoneStoryQuest_icon.dds",
    [MAP_PIN_TYPE_QUEST_ZONE_STORY_ENDING] = "EsoUI/Art/Compass/zoneStoryQuest_icon.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_OFFER_ZONE_STORY] = "EsoUI/Art/Compass/zoneStoryQuest_available_icon.dds"
}

local breadcrumbQuestPinTextures = {
    [MAP_PIN_TYPE_ASSISTED_QUEST_CONDITION] = "EsoUI/Art/Compass/quest_icon_door_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/quest_icon_door_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_ENDING] = "EsoUI/Art/Compass/quest_icon_door_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_REPEATABLE_CONDITION] = "EsoUI/Art/Compass/repeatableQuest_icon_door_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_REPEATABLE_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/repeatableQuest_icon_door_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_REPEATABLE_ENDING] = "EsoUI/Art/Compass/repeatableQuest_icon_door_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_ZONE_STORY_CONDITION] = "EsoUI/Art/Compass/zoneStoryQuest_icon_door_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_ZONE_STORY_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/zoneStoryQuest_icon_door_assisted.dds",
    [MAP_PIN_TYPE_ASSISTED_QUEST_ZONE_STORY_ENDING] = "EsoUI/Art/Compass/zoneStoryQuest_icon_door_assisted.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_CONDITION] = "EsoUI/Art/Compass/quest_icon_door.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/quest_icon_door.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_ENDING] = "EsoUI/Art/Compass/quest_icon_door.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_REPEATABLE_CONDITION] = "EsoUI/Art/Compass/repeatableQuest_icon_door.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_REPEATABLE_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/repeatableQuest_icon_door.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_REPEATABLE_ENDING] = "EsoUI/Art/Compass/repeatableQuest_icon_door.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_ZONE_STORY_CONDITION] = "EsoUI/Art/Compass/zoneStoryQuest_icon_door.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_ZONE_STORY_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/zoneStoryQuest_icon_door.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_ZONE_STORY_ENDING] = "EsoUI/Art/Compass/zoneStoryQuest_icon_door.dds",
    [MAP_PIN_TYPE_QUEST_CONDITION] = "EsoUI/Art/Compass/quest_icon_door.dds",
    [MAP_PIN_TYPE_QUEST_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/quest_icon_door.dds",
    [MAP_PIN_TYPE_QUEST_ENDING] = "EsoUI/Art/Compass/quest_icon_door.dds",
    [MAP_PIN_TYPE_QUEST_REPEATABLE_CONDITION] = "EsoUI/Art/Compass/repeatableQuest_icon_door.dds",
    [MAP_PIN_TYPE_QUEST_REPEATABLE_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/repeatableQuest_icon_door.dds",
    [MAP_PIN_TYPE_QUEST_REPEATABLE_ENDING] = "EsoUI/Art/Compass/repeatableQuest_icon_door.dds",
    [MAP_PIN_TYPE_QUEST_ZONE_STORY_CONDITION] = "EsoUI/Art/Compass/zoneStoryQuest_icon_door.dds",
    [MAP_PIN_TYPE_QUEST_ZONE_STORY_OPTIONAL_CONDITION] = "EsoUI/Art/Compass/zoneStoryQuest_icon_door.dds",
    [MAP_PIN_TYPE_QUEST_ZONE_STORY_ENDING] = "EsoUI/Art/Compass/zoneStoryQuest_icon_door.dds",
    [MAP_PIN_TYPE_TRACKED_QUEST_OFFER_ZONE_STORY] = "EsoUI/Art/Compass/zoneStoryQuest_available_icon_door.dds"
}

local ZONE_EXPLORATION_PIN_TYPES = ZO_MapPin.SUGGESTION_PIN_TYPES -- showsPinAndArea = true is forward camps and SUGGESTION_PIN_TYPES

local OBJECTIVE_PIN_TYPES = ZO_MapPin.OBJECTIVE_PIN_TYPES

local CustomWaypoints = ZO_MapPin.MAP_PING_PIN_TYPES

local BORDER_KEEP_PIN_TYPES = {
   [MAP_PIN_TYPE_BORDER_KEEP_ALDMERI_DOMINION] = true,
   [MAP_PIN_TYPE_BORDER_KEEP_EBONHEART_PACT] = true,
   [MAP_PIN_TYPE_BORDER_KEEP_DAGGERFALL_COVENANT] = true,
}

----------------------------------------------------------------

local function GetQuestPinCount()
    return FyrMM.questPinCount
end

local function AvailableCustomPins()
    local count = 0
    for _, b in pairs(FyrMM.CustomPinList) do
       for _, c in pairs(b) do
	      count = count + 1
	   end
    end
    return count
end

local function IsCustomPinsLoading()
    for _, b in pairs(FyrMM.LoadingCustomPins) do
        if b then
            return b
        end
    end
    return false
end

local function GetQuestFreePinIndex()
    local index = LastQuestPinIndex
    if not ZO_IsTableEmpty(FreeQuestPinIndex) then
        index = table.remove(FreeQuestPinIndex)
        return index
    end
    index = index + 1
    LastQuestPinIndex = index
    return index
end

FyrMM.RequestJournalQuestConditionAssistance = RequestJournalQuestConditionAssistance
function RequestJournalQuestConditionAssistance(questIndex, stepIndex, conditionIndex, assisted)
    local taskId = FyrMM.RequestJournalQuestConditionAssistance(questIndex, stepIndex, conditionIndex, assisted)
    local tag = ZO_MapPin.CreateQuestPinTag(questIndex, stepIndex, conditionIndex)
    local currentTime = GetGameTimeMilliseconds()
    if currentTime - FyrMM.LastQuestPinRequest > FYRMM_QUEST_PIN_REQUEST_MINIMUM_DELAY then
        FyrMM.questPinCount = GetQuestPinCount()
        QuestPinsUpdating = true
    end
    if taskId and not FyrMM.Halted then
        FyrMM.LastQuestPinRequest = currentTime
        local currentTask = {}
        currentTask = tag
        currentTask.RequestTimeStamp = FyrMM.LastQuestPinRequest
        currentTask.MapId = CurrentMap.MapId
        currentTask.Fetched = true
        currentTask.ZO_MapVisible = ZO_WorldMap:IsHidden()
        CurrentTasks[taskId] = currentTask
    end
    return taskId
end

FyrMM.CancelRequestJournalQuestConditionAssistance = CancelRequestJournalQuestConditionAssistance -- never used
function CancelRequestJournalQuestConditionAssistance(taskId)
    if taskId and CurrentTasks[taskId] and CurrentTasks[taskId].Fetched then
        CurrentTasks[taskId] = nil
        FyrMM.CancelRequestJournalQuestConditionAssistance(taskId)
    end
end

-----------------------------------------------------------------
-- Utility functions
-----------------------------------------------------------------

local function CancelUpdates()
    -- 03/07/2026: Removed three UnregisterForUpdate() calls for "FyrMiniMapPOIPins",
    -- "FyrMiniMapLocationsPins", and "FyrMiniMapWayshrinesPins" - the same class of dead reference
    -- as the SetBorderPinHandlers() fix above. POI/Location/Wayshrine pins are built via direct
    -- one-shot calls (FyrMM.POIPins(), FyrMM.LocationPins(), FyrMM.Wayshrines(), see PinUpdate) and
    -- were never registered under these names anywhere in the addon, so these were always no-ops
    -- left over from a since-removed timer-based version of that code.
    FyrMM.UpdatingCustomPins = {}
    FyrMM.LoadingCustomPins = {}
    if PinRef then
        for i, n in pairs(PRCustomPins) do
            if i > MAP_PIN_TYPE_INVALID then
                EVENT_MANAGER:UnregisterForUpdate(string.format("OnFyrMiniMapCustomPinGroup%s",i))
            end
        end
    end
end

local function IsCurrentLocation(pin) -- is player at pin + calculate distance for the tooltip 
    if pin == nil then
        return
    end

    local x, y = CurrentMap.PlayerNX, CurrentMap.PlayerNY -- GetMapPlayerPosition("player")
    local nX = pin.nX or pin.normalizedX
    local nY = pin.nY or pin.normalizedY

    if nX == nil or nY == nil or CurrentMap.TrueMapSize == nil then
        return false
    end

    local distance = zo_round(CurrentMap.TrueMapSize * zo_sqrt(((x - nX) ^ 2) + ((y - nY) ^ 2)) * 7.55) / 10 -- assumed size is 1.325 times larger than approximate effective skill distance in meters.
    local message = string.format("%s %s m", GetString(SI_MM_STRING_DISTANCE), distance)
    
	if pin.isBreadcrumb or (pin.m_PinTag and pin.m_PinTag.isBreadcrumb) then  -- breadcrumbed pins
	    message = string.format("%s (%s)", message, zo_strformat(GetString(SI_WORLD_MAP_ACTION_TRAVEL_TO_WAYSHRINE),"<<z:2>>", GetString(SI_GAMEPAD_PLAYER_PROGERSS_BAR_LOCATION_HEADER)))
	end
	
	if not InformationTooltip:IsHidden() then -- add distance to pin on tooltip
	      ZO_Tooltip_AddDivider(InformationTooltip)
        InformationTooltip:AddLine(message, FyrMM.DefaultFontType, ZO_HIGHLIGHT_TEXT:UnpackRGB())
    end

    if not ZO_MapLocationTooltip:IsHidden() then -- add distance to pin on tooltip
	      ZO_Tooltip_AddDivider(ZO_MapLocationTooltip)
        ZO_MapLocationTooltip:AddLine(message, FyrMM.DefaultFontType, ZO_HIGHLIGHT_TEXT:UnpackRGB())
    end

    return CurrentMap.TrueMapSize * zo_sqrt((x - nX) ^ 2 + (y - nY) ^ 2) < 14 -- Approximate distance to use a wayshrine
end

local function IsCraftingService(pin)
	if pin == nil then
		return false
	end

	local tooltipIndex = pin.locationIndex
	if tooltipIndex == nil then
		return false
	end

	for _, v in pairs(FyrMM.CSProviders) do
		if v then
			for j = 1, GetNumMapLocationTooltipLines(tooltipIndex) do
				local _, tooltipLineText = GetMapLocationTooltipLineInfo(tooltipIndex, j)
				if string.find(tooltipLineText, v) then
					return true
				end
			end
		end
	end

	return false
end

local function SetTooltipMessage(pin)
    if pin == nil then
        return
    end
    if pin:IsFastTravelWayShrine() then
        local nodeIndex = pin:GetFastTravelNodeIndex()
        local known, name = GetFastTravelNodeInfo(nodeIndex)
        if not known then
            name = string.format("%s (undiscovered)", name)
        end
        InformationTooltip:AddLine(zo_strformat(SI_WORLD_MAP_LOCATION_NAME, name), FyrMM.HeaderFontType, ZO_WHITE:UnpackRGB()) -- Wayshrine name
        if IsCurrentLocation(pin) then
            InformationTooltip:AddLine(GetString(SI_TOOLTIP_WAYSHRINE_CURRENT_LOC), FyrMM.DefaultFontType, ZO_HIGHLIGHT_TEXT:UnpackRGB()) -- Player is near wayshrine
        else
            if IsInAvAZone() then
                InformationTooltip:AddLine(GetString(SI_TOOLTIP_WAYSHRINE_CANT_RECALL_AVA), FyrMM.DefaultFontType, ZO_ERROR_COLOR:UnpackRGB()) -- Can't travel to a wayshrine in Cyrodiil
            else
                local _, premiumTimeLeft = GetRecallCooldown()
                if premiumTimeLeft == 0 then
                    InformationTooltip:AddLine(GetString(SI_TOOLTIP_WAYSHRINE_CLICK_TO_RECALL), FyrMM.DefaultFontType, ZO_HIGHLIGHT_TEXT:UnpackRGB()) -- Recall text line
                    local cost = GetRecallCost()
                    if cost > 0 then
                        if cost <= GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) then
                            ZO_ItemTooltip_AddMoney(InformationTooltip, cost, SI_TOOLTIP_RECALL_COST, CURRENCY_HAS_ENOUGH)
                        else
                            ZO_ItemTooltip_AddMoney(InformationTooltip, cost, SI_TOOLTIP_RECALL_COST, CURRENCY_NOT_ENOUGH)
                        end
                    end
                else
                    local cooldownText = zo_strformat(SI_TOOLTIP_WAYSHRINE_RECALL_COOLDOWN, ZO_FormatTimeMilliseconds(premiumTimeLeft, TIME_FORMAT_STYLE_DESCRIPTIVE, TIME_FORMAT_PRECISION_SECONDS))
                    InformationTooltip:AddLine(cooldownText, FyrMM.DefaultFontType, ZO_HIGHLIGHT_TEXT:UnpackRGB())
                end
            end
        end
    else
        local poiIndex = pin:GetPOIIndex()
        local zoneIndex = pin:GetPOIZoneIndex()
        local poiName, _, poiStartDesc, poiFinishedDesc = GetPOIInfo(zoneIndex, poiIndex)
        InformationTooltip:AddLine(zo_strformat(SI_WORLD_MAP_LOCATION_NAME, poiName), FyrMM.HeaderFontType, ZO_WHITE:UnpackRGB())
        local pinType = select(3, MM_GetPOIMapInfo(zoneIndex, poiIndex))
        if not (ZO_MapPin.POI_PIN_TYPES[pinType]) then
            InformationTooltip:AddLine("(undiscovered)", FyrMM.DefaultFontType, ZO_HIGHLIGHT_TEXT:UnpackRGB())
        end
        if pinType == MAP_PIN_TYPE_POI_COMPLETE then
            if poiFinishedDesc ~= "" then
                InformationTooltip:AddLine(poiFinishedDesc, FyrMM.DefaultFontType, ZO_HIGHLIGHT_TEXT:UnpackRGB())
            end
        else
            if poiStartDesc ~= "" then
                InformationTooltip:AddLine(poiStartDesc, FyrMM.DefaultFontType, ZO_HIGHLIGHT_TEXT:UnpackRGB())
            end
        end
    end
end

function FyrMM.GetCurrentMapTextureFileInfo()
    local tileTexture = (GetMapTileTexture()):lower()
    if tileTexture == nil or tileTexture == "" then
        return "tamriel_0", "tamriel_", "art/maps/tamriel/"
    end
    local pos = select(2, tileTexture:find("maps/([%w%-]+)/"))
    if pos == nil then
        return "tamriel_0", "tamriel_", "art/maps/tamriel/"
    end
    pos = pos + 1
    return string.gsub(string.sub(tileTexture, pos), ".dds", ""), string.gsub(string.sub(tileTexture, pos), "0.dds", ""), tileTexture:sub(1, pos - 1)
end

function FyrMM.GetMapId()
    return GetCurrentMapId()
end

local function SetMapToZone()
    if FyrMM.DisableSubzones == true and GetMapType() == 1 and not IsUnitInDungeon("player") and not IsPlayerInRaid() and not IsActiveWorldBattleground() and not IsInAvAZone() then
        MapZoomOut()
        if not FyrMM.SV.HideZoneLabel then
            FyrMM.UpdateLabels()
        end
		CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    end
end

function FyrMM.MapHalfDiagonal()
    FyrMM.DiagonalND = zo_sqrt((Fyr_MM_Player:GetRight() - Fyr_MM:GetRight()) ^ 2 +
        (Fyr_MM_Player:GetTop() - Fyr_MM:GetTop()) ^ 2)
    return FyrMM.DiagonalND
end

-- local function IsSubmap() -- never used
    -- return CurrentMap.MapContent == MAP_CONTENT_DUNGEON or GetMapType() == MAPTYPE_SUBZONE
-- end

local function GetQuestJournalMaxValidIndex()
    -- 02/07/2026 optimization: Scan backward and return on the first hit instead of always
    -- scanning all MAX_JOURNAL_QUESTS slots forward. Since we only want the highest valid index,
    -- a backward scan finds the identical answer but can stop immediately instead of always
    -- checking all 50 slots - this runs on every quest condition counter change, which can fire
    -- in bursts during combat on kill-quests.
    for i = MAX_JOURNAL_QUESTS, 1, -1 do
        if IsValidQuestIndex(i) then
            return i
        end
    end
    return 0
end

local function IsAssisted(pinType)
    return ASSISTED_PIN_TYPES[pinType] ~= nil -- non-existent key = nil
end

-- local function IsQuestType(pinType)        -- never used
    -- return QUEST_PIN_TYPES[pinType] ~= nil -- non-existent key = nil
-- end

local function valueExists(i, x)
    for j = 1, #x do -- instead of ipairs to avoid overhead
        if x[j] == i then
            return true
        end
    end
    return false
end

local function questpinDataExists(pinData, array)
    -- Avoid continuous table lookups localize the values instead
    local questIndex, questName, conditionText, conditionIndex, normX, normY, radius, stepIndex = pinData.questIndex, pinData.questName, pinData.conditionText, pinData.conditionIndex, pinData.normalizedX, pinData.normalizedY, pinData.radius, pinData.stepIndex

    for i, v in pairs(array) do
        if v.questIndex == questIndex and v.questName == questName and v.conditionText == conditionText and v.conditionIndex == conditionIndex and v.normalizedX == normX and v.normalizedY == normY and v.radius == radius and v.stepIndex == stepIndex then
            return i
        end
    end
    return nil
end

function FyrMM.SetTargetScale(pin, targetScale)
    if pin == nil or targetScale == nil or not ((pin.targetScale and targetScale ~= pin.targetScale) or
            (pin.targetScale == nil and targetScale ~= pin:GetScale())) then
        return
    end

    local primaryPin, secondaryPin, tertiaryPin = pin.primaryPin, pin.secondaryPin, pin.tertiaryPin
    local newScale
    pin.targetScale = targetScale
    for i = 1, 50 do
      zo_callLater(function() -- that zo_callLater creates the smooth effect while hovering pins, better keep it
            newScale = zo_deltaNormalizedLerp(pin:GetScale(), targetScale, 0.1)
            if (abs(newScale - targetScale) < 0.01) then
                pin:SetScale(targetScale)
                if primaryPin then
                    pin.primaryPin:SetScale(targetScale)
                end
                if secondaryPin then
                    pin.secondaryPin:SetScale(targetScale)
                end
                if tertiaryPin then
                    pin.tertiaryPin:SetScale(targetScale)
                end
                pin.targetScale = nil
                return
            end
            pin:SetScale(newScale)
            if primaryPin then
                pin.primaryPin:SetScale(newScale)
            end
            if secondaryPin then
                pin.secondaryPin:SetScale(newScale)
            end
            if tertiaryPin then
                pin.tertiaryPin:SetScale(newScale)
            end
        end, i * 5)
    end
end

local function AfterCombatShow()
    if not FyrMM.AfterCombatUnhidePending then
        return
    end
    if GetFrameTimeMilliseconds() - FyrMM.AfterCombatUnhideTimeStamp < 1000 * (FyrMM.SV.AfterCombatUnhideDelay - 1) then
        return
    end
    FyrMM.AfterCombatUnhidePending = false
    if not IsUnitInCombat("player") then
        FyrMM.AutoHidden = false
        FyrMM.Visible = true
        FyrMM.HideCheck()
    end
end



local function SkyshardDistances() 
    if not (FyrMM.SV.BorderPins and FyrMM.SV.BorderSkyshard) then
        return
    end

	local totalSkyshards = Fyr_MM_Scroll_Map_SkyshardPins:GetNumChildren()
	
	if totalSkyshards == 0 then 
	    return
	end
	
    if CurrentMap.movedTimeStamp == SkyshardDistancesTimeStamp and SkyshardDistancesTimeStamp ~= 0 then
        return
    end

    SkyshardDistancesTimeStamp = CurrentMap.movedTimeStamp

    local gameTime = GetGameTimeMilliseconds()
    local wDmi, minWD = 1, 1
    local playerX, playerY = CurrentMap.PlayerNX, CurrentMap.PlayerNY

    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", string.format("SkyshardDistances Start: %s", totalSkyshards))
    end

    FyrMM.SkyshardPinControlCache = FyrMM.SkyshardPinControlCache or {}

    -- 03/07/2026 optimization: Cache skyshard UI controls to avoid expensive GetControl lookups and string allocations in hot paths
    for wDi = 1, totalSkyshards do
        local skyshard = FyrMM.SkyshardPinControlCache[wDi]
        if skyshard == nil then
            skyshard = GetControl(string.format("Fyr_MM_Scroll_Map_SkyshardPins_Pin%s", wDi))
            if skyshard ~= nil then
                FyrMM.SkyshardPinControlCache[wDi] = skyshard
            end
        end
        if skyshard and skyshard.nX and skyshard.nY then
            skyshard.nDistance = zo_sqrt((playerX - skyshard.nX) ^ 2 + (playerY - skyshard.nY) ^ 2)
            if skyshard.nDistance > 0 and skyshard.nDistance < minWD then
                minWD = skyshard.nDistance
                wDmi = wDi
            end
        end
    end
			
    for i = 1, totalSkyshards do
        local l = FyrMM.SkyshardPinControlCache[i]
        if l == nil then
            l = GetControl(string.format("Fyr_MM_Scroll_Map_SkyshardPins_Pin%s", i))
            if l ~= nil then
                FyrMM.SkyshardPinControlCache[i] = l
            end
        end
        if l ~= nil then
            l.Closest = (i == wDmi)
        end
    end

    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", string.format("SkyshardDistances Done.(%s) %s", wDmi, GetGameTimeMilliseconds() - gameTime))
    end
end

local function KeepDistances()
    if not (FyrMM.SV.BorderPins and FyrMM.SV.BorderKeep) or CurrentMap.MapId ~= 16 then
        return
    end

    if CurrentMap.movedTimeStamp == KeepDistancesTimeStamp and KeepDistancesTimeStamp ~= 0 then
        return
    end

    KeepDistancesTimeStamp = CurrentMap.movedTimeStamp

    local gameTime = GetGameTimeMilliseconds()
    local wDmi, wDmi2, wDmi3, minWD, minWD2, minWD3 = 1, 1, 1, 1, 1, 1
    local playerX, playerY = CurrentMap.PlayerNX, CurrentMap.PlayerNY 

    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", string.format("KeepDistances Start: %s", GetNumKeeps()))  
    end

    -- 26/06/2026 optimization: Run the distance calculation synchronously rather than using a 20ms update registration.
    -- This avoids timer overhead, callback latency, and string allocation churn.
    local function checkKeepDistance(wDi)
        local keep = GetControl(string.format("Fyr_MM_Scroll_Map_Keeps_Keep%s", wDi))
        if keep and keep.nX and keep.nY then
            local Visible = FyrMM.SV.WheelMap and FyrMM.Is_PinInsideWheel(keep) or FyrMM.IsPinVisible(keep)
            if not Visible then 
                keep.nDistance = zo_sqrt((playerX - keep.nX) ^ 2 + (playerY - keep.nY) ^ 2)
                if keep.nDistance > 0 and keep.nDistance < minWD then 
                    minWD = keep.nDistance
                    wDmi3 = wDmi2
                    wDmi2 = wDmi
                    wDmi = wDi
                elseif keep.nDistance > 0 and keep.nDistance < minWD2 then
                    minWD2 = keep.nDistance
                    wDmi3 = wDmi2
                    wDmi2 = wDi
                elseif keep.nDistance > 0 and keep.nDistance < minWD3 then
                    minWD3 = keep.nDistance
                    wDmi3 = wDi
                end
            end
        end
    end

    -- keeps: 3 to 20
    for wDi = 3, 20 do checkKeepDistance(wDi) end
    -- outposts: 132 to 134 and 163 to 165
    for wDi = 132, 134 do checkKeepDistance(wDi) end
    for wDi = 163, 165 do checkKeepDistance(wDi) end
    -- towns: 149, 151, 152
    for wDi = 149, 152 do checkKeepDistance(wDi) end
	
    for i = 3, 20 do -- keeps
        local l = GetControl(string.format("Fyr_MM_Scroll_Map_Keeps_Keep%s", i))
        if l ~= nil then
            l.Closest = (i == wDmi) or (i == wDmi2) or (i == wDmi3)
        end
    end
			
    for i = 132, 134 do -- outposts 
        local l = GetControl(string.format("Fyr_MM_Scroll_Map_Keeps_Keep%s", i))
        if l ~= nil then
            l.Closest = (i == wDmi) or (i == wDmi2) or (i == wDmi3)
        end
    end
			
    for i = 163, 165 do -- outposts 
        local l = GetControl(string.format("Fyr_MM_Scroll_Map_Keeps_Keep%s", i))
        if l ~= nil then
            l.Closest = (i == wDmi) or (i == wDmi2) or (i == wDmi3)
        end
    end
			
    for i = 149, 152 do -- towns 
        local l = GetControl(string.format("Fyr_MM_Scroll_Map_Keeps_Keep%s", i))
        if l ~= nil then
            l.Closest = (i == wDmi) or (i == wDmi2) or (i == wDmi3)
        end
    end

    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", string.format("KeepDistances Done.(%s) %s", wDmi, GetGameTimeMilliseconds() - gameTime))
    end
end


local function QuestGiverDistances() 
    if not (FyrMM.SV.BorderPins and FyrMM.SV.BorderQuestGivers) or #FyrMM.AvailableQuestGivers == 0 then
        return
    end
    
    if CurrentMap.movedTimeStamp == QuestGiverDistancesTimeStamp and QuestGiverDistancesTimeStamp ~= 0 then
        return
    end
   QuestGiverDistancesTimeStamp = CurrentMap.movedTimeStamp

    local gameTime = GetGameTimeMilliseconds()
    local x, y = CurrentMap.PlayerNX, CurrentMap.PlayerNY -- GetMapPlayerPosition("player")
    AQGListFull = {}
    local multiplier = Fyr_MM:GetWidth()

    for _, v in ipairs(FyrMM.AvailableQuestGivers) do
        if v.nX == nil and v.mpin.normalizedX ~= nil then -- workaround just in case
            v.nX = v.mpin.normalizedX
            v.nY = v.mpin.normalizedY
        end

        if v.nX and v.nY then
            v.nDistance = zo_sqrt((x - v.nX) * (x - v.nX) + (y - v.nY) * (y - v.nY))
            AQGListFull[#AQGListFull + 1] = {
                index = floor(multiplier * v.nDistance),
                data = v
            }
        end
    end
    
    
    local function sort(a, b)
        local typeA, typeB = type(a.index), type(b.index) -- avoid repeated calls to the type function

        if typeA == "number" and typeB == "number" then
            return a.index < b.index
        end
        if typeA == "number" and typeB ~= "number" then
            return true
        end
        if typeA ~= "number" and typeB == "number" then
            return false
        end

        return a.index and b.index and tostring(a.index) < tostring(b.index)
    end

    table.sort(AQGListFull, sort)

    AQGList = {}
    if FyrMM.ZoneStoryPin then
        AQGList[#AQGList + 1] = FyrMM.ZoneStoryPin
    end

    for i, n in ipairs(AQGListFull) do
        if i > 5 then
            break
        end
        AQGList[#AQGList + 1] = n.data
    end

    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", string.format("QuestGiverDistances %s", GetGameTimeMilliseconds() - gameTime))
    end
end

local function WayshrineDistances() 

    if not (FyrMM.SV.BorderPins and FyrMM.SV.BorderWayshrine) or FyrMM.currentWayshrineCount == 0 then
        return
    end

    if CurrentMap.movedTimeStamp == WayshrineDistancesTimeStamp and WayshrineDistancesTimeStamp ~= 0 then
        return
    end

    WayshrineDistancesTimeStamp = CurrentMap.movedTimeStamp

    local gameTime = GetGameTimeMilliseconds()
    local wDmi, minWD = 1, 1
    local playerX, playerY = CurrentMap.PlayerNX, CurrentMap.PlayerNY

    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", string.format("WayshrineDistances Start: %s", FyrMM.currentWayshrineCount))
    end

    if FyrMM.currentWayshrineCount == 1 then
        Wayshrines[1].Closest = Wayshrines[1].isRealWayshrine
        return
    end

    -- 26/06/2026 optimization: Run the distance calculation synchronously rather than using a 100ms update registration.
    -- This avoids timer overhead, callback latency, and string allocation churn.
    for wDi = 1, FyrMM.currentWayshrineCount do
        if Wayshrines[wDi] and Wayshrines[wDi].isRealWayshrine then
            Wayshrines[wDi].nDistance = zo_sqrt((playerX - Wayshrines[wDi].nX) ^ 2 + (playerY - Wayshrines[wDi].nY) ^ 2)
            if Wayshrines[wDi].nDistance < minWD then
                minWD = Wayshrines[wDi].nDistance
                wDmi = wDi
            end
        end
    end

    for i, _ in pairs(Wayshrines) do
        Wayshrines[i].Closest = (i == wDmi)
        Wayshrines[i].pin.Closest = (i == wDmi)
    end

    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", string.format("WayshrineDistances Done.(%s) %s", wDmi, GetGameTimeMilliseconds() - gameTime))
    end
end






function FyrMM.MenuTooltip(button, message)
    -- Fyr_MM_Menu:SetAlpha(1)
    FyrMM.OverMenu = true
    Fyr_MM_Close:SetAlpha(1)
    if message == nil or button == nil then
        return
    end
    InitializeTooltip(InformationTooltip, Fyr_MM, TOPLEFT, 38, button:GetTop())
    InformationTooltip:AddLine(message, FyrMM.DefaultFontType, ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB())
end

function FyrMM.TooltipExit()
    FyrMM.OverMenu = false
    -- Fyr_MM_Menu:SetAlpha(0.1)
    Fyr_MM_Close:SetAlpha(0)
    ClearTooltip(InformationTooltip)
end

-- function FyrMM.PinToggle(value)
    -- MM_SetLockResizing(value)
    -- MM_RefreshPanel()
-- end

function FyrMM.OpenSettingsPanel()
    FyrMM.LAM:OpenToPanel(FyrMM.CPL)
end

function FyrMM.API_Check()
    if FyrMM.SV.UseOriginalAPI and _G.CGV then -- if Community Leveling Guides is active and original functions to be used
        -- if _G.GetPOIMapInfo then                            -- _GetPOIMapInfo_ORIG_ZGV
            -- MM_GetPOIMapInfo = _G.GetPOIMapInfo             -- _GetPOIMapInfo_ORIG_ZGV
        -- end
        if _GetNumMapLocations ~= nil then                  -- _0GetNumMapLocations
            FyrMM.MapAPI0Present = true
            MM_GetNumMapLocations = _GetNumMapLocations     -- _0GetNumMapLocations
		end
        if _IsMapLocationVisible ~= nil then                -- _0IsMapLocationVisible
            MM_IsMapLocationVisible = _IsMapLocationVisible -- _0IsMapLocationVisible
        end
        if _GetMapLocationIcon ~= nil then                  -- _0GetMapLocationIcon
            MM_GetMapLocationIcon = _GetMapLocationIcon     -- _0GetMapLocationIcon
        end
        if _G.GetNumPOIs ~= nil then                        -- _0GetNumPOIs
            MM_GetNumPOIs = _G.GetNumPOIs                   -- _0GetNumPOIs
        end
        if _G.GetPOIMapInfo ~= nil then                     -- _0GetPOIMapInfo
            MM_GetPOIMapInfo = _G.GetPOIMapInfo             -- _0GetPOIMapInfo
        end
    else
        MM_GetMapLocationIcon = GetMapLocationIcon
        MM_GetPOIMapInfo = GetPOIMapInfo
        MM_GetNumMapLocations = GetNumMapLocations
        MM_IsMapLocationVisible = IsMapLocationVisible
		    MM_GetNumPOIs = GetNumPOIs
    end
end

function FyrMM.GetCurrentMapSize()
    return CurrentMap and CurrentMap.TrueMapSize or nil -- Returns assumed calculated map size in feet, returns nil no calculated size or not possible to do so
end

-- 19/06/2026 optimization: Frame-caching state for map dimensions and player coordinates to avoid redundant API queries
local lastDimCheckTime = 0
local cachedMWidth, cachedMHeight = 0, 0
local cachedPlayerX, cachedPlayerY = 0, 0
local cachedDi = 0
local lastDiCheckTime = 0
local lastHeadingRotCheck = nil
local cachedCosHeading = 1
local cachedSinHeading = 0

local function GetRotatedPosition(x, y) -- Inspired by DeathAngel's RadarMiniMap
    if CurrentMap.Heading == nil then
        return
    end
    if not (x or CurrentMap.PlayerX) then
        return x, y
    end
    local frameTime = GetFrameTimeMilliseconds()
    -- 19/06/2026 optimization: Query map dimensions only once per frame
    if frameTime ~= lastDimCheckTime then
        lastDimCheckTime = frameTime
        cachedMWidth, cachedMHeight = Fyr_MM_Scroll_Map:GetDimensions()
    end
    
    -- 26/06/2026 optimization: Cache trig functions for Heading once per frame to avoid redundant zo_sin/zo_cos calculations
    if frameTime ~= lastHeadingRotCheck then
        lastHeadingRotCheck = frameTime
        local heading = -CurrentMap.Heading
        cachedCosHeading = zo_cos(heading)
        cachedSinHeading = zo_sin(heading)
    end
    
    local ix, iy = (x * cachedMWidth) - CurrentMap.PlayerX, (y * cachedMHeight) - CurrentMap.PlayerY
    local rx = cachedCosHeading * ix - cachedSinHeading * iy
    local ry = cachedSinHeading * ix + cachedCosHeading * iy
    return zo_round(rx), zo_round(ry)
end


local function GetNorthFacingPosition(x, y)
    if not (x and y) then
        return x, y
    end
    local frameTime = GetFrameTimeMilliseconds()
    -- 19/06/2026 optimization: Query map dimensions only once per frame
    if frameTime ~= lastDimCheckTime then
        lastDimCheckTime = frameTime
        cachedMWidth, cachedMHeight = Fyr_MM_Scroll_Map:GetDimensions()
    end
    return floor(cachedMWidth * x), floor(cachedMHeight * y) -- floor is faster than zo_round
end

function FyrMM.Is_PinInsideWheel(pin)
    local pinX = pin.nX or pin.normalizedX
    local pinY = pin.nY or pin.normalizedY
    if not pinX or not pinY then
        return false
    end

    local frameTime = GetFrameTimeMilliseconds()
    -- 19/06/2026 optimization: Query map dimensions only once per frame
    if frameTime ~= lastDimCheckTime then
        lastDimCheckTime = frameTime
        cachedMWidth, cachedMHeight = Fyr_MM_Scroll_Map:GetDimensions()
    end
    cachedPlayerX = CurrentMap.PlayerX
    cachedPlayerY = CurrentMap.PlayerY

    local distanceSquared
    local fallbackDistanceSquared
    local useFallback = false
    if cachedMWidth and cachedMHeight and cachedPlayerX and cachedPlayerY then
        local ix = (pinX * cachedMWidth) - cachedPlayerX
        local iy = (pinY * cachedMHeight) - cachedPlayerY
        distanceSquared = ix * ix + iy * iy
    else
        -- Fallback in case dimensions/positions are not initialized yet
        local x, y = pin:GetCenter()
        local x1, y1 = Fyr_MM_Player:GetCenter()
        if not x or not x1 then return false end
        fallbackDistanceSquared = (x - x1) ^ 2 + (y - y1) ^ 2
        useFallback = true
    end

    -- 19/06/2026 optimization: Cache map width/diameter once per frame to avoid redundant UI width queries
    if frameTime ~= lastDiCheckTime then
        lastDiCheckTime = frameTime
        cachedDi = Fyr_MM:GetWidth() or FyrMM.SV.MapWidth
    end

    local width = pin:GetWidth() or 32

    local threshold = cachedDi / 2 - ((30 / 512) * cachedDi)
    if (pin.radius and pin.radius > 0) or pin.borderInformation then 
        threshold = threshold + width / 2 - 10
    end
	
    -- 26/06/2026 optimization: Squared Distance Comparison to avoid expensive zo_sqrt inside loops
    local thresholdSquared = threshold * threshold
    if useFallback then
        return fallbackDistanceSquared < thresholdSquared
    else
        return distanceSquared < thresholdSquared
    end
end

local function smoothHeadingRotation() -- added by @Masteroshi430
    local x, y, pheading = CurrentMap.PlayerNX, CurrentMap.PlayerNY, CurrentMap.PlayerHeading or GetMapPlayerPosition("player")
    local headingTo = abs(pheading - doublePi)

    if not FyrMM.SV.RotateMap then -- no rotation option so we return a value ASAP
        return 0 
    end
	
	if FyrMM.SV.MapHeading == "CAMERA" and CurrentMap.CameraHeading then -- map heading to camera heading option
	   headingTo = abs(CurrentMap.CameraHeading - doublePi) 
	end  

    local heading = CurrentMap.Heading or 0
    local diff = ((headingTo - heading) + pi) % (doublePi) - pi
    local currentHeading = (heading + (diff / 10)) % (doublePi)

    if currentHeading < 0 then -- apparently unnecessary
        currentHeading = currentHeading + (doublePi)
    end

    return currentHeading
end

local function SetDigSitePoints(digSite) 
    local borderInformation = digSite.borderInformation
    local RotateMap = FyrMM.SV.RotateMap
    local heading = CurrentMap.Heading

    -- 02/07/2026 optimization: Skip recomputing the rotated polygon (trig per border point) if
    -- the heading hasn't changed meaningfully since last time. This runs on every RefreshAnchor
    -- for bordered dig-site pins while RotateMap is on - roughly every 60ms - and was previously
    -- redoing the full rotation every call even while the player stood still or moved without
    -- turning, mirroring the same redundant-draw check already used for the camera/player textures.
    if RotateMap and heading and CurrentMap.PlayerNX and digSite.lastPointsHeading and
        abs(digSite.lastPointsHeading - heading) < 0.0001 then
        return
    end

    digSite:ClearPoints()
	

	-- for i = 0, 11 do -- supposed to draw a perfect circle around the dig site, why do I sometimes have to multiply x by two at the end I don't know... 
	
        -- local ix = borderInformation.centerX  
        -- local iy = borderInformation.centerZ 
        -- local sine = zo_sin(i*doublePi/12)
        -- local cosine = zo_cos(i*doublePi/12)
        -- local rx =  (cosine * ix) - (sine * iy)
        -- local ry = (cosine * iy) + (sine * ix) 
        -- digSite:AddPoint(rx, ry*(4/3))
		-- -- multiply ry by 4/3 works
    -- end
    -- if FyrMM then return end


    if not (RotateMap and heading and CurrentMap.PlayerNX) then -- steady map
        for i = 1, #borderInformation.borderPoints do
            digSite:AddPoint(borderInformation.borderPoints[i].x, borderInformation.borderPoints[i].y)
        end
        return
    end
	
	-- rotate map 
    local points = borderInformation.borderPoints
		
    for i = 1, #points do 

		
		-- method 2	(same shit, less precise) 
		-- local newX, newY = GetRotatedPosition(points[i].x, points[i].y)
        -- digSite:AddPoint((newX/1000)*2, newY/1000)

		
        -- method 1		
        local point = points[i]
        local ix = point.x - 0.5
        local iy = point.y - 0.5
        local sine = zo_sin(-heading)
        local cosine = zo_cos(-heading)
        local rx = (cosine * ix) - (sine * iy)
        local ry = (cosine * iy) + (sine * ix)
		digSite:AddPoint(rx,ry)
		
		
		
		-- method 3
		--digSite:AddPoint(borderInformation.borderPoints[i].x, borderInformation.borderPoints[i].y)
		

        
		
		-- depending on which tile is the point :
		--(rx*0.7, ry*0.9) more accurate when heading north...
        --(rx*2, ry) stays in shape when rotating...


		
   end
   
    digSite.lastPointsHeading = heading

    -- method 3
	-- local newAngle = (heading + pi) % (doublePi)
    -- digSite:SetTransformRotationZ(newAngle)	
end



local function SetPinFunctions(pin)
    if pin.UpdateWheelVisibility == nil then
        pin.UpdateWheelVisibility = function(self)
            if FyrMM.SV.WheelMap then
                self:SetHidden(not FyrMM.Is_PinInsideWheel(self))
            end
        end
    end

    if pin.RefreshAnchor then
        return
    end

    pin.RefreshAnchor = function(self)
        local x = self.nX or self.normalizedX
        local y = self.nY or self.normalizedY

        if x == nil or y == nil then
            return
        end

        self:ClearAnchors()

        if FyrMM.SV.RotateMap then
            if pin.borderInformation then 
                SetDigSitePoints(pin)
                self:SetAnchor(TOPLEFT, Fyr_MM_Scroll, CENTER, GetRotatedPosition(x, y))
                return
            end
            self:SetAnchor(CENTER, Fyr_MM_Scroll, CENTER, GetRotatedPosition(x, y))
            return
        end

        if FyrMM.SV.WheelMap then
            self:SetAnchor(CENTER, Fyr_MM_Scroll_Map_Pins, TOPLEFT, GetNorthFacingPosition(x, y))
            if pin.borderInformation then
                self:SetParent(FyrMM.GetScrollObject(self))
            end
            return
        end

        self:SetAnchor(CENTER, self:GetParent(), TOPLEFT, GetNorthFacingPosition(x, y))
		
    end
end


function FyrMM.AxisPosition(angle, mapWidth, mapHeight, northAngle, southAngle, doubleSouthAngle)
    -- If they are not passed (just in case it's called from elsewhere), compute them:
    if not mapWidth then
        local w, h = Fyr_MM:GetDimensions() or FyrMM.SV.MapWidth, FyrMM.SV.MapHeight
        mapWidth = w / 2
        mapHeight = h / 2
        northAngle = math.atan(mapWidth / mapHeight)
        southAngle = halfPi - northAngle
        doubleSouthAngle = southAngle * 2
    end

    local northPos, eastPos, southPos, westPos
    local aMinusNorth = angle - northAngle
    local aPlusNorth = angle + northAngle

    if aPlusNorth >= doublePi or aMinusNorth <= 0 then -- Upper border line
        if aMinusNorth <= 0 then
            northPos = mapWidth + mapHeight * zo_sin(angle) / zo_sin(halfPi - angle)
        else
            northPos = mapWidth - mapHeight * zo_sin(doublePi - angle) / zo_sin(halfPi - (doublePi - angle))
        end
        return northPos, 0
    end

    if aMinusNorth > 0 and aMinusNorth < doubleSouthAngle then -- Right border line
        if aMinusNorth > southAngle then
            eastPos = mapHeight + mapWidth * zo_sin(aMinusNorth - southAngle) /
                zo_sin(halfPi - (aMinusNorth - southAngle))
        else
            eastPos = mapWidth * zo_sin(aMinusNorth) / zo_sin(halfPi - aMinusNorth)
        end
        return mapWidth * 2, eastPos
    end

    if aMinusNorth >= doubleSouthAngle and angle <= 3 * northAngle + doubleSouthAngle then -- Bottom border line
        if aMinusNorth - northAngle > doubleSouthAngle then
            southPos = mapWidth - mapHeight * zo_sin(angle - 2 * northAngle - doubleSouthAngle) /
                zo_sin(halfPi - (angle - 2 * northAngle - doubleSouthAngle))
        else
            southPos = mapWidth * 2 - mapHeight * zo_sin(aMinusNorth - doubleSouthAngle) /
                zo_sin(halfPi - (aMinusNorth - doubleSouthAngle))
        end
        return southPos, mapHeight * 2
    end

    if aPlusNorth > doublePi - doubleSouthAngle and aPlusNorth < doublePi then -- Left border line
        if aMinusNorth > southAngle then
            westPos = mapHeight - mapWidth * zo_sin(angle - 3 * northAngle - 3 * southAngle) /
                zo_sin(halfPi - (angle - 3 * northAngle - 3 * southAngle))
        else
            westPos = mapHeight - mapWidth * zo_sin(angle - 3 * northAngle - doubleSouthAngle) /
                zo_sin(halfPi - (angle - 3 * northAngle - doubleSouthAngle))
        end
        return 0, westPos
    end
end

local function RoundArc(angle) -- return angle % (math.doublePi) faster for loops higher than ~100 of this function
    return (angle > doublePi) and angle - doublePi or angle -- return angle if angle is not less than double pi
end

local cachedTop, cachedLeft, cachedRight, cachedMargin = 0, 0, 0, 0

local function CanDrawCardinalForRotateWheelmap(x, y)
    if not FyrMM.SV.WheelMap then
        return true
    end
    if not FyrMM.SV.CardinalPoints then
        return false
    end
    return (y == cachedTop) and (x >= cachedLeft + cachedMargin) and (x <= cachedRight - cachedMargin)
end

local lastCardCheckTime = 0
local function AxisSwitch()
    local rotateMap = FyrMM.SV.RotateMap

    -- 19/06/2026 optimization: Frame-cache Fyr_MM dimensions to avoid 64+ UI engine queries per frame
    local frameTime = GetFrameTimeMilliseconds()
    if frameTime ~= lastCardCheckTime then
        lastCardCheckTime = frameTime
        local w = Fyr_MM:GetWidth() or FyrMM.SV.MapWidth or 300
        cachedMargin = w / 3.5
        cachedTop = Fyr_MM:GetTop() or 0
        cachedLeft = Fyr_MM:GetLeft() or 0
        cachedRight = Fyr_MM:GetRight() or 0
    end

    for i = 1, Fyr_MM_Axis_Textures:GetNumChildren() do
        local texture = Fyr_MM_Axis_Textures:GetChild(i)
        if texture then
            texture:ClearAnchors()
            local x, y = texture:GetCenter()
            texture:SetHidden(not rotateMap or not CanDrawCardinalForRotateWheelmap(x, y))

            -- 19/06/2026 optimization: Cache texture dimensions configuration to prevent redundant string manipulation and layout updates
            if not texture.dimSet then
                local name = texture:GetName()
                name = string.gsub(name, "Fyr_MM_Axis_", "")
                texture:SetDimensions(#name == 1 and 24 or 32, 24)
                texture.dimSet = true
            end
        end
    end

    for i = 1, Fyr_MM_Axis_Labels:GetNumChildren() do
        local label = Fyr_MM_Axis_Labels:GetChild(i)
        if label then
            label:ClearAnchors()
            local x, y = label:GetCenter()
            label:SetHidden(not rotateMap or not CanDrawCardinalForRotateWheelmap(x, y))
        end
    end
end

do
    -- 19/06/2026 Optimization: Cache axis angles table to prevent high-frequency table allocation (225 tables/sec)
    local AxisAngles = nil
    -- 26/06/2026 optimization: Cache last layout state to avoid redundant ClearAnchors and SetAnchor calls
    local lastHeading = nil
    local lastMapW = nil
    local lastMapH = nil

    function FyrMM.AxisPins()
        if FyrMM.SV.WheelMap and FyrMM.SV.RotateMap and FyrMM.SV.CardinalPoints then
            AxisSwitch()
        elseif (FyrMM.SV.WheelMap and not Fyr_MM_Axis_N:IsHidden()) or
            not (FyrMM.SV.RotateMap and not Fyr_MM_Axis_N:IsHidden()) then
            AxisSwitch()
            return
        end

        if not FyrMM.SV.RotateMap or not CurrentMap.Heading then
            return
        end

        -- 19/06/2026 Optimization: Lazy initialize and reuse the static control table
        if not AxisAngles then
            AxisAngles = { {
                pin = Fyr_MM_Axis_NE,
                label = Fyr_MM_Axis_NE_Label
            }, {
                pin = Fyr_MM_Axis_E,
                label = Fyr_MM_Axis_E_Label
            }, {
                pin = Fyr_MM_Axis_SE,
                label = Fyr_MM_Axis_SE_Label
            }, {
                pin = Fyr_MM_Axis_S,
                label = Fyr_MM_Axis_S_Label
            },	{
                pin = Fyr_MM_Axis_SW,
                label = Fyr_MM_Axis_SW_Label
            }, {
                pin = Fyr_MM_Axis_W,
                label = Fyr_MM_Axis_W_Label
            } ,	{
                pin = Fyr_MM_Axis_NW,
                label = Fyr_MM_Axis_NW_Label
            }, 	{
                pin = Fyr_MM_Axis_N,
                label = Fyr_MM_Axis_N_Label
            }}
        end

        local w, h = Fyr_MM:GetDimensions()
        w = w or FyrMM.SV.MapWidth
        h = h or FyrMM.SV.MapHeight
        local heading = CurrentMap.Heading

        -- 26/06/2026 optimization: Cache last layout state to avoid redundant ClearAnchors and SetAnchor calls (16 layout operations/frame)
        if lastHeading and abs(lastHeading - heading) < 0.0001 and lastMapW == w and lastMapH == h then
            return
        end
        lastHeading = heading
        lastMapW = w
        lastMapH = h

        local mapWidth = w / 2
        local mapHeight = h / 2
        local northAngle = math.atan(mapWidth / mapHeight)
        local southAngle = halfPi - northAngle
        local doubleSouthAngle = southAngle * 2

        local n = doublePi - heading

        for i, angle in ipairs(AxisAngles) do
            local angleValue = RoundArc(n + pi * (i * 0.25)) 
            local posX, posY = FyrMM.AxisPosition(angleValue, mapWidth, mapHeight, northAngle, southAngle, doubleSouthAngle)
            angle.pin:ClearAnchors()
            angle.label:ClearAnchors()
            angle.pin:SetAnchor(CENTER, Fyr_MM_Axis_Control, TOPLEFT, posX, posY)
            angle.label:SetAnchor(CENTER, Fyr_MM_Axis_Control, TOPLEFT, posX, posY)
        end
    end
end

local lastViewRange = nil
local lastTrueMapSize = nil
local cachedSquaredRange = 0

-- 19/06/2026 Optimization: Squared Distance Comparison to avoid expensive zo_sqrt inside loops
local function IsCoordinateInRange(x, y)
    if CurrentMap.TrueMapSize == nil or CurrentMap.PlayerNX == nil or not FyrMM.SV.CustomPinViewRange or
        not FyrMM.SV.ViewRangeFiltering then
        return true
    end

    local mapSize = CurrentMap.TrueMapSize
    if mapSize <= 0 then
        return true
    end

    local viewRange = FyrMM.SV.CustomPinViewRange
    -- Cache the squared range ratio to avoid division/squaring on every call
    if mapSize ~= lastTrueMapSize or viewRange ~= lastViewRange then
        lastTrueMapSize = mapSize
        lastViewRange = viewRange
        cachedSquaredRange = (viewRange / mapSize) ^ 2
    end

    local dx = x - CurrentMap.PlayerNX
    local dy = y - CurrentMap.PlayerNY
    return (dx * dx + dy * dy) <= cachedSquaredRange
end

function FyrMM.SetPinSize(pin, size, _)
    local properSize = floor(size / 2) * 2
    if (pin.radius == nil or pin.radius == 0) and CurrentMap.MapId ~= 16 and CurrentMap.MapId ~= 660 and
        CurrentMap.MapContentType ~= MAP_CONTENT_BATTLEGROUND and properSize > 42 then
        properSize = 42
    end
    if (pin.radius == nil or pin.radius == 0) and CurrentMap.MapId ~= 16 and CurrentMap.MapId ~= 660 and
        CurrentMap.MapContentType ~= MAP_CONTENT_BATTLEGROUND and properSize < 23 then
        properSize = 23
    end
	if pin.radius and pin.radius > 0 then 
	   -- Already set in the RescalePinPositions() function (fix for SilverBride's bug) 
	else
	    pin:SetDimensions(properSize, properSize)
	end
end

function FyrMM.SetPinAnchor(pin, x, y, AnchorToControl, hidden)
    local newX, newY, currentX, currentY, currentObject, _
    if pin == nil then
        return
    end
    SetPinFunctions(pin)

    if pin.nX == nil and pin.nY == nil and pin.normalizedX == nil and pin.normalizedY == nil then
        PinsList[pin:GetName()] = nil
        pin:ClearAnchors()
        pin:SetHidden(true)
        return
    end

    if x and y and AnchorToControl then
        _, _, currentObject, _, currentX, currentY = pin:GetAnchor()
        if PinsList[pin:GetName()] == nil then
            PinsList[pin:GetName()] = pin
        end

        if FyrMM.SV.RotateMap then
            newX, newY = GetRotatedPosition(x, y)
            AnchorToControl = Fyr_MM_Scroll
        else
            newX, newY = GetNorthFacingPosition(x, y)
        end

        if newX ~= currentX or newY ~= currentY or currentObject ~= AnchorToControl then
            pin:ClearAnchors()
            if FyrMM.SV.RotateMap then
                if pin.borderInformation then
                    pin:SetAnchor(TOPLEFT, AnchorToControl, CENTER, newX, newY)
                else
                    pin:SetAnchor(CENTER, AnchorToControl, CENTER, newX, newY)
                end
            else
                pin:SetAnchor(CENTER, AnchorToControl, TOPLEFT, newX, newY)
            end
        end
    end

    if hidden then
        pin:SetHidden(true)
        return
    end

    if FyrMM.SV.WheelMap and x and y then
        pin:SetHidden(not FyrMM.Is_PinInsideWheel(pin))
    end
end

local function RescaleLinks()
    if not IsInAvAZone() then
        return
    end
    local mWidth, mHeight = Fyr_MM_Scroll_Map:GetDimensions()
    local Count, mapLink, startX, startY, endX, endY
    
    -- 26/06/2026 optimization: Track link existence to break the loop early and avoid up to 300 redundant GetControl lookups per frame
    local linkExists = false

    FyrMM.MapLinkCache = FyrMM.MapLinkCache or {}
    FyrMM.MapLinkNSCache = FyrMM.MapLinkNSCache or {}
    FyrMM.MapLinkWECache = FyrMM.MapLinkWECache or {}

    -- 03/07/2026 optimization: Cache link UI controls to avoid expensive GetControl lookups and string allocations in hot paths
    for i = 1, 100 do
        linkExists = false
        mapLink = FyrMM.MapLinkCache[i]
        if mapLink == nil then
            mapLink = GetControl(string.format("Fyr_MM_Scroll_Map_Links_Link%s", i))
            if mapLink ~= nil then
                FyrMM.MapLinkCache[i] = mapLink
            end
        end
        if mapLink then
            linkExists = true
            if FyrMM.SV.WheelMap then
                mapLink:SetParent(Fyr_MM_Scroll_CW_Map_Pins)
            else
                mapLink:SetParent(Fyr_MM_Scroll_Map_Links)
            end

            if FyrMM.SV.RotateMap then
                mapLink:ClearAnchors()
                mapLink:SetAnchor(TOPLEFT, Fyr_MM_Scroll, CENTER, GetRotatedPosition(mapLink.startNX, mapLink.startNY))
                mapLink:SetAnchor(BOTTOMRIGHT, Fyr_MM_Scroll, CENTER, GetRotatedPosition(mapLink.endNX, mapLink.endNY))
            else
                startX, startY, endX, endY = mapLink.startNX * mWidth - mWidth / 2,
                    mapLink.startNY * mHeight - mHeight / 2,
                    mapLink.endNX * mWidth - mWidth / 2, mapLink.endNY * mHeight - mHeight / 2
                mapLink:ClearAnchors()
                mapLink:SetAnchor(TOPLEFT, Fyr_MM_Scroll_Map_Links, CENTER, zo_round(startX), zo_round(startY))
                mapLink:SetAnchor(BOTTOMRIGHT, Fyr_MM_Scroll_Map_Links, CENTER, zo_round(endX), zo_round(endY))
            end
        end

        mapLink = FyrMM.MapLinkNSCache[i]
        if mapLink == nil then
            mapLink = GetControl(string.format("Fyr_MM_Scroll_Map_LinksNS_Link%s", i))
            if mapLink ~= nil then
                FyrMM.MapLinkNSCache[i] = mapLink
            end
        end
        if mapLink then
            linkExists = true
            if FyrMM.SV.WheelMap then
                mapLink:SetParent(Fyr_MM_Scroll_CW_Map_Pins)
            else
                mapLink:SetParent(Fyr_MM_Scroll_Map_Links)
            end
            
            if FyrMM.SV.RotateMap then
                mapLink:ClearAnchors()
                mapLink:SetAnchor(TOPLEFT, Fyr_MM_Scroll, CENTER, GetRotatedPosition(mapLink.startNX, mapLink.startNY))
                mapLink:SetAnchor(BOTTOMRIGHT, Fyr_MM_Scroll, CENTER, GetRotatedPosition(mapLink.endNX, mapLink.endNY))
            else
                startX, startY, endX, endY = mapLink.startNX * mWidth - mWidth / 2,
                    mapLink.startNY * mHeight - mHeight / 2,
                    mapLink.endNX * mWidth - mWidth / 2, mapLink.endNY * mHeight - mHeight / 2
                mapLink:ClearAnchors()
                mapLink:SetAnchor(TOPLEFT, Fyr_MM_Scroll_Map_Links, CENTER, zo_round(startX), zo_round(startY))
                mapLink:SetAnchor(BOTTOMRIGHT, Fyr_MM_Scroll_Map_Links, CENTER, zo_round(endX), zo_round(endY))
            end
        end

        mapLink = FyrMM.MapLinkWECache[i]
        if mapLink == nil then
            mapLink = GetControl(string.format("Fyr_MM_Scroll_Map_LinksWE_Link%s", i))
            if mapLink ~= nil then
                FyrMM.MapLinkWECache[i] = mapLink
            end
        end
        if mapLink then
            linkExists = true
            if FyrMM.SV.WheelMap then
                mapLink:SetParent(Fyr_MM_Scroll_CW_Map_Pins)
            else
                mapLink:SetParent(Fyr_MM_Scroll_Map_Links)
            end
            
            if FyrMM.SV.RotateMap then
                mapLink:ClearAnchors()
                mapLink:SetAnchor(TOPLEFT, Fyr_MM_Scroll, CENTER, GetRotatedPosition(mapLink.startNX, mapLink.startNY))
                mapLink:SetAnchor(BOTTOMRIGHT, Fyr_MM_Scroll, CENTER, GetRotatedPosition(mapLink.endNX, mapLink.endNY))
            else
                startX, startY, endX, endY = mapLink.startNX * mWidth - mWidth / 2,
                    mapLink.startNY * mHeight - mHeight / 2,
                    mapLink.endNX * mWidth - mWidth / 2, mapLink.endNY * mHeight - mHeight / 2
                mapLink:ClearAnchors()
                mapLink:SetAnchor(TOPLEFT, Fyr_MM_Scroll_Map_Links, CENTER, zo_round(startX), zo_round(startY))
                mapLink:SetAnchor(BOTTOMRIGHT, Fyr_MM_Scroll_Map_Links, CENTER, zo_round(endX), zo_round(endY))
            end
        end
        
        -- only on cyrodiil main map because it would block links from updating their position when moving while arriving for the 1st time in one of the 6 bases
        if not linkExists and CurrentMap.MapId == 16 then
            break
        end
    end
end

local function UpdateWheelPins()
    if Fyr_MM:IsHidden() then
        return
    end
    local RotateMap = FyrMM.SV.RotateMap
    local WheelMap = FyrMM.SV.WheelMap
    if not RotateMap and not WheelMap then
        return
    end
    for _, v in pairs(PinsList) do
        if WheelMap then
            v:UpdateWheelVisibility()
        end
        if RotateMap then
            if not v:IsHidden() or v.BorderPin then
                v:RefreshAnchor()
            end
        end
    end
    RescaleLinks()
end


local function UpdateCustomPinPositions()
    if not FyrMM.Visible or Fyr_MM:IsHidden() or FyrMM.worldMapShowing or CustomPinsCopying then
        return
    end
    -- local currentZone = CurrentMap.MapId
    local mWidth, mHeight = Fyr_MM_Scroll_Map:GetDimensions()
    local enabled
    
    -- 26/06/2026 optimization: Cache custom pin enabled check results per update to avoid repeating expensive ZO_WorldMap_GetPinManager():IsCustomPinEnabled calls
    local pinManager = ZO_WorldMap_GetPinManager()
    local enabledCache = {}

    for _, p in pairs(PinsList) do
        if p and p.m_PinType then
            local pinType = p.m_PinType
            if pinType == 9999 or pinType == 9998 then -- fix for my fake custom pins 
                p:SetHidden(not IsCoordinateInRange(p.nX, p.nY))
                p:RefreshAnchor()
            elseif pinType >= MAP_PIN_TYPE_INVALID then
                enabled = enabledCache[pinType]
                if enabled == nil then
                    if PinRef then
                        if PRCustomPins and PRCustomPins[pinType] then
                            enabled = PRCustomPins[pinType].enabled
                        end
                    else
                        enabled = pinManager:IsCustomPinEnabled(pinType) -- checks filter for custom pin
                    end
                    enabledCache[pinType] = enabled or false
                end

                if p.nX and p.nY and enabled then
                    p:SetHidden(not IsCoordinateInRange(p.nX, p.nY))
                    if not p:IsHidden() then
                        if p.pinTexture and p.pinTexture ~= p:GetTextureFileName() then
                            p:SetTexture(p.pinTexture)
                        end
                        p:RefreshAnchor()
                    end
                end
            end
        end
    end
end

local function RescalePinPositions()
    if Fyr_MM:IsHidden() or not CurrentMap.needRescale then
        return
    end
    CurrentMap.needRescale = false
    local mWidth, mHeight = Fyr_MM_Scroll_Map:GetDimensions()

 for _, v in pairs(PinsList) do
	
		v:RefreshAnchor() -- refresh pins positions

		------------ RESCALE PINS -------------------
		if v.borderInformation ~= nil then -- antiquity digging sites
			local width = v.borderInformation.borderWidth * mWidth
			local height = v.borderInformation.borderHeight * mHeight
			v:SetDimensions(width, height)
		elseif FyrMM.SV.autoResizePin and v ~= ZO_WorldMap_GetPinManager():GetPlayerPin() and v.m_textureAnimTimeline == nil and CurrentMap.MapId ~= 16 and CurrentMap.MapId ~= 660 and
			   (v.radius == 0 or v.radius == nil) and CurrentMap.MapContentType ~= MAP_CONTENT_BATTLEGROUND and not v.noZoomResize then -- autoresize pins to zoom option
			if v.m_PinType == 9999 then -- Elder Scroll aura 
				local size = 64
				FyrMM.SetPinSize(v, size * FyrMM.pScalePercent)
			elseif v.m_PinType == 9997 then	-- spectacle events effect pin
				local size = 48
				FyrMM.SetPinSize(v, size * FyrMM.pScalePercent * FyrMM.pinZoomScale)
			elseif BORDER_KEEP_PIN_TYPES[v.m_PinType] then	-- border keeps (alliance bases)
				local size = 64
				FyrMM.SetPinSize(v, size * FyrMM.pScalePercent)
			elseif v.m_PinType then -- other pins
				local size = 32
				if ZO_MapPin.FAST_TRAVEL_WAYSHRINE_PIN_TYPES[v.m_PinType] or ZO_MapPin.POI_PIN_TYPES[v.m_PinType] or v.m_PinType == MAP_PIN_TYPE_LOCATION then -- scale pin to zoom level only for these types
					FyrMM.SetPinSize(v, size * FyrMM.pScalePercent * FyrMM.pinZoomScale)
				else
					FyrMM.SetPinSize(v, size * FyrMM.pScalePercent)
				end
			end
		elseif v.radius and v.radius > 0 then -- resize area pin in case of zoom
			local size = mHeight * v.radius * 2
			v:SetDimensions(size, size)
		end
	
	  if v.isForwardCampPreview then -- forward camp preview pin
			if FyrMM.Visible and FORWARD_CAMP_PREVIEW and FORWARD_CAMP_PREVIEW.forwardCampSlotted and CurrentMap.MapId == 16 then
    		   v.nX = CurrentMap.PlayerNX 
			     v.nY = CurrentMap.PlayerNY
           v.radius = 0.026000000536442
			     v.pinTexture = "EsoUI/Art/MapPins/map_areaPin.dds" 
				   v:SetTexture("EsoUI/Art/MapPins/map_areaPin.dds")
			     if v:IsHidden() then v:SetHidden(false) end
			     v:SetAlpha(1)
			else
				 if not v:IsHidden() then v:SetHidden(true) end
			     v.nX = CurrentMap.PlayerNX 
			     v.nY = CurrentMap.PlayerNY
           v.radius = 0.026000000536442
			     v.pinTexture = "EsoUI/Art/MapPins/map_areaPin.dds" 
			     v:SetAlpha(0)
				   v.isForwardCampPreview = nil
				   FyrMM.ForwardCampPreview = nil
				   FyrMM.RemoveCustomPin(v)
			   end		
		  elseif FyrMM.SV.WheelMap then -- normal pins show / hide
            v:SetHidden(not FyrMM.Is_PinInsideWheel(v))
            if v.BorderPin then
               v.BorderPin:SetHidden(not v:IsHidden())
            end
       end
  end
	
	if FORWARD_CAMP_PREVIEW == nil or FORWARD_CAMP_PREVIEW.forwardCampSlotted ~= true or CurrentMap.MapId ~= 16 then
		FyrMM.ForwardCampPreview = nil
	end
	
    RescaleLinks()
    FyrMM.UpdateQuestPinPositions()
    FyrMM.PlaceBorderPins()
end

local function AnimateZoom(newzoom)
    if CurrentMap.ZoomLevel == newzoom then
	    ZoomAnimating = false
        return
    end

    local step = (newzoom - CurrentMap.ZoomLevel) / 10
	
	if step > 0 then
	     PlaySound(SOUNDS.MAP_ZOOM_IN)
    else
	     PlaySound(SOUNDS.MAP_ZOOM_OUT)
    end	

    EVENT_MANAGER:RegisterForUpdate("OnFyrMMZoomAnimate", 1, function()
        FyrMM.SetCurrentMapZoom(CurrentMap.ZoomLevel + step)

        if (step < 0 and CurrentMap.ZoomLevel <= newzoom) or (step > 0 and CurrentMap.ZoomLevel >= newzoom) then
            EVENT_MANAGER:UnregisterForUpdate("OnFyrMMZoomAnimate")
            --d("zoom ended")           
		    FyrMM.SetCurrentMapZoom(newzoom)
			
			if FyrMM.SV.autoResizePin and CurrentMap.MapId ~= 16 and CurrentMap.MapId ~= 660 and CurrentMap.MapContentType ~= MAP_CONTENT_BATTLEGROUND then
				-- zoom: 1 to 50 default: 10
				-- should be between 0.1 and 5
				FyrMM.pinZoomScale = (CurrentMap.ZoomLevel) / 10
				-- d("pinzoom: "..FyrMM.pinZoomScale)
			else
				FyrMM.pinZoomScale = 1
			end
			
			FyrMM.PositionUpdate()
            CurrentMap.needRescale = true
            RescalePinPositions()
            FyrMM.UpdateMapTiles(true)
            ZoomAnimating = false
        else
		   -- d("zoomming step: "..step.." state: "..CurrentMap.ZoomLevel.." goal: "..newzoom)
        end
    end)
end

local function GetQuestData(pin)
    return pin.m_PinTag[1], pin.m_PinTag[3], pin.m_PinTag[2]
end

local function SetQuestTooltip(pin)
    if pin == nil then
        return
    end
    local tooltipLines = {}
    local line = ""
    local nX = pin.normalizedX
    local nY = pin.normalizedY
    local pinCount = Fyr_MM_Scroll_Map_QuestPins:GetNumChildren()
	local prevQuestname
    for index = 1, pinCount + 10 do
        local questPin = GetControl(string.format("Fyr_MM_Scroll_Map_QuestPins_Pin%s", index))
        if questPin and (not questPin:IsHidden() or FyrMM.SV.WheelMap) then
            line = ""
            if questPin.normalizedX == nX and questPin.normalizedY == nY then
                if QUEST_PIN_TYPES[questPin.m_PinType] then
                    line = GenerateQuestConditionTooltipLine(GetQuestData(questPin))
					if valueExists(line, tooltipLines) or line == nil or line == "" then
                        line = ""
                    else
					    local icon = zo_iconTextFormatNoSpace(questPinTextures[questPin.m_PinType],24,24,"")
						local questName = string.format("%s: ", GetJournalQuestName(questPin.questIndex))
						if prevQuestname ~= questName then
							 if GetTrackedIsAssisted(TRACK_TYPE_QUEST, questPin.questIndex) then
								   InformationTooltip:AddLine(string.format("%s%s", icon, questName), FyrMM.DefaultFontType, ZO_SELECTED_TEXT:UnpackRGB())
							 else 
								   InformationTooltip:AddLine(string.format("%s%s", icon, questName), FyrMM.DefaultFontType, ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB())
							 end
						end
						local text = GenerateQuestConditionTooltipLine(GetQuestData(questPin))
					    local bulletIcon = zo_iconTextFormatNoSpace("EsoUI/Art/Miscellaneous/Gamepad/gp_bullet.dds",12,12,"")
						if GetTrackedIsAssisted(TRACK_TYPE_QUEST, questPin.questIndex) then
						    InformationTooltip:AddLine(string.format("%s%s", bulletIcon, text), FyrMM.DefaultFontType, ZO_SELECTED_TEXT:UnpackRGB())
						else 
						    InformationTooltip:AddLine(string.format("%s%s", bulletIcon, text), FyrMM.DefaultFontType, ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB())
						end
						prevQuestname = questName
                    end

                end
                if GetTrackedIsAssisted(TRACK_TYPE_QUEST, questPin.questIndex) then
                    questPin:SetMouseEnabled(true)
					
                else
                    questPin:SetMouseEnabled(false)
                end
            end
            if line ~= "" then
                table.insert(tooltipLines, line)
            end
        end
    end
    pin:SetMouseEnabled(true)
end

local lastFyrMMCheckTime = nil
local cachedFyrMMLeft = 0
local cachedFyrMMRight = 0
local cachedFyrMMTop = 0
local cachedFyrMMBottom = 0

-- 26/06/2026 optimization: Cache Fyr_MM bounds once per frame to avoid redundant UI layout queries
function FyrMM.IsPinVisible(pin) -- Check for pin leaving map limits
    local frameTime = GetFrameTimeMilliseconds()
    if frameTime ~= lastFyrMMCheckTime then
        lastFyrMMCheckTime = frameTime
        cachedFyrMMLeft = Fyr_MM:GetLeft() or 0
        cachedFyrMMRight = Fyr_MM:GetRight() or 0
        cachedFyrMMTop = Fyr_MM:GetTop() or 0
        cachedFyrMMBottom = Fyr_MM:GetBottom() or 0
    end

    local pinRight = pin:GetRight()
    local pinLeft = pin:GetLeft()
    local pinBottom = pin:GetBottom()
    local pinTop = pin:GetTop()

    if not pinRight or not pinLeft or not pinBottom or not pinTop then
        return false
    end

    return (pinRight >= cachedFyrMMLeft + 6 and pinLeft <= cachedFyrMMRight - 10 and pinBottom >=
        cachedFyrMMTop + 6 and pinTop <= cachedFyrMMBottom - 10)
end

function FyrMM.IsValidBorderPin(pin)
    if not FyrMM.SV.BorderPins then
        return false
    end
	
    local Visible, Tracked
    if FyrMM.SV.WheelMap then
	    Visible = FyrMM.Is_PinInsideWheel(pin)
    else
	    Visible = FyrMM.IsPinVisible(pin)
    end

    if pin.m_PinType == MAP_PIN_TYPE_GROUP or pin.m_PinType == MAP_PIN_TYPE_GROUP_LEADER then
        if IsUnitOnline(pin.unitTag) or pin.unitTag == "companion" then
            if FyrMM.SV.BorderPinsOnlyLeader and not IsUnitGroupLeader("player") and not IsActiveWorldBattleground() then
                Tracked = IsUnitGroupLeader(pin.unitTag) and (GetUnitZone("player") == GetUnitZone(pin.unitTag))
            else
                Tracked = GetUnitZone("player") == GetUnitZone(pin.unitTag)
            end
        end
    else 
	    if pin.questIndex then -- quest pins
			if FyrMM.SV.BorderPinsOnlyAssisted then
				   local isAssisted = GetTrackedIsAssisted(TRACK_TYPE_QUEST, pin.questIndex)
				   if not isAssisted then
					    Tracked = false
				   else
					    Tracked = true
				   end 
				   
			else
				Tracked = true
			end
		end 
    end

    if pin.m_PinType == MAP_PIN_TYPE_ACTIVE_COMPANION then
        Tracked = true
    end

    if CustomWaypoints[pin.m_PinType] then
        Tracked = FyrMM.SV.BorderPinsWaypoint
    end

    if pin.m_Pin then
        if pin.m_Pin:IsFastTravelWayShrine() then 
            local index, _ = string.gsub(pin:GetName(), "Fyr_MM_Scroll_Map_WayshrinePins_Pin", "")
            if Wayshrines[tonumber(index)] then
                if Wayshrines[tonumber(index)].Closest and CurrentMap.MapId and CurrentMap.MapId ~= 16 then -- removes wayshrine border pin on Cyrodiil map
                    Tracked = FyrMM.SV.BorderWayshrine
                else
                    Tracked = false
                end
            end
        end
    end


	-- Skyshards
	if pin.m_PinType == MAP_PIN_TYPE_SKYSHARD_COMPLETE or pin.m_PinType == MAP_PIN_TYPE_SKYSHARD_SEEN or pin.m_PinType ==  MAP_PIN_TYPE_SKYSHARD_SUGGESTED then 
		if pin.Closest then  
			Tracked = FyrMM.SV.BorderSkyshard
		else
			Tracked = false
		end
  end
	
	
	-- keeps
	if ZO_MapPin.KEEP_PIN_TYPES[pin.m_PinType] then 
			if pin.Closest and CurrentMap.MapId and CurrentMap.MapId == 16 then 
				Tracked = FyrMM.SV.BorderKeep
			else
				Tracked = false
			end
    end
	
    -- under attack keep texture
    if pin.m_PinType == MAP_PIN_TYPE_KEEP_ATTACKED_LARGE or pin.m_PinType == MAP_PIN_TYPE_KEEP_ATTACKED_SMALL then 
            local keep = GetControl(string.format("Fyr_MM_Scroll_Map_Keeps_Keep%s", pin.keepId))
	     	if CurrentMap.MapId and CurrentMap.MapId == 16 and keep and keep.Closest then
            keep.hasAura = true
				    Tracked = FyrMM.SV.BorderKeep
			else
			    if keep then keep.hasAura = false end
				Tracked = false
			end
    end	

    if pin.m_PinType == MAP_PIN_TYPE_LOCATION then
        Tracked = false
        if pin.IsBankPin and FyrMM.SV.BorderPinsBank then
            Tracked = pin.IsBankPin
        end
        if pin.IsStablePin and FyrMM.SV.BorderPinsStables then
            Tracked = pin.IsStablePin
        end
        if pin.IsCraftingServicePin and FyrMM.SV.BorderCrafting then
            Tracked = pin.IsCraftingServicePin
        end
        -- Community Leveling Guides
        if pin.isZGESO then
            Tracked = pin.isZGESO
        end
    end

    -- AVA and Battlegrounds moving pins
    if pin.AVABGtype ~= nil then
        Tracked = true
    end

    -- lost treasure & Map pins treasures & surveys
    if pin.IsTreasure then
        if (pin.pinTexture and string.find(pin.pinTexture, "MapPins/Treasure_")) or
           (PRCustomPins and PRCustomPins[pin.m_PinType] and PRCustomPins[pin.m_PinType].pinTypeString and
           string.find(PRCustomPins[pin.m_PinType].pinTypeString, "LostTreasure")) then
            Tracked = FyrMM.SV.BorderTreasures
        else
            pin.IsTreasure = nil
            Tracked = false
        end
    end

    -- Dragon Next location
    if FyrMM.SV.WorldEvents and pin.IsDragonNextLocation then
        if pin.pinTexture and string.find(pin.pinTexture, "dragonNextLocation") and (pin.nX ~= -1 and pin.nX ~= -1) then
            Tracked = FyrMM.SV.WorldEvents
        else
            pin.IsDragonNextLocation = nil
            Tracked = false
        end
    end

    -- antiquity digging sites
    if pin.borderInformation ~= nil then
        Tracked = FyrMM.SV.BorderTreasures
    end

    -- quest givers and zonestory
    if pin.IsAvailableQuest then
        if pin.m_PinTag ~= nil then
            if pin.m_PinTag.IsAvailableQuest then
                if pin.m_PinTag.isZoneStory and pin == FyrMM.ZoneStoryPin then 
                    Tracked = FyrMM.SV.BorderQuestGivers
                elseif not pin.m_PinTag.isZoneStory then
                    Tracked = FyrMM.SV.BorderQuestGivers
                else
                    Tracked = false
                end
            else
                pin.IsAvailableQuest = nil
				Tracked = false
            end
        else
            pin.IsAvailableQuest = nil
			Tracked = false
        end
    end

    -- world events           -- has to stay on bottom
    if pin.context ~= nil and FyrMM.SV.WorldEvents then
       if pin.weDistance then
            if GetMapType() == MAPTYPE_SUBZONE then -- world events within X subzone map are displayed on border
                local distance = CurrentMap.TrueMapSize or 1
				        if pin.nX == nil or pin.nY == nil then return false end
                local weDistance = distance *zo_sqrt((pin.nX - CurrentMap.PlayerNX) * (pin.nX - CurrentMap.PlayerNX) + (pin.nY - CurrentMap.PlayerNY) * (pin.nY - CurrentMap.PlayerNY))
                Tracked = (weDistance <= distance)
                -- d(CurrentMap.filename.." subzone tms "..distance.." dist "..weDistance)
            else -- world events within zone map / 8 are displayed on border
				        local TrueMapSize = CurrentMap.TrueMapSize or 1
                local distance = TrueMapSize / 8
                Tracked = (pin.weDistance <= distance)
                 --d(CurrentMap.filename.." tms "..distance.." dist "..pin.weDistance)
            end
        else
            Tracked = false
        end
    end
	
	
    return not Visible and Tracked
end

local function GetNumBorderPins()
    local totalPins = Fyr_MM_Axis_Border_Pins:GetNumChildren()
    local count = 0
    for index = 1, totalPins do
        local borderPinChild = Fyr_MM_Axis_Border_Pins:GetChild(index)
        if borderPinChild then
            if borderPinChild.pin then
                count = count + 1
            else
                borderPinChild:SetHidden(true)
            end
        end
    end
    return count
end

local function RemoveBorderPin(pin) 
    if pin == nil then
        return
    end
	pin:ClearAnchors()
    pin:SetHidden(true)
    pin:SetMouseEnabled(false)

    -- stop any leftover ZOS texture-frame animation before this control is recycled for a
    -- different pin type, otherwise the stale timeline keeps stepping frames on whatever
    -- static texture gets assigned next (border pin "randomly animates" bug)
    if pin.m_textureAnimTimeline then
        if pin.m_textureAnimTimeline ~= "yes" then
            pin.m_textureAnimTimeline:Stop()
        end
        pin.m_textureAnimTimeline = nil
    end

    if pin.pin then
        if pin.pin.OnBorder then
            pin.pin.OnBorder = nil
        end
        if pin.pin.BorderPin then
            pin.pin.BorderPin = nil
        end
    end

    pin.pin = nil -- clear the border pin's own forward reference so GetNewBorderPinIndex()
                  -- can recognize and recycle this slot instead of always allocating a new one
end

local function CleanUpMisc()
    local gameTime = GetGameTimeMilliseconds()
    if not IsInAvAZone() or (CurrentMap.MapId < 578 and CurrentMap.MapId > 571 and FyrMM.dirtyLinks) then
        KeepIndex = {}
        local LinksDone = false
        local LinksNSDone = false
        local LinksWEDone = false
        local LocksDone = false
		local l
        for index = 1, 100 do
            l = GetControl(string.format("Fyr_MM_Scroll_Map_Links_Link%s", index))
            if l ~= nil then
                l:ClearAnchors()
                l:SetHidden(true)
                l:SetMouseEnabled(false)
            else
                LinksDone = true
            end
            l = GetControl(string.format("Fyr_MM_Scroll_Map_LinksNS_Link%s", index))
            if l ~= nil then
                l:ClearAnchors()
                l:SetHidden(true)
                l:SetMouseEnabled(false)
            else
                LinksNSDone = true
            end
            l = GetControl(string.format("Fyr_MM_Scroll_Map_LinksWE_Link%s", index))
            if l ~= nil then
                l:ClearAnchors()
                l:SetHidden(true)
                l:SetMouseEnabled(false)
            else
                LinksWEDone = true
            end
            l = GetControl(string.format("Fyr_MM_Scroll_Map_Locks_Lock%s", index))
            if l ~= nil then
                l:ClearAnchors()
                l.normalizedX = nil
                l.normalizedY = nil
                l:SetHidden(true)
                l:SetMouseEnabled(false)
                l:SetDimensions(0, 0)
            else
                LocksDone = true
            end
            -- 03/07/2026: Reverted the 02/07/2026 "break" optimization here at the user's request
            -- while investigating a reported Cyrodiil link-position regression. Restored to
            -- original behavior (all 100 iterations always run) until the cause is confirmed.
            if LinksDone and LinksNSDone and LinksWEDone and LocksDone then
                index = 100
            end
			
        end
		FyrMM.dirtyLinks = false
    end

    FyrMM.CustomPinCount = 0
    FreeCustomPinIndex = {}
    CustomPinIndex = {}
    CustomPinKeyIndex = {}
    LastCustomPinIndex = 0
    FyrMM.Reloading = false

    FyrMM.InitialPreload()


    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", string.format("CleanUpMisc %s", GetGameTimeMilliseconds() - gameTime))
    end
end

function FyrMM.RemoveCustomPin(p)
    if p == nil then 
	-- d("FyrMM.RemoveCustomPin pin is nil") 
        return
    end

    if p.BorderPin then
        RemoveBorderPin(p.BorderPin)
    end
    
    p.radius = p.radius or 0
    p.nX = p.nX or 0
    p.nY = p.nY or 0
    
	
	  local Type = p.m_PinType

    local key = string.format("%s:%s:%s", p.nX, p.nY, p.radius)
    if p.m_PinType and FyrMM.CustomPinCheckList[p.m_PinType] and FyrMM.CustomPinCheckList[p.m_PinType][key] then
        FyrMM.CustomPinCheckList[p.m_PinType][key].Id = 0
    end
	
    p:ClearAnchors()
    p:SetHidden(true)
    p.m_PinTag = nil
    p.MapId = nil
    p.radius = nil
    p.nX = nil
    p.nY = nil
    p.IsTreasure = nil
    p.IsAvailableQuest = nil
    p.pinTexture = nil


    -- if p.Key == nil then d("p.Key == nil, could not remove that pin") end
    -- if p.Index == nil then d("p.Index == nil, could not remove that pin") end

    if FyrMM.CustomPinList[p.m_PinType] and FyrMM.CustomPinList[p.m_PinType][p.Key] and FyrMM.CustomPinList[p.m_PinType][p.Key].pin then
        FyrMM.CustomPinList[p.m_PinType][p.Key].pin = nil
        FyrMM.CustomPinList[p.m_PinType][p.Key] = nil
    end

    if not ZO_IsTableEmpty(CustomPinIndex) then
        if p.Index then
            table.insert(FreeCustomPinIndex, p.Index)
            FyrMM.CustomPinCount = FyrMM.CustomPinCount - 1
        end

        if CustomPinIndex[p.m_PinType] and p.Index and CustomPinIndex[p.m_PinType][p.Index] then
            CustomPinIndex[p.m_PinType][p.Index] = nil
        end
    end
	
	if p.Key ~= nil and p.m_PinType ~= nil and not ZO_IsTableEmpty(CustomPinKeyIndex) then
		CustomPinKeyIndex[p.m_PinType][p.Key] = nil
	end

    if p:GetName() and PinsList[p:GetName()] then
	    PinsList[p:GetName()]:ClearAnchors()
		PinsList[p:GetName()]:SetHidden(true)
        PinsList[p:GetName()] = nil
    end

    p.Key = nil
    p.m_PinType = nil
    p.Index = nil

	if p.tertiaryPin then
		FyrMM.RemoveCustomPin(p.tertiaryPin)
	end
  
	if p.secondaryPin then
		FyrMM.RemoveCustomPin(p.secondaryPin)
	end
	
	-- if p.primaryPin then -- this causes a loop, don't do!
		-- FyrMM.RemoveCustomPin(p.primaryPin)
	-- end
	
    p = nil
    -- d("pin was removed")
	--FyrMM.AddCustomPinTypesToCheckForConsistence(Type) -- test 03/08/2023
end



-- function FyrMM.AddCustomPinTypesToCheckForConsistence(Type)
     -- if Type == nil or Type <= MAP_PIN_TYPE_INVALID or Type == 9999 then return end 
     -- FyrMM.CustomPinTypesToCheckForConsistence = FyrMM.CustomPinTypesToCheckForConsistence or {}
	 -- FyrMM.CustomPinTypesToCheckForConsistence[Type] = true
-- end


function FyrMM.CheckCustomPinConsistence(Type)
    --d("check custom pin for consistence "..Type)
    local pin
    if Type == nil then
        for i, n in pairs(CustomPinKeyIndex) do
            if FyrMM.CustomPinList[i] == nil then
                for j, index in pairs(n) do
                    pin = GetControl(string.format("Fyr_MM_Scroll_Map_Pins_Pin%s", index))
                    FyrMM.RemoveCustomPin(pin)
                    --CustomPinKeyIndex[i][j] = nil
                end
            else
                if #n ~= #FyrMM.CustomPinList[i] then
                    for j, index in pairs(n) do
                        if FyrMM.CustomPinList[i][j] == nil then
                            pin = GetControl(string.format("Fyr_MM_Scroll_Map_Pins_Pin%s", index))
                            FyrMM.RemoveCustomPin(pin)
                            --CustomPinKeyIndex[i][j] = nil
						end
                    end
                end
            end
        end
    else
		
        if CustomPinKeyIndex[Type] == nil then
		    --d("no CustomPinKeyIndex for "..Type)
            return
        end
		
        if FyrMM.CustomPinList[Type] == nil then
            for j, index in pairs(CustomPinKeyIndex[Type]) do
                pin = GetControl(string.format("Fyr_MM_Scroll_Map_Pins_Pin%s", index))
                FyrMM.RemoveCustomPin(pin)
                --CustomPinKeyIndex[Type][j] = nil
            end
        else
            if #CustomPinKeyIndex[Type] ~= #FyrMM.CustomPinList[Type] then
                for j, index in pairs(CustomPinKeyIndex[Type]) do
                    if FyrMM.CustomPinList[Type][j] == nil then
                        pin = GetControl(string.format("Fyr_MM_Scroll_Map_Pins_Pin%s", index))
                        FyrMM.RemoveCustomPin(pin)
                        --CustomPinKeyIndex[Type][j] = nil
                    end
				end
			     
			    -- d("list for "..Type.." is ok "..#FyrMM.CustomPinList[Type])
			end
        end
    end
end

local function CleanUpPins()
    -- faster ways for cleaning up pins result in occasional pins not removing

    if ZO_IsTableEmpty(PinsList) then
        FyrMM.Reloading = false
        return
    end

    local cui = 0
    local chunk = FyrMM.SV.ChunkSize or 50
    local delay = FyrMM.SV.ChunkDelay or 50
	
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", string.format("CleanUpPins Start: %s - %s", chunk, delay)) 
    end

    EVENT_MANAGER:RegisterForUpdate("FyrMiniMapCleanupPinsTask", delay, function()
        local count = 0
        local isCustomPin = false
        cui = cui + 1
        local gameTime = GetGameTimeMilliseconds()
        for index, pin in pairs(PinsList) do
            count = count + 1

            if count >= chunk then
                if FyrMM.DebugMode then
                    CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", string.format("CleanUpPins  %s %s", cui, GetGameTimeMilliseconds() - gameTime))
                end
                return
            end

            if pin then
                if pin.m_PinType and pin.m_PinType >= MAP_PIN_TYPE_INVALID then -- is custom pin
                    FyrMM.RemoveCustomPin(pin)
                    isCustomPin = true
                end

                if not isCustomPin then -- is regular pin
                    if pin.BorderPin then
                        RemoveBorderPin(pin.BorderPin)
                    end
                    pin:ClearAnchors() 
                    pin:SetHidden(true)
                    pin:SetMouseEnabled(false)
                    pin.nX = nil
                    pin.nY = nil
                    pin:ClearAnchors()
                    pin:SetHidden(true)
                    pin:SetMouseEnabled(false)
                    pin:SetDimensions(0, 0)
                    pin.m_PinTag = nil
                    pin.m_PinType = nil
                    pin.m_Pin = nil
                    pin.IsAvailableQuest = nil
                    pin.normalizedX = nil
                    pin.normalizedY = nil
                    pin.radius = nil
                    pin.MapId = nil
                    pin.Index = nil
                    pin.questName = nil
                    pin.PinToolTipText = nil
                    pin.primaryPin = nil
                    pin.secondaryPin = nil
                    pin.tertiaryPin = nil
                    pin.MM_Tag = nil
                    pin.pinAge = nil
                    pin.IsTreasure = nil
                    pin.isDps = nil
                    pin.isHeal = nil
                    pin.isTank = nil
                    pin.ClassId = nil
                    pin.isLeader = nil
                    PinsList[index] = nil
                end
            end
			
            if ZO_IsTableEmpty(PinsList) then
                if FyrMM.DebugMode then
                    CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "CleanUpPins Done. "..tostring(GetGameTimeMilliseconds() - gameTime))
                end
                EVENT_MANAGER:UnregisterForUpdate("FyrMiniMapCleanupPinsTask")
                CleanUpMisc()
                return
            end
        end
    end)
end

local function GetNewBorderPinIndex()
    -- 02/07/2026 optimization: Previously called GetNumChildren() up to 4 times and could run
    -- two full loops over every border-pin child (one hidden inside GetNumBorderPins just to
    -- decide whether a free slot might exist, one to actually find it). A single pass searching
    -- directly for a free slot returns the identical index with a third of the work. The
    -- SetHidden(true) that GetNumBorderPins used to do for orphaned slots is already performed
    -- at every site that clears pin.BorderPin.pin, so nothing is lost by not calling it here.
    local numChildren = Fyr_MM_Axis_Border_Pins:GetNumChildren()
    if numChildren == 0 then
        return 1
    end

    for i = 1, numChildren do
        local l = Fyr_MM_Axis_Border_Pins:GetChild(i)
        if l and l.pin == nil then
            return i
        end
    end

    return numChildren + 1
end

local function GetTextureForBorderPin(pin)
    local texture = pin.pinTexture

    if pin.IsTreasure and texture then
        return texture
    end

    if pin.IsDragonNextLocation and texture then
        return texture
    end

    if pin.IsAvailableQuest then
        if pin.m_PinTag.isZoneStory or ZO_MapPin.SUGGESTION_PIN_TYPES[pin.m_PinType] then -- zone stories
            if pin.m_PinType == MAP_PIN_TYPE_SKYSHARD_SUGGESTED then
                return "EsoUI/Art/MapPins/skyshard_seen.dds"
            end

            return "esoui/art/lfg/gamepad/lfg_menuicon_zonestories.dds"
        end

        if texture then
            return texture
        end
    end

    if pin.borderInformation then -- antiquities
        return "/esoui/art/icons/servicemappins/servicepin_antiquities.dds"
    end
	
	if pin.radius and pin.radius > 0 then -- areapin
		pin.isAreaPin = true
	    return "MiniMap/Textures/opaque_map_areaPin.dds" 
	end

    if pin.m_PinType == MAP_PIN_TYPE_PLAYER_WAYPOINT then
        return "EsoUI/Art/MapPins/UI_Worldmap_pin_customDestination.dds"
    end

    if pin.m_PinType == MAP_PIN_TYPE_RALLY_POINT then
        return ZOpinData[MAP_PIN_TYPE_RALLY_POINT].texture --return "MiniMap/Textures/rally.dds"
    end

    if pin.m_PinType == MAP_PIN_TYPE_PING then
        return "MiniMap/Textures/ping.dds"
    end

    if pin.m_PinType == MAP_PIN_TYPE_LOCATION and pin.m_PinTag[2] then
        return pin.m_PinTag[2]
    end

    if (pin.m_PinType == MAP_PIN_TYPE_GROUP or pin.m_PinType == MAP_PIN_TYPE_GROUP_LEADER) and texture then
        return texture
    end

    if pin.m_PinType == MAP_PIN_TYPE_ACTIVE_COMPANION and texture then
        return texture
    end
     
    if pin.context then
        return texture
		-- dragons & world events
    end
	
	if pin.m_PinType == MAP_PIN_TYPE_SKYSHARD_COMPLETE or pin.m_PinType == MAP_PIN_TYPE_SKYSHARD_SEEN or pin.m_PinType ==  MAP_PIN_TYPE_SKYSHARD_SUGGESTED then 
	    return texture
		-- skyshards
	end
	
	if ZO_MapPin.KEEP_PIN_TYPES[pin.m_PinType] or pin.m_PinType == MAP_PIN_TYPE_KEEP_ATTACKED_LARGE or pin.m_PinType == MAP_PIN_TYPE_KEEP_ATTACKED_SMALL then 
	    return texture
		--- keeps & UA keeps
	end

    if QUEST_PIN_TYPES[pin.m_PinType] then
        if pin.m_PinTag.isBreadcrumb then
            return breadcrumbQuestPinTextures[pin.m_PinType]
        end

        return questPinTextures[pin.m_PinType]
    end

    if pin.m_Pin and pin.m_Pin:IsFastTravelWayShrine() then
        if pin.m_Pin.m_PinTag[2] then
            return pin.m_Pin.m_PinTag[2]
        end
        return "/esoui/art/icons/poi_wayshrine_complete.dds"
    end

    if OBJECTIVE_PIN_TYPES[pin.m_PinType] or ZO_MapPin.RETURN_OBJECTIVE_PIN_TYPES[pin.m_PinType] or
        ZO_MapPin.SPAWN_OBJECTIVE_PIN_TYPES[pin.m_PinType] then
        return ZO_MapPin.PIN_DATA[pin.m_PinType].texture
		-- AVA and Battlegrounds
    end

    if pin.m_PinType == 9999 then
        return "MiniMap/Textures/scroll_aura.dds"
        -- Elder Scroll aura
    end
end

local function ProcessQuestPinClick(pin)
    local PinHandlers = {}
    local Pins = {}
    local HandlerCount = 0
    local Handler = {}
    local entries = {}
    local entry = ""
    Handler.Callback = function(questIndex)
        FOCUSED_QUEST_TRACKER:ForceAssist(questIndex)
    end
    Handler.Name = zo_strformat(SI_WORLD_MAP_ACTION_SELECT_QUEST, GetJournalQuestName(pin.questIndex))
    table.insert(PinHandlers, Handler)
    table.insert(Pins, pin)
    for i = 1, FyrMM.questPinCount do
        local p = GetControl("Fyr_MM_Scroll_Map_QuestPins_Pin" .. tostring(i))
        if p ~= nil then
            if p ~= pin and p.normalizedX == pin.normalizedX and p.normalizedY == pin.normalizedY and not p:IsHidden() then
                entry = zo_strformat(SI_WORLD_MAP_ACTION_SELECT_QUEST, GetJournalQuestName(p.questIndex))
                if not valueExists(entry, entries) then
                    HandlerCount = HandlerCount + 1
                    local Handler = {}
                    Handler.Callback = function(questIndex)
                        FOCUSED_QUEST_TRACKER:ForceAssist(questIndex)
                    end
                    Handler.Name = zo_strformat(SI_WORLD_MAP_ACTION_SELECT_QUEST, GetJournalQuestName(p.questIndex))
                    table.insert(PinHandlers, Handler)
                    table.insert(Pins, p)
                    table.insert(entries, entry)
                end
            end
        end
    end
    if HandlerCount <= 1 then
        PinHandlers[1].Callback(Pins[1].questIndex)
    else
        ClearMenu()
        for i = 1, HandlerCount do
            local Handler = PinHandlers[i]
            local questIndex = Pins[i].questIndex
            local Name = Handler.Name
            if type(Name) == "function" then
                Name = Name(Pins[i])
            end
            AddMenuItem(Name, function()
                Handler.Callback(questIndex)
            end)
        end
        ShowMenu(pin)
    end
end

function FyrMM.PinOnMouseExit(pin)
    if pin == nil then
        return
    end
    FyrMM.SetTargetScale(pin, 1)
    if pin.m_PinType == MAP_PIN_TYPE_LOCATION then
        ClearTooltip(ZO_MapLocationTooltip)
    else
        ClearTooltip(InformationTooltip)
    end
end

function FyrMM.PinOnMouseEnter(pin) 
    FyrMM.SetTargetScale(pin, 1.3)
    if not FyrMM.SV.PinTooltips then
        return
    end
	
    if pin.pinType ~= nil then -- antiquities
        if pin.pinType == MAP_PIN_TYPE_TRACKED_ANTIQUITY_DIG_SITE or pin.pinType == MAP_PIN_TYPE_ANTIQUITY_DIG_SITE then
            InitializeTooltip(InformationTooltip, Fyr_MM, TOPLEFT, 0, 0)
            InformationTooltip:AddLine(GetString(SI_GAMEPAD_MAIN_MENU_JOURNAL_ANTIQUITIES), FyrMM.HeaderFontType, ZO_WHITE:UnpackRGB())
			      ZO_Tooltip_AddDivider(InformationTooltip)
            InformationTooltip:AppendDigSiteAntiquities(pin.Tag)
			      return
        end
    end	
	
    if pin.m_PinType ~= nil then
       if pin.context ~= nil then  -- world events and dragons
            if pin.context == 9999 then -- dynamic encounter
                  if ZO_MapPin.TOOLTIP_CREATORS[MAP_PIN_TYPE_LOCATION].tooltip then
                      InitializeTooltip(ZO_MapLocationTooltip, Fyr_MM, TOPLEFT, 0, 0)
                      ZO_MapPin.TOOLTIP_CREATORS[MAP_PIN_TYPE_LOCATION].creator(pin.m_Pin)
                  end
            else -- other worls events
                InitializeTooltip(InformationTooltip, Fyr_MM, TOPLEFT, 0, 0)
                InformationTooltip:AddLine(GetString(SI_ZONECOMPLETIONTYPE8), FyrMM.HeaderFontType, ZO_WHITE:UnpackRGB())
			          ZO_Tooltip_AddDivider(InformationTooltip)
                InformationTooltip:AddLine(zo_strformat(SI_WORLD_MAP_LOCATION_NAME, pin.name), FyrMM.DefaultFontType, ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB())
            end
            IsCurrentLocation(pin)
            return 
        elseif QUEST_PIN_TYPES[pin.m_PinType] then -- quests
            InitializeTooltip(InformationTooltip, Fyr_MM, TOPLEFT, 0, 0)
			      InformationTooltip:AddLine(GetString(SI_GUILDACTIVITYATTRIBUTEVALUE6), FyrMM.HeaderFontType, ZO_WHITE:UnpackRGB())
			      ZO_Tooltip_AddDivider(InformationTooltip)
            SetQuestTooltip(pin)
            IsCurrentLocation(pin)
            return
        elseif pin.skyshardId then -- skyshards
            InitializeTooltip(InformationTooltip, Fyr_MM, TOPLEFT, 0, 0)
			      InformationTooltip:AddLine(GetZoneNameByIndex(CurrentMap.ZoneIndex).." "..GetString(SI_GAMEPAD_SKILLS_SKY_SHARDS), FyrMM.HeaderFontType, ZO_WHITE:UnpackRGB()) 
			      ZO_Tooltip_AddDivider(InformationTooltip)
            InformationTooltip:AppendSkyshardHint(pin.skyshardId)
			      InformationTooltip:AddLine(zo_strformat(SI_WORLD_MAP_SKYSHARD_STATUS_FORMATTER, pin.status), FyrMM.DefaultFontType, ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB())
            IsCurrentLocation(pin)
            return	
        elseif ZONE_EXPLORATION_PIN_TYPES[pin.m_PinType] then -- suggested & exploration
            if ZO_MapPin.TOOLTIP_CREATORS[pin.m_PinType] == nil then
                return
            end
            if ZO_MapPin.TOOLTIP_CREATORS[pin.m_PinType].tooltip then
                InitializeTooltip(InformationTooltip, Fyr_MM, TOPLEFT, 0, 0)
            end
			      local zoneId, zoneCompletionType, activityId = GetTrackedZoneStoryActivityInfo()
            local shortDescription = GetZoneStoryShortDescriptionByActivityId(zoneId, zoneCompletionType, activityId)
			      InformationTooltip:AddLine(GetString(SI_ZONE_STORY_INFO_HEADER), FyrMM.HeaderFontType, ZO_WHITE:UnpackRGB())
		        ZO_Tooltip_AddDivider(InformationTooltip)
		      	InformationTooltip:AddLine(shortDescription, FyrMM.DefaultFontType, ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB())
            IsCurrentLocation(pin)
        elseif CustomWaypoints[pin.m_PinType] then -- waypoints
            if ZO_MapPin.TOOLTIP_CREATORS[pin.m_PinType] then
                if ZO_MapPin.TOOLTIP_CREATORS[pin.m_PinType].tooltip and
                    ZO_MapPin.TOOLTIP_CREATORS[pin.m_PinType].creator then
                    InitializeTooltip(InformationTooltip, Fyr_MM, TOPLEFT, 0, 0)
                    ZO_MapPin.TOOLTIP_CREATORS[pin.m_PinType].creator(pin)
                    IsCurrentLocation(pin)
                    return
                end
            end
        elseif ZO_MapPin.FAST_TRAVEL_WAYSHRINE_PIN_TYPES[pin.m_PinType] or ZO_MapPin.POI_PIN_TYPES[pin.m_PinType] then -- wayshrines & portable locations
            InitializeTooltip(InformationTooltip, Fyr_MM, TOPLEFT, 0, 0)
            SetTooltipMessage(pin.m_Pin)
            if not ZO_MapPin.FAST_TRAVEL_WAYSHRINE_PIN_TYPES[pin.m_PinType] then
                IsCurrentLocation(pin)
            end
            return
        elseif pin.m_PinType == MAP_PIN_TYPE_LOCATION then -- locations
            if ZO_MapPin.TOOLTIP_CREATORS[MAP_PIN_TYPE_LOCATION].tooltip then
                InitializeTooltip(ZO_MapLocationTooltip, Fyr_MM, TOPLEFT, 0, 0)
                ZO_MapPin.TOOLTIP_CREATORS[MAP_PIN_TYPE_LOCATION].creator(pin.m_Pin)
                IsCurrentLocation(pin)
                return
            end
        elseif ZO_MapPin.GROUP_PIN_TYPES[pin.m_PinType] then -- group
            InitializeTooltip(InformationTooltip, Fyr_MM, TOPLEFT, 0, 0)
			      InformationTooltip:AddLine(GetString(SI_MAPFILTER9), FyrMM.HeaderFontType, ZO_WHITE:UnpackRGB())
		      	ZO_Tooltip_AddDivider(InformationTooltip)
            InformationTooltip:AppendUnitName(pin.unitTag)
			if pin.isLeader then
			   InformationTooltip:AddLine(GetString(SI_GROUP_LEADER_TOOLTIP), FyrMM.DefaultFontType, ZO_HIGHLIGHT_TEXT:UnpackRGB()) 
			end
			local level = GetUnitLevel(pin.unitTag) 
			if level == 50 then
			    level = zo_strformat(SI_ENCHANTING_GLYPH_CREATED_CHAMPION_LEVEL, GetUnitChampionPoints(pin.unitTag)) 
			else
			    level = zo_strformat(SI_LEVEL_DISPLAY, GetString(SI_EXPERIENCE_LEVEL_LABEL), level)  
			end 
			local class = " "..GetUnitClass(pin.unitTag)
			local race = " "..GetUnitRace(pin.unitTag)
			local role = ""
			if pin.isDps then
			       role = "|t32:32:EsoUI/Art/LFG/LFG_dps_down.dds|t"
			elseif pin.isHeal then
			       role = "|t32:32:EsoUI/Art/LFG/LFG_healer_down.dds|t" 
			elseif pin.isTank then
			       role = "|t32:32:EsoUI/Art/LFG/LFG_tank_down.dds|t"
			end

			InformationTooltip:AddLine(level..class..race..role, FyrMM.DefaultFontType, ZO_WHITE:UnpackRGB())

			if IsPlayerInAvAWorld() or IsActiveWorldBattleground() then -- we add group member rank info when necessary
			   local rank = GetUnitAvARank(pin.unitTag)
			   local rankName = GetAvARankName(GetUnitGender(pin.unitTag), rank)
			   local rankIcon = GetLargeAvARankIcon(rank)
			   InformationTooltip:AddLine("|t32:32:"..rankIcon.."|t"..rankName, FyrMM.DefaultFontType, ZO_WHITE:UnpackRGB())   
			end
			
            IsCurrentLocation(pin)
            return
        elseif pin.m_PinType == MAP_PIN_TYPE_ACTIVE_COMPANION then -- companions
            InitializeTooltip(InformationTooltip, Fyr_MM, TOPLEFT, 0, 0)
			      InformationTooltip:AddLine(GetString(SI_MAPFILTER14), FyrMM.HeaderFontType, ZO_WHITE:UnpackRGB())
		      	ZO_Tooltip_AddDivider(InformationTooltip)
            InformationTooltip:AppendUnitName(pin.unitTag)
		      	local level = GetUnitLevel(pin.unitTag)
			      InformationTooltip:AddLine(zo_strformat(SI_LEVEL_DISPLAY, GetString(SI_EXPERIENCE_LEVEL_LABEL), level), FyrMM.DefaultFontType, ZO_WHITE:UnpackRGB())
            IsCurrentLocation(pin)
            return	
        elseif pin.m_PinType >= MAP_PIN_TYPE_INVALID then -- custom pins: has to stay on bottom
            if ZO_MapPin.TOOLTIP_CREATORS[pin.m_PinType] then
                if ZO_MapPin.TOOLTIP_CREATORS[pin.m_PinType].tooltip and
                    ZO_MapPin.TOOLTIP_CREATORS[pin.m_PinType].creator then
                    InitializeTooltip(InformationTooltip, Fyr_MM, TOPLEFT, 0, 0)
                    ZO_MapPin.TOOLTIP_CREATORS[pin.m_PinType].creator(pin.mpin)
                    IsCurrentLocation(pin)
                    return
                end
            end
        end
    end
end

local function PinOnMouseUp(pin)
    FyrMM.SetTargetScale(pin, 1.3)
    if not FyrMM.SV.PinTooltips then
        return
    end
    if pin.m_PinType ~= nil then
        if QUEST_PIN_TYPES[pin.m_PinType] then
            ProcessQuestPinClick(pin)
            FyrMM.UpdateQuestPins()
        end
        if ZO_MapPin.FAST_TRAVEL_WAYSHRINE_PIN_TYPES[pin.m_PinType] then
            if not IsInAvAZone() and FyrMM.SV.FastTravelEnabled then
                if IsCurrentLocation(pin.m_Pin) then
                    return
                end -- No need to recall if player is near wayshrine
                local nodeIndex = pin.m_Pin:GetFastTravelNodeIndex()
                ZO_Dialogs_ReleaseDialog("FAST_TRAVEL_CONFIRM")
                local name = select(2, GetFastTravelNodeInfo(nodeIndex))
                ZO_Dialogs_ShowDialog("FAST_TRAVEL_CONFIRM", {
                    nodeIndex = nodeIndex,
                    recall = true
                }, {
                    mainTextParams = { name }
                })
            end
        end
    end
end

function FyrMM.BorderPinOnMouseExit(pin)
    if pin == nil then
        return
    end
    if pin.pin == nil then
        return
    end
    FyrMM.SetTargetScale(pin, 1)
	
	if pin.pin.tooltipId then 
	   FyrMM.AvAPinOnMouseExit(pin.pin)
       return
	end
	
	if pin.pin then -- test 04/09/2023
	   FyrMM.PinOnMouseExit(pin.pin)
	   return 
	end
end

function FyrMM.BorderPinOnMouseEnter(pin) 
    if pin.pin == nil then
        RemoveBorderPin(pin)
        return
    end
	
    FyrMM.SetTargetScale(pin, 1.3)
    if not FyrMM.SV.PinTooltips then
        return
    end
	
	if pin.pin.tooltipId then 
	   FyrMM.AvAPinOnMouseEnter(pin.pin)
	   return
	end
	
	if pin.pin then -- test 04/09/2023
	   FyrMM.PinOnMouseEnter(pin.pin)
	   return 
	end 
end

local function SetBorderPinHandlers(pin)
    if pin == nil then
        -- 03/07/2026 optimization: This branch is called unconditionally, for every player
        -- regardless of settings, on every PlaceWaypointBorderPins() call (itself part of the
        -- ~60ms PlaceBorderPins tick). It looked up controls named "Fyr_MM_Axis_Border_Pins_Pin"..i,
        -- but that name is never created anywhere in the addon - real border pin slots are named
        -- "Fyr_MM_Axis_Border_Pin"..i (see CreateBorderPin above), without the extra "s". Because
        -- of that mismatch GetControl() always found nothing and the loop returned after its very
        -- first iteration, so this cleanup pass never actually removed anything - it only ever
        -- burned one wasted string concatenation + name lookup per call. Same bug class as the
        -- 02/07/2026 fix above; removed rather than "fixed" since it has never been functional and
        -- no other code path relies on its (nonexistent) effect.
        return
    end
    pin:SetHandler("OnMouseEnter", FyrMM.BorderPinOnMouseEnter)
    pin:SetHandler("OnMouseExit", FyrMM.BorderPinOnMouseExit)
    pin:SetMouseEnabled(true)
end

function FyrMM.CreateBorderPin(pin) -- Should have been called create / update border pin
	
	if pin == nil then
        return
    end
    if pin.m_PinType == nil then
        return
    end
    local borderpin

    local pdata = ZO_MapPin.PIN_DATA[pin.m_PinType]
    local bpsize

    if pin.m_PinType == 9999 then -- Elder Scroll aura
        bpsize = 64
    elseif pdata == nil or pdata.size == nil then
        bpsize = 32
    else
        bpsize = pdata.size
    end

    if not FyrMM.IsValidBorderPin(pin) or not FyrMM.SV.BorderPins then
        if pin.BorderPin then -- was "if not" WTF???
            RemoveBorderPin(pin.BorderPin)
        end
        return
	end
	
	-- note : Systematically removing borderpins causes huge lag


    local mmWidth, mmHeight = Fyr_MM:GetDimensions()
    local mmX, mmY = Fyr_MM_Player:GetRight(), Fyr_MM_Player:GetTop()
    local pinX, pinY = abs(pin:GetRight() - mmX), abs(pin:GetTop() - mmY)
    local m = 0
    if pinX ~= 0 then
        m = pinY / pinX
    end
    local D = mmWidth / 2 - ((38 / 512) * mmWidth)
    local newX, newY
    local na = math.atan((mmWidth / 2) / (mmHeight / 2))
    local nb = pi * 0.5 - na
    local pa = math.atan(pinX / (pinY))
    local pb = pi * 0.5 - pa

    if not pin.OnBorder and pin.BorderPin == nil then
        local index = GetNewBorderPinIndex() 
        borderpin = GetControl("Fyr_MM_Axis_Border_Pin"..tostring(index))
        if borderpin == nil then
            borderpin = WINDOW_MANAGER:CreateControl("Fyr_MM_Axis_Border_Pin"..tostring(index), Fyr_MM_Axis_Border_Pins, CT_TEXTURE)
        end
		borderpin.index = index
    else
        if pin.BorderPin and pin.BorderPin.index then
		    borderpin = GetControl("Fyr_MM_Axis_Border_Pin"..tostring(pin.BorderPin.index))
			if borderpin == nil then 
			   RemoveBorderPin(pin.BorderPin)
			   return
            end			
		else
		    RemoveBorderPin(pin.BorderPin)
			return
		end   
    end
	
	  pin.BorderPin = borderpin
    borderpin.pin = pin
	

    SetBorderPinHandlers(borderpin)
    pin.OnBorder = true
    borderpin:SetTexture(GetTextureForBorderPin(pin))

   

	if pin.questIndex and FyrMM.SV.BorderPinsOnlyAssisted then -- assisted quest pins
	   -- system to avoid quest border pins duplicates
	   
	   for i = 1, Fyr_MM_Axis_Border_Pins:GetNumChildren() do
            local l = Fyr_MM_Axis_Border_Pins:GetChild(i)
            if l and l.pin and l.pin.questIndex == pin.questIndex and l.pin.normalizedX == pin.normalizedX and l.pin.normalizedY == pin.normalizedY then  
                l:SetHidden(true)
                --d("hide duplicate")				
            end
        end
           
       
	   local r,g,b,a = pin:GetColor()
	   borderpin:SetColor(r,g,b,a)
      
    elseif pin.borderInformation ~= nil then -- antiquities
        local antiquityIds = {GetInProgressAntiquitiesForDigSite(pin.Tag)}
        for index, antiquityId in pairs(antiquityIds) do 
            local antiquityData = ANTIQUITY_DATA_MANAGER:GetAntiquityData(antiquityId)
            if not antiquityData:IsInCurrentPlayerZone() then
			
			          if pin.BorderPin then -- fix for antiquities border pins of other zones showing
                   RemoveBorderPin(pin.BorderPin)
                end
                FyrMM.RemoveCustomPin(pin)
				        return	
            else 

                local c = GetAntiquityQualityColor(antiquityData:GetQuality())
                if c.r ~= nil then
                     borderpin:SetColor(c.r, c.g, c.b, c.a) -- last antiquityId gets the digsite quality color *shrug*
                else
                     borderpin:SetColor(1, 1, 1, 1)
                end
			      end	
        end

    -- group leader colour
    elseif (not FyrMM.SV.MemberRolesColor) and pin.isLeader then 
        borderpin:SetColor(FyrMM.SV.LeaderDeadPinColor.r, FyrMM.SV.LeaderDeadPinColor.g, FyrMM.SV.LeaderDeadPinColor.b, 1)
		-- colored group members
    elseif pin.isDps or pin.isHeal or pin.isTank then 
            borderpin:SetColor(pin:GetColor())
        -- coloured custom pins	
    elseif pin.m_PinType ~= nil and pin.context == nil and not (pin.m_PinTag and pin.m_PinTag.isZoneStory) then
        if pin.tint then -- compatibility with addons which modify pin colors by pin
            if type(pin.tint) ~= "function" then
                borderpin:SetColor(pin.tint:UnpackRGBA())
            else
                if type(pin.tint) == "table" then
                    borderpin:SetColor(pin.tint.r, pin.tint.g, pin.tint.b, pin.tint.a)
                end
            end
        elseif ZOpinData[pin.m_PinType] and ZOpinData[pin.m_PinType].tint and ZOpinData[pin.m_PinType].tint ~= nil then -- was only ZOpinData[pin.m_PinType].tint ~= nil 27/06/2023 
            if type(ZOpinData[pin.m_PinType].tint) ~= "function" then
                borderpin:SetColor(ZOpinData[pin.m_PinType].tint:UnpackRGBA())
            else
                if borderpin.pin.m_Pin ~= nil then
                    borderpin:SetColor(ZOpinData[pin.m_PinType].tint(borderpin.pin.m_Pin):UnpackRGBA())
                elseif borderpin.pin ~= nil then
                    borderpin:SetColor(ZOpinData[pin.m_PinType].tint(borderpin.pin):UnpackRGBA())
                else
                    borderpin:SetColor(1, 1, 1, 1)
                end
            end
        else
            borderpin:SetColor(1, 1, 1, 1)
        end
    end
	
    if pin.color then
        borderpin:SetColor(pin.color[1], pin.color[2], pin.color[3], 1)
    end
	
    if pinX > 0 and pinY > 0 then
        if pa <= na then
            if pin:GetRight() >= mmX then
                newX = mmWidth / 2 + mmHeight / 2 * zo_sin(pa) / zo_sin(pi * 0.5 - pa)
            else
                newX = mmWidth / 2 - mmHeight / 2 * zo_sin(pa) / zo_sin(pi * 0.5 - pa)
            end
            if pin:GetTop() < mmY then
                newY = 4
            else
                newY = mmHeight - (bpsize * FyrMM.pScalePercent) / 2 + 2
            end
        else
            if pin:GetRight() > mmX then
                newX = mmWidth - (bpsize * FyrMM.pScalePercent) / 2 + 4
            else
                newX = 2
            end
            pa = pi * 0.5 - (pa - na)
            if pin:GetTop() <= mmY then
                newY = mmHeight / 2 - mmWidth / 2 * zo_sin(pa - na) / zo_sin(pi * 0.5 - (pa - na))
            else
                newY = mmHeight / 2 + mmWidth / 2 * zo_sin(pa - na) / zo_sin(pi * 0.5 - (pa - na))
            end
        end
		
        if pin.m_PinType == MAP_PIN_TYPE_GROUP then
            FyrMM.SetPinSize(borderpin, pin:GetDimensions())
        else
            FyrMM.SetPinSize(borderpin, bpsize * FyrMM.pScalePercent, 0)
        end
		
        if FyrMM.SV.WheelMap then
            if pin:GetRight() >= mmX and pin:GetTop() >= mmY then
                newX = D / zo_sqrt(1 + m * m) + mmWidth / 2
                newY = (m * D) / zo_sqrt(1 + m * m) + mmHeight / 2
            end
            if pin:GetRight() >= mmX and pin:GetTop() < mmY then
                newX = D / zo_sqrt(1 + m * m) + mmWidth / 2
                newY = mmWidth / 2 - (m * D) / zo_sqrt(1 + m * m)
            end
            if pin:GetRight() < mmX and pin:GetTop() < mmY then
                newX = mmWidth / 2 - D / zo_sqrt(1 + m * m)
                newY = mmWidth / 2 - (m * D) / zo_sqrt(1 + m * m)
            end
            if pin:GetRight() < mmX and pin:GetTop() >= mmY then
                newX = mmWidth / 2 - D / zo_sqrt(1 + m * m)
                newY = (m * D) / zo_sqrt(1 + m * m) + mmWidth / 2
            end
        end

        borderpin:SetHidden(false)
        borderpin:ClearAnchors()
        borderpin:SetAnchor(CENTER, Fyr_MM_Axis_Control, TOPLEFT, newX, newY)

        -- animated world events
        if pin.context ~= nil then
            borderpin:SetColor(1, 1, 1, 1)
            if ZO_MapPin.WORLD_EVENT_UNIT_PIN_TYPES[pin.m_PinType] then -- Dragons, Cartoklepts, Arcane Knots, etc 
                if IsUnitInCombat(pin.unitTag) then
                    if pdata.isAnimated and borderpin.m_textureAnimTimeline == nil then
                     borderpin.m_textureAnimTimeline = "yes" 
                     FyrMM.PlayTextureAnimation(borderpin, pdata.framesWide, pdata.framesHigh, pdata.framesPerSecond, LOOP_INDEFINITELY, ANIMATION_PLAYBACK_LOOP)
                    end
				        else
                     if borderpin.m_textureAnimTimeline and borderpin.m_textureAnimTimeline ~= "yes" then 
                       borderpin.m_textureAnimTimeline:Stop()
                     end
                     borderpin.m_textureAnimTimeline = nil
                end
            else -- POI world events (anchors, harrowtorms, etc..;)
                if string.find(GetTextureForBorderPin(pin), "skirmish") then -- it's a night market skirmish, we treat it differently
                    if pdata.isAnimated and borderpin.m_textureAnimTimeline == nil then
                       borderpin.m_textureAnimTimeline = "yes"
                       FyrMM.PlayTextureAnimation(borderpin, pdata.framesWide, pdata.framesHigh, pdata.framesPerSecond, LOOP_INDEFINITELY, ANIMATION_PLAYBACK_LOOP)
                    end
                else
                    -- we won't animate that pin the ZOS way because I prefer my spinning huricane 8-)
                    FyrMM.CheapAnimation(borderpin, true)

                end
                
            end
        else
            borderpin:SetTransformRotationZ(0)
        end
		
        -- animated rally point border pin
        if pin == FyrMM.Rally then 
          local pdata = ZOpinData[MAP_PIN_TYPE_RALLY_POINT]
          if pdata.isAnimated and borderpin.m_textureAnimTimeline == nil then 
             borderpin.m_textureAnimTimeline = "yes"
             FyrMM.PlayTextureAnimation(borderpin, pdata.framesWide, pdata.framesHigh, pdata.framesPerSecond, LOOP_INDEFINITELY, ANIMATION_PLAYBACK_LOOP)
          end
          borderpin:SetDimensions(pdata.minSize, pdata.minSize)
        end

        -- zone story border pin
        if pin.m_PinTag and (pin.m_PinTag.isZoneStory or ZO_MapPin.SUGGESTION_PIN_TYPES[pin.m_PinType]) then
            borderpin:SetColor(1, 1, 1, 1)
            FyrMM.SetPinSize(borderpin, 48 * FyrMM.pScalePercent, 0)
        end
		
        borderpin:SetDrawLevel(pin:GetDrawLevel())
        borderpin:SetDrawTier(pin:GetDrawTier())
		    borderpin:SetDrawLayer(pin:GetDrawLayer())
	end

    if not pin.hasAura and not pin.isAreaPin and (pin.nX and pin.nY) or (pin.normalizedX and pin.normalizedY) and CurrentMap.TrueMapSize then -- fade distant border pin texture 
        local nX = pin.nX or pin.normalizedX
        local nY = pin.nY or pin.normalizedY

        local distance = CurrentMap.TrueMapSize * (zo_sqrt((nX - CurrentMap.PlayerNX) * (nX - CurrentMap.PlayerNX) + (nY - CurrentMap.PlayerNY) * (nY - CurrentMap.PlayerNY)) or 1)
        if not distance or distance > 650 then
            distance = 650
        end
        local iDistance = 650 - distance

        local minVal1 = 0   -- min distance value
        local maxVal1 = 650 -- max distance value
        local minVal2 = 0.6 -- min alpha
        local maxVal2 = 1   -- max alpha

        local alpha = ((maxVal2 - minVal2) * (((iDistance) - (minVal1)) / ((maxVal1) - (minVal1)))) + minVal2
		
		local mapAlpha = FyrMM.SV.MapAlpha/100 -- borderpin alpha shouldn't be higher than map alpha 
		if alpha > mapAlpha then
		   alpha  = mapAlpha
		end

        -- d("alpha "..alpha.." distance "..distance)
        borderpin:SetAlpha(alpha)
    else
	    local alpha = 1
	    local mapAlpha = FyrMM.SV.MapAlpha/100 -- borderpin alpha shouldn't be higher than map alpha 
		if alpha > mapAlpha then
		   alpha  = mapAlpha
		end
	
        borderpin:SetAlpha(alpha)
    end

    return borderpin
end

function FyrMM.PlaceBorderPins()
    local i, j, l, v
	
    if not FyrMM.Visible or Fyr_MM:IsHidden() then
        return
    end
	
    for i = 1, Fyr_MM_Axis_Border_Pins:GetNumChildren() do
        l = Fyr_MM_Axis_Border_Pins:GetChild(i)
        if l ~= nil then
            if FyrMM.SV.BorderPins then
                if l.pin == nil then
                    l:SetHidden(true)
                else
                    if not FyrMM.IsValidBorderPin(l.pin) then
                        RemoveBorderPin(l)
                    end
                end
            else
                RemoveBorderPin(l)
            end
        end
    end

    if not FyrMM.SV.BorderPins then
        return
    end

    -- border pins for moving or interesting AVA & Battleground pins
    if (not IsInAvAZone() and not IsActiveWorldBattleground()) and FyrMM.AVABGobjectivesToBorderPins then
        FyrMM.AVABGobjectivesToBorderPins = nil
    end
    if FyrMM.SV.borderAVABG then
        local bgContext = ZO_WorldMap_GetBattlegroundQueryType()
        if FyrMM.AVABGobjectivesToBorderPins and not ZO_IsTableEmpty(FyrMM.AVABGobjectivesToBorderPins) then
            for i, v in pairs(FyrMM.AVABGobjectivesToBorderPins) do
                if v ~= nil then
                    local type = GetObjectiveType(v.keepId, v.objectiveId, bgContext)
                    local objectiveControlState = GetObjectiveControlState(v.keepId, v.objectiveId, bgContext)
                    local exists = DoesObjectiveExist(v.keepId, v.objectiveId, bgContext)
                    local visible = IsObjectiveObjectVisible(v.keepId, v.objectiveId, bgContext)
                    local gameType = GetBattlegroundGameType(GetCurrentBattlegroundId())

                    if exists and visible then
                        local daedricWeapon = type == OBJECTIVE_DAEDRIC_WEAPON and objectiveControlState ~=
                            OBJECTIVE_CONTROL_STATE_UNKNOWN
                        local elderScroll = (type == OBJECTIVE_ARTIFACT_DEFENSIVE or type ==
                                OBJECTIVE_ARTIFACT_OFFENSIVE or type == OBJECTIVE_ARTIFACT_RETURN) and
                            (objectiveControlState == OBJECTIVE_CONTROL_STATE_FLAG_HELD or
                                objectiveControlState == OBJECTIVE_CONTROL_STATE_FLAG_DROPPED)
                        local captureTheRelicRelic = type == OBJECTIVE_FLAG_CAPTURE
                        local captureTheRelicOwnBase = v.AVABGtype == "spawn"
                        local showAllWithThisGameType = gameType == BATTLEGROUND_GAME_TYPE_DOMINATION or gameType == BATTLEGROUND_GAME_TYPE_CRAZY_KING or gameType == BATTLEGROUND_GAME_TYPE_MURDERBALL

                        if daedricWeapon or elderScroll or captureTheRelicRelic or captureTheRelicOwnBase or showAllWithThisGameType then
                            v.size = 32
                            if elderScroll then
                                v.size = 80
                            end
                            if battlegroundMovingPins then
                                v.size = 64
                            end
                            FyrMM.CreateBorderPin(v)
                        else
                            if v.BorderPin ~= nil then
                                RemoveBorderPin(v.BorderPin)
                            end
                        end
                    else
                        if v.BorderPin ~= nil then
                            RemoveBorderPin(v.BorderPin)
                        end
                    end
                end
            end
        end
    end

    -- waypoints
    FyrMM.PlaceWaypointBorderPins()

    -- border pins
    if Fyr_MM_Axis_Control:IsHidden() and FyrMM.SV.BorderPins then
        Fyr_MM_Axis_Control:SetHidden(false)
    end

    -- quest pins
    for i, v in pairs(QuestPins) do
        if not v.Pin:IsHidden() and FyrMM.IsValidBorderPin(v.Pin) then 
		    --d("create questpin borderpin")
            FyrMM.CreateBorderPin(v.Pin)
        end
    end

    -- 02/07/2026 optimization: Removed a dead loop that looked up controls named
    -- "Fyr_MM_Scroll_Map_Pinsgroup"..i, a name never created anywhere in the addon (real
    -- group pins are named "Fyr_MM_Scroll_Map_GroupPins_"..tag). It always found nil and did
    -- nothing, yet still burned up to 24 GetControl calls every call - and this function runs
    -- roughly every 60ms via RescalePinPositions, not just its nominal 2000ms timer.

    -- Bank - stables - crafting - community leveling guides
    -- 03/07/2026 optimization: Same GetControl()-by-name-every-call pattern as the keep loop above,
    -- but this one isn't Cyrodiil-only - it runs for any player with Border Pins Bank/Stables/
    -- Crafting/UseOriginalAPI enabled (very common settings), in every zone, on the same ~60ms
    -- PlaceBorderPins cadence. Location pin controls are also created once and reused by index
    -- (see the location pin build code) rather than destroyed between zones, so the same
    -- cache-on-first-lookup approach applies safely here.
    if FyrMM.SV.BorderPinsBank or FyrMM.SV.BorderPinsStables or FyrMM.SV.BorderCrafting or FyrMM.SV.UseOriginalAPI then
        FyrMM.LocationPinControlCache = FyrMM.LocationPinControlCache or {}
        for i = 1, FyrMM.currentLocationsCount do
            local l = FyrMM.LocationPinControlCache[i]
            if l == nil then
                l = GetControl("Fyr_MM_Scroll_Map_LocationPins_Pin" .. tostring(i))
                if l ~= nil then
                    FyrMM.LocationPinControlCache[i] = l
                end
            end
            if l ~= nil then
                if l.m_PinType == MAP_PIN_TYPE_LOCATION and FyrMM.IsValidBorderPin(l) then
                    FyrMM.CreateBorderPin(l)
                elseif l.isZGESO and FyrMM.IsValidBorderPin(l) then
                    l.m_PinType = MAP_PIN_TYPE_LOCATION
                    FyrMM.CreateBorderPin(l)
                end
            end
        end
    end

    -- wayshrines
    -- 03/07/2026 optimization: Cache wayshrine and skyshard UI controls to avoid expensive GetControl lookups and string allocations in hot paths
    if FyrMM.SV.BorderWayshrine and FyrMM.currentWayshrineCount > 0 then
        FyrMM.WayshrinePinControlCache = FyrMM.WayshrinePinControlCache or {}
        for i, v in ipairs(Wayshrines) do
            if v.Closest then
                local l = FyrMM.WayshrinePinControlCache[i]
                if l == nil then
                    l = GetControl("Fyr_MM_Scroll_Map_WayshrinePins_Pin" .. tostring(i))
                    if l ~= nil then
                        FyrMM.WayshrinePinControlCache[i] = l
                    end
                end
                if l ~= nil then
                    FyrMM.CreateBorderPin(l)
                end
            end
        end
    end
	
	
    -- skyshards
    if FyrMM.SV.BorderSkyshard then  
        FyrMM.SkyshardPinControlCache = FyrMM.SkyshardPinControlCache or {}
        for i = 1, Fyr_MM_Scroll_Map_SkyshardPins:GetNumChildren() do
                local l = FyrMM.SkyshardPinControlCache[i]
                if l == nil then
                    l = GetControl("Fyr_MM_Scroll_Map_SkyshardPins_Pin"..tostring(i)) 
                    if l ~= nil then
                        FyrMM.SkyshardPinControlCache[i] = l
                    end
                end
                if l ~= nil and l.Closest then
					FyrMM.CreateBorderPin(l)
                end
        end
    end
	
    -- keeps
    -- 03/07/2026 optimization: This loop runs up to 163 GetControl() calls (each preceded by a
    -- string concatenation) every time PlaceBorderPins() runs - and per the 02/07/2026 note above,
    -- that's roughly every 60ms via RescalePinPositions, not just the nominal 2000ms timer. For
    -- Cyrodiil players with Border Keep Pins enabled that's up to ~5,000+ redundant name lookups/sec,
    -- even though keep/under-attack controls are created once (see the keep refresh function) and
    -- never destroyed for the rest of the session - only ever hidden/shown. Cache each resolved
    -- control by keep index the first time it's found, so later calls skip straight to a table read.
    if FyrMM.SV.BorderKeep and CurrentMap.MapId == 16 then  
        FyrMM.KeepPinControlCache = FyrMM.KeepPinControlCache or {}
        FyrMM.UnderAttackKeepPinControlCache = FyrMM.UnderAttackKeepPinControlCache or {}
        for i = 3, 165 do
                local l = FyrMM.KeepPinControlCache[i]
                if l == nil then
                    l = GetControl("Fyr_MM_Scroll_Map_Keeps_Keep"..tostring(i))
                    if l ~= nil then
                        FyrMM.KeepPinControlCache[i] = l
                    end
                end
                if l ~= nil and l.Closest then 
                    FyrMM.CreateBorderPin(l)
					local UA = FyrMM.UnderAttackKeepPinControlCache[i]
					if UA == nil then
						UA = GetControl("Fyr_MM_Scroll_Map_Keeps_Under_Attack_Keep"..tostring(i))
						if UA ~= nil then
							FyrMM.UnderAttackKeepPinControlCache[i] = UA
						end
					end
					if UA then -- under attack!
					   FyrMM.CreateBorderPin(UA) 
					end
                end
        end
    end

    -- treasures and antiquities
    if FyrMM.SV.BorderTreasures then
        if not ZO_IsTableEmpty(Treasures) then
            for i, v in pairs(Treasures) do
                if v ~= nil then
                    if v.IsTreasure then
                        FyrMM.CreateBorderPin(v)
                    end
                end
            end
        end
    end

    -- Dragon next location
    if FyrMM.SV.WorldEvents then
        if not ZO_IsTableEmpty(DragonNextLocation) then
            for i, v in pairs(DragonNextLocation) do
                if v ~= nil then
                    if v.IsDragonNextLocation then
                        FyrMM.CreateBorderPin(v)
                    end
                end
            end
        end
    end

    -- digsites
    if not ZO_IsTableEmpty(Digsites) then
        for i, v in pairs(Digsites) do
            if v ~= nil then
                if v.borderInformation ~= nil then
                    FyrMM.CreateBorderPin(v)
                end
            end
        end
    end

    -- Quest givers
    if FyrMM.SV.BorderQuestGivers and not ZO_IsTableEmpty(FyrMM.AvailableQuestGivers) then
        if #FyrMM.AvailableQuestGivers <= 5 then
            for i, v in pairs(FyrMM.AvailableQuestGivers) do
                if v ~= nil then
                    if v.IsAvailableQuest then
                        FyrMM.CreateBorderPin(v)
                    end
                end
            end
        else
            if not ZO_IsTableEmpty(AQGList) then
                for i = 1, 5 do
                    if AQGList[i] ~= nil then
                        FyrMM.CreateBorderPin(AQGList[i])
                    end
                end
            end
        end
    end
end

function FyrMM.PlaceWaypointBorderPins()
    SetBorderPinHandlers()
    if FyrMM.SV.BorderPinsWaypoint then
        if FyrMM.IsWaypoint then
            if not FyrMM.Waypoint:IsHidden() or not FyrMM.Is_PinInsideWheel(FyrMM.Waypoint) then
                FyrMM.CreateBorderPin(FyrMM.Waypoint)
                if FyrMM.Waypoint.BorderPin then
                    FyrMM.Waypoint.BorderPin:SetHandler("OnMouseEnter", FyrMM.BorderPinOnMouseEnter)
                    FyrMM.Waypoint.BorderPin:SetHandler("OnMouseExit", FyrMM.BorderPinOnMouseExit)
                    FyrMM.Waypoint.BorderPin:SetMouseEnabled(true)
                end
            else
                if FyrMM.Waypoint.BorderPin ~= nil then
                    RemoveBorderPin(FyrMM.Waypoint)
                end
            end
        end
        if FyrMM.IsPing then
            if not FyrMM.Ping:IsHidden() or not FyrMM.Is_PinInsideWheel(FyrMM.Ping) then
                FyrMM.CreateBorderPin(FyrMM.Ping)
                if FyrMM.Ping.BorderPin then
                    FyrMM.Ping.BorderPin:SetHandler("OnMouseEnter", FyrMM.BorderPinOnMouseEnter)
                    FyrMM.Ping.BorderPin:SetHandler("OnMouseExit", FyrMM.BorderPinOnMouseExit)
                    FyrMM.Ping.BorderPin:SetMouseEnabled(true)
                end
            else
                if FyrMM.Ping.BorderPin ~= nil then
                    RemoveBorderPin(FyrMM.Ping)
                end
            end
        end
        if FyrMM.IsRally then
            if not FyrMM.Rally:IsHidden() or not FyrMM.Is_PinInsideWheel(FyrMM.Rally) then
                FyrMM.CreateBorderPin(FyrMM.Rally)
                if FyrMM.Rally.BorderPin then
                    FyrMM.Rally.BorderPin:SetHandler("OnMouseEnter", FyrMM.BorderPinOnMouseEnter)
                    FyrMM.Rally.BorderPin:SetHandler("OnMouseExit", FyrMM.BorderPinOnMouseExit)
                    FyrMM.Rally.BorderPin:SetMouseEnabled(true)
                end
            else
                if FyrMM.Rally.BorderPin ~= nil then
                    RemoveBorderPin(FyrMM.Rally)
                end
            end
        end
    end
end

function FyrMM.isSameZone(PinMapId)
    local _, _, _, pinZone = GetMapInfoById(PinMapId)
    local _, _, _, currentMapZone = GetMapInfoById(CurrentMap.MapId)

    if PinMapId == CurrentMap.MapId or pinZone == currentMapZone then
        return true
    else
        return false
    end
end

-----------------------------------------------------------------
-- Pin Clean up
-----------------------------------------------------------------
local function CleanupMapLocations()
    local t = GetGameTimeMilliseconds()
    local totalPins = Fyr_MM_Scroll_Map_LocationPins:GetNumChildren()
    if totalPins > FyrMM.currentLocationsCount then
        for i = FyrMM.currentLocationsCount + 1, totalPins do
            local l = GetControl("Fyr_MM_Scroll_Map_LocationPins_Pin" .. tostring(i))
            if l ~= nil then
                if l.BorderPin ~= nil then
                    RemoveBorderPin(l.BorderPin)
                end
                l:ClearAnchors()
                l.nX = nil
                l.nY = nil
                l:SetHidden(true)
                l:SetMouseEnabled(false)
                l:SetDimensions(0, 0)
                l.m_Pin = nil
                PinsList[l:GetName()] = nil
            end
        end
    end
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "CleanupMapLocations " .. tostring(GetGameTimeMilliseconds() - t))
    end
end

local function CleanupWayshrines()
    local t = GetGameTimeMilliseconds()
    local totalPins = Fyr_MM_Scroll_Map_WayshrinePins:GetNumChildren()
    if totalPins > FyrMM.currentWayshrineCount then
        FyrMM.WayshrinePinControlCache = FyrMM.WayshrinePinControlCache or {}
        -- 03/07/2026 optimization: Cache wayshrine controls to avoid expensive GetControl lookups and string allocations
        for i = FyrMM.currentWayshrineCount + 1, totalPins do
            local l = FyrMM.WayshrinePinControlCache[i]
            if l == nil then
                l = GetControl("Fyr_MM_Scroll_Map_WayshrinePins_Pin" .. tostring(i))
                if l ~= nil then
                    FyrMM.WayshrinePinControlCache[i] = l
                end
            end
            if l ~= nil then
                if l.BorderPin ~= nil then
                    RemoveBorderPin(l.BorderPin)
                end
                l.nX = nil
                l.nY = nil
                l:ClearAnchors()
                l:SetHidden(true)
                l:SetMouseEnabled(false)
                l:SetDimensions(0, 0)
                l.m_Pin = nil
                PinsList[l:GetName()] = nil
            end
        end
    end
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "CleanupWayshrines " .. tostring(GetGameTimeMilliseconds() - t))
    end
end

local function RemoveSkyshards()
    local t = GetGameTimeMilliseconds()
	
    local totalPins = Fyr_MM_Scroll_Map_SkyshardPins:GetNumChildren()
    if totalPins == 0 then
        return
    end

    FyrMM.SkyshardPinControlCache = FyrMM.SkyshardPinControlCache or {}
    -- 03/07/2026 optimization: Cache skyshard controls to avoid expensive GetControl lookups and string allocations
	for i = 1, totalPins do
		local l = FyrMM.SkyshardPinControlCache[i]
        if l == nil then
            l = GetControl("Fyr_MM_Scroll_Map_SkyshardPins_Pin"..tostring(i))
            if l ~= nil then
                FyrMM.SkyshardPinControlCache[i] = l
            end
        end
		if l ~= nil then
		    if l.BorderPin then
		       RemoveBorderPin(l.BorderPin)
	        end	
			l:SetHidden(true)
			l:ClearAnchors()
			l.pinTexture = nil
			l.Closest = nil
			l.skyshardId = nil
			l.m_PinType = nil
			l.status = nil
			l.nX = nil
			l.nY = nil
			l:SetMouseEnabled(false)
			l:SetDimensions(0, 0)
			l.m_Pin = nil
			PinsList[l:GetName()] = nil
		end
	end

	
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug","RemoveSkyshards("..tostring(totalPins)..") "..tostring(GetGameTimeMilliseconds() - t))
    end

end

local function CleanupPOIs()
    local t = GetGameTimeMilliseconds()
    local totalPins = Fyr_MM_Scroll_Map_POIPins:GetNumChildren()
    if totalPins == 0 then
	    FyrMM.updatingPOIPins = false
        return
    end
    if CleanPOIs + FyrMM.currentPOICount ~= totalPins then
        -- if totalPins > FyrMM.currentPOICount then
        CleanPOIs = 0
        for i = FyrMM.currentPOICount + 1, totalPins do
            local l = GetControl("Fyr_MM_Scroll_Map_POIPins_Pin"..tostring(i))
            if l ~= nil then
			    local m = GetControl("Fyr_MM_Scroll_Map_POIPins_Pin"..tostring(i).."_Wall")
				if m ~= nil then
					m.nX = nil
					m.nY = nil
					m:ClearAnchors()
					m:SetHidden(true)
					m:SetMouseEnabled(false)
					m:SetDimensions(0, 0)
					m.m_Pin = nil
					PinsList[m:GetName()] = nil
				end
			    local n = GetControl("Fyr_MM_Scroll_Map_POIPins_Pin"..tostring(i).."_Caustics")
				if n ~= nil then
					n.nX = nil
					n.nY = nil
					n:ClearAnchors()
					n:SetHidden(true)
					n:SetMouseEnabled(false)
					n:SetDimensions(0, 0)
					n.m_Pin = nil
					PinsList[n:GetName()] = nil
				end
                l.nX = nil
                l.nY = nil
                l:ClearAnchors()
                l:SetHidden(true)
                l:SetMouseEnabled(false)
                l:SetDimensions(0, 0)
                l.m_Pin = nil
				l.spectacleEventPin = nil
                PinsList[l:GetName()] = nil
                CleanPOIs = CleanPOIs + 1
            end
        end
    end
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug",
            "CleanupPOIs("..tostring(FyrMM.currentPOICount + 1).." - "..tostring(totalPins)..") ("..CleanPOIs..") "..tostring(GetGameTimeMilliseconds() - t))
    end
	FyrMM.updatingPOIPins = false
end

local function RemoveQuestPin(l)
    if l == nil then
        return
    end
	
	if l.BorderPin then
		RemoveBorderPin(l.BorderPin)
	end	
	
	if l.OnBorder then
		l.OnBorder = nil
	end
	
    if l.MM_Tag ~= nil then
        if l.MM_Tag == 1 then
            if l.secondaryPin ~= nil then
                l.secondaryPin.MM_Tag = nil
                RemoveQuestPin(l.secondaryPin)
            end
            if l.tertiaryPin ~= nil then
                l.tertiaryPin.MM_Tag = nil
                RemoveQuestPin(l.tertiaryPin)
            end
        else
            if l.primaryPin ~= nil then
                l.primaryPin.MM_Tag = nil
                RemoveQuestPin(l.primaryPin)
            end
        end
    end
    if l.questdataIndex ~= nil then
        if FyrMM.questPinCount > 0 then
            FyrMM.questPinCount = FyrMM.questPinCount - 1
        end
        if QuestPins[l.questdataIndex] ~= nil then
            table.insert(FreeQuestPinIndex, QuestPins[l.questdataIndex].pinIndex)
        end
        QuestPins[l.questdataIndex] = nil
    end

    l:SetParent(Fyr_MM_Scroll_Map_QuestPins)
    l:ClearAnchors()
    l:SetHidden(true)
    l:SetMouseEnabled(false)
    l:SetDimensions(0, 0)
    l.questdataIndex = nil
    l.MM_Tag = nil
    l.m_PinTag = nil
    l.m_PinType = nil
    l.m_Pin = nil
    l.normalizedX = nil
    l.normalizedY = nil
    l.radius = nil
    l.MapId = nil
    l.questIndex = nil
    l.questName = nil
    l.PinToolTipText = nil
    l.primaryPin = nil
    l.secondaryPin = nil
    l.tertiaryPin = nil
    l.pinAge = nil
    PinsList[l:GetName()] = nil
	l = nil
end

local function ClearDigsiteBlob(digSite)
    digSite:ClearPoints()
    digSite:ClearAnchors()
	digSite.pinType = nil
    digSite.m_PinType = nil
    digSite.Tag = nil
    digSite.nX = nil
    digSite.nY = nil
    digSite.MapId = nil
    digSite.borderInformation = nil
    digSite:SetHidden(true)
end

local function CreateDigSiteAreaSidePins(pin, width, height, isTracked)
    local DigSiteAreaSidePinNS
    DigSiteAreaSidePinNS = GetControl("Fyr_MM_Scroll_Map_DigSite"..tostring(FyrMM.currentDigSiteCount).."_NS")
    if DigSiteAreaSidePinNS == nil then
        DigSiteAreaSidePinNS = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_DigSite"..tostring(FyrMM.currentDigSiteCount) .. "_NS", Fyr_MM_Scroll_NS_Map_Pins, CT_POLYGON)
    else
        DigSiteAreaSidePinNS:SetParent(Fyr_MM_Scroll_NS_Map_Pins)
    end

    DigSiteAreaSidePinNS.m_PinType = pin.m_PinType
    DigSiteAreaSidePinNS.nX = pin.nX
    DigSiteAreaSidePinNS.nY = pin.nY
    DigSiteAreaSidePinNS.borderInformation = pin.borderInformation
    DigSiteAreaSidePinNS.lastPointsHeading = nil -- 02/07/2026: invalidate cached rotation since this pin control may be reused for a different dig site
    DigSiteAreaSidePinNS.MapId = pin.MapId
    DigSiteAreaSidePinNS:SetDimensions(width, height)
    DigSiteAreaSidePinNS:SetHidden(not ZO_WorldMap_IsPinGroupShown(MAP_FILTER_DIG_SITES))

    local centerColor = isTracked and ZO_MAP_PIN_TRACKED_DIG_SITE_COLOR or ZO_MAP_PIN_DIG_SITE_COLOR
    local r, g, b = centerColor:UnpackRGB()
    local alpha = 0.39
    DigSiteAreaSidePinNS:SetCenterColor(r, g, b, alpha)
    local borderColor = ZO_MAP_PIN_DIG_SITE_BORDER_COLOR
    DigSiteAreaSidePinNS:SetBorderColor(borderColor:UnpackRGBA())
    DigSiteAreaSidePinNS:SetSmoothingEnabled(true)
    DigSiteAreaSidePinNS:SetBorderThickness(3, 3, 0)
    DigSiteAreaSidePinNS:SetShapeType(SHAPE_CIRCLE)
    DigSiteAreaSidePinNS:SetDrawLayer(1)

    FyrMM.SetPinAnchor(DigSiteAreaSidePinNS, DigSiteAreaSidePinNS.nX, DigSiteAreaSidePinNS.nY, Fyr_MM_Scroll_Map_Pins)
    if FyrMM.SV.WheelMap then
        DigSiteAreaSidePinNS:SetParent(Fyr_MM_Scroll_NS_Map_Pins)
    end
    DigSiteAreaSidePinNS:SetHandler("OnMouseUp", PinOnMouseUp)
    DigSiteAreaSidePinNS:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
    DigSiteAreaSidePinNS:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
    SetDigSitePoints(DigSiteAreaSidePinNS)

    local DigSiteAreaSidePinWE
    DigSiteAreaSidePinWE = GetControl("Fyr_MM_Scroll_Map_DigSite" .. tostring(FyrMM.currentDigSiteCount) .. "_WE")
    if DigSiteAreaSidePinWE == nil then
        DigSiteAreaSidePinWE = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_DigSite"..tostring(FyrMM.currentDigSiteCount).."_WE", Fyr_MM_Scroll_WE_Map_Pins, CT_POLYGON)
    else
        DigSiteAreaSidePinWE:SetParent(Fyr_MM_Scroll_WE_Map_Pins)
    end

    DigSiteAreaSidePinWE.m_PinType = pin.m_PinType
    DigSiteAreaSidePinWE.nX = pin.nX
    DigSiteAreaSidePinWE.nY = pin.nY
    DigSiteAreaSidePinWE.borderInformation = pin.borderInformation
    DigSiteAreaSidePinWE.lastPointsHeading = nil -- 02/07/2026: invalidate cached rotation since this pin control may be reused for a different dig site
    DigSiteAreaSidePinWE.MapId = pin.MapId
    DigSiteAreaSidePinWE:SetDimensions(width, height) 
    DigSiteAreaSidePinWE:SetHidden(not ZO_WorldMap_IsPinGroupShown(MAP_FILTER_DIG_SITES))
    DigSiteAreaSidePinWE:SetCenterColor(r, g, b, alpha)
    DigSiteAreaSidePinWE:SetBorderColor(borderColor:UnpackRGBA())
    DigSiteAreaSidePinWE:SetSmoothingEnabled(true)
    DigSiteAreaSidePinWE:SetBorderThickness(3, 3, 0)
    DigSiteAreaSidePinWE:SetShapeType(SHAPE_CIRCLE)
    DigSiteAreaSidePinWE:SetDrawLayer(1)
    FyrMM.SetPinAnchor(DigSiteAreaSidePinWE, DigSiteAreaSidePinWE.nX, DigSiteAreaSidePinWE.nY, Fyr_MM_Scroll_Map_Pins)
    if FyrMM.SV.WheelMap then
        DigSiteAreaSidePinWE:SetParent(Fyr_MM_Scroll_WE_Map_Pins)
    end
    DigSiteAreaSidePinWE:SetHandler("OnMouseUp", PinOnMouseUp)
    DigSiteAreaSidePinWE:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
    DigSiteAreaSidePinWE:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
    SetDigSitePoints(DigSiteAreaSidePinWE)
end

local function CreateDigSiteBlob(DigsiteId)
    local centerX, centerZ, isShownInCurrentMap = GetDigSiteNormalizedCenterPosition(DigsiteId)
    if isShownInCurrentMap then
        local isTracked = IsDigSiteAssociatedWithTrackedAntiquity(DigsiteId)
        local points = {}
        local minX = 1.0
        local maxX = 0.0
        local minY = 1.0
        local maxY = 0.0

        local borderPoints = { GetDigSiteNormalizedBorderPoints(DigsiteId) }

        for i = 1, #borderPoints, 2 do    -- loop by 2 because we are getting x and z coordinates
            local x = borderPoints[i]
            local y = borderPoints[i + 1] -- UI is going to treat z as y

            minX = zo_min(x, minX)
            maxX = zo_max(x, maxX)

            minY = zo_min(y, minY)
            maxY = zo_max(y, maxY)
			
			--d("Border point "..i.." x: "..x.." y: "..y)

            local coordinates = {
                x = x,
                y = y
            }
            table.insert(points, coordinates)
        end

        for index, coordinates in ipairs(points) do
            coordinates.x = zo_normalize(coordinates.x, minX, maxX) 
            coordinates.y = zo_normalize(coordinates.y, minY, maxY)
        end
		
		local mWidth, mHeight = Fyr_MM_Scroll_Map:GetDimensions()

        local borderInformation = {
            borderPoints = points,
            borderWidth = maxX - minX,
            borderHeight = maxY - minY,
			centerX = centerX,
			centerZ = centerZ,
	        }

        

        local digSite
        FyrMM.currentDigSiteCount = FyrMM.currentDigSiteCount + 1
        digSite = GetControl("Fyr_MM_Scroll_Map_DigSite" .. tostring(FyrMM.currentDigSiteCount))
        if digSite == nil then
            digSite = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_DigSite" .. tostring(FyrMM.currentDigSiteCount), Fyr_MM_Scroll_Map_Pins, CT_POLYGON)

            digSite.nDistance = function(self)
                if self.nX == nil then
                    return 1
                end
                return zo_sqrt((zo_round(CurrentMap.PlayerNX * 10000) - zo_round(self.nX * 10000)) * (zo_round(CurrentMap.PlayerNX * 10000) - zo_round(self.nX * 10000)) +
				(zo_round(CurrentMap.PlayerNY * 10000) - zo_round(self.nY * 10000)) * (zo_round(CurrentMap.PlayerNX * 10000) - zo_round(self.nY * 10000))) / 10000
            end
            digSite:SetMouseEnabled(true)
            digSite:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
            digSite:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
            digSite:SetHandler("OnMouseUp", PinOnMouseUp)
        end
        digSite.pinType = isTracked and MAP_PIN_TYPE_TRACKED_ANTIQUITY_DIG_SITE or MAP_PIN_TYPE_ANTIQUITY_DIG_SITE
        digSite.Tag = DigsiteId
        digSite.nX = centerX
        digSite.nY = centerZ

        SetMapToDigSitePosition(DigsiteId)
        digSite.MapId = CurrentMap.MapId
        FyrMM.SetMapToPlayerLocation()

        digSite.borderInformation = borderInformation
        digSite.lastPointsHeading = nil -- 02/07/2026: invalidate cached rotation since this pin control may be reused for a different dig site
        digSite.m_PinType = digSite.pinType
        digSite:SetDrawLayer(1)
        local width = borderInformation.borderWidth * mWidth 
        local height = borderInformation.borderHeight * mHeight
		
		
        digSite:SetDimensions(width, height)
        local centerColor = isTracked and ZO_MAP_PIN_TRACKED_DIG_SITE_COLOR or ZO_MAP_PIN_DIG_SITE_COLOR
        local r, g, b = centerColor:UnpackRGB()
        local alpha = 0.39
        digSite:SetCenterColor(r, g, b, alpha)
        local borderColor = ZO_MAP_PIN_DIG_SITE_BORDER_COLOR
        digSite:SetBorderColor(borderColor:UnpackRGBA())
        digSite:SetSmoothingEnabled(true)
        digSite:SetBorderThickness(3, 3, 0)
        digSite:SetShapeType(SHAPE_CIRCLE)
        FyrMM.SetPinAnchor(digSite, centerX, centerZ, Fyr_MM_Scroll_Map_Pins)

        if FyrMM.SV.WheelMap then 
			if FyrMM.SV.RotateMap then
                digSite:SetParent(Fyr_MM_Scroll_CW_Map_Pins)
            else
                digSite:SetParent(FyrMM.GetScrollObject(digSite))
            end
            CreateDigSiteAreaSidePins(digSite, width, height, isTracked)
        end

        digSite:SetHidden(not ZO_WorldMap_IsPinGroupShown(MAP_FILTER_DIG_SITES))

        SetDigSitePoints(digSite)
        table.insert(Digsites, digSite)
    end
end

function FyrMM.UpdateAntiquityDigSites()
    if FyrMM.currentDigSiteCount > 0 then
        Digsites = {}
        for i = 1, FyrMM.currentDigSiteCount, 1 do
            local digSite = GetControl("Fyr_MM_Scroll_Map_DigSite" .. tostring(i))
            local digSiteNS = GetControl("Fyr_MM_Scroll_Map_DigSite" .. tostring(i) .. "_NS")
            local digSiteWE = GetControl("Fyr_MM_Scroll_Map_DigSite" .. tostring(i) .. "_WE")
            
            if FyrMM.SV.WheelMap then
                if digSiteNS then
                    ClearDigsiteBlob(digSiteNS)
                end
                if digSiteWE then
                    ClearDigsiteBlob(digSiteWE)
                end
            end
			ClearDigsiteBlob(digSite)
        end
    end
    FyrMM.currentDigSiteCount = 0
    local numInprogress = GetNumInProgressAntiquities()
    for antiquityIndex = 1, numInprogress, 1 do
        local numDigSites = GetNumDigSitesForInProgressAntiquity(antiquityIndex)
        if numDigSites > 0 then
            if numDigSites == 1 then
                local digSiteId = GetInProgressAntiquityDigSiteId(antiquityIndex, 1)
                if digSiteId > 0 then
                    CreateDigSiteBlob(digSiteId)
                end
            else
                for digSiteIndex = 1, numDigSites, 1 do
                    local digSiteId = GetInProgressAntiquityDigSiteId(antiquityIndex, digSiteIndex)
                    if digSiteId > 0 then
                        CreateDigSiteBlob(digSiteId)
                    end
                end
            end
        end
    end
end

function FyrMM.RemoveInvalidQuestPins()
    local t = GetGameTimeMilliseconds()
    local _
    local complete
	local removed
    for i, v in pairs(QuestPins) do
        local l = v.Pin
        if l ~= nil then
            if not l:IsHidden() then
                local a = l.m_PinTag[1]
                local b = l.m_PinTag[3]
                local c = l.m_PinTag[2]
                local qi = l.questIndex
                if l.questIndex ~= nil then
                    if not IsValidQuestIndex(qi) or GetJournalQuestName(qi) ~= l.questName then
                        RemoveQuestPin(l)
						removed = true
						--d("removed a quest pin METHOD 1")
                    else
						if l.m_PinTag ~= nil and l.PinToolTipText ~= nil and l.PinToolTipText ~= "" then
                            if l.PinToolTipText ~= GenerateQuestConditionTooltipLine(a, b, c) or not GenerateQuestConditionTooltipLine(a, b, c) or GenerateQuestConditionTooltipLine(a, b, c) == "" then
                                RemoveQuestPin(l)
								removed = true
								--d("removed a quest pin METHOD 2")
                            else
                                _, _, _, _, complete, _ = GetJournalQuestConditionInfo(a, b, c)
                                if complete then
                                    RemoveQuestPin(l)
									removed = true
									--d("removed a quest pin METHOD 3")
                                end
                            end
                        else
                            RemoveQuestPin(l)
							removed = true
							--d("removed a quest pin METHOD 4")
                        end
                    end
                else
                    RemoveQuestPin(l)
					removed = true
					--d("removed a quest pin METHOD 5")
                end
            end
        end
    end
	
	if removed then 
	   FyrMM.RequestQuestPinUpdate()
	end   
	
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug",
            "RemoveInvalidQuestPins " .. tostring(GetGameTimeMilliseconds() - t))
    end
end

function FyrMM.UpdateLabels()
    if not FyrMM.SV or FyrMM.SV.HideZoneLabel then
        return
    end 

    if Fyr_MM:IsHidden() then
        Fyr_MM_ZoneFrame:SetHidden(true)
        return
    end
    
	local level = "" -- display stages
	if CurrentMap.MapId > 682 and CurrentMap.MapId < 693 then -- Display Dragonstar Arena Stages
	    local number = CurrentMap.MapId - 682
	    level = " "..number.."/10"
	elseif CurrentMap.MapId == 988 then -- Maelstrom Arena 1
	    level = " 1/9"
	elseif CurrentMap.MapId == 963 then -- Maelstrom Arena 2
	    level = " 2/9"
    elseif CurrentMap.MapId == 978 then -- Maelstrom Arena 3
	    level = " 3/9"
    elseif CurrentMap.MapId == 970 then -- Maelstrom Arena 4
	    level = " 4/9"
    elseif CurrentMap.MapId == 976 then -- Maelstrom Arena 5
	    level = " 5/9"
    elseif CurrentMap.MapId == 973 then -- Maelstrom Arena 6
	    level = " 6/9"
    elseif CurrentMap.MapId == 987 then -- Maelstrom Arena 7
	    level = " 7/9"
    elseif CurrentMap.MapId == 986 then -- Maelstrom Arena 8
	    level = " 8/9"
    elseif CurrentMap.MapId == 985 then -- Maelstrom Arena 9
	    level = " 9/9"
	end 
	
    local currentMapName, _ = LocalizeString('<<1>>', GetMapName())
    local currentAreaName = LocalizeString('<<1>>', GetPlayerLocationName())
    if not FyrMM.SV.ZoneNameContents ~= nil then
        if FyrMM.SV.ZoneNameContents == "Classic (Map only)" and not (IsPlayerInAvAWorld() and FyrMM.SV.ForceAreaOnlyInCyro) then
            Fyr_MM_Zone:SetText(currentMapName..level)
        elseif FyrMM.SV.ZoneNameContents == "Map & Area" then
            if currentMapName ~= currentAreaName then
                Fyr_MM_Zone:SetText(currentMapName..level.."\n"..currentAreaName)
            else
                Fyr_MM_Zone:SetText(currentMapName..level)
            end
        else
            Fyr_MM_Zone:SetText(currentAreaName..level)
        end
    else
        Fyr_MM_Zone:SetText(currentMapName..level)
    end

    local zoneWidth, zoneHeight = Fyr_MM_Zone:GetTextDimensions() or 100, 20
    if string.find(Fyr_MM_Zone:GetText(), "\n") then
        zoneHeight = zoneHeight * 2
    end

    Fyr_MM_ZoneFrame:SetDimensions(zoneWidth + 10, zoneHeight + 3)
    if FyrMM.SV.ZoneFrameLocationOption == "Free" then
        Fyr_MM_ZoneFrame:ClearAnchors()
        Fyr_MM_ZoneFrame:SetAnchor(MM_GetZoneFrameAnchor())
    end
    Fyr_MM_ZoomLevel:SetText(tostring(CurrentMap.ZoomLevel))
end

-----------------------------------------------------------------
-- Updates
-----------------------------------------------------------------

function FyrMM.GetMapMeasureMultiplier()
    -- Based on assumption that player constantly moves at the same speed anywhere - world size has to be adjusted to match it. According to Tamriel distance difference for some specific maps I made a few adjustments for the worldsizes while in those maps.
    -- Maps like Auridon or Glenumbra indicate same player speeds while Cyrodiil, Craglorn and starting maps show compleately different speeds (for mapsize 33440)

    local mapIndex = GetCurrentMapIndex()
    local multiplier = 1
    -- walking = 2.00/2.03 m/s
    -- if mapIndex == 14 then -- cyrodiil
    -- multiplier = 2.2
    -- elseif mapIndex == 18 then -- Bal foyen
    -- multiplier = 1 --1.353
    -- elseif mapIndex == 19 then -- stros m'kai
    -- multiplier = 2.6
    -- elseif mapIndex == 21 then --  kenarthi's roost
    -- multiplier = 2.4865
    -- elseif mapIndex == 22 then -- Bleakrock isle
    -- multiplier = 1 --3.1
    -- elseif mapIndex == 25 then -- craglorn
    -- multiplier = 1 --1.087
    if mapIndex == 39 then -- Greymoor Caverns
        multiplier = 4.5
    end
    -- alik'r, artaeum, auridon, Bal foyen, Bangkorai , Betnikh, Arkhzand cavern, Blackwood, Bleakrock, clockwork city, craglorn, deshaan, eastmarch,
    -- fargrave, glenumbra, gold coast, grahtwood, greenshade, hew's bane, high isle, kenarthi's roost, malabal tor, murkmire, northern elsweyr
    -- reaper's march, rivenspire, shadowfen, southern elsweyr, stonefalls, stormhaven, stros m'kai, summerset, the deadlands, the reach
    -- the rift, western skyrim, wrothgar are multiplier = 1

    return multiplier
end

function FyrMM.MeasureDistance()
    if not FyrMM.MeasureMaps then
        return
    end

    if CurrentMap.TrueMapSize and CurrentMap.TrueMapSize > 1 then
        FyrMM.DistanceMeasurementStarted = false
        return
    end

    local _
    FyrMM.SetMapToPlayerLocation()
    FyrMM.MeasurementXl, FyrMM.MeasurementYl, _ = GetMapPlayerPosition("player")
    local mapIndex = GetCurrentMapIndex()
    if mapIndex == nil then
        MapZoomOut()
        mapIndex = GetCurrentMapIndex()
    end

    if mapIndex ~= 23 then
        SetMapToMapListIndex(1)
    end

    FyrMM.MeasurementX, FyrMM.MeasurementY, _ = GetMapPlayerPosition("player")
    FyrMM.DistanceMeasurementStarted = true
    FyrMM.SetMapToPlayerLocation()
    zo_callLater(FyrMM.FinishDistanceMeasurement, 5000)
end

function FyrMM.FinishDistanceMeasurement()
    if Fyr_MM:IsHidden() or FyrMM.worldMapShowing then
        return
    end
    FyrMM.DistanceMeasurementStarted = false
    if CurrentMap == nil or CurrentMap.TrueMapSize == nil or  CurrentMap.TrueMapSize > 1 then
        return
    end
    local x, y = FyrMM.MeasurementX, FyrMM.MeasurementY
    FyrMM.SetMapToPlayerLocation()
    local xl, yl = FyrMM.MeasurementXl, FyrMM.MeasurementYl
    local x2l, y2l, _ = GetMapPlayerPosition("player")
    local mapIndex = GetCurrentMapIndex()
    if mapIndex == nil then
        MapZoomOut()
        mapIndex = GetCurrentMapIndex()
    end
    local worldsize, multiplier

    if mapIndex ~= 23 then -- not coldharbour
        SetMapToMapListIndex(1)
        worldsize = 33440  -- Assumed Tamriel size in feet taken from ZygorGuides
    else
        worldsize = 5684   -- Assumed Coldharbour size in feet
    end

    local multiplier = FyrMM.GetMapMeasureMultiplier()

    local x2, y2, _ = GetMapPlayerPosition("player")
    FyrMM.SetMapToPlayerLocation()
    local localdistance = zo_sqrt((xl - x2l) * (xl - x2l) + (yl - y2l) * (yl - y2l)) -- Local map distance
    local continentdistance = zo_sqrt((x - x2) * (x - x2) + (y - y2) * (y - y2))     -- Tamriel/Coldharbour
    local mapSize = (worldsize * continentdistance / localdistance) * multiplier
    if not (mapSize > 0) then                                                          -- Error
        FyrMM.DistanceMeasurementStarted = true
        return
    end
    if FyrMM.SV.MapSizes == nil then
        FyrMM.SV.MapSizes = {}
    end
    if CurrentMap.filename == nil or CurrentMap.filename == "" then
        local filename, nameNoNum, path = FyrMM.GetCurrentMapTextureFileInfo()
        CurrentMap.filename = string.lower(filename)
    end
    FyrMM.SV.MapSizes[CurrentMap.filename] = mapSize
    CurrentMap.TrueMapSize = mapSize
end

function FyrMM.InCombatAutoHideCheck()
    if not FyrMM.SV.InCombatAutoHide then
        return
    end
    if IsUnitInCombat("player") then
        FyrMM.AfterCombatUnhidePending = false
        if not Fyr_MM:IsHidden() then
            FyrMM.Visible = false
            FyrMM.AutoHidden = true
        end
    else
        if Fyr_MM:IsHidden() and FyrMM.AutoHidden then
            if not FyrMM.AfterCombatUnhidePending then
                FyrMM.AfterCombatUnhidePending = true
                FyrMM.AfterCombatUnhideTimeStamp = GetFrameTimeMilliseconds()
                zo_callLater(AfterCombatShow, 1000 * FyrMM.SV.AfterCombatUnhideDelay) -- zo_callLater ok 
            end
        end
    end
end

local function DelayedReload()
    if FyrMM.Reloading then
        return
    end
    zo_callLater(FyrMM.Reload, 100) -- zo_callLater ok 
end

local function DelayedShow()
    if not Fyr_MM:IsHidden() or FyrMM.Reloading then
        return
    end
    zo_callLater(FyrMM.Show, 100) -- zo_callLater ok 
end

function FyrMM.ClockCheck()
    if FyrMM.SV.ShowClock then
        if GetSecondsSinceMidnight() ~= FyrMM.SecondsSinceMidnight then
            local TS = ""
            local a = GetTimeString()
            if FyrMM.TimeFormat == 0 then
                Fyr_MM_Time:SetText(a)
            elseif FyrMM.TimeFormat == 2 then
                TS = " " .. string.sub(a, 1, 5) .. " "
                Fyr_MM_Time:SetText(TS)
            else
                local h = tonumber(string.sub(a, 1, 2))
                if h > 12 then
                    local H = tostring(h - 12)
                    if (h - 12) < 10 then
                        H = "0" .. H
                    end
                    TS = (H .. string.sub(a, 3, 5) .. "pm")
                else
                    TS = (string.sub(a, 1, 5) .. "am")
                end
                Fyr_MM_Time:SetText(TS)
            end
            Fyr_MM_Time:SetMouseEnabled(true)
            if Fyr_MM_Time:IsHidden() then
                Fyr_MM_Time:SetHidden(false)
            end
            FyrMM.SecondsSinceMidnight = GetSecondsSinceMidnight()
        end
    else
        Fyr_MM_Time:SetMouseEnabled(false)
        Fyr_MM_Time:SetHidden(true)
    end
end


local frameRatePrevious = GetFramerate()

function FyrMM.HideCheck() 
	
	if FyrMM.AreFyrmmSettingsShowing then -- show minimap when it's settings are showing
        if Fyr_MM:IsHidden() then
		    if FyrMM.ActionMapMode then
	            FyrMM.ActionMap.Hide()
	        end
			zo_callLater(function() -- zo_callLater ok 
				FyrMM.UpdateMapTiles(true)
				FyrMM.RegisterUpdates()
			end, 5) -- was 100

			Fyr_MM_Frame_Wheel:SetHidden(not FyrMM.SV.WheelMap)
			if FyrMM.SV.WheelMap then
				FyrMM.Show_WheelScrolls()
			end
			Fyr_MM_Frame_Control:SetHidden(not FyrMM.SV.WheelMap)
			Fyr_MM:SetHidden(false)
			Fyr_MM_Menu:SetHidden(FyrMM.SV.MenuDisabled)
			Fyr_MM_Menu:SetMouseEnabled(not FyrMM.SV.MenuDisabled)
			Fyr_MM_Zone_Background:SetHidden(not FyrMM.SV.ShowZoneBackground)
			Fyr_MM_ZoneFrame:SetHidden(FyrMM.SV.HideZoneLabel)
			if not FyrMM.SV.HideZoneLabel then
				FyrMM.UpdateLabels()
			end
			Fyr_MM_Coordinates:SetHidden(not FyrMM.SV.ShowPosition)
			Fyr_MM_Axis_Control:SetHidden(not (FyrMM.SV.RotateMap or FyrMM.SV.BorderPins))
			Fyr_MM_Speed:SetHidden(not FyrMM.SV.ShowSpeed)
			Fyr_MM_ZoneFrame:SetMouseEnabled(true)
			Fyr_MM:SetMouseEnabled(true)
			if FyrMM.SV.ShowBorder then
			   Fyr_MM_Border:SetAlpha(100)
			end
        end
		return
	end
	
    -------- hide compass -------------------------------------------------------------
    if not ZO_CompassFrame:IsHidden() and (FyrMM.SV.hideCompass == true or (FyrMM.SV.ShowCompassInAvAZoneOnly == true and not IsInAvAZone())) then
        ZO_CompassFrame:SetHidden(true)
    end


    --------------- SHOW / HIDE MINIMAP STUFF --------------------------------------------------------------------------------------------------- 	

    ------ Protect against minimap conflicts stuff	
    if BUI and BUI.MiniMap and BUI.Vars.MiniMap == true then -- disables to avoid conflicts with BUI minimap
        if not FyrMM.minimapConflictMessage then
            d("|ceeeeeeMiniMap by |c006600Fyrakin |ceeeeee v" .. FyrMM.Panel.version .. "|r" ..
                "|c00BFFF is disabled to avoid conflicts with |cFF0000Bandits User Interface|r|c00BFFF's minimap. To use Minimap by |c006600Fyrakin|r|c00BFFF you need to disable |cFF0000Bandits User Interface|r|c00BFFF's minimap first. Please, always test/compare your minimaps one by one.")
        end
        FyrMM.minimapConflictMessage = true
    elseif AUI and AUI.Minimap and AUI.Minimap.IsEnabled() then -- disables to avoid conflicts with AUI's minimap
        if not FyrMM.minimapConflictMessage then
            d("|ceeeeeeMiniMap by |c006600Fyrakin |ceeeeee v" .. FyrMM.Panel.version .. "|r" ..
                "|c00BFFF is disabled to avoid conflicts with |cFF0000Advanced User Interface|r|c00BFFF's minimap. To use Minimap by |c006600Fyrakin|r|c00BFFF you need to disable |cFF0000Advanced User Interface|r|c00BFFF's minimap first. Please, always test/compare your minimaps one by one.")
        end
        FyrMM.minimapConflictMessage = true
    elseif VOTANS_MINIMAP and VOTANS_MINIMAP.account.enableMap then -- disables to avoid conflicts with Votan's minimap
        if not FyrMM.minimapConflictMessage then
            d("|ceeeeeeMiniMap by |c006600Fyrakin |ceeeeee v" .. FyrMM.Panel.version .. "|r" ..
                "|c00BFFF is disabled to avoid conflicts with |cFF0000Votan|r|c00BFFF's minimap. To use Minimap by |c006600Fyrakin|r|c00BFFF you need to disable |cFF0000Votan|r|c00BFFF's minimap first. Please, always test/compare your minimaps one by one.")
        end
        FyrMM.minimapConflictMessage = true
    else
        FyrMM.minimapConflictMessage = false
    end
    
    FyrMM.InCombatAutoHideCheck()

    -- menus, scenes stuff
    local siegeControlling = IsPlayerControllingSiegeWeapon()

    
    local hudShowing = HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()

    if siegeControlling and FyrMM.SV.Siege and not FyrMM.manuallyHidden then -- controlling siege weapon
        FyrMM.Visible = true
    elseif not hudShowing or FyrMM.AutoHidden or FyrMM.minimapConflictMessage or (FyrMM.isInHouse and FyrMM.SV.InHouseAutoHide) or (FyrMM.SV.InEndlessDungeonAutoHide and IsInstanceEndlessDungeon()) then
        FyrMM.Visible = false
    elseif not FyrMM.manuallyHidden then
        FyrMM.Visible = true
    end

    if FyrMM.manuallyHidden then                              -- if hidden by user, never show
        FyrMM.Hide()
    elseif FyrMM.Visible == false or FyrMM.noMap == true then -- not visible or no map data
        FyrMM.Hide()
    else                                                      -- if everything is good we show the mini map
        DelayedShow()
    end

    if FyrMM.Visible == true and FyrMM.noMap == true then -- reload in case of problem
        FyrMM.noMap = false
        DelayedReload()
        DelayedShow()
        return
    end

    -- checks for Mini compass
    if FyrMM.SV.miniCompassOption and not COMPASS_FRAME:GetBossBarActive() then
        if ZO_CompassFrame:IsHidden() and not Fyr_MM:IsHidden() then
            ZO_CompassFrame:SetHidden(false)
        end
        FyrMM.SetMiniCompass()
    elseif FyrMM.SV.miniCompassOption and COMPASS_FRAME:GetBossBarActive() then
        if FyrMM.SV.miniCompassNoBossBar then
            if not ZO_CompassFrame:IsHidden() then
                ZO_CompassFrame:SetHidden(true)
            end
        else
            FyrMM.compassDefaultWidth = FyrMM.compassDefaultWidth or 650
            local width = ZO_CompassFrame:GetWidth()
            if width ~= FyrMM.compassDefaultWidth then
                ZO_CompassFrame:SetWidth(FyrMM.compassDefaultWidth)
                if width ~= MM_GetMapWidth() - 10 then
                    FyrMM.compassDefaultWidth = width
                end
            end
        end
    end
end

function FyrMM.WorldMapShowHide()
    if ZO_WorldMap:IsHidden() then
        FyrMM.UnregisterUpdates()
        CancelUpdates()
        FyrMM.worldMapShowing = true
        FyrMM.Reloading = true
    else
        CurrentTasks = {}
        FyrMM.worldMapShowing = false
        FyrMM.Reloading = false
    end
end

function FyrMM.SetMapToPlayerLocation()
    
	if Fyr_MM:IsHidden() then
		return
	end

    if GetMapFilterType() == 0 then
        zo_callLater(FyrMM.SetMapToPlayerLocation, 50) -- zo_callLater should be ok, I doubt GetMapFilterType() can constantly be at 0
        return
    end
    if FyrMM.worldMapShowing 
	or (ZO_QuestJournal and not ZO_QuestJournal:IsHidden()) then
        return
    end
    if FyrMM.DisableSubzones == true and GetMapType() ~= 1 then
        return
    end

    if FyrMM.DisableSubzones == true and GetMapType() == 1 and not IsUnitInDungeon("player") and not IsPlayerInRaid() and not IsActiveWorldBattleground() and not IsInAvAZone() then
        SetMapToZone()
        return true
    end

    if SetMapToPlayerLocation() ~= SET_MAP_RESULT_CURRENT_MAP_UNCHANGED then -- SET_MAP_RESULT_CURRENT_MAP_UNCHANGED = 1 SET_MAP_RESULT_FAILED = 0 SET_MAP_RESULT_MAP_CHANGED = 2
        
		if FyrMM.DebugMode then
			CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "OnWorldMapChanged (SetMapToPlayerLocation)"..tostring(GetGameTimeMilliseconds()))
		end
        
		CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
		return true
    end
	
end

function FyrMM.Hide()
    CurrentMap.afkAnimTimeStamp = CurrentMap.currentTimeStamp
		
	if GetInteractionType() ~= INTERACTION_FAST_TRAVEL then 
	   FyrMM.FastTravelOpen = false
	end 
    if Fyr_MM:IsHidden() then
        return
    end
    FyrMM.UnregisterUpdates()
    CancelUpdates()
    Fyr_MM_Wheel_Background:SetHidden(true)
    Fyr_MM_Menu:SetHidden(true)
    Fyr_MM_Coordinates:SetHidden(true)
    Fyr_MM_Axis_Control:SetHidden(true)
    Fyr_MM_Scroll_WheelCenter:SetHidden(true)
    Fyr_MM_Scroll_WheelNS:SetHidden(true)
    Fyr_MM_Scroll_WheelWE:SetHidden(true)
    Fyr_MM_Frame_Wheel:SetHidden(true)
    if not FyrMM.SV.ShowBorder then
        Fyr_MM_Border:SetAlpha(0)
    end
    Fyr_MM:SetMouseEnabled(false)
    Fyr_MM_Menu:SetMouseEnabled(false)
    Fyr_MM_Zone_Background:SetHidden(true)
    Fyr_MM_ZoneFrame:SetHidden(true)
    Fyr_MM_Zone:SetText("")
    Fyr_MM_Speed:SetHidden(true)
    Fyr_MM:SetMouseEnabled(false)
    Fyr_MM_Frame_Control:SetMouseEnabled(false)
    Fyr_MM_ZoneFrame:SetMouseEnabled(false)
    Fyr_MM:SetHidden(true)
end

function FyrMM.Show_WheelScrolls()
    FyrMM.UpdateMapTiles(true)
    Fyr_MM_Wheel_Background:SetHidden(not FyrMM.SV.WheelMap)
    Fyr_MM_Scroll_WheelCenter:SetHidden(not FyrMM.SV.WheelMap)
    Fyr_MM_Scroll_WheelNS:SetHidden(not FyrMM.SV.WheelMap)
    Fyr_MM_Scroll_WheelWE:SetHidden(not FyrMM.SV.WheelMap)
    Fyr_MM_Scroll:SetHorizontalScroll(CurrentMap.hpos)
    Fyr_MM_Scroll:SetVerticalScroll(CurrentMap.vpos)
   -- Fyr_MM_Scroll_WheelCenter:SetHorizontalScroll(CurrentMap.hpos)
    --Fyr_MM_Scroll_WheelCenter:SetVerticalScroll(CurrentMap.vpos)
   -- Fyr_MM_Scroll_WheelNS:SetHorizontalScroll(CurrentMap.hpos)
   -- Fyr_MM_Scroll_WheelNS:SetVerticalScroll(CurrentMap.vpos)
   -- Fyr_MM_Scroll_WheelWE:SetHorizontalScroll(CurrentMap.hpos)
   -- Fyr_MM_Scroll_WheelWE:SetVerticalScroll(CurrentMap.vpos)
end

function FyrMM.Show()
    if FyrMM.Reloading or not Fyr_MM:IsHidden() then
        return
    end 
	
    if FyrMM.ActionMapMode then
	    FyrMM.ActionMap.Hide()
	 end

    if not (IsPlayerControllingSiegeWeapon() and FyrMM.SV.Siege) then
        if not FyrMM.Visible or FyrMM.worldMapShowing or not ZO_KeybindStripControl:IsHidden() or
            (ZO_InteractWindow and not ZO_InteractWindow:IsHidden()) or 
			not ZO_GameMenu_InGame:IsHidden() or
            WINDOW_MANAGER:IsSecureRenderModeEnabled() then
            return
        end
    end

    if FyrMM.Halted and FyrMM.Visible and not FyrMM.worldMapShowing and FyrMM.HaltTimeOffset ~= 0 then
        if GetFrameTimeMilliseconds() - FyrMM.HaltTimeOffset > 1000 then
            FyrMM.RegisterUpdates()
        end
    end

    FyrMM.SetMapToPlayerLocation()
    if Fyr_MM:IsHidden() then
        zo_callLater(function() -- zo_callLater ok
            FyrMM.UpdateMapTiles(true)
            FyrMM.RegisterUpdates()
        end, 5) -- was 100

        Fyr_MM_Frame_Wheel:SetHidden(not FyrMM.SV.WheelMap)
        if FyrMM.SV.WheelMap then
            FyrMM.Show_WheelScrolls()
        end
        Fyr_MM_Frame_Control:SetHidden(not FyrMM.SV.WheelMap)
        Fyr_MM:SetHidden(false)
        Fyr_MM_Menu:SetHidden(FyrMM.SV.MenuDisabled)
        Fyr_MM_Menu:SetMouseEnabled(not FyrMM.SV.MenuDisabled)
        Fyr_MM_Zone_Background:SetHidden(not FyrMM.SV.ShowZoneBackground)
        Fyr_MM_ZoneFrame:SetHidden(FyrMM.SV.HideZoneLabel)
        if not FyrMM.SV.HideZoneLabel then
            FyrMM.UpdateLabels()
        end
        Fyr_MM_Coordinates:SetHidden(not FyrMM.SV.ShowPosition)
        Fyr_MM_Axis_Control:SetHidden(not (FyrMM.SV.RotateMap or FyrMM.SV.BorderPins))
        Fyr_MM_Speed:SetHidden(not FyrMM.SV.ShowSpeed)
        Fyr_MM_ZoneFrame:SetMouseEnabled(true)
        Fyr_MM:SetMouseEnabled(true)
    end

    if FyrMM.SV.ShowBorder then
        Fyr_MM_Border:SetAlpha(100)
    end

    Fyr_MM:SetMouseEnabled(true)
    FyrMM.RequestQuestPinUpdate() -- test 03/05/2023
    if FyrMM.checkLater == true then
        FyrMM.ZoneCheck()
		    FyrMM.skyshardPins()
    end
	
	CurrentMap.afkAnimTimeStamp = CurrentMap.currentTimeStamp
	
end

-------------------- ACTION MAP 

function FyrMM.ActionMap.Show() 
	if not IsPlayerActivated() then return end
  
  local isValid, point, relativeTo, relativePoint, offsetX, offsetY = Fyr_MM:GetAnchor(0)
  if isValid then
     FyrMM.lastTLCanchor = { point, GuiRoot, relativePoint, offsetX, offsetY }
  end
  
    FyrMM.ActionMapMode = true
	
    Fyr_MM_Border:SetHidden(true)
   
    --Fyr_MM_Frame_Wheel:SetHidden(true)
	Fyr_MM_Wheel_Background:SetHidden(true)
	Fyr_MM_Frame_RoundMenu:SetHidden(true)
	Fyr_MM_Frame_SquareMenu:SetHidden(true)
	Fyr_MM_Scroll_Fill:SetHidden(true)
   	
	Fyr_MM_Frame_Control:SetHidden(false)
	

    Fyr_MM_Menu:SetHidden(true)
    Fyr_MM_Coordinates:SetHidden(true)
    Fyr_MM_Zone_Background:SetHidden(true)
    Fyr_MM_ZoneFrame:SetHidden(true)
    Fyr_MM_Speed:SetHidden(true)
	
	
	Fyr_MM_Bg:SetHidden(true) --SetColor(0, 0, 0, 0)
	
	local actionMapAlpha = 0.40
	Fyr_MM:SetAlpha(actionMapAlpha)
	Fyr_MM_Scroll_WheelWE:SetAlpha(actionMapAlpha)
	Fyr_MM_Scroll_WheelNS:SetAlpha(actionMapAlpha)
	Fyr_MM_Scroll_WheelCenter:SetAlpha(actionMapAlpha)
	Fyr_MM_Axis_Control:SetAlpha(actionMapAlpha)
	
	--Fyr_MM_Scroll_WheelCenter:SetDesaturation(1)
	
	local screenCenterX, screenCenterY = GuiRoot:GetCenter()
	local screenWidth, screenHeight = GuiRoot:GetDimensions()
	local actionMapSize = math.min(screenWidth,screenHeight)/1.25 
	
	Fyr_MM:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, screenCenterX/2, screenCenterY/8)
	
	
	--Fyr_MM_Wheel_Background:SetDimensions(actionMapSize+8, actionMapSize+8) 
	Fyr_MM_Scroll:SetHeight(actionMapSize)
	Fyr_MM:SetHeight(actionMapSize)
	Fyr_MM_Scroll_Fill:SetHeight(actionMapSize)
	
	
	Fyr_MM_Scroll:SetWidth(actionMapSize)
	Fyr_MM:SetWidth(actionMapSize)
	FyrMM.MapHalfDiagonal()
	
  FyrMM.UpdateMapTiles(true)
   
end





function FyrMM.ActionMap.Hide() 
   FyrMM.ActionMapMode = false
   
  Fyr_MM:SetAlpha(FyrMM.SV.MapAlpha/100) 
	Fyr_MM_Scroll_WheelWE:SetAlpha(FyrMM.SV.MapAlpha/100)
	Fyr_MM_Scroll_WheelNS:SetAlpha(FyrMM.SV.MapAlpha/100)
	Fyr_MM_Scroll_WheelCenter:SetAlpha(FyrMM.SV.MapAlpha/100)
  Fyr_MM_Axis_Control:SetAlpha(1)	
   
  if not FyrMM.SV.WheelMap then
		Fyr_MM_Scroll:SetHeight(FyrMM.SV.MapHeight)
		Fyr_MM_Border:SetHeight(FyrMM.SV.MapHeight+8)
		Fyr_MM:SetHeight(FyrMM.SV.MapHeight)
		Fyr_MM_Scroll_Fill:SetHeight(FyrMM.SV.MapHeight)
		FyrMM.MapHalfDiagonal()
	end
   

	Fyr_MM_Scroll:SetWidth(FyrMM.SV.MapWidth)
	Fyr_MM_Border:SetWidth(FyrMM.SV.MapWidth+8)
	Fyr_MM_Frame_Wheel:SetDimensions(FyrMM.SV.MapWidth+8, FyrMM.SV.MapWidth+8)
	Fyr_MM_Frame_RoundMenu:SetDimensions(FyrMM.SV.MapWidth, FyrMM.SV.MapWidth/4)
	Fyr_MM_Frame_RoundMenu:ClearAnchors()
	Fyr_MM_Frame_RoundMenu:SetAnchor(TOPLEFT, Fyr_MM, TOPLEFT, 0, FyrMM.SV.MapWidth - FyrMM.SV.MapWidth/9)
	Fyr_MM_Frame_SquareMenu:SetDimensions(FyrMM.SV.MapWidth, FyrMM.SV.MapWidth/4)
	Fyr_MM_Wheel_Background:SetDimensions(FyrMM.SV.MapWidth+8, FyrMM.SV.MapWidth+8)
	Fyr_MM:SetWidth(FyrMM.SV.MapWidth)
	Fyr_MM_Scroll_Fill:SetWidth(FyrMM.SV.MapWidth)
	if FyrMM.SV.WheelMap then
		Fyr_MM_Scroll:SetHeight(FyrMM.SV.MapWidth)
		Fyr_MM_Border:SetHeight(FyrMM.SV.MapWidth+8)
		Fyr_MM:SetHeight(FyrMM.SV.MapWidth)
		Fyr_MM_Scroll_Fill:SetHeight(FyrMM.SV.MapWidth)
		FyrMM.MapHalfDiagonal()
	end
	MM_RearrangeMenu()


   MM_SetMapWidth(FyrMM.SV.MapWidth)
   
   Fyr_MM:SetAnchor(FyrMM.lastTLCanchor)
   
   FyrMM.Hide()
   FyrMM.Show()

end



function FyrMM.ActionMap.Toggle()
   if FyrMM.ActionMapMode then
       FyrMM.ActionMap.Hide()  
   else
       FyrMM.ActionMap.Show()
   end
end


----------------------------------------------------------------------------------------------------------------


function FyrMM.ZoneUpdate()
    if FyrMM.Reloading then
        return
    end
    if FyrMM.SV.DisableSubzones then
        FyrMM.ZoneCheck()
    end
end

-- 19/06/2026 Optimization: Avoid table creation in playerMoved() called every 30ms (33 tables/sec)
function FyrMM.playerMoved()
    local nx, ny = CurrentMap.PlayerNX, CurrentMap.PlayerNY
    if FyrMM.oldPosNX == nx and FyrMM.oldPosNY == ny then
        return false
    end
    FyrMM.oldPosNX = nx
    FyrMM.oldPosNY = ny
    return true
end

local function ZoneCheck()
    if Fyr_MM:IsHidden() then
        FyrMM.checkLater = true
		    FyrMM.CheckingZone = false
        return
    end
    FyrMM.RegisterUpdates() -- Solves the bug where custom pins of parent zone are displayed on current subzone map after porting to a wayshrine in the same subzone 24/07/2022

    if not FyrMM.worldMapShowing then
        if GetMapFilterType() == 0 then
            zo_callLater(ZoneCheck, 50) -- zo_callLater should be ok I doubt GetMapFilterType() can constantly be at 0
            FyrMM.CheckingZone = false
		   return
        end
        FyrMM.CheckingZone = true

        local filename, _, _ = FyrMM.GetCurrentMapTextureFileInfo()
        if filename == "tamriel_0" then
            FyrMM.CheckingZone = false
            return
        end
		
        CurrentMap.ZoneIndex = GetCurrentMapZoneIndex()

        if string.lower(CurrentMap.filename) ~= string.lower(filename) then
            FyrMM.UnregisterUpdates()
            CancelUpdates()
            FyrMM.ReleaseAllEventUnitPins() -- world event units don't carry over between zones
            local ZoneIndex = 0
            local mapId = FyrMM.GetMapId()

            if FyrMM.MapSizes[mapId] then
                FyrMM.ResetOrLoadCustomPinList()
            end

            if ZoneIndex == 0 then
                FyrMM.SetMapToPlayerLocation()
                CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
            else
                CurrentMap.ZoneIndex = ZoneIndex
            end

            FyrMM.UpdateMapInfo()
            FyrMM.UpdateMapTiles(true)
            FyrMM.MovementSpeed = 0
            FyrMM.MovementSpeedPrevious = 0
            FyrMM.MovementSpeedMax = 0
            CustomPinIndex = {}
			--FyrMM.CustomPinTypesToCheckForConsistence = {}

            if IsInAvAZone() then
			    FyrMM.dirtyLinks = true
                zo_callLater(FyrMM.RequestKeepRefresh, 5) -- WAS 1000 / zo_callLater ok
            end

            CurrentMap.PlayerNX, CurrentMap.PlayerNY, CurrentMap.PlayerHeading = GetMapPlayerPosition("player")
            CurrentMap.MapId = mapId
            CurrentMap.MapContentType = GetMapContentType()

            CALLBACK_MANAGER:FireCallbacks("OnFyrMiniNewMapEntered")
        end

        if FyrMM.SV.RotateMap then
            Fyr_MM_Scroll:SetHorizontalScroll(0)
            Fyr_MM_Scroll:SetVerticalScroll(0)
        else
            Fyr_MM_Scroll:SetHorizontalScroll(CurrentMap.hpos)
            Fyr_MM_Scroll:SetVerticalScroll(CurrentMap.vpos)
        end

        -- if FyrMM.SV.WheelMap then
            -- FyrMM.WheelScroll(CurrentMap.hpos, CurrentMap.vpos)
        -- end

        FyrMM.customPinsUpdateCount = nil
		
		zo_callLater(FyrMM.checkWaypoints, 1000) -- zo_callLater ok 

    end
    FyrMM.CheckingZone = false
    FyrMM.checkLater = false
end

function FyrMM.ZoneCheck()
    if FyrMM.CheckingZone then  
        return
    end
	FyrMM.CheckingZone = true
	zo_callLater(ZoneCheck, 50) -- removing this zo_callLater causes pins not removing when switching maps on main worldmap 
end

local function TaskExists(tag)
    for i, v in pairs(CurrentTasks) do
        if CurrentTasks[i] ~= nil then
            if GetFrameTimeMilliseconds() - CurrentTasks[i].RequestTimeStamp < FYRMM_QUEST_PIN_REQUEST_TIMEOUT then
                if CurrentTasks[i][1] == tag[1] and CurrentTasks[i][2] == tag[2] and CurrentTasks[i][3] == tag[3] and
                    CurrentTasks[i].isBreadcrumb == tag.isBreadcrumb then
                    return true
                end
            else
                -- CurrentTasks[i] = nil
            end
        end
    end
    return false
end

local function DestroyTasks()
    for i, v in pairs(CurrentTasks) do
        if CurrentTasks[i] ~= nil then
            CurrentTasks[i] = nil
        end
    end
end

local function RemoveObsoleteQuestPins()
    local t = GetGameTimeMilliseconds()
	local removed	
	
    for i, v in pairs(QuestPins) do
        if questpinDataExists(v, RequestedQuestPins) == nil then
            RemoveQuestPin(v.Pin)
			removed = true
        end
    end
	
    local pinCount = Fyr_MM_Scroll_Map_QuestPins:GetNumChildren()
    local l
    local nilcount = 0

	
    for i = 1, pinCount + 100 do
        l = GetControl("Fyr_MM_Scroll_Map_QuestPins_Pin" .. tostring(i))
        if l == nil then
            nilcount = nilcount + 1
            if nilcount > 1 then
                return
            end
        end
        if l ~= nil and l.questdataIndex ~= nil then
            if QuestPins[l.questdataIndex] == nil then
                if l.MM_Tag == nil then
                    RemoveQuestPin(l)
					          removed = true
                else
                    if l.MM_Tag == 1 then
                        if l.secondaryPin ~= nil then
                            l.secondaryPin.MM_Tag = nil
                            RemoveQuestPin(l.secondaryPin)
						              	removed = true
                        end
                        if l.tertiaryPin ~= nil then
                            l.tertiaryPin.MM_Tag = nil
                            RemoveQuestPin(l.tertiaryPin)
					              		removed = true
                        end
                        l.MM_Tag = nil
                        RemoveQuestPin(l)
				            		removed = true
                    end
                end
            end
        end
    end
	
	if removed then 
	   FyrMM.RequestQuestPinUpdate() 
	end   
	
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug","RemoveObsoleteQuestPins "..tostring(GetGameTimeMilliseconds() - t))
    end
end

local function AddMissingQuestPins()
    local properType, pinTexture, size
	local added
    for i, v in pairs(RequestedQuestPins) do
        if questpinDataExists(v, QuestPins) == nil then
            properType, pinTexture, size = FyrMM.GetQuestPinInfo(MAP_PIN_TYPE_TRACKED_QUEST_CONDITION, GetTrackedIsAssisted(TRACK_TYPE_QUEST, v.questIndex), v.isBreadcrumb, v.radius)
            FyrMM.CreateQuestPin(properType, v.tag, v.normalizedX, v.normalizedY, v.radius)
			added = true
        end
    end
	
	if added then
	   FyrMM.RequestQuestPinUpdate() 
	end   
end


function FyrMM.customPinsUpdate(count) -- added by @Masteroshi430

    if FyrMM.Reloading then 
        return
    end
     --d("tries to update custom pins")
    if count ~= FyrMM.customPinsUpdateCount then 
		return
    end
	
    if FyrMM.CustomPinCount == AvailableCustomPins() then
	   --d("custom pins are good!")
        FyrMM.customPinsUpdateCount = nil
        if FyrMM.DebugMode then
            CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "FyrMM.CustomPins End: (" .. tostring(FyrMM.CustomPinCount) .. ") " .. tostring(GetGameTimeMilliseconds()))
        end
        return
    end

    count = count or 1

    if count < 5 then
        if FyrMM.DebugMode then
            CALLBACK_MANAGER:FireCallbacks("FyrMMDebug",
                "FyrMM.CustomPins Start: (" .. tostring(FyrMM.CustomPinCount) .. ") " .. tostring(GetGameTimeMilliseconds()))
        end
        FyrMM.CustomPins()
        --d("check custompins attempt "..count)
        zo_callLater(function() --  zo_callLater OK 
            FyrMM.customPinsUpdate(count + 1)
        end, count * 10)
        FyrMM.customPinsUpdateCount = count + 1
        return
    end
    
    FyrMM.ResetOrLoadCustomPinList()
    --d("check custompins attempt "..count..": resetting custompins!")
end

local lastCustomPinCountCheck = 0
function FyrMM.PinUpdate()
    if FyrMM.Halted then
        return
    end
	
    if ((not FyrMM.Visible or Fyr_MM:IsHidden()) and FyrMM.Initialized) or FyrMM.worldMapShowing then
        return
    end
	
    -- 02/07/2026 optimization: Only capture the debug-profiling timestamp when DebugMode is
    -- actually on, instead of calling GetGameTimeMilliseconds() unconditionally every tick
    -- for a value that's discarded for virtually every user, who has DebugMode off by default.
    local a = FyrMM.DebugMode and GetGameTimeMilliseconds() or nil
	
	CurrentMap.ZoneIndex = GetCurrentMapZoneIndex()
	
	if NeedCheckRemoveInvalidQuestPins then 
	   FyrMM.RemoveInvalidQuestPins() 
	   NeedCheckRemoveInvalidQuestPins = false
	end 


    if FyrMM.currentPOICount == 0 then
        if MM_GetNumPOIs(CurrentMap.ZoneIndex) ~= 0 then
			FyrMM.POIPins()
		end
    end

    if FyrMM.currentLocationsCount == 0 then 
        if MM_GetNumMapLocations() ~= 0 then
          FyrMM.LocationPins()
        end
    end

    if FyrMM.currentWayshrineCount == 0 then
	     if GetNumFastTravelNodes() ~= 0 and FyrMM.wayshrineCheckMapId ~= CurrentMap.MapId then
			    FyrMM.Wayshrines()
       end	
    end


    -- 02/07/2026 optimization: AvailableCustomPins() walks a nested table of every custom pin
    -- every time it's called, purely to catch drift in FyrMM.CustomPinCount (which is already
    -- incrementally tracked at every add/remove site). Running that full re-walk on every
    -- PinUpdate tick (up to 10x/sec by default) was wasted work in the common case where nothing
    -- changed. Throttle it to twice a second - the cheap empty-list and new-pin-detected checks
    -- stay fully responsive every tick.
    local countMismatch = false
    local now = GetGameTimeMilliseconds()
    if now - lastCustomPinCountCheck > 500 then
        lastCustomPinCountCheck = now
        countMismatch = FyrMM.CustomPinCount ~= AvailableCustomPins()
    end

    if (countMismatch or ZO_IsTableEmpty(FyrMM.CustomPinList) or detectedNewCustomPin) and not IsCustomPinsLoading() then -- and not IsCustomPinsLoading() test 02/01/2024
        if ZO_IsTableEmpty(FyrMM.CustomPinList) then
            FyrMM.ResetOrLoadCustomPinList()
        elseif detectedNewCustomPin then
		     --d("detected new custom pin")
            FyrMM.CheckForNewCustomPins()
		elseif not FyrMM.customPinsUpdateCount then
		   -- d(FyrMM.CustomPinCount.." "..AvailableCustomPins()) 
            FyrMM.customPinsUpdate()
		 end
    end

    if ZO_IsTableEmpty(CurrentTasks) and QuestPinsUpdating and not QuestTasksPending then
        RemoveObsoleteQuestPins()
        AddMissingQuestPins()
        GetNumBorderPins()
        QuestPinsUpdating = false
    end

    if (NeedQuestPinUpdate or FyrMM.questPinCount == 0) and GetQuestJournalMaxValidIndex() > 0 then
        if not QuestPinsUpdating then
            if not (ZO_IsTableEmpty(CurrentTasks) and GetFrameTimeMilliseconds() - FyrMM.LastQuestPinRequest < FYRMM_QUEST_PIN_REQUEST_MINIMUM_DELAY) then
                RequestedQuestPins = {}
                FyrMM.UpdateQuestPins()
                NeedQuestPinUpdate = false
				NeedCheckRemoveInvalidQuestPins = true
            end
        end
    end
	
	FyrMM.skyshardPinsZoneCheck()


    if FyrMM.DebugMode and a then
        a = GetFrameTimeMilliseconds() - a
        if a > 0 then
            CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "FyrMM.PinUpdate " .. tostring(a))
        end
    end
end

function FyrMM.Debug_d(value)
    if FyrMM.DebugMode and FyrMM.SV then
        if FyrMM.SV.DebugLog == nil then
            FyrMM.SV.DebugLog = {}
        end
        local t = GetGameTimeMilliseconds() - floor(GetGameTimeMilliseconds() / 1000) * 1000
        d("[" .. GetTimeString() .. string.format("] %s", tostring(value)))
        table.insert(FyrMM.SV.DebugLog,
            "[" .. GetTimeString() .. "." .. tostring(t) .. "] FPS:" .. tostring(zo_round(GetFramerate() * 10) / 10) ..
            " RAM:" .. tostring(zo_round((collectgarbage("count") / 1024) * 100) / 100) .. " MAP:" ..
            tostring(CurrentMap.MapId) .. " LOC:" ..
            string.format("%05.02f, %05.02f", zo_round(CurrentMap.PlayerNX * 10000) / 100,
                zo_round(CurrentMap.PlayerNY * 10000) / 100) .. " FN:" .. tostring(value))
    else
        FyrMM.SV.DebugLog = nil
    end
end

function FyrMM.SetMiniCompass()
    -- 02/07/2026 optimization: Cache MM_GetMapWidth() once - it queries Fyr_MM_Scroll:GetWidth()
    -- from the UI engine, and this function was calling it 9 times for a value that cannot
    -- change within a single call.
    local mapWidth = MM_GetMapWidth()
    if ZO_Compass:GetScale() ~= mapWidth / 350 then
        if not Harvest then
            ZO_Compass:SetScale(mapWidth / 350)
        end
    end
    ZO_Compass:SetDimensions(mapWidth - 10, mapWidth / 20)
    ZO_CompassCenterOverPinLabel:SetScale(mapWidth / 300)
    ZO_CompassFrameLeft:SetDimensions(10, mapWidth / 20)
    ZO_CompassFrameRight:SetDimensions(10, mapWidth / 20)
    ZO_CompassFrame:SetDimensions(mapWidth - 10, mapWidth / 20)

    ZO_CompassCenterOverPinLabel:SetHidden(true) -- hide compass pin text

    ZO_CompassFrame:ClearAnchors()
    if FyrMM.SV.miniCompassLocation == "Top" then
        ZO_CompassFrame:SetAnchor(BOTTOMLEFT, Fyr_MM, TOPLEFT, 5, -5) -- TOP POSITION
    else
        local verticalOffset = 5
        if (not Fyr_MM_Frame_RoundMenu:IsHidden()) and Fyr_MM_Frame_RoundMenu:GetAlpha() ~= 0 then
            verticalOffset = verticalOffset + (Fyr_MM_Frame_RoundMenu:GetHeight() / 3)
        end
        if (not Fyr_MM_Frame_SquareMenu:IsHidden()) and Fyr_MM_Frame_SquareMenu:GetAlpha() ~= 0 then
            verticalOffset = verticalOffset + (Fyr_MM_Frame_SquareMenu:GetHeight() / 3)
        end

        if not Fyr_MM_ZoneFrame:IsHidden() then
            verticalOffset = verticalOffset + Fyr_MM_ZoneFrame:GetHeight()
        end
        ZO_CompassFrame:SetAnchor(TOPLEFT, Fyr_MM, BOTTOMLEFT, 5, verticalOffset) -- BOTTOM POSITION
    end
    ZO_CompassFrame:SetClampedToScreen(true)
    ZO_CompassFrame:SetDrawLayer(-1)
end

function FyrMM.Reload()
    if FyrMM.Reloading then
        return
    end
    local t = GetGameTimeMilliseconds()
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "FyrMM.Reload Start:")
    end
    FyrMM.Reloading = true
    CancelUpdates()
    CustomPinsCopying = false
    FyrMM.LastReload = GetFrameTimeMilliseconds()
    FyrMM.UnregisterUpdates()
    if not FyrMM.SV.HideZoneLabel then
        FyrMM.UpdateLabels()
    end
    FyrMM.MapHalfDiagonal()
    FyrMM.UpdateMapInfo()
    FyrMM.UpdateMapTiles(true)
    FyrMM.PositionUpdate()

    FreeQuestPinIndex = {}
    QuestPins = {}
    LastQuestPinIndex = 0
    FyrMM.DistanceMeasurementStarted = false
    FyrMM.MovementSpeedMax = 0
    FyrMM.questPinCount = 0
    FyrMM.currentLocationsCount = 0
    FyrMM.currentPOICount = 0
    FyrMM.currentForwardCamps = 0
    FyrMM.currentWayshrineCount = 0
    FyrMM.wayshrineCheckMapId = nil -- force Wayshrines() to rebuild after a manual reload (fixes wayshrines disappearing/staying stale)
    FyrMM.currentSkyshardCount = 0
    FyrMM.skyshardPinsMap = nil -- force skyshardPinsZoneCheck() to rebuild skyshard pins after a manual reload (same bug as wayshrines: pins get hidden by CleanUpPins() but the map-gate never reopens on a same-map reload)
    CleanUpPins()
    FyrMM.MeasureDistance()
    FyrMM.PlaceWaypointBorderPins()
    FyrMM.ResetOrLoadCustomPinList()
    FyrMM.UpdateAntiquityDigSites()
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "FyrMM.Reload Done." .. tostring(GetGameTimeMilliseconds() - t))
    end
end

-- function FyrMM.WheelScroll(x, y)
    -- if x and y then
        -- Fyr_MM_Scroll_WheelCenter:SetHorizontalScroll(x) 
        -- Fyr_MM_Scroll_WheelCenter:SetVerticalScroll(y)
        -- Fyr_MM_Scroll_WheelNS:SetHorizontalScroll(x)
        -- Fyr_MM_Scroll_WheelNS:SetVerticalScroll(y)
        -- Fyr_MM_Scroll_WheelWE:SetHorizontalScroll(x)
        -- Fyr_MM_Scroll_WheelWE:SetVerticalScroll(y)
    -- end
-- end

local function SetSpeedLabel(speed)
    if speed == nil then
        speed = 0
    end
	
	if Fyr_MM:IsHidden() then
	       if not Fyr_MM_SpeedLabel:IsHidden() then Fyr_MM_SpeedLabel:SetHidden(true) end 
		   if not Fyr_MM_Speed_Background:IsHidden() then Fyr_MM_Speed_Background:SetHidden(true) end
    elseif speed ~= 0 then
        if FyrMM.SV.SpeedUnit == "ft/s" then
            speed = zo_round(speed * 22.0632) / 100
            Fyr_MM_SpeedLabel:SetText(string.format("%05.02f ft/s", speed))
        end
        if FyrMM.SV.SpeedUnit == "m/s" then
            speed = zo_round(speed * 6.7249) / 100
            Fyr_MM_SpeedLabel:SetText(string.format("%05.02f m/s", speed))
        end
        if FyrMM.SV.SpeedUnit == "%" then
            speed = zo_round(speed * 100) / 100
            Fyr_MM_SpeedLabel:SetText(string.format("%05.01f ", speed) .. "%")
        end
		local speedWidth, speedHeight = Fyr_MM_SpeedLabel:GetTextDimensions() or 100, 20
        Fyr_MM_Speed:SetDimensions(speedWidth + 10, speedHeight + 3)
		
		-- show speed when > 0
		if Fyr_MM_SpeedLabel:IsHidden() then Fyr_MM_SpeedLabel:SetHidden(false) end 
		if Fyr_MM_Speed_Background:IsHidden() then Fyr_MM_Speed_Background:SetHidden(not FyrMM.SV.SpeedBackground) end
		
	-- show label while in cursor mode to allow drag & drop	
    elseif SCENE_MANAGER:IsInUIMode() then
	       Fyr_MM_SpeedLabel:SetText("0 "..FyrMM.SV.SpeedUnit)
		if Fyr_MM_SpeedLabel:IsHidden() then Fyr_MM_SpeedLabel:SetHidden(false) end 
		if Fyr_MM_Speed_Background:IsHidden() then Fyr_MM_Speed_Background:SetHidden(not FyrMM.SV.SpeedBackground) end
	else
	    -- hide speed when 0
        if not Fyr_MM_SpeedLabel:IsHidden() then Fyr_MM_SpeedLabel:SetHidden(true) end 
		if not Fyr_MM_Speed_Background:IsHidden() then Fyr_MM_Speed_Background:SetHidden(true) end
    end
	

end

local function ChangeAfkSize(control, desired)
    if control == nil then
    	return
	end
	
	if not FyrMM.Visible or IsUnitInCombat("player") or CurrentMap.currentTimeStamp < (CurrentMap.movedTimeStamp + 60000) then
	    desired = 0
	end
	
    local size = control:GetWidth() 
	local _,_,rotation =  control:GetTransformRotation()
	local randomRotation = math.random(1, 3)
	if randomRotation == 1 then
	    control:SetTransformRotationZ(rotation+(0.0174533*2))
	elseif randomRotation == 2 then
	    control:SetTransformRotationZ(rotation-(0.0174533*2))
	end
	
	local newSize
    if desired ~= 0 and size ~= desired then
	   newSize = size + 1  
	   if newSize > desired then
	      newSize = desired
       end
	   control:SetDimensions(newSize, newSize)
	   zo_callLater(function() ChangeAfkSize(control, desired) end ,5) 
	elseif desired == 0 and size ~= desired then
	    newSize = size - 1 
	   if newSize < desired then
	      newSize = desired
       end
	   	  control:SetDimensions(newSize, newSize)
	   if newSize == 0 then
	       control:SetHidden(true)
		   
		   local randomReset = math.random(1, 2)
		   if randomReset == 1 and FyrMM.Visible and not IsUnitInCombat("player") then
              CurrentMap.afkAnimTimeStamp = CurrentMap.movedTimeStamp
		   end
           return 		   
	   end

	   zo_callLater(function() ChangeAfkSize(control, desired) end ,5)
    end
end

local function LogPosition() -- called every 30ms
    if FyrMM.worldMapShowing then return end
    local MapId = FyrMM.GetMapId()
    local size = CurrentMap.TrueMapSize
    local gameTime = GetGameTimeMilliseconds()

    CurrentMap.PlayerNX, CurrentMap.PlayerNY, CurrentMap.PlayerHeading = GetMapPlayerPosition("player")
    if FyrMM.SV.ShowSpeed then
        -- 19/06/2026 Optimization: Reuse existing log tables instead of allocating new ones every 30ms (33 tables/sec)
        PositionLogCounter = PositionLogCounter + 1
        local logEntry = PositionLog3D[PositionLogCounter]
        if not logEntry then
            logEntry = {}
            PositionLog3D[PositionLogCounter] = logEntry
        end
        local zoneIndex, x, y, z = GetUnitWorldPosition("player")
        logEntry[1] = zoneIndex
        logEntry[2] = x
        logEntry[3] = y
        logEntry[4] = z
        logEntry[5] = GetFrameTimeMilliseconds()
        logEntry[6] = CurrentMap.PlayerNX
        logEntry[7] = CurrentMap.PlayerNY
    end
    CurrentMap.CameraHeading = GetPlayerCameraHeading()
    CurrentMap.PlayerTurned = (CurrentMap.Heading ~= abs(CurrentMap.PlayerHeading - doublePi))
    CurrentMap.Heading = smoothHeadingRotation()

    CurrentMap.PlayerMoved = FyrMM.playerMoved()
	
    if zo_round(CurrentMap.PlayerNX * 100) / 100 <= 0 or zo_round(CurrentMap.PlayerNY * 100) / 100 <= 0 or
        CurrentMap.PlayerNX >= 1 or CurrentMap.PlayerNY >= 1 then
        if not Fyr_MM:IsHidden() then
            zo_callLater(FyrMM.SetMapToPlayerLocation, 50) -- only called if X Y data is wrong so should be ok  
        end
    end

    if MapId ~= CurrentMap.MapId and FyrMM.CheckingZone == false then
        FyrMM.ZoneCheck()
    end
	
    CurrentMap.PlayerX, CurrentMap.PlayerY = Fyr_MM_Scroll_Map:GetDimensions()
    CurrentMap.PlayerX = CurrentMap.PlayerX * CurrentMap.PlayerNX
    CurrentMap.PlayerY = CurrentMap.PlayerY * CurrentMap.PlayerNY
    CurrentMap.currentTimeStamp = gameTime

    if CurrentMap.PlayerMoved then
        CurrentMap.movedTimeStamp = gameTime
 	elseif (not FyrMM.SV.noEyeFK) and CurrentMap.currentTimeStamp > (CurrentMap.movedTimeStamp + 60000) and FyrMM.Visible then -- 1mn afk -- AFK ANIMATION AKA eyeFK
	       if IsInteracting() then -- disable EyeFK when interacting
		      CurrentMap.afkAnimTimeStamp = CurrentMap.currentTimeStamp 
		   end 
		   if CurrentMap.afkAnimTimeStamp then
			   if CurrentMap.currentTimeStamp > (CurrentMap.afkAnimTimeStamp + 30000) and not IsUnitInCombat("player") then -- 30s without afk animation
					if FyrMM.SV.WheelMap then 
					  
					  local afkAnimation = GetControl("Fyr_MM_AFK_animation")
					  if afkAnimation == nil then
						 afkAnimation = WINDOW_MANAGER:CreateControl("Fyr_MM_AFK_animation", Fyr_MM_Frame_Wheel, CT_TEXTURE)
					  end
	 
					  local radius = Fyr_MM_Frame_Wheel:GetWidth()/2
					  
					  local angle =  math.random()*pi*2 -- random angle
					  local x = zo_cos(angle)*radius
					  local y = zo_sin(angle)*radius
					  
					  afkAnimation:SetTexture("/esoui/art/pregameanimatedbackground/magma/ouroborosinner.dds")
					  
					  local randomReset = math.random(1, 2)
					  if randomReset == 1 then
					      afkAnimation.m_textureAnimTimeline = nil
					  end
					  local randomPlaybackType = math.random(1, 2)
					  local playbackType = ANIMATION_PLAYBACK_LOOP
					  if randomPlaybackType == 2 then
					      playbackType = ANIMATION_PLAYBACK_PING_PONG 
					  end
					  
					  afkAnimation:SetHidden(false)
					  afkAnimation:SetDimensions(1, 1)
					  local randomRotation = math.random(1, 2)
					  if randomRotation == 1 then
						  afkAnimation:SetTransformRotationZ(math.rad(0))
					  else
						  afkAnimation:SetTransformRotationZ(math.rad(180))
					  end
					  afkAnimation:ClearAnchors()
					  afkAnimation:SetDrawTier(DT_HIGH)
					  afkAnimation:SetAnchor(CENTER, Fyr_MM_Frame_Wheel, CENTER, x, y) 
					  if not afkAnimation.m_textureAnimTimeline then
					     afkAnimation.m_textureAnimTimeline = "yes"
					     FyrMM.PlayTextureAnimation(afkAnimation, 16, 16, 18, LOOP_INDEFINITELY, playbackType)
					  end
					  local randomSize = math.random(16, 32)
					  ChangeAfkSize(afkAnimation, randomSize)
					  
					  local randomTime = math.random(5000, 12000)
					  zo_callLater(function()
						  ChangeAfkSize(afkAnimation, 0)
					  end, randomTime) 				  
			   
					  CurrentMap.afkAnimTimeStamp = CurrentMap.currentTimeStamp
				  
				  else -- squaremap
				      if not FyrMM.SV.RotateMap then
						  local afkAnimation = GetControl("Fyr_MM_AFK_animation")
						  if afkAnimation == nil then
							 afkAnimation = WINDOW_MANAGER:CreateControl("Fyr_MM_AFK_animation", Fyr_MM, CT_TEXTURE)
						  end
						  
						  afkAnimation:SetTexture("/esoui/art/pregameanimatedbackground/magma/ouroborosinner.dds")
						  
						  local randomReset = math.random(1, 2)
						  if randomReset == 1 then
							  afkAnimation.m_textureAnimTimeline = nil
						  end
						  local randomPlaybackType = math.random(1, 2)
						  local playbackType = ANIMATION_PLAYBACK_LOOP
						  if randomPlaybackType == 2 then
							  playbackType = ANIMATION_PLAYBACK_PING_PONG 
						  end  
					  
						  afkAnimation:SetHidden(false)
						  afkAnimation:SetDimensions(1, 1)
						  local randomRotation = math.random(1, 2)
						  if randomRotation == 1 then
						      afkAnimation:SetTransformRotationZ(math.rad(0))
						  else
						      afkAnimation:SetTransformRotationZ(math.rad(180))
                          end						  
						  local randomSize = math.random(16, 32)
						  
						  afkAnimation:ClearAnchors()
						  afkAnimation:SetDrawTier(DT_HIGH)
						  if not afkAnimation.m_textureAnimTimeline then
							 afkAnimation.m_textureAnimTimeline = "yes"
							 FyrMM.PlayTextureAnimation(afkAnimation, 16, 16, 18, LOOP_INDEFINITELY, playbackType)
						  end
						  
						  local width = Fyr_MM:GetWidth()
						  local height = Fyr_MM:GetHeight()
						  
						  local whichSide = math.random(1, 4)
						  local x, y = 0, 0
						  local randomHeight = math.random(0, height)
						  local randomWidth = math.random(0, width)
						  if whichSide == 1 then -- on top
							 y = 0  
							 x = randomWidth
						  elseif whichSide == 2 then -- on bottom
							 y = height
							 x = randomWidth
						  elseif whichSide == 3 then -- on left
							 x = 0
							 y = randomHeight
						  else -- on right
							 x = width
							 y = randomHeight
						  end
						  
						  afkAnimation:SetAnchor(CENTER,  Fyr_MM, TOPLEFT, x, y)
						  ChangeAfkSize(afkAnimation, randomSize)
						  
						  local randomTime = math.random(5000, 12000)
						  zo_callLater(function()
							  ChangeAfkSize(afkAnimation, 0)
						  end, randomTime) 				  
				   
						  CurrentMap.afkAnimTimeStamp = CurrentMap.currentTimeStamp
				      end
				  end 
			   end
		   else
			   CurrentMap.afkAnimTimeStamp = CurrentMap.movedTimeStamp
		   end
    end

    -- 19/06/2026 Optimization: Only update coordinate label text and dimensions if value changed to avoid UI reflow overhead
    -- 03/07/2026 optimization: The check above only skipped the SetText/GetTextDimensions/SetDimensions
    -- calls, but string.format() itself - which allocates a new string - was still being run
    -- unconditionally every 30ms (33 times/sec), even though its result is thrown away whenever the
    -- displayed coordinates haven't changed (e.g. player standing still, reading a quest, in a menu).
    -- Round to the same precision %05.02f would produce and compare those numbers first, so the
    -- string is only built when it would actually differ from what's already on screen.
    local roundedX = zo_round(CurrentMap.PlayerNX * 10000) / 100
    local roundedY = zo_round(CurrentMap.PlayerNY * 10000) / 100
    if CurrentMap.lastPositionX ~= roundedX or CurrentMap.lastPositionY ~= roundedY then
        CurrentMap.lastPositionX = roundedX
        CurrentMap.lastPositionY = roundedY
        local newText = string.format("%05.02f, %05.02f", roundedX, roundedY)
        Fyr_MM_Position:SetText(newText) -- thanks Garkin
        local textWidth, textHeight = Fyr_MM_Position:GetTextDimensions() or 100, 20
        Fyr_MM_Position_Background:SetDimensions(textWidth + 10, textHeight + 3)
        CurrentMap.lastPositionText = newText
    end
    Fyr_MM_Player_incombat:SetHidden(not (FyrMM.SV.InCombatState and IsUnitActivelyEngaged("player")))
end

local function SpeedMeasure()
    if not FyrMM.SV.ShowSpeed or ZO_IsTableEmpty(PositionLog3D) or not IsPlayerActivated() then 
        return
    end
	
	if Fyr_MM:IsHidden() then
	    SetSpeedLabel(0)
		return
	end

    local multiplier = FyrMM.GetMapMeasureMultiplier()

    local x13d, y13d, z13d, t1 = PositionLog3D[1][2], PositionLog3D[1][3] , PositionLog3D[1][4], PositionLog3D[1][5]
    local x12d, y12d = 0, 0 -- aren't used till after they are assigned in for loop
    local x23d, y23d, z23d, t2, x22d, y22d = 0, 0, 0, 0, 0, 0
    local d3d, v13d, va3d = 0, 0, 0
    local size = FyrMM.MapSizes[CurrentMap.MapId] or FyrMM.currentMap.TrueMapSize

    if IsPlayerMoving() then
        for i = 2, PositionLogCounter do
            local posData = PositionLog3D[i]
            x23d, y23d, z23d, t2, x22d, y22d = posData[2] or 0, posData[3] or 0, posData[4] or 0, posData[5] or 0, posData[6] or 0, posData[7] or 0
            d3d = zo_sqrt((x23d - x13d) ^ 2 + (y23d - y13d) ^ 2 + (z23d - z13d) ^ 2)
            v13d = 0.1487 * d3d / abs((t2 - t1) / 1000)
            x13d, y13d, z13d, t1, x12d, y12d = x23d, y23d, z23d, t2, x22d, y22d
            va3d = va3d + v13d
        end
        if PositionLogCounter == 0 then
            return
        end
		
        local nsize = 0.0143 * zo_sqrt((x23d - x13d) ^ 2 + (y23d - y13d) ^ 2) /
            zo_sqrt((x22d - x12d) ^ 2 + (y22d - y12d) ^ 2)
        if nsize and size and nsize ~= 1e309 and size < nsize then
            FyrMM.currentMap.TrueMapSize = nsize
        end
        va3d = va3d / (PositionLogCounter - 1) * multiplier
    end

    PositionLogCounter = 0
    local MovementSpeedPrevious = FyrMM.MovementSpeedPrevious -- cache global variable
    if MovementSpeedPrevious then
        FyrMM.MovementSpeed = (va3d + MovementSpeedPrevious) / 2
    else
        FyrMM.MovementSpeed = va3d
    end

    if MovementSpeedPrevious ~= FyrMM.MovementSpeed then
        CALLBACK_MANAGER:FireCallbacks("MovementSpeedChanged", va3d)
        FyrMM.MovementSpeedPrevious = FyrMM.MovementSpeed
    end

    if va3d > FyrMM.MovementSpeedMax then
        FyrMM.MovementSpeedMax = va3d
    end
    SetSpeedLabel(va3d)
end

function FyrMM.PositionUpdate()
    if not FyrMM.Visible or Fyr_MM:IsHidden() or FyrMM.worldMapShowing or not FyrMM.Initialized or
        not Fyr_MM_Scroll_Map_0 or not CurrentMap.Dx then
        return
    end

    if FyrMM.GetMapId() ~= CurrentMap.MapId and not FyrMM.CheckingZone then
        FyrMM.ZoneCheck()
    end

    -- 02/07/2026 optimization: Only capture the debug-profiling timestamp when DebugMode is
    -- actually on, instead of calling GetGameTimeMilliseconds() unconditionally every 40ms tick
    -- for a value that's discarded for virtually every user, who has DebugMode off by default.
    local a = FyrMM.DebugMode and GetGameTimeMilliseconds() or nil
    local x = CurrentMap.PlayerNX
    local y = CurrentMap.PlayerNY
    local pheading = CurrentMap.PlayerHeading
    if x == nil or pheading == nil then
        x, y, pheading = GetMapPlayerPosition("player")
    end

    local moved = CurrentMap.PlayerMoved
    CurrentMap.CameraHeading = CurrentMap.CameraHeading or GetPlayerCameraHeading()

    local cpheading = FyrMM.SV.RotateMap and abs(pheading - doublePi) + CurrentMap.CameraHeading or CurrentMap.CameraHeading
    -- 19/06/2026 optimization: Redundant Draw Reduction: only rotate camera texture if heading change is significant (> 0.0001 rad)
    if not CurrentMap.LastCameraRotation or abs(CurrentMap.LastCameraRotation - cpheading) > 0.0001 then
        Fyr_MM_Camera:SetTextureRotation(cpheading)
        CurrentMap.LastCameraRotation = cpheading
    end

    local hpos = (x * (Fyr_MM_Scroll_Map_0:GetWidth() * CurrentMap.Dx)) - (Fyr_MM_Scroll:GetWidth() / 2)
    local vpos = (y * (Fyr_MM_Scroll_Map_0:GetHeight() * CurrentMap.Dx)) - (Fyr_MM_Scroll:GetHeight() / 2)

    local heading = pheading
    if FyrMM.SV.PPStyle ~= GetString(SI_MM_STRING_PLAYERANDCAMERA) then
        if FyrMM.SV.Heading == "CAMERA" then
            heading = CurrentMap.CameraHeading
        end
        if not moved and FyrMM.SV.Heading == "MIXED" then
            heading = CurrentMap.CameraHeading
        end
    end

    if moved and FyrMM.SV.ViewRangeFiltering then
        UpdateCustomPinPositions()
    end

    if ((x < 1.2 and x > -0.2) and (y < 1.2 and y > -0.2)) then -- Can't let the scroll go too far outside view (Black map issue)
        if not Fyr_MM:IsHidden() and moved then
            FyrMM.SetMapToPlayerLocation()
        end
        CurrentMap.hpos = hpos
        CurrentMap.vpos = vpos

        if FyrMM.SV.RotateMap then
            Fyr_MM_Scroll:SetHorizontalScroll(0)
            Fyr_MM_Scroll:SetVerticalScroll(0)
        else
            Fyr_MM_Scroll:SetHorizontalScroll(hpos)
            Fyr_MM_Scroll:SetVerticalScroll(vpos)
        end

        -- if FyrMM.SV.WheelMap then
            -- FyrMM.WheelScroll(CurrentMap.hpos, CurrentMap.vpos)
        -- end
    else
        CurrentMap.hpos = hpos
        CurrentMap.vpos = vpos

        if FyrMM.SV.RotateMap then
            Fyr_MM_Scroll:SetHorizontalScroll(0)
            Fyr_MM_Scroll:SetVerticalScroll(0)
        else
            Fyr_MM_Scroll:SetHorizontalScroll(CurrentMap.hpos)
            Fyr_MM_Scroll:SetVerticalScroll(CurrentMap.vpos)
        end

        -- if FyrMM.SV.WheelMap then
            -- FyrMM.WheelScroll(CurrentMap.hpos, CurrentMap.vpos)
        -- end
    end

    FyrMM.UpdateMapTiles(moved)   -- can cause tiles not updating but should be fixed by now
    CurrentMap.needRescale = true -- REMOVING THIS CAUSES OCCASIONAL PINS DEPHASING ON ROTATING MAPS

    -- 03/07/2026: Call RescaleLinks() directly here instead of relying solely on the indirect
    -- RescalePinPositions chain, so keep-network link positions get reliably re-anchored to the
    -- player's current heading every 40ms while moving/turning, rather than only snapping to a
    -- new position whenever a keep-network event happens to fire.
    if IsInAvAZone() then
        RescaleLinks()
    end

    if FyrMM.SV.RotateMap then
        -- 19/06/2026 optimization: Cache player rotation state to avoid redundant SetTextureRotation calls
        if not CurrentMap.PlayerRotationSetZero then
            Fyr_MM_Player:SetTextureRotation(0)
            CurrentMap.PlayerRotationSetZero = true
            CurrentMap.LastPlayerRotation = nil
        end
        FyrMM.AxisPins()
    else
        CurrentMap.PlayerRotationSetZero = nil
        -- 19/06/2026 optimization: Redundant Draw Reduction: only rotate player texture if heading change is significant (> 0.0001 rad)
        if not CurrentMap.LastPlayerRotation or abs(CurrentMap.LastPlayerRotation - heading) > 0.0001 then
            Fyr_MM_Player:SetTextureRotation(heading)
            CurrentMap.LastPlayerRotation = heading
        end
    end

    if FyrMM.DebugMode and a then
        a = GetGameTimeMilliseconds() - a
        if a > 0 then
            CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "FyrMM.PositionUpdate " .. tostring(a))
        end
    end
end

-------------------------------------------------------------
-- Map Building
-------------------------------------------------------------
-- get map info for minimap
function FyrMM.UpdateMapInfo(IgnoreZone)
    local t = GetGameTimeMilliseconds()
    CurrentMap.ready = false
    CurrentMap.name = GetMapName()
    CurrentMap.tileTexture = string.lower(GetMapTileTexture())
    CurrentMap.Dx, CurrentMap.Dy = GetMapNumTiles()
    local filename, nameNoNum, path = FyrMM.GetCurrentMapTextureFileInfo()
    CurrentMap.filename = string.lower(filename)
    CurrentMap.nameNoNum = nameNoNum
    CurrentMap.path = path
    --CurrentMap.TextureAngle = 0
    local id = FyrMM.GetMapId()

    if string.lower(CurrentMap.filename) == "tamriel_0" then 
        CurrentMap.ready = true
        zo_callLater(FyrMM.UpdateMapInfo, 5) -- mmmmh should be good 
        return
    end

    if CurrentMap.Dx < 2 or CurrentMap.Dy < 2 or CurrentMap.Dx == nil or CurrentMap.Dy == nil then
        if id ~= 0 then
            CurrentMap.Dx, CurrentMap.Dy = GetMapNumTilesForMapId(id)
        else
            CurrentMap.Dx = 3
            CurrentMap.Dy = 3
        end
    end
    CurrentMap.type = GetMapType()
    if not IgnoreZone then
        CurrentMap.ZoneIndex = GetCurrentMapZoneIndex()
    end
    -- if we have no texture we have nothing further to do
    if CurrentMap.tileTexture == "" or CurrentMap.Dx == nil or CurrentMap.Dy == nil then
        FyrMM.noMap = true
        return
    else
        FyrMM.noMap = false
    end

    CurrentMap.numTiles = CurrentMap.Dx * CurrentMap.Dy
    CurrentMap.TrueMapSize = 1
    if id ~= 0 and FyrMM.MapSizes[id] then
        CurrentMap.TrueMapSize = FyrMM.MapSizes[id]
        if FyrMM.SV.MapSizes then
            if FyrMM.SV.MapSizes[CurrentMap.filename] and CurrentMap.TrueMapSize > 1 then
                FyrMM.SV.MapSizes[CurrentMap.filename] = nil
            end
        end
    end

    -- store tile textures in table
    CurrentMap.tiles = {}
    for i = 1, CurrentMap.numTiles do
        table.insert(CurrentMap.tiles, string.lower(GetMapTileTexture(i)))
    end

    if CurrentMap.filename == nil or CurrentMap.filename == "" then
        local filename, _, _ = FyrMM.GetCurrentMapTextureFileInfo()
        CurrentMap.filename = string.lower(filename)
    end

    if FyrMM.SV.ZoomTable[CurrentMap.filename] == nil then
        FyrMM.SV.ZoomTable[CurrentMap.filename] = FYRMM_DEFAULT_ZOOM_LEVEL
        CurrentMap.ZoomLevel = FYRMM_DEFAULT_ZOOM_LEVEL
    else
        CurrentMap.ZoomLevel = FyrMM.SV.ZoomTable[CurrentMap.filename]
    end

    if FyrMM.SV.autoResizePin and CurrentMap.MapId ~= 16 and CurrentMap.MapId ~= 660 and CurrentMap.MapContentType ~= MAP_CONTENT_BATTLEGROUND then
        -- zoom: 1 to 50 default: 10
        FyrMM.pinZoomScale = (CurrentMap.ZoomLevel) / 10
    else
        FyrMM.pinZoomScale = 1
    end

    if id ~= 0 then
        CurrentMap.MapId = id
        if CurrentMap.TrueMapSize == 1 then
            if FyrMM.SV.MapSizes[CurrentMap.filename] then
                CurrentMap.TrueMapSize = FyrMM.SV.MapSizes[CurrentMap.filename]
            end
        end
    else
        CurrentMap.MapId = 0 -- "unknown"
        if FyrMM.SV.MapSizes == nil then
            FyrMM.SV.MapSizes = {}
            FyrMM.SV.MapSizes[CurrentMap.filename] = 1
            CurrentMap.TrueMapSize = 1
        else
            if FyrMM.SV.MapSizes[CurrentMap.filename] ~= nil then
                CurrentMap.TrueMapSize = FyrMM.SV.MapSizes[CurrentMap.filename]
            end
        end
    end

    CurrentMap.ready = true
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "FyrMM.UpdateMapInfo " .. tostring(GetGameTimeMilliseconds() - t))
    end
    CALLBACK_MANAGER:FireCallbacks("OnFyrMiniMapChanged")
end

function FyrMM.GetTileDimensions()    -- gets tile scale for map
    local texW, texH = Fyr_MM_Scroll_Map_0:GetTextureFileDimensions()  or 256, 256 -- 256 = unknown map
     -- or ((texW < 256 or texH < 256) or (texW > 1024 or texH > 1024) or texW == nil or texH == nil) and CurrentMap.filename
    local id = FyrMM.GetMapId()
    local dx, dy = GetMapNumTilesForMapId(id)
    local zoomlevel = CurrentMap.ZoomLevel or FYRMM_DEFAULT_ZOOM_LEVEL

    local tileX = floor(zo_round(((zoomlevel / 10) * texW * dx) / dx) / 2) * 2
    local tileY = floor(zo_round(((zoomlevel / 10) * texW * dy) / dy) / 2) * 2

    return tileX, tileY
end

local Tiles = false
-- 19/06/2026 Optimization: Cache tile updates state to avoid redundant UI re-anchoring & rotation operations
local lastTileUpdate = {}

function FyrMM.UpdateMapTiles(stealth)
    local needRescale = false
    if not stealth and ((not FyrMM.Visible or Fyr_MM:IsHidden()) and not FyrMM.Initialized) then
        return
    end
    if not CurrentMap.ready then
        return
    end
    if string.lower(CurrentMap.filename) == "tamriel_0" then
        return
    end

    -- 02/07/2026 optimization: Moved GetTileDimensions() (which does a texture-file-dimensions
    -- query plus two more native API calls) to after the cache check below, since it was
    -- previously computed unconditionally before an early-return that fires on nearly every
    -- tick for every user - wasting the call ~25x/sec regardless of whether anything changed.
    local mapFilename = CurrentMap.filename
    local zoomLevel = CurrentMap.ZoomLevel
    local rotateMap = FyrMM.SV.RotateMap
    local wheelMap = FyrMM.SV.WheelMap
    local playerX = CurrentMap.PlayerX
    local playerY = CurrentMap.PlayerY
    local heading = CurrentMap.Heading
    local isForce = (stealth == true)

    if not isForce then
        if lastTileUpdate.mapFilename == mapFilename and
           lastTileUpdate.zoomLevel == zoomLevel and
           lastTileUpdate.rotateMap == rotateMap and
           lastTileUpdate.wheelMap == wheelMap then
            -- If rotate is active, we also care if player moved/turned
            if not rotateMap or (lastTileUpdate.playerX == playerX and lastTileUpdate.playerY == playerY and lastTileUpdate.heading == heading) then
                return
            end
        end
    end

    -- Update cache
    lastTileUpdate.mapFilename = mapFilename
    lastTileUpdate.zoomLevel = zoomLevel
    lastTileUpdate.rotateMap = rotateMap
    lastTileUpdate.wheelMap = wheelMap
    lastTileUpdate.playerX = playerX
    lastTileUpdate.playerY = playerY
    lastTileUpdate.heading = heading

    local MM_TileSizeW, MM_TileSizeH = FyrMM.GetTileDimensions()

    if Fyr_MM_Scroll_Map_0:GetTextureFileName():lower() == CurrentMap.tiles[1]:lower() and
        zo_round(Fyr_MM_Scroll_Map_0:GetWidth()) == zo_round(MM_TileSizeW) and zo_round(Fyr_MM_Scroll_Map_0:GetHeight()) ==
        zo_round(MM_TileSizeH) then
        if stealth == GetFrameTimeMilliseconds() then
            return
        end
    else
        if zo_round(Fyr_MM_Scroll_Map_0:GetWidth()) ~= zo_round(MM_TileSizeW) or
            zo_round(Fyr_MM_Scroll_Map_0:GetHeight()) ~= zo_round(MM_TileSizeH) then
            CurrentMap.needRescale = true
        end
    end 

    if Tiles then -- nothing to update if same map
        return
    end
	
    Tiles = true
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "FyrMM.UpdateMapTiles " .. tostring(stealth))
    end
    local sa, sb, centerSize
    local i = 0

    -- 02/07/2026 optimization: Removed a duplicate GetTileDimensions() call here - reuse the
    -- value computed once above, since map id, zoom level, and texture dimensions can't change
    -- within this same function call.
    local mWidth, mHeight = MM_TileSizeW * CurrentMap.Dx, MM_TileSizeH * CurrentMap.Dy
    Fyr_MM_Scroll_Map:SetDimensions(mWidth, mHeight)
    Fyr_MM_Scroll_Map:SetDrawLayer(0) 

    if not FyrMM.SV.WheelMap then 
        Fyr_MM_Bg:SetColor(0, 0, 0, 1)
        Fyr_MM_Scroll_WheelNS:SetHidden(true)
        Fyr_MM_Scroll_WheelCenter:SetHidden(true)
        Fyr_MM_Scroll_WheelWE:SetHidden(true)
    else
        Fyr_MM_Bg:SetColor(1, 1, 1, 0)
        Fyr_MM_Border:SetHidden(true)
        sa = Fyr_MM:GetWidth() - ((50 / 512) * Fyr_MM:GetWidth())
        sb = (220 / 512) * Fyr_MM:GetWidth()
        Fyr_MM_Scroll_WheelWE:SetDimensions(sa, sb)
        Fyr_MM_Scroll_WheelNS:SetDimensions(sb, sa)
        Fyr_MM_Frame_Control:SetDimensions(Fyr_MM:GetWidth(), Fyr_MM:GetWidth())
        Fyr_MM_Frame_Wheel:SetDimensions(Fyr_MM:GetWidth() + 8, Fyr_MM:GetWidth() + 8)

        if FyrMM.SV.RotateMap and CurrentMap.Heading then
            Fyr_MM_Frame_Wheel:SetTextureCoordsRotation(CurrentMap.Heading)
        end

        centerSize = zo_sqrt(2 * Fyr_MM:GetWidth() * Fyr_MM:GetWidth()) / 2
        Fyr_MM_Scroll_WheelCenter:SetDimensions(centerSize, centerSize)

        if CurrentMap.PlayerX == nil or CurrentMap.PlayerY == nil or CurrentMap.Heading == nil then
            local x, y, pheading = GetMapPlayerPosition("player")
            CurrentMap.PlayerNX = x
            CurrentMap.PlayerNY = y
            CurrentMap.PlayerX, CurrentMap.PlayerY = Fyr_MM_Scroll_Map:GetDimensions()
            CurrentMap.PlayerX = CurrentMap.PlayerX * x
            CurrentMap.PlayerY = CurrentMap.PlayerY * y
            CurrentMap.Heading = smoothHeadingRotation()
        end
    end
	
    local tileposX, tileposY, x, y
    
    FyrMM.MapTileCache = FyrMM.MapTileCache or {}
    FyrMM.MapTileNSCache = FyrMM.MapTileNSCache or {}
    FyrMM.MapTileCCache = FyrMM.MapTileCCache or {}
    FyrMM.MapTileWECache = FyrMM.MapTileWECache or {}

    -- 10/07/2026 optimization: the "wheel map" skin (NS/Center/WE tile sets) is an alternate
    -- display mode that's hidden whenever FyrMM.SV.WheelMap is off, which is the common case.
    -- Previously every tile still got 3 extra texture controls fully updated (SetTexture,
    -- SetDimensions, SetDrawLayer, ClearAnchors, rotation, scale, anchor) every single call even
    -- though they were invisible - up to 4x the necessary work per tile, on a function that can
    -- run every ~40ms while RotateMap + player movement are active. Now those 3 sets are only
    -- touched when the wheel map is actually being shown; otherwise they're just hidden once
    -- (only if they were already created from a prior WheelMap session) and left alone.
    local wheelModeActive = FyrMM.SV.WheelMap

    -- 03/07/2026 optimization: Cache map tile UI controls to avoid expensive GetControl lookups and string allocations in hot paths
    for a = 1, CurrentMap.Dy do 
        for b = 1, CurrentMap.Dx do
            i = i + 1
            local idx = i - 1
            local tileControl = FyrMM.MapTileCache[idx]
            if tileControl == nil then
                tileControl = GetControl("Fyr_MM_Scroll_Map_" .. tostring(idx))  
                if tileControl == nil then
                    tileControl = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_"..tostring(idx), Fyr_MM_Scroll_Map, CT_TEXTURE)
                end
                FyrMM.MapTileCache[idx] = tileControl
            end

            tileControl:SetHidden(wheelModeActive)
            if tileControl:GetTextureFileName():lower() ~= CurrentMap.tiles[i]:lower() then
                tileControl:SetTexture(CurrentMap.tiles[i])
            end
            -- 02/07/2026 optimization: Reuse the MM_TileSizeW/H already computed once for this
            -- whole function call instead of calling GetTileDimensions() 4 times per tile. With
            -- Dx*Dy tiles on the map this was up to 4x that many redundant native API calls on
            -- every invocation - and this loop can run every 40ms while RotateMap is active and
            -- the player is moving or turning.
            tileControl:SetDimensions(MM_TileSizeW, MM_TileSizeH)
            tileControl:SetDrawLayer(0)
            tileControl:ClearAnchors()

            local tilens, tilec, tilewe

            if wheelModeActive then
                tilens = FyrMM.MapTileNSCache[idx]
                if tilens == nil then
                    tilens = GetControl("Fyr_MM_Scroll_WNS_Map_" .. tostring(idx)) -- top & bottom
                    if tilens == nil then
                        tilens = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_WNS_Map_"..tostring(idx), Fyr_MM_Scroll_WheelNS, CT_TEXTURE)
                    end
                    FyrMM.MapTileNSCache[idx] = tilens
                end
                tilec = FyrMM.MapTileCCache[idx]
                if tilec == nil then
                    tilec = GetControl("Fyr_MM_Scroll_CW_Map_"..tostring(idx)) -- corners
                    if tilec == nil then
                        tilec = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_CW_Map_"..tostring(idx), Fyr_MM_Scroll_WheelCenter, CT_TEXTURE)
                    end
                    FyrMM.MapTileCCache[idx] = tilec
                end
                tilewe = FyrMM.MapTileWECache[idx]
                if tilewe == nil then
                    tilewe = GetControl("Fyr_MM_Scroll_WWE_Map_"..tostring(idx)) -- left and right
                    if tilewe == nil then
                        tilewe = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_WWE_Map_"..tostring(idx), Fyr_MM_Scroll_WheelWE, CT_TEXTURE)
                    end
                    FyrMM.MapTileWECache[idx] = tilewe
                end

                tilens:SetHidden(false)
                tilec:SetHidden(false)
                tilewe:SetHidden(false)
                if tilens:GetTextureFileName():lower() ~= CurrentMap.tiles[i]:lower() then
                    tilens:SetTexture(CurrentMap.tiles[i])
                    tilec:SetTexture(CurrentMap.tiles[i])
                    tilewe:SetTexture(CurrentMap.tiles[i])
                end
                tilens:SetDimensions(MM_TileSizeW, MM_TileSizeH)
                tilec:SetDimensions(MM_TileSizeW, MM_TileSizeH)
                tilewe:SetDimensions(MM_TileSizeW, MM_TileSizeH)
                tilens:SetDrawLayer(0)
                tilec:SetDrawLayer(0)
                tilewe:SetDrawLayer(0)
                tilens:ClearAnchors()
                tilec:ClearAnchors()
                tilewe:ClearAnchors()
            else
                -- Wheel map is off: just make sure any tiles left over from a prior WheelMap
                -- session stay hidden. No texture/dimension/anchor work needed since nothing
                -- reads their state while hidden.
                tilens = FyrMM.MapTileNSCache[idx]
                if tilens then tilens:SetHidden(true) end
                tilec = FyrMM.MapTileCCache[idx]
                if tilec then tilec:SetHidden(true) end
                tilewe = FyrMM.MapTileWECache[idx]
                if tilewe then tilewe:SetHidden(true) end
            end

            if FyrMM.SV.RotateMap then
                if CurrentMap.PlayerX == nil or CurrentMap.PlayerY == nil or CurrentMap.Heading == nil then
                    local x, y, pheading = GetMapPlayerPosition("player")
                    CurrentMap.PlayerNX = x
                    CurrentMap.PlayerNY = y
                    CurrentMap.PlayerX, CurrentMap.PlayerY = Fyr_MM_Scroll_Map:GetDimensions()
                    CurrentMap.PlayerX = CurrentMap.PlayerX * x
                    CurrentMap.PlayerY = CurrentMap.PlayerY * y
                    CurrentMap.Heading = smoothHeadingRotation()
                end
                x = ((b - 0.5) * mWidth / CurrentMap.Dx) - CurrentMap.PlayerX
                y = ((a - 0.5) * mHeight / CurrentMap.Dy) - CurrentMap.PlayerY
                tileposX = (zo_cos(-CurrentMap.Heading) * x) - (zo_sin(-CurrentMap.Heading) * y)
                tileposY = (zo_sin(-CurrentMap.Heading) * x) + (zo_cos(-CurrentMap.Heading) * y)
                tileControl:SetTextureRotation(CurrentMap.Heading, 0.5, 0.5)
                local scale = (FyrMM.SV.MapAlpha > 80) and 1.0055 or 1
                tileControl:SetScale(scale)
                tileControl:SetAnchor(CENTER, Fyr_MM_Scroll, CENTER, tileposX, tileposY)
                if wheelModeActive then
                    tilens:SetTextureRotation(CurrentMap.Heading, 0.5, 0.5)
                    tilec:SetTextureRotation(CurrentMap.Heading, 0.5, 0.5)
                    tilewe:SetTextureRotation(CurrentMap.Heading, 0.5, 0.5)
                    tilens:SetScale(scale)
                    tilec:SetScale(scale)
                    tilewe:SetScale(scale)
                    tilens:SetAnchor(CENTER, Fyr_MM_Scroll_WheelNS, CENTER, tileposX, tileposY)
                    tilec:SetAnchor(CENTER, Fyr_MM_Scroll_WheelCenter, CENTER, tileposX, tileposY)
                    tilewe:SetAnchor(CENTER, Fyr_MM_Scroll_WheelWE, CENTER, tileposX, tileposY)
                end
            else
                tileposX = ((b - 0.5) * mWidth / CurrentMap.Dx) - mWidth / 2
                tileposY = ((a - 0.5) * mHeight / CurrentMap.Dy) - mHeight / 2
                tileControl:SetScale(1)
                tileControl:SetTextureRotation(0)
                tileControl:SetAnchor(CENTER, Fyr_MM_Scroll_Map, CENTER, tileposX, tileposY)
                if wheelModeActive then
                    tilens:SetScale(1)
                    tilec:SetScale(1)
                    tilewe:SetScale(1)
                    tilens:SetTextureRotation(0)
                    tilec:SetTextureRotation(0)
                    tilewe:SetTextureRotation(0)
                    tilens:SetAnchor(CENTER, Fyr_MM_Scroll_Map, CENTER, tileposX, tileposY)
                    tilec:SetAnchor(CENTER, Fyr_MM_Scroll_Map, CENTER, tileposX, tileposY)
                    tilewe:SetAnchor(CENTER, Fyr_MM_Scroll_Map, CENTER, tileposX, tileposY)
                end
            end
        end
    end
	
    for j = i, Fyr_MM_Scroll_Map:GetNumChildren() do
        local tileControl = FyrMM.MapTileCache[j]
        if tileControl == nil then
            tileControl = GetControl("Fyr_MM_Scroll_Map_" .. tostring(j))
            if tileControl ~= nil then
                FyrMM.MapTileCache[j] = tileControl
            end
        end
        tilens = FyrMM.MapTileNSCache[j]
        if tilens == nil then
            tilens = GetControl("Fyr_MM_Scroll_WNS_Map_" .. tostring(j))
            if tilens ~= nil then
                FyrMM.MapTileNSCache[j] = tilens
            end
        end
        tilec = FyrMM.MapTileCCache[j]
        if tilec == nil then
            tilec = GetControl("Fyr_MM_Scroll_CW_Map_" .. tostring(j))
            if tilec ~= nil then
                FyrMM.MapTileCCache[j] = tilec
            end
        end
        tilewe = FyrMM.MapTileWECache[j]
        if tilewe == nil then
            tilewe = GetControl("Fyr_MM_Scroll_WWE_Map_" .. tostring(j))
            if tilewe ~= nil then
                FyrMM.MapTileWECache[j] = tilewe
            end
        end
        if (tileControl) then
            tileControl:ClearAnchors()
            tileControl:SetHidden(true)
        end
        if (tilens) then
            tilens:ClearAnchors()
            tilens:SetHidden(true)
        end
        if (tilec) then
            tilec:ClearAnchors()
            tilec:SetHidden(true)
        end
        if (tilewe) then
            tilewe:ClearAnchors()
            tilewe:SetHidden(true)
        end
    end
	
    -- if FyrMM.SV.WheelMap then
        -- CurrentMap.TextureAngle = CurrentMap.Heading
    -- else
        -- CurrentMap.TextureAngle = 0
    -- end
	
    Tiles = false
end

function FyrMM.GetScrollObject(control)
    if not FyrMM.SV.WheelMap then
        return Fyr_MM_Scroll_WheelCenter
    end

    local xl = control:GetLeft()
    local xr = control:GetRight()
    local yt = control:GetTop()
    local yb = control:GetBottom()
    local scrollWheels = {
        Fyr_MM_Scroll_WheelCenter,
        Fyr_MM_Scroll_WheelNS,
        Fyr_MM_Scroll_WheelWE,
    }

    for _, scrollWheel in ipairs(scrollWheels) do
        if (xr >= scrollWheel:GetLeft() + 6 and xl <= scrollWheel:GetRight() - 10 and yb >=
                scrollWheel:GetTop() + 6 and yt <= scrollWheel:GetBottom() - 10) then
            return scrollWheel
        end
    end

    return Fyr_MM_Scroll_Map
end

-----------------------------------------------------------------
-- Map Pins
-----------------------------------------------------------------
local function GetPinTexture(pinType, control)
    if type(ZO_MapPin.PIN_DATA[pinType].texture) == 'string' then
        return ZO_MapPin.PIN_DATA[pinType].texture
    end

    if not type(ZO_MapPin.PIN_DATA[pinType].texture) == 'function' then
        return
    end

    if control.m_PinTag.isBreadcrumb then
        return breadcrumbQuestPinTextures[pinType]
    end

    return questPinTextures[pinType]
end

local function GetCustomPin()
    local p
    if ZO_IsTableEmpty(FreeCustomPinIndex) then
        LastCustomPinIndex = LastCustomPinIndex + 1
        p = GetControl("Fyr_MM_Scroll_Map_Pins_Pin" .. tostring(LastCustomPinIndex))
        if p == nil then
            p = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_Pins_Pin" .. tostring(LastCustomPinIndex), Fyr_MM_Scroll_Map_Pins, CT_TEXTURE)
            p:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
            p:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
        end
        p.Index = LastCustomPinIndex
        return p
    else
        for i, n in pairs(FreeCustomPinIndex) do
            p = GetControl("Fyr_MM_Scroll_Map_Pins_Pin" .. tostring(n))
            if p == nil then
                p = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_Pins_Pin" .. tostring(n), Fyr_MM_Scroll_Map_Pins, CT_TEXTURE)
                p:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
                p:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
            end
            p.Index = n
            FreeCustomPinIndex[i] = nil
            return p
        end
    end
end


function FyrMM.RemoveCustomPinDuplicates(pin)
    if FyrMM.CustomPinList == nil or pin.m_PinType == nil or FyrMM.CustomPinList[pin.m_PinType] == nil then
        return
    end

    for i, v in pairs(FyrMM.CustomPinList[pin.m_PinType]) do
	    if v.pin ~= nil then
			local pinFromList = GetControl(v.pin:GetName())
			

			if v.pin.isSimpleSkyshard then -- fix for simple skyshard addon pins not displaying (will maybe add other addons here in the future)
				if v.pin:GetDrawTier() < 1 then
					v.pin:SetDrawTier(1)
				end
				
				if v.pin:GetDrawLayer() < 1 then
					v.pin:SetDrawLayer(1)
				end
				
				if v.pin:GetDrawLevel() < 1 then
					v.pin:SetDrawLevel(1)
				end
			end
			

			if v.pin.nX == pin.nX and v.pin.nY == pin.nY and v.pin.radius == pin.radius and v.pin.MapId == pin.MapId and v.pin.Index ~= pin.Index and v.pin.created < pin.created then
			  
			  
			   -- local pinTypeName = pin.m_PinType
				-- if PRCustomPins[pin.m_PinType].pinTypeString then
					-- pinTypeName = PRCustomPins[pin.m_PinType].pinTypeString
				-- end
			   -- d("removed a custom pin duplicate "..pinTypeName) 
			   
			  FyrMM.RemoveCustomPin(pinFromList) 
			end
		end
    end
end


function FyrMM.InsertCustomPin(p, key)
    if p == nil or FyrMM.Reloading then
        return
    end
    if p.m_PinType == nil then
        return
    end
    if ZOpinData == nil then
        return
    end
    if ZOpinData[p.m_PinType] == nil then
        return
    end
    local j = 1
    -- local mapId = CurrentMap.MapId
    local pin, texture, pScalePercent
    pScalePercent = FyrMM.pScalePercent
    if pScalePercent == nil then
        pScalePercent = 1
    end
	
	if (PRCustomPins and PRCustomPins[p.m_PinType] and PRCustomPins[p.m_PinType].pinTypeString and 
			    string.find(PRCustomPins[p.m_PinType].pinTypeString, "PreviewForwardCamp")) and FyrMM.ForwardCampPreview then -- avoid drawing multiple forward camp preview pins
	    return			
	end			

    local enabled
    if type(p) == "table" then

        enabled = true
        if PinRef ~= nil then
            if PRCustomPins ~= nil and p.m_PinType >= MAP_PIN_TYPE_INVALID then
                enabled = PRCustomPins[p.m_PinType].enabled
            end
        else
            if p.m_PinType >= MAP_PIN_TYPE_INVALID then
                enabled = ZO_WorldMap_GetPinManager():IsCustomPinEnabled(p.m_PinType) -- checks filter for custom pin
            end
        end

        if CustomPinIndex[p.m_PinType] == nil then
            CustomPinIndex[p.m_PinType] = {}
        end

        if CustomPinKeyIndex[p.m_PinType] == nil then
            CustomPinKeyIndex[p.m_PinType] = {}
        end

        if FyrMM.CustomPinList[p.m_PinType] == nil then
            FyrMM.CustomPinList[p.m_PinType] = {}
        end

        if enabled then
            pin = GetCustomPin()
            if pin.mpin == nil then
                pin.mpin = ZO_MapPin:New(ZO_WorldMapContainer)
            end

            if FyrMM.CustomPinList[p.m_PinType][key] ~= nil then
                FyrMM.CustomPinList[p.m_PinType][key].pin = pin
            end
            j = pin.Index

            if key ~= nil then
                CustomPinKeyIndex[p.m_PinType][key] = j
            end

            FyrMM.CustomPinCount = FyrMM.CustomPinCount + 1
            CustomPinIndex[p.m_PinType][j] = pin
            pin:SetHidden(true) -- updating...
            if pin.BorderPin ~= nil then
                RemoveBorderPin(pin.BorderPin)
            end
            texture = ""
            pin.m_PinType = p.m_PinType
            pin.m_PinTag = p.m_PinTag
            pin.mpin.m_PinType = p.m_PinType
            pin.mpin.m_PinTag = p.m_PinTag
            pin.mpin.normalizedX = p.normalizedX
            pin.mpin.normalizedY = p.normalizedY
            pin.nX = p.normalizedX
            pin.nY = p.normalizedY
            pin.radius = p.radius
            pin.MapId = CurrentMap.MapId
            pin.Index = j
            pin.Key = key 
            pin.tint = p.tint
            CustomPinCrossReference[pin.mpin] = pin
			pin.created = GetFrameTimeMilliseconds()
            -- pin.GetPinTypeAndTag = function(self) return self.m_PinType, self.m_PinTag end

            if FyrMM.SV.autoResizePin and CurrentMap.MapId ~= 16 and CurrentMap.MapId ~= 660 and CurrentMap.MapContentType ~= MAP_CONTENT_BATTLEGROUND then
                -- zoom: 1 to 50 default: 10
                FyrMM.pinZoomScale = (CurrentMap.ZoomLevel) / 10
            else
                FyrMM.pinZoomScale = 1
            end

            if not ZO_MapPin.FAST_TRAVEL_WAYSHRINE_PIN_TYPES[pin.m_PinType] == nil and
                not ZO_MapPin.POI_PIN_TYPES[pin.m_PinType] and not pin.m_PinType == MAP_PIN_TYPE_LOCATION then
                pin.noZoomResize = true
            end

            if ZOpinData[p.m_PinType].size ~= nil then
                FyrMM.SetPinSize(pin, ZOpinData[p.m_PinType].size * pScalePercent * FyrMM.pinZoomScale)
            end

            if type(ZOpinData[p.m_PinType].texture) == 'string' then
                texture = ZOpinData[p.m_PinType].texture
            elseif type(ZOpinData[p.m_PinType].texture) == 'function' then
                texture = ZOpinData[p.m_PinType].texture(pin.mpin)
            end

            if p.m_PinType == MAP_PIN_TYPE_PLAYER_WAYPOINT then
                texture = "EsoUI/Art/MapPins/UI_Worldmap_pin_customDestination.dds"
                FyrMM.IsWaypoint = true
                FyrMM.SetPinSize(pin, ZOpinData[p.m_PinType].minSize * pScalePercent)
                if FyrMM.Waypoint ~= nil then
                    if FyrMM.Waypoint.BorderPin ~= nil then
                        RemoveBorderPin(FyrMM.Waypoint.BorderPin)
                    end
                end
                FyrMM.Waypoint = pin
            end

            if p.m_PinType == MAP_PIN_TYPE_RALLY_POINT then 
                texture = ZOpinData[MAP_PIN_TYPE_RALLY_POINT].texture --"MiniMap/Textures/rally.dds"
				pin:SetDimensions(ZOpinData[MAP_PIN_TYPE_RALLY_POINT].minSize, ZOpinData[MAP_PIN_TYPE_RALLY_POINT].minSize)
                FyrMM.IsRally = true
                if FyrMM.Rally ~= nil then
                    if FyrMM.Rally.BorderPin ~= nil then
                        RemoveBorderPin(FyrMM.Rally.BorderPin)
                    end
                end
                FyrMM.Rally = pin
            end

            if p.m_PinType == MAP_PIN_TYPE_PING then
                texture = "MiniMap/Textures/ping.dds"
                FyrMM.SetPinSize(pin, ZOpinData[p.m_PinType].minSize * pScalePercent)
                FyrMM.IsPing = true
                if FyrMM.Ping ~= nil then
                    if FyrMM.Ping.BorderPin ~= nil then
                        RemoveBorderPin(FyrMM.Ping.BorderPin)
                    end
                end
                FyrMM.Ping = pin
            end
			
			if (PRCustomPins and PRCustomPins[p.m_PinType] and PRCustomPins[p.m_PinType].pinTypeString and 
			    string.find(PRCustomPins[p.m_PinType].pinTypeString, "PreviewForwardCamp")) then -- Forward Camp Preview
				if not FyrMM.ForwardCampPreview then
				    texture = "EsoUI/Art/MapPins/map_areaPin.dds"
				    pin.isForwardCampPreview = true
				end
			end
			
			if (PRCustomPins and PRCustomPins[p.m_PinType] and PRCustomPins[p.m_PinType].pinTypeString and 
			    string.find(PRCustomPins[p.m_PinType].pinTypeString, "SIMPLE_SKYSHARDS")) then -- Simple Skyshards addon
				pin.isSimpleSkyshard = true
			end	

            pin.pinTexture = texture
            pin:SetTexture(texture)

            if (PRCustomPins and PRCustomPins[p.m_PinType] and PRCustomPins[p.m_PinType].pinTypeString and -- treasures and surveys
                string.find(PRCustomPins[p.m_PinType].pinTypeString, "LostTreasure")) or string.find(texture, "MapPins/Treasure_") then
                pin.IsTreasure = true
                pin.noZoomResize = true
                table.insert(Treasures, pin)
            end


            if string.find(texture, "dragonNextLocation") then
                pin.IsDragonNextLocation = true
                table.insert(DragonNextLocation, pin)
            end

            pin:SetColor(1, 1, 1, 1)

            if ZOpinData[p.m_PinType].tint ~= nil then -- compatibility with addons which modify pin colors by type
                if type(ZOpinData[p.m_PinType].tint) ~= "function" then
                    pin:SetColor(ZOpinData[p.m_PinType].tint:UnpackRGBA())
                else
                    local c = ZOpinData[p.m_PinType].tint(pin.mpin)
                    if type(c) == "table" then
                        pin:SetColor(c.r, c.g, c.b, c.a)
                    end
                end
            end

            if p.tint then -- compatibility with addons which modify pin colors by pin
                if type(p.tint) ~= "function" then
                    pin:SetColor(p.tint:UnpackRGBA())
                else
                    if type(p.tint) == "table" then
                        pin:SetColor(p.tint.r, p.tint.g, p.tint.b, p.tint.a)
                    end
                end
            end

            if type(p.m_PinTag) == "table" then -- suggested
                if p.m_PinTag.IsAvailableQuest or p.m_PinTag.isZoneStory or ZO_MapPin.SUGGESTION_PIN_TYPES[p.m_PinType] then
                    pin.m_PinTag.IsAvailableQuest = true
                    pin.IsAvailableQuest = true
                    if ZO_MapPin.SUGGESTION_PIN_TYPES[p.m_PinType] and IsZoneStoryComplete(ZO_ExplorationUtils_GetZoneStoryZoneIdForCurrentMap()) == false then
                        pin.m_PinTag.isZoneStory = true
                        local _, _, activityId = GetTrackedZoneStoryActivityInfo()
                        pin.m_PinTag.activityId = activityId
                        FyrMM.ZoneStoryPin = pin
                    end
                    table.insert(FyrMM.AvailableQuestGivers, pin)

                    if p.radius and p.radius > 0 and p.m_PinType then
                        local properType, pinTexture, size = FyrMM.GetQuestPinInfo(p.m_PinType, false, false, p.radius)
                        local areaPin = pin
                        areaPin:SetTexture(pinTexture)
						local mWidth, mHeight = Fyr_MM_Scroll_Map:GetDimensions()
						size = mHeight * p.radius * 2
                        areaPin:SetDimensions(size, size)
                        local color = ZO_MAP_PIN_NORMAL_COLOR
                        areaPin:SetColor(color:UnpackRGBA())
                        if FyrMM.SV.WheelMap then
                            areaPin:SetParent(Fyr_MM_Scroll_CW_Map_Pins)
                            FyrMM.CreateSuggestedAreaSidePins(areaPin, p.radius)
                        end
                        table.insert(FyrMM.AvailableQuestGivers, areaPin)
                    end
                end
            end

            FyrMM.SetPinAnchor(pin, pin.nX, pin.nY, Fyr_MM_Scroll_Map_Pins)
			
            local pinHidden = true
            if FyrMM.SV.WheelMap then
                pin:SetHidden(not FyrMM.Is_PinInsideWheel(pin) and pinHidden)
            else
                pin:SetHidden(not pinHidden)
            end
            pin:SetMouseEnabled(true)
            if (FyrMM.IsWaypoint or FyrMM.IsRally or FyrMM.IsPing) and FyrMM.SV.BorderPinsWaypoint then
                FyrMM.PlaceWaypointBorderPins()
            end
			
			if pin.isForwardCampPreview and not FyrMM.ForwardCampPreview then -- forward camp preview
				local color = ZO_MAP_PIN_NORMAL_COLOR
				pin:SetColor(color:UnpackRGBA())
				if FyrMM.SV.WheelMap then
					pin:SetParent(Fyr_MM_Scroll_CW_Map_Pins)
					FyrMM.CreateSuggestedAreaSidePins(pin, p.radius) 
				end
				FyrMM.ForwardCampPreview = true
			else
			    FyrMM.RemoveCustomPinDuplicates(pin)
			end
			
        end
    end
end

function FyrMM.CustomPins()
    if FyrMM.Halted or not FyrMM.Visible or Fyr_MM:IsHidden() or FyrMM.worldMapShowing then
        return
    end

    local function DebugMessage()
	    local gameTime = GetGameTimeMilliseconds()
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "FyrMM.CustomPins " .. tostring(GetGameTimeMilliseconds() - gameTime))
    end

    if ZO_IsTableEmpty(FyrMM.CustomPinList) or IsCustomPinsLoading() then
        if FyrMM.DebugMode then
            DebugMessage()
        end
        return
    end

    FyrMM.CustomPinCount = 0 -- mandatory
	LastCustomPinIndex = 0 -- mandatory

	
    local function ProcessPin(t, n, i, v)
        if v.pin == nil then
            FyrMM.InsertCustomPin(v, i)
            return
        end

        local pin = v.pin
		
		if pin.m_PinType == nil then
            return
        end
        local pinType = pin.m_PinType
		
        if FyrMM.UpdatingCustomPins[pinType] then
            return
        end

		if pin.Index == nil then
            return
        end
        local Index = pin.Index
		
		
        if pin.Key == nil then
            return
        end
		local Key = pin.Key

		
        pin.Key = Key
        pin.Index = Index

        CustomPinIndex = CustomPinIndex or {}

        if CustomPinIndex[pinType] == nil then 
            CustomPinIndex[pinType] = {}
        end

        CustomPinIndex[pinType][Index] = pin
        CustomPinKeyIndex[pinType][Key] = Index
        FyrMM.CustomPinCount = FyrMM.CustomPinCount + 1

        if type(pin.m_PinTag) == "table" and
            (pin.m_PinTag.IsAvailableQuest or pin.m_PinTag.isZoneStory or ZO_MapPin.SUGGESTION_PIN_TYPES[pin.m_PinType]) then
            pin.m_PinTag.IsAvailableQuest = true
            pin.IsAvailableQuest = true
            if pin.m_PinTag.isZoneStory and CanZoneStoryContinueTrackingActivities(ZO_ExplorationUtils_GetZoneStoryZoneIdForCurrentMap()) then
                local _, _, activityId = GetTrackedZoneStoryActivityInfo()
                if pin.m_PinTag.activityId == activityId or pin.m_PinTag[3] == activityId then 
                    FyrMM.ZoneStoryPin = pin
                else
                    if pin == FyrMM.ZoneStoryPin then
                        FyrMM.RemoveCustomPin(pin)
                        FyrMM.ZoneStoryPin = nil
                    end
                end
            else
                if pin == FyrMM.ZoneStoryPin then
                    FyrMM.RemoveCustomPin(pin)
                    FyrMM.ZoneStoryPin = nil
                end
            end
			FyrMM.AvailableQuestGivers = FyrMM.AvailableQuestGivers or {}
            table.insert(FyrMM.AvailableQuestGivers, pin)
        end

        if (pin.pinTexture and string.find(pin.pinTexture, "MapPins/Treasure_")) or
           (PRCustomPins and PRCustomPins[pin.m_PinType] and PRCustomPins[pin.m_PinType].pinTypeString and
           string.find(PRCustomPins[pin.m_PinType].pinTypeString, "LostTreasure")) then
		    Treasures = Treasures or {}
            table.insert(Treasures, pin)
        end
        if pin.pinTexture and string.find(pin.pinTexture, "dragonNextLocation") then
            DragonNextLocation = DragonNextLocation or {}
			table.insert(DragonNextLocation, pin)
        end
		
    end

    for t, n in pairs(FyrMM.CustomPinList) do
        if FyrMM.UpdatingCustomPins[t] == nil then
            for i, v in pairs(n) do
                ProcessPin(t, n, i, v)
            end
        end
    end

    if FyrMM.DebugMode then
        DebugMessage()
    end

end

------------------------------------------------------------
-- Waypoint/Rally Pins
-----------------------------------------------------------

local waypoints = {
    Player = {
        Control = "Fyr_MM_Scroll_Map_Pins_PlayerWaypoint",
        PinType = MAP_PIN_TYPE_PLAYER_WAYPOINT,
        PinTag = "waypoint",
        Texture = "EsoUI/Art/MapPins/UI_WorldMap_pin_customDestination.dds",
    },

    Rally = {
        Control = "Fyr_MM_Scroll_Map_Pins_RallyPoint",
        PinType = MAP_PIN_TYPE_RALLY_POINT,
        PinTag = "rally",
        Texture = "MiniMap/Textures/rally.dds",
        IsRally = true,
    },

    Ping = {
        Control = "Fyr_MM_Scroll_Map_Pins_Ping",
        PinType = MAP_PIN_TYPE_PING,
        PinTag = "ping",
        Texture = "MiniMap/Textures/ping.dds",
    }
}

function FyrMM.ProcessWaypointPin(waypointData, pingEventType, wpx, wpy)
    local waypointPin

    if pingEventType ~= PING_EVENT_ADDED or (wpx == 0 and wpy == 0) then
        waypointPin = GetControl(waypointData.Control)
        if waypointPin then
            waypointPin.m_Pin = nil
            waypointPin.MapId = 0
            waypointPin.nX = 0
            waypointPin.nY = 0
            waypointPin.m_PinType = 0
            waypointPin:SetTexture("")
            waypointPin:SetHidden(true)
        end
        return nil
    end


    waypointPin = GetControl(waypointData.Control)
    if waypointPin == nil then
        waypointPin = WINDOW_MANAGER:CreateControl(waypointData.Control, Fyr_MM_Scroll_Map_Pins, CT_TEXTURE)
        waypointPin.nDistance = function(self)
            if self.nX == nil then
                return 1
            end
            return zo_sqrt((zo_round(CurrentMap.PlayerNX * 10000) - zo_round(self.nX * 10000)) ^ 2 + (zo_round(CurrentMap.PlayerNY * 10000) - zo_round(self.nY * 10000)) ^ 2) / 10000
        end
        waypointPin:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
        waypointPin:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
        waypointPin:SetHandler("OnMouseUp", PinOnMouseUp)
    end
    
    local pin = waypointPin.m_Pin or ZO_Object.New(ZO_MapPin)
	local pdata = ZOpinData[waypointData.PinType]
    local pinSize =  pdata.minSize -- waypointData.IsRally and (pdata.minSize / 3) * FyrMM.pScalePercent or pdata.minSize * FyrMM.pScalePercent
    pin.m_PinType = waypointData.PinType
    pin.m_PinTag = waypointData.PinTag
    pin.nX = wpx
    pin.nY = wpy
    waypointPin.m_Pin = pin
    waypointPin.MapId = CurrentMap.MapId
    waypointPin.nX = wpx
    waypointPin.nY = wpy
    waypointPin.m_PinType = waypointData.PinType
	waypointPin:SetDrawTier(1)
    waypointPin:SetDrawLayer(1)
	waypointPin:SetDrawLevel(pdata.level)
    --FyrMM.SetPinSize(waypointPin, pinSize, 0)
	waypointPin:SetDimensions(pinSize, pinSize)
    waypointPin:SetTexture(ZOpinData[waypointData.PinType].texture) -- waypointData.Texture
    waypointPin:SetHidden(false)
    FyrMM.SetPinAnchor(waypointPin, wpx, wpy, Fyr_MM_Scroll_Map_Pins)
    waypointPin:SetMouseEnabled(true)
	
	if ZOpinData[waypointData.PinType].tint ~= nil then -- compatibility with addons which modify pin colors by type
		if type(ZOpinData[waypointData.PinType].tint) ~= "function" then
			waypointPin:SetColor(ZOpinData[waypointData.PinType].tint:UnpackRGBA())
		else
			local c = ZOpinData[waypointData.PinType].tint(waypointPin.m_Pin) 
			if type(c) == "table" then
				waypointPin:SetColor(c.r, c.g, c.b, c.a)
			end
		end
	end
	
    if pdata.isAnimated and waypointPin.m_textureAnimTimeline == nil then 
	   waypointPin.m_textureAnimTimeline = "yes"
	   FyrMM.PlayTextureAnimation(waypointPin, pdata.framesWide, pdata.framesHigh, pdata.framesPerSecond, LOOP_INDEFINITELY, ANIMATION_PLAYBACK_LOOP)
    end
	
    return waypointPin
end

function FyrMM.WaypointPins(pingEventType, pinType, wpx, wpy)
    local waypointPin
    if pinType == MAP_PIN_TYPE_PLAYER_WAYPOINT then
        waypointPin = FyrMM.ProcessWaypointPin(waypoints.Player, pingEventType, wpx, wpy)
        if waypointPin then
            FyrMM.Waypoint = waypointPin
             FyrMM.IsWaypoint = true
        else
            FyrMM.Waypoint = nil
            FyrMM.IsWaypoint = false
        end
    elseif pinType == MAP_PIN_TYPE_RALLY_POINT then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "is rally point ")
        waypointPin = FyrMM.ProcessWaypointPin(waypoints.Rally, pingEventType, wpx, wpy)
        if waypointPin then
            FyrMM.Rally = waypointPin
            FyrMM.IsRally = true
        else
            FyrMM.Rally = nil
            FyrMM.IsRally = false
        end
    elseif pinType == MAP_PIN_TYPE_PING then
        waypointPin = FyrMM.ProcessWaypointPin(waypoints.Ping, pingEventType, wpx, wpy)
        if waypointPin then
            FyrMM.Ping = waypointPin
            FyrMM.IsPing = true
        else
            FyrMM.Ping = nil
            FyrMM.IsPing = false
        end
    end
end

function FyrMM.checkWaypoints()
		local waypointX, waypointY = GetMapPlayerWaypoint() 
		if not (waypointX == 0 and waypointY == 0) then FyrMM.WaypointPins(PING_EVENT_ADDED, MAP_PIN_TYPE_PLAYER_WAYPOINT, waypointX, waypointY) end
		
		local rallypointX, rallypointY = GetMapRallyPoint() 
		if not (rallypointX == 0 and rallypointY == 0) then FyrMM.WaypointPins(PING_EVENT_ADDED, MAP_PIN_TYPE_RALLY_POINT, rallypointX, rallypointY) end		
end

------------------------------------------------------------
-- Wayshrine Pins
-----------------------------------------------------------

local function CreateWayshrinePin(pinType, tag, nX, nY, isRealWayshrine)

    FyrMM.WayshrinePinControlCache = FyrMM.WayshrinePinControlCache or {}
    -- 03/07/2026 optimization: Cache wayshrine control on creation
    local wayshrinePin = FyrMM.WayshrinePinControlCache[FyrMM.currentWayshrineCount]
    if wayshrinePin == nil then
        wayshrinePin = GetControl("Fyr_MM_Scroll_Map_WayshrinePins_Pin" .. tostring(FyrMM.currentWayshrineCount))
        if wayshrinePin == nil then
            wayshrinePin = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_WayshrinePins_Pin" ..tostring(FyrMM.currentWayshrineCount), Fyr_MM_Scroll_Map_WayshrinePins, CT_TEXTURE)

            wayshrinePin.nDistance = function(self)
                if self.nX == nil then
                    return 1
                end
                return zo_sqrt((zo_round(CurrentMap.PlayerNX * 10000) - zo_round(self.nX * 10000)) *
                    (zo_round(CurrentMap.PlayerNX * 10000) - zo_round(self.nX * 10000)) +
                    (zo_round(CurrentMap.PlayerNY * 10000) - zo_round(self.nY * 10000)) *
                    (zo_round(CurrentMap.PlayerNX * 10000) - zo_round(self.nY * 10000))) / 10000
            end
            wayshrinePin:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
            wayshrinePin:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
            wayshrinePin:SetHandler("OnMouseUp", PinOnMouseUp)
        end
        FyrMM.WayshrinePinControlCache[FyrMM.currentWayshrineCount] = wayshrinePin
    end
    local pin = ZO_Object.New(ZO_MapPin)
    local pinSize = 40 * FyrMM.pScalePercent * FyrMM.pinZoomScale
    pin.m_PinType = pinType
    pin.m_PinTag = tag
    pin.nX = nX
    pin.nY = nY
    wayshrinePin.m_Pin = pin
    wayshrinePin.MapId = CurrentMap.MapId
    wayshrinePin.nX = nX
    wayshrinePin.nY = nY
    wayshrinePin.m_PinType = pinType
    wayshrinePin:SetDrawLayer(1)
    FyrMM.SetPinSize(wayshrinePin, pinSize, 0)
    wayshrinePin:SetTexture(tag[2])
    wayshrinePin.isRealWayshrine = isRealWayshrine

    local wayshrinePinData = ZOpinData[pinType]
    if wayshrinePinData.tint then -- compatibility with addons which modify wayshrines colors
        if type(wayshrinePinData.tint) ~= "function" then
            wayshrinePin:SetColor(wayshrinePinData.tint:UnpackRGBA())
        else
            if wayshrinePin.m_Pin ~= nil then
                wayshrinePin:SetColor(wayshrinePinData.tint(wayshrinePin.m_Pin):UnpackRGBA())
            else
                wayshrinePin:SetColor(wayshrinePinData.tint(wayshrinePin):UnpackRGBA())
            end
        end
    else
        wayshrinePin:SetColor(1, 1, 1, 1)
    end

    wayshrinePin:SetHidden(not ZO_WorldMap_IsPinGroupShown(MAP_FILTER_WAYSHRINES))
    FyrMM.SetPinAnchor(wayshrinePin, nX, nY, Fyr_MM_Scroll_Map_WayshrinePins)
    wayshrinePin:SetMouseEnabled(true)
    Wayshrines[FyrMM.currentWayshrineCount] = {
        Closest = false,
        nDistance = 1,
        tag = tag,
        nX = nX,
        nY = nY,
        MapId = CurrentMap.MapId,
        pin = wayshrinePin,
        isRealWayshrine = isRealWayshrine
    }
end

function FyrMM.Wayshrines() -- that one seems to trigger only once when zoning, no need to filter
	  if FyrMM.Reloading then
		   return
	  end
	  if FyrMM.Halted or GetNumFastTravelNodes() == 0 then
        return
    end
    if not FyrMM.Visible or Fyr_MM:IsHidden() or FyrMM.worldMapShowing then
        return
    end

    local t = GetGameTimeMilliseconds()
    FyrMM.SetMapToPlayerLocation()
    FyrMM.currentWayshrineCount = 0
    Wayshrines = {}
    if string.lower(CurrentMap.filename) ~= "giantsrun_base_0" then
	    
        for nodeIndex = 1, GetNumFastTravelNodes() do
            local known, name, nX, nY, icon, glowIcon, poiType, isShownInCurrentMap = GetFastTravelNodeInfo(nodeIndex)
            if known or FyrMM.SV.ShowUnexploredPins then
                local isRealWayshrine = false
				        local pinType = MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE
                if poiType == POI_TYPE_WAYSHRINE and isShownInCurrentMap and name and string.find(string.lower(name), string.lower(GetString(SI_DEATH_PROMPT_WAYSHRINE))) then
					         isRealWayshrine = true
                end  
                if not known and isRealWayshrine then 
                    icon = "/esoui/art/icons/poi/poi_wayshrine_incomplete.dds"
                    glowIcon = "/esoui/art/icons/poi/poi_wayshrine_glow.dds"
                elseif not known and poiType == POI_TYPE_HOUSE then
                    icon = "/esoui/art/icons/poi/poi_group_house_unowned.dds"
                    glowIcon = "/esoui/art/icons/poi/poi_group_house_unowned_glow.dds"
                elseif not known and poiType == POI_TYPE_GROUP_DUNGEON then
                    icon = "/esoui/art/icons/poi/poi_groupinstance_incomplete.dds"
                    glowIcon = "/esoui/art/icons/poi/poi_groupinstance_incomplete_glow.dds"
                end
                local tag = ZO_MapPin.CreateTravelNetworkPinTag(nodeIndex, icon, glowIcon)
                
                if nX > 0 and nX < 1.0001 and nY > 0 and nY < 1.0001 and isShownInCurrentMap and icon ~= "/esoui/art/icons/icon_missing.dds" then
                    FyrMM.currentWayshrineCount = FyrMM.currentWayshrineCount + 1
                    CreateWayshrinePin(pinType, tag, nX, nY, isRealWayshrine)
                end
            end
        end
    end
	
	FyrMM.wayshrineCheckMapId = CurrentMap.MapId
    -- One-time delayed re-check: known/discovered status can be momentarily stale right after
    -- zoning in, before the game finishes syncing discovery data. Re-run once, 2s later, to
    -- catch and correct any wayshrines that were still reporting as undiscovered at build time.
    zo_callLater(function() -- zo_callLater ok
        if CurrentMap.MapId == FyrMM.wayshrineCheckMapId then
            FyrMM.wayshrineCheckMapId = nil
            FyrMM.Wayshrines()
        end
    end, 2000)
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "FyrMM.Wayshrines ("..tostring(GetNumFastTravelNodes())..")"..tostring(GetGameTimeMilliseconds() - t))
    end
    CleanupWayshrines()
end

------------------------------------------------------------
-- Skyshard Pins
------------------------------------------------------------

local function SkyshardAddonRunning()
   if SkyShards or SimpleSkyshards then 
      return true
   end
   
   return false   
end


local function CreateSkyshardPin(skyshardId)
        if SkyshardAddonRunning() then
		   return 
		end
		
        local discoveryStatus = GetSkyshardDiscoveryStatus(skyshardId)
		local nX, nY, isInCurrentMap = GetNormalizedPositionForSkyshardId(skyshardId)
		
		local display 
        local pintype
        local icon
        local status 		
		
		if discoveryStatus == SKYSHARD_DISCOVERY_STATUS_ACQUIRED then
		     --d("we have an aquired skyshard "..skyshardId.." at "..nX.." "..nY)
			 pintype = MAP_PIN_TYPE_SKYSHARD_COMPLETE
			 display = ZO_WorldMap_IsPinGroupShown(MAP_FILTER_ACQUIRED_SKYSHARDS)
			 icon = "/esoui/art/icons/mapkey/mapkey_skyshard_complete.dds"
			 status = GetString(SI_SKYSHARDDISCOVERYSTATUS2) 
		elseif discoveryStatus == SKYSHARD_DISCOVERY_STATUS_DISCOVERED then
		     --d("we have a discovered skyshard "..skyshardId.." at "..nX.." "..nY)
			 pintype = MAP_PIN_TYPE_SKYSHARD_SEEN
			 display = ZO_WorldMap_IsPinGroupShown(MAP_FILTER_OBJECTIVES)
			 icon = "/esoui/art/icons/mapkey/mapkey_skyshard_seen.dds"
			 status = GetString(SI_SKYSHARDDISCOVERYSTATUS1)
		elseif discoveryStatus == SKYSHARD_DISCOVERY_STATUS_UNDISCOVERED then
		    -- d("we have an undiscovered skyshard "..skyshardId.." at "..nX.." "..nY)
			 display = ZO_WorldMap_IsPinGroupShown(MAP_FILTER_OBJECTIVES) and FyrMM.SV.ShowUndiscoveredSkyshards
			 pintype = MAP_PIN_TYPE_SKYSHARD_SUGGESTED
			 icon = "/esoui/art/icons/mapkey/mapkey_skyshard_seen.dds"
			 status = GetString(SI_SKYSHARDDISCOVERYSTATUS0)
		end
		
		if not isInCurrentMap then
		    -- icon = "MiniMap/Textures/skyshard_icon_door.dds"
		    status = zo_strformat(GetString(SI_GAMEPAD_WORLD_MAP_TRAVEL_TO_HOUSE_INSIDE),status)
		end
		
		if not display then
		   return
		end

    local skyshardPin
    if nX > 0 and nX < 1.0001 and nY > 0 and nY < 1.0001 then
        
            FyrMM.currentSkyshardCount = FyrMM.currentSkyshardCount + 1
            local tag = ZO_MapPin.CreateSkyshardPinTag(skyshardId)
            FyrMM.SkyshardPinControlCache = FyrMM.SkyshardPinControlCache or {}
            -- 03/07/2026 optimization: Cache skyshard control on creation
            skyshardPin = FyrMM.SkyshardPinControlCache[FyrMM.currentSkyshardCount]
            if skyshardPin == nil then
                skyshardPin = GetControl("Fyr_MM_Scroll_Map_SkyshardPins_Pin"..tostring(FyrMM.currentSkyshardCount))
                if skyshardPin == nil then
                    skyshardPin = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_SkyshardPins_Pin"..tostring(FyrMM.currentSkyshardCount), Fyr_MM_Scroll_Map_SkyshardPins, CT_TEXTURE)
                    skyshardPin:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
                    skyshardPin:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
                end
                FyrMM.SkyshardPinControlCache[FyrMM.currentSkyshardCount] = skyshardPin
            end
            local pin = ZO_Object.New(ZO_MapPin)
            local pinSize = 40 * FyrMM.pScalePercent * FyrMM.pinZoomScale
			
			if pintype == MAP_PIN_TYPE_SKYSHARD_COMPLETE then
			    skyshardPin:SetColor(1, 1, 1, 1)
				skyshardPin.color = {1, 1, 1, 1}
            elseif not isInCurrentMap then -- pin is through a door 
                skyshardPin:SetColor(1, 1, 1, 1)
				skyshardPin.color = {1, 1, 1, 1}
			else 
                skyshardPin:SetColor(0, 255, 255, 1)
                skyshardPin.color = {0, 255, 255, 1}				
            end
			
			if pintype == MAP_PIN_TYPE_SKYSHARD_SUGGESTED then -- undiscoverd have a smaller size
			   pinSize = 30 * FyrMM.pScalePercent * FyrMM.pinZoomScale
			end
			
			skyshardPin.Closest = false
            skyshardPin.skyshardId = skyshardId 
			skyshardPin.status = status
            pin.m_PinType = pintype
            pin.m_PinTag = tag
            skyshardPin.m_Pin = pin
            skyshardPin.MapId = CurrentMap.MapId
            skyshardPin.nX = nX
            skyshardPin.nY = nY
            skyshardPin.m_PinType = pintype
            skyshardPin:SetDrawLayer(2)
            FyrMM.SetPinSize(skyshardPin, pinSize, 0)
            skyshardPin:SetTexture(icon)
			skyshardPin.pinTexture = icon

            local skyshardPinData = ZOpinData[pintype]
            if skyshardPinData.tint then -- compatibility with addons which modifies skyshard colors
                if type(skyshardPinData.tint) ~= "function" then
                    skyshardPin:SetColor(skyshardPinData.tint:UnpackRGBA())
                else
                    if skyshardPin.m_Pin ~= nil then
                        skyshardPin:SetColor(skyshardPinData.tint(skyshardPin.m_Pin):UnpackRGBA())
                    else
                        skyshardPin:SetColor(POIPinData.tint(skyshardPin):UnpackRGBA())
                    end
                end
            else
                --skyshardPin:SetColor(1, 1, 1, 1)
            end

            FyrMM.SetPinAnchor(skyshardPin, nX, nY, Fyr_MM_Scroll_Map_SkyshardPins)
            skyshardPin:SetMouseEnabled(true)
            skyshardPin:SetHidden(not display)
    end

end


function FyrMM.skyshardPins()
	if SkyshardAddonRunning() then
	   return 
	end
	
    RemoveSkyshards()	
	
	local zoneId = ZO_ExplorationUtils_GetZoneStoryZoneIdForCurrentMap()


	FyrMM.skyshardPinsMap = CurrentMap.MapId 
	
	local numSkyshardsInZone = GetNumSkyshardsInZone(zoneId)
    if numSkyshardsInZone == 0 then 
        return
    end
	
    local t = GetGameTimeMilliseconds()
	FyrMM.currentSkyshardCount = 0
	
    if string.lower(CurrentMap.filename) ~= "giantsrun_base_0" then
        for i = 1, numSkyshardsInZone do
			local id = GetZoneSkyshardId(zoneId, i)
            CreateSkyshardPin(id)
        end
    end
	
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug","FyrMM.skyshardPins("..tostring(numSkyshardsInZone)..")"..tostring(GetGameTimeMilliseconds() - t))
    end
end


function FyrMM.skyshardPinsZoneCheck()
	if SkyshardAddonRunning() then
	   return 
	end
	if FyrMM.skyshardPinsMap ~= CurrentMap.MapId then -- map has changed
	   zo_callLater(FyrMM.skyshardPins, 5)
    end    
end



------------------------------------------------------------
-- POI Pins
------------------------------------------------------------

local function CreatePOIPin(poiIndex)
    local POIPin
	local POIPinWall
	local POIPinCaustics
    local nX, nY, iconType, icon = MM_GetPOIMapInfo(CurrentMap.ZoneIndex, poiIndex)

    if CraftingStations ~= nil and icon and zo_strfind(icon, "icons/poi/poi_crafting_") then -- Crafting stations mix-up fix by Garkin
        return
    end 
    
	
	local isPOI = ZO_MapPin.POI_PIN_TYPES[iconType] 
	
    if not (isPOI) and FyrMM.SV.ShowUnexploredPins then
        icon = "/esoui/art/inventory/newitem_icon.dds"
        iconType = MAP_PIN_TYPE_POI_SEEN
    end
	
	
    if nX > 0 and nX < 1.0001 and nY > 0 and nY < 1.0001 and (isPOI) then
        if (not( GetPOIType(CurrentMap.ZoneIndex, poiIndex) == POI_TYPE_WAYSHRINE) or iconType == MAP_PIN_TYPE_POI_SEEN) then
            FyrMM.currentPOICount = FyrMM.currentPOICount + 1
            local tag = ZO_MapPin.CreatePOIPinTag(CurrentMap.ZoneIndex, poiIndex, icon)
            POIPin = GetControl("Fyr_MM_Scroll_Map_POIPins_Pin"..tostring(FyrMM.currentPOICount))
            if POIPin == nil then
                POIPin = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_POIPins_Pin"..tostring(FyrMM.currentPOICount), Fyr_MM_Scroll_Map_POIPins, CT_TEXTURE)
                POIPin:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
                POIPin:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
            end
            local pin = ZO_Object.New(ZO_MapPin)
            local pinSize = 40 * FyrMM.pScalePercent * FyrMM.pinZoomScale
            if icon == "/esoui/art/inventory/newitem_icon.dds" then
                pinSize = 32 * FyrMM.pScalePercent * FyrMM.pinZoomScale
                POIPin:SetColor(FyrMM.SV.UndiscoveredPOIPinColor.r, FyrMM.SV.UndiscoveredPOIPinColor.g,FyrMM.SV.UndiscoveredPOIPinColor.b, FyrMM.SV.UndiscoveredPOIPinColor.a)
            else
                POIPin:SetColor(1, 1, 1, 1)
            end
			
			
            POIPin.poiIndex = poiIndex
            pin.m_PinType = iconType
            pin.m_PinTag = tag
            POIPin.m_Pin = pin
            POIPin.MapId = CurrentMap.MapId
            POIPin.nX = nX
            POIPin.nY = nY
            POIPin.m_PinType = iconType
            POIPin:SetDrawLayer(1)
            FyrMM.SetPinSize(POIPin, pinSize, 0)
            POIPin:SetTexture(icon)
			
			if GetActiveSpectacleEventIdsForPOI(CurrentMap.ZoneIndex, poiIndex) then -- Spectacle event pin aura
			    local auraSize = 48 * FyrMM.pScalePercent * FyrMM.pinZoomScale
			    POIPin.spectacleEventPin = true
				POIPinWall = GetControl("Fyr_MM_Scroll_Map_POIPins_Pin"..tostring(FyrMM.currentPOICount).."_Wall")
				if POIPinWall == nil then
				    POIPinWall = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_POIPins_Pin"..tostring(FyrMM.currentPOICount).."_Wall", Fyr_MM_Scroll_Map_POIPins, CT_TEXTURE)
				end	
				POIPinWall.poiIndex = poiIndex
				POIPinWall.m_PinType = 9997
				POIPinWall.m_PinTag = tag
				POIPinWall.m_Pin = pin
				POIPinWall.MapId = CurrentMap.MapId
				POIPinWall.nX = nX
				POIPinWall.nY = nY
				POIPinWall:SetDrawLayer(1)
				POIPinWall:SetDrawLayer(ZO_MapPin.PIN_DATA[iconType].level - 1)
				FyrMM.SetPinSize(POIPinWall, auraSize, 0)
				POIPinWall:SetTexture("/esoui/art/mappins/writhing_wall.dds")
				FyrMM.SetPinAnchor(POIPinWall, nX, nY, Fyr_MM_Scroll_Map_POIPins)
				POIPinWall:SetHidden(not ZO_WorldMap_IsPinGroupShown(MAP_FILTER_OBJECTIVES))
				POIPinWall:SetShaderEffectType(SHADER_EFFECT_TYPE_WAVE)
				POIPinWall:SetWave(-0.05, 9.75, 3.8)
				POIPinWall:SetWaveBounds(0, 0, 0.18, 0)
				POIPinWall:SetPixelRoundingEnabled(false)
				
				
				POIPinCaustics = GetControl("Fyr_MM_Scroll_Map_POIPins_Pin"..tostring(FyrMM.currentPOICount).."_Caustics")
				if POIPinCaustics == nil then
				    POIPinCaustics = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_POIPins_Pin"..tostring(FyrMM.currentPOICount).."_Caustics", Fyr_MM_Scroll_Map_POIPins, CT_TEXTURE)
				end	
				POIPinCaustics.poiIndex = poiIndex
				POIPinCaustics.m_PinType = 9997
				POIPinCaustics.m_PinTag = tag
				POIPinCaustics.m_Pin = pin
				POIPinCaustics.MapId = CurrentMap.MapId
				POIPinCaustics.nX = nX
				POIPinCaustics.nY = nY
				POIPinCaustics:SetDrawLayer(1)
				POIPinCaustics:SetDrawLayer(ZO_MapPin.PIN_DATA[iconType].level - 1)
				FyrMM.SetPinSize(POIPinCaustics, auraSize, 0)
				POIPinCaustics:SetTexture("/esoui/art/mappins/writhing_wall_caustics.dds")
				FyrMM.SetPinAnchor(POIPinCaustics, nX, nY, Fyr_MM_Scroll_Map_POIPins)
				POIPinCaustics:SetHidden(not ZO_WorldMap_IsPinGroupShown(MAP_FILTER_OBJECTIVES))
				POIPinCaustics:SetShaderEffectType(SHADER_EFFECT_TYPE_CAUSTIC)
				POIPinCaustics:SetCaustic(120, 20, 1.75)
				POIPinCaustics:SetPixelRoundingEnabled(false)
				

			else
			    POIPin.spectacleEventPin = false
				POIPinWall = GetControl("Fyr_MM_Scroll_Map_POIPins_Pin"..tostring(FyrMM.currentPOICount).."_Wall")
				if POIPinWall ~= nil then
				    PinsList[POIPinWall:GetName()] = nil
				end
				POIPinCaustics = GetControl("Fyr_MM_Scroll_Map_POIPins_Pin"..tostring(FyrMM.currentPOICount).."_Caustics")
				if POIPinCaustics ~= nil then
				    PinsList[POIPinCaustics:GetName()] = nil
				end
			end

            local POIPinData = ZOpinData[iconType]
            if POIPinData.tint then -- compatibility with addons which modifies POI colors
                if type(POIPinData.tint) ~= "function" then
                    POIPin:SetColor(POIPinData.tint:UnpackRGBA())
                else
                    if POIPin.m_Pin ~= nil then
                        POIPin:SetColor(POIPinData.tint(POIPin.m_Pin):UnpackRGBA())
                    else
                        POIPin:SetColor(POIPinData.tint(POIPin):UnpackRGBA())
                    end
                end
            else
                --POIPin:SetColor(1, 1, 1, 1)
            end

             
            FyrMM.SetPinAnchor(POIPin, nX, nY, Fyr_MM_Scroll_Map_POIPins)
            POIPin:SetMouseEnabled(true)
			POIPin:SetHidden(not ZO_WorldMap_IsPinGroupShown(MAP_FILTER_OBJECTIVES))
        end
    end
end

function FyrMM.POIPins() 
	if FyrMM.Reloading then
		return
	end
    if FyrMM.Halted or MM_GetNumPOIs(CurrentMap.ZoneIndex) == 0 then
	    FyrMM.updatingPOIPins = false
        return
    else
	    FyrMM.updatingPOIPins = true
	end
	
    local t = GetGameTimeMilliseconds()
    FyrMM.currentPOICount = 0
    FyrMM.API_Check()
    FyrMM.SetMapToPlayerLocation()
    if string.lower(CurrentMap.filename) ~= "giantsrun_base_0" then
        for i = 1, MM_GetNumPOIs(CurrentMap.ZoneIndex) do
            if FyrMM.Reloading then
			          FyrMM.updatingPOIPins = false
                return
            end
            CreatePOIPin(i)
        end
    end
	
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug","FyrMM.POIPins("..tostring(MM_GetNumPOIs(CurrentMap.ZoneIndex))..")"..tostring(GetGameTimeMilliseconds() - t))
    end
	
    if FyrMM.currentPOICount == 0 and Fyr_MM_Scroll_Map_POIPins:GetNumChildren() == CleanPOIs then
        FyrMM.updatingPOIPins = false
		return
    end
	
	
	
    CleanPOIs = 0
    CleanupPOIs()
end

function FyrMM.DelayedPOIPins()
    if FyrMM.updatingPOIPins then
	   return
	end
	zo_callLater(FyrMM.POIPins, 5) -- zo_callLater OK - switched from 300 to 5
end
------------------------------------------------------------
-- Location Pins
------------------------------------------------------------

local function AddLocation(locationIndex)
    local locationPin, isExperienceBoost
    local ll = GetNumMapLocationTooltipLines(locationIndex)
    if ll >= 1 then
        local c1, c2, c3, cN = GetMapLocationTooltipLineInfo(locationIndex, 1)
        if cN == "Experience Boost" then
            return
        end
    end
    
    local icon, x, y = MM_GetMapLocationIcon(locationIndex)
    local hideDynamicWorldEvent
    local context
    local distance
    -- we need to show/hide Dynamic world event independantly of the FyrMM.SV.ShowUnexploredPins setting
    if icon == "/esoui/art/icons/servicemappins/u50_poi_dynamic_world_event.dds"  then  
        if not MM_IsMapLocationVisible(locationIndex) then
             hideDynamicWorldEvent = true
        else
             distance = CurrentMap.TrueMapSize * zo_sqrt( (x - CurrentMap.PlayerNX) * (x - CurrentMap.PlayerNX) + (y - CurrentMap.PlayerNY) * (y - CurrentMap.PlayerNY)) 
             context = 9999
        end
    end 
    
    
    if (MM_IsMapLocationVisible(locationIndex) or (FyrMM.SV.ShowUnexploredPins and not hideDynamicWorldEvent)) then
        if icon ~= "" and x > 0 and x < 1.0001 and y > 0 and y < 1.0001 then
            FyrMM.currentLocationsCount = FyrMM.currentLocationsCount + 1
            local tag = ZO_MapPin.CreateLocationPinTag(locationIndex, icon)
            locationPin = GetControl("Fyr_MM_Scroll_Map_LocationPins_Pin" .. tostring(FyrMM.currentLocationsCount))
            if locationPin == nil then
                locationPin = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_LocationPins_Pin"..tostring(FyrMM.currentLocationsCount), Fyr_MM_Scroll_Map_LocationPins, CT_TEXTURE)
                locationPin:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
                locationPin:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
            end

            local pinSize = 36 * FyrMM.pScalePercent * FyrMM.pinZoomScale
            local pin = ZO_Object.New(ZO_MapPin)
            if context then
                locationPin.context = context
            else
                locationPin.context = nil
            end
            if distance then
                locationPin.weDistance = distance
            else
                locationPin.weDistance = nil
            end
            locationPin.locationIndex = locationIndex
            pin.m_PinType = MAP_PIN_TYPE_LOCATION
            pin.m_PinTag = tag
            locationPin.m_Pin = pin
            locationPin.m_PinType = MAP_PIN_TYPE_LOCATION
            locationPin.m_PinTag = tag
            locationPin.MapId = CurrentMap.MapId
            locationPin.nX = x
            locationPin.nY = y
            FyrMM.SetPinSize(locationPin, pinSize, 0)
            locationPin:SetDrawLayer(1)
            locationPin:SetTexture(icon)
            locationPin.IsCraftingServicePin = IsCraftingService(locationPin)
            if tag[2] ~= nil then
                if string.sub(tag[2], -8) == "bank.dds" then
                    locationPin.IsBankPin = true
                else
                    locationPin.IsBankPin = false
                end
                if string.sub(tag[2], -10) == "stable.dds" then
                    locationPin.IsStablePin = true
                else
                    locationPin.IsStablePin = false
                end
            end
            if string.sub(icon, 1, 5) ~= "ZGESO" then -- string.sub(icon, 1, 17) ~= "ZygorGuidesViewer"
                if FyrMM.SV.ShowUnexploredPins then
                    locationPin:SetHidden(false)
                else
                    if locationPin:IsHidden() then
                        locationPin:SetHidden(not MM_IsMapLocationVisible(i))
                    end
                end
            else
                locationPin:SetHidden(false)
                locationPin.isZGESO = true
            end

            local locationPinData = ZOpinData[locationPin.m_PinType]
            if locationPinData.tint then -- compatibility with addons which modifies locations colors
                if type(locationPinData.tint) ~= "function" then
                    locationPin:SetColor(locationPinData.tint:UnpackRGBA())
                else
                    if locationPin.m_Pin ~= nil then
                        locationPin:SetColor(locationPinData.tint(locationPin.m_Pin):UnpackRGBA())
                    else
                        locationPin:SetColor(locationPinData.tint(locationPin):UnpackRGBA())
                    end
                end
            else
                locationPin:SetColor(1, 1, 1, 1)
            end

            FyrMM.SetPinAnchor(locationPin, x, y, Fyr_MM_Scroll_Map_LocationPins)
            locationPin:SetMouseEnabled(true)
        end
    end
end

function FyrMM.LocationPins() -- that one seems to trigger only once when zoning, no need to filter
	if FyrMM.Reloading then
		return
	end
	if FyrMM.Halted or MM_GetNumMapLocations() == 0 then
        return
    end 

    local t = GetGameTimeMilliseconds()
    FyrMM.currentLocationsCount = 0
    FyrMM.API_Check()
    FyrMM.SetMapToPlayerLocation()
    if string.lower(CurrentMap.filename) ~= "giantsrun_base_0" then
        for i = 1, MM_GetNumMapLocations() do
            if FyrMM.Reloading then
                return
            end
            AddLocation(i)
        end
    end
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug",
            "FyrMM.LocationPins (" .. tostring(MM_GetNumMapLocations()) .. ") " ..
            tostring(GetGameTimeMilliseconds() - t))
    end
    CleanupMapLocations()
end

------------------------------------------------------------
-- Event Units (Dragons, Cartoklepts, Arcane Knots)
------------------------------------------------------------
-- 31/07/2026 fix: event-unit pins used to be named after the dynamic unitTag string
-- ("Fyr_MM_Scroll_Map_EventUnits_"..unitTag), so every new dragon/cartoklept/arcane-knot
-- instance permanently added a brand new control - ESO controls can't be destroyed, so this
-- grew Fyr_MM_Scroll_Map_EventUnits's child count (and Lua/UI memory) without bound over a
-- session, and made the 100ms cleanup scan progressively slower. Controls are now created with
-- fixed slot names and reused via FyrMM.EventUnitPinByTag, the same pooling pattern used for
-- wayshrine/skyshard/dig site pins elsewhere in this file.
function FyrMM.ReleaseEventUnitPin(pin)
    if pin.unitTag and FyrMM.EventUnitPinByTag then
        FyrMM.EventUnitPinByTag[pin.unitTag] = nil
    end
    if pin.eventPOIKey and FyrMM.EventPOIPinByKey then
        FyrMM.EventPOIPinByKey[pin.eventPOIKey] = nil
    end
    pin.eventPOIKey = nil
    pin:SetHidden(true)
    pin:SetMouseEnabled(false)
    pin:ClearAnchors()
    pin.nX = nil
    pin.nY = nil
    pin.name = nil
    pin.unitTag = nil
    pin.nTag = nil
    pin.context = nil
    pin.m_PinType = nil
    pin.animationOngoing = nil
    if pin.textureAntl then
        pin.textureAntl:Stop()
        pin.textureAntl = nil
    end
    if pin.OnBorder then
        if pin.BorderPin then
            if pin.BorderPin.textureAntl then
                pin.BorderPin.textureAntl:Stop()
                pin.BorderPin.textureAntl = nil
            end
            pin.BorderPin:ClearAnchors()
            pin.BorderPin:SetHidden(true)
            pin.BorderPin.pin = nil
            pin.BorderPin = nil
        end
        pin.OnBorder = nil
    end
end

local function RemoveEventUnitPins()
    local num = Fyr_MM_Scroll_Map_EventUnits:GetNumChildren()
    local i, pin
    for i = 1, num do
        pin = Fyr_MM_Scroll_Map_EventUnits:GetChild(i)
        if pin ~= nil and (pin.context == WORLD_EVENT_LOCATION_CONTEXT_UNIT and (IsUnitDead(pin.unitTag) or not DoesUnitExist(pin.unitTag)) or pin.context == WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST) then
            FyrMM.ReleaseEventUnitPin(pin)
        end
    end
end

-- Force every active event-unit pin back into the pool on zone change instead of waiting for
-- DoesUnitExist()/IsUnitDead() to catch up next tick. World event units never carry over between
-- zones, so there's nothing worth preserving, and this guarantees slots are free before the new
-- zone's AddWorldEvent() pass runs (per-zone request: suppress event pins on zone change).
function FyrMM.ReleaseAllEventUnitPins()
    local num = Fyr_MM_Scroll_Map_EventUnits:GetNumChildren()
    for i = 1, num do
        local pin = Fyr_MM_Scroll_Map_EventUnits:GetChild(i)
        if pin ~= nil and pin.context ~= nil then
            FyrMM.ReleaseEventUnitPin(pin)
        end
    end
end

local function GetNextWorldEventInstanceIdIter(state, var1)
    return GetNextWorldEventInstanceId(var1)
end

-- 31/07/2026 fix: bounded pool of event-unit pin controls, reused across unitTags/zones instead
-- of creating a new permanently-named control per unitTag. Pool size is capped at the max number
-- of world event units ever concurrently visible in one pass, not the number ever seen this session.
local function GetPooledEventUnitPin(unitTag)
    FyrMM.EventUnitPinByTag = FyrMM.EventUnitPinByTag or {}
    FyrMM.EventUnitPinPool = FyrMM.EventUnitPinPool or {}

    local pin = FyrMM.EventUnitPinByTag[unitTag]
    if pin then
        return pin
    end

    for _, pooled in ipairs(FyrMM.EventUnitPinPool) do
        if pooled.unitTag == nil then
            pin = pooled
            break
        end
    end

    if pin == nil then
        pin = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_EventUnits_Slot"..(#FyrMM.EventUnitPinPool + 1), Fyr_MM_Scroll_Map_EventUnits, CT_TEXTURE)
        pin:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
        pin:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
        table.insert(FyrMM.EventUnitPinPool, pin)
    end

    FyrMM.EventUnitPinByTag[unitTag] = pin
    return pin
end

-- 31/07/2026 fix: same issue as GetPooledEventUnitPin above, but for dolmens/harrowstorms.
-- Controls were named "Fyr_MM_Scroll_Map_EventPOIs_"..poiIndex with no zoneIndex qualifier, so
-- visiting a zone whose event POI table used a poiIndex not seen in any previously-visited zone
-- always minted a brand new permanent control. Bounded pool + key->pin map instead, same pattern.
local function GetPooledEventPOIPin(poiIndex)
    FyrMM.EventPOIPinByKey = FyrMM.EventPOIPinByKey or {}
    FyrMM.EventPOIPinPool = FyrMM.EventPOIPinPool or {}

    local pin = FyrMM.EventPOIPinByKey[poiIndex]
    if pin then
        return pin
    end

    for _, pooled in ipairs(FyrMM.EventPOIPinPool) do
        if pooled.eventPOIKey == nil then
            pin = pooled
            break
        end
    end

    if pin == nil then
        pin = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_EventPOIs_Slot"..(#FyrMM.EventPOIPinPool + 1), Fyr_MM_Scroll_Map_EventUnits, CT_TEXTURE)
        pin:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
        pin:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
        table.insert(FyrMM.EventPOIPinPool, pin)
    end

    pin.eventPOIKey = poiIndex
    FyrMM.EventPOIPinByKey[poiIndex] = pin
    return pin
end

local function AddWorldEvent(worldEventInstanceId)

    if ZO_WorldMap_DoesMapHideWorldEventPins() or worldEventInstanceId == 0 then
        return
    end

    local context = GetWorldEventLocationContext(worldEventInstanceId)
    if context == WORLD_EVENT_LOCATION_CONTEXT_UNIT then
        local numUnits = GetNumWorldEventInstanceUnits(worldEventInstanceId)
        for i = 1, numUnits do
            local unitTag = GetWorldEventInstanceUnitTag(worldEventInstanceId, i)
            local pinType = GetWorldEventInstanceUnitPinType(worldEventInstanceId, unitTag)
            local zoneIndex, poiIndex = GetWorldEventPOIInfo(worldEventInstanceId)

            local pin
            if pinType ~= MAP_PIN_TYPE_INVALID then
                local xLoc, yLoc, _, isInCurrentMap = GetMapPlayerPosition(unitTag)
                if isInCurrentMap then
                    local tag = ZO_MapPin.CreateWorldEventUnitPinTag(worldEventInstanceId, unitTag)
                    pin = GetPooledEventUnitPin(unitTag)
                    FyrMM.SetEventPin(pin, pinType, unitTag, tag, context)
                end
            end
        end
    elseif context == WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST then

        local zoneIndex, poiIndex = GetWorldEventPOIInfo(worldEventInstanceId)
        
        if zoneIndex == 1 and poiIndex  == 1 then -- it's a location = it's a participating dynamic world event we abort
            return
        end
        
        
        local nX, nY, pinType, icon, isOnMap, _, discovered, nearby = MM_GetPOIMapInfo(CurrentMap.ZoneIndex, poiIndex)
        
         
        local tag = ZO_MapPin.CreateWorldEventPOIPinTag(worldEventInstanceId, CurrentMap.ZoneIndex, poiIndex)
        local pin

        if pinType ~= MAP_PIN_TYPE_INVALID  and isOnMap then
            pin = GetPooledEventPOIPin(poiIndex)
            FyrMM.SetEventPOIPin(pin, pinType, tag, poiIndex, context)
        end
    end
end

function FyrMM.SetEventPin(pin, pinType, tag, ntag, context) -- moving world events (dragons, cartoklepts, arcane knots)
    local nX, nY
    local pdata = ZO_MapPin.PIN_DATA[pinType]
    --local isDead = IsUnitDead(tag)

    if pin == nil then
        return
    end

    if not (DoesUnitExist(tag) and not AreUnitsEqual("player", tag)) then
        if FyrMM.EventUnitPinByTag then
            FyrMM.EventUnitPinByTag[tag] = nil
        end
        FyrMM.ReleaseEventUnitPin(pin)
        return
    end

    nX, nY = GetMapPlayerPosition(tag)
    pin.m_PinType = pinType
    local distance = CurrentMap.TrueMapSize * zo_sqrt( (nX - CurrentMap.PlayerNX) * (nX - CurrentMap.PlayerNX) + (nY - CurrentMap.PlayerNY) * (nY - CurrentMap.PlayerNY))

    local texturetest = GetWorldEventInstanceUnitPinIcon(ntag[1], tag, false) or "not"

    local texture = "esoui/art/icons/mapkey/mapkey_dragon.dds"

    if string.find(texturetest, "dragon") then               -- It's a dragon!
        texture = "esoui/art/icons/mapkey/mapkey_dragon.dds" -- /esoui/art/mappins/dragon_fly.dds
    elseif string.find(texturetest, "cartoklept") then       -- it's a cartoklept!
        texture = "esoui/art/compass/compass_cartoklept.dds"
	  elseif string.find(texturetest, "arcaneknottracker") then  -- it's an arcane knot !
        texture = "esoui/art/icons/poi/u42_tri_arcaneknottracker_whole.dds"	
   	elseif string.find(texturetest, "u49_az_worldeventmonster") then  -- it's a Night Market boss !
        texture = "/esoui/art/icons/mapkey/u49_az_worldeventmonster_healthy.dds"
    else
        texture = texturetest
    end

    pin:SetTexture(texture)
    pin.pinTexture = texture

    local pinsize = pdata.size
    if pinsize == nil then
        pinsize = 32
    end

    FyrMM.SetPinSize(pin, pinsize * FyrMM.pScalePercent, 0)
    pin.nX = nX
    pin.nY = nY
	  pin.name = GetRawUnitName(tag)
    pin.unitTag = tag
    pin.nTag = ntag
    pin.context = context
    pin.weDistance = distance
    pin.noZoomResize = true
    pin:SetDrawLayer(3)
    pin:SetMouseEnabled(true)
    FyrMM.SetPinAnchor(pin, nX, nY, Fyr_MM_Scroll_Map_EventUnits)
    

    if IsUnitInCombat(tag) then
        --FyrMM.CheapAnimation(pin)
		local REQUEST_ANIMATED_TEXTURE = false
		local animatedTexture = GetWorldEventInstanceUnitPinIcon(ntag[1], tag, REQUEST_ANIMATED_TEXTURE)
		pin:SetTexture(animatedTexture)
    pin.pinTexture = animatedTexture
        --pin:SetColor(1, 0, 0, 1)
        
	     if pdata.isAnimated and pin.m_textureAnimTimeline == nil then
		     pin.m_textureAnimTimeline = "yes"
	       FyrMM.PlayTextureAnimation(pin, pdata.framesWide, pdata.framesHigh, pdata.framesPerSecond, LOOP_INDEFINITELY, ANIMATION_PLAYBACK_LOOP)
       end
    else
        pin:SetColor(1, 1, 1, 1)
        pin:SetTransformRotationZ(0)
        if pin.m_textureAnimTimeline and pin.m_textureAnimTimeline ~= "yes" then 
           pin.m_textureAnimTimeline:Stop()
        end
        pin.m_textureAnimTimeline = nil
    end

    if FyrMM.SV.WheelMap then
        pin:SetHidden(not FyrMM.Is_PinInsideWheel(pin))
    else
        pin:SetHidden(false)
    end

    if FyrMM.IsValidBorderPin(pin) then
        FyrMM.CreateBorderPin(pin)
	end
end

function FyrMM.SetEventPOIPin(pin, pinType, tag, poiIndex, context) -- world events (dolmens, harrow storms, etc)
    local pdata = ZO_MapPin.PIN_DATA[pinType]

    if pin == nil then
        return
    end
    local nX, nY, pinType, icon, isOnMap, _, discovered, nearby = MM_GetPOIMapInfo(GetCurrentMapZoneIndex(), poiIndex)
	  local name,_,_,_ = GetPOIInfo(GetCurrentMapZoneIndex(), poiIndex)
    
    local distance = CurrentMap.TrueMapSize * zo_sqrt((nX - CurrentMap.PlayerNX) * (nX - CurrentMap.PlayerNX) + (nY - CurrentMap.PlayerNY) * (nY - CurrentMap.PlayerNY))

    if not isOnMap then
        FyrMM.ReleaseEventUnitPin(pin)
        return
    end

    pin.m_PinType = pinType

    local texture = "esoui/art/zonestories/completiontypeicon_worldevents.dds"
    
    pin:SetTexture(texture)
    pin.pinTexture = texture

    pin:SetColor(1, 1, 1, 1)
    local pinsize = pdata.size
    if pinsize == nil then
        pinsize = 32
    end
    FyrMM.SetPinSize(pin, pinsize * FyrMM.pScalePercent, 0)
    pin.nX = nX
    pin.nY = nY
	  pin.name = name
    pin.unitTag = tag
    pin.nTag = tag
    pin.context = context
    pin.weDistance = distance
    pin:SetDrawLayer(3)
    pin:SetMouseEnabled(true)
    FyrMM.SetPinAnchor(pin, nX, nY, Fyr_MM_Scroll_Map_EventUnits)
    
    
    if string.find(icon, "skirmish") then -- it's a night market skirmish, we treat it differently 
        local animatedTexture = "/esoui/art/icons/servicemappins/u49_worldevent_poi_adventurezone_skirmish.dds"
        pin:SetTexture(animatedTexture)
        pin.pinTexture = animatedTexture
        pdata = ZO_MapPin.PIN_DATA[MAP_PIN_TYPE_WORLD_EVENT_POI_ACTIVE]
        pin.m_PinType = MAP_PIN_TYPE_WORLD_EVENT_POI_ACTIVE
        
        if pdata.isAnimated and pin.m_textureAnimTimeline == nil then
           pin.m_textureAnimTimeline = "yes"
           FyrMM.PlayTextureAnimation(pin, pdata.framesWide, pdata.framesHigh, pdata.framesPerSecond, LOOP_INDEFINITELY, ANIMATION_PLAYBACK_LOOP)
        end
    else
        -- we won't animate that pin the ZOS way because I prefer my spinning huricane 8-)
        FyrMM.CheapAnimation(pin, true)
        pin.m_textureAnimTimeline = "yes"
    end


    if FyrMM.SV.WheelMap then
        pin:SetHidden(not FyrMM.Is_PinInsideWheel(pin))
    else
        pin:SetHidden(false)
    end

    if FyrMM.IsValidBorderPin(pin) then
        FyrMM.CreateBorderPin(pin)
    end
end

function FyrMM.RefreshEventUnits()
    RemoveEventUnitPins()
    for worldEventInstanceId in GetNextWorldEventInstanceIdIter do
        AddWorldEvent(worldEventInstanceId)
    end
end

function FyrMM.CheapAnimation(pin, rotate) -- added by @Masteroshi430
    local pinsize = 64
    local pinsizeMax = pinsize + 8
    local pinsizeMin = pinsize - 8

    if FyrMM.animatedPinSize then
        if FyrMM.animatedPinSize == pinsizeMax then
            FyrMM.goDown = true

            FyrMM.animatedPinSize = FyrMM.animatedPinSize - 1
        elseif FyrMM.animatedPinSize == pinsizeMin then
            FyrMM.goDown = false
            FyrMM.animatedPinSize = FyrMM.animatedPinSize + 1
        elseif FyrMM.animatedPinSize > pinsizeMin and FyrMM.goDown == true then
            FyrMM.animatedPinSize = FyrMM.animatedPinSize - 1
        elseif FyrMM.animatedPinSize < pinsizeMax then
            FyrMM.animatedPinSize = FyrMM.animatedPinSize + 1
        end
    else
        FyrMM.animatedPinSize = pinsizeMax
    end

    if rotate then
        if FyrMM.radians == nil then
            FyrMM.radians = 0
        end
        FyrMM.radians = zo_min(doublePi, FyrMM.radians + 0.1)
        if FyrMM.radians == doublePi then
            FyrMM.radians = 0
        end
        pin:SetTransformRotationZ(FyrMM.radians)
    else
        pin:SetTransformRotationZ(0)
    end

    local properSize = floor(FyrMM.animatedPinSize * FyrMM.pScalePercent / 2) * 2
    pin:SetDimensions(properSize, properSize)
end

------------------------------------------------------------
-- Group Pins
------------------------------------------------------------
function FyrMM.GroupEvent()
    FyrMM.GroupRefreshNeeded = true
    FyrMM.RefreshGroup()
end

-- 02/07/2026 optimization: Shared constant for the "target marker override" white color, reused
-- below instead of allocating a fresh {1,1,1,1} table on every group-pin texture update.
local WHITE_PIN_COLOR = {1, 1, 1, 1}

function FyrMM.SetGroupPinTexture(gmPin, odyTexture)
    local Multiplier = 1
    local gmPinTexture = ""
    if gmPin.unitTag == "companion" then -- companions
        gmPinTexture = "EsoUI/Art/MapPins/activeCompanion_pin.dds"
        if odyTexture then
            gmPinTexture = odyTexture
        end

        if gmPin.isSwimming then -- in case companions are able to swim in the future
            gmPinTexture = "MiniMap/Textures/swimming.dds"
            Multiplier = 0.7
        elseif gmPin.isMounted then
            gmPinTexture = "MiniMap/Textures/mountedMember.dds"
            Multiplier = 1.1
        elseif gmPin.isStealthed then
            gmPinTexture = "MiniMap/Textures/stealthed.dds"
            Multiplier = 0.8
        elseif gmPin.isDisguised then
            gmPinTexture = "MiniMap/Textures/disguised.dds"
            Multiplier = 0.8
        elseif gmPin.isInAir then -- in case companions are able to fly in the future LOL
            gmPinTexture = "MiniMap/Textures/flying.dds"
            Multiplier = 0.7
        end
        FyrMM.SetPinSize(gmPin, FyrMM.SV.MemberPinSize * FyrMM.pScalePercent * Multiplier, 0)
    else
        if gmPin.isLeader then -- group leader
            if FyrMM.SV.LeaderPin == "Default" then
                gmPinTexture = "EsoUI/Art/Compass/groupLeader.dds"
            elseif FyrMM.SV.LeaderPin == "Class" then
                gmPinTexture = ZO_GetClassIcon(gmPin.ClassId)
            elseif gmPin.isDps then
                gmPinTexture = "EsoUI/Art/LFG/LFG_dps_down.dds"
            elseif gmPin.isHeal then
                gmPinTexture = "EsoUI/Art/LFG/LFG_healer_down.dds"
            elseif gmPin.isTank then
                gmPinTexture = "EsoUI/Art/LFG/LFG_tank_down.dds"
            else
                gmPinTexture = "EsoUI/Art/Compass/groupLeader.dds"
            end

            if odyTexture then
                gmPinTexture = odyTexture
            end
			
            -- 02/07/2026 optimization: Call GetTargetMarkerPicture once and reuse the shared
            -- white color constant instead of calling the function twice and allocating a fresh
            -- color table, every group-pin update.
            local leaderMarkerPicture = FyrMM.GetTargetMarkerPicture(gmPin.unitTag)
            if leaderMarkerPicture then
                gmPinTexture = leaderMarkerPicture
				gmPin.color = WHITE_PIN_COLOR
	            gmPin:SetColor(gmPin.color[1], gmPin.color[2], gmPin.color[3], gmPin.color[4])
                Multiplier = 0.5
            end
			
			if gmPin.isSwimming and not gmPin.engaged then
                gmPinTexture = "MiniMap/Textures/swimming.dds"
                Multiplier = 0.7
            elseif gmPin.isMounted and not gmPin.engaged then
                gmPinTexture = "MiniMap/Textures/mountedLeader.dds"
                Multiplier = 1.1
            elseif gmPin.isStealthed and not gmPin.engaged then
                gmPinTexture = "MiniMap/Textures/stealthed.dds"
                Multiplier = 0.8
            elseif gmPin.isDisguised then
                gmPinTexture = "MiniMap/Textures/disguised.dds"
                Multiplier = 0.8
            elseif gmPin.isInAir and not gmPin.engaged then
                gmPinTexture = "MiniMap/Textures/flying.dds"
                Multiplier = 0.7
            end

            if gmPin.isBreadcrumb then
                gmPinTexture = "EsoUI/Art/Compass/groupLeader_door.dds"
            end

            FyrMM.SetPinSize(gmPin, FyrMM.SV.LeaderPinSize * FyrMM.pScalePercent * Multiplier, 0)
        else -- other group members
            if FyrMM.SV.MemberPin == "Class" or IsActiveWorldBattleground() then -- force class icons in battlegrounds  
                gmPinTexture = ZO_GetClassIcon(gmPin.ClassId)
				Multiplier = 1.3 
            elseif FyrMM.SV.MemberPin == "Default" then
                gmPinTexture = "EsoUI/Art/MapPins/UI-WorldMapGroupPip.dds" 
            elseif gmPin.isDps then
                gmPinTexture = "EsoUI/Art/LFG/LFG_dps_down.dds"
            elseif gmPin.isHeal then
                gmPinTexture = "EsoUI/Art/LFG/LFG_healer_down.dds"
            elseif gmPin.isTank then
                gmPinTexture = "EsoUI/Art/LFG/LFG_tank_down.dds"
            else
                gmPinTexture = "EsoUI/Art/MapPins/UI-WorldMapGroupPip.dds" -- "esoui/art/icons/mapkey/mapkey_groupmember.dds"
            end

            if odyTexture then
                gmPinTexture = odyTexture
            end
			
            -- 02/07/2026 optimization: Call GetTargetMarkerPicture once and reuse the shared
            -- white color constant instead of calling the function twice and allocating a fresh
            -- color table, every group-pin update.
            local memberMarkerPicture = FyrMM.GetTargetMarkerPicture(gmPin.unitTag)
            if memberMarkerPicture then
                gmPinTexture = memberMarkerPicture
				gmPin.color = WHITE_PIN_COLOR
	            gmPin:SetColor(gmPin.color[1], gmPin.color[2], gmPin.color[3], gmPin.color[4])
                Multiplier = 0.5
            end
			
            if gmPin.isSwimming and not gmPin.engaged then
                gmPinTexture = "MiniMap/Textures/swimming.dds"
                Multiplier = 0.7
            elseif gmPin.isMounted and not gmPin.engaged then
                gmPinTexture = "MiniMap/Textures/mountedMember.dds"
                Multiplier = 1.1
            elseif gmPin.isStealthed and not gmPin.engaged then
                gmPinTexture = "MiniMap/Textures/stealthed.dds"
				Multiplier = 0.8
            elseif gmPin.isDisguised then
                gmPinTexture = "MiniMap/Textures/disguised.dds"
                Multiplier = 0.8
            elseif gmPin.isInAir and not gmPin.engaged then
                gmPinTexture = "MiniMap/Textures/flying.dds"
                Multiplier = 0.7
            end

            if gmPin.isBreadcrumb then
                gmPinTexture = "esoui/art/compass/groupmember_door.dds"
            end
			
            FyrMM.SetPinSize(gmPin, FyrMM.SV.MemberPinSize * FyrMM.pScalePercent * Multiplier, 0)
        end
    end
	
	-- Apply target marker colors to Mounted, Stealthed, Swimming group pins
	-- 02/07/2026 optimization: Call GetTargetMarkerColor once and reuse the result instead of
	-- calling it twice (condition + body) for every group member every RefreshGroup tick.
	local targetColor = FyrMM.GetTargetMarkerColor(gmPin.unitTag)
	if targetColor and (not gmPin.engaged) and (gmPin.isMounted or gmPin.isStealthed or gmPin.isSwimming or gmPin.isDisguised) then
	   gmPin.color = targetColor
	   gmPin:SetColor(gmPin.color[1], gmPin.color[2], gmPin.color[3], gmPin.color[4])
	end
	
    gmPin:SetTexture(gmPinTexture)
    gmPin.pinTexture = gmPinTexture -- we set that here to avoid resetting it for borderpins
end

-- 02/07/2026 optimization: Build these lookup tables once instead of allocating them (targetMarkerColor
-- allocates 8 nested sub-tables) fresh on every call. Both functions run per group member on the
-- 40ms RefreshGroup path, so this was significant table-allocation churn for groups using target markers.
local targetMarkerTexture = {
    [TARGET_MARKER_TYPE_ONE] = "EsoUI/Art/TargetMarkers/Target_Blue_Square_64.dds",
    [TARGET_MARKER_TYPE_TWO] = "EsoUI/Art/TargetMarkers/Target_Gold_Star_64.dds",
    [TARGET_MARKER_TYPE_THREE] = "EsoUI/Art/TargetMarkers/Target_Green_Circle_64.dds",
    [TARGET_MARKER_TYPE_FOUR] = "EsoUI/Art/TargetMarkers/Target_Orange_Triangle_64.dds",
    [TARGET_MARKER_TYPE_FIVE] = "EsoUI/Art/TargetMarkers/Target_Pink_Moons_64.dds",
    [TARGET_MARKER_TYPE_SIX] = "EsoUI/Art/TargetMarkers/Target_Purple_Oblivion_64.dds",
    [TARGET_MARKER_TYPE_SEVEN] = "EsoUI/Art/TargetMarkers/Target_Red_Weapons_64.dds",
    [TARGET_MARKER_TYPE_EIGHT] = "EsoUI/Art/TargetMarkers/Target_White_Skull_64.dds",
}

function FyrMM.GetTargetMarkerPicture(tag)
    if not FyrMM.SV.GroupTargetMarkers then
        return nil
    end

    return targetMarkerTexture[GetUnitTargetMarkerType(tag)]
end

local targetMarkerColor = {
    [TARGET_MARKER_TYPE_ONE] =   {0.26, 0.76, 0.84, 1}, -- {68, 196, 215, 255},
    [TARGET_MARKER_TYPE_TWO] =   {0.96, 0.90, 0.63, 1}, -- {246, 231, 163, 255},
    [TARGET_MARKER_TYPE_THREE] = {0.38, 0.54, 0.32, 1}, -- {98, 140, 82, 255},
    [TARGET_MARKER_TYPE_FOUR] =  {0.87, 0.60, 0.21, 1}, -- {222, 154, 55, 255},
    [TARGET_MARKER_TYPE_FIVE] =  {0.63, 0.33, 0.51, 1}, -- {161, 85, 132, 255},
    [TARGET_MARKER_TYPE_SIX] =   {0.38, 0.14, 0.67, 1}, -- {97, 38, 171, 255},
    [TARGET_MARKER_TYPE_SEVEN] = {0.92, 0, 0, 1},       -- {236, 0, 0, 255},
    [TARGET_MARKER_TYPE_EIGHT] = {0.87, 0.90, 0.90, 1}, -- {222, 232, 230, 255},
}

function FyrMM.GetTargetMarkerColor(tag)
    if not FyrMM.SV.GroupTargetMarkers then
        return nil
    end

    -- 02/07/2026 optimization: Call GetUnitTargetMarkerType once instead of twice (guard + return),
    -- while still short-circuiting the native call entirely when the feature is disabled above.
    local markerType = GetUnitTargetMarkerType(tag)
    if markerType == 0 then
        return nil
    end

    return targetMarkerColor[markerType]
end

local GroupPinControls = {}
local function GetCachedGroupControl(name)
    local control = GroupPinControls[name]
    if not control then
        control = GetControl(name)
        GroupPinControls[name] = control
    end
    return control
end

-- 26/06/2026 optimization: Cache group and companion UI controls in a local table to avoid expensive GetControl lookups in hot paths
function FyrMM.SetGroupPin(tag)
    local pin, pin_ic, groupLabel, nX, nY
	local role = GetGroupMemberSelectedRole(tag)
	local isDps = false
	local isHeal = false
	local isTank = false

	if role == LFG_ROLE_DPS then
		isDps = true
	elseif role == LFG_ROLE_HEAL then
		isHeal = true
	elseif role == LFG_ROLE_TANK then
		isTank = true
	end
    local isDead = IsUnitDead(tag)
    pin = GetCachedGroupControl("Fyr_MM_Scroll_Map_GroupPins_"..tag)
    pin_ic = GetCachedGroupControl("Fyr_MM_Scroll_Map_GroupPins_"..tag.."_incombat")
    groupLabel = GetCachedGroupControl("Fyr_MM_Scroll_Map_GroupPins_"..tag.."_label")

	
    if (not DoesUnitExist(tag)) or AreUnitsEqual(tag, "player") or (not IsUnitOnline(tag)) or not(tag == "companion" or IsUnitGrouped(tag)) then 
      
	   if pin ~= nil then
            pin:SetHidden(true)
            pin:SetMouseEnabled(false)
            pin:ClearAnchors()
            pin.isDps = nil
            pin.isHeal = nil
            pin.isTank = nil
            pin.ClassId = nil
            pin.isLeader = nil
            pin.nX = nil
            pin.nY = nil
            PinsList["Fyr_MM_Scroll_Map_GroupPins_"..tag] = nil
			
            if pin.OnBorder then
                if pin.BorderPin then
                    pin.BorderPin:ClearAnchors()
                    pin.BorderPin:SetHidden(true)
                    pin.BorderPin.pin = nil
                    pin.BorderPin = nil
                end
                pin.OnBorder = nil
            end
        end
		
		if pin_ic ~= nil then
		    pin_ic.nX = nil
            pin_ic.nY = nil
            pin_ic:SetHidden(true)
            pin_ic:ClearAnchors()
			PinsList["Fyr_MM_Scroll_Map_GroupPins_"..tag.."_incombat"] = nil
		end
		
		if groupLabel then
		   groupLabel.nX = nil
		   groupLabel.nY = nil
		   groupLabel:SetHidden(true)
		   groupLabel:ClearAnchors()
		   PinsList["Fyr_MM_Scroll_Map_GroupPins_"..tag.."_label"] = nil
		end 

        return
    end

    if pin == nil then
        return
    end
	
    local nX, nY, _, isInCurrentMap = GetMapPlayerPosition(tag)
    pin.isDps = isDps
    pin.isHeal = isHeal
    pin.isTank = isTank
    pin.isLeader = IsUnitGroupLeader(tag)
    pin.isBreadcrumb = false
    pin.isMounted = GetTargetMountedStateInfo(GetRawUnitName(tag)) ~= MOUNTED_STATE_NOT_MOUNTED
	pin.isInAir = IsUnitInAir(tag) or IsUnitFalling(tag)
    pin.isStealthed = GetUnitStealthState(tag) ~= STEALTH_STATE_NONE
    pin.isSwimming = IsUnitSwimming(tag)
	pin.isDisguised = GetUnitDisguiseState(tag) == DISGUISE_STATE_DISGUISED

    -- 02/07/2026 optimization: The early-return guard above already established that
    -- DoesUnitExist(tag), not AreUnitsEqual(tag,"player"), and IsUnitOnline(tag) all hold -
    -- otherwise this function would have already returned. Re-checking them here was 3 wasted
    -- native API calls per group member on every 40ms RefreshGroup tick.
    do
        local isGroupMemberHiddenByInstance = false
        -- If we're in an instance and it has its own map, it's going to be a dungeon map or house. Don't show on the map if we're on different instances/layers
        -- If it doesn't have its own map, we're okay to show the group member regardless of instance
        if DoesCurrentMapMatchMapForPlayerLocation() and IsGroupMemberInSameWorldAsPlayer(tag) and
            (CurrentMap.MapContentType == MAP_CONTENT_DUNGEON or GetCurrentZoneHouseId() ~= 0) then
            if not IsGroupMemberInSameInstanceAsPlayer(tag) then
                -- We're in the same world as the group member, but a different instance
                isGroupMemberHiddenByInstance = true
            elseif not IsGroupMemberInSameLayerAsPlayer(tag) then
                -- We're in the same instance as the group member, but a different layer
                isGroupMemberHiddenByInstance = not IsUnitWorldMapPositionBreadcrumbed(tag)
            end
        end

        if not isGroupMemberHiddenByInstance then
            if isInCurrentMap then
                if IsUnitWorldMapPositionBreadcrumbed(tag) then
                    pin.isBreadcrumb = true
                end
            end
        end
    end
	

    if pin.isLeader then
        pin.m_PinType = MAP_PIN_TYPE_GROUP_LEADER
		
		if FyrMM.SV.MemberRolesColor then -- pins colored by roles
            if isDead then
			    if pin.isDps then
					pin:SetColor(FyrMM.SV.MemberRolesDeadDpsColor.r, FyrMM.SV.MemberRolesDeadDpsColor.g, FyrMM.SV.MemberRolesDeadDpsColor.b, FyrMM.SV.MemberRolesDeadDpsColor.a)
					if tag ~= "companion" and FyrMM.SV.ShowGroupLabels and groupLabel then
						groupLabel:SetColor(FyrMM.SV.MemberRolesDeadDpsColor.r, FyrMM.SV.MemberRolesDeadDpsColor.g, FyrMM.SV.MemberRolesDeadDpsColor.b, FyrMM.SV.MemberRolesDeadDpsColor.a) 
					end
				elseif pin.isHeal then
					pin:SetColor(FyrMM.SV.MemberRolesDeadHealColor.r, FyrMM.SV.MemberRolesDeadHealColor.g, FyrMM.SV.MemberRolesDeadHealColor.b, FyrMM.SV.MemberRolesDeadHealColor.a)
					if tag ~= "companion" and FyrMM.SV.ShowGroupLabels and groupLabel then
						groupLabel:SetColor(FyrMM.SV.MemberRolesDeadHealColor.r, FyrMM.SV.MemberRolesDeadHealColor.g, FyrMM.SV.MemberRolesDeadHealColor.b, FyrMM.SV.MemberRolesDeadHealColor.a) 
					end
				elseif pin.isTank then
					pin:SetColor(FyrMM.SV.MemberRolesDeadTankColor.r, FyrMM.SV.MemberRolesDeadTankColor.g, FyrMM.SV.MemberRolesDeadTankColor.b, FyrMM.SV.MemberRolesDeadTankColor.a)
					if tag ~= "companion" and FyrMM.SV.ShowGroupLabels and groupLabel then
						groupLabel:SetColor(FyrMM.SV.MemberRolesDeadTankColor.r, FyrMM.SV.MemberRolesDeadTankColor.g, FyrMM.SV.MemberRolesDeadTankColor.b, FyrMM.SV.MemberRolesDeadTankColor.a) 
					end
				end
            else
			    if pin.isDps then
					pin:SetColor(FyrMM.SV.MemberRolesDpsColor.r, FyrMM.SV.MemberRolesDpsColor.g, FyrMM.SV.MemberRolesDpsColor.b, FyrMM.SV.MemberRolesDpsColor.a)
					if tag ~= "companion" and FyrMM.SV.ShowGroupLabels and groupLabel then
						groupLabel:SetColor(FyrMM.SV.MemberRolesDpsColor.r, FyrMM.SV.MemberRolesDpsColor.g, FyrMM.SV.MemberRolesDpsColor.b, FyrMM.SV.MemberRolesDpsColor.a) 
					end
				elseif pin.isHeal then
					pin:SetColor(FyrMM.SV.MemberRolesHealColor.r, FyrMM.SV.MemberRolesHealColor.g, FyrMM.SV.MemberRolesHealColor.b, FyrMM.SV.MemberRolesHealColor.a)
					if tag ~= "companion" and FyrMM.SV.ShowGroupLabels and groupLabel then
						groupLabel:SetColor(FyrMM.SV.MemberRolesHealColor.r, FyrMM.SV.MemberRolesHealColor.g, FyrMM.SV.MemberRolesHealColor.b, FyrMM.SV.MemberRolesHealColor.a) 
					end
				elseif pin.isTank then
					pin:SetColor(FyrMM.SV.MemberRolesTankColor.r, FyrMM.SV.MemberRolesTankColor.g, FyrMM.SV.MemberRolesTankColor.b, FyrMM.SV.MemberRolesTankColor.a)
					if tag ~= "companion" and FyrMM.SV.ShowGroupLabels and groupLabel then
						groupLabel:SetColor(FyrMM.SV.MemberRolesTankColor.r, FyrMM.SV.MemberRolesTankColor.g, FyrMM.SV.MemberRolesTankColor.b, FyrMM.SV.MemberRolesTankColor.a) 
					end
				end
            end
        elseif FyrMM.SV.LeaderPinColor ~= nil and FyrMM.SV.LeaderDeadPinColor ~= nil then
            if isDead then
                pin:SetColor(FyrMM.SV.LeaderDeadPinColor.r, FyrMM.SV.LeaderDeadPinColor.g, FyrMM.SV.LeaderDeadPinColor.b, FyrMM.SV.LeaderDeadPinColor.a)
                if FyrMM.SV.ShowGroupLabels and groupLabel then
				   groupLabel:SetColor(FyrMM.SV.LeaderDeadPinColor.r, FyrMM.SV.LeaderDeadPinColor.g, FyrMM.SV.LeaderDeadPinColor.b, FyrMM.SV.LeaderDeadPinColor.a)
				end   
            else
                pin:SetColor(FyrMM.SV.LeaderPinColor.r, FyrMM.SV.LeaderPinColor.g, FyrMM.SV.LeaderPinColor.b, FyrMM.SV.LeaderPinColor.a)
				if FyrMM.SV.ShowGroupLabels and groupLabel then
                   groupLabel:SetColor(FyrMM.SV.LeaderPinColor.r, FyrMM.SV.LeaderPinColor.g, FyrMM.SV.LeaderPinColor.b, FyrMM.SV.LeaderPinColor.a)
				end   
            end
        else
		    if FyrMM.SV.ShowGroupLabels and groupLabel then
               groupLabel:SetColor(255, 255, 255, 255)
			end   
        end
    else
        if tag == "companion" then
            pin.m_PinType = MAP_PIN_TYPE_ACTIVE_COMPANION
        else
            pin.m_PinType = MAP_PIN_TYPE_GROUP
        end
		
		if FyrMM.SV.MemberRolesColor then -- pins colored by roles
            if isDead then
			    if pin.isDps then
					pin:SetColor(FyrMM.SV.MemberRolesDeadDpsColor.r, FyrMM.SV.MemberRolesDeadDpsColor.g, FyrMM.SV.MemberRolesDeadDpsColor.b, FyrMM.SV.MemberRolesDeadDpsColor.a)
					if tag ~= "companion" and FyrMM.SV.ShowGroupLabels and groupLabel then
						groupLabel:SetColor(FyrMM.SV.MemberRolesDeadDpsColor.r, FyrMM.SV.MemberRolesDeadDpsColor.g, FyrMM.SV.MemberRolesDeadDpsColor.b, FyrMM.SV.MemberRolesDeadDpsColor.a) 
					end
				elseif pin.isHeal then
					pin:SetColor(FyrMM.SV.MemberRolesDeadHealColor.r, FyrMM.SV.MemberRolesDeadHealColor.g, FyrMM.SV.MemberRolesDeadHealColor.b, FyrMM.SV.MemberRolesDeadHealColor.a)
					if tag ~= "companion" and FyrMM.SV.ShowGroupLabels and groupLabel then
						groupLabel:SetColor(FyrMM.SV.MemberRolesDeadHealColor.r, FyrMM.SV.MemberRolesDeadHealColor.g, FyrMM.SV.MemberRolesDeadHealColor.b, FyrMM.SV.MemberRolesDeadHealColor.a) 
					end
				elseif pin.isTank then
					pin:SetColor(FyrMM.SV.MemberRolesDeadTankColor.r, FyrMM.SV.MemberRolesDeadTankColor.g, FyrMM.SV.MemberRolesDeadTankColor.b, FyrMM.SV.MemberRolesDeadTankColor.a)
					if tag ~= "companion" and FyrMM.SV.ShowGroupLabels and groupLabel then
						groupLabel:SetColor(FyrMM.SV.MemberRolesDeadTankColor.r, FyrMM.SV.MemberRolesDeadTankColor.g, FyrMM.SV.MemberRolesDeadTankColor.b, FyrMM.SV.MemberRolesDeadTankColor.a) 
					end
				end
            else
			    if pin.isDps then
					pin:SetColor(FyrMM.SV.MemberRolesDpsColor.r, FyrMM.SV.MemberRolesDpsColor.g, FyrMM.SV.MemberRolesDpsColor.b, FyrMM.SV.MemberRolesDpsColor.a)
					if tag ~= "companion" and FyrMM.SV.ShowGroupLabels and groupLabel then
						groupLabel:SetColor(FyrMM.SV.MemberRolesDpsColor.r, FyrMM.SV.MemberRolesDpsColor.g, FyrMM.SV.MemberRolesDpsColor.b, FyrMM.SV.MemberRolesDpsColor.a) 
					end
				elseif pin.isHeal then
					pin:SetColor(FyrMM.SV.MemberRolesHealColor.r, FyrMM.SV.MemberRolesHealColor.g, FyrMM.SV.MemberRolesHealColor.b, FyrMM.SV.MemberRolesHealColor.a)
					if tag ~= "companion" and FyrMM.SV.ShowGroupLabels and groupLabel then
						groupLabel:SetColor(FyrMM.SV.MemberRolesHealColor.r, FyrMM.SV.MemberRolesHealColor.g, FyrMM.SV.MemberRolesHealColor.b, FyrMM.SV.MemberRolesHealColor.a) 
					end
				elseif pin.isTank then
					pin:SetColor(FyrMM.SV.MemberRolesTankColor.r, FyrMM.SV.MemberRolesTankColor.g, FyrMM.SV.MemberRolesTankColor.b, FyrMM.SV.MemberRolesTankColor.a)
					if tag ~= "companion" and FyrMM.SV.ShowGroupLabels and groupLabel then
						groupLabel:SetColor(FyrMM.SV.MemberRolesTankColor.r, FyrMM.SV.MemberRolesTankColor.g, FyrMM.SV.MemberRolesTankColor.b, FyrMM.SV.MemberRolesTankColor.a) 
					end
				end
            end
        elseif FyrMM.SV.MemberPinColor ~= nil and FyrMM.SV.MemberDeadPinColor ~= nil then -- pins colored by leader / group members
            if isDead then
                pin:SetColor(FyrMM.SV.MemberDeadPinColor.r, FyrMM.SV.MemberDeadPinColor.g, FyrMM.SV.MemberDeadPinColor.b, FyrMM.SV.MemberDeadPinColor.a)
                if tag ~= "companion" and FyrMM.SV.ShowGroupLabels and groupLabel then
                    groupLabel:SetColor(FyrMM.SV.MemberDeadPinColor.r, FyrMM.SV.MemberDeadPinColor.g, FyrMM.SV.MemberDeadPinColor.b, FyrMM.SV.MemberDeadPinColor.a) 
                end
            else
                pin:SetColor(FyrMM.SV.MemberPinColor.r, FyrMM.SV.MemberPinColor.g, FyrMM.SV.MemberPinColor.b, FyrMM.SV.MemberPinColor.a)
                if tag ~= "companion" and FyrMM.SV.ShowGroupLabels and groupLabel then
                    groupLabel:SetColor(FyrMM.SV.MemberPinColor.r, FyrMM.SV.MemberPinColor.g, FyrMM.SV.MemberPinColor.b, FyrMM.SV.MemberPinColor.a)
                end
            end
        else 
		    if FyrMM.SV.ShowGroupLabels and groupLabel then
               groupLabel:SetColor(255, 255, 255, 255)
			end   
        end
    end

    pin.noZoomResize = true
    pin.ClassId = GetUnitClassId(tag)
    pin.nX = nX
    pin.nY = nY
    pin.unitTag = tag

    -- 02/07/2026 optimization: Dropped a redundant IsUnitOnline(tag) check here - already
    -- guaranteed true by the early-return guard at the top of this function.
    if IsUnitActivelyEngaged(tag) and FyrMM.SV.InCombatState and not isDead then -- IsUnitActivelyEngaged instead of IsUnitInCombat to get individual combat state instead of group combat state
        pin_ic.nX = nX
        pin_ic.nY = nY
        pin_ic:SetHidden(false)

        if pin.isLeader then
            pin_ic:SetAlpha(0.66)
        else
            pin_ic:SetColor(255, 0, 0, 0.5)
        end

        FyrMM.SetPinAnchor(pin_ic, nX, nY, Fyr_MM_Scroll_Map_GroupPins)
    else
        PinsList["Fyr_MM_Scroll_Map_GroupPins_"..tag.."_incombat"] = nil
        pin_ic.nX = nil
        pin_ic.nY = nil
        -- pin_ic:SetColor(0,0,0,0)
        pin_ic:SetHidden(true)
        pin_ic:ClearAnchors()
    end

    if tag ~= "companion" then
        if FyrMM.SV.ShowGroupLabels and groupLabel then
		        groupLabel:SetFont(FyrMM.Fonts["Univers 57"].."|".."18".."|".."outline")
            groupLabel:SetText(groupLabel.index)
            groupLabel:SetHidden(false)
			      groupLabel:ClearAnchors()
			      groupLabel:SetAnchor(TOP, pin, BOTTOM, 0, -5)
			      groupLabel:SetDrawLevel(ZO_MapPin.PIN_DATA[pin.m_PinType].level) 
	          groupLabel:SetDrawLayer(4) 
			      groupLabel:SetDrawTier(DT_HIGH)
        else
            if groupLabel then  
               groupLabel:SetText("")
               groupLabel:SetHidden(true)
            end
        end
    end

    if IsUnitActivelyEngaged(tag) then
        pin.engaged = true
    else
        pin.engaged = false
    end

    if OSI and not OSI.isFakeOSIStub then -- support for OdySupportIcons
        local OPTIONS = OPTIONS or ZO_SavedVars:NewAccountWide("OSIStore", 1, nil, DEFAULT)
        local wmConfig = {
            ["dead"] = OPTIONS.wmdead,
            ["mechanic"] = false,
            ["raid"] = OPTIONS.raidallow,
            ["leader"] = OPTIONS.wmroles,
            ["tank"] = OPTIONS.wmroles,
            ["healer"] = OPTIONS.wmroles,
            ["dps"] = OPTIONS.wmroles,
            ["bg"] = OPTIONS.wmroles,
            ["custom"] = OPTIONS.wmuse,
            ["unique"] = OPTIONS.wmunique,
            ["anim"] = false
        }

        local tex, col, _, hodor = OSI.GetIconDataForPlayer(GetUnitDisplayName(tag), wmConfig, tag)
        if tex then
            FyrMM.SetGroupPinTexture(pin, tex)
            if col then
                pin:SetColor(col[1], col[2], col[3], 1)
                pin.color = col
            else
			          pin:SetColor(1, 1, 1, 1)
                pin.color = {1, 1, 1, 1}
			      end
        else
            FyrMM.SetGroupPinTexture(pin)
        end
    else
        FyrMM.SetGroupPinTexture(pin)
    end
	
	-- Apply target marker colors to Mounted, Stealthed, Swimming group pins
	if FyrMM.GetTargetMarkerColor(pin.unitTag) and (not pin.engaged) and (pin.isMounted or pin.isStealthed or pin.isSwimming or pin.isDisguised) then
	   pin.color = FyrMM.GetTargetMarkerColor(pin.unitTag)
	   pin:SetColor(pin.color[1], pin.color[2], pin.color[3], pin.color[4])
	end


    FyrMM.SetPinSize(pin_ic, pin:GetDesiredHeight() + 10, 0) -- +6

    pin:SetDrawLayer(3)
    pin:SetDrawLevel(ZO_MapPin.PIN_DATA[pin.m_PinType].level)
    pin_ic:SetDrawLayer(2)

    pin:SetMouseEnabled(true)
    FyrMM.SetPinAnchor(pin, nX, nY, Fyr_MM_Scroll_Map_GroupPins)
    PinsList["Fyr_MM_Scroll_Map_GroupPins_" .. tag .. "_incombat"] = nil

    if FyrMM.SV.WheelMap then
        pin:SetHidden(not FyrMM.Is_PinInsideWheel(pin))
    else
        pin:SetHidden(false) 
    end

    if FyrMM.IsValidBorderPin(pin) then
        FyrMM.CreateBorderPin(pin)
    end
end

function FyrMM.ClearGroupPins()

    for i = 1, 24 do
      local tag = "group"..i -- GetGroupUnitTagByIndex returns nil when not grouped anymore
		  if tag then
			local pin = GetControl("Fyr_MM_Scroll_Map_GroupPins_"..tag)
			local pin_ic = GetControl("Fyr_MM_Scroll_Map_GroupPins_"..tag.."_incombat")
			local groupLabel = GetControl("Fyr_MM_Scroll_Map_GroupPins_"..tag.."_label")
			
			if pin ~= nil then
				pin:SetHidden(true)
				pin:SetMouseEnabled(false)
				pin:ClearAnchors()
				pin.isDps = nil
				pin.isHeal = nil
				pin.isTank = nil
				pin.ClassId = nil
				pin.isLeader = nil
				pin.isBreadcrumb = nil
				pin.nX = nil
				pin.nY = nil
				PinsList["Fyr_MM_Scroll_Map_GroupPins_"..tag] = nil

				if pin.OnBorder then
					if pin.BorderPin then
						pin.BorderPin:ClearAnchors()
						pin.BorderPin:SetHidden(true)
						pin.BorderPin.pin = nil
						pin.BorderPin = nil
					end
					pin.OnBorder = nil
				end
			end
			
			if pin_ic ~= nil then
			   	pin_ic.nX = nil
				pin_ic.nY = nil
				pin_ic:SetHidden(true)
				pin_ic:ClearAnchors()
				PinsList["Fyr_MM_Scroll_Map_GroupPins_"..tag.."_incombat"] = nil
			end
			
			if groupLabel ~= nil then
			   groupLabel.nX = nil
			   groupLabel.nY = nil
			   groupLabel:SetHidden(true)
			   groupLabel:ClearAnchors()
			   PinsList["Fyr_MM_Scroll_Map_GroupPins_"..tag.."_label"] = nil
			end
		end
    end

    if not DoesUnitExist("companion") then
        local pin = GetControl("Fyr_MM_Scroll_Map_GroupPins_companion")
        local pin_ic = GetControl("Fyr_MM_Scroll_Map_GroupPins_companion_incombat")
        if pin ~= nil then
            pin:SetHidden(true)
            pin:SetMouseEnabled(false)
            pin:ClearAnchors()
            pin.isDps = nil
            pin.isHeal = nil
            pin.isTank = nil
            pin.ClassId = nil
            pin.isLeader = nil
            pin.isBreadcrumb = nil
            pin.nX = nil
            pin.nY = nil
            pin_ic.nX = nil
            pin_ic.nY = nil
            pin_ic:SetHidden(true)
            pin_ic:ClearAnchors()
            PinsList["Fyr_MM_Scroll_Map_GroupPins_companion"] = nil
            PinsList["Fyr_MM_Scroll_Map_GroupPins_companion_incombat"] = nil
            if pin.OnBorder then
                if pin.BorderPin then
                    pin.BorderPin:ClearAnchors()
                    pin.BorderPin:SetHidden(true)
                    pin.BorderPin.pin = nil
                    pin.BorderPin = nil
                end
                pin.OnBorder = nil
            end
        end
    end
end

function FyrMM.RefreshGroup()
    if (not FyrMM.GroupRefreshNeeded and not IsCompanionAround) or Fyr_MM:IsHidden() then
        return
    end
	
    -- 02/07/2026 optimization: Bound the loop by the actual group size instead of the fixed raid-size
    -- constant (24), which was forcing up to 24 GetGroupUnitTagByIndex calls every 40ms (25x/sec)
    -- even for small groups or solo play. Real group sizes are almost always far below the cap.
    local tag, pin, pin_ic, groupLabel
	  local groupSize = GetGroupSize()
	  local noGroup = groupSize == 0
	  local companion = DoesUnitExist("companion")
	

    if noGroup and not companion then
	      FyrMM.GroupRefreshNeeded = false
        FyrMM.ClearGroupPins()
        return
    end
	
	  if noGroup then
	     FyrMM.ClearGroupPins()
    end
	
    if not noGroup and not companion then -- fix for companion icons staying when he/she leaves while grouped
        local pin = GetCachedGroupControl("Fyr_MM_Scroll_Map_GroupPins_companion")
        local pin_ic = GetCachedGroupControl("Fyr_MM_Scroll_Map_GroupPins_companion_incombat")
        if pin ~= nil then
            pin:SetHidden(true)
            pin:SetMouseEnabled(false)
            pin:ClearAnchors()
            pin.isDps = nil
            pin.isHeal = nil
            pin.isTank = nil
            pin.ClassId = nil
            pin.isLeader = nil
            pin.isBreadcrumb = nil
            pin.nX = nil
            pin.nY = nil
            pin_ic.nX = nil
            pin_ic.nY = nil
            pin_ic:SetHidden(true)
            pin_ic:ClearAnchors()
            PinsList["Fyr_MM_Scroll_Map_GroupPins_companion"] = nil
            PinsList["Fyr_MM_Scroll_Map_GroupPins_companion_incombat"] = nil
            if pin.OnBorder then
                if pin.BorderPin then
                    pin.BorderPin:ClearAnchors()
                    pin.BorderPin:SetHidden(true)
                    pin.BorderPin.pin = nil
                    pin.BorderPin = nil
                end
                pin.OnBorder = nil
            end
        end
    end

    
    -- 02/07/2026 optimization: Only capture the debug-profiling timestamp when DebugMode is
    -- actually on, instead of calling GetGameTimeMilliseconds() unconditionally every 40ms tick
    -- for a value that's discarded for virtually every user, who has DebugMode off by default.
    local gameTime = FyrMM.DebugMode and GetGameTimeMilliseconds() or nil

    for index = 1, groupSize do
        if FyrMM.Reloading then
            return
        end
        tag = GetGroupUnitTagByIndex(index) 
        if tag then
          groupLabel = GetCachedGroupControl("Fyr_MM_Scroll_Map_GroupPins_"..tag.."_label")
          
          if groupLabel then
             groupLabel.index = tostring(index)
          end
          FyrMM.SetGroupPin(tag)
        end
    end

    if companion then 
        tag = "companion"
        local companionPinName = "Fyr_MM_Scroll_Map_GroupPins_"..tag
        local companionInCombatName = "Fyr_MM_Scroll_Map_GroupPins_"..tag.."_incombat"
        if GetCachedGroupControl(companionPinName) == nil then
            pin = WINDOW_MANAGER:CreateControl(companionPinName, Fyr_MM_Scroll_Map_GroupPins, CT_TEXTURE)
            pin:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
            pin:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
            GroupPinControls[companionPinName] = pin
        end
        if GetCachedGroupControl(companionInCombatName) == nil then
            pin_ic = WINDOW_MANAGER:CreateControl(companionInCombatName, Fyr_MM_Scroll_Map_GroupPins, CT_TEXTURE)
            pin_ic:SetTexture("esoui/art/mappins/ava_attackburst_32.dds")
            pin_ic:SetColor(255, 0, 0, 0.5)
            GroupPinControls[companionInCombatName] = pin_ic
        end
        FyrMM.SetGroupPin(tag)
    end

    if FyrMM.DebugMode and gameTime then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "FyrMM.RefreshGroup "..tostring(GetGameTimeMilliseconds() - gameTime))
    end
end

---------------------------------------------------
-- Quest pin updates
---------------------------------------------------
function FyrMM.GetQuestPinInfo(pinType, isassited, isBreadcrumb, radius)
    if radius == nil then
        radius = 0
    end
    local mWidth, mHeight = Fyr_MM_Scroll_Map:GetDimensions()
    local Diameter = radius * 2 * mHeight
    local texture
    if Diameter < 16 then
        Diameter = 16
    end
    local properType, properTexture
    if (pinType == MAP_PIN_TYPE_ASSISTED_QUEST_CONDITION or pinType == MAP_PIN_TYPE_TRACKED_QUEST_CONDITION) then
        if isassited then
            properType = MAP_PIN_TYPE_ASSISTED_QUEST_CONDITION
        else
            properType = MAP_PIN_TYPE_TRACKED_QUEST_CONDITION
        end
    end
    if (pinType == MAP_PIN_TYPE_ASSISTED_QUEST_OPTIONAL_CONDITION or pinType ==
            MAP_PIN_TYPE_TRACKED_QUEST_OPTIONAL_CONDITION) then
        if isassited then
            properType = MAP_PIN_TYPE_ASSISTED_QUEST_OPTIONAL_CONDITION
        else
            properType = MAP_PIN_TYPE_TRACKED_QUEST_OPTIONAL_CONDITION
        end
    end
    if (pinType == MAP_PIN_TYPE_ASSISTED_QUEST_ENDING or pinType == MAP_PIN_TYPE_TRACKED_QUEST_ENDING) then
        if isassited then
            properType = MAP_PIN_TYPE_ASSISTED_QUEST_ENDING
        else
            properType = MAP_PIN_TYPE_TRACKED_QUEST_ENDING
        end
    end
    if properType == nil then
        properType = pinType
    end
    if radius == 0 then
        texture = isBreadcrumb and breadcrumbQuestPinTextures[properType] or questPinTextures[properType]
        return properType, texture, 32 * FyrMM.pScalePercent
    else
        if Diameter > 24 then
            texture = isassited and "EsoUI/Art/MapPins/map_assistedAreaPin.dds" or "EsoUI/Art/MapPins/map_areaPin.dds"
            return properType, texture, Diameter, true
        else
            texture = isassited and "EsoUI/Art/MapPins/map_assistedAreaPin_32.dds" or "EsoUI/Art/MapPins/map_areaPin_32.dds"
            return properType, texture, Diameter, true
        end
    end
end

function FyrMM.ApplyProperQuestPinTextures() -- Discrepancy fix
    local questPin, pinType

    local function applyTextures(index, a)
        questPin = GetControl("Fyr_MM_Scroll_Map_QuestPins_Pin" .. tostring(a))
        if questPin == nil or questPin.questIndex ~= index or questPin:IsHidden(true) or IsAssisted(questPin.m_PinType) == FyrMM.GetQuestPinInfo(GetTrackedByIndex(index)) then
            return
        end
        local properType, pinTexture, size =
            FyrMM.GetQuestPinInfo(questPin.m_PinType, GetTrackedIsAssisted(TRACK_TYPE_QUEST, questPin.questIndex), questPin.m_PinTag.isBreadcrumb, questPin.radius)
        questPin.m_PinType = properType
        questPin:SetTexture(pinTexture)
        FyrMM.SetPinSize(questPin, size, 0)
        local drawLayerIndex = GetTrackedIsAssisted(TRACK_TYPE_QUEST, questPin.questIndex) and 3 or 2
        questPin:SetDrawLayer(drawLayerIndex)
    end

    for index = 1, MAX_JOURNAL_QUESTS do
        if (IsValidQuestIndex(index)) then
            for a = 1, FyrMM.questPinCount do
                applyTextures(index, a)
            end
        end
    end
end

local function UpdateQuestPinPosition(questPin)
    if questPin == nil then
        return
    end

    if questPin.MapId ~= CurrentMap.MapId or questPin.m_PinTag == nil then
        questPin:SetHidden(true)
        questPin:ClearAnchors()
        return
    end

    local properType, pinTexture, size = FyrMM.GetQuestPinInfo(questPin.m_PinType, GetTrackedIsAssisted(TRACK_TYPE_QUEST, questPin.questIndex), questPin.m_PinTag.isBreadcrumb, questPin.radius)

    questPin.m_PinType = properType
    questPin:SetTexture(pinTexture)
    FyrMM.SetPinSize(questPin, size, 0)
    questPin:SetHidden(not ZO_WorldMap_IsPinGroupShown(MAP_FILTER_QUESTS))

    local drawLayerIndex = GetTrackedIsAssisted(TRACK_TYPE_QUEST, questPin.questIndex) and 3 or 2
    questPin:SetDrawLayer(drawLayerIndex)

    FyrMM.SetPinAnchor(questPin, questPin.normalizedX, questPin.normalizedY, Fyr_MM_Scroll_Map_QuestPins)
    if FyrMM.SV.WheelMap and questPin.radius > 0 and questPin.MM_Tag == nil then
        questPin:SetParent(Fyr_MM_Scroll_CW_Map_Pins)
    elseif questPin.MM_Tag == 1 and not FyrMM.SV.WheelMap then
        questPin:SetParent(Fyr_MM_Scroll_Map_QuestPins)
    elseif questPin.MM_Tag == 1 and questPin.radius > 0 then
        questPin:SetParent(Fyr_MM_Scroll_CW_Map_Pins)
        if questPin.secondaryPin then
            questPin.secondaryPin:SetTexture(pinTexture)
        end
        if questPin.tertiaryPin then
            questPin.tertiaryPin:SetTexture(pinTexture)
        end
    elseif questPin.MM_Tag == 2 then
        questPin:SetParent(Fyr_MM_Scroll_NS_Map_Pins)
    elseif questPin.MM_Tag == 3 then
        questPin:SetParent(Fyr_MM_Scroll_WE_Map_Pins)
    elseif questPin.MM_Tag then
        questPin.MM_Tag = nil
        questPin:SetParent(Fyr_MM_Scroll_Map_QuestPins)
    end

    if FyrMM.IsValidBorderPin(questPin) then
        FyrMM.CreateBorderPin(questPin)
    end
end

function FyrMM.UpdateQuestPinPositions()
    if QuestPinsUpdating then
        return
    end
    for _, v in pairs(QuestPins) do
        UpdateQuestPinPosition(v.Pin)
        if v.Pin.secondaryPin then
            UpdateQuestPinPosition(v.Pin.secondaryPin)
        end
        if v.Pin.tertiaryPin then
            UpdateQuestPinPosition(v.Pin.tertiaryPin)
        end
    end
end

function FyrMM.PlayTextureAnimation(pin, framesWide, framesHigh, framesPerSecond, loopCount, playbackType) -- ZOSanimation revisited for the minimap
    if pin.m_textureAnimTimeline == "yes" then
        local animation
        animation, pin.m_textureAnimTimeline = CreateSimpleAnimation(ANIMATION_TEXTURE, pin)
        animation:SetImageData(framesWide, framesHigh)
        animation:SetFramerate(framesPerSecond)
        animation:SetHandler("OnStop", function()
            pin:SetTextureCoords(0, 1, 0, 1)
        end)
	    pin.m_textureAnimTimeline:SetPlaybackType(playbackType, loopCount)
        pin.m_textureAnimTimeline:PlayFromStart()	
    end

end

function FyrMM.ResetAnimation(pin, resetOptions, loopCount, pulseIcon, overlayIcon, postPulseCallback, min, max) -- ZOSanimation, I don't know the use... 
    resetOptions = resetOptions or ZO_MapPin.ANIM_CONSTANTS.RESET_ANIM_PREVENT_PLAY

    -- The animated control
    local pulseControl = pin

    if resetOptions == ZO_MapPin.ANIM_CONSTANTS.RESET_ANIM_ALLOW_PLAY then
        pulseControl:SetHidden(pulseIcon == nil)
        if pulseIcon then
            pulseControl:SetTexture(pulseIcon)
            postPulseCallback = postPulseCallback or ZO_MapPin.DoFinalFadeOutAfterPing
            ZO_AlphaAnimation_GetAnimation(pulseControl):PingPong(.3, 1, 750, loopCount, postPulseCallback)
        end
    elseif resetOptions == ZO_MapPin.ANIM_CONSTANTS.RESET_ANIM_HIDE_CONTROL then
        ZO_AlphaAnimation_GetAnimation(pulseControl):Stop()
        pulseControl:SetHidden(true)
        pulseControl:StopTextureAnimation()
    elseif resetOptions == ZO_MapPin.ANIM_CONSTANTS.RESET_ANIM_PREVENT_PLAY then
        ZO_AlphaAnimation_GetAnimation(pulseControl):FadeOut(0, 300, ZO_ALPHA_ANIMATION_OPTION_USE_CURRENT_ALPHA,
            ZO_MapPin.HidePulseAfterFadeOut)
    end
end

local function CreateQuestAreaSidePins(pin, assisted)
    local index
    local properType, pinTexture, size = FyrMM.GetQuestPinInfo(pinType,
        GetTrackedIsAssisted(TRACK_TYPE_QUEST, pin.m_PinTag[1]), pin.m_PinTag.isBreadcrumb, pin.radius)
    FyrMM.questPinCount = FyrMM.questPinCount + 1
    local questPinNS
    index = GetQuestFreePinIndex()
    questPinNS = GetControl("Fyr_MM_Scroll_Map_QuestPins_Pin" .. tostring(index))
    if questPinNS == nil then
        questPinNS = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_QuestPins_Pin" .. tostring(index),
            Fyr_MM_Scroll_NS_Map_Pins, CT_TEXTURE)
    else
        questPinNS:SetParent(Fyr_MM_Scroll_NS_Map_Pins)
    end
    questPinNS.m_PinTag = pin.m_PinTag
    questPinNS.questIndex = pin.questIndex
    questPinNS.m_PinType = properType
    questPinNS.PinToolTipText = pin.PinToolTipText
    questPinNS.questName = pin.questName
    questPinNS.normalizedX = pin.normalizedX
    questPinNS.normalizedY = pin.normalizedY
    questPinNS.radius = pin.radius
    questPinNS.MapId = pin.MapId
    questPinNS:SetTexture(pinTexture)
    -- FyrMM.SetPinSize(questPinNS, size, 0)
    questPinNS:SetDimensions(size, size)
    questPinNS.pinAge = pin.pinAge
    questPinNS:SetHidden(not ZO_WorldMap_IsPinGroupShown(MAP_FILTER_QUESTS))
    questPinNS.MM_Tag = 2
    questPinNS.primaryPin = pin
    pin.secondaryPin = questPinNS

    if assisted then
        local assistedColor = ZO_MAP_PIN_ASSISTED_COLOR
        questPinNS:SetColor(assistedColor:UnpackRGBA())
    else
        local color = ZO_MAP_PIN_NORMAL_COLOR
        questPinNS:SetColor(color:UnpackRGBA())
    end

    questPinNS:SetDrawLayer(3)

    FyrMM.SetPinAnchor(questPinNS, questPinNS.normalizedX, questPinNS.normalizedY, Fyr_MM_Scroll_Map_QuestPins)
    questPinNS:SetHandler("OnMouseUp", PinOnMouseUp)
    questPinNS:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
    questPinNS:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)

    FyrMM.questPinCount = FyrMM.questPinCount + 1
    local questPinWE
    index = GetQuestFreePinIndex()
    questPinWE = GetControl("Fyr_MM_Scroll_Map_QuestPins_Pin" .. tostring(index))
    if questPinWE == nil then
        questPinWE = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_QuestPins_Pin" .. tostring(index),
            Fyr_MM_Scroll_WE_Map_Pins, CT_TEXTURE)
    else
        questPinWE:SetParent(Fyr_MM_Scroll_WE_Map_Pins)
    end
    questPinWE.m_PinTag = pin.m_PinTag
    questPinWE.questIndex = pin.questIndex
    questPinWE.m_PinType = properType
    questPinWE.PinToolTipText = pin.PinToolTipText
    questPinWE.questName = pin.questName
    questPinWE.normalizedX = pin.normalizedX
    questPinWE.normalizedY = pin.normalizedY
    questPinWE.radius = pin.radius
    questPinWE.MapId = pin.MapId
    questPinWE:SetTexture(pinTexture)
    -- FyrMM.SetPinSize(questPinWE, size, 0)
    questPinWE:SetDimensions(size, size)
    questPinWE.pinAge = pin.pinAge
    questPinWE:SetHidden(not ZO_WorldMap_IsPinGroupShown(MAP_FILTER_QUESTS))
    questPinWE.MM_Tag = 3
    questPinWE.primaryPin = pin
    pin.tertiaryPin = questPinWE

    if assisted then
        local assistedColor = ZO_MAP_PIN_ASSISTED_COLOR
        questPinWE:SetColor(assistedColor:UnpackRGBA())
    else
        local color = ZO_MAP_PIN_NORMAL_COLOR
        questPinWE:SetColor(color:UnpackRGBA())
    end
    questPinWE:SetDrawLayer(3)
    FyrMM.SetPinAnchor(questPinWE, questPinWE.normalizedX, questPinWE.normalizedY, Fyr_MM_Scroll_Map_QuestPins)
    questPinWE:SetHandler("OnMouseUp", PinOnMouseUp)
    questPinWE:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
    questPinWE:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
end

function FyrMM.CreateSuggestedAreaSidePins(pin, radius)
    local index = pin.Index
    local properType, pinTexture, size = FyrMM.GetQuestPinInfo(pin.m_PinType, false, false, radius)

    local suggestedPinNS
    suggestedPinNS = GetControl("Fyr_MM_Scroll_Map_Pins_Pin"..tostring(index).."_NS")
    if suggestedPinNS == nil then
        suggestedPinNS = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_Pins_Pin"..tostring(index).."_NS", Fyr_MM_Scroll_NS_Map_Pins, CT_TEXTURE)
    else
        suggestedPinNS:SetParent(Fyr_MM_Scroll_NS_Map_Pins)
    end
    suggestedPinNS.m_PinTag = pin.m_PinTag
    suggestedPinNS.questIndex = pin.questIndex
    suggestedPinNS.m_PinType = pin.m_PinType
    suggestedPinNS.PinToolTipText = pin.PinToolTipText
    suggestedPinNS.questName = pin.questName
    suggestedPinNS.normalizedX = pin.nX
    suggestedPinNS.normalizedY = pin.nY
    suggestedPinNS.radius = pin.radius
    suggestedPinNS.MapId = pin.MapId
    suggestedPinNS:SetTexture(pinTexture)
    suggestedPinNS:SetDimensions(size, size)
    suggestedPinNS.pinAge = pin.pinAge
    suggestedPinNS:SetHidden(false)
    suggestedPinNS.MM_Tag = 2
    suggestedPinNS.primaryPin = pin
    pin.secondaryPin = suggestedPinNS

    local color = ZO_MAP_PIN_NORMAL_COLOR
    suggestedPinNS:SetColor(color:UnpackRGBA())
    suggestedPinNS:SetDrawLayer(3)

    FyrMM.SetPinAnchor(suggestedPinNS, suggestedPinNS.normalizedX, suggestedPinNS.normalizedY, Fyr_MM_Scroll_NS_Map_Pins) -- Fyr_MM_Scroll_Map_QuestPins
    suggestedPinNS:SetHandler("OnMouseUp", PinOnMouseUp)
    suggestedPinNS:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
    suggestedPinNS:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)

    local suggestedPinWE
    suggestedPinWE = GetControl("Fyr_MM_Scroll_Map_Pins_Pin" .. tostring(index) .. "_WE")
    if suggestedPinWE == nil then
        suggestedPinWE = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_Pins_Pin"..tostring(index).."_WE", Fyr_MM_Scroll_WE_Map_Pins, CT_TEXTURE)
    else
        suggestedPinWE:SetParent(Fyr_MM_Scroll_WE_Map_Pins)
    end
    suggestedPinWE.m_PinTag = pin.m_PinTag
    suggestedPinWE.questIndex = pin.questIndex
    suggestedPinWE.m_PinType = pin.m_PinType
    suggestedPinWE.PinToolTipText = pin.PinToolTipText
    suggestedPinWE.questName = pin.questName
    suggestedPinWE.normalizedX = pin.nX
    suggestedPinWE.normalizedY = pin.nY
    suggestedPinWE.radius = pin.radius
    suggestedPinWE.MapId = pin.MapId
    suggestedPinWE:SetTexture(pinTexture)
    suggestedPinWE:SetDimensions(size, size)
    suggestedPinWE.pinAge = pin.pinAge
    suggestedPinWE:SetHidden(false)
    suggestedPinWE.MM_Tag = 3
    suggestedPinWE.primaryPin = pin
    pin.tertiaryPin = suggestedPinWE

    local color = ZO_MAP_PIN_NORMAL_COLOR
    suggestedPinWE:SetColor(color:UnpackRGBA())
    suggestedPinWE:SetDrawLayer(3)

    FyrMM.SetPinAnchor(suggestedPinWE, suggestedPinWE.normalizedX, suggestedPinWE.normalizedY, Fyr_MM_Scroll_WE_Map_Pins) --Fyr_MM_Scroll_Map_QuestPins
    suggestedPinWE:SetHandler("OnMouseUp", PinOnMouseUp)
    suggestedPinWE:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
    suggestedPinWE:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
end

local function CreateForwardCampAreaSidePins(pin, size, usable)
    local pinTexture = "esoui/art/mappins/map_areapin.dds"

    local ForwardCampPinNS
    ForwardCampPinNS = GetControl("Fyr_MM_Scroll_Map_ForwardCamps_Pin"..tostring(FyrMM.currentForwardCamps).."_Blob".."_NS")
    if ForwardCampPinNS == nil then
        ForwardCampPinNS = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_ForwardCamps_Pin"..tostring(FyrMM.currentForwardCamps).."_Blob".."_NS", Fyr_MM_Scroll_NS_Map_Pins, CT_TEXTURE)
    else
        ForwardCampPinNS:SetParent(Fyr_MM_Scroll_NS_Map_Pins)
    end

    ForwardCampPinNS.m_PinTag = pin.m_PinTag
    ForwardCampPinNS.questIndex = pin.questIndex
    ForwardCampPinNS.m_PinType = pin.m_PinType
    ForwardCampPinNS.PinToolTipText = pin.PinToolTipText
    ForwardCampPinNS.questName = pin.questName
    ForwardCampPinNS.normalizedX = pin.normalizedX
    ForwardCampPinNS.normalizedY = pin.normalizedY
    ForwardCampPinNS.radius = pin.radius
    ForwardCampPinNS.MapId = pin.MapId
    ForwardCampPinNS:SetTexture(pinTexture)
    -- FyrMM.SetPinSize(ForwardCampPinNS, size, 0)
    ForwardCampPinNS:SetDimensions(size, size)
    ForwardCampPinNS.pinAge = pin.pinAge
    ForwardCampPinNS:SetHidden(not usable)
    ForwardCampPinNS.MM_Tag = 2
    ForwardCampPinNS.primaryPin = pin
    pin.secondaryPin = ForwardCampPinNS

    local color = ZO_MAP_PIN_NORMAL_COLOR
    ForwardCampPinNS:SetColor(color:UnpackRGBA())
    ForwardCampPinNS:SetDrawLayer(3)

    FyrMM.SetPinAnchor(ForwardCampPinNS, ForwardCampPinNS.normalizedX, ForwardCampPinNS.normalizedY, Fyr_MM_Scroll_Map_Pins) -- Fyr_MM_Scroll_Map_QuestPins
    ForwardCampPinNS:SetHandler("OnMouseUp", PinOnMouseUp)
    ForwardCampPinNS:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
    ForwardCampPinNS:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)

    local ForwardCampPinWE
    ForwardCampPinWE = GetControl(
        "Fyr_MM_Scroll_Map_ForwardCamps_Pin"..tostring(FyrMM.currentForwardCamps).."_Blob".."_WE")
    if ForwardCampPinWE == nil then
        ForwardCampPinWE = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_ForwardCamps_Pin"..tostring(FyrMM.currentForwardCamps).."_Blob".."_WE",
        Fyr_MM_Scroll_WE_Map_Pins, CT_TEXTURE)
    else
        ForwardCampPinWE:SetParent(Fyr_MM_Scroll_WE_Map_Pins)
    end
    ForwardCampPinWE.m_PinTag = pin.m_PinTag
    ForwardCampPinWE.questIndex = pin.questIndex
    ForwardCampPinWE.m_PinType = pin.m_PinType
    ForwardCampPinWE.PinToolTipText = pin.PinToolTipText
    ForwardCampPinWE.questName = pin.questName
    ForwardCampPinWE.normalizedX = pin.normalizedX
    ForwardCampPinWE.normalizedY = pin.normalizedY
    ForwardCampPinWE.radius = pin.radius
    ForwardCampPinWE.MapId = pin.MapId
    ForwardCampPinWE:SetTexture(pinTexture)
    -- FyrMM.SetPinSize(ForwardCampPinWE, size, 0)
    ForwardCampPinWE:SetDimensions(size, size)
    ForwardCampPinWE.pinAge = pin.pinAge
    ForwardCampPinWE:SetHidden(not usable)
    ForwardCampPinWE.MM_Tag = 3
    ForwardCampPinWE.primaryPin = pin
    pin.tertiaryPin = ForwardCampPinWE

    ForwardCampPinWE:SetColor(color:UnpackRGBA())
    ForwardCampPinWE:SetDrawLayer(3)
    FyrMM.SetPinAnchor(ForwardCampPinWE, ForwardCampPinWE.normalizedX, ForwardCampPinWE.normalizedY,Fyr_MM_Scroll_Map_Pins) -- Fyr_MM_Scroll_Map_QuestPins
    ForwardCampPinWE:SetHandler("OnMouseUp", PinOnMouseUp)
    ForwardCampPinWE:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
    ForwardCampPinWE:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
end

local function QuestPinExists(pinType, tag, xLoc, yLoc, radius)
	local numDuplicates = 0
    for i, v in pairs(QuestPins) do
        if v.Pin ~= nil then
            if v.Pin.m_PinTag then
                if v.Pin.m_PinTag[1] == tag[1] and v.Pin.m_PinTag[2] == tag[2] and v.Pin.m_PinTag[3] == tag[3] and v.Pin.m_PinType == pinType and v.Pin.radius == radius and v.Pin.normalizedX == xLoc and v.Pin.normalizedY == yLoc then
					         RemoveQuestPin(v.Pin)
				           numDuplicates = numDuplicates + 1
                end
            end
        end
    end
	return numDuplicates 
end

function FyrMM.CreateQuestPin(pinType, tag, xLoc, yLoc, radius)

    local numDuplicates = QuestPinExists(pinType, tag, xLoc, yLoc, radius) -- remove duplicates before creating a new quest pin
	
	FyrMM.questPinCount = FyrMM.questPinCount + 1
	local index = GetQuestFreePinIndex()
    
    local questPin
    local pinData = {}


    questPin = GetControl("Fyr_MM_Scroll_Map_QuestPins_Pin" .. tostring(index))

    if FyrMM.SV.WheelMap and radius > 0 then
        if questPin == nil then
            questPin = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_QuestPins_Pin" .. tostring(index),
                Fyr_MM_Scroll_CW_Map_Pins, CT_TEXTURE)
        else
            questPin:SetParent(Fyr_MM_Scroll_CW_Map_Pins)
        end
    else
        if questPin == nil then
            questPin = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_QuestPins_Pin" .. tostring(index),
                Fyr_MM_Scroll_Map_QuestPins, CT_TEXTURE)
        else
            questPin:SetParent(Fyr_MM_Scroll_Map_QuestPins)
        end
    end

    local properType, pinTexture, size, isAreaPin = FyrMM.GetQuestPinInfo(pinType, GetTrackedIsAssisted(TRACK_TYPE_QUEST, tag[1]), tag.isBreadcrumb, radius)
    pinType = properType
    questPin.m_PinTag = tag
    questPin.questIndex = tag[1]
    questPin.m_PinType = properType
    questPin.PinToolTipText = GenerateQuestConditionTooltipLine(tag[1], tag[3], tag[2])
    questPin.questName = GetJournalQuestName(tag[1])
    questPin.normalizedX = xLoc
    questPin.normalizedY = yLoc
    questPin.radius = radius
    questPin.MapId = CurrentMap.MapId

    questPin.pinAge = GetFrameTimeMilliseconds()

    pinData.questIndex = tag[1]
    pinData.questName = GetJournalQuestName(tag[1])
    pinData.conditionText = GenerateQuestConditionTooltipLine(tag[1], tag[3], tag[2])
    pinData.stepIndex = tag[3]
    pinData.conditionIndex = tag[2]
    pinData.pinIndex = index
    pinData.normalizedX = xLoc
    pinData.normalizedY = yLoc
    pinData.radius = radius
    pinData.isBreadcrumb = tag.isBreadcrumb
    pinData.isAssisted = GetTrackedIsAssisted(TRACK_TYPE_QUEST, tag[1])
    pinData.MapId = CurrentMap.MapId
    pinData.Pin = questPin
    pinData.tag = tag

    local questdataIndex = questpinDataExists(pinData, QuestPins)
    if questdataIndex == nil then
        table.insert(QuestPins, pinData)
        questdataIndex = questpinDataExists(pinData, QuestPins)
    else
        QuestPins[questdataIndex] = pinData
    end
    questPin.questdataIndex = questdataIndex
    local questPinData = ZOpinData[pinType]
    if questPinData ~= nil then
        local _, pulseTexture, glowTexture = GetPinTexture(pinType, questPin)

        questPin:SetTexture(pinTexture)

        FyrMM.SetPinSize(questPin, size, 0)

        if pulseTexture then
            FyrMM.ResetAnimation(questPin, ZO_MapPin.ANIM_CONSTANTS.RESET_ANIM_ALLOW_PLAY, ZO_MapPin.ANIM_CONSTANTS.LONG_LOOP_COUNT, pulseTexture, overlayTexture, ZO_MapPin.DoFinalFadeInAfterPing)
        else
            if glowTexture then
                FyrMM.ResetAnimation(questPin, ZO_MapPin.ANIM_CONSTANTS.RESET_ANIM_HIDE_CONTROL)
            end
        end
        questPin:SetDrawLevel(zo_max(questPinData.level, 1))
        if questPinData.isAnimated then -- ZOSanimation
            FyrMM.PlayTextureAnimation(questPin, questPinData.framesWide, questPinData.framesHigh, questPinData.framesPerSecond, LOOP_INDEFINITELY, ANIMATION_PLAYBACK_LOOP)
        end

        if FyrMM.SV.WheelMap and questPin.radius > 0 then
            questPin.MM_Tag = 1
            CreateQuestAreaSidePins(questPin, pinData.isAssisted)
        else
            if questPin.secondaryPin ~= nil then
                questPin.secondaryPin.MM_Tag = nil
                RemoveQuestPin(questPin.secondaryPin)
            end
            if questPin.tertiaryPin ~= nil then
                questPin.tertiaryPin.MM_Tag = nil
                RemoveQuestPin(questPin.tertiaryPin)
            end
            questPin.MM_Tag = nil
            questPin.primaryPin = nil
            questPin.secondaryPin = nil
            questPin.tertiaryPin = nil
            questPin:SetParent(Fyr_MM_Scroll_Map_QuestPins)
        end

        if questPinData.tint then -- compatibility with addons which modifies questpins colors
            if type(questPinData.tint) ~= "function" then
                questPin:SetColor(questPinData.tint:UnpackRGBA())
            else
                if questPin.m_Pin ~= nil then
                    questPin:SetColor(questPinData.tint(questPin.m_Pin):UnpackRGBA())
                else
                    questPin:SetColor(questPinData.tint(questPin):UnpackRGBA())
                end
            end
        else
            questPin:SetColor(1, 1, 1, 1)
        end

        if isAreaPin then -- apply modified areapin colors from other addons
            if pinData.isAssisted then
                local assistedColor = ZO_MAP_PIN_ASSISTED_COLOR
                questPin:SetColor(assistedColor:UnpackRGBA())
            else
                local color = ZO_MAP_PIN_NORMAL_COLOR
                questPin:SetColor(color:UnpackRGBA())
            end
        end

        questPin:SetHidden(not ZO_WorldMap_IsPinGroupShown(MAP_FILTER_QUESTS))
        FyrMM.SetPinAnchor(questPin, questPin.normalizedX, questPin.normalizedY, Fyr_MM_Scroll_Map_QuestPins)

        if FyrMM.IsValidBorderPin(questPin) then
            FyrMM.CreateBorderPin(questPin)
        end
        if GetTrackedIsAssisted(TRACK_TYPE_QUEST, tag[1]) then
            questPin:SetDrawLayer(3)
        else
            questPin:SetDrawLayer(2)
        end
        questPin:SetHandler("OnMouseUp", PinOnMouseUp)
        questPin:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
        questPin:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
        questPin:SetMouseEnabled(true)
    else
	    if questPin ~= nil then
		   RemoveQuestPin(questPin)
		end
	end
end

local function OnQuestPositionRequestComplete(eventCode, taskId, pinType, xLoc, yLoc, radius, insideCurrentMapWorld, isBreadcrumb)
    --	xLoc = zo_round(xLoc * 10000) / 10000
    --	yLoc = zo_round(yLoc * 10000) / 10000
    local tag = CurrentTasks[taskId]
    if (tag and insideCurrentMapWorld) then
        if CurrentTasks[taskId].Fetched then
            FyrMM.RequestQuestPinUpdate()  
            if CurrentTasks[taskId].MapId ~= CurrentMap.MapId then
                CurrentTasks[taskId] = nil
                return
            end
        else
            if CurrentTasks[taskId].ZO_MapVisible then
                return
            end
            local pinData = {}
            pinData.questIndex = tag[1]
            pinData.questName = GetJournalQuestName(tag[1])
            pinData.conditionText = GenerateQuestConditionTooltipLine(tag[1], tag[3], tag[2])
            pinData.stepIndex = tag[3]
            pinData.conditionIndex = tag[2]
            pinData.normalizedX = xLoc
            pinData.normalizedY = yLoc
            pinData.radius = radius
            pinData.isBreadcrumb = isBreadcrumb
            pinData.isAssisted = GetTrackedIsAssisted(TRACK_TYPE_QUEST, tag[1])
            pinData.MapId = CurrentMap.MapId
            pinData.tag = tag
            local requestedquestdataIndex = questpinDataExists(pinData, RequestedQuestPins)
            if requestedquestdataIndex == nil then
                table.insert(RequestedQuestPins, pinData)
            else
                RequestedQuestPins[requestedquestdataIndex] = pinData
            end
            pinData = {}
        end
        if tag.MapId == CurrentMap.MapId then
            tag.isBreadcrumb = isBreadcrumb
            FyrMM.CreateQuestPin(pinType, tag, xLoc, yLoc, radius)
        end
    else
        if isBreadcrumb then
            NeedQuestPinUpdate = true
        end
    end
    if tag then
        CurrentTasks[taskId] = nil
    end
    if ZO_IsTableEmpty(CurrentTasks) then
        QuestTasksPending = false
    else
        QuestTasksPending = true
    end
end

local function AddQuestPins(questIndex)
    if (ZO_WorldMap_IsPinGroupShown(MAP_FILTER_QUESTS)) then
        local assisted = GetTrackedIsAssisted(TRACK_TYPE_QUEST, questIndex)
        if GetJournalQuestIsComplete(questIndex) then
            local tag = ZO_MapPin.CreateQuestPinTag(questIndex, QUEST_MAIN_STEP_INDEX, 1)
            if not TaskExists(tag) then
                local taskId = FyrMM.RequestJournalQuestConditionAssistance(questIndex, QUEST_MAIN_STEP_INDEX, 1,
                    assisted)
                if taskId ~= nil then
                    FyrMM.LastQuestPinRequest = GetFrameTimeMilliseconds()
                    CurrentTasks[taskId] = {}
                    tag.MapId = CurrentMap.MapId
                    CurrentTasks[taskId] = tag
                    CurrentTasks[taskId].RequestTimeStamp = FyrMM.LastQuestPinRequest
                end
            end
        else
            for stepIndex = QUEST_MAIN_STEP_INDEX, GetJournalQuestNumSteps(questIndex) do
                for conditionIndex = 1, GetJournalQuestNumConditions(questIndex, stepIndex) do
                    local _, _, isFailCondition, isComplete =
                        GetJournalQuestConditionValues(questIndex, stepIndex, conditionIndex)
                    if (not (isFailCondition or isComplete)) then
                        local tag = ZO_MapPin.CreateQuestPinTag(questIndex, stepIndex, conditionIndex)
                        if not TaskExists(tag) then
                            local taskId = FyrMM.RequestJournalQuestConditionAssistance(questIndex, stepIndex,
                                conditionIndex, assisted)
                            if taskId ~= nil then
                                FyrMM.LastQuestPinRequest = GetFrameTimeMilliseconds()
                                CurrentTasks[taskId] = {}
                                tag.MapId = CurrentMap.MapId
                                CurrentTasks[taskId] = tag
                                CurrentTasks[taskId].RequestTimeStamp = FyrMM.LastQuestPinRequest
                            end
                        end
                    end
                end
            end
        end
    end
end

function FyrMM.UpdateQuestPins()
    if FyrMM.Halted then
        return
    end
    if not ZO_IsTableEmpty(CurrentTasks) and GetFrameTimeMilliseconds() - FyrMM.LastQuestPinRequest > FYRMM_QUEST_PIN_REQUEST_TIMEOUT then
        DestroyTasks()
    end
    if not ZO_IsTableEmpty(CurrentTasks) then
        return
    end
    if ZO_IsTableEmpty(CurrentTasks) and GetFrameTimeMilliseconds() - FyrMM.LastQuestPinRequest < FYRMM_QUEST_PIN_REQUEST_MINIMUM_DELAY then
        return
    end -- anti spam
    FyrMM.questPinCount = GetQuestPinCount()
    QuestPinsUpdating = true
    QuestTasksPending = true
    for i = 1, MAX_JOURNAL_QUESTS do
        if (IsValidQuestIndex(i)) then
            if FyrMM.Reloading then
                return
            end
            AddQuestPins(i)
        end
    end
end

function FyrMM.RequestQuestPinUpdate()
    NeedQuestPinUpdate = true -- moved this on top to avoid quest pins not removing 02/07/2023
    if Fyr_MM:IsHidden() then -- test 03/05/2023
        return
    end                     
    FyrMM.RegisterUpdates() -- fix for questpins not updating after completing quest
end

---------------------------------------------------
-- Keep Network updates
---------------------------------------------------
function FyrMM.AvAPinOnMouseExit(pin)
    FyrMM.SetTargetScale(pin, 1)
    if pin.tooltipId >= 3 then
        --ZO_Tooltips_HideTextTooltip()
		ClearTooltip(InformationTooltip)
    else
        ZO_KeepTooltip:SetHidden(true)
    end
end

function FyrMM.AvAPinOnMouseEnter(pin) 
    FyrMM.SetTargetScale(pin, 1.3)
    if not FyrMM.SV.PinTooltips then
        return
    end
    if pin == nil then
        return
    end

    if pin.tooltipId == nil then
        return
    
    elseif pin.tooltipId == 1 then -- keeps
        ZO_KeepTooltip:SetKeep(pin.keepId, ZO_WorldMap_GetBattlegroundQueryType(), 95)
        ZO_KeepTooltip:SetHidden(false)
        ZO_KeepTooltip:ClearAnchors()
        ZO_KeepTooltip:SetAnchor(TOPLEFT, Fyr_MM, TOPRIGHT, 0, 0)
        return
    
    elseif pin.tooltipId == 2 then -- forward camps
        ZO_KeepTooltip:SetForwardCamp(pin.m_Pin:GetForwardCampIndex())
        ZO_KeepTooltip:SetHidden(false)
        ZO_KeepTooltip:ClearAnchors()
        ZO_KeepTooltip:SetAnchor(TOPLEFT, Fyr_MM, TOPRIGHT, 0, 0)
        return
    
    elseif pin.tooltipId == 3 then -- AVA objective
        InitializeTooltip(InformationTooltip, Fyr_MM, TOPLEFT, 0, 0)
		local bgContext = ZO_WorldMap_GetBattlegroundQueryType()
		local objectiveName, objectiveType, objectiveState = GetObjectiveInfo(pin.keepId, pin.objectiveId, bgContext)
		local alliance = 0
		
		
		if objectiveType == OBJECTIVE_ARTIFACT_DEFENSIVE or objectiveType == OBJECTIVE_ARTIFACT_OFFENSIVE or objectiveType == OBJECTIVE_BALL or objectiveType == OBJECTIVE_DAEDRIC_WEAPON then
		     alliance = GetCarryableObjectiveHoldingAllianceInfo(pin.keepId, pin.objectiveId, bgContext) 
		else 
		     alliance = GetCaptureAreaObjectiveOwner(pin.keepId, pin.objectiveId, bgContext)
		end
		
		if alliance == nil or alliance == 0 then
		    InformationTooltip:AddLine(objectiveName, FyrMM.HeaderFontType, ZO_WHITE:UnpackRGB())
			  IsCurrentLocation(pin)
        return
		end
		
		local icon = ""
		local allianceName = ""
		local allianceColor = ZO_WHITE
		
		if IsActiveWorldBattleground()	then  
		     icon = ZO_GetBattlegroundTeamIcon(alliance)
		     allianceColor = GetBattlegroundTeamColor(alliance) 
         allianceName = allianceColor:Colorize(GetBattlegroundTeamName(alliance))
		else 
		     icon = ZO_GetAllianceIcon(alliance)
		     allianceColor = GetAllianceColor(alliance)
			   allianceName = allianceColor:Colorize(GetAllianceName(alliance))
		end
		
		local allianceIcon = allianceColor:Colorize(zo_iconFormatInheritColor(icon, 16, 32))

		InformationTooltip:AddLine(objectiveName, FyrMM.HeaderFontType, ZO_WHITE:UnpackRGB())
		ZO_Tooltip_AddDivider(InformationTooltip)
		
		InformationTooltip:AddLine(zo_strformat(SI_TOOLTIP_KEEP_ALLIANCE_OWNER, allianceIcon, "", "")..allianceName, FyrMM.DefaultFontType, 1, 1, 1, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_LEFT)

		IsCurrentLocation(pin)
    return
    
    elseif pin.tooltipId == 4 then -- link locks  -- NOT WORKING
	      InitializeTooltip(InformationTooltip, Fyr_MM, TOPLEFT, 0, 0)
        InformationTooltip:AddLine(zo_strformat(SI_TOOLTIP_ALLIANCE_RESTRICTED_LINK, GetAllianceName(pin.alliance)), FyrMM.DefaultFontType, ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB())
		return
		
	elseif pin.tooltipId == 5 then	-- KILL LOCATIONS
		InitializeTooltip(InformationTooltip, Fyr_MM, TOPLEFT, 0, 0)
		InformationTooltip:AddLine(GetString(SI_KILL_LOCATION_TOOLTIP_HEADING))
		
		for alliance = ALLIANCE_ITERATION_BEGIN, ALLIANCE_ITERATION_END do
			local numKills = GetNumKillLocationAllianceKills(pin.m_PinTag, alliance)
			if numKills > 0 then
				local allianceColor = GetAllianceColor(alliance)
				local allianceIcon = allianceColor:Colorize(zo_iconFormatInheritColor(ZO_GetAllianceIcon(alliance), 16, 32))
				local allianceName = allianceColor:Colorize(GetAllianceName(alliance))
				InformationTooltip:AddLine(zo_strformat(SI_KILL_LOCATION_TOOLTIP_ALLIANCE_KILLS, allianceIcon, allianceName, numKills), FyrMM.DefaultFontType, 1, 1, 1, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_LEFT)
			end
		end
		IsCurrentLocation(pin)
		
	elseif pin.tooltipId == 6 then	-- town fast travel nodes
		InitializeTooltip(InformationTooltip, Fyr_MM, TOPLEFT, 0, 0)
		InformationTooltip:AddLine( GetKeepName(pin.keepId).." "..GetString(SI_GAMEPAD_WORLD_MAP_FAST_TRAVEL),FyrMM.DefaultFontType)
		IsCurrentLocation(pin)
    end

end


function FyrMM.KeepNetworkCleanupReminder(from, parent)
    if parent == nil then
        return
    end
    local t = GetGameTimeMilliseconds()
    local Count = parent:GetNumChildren()
    for i = from, Count do
        local l = parent:GetChild(i)
        if l ~= nil then 
            l:ClearAnchors()
            l.nX = nil
            l.nY = nil
            l.m_PinType = nil
            l.tooltipId = nil
            l.continuousUpdate = nil
            l.objectiveId = nil
            l:SetHidden(true)
            l:SetMouseEnabled(false)
            l:SetDimensions(0, 0)
            PinsList[l:GetName()] = nil
        end
    end
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "FyrMM.KeepNetworkCleanupReminder "..parent:GetName().." "..tostring(GetGameTimeMilliseconds() - t))
    end
end

function FyrMM.UpdateKeepNetwork()
    if FyrMM.Halted then
        return
    end

    if CurrentMap.MapId == 16 then -- set links as dirty when on the Cyrodiil big map
        FyrMM.dirtyLinks = true
    end  

    if CurrentMap.MapId ~= 16 and CurrentMap.MapId ~= 660 and (CurrentMap.MapId > 577 or CurrentMap.MapId < 572) then -- no links & keep display when not on Cyrodiil map, Imperial city, or the 6 bases
        KeepIndex = {}
        local LinksDone = false
        local LinksNSDone = false
        local LinksWEDone = false
        local LocksDone = false
		local l
        for i = 1, 100 do
            l = GetControl("Fyr_MM_Scroll_Map_Links_Link" .. tostring(i))
            if l ~= nil then
                l:ClearAnchors()
                l:SetHidden(true)
                l:SetMouseEnabled(false)
            else
                LinksDone = true
            end
            l = GetControl("Fyr_MM_Scroll_Map_LinksNS_Link" .. tostring(i))
            if l ~= nil then
                l:ClearAnchors()
                l:SetHidden(true)
                l:SetMouseEnabled(false)
            else
                LinksNSDone = true
            end
            l = GetControl("Fyr_MM_Scroll_Map_LinksWE_Link" .. tostring(i))
            if l ~= nil then
                l:ClearAnchors()
                l:SetHidden(true)
                l:SetMouseEnabled(false)
            else
                LinksWEDone = true
            end
            l = GetControl("Fyr_MM_Scroll_Map_Locks_Lock" .. tostring(i))
            if l ~= nil then
                l:ClearAnchors()
                l.normalizedX = nil
                l.normalizedY = nil
                l:SetHidden(true)
                l:SetMouseEnabled(false)
                l:SetDimensions(0, 0)
            else
                LocksDone = true
            end
            -- 03/07/2026: Reverted the 02/07/2026 "break" optimization here at the user's request
            -- while investigating a reported Cyrodiil link-position regression. Restored to
            -- original behavior (all 100 iterations always run) until the cause is confirmed.
            if LinksDone and LinksNSDone and LinksWEDone and LocksDone then
                i = 100
            end
        end

        if not IsActiveWorldBattleground() then -- if in battleground we continue to display the objectives
            FyrMM.KeepRefreshNeeded = false
            return
        end
    end

    if not IsInAvAZone() or (not FyrMM.Visible or Fyr_MM:IsHidden()) or (not CurrentMap.ready and not CurrentMap.mapBuilt) then
        return
    end
    if not FyrMM.KeepRefreshNeeded then
        return
    end

    local t = GetGameTimeMilliseconds()
    local historyPercent = 100.0
    local playerAlliance = GetUnitAlliance("player")
    local bgContext = ZO_WorldMap_GetBattlegroundQueryType()
    local mWidth, mHeight = Fyr_MM_Scroll_Map:GetDimensions()
    FyrMM.KeepNetworkCleanupReminder(1, Fyr_MM_Scroll_Map_Keeps)
    FyrMM.KeepNetworkCleanupReminder(1, Fyr_MM_Scroll_Map_Keeps_Under_Attack)

    for i = 1, GetNumKeeps() do
        if FyrMM.Reloading then
            return
        end
        local keepId, kbgContext = GetKeepKeysByIndex(i)
        KeepIndex[keepId] = nil
        if IsLocalBattlegroundContext(kbgContext) then
            KeepIndex[keepId] = i
            local pinType, normalizedX, normalizedY = GetHistoricalKeepPinInfo(keepId, bgContext, historyPercent)
            local keepAlliance = GetKeepAlliance(keepId, bgContext)
            local keepUnderAttack = GetKeepUnderAttack(keepId, bgContext)
            local keepUnderAttackPinType = ZO_WorldMap_GetUnderAttackPinForKeepPin(pinType)
            if FyrMM.IsCoordinatesInMap(normalizedX, normalizedY) then
                local uakeepControl = GetControl("Fyr_MM_Scroll_Map_Keeps_Under_Attack_Keep"..tostring(keepId))
                if keepUnderAttack then
                    if uakeepControl == nil then
                        uakeepControl = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_Keeps_Under_Attack_Keep"..tostring(keepId), Fyr_MM_Scroll_Map_Keeps_Under_Attack, CT_TEXTURE)
                    end
                    uakeepControl:SetTexture(GetPinTexture(keepUnderAttackPinType, uakeepControl))
					          uakeepControl.pinTexture = GetPinTexture(keepUnderAttackPinType, uakeepControl)
                    uakeepControl.nX = normalizedX
                    uakeepControl.nY = normalizedY
                    uakeepControl.keepId = keepId
                    uakeepControl.m_PinType = keepUnderAttackPinType
                    uakeepControl:SetHidden(false)
                    uakeepControl:SetDrawLayer(1)
                    FyrMM.SetPinSize(uakeepControl, ZO_MapPin.PIN_DATA[keepUnderAttackPinType].size * FyrMM.pScalePercent, 0)
                    FyrMM.SetPinAnchor(uakeepControl, normalizedX, normalizedY, Fyr_MM_Scroll_Map_Keeps_Under_Attack)
                else
                    if uakeepControl ~= nil then
                        uakeepControl:ClearAnchors()
                        uakeepControl.nX = nil
                        uakeepControl.nY = nil
                        uakeepControl.m_PinType = nil
                        uakeepControl:SetHidden(true)
                        uakeepControl:SetMouseEnabled(false)
                        uakeepControl:SetDimensions(0, 0)
                        PinsList[uakeepControl:GetName()] = nil
                    end
                end

                local keepControl = GetControl("Fyr_MM_Scroll_Map_Keeps_Keep"..tostring(keepId))
                if keepControl == nil then
                    keepControl = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_Keeps_Keep" .. tostring(keepId), Fyr_MM_Scroll_Map_Keeps, CT_TEXTURE)
                    keepControl:SetHandler("OnMouseEnter", FyrMM.AvAPinOnMouseEnter)
                    keepControl:SetHandler("OnMouseExit", FyrMM.AvAPinOnMouseExit)
                end
                keepControl.nX = normalizedX
                keepControl.nY = normalizedY
			        	keepControl.nDistance = function()
                      if keepControl.nX == nil then
                        return 1
                      end
                      return zo_sqrt((CurrentMap.PlayerNX - keepControl.nX) ^ 2 + (CurrentMap.PlayerNY - keepControl.nY) ^ 2)
				          end
                keepControl:SetTexture(GetPinTexture(pinType, keepControl))
			        	keepControl.pinTexture = GetPinTexture(pinType, keepControl)
                keepControl.keepId = keepId
                keepControl.m_PinType = pinType
                keepControl:SetDrawLayer(3)
                FyrMM.SetPinSize(keepControl, ZO_MapPin.PIN_DATA[pinType].size * FyrMM.pScalePercent, 0)
                keepControl:SetHidden(false)
                FyrMM.SetPinAnchor(keepControl, normalizedX, normalizedY, Fyr_MM_Scroll_Map_Keeps)
                keepControl.tooltipId = 1 -- Keeps
                keepControl:SetMouseEnabled(true)
            else
                local keepControl = GetControl("Fyr_MM_Scroll_Map_Keeps_Keep" .. tostring(keepId))
                local uakeepControl = GetControl("Fyr_MM_Scroll_Map_Keeps_Under_Attack_Keep" .. tostring(keepId))
                if keepControl ~= nil then
                    keepControl:SetHidden(true)
                end
                if uakeepControl ~= nil then
                    uakeepControl:SetHidden(true)
                end
            end
			
				
			-- Draw travel nodes real locations for the 3 towns if accessible
			if CurrentMap.MapId == 16 and (keepId == 149 or keepId == 151 or keepId == 152) and GetKeepAccessible(keepId, bgContext) then
			    local normalizedX, normalizedY
				
				if keepId == 149 then -- Vlastarus
				      normalizedX = 0.3125
				      normalizedY = 0.6718
				elseif keepId == 151 then -- Bruma
				      normalizedX = 0.4724
				      normalizedY = 0.1902
				elseif keepId == 152 then -- Cropsford
					  normalizedX = 0.7002
				      normalizedY = 0.6432
				end
			
			    local nodeControl = GetControl("Fyr_MM_Scroll_Map_Keeps_Node" .. tostring(keepId))
				if nodeControl == nil then
					nodeControl = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_Keeps_Node" .. tostring(keepId), Fyr_MM_Scroll_Map_Keeps, CT_TEXTURE)
					nodeControl:SetHandler("OnMouseEnter", FyrMM.AvAPinOnMouseEnter)
					nodeControl:SetHandler("OnMouseExit", FyrMM.AvAPinOnMouseExit)
				end
				nodeControl.nX = normalizedX
				nodeControl.nY = normalizedY
				nodeControl:SetTexture(ZO_GetAllianceIcon(GetUnitAlliance("player"))) 
				nodeControl:SetColor(GetAllianceColor(GetUnitAlliance("player")):UnpackRGBA())
				nodeControl.keepId = keepId
				nodeControl.m_PinType = 9998
				nodeControl:SetDrawLevel(3)
				nodeControl:SetDrawTier(3)
				nodeControl:SetDrawLayer(3)
				nodeControl:SetDimensions(16, 32)
				nodeControl:SetHidden(false)
				FyrMM.SetPinAnchor(nodeControl, normalizedX, normalizedY, Fyr_MM_Scroll_Map_Keeps)
				nodeControl.tooltipId = 6 
				nodeControl:SetMouseEnabled(true)
			else
				local nodeControl = GetControl("Fyr_MM_Scroll_Map_Keeps_Node" .. tostring(keepId))
				if nodeControl ~= nil then
					nodeControl:SetHidden(true)
					if nodeControl.nX == nil or nodeControl.nX == nil then
					   nodeControl = nil
					end   
				end
			end		
		
        end
    end

    local numForwardCamps = GetNumForwardCamps(bgContext)
    FyrMM.currentForwardCamps = 0
    FyrMM.KeepNetworkCleanupReminder(numForwardCamps + 1, Fyr_MM_Scroll_Map_ForwardCamps)
    for i = 1, numForwardCamps do
        local pinType, normalizedX, normalizedY, radius, usable = GetForwardCampPinInfo(bgContext, i)
        if (normalizedX > 0 and normalizedX < 1.0001 and normalizedY > 0 and normalizedY < 1.0001) then
            if not usable then
                radius = 0
            end
            FyrMM.currentForwardCamps = FyrMM.currentForwardCamps + 1
            local forwardCampControl = GetControl("Fyr_MM_Scroll_Map_ForwardCamps_Pin"..tostring(FyrMM.currentForwardCamps))
            if forwardCampControl == nil then
                forwardCampControl = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_ForwardCamps_Pin" .. tostring(FyrMM.currentForwardCamps), Fyr_MM_Scroll_Map_ForwardCamps, CT_TEXTURE)
                forwardCampControl:SetHandler("OnMouseEnter", FyrMM.AvAPinOnMouseEnter)
                forwardCampControl:SetHandler("OnMouseExit", FyrMM.AvAPinOnMouseExit)
            end

            local forwardCampBlobControl = GetControl("Fyr_MM_Scroll_Map_ForwardCamps_Pin"..tostring(FyrMM.currentForwardCamps).."_Blob")
            if forwardCampBlobControl == nil then
                forwardCampBlobControl = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_ForwardCamps_Pin"..tostring(FyrMM.currentForwardCamps).."_Blob", Fyr_MM_Scroll_Map_ForwardCamps, CT_TEXTURE)
            end

            local pin = ZO_Object.New(ZO_MapPin)
            forwardCampControl.nX = normalizedX
            forwardCampControl.nY = normalizedY
            forwardCampBlobControl.nX = normalizedX
            forwardCampBlobControl.nY = normalizedY
            pin.normalizedX = normalizedX
            pin.normalizedY = normalizedY
            pin.radius = radius
            pin.m_PinType = pinType
            pin.m_PinTag = ZO_MapPin.CreateForwardCampPinTag(i)
            forwardCampBlobControl.m_Pin = pin
            forwardCampBlobControl:SetDrawLayer(3)
            forwardCampBlobControl:SetTexture("esoui/art/mappins/map_areapin.dds")
            local color = ZO_MAP_PIN_NORMAL_COLOR
            forwardCampBlobControl:SetColor(color:UnpackRGBA())
            forwardCampControl.m_Pin = pin
            forwardCampControl.m_PinType = pinType
            forwardCampControl:SetDrawLayer(3)
            forwardCampControl:SetTexture(ZO_MapPin.PIN_DATA[pinType].texture)
            local campIconSize = 64 * FyrMM.pScalePercent
            local campBlobSize = mHeight * radius * 2
            FyrMM.SetPinSize(forwardCampControl, campIconSize, 0)
            forwardCampBlobControl:SetDimensions(campBlobSize, campBlobSize)
            if FyrMM.SV.WheelMap then
                forwardCampBlobControl:SetParent(Fyr_MM_Scroll_CW_Map_Pins)
                CreateForwardCampAreaSidePins(pin, campBlobSize, usable)
            end

            forwardCampControl:SetHidden(false)
            forwardCampBlobControl:SetHidden(not usable)
            FyrMM.SetPinAnchor(forwardCampControl, normalizedX, normalizedY, Fyr_MM_Scroll_Map_ForwardCamps)
            FyrMM.SetPinAnchor(forwardCampBlobControl, normalizedX, normalizedY, Fyr_MM_Scroll_Map_ForwardCamps)
            forwardCampControl.tooltipId = 2
            forwardCampControl:SetMouseEnabled(true)
        end
    end

    --- Kill Locations (Battles) ---
    local killPinCount = 0
    FyrMM.KeepNetworkCleanupReminder(GetNumKillLocations() + 1, Fyr_MM_Scroll_Map_Kill_Locations)
    for i = 1, GetNumKillLocations() do
        local pinType, normalizedX, normalizedY = GetKillLocationPinInfo(i)
        if (pinType ~= MAP_PIN_TYPE_INVALID) then
            if (ZO_WorldMap_IsPinGroupShown(MAP_FILTER_KILL_LOCATIONS)) then
                if ((normalizedX < 1.001 or normalizedY < 1.001) and (normalizedX > -.001 or normalizedY > -.001)) then
                    killPinCount = killPinCount + 1
                    local killPin = GetControl("Fyr_MM_Scroll_Map_Kill_Locations_Pin" .. tostring(killPinCount))
                    if killPin == nil then
                        killPin = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_Kill_Locations_Pin" .. tostring(killPinCount), Fyr_MM_Scroll_Map_Kill_Locations, CT_TEXTURE)
					             	killPin:SetHandler("OnMouseEnter", FyrMM.AvAPinOnMouseEnter)
                        killPin:SetHandler("OnMouseExit", FyrMM.AvAPinOnMouseExit)
                    end
                    local killPinSize = ZO_MapPin.PIN_DATA[pinType].size * FyrMM.pScalePercent
                    killPin:SetTexture(ZO_MapPin.PIN_DATA[pinType].texture)
                    FyrMM.SetPinSize(killPin, killPinSize, 0)
                    local pin = ZO_Object.New(ZO_MapPin)
                    pin.normalizedX = normalizedX
                    pin.normalizedY = normalizedY
                    pin.m_PinType = pinType
					pin.m_PinTag = i
                    killPin.m_Pin = pin
                    killPin.m_PinType = pinType
                    killPin.nX = normalizedX
                    killPin.nY = normalizedY
                    killPin:SetDrawLayer(3)
                    killPin:SetHidden(false)
                    FyrMM.SetPinAnchor(killPin, normalizedX, normalizedY, Fyr_MM_Scroll_Map_Kill_Locations)
                    killPin.tooltipId = 5
                    killPin:SetMouseEnabled(true)
                end
            end
        end
    end
	

    local r, g, b
    local numLinks = GetNumKeepTravelNetworkLinks(bgContext)
    local linkControl, linkControlNS, linkControlWE

    for linkIndex = 1, numLinks do
        local linkType, linkOwner, restrictedToAlliance, startNX, startNY, endNX, endNY = GetHistoricalKeepTravelNetworkLinkInfo(linkIndex, bgContext, historyPercent)
        --		startNX = zo_round(startNX * 10000) / 10000
        --		startNY = zo_round(startNY * 10000) / 10000	
        --		endNX = zo_round(endNX * 10000) / 10000
        --		endNY = zo_round(endNY * 10000) / 10000	
        if startNX < 1 or startNY < 1 or endNX < 1 or endNY < 1 then
            local startX, startY, endX, endY = zo_round(startNX * mWidth - mWidth / 2), zo_round(startNY * mHeight - mHeight / 2), zo_round(endNX * mWidth - mWidth / 2), zo_round(endNY * mHeight - mHeight / 2)
            local linkControl = GetControl("Fyr_MM_Scroll_Map_Links_Link" .. tostring(linkIndex))
            if linkControl == nil then
                linkControl = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_Links_Link" .. tostring(linkIndex), Fyr_MM_Scroll_Map_Links, CT_LINE)
            end
            local linkControlNS = GetControl("Fyr_MM_Scroll_Map_LinksNS_Link" .. tostring(linkIndex))
            if linkControlNS == nil then
                linkControlNS = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_LinksNS_Link" .. tostring(linkIndex), Fyr_MM_Scroll_NS_Map_Pins, CT_LINE)
            end
            -- 03/07/2026: Reverted the 02/07/2026 optimization here at the user's request while
            -- investigating a reported Cyrodiil link-position regression. Restored to original
            -- code (calls GetControl() twice) until the cause is confirmed.
            local linkControlWE = GetControl("Fyr_MM_Scroll_Map_LinksWE_Link" .. tostring(linkIndex))
            if GetControl("Fyr_MM_Scroll_Map_LinksWE_Link" .. tostring(linkIndex)) == nil then
                linkControlWE = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_LinksWE_Link" .. tostring(linkIndex),Fyr_MM_Scroll_WE_Map_Pins, CT_LINE)
            end
            linkControl.startNX = startNX
            linkControl.startNY = startNY
            linkControl.endNX = endNX
            linkControl.endNY = endNY
            linkControl:SetHidden(false)
            linkControl:SetDrawLayer(1)

            linkControlNS.startNX = startNX
            linkControlNS.startNY = startNY
            linkControlNS.endNX = endNX
            linkControlNS.endNY = endNY
            linkControlNS:SetHidden(false)
            linkControlNS:SetDrawLayer(1)

            linkControlWE.startNX = startNX
            linkControlWE.startNY = startNY
            linkControlWE.endNX = endNX
            linkControlWE.endNY = endNY
            linkControlWE:SetHidden(false)
            linkControlWE:SetDrawLayer(1)

            local linkThickness = floor((zo_round(80 * FyrMM.pScalePercent) / 10) / 2) * 2
            if linkThickness < 6 then
                linkThickness = 6
            end
            linkControl:SetThickness(linkThickness)
            linkControlNS:SetThickness(linkThickness)
            linkControlWE:SetThickness(linkThickness)

            if (GetKeepFastTravelInteraction()) then
                if (linkOwner == playerAlliance) then
                    if (linkType == FAST_TRAVEL_LINK_ACTIVE) then
                        linkControl:SetColor(ZO_KeepNetwork.LINK_READY_COLOR:UnpackRGBA())
                        linkControlNS:SetColor(ZO_KeepNetwork.LINK_READY_COLOR:UnpackRGBA())
                        linkControlWE:SetColor(ZO_KeepNetwork.LINK_READY_COLOR:UnpackRGBA())
                    else
                        linkControl:SetColor(ZO_KeepNetwork.LINK_NOT_READY_COLOR:UnpackRGBA())
                        linkControlNS:SetColor(ZO_KeepNetwork.LINK_NOT_READY_COLOR:UnpackRGBA())
                        linkControlWE:SetColor(ZO_KeepNetwork.LINK_NOT_READY_COLOR:UnpackRGBA())
                    end
                else
                    r, g, b = GetAllianceColor(linkOwner):UnpackRGB()
                    linkControl:SetColor(r, g, b, ZO_KeepNetwork.ALLIANCE_OWNER_ALPHA[linkOwner])
                    linkControlNS:SetColor(r, g, b, ZO_KeepNetwork.ALLIANCE_OWNER_ALPHA[linkOwner])
                    linkControlWE:SetColor(r, g, b, ZO_KeepNetwork.ALLIANCE_OWNER_ALPHA[linkOwner])
                end
            else
                r, g, b = GetAllianceColor(linkOwner):UnpackRGB()
                linkControl:SetColor(r, g, b, ZO_KeepNetwork.ALLIANCE_OWNER_ALPHA[linkOwner])
                linkControlNS:SetColor(r, g, b, ZO_KeepNetwork.ALLIANCE_OWNER_ALPHA[linkOwner])
                linkControlWE:SetColor(r, g, b, ZO_KeepNetwork.ALLIANCE_OWNER_ALPHA[linkOwner])
            end
            if (linkType == FAST_TRAVEL_LINK_IN_COMBAT) then
                linkControl:SetTexture("EsoUI/Art/AvA/AvA_transitLine_dashed.dds")
                linkControlNS:SetTexture("EsoUI/Art/AvA/AvA_transitLine_dashed.dds")
                linkControlWE:SetTexture("EsoUI/Art/AvA/AvA_transitLine_dashed.dds")
            else
                linkControl:SetTexture("EsoUI/Art/AvA/AvA_transitLine.dds")
                linkControlNS:SetTexture("EsoUI/Art/AvA/AvA_transitLine.dds")
                linkControlWE:SetTexture("EsoUI/Art/AvA/AvA_transitLine.dds")
            end
            if FyrMM.SV.WheelMap then
                linkControl:SetParent(Fyr_MM_Scroll_CW_Map_Pins)
            else
                linkControl:SetParent(Fyr_MM_Scroll_Map_Links)
            end

            linkControl:ClearAnchors()
            linkControlNS:ClearAnchors()
            linkControlWE:ClearAnchors()

            if FyrMM.SV.RotateMap then
                linkControl:SetAnchor(TOPLEFT, Fyr_MM_Scroll, CENTER, GetRotatedPosition(startNX, startNY))
                linkControl:SetAnchor(BOTTOMRIGHT, Fyr_MM_Scroll, CENTER, GetRotatedPosition(endNX, endNY))
                linkControlNS:SetAnchor(TOPLEFT, Fyr_MM_Scroll, CENTER, GetRotatedPosition(startNX, startNY))
                linkControlNS:SetAnchor(BOTTOMRIGHT, Fyr_MM_Scroll, CENTER, GetRotatedPosition(endNX, endNY))
                linkControlWE:SetAnchor(TOPLEFT, Fyr_MM_Scroll, CENTER, GetRotatedPosition(startNX, startNY))
                linkControlWE:SetAnchor(BOTTOMRIGHT, Fyr_MM_Scroll, CENTER, GetRotatedPosition(endNX, endNY))
            else
                linkControl:SetAnchor(TOPLEFT, Fyr_MM_Scroll_Map_Links, CENTER, startX, startY)
                linkControl:SetAnchor(BOTTOMRIGHT, Fyr_MM_Scroll_Map_Links, CENTER, endX, endY)
                linkControlNS:SetAnchor(TOPLEFT, Fyr_MM_Scroll_Map_Links, CENTER, startX, startY)
                linkControlNS:SetAnchor(BOTTOMRIGHT, Fyr_MM_Scroll_Map_Links, CENTER, endX, endY)
                linkControlWE:SetAnchor(TOPLEFT, Fyr_MM_Scroll_Map_Links, CENTER, startX, startY)
                linkControlWE:SetAnchor(BOTTOMRIGHT, Fyr_MM_Scroll_Map_Links, CENTER, endX, endY)
            end

            -- Link Locks
            if (linkOwner == ALLIANCE_NONE and restrictedToAlliance ~= ALLIANCE_NONE) then
                local lockControl = GetControl("Fyr_MM_Scroll_Map_Locks_Lock"..tostring(linkIndex))
                if lockControl == nil then
                    lockControl = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_Locks_Lock"..tostring(linkIndex), Fyr_MM_Scroll_Map_Locks, CT_TEXTURE)
				          	lockControl:SetHandler("OnMouseEnter", FyrMM.AvAPinOnMouseEnter) -- not working for some reason
                    lockControl:SetHandler("OnMouseExit", FyrMM.AvAPinOnMouseExit)   -- not working for some reason
                    lockControl:SetAlpha(0.4)
                end
                lockControl:SetTexture("/esoui/art/ava/ava_transitlocked.dds")
                FyrMM.SetPinSize(lockControl, 16 * FyrMM.pScalePercent, 0)
                lockControl:SetHidden(false)
                r, g, b = GetAllianceColor(restrictedToAlliance):UnpackRGB()
                lockControl:SetColor(r, g, b, 1)
                lockControl.alliance = restrictedToAlliance
                lockControl:SetDrawLayer(2) 

                if FyrMM.SV.WheelMap then
                    lockControl:SetParent(Fyr_MM_Scroll_CW_Map_Pins)
                else
                    lockControl:SetParent(Fyr_MM_Scroll_Map_Links)
                end
                lockControl:ClearAnchors()
                lockControl:SetAnchor(CENTER, linkControl, CENTER, 0, 0)

                lockControl.Lock = true
                lockControl.tooltipId = 4
                lockControl:SetMouseEnabled(true)
            end
        end
    end

    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug",
            "FyrMM.UpdateKeepNetwork " .. tostring(GetGameTimeMilliseconds() - t))
    end
    FyrMM.KeepRefreshNeeded = false
end

function FyrMM.RequestKeepRefresh()
    if not IsInAvAZone() or FyrMM.SV.HidePvPPins then
	    FyrMM.KeepRefreshNeeded = false
        return
    end
	
	  FyrMM.KeepRefreshNeeded = true

    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "Keep refresh request ")
    end
end

function FyrMM.KeepRefreshCheck() -- called every 1 second to avoid refresh spam
    if FyrMM.Halted or not IsInAvAZone() or FyrMM.SV.HidePvPPins then
        return
    end
    if FyrMM.KeepRefreshNeeded then
       FyrMM.UpdateKeepNetwork() 
    end
end

function FyrMM.UpdateAVABGobjectives()
    if FyrMM.Halted or FyrMM.SV.HidePvPPins then
        return
    end
    if (not IsInAvAZone() and not IsActiveWorldBattleground()) or (not FyrMM.Visible or Fyr_MM:IsHidden()) or
        (not CurrentMap.ready and not CurrentMap.mapBuilt) then
        return
    end
    if FyrMM.UpdateAVABGobjectivesBusy then
        return
    end

    FyrMM.UpdateAVABGobjectivesBusy = true

    local bgContext = ZO_WorldMap_GetBattlegroundQueryType()
    local numObjectives = GetNumObjectives()
    FyrMM.KeepNetworkCleanupReminder(1, Fyr_MM_Scroll_Map_Objectives)

    for i = 1, numObjectives do
        local okeepId, objectiveId, obgContext = GetObjectiveIdsForIndex(i)
        if (IsLocalBattlegroundContext(obgContext)) then
            if ZO_WorldMap_IsObjectiveShown(okeepId, objectiveId, obgContext) and DoesObjectiveExist(okeepId, objectiveId, obgContext) then
                local opinType, currentX, currentY, continuousUpdate = GetObjectivePinInfo(okeepId, objectiveId, bgContext)
                local spawnPinType, spawnX, spawnY = GetObjectiveSpawnPinInfo(okeepId, objectiveId, bgContext)
                local returnPinType, returnX, returnY, returnContinuousUpdate = GetObjectiveReturnPinInfo(okeepId, objectiveId, bgContext)
                local visible = IsObjectiveObjectVisible(okeepId, objectiveId, bgContext)

                local alliance = GetCarryableObjectiveHoldingAllianceInfo(okeepId, objectiveId, bgContext)
                local auraR, auraG, auraB, auraA = GetAllianceColor(alliance):UnpackRGBA()

                if spawnPinType ~= MAP_PIN_TYPE_INVALID and visible then
                    local objectiveSpawnControl = GetControl("Fyr_MM_Scroll_Map_Objectives_ObjectiveSpawn" .. tostring(objectiveId))
                    if objectiveSpawnControl == nil then
                        objectiveSpawnControl = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_Objectives_ObjectiveSpawn" .. tostring(objectiveId), Fyr_MM_Scroll_Map_Objectives, CT_TEXTURE)
                        objectiveSpawnControl:SetHandler("OnMouseEnter", FyrMM.AvAPinOnMouseEnter)
                        objectiveSpawnControl:SetHandler("OnMouseExit", FyrMM.AvAPinOnMouseExit)
                    end
                    objectiveSpawnControl.nX = spawnX
                    objectiveSpawnControl.nY = spawnY
                    objectiveSpawnControl.m_PinType = spawnPinType
                    objectiveSpawnControl:SetDrawLayer(3)
                    objectiveSpawnControl:SetDrawLevel(ZO_MapPin.PIN_DATA[spawnPinType].level)
                    objectiveSpawnControl:SetTexture(GetPinTexture(spawnPinType, objectiveSpawnControl))
                    FyrMM.SetPinSize(objectiveSpawnControl, ZO_MapPin.PIN_DATA[spawnPinType].size * FyrMM.pScalePercent,0)
                    objectiveSpawnControl:SetHidden(false)
                    FyrMM.SetPinAnchor(objectiveSpawnControl, spawnX, spawnY, Fyr_MM_Scroll_Map_Objectives)
                    objectiveSpawnControl.keepId = okeepId
                    objectiveSpawnControl.objectiveId = objectiveId
                    objectiveSpawnControl.tooltipId = 3
                    objectiveSpawnControl:SetMouseEnabled(true)

                    if FyrMM.SV.borderAVABG then -- create borderpin
                        FyrMM.AVABGobjectivesToBorderPins = FyrMM.AVABGobjectivesToBorderPins or {}

                        local playerBGalliance = GetUnitBattlegroundTeam("player")

                        -- chaosball base & your "capture the relic" base
                        local display = false
                        if spawnPinType == MAP_PIN_TYPE_BGPIN_MURDERBALL_SPAWN_NEUTRAL then
                            display = true
                        elseif spawnPinType == MAP_PIN_TYPE_BGPIN_FLAG_SPAWN_FIRE_DRAKES and playerBGalliance == 1 then
                            display = true
                        elseif spawnPinType == MAP_PIN_TYPE_BGPIN_FLAG_SPAWN_PIT_DAEMONS and playerBGalliance == 2 then
                            display = true
                        elseif spawnPinType == MAP_PIN_TYPE_BGPIN_FLAG_SPAWN_STORM_LORDS and playerBGalliance == 3 then
                            display = true
                        end

                        if objectiveSpawnControl and display then
                            objectiveSpawnControl.AVABGtype = "spawn"
                            FyrMM.AVABGobjectivesToBorderPins["spawn" .. tostring(objectiveId)] = objectiveSpawnControl
                        end
                    end
                end

                if returnPinType ~= MAP_PIN_TYPE_INVALID and visible then -- Diamond shape icon
                    local objectiveReturnControl = GetControl(
                        "Fyr_MM_Scroll_Map_Objectives_ObjectiveReturn" .. tostring(objectiveId))
                    if objectiveReturnControl == nil then
                        objectiveReturnControl = WINDOW_MANAGER:CreateControl(
                            "Fyr_MM_Scroll_Map_Objectives_ObjectiveReturn" .. tostring(objectiveId),
                            Fyr_MM_Scroll_Map_Objectives, CT_TEXTURE)
                        objectiveReturnControl:SetHandler("OnMouseEnter", FyrMM.AvAPinOnMouseEnter)
                        objectiveReturnControl:SetHandler("OnMouseExit", FyrMM.AvAPinOnMouseExit)
                    end
                    objectiveReturnControl.nX = currentX
                    objectiveReturnControl.nY = currentY
                    objectiveReturnControl.m_PinType = returnPinType
                    objectiveReturnControl.continuousUpdate = returnContinuousUpdate
                    objectiveReturnControl:SetDrawLayer(3)
                    objectiveReturnControl:SetDrawLevel(ZO_MapPin.PIN_DATA[returnPinType].level)
                    objectiveReturnControl:SetTexture(GetPinTexture(returnPinType, objectiveReturnControl))
                    FyrMM.SetPinSize(objectiveReturnControl, ZO_MapPin.PIN_DATA[returnPinType].size * FyrMM.pScalePercent, 0)
                    objectiveReturnControl:SetHidden(false)
                    FyrMM.SetPinAnchor(objectiveReturnControl, currentX, currentY, Fyr_MM_Scroll_Map_Objectives)
                    objectiveReturnControl.keepId = okeepId
                    objectiveReturnControl.objectiveId = objectiveId
                    objectiveReturnControl.tooltipId = 3
                    objectiveReturnControl:SetMouseEnabled(true)
                end

                if opinType ~= MAP_PIN_TYPE_INVALID and visible then
                    local objectiveControl = GetControl("Fyr_MM_Scroll_Map_Objectives_Objective"..tostring(objectiveId))
                    if objectiveControl == nil then
                        objectiveControl = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_Objectives_Objective"..tostring(objectiveId), Fyr_MM_Scroll_Map_Objectives, CT_TEXTURE)
                        objectiveControl:SetHandler("OnMouseEnter", FyrMM.AvAPinOnMouseEnter)
                        objectiveControl:SetHandler("OnMouseExit", FyrMM.AvAPinOnMouseExit)
                    end
                    objectiveControl.nX = currentX
                    objectiveControl.nY = currentY
                    objectiveControl.m_PinType = opinType
                    objectiveControl.continuousUpdate = continuousUpdate
                    objectiveControl:SetDrawLayer(3)
                    objectiveControl:SetDrawLevel(ZO_MapPin.PIN_DATA[opinType].level)
                    objectiveControl:SetTexture(GetPinTexture(opinType, objectiveControl))
                    FyrMM.SetPinSize(objectiveControl, (ZO_MapPin.PIN_DATA[opinType].size * FyrMM.pScalePercent), 0)
                    objectiveControl:SetHidden(false)
                    FyrMM.SetPinAnchor(objectiveControl, currentX, currentY, Fyr_MM_Scroll_Map_Objectives)
                    objectiveControl.keepId = okeepId
                    objectiveControl.objectiveId = objectiveId
                    objectiveControl.tooltipId = 3
                    objectiveControl:SetMouseEnabled(true)

                    if FyrMM.SV.borderAVABG then -- create borderpin
                        FyrMM.AVABGobjectivesToBorderPins = FyrMM.AVABGobjectivesToBorderPins or {}
                        if objectiveControl then
                            objectiveControl.AVABGtype = "objective"
                            FyrMM.AVABGobjectivesToBorderPins["objective" .. tostring(objectiveId)] = objectiveControl
                        end
                    end

                    if objectiveControl then
                        local auraPinType, red, green, blue = GetObjectiveAuraPinInfo(okeepId, objectiveId, bgContext)
                        if auraPinType ~= MAP_PIN_TYPE_INVALID and visible then
                            local objectiveAuraControl = GetControl(
                                "Fyr_MM_Scroll_Map_Objectives_ObjectiveAura" .. tostring(objectiveId))
                            if objectiveAuraControl == nil then
                                objectiveAuraControl = WINDOW_MANAGER:CreateControl(
                                    "Fyr_MM_Scroll_Map_Objectives_ObjectiveAura"..tostring(objectiveId),
                                    Fyr_MM_Scroll_Map_Objectives, CT_TEXTURE)
                                objectiveAuraControl:SetHandler("OnMouseEnter", FyrMM.AvAPinOnMouseEnter)
                                objectiveAuraControl:SetHandler("OnMouseExit", FyrMM.AvAPinOnMouseExit)
                            end
                            local auraTag = ZO_MapPin.CreateObjectivePinTag(okeepId, objectiveId, bgContext)
                            objectiveAuraControl.nX = currentX
                            objectiveAuraControl.nY = currentY
                            objectiveAuraControl.m_PinType = auraPinType
                            objectiveAuraControl.m_PinTag = auraTag
                            objectiveAuraControl.continuousUpdate = continuousUpdate
                            objectiveAuraControl:SetDrawLayer(3)
                            objectiveAuraControl:SetDrawLevel(ZO_MapPin.PIN_DATA[auraPinType].level)
                            objectiveAuraControl:SetTexture(GetPinTexture(auraPinType, objectiveAuraControl))
                            FyrMM.SetPinSize(objectiveAuraControl,(ZO_MapPin.PIN_DATA[auraPinType].size * FyrMM.pScalePercent), 0)
                            objectiveAuraControl:SetHidden(false)
                            FyrMM.SetPinAnchor(objectiveAuraControl, currentX, currentY, Fyr_MM_Scroll_Map_Objectives)
                            objectiveAuraControl.keepId = okeepId
                            objectiveAuraControl.objectiveId = objectiveId
                            objectiveAuraControl.tooltipId = 3
                            objectiveAuraControl:SetColor(red, green, blue)
                            objectiveAuraControl.tint = ZO_ColorDef:New(red, green, blue)
                            objectiveAuraControl:SetMouseEnabled(true)

                            if FyrMM.SV.borderAVABG then --  create borderpin
                                FyrMM.AVABGobjectivesToBorderPins = FyrMM.AVABGobjectivesToBorderPins or {}
                                if objectiveAuraControl then
                                    objectiveAuraControl.AVABGtype = "aura"
                                    FyrMM.AVABGobjectivesToBorderPins["aura"..tostring(objectiveId)] = objectiveAuraControl
                                end
                            end
                        elseif visible and ZO_MapPin.PIN_DATA[opinType].level == 105 and alliance ~= ALLIANCE_NONE then -- let's make an aura pin for elder scrolls which doesn't exist in game :)
                            local objectiveAuraControl = GetControl("Fyr_MM_Scroll_Map_Objectives_ObjectiveAura" .. tostring(objectiveId))
                            if objectiveAuraControl == nil then
                                objectiveAuraControl = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_Objectives_ObjectiveAura"..tostring(objectiveId), Fyr_MM_Scroll_Map_Objectives, CT_TEXTURE)
                                objectiveAuraControl:SetHandler("OnMouseEnter", FyrMM.AvAPinOnMouseEnter)
                                objectiveAuraControl:SetHandler("OnMouseExit", FyrMM.AvAPinOnMouseExit)
                            end
                            local auraTag = ZO_MapPin.CreateObjectivePinTag(okeepId, objectiveId, bgContext)
                            objectiveAuraControl.nX = currentX
                            objectiveAuraControl.nY = currentY
                            objectiveAuraControl.m_PinType = 9999
                            objectiveAuraControl.m_PinTag = auraTag
                            objectiveAuraControl.continuousUpdate = continuousUpdate
                            objectiveAuraControl:SetDrawLayer(3)
                            objectiveAuraControl:SetDrawLevel(104)
                            objectiveAuraControl:SetTexture("MiniMap/Textures/scroll_aura.dds")
                            FyrMM.SetPinSize(objectiveAuraControl, (64 * FyrMM.pScalePercent), 0)
                            objectiveAuraControl:SetHidden(false)
                            FyrMM.SetPinAnchor(objectiveAuraControl, currentX, currentY, Fyr_MM_Scroll_Map_Objectives)
                            objectiveAuraControl.keepId = okeepId
                            objectiveAuraControl.objectiveId = objectiveId
                            objectiveAuraControl.tooltipId = 3
                            objectiveAuraControl:SetColor(auraR, auraG, auraB, auraA)
                            objectiveAuraControl.tint = ZO_ColorDef:New(auraR, auraG, auraB, auraA)
                            objectiveAuraControl:SetMouseEnabled(true)
							
							              objectiveControl.hasAura = true -- test 05/09/2023

                            if FyrMM.SV.borderAVABG then --  create borderpin
                                FyrMM.AVABGobjectivesToBorderPins = FyrMM.AVABGobjectivesToBorderPins or {}
                                if objectiveAuraControl then
                                    objectiveAuraControl.AVABGtype = "aura"
                                    FyrMM.AVABGobjectivesToBorderPins["aura" .. tostring(objectiveId)] = objectiveAuraControl
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    FyrMM.UpdateAVABGobjectivesBusy = false
end

-------------------------------------------------------------
-- Miscelaneous functions
-------------------------------------------------------------
function FyrMM.IsCoordinatesInMap(nX, nY)
    if nX <= 1 and nX >= 0 and nY <= 1 and nY >= 0 then
        return true
    else
        return false
    end
end

function FyrMM.SetCurrentMapZoom(newZoom)
    CurrentMap.ZoomLevel = newZoom
    if FyrMM.SV.ZoomTable ~= nil then
        if CurrentMap.filename == nil or CurrentMap.filename == "" then
            local filename, _, _ = FyrMM.GetCurrentMapTextureFileInfo()
            CurrentMap.filename = string.lower(filename)
        end

        FyrMM.SV.ZoomTable[CurrentMap.filename] = newZoom
         --d("set new zoom to "..newZoom.." for "..CurrentMap.filename )
    end
    Fyr_MM_ZoomLevel:SetText(newZoom)
end

function FyrMM.UnregisterUpdates(fromRegister)
    if FyrMM.HaltTimeOffset + 1000 > GetFrameTimeMilliseconds() then
        return
    end
    -- if not fromRegister then d("unregister updates") end
    FyrMM.Halted = true
    FyrMM.HaltTimeOffset = GetFrameTimeMilliseconds()
    EVENT_MANAGER:UnregisterForUpdate("OnUpdateFyrMMMapPins")
    EVENT_MANAGER:UnregisterForUpdate("OnUpdateFyrMMMapGroupPins")
    EVENT_MANAGER:UnregisterForUpdate("OnUpdateFyrMMMapPosition")
    EVENT_MANAGER:UnregisterForUpdate("FyrMiniMapMovingObjectivesUpdate")
    EVENT_MANAGER:UnregisterForUpdate("FyrMiniMapRWUpdate")
    EVENT_MANAGER:UnregisterForUpdate("FyrMiniMapRescale")
    EVENT_MANAGER:UnregisterForUpdate("FyrMiniMapWayshrineDistances")
    EVENT_MANAGER:UnregisterForUpdate("FyrMiniMapBorderPins")
	  EVENT_MANAGER:UnregisterForUpdate("FyrMiniMapKeepRefreshCheck") 
    EVENT_MANAGER:UnregisterForUpdate("OnFyrMMZoomAnimate") -- just in case it is stuck
	  EVENT_MANAGER:UnregisterForUpdate("FyrMiniMapClockUpdate") 
end

function FyrMM.RegisterUpdates()
    if not FyrMM.Halted then
        return
    end
    FyrMM.UnregisterUpdates(true)
    CancelUpdates()
    FyrMM.Halted = false
    FyrMM.HaltTimeOffset = 0
    -- d("register updates")

    EVENT_MANAGER:RegisterForUpdate("OnUpdateFyrMMMapPins", FyrMM.SV.PinRefreshRate, FyrMM.PinUpdate)
    EVENT_MANAGER:RegisterForUpdate("OnUpdateFyrMMMapGroupPins", FyrMM.SV.MapRefreshRate, FyrMM.RefreshGroup)
    EVENT_MANAGER:RegisterForUpdate("OnUpdateFyrMMMapPosition", FyrMM.SV.MapRefreshRate, FyrMM.PositionUpdate)
    EVENT_MANAGER:RegisterForUpdate("FyrMiniMapMovingObjectivesUpdate", FyrMM.SV.MapRefreshRate, FyrMM.UpdateAVABGobjectives)
    EVENT_MANAGER:RegisterForUpdate("FyrMiniMapRWUpdate", 1001, UpdateWheelPins)
    EVENT_MANAGER:RegisterForUpdate("FyrMiniMapRescale", 60, RescalePinPositions)
    EVENT_MANAGER:RegisterForUpdate("FyrMiniMapWayshrineDistances", 5000, function() WayshrineDistances() zo_callLater(KeepDistances, 500) zo_callLater(SkyshardDistances, 1000) zo_callLater(QuestGiverDistances, 1500) end)
	  EVENT_MANAGER:RegisterForUpdate("FyrMiniMapBorderPins", 2000, FyrMM.PlaceBorderPins)
	  EVENT_MANAGER:RegisterForUpdate("FyrMiniMapKeepRefreshCheck", 1000, FyrMM.KeepRefreshCheck)
    if FyrMM.SV.ShowClock then
       EVENT_MANAGER:RegisterForUpdate("FyrMiniMapClockUpdate", 1000, FyrMM.ClockCheck)
    else
         FyrMM.ClockCheck()
    end
	
	  EVENT_MANAGER:UnregisterForUpdate("OnFyrMMZoomAnimate") -- just in case it is stuck
	
	if FyrMM.UpdateCustomPinGroupLater then -- update pins which changed when map was not showing
		if FyrMM.UpdateCustomPinGroupLater["all"] then
		   FyrMM.UpdateCustomPinGroup()
	     return	
		end 
		for k,_ in pairs(FyrMM.UpdateCustomPinGroupLater) do
			FyrMM.UpdateCustomPinGroup(k)
		end
	end
end

-------------------------------------------------------------
-- On Initialized
-------------------------------------------------------------
function FyrMM.LoadScreen() -- Initialize Player group events
    if not FyrMM.SV.StartupInfo then
        d("|ceeeeeeMiniMap by Fyrakin continued by |c3CB371@Masteroshi430|r |ceeeeee v" .. FyrMM.Panel.version .. "|r")
    end

    FyrMM.SV.PanelVersion = FyrMM.Panel.version

    if FYRMM_ZOOM_INCREMENT_AMOUNT == nil then
        FYRMM_ZOOM_INCREMENT_AMOUNT = 1
    end

    EVENT_MANAGER:RegisterForEvent("MiniMapOnGroupMemberJoined", EVENT_GROUP_MEMBER_JOINED, FyrMM.GroupEvent)
    EVENT_MANAGER:RegisterForEvent("MiniMapOnGroupmemberLeft", EVENT_GROUP_MEMBER_LEFT, function() FyrMM.ClearGroupPins() FyrMM.GroupEvent() end)
    EVENT_MANAGER:RegisterForEvent("MiniMapOnGroupDisbanded", EVENT_GROUP_DISBANDED, FyrMM.GroupEvent)
    EVENT_MANAGER:RegisterForEvent("MiniMapOnLeaderUpdated", EVENT_LEADER_UPDATE, FyrMM.GroupEvent)
	  EVENT_MANAGER:RegisterForEvent("MiniMapOnUnitRenamed", EVENT_UNIT_CHARACTER_NAME_CHANGED, FyrMM.GroupEvent)
    FyrMM.GroupEvent()
    FyrMM.UpdateQuestPins()
    FyrMM.getHouseStatus()
    zo_callLater(function() FyrMM.HideCheck()  end, 100)
	
	  IsCompanionAround = DoesUnitExist("companion")
    
    
    if IsInGamepadPreferredMode() then -- we set the fonts for gamepad mode
           FyrMM.HeaderFontType = "ZoFontGamepad36"
           FyrMM.DefaultFontType = "ZoFontGamepad18"
	         Fyr_MM_Axis_NE_Label:SetFont("ZoFontGamepad61".."|".."18".."|".."outline")
		       Fyr_MM_Axis_E_Label:SetFont("ZoFontGamepad61".."|".."18".."|".."outline")
           Fyr_MM_Axis_SE_Label:SetFont("ZoFontGamepad61".."|".."18".."|".."outline")
           Fyr_MM_Axis_S_Label:SetFont("ZoFontGamepad61".."|".."18".."|".."outline")
           Fyr_MM_Axis_SW_Label:SetFont("ZoFontGamepad61".."|".."18".."|".."outline")
           Fyr_MM_Axis_W_Label:SetFont("ZoFontGamepad61".."|".."18".."|".."outline")
           Fyr_MM_Axis_NW_Label:SetFont("ZoFontGamepad61".."|".."18".."|".."outline")
           Fyr_MM_Axis_N_Label:SetFont("ZoFontGamepad61".."|".."18".."|".."outline")
           Fyr_MM_Position:SetFont("ZoFontGamepad61".."|".."18".."|".."outline")
           Fyr_MM_ZoomLevel:SetFont("ZoFontGamepad61".."|".."18".."|".."outline")
           Fyr_MM_Zone:SetFont("ZoFontGamepad61".."|".."18".."|".."outline")
           Fyr_MM_SpeedLabel:SetFont("ZoFontGamepad61".."|".."18".."|".."outline")
    else
           FyrMM.HeaderFontType = "ZoFontHeader"
           FyrMM.DefaultFontType = ""
    end

    EVENT_MANAGER:UnregisterForEvent("MiniMap", EVENT_PLAYER_ACTIVATED)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_PLAYER_ACTIVATED, function() FyrMM.getHouseStatus() zo_callLater(function() FyrMM.HideCheck()  end, 1000) end)
end

function FyrMM.InitialPreload() -- Also called when zoning or reloading via keybinds 
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "FyrMM.InitialPreload Start:")
    end

	--d("go")
	FyrMM.InitialPreloadTimeStamp = GetFrameTimeMilliseconds()
	FyrMM.SV.DebugLog = nil
	
	if FyrMM.Reloading then
		return
	end

	FyrMM.SetMapToPlayerLocation()
	CurrentMap.ZoneIndex = GetCurrentMapZoneIndex()
	FyrMM.UpdateMapInfo()
	FyrMM.UpdateMapTiles(true)
	FyrMM.Show()
	FyrMM.MapHalfDiagonal()
	FyrMM.PositionUpdate()
	FyrMM.GroupEvent()
	FyrMM.UpdateQuestPins()
	CurrentMap.needRescale = true
	RescalePinPositions()

	if FyrMM.SV.BorderPins then
		FyrMM.PlaceBorderPins()
	end

	if IsInAvAZone() then
		FyrMM.RequestKeepRefresh()
	end

	FyrMM.Reloading = false
	FyrMM.PinUpdate()
	FyrMM.UpdateAntiquityDigSites()

	if FyrMM.DebugMode then
		CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "FyrMM.InitialPreload Done." ..
			tostring(GetGameTimeMilliseconds() - FyrMM.InitialPreloadTimeStamp))
	end
	
	FyrMM.RegisterUpdates()

     --d("preload time = "..GetFrameTimeMilliseconds()-FyrMM.InitialPreloadTimeStamp) -- 450/500ms is too much!
end


function FyrMM.CheckForNewCustomPins()
    if not ZO_IsTableEmpty(FyrMM.CustomPinCheckList) then
        for i, n in pairs(FyrMM.CustomPinCheckList) do
            for p, j in pairs(n) do
                if j.Id == 0 then
                    if j.m_PinType ~= nil and j.normalizedX ~= nil and j.normalizedY ~= nil then
                        local r = {
                            m_PinType = i,
                            m_PinTag = j.m_PinTag,
                            normalizedX = j.normalizedX,
                            normalizedY = j.normalizedY,
                            radius = j.radius
                        }
                        table.insert(FyrMM.CustomPinList[i], r)
                        FyrMM.CustomPinCheckList[i][p].Id = #FyrMM.CustomPinList[i]
                    end
                end
            end
        end
    end
    detectedNewCustomPin = false
end

function FyrMM.FastTravelInteraction(Interacting, Index, EventCode)
    if FyrMM.DebugMode then
        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "FyrMM.FastTravelInteraction (" .. tostring(Interacting) .. ") "..tostring(Index))
    end
    if Interacting then
        FyrMM.FastTravelOpen = true
        --FyrMM.UnregisterUpdates()
        -- CancelUpdates()
        FyrMM.Reloading = true
    else
        --CurrentTasks = {}
        FyrMM.Reloading = false
        FyrMM.FastTravelOpen = false
    end
end

function FyrMM.ResetOrLoadCustomPinList()
    if Fyr_MM:IsHidden() then
        return
    end
	
    -- d("Load custom pins")
    if PRCustomPins then
        if not ZO_IsTableEmpty(PRCustomPins) then
            FyrMM.CustomPinList = {}
            FyrMM.CustomPinCheckList = {}
            for i, n in pairs(PRCustomPins) do
                FyrMM.UpdateCustomPinGroup(i)
            end
			FyrMM.UpdateCustomPinGroupLater = {}
	        FyrMM.customPinsUpdateCount = nil 
        end
    end
end


local _FindPin = _G["ZO_WorldMapPins_Manager"].FindPin

local function FindPin(obj, pinTypeString, pinType, pinIndex)
    -- pinTypeString = lookupType
    -- pinType = majorIndex
    -- pinIndex = keyIndex
    
    if FyrMM.LoadingCustomPins then
        if FyrMM.LoadingCustomPins[pinType] then
            return nil
        end
    end
    return _FindPin(obj, pinTypeString, pinType, pinIndex)
end

_G["ZO_WorldMapPins_Manager"].FindPin = FindPin

local _CreatePin = _G["ZO_WorldMapPins_Manager"].CreatePin

local function CreatePin(obj, pinType, pinTag, x, y, radius, borderInformation, isSymbolicLoc)
    if obj == nil or pinType == nil then 
        return
    end
    
    radius = radius or 0

    if PinRef == nil then
        PinRef = obj
        FyrMM.PinRef = obj
        PRCustomPins = obj.customPins
        if PinRef and PinRef.playerPin and PinRef.playerPin.PIN_DATA then
            ZOpinData = PinRef.playerPin.PIN_DATA
            FyrMM.ZOpinData = ZOpinData
        end
    end

    local mapId = FyrMM.GetMapId()
    if not FyrMM.worldMapShowing and CurrentMap.MapId ~= mapId and not Fyr_MM:IsHidden() and FyrMM.CheckingZone == false then
        FyrMM.ZoneCheck()
        if FyrMM.DebugMode then
            CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "CreatePin detected New Map ID:" .. tostring(mapId))
        end
    end
    
    if not FyrMM.worldMapShowing then
       CustomPinMapId = CurrentMap.MapId
    end


    if CurrentMap.MapId == mapId and not FyrMM.worldMapShowing and not FyrMM.FastTravelOpen and x ~= nil and y ~= nil and CustomWaypoints[pinType] and CustomPinMapId ~= 0 then 
        if pinType == MAP_PIN_TYPE_PING and FyrMM.Ping ~= nil then
            FyrMM.Ping.nX = x
            FyrMM.Ping.nY = y
            FyrMM.Ping:RefreshAnchor()
        end
        if pinType == MAP_PIN_TYPE_RALLY_POINT and FyrMM.Rally ~= nil then
            FyrMM.Rally.nX = x
            FyrMM.Rally.nY = y
            FyrMM.Rally:RefreshAnchor()
        end
        if pinType == MAP_PIN_TYPE_PLAYER_WAYPOINT and FyrMM.Waypoint ~= nil then
            FyrMM.Waypoint.nX = x
            FyrMM.Waypoint.nY = y
            FyrMM.Waypoint:RefreshAnchor()
        end
    end

    local newPin = false
    local key = ""
    local r = {}

    if not FyrMM.worldMapShowing and PRCustomPins[pinType] or ZONE_EXPLORATION_PIN_TYPES[pinType] then 
        key = string.format("%s:%s:%s", x, y, radius)
        r = {
            m_PinType = pinType,
            m_PinTag = pinTag,
            normalizedX = x,
            normalizedY = y,
            radius = radius
        }

        if FyrMM.CustomPinCheckList[pinType] == nil then
            FyrMM.CustomPinCheckList[pinType] = {}
        end

        if CurrentMap.MapId == mapId and not FyrMM.worldMapShowing and not FyrMM.FastTravelOpen then
            if not FyrMM.LoadingCustomPins[pinType] then
                if FyrMM.CustomPinCheckList[pinType][key] == nil then
                    if FyrMM.DebugMode then
                        CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "Detected new Pin:" .. tostring(pinTag) .. " " .. tostring(pinType))
                    end
                    if pinType ~= nil then
                        if FyrMM.CustomPinList[pinType] == nil then
                            FyrMM.CustomPinList[pinType] = {}
                        end
                        table.insert(FyrMM.CustomPinList[pinType], r)
                        FyrMM.CustomPinCheckList[pinType][key] = r
                        FyrMM.CustomPinCheckList[pinType][key].Id = #FyrMM.CustomPinList[pinType]
                        detectedNewCustomPin = true
                    end
                end
            end
        end
    end

    if not FyrMM.worldMapShowing and FyrMM.LoadingCustomPins[pinType] then
        key = string.format("%s:%s:%s", x, y, radius)
        r = {
            m_PinType = pinType,
            m_PinTag = pinTag,
            normalizedX = x,
            normalizedY = y,
            radius = radius
        } 

        if FyrMM.DebugMode then
            CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "Create Pin:" .. tostring(pinTag) .. " " .. tostring(pinType))
        end
		
        if pinType then
            if FyrMM.CustomPinList[pinType] == nil then
                FyrMM.CustomPinList[pinType] = {}
            end
            table.insert(FyrMM.CustomPinList[pinType], r)
            FyrMM.CustomPinCheckList[pinType][key] = r
            FyrMM.CustomPinCheckList[pinType][key].Id = #FyrMM.CustomPinList[pinType]
        end

        local timeout = 100
		    -- bigger timeout for destinations addon, QuestMap addon pintypes, SLOW ADDONS, LOTS OF DATA -- TODO: check with mappins addon
        if string.sub(PRCustomPins[pinType].pinTypeString, 1, 4) == "DEST" or string.find(PRCustomPins[pinType].pinTypeString, "QuestMap") then 
            timeout = 200
        end

        zo_callLater(function() -- zo_callLater ok
            FyrMM.LoadingCustomPins[pinType] = false
        end, timeout) 

        -- Compatibility with WaypointIt code:
        if WaypointIt then
            local func = function()
                return false
            end
            r.IsGroup = func
            r.IsPOI = func
            r.IsLocation = func
            r.IsQuest = func
            r.IsAvAObjective = func
            r.IsKeep = func
            r.IsMapPing = func
            r.IsKillLocation = func
            r.IsFastTravelKeep = func
            r.IsFastTravelWayShrine = func
            r.IsForwardCamp = func
            r.IsAvARespawn = func
            r.UpdateLocation = function()
            end
            r.GetNormalizedPosition = function(self)
                return self.normalizedX, self.normalizedY
            end
            r.GetPinTypeAndTag = function(self)
                return self.m_PinType, self.m_PinTag
            end
            r.PIN_DATA = ZOpinData
        end

        return r
    else
        if FyrMM.DebugMode then
            CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "Passed Create Pin:"..tostring(pinTag).." ".. tostring(pinType))
        end
        local pin = _CreatePin(obj, pinType, pinTag, x, y, radius, borderInformation, isSymbolicLoc)
        return pin
    end
end

-- needed to get custom pins
_G["ZO_WorldMapPins_Manager"].CreatePin = CreatePin

function FyrMM.LoadCustomPinGroup(Type)
    if Fyr_MM:IsHidden() then
		FyrMM.UpdateCustomPinGroupLater = FyrMM.UpdateCustomPinGroupLater or {}
		FyrMM.UpdateCustomPinGroupLater[Type] = true
        return
    end
	
    if PRCustomPins and PRCustomPins[Type] and PRCustomPins[Type].enabled and PRCustomPins[Type].layoutCallback and type(PRCustomPins[Type].layoutCallback) == "function" then
        local gameTime = GetGameTimeMilliseconds()


        if FyrMM.LoadingCustomPins[Type] then 
            return
        end

        FyrMM.LoadingCustomPins[Type] = true 
        FyrMM.CustomPinList = FyrMM.CustomPinList or {}
        FyrMM.CustomPinList[Type] = {}
        PRCustomPins[Type].layoutCallback(PinRef)
        FyrMM.LoadingCustomPins[Type] = false

	   
	    FyrMM.customPinsUpdateCount = nil
      if FyrMM.UpdateCustomPinGroupLater and FyrMM.UpdateCustomPinGroupLater[Type] then
        FyrMM.UpdateCustomPinGroupLater[Type] = nil
      end
		
        if FyrMM.DebugMode then
            CALLBACK_MANAGER:FireCallbacks("FyrMMDebug", "FyrMM.LoadCustomPinGroup "..tostring(Type).." Done. "..tostring(GetGameTimeMilliseconds() - gameTime))
        end
    end
end

local function InitFinish()
    FyrMM.Initialized = true
    if FyrMM.SV.MenuAutoHide then
        zo_callLater(FyrMM.MenuFadeOut, 3000) -- zo_callLater OK
    end
end




function FyrMM.UpdateCustomPinGroup(pinType)
    --[[ d("UpdateCustomPinGroup triggered for "..pinType) --]]
	if pinType == nil then
	   FyrMM.ResetOrLoadCustomPinList()
	   --d("Update all custom pin groups")
	   return
	end
	
    if pinType >= MAP_PIN_TYPE_INVALID then
        -- d("UpdateCustomPinGroup "..pinType)
        if FyrMM.UpdatingCustomPins[pinType] then --[[ d("UpdateCustomPinGroup "..pinType.." not done because FyrMM.UpdatingCustomPins[pinType]") --]]
            return
        end
		
        FyrMM.UpdatingCustomPins[pinType] = true
        if FyrMM.CustomPinList[pinType] then
            -- if #FyrMM.CustomPinList[pinType] == 0 then --[[ d("UpdateCustomPinGroup "..pinType.." FyrMM.CustomPinList[pinType] is empty")--]]
                -- return
            -- end

            
            for i, n in pairs(FyrMM.CustomPinList[pinType]) do
                if n.pin then
                    local pin = GetControl(n.pin:GetName())
                    -- d("method 1: removing pin "..n.pin:GetName())
                    FyrMM.RemoveCustomPin(pin)
                else
                    local Index = n.Index or i
                    if CustomPinKeyIndex[pinType] then
                        local pin = GetControl("Fyr_MM_Scroll_Map_Pins_Pin"..tostring(CustomPinKeyIndex[pinType][Index]))
                        -- d("method 2: removing pin Fyr_MM_Scroll_Map_Pins_Pin"..tostring(CustomPinKeyIndex[pinType][Index]))
                        FyrMM.RemoveCustomPin(pin)
                    end
                end
            end
			FyrMM.UpdatingCustomPins[pinType] = nil
			FyrMM.CustomPinList[pinType] = {}
			if PRCustomPins and PRCustomPins[pinType] and PRCustomPins[pinType].enabled then
		       FyrMM.LoadCustomPinGroup(pinType)

			
				-- local pinTypeName = pinType
				-- if PRCustomPins[pinType].pinTypeString then
					-- pinTypeName = PRCustomPins[pinType].pinTypeString
				-- end			
				-- d("Update custom pin group |cFFFFFF"..pinTypeName.. "|r after removing pins") 
			end
        else
            --[[ d("UpdateCustomPinGroup FyrMM.CustomPinList[pinType] is nil") --]]
			FyrMM.UpdatingCustomPins[pinType] = nil
            FyrMM.CustomPinList[pinType] = {}
            if PRCustomPins and PRCustomPins[pinType] and PRCustomPins[pinType].enabled then
		       FyrMM.LoadCustomPinGroup(pinType)
			   
			    -- local pinTypeName = pinType
				-- if PRCustomPins[pinType].pinTypeString then
					-- pinTypeName = PRCustomPins[pinType].pinTypeString
				-- end	
				-- d("Update custom pin group |cFFFFFF"..pinTypeName.. "|r after creating it")
			end   
			

        end
        
    end
end

local function SetPinLocation(pin, nX, nY, radius)
    pin.nX = nX
    pin.nY = nY
    pin.radius = radius
    if CustomPinCrossReference[pin] then
        CustomPinCrossReference[pin].nX = nX
        CustomPinCrossReference[pin].nY = nY
        CustomPinCrossReference[pin].radius = radius
        FyrMM.SetPinAnchor(CustomPinCrossReference[pin], nX, nY, Fyr_MM_Scroll_Map_Pins)
    end
end

function FyrMM.getHouseStatus() 
    if GetCurrentZoneHouseId() > 0 then -- we check if we are in a house
        FyrMM.isInHouse = true
    else
        FyrMM.isInHouse = false
    end
	if not IsInCyrodiil() and FyrMM.ForwardCampPreview then FyrMM.ForwardCampPreview = nil end -- reset the forward camp preview pin when leaving Cyrodiil
	zo_callLater(function() if not Fyr_MM:IsHidden() then FyrMM.RegisterUpdates() end end, 100) -- added to avoid the map frozen just after leaving a dungeaon instance 26/05/2023
end

function FyrMM.UnregisterForLoadingScreen() 
     FyrMM.UnregisterUpdates()
end

local function OnInit() -- Initialize Map and Update events after add-on load
    Fyr_MM_Frame_Control:SetAnchor(CENTER, Fyr_MM, CENTER, 0, 0)
    Fyr_MM_Wheel_Background:SetAnchor(CENTER, Fyr_MM, CENTER, 0, 0)
    Fyr_MM_Wheel_Background:SetTexture("MiniMap/Textures/wheelbackground.dds")
    Fyr_MM_Scroll_WheelNS:SetAnchor(CENTER, Fyr_MM_Scroll, CENTER, 0, 0)
    Fyr_MM_Scroll_WheelWE:SetAnchor(CENTER, Fyr_MM_Scroll, CENTER, 0, 0) 
    Fyr_MM_Scroll_WheelCenter:SetAnchor(CENTER, Fyr_MM_Scroll, CENTER, 0, 0)
    MenuAnimation = ZO_AlphaAnimation:New(Fyr_MM_Menu)

    FyrMM.LAM = LibAddonMenu2
    FyrMM.CPL = FyrMM.LAM:RegisterAddonPanel("FyrMiniMap", FyrMM.Panel)
    FyrMM.SettingsPanel = FyrMM.LAM:RegisterOptionControls("FyrMiniMap", FyrMM.Options)

    Fyr_MM:SetHandler("OnMouseWheel", function(self, delta, ctrl, alt, shift)
        if not FyrMM.SV.MouseWheel then
            return
        end
        if delta < 0 then
            FyrMM.ZoomOut()
        elseif delta > 0 then
            FyrMM.ZoomIn()
        end
    end)

    Fyr_MM_Time:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
        if upInside then
            FyrMM.TimeFormat = FyrMM.TimeFormat + 1
            if FyrMM.TimeFormat > 2 then
                FyrMM.TimeFormat = 0
            end
            FyrMM.SV.TimeFormat = FyrMM.TimeFormat
        end
    end)
    
    Fyr_MM_Time:SetHidden(true)

    if not FyrMM.SV.HideZoneLabel then
        FyrMM.UpdateLabels()
    end
    
    -- check scene change for hiding UI
    SecurePostHook(SCENE_MANAGER, "OnSceneStateChange", function()
         zo_callLater(function() FyrMM.HideCheck()  end, 100)
    end)
    
    
    
    EVENT_MANAGER:RegisterForUpdate("OnUpdateFyrMMLogPosition", 30, LogPosition)
    EVENT_MANAGER:RegisterForUpdate("OnUpdateFyrMMSpeedMeasure", 301, SpeedMeasure)
    EVENT_MANAGER:RegisterForUpdate("OnUpdateFyrMMRefreshEventUnits", 100, FyrMM.RefreshEventUnits)

    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_QUEST_ADDED, function(_, questIndex)
        if IsJournalQuestIndexInTrackedZoneStory(questIndex) then
            FyrMM.RemoveCustomPin(FyrMM.ZoneStoryPin)
            FyrMM.ZoneStoryPin = nil
        end
        FyrMM.RequestQuestPinUpdate()
    end) -- testing 27/11/2022
	
	-- EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_ZONE_STORY_QUEST_ACTIVITY_TRACKED, function(_, questIndex)
        -- if IsJournalQuestIndexInTrackedZoneStory(questIndex) then
            -- FyrMM.RemoveCustomPin(FyrMM.ZoneStoryPin)
            -- FyrMM.ZoneStoryPin = nil
        -- end
        -- FyrMM.RequestQuestPinUpdate()
    -- end) 
	
	-- EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_ZONE_STORY_ACTIVITY_UNTRACKED, function(_)
        
         -- FyrMM.RemoveCustomPin(FyrMM.ZoneStoryPin)
         -- FyrMM.ZoneStoryPin = nil

         -- --FyrMM.RequestQuestPinUpdate()
    -- end) 
	
	
	

    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_QUEST_ADVANCED, FyrMM.RequestQuestPinUpdate)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_QUEST_COMPLETE_DIALOG, FyrMM.RequestQuestPinUpdate)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_QUEST_COMPLETE, FyrMM.RequestQuestPinUpdate)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_QUEST_CONDITION_COUNTER_CHANGED, FyrMM.RequestQuestPinUpdate)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_QUEST_CONDITION_OVERRIDE_TEXT_CHANGED, FyrMM.RequestQuestPinUpdate)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_QUEST_LIST_UPDATED, FyrMM.RequestQuestPinUpdate)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_QUEST_OFFERED, FyrMM.RequestQuestPinUpdate)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_QUEST_OPTIONAL_STEP_ADVANCED, FyrMM.RequestQuestPinUpdate)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_MOUSE_REQUEST_ABANDON_QUEST, FyrMM.RequestQuestPinUpdate)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_QUEST_REMOVED, FyrMM.RequestQuestPinUpdate)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_QUEST_TOOL_UPDATED, FyrMM.RequestQuestPinUpdate)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_ACTIVE_QUEST_TOOL_CLEARED, FyrMM.RequestQuestPinUpdate)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_ACTIVE_QUEST_TOOL_CHANGED, FyrMM.RequestQuestPinUpdate)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_OBJECTIVES_UPDATED, FyrMM.RequestQuestPinUpdate)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_POI_UPDATED, FyrMM.DelayedPOIPins)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_DISCOVERY_EXPERIENCE, function()
        FyrMM.Wayshrines()
	      FyrMM.DelayedPOIPins()
    end)
    
    -- for dynamic world events
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_WORLD_EVENT_ACTIVATED, function()
        FyrMM.currentLocationsCount = 0
    end)
    
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_WORLD_EVENT_ACTIVE_LOCATION_CHANGED, function()
        FyrMM.currentLocationsCount = 0
    end)
    
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_WORLD_EVENT_DEACTIVATED, function()
        FyrMM.currentLocationsCount = 0
    end)
    
    
    
    
	
	EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_SKYSHARDS_UPDATED, FyrMM.skyshardPins) 

    -- AVA
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_KEEPS_INITIALIZED, FyrMM.RequestKeepRefresh)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_KEEP_ALLIANCE_OWNER_CHANGED, FyrMM.RequestKeepRefresh)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_KEEP_END_INTERACTION, FyrMM.RequestKeepRefresh)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_KEEP_GATE_STATE_CHANGED, FyrMM.RequestKeepRefresh)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_KEEP_GUILD_CLAIM_UPDATE, FyrMM.RequestKeepRefresh)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_KEEP_INITIALIZED, FyrMM.RequestKeepRefresh)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_KEEP_OWNERSHIP_CHANGED_NOTIFICATION, FyrMM.RequestKeepRefresh)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_KEEP_RESOURCE_UPDATE, FyrMM.RequestKeepRefresh)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_KEEP_START_INTERACTION, FyrMM.RequestKeepRefresh)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_KEEP_UNDER_ATTACK_CHANGED, FyrMM.RequestKeepRefresh)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_KILL_LOCATIONS_UPDATED, FyrMM.RequestKeepRefresh)
    EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_FORWARD_CAMPS_UPDATED, FyrMM.RequestKeepRefresh)

    FOCUSED_QUEST_TRACKER:RegisterCallback("QuestTrackerAssistStateChanged", function()
        FyrMM.UpdateQuestPinPositions()
    end)
    FOCUSED_QUEST_TRACKER:RegisterCallback("QuestTrackerRefreshedMapPins", function()
        FyrMM.RequestQuestPinUpdate()
    end)
    CALLBACK_MANAGER:RegisterCallback("OnFyrMiniNewMapEntered", DelayedReload)
    CALLBACK_MANAGER:RegisterCallback("OnFyrMiniMapChanged", FyrMM.UpdateLabels)
    CALLBACK_MANAGER:RegisterCallback("FyrMMDebug", function(value)
        if FyrMM.DebugMode then
            FyrMM.Debug_d(value)
        end
    end)

    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function(manual)
        local filename, _, _ = FyrMM.GetCurrentMapTextureFileInfo()
        if manual == nil and string.lower(CurrentMap.filename) ~= string.lower(filename) and not FyrMM.FastTravelOpen then
            FyrMM.Refresh = true
			if not FyrMM.SV.HideZoneLabel then
                FyrMM.UpdateLabels()
            end
            FyrMM.ZoneCheck()
        elseif manual == nil and (FyrMM.SV.ZoneNameContents ~= "Classic (Map only)" or (FyrMM.SV.ZoneNameContents == "Classic (Map only)" and IsPlayerInAvAWorld() and FyrMM.SV.ForceAreaOnlyInCyro)) and not FyrMM.FastTravelOpen then -- update zone name for Map & Area and Area only option 
			if not FyrMM.SV.HideZoneLabel then
                FyrMM.UpdateLabels()
            end
        else -- change is manual
            FyrMM.Refresh = false
        end
    end)

    CALLBACK_MANAGER:RegisterCallback("OnWorldMapModeChanged", function(mode)
        zo_callLater(function()
            if ZO_WorldMap:IsHidden() then
                if SetMapToPlayerLocation() ~= SET_MAP_RESULT_CURRENT_MAP_UNCHANGED then
                    CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
                end
            else
			          FyrMM.ZoneCheck()
                FyrMM.UnregisterUpdates()
                CancelUpdates()
            end
        end, 20)
    end)

    function ZO_WorldMapPins_Manager:RefreshCustomPins(optionalPinType)
        for pinTypeId, pinData in pairs(self.customPins) do
            if optionalPinType == nil or optionalPinType == pinTypeId then
                self:RemovePins(pinData.pinTypeString)
                if optionalPinType == pinTypeId then -- and not FyrMM.worldMapShowing is a workaround for destinations addon's pins disapearing when opening world map 21/12/2022 
					if not FyrMM.worldMapShowing and not FyrMM.Halted then
					    FyrMM.UpdateCustomPinGroup(optionalPinType)
					elseif not FyrMM.worldMapShowing then
					    if optionalPinType == nil then 
						     optionalPinType = "all"
              end						
					    FyrMM.UpdateCustomPinGroupLater = FyrMM.UpdateCustomPinGroupLater or {}
						  FyrMM.UpdateCustomPinGroupLater[optionalPinType] = true
					end
                end 

                if pinData.enabled then
                    pinData.layoutCallback(self)
                end
            elseif optionalPinType == pinData.pinTypeString then -- compatibility with map pins addon and other addons using pinTypeString to remove pins
				     if not FyrMM.worldMapShowing and not FyrMM.Halted then
					     FyrMM.UpdateCustomPinGroup(pinTypeId)
					 elseif not FyrMM.worldMapShowing then
					     if pinTypeId == nil then 
						   pinTypeId = "all"
                         end	
					     FyrMM.UpdateCustomPinGroupLater = FyrMM.UpdateCustomPinGroupLater or {}
						 FyrMM.UpdateCustomPinGroupLater[pinTypeId] = true
                     end					 
            end
        end
    end
	

    ZO_PreHook(ZO_MapPin, "SetLocation", function(ref, xLoc, yLoc, radius)
        SetPinLocation(ref, xLoc, yLoc, radius)
    end)

    ZO_PreHook(COMPASS, "PerformFullAreaQuestUpdate", FyrMM.RequestQuestPinUpdate)
    ZO_PreHook(ZO_WorldMap, "SetHidden", FyrMM.WorldMapShowHide)


    if FyrMM.CustomPinsEnabled then
        for i = 1, 1200 do -- 1200
            local pin = GetControl("Fyr_MM_Scroll_Map_Pins_Pin" .. tostring(i))
            if pin == nil then
                pin = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_Pins_Pin" .. tostring(i), Fyr_MM_Scroll_Map_Pins,CT_TEXTURE)
                pin:SetDrawLayer(1)
                pin:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
                pin:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
                SetPinFunctions(pin)
            end
        end
    end

    for i = 1, 50 do -- 50
        local pin = GetControl("Fyr_MM_Scroll_Map_WayshrinePins_Pin"..tostring(i))
        if pin == nil then
            pin = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_WayshrinePins_Pin"..tostring(i), Fyr_MM_Scroll_Map_WayshrinePins, CT_TEXTURE)
            pin.nDistance = function(self)
                if self.nX == nil then
                    return 1
                end
                return zo_sqrt((zo_round(CurrentMap.PlayerNX * 10000) - zo_round(self.nX * 10000)) *
                    (zo_round(CurrentMap.PlayerNX * 10000) - zo_round(self.nX * 10000)) +
                    (zo_round(CurrentMap.PlayerNY * 10000) - zo_round(self.nY * 10000)) *
                    (zo_round(CurrentMap.PlayerNX * 10000) - zo_round(self.nY * 10000))) / 10000
            end
            pin:SetDrawLayer(1)
            pin:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
            pin:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
            pin:SetHandler("OnMouseUp", PinOnMouseUp)
            SetPinFunctions(pin)
        end
    end
    for i = 1, 50 do -- 50
        local pin = GetControl("Fyr_MM_Scroll_Map_LocationPins_Pin" .. tostring(i))
        if pin == nil then
            pin = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_LocationPins_Pin" .. tostring(i),
                Fyr_MM_Scroll_Map_LocationPins, CT_TEXTURE)
            pin:SetDrawLayer(1)
            pin:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
            pin:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
            SetPinFunctions(pin)
        end
    end

    for i = 1, 100 do -- 100
        local pin = GetControl("Fyr_MM_Scroll_Map_POIPins_Pin" .. tostring(i))
        if pin == nil then
            pin = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_POIPins_Pin"..tostring(i), Fyr_MM_Scroll_Map_POIPins, CT_TEXTURE)
            pin:SetDrawLayer(1)
            pin:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
            pin:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
            SetPinFunctions(pin)
        end
    end
	
    for i = 1, 50 do 
        local pin = GetControl("Fyr_MM_Scroll_Map_SkyshardPins_Pin"..tostring(i))
        if pin == nil then
            pin = WINDOW_MANAGER:CreateControl("Fyr_MM_Scroll_Map_SkyshardPins_Pin"..tostring(i), Fyr_MM_Scroll_Map_SkyshardPins, CT_TEXTURE)
            pin:SetDrawLayer(2)
            pin:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
            pin:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
            SetPinFunctions(pin)
        end
    end

    for i = 1, 50 do -- 100
        local pin = GetControl("Fyr_MM_Axis_Border_Pin" .. tostring(i))
        if pin == nil then
            pin = WINDOW_MANAGER:CreateControl("Fyr_MM_Axis_Border_Pin"..tostring(i), Fyr_MM_Axis_Border_Pins, CT_TEXTURE)
            pin:SetDrawLayer(1)
            SetBorderPinHandlers(pin)
        end
    end

    for i = 1, MAX_GROUP_SIZE_THRESHOLD do 
        local pin = GetControl("Fyr_MM_Scroll_Map_GroupPins_group"..tostring(i))
        if pin then
            pin:SetDrawLayer(1)
            pin:SetHandler("OnMouseEnter", FyrMM.PinOnMouseEnter)
            pin:SetHandler("OnMouseExit", FyrMM.PinOnMouseExit)
            SetPinFunctions(pin)
        end
    end
	
    zo_callLater(InitFinish, 100) -- zo_callLater ok
end

function FyrMM.MenuFadeIn()
    if Fyr_MM_Menu:GetAlpha() > 0 or FyrMM.SV.MenuDisabled or FyrMM.MenuFadingIn or Fyr_MM:IsHidden() then
        return
    end
    FyrMM.MenuFadingIn = true
    if FyrMM.SV.ZoneFrameLocationOption == "Default" then
        Fyr_MM_ZoneFrame:ClearAnchors()
        if FyrMM.SV.WheelMap then
            Fyr_MM_ZoneFrame:SetAnchor(TOP, Fyr_MM_Menu, BOTTOM, 0, -Fyr_MM_Menu:GetHeight() / 5)
        else
            Fyr_MM_ZoneFrame:SetAnchor(TOP, Fyr_MM_Menu, BOTTOM, 0, -Fyr_MM_Menu:GetHeight() / 2.5)
        end
        Fyr_MM_ZoneFrame:SetMovable(false)
    end
    if FyrMM.OverMiniMap or FyrMM.OverMenu then
        MenuAnimation:FadeIn(0, 1000, ZO_ALPHA_ANIMATION_OPTION_FORCE_ALPHA, function()
            FyrMM.MenuFadingIn = false
        end)
    end
end

function FyrMM.MenuFadeOut()
    if not FyrMM.SV.MenuAutoHide or FyrMM.OverMiniMap or FyrMM.OverMenu or Fyr_MM_Menu:GetAlpha() == 0 or
        FyrMM.SV.MenuDisabled or FyrMM.MenuFadingOut then
        return
    end
    FyrMM.MenuFadingOut = true
    MenuAnimation:FadeOut(0, 1000, ZO_ALPHA_ANIMATION_OPTION_FORCE_ALPHA, function()
        FyrMM.MenuFadingOut = false
        if FyrMM.SV.ZoneFrameLocationOption == "Default" then
            Fyr_MM_ZoneFrame:ClearAnchors()
            Fyr_MM_ZoneFrame:SetAnchor(TOP, Fyr_MM_Border, BOTTOM)
            Fyr_MM_ZoneFrame:SetMovable(false)
        end
    end)
end

local function UpdateZoomTable()
    if FyrMM.SV.ZoomTable then
        local t = {}
        for i, n in pairs(FyrMM.SV.ZoomTable) do
            t[i] = n
        end
        FyrMM.SV.ZoomTable = t
        FyrMM.SV.MapTable = nil
    end
    if FyrMM.SV.MapTable then
        FyrMM.SV.ZoomTable = {}
        for i, n in pairs(FyrMM.SV.MapTable) do
            FyrMM.SV.ZoomTable[i] = n.ZoomLevel
        end
        FyrMM.SV.MapTable = nil
    end
end

local function OnLoaded(eventCode, addOnName)
    if addOnName ~= "MiniMap" then
        return
    end
	
    FyrMM.Initialized = false
    MM_CreateDataTables()
    FyrMM.SV = ZO_SavedVars:NewAccountWide("FyrMMSV", 5, nil, FyrMM.Defaults, nil)
    if FyrMM.SV then
        UpdateZoomTable()
        MM_LoadSavedVars()
    end
    FyrMM.API_Check()

    if not FyrMM.HudElementRegistered then
        HUD_MANAGER:RegisterKeyboardElement(GetControl("Fyr_MM"), "Minimap by Fyrakin", { defaultAnchor = ZO_Anchor:New(TOP, nil, TOP, 0, 40) }, COMPASS_OPTIONS) -- for Keyboard UI
        HUD_MANAGER:RegisterGamepadElement(GetControl("Fyr_MM"), "Minimap by Fyrakin", { defaultAnchor = ZO_Anchor:New(TOP, nil, TOP, 0, 40) }, COMPASS_OPTIONS) --for Gamepad UI
        FyrMM.HudElementRegistered = true
    end

    Fyr_MM:SetResizeHandleSize(MOUSE_CURSOR_RESIZE_NS)
    Fyr_MM:SetHandler("OnMouseEnter", function()
        FyrMM.OverMiniMap = true
        FyrMM.MenuFadeIn()
        Fyr_MM_Close:SetAlpha(1)
    end)
    Fyr_MM:SetHandler("OnMouseExit", function()
        FyrMM.OverMiniMap = false
        zo_callLater(FyrMM.MenuFadeOut, 3000) -- zo_callLater ok
        Fyr_MM_Close:SetAlpha(0)
    end)
    Fyr_MM_Menu:SetHandler("OnMouseEnter", function()
        FyrMM.OverMenu = true
        FyrMM.MenuFadeIn()
        Fyr_MM_Close:SetAlpha(1)
    end)
    Fyr_MM_Menu:SetHandler("OnMouseExit", function()
        FyrMM.OverMenu = false
        zo_callLater(FyrMM.MenuFadeOut, 3000) -- zo_callLater ok
        Fyr_MM_Close:SetAlpha(0)
    end)
    -- Fyr_MM:SetHandler("OnMouseUp", function(self)
        -- if not FyrMM.SV.LockResizing then
            -- local width = Fyr_MM:GetWidth()
            -- local height = Fyr_MM:GetHeight()
            -- MM_SetMapWidth(width)
            -- MM_SetMapHeight(height)
            -- FyrMM.SV.position.offsetX = Fyr_MM:GetLeft()
            -- FyrMM.SV.position.offsetY = Fyr_MM:GetTop()
            -- FyrMM.MapHalfDiagonal()
            -- MM_RefreshPanel()
        -- else
            -- local pos = {}
            -- pos.anchorTo = GetControl(pos.anchorTo)
            -- Fyr_MM:SetAnchor(FyrMM.SV.position.point, pos.anchorTo, FyrMM.SV.position.relativePoint,
            -- FyrMM.SV.position.offsetX, FyrMM.SV.position.offsetY)
            -- Fyr_MM:SetDimensions(FyrMM.SV.MapWidth, FyrMM.SV.MapHeight)
        -- end
    -- end)
    Fyr_MM_Coordinates:SetHandler("OnMouseUp", function(self)
        local pos = {}
		pos[1] = CENTER 
		pos[2] = "GuiRoot"
	    pos[3] = TOPLEFT

        local coordFrameX, coordFrameY = Fyr_MM_Coordinates:GetCenter()
        pos[4] = coordFrameX
		pos[5] = coordFrameY
        FyrMM.SV.CoordinatesAnchor = pos
    end)
    Fyr_MM_ZoneFrame:SetHandler("OnMouseUp", function(self) 
        local pos = {}
        pos[1] = CENTER 
		pos[2] = "GuiRoot"
	    pos[3] = TOPLEFT

        local zoneFrameX, zoneFrameY = Fyr_MM_ZoneFrame:GetCenter()
        pos[4] = zoneFrameX
		pos[5] = zoneFrameY
        FyrMM.SV.ZoneFrameAnchor = pos
        --d("Zone frame anchor set to: " .. pos[1] .. " " .. pos[2] .. " " .. pos[3] .. " " .. pos[4] .. " " .. pos[5])
    end)
    Fyr_MM_Speed:SetHandler("OnMouseUp", function(self)
        local pos = {}
        pos[1] = CENTER 
		pos[2] = "GuiRoot"
	    pos[3] = TOPLEFT
		
        local speedFrameX, speedFrameY = Fyr_MM_Speed:GetCenter()
        pos[4] = speedFrameX
		pos[5] = speedFrameX
        FyrMM.SV.SpeedAnchor = pos
    end)
    Fyr_MM_Scroll:SetScrollBounding(0)
    Fyr_MM_Player_incombat:SetTexture("esoui/art/mappins/ava_attackburst_32.dds")
    Fyr_MM_Player_incombat:SetAlpha(0.50)


    AxisSwitch()
    zo_callLater(OnInit, 10) -- zo_callLater ok -- 1000
end

-----------------------------------------
-- Key bind functions
-----------------------------------------

function FyrMM.ZoomOut()
    if not FyrMM.Visible or Fyr_MM:IsHidden() or ZoomAnimating then
        return
    end
	
    local zoomLevel = CurrentMap.ZoomLevel
    zoomLevel = zoomLevel - FYRMM_ZOOM_INCREMENT_AMOUNT
	
    if zoomLevel < FYRMM_ZOOM_MIN then
        zoomLevel = FYRMM_ZOOM_MIN
    end
	
    if not ZoomAnimating and zoomLevel ~= CurrentMap.ZoomLevel then
	    ZoomAnimating = true
        AnimateZoom(zoomLevel)
    end
end

function FyrMM.ZoomIn()
    if not FyrMM.Visible or Fyr_MM:IsHidden() or ZoomAnimating then
        return
    end
	
    local zoomLevel = CurrentMap.ZoomLevel
    zoomLevel = zoomLevel + FYRMM_ZOOM_INCREMENT_AMOUNT
	
    if zoomLevel > FYRMM_ZOOM_MAX then
        zoomLevel = FYRMM_ZOOM_MAX
    end
	
    if not ZoomAnimating and zoomLevel ~= CurrentMap.ZoomLevel then
	    ZoomAnimating = true
        AnimateZoom(zoomLevel)
    end
end

function FyrMM.ToggleVisible()
    if not FyrMM.worldMapShowing and ZO_InteractWindow:IsHidden() and ZO_KeybindStripControl:IsHidden() then
        if FyrMM.Visible then
            PlaySound(SOUNDS.MAP_WINDOW_CLOSE) 
            FyrMM.manuallyHidden = true
        else
            PlaySound(SOUNDS.MAP_WINDOW_OPEN)
            FyrMM.manuallyHidden = false
        end
        FyrMM.Visible = not FyrMM.Visible
    end
    FyrMM.HideCheck()
end

EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_QUEST_POSITION_REQUEST_COMPLETE, OnQuestPositionRequestComplete)
EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_ADD_ON_LOADED, OnLoaded)
EVENT_MANAGER:RegisterForEvent( "MiniMap", EVENT_ZONE_CHANGED, FyrMM.UpdateLabels)
-- EVENT_MANAGER:RegisterForEvent( "MiniMap", EVENT_ZONE_UPDATE, function (eventCode, unitTag, newZoneName) d(eventCode) d(unitTag) d(newZoneName) end)
EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_PLAYER_ACTIVATED, FyrMM.LoadScreen)
EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_PLAYER_DEACTIVATED, FyrMM.UnregisterForLoadingScreen)

EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_START_FAST_TRAVEL_INTERACTION, function(eventCode, index)
    FyrMM.FastTravelInteraction(true, index, eventCode)
end)
EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_END_FAST_TRAVEL_INTERACTION, function(eventCode)
    FyrMM.FastTravelInteraction(false, nil, eventCode)
end)
EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_START_FAST_TRAVEL_KEEP_INTERACTION, function(eventCode, index)
    FyrMM.FastTravelInteraction(true, index, eventCode)
end)
EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_END_FAST_TRAVEL_KEEP_INTERACTION, function(eventCode)
    FyrMM.FastTravelInteraction(false, nil, eventCode)
end)
EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_MOUNTED_STATE_CHANGED, function(eventCode, mounted)
    CurrentMap.PlayerMounted = mounted
end)
EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_PLAYER_NOT_SWIMMING, function(eventCode)
    CurrentMap.PlayerSwimming = false
end)
EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_PLAYER_SWIMMING, function(eventCode)
    CurrentMap.PlayerSwimming = true
end)
EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_ANTIQUITY_DIG_SITES_UPDATED, function(eventCode, antiquityId)
    FyrMM.UpdateAntiquityDigSites()
end)

EVENT_MANAGER:RegisterForEvent( "MiniMap", EVENT_PLAYER_COMBAT_STATE, FyrMM.HideCheck)

EVENT_MANAGER:RegisterForEvent( "MiniMap", EVENT_PLAYER_ALIVE, FyrMM.HideCheck)


EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_MAP_PING, function(eventCode, pingEventType, pinType, _, x, y)
    -- we avoid using ping pin types because it is monopolysed by some addons spamming it for sharing data
    if pinType ~= MAP_PIN_TYPE_PING then FyrMM.WaypointPins(pingEventType, pinType, x, y) end 
end)

CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
    if panel ~= FyrMM.CPL then return end
	  FyrMM.AreFyrmmSettingsShowing = true
    FyrMM.HideCheck()
end)

CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
    if panel ~= FyrMM.CPL then return end
    FyrMM.AreFyrmmSettingsShowing = false
    FyrMM.HideCheck()
end)

EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_COMPANION_ACTIVATED, function(eventCode)
    IsCompanionAround = true
end)

EVENT_MANAGER:RegisterForEvent("MiniMap", EVENT_COMPANION_DEACTIVATED, function(eventCode)
    IsCompanionAround = false
end)
