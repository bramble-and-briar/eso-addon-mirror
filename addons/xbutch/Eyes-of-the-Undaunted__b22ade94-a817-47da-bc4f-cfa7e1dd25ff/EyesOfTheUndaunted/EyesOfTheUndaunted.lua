-- Eyes of the Undaunted - show dungeon boss locations
EOTU = EOTU or {}

local C = EOTU_Config or {
	ADDON_NAME = "EyesOfTheUndaunted",
	NAME_SHORT = "EOTU",
	NAMESPACE = "EOTU",
	SAVEDVARS = "EOTU_SavedVars",
	PIN_TYPE = "EOTU_Pin",
}

local ADDON_NAME = C.ADDON_NAME
local PIN_TYPE = C.PIN_TYPE
local MapPins = EOTU.internal and EOTU.internal.mapPins
local BossData = EOTU.internal and EOTU.internal.bossData
EOTU.pinType = PIN_TYPE

EOTU.defaults = {
	showBosses = true,
	pinSize = 24,
	showImperialCity = true,
	showPatrols = true,
}
EOTU.variableVersion = 5

local PIN_ICON = "EsoUI/Art/WorldMap/map_indexicon_locations_down.dds"

--------------------------------------------------------------------
-- Debug helper
--------------------------------------------------------------------
local debugEnabled = false
local debugCount = 0

local function ChatPrint(msg)
	if type(d) == 'function' then
		d(msg)
	elseif CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(msg)
	else
		print(msg)
	end
end

function EOTU:Print(message)
	ChatPrint("|c99CCFFEyes of the Undaunted:|r " .. tostring(message))
end

local function dbg(msg)
	if not debugEnabled then return end
	debugCount = debugCount + 1
	ChatPrint('|c99CCFF[EOTU ' .. debugCount .. ']|r ' .. msg)
end

local function SwitchDebugMode()
	if debugEnabled then
		dbg('Debug disabled')
		debugEnabled = false
		debugCount = 0
	else
		debugEnabled = true
		dbg('Debug enabled')
	end
end

--------------------------------------------------------------------
-- Map name helper
--------------------------------------------------------------------
local function GetMapBaseName()
	local texture = GetMapTileTexture()
	if not texture then return nil end
	texture = texture:lower()
	local name = texture:match("maps/(.-)%.dds")
	if not name then return nil end
	return name:match("([^/]+)$") or name
end

--------------------------------------------------------------------
-- Pin placement
--------------------------------------------------------------------
local function AddPins()
	MapPins:CancelPending()
	local mapName = GetMapBaseName()
	if not mapName then return end
	local imperial = BossData and BossData.ImperialCity
	local isImperial = imperial and imperial:IsSupportedMap(mapName)
	if not isImperial and GetMapContentType() ~= MAP_CONTENT_DUNGEON then return end
	dbg("AddPins: " .. mapName)

	if not EOTU.savedVars.showBosses then return end

	local index = BossData and BossData.ChampionTableIndex
	local getEntries = BossData and BossData.GetChampionEntriesForMap
	if not index or not getEntries then
		dbg("AddPins: boss data not loaded")
		return
	end

	local function current()
		return EOTU.savedVars.showBosses and GetMapBaseName() == mapName
			and (isImperial or GetMapContentType() == MAP_CONTENT_DUNGEON)
	end
	MapPins:QueuePins(function()
		if not current() then return end
		local function place(row)
			if not current() then return false end
			MapPins:CreatePin(PIN_TYPE, { tooltip = row[index.NAME] or "Unknown Champion" }, row[index.X], row[index.Y])
			coroutine.yield()
			return current()
		end
		if isImperial then
			if EOTU.savedVars.showImperialCity then imperial:BuildPins(mapName, place, current, EOTU.savedVars.showPatrols) end
			return
		end
		local mapData = getEntries(mapName, nil, function() coroutine.yield() end)
		if not mapData then return end
		for _, row in ipairs(mapData) do if not place(row) then return end end
	end)
end

--------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------
local function Initialize()
	dbg("Initialize")
	if not MapPins then
		dbg("Initialize: private map pin helper not found")
		return
	end
	EOTU.savedVars = ZO_SavedVars:NewAccountWide(C.SAVEDVARS, EOTU.variableVersion, nil, EOTU.defaults)
	for _, key in ipairs({ "showBosses", "showImperialCity", "showPatrols" }) do
		if type(EOTU.savedVars[key]) ~= "boolean" then EOTU.savedVars[key] = EOTU.defaults[key] end
	end
	local size = EOTU.savedVars.pinSize
	if type(size) ~= "number" or size ~= size or size < 16 or size > 36 or size ~= math.floor(size) then
		EOTU.savedVars.pinSize = EOTU.defaults.pinSize
	end

	if EOTU.CreateOptions then
		EOTU:CreateOptions()
	end
	if EOTU.Announcements then EOTU.Announcements:Init() end

	local layout = {
		level = 50,
		size = EOTU.savedVars.pinSize,
		texture = function() return PIN_ICON end,
	}

	local pinTooltipCreator = {
		tooltip = ZO_MAP_TOOLTIP_MODE.INFORMATION,
		creator = function(pin)
			local tag = select(2, pin:GetPinTypeAndTag())
			local text = tag and tag.tooltip
			if not text then return end
			if IsInGamepadPreferredMode() then
				local InformationTooltip = ZO_MapLocationTooltip_Gamepad
				local baseSection = InformationTooltip.tooltip
				InformationTooltip:LayoutIconStringLine(baseSection, nil, text,
					baseSection:GetStyle("mapLocationTooltipContentName"))
			else
				InformationTooltip:ClearLines()
				InformationTooltip:AddLine(text)
			end
		end
	}

	MapPins:AddPinType(PIN_TYPE, AddPins, nil, layout, pinTooltipCreator)

	CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
		dbg("OnWorldMapChanged")
		MapPins:RefreshPins(PIN_TYPE)
	end)

	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
		dbg("EVENT_PLAYER_ACTIVATED")
		if EOTU.RegisterGamepadMenu then EOTU:RegisterGamepadMenu() end
		if EOTU.RegisterRadial then EOTU:RegisterRadial() end
		if EOTU.Announcements then EOTU.Announcements:Init() end
		MapPins:RefreshPins(PIN_TYPE)
	end)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_DEACTIVATED, function()
		MapPins:CancelPending()
	end)
end

local function OnAddOnLoaded(_, addonName)
	if addonName ~= ADDON_NAME then return end
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
	Initialize()
end

SLASH_COMMANDS[C.SLASH or "/eotu_debug"] = SwitchDebugMode

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
